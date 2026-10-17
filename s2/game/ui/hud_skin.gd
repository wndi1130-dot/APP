extends RefCounted
## The field HUD's look (UI 3단계 시안 2차, 방향 B 「성에 낀 계기」, B1 smoked
## glass): glass pills and plates, matte round keys with one even ring and no
## shine (user 2026-10-17), lamp light from inside a key that is on, paper
## slips for notes. Only the look: where a key sits and how big its touch is
## stay field_hud.gd's (시안 3절: the touch size is not the size seen).
## B2 (frosted, light) is a morning choice; these are B1's values.

const GLASS := Color(8 / 255.0, 11 / 255.0, 15 / 255.0, 0.6)
const TOP_LIGHT := Color(1, 1, 1, 0.1)
const INK := Color("eee9dc")
const INK2 := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.7)
const INK3 := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.54)
## One even ring on every round key (the three-light brass rim is gone, user 2026-10-17).
const RING := Color("6d5b3d")
## Lamp light, darkened and cooled for the white snow (user 2026-10-17).
const LAMP1 := Color("e9c886")
const LAMP2 := Color("d18c32")
const LAMP3 := Color("94511a")
const LAMP_INK := Color("2a1804")
## Crouching shows brass, not lamp light, so it is not read as running.
const BRASS1 := Color("f3dfae")
const BRASS2 := Color("caa45c")
const BRASS3 := Color("7b5b26")
## The brass rim of the lamp pills that are not round (뒤지기, 출발, 지혈).
const RIM1 := Color("f7e6b4")
const RIM2 := Color("caa45c")
const RIM3 := Color("7b5b26")
const GOOD := Color("a8d29a")
const BAD := Color("f5916f")
const HEED := Color("f2a63c")
const URGENT := Color("ffd08a")
const GOAL := Color("d9b56a")
const PAPER := Color("cdc2a8")
const PAPER_INK := Color("231a12")
const GLOW := Color(242 / 255.0, 160 / 255.0, 50 / 255.0, 0.42)
const PRESS_SINK: float = 2.0

enum Light { NONE, LAMP, BRASS }


## A glass pill: smoked glass, a faint light along its top, a soft shadow on the snow.
static func glass(pad_x: float = 12.0, pad_y: float = 4.0, alpha: float = GLASS.a) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GLASS.r, GLASS.g, GLASS.b, alpha)
	sb.set_corner_radius_all(999)
	sb.border_width_top = 1
	sb.border_color = TOP_LIGHT
	sb.shadow_color = Color(0, 0, 0, 0.26)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


