extends "res://addons/gut/test.gd"
## 열차 가구 장부·파일 집합·바이트·해시·개별/전체 예산.

const KIT_DIR := "res://models/train_interior"
const EXPECTED := [
	"bench", "stove", "bunk_lower", "bunk_upper", "book", "blanket",
	"sacks", "workbench", "crates", "insulation_panel", "side_table", "supplies",
	"curtain_half_open", "medicine_box", "dining_table", "cooking_pot", "bowls",
	"class_slate", "ballot_box", "bell", "wrench", "memorial_board", "ladle",
	"tools", "shelf", "captain_desk", "radio", "coal_pile", "food_crates",
	"divider", "empty_platform", "storage_board", "boiler",
	# 공개 3D(CC0)에서 가져와 더한 자리(tools/blender/train_interior_swap.py).
	"cupboard", "wood_chair",
	# 찬 칸·꼬리칸 꾸밈(tools/blender/train_car_dress.py).
	"blanket_stack", "lantern_off", "blanket_curtain", "laundry_line", "patch_boards", "coal_heap",
	# 사는 칸 세 겹 꾸밈(tools/blender/train_car_layers.py).
	"hang_lamp", "drying_line", "drying_line_b", "drying_line_c", "hang_pot", "coat_hook", "wall_notes", "wall_rack",
	"rug", "bucket", "firewood", "basket",
]
## 칸 살림 단계(0~3) 꾸밈(tools/blender/train_car_tiers.py): 바닥 원점, 모형마다 자기 상한.
const TIERS := [
	"wall_patch", "tarp_patch", "straw_mat", "stick_candle", "tin_stove", "sack_bunk_upper", "sack_bunk_lower",
	"wood_wall_box", "wood_wall_box_shallow", "drum_stove", "end_shelf", "top_shelf", "pale_paneling", "stick_lamp",
	"small_frame", "wall_plant", "table_plant", "open_bunk_upper", "open_bunk_lower",
	"tiny_cup", "tiny_bowl", "tiny_plate", "tiny_bottle", "tiny_can", "tiny_jar", "tiny_teapot", "tiny_tray",
	"thread_spool", "tiny_brush", "tiny_clock", "tiny_book",
]


func _assets() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(KIT_DIR + "/catalog.json"))
	if not parsed is Dictionary:
		return {}
	var assets: Variant = parsed.get("assets", {})
	return assets if assets is Dictionary else {}


func test_catalog_names_are_exactly_the_listed_models() -> void:
	var assets := _assets()
	assert_false(assets.is_empty(), "빈 장부는 통과하지 않음")
	var listed: Array = assets.keys()
	listed.sort()
	var expected: Array = EXPECTED + TIERS
	expected.sort()
	assert_eq(listed, expected, "이름 집합")
	var on_disk: Array = []
	for file: String in DirAccess.get_files_at(KIT_DIR):
		if file.get_extension() == "glb":
			on_disk.append(file.get_basename())
	on_disk.sort()
	assert_eq(on_disk, expected, "실제 glb 집합")


func test_each_catalog_entry_has_a_matching_glb() -> void:
	var assets := _assets()
	assert_eq(assets.size(), EXPECTED.size() + TIERS.size(), "모든 모델 검사")
	for id: String in assets:
		var asset: Dictionary = assets[id]
		var path := "%s/%s.glb" % [KIT_DIR, id]
		assert_eq(asset.get("path", ""), path, "%s 경로" % id)
		assert_eq(asset.get("status", ""), "ready", "%s 상태" % id)
		assert_eq(asset.get("origin", ""), "floor_center" if TIERS.has(id) else "box_center", "%s 원점" % id)
		assert_true(FileAccess.file_exists(path), "%s glb" % id)
		assert_true(FileAccess.file_exists(path + ".import"), "%s 가져오기 설정" % id)
		# 정점 색은 가져오기 스크립트가 바탕색으로 잇는다 — 빠지면 노드로 짓는 모형이 흰 재질로 나온다.
		var settings := ConfigFile.new()
		if settings.load(path + ".import") == OK:
			assert_eq(String(settings.get_value("params", "import_script/path", "")), KIT_DIR + "/vertex_colors.gd", "%s 정점 색 가져오기" % id)
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		assert_eq(file.get_length(), int(asset.get("bytes", -1)), "%s 바이트" % id)
		assert_eq(FileAccess.get_sha256(path), asset.get("sha256", ""), "%s SHA-256" % id)


func test_individual_and_total_triangle_budgets() -> void:
	var assets := _assets()
	assert_eq(assets.size(), EXPECTED.size() + TIERS.size(), "모두 예산 검사")
	var total := 0
	for id: String in assets:
		var asset: Dictionary = assets[id]
		var triangles := int(asset.get("lod0_tris", -1))
		assert_gt(triangles, 0, "%s 빈 메시 금지" % id)
		if TIERS.has(id):
			assert_lte(triangles, int(asset.get("triangle_limit", -1)), "%s 개별 상한" % id)
		else:
			assert_lte(triangles, 600, "%s 개별 상한" % id)
			assert_eq(int(asset.get("triangle_limit", -1)), 600, "%s 예산" % id)
		total += triangles
	assert_lte(total, 10000, "합계 상한(살림 단계 꾸밈을 더한 장부)")
