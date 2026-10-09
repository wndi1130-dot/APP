shader_type spatial;
// Dark river and canal water (the Elbe crossing shows only water and banks).
// Flow ripples along `flow`, rain rings when fx_wet is up, ice skin by fx_frost.
// No depth or screen texture reads, so it stays cheap on the Mobile renderer.
render_mode cull_back, specular_schlick_ggx;
#include "res://fx/shaders/fx_common.gdshaderinc"

uniform vec4 deep : source_color = vec4(0.06, 0.075, 0.08, 1.0);
uniform vec4 shallow : source_color = vec4(0.16, 0.17, 0.16, 1.0);
uniform vec2 flow = vec2(1.0, 0.0);
uniform float flow_speed = 0.4;
uniform float ripple_scale = 0.6;
// Ice skin from the edges when frost is hard (0 never freezes).
uniform float freezes : hint_range(0.0, 1.0) = 1.0;

varying vec3 w_pos;

float h_at(vec2 p) {
	vec2 f = flow * TIME * flow_speed;
	return fx_fbm2(p * ripple_scale - f) * 0.6 + fx_vnoise(p * ripple_scale * 3.0 - f * 1.7) * 0.4;
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = w_pos.xz;
	float e = 0.15;
	float h0 = h_at(p);
	float hx = h_at(p + vec2(e, 0.0));
	float hz = h_at(p + vec2(0.0, e));
	vec3 nw = normalize(vec3(h0 - hx, e * 2.5, h0 - hz));

	// Rain: rings spreading in a grid of cells, each with its own phase.
	float wet = clamp(fx_wet, 0.0, 1.0);
	vec2 cell = floor(p * 1.5);
	vec2 local = fract(p * 1.5) - 0.5;
	float ph = fract(TIME * 0.9 + fx_hash(cell));
	float ring = smoothstep(0.04, 0.0, abs(length(local) - ph * 0.45)) * (1.0 - ph);
	nw.xz += local * ring * wet * 0.8;
	nw = normalize(nw);

	float ice = clamp(fx_frost * freezes - 0.6, 0.0, 0.4) / 0.4;
	float skin = ice * smoothstep(0.3, 0.7, fx_fbm2(p * 0.25));
	vec3 col = mix(deep.rgb, shallow.rgb, h0 * 0.5);
	col = mix(col, FX_RIME * 0.7, skin);
	ALBEDO = fx_photo(col, fx_fade);
	ROUGHNESS = mix(0.08, 0.6, skin);
	METALLIC = 0.0;
	SPECULAR = 0.6;
	NORMAL = mix((VIEW_MATRIX * vec4(nw, 0.0)).xyz, NORMAL, skin);
}
