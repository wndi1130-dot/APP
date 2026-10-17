extends Button
## The main key of a screen (UI 3단계 시안 2차 .main, B1): lamp enamel in a dark
## brass rim, its word in dark lamp ink with wide spacing and an arrow right
## after it, the two centred together (8 px right of centre: padding-left 8).
## 148 × 48 in the mockup wherever it is (코디네이터 10-12). Pressed it sinks
## 2 px and brightens; off it goes grey and dim. The face is drawn by
## lamp_key.gdshader behind the word.

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const SHADER := preload("res://game/ui/lamp_key.gdshader")

const CSS_SIZE := Vector2(148, 48)
const INK := Color("2a1804")
## How far the glow and shadow reach past the key.
const REACH_CSS: float = 20.0
const ARROW_CSS: float = 20.0
const GAP_CSS: float = 6.0

var face: ColorRect
var arrow: bool = true
var _sink: float = 0.0
var _arrow_tex: Texture2D


func _init(word: String = "", with_arrow: bool = true, css_size: Vector2 = CSS_SIZE) -> void:
	text = word
	arrow = with_arrow
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = css_size * UiFonts.K
	UiFonts.style(self, UiFonts.WORD, 600, 16.0, INK, 2.56)
	add_theme_color_override("font_disabled_color", INK)
	_sink = UiFonts.px(2.0)
	# The word is centred in what is left of the key once the arrow and its gap
	# are kept at the right, so word and arrow sit together in the middle.
	var right: float = UiFonts.px(ARROW_CSS + GAP_CSS) if arrow else 0.0
	for state in ["normal", "hover", "focus", "disabled"]:
		add_theme_stylebox_override(state, _pad(0.0, right))
	for state in ["pressed", "hover_pressed"]:
		add_theme_stylebox_override(state, _pad(_sink, right))
	if arrow:
		_arrow_tex = HudIcons.texture("fwd", int(round(UiFonts.px(ARROW_CSS))), INK, 2.4)
		draw.connect(_draw_arrow)
	face = ColorRect.new()
	face.name = "Face"
	face.show_behind_parent = true
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("k", UiFonts.K)
	m.set_shader_parameter("rim", UiFonts.px(2.0))
	face.material = m
	add_child(face)
	resized.connect(_place)
	button_down.connect(_press.bind(true))
	button_up.connect(_press.bind(false))
	_place()


func _pad(sink: float, right: float) -> StyleBoxEmpty:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = UiFonts.px(8.0)
	sb.content_margin_right = right
	sb.content_margin_top = sink
	sb.content_margin_bottom = -sink
	return sb


func _draw_arrow() -> void:
	if _arrow_tex == null or text == "":
		return
	var f: Font = get_theme_font("font")
	var px: int = get_theme_font_size("font_size")
	var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var left: float = UiFonts.px(8.0)
	var room: float = size.x - left - UiFonts.px(ARROW_CSS + GAP_CSS)
	var x: float = left + (room + w) * 0.5 + UiFonts.px(GAP_CSS)
	var down: float = _sink if (is_pressed() or get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED) else 0.0
	var a: Vector2 = _arrow_tex.get_size() * 0.5
	draw_texture_rect(_arrow_tex, Rect2(Vector2(x, (size.y - a.y) * 0.5 + down), a), false)


func _place() -> void:
	var reach: float = UiFonts.px(REACH_CSS)
	face.position = -Vector2(reach, reach)
	face.size = size + Vector2(reach, reach) * 2.0
	var m := face.material as ShaderMaterial
	m.set_shader_parameter("key_size", size)
	m.set_shader_parameter("reach", reach)


func _press(down: bool) -> void:
	var m := face.material as ShaderMaterial
	m.set_shader_parameter("sink", _sink if down else 0.0)
	m.set_shader_parameter("bright", 1.14 if down else 1.0)
	queue_redraw()


## Off: grey and dim, and it does not press.
func set_off(v: bool) -> void:
	disabled = v
	(face.material as ShaderMaterial).set_shader_parameter("off", v)
