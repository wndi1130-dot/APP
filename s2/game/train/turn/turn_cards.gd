extends RefCounted
## S1 cards.ts choices and function-valued travel effects.
## Internal effect tuples keep their S1 order; no fixture states are consulted.
const C = preload("res://game/train/turn/turn_common.gd")
const St = preload("res://game/train/train_state.gd")
const W = preload("res://game/train/turn/turn_wounds.gd")
const People = preload("res://game/train/turn/turn_people.gd")
const Death = preload("res://game/train/turn/turn_death.gd")
const Travel = preload("res://game/train/turn/turn_travel.gd")
const Field = preload("res://game/politics/field_return.gd")
const RationCut = preload("res://game/train/turn/turn_ration_cut.gd")

static func choice(id: String, label: String, effs: Array, special: String = "", witness: bool = false) -> Dictionary:
	return {"id": id, "label": label, "effs": effs, "special": special, "witness": witness}

static func travel_view(g: Dictionary, t: Dictionary, id: String) -> Dictionary:
	var past: Dictionary = g.get("eventLog", {}).get(id, {})
	var n: int = mini(int(past.get("n", 0)), 3)
	var pick: String = past.get("pick", "")
	var title: String = ""
	var choices: Array = []
	match id:
		"tail_cold":
			title = "꺼진 난로" if past.is_empty() else "또 꺼진 난로"
			choices = [choice("fuel_front", "앞칸 연료를 덜어 온다", [["base", "tail", 0, 5], ["base", "front", 0, -5], ["rel", "tail", 5], ["rel", "front", -(8 + 3 * n)]]), choice("blankets", "담요를 나눈다", [["lux", -(1 + n)], ["rel", "tail", 4]]), choice("endure", "참으라 한다", [["rel", "tail", -(5 + 3 * n)], ["tension", 2 + 2 * n]])]
		"crowd_fight":
			title = "자리 싸움" if past.is_empty() else "또 자리 싸움"
			choices = [choice("guard_break", "경비대가 말린다", [["rel", "tail", -(3 + 2 * n)], ["tension", -3], ["fear", 2]]), choice("widen", "칸을 넓혀 준다", [["base", "tail", 2, -5], ["base", "front", 2, 5], ["rel", "front", -5], ["rel", "tail", 3]]), choice("let_be", "내버려 둔다", [["injured", 1 if past.is_empty() else 2], ["tension", 4 + 2 * n]])]
		"front_curtain":
			title = "앞칸의 커튼" if past.is_empty() else "다시 걸린 커튼"
			choices = [choice("curtain_open", "커튼을 걷게 한다", [["rel", "front", -(6 + 2 * n)], ["rel", "tail", 4]]), choice("side_front", "앞칸 편을 든다", [["rel", "tail", -(4 + 3 * n)], ["rel", "front", 4]]), choice("call_reps", "대표 둘을 부른다", [["lux", -(1 + n)], ["tension", -2], ["trust", 1]])]
		"water_tower":
			title = "얼어붙은 급수탑"
			var sc: String = g.get("lastCrew", "tail")
			var chore: float = float(t["P"]["choreRel"]) if t["CHORE_COMMS"].has(sc) else 0.0
			var hold: Array = [["coal", -2], ["rel", "engine", -(4 + 2 * n)]]
			if pick == "hold_on": hold.append(["base", "engine", 3, 6])
			choices = [choice("burn_melt", "불을 피워 녹인다", [["coal", -3]]), choice("snow_melt", "눈을 녹인다", [["base", sc, 3, t["P"]["snowExposure"]], ["rel", sc, -(4 + 3 * n) + chore]]), choice("hold_on", "다음 역까지 버틴다", hold)]
		"snow_drift":
			title = "눈더미"
			var tail: Array = [["rel", "tail", -(5 + 3 * n)]]
			if pick == "dig_tail": tail.append(["tension", 3])
			choices = [choice("dig_all", "모든 칸이 나눠 판다", [["food", -3], ["rel", "front", -1 if pick == "dig_all" else -3], ["tension", -1]]), choice("dig_tail", "꼬리칸이 판다", tail), choice("plow", "기관차로 밀어붙인다", [["coal", -(4 + n)], ["base", "engine", 3, 4 + 2 * n]])]
		"abandoned_tender":
			title = "측선의 탄수차"
			choices = [choice("tender_take", "석탄을 옮긴다", [["coal", 8]], "risk_injury"), choice("tender_pass", "지나친다", [])]
		"sick_child":
			title = "아이 열병" if past.is_empty() else "열병이 번진다"
			var save: Array = [["rel", "tail", -(4 + 3 * n)], ["rel", "medtech", -2]]
			if pick == "med_save": save.append(["trust", -2])
			choices = [choice("med_use", "의약품을 쓴다", [["med", -3 if pick == "med_use" else -2], ["rel", "tail", 4], ["rel", "medtech", 2]]), choice("med_save", "아껴 둔다", save)]
		"ration_line":
			title = "배급 줄"
			var guard: Array = [["fear", 3], ["rel", "tail", -3], ["rel", "guard", 2]]
			if not past.is_empty(): guard.append(["tension", 2 * n])
			choices = [choice("reshare", "다시 나눈다", [["food", -(4 + n)], ["rel", "tail", 3]]), choice("guard_line", "경비대를 세운다", guard)]
		"guard_frost":
			title = "동상"
			choices = [choice("guard_heat", "경비대 난방을 올린다", [["lever", "guard", "heat", 1], ["rel", "guard", 3]]), choice("watch_less", "경계를 줄인다", [["rel", "guard", 2], ["tension", 2 + n]]), choice("hold_post", "그대로 선다", [["rel", "guard", -(5 + 4 * n)], ["injured", 1]])]
		_: return {}
	return {"title": title, "key": id, "choices": choices}

