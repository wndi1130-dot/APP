extends "res://addons/gut/test.gd"
## A line of type as the mockup's CSS sets it (type_line.gd): words of two
## faces and sizes on one baseline, and a face taller than its line box
## spilling over it instead of pushing the rows under it down.

const TypeLine = preload("res://game/ui/type_line.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")


func _line(line: float = 0.0, box: float = 0.0) -> Container:
	var l = TypeLine.new(line, box)
	add_child_autofree(l)
	return l


func _word(text: String, kind: int, css_px: float) -> Label:
	return UiFonts.label(text, kind, 400, css_px, Color.WHITE)


func _base(l: Label) -> float:
	return l.position.y + TypeLine.rise_of(l).x


func test_words_of_two_faces_and_sizes_sit_on_one_baseline() -> void:
	var line := _line()
	var word := _word("경비 노출 ", UiFonts.WORD, 12.0)
	var num := _word("22", UiFonts.NUMBER, 21.0)
	line.add_child(word)
	line.add_child(num)
	await wait_frames(2)
	assert_almost_eq(_base(word), _base(num), 0.6, "one baseline, not one middle")
	assert_gt(num.size.y, word.size.y, "the bigger number is the taller label")
	assert_almost_eq(num.position.x, word.size.x, 0.6, "side by side")


func test_a_pen_title_spills_over_its_line_instead_of_growing_it() -> void:
	var line := _line(28.0, 26.0)
	var title := _word("병원 옆의 역", UiFonts.HAND, 31.0)
	line.add_child(title)
	await wait_frames(2)
	assert_almost_eq(line.get_combined_minimum_size().y, UiFonts.px(26.0), 0.01, "the row keeps the mockup's 26")
	assert_gt(title.size.y, UiFonts.px(28.0), "the pen face is taller than its line box")
	assert_almost_eq(title.position.y + title.size.y * 0.5, UiFonts.px(14.0), 0.6, "centred in its 28 line as half-leading centres it")


func test_a_block_line_sits_at_the_top_of_its_box() -> void:
	var line := _line(20.0, 26.0)
	var scene := _word("약이 남았을 만한 곳", UiFonts.HAND, 18.0)
	line.add_child(scene)
	await wait_frames(2)
	assert_almost_eq(scene.position.y + scene.size.y * 0.5, UiFonts.px(10.0), 0.6, "a 20 line atop 26, as a paragraph's first line")


func test_a_part_that_expands_takes_the_width_left_over() -> void:
	var line := _line()
	line.size = Vector2(UiFonts.px(386.0), 0.0)
	var name_word := _word("술레후프", UiFonts.HAND, 31.0)
	name_word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var risk := _word("위험", UiFonts.WORD, 12.0)
	line.add_child(name_word)
	line.add_child(risk)
	await wait_frames(2)
	assert_almost_eq(risk.position.x + risk.size.x, line.size.x, 0.6, "the risk at the right end (space-between)")


func test_centred_parts_sit_in_the_middle_of_a_wider_line() -> void:
	var line := _line()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.custom_minimum_size = Vector2(UiFonts.px(38.0), 0.0)
	var n := _word("6", UiFonts.NUMBER, 21.0)
	line.add_child(n)
	await wait_frames(2)
	assert_almost_eq(n.position.x + n.size.x * 0.5, line.size.x * 0.5, 0.6, "the count centred in its 38 (.stepper b)")


func test_a_number_is_set_where_godot_draws_its_digits() -> void:
	# A Label centres its line in its face's height, fallbacks and all; the
	# number face's word fallback rises higher, so its digits draw lower than
	# their own ascent (28 px digits ended 8 game px low before this).
	var num := _word("35", UiFonts.NUMBER, 28.0)
	add_child_autofree(num)
	var f: Font = num.get_theme_font("font")
	var s: int = num.get_theme_font_size("font_size")
	var tl := TextLine.new()
	tl.add_string("35", f, s)
	var lead: float = (f.get_height(s) - tl.get_line_ascent() - tl.get_line_descent()) * 0.5
	assert_gt(lead, 0.0, "the fallback makes the face taller than its digits")
	assert_almost_eq(TypeLine.rise_of(num).x, lead + tl.get_line_ascent(), 0.01)
	var word := _word("온기", UiFonts.WORD, 12.0)
	add_child_autofree(word)
	var wf: Font = word.get_theme_font("font")
	assert_almost_eq(TypeLine.rise_of(word).x, wf.get_ascent(word.get_theme_font_size("font_size")), 0.01, "no fallback: its ascent")


func test_a_number_among_words_makes_the_line_no_taller_than_its_digits() -> void:
	var line := _line()
	var num := _word("4", UiFonts.NUMBER, 21.0)
	var word := _word("명", UiFonts.WORD, 14.0)
	line.add_child(num)
	line.add_child(word)
	await wait_frames(2)
	var en: Vector2 = TypeLine.extent_of(num)
	var ew: Vector2 = TypeLine.extent_of(word)
	assert_almost_eq(line.get_combined_minimum_size().y, maxf(en.x, ew.x) + maxf(en.y, ew.y), 0.01)
	assert_lt(en.x + en.y, num.get_combined_minimum_size().y, "the digits' own ascent and descent, not the label's box")
	assert_almost_eq(_base(num), _base(word), 0.6, "still one baseline")
