# 이 지도가 다른 판단을 만드는 것: 운반조 다섯을 모두 부르려면 얼음 쪽 끝까지 가야 하고, 그 사이 첫 무리가 얼음을 건너온다.
extends RefCounted

const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const PLACE_ID: String = "story_01"
const WIDTH: int = 140
const HEIGHT: int = 100
const TRAIN: Rect2i = Rect2i(30, 38, 80, 3)
const BANDS: Dictionary = {"upper": Rect2i(10, 16, 120, 22), "lower": Rect2i(10, 41, 120, 22)}
const ENTRY_NAMES: Dictionary = {"ice_west": "서쪽 얼음길", "ice_east": "동쪽 얼음길", "village_road": "마을 쪽 길"}
const ENTRY_WEIGHTS: Dictionary = {"ice_west": 1.0, "ice_east": 1.0, "village_road": 0.5}
const FIRST_ENTRY: String = "ice_west"
const TURNTABLE_CENTER: Vector2i = Vector2i(40, 62)
const TURNTABLE_RADIUS: int = 8
# y별 땅/얼음 경계의 꺾이는 자리. 서쪽은 ICE의 끝 x, 동쪽은 시작 x다.
# 띠가 있는 y=16..62에서는 서쪽 <=10, 동쪽 >=130으로 눈 바닥을 남긴다.
const WEST_ICE_EDGE: Array = [
	[0, 12], [8, 18], [15, 10], [24, 6], [30, 8], [37, 10], [43, 9],
	[51, 6], [58, 8], [62, 10], [69, 18], [76, 13], [82, 16], [86, 18], [92, 9], [99, 7]
]
const EAST_ICE_EDGE: Array = [
	[0, 128], [8, 122], [15, 130], [24, 133], [32, 130], [40, 131],
	[49, 134], [57, 132], [62, 130], [70, 122], [76, 126], [83, 128], [87, 122], [93, 126], [99, 132]
]

