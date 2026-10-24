extends RefCounted
## Running noise score for one stop. Each entry: {t, level, tag, total}.

const SimNoise = preload("res://game/sim/noise.gd")

var total: int = 0
var history: Array = []
## Hearing observations do not add pressure. Footsteps aggregate without growing history.
var sound_events: int = 0
var sound_reactions: int = 0
var by_action: Dictionary = {}


func observe(level: int, tag: String, radius: float, reacted: int) -> void:
	var count := maxi(reacted, 0)
	sound_events += 1
	sound_reactions += count
	var row: Dictionary = by_action.get(tag, {"events": 0, "reactions": 0, "max_radius": 0.0, "linger": 0.0})
	row["events"] += 1
	row["reactions"] += count
	row["max_radius"] = maxf(float(row["max_radius"]), maxf(radius, 0.0))
	row["linger"] = maxf(float(row["linger"]), SimNoise.LINGER[SimNoise.clamp_level(level)])
	by_action[tag] = row


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
