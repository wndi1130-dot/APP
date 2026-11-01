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
const FieldReceipt = preload("res://game/sim/receipt.gd")
const FieldArrival = preload("res://game/politics/field_arrival.gd")
const RouteState = preload("res://game/train/route_state.gd")
const CampaignRoute = preload("res://game/train/campaign_route.gd")
const FieldReturn = preload("res://game/politics/field_return.gd")
const STEPS: Array[String] = ["train", "stop_pick", "field", "receipt", "council", "travel", "arrive", "end"]


static func capture(flow) -> Dictionary:
	var g: Dictionary = flow.train_g
	var captured: Dictionary = {
		"version": VERSION, "kind": KIND, "step": resume_step(g, flow.current()),
		"run": flow.run, "train_sha": _text(g).sha256_text(),
		"seg": int(g.get("seg", 0)), "applied": applied_ids(g),
		"contract": flow.contract.duplicate(true), "receipt": flow.receipt.duplicate(true),
		"passed": flow.passed, "result_reason": String(flow.result.get("reason", "")),
	}
	if RouteState.is_campaign(g):
		captured["mode"] = "campaign"
		captured["visit_id"] = String(g["campaign"]["visit"].get("id", ""))
		captured["passed"] = g["campaign"]["visit"].get("result") == "passed"
	return captured


static func applied_ids(g: Dictionary) -> Array:
	var returns := _returns(g)
	var ids: Array = (returns.get("applied", {}) as Dictionary).keys()
	ids.sort()
	return ids


static func _returns(g: Dictionary) -> Dictionary:
	return g["fieldReturns"] if g.get("fieldReturns") is Dictionary else {}


## A left session still says "opened"; its result and phase say it was left.
static func step_of_board(g: Dictionary) -> String:
	if RouteState.is_campaign(g):
		return _campaign_step(g)
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
	if RouteState.is_campaign(g):
		var at: String = step_of_board(g)
		return "field" if at == "stop_pick" and wanted == "field" else at
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
	if not d.get("run") is String or not d.get("train_sha") is String:
		return false
	var seen: Dictionary = {}
	for id: Variant in d["applied"]:
		if not id is String or seen.has(id):
			return false
		seen[id] = true
	return true


static func _parse(at: String, source: Dictionary = {}) -> Dictionary:
	if not FileAccess.file_exists(at):
		return {}
	var text := FileAccess.get_file_as_string(at)
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {}
	var decoded: Dictionary = FieldSave._decode(json.data)
	source["train_sha"] = text.sha256_text()
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
static func write_train(g: Dictionary, path: String = TrainSave.DEFAULT_PATH, written: Dictionary = {}) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	var text := _text(g)
	file.store_string(text)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or not _replace(path, true):
		return false
	written["train_sha"] = text.sha256_text()
	return true


## Keys keep their order, as S1's JSON and save_slot.gd do: ties picked by insertion order
## (laws repealed in the same segment) stay the same after a resume.
static func _text(d: Dictionary) -> String:
	return JSON.stringify(FieldSave._encode(d), "", false, true)


static func _replace(path: String, train_slot: bool = false) -> bool:
	var backup := path + ".bak"
	if FileAccess.file_exists(path):
		var previous := _parse(path)
		var valid: bool = not previous.is_empty() and (previous.get("seg") is int or previous.get("seg") is float) if train_slot else _shape(previous)
		var moved := backup if valid else path + ".broken"
		if FileAccess.file_exists(moved) and DirAccess.remove_absolute(moved) != OK:
			return false
		if DirAccess.rename_absolute(path, moved) != OK:
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
	for at: String in [path, path + ".tmp", path + ".bak", path + ".broken"]:
		if FileAccess.file_exists(at):
			DirAccess.remove_absolute(at)


## Read through S1's shape check without writing its global broken-save slot.
static func _train(path: String, t: Dictionary, source: Dictionary = {}) -> Dictionary:
	for at: String in [path, path + ".bak"]:
		var loaded: Dictionary = TrainSave.read_save(_parse(at, source), t)
		if bool(loaded.get("ok", false)):
			var g: Dictionary = loaded["g"]
			if g.has("campaign") and RouteState.problem(g, t) != "":
				return {}
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
	if RouteState.is_campaign(g):
		var record: Dictionary = RouteState.record_for_visit(g)
		records = [record] if not record.is_empty() else []
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


static func receipt_of_field(saved: Dictionary) -> Dictionary:
	var ended = FieldReceipt.new(String(saved.get("place", "")))
	FieldSave._put_receipt(ended, saved.get("receipt_state", {}))
	return ended.to_dict()


