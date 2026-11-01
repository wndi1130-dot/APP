extends GutTest
## Run by the calling session. This worktree must not launch Godot or GUT.

const Scene = preload("res://game/train/train_scene.gd")
const Rules = preload("res://game/train/train_rules.gd")
const Catalog = preload("res://game/train/train_catalog.gd")
const Interior = preload("res://game/train/train_interior.gd")
const Warm = preload("res://game/train/train_warm.gd")
const MAX_FRAMES: int = 2400
const MAX_REAP_FRAMES: int = 120
var _saved_cfg_path: String
var _saved_default_on: bool
var _saved_held: Dictionary
var _saved_dress: Dictionary
var _scenes: Array[Scene] = []
var _files: Array[String] = []


func before_each() -> void:
	_saved_cfg_path = Warm.cfg_path
	_saved_default_on = Warm.default_on
	_saved_held = Warm.held.duplicate()
	_saved_dress = Interior._dress_meshes.duplicate()
	Warm.held.clear()
	Interior._dress_meshes.clear()
	assert_true(Warm._requests.is_empty())
	assert_true(Warm._orphans.is_empty())
	Warm.cfg_path = "user://test_train_warm_%d_%d.cfg" % [get_instance_id(), Time.get_ticks_usec()]


func after_each() -> void:
	# Exit before restoring shared caches; GUT frees the empty viewports later.
	for s: Scene in _scenes:
		if is_instance_valid(s):
			s.free()
	_scenes.clear()
	await _drain_orphans()
	for path: String in _files:
		if FileAccess.file_exists(path):
			assert_eq(DirAccess.remove_absolute(path), OK)
	_files.clear()
	if FileAccess.file_exists(Warm.cfg_path):
		assert_eq(DirAccess.remove_absolute(Warm.cfg_path), OK)
	Warm.cfg_path = _saved_cfg_path
	Warm.default_on = _saved_default_on
	Warm.held = _saved_held
	Interior._dress_meshes = _saved_dress


func _scene(options: Dictionary = {"warm": true}) -> Scene:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1688, 780)
	viewport.own_world_3d = true
	add_child_autofree(viewport)
	var s := Scene.new()
	s.rules = Rules.load_default()
	s.rules["train"]["home"] = {"guard": 0}
	s.rules["view"]["daytime"] = "night"
	s.opts = {"seed": 7, "panel": false, "baked_people": false, "view_mode": "section"}
	s.opts.merge(options, true)
	viewport.add_child(s)
	s.set_process(false)  # One scheduler step per observed process_frame.
	_scenes.append(s)
	return s


func _frame(s: Scene, advance_restage: bool = true) -> void:
	await get_tree().process_frame
	var busy: bool = s.restaging()
	if advance_restage:
		s._step_restages()
	s.warm.step(busy)


func _drain(s: Scene) -> void:
	var frames: int = 0
	while s.warm.state != "done" and frames < MAX_FRAMES:
		var dress_before: int = int(s.warm.stats["dress"])
		var requests_before: int = s.warm.requested
		var next_dress: int = s.warm._next_dress
		await _frame(s)
		assert_lte(s.warm._in_flight.size(), Warm.WARM_IN_FLIGHT)
		assert_lte(Warm._requests.size(), Warm.WARM_IN_FLIGHT)
		assert_lte(s.warm.requested - requests_before, Warm.WARM_IN_FLIGHT)
		assert_lte(int(s.warm.stats["dress"]) - dress_before, 1)
		if s.warm._next_dress > next_dress:
			var path: String = Interior.MODEL_ROOT + String(s.warm._dress[next_dress]) + ".glb"
			if not s.warm._keep.has(path):
				assert_false(Warm.held.has(path), "dress-only scene is dropped in its mesh frame")
		frames += 1
	assert_eq(s.warm.state, "done", "warming finishes within the frame limit")
	assert_true(s.warm._in_flight.is_empty())
	assert_true(Warm._requests.is_empty())


func _drain_orphans() -> void:
	var frames: int = 0
	while not Warm._orphans.is_empty() and frames < MAX_REAP_FRAMES:
		await get_tree().process_frame
		frames += 1
	assert_true(Warm._orphans.is_empty(), "retired requests finish within a few frames")
	assert_true(Warm._requests.is_empty())
	assert_null(Warm._reaper._tree, "the reaper disconnects when it has no work")
	assert_false(get_tree().process_frame.is_connected(Warm._reaper._poll))


