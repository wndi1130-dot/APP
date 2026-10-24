extends RefCounted
## What is drawn on the smoked glass of the train's screens (UI 3단계 시안 2차,
## B1 「성에 낀 계기」): the matte medal keys, a word set where the mockup's box
## puts it, rounded shapes with a gradient across them, the paper tag that
## hangs on a cold car (.ptag), and the shade a dimmed part takes. Every size
## is the mockup's px (ui_fonts.gd turns them into the game's).

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const TypeLine = preload("res://game/ui/type_line.gd")
const PAPER_TEX := preload("res://game/ui/tex/paper.png")

## 디자인 토큰 2차: the medal's dark enamel, its ring, the paper and its ink.
const MEDAL_TOP := Color("182028")
const MEDAL_BOT := Color("11171d")
const RING := Color("6d5b3d")
const MEDAL_CUT := Color("141b22")
const PAPER := Color("cdc2a8")
const TAG_INK := Color("231a12")
## The paper's fibre tile (--tx-paper), in mockup px.
const PAPER_TILE: float = 240.0

## Glows made so far, by size and colour.
static var _glows: Dictionary = {}


## A colour as a dimmed part shows it: saturate(.3), then a third of its alpha.
static func tone(c: Color, dim: bool) -> Color:
	if not dim:
		return c
	var grey: float = c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
	return Color(lerpf(grey, c.r, 0.3), lerpf(grey, c.g, 0.3), lerpf(grey, c.b, 0.3), c.a * 0.3)


## A matte medal (.med): a `box_css` square holding a disc `disc_css` across,
## dark with a faint light at the top and one even ring (user 2026-10-17), its
## mark `icon_css` across in `color` at .86.
static func medal(icon: String, color: Color, box_css: float = 44.0, disc_css: float = 38.0, icon_css: float = 22.0, dim: bool = false) -> Control:
	var k: float = UiFonts.K
	var m := Control.new()
	m.name = "Medal_" + icon
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.size = Vector2(box_css, box_css) * k
	m.custom_minimum_size = m.size
	var r: float = disc_css * 0.5 * k
	var shades: Array = []
	for i in 3:
		shades.append(tone(Color(0, 0, 0, 0.08 + 0.05 * i), dim))
	var top: Color = tone(MEDAL_TOP, dim)
	var bot: Color = tone(MEDAL_BOT, dim)
	var ring: Color = tone(RING, dim)
	m.draw.connect(func() -> void:
		var c: Vector2 = m.size * 0.5
		# 0 1px 3px rgba(0,0,0,.45): a soft shadow a little low.
		for i in 3:
			m.draw_circle(c + Vector2(0, 1.0 * k), r + float(3 - i) * k, shades[i], true, -1.0, true)
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i in 48:
			var a: float = TAU * float(i) / 48.0
			var p: Vector2 = c + Vector2(cos(a), sin(a)) * r
			pts.append(p)
			cols.append(top.lerp(bot, (p.y - (c.y - r)) / (r * 2.0)))
		m.draw_polygon(pts, cols)
		m.draw_arc(c, r - 1.0 * k, 0.0, TAU, 64, ring, 2.0 * k, true))
	var mark := TextureRect.new()
	mark.name = "Mark"
	var px: int = int(round(icon_css * k))
	mark.texture = HudIcons.texture(icon, px, tone(Color(color.r, color.g, color.b, 0.86), dim), 2.0, tone(MEDAL_CUT, dim))
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.size = Vector2(px, px)
	mark.position = (m.size - mark.size) * 0.5
	m.add_child(mark)
	return m


## Put `l` at `x_css` so it sits as the mockup's box at `top_css` does: a box
## `h_css` high centres its line in it (a block's line box); with no height
## the box is the type's own (an inline box), its top at `top_css`.
static func put(l: Label, x_css: float, top_css: float, h_css: float = -1.0) -> void:
	var r: Vector2 = shaped(l)
	var base: float = top_css * UiFonts.K + r.x
	if h_css >= 0.0:
		base += (h_css * UiFonts.K - (r.x + r.y)) * 0.5
	put_on(l, x_css * UiFonts.K, base)


## How far `l`'s type rises above its baseline and falls below it, as it is
## shaped (a face's fallbacks make its box taller than the words it draws).
static func shaped(l: Label) -> Vector2:
	var tl := TextLine.new()
	tl.add_string(l.text if l.text != "" else " ", l.get_theme_font("font"), l.get_theme_font_size("font_size"))
	return Vector2(tl.get_line_ascent(), tl.get_line_descent())


