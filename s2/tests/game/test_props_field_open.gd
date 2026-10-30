extends "res://addons/gut/test.gd"
## 공개 소품 14종. 계획판은 실패하며 굽기·가져오기 뒤 실행한다.
const PropKinds = preload("res://game/world/prop_kinds.gd")
const KIT_DIR: String = "res://models/props_field"
const EXPECTED_TEXT: String = "kettle kettle_enamel cutting_board vase alarm_clock mug teapot serving_bowl dinner_plate yard_well mailbox wall_poster wall_clock bicycle"
const MADE: Array[String] = ["mailbox", "wall_poster", "wall_clock", "bicycle"]
const WALL: Array[String] = ["wall_poster", "wall_clock"]
const LIMITS: Dictionary = {
	"kettle": 250,
	"kettle_enamel": 250,
	"cutting_board": 80,
	"vase": 120,
	"alarm_clock": 220,
	"mug": 120,
	"teapot": 250,
	"serving_bowl": 150,
	"dinner_plate": 80,
	"yard_well": 700,
	"mailbox": 200,
	"wall_poster": 150,
	"wall_clock": 250,
	"bicycle": 600,
}
# Godot XYZ: 가로·높이·깊이.
const RANGES: Dictionary = {
	"kettle": [Vector3(0.12, 0.12, 0.08), Vector3(0.5, 0.4, 0.4)],
	"kettle_enamel": [Vector3(0.12, 0.12, 0.08), Vector3(0.5, 0.4, 0.4)],
	"cutting_board": [Vector3(0.3, 0.005, 0.15), Vector3(0.5, 0.04, 0.3)],
	"vase": [Vector3(0.04, 0.08, 0.04), Vector3(0.3, 0.6, 0.3)],
	"alarm_clock": [Vector3(0.09, 0.14, 0.04), Vector3(0.13, 0.19, 0.07)],
	"mug": [Vector3(0.11, 0.095, 0.08), Vector3(0.15, 0.13, 0.12)],
	"teapot": [Vector3(0.16, 0.11, 0.16), Vector3(0.22, 0.16, 0.22)],
	"serving_bowl": [Vector3(0.18, 0.05, 0.18), Vector3(0.24, 0.09, 0.24)],
	"dinner_plate": [Vector3(0.24, 0.02, 0.24), Vector3(0.31, 0.055, 0.31)],
	"yard_well": [Vector3(1.3, 1.8999, 1.3), Vector3(1.92, 1.9001, 1.92)],
	"mailbox": [Vector3(0.19, 1.2499, 0.47), Vector3(0.3, 1.2501, 0.49)],
	"wall_poster": [Vector3(0.5999, 0.8499, 0.0099), Vector3(0.6001, 0.8501, 0.0101)],
	"wall_clock": [Vector3(0.3199, 0.3199, 0.0499), Vector3(0.3201, 0.3201, 0.0501)],
	"bicycle": [Vector3(1.6999, 0.1, 0.65), Vector3(1.7001, 0.35, 0.96)],
}
const EPS: float = 0.0001


func _catalog() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(KIT_DIR + "/catalog_open.json"))
	if parsed is Dictionary:
		return parsed
	return {}


func _assets() -> Dictionary:
	var book: Dictionary = _catalog()
	var assets: Dictionary = book.get("assets", {})
	return assets


func test_catalog_names_equal_the_fourteen_open_kinds() -> void:
	var book: Dictionary = _catalog()
	var assets: Dictionary = _assets()
	var expected: PackedStringArray = EXPECTED_TEXT.split(" ", false)
	var listed: PackedStringArray = PackedStringArray(assets.keys())
	var declared: PackedStringArray = PackedStringArray(book.get("expected_kinds", []))
	expected.sort()
	listed.sort()
	declared.sort()
	assert_eq(assets.size(), 14, "일부 생성이나 빈 장부는 통과하지 않음")
	assert_eq(listed, expected, "장부 이름")
	assert_eq(declared, expected, "장부 선언 이름")
	var made: PackedStringArray = []
	for filename: String in DirAccess.get_files_at(KIT_DIR):
		if filename.get_extension() == "glb" and filename.get_basename() in expected:
			made.append(filename.get_basename())
	made.sort()
	assert_eq(made, expected, "실제 GLB 14종")
	for kind: String in expected:
		assert_eq(PropKinds.model_path(kind), KIT_DIR + "/" + kind + ".glb", kind + " 종류 경로")


