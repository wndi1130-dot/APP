extends "res://addons/gut/test.gd"
## 방 가구 16종. .import는 이 묶음을 받는 Godot 세션에서 만든다.
const PropKinds = preload("res://game/world/prop_kinds.gd")
const KIT_DIR := "res://models/props_field"
const EXPECTED_TEXT := "dresser chair nightstand counter sink cupboard settee armchair low_table side_table toilet washstand bathtub towel_shelf medicine_cabinet waste_bin"
const HEIGHTS := {
	"dresser": 1.0, "chair": 0.85, "nightstand": 0.55, "counter": 0.9,
	"sink": 0.9, "cupboard": 1.8, "settee": 0.85, "armchair": 0.9,
	"low_table": 0.45, "side_table": 0.6, "toilet": 0.65, "washstand": 0.85,
	"bathtub": 0.6, "towel_shelf": 1.6, "medicine_cabinet": 1.75, "waste_bin": 0.45,
}
const WIDE_KINDS := ["dresser", "settee", "bathtub"]
const EPS := 0.0001


func _assets() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(KIT_DIR + "/catalog_room.json"))
	return parsed.get("assets", {}) if parsed is Dictionary else {}


func test_catalog_names_equal_the_sixteen_room_kinds() -> void:
	var assets := _assets()
	assert_eq(assets.size(), 16, "빈 장부나 일부 생성은 통과하지 않음")
	var expected: PackedStringArray = EXPECTED_TEXT.split(" ", false)
	var listed: PackedStringArray = PackedStringArray(assets.keys())
	expected.sort()
	listed.sort()
	assert_eq(listed, expected)
	var made: PackedStringArray = []
	for filename: String in DirAccess.get_files_at(KIT_DIR):
		if filename.get_extension() == "glb" and filename.get_basename() in expected:
			made.append(filename.get_basename())
	made.sort()
	assert_eq(made, expected, "room GLB 집합")
	for id: String in expected:
		assert_eq(PropKinds.model_path(id), KIT_DIR + "/" + id + ".glb", id + " is found by its kind")


func test_every_entry_has_glb_import_and_matching_digest() -> void:
	var assets := _assets()
	assert_false(assets.is_empty())
	for id: String in assets:
		var asset: Dictionary = assets[id]
		var path := KIT_DIR + "/" + id + ".glb"
		assert_eq(str(asset.get("path", "")), path, id)
		assert_eq(str(asset.get("status", "")), "ready", id + " bake completed")
		assert_true(FileAccess.file_exists(path), id + " glb")
		assert_true(FileAccess.file_exists(path + ".import"), id + " import")
		assert_eq(str(asset.get("source_credit", "")), "Kenney Furniture Kit 2.0, CC0", id)
		assert_false(str(asset.get("source_name", "")).is_empty(), id + " source")
		if not FileAccess.file_exists(path):
			continue
		assert_eq(FileAccess.get_sha256(path), str(asset.get("sha256", "")), id + " SHA-256")
		var file := FileAccess.open(path, FileAccess.READ)
		assert_eq(file.get_length(), int(asset.get("bytes", 0)), id + " bytes")
		file.close()


func test_every_prop_stays_within_700_triangles_and_96_percent_footprint() -> void:
	var assets := _assets()
	assert_false(assets.is_empty())
	for id: String in assets:
		var asset: Dictionary = assets[id]
		assert_eq(str(asset.get("status", "")), "ready", id)
		if asset.get("status") != "ready":
			continue
		assert_gt(int(asset.get("lod0_tris", 0)), 0, id)
		assert_lte(int(asset.get("lod0_tris", 99999)), 700, id)
		assert_eq(int(asset.get("triangle_limit", 0)), 700, id)
		var size: Array = asset.get("dimensions_m", [])
		var cells: Array = asset.get("footprint_m", [])
		var bounds: Array = asset.get("bounds_m", [])
		assert_eq(size.size(), 3, id + " dimensions")
		assert_eq(cells.size(), 2, id + " footprint")
		assert_eq(bounds.size(), 2, id + " bounds")
		if size.size() != 3 or cells.size() != 2 or bounds.size() != 2:
			continue
		assert_eq(int(cells[0]), 2 if id in WIDE_KINDS else 1, id + " expected width")
		assert_eq(int(cells[1]), 1, id + " expected depth")
		assert_lte(float(size[0]), float(cells[0]) * 0.96 + EPS, id + " within width")
		assert_lte(float(size[2]), float(cells[1]) * 0.96 + EPS, id + " within depth")
		assert_almost_eq(float(bounds[0][0]) + float(bounds[1][0]), 0.0, EPS, id + " centered X")
		assert_almost_eq(float(bounds[0][2]) + float(bounds[1][2]), 0.0, EPS, id + " centered Z")
		assert_almost_eq(float(bounds[1][1]), float(HEIGHTS[id]), EPS, id + " top elevation")
		assert_almost_eq(float(bounds[0][1]), 1.15 if id == "medicine_cabinet" else 0.0, EPS, id + " bottom elevation")
		if id in WIDE_KINDS:
			assert_gt(float(size[0]), float(size[2]), id + " long side X")
		if id == "medicine_cabinet":
			assert_almost_eq(float(size[1]), 0.6, EPS, "wall cabinet is 60 cm tall")
			assert_lte(float(size[2]), 0.24, "wall cabinet stays shallow")


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


func test_imported_mesh_has_one_surface_colours_and_measured_bounds() -> void:
	var assets := _assets()
	assert_eq(assets.size(), 16)
	for id: String in assets:
		var path := KIT_DIR + "/" + id + ".glb"
		if assets[id].get("status") != "ready" or not FileAccess.file_exists(path + ".import"):
			assert_true(false, id + " requires a completed bake and caller's import")
			continue
		var packed := load(path) as PackedScene
		assert_not_null(packed, id)
		if packed == null:
			continue
		var root := packed.instantiate()
		var nodes: Array[MeshInstance3D] = []
		_mesh_nodes(root, nodes)
		assert_eq(nodes.size(), 1, id + " one mesh node")
		if nodes.size() != 1 or nodes[0].mesh == null:
			root.free()
			continue
		var mesh := nodes[0].mesh
		assert_eq(mesh.get_surface_count(), 1, id + " one surface")
		if mesh.get_surface_count() != 1:
			root.free()
			continue
		assert_eq(mesh.surface_get_primitive_type(0), Mesh.PRIMITIVE_TRIANGLES, id)
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		assert_gt(vertices.size(), 0, id)
		assert_eq(colours.size(), vertices.size(), id + " actual vertex colours")
		var index_count := indices.size() if not indices.is_empty() else vertices.size()
		var tris := int(index_count / 3)
		assert_eq(index_count % 3, 0, id)
		assert_eq(tris, int(assets[id]["lod0_tris"]), id + " actual triangles")
		assert_lte(tris, 700, id)
		var measured := _model_transform(nodes[0]) * mesh.get_aabb()
		var bounds: Array = assets[id]["bounds_m"]
		for axis: int in range(3):
			assert_almost_eq(measured.position[axis], float(bounds[0][axis]), EPS, id + " actual minimum")
			assert_almost_eq(measured.end[axis], float(bounds[1][axis]), EPS, id + " actual maximum")
		for colour: Color in colours:
			assert_almost_eq(colour.a, 1.0, EPS, id + " opaque colour")
		root.free()
