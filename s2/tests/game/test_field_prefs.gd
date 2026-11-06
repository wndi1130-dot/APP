extends "res://addons/gut/test.gd"
## 설정 창의 스틱·무전·상태 아이콘은 플레이어가 고른 대로 정차 사이·판 사이에 남는다(user://controls.cfg [field]).
## 슬라이스·캠페인이 정차마다 새 필드를 만들 때(slice_flow._field_opts)와 저장에서 다시 세울 때
## (_resumed_field_opts) 남긴 값을 넣고, 그렇게 만든 필드(opts["prefs"])에서 바꿀 때만 남긴다 — 밝기
## (screen_lift.gd)처럼, 촬영 도구·시험·봇이 직접 만든 필드는 파일을 쓰지 않는다. 스크립트로 띄운 실행은
## 슬라이스를 거쳐도 플레이어의 파일을 읽지도 쓰지도 않는다. 쓰기가 실패하면 이 실행 동안 기억했다가 다시
## 쓰고, 읽을 수 없는 파일은 덮어쓰지 않고 옆으로 옮긴다(6 Pro 점검). 전에는 슬라이스가 이 셋을 넘기지
## 않아 정차마다 처음 값으로 돌아갔다.

const FieldPrefs = preload("res://game/ui/field_prefs.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")

## This run's own file: two runs on one PC share user:// (6 Pro 점검).
var file: String = "user://controls_test_%d.cfg" % OS.get_process_id()
var no_dir: String = "user://controls_test_%d_missing" % OS.get_process_id()


func before_each() -> void:
	_clear()
	FieldPrefs.where = file


func after_each() -> void:
	_clear()
	FieldPrefs.where = FieldPrefs.FILE


func _clear() -> void:
	for path: String in [file, file + FieldPrefs.BROKEN_SUFFIX, no_dir.path_join("c.cfg")]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(no_dir):
		DirAccess.remove_absolute(no_dir)
	FieldPrefs._unsaved = {}


func _saved() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(file)
	return cfg


func _game(opts: Dictionary) -> Node:
	var game = FieldGame.new()
	var o: Dictionary = {"seed": 5, "raiders": false, "auto_pause": false, "arrive": false, "arrival_horde": false}
	o.merge(opts, true)
	game.opts = o
	game.map_script = BareLine
	add_child_autofree(game)
	game.set_process(false)
	return game


func _shut(game) -> void:
	if game.hud.modal_open:
		game.hud._close_modal()


# ---------------------------------------------------------------- the file


func test_nothing_kept_leaves_the_options_as_they_are() -> void:
	var o: Dictionary = {"seed": 3}
	FieldPrefs.fill(o)
	assert_eq(o, {"seed": 3, "prefs": true}, "only the mark that this field keeps what is changed")
	assert_false(FileAccess.file_exists(file), "filling reads, never writes")


func test_what_was_kept_comes_back_and_what_is_asked_wins() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("field", "stick_float", true)
	cfg.set_value("field", "radio", "often")
	cfg.set_value("field", "status_size", 64)
	cfg.save(file)
	var o: Dictionary = {}
	FieldPrefs.fill(o)
	assert_eq(o.get("stick_float"), true)
	assert_eq(o.get("radio"), "often")
	assert_eq(o.get("status_size"), 64)
	var asked: Dictionary = {"radio": "off"}
	FieldPrefs.fill(asked)
	assert_eq(asked["radio"], "off", "a value the field is made with stays")
	assert_eq(asked.get("stick_float"), true)


## The player changed one setting: the file holds that one, and reading it is quiet
## (the null default on a missing key was an engine error at every stop).
func test_a_file_with_only_some_values_gives_those() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("field", "radio", "often")
	cfg.save(file)
	var o: Dictionary = {}
	FieldPrefs.fill(o)
	assert_eq(o, {"radio": "often", "prefs": true})


func test_a_kept_value_of_the_wrong_kind_is_left_out() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("field", "stick_float", "yes")
	cfg.set_value("field", "radio", 3)
	cfg.set_value("field", "status_size", "big")
	cfg.set_value("field", "melee_chain", false)
	cfg.save(file)
	var o: Dictionary = {}
	FieldPrefs.fill(o)
	assert_eq(o, {"prefs": true}, "a broken or foreign value never reaches the field")


func test_a_broken_file_is_as_none() -> void:
	var f := FileAccess.open(file, FileAccess.WRITE)
	f.store_string("[field\nstick_float = = tru")
	f.close()
	var o: Dictionary = {}
	FieldPrefs.fill(o)
	assert_eq(o, {"prefs": true})
	assert_engine_error("ConfigFile parse error", "the engine says the file is broken; the field goes on as if none")


func test_a_change_keeps_the_other_values_in_the_file() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("field", "radio", "often")
	cfg.set_value("other", "kept", 7)
	cfg.save(file)
	var game = _game({"prefs": true})
	game.hud._set_stick()
	var after := _saved()
	assert_eq(after.get_value("field", "stick_float", null), true)
	assert_eq(after.get_value("field", "radio", null), "often", "a kept value beside it stays")
	assert_eq(after.get_value("other", "kept", null), 7, "and so does another section's")
	_shut(game)


func test_an_unreadable_file_is_moved_aside_not_written_over() -> void:
	var broken: String = "[field\nradio = = of"
	var f := FileAccess.open(file, FileAccess.WRITE)
	f.store_string(broken)
	f.close()
	var game = _game({"prefs": true})
	game.opts["stick_float"] = true
	assert_eq(FieldPrefs.keep(game, "stick_float"), OK, "a fresh file is written")
	assert_engine_error("ConfigFile parse error")
	assert_eq(FileAccess.get_file_as_string(file + FieldPrefs.BROKEN_SUFFIX), broken, "what could not be read is kept aside as it was")
	assert_eq(_saved().get_value("field", "stick_float", null), true)


