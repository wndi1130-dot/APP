extends RefCounted
## The train turn between stops, ported from s1/src/game/turn.ts (the reference) for the S1a game:
## what a stretch costs in coal and food, the levers, how each car's situation moves its relation,
## and stepping on to the next stretch. States and tables as in train_state.gd.
## Functions that change the state take a state, copy it and hand the copy back; lines the S1 rule
## writes to the journal or the card pile are appended to the copy's "journal" and "cards" in the
## same words. tests/train/test_train_turn.gd checks them against the S1 answers.
##
## meters is checked at every sampled state; hungerTick and checkEnd against whole S1 settles (the
## fixture's "settle" cases, made before turn.ts exported them), as nothing later in an S1a settle
## touches what they read or write. Not here: the rest of settle, and depart and arriveStop, which
## draw events and places.

const St = preload("res://game/train/train_state.gd")
const CouncilMath = preload("res://game/politics/council_math.gd")
const TurnCommon = preload("res://game/train/turn/turn_common.gd")


static func heat_cost(g: Dictionary, t: Dictionary) -> float:
	var sum := 0.0
	for c: String in St.comms(t):
		var s: Dictionary = g["comms"][c]
		sum += (float(s["heat"]) * float(s["pop"])) / 40.0
	return sum * float(t["P"]["coalHeatPerLever"])


static func food_cost(g: Dictionary, t: Dictionary) -> float:
	var sum := 0.0
	for c: String in St.comms(t):
		var s: Dictionary = g["comms"][c]
		sum += float(s["pop"]) * float(s["ration"])
	return sum * float(t["P"]["foodPerPersonLever"])


## The tail refuses work: fervor 1 or more at relation -40 or worse.
static func tail_idle(g: Dictionary) -> bool:
	var tail: Dictionary = g["comms"]["tail"]
	return float(tail["fervor"]) >= 1.0 and float(tail["rel"]) <= -40.0


## Coal and food this stretch will cost, stops left out: {coal, food}. A stranded train burns none.
static func forecast(g: Dictionary, t: Dictionary) -> Dictionary:
	var p: Dictionary = t["P"]
	var run := float(p["coalStrike"]) if bool(g["inStrike"]) else float(p["coalRun"])
	var coal := heat_cost(g, t) * St.law_mult(g, t, "heatMult") + St.law_sum(g, t, "coalAdd") + St.calm_coal(g, t) + run \
		- (2.0 if bool(g["forcedRun"]) else 0.0) + (float(p["tailIdleCoal"]) if tail_idle(g) else 0.0) + St.loco_coal(g, t)
	var food := food_cost(g, t) + St.law_sum(g, t, "foodAdd")
	if g.has("nextCardUid") and g.get("hands") is Dictionary:
		coal += float(t["HANDS"]["stokerCoal"]) * float(g["hands"]["short"]["stoker"])
	return {"coal": 0.0 if g.get("stranded") != null else coal, "food": food}


static func seg_km_of(g: Dictionary, t: Dictionary, seg: int = -1) -> float:
	var at := int(g["seg"]) if seg < 0 else seg
	var route: Variant = g.get("route")
	if route is Array:
		for r: Variant in route:
			if int(r["seg"]) == at:
				return float(r["km"])
	return float(t["P"]["segKmDefault"])


## Where the coal runs out, in km from the last station, cut to 1 km short of the next.
static func stall_km(seg_km: float, coal_before: float, need: float) -> float:
	if need <= 0.0:
		return maxf(1.0, seg_km - 1.0)
	return minf(maxf(1.0, seg_km - 1.0), maxf(1.0, floorf(seg_km * maxf(0.0, coal_before) / need)))


## Whether the coal gives out on the way this stretch.
static func stalls_en_route(g: Dictionary, t: Dictionary) -> bool:
	if g.get("stranded") != null or bool(g["inStrike"]):
		return false
	return float(g["coal"]) - float(forecast(g, t)["coal"]) <= 0.0


