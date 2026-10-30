extends "res://addons/gut/test.gd"
## 굽기 뒤의 실제 GLB JSON과 장부를 대조하고, 가구 칠 판을 확인한다.
## --only 장부도 검사하되 관측 rect와 표본 없는 세 종의 가정을 구분한다.

const KIT_DIR: String = "res://models/props_stop01"
const FurnitureTints = preload("res://game/world/furniture_tints.gd")
const PropModels = preload("res://game/world/prop_models.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")
const BUDGETS: Dictionary = {
	"workbench": 500, "bookcase": 700, "drawer_chest_spilled": 700,
	"shop_shelf": 500, "toolbox": 200, "office_desk": 600,
}
const SOURCES: Dictionary = {
	"wardrobe": ["poly_haven"], "dining_set": ["poly_haven"], "table_overturned": ["poly_haven"],
	"workbench": ["blender_primitives"], "shop_shelf": ["blender_primitives"],
	"toolbox": ["blender_primitives"], "iron_bed": ["blender_primitives"],
	"bookcase": ["poly_haven", "blender_primitives"],
	"office_desk": ["poly_haven", "blender_primitives"],
	"drawer_chest_spilled": ["poly_haven", "blender_primitives"],
}
const EXPECTED: Array[String] = [
	"wardrobe", "shop_shelf", "bookcase", "dining_set", "table_overturned",
	"workbench", "office_desk", "iron_bed", "drawer_chest_spilled", "toolbox",
]
const FALLBACK_RECTS: Dictionary = {
	"table_overturned": [1, 2], "drawer_chest_spilled": [1, 1], "toolbox": [1, 1],
}
const EPSILON: float = 0.0001


func _catalog() -> Dictionary:
	var path: String = KIT_DIR + "/catalog_cc0.json"
	assert_true(FileAccess.file_exists(path), "굽기 스크립트가 만든 catalog_cc0.json")
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, "CC0 장부 JSON")
	if not parsed is Dictionary:
		return {}
	var book: Dictionary = parsed
	return book


func _read_glb(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, path)
	if file == null:
		return {}
	var length: int = file.get_length()
	assert_gte(length, 20, path + " GLB header length")
	if length < 20:
		file.close()
		return {}
	assert_eq(file.get_buffer(4).get_string_from_ascii(), "glTF", path + " magic")
	assert_eq(file.get_32(), 2, path + " version")
	assert_eq(file.get_32(), length, path + " total bytes")
	var json_length: int = file.get_32()
	var chunk_type: int = file.get_32()
	assert_eq(chunk_type, 0x4e4f534a, path + " JSON chunk")
	assert_lte(json_length, length - 20, path + " JSON length")
	if chunk_type != 0x4e4f534a or json_length > length - 20:
		file.close()
		return {}
	var parsed: Variant = JSON.parse_string(file.get_buffer(json_length).get_string_from_utf8())
	file.close()
	assert_true(parsed is Dictionary, path + " GLB JSON")
	if not parsed is Dictionary:
		return {}
	var doc: Dictionary = parsed
	return doc


func _accessor(doc: Dictionary, index: int, label: String) -> Dictionary:
	var accessors: Array = doc.get("accessors", [])
	assert_true(index >= 0 and index < accessors.size(), label + " accessor index")
	if index < 0 or index >= accessors.size():
		return {}
	var value: Dictionary = accessors[index]
	return value


func test_catalog_scope_and_partial_status() -> void:
	var book: Dictionary = _catalog()
	var assets: Dictionary = book.get("assets", {})
	assert_gt(assets.size(), 0, "빈 장부는 완료가 아님")
	assert_eq(int(book.get("schema_version", -1)), 1)
	assert_eq(int(book.get("triangle_limit", -1)), 700)
	var missing: Array[String] = []
	for kind: String in EXPECTED:
		if not assets.has(kind):
			missing.append(kind)
	missing.sort()
	var recorded: Array = book.get("missing", [])
	assert_eq(recorded, missing, "--only 미생성 종류를 숨기지 않음")
	var pending: Array[String] = []
	for kind: String in assets:
		assert_true(kind in EXPECTED, kind + " 허용된 열 종")
		var row: Dictionary = assets[kind]
		if String(row.get("bake_status", "")) == "pending":
			pending.append(kind)
			for key: String in ["lod0_tris", "bytes", "sha256"]:
				assert_true(row.has(key), kind + " 재굽기 뒤 채울 키")
				assert_null(row.get(key), kind + " 이전 수치를 새 결과로 쓰지 않음")
			var previous: Dictionary = row.get("previous_bake", {})
			assert_eq(FileAccess.get_sha256(KIT_DIR + "/" + kind + ".glb"),
				String(previous.get("sha256", "")), kind + " 이전 GLB 영수증 보존")
	pending.sort()
	assert_eq(book.get("pending", []), pending)
	assert_eq(bool(book.get("complete", false)), missing.is_empty() and pending.is_empty())


