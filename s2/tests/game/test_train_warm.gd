extends GutTest
## Run by the calling session. This worktree must not launch Godot or GUT.

const Scene = preload("res://game/train/train_scene.gd")
const Rules = preload("res://game/train/train_rules.gd")
const Catalog = preload("res://game/train/train_catalog.gd")
const Interior = preload("res://game/train/train_interior.gd")
const Warm = preload("res://game/train/train_warm.gd")
const MAX_FRAMES: int = 2400
var _saved_cfg_path: String
var _saved_held: Dictionary
var _saved_dress: Dictionary


func before_each() -> void:
	_saved_cfg_path = Warm.cfg_path
	_saved_held = Warm.held.duplicate()
	_saved_dress = Interior._dress_meshes.duplicate()
	Warm.cfg_path = "user://test_train_warm_%d_%d.cfg" % [get_instance_id(), Time.get_ticks_usec()]


func after_each() -> void:
	if FileAccess.file_exists(Warm.cfg_path):
		assert_eq(DirAccess.remove_absolute(Warm.cfg_path), OK)
	Warm.cfg_path = _saved_cfg_path
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
	return s


func _frame(s: Scene, advance_restage: bool = true) -> void:
	await get_tree().process_frame
	if advance_restage:
		s._step_restages()
	s.warm.step()


func _drain(s: Scene) -> void:
	var frames: int = 0
	while s.warm.state != "done" and frames < MAX_FRAMES:
		var dress_before: int = int(s.warm.stats["dress"])
		var requests_before: int = s.warm.requested
		await _frame(s)
		assert_lte(s.warm._in_flight.size(), Warm.WARM_IN_FLIGHT)
		assert_lte(s.warm.requested - requests_before, Warm.WARM_IN_FLIGHT)
		assert_lte(int(s.warm.stats["dress"]) - dress_before, 1)
		frames += 1
	assert_eq(s.warm.state, "done", "warming finishes within the frame limit")


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
	assert_eq(Warm.held, _saved_held)


func test_guard_paths_include_tier_stove_and_dress_without_duplicates() -> void:
	var guard: Dictionary = {}
	for def: Dictionary in Rules.display_cars(Rules.load_default()):
		if def["id"] == "guard":
			guard = def
	assert_false(guard.is_empty())
	var paths: Dictionary = Warm.paths_for([guard, guard])
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
	var paths: Dictionary = Warm.paths_for([{"id": "guard", "interior": fixture}])
	layouts.erase(fixture)
	assert_eq(paths["dress"], ["wood_wall_box"])
	assert_eq(paths["scenes"], [Interior.MODEL_ROOT + "wood_wall_box.glb", Interior.model_path("bed")])
	assert_eq(Interior.model_path("wood_wall_box"), Interior.MODEL_ROOT + "wood_wall_box.glb")
	assert_eq(Interior.model_path("bed"), Interior.COMMON_ROOT + "bed.glb")


func test_enabled_warm_holds_cached_scenes_and_dress_and_finishes_once() -> void:
	_config(false)  # A boolean option takes precedence over the file.
	var s := _scene({"warm": true})
	assert_eq(s.warm.state, "waiting")
	assert_gt(int(s.warm.stats["paths"]), 0)
	for _frame_index: int in range(Warm.WARM_DELAY_FRAMES):
		await _frame(s)
		assert_eq(s.warm.state, "waiting")
		assert_eq(s.warm.requested, 0)
		assert_eq(int(s.warm.stats["cached"]), 0)
	await _drain(s)
	var definitions: Array = []
	for c: Dictionary in s.cars:
		definitions.append(c["def"])
	var paths: Dictionary = Warm.paths_for(definitions)
	for path: String in paths["scenes"]:
		assert_true(ResourceLoader.has_cached(path), path)
		assert_true(Warm.held.has(path), path)
		if Warm.held.has(path):
			assert_eq(load(path), Warm.held[path], "the exact cached resource is retained")
	for model: String in paths["dress"]:
		assert_true(Interior._dress_meshes.has(model), model)
		assert_not_null(Interior._dress_meshes.get(model), model)
	assert_eq(int(s.warm.stats["failed"]), 0)
	assert_eq(int(s.warm.stats["paths"]), (paths["scenes"] as Array).size())
	assert_eq(int(s.warm.stats["loaded"]) + int(s.warm.stats["cached"]), int(s.warm.stats["paths"]))
	assert_eq(int(s.warm.stats["dress"]), (paths["dress"] as Array).size())
	assert_gte(float(s.warm.stats["ms"]), 0.0)
	assert_true(s.warm.stats.has("static_mb_delta"))
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
