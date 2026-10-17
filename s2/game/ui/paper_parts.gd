extends RefCounted
## What is drawn on paper (UI 3단계 시안 2차 c2.css · c8.css, B1 「종이 위 · 먹빛」):
## ink words, chips with an ink ring or filled with ink when picked, the pick
## chips of what to go for with a bar under the word, keys with no ring but a
## faint line under the word, and the stamp at the end of a line. Every size
## is the mockup's px (ui_fonts.gd turns them into the game's). A chip's touch
## reaches 5 px past what is drawn above and below (.chip::after), as the mockup's.

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")

## 디자인 토큰 2차: paper, ink, side ink, the seal's brown, the amber.
const PAPER := Color("cdc2a8")
const INK := Color("231a12")
const INK2 := Color(35 / 255.0, 26 / 255.0, 18 / 255.0, 0.72)
const RING := Color(42 / 255.0, 32 / 255.0, 24 / 255.0, 0.24)
const LINE := Color(42 / 255.0, 32 / 255.0, 24 / 255.0, 0.3)
const TRACK := Color(42 / 255.0, 32 / 255.0, 24 / 255.0, 0.15)
const TRACK_ON := Color(231 / 255.0, 222 / 255.0, 200 / 255.0, 0.26)
const SUB_ON := Color(231 / 255.0, 222 / 255.0, 200 / 255.0, 0.74)
const PRESS := Color(42 / 255.0, 32 / 255.0, 24 / 255.0, 0.08)
const STAMP := Color(35 / 255.0, 26 / 255.0, 18 / 255.0, 0.42)
const SEAL := Color("7e3f1c")
const AMBER := Color("f2a63c")
## The touch reaches this far past the drawn chip above and below.
const TOUCH_Y: float = 5.0
## A pick chip's touch is 44 high as a chip's is (.chip--t::after −3 px).
const TOUCH_T: float = 3.0


static func ink(text: String, kind: int, weight: int, css_px: float, color: Color = INK, spacing: float = 0.0) -> Label:
	return UiFonts.label(text, kind, weight, css_px, color, spacing)


## A box of `css_h` mockup px holding `c` centred upright (a flex row's line).
static func line_box(css_h: float) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, UiFonts.px(css_h))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.alignment = BoxContainer.ALIGNMENT_BEGIN
	return h


static func _ring_box(on: bool, radius: float, pad_x: float, css_h: float, touch_h: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(round(UiFonts.px(radius))))
	sb.corner_detail = 12
	sb.anti_aliasing_size = 0.8
	var trim: float = -UiFonts.px((touch_h - css_h) * 0.5)
	sb.expand_margin_top = trim
	sb.expand_margin_bottom = trim
	sb.content_margin_left = UiFonts.px(pad_x)
	sb.content_margin_right = UiFonts.px(pad_x)
	if on:
		sb.bg_color = INK
		sb.shadow_color = Color(0, 0, 0, 0.4)
		sb.shadow_size = int(round(UiFonts.px(2.0)))
		sb.shadow_offset = Vector2(0, UiFonts.px(1.0))
	else:
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_border_width_all(int(round(UiFonts.px(2.0))))
		sb.border_color = RING
	return sb


static func _skin(b: Button, on: bool, radius: float, pad_x: float, css_h: float, touch_h: float) -> void:
	var rest := _ring_box(on, radius, pad_x, css_h, touch_h)
	var down := _ring_box(on, radius, pad_x, css_h, touch_h)
	if not on:
		down.bg_color = PRESS
	for state in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, rest)
	for state in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, down)


## A chip (.chip): 34 high, a 2 px ink ring, the word at 14/500; picked it is
## filled with ink and the word turns paper. `sub` follows the word, smaller.
static func chip(word: String, on: bool, sub: String = "", pad_x: float = 12.0) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, UiFonts.px(34.0 + TOUCH_Y * 2.0))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_skin(b, on, 17.0, pad_x, 34.0, 34.0 + TOUCH_Y * 2.0)
	if sub == "":
		b.text = word
		UiFonts.style(b, UiFonts.WORD, 500, 14.0, PAPER if on else INK, 0.56)
		return b
	# A word and its smaller cost: two labels in the chip, the key's own text empty.
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(round(UiFonts.px(5.0))))
	row.add_child(ink(word, UiFonts.WORD, 500, 14.0, PAPER if on else INK, 0.56))
	row.add_child(ink(sub, UiFonts.NUMBER, 400, 13.0, SUB_ON if on else INK2, 0.26))
	for l in row.get_children():
		(l as Label).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_child(row)
	var fit := func() -> void:
		var need: Vector2 = row.get_combined_minimum_size()
		b.custom_minimum_size.x = need.x + UiFonts.px(pad_x * 2.0)
		row.position = Vector2((b.size.x - need.x) * 0.5, 0)
		row.size = Vector2(need.x, b.size.y)
	b.resized.connect(fit)
	row.minimum_size_changed.connect(fit)
	fit.call()
	return b


