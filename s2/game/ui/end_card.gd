extends Control
## The end of the slice (밤 계획 2026-10-18 PR 3): the long sheet (UI 3단계 시안
## 2차 07 「긴 판」, k3d_views.js vLong · c4.css .lp, B1) over everything
## darkened. At the left its picture, stamped in: the mockup's twelfth (lp12,
## 「우리는 견뎌냈다」: the car's frosted window thawing at its middle onto a
## field at dawn) with its finish (lpFinish: dark corners, the dark foot under
## a caption, grain, the edge running out like ink in paper), baked as the
## mockup draws it (tex/lp_window.png); the caption at its foot, a line and a
## small line under it. At the right, on a dark of its own: the kick, the title,
## its rule, the line of why, what it cost as the sheet's bars (how much is
## left, how much went, hatched), and the main key at the foot. A good end
## (.lp.is-good): the title, its rule and the kick's dash in lamp amber. They
## come up one after another as the mockup's do (c4.css delays); a touch, or
## `still`, has them all up at once (.lp.skip).
##
## The words are the politics port's end card (field_arrival.gd end_card): its
## title, its first line as the why, its second (who stayed behind or that all
## came back) under the picture and its third (where the slice stops) small
## under that. The bars are the first return's record and the state now
## (people, coal, food from before the first stop to here), whole as the band
## shows them. It sets nothing.

signal went_on

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const LampKey = preload("res://game/ui/lamp_key.gd")
const FieldArrival = preload("res://game/politics/field_arrival.gd")
const FieldReturn = preload("res://game/politics/field_return.gd")
const PICTURE := preload("res://game/ui/tex/lp_window.png")

## The sheet on the mockup's 844 × 390 stage: .lp from 48, its picture at
## 28 · 22 in it (388 × 242), its words at 452 · 18 (362 × 254), the dark
## under them at 446 · 36 (350 × 212, corners of 40, spreading 40 and blurring 46).
const PIC := Rect2(28, 70, 388, 242)
const TXT := Rect2(452, 66, 362, 254)
const BLOB := Rect2(446, 84, 350, 212)
const BLOB_R: float = 40.0
const BLOB_SPREAD: float = 40.0
const BLOB_BLUR: float = 46.0
## .lpdim and the dark under the words.
const DIM := Color(2 / 255.0, 4 / 255.0, 6 / 255.0, 0.78)
const UNDER := Color(2 / 255.0, 4 / 255.0, 6 / 255.0, 0.84)
const INK := Color("eee9dc")
const CAPTION := Color("f1ecdf")
## .lp.is-good: the title's amber and the lamp amber of its rule and the dash.
const GOOD := Color("f8c97c")
const AMBER := Color("f2a63c")
const KICK := "끝 · 둘째 역"
## The title in the hand (the serif waits on its decision): the mockup's 32 serif
## stands this tall in the pen.
const TITLE_CSS: float = 42.0
## The bars' columns (.lp__loss li: 58 · 1fr · 34 · 38, 8 apart, 24 high).
const ROW_H: float = 24.0
const COLS: Array = [58.0, 0.0, 34.0, 38.0]
const COL_GAP: float = 8.0
## When each part comes up (c4.css): [part, delay s, length s].
const SHOW: Array = [["Kick", 1.0, 0.4], ["Title", 1.6, 0.4], ["Why", 2.0, 0.4], ["Row0", 2.8, 0.3],
		["Row1", 3.15, 0.3], ["Row2", 3.5, 0.3], ["Caption", 4.2, 0.5], ["Go", 5.0, 0.4]]
const DIM_S: float = 0.7
## The picture stamped in (lpStamp .15 s at .7 s), then shaken (lpShake .3 s
## at .85 s: across 0, −6, 6, −4, 4, 0).
const STAMP_AT: float = 0.7
const STAMP_S: float = 0.15
const SHAKE_AT: float = 0.85
const SHAKE_S: float = 0.3
const SHAKE: Array = [-6.0, 6.0, -4.0, 4.0, 0.0]
const RISE_CSS: float = 5.0

## The state the slice ended in (field_arrival.gd finish_slice) and its tables.
var g: Dictionary = {}
var t: Dictionary = {}
var go_word: String = ""
## Everything up at once, no coming up (screens for checks).
var still: bool = false
var go_key: Button
var _dim: ColorRect
var _frame: TextureRect
var _words: Control
var _tweens: Array = []


