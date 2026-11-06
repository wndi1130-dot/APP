extends "res://addons/gut/test.gd"
## 모형의 구조만 검사한다. Godot·GUT 실행은 호출 세션의 문지기가 맡는다.

const Goods = preload("res://tools/item_models_goods.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const Carry = preload("res://game/sim/carry.gd")
const EXPECTED_KEYS: Array[String] = [
	"frag_craft", "frag_engine", "frag_expedition", "frag_med", "frag_radio",
	"junk_paper", "note_map", "info_telegraph", "info_timetable",
	"core_electric", "core_engine", "plow_core", "junk_nails", "tweezers",
	"rare_saw_blades", "rusk", "jar_cabbage", "jar_honey", "flour", "peas",
	"rare_coffee_sack", "fever_pills", "food_pack", "herbs", "med_box", "plank",
	"rare_wine_case", "rare_silver_case", "junk_smokes", "junk_rag", "luxury_pack",
]
const FRAGMENT_KEYS: Array[String] = [
	"frag_craft", "frag_engine", "frag_expedition", "frag_med", "frag_radio",
]
const GLASS_KEYS: Array[String] = ["jar_cabbage", "rare_wine_case", "luxury_pack"]
const LONG_KEYS: Array[String] = ["plank", "tweezers", "info_telegraph"]
const MIN_AXIS: float = 0.006
const MAX_AXIS: float = 0.6
const MIN_LONGEST_AXIS: float = 0.06
const MIN_FOOT_Y: float = -0.01
const MAX_SATURATION: float = 0.75
const MIN_VALUE: float = 0.12
const MAX_BODY_VALUE: float = 0.8
const MIN_GLASS_ALPHA: float = 0.55
const MAX_GLASS_ALPHA: float = 0.75


func test_ids_are_exactly_the_31_requested_keys() -> void:
	assert_eq(EXPECTED_KEYS.size(), 31)
	var expected: Array[String] = EXPECTED_KEYS.duplicate()
	var actual: Array = Goods.ids()
	expected.sort()
	actual.sort()
	assert_eq(actual, expected, "누락·추가·중복 없이 같은 집합")
	assert_false(actual.has("note_side"), "같은 이름의 쪽지는 중복으로 굽지 않음")
	actual.clear()
	assert_eq(Goods.ids().size(), 31, "반환한 목록을 바꿔도 등록부는 보존")


func test_every_key_is_a_named_field_or_carry_item() -> void:
	for key: String in EXPECTED_KEYS:
		var field_known: bool = FieldItems.has(key)
		var carry_known: bool = Carry.ITEM_NAMES.has(key)
		assert_true(field_known or carry_known, key + "가 실제 물건으로 등록됨")
		var display_name: String = FieldItems.item_name(key) if field_known else String(Carry.ITEM_NAMES.get(key, ""))
		assert_false(display_name.is_empty(), key + "에 이름이 있음")
		assert_ne(display_name, key, key + "가 id 그대로를 이름으로 돌려주지 않음")
	assert_eq(FieldItems.item_name("note_map"), FieldItems.item_name("note_side"), "쪽지의 이름이 같음")


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
			assert_gte(combined.position.y, MIN_FOOT_Y, key + " 바닥 아래로 잠기지 않음")
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


func _collect_meshes(node: Node, parent_pose: Transform3D, parts: Array[Dictionary]) -> void:
	var pose: Transform3D = parent_pose
	if node is Node3D:
		var spatial: Node3D = node as Node3D
		pose = spatial.transform if spatial.top_level else parent_pose * spatial.transform
	if node is MeshInstance3D:
		parts.append({"instance": node, "pose": pose})
	for child: Node in node.get_children():
		_collect_meshes(child, pose, parts)


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