# 한 칸은 1m다. 둘레까지 포함한 최종 좌표이며 확장이나 층 복제는 하지 않는다.
# 같은 구역 글자 C의 두 사각형은 두 호수 가장자리다. 구역 이름은 모두 네 개다.
const PLAN: Dictionary = {
	"zones": [
		["A", "승강장과 급수탑", [0, 0, 140, 100]],
		["B", "저탄장", [55, 63, 65, 37]],
		["C", "호수 얼음길", [0, 0, 15, 100]],
		["C", "호수 얼음길", [126, 0, 14, 100]],
		["D", "원형 기관고", [25, 71, 30, 24]]
	],
	"labels": [["승강장과 급수탑", [73, 26]], ["저탄장", [70, 66]], ["호수 얼음길", [12, 84]], ["원형 기관고", [40, 76]], ["역무실", [96, 9]], ["급수탑 공구실", [114, 7]]],
	"floors": [
		[70, 0, 10, 16, 1], [15, 76, 40, 10, 7], [55, 63, 65, 33, 7],
		[25, 63, 30, 8, 7], [103, 3, 8, 10, 6], [105, 92, 20, 1, 4]
	],
	"buildings": [
		{"id": 0, "name": "원형 기관고", "rect": [25, 71, 30, 24], "warm": false, "window_broken": false},
		{"id": 1, "name": "역무실", "rect": [92, 6, 9, 9], "warm": false, "window_broken": false},
		{"id": 2, "name": "급수탑 공구실", "rect": [109, 3, 10, 11], "warm": false, "window_broken": false}
	],
	"roundhouse_rows": [[71, 78, 25, 55], [78, 84, 27, 53], [84, 89, 31, 49], [89, 94, 35, 45], [94, 95, 38, 42]],
	"walls": [[27, 83, 26, 1]],
	"doors": [[35, 71], [45, 71], [40, 83], [96, 14], [114, 13]],
	"deep": {"rect": [31, 84, 18, 11], "door": [40, 83], "approach": [40, 79]},
	"props": [
		# 만 셋 사이로 곶 둘이 나온다. 서쪽 남단은 그대로여서 첫 진입은 물을 돌아온다.
		{"kind": "water", "rect": [5, 0, 4, 6], "solid": "low", "facing": 0, "note": "서쪽 호수 북쪽 물목", "level": 0},
		{"kind": "water", "rect": [4, 6, 6, 6], "solid": "low", "facing": 0, "note": "서쪽 호수 북쪽 만 어귀", "level": 0},
		{"kind": "water", "rect": [3, 12, 7, 6], "solid": "low", "facing": 0, "note": "서쪽 호수 북쪽 만", "level": 0},
		{"kind": "water", "rect": [4, 18, 5, 6], "solid": "low", "facing": 0, "note": "서쪽 호수 첫 곶 어귀", "level": 0},
		{"kind": "water", "rect": [5, 24, 3, 6], "solid": "low", "facing": 0, "note": "서쪽 호수 첫 곶 앞", "level": 0},
		{"kind": "water", "rect": [4, 30, 5, 6], "solid": "low", "facing": 0, "note": "서쪽 호수 가운데 만 어귀", "level": 0},
		{"kind": "water", "rect": [2, 36, 8, 6], "solid": "low", "facing": 0, "note": "서쪽 호수 가운데 만", "level": 0},
		{"kind": "water", "rect": [3, 42, 6, 6], "solid": "low", "facing": 0, "note": "서쪽 호수 둘째 곶 어귀", "level": 0},
		{"kind": "water", "rect": [5, 48, 3, 6], "solid": "low", "facing": 0, "note": "서쪽 호수 둘째 곶 앞", "level": 0},
		{"kind": "water", "rect": [4, 54, 5, 6], "solid": "low", "facing": 0, "note": "서쪽 호수 남쪽 만 어귀", "level": 0},
		{"kind": "water", "rect": [3, 60, 6, 3], "solid": "low", "facing": 0, "note": "서쪽 호수 남쪽 만 물목", "level": 0},
		{"kind": "water", "rect": [3, 63, 9, 5], "solid": "low", "facing": 0, "note": "서쪽 호수 남쪽 만", "level": 0},
		{"kind": "water", "rect": [4, 68, 7, 4], "solid": "low", "facing": 0, "note": "서쪽 호수 남쪽 굽이", "level": 0},
		{"kind": "water", "rect": [5, 72, 5, 4], "solid": "low", "facing": 0, "note": "서쪽 호수 얼음길 앞 물끝", "level": 0},
		{"kind": "water", "rect": [134, 0, 6, 7], "solid": "low", "facing": 0, "note": "동쪽 호수 북쪽 물목", "level": 0},
		{"kind": "water", "rect": [132, 7, 8, 7], "solid": "low", "facing": 0, "note": "동쪽 호수 북쪽 만 어귀", "level": 0},
		{"kind": "water", "rect": [130, 14, 10, 7], "solid": "low", "facing": 0, "note": "동쪽 호수 북쪽 만", "level": 0},
		{"kind": "water", "rect": [131, 21, 9, 7], "solid": "low", "facing": 0, "note": "동쪽 호수 첫 곶 어귀", "level": 0},
		{"kind": "water", "rect": [134, 28, 6, 7], "solid": "low", "facing": 0, "note": "동쪽 호수 첫 곶 앞", "level": 0},
		{"kind": "water", "rect": [133, 35, 7, 7], "solid": "low", "facing": 0, "note": "동쪽 호수 가운데 만 어귀", "level": 0},
		{"kind": "water", "rect": [130, 42, 10, 7], "solid": "low", "facing": 0, "note": "동쪽 호수 가운데 만", "level": 0},
		{"kind": "water", "rect": [131, 49, 9, 7], "solid": "low", "facing": 0, "note": "동쪽 호수 둘째 곶 어귀", "level": 0},
		{"kind": "water", "rect": [134, 56, 6, 7], "solid": "low", "facing": 0, "note": "동쪽 호수 둘째 곶 앞", "level": 0},
		{"kind": "water", "rect": [133, 63, 7, 7], "solid": "low", "facing": 0, "note": "동쪽 호수 남쪽 만 어귀", "level": 0},
		{"kind": "water", "rect": [131, 70, 9, 6], "solid": "low", "facing": 0, "note": "동쪽 호수 남쪽 만", "level": 0},
		{"kind": "water", "rect": [133, 76, 7, 6], "solid": "low", "facing": 0, "note": "동쪽 호수 남쪽 굽이", "level": 0},
		{"kind": "water", "rect": [134, 82, 6, 4], "solid": "low", "facing": 0, "note": "동쪽 호수 얼음길 곁", "level": 0},
		{"kind": "water", "rect": [136, 86, 4, 2], "solid": "low", "facing": 0, "note": "동쪽 호수 얼음길 앞 물끝", "level": 0},
		# lake_01의 낮은 갈대 모형은 얼음 판으로 읽히지 않도록 물가의 눈 바닥 쪽에 둔다.
		{"kind": "frozen_reeds", "rect": [17, 10, 2, 2], "solid": "none", "facing": 0, "note": "서쪽 북쪽 만 땅가 갈대", "level": 0},
		{"kind": "frozen_reeds", "rect": [8, 25, 2, 2], "solid": "none", "facing": 0, "note": "서쪽 첫 곶 땅가 갈대", "level": 0},
		{"kind": "frozen_reeds", "rect": [18, 68, 2, 2], "solid": "none", "facing": 0, "note": "서쪽 남쪽 만 땅가 갈대", "level": 0},
		{"kind": "boulder", "rect": [10, 7, 2, 2], "solid": "low", "facing": 0, "note": "서쪽 북쪽 물가 돌", "level": 0},
		{"kind": "boulder", "rect": [12, 70, 2, 2], "solid": "low", "facing": 0, "note": "서쪽 남쪽 물가 돌", "level": 0},
		{"kind": "frozen_reeds", "rect": [122, 10, 2, 2], "solid": "none", "facing": 0, "note": "동쪽 북쪽 만 땅가 갈대", "level": 0},
		{"kind": "frozen_reeds", "rect": [129, 28, 2, 2], "solid": "none", "facing": 0, "note": "동쪽 첫 곶 땅가 갈대", "level": 0},
		{"kind": "frozen_reeds", "rect": [120, 70, 2, 2], "solid": "none", "facing": 0, "note": "동쪽 남쪽 만 땅가 갈대", "level": 0},
		{"kind": "boulder", "rect": [128, 12, 2, 2], "solid": "low", "facing": 0, "note": "동쪽 북쪽 물가 돌", "level": 0},
		{"kind": "boulder", "rect": [129, 74, 2, 2], "solid": "low", "facing": 0, "note": "동쪽 남쪽 물가 돌", "level": 0},
		{"kind": "sleeper_pile", "rect": [33, 29, 4, 2], "solid": "low", "facing": 0, "note": "승강장 서쪽 침목 더미", "level": 0},
		{"kind": "crate_stack", "rect": [40, 29, 4, 2], "solid": "low", "facing": 0, "note": "승강장 자재 상자", "level": 0},
		{"kind": "snow_drift", "rect": [87, 23, 4, 2], "solid": "low", "facing": 0, "note": "급수탑 앞 눈 둔덕", "level": 0},
		{"kind": "sleeper_pile", "rect": [94, 23, 4, 2], "solid": "low", "facing": 0, "note": "승강장 동쪽 침목 더미", "level": 0},
		{"kind": "sleeper_pile", "rect": [21, 55, 5, 2], "solid": "low", "facing": 0, "note": "저탄장 서쪽 침목 더미", "level": 0},
		{"kind": "crate_stack", "rect": [29, 55, 4, 2], "solid": "low", "facing": 0, "note": "기관고 앞 자재 상자", "level": 0},
		{"kind": "crate_stack", "rect": [112, 53, 4, 2], "solid": "low", "facing": 0, "note": "저탄장 동쪽 자재 상자", "level": 0},
		{"kind": "snow_drift", "rect": [119, 53, 5, 2], "solid": "low", "facing": 0, "note": "동쪽 얼음길 앞 눈 둔덕", "level": 0},
		{"kind": "water_tower", "rect": [103, 5, 5, 5], "solid": "wall", "facing": 0, "note": "얼어붙은 급수탑", "level": 0},
		{"kind": "water_crane", "rect": [88, 11, 2, 2], "solid": "low", "facing": 0, "note": "얼어붙은 급수관", "level": 0},
		# 원형 고리 (36,68)/(44,68)에서 두 문까지 잇는다. 끝 조각 중심은 문 밖에 남긴다.
		{"kind": "mine_track", "rect": [36, 68, 1, 2], "solid": "none", "facing": 0, "note": "전차대 서쪽 테두리에서 나가는 선로", "level": 0},
		{"kind": "mine_track", "rect": [35, 69, 2, 1], "solid": "none", "facing": 1, "note": "서쪽 정비문 앞 선로", "level": 0},
		{"kind": "mine_track", "rect": [35, 69, 1, 3], "solid": "none", "facing": 0, "note": "서쪽 정비문으로 드는 선로", "level": 0},
		{"kind": "mine_track", "rect": [44, 68, 1, 2], "solid": "none", "facing": 0, "note": "전차대 동쪽 테두리에서 나가는 선로", "level": 0},
		{"kind": "mine_track", "rect": [44, 69, 2, 1], "solid": "none", "facing": 1, "note": "동쪽 정비문 앞 선로", "level": 0},
		{"kind": "mine_track", "rect": [45, 69, 1, 3], "solid": "none", "facing": 0, "note": "동쪽 정비문으로 드는 선로", "level": 0},
		# 기관고는 core_scenes가 맡는 건물이므로 작업 가구도 지도가 직접 둔다.
		{"kind": "workbench", "rect": [26, 73, 1, 3], "solid": "low", "facing": 1, "note": "기관고 서쪽 정비칸 작업대", "level": 0},
		{"kind": "tool_chest", "rect": [28, 72, 2, 1], "solid": "low", "facing": 0, "note": "기관고 서쪽 정비칸 공구함", "level": 0},
		{"kind": "shelf", "rect": [28, 82, 3, 1], "solid": "low", "facing": 2, "note": "기관고 서쪽 정비칸 부품 선반", "level": 0},
		{"kind": "barrel", "rect": [28, 78, 1, 1], "solid": "low", "facing": 1, "note": "기관고 서쪽 정비칸 연료 통", "level": 0},
		{"kind": "workbench", "rect": [53, 73, 1, 3], "solid": "low", "facing": 3, "note": "기관고 동쪽 정비칸 작업대", "level": 0},
		{"kind": "shelf", "rect": [48, 72, 3, 1], "solid": "low", "facing": 0, "note": "기관고 동쪽 정비칸 부품 선반", "level": 0},
		{"kind": "tool_chest", "rect": [49, 82, 2, 1], "solid": "low", "facing": 2, "note": "기관고 동쪽 정비칸 공구함", "level": 0},
		{"kind": "barrel", "rect": [51, 79, 1, 1], "solid": "low", "facing": 3, "note": "기관고 동쪽 정비칸 연료 통", "level": 0},
		{"kind": "pallet_stack", "rect": [43, 77, 3, 2], "solid": "low", "facing": 0, "note": "뜯어 둔 기관 부품", "level": 0},
		{"kind": "crate_stack", "rect": [46, 77, 2, 2], "solid": "low", "facing": 0, "note": "뜯어 둔 기관 부품", "level": 0},
		{"kind": "part_crate", "rect": [43, 79, 2, 1], "solid": "low", "facing": 0, "note": "뜯어 둔 기관 부품", "level": 0},
		{"kind": "barrel", "rect": [46, 79, 1, 1], "solid": "low", "facing": 0, "note": "뜯어 둔 기관 부품", "level": 0},
		# 깊은 방 남쪽 벽가(y=89..93)는 부서진 기관차의 _deepest 후보로 비워 둔다.
		{"kind": "workbench", "rect": [33, 84, 3, 1], "solid": "low", "facing": 0, "note": "기관고 깊은 정비칸 작업대", "level": 0},
		{"kind": "shelf", "rect": [44, 84, 3, 1], "solid": "low", "facing": 0, "note": "기관고 깊은 정비칸 부품 선반", "level": 0},
		{"kind": "tool_chest", "rect": [32, 86, 1, 2], "solid": "low", "facing": 1, "note": "기관고 깊은 정비칸 공구함", "level": 0},
		{"kind": "barrel", "rect": [47, 86, 1, 1], "solid": "low", "facing": 3, "note": "기관고 깊은 정비칸 연료 통", "level": 0},
		{"kind": "coal_heap", "rect": [60, 79, 5, 3], "solid": "low", "facing": 0, "note": "저탄장 서쪽 석탄 더미", "level": 0},
		{"kind": "coal_heap", "rect": [75, 88, 5, 4], "solid": "low", "facing": 0, "note": "저탄장 안쪽 석탄 더미", "level": 0},
		{"kind": "coal_heap", "rect": [96, 68, 5, 3], "solid": "low", "facing": 0, "note": "저탄장 앞 석탄 더미", "level": 0},
		{"kind": "crate_stack", "rect": [70, 76, 3, 2], "solid": "low", "facing": 0, "note": "낮은 석탄 통", "level": 0},
		{"kind": "crate_stack", "rect": [98, 84, 3, 2], "solid": "low", "facing": 0, "note": "안쪽 낮은 석탄 통", "level": 0},
		{"kind": "bare_tree", "rect": [18, 3, 1, 1], "solid": "tree", "facing": 0, "note": "북쪽 숲 가장자리", "level": 0},
		{"kind": "bare_tree", "rect": [29, 7, 1, 1], "solid": "tree", "facing": 0, "note": "북쪽 마른 나무", "level": 0},
		{"kind": "bare_tree", "rect": [91, 4, 1, 1], "solid": "tree", "facing": 0, "note": "급수탑 뒤 마른 나무", "level": 0},
		{"kind": "bare_tree", "rect": [119, 8, 1, 1], "solid": "tree", "facing": 0, "note": "북동쪽 숲 가장자리", "level": 0},
		{"kind": "bare_tree", "rect": [57, 98, 1, 1], "solid": "tree", "facing": 0, "note": "남쪽 숲 가장자리", "level": 0},
		{"kind": "bare_tree", "rect": [100, 97, 1, 1], "solid": "tree", "facing": 0, "note": "측선 뒤 마른 나무", "level": 0},
		{"kind": "bare_tree", "rect": [122, 96, 1, 1], "solid": "tree", "facing": 0, "note": "남동쪽 숲 가장자리", "level": 0}
	],
	"coal_boxes": [
		["coal_front_01", [63, 72]], ["coal_front_02", [74, 68]], ["coal_front_03", [89, 69]], ["coal_front_04", [102, 74]],
		["coal_ice_01", [12, 81]], ["coal_ice_02", [15, 86]], ["coal_ice_03", [128, 79]], ["coal_ice_04", [131, 86]]
	],
	# 사건용 석탄 빈칸 8개와 별도로, 뒤질 상자 39개에 무게 54.3을 고르게 둔다.
	# 깊은 방 남쪽의 코어 후보는 비운다. 기존 공구 상자 두 개는 같은 내용물을 유지한다.
	"containers": [
		{"id":"tools_shallow","name":"기관고 앞방 공구 상자","cell":[35,78],"building":0,"search":4,"items":["nails","gears","wire_coil"],"locked":false,"level":0,"searched":false},
		{"id":"tools_deep","name":"기관고 안쪽 공구 상자","cell":[40,90],"building":0,"search":4,"items":["nails","gears","wire_coil"],"locked":false,"level":0,"searched":false},
		{"id":"roundhouse_loot_01","name":"기관고 서쪽 정비칸 공구함","cell":[29,73],"building":0,"search":5,"items":["nails","nails","junk_rag","sewing_kit"],"locked":false,"level":0,"searched":false},
		{"id":"roundhouse_loot_02","name":"기관고 서쪽 정비칸 부품 선반","cell":[29,81],"building":0,"search":5,"items":["gears","wire_coil","springs"],"locked":false,"level":0,"searched":false},
		{"id":"roundhouse_loot_03","name":"기관고 서쪽 정비칸 작업대 서랍","cell":[27,74],"building":0,"search":5,"items":["nails","nails","gears"],"locked":false,"level":0,"searched":false},
		{"id":"roundhouse_loot_04","name":"기관고 서쪽 정비칸 톱니 상자","cell":[30,78],"building":0,"search":5,"items":["gears","gears","springs"],"locked":false,"level":0,"searched":false},
		{"id":"roundhouse_loot_05","name":"기관고 서쪽 정비칸 수선 사물함","cell":[28,76],"building":0,"search":5,"items":["old_clothes","sewing_kit","junk_rag","wire_coil"],"locked":false,"level":0,"searched":false},
		{"id":"roundhouse_loot_06","name":"기관고 서쪽 정비칸 연료 상자","cell":[29,79],"building":0,"search":5,"items":["fuel_can","junk_rag"],"locked":false,"level":0,"searched":false},
		{"id":"roundhouse_loot_07","name":"기관고 서쪽 정비칸 전선 선반","cell":[32,80],"building":0,"search":5,"items":["wire_coil","wire_coil","springs"],"locked":false,"level":0,"searched":false},
		{"id":"roundhouse_loot_08","name":"기관고 서쪽 정비칸 헌옷 사물함","cell":[33,74],"building":0,"search":5,"items":["old_clothes","old_clothes","sewing_kit","junk_rag"],"locked":false,"level":0,"searched":false},
		{"id":"roundhouse_loot_09","name":"기관고 서쪽 정비칸 못 상자","cell":[31,72],"building":0,"search":5,"items":["nails","nails","junk_rag","sewing_kit"],"locked":false,"level":0,"searched":false},
		{"id":"roundhouse_loot_10","name":"기관고 동쪽 정비칸 공구함","cell":[50,81],"building":0,"search":5,"items":["nails","nails","junk_rag","sewing_kit"],"locked":false,"level":0,"searched":false},
		{"id":"roundhouse_loot_11","name":"기관고 동쪽 정비칸 부품 선반","cell":[49,73],"building":0,"search":5,"items":["gears","wire_coil","springs"],"locked":false,"level":0,"searched":false},
		{"id":"roundhouse_loot_12","name":"기관고 동쪽 정비칸 작업대 서랍","cell":[52,74],"building":0,"search":5,"items":["nails","nails","gears"],"locked":false,"level":0,"searched":false},
		{"id":"roundhouse_loot_13","name":"기관고 동쪽 정비칸 연료 상자","cell":[50,79],"building":0,"search":5,"items":["fuel_can","junk_rag"],"locked":false,"level":0,"searched":false},
		{"id":"roundhouse_loot_14","name":"기관고 동쪽 정비칸 뜯은 부품 상자","cell":[48,78],"building":0,"search":5,"items":["gears","gears","springs"],"locked":false,"level":0,"searched":false},
		{"id":"roundhouse_loot_15","name":"기관고 동쪽 정비칸 전선 상자","cell":[42,77],"building":0,"search":5,"items":["wire_coil","wire_coil","springs"],"locked":false,"level":0,"searched":false},
		{"id":"roundhouse_loot_16","name":"기관고 동쪽 정비칸 수선 사물함","cell":[45,80],"building":0,"search":5,"items":["old_clothes","sewing_kit","junk_rag","wire_coil"],"locked":false,"level":0,"searched":false},
		{"id":"roundhouse_loot_17","name":"기관고 동쪽 정비칸 헌옷 사물함","cell":[51,76],"building":0,"search":5,"items":["old_clothes","old_clothes","sewing_kit","junk_rag"],"locked":false,"level":0,"searched":false},
		{"id":"roundhouse_loot_18","name":"기관고 동쪽 정비칸 예비 연료 상자","cell":[48,80],"building":0,"search":5,"items":["fuel_can","junk_rag"],"locked":false,"level":0,"searched":false},
		{"id":"roundhouse_loot_19","name":"기관고 깊은 정비칸 작업대 서랍","cell":[34,85],"building":0,"search":5,"items":["nails","nails","junk_rag","sewing_kit"],"locked":false,"level":0,"searched":false},
		{"id":"roundhouse_loot_20","name":"기관고 깊은 정비칸 부품 선반","cell":[45,85],"building":0,"search":5,"items":["gears","wire_coil","springs"],"locked":false,"level":0,"searched":false},
		{"id":"roundhouse_loot_21","name":"기관고 깊은 정비칸 공구함 구급 칸","cell":[33,86],"building":0,"search":5,"items":["ointment","fever_pills","junk_rag"],"locked":false,"level":0,"searched":false},
		{"id":"roundhouse_loot_22","name":"기관고 깊은 정비칸 연료 상자","cell":[46,86],"building":0,"search":5,"items":["fuel_can","junk_rag"],"locked":false,"level":0,"searched":false},
		{"id":"station_loot_01","name":"역무실 기록 서랍","cell":[93,7],"building":1,"search":5,"items":["book","book","candle","junk_paper"],"locked":false,"level":0,"searched":false},
		{"id":"station_loot_02","name":"역무실 운행 기록 책장","cell":[95,7],"building":1,"search":5,"items":["book","book","candle","sewing_kit"],"locked":false,"level":0,"searched":false},
		{"id":"station_loot_03","name":"역무실 시계 서랍","cell":[98,7],"building":1,"search":5,"items":["book","pocket_watch","junk_paper"],"locked":false,"level":0,"searched":false},
		{"id":"station_loot_04","name":"역무실 옷감 사물함","cell":[99,9],"building":1,"search":5,"items":["old_clothes","sewing_kit","candle","junk_rag"],"locked":false,"level":0,"searched":false},
		{"id":"station_loot_05","name":"역무실 구급 서랍","cell":[99,12],"building":1,"search":5,"items":["painkillers","ointment"],"locked":false,"level":0,"searched":false},
		{"id":"station_loot_06","name":"역무실 비상 간식 보관함","cell":[94,12],"building":1,"search":5,"items":["can_beans","can_opener","candle"],"locked":false,"level":0,"searched":false},
		{"id":"station_loot_07","name":"역무실 휴식 간식 보관함","cell":[93,10],"building":1,"search":5,"items":["hardtack","rusk","candle"],"locked":false,"level":0,"searched":false},
		{"id":"station_loot_08","name":"역무실 바느질 사물함","cell":[96,10],"building":1,"search":5,"items":["old_clothes","old_clothes","sewing_kit","candle"],"locked":false,"level":0,"searched":false},
		{"id":"pump_loot_01","name":"급수탑 공구실 작업대 공구함","cell":[110,5],"building":2,"search":5,"items":["nails","gears","wire_coil"],"locked":false,"level":0,"searched":false},
		{"id":"pump_loot_02","name":"급수탑 공구실 부품 선반","cell":[112,4],"building":2,"search":5,"items":["gears","wire_coil","springs"],"locked":false,"level":0,"searched":false},
		{"id":"pump_loot_03","name":"급수탑 공구실 연료 보관함","cell":[116,4],"building":2,"search":5,"items":["fuel_can","nails"],"locked":false,"level":0,"searched":false},
		{"id":"pump_loot_04","name":"급수탑 공구실 예비 연료 상자","cell":[117,7],"building":2,"search":5,"items":["fuel_can","junk_rag"],"locked":false,"level":0,"searched":false},
		{"id":"pump_loot_05","name":"급수탑 공구실 수선 사물함","cell":[110,9],"building":2,"search":5,"items":["old_clothes","sewing_kit","junk_rag","wire_coil","can_opener"],"locked":false,"level":0,"searched":false},
		{"id":"pump_loot_06","name":"급수탑 공구실 못 상자","cell":[112,11],"building":2,"search":5,"items":["nails","nails","junk_rag","sewing_kit"],"locked":false,"level":0,"searched":false},
		{"id":"pump_loot_07","name":"급수탑 공구실 전선 선반","cell":[117,11],"building":2,"search":5,"items":["wire_coil","wire_coil","springs"],"locked":false,"level":0,"searched":false}
	],
	"wagons": [{"id": "coal_siding", "name": "열린 석탄 화차", "rect": [108, 91, 12, 3], "coal": 0, "work": [112, 90]}],
	"entries": [["ice_west", [[1, 18], [1, 19], [1, 20]], 1.4], ["ice_east", [[137, 95], [137, 96], [137, 97]], 1.4], ["village_road", [[74, 0], [75, 0], [76, 0]], 2.0]],
	"barricades": [[37, 30], [38, 30], [39, 30], [91, 24], [92, 24], [93, 24], [26, 56], [27, 56], [28, 56], [116, 54], [117, 54], [118, 54]],
	"work_site": {"cell": [69, 68], "rect": [58, 64, 50, 31]},
	"story_spots": [
		["story_porter_01", "저탄장 앞쪽 운반조", [65, 72], [64, 71, 3, 3]],
		["story_porter_02", "저탄장 안쪽 운반조", [81, 82], [80, 81, 3, 3]],
		["story_porter_03", "저탄장 동쪽 운반조", [102, 88], [101, 87, 3, 3]],
		["story_porter_04", "서쪽 얼음 끝 운반조", [12, 82], [10, 80, 5, 5]],
		["story_porter_05", "동쪽 얼음 끝 운반조", [131, 83], [128, 81, 5, 5]],
		["story_platform_end", "승강장 끝의 빈 터", [90, 35], [82, 31, 15, 7]]
	]
}


