extends RefCounted
## S1a council stance, blocs and one non-decree vote. The field slice's two motions and every
## S1a law but 비상대권 are accepted, enacted or repealed (결정 426 PR 7: S1a laws are LAW_IDS less
## S1C_LAWS and FAREWELL_LAWS; emergency_powers, ratifying and deals are not ported yet, and no
## S1a law has a variant to amend to). tests/train/test_law_port.gd checks them against S1.

const CouncilMath = preload("res://game/politics/council_math.gd")
const VoteCount = preload("res://game/politics/vote_count.gd")
const CouncilAgenda = preload("res://game/politics/council_agenda.gd")
const St = preload("res://game/train/train_state.gd")
const RationCut = preload("res://game/train/turn/turn_ration_cut.gd")
const Stop = preload("res://game/train/train_stop.gd")
const CouncilLog = preload("res://game/politics/council_log.gd")

const LEDGER_MAX := 64
const SUPPORTED_LAWS := [
	"common_kitchen", "contribution_ration", "seed_grain", "common_heating", "heat_quota", "snow_duty",
	"child_labor", "corpse_throw", "corpse_store", "corpse_burn", "treat_all", "triage", "no_outsiders",
	"patrol", "secret_ballot", "strike_ban", "guided_voting", "evening_pot", "wall_ledger",
	"night_of_names", "emergency_ration",
]
const CHILD_LAWS := ["child_labor", "child_pack"]
const SUPPORTED_MOTIONS := ["field_symbol", "field_promise"]


static func _clamp(value: float, lo: float, hi: float) -> float:
	return maxf(lo, minf(hi, value))


static func _journal(g: Dictionary, text: String, tone: Variant = null) -> void:
	var row := {"seg": g["seg"], "text": text}
	if tone != null:
		row["tone"] = tone
	(g["journal"] as Array).append(row)


static func _note(g: Dictionary, key: String, delta: float, why: String) -> void:
	if delta == 0.0:
		return
	if not g.get("ledger") is Array:
		g["ledger"] = []
	var rows: Array = g["ledger"]
	rows.append({"k": key, "d": delta, "why": why})
	while rows.size() > LEDGER_MAX:
		rows.pop_front()


static func _bump(g: Dictionary, key: String, delta: float, why: String) -> void:
	var before := float(g[key])
	var value := before + delta
	if key == "trust" or key == "tension":
		value = _clamp(value, 0.0, 100.0)
	g[key] = value
	_note(g, key, value - before, why)


static func _bump_rel(g: Dictionary, comm: String, delta: float, why: String) -> void:
	var state: Dictionary = g["comms"][comm]
	var before := float(state["rel"])
	state["rel"] = _clamp(before + delta, -100.0, 100.0)
	_note(g, "rel:%s" % comm, float(state["rel"]) - before, why)


static func _law_active(g: Dictionary, law: String) -> bool:
	return (g.get("passed", {}) as Dictionary).has(law)


static func _is_law(agenda: Dictionary) -> bool:
	return agenda.get("kind") != "motion"


static func _assert_supported(agenda: Dictionary) -> void:
	if _is_law(agenda):
		assert(SUPPORTED_LAWS.has(agenda.get("law")), "지원하지 않는 법 안건: %s" % agenda.get("law"))
		assert(not bool(agenda.get("ratify", false)) and not agenda.has("amend"), "추인·개정 안건은 아직 옮기지 않았다")
	else:
		assert(SUPPORTED_MOTIONS.has(agenda.get("motion")), "지원하지 않는 동의 안건: %s" % agenda.get("motion"))


static func _motion_lean(t: Dictionary, comm: String, agenda: Dictionary) -> Dictionary:
	var amount := 0.0
	if agenda["motion"] == "field_symbol":
		amount = float(t["FIELD"]["symbolLean"])
	elif agenda.get("verdict") == "kept":
		amount = float(t["FIELD"]["promiseLean"])
	else:
		amount = float(t["FIELD"]["pressLean"])
	return {"mat": amount if comm == agenda.get("subject") else 0.0, "ideo": 0.0}


static func stance(g: Dictionary, t: Dictionary, comm: String, agenda: Dictionary, with_grudge: bool = true) -> Dictionary:
	# Reading a law's stance is table-driven; action support is checked by cast_vote.
	var mat := 0.0
	var ideology := 0.0
	if not _is_law(agenda):
		var lean := _motion_lean(t, comm, agenda)
		mat = float(lean["mat"])
		ideology = float(lean["ideo"])
	else:
		var law: Dictionary = t["LAWS"][agenda["law"]]
		mat = float((law.get("like", {}) as Dictionary).get(comm, 0))
		var mats: Variant = (law.get("mats", {}) as Dictionary).get(comm)
		if mats is Array:
			var gain := float(mats[0]) + float(mats[1]) - float(mats[2]) - float(mats[3])
			mat += 2.0 if gain >= 15.0 else (1.0 if gain >= 5.0 else (-2.0 if gain <= -15.0 else (-1.0 if gain <= -5.0 else 0.0)))
		var relation: Variant = (law.get("rels", {}) as Dictionary).get(comm)
		if relation != null:
			var rel := float(relation)
			mat += -2.0 if rel <= -15.0 else (-1.0 if rel < 0.0 else (1.0 if rel >= 10.0 else 0.0))
		var axes: Array = law["axes"]
		var own: Array = t["IDEO"][comm]
		for i: int in axes.size():
			ideology += float(axes[i]) * float(own[i])
		if bool(agenda.get("repeal", false)):
			mat = -mat
			ideology = -ideology
	var state: Dictionary = g["comms"][comm]
	if state.get("sick") != null:
		var sign := -1.0 if mat < 0.0 else (1.0 if mat > 0.0 else 0.0)
		mat = sign * CouncilMath.round_half_up(absf(mat) * 1.5)
	var score := mat + ideology + float(CouncilMath.stage_of(float(state["rel"]), t["STAGES"])["band"])
	var grudge := int(state["grudge"])
	if with_grudge and grudge >= int(t["P"]["hostileGrudge"]):
		score = maxf(score, 3.0) if agenda.has("by") else minf(score, -3.0)
	elif with_grudge and grudge >= 1 and not agenda.has("by"):
		score -= 1.0
	return {"score": int(score), "ideo": int(ideology), "mat": int(mat)}


