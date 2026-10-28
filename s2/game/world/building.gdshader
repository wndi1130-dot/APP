shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;
// 건물 키트 셰이더(명세 건물 v1 5장). 조각에는 그림이 없고 정점 색에 칠 구역 번호의
// 비트(R 1자리, G 2자리, B 4자리)와 날씨 받음(A: 바깥에 드러난 면 1, 안쪽 0)만 있다.
// 구역마다 색과 이어지는 무늬를 세계 좌표로 그리고, weathered의 날씨와 색 보정,
// world_vis의 시야 가림과 등불 빛, 가림 구멍(3.3)과 들고 날 때의 점박이(3.4)를 한 번에 한다.
#include "res://fx/shaders/fx_common.gdshaderinc"
#include "res://game/world/room_finish.gdshaderinc"

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
// 벽면 칠(rgb)과 지붕 색 갈래(a: ROOFS 번호), 건물 번호.
instance uniform float fade = 0.0;
instance uniform vec2 seen_fixed = vec2(-1.0, -1.0);
instance uniform vec4 paint = vec4(0.58, 0.55, 0.50, 0.0);
// 바깥벽 재질(결정 478 1가, building_forms.gd): 0 회칠, 1 벽돌, 2 세로 판자, 3 가로 판자, 4 통나무,
// 5 골함석. 8을 더하면 땅층 아래 돌 기단 띠.
instance uniform float wall_kind = 0.0;
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
	// 박공을 물매로 높이만 늘리므로(결정 478) 법선은 늘림을 거슬러 바로잡는다.
	w_nrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

// 지붕 색 갈래(결정 469 C1, sRGB — 쓸 때 선형으로): 슬레이트·바랜 기와·짙은 초록·갈색 널.
// 명암: 지붕은 아스팔트보다 밝고 보도와 비슷한 가운데 단. 옛 칠(슬레이트 0.52~0.58)보다 밝기를
// 15% 안팎 올린다 — 맑은 초겨울 낮엔 해를 등진 비탈이 하늘빛만 받아, 옛 기와 칠도 V 0.15 밑이었다
// (어두운 칸 6% 넘음, 결정 470).
// 4~7은 지역 판(결정 478): 짙은 슬레이트·녹슨 함석·짙은 널·회색 함석. 같은 밝기 단을 지킨다.
const vec3 ROOFS[8] = vec3[8](vec3(0.56, 0.59, 0.65), vec3(0.72, 0.50, 0.40), vec3(0.50, 0.63, 0.52), vec3(0.65, 0.55, 0.44),
	vec3(0.50, 0.52, 0.56), vec3(0.66, 0.48, 0.38), vec3(0.58, 0.49, 0.40), vec3(0.62, 0.63, 0.64));
// 바깥벽 칠과 지붕은 집마다 굴린 색이라 모델 색 보정을 이만큼 덜 받는다(생활 색과 같은 길).
uniform float house_colour : hint_range(0.0, 1.0) = 0.8;

