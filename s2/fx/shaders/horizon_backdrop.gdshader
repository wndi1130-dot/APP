shader_type spatial;
// Far horizon card seen from the running train (presentation_motion.md 7b).
// A pre-baked horizon picture (or, without one, procedural hill bands) gets
// only weather colour, haze and night here. `scroll` is distance travelled
// divided by the card's period, set by script so the view stops with the train.
// Ban line: no smoking chimneys or cooling towers belong in the picture; this
// shader adds no smoke of its own.
render_mode unshaded, cull_disabled;
#include "res://fx/shaders/fx_common.gdshaderinc"

uniform sampler2D horizon_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_black;
uniform bool use_texture = false;
uniform float scroll = 0.0;
// Fog and low cloud washing the far layers out (0 clear .. 1 thick).
uniform float haze : hint_range(0.0, 1.0) = 0.6;
// Night erases the horizon line (presentation_motion.md 7b).
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform vec4 sky_top : source_color = vec4(0.30, 0.32, 0.35, 1.0);
uniform vec4 sky_low : source_color = vec4(0.55, 0.56, 0.57, 1.0);
uniform vec4 land : source_color = vec4(0.16, 0.17, 0.17, 1.0);

float ridge(float x, float freq, float seed) {
	return fx_vnoise(vec2(x * freq, seed)) * 0.6 + fx_vnoise(vec2(x * freq * 3.1, seed + 9.0)) * 0.4;
}

void fragment() {
	vec2 uv = UV;
	vec3 sky = mix(sky_low.rgb, sky_top.rgb, smoothstep(0.35, 1.0, 1.0 - uv.y));
	// Clouds drift with the wind, slower than the land.
	float cloud = fx_fbm2(vec2(uv.x * 3.0 + scroll * 0.05 + TIME * 0.01 * fx_wind.z, uv.y * 6.0));
	sky = mix(sky, sky * 0.82, smoothstep(0.4, 0.8, cloud) * (1.0 - uv.y));
	sky *= fx_tint.rgb * 1.25;
	vec3 col = sky;
	float h = 1.0 - uv.y; // 0 bottom .. 1 top
	if (use_texture) {
		vec4 t = texture(horizon_tex, vec2(uv.x + scroll, uv.y));
		col = mix(sky, t.rgb * fx_tint.rgb * 1.25, t.a);
	} else {
		// Three hill bands: far ones scroll slowly and sink into the haze.
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			float depth = 1.0 - fi / 3.0; // 1 far .. 0.33 near
			float x = uv.x + scroll * (0.25 + 0.75 * (1.0 - depth));
			float top = 0.18 + 0.12 * (1.0 - depth) + ridge(x, 2.0 + fi * 2.5, fi * 13.0) * (0.10 + 0.06 * fi);
			float hill = 1.0 - smoothstep(top - 0.004, top + 0.004, h);
			vec3 c = mix(land.rgb, sky, clamp(depth * (0.35 + 0.6 * haze), 0.0, 0.95));
			col = mix(col, c, hill);
		}
	}
	// Night: the horizon goes, only a faint sky glow stays.
	vec3 dark = vec3(0.035, 0.04, 0.05) + sky_low.rgb * 0.04 * h;
	col = mix(col, dark, night * 0.92);
	// Lightning lights the sky part only.
	col += fx_flash * 0.5 * smoothstep(0.2, 0.7, h) * vec3(0.8, 0.82, 0.86);
	ALBEDO = fx_photo(col, fx_fade);
}