static func _hard_share(g: Dictionary, t: Dictionary, comm: String, ideology: int) -> float:
	var state: Dictionary = g["comms"][comm]
	var band := int(CouncilMath.stage_of(float(state["rel"]), t["STAGES"])["band"])
	var p: Dictionary = t["P"]
	var share := float(p["hardNoBase"]) + float(p["hardNoIdeo"]) * maxf(0.0, -ideology)
	if band < 0:
		share += float(p["hardNoCold"])
	elif band > 0:
		share -= float(p["hardNoWarm"])
	if int(state["grudge"]) >= 1:
		share += float(p["hardNoGrudge"])
	return _clamp(share, float(p["hardNoMin"]), float(p["hardNoMax"]))


static func _mourners(g: Dictionary, comm: String) -> int:
	var count := 0
	for row: Dictionary in g.get("mourning", []):
		if int(row["until"]) >= int(g["seg"]) and row["comm"] == comm:
			count += 1
	return count


static func _base_bloc(g: Dictionary, t: Dictionary, comm: String, agenda: Dictionary, seat_count: int) -> Dictionary:
	var opinion := stance(g, t, comm, agenda)
	var state: Dictionary = g["comms"][comm]
	var away := int(state["away"]) + _mourners(g, comm)
	var absent := mini(seat_count, CouncilMath.round_half_up(float(seat_count * away) / float(state["pop"]))) if int(state["pop"]) > 0 else 0
	var present := seat_count - absent
	var shares := CouncilMath.split(int(opinion["score"]))
	var yes := CouncilMath.round_half_up(present * float(shares[0]))
	var no := CouncilMath.round_half_up(present * float(shares[2]))
	var hard := mini(no, CouncilMath.round_half_up(present * _hard_share(g, t, comm, int(opinion["ideo"]))))
	return {
		"seats": seat_count, "absent": absent, "yes": yes, "und": present - yes - no,
		"no": no, "hard": hard, "pool": 0, "poolChance": 0.0,
		"score": opinion["score"], "ideo": opinion["ideo"],
	}


static func _seats(g: Dictionary, t: Dictionary) -> Dictionary:
	var pops: Array = []
	for comm: String in t["COMMS"]:
		pops.append(int(g["comms"][comm]["pop"]))
	var counts := CouncilMath.seats(pops)
	var out := {}
	for i: int in (t["COMMS"] as Array).size():
		out[t["COMMS"][i]] = counts[i]
	return out


static func _shift(bloc: Dictionary, amount: float) -> Dictionary:
	var out := bloc.duplicate()
	var left := absi(CouncilMath.round_half_up(amount))
	var sources: Array = ["no", "und"] if amount > 0.0 else ["yes", "und"]
	for key: String in sources:
		var room := int(out["no"]) - int(out["hard"]) if key == "no" else int(out[key])
		var take := mini(left, room)
		out[key] = int(out[key]) - take
		if amount > 0.0:
			out["yes"] = int(out["yes"]) + take
		else:
			out["no"] = int(out["no"]) + take
		left -= take
	return out


static func blocs(g: Dictionary, t: Dictionary, agenda: Dictionary, deals: Array = []) -> Dictionary:
	_assert_supported(agenda)
	var seat_map := _seats(g, t)
	var out := {}
	for comm: String in t["COMMS"]:
		var bloc := _base_bloc(g, t, comm, agenda, int(seat_map[comm]))
		if _law_active(g, "guided_voting") and int(g.get("guidedLeft", 0)) > 0:
			var moved := CouncilMath.round_half_up(int(bloc["und"]) * 0.3)
			bloc["yes"] = int(bloc["yes"]) + moved
			bloc["und"] = int(bloc["und"]) - moved
		for deal: Dictionary in deals:
			if deal["comm"] == comm and deal_holds(deal):
				_apply_deal(g, t, bloc, comm, str(deal["tool"]))
		for row: Dictionary in g.get("voteShift", []):
			if row["comm"] == comm:
				var side := 1.0 if row["side"] == "yes" or (row["side"] == "captain" and not agenda.has("by")) else (-1.0 if row["side"] == "no" else 0.0)
				bloc = _shift(bloc, float(row["n"]) * side)
		out[comm] = bloc
	return out


## S1 dealHolds: a refused deal took the seat but moves no votes.
static func deal_holds(deal: Dictionary) -> bool:
	return not bool(deal.get("refused", false)) and deal.get("label") != "뇌물을 거절당함"


## S1 applyDeal. No deal moves the hard no; open and persuasion turn minds
## (the undecided and part of the soft no), blackmail has the leader bring the
## bloc, bribes and debts pool the votes the leader brings at the bloc's cohesion.
static func _apply_deal(g: Dictionary, t: Dictionary, bloc: Dictionary, comm: String, tool: String) -> void:
	var soft := int(bloc["no"]) - int(bloc["hard"])
	if tool == "open" or tool == "fetch" or tool == "persuade":
		var share := 0.2 if tool != "persuade" else float(t["P"]["persuadeSoft"])
		var moved := CouncilMath.round_half_up(soft * share)
		bloc["yes"] = int(bloc["yes"]) + int(bloc["und"]) + moved
		bloc["no"] = int(bloc["no"]) - moved
		bloc["und"] = 0
	elif tool == "blackmail":
		bloc["yes"] = int(bloc["yes"]) + int(bloc["und"]) + soft
		bloc["und"] = 0
		bloc["no"] = bloc["hard"]
	else:
		bloc["pool"] = int(bloc["pool"]) + int(bloc["und"]) + soft
		bloc["poolChance"] = g["comms"][comm]["coh"]
		bloc["und"] = 0
		bloc["no"] = bloc["hard"]


