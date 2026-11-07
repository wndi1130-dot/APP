extends "res://addons/gut/test.gd"
## Exercise boot's choice and factory, keeping GUT's current scene.
const Boot = preload("res://game/boot.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const SliceSave = preload("res://game/sim/slice_save.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const FieldReturn = preload("res://game/politics/field_return.gd")
const TrainSave = preload("res://game/politics/save_slot.gd")
const TrainDom = preload("res://game/train/train_dom.gd")

var folder: String = "user://test_boot_read_once_%d" % OS.get_process_id()
var slice_path: String = folder + "/slice.json"
var train_path: String = folder + "/train.json"
var field_path: String = folder + "/field.json"
var roots: Array[Node] = []
## The machine's own autostart must not open a stop where a menu is expected.
var had_auto: bool = false
var old_auto: String = ""


class FlowProbe extends SliceFlow:
	var before_restore: Dictionary = {}
	var reads_before_restore: int = -1

	func _start_field() -> void:
		before_restore = field_resume.duplicate()
		reads_before_restore = FieldSave._test_reads
		super._start_field()
		if is_instance_valid(field):
			field.set_process(false)
			field.set_physics_process(false)


class BootProbe extends Boot:
	var opened: FlowProbe = null
	var before_restore: Dictionary = {}
	var reads_before_restore: int = -1
	var before_slice: Callable

	func _start_slice(resume: Dictionary = {}) -> void:
		if before_slice.is_valid():
			before_slice.call()
		var configured: Node = _make_slice(resume)
		opened = FlowProbe.new()
		opened.opts = configured.opts
		configured.free()
		opened.opts["cinema"] = false
		opened.opts["map_threads"] = false
		opened.opts["still"] = true
		add_child(opened)
		opened.set_process(false)

	func _start(resume: Dictionary = {}) -> void:
		before_restore = resume.duplicate()
		reads_before_restore = FieldSave._test_reads
		super._start(resume)
		field.set_process(false)
		field.set_physics_process(false)


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	_clear_slots()
	FieldSave._test_reads = 0
	SliceSave._test_train_parses = 0
	had_auto = OS.has_environment("S2_AUTOSTART")
	old_auto = OS.get_environment("S2_AUTOSTART")
	OS.unset_environment("S2_AUTOSTART")


func after_each() -> void:
	for node: Node in roots:
		if is_instance_valid(node):
			node.free()
	roots.clear()
	OS.unset_environment("S2_AUTOSTART")
	if had_auto:
		OS.set_environment("S2_AUTOSTART", old_auto)
	_clear_slots()
	FieldSave._test_reads = 0
	SliceSave._test_train_parses = 0
	await get_tree().process_frame


func _clear_slots() -> void:
	for path: String in [slice_path, train_path, field_path, field_path + ".bak", field_path + ".other"]:
		SliceSave.clear(path)
		FieldSave.clear(path)


## The train's own slot (the board a new run starts on) carrying what it took in.
func _write_train(applied: Dictionary) -> void:
	var board: Array = SliceFlow.start_board()
	var g: Dictionary = (board[0] as Dictionary).duplicate(true)
	if g.get("dom") == null:
		g["dom"] = TrainDom.start()
	TrainDom.ensure(g)
	TrainSave.fill_defaults(g)
	g["fieldReturns"] = {"applied": applied, "records": []}
	assert_true(SliceSave.write_train(g, train_path))


## The board boot_choice decides over, the same one boot reads.
func _choice() -> Dictionary:
	return SliceSave.boot_choice(slice_path, train_path, SliceFlow.start_board()[1], field_path)


func _boot(before_slice: Callable = Callable()) -> BootProbe:
	var boot: BootProbe = BootProbe.new()
	boot.slice_save_path = slice_path
	boot.train_save_path = train_path
	boot.field_save_path = field_path
	boot.before_slice = before_slice
	roots.append(boot)
	FieldSave._test_reads = 0
	add_child(boot)
	return boot


func _pick() -> Dictionary:
	var board: Array = SliceFlow.start_board()
	return SliceSave.pick(slice_path, train_path, board[1], field_path)


func _left_slice(campaign: bool, ended: bool = false) -> Dictionary:
	var flow: SliceFlow = SliceFlow.new()
	flow.opts = {"save": true, "seed": 5, "cinema": false, "map_threads": false,
		"still": true, "slice_save_path": slice_path,
		"train_save_path": train_path, "field_save_path": field_path}
	if campaign:
		flow.opts["mode"] = "campaign"
	add_child(flow)
	flow.set_process(false)
	if campaign:
		for _turn: int in 32:
			if flow.current() == "stop_pick" or flow.campaign_error != "":
				break
			if SliceFlow.papers_of(flow.train_g):
				flow._take(SliceFlow.pick_first(flow.train_g, flow.train_t))
			flow.train_on()
		assert_eq(flow.campaign_error, "")
		assert_eq(flow.current(), "stop_pick")
		flow.next()
	else:
		flow.go(flow._index_of("field"))
	assert_not_null(flow.field)
	if not is_instance_valid(flow.field):
		flow.free()
		return {}
	assert_true(flow.field.is_built)
	flow.field.set_process(false)
	flow.field.set_physics_process(false)
	flow.field.clock.elapsed = 77.0
	flow.field.receipt.place_note("manholeBlocked", true)
	if ended:
		flow.field.finish("departed")
	else:
		flow.field.interrupt()
	assert_true(flow._save_slice())
	var saved: Dictionary = FieldSave.read(field_path)
	flow.free()
	return saved


func _left_standalone() -> Dictionary:
	var game: FieldGame = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false,
		"receipt_id": "ret_boot_once", "field_save": true, "field_save_path": field_path}
	game.opts["squad"] = game.default_squad("crude")
	add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.clock.elapsed = 77.0
	game.interrupt()
	var saved: Dictionary = FieldSave.read(field_path)
	game.free()
	return saved


