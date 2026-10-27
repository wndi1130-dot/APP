extends RefCounted
const C = preload("res://game/train/turn/turn_common.gd")
const St = preload("res://game/train/train_state.gd")
const Turn = preload("res://game/train/train_turn.gd")
const Care = preload("res://game/train/turn/turn_settle_care.gd")
const TrainHands = preload("res://game/train/train_hands.gd")
const W = preload("res://game/train/turn/turn_wounds.gd")
const People = preload("res://game/train/turn/turn_people.gd")
const Death = preload("res://game/train/turn/turn_death.gd")
const Needs = preload("res://game/train/turn/turn_needs.gd")
const Field = preload("res://game/politics/field_return.gd")
const Agenda = preload("res://game/politics/council_agenda.gd")
const Vote = preload("res://game/politics/council_vote.gd")
const Ladder = preload("res://game/train/turn/turn_ladder.gd")
const TrainClimate = preload("res://game/train/train_climate.gd")

static func settle(g0: Dictionary, t: Dictionary) -> Dictionary:
	if g0.get("stranded") != null: return C.unsupported(g0, "settle: stranded/trip")
	if g0.get("deathWeight", false): return C.unsupported(g0, "settle: deathWeight")
	for law: String in g0.get("ratify", []):
		if St.law_active(g0, law): return C.unsupported(g0, "dropUnratified: repeal")
	for law: String in g0.get("ratifyRepeal", []):
		if not St.law_active(g0, law): return C.unsupported(g0, "dropUnratified: enact")
	var g: Dictionary = g0.duplicate(true)
	var before: Dictionary = {}
	for key: String in ["coal", "food", "med", "trust", "tension"]: before[key] = g[key]
	before["rel"] = {}
	for comm: String in t["COMMS"]: before["rel"][comm] = g["comms"][comm]["rel"]
	var notes: Array = []
	var f: Dictionary = Turn.forecast(g, t)
	var p: Dictionary = t["P"]
	var parts: Dictionary = Turn.forecast_parts(g, t)
	if float(g["coal"]) - float(f["coal"]) <= 0: return C.unsupported(g0, "settle: enterStranded")
	C.bump_parts(g, "coal", -float(f["coal"]), parts["coal"])
	C.bump_parts(g, "food", -float(f["food"]), parts["food"])
	if bool(g["inStrike"]): C.bump(g, "tension", 3, "strike")
	else: g["comms"]["engine"]["base"][3] += float(p["engineFatigue"])
	if g.get("space") is Dictionary and g["space"].get("giver") != null and float(g["space"].get("step", 0)) > 0: C.bump_rel(g, g["space"]["giver"], float(p["spaceHoldRel"]) * float(g["space"]["step"]), "situation")
	g["forcedRun"] = false
	g["guardEscort"] = false
	Care.medicine(g, t, notes)
	Care.child_settle(g, t, notes)
	Care.heat_settle(g, t, notes)
	# 내정 훅 자리: domesticSettle(g, notes).
	hub_leak_tick(g, t, notes)
	g = Turn.drift(g, t)
	Care.calm_settle(g, t)
	check_due_promises(g, t)
	# arrivalsSettle: gated at the action boundary until the arrivals branch is ported.
	hunger_tick(g, t, notes)
	bite_tick(g, t)
	Needs.tick(g, t, notes)
	People.tick(g, t)
	Care.calm_night(g, t)
	if g.get("council") is Dictionary:
		if not bool(g["council"].get("emergency", false)) and not bool(g["council"].get("martial", false)):
			g["ratify"] = []
			g["ratifyRepeal"] = []
		bribe_detection(g, t)
	leash_tick(g, t)
	ai_leaders(g, t)
	g = Turn.meters(g, t)
	if g["phase"] != "end": riot_tick(g, t, notes)
	for comm: String in t["COMMS"]: g["comms"][comm]["away"] = 0
	# hands.ts handsSettle: the one rule for the hands, the S1a board's and the domestic train's alike (train_hands.gd).
	g = TrainHands.settle(g, t, notes)
	if g["phase"] != "end": g = Turn.check_end(g, t)
	if g["phase"] == "end": return C.unsupported(g0, "settle: finish lookback")
	# S1 disasterSettle stands here (no disasters in S2), then climateSettle: a frozen stretch goes by.
	TrainClimate.settle(g, t)
	Care.lookback(g)
	var receipt: Dictionary = {"rel": {}, "notes": notes}
	for key: String in ["coal", "food", "med", "trust", "tension"]: receipt[key] = float(g[key]) - float(before[key])
	for comm: String in t["COMMS"]: receipt["rel"][comm] = float(g["comms"][comm]["rel"]) - float(before["rel"][comm])
	g["lastSettle"] = receipt
	g["phase"] = "settle"
	return g