static func expected(map: Dictionary, t: Dictionary) -> Dictionary:
	var mean := 0.0
	var minimum := 0
	var maximum := 0
	for comm: String in t["COMMS"]:
		var bloc: Dictionary = map[comm]
		mean += int(bloc["yes"]) + int(bloc["und"]) * CouncilMath.undecided_chance(int(bloc["score"])) + int(bloc["pool"]) * float(bloc["poolChance"])
		minimum += int(bloc["yes"])
		maximum += int(bloc["yes"]) + int(bloc["und"]) + int(bloc["pool"])
	return {"mean": mean, "min": minimum, "max": maximum}


static func agenda_need(t: Dictionary, agenda: Dictionary) -> int:
	_assert_supported(agenda)
	if not _is_law(agenda):
		return 51
	return 67 if t["LAWS"][agenda["law"]]["kind"] == "rule" else 51


static func agenda_title(t: Dictionary, agenda: Dictionary) -> String:
	# A table-driven title is also needed for AI proposals outside executable votes.
	if not _is_law(agenda):
		var name: String = String(t["COMM_NAME"].get(agenda.get("subject"), "그 칸"))
		if agenda["motion"] == "field_symbol":
			return "%s의 상징물을 열차 앞에 세우기" % name
		return "%s과(와)의 약속을 지킨 것을 기록에 올리기" % name if agenda.get("verdict") == "kept" else "%s과(와)의 약속 어김 추궁" % name
	return "%s%s" % [t["LAWS"][agenda["law"]]["title"], " 폐지" if bool(agenda.get("repeal", false)) else ""]


static func _offend(g: Dictionary, comm: String) -> void:
	var state: Dictionary = g["comms"][comm]
	state["grudge"] = mini(3, int(state["grudge"]) + 1)
	state["lastOffense"] = g["session"]


static func _sign(value: float) -> String:
	var shown: Variant = int(value) if value == floorf(value) else value
	return "+%s" % shown if value >= 0.0 else "−%s" % absf(value)


static func _motion_effect(g: Dictionary, t: Dictionary, agenda: Dictionary, passed: bool) -> void:
	var comm: Variant = agenda.get("subject")
	if comm == null:
		return
	var name: String = t["COMM_NAME"][comm]
	if agenda["motion"] == "field_symbol":
		var delta := float(t["FIELD"]["symbolRel"])
		if delta != 0.0:
			_bump_rel(g, comm, delta if passed else -delta, "symbol")
		if passed:
			_journal(g, "%s의 상징물이 열차 앞에 섰다." % name, "good")
		else:
			_journal(g, "%s의 상징물은 세우지 않기로 했다. 그 칸 사람들이 말을 아낀다." % name, "bad")
		return
	var verdict: String = agenda.get("verdict", "")
	var trust_delta := float(t["FIELD"]["promiseTrust"])
	var rel_delta := float(t["FIELD"]["promiseRel"])
	if passed:
		if verdict == "kept":
			if trust_delta != 0.0:
				_bump(g, "trust", trust_delta, "promise")
			_journal(g, "%s과(와)의 약속을 지킨 일이 기록에 올랐다." % name, "good")
		else:
			if trust_delta != 0.0:
				_bump(g, "trust", -trust_delta, "promise")
			if rel_delta != 0.0:
				_bump_rel(g, comm, rel_delta, "promise")
			_journal(g, "의회가 %s의 추궁을 받아들였다. 열차장이 약속을 어긴 것이 기록에 남는다." % name, "bad")
	elif verdict != "kept":
		if rel_delta != 0.0:
			_bump_rel(g, comm, -rel_delta, "promise")
		_journal(g, "%s의 추궁이 부결됐다. 그 칸은 들어 주지 않았다고 기억한다." % name, "bad")


## S1 addCard.
static func _add_card(g: Dictionary, value: Dictionary) -> void:
	var row: Dictionary = {"uid": g["nextCardUid"]}
	row.merge(value)
	g["nextCardUid"] = int(g["nextCardUid"]) + 1
	(g["cards"] as Array).append(row)


## S1 classroom enactScale (결정 205): child work set while a lesson stands
## takes its one-time cost at half, and remembers so its repeal takes back half.
static func _enact_scale(g: Dictionary, t: Dictionary, law: String) -> float:
	if not CHILD_LAWS.has(law):
		return 1.0
	var lesson := false
	for edu: String in t["EDU_LAWS"]:
		lesson = lesson or _law_active(g, edu)
	if not lesson:
		return 1.0
	if not g.get("edu") is Dictionary:
		g["edu"] = {"segs": 0, "early": 0, "hands": 0}
	if not g["edu"].get("halfMat") is Dictionary:
		g["edu"]["halfMat"] = {}
	g["edu"]["halfMat"][law] = true
	return 0.5


## S1 classroom repealScale.
static func _repeal_scale(g: Dictionary, law: String) -> float:
	var edu: Variant = g.get("edu")
	if not edu is Dictionary or not edu.get("halfMat") is Dictionary or not edu["halfMat"].get(law, false):
		return 1.0
	edu["halfMat"].erase(law)
	return 0.5


static func _calm(g: Dictionary) -> Dictionary:
	if not g.get("calm") is Dictionary:
		g["calm"] = {}
	return g["calm"]


## S1 calmEnact: the evening pot, the wall ledger and the night of names start from now.
static func _calm_enact(g: Dictionary, t: Dictionary, law: String) -> void:
	if law == "evening_pot":
		var c := _calm(g)
		c["potOn"] = float(g["coal"]) > float(t["CALM"]["potOffCoal"])
		c["potSegs"] = 0
	elif law == "wall_ledger":
		var c := _calm(g)
		c["ledger"] = St.ledger_level(g, t)
		c["ledgerSegs"] = 0
	elif law == "night_of_names":
		_calm(g)["nightSeg"] = int(g["seg"]) - 1