func _fresh_path() -> String:
	var path: String = Warm.cfg_path + "_%d.tscn" % _files.size()
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		file.store_string("[gd_scene format=3]\n\n[node name=\"WarmFixture\" type=\"Node3D\"]\n")
		file.close()
	_files.append(path)
	assert_false(ResourceLoader.has_cached(path), "this path has never been loaded")
	return path


func _only_paths(s: Scene, paths: Array) -> void:
	s.warm._cars = []
	s.warm._paths = paths
	s.warm._dress = []
	s.warm._wait_frames = 0
	s.warm.stats["paths"] = paths.size()


func _handle_loader_errors(path: String) -> void:
	# Failed/invalid requests deliberately report engine errors; keep script errors visible.
	for tracked: Variant in get_errors():
		var detail: String = String(tracked.code) + String(tracked.rationale)
		var loader: bool = String(tracked.file).ends_with("resource_loader.cpp") \
			or String(tracked.file).ends_with("resource_format_text.cpp")
		if tracked.is_engine_error() and loader and (detail.contains(path.get_file()) \
				or String(tracked.function) == "load_threaded_get"):
			tracked.handled = true


func _snapshot(s: Scene) -> Dictionary:
	return {"state": s.warm.state, "stats": s.warm.stats.duplicate(),
		"requested": s.warm.requested, "wait": s.warm._wait_frames,
		"car": s.warm._next_car, "path": s.warm._next_path, "dress": s.warm._next_dress,
		"pending": s.warm._in_flight.duplicate()}


func _config(on: bool) -> void:
	var config := ConfigFile.new()
	config.set_value("warm", "on", on)
	assert_eq(config.save(Warm.cfg_path), OK)


func _assert_off(s: Scene) -> void:
	assert_eq(s.warm.state, "off")
	for _frame_index: int in range(Warm.WARM_DELAY_FRAMES + 5):
		await _frame(s)
	assert_eq(s.warm.state, "off")
	assert_eq(s.warm.requested, 0)
	assert_eq(int(s.warm.stats["paths"]), 0, "disabled warming never collects model paths")
	assert_eq(int(s.warm.stats["loaded"]), 0)
	assert_eq(int(s.warm.stats["cached"]), 0)
	assert_eq(int(s.warm.stats["dress"]), 0)
	assert_true(Warm.held.is_empty())


func test_guard_paths_include_tier_stove_and_dress_without_duplicates() -> void:
	var guard: Dictionary = {}
	for def: Dictionary in Rules.display_cars(Rules.load_default()):
		if def["id"] == "guard":
			guard = def
	assert_false(guard.is_empty())
	var car: Dictionary = {"def": guard, "home_stage": 0}
	var paths: Dictionary = Warm.paths_for([car, car])
	var scenes: Array = paths["scenes"]
	var dress: Array = paths["dress"]
	assert_has(scenes, "res://models/train_interior/drum_stove.glb")
	assert_has(scenes, Scene.STOVE_MODEL)
	assert_eq(Warm.STOVE_MODEL, Scene.STOVE_MODEL)
	assert_has(dress, "insulation_panel")
	assert_has(dress, "pale_paneling")
	for path: String in scenes:
		assert_eq(scenes.count(path), 1)
		assert_true(ResourceLoader.exists(path), path)
	for model: String in dress:
		assert_eq(dress.count(model), 1)
		assert_has(scenes, Interior.MODEL_ROOT + model + ".glb")


func test_paths_filter_car_and_home_before_resolving_models() -> void:
	var layouts: Dictionary = Catalog.data()["layouts"]
	var fixture: String = "__warm_test_%d" % get_instance_id()
	layouts[fixture] = {"props": [
		{"model": "drum_stove", "system": "stove", "cars": ["other"]},
		{"model": "pale_paneling", "dress": true, "home": [4, 5]},
		{"model": "insulation_panel", "dress": true, "home": [1, 1],
			"home_model": {"0": "pale_paneling", "1": "wood_wall_box"}},
		{"model": "bed"}, {"model": "__warm_missing_model"}]}
	var paths: Dictionary = Warm.paths_for([{
		"def": {"id": "guard", "interior": fixture}, "home_stage": 0}])
	layouts.erase(fixture)
	assert_eq(paths["dress"], ["wood_wall_box"])
	assert_eq(paths["scenes"], [Interior.MODEL_ROOT + "wood_wall_box.glb", Interior.model_path("bed")])
	assert_eq(Interior.model_path("wood_wall_box"), Interior.MODEL_ROOT + "wood_wall_box.glb")
	assert_eq(Interior.model_path("bed"), Interior.COMMON_ROOT + "bed.glb")


