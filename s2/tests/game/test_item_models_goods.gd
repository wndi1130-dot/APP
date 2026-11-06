extends "res://addons/gut/test.gd"
## 모형의 구조만 검사한다. Godot·GUT 실행은 호출 세션의 문지기가 맡는다.

const Goods = preload("res://tools/item_models_goods.gd")
const BaseModels = preload("res://tools/item_models.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const Carry = preload("res://game/sim/carry.gd")
const EXPECTED_KEYS: Array[String] = [
	"frag_craft", "frag_engine", "frag_expedition", "frag_med", "frag_radio",
	"junk_paper", "note_map", "info_telegraph", "info_timetable",
	"core_electric", "core_engine", "plow_core", "junk_nails", "tweezers",
	"rare_saw_blades", "rusk", "jar_cabbage", "jar_honey", "flour", "peas",
	"rare_coffee_sack", "fever_pills", "food_pack", "herbs", "med_box", "plank",
	"rare_wine_case", "rare_silver_case", "junk_smokes", "junk_rag", "luxury_pack",
	"it_key",
]
const FRAGMENT_KEYS: Array[String] = [
	"frag_craft", "frag_engine", "frag_expedition", "frag_med", "frag_radio",
]
const GLASS_KEYS: Array[String] = ["jar_cabbage", "rare_wine_case", "luxury_pack"]
const LONG_KEYS: Array[String] = ["plank", "tweezers", "info_telegraph", "it_key"]
const MIN_AXIS: float = 0.006
const MAX_AXIS: float = 0.6
const MIN_LONGEST_AXIS: float = 0.06
const MIN_FOOT_Y: float = -0.01
const MAX_FOOT_Y: float = 0.01
const MAX_SATURATION: float = 0.75
const MIN_VALUE: float = 0.12
const MAX_BODY_VALUE: float = 0.8
const MIN_GLASS_ALPHA: float = 0.55
const MAX_GLASS_ALPHA: float = 0.75


func test_ids_are_exactly_the_32_requested_keys() -> void:
	assert_eq(EXPECTED_KEYS.size(), 32)
	var expected: Array[String] = EXPECTED_KEYS.duplicate()
	var actual: Array = Goods.ids()
	expected.sort()
	actual.sort()
	assert_eq(actual, expected, "누락·추가·중복 없이 같은 집합")
	assert_false(actual.has("note_side"), "같은 이름의 쪽지는 중복으로 굽지 않음")
	actual.clear()
	assert_eq(Goods.ids().size(), 32, "반환한 목록을 바꿔도 등록부는 보존")


func test_every_key_is_a_named_field_or_carry_item() -> void:
	for key: String in EXPECTED_KEYS:
		# it_key는 물건 id가 아니라 번호별 집 열쇠가 공유하는 그림 이름이다.
		var item_id: String = FieldItems.key_for(0) if key == "it_key" else key
		var field_known: bool = FieldItems.has(item_id)
		var carry_known: bool = Carry.ITEM_NAMES.has(item_id)
		assert_true(field_known or carry_known, key + "가 실제 물건으로 등록됨")
		var display_name: String = FieldItems.item_name(item_id) if field_known else String(Carry.ITEM_NAMES.get(item_id, ""))
		assert_false(display_name.is_empty(), key + "에 이름이 있음")
		assert_ne(display_name, item_id, key + "가 id 그대로를 이름으로 돌려주지 않음")
	assert_eq(FieldItems.item_name("note_map"), FieldItems.item_name("note_side"), "쪽지의 이름이 같음")


func test_numbered_house_keys_share_one_it_key_picture() -> void:
	const BUILDING_NUMBERS: Array[int] = [0, 1, 423, 9999]
	for building: int in BUILDING_NUMBERS:
		var item_id: String = FieldItems.key_for(building)
		assert_true(FieldItems.has(item_id), item_id + "는 실제 집 열쇠")
		assert_eq(FieldItems.key_building(item_id), building, "집 번호 보존")
		assert_eq(FieldItems.icon(item_id), "it_key", "번호마다 같은 그림 이름")
		assert_eq(FieldItems.item_name(item_id), "열쇠", "번호마다 같은 물건 이름")
		var numbered_model: Node3D = Goods.build(item_id)
		assert_null(numbered_model, "번호별 모형을 중복 등록하지 않음")
		if numbered_model != null:
			numbered_model.free()


func test_house_key_has_open_head_tag_and_distinct_metal_geometry() -> void:
	const OTHER_METAL_KEYS: Array[String] = ["tweezers", "junk_nails"]
	var model: Node3D = Goods.build("it_key")
	assert_not_null(model, "집 열쇠 모형 생성")
	if model == null:
		return
	var parts: Array[Dictionary] = []
	_collect_meshes(model, Transform3D.IDENTITY, parts)
	var bounds: AABB = _combined_bounds(parts)
	assert_between(maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)), 0.07, 0.1, "꼬리표를 포함한 열쇠 전체 길이")
	var head: MeshInstance3D = model.find_child("Head", true, false) as MeshInstance3D
	assert_not_null(head, "고리 머리 있음")
	if head != null:
		assert_true(head.mesh is TorusMesh, "막힌 원판 대신 구멍 있는 원환")
		if head.mesh is TorusMesh:
			var ring: TorusMesh = head.mesh as TorusMesh
			assert_gt(ring.inner_radius, 0.0, "머리 가운데 실제 구멍")
			assert_gt(ring.outer_radius, ring.inner_radius, "쇠 고리 두께")
		var material: BaseMaterial3D = head.get_active_material(0) as BaseMaterial3D
		assert_not_null(material, "쇠 고리 재질")
		if material != null:
			assert_between(material.metallic, 0.4, 0.7, "쇠 반사")
			assert_between(material.roughness, 0.35, 0.5, "쇠 거칠기")
	var tag: Node = model.find_child("Tag", true, false)
	assert_not_null(tag, "작은 종이 꼬리표 있음")
	if tag != null:
		var tag_parts: Array[Dictionary] = []
		_collect_meshes(tag, Transform3D.IDENTITY, tag_parts)
		assert_gte(tag_parts.size(), 2, "종이와 글줄 있음")
	for other_key: String in OTHER_METAL_KEYS:
		var other: Node3D = Goods.build(other_key)
		assert_not_null(other, other_key + " 비교 모형 생성")
		if other == null:
			continue
		var other_parts: Array[Dictionary] = []
		_collect_meshes(other, Transform3D.IDENTITY, other_parts)
		assert_ne(_signature(parts), _signature(other_parts), "열쇠는 " + other_key + "와 다른 모형")
		other.free()
	model.free()


