shader_type spatial;
// The glowing heart of a night light (night_light_view.gd): a flame or a round
// glow on an upright quad that turns to the camera, added on top. It flickers
// by itself on the GPU, each light out of step with the others. No smoke.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://fx/shaders/fx_common.gdshaderinc"

uniform vec3 tint : source_color = vec3(1.0, 0.62, 0.28);
// Linear on purpose (no source_color): the pale yolk this shader always had.
uniform vec3 core_tint = vec3(1.0, 0.86, 0.58);
uniform bool bed = false;
uniform float seed = 0.0;
uniform float phase = 0.0;
uniform float flicker = 1.0;   // 0: a steady light (headlights)
uniform float round_glow = 0.0;   // 0: a flame, wide below and pointed above; 1: a round glow

void vertex() {
	if (!bed) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
			vec4(0.0, 1.0, 0.0, 0.0),
			vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
			MODEL_MATRIX[3]);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float t = TIME * 7.0 + phase;
	float wob = flicker * (0.08 * sin(t + seed) + 0.05 * sin(t * (2.3 + 0.12 * sin(seed)) + 1.7 + seed));
	float f;
	vec3 col = tint;
	if (bed) {
		// Round, low embers: the model's flat transform and depth test stay intact.
		f = 1.0 - smoothstep(0.55, 1.0, length(p));
		f *= 0.55 + 0.10 * fx_vnoise(p * 7.0 + phase);
	} else if (round_glow > 0.5) {
		f = 1.0 - smoothstep(0.0, 1.0, length(p));
		f *= f;
	} else {
		// A tongue of flame: soft at its sides and tip, a pale core low down
		// that warms to the orange tint as it rises.
		float h = 1.0 - UV.y;
		float w = mix(0.62, 0.05, pow(h, 0.75)) * (1.0 + wob);
		float x = abs(p.x + wob * h * 1.8);
		f = (1.0 - smoothstep(w * 0.15, w, x)) * (1.0 - smoothstep(0.55 + wob, 1.0, h)) * smoothstep(0.0, 0.18, h);
		float core = (1.0 - smoothstep(0.0, w * 0.5, x)) * (1.0 - smoothstep(0.1, 0.55, h));
		col = mix(tint, core_tint, core);
	}
	float pulse = 1.0 - flicker * (0.12 + 0.12 * sin(t * 1.3 + 0.4));
	if (bed) {
		pulse = 0.92 + 0.04 * sin(TIME * 1.1 + phase);
	}
	ALBEDO = fx_photo(col, fx_fade) * f * pulse * 0.9;
}