func test_a_failed_write_is_held_for_the_next_stop_and_written_again() -> void:
	FieldPrefs.where = no_dir.path_join("c.cfg")   # its folder is not there: the write fails
	var game = _game({"prefs": true})
	game.opts["stick_float"] = true
	assert_ne(FieldPrefs.keep(game, "stick_float"), OK, "the write failed and says so")
	var next: Dictionary = {}
	FieldPrefs.fill(next)
	assert_eq(next.get("stick_float"), true, "the next stop still starts as the player chose")
	DirAccess.make_dir_absolute(no_dir)
	game.opts["radio"] = "often"
	assert_eq(FieldPrefs.keep(game, "radio"), OK)
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(FieldPrefs.where), OK)
	assert_eq(cfg.get_value("field", "stick_float", null), true, "the held value is written with the next")
	assert_eq(cfg.get_value("field", "radio", null), "often")
	assert_eq(FieldPrefs._unsaved, {}, "nothing held once it is on disk")


func test_a_script_run_never_reads_or_writes_the_player_file() -> void:
	assert_eq(FieldPrefs.path_for(FieldPrefs.FILE, false), FieldPrefs.FILE, "the game's own run uses the player's file")
	assert_eq(FieldPrefs.path_for(FieldPrefs.FILE, true), "", "a script's run (tests, shot tools, bots) does not")
	assert_eq(FieldPrefs.path_for(file, true), file, "a file a test points at is used as it is")
	assert_true(FieldPrefs._scripted(), "this run is the test runner's script")
	FieldPrefs.where = FieldPrefs.FILE
	var player: String = FieldPrefs.FILE
	var was_there: bool = FileAccess.file_exists(player)
	var stamp: int = FileAccess.get_modified_time(player) if was_there else 0
	var o: Dictionary = {}
	FieldPrefs.fill(o)
	assert_eq(o, {"prefs": true}, "nothing of the player's comes into a test's slice field")
	var game = _game({"prefs": true})
	game.hud._set_stick()
	assert_true(game.hud.stick_floats(), "the change holds on that field")
	assert_eq(FieldPrefs.keep(game, "stick_float"), ERR_SKIP)
	assert_eq(FileAccess.file_exists(player), was_there, "and the player's file is not made")
	if was_there:
		assert_eq(FileAccess.get_modified_time(player), stamp, "nor written")
	_shut(game)


# ---------------------------------------------------------------- the slice


func test_each_stop_of_the_slice_gets_what_the_player_chose() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("field", "stick_float", true)
	cfg.set_value("field", "radio", "off")
	cfg.set_value("field", "status_size", 80)
	cfg.save(file)
	var f = SliceFlow.new()
	f.opts = {"skip_field": true, "seed": 7, "cinema": false}
	add_child_autofree(f)
	f.next()
	var o: Dictionary = f._field_opts()
	assert_eq(o.get("stick_float"), true, "the stick as chosen, not back to fixed")
	assert_eq(o.get("radio"), "off")
	assert_eq(o.get("status_size"), 80)
	assert_true(bool(o.get("prefs", false)), "and its field keeps what is changed there")


## A field saved, through JSON, stood up again by the slice: what it was saved with
## stays, it keeps what is changed, and the next stop starts as it was left. A save
## from before (no mark) is stood up with the mark (6 Pro 점검).
func test_a_field_stood_up_from_its_save_keeps_what_is_changed() -> void:
	for old: bool in [false, true]:
		_clear()
		var source = _game({"prefs": true, "stick_float": true, "status_size": 80})
		var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(source)))
		assert_false(saved.is_empty(), "the save goes through JSON")
		_shut(source)
		if old:
			(saved["start_opts"] as Dictionary).erase("prefs")
		var f = SliceFlow.new()
		f.opts = {"skip_field": true, "seed": 7, "cinema": false}
		add_child_autofree(f)
		f.field_resume = FieldSave.resume_opts(saved)
		var o: Dictionary = f._resumed_field_opts()
		assert_true(f.field_resume.is_empty(), "the save is used once")
		assert_true(bool(o.get("prefs", false)), "the mark, old save or new (old %s)" % old)
		assert_eq(o.get("stick_float"), true, "what it was saved with stays")
		var game = _game(o)
		assert_eq(game.hud.status_diameter(), 80, "a size back from JSON reads as it was")
		game.hud._set_stick()
		game.hud._set_status_size()
		assert_eq(_saved().get_value("field", "stick_float", null), false, "a change on it is kept (old %s)" % old)
		var size: Variant = _saved().get_value("field", "status_size", null)
		assert_eq(typeof(size), TYPE_INT, "the next size is kept as a whole number")
		assert_eq(size, game.hud.status_diameter())
		var next: Dictionary = {}
		FieldPrefs.fill(next)
		assert_eq([next.get("stick_float"), next.get("status_size")], [false, game.hud.status_diameter()], "the next stop starts as this one was left")
		_shut(game)


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
	_shut(game)


func test_a_field_not_made_by_the_play_flow_keeps_nothing() -> void:
	var game = _game({})
	game.hud._set_stick()
	game.hud._set_radio()
	game.hud._set_status_size()
	assert_true(game.hud.stick_floats(), "the change still holds on that field")
	assert_eq(FieldPrefs.keep(game, "stick_float"), ERR_SKIP)
	assert_false(FileAccess.file_exists(file), "but a tool's or a test's field writes no file")
	_shut(game)
