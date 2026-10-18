extends PanelContainer
## A pane of smoked glass come in from the left edge (UI 3단계 시안 2차 c11.css
## .pane--menu, B1 「성에 낀 계기」): a dark backing that thins out over its last
## fifth, and over it the car pane's frosted canvas mirrored, so its frost melts
## at the right as the menu's does (tex/pane_glass.png); a head (a mark and the
## name at 18/500 with wide spacing, a side line, 접기 at the top right) over
## `body`, where the rows go. The mockup draws the train's menu so, and the
## field's panels (field_hud.gd: settings, bag, search, orders, the crew, care)
## are its kin, built of its parts: the cells (.mn__b), the named cells
## (.mn__b--2), the picks with the four amber corners (.mn__pick) and the row
## words (.mn__k). The pane is as high as its rows. Sizes are the mockup's px
## (ui_fonts.gd K).

signal folded

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const GlassParts = preload("res://game/ui/glass_parts.gd")
const TypeLine = preload("res://game/ui/type_line.gd")
const GLASS := preload("res://game/ui/tex/pane_glass.png")

## 디자인 토큰 2차 (B1).
const INK := Color("eee9dc")
const INK2 := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.7)
const INK3 := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.54)
const HAIR := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.16)
const AMBER := Color("f2a63c")
const AMBER_L := Color("ffc66c")
const RED_L := Color("f29078")
const SOOT_CUT := Color("10151a")
## Under the glass (.pane--menu::before): dark to four fifths, gone at the edge.
const BACKING: Array = [
	[0.0, Color(7 / 255.0, 10 / 255.0, 13 / 255.0, 0.9)],
	[0.8, Color(7 / 255.0, 10 / 255.0, 13 / 255.0, 0.88)],
	[1.0, Color(7 / 255.0, 10 / 255.0, 13 / 255.0, 0.0)],
]
## Over the rest of the screen while a pane is up (.mscrim).
const SCRIM := Color(2 / 255.0, 4 / 255.0, 6 / 255.0, 0.62)
## A cell's ground (.mn__b, .mn__pick): rgba(0,0,0,.2) inside a 2 px hairline.
const CELL := Color(0, 0, 0, 0.2)
## Under the band, as the menu (top 48).
const TOP: float = 48.0
## .mn: padding 12 40 0 16. The menu is 286 high and its rows end short of its
## foot; a pane as high as its rows keeps 14 under them.
const PAD_L: float = 16.0
const PAD_R: float = 40.0
const PAD_T: float = 12.0
const PAD_B: float = 14.0
## .pane__head: 40 high and 6 over the rows; cells 6 apart in a row, rows 8.
const HEAD_H: float = 40.0
const HEAD_GAP: float = 6.0
const GAP: float = 6.0
const SET_GAP: float = 8.0
## .mn__b: 44 high, corners of 6. An unpicked pick shows at .62.
const CELL_H: float = 44.0
const RADIUS: float = 6.0
const OFF: float = 0.62
## .mn__pick.on::before: a bar 12 long and 2 thick each way at each corner.
const ARM: float = 12.0
## How the pane comes in (c4.css spIn: .15 s from 12 px to the left).
const IN_S: float = 0.15
const IN_FROM: float = 12.0

var body: VBoxContainer
var title_label: Label


func _init(width_css: float = 420.0, title: String = "", side: String = "", icon: String = "") -> void:
	name = "Pane"
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	custom_minimum_size = Vector2(UiFonts.px(width_css), 0)
	var back := Control.new()
	back.name = "Back"
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.draw.connect(func() -> void: GlassParts.grad_rect(back, Rect2(Vector2.ZERO, back.size), 0.0, BACKING))
	back.resized.connect(back.queue_redraw)
	add_child(back)
	var glass := TextureRect.new()
	glass.name = "Glass"
	glass.texture = GLASS
	glass.flip_h = true
	glass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glass.stretch_mode = TextureRect.STRETCH_SCALE
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glass)
	var margin := MarginContainer.new()
	margin.name = "Rows"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", px(PAD_L))
	margin.add_theme_constant_override("margin_right", px(PAD_R))
	margin.add_theme_constant_override("margin_top", px(PAD_T))
	margin.add_theme_constant_override("margin_bottom", px(PAD_B))
	add_child(margin)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", px(HEAD_GAP))
	margin.add_child(col)
	col.add_child(_head(title, side, icon))
	body = VBoxContainer.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", px(SET_GAP))
	col.add_child(body)
	minimum_size_changed.connect(_fit)


