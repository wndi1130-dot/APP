extends "res://addons/gut/test.gd"

const MapView = preload("res://game/world/map_view.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const PropModels = preload("res://game/world/prop_models.gd")


func after_each() -> void:
	ProjectSettings.set_setting(PropModels.MODE_SETTING, true)


func test_a_tree_cell_grows_the_same_tree_each_time() -> void:
	var a := MapView.tree_plant("church_01", Vector2i(10, 12))
	assert_eq(a, MapView.tree_plant("church_01", Vector2i(10, 12)))
	assert_ne(a, MapView.tree_plant("church_01", Vector2i(11, 12)), "the next cell, another tree")
	var at: Vector3 = a["at"]
	assert_between(at.x, 10.3, 10.7, "near the middle of its cell")
	assert_between(at.z, 12.3, 12.7)
	var size: Array = MapView.TREE_SIZE[a["model"]]
	assert_between(float(a["height"]), float(size[0]), float(size[1]))


func test_the_place_picks_its_trees() -> void:
	var shares := {}
	for place: String in ["bare_line_01", "sawmill_02", "lake_03", "houses_01", "church_02", "factory_01"]:
		var counts := {}
		for i in 400:
			var model := String(MapView.tree_plant(place, Vector2i(i % 20, floori(i / 20.0)))["model"])
			counts[model] = int(counts.get(model, 0)) + 1
		shares[place] = counts
	for place: String in ["bare_line_01", "sawmill_02"]:
		assert_gt(int((shares[place] as Dictionary).get(MapView.TREE_SPRUCE, 0)), 240, "spruce first in the woods (%s)" % place)
	assert_gt(int((shares["lake_03"] as Dictionary).get(MapView.TREE_WILLOW, 0)), 60, "willows by the water")
	for place: String in ["houses_01", "church_02"]:
		assert_gt(int((shares[place] as Dictionary).get(MapView.TREE_STREET, 0)), 60, "street trees in town (%s)" % place)
		assert_gt(int((shares[place] as Dictionary).get(MapView.TREE_ORCHARD, 0)), 15, "and fruit trees (%s)" % place)
	assert_gt(int((shares["factory_01"] as Dictionary).get(MapView.TREE_BARE, 0)), int((shares["factory_01"] as Dictionary).get(MapView.TREE_SPRUCE, 0)), "the rail works mostly leafless")


func test_tree_cells_are_models_not_boxes_and_keep_their_cells() -> void:
	var data: Dictionary = FieldMaps.build_from(load(FieldMaps.path_of("bare_line_01")))
	var solids := (data["grid"].solid as PackedByteArray).duplicate()
	var view: Node3D = autofree(MapView.new())
	view.setup(data)
	var planted := 0
	for node in view.level_roots[0].get_children():
		if node is MultiMeshInstance3D and String(node.name).begins_with("Trees_"):
			planted += (node as MultiMeshInstance3D).multimesh.instance_count
	var expected := 0
	for c: Vector2i in data["trees"]:
		if not view.modelled_prop_cells.has(c):
			expected += 1
	assert_gt(expected, 100)
	assert_eq(planted, expected, "every tree cell a model")
	assert_eq(data["grid"].solid, solids, "the cells and their solids stay as they are")


func test_with_models_off_the_trees_are_boxes_again() -> void:
	ProjectSettings.set_setting(PropModels.MODE_SETTING, false)
	var view: Node3D = autofree(MapView.new())
	view.setup(FieldMaps.build_from(load(FieldMaps.path_of("bare_line_01"))))
	for node in view.level_roots[0].get_children():
		assert_false(String(node.name).begins_with("Trees_"), "no tree models")


func test_forced_spruce_keeps_the_cell_seed_and_uses_its_own_size() -> void:
	for i: int in 8:
		var c := Vector2i(10 + i, 12)
		var mixed := MapView.tree_plant("houses_01", c)
		var spruce := MapView.tree_plant("houses_01", c, MapView.TREE_SPRUCE)
		assert_eq(spruce, MapView.tree_plant("houses_01", c, MapView.TREE_SPRUCE))
		assert_eq(spruce["model"], MapView.TREE_SPRUCE)
		assert_eq(spruce["at"], mixed["at"], "the same seed draws still place the tree within its cell")
		assert_eq(spruce["yaw"], mixed["yaw"])
		var size: Array = MapView.TREE_SIZE[MapView.TREE_SPRUCE]
		assert_between(float(spruce["height"]), float(size[0]), float(size[1]))
		assert_eq(float(spruce["spread"]), float(size[2]))


func test_deep_forest_tree_cells_build_always_visible_spruce_in_a_town() -> void:
	var view: Node3D = autofree(MapView.new())
	var ground := Node3D.new()
	view.add_child(ground)
	view.level_roots[0] = ground
	view.data = {"place_id": "houses_01", "deep_forest": [Rect2i(10, 10, 8, 4)]}
	var cells: Array = []
	for y: int in range(10, 14):
		for x: int in range(10, 18):
			cells.append(Vector2i(x, y))
	assert_eq(view._build_tree_models(cells), [], "every forest cell gets its spruce model")
	var planted: int = 0
	for node in ground.get_children():
		assert_true(node is MultiMeshInstance3D)
		assert_true(String(node.name).begins_with("Trees_spruce_"), "forest overrides the town's TREE_MIX")
		if node is MultiMeshInstance3D:
			assert_true((node as MultiMeshInstance3D).visible, "these models do not wait for prop discovery")
			planted += (node as MultiMeshInstance3D).multimesh.instance_count
	assert_eq(planted, cells.size())
	for c: Vector2i in cells:
		assert_false(view.modelled_prop_cells.has(c), "forest rows never enter the prop exclusion set")