func test_enabled_warm_holds_cached_scenes_and_dress_and_finishes_once() -> void:
	_config(false)  # A boolean option takes precedence over the file.
	var s := _scene({"warm": true})
	assert_eq(s.warm.state, "waiting")
	assert_eq(int(s.warm.stats["paths"]), 0, "begin only stores the car list")
	for _frame_index: int in range(Warm.WARM_DELAY_FRAMES):
		var car_before: int = s.warm._next_car
		await _frame(s)
		assert_eq(s.warm._next_car, mini(car_before + 1, s.cars.size()))
		assert_eq(s.warm.state, "waiting")
		assert_eq(s.warm.requested, 0)
		assert_eq(int(s.warm.stats["cached"]), 0)
	# Saved caches may retain every catalog resource; force a genuinely new request too.
	var fresh_path: String = _fresh_path()
	s.warm._paths.append(fresh_path)
	s.warm._keep[fresh_path] = true
	s.warm.stats["paths"] += 1
	await _drain(s)
	assert_gt(s.warm.requested, 0)
	assert_gt(int(s.warm.stats["loaded"]), 0)
	assert_true(Warm.held.has(fresh_path))
	var paths: Dictionary = Warm.paths_for(s.cars)
	for path: String in paths["keep"]:
		assert_true(ResourceLoader.has_cached(path), path)
		assert_true(Warm.held.has(path), path)
		if Warm.held.has(path):
			assert_eq(load(path), Warm.held[path], "the exact cached resource is retained")
	for model: String in paths["dress"]:
		assert_true(Interior._dress_meshes.has(model), model)
		assert_not_null(Interior._dress_meshes.get(model), model)
		var path: String = Interior.MODEL_ROOT + model + ".glb"
		if not (paths["keep"] as Array).has(path):
			assert_false(Warm.held.has(path), "dress-only PackedScenes are released")
	assert_eq(int(s.warm.stats["failed"]), 0)
	assert_eq(int(s.warm.stats["paths"]), (paths["scenes"] as Array).size() + 1)
	assert_eq(int(s.warm.stats["loaded"]) + int(s.warm.stats["cached"]), int(s.warm.stats["paths"]))
	assert_eq(int(s.warm.stats["dress"]), (paths["dress"] as Array).size())
	assert_gte(float(s.warm.stats["ms"]), 0.0)
	assert_true(s.warm.stats.has("static_mb_delta"))
	assert_true(s.warm.stats.has("max_step_ms"))
	assert_true(s.warm.stats.has("max_dress_ms"))
	assert_gte(float(s.warm.stats["max_dress_ms"]), 0.0)
	assert_gte(float(s.warm.stats["max_step_ms"]), float(s.warm.stats["max_dress_ms"]))
	var finished: Dictionary = s.warm.stats.duplicate()
	for _frame_index: int in range(3):
		await _frame(s)
	assert_eq(s.warm.stats, finished, "done is terminal and keeps its first timing sample")


func test_false_option_overrides_enabled_config_without_requests() -> void:
	_config(true)
	await _assert_off(_scene({"warm": false}))


func test_config_false_disables_warming_without_requests() -> void:
	_config(false)
	await _assert_off(_scene({}))


func test_missing_config_enables_warming() -> void:
	Warm.default_on = true
	assert_false(FileAccess.file_exists(Warm.cfg_path))
	var s := _scene({})
	assert_eq(s.warm.state, "waiting")
	await _drain(s)
	assert_eq(int(s.warm.stats["failed"]), 0)


func test_restage_pauses_waiting_loading_and_new_requests() -> void:
	var s := _scene()
	for target_stage: int in [3, 1]:
		s.rules["train"]["home"]["guard"] = target_stage
		s.apply_rules()
		assert_true(s.restaging())
		var state_before: String = s.warm.state
		var stats_before: Dictionary = s.warm.stats.duplicate()
		var requests_before: int = s.warm.requested
		var wait_before: int = s.warm._wait_frames
		var path_before: int = s.warm._next_path
		var dress_before: int = s.warm._next_dress
		var pending_before: Array = s.warm._in_flight.duplicate()
		for _frame_index: int in range(Warm.WARM_DELAY_FRAMES + 2):
			await _frame(s, false)  # Keep the registered rebuild pending.
			assert_eq(s.warm.state, state_before)
			assert_eq(s.warm.stats, stats_before)
			assert_eq(s.warm.requested, requests_before)
			assert_eq(s.warm._wait_frames, wait_before)
			assert_eq(s.warm._next_path, path_before)
			assert_eq(s.warm._next_dress, dress_before)
			assert_eq(s.warm._in_flight, pending_before)
		s.finish_restage_now()
		assert_false(s.restaging())
		if target_stage == 3:
			for _frame_index: int in range(Warm.WARM_DELAY_FRAMES + 1):
				await _frame(s)
			assert_eq(s.warm.state, "loading", "also exercise a pause after warming starts")
	await _drain(s)
	assert_eq(int(s.warm.stats["failed"]), 0)


