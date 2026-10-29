extends "res://addons/gut/test.gd"
## Stop form stays with the field through a save (decision 494).

const StopForm = preload("res://game/sim/stop_form.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")


func _game(extra: Dictionary = {}):
	var game = FieldGame.new()
	var opts := {"seed": 7, "raiders": false, "auto_pause": false, "arrive": false, "arrival_horde": false}
	opts.merge(extra, true)
	game.opts = opts
	game.map_script = BareLine
	add_child_autofree(game)
	game.set_process(false)
	return game


func test_place_defaults() -> void:
	for kind in ["freight", "factory", "mine", "sawmill"]:
		assert_eq(StopForm.resolve({}, kind), "siding", kind)
	for kind in ["houses", "hospital", "church", "office", "lodge", "lake", "summit", "unknown", ""]:
		assert_eq(StopForm.resolve({}, kind), "city", kind)


func test_valid_opts_win_and_bad_values_use_the_place() -> void:
	for form in ["city", "edge", "remote", "siding"]:
		assert_eq(StopForm.resolve({"stop_form": form}, "mine"), form)
		assert_eq(StopForm.resolve({"stop_form": form}, "houses"), form)
	for bad in ["", "Remote", "other", null, 7, [], {}]:
		assert_eq(StopForm.resolve({"stop_form": bad}, "mine"), "siding")
		assert_eq(StopForm.resolve({"stop_form": bad}, "houses"), "city")
	assert_eq(StopForm.resolve({"departure": {"stop_form": "remote"}}, "houses"), "city")


func test_times_and_fill_shares() -> void:
	for form in ["city", "edge", "siding"]:
		assert_eq(StopForm.safe_sec(form), 1200.0)
		assert_eq(StopForm.limit_sec(form), 1800.0)
	assert_eq(StopForm.safe_sec("remote"), 1800.0)
	assert_eq(StopForm.limit_sec("remote"), 2400.0)
	assert_eq(StopForm.fill_share("city"), 1.0)
	assert_eq(StopForm.fill_share("edge"), 0.5)
	assert_eq(StopForm.fill_share("siding"), 1.0)
	assert_eq(StopForm.fill_share("remote"), 0.0)


func test_remote_field_sets_clock_horde_and_music_times() -> void:
	var game = _game({"stop_form": "remote"})
	assert_eq(game.stop_form, "remote")
	assert_eq(game.clock.safe_sec, 1800.0)
	assert_eq(game.clock.limit_sec, 2400.0)
	assert_eq(game.director.limit_sec, 2400.0)
	assert_almost_eq(game.director.call_range_mult(1800.0), 1.45, 0.0001)
	assert_almost_eq(game.director.call_range_mult(2400.0), 1.6, 0.0001)
	assert_eq(game.music.director.safe_sec, 1800.0)
	assert_true(game.music.director._may_explore({}, 800.0))
	game.clock.elapsed = 1200.0
	assert_false(game.clock.past_safe())
	game.clock.elapsed = 1800.0
	assert_true(game.clock.past_safe())
	assert_false(game.clock.past_limit())
	game.clock.elapsed = 2400.0
	assert_true(game.clock.past_limit())


func test_remote_survives_capture_json_and_resume() -> void:
	var first = _game({"stop_form": "remote"})
	first.clock.elapsed = 123.0
	var saved := FieldSave.from_json(FieldSave.to_json(FieldSave.capture(first)))
	assert_eq(saved["stop_form"], "remote")
	# The saved form wins over stale start options and derived runtime values.
	saved["start_opts"]["stop_form"] = "city"
	saved["runtime"]["components"]["director"]["limit_sec"] = 1800.0
	var next_opts := FieldSave.resume_opts(saved)
	assert_eq(next_opts["stop_form"], "remote")
	var back = _game(next_opts)
	assert_eq(back.stop_form, "remote")
	assert_eq(back.clock.elapsed, 123.0)
	assert_eq(back.clock.safe_sec, 1800.0)
	assert_eq(back.clock.limit_sec, 2400.0)
	assert_eq(back.director.limit_sec, 2400.0)
	assert_eq(back.music.director.safe_sec, 1800.0)


func test_old_save_resolves_from_start_opts_then_place() -> void:
	var first = _game({"stop_form": "remote"})
	var saved := FieldSave.from_json(FieldSave.to_json(FieldSave.capture(first)))
	saved.erase("stop_form")
	saved["runtime"]["components"]["director"].erase("limit_sec")
	var from_opts = _game(FieldSave.resume_opts(saved))
	assert_eq(from_opts.stop_form, "remote")
	assert_eq(from_opts.director.limit_sec, 2400.0)
	saved["start_opts"].erase("stop_form")
	var from_place = _game(FieldSave.resume_opts(saved))
	assert_eq(from_place.stop_form, "siding", "the fixture is a mine")
	assert_eq(from_place.clock.safe_sec, 1200.0)
	assert_eq(from_place.clock.limit_sec, 1800.0)
	assert_eq(from_place.director.limit_sec, 1800.0)
	assert_eq(from_place.music.director.safe_sec, 1200.0)
