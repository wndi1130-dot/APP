extends RefCounted
## Keep rows and their controls while the model changes.

const PaneMotion = preload("res://game/ui/pane_motion.gd")

const ADD_S: float = 0.12
const REMOVE_S: float = 0.10
const MOVE_S: float = 0.15
const ID_META: StringName = &"row_keep_id"
const TWEEN_META: StringName = &"row_keep_tween"
const LEAVING_META: StringName = &"row_keep_leaving"
const USED_META: StringName = &"row_keep_used"
const SCROLL_META: StringName = &"row_keep_scroll"


## make(id) returns a row; fill(row, id, index) sets its target position.
static func sync(into: Control, ids: Array, make: Callable, fill: Callable) -> void:
	var kept: Dictionary = {}
	for child: Node in into.get_children():
		if child is Control and child.has_meta(ID_META):
			var id: String = String(child.get_meta(ID_META))
			if child.has_meta(LEAVING_META):
				if ids.has(id):
					child.hide()
			else:
				kept[id] = child
	for id: String in kept:
		if not ids.has(id):
			_retire(kept[id])
	for index: int in ids.size():
		var id: String = String(ids[index])
		var fresh: bool = not kept.has(id)
		var row: Control = make.call(id) if fresh else kept[id]
		if fresh:
			row.name = "Item_" + id.validate_node_name()
			row.set_meta(ID_META, id)
			into.add_child(row)
		var from: Vector2 = row.position
		_stop(row)
		fill.call(row, id, index)
		var target: Vector2 = row.position
		into.move_child(row, index)
		if fresh:
			row.modulate.a = 0.0
		else:
			row.position = from
		var moving: bool = not row.position.is_equal_approx(target)
		if moving or row.modulate.a < 1.0:
			var tween: Tween = row.create_tween().set_parallel(true)
			row.set_meta(TWEEN_META, tween)
			if moving:
				tween.tween_property(row, "position", target, MOVE_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			if row.modulate.a < 1.0:
				tween.tween_property(row, "modulate:a", 1.0, ADD_S)
	_quiet_if_needed(into)


static func _stop(row: Control) -> void:
	if row.has_meta(TWEEN_META):
		var tween: Tween = row.get_meta(TWEEN_META)
		if tween != null and tween.is_valid():
			tween.kill()
		row.remove_meta(TWEEN_META)


static func _retire(row: Control) -> void:
	_stop(row)
	row.set_meta(LEAVING_META, true)
	row.name = "Leaving_%d" % row.get_instance_id()
	_block(row)
	var tween: Tween = row.create_tween()
	row.set_meta(TWEEN_META, tween)
	tween.tween_property(row, "modulate:a", 0.0, REMOVE_S)
	tween.tween_callback(row.queue_free)


static func _block(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_NONE
		if node.has_focus():
			node.release_focus()
	if node is BaseButton:
		node.disabled = true
	for child: Node in node.get_children():
		_block(child)


## Keep the intended filter for reopening while a quiet ancestor owns input.
static func pass_mouse(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	if control.has_meta(PaneMotion.META_MOUSE):
		control.set_meta(PaneMotion.META_MOUSE, Control.MOUSE_FILTER_PASS)
	_quiet_if_needed(control)


static func _quiet_if_needed(control: Control) -> void:
	var ancestor: Node = control
	while ancestor != null:
		if ancestor.has_meta(PaneMotion.META_RETIRING) or ancestor.has_meta(PaneMotion.META_MOUSE):
			PaneMotion.quiet(control)
			return
		ancestor = ancestor.get_parent()


## Mark parts as used without hiding a held button between fills.
static func begin(into: Control) -> void:
	for child: Node in into.get_children():
		if child is Control:
			child.set_meta(USED_META, false)


static func part(into: Control, key: String, make: Callable) -> Control:
	var control: Control = into.get_node_or_null(NodePath(key)) as Control
	if control == null:
		control = make.call()
		control.name = key
		into.add_child(control)
	control.set_meta(USED_META, true)
	if not control.visible:
		control.show()
	return control


static func finish(into: Control) -> void:
	for child: Node in into.get_children():
		if child is Control and child.has_meta(USED_META) and not bool(child.get_meta(USED_META)):
			child.hide()
	# Parts are fully configured now, so save their final input settings.
	_quiet_if_needed(into)


## Container sorting is deferred; only the latest fill restores the scroll.
static func restore_scroll(scroll: ScrollContainer, value: int) -> void:
	var serial: int = int(scroll.get_meta(SCROLL_META)) + 1 if scroll.has_meta(SCROLL_META) else 1
	scroll.set_meta(SCROLL_META, serial)
	_apply_scroll(scroll, value, serial)
	_apply_scroll.call_deferred(scroll, value, serial, scroll.scroll_vertical)


static func _apply_scroll(scroll: ScrollContainer, value: int, serial: int, expected: int = -1) -> void:
	if not is_instance_valid(scroll) or not scroll.has_meta(SCROLL_META) or int(scroll.get_meta(SCROLL_META)) != serial:
		return
	if expected >= 0 and scroll.scroll_vertical != expected:
		return
	var content: Control = scroll.get_child(0) as Control
	var end: int = maxi(0, int(ceilf(content.get_combined_minimum_size().y - scroll.size.y)))
	scroll.scroll_vertical = mini(value, end)