static func hub_leak_tick(g: Dictionary, t: Dictionary, notes: Array) -> void:
	if int(g["seg"]) < int(t["P"]["segments"]) - 1 or int(g["seg"]) > int(t["P"]["segments"]): return
	var hub: Dictionary = C.hub(g)
	var total: float = 0
	for comm: String in t["COMMS"]: total += float(g["comms"][comm]["pop"])
	total = maxf(1, total)
	var any: bool = false
	for comm: String in hub["warned"]:
		var share: float = Agenda._depart_share(g, t, comm)
		if share <= 0: continue
		var k: float = share * (float(g["comms"][comm]["pop"]) / total) * float(t["HUB"]["leak"])
		var food: float = maxf(0, floor(float(g["food"]) * k * 10 + 0.5) / 10)
		var med: float = maxf(0, floor(float(g["med"]) * k * 10 + 0.5) / 10)
		if food + med <= 0: continue
		C.bump(g, "food", -food, "hub.stash")
		C.bump(g, "med", -med, "hub.stash")
		if not hub["stash"].has(comm): hub["stash"][comm] = {"food": 0, "med": 0}
		hub["stash"][comm]["food"] += food
		hub["stash"][comm]["med"] += med
		any = true
	if any:
		var line: String = "창고 장부와 자루 수가 안 맞는다. 모자란 건 하필 오래 가는 것들이다."
		notes.append(line)
		C.journal(g, line, "dark")

static func bribe_detection(g: Dictionary, t: Dictionary) -> void:
	for deal: Dictionary in g["council"].get("deals", []):
		var comm: String = deal["comm"]
		if deal["tool"] == "bribe" and not bool(deal.get("refused", false)) and deal.get("label") != "뇌물을 거절당함":
			var s: Dictionary = g["comms"][comm]
			if C.rnd(g) < float(t["BRIBE_EXPOSE"][s["leader"]["trait"]]):
				s["coh"] = clampf(float(s["coh"]) - 0.2, 0, 1)
				s["disgraced"] = true
				C.bump(g, "trust", -10, "leak")
				Field._offend(g, comm)
				C.journal(g, "뇌물이 드러났다. %s의 정당성이 무너지고 열차장도 신임을 잃었다." % s["leader"]["name"], "bad")
		elif deal["tool"] == "favor" and C.rnd(g) < 0.15:
			for other: String in t["COMMS"]:
				if other != comm: C.bump_rel(g, other, -5, "deal")
			C.journal(g, "%s의 표가 빚 때문이었다는 말이 돈다. 공정성 시비가 붙었다." % g["comms"][comm]["leader"]["name"], "bad")
	g["council"] = null

