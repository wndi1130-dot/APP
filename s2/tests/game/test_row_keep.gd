extends "res://addons/gut/test.gd"
## Row identity, input and motion without waiting for wall time.

const RowKeep = preload("res://game/ui/row_keep.gd")
const PaneMotion = preload("res://game/ui/pane_motion.gd")

var _list: Control
var _made: int = 0


func before_each() -> void:
	_made = 0
	_list = Control.new()
	add_child_autofree(_list)


func _make(id: String) -> Control:
	_made += 1
	var row := Control.new()
	row.size = Vector2(120, 30)
	var button := Button.new()
	button.name = "Key"
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(button)
	var word := Label.new()
	word.name = "Word"
	word.text = id
	word.mouse_filter = Control.MOUSE_FILTER_STOP
	word.focus_mode = Control.FOCUS_ALL
	button.add_child(word)
	return row


func _fill(row: Control, id: String, index: int) -> void:
	row.position = Vector2(0, 30 * index)
	(row.get_node("Key/Word") as Label).text = id


func _sync(ids: Array) -> void:
	RowKeep.sync(_list, ids, _make, _fill)


func _item(id: String) -> Control:
	return _list.get_node("Item_" + id) as Control


func _step(row: Control, seconds: float) -> void:
	var tween: Tween = row.get_meta(RowKeep.TWEEN_META)
	tween.pause()
	tween.custom_step(seconds)


func _settle() -> void:
	for child: Node in _list.get_children():
		if child is Control and child.has_meta(RowKeep.TWEEN_META):
			var tween: Tween = child.get_meta(RowKeep.TWEEN_META)
			if tween.is_valid():
				_step(child, maxf(RowKeep.ADD_S, RowKeep.MOVE_S))


func test_same_ids_keep_the_rows_controls_focus_and_pressed_state() -> void:
	_sync(["a", "b"])
	_settle()
	var row: Control = _item("b")
	var key: Button = row.get_node("Key") as Button
	var row_id: int = row.get_instance_id()
	var key_id: int = key.get_instance_id()
	key.set_pressed_no_signal(true)
	key.grab_focus()
	_sync(["a", "b"])
	assert_eq(_made, 2)
	assert_eq(_item("b").get_instance_id(), row_id)
	assert_eq((_item("b").get_node("Key") as Button).get_instance_id(), key_id)
	assert_true(key.button_pressed)
	assert_true(key.has_focus())


func test_one_added_id_only_makes_that_row_and_starts_at_its_target() -> void:
	_sync(["a"])
	_settle()
	var row_id: int = _item("a").get_instance_id()
	_sync(["a", "b"])
	var added: Control = _item("b")
	assert_eq(_made, 2)
	assert_eq(_item("a").get_instance_id(), row_id)
	assert_eq(added.position, Vector2(0, 30))
	assert_almost_eq(added.modulate.a, 0.0, 0.00001)
	_step(added, RowKeep.ADD_S * 0.5)
	assert_gt(added.modulate.a, 0.0)
	assert_lt(added.modulate.a, 1.0)
	_step(added, RowKeep.ADD_S * 0.5)
	assert_almost_eq(added.modulate.a, 1.0, 0.00001)
	assert_eq(added.position, Vector2(0, 30))