func test_ready_files_imports_digest_and_credits() -> void:
	var assets: Dictionary = _assets()
	for kind: String in EXPECTED_TEXT.split(" ", false):
		var row: Dictionary = assets.get(kind, {})
		var path: String = KIT_DIR + "/" + kind + ".glb"
		assert_eq(str(row.get("status", "")), "ready", kind + " 굽기 완료")
		assert_eq(str(row.get("path", "")), path, kind)
		assert_true(FileAccess.file_exists(path), kind + " GLB")
		assert_true(FileAccess.file_exists(path + ".import"), kind + " import")
		assert_false(str(row.get("source_name", "")).is_empty(), kind + " 원본 이름")
		assert_false(str(row.get("license_path", "")).is_empty(), kind + " 라이선스 근거")
		var source_credit: String = str(row.get("source_credit", ""))
		if kind in MADE:
			assert_true(source_credit.contains("자체 제작"), kind + " 자체 제작 출처")
		else:
			assert_true(source_credit.contains("CC BY 4.0"), kind + " 제3자 출처 표시")
		if not FileAccess.file_exists(path):
			continue
		assert_eq(FileAccess.get_sha256(path), str(row.get("sha256", "")), kind + " SHA-256")
		var handle: FileAccess = FileAccess.open(path, FileAccess.READ)
		assert_not_null(handle, kind + " 파일 열기")
		if handle == null:
			continue
		assert_eq(handle.get_length(), int(row.get("bytes", 0)), kind + " 바이트")
		handle.close()


func _assert_dimensions(kind: String, measured: AABB) -> void:
	var expected: Array = RANGES[kind]
	var lower: Vector3 = expected[0]
	var upper: Vector3 = expected[1]
	for axis: int in range(3):
		assert_gte(measured.size[axis], lower[axis] - EPS, kind + " 최소 치수")
		assert_lte(measured.size[axis], upper[axis] + EPS, kind + " 최대 치수")
	var footprint: Vector2 = Vector2(2, 2) if kind == "yard_well" else (
		Vector2(2, 1) if kind == "bicycle" else Vector2.ONE)
	assert_lte(measured.size.x, footprint.x * 0.96 + EPS, kind + " 가로 96%")
	assert_lte(measured.size.z, footprint.y * 0.96 + EPS, kind + " 깊이 96%")
	assert_almost_eq(measured.position.x + measured.end.x, 0.0, EPS, kind + " 가로 중심")
	assert_almost_eq(measured.position.z + measured.end.z, 0.0, EPS, kind + " 깊이 중심")
	var bottom: float = 1.20 if kind == "wall_poster" else (1.79 if kind == "wall_clock" else 0.0)
	assert_almost_eq(measured.position.y, bottom, EPS, kind + " 밑면")
	if kind in WALL:
		assert_gte(measured.position.y, 1.0, kind + " 벽걸이 높이")
	if kind == "wall_clock":
		assert_almost_eq(measured.get_center().y, 1.95, EPS, "벽시계 중심")
	if kind == "cutting_board":
		assert_lt(measured.size.y, minf(measured.size.x, measured.size.z), "도마는 눕힘: 얇은 쪽이 위")
	if kind == "bicycle":
		assert_gt(measured.size.x, measured.size.z, "자전거 긴 쪽 X")
		assert_lte(measured.size.y, 0.35 + EPS, "쓰러진 자전거 높이")


