shader_type spatial;
render_mode cull_back;
#include "res://fx/shaders/fx_common.gdshaderinc"

// VAT layout from scripts/vat_baker.gd. INSTANCE_CUSTOM:
// r = phase, g = clip number, b = 1 stops the animation, a = shade. b below 0
// is a tremble of the cold (the train's people, -0.5 at most) and stops nothing.
// Clips stack downward in the texture; the four tables say where each one
// starts, how many frames it has, how fast it runs and whether it loops.
// Tables left unset mean the box bake: 0 wander and 1 chase, 32 frames each.
// A clip that does not loop reads r as its progress (0 start .. 1 end), so
// the rule clock picks the frame and TIME is not used.
// g may carry more than the clip (game/actors/dead_body.gd, mixed): the frame
// a body was in when it changed to this clip and how much of that it still
// keeps, g = clip + 16 * frame + 65536 * share (share 0..31). A plain clip
// number reads as before: no frame, no share. Clips 16 and up carry 2097152
// more for each sixteen (16..31 once, 32..47 twice, up to 112..127 seven
// times) and are written as clip % 16 (scripts/vat_baker.gd pack_motion), so
// every g below 2097152 reads exactly as it did with sixteen places; 127 with
// every frame and share is 2^24 - 1, the most a float carries whole.
uniform sampler2D vat : filter_nearest, repeat_disable;
uniform float rows_per_frame = 1.0;
uniform float frame_rows = 64.0;
uniform float clip_start[128];
uniform float clip_frames[128];
uniform float clip_rate[128];
uniform float clip_loop[128];
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
// A compacted bake (scripts/body_bake.gd compact) keeps 8 bits a channel
// inside each clip's own box; the picture's 0..1 goes back to lo..hi.
uniform bool quantized = false;
uniform vec3 clip_lo[128];
uniform vec3 clip_hi[128];
// A baked body that brings its own colour picture (models/people/<body>/albedo.png)
// is drawn with it, pressed like every other model (fx_model_grade, the user's
// values of 2026-10-17); tint then only shifts it (tint / 0.5, so 0.5 leaves it).
// Without one the body is tint alone, as before.
uniform bool has_albedo = false;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float grade_saturation : hint_range(0.0, 1.0) = 0.45;
uniform float grade_value : hint_range(0.0, 1.0) = 0.82;
uniform vec3 grade_cool : source_color = vec3(0.78, 0.85, 0.95);
uniform float grade_cool_mix : hint_range(0.0, 1.0) = 0.35;

varying float shade;
varying vec3 view_pos;

vec3 offset_at(float x, float row, int clip) {
	vec3 v = texture(vat, vec2(x, row)).rgb;
	if (quantized) {
		v = clip_lo[clip] + v * (clip_hi[clip] - clip_lo[clip]);
	}
	return v - vec3(bias);
}

// The clip a frame row belongs to (for the frame a body keeps while it changes motion).
int clip_of(float frame) {
	for (int n = 0; n < 128; n++) {
		if (frame >= clip_start[n] && frame < clip_start[n] + clip_frames[n]) {
			return n;
		}
	}
	return 0;
}

void vertex() {
	// g is a whole number; above 2^23 a float has no halves, so adding 0.5 would
	// round an odd one up to the next clip (clips 32 and on). round() keeps it.
	float packed = round(INSTANCE_CUSTOM.g);
	float upper = floor(packed / 2097152.0);
	packed -= upper * 2097152.0;
	float share = floor(packed / 65536.0);
	float kept = floor((packed - share * 65536.0) / 16.0);
	int clip = int(packed - share * 65536.0 - kept * 16.0 + 0.5) + 16 * int(upper);
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
	float hold = max(INSTANCE_CUSTOM.b, 0.0);
	float shiver = max(-INSTANCE_CUSTOM.b, 0.0);
	float speed = rate * pace * (1.0 - hold);
	float looped = mod(TIME * speed + INSTANCE_CUSTOM.r * frames, frames);
	float once = clamp(INSTANCE_CUSTOM.r, 0.0, 1.0) * (frames - 1.0);
	float frame = mix(once, looped, loops);
	float current = floor(frame);
	float next = mix(min(current + 1.0, frames - 1.0), mod(current + 1.0, frames), loops);
	float height = frame_rows * rows_per_frame;
	float row_a = ((start + current) * rows_per_frame + UV2.y + 0.5) / height;
	float row_b = ((start + next) * rows_per_frame + UV2.y + 0.5) / height;
	vec3 a = offset_at(UV2.x, row_a, clip);
	vec3 b = offset_at(UV2.x, row_b, clip);
	vec3 offset = mix(a, b, fract(frame));
	if (mixes && share > 0.5) {
		float row_c = (kept * rows_per_frame + UV2.y + 0.5) / height;
		offset = mix(offset, offset_at(UV2.x, row_c, quantized ? clip_of(kept) : clip), share / 31.0);
	}
	VERTEX += offset;
	// The cold's tremble: quick and small, from the hips up, more toward the head, each body at its own phase.
	VERTEX.xz += shiver * clamp((VERTEX.y - 0.55) / 0.7, 0.0, 1.0) * 0.05 * vec2(sin(TIME * 59.0 + INSTANCE_CUSTOM.r * 41.0), sin(TIME * 47.0 + INSTANCE_CUSTOM.r * 29.0) * 0.6);
	shade = INSTANCE_CUSTOM.a;
	view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (flat_normals) {
		NORMAL = normalize(cross(dFdy(view_pos), dFdx(view_pos)));
	}
	vec3 base = tint;
	if (has_albedo) {
		vec3 c = fx_model_grade(texture(albedo_tex, UV).rgb, grade_saturation, grade_value, grade_cool, grade_cool_mix);
		base = c * (tint / 0.5);
	}
	ALBEDO = base * shade;
	ROUGHNESS = 1.0;
}
