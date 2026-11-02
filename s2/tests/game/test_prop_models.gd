extends "res://addons/gut/test.gd"

const Props = preload("res://game/world/prop_models.gd")
const FieldMap = preload("res://game/world/sulehuf_map.gd")
const MapView = preload("res://game/world/map_view.gd")
const BootScene = preload("res://scenes/boot.tscn")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const TrainModels = preload("res://game/world/train_model_kit.gd")


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
	# Under every point of a top's rect, its edges too, the highest face of the model is that top, in every
	# LOD the map draws: nothing stands above it (a splashback, a flue) and it is not a hole. A rebake that
	# moves a top fails here.
	for path: String in Props.TOPS:
		var meshes: Dictionary = Props.batch_meshes(path)
		assert_true(meshes.has(0), path + " loads")
		for lod: int in meshes:
			var tris := _triangles(meshes[lod])
			for top: Dictionary in Props.tops(path):
				var rect: Rect2 = top["rect"]
				var y: float = top["y"]
				for i in 7:
					for j in 7:
						var p := Vector2(rect.position.x + 0.001 + (rect.size.x - 0.002) * i / 6.0,
							rect.position.y + 0.001 + (rect.size.y - 0.002) * j / 6.0)
						var h := _highest(tris, p)
						assert_between(h, y - 0.015, y + 0.005, "%s LOD%d top %.2f at %s: %.3f" % [path.get_file(), lod, y, p, h])


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


func test_release_twice_empties_both_caches() -> void:
	Props.batch_meshes(Props.DIR + "office_desk.glb")
	assert_false(Props._rows.is_empty())
	assert_false(Props._batches.is_empty())
	for i in 2:
		Props.release()
		assert_true(Props._rows.is_empty())
		assert_true(Props._batches.is_empty())


func test_release_keeps_attached_multimesh_and_copied_axe_meshes() -> void:
	var parent: Node3D = autofree(Node3D.new())
	assert_true(Props.attach(parent, "office_desk", Vector3.ZERO))
	var nodes: Array = parent.get_node("Prop").get_children()
	assert_false(nodes.is_empty())
	var surfaces: Array[int] = []
	for node: MeshInstance3D in nodes:
		surfaces.append(node.mesh.get_surface_count())
	var multi := MultiMesh.new()
	multi.mesh = Props.batch_meshes(Props.DIR + "office_desk.glb")[0]
	var count := multi.mesh.get_surface_count()
	# The same opt-in copy used by zombies.gd for its embedded axe.
	var axe := MultiMesh.new()
	axe.mesh = Props.with_sight_fade(Props.batch_meshes("res://models/weapons/axe.glb")[0])
	var axe_count := axe.mesh.get_surface_count()
	Props.release()
	assert_true(Props._rows.is_empty())
	assert_true(Props._batches.is_empty())
	for i in nodes.size():
		var node: MeshInstance3D = nodes[i]
		assert_true(is_instance_valid(node.mesh))
		assert_not_null(node.mesh)
		assert_eq(node.mesh.get_surface_count(), surfaces[i])
	assert_true(is_instance_valid(multi.mesh))
	assert_not_null(multi.mesh)
	assert_eq(multi.mesh.get_surface_count(), count)
	assert_true(is_instance_valid(axe.mesh))
	assert_not_null(axe.mesh)
	assert_eq(axe.mesh.get_surface_count(), axe_count)
	assert_eq((axe.mesh.surface_get_material(0) as ShaderMaterial).shader, Props.WeatheredSightFade)


