shader_type spatial;
// The world outside the running train (presentation_motion.md 7b), painted on
// one card the train camera carries behind the train (fx/outside_view.gd).
// Everything comes from the atmosphere look (fx/atmosphere.gd): the sky by the
// hour (gold and pink at dawn, orange and violet at dusk, moonlit night), broken
// or closed cloud with light falling through the gaps, the region's far line
// (wood, white birch, lakes, roofs, church towers, grain towers, rolling hills),
// poles keeping the beat of the speed, and the ground in front of the train:
// track bed, embankment, fence posts flying past, then field or lake, under
// snow, wet and dark, or iced, all lit by the hour's sun and fill. Metres on
// the train's own plane (x along the track, y up), so the far line sits just
// over the roof at either zoom.
// Ban lines: nothing smokes, no chimneys or towers that read as watchtowers, no
// wire fences, no closed wagons. No screen or depth reads.
render_mode unshaded, cull_disabled, shadows_disabled;
#include "res://fx/shaders/fx_common.gdshaderinc"

// Where the camera looks (world), and the train's side plane (world z).
uniform vec3 view_dir = vec3(0.0, -0.14, -0.99);
uniform float plane_z = 0.0;
// Metres run (the ground goes by at this; far things at a share of it).
uniform float scroll = 0.0;
uniform float cam_x = 0.0;
// Heights on the train's plane: the far line, and the top of the ground in front.
uniform float horizon = 3.6;
uniform float ground_top = -1.55;

uniform vec4 sky_top : source_color = vec4(0.47, 0.55, 0.66, 1.0);
uniform vec4 sky_low : source_color = vec4(0.76, 0.78, 0.80, 1.0);
uniform vec4 sun_glow : source_color = vec4(0.95, 0.94, 0.9, 1.0);
uniform vec4 lamp : source_color = vec4(1.0, 0.64, 0.30, 1.0);
// The hour's light on the land: the sun's colour and strength, the sky's fill.
uniform vec4 sun_col : source_color = vec4(0.80, 0.85, 0.92, 1.0);
uniform float sun_e = 0.7;
uniform vec4 fill_col : source_color = vec4(0.56, 0.60, 0.67, 1.0);
uniform float fill_e = 0.26;
// x: the sun left (-1) or right (+1) of the view's middle, y: height in degrees.
uniform vec2 sun_at = vec2(0.0, 20.0);
uniform float sun_vis : hint_range(0.0, 1.0) = 0.5;
uniform float cloud : hint_range(0.0, 1.0) = 0.3;
uniform float haze : hint_range(0.0, 1.0) = 0.3;
uniform float veil : hint_range(0.0, 1.0) = 0.0;
uniform float lum : hint_range(0.0, 1.0) = 1.0;
uniform float night : hint_range(0.0, 1.0) = 0.0;
// Lying snow, frozen water, wet ground, dead leaf (the cold's).
uniform float snow : hint_range(0.0, 1.0) = 0.9;
uniform float ice : hint_range(0.0, 1.0) = 1.0;
uniform float wet : hint_range(0.0, 1.0) = 0.0;
uniform float leaves : hint_range(0.0, 1.0) = 0.0;
// The region (atmosphere REGIONS).
uniform float forest : hint_range(0.0, 1.0) = 0.45;
uniform float conifer : hint_range(0.0, 1.0) = 0.55;
uniform float birch : hint_range(0.0, 1.0) = 0.45;
uniform float water : hint_range(0.0, 1.0) = 0.6;
uniform float town : hint_range(0.0, 1.0) = 0.3;
uniform float hills : hint_range(0.0, 1.0) = 0.1;
uniform float spire : hint_range(0.0, 1.0) = 0.4;
uniform float silo : hint_range(0.0, 1.0) = 0.0;
uniform float mist : hint_range(0.0, 1.0) = 0.3;
// 0 telegraph poles (Polish side), 1 catenary masts (German side).
uniform float catenary : hint_range(0.0, 1.0) = 0.0;
// Rain or wet snow falling: the far line goes greyer, the near ground darker.
uniform float falling : hint_range(0.0, 1.0) = 0.0;
// Photo skies (CC0, 사용자 10-25 공개 자산 먼저): up to three bands mixed by sky_w, each the half
// of a real sky that faces the sun, horizon at the bottom. They lend their
// clouds to the hour's colours, and sky_hue of their own colour. photo_on 0:
// the drawn sky only.
uniform sampler2D sky_a : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sky_b : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sky_c : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 sky_w = vec3(1.0, 0.0, 0.0);
uniform vec3 sky_hue = vec3(0.25);
uniform float photo_on : hint_range(0.0, 1.0) = 0.0;