## S1 calmRepeal: wiping the wall ledger costs trust once.
static func _calm_repeal(g: Dictionary, t: Dictionary, law: String) -> void:
	if law == "wall_ledger":
		_bump(g, "trust", float(t["CALM"]["repealTrust"]), "calm.ledger")
		_journal(g, "벽 장부를 지웠다. 숨기는 것이 있다는 말이 돈다.", "bad")
	elif law == "evening_pot" and g.get("calm") is Dictionary:
		g["calm"].erase("potOn")


static func _enact_law_mut(g: Dictionary, t: Dictionary, law: String, bought_from: Array) -> void:
	assert(SUPPORTED_LAWS.has(law), "지원하지 않는 법: %s" % law)
	var definition: Dictionary = t["LAWS"][law]
	var base: Variant = t["LAW_VARIANT_OF"].get(law)
	if not g.get("boughtBy") is Dictionary:
		g["boughtBy"] = {}
	var carried: Variant = null
	if base != null and (g["passed"] as Dictionary).has(base):
		(g["passed"] as Dictionary).erase(base)
		# A variant over a law bought with promises carries the deal: turning it within three sessions is betrayal too.
		carried = g["boughtBy"].get(base)
		g["boughtBy"].erase(base)
		g["repealedAt"][base] = g["session"]
		var old: Dictionary = t["LAWS"][base]
		var base_scale := _repeal_scale(g, base)
		for comm: String in t["COMMS"]:
			var mats: Variant = (old.get("mats", {}) as Dictionary).get(comm)
			if mats is Array:
				for i: int in 4:
					g["comms"][comm]["base"][i] = float(g["comms"][comm]["base"][i]) - float(mats[i]) * base_scale
		_journal(g, "%s을(를) %s(으)로 고쳤다." % [old["title"], definition["title"]])
	g["passed"][law] = g["session"]
	if not bought_from.is_empty():
		var comms: Array = (carried["comms"] as Array).duplicate() if carried is Dictionary else []
		for comm: String in bought_from:
			if not comms.has(comm): comms.append(comm)
		g["boughtBy"][law] = {"comms": comms, "session": g["session"]}
	elif carried != null:
		g["boughtBy"][law] = carried
	var scale := _enact_scale(g, t, law)
	for comm: String in t["COMMS"]:
		var mats: Variant = (definition.get("mats", {}) as Dictionary).get(comm)
		if mats is Array:
			for i: int in 4:
				g["comms"][comm]["base"][i] = float(g["comms"][comm]["base"][i]) + float(mats[i]) * scale
		var relation: Variant = (definition.get("rels", {}) as Dictionary).get(comm)
		if relation != null:
			_bump_rel(g, comm, float(relation) * scale, "vote")
	if not g.get("onceTaken") is Array:
		g["onceTaken"] = []
	var once: String = base if base != null else law
	if not (g["onceTaken"] as Array).has(once):
		var res: Dictionary = definition.get("res", {})
		if float(res.get("trustOnce", 0)) != 0.0:
			_bump(g, "trust", float(res["trustOnce"]), "vote")
		if float(res.get("fearOnce", 0)) != 0.0:
			g["fear"] = _clamp(float(g["fear"]) + float(res["fearOnce"]) * scale, 0.0, 100.0)
		if float(res.get("foodOnce", 0)) != 0.0:
			_bump(g, "food", float(res["foodOnce"]), "vote")
		if float(res.get("trustOnce", 0)) != 0.0 or float(res.get("fearOnce", 0)) != 0.0 or float(res.get("foodOnce", 0)) != 0.0:
			(g["onceTaken"] as Array).append(once)
	_calm_enact(g, t, law)
	# 비상식량감축법이 서면 꼬리칸이 요구를 낸다(결정 091·430, turn_ration_cut.gd).
	if law == "emergency_ration":
		_add_card(g, {"kind": "ration_cut", "comm": "tail"})
	if law == "guided_voting":
		g["guidedLeft"] = 3
	if (t["CORPSE_LAWS"] as Array).has(law):
		g["corpseIssue"] = false
	g["stats"]["lawsPassed"] = int(g["stats"]["lawsPassed"]) + 1


static func enact_law(g0: Dictionary, t: Dictionary, law: String, bought_from: Array = []) -> Dictionary:
	var g := g0.duplicate(true)
	_enact_law_mut(g, t, law, bought_from)
	return g


## S1 repealLaw: the law's cost comes back off the cars, the cars that wanted it
## (stance 3 or more) take it badly, and a law bought with a promise and turned
## over within three sessions is remembered as betrayal.
static func _repeal_law_mut(g: Dictionary, t: Dictionary, law: String) -> void:
	assert(SUPPORTED_LAWS.has(law), "지원하지 않는 법: %s" % law)
	var definition: Dictionary = t["LAWS"][law]
	var supporters: Array[String] = []
	for comm: String in t["COMMS"]:
		if int(stance(g, t, comm, {"law": law, "repeal": false}, false)["score"]) >= 3:
			supporters.append(comm)
	(g["passed"] as Dictionary).erase(law)
	g["repealedAt"][law] = g["session"]
	var scale := _repeal_scale(g, law)
	for comm: String in t["COMMS"]:
		var mats: Variant = (definition.get("mats", {}) as Dictionary).get(comm)
		if mats is Array:
			for i: int in 4:
				g["comms"][comm]["base"][i] = float(g["comms"][comm]["base"][i]) - float(mats[i]) * scale
	for comm: String in supporters:
		_bump_rel(g, comm, -float(t["P"]["repealRel"]), "vote")
	var bought: Variant = null
	if g.get("boughtBy") is Dictionary:
		bought = g["boughtBy"].get(law)
		g["boughtBy"].erase(law)
	if bought is Dictionary and int(g["session"]) - int(bought["session"]) <= 3:
		var names: Array[String] = []
		for comm: String in bought["comms"]:
			_offend(g, comm)
			names.append(String(t["COMM_NAME"][comm]))
		_journal(g, "약속으로 통과시킨 %s을(를) 뒤집었다. %s이(가) 배신으로 기억한다." % [definition["title"], ", ".join(names)], "bad")
	if (t["CORPSE_LAWS"] as Array).has(law):
		g["corpseIssue"] = true
	_calm_repeal(g, t, law)
	if law == "guided_voting":
		g["guidedLeft"] = 0
	if law == "emergency_ration":
		RationCut.revert(g)
	g["stats"]["repeals"] = int(g["stats"]["repeals"]) + 1


