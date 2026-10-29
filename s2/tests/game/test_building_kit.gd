extends "res://addons/gut/test.gd"
## 건물 조각 키트: 블렌더 스크립트(tools/blender/building_kit.py)가 쓴 대응표와
## 가져온 메시가 서로 맞는지, 조각이 지도 격자의 약속(칸 1 m, 층 높이, 턱 높이,
## 바깥은 +Z)을 지키는지, 정점 색에 칠 구역 비트만 들었는지 본다.

const MapView = preload("res://game/world/map_view.gd")
const KIT_DIR := "res://models/building_kit"
const CATALOG_PATH := "res://models/building_kit/catalog.json"
## 가져오며 정점 위치가 16비트로 줄어든다. 10 m 지붕에서도 이 안쪽이다.
const EPS := 0.002
var _book: Dictionary = {}


func _catalog() -> Dictionary:
	if _book.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		_book = parsed if parsed is Dictionary else {}
	return _book


func _asset(id: String) -> Dictionary:
	return _catalog()["assets"][id]


## 조각 하나의 메시와 노드 변환 목록
func _meshes(id: String) -> Array:
	var rows: Array = []
	var scene := load(_asset(id)["path"]) as PackedScene
	if scene == null:
		return rows
	var root := scene.instantiate()
	_collect(root, Transform3D.IDENTITY, rows)
	root.free()
	return rows


static func _collect(node: Node, parent: Transform3D, rows: Array) -> void:
	var transform: Transform3D = parent * node.transform if node is Node3D else parent
	if node is MeshInstance3D and node.mesh != null:
		rows.append({"mesh": node.mesh, "transform": transform})
	for child in node.get_children():
		_collect(child, transform, rows)


## 삼각형마다 꼭짓점 셋, 정점 법선, 정점 색(꼭짓점 셋 모두)
func _triangles(id: String) -> Array:
	var out: Array = []
	for row in _meshes(id):
		var mesh: Mesh = row["mesh"]
		var transform: Transform3D = row["transform"]
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for i in vertices.size():
					indices.append(i)
			for i in range(0, indices.size(), 3):
				var corner := [indices[i], indices[i + 1], indices[i + 2]]
				var tri := {"p": [], "colours": [], "normal": Vector3.ZERO}
				for k: int in corner:
					tri["p"].append(transform * vertices[k])
					tri["colours"].append(colours[k] if not colours.is_empty() else Color(-1, -1, -1, -1))
					if not normals.is_empty():
						tri["normal"] += transform.basis * normals[k]
				tri["normal"] = (tri["normal"] as Vector3).normalized()
				out.append(tri)
	return out


func _bounds(id: String) -> AABB:
	var box := AABB()
	var first := true
	for tri in _triangles(id):
		for p: Vector3 in tri["p"]:
			if first:
				box = AABB(p, Vector3.ZERO)
				first = false
			else:
				box = box.expand(p)
	return box


static func _zone(c: Color) -> int:
	return int(roundf(c.r)) + 2 * int(roundf(c.g)) + 4 * int(roundf(c.b))


func test_catalog_lists_exactly_the_kit_files_with_matching_bytes() -> void:
	assert_false(_catalog().is_empty(), "대응표를 읽지 못함")
	var on_disk: Array = []
	for file in DirAccess.get_files_at(KIT_DIR):
		if file.get_extension() == "glb":
			on_disk.append(file.get_basename())
	on_disk.sort()
	var listed: Array = _catalog()["assets"].keys()
	listed.sort()
	assert_eq(listed, on_disk, "대응표의 조각과 폴더의 glb가 같아야 함")
	for id: String in listed:
		var asset := _asset(id)
		assert_eq(asset["status"], "ready", "%s 상태" % id)
		assert_eq(asset["path"], "%s/%s.glb" % [KIT_DIR, id], "%s 경로" % id)
		assert_true(ResourceLoader.exists(asset["path"]), "%s 가져온 자원 없음" % id)
		var file := FileAccess.open(asset["path"], FileAccess.READ)
		assert_eq(file.get_length(), int(asset["bytes"]), "%s 바이트" % id)
		assert_eq(FileAccess.get_sha256(asset["path"]), asset["sha256"], "%s sha256" % id)


