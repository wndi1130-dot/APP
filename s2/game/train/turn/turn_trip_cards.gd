extends RefCounted
## S1 stranded_cards.ts. All words and effect order belong to the rules.
const S = preload("res://game/train/turn/turn_stranded.gd")

static func _speaker(g: Dictionary, t: Dictionary, comm: String) -> Dictionary:
	return {"name": g["comms"][comm]["leader"]["name"], "role": t["REP_ROLE"][comm], "comm": comm}

static func _who(t: Dictionary, comm: String) -> String:
	var name: String = t["COMM_NAME"][comm]
	return name + S.josa(name, "이/가")

static func _choice(label: String, line: String, effs: Array, special: String = "", say: String = "") -> Dictionary:
	return {"id": "", "label": label, "log": line, "effs": effs, "special": special, "witness": false, "say": say}

static func _send_choices(g: Dictionary, t: Dictionary, crew_label: String, wait_label: String, wait_say: String, tension: float, crew_log: String, captain_log: String, wait_log: String) -> Array:
	var out: Array = []
	var crew: Variant = S.trip_plan(g, t, "crew") if S.crew_allowed(g, t) else null
	var cap: Variant = S.trip_plan(g, t, "captain")
	if crew != null:
		var choice: Dictionary = _choice(crew_label, crew_log, [], "trip_go_crew", "살아서 돌아와라. 그것만 하면 된다.")
		choice["extra"] = ["%d턴 예정" % int(crew["total"]), "식량 −%d" % int(crew["food"]), "%s %d명이 자리를 비운다" % [t["COMM_NAME"][crew["comm"]], crew["names"].size()], "돌아오면 %s 관계 +%d" % [t["COMM_NAME"][crew["comm"]], int(t["P"]["tripRelCrew"])]]
		out.append(choice)
	if cap != null:
		var dep: String = S.deputy_of(g, t)
		var choice: Dictionary = _choice("내가 간다", captain_log, [["rel", dep, t["P"]["tripRelDeputy"]]], "trip_go_captain", "내가 간다. 돌아올 때까지 %s 맡는다." % _who(t, dep))
		choice["extra"] = ["%d턴 예정" % int(cap["total"]), "식량 −%d" % int(cap["food"]), "열차장이 없는 동안 회기가 닫힌다"]
		out.append(choice)
	out.append(_choice(wait_label, wait_log, [["tension", tension]] if tension > 0 else [], "trip_stay", wait_say))
	return out

