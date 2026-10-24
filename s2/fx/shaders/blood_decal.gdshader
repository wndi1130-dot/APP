shader_type spatial;
render_mode cull_disabled, depth_draw_never;
// Attached body/clothing marks. Decal3D uses the matching CPU-generated mask
// in blood_fx.gd because Decal has texture inputs, not a ShaderMaterial slot.
uniform float pattern_seed = 1.0;
uniform float dry : hint_range(0.0, 1.0) = 0.0;
uniform float snow : hint_range(0.0, 1.0) = 0.0;
uniform int mark_kind = 0; // stain, bite, scratch
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float angle = atan(p.y, p.x);
	float rim = 0.56 + sin(angle * 3.0 + pattern_seed * 0.73) * 0.10 + sin(angle * 7.0 + pattern_seed * 1.17) * 0.06;
	float mask = 1.0 - smoothstep(rim - 0.06, rim + mix(0.03, 0.18, snow), length(p));
	for (int i = 0; i < 4; i++) {
		float a = pattern_seed * 0.7 + float(i) * 2.4;
		vec2 dot_pos = vec2(cos(a), sin(a)) * 0.77;
		mask = max(mask, 1.0 - smoothstep(0.025, 0.08 + snow * 0.04, length(p - dot_pos)));
	}
	if (mark_kind == 1) {
		float ring = abs(length(p * vec2(1.0, 1.4)) - 0.55);
		mask = (1.0 - smoothstep(0.04, 0.13, ring)) * step(0.1, abs(p.y)) * step(0.1, sin(angle * 10.0));
	} else if (mark_kind == 2) {
		float cut = abs(abs(p.y + p.x * 0.22) - 0.25);
		cut = min(cut, abs(p.y + p.x * 0.22));
		mask = (1.0 - smoothstep(0.025, 0.065, cut)) * (1.0 - smoothstep(0.5, 0.85, abs(p.x)));
	}
	if (mask < 0.025) { discard; }
	// Same sRGB colours as BloodFx.FRESH and DRIED, converted to linear.
	ALBEDO = pow(mix(vec3(0.23, 0.07, 0.055), vec3(0.17, 0.075, 0.055), dry), vec3(2.2));
	ROUGHNESS = mix(0.38, 0.96, dry);
	ALPHA = mask * opacity;
}