func test_all_models_have_grounded_geometry_and_muted_opaque_materials() -> void:
	for key: String in EXPECTED_KEYS:
		var model: Node3D = Goods.build(key)
		assert_not_null(model, key + " 모형 생성")
		if model == null:
			continue
		var parts: Array[Dictionary] = []
		_collect_meshes(model, Transform3D.IDENTITY, parts)
		assert_gte(parts.size(), 2, key + "에 메시 둘 이상")
		for entry: Dictionary in parts:
			var instance: MeshInstance3D = entry["instance"] as MeshInstance3D
			assert_not_null(instance.mesh, key + "에 메시 자원 있음")
			if instance.mesh == null:
				continue
			var part_box: AABB = _part_bounds(entry)
			assert_true(part_box.position.is_finite() and part_box.size.is_finite(), key + "의 유한한 치수")
			assert_gt(instance.mesh.get_surface_count(), 0, key + "에 표면 있음")
			for surface_index: int in instance.mesh.get_surface_count():
				var material: BaseMaterial3D = instance.get_active_material(surface_index) as BaseMaterial3D
				assert_not_null(material, key + "의 모든 표면에 재질 있음")
				if material == null:
					continue
				if material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
					assert_lte(material.albedo_color.s, MAX_SATURATION, key + " 불투명 채도")
					assert_gte(material.albedo_color.v, MIN_VALUE, key + " 불투명 명도")
					assert_almost_eq(material.albedo_color.a, 1.0, 0.00001, key + " 불투명 알파")
		assert_false(parts.is_empty(), key + "의 치수를 측정할 수 있음")
		if not parts.is_empty():
			var combined: AABB = _combined_bounds(parts)
			for axis: int in 3:
				assert_between(combined.size[axis], MIN_AXIS, MAX_AXIS, key + " 축 " + str(axis) + " m")
			assert_gte(maxf(combined.size.x, maxf(combined.size.y, combined.size.z)), MIN_LONGEST_AXIS, key + " 가장 긴 축")
			assert_between(combined.position.y, MIN_FOOT_Y, MAX_FOOT_Y, key + " 바닥에 놓임(잠기지도 뜨지도 않음)")
		model.free()


