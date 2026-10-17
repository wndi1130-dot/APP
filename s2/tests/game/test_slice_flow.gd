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
		assert_true(f.panel.visible, f.current() + " has its panel")
		if f.current() == "end":
			break
		f.next()
	assert_eq(seen, ["train", "stop_pick", "receipt", "council", "travel", "arrive", "end"], "the field is skipped here")
	assert_eq(phases, ["travel", "stop", "settle", "council", "travel", "stop", "end"])
	assert_eq(f.next_button.text, "처음으로 ›")


func test_the_receipt_panel_reads_the_sample_when_the_field_is_skipped() -> void:
	var f = _flow()
	f.next()
	f.next()
	assert_eq(f.current(), "receipt")
	assert_eq(f.title.text, "귀환 영수증")
	var texts := _texts(f)
	assert_true(texts[0].begins_with("first_leg_01_sulechow"), texts[0])
	assert_true(texts.any(func(t: String) -> bool: return t.begins_with("약속:")), "the promises are listed")
	assert_eq(SliceFlow.receipt_lines({}), ["영수증 없음"])


func test_after_the_field_a_key_goes_on_to_its_own_receipt() -> void:
	var f = _flow({"skip_field": false, "seed": 5})
	f.next()
	f.next()
	assert_eq(f.current(), "field")
	assert_not_null(f.field)
	assert_false(f.panel.visible, "nothing over the stop while it is played")
	f.field.set_process(false)
	f.field.finish("departed")
	assert_true(f.panel.visible, "a key over the end card")
	f.next()
	assert_eq(f.current(), "receipt")
	assert_eq(f.receipt, f.result["receipt"], "the field's own receipt")
	assert_ne(_texts(f)[0], "영수증 없음")


func test_the_boot_menu_has_the_slice_key() -> void:
	var boot = Boot.new()
	add_child_autofree(boot)
	assert_not_null(boot.find_child("SliceButton", true, false))
