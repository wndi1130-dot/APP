extends RefCounted
## One plain theme for the graybox: dark flat panels, readable Korean text,
## buttons big enough for a thumb. The worn two-material UI is not S2's job.

const INK := Color(0.93, 0.91, 0.86)
const PRESS_SINK: float = 2.0


static func make(font_size: int = 22) -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Pretendard", "Noto Sans CJK KR", "Noto Sans KR", "Droid Sans Fallback", "sans-serif"])
	theme.default_font = font
	theme.default_font_size = font_size
	theme.set_stylebox("normal", "Button", _box(Color(0.2, 0.2, 0.21, 0.92), Color(1, 1, 1, 0.1)))
	theme.set_stylebox("hover", "Button", _box(Color(0.25, 0.25, 0.26, 0.95), Color(1, 1, 1, 0.18)))
	# Pressed sinks the content PRESS_SINK px: top +2, bottom -2, so the size stays (ui_states P1).
	theme.set_stylebox("pressed", "Button", _box(Color(0.32, 0.3, 0.26, 0.98), Color(0.95, 0.85, 0.6, 0.5), PRESS_SINK))
	theme.set_stylebox("hover_pressed", "Button", _box(Color(0.32, 0.3, 0.26, 0.98), Color(0.95, 0.85, 0.6, 0.5), PRESS_SINK))
	theme.set_stylebox("disabled", "Button", _box(Color(0.15, 0.15, 0.15, 0.7), Color(1, 1, 1, 0.05)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", Color(1, 0.95, 0.82))
	theme.set_color("font_color", "Label", INK)
	return theme


static func _box(bg: Color, border: Color, sink: float = 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6 + sink
	sb.content_margin_bottom = 6 - sink
	return sb