func test_catalog_sources_and_size_contract() -> void:
	var assets: Dictionary = _catalog().get("assets", {})
	for kind: String in assets:
		var entry: Dictionary = assets[kind]
		var source: Variant = entry.get("source", "")
		var sources: Array = source if source is Array else [source]
		assert_eq(sources, SOURCES.get(kind, []), kind + " 실제 재료별 출처")
		var ids: Array = entry.get("source_ids", [])
		var parts: Array = entry.get("primitive_parts", [])
		assert_eq(not ids.is_empty(), sources.has("poly_haven"), kind + " 외부 원본 목록")
		assert_eq(not parts.is_empty(), sources.has("blender_primitives"), kind + " 기본 도형 목록")
		assert_eq(entry.get("size_m", []), entry.get("chosen_size_m", []), kind + " 기존 크기 보존")
		assert_eq(int(entry.get("triangle_limit", -1)), int(BUDGETS.get(kind, 700)), kind + " 종별 예산")


func test_catalog_body_press_is_recorded_for_six_kinds() -> void:
	var book: Dictionary = _catalog()
	var press: Dictionary = book.get("body_press", {})
	var assets: Dictionary = book.get("assets", {})
	assert_eq(press.size(), 6)
	assert_eq(String(book.get("body_press_basis", "")), "srgb_hsv_after_existing_palette_tint_body_only")
	for kind: String in ["wardrobe", "dining_set", "table_overturned", "office_desk", "bookcase", "drawer_chest_spilled"]:
		assert_true(press.has(kind), kind + " 색 억제 표")
		var knobs: Dictionary = press.get(kind, {})
		assert_almost_eq(float(knobs.get("saturation", -1.0)), 0.60, EPSILON)
		assert_almost_eq(float(knobs.get("value", -1.0)), 0.85, EPSILON)
		if assets.has(kind):
			assert_eq(assets[kind].get("body_press"), knobs, kind + " 종별 장부에도 기록")
	for kind: String in ["workbench", "shop_shelf", "toolbox", "iron_bed"]:
		assert_false(press.has(kind), kind + " 새 팔레트·유지 대상은 중복 억제하지 않음")


