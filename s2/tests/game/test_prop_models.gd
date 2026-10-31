extends "res://addons/gut/test.gd"

const Props = preload("res://game/world/prop_models.gd")
const FieldMap = preload("res://game/world/sulehuf_map.gd")
const MapView = preload("res://game/world/map_view.gd")


func after_each() -> void:
	ProjectSettings.set_setting(Props.MODE_SETTING, true)


func test_every_listed_model_file_loads() -> void:
	for id: String in Props.BY_ID:
		assert_false(Props.rows(Props.BY_ID[id]).is_empty(), id)


func test_every_listed_container_is_on_the_first_stop() -> void:
	var containers: Dictionary = FieldMap.build()["containers"]
	for id: String in Props.BY_ID:
		assert_true(containers.has(id), id)


func test_first_stop_draws_furniture_and_keeps_the_rest_as_boxes() -> void:
	var view: Node3D = autofree(MapView.new())
	view.setup(FieldMap.build())
	for id: String in view.data["containers"]:
		assert_true(view.has_container(id), id)
		assert_not_null(view.container_mesh(id), id)
		assert_eq(view.container_nodes.has(id), Props.BY_ID.has(id), id)
		if view.container_nodes.has(id):
			assert_true((view.container_nodes[id] as Node3D).has_node("Prop"), id)
	assert_false(view.container_nodes.has("bell"), "the bell keeps its own shape in the chunk")


func test_searching_keeps_the_model_and_changes_the_mat() -> void:
	var data := FieldMap.build()
	var view: Node3D = autofree(MapView.new())
	view.setup(data)
	var before: Mesh = view.container_mesh("office_desk")
	data["containers"]["office_desk"]["searched"] = true
	view.update_container("office_desk")
	assert_true(view.container_nodes["office_desk"].has_node("Prop"))
	assert_ne(view.container_mesh("office_desk"), before)


func test_switch_off_keeps_every_box() -> void:
	ProjectSettings.set_setting(Props.MODE_SETTING, false)
	var view: Node3D = autofree(MapView.new())
	view.setup(FieldMap.build())
	assert_true(view.container_nodes.is_empty(), "no model parents when models are off")
	for id: String in view.data["containers"]:
		assert_true(view.has_container(id), id)
		assert_not_null(view.container_mesh(id), id)


func test_vertex_coloured_models_turn_the_shader_colour_on() -> void:
	var painted := _collected_material(_triangle(true))
	var plain := _collected_material(_triangle(false))
	assert_true(painted.get_shader_parameter("use_vertex_color"), "a coloured model uses its colours")
	assert_ne(plain.get_shader_parameter("use_vertex_color"), true, "a plain model keeps the default")


func test_every_model_darkens_at_the_foot_it_stands_on() -> void:
	# T0-6: the foot of a model on its floor goes darker (weathered.gdshader contact_dark), so a pale
	# box does not float over the floor; the shader leaves it off for anything else.
	for coloured: bool in [true, false]:
		var m := _collected_material(_triangle(coloured))
		assert_almost_eq(float(m.get_shader_parameter("contact_dark")), Props.CONTACT_DARK, 0.0001)
	assert_gt(Props.CONTACT_DARK, 0.2)
	assert_lt(Props.CONTACT_DARK, 0.5, "darker, never black")


func test_tops_are_where_the_baked_furniture_is_flat() -> void:
	# Under every point of a top's rect the highest face of the model is that top: nothing stands above it
	# (a splashback, a flue) and it is not a hole. A rebake that moves a top fails here.
	for path: String in Props.TOPS:
		var meshes: Dictionary = Props.batch_meshes(path)
		assert_true(meshes.has(0), path + " loads")
		if not meshes.has(0):
			continue
		var tris := _triangles(meshes[0])
		for top: Dictionary in Props.tops(path):
			var rect: Rect2 = top["rect"]
			var y: float = top["y"]
			for i in 5:
				for j in 5:
					var p := Vector2(rect.position.x + 0.01 + (rect.size.x - 0.02) * i / 4.0,
						rect.position.y + 0.01 + (rect.size.y - 0.02) * j / 4.0)
					var h := _highest(tris, p)
					assert_between(h, y - 0.015, y + 0.005, "%s top %.2f at %s: %.3f" % [path.get_file(), y, p, h])


func test_tops_are_only_the_furniture_things_go_on() -> void:
	assert_true(Props.tops("res://models/props_stop01/tiled_stove.glb").is_empty(), "a fallback model has no top")
	for path: String in Props.TOPS:
		assert_false(Props.tops(path).is_empty(), path)


func test_tabletop_things_keep_their_colour_and_take_no_rime() -> void:
	for kind: String in Props.TABLETOP_KINDS:
		var path := Props.LIVELY_DIR + kind + ".glb"
		var rows: Array = Props.rows_path(path)
		assert_false(rows.is_empty(), kind + " loads")
		for row: Dictionary in rows:
			var m := row["material"] as ShaderMaterial
			assert_eq(float(m.get_shader_parameter("rime_catch")), 0.0, kind + ": indoors, no rime")
			assert_ne(m.get_shader_parameter("lively"), 1.0, kind + ": its own colours")


## The triangles of `mesh` as [a, b, c] points, every surface.
func _triangles(mesh: Mesh) -> Array:
	var out := []
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx = arrays[Mesh.ARRAY_INDEX]
		var order: Array = Array(idx) if idx != null and not (idx as PackedInt32Array).is_empty() else range(v.size())
		for k in range(0, order.size() - 2, 3):
			out.append([v[order[k]], v[order[k + 1]], v[order[k + 2]]])
	return out


## The highest face of `tris` over the ground point `p` (x, z); -1 where there is none.
func _highest(tris: Array, p: Vector2) -> float:
	var best := -1.0
	for t: Array in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		var d := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		if absf(d) < 1e-9:
			continue
		var w1 := ((b.z - c.z) * (p.x - c.x) + (c.x - b.x) * (p.y - c.z)) / d
		var w2 := ((c.z - a.z) * (p.x - c.x) + (a.x - c.x) * (p.y - c.z)) / d
		var w3 := 1.0 - w1 - w2
		if w1 < -1e-6 or w2 < -1e-6 or w3 < -1e-6:
			continue
		best = maxf(best, w1 * a.y + w2 * b.y + w3 * c.y)
	return best


func _triangle(coloured: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point: Vector3 in [Vector3.ZERO, Vector3.RIGHT, Vector3.UP]:
		if coloured:
			st.set_color(Color(0.6, 0.3, 0.1))
		st.add_vertex(point)
	return st.commit()


func _collected_material(mesh: Mesh) -> ShaderMaterial:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var found := []
	Props._collect(node, Transform3D.IDENTITY, found)
	node.free()
	return found[0]["material"]