## The warning before leaving: {atKm, toNextKm, segKm}, or null when the train will not stop.
static func predict_stall(g: Dictionary, t: Dictionary) -> Variant:
	if g.get("stranded") != null:
		return null
	var need := float(forecast(g, t)["coal"])
	if need <= 0.0 or float(g["coal"]) > need:
		return null
	var seg_km := seg_km_of(g, t)
	var at_km := stall_km(seg_km, float(g["coal"]), need)
	return {"atKm": at_km, "toNextKm": seg_km - at_km, "segKm": seg_km}


## One lever, held between the law floor and 4.
static func set_lever(g0: Dictionary, t: Dictionary, c: String, which: String, value: float) -> Dictionary:
	var g := g0.duplicate(true)
	var key := "heatFloor" if which == "heat" else "rationFloor"
	g["comms"][c][which] = int(St.clampv(CouncilMath.round_half_up(value), St.law_floor(g, t, key), 4.0))
	return g


## Who keeps the ration book: the front car in S1a (rationComm).
static func ration_comm(_g: Dictionary) -> String:
	return "front"


## Whether the levers can be handed to the ration keeper (autoLeverStatus; the reason line is the
## screen's and is not ported).
static func auto_lever_status(g: Dictionary, t: Dictionary) -> bool:
	var d: Dictionary = t["DELEGATE"]
	if int(g["seg"]) - 1 < int(d["after"]):
		return false
	var s: Dictionary = g["comms"][ration_comm(g)]
	var line := float(d["reOn"]) if not bool(g["autoLevers"]) and bool(g.get("autoDropped", false)) else float(d["on"])
	return not (float(s["rel"]) < line or float(s["grudge"]) > 0.0)


## The ration keeper moves the levers: {state, changes}. changes are S1's own lines.
static func auto_levers(g0: Dictionary, t: Dictionary) -> Dictionary:
	var g := g0.duplicate(true)
	var changes: Array[String] = []
	var hf := St.law_floor(g, t, "heatFloor")
	var rf := St.law_floor(g, t, "rationFloor")
	var coal := float(g["coal"])
	var food := float(g["food"])
	for c: String in St.comms(t):
		var s: Dictionary = g["comms"][c]
		var sit := St.situation(g, t, c)
		var w := sit[0]
		var r := sit[1]
		var name: String = t["COMM_NAME"][c]
		if w < 45.0 and coal > 50.0 and float(s["heat"]) < 4.0:
			s["heat"] = int(s["heat"]) + 1
			changes.append("%s 난방 +1" % name)
		if r < 45.0 and food > 50.0 and float(s["ration"]) < 4.0:
			s["ration"] = int(s["ration"]) + 1
			changes.append("%s 배급 +1" % name)
		if w > 65.0 and coal < 40.0 and float(s["heat"]) > maxf(1.0, hf):
			s["heat"] = int(s["heat"]) - 1
			changes.append("%s 난방 −1" % name)
		if r > 65.0 and food < 40.0 and float(s["ration"]) > maxf(1.0, rf):
			s["ration"] = int(s["ration"]) - 1
			changes.append("%s 배급 −1" % name)
	return {"state": g, "changes": changes}


static func _journal(g: Dictionary, text: String, tone: Variant = null) -> void:
	if not g.get("journal") is Array:
		g["journal"] = []
	var row: Dictionary = {"seg": g["seg"], "text": text}
	# Older train fixtures project absent tone to null; whole Game JSON omits it.
	if tone != null or not g.has("version"):
		row["tone"] = tone
	(g["journal"] as Array).append(row)


static func _card(g: Dictionary, card: Dictionary) -> void:
	if not g.get("cards") is Array:
		g["cards"] = []
	var row: Dictionary = card.duplicate(true)
	# Full states carry the card sequence; the original projection has no uid field.
	if g.has("nextCardUid"):
		row["uid"] = g["nextCardUid"]
		g["nextCardUid"] = int(g["nextCardUid"]) + 1
		for key: String in ["comm", "who", "text"]:
			if row.has(key) and row[key] == null: row.erase(key)
	(g["cards"] as Array).append(row)


static func _bump_rel(s: Dictionary, d: float) -> void:
	s["rel"] = St.clampv(float(s["rel"]) + d, -100.0, 100.0)


