extends "res://addons/gut/test.gd"
## The return receipt on paper (receipt_card.gd) and the promise line under the
## clock: they read the stop's record and the departure, count the dead without
## naming them, and say what was seen of a promise, never whether it held.

const FieldGame = preload("res://game/field_game.gd")
const ReceiptCard = preload("res://game/ui/receipt_card.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")

const V4 := "res://tests/game/fixtures/field_v4/"


func _json(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(V4 + name + ".json"))


func _result(receipt: Dictionary) -> Dictionary:
	return {"reason": "departed", "receipt": receipt, "stay": 160, "boarded": 4, "hordes": 0}


func _all_text(d: Dictionary) -> String:
	var bits: Array = [d["place"], d["stamp"], d["when"]]
	bits.append_array(d["head"])
	for column: Array in d["columns"]:
		bits.append(column[0])
		bits.append_array(column[1])
	bits.append_array(d["seen"])
	return " | ".join(bits)


func _game(extra: Dictionary = {}):
	var game = FieldGame.new()
	var opts := {"seed": 5, "raiders": false, "auto_pause": false}
	opts.merge(extra)
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	return game


func test_the_slip_reads_the_place_the_hours_and_what_was_seen() -> void:
	var d: Dictionary = ReceiptCard.rows(_result(_json("case1_symbol_kept")))
	assert_eq(d["stamp"], "출발")
	assert_eq(d["when"], "1일째 10:30 → 13:10", "one day, said once")
	assert_eq(d["head"][0], "다친 사람을 태우고 떠났다", "the leaving beat's own head line")
	assert_eq(d["seen"], ["약속 서막 · 본 사람 2 · 꼬리칸 들음", "상징물 · 꼬리칸의 것 · 든 사람 있음"])
	var plain: Dictionary = ReceiptCard.rows(_result(_json("skip_kept")))
	assert_eq(plain["seen"], ["약속 교대 · 본 사람 1 · 꼬리칸 들음"], "no symbol, no symbol line")


func test_the_dead_are_counted_and_never_named() -> void:
	var r: Dictionary = _json("witness_one_back")
	var d: Dictionary = ReceiptCard.rows(_result(r))
	var text := _all_text(d)
	assert_string_contains(text, "죽은 사람 1")
	for id in r["people"]["sent"]:
		assert_false(text.contains(String(id)), "no one by id: " + String(id))


func test_the_promise_line_says_each_promise_in_a_word_or_two() -> void:
	var prologue: Array = _json("departure_prologue")["promises"]
	var skip: Array = _json("departure_skip_kept")["promises"]
	assert_eq(ReceiptCard.promise_line(prologue), "약속: 서막 2명 데려오기")
	assert_eq(ReceiptCard.promise_line(skip), "약속: 교대 꼬리칸 파견 제외")
	assert_eq(ReceiptCard.promise_line(prologue + skip), "약속: 서막 2명 데려오기 / 교대 꼬리칸 파견 제외")
	assert_eq(ReceiptCard.promise_line([{"kind": "prologue", "state": "0/2"}]), "약속: 서막 0/2", "the train's own word first")
	assert_eq(ReceiptCard.promise_line([]), "")


func test_the_promise_line_is_up_only_with_promises() -> void:
	var plain = _game()
	assert_false(plain.hud.promise_label.get_parent().visible, "a stop with no promise has no line")
	var sent = _game({"departure": _json("departure_prologue")})
	assert_true(sent.hud.promise_label.get_parent().visible)
	assert_eq(sent.hud.promise_label.text.replace(UiFonts.WORD_JOINER, ""), "약속: 서막 2명 데려오기")
	sent.hud.set_promises([{"kind": "skip_dispatch", "state": "꼬리칸 쉼"}])
	assert_eq(sent.hud.promise_label.text.replace(UiFonts.WORD_JOINER, ""), "약속: 교대 꼬리칸 쉼")
	sent.hud.set_promises([])
	assert_false(sent.hud.promise_label.get_parent().visible)


func test_the_end_card_is_the_paper_slip_with_its_keys_under_it() -> void:
	var game = _game()
	var got: Array = []
	game.finished.connect(func(r): got.append(r))
	game.finish("departed")
	assert_eq(got.size(), 1)
	game.hud.show_end(got[0])
	assert_true(game.hud.modal_open)
	var slip: Control = game.hud.modal.find_child("Receipt", true, false)
	assert_not_null(slip, "the slip is on the card")
	var stamp: Control = slip.find_child("Stamp", true, false)
	assert_not_null(stamp)
	assert_eq((stamp as Label).text, "출발")
	var keys: Array = []
	for b in game.hud.modal.find_children("*", "Button", true, false):
		keys.append((b as Button).text)
	assert_eq(keys, ["영수증 복사", "기록 복사", "다시"])
	for b in game.hud.modal.find_children("*", "Button", true, false):
		assert_false(slip.is_ancestor_of(b), "the keys are glass, off the slip")
