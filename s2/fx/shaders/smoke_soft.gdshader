shader_type spatial;
// Soft billboard puffs for GPUParticles3D: running-locomotive smoke, low steam
// under a stopped engine's wheels, faint stove steam, ground-hugging omen
// smoke. fx/smoke.gd builds every emitter and owns the ban-line limits
// (no chimney or column kinds); this shader only draws a puff.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
#include "res://fx/shaders/fx_common.gdshaderinc"

uniform vec4 smoke_color : source_color = vec4(0.42, 0.42, 0.43, 1.0);
// Colour the puff fades to as it ages (smoke thins and greys out).
uniform vec4 old_color : source_color = vec4(0.62, 0.63, 0.64, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.7;
uniform float softness : hint_range(0.05, 1.0) = 0.6;

varying float age;
varying float seed;

void vertex() {
	// Camera-facing billboard that keeps the particle's scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	age = INSTANCE_CUSTOM.y;
	seed = fract(float(INSTANCE_ID) * 0.6180339);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float n = fx_fbm2(UV * 3.0 + vec2(seed * 17.0, seed * 5.0 - TIME * 0.15));
	// The puff erodes from its rim as it ages.
	float edge = 1.0 - smoothstep(1.0 - softness, 1.0, r + (n - 0.5) * 0.6 + age * 0.25);
	float fade_in = smoothstep(0.0, 0.08, age);
	float fade_out = 1.0 - smoothstep(0.55, 1.0, age);
	// Unshaded, so take the hour and weather from fx_tint (dark at night).
	vec3 c = mix(smoke_color.rgb, old_color.rgb, age) * fx_tint.rgb * 1.3;
	ALBEDO = fx_photo(c * (0.85 + 0.3 * n), fx_fade) * COLOR.rgb;
	ALPHA = clamp(edge * fade_in * fade_out * density * COLOR.a, 0.0, 1.0);
}
