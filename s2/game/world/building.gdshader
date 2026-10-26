shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;
// 건물 키트 셰이더(명세 건물 v1 5장). 조각에는 그림이 없고 정점 색에 칠 구역 번호의
// 비트(R 1자리, G 2자리, B 4자리)와 날씨 받음(A: 바깥에 드러난 면 1, 안쪽 0)만 있다.
// 구역마다 색과 이어지는 무늬를 세계 좌표로 그리고, weathered의 날씨와 색 보정,
// world_vis의 시야 가림과 등불 빛, 가림 구멍(3.3)과 들고 날 때의 점박이(3.4)를 한 번에 한다.
#include "res://fx/shaders/fx_common.gdshaderinc"

// 시야 그림: world_vis와 같은 것(R 지금 봄, G 본 적 있음, B 등불 빛).
uniform sampler2D vis : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(120.0, 70.0);
uniform float mask_on = 1.0;
uniform vec3 lamp_color : source_color = vec3(1.0, 0.64, 0.30);
uniform float lamp_gain = 0.0;
// 칠 표(첫 정차, 결정 408에서 시안 그림을 보고 정함). 벽면 색은 건물마다 paint로 받는다.
// source_color라 선형으로 바뀌어 어두워진다: 지붕이 눈 바닥(밝기 127) 옆에서 60~70쯤 되게 맞췄다.
uniform vec3 stone_color : source_color = vec3(0.58, 0.57, 0.55);
uniform vec3 brick_color : source_color = vec3(0.55, 0.40, 0.34);
uniform vec3 wood_color : source_color = vec3(0.45, 0.36, 0.29);
uniform vec3 glass_color : source_color = vec3(0.09, 0.11, 0.13);
uniform vec3 slate_color : source_color = vec3(0.52, 0.54, 0.58);
uniform vec3 tile_color : source_color = vec3(0.60, 0.45, 0.38);
uniform vec3 metal_color : source_color = vec3(0.32, 0.32, 0.34);
// 결정 286 색 보정: weathered.gdshader와 같은 기본값(FxState.MODEL_GRADE).
uniform float grade_saturation : hint_range(0.0, 1.0) = 0.45;
uniform float grade_value : hint_range(0.0, 1.0) = 0.82;
uniform vec3 grade_cool : source_color = vec3(0.78, 0.85, 0.95);
uniform float grade_cool_mix : hint_range(0.0, 1.0) = 0.35;
// 안쪽 면의 어둠(9.6 그림, 가안). 등불 빛(B)이 닿으면 걷힌다.
uniform float indoor_dark : hint_range(0.0, 1.0) = 0.55;
// 가림 구멍: 화면 가운데(플레이어) 둘레에서 플레이어보다 카메라 쪽 면만 점박이로 비운다.
uniform vec3 hole_center = vec3(0.0, -1000.0, 0.0);
uniform float hole_radius = 3.5;
uniform float hole_strength : hint_range(0.0, 1.0) = 0.8;
uniform vec3 cam_back = vec3(0.0, 0.788, 0.616);
// 열린 건물 바닥(xz 사각형, 바닥 높이)을 가리는 다른 건물의 면도 같은 점박이로 비운다.
uniform vec4 open_rect = vec4(0.0);
uniform float open_floor = -1000.0;
uniform float open_building = -1.0;

// 노드마다: 점박이로 사라짐(0 다 보임, 1 다 사라짐), 고정 시야(x < 0이면 칸에서 읽음),
// 벽면 칠(rgb)과 지붕 갈래(a: 0 슬레이트, 1 기와), 건물 번호.
instance uniform float fade = 0.0;
instance uniform vec2 seen_fixed = vec2(-1.0, -1.0);
instance uniform vec4 paint = vec4(0.58, 0.55, 0.50, 0.0);
instance uniform float building_id = -1.0;
// 생활 색(사용자 2026-10-24, 분위기 틀): 바깥 나무(문짝·덧문·창틀)에 남은 칠(rgb)과
// 남은 정도(a). 회벽의 안쪽 면은 벽지, 커튼(천 구역 6)은 건물·층마다 다른 색이다.
// 칠은 모델 색 보정을 거치되 덜 누른다(accent_saturation). 0이면 칠 없음.
instance uniform vec4 accent = vec4(0.0);
// 이 층이 지붕 바로 밑(맨 위 층)이면 1: 처마 밑에 고드름(fx_cold.z), 녹을 땐 물 자국.
instance uniform float eave = 0.0;
uniform float accent_saturation : hint_range(0.0, 1.0) = 0.75;
uniform float level_h = 3.0;

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// 벽지·커튼 색(바랜 것만). 건물·층의 번호로 고른다.
const vec3 PAPERS[5] = vec3[5](vec3(0.60, 0.46, 0.43), vec3(0.50, 0.56, 0.46), vec3(0.66, 0.56, 0.38), vec3(0.48, 0.52, 0.58), vec3(0.72, 0.68, 0.56));
const vec3 CURTAINS[6] = vec3[6](vec3(0.52, 0.30, 0.22), vec3(0.70, 0.56, 0.26), vec3(0.31, 0.45, 0.31), vec3(0.75, 0.70, 0.58), vec3(0.31, 0.37, 0.52), vec3(0.80, 0.79, 0.75));

