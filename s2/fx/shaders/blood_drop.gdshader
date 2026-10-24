shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, skip_vertex_transform;
// Flying blood: each drop is a streak along its own velocity as the camera
// sees it; a puff is a soft round cloud that spreads and fades.
// INSTANCE_CUSTOM: xyz velocity (m/s), w radius in metres (negative = puff).
// COLOR: sRGB colour and alpha. No light, no screen or depth reads.

// How much a drop stretches per m/s of on-screen speed, and the most it may.
uniform float stretch = 0.45;
uniform float max_stretch = 2.0;

varying float puff;

void vertex() {
	vec3 center = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	float radius = abs(INSTANCE_CUSTOM.w);
	puff = INSTANCE_CUSTOM.w < 0.0 ? 1.0 : 0.0;
	vec2 v = (VIEW_MATRIX * vec4(INSTANCE_CUSTOM.xyz, 0.0)).xy;
	float speed = length(v);
	vec2 d = speed > 0.001 ? v / speed : vec2(1.0, 0.0);
	vec2 n = vec2(-d.y, d.x);
	// A drop stretches up to three times its width with speed; a puff stays round.
	float len = radius * (1.0 + (1.0 - puff) * min(speed * stretch, max_stretch));
	vec2 offs = d * VERTEX.x * 2.0 * len + n * VERTEX.y * 2.0 * radius;
	VERTEX = center + vec3(offs, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float mask;
	if (puff > 0.5) {
		float wob = 0.75 + 0.25 * sin(atan(p.y, p.x) * 5.0 + UV.x * 3.0);
		mask = (1.0 - smoothstep(0.2 * wob, 0.95 * wob, length(p))) * 0.8;
	} else {
		// Round head, thinner tail behind it.
		float w = mix(0.55, 1.0, smoothstep(-1.0, 0.6, p.x));
		mask = 1.0 - smoothstep(0.55 * w, 0.95 * w, length(vec2(p.x, p.y / max(w, 0.2))));
	}
	if (mask * COLOR.a < 0.02) {
		discard;
	}
	ALBEDO = pow(max(COLOR.rgb, vec3(0.0)), vec3(2.2));
	ALPHA = mask * COLOR.a;
}