static func build() -> Dictionary:
	var g := FieldGrid.new(WIDTH, HEIGHT)
	var levels: Dictionary = {0: g}
	var data: Dictionary = {
		"grid": g, "levels": levels, "stairs": [], "containers": {}, "spots": {},
		"stoves": [], "entries": {}, "entry_gap": {}, "entry_levels": {},
		"buildings": [], "wagons": [], "train": TRAIN,
		"platform": Rect2i(46, 34, 47, 4), "unload": Rect2i(30, 41, 80, 3),
		"train_cars": [], "spawns": {}, "labels": [], "trees": [], "low_blocks": [],
		"upper_rects": [], "lights": [], "manholes": {}, "manhole_levels": {},
		"sewer_names": {}, "anchors": {}, "zone_names": {}, "place_id": PLACE_ID,
		"place_kind": "freight", "bands": BANDS.duplicate(true),
		"train_doors": {"upper": [], "lower": []}, "crossings": [], "barricade_slots": [],
		"interior_kind_slots": [{"zone": "D", "kinds": ["empty", "raiders", "nest", "beasts"]}],
		"props": [], "hole_faces": {}, "entry_names": ENTRY_NAMES.duplicate(true),
		"entry_weights": ENTRY_WEIGHTS.duplicate(true), "first_entry": FIRST_ENTRY
	}
	for row in PLAN["zones"]:
		data["zone_names"][row[0]] = row[1]
		var r := _rect(row[2])
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				g.zone[g.index(Vector2i(x, y))] = row[0]
	for row in PLAN["labels"]:
		data["labels"].append({"text": row[0], "cell": _cell(row[1])})
	for row in PLAN["floors"]:
		_fill_floor(g, Rect2i(row[0], row[1], row[2], row[3]), int(row[4]))
	_fill_floor(g, Rect2i(0, TRAIN.position.y, WIDTH, 3), F.RAIL)
	_fill_floor(g, data["platform"], F.PLATFORM)
	_fill_floor(g, data["unload"], F.GRAVEL)
	_lake_floors(g)
	_turntable(g)
	_fill_solid(g, TRAIN, S.BLOCK)
	for row in PLAN["buildings"]:
		var b: Dictionary = row.duplicate(true)
		b["rect"] = _rect(row["rect"])
		data["buildings"].append(b)
	_roundhouse(g)
	_service_rooms(g)
	for row in PLAN["walls"]:
		_fill_solid(g, _rect(row), S.WALL)
	for row in PLAN["doors"]:
		var c := _cell(row)
		g.set_solid(c, S.DOOR)
		g.doors[c] = {"state": "open", "hp": 8, "building": g.building_at(c), "cell": c}
	for row in _shore_props():
		var pr: Dictionary = row.duplicate(true)
		var r := _rect(row["rect"])
		pr["rect"] = r
		data["props"].append(pr)
		match String(pr["solid"]):
			"low":
				_fill_solid(g, r, S.LOW)
				if pr["kind"] == "water":
					_fill_floor(g, r, F.ICE)
				else:
					data["low_blocks"].append(r)
			"wall":
				_fill_solid(g, r, S.WALL)
			"tree":
				_fill_solid(g, r, S.BLOCK)
				data["trees"].append(r.position)
	for row in PLAN["wagons"]:
		var wagon: Dictionary = row.duplicate(true)
		wagon["rect"] = _rect(row["rect"])
		wagon["work"] = _cell(row["work"])
		data["wagons"].append(wagon)
		_fill_solid(g, wagon["rect"], S.BLOCK)
	# 석탄은 사건 쪽에서 채운다. 여기서는 상자 자리만 두고 수량을 정하지 않는다.
	for row in PLAN["coal_boxes"]:
		data["containers"][row[0]] = {"id": row[0], "name": "석탄 자루 상자", "cell": _cell(row[1]), "building": -1, "search": 4.0, "items": [], "locked": false, "level": 0, "searched": false}
	for row: Dictionary in PLAN["containers"]:
		var box: Dictionary = row.duplicate(true)
		box["cell"] = _cell(row["cell"])
		data["containers"][box["id"]] = box
	for row in PLAN["entries"]:
		var cells: Array[Vector2i] = []
		for c in row[1]:
			cells.append(_cell(c))
		data["entries"][row[0]] = cells
		data["entry_gap"][row[0]] = float(row[2])
		data["entry_levels"][row[0]] = 0
	for row in PLAN["barricades"]:
		data["barricade_slots"].append(_cell(row))
	_train(g, data)
	var work: Dictionary = PLAN["work_site"]
	data["spots"]["work_site"] = {"kind": "work_site", "cell": _cell(work["cell"]), "name": "저탄장 작업 구역", "state": "closed", "zone_rect": _rect(work["rect"])}
	for row in PLAN["story_spots"]:
		data["spots"][row[0]] = {"kind": "story", "cell": _cell(row[2]), "name": row[1], "zone_rect": _rect(row[3])}
	# 초기 망자와 누운 몸은 없다. 첫 얼음 물결의 시계와 운반조는 사건 쪽 소유다.
	data["spawns"] = {"squad": [Vector2i(64, 44), Vector2i(62, 45), Vector2i(66, 45)], "train_door": data["train_doors"]["upper"] + data["train_doors"]["lower"], "dead_ice": [], "dead_levels": []}
	data["anchors"] = {"horde_home": Vector2i(64, 44), "whistle": Vector2i(108, 41), "flee_exit": Vector2i(75, 0), "engine": Vector2i(102, 39)}
	g.refresh_paths()
	return data