## 이웃 시험과 같이 회전에 무관한 메시 부피 × 변환 행렬식으로 큰 부품을 찾는다.
func test_every_tied_largest_part_has_value_at_most_point_eight() -> void:
	for key: String in EXPECTED_KEYS:
		var model: Node3D = Goods.build(key)
		assert_not_null(model, key + " 몸통 명도 검사")
		if model == null:
			continue
		var parts: Array[Dictionary] = []
		_collect_meshes(model, Transform3D.IDENTITY, parts)
		var largest_volume: float = -1.0
		var largest_parts: Array[MeshInstance3D] = []
		for entry: Dictionary in parts:
			var instance: MeshInstance3D = entry["instance"] as MeshInstance3D
			if instance.mesh == null:
				continue
			var pose: Transform3D = entry["pose"]
			var volume: float = instance.mesh.get_aabb().get_volume() * absf(pose.basis.determinant())
			var volume_slack: float = maxf(volume, largest_volume) * 0.00001
			if volume > largest_volume + volume_slack:
				largest_volume = volume
				largest_parts.clear()
			if absf(volume - largest_volume) <= volume_slack:
				largest_parts.append(instance)
		assert_false(largest_parts.is_empty(), key + "에 가장 큰 부품 있음")
		for instance: MeshInstance3D in largest_parts:
			for surface_index: int in instance.mesh.get_surface_count():
				var material: BaseMaterial3D = instance.get_active_material(surface_index) as BaseMaterial3D
				assert_not_null(material, key + " 큰 부품의 재질")
				if material != null:
					assert_lte(material.albedo_color.v, MAX_BODY_VALUE, key + " 큰 부품의 명도")
		model.free()


func test_glass_uses_alpha_transparency_and_visible_inner_geometry() -> void:
	for key: String in EXPECTED_KEYS:
		var model: Node3D = Goods.build(key)
		assert_not_null(model, key + " 유리 검사")
		if model == null:
			continue
		var parts: Array[Dictionary] = []
		_collect_meshes(model, Transform3D.IDENTITY, parts)
		var glass_surfaces: int = 0
		for entry: Dictionary in parts:
			var instance: MeshInstance3D = entry["instance"] as MeshInstance3D
			if instance.mesh == null:
				continue
			for surface_index: int in instance.mesh.get_surface_count():
				var material: BaseMaterial3D = instance.get_active_material(surface_index) as BaseMaterial3D
				if material == null:
					continue
				var glass_marked: bool = bool(instance.get_meta("goods_glass", false))
				if glass_marked or material.albedo_color.a < 1.0 or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					glass_surfaces += 1
					assert_eq(material.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, key + " 유리 투명도 켜짐")
					assert_between(material.albedo_color.a, MIN_GLASS_ALPHA, MAX_GLASS_ALPHA, key + " 유리 알파")
		if GLASS_KEYS.has(key):
			assert_gt(glass_surfaces, 0, key + "에 유리 표면 있음")
			var contents: Node = model.find_child("Contents", true, false)
			assert_not_null(contents, key + "의 유리 안 내용물")
			if contents != null:
				var inner_parts: Array[Dictionary] = []
				_collect_meshes(contents, Transform3D.IDENTITY, inner_parts)
				assert_false(inner_parts.is_empty(), key + " 내용물이 실제 메시임")
		else:
			assert_eq(glass_surfaces, 0, key + "는 불투명 재질")
		model.free()