static func repeal_law(g0: Dictionary, t: Dictionary, law: String) -> Dictionary:
	var g := g0.duplicate(true)
	_repeal_law_mut(g, t, law)
	return g


# ---- deals (S1 politics.ts 거래; persuasion 결정 433) ----

const CRISIS_WORD := {"coal": "석탄 바닥", "food": "식량 바닥", "corpse": "쌓인 시신", "med": "떨어진 약"}
const DIGIT_FINAL := {"0": "final", "1": "rieul", "2": "none", "3": "final", "4": "none", "5": "none", "6": "final", "7": "rieul", "8": "rieul", "9": "none"}


## S1 josa: the half of a pair like 을/를 that fits the word's last sound.
static func _josa(word: String, pair: String) -> String:
	var halves := pair.split("/")
	var last := word.strip_edges().right(1)
	var final := String(DIGIT_FINAL.get(last, "none"))
	if not last.is_empty():
		var code := last.unicode_at(0)
		if code >= 0xac00 and code <= 0xd7a3:
			var jong := (code - 0xac00) % 28
			final = "none" if jong == 0 else ("rieul" if jong == 8 else "final")
	if halves[0] == "으로":
		return "으로" if final == "final" else "로"
	return halves[1] if final == "none" else halves[0]


static func _truthy(v: Variant) -> bool:
	return v != null and not (v is bool and not v)


static func _pre_vote(council: Dictionary) -> bool:
	return council.get("pre") is Dictionary and not _truthy(council["pre"].get("result"))


## S1 currentAgenda: the open vote before the law (a confidence vote) while it stands.
static func current_agenda(g: Dictionary) -> Variant:
	var council: Variant = g.get("council")
	if not council is Dictionary:
		return null
	if _pre_vote(council):
		return council["pre"]["agenda"]
	var options: Array = council.get("options", [])
	return null if options.is_empty() else options[int(council["idx"])]


static func bribe_price(g: Dictionary, t: Dictionary, comm: String) -> int:
	return 2 + CouncilMath.round_half_up(float(_seats(g, t)[comm]) / 10.0)


## S1 persuadeEvidence: the crisis this law answers now, or "".
static func persuade_evidence(g: Dictionary, t: Dictionary, agenda: Dictionary) -> String:
	if not _is_law(agenda) or bool(agenda.get("repeal", false)):
		return ""
	var now: Array[String] = CouncilAgenda.crisis_now(g, t)
	for crisis: String in t["LAWS"][agenda["law"]]["crisis"]:
		if now.has(crisis):
			return crisis
	return ""


## S1 persuadeChance (결정 433): trust, the relation, promises kept and broken
## with that car, belief and the evidence; it costs nothing to try.
static func persuade_chance(g: Dictionary, t: Dictionary, comm: String, agenda: Dictionary) -> float:
	var s: Dictionary = g["comms"][comm]
	var p: Dictionary = t["P"]
	var ideo := int(blocs(g, t, agenda, [])[comm]["ideo"])
	var chance: float = float(p["persuadeBase"]) + float(p["persuadeRel"]) * float(s["rel"]) + float(p["persuadeTrust"]) * (float(g["trust"]) - 50.0) \
		+ float(p["persuadeKept"]) * minf(float(p["persuadeKeptMax"]), float(s.get("kept", 0))) - float(p["persuadeBroken"]) * float(s.get("broken", 0)) \
		+ float(p["persuadeIdeo"]) * ideo + (float(p["persuadeEvidence"]) if persuade_evidence(g, t, agenda) != "" else 0.0)
	return _clamp(chance, float(p["persuadeMin"]), float(p["persuadeMax"]))


## Whether persuasion took: fixed by the run's seed, the session and the car,
## so asking again in the session gives the same and the run's draws are untouched.
static func _persuade_roll(g: Dictionary, comm: String) -> float:
	return float(Stop.hash_text("%s|%s|%s|persuade" % [g["seed"], int(g["session"]), comm])) / 4294967296.0


