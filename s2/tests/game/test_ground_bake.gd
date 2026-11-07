extends "res://addons/gut/test.gd"
## Authored before the implementation. Engine execution belongs to the lead.

const Bake = preload("res://tools/ground_bake.gd")
## ARRAY_COLOR is stored as RGBA8, truncating channels; source and baked mesh
## readback can straddle an 8-bit step. Allow at most 1.5 steps, not a float epsilon.
const COLOR_EPSILON: float = 1.5 / 255.0


func test_primitives_are_copied_and_only_reduced() -> void:
	var cylinder := CylinderMesh.new()
	cylinder.radial_segments = 32
	cylinder.rings = 6
	var low_cylinder: CylinderMesh = Bake.low_poly(cylinder) as CylinderMesh
	assert_ne(low_cylinder, cylinder)
	assert_eq(low_cylinder.radial_segments, 8)
	assert_eq(low_cylinder.rings, 1)
	assert_eq(cylinder.radial_segments, 32)
	var sphere := SphereMesh.new()
	sphere.radial_segments = 32
	sphere.rings = 12
	var low_sphere: SphereMesh = Bake.low_poly(sphere) as SphereMesh
	assert_eq(low_sphere.radial_segments, 8)
	assert_eq(low_sphere.rings, 4)
	var torus := TorusMesh.new()
	torus.rings = 32
	torus.ring_segments = 16
	var low_torus: TorusMesh = Bake.low_poly(torus) as TorusMesh
	assert_eq(low_torus.rings, 8)
	assert_eq(low_torus.ring_segments, 4)
	var capsule := CapsuleMesh.new()
	capsule.radial_segments = 32
	capsule.rings = 8
	var low_capsule: CapsuleMesh = Bake.low_poly(capsule) as CapsuleMesh
	assert_eq(low_capsule.radial_segments, 8)
	assert_eq(low_capsule.rings, 2)
	cylinder.radial_segments = 4
	cylinder.rings = 1
	sphere.radial_segments = 4
	sphere.rings = 2
	torus.rings = 4
	torus.ring_segments = 3
	capsule.radial_segments = 4
	capsule.rings = 1
	assert_eq((Bake.low_poly(cylinder) as CylinderMesh).radial_segments, 4)
	assert_eq((Bake.low_poly(sphere) as SphereMesh).rings, 2)
	assert_eq((Bake.low_poly(sphere) as SphereMesh).radial_segments, 4)
	assert_eq((Bake.low_poly(torus) as TorusMesh).rings, 4)
	assert_eq((Bake.low_poly(torus) as TorusMesh).ring_segments, 3)
	assert_eq((Bake.low_poly(capsule) as CapsuleMesh).rings, 1)
	assert_eq((Bake.low_poly(capsule) as CapsuleMesh).radial_segments, 4)
	var mesh := ArrayMesh.new()
	assert_eq(Bake.low_poly(mesh), mesh, "imported meshes are unchanged")
	var box := BoxMesh.new()
	box.subdivide_width = 6
	assert_eq((Bake.low_poly(box) as BoxMesh).subdivide_width, 0)
	var plane := PlaneMesh.new()
	plane.subdivide_width = 7
	plane.subdivide_depth = 7
	assert_eq((Bake.low_poly(plane) as PlaneMesh).subdivide_depth, 0)
	var prism := PrismMesh.new()
	prism.subdivide_height = 7
	assert_eq((Bake.low_poly(prism) as PrismMesh).subdivide_height, 0)


func test_srgb_texture_and_vertex_colour_are_multiplied_without_linearizing() -> void:
	var paint := Color(0.6, 0.4, 0.2, 0.3)
	assert_eq(Bake.vertex_colour(paint, Color.WHITE, Color.WHITE, false), Color(0.6, 0.4, 0.2, 0.0))
	var result: Color = Bake.vertex_colour(paint, Color(0.5, 0.25, 1.0), Color(0.5, 1.0, 0.5), true)
	assert_almost_eq(result.r, 0.15, 0.00001)
	assert_almost_eq(result.g, 0.1, 0.00001)
	assert_almost_eq(result.b, 0.1, 0.00001)
	assert_eq(result.a, 0.0)
	var image := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color.RED)
	image.set_pixel(1, 0, Color.BLUE)
	assert_eq(Bake.sample_nearest(image, Vector2(0.1, 0.5)), Color.RED)
	assert_eq(Bake.sample_nearest(image, Vector2(0.8, 0.5)), Color.BLUE)
	assert_eq(Bake.sample_nearest(image, Vector2(1.0, 0.5)), Color.BLUE)


