extends RefCounted
## Which body the dead are drawn with, and what each one tells the shader.
## With no baked folder the dead are the boxes VatBaker builds, drawn exactly as
## before. With one (made by tools/bake_body_cli.gd, kept outside the repository)
## every dead body is that one body, and the motion comes from the rules' clocks:
## it only reads them (state, age, fell_at) and decides nothing.

const BodyBake = preload("res://scripts/body_bake.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
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
const HIT: int = 5                            # struck: one held pose, thrown back from the chest
const FALL: int = 6                           # on its back
const RUN: int = 7
const TELL: int = 8                           # dropping low before it runs
const FALL_FRONT: int = 9                     # on its face
const CRAWL: int = 10
const RISE: int = 11                          # getting up off its back
const CLIMB: int = 12                         # hauling itself up out of a hole
const RISE_FRONT: int = 13                    # getting up off its face
const STAGGER: int = 14                       # spent after a run: bent over, reeling on wide legs
const FALL_THROWN: int = 15                   # on its back, thrown over (decision 412)
const FALL_SLUMP: int = 16                    # on its face, slumped
# What the reference game's dead do that these could not before (motion detail 2,
# 2026-10-24), picked below only where the folder in use has them (decision 422).
const THUMP: int = 17                         # at a door, both forearms on it (motion.gd dead_thump)
const CLAW: int = 18                          # at a door, clawing with one hand then the other
const HIT_LEFT: int = 19                      # struck on the head from its left
const HIT_RIGHT: int = 20                     # from its right
const HIT_TOP: int = 21                       # from above
const HIT_UPPER: int = 22                     # from under the chin
const TURN_LEFT: int = 23                     # turning round to something on its left
const TURN_RIGHT: int = 24                    # on its right
const WALK_D: int = 25                        # two slower walks: a shuffle
const WALK_E: int = 26                        # and a lurch on a stiff leg
const CRAWL_LEN: float = 1.8                  # one round of the crawl, seconds (as baked)
# How far one round of a motion carries the body, metres, so that the foot
# going backwards stays on its spot. The bake measures it on the body it bakes
# (body_bake.gd, round_of) and assets() reads that; these are for a folder
# baked before it did, measured the same way on one body. The feet keep that
# pace to within a quarter. The crawl's hands keep no steady pace, and its
# number is only their middle.
const STRIDE: Dictionary = {0: 1.27, 1: 1.46, 2: 0.91, RUN: 2.14, CRAWL: 0.61, STAGGER: 1.01, WALK_D: 0.61, WALK_E: 1.08}
const STRIDE_CAP: float = 0.5                 # more than this between two drawings is not a step (it was moved, or not drawn)
static var rounds: Dictionary = {}             # what the baked folder in use measured (see assets)
static var table: Array = []                   # its motions: [first frame, frames, loops, seconds] each

const SECONDS: Dictionary = {STAND: 3.0, LUNGE: 1.0}   # a round of each, for a folder that does not say
const SWAY_CAP: float = 0.1                   # a longer gap between two drawings is not played through
const MIX_TIME: float = 0.2                   # a body changing motion keeps something of the frame it was in this long
# How long a change into these is eased, after the reference game's dead
# (상태표 2.4: struck 0.10 s, the lunge 0.35, reeling back 0.40, getting up
# 0.20; walking, running and standing 0.35, crawling 0.20; at a door 0.20;
# turning round 0.40). Struck shows at once; a body that reels goes into it slowly.
const MIX_IN: Dictionary = {HIT: 0.1, LUNGE: 0.35, STAGGER: 0.4, RISE: 0.2, RISE_FRONT: 0.2,
	0: 0.35, 1: 0.35, 2: 0.35, RUN: 0.35, STAND: 0.35, CRAWL: 0.2,
	THUMP: 0.2, CLAW: 0.2, HIT_LEFT: 0.1, HIT_RIGHT: 0.1, HIT_TOP: 0.1, HIT_UPPER: 0.1,
	TURN_LEFT: 0.4, TURN_RIGHT: 0.4, WALK_D: 0.35, WALK_E: 0.35}
# At a door: still at it while it was last seen banging within AT_DOOR; half of
# the dead (by their own number) claw at it, and a claw's bang lands at CLAW_LANDS
# of its round (the thump's where motion.gd dead_thump has it).
const AT_DOOR: float = 0.25
const CLAW_LANDS: float = 0.73
# Struck on the head (field_combat.gd notes when, from where and with which way
# of the blow): across and the axe's chop in come from the striker's right, back
# the other way from its left, overhead from above, a stab from under the chin.
const BLOW_FROM: Dictionary = {"p_swing_back": -1.0, "p_swing_axe": 0.0, "p_stab": 0.0}
const BLOW_MOTION: Dictionary = {"p_swing_axe": HIT_TOP, "p_stab": HIT_UPPER}
const HAND_OUT: float = 0.4                   # how far to the striker's side a swing comes in from, metres
# Turning round to something it heard (zombies.gd turn_t): the body is drawn
# coming round over the rules' turn, not at once; less than TURN_MIN is no turn.
# Cut short, it comes the rest of the way round within TURN_CATCH.
const TURN_MIN: float = 0.35
const TURN_CATCH: float = 0.15
# Of the dead only wandering (zombies.gd SPEED_WANDER, slower than the slow
# walks' own pace), a fifth shuffle and a fifth go on a stiff leg; hurrying,
# they walk their own walk (a slow walk at a hurry's pace would race).
const SLOW_WALKS: float = 0.4
# Held on to someone (grab) or about to be (attack): the lunge's reach held at
# one place in its round, the legs only shifting a little, not walking.
const REACH_AT: float = 0.0
const REACH_SHIFT: float = 0.03               # how far round the legs shift either way
const REACH_HZ: float = 0.9
# The reference game scatters how fast each of the dead stands breathing (0.2..1.25
# of its pace) and how long its stride is; past a tenth of the stride the feet slide.
const STAND_PACE: Vector2 = Vector2(0.3, 1.25)
const STRIDE_SPREAD: float = 0.1
const REEL_PACE: float = 0.6                  # stunned after being thrown off: its reel at this pace, on the spot
const REEL_AFTER: float = 1.0                 # that long after it was thrown off at most (zombies.gd release stuns it 1 s)
const MIX_STEPS: float = 31.0                 # how finely the shader is told how much (VatBaker.SHARE_MAX, dead_vat.gdshader)

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
	return frame_in(table, motion, r)


## The same in a given folder's table (the living wear another body).
static func frame_in(tab: Array, motion: int, r: float) -> int:
	if motion < 0 or motion >= tab.size():
		return 0
	var first: int = tab[motion][0]
	var frames: int = tab[motion][1]
	if tab[motion][2]:
		return first + int(fposmod(r, 1.0) * float(frames)) % frames
	return first + int(roundf(clampf(r, 0.0, 1.0) * float(frames - 1)))


## How long a change into a motion is eased.
static func mix_time(motion: int) -> float:
	return float(MIX_IN.get(motion, MIX_TIME))


## Eases a body from the motion it was in to the one it is in now: for
## MIX_TIME after the change, g also carries the frame it was last drawn in
## and how much of that it still keeps (g = motion + 16 * frame + 65536 *
## share, share 0..MIX_STEPS). Nothing is added once it has settled, or when
## no baked folder's table is known. What it was last drawn as is noted on the
## body itself, under names the rules do not use.
static func mixed(z: Dictionary, plain: Color) -> Color:
	return mix_from(z, plain, float(z["age"]), table)


## The easing itself, for any body: `note` keeps what it was last drawn as,
## `now` is its own clock, `tab` its folder's table, `mix_in` how long a change
## into each of its motions is eased (another folder numbers its motions its own way).
static func mix_from(note: Dictionary, plain: Color, now: float, tab: Array, mix_in: Dictionary = MIX_IN) -> Color:
	var motion := int(plain.g)
	if tab.is_empty():
		return packed(plain, motion, 0, 0.0)
	if note.has("body_motion") and int(note["body_motion"]) != motion:
		note["body_from"] = frame_in(tab, int(note["body_motion"]), float(note["body_r"]))
		note["body_changed"] = now
		note["body_mix"] = float(mix_in.get(motion, MIX_TIME))
	note["body_motion"] = motion
	note["body_r"] = plain.r
	if not note.has("body_changed"):
		return packed(plain, motion, 0, 0.0)
	var left := 1.0 - (now - float(note["body_changed"])) / float(note.get("body_mix", MIX_TIME))
	if left <= 0.0:
		return packed(plain, motion, 0, 0.0)
	var share := roundf(left * left * (3.0 - 2.0 * left) * MIX_STEPS)
	if share <= 0.0:
		return packed(plain, motion, 0, 0.0)
	return packed(plain, motion, int(note["body_from"]), share)


## The colour the shader reads: the motion, from motion 16 on in its upper half
## (VatBaker.pack_motion), and while it changes motion the frame it was in and
## how much of that it keeps.
static func packed(plain: Color, motion: int, from: int, share: float) -> Color:
	return Color(plain.r, VatBaker.pack_motion(motion, from, int(share)), plain.b, plain.a)


## The motion a packed colour is in (undoing packed()).
static func motion_in(g: float) -> int:
	var at := floorf(g + 0.5)
	var upper := floorf(at / VatBaker.UPPER)
	at -= upper * VatBaker.UPPER
	return int(fposmod(at, 16.0)) + 16 * int(upper)


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
		return Color(fall_progress(z, down), float(fall_motion(z, front)), 1.0, shade)
	if state == "attack" or state == "grab":
		# It has reached them: the arms stay out at them and the legs shift
		# under it (the body is held at their side, so a walk would slide).
		var shift := REACH_SHIFT * sin(TAU * (REACH_HZ * float(z["age"]) + phase))
		return Color(fposmod(REACH_AT + shift, 1.0), float(LUNGE), 1.0, shade)
	var struck := struck_motion(z)
	if struck >= 0:
		return Color(struck_k(z), float(struck), 1.0, shade)
	if float(z.get("shoved_t", 0.0)) > 0.0:
		# Thrown off: it reels back, its feet going back over the ground it is
		# seen to cover; then, stunned, it reels on the spot until it comes on.
		return Color(step_back(z, STAGGER), float(STAGGER), 1.0, shade)
	if float(z.get("stun", 0.0)) > 0.0 and float(z["age"]) - float(z.get("body_reeled", -10.0)) < REEL_AFTER:
		return Color(reeling(z, still), float(STAGGER), 1.0, shade)
	if at_door(z):
		moved(z)
		var beat := door_motion(z)
		return Color(door_k(z, beat), float(beat), 1.0, shade)
	if state == "tell":
		return Color(tell_k(z), float(TELL), 1.0, shade)
	if state == "frozen" or state == "waking":
		return Color(swayed(z, STAND, still), float(STAND), 1.0, shade)
	var turn := turn_motion(z)
	if turn >= 0:
		moved(z)
		return Color(turn_k(z), float(turn), 1.0, shade)
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


## Which way a body goes over: struck from behind on its face, otherwise on
## its back, and half of the dead (by their own number, so always the same)
## the other way of each when the folder in use has it (decision 412: thrown
## over stiffly, or slumping limp). Both lie at the end as the first does.
static func fall_motion(z: Dictionary, front: bool) -> int:
	var other := FALL_SLUMP if front else FALL_THROWN
	if other < table.size() and fposmod(float(z["phase"]) * 5.17, 1.0) < 0.5:
		return other
	return FALL_FRONT if front else FALL


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
## own pace (0.82..1.18, as the shader had it; standing, STAND_PACE); `still` 1 holds it.
static func swayed(z: Dictionary, motion: int, still: float) -> float:
	var age: float = z["age"]
	var gone := clampf(age - float(z.get("body_age", age)), 0.0, SWAY_CAP)
	z["body_age"] = age
	var at: float = z.get("body_sway", z["phase"])
	var seconds: float = table[motion][3] if motion < table.size() and table[motion].size() > 3 else float(SECONDS[motion])
	var spread: Vector2 = STAND_PACE if motion == STAND else Vector2(0.82, 1.18)
	var pace := lerpf(spread.x, spread.y, fposmod(float(z["phase"]) * 7.31, 1.0))
	at = fposmod(at + gone * pace * (1.0 - still) / maxf(seconds, 0.001), 1.0)
	z["body_sway"] = at
	return at


## Where in a round of the reel a body thrown back is: the ground it is seen
## to cover goes the other way under its feet.
static func step_back(z: Dictionary, motion: int) -> float:
	var gone := moved(z)
	z["body_reeled"] = z["age"]
	var at: float = z.get("body_step", z["phase"])
	if gone <= STRIDE_CAP:
		at = fposmod(at - gone / float(rounds.get(motion, STRIDE[motion])), 1.0)
	z["body_step"] = at
	return at


## The reel on the spot after it, by the drawing side's own clock.
static func reeling(z: Dictionary, still: float) -> float:
	moved(z)
	var age: float = z["age"]
	var gone := clampf(age - float(z.get("body_age", age)), 0.0, SWAY_CAP)
	z["body_age"] = age
	var at: float = z.get("body_step", z["phase"])
	var seconds: float = table[STAGGER][3] if STAGGER < table.size() and table[STAGGER].size() > 3 else 1.3
	at = fposmod(at + gone * REEL_PACE * (1.0 - still) / maxf(seconds, 0.001), 1.0)
	z["body_step"] = at
	return at


## Where in a round of its walk (or run, or crawl) a body is, 0..1: it goes on
## by the ground covered since it was last drawn, and starts from the body's
## own number so that no two step together, each with its own stride (STRIDE_SPREAD).
static func step(z: Dictionary, motion: int) -> float:
	var gone := moved(z)
	var at: float = z.get("body_step", z["phase"])
	if gone <= STRIDE_CAP:
		var own := lerpf(1.0 - STRIDE_SPREAD, 1.0 + STRIDE_SPREAD, fposmod(float(z["phase"]) * 3.17, 1.0))
		at = fposmod(at + gone / (float(rounds.get(motion, STRIDE[motion])) * own), 1.0)
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
	if z["state"] == "wander" and WALK_E < table.size():
		var slow := fposmod(float(z["phase"]) * 4.21, 1.0)
		if slow < SLOW_WALKS:
			return WALK_D if slow < SLOW_WALKS * 0.5 else WALK_E
	return walk_of(z["phase"])


## The length of a motion in the folder in use, seconds (`or_else` without one).
static func seconds_of(motion: int, or_else: float) -> float:
	if motion < table.size() and table[motion].size() > 3 and float(table[motion][3]) > 0.0:
		return float(table[motion][3])
	return or_else


## True while a body is at a shut door beating on it (zombies.gd _bang notes
## each moment it is there), and the folder in use has the motions for it.
static func at_door(z: Dictionary) -> bool:
	if CLAW >= table.size() or not z.has("bang_seen"):
		return false
	var since := float(z["age"]) - float(z["bang_seen"])
	return since >= 0.0 and since < AT_DOOR


## Thumping with both forearms, or (half of the dead, by their own number) clawing.
static func door_motion(z: Dictionary) -> int:
	return CLAW if fposmod(float(z["phase"]) * 6.73, 1.0) < 0.5 else THUMP


## How far round its beat at the door a body is: on the rules' bang clock, so
## the blow lands as the door is banged on (and the sound made).
static func door_k(z: Dictionary, motion: int) -> float:
	var row: Dictionary = Motion.row("dead_thump")
	var beat := float(row["len"])
	var lands := float(row["hit"]) / beat if motion == THUMP else CLAW_LANDS
	var since := beat - clampf(float(z.get("bang_t", 0.0)), 0.0, beat)
	return fposmod(lands + since / beat, 1.0)


## Struck on the head and still on its feet: which of the four, for as long as
## the motion lasts after the blow; -1 otherwise (or the folder has none of
## them: then as before). A shove after the blow is seen over it.
static func struck_motion(z: Dictionary) -> int:
	if HIT_UPPER >= table.size() or not z.has("hit_at"):
		return -1
	var since := float(z["age"]) - float(z["hit_at"])
	if since < 0.0 or since >= seconds_of(HIT_LEFT, 0.4):
		return -1
	var shoved := float(z.get("shoved_t", 0.0))
	if shoved > 0.0 and float(Motion.row("dead_shoved")["len"]) - shoved < since:
		return -1
	if float(z.get("body_hit_seen", -1.0)) != float(z["hit_at"]):
		z["body_hit_seen"] = z["hit_at"]
		z["body_hit"] = struck_from(z)
	return int(z["body_hit"])


static func struck_k(z: Dictionary) -> float:
	return clampf((float(z["age"]) - float(z["hit_at"])) / seconds_of(HIT_LEFT, 0.4), 0.0, 1.0)


## Which side of its head the blow came in from: the way of the blow the
## striker was seen to swing, and where it stood (it faces what it strikes).
static func struck_from(z: Dictionary) -> int:
	var way := String(z.get("hit_way", ""))
	if BLOW_MOTION.has(way):
		return int(BLOW_MOTION[way])
	var at: Vector3 = z["pos"]
	var by: Vector3 = z.get("hit_by", at)
	var toward := Vector3(at.x - by.x, 0.0, at.z - by.z)
	if toward.length() < 0.01:
		return HIT_LEFT
	toward = toward.normalized()
	var hand := float(BLOW_FROM.get(way, 1.0))
	var came := Vector3(by.x - at.x, 0.0, by.z - at.z) + Vector3(-toward.z, 0.0, toward.x) * hand * HAND_OUT
	var fwd := Vector3(sin(float(z["angle"])), 0.0, cos(float(z["angle"])))
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	return HIT_RIGHT if right.dot(came) > 0.0 else HIT_LEFT


## Notes a turn the rules have just begun (turn_t from nothing): from the way
## the body was last drawn facing to the way it turns to, over the rules' turn.
## Safe to call more than once a frame.
static func _note_turn(z: Dictionary) -> void:
	if TURN_RIGHT >= table.size():
		return
	var left := float(z.get("turn_t", 0.0))
	if left <= 0.0:
		if bool(z.get("body_turning", false)):
			z["body_turning"] = false
			if int(z.get("body_turn", -1)) >= 0 and _turn_ratio(z) < 1.0:
				# Cut short (it saw someone): the rest of the way round, quickly.
				z["body_turn_from"] = z.get("body_yaw", z["angle"])
				z["body_turn_at"] = z["age"]
				z["body_turn_len"] = TURN_CATCH
				z["body_turn"] = -2
		return
	if bool(z.get("body_turning", false)):
		return
	z["body_turning"] = true
	var from := float(z.get("body_yaw", z["angle"]))
	var to: Vector3 = z.get("target", z["pos"])
	var want := atan2(to.x - z["pos"].x, to.z - z["pos"].z) if to.distance_to(z["pos"]) > 0.01 else float(z["angle"])
	var d := angle_difference(from, want)
	z["body_turn_from"] = from
	z["body_turn_at"] = z["age"]
	z["body_turn_len"] = maxf(left, 0.05)
	# Turning by more round toward its left (the body faces +z, its right is -x).
	z["body_turn"] = (TURN_LEFT if d > 0.0 else TURN_RIGHT) if absf(d) >= TURN_MIN else -1


## How far through its turn round a body is, 0..1; -1 when it is not turning.
static func turn_k(z: Dictionary) -> float:
	var k := _turn_ratio(z)
	return -1.0 if k >= 1.0 else maxf(k, 0.0)


static func _turn_ratio(z: Dictionary) -> float:
	if not z.has("body_turn_at"):
		return INF
	return (float(z["age"]) - float(z["body_turn_at"])) / maxf(float(z["body_turn_len"]), 0.001)


## The turn-round motion a body is in, or -1.
static func turn_motion(z: Dictionary) -> int:
	_note_turn(z)
	var turn := int(z.get("body_turn", -1))
	if turn < 0 or not bool(z.get("body_turning", false)) or turn_k(z) < 0.0:
		return -1
	return turn


## The way a body is drawn facing: the rules' own, except while it comes round
## to something it heard, eased over the turn (the motion only moves the limbs).
## Notes what it was drawn as. The boxes face the rules' way.
static func yaw_of(z: Dictionary, baked: bool) -> float:
	var yaw := float(z["angle"])
	if not baked:
		return yaw
	_note_turn(z)
	if int(z.get("body_turn", -1)) != -1:
		var k := turn_k(z)
		if k >= 0.0:
			yaw = lerp_angle(float(z["body_turn_from"]), yaw, k * k * (3.0 - 2.0 * k))
	z["body_yaw"] = yaw
	return yaw
