// A baked body drawn from its motion picture (scripts/vat_baker.gd), shared by
// dead_vat.gdshader (the dead, the train's people) and person_vat.gdshader
// (the field's living, WORN defined: what they wear over the body and on their hands).
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
// Seconds the field has stood paused (pause_veil.gd): the motions run on TIME - fx_still, so they hold.
global uniform float fx_still;
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
#ifdef WORN
// The two below are off but where game/actors/person_visual.gd turns them on, so
// the dead and the train's people are drawn as before. Both read the
// multimesh's own colour of each body (Godot gives it times the vertex colour).
// A garment over the body in the look of the one worn (decision 434): rgb its
// colour, as tint is (linear), alpha its pattern, 0 plain, 1/3 check, 2/3 knit,
// 1 quilt, laid on the cloth where it rests so it moves with it.
uniform bool worn_look = false;
// Gloves painted over the colour picture before it is pressed: the body's
// vertex colour marks its hands (alpha 1, scripts/body_bake.gd hand_marks), the
// instance colour says the gloves (rgb linear, as the picture would hold them;
// alpha 1 gloved, 0 bare). They keep half the picture's own light and dark
// against glove_light, the picture's light at the hands (body_bake.gd GLOVE_GRAIN).
uniform bool gloves = false;
uniform float glove_light = 0.45;
#endif

varying float shade;
varying vec3 view_pos;
#ifdef WORN
varying vec4 worn;
varying vec3 rest;
varying vec3 rest_normal;
#endif

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
	float looped = mod((TIME - fx_still) * speed + INSTANCE_CUSTOM.r * frames, frames);
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
#ifdef WORN
	rest = VERTEX;
	rest_normal = NORMAL;
#endif
	VERTEX += offset;
	// The cold's tremble: quick and small, from the hips up, more toward the head, each body at its own phase.
	VERTEX.xz += shiver * clamp((VERTEX.y - 0.55) / 0.7, 0.0, 1.0) * 0.05 * vec2(sin((TIME - fx_still) * 59.0 + INSTANCE_CUSTOM.r * 41.0), sin((TIME - fx_still) * 47.0 + INSTANCE_CUSTOM.r * 29.0) * 0.6);
	shade = INSTANCE_CUSTOM.a;
	view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
#ifdef WORN
	worn = COLOR;
#endif
}

#ifdef WORN
// How much of [x - w/2, x + w/2] is in the bands of a stripe of period 1 that
// are `d` wide: the stripe seen through one pixel, so a fine one fades to its
// share instead of shimmering.
float band_sum(float x, float d) {
	return floor(x) * d + max(fract(x) - (1.0 - d), 0.0);
}

float band(float x, float d, float w) {
	w = max(w, 0.0001);
	return (band_sum(x + 0.5 * w, d) - band_sum(x - 0.5 * w, d)) / w;
}

// One of the patterns on a plane of the cloth (metres; w how much of it a pixel
// spans): 1 is the garment's own colour, below it darker.
float pattern_on(int kind, vec2 p, vec2 w) {
	if (kind == 1) {
		// Check: two ways of dark bands 9 cm apart, darkest where they cross.
		vec2 c = p / 0.09;
		vec2 cw = w / 0.09;
		return 1.0 - 0.16 * band(c.x, 0.35, cw.x) - 0.16 * band(c.y, 0.35, cw.y);
	}
	if (kind == 2) {
		// Knit: ribs down the cloth 2.5 cm apart, and rows across it.
		return 1.0 - 0.12 * band(p.x / 0.025, 0.5, w.x / 0.025) - 0.05 * band(p.y / 0.012, 0.5, w.y / 0.012);
	}
	if (kind == 3) {
		// Quilt: diamonds sewn 11 cm apart, the seams sunk, each cell puffed up.
		vec2 d = vec2(p.x + p.y, p.x - p.y) / 0.11;
		float dw = (w.x + w.y) / 0.11;
		float seams = max(band(d.x, 0.14, dw), band(d.y, 0.14, dw));
		float puff = 1.0 - abs(fract(d.x) - 0.5) - abs(fract(d.y) - 0.5);
		return 1.0 - 0.22 * seams + 0.05 * puff * (1.0 - clamp(dw * 2.0, 0.0, 1.0));
	}
	return 1.0;
}

// The pattern laid on the cloth from three sides as it rests, by which way it faces.
float pattern_at(int kind, vec3 p, vec3 n, vec3 w) {
	if (kind == 0) {
		return 1.0;
	}
	vec3 k = pow(abs(normalize(n)), vec3(4.0));
	k /= max(k.x + k.y + k.z, 0.0001);
	return k.x * pattern_on(kind, p.zy, w.zy) + k.y * pattern_on(kind, p.xz, w.xz) + k.z * pattern_on(kind, p.xy, w.xy);
}
#endif

void fragment() {
	if (flat_normals) {
		NORMAL = normalize(cross(dFdy(view_pos), dFdx(view_pos)));
	}
	vec3 base = tint;
#ifdef WORN
	vec3 cloth = fwidth(rest);           // outside the branches: derivatives want every pixel
	if (worn_look) {
		base = worn.rgb * pattern_at(int(worn.a * 3.0 + 0.5), rest, rest_normal, cloth);
	}
#endif
	if (has_albedo) {
		vec3 picture = texture(albedo_tex, UV).rgb;
#ifdef WORN
		if (gloves && worn.a > 0.2) {
			float light = pow(max(dot(picture, vec3(0.2126, 0.7152, 0.0722)), 0.0), 1.0 / 2.2);
			float grain = mix(1.0, clamp(light / max(glove_light, 0.05), 0.5, 1.5), 0.5);
			picture = mix(picture, worn.rgb * pow(grain, 2.2), smoothstep(0.2, 0.4, worn.a));
		}
#endif
		vec3 c = fx_model_grade(picture, grade_saturation, grade_value, grade_cool, grade_cool_mix);
		base = c * (tint / 0.5);
	}
	ALBEDO = base * shade;
	ROUGHNESS = 1.0;
}