func test_the_five_blueprint_stamps_have_different_geometry() -> void:
	var signatures: Array[Dictionary] = []
	for key: String in FRAGMENT_KEYS:
		var model: Node3D = Goods.build(key)
		assert_not_null(model, key + " 설계도 검사")
		if model == null:
			continue
		var stamp: Node = model.find_child("Stamp", true, false)
		assert_not_null(stamp, key + " 도장 있음")
		if stamp != null:
			var parts: Array[Dictionary] = []
			_collect_meshes(stamp, Transform3D.IDENTITY, parts)
			assert_gte(parts.size(), 3, key + " 원형 도장과 큰 문양")
			var motif_parts: Array[Dictionary] = []
			for entry: Dictionary in parts:
				var instance: MeshInstance3D = entry["instance"] as MeshInstance3D
				if instance.name != "Seal":
					motif_parts.append(entry)
			var bounds: AABB = _combined_bounds(motif_parts)
			for previous: Dictionary in signatures:
				var previous_size: Vector3 = previous["size"]
				# 원형 바탕을 빼고 문양 자체도 비교한다.
				var same_count: bool = int(previous["count"]) == motif_parts.size()
				assert_false(same_count and bounds.size.is_equal_approx(previous_size), key + "와 " + String(previous["key"]) + " 도장 차이")
			signatures.append({"key": key, "count": motif_parts.size(), "size": bounds.size})
		model.free()
	assert_eq(signatures.size(), FRAGMENT_KEYS.size())


func test_bake_list_contains_exact_keys_and_required_camera_settings() -> void:
	const LIST_PATH: String = "res://tools/icon_bake_items_goods.txt"
	assert_true(FileAccess.file_exists(LIST_PATH), "굽기 목록 존재")
	var text: String = FileAccess.get_file_as_string(LIST_PATH)
	assert_true(text.begins_with("#"), "목록 맨 앞에 설명")
	var actual: Array[String] = []
	for raw_line: String in text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var fields: PackedStringArray = line.split(" ", false)
		assert_eq(fields.size(), 6, "명시적인 네 카메라 값: " + line)
		if fields.size() != 6:
			continue
		var key: String = fields[0]
		actual.append(key)
		assert_eq(fields[1], "res://tools/item_models_goods.gd")
		for field_index: int in range(2, 6):
			assert_true(fields[field_index].is_valid_float(), key + "의 숫자 설정")
			assert_true(is_finite(fields[field_index].to_float()), key + "의 유한한 설정")
		if FRAGMENT_KEYS.has(key) or key in ["junk_paper", "note_map", "info_timetable"]:
			assert_between(fields[3].to_float(), 55.0, 70.0, key + " 종이를 내려다봄")
		if LONG_KEYS.has(key):
			assert_eq(fields[2].to_float(), 35.0, key + " yaw")
			assert_eq(fields[3].to_float(), 28.0, key + " pitch")
			assert_eq(absf(fields[4].to_float()), 30.0, key + " 대각선")
			assert_eq(fields[5].to_float(), 0.06, key + " 좁은 여백")
	var expected: Array[String] = EXPECTED_KEYS.duplicate()
	expected.sort()
	actual.sort()
	assert_eq(actual, expected, "한 물건당 굽기 한 줄")


func test_unknown_empty_unicode_and_long_keys_return_null() -> void:
	var unknown: Array[String] = ["", "missing_goods", "note_side", "없는 물건 / 未登録", "긴 이름/".repeat(128)]
	for key: String in unknown:
		var model: Node3D = Goods.build(key)
		assert_null(model, "등록되지 않은 키: " + key)
		if model != null:
			model.free()


func test_bounds_helper_applies_nested_rotation_scale_and_translation() -> void:
	var fixture: Node3D = Node3D.new()
	fixture.position = Vector3(0.02, 0.03, 0.01)
	var pivot: Node3D = Node3D.new()
	pivot.rotation_degrees.z = 90.0
	pivot.scale = Vector3(2, 1, 1)
	fixture.add_child(pivot)
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.1, 0.02, 0.04)
	instance.mesh = mesh
	instance.position = Vector3(0.05, 0.01, 0)
	pivot.add_child(instance)
	var parts: Array[Dictionary] = []
	_collect_meshes(fixture, Transform3D.IDENTITY, parts)
	var bounds: AABB = _combined_bounds(parts)
	assert_true(bounds.position.is_equal_approx(Vector3(0, 0.03, -0.01)), "변환한 최소점")
	assert_true(bounds.size.is_equal_approx(Vector3(0.02, 0.2, 0.04)), "회전·배율을 적용한 크기")
	fixture.free()


