// 방 마감(game/world/room_finish.gd, 결정 469 C3): 칸마다 방 갈래와 판. 층마다 채널 하나
// (0층 R, 1층 G, 지하 B, 2층 A). 갈래 1 침실, 2 부엌, 3 욕실, 4 거실, 0이면 지금 그림 그대로.
// 판(0~2) = 값 / 8. building_view가 그림을 넣고 켠다(자료 없는 지도·회색 상자는 꺼진 채).
uniform sampler2D room_tex : filter_nearest, repeat_disable;
uniform float room_on = 0.0;

// 그 자리(xz, 높이 y)의 방 값. 층 높이는 3 m(building_view LEVEL_H).
int room_code(vec2 xz, float y, vec2 size) {
	if (room_on < 0.5) {
		return 0;
	}
	int lv = int(floor(y / 3.0));
	vec4 r = texture(room_tex, (floor(xz) + 0.5) / size);
	float v = lv == 0 ? r.r : (lv == 1 ? r.g : (lv == -1 ? r.b : (lv == 2 ? r.a : 0.0)));
	return int(v * 255.0 + 0.5);
}
