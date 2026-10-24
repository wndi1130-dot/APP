shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// A flat glass triangle; no refraction or scene texture read.
uniform vec3 tint : source_color = vec3(0.48, 0.55, 0.56);
uniform float opacity : hint_range(0.0, 1.0) = 0.62;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	if (abs(p.x) > (1.0 - p.y) * 0.42 || p.y < -0.8) { discard; }
	ALBEDO = tint;
	ALPHA = opacity;
}
