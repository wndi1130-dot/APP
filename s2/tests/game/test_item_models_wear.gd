extends "res://addons/gut/test.gd"
## 장면 트리·뷰포트 없이 펼친 옷과 굽기 계약을 확인한다.

const WearModels = preload("res://tools/item_models_wear.gd")
const Wear = preload("res://game/sim/wear.gd")
const BAKE_LIST: String = "res://tools/icon_bake_items_wear.txt"
const KIND_COUNT: int = 47
const LONGEST_MIN: float = 0.15
const LONGEST_MAX: float = 1.4
const THINNEST_MIN: float = 0.006
const GROUND_MIN: float = -0.01
const HUE_SOURCE_MIN_SATURATION: float = 0.12
const HUE_DISTANCE_MAX: float = 0.08
const VOLUME_TOLERANCE: float = 0.00001


func test_ids_are_exactly_the_47_wear_kinds() -> void:
	var actual: Array = WearModels.ids()
	var expected: Array = Wear.KINDS.keys()
	actual.sort()
	expected.sort()
	assert_eq(actual.size(), KIND_COUNT, "모형 47개")
	assert_eq(expected.size(), KIND_COUNT, "원본 옷 47개")
	assert_eq(actual, expected, "별칭 대신 실제 옷 id를 모두 쓴다")


func test_all_models_have_grounded_geometry_and_muted_materials() -> void:
	for key: String in WearModels.ids():
		var model: Node3D = WearModels.build(key)
		assert_not_null(model, key + " 생성")
		if model == null:
			continue
		var parts: Array[Dictionary] = []
		_collect_meshes(model, Transform3D.IDENTITY, parts)
		assert_gte(parts.size(), 3, key + " 부품 3개 이상")
		var combined: AABB = AABB()
		var have_bounds: bool = false
		for entry: Dictionary in parts:
			var instance: MeshInstance3D = entry["instance"] as MeshInstance3D
			assert_not_null(instance.mesh, key + " 메시 자원")
			if instance.mesh == null:
				continue
			var pose: Transform3D = entry["pose"]
			var bounds: AABB = _transformed_box(instance.mesh.get_aabb(), pose)
			assert_true(bounds.position.is_finite(), key + " 유한한 위치")
			assert_true(bounds.size.is_finite(), key + " 유한한 크기")
			combined = combined.merge(bounds) if have_bounds else bounds
			have_bounds = true
			assert_gt(instance.mesh.get_surface_count(), 0, key + " 표면 존재")
			for surface: int in instance.mesh.get_surface_count():
				var material: BaseMaterial3D = instance.get_active_material(surface) as BaseMaterial3D
				assert_not_null(material, key + " 모든 표면의 재질")
				if material == null:
					continue
				assert_lte(material.albedo_color.s, 0.75, key + " 채도")
				assert_gte(material.albedo_color.v, 0.12, key + " 명도")
		assert_true(have_bounds, key + " 합칠 수 있는 경계")
		if have_bounds:
			var longest: float = maxf(combined.size.x, maxf(combined.size.y, combined.size.z))
			var thinnest: float = minf(combined.size.x, minf(combined.size.y, combined.size.z))
			assert_between(longest, LONGEST_MIN, LONGEST_MAX, key + " 가장 긴 축(m)")
			assert_gte(thinnest, THINNEST_MIN, key + " 가장 짧은 축(m)")
			assert_between(combined.position.y, GROUND_MIN, 0.01, key + " 땅 위에 놓임")
		model.free()


func test_every_tied_largest_part_has_a_readable_body_colour() -> void:
	for key: String in WearModels.ids():
		var model: Node3D = WearModels.build(key)
		assert_not_null(model, key + " 몸판 색 검사 생성")
		if model == null:
			continue
		var parts: Array[Dictionary] = []
		_collect_meshes(model, Transform3D.IDENTITY, parts)
		var largest: Array[MeshInstance3D] = _largest_parts(parts)
		assert_false(largest.is_empty(), key + " 가장 큰 부품 존재")
		for instance: MeshInstance3D in largest:
			for surface: int in instance.mesh.get_surface_count():
				var material: BaseMaterial3D = instance.get_active_material(surface) as BaseMaterial3D
				assert_not_null(material, key + " 몸판 재질")
				if material != null:
					assert_lte(material.albedo_color.v, 0.8, key + " 몸판 명도 상한")
		model.free()


