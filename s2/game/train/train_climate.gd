extends RefCounted
## The outside temperature on the train (S1 s1/src/game/climate.ts, season.ts and the
## climate branch of omens.ts; decisions 351, 357, 370, 423): a board with `climate`
## on reads the season table's stage for each stretch. The stage's multiplier is on
## the heating coal (heat_cost), a change of stage when the train leaves moves every
## car's warmth by 5 a stage and replaces the regular winter drop, the stops' weather
## is drawn from the season's own shares, and the window and omen lines of a stretch
## with no lying snow or night frost, or with rain, are swapped (SNOW_SWAP,
## FROST_SWAP, RAIN_SWAP). The water tower and snow drift events ask the season.
##
## The numbers are S1's as the board's tables carry them (t.CL, t.SEASON_ROWS,
## t.FALLS, the swap tables); the seasons' weather shares are the season table's
## (season_table.gd, the same file as S1's). A board with climate off is untouched.
##
## The track freeze too (freezeDepart, climateSettle, freezeCoal/Food, the track
## events' boost): leaving a wet stop for a colder stage freezes the track for
## CL.freezeLen stretches — a coal more, half a day's food more, the water tower
## and the snow drift drawn twice as often — and it thaws at the settle's end.
##
## Not here yet: the disasters' cold snap one stage deeper (departStage's
## coldStep, and freezeDepart's coldStart: S2 has no disasters).

const C = preload("res://game/train/turn/turn_common.gd")
const SeasonTable = preload("res://game/season_table.gd")

## climate.ts LINES: [first person, third person].
const LINES: Dictionary = {
	"drop": ["날씨가 추워지고 있어…", "창에 성에가 다시 낀다……"],
	"deep": ["숨 쉬는 것도 아파…", "쇠붙이가 손에 들러붙는다……"],
	"ease": ["바람이 좀 누그러졌어…", "지붕의 눈이 녹아 흘러내린다……"],
	"freeze": ["바퀴가 자꾸 헛돌아…", "선로가 얼어붙고 있다……"],
	"thaw": ["이제 좀 굴러가네…", "바퀴 밑 얼음이 갈라진다……"],
}
## climate.ts TRACK_EVENTS: the track events a freeze draws more often.
const TRACK_EVENTS: Array[String] = ["water_tower", "snow_drift"]
## climate.ts WEATHER_TEMP's cold (the one a departure's line can add).
const COLD_TEMP: float = -12.0
## season.ts DRAWN: the five a stop's weather is drawn from, in this order.
const DRAWN: Array = ["snow", "fog", "sleet", "overcast", "clear"]


static func on(g: Dictionary) -> bool:
	return bool(g.get("climate", false))


## climate.ts stageAt: the stage of a departure from stretch `seg`.
static func stage_at(t: Dictionary, seg: int) -> int:
	var table: Array = t["CL"]["table"]
	var st: int = int(table[0][1])
	for row: Array in table:
		if seg >= int(row[0]):
			st = int(row[1])
	return st


## climate.ts segTemp: the midday temperature shown for stretch `seg`.
static func seg_temp(t: Dictionary, seg: int) -> float:
	var temps: Array = t["CL"]["segTemp"]
	return float(temps[clampi(seg, 1, temps.size()) - 1])


## climate.ts tempMult: what heat_cost is multiplied by; 1 with climate off.
static func temp_mult(g: Dictionary, t: Dictionary) -> float:
	if not on(g):
		return 1.0
	return float(t["CL"]["mult"][int(g.get("outside", 1))])


