shader_type spatial;
render_mode cull_back;

uniform sampler2D vat : filter_nearest, repeat_disable;
// Wide meshes fold each frame into several texture rows; UV2.y is the block.
uniform float rows_per_frame = 1.0;
const float FRAMES = 32.0;

void vertex() {
	float clip = step(0.5, INSTANCE_CUSTOM.g);
	float frame = mod(TIME * mix(7.0, 11.0, clip) + INSTANCE_CUSTOM.r * FRAMES, FRAMES);
	float current = floor(frame);
	float next = mod(current + 1.0, FRAMES);
	float height = FRAMES * 2.0 * rows_per_frame;
	float row_a = ((clip * FRAMES + current) * rows_per_frame + UV2.y + 0.5) / height;
	float row_b = ((clip * FRAMES + next) * rows_per_frame + UV2.y + 0.5) / height;
	vec3 a = texture(vat, vec2(UV2.x, row_a)).rgb - vec3(0.5);
	vec3 b = texture(vat, vec2(UV2.x, row_b)).rgb - vec3(0.5);
	VERTEX += mix(a, b, fract(frame));
}

void fragment() {
	ALBEDO = vec3(0.52);
	ROUGHNESS = 1.0;
}
