extends RefCounted
## One JSON save slot compatible with the S1a Game object. Invalid text is preserved in a separate
## slot; the original is never deleted by load_slot.

const SAVE_VERSION := 1
const TrainDecor = preload("res://game/train/train_decor.gd")
const Late = preload("res://game/train/turn/turn_late.gd")
const DEFAULT_PATH := "user://s1a_game_v2.json"
const DEFAULT_BROKEN_PATH := "user://s1a_game_broken.json"
const PHASES := ["prep", "travel", "stop", "council", "settle", "end"]
const CREW_COMMS := ["tail", "medtech", "guard", "front"]


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


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
	if g.has("deferred") and g["deferred"] != null and not g["deferred"] is Array:
		return "미뤄 둔 카드 목록이 이상하다"
	if g.has("lateOn") and not g["lateOn"] is bool:
		return "서류 미루기 켜짐 값이 이상하다"
	if g.has("lateCards") and not g["lateCards"] is Array:
		return "미룬 서류 목록이 이상하다"
	for key: String in ["cards", "lateCards", "deferred"]:
		for card: Variant in g.get(key, []) if g.get(key) is Array else []:
			if not card is Dictionary: return "서류 카드가 이상하다"
			if card.has("late") and (not _is_number(card["late"]) or float(card["late"]) != floorf(float(card["late"])) or float(card["late"]) < 0 or float(card["late"]) > Late.LATE.max):
				return "서류 미룬 횟수가 이상하다"
			if key == "lateCards":
				if Late.kind(card) == "" or not _is_number(card.get("uid")) or float(card["uid"]) != floorf(float(card["uid"])) or float(card["uid"]) < 1:
					return "미룬 서류 카드가 이상하다"
				if card.has("comm") and not (t["COMMS"] as Array).has(card["comm"]): return "미룬 서류 칸이 이상하다"
				if card.get("who") != null and not card["who"] is String: return "미룬 서류 대표가 이상하다"
	if g.has("fieldReturns") and g["fieldReturns"] != null:
		var field_returns: Variant = g["fieldReturns"]
		if not (field_returns is Dictionary) or not (field_returns.get("applied") is Dictionary) or not (field_returns.get("records") is Array):
			return "필드 귀환 기록이 이상하다"
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
	file.store_string(JSON.stringify(g))
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