## climate.ts climateDepart: on leaving, a change of stage moves every car's
## warmth by ∓5 a stage, sets the stage in force and writes two lines. Returns
## {from, to}, or null with climate off. (departStage's cold snap needs disasters.)
static func depart(g: Dictionary, t: Dictionary) -> Variant:
	if not on(g):
		return null
	var cl: Dictionary = t["CL"]
	var seg: int = int(g["seg"])
	var from: int = int(g["outside"]) if g.get("outside") != null else stage_at(t, seg)
	var to: int = stage_at(t, seg)
	if to == from:
		return {"from": from, "to": to}
	var diff: int = to - from
	for c: String in t["COMMS"]:
		g["comms"][c]["base"][0] = float(g["comms"][c]["base"][0]) - float(cl["warmStep"]) * diff
	g["outside"] = to
	g["climateChange"] = {"seg": seg, "from": from, "to": to}
	if diff > 0:
		if not g.get("climateStats") is Dictionary:
			g["climateStats"] = {"drops": 0, "freezes": 0}
		g["climateStats"]["drops"] = int(g["climateStats"]["drops"]) + 1
	C.journal(g, _line(g, LINES["deep" if diff >= 2 else ("drop" if diff > 0 else "ease")]), "bad" if diff > 0 else "good")
	var warm: float = -float(cl["warmStep"]) * diff
	var temp: float = seg_temp(t, seg) + (COLD_TEMP if to > stage_at(t, seg) else 0.0)
	C.journal(g, "바깥 %s°. 모든 칸 온기 %s%s, 난방 석탄 ×%s." % [_js(temp).replace("-", "−"), "+" if warm > 0 else "−", _js(absf(warm)), _js(float(cl["mult"][to]))],
		"bad" if diff > 0 else "good")
	return {"from": from, "to": to}


## climate.ts freezeDepart (after the departure's stage, `shift` from depart):
## a colder stage left from a wet stop freezes the track — wet is sleet at the
## stop left, or the stage left being a wet one (late autumn, decision 370 3).
## No disasters in S2, so no cold snap starts one.
static func freeze_depart(g: Dictionary, t: Dictionary, shift: Variant) -> void:
	if not on(g) or not bool(t["CL"]["freezeOn"]) or not shift is Dictionary:
		return
	if int(shift["to"]) <= int(shift["from"]):
		return
	var last: Variant = g.get("lastStop")
	var sleet: bool = last is Dictionary and String((last as Dictionary).get("weather", "")) == "sleet"
	if not sleet and not bool(t["CL"]["wet"][int(shift["from"])]):
		return
	var cl: Dictionary = t["CL"]
	g["freeze"] = cl["freezeLen"]
	if not g.get("climateStats") is Dictionary:
		g["climateStats"] = {"drops": 0, "freezes": 0}
	g["climateStats"]["freezes"] = int(g["climateStats"]["freezes"]) + 1
	C.journal(g, _line(g, LINES["freeze"]), "bad")
	C.journal(g, "선로 결빙: 석탄 +%s, 식량 +반나절." % _js(float(cl["freezeCoal"])), "bad")


## climate.ts climateSettle (the settle's end): a frozen stretch goes by; the
## last one writes the thaw.
static func settle(g: Dictionary, t: Dictionary) -> void:
	if not on(g) or float(g.get("freeze", 0)) == 0.0:
		return
	g["freeze"] = float(g["freeze"]) - 1.0
	if float(g["freeze"]) <= 0.0:
		C.journal(g, _line(g, LINES["thaw"]), "good")


## climate.ts freezeCoal: the coal a frozen stretch costs more (0 otherwise).
static func freeze_coal(g: Dictionary, t: Dictionary) -> float:
	return float(t["CL"]["freezeCoal"]) if on(g) and float(g.get("freeze", 0)) > 0.0 else 0.0


## climate.ts freezeFood: the share more food_cost a frozen stretch takes (0 otherwise).
static func freeze_food(g: Dictionary, t: Dictionary) -> float:
	return float(t["CL"]["freezeFood"]) if on(g) and float(g.get("freeze", 0)) > 0.0 else 0.0


## climate.ts freezeTrackBoost: in a frozen stretch the track events already in
## the travel pool go in again (freezeTrack times in all).
static func track_boost(g: Dictionary, t: Dictionary, pool: Array) -> Array:
	if not on(g) or float(g.get("freeze", 0)) == 0.0:
		return pool
	var out: Array = pool.duplicate()
	for id: String in TRACK_EVENTS:
		if pool.has(id):
			for _i: int in range(1, int(t["CL"]["freezeTrack"])):
				out.append(id)
	return out


