extends "res://addons/gut/test.gd"
## Stop form stays with the field through a save (decision 494).

const StopForm = preload("res://game/sim/stop_form.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const SidePath = preload("res://game/world/side_path.gd")


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


func test_remote_resumes_a_small_version_two_grid_through_legacy_restore() -> void:
	var first: FieldGame = _game({"stop_form": "city"})
	first.clock.elapsed = 321.0
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(first)))
	assert_eq(int(saved["version"]), 2)
	assert_eq(saved["runtime"]["levels"][0]["solid"].size(), 1800, "the old remote map was 60 by 30")
	saved["stop_form"] = "remote"
	# An exact-only flag distinguishes the fallback from an attempted runtime restore.
	saved["runtime"]["game"]["glass_warned"] = true
	var back: FieldGame = _game(FieldSave.resume_opts(saved))
	assert_eq(back.stop_form, "remote")
	assert_eq(back.clock.elapsed, 321.0, "the fallback still restores the saved clock")
	assert_gt(back.grid.width, BareLine.WIDTH)
	assert_eq(back.grid.height, BareLine.HEIGHT)
	assert_eq(back.grid.solid.size(), back.grid.width * back.grid.height)
	assert_eq(back.grid.walk_people.size(), back.grid.solid.size())
	assert_eq(back.grid.walk_dead.size(), back.grid.solid.size())
	assert_false(back.glass_warned, "the incompatible exact runtime was skipped")
	assert_engine_error_count(0)
	assert_push_warning_count(1)


func test_exact_grid_size_check_covers_every_saved_floor() -> void:
	var ground: FieldGrid = FieldGrid.new(2, 3)
	var upper: FieldGrid = FieldGrid.new(2, 3)
	var game: Dictionary = {"levels": {0: ground, 1: upper}}
	var saved: Dictionary = {"runtime": {"levels": {
		0: {"solid": ground.solid.duplicate()}, 1: {"solid": upper.solid.duplicate()}}}}
	assert_true(FieldSave._grid_sizes_match(game, saved))
	saved["runtime"]["levels"][1]["solid"] = PackedByteArray([0])
	assert_false(FieldSave._grid_sizes_match(game, saved), "a later floor prevents any exact restore")
	assert_eq(ground.solid.size(), 6, "checking does not mutate an earlier floor")
	saved["runtime"]["levels"][1]["solid"] = upper.solid.duplicate()
	game["levels"].erase(1)
	assert_false(FieldSave._grid_sizes_match(game, saved), "a saved floor must still exist")


func test_shape_stop_rebuilds_a_city_side_path_and_drops_ahead_data_for_remote() -> void:
	var place: String = "houses_01"
	var handed: Dictionary = {}
	var run_seed: int = -1
	for seed_value: int in range(1, 200):
		if not SidePath.rolls(place, seed_value):
			continue
		handed = SidePath.add(FieldMaps.build(place), seed_value)
		if handed.has("side_path"):
			run_seed = seed_value
			break
	assert_gt(run_seed, 0)
	if run_seed < 0:
		return
	handed["stop_form"] = "city"
	var bare: Dictionary = FieldMaps.build(place)
	for key: String in FieldGame.AHEAD_KEYS:
		handed[key] = "made ahead"
		bare[key] = "fresh ahead"
	var rebuilt: Array[bool] = [false]
	var fresh: Callable = func() -> Dictionary:
		rebuilt[0] = true
		return bare
	var now: Dictionary = FieldGame.shape_stop(handed, "remote", run_seed, 600.0, fresh)
	assert_true(rebuilt[0], "a city map with a side path is built again bare")
	assert_false(now.has("side_path"))
	for key: String in FieldGame.AHEAD_KEYS:
		assert_false(now.has(key), key + ": no ahead data survives the remote resize")
	assert_eq(now["stop_form"], "remote")
	assert_false(is_same(now["grid"], handed["grid"]))
	assert_gt(now["grid"].width, bare["grid"].width)
	assert_eq(now["grid"].height, bare["grid"].height, "the old side path's growth is discarded")