// 벽지·커튼 색(바랜 것만). 건물·층의 번호로 고른다.
const vec3 PAPERS[5] = vec3[5](vec3(0.60, 0.46, 0.43), vec3(0.50, 0.56, 0.46), vec3(0.66, 0.56, 0.38), vec3(0.48, 0.52, 0.58), vec3(0.72, 0.68, 0.56));
// 살림방 벽(room_finish, 결정 469 C3, 사용자 10-28 「색깔도 다양하게」, 선형): 갈래마다 다섯 판, 판마다
// 칠과 무늬(0 민, 1 세로 줄, 2 잔꽃, 3 다마스크). 흰 칠 반사율 0.8을 넘지 않고, 옛 벽지(PAPERS, 선형
// 밝기 0.50~0.68)보다 한 단 밝다 — 잘라 보이기로 드러난 방이 밝기 줄(V 0.36) 밑이었다(mood, 낮 채움빛).
// 판벽(나무 허리·온 벽)은 선형 밝기 0.5 밑으로 내려가지 않는다.
const vec3 BED_PAPERS[5] = vec3[5](vec3(0.70, 0.56, 0.52), vec3(0.76, 0.70, 0.56), vec3(0.60, 0.66, 0.55), vec3(0.60, 0.66, 0.74), vec3(0.68, 0.60, 0.68));
const int BED_MOTIF[5] = int[5](2, 2, 1, 2, 3);
const vec3 LIVING_PAPERS[5] = vec3[5](vec3(0.74, 0.62, 0.42), vec3(0.52, 0.62, 0.50), vec3(0.56, 0.62, 0.70), vec3(0.72, 0.56, 0.46), vec3(0.78, 0.72, 0.60));
const int LIVING_MOTIF[5] = int[5](1, 1, 3, 2, 0);
const vec3 KITCHEN_PAINTS[5] = vec3[5](vec3(0.78, 0.74, 0.62), vec3(0.66, 0.74, 0.62), vec3(0.80, 0.74, 0.52), vec3(0.66, 0.72, 0.78), vec3(0.80, 0.68, 0.58));
const vec3 KITCHEN_TILES[5] = vec3[5](vec3(0.78, 0.78, 0.74), vec3(0.78, 0.78, 0.74), vec3(0.78, 0.74, 0.62), vec3(0.62, 0.70, 0.62), vec3(0.66, 0.72, 0.78));
const vec3 BATH_TILES[5] = vec3[5](vec3(0.80, 0.80, 0.77), vec3(0.62, 0.72, 0.76), vec3(0.64, 0.74, 0.66), vec3(0.78, 0.78, 0.74), vec3(0.78, 0.66, 0.64));
const vec3 HALL_PAPERS[5] = vec3[5](vec3(0.60, 0.66, 0.55), vec3(0.74, 0.62, 0.42), vec3(0.66, 0.66, 0.64), vec3(0.68, 0.52, 0.50), vec3(0.78, 0.72, 0.60));
const vec3 DINING_PAPERS[5] = vec3[5](vec3(0.50, 0.60, 0.50), vec3(0.68, 0.50, 0.48), vec3(0.74, 0.64, 0.44), vec3(0.56, 0.62, 0.72), vec3(0.78, 0.72, 0.60));
const vec3 STORE_PAINTS[5] = vec3[5](vec3(0.74, 0.72, 0.68), vec3(0.54, 0.64, 0.54), vec3(0.64, 0.54, 0.44), vec3(0.64, 0.66, 0.66), vec3(0.72, 0.70, 0.64));
// 나무 허리·판벽: 니스 칠 참나무, 산골의 소나무, 물가의 흰 칠 널.
const vec3 OAK_DADO = vec3(0.64, 0.50, 0.34);
const vec3 PINE_WALL = vec3(0.70, 0.54, 0.36);
const vec3 BEADBOARD = vec3(0.70, 0.76, 0.80);
const vec3 CURTAINS[6] =vec3[6](vec3(0.52, 0.30, 0.22), vec3(0.70, 0.56, 0.26), vec3(0.31, 0.45, 0.31), vec3(0.75, 0.70, 0.58), vec3(0.31, 0.37, 0.52), vec3(0.80, 0.79, 0.75));

// 줄눈이나 판자 틈: 무늬 칸 가장자리 폭 w(칸 비율)를 화면 크기에 맞춰 부드럽게.
float seam(vec2 f, vec2 w) {
	vec2 aa = fwidth(f) + 1e-4;
	vec2 e = smoothstep(w - aa, w + aa, f) * (vec2(1.0) - smoothstep(vec2(1.0) - aa, vec2(1.0), f));
	return 1.0 - e.x * e.y;
}

// 바깥벽 재질의 무늬(결정 478 1가). 색은 paint(집 칠과 같은 색 보정 길). 무늬 크기는 지금 벽돌
// 무늬처럼 대각뷰 거리에서 읽히게 실물보다 조금 크다.
vec3 wall_skin(int kind, vec3 tint, vec2 fp, float big, float fine) {
	if (kind == 1) {
		vec2 bc = fp / vec2(0.5, 0.18);
		bc.x += 0.5 * mod(floor(bc.y), 2.0);
		vec3 c = tint * (0.84 + 0.26 * fx_hash(floor(bc))) * (0.94 + 0.1 * big);
		return mix(vec3(0.62, 0.60, 0.56) * 0.85, c, 1.0 - seam(fract(bc), vec2(0.05, 0.11)));
	}
	if (kind == 2) {
		float k = floor(fp.x / 0.3);
		vec3 c = tint * (0.86 + 0.22 * fx_hash(vec2(k, 3.0))) * (0.92 + 0.12 * fx_vnoise(vec2(k * 5.0, fp.y * 1.5)));
		return c * (1.0 - 0.4 * seam(vec2(fract(fp.x / 0.3), 0.5), vec2(0.07, 0.0)));
	}
	if (kind == 3) {
		float k = floor(fp.y / 0.25);
		vec3 c = tint * (0.9 + 0.12 * fx_hash(vec2(3.0, k))) * (0.95 + 0.06 * fine);
		return c * mix(0.74, 1.0, smoothstep(0.0, 0.3, fract(fp.y / 0.25)));
	}
	if (kind == 4) {
		float k = floor(fp.y / 0.3);
		vec3 c = tint * (0.86 + 0.2 * fx_hash(vec2(k, 7.0))) * (0.92 + 0.12 * fx_vnoise(vec2(fp.x * 0.8, k * 3.0)));
		return c * (0.72 + 0.28 * sin(3.14159 * fract(fp.y / 0.3)));
	}
	float rib = 0.5 + 0.5 * sin(fp.x / 0.2 * 6.28318);
	vec3 c = tint * (0.86 + 0.16 * rib) * (0.95 + 0.06 * fine);
	return mix(c, vec3(0.45, 0.31, 0.23), 0.35 * smoothstep(0.6, 0.85, fx_vnoise(vec2(fp.x * 2.5, fp.y * 0.2))));
}