func _painted_triangle(material: BaseMaterial3D) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex: Vector3 in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(0, 0.2, 1)]:
		surface.set_color(Color(0.5, 1.0, 0.5, 0.4))
		surface.set_normal(Vector3.UP)
		surface.set_uv(Vector2(0.75, 0.5))
		surface.add_vertex(vertex)
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material
	return instance


func test_actual_material_texture_vertex_flag_and_glass_use_srgb() -> void:
	var image := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 0.5, 0.25, 0.3))
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.6, 0.4, 0.2, 0.3)
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.albedo_texture = ImageTexture.create_from_image(image)
	var source: MeshInstance3D = _painted_triangle(paint)
	for use_vertex: bool in [false, true]:
		paint.vertex_color_use_as_albedo = use_vertex
		var result: Dictionary = Bake.bake_node(source)
		assert_false(result.has("error"))
		if result.has("error"):
			continue
		var arrays: Array = (result["mesh"] as ArrayMesh).surface_get_arrays(0)
		var expected: Color = Bake.vertex_colour(paint.albedo_color, image.get_pixel(1, 0), Color(0.5, 1, 0.5, 0.4), use_vertex)
		var actual: Color = arrays[Mesh.ARRAY_COLOR][0]
		assert_almost_eq(actual.r, expected.r, COLOR_EPSILON)
		assert_almost_eq(actual.g, expected.g, COLOR_EPSILON)
		assert_almost_eq(actual.b, expected.b, COLOR_EPSILON)
		assert_eq(actual.a, 0.0)
	source.free()


func test_transforms_keep_metres_and_reflections_reverse_winding() -> void:
	var source: MeshInstance3D = _painted_triangle(StandardMaterial3D.new())
	source.scale = Vector3(-2, 3, 4)
	source.position = Vector3(6, -8, 10)
	var result: Dictionary = Bake.bake_node(source)
	assert_false(result.has("error"))
	if not result.has("error"):
		assert_almost_eq((result["size"] as Vector3).distance_to(Vector3(4, 0.6, 8)), 0.0, 0.00001)
		var arrays: Array = (result["mesh"] as ArrayMesh).surface_get_arrays(0)
		# Compaction renumbers vertices in first-use order, so the index list itself
		# reads 0, 1, 2 again; what must hold is the face: drawn in index order it
		# faces the way its (mirrored-back) normal does, as the unmirrored one did.
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array([0, 1, 2])
		var face: Vector3 = (vertices[order[2]] - vertices[order[0]]).cross(vertices[order[1]] - vertices[order[0]])
		assert_gt(face.dot(normals[order[0]]), 0.0, "a mirrored part is not drawn inside out")
		assert_gt(normals[order[0]].y, 0.0, "its normal still points up")
	source.scale = Vector3(0.01, 0.01, 0.01)
	assert_false(Bake.bake_node(source).has("error"), "small but invertible metre transforms are valid")
	source.free()


func test_origin_uses_footprint_middle_and_bottom_without_rescaling() -> void:
	var result: Dictionary = Bake.centered(PackedVector3Array([Vector3(2, -2, 4), Vector3(6, 1, 10)]))
	assert_false(result.has("error"))
	assert_eq(result["size"], Vector3(4, 3, 6))
	assert_eq(result["vertices"], PackedVector3Array([Vector3(-2, 0, -3), Vector3(2, 3, 3)]))
	assert_true(Bake.centered(PackedVector3Array()).has("error"))
	assert_true(Bake.centered(PackedVector3Array([Vector3.ZERO, Vector3.ZERO])).has("error"))
	assert_true(Bake.centered(PackedVector3Array([Vector3(INF, 0, 0)])).has("error"))


func test_vertex_limit_and_invalid_sources_fail() -> void:
	assert_eq(Bake.vertex_limit_error(Bake.MAX_VERTICES), "")
	assert_ne(Bake.vertex_limit_error(Bake.MAX_VERTICES + 1), "")
	assert_ne(Bake.vertex_limit_error(0), "")
	assert_true(Bake.bake_source("missing", "res://no_such_ground_source.glb").has("error"))
	assert_true(Bake.bake_node(null).has("error"))
	var empty := Node3D.new()
	assert_true(Bake.bake_node(empty).has("error"))
	empty.free()