## What the sheet says for the end state (tests read this; the sheet draws it).
static func model(g0: Dictionary, t0: Dictionary) -> Dictionary:
	if g0.is_empty():
		return {}
	var card: Dictionary = FieldArrival.end_card(g0)
	var lines: Array = card.get("lines", [])
	var rows: Array = []
	var fr: Variant = g0.get("fieldReturns")
	if fr is Dictionary and not (fr.get("records", []) as Array).is_empty() and not t0.is_empty():
		var before: Dictionary = fr["records"][0]["before"]
		var now: Dictionary = FieldReturn.snapshot(g0, t0)
		rows.append(["사람", _sum(before["pop"]), _sum(now["pop"])])
		rows.append(["석탄", int(round(float(before["coal"]))), int(round(float(now["coal"])))])
		rows.append(["식량", int(round(float(before["food"]))), int(round(float(now["food"])))])
	return {
		"kick": KICK,
		"title": String(card.get("title", "")),
		"good": true,
		"why": String(lines[0]) if lines.size() > 0 else "",
		"caption": String(lines[1]) if lines.size() > 1 else "",
		"small": String(lines[2]) if lines.size() > 2 else "",
		"rows": rows,
	}


static func _sum(d: Dictionary) -> int:
	var n: float = 0.0
	for v in d.values():
		n += float(v)
	return int(round(n))


## How much of a bar is left and how much went, 0–1 each, for [word, before, now].
static func bar_of(row: Array) -> Vector2:
	var a: float = float(row[1])
	var b: float = float(row[2])
	if a <= 0.0:
		return Vector2(1.0, 0.0)
	var left: float = clampf(b / a, 0.0, 1.0)
	return Vector2(left, 1.0 - left)


## The small number after a bar: what went (「−2」), what came, or 「그대로」.
static func moved_of(row: Array) -> String:
	var d: int = int(row[2]) - int(row[1])
	if d == 0:
		return "그대로"
	return ("+%d" % d) if d > 0 else ("−%d" % -d)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var k: float = UiFonts.K
	var m: Dictionary = model(g, t)
	var good: bool = bool(m.get("good", false))
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = DIM
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	var under := Control.new()
	under.name = "Under"
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	under.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	under.draw.connect(_draw_under.bind(under))
	_dim.add_child(under)
	var pic := Rect2(PIC.position * k, PIC.size * k)
	_frame = TextureRect.new()
	_frame.name = "Picture"
	_frame.texture = PICTURE
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.position = pic.position
	_frame.size = pic.size
	_frame.pivot_offset = pic.size * 0.5
	add_child(_frame)
	_words = Control.new()
	_words.name = "Words"
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_words.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_words)
	if String(m.get("caption", "")) != "" or String(m.get("small", "")) != "":
		_caption(String(m.get("caption", "")), String(m.get("small", "")))
	_column(m, good)
	if not still:
		_come_up()


## The dark under the words (.lp::before): its own and its spread, blurred.
func _draw_under(c: Control) -> void:
	var k: float = UiFonts.K
	var r := Rect2(BLOB.position * k, BLOB.size * k)
	# A spread of 40 blurred 46: half dark at 40 out, the ring fading over the blur.
	var grow: float = (BLOB_SPREAD - BLOB_BLUR * 0.5) * k
	var sb := StyleBoxFlat.new()
	sb.bg_color = UNDER
	sb.shadow_color = UNDER
	sb.shadow_size = int(round(BLOB_BLUR * k))
	sb.set_corner_radius_all(int(round((BLOB_R + BLOB_SPREAD - BLOB_BLUR * 0.5) * k)))
	sb.corner_detail = 12
	c.draw_style_box(sb, r.grow(grow))
	var body := StyleBoxFlat.new()
	body.bg_color = UNDER
	body.set_corner_radius_all(int(round(BLOB_R * k)))
	body.corner_detail = 12
	c.draw_style_box(body, r)


## The caption at the picture's foot (.lp__q: 22 in from its sides, 12 up from
## its foot): the line (14 on 21), and the small line under it (12 on 16, .1em
## apart, after a dash of 14 × 2, 6 before the words), in the picture's own
## shadow (0 1px 3px #000).
func _caption(line: String, small: String) -> void:
	var k: float = UiFonts.K
	var box := VBoxContainer.new()
	box.name = "Caption"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	_frame.add_child(box)
	var w: float = (PIC.size.x - 44.0) * k
	if line != "":
		var l := _wrapped(line, 14.0, 21.0, CAPTION, w)
		l.name = "Line"
		_shadowed(l)
		var half: float = _half_leading(l, 21.0)
		box.add_child(_gap_px(half))
		box.add_child(l)
		box.add_child(_gap_px(half))
	if small != "":
		var row := HBoxContainer.new()
		row.name = "Small"
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.custom_minimum_size = Vector2(0, 16.0 * k)
		row.add_theme_constant_override("separation", int(round(6.0 * k)))
		box.add_child(row)
		var dash := ColorRect.new()
		dash.color = Color(INK, 0.5)
		dash.custom_minimum_size = Vector2(14.0, 2.0) * k
		dash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dash)
		var s := UiFonts.label(small, UiFonts.WORD, 400, 12.0, Color(INK, 0.66), 1.2)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_shadowed(s)
		row.add_child(s)
	# Its foot 12 up from the picture's: laid where its lines end, so it can rise.
	var h: float = box.get_combined_minimum_size().y
	box.position = Vector2(22.0 * k, PIC.size.y * k - 12.0 * k - h)
	box.size = Vector2(w, h)


