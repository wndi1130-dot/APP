extends RefCounted
## How far down a dead body is drawn: it goes over when it is knocked down or
## killed, lies, and comes up again over the last part of its time on the
## ground. It only reads the rules' clocks (state, t, rise_t, age) and decides
## nothing: for the rules the body is down from the moment it is knocked down
## and up when its time runs out, as before. The lengths are rows in motion.gd.

const Motion = preload("res://game/sim/motion.gd")

const SIT: float = 0.55              # getting up: this far down when it has its hands under it
const LIFT: float = 0.18             # a body flat on the ground is drawn this much higher (its depth)


## Called as a standing body goes down (knocked down or killed): from here the
## fall is drawn. A body already on the ground, or one that crawls, has no fall.
static func mark_fall(z: Dictionary) -> void:
	if z["crawl"] or z["state"] in ["dead", "downed", "rising", "frozen", "waking"]:
		return
	z["fell_at"] = z["age"]


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
