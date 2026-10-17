extends RefCounted
## Which body the dead are drawn with, and what each one tells the shader.
## With no baked folder the dead are the boxes VatBaker builds, drawn exactly as
## before. With one (made by tools/bake_body_cli.gd, kept outside the repository)
## every dead body is that one body, and the motion comes from the rules' clocks:
## it only reads them (state, age, fell_at) and decides nothing.

const BodyBake = preload("res://scripts/body_bake.gd")
const DeadPose = preload("res://game/actors/dead_pose.gd")
const Motion = preload("res://game/sim/motion.gd")
const LungerRules = preload("res://game/sim/lunger_rules.gd")

const FOLDER_ENV: String = "S2_DEAD_BODY"    # a folder to read instead of the usual one
const FOLDER: String = "user://dead_body"
## The body the dead wear when neither of the above is there: the one carried in
## the build. The switch turns it off and the dead are the boxes again.
const BUILT_IN: String = "res://models/people/n3-body_tracksuit"
const BUILT_IN_SETTING: String = "visuals/baked_dead_enabled"
const ALBEDO_FILE: String = "albedo.png"     # a baked folder's colour picture, when it has one
# Motion numbers, in the order body_bake.gd bakes them.
const WALKS: int = 3                          # 0, 1, 2: three ways of walking
const STAND: int = 3
const LUNGE: int = 4
const FALL: int = 6                           # on its back
const RUN: int = 7
const TELL: int = 8                           # dropping low before it runs
const FALL_FRONT: int = 9                     # on its face
const CRAWL: int = 10
const RISE: int = 11                          # getting up off its back
const CLIMB: int = 12                         # hauling itself up out of a hole
const RISE_FRONT: int = 13                    # getting up off its face
const STAGGER: int = 14                       # spent after a run: bent over, reeling on wide legs
const CRAWL_LEN: float = 1.8                  # one round of the crawl, seconds (as baked)
# How far one round of a motion carries the body, metres, so that the foot
# going backwards stays on its spot. The bake measures it on the body it bakes
# (body_bake.gd, round_of) and assets() reads that; these are for a folder
# baked before it did, measured the same way on one body. The feet keep that
# pace to within a quarter. The crawl's hands keep no steady pace, and its
# number is only their middle.
const STRIDE: Dictionary = {0: 1.27, 1: 1.46, 2: 0.91, RUN: 2.14, CRAWL: 0.61, STAGGER: 1.01}
const STRIDE_CAP: float = 0.5                 # more than this between two drawings is not a step (it was moved, or not drawn)
static var rounds: Dictionary = {}             # what the baked folder in use measured (see assets)
static var table: Array = []                   # its motions: [first frame, frames, loops, seconds] each

const SECONDS: Dictionary = {STAND: 3.0, LUNGE: 1.0}   # a round of each, for a folder that does not say
const SWAY_CAP: float = 0.1                   # a longer gap between two drawings is not played through
const MIX_TIME: float = 0.2                   # a body changing motion keeps something of the frame it was in this long
const MIX_STEPS: float = 63.0                 # how finely the shader is told how much (see dead_vat.gdshader)

const STILL_AFTER: float = 0.3               # it stands (not walks) once it has kept its place this long


## The baked body, or {} when there is none.
static func assets() -> Dictionary:
	var dir := OS.get_environment(FOLDER_ENV)
	if dir == "":
		dir = FOLDER if DirAccess.dir_exists_absolute(FOLDER) else built_in()
	var got := with_albedo(BodyBake.load_baked(dir), dir) if dir != "" else {}
	rounds = rounds_of(got)
	table = table_of(got) if can_mix() else []
	return got


## The folder carried in the build, or "" when the switch is off.
static func built_in() -> String:
	return BUILT_IN if bool(ProjectSettings.get_setting(BUILT_IN_SETTING, true)) else ""


## A loaded bake with its folder's colour picture added as "albedo", when the
## folder has one (vat_baker.gd shader_tables hands it to the shader).
static func with_albedo(got: Dictionary, dir: String) -> Dictionary:
	var path := dir.path_join(ALBEDO_FILE)
	if not got.is_empty() and ResourceLoader.exists(path):
		got["albedo"] = load(path)
	return got


## False where the instance values reach the shader too coarse to carry a
## frame and a share in g (the compatibility renderer: a large g does not come
## back from the instance buffer as it went in). There a body changes motion
## at once, as it did.
static func can_mix() -> bool:
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"


## Where each motion of a baked folder lies in its picture.
static func table_of(vat: Dictionary) -> Array:
	var out := []
	for clip: Dictionary in vat.get("clips", []):
		out.append([int(clip["start"]), int(clip["frames"]), bool(clip["loop"]), float(clip["length"])])
	return out


## Motion number -> its round, for the motions the baked folder gives one.
static func rounds_of(vat: Dictionary) -> Dictionary:
	var out := {}
	var clips: Array = vat.get("clips", [])
	for n in clips.size():
		var size := float(clips[n].get("round", 0.0))
		if size > 0.0:
			out[n] = size
	return out


