extends SceneTree
## E 묶음만 검사한다. 다른 발주 파일은 검사 집합에 넣지 않는다.
const PropModels = preload("res://game/world/prop_models.gd")
const ROOT := "res://models/props_field/"
const EXPECTED_TEXT := "garage_door_leaf hive_box inspection_pit log_flatcar millstone mooring_post rail_plow siding_buffer wheelset wind_pole ballast_pile dock_plate dry_grass evidence_shelf fuel_pump hose_rack long_table plank_patch skybridge_rail slate_board turntable_rim windbreak_fence bin_bay bunk_bed chiller_case coal_hopper dock_door fallen_pole garden_bed hand_pump_cart hedge laundry_line rail_handcar rubble_heap well_cover armory_rack brake_shoe_pile curing_barrel frozen_barge grain_silo herb_bed herb_rack lock_wheel log_pile patrol_car plank_fence platform_cart repair_scaffold roof_beam_pile roof_tile_heap sluice_frame strongbox transformer_unit water_gauge anchor bridge_rail bridge_truss dock_platform fallen_bell fire_engine fishing_boat flagpole frozen_fountain pallet_truck pit_rail_pair playground_frame quay_crane reed_clump shop_awning signal_bridge stalled_tram switch_cluster switch_lever tow_truck training_frame turntable_deck water_crane water_tower"
var errors: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _require(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		print("FAIL " + message)


func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "catalog_e.json"))
	if not parsed is Dictionary:
		print("FAIL catalog_e.json 읽기")
		quit(1)
		return
	var book: Dictionary = parsed
	var assets: Dictionary = book.get("assets", {})
	var expected: PackedStringArray = EXPECTED_TEXT.split(" ", false)
	var names: PackedStringArray = PackedStringArray(assets.keys())
	expected.sort()
	names.sort()
	_require(names == expected and names.size() == 78, "catalog 이름 집합 78종")
	var total_tris := 0
	var passed := 0
	var max_tris := 0
	var colour_disabled := 0
	for id: String in expected:
		var before := errors.size()
		if not assets.has(id):
			_require(false, id + " 장부 없음")
			continue
		var asset: Dictionary = assets[id]
		var path := ROOT + id + ".glb"
		_require(FileAccess.file_exists(path + ".import"), id + " .import")
		_require(FileAccess.get_sha256(path) == String(asset.get("sha256", "")), id + " SHA-256")
		var packed: PackedScene = load(path) as PackedScene
		_require(packed != null, id + " PackedScene")
		if packed == null:
			continue
		var instance: Node = packed.instantiate()
		_require(instance != null, id + " instantiate")
		if instance != null:
			instance.free()
		var batches: Dictionary = PropModels.batch_meshes(path)
		_require(not batches.is_empty() and batches.has(0), id + " batch_meshes LOD0")
		if not batches.has(0):
			continue
		var mesh: Mesh = batches[0]
		var aabb: AABB = mesh.get_aabb()
		var footprint: Array = asset.get("footprint_m", [])
		var limit_x: float = float(footprint[0]) * 0.525
		var limit_z: float = float(footprint[1]) * 0.525
		_require(aabb.position.x >= -limit_x and aabb.end.x <= limit_x, id + " AABB X ±5%")
		_require(aabb.position.z >= -limit_z and aabb.end.z <= limit_z, id + " AABB Z ±5%")
		_require(absf(aabb.position.y) <= 0.001, id + " 바닥 기준점")
		_require(absf(aabb.end.y - float(asset.get("height_m", -1))) <= 0.002, id + " 높이")
		_require(absf(aabb.get_center().x) <= 0.001 and absf(aabb.get_center().z) <= 0.001, id + " 중앙 기준점")
		_require(mesh.get_surface_count() == 1, id + " 단일 surface")
		var render_material: ShaderMaterial = mesh.surface_get_material(0) as ShaderMaterial
		if render_material != null and render_material.get_shader_parameter("use_vertex_color") != true:
			colour_disabled += 1
		var triangles := 0
		for surface in range(mesh.get_surface_count()):
			_require(mesh.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES, id + " 삼각형 primitive")
			var arrays: Array = mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			_require(not colours.is_empty() and colours.size() == vertices.size(), id + " 정점색")
			var count: int = indices.size() if not indices.is_empty() else vertices.size()
			_require(count % 3 == 0, id + " 인덱스 3배수")
			triangles += count / 3
		_require(triangles > 0 and triangles <= 600, id + " 삼각형 상한")
		_require(triangles == int(asset.get("lod0_tris", -1)), id + " 장부 삼각형 일치")
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		_require(file != null and file.get_length() == int(asset.get("bytes", -1)), id + " 바이트")
		total_tris += triangles
		max_tris = maxi(max_tris, triangles)
		if errors.size() == before:
			passed += 1
			print("PASS %s tris=%d aabb=(%.3f,%.3f,%.3f) PackedScene batch_meshes colour import sha256" % [id, triangles, aabb.size.x, aabb.size.y, aabb.size.z])
	print("PROPS_FIELD_E_CHECK passed=%d expected=78 failed=%d total_triangles=%d max_triangles=%d" % [passed, errors.size(), total_tris, max_tris])
	if colour_disabled > 0:
		print("INTEGRATION_WARN existing_material_vertex_colour_disabled=%d (asset colours present; shared renderer unchanged)" % colour_disabled)
	quit(0 if errors.is_empty() and passed == 78 else 1)