static func view(g: Dictionary, t: Dictionary, card: Dictionary) -> Dictionary:
	var comm: String = card.get("comm", "tail")
	var s: Dictionary = g["comms"][comm]
	match str(card["kind"]):
		"travel": return travel_view(g, t, card.get("text", ""))
		"info": return {"title": str(card.get("who", "알림")), "choices": [choice("", "알았다", [])]}
		"need_warn":
			if not t["NEEDS"].has(card.get("text")): return {}
			var def: Dictionary = t["NEEDS"][card["text"]]
			var promise: Dictionary = choice("", "약속한다", [], "need_promise")
			promise["log"] = "%s을 정하겠다고 약속했다." % def["title"]
			return {"title": "%s이 필요하다" % def["title"], "choices": [promise, choice("", "두고 본다", [])]}
		"demand":
			var sit: Array = St.situation(g, t, comm)
			if comm == "engine" and float(sit[3]) > 50:
				var past: Dictionary = g.get("eventLog", {}).get("demand:engine_shift", {})
				var n: int = mini(int(past.get("n", 0)), 3)
				return {"title": "화부 교대" if past.is_empty() else "화부 교대, 다시", "key": "demand:engine_shift", "choices": [choice("shift_more", "교대를 늘린다", [["coal", -float(t["P"]["shiftCoal"])], ["base", "engine", 3, -float(t["P"]["shiftRelief"])], ["rel", "engine", 3]]), choice("shift_apprentice", "견습생을 붙인다", [["base", "engine", 3, -5], ["base", "tail", 3, 3], ["rel", "tail", -(2 + 2 * n)]]), choice("refuse", "거절한다", [["fervor", "engine", 1], ["rel", "engine", -(float(t["P"]["refuseRel"]) + 3 * n)]])]}
			var which: String = "ration" if float(s["heat"]) >= 4 else ("heat" if float(s["ration"]) >= 4 or float(sit[0]) < float(sit[1]) else "ration")
			var past: Dictionary = g.get("eventLog", {}).get("demand:" + comm, {})
			var n: int = mini(int(past.get("n", 0)), 3) if past.get("pick") == "refuse" else 0
			return {"title": "난방 요구" if which == "heat" else "배급 요구", "key": "demand:" + comm, "choices": [choice("heat_up" if which == "heat" else "ration_up", "난방을 올린다" if which == "heat" else "배급을 올린다", [["lever", comm, which, 1], ["rel", comm, 2]]), choice("refuse", "거절한다", [["fervor", comm, 1], ["rel", comm, -(float(t["P"]["refuseRel"]) + 3 * n)]])]}
		"favor":
			var again: bool = g.get("eventLog", {}).has("favor:" + comm)
			var costs: Dictionary = {"tail": [["med", -2], ["base", "medtech", 2, 3]], "medtech": [["rel", "front", -3]] if again else [["base", "front", 2, 3]], "guard": [["rel", "engine", -2], ["rel", "tail", -1]] if again else [["rel", "engine", -2]], "front": [["lux", -3 if again else -2]], "engine": [["rel", "tail", -3 if again else -2]]}
			var cost: Array = costs[comm]
			cost.append(["debt", comm])
			return {"title": "사적인 부탁", "key": "favor:" + comm, "choices": [choice("grant", "들어준다", cost, "favor_risk"), choice("refuse", "거절한다", [["rel", comm, -4 if again else -3]])]}
		"rescue":
			var options: Array = []
			if g["passed"].has("no_outsiders"): options = [choice("leave_law", "법대로 두고 온다", [["trust", -1]], "", true)]
			else:
				var past: Dictionary = g.get("eventLog", {}).get("rescue", {})
				var n: int = mini(int(past.get("n", 0)), 3) if past.get("pick") == "leave" else 0
				options = [choice("take_in", "데려온다", [["pop", "tail", 2], ["base", "tail", 2, 3], ["injured", 1], ["rel", "medtech", 3]], "", true), choice("supplies_only", "물자만 받는다", [["food", 3], ["trust", -1], ["rel", "medtech", -3]], "", true), choice("leave", "두고 온다", [["trust", -(1 + n)], ["rel", "medtech", -3]], "", true)]
			return {"title": "부상자", "key": "rescue", "choices": options}
		"bitten":
			var part: String = ["팔을", "다리를", "손을"][int(card["uid"]) % 3]
			return {"title": "물렸다", "key": "bitten", "choices": [choice("cut", part + " 자른다", [["med", -3], ["injured", 1], ["rel", comm, 2]], "", true), choice("hide", "숨겨 준다", [], "hide_bite", true), choice("leave", "두고 온다", [["rel", comm, -8], ["tension", 2]], "leave_bitten", true)]}
		"ration_cut":
			# The tail's demand after 비상식량감축법 stands (결정 091·430, turn_ration_cut.gd).
			var k: Dictionary = t["RATION_CUT"]
			return {"title": "감축 배급 요구", "key": "ration_cut", "choices": [
				choice("cut_spare_tail", "꼬리칸은 뺀다", [["rel", "tail", k["spareRel"]["tail"]], ["rel", "front", k["spareRel"]["front"]]], "cut_spare_tail"),
				choice("cut_front_first", "앞칸이 먼저 낸다", [["rel", "tail", k["frontRel"]["tail"]], ["rel", "front", k["frontRel"]["front"]]], "cut_front_first"),
				choice("refuse", "거절한다", [["rel", "tail", k["refuseRel"]], ["tension", k["refuseTension"]]], "cut_refuse")]}
		"rep_sick":
			return {"title": "대표가 앓는다", "choices": [choice("", "약을 보낸다", [["med", -2], ["rel", comm, 3]], "rep_heal"), choice("", "측근을 만난다", [], "proxy_meet"), choice("", "그냥 둔다", [])] if s.get("sick") is Dictionary else [choice("", "알았다", [])]}
	return {}

