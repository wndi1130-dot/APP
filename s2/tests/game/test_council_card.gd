extends "res://addons/gut/test.gd"
## The special session (council_card.gd): it says what the politics port says
## for the session it is given (the slice's sample, field_vectors.json), its
## lever casts the port's vote, and closing hands on the state the port leaves.

const CouncilCard = preload("res://game/ui/council_card.gd")
const CouncilVote = preload("res://game/politics/council_vote.gd")
const SliceSamples = preload("res://tests/game/slice_samples.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const FieldHud = preload("res://game/ui/field_hud.gd")
const DEALS := "res://tests/fixtures/train/deal_vectors.json"


func _card(g: Dictionary = {}, t: Dictionary = {}):
	var s: Array = SliceSamples.council_sample()
	var c = CouncilCard.new()
	c.g = g if not g.is_empty() else s[0]
	c.t = t if not t.is_empty() else s[1]
	add_child_autofree(c)
	return c


## The words of the labels under `n`, without the joiners that keep words whole.
func _said(n: Node) -> Array:
	var out: Array = []
	for l in n.find_children("*", "Label", true, false):
		if not l.is_queued_for_deletion():
			out.append(String((l as Label).text).replace(UiFonts.WORD_JOINER, ""))
	return out


func test_the_card_says_what_the_port_says_for_the_sample_session() -> void:
	var s: Array = SliceSamples.council_sample()
	var g: Dictionary = s[0]
	var t: Dictionary = s[1]
	assert_false(g.is_empty(), "the port's sample opens a session for the slice's departure and receipt")
	var m: Dictionary = CouncilCard.model(g, t, 0)
	var agenda: Dictionary = g["council"]["options"][0]
	assert_eq(m["count"], 3, "three agendas on the table")
	assert_eq(m["title"], CouncilVote.agenda_title(t, agenda))
	assert_eq(m["need"], CouncilVote.agenda_need(t, agenda))
	var map: Dictionary = CouncilVote.blocs(g, t, agenda, [])
	var ex: Dictionary = CouncilVote.expected(map, t)
	assert_eq([m["got"], m["max"]], [int(ex["min"]), int(ex["max"])])
	var seats: int = 0
	for c: Dictionary in m["comms"]:
		var b: Dictionary = map[c["id"]]
		assert_eq([c["yes"], c["und"], c["no"], c["hard"], c["absent"]],
				[int(b["yes"]), int(b["und"]), int(b["no"]), int(b["hard"]), int(b["absent"])], String(c["id"]))
		seats += int(c["seats"])
	assert_eq(seats, m["total"])
	assert_true(m["special"], "the session after the first return")
	assert_eq(m["changes"], [["가결", "꼬리칸 관계", "+5"], ["부결", "꼬리칸 관계", "−5"]], "the symbol's motion: what passing and failing do")


func test_a_law_s_lines_split_as_the_mockup_s_bill() -> void:
	var t: Dictionary = SliceSamples.council_sample()[1]
	assert_eq(CouncilCard.change_rows(t, {"law": "contribution_ration"}), [
		["식량 절약", "구간마다", "+1.5"], ["기관실·경비대", "배급", "+10"], ["앞칸", "배급", "−10"], ["꼬리칸·의무진", "배급", "−5"]])
	assert_eq(CouncilCard.split_change("식량 +30(한 번)"), ["식량", "한 번", "+30"])
	assert_eq(CouncilCard.split_change("더운물 석탄 ×0.8"), ["더운물", "석탄", "×0.8"])
	assert_eq(CouncilCard.split_change("공포 +2"), ["공포", "", "+2"])
	assert_eq(CouncilCard.split_change("모든 칸 배급 높음 아래로 못 내림"), ["모든 칸 배급 높음 아래로 못 내림", "", ""], "no number: whole")
	var two := "사람이 죽은 구간의 밤: 공포 −2, 긴장 −2, 그 사람의 칸 관계 +3"
	assert_eq(CouncilCard.split_change(two), [two, "", ""], "more than one change: whole")
	assert_eq(CouncilCard.sign_of(-5.0), "−5", "a true minus")
	assert_eq(CouncilCard.sign_of(1.5), "+1.5")
	assert_eq(CouncilCard.stance_of(2), ["y", "찬성"])
	assert_eq(CouncilCard.stance_of(0), ["", "망설임"])
	assert_eq(CouncilCard.stance_of(-1), ["n", "반대 쪽"])


func test_the_bill_turns_between_agendas_and_a_group_opens_its_pane() -> void:
	var c = _card()
	assert_has(_said(c.bill), "특별", "a special session says so in a word (결정 417)")
	var prev: Button = c.bill.find_child("Prev", true, false)
	var nxt: Button = c.bill.find_child("Next", true, false)
	assert_true(prev.disabled, "the first agenda: nothing before it")
	assert_false(nxt.disabled)
	nxt.pressed.emit()
	assert_eq(c.idx, 1)
	assert_eq(c.m["title"], CouncilVote.agenda_title(c.t, c.g["council"]["options"][1]))
	# The groups' list by its columns (no 「집단별 표」 over them: 결정 417).
	assert_has(_said(c.pane), "미정")
	c.board.picked.emit(0)
	assert_eq(c.sel, 0)
	var fold: Button = c.pane.find_child("Fold", true, false)
	assert_not_null(fold, "the group's own pane")
	assert_has(_said(c.pane), String(c.m["comms"][0]["role"]))
	fold.pressed.emit()
	assert_eq(c.sel, -1)
	assert_not_null(c.pane.find_child("Row_tail", true, false), "folded: the list again")


func test_the_lever_casts_the_port_s_vote_and_closing_hands_on_its_state() -> void:
	var c = _card()
	var gi: Dictionary = c.g.duplicate(true)
	gi["council"]["idx"] = 0
	var want: Dictionary = CouncilVote.cast_vote(gi, c.t)["result"]
	c.bar.main_pressed.emit()
	assert_eq([c.result["yes"], c.result["no"], c.result["passed"]], [want["yes"], want["no"], want["passed"]])
	assert_true(c.board.revealing(), "the stones turn")
	assert_eq(c.bar.main_word, "확인", "the lever stays down on 확인")
	assert_true((c.bill.find_child("Prev", true, false) as Button).disabled, "no turning the bill after the vote")
	c.board.finish_reveal()
	# The count's list: yes and no only (no 「집단별 결과」: 결정 417).
	assert_does_not_have(_said(c.pane), "미정")
	assert_has(_said(c.pane), "반대")
	var got: Array = []
	c.left.connect(func(g2: Dictionary) -> void: got.append(g2))
	c.bar.main_pressed.emit()
	assert_eq(got.size(), 1)
	assert_eq(got[0]["phase"], c.g["fieldReturns"]["special"]["back"], "back to where the session was called from")
	assert_eq(got[0]["fieldReturns"]["special"]["result"]["passed"], want["passed"])


func test_a_long_law_sets_its_lines_tight_and_scrolls_the_rest_on_its_paper() -> void:
	var s: Array = SliceSamples.council_sample()
	var g: Dictionary = (s[0] as Dictionary).duplicate(true)
	g["council"]["options"] = [{"law": "contribution_ration", "repeal": false}, {"law": "corpse_burn", "repeal": false}]
	var c = _card(g, s[1])
	assert_eq(c.bill_scroll_max, 0.0, "the mockup's own bill fits its paper")
	assert_almost_eq(c.bill.size.y / UiFonts.K, CouncilCard.BILL_SIZE.y, 0.5)
	c.turn(1)
	assert_gt(c.bill_scroll_max, 0.0, "the longest law a session holds runs past its paper")
	assert_almost_eq(c.bill.size.y / UiFonts.K, CouncilCard.BILL_MAX_H, 0.5, "grown down to the band")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	for i in 20:
		c._rows_input(wheel)
	assert_eq(c.bill_scroll, c.bill_scroll_max, "scrolled no further than its last line")
	# Its sentences break between words only (the mockup's keep-all).
	var wrapped: int = 0
	for l: Label in c.bill.find_children("*", "Label", true, false):
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF or l.is_queued_for_deletion():
			continue
		wrapped += 1
		var para := TextParagraph.new()
		para.width = l.size.x
		para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		para.add_string(l.text, l.get_theme_font("font"), l.get_theme_font_size("font_size"))
		for i in para.get_line_count() - 1:
			var end: int = para.get_line_range(i).y
			assert_eq(l.text[end - 1], " ", "%s: line %d ends on a space" % [l.text.replace(UiFonts.WORD_JOINER, ""), i])
	assert_gt(wrapped, 0, "its long lines wrap")


func test_keep_all_joins_the_letters_of_a_word_only() -> void:
	var wj: String = UiFonts.WORD_JOINER
	assert_eq(UiFonts.keep_all("못 내림"), "못 내" + wj + "림")
	assert_eq(UiFonts.keep_all("못 내림").replace(wj, ""), "못 내림")

## A session with the deal tables (s1/tools/deal_port_fixtures.ts: 난방 배당 on the
## table, the coal under the crisis line, luxuries, debts and secrets in hand).
func _dealing():
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEALS))
	for row: Dictionary in d["cases"]:
		if row["name"] == "status/deal-0/heat_quota/tail/open":
			return _card(row["before"], d["tables"])
	return null


