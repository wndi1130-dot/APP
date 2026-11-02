shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, shadows_disabled, fog_disabled, diffuse_lambert, specular_disabled;
#include "res://fx/shaders/fx_common.gdshaderinc"

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 bounds_px[32]; // direction * 4 + motion: x, y, width, height. 세 몸·여섯 틀의 합.
uniform float clip_lengths[12]; // body * 4 + motion, clips.json에서 읽음.
uniform sampler2D vis_texture : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(120.0, 70.0);
uniform float mask_on = 1.0;
uniform vec2 eye_xz = vec2(-1000.0);
uniform float eye_r = 18.0;
uniform float round_day = 0.0;
uniform float round_floor = 0.95;
uniform vec4 focus = vec4(0.0);
uniform vec2 wall_a;
uniform vec2 wall_b;
uniform vec2 wall_out;
// 최근 1초를 30 Hz로 보관. 각 개체의 이전 틀 경계 시각을 읽으므로
// 플레이어가 경계를 넘은 중간 틀에 동작이 바뀌지 않는다. CPU는 개체를 순회하지 않는다.
uniform vec4 focus_history[32];
uniform float focus_clock = 0.0;
uniform float foot_px_x[32]; // (방향, 동작)마다 칸 안 발 x — 자르기 자리를 자세 쪽으로 옮긴 만큼.
uniform float camera_pitch; // HordeView.CAM_PITCH를 라디안으로 전달.
uniform bool comparison_hold = false; // 촬영의 같은 몸/방향/첫 틀 비교만 정지.

const float TAU_H = 6.28318530718;
const float CAMERA_THETA = 0.785398163397; // cam_back().xz의 방위, 보는 쪽이 아님.
const float THETA_ZERO = 0.0;
const vec2 CELL_PX = vec2(42.0, 80.0);
const vec2 ATLAS_PX = vec2(2048.0, 1024.0);
const vec2 FOOT_PX = vec2(21.0, 64.0);
const float PX_PER_M = 30.0;
// 위쪽 0.87 + 카메라 쪽 0.35, 모든 카드에서 같은 세계 법선(카드를 세워도 몸의 평균 법선은 그대로). PC 그림에서 확인할 값.
const vec3 CARD_NORMAL = vec3(0.3495, 0.8690, 0.3495);

varying flat vec2 cell_origin;
varying flat vec3 cloth_mul;
varying flat float sight_mul;
varying vec2 picture_px;

float person_hash(float seed, float lane) {
	// 24비트 custom 씨앗을 정수로 되돌려 기기별 삼각함수 오차를 피한다.
	uint bits = uint(seed * 16777216.0) ^ (uint(lane) * 374761393u);
	bits = (bits ^ (bits >> 13u)) * 1274126177u;
	bits = bits ^ (bits >> 16u);
	return float(bits & 16777215u) / 16777216.0;
}

vec2 segment_nearest(vec2 point) {
	vec2 segment = wall_b - wall_a;
	float along = clamp(dot(point - wall_a, segment) / max(dot(segment, segment), 0.0001), 0.0, 1.0);
	return wall_a + along * segment;
}

float response(vec4 sample_focus, vec2 foot) {
	vec2 nearest = segment_nearest(sample_focus.xy);
	float distance_to_wall = distance(sample_focus.xy, nearest);
	float inside = 1.0 - step(0.001, dot(sample_focus.xy - nearest, wall_out));
	float near_wall = 1.0 - smoothstep(7.0, 10.0, distance_to_wall);
	float local = 1.0 - smoothstep(6.0, 14.0, distance(foot, nearest));
	return sample_focus.z * inside * near_wall * local;
}

// HordeView.upright_corner 계약: 위 면은 수직, 발 아래 면은 지면 위.
// 카메라 축은 부르는 vertex()가 넘긴다(INV_VIEW_MATRIX는 처리 함수 안에서만 쓸 수 있음).
vec3 upright_corner(vec3 foot, vec2 corner, vec3 right_h, vec3 back_h) {
	float lift = 0.02 * clamp(-corner.y / (16.0 * 1.08 / PX_PER_M), 0.0, 1.0);
	return foot + right_h * corner.x + (corner.y >= 0.0 ? vec3(0.0, 1.0, 0.0) * corner.y / cos(camera_pitch) : back_h * (-corner.y) / sin(camera_pitch)) + vec3(0.0, lift, 0.0);
}

