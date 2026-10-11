extends RefCounted
## How far down a dead body is drawn: it goes over when it is knocked down or
## killed, lies, and comes up again over the last part of its time on the
## ground. It only reads the rules' clocks (state, t, rise_t, age) and decides
## nothing: for the rules the body is down from the moment it is knocked down
## and up when its time runs out, as before. The lengths are rows in motion.gd.

const Motion = preload("res://game/sim/motion.gd")

const SIT: float = 0.55              # getting up: this far down when it has its hands under it
const STRIKER_REACH: float = 2.6     # someone this close is taken to be the one who struck it
const STOOP_MAX: float = 0.22        # the most a body leans forward as it stands (radians)
const LIMP_ROCK: float = 0.12        # how far a dragging leg rocks the body
const LIFT: float = 0.18             # a body flat on the ground is drawn this much higher (its depth)


## Called as a standing body goes down (knocked down or killed): from here the
## fall is drawn. A body already on the ground, or one that crawls, has no fall.
## It goes over away from whoever is close enough to have struck it: on its
## back with them in front of it, on its face with them behind it.
static func mark_fall(z: Dictionary, people: Array = []) -> void:
	if z["crawl"] or z["state"] in ["dead", "downed", "rising", "frozen", "waking"]:
		return
	z["fell_at"] = z["age"]
	z["fell_fwd"] = struck_from_behind(z, people)


static func struck_from_behind(z: Dictionary, people: Array) -> bool:
	var forward := Vector3(sin(z["angle"]), 0, cos(z["angle"]))
	var best := STRIKER_REACH
	var behind := false
	for p in people:
		var to_p: Vector3 = p.position - z["pos"]
		to_p.y = 0
		var d := to_p.length()
		if d < best and d > 0.01:
			best = d
			behind = forward.dot(to_p / d) < 0.0
	return behind


## Which way the lying body is turned over: -1 on its back, 1 on its face.
static func fall_side(z: Dictionary) -> float:
	return 1.0 if bool(z.get("fell_fwd", false)) else -1.0


## How one upright body carries itself, so a crowd does not move as one: each
## has its own stoop, and one in three drags a leg (it rocks side to side with
## every step). It comes from the body's own number (phase), so it never changes.
static func gait(phase: float) -> Dictionary:
	var a := fposmod(phase * 7.31, 1.0)
	var b := fposmod(phase * 13.7, 1.0)
	return {"stoop": lerpf(0.0, STOOP_MAX, a), "limp": b < 0.34, "rate": lerpf(4.0, 5.5, a), "lean": lerpf(-0.06, 0.06, b)}


static func gait_basis(z: Dictionary) -> Basis:
	var g: Dictionary = gait(float(z["phase"]))
	var rock := float(g["lean"])
	if g["limp"]:
		# The rock goes with the ground covered, so it stops when the body stops.
		var at: Vector3 = z["pos"]
		var walked: float = float(z.get("pose_walked", 0.0)) + minf(at.distance_to(z.get("pose_at", at)), 0.5)
		z["pose_walked"] = walked
		z["pose_at"] = at
		rock += sin(walked * float(g["rate"])) * LIMP_ROCK
	return Basis(Vector3.RIGHT, float(g["stoop"])) * Basis(Vector3.BACK, rock)


## 0 upright .. 1 flat on the ground.
static func down_k(z: Dictionary) -> float:
	var state: String = z["state"]
	if not (state == "dead" or state == "downed" or state == "rising"):
		z.erase("fell_at")
		return 1.0 if z["crawl"] else 0.0
	var k := 1.0
	if z.has("fell_at"):
		k = fall_k(float(z["age"]) - float(z["fell_at"]))
	if z["crawl"] or state == "dead":
		return k
	var left: float = float(z["t"]) if state == "downed" else float(z.get("rise_t", 0.0))
	return minf(k, rise_k(left))


## Going over: slow off the heels, fast into the ground.
static func fall_k(since: float) -> float:
	var u := clampf(since / float(Motion.row("dead_fall")["len"]), 0.0, 1.0)
	return u * u


## Coming up, by the time left on the ground: flat until the last stretch, up
## on its hands by the middle of it, on its feet as the time runs out.
static func rise_k(left: float) -> float:
	var total := float(Motion.row("dead_rise")["len"])
	if left >= total:
		return 1.0
	var u := 1.0 - clampf(left / total, 0.0, 1.0)
	if u < 0.5:
		return lerpf(1.0, SIT, smoothstep(0.0, 0.5, u))
	return lerpf(SIT, 0.0, smoothstep(0.5, 1.0, u))
