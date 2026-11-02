extends RefCounted
const C = preload("res://game/train/turn/turn_common.gd")
const St = preload("res://game/train/train_state.gd")
const W = preload("res://game/train/turn/turn_wounds.gd")
const Death = preload("res://game/train/turn/turn_death.gd")
const People = preload("res://game/train/turn/turn_people.gd")

static func medicine(g: Dictionary, t: Dictionary, notes: Array) -> void:
	W.reconcile(g, t)
	W.rebalance(g, t)
	W.tick(g, t, notes, St.law_mult(g, t, "medMult"))
	W.rebalance(g, t)
	var kin: float = St.pyre_count(g) - float(g.get("pyre", 0))
	var weight: float = float(g.get("pyre", 0)) + 2 * kin
	if weight > 0 and C.rnd(g) < minf(0.3, float(t["P"]["storeRisk"]) * weight):
		var in_kin: bool = kin > 0 and C.rnd(g) < 2 * kin / weight
		if in_kin: Death.take_kin_body(g, t)
		else: g["pyre"] = int(g.get("pyre", 0)) - 1
		g["injured"] += 1
		W.note_injury(g, t, 1, "rise", "살던 칸" if in_kin else "냉동칸")
		C.bump(g, "tension", 5, "corpse")
		C.journal(g, "칸에 두었던 시신 하나가 일어났다. 한 명이 다쳤다." if in_kin else "냉동칸에서 태우려고 기다리던 시신 하나가 일어났다. 경비 하나가 다쳤다.", "bad")
	if float(g["stored"]) > 0 and C.rnd(g) < minf(0.3, float(t["P"]["storeRisk"]) * float(g["stored"])):
		g["injured"] += 2
		W.note_injury(g, t, 2, "thaw", "냉동칸")
		C.bump(g, "tension", 8, "corpse")
		g["stored"] = 0
		C.journal(g, "냉동칸의 시신이 녹아 일어났다. 두 명이 다쳤다.", "bad")

static func child_settle(g: Dictionary, t: Dictionary, notes: Array) -> void:
	if not St.law_active(g, "child_labor"): return
	var half: bool = false
	for law: String in t["EDU_LAWS"]:
		if St.law_active(g, law): half = true
	var d: float = 0.5 if half else 1.0
	C.bump_rel(g, "medtech", -d, "child")
	var lines: Array = ["의무진이 승강장 일을 적어 두었다. 의무진 관계 −{d}.", "의무진은 이번 구간에도 말이 없었다. 의무진 관계 −{d}.", "의무칸 문에 동상 걸린 손의 수가 적혔다. 의무진 관계 −{d}."]
	notes.append(str(lines[int(g["seg"]) % lines.size()]).replace("{d}", "0.5" if half else "1"))

static func heat_settle(g: Dictionary, t: Dictionary, notes: Array) -> void:
	if not St.law_active(g, "heat_quota"): return
	var d: Dictionary = t["D"]
	if float(d["heatAllocRel"]) > 0:
		for comm: String in ["tail", "medtech"]: C.bump_rel(g, comm, -float(d["heatAllocRel"]), "heat_quota")
		var lines: Array = ["난방 배당표가 꼬리칸과 의무칸에 돌았다. 꼬리칸·의무진 관계 −{d}.", "배당표를 받은 두 칸의 말수가 줄었다. 꼬리칸·의무진 관계 −{d}.", "꼬리칸이 배당표를 적어 두었다. 꼬리칸·의무진 관계 −{d}."]
		notes.append(str(lines[int(g["seg"]) % lines.size()]).replace("{d}", str(int(d["heatAllocRel"])) if float(d["heatAllocRel"]) == floor(float(d["heatAllocRel"])) else str(d["heatAllocRel"])))
	if float(d["heatAllocDeath"]) <= 0: return
	var lost: int = 0
	for comm: String in ["tail", "medtech", "guard"]:
		if St.situation(g, t, comm)[0] >= float(d["heatAllocWarm"]) or C.rnd(g) >= float(d["heatAllocDeath"]): continue
		var pool: Array = []
		for p: Dictionary in t["PROFILES"]:
			if p["community"] == comm and int(p["age"]) >= 16 and int(p["age"]) <= 64 and p["name"] != g["comms"][comm]["leader"]["name"] and not St.is_gone(g, p["name"]): pool.append(p)
		if pool.is_empty(): continue
		Death.on_death(g, t, comm, [pool[int(floor(C.rnd(g) * pool.size()))]["name"]], "other", false, true)
		lost += 1
	if lost > 0:
		var line: String = "불을 줄인 밤, 한 사람을 잃었다." if lost == 1 else "난로가 식은 칸에서 밤사이 %d명을 잃었다." % lost
		C.journal(g, line, "bad")
		notes.append(line)

