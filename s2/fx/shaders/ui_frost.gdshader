shader_type canvas_item;
// Frost growing in from a control's edges (cold car panels, the portrait rim
// when someone is cold). Grey-white rime, not sky blue (decisions.md 날씨와 빛).
// Draw it on a ColorRect over the panel's frame; keep text out of its reach
// by limiting `amount` (0.5 stops about a quarter of the way in).
#include "res://fx/shaders/fx_common.gdshaderinc"

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 rime : source_color = vec4(0.74, 0.76, 0.78, 1.0);
uniform vec2 rect_aspect = vec2(1.0, 1.0);
uniform float seed = 0.0;

void fragment() {
	vec2 a = UV * rect_aspect;
	vec2 e2 = min(a, rect_aspect - a);
	float edge = min(e2.x, e2.y) / (0.5 * min(rect_aspect.x, rect_aspect.y));
	float n = fx_fbm2(a * 8.0 + seed);
	float fern = fx_crystal(a * 14.0 + seed * 3.0);
	float reach = amount * 0.55;
	float f = amount > 0.001 ? 1.0 - smoothstep(reach - 0.05, reach + 0.05, edge + (n - 0.5) * 0.25) : 0.0;
	f *= 0.6 + 0.4 * fern;
	COLOR = vec4(rime.rgb * (0.9 + 0.1 * fern), clamp(f, 0.0, 0.92) * COLOR.a);
}
