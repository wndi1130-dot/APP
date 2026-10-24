shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Compact camera-facing drops, shards, snow dust and sideways vapour.
// No scene colour/depth sampling and no dynamic light.
uniform int style = 0; // blood, spark, wood, glass, muzzle, snow, vapour

void vertex() {
	vec3 dimensions = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX[0].xyz *= dimensions.x;
	MODELVIEW_MATRIX[1].xyz *= dimensions.y;
	MODELVIEW_MATRIX[2].xyz *= dimensions.z;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float mask = 1.0 - smoothstep(0.55, 1.0, length(p * vec2(1.0, 0.8)));
	if (style == 1) {
		mask = (1.0 - smoothstep(0.08, 0.3, abs(p.x))) * (1.0 - abs(p.y));
	} else if (style == 2) {
		mask = step(abs(p.x + p.y * 0.2), 0.23) * step(abs(p.y), 0.9);
	} else if (style == 3) {
		mask = step(abs(p.x), (1.0 - p.y) * 0.42) * step(-0.8, p.y);
	} else if (style == 4) {
		float rays = 0.4 + 0.4 * pow(abs(cos(atan(p.y, p.x) * 3.0)), 5.0);
		mask = 1.0 - smoothstep(rays * 0.6, rays, length(p));
	} else if (style >= 5) {
		mask = pow(max(0.0, 1.0 - dot(p, p)), 2.0);
	}
	if (mask < 0.025) { discard; }
	// Particle colours arrive as sRGB values; the spatial shader works in linear.
	vec3 c = pow(max(COLOR.rgb, vec3(0.0)), vec3(2.2));
	ALBEDO = c;
	EMISSION = (style == 1 || style == 4) ? c * 0.7 : vec3(0.0);
	ALPHA = mask * COLOR.a;
}
