extends "res://addons/gut/test.gd"

const Kinds = preload("res://game/world/prop_kinds.gd")
const Props = preload("res://game/world/prop_models.gd")
const STOP_NAMES := [
	"arrow_set", "bookcase", "canvas_windbreak", "chopping_block", "concrete_barrier",
	"crt_monitor", "dining_set", "drawer_chest_spilled", "folding_workbench", "garden_wall",
	"hand_basket", "iron_bed", "kitchen_knife", "machete", "mine_track", "office_desk",
	"plank_barricade", "scattered_tools", "shop_shelf", "sleeper_fence", "table_overturned",
	"tiled_stove", "toolbox", "wardrobe", "workbench", "yard_gate",
]
var _was_enabled: Variant


func before_each() -> void:
	_was_enabled = ProjectSettings.get_setting(Props.MODE_SETTING) if ProjectSettings.has_setting(Props.MODE_SETTING) else null


func after_each() -> void:
	ProjectSettings.set_setting(Props.MODE_SETTING, _was_enabled)


func test_same_named_models_and_furniture_aliases() -> void:
	for kind: String in STOP_NAMES:
		var path := Kinds.STOP_DIR + kind + ".glb"
		assert_eq(Kinds.MODELS[kind], path, kind)
		assert_true(FileAccess.file_exists(path), kind)
	var aliases := {"shelf": "shop_shelf", "desk": "office_desk", "bed": "iron_bed", "cold_stove": "tiled_stove",
		"display_shelf": "shop_shelf", "tool_bench": "workbench", "typewriter_desk": "office_desk", "jar_shelf": "shop_shelf"}
	for kind: String in aliases:
		assert_eq(Kinds.MODELS[kind], Kinds.STOP_DIR + aliases[kind] + ".glb", kind)


func test_every_table_path_resolves_or_keeps_the_visual_fallback() -> void:
	for kind: String in Kinds.MODELS:
		var expected := ""
		for path in Kinds.candidates(kind):
			assert_true(path.begins_with("res://models/") and path.ends_with(".glb"), kind)
			if expected.is_empty() and ResourceLoader.exists(path):
				expected = path
		assert_eq(Kinds.model_path(kind), expected, kind)
		if expected.is_empty():
			assert_eq(Kinds.fallback_for("low"), "low", kind)
			assert_eq(Kinds.fallback_for("none"), "hidden", kind)


func test_twenty_optional_common_models_precede_existing_models() -> void:
	assert_eq(Kinds.COMMON_MODELS.size(), 20)
	for kind: String in Kinds.COMMON_MODELS:
		var common: String = Kinds.COMMON_MODELS[kind]
		assert_eq(Kinds.candidates(kind)[0], common, kind)
		if ResourceLoader.exists(common):
			assert_eq(Kinds.model_path(kind), common, kind)
		else:
			var fallback: String = Kinds.MODELS[kind]
			var expected := fallback if not fallback.is_empty() and ResourceLoader.exists(fallback) else ""
			assert_eq(Kinds.model_path(kind), expected, kind)


func test_unknown_kinds_keep_existing_fallbacks_without_loading() -> void:
	assert_true(Kinds.candidates("unlisted_prop").is_empty())
	assert_eq(Kinds.model_path("unlisted_prop"), "")
	assert_eq(Kinds.fallback_for("low"), "low")
	for solid: String in ["none", "tree", "wall", "wagon", ""]:
		assert_eq(Kinds.fallback_for(solid), "hidden", solid)


func test_container_names_use_the_requested_suffixes() -> void:
	var expected := {"선반": "shop_shelf", "책상": "office_desk", "침대": "iron_bed", "옷장": "wardrobe",
		"공구함": "toolbox", "찬장": "bookcase", "궤": "", "보관함": "", "자재함": "", "상자": "", "묶음": ""}
	for suffix: String in expected:
		assert_eq(Props.kind_for("box_001", "서쪽 " + suffix), expected[suffix], suffix)
	assert_eq(Props.kind_for("box_001", " 책상  "), "office_desk")
	assert_eq(Props.kind_for("box_001", "선반 옆 바닥"), "", "끝말만 사용")
	assert_eq(Props.kind_for("box_001"), "")


func test_first_stop_ids_win_over_the_name_suffix() -> void:
	for id: String in Props.BY_ID:
		assert_eq(Props.kind_for(id, "다른 상자"), Props.BY_ID[id], id)


func test_switch_off_keeps_suffix_containers_as_boxes() -> void:
	ProjectSettings.set_setting(Props.MODE_SETTING, false)
	assert_eq(Props.model_for("box_001", "작업대 공구함"), "")
	assert_eq(Props.model_for("office_desk", "책상"), "")
