extends "res://addons/gut/test.gd"
## 공용 소품: 자동 장부의 이름·파일·삼각형 예산을 확인한다.

const KIT_DIR := "res://models/props_common"
const CATALOG_PATH := KIT_DIR + "/catalog.json"
const EXPECTED := [
	"shelf", "cold_stove", "desk", "barrel", "bed", "bare_tree",
	"crate_stack", "sack_pile", "file_cabinet", "part_crate", "handcart",
	"blanket_chest", "fridge_open", "iv_stand", "tool_chest", "paper_cart",
	"oxygen_cylinder", "pallet_stack",
]


func _assets() -> Dictionary:
	if not FileAccess.file_exists(CATALOG_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not parsed is Dictionary:
		return {}
	var assets: Variant = parsed.get("assets", {})
	return assets if assets is Dictionary else {}


func test_catalog_names_are_exactly_the_eighteen_common_props() -> void:
	var assets := _assets()
	assert_false(assets.is_empty(), "공용 소품 대응표를 읽어야 함")
	var listed: Array = assets.keys()
	listed.sort()
	var expected: Array = EXPECTED.duplicate()
	expected.sort()
	assert_eq(listed, expected, "기존 wardrobe·workbench를 제외한 18종")
	for id: String in listed:
		assert_true(id in EXPECTED, "%s 허용 이름" % id)
	var on_disk: Array = []
	for file: String in DirAccess.get_files_at(KIT_DIR):
		if file.get_extension() == "glb":
			on_disk.append(file.get_basename())
	on_disk.sort()
	assert_eq(on_disk, listed, "폴더의 glb와 장부의 종류가 같아야 함")


func test_each_catalog_entry_has_a_matching_glb() -> void:
	var assets := _assets()
	assert_false(assets.is_empty(), "빈 대응표는 통과시키지 않음")
	for id: String in assets:
		var asset: Dictionary = assets[id]
		var path := "%s/%s.glb" % [KIT_DIR, id]
		assert_eq(asset.get("path", ""), path, "%s 파일 경로" % id)
		assert_eq(asset.get("status", ""), "ready", "%s 생성 상태" % id)
		assert_true(FileAccess.file_exists(path), "%s glb가 있어야 함" % id)
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		assert_eq(file.get_length(), int(asset.get("bytes", -1)), "%s 바이트" % id)
		assert_eq(FileAccess.get_sha256(path), asset.get("sha256", ""), "%s 파일 확인값" % id)


func test_each_prop_stays_within_six_hundred_triangles() -> void:
	var assets := _assets()
	assert_false(assets.is_empty(), "빈 대응표는 통과시키지 않음")
	for id: String in assets:
		var asset: Dictionary = assets[id]
		var triangles := int(asset.get("lod0_tris", -1))
		assert_gt(triangles, 0, "%s 메시가 비면 안 됨" % id)
		assert_lte(triangles, 600, "%s 삼각형 상한" % id)
		assert_eq(int(asset.get("triangle_limit", -1)), 600, "%s 예산" % id)
