shader_type spatial;
// A warm pool of light on the floor under a car's hanging lamp (train_scene.gd, 코디 10-30:
// the lamp reads as a lamp). Added over the floor, brightest under the lamp and gone at the
// quad's edge; the lamp's colour and strength come per car as instance uniforms.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

instance uniform vec4 pool_color : source_color = vec4(1.0, 0.72, 0.42, 1.0);
instance uniform float pool_strength = 0.0;

void fragment() {
	vec2 d = (UV - vec2(0.5)) * vec2(2.0, 2.0);
	float r = length(d);
	float fall = clamp(1.0 - r, 0.0, 1.0);
	ALBEDO = pool_color.rgb * fall * fall * pool_strength;
}
