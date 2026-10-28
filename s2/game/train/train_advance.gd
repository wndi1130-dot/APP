extends RefCounted
## Partial S1a turn port. Every public action returns a deep copy.
## Unported branches return that copy with _turn_port_error = F-NOT-PORTED: ...;
## callers must reject that result. No fixture answers are read by these rules.

const Turn = preload("res://game/train/train_turn.gd")
const Stop = preload("res://game/train/train_stop.gd")
const State = preload("res://game/train/train_state.gd")
const Agenda = preload("res://game/politics/council_agenda.gd")
const Vote = preload("res://game/politics/council_vote.gd")
const Field = preload("res://game/politics/field_return.gd")
const Special = preload("res://game/politics/field_council.gd")
const Rng = preload("res://game/politics/rng.gd")
const Settle = preload("res://game/train/turn/turn_settle.gd")
const Death = preload("res://game/train/turn/turn_death.gd")
const Travel = preload("res://game/train/turn/turn_travel.gd")
const Cards = preload("res://game/train/turn/turn_cards.gd")
const Wounds = preload("res://game/train/turn/turn_wounds.gd")


static func _unported(g: Dictionary, reason: String) -> Dictionary:
	var out: Dictionary = g.duplicate(true)
	out["_turn_port_error"] = "F-NOT-PORTED: " + reason
	return out


static func _rnd(g: Dictionary) -> float:
	var draw: Array = Rng.next(int(g["rng"]["state"]))
	g["rng"]["state"] = draw[1]
	return float(draw[0])


static func _session(g: Dictionary, t: Dictionary) -> bool:
	return int(g["seg"]) > 0 and int(g["seg"]) % int(t["P"]["sessionEvery"]) == 0


static func _pre_vote(council: Dictionary) -> bool:
	return council.get("pre") is Dictionary and council["pre"].get("result") == null


static func advance(g: Dictionary, t: Dictionary) -> Dictionary:
	if not (g["cards"] as Array).is_empty() or g["phase"] == "end": return g.duplicate(true)
	if not State.is_s1a(g): return _unported(g, "S1a only")
	match str(g["phase"]):
		"stop":
			if not g.get("stop") is Dictionary or not bool(g["stop"].get("done", false)): return g.duplicate(true)
			return after_stop(g, t)
		"council":
			var council: Dictionary = g["council"] if g.get("council") is Dictionary else {}
			if _pre_vote(council) and council.get("result") != null:
				var out: Dictionary = g.duplicate(true)
				out["council"]["pre"]["result"] = out["council"]["result"]
				out["council"]["result"] = null
				return out
			if not bool(council.get("martial", false)) and (not (council.get("options", []) as Array).is_empty() or _pre_vote(council)) and council.get("result") == null:
				return g.duplicate(true)
			if bool(council.get("special", false)): return Special.leave_special_council(g, t)["g"]
			return Settle.settle(g, t)
		"settle":
			if Turn.next_segment_covers(g, t): return Turn.next_segment(g, t)
			return _unported(g, "nextSegment: terminal/stranded/decree expiry")
		"prep": return Travel.depart(g, t)
		"travel": return Travel.run_travel(g, t, after_stop)
	return g.duplicate(true)


static func _stranger_corpse(g: Dictionary, t: Dictionary) -> void:
	var flags: Dictionary = g["story"]["flags"]
	if int(g["seg"]) != int(t["STRANGER_SEG"]) or bool(flags.get("first_death", false)) or bool(g["corpseIssue"]): return
	for law: String in t["CORPSE_LAWS"]:
		if State.law_active(g, law): return
	if flags.has("first_corpse_agenda") and flags["first_corpse_agenda"] != "none": return
	g["corpseIssue"] = true
	flags["first_corpse_agenda"] = "stranger"
	Turn._journal(g, "강가에 낯선 사람이 얼어 죽어 있다. 강을 건너오다 쓰러진 모양이다. 데려가 묻을지, 두고 갈지, 선로 밖으로 치울지 말이 갈렸다. 시신 처리가 안건에 올랐다.", "bad")


