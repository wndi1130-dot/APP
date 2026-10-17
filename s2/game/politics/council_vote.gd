extends RefCounted
## S1a council stance, blocs and one non-decree vote. Only the field slice's two motions and five
## law ids are accepted; extending that set requires porting the corresponding S1 effects too.

const CouncilMath = preload("res://game/politics/council_math.gd")
const VoteCount = preload("res://game/politics/vote_count.gd")

const LEDGER_MAX := 64
const SUPPORTED_LAWS := [
	"corpse_throw", "corpse_store", "corpse_burn", "common_kitchen", "contribution_ration",
]
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
		assert(not bool(agenda.get("repeal", false)) and not bool(agenda.get("ratify", false)) and not agenda.has("amend"), "폐지·추인·개정 안건은 이 슬라이스 범위가 아니다")
	else:
		assert(SUPPORTED_MOTIONS.has(agenda.get("motion")), "지원하지 않는 동의 안건: %s" % agenda.get("motion"))


static func _motion_lean(t: Dictionary, comm: String, agenda: Dictionary) -> Dictionary:
	var amount := 0.0
	if agenda["motion"] == "field_symbol":
		amount = float(t["FIELD"]["symbolLean"])
	else:
		amount = float(t["FIELD"]["promiseLean"])
	return {"mat": amount if comm == agenda.get("subject") else 0.0, "ideo": 0.0}


static func stance(g: Dictionary, t: Dictionary, comm: String, agenda: Dictionary, with_grudge: bool = true) -> Dictionary:
	_assert_supported(agenda)
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
	assert(deals.is_empty(), "field slice council accepts no deals")
	var seat_map := _seats(g, t)
	var out := {}
	for comm: String in t["COMMS"]:
		var bloc := _base_bloc(g, t, comm, agenda, int(seat_map[comm]))
		if _law_active(g, "guided_voting") and int(g.get("guidedLeft", 0)) > 0:
			var moved := CouncilMath.round_half_up(int(bloc["und"]) * 0.3)
			bloc["yes"] = int(bloc["yes"]) + moved
			bloc["und"] = int(bloc["und"]) - moved
		for row: Dictionary in g.get("voteShift", []):
			if row["comm"] == comm:
				var side := 1.0 if row["side"] == "yes" or (row["side"] == "captain" and not agenda.has("by")) else (-1.0 if row["side"] == "no" else 0.0)
				bloc = _shift(bloc, float(row["n"]) * side)
		out[comm] = bloc
	return out


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
	_assert_supported(agenda)
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


static func _enact_law_mut(g: Dictionary, t: Dictionary, law: String, bought_from: Array) -> void:
	assert(SUPPORTED_LAWS.has(law), "지원하지 않는 법: %s" % law)
	assert(bought_from.is_empty(), "field slice council accepts no bought votes")
	var definition: Dictionary = t["LAWS"][law]
	var base: Variant = t["LAW_VARIANT_OF"].get(law)
	if base != null and (g["passed"] as Dictionary).has(base):
		(g["passed"] as Dictionary).erase(base)
		g["repealedAt"][base] = g["session"]
		var old: Dictionary = t["LAWS"][base]
		for comm: String in t["COMMS"]:
			var mats: Variant = (old.get("mats", {}) as Dictionary).get(comm)
			if mats is Array:
				for i: int in 4:
					g["comms"][comm]["base"][i] = float(g["comms"][comm]["base"][i]) - float(mats[i])
		_journal(g, "%s을(를) %s(으)로 고쳤다." % [old["title"], definition["title"]])
	g["passed"][law] = g["session"]
	for comm: String in t["COMMS"]:
		var mats: Variant = (definition.get("mats", {}) as Dictionary).get(comm)
		if mats is Array:
			for i: int in 4:
				g["comms"][comm]["base"][i] = float(g["comms"][comm]["base"][i]) + float(mats[i])
		var relation: Variant = (definition.get("rels", {}) as Dictionary).get(comm)
		if relation != null:
			_bump_rel(g, comm, float(relation), "vote")
	if not g.get("onceTaken") is Array:
		g["onceTaken"] = []
	var once: String = base if base != null else law
	if not (g["onceTaken"] as Array).has(once):
		var res: Dictionary = definition.get("res", {})
		if float(res.get("trustOnce", 0)) != 0.0:
			_bump(g, "trust", float(res["trustOnce"]), "vote")
		if float(res.get("fearOnce", 0)) != 0.0:
			g["fear"] = _clamp(float(g["fear"]) + float(res["fearOnce"]), 0.0, 100.0)
		if float(res.get("foodOnce", 0)) != 0.0:
			_bump(g, "food", float(res["foodOnce"]), "vote")
		if float(res.get("trustOnce", 0)) != 0.0 or float(res.get("fearOnce", 0)) != 0.0 or float(res.get("foodOnce", 0)) != 0.0:
			(g["onceTaken"] as Array).append(once)
	if (t["CORPSE_LAWS"] as Array).has(law):
		g["corpseIssue"] = false
	g["stats"]["lawsPassed"] = int(g["stats"]["lawsPassed"]) + 1


static func enact_law(g0: Dictionary, t: Dictionary, law: String, bought_from: Array = []) -> Dictionary:
	var g := g0.duplicate(true)
	_enact_law_mut(g, t, law, bought_from)
	return g


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
	council["result"] = result
	if not _law_active(g, "secret_ballot"):
		g["fear"] = _clamp(float(g["fear"]) + 1.0, 0.0, 100.0)
	var pre := council.get("pre") is Dictionary and council["pre"].get("result") == null
	if not pre:
		g.erase("voteShift")
	if not pre and bool(council.get("emergency", false)) and bool(result["passed"]):
		for comm: String in t["COMMS"]:
			if int(map[comm]["absent"]) > 0 and int(map[comm]["score"]) < 0:
				_offend(g, comm)
				_journal(g, "%s의 작업조가 돌아와 쓰러져 자는 사이 표결했다. 기습으로 기억한다." % t["COMM_NAME"][comm], "dark")
	var title := agenda_title(t, agenda)
	var attendance := ", 부재 %d" % int(result["absent"]) if int(result["absent"]) != 0 else ""
	_journal(g, "%s: 찬성 %d, 반대 %d%s. %s." % [title, int(result["yes"]), int(result["no"]), attendance, "가결" if bool(result["passed"]) else "부결"], "good" if bool(result["passed"]) else "bad")
	if not _is_law(agenda):
		_motion_effect(g, t, agenda, bool(result["passed"]))
	elif not bool(result["passed"]):
		g["stats"]["lawsFailed"] = int(g["stats"]["lawsFailed"]) + 1
	else:
		_enact_law_mut(g, t, agenda["law"], [])
	return {"result": result, "g": g}
