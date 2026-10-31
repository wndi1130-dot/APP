extends RefCounted
## The slice's place beside the train's S1 save. The train wins a torn pair.
## Both slots keep every value's type and every float's digits (field_save.gd's codec): plain
## JSON brings a 9 back as 9.0 and cuts floats to six figures, and a board read back must be
## the board that was saved.

const VERSION := 1
const KIND := "s3_slice"
const PATH := "user://slice_save.json"
const TrainSave = preload("res://game/politics/save_slot.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const FieldArrival = preload("res://game/politics/field_arrival.gd")
const STEPS: Array[String] = ["train", "stop_pick", "field", "receipt", "council", "travel", "arrive", "end"]


static func capture(flow) -> Dictionary:
	var g: Dictionary = flow.train_g
	return {
		"version": VERSION, "kind": KIND, "step": resume_step(g, flow.current()),
		"seg": int(g.get("seg", 0)), "applied": applied_ids(g),
		"contract": flow.contract.duplicate(true), "receipt": flow.receipt.duplicate(true),
		"passed": flow.passed, "result_reason": String(flow.result.get("reason", "")),
	}


static func applied_ids(g: Dictionary) -> Array:
	var returns := _returns(g)
	var ids: Array = (returns.get("applied", {}) as Dictionary).keys()
	ids.sort()
	return ids


static func _returns(g: Dictionary) -> Dictionary:
	return g["fieldReturns"] if g.get("fieldReturns") is Dictionary else {}


## A left session still says "opened"; its result and phase say it was left.
static func step_of_board(g: Dictionary) -> String:
	var phase := String(g.get("phase", ""))
	if phase == "end":
		return "end"
	var returns := _returns(g)
	var records: Array = returns.get("records", [])
	var special: Variant = returns.get("special")
	if phase == "council" and special is Dictionary and special.get("status") == "opened":
		return "council"
	if not records.is_empty():
		if FieldArrival.second_station_reached(g):
			return "arrive"
		if special is Dictionary and (special.get("status") == "skipped" or special.get("result") is Dictionary):
			return "travel"
		return "receipt"
	var stop: Variant = g.get("stop")
	if stop is Dictionary and bool(stop.get("done", false)):
		return "travel"
	return "stop_pick" if phase == "stop" else "train"


## A return or a vote can be saved before its screen has changed.
static func resume_step(g: Dictionary, wanted: String) -> String:
	var board := step_of_board(g)
	if board == "end" or board == "council" or not STEPS.has(wanted):
		return board
	return board if STEPS.find(board) > STEPS.find(wanted) else wanted


static func _shape(d: Dictionary) -> bool:
	var version: Variant = d.get("version")
	var seg: Variant = d.get("seg")
	if not (version is int or version is float) or version != VERSION:
		return false
	if d.get("kind") != KIND or not d.get("step") is String or not STEPS.has(d["step"]):
		return false
	if not (seg is int or seg is float) or not is_finite(float(seg)) or float(seg) < 0.0 or float(seg) != floorf(float(seg)):
		return false
	if not d.get("applied") is Array or not d.get("contract") is Dictionary or not d.get("receipt") is Dictionary:
		return false
	if not d.get("passed") is bool or not d.get("result_reason") is String:
		return false
	var seen: Dictionary = {}
	for id: Variant in d["applied"]:
		if not id is String or seen.has(id):
			return false
		seen[id] = true
	return true


static func _parse(at: String) -> Dictionary:
	if not FileAccess.file_exists(at):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(at)) != OK or not json.data is Dictionary:
		return {}
	var decoded: Dictionary = FieldSave._decode(json.data)
	return decoded


static func write(d: Dictionary, path: String = PATH) -> bool:
	if not _shape(d):
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(_text(d))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	return error == OK and _replace(path)


## The S1 board as it is, through the same temporary-file boundary as the slice slot.
static func write_train(g: Dictionary, path: String = TrainSave.DEFAULT_PATH) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(_text(g))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	return error == OK and _replace(path)


static func _text(d: Dictionary) -> String:
	return JSON.stringify(FieldSave._encode(d), "", true, true)


static func _replace(path: String) -> bool:
	var backup := path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup) != OK:
			return false
		if DirAccess.rename_absolute(path, backup) != OK:
			return false
	if DirAccess.rename_absolute(path + ".tmp", path) == OK:
		return true
	if not FileAccess.file_exists(path) and FileAccess.file_exists(backup):
		DirAccess.rename_absolute(backup, path)
	return false


static func read(path: String = PATH) -> Dictionary:
	for at: String in [path, path + ".bak"]:
		var d := _parse(at)
		if _shape(d):
			return d
	return {}


static func clear(path: String = PATH) -> void:
	for at: String in [path, path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(at):
			DirAccess.remove_absolute(at)


## Read through S1's shape check without writing its global broken-save slot.
static func _train(path: String, t: Dictionary) -> Dictionary:
	for at: String in [path, path + ".bak"]:
		var loaded: Dictionary = TrainSave.read_save(_parse(at), t)
		if bool(loaded.get("ok", false)):
			var g: Dictionary = loaded["g"]
			var valid: bool = true
			for record: Variant in _returns(g).get("records", []):
				if not record is Dictionary or not record.get("receiptId") is String or not (record.get("seg") is int or record.get("seg") is float):
					valid = false
			if valid:
				return g
	return {}


## S1 keeps the whole canonical receipt as the applied id's fingerprint.
static func receipt_of_board(g: Dictionary) -> Dictionary:
	var returns := _returns(g)
	var records: Array = returns.get("records", [])
	if records.is_empty():
		return {}
	var id := String(records[0].get("receiptId", ""))
	var raw: Variant = (returns.get("applied", {}) as Dictionary).get(id)
	if not raw is String:
		return {}
	var json := JSON.new()
	if json.parse(raw) != OK or not json.data is Dictionary:
		return {}
	var receipt: Dictionary = json.data
	return receipt if receipt.get("receiptId") == id else {}


static func pick(slice_path: String, train_path: String, t: Dictionary) -> Dictionary:
	var d := read(slice_path)
	if d.is_empty():
		return {}
	var g := _train(train_path, t)
	if g.is_empty() or String(g.get("phase", "")) == "end":
		return {}
	var saved_ids: Array = d["applied"].duplicate()
	saved_ids.sort()
	var torn: bool = int(d["seg"]) != int(g["seg"]) or saved_ids != applied_ids(g)
	var at := step_of_board(g) if torn else resume_step(g, String(d["step"]))
	if at == "end":
		return {}
	var receipt := receipt_of_board(g)
	# The train keeps the receipt as S1's canonical text; the slice slot keeps its types.
	if not torn and not receipt.is_empty() and d["receipt"].get("receiptId") == receipt.get("receiptId"):
		receipt = d["receipt"].duplicate(true)
	var contract: Dictionary = d["contract"].duplicate(true)
	if not contract.is_empty():
		if not receipt.is_empty():
			if contract.get("departureId") != receipt.get("departureId"):
				contract = {}
		elif int(contract.get("segment", -1)) != int(g["seg"]):
			contract = {}
	var stop: Dictionary = g.get("stop", {}) if g.get("stop") is Dictionary else {}
	var passed: bool = applied_ids(g).is_empty() and bool(stop.get("done", false))
	var reason := String(receipt.get("endReason", ""))
	if not torn and String(d["result_reason"]) != "" and d["receipt"].get("receiptId") == receipt.get("receiptId"):
		reason = String(d["result_reason"])
	return {
		"g": g, "step": at, "contract": contract, "receipt": receipt, "passed": passed,
		"result_reason": reason, "reconciled": torn,
	}