static func after_stop(g0: Dictionary, t: Dictionary) -> Dictionary:
	var due: bool = _session(g0, t) or bool(g0.get("councilOwed", false))
	var stranded: Dictionary = g0["stranded"] if g0.get("stranded") is Dictionary else {}
	var g: Dictionary = g0.duplicate(true)
	_stranger_corpse(g, t)
	if not due or bool(stranded.get("captainAway", false)):
		if due: g["councilOwed"] = true
		var settled: Dictionary = Settle.settle(g, t)
		return _unported(g0, str(settled["_turn_port_error"]).trim_prefix("F-NOT-PORTED: ")) if settled.has("_turn_port_error") else settled
	g["councilOwed"] = false
	var opened: Dictionary = open_council(g, t)
	if opened.has("_turn_port_error"): return _unported(g0, str(opened["_turn_port_error"]))
	opened["phase"] = "council"
	return opened


static func _new_secret(g: Dictionary, t: Dictionary) -> Dictionary:
	var comms: Array = t["COMMS"]
	var comm: String = comms[int(floor(_rnd(g) * comms.size()))]
	var owned: Array = []
	for secret: Dictionary in g["secrets"]: owned.append(secret["text"])
	var pool: Array = []
	for base: Dictionary in t["SECRET_POOL"]:
		if not owned.has(base["text"]): pool.append(base)
	if pool.is_empty(): pool = t["SECRET_POOL"]
	var chosen: Dictionary = pool[int(floor(_rnd(g) * pool.size()))]
	var secret: Dictionary = {"id": g["nextSecretId"], "text": chosen["text"], "weight": chosen["weight"], "about": comm, "uses": 0}
	g["nextSecretId"] = int(g["nextSecretId"]) + 1
	(g["secrets"] as Array).append(secret)
	return secret


static func open_council(g0: Dictionary, t: Dictionary, emergency: bool = false) -> Dictionary:
	if g0.get("agendaHolder") != null: return _unported(g0, "openCouncil: agendaHolder stance")
	var g: Dictionary = g0.duplicate(true)
	g["session"] = int(g["session"]) + 1
	for comm: String in t["COMMS"]:
		var state: Dictionary = g["comms"][comm]
		if emergency: state["lastOffense"] = int(state["lastOffense"]) + 1
		elif int(state["grudge"]) > 0 and int(g["session"]) - int(state["lastOffense"]) >= int(t["P"]["grudgeDecay"]):
			state["grudge"] = int(state["grudge"]) - 1
			state["lastOffense"] = g["session"]
	if not emergency and State.law_active(g, "patrol") and _rnd(g) < 0.25:
		var secret: Dictionary = _new_secret(g, t)
		Turn._journal(g, "귀환 검사에서 %s 대표의 약점이 드러났다." % t["COMM_NAME"][secret["about"]], "dark")
	var regular: Dictionary = Agenda.agenda_options(g, t)
	g["council"] = {"options": regular["options"], "idx": 0, "locked": false, "deals": [], "result": null}
	if emergency: g["council"]["emergency"] = true
	g["agendaHolder"] = null
	# 내정 훅 자리: COUNCIL_HOOKS.open.
	return g


static func cast_vote(g: Dictionary, t: Dictionary) -> Dictionary:
	var council: Dictionary = g["council"] if g.get("council") is Dictionary else {}
	if council.is_empty() or council.get("result") != null: return g.duplicate(true)
	if _pre_vote(council): return _unported(g, "castVote: pre vote")
	var options: Array = council.get("options", [])
	if options.is_empty(): return g.duplicate(true)
	var agenda: Dictionary = options[int(council["idx"])]
	if bool(council.get("martial", false)): return _unported(g, "castVote: martial")
	if agenda.get("kind") == "motion":
		if not Vote.SUPPORTED_MOTIONS.has(agenda.get("motion")): return _unported(g, "castVote: motion " + str(agenda.get("motion")))
	elif not Vote.supported_law(agenda.get("law")) or bool(agenda.get("ratify", false)):
		return _unported(g, "castVote: law " + str(agenda.get("law")))
	return Vote.cast_vote(g, t)["g"]


static func choose_card(g: Dictionary, t: Dictionary, uid: int, index: int) -> Dictionary:
	return Cards.choose(g, t, uid, index)


