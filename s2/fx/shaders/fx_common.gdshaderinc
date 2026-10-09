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

// Rime and snow are grey-white, never sky blue (decisions.md 날씨와 빛).
const vec3 FX_SNOW = vec3(0.70, 0.71, 0.72);
const vec3 FX_RIME = vec3(0.70, 0.715, 0.73);
// Coal black for ink and soot; red and sky blue stay out (decisions.md UI 연출).
const vec3 FX_COAL = vec3(0.07, 0.065, 0.06);

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