// 줄눈이나 판자 틈: 무늬 칸 가장자리 폭 w(칸 비율)를 화면 크기에 맞춰 부드럽게.
float seam(vec2 f, vec2 w) {
	vec2 aa = fwidth(f) + 1e-4;
	vec2 e = smoothstep(w - aa, w + aa, f) * (vec2(1.0) - smoothstep(vec2(1.0) - aa, vec2(1.0), f));
	return 1.0 - e.x * e.y;
}

void fragment() {
	vec3 n = normalize(w_nrm);
	// 점박이: 들고 남(fade), 가림 구멍, 열린 건물을 가리는 이웃.
	float dith = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float gone = fade;
	// 그림자 그리기(해가 보는 쪽)에서는 구멍을 뚫지 않는다: 땅의 그림자에 점박이가 생긴다.
	bool from_camera = dot(INV_VIEW_MATRIX[2].xyz, cam_back) > 0.99;
	vec3 rel = w_pos - hole_center;
	float toward = dot(rel, cam_back);
	float off = length(rel - toward * cam_back);
	float hole = (1.0 - smoothstep(hole_radius - 1.0, hole_radius, off)) * smoothstep(0.15, 0.6, toward);
	gone = max(gone, from_camera ? hole * hole_strength : 0.0);
	if (from_camera && open_building >= 0.0 && abs(building_id - open_building) > 0.5) {
		float t = (w_pos.y - open_floor) / max(cam_back.y, 0.05);
		vec2 q = (w_pos - cam_back * t).xz;
		if (t > 0.0 && q.x > open_rect.x && q.y > open_rect.y && q.x < open_rect.z && q.y < open_rect.w) {
			gone = max(gone, hole_strength);
		}
	}
	if (dith < gone) {
		discard;
	}

	int zone = int(COLOR.r + 0.5) + 2 * int(COLOR.g + 0.5) + 4 * int(COLOR.b + 0.5);
	float exposed = COLOR.a;
	float up = clamp(n.y, 0.0, 1.0);
	// 선 면의 좌표: 면을 따라(가로) 와 높이(세로).
	float run = abs(n.x) > abs(n.z) ? w_pos.z : w_pos.x;
	vec2 fp = vec2(run, w_pos.y);
	float big = fx_fbm2(w_pos.xz * 0.35 + vec2(w_pos.y * 0.21, 0.0));
	float fine = fx_vnoise(fp * 3.1 + w_pos.xz * 0.7);
	vec3 base;
	float rough = 0.9;
	float metal = 0.0;
	float porous = 0.6;
	// 생활 색이 칠해진 정도: 모델 색 보정을 덜 받는다.
	float lively = 0.0;
	if (zone == 0) {
		// 회벽: 큰 얼룩, 떨어져 나간 자리에 벽돌.
		base = paint.rgb * (0.86 + 0.22 * big) * (0.95 + 0.08 * fine);
		vec2 bc = fp / vec2(0.5, 0.18);
		bc.x += 0.5 * mod(floor(bc.y), 2.0);
		vec3 brick = brick_color * (0.82 + 0.3 * fx_hash(floor(bc)));
		brick = mix(stone_color * 0.95, brick, 1.0 - seam(fract(bc), vec2(0.05, 0.11)));
		float bare = smoothstep(0.6, 0.7, fx_fbm2(fp * 0.8 + vec2(7.3, 1.9))) * exposed * (1.0 - up);
		base = mix(base, brick, bare);
		if (exposed < 0.5 && up < 0.5 && building_id >= 0.0) {
			// 안쪽 벽: 건물·층마다 바랜 벽지(세로 줄이나 잔무늬), 군데군데 뜯겨 회벽이 드러남.
			float pick = fx_hash(vec2(building_id, floor(w_pos.y / level_h) + 3.0));
			vec3 paper = PAPERS[int(pick * 4.99)];
			float stripe = pick > 0.5 ? smoothstep(0.35, 0.5, abs(fract(run * 2.4) - 0.5)) : smoothstep(0.62, 0.8, fx_vnoise(fp * 7.0));
			paper *= 0.9 + 0.12 * stripe;
			float torn = smoothstep(0.62, 0.7, fx_fbm2(fp * 1.1 + vec2(building_id, 2.0)));
			base = mix(paper * (0.9 + 0.1 * big), base, torn);
			lively = 1.0 - torn;
		}
	} else if (zone == 1) {
		// 석재: 큰 돌과 줄눈.
		vec2 sc = (up > 0.5 ? w_pos.xz : fp) / vec2(0.55, 0.3);
		sc.x += 0.5 * mod(floor(sc.y), 2.0);
		base = stone_color * (0.84 + 0.26 * fx_hash(floor(sc))) * (1.0 - 0.3 * seam(fract(sc), vec2(0.04, 0.07)));
		porous = 0.4;
	} else if (zone == 2) {
		// 나무: 판자 틈과 결.
		float k = (up > 0.5 ? w_pos.x : run) / 0.16;
		base = wood_color * (0.8 + 0.3 * fx_hash(vec2(floor(k), 3.0)));
		base *= (1.0 - 0.35 * seam(vec2(fract(k), 0.5), vec2(0.07, 0.0))) * (0.9 + 0.15 * fx_vnoise(vec2(k * 2.0, w_pos.y * 9.0)));
		porous = 0.8;
		if (exposed > 0.5 && up < 0.5 && accent.a > 0.0) {
			// 바깥 나무에 남은 칠: 결 따라 벗겨져 나무가 드러난다.
			float peel = smoothstep(0.45, 0.6, fx_fbm2(vec2(k * 0.7, w_pos.y * 2.3) + building_id) + (1.0 - accent.a) * 0.5);
			vec3 painted = accent.rgb * (0.88 + 0.16 * big) * (1.0 - 0.2 * seam(vec2(fract(k), 0.5), vec2(0.07, 0.0)));
			base = mix(painted, base, peel);
			lively = 1.0 - peel;
		}
	} else if (zone == 3) {
		base = glass_color * (0.85 + 0.3 * fine);
		rough = 0.12;
		porous = 0.0;
	} else if (zone == 6) {
		// 커튼(building_view ZONE_CLOTH): 창 안쪽에 걸린 천. 열림·닫힘은 그 모형이 보여 주고,
		// 색은 건물·층마다 하나(한 집의 커튼은 맞춘다), 창마다 조금 바래고 주름이 세로로 진다.
		float level = floor(w_pos.y / level_h);
		float pick = fx_hash(vec2(building_id * 7.0 + 1.3, level));
		float cell = fx_hash(vec2(floor(run * 0.9) + building_id * 7.0, level));
		// 안에 걸려 벽지(PAPERS)보다 밝지 않게 누른다.
		vec3 cloth = CURTAINS[int(pick * 5.99)] * (0.75 + 0.14 * cell);
		float fold = 0.78 + 0.22 * sin(run * 26.0 + cell * 9.0);
		base = cloth * fold * (0.95 + 0.08 * fine);
		rough = 1.0;
		porous = 0.4;
		lively = 0.8;
	} else if (zone == 4) {
		// 지붕: 높이로 줄을 긋고 용마루 쪽으로 엇갈린 이음.
		vec3 roof = mix(slate_color, tile_color, paint.a);
		if (up > 0.97) {
			// 평지붕: 높이가 한결같아 기와 줄이 안 생긴다. 1 m 폭 루핑 띠와 엇갈린 이음.
			vec2 fc = w_pos.xz / vec2(0.95, 3.0);
			fc.y += 0.37 * fx_hash(vec2(floor(fc.x), 5.0));
			base = slate_color * 1.15 * (0.88 + 0.2 * fx_hash(floor(fc))) * (0.9 + 0.18 * big);
			base *= 1.0 - 0.25 * seam(fract(fc), vec2(0.03, 0.02));
		} else {
			float ax = abs(n.x) > abs(n.z) ? w_pos.z : w_pos.x;
			vec2 tc = vec2(ax / 0.32, w_pos.y / 0.15);
			tc.x += 0.5 * mod(floor(tc.y), 2.0);
			base = roof * (0.84 + 0.28 * fx_hash(floor(tc))) * (1.0 - 0.4 * seam(fract(tc), vec2(0.05, 0.16)));
		}
		porous = 0.5;
	} else {
		base = metal_color * (0.8 + 0.3 * big);
		rough = 0.5;
		metal = 0.6;
		porous = 0.1;
	}
	base = mix(fx_model_grade(base, grade_saturation, grade_value, grade_cool, grade_cool_mix),
			fx_model_grade(base, accent_saturation, grade_value, grade_cool, grade_cool_mix * 0.6), lively);

	// 날씨(weathered와 같은 결): 땅에서 오르는 때, 젖음, 위를 보는 면의 눈, 서리.
	float g = (1.0 - smoothstep(0.0, 0.9, w_pos.y)) * (0.55 + 0.45 * big) * exposed * 0.6;
	base = mix(base, base * vec3(0.34, 0.32, 0.31), g);
	float wet = clamp(fx_wet, 0.0, 1.0) * exposed;
	base *= mix(1.0, 0.55, porous * wet);
	rough = mix(rough, min(rough, 0.35), wet * 0.8);
	float s = clamp(fx_snow, 0.0, 1.0) * exposed;
	float t = 1.0 - 0.9 * s;
	vec2 sp = mat2(vec2(0.82, 0.57), vec2(-0.57, 0.82)) * w_pos.xz;
	float sn = fx_fbm2(sp * 0.28) * 0.75 + fx_vnoise(sp * 1.7 + 3.1) * 0.25;
	float lie = up * up * (0.55 + 0.45 * sn);
	float cover = s > 0.001 ? smoothstep(t - 0.12, t + 0.08, lie) : 0.0;
	base = mix(base, FX_SNOW * (0.92 + 0.08 * fine) * mix(1.0, 0.72, wet), cover);
	rough = mix(rough, mix(0.85, 0.5, wet), cover);
	float rime = clamp(fx_frost, 0.0, 1.0) * exposed * (1.0 - cover);
	base = mix(base, FX_RIME, rime * 0.35 * smoothstep(0.35, 0.8, big));

	// 처마 밑 고드름(길이 fx_cold.z): 맨 위 층의 바깥 선 벽 꼭대기에서 아래로 뾰족하게.
	// 얼음이 풀리면(fx_cold.y가 낮으면) 고드름 밑으로 물 자국이 진다.
	float hang = 0.55 * clamp(fx_cold.z, 0.0, 1.0) * eave;
	if (hang > 0.01 && exposed > 0.5 && abs(n.y) < 0.2 && zone != 3) {
		float d = MODEL_MATRIX[3].y + level_h - w_pos.y;
		float k = run * 6.5;
		float len = hang * (0.2 + 0.8 * fx_hash(vec2(floor(k), building_id + 1.0)));
		float f = abs(fract(k) - 0.5);
		float wide = 0.3 * (1.0 - clamp(d / max(len, 0.001), 0.0, 1.0));
		float tooth = step(0.0, d) * step(d, len) * (1.0 - smoothstep(wide - 0.05, wide, f));
		vec3 ice = mix(vec3(0.70, 0.76, 0.82), fx_sky.rgb, 0.3) * (0.85 + 0.3 * (0.5 - f));
		base = mix(base, ice, tooth * 0.9);
		float melt = (1.0 - clamp(fx_cold.y, 0.0, 1.0)) * step(0.62, fx_hash(vec2(floor(run * 3.0), building_id)));
		base *= 1.0 - 0.22 * melt * step(0.0, d) * (1.0 - smoothstep(0.4, 1.6, d)) * (1.0 - tooth);
	}
	// 구름 그림자가 바깥 면 위로 지나간다.
	base *= mix(1.0, fx_cloud_shade(w_pos.xz, TIME), exposed);

	// 시야 가림(world_vis와 같은 셈). 지붕은 건물마다 고정 시야를 받는다(바깥벽 칸의 값).
	vec4 cell = texture(vis, (w_pos.xz - n.xz * 0.1) / map_size);
	vec2 seen = seen_fixed.x >= 0.0 ? seen_fixed : cell.rg;
	float lit = mix(1.0, max(seen.r, mix(fx_sight.x, fx_sight.y, seen.g)), mask_on);
	float grey = dot(base, vec3(0.3, 0.59, 0.11));
	vec3 dimmed = mix(vec3(grey), base, seen.r * 0.6 + 0.4);
	dimmed *= mix(1.0, indoor_dark, (1.0 - exposed) * (1.0 - clamp(cell.b * 2.0, 0.0, 1.0)));
	ALBEDO = fx_photo(dimmed, fx_fade) * lit;
	ROUGHNESS = rough;
	METALLIC = metal * (1.0 - cover);
	float lamp = cell.b * lamp_gain * mix(0.4, 1.0, seen.r) * (1.0 - 0.5 * clamp(fx_fade, 0.0, 1.0));
	EMISSION = lamp_color * (0.25 + 0.75 * grey) * lamp;
}
