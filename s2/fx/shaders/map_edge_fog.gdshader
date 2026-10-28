shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, diffuse_lambert, specular_disabled;
#include "res://fx/shaders/fx_common.gdshaderinc"
// Low fog over the ground past the map's edge (fx/map_edge.gd, 결정 448 17).
// The reference game's fog sheets: a pale grey (0.9, 0.9, 0.95) under the
// hour's light, a noise whose upper half is the cover, coloured by the noise
// too, drifting with the wind. Here the cover also grows with the distance past
// the edge until it is whole, so nothing beyond reads. Lit like the ground, so
// it goes dark at night instead of glowing.

uniform vec2 map_size = vec2(120.0, 70.0);
uniform vec3 fog_color : source_color = vec3(0.6, 0.61, 0.63);
uniform float inset = 2.5;   // m inside the edge the fog starts
uniform float reach = 12.0;  // m past the edge it is whole
uniform float layer_k = 0.5; // how much this sheet covers
uniform float mask_on = 1.0; // the sight mask's shade (map_view mask_on)
// The map's sight mask (map_view vis_texture); past the edge it reads the
// nearest edge cell, as the ground there does.
uniform sampler2D vis : filter_linear, repeat_disable;
// By day round and soft about the eye, as the ground (world_vis, decision 491).
uniform vec2 eye_xz = vec2(-1000.0);
uniform float eye_r = 18.0;
uniform float round_day = 0.0;
uniform float round_floor = 0.95;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Metres past the map's edge (inside it the distance is negative).
	vec2 half_size = map_size * 0.5;
	vec2 e = abs(world_pos.xz - half_size) - half_size;
	float d = length(max(e, vec2(0.0))) + min(max(e.x, e.y), 0.0);
	// Each sheet its own pattern (height as an offset), sliding with the wind.
	vec2 drift = fx_wind.xy * TIME * (0.15 + 0.6 * fx_wind.z);
	// Big slow lumps push the fog's front in and out, so it is no straight wall.
	d += (fx_fbm2(world_pos.xz * 0.05 + drift * 0.03 + vec2(13.0, world_pos.y)) - 0.5) * 10.0;
	float ramp = smoothstep(-inset, reach, d);
	float n = fx_fbm2(world_pos.xz * 0.11 + drift * 0.08 + vec2(world_pos.y * 5.3, world_pos.y * 2.1));
	float sheet = mix(smoothstep(0.3, 0.72, n), 1.0, smoothstep(reach * 0.45, reach, d));
	// The hour's fog hue at a pale fog's brightness; the light does the rest.
	// The fog's own light and dark: 0.88 .. 1.06 of it.
	// Half of it the reference's cool white, so a warm hour does not turn it khaki.
	vec3 hue = fog_color / max(max(fog_color.r, fog_color.g), max(fog_color.b, 0.05));
	hue = mix(hue, vec3(0.95, 0.95, 1.0), 0.5);
	vec3 col = hue * 0.8 * (0.88 + 0.18 * n);
	// Under the sight mask the fog dims as the ground beneath it does (world_vis:
	// seen now full, seen before dim, never seen dark), a little less in the
	// dark, so the edge is never the brightest thing on the screen.
	vec2 seen = texture(vis, world_pos.xz / map_size).rg;
	float reveal = seen.r;
	float floor_k = mix(fx_sight.x, fx_sight.y, seen.g);
	float round_k = clamp(round_day, 0.0, 1.0);
	if (round_k > 0.001) {
		float near = 1.0 - smoothstep(eye_r * 0.4, eye_r * 1.3, distance(world_pos.xz, eye_xz));
		// As world_vis: the floor first, the round shape after.
		reveal = mix(reveal, near, smoothstep(0.5, 1.0, round_k));
		floor_k = mix(floor_k, round_floor, smoothstep(0.0, 0.5, round_k));
	}
	float lit = max(max(reveal, floor_k), 0.45);
	col *= mix(1.0, lit, clamp(mask_on, 0.0, 1.0));
	ALBEDO = fx_photo(col, fx_fade);
	ROUGHNESS = 1.0;
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	// Farther out every sheet closes, so the three together hide it all.
	float k = mix(layer_k, 1.0, smoothstep(reach, reach * 1.6, d));
	ALPHA = clamp(ramp * sheet * k, 0.0, 1.0);
}
