shader_type canvas_item;
// One full-screen ColorRect above the 3D view, under the HUD. It only blends
// on top (no screen-texture read), so it costs one cheap pass on phones.
// - vignette: always a little; deeper when hurt or paused
// - edge_frost: colourless frost on the edge the horde comes from
//   (presentation_motion.md 무리 경고; never a red flag)
// - hurt: a dark pulse after a bite, no red (red is for discontent and shortage)
// - grain, and fx_flash for lightning
// - storm (weather_fx.md 14장): front is the dark bank on the edge the wind
//   comes from before a storm; whiteout is the snow-fog that closes the view
//   inside it, streaming with the wind and thickening in gusts
// The photo fade of a tactical pause is fx_fade inside the world shaders, so
// people and HUD keep their colour.
#include "res://fx/shaders/fx_common.gdshaderinc"

uniform float vignette : hint_range(0.0, 1.0) = 0.35;
uniform float edge_frost : hint_range(0.0, 1.0) = 0.0;
// Screen direction the threat comes from (x right, y down); zero = all edges.
uniform vec2 frost_dir = vec2(0.0);
uniform float hurt : hint_range(0.0, 1.0) = 0.0;
uniform float grain : hint_range(0.0, 0.2) = 0.03;
uniform float pause_dim : hint_range(0.0, 1.0) = 0.0;
uniform float front : hint_range(0.0, 1.0) = 0.0;
uniform float whiteout : hint_range(0.0, 1.0) = 0.0;
// Screen direction the wind blows toward (x right, y down).
uniform vec2 storm_dir = vec2(1.0, 0.0);
// Lamps that stay readable through the snow-fog: xy screen position (0..1),
// z reach as a share of the screen height, w strength.
uniform int glow_count : hint_range(0, 8) = 0;
uniform vec4 glow[8];

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = px.x / px.y;
	vec2 d = (uv - 0.5) * vec2(aspect, 1.0);

	// Darkening layer (black with alpha).
	float r = length(d) / length(vec2(aspect, 1.0) * 0.5);
	float dark = smoothstep(0.45, 1.05, r) * (vignette + hurt * 0.55 + pause_dim * 0.25);

	// Frost layer: grows in from the edges, weighted toward frost_dir.
	vec2 e2 = min(uv, 1.0 - uv) * vec2(aspect, 1.0);
	float edge = min(e2.x, e2.y);
	float side = 1.0;
	if (length(frost_dir) > 0.001) {
		// Measure from the threatened edge only; other edges stay clear.
		vec2 dir = normalize(frost_dir);
		float half_ext = 0.5 * (abs(dir.x) * aspect + abs(dir.y));
		edge = half_ext - dot(d, dir);
		side = smoothstep(0.0, 0.5, dot(normalize(d + 1e-4), dir) + 0.3);
	}
	float n = fx_fbm2(uv * vec2(aspect, 1.0) * 14.0);
	float fern = fx_crystal(uv * vec2(aspect, 1.0) * 26.0);
	float reach = edge_frost * side * 0.22;
	float frost = edge_frost > 0.001 ? 1.0 - smoothstep(reach - 0.02, reach + 0.03, edge + (n - 0.5) * 0.06) : 0.0;
	frost *= 0.55 + 0.45 * fern;

	// Storm layers. Skipped (no noise cost) on an ordinary stop.
	float bank = 0.0;
	float fog = 0.0;
	float lit = 0.0;
	float halo = 0.0;
	if (front > 0.001 || whiteout > 0.001) {
		vec2 wdir = normalize(storm_dir + vec2(1e-4, 0.0));
		vec2 q = uv * vec2(aspect, 1.0);
		float half_w = 0.5 * (abs(wdir.x) * aspect + abs(wdir.y));
		// 1 on the edge the wind comes from, 0 on the far edge.
		float upwind = 0.5 - 0.5 * dot(d, wdir) / half_w;
		float roll = fx_fbm2(q * 2.2 - wdir * TIME * 0.05);
		bank = front * smoothstep(0.35, 1.05, upwind + (roll - 0.5) * 0.35) * 0.7;
		float sheets = fx_fbm2(q * vec2(1.4, 2.8) - wdir * TIME * 0.5) * 0.6
				+ fx_fbm2(q * 4.6 - wdir * TIME * 1.3) * 0.4;
		float gust = 0.8 + 0.2 * sin(TIME * 0.6) * sin(TIME * 0.23 + 1.7);
		// A little open round the middle, where the squad stands.
		float open = mix(0.5, 1.0, smoothstep(0.05, 0.6, length(d)));
		fog = whiteout * (0.3 + 0.7 * sheets) * gust * open;
		// Lamplight burns a hole in the fog and leaves an amber halo in it.
		for (int i = 0; i < glow_count; i++) {
			float away = length((uv - glow[i].xy) * vec2(aspect, 1.0));
			lit = max(lit, glow[i].w * (1.0 - smoothstep(0.0, glow[i].z, away)));
		}
		halo = lit * fog * 0.45;
		fog *= 1.0 - 0.8 * lit;
	}
	vec3 fog_col = mix(vec3(0.74, 0.75, 0.77), fx_tint.rgb, 0.35);
	vec3 bank_col = vec3(0.10, 0.10, 0.11);

	float g = (fx_hash(uv * px * 0.5 + fract(TIME * 7.13)) - 0.5) * grain;
	vec3 lamp_col = vec3(1.0, 0.64, 0.30);
	vec3 col = (FX_RIME * frost + bank_col * bank + fog_col * fog + lamp_col * halo) / max(frost + dark + bank + fog + halo, 1e-4);
	float a = clamp(dark + frost * 0.85 + bank + fog + halo, 0.0, 1.0);
	// Lightning: a pale wash; grain rides on whatever is there.
	col = mix(col, vec3(0.86, 0.88, 0.9), fx_flash * 0.5);
	a = max(a, fx_flash * 0.28);
	COLOR = vec4(col + g, clamp(a + abs(g), 0.0, 1.0));
}