## climate.ts line: the other voice from the last line; the board's first by its seed.
static func _line(g: Dictionary, pair: Array) -> String:
	var voice: int = C.hash_text("%s|cl-voice" % g["seed"]) % 2 if not g.has("climateVoice") else 1 - int(g["climateVoice"])
	g["climateVoice"] = voice
	return String(pair[voice])


## A number as JS's String() writes it: no ".0" on a whole one.
static func _js(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, roundf(x)) else str(x)


## season.ts rowAt: the season table's row for stretch `seg` (as the board's tables carry it).
static func row_at(t: Dictionary, seg: int) -> Dictionary:
	var rows: Array = t["SEASON_ROWS"]
	return rows[clampi(seg, 1, rows.size()) - 1]


## omens.ts pickWeather's climate branch: the season's shares (season.ts
## weatherWeights), the falling weather by the stretch's temperature (fallsAt).
## Null with climate off (the old fixed shares stand).
static func weather(g: Dictionary, t: Dictionary) -> Variant:
	if not on(g):
		return null
	var seg: int = int(g["seg"])
	var shares: Dictionary = SeasonTable.data()["seasons"][String(row_at(t, seg)["season"])]["weather"]
	var total: int = 0
	for w: String in DRAWN:
		total += int(shares.get(w, 0))
	var x: int = C.hash_text("%s:w:%d" % [g["seed"], seg]) % total
	for w: String in DRAWN:
		var n: int = int(shares.get(w, 0))
		if x < n:
			return _falls(t, seg, w)
		x -= n
	return "snow"


static func _falls(t: Dictionary, seg: int, w: String) -> String:
	if w != "snow" and w != "sleet":
		return w
	return "snow" if float(row_at(t, seg)["temp"]) <= float(t["FALLS"]["snow_below"]) else "sleet"


## omens.ts seasonCond: which lines a stop's words swap to; null with climate off.
static func lines_cond(g: Dictionary, t: Dictionary, weather_id: String) -> Variant:
	if not on(g):
		return null
	var seg: int = int(g["seg"])
	var row: Dictionary = row_at(t, seg)
	var cold: bool = weather_id == "cold" or weather_id == "cold_front"
	return {"snow": bool(row["snow"]), "frost": bool(row["night_freeze"]) or cold,
		"rain": weather_id == "sleet" and float(row["temp"]) > float(t["FALLS"]["rain_above"])}


## omens.ts seasonLine over a pool of lines.
static func fit(t: Dictionary, pool: Array, cond: Variant) -> Array:
	if not cond is Dictionary:
		return pool
	var out: Array = []
	for line: String in pool:
		var s: String = line
		if bool(cond["rain"]):
			s = String(t["RAIN_SWAP"].get(s, s))
		if not bool(cond["frost"]):
			s = String(t["FROST_SWAP"].get(s, s))
		if not bool(cond["snow"]):
			s = String(t["SNOW_SWAP"].get(s, s))
		out.append(s)
	return out


## climate.ts seasonHolds: whether ice stands (frost), snow lies (snow), or
## neither (bare). Climate off: always winter.
static func holds(g: Dictionary, t: Dictionary, need: String) -> bool:
	if not on(g):
		return need != "bare"
	var row: Dictionary = row_at(t, int(g["seg"]))
	if need == "snow":
		return bool(row["snow"])
	var stop: Variant = g.get("stop") if g.get("stop") != null else g.get("lastStop")
	var w: String = String((stop as Dictionary).get("weather", "")) if stop is Dictionary else ""
	var frost: bool = bool(row["night_freeze"]) or w == "cold" or w == "cold_front" or float(g.get("freeze", 0)) > 0.0
	return (not frost and not bool(row["snow"])) if need == "bare" else frost
