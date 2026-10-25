shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// The shade under the side path's trees (fx/woods_shade.gd): a sheet a hair over the
// ground that multiplies what is drawn under it. Vertex alpha is how much of the
// ground's light the trees take there; whatever stands on the ground is over it.

uniform float strength = 1.0; // 0 none .. 1 the full shade

void fragment() {
	ALBEDO = vec3(1.0 - clamp(COLOR.a * strength, 0.0, 1.0));
}
