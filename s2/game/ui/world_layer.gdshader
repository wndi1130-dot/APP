shader_type canvas_item;
// One layer of the weather the mockup lays over its world (k3_views.js
// .w-snow, .w-fogB, .w-drift): its texture tiled `tile_px` from `start_px`
// (CSS background-position), sliding `speed_px` a second, at `opacity`.
// Sizes in game px; `still` 1 holds it at its start (screens for checks).

uniform sampler2D tex : repeat_enable, filter_linear;
uniform vec2 rect_px = vec2(1.0);
uniform vec2 tile_px = vec2(400.0);
uniform vec2 start_px = vec2(0.0);
uniform vec2 speed_px = vec2(0.0);
uniform float opacity = 1.0;
uniform float still = 0.0;

void fragment() {
	vec2 at = start_px + speed_px * TIME * (1.0 - still);
	vec4 c = texture(tex, (UV * rect_px - at) / tile_px);
	COLOR = vec4(c.rgb, c.a * opacity);
}