varying vec3 wpos;

// Colours below are written as seen (sRGB) and turned linear here.
vec3 lin(vec3 c) {
	return pow(c, vec3(2.2));
}

// Land lit by the hour: the sky's fill all round, the sun as much as it reaches.
vec3 lit(vec3 albedo, float sun_k) {
	return albedo * (fill_col.rgb * fill_e * 1.7 + sun_col.rgb * sun_e * 1.9 * sun_k);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// A sharp-topped wood line (conifers) or a rounded one (bare broadleaf), height in metres.
float wood_line(float x, float seed, float tall, float sharp) {
	float base = fx_vnoise(vec2(x * 0.08, seed)) * 0.7 + fx_vnoise(vec2(x * 0.31, seed + 3.0)) * 0.3;
	float tooth = 1.0 - abs(fract(x * 1.6 + fx_hash(vec2(floor(x * 1.6), seed)) * 0.4) - 0.5) * 2.0;
	float round_top = fx_vnoise(vec2(x * 1.3, seed + 7.0));
	return tall * (0.55 + 0.45 * base) * mix(0.75 + 0.25 * round_top, 0.55 + 0.45 * tooth, sharp);
}

// A far village: gabled houses in clusters, a church tower now and then, grain
// towers where the region has them. Height in metres; 0 where there is none.
float town_line(float x, float seed) {
	float here = step(1.0 - town * 0.8, fx_vnoise(vec2(x * 0.025, seed + 1.0)));
	float lot = floor(x * 0.16);
	float f = fract(x * 0.16);
	float h = fx_hash(vec2(lot, seed));
	float wall = 0.6 + 0.9 * h;
	float roof = (0.5 - abs(f - 0.5)) * (0.9 + 0.6 * fx_hash(vec2(lot, seed + 2.0)));
	float house = (f > 0.08 && f < 0.92) ? wall + roof : 0.0;
	house *= here * step(0.25, fx_hash(vec2(lot, seed + 4.0)));
	// A church tower: a narrow shaft with a pointed cap, over the village.
	float t = fract(x * 0.018 + seed * 0.37);
	if (here > 0.5 && fx_hash(vec2(floor(x * 0.018 + seed * 0.37), seed + 5.0)) < spire) {
		float cx = abs(t - 0.5) * 55.0;
		house = max(house, cx < 0.6 ? 3.0 + max(0.0, 2.4 - cx * 4.0) : 0.0);
	}
	// Grain towers: a few tall round bins standing together (no smoke).
	float s = fract(x * 0.012 + seed);
	if (fx_hash(vec2(floor(x * 0.012 + seed), seed + 9.0)) < silo) {
		float sx = abs(s - 0.5) * 83.0;
		house = max(house, sx < 3.0 ? 4.4 + 0.2 * (1.0 - abs(fract(sx) - 0.5) * 2.0) : 0.0);
	}
	return house;
}

void fragment() {
	// Where this point of the card falls on the train's plane.
	vec2 p = vec2(wpos.x, wpos.y - view_dir.y * (wpos.z - plane_z) / view_dir.z);
	float h = p.y - horizon;
	float rel = p.x - cam_x;
	vec3 snow_alb = lin(vec3(0.86, 0.87, 0.89));
	vec3 col;

	// ---- sky
	float sx = rel / 9.0;
	vec2 sun_p = vec2(sun_at.x * 1.2, sun_at.y * 0.16);
	vec2 d = vec2(sx - sun_p.x, (h - sun_p.y) / 9.0);
	float r = length(d * vec2(1.0, 1.6));
	float t = 1.0 - exp(-max(h, 0.0) / 3.2);
	col = mix(sky_low.rgb, sky_top.rgb, t);
	float glow = exp(-r * 2.6) * (1.0 - night) * (1.0 - 0.7 * veil);
	col = mix(col, sun_glow.rgb, glow * 0.75);
	if (photo_on > 0.0) {
		// The photo's sun (the band's middle) stands where the drawn sun is.
		vec2 suv = vec2(0.5 + (sx - sun_p.x) * 0.14, 1.0 - clamp(h / 8.0, 0.0, 1.0));
		vec3 ph = texture(sky_a, suv).rgb * sky_w.x;
		vec3 mean_c = textureLod(sky_a, vec2(0.5), 10.0).rgb * sky_w.x;
		if (sky_w.y > 0.001) {
			ph += texture(sky_b, suv).rgb * sky_w.y;
			mean_c += textureLod(sky_b, vec2(0.5), 10.0).rgb * sky_w.y;
		}
		if (sky_w.z > 0.001) {
			ph += texture(sky_c, suv).rgb * sky_w.z;
			mean_c += textureLod(sky_c, vec2(0.5), 10.0).rgb * sky_w.z;
		}
		const vec3 LUM = vec3(0.2126, 0.7152, 0.0722);
		float lm = max(dot(mean_c, LUM), 0.02);
		vec3 shaped = col * (dot(ph, LUM) / lm);
		vec3 own = ph * (dot(col, LUM) / lm);
		col = mix(col, mix(shaped, own, dot(sky_hue, sky_w)), photo_on);
	}
	// Cloud: bands that flatten toward the line, lit on the sun's side.
	vec2 q = vec2(rel * 0.045 + scroll * 0.0015 + TIME * 0.006 * (0.3 + fx_wind.z), h * 0.22 + 2.0 / (h + 2.5));
	float n = fx_fbm2(q * vec2(1.0, 1.7));
	float dens = smoothstep(1.0 - cloud - 0.12, 1.0 - cloud + 0.22, n) * smoothstep(-0.2, 0.8, h);
	vec3 belly = mix(sky_low.rgb * 0.62, lin(vec3(0.42, 0.43, 0.45)) * lum, veil);
	vec3 rim = mix(belly, sun_glow.rgb, exp(-r * 4.0) * (1.0 - veil) * 0.8);
	col = mix(col, mix(belly, rim, smoothstep(0.4, 0.9, n)), dens * 0.85 * (1.0 - photo_on));
	// Light through the gaps: soft rays from the sun where the cloud breaks.
	float shafts = sun_vis * cloud * (1.0 - cloud) * 4.0 * (1.0 - night);
	if (shafts > 0.02) {
		float a = atan(d.y, d.x);
		float ray = pow(fx_vnoise(vec2(a * 9.0, 1.0)), 3.0) * exp(-r * 1.6) * (1.0 - dens);
		col += sun_glow.rgb * ray * shafts * 0.35;
	}
	// The sun's disc, low and soft.
	col = mix(col, sun_glow.rgb * 1.08, (1.0 - smoothstep(0.035, 0.05, r)) * sun_vis);
	// Haze toward the line.
	float far_k = clamp(0.22 + haze * 0.6 + mist * 0.12, 0.0, 0.92);

	// ---- the far line (over the train's roof)
	float xf = rel + cam_x * 0.08 + scroll * 0.03;
	float hill = hills * (0.4 + 1.4 * fx_vnoise(vec2(xf * 0.012, 2.0))) + 0.12 * fx_vnoise(vec2(xf * 0.05, 4.0));
	// Far away: the wood's crowns and the houses are small on the plane.
	float wood_far = forest * wood_line(xf * 2.2, 1.0, 0.95, conifer) * step(0.4, fx_vnoise(vec2(xf * 0.015, 8.0)) + forest * 0.55);
	float town_far = town_line(xf * 3.5, 3.0) * 0.32;
	float line = hill + max(wood_far, town_far);
	if (h < line && h > -0.05) {
		vec3 alb = mix(lin(vec3(0.16, 0.20, 0.17)), lin(vec3(0.26, 0.24, 0.22)), 1.0 - conifer);
		if (town_far > wood_far) {
			// Walls take the low sun, roofs are darker red-brown.
			alb = h - hill > town_far - 0.2 ? lin(vec3(0.30, 0.20, 0.18)) : lin(vec3(0.46, 0.42, 0.38));
		}
		vec3 sil = lit(alb, 0.6);
		// Snow on the tops and the open slopes.
		sil = mix(sil, lit(snow_alb, 0.6), snow * 0.5 * smoothstep(line - 0.2, line, h + 0.12));
		col = mix(sil, sky_low.rgb, far_k);
	}

	// ---- the field behind the train (seen between the cars) and the wood near the line
	float xm = rel + cam_x * 0.4 + scroll * 0.3;
	float mid_mask = step(0.35, fx_vnoise(vec2(xm * 0.02, 12.0)) + forest * 0.5);
	float wood_mid = forest * mid_mask * wood_line(xm * 0.35, 5.0, 3.0, conifer);
	float mid_base = horizon - 1.2;
	if (h < 0.0 && p.y < mid_base + wood_mid && p.y > mid_base - 0.3 && wood_mid > 0.05) {
		// Dark spruce and pine, bare broadleaf, white birch stems between.
		float lane = floor(xm * 2.3);
		float stem = step(0.84, fract(xm * 2.3 + fx_hash(vec2(lane, 6.0)))) * step(fx_hash(vec2(lane, 7.0)), birch);
		vec3 green = mix(lin(vec3(0.14, 0.21, 0.16)), lin(vec3(0.28, 0.25, 0.23)), 1.0 - conifer) * (0.8 + 0.4 * fx_vnoise(p * 3.0));
		green = mix(green, lin(vec3(0.55, 0.38, 0.20)), leaves * (1.0 - conifer) * 0.75);
		green = mix(green, snow_alb, snow * 0.5 * step(0.55, fx_vnoise(p * vec2(4.0, 9.0))));
		vec3 bark = mix(lin(vec3(0.84, 0.84, 0.80)), lin(vec3(0.10, 0.10, 0.10)), step(0.8, fx_vnoise(vec2(xm * 9.0, p.y * 6.0))));
		col = lit(mix(green, bark, stem), 0.7);
		col = mix(col, sky_low.rgb, far_k * 0.6);
	} else if (h < 0.0 && p.y > ground_top) {
		// Open field running to the line: snow with long drifts, dark wet earth,
		// or a lake (open water gives the sky back, ice is pale and milky).
		float depth = clamp(-h / 5.0, 0.0, 1.0);
		vec3 earth = mix(lin(vec3(0.30, 0.27, 0.22)), lin(vec3(0.30, 0.34, 0.24)), 0.5 * (1.0 - leaves));
		// Drifts: their sun side takes the hour's light, the troughs only the sky's.
		float drift_f = fx_vnoise(vec2(xm * 0.04, p.y * 1.8));
		vec3 field = lit(mix(earth, snow_alb * (0.94 + 0.06 * fx_vnoise(vec2(xm * 0.2, p.y * 3.0))), snow), mix(0.25, 1.0, drift_f));
		float lake = step(1.0 - water * 0.75, fx_vnoise(vec2(xm * 0.01, 20.0))) * step(-2.2, h);
		vec3 sky_back = mix(sky_low.rgb, sky_top.rgb, clamp(-h / 3.0, 0.0, 1.0));
		vec3 lake_col = mix(sky_back * 0.8, lit(lin(vec3(0.66, 0.70, 0.74)), 0.7), ice);
		col = mix(field, lake_col, lake);
		col = mix(col, sky_low.rgb, (1.0 - depth) * far_k * 0.8);
	}

	// ---- poles keeping the beat (track side, behind the train)
	vec3 post_col = lit(lin(vec3(0.20, 0.18, 0.16)), 0.4);
	float xp = p.x + scroll * 0.85;
	float pole_f = fract(xp / 45.0) * 45.0;
	if (pole_f < 0.2 && p.y > ground_top && p.y < 7.2) {
		col = post_col;
	}
	// Cross arm (telegraph) or the mast's reach over the line (catenary).
	float arm = catenary > 0.5 ? step(pole_f, 2.4) * step(6.6, p.y) * step(p.y, 6.78) : step(pole_f, 0.9) * step(6.7, p.y) * step(p.y, 6.84);
	col = mix(col, post_col, arm);

	// ---- the ground in front of the train, rushing by
	if (p.y < ground_top) {
		float g = ground_top - p.y;              // metres below the rail
		float xn = p.x + scroll;
		// Motion streaks: noise stretched along the track.
		float streak = fx_vnoise(vec2(xn * 0.35, g * 5.0)) * 0.6 + fx_vnoise(vec2(xn * 0.09, g * 13.0)) * 0.4;
		vec3 bed = mix(lin(vec3(0.24, 0.23, 0.22)), lin(vec3(0.36, 0.34, 0.31)), streak);
		vec3 slope = mix(lin(vec3(0.34, 0.31, 0.26)), lin(vec3(0.30, 0.34, 0.24)), 1.0 - leaves * 0.5) * (0.8 + 0.35 * streak);
		vec3 near_field = slope;
		// Snow lies thick on the slope and the field, thin on the bed.
		bed = mix(bed, snow_alb * (0.8 + 0.15 * streak), snow * 0.5);
		slope = mix(slope, snow_alb * (0.88 + 0.12 * streak), snow * 0.92);
		near_field = mix(near_field, snow_alb * (0.9 + 0.1 * streak), snow);
		// Wet: darker earth with the sky in the furrows and puddles.
		vec3 sky_back = mix(sky_low.rgb, sky_top.rgb, 0.4);
		float furrow = step(0.6, fract(g * 1.6 + fx_vnoise(vec2(xn * 0.05, 3.0)) * 0.6));
		vec3 alb = g < 0.5 ? bed : (g < 1.8 ? slope : near_field);
		// The slope's face turns a little from the sun; the field's drifts catch it
		// on one side and lie in the sky's blue on the other.
		// Long low drifts lying along the line (stretched, soft: never blotches).
		float drift_n = fx_vnoise(vec2(xn * 0.025, g * 1.4)) * 0.7 + fx_vnoise(vec2(xn * 0.06, g * 3.1 + 5.0)) * 0.3;
		float ripple = 0.5 + 0.5 * sin(g * 21.0 + fx_vnoise(vec2(xn * 0.1, g)) * 4.0);
		col = lit(alb, g < 0.5 ? 0.85 : (g < 1.8 ? 0.55 : mix(0.12, 1.0, smoothstep(0.25, 0.75, drift_n)) * mix(0.9, 1.0, ripple * snow)));
		col = mix(col, mix(col * 0.6, sky_back * 0.55, furrow * 0.6), wet * (1.0 - snow) * step(1.8, g));
		// Dry stalks through the snow by the fence.
		float stalk = step(0.8, fract(xn * 6.0)) * step(0.9, fx_hash(vec2(floor(xn * 6.0), 2.0))) * step(1.5, g) * step(g, 2.3 - 0.5 * fx_hash(vec2(floor(xn * 6.0), 3.0)));
		col = mix(col, lit(lin(vec3(0.36, 0.30, 0.22)), 0.6), stalk * 0.8);
		// A lake or pond some way off the line: open water or ice.
		float pond = step(1.0 - water * 0.6, fx_vnoise(vec2(xn * 0.006, 31.0))) * step(2.6, g);
		if (pond > 0.5) {
			float shore = smoothstep(2.6, 3.0, g);
			vec3 refl = mix(sky_low.rgb, sky_top.rgb, clamp((g - 2.6) / 4.0, 0.0, 1.0));
			refl = mix(refl, sun_glow.rgb, exp(-abs(sx - sun_p.x) * 3.0) * (1.0 - night) * (1.0 - veil) * 0.7);
			// The sun's path on open water.
			float glint = (1.0 - ice) * sun_vis * (1.0 - smoothstep(0.03, 0.09, abs(sx - sun_p.x))) * step(0.55, fx_vnoise(vec2(xn * 2.0, g * 8.0 - TIME)));
			float wave = 0.9 + 0.1 * sin(g * 30.0 + fx_vnoise(vec2(xn * 0.2, g * 2.0)) * 6.0 + TIME * 0.8);
			vec3 open_water = refl * 0.68 * wave + sun_glow.rgb * glint * 0.7;
			vec3 iced = mix(lit(lin(vec3(0.66, 0.70, 0.75)), 0.7), refl, 0.35);
			// Snow blown across the ice in long soft streaks.
			iced = mix(iced, lit(snow_alb, 0.9), snow * 0.6 * smoothstep(0.4, 0.7, fx_vnoise(vec2(xn * 0.05, g * 2.5))));
			iced *= 1.0 - 0.25 * pow(1.0 - abs(fx_vnoise(vec2(xn * 0.8, g * 1.5)) * 2.0 - 1.0), 12.0);
			col = mix(col, mix(open_water, iced, ice), shore);
		}
		// Fence posts by the line, flying past.
		float post = fract(xn / 3.2) * 3.2;
		if (post < 0.09 && g > 1.0 && g < 1.9) {
			col = post_col;
		}
		// At night the windows' light lies on the bank below them.
		float win = (1.0 - smoothstep(0.05, 0.32, abs(fract(p.x / 4.25) - 0.5))) * (1.0 - smoothstep(0.1, 1.3, g)) * smoothstep(0.0, 0.15, g);
		col += lamp.rgb * win * night * 0.07;
	}

	// ---- weather over all, night, lightning, the pause
	col = mix(col, sky_low.rgb, falling * 0.25 * (1.0 - smoothstep(0.0, 6.0, abs(h))));
	col += fx_flash * 0.5 * smoothstep(0.0, 3.0, h) * vec3(0.8, 0.82, 0.86);
	ALBEDO = fx_photo(col, fx_fade);
}
