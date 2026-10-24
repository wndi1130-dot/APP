extends "res://addons/gut/test.gd"
## A 장부의 이름·파일·실제 GLB 삼각형 예산. B 발주 파일은 비교에서 제외한다.

const KIT_DIR := "res://models/props_field"
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


func _assets() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(KIT_DIR + "/catalog_a.json"))
	if not parsed is Dictionary:
		return {}
	return parsed.get("assets", {})


func test_catalog_matches_all_fifty_requested_kinds() -> void:
	var assets := _assets()
	var names: Array = assets.keys()
	names.sort()
	var expected: Array = EXPECTED.duplicate()
	expected.sort()
	assert_eq(names, expected, "A 장부 이름 집합 = 요청 50종")
	var created: Array = []
	for file: String in DirAccess.get_files_at(KIT_DIR):
		if file.get_extension() == "glb" and file.get_basename() in EXPECTED:
			created.append(file.get_basename())
	created.sort()
	assert_eq(created, names, "A 생성 파일 이름 집합 = 장부; 다른 발주 이름 보존")


func test_catalog_files_and_receipts_match() -> void:
	var assets := _assets()
	assert_eq(assets.size(), 50)
	for kind: String in assets:
		var entry: Dictionary = assets[kind]
		var path := KIT_DIR + "/" + kind + ".glb"
		assert_true(FileAccess.file_exists(path), kind + " glb")
		assert_true(FileAccess.file_exists(path + ".import"), kind + " .import")
		assert_eq(entry.get("path", ""), path)
		assert_eq(entry.get("status", ""), "ready")
		assert_eq(FileAccess.get_sha256(path), entry.get("sha256", ""))
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			assert_eq(file.get_length(), int(entry.get("bytes", -1)))


func test_actual_glb_triangles_match_catalog_and_budget() -> void:
	var assets := _assets()
	assert_eq(assets.size(), 50)
	for kind: String in assets:
		var file := FileAccess.open(KIT_DIR + "/" + kind + ".glb", FileAccess.READ)
		assert_not_null(file, kind)
		if file == null:
			continue
		file.seek(12)
		var json_length: int = file.get_32()
		assert_eq(file.get_32(), 0x4e4f534a, kind + " GLB JSON chunk")
		var doc: Variant = JSON.parse_string(file.get_buffer(json_length).get_string_from_utf8())
		assert_true(doc is Dictionary, kind + " GLB JSON")
		if not doc is Dictionary:
			continue
		var primitive: Dictionary = doc["meshes"][0]["primitives"][0]
		var tris: int = int(doc["accessors"][int(primitive["indices"])]["count"]) / 3
		assert_gt(tris, 0, kind)
		assert_lte(tris, 600, kind)
		assert_eq(tris, int(assets[kind]["lod0_tris"]), kind)
		if int(assets[kind]["count"]) > 200:
			assert_lte(tris, 300, kind + " 다빈도 목표")