func test_hidden_parents_hide_children_even_when_top_level() -> void:
	var source := Node3D.new()
	var visible_part := MeshInstance3D.new()
	visible_part.mesh = BoxMesh.new()
	visible_part.position = Vector3(2, 3, 4)
	source.add_child(visible_part)
	var hidden := Node3D.new()
	hidden.visible = false
	source.add_child(hidden)
	var hidden_part := MeshInstance3D.new()
	hidden_part.mesh = BoxMesh.new()
	hidden_part.top_level = true
	hidden_part.position = Vector3(100, 100, 100)
	hidden.add_child(hidden_part)
	var result: Dictionary = Bake.bake_node(source)
	assert_false(result.has("error"))
	assert_eq(result.get("size"), Vector3.ONE)
	assert_eq(result.get("vertices"), 24)
	source.free()


func test_list_lines_allow_spaces_bom_and_ignore_icon_pose() -> void:
	assert_eq(Bake.parse_line(""), {})
	assert_eq(Bake.parse_line("  # comment"), {})
	var entry: Dictionary = Bake.parse_line("\ufeffknife res://some folder/a.glb 35 28 -30 0.06", 4)
	assert_eq(entry.get("name"), "knife")
	assert_eq(entry.get("path"), "res://some folder/a.glb")
	assert_eq(entry.get("line"), 4)
	assert_false(entry.has("yaw"), "icon framing never rotates or scales a ground model")
	assert_eq(Bake.parse_line("물건 res://소스 폴더/그림.glb").get("name"), "물건")
	for line: String in ["knife", "../escape res://a.glb", "knife user://a.glb", "knife res://a.exe", "knife res://a.glb bad", "knife res://a.glb 1 2 3 4 5"]:
		assert_true(Bake.parse_line(line).has("error"), line)


func test_exit_status_and_records_describe_this_run() -> void:
	var saved := {"name": "knife", "saved": true, "vertices": 24, "triangles": 12, "size": Vector3(1, 2, 3), "dropped": 2, "lod": 1, "reduced": 0.25}
	var skipped := {"name": "food_pack", "skipped": "BOX_ONLY"}
	assert_eq(Bake.exit_code([saved, skipped], []), 0)
	assert_eq(Bake.exit_code([skipped], []), 0)
	assert_eq(Bake.exit_code([], []), 1)
	assert_eq(Bake.exit_code([saved], ["list missing"]), 1)
	assert_eq(Bake.exit_code([{"name": "bad", "error": "empty"}], []), 1)
	assert_eq(Bake.exit_code([{"name": "unreached"}], []), 1)
	assert_eq(Bake.exit_code([{"name": "false_saved", "saved": false}], []), 1)
	var lines: PackedStringArray = Bake.record_lines([saved, skipped, {"name": "bad", "error": "empty"}], [])
	assert_eq(lines[0], "saved knife 24 12 1.000000 3.000000 2.000000 dropped=2 lod=1 reduced=0.250000")
	assert_eq(lines[1], "skipped food_pack BOX_ONLY")
	assert_eq(lines[2], "failed bad empty")


func test_real_clothing_goods_and_imported_mesh_bake_on_cpu() -> void:
	for pair: Array in [["drawers_cotton", "res://tools/item_models_wear.gd"], ["document", "res://tools/item_models.gd"], ["can_beans", "res://models/items/kenney_food/can.glb"], ["axe", "res://models/weapons/axe.glb"]]:
		var result: Dictionary = Bake.bake_source(pair[0], pair[1])
		assert_false(result.has("error"), str(pair) + ": " + str(result.get("error", "")))
		if result.has("error"):
			continue
		assert_lte(int(result["vertices"]), Bake.MAX_VERTICES)
		var mesh: ArrayMesh = result["mesh"]
		assert_eq(mesh.get_surface_count(), 1)
		var arrays: Array = mesh.surface_get_arrays(0)
		var bottom: float = INF
		for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			bottom = minf(bottom, vertex.y)
		assert_almost_eq(bottom, 0.0, 0.00001)
		for color: Color in arrays[Mesh.ARRAY_COLOR]:
			assert_eq(color.a, 0.0)
		assert_gte(int(result["dropped"]), 0)
		assert_gte(int(result["lod"]), 0)
		assert_gte(float(result["reduced"]), 0.0)
		assert_lt(float(result["reduced"]), 1.0)


