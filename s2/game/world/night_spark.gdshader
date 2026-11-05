shader_type spatial;
// Mixed, not added: beside a lit fire the ground is already near white, and an
// added two-pixel spark vanishes into it; a mixed hot dot still reads.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://fx/shaders/fx_common.gdshaderinc"

// World metres, horizontal only; the height bound includes the whole quad.
uniform float sway = 0.035;
varying float age;

void vertex() {
	age = INSTANCE_CUSTOM.y;
	float phase = float(INSTANCE_ID) * 2.39996;
	vec4 center = MODEL_MATRIX[3];
	center.xz += sway * vec2(sin(TIME * 5.0 + phase), cos(TIME * 4.3 + phase));
	// Preserve the particle process material's scale when facing the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * length(MODEL_MATRIX[2].xyz), 0.0), center);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float dot_shape = 1.0 - smoothstep(0.45, 1.0, length(UV * 2.0 - 1.0));
	float fade = (1.0 - smoothstep(0.6, 1.0, age)) * COLOR.a;
	ALBEDO = fx_photo(COLOR.rgb, fx_fade);
	ALPHA = dot_shape * fade;
}