func _assert_field(game: Node, saved: Dictionary, before: Dictionary) -> void:
	assert_true(before.get("field_resume") is Dictionary)
	if before.get("field_resume") is Dictionary:
		assert_eq(FieldSave.to_json(before["field_resume"]), FieldSave.to_json(saved))
	assert_eq(before.get("receipt_id"), saved["receipt_id"])
	assert_almost_eq(game.clock.elapsed, float(saved["clock"]["elapsed"]), 0.001)
	assert_eq(game.opts.get("receipt_id"), saved["receipt_id"])
	assert_false(game.opts.has("field_resume"), "the live field releases the parsed save")
	assert_true(game.opts.get("field_save", false))


func _assert_slice(campaign: bool) -> void:
	var saved: Dictionary = _left_slice(campaign)
	var expected: Dictionary = _pick() # Legacy caller, without a read context.
	assert_eq(expected["step"], "field")
	var boot: BootProbe = _boot()
	assert_not_null(boot.opened)
	assert_null(boot.field)
	assert_null(boot.menu)
	if boot.opened == null:
		return
	var flow: FlowProbe = boot.opened
	assert_eq(flow.current(), expected["step"])
	assert_eq(flow.run, expected["run"])
	assert_eq(FieldReturn.canonical(flow.contract), FieldReturn.canonical(expected["contract"]))
	assert_eq(FieldReturn.canonical(flow.receipt), FieldReturn.canonical(expected["receipt"]))
	assert_eq(SliceSave.applied_ids(flow.train_g), SliceSave.applied_ids(expected["g"]))
	assert_eq(flow.reads_before_restore, 1)
	assert_eq(FieldSave._test_reads, 1)
	assert_true(flow.field_resume.is_empty())
	assert_false(flow.opts.has("_field_read"))
	assert_false((flow.opts["resume"] as Dictionary).has("_field_read"))
	_assert_field(flow.field, saved, flow.before_restore)


func test_campaign_field_boot_parses_once_and_restores_the_same_visit() -> void:
	_assert_slice(true)


func test_slice_field_boot_keeps_its_single_parse_and_same_return() -> void:
	_assert_slice(false)


func test_standalone_boot_keeps_its_single_parse_and_resume_options() -> void:
	var saved: Dictionary = _left_standalone()
	_write_train({})
	var choice: Dictionary = _choice()
	assert_eq(String(choice["kind"]), "field")
	var expected: Dictionary = choice["resume"]
	var boot: BootProbe = _boot()
	assert_null(boot.opened)
	assert_null(boot.menu)
	assert_not_null(boot.field)
	assert_eq(boot.reads_before_restore, 1)
	assert_eq(FieldSave._test_reads, 1)
	assert_eq(FieldSave.to_json(boot.before_restore), FieldSave.to_json(expected))
	_assert_field(boot.field, saved, boot.before_restore)


func test_matching_slice_receipt_keeps_zero_field_parses() -> void:
	_left_slice(false, true)
	var expected: Dictionary = _pick()
	assert_eq(expected["step"], "receipt")
	var boot: BootProbe = _boot()
	assert_not_null(boot.opened)
	assert_eq(FieldSave._test_reads, 0)
	assert_eq(boot.opened.current(), "receipt")
	assert_null(boot.opened.field)
	assert_true(boot.opened.field_resume.is_empty())
	assert_eq(FieldSave.to_json(boot.opened.receipt), FieldSave.to_json(expected["receipt"]))
	assert_false(boot.opened.opts.has("_field_read"))


func test_torn_slice_receipt_keeps_one_parse_and_its_number_types() -> void:
	_left_slice(false, true)
	var metadata: Dictionary = SliceSave.read(slice_path)
	metadata["receipt"] = {}
	metadata["train_sha"] = "torn"
	assert_true(SliceSave.write(metadata, slice_path))
	var expected: Dictionary = _pick()
	assert_true(expected["reconciled"])
	var boot: BootProbe = _boot()
	assert_eq(FieldSave._test_reads, 1)
	assert_eq(boot.opened.current(), expected["step"])
	assert_null(boot.opened.field)
	assert_eq(FieldSave.to_json(boot.opened.receipt), FieldSave.to_json(expected["receipt"]))
	assert_true(boot.opened.receipt["version"] is int)


