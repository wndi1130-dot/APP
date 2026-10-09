shader_type spatial;
// Base surface for every opaque world model (kit buildings, props, Tripo
// meshes after cleanup). Weather comes from the fx_* globals so one script
// changes the whole stop: wet darkening and puddles, snow on up-facing faces,
// rime, and soot near the ground. Graybox meshes set use_vertex_color.
#include "res://fx/shaders/fx_common.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.9;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
// How much water darkens it: cloth, wood and brick high, metal and glass low.
uniform float porosity : hint_range(0.0, 1.0) = 0.6;
// 0 for undersides, interiors and anything a roof covers.
uniform float snow_catch : hint_range(0.0, 1.0) = 1.0;
uniform float rime_catch : hint_range(0.0, 1.0) = 1.0;
// Dirt and soot rising from the ground (world metres).
uniform float grime : hint_range(0.0, 1.0) = 0.0;
uniform float grime_height = 0.8;
// Flat ground only: let rain pool in low noise spots.
uniform float puddles : hint_range(0.0, 1.0) = 0.0;
// 1 indoors: no rain, snow or puddles reach it.
uniform float sheltered : hint_range(0.0, 1.0) = 0.0;

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb * albedo.rgb;
	if (use_vertex_color) {
		base *= COLOR.rgb;
	}
	float open = 1.0 - sheltered;
	float up = clamp(w_nrm.y, 0.0, 1.0);
	float n = fx_fbm2(w_pos.xz * 0.9 + w_pos.y * 0.37);
	float rough = roughness_base;

	// Soot and dirt: darker toward the ground, broken by noise.
	float g = grime * (1.0 - smoothstep(0.0, grime_height, w_pos.y)) * (0.55 + 0.45 * n);
	base = mix(base, base * vec3(0.34, 0.32, 0.31), g);

	// Wet: porous things darken, everything loses roughness.
	float wet = clamp(fx_wet, 0.0, 1.0) * open;
	base *= mix(1.0, 0.55, porosity * wet);
	rough = mix(rough, min(rough, 0.35), wet * 0.8);
	float pool = puddles * wet * smoothstep(0.66, 0.74, fx_fbm2(w_pos.xz * 0.5)) * smoothstep(0.9, 0.98, up);
	base = mix(base, base * 0.75, pool);
	rough = mix(rough, 0.06, pool);

	// Snow lies on faces that look up. Thin snow (level 1) leaves patches on
	// flat tops and slopes mostly bare; deep snow (level 2) takes slopes too.
	float s = clamp(fx_snow, 0.0, 1.0) * snow_catch * open;
	float t = 1.0 - 0.9 * s;
	// Own noise, rotated off the grid and broad, so bare patches read as
	// drifts and not as a blotch pattern.
	vec2 sp = mat2(vec2(0.82, 0.57), vec2(-0.57, 0.82)) * w_pos.xz;
	float sn = fx_fbm2(sp * 0.28) * 0.75 + fx_vnoise(sp * 1.7 + 3.1) * 0.25;
	float lie = up * up * (0.55 + 0.45 * sn);
	float cover = s > 0.001 ? smoothstep(t - 0.12, t + 0.08, lie) : 0.0;
	// Wet snow turns to grey slush.
	vec3 snow_col = FX_SNOW * (0.92 + 0.08 * n) * mix(1.0, 0.72, wet);
	base = mix(base, snow_col, cover);
	rough = mix(rough, mix(0.85, 0.5, wet), cover);

	// Rime: a grey-white bloom on whatever is left bare.
	float r = clamp(fx_frost, 0.0, 1.0) * rime_catch * (1.0 - cover);
	base = mix(base, FX_RIME, r * 0.35 * smoothstep(0.35, 0.8, n));

	ALBEDO = fx_photo(base, fx_fade);
	ROUGHNESS = rough;
	METALLIC = metallic * (1.0 - cover);
}