func test_imported_triangles_match_catalog_under_limits_in_one_surface() -> void:
	for id: String in _catalog()["assets"]:
		var asset := _asset(id)
		var surfaces := 0
		for row in _meshes(id):
			surfaces += (row["mesh"] as Mesh).get_surface_count()
		assert_eq(surfaces, 1, "%s는 그리기 한 번(면 묶음 하나)" % id)
		var tris := _triangles(id).size()
		assert_eq(tris, int(asset["lod0_tris"]), "%s 삼각형 수가 대응표와 같아야 함" % id)
		assert_lte(tris, int(asset["triangle_limit"]), "%s 삼각형 상한" % id)
		assert_lte(int(asset["triangle_limit"]), 300, "%s 상한은 조각당 300 아래" % id)


func test_imported_bounds_match_catalog() -> void:
	for id: String in _catalog()["assets"]:
		var box := _bounds(id)
		var want: Array = _asset(id)["bounds_m"]
		for axis in 3:
			assert_almost_eq(box.position[axis], float(want[0][axis]), EPS, "%s 최소 %d축" % [id, axis])
			assert_almost_eq(box.end[axis], float(want[1][axis]), EPS, "%s 최대 %d축" % [id, axis])


func test_pieces_keep_grid_heights_spans_and_cell_footprint() -> void:
	for id: String in _catalog()["assets"]:
		var asset := _asset(id)
		var box := _bounds(id)
		match asset["height"]:
			"full":
				assert_almost_eq(box.position.y, 0.0, EPS, "%s 바닥에 섬" % id)
				assert_almost_eq(box.end.y, MapView.LEVEL_H, EPS, "%s 층 높이까지" % id)
			"cut":
				assert_almost_eq(box.position.y, 0.0, EPS, "%s 바닥에 섬" % id)
				assert_almost_eq(box.end.y, MapView.CUT_H, EPS, "%s 턱 높이까지" % id)
		if asset["stretch"] in ["x", "xy"]:
			assert_almost_eq(box.position.x, -0.5, EPS, "%s 늘림 조각은 칸 끝에서 시작" % id)
			assert_almost_eq(box.end.x, 0.5, EPS, "%s 늘림 조각은 칸 끝에서 끝남" % id)
		if asset["fits_cell"]:
			for axis in [0, 2]:
				assert_gte(box.position[axis], -0.5 - EPS, "%s 칸 밖으로 나감" % id)
				assert_lte(box.end[axis], 0.5 + EPS, "%s 칸 밖으로 나감" % id)
		if asset["origin"] == "cell_floor":
			assert_gte(box.position.y, -EPS, "%s 바닥 아래로 내려감" % id)


func test_vertex_colours_hold_only_zone_bits_and_weather_flag() -> void:
	# 장부에 있는 구역 번호만(6은 building_view의 커튼 몫이라 조각엔 없고, 지붕 덮개 cap은 7).
	var known: Array = (_catalog()["zones"] as Dictionary).values().map(func(z: Variant) -> int: return int(z))
	for id: String in _catalog()["assets"]:
		var seen: Dictionary = {}
		var bad := 0
		for tri in _triangles(id):
			for c: Color in tri["colours"]:
				for v in [c.r, c.g, c.b, c.a]:
					if absf(v) > 0.01 and absf(v - 1.0) > 0.01:
						bad += 1
				seen[_zone(c)] = true
		assert_eq(bad, 0, "%s 정점 색은 0 또는 1만" % id)
		var zones: Array = seen.keys()
		zones.sort()
		assert_eq(zones, (_asset(id)["zones"] as Array).map(func(z: Variant) -> int: return int(z)), "%s 칠 구역" % id)
		for z: int in zones:
			assert_true(known.has(z), "%s 구역 번호 %d" % [id, z])