func test_changed_field_between_pick_and_slice_is_read_again() -> void:
	var saved: Dictionary = _left_slice(true)
	saved["clock"]["elapsed"] = 88.0
	var rewrite: Callable = func() -> void:
		assert_true(FieldSave.write(saved, field_path))
	var boot: BootProbe = _boot(rewrite)
	assert_eq(boot.opened.reads_before_restore, 2, "changed bytes require a fresh parse")
	assert_eq(FieldSave._test_reads, 2)
	_assert_field(boot.opened.field, saved, boot.opened.before_restore)


func test_missing_field_is_remembered_but_a_new_file_is_not_hidden() -> void:
	var saved: Dictionary = _left_standalone()
	FieldSave.clear(field_path)
	var context: Dictionary = {}
	FieldSave._test_reads = 0
	assert_eq(FieldSave.read_for_start(field_path, context), {})
	assert_eq(FieldSave.read_for_start(field_path, context), {})
	assert_eq(FieldSave._test_reads, 0)
	assert_true(FieldSave.write(saved, field_path))
	assert_eq(FieldSave.read_for_start(field_path, context), saved)
	assert_eq(FieldSave._test_reads, 1)
	FieldSave.clear(field_path)
	assert_eq(FieldSave.read_for_start(field_path, context), {})


func test_backup_and_path_changes_invalidate_the_boot_read() -> void:
	var saved: Dictionary = _left_standalone()
	assert_eq(DirAccess.rename_absolute(field_path, field_path + ".bak"), OK)
	var context: Dictionary = {}
	FieldSave._test_reads = 0
	assert_eq(FieldSave.read_for_start(field_path, context), saved)
	assert_eq(FieldSave.read_for_start(field_path, context), saved)
	assert_eq(FieldSave._test_reads, 1)
	var changed: Dictionary = saved.duplicate(true)
	changed["clock"]["elapsed"] = 88.0
	assert_true(FieldSave.write(changed, field_path + ".bak"))
	assert_eq(FieldSave.read_for_start(field_path, context), changed)
	assert_eq(FieldSave._test_reads, 2)
	assert_true(FieldSave.write(saved, field_path + ".other"))
	assert_eq(FieldSave.read_for_start(field_path + ".other", context), saved)
	assert_eq(FieldSave._test_reads, 3)


func test_default_callers_still_read_each_time() -> void:
	_left_standalone()
	_write_train({})
	FieldSave._test_reads = 0
	SliceSave._test_train_parses = 0
	var first: Dictionary = _choice()
	var reads: int = FieldSave._test_reads
	var parses: int = SliceSave._test_train_parses
	assert_gt(reads, 0)
	assert_gt(parses, 0)
	assert_eq(_choice(), first)
	assert_eq(FieldSave._test_reads, reads * 2, "each boot_choice reads the field slot again")
	assert_eq(SliceSave._test_train_parses, parses * 2, "and each train candidate again")
	_clear_slots()
	_left_slice(true)
	FieldSave._test_reads = 0
	SliceSave._test_train_parses = 0
	var picked: Dictionary = _pick()
	reads = FieldSave._test_reads
	parses = SliceSave._test_train_parses
	assert_gt(parses, 0)
	assert_eq(_pick(), picked)
	assert_eq(FieldSave._test_reads, reads * 2)
	assert_eq(SliceSave._test_train_parses, parses * 2, "the legacy pick reads each time too")


func test_orphan_slice_field_still_opens_the_menu() -> void:
	_left_slice(false)
	SliceSave.clear(slice_path)
	var boot: BootProbe = _boot()
	assert_eq(FieldSave._test_reads, 1)
	assert_null(boot.opened)
	assert_null(boot.field)
	assert_not_null(boot.menu)


func test_empty_slots_do_not_parse_a_field() -> void:
	var boot: BootProbe = _boot()
	assert_eq(FieldSave._test_reads, 0)
	assert_null(boot.opened)
	assert_null(boot.field)
	assert_not_null(boot.menu)


func test_boot_parses_each_train_candidate_once() -> void:
	_write_train({})
	SliceSave._test_train_parses = 0
	_boot()
	assert_eq(SliceSave._test_train_parses, 1, "the slot alone is one parse")
	assert_eq(FieldSave._test_reads, 0, "the menu path reads no field")
	_write_train({})  # the second write keeps the first as the backup
	assert_true(FileAccess.file_exists(train_path + ".bak"))
	SliceSave._test_train_parses = 0
	_boot()
	assert_eq(SliceSave._test_train_parses, 2, "the slot and its backup, both read")
	SliceSave.clear(train_path)
	SliceSave._test_train_parses = 0
	_boot()
	assert_eq(SliceSave._test_train_parses, 0, "no train file, nothing parsed")
