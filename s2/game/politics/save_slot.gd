extends RefCounted
## One JSON save slot compatible with the S1a Game object. Invalid text is preserved in a separate
## slot; the original is never deleted by load_slot.

const SAVE_VERSION := 1
const TrainDecor = preload("res://game/train/train_decor.gd")
const Late = preload("res://game/train/turn/turn_late.gd")
const RouteState = preload("res://game/train/route_state.gd")
const DEFAULT_PATH := "user://s1a_game_v2.json"
const DEFAULT_BROKEN_PATH := "user://s1a_game_broken.json"
const PHASES := ["prep", "travel", "stop", "council", "settle", "end"]
const CREW_COMMS := ["tail", "medtech", "guard", "front"]


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _natural(value: Variant) -> bool:
	return _is_number(value) and float(value) >= 0 and float(value) == floorf(float(value))


static func _strings(value: Variant) -> bool:
	if not value is Array: return false
	for item: Variant in value:
		if not item is String: return false
	return true


static func _stranded_problem(st: Dictionary, t: Dictionary) -> Variant:
	for key: String in ["since", "turns", "segKm", "atKm", "toNextKm", "lostTrips"]:
		if not _natural(st.get(key)): return "멈춘 열차 수치가 이상하다: " + key
	if not _strings(st.get("seen")): return "멈춘 열차 사건 목록이 이상하다"
	for key: String in ["captainAway", "lamp"]:
		if not st.get(key) is bool: return "멈춘 열차 표식이 이상하다: " + key
	if not st.has("deputy") or (st["deputy"] != null and st["deputy"] not in t["COMMS"]): return "열차를 맡은 칸이 이상하다"
	if not st.has("snow") or st["snow"] not in [null, "all", "guard", "none"]: return "선로의 눈 기록이 이상하다"
	if st.has("burned") and not _is_number(st["burned"]): return "태운 석탄 수치가 이상하다"
	if not st.has("trip") or (st["trip"] != null and not st["trip"] is Dictionary): return "수동차 원정 칸이 이상하다"
	if st["trip"] == null: return null
	var trip: Dictionary = st["trip"]
	for key: String in ["leaderGoes", "forced", "known"]:
		if not trip.get(key) is bool: return "수동차 표식이 이상하다: " + key
	if trip.get("comm") not in t["COMMS"]: return "수동차 칸 이름이 이상하다"
	if not _strings(trip.get("names")): return "수동차 사람 목록이 이상하다"
	for key: String in ["size", "distKm", "extends", "goTurns", "searchTurns", "backTurns", "plannedTurns", "turn"]:
		if not _natural(trip.get(key)): return "수동차 수치가 이상하다: " + key
	if trip.get("phase") not in ["go", "search", "back"]: return "수동차 단계가 이상하다"
	for key: String in ["posKm", "baseFood", "foodShort", "foodOwed"]:
		if not _is_number(trip.get(key)): return "수동차 수치가 이상하다: " + key
	if not trip.has("outcome") or trip["outcome"] not in [null, "coal", "lost"]: return "수동차 결과가 이상하다"
	if not trip.has("promise") or trip["promise"] not in [null, "yes", "no"]: return "수동차 약속이 이상하다"
	return null