static func is_baked(vat: Dictionary) -> bool:
	return vat.has("clips")


## True when the baked motions put this body on the ground by themselves (the
## falls, the crawl), so the whole body is not turned over on top of them.
static func falls_by_motion(_z: Dictionary, baked: bool) -> bool:
	return baked


## How far a baked body turns off the line it fell on as it goes down, so no
## two lie alike (the same turn the boxes get; the roll onto a shoulder is left
## to the motion). A crawler keeps to its line.
static func ground_turn(z: Dictionary, down: float) -> float:
	if z["crawl"]:
		return 0.0
	return float(DeadPose.sprawl(float(z["phase"]))["turn"]) * down


## Where a climbing body is drawn from its standing place. Out of a manhole it
## is what the boxes get (lifted out of the ground, leaning on the rim). Out of
## a culvert the baked crawl and fall already lie flat, so the body is only
## slid out along the way it faces, not turned over as well.
static func climbing(z: Dictionary, baked: bool) -> Transform3D:
	var whole := DeadPose.climbing(z)
	if baked and String(z.get("climb_way", "lid")) == "culvert":
		return Transform3D(Basis(), Vector3(0, 0, whole.origin.z))
	return whole


## Which of the three walks a body has: its own, from its number.
static func walk_of(phase: float) -> int:
	return int(fposmod(phase * 9.13, 1.0) * float(WALKS)) % WALKS


## What one drawn body tells the shader: r = its own number (or how far through
## a motion that plays once), g = the motion, b = 1 holds it still, a = shade.
## A baked body that has just changed motion also says what frame it was in
## (see mixed).
static func custom(z: Dictionary, down: float, still: float, shade: float, baked: bool) -> Color:
	var plain := picked(z, down, still, shade, baked)
	return mixed(z, plain) if baked else plain


## The frame of the picture a motion is at for r.
static func frame_of(motion: int, r: float) -> int:
	if motion < 0 or motion >= table.size():
		return 0
	var first: int = table[motion][0]
	var frames: int = table[motion][1]
	if table[motion][2]:
		return first + int(fposmod(r, 1.0) * float(frames)) % frames
	return first + int(roundf(clampf(r, 0.0, 1.0) * float(frames - 1)))


## Eases a body from the motion it was in to the one it is in now: for
## MIX_TIME after the change, g also carries the frame it was last drawn in
## and how much of that it still keeps (g = motion + 16 * frame + 65536 *
## share, share 0..MIX_STEPS). Nothing is added once it has settled, or when
## no baked folder's table is known. What it was last drawn as is noted on the
## body itself, under names the rules do not use.
static func mixed(z: Dictionary, plain: Color) -> Color:
	if table.is_empty():
		return plain
	var motion := int(plain.g)
	var age: float = z["age"]
	if z.has("body_motion") and int(z["body_motion"]) != motion:
		z["body_from"] = frame_of(int(z["body_motion"]), float(z["body_r"]))
		z["body_changed"] = age
	z["body_motion"] = motion
	z["body_r"] = plain.r
	if not z.has("body_changed"):
		return plain
	var left := 1.0 - (age - float(z["body_changed"])) / MIX_TIME
	if left <= 0.0:
		return plain
	var share := roundf(left * left * (3.0 - 2.0 * left) * MIX_STEPS)
	if share <= 0.0:
		return plain
	return Color(plain.r, plain.g + 16.0 * float(z["body_from"]) + 65536.0 * share, plain.b, plain.a)


## The motion one body is in and how far through it, before any easing.
static func picked(z: Dictionary, down: float, still: float, shade: float, baked: bool) -> Color:
	var state: String = z["state"]
	if not baked:
		var clip := 1.0 if state == "chase" or state == "attack" or state == "grab" else 0.0
		return Color(z["phase"], clip, still, shade)
	var phase: float = z["phase"]
	if state == "climb":
		if String(z.get("climb_way", "lid")) != "culvert":
			return Color(DeadPose.climb_k(z), float(CLIMB), 1.0, shade)
		# Out of a culvert it crawls, then gets up off its face.
		# Nothing steps its walk while it climbs, so the crawl is read off the same clock.
		var row := DeadPose.climb_row(z)
		if DeadPose.in_hole(z):
			return Color(fposmod(DeadPose.climb_k(z) * float(row["len"]) / CRAWL_LEN, 1.0), float(CRAWL), 0.0, shade)
		var open := float(row["open"]) / float(row["len"])
		return Color((DeadPose.climb_k(z) - open) / (1.0 - open), float(RISE_FRONT), 1.0, shade)
	if z["crawl"]:
		# A crawler drags itself along on its face; knocked down it lies as it crawled, and dead it lies as one fallen forward.
		if state == "dead":
			return Color(1.0, float(FALL_FRONT), 1.0, shade)
		if state == "downed":
			return Color(float(z.get("body_step", phase)), float(CRAWL), 1.0, shade)
		return Color(step(z, CRAWL), float(CRAWL), 1.0, shade)
	if down > 0.0:
		# Struck from behind it goes over on its face, otherwise on its back.
		var front := DeadPose.fall_side(z) > 0.0
		if coming_up(z, down):
			return Color(1.0 - down, float(RISE_FRONT if front else RISE), 1.0, shade)
		return Color(fall_progress(z, down), float(FALL_FRONT if front else FALL), 1.0, shade)
	if state == "attack" or state == "grab":
		return Color(swayed(z, LUNGE, still), float(LUNGE), 1.0, shade)
	if state == "tell":
		return Color(tell_k(z), float(TELL), 1.0, shade)
	if state == "frozen" or state == "waking":
		return Color(swayed(z, STAND, still), float(STAND), 1.0, shade)
	# Its feet go by the ground it has covered, not by the clock: a wanderer
	# plods and one hurrying steps quicker, on the same walk.
	var gait := gait_of(z)
	var at := step(z, gait)
	if kept_still(z):
		return Color(swayed(z, STAND, still), float(STAND), 1.0, shade)
	return Color(at, float(gait), 1.0, shade)


