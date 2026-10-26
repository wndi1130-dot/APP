shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_schlick_ggx;
#include "res://fx/shaders/fx_common.gdshaderinc"
// Floor and wall blood as flat instanced quads: one draw for a whole stop.
// The shape is made here (no texture), so every mark differs by its seed.
// INSTANCE_CUSTOM: r seed 0..1, g birth time in stop seconds,
//   b kind (0 drop, 1 splat, 2 pool, 3 wall) + 0.5 when it lies on snow,
//   a strength 0..1.
uniform float now = 0.0;
uniform vec3 fresh : source_color = vec3(0.23, 0.07, 0.055);
uniform vec3 dried : source_color = vec3(0.17, 0.075, 0.055);
uniform float dry_seconds = 90.0;
uniform float pool_seconds = 8.0;
uniform float life_seconds = 900.0;
// The ground's sight mask (map_view): R seen now, G seen before.
uniform sampler2D vis : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(1.0, 1.0);
uniform float mask_on = 0.0;

varying vec4 custom;
varying vec3 world_pos;

float h1(float n) {
	return fract(sin(n * 127.1 + 0.37) * 43758.5453);
}

void vertex() {
	custom = INSTANCE_CUSTOM;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float seed = custom.r * 97.0 + 1.0;
	float age = max(now - custom.g, 0.0);
	float kind = floor(custom.b + 0.01);
	float snow = step(0.25, fract(custom.b + 0.01));
	float strength = clamp(custom.a, 0.0, 1.0);
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec2 ring_dir = r > 0.0001 ? p / r : vec2(1.0, 0.0);
	// A pool spreads from a third of its size; blood on snow soaks outward a little.
	float grow = kind == 2.0 ? mix(0.32, 1.0, smoothstep(0.0, pool_seconds, age)) : 1.0;
	float soak = snow * smoothstep(0.0, 12.0, age);
	float wobble = kind == 2.0 ? 0.18 : (kind == 0.0 ? 0.26 : 0.40);
	float rim = (kind == 2.0 ? 0.74 : 0.56) + (fx_vnoise(ring_dir * 1.7 + seed) - 0.5) * wobble;
	rim += (fx_vnoise(ring_dir * 4.3 + seed * 1.7) - 0.5) * 0.14;
	rim *= grow * (1.0 + soak * 0.12);
	float edge = mix(0.025, 0.11, snow) + soak * 0.05;
	float mask = 1.0 - smoothstep(rim - edge, rim + edge, r);
	// Flung droplets around a splat (fewer on a pool, none on a single drop).
	int dots = kind == 1.0 ? 7 : (kind == 3.0 ? 5 : (kind == 2.0 ? 3 : 1));
	for (int i = 0; i < dots; i++) {
		float fi = float(i);
		float ang = h1(seed + fi * 3.1) * 6.2832;
		float dist = rim + 0.06 + h1(seed + fi * 7.7) * (kind == 0.0 ? 0.12 : 0.32);
		float rad = 0.02 + h1(seed + fi * 1.3) * (kind == 0.0 ? 0.04 : 0.07);
		vec2 c = vec2(cos(ang), sin(ang)) * dist;
		mask = max(mask, 1.0 - smoothstep(rad - edge * 0.5, rad + edge * 0.5, length(p - c)));
	}
	// Wall marks run down: local +X is up, so drips go toward -X.
	if (kind == 3.0) {
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			float y = (h1(seed + fi * 5.3) - 0.5) * 0.9;
			float len = 0.35 + h1(seed + fi * 2.9) * 0.6;
			float w = 0.035 + h1(seed + fi * 9.1) * 0.03;
			float along = clamp((-p.x) / max(len, 0.01), 0.0, 1.0);
			float drip = (1.0 - smoothstep(w * (1.0 - along * 0.6), w * (1.0 - along * 0.6) + 0.02, abs(p.y - y)));
			drip *= step(0.0, -p.x) * (1.0 - smoothstep(len - 0.05, len, -p.x));
			mask = max(mask, drip);
		}
	}
	float dry = smoothstep(0.0, dry_seconds, age);
	vec3 col = mix(fresh, dried, dry);
	// Dried blood gathers dark at the rim; the inside is uneven.
	float rim_band = smoothstep(rim - 0.2, rim - 0.03, r) * (1.0 - smoothstep(rim, rim + 0.06, r));
	col *= 1.0 - (0.25 + 0.25 * dry) * rim_band;
	col *= 0.82 + 0.36 * fx_vnoise(p * 5.0 + seed);
	float fade = 1.0 - smoothstep(life_seconds - 30.0, life_seconds, age);
	float alpha = mask * mix(0.6, 0.92, strength) * fade;
	if (alpha < 0.01) {
		discard;
	}
	float lit = 1.0;
	if (mask_on > 0.5) {
		vec2 seen = texture(vis, world_pos.xz / map_size).rg;
		lit = max(seen.r, mix(fx_sight.x, fx_sight.y, seen.g));
	}
	ALBEDO = fx_photo(col, fx_fade) * lit;
	ROUGHNESS = mix(0.28, 0.92, dry);
	SPECULAR = 0.5 * (1.0 - dry) * (1.0 - snow * 0.5);
	ALPHA = alpha;
}
