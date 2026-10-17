extends Container
## A line of type as the mockup's CSS sets it (UI 3단계 시안 2차): words of
## different faces and sizes side by side on one baseline (a 14 px number among
## 12 px words sits on their line, not on their middle), in a line box of the
## CSS line-height. A face taller than its line box spills over it evenly, as a
## browser's half-leading does, instead of pushing the line taller: the pen
## hand's tall ascent no longer moves every row under it.
##
## `line_css` is the CSS line-height in mockup px (0: the type's own height,
## centred in whatever height the line is given); `box_css` is the height the
## line takes in its row (0: the line's), its line box at its top as a block's
## first line is. A child with SIZE_EXPAND takes the width left over; anything
## that is not a Label stands with its foot on the baseline.

const UiFonts = preload("res://game/ui/ui_fonts.gd")

var line_css: float = 0.0
var box_css: float = 0.0
var gap_css: float = 0.0
## Where the parts sit when the line is wider than they are.
var alignment: int = BoxContainer.ALIGNMENT_BEGIN


func _init(line: float = 0.0, box: float = 0.0, gap: float = 0.0) -> void:
	line_css = line
	box_css = box
	gap_css = gap
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## How far `c`'s baseline is below its top, and how far its foot is below that,
## at its least size.
static func rise_of(c: Control) -> Vector2:
	var m: Vector2 = c.get_combined_minimum_size()
	if c is Label:
		var l := c as Label
		var f: Font = l.get_theme_font("font")
		var s: int = l.get_theme_font_size("font_size")
		var tl := TextLine.new()
		tl.add_string(l.text if l.text != "" else " ", f, s)
		var up: float = tl.get_line_ascent()
		var down: float = tl.get_line_descent()
		var top: float = 0.0
		var bottom: float = 0.0
		var sb: StyleBox = l.get_theme_stylebox("normal")
		if sb != null:
			top = sb.get_margin(SIDE_TOP)
			bottom = sb.get_margin(SIDE_BOTTOM)
		var room: float = maxf(0.0, m.y - top - bottom - up - down)
		var off: float = 0.0
		if l.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
			off = room * 0.5
		elif l.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
			off = room
		var base: float = top + off + up
		return Vector2(base, m.y - base)
	if c.has_method("own_baseline"):
		var b: float = c.own_baseline()
		return Vector2(b, m.y - b)
	return Vector2(m.y, 0.0)


## Where this line's own baseline is below its top at its least size.
func own_baseline() -> float:
	var r: Vector2 = _rise()
	return _base_y(r, get_combined_minimum_size().y)


func _parts() -> Array:
	var out: Array = []
	for c in get_children():
		if c is Control and (c as Control).visible and not (c as Control).top_level:
			out.append(c)
	return out


func _rise() -> Vector2:
	var up: float = 0.0
	var down: float = 0.0
	for c: Control in _parts():
		var r: Vector2 = rise_of(c)
		up = maxf(up, r.x)
		down = maxf(down, r.y)
	return Vector2(up, down)


func _base_y(r: Vector2, h: float) -> float:
	var line: float = UiFonts.px(line_css) if line_css > 0.0 else h
	return (line - (r.x + r.y)) * 0.5 + r.x


func _get_minimum_size() -> Vector2:
	var w: float = 0.0
	var parts: Array = _parts()
	for c: Control in parts:
		w += c.get_combined_minimum_size().x
	if parts.size() > 1:
		w += UiFonts.px(gap_css) * (parts.size() - 1)
	var h: float
	if box_css > 0.0:
		h = UiFonts.px(box_css)
	elif line_css > 0.0:
		h = UiFonts.px(line_css)
	else:
		var r: Vector2 = _rise()
		h = r.x + r.y
	return Vector2(w, h)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_lay()
	elif what == NOTIFICATION_THEME_CHANGED:
		update_minimum_size()


func _lay() -> void:
	var parts: Array = _parts()
	if parts.is_empty():
		return
	var r: Vector2 = _rise()
	var base: float = _base_y(r, size.y)
	var gap: float = UiFonts.px(gap_css)
	var need: float = gap * (parts.size() - 1)
	for c: Control in parts:
		need += c.get_combined_minimum_size().x
	var spare: float = maxf(0.0, size.x - need)
	var growers: Array = parts.filter(func(c: Control) -> bool: return c.size_flags_horizontal & Control.SIZE_EXPAND)
	var x: float = 0.0
	if growers.is_empty():
		if alignment == BoxContainer.ALIGNMENT_CENTER:
			x = spare * 0.5
		elif alignment == BoxContainer.ALIGNMENT_END:
			x = spare
	for c: Control in parts:
		var m: Vector2 = c.get_combined_minimum_size()
		var w: float = m.x
		if not growers.is_empty() and growers.has(c):
			w += spare / growers.size()
		var rc: Vector2 = rise_of(c)
		fit_child_in_rect(c, Rect2(x, base - rc.x, w, m.y))
		x += w + gap