static func shape_problem(g: Dictionary, t: Dictionary) -> Variant:
	if not g.get("seed") is String or String(g.get("seed")).is_empty():
		return "시드가 없다"
	if not (g.get("rng") is Dictionary) or not _is_number(g["rng"].get("state")):
		return "난수 상태가 없다"
	if not _is_number(g.get("seg")) or float(g["seg"]) < 0.0 or float(g["seg"]) != floorf(float(g["seg"])):
		return "구간 번호가 이상하다"
	if not g.get("phase") is String or not PHASES.has(g["phase"]):
		return "모르는 단계: %s" % g.get("phase")
	for key: String in ["coal", "food", "med", "trust", "tension"]:
		if not _is_number(g.get(key)):
			return "수치가 이상하다: %s" % key
	if not (g.get("comms") is Dictionary):
		return "공동체 칸이 없다"
	for comm: String in t["COMMS"]:
		var state: Variant = g["comms"].get(comm)
		if not (state is Dictionary) or not _is_number(state.get("pop")) or not _is_number(state.get("rel")):
			return "공동체가 이상하다: %s" % comm
	for key: String in ["cards", "journal"]:
		if not (g.get(key) is Array):
			return "목록이 없다: %s" % key
	if not (g.get("passed") is Dictionary):
		return "통과한 법 칸이 없다"
	if g.has("dom") and g["dom"] != null and not g["dom"] is Dictionary:
		return "내정 칸이 이상하다"
	if g.get("stranded") != null:
		if not g["stranded"] is Dictionary: return "멈춘 열차 칸이 이상하다"
		var problem: Variant = _stranded_problem(g["stranded"], t)
		if problem != null: return problem
	if g.get("budget") is Dictionary:
		for key: String in ["seg", "picked"]:
			if not _is_number(g["budget"].get(key)): return "서류 예산 수치가 이상하다: " + key
	if g.has("deferred") and g["deferred"] != null and not g["deferred"] is Array:
		return "미뤄 둔 카드 목록이 이상하다"
	if g.has("lateOn") and not g["lateOn"] is bool:
		return "서류 미루기 켜짐 값이 이상하다"
	if g.has("lateCards") and not g["lateCards"] is Array:
		return "미룬 서류 목록이 이상하다"
	# Content (event pack) fields: absent or null is none (S1 `??`), anything else must have its shape.
	if g.has("eventPack") and g["eventPack"] != null and not g["eventPack"] is bool:
		return "사건 묶음 켜짐 값이 이상하다"
	for key: String in ["contentFlags", "contentAway", "contentSecrets"]:
		if g.has(key) and g[key] != null and not g[key] is Dictionary:
			return "사건 기록이 이상하다: %s" % key
	for key: String in ["contentInjured", "contentQueue", "contentDeals"]:
		if g.has(key) and g[key] != null and not g[key] is Array:
			return "사건 목록이 이상하다: %s" % key
	for queued: Variant in g.get("contentQueue", []) if g.get("contentQueue") is Array else []:
		if not queued is Dictionary or not queued.get("id") is String or not _is_number(queued.get("at")):
			return "예약된 사건이 이상하다"
	for deal: Variant in g.get("contentDeals", []) if g.get("contentDeals") is Array else []:
		if not deal is Dictionary or not deal.get("id") is String or not deal.get("comm") is String or not _is_number(deal.get("due")):
			return "사건 거래가 이상하다"
	for key: String in ["cards", "lateCards", "deferred"]:
		for card: Variant in g.get(key, []) if g.get(key) is Array else []:
			if not card is Dictionary: return "서류 카드가 이상하다"
			if card.has("late") and (not _is_number(card["late"]) or float(card["late"]) != floorf(float(card["late"])) or float(card["late"]) < 0 or float(card["late"]) > Late.LATE.max):
				return "서류 미룬 횟수가 이상하다"
			if card.has("vals") and card["vals"] != null and not card["vals"] is Dictionary:
				return "사건 카드 값이 이상하다"
			if key == "lateCards":
				if Late.kind(card) == "" or not _is_number(card.get("uid")) or float(card["uid"]) != floorf(float(card["uid"])) or float(card["uid"]) < 1:
					return "미룬 서류 카드가 이상하다"
				if card.has("comm") and not (t["COMMS"] as Array).has(card["comm"]): return "미룬 서류 칸이 이상하다"
				if card.get("who") != null and not card["who"] is String: return "미룬 서류 대표가 이상하다"
	if g.has("fieldReturns") and g["fieldReturns"] != null:
		var field_returns: Variant = g["fieldReturns"]
		if not (field_returns is Dictionary) or not (field_returns.get("applied") is Dictionary) or not (field_returns.get("records") is Array):
			return "필드 귀환 기록이 이상하다"
	if g.has("campaign"):
		var issue: String = RouteState.problem(g, t)
		if issue != "":
			return issue
	return null