func test_files_geometry_colours_bounds_and_hashes_match_catalog() -> void:
	var book: Dictionary = _catalog()
	var assets: Dictionary = book.get("assets", {})
	assert_gt(assets.size(), 0)
	assert_eq(book.get("pending", []), [], "2차 GLB 재굽기 필요: 미굽기는 완료가 아님")
	for kind: String in assets:
		var entry: Dictionary = assets[kind]
		if String(entry.get("bake_status", "")) == "pending":
			continue
		var path: String = KIT_DIR + "/" + kind + ".glb"
		assert_eq(String(entry.get("path", "")), path, kind + " 같은 파일 이름")
		assert_true(FileAccess.file_exists(path), kind + " 파일")
		if not FileAccess.file_exists(path):
			continue
		assert_eq(FileAccess.get_sha256(path), String(entry.get("sha256", "")), kind + " SHA-256")
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		assert_not_null(file, kind)
		if file == null:
			continue
		assert_eq(file.get_length(), int(entry.get("bytes", -1)), kind + " bytes")
		file.close()
		var doc: Dictionary = _read_glb(path)
		if doc.is_empty():
			continue
		var meshes: Array = doc.get("meshes", [])
		assert_eq(meshes.size(), 1, kind + " 단일 메시·LOD0")
		if meshes.size() != 1:
			continue
		var nodes: Array = doc.get("nodes", [])
		var mesh_nodes: int = 0
		for node: Dictionary in nodes:
			if node.has("mesh"):
				mesh_nodes += 1
				assert_eq(int(node["mesh"]), 0, kind + " mesh index")
			for transform_key: String in ["matrix", "translation", "rotation", "scale"]:
				assert_false(node.has(transform_key), kind + " 경계 밖 노드 변환 없음")
		assert_eq(mesh_nodes, 1, kind + " 메시 인스턴스 하나")
		var mesh: Dictionary = meshes[0]
		var primitives: Array = mesh.get("primitives", [])
		assert_eq(primitives.size(), 1, kind + " 단일 surface")
		if primitives.size() != 1:
			continue
		var primitive: Dictionary = primitives[0]
		assert_eq(int(primitive.get("mode", 4)), 4, kind + " TRIANGLES")
		assert_false(primitive.has("material"), kind + " 재질 참조 없음")
		for resource_key: String in ["images", "textures", "materials", "animations", "skins"]:
			var resources: Array = doc.get(resource_key, [])
			assert_eq(resources.size(), 0, kind + " " + resource_key)
		var buffers: Array = doc.get("buffers", [])
		for buffer: Dictionary in buffers:
			assert_false(buffer.has("uri"), kind + " 외부 자원 없음")
		var attributes: Dictionary = primitive.get("attributes", {})
		assert_true(attributes.has("COLOR_0"), kind + " Col")
		assert_true(attributes.has("POSITION"), kind + " 위치")
		for attribute: String in attributes:
			assert_false(attribute.begins_with("TEXCOORD_"), kind + " UV 없음")
		var colour: Dictionary = _accessor(doc, int(attributes.get("COLOR_0", -1)), kind + " colour")
		assert_eq(String(colour.get("type", "")), "VEC4", kind + " 색 갈래 알파 보존")
		var position: Dictionary = _accessor(doc, int(attributes.get("POSITION", -1)), kind + " position")
		assert_eq(int(colour.get("count", -1)), int(position.get("count", -2)), kind + " 위치·색 수")
		var indices: Dictionary = _accessor(doc, int(primitive.get("indices", -1)), kind + " indices")
		var index_count: int = int(indices.get("count", 0))
		assert_eq(String(indices.get("type", "")), "SCALAR")
		assert_eq(index_count % 3, 0, kind + " 삼각형 인덱스")
		var triangles: int = int(index_count / 3.0)
		assert_gt(triangles, 0, kind)
		assert_lte(triangles, int(BUDGETS.get(kind, 700)), kind + " 면 예산")
		assert_eq(triangles, int(entry.get("lod0_tris", -1)), kind + " 장부 삼각형")
		_check_bounds(kind, entry, position)
		var counts: Dictionary = entry.get("mask_counts", {})
		var ratios: Dictionary = entry.get("mask_ratio", {})
		var total: int = 0
		var ratio_sum: float = 0.0
		for mask: String in ["body", "trim", "keep"]:
			var count: int = int(counts.get(mask, -1))
			var ratio: float = float(ratios.get(mask, -1.0))
			assert_gte(count, 0, kind + " mask count")
			assert_gte(ratio, 0.0, kind + " mask ratio")
			if index_count > 0:
				assert_almost_eq(ratio, float(count) / float(index_count), EPSILON, kind + " mask ratio/count")
			total += count
			ratio_sum += ratio
		assert_eq(total, index_count, kind + " 삼각형 코너 기준 마스크")
		assert_almost_eq(ratio_sum, 1.0, EPSILON, kind + " 마스크 비율 합")
		assert_true(bool(entry.get("mask_alpha_verified", false)), kind + " 굽기 때 알파 바이트 대조")


