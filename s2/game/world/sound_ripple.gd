extends Node3D
## 소리 물결(결정 471 H1, 442): 뛰기·문 차기·창 깨기 같은 우리 쪽 큰 소리가 닿는 넓이를 바닥에 옅은
## 동그라미로 잠깐 보인다. 누가 듣는지는 그대로다 — make_sound가 잰 반경을 그릴 뿐이다. 색은 차갑고
## 옅게 두어 어두운 바탕에서 튀지 않는다. 밤 0.15, 낮 0.30(밝은 바닥·실내 낮에서도 읽히게), 사이는 하늘빛으로 잇는다.

const SECONDS: float = 1.0
const GROW: float = 0.6            # the ring reaches its radius in this part of the second
const WIDTH: float = 0.09          # metres
const MOST_RADIUS: float = 40.0    # a sound heard over the whole map still draws a ring this wide
const ALPHA: float = 0.15          # at night
const DAY_ALPHA: float = 0.30      # in full day; the hour's light blends the two
const COLOR := Color(0.74, 0.77, 0.80)
const FADE_IN: float = 0.06
const FADE_OUT_START: float = 0.45
const FADE_OUT_END: float = 0.85

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
global uniform vec4 fx_tint : source_color; // weather and hour colour for sky and haze
uniform vec4 tint : source_color = vec4(0.74, 0.77, 0.80, 1.0);
uniform float fade = 1.0;          // the ring's envelope at this moment
uniform float night_alpha = 0.15;
uniform float day_alpha = 0.30;
uniform float width = 0.02;
// Linear maxima: FxState clear night (0.80 * 0.36), default day (0.75 * 0.77).
// Atmosphere's night lies below this range and its clear day above it.
const float FX_TINT_NIGHT = 0.06743727;
const float FX_TINT_DAY = 0.29291349;
const float NIGHT_BRIGHTNESS = 0.6;
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float x = (d - (1.0 - width)) / width;
	float band = smoothstep(0.0, 0.5, x) * (1.0 - smoothstep(0.5, 1.0, x));
	float light = max(fx_tint.r, max(fx_tint.g, fx_tint.b));
	float day = smoothstep(FX_TINT_NIGHT, FX_TINT_DAY, light);
	ALBEDO = tint.rgb * mix(NIGHT_BRIGHTNESS, 1.0, day);
	ALPHA = fade * band * mix(night_alpha, day_alpha, day);
}
"""

var peak_alpha: float = ALPHA      # night peak
var day_alpha: float = DAY_ALPHA
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
	mat.set_shader_parameter("night_alpha", peak_alpha)
	mat.set_shader_parameter("day_alpha", day_alpha)
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


## Fades in, holds while it spreads, then drops fast once out: (1 - u)^2 over the fade-out.
static func envelope(t: float) -> float:
	var u: float = clampf((t - FADE_OUT_START) / (FADE_OUT_END - FADE_OUT_START), 0.0, 1.0)
	return smoothstep(0.0, FADE_IN, t) * (1.0 - u) * (1.0 - u)


## Grows out to its radius over GROW, fades out by FADE_OUT_END; the band stays WIDTH wide.
func _shape(ring: Dictionary) -> void:
	var t: float = ring["t"]
	var s: float = float(ring["r"]) * lerpf(0.3, 1.0, minf(1.0, t / GROW))
	(ring["node"] as Node3D).scale = Vector3(s, 1.0, s)
	var mat: ShaderMaterial = ring["mat"]
	mat.set_shader_parameter("width", WIDTH / s)
	mat.set_shader_parameter("fade", envelope(t))
