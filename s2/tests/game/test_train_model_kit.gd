extends "res://addons/gut/test.gd"

const Kit = preload("res://game/world/train_model_kit.gd")
const FieldMap = preload("res://game/world/sulehuf_map.gd")
const MapView = preload("res://game/world/map_view.gd")
var _previous_setting: bool


func before_all() -> void:
	_previous_setting = Kit.models_enabled()


func before_each() -> void:
	ProjectSettings.set_setting(Kit.MODE_SETTING, true)


func after_each() -> void:
	ProjectSettings.set_setting(Kit.MODE_SETTING, _previous_setting)


func _triangles(mesh: Mesh) -> int:
	var count := 0
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		count += (indices.size() if not indices.is_empty() else vertices.size()) / 3
	return count


func test_all_ready_files_exist_and_held_assets_have_no_public_file() -> void:
	for id: String in Kit.catalog()["assets"]:
		var asset: Dictionary = Kit.catalog()["assets"][id]
		if asset["status"] == "ready":
			assert_true(ResourceLoader.exists(asset["path"]), id)
		else:
			assert_eq(asset["path"], "", id)
			assert_false(FileAccess.file_exists("res://models/train_%s/%s.glb" % [asset["category"], id]), id)
	for kind: String in Kit.catalog()["kinds"]:
		for id: String in Kit.model_plan(kind):
			assert_true(ResourceLoader.exists(Kit.catalog()["assets"][id]["path"]), kind)


func test_imported_geometry_texture_materials_and_bytes_meet_measured_budgets() -> void:
	var total_bytes := 0
	for id: String in Kit.catalog()["assets"]:
		var asset: Dictionary = Kit.catalog()["assets"][id]
		if asset["status"] != "ready":
			continue
		var file := FileAccess.open(asset["path"], FileAccess.READ)
		var bytes := file.get_length()
		total_bytes += bytes
		assert_eq(bytes, int(asset["bytes"]), id)
		assert_lte(bytes, mini(2000000, int(asset["byte_limit"])), id)
		assert_eq(FileAccess.get_sha256(asset["path"]), asset["sha256"], id)
		var library := Kit.asset_meshes(id)
		for lod in 2:
			var triangles := 0
			var surfaces := 0
			for row in library[lod]:
				triangles += _triangles(row["mesh"])
				surfaces += row["mesh"].get_surface_count()
				var material: ShaderMaterial = row["material"]
				assert_eq(material.shader.resource_path, "res://fx/shaders/weathered.gdshader", id)
				var texture := material.get_shader_parameter("albedo_tex") as Texture2D
				assert_not_null(texture, id)
				if texture != null:
					assert_true(texture.get_image().has_mipmaps(), id)
					assert_true(texture.resource_path.contains(".glb::"), id)
					assert_lte(texture.get_width(), int(asset["texture_limit"]), id)
					assert_lte(texture.get_height(), int(asset["texture_limit"]), id)
			var expected := int(asset["lod0_tris"] if lod == 0 or int(asset["lod1_tris"]) == 0 else asset["lod1_tris"])
			assert_eq(triangles, expected, "%s LOD%d" % [id, lod])
			assert_lte(surfaces, 2 if asset["category"] == "exterior" else 1, id)
			assert_lte(triangles, int(asset["triangle_limit"]), id)
		if asset["category"] == "exterior":
			assert_lte(int(asset["lod1_tris"]) * 2, int(asset["lod0_tris"]), id)
	assert_lte(total_bytes, 19400000)


func test_unknown_held_and_missing_models_fall_back() -> void:
	assert_false(Kit.can_replace("unknown"))
	assert_false(Kit.can_replace("car"))
	assert_false(Kit.can_replace("captain"))
	var book := Kit.catalog().duplicate(true)
	book["assets"]["coach_medic"]["path"] = "res://models/train_exterior/missing.glb"
	assert_true(Kit.model_plan("medtech", book).is_empty())
	book["assets"]["tender"]["path"] = "res://models/train_exterior/missing.glb"
	assert_true(Kit.model_plan("engine", book).is_empty(), "engine pair is atomic")


