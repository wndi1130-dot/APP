extends "res://addons/gut/test.gd"
## The start's one decision: SliceSave._train_read over the train's slot and backup (four
## states, both version forms, a newer save over a refusing cell), boot_choice's five kinds,
## the first accepted candidate's hash, and the field's pure resume decision.

const Boot = preload("res://game/boot.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const SliceSave = preload("res://game/sim/slice_save.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const TrainSave = preload("res://game/politics/save_slot.gd")
const TrainDom = preload("res://game/train/train_dom.gd")
const RouteState = preload("res://game/train/route_state.gd")

var folder: String = "user://test_boot_choice_%d" % OS.get_process_id()
var slice_at: String = folder + "/slice.json"
var train_at: String = folder + "/train.json"
var field_at: String = folder + "/field.json"
var other_at: String = folder + "/other_train.json"
var had_auto: bool = false
var old_auto: String = ""


class Probe extends Boot:
	var slice_started: bool = false

	func _start_slice(resume: Dictionary = {}) -> void:
		slice_started = true


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	_clear()
	had_auto = OS.has_environment("S2_AUTOSTART")
	old_auto = OS.get_environment("S2_AUTOSTART")
	OS.unset_environment("S2_AUTOSTART")


func after_each() -> void:
	OS.unset_environment("S2_AUTOSTART")
	if had_auto:
		OS.set_environment("S2_AUTOSTART", old_auto)
	_clear()


func _clear() -> void:
	for at: String in [slice_at, train_at, field_at, other_at]:
		SliceSave.clear(at)
		FieldSave.clear(at)


func _write_text(at: String, text: String) -> void:
	var file := FileAccess.open(at, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _table() -> Dictionary:
	var board: Array = SliceFlow.start_board()
	var t: Dictionary = board[1]
	return t


func _board(applied: Dictionary = {}) -> Dictionary:
	var start: Array = SliceFlow.start_board()
	var g: Dictionary = (start[0] as Dictionary).duplicate(true)
	if g.get("dom") == null:
		g["dom"] = TrainDom.start()
	TrainDom.ensure(g)
	TrainSave.fill_defaults(g)
	g["fieldReturns"] = {"applied": applied, "records": []}
	return g


func _write_train(g: Dictionary, at: String = "") -> String:
	var path: String = at if at != "" else train_at
	assert_true(SliceSave.write_train(g, path))
	return FileAccess.get_file_as_string(path)


## slot_board writes a version of its own on any later write, so the condition is put on disk
## last and read back.
func _rewrite_version(at: String, value: Variant) -> void:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(at))
	parsed["version"] = value
	_write_text(at, JSON.stringify(parsed, "", false, true))
	var disk: Variant = (JSON.parse_string(FileAccess.get_file_as_string(at)) as Dictionary).get("version")
	if value is Dictionary:
		assert_true(disk is Dictionary, "the typed int tag is on disk")
		if disk is Dictionary:
			var typed: Dictionary = disk
			assert_eq(String(typed.get("value", "")), String((value as Dictionary).get("value", "")))
	else:
		var plain: bool = disk is int or disk is float
		assert_true(plain, "a plain number is on disk")
		if plain:
			assert_eq(float(disk), float(value))


func _left_field(extra: Dictionary = {}) -> Dictionary:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "receipt_id": "ret_resume", "field_save": true, "field_save_path": field_at}
	game.opts.merge(extra, true)
	game.opts["squad"] = game.default_squad("crude")
	add_child_autofree(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.interrupt()
	return FieldSave.read(field_at)


func _matching_slice(g: Dictionary, text: String) -> void:
	var saved: Dictionary = {
		"version": SliceSave.VERSION, "kind": SliceSave.KIND, "step": "stop_pick", "run": "boot_read",
		"train_sha": text.sha256_text(), "seg": int(g["seg"]), "applied": SliceSave.applied_ids(g),
		"contract": {}, "receipt": {}, "passed": false, "result_reason": "",
	}
	assert_true(SliceSave.write(saved, slice_at))


## The warning boot_choice pushes for a blocked start is expected; any other stays visible.
func _handle_block_warnings() -> void:
	for tracked: Variant in get_errors():
		if tracked.is_push_warning() and tracked.contains_text("resuming is held"):
			tracked.handled = true


# ---------------------------------------------------------------- _train_read

func test_train_read_reports_absent() -> void:
	var read: Dictionary = SliceSave._train_read(train_at, _table())
	assert_eq(String(read["status"]), "absent")
	assert_eq(read["g"], {})
	assert_eq(String(read["sha"]), "")
	assert_false(bool(read["newer"]))


func test_train_read_accepts_and_hashes_the_slot() -> void:
	var text: String = _write_train(_board())
	var read: Dictionary = SliceSave._train_read(train_at, _table())
	assert_eq(String(read["status"]), "accepted")
	assert_false((read["g"] as Dictionary).is_empty())
	assert_eq(String(read["sha"]), text.sha256_text())


func test_train_read_reports_unacceptable_when_no_candidate_fits() -> void:
	_write_text(train_at, JSON.stringify({"version": 1, "phase": "settle"}, "", false, true))
	var read: Dictionary = SliceSave._train_read(train_at, _table())
	assert_eq(String(read["status"]), "unacceptable")
	assert_eq(read["g"], {})


func test_train_read_reports_newer_for_a_plain_number() -> void:
	_write_train(_board())
	_rewrite_version(train_at, float(TrainSave.SAVE_VERSION + 1))
	var read: Dictionary = SliceSave._train_read(train_at, _table())
	assert_eq(String(read["status"]), "newer")
	assert_true(bool(read["newer"]))


func test_train_read_reports_newer_for_a_typed_int_tag() -> void:
	_write_train(_board())
	_rewrite_version(train_at, {"$type": "int", "value": str(TrainSave.SAVE_VERSION + 1)})
	var read: Dictionary = SliceSave._train_read(train_at, _table())
	assert_eq(String(read["status"]), "newer")


func test_train_read_takes_a_typed_int_tag_of_the_current_version() -> void:
	_write_train(_board())
	_rewrite_version(train_at, {"$type": "int", "value": str(TrainSave.SAVE_VERSION)})
	var read: Dictionary = SliceSave._train_read(train_at, _table())
	assert_eq(String(read["status"]), "accepted", "the tag's text is the slot's version")
	assert_false(bool(read["newer"]), "the current version is not a newer one")


func test_train_read_reads_a_newer_version_before_a_refused_cell() -> void:
	_write_train(_board())
	_rewrite_version(train_at, float(TrainSave.SAVE_VERSION + 1))
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(train_at))
	parsed["seg"] = {"$type": "int", "value": "x"}
	_write_text(train_at, JSON.stringify(parsed, "", false, true))
	assert_null(FieldSave.decode_checked(JSON.parse_string(FileAccess.get_file_as_string(train_at))), "the codec refuses this file")
	var read: Dictionary = SliceSave._train_read(train_at, _table())
	assert_eq(String(read["status"]), "newer", "and it is still a newer save")


