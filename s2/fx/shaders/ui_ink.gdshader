shader_type canvas_item;
// Ink soaking into paper (cards, bills, the log) for panels and buttons.
// Reveal rule from research ui-motion (implementation.md 2장):
//   q = distance from the touch + large noise + small fibre noise
//   alpha = 1 - smoothstep(p - w, p + w, q)
// A darker fringe rides just inside the front and dries to a faint line.
// Put it on the panel background only: text, numbers and portraits sit in
// child nodes and never bleed (presentation_motion.md 하지 않을 것).
#include "res://fx/shaders/fx_common.gdshaderinc"

uniform float progress : hint_range(0.0, 1.0) = 1.0;
// Where the ink starts, in the control's UV (the touch point, or an edge).
uniform vec2 origin = vec2(0.5, 0.5);
uniform float width : hint_range(0.005, 0.2) = 0.03;
uniform float fringe : hint_range(0.0, 0.3) = 0.09;
uniform vec4 ink : source_color = vec4(0.07, 0.065, 0.06, 1.0);
uniform float fringe_strength : hint_range(0.0, 1.0) = 0.7;
// Same seed every time for one control, so a reversed transition never jumps.
uniform float seed = 0.0;
uniform vec2 rect_aspect = vec2(1.0, 1.0);

void fragment() {
	vec4 src = texture(TEXTURE, UV) * COLOR;
	vec2 a = UV * rect_aspect;
	vec2 o = origin * rect_aspect;
	float maxd = length(max(o, rect_aspect - o));
	float big = fx_fbm2(a * 3.0 + seed * 7.3) - 0.5;
	float fibre = fx_vnoise(vec2(a.x * 70.0, a.y * 9.0) + seed) - 0.5;
	float q = distance(a, o) / maxd + big * 0.35 + fibre * 0.06;
	// Map progress so 0 shows nothing and 1 shows everything.
	float p = mix(-0.25 - width, 1.25 + width, progress);
	float alpha = 1.0 - smoothstep(p - width, p + width, q);
	float band = alpha * smoothstep(p - fringe, p, q);
	// A finished reveal keeps a faint dried edge where the front stopped.
	vec3 col = mix(src.rgb, ink.rgb, band * fringe_strength);
	COLOR = vec4(col, src.a * alpha);
}