// 벽지 무늬: 바탕 `paper`에 무늬 `motif`(0 민, 1 세로 줄, 2 잔꽃, 3 다마스크). 대각뷰에서 읽히게 실물보다 크다.
vec3 wall_paper(vec3 paper, int motif, vec2 fp, float fine) {
	if (motif == 1) {
		return paper * (0.9 + 0.12 * smoothstep(0.35, 0.5, abs(fract(fp.x * 2.4) - 0.5)));
	}
	if (motif == 2) {
		vec2 g = fp / vec2(0.2, 0.24);
		g.x += 0.5 * mod(floor(g.y), 2.0);
		vec2 l = fract(g) - 0.5;
		float m = 1.0 - smoothstep(0.1, 0.17, length(l * vec2(1.0, 1.2)));
		return paper * (0.97 + 0.04 * fine) * (1.0 - 0.14 * m);
	}
	if (motif == 3) {
		vec2 g = fp / vec2(0.36, 0.48);
		g.x += 0.5 * mod(floor(g.y), 2.0);
		vec2 l = abs(fract(g) - 0.5);
		float d = l.x * 1.3 + l.y;
		float m = smoothstep(0.3, 0.34, d) * (1.0 - smoothstep(0.38, 0.42, d)) + (1.0 - smoothstep(0.1, 0.14, d));
		return paper * (0.94 + 0.1 * m);
	}
	return paper * (0.95 + 0.06 * fine);
}

// 세로 널 판벽(높이 `top`까지): 널 폭 `w`, 널마다 한 끗 다른 결, 위 끝에 짙은 갓 띠 6 cm.
vec3 wall_boards(vec3 wood, float run, float rise, float top, float w) {
	float k = floor(run / w);
	vec3 c = wood * (0.88 + 0.16 * fx_hash(vec2(k, 5.0))) * (0.94 + 0.08 * fx_vnoise(vec2(k * 3.0, rise * 6.0)));
	c *= 1.0 - 0.3 * seam(vec2(fract(run / w), 0.5), vec2(0.06, 0.0));
	return mix(c, wood * 0.74, step(top - 0.06, rise) * step(rise, top));
}

// 지역의 빛깔(결정 478 지역 무리): 철도 공업지는 그을려 잿빛, 산골은 송진 빛, 물가는 바래 차갑고, 빈 선로는 수수하다.
vec3 wall_grade(vec3 c, int region) {
	vec3 grey = vec3(dot(c, vec3(0.2126, 0.7152, 0.0722)));
	if (region == 1) {
		return mix(c, grey, 0.22);
	} else if (region == 2 || region == 3) {
		return c * vec3(1.03, 1.0, 0.93);
	} else if (region == 4) {
		return mix(c, grey, 0.15) * vec3(0.98, 1.01, 1.04);
	} else if (region == 5) {
		return mix(c, grey, 0.3);
	}
	return c;
}

