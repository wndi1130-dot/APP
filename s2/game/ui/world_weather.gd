extends Control
## The weather the mockup lays over its world, over the train and under the
## frost (UI 3단계 시안 2차, k3_views.js world: .w-drift, .w-fogB, .w-snow2,
## .w-snow3). While the train runs, the snow streaks past on a slant and the
## drift blows along the ground; at a stop it falls slowly and the drift
## settles (.world.is-stop). The textures are the mockup's own canvases
## (k0_core.js); tiles, speeds and opacities are its CSS (mockup px × K).

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const LAYER := preload("res://game/ui/world_layer.gdshader")
const DRIFT := preload("res://game/ui/tex/drift.png")
const FOG := preload("res://game/ui/tex/fog.png")
const SNOW_RUN_FAR := preload("res://game/ui/tex/snow_run_far.png")
const SNOW_RUN_NEAR := preload("res://game/ui/tex/snow_run_near.png")
const SNOW_STOP_FAR := preload("res://game/ui/tex/snow_stop_far.png")
const SNOW_STOP_NEAR := preload("res://game/ui/tex/snow_stop_near.png")
## The snow's two sheets slide this far a second (mockup px): running, the far
## one by (−400, 200) in 4.4 s (snowA) and the near one by (−800, 400) in 2.4 s
## (snowB); stopped, by (−400, 1600) in 27 s and 15 s (fallA).
const FAR_RUN := Vector2(-400.0 / 4.4, 200.0 / 4.4)
const NEAR_RUN := Vector2(-800.0 / 2.4, 400.0 / 2.4)
const FAR_STOP := Vector2(-400.0 / 27.0, 1600.0 / 27.0)
const NEAR_STOP := Vector2(-400.0 / 15.0, 1600.0 / 15.0)

## Running (the snow on a slant, the drift blowing) or at a stop.
var moving: bool = true: set = set_moving
## Held at the start (screens taken for checks).
var still: bool = false: set = set_still

var drift: ColorRect
var fog: ColorRect
var far: ColorRect
var near: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# .w-drift (238, 90 high): the 844 strip blowing by in 3 s.
	drift = _layer("Drift", DRIFT, 238.0, 90.0, Vector2(844, 90), Vector2.ZERO, Vector2(-844.0 / 3.0, 0.0), 1.0)
	# .w-fogB (214, 150 high): the fog's 1266 tile from −300, by in 28 s, at .42.
	fog = _layer("Fog", FOG, 214.0, 150.0, Vector2(1266, 150), Vector2(-300, 0), Vector2(-1266.0 / 28.0, 0.0), 0.42)
	far = _layer("SnowFar", SNOW_RUN_FAR, 0.0, -1.0, Vector2(400, 400), Vector2.ZERO, FAR_RUN, 0.8)
	near = _layer("SnowNear", SNOW_RUN_NEAR, 0.0, -1.0, Vector2(400, 400), Vector2.ZERO, NEAR_RUN, 0.6)
	_apply()


func set_moving(v: bool) -> void:
	moving = v
	_apply()


func set_still(v: bool) -> void:
	still = v
	for c in [drift, fog, far, near]:
		if c != null:
			((c as ColorRect).material as ShaderMaterial).set_shader_parameter("still", 1.0 if v else 0.0)


func _apply() -> void:
	if far == null:
		return
	drift.visible = moving
	_snow(far, SNOW_RUN_FAR if moving else SNOW_STOP_FAR, FAR_RUN if moving else FAR_STOP)
	_snow(near, SNOW_RUN_NEAR if moving else SNOW_STOP_NEAR, NEAR_RUN if moving else NEAR_STOP)


func _snow(c: ColorRect, tex: Texture2D, speed: Vector2) -> void:
	var m := c.material as ShaderMaterial
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("speed_px", speed * UiFonts.K)


## A sheet across the screen, `h_css` high at `top_css` (−1: all of it), its
## texture tiled `tile` from `start`, sliding `speed` a second (mockup px).
func _layer(id: String, tex: Texture2D, top_css: float, h_css: float, tile: Vector2, start: Vector2, speed: Vector2, opacity: float) -> ColorRect:
	var k: float = UiFonts.K
	var c := ColorRect.new()
	c.name = id
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if h_css < 0.0:
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		c.anchor_right = 1.0
		c.offset_top = top_css * k
		c.offset_bottom = (top_css + h_css) * k
	var m := ShaderMaterial.new()
	m.shader = LAYER
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("tile_px", tile * k)
	m.set_shader_parameter("start_px", start * k)
	m.set_shader_parameter("speed_px", speed * k)
	m.set_shader_parameter("opacity", opacity)
	m.set_shader_parameter("still", 1.0 if still else 0.0)
	c.material = m
	c.resized.connect(func() -> void: m.set_shader_parameter("rect_px", c.size))
	add_child(c)
	m.set_shader_parameter("rect_px", c.size)
	return c