## Put `l` with its baseline at `base` (game px) and its left at `x` (game px).
static func put_on(l: Label, x: float, base: float) -> void:
	l.size = l.get_combined_minimum_size()
	l.position = Vector2(x, base - TypeLine.rise_of(l).x)


## Where `l`'s baseline is, in game px.
static func base_of(l: Label) -> float:
	return l.position.y + TypeLine.rise_of(l).x


## How wide `l`'s words are, in game px (off its face, so it holds before it is laid out).
static func text_w(l: Label) -> float:
	var f: Font = l.get_theme_font("font")
	var s: int = l.get_theme_font_size("font_size")
	return f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x


## A rounded rect with soft edges.
static func round_rect(ci: CanvasItem, rect: Rect2, radius: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(round(radius)))
	sb.corner_detail = 8
	sb.anti_aliasing_size = 0.7
	ci.draw_style_box(sb, rect)


## The outline of `rect` with corners of `radius`, points close along its
## edges so a colour per point can follow a gradient across it.
static func outline(rect: Rect2, radius: float, step: float = 2.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var n: int = 6
	var corners: Array = [
		[Vector2(rect.end.x - r, rect.position.y + r), -PI * 0.5],
		[Vector2(rect.end.x - r, rect.end.y - r), 0.0],
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5],
		[Vector2(rect.position.x + r, rect.position.y + r), PI],
	]
	var x: float = rect.position.x + r
	while x < rect.end.x - r:
		out.append(Vector2(x, rect.position.y))
		x += step
	for i in 4:
		var cn: Array = corners[i]
		for j in n + 1:
			var a: float = float(cn[1]) + PI * 0.5 * float(j) / float(n)
			out.append((cn[0] as Vector2) + Vector2(cos(a), sin(a)) * r)
		if i == 1:
			x = rect.end.x - r
			while x > rect.position.x + r:
				out.append(Vector2(x, rect.end.y))
				x -= step
	return out


## `stops` ([[0–1, Color], …]) at `f`.
static func grad_at(stops: Array, f: float) -> Color:
	f = clampf(f, 0.0, 1.0)
	for i in range(1, stops.size()):
		var a: Array = stops[i - 1]
		var b: Array = stops[i]
		if f <= float(b[0]):
			return (a[1] as Color).lerp(b[1], (f - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001))
	return stops[stops.size() - 1][1]


## A rounded rect filled with a gradient from its left to its right: upright
## strips, each its own two colours, so no triangle spans a stop; a soft edge
## round the outside.
static func grad_rect(ci: CanvasItem, rect: Rect2, radius: float, stops: Array) -> void:
	if rect.size.x <= 0.5 or rect.size.y <= 0.5:
		return
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var n: int = maxi(2, int(ceil(rect.size.x / 1.5)))
	var prev_x: float = rect.position.x
	var prev_y: Vector2 = _span(rect, r, prev_x)
	var prev_c: Color = grad_at(stops, 0.0)
	for i in range(1, n + 1):
		var x: float = rect.position.x + rect.size.x * float(i) / float(n)
		var y: Vector2 = _span(rect, r, x)
		var col: Color = grad_at(stops, float(i) / float(n))
		ci.draw_polygon(PackedVector2Array([Vector2(prev_x, prev_y.x), Vector2(x, y.x), Vector2(x, y.y), Vector2(prev_x, prev_y.y)]), PackedColorArray([prev_c, col, col, prev_c]))
		prev_x = x
		prev_y = y
		prev_c = col
	var ring: PackedVector2Array = outline(rect, r, 1.5)
	var ring_c := PackedColorArray()
	for p in ring:
		ring_c.append(grad_at(stops, (p.x - rect.position.x) / rect.size.x))
	ring.append(ring[0])
	ring_c.append(ring_c[0])
	ci.draw_polyline_colors(ring, ring_c, 1.0, true)


## How far up and down a rect with corners of `r` reaches at `x`.
static func _span(rect: Rect2, r: float, x: float) -> Vector2:
	var dx: float = 0.0
	if x < rect.position.x + r:
		dx = rect.position.x + r - x
	elif x > rect.end.x - r:
		dx = x - (rect.end.x - r)
	var inset: float = r - sqrt(maxf(0.0, r * r - dx * dx)) if dx > 0.0 else 0.0
	return Vector2(rect.position.y + inset, rect.end.y - inset)


