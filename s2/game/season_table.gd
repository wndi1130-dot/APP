extends RefCounted
## The one season table (코디네이터 10-25: S1 climate, the S2 train and the S2
## field and travel pictures read the same file). The master copy is
## s1/src/game/season_table.json; game/season_table.json is its copy
## (s1/tools/season_table_sync.ts writes it, an S1 test checks they match).
## Every number is a proposal. The prologue is the first leg, one row a
## stretch (segment); the acts after it run by progress 0..1.

const PATH := "res://game/season_table.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var text := FileAccess.get_file_as_string(PATH)
		var parsed = JSON.parse_string(text)
		_data = parsed if parsed is Dictionary else {}
	return _data


static func segments() -> int:
	return int(data().get("first_leg_segments", 24))


static func prologue() -> Array:
	return data().get("prologue", [])


## The prologue row of a stretch (1..segments; past the end, the last).
static func row(seg: int) -> Dictionary:
	var rows := prologue()
	if rows.is_empty():
		return {}
	return rows[clampi(seg, 1, rows.size()) - 1]


## How far into the prologue a stretch is (stretch 1 is 0, the last is 1).
static func seg_progress(seg: int) -> float:
	return clampf(float(seg - 1) / maxf(float(segments() - 1), 1.0), 0.0, 1.0)


## The stretch at a progress into the prologue, with the part of the way to the next.
static func seg_at(progress: float) -> float:
	return 1.0 + clampf(progress, 0.0, 1.0) * float(segments() - 1)


static func act(name: String) -> Dictionary:
	return data().get("acts", {}).get(name, {})


## Midday outside temperature in C: the prologue straight between its rows,
## an act straight between its first and last stop.
static func temp_at(act_name: String, progress: float) -> float:
	if act_name == "prologue" or act(act_name).is_empty():
		var s := seg_at(progress)
		var a := float(row(int(floor(s))).get("temp", 0.0))
		var b := float(row(int(floor(s)) + 1).get("temp", a))
		return lerpf(a, b, s - floor(s))
	var t: Array = act(act_name)["temp"]
	return lerpf(float(t[0]), float(t[1]), clampf(progress, 0.0, 1.0))


## Which side of midwinter (0 autumn, 1 spring). The prologue is autumn.
static func side_at(act_name: String) -> float:
	if act_name == "prologue" or act(act_name).is_empty():
		return 0.0
	return float(act(act_name).get("side", 0.0))


## The season state's name (seasons_regions.md 2.2) at this point.
static func season_at(act_name: String, progress: float) -> String:
	if act_name == "prologue" or act(act_name).is_empty():
		return String(row(int(round(seg_at(progress)))).get("season", "late_autumn"))
	var out := "deep_winter"
	for step in act(act_name).get("season", []):
		if clampf(progress, 0.0, 1.0) >= float(step[0]) - 0.00001:
			out = String(step[1])
	return out


## The season state of a stretch of the first leg (the train's view).
static func season_of_seg(seg: int) -> String:
	return String(row(seg).get("season", "late_autumn"))