func _shadowed(l: Label) -> void:
	var k: float = UiFonts.K
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", int(round(1.0 * k)))
	l.add_theme_constant_override("shadow_outline_size", int(round(3.0 * k)))


## The words' column (.lp__txt), each part laid where the mockup's flow puts it
## (each its own so each can rise as it comes up): the kick (16), 3 under it
## the title (a line of 44) and 5 under that its rule (54 × 2), 9 under that
## the why (14 on 22), 12 under that the bars (24 each); the key at the foot.
func _column(m: Dictionary, good: bool) -> void:
	var k: float = UiFonts.K
	var x0: float = TXT.position.x * k
	var w: float = TXT.size.x * k
	var y: float = TXT.position.y * k
	# The kick: a short dash, 8 apart, the words (.2em).
	var kick := _part("Kick", Rect2(x0, y, w, 16.0 * k))
	var dash := ColorRect.new()
	dash.color = AMBER if good else Color(INK, 0.5)
	dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dash.position = Vector2(0, (16.0 - 2.0) * 0.5 * k)
	dash.size = Vector2(18.0, 2.0) * k
	kick.add_child(dash)
	var kw := UiFonts.label(String(m.get("kick", KICK)), UiFonts.WORD, 400, 12.0, Color(INK, 0.66), 2.4)
	_centred(kick, kw, 26.0 * k)
	y += (16.0 + 3.0) * k
	# The title in its line of 44, its rule 5 under it.
	var title := _part("Title", Rect2(x0, y, w, (44.0 + 5.0 + 2.0) * k))
	var tw := UiFonts.label(String(m.get("title", "")), UiFonts.HAND, 400, TITLE_CSS, GOOD if good else INK)
	tw.name = "TitleWord"
	var line := Control.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.size = Vector2(w, 44.0 * k)
	title.add_child(line)
	_centred(line, tw, 0.0)
	var rule := Control.new()
	rule.name = "Rule"
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.position = Vector2(0, (44.0 + 5.0) * k)
	rule.size = Vector2(54.0, 2.0) * k
	rule.draw.connect(_draw_rule.bind(rule, good))
	title.add_child(rule)
	y += (44.0 + 5.0 + 2.0 + 9.0) * k
	# Why, its lines 22 apart.
	var why_text: String = String(m.get("why", ""))
	if why_text != "":
		var why := _part("Why", Rect2(x0, y, w, 22.0 * k))
		var l := _wrapped(why_text, 14.0, 22.0, Color(INK, 0.92), w)
		l.position = Vector2(0, _half_leading(l, 22.0))
		why.add_child(l)
		why.size.y = maxi(1, l.get_line_count()) * 22.0 * k
		y += why.size.y
	y += 12.0 * k
	var rows: Array = m.get("rows", [])
	for i in rows.size():
		_bar_row(_part("Row%d" % i, Rect2(x0, y, w, ROW_H * k)), rows[i])
		y += ROW_H * k
	go_key = LampKey.new(go_word)
	go_key.name = "Go"
	go_key.pressed.connect(func() -> void: went_on.emit())
	_words.add_child(go_key)
	var key_size: Vector2 = go_key.custom_minimum_size
	go_key.size = key_size
	go_key.position = Vector2(TXT.end.x * k - key_size.x, TXT.end.y * k - key_size.y)


## A part of the column at `r`, on the words' layer.
func _part(part_name: String, r: Rect2) -> Control:
	var c := Control.new()
	c.name = part_name
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_words.add_child(c)
	c.position = r.position
	c.size = r.size
	return c


## `l` across `holder` from `left`, its line centred in the holder's height as
## a line box centres its text.
func _centred(holder: Control, l: Label, left: float) -> void:
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = 0.5
	l.anchor_bottom = 0.5
	l.offset_left = left
	l.offset_right = 0.0
	l.offset_top = 0.0
	l.offset_bottom = 0.0
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(l)


