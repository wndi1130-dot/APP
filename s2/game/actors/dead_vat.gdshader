shader_type spatial;
render_mode cull_back;

// VAT layout from scripts/vat_baker.gd. INSTANCE_CUSTOM:
// r = phase, g = clip number, b = 1 stops the animation, a = shade.
// Clips stack downward in the texture; the four tables say where each one
// starts, how many frames it has, how fast it runs and whether it loops.
// Tables left unset mean the box bake: 0 wander and 1 chase, 32 frames each.
// A clip that does not loop reads r as its progress (0 start .. 1 end), so
// the rule clock picks the frame and TIME is not used.
// g may carry more than the clip (game/actors/dead_body.gd, mixed): the frame
// a body was in when it changed to this clip and how much of that it still
// keeps, g = clip + 16 * frame + 65536 * share (share 0..63). A plain clip
// number reads as before: no frame, no share.
uniform sampler2D vat : filter_nearest, repeat_disable;
uniform float rows_per_frame = 1.0;
uniform float frame_rows = 64.0;
uniform float clip_start[16];
uniform float clip_frames[16];
uniform float clip_rate[16];
uniform float clip_loop[16];
// Box bake stores offset + 0.5 in 8 bits; a skinned bake stores metres (bias 0).
uniform float bias = 0.5;
uniform vec3 tint = vec3(0.5);
// The bake moves vertices only, so a lying body keeps its standing normals.
// On, the face normal is taken from the moved surface instead. Off until it
// has been timed on the phone.
uniform bool flat_normals = false;
// On for a baked body: one more look at the picture while a body changes
// motion. Not timed on the phone.
uniform bool mixes = false;

varying float shade;
varying vec3 view_pos;

void vertex() {
	float packed = floor(INSTANCE_CUSTOM.g + 0.5);
	float share = floor(packed / 65536.0);
	float kept = floor((packed - share * 65536.0) / 16.0);
	int clip = int(packed - share * 65536.0 - kept * 16.0 + 0.5);
	float frames = clip_frames[clip];
	float start = clip_start[clip];
	float rate = clip_rate[clip];
	float loops = clip_loop[clip];
	if (frames < 0.5) {
		frames = 32.0;
		start = float(clip) * 32.0;
		rate = mix(7.0, 11.0, float(clip));
		loops = 1.0;
	}
	// Each body walks at its own pace (0.82..1.18), from its own number.
	float pace = mix(0.82, 1.18, fract(INSTANCE_CUSTOM.r * 7.31));
	float speed = rate * pace * (1.0 - INSTANCE_CUSTOM.b);
	float looped = mod(TIME * speed + INSTANCE_CUSTOM.r * frames, frames);
	float once = clamp(INSTANCE_CUSTOM.r, 0.0, 1.0) * (frames - 1.0);
	float frame = mix(once, looped, loops);
	float current = floor(frame);
	float next = mix(min(current + 1.0, frames - 1.0), mod(current + 1.0, frames), loops);
	float height = frame_rows * rows_per_frame;
	float row_a = ((start + current) * rows_per_frame + UV2.y + 0.5) / height;
	float row_b = ((start + next) * rows_per_frame + UV2.y + 0.5) / height;
	vec3 a = texture(vat, vec2(UV2.x, row_a)).rgb - vec3(bias);
	vec3 b = texture(vat, vec2(UV2.x, row_b)).rgb - vec3(bias);
	vec3 offset = mix(a, b, fract(frame));
	if (mixes && share > 0.5) {
		float row_c = (kept * rows_per_frame + UV2.y + 0.5) / height;
		offset = mix(offset, texture(vat, vec2(UV2.x, row_c)).rgb - vec3(bias), share / 63.0);
	}
	VERTEX += offset;
	shade = INSTANCE_CUSTOM.a;
	view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (flat_normals) {
		NORMAL = normalize(cross(dFdy(view_pos), dFdx(view_pos)));
	}
	ALBEDO = tint * shade;
	ROUGHNESS = 1.0;
}
