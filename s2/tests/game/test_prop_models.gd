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
	for id: String in view.container_nodes:
		var node: Node3D = view.container_nodes[id]
		assert_eq(node.has_node("Prop"), Props.BY_ID.has(id), id)
	assert_false(view.container_nodes["bell"].has_node("Prop"), "the bell keeps its own shape")


func test_searching_keeps_the_model_and_changes_the_mat() -> void:
	var data := FieldMap.build()
	var view: Node3D = autofree(MapView.new())
	view.setup(data)
	var before: Mesh = view.container_nodes["office_desk"].mesh
	data["containers"]["office_desk"]["searched"] = true
	view.update_container("office_desk")
	assert_true(view.container_nodes["office_desk"].has_node("Prop"))
	assert_ne(view.container_nodes["office_desk"].mesh, before)


func test_switch_off_keeps_every_box() -> void:
	ProjectSettings.set_setting(Props.MODE_SETTING, false)
	var view: Node3D = autofree(MapView.new())
	view.setup(FieldMap.build())
	for id: String in view.container_nodes:
		assert_false(view.container_nodes[id].has_node("Prop"), id)


func test_vertex_coloured_models_turn_the_shader_colour_on() -> void:
	var painted := _collected_material(_triangle(true))
	var plain := _collected_material(_triangle(false))
	assert_true(painted.get_shader_parameter("use_vertex_color"), "a coloured model uses its colours")
	assert_ne(plain.get_shader_parameter("use_vertex_color"), true, "a plain model keeps the default")


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