## At the left edge under the band. `slide`: it comes in as the short panel
## does; a pane laid again over itself (a setting changed) does not.
func pin(slide: bool) -> void:
	_fit()
	position = Vector2(0.0, UiFonts.px(TOP))
	if not slide or not is_inside_tree():
		return
	modulate.a = 0.0
	position.x = -UiFonts.px(IN_FROM)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, IN_S)
	tw.tween_property(self, "position:x", 0.0, IN_S)


func _fit() -> void:
	size = get_combined_minimum_size()


## The head (.pane__head, items centred): the mark and the name (h3: 18/500,
## .12em), the side line 12 to their right (.mn__sub), 접기 at the right.
func _head(title: String, side: String, icon: String) -> Control:
	var h := HBoxContainer.new()
	h.name = "Head"
	h.custom_minimum_size = Vector2(0, UiFonts.px(HEAD_H))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", px(8.0))
	if icon != "":
		h.add_child(mark(icon, 20.0, INK2))
	title_label = UiFonts.label(title, UiFonts.WORD, 500, 18.0, INK, 2.16)
	title_label.name = "Title"
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(title_label)
	if side != "":
		var air := Control.new()
		air.custom_minimum_size = Vector2(UiFonts.px(4.0), 0)
		air.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(air)
		var s := mixed(side)
		s.name = "Side"
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(s)
	var room := Control.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(room)
	h.add_child(_fold())
	return h


## 접기 (.word): the back arrow before the word at 13 with wide spacing, in
## side ink, a touch of 56 × 44.
func _fold() -> Button:
	var b := Button.new()
	b.name = "Fold"
	b.text = "접기"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(UiFonts.px(56.0), UiFonts.px(44.0))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiFonts.style(b, UiFonts.WORD, 400, 13.0, INK2, 1.3)
	var icon_px: int = px(14.0)
	b.icon = HudIcons.texture("back", icon_px, Color.WHITE, 2.0, SOOT_CUT)
	b.add_theme_constant_override("icon_max_width", icon_px)
	b.add_theme_constant_override("h_separation", px(3.0))
	for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(k, INK2)
	var rest := StyleBoxEmpty.new()
	rest.content_margin_left = UiFonts.px(6.0)
	rest.content_margin_right = UiFonts.px(6.0)
	var down := rest.duplicate() as StyleBoxEmpty
	down.content_margin_top = UiFonts.px(1.0)
	down.content_margin_bottom = -UiFonts.px(1.0)
	for state in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, rest)
	for state in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, down)
	b.pressed.connect(func() -> void: folded.emit())
	return b


# ---------------------------------------------------------------- the parts


## Mockup px → whole game px (gaps and widths a container rounds anyway).
static func px(css: float) -> int:
	return int(round(UiFonts.px(css)))


## A row of cells 6 apart (.mn__row).
static func row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", px(GAP))
	return h


## A cell's box: `fill` inside a 2 px hairline, corners of 6; `sink` lowers it
## and what is on it by that many game px (:active translateY(1px)).
static func _box(fill: Color, line: Color, sink: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(px(RADIUS))
	sb.corner_detail = 8
	sb.anti_aliasing_size = 0.7
	sb.set_border_width_all(px(2.0))
	sb.border_color = line
	sb.content_margin_left = UiFonts.px(8.0)
	sb.content_margin_right = UiFonts.px(8.0)
	sb.content_margin_top = sink
	sb.content_margin_bottom = -sink
	sb.expand_margin_top = -sink
	sb.expand_margin_bottom = sink
	return sb


static func _skin(b: Button, fill: Color = CELL) -> void:
	for state in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(state, _box(fill, HAIR, 0.0))
	for state in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, _box(fill, HAIR, UiFonts.px(1.0)))
	b.add_theme_stylebox_override("disabled", _box(Color(fill, fill.a * 0.5), Color(HAIR, HAIR.a * 0.5), 0.0))