## S1 toolStatus: whether `tool` can be used on `comm` now, why not, and its cost.
static func tool_status(g: Dictionary, t: Dictionary, comm: String, tool: String) -> Dictionary:
	var council: Variant = g.get("council")
	var agenda: Variant = current_agenda(g)
	if not council is Dictionary or agenda == null:
		return {"ok": false, "why": "회기가 아니다"}
	if bool(council.get("martial", false)):
		return {"ok": false, "why": "계엄 중엔 거래가 없다"}
	if _pre_vote(council):
		return {"ok": false, "why": "신임 표결엔 거래하지 않는다"}
	if _truthy(council.get("result")):
		return {"ok": false, "why": "표결이 끝났다"}
	var deals: Array = council.get("deals", [])
	for deal: Dictionary in deals:
		if deal["comm"] == comm:
			return {"ok": false, "why": "이미 거래했다"}
	var p: Dictionary = t["P"]
	if deals.size() >= int(p["maxDealsPerSession"]):
		return {"ok": false, "why": "회기당 %d건" % int(p["maxDealsPerSession"])}
	var s: Dictionary = g["comms"][comm]
	var b: Dictionary = blocs(g, t, agenda, deals)[comm]
	if int(b["und"]) + int(b["no"]) - int(b["hard"]) == 0:
		return {"ok": false, "why": "남은 반대는 꿈쩍 않는다" if int(b["hard"]) > 0 else "살 표가 없다"}
	var hostile := int(s["grudge"]) >= int(p["hostileGrudge"])
	match tool:
		"open", "fetch":
			var cost: String = "다음 정차: %s" % t["FETCH_WANT"][comm]["label"] if tool == "fetch" else "조건 하나"
			if bool(s.get("openClosed", false)): return {"ok": false, "why": "약속을 세 번 어겼다", "cost": cost}
			if _truthy(s.get("promise")): return {"ok": false, "why": "지키지 않은 약속", "cost": cost}
			if hostile: return {"ok": false, "why": "열차장을 적대한다", "cost": cost}
			if float(s["rel"]) <= -40.0: return {"ok": false, "why": "관계가 반대 이하", "cost": cost}
			if int(b["ideo"]) <= -3: return {"ok": false, "why": "신념에 정면으로 반한다", "cost": cost}
			return {"ok": true, "cost": cost}
		"favor":
			if _truthy(s.get("sick")): return {"ok": false, "why": "대신 나온 측근에겐 빚이 없다", "cost": "빚 1"}
			if not _truthy(s.get("debt")): return {"ok": false, "why": "받을 빚이 없다", "cost": "빚 1"}
			if hostile: return {"ok": false, "why": "열차장을 적대한다", "cost": "빚 1"}
			return {"ok": true, "cost": "빚 1"}
		"bribe":
			var price := bribe_price(g, t, comm)
			var cost := "사치품 %d" % price
			if hostile: return {"ok": false, "why": "집단이 따르지 않는다", "cost": cost}
			if _truthy(s.get("sick")): return {"ok": false, "why": "측근은 뇌물을 받지 않는다", "cost": cost}
			if float(g["lux"]) < price: return {"ok": false, "why": "사치품이 모자라다", "cost": cost}
			return {"ok": true, "cost": cost}
		"blackmail":
			var held := 0
			for secret: Dictionary in g["secrets"]:
				if secret["about"] == comm: held += 1
			var cost := "비밀 %d · 신임 −%d" % [held, absi(int(p["blackmailTrust"]))]
			if held == 0: return {"ok": false, "why": "쥔 비밀이 없다", "cost": cost}
			if hostile: return {"ok": false, "why": "집단이 따르지 않는다", "cost": cost}
			return {"ok": true, "cost": cost}
		"persuade":
			var cost := "될 듯 %d%%" % CouncilMath.round_half_up(100.0 * persuade_chance(g, t, comm, agenda))
			if hostile: return {"ok": false, "why": "열차장 말을 듣지 않는다", "cost": cost}
			if int(b["und"]) == 0 and int(b["no"]) - int(b["hard"]) == 0: return {"ok": false, "why": "돌릴 마음이 없다", "cost": cost}
			return {"ok": true, "cost": cost}
	return {"ok": false, "why": "할 수 없다"}


## S1 openConditions: the car's worst-off ask, one of its own and one common,
## the same within a session. S1c's conditions stay off (a dom of stores is S1a).
static func open_conditions(g: Dictionary, t: Dictionary, comm: String) -> Array:
	var pool: Array = []
	for cond: Dictionary in t["CONDITIONS"][comm]:
		if not bool(cond.get("s1c", false)):
			pool.append(cond)
	var sit: Array[float] = St.situation(g, t, comm)
	var want := "relocate" if comm == "tail" and sit[2] >= 70.0 else ("heat" if sit[0] < sit[1] else "ration")
	var first: int = 0
	for i: int in pool.size():
		if pool[i]["kind"] == want:
			first = i
			break
	var rest: Array = []
	for i: int in pool.size():
		if i != first: rest.append(pool[i])
	var second: Dictionary = rest[(int(g["session"]) + int(g["seg"])) % rest.size()]
	var commons: Array = []
	for cond: Dictionary in t["COMMON_CONDITIONS"]:
		if cond["kind"] != "agenda" or g.get("agendaHolder") == null:
			commons.append(cond)
	var common: Dictionary = commons[(int(g["session"]) + (t["COMMS"] as Array).find(comm)) % commons.size()]
	return [pool[first], second, common]


static func _reveal_trait(g: Dictionary, comm: String) -> void:
	var leader: Dictionary = g["comms"][comm]["leader"]
	if int(leader["traitShown"]) < 2:
		leader["traitShown"] = int(leader["traitShown"]) + 1


static func _expose_bribe(g: Dictionary, comm: String) -> void:
	var s: Dictionary = g["comms"][comm]
	s["coh"] = _clamp(float(s["coh"]) - 0.2, 0.0, 1.0)
	s["disgraced"] = true
	_bump(g, "trust", -10.0, "leak")
	_offend(g, comm)
	_journal(g, "뇌물이 드러났다. %s의 정당성이 무너지고 열차장도 신임을 잃었다." % s["leader"]["name"], "bad")


## S1 cutComm: the car's ration and privileges cut (식량 +4); its opposite is glad.
static func _cut_comm(g: Dictionary, t: Dictionary, comm: String, as_action: bool) -> void:
	var s: Dictionary = g["comms"][comm]
	_bump_rel(g, comm, -15.0, "comm")
	s["fervor"] = mini(3, int(s["fervor"]) + 1)
	_bump(g, "food", 4.0, "comm")
	_bump_rel(g, t["OPPOSITE"][comm], 5.0, "comm")
	var recent := int(g["seg"]) - int(s["supportedAt"]) <= 3
	for at: Variant in s["cutAt"]:
		recent = recent or int(g["seg"]) - int(at) <= 3
	if recent:
		_offend(g, comm)
	(s["cutAt"] as Array).append(g["seg"])
	if as_action:
		g["actedSeg"] = g["seg"]
	_journal(g, "%s의 배급과 특권을 깎았다(식량 +4)." % t["COMM_NAME"][comm], "dark")


