extends Control
## The film over the world, over the frost and under the keys (UI 3단계 시안
## 2차, k3_views.js world: .w-vig, .w-grain): the edges darken in an ellipse
## 74 % × 86 % about a point a little above the middle, and the mockup's 160 px
## grain (k0_core.js --tx-grain) lies over it all as a browser's overlay blend
## lays it, at .55.

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const GRAIN := preload("res://game/ui/tex/grain.png")
const GRAIN_SHADER := preload("res://game/ui/world_grain.gdshader")
## radial-gradient(74% 86% at 50% 45%, transparent 46%, .34 78%, .66 100%).
const VIG_R := Vector2(0.74, 0.86)
const VIG_AT := Vector2(0.5, 0.45)
const VIG_STOPS: Array = [[0.0, 0.0], [0.46, 0.0], [0.78, 0.34], [1.0, 0.66]]

var vignette: TextureRect
var grain: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette = TextureRect.new()
	vignette.name = "Vignette"
	vignette.texture = vignette_texture()
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The texture's circle (radius .74 of its width) drawn into a rect as wide
	# as the screen and .86 / .74 of it high, centred at 45 %, is the ellipse.
	var h: float = VIG_R.y / VIG_R.x
	vignette.anchor_left = 0.0
	vignette.anchor_right = 1.0
	vignette.anchor_top = VIG_AT.y - h * 0.5
	vignette.anchor_bottom = VIG_AT.y + h * 0.5
	add_child(vignette)
	grain = ColorRect.new()
	grain.name = "Grain"
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = GRAIN_SHADER
	m.set_shader_parameter("grain", GRAIN)
	m.set_shader_parameter("tile_px", 160.0 * UiFonts.K)
	m.set_shader_parameter("opacity", 0.55)
	grain.material = m
	grain.resized.connect(func() -> void: m.set_shader_parameter("rect_px", grain.size))
	add_child(grain)
	m.set_shader_parameter("rect_px", grain.size)


## The vignette's gradient: black, clear to 46 % of the way out, .34 at 78 %,
## .66 at the ellipse.
static func vignette_texture() -> GradientTexture2D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for s: Array in VIG_STOPS:
		offs.append(float(s[0]))
		cols.append(Color(0, 0, 0, float(s[1])))
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5 + VIG_R.x, 0.5)
	t.width = 256
	t.height = 256
	return t
