extends Control
## The scrawled map's mark (결정 카드 loot-feel M 가): once a scrawled map is
## picked up and read, a small inked × on a scrap of paper shows where its side
## path's gap is. Over the gap while it is on the screen; otherwise at the
## screen's edge on the way to it, with a notch pointing on. No words (결정
## 417). It only draws what the field holds in `side_hint` ({} or {"at":
## Vector3}, kept by the loot side): when that empties (someone reached the gap,
## the map was lost) the mark fades away.

const HudSkin = preload("res://game/ui/hud_skin.gd")

const INSET: float = 46.0            # px the mark keeps from the screen's edge
const RADIUS: float = 15.0           # the paper scrap
const CROSS: float = 7.0             # half an arm of the ×
const NOTCH: float = 10.0            # the point toward the gap, at the edge
const KEY_STEP: float = 6.0          # px a slide off a key goes at a time
const POP: float = 0.45              # seconds the mark takes to stamp down
const FADE: float = 0.6              # seconds it takes to go
const INK := Color("7d2a1c")         # dried red-brown ink
const RIM := Color(0.0, 0.0, 0.0, 0.55)

var hud                              # field_hud.gd
var point = null                     # Vector3 in the world, or null
var age: float = 0.0
var gone: float = -1.0               # >= 0 while fading away
var _at := Vector2.ZERO
var _edge := false
var _dir := Vector2.RIGHT


func setup(field_hud) -> void:
	hud = field_hud
	name = "MapStamp"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Point at a place in the world (the gap). A new aim stamps down afresh.
func aim(at: Vector3) -> void:
	if point is Vector3 and (point as Vector3).is_equal_approx(at) and gone < 0.0:
		return
	point = at
	age = 0.0
	gone = -1.0


func clear() -> void:
	point = null
	gone = -1.0
	visible = false


## Where on a screen of `size` the mark goes for a place seen at `seen` (behind:
## the place is behind the camera): itself when it is inside the inset, else the
## inset's edge on the line from the middle toward it. [point, at_edge, direction]
static func place_on(size: Vector2, seen: Vector2, behind: bool, inset: float = INSET) -> Array:
	var mid := size * 0.5
	inset = clampf(inset, 0.0, maxf(minf(mid.x, mid.y) - 1.0, 0.0))
	var d := seen - mid
	if behind:
		d = -d
	var box := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
	if not behind and box.has_point(seen):
		return [seen, false, d.normalized() if d.length() > 0.001 else Vector2.RIGHT]
	if d.length() < 0.001:
		d = Vector2.DOWN
	var half := box.size * 0.5
	var k: float = minf(half.x / maxf(absf(d.x), 0.001), half.y / maxf(absf(d.y), 0.001))
	return [mid + d * k, true, d.normalized()]


func _process(delta: float) -> void:
	if hud == null or hud.game == null:
		visible = false
		return
	var game = hud.game
	var hint = game.get("side_hint")
	if hint is Dictionary and (hint as Dictionary).get("at") is Vector3:
		aim(hint["at"])
	elif point is Vector3 and gone < 0.0:
		gone = 0.0
	if not point is Vector3:
		visible = false
		return
	var cam: Camera3D = game.camera
	if cam == null or not cam.is_inside_tree():
		visible = false
		return
	age += delta
	if gone >= 0.0:
		gone += delta
		if gone >= FADE:
			clear()
			return
	var row := place_on(size, cam.unproject_position(point), cam.is_position_behind(point))
	_at = row[0]
	_edge = row[1]
	_dir = row[2]
	if _edge:
		_at = clear_of(_at, size * 0.5, _keys())
	visible = true
	queue_redraw()


## At the edge the mark keeps off the HUD's keys (the attack key sits in the
## corner a far place often points to): it slides toward the middle till clear.
static func clear_of(at: Vector2, mid: Vector2, keys: Array) -> Vector2:
	var step: Vector2 = (mid - at).normalized() * KEY_STEP
	for i in 200:
		var hit := false
		for r: Rect2 in keys:
			if r.grow(RADIUS + NOTCH).has_point(at):
				hit = true
				break
		if not hit or at.distance_to(mid) <= KEY_STEP:
			return at
		at += step
	return at


func _keys() -> Array:
	var out: Array = []
	var top = hud.get("root")
	if not top is Control:
		return out
	for b in (top as Control).find_children("*", "BaseButton", true, false):
		var k := b as Control
		if k.is_visible_in_tree():
			out.append(k.get_global_rect())
	return out


func _draw() -> void:
	var t: float = clampf(age / POP, 0.0, 1.0)
	# Stamped down: a little large at first, settling.
	var k: float = lerpf(1.45, 1.0, 1.0 - pow(1.0 - t, 3.0))
	var a: float = t
	if gone >= 0.0:
		a *= 1.0 - clampf(gone / FADE, 0.0, 1.0)
	var r := RADIUS * k
	if _edge:
		var tip := _at + _dir * (r + NOTCH)
		var side := Vector2(-_dir.y, _dir.x) * (r * 0.45)
		draw_colored_polygon(PackedVector2Array([tip, _at + _dir * r * 0.6 + side, _at + _dir * r * 0.6 - side]), Color(HudSkin.PAPER, 0.92 * a))
	draw_circle(_at, r + 1.5, Color(RIM, RIM.a * a))
	draw_circle(_at, r, Color(HudSkin.PAPER, 0.92 * a))
	var c := CROSS * k
	var ink := Color(INK, 0.95 * a)
	# Two strokes a hand made, not quite square.
	draw_line(_at + Vector2(-c, -c * 0.9), _at + Vector2(c, c * 1.05), ink, 3.2, true)
	draw_line(_at + Vector2(c * 0.95, -c), _at + Vector2(-c * 1.05, c * 0.9), ink, 3.2, true)