func test_medical_models_use_cross_free_marks_and_no_red_materials() -> void:
	const MEDICAL_KEYS: Array[String] = ["med_box", "frag_med"]
	for key: String in MEDICAL_KEYS:
		var model: Node3D = Goods.build(key)
		assert_not_null(model, key + " 의술 표시 검사")
		if model == null:
			continue
		var parts: Array[Dictionary] = []
		_collect_meshes(model, Transform3D.IDENTITY, parts)
		for entry: Dictionary in parts:
			var instance: MeshInstance3D = entry["instance"] as MeshInstance3D
			if instance.mesh == null:
				continue
			for surface_index: int in instance.mesh.get_surface_count():
				var material: BaseMaterial3D = instance.get_active_material(surface_index) as BaseMaterial3D
				assert_not_null(material, key + " 표시의 재질")
				if material != null:
					var color: Color = material.albedo_color
					var red_hue: bool = color.h >= 0.95 or color.h <= 0.05
					assert_false(red_hue and color.s >= 0.4, key + "에 빨강을 쓰지 않음")
		if key == "frag_med":
			var stamp: Node = model.find_child("Stamp", true, false)
			assert_not_null(stamp, "의술 도장 있음")
			if stamp != null:
				var marker_parts: Array[Dictionary] = []
				_collect_meshes(stamp, Transform3D.IDENTITY, marker_parts)
				var pill_count: int = 0
				for entry: Dictionary in marker_parts:
					var instance: MeshInstance3D = entry["instance"] as MeshInstance3D
					if instance.name == "Seal":
						continue
					pill_count += 1
					assert_true(instance.mesh is SphereMesh, "의술 문양은 판 십자 대신 둥근 알약")
				assert_eq(pill_count, 2, "큰 알약 둘로 의술 표시")
		else:
			var bandage: Node = model.find_child("Bandage", true, false)
			assert_not_null(bandage, "약 상자에 붕대 두루마리 있음")
			if bandage != null:
				var bandage_parts: Array[Dictionary] = []
				_collect_meshes(bandage, Transform3D.IDENTITY, bandage_parts)
				assert_gte(bandage_parts.size(), 3, "붕대 몸과 끝면을 실제 도형으로 만듦")
				var rounded_parts: int = 0
				for entry: Dictionary in bandage_parts:
					var instance: MeshInstance3D = entry["instance"] as MeshInstance3D
					if instance.mesh is CylinderMesh or instance.mesh is TorusMesh:
						rounded_parts += 1
				assert_gte(rounded_parts, 3, "둥근 두루마리가 십자 판을 대신함")
		model.free()