func test_train_read_counts_each_candidate_once() -> void:
	_write_train(_board())
	SliceSave._test_train_parses = 0
	SliceSave._train_read(train_at, _table())
	assert_eq(SliceSave._test_train_parses, 1)
	SliceSave.clear(train_at)
	SliceSave._test_train_parses = 0
	SliceSave._train_read(train_at, _table())
	assert_eq(SliceSave._test_train_parses, 0)


## M6: the slot is the one the hash stands for, even when the backup is read too.
func test_train_read_keeps_the_slots_hash_over_a_whole_backup() -> void:
	var main_text: String = _write_train(_board())
	_write_train(_board({"other": true}), train_at + ".bak")
	var backup_text: String = FileAccess.get_file_as_string(train_at + ".bak")
	assert_ne(backup_text, main_text)
	var read: Dictionary = SliceSave._train_read(train_at, _table())
	assert_eq(String(read["status"]), "accepted")
	assert_eq(String(read["sha"]), main_text.sha256_text(), "the slot's own text")


func test_train_read_falls_back_to_the_backup_when_the_slot_is_broken() -> void:
	_write_train(_board())
	_write_text(train_at + ".bak", FileAccess.get_file_as_string(train_at))
	var backup_text: String = FileAccess.get_file_as_string(train_at + ".bak")
	_write_text(train_at, "{")
	var read: Dictionary = SliceSave._train_read(train_at, _table())
	assert_eq(String(read["status"]), "accepted")
	assert_eq(String(read["sha"]), backup_text.sha256_text())


func test_train_read_reports_a_newer_backup_over_a_whole_slot() -> void:
	_write_train(_board())
	_write_train(_board(), other_at)
	_rewrite_version(other_at, float(TrainSave.SAVE_VERSION + 2))
	_write_text(train_at + ".bak", FileAccess.get_file_as_string(other_at))
	var read: Dictionary = SliceSave._train_read(train_at, _table())
	assert_eq(String(read["status"]), "newer")
	assert_false((read["g"] as Dictionary).is_empty(), "the slot is still the accepted board")