static func _crew_rest(g: Dictionary, t: Dictionary, busy: String) -> void:
	for comm: String in t["COMMS"]:
		if not (t["REST_FLOOR"] as Dictionary).has(comm) or comm == busy: continue
		var base: Array = g["comms"][comm]["base"]
		base[3] = maxf(minf(float(t["REST_FLOOR"][comm]), float(base[3])), float(base[3]) - float(t["P"]["crewRest"]))


static func _crew_work(g: Dictionary, t: Dictionary, comm: String, gain: float, cap: float) -> String:
	var base: Array = g["comms"][comm]["base"]
	base[3] = maxf(float(base[3]), minf(cap, float(base[3]) + gain))
	if not (t["CHORE_COMMS"] as Array).has(comm): return ""
	Field._bump_rel(g, comm, float(t["P"]["choreRel"]), "stop.loot")
	var name: String = t["COMM_NAME"][comm]
	var final_code: int = name.unicode_at(name.length() - 1)
	var particle: String = "은" if final_code >= 0xAC00 and final_code <= 0xD7A3 and (final_code - 0xAC00) % 28 != 0 else "는"
	return "%s%s 손에 안 익은 짐을 날랐다. 불만이 나온다." % [name, particle]


static func _burn_pyre(g: Dictionary, t: Dictionary) -> void:
	var count: int = int(State.pyre_count(g))
	if count <= 0: return
	# 내정 훅 자리: domesticPyreWood.
	Field._bump(g, "coal", -minf(maxf(0.0, float(g["coal"])), float(t["P"]["pyreCoal"]) * count), "pyre")
	g["pyre"] = 0
	var kin: Dictionary = g.get("pyreKin", {})
	for comm: String in t["COMMS"]:
		while int(kin.get(comm, 0)) > 0:
			kin[comm] = int(kin[comm]) - 1
			g["comms"][comm]["base"][2] = float(g["comms"][comm]["base"][2]) - float(t["P"]["pyreKinCrowd"])
	Turn._journal(g, "선로 옆 장작불에 시신 %d구를 태웠다." % count, "dark")


static func _check_stop_promises(g: Dictionary, t: Dictionary, target: Variant, gains: Dictionary) -> void:
	for comm: String in t["COMMS"]:
		var promise: Variant = g["comms"][comm].get("promise")
		if not promise is Dictionary or int(promise["due"]) > int(g["seg"]): continue
		var verdict: int = 0
		if promise["kind"] == "fetch":
			var want: Dictionary = t["FETCH_WANT"][comm]
			verdict = 1 if float(gains.get(want["target"], 0)) >= float(want["amount"]) else -1
		elif promise["cond"]["kind"] == "target": verdict = 1 if target == promise["cond"]["target"] else -1
		elif promise["cond"]["kind"] == "skip_dispatch":
			if target == null: promise["due"] = int(g["seg"]) + 1
			else: verdict = 1 if g["stop"]["crewComm"] != "tail" else -1
		if verdict == 1:
			Field._keep_promise(g, t, comm, str(promise["label"]))
			if promise["kind"] == "fetch": Field._bump_rel(g, comm, 10.0, "promise")
		elif verdict == -1: Field._break_promise(g, t, comm, str(promise["label"]))


## Counts the kind a dispatched stop aimed at into the run (decision 482, S1 noteTarget). Passed stops never call it.
static func _note_target(g: Dictionary, target: Variant) -> void:
	if not target is String or target == "": return
	var run: Variant = g.get("targetRun")
	g["targetRun"] = {"target": target, "n": int(run["n"]) + 1} if run is Dictionary and run["target"] == target else {"target": target, "n": 1}


