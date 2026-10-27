shader_type spatial;
// The glowing heart of a night light (night_light_view.gd): a flame or a round
// glow on an upright quad that turns to the camera, added on top. It flickers
// by itself on the GPU, each light out of step with the others. No smoke.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.62, 0.28);
uniform float phase = 0.0;
uniform float flicker = 1.0;   // 0: a steady light (headlights)
uniform float round_glow = 0.0;   // 0: a flame, wide below and pointed above; 1: a round glow

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float t = TIME * 7.0 + phase;
	float wob = flicker * (0.08 * sin(t) + 0.05 * sin(t * 2.3 + 1.7));
	float f;
	if (round_glow > 0.5) {
		f = 1.0 - smoothstep(0.0, 1.0, length(p));
		f *= f;
	} else {
		float h = 1.0 - UV.y;
		float w = mix(0.7, 0.04, pow(h, 0.8)) * (1.0 + wob);
		float x = abs(p.x + wob * h * 1.5);
		f = (1.0 - smoothstep(w * 0.45, w, x)) * (1.0 - smoothstep(0.7 + wob, 1.0, h)) * smoothstep(0.0, 0.12, h);
	}
	float pulse = 1.0 - flicker * (0.12 + 0.12 * sin(t * 1.3 + 0.4));
	vec3 hot = mix(tint, vec3(1.0, 0.9, 0.72), f * f * 0.6);
	ALBEDO = hot * f * pulse * 1.6;
}