## The glow a round part casts (box-shadow 0 0 `blur` `col` on a circle of
## `radius`, game px): a blur's fall-off outside its edge only, as a browser
## clips an outer shadow, so a see-through part over it keeps its own shade.
static func glow_ring(ci: CanvasItem, center: Vector2, radius: float, blur: float, col: Color) -> void:
	var reach: float = radius + blur * 1.5
	var key: String = "%.2f@%.2f@%s" % [radius, blur, col.to_html()]
	if not _glows.has(key):
		var g := Gradient.new()
		var offs := PackedFloat32Array([0.0, maxf(0.0, radius / reach - 0.002)])
		var cols := PackedColorArray([Color(col, 0.0), Color(col, 0.0)])
		for i in 16:
			var d: float = blur * 1.5 * float(i) / 15.0
			offs.append(clampf((radius + d) / reach, 0.0, 1.0))
			cols.append(Color(col, col.a * _tail(d / (blur * 0.5))))
		g.offsets = offs
		g.colors = cols
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = int(ceil(reach * 2.0))
		tex.height = tex.width
		_glows[key] = tex
	ci.draw_texture_rect(_glows[key], Rect2(center - Vector2(reach, reach), Vector2(reach, reach) * 2.0), false)


## How much of a blur (a normal spread) lies past `x` of its sigmas.
static func _tail(x: float) -> float:
	if x < 0.0:
		return 1.0 - _tail(-x)
	var t: float = 1.0 / (1.0 + 0.2316419 * x)
	var poly: float = t * (0.319381530 + t * (-0.356563782 + t * (1.781477937 + t * (-1.821255978 + t * 1.330274429))))
	return exp(-0.5 * x * x) / sqrt(TAU) * poly


## A soft shadow under a rounded rect: `blur` and `drop` in game px.
static func shadow(ci: CanvasItem, rect: Rect2, radius: float, drop: float, blur: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.0)
	sb.shadow_color = col
	sb.shadow_size = int(round(blur))
	sb.shadow_offset = Vector2(0, drop)
	sb.set_corner_radius_all(int(round(radius)))
	ci.draw_style_box(sb, rect)


## The paper tag that hangs on a cold car (.ptag): paper with its fibre, cut
## to a point at the left, tilted `tilt` degrees, a line icon and a word in
## ink (no word: the mark alone). Its touch is the parent's; it only shows.
static func paper_tag(word: String, icon: String = "snow", tilt: float = -2.0) -> Control:
	var k: float = UiFonts.K
	var c := Control.new()
	c.name = "Tag"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := UiFonts.label(word, UiFonts.WORD, 500, 12.0, TAG_INK, 0.72)
	w.name = "Word"
	var mark := TextureRect.new()
	var px: int = int(round(12.0 * k))
	mark.texture = HudIcons.texture(icon, px, TAG_INK, 2.4, HudIcons.CUT_PAPER)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.size = Vector2(px, px)
	# padding 0 7 0 9, gap 3, 18 high.
	var width: float = (9.0 + 12.0 + 7.0) * k + ((3.0 * k + text_w(w)) if word != "" else 0.0)
	c.size = Vector2(width, 18.0 * k)
	c.custom_minimum_size = c.size
	c.pivot_offset = c.size * 0.5
	c.rotation_degrees = tilt
	var body := Control.new()
	body.name = "Paper"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size = c.size
	body.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	body.draw.connect(func() -> void:
		var s: Vector2 = body.size
		var tip: float = 6.0 * k
		var pts := PackedVector2Array([Vector2(tip, 0), Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(tip, s.y), Vector2(0, s.y * 0.5)])
		# 0 1px 2px rgba(0,0,0,.6) under the cut shape.
		for i in 2:
			var d: float = (1.0 + 0.6 * i) * k
			var under := PackedVector2Array()
			for p in pts:
				under.append(p + Vector2(0, d))
			body.draw_colored_polygon(under, Color(0, 0, 0, 0.3 - 0.12 * i))
		body.draw_colored_polygon(pts, PAPER)
		var uvs := PackedVector2Array()
		for p in pts:
			uvs.append(p / (PAPER_TILE * k))
		body.draw_polygon(pts, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]), uvs, PAPER_TEX))
	c.add_child(body)
	mark.position = Vector2(9.0 * k, (c.size.y - mark.size.y) * 0.5)
	c.add_child(mark)
	if word == "":
		w.free()
		return c
	c.add_child(w)
	# Its word on the line its ink sits on in the mockup, 13.3 down the 18.
	put_on(w, (9.0 + 12.0 + 3.0) * k, 13.3 * k)
	return c