## What is laid on a key sinks with it while it is held.
static func sinks(b: Button, c: Control) -> void:
	b.button_down.connect(func() -> void: c.position.y += UiFonts.px(1.0))
	b.button_up.connect(func() -> void: c.position.y -= UiFonts.px(1.0))


## A cell (.mn__b): 44 high, corners of 6, its word at 13/500 (.03em) in a 2 px
## hairline on a faint dark ground; pressed it sinks 1 px, off it is faint.
## `fill` is its ground where it stands on no pane (the field's glass).
static func key(word: String, cb: Callable, icon: String = "", fill: Color = CELL) -> Button:
	var b := Button.new()
	b.text = word
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, UiFonts.px(CELL_H))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiFonts.style(b, UiFonts.WORD, 500, 13.0, INK, 0.39)
	b.add_theme_color_override("font_disabled_color", Color(INK, 0.38))
	_skin(b, fill)
	if icon != "":
		var icon_px: int = px(16.0)
		b.icon = HudIcons.texture(icon, icon_px, Color.WHITE, 2.0, SOOT_CUT)
		b.add_theme_constant_override("icon_max_width", icon_px)
		b.add_theme_constant_override("h_separation", px(5.0))
		for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
			b.add_theme_color_override(k, INK2)
		b.add_theme_color_override("icon_disabled_color", Color(INK2, 0.38))
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


## A cell naming a setting over its value (.mn__b--2): the name at 12 in the
## third ink over the value at 13/500, a line of 16 each. The key's own text is
## the two together (「스틱: 따라오기」), drawn by the two words only.
static func cell(name_word: String, value: String, cb: Callable) -> Button:
	var b := key(name_word + ": " + value, cb)
	b.clip_text = true
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(k, Color(0, 0, 0, 0))
	var col := VBoxContainer.new()
	col.name = "Words"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var n := UiFonts.label(name_word, UiFonts.WORD, 400, 12.0, INK3, 0.72)
	n.name = "Name"
	var v := UiFonts.label(value, UiFonts.WORD, 500, 13.0, INK, 0.39)
	v.name = "Value"
	for l: Label in [n, v]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(0, UiFonts.px(16.0))
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		col.add_child(l)
	b.add_child(col)
	# As wide as the wider word and the cell's padding (the text it hides is wider).
	b.custom_minimum_size.x = maxf(GlassParts.text_w(n), GlassParts.text_w(v)) + UiFonts.px(16.0)
	sinks(b, col)
	return b


