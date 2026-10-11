extends RefCounted
## Which body the dead are drawn with, and what each one tells the shader.
## With no baked folder the dead are the boxes VatBaker builds, drawn exactly as
## before. With one (made by tools/bake_body_cli.gd, kept outside the repository)
## every dead body is that one body, and the motion comes from the rules' clocks:
## it only reads them (state, age, fell_at) and decides nothing.

const BodyBake = preload("res://scripts/body_bake.gd")
const DeadPose = preload("res://game/actors/dead_pose.gd")
const Motion = preload("res://game/sim/motion.gd")

const FOLDER_ENV: String = "S2_DEAD_BODY"    # a folder to read instead of the usual one
const FOLDER: String = "user://dead_body"
# Motion numbers, in the order body_bake.gd bakes them.
const WALKS: int = 3                          # 0, 1, 2: three ways of walking
const STAND: int = 3
const LUNGE: int = 4
const FALL: int = 6                           # on its back
const RUN: int = 7
const FALL_FRONT: int = 9                     # on its face
const CRAWL: int = 10
const RISE: int = 11                          # getting up off its back
const CLIMB: int = 12                         # hauling itself up out of a hole
const RISE_FRONT: int = 13                    # getting up off its face
const CRAWL_LEN: float = 1.8                  # one round of the crawl, seconds (as baked)
# How far one round of a motion carries the body, metres, so that the foot
# going backwards stays on its spot: measured on the hand-written motions as
# baked (how far a foot goes back in a frame, times the frames). The feet keep
# that pace to within a quarter. The crawl's hands keep no steady pace, and
# its number is only their middle.
const STRIDE: Dictionary = {0: 1.27, 1: 1.46, 2: 0.91, RUN: 2.14, CRAWL: 0.61}
const STRIDE_CAP: float = 0.5                 # more than this between two drawings is not a step (it was moved, or not drawn)
const STILL_AFTER: float = 0.3               # it stands (not walks) once it has kept its place this long


## The baked body, or {} when there is none.
static func assets() -> Dictionary:
	var dir := OS.get_environment(FOLDER_ENV)
	return BodyBake.load_baked(dir if dir != "" else FOLDER)


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
static func custom(z: Dictionary, down: float, still: float, shade: float, baked: bool) -> Color:
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
		return Color(phase, float(LUNGE), still, shade)
	if state == "frozen" or state == "waking":
		return Color(phase, float(STAND), still, shade)
	# Its feet go by the ground it has covered, not by the clock: a wanderer
	# plods and one hurrying steps quicker, on the same walk.
	var gait := gait_of(z)
	var at := step(z, gait)
	if kept_still(z):
		return Color(phase, float(STAND), still, shade)
	return Color(at, float(gait), 1.0, shade)


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


## Where in a round of its walk (or run, or crawl) a body is, 0..1: it goes on
## by the ground covered since it was last drawn, and starts from the body's
## own number so that no two step together.
static func step(z: Dictionary, motion: int) -> float:
	var gone := moved(z)
	var at: float = z.get("body_step", z["phase"])
	if gone <= STRIDE_CAP:
		at = fposmod(at + gone / float(STRIDE[motion]), 1.0)
	z["body_step"] = at
	return at


## The walk a body goes by: one of its three, or the run when it is one of the
## fresh dead coming after someone (the rules give those their speed).
static func gait_of(z: Dictionary) -> int:
	if z["state"] == "chase" and z.get("kind", "") == "fresh":
		return RUN
	return walk_of(z["phase"])
