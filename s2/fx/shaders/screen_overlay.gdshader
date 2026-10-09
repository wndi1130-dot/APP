shader_type canvas_item;
// One full-screen ColorRect above the 3D view, under the HUD. It only blends
// on top (no screen-texture read), so it costs one cheap pass on phones.
// - vignette: always a little; deeper when hurt or paused
// - edge_frost: colourless frost on the edge the horde comes from
//   (presentation_motion.md 무리 경고; never a red flag)
// - hurt: a dark pulse after a bite, no red (red is for discontent and shortage)
// - grain, and fx_flash for lightning
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

	float g = (fx_hash(uv * px * 0.5 + fract(TIME * 7.13)) - 0.5) * grain;
	vec3 col = mix(vec3(0.0), FX_RIME, frost / max(frost + dark, 1e-4));
	float a = clamp(dark + frost * 0.85, 0.0, 1.0);
	// Lightning: a pale wash; grain rides on whatever is there.
	col = mix(col, vec3(0.86, 0.88, 0.9), fx_flash * 0.5);
	a = max(a, fx_flash * 0.28);
	COLOR = vec4(col + g, clamp(a + abs(g), 0.0, 1.0));
}
