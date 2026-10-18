extends "res://addons/gut/test.gd"
## D에 배정된 종류만 검사한다. 다른 발주 소유 파일은 집합 비교에서 제외한다.

const DIR := "res://models/props_field/"
const EXPECTED := [
	"rubble_pile", "service_counter", "skidder", "support_frame", "bark_heap",
	"cleaning_table", "debarker", "drying_rack", "fish_hoist", "fishing_platform",
	"flat_trailer", "fuel_drum_group", "log_carriage", "log_cart", "log_conveyor",
	"oil_drum", "ore_cart_tipped", "ore_truck", "pickup_truck", "planer",
	"rubbish_pile", "sawdust_bin", "sawdust_pile", "sawhorse", "sleeper_pile",
	"weigh_scale", "arcade_column", "farm_cart", "fish_truck", "garden_rack",
	"grave_plot", "ice_saw_frame", "ladder_rack", "repair_lumber", "signal_post",
	"tender_wagon", "anvil_block", "box_wagon", "city_bus", "cooking_pot",
	"dough_table", "grave_slab", "parish_chest", "reed_bundle", "altar_table",
	"bell_frame", "bell_rope", "cloister_post", "fallen_signal", "high_rack",
	"meeting_table", "old_coach", "plow_blade", "pulpit", "snowplow_truck",
	"wire_coil", "blanket_screen", "boulder", "butcher_block", "courtyard_planter",
]


func _assets() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "catalog_d.json"))
	if not parsed is Dictionary:
		return {}
	var assets: Variant = parsed.get("assets", {})
	return assets if assets is Dictionary else {}


func test_catalog_names_equal_the_sixty_assigned_kinds() -> void:
	var listed: Array = _assets().keys()
	var expected: Array = EXPECTED.duplicate()
	listed.sort()
	expected.sort()
	assert_eq(listed, expected, "D 60종 이름 집합")
	var on_disk: Array = []
	for file: String in DirAccess.get_files_at(DIR):
		if file.get_extension() == "glb" and file.get_basename() in EXPECTED:
			on_disk.append(file.get_basename())
	on_disk.sort()
	assert_eq(on_disk, listed, "D의 실제 GLB와 장부 집합")


func test_each_catalog_entry_has_a_matching_glb_and_import() -> void:
	var assets := _assets()
	assert_eq(assets.size(), 60, "빈 장부는 통과하지 않음")
	for id: String in assets:
		var asset: Dictionary = assets[id]
		var path := DIR + id + ".glb"
		assert_eq(asset.get("path", ""), path, "%s 경로" % id)
		assert_eq(asset.get("status", ""), "ready", "%s 상태" % id)
		assert_true(FileAccess.file_exists(path), "%s GLB" % id)
		assert_true(FileAccess.file_exists(path + ".import"), "%s import" % id)
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			assert_eq(file.get_length(), int(asset.get("bytes", -1)), "%s 바이트" % id)
		assert_eq(FileAccess.get_sha256(path), asset.get("sha256", ""), "%s SHA-256" % id)


func test_each_prop_stays_within_six_hundred_triangles() -> void:
	var assets := _assets()
	assert_eq(assets.size(), 60, "60종 검사")
	for id: String in assets:
		var row: Dictionary = assets[id]
		assert_gt(int(row.get("lod0_tris", -1)), 0, "%s 비어 있지 않음" % id)
		assert_lte(int(row.get("lod0_tris", -1)), 600, "%s 삼각형 상한" % id)
		assert_eq(int(row.get("triangle_limit", -1)), 600, "%s 예산" % id)