static func view(g: Dictionary, t: Dictionary, card: Dictionary) -> Dictionary:
	var p: Dictionary = t["P"]
	match str(card["kind"]):
		"trip_depart":
			var km: float = float(g["stranded"]["toNextKm"]) if g.get("stranded") != null else 0.0
			var crew: Variant = S.trip_plan(g, t, "crew") if S.crew_allowed(g, t) else null
			var comm: String = crew["comm"] if crew != null else S.deputy_of(g, t)
			var body: String = ("다음 역까지 %dkm다. %s에서 %d명이 손을 들었다. 자루 둘과 나무 상자 하나를 수동차에 싣는다. %s" % [int(km), t["COMM_NAME"][crew["comm"]], crew["names"].size(), S.support_line_text(g, t)]) if crew != null else ("다음 역까지 %dkm다. 수동차 하나, 자루 둘. 아무도 열차장 대신 가겠다고 나서지 않는다. %s" % [int(km), S.support_line_text(g, t)])
			return {"title": "수동차", "speaker": _speaker(g, t, comm), "body": body, "focus": comm, "required": true,
				"choices": _send_choices(g, t, "수색대를 보낸다", "아직 안 보낸다", "하루만 더 본다.", float(p["tripWaitTension"]), "수동차에 수색대를 태워 보냈다.", "수동차에 직접 올랐다.", "수동차 출발을 미뤘다.")}
		"trip_return":
			var trip: Variant = g["stranded"]["trip"] if g.get("stranded") != null else null
			if trip == null: return {"title": "수동차", "body": "수동차는 빈 선로 위에 서 있다.", "choices": [_choice("알았다", "수동차가 빈 선로에 서 있는 것을 봤다.", [])], "required": true}
			var effs: Array = [["coal", p["tripCoal"]]]
			if bool(trip["leaderGoes"]) and bool(trip["forced"]): effs.append(["trust", p["tripTrustForced"]])
			if not bool(trip["leaderGoes"]): effs.append(["rel", trip["comm"], p["tripRelCrew"]])
			if trip["promise"] == "yes":
				if float(g["lux"]) >= float(p["promiseLux"]): effs.append_array([["lux", -float(p["promiseLux"])], ["rel", trip["comm"], p["promiseRel"]]])
				else: effs.append(["trust", p["promiseBrokenTrust"]])
			return {"title": "수동차가 돌아왔다", "speaker": _speaker(g, t, trip["comm"]), "focus": trip["comm"], "required": true,
				"body": "◂ 수동차가 어둠 속에서 나타났다. 자루 둘이 석탄으로 불룩하다. %d턴 만이다." % int(card["n"] if card.get("n") != null else trip["turn"]),
				"choices": [_choice("불을 넣는다", "돌아온 수동차의 석탄으로 불을 넣었다.", effs, "trip_fire", "불을 넣어라. 내일 아침에 간다." if bool(trip["leaderGoes"]) else "%s 해냈다. 오늘은 그 칸부터 먹는다." % _who(t, trip["comm"]))]}
		"trip_lost":
			var comm: String = str(card["comm"]) if card.get("comm") != null else "tail"
			var n: int = (str(card["who"]) if card.get("who") != null else "").split(",", false).size()
			var gone: String = "%d명을" % n if n > 0 else "수동차를"
			return {"title": "돌아오지 않았다", "speaker": _speaker(g, t, comm), "focus": comm, "required": true,
				"body": "돌아올 날이 지났다. 선로 끝에 아무것도 없다. %s 대표가 종이에 적어 둔 이름 %d개를 일지에 옮긴다. %s" % [t["COMM_NAME"][comm], n, S.support_line_text(g, t)],
				"choices": _send_choices(g, t, "다시 보낸다", "기다린다", "(열차장은 종이의 이름을 본다.)", 0, "돌아오지 않은 %s 찾으러 수색대를 다시 보냈다." % gone, "돌아오지 않은 %s 찾으러 직접 나섰다." % gone, "돌아오지 않은 %s 더 기다리기로 했다." % gone)}
		"trip_extend":
			var comm: String = str(card["comm"]) if card.get("comm") != null else "tail"
			return {"title": "무전", "speaker": _speaker(g, t, comm), "focus": comm, "required": true,
				"body": "무전이 짧게 왔다. 역에 석탄이 없다. %dkm를 더 간다. 식량 %d이 더 든다." % [int(p["extendKm"]), int(card.get("n", 0))],
				"choices": [_choice("알았다", "더 간다는 수동차 무전에 불을 아끼며 기다리기로 했다.", [], "", "기다린다. 불을 아껴라.")]}
	return {}

static func choose(g: Dictionary, t: Dictionary, choice: Dictionary) -> void:
	match str(choice["special"]):
		"trip_go_crew": S.start_trip(g, t, "crew")
		"trip_go_captain": S.start_trip(g, t, "captain")
		"trip_fire": S.return_trip(g, t)

static func filter_view(g: Dictionary, card: Dictionary, v: Dictionary) -> Dictionary:
	if g.get("stranded") == null or not bool(g["stranded"]["captainAway"]) or v.is_empty(): return v
	var choices: Array = v["choices"]
	if card["kind"] in ["tension_crisis", "protest"]: choices = choices.filter(func(c: Dictionary) -> bool: return c["label"] != "경비대를 푼다")
	elif card["kind"] == "content" and card.get("text") == "ev_str_snow": choices = choices.filter(func(c: Dictionary) -> bool: return c.get("special") != "content:c_guard_only")
	if choices.is_empty(): return v
	var out: Dictionary = v.duplicate(true)
	out["choices"] = choices
	return out
