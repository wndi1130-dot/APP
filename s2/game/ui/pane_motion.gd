extends RefCounted
## A pane slides from its pinned offsets and returns to them exactly.

const OPEN_S: float = 0.18       # Ease out.
const CLOSE_S: float = 0.14      # Ease in.
const SHIFT_PX: float = 18.0    # Viewport px.
const META_STATE := "pane_motion_state"
const META_TWEEN := "pane_motion_tween"
const META_RETIRING := "pane_motion_retiring"
const META_MOUSE := "pane_motion_mouse"
const META_FOCUS := "pane_motion_focus"


static func shown(c: Control) -> bool:
	if not is_instance_valid(c):
		return false
	if c.has_meta(META_STATE):
		var state: Dictionary = c.get_meta(META_STATE)
		return bool(state["shown"])
	return c.visible


## A child still belongs to the retiring screen until that screen is freed.
static func retiring(node: Node) -> bool:
	while is_instance_valid(node):
		if node.has_meta(META_RETIRING):
			return true
		node = node.get_parent()
	return false


static func open(c: Control) -> Tween:
	var fresh: bool = not c.has_meta(META_STATE)
	var state: Dictionary = _state(c)
	state["shown"] = true
	if fresh or not c.visible:
		_pose(c, SHIFT_PX, 0.0)
	c.show()
	_restore_input(c)
	var tw: Tween = _move(c, 0.0, 1.0, OPEN_S, Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(c):
			_pose(c, 0.0, 1.0))
	return tw


## Reusable panes hide; retired panes free after the same motion.
static func close(c: Control, retire: bool = false) -> Tween:
	var state: Dictionary = _state(c)
	state["shown"] = false
	quiet(c, retire)
	var tw: Tween = _move(c, SHIFT_PX, 0.0, CLOSE_S, Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(c):
			return
		c.hide()
		_pose(c, 0.0, 0.0)
		if retire:
			c.queue_free())
	return tw


## Measure the resting place even between motion ticks or after pin().
static func rest_rect(c: Control) -> Rect2:
	var state: Dictionary = _state(c)
	var rest: Vector4 = state["rest"]
	var shift := Vector2(c.offset_left - rest.x, c.offset_top - rest.y)
	var parent: Node = c.get_parent()
	if parent is CanvasItem:
		shift = (parent as CanvasItem).get_global_transform().basis_xform(shift)
	var rect: Rect2 = c.get_global_rect()
	rect.position -= shift
	return rect


## Leave the old name free for its replacement and stop every control.
static func quiet(c: Control, rename: bool = false) -> void:
	_block_input(c)
	if rename and not c.has_meta(META_RETIRING):
		c.set_meta(META_RETIRING, true)
		c.name = "%s_retiring_%d" % [c.name, c.get_instance_id()]


static func _block_input(node: Node) -> void:
	if node is Control:
		var c: Control = node as Control
		if not c.has_meta(META_MOUSE):
			c.set_meta(META_MOUSE, c.mouse_filter)
			c.set_meta(META_FOCUS, c.focus_mode)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if c.has_focus():
			c.release_focus()
		c.focus_mode = Control.FOCUS_NONE
	for child: Node in node.get_children():
		_block_input(child)


static func _restore_input(node: Node) -> void:
	if node is Control:
		var c: Control = node as Control
		if c.has_meta(META_MOUSE):
			c.mouse_filter = int(c.get_meta(META_MOUSE)) as Control.MouseFilter
			c.focus_mode = int(c.get_meta(META_FOCUS)) as Control.FocusMode
			c.remove_meta(META_MOUSE)
			c.remove_meta(META_FOCUS)
	for child: Node in node.get_children():
		_restore_input(child)


static func _offsets(c: Control) -> Vector4:
	return Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom)


## Only writes outside our last pose change the pinned offsets.
static func _state(c: Control) -> Dictionary:
	var at: Vector4 = _offsets(c)
	if not c.has_meta(META_STATE):
		var first: Dictionary = {"rest": at, "pose": at, "shown": c.visible}
		c.set_meta(META_STATE, first)
		return first
	var state: Dictionary = c.get_meta(META_STATE)
	var rest: Vector4 = state["rest"]
	var last: Vector4 = state["pose"]
	if at.x != last.x or at.z != last.z:
		rest.x = at.x
		rest.z = at.z
	if at.y != last.y:
		rest.y = at.y
	if at.w != last.w:
		rest.w = at.w
	state["rest"] = rest
	state["pose"] = at
	return state


static func _pose(c: Control, shift: float, alpha: float) -> void:
	if not is_instance_valid(c):
		return
	var state: Dictionary = _state(c)
	var rest: Vector4 = state["rest"]
	c.offset_left = rest.x + shift
	c.offset_right = rest.z + shift
	c.offset_top = rest.y
	c.offset_bottom = rest.w
	c.modulate.a = alpha
	state["pose"] = _offsets(c)
	if not bool(state["shown"]):
		_block_input(c)


static func _move(c: Control, shift: float, alpha: float, seconds: float, ease: Tween.EaseType) -> Tween:
	if c.has_meta(META_TWEEN):
		var old: Tween = c.get_meta(META_TWEEN) as Tween
		if old != null and old.is_valid():
			old.kill()
	var state: Dictionary = _state(c)
	var rest: Vector4 = state["rest"]
	var from_shift: float = c.offset_left - rest.x
	var from_alpha: float = c.modulate.a
	var tw: Tween = c.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(ease)
	c.set_meta(META_TWEEN, tw)
	tw.tween_method(func(k: float) -> void:
		_pose(c, lerpf(from_shift, shift, k), lerpf(from_alpha, alpha, k)), 0.0, 1.0, seconds)
	return tw