func _check_bounds(kind: String, entry: Dictionary, position: Dictionary) -> void:
	var lo: Array = position.get("min", [])
	var hi: Array = position.get("max", [])
	var bounds: Array = entry.get("bounds_m", [])
	var rect: Array = entry.get("rect_fit_m", [])
	assert_eq(lo.size(), 3, kind + " POSITION.min")
	assert_eq(hi.size(), 3, kind + " POSITION.max")
	assert_eq(bounds.size(), 2, kind + " 장부 경계")
	assert_eq(rect.size(), 2, kind + " rect")
	if lo.size() != 3 or hi.size() != 3 or bounds.size() != 2 or rect.size() != 2:
		return
	var modal: Variant = entry.get("rect_modal")
	if modal is Array:
		var observed: Array = modal
		assert_eq(rect, observed, kind + " 관측 최빈 rect 사용")
		assert_gt(int(entry.get("rect_modal_count", 0)), 0, kind + " 최빈 빈도")
	else:
		assert_null(modal, kind + " 표본 없는 항목의 최빈값은 null")
		assert_true(FALLBACK_RECTS.has(kind), kind + " 허용된 크기 가정")
		# JSON 숫자는 float로 읽히므로 칸 수는 정수로 바꿔 견준다.
		assert_eq(rect.map(func(v): return int(v)), FALLBACK_RECTS.get(kind, []), kind + " 명시된 가정 rect")
		assert_eq(int(entry.get("rect_samples", -1)), 0, kind + " 관측과 가정 구분")
		assert_eq(String(entry.get("rect_basis", "")), "assumed_no_rect_samples")
	for i: int in range(3):
		assert_almost_eq(float(bounds[0][i]), float(lo[i]), EPSILON, kind + " 최소 경계")
		assert_almost_eq(float(bounds[1][i]), float(hi[i]), EPSILON, kind + " 최대 경계")
	assert_gt(float(rect[0]), 0.0)
	assert_gt(float(rect[1]), 0.0)
	assert_lte(float(hi[0]) - float(lo[0]), float(rect[0]) * 0.96 + EPSILON, kind + " rect 가로 96%")
	assert_lte(float(hi[2]) - float(lo[2]), float(rect[1]) * 0.96 + EPSILON, kind + " rect 깊이 96%")
	var height: float = float(hi[1]) - float(lo[1])
	assert_gte(height, 0.3, kind + " 최소 높이")
	assert_lte(height, 2.1, kind + " 최대 높이")
	assert_almost_eq(height, float(entry.get("height_m", -1.0)), EPSILON, kind + " 장부 높이")
	assert_almost_eq(float(lo[1]), 0.0, EPSILON, kind + " 바닥 y=0")
	assert_almost_eq(float(lo[0]) + float(hi[0]), 0.0, EPSILON, kind + " 가로 가운데")
	assert_almost_eq(float(lo[2]) + float(hi[2]), 0.0, EPSILON, kind + " 깊이 가운데")


func test_furniture_tint_sets_are_four_muted_srgb_pairs() -> void:
	assert_eq(FurnitureTints.SETS.size(), 4, "한 집 칠 판 네 벌")
	for palette: Dictionary in FurnitureTints.SETS:
		assert_eq(palette.size(), 2)
		for key: String in ["body", "trim"]:
			assert_true(palette.get(key) is Color, key + " sRGB 색")
			if not palette.get(key) is Color:
				continue
			var colour: Color = palette[key]
			assert_lt(colour.s, 0.45, key + " 채도")
			assert_lt(colour.v, 0.75, key + " 밝기")
			assert_almost_eq(colour.a, 1.0, EPSILON, key + " 기본 칠 세기")


func test_furniture_tint_pick_obeys_explicit_index_first() -> void:
	for tint: int in [-9, -1, 0, 3, 4, 7, 12]:
		var expected: int = posmod(tint, 4)
		assert_eq(FurnitureTints.pick({"tint": tint, "building": 83}, Vector2i(2, 9)), expected)
		assert_eq(FurnitureTints.pick({"tint": tint, "building": 0}, Vector2i(-7, -3)), expected)


func test_furniture_tint_pick_keeps_a_building_together() -> void:
	var seen: Dictionary = {}
	# building -1(건물 밖)은 건물이 없는 줄과 같이 칸으로 고른다.
	assert_eq(FurnitureTints.pick({"building": -1}, Vector2i(18, -90)), FurnitureTints.pick({}, Vector2i(18, -90)))
	for building: int in [0, 1, 2, 7, 83, 129]:
		var expected: int = FurnitureTints.pick({"building": building}, Vector2i.ZERO)
		assert_gte(expected, 0)
		assert_lt(expected, 4)
		seen[expected] = true
		for cell: Vector2i in [Vector2i(-12, 5), Vector2i(18, -90), Vector2i(999, 3)]:
			assert_eq(FurnitureTints.pick({"building": building, "kind": "bookcase"}, cell), expected)
	assert_gt(seen.size(), 1, "건물 번호 해시가 상수가 아님")


func test_furniture_tint_pick_falls_back_to_repeatable_cells() -> void:
	var seen: Dictionary = {}
	for cell: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(-13, 29), Vector2i(31, -7)]:
		var expected: int = FurnitureTints.pick({}, cell)
		assert_gte(expected, 0)
		assert_lt(expected, 4)
		seen[expected] = true
		assert_eq(FurnitureTints.pick({}, cell), expected, "같은 칸 재호출")
		assert_eq(FurnitureTints.pick({"kind": "workbench"}, cell), expected, "무관한 열은 해시에 섞지 않음")
	assert_gt(seen.size(), 1, "칸 해시가 상수가 아님")