## Each car's situation moves its relation; fervor climbs after three bad stretches (drift).
static func drift(g0: Dictionary, t: Dictionary) -> Dictionary:
	var g := g0.duplicate(true)
	var p: Dictionary = t["P"]
	for c: String in St.comms(t):
		var s: Dictionary = g["comms"][c]
		var sit := St.situation(g, t, c)
		var w := sit[0]
		var r := sit[1]
		var cr := sit[2]
		var ex := sit[3]
		var dr := -(maxf(0.0, 45.0 - w) / 10.0) - maxf(0.0, 45.0 - r) / 10.0 - maxf(0.0, cr - 60.0) / 15.0 - maxf(0.0, ex - 50.0) / 15.0
		if dr == 0.0:
			var surplus := maxf(0.0, w - 45.0) + maxf(0.0, r - 45.0) + maxf(0.0, 60.0 - cr) + maxf(0.0, 50.0 - ex)
			dr = minf(float(p["recoverCap"]), float(p["recoverBase"]) + surplus / 30.0)
			dr = maxf(0.0, minf(dr, float(p["naturalCeiling"]) - float(s["rel"])))
		if float(g["food"]) <= 0.0:
			dr -= 5.0
		if c == "front" and float(g["lux"]) <= 0.0:
			dr -= 1.0
		if c == "tail" and float(s["rel"]) < float(p["backBelow"]) and float(s["heat"]) >= 2.0 and float(s["ration"]) >= 2.0:
			s["backStreak"] = int(s["backStreak"]) + 1
		elif c == "tail":
			s["backStreak"] = 0
		var back := c == "tail" and int(s["backStreak"]) >= int(p["backSegs"])
		if g.has("nextCardUid"): TurnCommon.bump_rel(g, c, St.clampv(dr, -6.0, float(p["recoverCap"])), "situation")
		else: _bump_rel(s, St.clampv(dr, -6.0, float(p["recoverCap"])))
		if back:
			if g.has("nextCardUid"): TurnCommon.bump_rel(g, c, float(p["backBonus"]), "back")
			else: _bump_rel(s, float(p["backBonus"]))
			if int(s["fervor"]) > 0:
				s["fervor"] = int(s["fervor"]) - 1
			s["badStreak"] = 0
		if float(s["rel"]) <= -40.0:
			s["badStreak"] = int(s["badStreak"]) + 1
			if int(s["badStreak"]) >= 3:
				s["fervor"] = mini(3, int(s["fervor"]) + 1)
				s["badStreak"] = 0
				_journal(g, "%s의 열기가 올랐다. %s이(가) 시작될 수 있다." % [t["COMM_NAME"][c], t["PROTEST"][c]], "bad")
		else:
			s["badStreak"] = 0
		if float(s["rel"]) >= 15.0 and int(s["fervor"]) > 0:
			s["fervor"] = int(s["fervor"]) - 1
	return g


## Trust and tension at settle (meters). Trust follows the seat-weighted relation; tension climbs
## with angry cars, cold or hungry cars, an empty larder, laws and the evening pot, and fear slows
## the climb unless the guard was ever let loose. The S1a game has no train broadcast, so its share
## is 0. The reason lines S1 keeps for the screen are not ported.
static func meters(g0: Dictionary, t: Dictionary) -> Dictionary:
	var g := g0.duplicate(true)
	var seat_map := St.seats(g, t)
	var avg := 0.0
	for c: String in St.comms(t):
		avg += float(g["comms"][c]["rel"]) * float(seat_map[c])
	avg /= 100.0
	if g.has("nextCardUid"): TurnCommon.bump(g, "trust", St.clampv(avg / 40.0, -2.5, 2.5), "mood")
	else: g["trust"] = St.clampv(float(g["trust"]) + St.clampv(avg / 40.0, -2.5, 2.5), 0.0, 100.0)
	var inc := 0.0
	for c: String in St.comms(t):
		var rel := float(g["comms"][c]["rel"])
		if rel <= -40.0:
			inc += 3.0 if c == "tail" else 2.0
		elif rel <= -15.0:
			inc += 1.0
		var sit := St.situation(g, t, c)
		if sit[0] <= 25.0 or sit[1] <= 25.0:
			inc += 2.0
	var mood_inc: float = inc
	var food_inc: float = 8.0 if float(g["food"]) <= 0.0 else 0.0
	inc += food_inc
	inc += St.law_sum(g, t, "tensionAdd") + St.calm_tension(g, t)
	g["fear"] = St.clampv(float(g["fear"]) + St.law_sum(g, t, "fearAdd"), 0.0, 100.0)
	if inc <= 0.0:
		if g.has("nextCardUid"): TurnCommon.bump(g, "tension", -2, "drift")
		else: g["tension"] = St.clampv(float(g["tension"]) - 2.0, 0.0, 100.0)
	else:
		var calmed := 1.0 if int(g.get("tensionCrisisUsed", 0)) > 0 else 1.0 - float(g["fear"]) / 200.0
		if g.has("nextCardUid"):
			var pot_t: float = float(t["CALM"]["potTension"]) if St.pot_running(g, t) else 0.0
			TurnCommon.bump_parts(g, "tension", maxf(0.0, inc) * calmed, [["mood", mood_inc], ["short", food_inc], ["law", St.law_sum(g, t, "tensionAdd")], ["calm.pot", pot_t], ["calm.ledger", St.calm_tension(g, t) - pot_t], ["cast", 0]])
		else: g["tension"] = St.clampv(float(g["tension"]) + maxf(0.0, inc) * calmed, 0.0, 100.0)
	g["fear"] = St.clampv(float(g["fear"]) - 1.0, 0.0, 100.0)
	return g


