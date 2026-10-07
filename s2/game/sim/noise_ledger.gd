extends RefCounted
## Running noise score for one stop. Each entry: {t, level, tag, total}.

const SimNoise = preload("res://game/sim/noise.gd")

var total: int = 0
var history: Array = []


## Adds one sound event; returns the points added.
func add(level: int, t: float, tag: String) -> int:
	var lv: int = SimNoise.clamp_level(level)
	var pts: int = SimNoise.score(lv)
	total += pts
	history.append({"t": t, "level": lv, "tag": tag, "total": total})
	return pts


## Points from events at or after t.
func score_since(t: float) -> int:
	var sum: int = 0
	for e: Dictionary in history:
		if float(e["t"]) >= t:
			sum += SimNoise.score(int(e["level"]))
	return sum
