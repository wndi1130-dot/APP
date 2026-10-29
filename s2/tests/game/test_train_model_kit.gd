extends "res://addons/gut/test.gd"

const Kit = preload("res://game/world/train_model_kit.gd")
const FieldMap = preload("res://game/world/sulehuf_map.gd")
const MapView = preload("res://game/world/map_view.gd")
const FieldGame = preload("res://game/field_game.gd")
const FxState = preload("res://fx/fx_state.gd")
## 지금 대응표에서 모델로 바뀌어야 하는 종류. 대응표의 나머지 종류는 모두 상자로 떨어져야 한다.
## 객차 넷이 맑은 유리창으로 다시 들어와(결정 407 G3) 지금은 모든 종류가 모델이다. 상자로 떨어지는 갈래는
## 보류·누락·못 읽는 대응표 시험이 본다.
const MODEL_KINDS := ["car", "tail1", "tail2", "tail3", "cold", "medtech", "dining", "guard", "captain", "front", "workshop",
	"engine_room", "greenhouse", "freight", "store", "tender", "locomotive", "engine",
	"wagon_coal", "wagon_open", "wagon_flat", "wagon_tender", "door_open"]
var _previous_setting: bool


func before_all() -> void:
	_previous_setting = Kit.models_enabled()


func before_each() -> void:
	ProjectSettings.set_setting(Kit.MODE_SETTING, true)


func after_each() -> void:
	ProjectSettings.set_setting(Kit.MODE_SETTING, _previous_setting)
	# 대응표를 바꿔 끼운 시험이 다음 시험에 새지 않게 다음 접근에서 원래 파일을 다시 읽힌다.
	Kit._catalog = {}


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
	var book := Kit.catalog().duplicate(true)
	book["assets"]["coach_worn"]["status"] = "held"
	assert_true(Kit.model_plan("car", book).is_empty(), "held body")
	assert_false(Kit.model_plan("captain", book).is_empty(), "other coach bodies stay")
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
	assert_eq(root.get_meta("model_count"), 5)
	assert_eq(root.get_meta("fallback_count", 0), 0)
	assert_gt(root.find_children("*", "MultiMeshInstance3D", true, false).size(), 0)
	assert_eq(root.find_children("*", "MeshInstance3D", true, false).size(), 0)