func test_chromatic_wear_tints_keep_their_srgb_hue() -> void:
	for key: String in Wear.KINDS.keys():
		var look: Dictionary = Wear.look(key)
		var tint: Array = look.get("look_tint", [])
		if tint.size() != 3:
			continue
		var source: Color = Color(float(tint[0]), float(tint[1]), float(tint[2])).linear_to_srgb()
		# 거의 회색인 원본은 작은 RGB 오차만으로 H가 크게 움직인다.
		# 이 색상 잡음에는 허용 오차를 늘리는 대신 요청한 채도 문턱을 적용한다.
		if source.s < HUE_SOURCE_MIN_SATURATION:
			continue
		var model: Node3D = WearModels.build(key)
		assert_not_null(model, key + " 색조 검사 생성")
		if model == null:
			continue
		var parts: Array[Dictionary] = []
		_collect_meshes(model, Transform3D.IDENTITY, parts)
		var largest: Array[MeshInstance3D] = _largest_parts(parts)
		assert_false(largest.is_empty(), key + " 색조를 검사할 몸판")
		for instance: MeshInstance3D in largest:
			for surface: int in instance.mesh.get_surface_count():
				var material: BaseMaterial3D = instance.get_active_material(surface) as BaseMaterial3D
				assert_not_null(material, key + " 색조 재질")
				if material != null:
					var distance: float = absf(material.albedo_color.h - source.h)
					distance = minf(distance, 1.0 - distance)
					assert_lte(distance, HUE_DISTANCE_MAX, key + " 원형 색상 거리")
		model.free()


func test_no_two_kinds_in_a_shape_family_share_the_same_signature() -> void:
	var signatures: Dictionary = {}
	for key: String in WearModels.ids():
		var model: Node3D = WearModels.build(key)
		assert_not_null(model, key + " 갈래 비교 생성")
		if model == null:
			continue
		var signature: Dictionary = _signature(model)
		var family: String = String(WearModels.RECIPES[key]["shape"])
		for other_key: String in signatures.keys():
			var other_family: String = String(WearModels.RECIPES[other_key]["shape"])
			if family == other_family:
				var other_signature: Dictionary = signatures[other_key]
				assert_true(_signatures_differ(signature, other_signature), key + " / " + other_key)
		signatures[key] = signature
		model.free()


func test_bake_list_has_each_kind_once_and_one_angle_for_flat_clothes() -> void:
	assert_true(FileAccess.file_exists(BAKE_LIST), "굽기 목록 존재")
	var contents: String = FileAccess.get_file_as_string(BAKE_LIST)
	var listed: Array[String] = []
	for raw_line: String in contents.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var fields: PackedStringArray = line.split(" ", false)
		assert_eq(fields.size(), 6, "id·경로·각도 셋·여백: " + line)
		if fields.size() != 6:
			continue
		var key: String = fields[0]
		assert_false(listed.has(key), key + " 중복 없음")
		listed.append(key)
		assert_eq(fields[1], "res://tools/item_models_wear.gd", key + " 모형 경로")
		for field_index: int in range(2, 6):
			assert_true(fields[field_index].is_valid_float(), key + " 수치 인자")
			assert_true(is_finite(fields[field_index].to_float()), key + " 유한한 인자")
		assert_between(fields[5].to_float(), 0.0, 0.4, key + " 유효 여백")
		if not WearModels.RECIPES.has(key):
			continue
		var family: String = String(WearModels.RECIPES[key]["shape"])
		if family not in ["footwear", "hat"]:
			assert_eq(fields[2].to_float(), 0.0, key + " 펼친 옷 yaw")
			assert_eq(fields[3].to_float(), 68.0, key + " 펼친 옷 pitch")
			assert_eq(fields[4].to_float(), 0.0, key + " 펼친 옷 roll")
			assert_eq(fields[5].to_float(), 0.06, key + " 펼친 옷 여백")
	listed.sort()
	var expected: Array = Wear.KINDS.keys()
	expected.sort()
	assert_eq(listed.size(), KIND_COUNT, "굽기 47줄")
	assert_eq(Array(listed), expected, "굽기 목록도 실제 옷 id 전부")


