extends SceneTree
## A종만 검사한다. 같은 폴더의 다른 발주 파일은 읽거나 고치지 않는다.

const PropModels = preload("res://game/world/prop_models.gd")
const DIR := "res://models/props_field/"
const EXPECTED := [
	"bare_willow", "map_cabinet", "record_shelf_row", "street_tree", "firewood_pile",
	"car", "conductor_log_chest", "shop_counter", "tin_crate", "fuel_can_group",
	"freezer_chest", "tire_stack", "coal_heap", "candle_stand", "bench", "hand_bell",
	"salvage", "plank_stack", "stone_wall_segment", "shopping_cart", "bare_orchard_tree",
	"tip_up_flag", "hymn_shelf", "tool_cart", "vestry_chest", "fuel_drum", "parts_rack",
	"car_window", "bread_rack", "gear_rack", "pew_row", "radio_set", "net_pile",
	"lamp_post", "firebox", "ammo_crate", "quilted_vest", "frozen_reeds", "log_stack_high",
	"hardware_rack", "coupler_set", "tool_rack", "work_site", "ice_cut_pool", "lamp_shelf",
	"rope_coil", "notice_board", "blanket_crate", "glass_cabinet", "fieldstone_wall",
]

var failures: Array[String] = []
var checked: int = 0
var triangle_sum: int = 0
var map_budget: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _require(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		print("FAIL " + message)
	return ok


func _forbidden_nodes(node: Node) -> bool:
	if node is Light3D or node is GPUParticles3D or node is CPUParticles3D or node is Camera3D:
		return true
	for child: Node in node.get_children():
		if _forbidden_nodes(child):
			return true
	return false


func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "catalog_a.json"))
	if not _require(parsed is Dictionary, "catalog_a dictionary"):
		quit(1)
		return
	var assets: Dictionary = parsed.get("assets", {})
	var names: Array = assets.keys()
	names.sort()
	var expected: Array = EXPECTED.duplicate()
	expected.sort()
	_require(names == expected, "catalog_a exact 50 names")
	for kind: String in EXPECTED:
		if not _require(assets.has(kind), kind + " catalog entry"):
			continue
		_check(kind, assets[kind])
	if "--map-budget" in OS.get_cmdline_user_args():
		_map_budget(assets)
	var status := "PASS" if failures.is_empty() and checked == 50 else "FAIL"
	print("PROPS_FIELD_A %s checked=%d expected=50 triangles=%d failures=%d" % [status, checked, triangle_sum, failures.size()])
	var report := FileAccess.open("res://.godot/props_a_work/check_result.json", FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify({"status": status, "checked": checked, "triangles": triangle_sum, "failures": failures, "map_budget": map_budget}, "\t") + "\n")
	quit(0 if status == "PASS" else 1)


func _map_budget(assets: Dictionary) -> void:
	var maps: Dictionary = {}
	var largest_map: String = ""
	var largest_tris: int = 0
	var counts_all: Dictionary = {}
	var rotated_outside: int = 0
	var kind_regex := RegEx.new()
	kind_regex.compile('"kind"\\s*:\\s*"([^"]+)"')
	var rect_regex := RegEx.new()
	rect_regex.compile('"rect"\\s*:\\s*(?:Rect2i\\(|\\[)\\s*-?\\d+\\s*,\\s*-?\\d+\\s*,\\s*(\\d+)\\s*,\\s*(\\d+)')
	var facing_regex := RegEx.new()
	facing_regex.compile('"facing"\\s*:\\s*(\\d+)')
	var separators := RegEx.new()
	separators.compile('\\}\\s*,\\s*\\{')
	for file: String in DirAccess.get_files_at("res://game/world/maps"):
		if file.get_extension() != "gd":
			continue
		var counts: Dictionary = {}
		var tris: int = 0
		# 게임 초기화를 실행하지 않는 지도 원문 기준 추정이다.
		var map_text := FileAccess.get_file_as_string("res://game/world/maps/" + file)
		for line: String in separators.sub(map_text, "}\n{", true).split("\n"):
			var found := kind_regex.search(line)
			if found == null or not assets.has(found.get_string(1)):
				continue
			var kind := found.get_string(1)
			counts[kind] = int(counts.get(kind, 0)) + 1
			counts_all[kind] = int(counts_all.get(kind, 0)) + 1
			tris += int(assets[kind]["lod0_tris"])
			var rect_match := rect_regex.search(line)
			if rect_match == null:
				continue
			var mesh: Mesh = PropModels.batch_meshes(DIR + kind + ".glb")[0]
			var facing_match := facing_regex.search(line)
			var facing: int = int(facing_match.get_string(1)) if facing_match != null else 0
			var rotation := Transform3D(Basis(Vector3.UP, -float(facing % 4) * PI * 0.5), Vector3.ZERO)
			var bounds: AABB = rotation * mesh.get_aabb()
			if bounds.size.x > int(rect_match.get_string(1)) * 1.05 or bounds.size.z > int(rect_match.get_string(2)) * 1.05:
				rotated_outside += 1
		maps[file.get_basename()] = {"counts": counts, "triangles": tris}
		if tris > largest_tris:
			largest_tris = tris
			largest_map = file.get_basename()
	map_budget = {"method": "source_kind_occurrences", "maps": maps, "max_map": largest_map, "max_triangles": largest_tris, "source_counts": counts_all, "rotated_rect_overruns": rotated_outside}
	_require(maps.size() == 80, "80 map budgets")
	print("MAP_BUDGET source_estimate maps=%d max_map=%s triangles=%d rotated_rect_overruns=%d" % [maps.size(), largest_map, largest_tris, rotated_outside])