## The hunger count at settle (hungerTick): back to 0 while there is food, else one more stretch;
## the first empty stretch puts up a card. {state, notes, starves}: past the grace stretches
## somebody starves, and who is drawn by the S1 victim picker, which is not ported, so the copy
## only says that somebody does.
static func hunger_tick(g0: Dictionary, t: Dictionary) -> Dictionary:
	var g := g0.duplicate(true)
	var notes: Array[String] = []
	if float(g["food"]) > 0.0:
		g["hunger"] = 0
		return {"state": g, "notes": notes, "starves": false}
	g["hunger"] = int(g.get("hunger", 0)) + 1
	var grace := int(t["HUNGER_GRACE"])
	if int(g["hunger"]) == 1:
		_card(g, {"kind": "info", "comm": null, "who": "식량이 떨어졌다",
			"text": "사람들은 허리띠를 졸라매고 버틴다. %d구간을 넘기면 굶어 죽는 사람이 나온다." % grace})
		return {"state": g, "notes": notes, "starves": false}
	if int(g["hunger"]) <= grace:
		notes.append("굶은 지 %d구간째다." % int(g["hunger"]))
		return {"state": g, "notes": notes, "starves": false}
	return {"state": g, "notes": notes, "starves": true}


## The end checks at the close of settle (checkEnd): the trust crisis and its three stretches,
## the tension warning at 60 and the last chance at 100. An S1a game has no martial law.
## Ending writes the end and its first journal line; the look-back lines after it are not ported.
static func check_end(g0: Dictionary, t: Dictionary) -> Dictionary:
	var g := g0.duplicate(true)
	if float(g["food"]) < 0.0:
		g["food"] = 0
	var trust := float(g["trust"])
	var crisis: Variant = g.get("trustCrisis")
	if trust <= 0.0 and crisis == null:
		g["trustCrisis"] = int(g["seg"]) + 3
		_card(g, {"kind": "trust_crisis", "comm": null, "who": null, "text": null})
		_journal(g, "신임이 바닥났다. 3구간 안에 25까지 되돌려야 한다.", "bad")
	elif crisis != null:
		if trust >= 25.0:
			g["trustCrisis"] = null
			_journal(g, "불신임의 말이 잦아들었다.", "good")
		elif int(g["seg"]) >= int(crisis):
			return _finish(g, "ousted")
	var tension := float(g["tension"])
	if tension >= 60.0 and not bool(g.get("tensionWarned", false)):
		g["tensionWarned"] = true
		_card(g, {"kind": "info", "comm": null, "who": "긴장 경고",
			"text": "칸 사이 문마다 사람이 서 있다. 긴장이 100에 닿으면 마지막 기회가 온다."})
	if tension >= 100.0:
		if int(g.get("tensionCrisisUsed", 0)) < 2:
			_card(g, {"kind": "tension_crisis", "comm": "tail", "who": null, "text": null})
		else:
			return _finish(g, "revolt")
	return g


