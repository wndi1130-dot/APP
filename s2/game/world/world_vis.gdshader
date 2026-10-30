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
// How far a lamp's light lifts the sight mask out of doors (decision 474 B9):
// 0 by day (no lamp outshines the day), 1 at night.
uniform float lamp_reveal = 0.0;
// The lamp channel is one layer for every floor: it lights the ground and the
// floor the player stands on (height lamp_floor), not a roof above a fire.
uniform float lamp_floor = 0.0;
// Low sun through the windows at dusk (LampLight.window_cells): ground floor only.
uniform sampler2D win : hint_default_black, filter_linear, repeat_disable;
uniform vec3 win_color : source_color = vec3(1.0, 0.5, 0.28);
uniform float win_gain = 1.0;
// Out of doors by day the sight mask is round and soft about the eye (decision
// 491): the sight cone's straight sides drew a bright wedge on open ground.
// round_day 0 (night, or never set) leaves the cells to rule, as indoors always.
uniform vec2 eye_xz = vec2(-1000.0);
uniform float eye_r = 18.0;
uniform float round_day = 0.0;
uniform float round_floor = 0.95;
// Decision 496: unit-mean CC0 detail, stored at half strength without an sRGB hint.
uniform sampler2DArray ground_layers : repeat_enable, filter_linear_mipmap_anisotropic;
uniform bool ground_layers_on = false;
uniform int region_band = 1;
// Where the round falloff starts and ends, in sight radii.
const float ROUND_IN = 0.4;
const float ROUND_OUT = 1.3;

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
// Faded olive grass of late autumn (decision 499): grey olive, hue 90 degrees and saturation 0.23,
// at the dry grass's lightness (linear 0.215 to its 0.22).
const vec3 LATE_GREEN = vec3(0.46, 0.52, 0.40);

// Decision 496: metres per layer; the K1 row is road, patch, pavement, grass.
// Later bands add rows here. Until then every band uses the K1 materials.
// The two asphalt photos hold their pattern three times over each way, so one
// tile spans three 4 m (6 m) patterns rather than repeating every 1.3 m (2 m).
// Soil and grass take different sizes, so their height difference (which places
// the grass's bare patches) does not repeat every tile.
const float GROUND_TILE_M[8] = float[8](12.0, 18.0, 3.0, 2.5, 1.5, 1.5, 3.55, 3.0);
const ivec4 GROUND_BAND_LAYERS[1] = ivec4[1](ivec4(0, 1, 3, 7));
// The second read's turn (37 degrees) and scale (2.7 times larger).
const mat2 GROUND_TURN = mat2(vec2(0.79863551, 0.60181502), vec2(-0.60181502, 0.79863551)) / 2.7;

// Two reads per layer, at most two layers per fragment. Both projections are
// continuous in world space. Loose layers take the second tile 2.7 times larger,
// turned 37 degrees; the laid slabs (2 concrete, 3 pavement) would show their joints
// twice that way, so theirs is only moved by whole slabs (a quarter tile each way:
// both photos lay their joints on a quarter-tile lattice), which keeps the joints
// on the same lines whatever their phase in the texels.
// The callers sit in per-kind branches, so the gradients come in from the
// fragment (dx, dy: of p) and the reads take explicit gradients.
vec4 ground_layer(int layer, vec2 p, vec2 dx, vec2 dy) {
	float m = GROUND_TILE_M[layer];
	vec2 q = p / m;
	vec2 qx = dx / m;
	vec2 qy = dy / m;
	bool slabbed = layer == 2 || layer == 3;
	vec2 turned = slabbed ? q + vec2(0.25, 0.25) : GROUND_TURN * q + vec2(0.37, 0.61);
	vec4 a = textureGrad(ground_layers, vec3(q, float(layer)), qx, qy);
	vec4 b = textureGrad(ground_layers, vec3(turned, float(layer)), slabbed ? qx : GROUND_TURN * qx, slabbed ? qy : GROUND_TURN * qy);
	float blend = smoothstep(0.25, 0.75, fx_vnoise(p / 9.0 + vec2(13.7, 2.3)));
	vec4 detail = mix(a, b, blend);
	return vec4(detail.rgb * 2.0, detail.a);
}

