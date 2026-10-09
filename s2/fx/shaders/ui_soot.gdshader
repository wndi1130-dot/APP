shader_type canvas_item;
// Coal soot blooming up behind enamel and brass gauges (presentation_motion.md
// 재질별 얼룩: the metal rim never bleeds, soot rises from behind it).
// Draw it on a ColorRect placed behind the gauge. amount 0 hides it.
#include "res://fx/shaders/fx_common.gdshaderinc"

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 soot : source_color = vec4(0.07, 0.065, 0.06, 1.0);
uniform float rise_speed = 0.08;
uniform float seed = 0.0;

void fragment() {
	vec2 uv = UV;
	vec2 from = vec2(0.5, 1.0); // rises from the bottom middle
	float n = fx_fbm2(vec2(uv.x * 4.0 + seed, uv.y * 3.0 + TIME * rise_speed));
	float wisp = fx_vnoise(vec2(uv.x * 11.0 - seed, uv.y * 7.0 + TIME * rise_speed * 1.7));
	float reach = amount * 1.15;
	float d = distance(uv * vec2(1.4, 1.0), from * vec2(1.4, 1.0));
	float body = 1.0 - smoothstep(reach - 0.25, reach, d + (n - 0.5) * 0.35);
	float a = body * (0.55 + 0.45 * wisp) * amount;
	COLOR = vec4(soot.rgb, clamp(a, 0.0, 0.9) * COLOR.a);
}