const END_TEXT := {
	"complete": "라이프치히 중앙역에 닿았다.", "stranded": "석탄이 다 떨어졌다. 열차가 섰다.",
	"ousted": "의회가 열차장을 끌어내렸다.", "revolt": "반란이 일어났다.",
}


static func _finish(g: Dictionary, end: String) -> Dictionary:
	if g["phase"] == "end":
		return g
	g["end"] = end
	g["phase"] = "end"
	_journal(g, END_TEXT[end], "good" if end == "complete" else "bad")
	return g


## The unrest/support band: {unrest, neutral, support, byComm: [{c, seats, side}]}.
static func standings(g: Dictionary, t: Dictionary) -> Dictionary:
	var seat_map := St.seats(g, t)
	var unrest := 0
	var neutral := 0
	var support := 0
	var by_comm: Array = []
	for c: String in St.comms(t):
		var rel := float(g["comms"][c]["rel"])
		var side := 1 if rel >= 15.0 else (-1 if rel <= -15.0 else 0)
		var n: int = seat_map[c]
		if side > 0:
			support += n
		elif side < 0:
			unrest += n
		else:
			neutral += n
		by_comm.append({"c": c, "seats": n, "side": side})
	return {"unrest": unrest, "neutral": neutral, "support": support, "byComm": by_comm}


static func rel_stage(g: Dictionary, t: Dictionary, c: String) -> String:
	return St.stage_of(float(g["comms"][c]["rel"]), t)["name"]


## Whether next_segment covers this state: the settle step of an S1a game, before the run-up to
## the hub, not stranded, and not the stretch an emergency term runs out (that ends in politics).
static func next_segment_covers(g: Dictionary, t: Dictionary) -> bool:
	var p: Dictionary = t["P"]
	return St.is_s1a(g) and g["phase"] == "settle" and g.get("stranded") == null \
		and int(g["seg"]) + 1 < int(p["segments"]) - 1 and int(g.get("decreeLeft", 0)) != 1 \
		and (g.get("cards", []) as Array).is_empty()


## From settle to the next stretch (nextSegment, reached by advance at settle).
static func next_segment(g0: Dictionary, t: Dictionary) -> Dictionary:
	assert(next_segment_covers(g0, t), "next_segment: state outside the ported case")
	var g := g0.duplicate(true)
	g["seg"] = int(g["seg"]) + 1
	g["lastStop"] = g.get("stop")
	g["stop"] = null
	if int(g.get("decreeLeft", 0)) > 0:
		g["decreeLeft"] = int(g["decreeLeft"]) - 1
	g["phase"] = "prep"
	var hf := St.law_floor(g, t, "heatFloor")
	var rf := St.law_floor(g, t, "rationFloor")
	for c: String in St.comms(t):
		var s: Dictionary = g["comms"][c]
		s["heat"] = maxf(float(s["heat"]), hf)
		s["ration"] = maxf(float(s["ration"]), rf)
	if bool(g["autoLevers"]) and not auto_lever_status(g, t):
		g["autoLevers"] = false
		g["autoDropped"] = true
		var rc: String = t["COMM_NAME"][ration_comm(g)]
		_card(g, {"kind": "info", "comm": null, "who": "배급장이 장부를 내려놓았다",
			"text": "%s의 지지가 떨어지자 배급장이 레버에서 손을 뗐다. 칸마다 레버를 다시 열차장이 잡는다." % rc})
	if bool(g["autoLevers"]):
		var moved := auto_levers(g, t)
		g = moved["state"]
		var changes: Array[String] = moved["changes"]
		if not changes.is_empty():
			_journal(g, "배급장이 레버를 움직였다: %s." % ", ".join(changes))
	for c: String in St.comms(t):
		var s: Dictionary = g["comms"][c]
		if c != "engine" and float(s["fervor"]) >= 1.0 and float(s["rel"]) <= -40.0:
			_journal(g, "%s: %s." % [t["COMM_NAME"][c], t["PROTEST"][c]], "bad")
	return g
