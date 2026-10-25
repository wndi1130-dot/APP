extends "res://addons/gut/test.gd"
## The end of the slice on the long sheet (end_card.gd): the port's end card in
## the mockup's places, what the slice cost as its bars, a good end's amber,
## the parts coming up one after another or all at once, and its key goes on.

const EndCard = preload("res://game/ui/end_card.gd")
const SliceSamples = preload("res://tests/game/slice_samples.gd")
const FieldArrival = preload("res://game/politics/field_arrival.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")

const PARTS: Array = ["Picture", "Caption", "Kick", "Title", "Why", "Row0", "Row1", "Row2", "Go"]


func _end() -> Array:
	var s: Array = SliceSamples.arrival_sample()
	return [FieldArrival.finish_slice(s[0], s[1])["g"], s[1]]


func _card(still: bool = true, g1: Dictionary = {}):
	var e: Array = _end()
	var c = EndCard.new()
	c.g = g1 if not g1.is_empty() else e[0]
	c.t = e[1]
	c.go_word = "처음으로"
	c.still = still
	add_child_autofree(c)
	return c


func test_the_sheet_says_the_port_s_end_card() -> void:
	var e: Array = _end()
	var m: Dictionary = EndCard.model(e[0], e[1])
	assert_false(m.has("kick"), "no 「끝 · 둘째 역」 kick (결정 417)")
	assert_eq(m["title"], "여기까지")
	assert_true(m["good"], "the slice ends where it meant to: a good end")
	assert_eq(m["why"], "첫 정차 한 번이 열차를 이만큼 바꿨다.")
	assert_eq(m["caption"], "나간 사람은 모두 열차로 돌아왔다.", "under the picture")
	assert_eq(m["small"], "이 시험판은 둘째 역에서 멈춘다.", "small under that")
	assert_eq(m["rows"], [["사람", 199, 199], ["석탄", 98, 96], ["식량", 106, 99]], "from before the first stop to here, whole")
	assert_eq(EndCard.model({}, e[1]), {}, "no state, nothing to say")


func test_who_stayed_behind_is_said_under_the_picture_as_a_count() -> void:
	var e: Array = _end()
	var g1: Dictionary = (e[0] as Dictionary).duplicate(true)
	g1["fieldReturns"]["records"][0]["dead"] = ["p_152", "p_153"]
	assert_eq(EndCard.model(g1, e[1])["caption"], "2명은 그 역에 남았다.")
	var c = _card(true, g1)
	var said: Array = []
	for l in c.find_children("*", "Label", true, false):
		said.append(String((l as Label).text).replace(UiFonts.WORD_JOINER, ""))
	assert_has(said, "2명은 그 역에 남았다.")
	for s in said:
		assert_false(String(s).contains("p_15"), "a number, never a name")


func test_a_bar_is_what_is_left_and_what_went() -> void:
	assert_almost_eq(EndCard.bar_of(["석탄", 98, 96]), Vector2(96.0 / 98.0, 2.0 / 98.0), Vector2(0.0001, 0.0001))
	assert_eq(EndCard.bar_of(["사람", 199, 199]), Vector2(1, 0))
	assert_eq(EndCard.bar_of(["식량", 0, 3]), Vector2(1, 0), "nothing before: whole")
	assert_eq(EndCard.bar_of(["식량", 50, 80]), Vector2(1, 0), "more than before: whole")
	assert_eq(EndCard.moved_of(["석탄", 98, 96]), "−2", "a minus sign")
	assert_eq(EndCard.moved_of(["사람", 199, 199]), "그대로")
	assert_eq(EndCard.moved_of(["식량", 50, 80]), "+30")


func test_it_lays_its_parts_where_the_mockup_does() -> void:
	var c = _card()
	await wait_frames(2)
	var k: float = UiFonts.K
	for n in PARTS:
		var part: Control = c.find_child(n, true, false) as Control
		assert_not_null(part, n)
		assert_eq(part.modulate.a, 1.0, n + " up at once when still")
	var pic := c.find_child("Picture", true, false) as TextureRect
	assert_eq(pic.texture, EndCard.PICTURE, "the mockup's picture, baked")
	assert_eq(pic.position, EndCard.PIC.position * k)
	assert_eq(pic.size, EndCard.PIC.size * k)
	assert_almost_eq(c.go_key.position + c.go_key.size, EndCard.TXT.end * k, Vector2(0.01, 0.01), "the key at the words' foot, at their right")
	assert_eq(c.go_key.text, "처음으로")
	var txt := Rect2(EndCard.TXT.position * k, EndCard.TXT.size * k).grow(1.0)
	for n in ["Kick", "Title", "Why", "Row0", "Row1", "Row2"]:
		var part: Control = c.find_child(n, true, false)
		assert_true(txt.encloses(Rect2(part.position, part.size)), n + " in the words' column")
	var row2: Control = c.find_child("Row2", true, false)
	assert_true(row2.position.y + row2.size.y <= c.go_key.position.y, "the bars end above the key")
	assert_almost_eq((c.find_child("Row1", true, false) as Control).position.y - (c.find_child("Row0", true, false) as Control).position.y, EndCard.ROW_H * k, 0.01, "rows 24 apart")
	var cap: Control = c.find_child("Caption", true, false)
	assert_true(Rect2(Vector2.ZERO, pic.size).encloses(Rect2(cap.position, cap.size)), "the caption in the picture")
	assert_almost_eq(cap.position.y + cap.size.y, pic.size.y - 12.0 * k, 0.5, "12 up from its foot")
	assert_eq((c.find_child("TitleWord", true, false) as Label).get_theme_color("font_color"), EndCard.GOOD, "a good end's title in amber")


func test_its_parts_come_up_one_after_another_and_a_touch_has_them_all_up() -> void:
	var c = _card(false)
	assert_eq((c.find_child("Go", true, false) as Control).modulate.a, 0.0, "the key comes up last")
	assert_eq((c.find_child("Picture", true, false) as Control).modulate.a, 0.0, "the picture stamped in after the dark")
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	c._gui_input(up)
	for n in PARTS:
		assert_almost_eq((c.find_child(n, true, false) as Control).modulate.a, 1.0, 0.001, n + " up")
	var k: float = UiFonts.K
	assert_almost_eq(c.go_key.position + c.go_key.size, EndCard.TXT.end * k, Vector2(0.01, 0.01), "the key risen to its place")
	assert_almost_eq((c.find_child("Picture", true, false) as Control).position, EndCard.PIC.position * k, Vector2(0.01, 0.01), "the shake over")


func test_its_key_goes_on() -> void:
	var c = _card()
	watch_signals(c)
	c.go_key.pressed.emit()
	assert_signal_emitted(c, "went_on")
