shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;
#include "res://fx/shaders/fx_common.gdshaderinc"
// A foggy day over the whole field (fx/map_edge.gd, 색감 루프 C5), one layer
// over the screen: each pixel finds the ground spot under it (the camera is
// orthographic, so the ray is the camera's forward) and lays the fog there. The
// reference game's fog: drifting noise whose upper half is the cover, a tenth of
// it round the walker; here it closes in from where sight ends in the fog. One
// layer, so a roof or a wall crossing it leaves no edge.

uniform float field_fog = 0.0;       // 0 none .. 1 a foggy day (Atmosphere.field_fog)
uniform vec2 clear_at = vec2(0.0);   // the eye (player) on the ground, x z
uniform float clear_r = 11.0;        // how far sight reaches in the fog (m)
uniform vec3 fog_albedo = vec3(0.6);  // the fog's own colour, linear (MapEdge.fog_albedo)
uniform vec3 fog_light = vec3(0.5);   // the hour's light on an up-facing sheet, linear (MapEdge.fog_light)
uniform float mask_on = 1.0;         // the sight mask's shade (map_view mask_on)

void vertex() {
	// Over the whole screen whatever the camera.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, 0.5);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	vec3 origin = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec3 dir = -INV_VIEW_MATRIX[2].xyz;
	float t = -origin.y / min(dir.y, -0.001);
	vec2 ground = origin.xz + dir.xz * t;
	vec2 drift = fx_wind.xy * TIME * (0.15 + 0.6 * fx_wind.z);
	float n = fx_fbm2(ground * 0.11 + drift * 0.08);
	float n2 = fx_fbm2(ground * 0.045 - drift * 0.05 + vec2(31.0, 7.0));
	float eye = distance(ground, clear_at);
	float near = mix(0.1, 1.0, smoothstep(clear_r * 0.55, clear_r * 1.35, eye));
	float cover = smoothstep(0.2, 0.7, n * 0.6 + n2 * 0.4);
	// Faded (tactical pause) as a surface is, then lit, as world_vis does.
	vec3 col = fx_photo(fog_albedo * (0.88 + 0.18 * n), fx_fade) * fog_light;
	// Under the sight mask the fog past sight dims as unseen ground does, a
	// little less, and smoothly (the mask's own cells would show their edges).
	float lit = mix(1.0, 0.45, smoothstep(clear_r * 0.8, clear_r * 1.2, eye));
	col *= mix(1.0, lit, clamp(mask_on, 0.0, 1.0));
	ALBEDO = col;
	// A fixed dither of a few percent: a smooth fog in the dark otherwise breaks
	// into flat steps of the screen's 256 levels.
	float dither = (fx_hash(floor(FRAGCOORD.xy)) - 0.5) * 0.04;
	ALPHA = clamp(field_fog * 0.85 * cover * near + dither * field_fog, 0.0, 1.0);
}
