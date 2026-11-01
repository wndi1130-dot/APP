extends "res://addons/gut/test.gd"
## The captain's board: the rules' wounds become a field body, the line says
## where the captain is and how they are in the field's own words, the figure
## has six parts that are never red, and the board has no gauge and no button.

const Captain = preload("res://game/train/train_captain.gd")
const Rules = preload("res://game/train/train_rules.gd")
const Hud = preload("res://game/ui/field_hud.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const BodyState = preload("res://game/sim/body_state.gd")

const THREE_WOUNDS: Array = [
	{"part": "arm_left", "kind": "deep", "blood": 0.0, "bandaged": true},
	{"part": "leg_right", "kind": "fracture", "splinted": true},
	{"part": "torso", "kind": "laceration", "festering": true},
]


func _cars() -> Array:
	return Rules.load_default()["cars"]


func _hurt(wounds: Array) -> Dictionary:
	return {"at": "captain", "doing": "", "hands": {"weapon": "axe", "tool": ""}, "wounds": wounds}


func _word(wounds: Array) -> String:
	return Captain.body_of(_hurt(wounds)).status_words()


func _is_red(c: Color) -> bool:
	return c.r > 0.6 and c.g < 0.35 and c.b < 0.35


func _wound_of(body: BodyState, part: String) -> Dictionary:
	for w in body.wounds:
		if w["part"] == part:
			return w
	return {}


# ---------------------------------------------------------------- the body

func test_a_captain_without_wounds_is_sound() -> void:
	var body := Captain.body_of(_hurt([]))
	assert_eq(body.status_words(), "멀쩡함")
	assert_true(body.wounds.is_empty())


func test_three_wounds_become_three_with_their_flags() -> void:
	var body := Captain.body_of(_hurt(THREE_WOUNDS))
	assert_eq(body.wounds.size(), 3)
	assert_true(bool(_wound_of(body, "arm_left")["bandaged"]))
	assert_true(bool(_wound_of(body, "leg_right")["splinted"]))
	assert_true(bool(_wound_of(body, "torso")["festering"]))
	assert_false(bool(_wound_of(body, "torso")["bandaged"]))


func test_a_wound_of_no_such_part_or_kind_is_skipped() -> void:
	var body := Captain.body_of(_hurt([
		{"part": "tail", "kind": "deep"},
		{"part": "torso", "kind": "nibble"},
		{"kind": "deep"},
	]))
	assert_eq(body.wounds.size(), 0)


func test_a_deep_wound_reads_as_bleeding_heavily() -> void:
	assert_eq(_word([{"part": "torso", "kind": "deep"}]), "피를 흘림")


func test_a_scratch_reads_as_bleeding_a_little() -> void:
	assert_eq(_word([{"part": "arm_right", "kind": "scratch"}]), "피가 남")


func test_a_splinted_leg_fracture_reads_as_slow() -> void:
	assert_eq(_word([{"part": "leg_right", "kind": "fracture", "splinted": true}]), "느림")


func test_none_of_those_words_is_just_hurt() -> void:
	for wounds in [
		[{"part": "torso", "kind": "deep"}],
		[{"part": "arm_right", "kind": "scratch"}],
		[{"part": "leg_right", "kind": "fracture", "splinted": true}],
	]:
		assert_ne(_word(wounds), "다침")


func test_only_wounds_are_read_into_the_body() -> void:
	var captain := _hurt([])
	captain["exhaustion"] = 1.0
	captain["cold_level"] = 2
	assert_eq(Captain.body_of(captain).status_words(), "멀쩡함")


# ---------------------------------------------------------------- the line

func test_the_line_of_a_captain_in_their_own_car() -> void:
	var captain := {"at": "captain"}
	assert_eq(Captain.line(captain, _cars(), "멀쩡함"), "열차장실 · 멀쩡함")


func test_the_line_of_a_captain_in_a_bed_has_the_stretches_left() -> void:
	var captain := {"at": "medtech", "doing": "bed", "left": 3}
	assert_eq(Captain.line(captain, _cars(), "느림"), "의무칸 침상 · 느림 · 3구간")


func test_the_line_of_a_captain_at_rest() -> void:
	var captain := {"at": "captain", "doing": "rest", "left": 1}
	assert_eq(Captain.line(captain, _cars(), "멀쩡함"), "열차장실 · 쉬는 중 · 멀쩡함 · 1구간")


func test_the_line_of_a_captain_who_is_out() -> void:
	var captain := {"at": "out"}
	assert_eq(Captain.line(captain, _cars(), "멀쩡함"), "밖에 나감 · 멀쩡함")


func test_no_stretches_are_added_when_none_are_left() -> void:
	var captain := {"at": "captain", "left": 0}
	assert_eq(Captain.line(captain, _cars(), "멀쩡함"), "열차장실 · 멀쩡함")


func test_a_car_the_line_does_not_know_shows_its_id() -> void:
	assert_eq(Captain.line({"at": "nowhere"}, _cars(), "멀쩡함"), "nowhere · 멀쩡함")


func test_an_empty_captain_gives_the_word_alone() -> void:
	assert_eq(Captain.line({}, _cars(), "멀쩡함"), "멀쩡함")


func test_a_captain_who_is_out_is_not_at_rest() -> void:
	var captain := {"at": "out", "doing": "rest"}
	assert_eq(Captain.line(captain, _cars(), "멀쩡함"), "밖에 나감 · 멀쩡함")


# ---------------------------------------------------------------- the figure

func test_the_figure_has_six_parts() -> void:
	var looks := Captain.part_looks(Captain.body_of(_hurt([])))
	assert_eq(looks.size(), 6)
	for part in BodyState.PARTS:
		assert_true(looks.has(part), part)


func test_a_sound_part_wears_the_sound_fill_and_a_plain_rim() -> void:
	var looks := Captain.part_looks(Captain.body_of(_hurt([])))
	for part in looks:
		assert_eq(looks[part]["fill"], Captain.FILL_SOUND, part)
		assert_eq(looks[part]["rim_w"], Captain.RIM_W, part)
		assert_false(looks[part]["cracked"], part)


func test_a_bleeding_part_is_brown() -> void:
	var looks := Captain.part_looks(Captain.body_of(_hurt([{"part": "torso", "kind": "laceration"}])))
	assert_eq(looks["torso"]["fill"], Hud.BLOOD_BROWN)
	assert_eq(looks["arm_left"]["fill"], Captain.FILL_SOUND)


func test_a_part_whose_bleeding_has_stopped_wears_the_hurt_fill() -> void:
	var looks := Captain.part_looks(Captain.body_of(_hurt([{"part": "arm_left", "kind": "deep", "blood": 0.0}])))
	assert_eq(looks["arm_left"]["fill"], Captain.FILL_HURT)


func test_a_festering_part_has_the_sallow_rim_and_a_wide_one() -> void:
	var looks := Captain.part_looks(Captain.body_of(_hurt(THREE_WOUNDS)))
	assert_eq(looks["torso"]["rim"], Hud.FESTER_RIM)
	assert_eq(looks["torso"]["rim_w"], Captain.RIM_W_FESTER)
	assert_ne(looks["arm_left"]["rim"], Hud.FESTER_RIM)


func test_a_broken_part_is_cracked() -> void:
	var looks := Captain.part_looks(Captain.body_of(_hurt(THREE_WOUNDS)))
	assert_true(looks["leg_right"]["cracked"])
	assert_false(looks["leg_left"]["cracked"])


func test_the_kinds_of_a_part_are_named_in_korean() -> void:
	var looks := Captain.part_looks(Captain.body_of(_hurt(THREE_WOUNDS)))
	assert_eq(looks["arm_left"]["kinds"], ["깊은 상처"])
	assert_eq(looks["leg_right"]["kinds"].size(), 1)
	assert_true(looks["head_neck"]["kinds"].is_empty())


func test_no_part_is_ever_red() -> void:
	var states: Array = [[], THREE_WOUNDS, [{"part": "torso", "kind": "deep"}, {"part": "head_neck", "kind": "bite", "festering": true}]]
	for wounds in states:
		var looks := Captain.part_looks(Captain.body_of(_hurt(wounds)))
		for part in looks:
			assert_false(_is_red(looks[part]["fill"]), part)
			assert_false(_is_red(looks[part]["rim"]), part)


# ---------------------------------------------------------------- the hands

func test_the_names_of_what_is_held() -> void:
	assert_eq(Captain.held_name("axe"), "손도끼")
	assert_eq(Captain.held_name("flare"), "철도 섬광")
	assert_eq(Captain.held_name(""), "")
	assert_eq(Captain.held_name("no_such_thing"), "no_such_thing")


func test_a_hand_in_a_line() -> void:
	var captain := _hurt([])
	assert_eq(Captain.hand_text(captain, "weapon"), "무기 · 손도끼")
	assert_eq(Captain.hand_text(captain, "tool"), "도구 · 없음")


func test_a_captain_without_hands_holds_nothing() -> void:
	assert_eq(Captain.hand_text({}, "weapon"), "무기 · 없음")
	assert_eq(Captain.hand_text({}, "tool"), "도구 · 없음")


# ---------------------------------------------------------------- the board

func test_the_board_shows_the_rules_captain() -> void:
	var board := Captain.new()
	add_child_autofree(board)
	var d := Rules.load_default()
	board.show_captain(d["captain"], d["cars"])
	assert_eq(board.line_label.text.replace(UiFonts.WORD_JOINER, ""), "열차장실 · 멀쩡함")
	assert_eq(board.weapon_label.text.replace(UiFonts.WORD_JOINER, ""), "무기 · 손도끼")
	assert_eq(board.tool_label.text.replace(UiFonts.WORD_JOINER, ""), "도구 · 없음")
	assert_eq(board.tool_label.get_theme_color("font_color"), Hud.DIM, "an empty hand stays dim through the word joiners")
	assert_eq(board.weapon_label.get_theme_color("font_color"), Hud.INK)
	assert_true(board.wound_lines.is_empty())
	assert_eq(board.wound_box.get_child_count(), 1)
	assert_eq((board.wound_box.get_child(0) as Label).text.replace(UiFonts.WORD_JOINER, ""), "상처 없음")


func test_the_board_lists_the_wounds_one_a_line() -> void:
	var board := Captain.new()
	add_child_autofree(board)
	var d := Rules.load_default()
	board.show_captain(_hurt(THREE_WOUNDS), d["cars"])
	assert_eq(board.wound_lines.size(), 3)
	assert_eq(board.wound_box.get_child_count(), 3)
	assert_eq(board.looks.size(), 6)


func test_the_figure_is_as_big_as_the_field_body() -> void:
	var board := Captain.new()
	add_child_autofree(board)
	assert_eq(board.figure.custom_minimum_size, Hud.BODY_SIZE * Hud.BODY_SCALE)


func test_the_board_has_no_gauge_and_no_button() -> void:
	var board := Captain.new()
	add_child_autofree(board)
	board.show_captain(_hurt(THREE_WOUNDS), _cars())
	assert_true(board.find_children("*", "Range", true, false).is_empty())
	assert_true(board.find_children("*", "BaseButton", true, false).is_empty())
