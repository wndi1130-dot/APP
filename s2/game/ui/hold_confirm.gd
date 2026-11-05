extends Control
## 길게 눌러 확정 (결정 559): a key whose work cannot be undone (throwing an empty
## can, loading everything on the train) does it only when held. A line fills along
## the key's edge from twelve o'clock clockwise in HOLD_S, at one pace; let go early,
## or slip more than SLIP_DP past the key's edge, and it winds back in BACK_S with
## nothing done — a slip lets go for good, coming back on the key fills nothing
## until a new press; full, a short buzz and one flash of the face, and the work
## runs once as the flash ends (결정 561 ④). The times are the
## council's lever's (vote and departure), the line the field keys' own.
## The timing is hold_step(), a pure function the tests drive with their own clock;
## this node only feeds it the finger and the frame time, and draws the line.

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const GlassPane = preload("res://game/ui/glass_pane.gd")

const HOLD_S: float = 0.8
const BACK_S: float = 0.24
## css per dp: a landscape phone is 360 dp high, the canvas 390 css.
const CSS_PER_DP: float = 390.0 / 360.0
const SLIP_DP: float = 16.0
const LINE_DP: float = 2.5
const BUZZ_MS: int = 32
const LINE_INK := GlassPane.AMBER_L
## The key's own edge darkens under the line while it is held.
const UNDER_INK := Color(0.16, 0.19, 0.21, 0.95)
const ARC_STEPS: int = 8
## Full, the key flashes once (결정 561 ④): the face lit with the line's ink,
## fading over FLASH_S; the work runs as the flash ends, so the key is still there
## to be seen (the pane may lay itself again on the work). No repeat, no shake.
const FLASH_S: float = 0.16
const FLASH_ALPHA: float = 0.37

signal confirmed

var state: Dictionary = fresh()
var work: Callable = Callable()
## Seconds of the confirm flash left; the work waits for it.
var flash: float = 0.0
var _work_pending: bool = false
var _key: Button = null
var _down: bool = false
var _inside: bool = true


## A key's hold at rest.
static func fresh() -> Dictionary:
	return {"fill": 0.0, "back_from": 0.0, "back_t": -1.0, "done": false, "fired": false}


## One step of the hold, `dt` seconds on: `down` while a finger stays on the key
## (within the slip). Filling, the line grows at one pace; full, "fired" is true on
## that one step and stays done until the finger lifts. Let go early, it winds back
## from where it stood in BACK_S. Pressed again while winding back, it fills on from
## there.
static func hold_step(s: Dictionary, dt: float, down: bool) -> Dictionary:
	var out: Dictionary = s.duplicate()
	out["fired"] = false
	var step: float = maxf(dt, 0.0)
	if down:
		out["back_t"] = -1.0
		if not bool(s["done"]):
			out["fill"] = minf(1.0, float(s["fill"]) + step / HOLD_S)
			if float(out["fill"]) >= 1.0 - 0.000001:
				out["fill"] = 1.0
				out["done"] = true
				out["fired"] = true
		return out
	if bool(s["done"]) or float(s["fill"]) <= 0.0:
		return fresh()
	if float(s["back_t"]) < 0.0:
		out["back_from"] = float(s["fill"])
		out["back_t"] = 0.0
	out["back_t"] = float(out["back_t"]) + step
	out["fill"] = maxf(0.0, float(out["back_from"]) * (1.0 - float(out["back_t"]) / BACK_S))
	if float(out["fill"]) <= 0.0:
		return fresh()
	return out


## Whether a finger at `at` (the key's own coordinates) still holds a key of `box`:
## on it, or no more than `slip` px past its edge.
static func holds(at: Vector2, box: Vector2, slip: float) -> bool:
	return Rect2(Vector2.ZERO, box).grow(slip).has_point(at)


## Points along a rounded box's edge, `inset` in from it, from the top's middle
## clockwise round to it again; `fill` 0..1 keeps that share of the way.
static func edge_path(box: Vector2, radius: float, inset: float, fill: float) -> PackedVector2Array:
	var r: float = clampf(radius - inset, 0.0, minf(box.x, box.y) * 0.5 - inset)
	var lo := Vector2(inset, inset)
	var hi := box - Vector2(inset, inset)
	var all := PackedVector2Array()
	all.append(Vector2(box.x * 0.5, lo.y))
	var corners: Array = [[Vector2(hi.x - r, lo.y + r), -PI * 0.5], [Vector2(hi.x - r, hi.y - r), 0.0], [Vector2(lo.x + r, hi.y - r), PI * 0.5], [Vector2(lo.x + r, lo.y + r), PI]]
	for corner: Array in corners:
		var centre: Vector2 = corner[0]
		var from: float = corner[1]
		for i: int in ARC_STEPS + 1:
			var a: float = from + PI * 0.5 * float(i) / float(ARC_STEPS)
			all.append(centre + Vector2(cos(a), sin(a)) * r)
	all.append(Vector2(box.x * 0.5, lo.y))
	var share: float = clampf(fill, 0.0, 1.0)
	if share >= 1.0:
		return all
	if share <= 0.0:
		return PackedVector2Array([all[0]])
	var total: float = 0.0
	for i: int in range(1, all.size()):
		total += all[i - 1].distance_to(all[i])
	var want: float = total * share
	var out := PackedVector2Array([all[0]])
	var walked: float = 0.0
	for i: int in range(1, all.size()):
		var leg: float = all[i - 1].distance_to(all[i])
		if walked + leg >= want:
			if leg > 0.0:
				out.append(all[i - 1].lerp(all[i], (want - walked) / leg))
			return out
		walked += leg
		out.append(all[i])
	return out


