extends SceneTree
## 실제 가져온 장면의 메시·중앙 기준·크기·정점색·삼각형을 검사한다.

const ROOT := "res://models/train_interior/"
const EXPECTED := [
	"bench", "stove", "bunk_lower", "bunk_upper", "book", "blanket",
	"sacks", "workbench", "crates", "insulation_panel", "side_table", "supplies",
	"curtain_half_open", "medicine_box", "dining_table", "cooking_pot", "bowls",
	"class_slate", "ballot_box", "bell", "wrench", "memorial_board", "ladle",
	"tools", "shelf", "captain_desk", "radio", "coal_pile", "food_crates",
	"divider", "empty_platform", "storage_board", "boiler",
	"cupboard", "wood_chair",
]
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _collect(node: Node, parent_transform: Transform3D, stats: Dictionary) -> void:
	var transform := parent_transform
	if node is Node3D:
		transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		var mesh := instance.mesh
		if mesh == null:
			stats["valid"] = false
		else:
			var bounds: AABB = transform * mesh.get_aabb()
			stats["bounds"] = bounds if stats["meshes"] == 0 else (stats["bounds"] as AABB).merge(bounds)
			stats["meshes"] += 1
			stats["surfaces"] += mesh.get_surface_count()
			for surface in mesh.get_surface_count():
				var arrays: Array = mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				var count: int = indices.size() if not indices.is_empty() else vertices.size()
				if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES or count % 3 != 0:
					stats["valid"] = false
				stats["triangles"] += count / 3
				if colours.size() != vertices.size():
					stats["valid"] = false
					stats["errors"].append("colour_count=%d vertex_count=%d" % [colours.size(), vertices.size()])
				var material := instance.get_active_material(surface)
				if material is BaseMaterial3D:
					if not (material as BaseMaterial3D).vertex_color_use_as_albedo:
						stats["valid"] = false
						stats["errors"].append("vertex_color_use_as_albedo=false")
				else:
					stats["valid"] = false
					stats["errors"].append("material=null" if material == null else material.get_class())
	for child in node.get_children():
		_collect(child, transform, stats)


func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "catalog.json"))
	if not parsed is Dictionary or not parsed.get("assets") is Dictionary:
		print("TRAIN_INTERIOR_CHECK FAIL catalog")
		quit(1)
		return
	var assets: Dictionary = parsed["assets"]
	var expected: Array = EXPECTED.duplicate()
	expected.sort()
	var listed: Array = assets.keys()
	listed.sort()
	if listed != expected:
		failures.append("catalog names")
	var disk: Array = []
	for file in DirAccess.get_files_at(ROOT):
		if file.get_extension() == "glb":
			disk.append(file.get_basename())
	disk.sort()
	if disk != expected:
		failures.append("disk names")
	var passed := 0
	var total_triangles := 0
	for id: String in EXPECTED:
		if not assets.has(id):
			failures.append(id + ": missing catalog entry")
			continue
		var asset: Dictionary = assets[id]
		var path := ROOT + id + ".glb"
		var resource := load(path)
		if not resource is PackedScene:
			failures.append(id + ": not PackedScene")
			continue
		var scene: Node = (resource as PackedScene).instantiate()
		var stats: Dictionary = {"meshes": 0, "surfaces": 0, "triangles": 0, "bounds": AABB(), "valid": true, "errors": []}
		_collect(scene, Transform3D.IDENTITY, stats)
		scene.free()
		var bounds: AABB = stats["bounds"]
		var sizes: Array = asset.get("reference_size_m", [])
		var valid: bool = stats["valid"] and stats["meshes"] == 1 and stats["surfaces"] == 1 and sizes.size() == 3
		if sizes.size() == 3:
			for axis in 3:
				var size := float(sizes[axis])
				# 각 축의 크기 ±5%, 중앙 위치 ±0.5%. 끝점도 경계 안이어야 한다.
				valid = valid and absf(bounds.size[axis] - size) <= size * 0.05 + 0.00001
				valid = valid and absf(bounds.get_center()[axis]) <= size * 0.005 + 0.00001
				valid = valid and bounds.position[axis] >= -size * 0.525 - 0.00001
				valid = valid and bounds.end[axis] <= size * 0.525 + 0.00001
		var triangles := int(stats["triangles"])
		total_triangles += triangles
		valid = valid and triangles > 0 and triangles <= 600 and triangles == int(asset.get("lod0_tris", -1))
		valid = valid and FileAccess.get_sha256(path) == asset.get("sha256", "")
		valid = valid and FileAccess.file_exists(path + ".import")
		if valid:
			passed += 1
			print("PASS %s size=(%.6f, %.6f, %.6f) triangles=%d vertex_color=ok" % [id, bounds.size.x, bounds.size.y, bounds.size.z, triangles])
		else:
			failures.append(id + ": bounds/mesh/colour/triangles/hash/import")
			print("FAIL %s %s" % [id, stats])
	if total_triangles > 8000 or total_triangles != int(parsed.get("total_triangles", -1)):
		failures.append("total triangle budget")
	print("TRAIN_INTERIOR_CHECK %d/%d %s triangles=%d/8000" % [passed, EXPECTED.size(), "PASS" if failures.is_empty() and passed == EXPECTED.size() else "FAIL", total_triangles])
	for failure in failures:
		print("FAILURE " + failure)
	quit(0 if failures.is_empty() and passed == EXPECTED.size() else 1)
