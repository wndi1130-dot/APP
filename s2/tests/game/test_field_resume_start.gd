extends "res://addons/gut/test.gd"
## Where the app starts (S3 spec 4, user decision 296): no save starts fresh, a
## stop left mid-play comes back while the train has not taken its return in,
## and once the train has, the start is fresh again.

const Boot = preload("res://game/boot.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")

const DIR := "user://test_field_resume_start"
const FIELD_AT := DIR + "/field_save.json"
const TRAIN_AT := DIR + "/train_save.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_clear()


func after_each() -> void:
	_clear()


func _clear() -> void:
	FieldSave.clear(FIELD_AT)
	if FileAccess.file_exists(TRAIN_AT):
		DirAccess.remove_absolute(TRAIN_AT)


func _boot():
	var boot = Boot.new()
	boot.field_save_path = FIELD_AT
	boot.train_save_path = TRAIN_AT
	add_child_autofree(boot)
	return boot


## A stop played for a while and pushed away mid-play: what the slot holds then.
func _left_mid_play() -> Dictionary:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "receipt_id": "ret_resume", "field_save": true, "field_save_path": FIELD_AT}
	game.opts["squad"] = game.default_squad("crude")
	add_child_autofree(game)
	game.set_process(false)
	game.clock.elapsed = 77.0
	game.player.position += Vector3(1.5, 0, 0)
	game.interrupt()
	return FieldSave.read(FIELD_AT)


func _train_took(ids: Array) -> void:
	var applied := {}
	for id in ids:
		applied[id] = true
	var f := FileAccess.open(TRAIN_AT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "phase": "settle", "fieldReturns": {"applied": applied, "records": []}}))
	f.close()


func test_with_no_save_the_app_starts_at_the_menu() -> void:
	assert_eq(FieldSave.pick_start(FIELD_AT, TRAIN_AT), {})
	var boot = _boot()
	assert_null(boot.field, "no stop is started")
	assert_not_null(boot.menu, "the start screen is up")


func test_a_stop_left_mid_play_comes_back_while_the_train_has_not_taken_it_in() -> void:
	var saved := _left_mid_play()
	assert_eq(saved["phase"], "field")
	_train_took([])
	var boot = _boot()
	assert_not_null(boot.field, "the stop is started at once")
	assert_null(boot.menu)
	assert_almost_eq(boot.field.clock.elapsed, 77.0, 0.001, "at the time it was left")
	assert_true(bool(boot.field.opts.get("field_save", false)), "and it goes on saving")
	assert_eq(String(boot.field.opts.get("receipt_id", "")), "ret_resume")


func test_once_the_train_took_the_return_in_the_app_starts_fresh() -> void:
	_left_mid_play()
	_train_took(["ret_resume"])
	assert_eq(FieldSave.pick_start(FIELD_AT, TRAIN_AT), {})
	var boot = _boot()
	assert_null(boot.field)
	assert_not_null(boot.menu)


func test_a_stop_that_ended_writes_its_end_and_does_not_come_back() -> void:
	_left_mid_play()
	var game = FieldGame.new()
	game.opts = {"seed": 6, "raiders": false, "auto_pause": false, "field_save": true, "field_save_path": FIELD_AT}
	game.opts["squad"] = game.default_squad("crude")
	add_child_autofree(game)
	game.set_process(false)
	game.finish("departed")
	assert_eq(FieldSave.read(FIELD_AT)["phase"], "ended")
	assert_eq(FieldSave.pick_start(FIELD_AT, TRAIN_AT), {})

