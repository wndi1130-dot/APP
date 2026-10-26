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


## Whether the night freezes at this point: the prologue stretch's night_freeze,
## an act's.
static func night_freeze_at(act_name: String, progress: float) -> bool:
	if act_name == "prologue" or act(act_name).is_empty():
		return bool(row(int(round(seg_at(progress)))).get("night_freeze", false))
	return bool(act(act_name).get("night_freeze", true))


## The night air (2026-10-25 user answer: the rules follow the pictures' curve,
## held to the table's night frost at zero). Full night is colder than midday by
## NIGHT_DROP_CLEAR under a clear sky, NIGHT_DROP otherwise; a stretch without
## night frost stays at NO_FROST_FLOOR or above, one with it gets to FROST_CEIL
## or below. dark: 0 day .. 1 full night. frost: 1 freezes, 0 does not, -1 not
## known (an air or a cold given outright): no bounds. Proposals.
const NIGHT_DROP_CLEAR := 5.0
const NIGHT_DROP := 2.5
const NO_FROST_FLOOR := 0.5
const FROST_CEIL := -1.0


static func night_air(midday: float, dark: float, clear: bool, frost: int) -> float:
	var night := midday - (NIGHT_DROP_CLEAR if clear else NIGHT_DROP)
	if frost == 0:
		night = maxf(night, minf(midday, NO_FROST_FLOOR))
	elif frost == 1:
		night = minf(night, FROST_CEIL)
	return lerpf(midday, night, clampf(dark, 0.0, 1.0))


## The season state of a stretch of the first leg (the train's view).
static func season_of_seg(seg: int) -> String:
	return String(row(seg).get("season", "late_autumn"))


## What falls is the temperature's (결정 423): above rain_above rain, at or
## below snow_below snow, between sleet. fx/atmosphere.gd draws by the same two.
static func falls() -> Dictionary:
	return data().get("falls", {"rain_above": 1.5, "snow_below": -2.0})


## The weathers a plain stop draws, in S1's order (s1/src/game/season.ts DRAWN):
## a blizzard comes only as a storm (S1's disaster), never from this draw.
const DRAWN: Array = ["snow", "fog", "sleet", "overcast", "clear"]


## A season state's weather weights, in DRAWN's order.
static func weights(season: String) -> Array:
	var w: Dictionary = data().get("seasons", {}).get(season, {}).get("weather", {})
	var out: Array = []
	for k in DRAWN:
		out.append(float(w.get(k, 0.0)))
	return out


## S1's string hash (omens.ts hash, FNV-1a 32 bit), so a stop drawn here from
## S1's key falls the same way S1 drew it.
static func hash32(s: String) -> int:
	var x := 2166136261
	for i in s.length():
		x = ((x ^ s.unicode_at(i)) * 16777619) & 0xFFFFFFFF
	return x


## A plain stop's weather from the table: the season's weights, then what falls
## by the midday temperature. seed and seg make S1's key ("<seed>:w:<seg>") on
## the prologue; an act's stop keys by its progress. Returns "weather" (S1's
## name: snow, fog, sleet, overcast, clear; rain stays "sleet" as in S1),
## "falls" (rain, sleet, snow or none), "temp" and "look" (the picture's kinds:
## fx/atmosphere.gd turns sleet into rain by the same temperature).
static func pick_weather(act_name: String, progress: float, stop_seed: String) -> Dictionary:
	var prologue_stop := act_name == "prologue" or act(act_name).is_empty()
	var seg := int(round(seg_at(progress)))
	var picked := "snow"
	if prologue_stop:
		# Decision 474 N2. Load at the call to avoid a preload cycle: the flow reads this table.
		picked = load("res://game/train/route_weather.gd").weather(stop_seed, seg)
	else:
		var key := "%s:w:%s:%d" % [stop_seed, act_name, int(round(clampf(progress, 0.0, 1.0) * 100.0))]
		var w := weights(season_at(act_name, progress))
		var total := 0
		for v in w:
			total += int(v)
		if total > 0:
			var x := hash32(key) % total
			for i in DRAWN.size():
				if x < int(w[i]):
					picked = String(DRAWN[i])
					break
				x -= int(w[i])
	var temp := float(row(seg).get("temp", 0.0)) if prologue_stop else temp_at(act_name, progress)
	var f := falls()
	var falling := "none"
	if picked == "snow" or picked == "sleet":
		picked = "snow" if temp <= float(f["snow_below"]) else "sleet"
		falling = "snow" if picked == "snow" else ("rain" if temp > float(f["rain_above"]) else "sleet")
	return {"weather": picked, "falls": falling, "temp": temp, "look": [picked], "rules": rules_kinds(picked, falling)}


## The field rules' kinds (sim/weather.gd ROWS) for a drawn weather: overcast
## has no row (it changes nothing), rain is its own row (no ice underfoot).
static func rules_kinds(weather: String, falling: String) -> Array:
	if weather == "overcast":
		return []
	if falling == "rain":
		return ["rain"]
	return [weather]
