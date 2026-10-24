extends SceneTree
## B 몫만 검사한다. 다른 발주의 파일은 집합 비교에서 제외한다.
const PropModels = preload("res://game/world/prop_models.gd")
const CATALOG := "res://models/props_field/catalog_b.json"
const INPUT := "res://../_in/kinds_b.json"
var errors: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		printerr("FAIL " + message)


func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _mesh_count(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _mesh_count(child)
	return count


func _run() -> void:
	var book := _read(CATALOG)
	var source := _read(INPUT)
	_check(not book.is_empty() and not source.is_empty(), "장부와 입력 목록 읽기")
	if book.is_empty() or source.is_empty():
		quit(1)
		return
	var assets: Dictionary = book.get("assets", {})
	var skipped: Dictionary = book.get("skipped", {})
	var expected: Array = []
	for row: Dictionary in source.get("kinds", []):
		expected.append(String(row["kind"]))
	expected.sort()
	var accounted: Array = assets.keys() + skipped.keys()
	accounted.sort()
	_check(expected.size() == 50 and accounted == expected, "입력 50종 = 생성 + 근거 있는 제외")
	_check(assets.size() == 49 and skipped.keys() == ["unload"], "49종 생성, unload 1종 제외")
	_check(book.get("failures", []).is_empty(), "생성 실패 없음")
	var total_tris := 0
	var total_bytes := 0
	var passed := 0
	for kind: String in assets:
		var before := errors.size()
		var row: Dictionary = assets[kind]
		var path := "res://models/props_field/%s.glb" % kind
		_check(row.get("path", "") == path, kind + " 경로")
		_check(FileAccess.file_exists(path + ".import"), kind + " .import")
		_check(FileAccess.get_sha256(path) == row.get("sha256", ""), kind + " SHA-256")
		var file := FileAccess.open(path, FileAccess.READ)
		_check(file != null and file.get_length() == int(row.get("bytes", -1)), kind + " 바이트")
		var packed := load(path) as PackedScene
		_check(packed != null, kind + " PackedScene")
		if packed == null:
			continue
		var root := packed.instantiate()
		_check(_mesh_count(root) == 1, kind + " 단일 메시")
		root.free()
		var batches: Dictionary = PropModels.batch_meshes(path)
		_check(not batches.is_empty() and batches.has(0), kind + " batch_meshes")
		if not batches.has(0):
			continue
		var mesh: Mesh = batches[0]
		_check(mesh.get_surface_count() == 1, kind + " 면 묶음 하나")
		var tris := 0
		var colour_count := 0
		var colours: Dictionary = {}
		for surface in range(mesh.get_surface_count()):
			_check(mesh.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES, kind + " 삼각형 메시")
			var arrays := mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			tris += (indices.size() if not indices.is_empty() else vertices.size()) / 3
			var vertex_colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			colour_count += vertex_colours.size()
			_check(vertex_colours.size() == vertices.size(), kind + " 정점색 개수")
			for colour in vertex_colours:
				colours[colour.to_html()] = true
		_check(tris > 0 and tris <= 600, kind + " 삼각형 상한")
		_check(tris == int(row.get("lod0_tris", -1)), kind + " 장부 삼각형 일치")
		_check(colour_count > 0 and colours.size() >= 1, kind + " 정점색")
		var aabb := mesh.get_aabb()
		var wh: Array = row["footprint_m"]
		var half_width := float(wh[0]) * 0.525
		var half_depth := float(wh[1]) * 0.525
		_check(aabb.position.x >= -half_width and aabb.end.x <= half_width, kind + " X 발자국 ±5%")
		_check(aabb.position.z >= -half_depth and aabb.end.z <= half_depth, kind + " Z 발자국 ±5%")
		_check(absf(aabb.position.y) < 0.005, kind + " 바닥 기준점")
		_check(absf(aabb.position.x + aabb.end.x) < 0.005 and absf(aabb.position.z + aabb.end.z) < 0.005, kind + " 가운데 기준점")
		_check(absf(aabb.size.y - float(row["height_m"])) < 0.005, kind + " 높이")
		total_tris += tris
		total_bytes += int(row["bytes"])
		if errors.size() == before:
			passed += 1
			print("PASS %s tris=%d aabb=%.3fx%.3fx%.3f colours=%d bytes=%d" % [kind, tris, aabb.size.x, aabb.size.y, aabb.size.z, colours.size(), int(row["bytes"])])
	for kind: String in skipped:
		_check(not FileAccess.file_exists("res://models/props_field/%s.glb" % kind), kind + " 제외 파일 없음")
		print("SKIP %s: %s" % [kind, skipped[kind]])
	print("PROPS_FIELD_B_CHECK %s generated=%d passed=%d skipped=%d accounted=%d triangles=%d bytes=%d errors=%d" % ["ALL_PASS" if errors.is_empty() else "FAILED", assets.size(), passed, skipped.size(), accounted.size(), total_tris, total_bytes, errors.size()])
	quit(0 if errors.is_empty() else 1)
