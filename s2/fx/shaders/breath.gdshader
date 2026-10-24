shader_type spatial;
// Breath puffing out before a face in the cold (fx/breath_fx.gd, one MultiMesh
// for everyone). INSTANCE_CUSTOM: x the person's own phase, y strength (cold
// and dark), z running (quicker, fuller). Each breath swells, rises a little,
// drifts on the wind and is gone in under two seconds. Grey-white, no screen
// or depth reads.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
#include "res://fx/shaders/fx_common.gdshaderinc"

// How lit the hour is (dim at night).
uniform float light : hint_range(0.0, 1.0) = 1.0;

varying float fade_v;

void vertex() {
	float run = INSTANCE_CUSTOM.z;
	float period = mix(3.4, 1.5, run);
	float t = fract(TIME / period + INSTANCE_CUSTOM.x * 7.0);
	float out_breath = smoothstep(0.0, 0.07, t) * (1.0 - smoothstep(0.16, 0.48, t));
	float grow = mix(0.3, 1.0, smoothstep(0.0, 0.45, t)) * mix(1.0, 1.25, run);
	vec3 drift = vec3(fx_wind.x, 0.0, fx_wind.y) * (0.15 + fx_wind.z) * t * 0.7 + vec3(0.0, t * 0.2, 0.0);
	vec3 origin = MODEL_MATRIX[3].xyz + drift;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], vec4(origin, 1.0));
	VERTEX *= grow;
	fade_v = out_breath * clamp(INSTANCE_CUSTOM.y, 0.0, 1.3);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float n = fx_vnoise(UV * 3.5 + vec2(TIME * 0.7, 0.0));
	float a = (1.0 - smoothstep(0.15, 1.0, length(p) * (0.8 + 0.4 * n))) * fade_v * 0.5;
	ALBEDO = fx_photo(mix(vec3(0.86, 0.87, 0.88), fx_sky.rgb, 0.2) * light, fx_fade);
	ALPHA = clamp(a, 0.0, 1.0);
}
