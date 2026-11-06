extends "res://addons/gut/test.gd"
## 설정 창의 스틱·무전·상태 아이콘은 플레이어가 고른 대로 정차 사이·판 사이에 남는다(user://controls.cfg [field]).
## 슬라이스·캠페인이 정차마다 새 필드를 만들 때(slice_flow._field_opts) 남긴 값을 넣고, 그렇게 만든
## 필드(opts["prefs"])에서 바꿀 때만 남긴다 — 밝기(screen_lift.gd)처럼, 촬영 도구·시험·봇이 만든 필드는
## 파일을 읽지도 쓰지도 않는다. 전에는 슬라이스가 이 셋을 넘기지 않아 정차마다 처음 값으로 돌아갔다.

const FieldPrefs = preload("res://game/ui/field_prefs.gd")
const FieldGame = preload("res://game/field_game.gd")
const SliceFlow = preload("res://game/slice_flow.gd")

const TEST_FILE: String = "user://controls_test.cfg"


func before_each() -> void:
	DirAccess.remove_absolute(TEST_FILE)
	FieldPrefs.where = TEST_FILE


func after_each() -> void:
	DirAccess.remove_absolute(TEST_FILE)
	FieldPrefs.where = FieldPrefs.FILE


func _saved() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(TEST_FILE)
	return cfg


func _game(opts: Dictionary) -> Node:
	var game = FieldGame.new()
	var o: Dictionary = {"seed": 5, "raiders": false, "auto_pause": false, "arrive": false}
	o.merge(opts, true)
	game.opts = o
	add_child_autofree(game)
	game.set_process(false)
	return game


# ---------------------------------------------------------------- the file


func test_nothing_kept_leaves_the_options_as_they_are() -> void:
	var o: Dictionary = {"seed": 3}
	FieldPrefs.fill(o)
	assert_eq(o, {"seed": 3, "prefs": true}, "only the mark that this field keeps what is changed")
	assert_false(FileAccess.file_exists(TEST_FILE), "filling reads, never writes")


func test_what_was_kept_comes_back_and_what_is_asked_wins() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("field", "stick_float", true)
	cfg.set_value("field", "radio", "often")
	cfg.set_value("field", "status_size", 64)
	cfg.save(TEST_FILE)
	var o: Dictionary = {}
	FieldPrefs.fill(o)
	assert_eq(o.get("stick_float"), true)
	assert_eq(o.get("radio"), "often")
	assert_eq(o.get("status_size"), 64)
	var asked: Dictionary = {"radio": "off"}
	FieldPrefs.fill(asked)
	assert_eq(asked["radio"], "off", "a value the field is made with stays")
	assert_eq(asked.get("stick_float"), true)


func test_a_kept_value_of_the_wrong_kind_is_left_out() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("field", "stick_float", "yes")
	cfg.set_value("field", "radio", 3)
	cfg.set_value("field", "status_size", "big")
	cfg.set_value("field", "melee_chain", false)
	cfg.save(TEST_FILE)
	var o: Dictionary = {}
	FieldPrefs.fill(o)
	assert_eq(o, {"prefs": true}, "a broken or foreign value never reaches the field")


func test_a_broken_file_is_as_none() -> void:
	var f := FileAccess.open(TEST_FILE, FileAccess.WRITE)
	f.store_string("[field\nstick_float = = tru")
	f.close()
	var o: Dictionary = {}
	FieldPrefs.fill(o)
	assert_eq(o, {"prefs": true})
	assert_engine_error("ConfigFile parse error", "the engine says the file is broken; the field goes on as if none")


# ---------------------------------------------------------------- the slice


func test_each_stop_of_the_slice_gets_what_the_player_chose() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("field", "stick_float", true)
	cfg.set_value("field", "radio", "off")
	cfg.set_value("field", "status_size", 80)
	cfg.save(TEST_FILE)
	var f = SliceFlow.new()
	f.opts = {"skip_field": true, "seed": 7, "cinema": false}
	add_child_autofree(f)
	f.next()
	var o: Dictionary = f._field_opts()
	assert_eq(o.get("stick_float"), true, "the stick as chosen, not back to fixed")
	assert_eq(o.get("radio"), "off")
	assert_eq(o.get("status_size"), 80)
	assert_true(bool(o.get("prefs", false)), "and its field keeps what is changed there")


# ---------------------------------------------------------------- the panel


func test_a_change_in_a_play_field_is_kept_for_the_next_stop() -> void:
	var game = _game({"prefs": true})
	var hud = game.hud
	hud._set_stick()
	hud._set_radio()
	hud._set_status_size()
	var cfg := _saved()
	assert_eq(cfg.get_value("field", "stick_float", null), true)
	assert_eq(cfg.get_value("field", "radio", null), game.radio_mode())
	assert_eq(cfg.get_value("field", "status_size", null), hud.status_diameter())
	hud._set_stick()
	assert_eq(_saved().get_value("field", "stick_float", null), false, "turned back, kept back")
	var next: Dictionary = {}
	FieldPrefs.fill(next)
	assert_eq([next["stick_float"], next["radio"], next["status_size"]], [false, game.radio_mode(), hud.status_diameter()], "the next stop starts as this one was left")
	if hud.modal_open:
		hud._close_modal()


func test_a_field_not_made_by_the_play_flow_keeps_nothing() -> void:
	var game = _game({})
	game.hud._set_stick()
	game.hud._set_status_size()
	assert_true(game.hud.stick_floats(), "the change still holds on that field")
	assert_false(FileAccess.file_exists(TEST_FILE), "but a tool's or a test's field writes no file")
	if game.hud.modal_open:
		game.hud._close_modal()
