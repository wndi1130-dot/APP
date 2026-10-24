extends "res://addons/gut/test.gd"
## E 장부/파일 이름 집합과 삼각형 예산. 공용·A~D 파일은 대상에서 제외한다.
const KIT_DIR := "res://models/props_field"
const EXPECTED_TEXT := "garage_door_leaf hive_box inspection_pit log_flatcar millstone mooring_post rail_plow siding_buffer wheelset wind_pole ballast_pile dock_plate dry_grass evidence_shelf fuel_pump hose_rack long_table plank_patch skybridge_rail slate_board turntable_rim windbreak_fence bin_bay bunk_bed chiller_case coal_hopper dock_door fallen_pole garden_bed hand_pump_cart hedge laundry_line rail_handcar rubble_heap well_cover armory_rack brake_shoe_pile curing_barrel frozen_barge grain_silo herb_bed herb_rack lock_wheel log_pile patrol_car plank_fence platform_cart repair_scaffold roof_beam_pile roof_tile_heap sluice_frame strongbox transformer_unit water_gauge anchor bridge_rail bridge_truss dock_platform fallen_bell fire_engine fishing_boat flagpole frozen_fountain pallet_truck pit_rail_pair playground_frame quay_crane reed_clump shop_awning signal_bridge stalled_tram switch_cluster switch_lever tow_truck training_frame turntable_deck water_crane water_tower"


func _assets() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(KIT_DIR + "/catalog_e.json"))
	return parsed.get("assets", {}) if parsed is Dictionary else {}


func test_catalog_names_equal_the_78_created_e_kinds() -> void:
	var assets := _assets()
	assert_eq(assets.size(), 78, "빈 장부는 통과하지 않음")
	var expected: PackedStringArray = EXPECTED_TEXT.split(" ", false)
	var listed: PackedStringArray = PackedStringArray(assets.keys())
	expected.sort()
	listed.sort()
	assert_eq(listed, expected, "201~278위 이름 집합")
	var made: PackedStringArray = []
	for filename: String in DirAccess.get_files_at(KIT_DIR):
		if filename.get_extension() == "glb" and filename.get_basename() in expected:
			made.append(filename.get_basename())
	made.sort()
	assert_eq(made, listed, "E glb 집합 = E 장부 집합")


func test_every_entry_has_glb_import_and_matching_digest() -> void:
	var assets := _assets()
	assert_false(assets.is_empty())
	for id: String in assets:
		var asset: Dictionary = assets[id]
		var path := KIT_DIR + "/" + id + ".glb"
		assert_eq(String(asset.get("path", "")), path, id)
		assert_eq(String(asset.get("status", "")), "ready", id)
		assert_true(FileAccess.file_exists(path), id + " glb")
		assert_true(FileAccess.file_exists(path + ".import"), id + " import")
		assert_eq(FileAccess.get_sha256(path), String(asset.get("sha256", "")), id + " SHA-256")


func test_every_prop_stays_within_600_triangles() -> void:
	var assets := _assets()
	assert_false(assets.is_empty())
	for id: String in assets:
		var asset: Dictionary = assets[id]
		assert_gt(int(asset.get("lod0_tris", 0)), 0, id)
		assert_lte(int(asset.get("lod0_tris", 99999)), 600, id)
		assert_eq(int(asset.get("triangle_limit", 0)), 600, id)
