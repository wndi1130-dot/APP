extends "res://addons/gut/test.gd"

const Models = preload("res://game/world/ground_models.gd")
const MapView = preload("res://game/world/map_view.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")

var _old_cache: Dictionary = {}


func before_each() -> void:
	_old_cache = Models.cache_snapshot()
	Models.restore_cache({})


func after_each() -> void:
	Models.restore_cache(_old_cache)


## A one-triangle template as baked (vertex alpha 0, on the floor, round its
## footprint's middle), or with its alpha, height or sideways place changed.
func _triangle(alpha: float = 0.0, lift: float = 0.0, shift: float = 0.0) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.4 + shift, lift, -0.2), Vector3(0.4 + shift, lift, -0.2), Vector3(shift, 0.1 + lift, 0.2)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD])
	var colour := Color(0.5, 0.4, 0.3, alpha)
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([colour, colour, colour])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func test_templates_and_misses_are_cached_and_can_be_restored() -> void:
	assert_true(Models.cache_template("knife", _triangle()))
	var first: Dictionary = Models.template("knife")
	assert_eq(first, Models.template("knife"))
	assert_eq(first["size"], Vector3(0.8, 0.1, 0.4))
	assert_eq((first["flat_vertices"] as PackedVector3Array).size(), 3, "spelled out once, three per triangle")
	assert_eq((first["flat_normals"] as PackedVector3Array).size(), 3)
	assert_eq((first["flat_colors"] as PackedColorArray).size(), 3)
	assert_eq(Models.template("no_such_ground_template_550"), {})
	assert_eq(Models.template("no_such_ground_template_550"), {})
	assert_true(Models.cache_snapshot().has("no_such_ground_template_550"), "missing resources are negative cached")
	assert_false(Models.cache_template("empty", ArrayMesh.new()))
	assert_eq(Models.template("empty"), {})
	assert_eq(Models.template("../escape"), {})


## A template not as baked is a cached miss and its thing keeps a box: a vertex
## alpha above 0 (world_vis.gdshader would lay snow and rain over it), lying
## above its floor or off its footprint's middle (it would float or stand off
## its spot and its rim).
func test_a_template_not_as_baked_is_a_miss_and_keeps_a_box() -> void:
	assert_true(Models.cache_template("as_baked", _triangle()), "the fixture itself passes")
	for bad: Array in [["coloured_alpha", _triangle(1.0)], ["lifted", _triangle(0.0, 0.05)], ["off_middle", _triangle(0.0, 0.0, 0.1)]]:
		assert_false(Models.cache_template(bad[0], bad[1]), bad[0])
		assert_eq(Models.template(bad[0]), {}, "%s is a cached miss" % bad[0])
		assert_eq(Models.resolve(bad[0]), "", "%s is drawn as a box" % bad[0])


func test_candidate_priority_is_shared_with_the_pane() -> void:
	for candidate: String in ["note_side", "note_map", "herbal_book", "book"]:
		assert_true(Models.cache_template(candidate, _triangle()))
	assert_eq(Models.resolve("note_side", "book"), "note_side")
	Models.restore_cache({"note_side": {}})
	assert_true(Models.cache_template("note_map", _triangle()))
	assert_true(Models.cache_template("herbal_book", _triangle()))
	assert_eq(Models.resolve("note_side", "book"), "note_map")


func test_boxes_and_templates_share_one_unindexed_surface() -> void:
	assert_true(Models.cache_template("knife", _triangle()))
	var batch: Models.Batch = Models.begin()
	Models.append_box(batch, Vector3.ONE, Vector3.ZERO, Color(0.2, 0.2, 0.2, 0), 0.3)
	Models.append_template(batch, Models.template("knife"), Vector3(2, 0, 0), PI * 0.5)
	Models.append_box(batch, Vector3.ONE, Vector3(4, 0, 0), Color(0.2, 0.2, 0.2, 0), 0.7)
	Models.append_template(batch, Models.template("knife"), Vector3(6, 0, 0), 0.0)
	var mesh: ArrayMesh = Models.commit(batch)
	assert_eq(mesh.get_surface_count(), 1)
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(vertices.size(), (12 * 2 + 2) * 3)
	var indices: Variant = arrays[Mesh.ARRAY_INDEX]
	assert_true(indices == null or (indices as PackedInt32Array).is_empty(), "no indexed/unindexed mixing")
	assert_almost_eq(vertices[36].distance_to(Vector3(2, 0, 0) + Basis(Vector3.UP, PI * 0.5) * Vector3(-0.4, 0, -0.2)), 0.0, 0.00001)
	var template: Dictionary = Models.template("knife")
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var source_normal: Vector3 = (template["flat_normals"] as PackedVector3Array)[0]
	assert_almost_eq(normals[36].distance_to(Basis(Vector3.UP, PI * 0.5) * source_normal), 0.0, 0.02, "the turn turns the normals too")
	assert_almost_eq(normals[75].distance_to(source_normal), 0.0, 0.02)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var expected_color: Color = (template["flat_colors"] as PackedColorArray)[0]
	for at: int in [36, 75]:
		assert_almost_eq(colors[at].r, expected_color.r, 1.5 / 255.0, "the stored sRGB vertex colour")
		assert_almost_eq(colors[at].g, expected_color.g, 1.5 / 255.0)
		assert_almost_eq(colors[at].b, expected_color.b, 1.5 / 255.0)
	assert_almost_eq(colors[0].r, 0.2, 1.5 / 255.0, "the adjacent box keeps its colour")
	for color: Color in arrays[Mesh.ARRAY_COLOR]:
		assert_eq(color.a, 0.0)


