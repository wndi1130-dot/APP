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
#ifdef FADED
// The train's people while a car is decorated (people_faded.gdshader): seen, but through.
uniform float fade : hint_range(0.0, 1.0) = 0.0;
#endif
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
#ifdef WEATHERED
// The dead: which texels of the colour picture are skin (models/people/<body>/skin_mask.png, made by
// tools/dead_skin_mask.py from the rigged source: head, neck, hands and bare forearms, by colour inside
// them). With it only the skin goes grey-green and takes the state's tint; the clothes keep their own
// colour and take the state only by cloth_state (dead_cast.gd CLOTH_STATE, the garments over them alike).
// Without it the whole picture is tinted, as before.
uniform bool has_skin = false;
uniform sampler2D skin_tex : filter_linear, repeat_enable, hint_default_black;
uniform float cloth_state : hint_range(0.0, 1.0) = 0.25;
// How much of the look's colour the skin takes, the rest only its darkness (dead_cast.gd SKIN_TINT).
uniform float skin_tint : hint_range(0.0, 1.0) = 1.0;
#endif
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
#ifdef WEATHERED
// The field's dead (dead_weathered.gdshader, zombies.gd): how worn each one is,
// in the multimesh's own colour of it (Godot gives it times the vertex colour,
// whose rgb is 1): r blood, g dirt, b how far the skin has gone off, each 0..1.
// Where on the body, by its resting place: blood on the front of the chest and
// at the mouth and on the hands (the vertex colour's alpha marks them), dirt
// from the feet up, the skin by its colour (warm and light is skin), each in
// patches by the colour picture's own place, so they hold on the body as it moves.
varying vec4 tear;
varying vec2 tear_at;    // x how high it rests (0 feet .. 1 crown), y 1 on the front
#endif

varying float shade;
varying vec3 view_pos;
// 1 in a motion on the ground (falls, the crawl, getting up, eating; vat_baker.gd shader_tables marks
// them in clip_loop as 2 more): its normals are taken from the moved surface (see flat_normals).
varying float lying;
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
	float loop_code = clip_loop[clip];   // 1 loops, + 2 on the ground
	float loops = mod(loop_code, 2.0);
	lying = step(1.5, loop_code);
	if (frames < 0.5) {
		frames = 32.0;
		start = float(clip) * 32.0;
		rate = mix(7.0, 11.0, float(clip));
		loops = 1.0;
		lying = 0.0;
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
		int was = clip_of(kept);
		offset = mix(offset, offset_at(UV2.x, row_c, quantized ? was : clip), share / 31.0);
		// Still mostly in a motion on the ground it left (eating, then struck): lit by its moved surface.
		lying = max(lying, step(1.5, clip_loop[was]) * step(15.5, share));
	}
#ifdef WORN
	rest = VERTEX;
	rest_normal = NORMAL;
#endif
#ifdef WEATHERED
	tear = COLOR;
	tear_at = vec2(clamp(VERTEX.y / 1.7, 0.0, 1.0), step(0.0, VERTEX.z));
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

