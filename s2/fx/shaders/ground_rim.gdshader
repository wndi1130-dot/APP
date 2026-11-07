shader_type spatial;
// Ground items alone: a dark rim with an optional pale outer band on dark floors.
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

#include "res://fx/shaders/fx_common.gdshaderinc"

uniform float core : hint_range(0.0, 1.0) = 0.6;
uniform float snow_keep : hint_range(0.0, 1.0) = 0.5;
uniform float halo : hint_range(0.0, 1.0) = 0.0;
uniform float halo_from : hint_range(0.0, 1.0) = 0.7;

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
	// Distance across the margin, with rounded corners, as in contact_shade.
	vec2 lo = max(foot.xy - UV, vec2(0.0)) / max(foot.xy, vec2(0.001));
	vec2 hi = max(UV - foot.zw, vec2(0.0)) / max(vec2(1.0) - foot.zw, vec2(0.001));
	float d = length(lo + hi);
	float edge = 1.0 - smoothstep(1.0 - fwidth(d), 1.0, d);
	// Keep the old last-pixel fade when halo is zero; roofs keep full strength.
	float dark = strength * (1.0 - smoothstep(core, 1.0, d)) * edge
		* mix(1.0, snow_keep, clamp(fx_snow, 0.0, 1.0) * sky);
	// Snow does not dim the pale band: on a pale floor it simply blends in.
	float light = halo * smoothstep(halo_from, 1.0, d) * edge;
	ALPHA = clamp(dark + light, 0.0, 1.0);
	ALBEDO = vec3(light / max(dark + light, 1e-4));
}
