extends "res://addons/gut/test.gd"
## B 전용 집합: 같은 폴더의 다른 발주 GLB는 건드리거나 비교하지 않는다.
const DIR := "res://models/props_field/"
const EXPECTED := [
	"power_pole", "sleeper_stack", "cable_drum", "ration_ledger_chest", "hose_reel",
	"spruce", "cloth_bolt_rack", "coal_wagon", "loom", "log_stack_low",
	"axe_rack", "heavy_coat_rack", "sunken_bow", "sunken_wheelhouse", "battery_rack",
	"engine", "fuel_drum_stack", "lumber_stack", "sunken_deck_section", "buoy_line",
	"scrap_stack", "shore_ice_heap", "firewood_stack", "herb_drying_rack", "door_pile",
	"dry_bush", "net_drying_rack", "fuel_tank", "log_scatter", "rail_marker",
	"rock_ridge", "ice_sled_load", "buffer_stop", "office_cabinet", "overturned_boat",
	"plate_stack", "fallen_log", "floor_shell", "stair_stub", "fish_trap_stack",
	"flat_wagon", "fallen_mast", "pier_deck", "vent_pipe", "fish_crate_stack",
	"hay_cart", "medicine_crate", "coal_bin", "firewood_rick",
]


func _book() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "catalog_b.json"))
	return data if data is Dictionary else {}


func test_catalog_names_equal_created_b_kinds() -> void:
	var book := _book()
	var assets: Dictionary = book.get("assets", {})
	assert_false(assets.is_empty(), "빈 장부 통과 금지")
	var listed: Array = assets.keys()
	listed.sort()
	var expected: Array = EXPECTED.duplicate()
	expected.sort()
	assert_eq(listed, expected, "B 생성 49종")
	var present: Array = []
	for file: String in DirAccess.get_files_at(DIR):
		if file.get_extension() == "glb" and file.get_basename() in EXPECTED:
			present.append(file.get_basename())
	present.sort()
	assert_eq(present, listed, "B 소유 파일과 장부 집합 일치")
	var skipped: Dictionary = book.get("skipped", {})
	assert_eq(skipped.keys(), ["unload"], "비물체 상호작용 지점 제외")
	assert_false(FileAccess.file_exists(DIR + "unload.glb"), "하역 자리 물체를 만들지 않음")
	assert_eq(listed.size() + skipped.size(), 50, "입력 50종 처리")


func test_each_catalog_entry_has_matching_glb_and_import() -> void:
	var assets: Dictionary = _book().get("assets", {})
	assert_eq(assets.size(), 49)
	for id: String in assets:
		var row: Dictionary = assets[id]
		var path := DIR + id + ".glb"
		assert_eq(row.get("path", ""), path)
		assert_eq(row.get("status", ""), "ready")
		assert_true(FileAccess.file_exists(path), id + " GLB")
		assert_true(FileAccess.file_exists(path + ".import"), id + " 가져오기")
		assert_eq(FileAccess.get_sha256(path), row.get("sha256", ""), id + " SHA-256")
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			assert_eq(file.get_length(), int(row.get("bytes", -1)), id + " 바이트")


func test_each_prop_has_at_most_six_hundred_triangles() -> void:
	var assets: Dictionary = _book().get("assets", {})
	assert_eq(assets.size(), 49)
	for id: String in assets:
		var row: Dictionary = assets[id]
		assert_gt(int(row.get("lod0_tris", -1)), 0, id + " 빈 메시 금지")
		assert_lte(int(row.get("lod0_tris", -1)), 600, id + " 삼각형 상한")
		assert_eq(int(row.get("triangle_limit", -1)), 600, id + " 예산")