func test_switch_rebuilds_the_original_six_open_graybox_cars() -> void:
	ProjectSettings.set_setting(Kit.MODE_SETTING, false)
	var parent: Node3D = autofree(Node3D.new())
	var root := Kit.create_stage(parent)
	assert_eq(root.get_child_count(), 30)
	assert_eq(root.get_meta("fallback_count"), 6)
	for child in root.get_children():
		assert_true(child is MeshInstance3D)
		assert_true(child.mesh is BoxMesh)
	assert_false(Kit.can_replace("engine"))


func test_model_stage_contains_models_and_exact_fallback_slots() -> void:
	var parent: Node3D = autofree(Node3D.new())
	var root := Kit.create_stage(parent)
	assert_eq(root.get_meta("model_count"), 2)
	assert_eq(root.get_meta("fallback_count"), 3)
	assert_gt(root.find_children("*", "MultiMeshInstance3D", true, false).size(), 0)
	assert_eq(root.find_children("*", "MeshInstance3D", true, false).size(), 15)


func test_station_and_home_call_the_same_kit() -> void:
	for scene_path: String in ["res://scenes/station.tscn", "res://scenes/home.tscn"]:
		var scene := load(scene_path) as PackedScene
		var instance := scene.instantiate()
		add_child_autofree(instance)
		var root := instance.get_node_or_null("TrainModels")
		assert_not_null(root, scene_path)
		if root != null:
			assert_eq(root.get_meta("model_count"), 2, scene_path)


func test_stage_engine_tender_and_coach_share_one_uniform_scale() -> void:
	var parent: Node3D = autofree(Node3D.new())
	var root := Kit.create_stage(parent)
	var scales: Array[Vector3] = []
	# Dummy rendering returns identity from MultiMesh readback. Check the
	# actual instance matrices supplied to the renderer by the batch builder.
	for key: String in root._batches:
		var row: Dictionary = root._batches[key]
		if row["lod"] == 0 and not key.begins_with("coach_flue"):
			scales.append((row["transforms"][0] as Transform3D).basis.get_scale())
	assert_eq(scales.size(), 3, "coach plus tender and locomotive")
	for scale in scales:
		assert_almost_eq(scale.x, 4.5 / 16.0, 0.00001)
		assert_almost_eq(scale.y, scale.x, 0.00001)
		assert_almost_eq(scale.z, scale.x, 0.00001)


func test_people_kinds_only_use_coach_bodies() -> void:
	for kind: String in Kit.catalog()["kinds"]:
		var entry: Dictionary = Kit.catalog()["kinds"][kind]
		if entry["people"]:
			for id: String in entry["assets"]:
				assert_true(id.begins_with("coach_"), kind)
	assert_false(Kit.catalog()["kinds"]["freight"]["people"])
	assert_false(Kit.catalog()["kinds"]["store"]["people"])


func test_flue_rules_exclude_freight_and_cold_even_with_clear_site() -> void:
	var site: Dictionary = Kit.catalog()["assets"]["coach_medic"]["attachment_sites"]["roof_clear"].duplicate(true)
	for kind: String in ["freight", "store", "cold", "tender"]:
		assert_false(Kit.part_allowed(kind, "coach_flue", site), kind)
	assert_false("freight" in Kit.catalog()["part_rules"]["coach_flue"]["kinds"])
	assert_false("cold" in Kit.catalog()["part_rules"]["coach_flue"]["kinds"])


func test_default_parts_fit_the_whole_car_budget_and_verified_site() -> void:
	for kind: String in Kit.catalog()["kinds"]:
		var entry: Dictionary = Kit.catalog()["kinds"][kind]
		if entry["parts"].is_empty():
			continue
		var body: Dictionary = Kit.catalog()["assets"][entry["assets"][0]]
		var used := int(body["lod0_tris"])
		for request in entry["parts"]:
			var site: Dictionary = body["attachment_sites"][request["site"]]
			assert_true(Kit.part_allowed(kind, request["asset"], site, used), kind)
			used += int(Kit.catalog()["assets"][request["asset"]]["lod0_tris"])
		assert_lte(used, int(body["triangle_limit"]), kind)