#ifdef WEATHERED
// Smooth noise on the colour picture's place (0..1), for patches that stay put on the body.
float tear_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// The colour picture (linear) of one of the dead as worn as `worn_as` says, at
// `uv`, `worn_at` where on the body (the varyings, passed in); `skin_in` how much
// of it is skin (the skin mask), below 0 where the body has no mask.
// SKIN_OFF: what gone-off skin is, times its own light: a faintly green grey (tools/dead_skin_split.py
// checks it against the living: the dead under 0.6 of their saturation or 0.04, 60..160 degrees; the
// newly risen no more saturated and 10 degrees greener). SKIN_GONE: how far by the kind's b
// (dead_cast.gd TEAR), from SKIN_GONE_LEAST for the newly risen to all of it for the long dead.
const vec3 SKIN_OFF = vec3(0.768, 0.8, 0.608);
const vec2 SKIN_GONE = vec2(0.1, 0.45);
const float SKIN_GONE_LEAST = 0.82;
// SKIN_EDGE: the mask read through a smooth step, so skin is wholly skin inside and the soft rim
// (128 x 128, filtered) stays a rim, not a half-gone face.
const vec2 SKIN_EDGE = vec2(0.15, 0.5);
// A light red cloth on the head (a hood; the skin mask's green, dead_skin_mask.py): the grade presses
// it pink, a bare living head on the dead, so it becomes a dark adzuki red-brown, its own folds kept
// (HEAD_CLOTH the colour for a light of 1, HEAD_CLOTH_DIM how dark).
const vec3 HEAD_CLOTH = vec3(2.03, 0.73, 0.63);
const float HEAD_CLOTH_DIM = 0.45;
vec3 worn_down(vec3 picture, vec2 uv, vec4 worn_as, vec2 worn_at, float skin_in) {
	float n = tear_noise(uv * 40.0) * 0.65 + tear_noise(uv * 110.0) * 0.35;
	float light = dot(picture, vec3(0.2126, 0.7152, 0.0722));
	// Skin gone off: grey-olive, darker than it was and blotched, so a light face under a dark hood
	// reads as dead skin, not a white mask (without a mask: what is warm and light).
	float skin = skin_in >= 0.0 ? skin_in : clamp((picture.r - picture.b) * 7.0 - 0.25, 0.0, 1.0) * smoothstep(0.02, 0.09, light);
	vec3 off = vec3(light) * SKIN_OFF;
	float gone = mix(SKIN_GONE_LEAST, 1.0, smoothstep(SKIN_GONE.x, SKIN_GONE.y, worn_as.b));
	picture = mix(picture, off * (1.0 - 0.5 * n), gone * skin);
	// Dirt from the feet up, in patches.
	float low = 1.0 - smoothstep(0.12, 0.55, worn_at.x);
	float dirt = worn_as.g * clamp(low * 0.9 + (n - 0.55) * 1.6, 0.0, 1.0);
	return mix(picture, picture * vec3(0.52, 0.47, 0.4), dirt);
}

// How much blood is on it there (0..1): down the front from the mouth, in
// patches, and on the hands. Laid on after the picture is pressed, so it keeps
// its own dark red where the press would turn it brown.
float bled(vec2 uv, vec4 worn_as, vec2 worn_at) {
	float n = tear_noise(uv * 40.0 + vec2(17.0, 5.0)) * 0.65 + tear_noise(uv * 110.0) * 0.35;
	float chest = smoothstep(0.62, 0.74, worn_at.x) * (1.0 - smoothstep(0.9, 0.95, worn_at.x)) * worn_at.y;
	return worn_as.r * clamp(chest * smoothstep(0.3, 0.6, n) * 1.3 + worn_as.a * 0.9, 0.0, 1.0);
}
const vec3 DRIED_BLOOD = vec3(0.075, 0.012, 0.01);
#endif

void fragment() {
	// The face of the moved surface, outside any branch (derivatives want every pixel); used switched on,
	// or in a motion on the ground, where the standing normals would light the body as if upright.
	vec3 face = cross(dFdy(view_pos), dFdx(view_pos));
	if ((flat_normals || lying > 0.5) && dot(face, face) > 1e-14) {
		NORMAL = normalize(face);
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
#ifdef WEATHERED
		vec2 mask_here = has_skin ? texture(skin_tex, UV).rg : vec2(-1.0, 0.0);
		float skin_here = has_skin ? smoothstep(SKIN_EDGE.x, SKIN_EDGE.y, mask_here.r) : -1.0;
		picture = mix(picture, HEAD_CLOTH * (dot(picture, vec3(0.2126, 0.7152, 0.0722)) * HEAD_CLOTH_DIM), mask_here.g);
		picture = worn_down(picture, UV, tear, tear_at, skin_here);
#endif
		vec3 c = fx_model_grade(picture, grade_saturation, grade_value, grade_cool, grade_cool_mix);
#ifdef WEATHERED
		c = mix(c, DRIED_BLOOD, bled(UV, tear, tear_at) * 0.85);
		vec3 state = tint / 0.5;
		// On the skin the state's colour but never its brightening (the frozen's 1.8 turned faces white).
		float state_light = dot(state, vec3(0.2126, 0.7152, 0.0722));
		vec3 on_skin = mix(vec3(state_light), state, skin_tint) / max(1.0, state_light);
		base = c * (has_skin ? mix(mix(vec3(1.0), state, cloth_state), on_skin, skin_here) : state);
#else
		base = c * (tint / 0.5);
#endif
	}
	ALBEDO = base * shade;
	ROUGHNESS = 1.0;
#ifdef FADED
	ALPHA = 1.0 - fade;
#endif
}
