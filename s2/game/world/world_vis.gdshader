shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;
#include "res://fx/shaders/fx_common.gdshaderinc"
// CC0 photo detail (사용자 10-25 공개 자산 먼저, fx/atmosphere.gd): the ground's grain (R snow,
// G autumn leaf, B wet soil, A grit, light and dark round 0.5) and the photo
// sky the puddles give back. FxState writes them; the map's colours stay.
global uniform sampler2D fx_ground : repeat_enable, filter_linear_mipmap;
global uniform sampler2D fx_sky_tex : source_color, repeat_enable, filter_linear_mipmap;

// Low-resolution sight mask: one texel per metre cell (R = seen now, G = seen before).
uniform sampler2D vis : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(120.0, 70.0);
uniform float mask_on = 1.0;
uniform float frost = 0.0;
// Warm lamp light from the mask's B channel (weather_fx 12.2): no light nodes.
uniform vec3 lamp_color : source_color = vec3(1.0, 0.64, 0.30);
uniform float lamp_gain = 0.0;

varying vec3 world_pos;
varying vec3 world_nrm;
varying float bank;
// The floor kind + 1 the ground carries in UV2.x (map_view, map_edge); 0 on all else.
varying flat float ground_kind;

// The map's floor colours (map_view FLOOR_COLORS, vertex colour) are sRGB numbers,
// as every other material's colour is: read them as such (mood C9).
vec3 floor_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

// Bare ground by floor kind, for while no snow lies on it: the kinds read apart
// by brightness as the reference's grass, asphalt and concrete tile sets do (D13).
// Open ground is dead grass and soil in patches, the road dark asphalt, the
// platform light concrete slabs, gravel speckled. Other kinds keep their colour.
// sRGB, like the floor colours.
vec3 bare_ground(int kind, vec3 colour, vec2 p, vec4 grain) {
	if (kind == 0 || kind == 5) {
		float patch = fx_fbm2(p * 0.22 + vec2(3.7, 1.1));
		// Under the platform's concrete as grass and soil are in the world (albedo grass 0.25,
		// bare soil 0.17, new concrete 0.55: about 0.7 and 0.6 of it in sRGB) and in the
		// reference's tiles (grass about 0.7 of the pavement): mood, 바닥 색.
		vec3 grass = mix(vec3(0.53, 0.52, 0.46), vec3(0.56, 0.55, 0.49), fx_vnoise(p * 2.3));
		vec3 soil = vec3(0.45, 0.42, 0.38) * (0.95 + 0.1 * grain.a);
		return mix(grass, soil, smoothstep(0.42, 0.6, patch));
	} else if (kind == 1) {
		return vec3(0.26, 0.26, 0.27) * (0.95 + 0.1 * fx_vnoise(p * 1.7));
	} else if (kind == 2) {
		vec2 slab = fract(p * 0.5);
		float seam = step(0.96, max(slab.x, slab.y));
		return vec3(0.72, 0.72, 0.71) * (0.97 + 0.05 * fx_hash(floor(p * 0.5))) * (1.0 - 0.15 * seam);
	} else if (kind == 7) {
		return vec3(0.59, 0.58, 0.57) * (0.9 + 0.2 * fx_hash(floor(p * 6.0)));
	}
	return colour;
}

