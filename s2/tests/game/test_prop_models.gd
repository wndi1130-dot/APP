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