## S1 payNow: the open conditions paid on the spot.
static func _pay_now(g: Dictionary, t: Dictionary, comm: String, kind: String, cut_target: String) -> void:
	match kind:
		"relocate":
			g["comms"]["tail"]["base"][2] = float(g["comms"]["tail"]["base"][2]) - 15.0
			g["comms"]["front"]["base"][2] = float(g["comms"]["front"]["base"][2]) + 10.0
			_bump_rel(g, "front", -5.0, "deal")
		"front_levy":
			_bump(g, "lux", 3.0, "deal")
			_bump_rel(g, "front", -8.0, "deal")
			_bump_rel(g, comm, 3.0, "deal")
		"shift":
			_bump(g, "coal", -float(t["P"]["shiftCoal"]), "deal")
			g["comms"]["engine"]["base"][3] = float(g["comms"]["engine"]["base"][3]) - float(t["P"]["shiftRelief"])
		"agenda":
			g["agendaHolder"] = comm
			_bump(g, "trust", 2.0, "deal")
		"cut":
			if cut_target != "":
				_cut_comm(g, t, cut_target, false)


## S1 makeDeal: {ok, text, g}. An open deal takes `cond_index` of open_conditions
## (and `cut_target` for 「다른 칸 하나 칼질」).
static func make_deal(g0: Dictionary, t: Dictionary, comm: String, tool: String, cond_index: int = 0, cut_target: String = "") -> Dictionary:
	var g := g0.duplicate(true)
	var status := tool_status(g, t, comm, tool)
	var council: Variant = g.get("council")
	var agenda: Variant = current_agenda(g)
	if not bool(status["ok"]) or not council is Dictionary or agenda == null:
		return {"ok": false, "text": status.get("why", "할 수 없다"), "g": g}
	var s: Dictionary = g["comms"][comm]
	var name: String = t["COMM_NAME"][comm]
	var leader: String = s["leader"]["name"]
	var p: Dictionary = t["P"]
	var label := ""
	match tool:
		"open":
			var conds := open_conditions(g, t, comm)
			if cond_index < 0 or cond_index >= conds.size():
				return {"ok": false, "text": "조건이 없다", "g": g}
			var cond: Dictionary = (conds[cond_index] as Dictionary).duplicate(true)
			var kind: String = cond["kind"]
			if kind == "cut" and (cut_target == "" or cut_target == comm):
				return {"ok": false, "text": "칼질할 칸을 고른다", "g": g}
			label = "%s 칼질" % t["COMM_NAME"][cut_target] if kind == "cut" else String(cond["label"])
			if bool(cond["now"]):
				_pay_now(g, t, comm, kind, cut_target)
			else:
				var promise := {"kind": "open", "cond": cond, "label": label, "madeSession": g["session"],
					"due": int(g["seg"]) + 1 if kind in ["target", "skip_dispatch"] else int(g["seg"]) + int(p["promiseSegments"])}
				if _is_law(agenda):
					promise["law"] = agenda["law"]
				if kind == "heat":
					promise["baseline"] = s["heat"]
				elif kind in ["ration", "keep_ration"]:
					promise["baseline"] = s["ration"]
				s["promise"] = promise
			_journal(g, "%s과(와) 공개 협상: %s. %s에 찬성하기로 했다." % [name, label, agenda_title(t, agenda)], "deal")
		"fetch":
			var want: String = t["FETCH_WANT"][comm]["label"]
			label = "현장 조달: %s" % want
			var promise := {"kind": "fetch", "cond": {"kind": "target", "label": want, "now": false}, "label": label, "due": int(g["seg"]) + 1, "madeSession": g["session"]}
			if _is_law(agenda):
				promise["law"] = agenda["law"]
			s["promise"] = promise
			_journal(g, "%s에 약속했다: 다음 정차에서 %s을(를) 가져온다." % [name, want], "deal")
		"favor":
			s["debt"] = false
			label = "빚 회수"
			_journal(g, "%s에게 빚을 받았다. 대표가 표를 끌고 온다." % leader, "deal")
		"bribe":
			var price := bribe_price(g, t, comm)
			_bump(g, "lux", -price, "deal")
			label = "뇌물(사치품 %d)" % price
			g["stats"]["bribes"] = int(g["stats"]["bribes"]) + 1
			_reveal_trait(g, comm)
			if s["leader"]["trait"] == "ideal":
				# 이상주의자는 뇌물을 내밀면 폭로한다(3.3).
				_expose_bribe(g, comm)
				(council["deals"] as Array).append({"comm": comm, "tool": tool, "label": "뇌물을 거절당함", "refused": true})
				return {"ok": false, "text": "%s이(가) 뇌물을 의회 앞에서 내보였다." % leader, "g": g}
			_journal(g, "%s에게 사치품 %d을(를) 건넸다." % [leader, price], "dark")
		"persuade":
			var evidence := persuade_evidence(g, t, agenda)
			var why := "말로"
			if evidence != "":
				why = "%s%s 들어" % [CRISIS_WORD[evidence], _josa(CRISIS_WORD[evidence], "을/를")]
			elif int(s.get("kept", 0)) > 0:
				why = "지킨 약속을 들어"
			if _persuade_roll(g, comm) >= persuade_chance(g, t, comm, agenda):
				_bump_rel(g, comm, float(p["persuadeFailRel"]), "deal")
				(council["deals"] as Array).append({"comm": comm, "tool": tool, "label": "설득이 먹히지 않음", "refused": true})
				_journal(g, "%s을(를) %s 설득했지만 고개를 저었다." % [leader, why], "bad")
				return {"ok": false, "text": "%s이(가) 설득에 넘어오지 않았다." % leader, "g": g}
			label = "설득: %s" % why
			_journal(g, "%s을(를) %s 설득했다. %s에 마음이 돌아섰다." % [leader, why, agenda_title(t, agenda)], "deal")
		_:
			# The heaviest secret about the car (the first of the heaviest, as S1's stable sort).
			var secret: Dictionary = {}
			for row: Dictionary in g["secrets"]:
				if row["about"] == comm and (secret.is_empty() or float(row["weight"]) > float(secret["weight"])):
					secret = row
			g["secrets"] = (g["secrets"] as Array).filter(func(row: Dictionary) -> bool: return row["id"] != secret["id"])
			label = "협박: %s" % secret["text"]
			(g["leashes"] as Array).append({"comm": comm, "since": g["seg"], "weight": maxi(1, int(secret["weight"]) - int(secret["uses"]))})
			g["blackmails"] = int(g["blackmails"]) + 1
			g["stats"]["blackmails"] = int(g["stats"]["blackmails"]) + 1
			_bump(g, "trust", float(p["blackmailTrust"]), "deal")
			_bump_rel(g, comm, float(p["blackmailRel"]), "deal")
			_offend(g, comm)
			_reveal_trait(g, comm)
			_journal(g, "%s을(를) 비밀로 눌렀다: \"%s\"." % [leader, secret["text"]], "dark")
			if int(g["blackmails"]) % int(p["blackmailReputation"]) == 0:
				for other: String in t["COMMS"]:
					_offend(g, other)
				_journal(g, "소문이 돈다: \"열차장은 약점을 잡는다.\" 모든 칸이 경계한다.", "bad")
	(council["deals"] as Array).append({"comm": comm, "tool": tool, "label": label})
	g["stats"]["dealsMade"] = int(g["stats"]["dealsMade"]) + 1
	return {"ok": true, "text": label, "g": g}