func test_the_field_sample_has_no_deal_tables_and_no_tools() -> void:
	var c = _card()
	assert_false(c.m["dealing"])
	c.board.picked.emit(0)
	assert_null(c.pane.find_child("Tool_open", true, false))
	assert_null(c.bill.find_child("Deals", true, false))


func test_the_picked_group_has_six_tools_a_finger_takes() -> void:
	var c = _dealing()
	assert_true(c.m["dealing"])
	assert_eq(c.bill.find_child("Deals", true, false).text, "0/3", "the bill counts the deals")
	c.board.picked.emit(0)
	for tool_row: Array in CouncilCard.TOOLS:
		var b: Button = c.pane.find_child("Tool_" + String(tool_row[0]), true, false)
		assert_not_null(b, String(tool_row[0]))
		assert_gte(b.size.y, FieldHud.MIN_TOUCH - 0.01, String(tool_row[0]) + " tall enough")
		assert_gte(b.size.x, FieldHud.MIN_TOUCH * 0.6, String(tool_row[0]))
	var deal: Button = c.pane.find_child("Deal", true, false)
	assert_gte(deal.size.y, FieldHud.MIN_TOUCH - 0.01, "거래 tall enough")
	(c.pane.find_child("Tool_bribe", true, false) as Button).pressed.emit()
	var st: Dictionary = CouncilVote.tool_status(c.g, c.t, "tail", "bribe")
	assert_eq(c.pane.find_child("DealCost", true, false).text, st["cost"], "the tool's cost as the port says")
	(c.pane.find_child("Tool_favor", true, false) as Button).pressed.emit()
	st = CouncilVote.tool_status(c.g, c.t, "tail", "favor")
	assert_false(st["ok"])
	assert_eq(c.pane.find_child("DealLine", true, false).text, st["why"], "why not, in a line")
	assert_true((c.pane.find_child("Deal", true, false) as Button).disabled)