static func _train(g: FieldGrid, data: Dictionary) -> void:
	for side in ["upper", "lower"]:
		var y: int = TRAIN.position.y - 1 if side == "upper" else TRAIN.end.y
		for x in [48, 64, 80]:
			data["train_doors"][side].append(Vector2i(x, y))
		var apron: Rect2i = Rect2i(46, 34, 47, 3) if side == "upper" else Rect2i(30, 41, 80, 3)
		data["spots"]["unload_" + side] = {"kind": "unload", "name": "승강장 하역 자리" if side == "upper" else "저탄장 하역 자리", "cell": Vector2i(64, 36 if side == "upper" else 42), "state": "open", "zone_rect": apron}
	# 열차 밑을 뚫지 않는다. 양 끝으로 사람과 무리가 돌아간다.
	for x in [TRAIN.position.x - 1, TRAIN.end.x]:
		var cells: Array[Vector2i] = []
		for y in range(TRAIN.position.y - 1, TRAIN.end.y + 1):
			var c := Vector2i(x, y)
			cells.append(c)
			g.floor[g.index(c)] = F.GRAVEL
		data["crossings"].append({"cells": cells, "who": {"person": true, "zombie": true, "carrying": true, "wounded": true, "sled": true}})
	for k in range(5):
		data["train_cars"].append({"rect": Rect2i(TRAIN.position.x + 16 * k, TRAIN.position.y, 16, 3), "kind": "engine" if k == 4 else "car"})