## The rule under the title (54 × 2): faint ink, or on a good end lamp amber
## glowing (0 0 8px rgba(242,166,60,.7)). A blur of 8 over a line 2 high is a
## faint haze where it is thickest, so the glow starts at a quarter of that .7
## and fades over the 8.
func _draw_rule(c: Control, good: bool) -> void:
	var sb := StyleBoxFlat.new()
	if good:
		sb.bg_color = AMBER
		sb.shadow_color = Color(242 / 255.0, 166 / 255.0, 60 / 255.0, 0.7 * 0.25)
		sb.shadow_size = int(round(8.0 * UiFonts.K))
		sb.set_corner_radius_all(1)
		sb.corner_detail = 8
	else:
		sb.bg_color = Color(INK, 0.4)
	c.draw_style_box(sb, Rect2(Vector2.ZERO, c.size))


## One bar's row (.lp__loss li): the word, the bar (what is left in paper white,
## what went hatched), the number now, the small number of what moved.
func _bar_row(h: Control, row: Array) -> void:
	var k: float = UiFonts.K
	var bar_w: float = TXT.size.x - float(COLS[0]) - float(COLS[2]) - float(COLS[3]) - COL_GAP * 3.0
	var xs: Array = [0.0, float(COLS[0]) + COL_GAP, float(COLS[0]) + bar_w + COL_GAP * 2.0, float(COLS[0]) + bar_w + float(COLS[2]) + COL_GAP * 3.0]
	var ws: Array = [float(COLS[0]), bar_w, float(COLS[2]), float(COLS[3])]
	var cells: Array = []
	for i in 4:
		var c := Control.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(c)
		c.position = Vector2(float(xs[i]) * k, 0)
		c.size = Vector2(float(ws[i]) * k, ROW_H * k)
		cells.append(c)
	_centred(cells[0], UiFonts.label(String(row[0]), UiFonts.WORD, 400, 13.0, Color(INK, 0.72), 0.78), 0.0)
	var bar: Control = cells[1]
	bar.name = "Bar"
	bar.set_meta("split", bar_of(row))
	bar.draw.connect(_draw_bar.bind(bar))
	var n := UiFonts.label(str(int(row[2])), UiFonts.NUMBER, 500, 19.0, INK)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_centred(cells[2], n, 0.0)
	var mv: String = moved_of(row)
	var same: bool = mv == "그대로"
	_centred(cells[3], UiFonts.label(mv, UiFonts.WORD if same else UiFonts.NUMBER, 400, 12.0 if same else 14.0, Color(INK, 0.56)), 0.0)


## The bar (.lbar: 8 high, its parts 2 apart, each its share of the bar): what
## is left from paper white down to grey (#f2eee2 → #c9c4b6), rounded at its
## left; what went hatched (stripes 2 of every 5 across −58°) in a faint ring,
## rounded at its right.
func _draw_bar(c: Control) -> void:
	var k: float = UiFonts.K
	var split: Vector2 = c.get_meta("split", Vector2(1, 0))
	var bh: float = 8.0 * k
	var y: float = roundf((c.size.y - bh) * 0.5)
	var r: float = 4.0 * k
	var lw: float = maxf(2.0 * k, c.size.x * split.x) if split.x > 0.0 else 0.0
	if lw > 0.0:
		var pts: PackedVector2Array = _rounded(Rect2(0, y, lw, bh), minf(r, lw * 0.5), 0.0, 0.0, minf(r, lw * 0.5))
		var cols := PackedColorArray()
		for p in pts:
			cols.append(Color("f2eee2").lerp(Color("c9c4b6"), clampf((p.y - y) / bh, 0.0, 1.0)))
		c.draw_polygon(pts, cols)
	if split.y <= 0.0:
		return
	var x0: float = (lw + 2.0 * k) if lw > 0.0 else 0.0
	var rw: float = minf(c.size.x * split.y, c.size.x + 2.0 * k - x0)
	if rw <= 0.5:
		return
	var shape: PackedVector2Array = _rounded(Rect2(x0, y, rw, bh), 0.0, minf(r, rw), minf(r, rw), 0.0)
	var hatch := Color(168 / 255.0, 170 / 255.0, 174 / 255.0, 0.72)
	# −58°: the stripes run up and to the right, 5 apart across them.
	var s58: float = sin(deg_to_rad(58.0))
	var step: float = 5.0 * k / s58
	var sw: float = 2.0 * k / s58
	var lean: float = bh / tan(deg_to_rad(58.0))
	var x: float = x0 - lean
	while x < x0 + rw:
		var stripe := PackedVector2Array([Vector2(x, y + bh), Vector2(x + sw, y + bh), Vector2(x + sw + lean, y), Vector2(x + lean, y)])
		for poly: PackedVector2Array in Geometry2D.intersect_polygons(stripe, shape):
			c.draw_colored_polygon(poly, hatch)
		x += step
	# inset 0 0 0 1px rgba(168,170,174,.4)
	var half: float = 0.5 * k
	var ring: PackedVector2Array = _rounded(Rect2(x0 + half, y + half, rw - half * 2.0, bh - half * 2.0), 0.0, maxf(0.0, minf(r, rw) - half), maxf(0.0, minf(r, rw) - half), 0.0)
	ring.append(ring[0])
	c.draw_polyline(ring, Color(168 / 255.0, 170 / 255.0, 174 / 255.0, 0.4), 1.0 * k, true)