## A written slot as the codec's typed map of [key, value] pairs (field_save.gd _encode's form
## for a map with a key that is not text), carrying this version; the form is checked on disk.
func _as_pairs(at: String, version: Variant) -> String:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(at))
	parsed["version"] = version
	var pairs: Array = []
	for key: String in parsed:
		pairs.append([key, parsed[key]])
	_write_text(at, JSON.stringify({"$type": "Dictionary", "value": pairs}, "", false, true))
	var text: String = FileAccess.get_file_as_string(at)
	var disk: Dictionary = JSON.parse_string(text)
	assert_eq(disk.get("$type"), "Dictionary", "the typed map is on disk")
	assert_false(disk.has("version"), "no version at the top")
	return text


func test_train_read_reports_newer_for_a_pairs_slot_over_a_whole_backup() -> void:
	_write_train(_board())
	_write_train(_board())
	_as_pairs(train_at, {"$type": "int", "value": str(TrainSave.SAVE_VERSION + 1)})
	var read: Dictionary = SliceSave._train_read(train_at, _table())
	assert_eq(String(read["status"]), "newer")
	assert_false((read["g"] as Dictionary).is_empty(), "the backup is still read")


func test_train_read_reports_newer_for_a_pairs_backup_over_a_whole_slot() -> void:
	_write_train(_board())
	_write_train(_board(), other_at)
	_as_pairs(other_at, float(TrainSave.SAVE_VERSION + 2))
	_write_text(train_at + ".bak", FileAccess.get_file_as_string(other_at))
	var read: Dictionary = SliceSave._train_read(train_at, _table())
	assert_eq(String(read["status"]), "newer")


## The pairs form of this build's version is a board this build reads (the codec's own form).
func test_train_read_accepts_a_pairs_slot_of_the_current_version() -> void:
	_write_train(_board())
	var text: String = _as_pairs(train_at, {"$type": "int", "value": str(TrainSave.SAVE_VERSION)})
	var read: Dictionary = SliceSave._train_read(train_at, _table())
	assert_eq(String(read["status"]), "accepted")
	assert_eq(String(read["sha"]), text.sha256_text())


## Implementation review L: the record check decides between two boards that differ.
func test_train_read_skips_a_slot_with_a_bad_record_row() -> void:
	var bad: Dictionary = _board({})
	bad["fieldReturns"] = {"applied": {}, "records": [{"receiptId": 1, "seg": 0}]}
	_write_train(bad)
	_write_train(_board({"ret_resume": true}), other_at)
	var backup_text: String = FileAccess.get_file_as_string(other_at)
	_write_text(train_at + ".bak", backup_text)
	var read: Dictionary = SliceSave._train_read(train_at, _table())
	assert_eq(String(read["status"]), "accepted")
	assert_eq(String(read["sha"]), backup_text.sha256_text(), "the backup is the board read")
	assert_true(((read["g"]["fieldReturns"] as Dictionary)["applied"] as Dictionary).has("ret_resume"))


# ---------------------------------------------------------------- pick

## pick is boot_choice's slice part and holds the same way: a newer slot resumes nothing, even
## over a whole backup the slice was saved beside.
func test_pick_holds_a_newer_train_like_the_start() -> void:
	var g: Dictionary = _board({})
	var text: String = _write_train(g)
	_matching_slice(g, text)
	assert_false(SliceSave.pick(slice_at, train_at, _table(), field_at).is_empty(), "the pair resumes")
	_write_text(train_at + ".bak", text)
	_rewrite_version(train_at, float(TrainSave.SAVE_VERSION + 1))
	assert_eq(SliceSave.pick(slice_at, train_at, _table(), field_at), {})


func test_pick_resumes_nothing_from_an_unreadable_train() -> void:
	var g: Dictionary = _board({})
	var text: String = _write_train(g)
	_matching_slice(g, text)
	_write_text(train_at, "{")
	assert_eq(SliceSave.pick(slice_at, train_at, _table(), field_at), {})


# ---------------------------------------------------------------- boot_choice

func test_boot_choice_is_menu_with_no_saves() -> void:
	assert_eq(String(SliceSave.boot_choice(slice_at, train_at, _table(), field_at)["kind"]), "menu")


func test_boot_choice_is_blocked_for_an_unreadable_train() -> void:
	_write_text(train_at, "{")
	var choice: Dictionary = SliceSave.boot_choice(slice_at, train_at, _table(), field_at)
	assert_eq(String(choice["kind"]), "blocked")
	assert_eq(choice["resume"], {})
	assert_eq(String(choice["why"]), "unacceptable")
	_handle_block_warnings()


