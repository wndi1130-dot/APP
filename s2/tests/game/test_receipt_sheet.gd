extends "res://addons/gut/test.gd"
## The return receipt on the stop's sheet (receipt_sheet.gd): it says what the
## stop's own record says (S3 영수증 판 4 표본), lies where the stop card lies,
## keeps all it writes on the paper in the game's own faces, and its key goes on.

const ReceiptSheet = preload("res://game/ui/receipt_sheet.gd")
const PaperSheet = preload("res://game/ui/paper_sheet.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")

const FIX := "res://tests/game/fixtures/field_v4/"


func _receipt(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIX + name + ".json"))


func _sheet(result: Dictionary = {}, word: String = "특별 회기"):
	var c = ReceiptSheet.new()
	c.result = result if not result.is_empty() else SliceFlow.result_of(_receipt("case1_symbol_kept"))
	c.go_word = word
	add_child_autofree(c)
	return c


func _said(n: Node) -> Array:
	var out: Array = []
	for l in n.find_children("*", "Label", true, false):
		out.append(String((l as Label).text).replace(UiFonts.WORD_JOINER, ""))
	return out


func test_the_sheet_says_what_the_stop_s_record_says() -> void:
	var m: Dictionary = ReceiptSheet.model(SliceFlow.result_of(_receipt("case1_symbol_kept")), 1)
	assert_eq(m["seg"], 1)
	assert_false(m.has("kick"), "no 「구간 정차 · 귀환 영수증」 kick (결정 417)")
	assert_eq(m["place"], "술레후프")
	assert_eq(m["stamp"], "출발")
	assert_eq(m["when"], "1일째 10:30 → 13:10", "the same day said once")
	assert_eq(m["head"][0], "다친 사람을 태우고 떠났다", "one of the four came back hurt")
	assert_eq(m["columns"][0], ["실은 것", ["석탄 6", "식량 3", "상징물 1"]])
	assert_eq(m["columns"][1], ["탄 사람", ["4명", "모두 탔다"]])
	assert_eq(m["seen"], ["약속 서막 · 본 사람 2 · 꼬리칸 들음", "상징물 · 꼬리칸의 것 · 든 사람 있음"])
	assert_false(m.has("note"), "no line on who calls the promise (결정 417): no stamp on it says so")
	assert_eq(ReceiptSheet.model({}), {}, "no receipt, nothing to say")


func test_numbers_keep_what_joins_their_digits() -> void:
	assert_eq(ReceiptSheet.num_runs("1일째 10:30 → 13:10"), [["1", true], ["일째 ", false], ["10:30", true], [" → ", false], ["13:10", true]])
	assert_eq(ReceiptSheet.num_runs("4명"), [["4", true], ["명", false]])
	assert_eq(ReceiptSheet.num_runs("모두 탔다"), [["모두 탔다", false]])


func test_the_sheet_lies_where_the_stop_card_lies_and_its_key_goes_on() -> void:
	var c = _sheet()
	assert_eq(c.sheet.position, ReceiptSheet.SHEET_AT * UiFonts.K)
	assert_eq(c.sheet.size, PaperSheet.SIZE * UiFonts.K, "the stop card's sheet, 446 × 346")
	for n in ["Place", "Stamp", "Head", "Stay", "Columns", "Seen", "When", "Go"]:
		assert_not_null(c.find_child(n, true, false), n)
	assert_eq(c.go_key.text, "특별 회기")
	var said: Array = _said(c)
	assert_has(said, "출발")
	assert_has(said, "다친 사람을 태우고 떠났다")
	watch_signals(c)
	c.go_key.pressed.emit()
	assert_signal_emitted(c, "went_on")


func test_all_it_writes_stays_on_the_paper_in_the_game_s_faces() -> void:
	var c = _sheet()
	await wait_frames(3)
	var inner: Control = c.sheet.inner
	var room := Rect2(Vector2.ZERO, inner.size).grow(1.0)
	var least: int = UiFonts.size(12.0)
	for l in c.find_children("*", "Label", true, false):
		var lab := l as Label
		if lab.text.strip_edges() == "":
			continue
		# Where it is in the paper's own frame (the sheet leans as a whole).
		var at: Vector2 = lab.get_global_transform().origin - inner.get_global_transform().origin
		var r := Rect2(at.rotated(-c.sheet.rotation), lab.size)
		if lab.name != "Stamp":
			assert_true(room.encloses(r), "%s inside the paper: %s in %s" % [lab.text, r, room])
		var f: Font = lab.get_theme_font("font")
		assert_true(f is FontVariation and String((f as FontVariation).base_font.resource_path).begins_with(UiFonts.DIR), lab.text + " in the game's own face")
		assert_true(lab.get_theme_font_size("font_size") >= least, lab.text + " no smaller than 12")
	var key: Rect2 = Rect2(c.go_key.get_global_transform().origin - inner.get_global_transform().origin, c.go_key.size)
	key.position = key.position.rotated(-c.sheet.rotation)
	assert_true(room.encloses(key), "the key on the paper: %s in %s" % [key, room])


func test_a_harder_stop_says_its_dead_as_a_count_only() -> void:
	var r: Dictionary = _receipt("case2_symbol_broken")
	r["people"]["dead"] = ["p_152"]
	var result: Dictionary = SliceFlow.result_of(r)
	var m: Dictionary = ReceiptSheet.model(result)
	assert_eq(m["head"][0], "돌아오지 못한 사람이 있다")
	assert_has(m["columns"][2][1], "죽은 사람 1")
	var c = _sheet(result)
	for s in _said(c):
		assert_false(String(s).contains("p_152"), "a number, never a name")