## How far into its tell one of the dead is: 0 as it starts to drop, 1 as it runs.
static func tell_k(z: Dictionary) -> float:
	return clampf(1.0 - float(z["t"]) / LungerRules.TELL, 0.0, 1.0)


## True when a body that is partly down is on its way up, not on its way down.
static func coming_up(z: Dictionary, down: float) -> bool:
	if z["state"] == "rising":
		return true
	if down >= 1.0 or not z.has("fell_at"):
		return down < 1.0
	return float(z["age"]) - float(z["fell_at"]) >= float(Motion.row("dead_fall")["len"])


## How far through the fall a body on the ground is drawn. Going over, it is the
## time since it fell. Coming up has its own motions (see custom), so past the
## fall this is only how far down a body that is not coming up lies.
static func fall_progress(z: Dictionary, down: float) -> float:
	if z.has("fell_at") and z["state"] != "rising":
		var u := clampf((float(z["age"]) - float(z["fell_at"])) / float(Motion.row("dead_fall")["len"]), 0.0, 1.0)
		if u < 1.0:
			return u
	return clampf(down, 0.0, 1.0)


## True once a body has kept its place for a while (moved keeps the note of
## that on the body itself, under names the rules do not use).
static func kept_still(z: Dictionary) -> bool:
	return float(z["age"]) - float(z.get("body_since", z["age"])) >= STILL_AFTER


## How far a body has come since it was last drawn; notes the place, and when
## it last left one.
static func moved(z: Dictionary) -> float:
	var at: Vector3 = z["pos"]
	var gone := at.distance_to(z.get("body_at", at))
	if gone > 0.001 or not z.has("body_since"):
		z["body_since"] = z["age"]
	z["body_at"] = at
	return gone


## Where in a round of a motion that goes by the clock (standing, lunging) a
## body is, 0..1. The drawing side keeps that clock itself, off the body's
## age, so that it knows the frame (the shader's own clock is not used for a
## baked body). It starts from the body's own number and each body goes at its
## own pace (0.82..1.18, as the shader had it); `still` 1 holds it.
static func swayed(z: Dictionary, motion: int, still: float) -> float:
	var age: float = z["age"]
	var gone := clampf(age - float(z.get("body_age", age)), 0.0, SWAY_CAP)
	z["body_age"] = age
	var at: float = z.get("body_sway", z["phase"])
	var seconds: float = table[motion][3] if motion < table.size() and table[motion].size() > 3 else float(SECONDS[motion])
	var pace := lerpf(0.82, 1.18, fposmod(float(z["phase"]) * 7.31, 1.0))
	at = fposmod(at + gone * pace * (1.0 - still) / maxf(seconds, 0.001), 1.0)
	z["body_sway"] = at
	return at


## Where in a round of its walk (or run, or crawl) a body is, 0..1: it goes on
## by the ground covered since it was last drawn, and starts from the body's
## own number so that no two step together.
static func step(z: Dictionary, motion: int) -> float:
	var gone := moved(z)
	var at: float = z.get("body_step", z["phase"])
	if gone <= STRIDE_CAP:
		at = fposmod(at + gone / float(rounds.get(motion, STRIDE[motion])), 1.0)
	z["body_step"] = at
	return at


## The walk a body goes by: one of its three, or the run when it is one of the
## fresh dead coming after someone (the rules give those their speed). One
## that lunges runs while its run lasts and reels while it is spent.
static func gait_of(z: Dictionary) -> int:
	if z["state"] == "chase":
		if float(z.get("dash_t", 0.0)) > 0.0:
			return RUN
		if float(z.get("spent_t", 0.0)) > 0.0:
			return STAGGER
	if z["state"] == "chase" and z.get("kind", "") == "fresh":
		return RUN
	return walk_of(z["phase"])
