shader_type spatial;
// Contact shade (T0-6): a flat quad on the floor round a thing on the ground (ground_look.gd rim) or
// under a prop, black with an alpha, so whatever the floor is (asphalt, boards, snow, a lamp's pool)
// it is that floor made darker. Full over the footprint and out to `core` of the margin, then it
// fades to the quad's edge; the last pixel is smoothed (fwidth) so a thin rim does not crawl as the
// camera moves. Lighter on snow (snow_keep): a shade in the snow, not a black line. Black over the
// floor comes out the same in any order, so the quads need no sorting among themselves; the
// materials draw first of the see-through things (render_priority, map_view.gd).
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

#include "res://fx/shaders/fx_common.gdshaderinc"

// The footprint's share of the quad along its two sides (x, y) and the strength (z): a MultiMesh
// row's custom data (per_instance) or the quad's vertex colour.
uniform bool per_instance = false;
// How much of the margin round the footprint keeps the full strength before it fades.
uniform float core : hint_range(0.0, 1.0) = 0.0;
// What is left of the strength on deep snow (fx_snow 1).
uniform float snow_keep : hint_range(0.0, 1.0) = 0.5;

varying vec3 shade;

void vertex() {
	shade = per_instance ? INSTANCE_CUSTOM.rgb : COLOR.rgb;
}

void fragment() {
	vec2 inner = clamp(shade.xy, vec2(0.0), vec2(0.98));
	// 0 at the footprint's edge, 1 at the quad's edge (round at the corners).
	float d = length(max(abs(UV - 0.5) * 2.0 - inner, vec2(0.0)) / (vec2(1.0) - inner));
	float k = 1.0 - smoothstep(core, 1.0, d);
	k *= 1.0 - smoothstep(1.0 - fwidth(d), 1.0, d);
	ALBEDO = vec3(0.0);
	ALPHA = shade.z * k * mix(1.0, snow_keep, clamp(fx_snow, 0.0, 1.0));
}