static func affordable(g: Dictionary, effs: Array) -> bool:
	for e: Array in effs:
		if e[0] in ["coal", "food", "med", "lux"] and float(e[1]) < 0 and float(g[e[0]]) < -float(e[1]): return false
		if e[0] == "lever" and float(e[3]) > 0 and float(g["comms"][e[1]][e[2]]) >= 4: return false
	return true

static func apply_effects(g: Dictionary, t: Dictionary, effs: Array, from: String, comm: String) -> void:
	for e: Array in effs:
		var kind: String = e[0]
		match kind:
			"coal", "food", "med", "lux", "trust", "tension": C.bump(g, kind, float(e[1]), "card", kind in ["med", "lux"])
			"fear": g["fear"] = clampf(float(g["fear"]) + float(e[1]), 0, 100)
			"injured":
				var before: int = int(g["injured"])
				g["injured"] = maxi(0, before + int(e[1]))
				if int(g["injured"]) > before: W.note_injury(g, t, int(g["injured"]) - before, from, "카드", {"comm": comm})
				else: W.note_relief(g, before - int(g["injured"]))
			"rel": C.bump_rel(g, e[1], float(e[2]), "card")
			"fervor": g["comms"][e[1]]["fervor"] = clampf(float(g["comms"][e[1]]["fervor"]) + float(e[2]), 0, 3)
			"pop": g["comms"][e[1]]["pop"] = maxi(1, int(g["comms"][e[1]]["pop"]) + int(e[2]))
			"base": g["comms"][e[1]]["base"][int(e[2])] += float(e[3])
			"lever": g["comms"][e[1]][e[2]] = clampf(float(g["comms"][e[1]][e[2]]) + float(e[3]), 0, 4)
			"debt": g["comms"][e[1]]["debt"] = true
			"grudge": Field._offend(g, e[1])