## A pick among a few (.mn__pick): as wide as its row allows, an icon before
## the word if given (else the words centred), the word at 14/600 (.08em) over
## a smaller line in the third ink; unpicked at .62, picked at full with the
## icon in amber and the four lamp-amber corners and their glow.
static func pick(word: String, sub: String, on: bool, cb: Callable, icon: String = "", css_h: float = CELL_H) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.custom_minimum_size = Vector2(0, UiFonts.px(css_h))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skin(b)
	var h := HBoxContainer.new()
	h.name = "Words"
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", px(4.0))
	h.alignment = BoxContainer.ALIGNMENT_BEGIN if icon != "" else BoxContainer.ALIGNMENT_CENTER
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# padding 0 6 0 2 with a picture, 0 4 without (.mn__pick--hw).
	h.offset_left = UiFonts.px(6.0 if icon != "" else 4.0)
	h.offset_right = -UiFonts.px(6.0 if icon != "" else 4.0)
	if icon != "":
		var m := mark(icon, 24.0, AMBER if on else INK2)
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(m)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	h.add_child(col)
	var w := UiFonts.label(word, UiFonts.WORD, 600, 14.0, INK, 1.12)
	w.name = "Word"
	col.add_child(w)
	if sub != "":
		col.add_child(UiFonts.label(sub, UiFonts.WORD, 400, 12.0, INK3, 0.12))
	if icon == "":
		for l in col.get_children():
			(l as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(h)
	b.custom_minimum_size.x = h.get_combined_minimum_size().x + UiFonts.px(12.0)
	b.modulate.a = 1.0 if on else OFF
	if on:
		b.draw.connect(func() -> void: corners(b, Rect2(Vector2.ZERO, b.size)))
	sinks(b, h)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


## The four lamp-amber corners of what is picked (.mn__pick.on::before): a bar
## 12 long and 2 thick each way at each corner, under them their glow
## (drop-shadow 0 0 4px rgba(242,166,60,.7)).
static func corners(ci: CanvasItem, r: Rect2) -> void:
	var arm: float = UiFonts.px(ARM)
	var th: float = UiFonts.px(2.0)
	var at: Array = [[r.position, 1.0, 1.0], [Vector2(r.end.x, r.position.y), -1.0, 1.0],
			[Vector2(r.position.x, r.end.y), 1.0, -1.0], [r.end, -1.0, -1.0]]
	for i in 4:
		var grow: float = UiFonts.px(float(3 - i)) if i < 3 else 0.0
		var col: Color = Color(AMBER, [0.12, 0.2, 0.32][i]) if i < 3 else AMBER_L
		for c: Array in at:
			var o: Vector2 = c[0]
			var sx: float = float(c[1])
			var sy: float = float(c[2])
			ci.draw_rect(Rect2(o, Vector2(arm * sx, th * sy)).abs().grow(grow), col)
			ci.draw_rect(Rect2(o, Vector2(th * sx, arm * sy)).abs().grow(grow), col)


## The word that heads a row (.mn__k): 60 wide, 13/500 (.06em) over a smaller
## line in the third ink, set in the row's middle.
static func row_word(word: String, sub: String = "") -> Control:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.custom_minimum_size = Vector2(UiFonts.px(60.0), 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.add_child(UiFonts.label(word, UiFonts.WORD, 500, 13.0, INK, 0.78))
	if sub != "":
		col.add_child(UiFonts.label(sub, UiFonts.WORD, 400, 12.0, INK3, 0.24))
	return col


## A line of words with its numbers in the number face, on one baseline
## (.mn__sub and its .num): words at `word_css` in `word_ink`, numbers at
## `num_css` in `num_ink`. A number keeps what joins its digits (「2.6」,
## 「10:30」, 「0/2」) in one run.
static func mixed(text: String, word_css: float = 12.0, num_css: float = 13.0, word_ink: Color = INK2, num_ink: Color = INK) -> Control:
	var line = TypeLine.new()
	var re := RegEx.create_from_string("[0-9]+(?:[:./][0-9]+)*")
	var at: int = 0
	for m: RegExMatch in re.search_all(text):
		if m.get_start() > at:
			line.add_child(UiFonts.label(text.substr(at, m.get_start() - at), UiFonts.WORD, 400, word_css, word_ink, word_css * 0.05))
		line.add_child(UiFonts.label(m.get_string(), UiFonts.NUMBER, 500, num_css, num_ink, num_css * 0.015))
		at = m.get_end()
	if at < text.length():
		line.add_child(UiFonts.label(text.substr(at), UiFonts.WORD, 400, word_css, word_ink, word_css * 0.05))
	return line


## A line that wraps between words (keep-all) within `width_css`.
static func note(text: String, width_css: float, color: Color = INK3, css_px: float = 12.0, weight: int = 400) -> Label:
	var l := UiFonts.label(UiFonts.keep_all(text), UiFonts.WORD, weight, css_px, color, css_px * 0.03)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(UiFonts.px(width_css), 0)
	return l


## A line icon on the glass, `css_px` across.
static func mark(id: String, css_px: float, color: Color) -> TextureRect:
	var t := TextureRect.new()
	var icon_px: int = px(css_px)
	t.texture = HudIcons.texture(id, icon_px, color, 2.0, SOOT_CUT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(icon_px, icon_px)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## A hairline across the pane between list rows (1 px of the hairline ink).
static func rule() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(0, UiFonts.px(1.0))
	c.draw.connect(func() -> void: c.draw_rect(Rect2(Vector2.ZERO, c.size), HAIR))
	return c


## `rows` in a scroll as high as they are, up to `max_css`: a long list stays
## inside the screen and is dragged.
static func scroll(rows: Control, max_css: float) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.name = "List"
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	s.mouse_filter = Control.MOUSE_FILTER_PASS
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(rows)
	var fit := func() -> void:
		s.custom_minimum_size.y = minf(rows.get_combined_minimum_size().y, UiFonts.px(max_css))
	rows.minimum_size_changed.connect(fit)
	fit.call()
	return s
