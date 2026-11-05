extends "res://addons/gut/test.gd"
## Story names keep their own band and hand-made ground while borrowing a map kind.

const StoryMaps = preload("res://game/world/story_maps.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const RouteBands = preload("res://game/train/route_bands.gd")
const StopGround = preload("res://game/world/stop_ground.gd")
const FieldGame = preload("res://game/field_game.gd")
const MapRing = preload("res://game/world/map_ring.gd")
const BuildingUses = preload("res://game/world/building_uses.gd")
const SidePath = preload("res://game/world/side_path.gd")
const StopLoader = preload("res://game/stop_loader.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const StopForm = preload("res://game/sim/stop_form.gd")
const StoryFixture = preload("res://tests/fixtures/story_fixture_map.gd")
const FORMS: Array[String] = ["city", "edge", "siding", "remote"]


func test_only_the_three_exact_names_are_story_maps() -> void:
	assert_eq_deep(StoryMaps.BASE, {"story_01": "freight", "story_02": "freight", "story_03": "office"})
	for id: String in StoryMaps.BASE:
		assert_true(StoryMaps.is_story(id), id)
		assert_eq(StoryMaps.base_of(id), StoryMaps.BASE[id], id)
	for id: String in ["", "story", "story_1", "story_00", "story_04", "STORY_01", "story_01.gd", "../story_01", "story_01/../freight_01", "freight_01"]:
		assert_false(StoryMaps.is_story(id), id)
		assert_eq(StoryMaps.base_of(id), "", id)
		assert_eq(StoryMaps.stop_of(id), [], id)
	assert_eq(StoryMaps.stop_of("story_01"), [])
	assert_eq_deep(StoryMaps.stop_of("story_02"), ["act1", 10])
	assert_eq_deep(StoryMaps.stop_of("story_03"), ["act2", 1])


func test_missing_story_scripts_resolve_to_the_default_without_joining_the_registry() -> void:
	# Story maps never join the random picks; a story name whose script is not there yet resolves to the default.
	assert_eq(FieldMaps.ids().size(), 82)
	for id: String in StoryMaps.BASE:
		assert_false(FieldMaps.ids().has(id), id)
		if not ResourceLoader.exists(FieldMaps.path_of(id)):
			assert_false(FieldMaps.has(id), id)
			assert_eq(FieldMaps.resolve(id), FieldMaps.DEFAULT_PLACE, id)


func test_story_registry_only_lists_scripts_that_exist() -> void:
	var expected: Array[String] = []
	for id: String in StoryMaps.BASE:
		assert_eq(FieldMaps.path_of(id), FieldMaps.MAP_DIR + id + ".gd")
		var exists := ResourceLoader.exists(FieldMaps.path_of(id))
		assert_eq(FieldMaps.has(id), exists, id)
		if exists:
			expected.append(id)
	assert_eq(FieldMaps.story_ids(), expected)
	for id: String in ["story_1", "story_04", "story_01.gd", "../story_01", "story_01/../freight_01", "freight_1", "../freight_01"]:
		assert_false(FieldMaps.has(id), id)


func test_existing_story_scripts_keep_their_names_and_borrowed_kinds() -> void:
	var ids := FieldMaps.story_ids()
	if ids.is_empty():
		pass_test("No story map files yet.")
		return
	for id in ids:
		var data := FieldMaps.build(id)
		assert_eq(data["place_id"], id, id)
		assert_eq(data["place_kind"], StoryMaps.base_of(id), id)


func test_story_bands_and_building_groups_come_from_their_own_stop_and_base() -> void:
	assert_eq(RouteBands.band_of("story_02", "prologue", 1), "K10")
	assert_eq(RouteBands.band_of("story_03", "prologue", 1), "K10")
	assert_eq(RouteBands.band_of("story_01", "prologue", 1), "K1")
	assert_eq_deep(RouteBands.place_stop(FieldMaps.DEFAULT_PLACE), ["prologue", 1])
	assert_eq(BuildingUses.group_of("story_01"), "freight")
	assert_eq(BuildingUses.group_of("story_02"), "freight")
	assert_eq(BuildingUses.group_of("story_03"), "office")
	assert_eq(MapRing.width_for("freight"), 30)
	assert_eq(MapRing.width_for("office"), 30)


func test_slice_keeps_the_act_of_a_maps_own_stop() -> void:
	assert_eq_deep(SliceFlow.stop_at_for([], 3), ["prologue", 3])
	assert_eq_deep(SliceFlow.stop_at_for(["prologue", 1], SliceFlow.FIRST_SEG + 1), ["prologue", 2])
	assert_eq_deep(SliceFlow.stop_at_for(["act1", 10], SliceFlow.FIRST_SEG), ["act1", 10])
	assert_eq_deep(SliceFlow.stop_at_for(["act2", 1], 5), ["act2", 1])
	assert_eq(RouteBands.stop_band("act1", 10), "K10")
	assert_eq(StopForm.on_route("act2", 1), "remote")


func _ground(data: Dictionary) -> Dictionary:
	var g = data["grid"]
	return {"size": Vector2i(g.width, g.height), "train": data["train"],
		"doors": (data["train_doors"] as Dictionary).duplicate(true),
		"spawn_doors": (data["spawns"]["train_door"] as Array).duplicate(true),
		"kind": data["place_kind"]}


func _assert_kept(data: Dictionary, before: Dictionary) -> void:
	assert_eq_deep(_ground(data), before)
	for key: String in FieldGame.AHEAD_KEYS:
		assert_eq(data.get(key), "made ahead: " + key, key)
	assert_eq_deep(data["spots"]["work_site"], {"job": "wood", "amount": 3})
	assert_false(data.has("stop_form"), "the map has no grown stop ground")


func test_every_form_keeps_story_ground_ahead_data_and_work_even_with_a_side_path() -> void:
	for form in FORMS:
		for with_path in [false, true]:
			var data: Dictionary = StoryFixture.build()
			if with_path:
				data["side_path"] = {"side": 1}
			for key: String in FieldGame.AHEAD_KEYS:
				data[key] = "made ahead: " + key
			data["spots"]["work_site"] = {"job": "wood", "amount": 3}
			var before := _ground(data)
			var applied := StopGround.apply(data, form, 7)
			assert_true(is_same(applied, data), form)
			_assert_kept(applied, before)
			var fresh: Callable = func() -> Dictionary:
				fail_test("A story map must not be built again for " + form)
				return data
			var shaped := FieldGame.shape_stop(data, form, 7, -1.0, fresh)
			assert_true(is_same(shaped, data), form)
			_assert_kept(shaped, before)
			assert_eq(shaped.has("side_path"), with_path)
			if with_path:
				assert_eq_deep(shaped["side_path"], {"side": 1})


func test_story_names_skip_the_ring_but_a_normal_name_still_grows() -> void:
	for id: String in StoryMaps.BASE:
		var data: Dictionary = StoryFixture.build()
		data["place_id"] = id
		var before := _ground(data)
		var kept := MapRing.add(data)
		assert_true(is_same(kept, data), id)
		assert_eq_deep(_ground(kept), before)
	for kind: String in ["freight", "office"]:
		var normal: Dictionary = StoryFixture.build()
		normal["place_id"] = kind + "_01"
		normal["place_kind"] = kind
		var size: Vector2i = _ground(normal)["size"]
		var grown := MapRing.add(normal)
		assert_eq(_ground(grown)["size"], size + Vector2i(60, 60), kind)
		assert_eq(grown["place_kind"], kind)


func _side_seed(id: String) -> int:
	for run_seed in range(1, 257):
		if SidePath.rolls(id, run_seed):
			return run_seed
	fail_test("No side-path roll found for " + id)
	return 0


func test_story_names_keep_their_ground_even_when_a_side_path_rolls() -> void:
	for id: String in StoryMaps.BASE:
		var data: Dictionary = StoryFixture.build()
		data["place_id"] = id
		var before := _ground(data)
		var run_seed := _side_seed(id)
		assert_true(SidePath.rolls(id, run_seed))
		var kept := SidePath.add(data, run_seed)
		assert_true(is_same(kept, data), id)
		assert_eq_deep(_ground(kept), before)
		assert_false(kept.has("side_path"), id)


func test_field_side_path_keeps_story_ahead_data_when_a_side_path_rolls() -> void:
	for id: String in StoryMaps.BASE:
		var data: Dictionary = StoryFixture.build()
		data["place_id"] = id
		for key: String in FieldGame.AHEAD_KEYS:
			data[key] = "made ahead: " + key
		var before := _ground(data)
		var run_seed := _side_seed(id)
		assert_true(SidePath.rolls(id, run_seed))
		var kept := FieldGame.with_side_path(data, run_seed)
		assert_true(is_same(kept, data), id)
		assert_eq_deep(_ground(kept), before)
		for key: String in FieldGame.AHEAD_KEYS:
			assert_eq(kept.get(key), "made ahead: " + key, key)
		assert_false(kept.has("side_path"), id)


func test_loader_keeps_story_ground_for_every_form_with_nonnegative_seeds() -> void:
	var before := _ground(StoryFixture.build())
	for form in FORMS:
		for run_seed: int in [0, _side_seed(StoryFixture.PLACE_ID)]:
			var ready := StopLoader.make_ready(StoryFixture, run_seed, form)
			assert_eq_deep(_ground(ready), before)
			assert_eq(ready["place_id"], StoryFixture.PLACE_ID)
			assert_eq(ready["place_kind"], "freight")
			assert_eq(ready["_side_seed"], run_seed)
			assert_has(ready, "_ground_key")
			assert_false(ready.has("stop_form"), form)
			assert_false(ready.has("side_path"), form)


func _game(extra: Dictionary = {}):
	var game = FieldGame.new()
	var opts := {"seed": 7, "raiders": false, "auto_pause": false, "arrive": false, "arrival_horde": false}
	opts.merge(extra, true)
	game.opts = opts
	game.map_script = StoryFixture
	add_child_autofree(game)
	game.set_process(false)
	return game


func test_remote_clock_and_unchanged_story_ground_survive_save_and_resume() -> void:
	var before := _ground(StoryFixture.build())
	var first = _game({"stop_form": "remote"})
	assert_eq(first.data["place_id"], StoryFixture.PLACE_ID)
	assert_eq_deep(_ground(first.data), before)
	first.clock.elapsed = 123.0
	var saved := FieldSave.from_json(FieldSave.to_json(FieldSave.capture(first)))
	assert_eq(saved["place"], first.place)
	assert_eq(saved["stop_form"], "remote")
	assert_eq(saved["stop_ground"], "")
	var opts := FieldSave.resume_opts(saved)
	assert_eq(opts["place"], first.place)
	assert_eq(opts["stop_form"], "remote")
	assert_eq(opts["stop_ground"], "")
	var back = _game(opts)
	assert_eq(back.place, first.place)
	assert_eq(back.stop_form, first.stop_form)
	assert_eq(back.data["place_id"], StoryFixture.PLACE_ID)
	assert_eq_deep(_ground(back.data), before)
	assert_eq(back.clock.elapsed, 123.0)
	assert_eq(back.clock.safe_sec, 1800.0)
	assert_eq(back.clock.limit_sec, 2400.0)
	var resumed := FieldSave.capture(back)
	assert_eq(resumed["place"], first.place)
	assert_eq(resumed["stop_form"], saved["stop_form"])
	assert_eq(resumed["stop_ground"], saved["stop_ground"])


func test_existing_story_place_resumes_without_a_forced_map_script() -> void:
	var ids := FieldMaps.story_ids()
	if ids.is_empty():
		pass_test("No story map files yet.")
		return
	for id in ids:
		var first = FieldGame.new()
		first.opts = {"place": id, "seed": 7, "raiders": false, "auto_pause": false,
			"arrive": false, "arrival_horde": false}
		add_child_autofree(first)
		first.set_process(false)
		assert_null(first.map_script)
		assert_eq(first.place, id)
		assert_eq(first.data["place_id"], id)
		var saved := FieldSave.from_json(FieldSave.to_json(FieldSave.capture(first)))
		assert_eq(saved["place"], id)
		var opts := FieldSave.resume_opts(saved)
		assert_eq(opts["place"], id)
		var back = FieldGame.new()
		back.opts = opts
		add_child_autofree(back)
		back.set_process(false)
		assert_null(back.map_script)
		assert_eq(back.place, id)
		assert_eq(back.data["place_id"], id)