## A paper slip for a note: paper, ink, a small shadow (시안 .ftoast, .fsay).
static func paper(pad_x: float = 12.0, pad_y: float = 5.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


## The four looks of a key or pad, inside its touch rect: `seen` is the size
## drawn (zero: the whole rect), `round_key` a disc or else a pill. `on` is how
## it looks while on (a toggle that is set, a fight that goes on).
static func key_styles(seen: Vector2, round_key: bool, on: int = Light.LAMP, rest_light: int = Light.NONE) -> Dictionary:
	var rest := Plate.new()
	rest.setup(seen, round_key, rest_light)
	var down := Plate.new()
	down.setup(seen, round_key, rest_light)
	down.sink = PRESS_SINK
	var lit := Plate.new()
	lit.setup(seen, round_key, on)
	lit.sink = PRESS_SINK if on == rest_light else 0.0
	var off := Plate.new()
	off.setup(seen, round_key, Light.NONE)
	off.dim = 0.34
	for sb: StyleBox in [rest, down, lit, off]:
		sb.content_margin_left = 6.0 if round_key else 12.0
		sb.content_margin_right = 6.0 if round_key else 10.0
		sb.content_margin_top = 4.0
		sb.content_margin_bottom = 4.0
	return {"normal": rest, "hover": rest, "pressed": lit, "hover_pressed": lit, "disabled": off, "down": down}


## One plate: a disc or a pill of glass (or lamp light) with one ring, drawn
## centred in the rect it is given, a little lower while held down.
class Plate extends StyleBox:
	var seen: Vector2 = Vector2.ZERO
	var round_key: bool = true
	var light: int = 0               # Light: NONE, LAMP, BRASS
	var sink: float = 0.0
	var dim: float = 1.0
	var fill: Color = Color(8 / 255.0, 11 / 255.0, 15 / 255.0, 0.6)
	var ring: Color = Color("6d5b3d")
	var ring_w: float = 2.0
	var brass_rim: bool = false      # the lamp pills that are not round keep a brass rim

	static var _blob: ImageTexture

	func setup(at_size: Vector2, is_round: bool, how: int) -> void:
		seen = at_size
		round_key = is_round
		light = how
		brass_rim = how != 0 and not is_round

	## A soft round blob, white in the middle and gone at the edge (shadows, glow).
	static func blob() -> ImageTexture:
		if _blob == null:
			var n := 64
			var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
			for y in n:
				for x in n:
					var d: float = Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
					var a: float = clampf(1.0 - d, 0.0, 1.0)
					img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
			_blob = ImageTexture.create_from_image(img)
		return _blob

	func _shape(rect: Rect2) -> Rect2:
		var s: Vector2 = rect.size if seen == Vector2.ZERO else Vector2(minf(seen.x, rect.size.x), minf(seen.y, rect.size.y))
		if round_key:
			s = Vector2.ONE * minf(s.x, s.y)
		return Rect2(rect.get_center() - s * 0.5 + Vector2(0, sink), s)

	func _outline(r: Rect2) -> PackedVector2Array:
		var pts := PackedVector2Array()
		if round_key:
			var c := r.get_center()
			var rad: float = r.size.x * 0.5
			for i in 48:
				var a: float = TAU * float(i) / 48.0
				pts.append(c + Vector2(cos(a), sin(a)) * rad)
			return pts
		var h: float = r.size.y * 0.5
		var left := Vector2(r.position.x + h, r.position.y + h)
		var right := Vector2(r.end.x - h, r.position.y + h)
		for i in 13:
			var a: float = -PI * 0.5 + PI * float(i) / 12.0
			pts.append(right + Vector2(cos(a), sin(a)) * h)
		for i in 13:
			var a: float = PI * 0.5 + PI * float(i) / 12.0
			pts.append(left + Vector2(cos(a), sin(a)) * h)
		return pts

	## Lamp light from below the middle: bright at the centre, dark at the rim (시안 .fkey.on, .fpad--ctx).
	func _light_at(p: Vector2, r: Rect2) -> Color:
		var c1: Color = BRASS1 if light == 2 else LAMP1
		var c2: Color = BRASS2 if light == 2 else LAMP2
		var c3: Color = BRASS3 if light == 2 else LAMP3
		var t: float
		if round_key:
			t = (p - (r.position + r.size * Vector2(0.5, 0.58))).length() / (r.size.x * 0.766)
		else:
			var q: Vector2 = (p - (r.position + r.size * Vector2(0.5, 1.18))) / (r.size * Vector2(1.1, 1.5))
			t = q.length()
		t = clampf(t, 0.0, 1.0)
		var k: float = 0.62 if round_key else 0.48
		return c1.lerp(c2, t / k) if t < k else c2.lerp(c3, (t - k) / (1.0 - k))

	## A 140-degree brass sweep along the rim, light at the top left (시안 .fpad--ctx).
	func _rim_at(p: Vector2, r: Rect2) -> Color:
		var dir := Vector2(sin(deg_to_rad(140.0)), -cos(deg_to_rad(140.0)))
		var span: float = absf(dir.x) * r.size.x + absf(dir.y) * r.size.y
		var t: float = clampf((p - r.get_center()).dot(dir) / maxf(span, 1.0) + 0.5, 0.0, 1.0)
		return RIM1.lerp(RIM3, t * 2.0) if t < 0.5 else RIM3.lerp(RIM2, (t - 0.5) * 2.0)

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		var rs := RenderingServer
		var r := _shape(rect)
		var pts := _outline(r)
		var tex: RID = blob().get_rid()
		var shade := Rect2(r.position + Vector2(-5, -1), r.size + Vector2(10, 10))
		rs.canvas_item_add_texture_rect(to_canvas_item, shade, tex, false, Color(0, 0, 0, 0.42 * dim))
		if light != 0:
			var glow := r.grow(maxf(r.size.y * 0.22, 9.0))
			rs.canvas_item_add_texture_rect(to_canvas_item, glow, tex, false, Color(GLOW.r, GLOW.g, GLOW.b, GLOW.a * dim))
			var centre: Vector2 = r.position + r.size * (Vector2(0.5, 0.58) if round_key else Vector2(0.5, 0.82))
			var all := PackedVector2Array([centre])
			all.append_array(pts)
			var cols := PackedColorArray()
			for p in all:
				var c := _light_at(p, r)
				cols.append(Color(c.r, c.g, c.b, c.a * dim))
			var idx := PackedInt32Array()
			for i in pts.size():
				idx.append_array([0, 1 + i, 1 + (i + 1) % pts.size()])
			rs.canvas_item_add_triangle_array(to_canvas_item, idx, all, cols)
		else:
			rs.canvas_item_add_polygon(to_canvas_item, pts, PackedColorArray([Color(fill.r, fill.g, fill.b, fill.a * dim)]))
		var loop := pts.duplicate()
		loop.append(pts[0])
		if brass_rim:
			var rim := PackedColorArray()
			for p in loop:
				var c := _rim_at(p, r)
				rim.append(Color(c.r, c.g, c.b, dim))
			rs.canvas_item_add_polyline(to_canvas_item, loop, rim, ring_w, true)
		elif ring.a > 0.0:
			rs.canvas_item_add_polyline(to_canvas_item, loop, PackedColorArray([Color(ring.r, ring.g, ring.b, ring.a * dim)]), ring_w, true)