static func resolve_stop(g0: Dictionary, t: Dictionary, go: bool = true) -> Dictionary:
	if not g0.get("stop") is Dictionary or bool(g0["stop"].get("done", false)): return g0.duplicate(true)
	if not State.is_s1a(g0): return _unported(g0, "resolveStop: S1a only")
	var risk: Dictionary = Stop.stop_risk(g0, t)
	if g0.get("deathWeight", false): return _unported(g0, "resolveStop: deathWeight")
	var g: Dictionary = g0.duplicate(true)
	var stop: Dictionary = g["stop"]
	# S1 stopRisk/crewNames queries activeWounds, which creates the empty wound book.
	# The read-only risk port deliberately has no such side effect; the action owns it.
	if not g.has("wounds"): g["wounds"] = []
	var p: Dictionary = t["P"]
	var place: Dictionary = Stop._place(t, stop["place"])
	stop["done"] = true
	var comm: String = stop["crewComm"]
	var names: Array[String] = Stop.crew_names(g, t, comm, int(stop["crewSize"]))
	var scouts_back: int = 0
	var report: Variant = stop.get("scoutReport")
	if report is Dictionary:
		for name: String in report["names"]:
			if not (report["dead"] as Array).has(name) and not State.is_gone(g, name): scouts_back += 1
		g["comms"][report["comm"]]["away"] = int(g["comms"][report["comm"]]["away"]) + scouts_back
	var nobody: bool = go and stop.get("target") != null and names.is_empty()
	if not go or stop.get("target") == null or nobody:
		stop["result"] = {"passed": true, "gains": {}, "injured": [], "dead": [], "notes": ["나갈 수 있는 사람이 없어 정차하지 않고 지나쳤다." if nobody else "정차하지 않고 지나쳤다."]}
		Turn._journal(g, "%s을(를) 지나쳤다." % place["name"])
		_crew_rest(g, t, "")
		# 내정 훅 자리: domesticStop(g, true, 0).
		_check_stop_promises(g, t, null, {})
		return g
	var stay: Dictionary = t["STAY"][stop["stay"]]
	Field._bump(g, "coal", -float(stay["coal"]), "stop.stay")
	_burn_pyre(g, t)
	var weights: Dictionary = {}
	var total: float = 0.0
	for key: String in t["LOOT_KEYS"]:
		weights[key] = float(place["loot"][key]) * (float(p["targetBoost"]) if key == stop["target"] else 1.0)
		total += float(weights[key])
	var scout_haul: float = 1.0
	if report is Dictionary:
		var gear: Dictionary = stop.get("scoutGear", {})
		scout_haul = float(gear.get("haul", p["scoutHaul"]))
	# 내정 훅 자리: domesticHaulMult. S1a에서는 1.
	var haul: float = float(p["haulTotal"]) * (0.7 + _rnd(g) * 0.6) * float(stay["mult"]) * Stop.crew_haul_mult(maxi(1, names.size()), float(risk["need"]), t["CREW"]["haul"], t) * State.law_mult(g, t, "haulMult") * scout_haul * float(t["CREW_HAUL"].get(comm, 1))
	var notes: Array[String] = []
	if Turn.tail_idle(g):
		var own: bool = comm == "tail"
		haul *= 0.7 if own else float(p["tailIdleHaul"])
		notes.append("꼬리칸이 작업을 거부했다(−30%)." if own else "꼬리칸이 손을 놓아 일이 더디다(−%d%%)." % int(floor((1.0 - float(p["tailIdleHaul"])) * 100.0 + 0.5)))
	var grieving: Array[String] = []
	for name: String in names:
		for mourner: Dictionary in g.get("mourning", []):
			if name == mourner["name"] and int(mourner["until"]) >= int(g["seg"]) and not State.is_gone(g, name):
				grieving.append(name)
				break
	if not grieving.is_empty():
		haul *= 1.0 - 0.1 * grieving.size()
		notes.append("%s은(는) 상중이라 손이 느렸다." % ", ".join(grieving))
	var child: String = "child_labor" if State.law_active(g, "child_labor") else ("child_pack" if State.law_active(g, "child_pack") else "")
	var schooling: bool = false
	for law: String in t["EDU_LAWS"]:
		if State.law_active(g, law): schooling = true
	if child != "" and schooling:
		notes.append("아이들은 반나절만 짐을 받았다. 산출 +7.5%." if child == "child_labor" else "아이들은 반나절만 짐을 꾸렸다. 산출 +5%.")
	elif child == "child_labor": notes.append(("아이들이 승강장에서 짐을 받았다." if int(g["seg"]) % 2 == 0 else "승강장에 작은 손이 섰다.") + " 산출 +15%.")
	elif child == "" and schooling: notes.append("아이들은 열차에 남아 배웠다. 승강장의 손 +0%." if int(g["seg"]) % 2 == 0 else "오늘 승강장에는 어른만 섰다.")
	if child == "child_labor":
		if not g.has("edu"): g["edu"] = {"segs": 0, "early": 0, "hands": 0}
		g["edu"]["hands"] += 1
	var gains: Dictionary = {}
	for key: String in t["LOOT_KEYS"]:
		var amount: float = haul * float(weights[key]) / total
		var value: int
		if ["coal", "food", "medicine"].has(key): value = int(floor(amount * (float(p["coalHaul"]) if key == "coal" else 1.0) + 0.5))
		elif key == "luxury": value = int(floor(amount / 3.0 + 0.5))
		else: value = mini(2, int(floor(amount / 10.0)) + (1 if _rnd(g) < fmod(amount, 10.0) / 10.0 else 0))
		if value > 0: gains[key] = value
	for mapping: Array in [["coal", "coal"], ["food", "food"], ["med", "medicine"], ["lux", "luxury"]]:
		Field._bump(g, mapping[0], float(gains.get(mapping[1], 0)), "stop.loot")
	g["symbols"] = int(g["symbols"]) + int(gains.get("symbol", 0))
	for i: int in int(gains.get("secret", 0)):
		var secret: Dictionary = _new_secret(g, t)
		notes.append("문서에서 %s 대표의 약점을 찾았다." % t["COMM_NAME"][secret["about"]])
	if bool(risk["guardRefused"]): notes.append("경비대가 경계를 거부했다.")
	var dead: Array[String] = []
	for name: String in risk["dead"]:
		if not State.is_gone(g, name): dead.append(name)
	var hurt: Array[String] = []
	for name: String in risk["hurt"]:
		if not State.is_gone(g, name) and not dead.has(name): hurt.append(name)
	if hurt.is_empty() and dead.is_empty() and float(risk["lam"]) >= 0.2: notes.append("몇이 긁히고 삐었다. 크게 다친 사람은 없다.")
	g["injured"] = int(g["injured"]) + hurt.size()
	if not hurt.is_empty():
		Wounds.note_injury(g, t, hurt.size(), "stop", str(place["name"]), {"names": hurt, "comm": comm})
		Field._bump_rel(g, comm, float(p["hurtRel"]) * hurt.size(), "stop.loot")
	if not dead.is_empty(): Death.on_death(g, t, comm, dead, "warned" if bool(risk["known"]) and int(risk["maxDead"]) > 0 else "other")
	var returned: Array[String] = []
	for name: String in names:
		if not State.is_gone(g, name): returned.append(name)
	g["comms"][comm]["away"] = int(g["comms"][comm]["away"]) + Stop.crew_away_of(returned.size(), t["CREW"]["cost"], t)
	var cost: Dictionary = Stop.crew_gain_of(names.size(), t["CREW"]["cost"], t)
	var chore: String = _crew_work(g, t, comm, float(cost["gain"]), float(cost["cap"]))
	if chore != "": notes.append(chore)
	_crew_rest(g, t, comm)
	g["lastCrew"] = comm
	# 내정 훅 자리: domesticStop(g, false, 0).
	stop["result"] = {"passed": false, "gains": gains, "injured": hurt, "dead": dead, "notes": notes}
	var gained: Array[String] = []
	for key: String in gains: gained.append("%s %d" % [t["LOOT_NAME"][key], int(gains[key])])
	Turn._journal(g, "%s에 %s 머물렀다(%s %d명%s). %s.%s" % [place["name"], stay["name"], t["COMM_NAME"][comm], names.size(), ", 정찰 %d명" % scouts_back if scouts_back > 0 else "", ", ".join(gained) if not gained.is_empty() else "빈손", " 부상 %d." % hurt.size() if not hurt.is_empty() else ""])
	var event_log: Dictionary = g.get("eventLog", {})
	if int(g["seg"]) - int(event_log.get("rescue", {}).get("seg", -99)) >= 4 and _rnd(g) < float(p["rescueRate"]):
		var rescue: Dictionary = {"kind": "rescue", "comm": comm}
		if not returned.is_empty(): rescue["who"] = returned[0]
		Turn._card(g, rescue)
	if int(g["seg"]) - int(event_log.get("bitten", {}).get("seg", -99)) >= 3 and not hurt.is_empty() and _rnd(g) < 0.35:
		Turn._card(g, {"kind": "bitten", "comm": comm, "who": hurt[0]})
	_check_stop_promises(g, t, stop["target"], gains)
	_note_target(g, stop["target"])
	return g
