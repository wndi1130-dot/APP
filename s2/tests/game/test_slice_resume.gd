extends "res://addons/gut/test.gd"
## Four cuts, ten field seeds, and the train slot checked on its own.

const SliceFlow = preload("res://game/slice_flow.gd")
const SliceSave = preload("res://game/sim/slice_save.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const TrainSave = preload("res://game/politics/save_slot.gd")
const CouncilCard = preload("res://game/ui/council_card.gd")
const Boot = preload("res://game/boot.gd")
const SLICE := "user://test_slice_resume_slice.json"
const TRAIN := "user://test_slice_resume_train.json"
const FIELD := "user://test_slice_resume_field.json"
const ROUND_TRIP := "user://test_slice_resume_round_trip.json"
const BROKEN := "user://test_slice_resume_broken.json"
const SEEDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
var flows: Array = []


## Exercise boot's real choice and factory without replacing GUT's scene.
class BootProbe extends Boot:
	var opened: Node = null

	func _start_slice(resume: Dictionary = {}) -> void:
		opened = _make_slice(resume)
		opened.opts["cinema"] = false
		opened.opts["map_threads"] = false
		add_child(opened)
		opened.set_process(false)


func before_each() -> void:
	_clear_slots()


func after_each() -> void:
	for flow in flows:
		if is_instance_valid(flow):
			flow.free()
	flows.clear()
	_clear_slots()
	await get_tree().process_frame


func _clear_slots() -> void:
	for path: String in [SLICE, TRAIN, FIELD, ROUND_TRIP, BROKEN]:
		SliceSave.clear(path)


func _flow(extra: Dictionary = {}):
	var flow = SliceFlow.new()
	flow.opts = {
		"save": true, "skip_field": true, "seed": 1, "cinema": false, "map_threads": false,
		"slice_save_path": SLICE, "train_save_path": TRAIN, "field_save_path": FIELD,
	}
	flow.opts.merge(extra, true)
	flows.append(flow)
	add_child(flow)
	flow.set_process(false)
	return flow


func _pick() -> Dictionary:
	var start: Array = SliceFlow.start_board()
	return SliceSave.pick(SLICE, TRAIN, start[1])


## Every type and every float digit: a 9 that comes back as 9.0 is a different board.
func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


## The first place where a value read back is not the same type as the one saved, or "".
func _type_gap(saved: Variant, back: Variant, at: String = "g") -> String:
	if typeof(saved) != typeof(back):
		return "%s: %s -> %s" % [at, type_string(typeof(saved)), type_string(typeof(back))]
	if saved is Dictionary:
		for key: Variant in saved:
			if not (back as Dictionary).has(key):
				return "%s.%s: missing" % [at, str(key)]
			var gap := _type_gap(saved[key], back[key], "%s.%s" % [at, str(key)])
			if gap != "":
				return gap
		if (saved as Dictionary).size() != (back as Dictionary).size():
			return "%s: %d keys -> %d" % [at, (saved as Dictionary).size(), (back as Dictionary).size()]
	elif saved is Array:
		if (saved as Array).size() != (back as Array).size():
			return "%s: %d items -> %d" % [at, (saved as Array).size(), (back as Array).size()]
		for i: int in (saved as Array).size():
			var gap := _type_gap(saved[i], back[i], "%s[%d]" % [at, i])
			if gap != "":
				return gap
	return ""


func _raw(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		file.store_string(value)
		file.close()


func _session_count(g: Dictionary) -> int:
	var count: int = 0
	for row: Dictionary in g.get("journal", []):
		if String(row.get("text", "")).begins_with("첫 귀환을 두고 특별 회기를 연다."):
			count += 1
	return count


func _finish(flow) -> void:
	# Going straight to the next step uses the existing quiet return, with no run logs.
	for i in range(flow.step + 1, SliceFlow.STEPS.size()):
		flow.go(i)
	assert_eq(flow.current(), "end")
	assert_eq(flow.port_error, "")
	assert_eq(flow.train_g["fieldReturns"]["records"].size(), 1)
	assert_eq(flow.train_g["fieldReturns"]["applied"].size(), 1)
	assert_eq(_session_count(flow.train_g), 1, "the board opened the special session once")
	assert_eq(SliceSave.read(SLICE), {})
	assert_eq(FieldSave.read(FIELD), {})
	assert_true(FileAccess.file_exists(TRAIN), "the S1 slot stays")
	assert_eq(flow.save_error, "")


func _cut(at: String, seed_value: int) -> void:
	_clear_slots()
	var original = _flow({"seed": seed_value})
	original.go(original._index_of(at))
	var before: String = _json(original.train_g)
	var before_g: Dictionary = original.train_g.duplicate(true)
	var contract: String = _json(original.contract)
	var receipt: String = _json(original.receipt)
	original.notification(NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(original.save_error, "")
	original.free()
	var picked: Dictionary = _pick()
	assert_false(picked.is_empty(), "%s seed %d can be picked" % [at, seed_value])
	if picked.is_empty():
		return
	var resumed = _flow({"seed": seed_value, "resume": picked})
	assert_eq(resumed.current(), at)
	assert_eq(_json(resumed.train_g), before, "%s seed %d keeps the board" % [at, seed_value])
	assert_eq(_type_gap(before_g, resumed.train_g), "", "%s seed %d keeps every type" % [at, seed_value])
	assert_eq(_json(resumed.contract), contract)
	assert_eq(_json(resumed.receipt), receipt)
	if at == "receipt":
		assert_eq(String(resumed.card.name), "ReceiptSheet")
		assert_eq(resumed.card.result, resumed.result)
		assert_eq(resumed.result, SliceFlow.result_of(resumed.receipt))
	_finish(resumed)
	var ended: String = _json(resumed.train_g)
	resumed.free()
	# The same seed played through the same steps without the cut ends on the same board.
	var straight = _flow({"seed": seed_value, "save": false})
	straight.go(straight._index_of(at))
	for i in range(straight.step + 1, SliceFlow.STEPS.size()):
		straight.go(i)
	assert_eq(ended, _json(straight.train_g), "%s seed %d ends as the run that was never cut" % [at, seed_value])
	straight.free()


func test_ten_seeds_resume_at_stop_pick() -> void:
	for seed_value: int in SEEDS:
		_cut("stop_pick", seed_value)


func test_ten_seeds_resume_at_receipt() -> void:
	for seed_value: int in SEEDS:
		_cut("receipt", seed_value)


func test_ten_seeds_resume_at_council_before_the_vote() -> void:
	for seed_value: int in SEEDS:
		_cut("council", seed_value)


func _exercise_field(game) -> void:
	game.set_process(false)
	game.opts["auto_pause"] = false
	game.skip_arrival()
	for tick in 20:
		game._process(0.1)
	# Existing field save tests set elapsed directly; advance the same clock here.
	game.clock.advance(35.0)
	game.player.position += Vector3(1.5, 0.0, 1.0)
	game.receipt.place_note("manholeBlocked", true)
	var body: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(3.0, 0.0, 0.0))
	game.zombies.kill(body)


func _same_field(actual: Dictionary, expected: Dictionary) -> void:
	assert_eq(actual["clock"], expected["clock"])
	assert_eq(actual["people"].size(), expected["people"].size())
	for i in mini(actual["people"].size(), expected["people"].size()):
		assert_eq(actual["people"][i]["pid"], expected["people"][i]["pid"])
		assert_eq(actual["people"][i]["pos"], expected["people"][i]["pos"])
	assert_eq(actual["zombies"].size(), expected["zombies"].size())
	assert_eq(FieldSave.to_json(actual["receipt_state"]), FieldSave.to_json(expected["receipt_state"]))
	assert_eq(actual["receipt_id"], expected["receipt_id"])
	assert_eq(actual["phase"], expected["phase"])


func test_ten_seeds_resume_the_running_field() -> void:
	for seed_value: int in SEEDS:
		_clear_slots()
		var original = _flow({"seed": seed_value, "skip_field": false})
		original.go(original._index_of("field"))
		assert_true(original.field.is_built)
		assert_true(original.get_window().close_requested.is_connected(Callable(original.field, "interrupt")))
		_exercise_field(original.field)
		var before: Dictionary = FieldSave.capture(original.field)
		var board_before: String = _json(original.train_g)
		assert_gt(float(before["clock"]["elapsed"]), 30.0)
		# The OS delivers this to both nodes. The slice must not write FIELD again.
		original.propagate_notification(NOTIFICATION_APPLICATION_PAUSED)
		var field_text: String = FileAccess.get_file_as_string(FIELD)
		assert_false(FileAccess.file_exists(FIELD + ".bak"))
		original.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		assert_eq(FileAccess.get_file_as_string(FIELD), field_text)
		assert_false(FileAccess.file_exists(FIELD + ".bak"))
		original.free()
		var picked: Dictionary = _pick()
		assert_false(picked.is_empty())
		if picked.is_empty():
			return
		var resumed = _flow({"resume": picked, "skip_field": false})
		assert_eq(resumed.current(), "field")
		assert_eq(_json(resumed.train_g), board_before)
		assert_null(resumed.cinema, "no arrival scene on resume")
		assert_true(resumed.field.opts["slice"])
		assert_eq(resumed.field.opts["field_save_path"], FIELD)
		_same_field(FieldSave.capture(resumed.field), before)
		_finish(resumed)
		resumed.free()


func _train_round_trip(at: String) -> void:
	var flow = _flow({"skip_field": at != "field"})
	flow.go(flow._index_of(at))
	assert_null(TrainSave.shape_problem(flow.train_g, flow.train_t), at + " has the S1 shape")
	assert_true(SliceSave.write_train(flow.train_g, ROUND_TRIP))
	var loaded: Dictionary = SliceSave._train(ROUND_TRIP, flow.train_t)
	assert_false(loaded.is_empty(), at + " reads back through the S1 shape check")
	assert_eq(_json(loaded), _json(flow.train_g), at + " every value and digit")
	assert_eq(_type_gap(flow.train_g, loaded), "", at + " every type")


func test_train_slot_round_trip_at_stop_pick() -> void:
	_train_round_trip("stop_pick")


func test_train_slot_round_trip_in_field() -> void:
	_train_round_trip("field")


func test_train_slot_round_trip_at_receipt() -> void:
	_train_round_trip("receipt")


func test_train_slot_round_trip_in_council() -> void:
	_train_round_trip("council")


func test_broken_slice_without_backup_and_missing_train_are_not_picked() -> void:
	var flow = _flow()
	flow.go(flow._index_of("stop_pick"))
	SliceSave.clear(SLICE)
	_raw(SLICE, "{\"version\":1,\"kind\":")
	assert_eq(_pick(), {})
	assert_true(SliceSave.write(SliceSave.capture(flow), SLICE))
	SliceSave.clear(TRAIN)
	assert_eq(_pick(), {})


func test_slice_shape_rejects_wrong_types_and_unknown_steps() -> void:
	var flow = _flow()
	var good: Dictionary = SliceSave.capture(flow)
	for change: Dictionary in [{"version": 2}, {"kind": "s2_field"}, {"step": "missing"}, {"seg": -1}, {"seg": 2.5}, {"applied": {}}, {"applied": [2]}, {"contract": []}, {"receipt": []}, {"passed": 1}, {"result_reason": null}]:
		SliceSave.clear(SLICE)
		var bad: Dictionary = good.duplicate(true)
		bad.merge(change, true)
		_raw(SLICE, JSON.stringify(bad))
		assert_eq(SliceSave.read(SLICE), {}, str(change))


func test_capture_is_metadata_only_and_keeps_the_result_reason() -> void:
	var flow = _flow()
	flow.go(flow._index_of("receipt"))
	flow.result["reason"] = "saved_reason"
	var captured: Dictionary = SliceSave.capture(flow)
	var keys: Array = captured.keys()
	keys.sort()
	assert_eq(keys, ["applied", "contract", "kind", "passed", "receipt", "result_reason", "seg", "step", "version"])
	assert_eq(captured["contract"], flow.contract)
	assert_true(SliceSave.write(captured, SLICE))
	assert_eq(_pick()["result_reason"], "saved_reason")


func test_slice_and_train_each_fall_back_to_one_whole_backup() -> void:
	var flow = _flow()
	flow.go(flow._index_of("stop_pick"))
	var first: Dictionary = SliceSave.capture(flow)
	first["result_reason"] = "first"
	assert_true(SliceSave.write(first, SLICE))
	var second: Dictionary = first.duplicate(true)
	second["result_reason"] = "second"
	assert_true(SliceSave.write(second, SLICE))
	_raw(SLICE, "{")
	assert_eq(SliceSave.read(SLICE)["result_reason"], "first")
	assert_false(FileAccess.file_exists(SLICE + ".tmp"))
	_raw(TRAIN, "{")
	assert_eq(_pick()["step"], "stop_pick")
	assert_false(FileAccess.file_exists(BROKEN), "pick is read only")


func test_torn_segment_uses_the_train_and_recovers_its_receipt() -> void:
	var flow = _flow()
	flow.go(flow._index_of("stop_pick"))
	var old: Dictionary = SliceSave.capture(flow)
	flow.go(flow._index_of("receipt"))
	var expected: String = _json(flow.train_g)
	old["seg"] = int(flow.train_g["seg"]) + 1
	assert_true(SliceSave.write(old, SLICE))
	flow.free()
	var picked: Dictionary = _pick()
	assert_true(picked["reconciled"])
	assert_eq(picked["step"], "receipt")
	assert_false(picked["receipt"].is_empty())
	var resumed = _flow({"resume": picked})
	assert_eq(_json(resumed.train_g), expected)
	assert_eq(String(resumed.card.name), "ReceiptSheet")
	_finish(resumed)


func test_torn_applied_ids_keep_an_already_open_session() -> void:
	var flow = _flow()
	flow.go(flow._index_of("stop_pick"))
	var old: Dictionary = SliceSave.capture(flow)
	flow.go(flow._index_of("council"))
	assert_eq(int(old["seg"]), int(flow.train_g["seg"]))
	var expected: String = _json(flow.train_g)
	assert_true(SliceSave.write(old, SLICE))
	flow.free()
	var picked: Dictionary = _pick()
	assert_true(picked["reconciled"])
	assert_eq(picked["step"], "council")
	var resumed = _flow({"resume": picked})
	assert_eq(_json(resumed.train_g), expected)
	assert_eq(_session_count(resumed.train_g), 1)
	_finish(resumed)


func test_step_of_board_follows_the_committed_phase() -> void:
	var flow = _flow()
	assert_eq(SliceSave.step_of_board(flow.train_g), "train")
	for at: String in ["stop_pick", "receipt", "council"]:
		flow.go(flow._index_of(at))
		assert_eq(SliceSave.step_of_board(flow.train_g), at)
	var skipped: Dictionary = flow.train_g.duplicate(true)
	skipped["phase"] = "settle"
	skipped["fieldReturns"]["special"] = {"status": "skipped"}
	assert_eq(SliceSave.step_of_board(skipped), "travel")
	flow.card.cast()
	assert_eq(SliceSave.step_of_board(flow.train_g), "council", "a vote shown but not left")
	flow.card.close()
	assert_eq(SliceSave.step_of_board(flow.train_g), "travel")
	flow.go(flow._index_of("arrive"))
	assert_eq(SliceSave.step_of_board(flow.train_g), "arrive")
	flow.go(flow._index_of("end"))
	assert_eq(SliceSave.step_of_board(flow.train_g), "end")


func test_agenda_and_cast_vote_are_saved_before_leaving() -> void:
	var flow = _flow()
	flow.go(flow._index_of("council"))
	flow.card.turn(1)
	assert_eq(int(_pick()["g"]["council"]["idx"]), flow.card.idx)
	flow.card.cast()
	var expected: String = _json(flow.train_g)
	var vote: String = _json(flow.card.result)
	assert_eq(_json(_pick()["g"]), expected, "cast itself saves, before any pause")
	assert_false(flow.card.result.is_empty())
	flow.free()
	var resumed = _flow({"resume": _pick()})
	assert_eq(resumed.current(), "council")
	assert_eq(_json(resumed.train_g), expected)
	assert_eq(_json(resumed.card.result), vote)
	resumed.card.cast()
	assert_eq(_json(resumed.train_g), expected, "the restored vote cannot be cast twice")
	resumed.card.close()
	assert_eq(resumed.current(), "travel")
	var travelling: String = _json(resumed.train_g)
	resumed.free()
	var again = _flow({"resume": _pick()})
	assert_eq(again.current(), "travel")
	assert_eq(_json(again.train_g), travelling, "workshop upkeep is not paid twice")
	_finish(again)


func test_a_council_deal_is_saved_before_the_vote() -> void:
	var flow = _flow()
	flow.go(flow._index_of("council"))
	var made: bool = false
	for i in flow.card.m["comms"].size():
		var comm := String(flow.card.m["comms"][i]["id"])
		for tool: Dictionary in CouncilCard.tools_of(flow.card.g, flow.train_t, flow.card.idx, comm):
			if bool(tool["ok"]) and tool["id"] != "open":
				flow.card._pick(i)
				flow.card._make(String(tool["id"]), 0, "")
				made = true
				break
		if made:
			break
	assert_true(made, "the fixture has a legal deal")
	assert_eq(flow.train_g["council"]["deals"].size(), 1)
	var expected: String = _json(flow.train_g)
	assert_eq(_json(_pick()["g"]), expected)
	flow.free()
	var resumed = _flow({"resume": _pick()})
	assert_eq(_json(resumed.train_g), expected)
	assert_eq(resumed.card.g["council"]["deals"].size(), 1)
	_finish(resumed)


func test_return_is_saved_while_the_field_screen_is_still_current() -> void:
	var flow = _flow()
	flow.go(flow._index_of("stop_pick"))
	flow.step = flow._index_of("field")
	flow._apply_return(SliceFlow.quiet_receipt(flow._departure()))
	assert_eq(flow.current(), "field")
	var picked: Dictionary = _pick()
	assert_eq(picked["step"], "receipt")
	assert_eq(picked["g"]["fieldReturns"]["records"].size(), 1)
	assert_eq(_json(picked["receipt"]), _json(flow.receipt))


func test_missing_or_foreign_field_goes_back_to_the_board_step() -> void:
	var flow = _flow()
	flow.go(flow._index_of("stop_pick"))
	var saved: Dictionary = SliceSave.capture(flow)
	saved["step"] = "field"
	assert_true(SliceSave.write(saved, SLICE))
	flow.free()
	var resumed = _flow({"resume": _pick()})
	assert_eq(resumed.current(), "stop_pick")
	assert_null(resumed.field)
	resumed.free()
	var real = _flow({"skip_field": false})
	real.go(real._index_of("field"))
	var other: Dictionary = FieldSave.capture(real.field)
	other["start_opts"]["slice"] = false
	assert_true(FieldSave.write(other, FIELD))
	real.free()
	var refused = _flow({"resume": _pick()})
	assert_eq(refused.current(), "stop_pick")
	assert_null(refused.field)


func test_applied_field_is_not_reopened() -> void:
	var flow = _flow({"skip_field": false})
	flow.go(flow._index_of("field"))
	var old: Dictionary = SliceSave.capture(flow)
	var field_save: Dictionary = FieldSave.capture(flow.field)
	flow.go(flow._index_of("receipt"))
	field_save["receipt_id"] = flow.receipt["receiptId"]
	assert_true(FieldSave.write(field_save, FIELD))
	assert_true(SliceSave.write(old, SLICE))
	assert_false(FieldSave.should_resume(field_save, SliceSave.applied_ids(flow.train_g)))
	flow.free()
	var resumed = _flow({"resume": _pick(), "skip_field": false})
	assert_eq(resumed.current(), "receipt")
	assert_null(resumed.field)
	_finish(resumed)


func test_ended_field_commits_its_receipt_if_the_train_write_was_interrupted() -> void:
	var flow = _flow({"skip_field": false})
	flow.go(flow._index_of("field"))
	# Finish the receipt without finish()'s unrelated run-log files.
	flow.field._contract_end(flow.field.squad)
	assert_true(flow.field.receipt.set_time("D1 10:30", "D1 11:00", 30))
	assert_true(flow.field.receipt.set_end("departed"))
	assert_eq(flow.field.receipt.problems(), [])
	flow.field.ended = true
	var expected: String = _json(flow.field.receipt.to_dict())
	assert_true(FieldSave.write(FieldSave.capture(flow.field), FIELD))
	assert_false(flow._returned())
	flow.free()
	var resumed = _flow({"resume": _pick()})
	assert_eq(resumed.current(), "receipt")
	assert_null(resumed.field)
	assert_eq(_json(resumed.receipt), expected)
	assert_eq(resumed.train_g["fieldReturns"]["records"].size(), 1)
	resumed.free()
	var again = _flow({"resume": _pick()})
	assert_eq(_json(again.receipt), expected)
	_finish(again)


func test_all_three_app_notifications_save_the_train_and_slice() -> void:
	var flow = _flow()
	flow.go(flow._index_of("stop_pick"))
	for what: int in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		SliceSave.clear(SLICE)
		SliceSave.clear(TRAIN)
		flow.notification(what)
		assert_eq(_pick()["step"], "stop_pick")
		assert_eq(_json(_pick()["g"]), _json(flow.train_g))
		assert_false(FileAccess.file_exists(FIELD))


func test_save_false_preserves_all_three_slots_even_at_the_end() -> void:
	for path: String in [SLICE, TRAIN, FIELD]:
		_raw(path, "untouched")
	var flow = _flow({"save": false, "skip_field": false})
	flow.go(flow._index_of("field"))
	assert_false(flow.field.opts["field_save"])
	flow.propagate_notification(NOTIFICATION_APPLICATION_PAUSED)
	flow.go(flow._index_of("end"))
	for path: String in [SLICE, TRAIN, FIELD]:
		assert_eq(FileAccess.get_file_as_string(path), "untouched")
		assert_false(FileAccess.file_exists(path + ".bak"))


func test_passing_a_stop_and_ending_do_not_restore_a_field() -> void:
	var flow = _flow()
	flow.go(flow._index_of("stop_pick"))
	flow._pass_stop()
	var before: String = _json(flow.train_g)
	flow.free()
	var resumed = _flow({"resume": _pick()})
	assert_true(resumed.passed)
	assert_eq(resumed.current(), "travel")
	assert_eq(_json(resumed.train_g), before)
	resumed.go(resumed._index_of("end"))
	assert_eq(_pick(), {})


func test_terminal_train_rejects_a_stale_slice_backup() -> void:
	var flow = _flow()
	flow.go(flow._index_of("council"))
	var old: Dictionary = SliceSave.capture(flow)
	_finish(flow)
	_raw(SLICE + ".bak", JSON.stringify(old))
	assert_eq(_pick(), {})


func _boot():
	var boot = BootProbe.new()
	boot.slice_save_path = SLICE
	boot.train_save_path = TRAIN
	boot.field_save_path = FIELD
	flows.append(boot)
	add_child(boot)
	return boot


func test_boot_opens_the_slice_before_considering_its_field() -> void:
	var flow = _flow({"skip_field": false})
	flow.go(flow._index_of("field"))
	_exercise_field(flow.field)
	flow.propagate_notification(NOTIFICATION_APPLICATION_PAUSED)
	flow.free()
	var boot = _boot()
	assert_not_null(boot.opened)
	assert_null(boot.field)
	assert_null(boot.menu)
	assert_eq(boot.opened.current(), "field")
	assert_eq(boot.opened.opts["slice_save_path"], SLICE)
	assert_eq(boot.opened.opts["train_save_path"], TRAIN)
	assert_eq(boot.opened.field.opts["field_save_path"], FIELD)


func test_boot_keeps_an_orphan_slice_field_out_of_standalone_play() -> void:
	var flow = _flow({"skip_field": false})
	flow.go(flow._index_of("field"))
	flow.propagate_notification(NOTIFICATION_APPLICATION_PAUSED)
	flow.free()
	SliceSave.clear(SLICE)
	var boot = _boot()
	assert_null(boot.opened)
	assert_null(boot.field)
	assert_not_null(boot.menu)


func test_a_new_run_clears_an_orphan_field_with_the_same_departure_id() -> void:
	var previous = _flow({"skip_field": false})
	previous.go(previous._index_of("field"))
	previous.propagate_notification(NOTIFICATION_APPLICATION_PAUSED)
	previous.free()
	SliceSave.clear(SLICE)
	assert_false(FieldSave.read(FIELD).is_empty())
	var fresh = _flow()
	assert_eq(fresh.current(), "train")
	assert_eq(FieldSave.read(FIELD), {}, "departure ids repeat between new runs")


func test_the_train_s_sleds_survive_the_slots() -> void:
	# The workshop's load sleds are the train's (two at most, docs/design/briefs/sled.md 94):
	# they come back with it.
	var flow = _flow()
	flow.go(flow._index_of("stop_pick"))
	flow.train_g["dom"]["sleds"] = 2
	flow.notification(NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(flow.save_error, "")
	flow.free()
	var picked: Dictionary = _pick()
	assert_false(picked.is_empty(), "the stop can be picked")
	if picked.is_empty():
		return
	assert_eq(int(picked["g"]["dom"]["sleds"]), 2)
	var resumed = _flow({"resume": picked})
	assert_eq(int(resumed.train_g["dom"]["sleds"]), 2, "the sleds are still the train's")