void vertex() {
	ground_kind = UV2.x;
	// Snow banked against the walls the wind blows at. Only the ground mesh
	// carries UV (map_view.drift_uv: which way the wall stands from the vertex).
	bank = (max(0.0, UV.x * fx_wind.x) + max(0.0, UV.y * fx_wind.y)) * COLOR.a;
	bank *= smoothstep(0.2, 0.9, fx_snow) * (0.4 + 0.6 * fx_wind.z);
	VERTEX.y += 0.35 * bank;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb;
	// Weather (fx_common globals): wet darkens and shines, snow dusts up faces.
	// Snow is capped and spares saturated colours, so loot, stove and floor
	// kinds stay readable. Floors under a roof get neither.
	float up = clamp(world_nrm.y, 0.0, 1.0);
	// Vertex alpha: 1 open to the sky, 0 under a roof (map_view.sky_alpha).
	float sky = COLOR.a;
	float wet = clamp(fx_wet, 0.0, 1.0) * sky;
	vec2 uv = world_pos.xz / map_size;
	vec4 cell = texture(vis, uv);
	// A: how much of the cell's snow is untouched (1 fresh; lower where someone
	// walked). Marks thin the snow and show the darker ground through it.
	float trodden = (1.0 - cell.a) * sky * smoothstep(0.6, 0.9, up);
	float drift = fx_fbm2(world_pos.xz * 0.35);
	float chroma = max(base.r, max(base.g, base.b)) - min(base.r, min(base.g, base.b));
	float cover = smoothstep(0.6, 0.9, up) * clamp(fx_snow * (0.6 + 0.8 * drift), 0.0, 1.0);
	cover *= 0.75 * sky * (1.0 - smoothstep(0.08, 0.3, chroma));
	// The photo grain, one fetch for all four; its strength wanders so the
	// 2.6 m tile does not read as a grid. Grit on bare ground, wet soil as it wets.
	vec4 grain = texture(fx_ground, world_pos.xz * (1.0 / 2.6));
	float ground_k = smoothstep(0.6, 0.9, up) * sky * (1.0 - smoothstep(0.08, 0.3, chroma));
	float wander = 0.55 + 0.9 * fx_vnoise(world_pos.xz * 0.13 + 7.0);
	// The kind's bare look on open flat ground, gone back to the floor's own colour
	// as snow comes (the gates above keep reading the floor's own colour).
	float bare_k = sky * smoothstep(0.6, 0.9, up) * (1.0 - smoothstep(0.25, 0.8, fx_snow));
	if (ground_kind > 0.5 && bare_k > 0.001) {
		base = mix(base, bare_ground(int(ground_kind + 0.5) - 1, base, world_pos.xz, grain), bare_k);
	}
	base = floor_to_linear(base);
	float soil = mix(grain.a, grain.b, clamp(wet * 1.4, 0.0, 1.0));
	base *= 1.0 + (soil - 0.5) * 1.3 * ground_k * wander;
	base *= 1.0 - 0.35 * wet;
	cover = max(cover, 0.8 * clamp(bank, 0.0, 1.0));
	cover *= 1.0 - 0.9 * trodden;
	base *= 1.0 - 0.3 * trodden * clamp(fx_snow, 0.0, 1.0);
	base = mix(base, FX_SNOW * mix(1.0, 0.75, wet) * (1.0 + (grain.r - 0.5) * 0.35 * wander), cover);
	// Rime on upright faces in hard cold: thin and patchy, never a white wall.
	float rime = (1.0 - smoothstep(0.2, 0.6, up)) * sky * clamp(fx_frost, 0.0, 1.0);
	rime *= 0.16 * smoothstep(0.3, 0.9, fx_fbm2(vec2((world_pos.x + world_pos.z) * 0.7, world_pos.y * 1.6)));
	base = mix(base, FX_RIME, rime * (1.0 - smoothstep(0.08, 0.3, chroma)));
	// The atmosphere frame (fx_cold, fx_sky): standing water on open flat ground
	// where the snow thins, open and ringed by rain above freezing, ice below;
	// wet ground gives a little of the sky back (no specular here); dead leaf on
	// bare ground in the warm stages. Saturated floor kinds are spared.
	float level_k = smoothstep(0.9, 0.98, up) * sky * (1.0 - smoothstep(0.08, 0.3, chroma)) * (1.0 - smoothstep(0.3, 0.7, cover));
	float water = clamp(max(fx_wet * 1.2, fx_cold.y * 0.85), 0.0, 1.0);
	float standing = 0.0;
	// Noise only where a pool could show (phone budget).
	if (level_k * water > 0.01) {
		standing = fx_pool(world_pos.xz) * level_k * water;
		if (standing > 0.001) {
			// The photo sky's clouds in the water, at the hour's light (fx_sky).
			vec2 suv = vec2(world_pos.x * 0.015 + TIME * 0.002, 0.2 + 0.6 * abs(fract(world_pos.z * 0.0075) * 2.0 - 1.0));
			float shape = dot(texture(fx_sky_tex, suv).rgb, vec3(0.3, 0.59, 0.11));
			float mean_l = max(dot(textureLod(fx_sky_tex, vec2(0.5), 10.0).rgb, vec3(0.3, 0.59, 0.11)), 0.02);
			vec3 refl = fx_sky.rgb * clamp(shape / mean_l, 0.4, 1.8);
			base = mix(base, fx_pool_color(base, world_pos.xz, TIME, fx_cold.y, fx_wet * (1.0 - fx_cold.y), refl), standing);
		}
	}
	base = mix(base, fx_sky.rgb * 0.5, wet * level_k * (1.0 - standing) * 0.18);
	if (fx_cold.w * level_k > 0.01) {
		// Fallen leaf in drifts a few metres across (from this far a drift reads,
		// a single leaf does not); the photo's leaves are the pattern inside,
		// from dark brown to a dull orange.
		float heap = smoothstep(0.5, 0.64, drift) * (0.6 + 0.4 * fx_vnoise(world_pos.xz * 1.1 + 3.0));
		float leaf = fx_cold.w * level_k * heap * (0.55 + 0.45 * smoothstep(0.4, 0.65, grain.g));
		vec3 leaf_col = mix(vec3(0.24, 0.15, 0.08), vec3(0.55, 0.34, 0.15), clamp((grain.g - 0.3) * 1.8, 0.0, 1.0));
		base = mix(base, leaf_col, leaf * 0.62);
	}
	// Cloud shadows drift over whatever is open to the sky.
	base *= mix(1.0, fx_cloud_shade(world_pos.xz, TIME), sky);
	vec2 seen = cell.rg;
	// Seen now: full. Seen before: dim memory. Never seen: dark but readable.
	float lit = mix(1.0, max(seen.r, seen.g * 0.3 + 0.24), mask_on);
	float grey = dot(base, vec3(0.3, 0.59, 0.11));
	vec3 dimmed = mix(vec3(grey), base, seen.r * 0.6 + 0.4);
	// Tactical pause (fx_fade) fades the world before the sight mask darkens it.
	ALBEDO = fx_photo(mix(dimmed, vec3(0.86, 0.88, 0.9), frost), fx_fade) * lit;
	ROUGHNESS = mix(1.0, 0.4, wet * (1.0 - cover));
	if (bank > 0.002) {
		// The bank's own slope, so the light picks it out.
		NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	}
	// A lamp out of sight still shows faintly, so mates can be found in the dark.
	float lamp = cell.b * lamp_gain * mix(0.4, 1.0, seen.r) * (1.0 - 0.5 * clamp(fx_fade, 0.0, 1.0));
	EMISSION = lamp_color * (0.25 + 0.75 * grey) * lamp;
}