func test_catalog_budgets_measurements_and_mounts() -> void:
	var assets: Dictionary = _assets()
	for kind: String in EXPECTED_TEXT.split(" ", false):
		var row: Dictionary = assets.get(kind, {})
		assert_eq(str(row.get("status", "")), "ready", kind)
		assert_eq(int(row.get("triangle_limit", 0)), int(LIMITS[kind]), kind + " 고정 상한")
		var expected_mount: String = "wall" if kind in WALL else (
			"floor" if kind in ["yard_well", "mailbox", "bicycle"] else "top")
		assert_eq(str(row.get("mount", "")), expected_mount, kind + " 놓기 방식")
		if str(row.get("status", "")) != "ready":
			continue
		var tris: int = int(row.get("lod0_tris", 0))
		assert_gt(tris, 0, kind)
		assert_lte(tris, int(LIMITS[kind]), kind)
		var size: Array = row.get("dimensions_m", [])
		var footprint: Array = row.get("footprint_m", [])
		var limits: Array = row.get("bounds_m", [])
		assert_eq(size.size(), 3, kind + " 치수")
		assert_eq(footprint.size(), 2, kind + " 발자국")
		assert_eq(limits.size(), 2, kind + " 경계")
		if size.size() != 3 or footprint.size() != 2 or limits.size() != 2:
			continue
		var lower: Array = limits[0]
		var upper: Array = limits[1]
		assert_eq(lower.size(), 3, kind)
		assert_eq(upper.size(), 3, kind)
		if lower.size() != 3 or upper.size() != 3:
			continue
		var a: Vector3 = Vector3(float(lower[0]), float(lower[1]), float(lower[2]))
		var b: Vector3 = Vector3(float(upper[0]), float(upper[1]), float(upper[2]))
		var measured: AABB = AABB(a, b - a)
		_assert_dimensions(kind, measured)
		for axis: int in range(3):
			assert_almost_eq(measured.size[axis], float(size[axis]), EPS, kind + " 경계·치수 일치")
		assert_eq(int(footprint[0]), 2 if kind in ["yard_well", "bicycle"] else 1, kind + " 칸 가로")
		assert_eq(int(footprint[1]), 2 if kind == "yard_well" else 1, kind + " 칸 깊이")
		assert_almost_eq(float(row.get("height_m", 0)), b.y, EPS, kind + " 위끝")
		assert_almost_eq(float(row.get("bottom_m", 0)), a.y, EPS, kind + " 밑면 장부")


func test_glb_contains_no_material_texture_or_animation() -> void:
	for kind: String in EXPECTED_TEXT.split(" ", false):
		var path: String = KIT_DIR + "/" + kind + ".glb"
		if not FileAccess.file_exists(path):
			assert_true(false, kind + " GLB 없음")
			continue
		var data: PackedByteArray = FileAccess.get_file_as_bytes(path)
		assert_gte(data.size(), 28, kind + " GLB 머리")
		if data.size() < 28:
			continue
		assert_eq(data.slice(0, 4).get_string_from_ascii(), "glTF", kind)
		assert_eq(data.decode_u32(4), 2, kind + " GLB 버전")
		assert_eq(data.decode_u32(8), data.size(), kind + " GLB 길이")
		assert_eq(data.decode_u32(16), 0x4E4F534A, kind + " JSON chunk")
		var length: int = data.decode_u32(12)
		assert_lte(20 + length, data.size(), kind)
		if 20 + length > data.size():
			continue
		var parsed: Variant = JSON.parse_string(data.slice(20, 20 + length).get_string_from_utf8())
		assert_true(parsed is Dictionary, kind + " GLB JSON")
		if not parsed is Dictionary:
			continue
		var doc: Dictionary = parsed
		for key: String in ["materials", "textures", "images", "animations", "skins"]:
			var entries: Array = doc.get(key, [])
			assert_true(entries.is_empty(), kind + " 불필요 자원 " + key)
		var meshes: Array = doc.get("meshes", [])
		assert_eq(meshes.size(), 1, kind + " GLB 메시")
		if meshes.size() == 1:
			var primitives: Array = meshes[0].get("primitives", [])
			assert_eq(primitives.size(), 1, kind + " GLB surface")
			if primitives.size() == 1:
				var primitive: Dictionary = primitives[0]
				var attributes: Dictionary = primitive.get("attributes", {})
				assert_true(attributes.has("COLOR_0"), kind + " 정점색")
				assert_false(primitive.has("material"), kind + " 재질 연결 없음")


