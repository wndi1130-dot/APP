shader_type spatial;
// Ground items alone (ground_look.gd rim): contact_shade's rim, black with an
// alpha over whatever the floor is, with its own core and snow keep so a thing
// on the new thin snow still stands off it (other rims keep contact_shade).
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

#include "res://fx/shaders/fx_common.gdshaderinc"

// How much of the margin round the footprint keeps the full strength before it fades.
uniform float core : hint_range(0.0, 1.0) = 0.6;
// What is left of the strength on deep snow (fx_snow 1), out of doors only.
uniform float snow_keep : hint_range(0.0, 1.0) = 0.85;

varying vec4 foot;
varying float strength;
varying float sky;

void vertex() {
	// RG is the centred footprint's share; B is strength, A is open sky.
	vec2 h = clamp(COLOR.rg, vec2(0.0), vec2(0.98)) * 0.5;
	foot = vec4(vec2(0.5) - h, vec2(0.5) + h);
	strength = COLOR.b;
	sky = COLOR.a;
}

void fragment() {
	// 0 on the footprint, 1 at the quad's edge on each side (round at the corners).
	vec2 lo = max(foot.xy - UV, vec2(0.0)) / max(foot.xy, vec2(0.001));
	vec2 hi = max(UV - foot.zw, vec2(0.0)) / max(vec2(1.0) - foot.zw, vec2(0.001));
	float d = length(lo + hi);
	float k = 1.0 - smoothstep(core, 1.0, d);
	// The last pixel is smoothed so a thin rim does not crawl as the camera moves.
	k *= 1.0 - smoothstep(1.0 - fwidth(d), 1.0, d);
	ALBEDO = vec3(0.0);
	ALPHA = strength * k * mix(1.0, snow_keep, clamp(fx_snow, 0.0, 1.0) * sky);
}