static func calm_settle(g: Dictionary, t: Dictionary) -> void:
	if not g.has("calm"): g["calm"] = {}
	var c: Dictionary = g["calm"]
	var p: Dictionary = t["CALM"]
	if St.law_active(g, "evening_pot"):
		var was: bool = bool(c.get("potOn", float(g["coal"]) > float(p["potOffCoal"])))
		if was and float(g["coal"]) <= float(p["potOffCoal"]):
			c["potOn"] = false
			for k: String in t["COMMS"]:
				if float(g["comms"][k]["rel"]) <= float(p["potRelLine"]): C.bump_rel(g, k, float(p["potOffRel"]), "calm.pot")
			C.journal(g, "저녁 솥불이 꺼졌다. 석탄이 모자란다.", "bad")
		elif not was and float(g["coal"]) >= float(p["potOnCoal"]):
			c["potOn"] = true
			c["potSegs"] = 0
			C.journal(g, "저녁 솥불을 다시 켰다.", "good")
		else: c["potOn"] = was
		if bool(c["potOn"]):
			var lifted: String = ""
			for k: String in t["COMMS"]:
				if float(g["comms"][k]["rel"]) <= float(p["potRelLine"]):
					C.bump_rel(g, k, float(p["potRel"]), "calm.pot")
					if lifted == "" or float(g["comms"][k]["rel"]) < float(g["comms"][lifted]["rel"]): lifted = k
			c["potSegs"] = int(c.get("potSegs", 0)) + 1
			if lifted != "" and int(c["potSegs"]) % int(p["noteEvery"]) == 0: C.journal(g, "저녁 솥불 덕에 %s의 말이 조금 누그러졌다." % t["COMM_NAME"][lifted], "good")
	if St.law_active(g, "wall_ledger"):
		var level: String = St.ledger_level(g, t)
		if level == "rich" and float(g["trust"]) < float(p["trustCap"]): C.put(g, "trust", minf(float(p["trustCap"]), float(g["trust"]) + float(p["richTrust"])), "calm.ledger")
		elif level == "poor": C.bump_rel(g, "tail", float(p["poorRel"]), "calm.ledger")
		c["ledgerSegs"] = int(c.get("ledgerSegs", 0)) + 1 if c.get("ledger") == level else 0
		if c.get("ledger") != level:
			if level == "poor": C.journal(g, "벽의 숫자가 날마다 줄어든다. 꼬리칸이 그 앞에 오래 서 있다.", "bad")
			elif c.get("ledger") == "poor": C.journal(g, "벽의 숫자가 다시 늘었다. 꼬리칸이 한숨을 돌린다.", "good")
		elif level == "rich" and int(c["ledgerSegs"]) > 0 and int(c["ledgerSegs"]) % int(p["noteEvery"]) == 0: C.journal(g, "벽의 숫자를 보고 잠드는 사람이 늘었다.", "good")
		c["ledger"] = level

static func calm_night(g: Dictionary, t: Dictionary) -> void:
	if not St.law_active(g, "night_of_names"): return
	if not g.has("calm"): g["calm"] = {}
	var c: Dictionary = g["calm"]
	var p: Dictionary = t["CALM"]
	var fresh: Array = []
	for d: Dictionary in g.get("deathLog", []):
		if int(d["seg"]) > int(c.get("nightSeg", int(g["seg"]) - 1)) and int(d["seg"]) <= int(g["seg"]): fresh.append(d)
	if fresh.is_empty(): return
	c["nightSeg"] = g["seg"]
	if float(g["coal"]) <= float(p["nightMinCoal"]):
		C.journal(g, "이름을 부를 불이 없었다.", "bad")
		return
	c["nights"] = int(c.get("nights", 0)) + 1
	var k: float = (0.5 if int(c["nights"]) >= int(p["nightHalfFrom"]) else 1.0) * (0.5 if float(g["lux"]) <= 0 else 1.0)
	C.bump(g, "coal", -float(p["nightCoal"]), "calm.night")
	C.bump(g, "lux", -float(p["nightLux"]), "calm.night", true)
	g["fear"] = clampf(float(g["fear"]) + float(p["nightFear"]) * k, 0, 100)
	C.bump(g, "tension", float(p["nightTension"]) * k, "calm.night")
	var comms: Array = []
	var names: Array = []
	var chosen: bool = false
	for d: Dictionary in fresh:
		names.append(d["name"])
		chosen = chosen or d["cause"] != "other"
		if d.has("comm") and not comms.has(d["comm"]): comms.append(d["comm"])
	for comm: String in comms: C.bump_rel(g, comm, float(p["nightRel"]) * k, "calm.night")
	if chosen: C.bump(g, "trust", float(p["chosenTrust"]), "calm.night")
	C.journal(g, "떠난 사람의 밤. 식당칸에 모여 %s의 이름을 불렀다.%s" % [", ".join(names), " 그중에는 열차장이 고른 죽음이 있었다." if chosen else ""], "bad" if chosen else "good")

static func lookback(g: Dictionary) -> void:
	if not g.has("look"): g["look"] = {"low": {}, "skip": {}, "coalStops": 0}
	var look: Dictionary = g["look"]
	for res: String in ["coal", "food"]:
		if float(g[res]) <= (15 if res == "coal" else 25) and not look["low"].has(res): look["low"][res] = g["seg"]
	var taken: Dictionary = {"tailHeat": float(g["comms"]["tail"]["heat"]) < 2, "heatQuota": St.law_active(g, "heat_quota"), "tailRation": float(g["comms"]["tail"]["ration"]) < 2, "contribution": St.law_active(g, "contribution_ration"), "noOutsiders": St.law_active(g, "no_outsiders"), "breakdown": false}
	for key: String in taken:
		if bool(taken[key]) and not look["skip"].has(key): look["skip"][key] = g["seg"]
