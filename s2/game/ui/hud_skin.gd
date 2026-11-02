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
## A quiet steel ring, with small material marks on some keys.
const RING := Color("5b5f63")
## Lamp light, darkened and cooled for the white snow (user 2026-10-17).
const LAMP1 := Color("e9c886")
const LAMP2 := Color("d18c32")
const LAMP3 := Color("94511a")
const LAMP_INK := Color("2a1804")
## Crouching shows brass, not lamp light, so it is not read as running.
const BRASS1 := Color("f3dfae")
const BRASS2 := Color("caa45c")
const BRASS3 := Color("7b5b26")
## The cool metal sweep on pills.
const RIM1 := Color("8d9092")
const RIM2 := Color("63676b")
const RIM3 := Color("3f4347")
const GOOD := Color("a8d29a")
const BAD := Color("f5916f")
const HEED := Color("f2a63c")
const URGENT := Color("ffd08a")
const GOAL := Color("d9b56a")
const PAPER := Color("cdc2a8")
const PAPER_INK := Color("231a12")
const GLOW := Color(242 / 255.0, 160 / 255.0, 50 / 255.0, 0.42)
const PRESS_SINK: float = 2.0
## The paper's fibre (--tx-paper), a tile 240 시안 px across.
const PAPER_TEX := preload("res://game/ui/tex/paper.png")
const PAPER_TILE: float = 240.0 * 720.0 / 390.0
## 시안 px → game px (ui_fonts.gd K).
const K: float = 720.0 / 390.0
## The stick's knob (시안 --med): dark enamel with a light at its top left.
const KNOB_LIGHT := Color("323a43")
const KNOB_DARK := Color("0c1014")

enum Light { NONE, LAMP, BRASS }

static var _stick_bed: ImageTexture
static var _stick_knob: ImageTexture


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


## A paper slip with its fibre on it (시안 .ftoast: --tx-paper on --paper). The
## control that shows it repeats textures (CanvasItem.TEXTURE_REPEAT_ENABLED).
static func slip(pad_x: float = 12.0, pad_y: float = 5.0) -> StyleBox:
	var sb := Slip.new()
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


## Paper and its fibre over `rect` on `ci` (a control drawing itself).
static func draw_paper(ci: CanvasItem, rect: Rect2, alpha: float = 1.0) -> void:
	ci.draw_rect(rect, Color(PAPER.r, PAPER.g, PAPER.b, alpha))
	ci.draw_polygon(_corners(rect), PackedColorArray([Color(1, 1, 1, alpha)]), _paper_uv(rect), PAPER_TEX)