## A rect's outline with its corners rounded (top left, top right, bottom
## right, bottom left), clockwise from its top left.
static func _rounded(r: Rect2, tl: float, tr: float, br: float, bl: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners: Array = [
		[Vector2(r.position.x + tl, r.position.y + tl), tl, PI],
		[Vector2(r.end.x - tr, r.position.y + tr), tr, PI * 1.5],
		[Vector2(r.end.x - br, r.end.y - br), br, 0.0],
		[Vector2(r.position.x + bl, r.end.y - bl), bl, PI * 0.5],
	]
	for corner: Array in corners:
		var centre: Vector2 = corner[0]
		var rad: float = corner[1]
		if rad <= 0.0:
			pts.append(centre)
			continue
		for i in 7:
			var a: float = float(corner[2]) + PI * 0.5 * i / 6.0
			pts.append(centre + Vector2(cos(a), sin(a)) * rad)
	return pts


func _wrapped(text: String, css: float, line_css: float, col: Color, w: float) -> Label:
	var l := UiFonts.label(UiFonts.keep_all(text), UiFonts.WORD, 400, css, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	l.size = Vector2(w, 0)
	var f: Font = l.get_theme_font("font")
	var fs: int = l.get_theme_font_size("font_size")
	l.add_theme_constant_override("line_spacing", int(round(line_css * UiFonts.K - f.get_height(fs))))
	return l


## Half of what a line box of `line_css` holds over the label's own line: the
## room a line box leaves above its text.
func _half_leading(l: Label, line_css: float) -> float:
	var f: Font = l.get_theme_font("font")
	var fs: int = l.get_theme_font_size("font_size")
	return maxf(0.0, (line_css * UiFonts.K - f.get_height(fs)) * 0.5)


func _gap_px(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## The sheet comes up as the mockup's: the dark (.7 s), the picture stamped in
## and shaken, then the words one after another, each rising 5 px as it shows.
func _come_up() -> void:
	_dim.modulate.a = 0.0
	_frame.modulate.a = 0.0
	_frame.scale = Vector2(1.05, 1.05)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_dim, "modulate:a", 1.0, DIM_S)
	tw.tween_property(_frame, "modulate:a", 1.0, STAMP_S).set_delay(STAMP_AT)
	tw.tween_property(_frame, "scale", Vector2.ONE, STAMP_S).set_delay(STAMP_AT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for s: Array in SHOW:
		var part: Control = find_child(String(s[0]), true, false) as Control
		if part == null:
			continue
		part.modulate.a = 0.0
		tw.tween_property(part, "modulate:a", 1.0, float(s[2])).set_delay(float(s[1]))
		if not part.get_parent() is Container:
			var at: Vector2 = part.position
			part.position = at + Vector2(0, RISE_CSS * UiFonts.K)
			tw.tween_property(part, "position", at, float(s[2])).set_delay(float(s[1])).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tweens.append(tw)
	var shake := create_tween()
	shake.tween_interval(SHAKE_AT)
	var x0: float = _frame.position.x
	for dx: float in SHAKE:
		shake.tween_property(_frame, "position:x", x0 + dx * UiFonts.K, SHAKE_S / SHAKE.size()).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tweens.append(shake)


## Up at once (a touch while it comes up).
func skip() -> void:
	for tw: Tween in _tweens:
		if tw.is_valid() and tw.is_running():
			tw.custom_step(10.0)


func _coming_up() -> bool:
	for tw: Tween in _tweens:
		if tw.is_valid() and tw.is_running():
			return true
	return false


func _gui_input(e: InputEvent) -> void:
	var up_click: bool = e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not e.is_pressed()
	var up_touch: bool = e is InputEventScreenTouch and not e.is_pressed()
	if (up_click or up_touch) and _coming_up():
		skip()
		accept_event()
