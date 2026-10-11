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
# Going over is four beats, as shares of the fall's length: thrown back on its
# heels by the blow, the knees go, it drops, and it settles where it landed.
const REEL: float = 0.28             # until here it is only rocked back
const BUCKLE: float = 0.52           # by here the knees have gone from under it
const LAND: float = 0.84             # it meets the ground here
const REEL_TILT: float = 0.2         # how far over (0..1) the blow alone throws it
const BUCKLE_TILT: float = 0.36      # and how far over it is as the knees go
const SINK: float = 0.3              # how far the body drops as the knees go
const REBOUND: float = 0.08          # how far it comes back off the ground as it lands
const SPRAWL_TURN: float = 0.55      # a lying body is turned at most this far off the line it fell on (radians)
const SPRAWL_ROLL: float = 0.32      # and rolled at most this far onto one shoulder
# Coming up out of a hole (the lengths are motion.gd's dead_climb rows).
const HOLE_DEPTH: float = 1.5        # a body at the bottom of the climb is this far under the ground
const HOLE_HANG: float = 0.95        # with its head and arms out it still hangs this far down
const HOLE_LEAN: float = 0.5         # it lies this far forward over the rim as it hauls itself up (radians)
const CRAWL_BACK: float = 1.3       # a body crawling out of a culvert's mouth starts this far back in it


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


## Going over: rocked back by the blow, held there as the knees go, then fast
## into the ground, and a short settle (it comes a little way back up and lies).
static func fall_k(since: float) -> float:
	var u := clampf(since / float(Motion.row("dead_fall")["len"]), 0.0, 1.0)
	if u < REEL:
		var x := 1.0 - u / REEL
		return REEL_TILT * (1.0 - x * x)
	if u < BUCKLE:
		return lerpf(REEL_TILT, BUCKLE_TILT, smoothstep(REEL, BUCKLE, u))
	if u < LAND:
		var x := (u - BUCKLE) / (LAND - BUCKLE)
		return lerpf(BUCKLE_TILT, 1.0, x * x)
	var x := (u - LAND) / (1.0 - LAND)
	return 1.0 - REBOUND * sin(x * PI) * (1.0 - x)


## 0..1: how far the knees have gone. The body drops on them before it goes
## over, and is back on the ground's level by the time it lands.
static func sink_k(since: float) -> float:
	var u := clampf(since / float(Motion.row("dead_fall")["len"]), 0.0, 1.0)
	if u < REEL or u >= LAND:
		return 0.0
	if u < BUCKLE:
		return smoothstep(REEL, BUCKLE, u)
	return 1.0 - smoothstep(BUCKLE, LAND, u)


## How one body ends up lying, so no two lie alike and none lies like a plank:
## turned off the line it fell on and rolled onto a shoulder. From the body's
## own number, so it lies the same way every time it is drawn.
static func sprawl(phase: float) -> Dictionary:
	var a := fposmod(phase * 5.17, 1.0)
	var b := fposmod(phase * 11.3, 1.0)
	return {"turn": lerpf(-SPRAWL_TURN, SPRAWL_TURN, a), "roll": lerpf(-SPRAWL_ROLL, SPRAWL_ROLL, b)}


## What to draw on top of a body's standing place when it is `down` (0..1) of
## the way to the ground: the turn over, its own sprawl, the drop of the knees
## and the lift of a body lying on its depth. A crawler stays on its line.
static func lying(z: Dictionary, down: float) -> Transform3D:
	var basis := Basis(Vector3.RIGHT, fall_side(z) * PI * 0.5 * down)
	if not z["crawl"]:
		var s: Dictionary = sprawl(float(z["phase"]))
		basis = Basis(Vector3.UP, float(s["turn"]) * down) * basis * Basis(Vector3.UP, float(s["roll"]) * down)
	var y := LIFT * down
	if z.has("fell_at") and z["state"] != "rising":
		y -= SINK * sink_k(float(z["age"]) - float(z["fell_at"]))
	return Transform3D(basis, Vector3(0, y, 0))


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


## The row of the hole a climbing body is coming out of.
static func climb_row(z: Dictionary) -> Dictionary:
	return Motion.row("dead_climb_" + String(z.get("climb_way", "lid")))


## 0..1: how far through its climb a body is (1 when it is not climbing).
static func climb_k(z: Dictionary) -> float:
	if z["state"] != "climb" or not z.has("climb_at"):
		return 1.0
	return clampf((float(z["age"]) - float(z["climb_at"])) / float(climb_row(z)["len"]), 0.0, 1.0)


## True while only the head and arms of a climbing body are out of the hole.
static func in_hole(z: Dictionary) -> bool:
	var row := climb_row(z)
	return z["state"] == "climb" and climb_k(z) * float(row["len"]) < float(row["open"])


## What to draw on top of a climbing body's standing place. Out of a manhole:
## the head and arms come up and hang on the rim, then it heaves itself up
## lying forward over the rim and straightens. Out of a culvert: it comes out
## flat on its face, head first along the way it faces, and gets up. The
## origin is in the body's own frame (z is the way it faces). A body that is
## not climbing is left as it is.
static func climbing(z: Dictionary) -> Transform3D:
	var u := climb_k(z)
	if u >= 1.0:
		return Transform3D.IDENTITY
	var row := climb_row(z)
	var open := float(row["open"]) / float(row["len"])
	if String(z.get("climb_way", "lid")) == "culvert":
		if u < open:
			return Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, LIFT, -CRAWL_BACK * (1.0 - smoothstep(0.0, open, u))))
		var up := smoothstep(open, 1.0, u)
		return Transform3D(Basis(Vector3.RIGHT, PI * 0.5 * (1.0 - up)), Vector3(0, LIFT * (1.0 - up), 0))
	if u < open:
		# Slow at first, then a hold on the rim.
		var reach := smoothstep(0.0, open * 0.7, u)
		return Transform3D(Basis(Vector3.RIGHT, HOLE_LEAN * 0.4 * reach), Vector3(0, lerpf(-HOLE_DEPTH, -HOLE_HANG, reach), 0))
	var heave := (u - open) / (1.0 - open)
	var lean := lerpf(HOLE_LEAN * 0.4, HOLE_LEAN, sin(minf(heave * 2.0, 1.0) * PI * 0.5)) if heave < 0.5 else lerpf(HOLE_LEAN, 0.0, smoothstep(0.5, 1.0, heave))
	return Transform3D(Basis(Vector3.RIGHT, lean), Vector3(0, -HOLE_HANG * (1.0 - smoothstep(0.0, 0.7, heave)), 0))