static func check_due_promises(g: Dictionary, t: Dictionary) -> void:
	for comm: String in t["COMMS"]:
		var s: Dictionary = g["comms"][comm]
		var promise: Variant = s.get("promise")
		if not promise is Dictionary or int(promise["due"]) > int(g["seg"]): continue
		var kind: String = promise["cond"]["kind"]
		if promise["kind"] == "fetch" or kind in ["target", "skip_dispatch"]:
			if bool(g["inStrike"]): promise["due"] = int(g["seg"]) + 1
			continue
		# 내정 훅 자리: domesticPromise(g, comm, promise).
		var ok: bool = false
		if kind in ["heat", "ration"]: ok = float(s[kind]) >= float(promise.get("baseline", 0)) + 1
		elif kind == "keep_ration": ok = float(s["ration"]) >= float(promise.get("baseline", 0))
		elif kind in ["give_med", "give_lux"]:
			var resource: String = "med" if kind == "give_med" else "lux"
			var amount: float = float(promise["cond"].get("amount", 0))
			ok = float(g[resource]) >= amount
			if ok: C.bump(g, resource, -amount, "promise")
		if ok: Field._keep_promise(g, t, comm, str(promise.get("label", "")))
		else: Field._break_promise(g, t, comm, str(promise.get("label", "")))

static func hunger_tick(g: Dictionary, t: Dictionary, notes: Array) -> void:
	if float(g["food"]) > 0:
		g["hunger"] = 0
		return
	g["hunger"] = int(g.get("hunger", 0)) + 1
	if int(g["hunger"]) == 1:
		C.card(g, {"kind": "info", "who": "식량이 떨어졌다", "text": "사람들은 허리띠를 졸라매고 버틴다. 3구간을 넘기면 굶어 죽는 사람이 나온다."})
	elif int(g["hunger"]) <= 3: notes.append("굶은 지 %d구간째다." % int(g["hunger"]))
	else:
		var victims: Array = People.pick_victims(g, t, 1, "hunger", g)
		if not victims.is_empty():
			var person: Dictionary = victims[0]
			Death.on_death(g, t, person["community"], [person["name"]])
			C.journal(g, "%s의 %s(%d)이(가) 굶어 죽었다." % [t["COMM_NAME"][person["community"]], person["name"], int(person["age"])], "bad")
			notes.append("굶어 죽은 사람이 나왔다.")

static func bite_tick(g: Dictionary, t: Dictionary) -> void:
	var keep: Array = []
	for b: Dictionary in g.get("hiddenBites", []):
		if int(g["seg"]) >= int(b["due"]):
			var bitten: int = 0
			var waiting: bool = false
			for card: Dictionary in g["cards"]:
				if card["kind"] == "bite_found" and card.get("who") == b["who"]: waiting = true
			if bool(b.get("isolated", false)): C.journal(g, "격리된 %s이(가) 숨을 거뒀다. 일어나기 전에 경비대가 처리했다." % b["who"], "dark")
			elif not bool(b.get("found", false)) or not waiting:
				bitten = 1 + (1 if C.rnd(g) < 0.5 else 0)
				C.bump(g, "tension", 8, "corpse")
				g["fear"] = clampf(float(g["fear"]) + 5, 0, 100)
				C.journal(g, "%s이(가) %s 안에서 일어났다. %d명이 물렸다." % [b["who"], t["COMM_NAME"][b["comm"]], bitten], "bad")
			else:
				keep.append(b)
				continue
			Death.on_death(g, t, b["comm"], [b["who"]], "chosen")
			if bitten > 0:
				g["injured"] += bitten
				W.note_injury(g, t, bitten, "rise", "물림", {"comm": b["comm"]})
			continue
		if not bool(b.get("found", false)) and (St.law_active(g, "patrol") or C.rnd(g) < 0.5):
			b["found"] = true
			C.card(g, {"kind": "bite_found", "comm": b["comm"], "who": b["who"], "text": "귀환 검사에서 드러났다." if St.law_active(g, "patrol") else "열이 오르는 걸 의무장이 알아챘다."})
		keep.append(b)
	g["hiddenBites"] = keep