func test_bent_nails_have_flat_heads_points_bends_and_differ_from_it_nails() -> void:
	const MIN_HEAD_DIAMETER_RATIO: float = 2.5
	const MAX_HEAD_THICKNESS_RATIO: float = 0.25
	var model: Node3D = Goods.build("junk_nails")
	assert_not_null(model, "굽은 쇠못 모형 생성")
	if model == null:
		return
	var nails: Array[Node] = model.find_children("Nail_*", "Node3D", true, false)
	assert_between(nails.size(), 3, 4, "쇠못 셋에서 넷")
	var straight_count: int = 0
	var bent_count: int = 0
	for nail: Node in nails:
		var shafts: Array[MeshInstance3D] = []
		for child: Node in nail.get_children():
			if child is MeshInstance3D and String(child.name).begins_with("Shaft_"):
				shafts.append(child as MeshInstance3D)
		assert_between(shafts.size(), 1, 2, "몸통은 곧거나 한 번만 꺾임")
		if shafts.is_empty():
			continue
		if shafts.size() == 1:
			straight_count += 1
		else:
			bent_count += 1
			var first_direction: Vector3 = shafts[0].transform.basis.y.normalized()
			var second_direction: Vector3 = shafts[1].transform.basis.y.normalized()
			assert_lt(absf(first_direction.dot(second_direction)), 0.9, "몸통 두 토막의 꺾임이 실제로 보임")
		var head: MeshInstance3D = nail.get_node_or_null("Head") as MeshInstance3D
		assert_not_null(head, "납작한 못 머리 있음")
		if head != null:
			assert_true(head.mesh is CylinderMesh, "둥근 막대 덩어리 대신 납작한 원통 머리")
			if head.mesh is CylinderMesh and shafts[0].mesh is CylinderMesh:
				var head_mesh: CylinderMesh = head.mesh as CylinderMesh
				var shaft_mesh: CylinderMesh = shafts[0].mesh as CylinderMesh
				var head_radius: float = maxf(head_mesh.top_radius, head_mesh.bottom_radius)
				var shaft_radius: float = maxf(shaft_mesh.top_radius, shaft_mesh.bottom_radius)
				assert_gte(head_radius, shaft_radius * MIN_HEAD_DIAMETER_RATIO, "머리 지름이 몸통의 2.5배 이상")
				assert_lte(head_mesh.height, head_radius * 2.0 * MAX_HEAD_THICKNESS_RATIO, "얇은 못 머리")
		var tip: MeshInstance3D = nail.get_node_or_null("Tip") as MeshInstance3D
		assert_not_null(tip, "뾰족한 못 끝 있음")
		if tip != null:
			assert_true(tip.mesh is CylinderMesh, "원뿔 끝")
			if tip.mesh is CylinderMesh:
				var tip_mesh: CylinderMesh = tip.mesh as CylinderMesh
				assert_almost_eq(tip_mesh.top_radius, 0.0, 0.00001, "끝 반지름이 영인 뾰족한 원뿔")
				assert_gt(tip_mesh.bottom_radius, 0.0, "몸통과 이어지는 끝")
	assert_eq(straight_count, 2, "곧은 몸통 둘")
	assert_between(bent_count, 1, 2, "한 번 꺾인 몸통 하나에서 둘")
	var parts: Array[Dictionary] = []
	_collect_meshes(model, Transform3D.IDENTITY, parts)
	for entry: Dictionary in parts:
		var instance: MeshInstance3D = entry["instance"] as MeshInstance3D
		if instance.mesh == null:
			continue
		for surface_index: int in instance.mesh.get_surface_count():
			var material: BaseMaterial3D = instance.get_active_material(surface_index) as BaseMaterial3D
			assert_not_null(material, "쇠못 재질 있음")
			if material != null:
				assert_between(material.metallic, 0.4, 0.7, "쇠 반사")
				assert_between(material.roughness, 0.35, 0.5, "쇠 거칠기")
				assert_lte(material.albedo_color.s, 0.2, "구릿빛 대신 회색")
				assert_gte(material.albedo_color.v, 0.45, "어두운 바탕에서도 보이는 쇳빛")
	var original: Node3D = BaseModels.build("it_nails")
	assert_not_null(original, "기존 곧은 쇠못 무더기 비교")
	if original != null:
		var original_parts: Array[Dictionary] = []
		_collect_meshes(original, Transform3D.IDENTITY, original_parts)
		assert_ne(_signature(parts), _signature(original_parts), "굽은 못은 it_nails와 다른 모형")
		original.free()
	model.free()


func test_a_kit_model_without_its_colour_map_fails_whole() -> void:
	const NO_MAP_ASSET: String = "res://models/props_field/alarm_clock.glb"
	assert_true(ResourceLoader.exists(NO_MAP_ASSET), "색표 없는 폴더의 모형이 있음")
	var map_path: String = NO_MAP_ASSET.get_base_dir().path_join("Textures/colormap.png")
	assert_false(FileAccess.file_exists(ProjectSettings.globalize_path(map_path)), "그 폴더에 색표 없음")
	var root: Node3D = Node3D.new()
	assert_null(Goods._kenney(root, NO_MAP_ASSET, 0.1, Vector3.ZERO, Color.WHITE), "색표를 못 읽으면 반쯤 칠한 모형 대신 null")
	root.free()