func _check(kind: String, entry: Dictionary) -> void:
	var start_failures: int = failures.size()
	var path := DIR + kind + ".glb"
	if not _require(ResourceLoader.exists(path), kind + " imported resource"):
		return
	var scene := load(path) as PackedScene
	if not _require(scene != null, kind + " PackedScene"):
		return
	var instance := scene.instantiate()
	_require(not _forbidden_nodes(instance), kind + " no lights/particles/cameras")
	instance.free()
	var batches: Dictionary = PropModels.batch_meshes(path)
	if not _require(not batches.is_empty() and batches.has(0), kind + " batch_meshes nonempty"):
		return
	var mesh: Mesh = batches[0]
	_require(mesh.get_surface_count() == 1, kind + " one surface")
	var tris: int = 0
	for surface in range(mesh.get_surface_count()):
		_require(mesh.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES, kind + " triangle primitive")
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		_require(colors.size() == vertices.size() and not colors.is_empty(), kind + " vertex colors")
		var count: int = indices.size() if not indices.is_empty() else vertices.size()
		_require(count % 3 == 0, kind + " complete triangles")
		tris += count / 3
	_require(tris > 0 and tris <= 600, kind + " triangle limit")
	_require(tris == int(entry["lod0_tris"]), kind + " catalog triangles")
	if int(entry["count"]) > 200:
		_require(tris <= 300, kind + " frequent-kind 300 target")
	var bounds := mesh.get_aabb()
	var footprint: Array = entry["footprint_m"]
	var half_x: float = float(footprint[0]) * 0.5 * 1.05
	var half_z: float = float(footprint[1]) * 0.5 * 1.05
	_require(bounds.position.x >= -half_x and bounds.end.x <= half_x, kind + " X footprint +/-5%")
	_require(bounds.position.z >= -half_z and bounds.end.z <= half_z, kind + " Z footprint +/-5%")
	_require(absf(bounds.position.y) <= 0.002, kind + " floor origin")
	_require(absf(bounds.get_center().x) <= 0.002 and absf(bounds.get_center().z) <= 0.002, kind + " centered footprint")
	_require(absf(bounds.size.y - float(entry["height_m"])) <= 0.005, kind + " height")
	_require(FileAccess.file_exists(path + ".import"), kind + " import sidecar")
	_require(FileAccess.get_sha256(path) == entry["sha256"], kind + " sha256")
	var file := FileAccess.open(path, FileAccess.READ)
	_require(file != null and file.get_length() == int(entry["bytes"]), kind + " bytes")
	triangle_sum += tris
	checked += 1
	if failures.size() == start_failures:
		print("PASS %s PackedScene batch_meshes AABB colors sha256 tris=%d size=%.3fx%.3fx%.3f" % [kind, tris, bounds.size.x, bounds.size.y, bounds.size.z])