static func fill_defaults(g: Dictionary) -> void:
	TrainDecor.migrate(g)
	if not g.has("lateOn"): g["lateOn"] = false
	if not g.has("lateCards"): g["lateCards"] = []
	if not g.has("eventLog") or g["eventLog"] == null:
		g["eventLog"] = {}
	if not g.has("needs") or g["needs"] == null:
		g["needs"] = {}
	if not g.has("emergencyCalls") or g["emergencyCalls"] == null:
		g["emergencyCalls"] = []
	if not g.has("hunger") or g["hunger"] == null:
		g["hunger"] = 0
	if not g.has("linesSeen") or g["linesSeen"] == null:
		g["linesSeen"] = []
	# S1 reads these content fields with `??`: a null one is the same as none.
	for key: String in ["contentAway", "contentFlags", "contentInjured", "contentDeals", "contentQueue", "contentSecrets"]:
		if g.has(key) and g[key] == null: g.erase(key)
	for pile: String in ["cards", "lateCards", "deferred"]:
		for card: Variant in g.get(pile, []) if g.get(pile) is Array else []:
			if card is Dictionary and card.has("vals") and card["vals"] == null: card.erase("vals")
	if g.get("budget") is Dictionary:
		if not g.has("deferred") or g["deferred"] == null:
			g["deferred"] = []
		if not g["budget"].get("stats") is Dictionary:
			g["budget"]["stats"] = {"deferred": {}, "faded": {}, "dropped": {}}
	if g.get("stop") is Dictionary and not bool(g["stop"].get("done", false)) and not CREW_COMMS.has(g["stop"].get("crewComm")):
		g["stop"]["crewComm"] = "guard"


static func read_save(raw: Variant, t: Dictionary) -> Dictionary:
	if not (raw is Dictionary):
		return {"ok": false, "why": "판 자료가 아니다"}
	var game: Dictionary = raw.duplicate(true)
	var version: Variant = game.get("version")
	if not _is_number(version) or float(version) != floorf(float(version)) or int(version) < 1:
		return {"ok": false, "why": "판 번호가 없다"}
	if int(version) > SAVE_VERSION:
		return {"ok": false, "why": "더 새 빌드에서 저장한 판이다(판 번호 %d)" % int(version)}
	# SAVE_VERSION is still 1, so there are no migration steps yet.
	var problem: Variant = shape_problem(game, t)
	if problem != null:
		return {"ok": false, "why": problem}
	fill_defaults(game)
	return {"ok": true, "g": game}


static func save_slot(g: Dictionary, path: String = DEFAULT_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	# Keys keep their order, as S1's JSON does: ties picked by insertion order
	# (laws repealed in the same segment) stay the same after a load.
	file.store_string(JSON.stringify(g, "", false))
	file.close()
	return true


static func save(g: Dictionary, path: String = DEFAULT_PATH) -> bool:
	return save_slot(g, path)


static func _preserve_broken(raw: String, broken_path: String) -> bool:
	var file := FileAccess.open(broken_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(raw)
	file.close()
	return true


static func load_slot(t: Dictionary, path: String = DEFAULT_PATH, broken_path: String = DEFAULT_BROKEN_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"g": null, "why": null}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"g": null, "why": "이 창에선 저장 칸을 읽을 수 없다"}
	var raw := file.get_as_text()
	file.close()
	if raw.is_empty():
		return {"g": null, "why": null}
	var parser := JSON.new()
	var read: Dictionary
	if parser.parse(raw) != OK:
		read = {"ok": false, "why": "저장 글이 깨졌다"}
	else:
		read = read_save(preload("res://game/sim/field_save.gd")._decode(parser.data), t)
	if bool(read["ok"]):
		return {"g": read["g"], "why": null}
	if _preserve_broken(raw, broken_path):
		return {"g": null, "why": "%s. 옛 저장은 따로 남겨 두었다" % read["why"]}
	return {"g": null, "why": read["why"]}


static func load(t: Dictionary, path: String = DEFAULT_PATH, broken_path: String = DEFAULT_BROKEN_PATH) -> Dictionary:
	return load_slot(t, path, broken_path)
