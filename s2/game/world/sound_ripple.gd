extends Node3D
## 소리 물결(결정 471 H1, 442): 뛰기·문 차기·창 깨기 같은 우리 쪽 큰 소리가 닿는 넓이를 바닥에 옅은
## 동그라미로 1초 보인다. 누가 듣는지는 그대로다 — make_sound가 잰 반경을 그릴 뿐이다. 색은 차갑고
## 옅게 두어 눈 바탕에서 튀지 않는다.

const SECONDS: float = 1.0
const GROW: float = 0.6            # the ring reaches its radius in this part of the second
const WIDTH: float = 0.18          # metres
const MOST_RADIUS: float = 40.0    # a sound heard over the whole map still draws a ring this wide
const ALPHA: float = 0.35
const COLOR := Color(0.80, 0.82, 0.84)

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.8, 0.82, 0.84, 1.0);
uniform float alpha = 0.35;
uniform float width = 0.02;
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float band = smoothstep(1.0 - width * 2.0, 1.0 - width, d) * (1.0 - smoothstep(1.0 - width * 0.5, 1.0, d));
	ALBEDO = tint.rgb;
	ALPHA = alpha * band;
}
"""

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


## Grows out to its radius over GROW, fades over the whole second; the band stays WIDTH wide.
func _shape(ring: Dictionary) -> void:
	var t: float = ring["t"]
	var s: float = float(ring["r"]) * lerpf(0.3, 1.0, minf(1.0, t / GROW))
	(ring["node"] as Node3D).scale = Vector3(s, 1.0, s)
	var mat: ShaderMaterial = ring["mat"]
	mat.set_shader_parameter("width", WIDTH / s)
	mat.set_shader_parameter("alpha", ALPHA * (1.0 - t / SECONDS))