func test_removed_id_renames_blocks_every_child_and_frees_after_its_fade() -> void:
	_sync(["a", "b"])
	_settle()
	var leaving: Control = _item("a")
	var key: Button = leaving.get_node("Key") as Button
	key.grab_focus()
	_sync(["b"])
	assert_true(String(leaving.name).begins_with("Leaving_"))
	assert_false(_list.has_node("Item_a"))
	assert_eq(leaving.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(leaving.focus_mode, Control.FOCUS_NONE)
	assert_eq(key.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(key.focus_mode, Control.FOCUS_NONE)
	assert_true(key.disabled)
	assert_false(key.has_focus())
	var word: Control = key.get_node("Word") as Control
	assert_eq(word.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(word.focus_mode, Control.FOCUS_NONE)
	_sync(["a", "b"])
	assert_ne(_item("a").get_instance_id(), leaving.get_instance_id())
	assert_eq(String(_item("a").name), "Item_a")
	_step(leaving, RowKeep.REMOVE_S * 0.5)
	assert_true(is_instance_valid(leaving))
	assert_gt(leaving.modulate.a, 0.0)
	_step(leaving, RowKeep.REMOVE_S * 0.5)
	assert_almost_eq(leaving.modulate.a, 0.0, 0.00001)
	assert_true(leaving.is_queued_for_deletion())
	await wait_process_frames(1)
	assert_false(is_instance_valid(leaving))
	assert_eq(String(_item("a").name), "Item_a")


func test_reorder_finishes_at_the_exact_targets() -> void:
	_sync(["a", "b", "c"])
	_settle()
	var first_id: int = _item("a").get_instance_id()
	_sync(["c", "b", "a"])
	assert_eq(_item("a").position, Vector2.ZERO)
	assert_eq(_item("c").position, Vector2(0, 60))
	_step(_item("a"), RowKeep.MOVE_S)
	_step(_item("c"), RowKeep.MOVE_S)
	assert_eq(_item("a").position, Vector2(0, 60))
	assert_eq(_item("b").position, Vector2(0, 30))
	assert_eq(_item("c").position, Vector2.ZERO)
	assert_eq(_item("a").get_instance_id(), first_id)


func test_sync_while_quiet_blocks_new_rows_until_the_pane_opens() -> void:
	PaneMotion.quiet(_list)
	_sync(["a"])
	_settle()
	var row: Control = _item("a")
	var key: Button = row.get_node("Key") as Button
	var word: Control = key.get_node("Word") as Control
	for control: Control in [row, key, word]:
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(control.focus_mode, Control.FOCUS_NONE)
	assert_false(key.disabled)
	var tween: Tween = PaneMotion.open(_list)
	tween.pause()
	tween.custom_step(PaneMotion.OPEN_S)
	assert_eq(row.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(key.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(key.focus_mode, Control.FOCUS_ALL)
	assert_eq(word.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(word.focus_mode, Control.FOCUS_ALL)


func test_finish_while_quiet_blocks_new_parts_and_pass_mouse_until_open() -> void:
	PaneMotion.quiet(_list)
	RowKeep.begin(_list)
	var scroll: ScrollContainer = RowKeep.part(_list, "List", func() -> Control: return ScrollContainer.new()) as ScrollContainer
	RowKeep.pass_mouse(scroll)
	var rows: Control = RowKeep.part(scroll, "Rows", func() -> Control: return Control.new())
	RowKeep.pass_mouse(rows)
	var choice: Button = RowKeep.part(rows, "Choice", func() -> Control: return Button.new()) as Button
	choice.focus_mode = Control.FOCUS_ALL
	RowKeep.finish(_list)
	# A later fill must not overwrite the saved PASS values with IGNORE.
	RowKeep.pass_mouse(scroll)
	RowKeep.pass_mouse(rows)
	RowKeep.finish(_list)
	for control: Control in [scroll, rows, choice]:
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(control.focus_mode, Control.FOCUS_NONE)
	var tween: Tween = PaneMotion.open(_list)
	tween.pause()
	tween.custom_step(PaneMotion.OPEN_S)
	assert_eq(scroll.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(rows.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(choice.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(choice.focus_mode, Control.FOCUS_ALL)
	assert_false(choice.disabled)


func test_retiring_ancestor_blocks_new_rows_and_parts() -> void:
	# The retiring marker alone is enough, even through a non-Control parent.
	_list.set_meta(PaneMotion.META_RETIRING, true)
	var bridge := Node.new()
	_list.add_child(bridge)
	var rows := Control.new()
	bridge.add_child(rows)
	RowKeep.pass_mouse(rows)
	RowKeep.sync(rows, ["a"], _make, _fill)
	var key: Button = rows.get_node("Item_a/Key") as Button
	assert_eq(rows.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(key.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(key.focus_mode, Control.FOCUS_NONE)
	RowKeep.begin(rows)
	var choice: Control = RowKeep.part(rows, "Choice", func() -> Control: return Button.new())
	RowKeep.finish(rows)
	assert_eq(choice.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(choice.focus_mode, Control.FOCUS_NONE)


func test_open_after_quiet_and_remove_keeps_leaving_descendants_blocked() -> void:
	_sync(["a"])
	_settle()
	var leaving: Control = _item("a")
	var key: Button = leaving.get_node("Key") as Button
	var word: Control = key.get_node("Word") as Control
	PaneMotion.quiet(_list)
	_sync([])
	_step(leaving, RowKeep.REMOVE_S * 0.5)
	var tween: Tween = PaneMotion.open(_list)
	tween.pause()
	tween.custom_step(PaneMotion.OPEN_S)
	assert_eq(_list.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_true(leaving.has_meta(RowKeep.LEAVING_META))
	for control: Control in [leaving, key, word]:
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(control.focus_mode, Control.FOCUS_NONE)
	assert_true(key.disabled)


func test_id_returning_during_retirement_has_only_one_visible_row() -> void:
	_sync(["a"])
	_settle()
	var leaving: Control = _item("a")
	_sync([])
	_step(leaving, RowKeep.REMOVE_S * 0.5)
	assert_true(leaving.visible)
	assert_gt(leaving.modulate.a, 0.0)
	_sync(["a"])
	var replacement: Control = _item("a")
	_step(replacement, RowKeep.ADD_S)
	assert_eq(_made, 2)
	assert_ne(replacement.get_instance_id(), leaving.get_instance_id())
	assert_eq(String(replacement.name), "Item_a")
	assert_false(leaving.visible)
	var visible_rows: int = 0
	for child: Node in _list.get_children():
		if child is Control and child.visible and child.get_meta(RowKeep.ID_META, "") == "a":
			visible_rows += 1
	assert_eq(visible_rows, 1)


func test_add_and_remove_slide_survivors_and_new_rows_do_not_fly_in() -> void:
	_sync(["a", "b"])
	_settle()
	_sync(["c", "a", "b"])
	assert_eq(_item("c").position, Vector2.ZERO)
	assert_eq(_item("a").position, Vector2.ZERO)
	_step(_item("a"), RowKeep.MOVE_S)
	_step(_item("b"), RowKeep.MOVE_S)
	assert_eq(_item("a").position, Vector2(0, 30))
	assert_eq(_item("b").position, Vector2(0, 60))
	_sync(["c", "b"])
	_step(_item("b"), RowKeep.MOVE_S)
	assert_eq(_item("b").position, Vector2(0, 30))


func test_a_fill_during_motion_continues_from_the_current_position_and_alpha() -> void:
	_sync(["a", "b"])
	_settle()
	_sync(["b", "a", "c"])
	var moving: Control = _item("a")
	var fading: Control = _item("c")
	var old: Tween = moving.get_meta(RowKeep.TWEEN_META)
	_step(moving, RowKeep.MOVE_S * 0.5)
	_step(fading, RowKeep.ADD_S * 0.5)
	var position_now: Vector2 = moving.position
	var alpha_now: float = fading.modulate.a
	_sync(["c", "a", "b"])
	assert_false(old.is_valid())
	assert_eq(moving.position, position_now)
	assert_almost_eq(fading.modulate.a, alpha_now, 0.00001)
	_step(moving, RowKeep.MOVE_S)
	_step(fading, RowKeep.MOVE_S)
	_step(_item("b"), RowKeep.MOVE_S)
	assert_eq(moving.position, Vector2(0, 30))
	assert_eq(fading.position, Vector2.ZERO)
	assert_eq(_item("b").position, Vector2(0, 60))
	assert_almost_eq(fading.modulate.a, 1.0, 0.00001)
	_sync(["c", "a", "b"])
	assert_eq(moving.position, Vector2(0, 30))
	assert_eq(fading.position, Vector2.ZERO)

func test_scroll_restoration_uses_the_latest_value_and_clamps_a_shorter_list() -> void:
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(120, 90)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child_autofree(scroll)
	var content := Control.new()
	content.custom_minimum_size = Vector2(120, 400)
	scroll.add_child(content)
	await wait_process_frames(2)
	RowKeep.restore_scroll(scroll, 80)
	RowKeep.restore_scroll(scroll, 40)
	await wait_process_frames(2)
	assert_eq(scroll.scroll_vertical, 40)
	content.custom_minimum_size.y = 60
	RowKeep.restore_scroll(scroll, 40)
	assert_eq(scroll.scroll_vertical, 0)
	await wait_process_frames(2)
	assert_eq(scroll.scroll_vertical, 0)


func test_deferred_scroll_restoration_preserves_a_value_changed_after_restore() -> void:
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(120, 90)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child_autofree(scroll)
	var content := Control.new()
	content.custom_minimum_size = Vector2(120, 400)
	scroll.add_child(content)
	await wait_process_frames(2)
	# Queue a real container sort before the deferred restoration.
	content.custom_minimum_size.y = 420
	RowKeep.restore_scroll(scroll, 80)
	assert_eq(scroll.scroll_vertical, 80)
	scroll.scroll_vertical = 125
	await wait_process_frames(2)
	assert_eq(scroll.scroll_vertical, 125)
