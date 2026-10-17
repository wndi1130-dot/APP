shader_type canvas_item;
// The film's grain over the world (k3_views.js .w-grain): the mockup's noise
// tile (`tile_px`, game px) laid over what is drawn under it as a browser's
// mix-blend-mode: overlay lays it, at `opacity`. The blend's result goes out
// with the tile's own alpha, so plain alpha blending finishes the CSS sum
// (1 − a) · under + a · overlay(under, grain).

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D grain : repeat_enable, filter_linear;
uniform vec2 rect_px = vec2(1.0);
uniform float tile_px = 160.0;
uniform float opacity = 0.55;

void fragment() {
	vec3 under = texture(screen_tex, SCREEN_UV).rgb;
	vec4 g = texture(grain, UV * rect_px / tile_px);
	vec3 lo = 2.0 * under * g.rgb;
	vec3 hi = 1.0 - 2.0 * (1.0 - under) * (1.0 - g.rgb);
	COLOR = vec4(mix(lo, hi, step(vec3(0.5), under)), g.a * opacity);
}
