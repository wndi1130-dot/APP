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

// Where the footprint lies in the quad (u0, v0, u1, v1), how strong the shade is and whether it lies
// open to the sky (1, or 0 under a roof, as the floors' vertex alpha in world_vis). A MultiMesh row
// (per_instance) gives the rect as its custom data and the strength as the height of its transform
// (the quad is flat, so that scale moves nothing), one more under a roof; a rim quad gives, in its
// vertex colour, the footprint's share of the quad along x and z round the middle, the strength and
// the sky.
uniform bool per_instance = false;
// How much of the margin round the footprint keeps the full strength before it fades.
uniform float core : hint_range(0.0, 1.0) = 0.0;
// What is left of the strength on deep snow (fx_snow 1), out of doors only: indoors no snow lies
// on the floor, so a rim there keeps its strength in every season.
uniform float snow_keep : hint_range(0.0, 1.0) = 0.5;
// A quad cut at a wall on one side (a container's own model, map_view._shade_container): its
// footprint rect (u0, v0, u1, v1) in CUSTOM0, the strength and the sky in the vertex colour.
uniform bool rect_custom = false;

varying vec4 foot;
varying float strength;
varying float sky;

void vertex() {
	if (per_instance) {
		foot = INSTANCE_CUSTOM;
		float h = length(MODEL_MATRIX[1].xyz);
		sky = 1.0 - step(1.0, h);
		strength = h - (1.0 - sky);
	} else {
		vec2 h = clamp(COLOR.rg, vec2(0.0), vec2(0.98)) * 0.5;
		foot = rect_custom ? CUSTOM0 : vec4(vec2(0.5) - h, vec2(0.5) + h);
		strength = COLOR.b;
		sky = COLOR.a;
	}
}

void fragment() {
	// 0 on the footprint, 1 at the quad's edge on each side (round at the corners).
	vec2 lo = max(foot.xy - UV, vec2(0.0)) / max(foot.xy, vec2(0.001));
	vec2 hi = max(UV - foot.zw, vec2(0.0)) / max(vec2(1.0) - foot.zw, vec2(0.001));
	float d = length(lo + hi);
	float k = 1.0 - smoothstep(core, 1.0, d);
	k *= 1.0 - smoothstep(1.0 - fwidth(d), 1.0, d);
	ALBEDO = vec3(0.0);
	ALPHA = strength * k * mix(1.0, snow_keep, clamp(fx_snow, 0.0, 1.0) * sky);
}
