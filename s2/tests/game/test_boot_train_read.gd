extends "res://addons/gut/test.gd"
## Boot's start choice at the node level: a stop left mid-play comes back, a broken or newer
## train slot holds the start (and the files are left as they are), and a newer backup is a
## newer save too.
## test_fail_* fail before the one-read change; test_keep_* hold before and after.
## Only boot's public shape is used here (Boot, FieldSave.read/write/clear, SliceSave.write_train,
## raw file writes), so this file compiles on the code before the change.

const Boot = preload("res://game/boot.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const SliceSave = preload("res://game/sim/slice_save.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const TrainSave = preload("res://game/politics/save_slot.gd")
const TrainDom = preload("res://game/train/train_dom.gd")

var folder: String = "user://test_boot_train_read_%d" % OS.get_process_id()
var slice_at: String = folder + "/slice.json"
var train_at: String = folder + "/train.json"
var field_at: String = folder + "/field.json"
## The machine's own autostart must not open a stop where a menu is expected.
var had_auto: bool = false
var old_auto: String = ""


## Boot with the scene switch caught: a slice start is recorded, not played.
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
	for at: String in [slice_at, train_at, field_at]:
		SliceSave.clear(at)
		FieldSave.clear(at)


func _write_text(at: String, text: String) -> void:
	var file := FileAccess.open(at, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _boot() -> Probe:
	var boot: Probe = Probe.new()
	boot.slice_save_path = slice_at
	boot.train_save_path = train_at
	boot.field_save_path = field_at
	add_child_autofree(boot)
	return boot


## A train board as the slot holds it (test_save_codec.gd _train_board's way).
func _board(applied: Dictionary = {}) -> Dictionary:
	var start: Array = SliceFlow.start_board()
	var g: Dictionary = (start[0] as Dictionary).duplicate(true)
	if g.get("dom") == null:
		g["dom"] = TrainDom.start()
	TrainDom.ensure(g)
	TrainSave.fill_defaults(g)
	g["fieldReturns"] = {"applied": applied, "records": []}
	return g


func _write_train_board(g: Dictionary, at: String = "") -> void:
	assert_true(SliceSave.write_train(g, at if at != "" else train_at))


## Rewrites the version of a written slot (slot_board sets it again on any later write) and
## checks the condition is really on disk.
func _rewrite_version(at: String, value: Variant) -> void:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(at))
	parsed["version"] = value
	_write_text(at, JSON.stringify(parsed, "", false, true))
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(at))
	var on_disk: Variant = disk.get("version")
	if value is Dictionary:
		assert_true(on_disk is Dictionary, "the typed int tag is on disk")
		if on_disk is Dictionary:
			var typed: Dictionary = on_disk
			assert_eq(String(typed.get("value", "")), String((value as Dictionary).get("value", "")))
	else:
		var plain: bool = on_disk is float or on_disk is int
		assert_true(plain, "a plain number is on disk")
		if plain:
			assert_eq(int(on_disk), int(value), "the plain version is on disk")


## One cell of the slot as a value the codec refuses (a typed int that is not its text).
func _break_cell(at: String, key: String) -> void:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(at))
	parsed[key] = {"$type": "int", "value": "x"}
	_write_text(at, JSON.stringify(parsed, "", false, true))
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(at))
	var cell: Variant = disk.get(key)
	assert_true(cell is Dictionary, "the refused cell is on disk")
	if cell is Dictionary:
		assert_eq(String((cell as Dictionary).get("value", "")), "x")


## A stop left mid-play, independent of the train (receipt id ret_resume).
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


## A slice slot that matches a board's text (its sha and applied ids), so the slice would come back.
func _matching_slice(g: Dictionary, text: String) -> void:
	var saved: Dictionary = {
		"version": SliceSave.VERSION, "kind": SliceSave.KIND, "step": "stop_pick", "run": "boot_read",
		"train_sha": text.sha256_text(), "seg": int(g["seg"]), "applied": SliceSave.applied_ids(g),
		"contract": {}, "receipt": {}, "passed": false, "result_reason": "",
	}
	assert_true(SliceSave.write(saved, slice_at))


## A warning pushed by the new block path is expected here; none is required (before the change).
func _handle_block_warnings() -> void:
	for tracked: Variant in get_errors():
		if tracked.is_push_warning() and tracked.contains_text("resuming is held"):
			tracked.handled = true


# ---------------------------------------------------------------- fail before the change

func test_fail_a_broken_train_slot_with_a_good_backup_does_not_start_the_field() -> void:
	_left_field()
	_write_train_board(_board({"ret_resume": true}), train_at + ".bak")
	_write_text(train_at, "{")
	var boot: Probe = _boot()
	assert_false(boot.slice_started)
	assert_null(boot.field, "the backup's applied return holds the field")
	assert_not_null(boot.menu)


func test_fail_a_refused_cell_in_the_train_slot_does_not_start_the_field() -> void:
	_left_field()
	_write_train_board(_board({"ret_resume": true}), train_at + ".bak")
	_write_train_board(_board({}))
	_break_cell(train_at, "seg")
	var boot: Probe = _boot()
	assert_false(boot.slice_started)
	assert_null(boot.field, "the backup is the train save read")
	assert_not_null(boot.menu)