static func _roundhouse(g: FieldGrid) -> void:
	# 북쪽의 넓은 정비문에서 남쪽으로 좁아지는 반원 윤곽. 전용 지붕은 만들지 않는다.
	for row in PLAN["roundhouse_rows"]:
		for y in range(int(row[0]), int(row[1])):
			for x in range(int(row[2]), int(row[3])):
				var c := Vector2i(x, y)
				g.building[g.index(c)] = 0
				g.floor[g.index(c)] = F.WOOD
	for row in PLAN["roundhouse_rows"]:
		for y in range(int(row[0]), int(row[1])):
			for x in range(int(row[2]), int(row[3])):
				var c := Vector2i(x, y)
				for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if g.building_at(c + step) != 0:
						g.set_solid(c, S.WALL)
						break


static func _service_rooms(g: FieldGrid) -> void:
	# 띠 북쪽의 작은 두 방. 역무/공구 이름으로 room_furnish의 office/work를 받는다.
	for row: Dictionary in PLAN["buildings"]:
		var building_id: int = int(row["id"])
		if building_id == 0:
			continue
		var r := _rect(row["rect"])
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				g.building[g.index(c)] = building_id
				g.floor[g.index(c)] = F.WOOD
				var wall: bool = x == r.position.x or x == r.end.x - 1 or y == r.position.y or y == r.end.y - 1
				g.set_solid(c, S.WALL if wall else S.NONE)