func test_a_box_stands_on_its_spot_at_its_size_and_turn() -> void:
	var batch: Models.Batch = Models.begin()
	Models.append_box(batch, Vector3(2, 1, 4), Vector3(1, 3, 1), Color(0.3, 0.2, 0.1, 0), 0.0)
	assert_eq(batch.vertices.size(), 36, "six faces, two triangles each")
	var low: Vector3 = batch.vertices[0]
	var high: Vector3 = low
	for vertex: Vector3 in batch.vertices:
		low = low.min(vertex)
		high = high.max(vertex)
	assert_almost_eq(low.distance_to(Vector3(0, 3, -1)), 0.0, 0.00001, "footprint centred on the spot, on its floor")
	assert_almost_eq(high.distance_to(Vector3(2, 4, 3)), 0.0, 0.00001)
	for index: int in batch.normals.size():
		assert_almost_eq(batch.normals[index].length(), 1.0, 0.00001, "scale never stretches a normal")
	var turned: Models.Batch = Models.begin()
	Models.append_box(turned, Vector3(2, 1, 4), Vector3.ZERO, Color.BLACK, PI * 0.5)
	var far: float = 0.0
	for vertex: Vector3 in turned.vertices:
		far = maxf(far, absf(vertex.x))
	assert_almost_eq(far, 2.0, 0.00001, "a quarter turn lays the long side along x")
	# Each face's triangles wind the way its normal points (front faces clockwise).
	for offset: int in range(0, batch.vertices.size(), 3):
		var face: Vector3 = (batch.vertices[offset + 2] - batch.vertices[offset]).cross(batch.vertices[offset + 1] - batch.vertices[offset])
		assert_gt(face.dot(batch.normals[offset]), 0.0, "triangle %d faces out" % floori(offset / 3.0))
	assert_null(Models.commit(Models.begin()), "nothing gathered, no mesh")


func test_each_floor_has_one_mesh_and_one_rim_and_unchanged_list_keeps_them() -> void:
	assert_true(Models.cache_template("knife", _triangle()))
	Models.cache_template("no_ground_art_550", null)
	var view := MapView.new()
	add_child_autofree(view)
	view.grid = FieldGrid.new(16, 16)
	for level: int in [0, 1]:
		var floor_root := Node3D.new()
		view.add_child(floor_root)
		view.level_roots[level] = floor_root
	var items: Array = [
		{"id": "knife", "n": 1, "pos": Vector3(2.5, 0, 2.5)},
		{"id": "no_ground_art_550", "n": 1, "pos": Vector3(5.5, 0, 5.5)},
		{"id": "knife", "n": 1, "pos": Vector3(2.5, 3, 2.5)},
	]
	view.update_ground(items)
	assert_eq(view.ground_nodes.size(), 2)
	for level: int in [0, 1]:
		var node: MeshInstance3D = view.ground_nodes[level]
		assert_eq((view.level_roots[level] as Node3D).get_child_count(), 1)
		assert_eq(node.get_child_count(), 1)
		assert_eq(node.mesh.get_surface_count(), 1)
		assert_not_null((node.get_node("Rim") as MeshInstance3D).mesh)
	var mesh_before: Mesh = view.ground_nodes[0].mesh
	var rim_before: Mesh = (view.ground_nodes[0].get_node("Rim") as MeshInstance3D).mesh
	assert_eq(mesh_before.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(), (12 + 1) * 3)
	view.update_ground(items.duplicate(true))
	assert_eq(view.ground_nodes[0].mesh, mesh_before)
	assert_eq((view.ground_nodes[0].get_node("Rim") as MeshInstance3D).mesh, rim_before)
	view.update_ground([])
	assert_null(view.ground_nodes[0].mesh)
	assert_null((view.ground_nodes[1].get_node("Rim") as MeshInstance3D).mesh)