func test_unknown_keys_return_null() -> void:
	var unknown: Array[String] = ["", "missing_wear_icon", "없는 옷 / 등록 안 됨", "긴 이름/".repeat(128)]
	for key: String in unknown:
		var model: Node3D = WearModels.build(key)
		assert_null(model, key + " 미등록 id")
		if model != null:
			model.free()


## 분리된 노드의 중첩 회전·크기·이동을 빠뜨리지 않는다.
func _collect_meshes(node: Node, parent_pose: Transform3D, parts: Array[Dictionary]) -> void:
	var pose: Transform3D = parent_pose
	if node is Node3D:
		var spatial: Node3D = node as Node3D
		pose = spatial.transform if spatial.top_level else parent_pose * spatial.transform
	if node is MeshInstance3D:
		parts.append({"instance": node, "pose": pose})
	for child: Node in node.get_children():
		_collect_meshes(child, pose, parts)


func _transformed_box(local_box: AABB, pose: Transform3D) -> AABB:
	var result: AABB = AABB(pose * local_box.get_endpoint(0), Vector3.ZERO)
	for corner: int in range(1, 8):
		result = result.expand(pose * local_box.get_endpoint(corner))
	return result


## 회전한 경계의 부피가 아니라 원래 경계 부피 × 변환 행렬식을 쓴다.
## 가장 큰 부품이 여러 개면 모두 검사한다(이웃 시험과 같은 기준).
func _largest_parts(parts: Array[Dictionary]) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	var largest_volume: float = -1.0
	for entry: Dictionary in parts:
		var instance: MeshInstance3D = entry["instance"] as MeshInstance3D
		if instance.mesh == null:
			continue
		var pose: Transform3D = entry["pose"]
		var volume: float = instance.mesh.get_aabb().get_volume() * absf(pose.basis.determinant())
		var slack: float = maxf(volume, largest_volume) * VOLUME_TOLERANCE
		if volume > largest_volume + slack:
			largest_volume = volume
			result.clear()
		if absf(volume - largest_volume) <= slack:
			result.append(instance)
	return result


func _signature(model: Node3D) -> Dictionary:
	var parts: Array[Dictionary] = []
	_collect_meshes(model, Transform3D.IDENTITY, parts)
	var bounds: AABB = AABB()
	var have_bounds: bool = false
	for entry: Dictionary in parts:
		var instance: MeshInstance3D = entry["instance"] as MeshInstance3D
		if instance.mesh == null:
			continue
		var pose: Transform3D = entry["pose"]
		var part_box: AABB = _transformed_box(instance.mesh.get_aabb(), pose)
		bounds = bounds.merge(part_box) if have_bounds else part_box
		have_bounds = true
	var largest: Array[MeshInstance3D] = _largest_parts(parts)
	var colour: Color = Color.TRANSPARENT
	if not largest.is_empty() and largest[0].mesh.get_surface_count() > 0:
		var material: BaseMaterial3D = largest[0].get_active_material(0) as BaseMaterial3D
		if material != null:
			colour = material.albedo_color
	return {"count": parts.size(), "bounds": bounds, "colour": colour}


func _signatures_differ(first: Dictionary, second: Dictionary) -> bool:
	var first_box: AABB = first["bounds"]
	var second_box: AABB = second["bounds"]
	var first_colour: Color = first["colour"]
	var second_colour: Color = second["colour"]
	return int(first["count"]) != int(second["count"]) \
		or not first_box.position.is_equal_approx(second_box.position) \
		or not first_box.size.is_equal_approx(second_box.size) \
		or not first_colour.is_equal_approx(second_colour)