// A joint or a painted line: 1 within w of the line at 0 (d the distance),
// smoothed over aa, a pixel's width taken from the unbroken position (the
// width of a fract() would jump where it wraps and draw every cell's edge).
float band(float d, float w, float aa) {
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

// The same two reads at a fixed coarse level: what a layer holds at `lod` and wider, the
// photo's broad clouds without its grain (flat_layer divides them out).
vec3 ground_layer_lod(int layer, vec2 p, float lod) {
	float m = GROUND_TILE_M[layer];
	vec2 q = p / m;
	vec3 a = textureLod(ground_layers, vec3(q, float(layer)), lod).rgb;
	// The second read's tile is 2.7 times larger: 1.43 levels finer for the same width in metres.
	vec3 b = textureLod(ground_layers, vec3(GROUND_TURN * q + vec2(0.37, 0.61), float(layer)), max(lod - 1.43, 0.0)).rgb;
	float blend = smoothstep(0.25, 0.75, fx_vnoise(p / 9.0 + vec2(13.7, 2.3)));
	return mix(a, b, blend) * 2.0;
}

// A layer with its broad light and dark clouds taken out (T0-4): over its own read at
// ROAD_FLAT_LOD (texels of about 1.5 m on the 12 m road tile), so the grit, ravels and cracks
// stay and a dark cloud some metres wide does not; the hue stays the photo's.
const float ROAD_FLAT_LOD = 6.0;
vec3 flat_layer(int layer, vec2 p, vec2 dx, vec2 dy) {
	vec3 fine = ground_layer(layer, p, dx, dy).rgb;
	float broad = dot(ground_layer_lod(layer, p, ROAD_FLAT_LOD), vec3(0.299, 0.587, 0.114));
	return fine / max(broad, 0.2);
}

// Trench repairs square to the grid (the streets run along x or z): about one 4 m square in
// six holds a patch 1.2 to 3.2 m by 0.8 to 2.4 m. x: inside (edges smoothed over a pixel),
// y: its sealed seam.
vec2 repair_patch(vec2 p, vec2 px) {
	vec2 cell = floor(p / 4.0);
	if (fx_hash(cell + vec2(31.7, 7.3)) > 0.17) {
		return vec2(0.0);
	}
	vec2 size = vec2(1.2 + 2.0 * fx_hash(cell + vec2(3.1, 9.9)), 0.8 + 1.6 * fx_hash(cell + vec2(17.5, 2.2)));
	size = fx_hash(cell + vec2(5.5, 5.5)) < 0.5 ? size : size.yx;
	vec2 lo = cell * 4.0 + (vec2(4.0) - size) * vec2(fx_hash(cell + vec2(1.3, 4.4)), fx_hash(cell + vec2(8.8, 0.6)));
	vec2 d = max(lo - p, p - (lo + size));
	float out_d = max(d.x, d.y);
	float aa = max(px.x, px.y) + 1e-4;
	return vec2(1.0 - smoothstep(-aa, aa, out_d), band(out_d, 0.035, aa));
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

vec3 bare_ground(int kind, float detail, vec3 colour, vec2 p, vec4 grain, vec2 dx, vec2 dy) {
	vec2 f = fract(p);
	vec2 px = abs(dx) + abs(dy);
	ivec4 layers = GROUND_BAND_LAYERS[clamp(region_band - 1, 0, GROUND_BAND_LAYERS.length() - 1)];
	if (kind == 0 || kind == 5) {
		if (detail < -0.5) {
			// Pavement beside a street: slabs across its run, grit in the joints.
			int along = int(-detail + 0.5) - 1;
			if (ground_layers_on) {
				// Square slabs, laid the same way along x and z, so they run on round a corner.
				return CONCRETE * ground_layer(layers.z, p, dx, dy).rgb;
			}
			return slabs(CONCRETE, p, px, along > 1 ? 2 : along, 1.25) * (0.94 + 0.1 * grain.a);
		}
		// Dry grass, faded green in drifts, soil showing where feet and eaves wore it.
		float patch = fx_fbm2(p * 0.22 + vec2(3.7, 1.1));
		// Darker than the pavement's concrete as in the world and the reference's tiles
		// (grass about 0.7~0.8 of the pavement in sRGB; mood, 바닥 색): same lightness
		// as before, the hue of dry grass and soil (결정 469 C1).
		vec3 grass = mix(DRY_GRASS, OLD_GREEN, smoothstep(0.35, 0.75, fx_vnoise(p * 0.45 + 9.0)));
		if (ground_layers_on) {
			// Decision 499: late autumn keeps a faded olive green in drifts through the dry grass, and all the
			// green (these drifts, the old faded ones and the photo's) dries back as the cold comes (fx_cold.x:
			// late autumn 0~0.4, early winter 0.4~0.85), so early winter reads as dry grass. fx_cold.w is the
			// leaf left on the trees, 1 in late autumn and 0 all through the spring side (Atmosphere
			// AUTUMN_KEYS, SPRING_KEYS): the green comes only on the autumn side, and the thaw's grass stays
			// as dry as the winter left it.
			float autumn = smoothstep(0.0, 0.2, fx_cold.w);
			float late = (1.0 - smoothstep(0.1, 0.45, fx_cold.x)) * autumn;
			float dry = max(smoothstep(0.3, 0.6, fx_cold.x), 1.0 - autumn);
			grass = mix(grass, LATE_GREEN, late * smoothstep(0.3, 0.55, fx_vnoise(p * 0.21 + vec2(4.1, 17.3))));
			grass = mix(grass, DRY_GRASS, dry);
			vec4 grass_detail = ground_layer(layers.w, p, dx, dy);
			// The photo's moss greens are fresher than faded grass: a third of the way to its lightness always.
			grass_detail.rgb = mix(grass_detail.rgb, vec3(dot(grass_detail.rgb, vec3(0.2126, 0.7152, 0.0722))), max(dry, 0.35));
			vec4 soil_detail = ground_layer(6, p, dx, dy);
			// Decision 496: interpolated corner soil is only a gentle bias. Height
			// and world-space noise place the edge, without thresholding that bias.
			float bias = (clamp(detail, 0.0, 1.0) - 0.5) * 0.3;
			float edge = (soil_detail.a - grass_detail.a) * 0.75 + (patch - 0.5) * 0.45;
			edge += (fx_vnoise(p * 0.8 + vec2(19.1, 3.7)) - 0.5) * 0.15 + bias;
			float aa = 0.08 + min(0.12, max(px.x, px.y) * 0.15);
			float bare = smoothstep(-aa, aa, edge);
			return mix(grass * grass_detail.rgb, SOIL * soil_detail.rgb, bare);
		}
		grass *= 0.92 + 0.16 * fx_vnoise(p * 2.3);
		float bare = smoothstep(0.52, 0.68, patch) * 0.7;
		bare = max(bare, smoothstep(0.3, 0.6, clamp(detail, 0.0, 1.0) + (patch - 0.5) * 0.5));
		return mix(grass, SOIL * (0.92 + 0.16 * grain.a), bare);
	} else if (kind == 1) {
		int bits = int(detail + 0.5);
		if ((bits & 512) != 0) {
			if (ground_layers_on) {
				return CONCRETE * 0.95 * ground_layer(2, p, dx, dy).rgb;
			}
			return slabs(CONCRETE * 0.95, p, px, 3, 1.0) * (0.93 + 0.12 * grain.a);
		}
		vec3 c;
		if (ground_layers_on) {
			// One even grey with its fine grain (T0-4): the photos' broad clouds taken out, the
			// repairs as squared trench patches of the second asphalt, a shade darker, sealed round.
			vec3 worn = flat_layer(layers.x, p, dx, dy);
			vec3 patched = flat_layer(layers.y, p, dx, dy) * 0.93;
			vec2 repair = repair_patch(p, px);
			c = ASPHALT * mix(worn, patched, repair.x) * (1.0 - 0.22 * repair.y);
		} else {
			// Aged asphalt: wide worn patches, a few cracks.
			c = ASPHALT * (0.9 + 0.18 * fx_fbm2(p * 0.18 + 11.0)) * (0.96 + 0.08 * fx_vnoise(p * 3.7));
			float vein = fx_vnoise(p * 0.9 + 2.0) - 0.5;
			float crack = band(vein, 0.012, fwidth(vein) + 1e-4) * smoothstep(0.55, 0.7, fx_vnoise(p * 0.3 + 5.0));
			c *= 1.0 - 0.3 * crack;
		}
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
		// The platform keeps its long cast slabs with the joints across its run (결정 469 C4):
		// the concrete photo is laid in small squares (decision 496 waits for a long-slab one).
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
		if (ground_layers_on) {
			return GRAVEL * ground_layer(4, p, dx, dy).rgb;
		}
		return GRAVEL * (0.86 + 0.28 * fx_vnoise(p * 9.0)) * (0.95 + 0.1 * grain.a);
	} else if (kind == 4 && ground_layers_on) {
		return colour * ground_layer(5, p, dx, dy).rgb;
	}
	return colour;
}

// Room floors by kind, the house's roll and the region (room_finish, 결정 469 C3, 사용자 10-28
// 「바닥재질도 방마다 다르게」), sRGB like the floor kinds. Each kind has its own family so the room
// next door reads apart at a glance: carpet or boards in bedrooms, parquet in living and dining
// rooms, linoleum or tile in kitchens, small tile in bathrooms, patterned tile, terrazzo or stone in
// halls, concrete or rough planks in store rooms. Within the measured ranges (linear albedo:
// varnished boards 0.1~0.3, linoleum 0.2~0.5, glazed tile 0.5~0.75; docs/art/material_values.md),
// the darkest wood at linear 0.18: the plain WOOD (V 0.40) left the cut-away rooms below the
// brightness line (V 0.36), and a house's floor held it at 0.368 against the reference's 0.495
// (mood B1 10-28: the floor is what falls short, the dark checker and dark boards most). Patterns
// are drawn a little larger than life so they read from the slanted view, and their seams fade to
// the mean as a pixel grows (no shimmer far out).
const vec3 HONEY_BOARD = vec3(0.64, 0.52, 0.37);
const vec3 WALNUT_BOARD = vec3(0.56, 0.43, 0.31);
const vec3 GREY_BOARD = vec3(0.60, 0.56, 0.49);
const vec3 PINE_BOARD = vec3(0.68, 0.55, 0.38);
const vec3 OAK_BLOCK = vec3(0.66, 0.56, 0.42);
// How far an unseen room's floor keeps its own lightness, from the plain floor's (0) to its own (1).
const float UNSEEN_FOLLOW = 0.25;

// Seam strength left as a pixel covers `size` (1 near, 0 once a seam is under a fifth of a pixel).
float seam_k(vec2 px, float size) {
	return 1.0 - smoothstep(0.08, 0.3, max(px.x, px.y) / size);
}

// Boards `w` wide along x, ends staggered on a 1.9 m run, a shade apart each.
vec3 room_boards(vec3 tone, vec2 p, vec2 px, float w) {
	float k = floor(p.y / w);
	float run = p.x + fx_hash(vec2(k, 13.0)) * 1.9;
	vec3 c = tone * (0.88 + 0.2 * fx_hash(vec2(k, floor(run / 1.9))));
	c *= 0.94 + 0.08 * fx_vnoise(vec2(run * 3.0, k * 7.0));
	float side = band((fract(p.y / w + 0.5) - 0.5) * w, 0.005, px.y + 1e-4);
	float end = band((fract(run / 1.9 + 0.5) - 0.5) * 1.9, 0.005, px.x + 1e-4);
	return c * (1.0 - 0.3 * max(side, end) * seam_k(px, w));
}

// Square tiles `size` across, a shade apart, in grout; two colours in a checker.
vec3 room_tiles(vec3 a, vec3 b, vec3 grout, vec2 p, vec2 px, float size) {
	vec2 cell = floor(p / size);
	vec3 c = mod(cell.x + cell.y, 2.0) > 0.5 ? b : a;
	c *= 0.95 + 0.08 * fx_hash(cell);
	vec2 d = (fract(p / size + 0.5) - 0.5) * size;
	float g = max(band(d.x, 0.006, px.x + 1e-4), band(d.y, 0.006, px.y + 1e-4)) * seam_k(px, size);
	return mix(c, grout, g);
}

// Parquet in a herringbone: columns `col` wide, slats at 45 degrees leaning the other way in
// every other column, the next column's slats half a slat on.
vec3 room_herring(vec3 tone, vec2 p, vec2 px, float col, float slat) {
	float ci = floor(p.x / col);
	float lean = mod(ci, 2.0) > 0.5 ? -1.0 : 1.0;
	float x = p.x - ci * col;
	float t = (p.y + lean * x + ci * 0.5 * slat) / slat;
	float k = floor(t);
	vec3 c = tone * (0.86 + 0.22 * fx_hash(vec2(ci, k)));
	c *= 0.95 + 0.07 * fx_vnoise(vec2(t * 0.7, x * 6.0 + ci * 3.0));
	float a = px.x + px.y + 1e-4;
	float s = max(band((fract(t + 0.5) - 0.5) * slat * 0.7071, 0.005, a * 0.7071),
		band((fract(p.x / col + 0.5) - 0.5) * col, 0.005, px.x + 1e-4));
	return c * (1.0 - 0.32 * s * seam_k(px, slat));
}

// Basket weave: squares `size` across of three slats, turned a quarter in a checker.
vec3 room_basket(vec3 tone, vec2 p, vec2 px, float size) {
	vec2 cell = floor(p / size);
	vec2 f = fract(p / size);
	bool turn = mod(cell.x + cell.y, 2.0) > 0.5;
	float across = (turn ? f.x : f.y) * 3.0;
	float k = floor(across);
	vec3 c = tone * (0.86 + 0.22 * fx_hash(cell * 3.0 + vec2(k, turn ? 1.0 : 0.0)));
	c *= 0.95 + 0.07 * fx_vnoise((turn ? p.yx : p) * vec2(4.0, 12.0));
	float sl = band((fract(across + 0.5) - 0.5) * size / 3.0, 0.004, (turn ? px.x : px.y) + 1e-4);
	vec2 d = (fract(p / size + 0.5) - 0.5) * size;
	float sq = max(band(d.x, 0.005, px.x + 1e-4), band(d.y, 0.005, px.y + 1e-4));
	return c * (1.0 - 0.3 * max(sl, sq) * seam_k(px, size / 3.0));
}

// Fitted carpet: no seams, a soft pile that mottles and a lighter worn path here and there.
vec3 room_carpet(vec3 tone, vec2 p) {
	vec3 c = tone * (0.93 + 0.12 * fx_vnoise(p * 1.4 + 4.0));
	c *= 0.96 + 0.06 * fx_vnoise(p * 7.0);
	return mix(c, c * 1.1 + 0.02, smoothstep(0.62, 0.8, fx_fbm2(p * 0.6 + 2.0)) * 0.6);
}

// Chips in a ground (terrazzo, speckled linoleum): dark and light flecks `size` across.
vec3 room_flecks(vec3 tone, vec3 dark, vec3 light, vec2 p, float size) {
	vec3 c = tone * (0.95 + 0.07 * fx_vnoise(p * 0.9));
	float n = fx_vnoise(p / size);
	float m = fx_vnoise(p / size + 17.0);
	c = mix(c, dark, smoothstep(0.78, 0.84, n) * 0.8);
	return mix(c, light, smoothstep(0.8, 0.86, m) * 0.7);
}

// Patterned (encaustic) tiles: a lozenge of `b` in each square of `a`, a thin rim of `b`.
vec3 room_lozenge(vec3 a, vec3 b, vec3 grout, vec2 p, vec2 px, float size) {
	vec2 cell = floor(p / size);
	vec2 l = fract(p / size) - 0.5;
	float k = seam_k(px, size * 0.3);
	float loz = 1.0 - smoothstep(0.26, 0.29, abs(l.x) + abs(l.y));
	float rim = max(band(abs(l.x) - 0.42, 0.02, 0.02), band(abs(l.y) - 0.42, 0.02, 0.02));
	vec3 c = mix(a, b, (0.5 + 0.5 * k) * max(loz, rim * step(abs(l.x), 0.43) * step(abs(l.y), 0.43)));
	c *= 0.95 + 0.07 * fx_hash(cell);
	vec2 d = (fract(p / size + 0.5) - 0.5) * size;
	return mix(c, grout, max(band(d.x, 0.006, px.x + 1e-4), band(d.y, 0.006, px.y + 1e-4)) * seam_k(px, size));
}

// Small hexagons `size` across, in grout.
vec3 room_hex(vec3 tone, vec3 grout, vec2 p, vec2 px, float size) {
	vec2 q = p / size;
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(q, r) - h;
	vec2 b = mod(q - h, r) - h;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 id = q - g;
	vec2 ag = abs(g);
	float e = 0.5 - max(dot(ag, normalize(r)), ag.x);
	vec3 c = tone * (0.95 + 0.07 * fx_hash(floor(id * 2.0)));
	return mix(c, grout, band(e, 0.04, (px.x + px.y) / size + 1e-4) * seam_k(px, size));
}

// Stone flags in rows, each row's stones their own length and shade.
vec3 room_flags(vec3 tone, vec3 joint, vec2 p, vec2 px) {
	float row = floor(p.y / 0.55);
	float len = 0.6 + 0.4 * fx_hash(vec2(row, 3.0));
	float run = p.x + fx_hash(vec2(row, 9.0)) * len;
	float k = floor(run / len);
	vec3 c = tone * (0.86 + 0.22 * fx_hash(vec2(row, k))) * (0.94 + 0.1 * fx_vnoise(p * 2.5));
	float s = max(band((fract(p.y / 0.55 + 0.5) - 0.5) * 0.55, 0.012, px.y + 1e-4),
		band((fract(run / len + 0.5) - 0.5) * len, 0.012, px.x + 1e-4));
	return mix(c, joint, s * seam_k(px, 0.55));
}

// Bricks laid flat in a stretcher bond, 0.3 by 0.15.
vec3 room_bricks(vec3 tone, vec3 joint, vec2 p, vec2 px) {
	vec2 bc = p / vec2(0.3, 0.15);
	bc.x += 0.5 * mod(floor(bc.y), 2.0);
	vec3 c = tone * (0.84 + 0.26 * fx_hash(floor(bc)));
	vec2 d = (fract(bc + 0.5) - 0.5) * vec2(0.3, 0.15);
	float s = max(band(d.x, 0.008, px.x + 1e-4), band(d.y, 0.008, px.y + 1e-4));
	return mix(c, joint, s * seam_k(px, 0.15));
}

// Concrete screed: broad damp patches, a few hairline cracks, a stain.
vec3 room_screed(vec3 tone, vec2 p, vec2 px) {
	vec3 c = tone * (0.9 + 0.16 * fx_fbm2(p * 0.5 + 6.0)) * (0.96 + 0.06 * fx_vnoise(p * 5.0));
	float vein = fx_vnoise(p * 0.8 + 3.0) - 0.5;
	c *= 1.0 - 0.2 * band(vein, 0.01, fwidth(vein) + 1e-4) * smoothstep(0.6, 0.72, fx_vnoise(p * 0.35));
	return c * (1.0 - 0.12 * smoothstep(0.66, 0.8, fx_fbm2(p * 0.4 + 1.0)));
}

// Painted boards, the paint worn through to the wood along the run.
vec3 room_painted(vec3 paint, vec3 wood, vec2 p, vec2 px, float w) {
	vec3 b = room_boards(paint, p, px, w);
	float worn = smoothstep(0.55, 0.75, fx_fbm2(vec2(p.x * 0.8, floor(p.y / w) * 1.7)));
	return mix(b, room_boards(wood, p, px, w), worn * 0.7);
}

// The region's grading (결정 478 지역 무리): the rail works sooty and greyer, the mountain works and
// the high mountain resin-warm, the waterside bleached cool, the bare line plain. Lightness kept.
vec3 room_grade(vec3 c, int region) {
	vec3 grey = vec3(dot(c, vec3(0.3, 0.59, 0.11)));
	if (region == 1) {
		return mix(c, grey, 0.22);
	} else if (region == 2 || region == 3) {
		return c * vec3(1.04, 1.0, 0.92);
	} else if (region == 4) {
		return mix(c, grey, 0.15) * vec3(0.98, 1.01, 1.05);
	} else if (region == 5) {
		return mix(c, grey, 0.32);
	}
	return c;
}

// `tone` is the finish's mean colour, to scale the whole of it (pattern and all).
vec3 room_floor(int code, vec2 p, vec2 px, out vec3 tone) {
	int kind = room_kind(code);
	int region = room_region(code);
	int roll = room_roll(code);
	// The mountain regions lay wide pine planks where the town lays narrow boards.
	bool hills = region == 2 || region == 3;
	float plank = hills ? 0.24 : 0.16;
	vec3 wood = hills ? PINE_BOARD : HONEY_BOARD;
	vec3 c;
	if (kind == 1) {
		// Bedrooms: fitted carpet in three of five houses (rose, sage, slate blue), boards, painted boards.
		if (roll == 0 || roll == 1 || roll == 3) {
			tone = roll == 0 ? vec3(0.66, 0.51, 0.49) : (roll == 1 ? vec3(0.57, 0.61, 0.51) : vec3(0.51, 0.56, 0.63));
			c = room_carpet(tone, p);
		} else if (roll == 2) {
			tone = wood;
			c = room_boards(tone, p, px, plank);
		} else {
			// Ox red, or the waterside's grey-blue.
			tone = region == 4 ? vec3(0.60, 0.66, 0.70) : vec3(0.64, 0.46, 0.40);
			c = room_painted(tone, wood, p, px, plank);
		}
	} else if (kind == 4 || kind == 6) {
		// Living and dining rooms: parquet (herringbone, basket weave), boards, oatmeal carpet;
		// dining rooms swap the carpet for terracotta tile.
		if (roll == 0 || roll == 1) {
			tone = roll == 0 ? vec3(0.66, 0.53, 0.37) : WALNUT_BOARD;
			c = room_herring(tone, p, px, 0.6, 0.2);
		} else if (roll == 2) {
			tone = OAK_BLOCK;
			c = room_basket(tone, p, px, 0.54);
		} else if (roll == 3) {
			tone = kind == 6 ? wood : (hills ? PINE_BOARD : GREY_BOARD);
			c = room_boards(tone, p, px, plank);
		} else if (kind == 6) {
			tone = vec3(0.68, 0.49, 0.38);
			c = room_tiles(tone, tone * 0.94, vec3(0.58, 0.53, 0.48), p, px, 0.3);
		} else {
			tone = vec3(0.66, 0.60, 0.51);
			c = room_carpet(tone, p);
		}
	} else if (kind == 2) {
		// Kitchens: linoleum checkers, quarry tile, speckled linoleum, a tile laid on the diagonal.
		if (roll == 0) {
			vec3 cream = vec3(0.76, 0.72, 0.60);
			vec3 sage = vec3(0.57, 0.64, 0.56);
			tone = 0.5 * (cream + sage);
			c = room_tiles(cream, sage, vec3(0.62, 0.62, 0.56), p, px, 0.33);
		} else if (roll == 1) {
			tone = vec3(0.68, 0.48, 0.36);
			c = room_tiles(tone, tone, vec3(0.56, 0.51, 0.46), p, px, 0.3);
		} else if (roll == 2) {
			tone = vec3(0.74, 0.70, 0.55);
			c = room_flecks(tone, vec3(0.45, 0.43, 0.36), vec3(0.86, 0.84, 0.76), p, 0.08);
		} else if (roll == 3) {
			vec3 cream = vec3(0.78, 0.76, 0.70);
			vec3 slate = vec3(0.54, 0.55, 0.56);
			tone = 0.5 * (cream + slate);
			vec2 q = vec2(p.x + p.y, p.x - p.y) * 0.7071;
			c = room_tiles(cream, slate, vec3(0.60, 0.60, 0.57), q, px * 1.4142, 0.34);
		} else {
			vec3 cream = vec3(0.74, 0.72, 0.64);
			vec3 blue = vec3(0.56, 0.64, 0.72);
			tone = 0.5 * (cream + blue);
			c = room_tiles(cream, blue, vec3(0.60, 0.60, 0.57), p, px, 0.33);
		}
	} else if (kind == 3) {
		// Bathrooms: small glazed tile, white, blue, cream and sage, hexagons, pink.
		if (roll == 0) {
			tone = vec3(0.76, 0.75, 0.71);
			c = room_tiles(tone, tone, vec3(0.56, 0.56, 0.53), p, px, 0.15);
		} else if (roll == 1) {
			tone = vec3(0.62, 0.68, 0.71);
			c = room_tiles(tone, tone, vec3(0.50, 0.52, 0.53), p, px, 0.15);
		} else if (roll == 2) {
			vec3 cream = vec3(0.74, 0.72, 0.64);
			vec3 sage = vec3(0.55, 0.62, 0.56);
			tone = 0.5 * (cream + sage);
			c = room_tiles(cream, sage, vec3(0.52, 0.52, 0.49), p, px, 0.2);
		} else if (roll == 3) {
			tone = vec3(0.78, 0.77, 0.74);
			c = room_hex(tone, vec3(0.55, 0.55, 0.53), p, px, 0.2);
		} else {
			tone = vec3(0.76, 0.64, 0.62);
			c = room_tiles(tone, tone, vec3(0.58, 0.54, 0.52), p, px, 0.15);
		}
	} else if (kind == 5) {
		// Halls: patterned tile, terrazzo, long walnut boards, stone flags, a muted checker.
		if (roll == 0) {
			vec3 cream = vec3(0.74, 0.70, 0.60);
			vec3 clay = vec3(0.60, 0.40, 0.32);
			tone = mix(cream, clay, 0.3);
			c = room_lozenge(cream, clay, vec3(0.56, 0.54, 0.50), p, px, 0.4);
		} else if (roll == 1) {
			tone = vec3(0.67, 0.65, 0.60);
			c = room_flecks(tone, vec3(0.40, 0.38, 0.36), vec3(0.82, 0.78, 0.70), p, 0.06);
		} else if (roll == 2) {
			tone = WALNUT_BOARD;
			c = room_boards(tone, p, px, plank);
		} else if (roll == 3) {
			tone = vec3(0.62, 0.60, 0.56);
			c = room_flags(tone, vec3(0.46, 0.45, 0.42), p, px);
		} else {
			vec3 cream = vec3(0.76, 0.74, 0.67);
			vec3 slate = vec3(0.54, 0.54, 0.53);
			tone = 0.5 * (cream + slate);
			c = room_tiles(cream, slate, vec3(0.58, 0.58, 0.55), p, px, 0.4);
		}
	} else if (kind == 7) {
		// Store rooms: concrete, rough planks, brick pavers, painted concrete, worn linoleum.
		if (roll == 0) {
			tone = vec3(0.62, 0.61, 0.58);
			c = room_screed(tone, p, px);
		} else if (roll == 1) {
			tone = vec3(0.61, 0.53, 0.42);
			c = room_boards(tone, p, px, 0.24);
		} else if (roll == 2) {
			tone = vec3(0.66, 0.48, 0.40);
			c = room_bricks(tone, vec3(0.56, 0.54, 0.50), p, px);
		} else if (roll == 3) {
			tone = vec3(0.56, 0.61, 0.57);
			c = room_screed(tone, p, px);
		} else {
			tone = vec3(0.64, 0.56, 0.47);
			c = room_carpet(tone, p * 0.5);
		}
	} else {
		tone = wood;
		c = room_boards(tone, p, px, plank);
	}
	tone = room_grade(tone, region);
	return room_grade(c, region);
}

// Rugs (room_furnish data.rugs, room_finish's right half): a field in one of eight colours, a
// border in one of four, inset from the rug's cells and drawn in one of seven weaves. Kept off the
// box mats' tan and the searched grey so a rug never reads as a box (map_view _bake_container).
const vec3 RUG_FIELD[8] = vec3[8](vec3(0.66, 0.38, 0.34), vec3(0.44, 0.48, 0.60), vec3(0.45, 0.55, 0.45), vec3(0.60, 0.45, 0.53),
	vec3(0.42, 0.58, 0.58), vec3(0.54, 0.62, 0.70), vec3(0.78, 0.74, 0.64), vec3(0.74, 0.54, 0.52));
const vec3 RUG_BORDER[4] = vec3[4](vec3(0.78, 0.74, 0.64), vec3(0.46, 0.22, 0.20), vec3(0.26, 0.30, 0.40), vec3(0.32, 0.32, 0.27));
const float RUG_INSET = 0.14;

// Returns how much of the rug covers this point (0 off it), its colour in `rug` and mean in `tone`.
float room_rug_finish(int look, float edge, vec2 p, vec2 px, out vec3 rug, out vec3 tone) {
	int weave = (look - 1) / 32;
	int way = (look - 1) % 32;
	vec3 field = RUG_FIELD[way % 8];
	vec3 rim = RUG_BORDER[way / 8];
	if (distance(field, rim) < 0.15) {
		rim = RUG_BORDER[(way / 8 + 1) % 4];
	}
	float a = 0.01 + max(px.x, px.y);
	float on = smoothstep(RUG_INSET - a, RUG_INSET + a, edge);
	float in_rim = 1.0 - smoothstep(RUG_INSET + 0.13 - a, RUG_INSET + 0.13 + a, edge);
	vec2 q = p;
	vec3 c = field;
	float k = seam_k(px, 0.12);
	if (weave == 1) {
		// Diamond lattice in the border colour.
		vec2 l = fract(vec2(q.x + q.y, q.x - q.y) * 0.7071 / 0.35) - 0.5;
		c = mix(field, rim, band(min(abs(l.x), abs(l.y)), 0.06, 0.03) * 0.6 * k);
	} else if (weave == 2) {
		// Rag rug: bands of the field, the border colour and cream across x.
		float s = floor(q.x / 0.12);
		float h = fx_hash(vec2(s, float(way)));
		c = h < 0.45 ? field : (h < 0.75 ? mix(field, rim, 0.6) : mix(field, RUG_BORDER[0], 0.55));
		c *= 0.92 + 0.12 * fx_vnoise(q * vec2(3.0, 14.0));
	} else if (weave == 3) {
		// A field of small rosettes.
		vec2 l = fract(q / 0.4) - 0.5;
		c = mix(field, rim, (1.0 - smoothstep(0.08, 0.12, length(l))) * 0.7 * k);
	} else if (weave == 4) {
		// Large checks of the field and a shade of it.
		vec2 cell = floor(q / 0.5);
		c = mod(cell.x + cell.y, 2.0) > 0.5 ? field * 0.86 : field;
	} else if (weave == 5) {
		// Plaid: crossing bands of the border colour.
		vec2 l = abs(fract(q / 0.6) - 0.5);
		float bandk = max(smoothstep(0.38, 0.42, l.x), smoothstep(0.38, 0.42, l.y));
		c = mix(field, rim, bandk * 0.55 * k);
	} else if (weave == 6) {
		// Braided ovals: rings from the rug's edge inward.
		float r = fract((edge - RUG_INSET) / 0.09);
		float h = fx_hash(vec2(floor((edge - RUG_INSET) / 0.09), float(way)));
		c = (h < 0.5 ? field : mix(field, rim, 0.55)) * (0.9 + 0.12 * smoothstep(0.2, 0.5, abs(r - 0.5)) * k);
	}
	// Woollen pile and a little wear.
	c *= 0.93 + 0.1 * fx_vnoise(q * 6.0);
	c = mix(c, rim, in_rim);
	// The fringe: a thin line just inside the border.
	c = mix(c, RUG_BORDER[0], band(edge - RUG_INSET - 0.13, 0.012, a) * 0.5 * k);
	rug = c;
	tone = mix(field, rim, 0.25);
	return on;
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
	float cover = 0.0;
	// Warped 0.15/m patches leave dark gaps; skip the new noise without snow.
	if (fx_snow > 0.01) {
		vec2 patch_p = world_pos.xz * 0.15;
		vec2 warp = vec2(fx_vnoise(patch_p * 0.5 + vec2(17.1, 9.2)),
			fx_vnoise(patch_p * 0.5 + vec2(3.7, 23.6))) - vec2(0.5);
		// A finer octave breaks the round value-noise blobs into ragged drifts.
		float snow_patch = 0.72 * fx_vnoise(patch_p + 0.7 * warp) + 0.28 * fx_vnoise(patch_p * 3.1 + 1.4 * warp + vec2(5.3, 11.9));
		// Pixel width, at least 0.02, keeps the edge firm without shimmer.
		float patch_w = max(fwidth(snow_patch), 0.02);
		// Half the noise range at snow 0.5; every patch is filled by 0.95.
		float snow_t = mix(1.0 + patch_w, -patch_w, smoothstep(0.05, 0.95, fx_snow));
		cover = 0.9 * smoothstep(snow_t - patch_w, snow_t + patch_w, snow_patch);
	}
	cover *= smoothstep(0.6, 0.9, up) * sky * (1.0 - smoothstep(0.08, 0.3, chroma));
	// The photo grain, one fetch for all four; its strength wanders so the
	// 2.6 m tile does not read as a grid. Grit on bare ground, wet soil as it wets.
	vec4 grain = texture(fx_ground, world_pos.xz * (1.0 / 2.6));
	// Decision 496: the ground layers' gradients, taken here outside the branches (bare_ground
	// reads the layers inside per-kind branches, where a quad's implicit derivatives are undefined).
	vec2 ground_dx = dFdx(world_pos.xz);
	vec2 ground_dy = dFdy(world_pos.xz);
	float ground_k = smoothstep(0.6, 0.9, up) * sky * (1.0 - smoothstep(0.08, 0.3, chroma));
	float wander = 0.55 + 0.9 * fx_vnoise(world_pos.xz * 0.13 + 7.0);
	// Keep the kind's dark bare look in snow gaps, even in deep winter.
	float bare_k = sky * smoothstep(0.6, 0.9, up);
	int kind = int(ground_kind + 0.5) - 1;
	if (ground_kind > 0.5 && bare_k > 0.001) {
		base = mix(base, bare_ground(kind, ground_detail, base, world_pos.xz, grain, ground_dx, ground_dy), bare_k);
	}
	// A furnished room's floor under its roof (room_finish; 0 elsewhere keeps the kind's colour).
	// The floor itself only, at a storey's height: what lies on it (a coat, a map, the empty mark)
	// is under the roof and faces up as well, and keeps its own colour.
	vec2 room_px = fwidth(world_pos.xz);
	float unseen_k = 1.0;
	if (sky < 0.5 && up > 0.9 && abs(world_pos.y - 3.0 * round(world_pos.y / 3.0)) < 0.003) {
		int rc = room_code(world_pos.xz, world_pos.y + 0.05, map_size);
		if (rc > 0) {
			vec3 tone;
			vec3 finish = room_floor(rc, world_pos.xz, room_px, tone);
			// A rug laid in the room (room_furnish), over the floor's finish.
			float rug_edge;
			int look = room_rug(world_pos.xz, world_pos.y + 0.05, map_size, rug_edge);
			if (look > 0) {
				vec3 rug;
				vec3 rug_tone;
				float on = room_rug_finish(look, rug_edge, world_pos.xz, room_px, rug, rug_tone);
				finish = mix(finish, rug, on);
				tone = mix(tone, rug_tone, on);
			}
			// Out of sight the finish keeps its hue and half its pattern, and its lightness goes
			// three quarters of the way (1 - UNSEEN_FOLLOW) to a shade under the plain floor (the kind's colour, WOOD
			// V 0.40) as the mask leaves it (`dimmed` below, in linear: 0.6 grey + 0.4 brightest
			// channel): the unseen rooms are 89 % of a house's floor (mood B1), so a light tile stays
			// lighter than a dark board there too, and the boxes' floor mats (map_view _bake_container)
			// still stand above the floor round them.
			float away = (1.0 - cell.r) * clamp(mask_on, 0.0, 1.0);
			vec3 luma = vec3(0.3, 0.59, 0.11);
			vec3 was_l = floor_to_linear(base);
			vec3 tone_l = floor_to_linear(tone);
			float was = 0.6 * dot(was_l, luma) + 0.4 * max(was_l.r, max(was_l.g, was_l.b));
			float as_seen = 0.6 * dot(tone_l, luma) + 0.4 * max(tone_l.r, max(tone_l.g, tone_l.b));
			unseen_k = mix(1.0, 0.93 * mix(was, as_seen, UNSEEN_FOLLOW) / max(as_seen, 0.001), away);
			base = mix(finish, tone, 0.5 * away);
		}
	}
	base = floor_to_linear(base) * unseen_k;
	float soil = mix(grain.a, grain.b, clamp(wet * 1.4, 0.0, 1.0));
	// Laid surfaces (road, platform, pavement) take less of the soil's blotches.
	// Less on bare ground than under snow, so the blotches do not break the forms nor
	// sink grass in a shadow under V 0.15 (결정 470 dark share).
	bool paved = kind == 1 || kind == 2 || ground_detail < -0.5;
	float laid = paved ? (ground_layers_on && kind != 2 ? 0.15 : 0.35) : (kind == 0 || kind == 5) ? (ground_layers_on ? 0.3 : 0.45) : 1.0;
	base *= 1.0 + (soil - 0.5) * 1.3 * ground_k * wander * mix(1.0, laid, bare_k);
	// The wet soil above already darkens in blotches; this is the even rest
	// (0.35 sank a rainy noon under V 0.36, decision 470).
	base *= 1.0 - 0.2 * wet;
	// Cleared paving keeps 25% of cover; exposed wet ground darkens up to 20%.
	// Apply before the bank so sheltered piles and footsteps still read.
	if (paved) {
		cover *= 0.25;
		base *= 1.0 - 0.2 * clamp(fx_snow, 0.0, 1.0) * bare_k;
	}
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
	// Ground out of doors in a lamp's pool shows as the light shows it, seen
	// or not (decision 474 B9); a room behind a shut door keeps its mask (sky 0).
	float lamp_here = max(step(-0.5, world_pos.y) * (1.0 - step(1.0, world_pos.y)), 1.0 - step(1.0, abs(world_pos.y - lamp_floor)));
	float reveal = max(seen.r, smoothstep(0.08, 0.24, cell.b) * lamp_reveal * sky * lamp_here);
	// Seen now: full. Seen before: dim memory. Never seen: dark but readable.
	float floor_k = mix(fx_sight.x, fx_sight.y, seen.g);
	float round_k = clamp(round_day, 0.0, 1.0) * sky;
	// Between dusk and night the floor comes up first and the round shape takes over
	// after, so the cone's side never stands out at half strength by the eye.
	float round_floor_k = smoothstep(0.0, 0.5, round_k);
	float pool_seen = seen.r;
	if (round_k > 0.001) {
		float near = 1.0 - smoothstep(eye_r * ROUND_IN, eye_r * ROUND_OUT, distance(world_pos.xz, eye_xz));
		float lamp_seen = smoothstep(0.08, 0.24, cell.b) * lamp_reveal * lamp_here;
		reveal = mix(reveal, max(near, lamp_seen), smoothstep(0.5, 1.0, round_k));
		pool_seen = mix(pool_seen, near, smoothstep(0.5, 1.0, round_k));
		// One floor out there, no trail where the eye has been.
		floor_k = mix(floor_k, round_floor, round_floor_k);
	}
	float lit = mix(1.0, max(reveal, floor_k), mask_on);
	float grey = dot(base, vec3(0.3, 0.59, 0.11));
	// The memory's grey only where the mask is drawn: with it off all is in sight.
	// Out of doors by day the colour goes less (0.9 kept, not 0.2). Out of sight
	// keeps a fifth of its colour: with the floors lifted (fx_sight 0.80 at night)
	// the grey is what tells an unseen room from a seen one.
	float keep = mix(reveal * 0.8 + 0.2, reveal * 0.1 + 0.9, round_floor_k);
	vec3 dimmed = mix(vec3(grey), base, mix(1.0, keep, clamp(mask_on, 0.0, 1.0)));
	// Tactical pause (fx_fade) fades the world before the sight mask darkens it.
	ALBEDO = fx_photo(mix(dimmed, vec3(0.86, 0.88, 0.9), frost), fx_fade) * lit;
	ROUGHNESS = mix(1.0, 0.4, wet * (1.0 - cover));
	if (bank > 0.002) {
		// The bank's own slope, so the light picks it out.
		NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	}
	// A lamp out of sight still shows faintly, so mates can be found in the dark.
	float lamp = cell.b * lamp_gain * lamp_here * mix(0.4, 1.0, reveal) * (1.0 - 0.5 * clamp(fx_fade, 0.0, 1.0));
	float pool = texture(win, uv).r * win_gain * mix(0.4, 1.0, pool_seen) * (1.0 - 0.5 * clamp(fx_fade, 0.0, 1.0))
		* smoothstep(0.6, 0.9, up) * step(-0.5, world_pos.y) * (1.0 - step(1.0, world_pos.y));
	EMISSION = (lamp_color * lamp + win_color * pool) * (0.25 + 0.75 * grey);
}