func _mesh_nodes(node: Node, into: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		into.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_mesh_nodes(child, into)


func _model_transform(node: Node) -> Transform3D:
	var result: Transform3D = Transform3D.IDENTITY
	var current: Node = node
	while current != null:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


func test_imported_mesh_actual_triangles_colours_and_bounds() -> void:
	var assets: Dictionary = _assets()
	for kind: String in EXPECTED_TEXT.split(" ", false):
		var row: Dictionary = assets.get(kind, {})
		var path: String = KIT_DIR + "/" + kind + ".glb"
		if str(row.get("status", "")) != "ready" or not FileAccess.file_exists(path + ".import"):
			assert_true(false, kind + " 굽기·가져오기 필요")
			continue
		var packed: PackedScene = load(path) as PackedScene
		assert_not_null(packed, kind)
		if packed == null:
			continue
		var root: Node = packed.instantiate()
		var nodes: Array[MeshInstance3D] = []
		_mesh_nodes(root, nodes)
		assert_eq(nodes.size(), 1, kind + " 메시 하나")
		if nodes.size() == 1:
			assert_not_null(nodes[0].mesh, kind + " 메시 자료")
		if nodes.size() != 1 or nodes[0].mesh == null:
			root.free()
			continue
		var mesh: Mesh = nodes[0].mesh
		assert_eq(mesh.get_surface_count(), 1, kind + " surface 하나")
		if mesh.get_surface_count() != 1:
			root.free()
			continue
		assert_eq(mesh.surface_get_primitive_type(0), Mesh.PRIMITIVE_TRIANGLES, kind)
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		assert_gt(vertices.size(), 0, kind)
		assert_eq(colours.size(), vertices.size(), kind + " 실제 정점색")
		var index_count: int = indices.size() if not indices.is_empty() else vertices.size()
		var tris: int = int(index_count / 3.0)
		assert_eq(index_count % 3, 0, kind)
		assert_gt(tris, 0, kind)
		assert_lte(tris, int(LIMITS[kind]), kind)
		assert_eq(tris, int(row.get("lod0_tris", 0)), kind + " 실제 삼각형")
		var measured: AABB = _model_transform(nodes[0]) * mesh.get_aabb()
		_assert_dimensions(kind, measured)
		var limits: Array = row.get("bounds_m", [])
		if limits.size() == 2:
			for axis: int in range(3):
				assert_almost_eq(measured.position[axis], float(limits[0][axis]), EPS, kind + " 실제 최소")
				assert_almost_eq(measured.end[axis], float(limits[1][axis]), EPS, kind + " 실제 최대")
		var pale := 0
		var sum := Vector3.ZERO
		var groups := {}
		for colour: Color in colours:
			sum += Vector3(colour.r, colour.g, colour.b)
			groups[Vector3i(roundi(colour.r * 20.0), roundi(colour.g * 20.0), roundi(colour.b * 20.0))] = true
			assert_almost_eq(colour.a, 1.0, EPS, kind + " 불투명")
			for c: float in [colour.r, colour.g, colour.b]:
				assert_true(is_finite(c) and c >= -EPS and c <= 1.0 + EPS, kind + " 정점색 범위")
			if colour.r > 0.99 and colour.g > 0.99 and colour.b > 0.99:
				pale += 1
		assert_lt(pale, colours.size(), kind + " 정점색이 모두 흰색이면 색을 잃은 것")
		# The colours that came in are the ones painted: the mean near the intended one, as many groups as paints.
		var mean := sum / maxf(float(colours.size()), 1.0)
		var intended: Array = row.get("intended_mean_rgb", [])
		assert_eq(intended.size(), 3, kind + " 칠한 평균 기록")
		if intended.size() == 3:
			for c in 3:
				assert_almost_eq(mean[c], float(intended[c]), 0.06, kind + " 정점색 평균이 칠한 값")
		assert_gte(groups.size(), int(row.get("paint_count", 1)), kind + " 칠 갈래 수")
		root.free()