static func _shore_edge(profile: Array, y: int) -> int:
	for i in range(1, profile.size()):
		var end: Array = profile[i]
		if y <= int(end[0]):
			var start: Array = profile[i - 1]
			var t: float = float(y - int(start[0])) / float(int(end[0]) - int(start[0]))
			return roundi(lerpf(float(start[1]), float(end[1]), t))
	return int(profile.back()[1])


static func _lake_floors(g: FieldGrid) -> void:
	# 큰 ICE 사각형 대신 경계 사이만 칠한다. 물가 보행 얼음은 본선 바깥에서도 이어진다.
	for y in range(HEIGHT):
		_fill_floor(g, Rect2i(0, y, _shore_edge(WEST_ICE_EDGE, y), 1), F.ICE)
		var east: int = _shore_edge(EAST_ICE_EDGE, y)
		_fill_floor(g, Rect2i(east, y, WIDTH - east, 1), F.ICE)


static func _shore_props() -> Array:
	var rows: Array = []
	for source: Dictionary in PLAN["props"]:
		if source["kind"] != "water":
			rows.append(source.duplicate(true))
			continue
		var r := _rect(source["rect"])
		var part: Dictionary = {}
		for y in range(r.position.y, r.end.y):
			var left: int = r.position.x
			var right: int = r.end.x
			if String(source["note"]).begins_with("서쪽"):
				# 꺾이는 물가도 네 방향으로 이어지도록 땅 쪽에 두 칸의 보행 얼음을 남긴다.
				right = mini(right, _shore_edge(WEST_ICE_EDGE, y) - 2)
				left = mini(left, right - 2)
			else:
				left = maxi(left, _shore_edge(EAST_ICE_EDGE, y) + 2)
			if not part.is_empty() and part["rect"][0] == left and part["rect"][2] == right - left:
				part["rect"][3] = int(part["rect"][3]) + 1
			else:
				part = source.duplicate(true)
				part["rect"] = [left, y, right - left, 1]
				rows.append(part)
	return rows


