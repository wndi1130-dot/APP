shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;
#include "res://fx/shaders/fx_common.gdshaderinc"
#include "res://game/world/room_finish.gdshaderinc"
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
// What is drawn on the cell (UV2.y, map_view.ground_details): a code for roads,
// pavements and platforms, the soil weight on grass (smooth over the cells).
varying float ground_detail;

// The map's floor colours (map_view FLOOR_COLORS, vertex colour) are sRGB numbers,
// as every other material's colour is: read them as such (mood C9).
vec3 floor_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

// Bare ground by floor kind and what map_view.ground_details says of the cell,
// for while no snow lies on it (D13; 결정 469 C1·C4): dry grass with soil worn
// through before doors and along walls, streets of aged asphalt with a kerb,
// gutter and a worn centre line, concrete pavements and footpaths, the platform
// in long slabs with a stripe at the edge, gravel speckled.
// The colours are sRGB, like the floor colours, set by real reflectance (linear
// luminance; measured albedos in brackets): dry grass 0.22 (green grass 0.25),
// faded green 0.19, soil 0.18 (bare soil 0.17), aged asphalt 0.11 (worn 0.12),
// concrete 0.53 (new 0.55), gravel 0.24. Light pavement, mid grass and soil,
// dark road: the ground reads in grey alone, and an overcast day keeps its
// spread of light (V p95-p5 at least 0.40, 결정 471 B1). Table and sources:
// docs/art/material_values.md.
const vec3 DRY_GRASS = vec3(0.57, 0.50, 0.32);
const vec3 OLD_GREEN = vec3(0.47, 0.51, 0.31);
const vec3 SOIL = vec3(0.53, 0.44, 0.34);
const vec3 ASPHALT = vec3(0.37, 0.37, 0.38);
const vec3 CONCRETE = vec3(0.76, 0.75, 0.72);
const vec3 LINE_PAINT = vec3(0.76, 0.64, 0.30);
const vec3 GRAVEL = vec3(0.55, 0.52, 0.47);