func test_every_face_winds_toward_its_normal() -> void:
	# Godot 메시는 시계 방향이 앞면이라, 꼭짓점 차례로 낸 법선이 정점 법선과 반대쪽이다.
	for id: String in _catalog()["assets"]:
		var flat := 0
		var wrong := 0
		for tri in _triangles(id):
			var p: Array = tri["p"]
			var wound: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
			if wound.length() < 1e-6:
				flat += 1
			elif wound.normalized().dot(tri["normal"]) > -0.95:
				wrong += 1
		assert_eq(flat, 0, "%s 넓이 없는 삼각형" % id)
		assert_eq(wrong, 0, "%s 감김과 법선이 어긋난 삼각형" % id)


func test_exposed_faces_of_outer_pieces_never_face_inward() -> void:
	for id: String in _catalog()["assets"]:
		# 바깥 조각(ext_)만 본다. 안벽·안문·상태 조각은 날씨를 받지 않는다.
		if not id.begins_with("ext_"):
			continue
		var inward := 0
		var exposed := 0
		for tri in _triangles(id):
			if (tri["colours"][0] as Color).a > 0.5:
				exposed += 1
				if (tri["normal"] as Vector3).z < -0.01:
					inward += 1
		assert_gt(exposed, 0, "%s 날씨 받는 면이 있어야 함" % id)
		assert_eq(inward, 0, "%s 날씨 받는 면이 안쪽(-Z)을 봄" % id)


func test_roof_keeps_pitch_and_gable_end_stays_under_it() -> void:
	var roof: Dictionary = _catalog()["roof"]
	var pitch := deg_to_rad(float(roof["pitch_deg"]))
	var slopes := 0
	for tri in _triangles("roof_gable"):
		if _zone(tri["colours"][0]) == int(_catalog()["zones"]["roof"]):
			slopes += 1
			assert_almost_eq((tri["normal"] as Vector3).angle_to(Vector3.UP), pitch, deg_to_rad(0.5), "지붕 경사")
	assert_eq(slopes, 4, "지붕 경사면은 둘(삼각형 넷)")
	var gable := _bounds("roof_gable_end")
	var top := _bounds("roof_gable")
	var half := float(roof["nominal_span_m"]) / 2.0
	assert_lt(gable.end.y, float(roof["rise_m"]), "박공 끝 벽은 용마루 아래")
	assert_lt(gable.end.x, half, "박공 끝 벽은 처마 안쪽")
	assert_almost_eq(top.end.z, half + float(roof["eave_m"]), EPS, "처마 내밈")
	# 박공 끝 벽 위 두 변이 지붕 밑면과 같은 경사여야 틈이 없다
	assert_almost_eq(atan2(gable.end.y, gable.end.x), pitch, deg_to_rad(0.5), "박공 끝 벽 경사")


func test_board_slots_stay_inside_their_opening() -> void:
	var grid: Dictionary = _catalog()["grid"]
	var openings := {
		"window": ["window_boards", float(grid["sill_m"]), float(grid["head_m"])],
		"door": ["door_boards", 0.0, float(grid["door_m"][1])],
	}
	for kind: String in openings:
		var piece: String = openings[kind][0]
		var board := _bounds(piece)
		var slots: Array = _catalog()["board_slots"][kind]
		assert_eq(slots.size(), 3, "%s 판자는 세 장까지" % kind)
		for slot: Dictionary in slots:
			var turn := Transform3D(Basis(Vector3.BACK, deg_to_rad(float(slot["roll_deg"]))), Vector3(0, float(slot["height_m"]), 0))
			for i in 8:
				var corner: Vector3 = turn * board.get_endpoint(i)
				assert_lte(absf(corner.x), 0.5 + EPS, "%s 판자가 칸 옆으로 나감" % kind)
				assert_gte(corner.y, float(openings[kind][1]) - EPS, "%s 판자가 구멍 아래로 나감" % kind)
				assert_lte(corner.y, float(openings[kind][2]) + EPS, "%s 판자가 구멍 위로 나감" % kind)
