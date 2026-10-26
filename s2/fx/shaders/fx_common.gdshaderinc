// Shared weather state and cheap noise for every fx shader.
// The globals live in project.godot [shader_globals]; fx/fx_state.gd is the
// only writer (docs/design/briefs/shaders.md 3장).
global uniform float fx_wet;    // 0 dry .. 1 soaked (rain, sleet, thaw)
global uniform float fx_snow;   // 0 bare .. 1 deep snow lying on up-facing faces
global uniform float fx_frost;  // 0 none .. 1 hard rime (glass, metal edges)
global uniform vec3 fx_wind;    // xy = ground direction (x, z), z = strength 0..1
global uniform vec4 fx_tint : source_color; // weather and hour colour for sky and haze
global uniform float fx_flash;  // lightning, 0..1 for a few frames
// Tactical pause: the world fades like an old photo. People and HUD skip it
// (presentation_motion.md 필드 일시정지), so only world shaders call fx_photo.
global uniform float fx_fade;
// The atmosphere frame (fx/atmosphere.gd): x the cold (0 warmest .. 1 coldest),
// y how frozen standing water is, z how long icicles hang, w dead leaf left.
global uniform vec4 fx_cold;
// The sky's light: what wet ground and ice give back, low sun on paint.
global uniform vec4 fx_sky : source_color;
// Cloud shadows crossing the ground: x cover, yz drift (m/s), w how much of the
// light they take (0 under a closed sky, where there is no sun to block).
global uniform vec4 fx_cloud;
// The sight mask's floors: x for ground never seen, y for ground seen before
// (seen now is full). Lighter by day, dark after dark (fx/fx_state.gd sight_floor).
global uniform vec2 fx_sight;

// Mobile budget: value noise with two octaves, no textures.
float fx_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float fx_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(fx_hash(i), fx_hash(i + vec2(1.0, 0.0)), u.x),
			mix(fx_hash(i + vec2(0.0, 1.0)), fx_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fx_fbm2(vec2 p) {
	return fx_vnoise(p) * 0.65 + fx_vnoise(p * 2.13 + 7.1) * 0.35;
}

// Cloud shadow drifting over world xz: 1 in the open, darker under a cloud.
// Built-ins are not seen inside functions, so the caller hands TIME in.
float fx_cloud_shade(vec2 xz, float time) {
	if (fx_cloud.w <= 0.001) {
		return 1.0;
	}
	vec2 p = (xz - fx_cloud.yz * time) * 0.022;
	float n = fx_fbm2(p) * 0.8 + fx_vnoise(p * 3.1 + 5.0) * 0.2;
	float edge = 1.0 - fx_cloud.x;
	return 1.0 - smoothstep(edge - 0.08, edge + 0.12, n) * fx_cloud.w * 0.75;
}

// Where water stands on open flat ground (0..1). Pools are the same in every
// shader, so a wall's foot and the ground beside it agree.
float fx_pool(vec2 xz) {
	return smoothstep(0.63, 0.71, fx_fbm2(xz * 0.42 + vec2(17.0, 3.0)));
}

// A pool: open water gives the sky back, ringed when it rains; frozen it is
// pale, milky ice with dark cracks. ice: fx_cold.y. rain: how hard it falls.
// sky: what the water gives back (the hour's sky light, with the photo's clouds).
vec3 fx_pool_color(vec3 base, vec2 xz, float time, float ice, float rain, vec3 sky) {
	float rip = 0.0;
	if (rain > 0.01) {
		vec2 cell = floor(xz * 2.2);
		vec2 f = fract(xz * 2.2) - 0.5;
		float t = fract(time * 0.9 + fx_hash(cell) * 7.0);
		rip = (1.0 - smoothstep(0.0, 0.06, abs(length(f) - t * 0.5))) * (1.0 - t) * rain;
	}
	vec3 water = mix(base * 0.35, sky * 0.62, 0.7) + rip * 0.12;
	float crack = 1.0 - abs(fx_vnoise(xz * 3.3 + 11.0) * 2.0 - 1.0);
	vec3 frozen = mix(vec3(0.60, 0.65, 0.70), sky * 0.9, 0.35) * (0.92 + 0.08 * fx_vnoise(xz * 1.7));
	frozen *= 1.0 - 0.35 * pow(crack, 14.0);
	return mix(water, frozen, clamp(ice, 0.0, 1.0));
}

// Rime and snow are grey-white, never sky blue (decisions.md 날씨와 빛).
const vec3 FX_SNOW = vec3(0.70, 0.71, 0.72);
const vec3 FX_RIME = vec3(0.70, 0.715, 0.73);
// Coal black for ink and soot; red and sky blue stay out (decisions.md UI 연출).
const vec3 FX_COAL = vec3(0.07, 0.065, 0.06);

// Model colour grade (decisions.md 셰이더 줄, 2026-10-17): painted models must
// not stand out on white snow, so their own colour is pressed darker and colder
// before any weather layer. sat scales HSV saturation (mix toward the brightest
// channel, like a hue/saturation node), val scales HSV value, then the colour is
// multiplied by a cold grey-blue at cool_mix strength. Snow and rime colours are
// added after this and stay as they are.
vec3 fx_model_grade(vec3 c, float sat, float val, vec3 cool, float cool_mix) {
	float v = max(c.r, max(c.g, c.b));
	vec3 g = mix(vec3(v), c, sat) * val;
	return mix(g, g * cool, cool_mix);
}

// Grey-brown photo fade with lifted blacks; amount 0 returns c unchanged.
// Frost: warped ridged noise gives thin branching veins over a soft bloom.
// Placeholder until a mask from real frost photos exists (presentation_motion.md
// 8b). No even grid or crossed lines: a regular hatch reads as wire mesh,
// which the ban lines keep off windows and edges.
float fx_crystal(vec2 p) {
	vec2 w = p + vec2(fx_fbm2(p * 0.5), fx_fbm2(p * 0.5 + 4.3)) * 2.5;
	float v1 = 1.0 - abs(fx_vnoise(w) * 2.0 - 1.0);
	float v2 = 1.0 - abs(fx_vnoise(w * 2.3 + 9.1) * 2.0 - 1.0);
	float veins = pow(v1, 6.0) * 0.65 + pow(v2, 8.0) * 0.35;
	return clamp(veins + fx_fbm2(p * 0.8 + 11.0) * 0.35, 0.0, 1.0);
}

vec3 fx_photo(vec3 c, float amount) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 faded = mix(vec3(0.17, 0.155, 0.14), vec3(0.72, 0.68, 0.61), l);
	return mix(c, faded, clamp(amount, 0.0, 1.0) * 0.85);
}
