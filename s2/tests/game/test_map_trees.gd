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
