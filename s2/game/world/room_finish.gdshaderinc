// 방 마감(game/world/room_finish.gd, 결정 469 C3, 사용자 10-28): 칸마다 방 갈래와 판. 층마다 채널 하나
// (0층 R, 1층 G, 지하 B, 2층 A). 갈래 1 침실, 2 부엌, 3 욕실, 4 거실, 5 복도, 6 식당, 7 창고,
// 0이면 지금 그림 그대로. 판 = 값 / 8 = 지역 × ROOM_VARIANTS + 집의 판(지역 차례는 room_finish REGIONS:
// 읍내·철도 공업지·산골 일터·높은 산·물가·빈 선로). 그림 폭은 지도의 두 배라 오른쪽 절반이 깔개 칸.
// building_view가 그림을 넣고 켠다(자료 없는 지도·회색 상자는 꺼진 채).
uniform sampler2D room_tex : filter_nearest, repeat_disable;
uniform float room_on = 0.0;

// room_finish.gd VARIANTS와 같아야 한다.
const int ROOM_VARIANTS = 5;

int room_level(float y) {
	return int(floor(y / 3.0));
}

int room_byte(vec4 r, int lv) {
	float v = lv == 0 ? r.r : (lv == 1 ? r.g : (lv == -1 ? r.b : (lv == 2 ? r.a : 0.0)));
	return int(v * 255.0 + 0.5);
}

// 그 자리(xz, 높이 y)의 방 값. 층 높이는 3 m(building_view LEVEL_H). `size`는 지도 칸 수(그림 왼쪽 절반).
int room_code(vec2 xz, float y, vec2 size) {
	if (room_on < 0.5) {
		return 0;
	}
	ivec2 c = ivec2(floor(xz));
	if (c.x < 0 || c.y < 0 || c.x >= int(size.x) || c.y >= int(size.y)) {
		return 0;
	}
	return room_byte(texelFetch(room_tex, c, 0), room_level(y));
}

int room_kind(int code) {
	return code & 7;
}

int room_region(int code) {
	return (code >> 3) / ROOM_VARIANTS;
}

int room_roll(int code) {
	return (code >> 3) % ROOM_VARIANTS;
}

// 그 칸의 깔개(0 없음)와, 깔개면 칸 안에서 깔개 바깥 가장자리까지의 거리(m, 이웃 칸이 같은 깔개면 이어짐).
int room_rug(vec2 xz, float y, vec2 size, out float edge) {
	edge = 0.0;
	if (room_on < 0.5) {
		return 0;
	}
	ivec2 c = ivec2(floor(xz));
	int w = int(size.x);
	if (c.x < 1 || c.y < 1 || c.x >= w - 1 || c.y >= int(size.y) - 1) {
		return 0;
	}
	int lv = room_level(y);
	int look = room_byte(texelFetch(room_tex, c + ivec2(w, 0), 0), lv);
	if (look == 0) {
		return 0;
	}
	vec2 f = xz - vec2(c);
	float d = 9.0;
	d = room_byte(texelFetch(room_tex, c + ivec2(w - 1, 0), 0), lv) == look ? d : min(d, f.x);
	d = room_byte(texelFetch(room_tex, c + ivec2(w + 1, 0), 0), lv) == look ? d : min(d, 1.0 - f.x);
	d = room_byte(texelFetch(room_tex, c + ivec2(w, -1), 0), lv) == look ? d : min(d, f.y);
	d = room_byte(texelFetch(room_tex, c + ivec2(w, 1), 0), lv) == look ? d : min(d, 1.0 - f.y);
	edge = d;
	return look;
}
