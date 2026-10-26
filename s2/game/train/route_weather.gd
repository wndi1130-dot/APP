extends RefCounted
## Decision 474 N2: S1 route_weather.ts. No saved history or game RNG; follow only
## the needed earlier stretches of the 24-stretch route.

const SeasonTable = preload("res://game/season_table.gd")
const TrainStop = preload("res://game/train/train_stop.gd")
const STAY: int = 50


## t optionally carries the same season rows/falls as S1's configured tables.
## Without t, the scene's prologue uses the shared season table.
static func weather(seed: String, seg: int, t: Dictionary = {}) -> String:
	var rows: Array = t.get("SEASON_ROWS", SeasonTable.prologue())
	var row: Dictionary = rows[clampi(seg, 1, rows.size()) - 1]
	var falls: Dictionary = t.get("FALLS", SeasonTable.falls())
	var shares: Dictionary = SeasonTable.data()["seasons"][String(row["season"])]["weather"]
	var picked: String = ""
	if seg > 1 and TrainStop.hash_text("%s:ws:%d" % [seed, seg]) % 100 < STAY:
		var previous: String = weather(seed, seg - 1, t)
		if int(shares.get(previous, 0)) > 0:
			picked = previous
	if picked == "":
		var total: int = 0
		for kind: String in SeasonTable.DRAWN:
			total += int(shares.get(kind, 0))
		var x: int = TrainStop.hash_text("%s:w:%d" % [seed, seg]) % total
		picked = "snow"
		for kind: String in SeasonTable.DRAWN:
			var weight: int = int(shares.get(kind, 0))
			if x < weight:
				picked = kind
				break
			x -= weight
	if picked == "snow" or picked == "sleet":
		return "snow" if float(row["temp"]) <= float(falls["snow_below"]) else "sleet"
	return picked
