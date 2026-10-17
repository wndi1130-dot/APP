extends Control
## A face on the field (decision 293 ①, 시안 2차 fFace): an ink bust on paper in
## a round frame that changes with the body, so the state reads at a glance and
## the card needs no state words. One look at a time, the most urgent first
## (infection, bleeding, a break, festering, frostbite, exhaustion), and frost
## on the rim while cold. It only reads the body. Blood is dark brown here,
## never red (field_hud BLOOD_BROWN); the reddish plates are the state icons'.

const HudSkin = preload("res://game/ui/hud_skin.gd")

const ORDER: Array[String] = ["infect", "bleed", "fracture", "fester", "frostbite", "tired"]
const PAPER := Color("d9cfb8")
const INK := Color("17120e")
const RING := Color("6d5b3d")
const BLOOD := Color(0.36, 0.17, 0.1)
const FESTER := Color(0.72, 0.65, 0.19)
const FROST := Color(0.894, 0.933, 0.965)
## The 시안 drew the face 40 across; lengths below are in those units.
const UNIT: float = 40.0

var kind: int = 3          # headwear: 3 a knit hat and a scarf (the chief in the 시안)
var face_seed: int = 31
var look: String = ""      # one of ORDER, or "" while the body is whole
var cold: int = 0          # 1 and up: frost on the rim; 3: the blue of frostbite

static var _edge: ImageTexture


## What a face shows of p: the most urgent look ("" when nothing is wrong).
## A scratch is not shown: whether it took is hidden until its window ends.
static func look_of(p) -> String:
	var b = p.body
	if b.infection == "bite":
		return "infect"
	if b.bleed > 0:
		return "bleed"
	if b.arm_fracture or b.leg_fracture:
		return "fracture"
	if b.has_festering():
		return "fester"
	if cold_of(p) >= 3:
		return "frostbite"
	if b.exhaustion_level() >= 1:
		return "tired"
	return ""


## How cold p is: the field's own tier (S2 stops at 1, '추움') or the body's.
static func cold_of(p) -> int:
	return maxi(p.cold_level(), int(p.body.cold_level))


## Follow p's body; it redraws only when the look or the cold changes.
func show_body(p) -> void:
	var l: String = look_of(p)
	var c: int = cold_of(p)
	if l != look or c != cold:
		look = l
		cold = c
		queue_redraw()


## Darkness that gathers at the rim and is gone past it (the vignette of a look).
static func edge() -> ImageTexture:
	if _edge == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d: float = Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
				var a: float = 0.0 if d > 1.0 else clampf((d - 0.3) / 0.7, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a))
		_edge = ImageTexture.create_from_image(img)
	return _edge


func _draw() -> void:
	var d: float = minf(size.x, size.y)
	var o: Vector2 = (size - Vector2(d, d)) * 0.5
	var c: Vector2 = o + Vector2(d, d) * 0.5
	var s: float = d / UNIT
	var r: float = d * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = face_seed * 17 + 3
	var disc: PackedVector2Array = _circle(c, r - 2.0 * s, 56)
	draw_colored_polygon(disc, PAPER)
	draw_texture_rect(HudSkin.Plate.blob(), Rect2(o + Vector2(d, d) * 0.08, Vector2(d, d) * 0.84), false, Color(44 / 255.0, 38 / 255.0, 34 / 255.0, 0.3))
	_draw_bust(o, d, disc, look == "tired")
	for i in 10:
		var at := o + Vector2(rng.randf() * d, d * (0.08 + rng.randf() * 0.84))
		if at.distance_to(c) < r - 3.0 * s:
			draw_circle(at, (0.5 + rng.randf() * 1.3) * s, Color(INK.r, INK.g, INK.b, 0.2 + rng.randf() * 0.5))
	match look:
		"infect":
			draw_colored_polygon(disc, Color(0.67, 0.71, 0.36, 0.42))
			draw_texture_rect(edge(), Rect2(o, Vector2(d, d)), false, Color(40 / 255.0, 48 / 255.0, 16 / 255.0, 0.62))
		"frostbite":
			draw_colored_polygon(disc, Color(0.57, 0.7, 0.84, 0.45))
			draw_texture_rect(edge(), Rect2(o, Vector2(d, d)), false, Color(0.886, 0.94, 0.98, 0.62))
		"bleed":
			_blots(o, d, disc, rng, Vector2(0.72, 0.74), 9, 0.2, 0.14, BLOOD)
		"fester":
			_blots(o, d, disc, rng, Vector2(0.5, 0.6), 4, 0.3, 0.09, FESTER)
		"fracture":
			_crack(o, d, s, rng)
		"tired":
			draw_colored_polygon(disc, Color(28 / 255.0, 24 / 255.0, 38 / 255.0, 0.3))
	draw_arc(c, r - 1.5 * s, 0.0, TAU, 64, RING, 2.0 * s, true)
	if cold >= 1:
		_frost(c, r, s, rng)