// 살림방 벽 하나(room_finish 갈래·판·지역). `torn`은 벽지가 뜯겨 회벽이 드러난 정도, `lively`는 생활 색 몫.
vec3 room_wall(int kind, int region, int roll, vec2 fp, float rise, float big, float fine, float torn, vec3 plaster, inout float lively) {
	bool hills = region == 2 || region == 3;
	vec3 c;
	float papered = 1.0;
	if (kind == 2 || kind == 3) {
		// 부엌은 1.2 m, 욕실은 1.5 m까지 15 cm 타일, 그 위 끝에 짙은 띠 4 cm, 위는 칠.
		float top = kind == 2 ? 1.2 : 1.5;
		vec2 tc = vec2(fp.x, rise) / 0.15;
		vec3 tile = (kind == 2 ? KITCHEN_TILES[roll] : BATH_TILES[roll]) * (0.95 + 0.07 * fx_hash(floor(tc)));
		tile *= 1.0 - 0.22 * seam(fract(tc), vec2(0.05, 0.05));
		vec3 upper = (kind == 2 ? KITCHEN_PAINTS[roll] : vec3(0.78, 0.76, 0.70)) * (0.95 + 0.06 * fine);
		c = rise < top ? tile : upper;
		c = mix(c, vec3(0.42, 0.44, 0.43), step(top, rise) * (1.0 - step(top + 0.04, rise)));
		lively = 0.8;
		return wall_grade(c, region);
	}
	if (kind == 7) {
		// 창고: 흰 회칠, 아래 1.2 m만 기름칠(초록·밤색), 잿빛 칠. 무늬 없이 얼룩만.
		vec3 paint = STORE_PAINTS[roll];
		vec3 wash = vec3(0.72, 0.70, 0.66);
		c = (roll == 1 || roll == 2) && rise >= 1.2 ? wash : paint;
		c = mix(c, c * 0.7, step(1.18, rise) * step(rise, 1.22) * float(roll == 1 || roll == 2));
		c *= (0.88 + 0.18 * big) * (0.95 + 0.06 * fine);
		lively = 0.5;
		return wall_grade(c, region);
	}
	if (hills && roll >= 3 && (kind == 1 || kind == 4 || kind == 6)) {
		// 산골 집의 방은 다섯에 둘이 온 벽 소나무 널.
		lively = 0.8;
		return wall_grade(wall_boards(PINE_WALL, fp.x, rise, 99.0, 0.18), region);
	}
	if (region == 4 && roll == 4 && kind == 1) {
		// 물가의 침실: 흰 칠 널벽.
		lively = 0.8;
		return wall_grade(wall_boards(BEADBOARD, fp.x, rise, 99.0, 0.1), region);
	}
	vec3 paper;
	int motif = 0;
	float dado = 0.0;
	if (kind == 1) {
		paper = BED_PAPERS[roll];
		motif = BED_MOTIF[roll];
	} else if (kind == 4) {
		paper = LIVING_PAPERS[roll];
		motif = LIVING_MOTIF[roll];
		// 판 3은 나무 허리, 판 4는 그림 띠.
		dado = roll == 3 ? 0.9 : 0.0;
	} else if (kind == 5) {
		paper = HALL_PAPERS[roll];
		motif = roll % 2 == 0 ? 1 : 2;
		dado = 0.9;
	} else {
		paper = DINING_PAPERS[roll];
		motif = 3;
		dado = 0.95;
	}
	c = wall_paper(paper, motif, fp, fine) * (0.9 + 0.1 * big);
	c = mix(c, plaster, torn);
	if (kind == 4 && roll == 4) {
		// 그림 띠: 2.3 m에 짙은 나무 띠 3 cm.
		c = mix(c, OAK_DADO * 0.8, step(2.3, rise) * step(rise, 2.33));
	}
	if (dado > 0.0 && rise < dado) {
		// 나무 허리(철도 공업지는 짙은 초록 기름칠 허리).
		c = region == 1 ? vec3(0.50, 0.60, 0.52) * (0.92 + 0.12 * big) : wall_boards(OAK_DADO, fp.x, rise, dado, 0.14);
		papered = 0.0;
	}
	lively = mix(0.8, 1.0 - torn, papered);
	return wall_grade(c, region);
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
		// 칠이 떨어진 자리는 물이 닿는 곳(결정 476 대각뷰): 기단 위 1 m 남짓은 이어진 때와 함께
		// 군데군데, 그 위는 손바닥만 한 조각만 드물게. 대각뷰에서 벽이 화면의 큰 몫이 되자 1 m 넘는
		// 얼룩이 위장 무늬로 읽혔다. 벽돌도 집 칠처럼 색 보정을 덜 받아 회색 구멍으로 뜨지 않게 한다.
		float damp = 1.0 - smoothstep(0.5, 1.5, w_pos.y);
		float flake = smoothstep(mix(0.78, 0.7, damp), mix(0.82, 0.76, damp), fx_fbm2(fp * 2.2 + vec2(7.3, 1.9)));
		float bare = max(flake, smoothstep(0.6, 0.68, fx_fbm2(fp * 1.3 + vec2(2.1, 5.7))) * damp);
		bare *= exposed * (1.0 - up);
		int skin = int(wall_kind + 0.5);
		if ((skin & 7) > 0 && exposed > 0.5 && up < 0.5) {
			base = wall_skin(skin & 7, paint.rgb, fp, big, fine);
		} else {
			base = mix(base, brick, bare);
		}
		if (skin >= 8 && exposed > 0.5 && up < 0.5 && w_pos.y < 0.75) {
			// 돌 기단 띠: 거친 돌 줄.
			vec2 sc = fp / vec2(0.55, 0.25);
			sc.x += 0.37 * mod(floor(sc.y), 2.0);
			vec3 stone = stone_color * (0.8 + 0.3 * fx_hash(floor(sc)));
			base = mix(stone_color * 0.6, stone, 1.0 - seam(fract(sc), vec2(0.04, 0.08)));
		}
		lively = house_colour * exposed;
		if (exposed < 0.5 && up < 0.5 && building_id >= 0.0) {
			// 안쪽 벽: 건물·층마다 바랜 벽지(세로 줄이나 잔무늬), 군데군데 뜯겨 밝은 회벽이 드러남.
			// 뜯긴 자리에 바깥 칠을 보이면 짙은 칠 집의 방이 위장 무늬가 된다.
			// 살림방은 갈래·판·지역대로(room_finish, room_wall). 그 밖의 방은 건물·층마다 굴린 벽지 그대로.
			int rc = room_code(w_pos.xz + n.xz * 0.55, w_pos.y - 0.01, map_size);
			int kind = room_kind(rc);
			float torn = smoothstep(0.68, 0.74, fx_fbm2(fp * 2.0 + vec2(building_id, 2.0)));
			// 석회 회벽(반사율 0.6 안팎, 선형). 벽지(PAPERS, 선형)보다 조금 밝아 뜯긴 자리가 읽힌다.
			vec3 plaster = vec3(0.66, 0.64, 0.60) * (0.92 + 0.1 * fine);
			if (kind == 0) {
				float pick = fx_hash(vec2(building_id, floor(w_pos.y / level_h) + 3.0));
				vec3 paper = PAPERS[int(pick * 4.99)];
				float stripe = pick > 0.5 ? smoothstep(0.35, 0.5, abs(fract(run * 2.4) - 0.5)) : smoothstep(0.62, 0.8, fx_vnoise(fp * 7.0));
				paper *= 0.9 + 0.12 * stripe;
				base = mix(paper * (0.9 + 0.1 * big), plaster, torn);
				lively = 1.0 - torn;
			} else {
				float rise = w_pos.y - floor((w_pos.y - 0.01) / level_h) * level_h;
				base = room_wall(kind, room_region(rc), room_roll(rc), fp, rise, big, fine, torn, plaster, lively);
			}
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
		vec3 roof = ROOFS[clamp(int(paint.a + 0.5), 0, 7)];
		roof = mix(roof / 12.92, pow((roof + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), roof));
		lively = house_colour * 0.75;
		if (up > 0.97) {
			// 평지붕: 1 m 폭 루핑 띠, 띠 사이 이음만 옅게(가로 이음은 바둑판으로 읽혀 뺌, 결정 469 C4).
			vec2 fc = w_pos.xz / vec2(0.95, 3.0);
			fc.y += 0.37 * fx_hash(vec2(floor(fc.x), 5.0));
			base = slate_color * 1.05 * (0.92 + 0.12 * fx_hash(floor(fc))) * (0.9 + 0.18 * big);
			base *= 1.0 - 0.12 * seam(vec2(fract(fc.x), 0.5), vec2(0.03, 0.0));
			lively = 0.0;
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
	// 기억의 회색도 가림이 켜졌을 때만(가림을 끄면 모두 보이는 것과 같다).
	vec3 dimmed = mix(vec3(grey), base, mix(1.0, seen.r * 0.6 + 0.4, clamp(mask_on, 0.0, 1.0)));
	dimmed *= mix(1.0, indoor_dark, (1.0 - exposed) * (1.0 - clamp(cell.b * 2.0, 0.0, 1.0)));
	ALBEDO = fx_photo(dimmed, fx_fade) * lit;
	ROUGHNESS = rough;
	METALLIC = metal * (1.0 - cover);
	float lamp = cell.b * lamp_gain * mix(0.4, 1.0, seen.r) * (1.0 - 0.5 * clamp(fx_fade, 0.0, 1.0));
	EMISSION = lamp_color * (0.25 + 0.75 * grey) * lamp;
}
