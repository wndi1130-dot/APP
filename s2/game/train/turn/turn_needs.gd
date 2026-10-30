extends RefCounted
const C = preload("res://game/train/turn/turn_common.gd")
const St = preload("res://game/train/train_state.gd")
const W = preload("res://game/train/turn/turn_wounds.gd")

static func hash_name(value: String) -> int:
	var h: int = 7
	for i: int in value.length(): h = (h * 31 + value.unicode_at(i)) & 0xffffffff
	return h

static func is_open(g: Dictionary, id: String) -> bool:
	match id:
		"coal": return float(g["coal"]) <= 50
		"food": return float(g["food"]) <= 50
		"corpse": return bool(g["corpseIssue"])
		"med": return float(g["injured"]) >= 4
	return false

static func hit(g: Dictionary, t: Dictionary, id: String, hits: int) -> String:
	var def: Dictionary = t["NEEDS"][id]
	if hits == 0: return def["hit"][0]
	if hits == 1:
		var who: Dictionary = {}
		var fallback: Dictionary = {}
		for p: Dictionary in t["PROFILES"]:
			if p["community"] != def["hurtComm"] or St.is_gone(g, p["name"]) or int(p["age"]) < 16: continue
			if fallback.is_empty(): fallback = p
			if not C.is_leader(g, t, p["name"]) and (hash_name("%s:%s" % [g["seed"], id]) + str(p["name"]).length()) % 3 == 0:
				who = p
				break
		if who.is_empty(): who = fallback
		g["injured"] += 1
		W.note_injury(g, t, 1, "brawl", def["title"], {"names": [] if who.is_empty() else [who["name"]], "comm": def["hurtComm"]})
		var lines: Dictionary = {"coal": "난로 차례를 두고 다투다 %s이(가) 꺼진 칸에서 손가락에 동상을 입었다.", "food": "배급 줄에서 밀치다 %s이(가) 넘어져 크게 다쳤다. 상자 몇 개가 또 사라졌다.", "corpse": "덮어 둔 시신을 혼자 옮기던 %s이(가) 언 발판에서 미끄러져 다쳤다. 경비대가 등을 돌린다.", "med": "침상 다툼을 말리던 %s이(가) 밀려 넘어졌다. 의무진이 한 손을 잃었다."}
		return str(lines[id]) % who.get("name", "한 사람")
	if hits == 2:
		var lines: Dictionary = {"coal": "%s이(가) 난방 순번을 다음 회기 거래 조건으로 들고 오겠다고 한다.", "food": "%s이(가) 사라진 상자 목록을 들고 왔다. 다음 회기에 따지겠다고 한다.", "corpse": "%s이(가) \"시신은 누가 치우느냐\"를 다음 회기 첫 말로 꺼내겠다고 한다.", "med": "%s이(가) 이대로는 손을 놓겠다고 한다. 다음 회기에 답을 달라고 한다."}
		return str(lines[id]) % g["comms"][def["hurtComm"]]["leader"]["name"]
	return def["hit"][3 if hits % 2 == 1 else 0]

static func tick(g: Dictionary, t: Dictionary, notes: Array) -> void:
	if not g.has("needs"): g["needs"] = {}
	for id: String in t["NEED_IDS"]:
		var def: Dictionary = t["NEEDS"][id]
		var settled: bool = false
		for law: String in t["LAW_IDS"]:
			if t["LAWS"][law].get("group") == def["group"] and St.law_active(g, law): settled = true
		var state: Variant = g["needs"].get(id)
		if settled or not is_open(g, id):
			if state != null and settled: C.journal(g, "%s이 정해지자 요구가 잦아들었다." % def["title"], "good")
			if state != null and settled and bool(state.get("promised", false)) and int(state["hits"]) == 0:
				C.bump(g, "trust", 3, "promise")
				C.journal(g, "열차장이 약속을 지켰다.", "good")
			g["needs"].erase(id)
			continue
		if state == null:
			g["needs"][id] = {"since": g["seg"], "due": int(g["seg"]) + int(t["NEED_GRACE"]), "hits": 0}
			if not g.has("needAsked"): g["needAsked"] = {}
			C.card(g, {"kind": "need_warn", "text": id, "n": g["needAsked"].get(id, 0)}, t)
			g["needAsked"][id] = int(g["needAsked"].get(id, 0)) + 1
			C.journal(g, "%s이 필요하다는 목소리가 커진다(%d구간 안에)." % [def["title"], int(t["NEED_GRACE"])], "bad")
			continue
		if int(g["seg"]) < int(state["due"]): continue
		if bool(state.get("promised", false)) and int(state["hits"]) == 0:
			C.bump(g, "trust", -float(t["NEED_PROMISE"]["trust"]), "promise")
			C.bump(g, "tension", float(t["NEED_PROMISE"]["tension"]), "promise")
			notes.append("열차장이 약속을 어겼다.")
			C.journal(g, "%s을 정하겠다던 열차장의 약속은 지켜지지 않았다." % def["title"], "bad")
		var hits: int = int(state["hits"])
		if id in ["coal", "food"]: C.bump(g, id, -(3 + hits), "need", id == "food")
		else: C.bump_rel(g, "guard" if id == "corpse" else "medtech", -(3 + hits), "need")
		C.bump(g, "tension", 2 if id == "med" else 3, "need")
		var line: String = hit(g, t, id, hits)
		if hits == 0: C.card(g, {"kind": "info", "who": "기한이 지났다", "text": line + " 법을 정할 때까지 손해가 이어진다."}, t)
		state["hits"] = hits + 1
		C.bump(g, "trust", -2, "need")
		notes.append(line)
		C.journal(g, line, "bad")