static func cast_vote(g0: Dictionary, t: Dictionary) -> Dictionary:
	var g := g0.duplicate(true)
	var council: Variant = g.get("council")
	if not council is Dictionary or council.get("result") != null or (council.get("options", []) as Array).is_empty():
		return {"result": null, "g": g}
	assert(not bool(council.get("martial", false)), "계엄 표결은 이 슬라이스 범위가 아니다")
	var agenda: Dictionary = council["options"][int(council["idx"])]
	_assert_supported(agenda)
	var map := blocs(g, t, agenda, council.get("deals", []))
	var packed: Array = []
	for comm: String in t["COMMS"]:
		packed.append(map[comm])
	var need := agenda_need(t, agenda)
	var counted := VoteCount.count(packed, int(g["rng"]["state"]), need)
	g["rng"]["state"] = counted["state"]
	var by_comm := {}
	for i: int in (t["COMMS"] as Array).size():
		var row: Array = counted["by_comm"][i]
		by_comm[t["COMMS"][i]] = {"yes": row[0], "no": row[1], "absent": row[2]}
	var flips: Array = []
	for row: Array in counted["flips"]:
		flips.append({"comm": t["COMMS"][int(row[0])], "yes": row[1]})
	var result := {
		"yes": counted["yes"], "no": counted["no"], "absent": counted["absent"], "need": need,
		"passed": counted["passed"], "byComm": by_comm, "flips": flips, "decree": false,
		"secret": _law_active(g, "secret_ballot"),
	}
	var turned := {}
	for i: int in (t["COMMS"] as Array).size():
		turned[t["COMMS"][i]] = {"und": counted["turned"][i][0], "pool": counted["turned"][i][1]}
	var why: Variant = CouncilLog.vote_why(t, map, turned)
	if why != null:
		result["why"] = why
	council["result"] = result
	if not _law_active(g, "secret_ballot"):
		g["fear"] = _clamp(float(g["fear"]) + 1.0, 0.0, 100.0)
	var pre := council.get("pre") is Dictionary and council["pre"].get("result") == null
	if not pre:
		g.erase("voteShift")
	if _law_active(g, "guided_voting") and int(g.get("guidedLeft", 0)) > 0 and not pre:
		for comm: String in t["COMMS"]:
			_bump_rel(g, comm, -3.0, "vote")
		g["fear"] = _clamp(float(g["fear"]) + 3.0, 0.0, 100.0)
		g["guidedLeft"] = int(g["guidedLeft"]) - 1
	if not pre and not bool(council.get("emergency", false)):
		for proposal: Dictionary in g.get("proposals", []):
			if proposal.get("by") != null and not CouncilAgenda.same_agenda(proposal, agenda):
				_bump_rel(g, str(proposal["by"]), -3.0, "vote")
		g["proposals"] = []
	if not pre and bool(council.get("emergency", false)) and bool(result["passed"]):
		for comm: String in t["COMMS"]:
			if int(map[comm]["absent"]) > 0 and int(map[comm]["score"]) < 0:
				_offend(g, comm)
				_journal(g, "%s의 작업조가 돌아와 쓰러져 자는 사이 표결했다. 기습으로 기억한다." % t["COMM_NAME"][comm], "dark")
	var title := agenda_title(t, agenda)
	var kind := "motion" if not _is_law(agenda) else ("ratify" if bool(agenda.get("ratify", false)) else ("amend" if agenda.get("amend") != null else ("repeal" if bool(agenda.get("repeal", false)) else "enact")))
	var row := {
		"session": g["session"], "seg": g["seg"], "title": title, "kind": kind, "by": agenda.get("by") if agenda.get("by") != null else "chief",
		"passed": result["passed"], "yes": result["yes"], "no": result["no"], "absent": result["absent"], "need": need, "exp": expected(map, t),
	}
	if why != null:
		row["why"] = why
	CouncilLog.log_vote(g, row)
	# The car handed the agenda choice picked this one (result arc): fails in a row sting.
	if council.get("holder") != null and not pre:
		CouncilLog.note_held(g, t, str(council["holder"]), bool(result["passed"]))
	var attendance := ", 부재 %d" % int(result["absent"]) if int(result["absent"]) != 0 else ""
	_journal(g, "%s: 찬성 %d, 반대 %d%s. %s." % [title, int(result["yes"]), int(result["no"]), attendance, "가결" if bool(result["passed"]) else "부결"], "good" if bool(result["passed"]) else "bad")
	if not _is_law(agenda):
		_motion_effect(g, t, agenda, bool(result["passed"]))
	elif not bool(result["passed"]):
		g["stats"]["lawsFailed"] = int(g["stats"]["lawsFailed"]) + 1
	elif bool(agenda.get("repeal", false)):
		_repeal_law_mut(g, t, agenda["law"])
	else:
		var bought: Array = []
		for deal: Dictionary in council.get("deals", []):
			if deal["tool"] == "open" or deal["tool"] == "fetch": bought.append(deal["comm"])
		_enact_law_mut(g, t, agenda["law"], bought)
	return {"result": result, "g": g}