## A pick chip of what to go for (.chip--t): 64 × 38 at least, corners of 8,
## the word over a 3 px bar; `fill` (0–1) is how much of it the place is
## likely to still have, −1 when that is not known (no bar then).
static func target_chip(word: String, on: bool, fill: float) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = word
	b.custom_minimum_size = Vector2(UiFonts.px(64.0), UiFonts.px(38.0 + TOUCH_T * 2.0))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_skin(b, on, 8.0, 10.0, 38.0, 38.0 + TOUCH_T * 2.0)
	UiFonts.style(b, UiFonts.WORD, 500, 14.0, PAPER if on else INK, 0.56)
	if fill < 0.0:
		return b
	# The word sits 3 px above the middle to leave room for its bar.
	for state in ["normal", "hover", "focus", "disabled", "pressed", "hover_pressed"]:
		var sb := b.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		sb.content_margin_bottom = UiFonts.px(6.0)
		b.add_theme_stylebox_override(state, sb)
	b.draw.connect(func() -> void:
		var x0: float = UiFonts.px(10.0)
		var w: float = b.size.x - UiFonts.px(20.0)
		var y: float = UiFonts.px(TOUCH_T + 28.0)
		var h: float = UiFonts.px(3.0)
		_bar(b, Rect2(x0, y, w, h), TRACK_ON if on else TRACK)
		if fill > 0.0:
			_bar(b, Rect2(x0, y, w * clampf(fill, 0.0, 1.0), h), AMBER if on else INK))
	return b


static func _bar(c: CanvasItem, r: Rect2, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(ceil(r.size.y * 0.5)))
	sb.anti_aliasing_size = 0.6
	c.draw_style_box(sb, r)


## A key with no ring (.ghost): 44 high, the word at 14/500 with wide spacing
## over a faint line, an icon before it if given; pressed, a faint shade.
static func ghost(word: String, icon: String = "") -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = word
	b.custom_minimum_size = Vector2(0, UiFonts.px(44.0))
	UiFonts.style(b, UiFonts.WORD, 500, 14.0, INK, 0.84)
	var rest := StyleBoxEmpty.new()
	rest.content_margin_left = UiFonts.px(10.0)
	rest.content_margin_right = UiFonts.px(10.0)
	var down := StyleBoxFlat.new()
	down.bg_color = PRESS
	down.content_margin_left = rest.content_margin_left
	down.content_margin_right = rest.content_margin_right
	for state in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, rest)
	for state in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, down)
	if icon != "":
		var px: int = int(round(UiFonts.px(16.0)))
		b.icon = HudIcons.texture(icon, px, Color.WHITE)
		b.add_theme_constant_override("icon_max_width", px)
		b.add_theme_constant_override("h_separation", int(round(UiFonts.px(5.0))))
		for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color", "icon_disabled_color"]:
			b.add_theme_color_override(k, INK)
	b.draw.connect(func() -> void:
		var x0: float = UiFonts.px(10.0)
		b.draw_rect(Rect2(x0, b.size.y - UiFonts.px(11.0), b.size.x - x0 * 2.0, UiFonts.px(2.0)), LINE))
	return b


## The stamp at a line's end (.pm): a 2 px ring of faint ink round a few
## words; `off` (it does not hold) is in the seal's brown and bolder.
static func stamp(text: String, off: bool = false) -> Label:
	var l := ink(text, UiFonts.WORD, 600 if off else 400, 12.0, SEAL if off else INK)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(int(round(UiFonts.px(2.0))))
	sb.border_color = SEAL if off else STAMP
	sb.set_corner_radius_all(int(round(UiFonts.px(10.0))))
	sb.corner_detail = 10
	sb.content_margin_left = UiFonts.px(8.0)
	sb.content_margin_right = UiFonts.px(8.0)
	l.add_theme_stylebox_override("normal", sb)
	l.custom_minimum_size = Vector2(0, UiFonts.px(20.0))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


## A name with the faint line under it (.nm: border-bottom 2px).
static func name_word(text: String, css_px: float = 12.0, color: Color = INK2) -> Label:
	var l := ink(text, UiFonts.WORD, 400, css_px, color)
	l.draw.connect(func() -> void:
		l.draw_rect(Rect2(0, l.size.y - UiFonts.px(2.0), l.size.x, UiFonts.px(2.0)), LINE))
	return l


## A line icon on paper, `css_px` across.
static func mark(id: String, css_px: float, color: Color = INK2, weight: float = 2.0) -> TextureRect:
	var px: int = int(round(UiFonts.px(css_px)))
	var t := TextureRect.new()
	t.texture = HudIcons.texture(id, px, color, weight, HudIcons.CUT_PAPER)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