func test_small_part_threshold_uses_posed_metres_and_keeps_the_boundary() -> void:
	assert_eq(Bake.MIN_PART_EXTENT, 0.02)
	assert_eq(Bake.MAX_VERTICES, 800)
	assert_true(Bake.should_drop_part(Vector3(0.019, 0.01, 0.005)))
	assert_false(Bake.should_drop_part(Vector3(0.02, 0.001, 0.001)))
	assert_false(Bake.should_drop_part(Vector3(0.001, 0.001, 0.03)), "use the longest of all axes")
	var pose := Transform3D(Basis.IDENTITY.scaled(Vector3(3, 3, 3)), Vector3(8, -4, 2))
	var bounds: Dictionary = Bake.transformed_bounds(PackedVector3Array([Vector3.ZERO, Vector3(0.01, 0.01, 0.01)]), pose)
	assert_almost_eq((bounds["size"] as Vector3).distance_to(Vector3(0.03, 0.03, 0.03)), 0.0, 0.00001)
	assert_false(Bake.should_drop_part(bounds["size"]), "scale is applied before the threshold")
	var turned: Dictionary = Bake.transformed_bounds(PackedVector3Array([Vector3.ZERO, Vector3(0.01, 0.01, 0.03)]), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO))
	assert_almost_eq(turned["size"].x, 0.03, 0.00001, "extent follows the posed axes")
	assert_true(Bake.transformed_bounds(PackedVector3Array(), pose).has("error"))


func test_tiny_visible_parts_are_counted_and_all_dropped_is_a_failure() -> void:
	var source := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	source.add_child(body)
	var button := MeshInstance3D.new()
	var tiny := BoxMesh.new()
	tiny.size = Vector3(0.01, 0.01, 0.01)
	button.mesh = tiny
	button.position = Vector3(100, 100, 100)
	source.add_child(button)
	var result: Dictionary = Bake.bake_node(source)
	assert_false(result.has("error"))
	assert_eq(result.get("dropped"), 1)
	assert_eq(result.get("size"), Vector3.ONE, "discarded details do not expand the footprint")
	assert_eq(result.get("vertices"), 24)
	assert_eq(result.get("lod"), 0)
	assert_eq(result.get("reduced"), 0.0)
	body.visible = false
	var empty: Dictionary = Bake.bake_node(source)
	assert_true(empty.has("error"))
	assert_eq(empty.get("dropped"), 1)
	source.free()


func test_lod_selection_picks_the_finest_fitting_stage_independent_of_order() -> void:
	var levels: Array = [
		{"lod": 2, "indices": PackedInt32Array([0, 2, 4])},
		{"lod": 0, "indices": PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])},
		{"lod": 1, "indices": PackedInt32Array([0, 2, 4, 4, 6, 0, 0, 4, 8])},
	]
	var chosen: Dictionary = Bake.select_lod(12, levels, 5)
	assert_false(chosen.has("error"))
	assert_eq(chosen.get("lod"), 1)
	assert_eq(chosen.get("vertices"), 5, "count unique referenced vertices, not indices")
	assert_eq(chosen.get("indices"), levels[2]["indices"])
	assert_eq(Bake.select_lod(12, levels, 12).get("lod"), 0)
	assert_true(Bake.select_lod(12, levels, 2).has("error"), "no fitting stage fails")
	assert_true(Bake.select_lod(12, [], 5).has("error"))
	assert_true(Bake.select_lod(12, [{"lod": 1, "indices": PackedInt32Array([0, 1, 12])}], 5).has("error"))