func test_parts_reject_blockage_duplicates_missing_proof_and_budget_overflow() -> void:
	var site: Dictionary = Kit.catalog()["assets"]["coach_medic"]["attachment_sites"]["roof_clear"].duplicate(true)
	assert_true(Kit.part_allowed("medtech", "coach_flue", site))
	for flag: String in ["blocks_window", "blocks_passage", "duplicate"]:
		var blocked := site.duplicate(true)
		blocked[flag] = true
		assert_false(Kit.part_allowed("medtech", "coach_flue", blocked), flag)
	assert_false(Kit.part_allowed("medtech", "coach_flue", {}))
	assert_false(Kit.part_allowed("medtech", "coach_flue", site, 7999))
	var too_small := site.duplicate(true)
	too_small["clearance_m"] = [0.01, 0.01, 0.01]
	assert_false(Kit.part_allowed("medtech", "coach_flue", too_small))
	assert_false(Kit.part_allowed("medtech", "steel_patches", site))


func test_step_and_patches_require_door_and_window_clearance() -> void:
	for id: String in ["plank_band", "plank_patches"]:
		var rule: Dictionary = Kit.catalog()["part_rules"][id]
		assert_eq(rule["site"], "lower_wall")
		assert_has(rule["requires"], "below_windows")
		assert_has(rule["forbids"], "blocks_passage")
	var step: Dictionary = Kit.catalog()["part_rules"]["side_step"]
	for flag: String in ["door_swing_clear", "boarding_clear", "step_missing"]:
		assert_has(step["requires"], flag)
	assert_has(Kit.catalog()["part_rules"]["coach_window_frame"]["requires"], "frame_missing")


func test_home_cutaway_removes_only_front_upper_middle_triangles() -> void:
	for lod in 2:
		var row: Dictionary = Kit.asset_meshes("coach_medic")[lod][0]
		var sliced := Kit.cutaway_mesh("coach_medic", lod, row)
		assert_gt(_triangles(sliced), 0)
		assert_lt(_triangles(sliced), _triangles(row["mesh"]))
		var original_bounds: AABB = row["transform"] * row["mesh"].get_aabb()
		assert_almost_eq(sliced.get_aabb().position.y, original_bounds.position.y, 0.01)
		var forbidden_triangle := false
		for surface in sliced.get_surface_count():
			var vertices: PackedVector3Array = sliced.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = sliced.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
			for i in range(0, indices.size(), 3):
				var center := (vertices[indices[i]] + vertices[indices[i + 1]] + vertices[indices[i + 2]]) / 3.0
				forbidden_triangle = forbidden_triangle or (center.z > 0 and center.y > 5.140098 * 0.28 and absf(center.x) < 16.0 * 0.45)
		assert_false(forbidden_triangle)


func test_repeated_models_are_batched_and_far_lod_has_no_shadow() -> void:
	var parent: Node3D = autofree(Node3D.new())
	var data := {"train": Rect2i(0, 0, 32, 3), "train_cars": [{"rect": Rect2i(0, 0, 16, 3), "kind": "medtech"}, {"rect": Rect2i(16, 0, 16, 3), "kind": "medtech"}]}
	var root := Kit.attach_field(parent, data)
	assert_eq(root.get_meta("model_count"), 2)
	assert_eq(root.get_child_count(), 4, "body and flue, two LODs, one 32m batch")
	for node in root.get_children():
		assert_eq(node.multimesh.instance_count, 2)
		if node.visibility_range_begin > 0:
			assert_eq(node.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			assert_eq(node.visibility_range_end, 120.0)


func test_field_uses_models_only_for_ready_kinds_and_rolls_with_train_parent() -> void:
	var parent: Node3D = autofree(Node3D.new())
	var data := FieldMap.build()
	var root := Kit.attach_field(parent, data)
	assert_eq(root.get_parent(), parent)
	assert_eq(root.get_meta("model_count"), 1, "generic passenger body is held; engine pair replaces one slot")
	parent.position.x = 17.0
	assert_eq(root.position.x, 0.0, "model root inherits the rolling parent's transform")
	ProjectSettings.set_setting(Kit.MODE_SETTING, false)
	var boxes := Kit.attach_field(parent, data)
	assert_eq(boxes.get_child_count(), 0)
	assert_false(Kit.can_replace("engine"))