func test_boot_choice_is_blocked_for_a_newer_train() -> void:
	_write_train(_board())
	_rewrite_version(train_at, float(TrainSave.SAVE_VERSION + 1))
	var choice: Dictionary = SliceSave.boot_choice(slice_at, train_at, _table(), field_at)
	assert_eq(String(choice["kind"]), "blocked")
	assert_eq(String(choice["why"]), "newer")
	_handle_block_warnings()


func test_boot_choice_is_slice_for_a_matching_pair() -> void:
	var g: Dictionary = _board({})
	var text: String = _write_train(g)
	_matching_slice(g, text)
	var choice: Dictionary = SliceSave.boot_choice(slice_at, train_at, _table(), field_at)
	assert_eq(String(choice["kind"]), "slice")
	assert_eq(String((choice["resume"] as Dictionary).get("step", "")), "stop_pick")


func test_boot_choice_is_field_for_an_unapplied_stop() -> void:
	_left_field()
	_write_train(_board({}))
	var choice: Dictionary = SliceSave.boot_choice(slice_at, train_at, _table(), field_at)
	assert_eq(String(choice["kind"]), "field")
	assert_eq(String((choice["resume"] as Dictionary).get("receipt_id", "")), "ret_resume")
	assert_eq(String((choice["resume"] as Dictionary).get("field_save_path", "")), field_at)


func test_boot_choice_is_campaign_for_a_campaign_board() -> void:
	var g: Dictionary = _board({})
	var routed: Dictionary = RouteState.start(g, "boot_read_campaign")
	# A route with no visit yet stands on the way (route_state.gd problem).
	routed["phase"] = "travel"
	assert_eq(RouteState.problem(routed, _table()), "")
	_write_train(routed)
	var choice: Dictionary = SliceSave.boot_choice(slice_at, train_at, _table(), field_at)
	assert_eq(String(choice["kind"]), "campaign")
	assert_eq(String((choice["resume"] as Dictionary).get("mode", "")), "campaign")


func test_a_blocked_choice_keeps_autostart_from_starting_anything() -> void:
	OS.set_environment("S2_AUTOSTART", "1")
	_write_text(train_at, "{")
	var boot: Probe = Probe.new()
	boot.slice_save_path = slice_at
	boot.train_save_path = train_at
	boot.field_save_path = field_at
	add_child_autofree(boot)
	assert_false(boot.slice_started)
	assert_null(boot.field, "autostart waits behind the block")
	assert_not_null(boot.menu)
	if boot.menu != null:
		assert_not_null(boot.menu.find_child("SaveNote", true, false))
	_handle_block_warnings()


func test_a_blocked_choice_leaves_the_save_files_as_they_were() -> void:
	_left_field()
	_write_text(train_at, "{")
	var field_text: String = FileAccess.get_file_as_string(field_at)
	var train_text: String = FileAccess.get_file_as_string(train_at)
	var boot: Probe = Probe.new()
	boot.slice_save_path = slice_at
	boot.train_save_path = train_at
	boot.field_save_path = field_at
	add_child_autofree(boot)
	assert_null(boot.field)
	assert_eq(FileAccess.get_file_as_string(field_at), field_text)
	assert_eq(FileAccess.get_file_as_string(train_at), train_text)
	assert_false(FileAccess.file_exists(field_at + ".tmp"))
	assert_false(FileAccess.file_exists(train_at + ".tmp"))
	_handle_block_warnings()


# ---------------------------------------------------------------- pick_start_with

func test_pick_start_with_is_pure_and_asks_should_resume() -> void:
	var save: Dictionary = _left_field()
	var opts: Dictionary = FieldSave.pick_start_with(save, {}, field_at)
	assert_eq(String(opts.get("receipt_id", "")), "ret_resume")
	assert_eq(String(opts.get("field_save_path", "")), field_at)
	assert_eq(FieldSave.pick_start_with(save, {"ret_resume": true}, field_at), {})
	var ended: Dictionary = save.duplicate(true)
	ended["phase"] = "ended"
	assert_eq(FieldSave.pick_start_with(ended, {}, field_at), {})
	assert_eq(FieldSave.pick_start_with({}, {}, field_at), {})


func test_pick_start_with_reads_no_file() -> void:
	_left_field()
	FieldSave._test_reads = 0
	var save: Dictionary = FieldSave.read(field_at)
	assert_eq(FieldSave._test_reads, 1)
	var opts: Dictionary = FieldSave.pick_start_with(save, {}, field_at)
	assert_false(opts.is_empty())
	assert_eq(FieldSave._test_reads, 1, "the decision itself parses nothing")