static func choose(g0: Dictionary, t: Dictionary, uid: int, index: int) -> Dictionary:
	var card: Dictionary = {}
	for row: Dictionary in g0["cards"]:
		if int(row["uid"]) == uid:
			card = row
			break
	if card.is_empty(): return g0.duplicate(true)
	var v: Dictionary = view(g0, t, card)
	if v.is_empty(): return C.unsupported(g0, "chooseCard: " + str(card["kind"]))
	if index < 0 or index >= v["choices"].size(): return g0.duplicate(true)
	var selected: Dictionary = v["choices"][index]
	if not affordable(g0, selected["effs"]): return g0.duplicate(true)
	if not St.is_s1a(g0) or g0.get("deathWeight", false): return C.unsupported(g0, "chooseCard: optional hooks")
	var g: Dictionary = g0.duplicate(true)
	g["cards"] = g["cards"].filter(func(row: Dictionary) -> bool: return int(row["uid"]) != uid)
	var sources: Dictionary = {"let_be": "brawl", "hold_post": "guard_post", "take_in": "rescue", "cut": "bite_cut"}
	var from: String = sources.get(selected["id"], "bite_cut" if selected["special"] == "bite_cut" else "stop")
	apply_effects(g, t, selected["effs"], from, card.get("comm", ""))
	var comm: String = card.get("comm", "tail")
	match str(selected["special"]):
		"risk_injury":
			if C.rnd(g) < 0.3 + 0.15 * mini(int(g.get("eventLog", {}).get("abandoned_tender", {}).get("n", 0)), 3):
				g["injured"] += 1
				W.note_injury(g, t, 1, "tender", "탄수차", {"comm": comm})
				C.journal(g, "탄수차 그늘에서 무언가가 튀어나왔다. 한 사람이 다쳤다.", "bad")
		"favor_risk":
			g["comms"][comm]["favorCool"] = 4
			if C.rnd(g) < 0.15:
				for other: String in t["COMMS"]:
					if other != comm: C.bump_rel(g, other, -5, "leak")
				C.journal(g, "%s의 부탁을 들어준 게 알려졌다. 공정성 시비가 붙었다." % g["comms"][comm]["leader"]["name"], "bad")
		"hide_bite":
			if not g.has("hiddenBites"): g["hiddenBites"] = []
			g["hiddenBites"].append({"who": card.get("who", "이름 모를 대원"), "comm": comm, "at": g["seg"], "due": int(g["seg"]) + 2})
			C.journal(g, "%s의 상처를 붕대로 감아 태웠다. 아는 사람은 수색대뿐이다." % card.get("who", "대원"), "dark")
		"leave_bitten":
			Field._offend(g, comm)
			g["comms"][comm]["pop"] = maxi(1, int(g["comms"][comm]["pop"]) - 1)
			g["deaths"].append(card.get("who", "이름 모를 대원"))
			Death.log_death(g, [card.get("who", "이름 모를 대원")], "chosen", true, comm)
			C.journal(g, "%s을(를) 역에 두고 왔다." % card.get("who", "대원"), "dark")
		"need_promise":
			var need: Variant = g.get("needs", {}).get(card.get("text", ""))
			if need is Dictionary and not bool(need.get("promised", false)):
				need["promised"] = true
				need["due"] += 1
		"rep_heal": People.recover(g, t, comm, "의무진의 약을 먹고")
		"cut_spare_tail": RationCut.apply(g, t, "spare_tail")
		"cut_front_first": RationCut.apply(g, t, "front_first")
		"cut_refuse": RationCut.apply(g, t, "refuse")
		"proxy_meet": g["comms"][comm]["leader"]["traitShown"] = 2
	# hub.ts registers hubChoose for every accepted card, including non-hub cards.
	var hub: Dictionary = C.hub(g)
	if not hub.has("lines"): hub["lines"] = []
	if not g.has("story"): g["story"] = {"stage": 1, "flags": {}}
	if not g["story"]["flags"].has("hub_split"): g["story"]["flags"]["hub_split"] = {}
	if v.has("key"):
		if not g.has("eventLog"): g["eventLog"] = {}
		var key: String = v["key"]
		g["eventLog"][key] = {"n": int(g["eventLog"].get(key, {}).get("n", 0)) + 1, "seg": g["seg"], "pick": selected["id"] if selected["id"] != "" else selected["label"], "st": Travel.event_state_key(g, t)}
	if not card["kind"] in ["info", "trust_crisis", "leash"]: C.journal(g, selected.get("log", "%s: %s." % [v["title"], selected["label"]]), "dark" if bool(selected["witness"]) else "")
	if bool(selected["witness"]) and g.get("stop") is Dictionary:
		var harsh: bool = selected["special"] in ["leave_bitten", "hide_bite"] or selected["id"] == "stay_put"
		for e: Array in selected["effs"]:
			if e[0] == "trust" and float(e[1]) < 0: harsh = true
		C.bump_rel(g, g["stop"]["crewComm"], -5 if harsh else 3, "card")
	return g
