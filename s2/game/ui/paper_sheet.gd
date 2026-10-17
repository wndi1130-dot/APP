extends Control
## A sheet of paper come in from the left (UI 3단계 시안 2차 c2.css .sheetw ·
## .sheet · .sheet__in, B1): a drop shadow on what is under it, the paper
## (paper_sheet.gdshader: fibres, the fold, grime at the edges, the right edge
## torn), and `inner`, the room for what is written on it. It leans a little
## from its bottom left corner as a sheet laid down by hand does. Sizes are the
## mockup's px (ui_fonts.gd K turns them into the game's).

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const SHADER := preload("res://game/ui/paper_sheet.gdshader")
const PAPER_TEX := preload("res://game/ui/tex/paper.png")
const TEAR_TEX := preload("res://game/ui/tex/tear.png")

## The mockup's sheet: 446 × 346, the writing 32 in from the left, 28 from the
## right, 12 from the top and 16 from the bottom; leaning −0.45°.
const SIZE := Vector2(446, 346)
const INSET_L: float = 32.0
const INSET_R: float = 28.0
const INSET_T: float = 12.0
const INSET_B: float = 16.0
const LEAN_DEG: float = -0.45
## drop-shadow(8px 6px 14px rgba(0,0,0,.62)): the blur radius is twice the spread.
const SHADOW_AT := Vector2(8, 6)
const SHADOW_BLUR: float = 14.0
const SHADOW_ALPHA: float = 0.62

var inner: Control
var _paper: ColorRect
var _shadow: ColorRect


func _init(css_size: Vector2 = SIZE) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = css_size * UiFonts.K
	custom_minimum_size = size
	pivot_offset = Vector2(0, size.y)
	rotation = deg_to_rad(LEAN_DEG)
	var sigma: float = UiFonts.px(SHADOW_BLUR) * 0.5
	var reach: float = ceil(sigma * 3.0)
	_shadow = _sheet_rect(true)
	_shadow.material.set_shader_parameter("reach", reach)
	_shadow.material.set_shader_parameter("sigma", sigma)
	_shadow.material.set_shader_parameter("shadow_alpha", SHADOW_ALPHA)
	_shadow.position = SHADOW_AT * UiFonts.K - Vector2(reach, reach)
	_shadow.size = size + Vector2(reach, reach) * 2.0
	add_child(_shadow)
	_paper = _sheet_rect(false)
	_paper.size = size
	_paper.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_paper)
	inner = Control.new()
	inner.name = "In"
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.position = Vector2(UiFonts.px(INSET_L), UiFonts.px(INSET_T))
	inner.size = size - Vector2(UiFonts.px(INSET_L + INSET_R), UiFonts.px(INSET_T + INSET_B))
	add_child(inner)


func _sheet_rect(is_shadow: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.WHITE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("paper_tex", PAPER_TEX)
	m.set_shader_parameter("tear_tex", TEAR_TEX)
	m.set_shader_parameter("sheet_size", size)
	m.set_shader_parameter("tile", UiFonts.px(240.0))
	m.set_shader_parameter("cut", UiFonts.px(13.0))
	m.set_shader_parameter("tear", Vector2(UiFonts.px(14.0), UiFonts.px(240.0)))
	m.set_shader_parameter("shadow", is_shadow)
	r.material = m
	return r