static func _turntable(g: FieldGrid) -> void:
	# 반지름 8칸 원판: 안쪽 ROAD와 한 칸 두께의 밝은 PLATFORM 고리. 모두 보행 가능.
	for y in range(TURNTABLE_CENTER.y - TURNTABLE_RADIUS, TURNTABLE_CENTER.y + TURNTABLE_RADIUS + 1):
		for x in range(TURNTABLE_CENTER.x - TURNTABLE_RADIUS, TURNTABLE_CENTER.x + TURNTABLE_RADIUS + 1):
			var c := Vector2i(x, y)
			var offset := c - TURNTABLE_CENTER
			var distance_squared: int = offset.x * offset.x + offset.y * offset.y
			if distance_squared <= TURNTABLE_RADIUS * TURNTABLE_RADIUS:
				g.floor[g.index(c)] = F.PLATFORM if distance_squared > (TURNTABLE_RADIUS - 1) * (TURNTABLE_RADIUS - 1) else F.ROAD
	_fill_floor(g, Rect2i(TURNTABLE_CENTER.x - TURNTABLE_RADIUS, TURNTABLE_CENTER.y, TURNTABLE_RADIUS * 2 + 1, 1), F.RAIL)


static func _cell(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


static func _rect(a: Array) -> Rect2i:
	return Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))


static func _fill_floor(g: FieldGrid, r: Rect2i, kind: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			g.floor[g.index(Vector2i(x, y))] = kind


static func _fill_solid(g: FieldGrid, r: Rect2i, kind: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			g.set_solid(Vector2i(x, y), kind)