static func leash_tick(g: Dictionary, _t: Dictionary) -> void:
	var keep: Array = []
	for leash: Dictionary in g["leashes"]:
		var s: Dictionary = g["comms"][leash["comm"]]
		if C.rnd(g) < float(s["grudge"]) * float(leash["weight"]) * 0.04:
			C.bump_rel(g, leash["comm"], -(int(g["seg"]) - int(leash["since"])) * 3, "deal")
			C.bump(g, "trust", -5, "deal")
			Field._offend(g, leash["comm"])
			C.card(g, {"kind": "leash", "comm": leash["comm"]})
			C.journal(g, "%s이(가) 목줄을 끊었다. 협박이 드러났다." % s["leader"]["name"], "bad")
		else: keep.append(leash)
	g["leashes"] = keep

static func ai_leaders(g: Dictionary, t: Dictionary) -> void:
	var cards: int = 0
	var worst: String = ""
	var worst_gap: float = 0
	for comm: String in t["COMMS"]:
		var s: Dictionary = g["comms"][comm]
		if int(s["demandCool"]) > 0:
			s["demandCool"] -= 1
			continue
		var sit: Array = St.situation(g, t, comm)
		var gap: float = float(sit[3]) - 50 + 5 if comm == "engine" and float(sit[3]) > 50 else (maxf(0, 45 - float(sit[0])) if float(s["heat"]) < 4 else 0.0) + (maxf(0, 45 - float(sit[1])) if float(s["ration"]) < 4 else 0.0)
		if gap > worst_gap:
			worst = comm
			worst_gap = gap
	if worst != "" and not C.has_card(g, "demand"):
		C.card(g, {"kind": "demand", "comm": worst})
		var seen: int = maxi(int(g.get("eventLog", {}).get("demand:" + worst, {}).get("n", 0)), int(g.get("eventLog", {}).get("demand:engine_shift", {}).get("n", 0)) if worst == "engine" else 0)
		g["comms"][worst]["demandCool"] = 3 + mini(seen, 2) * 3
		cards += 1
	var engine: Dictionary = g["comms"]["engine"]
	var engine_sit: Array = St.situation(g, t, "engine")
	if int(engine["fervor"]) == 0 and float(engine["rel"]) <= -8 and (float(engine_sit[3]) > 50 or float(engine_sit[1]) < 45) and int(g["seg"]) - int(g["strikeWarned"]) >= 4 and cards < 2:
		g["strikeWarned"] = g["seg"]
		C.card(g, {"kind": "strike_warn", "comm": "engine"})
		cards += 1
	for comm: String in t["COMMS"]:
		var s: Dictionary = g["comms"][comm]
		if int(s["favorCool"]) > 0:
			s["favorCool"] -= 1
			continue
		if cards < 2 and float(s["rel"]) >= 15 and not bool(s["debt"]) and not C.has_card(g, "favor") and C.rnd(g) < 0.3:
			C.card(g, {"kind": "favor", "comm": comm})
			s["favorCool"] = 4
			cards += 1
	for i: int in t["COMMS"].size():
		var comm: String = t["COMMS"][i]
		var s: Dictionary = g["comms"][comm]
		if int(s["agitateCool"]) > 0:
			s["agitateCool"] -= 1
			continue
		if float(s["rel"]) <= -15 and C.rnd(g) < 0.25:
			C.bump(g, "tension", 3, "mood")
			C.bump_rel(g, t["COMMS"][(i + 1) % t["COMMS"].size()], -3, "mood")
			s["agitateCool"] = 3
			C.journal(g, "밤중에 %s에서 수상한 모임이 있었다." % t["COMM_NAME"][comm], "dark")
	if (int(g["seg"]) + 1) % int(t["P"]["sessionEvery"]) != 0: return
	g["session"] += 1
	var options: Array = Agenda.agenda_options(g, t)["options"].filter(func(x: Dictionary) -> bool: return x.get("kind") != "motion")
	g["session"] -= 1
	var seat_map: Dictionary = St.seats(g, t)
	var comms: Array = (t["COMMS"] as Array).duplicate()
	comms.sort_custom(func(a: String, b: String) -> bool: return float(seat_map[a]) > float(seat_map[b]) if seat_map[a] != seat_map[b] else t["COMMS"].find(a) < t["COMMS"].find(b))
	var best: Dictionary = {}
	for comm: String in comms:
		for idx: int in options.size():
			var own: float = float(Vote.stance(g, t, comm, options[idx], false)["score"])
			var hostile: bool = int(g["comms"][comm]["grudge"]) >= 3 and bool(options[idx].get("repeal", false))
			var score: float = own + (3 if hostile else 0)
			if (own >= 3 or (bool(options[idx].get("repeal", false)) and own >= 2) or hostile) and (best.is_empty() or score > float(best["score"])): best = {"c": comm, "idx": idx, "score": score}
	if best.is_empty(): return
	var pick: Dictionary = options[int(best["idx"])].duplicate(true)
	var proposals: Array = []
	var same: bool = false
	for proposal: Dictionary in g["proposals"]:
		if proposal.get("kind") == "motion" or not bool(proposal.get("promise", false)): continue
		if Agenda.same_agenda(proposal, pick): same = true
		else: proposals.append(proposal)
	pick["by"] = best["c"]
	if same: pick["promise"] = true
	proposals.append(pick)
	g["proposals"] = proposals
	C.journal(g, "%s(%s)이(가) 다음 회기 안건을 냈다: %s." % [g["comms"][best["c"]]["leader"]["name"], t["COMM_NAME"][best["c"]], Vote.agenda_title(t, options[int(best["idx"])])])

