extends "res://addons/gut/test.gd"
## 굽기/가져오기 뒤 실행한다. pending_bake는 완료로 인정하지 않는다.

const BOOK := "res://models/props_field/catalog_trees.json"
const KINDS := ["spruce_tall", "spruce_mid", "spruce_round", "spruce_young", "spruce_far", "birch_bare",
	"bush_juniper", "bush_dry", "fern_dry"]
const HEIGHTS := {"spruce_tall": 11.0, "spruce_mid": 7.5, "spruce_round": 6.0, "spruce_young": 2.6,
	"spruce_far": 9.0, "birch_bare": 7.0, "bush_juniper": 1.1, "bush_dry": 0.9, "fern_dry": 0.6}
const EPS := 0.001


func _book() -> Dictionary:
	var f := FileAccess.open(BOOK, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


func _assets() -> Dictionary:
	return _book().get("assets", {})


func _budget(id: String) -> Vector2i:
	if id.begins_with("spruce_far"):
		return Vector2i(80, 100)
	if id.begins_with("spruce_young"):
		return Vector2i(200, 400)
	if id.begins_with("spruce"):
		return Vector2i(400, 600)
	if id == "birch_bare":
		return Vector2i(1, 599)
	return Vector2i(1, 200)


func _bake_ready(row: Dictionary, id: String) -> bool:
	var ready: bool = row.get("status") == "ready"
	assert_true(ready, id + " requires caller bake; pending_bake is not a result")
	return ready


func _mesh_nodes(node: Node, into: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		into.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_mesh_nodes(child, into)


func _model_transform(node: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current := node
	while current != null:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


func _imported_data(row: Dictionary, id: String) -> Dictionary:
	if not _bake_ready(row, id):
		return {}
	var path := String(row["path"])
	if not FileAccess.file_exists(path + ".import"):
		assert_true(false, id + " requires caller Godot import")
		return {}
	var packed := load(path) as PackedScene
	assert_not_null(packed, id)
	if packed == null:
		return {}
	var root := packed.instantiate()
	var nodes: Array[MeshInstance3D] = []
	_mesh_nodes(root, nodes)
	assert_eq(nodes.size(), 1, id + " one mesh")
	if nodes.size() != 1 or nodes[0].mesh == null:
		root.free()
		return {}
	var mesh := nodes[0].mesh
	assert_eq(mesh.get_surface_count(), 1, id + " one surface")
	if mesh.get_surface_count() != 1:
		root.free()
		return {}
	assert_eq(mesh.surface_get_primitive_type(0), Mesh.PRIMITIVE_TRIANGLES, id)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_gt(vertices.size(), 0, id + " vertices")
	assert_eq(colours.size(), vertices.size(), id + " colours")
	assert_eq(normals.size(), vertices.size(), id + " normals")
	var transform := _model_transform(nodes[0])
	var result := {"colours": colours, "normals": normals,
		"normal_basis": transform.basis.inverse().transposed(),
		"faces": transform * mesh.get_faces(), "bounds": transform * mesh.get_aabb()}
	for colour: Color in colours:
		assert_almost_eq(colour.a, 1.0, EPS, id + " opaque")
	root.free()
	return result


func _luminance(colour: Color) -> float:
	return colour.r * 0.2126 + colour.g * 0.7152 + colour.b * 0.0722


func _triangle_keys(faces: PackedVector3Array) -> Array[String]:
	# 가져오기 때 정점 공유/순서가 바뀌어도 각 삼각형의 꼴로 비교한다.
	var keys: Array[String] = []
	for i: int in range(0, faces.size(), 3):
		var points := PackedStringArray()
		for offset: int in range(3):
			var p := faces[i + offset]
			points.append("%.5f,%.5f,%.5f" % [p.x, p.y, p.z])
		points.sort()
		keys.append("|".join(points))
	keys.sort()
	return keys


func test_every_kind_and_its_snow_twin_is_listed() -> void:
	var assets := _assets()
	assert_eq(assets.size(), 14, "기존 이름 열넷 유지")
	for kind: String in KINDS:
		assert_true(assets.has(kind), kind)
		if kind.begins_with("spruce"):
			assert_true(assets.has(kind + "_snow"), kind + "_snow")


func test_sources_paths_heights_and_budget_contract() -> void:
	var assets := _assets()
	assert_eq(assets.size(), 14)
	for id: String in assets:
		var row: Dictionary = assets[id]
		var base_id := id.trim_suffix("_snow")
		var expected_source := "quaternius_nature" if id.begins_with("spruce") or id == "birch_bare" else "kenney_nature_kit"
		assert_eq(String(row.get("source", "")), expected_source, id + " source")
		assert_eq(String(row["path"]), "res://models/props_field/" + id + ".glb", id + " path")
		assert_almost_eq(float(row["height_m"]), float(HEIGHTS[base_id]), EPS, id + " height")
		var budget := _budget(id)
		assert_eq(int(row["triangle_min"]), budget.x, id + " minimum")
		assert_eq(int(row["triangle_limit"]), budget.y, id + " maximum")
		if id.begins_with("spruce"):
			assert_true(String(row["source_asset"]).begins_with("PineTree_"), id + " pine source")
			assert_false(String(row["source_asset"]).contains("Snow"), id + " no snow-mass source")


func test_files_match_the_book() -> void:
	var assets := _assets()
	assert_eq(assets.size(), 14)
	for id: String in assets:
		var row: Dictionary = assets[id]
		if not _bake_ready(row, id):
			continue
		var path := String(row["path"])
		assert_true(FileAccess.file_exists(path), id + " glb")
		assert_true(FileAccess.file_exists(path + ".import"), id + " import")
		assert_eq(FileAccess.get_sha256(path), String(row["sha256"]), id + " 해시")
		var file := FileAccess.open(path, FileAccess.READ)
		assert_not_null(file, id + " file")
		if file != null:
			assert_eq(file.get_length(), int(row["bytes"]), id + " bytes")


func test_trees_stay_in_the_phone_budget() -> void:
	var assets := _assets()
	assert_eq(assets.size(), 14)
	for id: String in assets:
		var row: Dictionary = assets[id]
		var data := _imported_data(row, id)
		if data.is_empty():
			continue
		var faces: PackedVector3Array = data["faces"]
		assert_eq(faces.size() % 3, 0, id + " triangles")
		var tris := int(faces.size() / 3)
		assert_eq(tris, int(row["lod0_tris"]), id + " actual triangles")
		var budget := _budget(id)
		assert_gte(tris, budget.x, id + " minimum")
		assert_lte(tris, budget.y, id + " maximum")
		var box: AABB = data["bounds"]
		assert_almost_eq(box.position.y, 0.0, EPS, id + " base")
		assert_almost_eq(box.size.y, float(row["height_m"]), EPS, id + " actual height")


func test_snow_twins_have_the_same_geometry_and_triangle_count() -> void:
	var assets := _assets()
	for kind: String in KINDS:
		if not kind.begins_with("spruce"):
			continue
		var base: Dictionary = assets.get(kind, {})
		var snow: Dictionary = assets.get(kind + "_snow", {})
		var base_data := _imported_data(base, kind)
		var snow_data := _imported_data(snow, kind + "_snow")
		if base_data.is_empty() or snow_data.is_empty():
			continue
		assert_eq(base["lod0_tris"], snow["lod0_tris"], kind + " same tris")
		assert_eq(base["source_asset"], snow["source_asset"], kind + " same source")
		assert_eq(_triangle_keys(base_data["faces"]), _triangle_keys(snow_data["faces"]), kind + " same geometry")


func test_needles_are_dark_and_snow_is_only_on_upper_faces() -> void:
	var book := _book()
	var palette: Dictionary = book.get("palette", {})
	assert_true(palette.has("snow"), "snow colour required")
	if not palette.has("snow"):
		return
	var rgb: Array = palette["snow"]
	var snow_y := _luminance(Color(float(rgb[0]), float(rgb[1]), float(rgb[2])))
	assert_almost_eq(snow_y, 0.87294, EPS, "기존 눈 색 명도")
	var assets: Dictionary = book.get("assets", {})
	assert_eq(assets.size(), 14)
	for id: String in assets:
		if not id.begins_with("spruce"):
			continue
		var data := _imported_data(assets[id], id)
		if data.is_empty():
			continue
		var colours: PackedColorArray = data["colours"]
		var normals: PackedVector3Array = data["normals"]
		if colours.size() != normals.size():
			continue
		var normal_basis: Basis = data["normal_basis"]
		var dark_count := 0
		var snow_count := 0
		for i: int in range(colours.size()):
			var colour := colours[i]
			var y := _luminance(colour)
			if y > 0.08 + EPS:
				snow_count += 1
				assert_true(id.ends_with("_snow"), id + " no snow in base mesh")
				var up := (normal_basis * normals[i]).normalized().y
				assert_gt(up, 0.15 - EPS, id + " snow only on upward faces")
			elif colour.g > colour.r and colour.b > colour.r:
				dark_count += 1
				assert_gte(y, 0.04 - EPS, id + " needle minimum")
				assert_lte(y, 0.08 + EPS, id + " needle maximum")
				assert_lt(y, snow_y * 0.1, id + " needle below one tenth of snow luminance")
		assert_gt(dark_count, 0, id + " dark needles remain")
		if id.ends_with("_snow"):
			assert_gt(snow_count, 0, id + " upper snow exists")
			# 눈 짝도 바늘잎이 더 많이 남아 나무가 눈 덮인 땅보다 어둡게 읽힌다.
			assert_gt(float(dark_count) / float(dark_count + snow_count), 0.5, id + " dark needles outnumber snow")