func test_station_and_home_call_the_same_kit() -> void:
	for scene_path: String in ["res://scenes/station.tscn", "res://scenes/home.tscn"]:
		var scene := load(scene_path) as PackedScene
		var instance := scene.instantiate()
		add_child_autofree(instance)
		var root := instance.get_node_or_null("TrainModels")
		assert_not_null(root, scene_path)
		if root != null:
			assert_eq(root.get_meta("model_count"), 5, scene_path)


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
	assert_eq(scales.size(), 6, "four coaches plus tender and locomotive")
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
	assert_eq(root.get_child_count(), 6, "body and flue, two LODs, one 32m batch; the window glow, two LODs")
	var panes: int = (Kit.catalog()["assets"]["coach_medic"]["windows"] as Array).size() * 2 * 2
	for node in root.get_children():
		assert_eq(node.multimesh.instance_count, panes if node in root._glow_nodes else 2)
		if node.visibility_range_begin > 0:
			assert_eq(node.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			assert_eq(node.visibility_range_end, 120.0)


func test_coach_windows_glow_on_their_glass_and_only_when_lit() -> void:
	# 낡은 객차(창 여덟), 온실칸(긴 유리 띠 하나), 덮개 화차(창 없음): 창빛은 객차 둘의 유리 자리에만.
	var data := {"train": Rect2i(0, 1, 48, 3), "train_cars": [{"rect": Rect2i(0, 1, 16, 3), "kind": "car"},
		{"rect": Rect2i(16, 1, 16, 3), "kind": "greenhouse"}, {"rect": Rect2i(32, 1, 16, 3), "kind": "freight"}]}
	var root := Kit.attach_field(autofree(Node3D.new()), data)
	var book: Dictionary = Kit.catalog()["assets"]
	var worn: Array = book["coach_worn"]["windows"]
	var k := (16.0 - Kit.FIELD_GAP_M) / float(book["coach_worn"]["dimensions_m"][0])
	assert_eq(root._glow_nodes.size(), 2, "one 32m batch, two LODs")
	for node: MultiMeshInstance3D in root._glow_nodes:
		assert_false(node.visible, "dark until the map says dusk")
		assert_eq(node.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		assert_true(node.multimesh.use_colors)
		assert_eq(node.multimesh.instance_count, (worn.size() + 1) * 2, "every pane on both sides")
	# 머리 없는 시험에서는 MultiMesh가 값을 돌려주지 않아 키트의 배치 목록을 읽는다.
	for lod in 2:
		var row: Dictionary = root._batches["window_glow:%d:0" % lod]
		var levels: Dictionary = {}
		for i in row["transforms"].size():
			var placed: Transform3D = row["transforms"][i]
			var colour: Color = row["colors"][i]
			var level: float = colour.r / FxState.LAMP.r
			if placed.origin.x < 16.0:
				levels[snappedf(level, 0.001)] = true
				assert_between(level, Kit.WINDOW_GLOW_LOW - 0.001, Kit.WINDOW_GLOW_HIGH + 0.001)
			else:
				assert_between(level, Kit.WINDOW_GLOW_LOW * 0.6 - 0.001, Kit.WINDOW_GLOW_HIGH * 0.6 + 0.001, "the greenhouse band is dimmer")
		assert_gt(levels.size(), 3, "windows differ in brightness")
	# 가까운 판은 창 가운데, 유리(벽 안 6 cm)와 커튼·판자(벽 안 5 cm부터) 사이에 창 크기로.
	var first: Transform3D = root._batches["window_glow:0:0"]["transforms"][0]
	var pane: Array = worn[0]
	assert_almost_eq(first.origin.x, 8.0 + (float(pane[0]) + float(pane[1])) * 0.5 * k, 0.001)
	assert_almost_eq(first.origin.y, (float(pane[2]) + float(pane[3])) * 0.5 * k, 0.001)
	assert_between(absf(first.origin.z - 2.5) / k, Kit.DOOR_WALL_Z - 0.06 + 0.001, Kit.DOOR_WALL_Z - 0.05 - 0.001)
	assert_almost_eq(first.basis.x.length(), (float(pane[1]) - float(pane[0])) * k, 0.001)
	root.set_windows_lit(true)
	for node: MultiMeshInstance3D in root._glow_nodes:
		assert_true(node.visible)
	# 지도의 빛 자리: 객차 둘의 옆 줄과 바로 바깥 줄만(지도마다 둘 중 하나에 놓는다).
	assert_true(root.lights_window_at(Vector2i(3, 3)))
	assert_true(root.lights_window_at(Vector2i(3, 4)))
	assert_true(root.lights_window_at(Vector2i(20, 0)))
	assert_false(root.lights_window_at(Vector2i(3, 5)))
	assert_false(root.lights_window_at(Vector2i(35, 4)), "the freight car has no windows")


func test_field_uses_models_only_for_ready_kinds_and_rolls_with_train_parent() -> void:
	var parent: Node3D = autofree(Node3D.new())
	var data := FieldMap.build()
	var root := Kit.attach_field(parent, data)
	assert_eq(root.get_parent(), parent)
	assert_eq(root.get_meta("model_count"), (data["train_cars"] as Array).size(), "passenger cars and the engine pair are all models")
	parent.position.x = 17.0
	assert_eq(root.position.x, 0.0, "model root inherits the rolling parent's transform")
	ProjectSettings.set_setting(Kit.MODE_SETTING, false)
	var boxes := Kit.attach_field(parent, data)
	assert_eq(boxes.get_child_count(), 0)
	assert_false(Kit.can_replace("engine"))


func _one_car(kind: String, slot: Rect2i = Rect2i(0, 0, 16, 3), train: Rect2i = Rect2i(0, 0, 16, 3)) -> Dictionary:
	return {"train": train, "train_cars": [{"rect": slot, "kind": kind}]}


func _model_ends(root: Node3D, kind: String) -> Vector2:
	var ends := Vector2(INF, -INF)
	for id: String in Kit.model_plan(kind):
		for key: String in root._batches:
			if not key.begins_with(id + ":0:"):
				continue
			var row: Dictionary = root._batches[key]
			for placed: Transform3D in row["transforms"]:
				var bounds: AABB = placed * (row["mesh"] as Mesh).get_aabb()
				ends = Vector2(minf(ends.x, bounds.position.x), maxf(ends.y, bounds.end.x))
	return ends


func _write(path: String, text: String) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path


func _stage_roots() -> Array:
	var roots := []
	for scene_path: String in ["res://scenes/station.tscn", "res://scenes/home.tscn"]:
		var instance := (load(scene_path) as PackedScene).instantiate()
		add_child_autofree(instance)
		roots.append(instance.get_node("TrainModels"))
	return roots


func _field_view() -> Dictionary:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "weather": ["clear"]}
	add_child_autofree(game)
	game.set_process(false)
	var train: MeshInstance3D = game.view.train_node
	var cars: Array = game.view.data["train_cars"]
	var engines := 0
	for car in cars:
		engines += 1 if car["kind"] == "engine" else 0
	return {"cars": cars.size(), "engines": engines, "kit": train.get_node("TrainModels"), "doors": int(train.get_node("DoorModels").get_meta("model_count", 0)), "vertices": train.mesh.surface_get_array_len(0) if train.mesh.get_surface_count() > 0 else 0}


func test_field_models_fill_the_logical_slot_length_within_the_gap() -> void:
	for kind: String in ["medtech", "freight", "engine"]:
		for length: int in [12, 16, 20]:
			var slot := Rect2i(4, 0, length, 3)
			var root := Kit.attach_field(autofree(Node3D.new()), _one_car(kind, slot, Rect2i(0, 0, 60, 3)))
			var label := "%s %dm" % [kind, length]
			assert_eq(root.get_meta("model_count", 0), 1, label)
			var ends := _model_ends(root, kind)
			assert_between(ends.x - slot.position.x, 0.0, Kit.FIELD_GAP_M, label + " 앞쪽 끝")
			assert_between(slot.end.x - ends.y, 0.0, Kit.FIELD_GAP_M, label + " 뒤쪽 끝")


## 대각뷰(결정 476)는 칸마다 끝면을 비스듬히 보인다: 16 m 칸에 나란히 선 두 객차의 연결막
## (차체 바닥과 처마 사이·폭 가운데에서 가장 바깥 꼭짓점 — 완충기·연결기는 그 밑, 지붕은 그 위)이
## 0.2 m 안으로 맞닿아, 사이로 끝벽 통로가 보이지 않는다.
func test_neighbour_coaches_meet_at_their_gangways() -> void:
	for id: String in ["coach_worn", "coach_clean", "coach_chief", "coach_medic", "coach_glass"]:
		var reach := 0.0
		for row in Kit.asset_meshes(id)[0]:
			var arrays: Array = (row["mesh"] as Mesh).surface_get_arrays(0)
			for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var at: Vector3 = row["transform"] * v
				if at.y > 1.15 and at.y < 2.5 and absf(at.z) < 0.6:
					reach = maxf(reach, absf(at.x))
		var dims: Array = Kit.catalog()["assets"][id]["dimensions_m"]
		var scale: float = (16.0 - Kit.FIELD_GAP_M) / float(dims[0])
		assert_lt(16.0 - 2.0 * reach * scale, 0.2, id + ": the gangways of two neighbouring coaches meet")


## 옆 선로 화차는 이름·석탄으로 모델을 고르고(지도 자료에 종류 칸이 없다) 화차 칸 길이를 채운다.
## 손잡이를 끄면 모두 지도 보기의 상자로 돌아간다(결정 476).
func test_wagons_take_models_by_name_and_coal() -> void:
	var wagons := [
		{"name": "석탄 화차", "rect": Rect2i(56, 15, 10, 3), "coal": 10.0},
		{"name": "버려진 탄수차", "rect": Rect2i(60, 23, 6, 3), "coal": 0.0},
		{"name": "빈 화차", "rect": Rect2i(82, 23, 10, 3), "coal": 0.0},
		{"name": "평판 화차", "rect": Rect2i(103, 71, 12, 3), "coal": 0},
	]
	var kinds := wagons.map(func(w: Dictionary) -> String: return Kit.wagon_kind(w))
	assert_eq(kinds, ["wagon_coal", "wagon_tender", "wagon_open", "wagon_flat"])
	var root := Kit.attach_wagons(autofree(Node3D.new()), wagons)
	assert_eq(root.get_meta("model_count", 0), 4)
	assert_eq(Array(root.get_meta("fallback_wagons")), [])
	for i in wagons.size():
		var r: Rect2i = wagons[i]["rect"]
		var ends := _model_ends(root, String(kinds[i]))
		assert_between(ends.x - r.position.x, 0.0, Kit.WAGON_GAP_M, String(kinds[i]) + " 앞쪽 끝")
		assert_between(r.end.x - ends.y, 0.0, Kit.WAGON_GAP_M, String(kinds[i]) + " 뒤쪽 끝")
	ProjectSettings.set_setting(Kit.MODE_SETTING, false)
	var boxes := Kit.attach_wagons(autofree(Node3D.new()), wagons)
	assert_eq(Array(boxes.get_meta("fallback_wagons")), [0, 1, 2, 3], "손잡이 끔: 화차는 모두 상자")


## 타는 문은 그 칸 객차의 옆벽에 문 조각으로 붙고(위쪽 면은 돌려 바깥을 본다), 객차가 아닌 칸의
## 문은 지도 보기의 상자로 남는다.
func test_doors_sit_on_the_coach_walls_and_stay_boxes_off_the_coaches() -> void:
	var data := {"train": Rect2i(0, 1, 48, 3), "train_cars": [
		{"rect": Rect2i(0, 1, 16, 3), "kind": "car"}, {"rect": Rect2i(16, 1, 16, 3), "kind": "car"},
		{"rect": Rect2i(32, 1, 16, 3), "kind": "engine"}]}
	var faces := [{"cell": Vector2i(2, 4), "z": 3.95}, {"cell": Vector2i(18, 0), "z": 1.05}, {"cell": Vector2i(34, 4), "z": 3.95}]
	var root := Kit.attach_doors(autofree(Node3D.new()), faces, data)
	assert_eq(root.get_meta("model_count", 0), 2)
	assert_eq(Array(root.get_meta("fallback_doors")), [2], "기관차 칸의 문은 상자")
	var placed: Array = []
	for key: String in root._batches:
		if key.begins_with("door_open:0:"):
			placed.append_array(root._batches[key]["transforms"])
	assert_eq(placed.size(), 2)
	if placed.size() != 2:
		return
	placed.sort_custom(func(a: Transform3D, b: Transform3D) -> bool: return a.origin.z > b.origin.z)
	var k: float = (16.0 - Kit.FIELD_GAP_M) / 16.0
	var lower: Transform3D = placed[0]
	var upper: Transform3D = placed[1]
	assert_almost_eq(lower.origin, Vector3(2.5, 0.0, 2.5 + Kit.DOOR_WALL_Z * k), Vector3.ONE * 0.01, "아래쪽 옆벽")
	assert_almost_eq(upper.origin, Vector3(18.5, 0.0, 2.5 - Kit.DOOR_WALL_Z * k), Vector3.ONE * 0.01, "위쪽 옆벽")
	assert_gt(lower.basis.z.z, 0.0, "아래쪽 문은 남쪽(+z)을 본다")
	assert_lt(upper.basis.z.z, 0.0, "위쪽 문은 북쪽(-z)을 본다")


func test_field_records_measured_height_beyond_the_box_envelope() -> void:
	var root := Kit.attach_field(autofree(Node3D.new()), _one_car("engine"))
	var overflow: Array = root.get_meta("envelope_overflow", [])
	assert_eq(overflow.size(), 1)
	if overflow.size() == 1:
		var dims: Array = Kit.catalog()["assets"]["locomotive"]["dimensions_m"]
		assert_eq(overflow[0]["kind"], "engine")
		assert_almost_eq(float(overflow[0]["height_m"]), float(dims[1]) * (16.0 - Kit.FIELD_GAP_M) / 16.0, 0.001)
	var stage := Kit.create_stage(autofree(Node3D.new()))
	assert_false(stage.has_meta("envelope_overflow"), "정차 모델은 정차 봉투 안에 든다")


func test_unreadable_catalog_becomes_empty_and_every_entry_point_draws_boxes() -> void:
	var text := FileAccess.get_file_as_string(Kit.CATALOG_PATH)
	var no_kinds: Dictionary = JSON.parse_string(text)
	no_kinds.erase("kinds")
	var field := FieldMap.build()
	var paths := [
		"res://game/world/no_such_train_catalog.json",
		_write("user://train_catalog_syntax.json", text.substr(0, 200)),
		_write("user://train_catalog_top.json", "[]"),
		_write("user://train_catalog_schema.json", JSON.stringify(no_kinds)),
	]
	for path: String in paths:
		var book := Kit.load_catalog(path)
		assert_true(book["kinds"].is_empty() and book["assets"].is_empty() and book["stage_kinds"].is_empty(), path)
		Kit._catalog = book
		assert_false(Kit.can_replace("medtech"), path)
		assert_eq(Kit.create_stage(autofree(Node3D.new())).get_meta("fallback_count"), 6, path)
		var models := Kit.attach_field(autofree(Node3D.new()), field)
		assert_eq((models.get_meta("fallback_cars") as Array).size(), (field["train_cars"] as Array).size(), path)
		assert_eq(models.get_child_count(), 0, path)
	for stage in _stage_roots():
		assert_eq(stage.get_meta("fallback_count"), 6, "대응표를 못 읽은 정차·홈 장면")
	var view := _field_view()
	assert_eq(view["kit"].get_meta("fallback_cars").size(), view["cars"], "대응표를 못 읽은 필드 화면")


func test_missing_part_file_is_recorded_and_skipped_while_the_body_stays() -> void:
	var book := Kit.catalog().duplicate(true)
	book["assets"]["coach_flue"]["path"] = "res://models/train_parts/missing_flue.glb"
	Kit._catalog = book
	var root := Kit.attach_field(autofree(Node3D.new()), _one_car("medtech"))
	assert_eq(root.get_meta("model_count", 0), 1)
	assert_true((root.get_meta("fallback_cars") as Array).is_empty())
	var skipped: Array = root.get_meta("skipped_parts", [])
	assert_eq(skipped.size(), 1)
	if skipped.size() == 1:
		assert_eq(skipped[0]["asset"], "coach_flue")
		assert_eq(skipped[0]["reason"], "파일 없음")
	assert_true(root._batches.has("coach_medic:0:false:0"), "부품이 빠져도 본체는 그린다")
	for key: String in root._batches:
		assert_false(key.begins_with("coach_flue"), key)
	Kit._catalog = {}
	assert_false(Kit.attach_field(autofree(Node3D.new()), _one_car("medtech")).has_meta("skipped_parts"))


func test_two_body_engine_parts_name_the_body_they_attach_to() -> void:
	var site := {"zone": "step", "position": [0.0, 0.0, 1.5], "clearance_m": [2.0, 2.0, 2.0], "door_swing_clear": true, "boarding_clear": true, "step_missing": true}
	assert_true(Kit.part_allowed("engine", "side_step", site, 0, "locomotive"))
	assert_false(Kit.part_allowed("engine", "side_step", site, 0), "본체가 둘인데 지정하지 않음")
	assert_false(Kit.part_allowed("engine", "side_step", site, 0, "coach_medic"), "칸 계획에 없는 본체")
	assert_true(Kit.part_allowed("locomotive", "side_step", site, 0))
	var book := Kit.catalog().duplicate(true)
	book["assets"]["locomotive"]["attachment_sites"] = {"step_check": site}
	book["assets"]["locomotive"]["triangle_limit"] = 20000
	book["kinds"]["engine"]["parts"] = [{"asset": "side_step", "site": "step_check", "body": "locomotive"}, {"asset": "side_step", "site": "step_check"}]
	Kit._catalog = book
	var root := Kit.attach_field(autofree(Node3D.new()), _one_car("engine"))
	var key := "side_step:0:false:0"
	assert_true(root._batches.has(key))
	if root._batches.has(key):
		var placed: Array = root._batches[key]["transforms"]
		assert_eq(placed.size(), 1, "본체를 지정한 요청만 붙는다")
		# 탄수차 5.2m, 틈 0.4m, 기관차 10.4m: 기관차 중심은 쌍의 중심에서 2.8m.
		assert_almost_eq((placed[0] as Transform3D).origin.x, 8.0 + 2.8 * (16.0 - Kit.FIELD_GAP_M) / 16.0, 0.001)


func test_every_kind_maps_to_its_expected_model_or_box() -> void:
	for kind: String in Kit.catalog()["kinds"]:
		var expected: bool = kind in MODEL_KINDS
		var ready := true
		for id: String in Kit.catalog()["kinds"][kind]["assets"]:
			ready = ready and Kit.catalog()["assets"][id]["status"] == "ready"
		assert_eq(ready, expected, "%s 준비 상태" % kind)
		assert_eq(Kit.can_replace(kind), expected, kind)
		var root := Kit.attach_field(autofree(Node3D.new()), _one_car(kind))
		assert_eq(root.get_meta("model_count", 0), 1 if expected else 0, kind)
		assert_eq((root.get_meta("fallback_cars") as Array).size(), 0 if expected else 1, kind)
	var stage := Kit.create_stage(autofree(Node3D.new()))
	var stage_models := 0
	for kind: String in Kit.catalog()["stage_kinds"]:
		stage_models += 1 if kind in MODEL_KINDS else 0
	assert_eq(stage.get_meta("model_count", 0), stage_models)
	assert_eq(stage.get_meta("fallback_count", 0), Kit.catalog()["stage_kinds"].size() - stage_models)


func test_switch_off_and_missing_models_reach_station_home_and_field_view() -> void:
	var on := _field_view()
	var models: int = on["kit"].get_meta("model_count", 0)
	assert_gt(models, 0, "손잡이를 켜면 필드 기관차는 모델")
	assert_eq(on["kit"].get_meta("fallback_cars").size(), on["cars"] - models)
	for stage in _stage_roots():
		assert_eq(stage.get_meta("model_count"), 5)
	ProjectSettings.set_setting(Kit.MODE_SETTING, false)
	var off := _field_view()
	assert_eq(off["kit"].get_meta("fallback_cars").size(), off["cars"], "손잡이 끔: 필드 칸이 모두 상자")
	assert_eq(off["kit"].get_child_count(), 0)
	assert_gt(on["doors"], 0, "손잡이를 켜면 필드 문은 문 조각")
	assert_eq(off["vertices"] - on["vertices"], 30 * (models + on["doors"]), "모델이 맡던 칸과 문마다 꼭짓점 30개짜리 상자가 하나씩 는다")
	for stage in _stage_roots():
		assert_eq(stage.get_meta("fallback_count"), 6)
		assert_eq(stage.find_children("*", "MultiMeshInstance3D", true, false).size(), 0)
	ProjectSettings.set_setting(Kit.MODE_SETTING, true)
	var book := Kit.catalog().duplicate(true)
	book["assets"]["locomotive"]["path"] = "res://models/train_exterior/missing_locomotive.glb"
	Kit._catalog = book
	var lost := _field_view()
	assert_eq(lost["kit"].get_meta("model_count", 0), models - lost["engines"], "기관차 파일 누락: 기관차 칸은 상자로")
	assert_eq(lost["vertices"] - on["vertices"], 30 * lost["engines"])
	for stage in _stage_roots():
		assert_eq(stage.get_meta("model_count"), 4)
		assert_eq(stage.get_meta("fallback_count"), 1)


func test_no_cutaway_body_is_drawn_whole_in_the_home_cutaway() -> void:
	var sliced_keys := func(root: Node3D) -> Array:
		return root._batches.keys().filter(func(k: String) -> bool: return k.contains(":true:"))
	var plain: Node3D = Kit.create_stage(autofree(Node3D.new()), true)
	var bodies: Array = []
	for key: String in sliced_keys.call(plain):
		var id := key.get_slice(":", 0)
		if id not in bodies:
			bodies.append(id)
	assert_false(bodies.is_empty(), "the home cutaway slices some coach today")
	var book := Kit.catalog().duplicate(true)
	book["assets"][bodies[0]][Kit.NO_CUTAWAY_KEY] = true
	Kit._catalog = book
	var marked: Node3D = Kit.create_stage(autofree(Node3D.new()), true)
	for key: String in sliced_keys.call(marked):
		assert_false(key.begins_with(bodies[0] + ":"), key)
	assert_true(marked._batches.has(bodies[0] + ":0:false:0") or marked._batches.keys().any(func(k: String) -> bool: return k.begins_with(bodies[0] + ":0:false:")), "drawn whole")
	assert_eq(marked.get_meta("model_count"), plain.get_meta("model_count"))


## 비(mood 10-30): 칠한 쇠인 열차 몸·쇠 조각은 물을 먹지 않아 젖어도 거의 어두워지지 않고,
## 창을 막은 판자만 나무 몫으로 젖는다.
func test_painted_metal_barely_darkens_in_rain_and_planks_soak() -> void:
	for id: String in Kit.catalog()["assets"].keys():
		var library: Array = Kit.asset_meshes(id)
		for lod: int in 2:
			for row: Dictionary in library[lod]:
				var paint: ShaderMaterial = row["material"]
				var want: float = Kit.WOOD_POROSITY if Kit.WOOD_PARTS.has(id) else Kit.PAINTED_POROSITY
				assert_almost_eq(float(paint.get_shader_parameter("porosity")), want, 0.001, id)
	assert_lt(Kit.PAINTED_POROSITY, 0.25, "painted metal: in the rain it loses no more than about a tenth")