// A joint or a painted line: 1 within w of the line at 0 (d the distance),
// smoothed over aa, a pixel's width taken from the unbroken position (the
// width of a fract() would jump where it wraps and draw every cell's edge).
float band(float d, float w, float aa) {
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

// Concrete laid in slabs `size` long along `along` (0 x, 1 z, else none):
// joints only across the run and faint, a few slabs a shade apart.
vec3 slabs(vec3 c, vec2 p, vec2 px, int along, float size) {
	float k = along == 1 ? p.y : p.x;
	float across = along == 1 ? p.x : p.y;
	float slab = floor(k / size);
	float tone = 0.95 + 0.08 * fx_hash(vec2(slab, floor(across * 0.5)));
	float joint = along == 0 || along == 1 ? band(fract(k / size + 0.5) - 0.5, 0.012, (along == 1 ? px.y : px.x) / size + 1e-4) : 0.0;
	return c * tone * (1.0 - 0.1 * joint);
}

vec3 bare_ground(int kind, float detail, vec3 colour, vec2 p, vec4 grain) {
	vec2 f = fract(p);
	vec2 px = fwidth(p);
	if (kind == 0 || kind == 5) {
		if (detail < -0.5) {
			// Pavement beside a street: slabs across its run, grit in the joints.
			int along = int(-detail + 0.5) - 1;
			return slabs(CONCRETE, p, px, along > 1 ? 2 : along, 1.25) * (0.94 + 0.1 * grain.a);
		}
		// Dry grass, faded green in drifts, soil showing where feet and eaves wore it.
		float patch = fx_fbm2(p * 0.22 + vec2(3.7, 1.1));
		// Darker than the pavement's concrete as in the world and the reference's tiles
		// (grass about 0.7~0.8 of the pavement in sRGB; mood, 바닥 색): same lightness
		// as before, the hue of dry grass and soil (결정 469 C1).
		vec3 grass = mix(DRY_GRASS, OLD_GREEN, smoothstep(0.35, 0.75, fx_vnoise(p * 0.45 + 9.0)));
		grass *= 0.92 + 0.16 * fx_vnoise(p * 2.3);
		float bare = smoothstep(0.52, 0.68, patch) * 0.7;
		bare = max(bare, smoothstep(0.3, 0.6, clamp(detail, 0.0, 1.0) + (patch - 0.5) * 0.5));
		return mix(grass, SOIL * (0.92 + 0.16 * grain.a), bare);
	} else if (kind == 1) {
		int bits = int(detail + 0.5);
		if ((bits & 512) != 0) {
			return slabs(CONCRETE * 0.95, p, px, 3, 1.0) * (0.93 + 0.12 * grain.a);
		}
		// Aged asphalt: wide worn patches, a few cracks.
		vec3 c = ASPHALT * (0.9 + 0.18 * fx_fbm2(p * 0.18 + 11.0)) * (0.96 + 0.08 * fx_vnoise(p * 3.7));
		float vein = fx_vnoise(p * 0.9 + 2.0) - 0.5;
		float crack = band(vein, 0.012, fwidth(vein) + 1e-4) * smoothstep(0.55, 0.7, fx_vnoise(p * 0.3 + 5.0));
		c *= 1.0 - 0.3 * crack;
		// The kerb (light stone) and gutter (dark, silted) on the sides at open ground.
		float edge = 1.0;
		edge = (bits & 1) != 0 ? min(edge, f.y) : edge;
		edge = (bits & 2) != 0 ? min(edge, 1.0 - f.x) : edge;
		edge = (bits & 4) != 0 ? min(edge, 1.0 - f.y) : edge;
		edge = (bits & 8) != 0 ? min(edge, f.x) : edge;
		c = mix(c, SOIL * 0.6, (1.0 - smoothstep(0.14, 0.34, edge)) * 0.45);
		c = mix(c, CONCRETE * 0.92, 1.0 - smoothstep(0.1, 0.13, edge));
		// A worn, dashed centre line.
		if ((bits & 48) != 0) {
			bool on_x = (bits & 16) != 0;
			float at = float((bits >> 6) & 7) * 0.25;
			float d = (on_x ? f.y : f.x) - at;
			float dash = step(0.45, fract((on_x ? p.x : p.y) / 6.0));
			float worn = smoothstep(0.25, 0.6, fx_vnoise(p * 1.3 + 7.0));
			c = mix(c, LINE_PAINT, band(d, 0.06, (on_x ? px.y : px.x) + 1e-4) * dash * worn * 0.8);
		}
		return c;
	} else if (kind == 2) {
		int bits = int(detail + 0.5);
		int along = (bits & 16) != 0 ? 0 : (bits & 32) != 0 ? 1 : 2;
		vec3 c = slabs(CONCRETE * 1.04, p, px, along, 3.0) * (0.95 + 0.08 * grain.a);
		// The stripe a step back from the edge over the rails, and its coping.
		float edge = 1.0;
		edge = (bits & 1) != 0 ? min(edge, f.y) : edge;
		edge = (bits & 2) != 0 ? min(edge, 1.0 - f.x) : edge;
		edge = (bits & 4) != 0 ? min(edge, 1.0 - f.y) : edge;
		edge = (bits & 8) != 0 ? min(edge, f.x) : edge;
		c = mix(c, LINE_PAINT * 0.95, band(edge - 0.5, 0.12, max(px.x, px.y) + 1e-4) * (0.55 + 0.35 * fx_vnoise(p * 1.7)));
		return mix(c, CONCRETE * 0.85, 1.0 - smoothstep(0.17, 0.2, edge));
	} else if (kind == 7) {
		return GRAVEL * (0.86 + 0.28 * fx_vnoise(p * 9.0)) * (0.95 + 0.1 * grain.a);
	}
	return colour;
}

// Room floors by kind and the house's roll (room_finish, 결정 469 C3), sRGB like the
// floor kinds. Varnished boards (linear albedo 0.2~0.3) in bedrooms and living rooms,
// linoleum or quarry tile in kitchens, small glazed tile in bathrooms (0.4~0.6;
// docs/art/material_values.md). The one plain WOOD (V 0.40) left the rooms the cut-away
// opens below the brightness line (V 0.36) once the day fill lit the walls (mood).
const vec3 HONEY_BOARD = vec3(0.58, 0.46, 0.32);
const vec3 WALNUT_BOARD = vec3(0.50, 0.38, 0.27);
const vec3 GREY_BOARD = vec3(0.56, 0.52, 0.45);

// Boards 0.16 m wide along x, ends staggered on a 1.9 m run, a shade apart each.
vec3 room_boards(vec3 tone, vec2 p, vec2 px) {
	float k = floor(p.y / 0.16);
	float run = p.x + fx_hash(vec2(k, 13.0)) * 1.9;
	vec3 c = tone * (0.88 + 0.2 * fx_hash(vec2(k, floor(run / 1.9))));
	c *= 0.94 + 0.08 * fx_vnoise(vec2(run * 3.0, k * 7.0));
	float side = band((fract(p.y / 0.16 + 0.5) - 0.5) * 0.16, 0.005, px.y + 1e-4);
	float end = band((fract(run / 1.9 + 0.5) - 0.5) * 1.9, 0.005, px.x + 1e-4);
	return c * (1.0 - 0.3 * max(side, end));
}

// Square tiles `size` across, a shade apart, in grout; two colours in a checker.
vec3 room_tiles(vec3 a, vec3 b, vec3 grout, vec2 p, vec2 px, float size) {
	vec2 cell = floor(p / size);
	vec3 c = mod(cell.x + cell.y, 2.0) > 0.5 ? b : a;
	c *= 0.95 + 0.08 * fx_hash(cell);
	vec2 d = (fract(p / size + 0.5) - 0.5) * size;
	return mix(c, grout, max(band(d.x, 0.006, px.x + 1e-4), band(d.y, 0.006, px.y + 1e-4)));
}

vec3 room_floor(int code, vec2 p, vec2 px) {
	int kind = code & 7;
	int roll = code >> 3;
	if (kind == 3) {
		if (roll == 0) {
			return room_tiles(vec3(0.76, 0.75, 0.71), vec3(0.76, 0.75, 0.71), vec3(0.56, 0.56, 0.53), p, px, 0.15);
		} else if (roll == 1) {
			return room_tiles(vec3(0.62, 0.68, 0.71), vec3(0.62, 0.68, 0.71), vec3(0.50, 0.52, 0.53), p, px, 0.15);
		}
		return room_tiles(vec3(0.74, 0.72, 0.64), vec3(0.55, 0.62, 0.56), vec3(0.52, 0.52, 0.49), p, px, 0.2);
	}
	if (kind == 2 && roll == 0) {
		// Linoleum laid in a checker: its seams barely show.
		return room_tiles(vec3(0.72, 0.68, 0.56), vec3(0.48, 0.55, 0.48), vec3(0.58, 0.58, 0.52), p, px, 0.33);
	}
	if (kind == 2 && roll == 1) {
		return room_tiles(vec3(0.64, 0.43, 0.32), vec3(0.64, 0.43, 0.32), vec3(0.52, 0.47, 0.42), p, px, 0.3);
	}
	if (kind == 2 || roll == 0) {
		return room_boards(HONEY_BOARD, p, px);
	}
	return room_boards(roll == 1 ? WALNUT_BOARD : GREY_BOARD, p, px);
}

void vertex() {
	ground_kind = UV2.x;
	ground_detail = UV2.y;
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
	int kind = int(ground_kind + 0.5) - 1;
	if (ground_kind > 0.5 && bare_k > 0.001) {
		base = mix(base, bare_ground(kind, ground_detail, base, world_pos.xz, grain), bare_k);
	}
	// A furnished room's floor under its roof (room_finish; 0 elsewhere keeps the kind's colour).
	vec2 room_px = fwidth(world_pos.xz);
	if (sky < 0.5 && up > 0.9) {
		int rc = room_code(world_pos.xz, world_pos.y + 0.05, map_size);
		if (rc > 0) {
			base = room_floor(rc, world_pos.xz, room_px);
		}
	}
	base = floor_to_linear(base);
	float soil = mix(grain.a, grain.b, clamp(wet * 1.4, 0.0, 1.0));
	// Laid surfaces (road, platform, pavement) take less of the soil's blotches.
	// Less on bare ground than under snow, so the blotches do not break the forms nor
	// sink grass in a shadow under V 0.15 (결정 470 dark share).
	float laid = (kind == 1 || kind == 2 || ground_detail < -0.5) ? 0.35 : (kind == 0 || kind == 5) ? 0.45 : 1.0;
	base *= 1.0 + (soil - 0.5) * 1.3 * ground_k * wander * mix(1.0, laid, bare_k);
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
	float lit = mix(1.0, max(seen.r, mix(fx_sight.x, fx_sight.y, seen.g)), mask_on);
	float grey = dot(base, vec3(0.3, 0.59, 0.11));
	// The memory's grey only where the mask is drawn: with it off all is in sight.
	vec3 dimmed = mix(vec3(grey), base, mix(1.0, seen.r * 0.6 + 0.4, clamp(mask_on, 0.0, 1.0)));
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