static func riot_tick(g: Dictionary, t: Dictionary, notes: Array) -> void:
	var p: Dictionary = t["P"]
	var from: float = float(p["riotFrom"])
	if from <= 0: return
	var r: Dictionary = g["riot"]
	var prev: float = float(r["prev"])
	var now: float = float(g["tension"])
	r["prev"] = now
	var ongoing: bool = int(r["stage"]) == 2
	var line: float = Ladder.protest_line(g, t)
	var pending: bool = bool(r.get("pending", false))
	var crossed: bool = not ongoing and ((prev < from and now >= from) or (pending and now >= from))
	# Crossing the riot line in one settle without a protest first: only the protest comes now (정치 흐름 4.1).
	var skipped: bool = crossed and not pending and prev < line
	if skipped: r["pending"] = true
	elif pending and (crossed or now < from): r.erase("pending")
	var starts: bool = crossed and not skipped
	if ongoing or starts:
		if starts:
			r["stage"] = 2
			r["riots"] += 1
		Ladder.riot_fell(g, t, int(p["riotFall"]))
		r["spilled"] += 1
		notes.append("난장판이 이어진다.")
		if not C.has_card(g, "protest"):
			r["riotCards"] += 1
			C.card(g, {"kind": "protest", "comm": "tail", "text": "riot"})
	else:
		r["stage"] = 1 if now >= float(p["protestFrom"]) else 0
		if int(r["spilled"]) > 0 and r["fire"].is_empty():
			notes.append("엎어진 물건 %d더미를 치웠다.%s" % [int(r["spilled"]), " 그을음과 부서진 선반은 남는다." if not r["scorched"].is_empty() else ""])
			r["spilled"] = 0
		# A dismissed protest comes back if tension is still over the line (unresolved); otherwise it is done.
		var again: bool = false
		if r.has("ignoredAt") and int(g["seg"]) - int(r["ignoredAt"]) >= int(Ladder.LADDER["ignoreAgain"]):
			again = now >= line
			r.erase("ignoredAt")
		if ((prev < line and now >= line) or skipped or again) and not C.has_card(g, "protest"):
			r["protests"] += 1
			C.card(g, {"kind": "protest", "comm": "tail", "text": "protest"})
