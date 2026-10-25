extends "res://addons/gut/test.gd"
## gap 장부/파일 이름 집합과 삼각형 예산(샛길 틈 세 갈래, 벽장 선반, 겨울 잡목 덤불). 다른 묶음 파일은 대상에서 제외한다.
const PropKinds = preload("res://game/world/prop_kinds.gd")
const KIT_DIR := "res://models/props_field"
const EXPECTED_TEXT := "gap_wire gap_gate gap_planks small_shelf thicket"


func _assets() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(KIT_DIR + "/catalog_gap.json"))
	return parsed.get("assets", {}) if parsed is Dictionary else {}


func test_catalog_names_equal_the_five_gap_kinds() -> void:
	var assets := _assets()
	assert_eq(assets.size(), 5, "빈 장부는 통과하지 않음")
	var expected: PackedStringArray = EXPECTED_TEXT.split(" ", false)
	var listed: PackedStringArray = PackedStringArray(assets.keys())
	expected.sort()
	listed.sort()
	assert_eq(listed, expected)
	for id: String in expected:
		assert_eq(PropKinds.model_path(id), KIT_DIR + "/" + id + ".glb", id + " is found by its kind")


func test_every_entry_has_glb_import_and_matching_digest() -> void:
	var assets := _assets()
	assert_false(assets.is_empty())
	for id: String in assets:
		var asset: Dictionary = assets[id]
		var path := KIT_DIR + "/" + id + ".glb"
		assert_eq(String(asset.get("path", "")), path, id)
		assert_eq(String(asset.get("status", "")), "ready", id)
		assert_true(FileAccess.file_exists(path + ".import"), id + " import")
		assert_eq(FileAccess.get_sha256(path), String(asset.get("sha256", "")), id + " SHA-256")


func test_every_prop_stays_within_600_triangles_and_its_footprint() -> void:
	var assets := _assets()
	assert_false(assets.is_empty())
	for id: String in assets:
		var asset: Dictionary = assets[id]
		assert_gt(int(asset.get("lod0_tris", 0)), 0, id)
		assert_lte(int(asset.get("lod0_tris", 99999)), 600, id)
		var size: Array = asset.get("dimensions_m", [])
		var cells: Array = asset.get("footprint_m", [])
		assert_lte(float(size[0]), float(cells[0]), id + " within its width")
		assert_lte(float(size[2]), float(cells[1]), id + " within its depth")


func test_the_gaps_can_be_walked_through() -> void:
	var assets := _assets()
	for id: String in ["gap_wire", "gap_gate", "gap_planks"]:
		assert_eq(String(assets.get(id, {}).get("solid", "")), "none", id)


# The thicket reads as a mass from above with fewer triangles than the bare tree it
# stands among (props_common bare_tree, 376).
func test_the_thicket_is_lighter_than_a_bare_tree() -> void:
	var thicket: Dictionary = _assets().get("thicket", {})
	assert_lt(int(thicket.get("lod0_tris", 9999)), 376)
	assert_gte(float(thicket.get("height_m", 0.0)), 1.5)
	assert_lte(float(thicket.get("height_m", 9.0)), 2.5)