## Gives `key` a hold: its press alone does nothing, a full hold calls `work`.
## Returns the hold (the key's child), for tests and for the key's tip.
static func attach(key: Button, on_full: Callable) -> Control:
	var hold = (load("res://game/ui/hold_confirm.gd") as GDScript).new()
	hold.name = "Hold"
	hold.work = on_full
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.add_child(hold)
	hold.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hold._bind(key)
	return hold as Control


func _bind(key: Button) -> void:
	_key = key
	key.button_down.connect(_press)
	key.button_up.connect(_lift)
	key.gui_input.connect(_finger)
	set_process(false)


func _press() -> void:
	_down = true
	_inside = true
	set_process(true)


func _lift() -> void:
	_down = false
	set_process(true)


func _finger(event: InputEvent) -> void:
	if not _down:
		return
	var at: Vector2 = Vector2.INF
	if event is InputEventMouseMotion:
		at = (event as InputEventMouseMotion).position
	elif event is InputEventScreenDrag:
		at = (event as InputEventScreenDrag).position
	# Slipped past the edge the press is let go for good: coming back on the key
	# does not fill on (a second finger's path does the same, field_hud.gd).
	if at != Vector2.INF and _key != null and not holds(at, _key.size, UiFonts.px(SLIP_DP * CSS_PER_DP)):
		_inside = false
		_down = false


## The frame's step; tests call it with their own `dt`.
func advance(dt: float) -> void:
	state = hold_step(state, dt, _down and _inside)
	if flash > 0.0:
		flash = maxf(0.0, flash - dt)
		if flash <= 0.0 and _work_pending:
			_work_pending = false
			queue_redraw()
			# The work may lay the pane again and free this node: last thing here.
			if work.is_valid():
				work.call()
			return
	if bool(state["fired"]):
		# Owed first: a listener that frees the hold still finds the work owed.
		flash = FLASH_S
		_work_pending = true
		Input.vibrate_handheld(BUZZ_MS)
		confirmed.emit()
	queue_redraw()
	if not _down and float(state["fill"]) <= 0.0 and flash <= 0.0:
		set_process(false)


func _process(delta: float) -> void:
	advance(delta)


## Gone mid-flash (the pane laid again as a thing came out, or shut): the hold was
## full and buzzed, so its work still runs, once, at the end of this frame — each
## hold its own deferred call, so two owed works stay two. The work's owner is the
## HUD, which outlives its panes; what the work does to a pane shut or opened since
## is its own (field_hud.gd _throw, _load_train: only the pane that held it).
func _exit_tree() -> void:
	if not _work_pending:
		return
	_work_pending = false
	flash = 0.0
	Callable(get_script(), "_run_owed").call_deferred(work)


## The owed work at the frame's end, run by the script (the hold itself is gone).
## Its owner gone first — the HUD freed with its field — it is dropped with it: a
## field torn down takes its unfinished confirm along, as it does its other work.
static func _run_owed(owed: Callable) -> void:
	if owed.is_valid():
		owed.call()


func _draw() -> void:
	var fill: float = float(state["fill"])
	var radius: float = float(GlassPane.px(GlassPane.RADIUS))
	if flash > 0.0:
		var face := StyleBoxFlat.new()
		face.bg_color = Color(LINE_INK, FLASH_ALPHA * flash / FLASH_S)
		face.set_corner_radius_all(int(radius))
		draw_style_box(face, Rect2(Vector2.ZERO, size))
	if fill <= 0.0:
		return
	var width: float = UiFonts.px(LINE_DP * CSS_PER_DP)
	draw_polyline(edge_path(size, radius, width * 0.5, 1.0), UNDER_INK, width, true)
	var line: PackedVector2Array = edge_path(size, radius, width * 0.5, fill)
	if line.size() >= 2:
		draw_polyline(line, LINE_INK, width, true)
