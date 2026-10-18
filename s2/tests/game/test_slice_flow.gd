extends "res://addons/gut/test.gd"
## The slice's order of screens (slice_flow.gd): every step comes up in turn
## with the train behind it at the phase the step names, the receipt panel
## reads a receipt, and the boot menu has the key that starts it.

const SliceFlow = preload("res://game/slice_flow.gd")
const Boot = preload("res://game/boot.gd")


func _flow(extra: Dictionary = {}):
	var f = SliceFlow.new()
	var o := {"skip_field": true, "seed": 3}
	o.merge(extra, true)
	f.opts = o
	add_child_autofree(f)
	return f


func _texts(f) -> Array:
	var out: Array = []
	for l in f.lines.get_children():
		if not l.is_queued_for_deletion():
			out.append(String(l.text))
	return out


func test_the_steps_come_in_the_slice_order_with_the_train_behind_them() -> void:
	var f = _flow()
	var seen: Array = []
	var phases: Array = []
	while true:
		seen.append(f.current())
		phases.append(f.train.phase() if f.train != null else "")
		assert_true(f.panel.visible or f.card != null, f.current() + " has its panel or its screen")
		if f.current() == "end":
			break
		f.next()
	assert_eq(seen, ["train", "stop_pick", "receipt", "council", "travel", "arrive", "end"], "the field is skipped here")
	assert_eq(phases, ["travel", "stop", "settle", "council", "travel", "stop", "end"])
	assert_eq(f.next_button.text, "처음으로", "the main key draws its own arrow")


func test_the_receipt_step_is_the_paper_receipt_of_the_sample_when_the_field_is_skipped() -> void:
	var f = _flow()
	f.next()
	f.next()
	assert_eq(f.current(), "receipt")
	var slip: Control = f.panel.find_child("Receipt", true, false)
	assert_not_null(slip, "the paper receipt")
	var texts: Array = []
	for l in slip.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	assert_has(texts, "약속 서막 · 본 사람 2 · 꼬리칸 들음", "the sample's promise, as seen")
	assert_has(texts, "출발")
	var made: Dictionary = SliceFlow.result_of(f.receipt)
	assert_eq(made["stay"], 160)
	assert_eq(made["boarded"], 4, "sent less the dead, missing and left")
	f.next()
	assert_eq(f.current(), "council")
	assert_null(f.panel.find_child("Receipt", true, false), "gone with its step")


func test_after_the_field_a_key_goes_on_to_its_own_receipt() -> void:
	var f = _flow({"skip_field": false, "seed": 5})
	f.next()
	f.next()
	assert_eq(f.current(), "field")
	assert_not_null(f.field)
	assert_eq(f.field.hud.promise_label.text, "약속: 서막 2명 데려오기", "the field goes out with the sample departure")
	assert_false(f.panel.visible, "nothing over the stop while it is played")
	assert_false(f.weather.visible or f.film.visible, "the field brings its own weather")
	f.field.set_process(false)
	f.field.finish("departed")
	assert_true(f.panel.visible, "a key over the end card")
	f.next()
	assert_eq(f.current(), "receipt")
	assert_eq(f.receipt, f.result["receipt"], "the field's own receipt")
	assert_not_null(f.panel.find_child("Receipt", true, false))


func test_the_special_session_is_the_session_card_and_closing_it_goes_on() -> void:
	var f = _flow()
	f.go(f._index_of("council"))
	assert_eq(f.current(), "council")
	assert_not_null(f.card, "the session card stands in for the panel")
	assert_eq(String(f.card.name), "CouncilCard")
	assert_false(f.panel.visible)
	assert_false(f.weather.visible or f.frost.visible or f.film.visible, "the dining car is the room behind it, no snow")
	assert_eq(f.gauges.g, f.card.g, "the gauges read the session's state")
	assert_eq(f.gauges.focus, ["trust", "mood", "food", "lux"])
	f.card.cast()
	f.card.close()
	assert_eq(f.current(), "travel", "closed: on to the next stretch")
	assert_eq(f.gauges.g, f.train_g, "the slice's own state again")


func test_the_boot_menu_has_the_slice_key() -> void:
	var boot = Boot.new()
	add_child_autofree(boot)
	assert_not_null(boot.find_child("SliceButton", true, false))


func test_choosing_the_stop_is_the_paper_card_and_its_keys_go_on() -> void:
	var f = _flow()
	f.next()
	assert_eq(f.current(), "stop_pick")
	assert_not_null(f.card, "the stop card stands in for the panel")
	assert_false(f.panel.visible)
	assert_eq((f.card.find_child("Place", true, false) as Label).text, "술레후프")
	(f.card.find_child("Send", true, false) as Button).pressed.emit()
	assert_eq(f.current(), "receipt", "sent: the field (skipped here), then its receipt")
	assert_null(f.card, "gone with its step")
	var g = _flow()
	g.next()
	(g.card.find_child("PassBy", true, false) as Button).pressed.emit()
	assert_eq(g.current(), "travel", "passed by: on to the next stretch")