func test_next_home_stage_paths_come_first_and_shared_dress_is_kept() -> void:
	var layouts: Dictionary = Catalog.data()["layouts"]
	var fixture: String = "__warm_order_%d" % get_instance_id()
	layouts[fixture] = {"props": [
		{"model": "wood_wall_box", "home": [0, 0]},
		{"model": "pale_paneling", "dress": true, "home": [2, 2]},
		{"model": "pale_paneling", "home": [2, 2]},
		{"model": "insulation_panel", "dress": true, "home": [1, 1]}]}
	var car: Dictionary = {"def": {"id": "guard", "interior": fixture}, "home_stage": 1}
	var seen: Dictionary = {}
	var paths: Dictionary = Warm.paths_for([car, car], seen)
	layouts.erase(fixture)
	assert_eq(paths["scenes"], [Interior.MODEL_ROOT + "pale_paneling.glb",
		Interior.MODEL_ROOT + "wood_wall_box.glb", Interior.MODEL_ROOT + "insulation_panel.glb"])
	assert_has(paths["keep"], Interior.MODEL_ROOT + "pale_paneling.glb")
	assert_eq(seen.size(), 3, "existence results are shared across rows, tiers and cars")


func test_exit_hands_requests_to_reaper_without_waiting() -> void:
	var s := _scene()
	var path: String = _fresh_path()
	_only_paths(s, [path])
	s.warm.step(false)
	assert_eq(s.warm.requested, 1)
	assert_has(s.warm._in_flight, path)
	assert_has(Warm._requests, path)
	var warmer: Warm = s.warm
	s.free()
	assert_eq(warmer.state, "released")
	assert_true(warmer._in_flight.is_empty())
	assert_has(Warm._orphans, path, "exit transfers ownership before any frame can poll")
	assert_has(Warm._requests, path)
	assert_true(get_tree().process_frame.is_connected(Warm._reaper._poll))
	await _drain_orphans()
	assert_eq(ResourceLoader.load_threaded_get_status(path), ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
	assert_true(Warm.held.is_empty(), "the reaper never retains a departed train's resources")
	warmer.release()
	await get_tree().process_frame
	assert_engine_error_count(0)


func test_failed_request_leaves_no_pending_path() -> void:
	var s := _scene()
	var path: String = Warm.cfg_path + "_missing.tscn"
	assert_false(FileAccess.file_exists(path))
	_only_paths(s, [path])
	await _drain(s)
	assert_eq(s.warm.requested, 1)
	assert_eq(int(s.warm.stats["failed"]), 1)
	assert_false(Warm.held.has(path))
	assert_eq(ResourceLoader.load_threaded_get_status(path), ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
	_handle_loader_errors(path)


func test_invalid_request_is_collected_and_removed() -> void:
	var s := _scene()
	var path: String = _fresh_path()
	_only_paths(s, [path])
	s.warm.step(false)
	assert_has(Warm._requests, path)
	var frames: int = 0
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS \
			and frames < MAX_REAP_FRAMES:
		await get_tree().process_frame
		frames += 1
	assert_eq(ResourceLoader.load_threaded_get_status(path), ResourceLoader.THREAD_LOAD_LOADED)
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return  # Never block on a test timeout either.
	# Model a request another consumer has already collected.
	ResourceLoader.load_threaded_get(path)
	assert_eq(ResourceLoader.load_threaded_get_status(path), ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
	await _drain(s)
	assert_eq(int(s.warm.stats["failed"]), 1)
	_handle_loader_errors(path)


func test_failed_orphan_is_collected_after_exit() -> void:
	var s := _scene()
	var path: String = _fresh_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string("this is not a scene\n")
	file.close()
	_only_paths(s, [path])
	s.warm.step(false)
	assert_has(s.warm._in_flight, path, "a recognized scene path starts a request before parsing fails")
	s.free()
	assert_has(Warm._orphans, path)
	await _drain_orphans()
	assert_eq(ResourceLoader.load_threaded_get_status(path), ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
	_handle_loader_errors(path)


func test_restage_finishing_frame_does_not_advance_warming() -> void:
	var s := _scene()
	s.rules["train"]["home"]["guard"] = 3
	s.apply_rules()
	assert_true(s.restaging())
	var frames: int = 0
	while s.restaging() and frames < MAX_FRAMES:
		await get_tree().process_frame
		var before: Dictionary = _snapshot(s)
		s._process(0.0)  # Exercise the real ordering, including its last rebuild unit.
		assert_eq(_snapshot(s), before)
		frames += 1
	assert_gt(frames, 0)
	assert_false(s.restaging())
	var wait_before: int = s.warm._wait_frames
	s._process(0.0)
	assert_eq(s.warm._wait_frames, wait_before - 1, "the following idle frame can warm")


func test_exit_clears_held_and_only_dress_added_by_warming() -> void:
	var preserved := BoxMesh.new()
	Interior._dress_meshes["__warm_preexisting"] = preserved
	var s := _scene()
	var before: Dictionary = Interior._dress_meshes.duplicate()
	await _drain(s)
	var added: Array = s.warm._dress_added.keys()
	assert_gt(added.size(), 0, "future tiers add meshes that the initial train did not build")
	assert_gt(Warm.held.size(), 0)
	# A later non-warm entry must survive too.
	Interior._dress_meshes["__warm_later"] = preserved
	s.free()
	assert_true(Warm.held.is_empty())
	for model: String in added:
		assert_false(Interior._dress_meshes.has(model), model)
	for model: String in before:
		assert_eq(Interior._dress_meshes.get(model), before[model], model)
	assert_eq(Interior._dress_meshes.get("__warm_later"), preserved)
	var again := _scene()
	assert_eq(again.warm.state, "waiting")
	assert_eq(again.warm._next_car, 0)
	await _drain(again)
	assert_gt(Warm.held.size(), 0, "a later visit warms again")


func test_reentry_waits_for_old_request_to_be_collected() -> void:
	var first := _scene()
	var path: String = _fresh_path()
	_only_paths(first, [path])
	first.warm.step(false)
	assert_has(Warm._requests, path)
	first.free()
	var again := _scene()
	_only_paths(again, [path])
	again.warm.step(false)
	assert_eq(again.warm.requested, 0, "the same path still belongs to the reaper")
	await _drain(again)
	assert_eq(int(again.warm.stats["loaded"]) + int(again.warm.stats["cached"]), 1)
	assert_true(Warm._orphans.is_empty())


func test_dress_only_scene_is_dropped_but_shared_scene_is_kept() -> void:
	var model: String = "pale_paneling"
	var path: String = Interior.MODEL_ROOT + model + ".glb"
	for shared: bool in [false, true]:
		var s := _scene()
		Interior._dress_meshes.erase(model)
		_only_paths(s, [path])
		s.warm._dress = [model]
		if shared:
			s.warm._keep[path] = true
		await _drain(s)
		assert_eq(int(s.warm.stats["dress"]), 1)
		assert_not_null(Interior._dress_meshes.get(model))
		assert_eq(Warm.held.has(path), shared)
		s.free()


func test_command_line_default_matches_gut_detection() -> void:
	var running_gut: bool = " ".join(OS.get_cmdline_args()).contains("gut_cmdln.gd")
	assert_eq(Warm.default_on, not running_gut)


func test_missing_config_uses_false_default() -> void:
	Warm.default_on = false
	await _assert_off(_scene({}))


func test_boolean_config_overrides_false_default() -> void:
	Warm.default_on = false
	_config(true)
	assert_true(Warm._enabled({}))
	assert_true(Warm._enabled({"warm": "not a boolean"}))


func test_non_boolean_config_warns_and_uses_default() -> void:
	var config := ConfigFile.new()
	config.set_value("warm", "on", "false")
	assert_eq(config.save(Warm.cfg_path), OK)
	Warm.default_on = false
	assert_false(Warm._enabled({}))
	Warm.default_on = true
	assert_true(Warm._enabled({}))
	assert_push_warning_count(2)


func test_unreadable_config_warns_and_uses_default() -> void:
	var file := FileAccess.open(Warm.cfg_path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string("[warm\non=true\n")
	file.close()
	Warm.default_on = false
	assert_false(Warm._enabled({}))
	assert_push_warning_count(1)
	for tracked: Variant in get_errors():
		if tracked.is_engine_error() and String(tracked.file).ends_with("config_file.cpp"):
			tracked.handled = true
