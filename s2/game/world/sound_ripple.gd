extends Node3D
## 소리 물결(결정 471 H1, 442): 뛰기·문 차기·창 깨기 같은 우리 쪽 큰 소리가 닿는 넓이를 바닥에 옅은
## 동그라미로 잠깐 보인다. 누가 듣는지는 그대로다 — make_sound가 잰 반경을 그릴 뿐이다. 색은 차갑고
## 옅게 두어 어두운 바탕에서 튀지 않는다. 밝으면 어둡게.

const FieldGrid = preload("res://game/world/field_grid.gd")

const SECONDS: float = 1.0
const GROW: float = 0.6            # the ring reaches its radius in this part of the second
const WIDTH: float = 0.12          # metres
const MOST_RADIUS: float = 40.0    # a sound heard over the whole map still draws a ring this wide
const ALPHA: float = 0.15
const COLOR := Color(0.74, 0.77, 0.80)
const FADE_IN: float = 0.06
const FADE_OUT_START: float = 0.45
const FADE_OUT_END: float = 0.85
const SNOW_FROM: float = 0.3
const SNOW_TO: float = 0.8
const BRIGHT_ALPHA_MULT: float = 1.8

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
global uniform float fx_snow;   // 0 bare .. 1 deep snow lying on up-facing faces
global uniform vec4 fx_tint : source_color; // weather and hour colour for sky and haze
uniform vec4 tint : source_color = vec4(0.74, 0.77, 0.80, 1.0);
uniform float alpha = 0.15;
uniform float width = 0.02;
uniform float ground_snow : hint_range(0.0, 1.0) = 1.0; // outdoor weight; fx_snow supplies cover
// Linear maxima: FxState clear night (0.80 * 0.36), default day (0.75 * 0.77).
// Atmosphere's night lies below this range and its clear day above it.
const float FX_TINT_NIGHT = 0.06743727;
const float FX_TINT_DAY = 0.29291349;
const float NIGHT_BRIGHTNESS = 0.6;
const float SNOW_FROM = 0.3;
const float SNOW_TO = 0.8;
const float BRIGHT_ALPHA_MULT = 1.8;
const vec3 DARK_TINT = vec3(0.20, 0.21, 0.23);
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float x = (d - (1.0 - width)) / width;
	float band = smoothstep(0.0, 0.5, x) * (1.0 - smoothstep(0.5, 1.0, x));
	float light = max(fx_tint.r, max(fx_tint.g, fx_tint.b));
	float day = smoothstep(FX_TINT_NIGHT, FX_TINT_DAY, light);
	float brightness = mix(NIGHT_BRIGHTNESS, 1.0, day);
	float bright = smoothstep(SNOW_FROM, SNOW_TO, ground_snow * fx_snow) * day;
	ALBEDO = mix(tint.rgb * brightness, DARK_TINT, bright);
	ALPHA = alpha * band * mix(1.0, BRIGHT_ALPHA_MULT, bright);
}
"""

var peak_alpha: float = ALPHA
var rings: Array = []   # {node, mat, t, r}
var _shader: Shader


## A ring on the ground at at, out to radius (capped at MOST_RADIUS).
func show_ring(at: Vector3, radius: float) -> void:
	var r := minf(radius, MOST_RADIUS)
	if r <= 0.5:
		return
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(2, 2)
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("tint", COLOR)
	var ground_snow: float = 1.0
	var field: Node = get_parent()
	if field != null and field.has_method("grid_at"):
		var grid: FieldGrid = field.call("grid_at", at) as FieldGrid
		ground_snow = 0.0 if grid.indoor(FieldGrid.cell_of(at)) else 1.0
	mat.set_shader_parameter("ground_snow", ground_snow)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at + Vector3(0, 0.04, 0)
	add_child(node)
	var ring := {"node": node, "mat": mat, "t": 0.0, "r": r}
	rings.append(ring)
	_shape(ring)


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	for ring: Dictionary in rings.duplicate():
		ring["t"] = float(ring["t"]) + delta
		if float(ring["t"]) >= SECONDS:
			(ring["node"] as Node).queue_free()
			rings.erase(ring)
			continue
		_shape(ring)


static func envelope(t: float) -> float:
	return smoothstep(0.0, FADE_IN, t) * (1.0 - smoothstep(FADE_OUT_START, FADE_OUT_END, t))


static func ground_look(ground_snow: float, day: float) -> Vector2:
	var bright: float = smoothstep(SNOW_FROM, SNOW_TO, ground_snow) * day
	return Vector2(bright, lerpf(1.0, BRIGHT_ALPHA_MULT, bright))


## Grows out to its radius over GROW, fades out by FADE_OUT_END; the band stays WIDTH wide.
func _shape(ring: Dictionary) -> void:
	var t: float = ring["t"]
	var s: float = float(ring["r"]) * lerpf(0.3, 1.0, minf(1.0, t / GROW))
	(ring["node"] as Node3D).scale = Vector3(s, 1.0, s)
	var mat: ShaderMaterial = ring["mat"]
	mat.set_shader_parameter("width", WIDTH / s)
	mat.set_shader_parameter("alpha", peak_alpha * envelope(t))