func test_compaction_preserves_attributes_and_rewrites_every_triangle_index() -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.BACK, Vector3.ONE])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.RIGHT, Vector3.DOWN, Vector3.FORWARD, Vector3.LEFT])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.RED, Color.GREEN, Color.BLUE, Color.WHITE, Color.BLACK])
	var result: Dictionary = Bake.compact_vertices(arrays, PackedInt32Array([4, 1, 3, 4, 3, 1]))
	assert_false(result.has("error"))
	if result.has("error"):
		return
	var packed: Array = result["arrays"]
	assert_eq(result["vertices"], 3)
	assert_eq(result["triangles"], 2)
	assert_eq(packed[Mesh.ARRAY_INDEX], PackedInt32Array([0, 1, 2, 0, 2, 1]))
	for at: int in range(3):
		var original: int = [4, 1, 3][at]
		for attribute: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR]:
			assert_eq(packed[attribute][at], arrays[attribute][original])
	for index: int in packed[Mesh.ARRAY_INDEX]:
		assert_gte(index, 0)
		assert_lt(index, 3)
	assert_eq(arrays[Mesh.ARRAY_VERTEX].size(), 5, "the input arrays stay unchanged")
	assert_true(Bake.compact_vertices(arrays, PackedInt32Array([0, 1, 8])).has("error"))
	assert_true(Bake.compact_vertices(arrays, PackedInt32Array([0, 1])).has("error"))


func test_clustering_merges_a_cell_averages_it_and_drops_collapsed_triangles() -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	# v0 and v1 share a 0.1 m cell; the sliver 0-1-2 collapses, 0-2-3 stays.
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3(0.002, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.DOWN, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color(1, 0, 0, 0), Color(0, 0, 1, 0), Color(0, 1, 0, 0), Color(1, 1, 1, 0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 3, 0, 1, 2])
	var result: Dictionary = Bake.cluster_vertices(arrays, 0.1)
	assert_false(result.has("error"), str(result.get("error", "")))
	if result.has("error"):
		return
	var packed: Array = result["arrays"]
	assert_eq(result["vertices"], 3)
	assert_eq(result["triangles"], 1, "the collapsed sliver is gone")
	assert_almost_eq((packed[Mesh.ARRAY_VERTEX][0] as Vector3).x, 0.001, 0.000001, "the cell's mean position")
	var merged: Color = packed[Mesh.ARRAY_COLOR][0]
	assert_almost_eq(merged.r, 0.5, 0.0001, "the cell's mean colour, as baked (sRGB)")
	assert_almost_eq(merged.b, 0.5, 0.0001)
	assert_eq(merged.a, 0.0, "still under-a-roof alpha")
	assert_eq(packed[Mesh.ARRAY_NORMAL][0], Vector3.UP, "opposite normals that cancel fall back to up, never zero")
	assert_true(Bake.cluster_vertices(arrays, 0.0).has("error"))
	assert_true(Bake.cluster_vertices(arrays, 10.0).has("error"), "one cell for everything leaves no triangle")


func test_clustering_grows_the_cell_until_the_mesh_fits() -> void:
	const SIDE: int = 20
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for z: int in SIDE + 1:
		for x: int in SIDE + 1:
			vertices.append(Vector3(float(x) * 0.01, 0.0, float(z) * 0.01))
			normals.append(Vector3.UP)
			colors.append(Color(0.4, 0.4, 0.4, 0.0))
	for z: int in SIDE:
		for x: int in SIDE:
			var at: int = z * (SIDE + 1) + x
			for index: int in [at, at + SIDE + 1, at + 1, at + 1, at + SIDE + 1, at + SIDE + 2]:
				indices.append(index)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var fitted: Dictionary = Bake.cluster_to_limit(arrays, 60)
	assert_false(fitted.has("error"), str(fitted.get("error", "")))
	if not fitted.has("error"):
		assert_lte(int(fitted["vertices"]), 60, "441 vertices brought within the cap")
		assert_gt(int(fitted["triangles"]), 0)
		assert_gt(float(fitted["cluster"]), 0.0)
	assert_true(Bake.cluster_to_limit(arrays, 2).has("error"), "no grid gets a plane to two vertices")


func test_a_dense_kit_gun_bakes_by_clustering_when_no_lod_fits() -> void:
	# The pistol's kit model is ~4500 vertices with seams the simplifier keeps
	# (11-07: no LOD stage under the cap); clustering brings it in.
	var result: Dictionary = Bake.bake_source("pistol", "res://models/weapons/pistol.glb")
	assert_false(result.has("error"), str(result.get("error", "")))
	if result.has("error"):
		return
	assert_lte(int(result["vertices"]), Bake.MAX_VERTICES)
	assert_eq(int(result["lod"]), Bake.CLUSTERED_LOD)
	assert_gt(float(result["cluster"]), 0.0)
	var arrays: Array = (result["mesh"] as ArrayMesh).surface_get_arrays(0)
	for color: Color in arrays[Mesh.ARRAY_COLOR]:
		assert_eq(color.a, 0.0)