func test_fail_a_broken_train_slot_leaves_its_files_and_says_so() -> void:
	_left_field()
	_write_text(train_at, "{")
	var train_text: String = FileAccess.get_file_as_string(train_at)
	var field_text: String = FileAccess.get_file_as_string(field_at)
	var boot: Probe = _boot()
	assert_null(boot.field, "no stop is started")
	assert_not_null(boot.menu)
	# With no menu up the line above already fails; the file checks below still run.
	if boot.menu != null:
		assert_not_null(boot.menu.find_child("SaveNote", true, false), "the menu says why")
	assert_eq(FileAccess.get_file_as_string(train_at), train_text, "the train slot is untouched")
	assert_eq(FileAccess.get_file_as_string(field_at), field_text, "the field slot is untouched")
	_handle_block_warnings()


func test_fail_a_newer_train_slot_does_not_start_the_matching_slice() -> void:
	var good: Dictionary = _board({})
	_write_train_board(good)
	var good_text: String = FileAccess.get_file_as_string(train_at)
	_write_train_board(_board({}))
	assert_eq(FileAccess.get_file_as_string(train_at + ".bak"), good_text, "the good slot became the backup")
	_rewrite_version(train_at, float(TrainSave.SAVE_VERSION + 1))
	_matching_slice(good, good_text)
	var boot: Probe = _boot()
	assert_false(boot.slice_started, "a newer train save holds the whole start")
	assert_null(boot.field)
	assert_not_null(boot.menu)
	_handle_block_warnings()


func test_fail_a_newer_backup_blocks_the_whole_start() -> void:
	_left_field()
	_write_train_board(_board({}))
	_write_train_board(_board({}), train_at + ".bak")
	_rewrite_version(train_at + ".bak", float(TrainSave.SAVE_VERSION + 1))
	var boot: Probe = _boot()
	assert_false(boot.slice_started)
	assert_null(boot.field)
	assert_not_null(boot.menu)
	_handle_block_warnings()


func test_fail_a_newer_train_slot_with_no_applied_return_does_not_start_the_field() -> void:
	_left_field()
	_write_train_board(_board({}))
	_rewrite_version(train_at, float(TrainSave.SAVE_VERSION + 1))
	var boot: Probe = _boot()
	assert_null(boot.field, "the newer slot's empty applied list does not open the field")
	assert_not_null(boot.menu)
	_handle_block_warnings()


func test_fail_a_newer_train_version_written_as_an_int_tag_blocks() -> void:
	_left_field()
	_write_train_board(_board({}))
	_rewrite_version(train_at, {"$type": "int", "value": str(TrainSave.SAVE_VERSION + 1)})
	var boot: Probe = _boot()
	assert_null(boot.field)
	assert_not_null(boot.menu)
	_handle_block_warnings()


func test_fail_a_newer_train_slot_wins_over_a_refusing_cell() -> void:
	_left_field()
	_write_train_board(_board({}))
	_rewrite_version(train_at, float(TrainSave.SAVE_VERSION + 1))
	_break_cell(train_at, "seg")
	var boot: Probe = _boot()
	assert_null(boot.field, "the version is read before the codec")
	assert_not_null(boot.menu)
	_handle_block_warnings()


# ---------------------------------------------------------------- hold before and after

func test_keep_a_slice_stop_does_not_start_from_the_field() -> void:
	_left_field({"slice": true, "slice_run": "boot_read"})
	var boot: Probe = _boot()
	assert_null(boot.field)
	assert_not_null(boot.menu)


func test_keep_a_train_without_the_return_starts_the_field() -> void:
	_left_field()
	_write_train_board(_board({}))
	var boot: Probe = _boot()
	assert_not_null(boot.field)
	assert_null(boot.menu)


func test_keep_a_train_with_the_return_starts_at_the_menu() -> void:
	_left_field()
	_write_train_board(_board({"ret_resume": true}))
	var boot: Probe = _boot()
	assert_null(boot.field)
	assert_not_null(boot.menu)


func test_keep_no_train_slot_starts_the_field() -> void:
	_left_field()
	var boot: Probe = _boot()
	assert_not_null(boot.field)
	assert_null(boot.menu)


func test_keep_a_version_less_train_slot_starts_at_the_menu() -> void:
	_left_field()
	_write_train_board(_board({"ret_resume": true}))
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(train_at))
	parsed.erase("version")
	_write_text(train_at, JSON.stringify(parsed, "", false, true))
	assert_false((JSON.parse_string(FileAccess.get_file_as_string(train_at)) as Dictionary).has("version"))
	var boot: Probe = _boot()
	assert_null(boot.field, "a board without a version is not this build's")
	assert_not_null(boot.menu)
	_handle_block_warnings()


func test_keep_a_newer_train_slot_with_the_return_applied_starts_at_the_menu() -> void:
	_left_field()
	_write_train_board(_board({"ret_resume": true}))
	_rewrite_version(train_at, float(TrainSave.SAVE_VERSION + 1))
	var boot: Probe = _boot()
	assert_null(boot.field)
	assert_not_null(boot.menu)
	_handle_block_warnings()


func test_keep_a_backup_alone_starts_the_field() -> void:
	_left_field()
	_write_train_board(_board({}), train_at + ".bak")
	assert_false(FileAccess.file_exists(train_at))
	var boot: Probe = _boot()
	assert_not_null(boot.field)
	assert_null(boot.menu)


func test_keep_a_bad_record_row_sends_the_read_to_the_backup() -> void:
	_left_field()
	var bad: Dictionary = _board({})
	bad["fieldReturns"] = {"applied": {}, "records": [{"receiptId": 1, "seg": 0}]}
	_write_train_board(bad)
	_write_train_board(_board({}), train_at + ".bak")
	var boot: Probe = _boot()
	assert_not_null(boot.field, "the backup's board is believed")
	assert_null(boot.menu)
