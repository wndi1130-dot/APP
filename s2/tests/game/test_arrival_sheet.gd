extends "res://addons/gut/test.gd"
## The second station on the stop's sheet (arrival_sheet.gd): it says what the
## port's arrival summary says for the slice's sample, in whole numbers as the
## band shows them, the session's slip beside it from the session's record,
## who did not come back as a count only, and its key goes on.

const ArrivalSheet = preload("res://game/ui/arrival_sheet.gd")
const PaperSheet = preload("res://game/ui/paper_sheet.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")


func _sheet(g1: Dictionary = {}, word: String = "끝 카드"):
	var s: Array = SliceFlow.arrival_sample()
	var c = ArrivalSheet.new()
	c.g = g1 if not g1.is_empty() else s[0]
	c.t = s[1]
	c.go_word = word
	add_child_autofree(c)
	return c


func _said(n: Node) -> Array:
	var out: Array = []
	for l in n.find_children("*", "Label", true, false):
		out.append(String((l as Label).text).replace(UiFonts.WORD_JOINER, ""))
	return out


func test_the_sheet_says_what_the_arrival_summary_says() -> void:
	var s: Array = SliceFlow.arrival_sample()
	var m: Dictionary = ArrivalSheet.model(s[0], s[1])
	assert_eq(m["seg"], 3)
	assert_false(m.has("kick"), "no 「구간 정차 · 도착」 kick (결정 417)")
	assert_eq(m["title"], "둘째 역")
	assert_eq(m["arrive"], "3구간, 둘째 역에 닿았다. 첫 정차에서 1구간을 달려왔다.")
	assert_eq(m["columns"][0], ["사람", [["다친 사람", "1", "+1"]]])
	assert_eq(m["columns"][1], ["물자", [["석탄", "96", "−2"], ["식량", "99", "−7"], ["의약품", "20", "그대로"], ["사치품", "9", "그대로"]]])
	assert_eq(m["columns"][2], ["온기", [["칸마다 온기는 그대로다.", "", ""]]], "no car's warmth moved: the summary's own line")
	assert_eq(m["seen"][0], ["symbol", "꼬리칸의 상징물을 가져왔다. 쓰임을 고른다."])
	assert_eq(m["seen"][2], ["promise", "꼬리칸과의 약속을 지켰다: 저탄장 운반조를 다 데려온다. 본 사람 2명이 돌아와 말했다."], "the port's two-way particle settled")
	assert_eq(ArrivalSheet.model({}, s[1]), {}, "no state, nothing to say")


func test_the_slip_is_the_session_s_record() -> void:
	var s: Array = SliceFlow.arrival_sample()
	var c: Dictionary = ArrivalSheet.model(s[0], s[1])["council"]
	assert_true(c["open"])
	assert_eq(c["seg"], 2)
	assert_eq(c["title"], "꼬리칸의 상징물을 열차 앞에 세우기")
	assert_eq(c["stamp"], "가결")
	assert_eq(c["votes"], [["찬성", 71], ["반대", 26], ["필요", 51]])
	assert_eq(c["rows"], [["신임", "", "52"], ["긴장", "", "23"], ["꼬리칸 관계", "−5", "0"]], "what did not move says only where it stands")
	var none: Dictionary = ArrivalSheet.council_of(null, s[1], ["꼬리칸과(와)의 회기"])
	assert_eq(none, {"open": false, "line": "꼬리칸과의 회기"}, "no session: the summary's own line")


func test_numbers_are_whole_as_the_band_shows_them() -> void:
	assert_eq(ArrivalSheet.whole(95.5125), "96")
	assert_eq(ArrivalSheet.whole(-5.0), "−5", "a minus sign, not a hyphen")
	assert_eq(ArrivalSheet.moved(98.0, 95.5125), "−2", "between the whole numbers shown")
	assert_eq(ArrivalSheet.moved(20.0, 20.4), "그대로")
	assert_eq(ArrivalSheet.moved(0.0, 1.0), "+1")
	assert_eq(ArrivalSheet.change_row("신임", 52.0, 52.2), ["신임", "", "52"])
	assert_eq(ArrivalSheet.change_row("긴장", 23.0, 21.0), ["긴장", "23", "21"])


func test_the_sheet_lies_where_the_stop_card_lies_and_its_key_goes_on() -> void:
	var c = _sheet()
	assert_eq(c.sheet.position, ArrivalSheet.SHEET_AT * UiFonts.K)
	assert_eq(c.sheet.size, PaperSheet.SIZE * UiFonts.K, "the stop card's sheet, 446 × 346")
	for n in ["Place", "Arrive", "Columns", "Go"]:
		assert_not_null(c.find_child(n, true, false), n)
	assert_not_null(c.slip, "the session's slip beside it")
	assert_eq(c.go_key.text, "끝 카드")
	var said: Array = _said(c)
	assert_has(said, "둘째 역")
	assert_has(said, "가결", "what the session came to, stamped")
	watch_signals(c)
	c.go_key.pressed.emit()
	assert_signal_emitted(c, "went_on")


func test_all_it_writes_stays_on_the_paper_in_the_game_s_faces() -> void:
	var c = _sheet()
	await wait_frames(3)
	var inner: Control = c.sheet.inner
	var room := Rect2(Vector2.ZERO, inner.size).grow(1.0)
	var least: int = UiFonts.size(12.0)
	for l in c.sheet.find_children("*", "Label", true, false):
		var lab := l as Label
		if lab.text.strip_edges() == "":
			continue
		# Where it is in the paper's own frame (the sheet leans as a whole).
		var at: Vector2 = lab.get_global_transform().origin - inner.get_global_transform().origin
		var r := Rect2(at.rotated(-c.sheet.rotation), lab.size)
		assert_true(room.encloses(r), "%s inside the paper: %s in %s" % [lab.text, r, room])
		var f: Font = lab.get_theme_font("font")
		assert_true(f is FontVariation and String((f as FontVariation).base_font.resource_path).begins_with(UiFonts.DIR), lab.text + " in the game's own face")
		assert_true(lab.get_theme_font_size("font_size") >= least, lab.text + " no smaller than 12")


func test_who_did_not_come_back_is_a_count_never_a_name() -> void:
	var s: Array = SliceFlow.arrival_sample()
	var g1: Dictionary = (s[0] as Dictionary).duplicate(true)
	g1["fieldReturns"]["records"][0]["dead"] = ["p_152"]
	var m: Dictionary = ArrivalSheet.model(g1, s[1])
	assert_eq(m["columns"][0][1][0], [ArrivalSheet.DEAD_WORD, "1", ""])
	var c = _sheet(g1)
	for said in _said(c):
		assert_false(String(said).contains("p_152"), "a number, never a name")
