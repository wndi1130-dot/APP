shader_type spatial;
// Rain streaks and snowflakes for GPUParticles3D on a QuadMesh.
// shape 0: rain, a thin streak along the fall as the screen sees it (world down
// pressed flat onto the view), at least RAIN_MIN_PX wide. Standing upright it
// showed the field's camera high above only its end (0.6 of its length), and at
// the mesh's 2.5 cm it was less than a pixel across, so the rain read as dots.
// shape 1: snow, a soft round flake that faces the camera, at least
// FLAKE_MIN_PX across: at the mesh's 10 cm the field showed a flake one or two
// pixels wide behind its soft edge, faint dust rather than falling snow.
// shape 2: wind-blown snow, a soft streak lying along `axis` (the way it flies).
// Pale grey, never sky blue (decisions.md 날씨와 빛).
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
#include "res://fx/shaders/fx_common.gdshaderinc"

uniform int shape : hint_range(0, 2) = 1;
uniform vec4 tint : source_color = vec4(0.86, 0.87, 0.88, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.7;
// shape 2: world direction the streak lies along.
uniform vec3 axis = vec3(0.0, -1.0, 0.0);
// Ice dust after a storm: each flake glints on and off (0 = steady).
uniform float twinkle : hint_range(0.0, 1.0) = 0.0;

varying float glint;

// Thinnest a rain streak is drawn, in screen pixels (a thinner quad breaks into
// dots as it crosses the pixel grid).
const float RAIN_MIN_PX = 1.5;
// Smallest a snowflake (or a sleet flake) is drawn across, in screen pixels.
const float FLAKE_MIN_PX = 4.0;

// One screen pixel's size in the world where this particle is (orthographic: w is 1).
float pixel_size(mat4 view, mat4 proj, vec3 at, vec2 viewport) {
	vec4 clip = proj * (view * vec4(at, 1.0));
	return 2.0 * abs(clip.w) / (abs(proj[1][1]) * viewport.y);
}

void vertex() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	float sx = max(scale.x, 0.0001);
	if (shape == 1) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		float px = pixel_size(VIEW_MATRIX, PROJECTION_MATRIX, MODEL_MATRIX[3].xyz, VIEWPORT_SIZE);
		VERTEX.xy = sign(VERTEX.xy) * 0.5 * max(2.0 * abs(VERTEX.xy) * sx, vec2(FLAKE_MIN_PX * px)) / sx;
	} else if (shape == 0) {
		vec3 back = INV_VIEW_MATRIX[2].xyz;
		vec3 up = vec3(0.0, 1.0, 0.0) - back * back.y;
		up = length(up) > 0.001 ? normalize(up) : INV_VIEW_MATRIX[1].xyz;
		vec3 side = normalize(cross(up, back));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(side, 0.0), vec4(up, 0.0), vec4(back, 0.0), MODEL_MATRIX[3]);
		// The mesh carries the streak's width (QuadMesh size): no thinner than
		// RAIN_MIN_PX where the drop is.
		float px = pixel_size(VIEW_MATRIX, PROJECTION_MATRIX, MODEL_MATRIX[3].xyz, VIEWPORT_SIZE);
		VERTEX.x = sign(VERTEX.x) * 0.5 * max(2.0 * abs(VERTEX.x) * sx, RAIN_MIN_PX * px) / sx;
	} else {
		vec3 up = normalize(axis);
		vec3 side = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
		vec3 fwd = cross(side, up);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(side, 0.0), vec4(up, 0.0), vec4(fwd, 0.0), MODEL_MATRIX[3]);
	}
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(scale.x, 0.0, 0.0, 0.0), vec4(0.0, scale.y, 0.0, 0.0), vec4(0.0, 0.0, scale.z, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	float phase = fx_hash(vec2(float(INSTANCE_ID), 3.7)) * 6.2832;
	glint = mix(1.0, pow(0.5 + 0.5 * sin(TIME * 2.3 + phase), 6.0), twinkle);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a;
	if (shape == 0) {
		// Bright head at the bottom, tail fading upward.
		a = (1.0 - smoothstep(0.2, 1.0, abs(p.x))) * smoothstep(-1.0, 0.6, -p.y) * 0.55;
	} else if (shape == 2) {
		a = (1.0 - smoothstep(0.25, 1.0, abs(p.x))) * (1.0 - smoothstep(0.15, 1.0, abs(p.y)));
	} else {
		a = 1.0 - smoothstep(0.35, 1.0, length(p));
	}
	ALBEDO = fx_photo(tint.rgb * mix(vec3(1.0), fx_tint.rgb, 0.25) + fx_flash * 0.3, fx_fade);
	ALPHA = clamp(a * opacity * COLOR.a * glint, 0.0, 1.0);
}