func test_a_deal_moves_the_votes_holds_the_agenda_and_counts_on_the_bill() -> void:
	var c = _dealing()
	c.board.picked.emit(0)
	(c.pane.find_child("Tool_bribe", true, false) as Button).pressed.emit()
	var want: Dictionary = CouncilVote.make_deal(c.g, c.t, "tail", "bribe")
	assert_gt(c.board._pre.size(), 0, "the seats the bribe would bring ring on the board")
	(c.pane.find_child("Deal", true, false) as Button).pressed.emit()
	assert_eq(c.g["council"]["deals"], want["g"]["council"]["deals"], "the port's own deal")
	assert_eq(c.m["deals"], 1)
	var b: Dictionary = CouncilVote.blocs(c.g, c.t, c.g["council"]["options"][0], c.g["council"]["deals"])["tail"]
	assert_eq([c.m["comms"][0]["yes"], c.m["comms"][0]["pool"]], [int(b["yes"]), int(b["pool"])])
	assert_has(c.board.kinds[0], "p", "the votes the leader brings on the board")
	assert_eq(c.bill.find_child("Deals", true, false).text, "1/3")
	assert_true((c.bill.find_child("Next", true, false) as Button).disabled, "the agenda holds once a deal is made")
	assert_eq(c.pane.find_child("DealLine", true, false).text, String(want["text"]), "what the deal came to")
	# The vote counts it: the lever casts with the deal in hand.
	var gi: Dictionary = c.g.duplicate(true)
	var cast: Dictionary = CouncilVote.cast_vote(gi, c.t)["result"]
	c.bar.main_pressed.emit()
	assert_eq([c.result["yes"], c.result["no"]], [cast["yes"], cast["no"]])


func test_open_asks_its_condition_and_a_cut_its_car() -> void:
	var c = _dealing()
	c.board.picked.emit(1)
	assert_eq(c.tool, "open", "the first tool it can use")
	(c.pane.find_child("Deal", true, false) as Button).pressed.emit()
	var conds: Array = CouncilVote.open_conditions(c.g, c.t, "medtech")
	for i in conds.size():
		var row: Button = c.pane.find_child("Cond_%d" % i, true, false)
		assert_not_null(row, "condition %d" % i)
		assert_gte(row.size.y, FieldHud.MIN_TOUCH - 0.01)
	assert_eq(conds[2]["kind"], "cut", "the sample's common condition is the cut")
	(c.pane.find_child("Cond_2", true, false) as Button).pressed.emit()
	assert_null(c.pane.find_child("Cut_medtech", true, false), "not its own car")
	assert_not_null(c.pane.find_child("Cut_tail", true, false))
	(c.pane.find_child("Fold", true, false) as Button).pressed.emit()
	assert_not_null(c.pane.find_child("Tool_open", true, false), "접기 goes back a step")
	(c.pane.find_child("Deal", true, false) as Button).pressed.emit()
	(c.pane.find_child("Cond_2", true, false) as Button).pressed.emit()
	var want: Dictionary = CouncilVote.make_deal(c.g, c.t, "medtech", "open", 2, "engine")
	(c.pane.find_child("Cut_engine", true, false) as Button).pressed.emit()
	assert_eq(c.g["council"]["deals"], want["g"]["council"]["deals"])
	assert_eq(c.g["comms"]["engine"]["rel"], want["g"]["comms"]["engine"]["rel"], "the cut is paid now")