static func pick(slice_path: String, train_path: String, t: Dictionary, field_path: String = FieldSave.PATH) -> Dictionary:
	var d := read(slice_path)
	var source: Dictionary = {}
	var g := _train(train_path, t, source)
	if RouteState.is_campaign(g):
		return _pick_campaign(d, g, source, field_path)
	if d.is_empty():
		return {}
	if g.is_empty() or String(g.get("phase", "")) == "end":
		return {}
	var saved_ids: Array = d["applied"].duplicate()
	saved_ids.sort()
	var torn: bool = int(d["seg"]) != int(g["seg"]) or saved_ids != applied_ids(g) or d["train_sha"] != source["train_sha"]
	var at := step_of_board(g) if torn else resume_step(g, String(d["step"]))
	if at == "end":
		return {}
	var receipt := receipt_of_board(g)
	# The train keeps the receipt as S1's canonical text; the slice slot keeps its types.
	if not receipt.is_empty():
		if d["receipt"].get("receiptId") == receipt.get("receiptId"):
			receipt = d["receipt"].duplicate(true)
		else:
			var saved: Dictionary = FieldSave.read(field_path)
			if saved.get("phase") == "ended" and saved.get("receipt_id") == receipt.get("receiptId"):
				receipt = receipt_of_field(saved)
			# Without either typed copy, the canonical train text loses number types.
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
		"g": g, "step": at, "run": d["run"], "contract": contract, "receipt": receipt, "passed": passed,
		"result_reason": reason, "reconciled": torn,
	}


static func _campaign_step(g: Dictionary) -> String:
	if RouteState.problem(g) != "":
		return ""
	var route: Dictionary = g["campaign"]
	if g.get("phase") == "end" or int(route["cursor"]) == CampaignRoute.size():
		return "end"
	var visit: Dictionary = route["visit"]
	if visit.is_empty():
		return "train"
	if visit["result"] == "open":
		return "stop_pick"
	if int(route["cursor"]) == CampaignRoute.size() - 1:
		return "receipt" if visit["result"] == "returned" else "end"
	if FieldArrival.second_station_reached(g):
		return "arrive"
	if visit["result"] == "passed":
		return "travel"
	var special: Variant = _returns(g).get("special")
	if special is Dictionary and special.get("receiptId") == visit.get("receipt_id"):
		if g.get("phase") == "council" and special.get("status") == "opened":
			return "council"
		if special.get("status") == "skipped" or special.get("result") is Dictionary:
			return "travel"
	return "receipt"


static func field_opts_belong(g: Dictionary, options: Dictionary) -> bool:
	if not RouteState.is_campaign(g) or not options.get("departure") is Dictionary:
		return false
	var visit: Dictionary = g["campaign"]["visit"]
	if visit.is_empty():
		return false
	if options.get("slice") != true or options.get("slice_run") != g["campaign"]["run"] or options.get("visit_id") != visit["id"] or options.get("place") != visit["map"] or options.get("seed") != visit["field_seed"]:
		return false
	var order: Dictionary = options["departure"]
	return RouteState.owns_contract(g, order) and visit.get("contract") is Dictionary and FieldReturn.canonical(order) == FieldReturn.canonical(visit["contract"])


static func field_belongs(g: Dictionary, saved: Dictionary) -> bool:
	if not RouteState.is_campaign(g) or not saved.get("start_opts") is Dictionary:
		return false
	var options: Dictionary = saved["start_opts"].duplicate(true)
	options["departure"] = saved.get("departure", {})
	options["place"] = saved.get("place", "")
	options["seed"] = saved.get("seed", -1)
	return field_opts_belong(g, options) and saved.get("stop_id") == g["campaign"]["visit"].get("stop_id") and saved.get("receipt_id") == "ret_" + String(g["campaign"]["visit"].get("departure_id", "")).trim_prefix("dep_")


static func _pick_campaign(d: Dictionary, g: Dictionary, source: Dictionary, field_path: String) -> Dictionary:
	if RouteState.problem(g) != "" or step_of_board(g) == "end":
		return {}
	var route: Dictionary = g["campaign"]
	var visit: Dictionary = route["visit"]
	var torn: bool = d.is_empty() or d.get("mode") != "campaign" or d.get("run") != route["run"] or d.get("visit_id") != visit.get("id", "") or d.get("train_sha") != source.get("train_sha") or d.get("seg") != g["seg"] or d.get("applied") != applied_ids(g)
	var at: String = step_of_board(g) if torn else resume_step(g, String(d["step"]))
	var receipt: Dictionary = receipt_of_board(g)
	var saved: Dictionary = FieldSave.read(field_path)
	if not receipt.is_empty():
		var fingerprint: String = FieldReturn.canonical(receipt)
		if not torn and RouteState.owns_receipt(g, d["receipt"]) and FieldReturn.canonical(d["receipt"]) == fingerprint:
			receipt = d["receipt"].duplicate(true)
		elif field_belongs(g, saved) and saved.get("phase") == "ended":
			var typed: Dictionary = receipt_of_field(saved)
			if FieldReturn.canonical(typed) == fingerprint:
				receipt = typed
	return {"g": g, "mode": "campaign", "run": route["run"], "step": at,
		"contract": (visit.get("contract", {}) as Dictionary).duplicate(true), "receipt": receipt,
		"passed": visit.get("result") == "passed", "result_reason": String(receipt.get("endReason", "")), "reconciled": torn}
