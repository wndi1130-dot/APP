extends SceneTree
## godot --headless --path s2 --script res://tools/props_common_check.gd
## 가져오기 완료 후 실행. 원본 장부와 실제 PackedScene/배치 메시를 함께 검사한다.

const PropModels = preload("res://game/world/prop_models.gd")
const CATALOG := "res://models/props_common/catalog.json"
const EXPECTED := [
	"shelf", "cold_stove", "desk", "barrel", "bed", "bare_tree",
	"crate_stack", "sack_pile", "file_cabinet", "part_crate", "handcart",
	"blanket_chest", "fridge_open", "iv_stand", "tool_chest", "paper_cart",
	"oxygen_cylinder", "pallet_stack",
]
const FLOOR_EPS := 0.001


func _initialize() -> void:
	call_deferred("_run")


func _mesh_info(mesh: Mesh, transform: Transform3D, info: Dictionary) -> void:
	info["meshes"] += 1
	for surface: int in range(mesh.get_surface_count()):
		info["surfaces"] += 1
		if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			info["valid"] = false
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: Variant = arrays[Mesh.ARRAY_COLOR]
		if not colors is PackedColorArray or colors.size() != vertices.size() or colors.is_empty():
			info["colors"] = false
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		var count: int = indices.size() if indices != null and not indices.is_empty() else vertices.size()
		if count % 3 != 0:
			info["valid"] = false
		info["triangles"] += count / 3
		for vertex: Vector3 in vertices:
			var point: Vector3 = transform * vertex
			if not point.is_finite():
				info["valid"] = false
			if not info["has_bounds"]:
				info["bounds"] = AABB(point, Vector3.ZERO)
				info["has_bounds"] = true
			else:
				info["bounds"] = info["bounds"].expand(point)


func _visit(node: Node, parent: Transform3D, info: Dictionary) -> void:
	var transform: Transform3D = parent * node.transform if node is Node3D else parent
	if node is MeshInstance3D and node.mesh != null:
		_mesh_info(node.mesh, transform, info)
	for child: Node in node.get_children():
		_visit(child, transform, info)


func _blank_info() -> Dictionary:
	return {"meshes": 0, "surfaces": 0, "triangles": 0, "colors": true,
		"valid": true, "has_bounds": false, "bounds": AABB()}


func _fits(info: Dictionary, expected: Vector3) -> bool:
	if not info["has_bounds"] or not info["valid"]:
		return false
	var bounds: AABB = info["bounds"]
	for axis: int in range(3):
		if absf(bounds.size[axis] - expected[axis]) > expected[axis] * 0.05:
			return false
	var centre: Vector3 = bounds.get_center()
	return absf(bounds.position.y) <= FLOOR_EPS and absf(centre.x) <= FLOOR_EPS and absf(centre.z) <= FLOOR_EPS


func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if not parsed is Dictionary or not parsed.get("assets") is Dictionary:
		print("PROPS_COMMON_CHECK FAIL invalid_catalog")
		quit(1)
		return
	var assets: Dictionary = parsed["assets"]
	var names: Array = assets.keys()
	names.sort()
	var expected_names: Array = EXPECTED.duplicate()
	expected_names.sort()
	var disk_names: Array = []
	for file: String in DirAccess.get_files_at("res://models/props_common"):
		if file.get_extension() == "glb":
			disk_names.append(file.get_basename())
	disk_names.sort()
	var all_ok: bool = names == expected_names and disk_names == expected_names
	var passed := 0
	var total := 0
	for id: String in EXPECTED:
		var row: Dictionary = assets.get(id, {})
		var path: String = "res://models/props_common/%s.glb" % id
		var scene: PackedScene = load(path) as PackedScene
		var info := _blank_info()
		var batch_info := _blank_info()
		if scene != null:
			var root: Node = scene.instantiate()
			_visit(root, Transform3D.IDENTITY, info)
			root.free()
		var batches: Dictionary = PropModels.batch_meshes(path)
		for mesh: Mesh in batches.values():
			_mesh_info(mesh, Transform3D.IDENTITY, batch_info)
		var footprint: Array = row.get("footprint_m", [0, 0])
		var expected := Vector3(float(footprint[0]), float(row.get("height_m", 0)), float(footprint[1]))
		var triangles: int = info["triangles"]
		var file := FileAccess.open(path, FileAccess.READ)
		var hash_ok: bool = file != null and file.get_length() == int(row.get("bytes", -1)) \
			and FileAccess.get_sha256(path) == row.get("sha256", "")
		var ok: bool = scene != null and batches.has(0) and not batches.is_empty() \
			and info["meshes"] == 1 and info["surfaces"] == 1 and info["colors"] \
			and _fits(info, expected) and _fits(batch_info, expected) and batch_info["colors"] \
			and batch_info["triangles"] == triangles and triangles > 0 and triangles <= 600 \
			and triangles == int(row.get("lod0_tris", -1)) and int(row.get("triangle_limit", -1)) == 600 \
			and row.get("path", "") == path and row.get("status", "") == "ready" and hash_ok
		var bounds: AABB = info["bounds"]
		print("%s %s packed=%s batch=%d meshes=%d surfaces=%d aabb=%s floor=%.6f colors=%s tris=%d/600 sha=%s" % [
			"PASS" if ok else "FAIL", id, scene != null, batches.size(), info["meshes"], info["surfaces"],
			bounds.size, bounds.position.y, info["colors"], triangles, hash_ok])
		passed += int(ok)
		total += triangles
		all_ok = all_ok and ok
	all_ok = all_ok and total <= 10932
	print("PROPS_COMMON_CHECK %d/18 %s total_tris=%d/10932 names=%s" % [passed, "PASS" if all_ok else "FAIL", total, names == expected_names])
	quit(0 if all_ok else 1)