void vertex() {
	vec3 foot = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 original_foot = foot;
	float seed = INSTANCE_CUSTOM.a;
	int body = min(int(floor(person_hash(seed, 1.0) * 3.0)), 2);
	int motion = clamp(int(round(INSTANCE_CUSTOM.g)), 0, 3);
	int base_motion = motion;
	float phase = INSTANCE_CUSTOM.r;
	float speed = mix(0.85, 1.15, person_hash(seed, 2.0));
	float person_size = mix(0.92, 1.08, person_hash(seed, 3.0));
	// 원래 동작 길이를 개체의 공통 6틀 주기로 사용한다. 반응 중에도 같은
	// 틀 번호/경계를 사용해 서로 다른 길이(걷기 1.4, 접촉 1.3)의 중간 교체를 막는다.
	float time = comparison_hold ? 0.0 : focus_clock;
	float base_rate = 6.0 * speed / clip_lengths[body * 4 + motion];
	float frame_clock = time * base_rate + 6.0 * phase;
	float frame_age = fract(frame_clock) / base_rate;
	float boundary_clock = max(0.0, time - frame_age);
	int history_index = int(mod(floor(boundary_clock * 30.0), 32.0));
	vec4 held_focus = focus_history[history_index];
	float active = response(held_focus, foot.xz);
	if (active > 0.2) {
		motion = 2 + int(step(0.5, person_hash(seed, 4.0)));
	}
	float reaction = clamp(response(focus, original_foot.xz), 0.0, 1.0);
	if (base_motion == 0) {
		// 실제 발 점도 0.3m 고리 안에서 이동. 같은 위상/속도가 걸음과 고리를 함께 구동.
		float orbit = time * speed / clip_lengths[body * 4] * TAU_H + phase * TAU_H;
		foot.xz += 0.3 * (1.0 - reaction) * vec2(cos(orbit), sin(orbit));
	}
	float wall_depth = max(0.0, dot(foot.xz - segment_nearest(foot.xz), wall_out));
	foot.xz -= wall_out * min(0.3 * reaction, max(0.0, wall_depth - 0.05));
	float theta = INSTANCE_CUSTOM.b * TAU_H;
	int direction = int(mod(floor((theta - CAMERA_THETA - THETA_ZERO + TAU_H / 16.0) / (TAU_H / 8.0)), 8.0));
	vec4 rect = bounds_px[direction * 4 + motion];
	// 실제 메시의 중간 꼭짓점 줄 UV.y=0.8이 항상 발 높이를 지나도록 한다.
	// 테두리가 발을 포함하지 않으면 한 면이 퇴화하여 테두리 밖을 그리지 않는다.
	float split_y = clamp(FOOT_PX.y, rect.y, rect.y + rect.w);
	float pixel_y = UV.y <= 0.8 ? mix(rect.y, split_y, UV.y / 0.8) : mix(split_y, rect.y + rect.w, (UV.y - 0.8) / 0.2);
	picture_px = vec2(rect.x + UV.x * rect.z, pixel_y);
	vec2 corner = vec2(picture_px.x - foot_px_x[direction * 4 + motion], FOOT_PX.y - picture_px.y) * person_size / PX_PER_M;
	vec3 right_h = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 back_h = normalize(vec3(INV_VIEW_MATRIX[2].x, 0.0, INV_VIEW_MATRIX[2].z));
	vec3 world = upright_corner(foot, corner, right_h, back_h);
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = normalize(mat3(VIEW_MATRIX) * CARD_NORMAL);
	float frame = mod(floor(frame_clock), 6.0);
	float index = ((float(body) * 8.0 + float(direction)) * 4.0 + float(motion)) * 6.0 + frame;
	cell_origin = vec2(mod(index, 48.0), floor(index / 48.0)) * CELL_PX;
	float colour = person_hash(seed, 5.0);
	cloth_mul = mix(0.85, 1.0, colour) * mix(vec3(0.97, 0.98, 1.0), vec3(1.0, 0.98, 0.96), person_hash(seed, 6.0));
	// 변형 전 발 위치를 가장 가까운 경계 칸 중심에 묶는다.
	vec2 nearest_cell = clamp(original_foot.xz, vec2(0.5), map_size - vec2(0.5));
	vec2 seen = textureLod(vis_texture, nearest_cell / map_size, 0.0).rg;
	float reveal = seen.r;
	float floor_k = mix(fx_sight.x, fx_sight.y, seen.g);
	float round_k = clamp(round_day, 0.0, 1.0);
	if (round_k > 0.001) {
		float near_eye = 1.0 - smoothstep(eye_r * 0.4, eye_r * 1.3, distance(original_foot.xz, eye_xz));
		reveal = mix(reveal, near_eye, smoothstep(0.5, 1.0, round_k));
		floor_k = mix(floor_k, round_floor, smoothstep(0.0, 0.5, round_k));
	}
	sight_mul = mix(1.0, max(max(reveal, floor_k), 0.45), clamp(mask_on, 0.0, 1.0));
}

void fragment() {
	vec2 atlas_uv = (cell_origin + clamp(picture_px, vec2(0.5), CELL_PX - vec2(0.5))) / ATLAS_PX;
	// 샘플과 미분은 알파 잘라냄보다 먼저. 모바일에서도 지원되는 미분으로 LOD를 추정.
	vec2 dx = dFdx(atlas_uv * ATLAS_PX);
	vec2 dy = dFdy(atlas_uv * ATLAS_PX);
	float lod = max(0.0, 0.5 * log2(max(max(dot(dx, dx), dot(dy, dy)), 0.0001)));
	vec4 sample_colour = texture(atlas, atlas_uv);
	vec3 colour = sample_colour.rgb * cloth_mul;
	float luma = dot(colour, vec3(0.299, 0.587, 0.114));
	colour = mix(vec3(luma), colour, 0.7) * sight_mul;
	ALBEDO = fx_photo(colour, fx_fade);
	ROUGHNESS = 1.0;
	ALPHA = sample_colour.a;
	ALPHA_SCISSOR_THRESHOLD = mix(0.48, 0.30, clamp(lod / 4.0, 0.0, 1.0));
	if (fx_fill.w > 0.5) {
		EMISSION = fx_fill_term(ALBEDO, 0.0, normalize(mat3(INV_VIEW_MATRIX) * NORMAL));
	}
}