static func _corners(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


static func _paper_uv(rect: Rect2) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	for p in _corners(rect):
		uvs.append(p / PAPER_TILE)
	return uvs


class Slip extends StyleBox:
	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		var rs := RenderingServer
		# 0 2px 4px rgba(0,0,0,.45): a soft shadow a little low.
		for i in 3:
			var g: float = float(3 - i)
			rs.canvas_item_add_rect(to_canvas_item, Rect2(rect.position + Vector2(-g * 0.5, 2.0 - g * 0.5), rect.size + Vector2(g, g)), Color(0, 0, 0, 0.15))
		rs.canvas_item_add_rect(to_canvas_item, rect, PAPER)
		var pts := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
		var uvs := PackedVector2Array()
		for p in pts:
			uvs.append(p / PAPER_TILE)
		rs.canvas_item_add_polygon(to_canvas_item, pts, PackedColorArray([Color.WHITE]), uvs, PAPER_TEX.get_rid())


## The stick (시안 .fstick): a ring of smoked glass that darkens toward its
## edge, a dark knob in it with a light at its top left and one even ring (lamp
## light while running). `held`: a thumb is on it.
static func draw_stick(ci: CanvasItem, base: Vector2, knob: Vector2, ring_r: float, knob_r: float, held: bool, running: bool) -> void:
	ci.draw_texture_rect(_bed(), Rect2(base - Vector2.ONE * ring_r, Vector2.ONE * ring_r * 2.0), false)
	ci.draw_arc(base, ring_r - 1.5 * K, 0.0, TAU, 72, Color(INK.r, INK.g, INK.b, 0.5 if held else 0.34), 3.0 * K, true)
	# 0 2px 5px rgba(0,0,0,.5) under the knob.
	ci.draw_texture_rect(Plate.blob(), Rect2(knob - Vector2.ONE * knob_r * 1.3 + Vector2(0, 2.0 * K), Vector2.ONE * knob_r * 2.6), false, Color(0, 0, 0, 0.5))
	ci.draw_texture_rect(_knob(), Rect2(knob - Vector2.ONE * knob_r, Vector2.ONE * knob_r * 2.0), false)
	ci.draw_arc(knob, knob_r - 1.0 * K, 0.0, TAU, 56, LAMP2 if running else RING, 2.0 * K, true)


## The ring's glass: radial-gradient(circle, fg .14, fg .32) out to the box's
## corner, so .27 at the rim; nothing outside it.
static func _bed() -> ImageTexture:
	if _stick_bed == null:
		var n := 128
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d: float = Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
				var a: float = lerpf(0.14, 0.32, d / sqrt(2.0)) * clampf((1.0 - d) * n * 0.5, 0.0, 1.0)
				img.set_pixel(x, y, Color(GLASS.r, GLASS.g, GLASS.b, a))
		_stick_bed = ImageTexture.create_from_image(img)
	return _stick_bed


## The knob: radial-gradient(circle at 36% 26%, #323a43, #0c1014 72%) in a disc.
static func _knob() -> ImageTexture:
	if _stick_knob == null:
		var n := 96
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var light := Vector2(0.36, 0.26) * n
		var reach: float = Vector2(0.64, 0.74).length() * n * 0.72
		for y in n:
			for x in n:
				var p := Vector2(x + 0.5, y + 0.5)
				var d: float = (p - Vector2.ONE * n * 0.5).length() / (n * 0.5)
				var c: Color = KNOB_LIGHT.lerp(KNOB_DARK, clampf(p.distance_to(light) / reach, 0.0, 1.0))
				c.a = clampf((1.0 - d) * n * 0.5, 0.0, 1.0)
				img.set_pixel(x, y, c)
		_stick_knob = ImageTexture.create_from_image(img)
	return _stick_knob


## The four looks of a key or pad, inside its touch rect: `seen` is the size
## drawn (zero: the whole rect), `round_key` a disc or else a pill. `on` is how
## it looks while on (a toggle that is set, a fight that goes on).
static func key_styles(seen: Vector2, round_key: bool, on: int = Light.LAMP, rest_light: int = Light.NONE, motif: String = "") -> Dictionary:
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
	for sb: Plate in [rest, down, lit, off]:
		sb.motif = motif
		sb.content_margin_left = 6.0 if round_key else 12.0
		sb.content_margin_right = 6.0 if round_key else 10.0
		sb.content_margin_top = 4.0
		sb.content_margin_bottom = 4.0
	return {"normal": rest, "hover": rest, "pressed": lit, "hover_pressed": lit, "disabled": off, "down": down}


## One plate: a disc or a pill of glass (or lamp light) with one ring, drawn
## centred in the rect it is given, a little lower while held down.
## Glass lies over the base ring colour or a pill's metal sweep.
## Material marks stay at the rim. With no ring the glass is see-through.
class Plate extends StyleBox:
	var seen: Vector2 = Vector2.ZERO
	var round_key: bool = true
	var motif: String = ""
	var light: int = 0               # Light: NONE, LAMP, BRASS
	var sink: float = 0.0
	var dim: float = 1.0
	var fill: Color = Color(8 / 255.0, 11 / 255.0, 15 / 255.0, 0.6)
	var ring: Color = RING
	var ring_w: float = 2.0 * K      # the 시안's 2px border
	var brass_rim: bool = false      # a pill wears the metal sweep, lit or not
	var over_ring: bool = true       # the glass lies over the ring's colour

	static var _blob: ImageTexture

	func setup(at_size: Vector2, is_round: bool, how: int) -> void:
		seen = at_size
		round_key = is_round
		light = how
		brass_rim = not is_round

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

	## The glass over `under`, as the 시안's two background layers mix.
	func _over(under: Color) -> Color:
		var a: float = fill.a
		return Color(fill.r * a + under.r * (1.0 - a), fill.g * a + under.g * (1.0 - a), fill.b * a + under.b * (1.0 - a), dim)

	## A 140-degree metal sweep, light at the top left.
	func _rim_at(p: Vector2, r: Rect2) -> Color:
		var dir := Vector2(sin(deg_to_rad(140.0)), -cos(deg_to_rad(140.0)))
		var span: float = absf(dir.x) * r.size.x + absf(dir.y) * r.size.y
		var t: float = clampf((p - r.get_center()).dot(dir) / maxf(span, 1.0) + 0.5, 0.0, 1.0)
		return RIM1.lerp(RIM3, t * 2.0) if t < 0.5 else RIM3.lerp(RIM2, (t - 0.5) * 2.0)

	## Inner and outer radius of a round key's drawn ring, line width included. A thicker
	## ring grows inward only, so the key's outer edge stays where it was.
	func ring_band(r: Rect2) -> Vector2:
		var rad: float = r.size.x * 0.5
		var width: float = ring_w * (1.4 if motif == "hammered" else 1.0)
		var outer: float = rad + ring_w * 0.5
		return Vector2(outer - width, outer)

	func _ring_color() -> Color:
		match motif:
			"stitch":
				return Color("4d463f")
			"tape":
				return Color("6a675e")
			"hammered":
				return Color("41464c")
			"twine":
				return Color("706c5f")
		return ring

	## Fixed marks in the rim's inner band; r already carries the press sink.
	func _draw_motif(ci: RID, r: Rect2) -> void:
		var c := r.get_center()
		var rad: float = r.size.x * 0.5
		var w: float = ring_w
		if w <= 0.0 or rad <= 1.5 * w:
			return
		match motif:
			"stitch":
				var thread := Color("aaa398")
				thread.a = 0.3
				for i in 28:
					var a: float = TAU * float(i) / 28.0
					_motif_arc(ci, c, rad - 1.15 * w, a, a + 0.55 * w / rad, thread, 0.18 * w)
			"tape":
				var cloth := Color("b0aea2")
				cloth.a = 0.46
				for a: float in [-2.4, -0.6, 1.8]:
					var p := c + Vector2.from_angle(a - 0.06) * (rad - 1.6 * w)
					var q := c + Vector2.from_angle(a + 0.06) * (rad - 0.15 * w)
					_motif_line(ci, p, q, cloth, 0.9 * w)
			"hammered":
				var sheen := Color("92999e")
				sheen.a = 0.28
				_motif_arc(ci, c, rad - 0.7 * w, PI * 1.1, PI * 1.43, sheen, 0.16 * w)
				var dent := Color("a1a8ad")
				dent.a = 0.32
				for i in 8:
					var a: float = TAU * float(i) / 8.0 + 0.12
					var p := c + Vector2.from_angle(a - 0.012) * (rad - 0.95 * w)
					var q := c + Vector2.from_angle(a + 0.025) * (rad - 0.45 * w)
					_motif_line(ci, p, q, dent, 0.24 * w)
			"twine":
				var fibre := Color("a7a397")
				fibre.a = 0.3
				for i in 36:
					var a: float = TAU * float(i) / 36.0
					var p := c + Vector2.from_angle(a - 0.025) * (rad - 0.95 * w)
					var q := c + Vector2.from_angle(a + 0.025) * (rad - 0.15 * w)
					_motif_line(ci, p, q, fibre, 0.23 * w)
			"rivet":
				var metal := Color("30353b")
				metal.a = 0.88
				var glint := Color("a2a8ad")
				glint.a = 0.58
				for i in 4:
					var a: float = PI * 0.25 + float(i) * PI * 0.5
					var p := c + Vector2.from_angle(a) * (rad - 0.55 * w)
					_motif_dot(ci, p, 0.56 * w, metal)
					_motif_dot(ci, p + Vector2(-0.14, -0.16) * w, 0.18 * w, glint)

	func _motif_line(ci: RID, p: Vector2, q: Vector2, col: Color, width: float) -> void:
		var ink := Color(col.r, col.g, col.b, col.a * dim * ring.a)
		RenderingServer.canvas_item_add_polyline(ci, PackedVector2Array([p, q]), PackedColorArray([ink]), width, true)

	func _motif_arc(ci: RID, c: Vector2, rad: float, start: float, end: float, col: Color, width: float) -> void:
		var pts := PackedVector2Array()
		for i in 13:
			pts.append(c + Vector2.from_angle(lerpf(start, end, float(i) / 12.0)) * rad)
		var ink := Color(col.r, col.g, col.b, col.a * dim * ring.a)
		RenderingServer.canvas_item_add_polyline(ci, pts, PackedColorArray([ink]), width, true)

	func _motif_dot(ci: RID, c: Vector2, rad: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 12:
			pts.append(c + Vector2.from_angle(TAU * float(i) / 12.0) * rad)
		var ink := Color(col.r, col.g, col.b, col.a * dim * ring.a)
		RenderingServer.canvas_item_add_polygon(ci, pts, PackedColorArray([ink]))

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
		elif brass_rim and over_ring:
			var all := PackedVector2Array([r.get_center()])
			all.append_array(pts)
			var cols := PackedColorArray()
			for p in all:
				cols.append(_over(_rim_at(p, r)))
			var idx := PackedInt32Array()
			for i in pts.size():
				idx.append_array([0, 1 + i, 1 + (i + 1) % pts.size()])
			rs.canvas_item_add_triangle_array(to_canvas_item, idx, all, cols)
		elif over_ring and ring.a > 0.0:
			rs.canvas_item_add_polygon(to_canvas_item, pts, PackedColorArray([_over(ring)]))
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
			var width: float = ring_w
			if round_key and motif == "hammered":
				var band := ring_band(r)
				width = band.y - band.x
				loop = _outline(r.grow((band.x + band.y) * 0.5 - r.size.x * 0.5))
				loop.append(loop[0])
			var ink: Color = _ring_color() if round_key else ring
			rs.canvas_item_add_polyline(to_canvas_item, loop, PackedColorArray([Color(ink.r, ink.g, ink.b, ring.a * dim)]), width, true)
			if round_key and motif != "":
				_draw_motif(to_canvas_item, r)
