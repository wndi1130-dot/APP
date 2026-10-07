shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

// Low-resolution sight mask: one texel per metre cell (R = seen now, G = seen before).
uniform sampler2D vis : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(120.0, 70.0);
uniform float mask_on = 1.0;
uniform float frost = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = COLOR.rgb;
	vec2 uv = world_pos.xz / map_size;
	vec2 seen = texture(vis, uv).rg;
	// Seen now: full. Seen before: dim memory. Never seen: dark but readable.
	float lit = mix(1.0, max(seen.r, seen.g * 0.3 + 0.24), mask_on);
	float grey = dot(base, vec3(0.3, 0.59, 0.11));
	vec3 dimmed = mix(vec3(grey), base, seen.r * 0.6 + 0.4);
	ALBEDO = mix(dimmed, vec3(0.86, 0.88, 0.9), frost) * lit;
	ROUGHNESS = 1.0;
}