func test_release_reloads_equal_rows_and_batches_at_every_lod() -> void:
	# Fresh loader-stage materials on both sides, before FurnitureTints draws them.
	Props.release()
	for path: String in [Props.DIR + "office_desk.glb", Props.LIVELY_DIR + "chair.glb",
			Props.LIVELY_DIR + "mug.glb", "res://models/weapons/axe.glb"]:
		var rows: Array = Props.rows_path(path)
		var batches: Dictionary = Props.batch_meshes(path)
		assert_false(rows.is_empty(), path)
		assert_false(batches.is_empty(), path)
		Props.release()
		var reloaded: Array = Props.rows_path(path)
		var rebuilt: Dictionary = Props.batch_meshes(path)
		assert_eq(reloaded.size(), rows.size(), path)
		for i in mini(rows.size(), reloaded.size()):
			assert_eq(reloaded[i]["lod"], rows[i]["lod"], path)
			assert_eq(reloaded[i]["transform"], rows[i]["transform"], path)
			assert_eq(_release_mesh_values(reloaded[i]["mesh"]), _release_mesh_values(rows[i]["mesh"]), path)
			assert_eq(_release_material_values(reloaded[i]["material"]), _release_material_values(rows[i]["material"]), path)
		assert_eq(rebuilt.size(), batches.size(), path)
		for lod: int in batches:
			assert_true(rebuilt.has(lod), "%s LOD%d" % [path, lod])
			if not rebuilt.has(lod):
				continue
			assert_eq(_release_mesh_values(rebuilt[lod]), _release_mesh_values(batches[lod]), path)
			var old: Mesh = batches[lod]
			var fresh: Mesh = rebuilt[lod]
			for surface in mini(old.get_surface_count(), fresh.get_surface_count()):
				assert_eq(_release_material_values(fresh.surface_get_material(surface)),
					_release_material_values(old.surface_get_material(surface)), path)


func test_direct_field_restart_leaves_all_three_caches_empty_in_menu() -> void:
	var old_cap := Engine.max_fps
	var had_auto := OS.has_environment("S2_AUTOSTART")
	var old_auto := OS.get_environment("S2_AUTOSTART")
	var boot = BootScene.instantiate()
	var slot := "user://test_menu_cache_release_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	boot.slice_save_path = slot + "_slice.json"
	boot.field_save_path = slot + "_field.json"
	boot.train_save_path = slot + "_train.json"
	for path: String in [boot.slice_save_path, boot.field_save_path, boot.train_save_path]:
		assert_false(FileAccess.file_exists(path))
	OS.set_environment("S2_AUTOSTART", "")
	add_child_autofree(boot)
	if had_auto:
		OS.set_environment("S2_AUTOSTART", old_auto)
	else:
		OS.unset_environment("S2_AUTOSTART")
	assert_not_null(boot.menu)
	# Start before the initial menu's delayed release: it must spare the new field.
	boot._start({"seed": 1, "weather": ["clear"], "raiders": false})
	var previous: Node3D = boot.field
	assert_true(previous.is_built, "the direct field is built synchronously")
	previous.opts["field_save"] = false
	UiFonts.face(UiFonts.NUMBER, 500, 0.5)
	TrainModels.cutaway_mesh("coach_medic", 0, TrainModels.asset_meshes("coach_medic")[0][0])
	for i in 2:
		await get_tree().process_frame
	assert_false(Props._rows.is_empty())
	assert_false(Props._batches.is_empty())
	assert_false(UiFonts._made.is_empty())
	assert_false(UiFonts._files.is_empty())
	assert_false(TrainModels._libraries.is_empty())
	assert_false(TrainModels._cuts.is_empty())
	boot._on_restart()
	assert_true(is_instance_valid(previous), "queue_free has not flushed in this call")
	assert_true(previous.is_queued_for_deletion())
	assert_false(Props._batches.is_empty(), "release is not inline with restart")
	for i in 3:
		await get_tree().process_frame
	assert_false(is_instance_valid(previous), "the old field has been freed")
	assert_null(boot.field)
	assert_true(is_instance_valid(boot.menu))
	# Observe a settled menu across further frames, rather than counting releases.
	for i in 4:
		assert_true(Props._rows.is_empty())
		assert_true(Props._batches.is_empty())
		assert_true(UiFonts._made.is_empty())
		assert_true(UiFonts._files.is_empty())
		assert_true(TrainModels._libraries.is_empty())
		assert_true(TrainModels._cuts.is_empty())
		await get_tree().process_frame
	Engine.max_fps = old_cap


func _release_mesh_values(mesh: Mesh) -> Array:
	var values: Array = []
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		values.append([vertices.size(), 0 if indices == null else indices.size(), vertices, indices])
	return values


func _release_material_values(material: ShaderMaterial) -> Dictionary:
	var values := {"shader": material.shader.code}
	for uniform: Dictionary in material.shader.get_shader_uniform_list():
		var key: String = uniform["name"]
		var value: Variant = material.get_shader_parameter(key)
		if value is Texture2D:
			var image: Image = value.get_image()
			value = [image.get_size(), image.get_format(), image.has_mipmaps(), image.get_data()]
		values[key] = value
	return values


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