func test_hidden_parts_are_not_measured() -> void:
	var root: Node3D = Node3D.new()
	var shown_part: MeshInstance3D = MeshInstance3D.new()
	shown_part.mesh = BoxMesh.new()
	root.add_child(shown_part)
	var hidden_frame: Node3D = Node3D.new()
	hidden_frame.visible = false
	root.add_child(hidden_frame)
	var under_hidden: MeshInstance3D = MeshInstance3D.new()
	under_hidden.mesh = BoxMesh.new()
	hidden_frame.add_child(under_hidden)
	var hidden_part: MeshInstance3D = MeshInstance3D.new()
	hidden_part.mesh = BoxMesh.new()
	hidden_part.visible = false
	root.add_child(hidden_part)
	var parts: Array[Dictionary] = []
	_collect_meshes(root, Transform3D.IDENTITY, parts)
	assert_eq(parts.size(), 1, "숨은 부품과 숨은 틀 밑 부품은 굽기처럼 뺌")
	if parts.size() == 1:
		assert_eq(parts[0]["instance"], shown_part)
	root.free()


## 부품들의 구조 지문: 부품마다 (메시 종류, mm로 반올림한 놓인 경계, 표면마다 색)을 정렬해 이은 것.
## 같으면 한 모형의 복사다. 다르다고 눈에 갈리는 것은 아니다(가려진 부품 하나로도 달라짐) — 그건
## 구운 그림의 픽셀 검사(test_item_art의 같은 그림·거의 같은 그림)가 본다.
func _signature(parts: Array[Dictionary]) -> String:
	var rows: PackedStringArray = PackedStringArray()
	for entry: Dictionary in parts:
		var instance: MeshInstance3D = entry["instance"] as MeshInstance3D
		if instance.mesh == null:
			continue
		var box: AABB = _part_bounds(entry)
		var colours: PackedStringArray = PackedStringArray()
		for surface: int in instance.mesh.get_surface_count():
			var material: BaseMaterial3D = instance.get_active_material(surface) as BaseMaterial3D
			colours.append(material.albedo_color.to_html() if material != null else "none")
		rows.append("%s %s %s %s" % [instance.mesh.get_class(), _mm(box.position), _mm(box.size), ",".join(colours)])
	rows.sort()
	return "\n".join(rows)


func _mm(value: Vector3) -> String:
	return "%d,%d,%d" % [roundi(value.x * 1000.0), roundi(value.y * 1000.0), roundi(value.z * 1000.0)]


## Only what is drawn: a hidden node hides what is under it, as the bake tool
## (icon_bake._copy_meshes) leaves it out.
func _collect_meshes(node: Node, parent_pose: Transform3D, parts: Array[Dictionary], shown: bool = true) -> void:
	var pose: Transform3D = parent_pose
	if node is Node3D:
		var spatial: Node3D = node as Node3D
		pose = spatial.transform if spatial.top_level else parent_pose * spatial.transform
		shown = shown and spatial.visible
	if node is MeshInstance3D and shown:
		parts.append({"instance": node, "pose": pose})
	for child: Node in node.get_children():
		_collect_meshes(child, pose, parts, shown)


func _part_bounds(entry: Dictionary) -> AABB:
	var instance: MeshInstance3D = entry["instance"] as MeshInstance3D
	if instance.mesh == null:
		return AABB()
	var pose: Transform3D = entry["pose"]
	var local_box: AABB = instance.mesh.get_aabb()
	var transformed: AABB = AABB(pose * local_box.get_endpoint(0), Vector3.ZERO)
	for corner: int in range(1, 8):
		transformed = transformed.expand(pose * local_box.get_endpoint(corner))
	return transformed


func _combined_bounds(parts: Array[Dictionary]) -> AABB:
	var combined: AABB = AABB()
	var have_bounds: bool = false
	for entry: Dictionary in parts:
		var instance: MeshInstance3D = entry["instance"] as MeshInstance3D
		if instance.mesh == null:
			continue
		var part_box: AABB = _part_bounds(entry)
		combined = combined.merge(part_box) if have_bounds else part_box
		have_bounds = true
	return combined