func _circle(c: Vector2, rad: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	return pts


func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 28:
		var a: float = TAU * float(i) / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


func _bezier(out: PackedVector2Array, a: Vector2, b: Vector2, e: Vector2, f: Vector2) -> void:
	for i in range(1, 11):
		var t: float = float(i) / 10.0
		var u: float = 1.0 - t
		out.append(a * u * u * u + b * 3.0 * u * u * t + e * 3.0 * u * t * t + f * t * t * t)


## The bust in the 시안's 120-high units, its feet at the bottom, then clipped
## to the frame. Its foot fades out, as ink thins at the edge of a brush.
func _draw_bust(o: Vector2, d: float, disc: PackedVector2Array, low: bool) -> void:
	var k: float = d / 120.0
	var base := Vector2(o.x + d * 0.5, o.y + d * (1.1 + (0.08 if low else 0.0)))
	var shapes: Array = []
	var torso := PackedVector2Array([Vector2(-52, 0)])
	_bezier(torso, Vector2(-52, 0), Vector2(-52, -30), Vector2(-40, -44), Vector2(-18, -50))
	torso.append_array([Vector2(-11, -58), Vector2(11, -58), Vector2(18, -50)])
	_bezier(torso, Vector2(18, -50), Vector2(40, -44), Vector2(52, -30), Vector2(52, 0))
	shapes.append(torso)
	shapes.append(_ellipse(Vector2(0, -78), 19, 23))
	match kind:
		1:
			shapes.append(_ellipse(Vector2(0, -93), 22, 13))
			shapes.append(_rect(-24, -90, 7, 22))
			shapes.append(_rect(17, -90, 7, 22))
		2:
			shapes.append(_ellipse(Vector2(0, -76), 25, 28))
			shapes.append(_ellipse(Vector2(0, -52), 34, 12))
		3:
			shapes.append(_ellipse(Vector2(0, -95), 21, 9))
			shapes.append(_ellipse(Vector2(0, -60), 27, 9))
		4:
			shapes.append(_ellipse(Vector2(0, -100), 12, 9))
			shapes.append(_ellipse(Vector2(0, -58), 31, 9))
		5:
			shapes.append(_rect(-28, -97, 56, 5))
			shapes.append(_rect(-18, -113, 36, 18))
	var ink := Color(INK.r, INK.g, INK.b, 0.93)
	if low:
		ink = Color(0.2, 0.19, 0.19, 0.9)
	for shape: PackedVector2Array in shapes:
		var placed := PackedVector2Array()
		for p in shape:
			placed.append(base + p * k)
		for part: PackedVector2Array in Geometry2D.intersect_polygons(placed, disc):
			var cols := PackedColorArray()
			for p in part:
				var fade: float = clampf((p.y - o.y - d * 0.7) / (d * 0.3), 0.0, 1.0)
				cols.append(Color(ink.r, ink.g, ink.b, ink.a * (1.0 - 0.95 * fade * fade * (3.0 - 2.0 * fade))))
			draw_polygon(part, cols)


## Soft blots (blood, a festering wound), each three rings deep so its edge is soft.
func _blots(o: Vector2, d: float, disc: PackedVector2Array, rng: RandomNumberGenerator, at: Vector2, n: int, spread: float, big: float, col: Color) -> void:
	for i in n:
		var a: float = rng.randf() * TAU
		var q: float = d * spread * rng.randf()
		var p: Vector2 = o + at * d + Vector2(cos(a) * q, sin(a) * q * 0.75)
		var rr: float = d * big * (0.6 + rng.randf() * 0.7)
		for ring in [[1.0, 0.22], [0.72, 0.28], [0.42, 0.4]]:
			for part: PackedVector2Array in Geometry2D.intersect_polygons(_circle(p, rr * float(ring[0]), 18), disc):
				draw_colored_polygon(part, Color(col.r, col.g, col.b, float(ring[1])))


## One crack across the glass, from the rim to near the far rim, and one short
## side crack at an angle (never two bars crossing).
func _crack(o: Vector2, d: float, s: float, rng: RandomNumberGenerator) -> void:
	var r: float = d * 0.5
	var a0: float = PI * (1.1 + rng.randf() * 0.1)
	var pts := PackedVector2Array()
	for i in 8:
		var t: float = float(i) / 7.0
		var q: float = (r - 2.0 * s) * (1.0 - 1.84 * t)
		var j: float = (d * (0.13 if i % 2 == 1 else 0.07)) if i > 0 and i < 7 else 0.0
		pts.append(o + Vector2(r + cos(a0) * q + (rng.randf() - 0.5) * j, r + sin(a0) * q + (rng.randf() - 0.5) * j))
	var ba: float = (pts[4] - pts[3]).angle() - 0.45
	var side_end: Vector2 = pts[3] + Vector2(cos(ba), sin(ba)) * d * 0.12
	for pass_ in [[Color(12 / 255.0, 9 / 255.0, 6 / 255.0, 0.6), 2.4, 0.7], [Color(252 / 255.0, 250 / 255.0, 244 / 255.0, 0.95), 1.2, 0.0]]:
		var off := Vector2.ONE * float(pass_[2]) * s
		var line := PackedVector2Array()
		for p in pts:
			line.append(p + off)
		draw_polyline(line, pass_[0], float(pass_[1]) * s, true)
		draw_line(pts[3] + off, side_end + off, pass_[0], float(pass_[1]) * s, true)


## Frost on the rim: a broken white ring and fern strokes growing in from it,
## longer for frostbite.
func _frost(c: Vector2, r: float, s: float, rng: RandomNumberGenerator) -> void:
	var rad: float = r - 1.6 * s
	var dash: Array[float] = [7.0, 5.0, 3.0, 6.0]
	var at: float = 0.0
	var i := 0
	var whole: float = TAU * rad
	while at < whole:
		var step: float = dash[i % dash.size()] * s
		if i % 2 == 0:
			draw_arc(c, rad, at / rad, minf(at + step, whole) / rad, 6, Color(FROST.r, FROST.g, FROST.b, 0.9), 2.6 * s, true)
		at += step
		i += 1
	var col := Color(240 / 255.0, 246 / 255.0, 250 / 255.0, 0.8)
	for n in 9:
		var a: float = rng.randf() * TAU
		var from: Vector2 = c + Vector2(cos(a), sin(a)) * (r - 1.0 * s)
		var dir: float = a + PI + (rng.randf() - 0.5) * 0.6
		var length: float = ((10.0 if cold >= 3 else 5.0) + rng.randf() * 6.0) * s
		var to: Vector2 = from + Vector2(cos(dir), sin(dir)) * length
		draw_line(from, to, col, 1.2 * s, true)
		for f in [0.4, 0.7]:
			var mid: Vector2 = from.lerp(to, f)
			for side in [-0.6, 0.6]:
				var back: float = dir + PI + side
				draw_line(mid, mid + Vector2(cos(back), sin(back)) * length * 0.3, col, 1.0 * s, true)
