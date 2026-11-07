extends "res://addons/gut/test.gd"
## Where the app starts (S3 spec 4, user decision 296): no save starts fresh, a
## stop left mid-play comes back while the train has not taken its return in,
## and once the train has, the start is fresh again.

const Boot = preload("res://game/boot.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const SliceSave = preload("res://game/sim/slice_save.gd")
const TrainSave = preload("res://game/politics/save_slot.gd")
const TrainDom = preload("res://game/train/train_dom.gd")

var folder: String = "user://test_field_resume_start_%d" % OS.get_process_id()
var field_at: String = folder + "/field_save.json"
var train_at: String = folder + "/train_save.json"
var slice_at: String = folder + "/slice.json"
## The machine's own autostart must not open a stop where a menu is expected.
var had_auto: bool = false
var old_auto: String = ""


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
	FieldSave.clear(field_at)
	SliceSave.clear(train_at)
	SliceSave.clear(slice_at)


func _boot():
	var boot = Boot.new()
	boot.field_save_path = field_at
	boot.train_save_path = train_at
	boot.slice_save_path = slice_at
	add_child_autofree(boot)
	return boot


## A stop played for a while and pushed away mid-play: what the slot holds then.
func _left_mid_play() -> Dictionary:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "receipt_id": "ret_resume", "field_save": true, "field_save_path": field_at}
	game.opts["squad"] = game.default_squad("crude")
	add_child_autofree(game)
	game.set_process(false)
	game.clock.elapsed = 77.0
	game.player.position += Vector3(1.5, 0, 0)
	game.interrupt()
	return FieldSave.read(field_at)


## The train's own slot (the board a new run starts on) carrying what it took in.
func _train_took(ids: Array) -> void:
	var applied := {}
	for id in ids:
		applied[id] = true
	var board: Array = SliceFlow.start_board()
	var g: Dictionary = (board[0] as Dictionary).duplicate(true)
	if g.get("dom") == null:
		g["dom"] = TrainDom.start()
	TrainDom.ensure(g)
	TrainSave.fill_defaults(g)
	g["fieldReturns"] = {"applied": applied, "records": []}
	assert_true(SliceSave.write_train(g, train_at))


func _boot_choice() -> Dictionary:
	return SliceSave.boot_choice(slice_at, train_at, SliceFlow.start_board()[1], field_at)


func test_with_no_save_the_app_starts_at_the_menu() -> void:
	assert_eq(String(_boot_choice()["kind"]), "menu")
	var boot = _boot()
	assert_null(boot.field, "no stop is started")
	assert_not_null(boot.menu, "the start screen is up")


func test_a_stop_left_mid_play_comes_back_while_the_train_has_not_taken_it_in() -> void:
	var saved := _left_mid_play()
	assert_eq(saved["phase"], "field")
	_train_took([])
	var choice: Dictionary = _boot_choice()
	assert_eq(String(choice["kind"]), "field")
	var boot = _boot()
	assert_not_null(boot.field, "the stop is started at once")
	assert_null(boot.menu)
	assert_almost_eq(boot.field.clock.elapsed, 77.0, 0.001, "at the time it was left")
	assert_true(bool(boot.field.opts.get("field_save", false)), "and it goes on saving")
	assert_eq(String(boot.field.opts.get("receipt_id", "")), "ret_resume")


func test_once_the_train_took_the_return_in_the_app_starts_fresh() -> void:
	_left_mid_play()
	_train_took(["ret_resume"])
	assert_eq(String(_boot_choice()["kind"]), "menu")
	var boot = _boot()
	assert_null(boot.field)
	assert_not_null(boot.menu)


func test_a_stop_that_ended_writes_its_end_and_does_not_come_back() -> void:
	_left_mid_play()
	var game = FieldGame.new()
	game.opts = {"seed": 6, "raiders": false, "auto_pause": false, "field_save": true, "field_save_path": field_at}
	game.opts["squad"] = game.default_squad("crude")
	add_child_autofree(game)
	game.set_process(false)
	game.finish("departed")
	assert_eq(FieldSave.read(field_at)["phase"], "ended")
	assert_eq(String(_boot_choice()["kind"]), "menu")
