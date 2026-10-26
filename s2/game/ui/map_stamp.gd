extends Control
## The scrawled map's mark (결정 카드 loot-feel M 가): once a scrawled map is
## picked up and read, a small inked × on a scrap of paper shows where its side
## path's gap is. Over the gap while it is on the screen; otherwise at the
## screen's edge on the way to it, with a notch pointing on. No words (결정
## 417). Reaching the gap wipes it (`reached`). It only draws: what was read and
## where it points are handed in (aim / clear).

signal reached

const HudSkin = preload("res://game/ui/hud_skin.gd")

const INSET: float = 46.0            # px the mark keeps from the screen's edge
const RADIUS: float = 15.0           # the paper scrap
const CROSS: float = 7.0             # half an arm of the ×
const NOTCH: float = 7.0             # the point toward the gap, at the edge
const REACH: float = 2.5             # metres from the gap that count as there
const POP: float = 0.45              # seconds the mark takes to stamp down
const FADE: float = 0.6              # seconds it takes to go
const INK := Color("7d2a1c")         # dried red-brown ink
const RIM := Color(0.0, 0.0, 0.0, 0.55)

var hud                              # field_hud.gd
var point = null                     # Vector3 in the world, or null
var age: float = 0.0
var gone: float = -1.0               # >= 0 while fading after reaching
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
	if not point is Vector3 or hud == null or hud.game == null:
		visible = false
		return
	var game = hud.game
	var cam: Camera3D = game.camera
	if cam == null or not cam.is_inside_tree():
		visible = false
		return
	age += delta
	if gone < 0.0 and game.player != null and is_instance_valid(game.player):
		var p: Vector3 = game.player.global_position
		var at: Vector3 = point
		if Vector2(p.x - at.x, p.z - at.z).length() < REACH:
			gone = 0.0
			reached.emit()
	if gone >= 0.0:
		gone += delta
		if gone >= FADE:
			clear()
			return
	var row := place_on(size, cam.unproject_position(point), cam.is_position_behind(point))
	_at = row[0]
	_edge = row[1]
	_dir = row[2]
	visible = true
	queue_redraw()


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
