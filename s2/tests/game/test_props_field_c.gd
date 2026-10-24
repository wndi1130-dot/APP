extends "res://addons/gut/test.gd"
## C 몫만 비교한다. 같은 폴더의 A/B 등 타 발주 파일은 허용한다.
const KIT_DIR := "res://models/props_field"
const EXPECTED := [
	"circular_saw_bench",
	"fish_drying_frame",
	"sled_load",
	"track_switch",
	"cask_stack",
	"generator",
	"relief_crate",
	"slag_heap",
	"checkout",
	"community_banner",
	"conveyor",
	"ice_block_stack",
	"mail_sorting_rack",
	"plank_bridge",
	"rail_pile",
	"stump_cluster",
	"wrecked_car_cluster",
	"band_saw",
	"box_truck",
	"drain_ditch",
	"flour_sack_pile",
	"lumber_rack",
	"market_stall",
	"nave_pillar",
	"post_box_row",
	"printing_press",
	"water_barrel",
	"weigh_platform",
	"boat_on_blocks",
	"forklift",
	"jib_crane",
	"log_truck",
	"ore_cart",
	"pit_props",
	"coal_sorter",
	"farm_tractor",
	"generator_unit",
	"hopper",
	"mine_portal",
	"rail_stack"
]

func _assets() -> Dictionary:
	var path := KIT_DIR + "/catalog_c.json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	var assets: Variant = parsed.get("assets", {})
	return assets if assets is Dictionary else {}

func test_catalog_names_are_exactly_forty_c_props() -> void:
	var assets := _assets()
	assert_false(assets.is_empty(), "빈 장부 금지")
	var listed: Array = assets.keys()
	listed.sort()
	var expected: Array = EXPECTED.duplicate()
	expected.sort()
	assert_eq(listed, expected, "발주 C 40종")
	var on_disk: Array = []
	for kind: String in EXPECTED:
		if FileAccess.file_exists("%s/%s.glb" % [KIT_DIR, kind]):
			on_disk.append(kind)
	on_disk.sort()
	assert_eq(on_disk, listed, "C 몫 glb 이름 집합")

func test_each_c_prop_has_matching_files_and_hash() -> void:
	var assets := _assets()
	assert_eq(assets.size(), 40, "40종 장부")
	for kind: String in assets:
		var asset: Dictionary = assets[kind]
		var path := "%s/%s.glb" % [KIT_DIR, kind]
		assert_eq(asset.get("path", ""), path, kind + " 경로")
		assert_eq(asset.get("status", ""), "ready", kind + " 상태")
		assert_true(FileAccess.file_exists(path), kind + " glb")
		assert_true(FileAccess.file_exists(path + ".import"), kind + " import")
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			assert_eq(file.get_length(), int(asset.get("bytes", -1)), kind + " 바이트")
			assert_eq(FileAccess.get_sha256(path), asset.get("sha256", ""), kind + " 해시")

func test_c_triangle_budget() -> void:
	var assets := _assets()
	assert_eq(assets.size(), 40)
	for kind: String in assets:
		var asset: Dictionary = assets[kind]
		assert_gt(int(asset.get("lod0_tris", -1)), 0, kind + " 비어 있지 않음")
		assert_lte(int(asset.get("lod0_tris", -1)), 600, kind + " 삼각형 상한")
		assert_eq(int(asset.get("triangle_limit", -1)), 600, kind + " 예산")