## 판 고르기(#985 점검 L3): 이어진 건물 번호도 판을 고르게 나눠 받는다. 해시를 그대로 자르면
## 판이 번호 차례대로 돌거나(아래 비트) 몇 채씩 몰린다(위 비트).
func test_furniture_tint_roll_spreads_neighbouring_buildings() -> void:
	for source: String in ["pick", "tint_for"]:
		var counts := [0, 0, 0, 0]
		var steps := 0
		var run := 0
		var longest := 0
		var last := -1
		for b in range(64):
			var t: int = FurnitureTints.pick({"building": b}, Vector2i.ZERO) if source == "pick" else RoomFurnish.tint_for("houses_01", b)
			counts[t] += 1
			run = run + 1 if t == last else 1
			longest = maxi(longest, run)
			if last >= 0 and t == posmod(last + 1, 4):
				steps += 1
			last = t
		for c: int in counts:
			assert_between(c, 8, 26, "%s 판마다 몫 %s" % [source, str(counts)])
		assert_lte(longest, 5, "%s 같은 판이 이어진 길이" % source)
		assert_lt(steps, 40, "%s 판이 번호 차례로 돌지 않음(+1 걸음 %d/63)" % [source, steps])


func test_furniture_tint_placed_building_and_batch_paths() -> void:
	# 줄에 building이 없으면 놓인 자리의 건물 번호로 줄의 building과 같은 판을 고른다.
	for building: int in [0, 5, 83]:
		assert_eq(FurnitureTints.pick({}, Vector2i(3, 4), building), FurnitureTints.pick({"building": building}, Vector2i(9, 9)))
	assert_eq(FurnitureTints.pick({"tint": 2}, Vector2i.ZERO, 5), 2, "tint가 건물보다 먼저")
	assert_true(FurnitureTints.applies("res://models/props_stop01/bookcase.glb"))
	assert_false(FurnitureTints.applies("res://models/props_stop01/barrel.glb"), "칠 마스크 없는 소품은 칠하지 않음")
	assert_false(FurnitureTints.applies("res://models/props_common/bookcase.glb"))


func test_furniture_tint_dress_loads_the_sets_on_the_batch_material() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://fx/shaders/weathered.gdshader")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v: Vector3 in [Vector3.ZERO, Vector3.RIGHT, Vector3.UP]:
		st.add_vertex(v)
	st.set_material(material)
	var mesh := st.commit()
	FurnitureTints.dress(mesh)
	assert_true(bool(material.get_shader_parameter("tint_from_custom")))
	var body: Array = material.get_shader_parameter("tint_sets_body")
	assert_eq(body.size(), 4)
	var first: Color = (FurnitureTints.SETS[0]["body"] as Color).srgb_to_linear()
	assert_almost_eq((body[0] as Vector4).x, first.r, 0.0001, "선형으로 옮긴 판 색")
	assert_almost_eq((body[0] as Vector4).w, FurnitureTints.BODY_STRENGTH, 0.0001)
	assert_eq(material.get_shader_parameter("tint_ref"), Vector2(0.18, 0.18), "칠 마스크 없는 메시는 예전 기준")


## 칠 밝기 기준(#985 점검 M3): 모형마다 몸체·테두리의 넓이 평균 밝기를 재어 재질에 싣는다.
## 예전 식(바탕 밝기 / 0.18)은 밝은 원목 모형을 흰색으로 띄우고 어두운 모형을 검게 눌렀다.
func test_furniture_paint_ref_is_each_models_own_mean() -> void:
	for kind: String in FurnitureTints.KINDS:
		var meshes := PropModels.batch_meshes("%s/%s.glb" % [KIT_DIR, kind])
		assert_true(meshes.has(0), kind + " 묶음 메시")
		if not meshes.has(0):
			continue
		var mesh: Mesh = meshes[0]
		var ref := FurnitureTints.paint_ref(mesh)
		assert_between(ref.x, 0.01, 1.0, kind + " 몸체 평균 밝기")
		assert_between(ref.y, 0.01, 1.0, kind + " 테두리 평균 밝기")
		FurnitureTints.dress(mesh)
		var material := mesh.surface_get_material(0) as ShaderMaterial
		assert_eq(material.get_shader_parameter("tint_ref"), ref, kind + " 재질에 실린 기준")
