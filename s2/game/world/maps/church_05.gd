# 이 지도가 다른 판단을 만드는 것: 둑길은 외길이라 내내 드러난다. 탑에 오르면 멀리 보이나 체류의 3분의 1을 쓴다.
# 위쪽의 판단: 씨앗 봉지와 농기구(가볍고 값지다)를 얻는 대신, 북서 구석의 사일로까지 가면 아래쪽 상징물을 챙길 시간이 거의 남지 않는다.
extends RefCounted

const FieldGrid = preload("res://game/world/field_grid.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const PLACE_ID: String = "church_05"
const WIDTH: int = 180
const SOUTH_HEIGHT: int = 100
const HEIGHT: int = SOUTH_HEIGHT + 45

# 각 방과 마당의 좌표는 이 지도에서만 쓰는 독립 평면이다.
# 종소리와 덧댄 문 해체는 자리만 남기며 여기서 실행하지 않는다.
const PLAN: Dictionary = {
	"id": "church_05",
	"size": [
		180,
		100
	],
	"names": {"A":"둑길","B":"늪과 갈대밭","C":"교회 구내","D":"어귀 가게 마당","E":"어부 창고 거리","F":"사제관 마당"},
	"zones": [
		{"id":"A","rect":[0,0,180,100]},
		{"id":"B","rect":[0,17,180,42]},
		{"id":"A","rect":[84,10,8,49]},
		{"id":"C","rect":[38,59,62,41]},
		{"id":"D","rect":[100,54,33,46]},
		{"id":"E","rect":[0,59,38,41]},
		{"id":"F","rect":[133,54,47,46]}
	],
	"ground": [
		{"rect":[0,26,15,33],"kind":"DEEP_SNOW"},
		{"rect":[104,30,68,27],"kind":"DEEP_SNOW"},
		{"rect":[38,59,96,33],"kind":"GRAVEL"},
		{"rect":[84,10,8,50],"kind":"ROAD"},
		{"rect":[84,55,46,5],"kind":"ROAD"},
		{"rect":[0,87,180,5],"kind":"ROAD"},
		{"rect":[0,64,39,5],"kind":"ROAD"},
		{"rect":[25,66,5,25],"kind":"ROAD"},
		{"rect":[128,57,5,35],"kind":"ROAD"},
		{"rect":[167,58,5,34],"kind":"ROAD"},
		{"rect":[133,76,47,5],"kind":"ROAD"},
		{"rect":[99,69,5,19],"kind":"ROAD"},
		{"rect":[34,73,21,5],"kind":"ROAD"}
	],
	"buildings": [
		{"id":0,"name":"교회 본당","rect":[55,60,44,24],"warm":true,"window_broken":false},
		{"id":1,"name":"종탑","rect":[39,60,12,12],"warm":false,"window_broken":false},
		{"id":2,"name":"사제관","rect":[133,61,18,14],"warm":false,"window_broken":false},
		{"id":3,"name":"어부 창고 가","rect":[4,60,20,12],"warm":false,"window_broken":false},
		{"id":4,"name":"어부 창고 나","rect":[5,76,16,10],"warm":false,"window_broken":false},
		{"id":5,"name":"어부 창고 다","rect":[24,77,14,10],"warm":false,"window_broken":false},
		{"id":6,"name":"어귀 가게","rect":[100,59,16,10],"warm":false,"window_broken":false},
		{"id":7,"name":"어귀 여관","rect":[118,75,14,10],"warm":false,"window_broken":false},
		{"id":8,"name":"갈대 지붕 집 가","rect":[153,62,14,10],"warm":false,"window_broken":false},
		{"id":9,"name":"갈대 지붕 집 나","rect":[155,82,12,10],"warm":false,"window_broken":false},
		{"id":10,"name":"장작 헛간","rect":[138,79,10,8],"warm":false,"window_broken":false},
		{"id":11,"name":"종지기 집","rect":[43,77,8,6],"warm":false,"window_broken":false},
		{"id":12,"name":"그물 말림 헛간","rect":[57,92,18,8],"warm":false,"window_broken":false},
		{"id":13,"name":"선구 헛간","rect":[81,91,12,8],"warm":false,"window_broken":false},
		{"id":14,"name":"우물집","rect":[105,79,6,6],"warm":false,"window_broken":false}
	],
	"shells": [
		{"building":0,"level":0,"rect":[55,60,44,24]},
		{"building":0,"level":1,"rect":[55,60,8,24]},
		{"building":0,"level":-1,"rect":[75,60,24,24]},
		{"building":1,"level":0,"rect":[39,60,12,12]},
		{"building":1,"level":1,"rect":[39,60,12,12]},
		{"building":1,"level":2,"rect":[39,60,12,12]},
		{"building":2,"level":0,"rect":[133,61,18,14]},
		{"building":2,"level":1,"rect":[133,61,18,14]},
		{"building":3,"level":0,"rect":[4,60,20,12]},
		{"building":3,"level":1,"rect":[4,60,20,12]},
		{"building":4,"level":0,"rect":[5,76,16,10]},
		{"building":5,"level":0,"rect":[24,77,14,10]},
		{"building":6,"level":0,"rect":[100,59,16,10]},
		{"building":7,"level":0,"rect":[118,75,14,10]},
		{"building":7,"level":1,"rect":[118,75,14,10]},
		{"building":8,"level":0,"rect":[153,62,14,10]},
		{"building":9,"level":0,"rect":[155,82,12,10]},
		{"building":10,"level":0,"rect":[138,79,10,8]},
		{"building":11,"level":0,"rect":[43,77,8,6]},
		{"building":12,"level":0,"rect":[57,92,18,8]},
		{"building":13,"level":0,"rect":[81,91,12,8]},
		{"building":14,"level":0,"rect":[105,79,6,6]}
	],
	"walls": [
		{"level":0,"rect":[56,66,42,1]},
		{"level":0,"rect":[56,77,42,1]},
		{"level":0,"rect":[63,61,1,5]},
		{"level":0,"rect":[63,78,1,5]},
		{"level":0,"rect":[72,61,1,5]},
		{"level":0,"rect":[72,78,1,5]},
		{"level":0,"rect":[80,61,1,5]},
		{"level":0,"rect":[80,78,1,5]},
		{"level":0,"rect":[89,61,1,5]},
		{"level":0,"rect":[89,78,1,5]},
		{"level":1,"rect":[56,72,6,1]},
		{"level":-1,"rect":[78,63,18,1]},
		{"level":-1,"rect":[78,80,18,1]},
		{"level":-1,"rect":[78,63,1,18]},
		{"level":-1,"rect":[95,63,1,18]},
		{"level":-1,"rect":[87,64,1,16]},
		{"level":0,"rect":[44,61,1,10]},
		{"level":1,"rect":[44,61,1,10]},
		{"level":2,"rect":[44,61,1,10]},
		{"level":0,"rect":[134,66,16,1]},
		{"level":0,"rect":[134,69,16,1]},
		{"level":1,"rect":[134,66,16,1]},
		{"level":1,"rect":[134,69,16,1]},
		{"level":0,"rect":[5,64,18,1]},
		{"level":0,"rect":[5,67,18,1]},
		{"level":1,"rect":[5,64,18,1]},
		{"level":1,"rect":[5,67,18,1]},
		{"level":0,"rect":[13,77,1,8]},
		{"level":0,"rect":[31,78,1,8]},
		{"level":0,"rect":[108,60,1,8]},
		{"level":0,"rect":[125,76,1,8]},
		{"level":1,"rect":[125,76,1,8]},
		{"level":0,"rect":[160,63,1,8]},
		{"level":0,"rect":[161,83,1,8]},
		{"level":0,"rect":[66,93,1,6]}
	],
	"doors": [
		{"building":0,"level":0,"cell":[59,66],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[59,77],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[68,66],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[68,77],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[76,66],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[76,77],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[85,66],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[85,77],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[94,66],"side":[0,1],"state":"closed","outer":false},
		{"building":0,"level":0,"cell":[94,77],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[55,72],"side":[-1,0],"state":"open","outer":true},
		{"building":0,"level":0,"cell":[98,72],"side":[1,0],"state":"open","outer":true},
		{"building":0,"level":1,"cell":[58,72],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":-1,"cell":[78,72],"side":[-1,0],"state":"open","outer":false},
		{"building":0,"level":-1,"cell":[95,72],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":0,"cell":[44,69],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":1,"cell":[44,69],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":2,"cell":[44,69],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":0,"cell":[50,69],"side":[1,0],"state":"open","outer":true},
		{"building":2,"level":0,"cell":[142,66],"side":[0,1],"state":"open","outer":false},
		{"building":2,"level":0,"cell":[142,69],"side":[0,-1],"state":"open","outer":false},
		{"building":2,"level":0,"cell":[133,67],"side":[-1,0],"state":"open","outer":true},
		{"building":2,"level":0,"cell":[150,67],"side":[1,0],"state":"open","outer":true},
		{"building":2,"level":1,"cell":[142,66],"side":[0,1],"state":"open","outer":false},
		{"building":2,"level":1,"cell":[142,69],"side":[0,-1],"state":"open","outer":false},
		{"building":3,"level":0,"cell":[14,64],"side":[0,1],"state":"open","outer":false},
		{"building":3,"level":0,"cell":[14,67],"side":[0,-1],"state":"open","outer":false},
		{"building":3,"level":0,"cell":[4,65],"side":[-1,0],"state":"open","outer":true},
		{"building":3,"level":0,"cell":[23,65],"side":[1,0],"state":"open","outer":true},
		{"building":3,"level":1,"cell":[14,64],"side":[0,1],"state":"open","outer":false},
		{"building":3,"level":1,"cell":[14,67],"side":[0,-1],"state":"open","outer":false},
		{"building":4,"level":0,"cell":[13,81],"side":[1,0],"state":"open","outer":false},
		{"building":4,"level":0,"cell":[5,81],"side":[-1,0],"state":"open","outer":true},
		{"building":4,"level":0,"cell":[20,81],"side":[1,0],"state":"open","outer":true},
		{"building":5,"level":0,"cell":[31,82],"side":[1,0],"state":"open","outer":false},
		{"building":5,"level":0,"cell":[24,82],"side":[-1,0],"state":"open","outer":true},
		{"building":5,"level":0,"cell":[37,82],"side":[1,0],"state":"open","outer":true},
		{"building":6,"level":0,"cell":[108,64],"side":[1,0],"state":"open","outer":false},
		{"building":6,"level":0,"cell":[100,64],"side":[-1,0],"state":"open","outer":true},
		{"building":6,"level":0,"cell":[115,64],"side":[1,0],"state":"open","outer":true},
		{"building":7,"level":0,"cell":[125,80],"side":[1,0],"state":"open","outer":false},
		{"building":7,"level":0,"cell":[118,80],"side":[-1,0],"state":"open","outer":true},
		{"building":7,"level":0,"cell":[131,80],"side":[1,0],"state":"open","outer":true},
		{"building":7,"level":1,"cell":[125,80],"side":[1,0],"state":"open","outer":false},
		{"building":8,"level":0,"cell":[160,67],"side":[1,0],"state":"open","outer":false},
		{"building":8,"level":0,"cell":[153,67],"side":[-1,0],"state":"open","outer":true},
		{"building":8,"level":0,"cell":[166,67],"side":[1,0],"state":"open","outer":true},
		{"building":9,"level":0,"cell":[161,87],"side":[1,0],"state":"open","outer":false},
		{"building":9,"level":0,"cell":[155,87],"side":[-1,0],"state":"open","outer":true},
		{"building":9,"level":0,"cell":[166,87],"side":[1,0],"state":"open","outer":true},
		{"building":10,"level":0,"cell":[138,83],"side":[-1,0],"state":"open","outer":true},
		{"building":10,"level":0,"cell":[147,83],"side":[1,0],"state":"open","outer":true},
		{"building":11,"level":0,"cell":[43,80],"side":[-1,0],"state":"open","outer":true},
		{"building":12,"level":0,"cell":[66,96],"side":[1,0],"state":"open","outer":false},
		{"building":12,"level":0,"cell":[57,96],"side":[-1,0],"state":"open","outer":true},
		{"building":12,"level":0,"cell":[74,96],"side":[1,0],"state":"open","outer":true},
		{"building":13,"level":0,"cell":[81,95],"side":[-1,0],"state":"open","outer":true},
		{"building":13,"level":0,"cell":[92,95],"side":[1,0],"state":"open","outer":true},
		{"building":14,"level":0,"cell":[105,82],"side":[-1,0],"state":"open","outer":true}
	],
	"windows": [
		{"building":0,"level":0,"cell":[67,60],"broken":false},
		{"building":0,"level":0,"cell":[67,83],"broken":false},
		{"building":0,"level":0,"cell":[86,60],"broken":false},
		{"building":0,"level":0,"cell":[86,83],"broken":false},
		{"building":0,"level":0,"cell":[55,62],"broken":false},
		{"building":0,"level":1,"cell":[57,60],"broken":false},
		{"building":0,"level":1,"cell":[57,83],"broken":false},
		{"building":0,"level":1,"cell":[60,60],"broken":false},
		{"building":0,"level":1,"cell":[60,83],"broken":false},
		{"building":0,"level":1,"cell":[55,62],"broken":false},
		{"building":1,"level":0,"cell":[42,60],"broken":false},
		{"building":1,"level":0,"cell":[42,71],"broken":false},
		{"building":1,"level":0,"cell":[47,60],"broken":false},
		{"building":1,"level":0,"cell":[47,71],"broken":false},
		{"building":1,"level":0,"cell":[39,62],"broken":false},
		{"building":1,"level":1,"cell":[42,60],"broken":false},
		{"building":1,"level":1,"cell":[42,71],"broken":false},
		{"building":1,"level":1,"cell":[47,60],"broken":false},
		{"building":1,"level":1,"cell":[47,71],"broken":false},
		{"building":1,"level":1,"cell":[39,62],"broken":false},
		{"building":1,"level":2,"cell":[42,60],"broken":false},
		{"building":1,"level":2,"cell":[42,71],"broken":false},
		{"building":1,"level":2,"cell":[47,60],"broken":false},
		{"building":1,"level":2,"cell":[47,71],"broken":false},
		{"building":1,"level":2,"cell":[39,62],"broken":false},
		{"building":2,"level":0,"cell":[138,61],"broken":false},
		{"building":2,"level":0,"cell":[138,74],"broken":false},
		{"building":2,"level":0,"cell":[145,61],"broken":false},
		{"building":2,"level":0,"cell":[145,74],"broken":false},
		{"building":2,"level":0,"cell":[133,63],"broken":false},
		{"building":2,"level":1,"cell":[138,61],"broken":false},
		{"building":2,"level":1,"cell":[138,74],"broken":false},
		{"building":2,"level":1,"cell":[145,61],"broken":false},
		{"building":2,"level":1,"cell":[145,74],"broken":false},
		{"building":2,"level":1,"cell":[133,63],"broken":false},
		{"building":3,"level":0,"cell":[9,60],"broken":false},
		{"building":3,"level":0,"cell":[9,71],"broken":false},
		{"building":3,"level":0,"cell":[17,60],"broken":false},
		{"building":3,"level":0,"cell":[17,71],"broken":false},
		{"building":3,"level":0,"cell":[4,62],"broken":false},
		{"building":3,"level":1,"cell":[9,60],"broken":false},
		{"building":3,"level":1,"cell":[9,71],"broken":false},
		{"building":3,"level":1,"cell":[17,60],"broken":false},
		{"building":3,"level":1,"cell":[17,71],"broken":false},
		{"building":3,"level":1,"cell":[4,62],"broken":false},
		{"building":4,"level":0,"cell":[9,76],"broken":false},
		{"building":4,"level":0,"cell":[9,85],"broken":false},
		{"building":4,"level":0,"cell":[16,76],"broken":false},
		{"building":4,"level":0,"cell":[16,85],"broken":false},
		{"building":4,"level":0,"cell":[5,78],"broken":false},
		{"building":5,"level":0,"cell":[28,77],"broken":false},
		{"building":5,"level":0,"cell":[28,86],"broken":false},
		{"building":5,"level":0,"cell":[33,77],"broken":false},
		{"building":5,"level":0,"cell":[33,86],"broken":false},
		{"building":5,"level":0,"cell":[24,79],"broken":false},
		{"building":6,"level":0,"cell":[104,59],"broken":false},
		{"building":6,"level":0,"cell":[104,68],"broken":false},
		{"building":6,"level":0,"cell":[111,59],"broken":false},
		{"building":6,"level":0,"cell":[111,68],"broken":false},
		{"building":6,"level":0,"cell":[100,61],"broken":false},
		{"building":7,"level":0,"cell":[122,75],"broken":false},
		{"building":7,"level":0,"cell":[122,84],"broken":false},
		{"building":7,"level":0,"cell":[127,75],"broken":false},
		{"building":7,"level":0,"cell":[127,84],"broken":false},
		{"building":7,"level":0,"cell":[118,77],"broken":false},
		{"building":7,"level":1,"cell":[122,75],"broken":false},
		{"building":7,"level":1,"cell":[122,84],"broken":false},
		{"building":7,"level":1,"cell":[127,75],"broken":false},
		{"building":7,"level":1,"cell":[127,84],"broken":false},
		{"building":7,"level":1,"cell":[118,77],"broken":false},
		{"building":8,"level":0,"cell":[157,62],"broken":false},
		{"building":8,"level":0,"cell":[157,71],"broken":false},
		{"building":8,"level":0,"cell":[162,62],"broken":false},
		{"building":8,"level":0,"cell":[162,71],"broken":false},
		{"building":8,"level":0,"cell":[153,64],"broken":false},
		{"building":9,"level":0,"cell":[158,82],"broken":false},
		{"building":9,"level":0,"cell":[158,91],"broken":false},
		{"building":9,"level":0,"cell":[163,82],"broken":false},
		{"building":9,"level":0,"cell":[163,91],"broken":false},
		{"building":9,"level":0,"cell":[155,84],"broken":false},
		{"building":10,"level":0,"cell":[141,79],"broken":false},
		{"building":10,"level":0,"cell":[141,86],"broken":false},
		{"building":10,"level":0,"cell":[144,79],"broken":false},
		{"building":10,"level":0,"cell":[144,86],"broken":false},
		{"building":10,"level":0,"cell":[138,81],"broken":false},
		{"building":11,"level":0,"cell":[45,77],"broken":false},
		{"building":11,"level":0,"cell":[45,82],"broken":false},
		{"building":11,"level":0,"cell":[48,77],"broken":false},
		{"building":11,"level":0,"cell":[48,82],"broken":false},
		{"building":11,"level":0,"cell":[43,79],"broken":false},
		{"building":12,"level":0,"cell":[62,92],"broken":false},
		{"building":12,"level":0,"cell":[62,99],"broken":false},
		{"building":12,"level":0,"cell":[69,92],"broken":false},
		{"building":12,"level":0,"cell":[69,99],"broken":false},
		{"building":12,"level":0,"cell":[57,94],"broken":false},
		{"building":13,"level":0,"cell":[84,91],"broken":false},
		{"building":13,"level":0,"cell":[84,98],"broken":false},
		{"building":13,"level":0,"cell":[89,91],"broken":false},
		{"building":13,"level":0,"cell":[89,98],"broken":false},
		{"building":13,"level":0,"cell":[81,93],"broken":false},
		{"building":14,"level":0,"cell":[107,79],"broken":false},
		{"building":14,"level":0,"cell":[107,84],"broken":false},
		{"building":14,"level":0,"cell":[108,79],"broken":false},
		{"building":14,"level":0,"cell":[108,84],"broken":false},
		{"building":14,"level":0,"cell":[105,81],"broken":false}
	],
	"stairs": [
		{"cell":[56,62],"low":0,"high":1,"ladder":false},
		{"cell":[76,62],"low":-1,"high":0,"ladder":false},
		{"cell":[97,81],"low":-1,"high":0,"ladder":false},
		{"cell":[40,61],"low":0,"high":1,"ladder":false},
		{"cell":[49,70],"low":1,"high":2,"ladder":false},
		{"cell":[135,67],"low":0,"high":1,"ladder":false},
		{"cell":[6,65],"low":0,"high":1,"ladder":false},
		{"cell":[120,79],"low":0,"high":1,"ladder":false}
	],
	"props": [
		{"kind":"bell_rope","rect":[41,63,1,1],"solid":"none","facing":0,"note":"종 줄 한 가닥","level":1},
		{"kind":"bell_frame","rect":[45,62,4,3],"solid":"none","facing":1,"note":"종을 거는 나무 틀","level":2},
		{"kind":"water","rect":[0,18,10,8],"solid":"low","facing":2,"note":"언 물","level":0},
		{"kind":"water","rect":[10,18,10,8],"solid":"low","facing":3,"note":"언 물","level":0},
		{"kind":"water","rect":[20,18,10,8],"solid":"low","facing":0,"note":"언 물","level":0},
		{"kind":"water","rect":[30,18,10,8],"solid":"low","facing":1,"note":"언 물","level":0},
		{"kind":"water","rect":[40,18,10,8],"solid":"low","facing":2,"note":"언 물","level":0},
		{"kind":"water","rect":[50,18,10,8],"solid":"low","facing":3,"note":"언 물","level":0},
		{"kind":"water","rect":[60,18,10,8],"solid":"low","facing":0,"note":"언 물","level":0},
		{"kind":"water","rect":[70,18,10,8],"solid":"low","facing":1,"note":"언 물","level":0},
		{"kind":"water","rect":[80,18,4,8],"solid":"low","facing":2,"note":"언 물","level":0},
		{"kind":"water","rect":[92,18,10,8],"solid":"low","facing":3,"note":"언 물","level":0},
		{"kind":"water","rect":[102,18,10,8],"solid":"low","facing":0,"note":"언 물","level":0},
		{"kind":"water","rect":[112,18,10,8],"solid":"low","facing":1,"note":"언 물","level":0},
		{"kind":"water","rect":[122,18,10,8],"solid":"low","facing":2,"note":"언 물","level":0},
		{"kind":"water","rect":[132,18,10,8],"solid":"low","facing":3,"note":"언 물","level":0},
		{"kind":"water","rect":[142,18,10,8],"solid":"low","facing":0,"note":"언 물","level":0},
		{"kind":"water","rect":[152,18,10,8],"solid":"low","facing":1,"note":"언 물","level":0},
		{"kind":"water","rect":[162,18,10,8],"solid":"low","facing":2,"note":"언 물","level":0},
		{"kind":"water","rect":[172,18,8,8],"solid":"low","facing":3,"note":"언 물","level":0},
		{"kind":"water","rect":[15,26,10,8],"solid":"low","facing":0,"note":"언 물","level":0},
		{"kind":"water","rect":[25,26,10,8],"solid":"low","facing":1,"note":"언 물","level":0},
		{"kind":"water","rect":[35,26,10,8],"solid":"low","facing":2,"note":"언 물","level":0},
		{"kind":"water","rect":[45,26,10,8],"solid":"low","facing":3,"note":"언 물","level":0},
		{"kind":"water","rect":[55,26,10,8],"solid":"low","facing":0,"note":"언 물","level":0},
		{"kind":"water","rect":[65,26,10,8],"solid":"low","facing":1,"note":"언 물","level":0},
		{"kind":"water","rect":[75,26,9,8],"solid":"low","facing":2,"note":"언 물","level":0},
		{"kind":"water","rect":[15,34,10,8],"solid":"low","facing":3,"note":"언 물","level":0},
		{"kind":"water","rect":[25,34,10,8],"solid":"low","facing":0,"note":"언 물","level":0},
		{"kind":"water","rect":[35,34,10,8],"solid":"low","facing":1,"note":"언 물","level":0},
		{"kind":"water","rect":[45,34,10,8],"solid":"low","facing":2,"note":"언 물","level":0},
		{"kind":"water","rect":[55,34,10,8],"solid":"low","facing":3,"note":"언 물","level":0},
		{"kind":"water","rect":[65,34,10,8],"solid":"low","facing":0,"note":"언 물","level":0},
		{"kind":"water","rect":[75,34,9,8],"solid":"low","facing":1,"note":"언 물","level":0},
		{"kind":"water","rect":[15,42,10,8],"solid":"low","facing":2,"note":"언 물","level":0},
		{"kind":"water","rect":[25,42,10,8],"solid":"low","facing":3,"note":"언 물","level":0},
		{"kind":"water","rect":[35,42,10,8],"solid":"low","facing":0,"note":"언 물","level":0},
		{"kind":"water","rect":[45,42,10,8],"solid":"low","facing":1,"note":"언 물","level":0},
		{"kind":"water","rect":[55,42,10,8],"solid":"low","facing":2,"note":"언 물","level":0},
		{"kind":"water","rect":[65,42,10,8],"solid":"low","facing":3,"note":"언 물","level":0},
		{"kind":"water","rect":[75,42,9,8],"solid":"low","facing":0,"note":"언 물","level":0},
		{"kind":"water","rect":[15,50,10,8],"solid":"low","facing":1,"note":"언 물","level":0},
		{"kind":"water","rect":[25,50,10,8],"solid":"low","facing":2,"note":"언 물","level":0},
		{"kind":"water","rect":[35,50,10,8],"solid":"low","facing":3,"note":"언 물","level":0},
		{"kind":"water","rect":[45,50,10,8],"solid":"low","facing":0,"note":"언 물","level":0},
		{"kind":"water","rect":[55,50,10,8],"solid":"low","facing":1,"note":"언 물","level":0},
		{"kind":"water","rect":[65,50,10,8],"solid":"low","facing":2,"note":"언 물","level":0},
		{"kind":"water","rect":[75,50,9,8],"solid":"low","facing":3,"note":"언 물","level":0},
		{"kind":"water","rect":[92,26,10,4],"solid":"low","facing":0,"note":"언 물","level":0},
		{"kind":"water","rect":[102,26,10,4],"solid":"low","facing":1,"note":"언 물","level":0},
		{"kind":"water","rect":[112,26,10,4],"solid":"low","facing":2,"note":"언 물","level":0},
		{"kind":"water","rect":[122,26,10,4],"solid":"low","facing":3,"note":"언 물","level":0},
		{"kind":"water","rect":[132,26,10,4],"solid":"low","facing":0,"note":"언 물","level":0},
		{"kind":"water","rect":[142,26,10,4],"solid":"low","facing":1,"note":"언 물","level":0},
		{"kind":"water","rect":[152,26,10,4],"solid":"low","facing":2,"note":"언 물","level":0},
		{"kind":"water","rect":[162,26,10,4],"solid":"low","facing":3,"note":"언 물","level":0},
		{"kind":"water","rect":[172,26,8,4],"solid":"low","facing":0,"note":"언 물","level":0},
		{"kind":"water","rect":[172,30,8,8],"solid":"low","facing":1,"note":"언 물","level":0},
		{"kind":"water","rect":[172,38,8,8],"solid":"low","facing":2,"note":"언 물","level":0},
		{"kind":"water","rect":[172,46,8,8],"solid":"low","facing":3,"note":"언 물","level":0},
		{"kind":"water","rect":[172,54,8,4],"solid":"low","facing":0,"note":"언 물","level":0},
		{"kind":"water","rect":[84,18,2,2],"solid":"low","facing":1,"note":"언 물","level":0},
		{"kind":"water","rect":[90,18,2,2],"solid":"low","facing":2,"note":"언 물","level":0},
		{"kind":"car","rect":[31,11,4,2],"solid":"low","facing":3,"note":"길가에 선 차","level":0},
		{"kind":"bench","rect":[50,12,3,1],"solid":"low","facing":0,"note":"긴 의자","level":0},
		{"kind":"crate_stack","rect":[66,12,2,2],"solid":"low","facing":1,"note":"나무 상자","level":0},
		{"kind":"reed_bundle","rect":[84,22,2,2],"solid":"low","facing":2,"note":"묶어 둔 갈대","level":0},
		{"kind":"rubble_heap","rect":[88,27,4,3],"solid":"low","facing":3,"note":"무너진 벽돌","level":0},
		{"kind":"windbreak_fence","rect":[6,94,8,1],"solid":"low","facing":0,"note":"바람막이 담 토막","level":0},
		{"kind":"windbreak_fence","rect":[21,94,8,1],"solid":"low","facing":1,"note":"바람막이 담 토막","level":0},
		{"kind":"windbreak_fence","rect":[101,96,8,1],"solid":"low","facing":2,"note":"바람막이 담 토막","level":0},
		{"kind":"windbreak_fence","rect":[121,96,8,1],"solid":"low","facing":3,"note":"바람막이 담 토막","level":0},
		{"kind":"reed_bundle","rect":[17,91,2,2],"solid":"low","facing":0,"note":"묶어 둔 갈대","level":0},
		{"kind":"reed_bundle","rect":[31,90,2,2],"solid":"low","facing":1,"note":"묶어 둔 갈대","level":0},
		{"kind":"reed_bundle","rect":[109,94,2,2],"solid":"low","facing":2,"note":"묶어 둔 갈대","level":0},
		{"kind":"lamp_shelf","rect":[35,94,2,1],"solid":"low","facing":3,"note":"꺼진 등잔 선반","level":0},
		{"kind":"frozen_reeds","rect":[11,53,3,3],"solid":"none","facing":0,"note":"늪 가장자리 갈대","level":0},
		{"kind":"frozen_reeds","rect":[165,33,3,3],"solid":"none","facing":1,"note":"늪 가장자리 갈대","level":0},
		{"kind":"frozen_reeds","rect":[160,44,3,3],"solid":"none","facing":2,"note":"늪 가장자리 갈대","level":0},
		{"kind":"frozen_reeds","rect":[110,36,3,3],"solid":"none","facing":3,"note":"늪 가장자리 갈대","level":0},
		{"kind":"crate_stack","rect":[7,73,2,2],"solid":"low","facing":0,"note":"나무 상자","level":0},
		{"kind":"crate_stack","rect":[13,73,2,2],"solid":"low","facing":1,"note":"나무 상자","level":0},
		{"kind":"barrel","rect":[18,73,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"barrel","rect":[22,74,1,1],"solid":"low","facing":3,"note":"저장 통","level":0},
		{"kind":"handcart","rect":[30,73,2,1],"solid":"low","facing":0,"note":"뒷문 곁 손수레","level":0},
		{"kind":"lamp_post","rect":[117,86,1,1],"solid":"none","facing":1,"note":"꺼진 등잔 기둥","level":0},
		{"kind":"crate_stack","rect":[114,92,2,2],"solid":"low","facing":2,"note":"나무 상자","level":0},
		{"kind":"snow_drift","rect":[120,91,4,2],"solid":"none","facing":3,"note":"모서리의 눈더미","level":0},
		{"kind":"car","rect":[171,86,4,2],"solid":"low","facing":0,"note":"길가에 선 차","level":0},
		{"kind":"bare_tree","rect":[15,14,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[26,16,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[43,15,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[58,16,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[72,15,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[98,12,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[110,15,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[124,12,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[143,14,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[163,15,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[7,32,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[9,43,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[4,52,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[104,34,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[113,42,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[125,48,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[135,34,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[149,43,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[164,54,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[173,61,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[176,68,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[169,95,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[151,95,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[135,92,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[100,94,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[77,95,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[51,92,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[38,92,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[24,96,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[3,96,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[53,85,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[95,86,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"hymn_shelf","rect":[56,61,2,1],"solid":"low","facing":1,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[62,65,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[56,65,2,1],"solid":"low","facing":3,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[62,61,1,1],"solid":"low","facing":0,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[61,82,2,1],"solid":"low","facing":1,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[56,82,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[61,78,2,1],"solid":"low","facing":3,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[57,78,1,1],"solid":"low","facing":0,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[64,65,2,1],"solid":"low","facing":1,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[71,61,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[65,61,2,1],"solid":"low","facing":3,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[70,65,1,1],"solid":"low","facing":0,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[70,78,2,1],"solid":"low","facing":1,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[65,78,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[69,82,2,1],"solid":"low","facing":3,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[64,78,1,1],"solid":"low","facing":0,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[74,61,2,1],"solid":"low","facing":1,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[78,65,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[73,65,2,1],"solid":"low","facing":3,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[79,65,1,1],"solid":"low","facing":0,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[77,82,2,1],"solid":"low","facing":1,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[73,78,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[73,82,2,1],"solid":"low","facing":3,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[79,78,1,1],"solid":"low","facing":0,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[81,61,2,1],"solid":"low","facing":1,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[88,65,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[81,65,2,1],"solid":"low","facing":3,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[88,61,1,1],"solid":"low","facing":0,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[87,82,2,1],"solid":"low","facing":1,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[81,82,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[87,78,2,1],"solid":"low","facing":3,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[82,78,1,1],"solid":"low","facing":0,"note":"글씨 없는 손종","level":0},
		{"kind":"parish_chest","rect":[90,65,2,1],"solid":"low","facing":1,"note":"회중 기록 궤","level":0},
		{"kind":"hymn_shelf","rect":[96,61,2,1],"solid":"low","facing":2,"note":"찬송집 선반","level":0},
		{"kind":"desk","rect":[91,61,2,1],"solid":"low","facing":3,"note":"책상","level":0},
		{"kind":"candle_stand","rect":[96,65,1,1],"solid":"low","facing":0,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"hymn_shelf","rect":[96,78,2,1],"solid":"low","facing":1,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[91,78,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[95,82,2,1],"solid":"low","facing":3,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[90,78,1,1],"solid":"low","facing":0,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[59,71,2,1],"solid":"none","facing":1,"note":"찬송집 선반","level":1},
		{"kind":"candle_stand","rect":[56,61,1,1],"solid":"none","facing":2,"note":"초 하나가 선 외줄기 촛대","level":1},
		{"kind":"vestry_chest","rect":[56,71,2,1],"solid":"none","facing":3,"note":"제의실 궤","level":1},
		{"kind":"hand_bell","rect":[61,61,1,1],"solid":"none","facing":0,"note":"글씨 없는 손종","level":1},
		{"kind":"hymn_shelf","rect":[56,73,2,1],"solid":"none","facing":1,"note":"찬송집 선반","level":1},
		{"kind":"candle_stand","rect":[61,82,1,1],"solid":"none","facing":2,"note":"초 하나가 선 외줄기 촛대","level":1},
		{"kind":"vestry_chest","rect":[56,82,2,1],"solid":"none","facing":3,"note":"제의실 궤","level":1},
		{"kind":"hand_bell","rect":[61,73,1,1],"solid":"none","facing":0,"note":"글씨 없는 손종","level":1},
		{"kind":"cold_stove","rect":[86,79,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":-1},
		{"kind":"coal_bin","rect":[79,78,3,2],"solid":"none","facing":2,"note":"난방용 석탄","level":-1},
		{"kind":"firewood_pile","rect":[85,64,2,1],"solid":"none","facing":3,"note":"처마 밑 장작","level":-1},
		{"kind":"barrel","rect":[80,64,1,1],"solid":"none","facing":0,"note":"저장 통","level":-1},
		{"kind":"cask_stack","rect":[88,78,2,2],"solid":"none","facing":1,"note":"저장고 큰 통","level":-1},
		{"kind":"sack_pile","rect":[93,64,2,2],"solid":"none","facing":2,"note":"곡물 자루","level":-1},
		{"kind":"relief_crate","rect":[89,64,2,1],"solid":"none","facing":3,"note":"남은 구호 식량 상자","level":-1},
		{"kind":"barrel","rect":[93,79,1,1],"solid":"none","facing":0,"note":"저장 통","level":-1},
		{"kind":"hand_bell","rect":[41,61,1,1],"solid":"low","facing":1,"note":"글씨 없는 손종","level":0},
		{"kind":"lamp_shelf","rect":[41,70,2,1],"solid":"low","facing":2,"note":"꺼진 등잔 선반","level":0},
		{"kind":"candle_stand","rect":[43,70,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"hand_bell","rect":[48,70,1,1],"solid":"low","facing":0,"note":"글씨 없는 손종","level":0},
		{"kind":"lamp_shelf","rect":[45,61,2,1],"solid":"low","facing":1,"note":"꺼진 등잔 선반","level":0},
		{"kind":"bench","rect":[45,70,3,1],"solid":"low","facing":2,"note":"긴 의자","level":0},
		{"kind":"candle_stand","rect":[49,61,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"hand_bell","rect":[43,70,1,1],"solid":"none","facing":0,"note":"글씨 없는 손종","level":1},
		{"kind":"lamp_shelf","rect":[40,70,2,1],"solid":"none","facing":1,"note":"꺼진 등잔 선반","level":1},
		{"kind":"bench","rect":[41,61,3,1],"solid":"none","facing":2,"note":"긴 의자","level":1},
		{"kind":"candle_stand","rect":[42,70,1,1],"solid":"none","facing":3,"note":"초 하나가 선 외줄기 촛대","level":1},
		{"kind":"hand_bell","rect":[45,70,1,1],"solid":"none","facing":0,"note":"글씨 없는 손종","level":1},
		{"kind":"lamp_shelf","rect":[48,61,2,1],"solid":"none","facing":1,"note":"꺼진 등잔 선반","level":1},
		{"kind":"bench","rect":[46,70,3,1],"solid":"none","facing":2,"note":"긴 의자","level":1},
		{"kind":"candle_stand","rect":[46,61,1,1],"solid":"none","facing":3,"note":"초 하나가 선 외줄기 촛대","level":1},
		{"kind":"hand_bell","rect":[40,70,1,1],"solid":"none","facing":0,"note":"글씨 없는 손종","level":2},
		{"kind":"lamp_shelf","rect":[42,61,2,1],"solid":"none","facing":1,"note":"꺼진 등잔 선반","level":2},
		{"kind":"bench","rect":[41,70,3,1],"solid":"none","facing":2,"note":"긴 의자","level":2},
		{"kind":"candle_stand","rect":[40,61,1,1],"solid":"none","facing":3,"note":"초 하나가 선 외줄기 촛대","level":2},
		{"kind":"hand_bell","rect":[49,61,1,1],"solid":"none","facing":0,"note":"글씨 없는 손종","level":2},
		{"kind":"lamp_shelf","rect":[46,61,2,1],"solid":"none","facing":1,"note":"꺼진 등잔 선반","level":2},
		{"kind":"bench","rect":[46,70,3,1],"solid":"none","facing":2,"note":"긴 의자","level":2},
		{"kind":"candle_stand","rect":[45,61,1,1],"solid":"none","facing":3,"note":"초 하나가 선 외줄기 촛대","level":2},
		{"kind":"bed","rect":[135,62,2,1],"solid":"low","facing":0,"note":"침대","level":0},
		{"kind":"desk","rect":[147,65,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[134,62,1,1],"solid":"low","facing":2,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[134,65,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[147,73,2,1],"solid":"low","facing":0,"note":"침대","level":0},
		{"kind":"desk","rect":[134,70,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[149,73,1,1],"solid":"low","facing":2,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[134,73,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[134,62,2,1],"solid":"none","facing":0,"note":"침대","level":1},
		{"kind":"desk","rect":[148,65,2,1],"solid":"none","facing":1,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[134,65,1,1],"solid":"none","facing":2,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[147,62,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[148,73,2,1],"solid":"none","facing":0,"note":"침대","level":1},
		{"kind":"desk","rect":[134,73,2,1],"solid":"none","facing":1,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[149,70,1,1],"solid":"none","facing":2,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[135,70,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"shelf","rect":[5,63,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"barrel","rect":[6,61,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"handcart","rect":[20,63,2,1],"solid":"low","facing":3,"note":"뒷문 곁 손수레","level":0},
		{"kind":"shelf","rect":[20,68,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"barrel","rect":[21,70,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"handcart","rect":[5,70,2,1],"solid":"low","facing":3,"note":"뒷문 곁 손수레","level":0},
		{"kind":"bed","rect":[6,61,2,1],"solid":"none","facing":0,"note":"침대","level":1},
		{"kind":"desk","rect":[20,63,2,1],"solid":"none","facing":1,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[5,61,1,1],"solid":"none","facing":2,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[5,63,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[20,70,2,1],"solid":"none","facing":0,"note":"침대","level":1},
		{"kind":"desk","rect":[5,68,2,1],"solid":"none","facing":1,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[22,70,1,1],"solid":"none","facing":2,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[5,70,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"shelf","rect":[6,77,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"crate_stack","rect":[11,83,2,2],"solid":"low","facing":1,"note":"나무 상자","level":0},
		{"kind":"barrel","rect":[6,84,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"handcart","rect":[11,77,2,1],"solid":"low","facing":3,"note":"뒷문 곁 손수레","level":0},
		{"kind":"shelf","rect":[17,84,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"crate_stack","rect":[14,83,2,2],"solid":"low","facing":1,"note":"나무 상자","level":0},
		{"kind":"barrel","rect":[19,77,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"handcart","rect":[15,77,2,1],"solid":"low","facing":3,"note":"뒷문 곁 손수레","level":0},
		{"kind":"shelf","rect":[25,85,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"crate_stack","rect":[29,78,2,2],"solid":"low","facing":1,"note":"나무 상자","level":0},
		{"kind":"barrel","rect":[26,78,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"handcart","rect":[28,85,2,1],"solid":"low","facing":3,"note":"뒷문 곁 손수레","level":0},
		{"kind":"shelf","rect":[34,78,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"crate_stack","rect":[34,84,2,2],"solid":"low","facing":1,"note":"나무 상자","level":0},
		{"kind":"barrel","rect":[32,78,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"handcart","rect":[32,85,2,1],"solid":"low","facing":3,"note":"뒷문 곁 손수레","level":0},
		{"kind":"display_shelf","rect":[102,60,4,1],"solid":"low","facing":0,"note":"가게 진열대","level":0},
		{"kind":"shop_counter","rect":[104,67,3,1],"solid":"low","facing":1,"note":"가게 계산대","level":0},
		{"kind":"freezer_chest","rect":[101,67,2,1],"solid":"low","facing":2,"note":"냉동 궤","level":0},
		{"kind":"barrel","rect":[107,67,1,1],"solid":"low","facing":3,"note":"저장 통","level":0},
		{"kind":"display_shelf","rect":[110,67,4,1],"solid":"low","facing":0,"note":"가게 진열대","level":0},
		{"kind":"shop_counter","rect":[109,60,3,1],"solid":"low","facing":1,"note":"가게 계산대","level":0},
		{"kind":"freezer_chest","rect":[113,60,2,1],"solid":"low","facing":2,"note":"냉동 궤","level":0},
		{"kind":"barrel","rect":[109,67,1,1],"solid":"low","facing":3,"note":"저장 통","level":0},
		{"kind":"bed","rect":[119,76,2,1],"solid":"low","facing":0,"note":"침대","level":0},
		{"kind":"desk","rect":[123,83,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[119,83,1,1],"solid":"low","facing":2,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[122,76,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[129,83,2,1],"solid":"low","facing":0,"note":"침대","level":0},
		{"kind":"desk","rect":[126,83,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[130,76,1,1],"solid":"low","facing":2,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[127,76,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[119,83,2,1],"solid":"none","facing":0,"note":"침대","level":1},
		{"kind":"desk","rect":[123,76,2,1],"solid":"none","facing":1,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[120,76,1,1],"solid":"none","facing":2,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[121,83,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[129,76,2,1],"solid":"none","facing":0,"note":"침대","level":1},
		{"kind":"desk","rect":[127,76,2,1],"solid":"none","facing":1,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[129,83,1,1],"solid":"none","facing":2,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[126,83,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[155,63,2,1],"solid":"low","facing":0,"note":"침대","level":0},
		{"kind":"desk","rect":[157,70,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[154,63,1,1],"solid":"low","facing":2,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[154,70,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[163,70,2,1],"solid":"low","facing":0,"note":"침대","level":0},
		{"kind":"desk","rect":[161,63,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[165,70,1,1],"solid":"low","facing":2,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[163,63,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[156,83,2,1],"solid":"low","facing":0,"note":"침대","level":0},
		{"kind":"desk","rect":[159,90,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[156,90,1,1],"solid":"low","facing":2,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[158,83,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[164,90,2,1],"solid":"low","facing":0,"note":"침대","level":0},
		{"kind":"desk","rect":[162,90,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[165,83,1,1],"solid":"low","facing":2,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[162,83,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"cold_stove","rect":[139,85,1,1],"solid":"low","facing":0,"note":"꺼진 난로","level":0},
		{"kind":"coal_bin","rect":[144,80,3,2],"solid":"low","facing":1,"note":"난방용 석탄","level":0},
		{"kind":"firewood_pile","rect":[140,80,2,1],"solid":"low","facing":2,"note":"처마 밑 장작","level":0},
		{"kind":"barrel","rect":[145,85,1,1],"solid":"low","facing":3,"note":"저장 통","level":0},
		{"kind":"bed","rect":[48,78,2,1],"solid":"low","facing":0,"note":"침대","level":0},
		{"kind":"desk","rect":[45,78,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[48,81,1,1],"solid":"low","facing":2,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[44,81,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"shelf","rect":[59,93,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"crate_stack","rect":[63,97,2,2],"solid":"low","facing":1,"note":"나무 상자","level":0},
		{"kind":"barrel","rect":[58,93,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"handcart","rect":[58,98,2,1],"solid":"low","facing":3,"note":"뒷문 곁 손수레","level":0},
		{"kind":"shelf","rect":[70,98,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"crate_stack","rect":[67,93,2,2],"solid":"low","facing":1,"note":"나무 상자","level":0},
		{"kind":"barrel","rect":[73,98,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"handcart","rect":[67,98,2,1],"solid":"low","facing":3,"note":"뒷문 곁 손수레","level":0},
		{"kind":"shelf","rect":[82,92,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"crate_stack","rect":[90,96,2,2],"solid":"low","facing":1,"note":"나무 상자","level":0},
		{"kind":"barrel","rect":[82,97,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"handcart","rect":[90,92,2,1],"solid":"low","facing":3,"note":"뒷문 곁 손수레","level":0},
		{"kind":"bed","rect":[108,83,2,1],"solid":"low","facing":0,"note":"침대","level":0},
		{"kind":"desk","rect":[106,83,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[109,80,1,1],"solid":"low","facing":2,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[106,80,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"community_banner","rect":[8,61,1,2],"solid":"none","facing":0,"note":"무늬 없는 바랜 천 깃발","level":1},
		{"kind":"hand_bell","rect":[136,62,1,1],"solid":"none","facing":1,"note":"글씨 없는 손종","level":1},
		{"kind":"hymn_shelf","rect":[106,60,2,1],"solid":"low","facing":2,"note":"찬송집 선반","level":0},
		{"kind":"pew_row","rect":[60,67,6,1],"solid":"low","facing":3,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[86,67,6,1],"solid":"low","facing":0,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[60,69,6,1],"solid":"low","facing":1,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[86,69,6,1],"solid":"low","facing":2,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[57,71,6,1],"solid":"low","facing":3,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[81,71,6,1],"solid":"low","facing":0,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[57,73,6,1],"solid":"low","facing":1,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[81,73,6,1],"solid":"low","facing":2,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[60,75,6,1],"solid":"low","facing":3,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[86,75,6,1],"solid":"low","facing":0,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"crate_stack","rect":[5,68,2,2],"solid":"low","facing":1,"note":"나무 상자","level":0},
		{"kind":"crate_stack","rect":[9,61,2,2],"solid":"low","facing":1,"note":"나무 상자","level":0},
		{"kind":"altar_table","rect":[91,68,3,1],"solid":"low","facing":1,"note":"무늬 없는 천을 덮은 제단 탁자","level":0},
		{"kind":"pulpit","rect":[95,68,2,2],"solid":"low","facing":2,"note":"설교단","level":0},
		{"kind":"candle_stand","rect":[90,68,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"candle_stand","rect":[89,68,1,1],"solid":"low","facing":0,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"community_banner","rect":[93,69,1,2],"solid":"none","facing":1,"note":"무늬 없는 바랜 천 깃발","level":0},
		{"kind":"lamp_shelf","rect":[121,86,2,1],"solid":"low","facing":2,"note":"맨홀 곁 꺼진 등잔","level":0},
		{"kind":"crate_stack","rect":[120,93,2,2],"solid":"low","facing":3,"note":"맨홀 곁 나무 상자","level":0},
		{"kind":"blanket_screen","rect":[113,86,3,1],"solid":"low","facing":0,"note":"맨홀 곁 반쯤 접힌 젖은 담요","level":0},
		{"kind":"barrel","rect":[101,60,1,1],"solid":"low","facing":1,"note":"저장 통","level":0},
		{"kind":"barrel","rect":[101,61,1,1],"solid":"low","facing":2,"note":"저장 통","level":0}
	],
	"rooms": [
		{"building":0,"level":0,"rect":[56,61,7,5],"name":"찬송집 방","theme":"church"},
		{"building":0,"level":0,"rect":[56,78,7,5],"name":"종지기 방","theme":"church"},
		{"building":0,"level":0,"rect":[64,61,8,5],"name":"현관 방","theme":"church"},
		{"building":0,"level":0,"rect":[64,78,8,5],"name":"옆 예배실","theme":"church"},
		{"building":0,"level":0,"rect":[73,61,7,5],"name":"제의실","theme":"church"},
		{"building":0,"level":0,"rect":[73,78,7,5],"name":"회중 준비방","theme":"church"},
		{"building":0,"level":0,"rect":[81,61,8,5],"name":"교구 사무방","theme":"church"},
		{"building":0,"level":0,"rect":[81,78,8,5],"name":"성가대방","theme":"church"},
		{"building":0,"level":0,"rect":[90,61,8,5],"name":"기록방","theme":"archive"},
		{"building":0,"level":0,"rect":[90,78,8,5],"name":"안쪽 저장실","theme":"church"},
		{"building":0,"level":0,"rect":[56,67,42,10],"name":"회중석","theme":"nave"},
		{"building":0,"level":1,"rect":[56,61,6,11],"name":"합창 다락 앞방","theme":"church"},
		{"building":0,"level":1,"rect":[56,73,6,10],"name":"합창 다락 뒷방","theme":"church"},
		{"building":0,"level":-1,"rect":[79,64,8,16],"name":"난방실","theme":"heat"},
		{"building":0,"level":-1,"rect":[88,64,7,16],"name":"막다른 식량 저장실","theme":"cellar"},
		{"building":0,"level":-1,"rect":[76,61,22,2],"name":"저장고 둘레 통로","theme":"corridor"},
		{"building":1,"level":0,"rect":[40,61,4,10],"name":"탑 아래 앞방","theme":"tower"},
		{"building":1,"level":0,"rect":[45,61,5,10],"name":"탑 아래 뒷방","theme":"tower"},
		{"building":1,"level":1,"rect":[40,61,4,10],"name":"종 줄 방","theme":"tower"},
		{"building":1,"level":1,"rect":[45,61,5,10],"name":"종 줄 방의 돌아가는 길","theme":"tower"},
		{"building":1,"level":2,"rect":[40,61,4,10],"name":"종 다락 앞방","theme":"tower"},
		{"building":1,"level":2,"rect":[45,61,5,10],"name":"종 다락","theme":"tower"},
		{"building":2,"level":0,"rect":[134,62,16,4],"name":"사제관 앞방","theme":"home"},
		{"building":2,"level":0,"rect":[134,70,16,4],"name":"사제관 뒷방","theme":"home"},
		{"building":2,"level":1,"rect":[134,62,16,4],"name":"사제관 앞방","theme":"home"},
		{"building":2,"level":1,"rect":[134,70,16,4],"name":"사제관 뒷방","theme":"home"},
		{"building":3,"level":0,"rect":[5,61,18,3],"name":"어부 창고 가 앞방","theme":"store"},
		{"building":3,"level":0,"rect":[5,68,18,3],"name":"어부 창고 가 뒷방","theme":"store"},
		{"building":3,"level":1,"rect":[5,61,18,3],"name":"어부 창고 가 앞방","theme":"home"},
		{"building":3,"level":1,"rect":[5,68,18,3],"name":"어부 창고 가 뒷방","theme":"home"},
		{"building":4,"level":0,"rect":[6,77,7,8],"name":"어부 창고 나 앞방","theme":"store"},
		{"building":4,"level":0,"rect":[14,77,6,8],"name":"어부 창고 나 뒷방","theme":"store"},
		{"building":5,"level":0,"rect":[25,78,6,8],"name":"어부 창고 다 앞방","theme":"store"},
		{"building":5,"level":0,"rect":[32,78,5,8],"name":"어부 창고 다 뒷방","theme":"store"},
		{"building":6,"level":0,"rect":[101,60,7,8],"name":"어귀 가게 앞방","theme":"shop"},
		{"building":6,"level":0,"rect":[109,60,6,8],"name":"어귀 가게 뒷방","theme":"shop"},
		{"building":7,"level":0,"rect":[119,76,6,8],"name":"어귀 여관 앞방","theme":"home"},
		{"building":7,"level":0,"rect":[126,76,5,8],"name":"어귀 여관 뒷방","theme":"home"},
		{"building":7,"level":1,"rect":[119,76,6,8],"name":"어귀 여관 앞방","theme":"home"},
		{"building":7,"level":1,"rect":[126,76,5,8],"name":"어귀 여관 뒷방","theme":"home"},
		{"building":8,"level":0,"rect":[154,63,6,8],"name":"갈대 지붕 집 가 앞방","theme":"home"},
		{"building":8,"level":0,"rect":[161,63,5,8],"name":"갈대 지붕 집 가 뒷방","theme":"home"},
		{"building":9,"level":0,"rect":[156,83,5,8],"name":"갈대 지붕 집 나 앞방","theme":"home"},
		{"building":9,"level":0,"rect":[162,83,4,8],"name":"갈대 지붕 집 나 뒷방","theme":"home"},
		{"building":10,"level":0,"rect":[139,80,8,6],"name":"장작 헛간 안방","theme":"heat"},
		{"building":11,"level":0,"rect":[44,78,6,4],"name":"종지기 집 안방","theme":"home"},
		{"building":12,"level":0,"rect":[58,93,8,6],"name":"그물 말림 헛간 앞방","theme":"store"},
		{"building":12,"level":0,"rect":[67,93,7,6],"name":"그물 말림 헛간 뒷방","theme":"store"},
		{"building":13,"level":0,"rect":[82,92,10,6],"name":"선구 헛간 안방","theme":"store"},
		{"building":14,"level":0,"rect":[106,80,4,4],"name":"우물집 안방","theme":"home"}
	],
	"containers": [
		{"id":"box_001","name":"찬송집 방 보관함","cell":[56,64],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_002","name":"종지기 방 보관함","cell":[57,81],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_003","name":"현관 방 보관함","cell":[64,64],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_004","name":"옆 예배실 보관함","cell":[67,81],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_005","name":"제의실 보관함","cell":[79,63],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_006","name":"회중 준비방 보관함","cell":[73,81],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_007","name":"교구 사무방 보관함","cell":[81,64],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_008","name":"성가대방 보관함","cell":[83,81],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_009","name":"기록방 보관함","cell":[97,63],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_010","name":"안쪽 저장실 보관함","cell":[92,81],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_011","name":"회중석 보관함","cell":[74,73],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_012","name":"합창 다락 앞방 보관함","cell":[61,67],"building":0,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_013","name":"합창 다락 뒷방 보관함","cell":[60,79],"building":0,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_014","name":"난방실 보관함","cell":[83,74],"building":0,"search":6,"items":["document","symbol_bell","food_pack"],"locked":false,"level":-1,"searched":false},
		{"id":"box_015","name":"막다른 식량 저장실 보관함","cell":[91,74],"building":0,"search":4,"items":["symbol_bell","document","food_pack"],"locked":false,"level":-1,"searched":false},
		{"id":"box_016","name":"탑 아래 앞방 보관함","cell":[42,66],"building":1,"search":4,"items":["symbol_bell"],"locked":false,"level":0,"searched":false},
		{"id":"box_017","name":"탑 아래 뒷방 보관함","cell":[49,66],"building":1,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_018","name":"종 줄 방 보관함","cell":[40,67],"building":1,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_019","name":"종 줄 방의 돌아가는 길 보관함","cell":[49,66],"building":1,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_020","name":"종 다락 앞방 보관함","cell":[40,67],"building":1,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_021","name":"종 다락 보관함","cell":[49,66],"building":1,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_022","name":"사제관 앞방 보관함","cell":[140,64],"building":2,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_023","name":"사제관 뒷방 보관함","cell":[140,72],"building":2,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_024","name":"사제관 앞방 보관함","cell":[143,64],"building":2,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_025","name":"사제관 뒷방 보관함","cell":[144,72],"building":2,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_026","name":"어부 창고 가 앞방 보관함","cell":[18,62],"building":3,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_027","name":"어부 창고 가 뒷방 보관함","cell":[22,69],"building":3,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_028","name":"어부 창고 가 앞방 보관함","cell":[22,62],"building":3,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_029","name":"어부 창고 가 뒷방 보관함","cell":[22,69],"building":3,"search":6,"items":["cloth","symbol_bell","food_pack"],"locked":false,"level":1,"searched":false},
		{"id":"box_030","name":"어부 창고 나 앞방 보관함","cell":[8,82],"building":4,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_031","name":"어부 창고 나 뒷방 보관함","cell":[19,80],"building":4,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_032","name":"어부 창고 다 앞방 보관함","cell":[26,83],"building":5,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_033","name":"어부 창고 다 뒷방 보관함","cell":[32,83],"building":5,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_034","name":"어귀 가게 앞방 보관함","cell":[102,65],"building":6,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_035","name":"어귀 가게 뒷방 보관함","cell":[110,65],"building":6,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_036","name":"어귀 여관 앞방 보관함","cell":[122,81],"building":7,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_037","name":"어귀 여관 뒷방 보관함","cell":[127,81],"building":7,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_038","name":"어귀 여관 앞방 보관함","cell":[121,81],"building":7,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_039","name":"어귀 여관 뒷방 보관함","cell":[128,81],"building":7,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_040","name":"갈대 지붕 집 가 앞방 보관함","cell":[155,68],"building":8,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_041","name":"갈대 지붕 집 가 뒷방 보관함","cell":[163,68],"building":8,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_042","name":"갈대 지붕 집 나 앞방 보관함","cell":[158,88],"building":9,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_043","name":"갈대 지붕 집 나 뒷방 보관함","cell":[163,88],"building":9,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_044","name":"장작 헛간 안방 보관함","cell":[141,84],"building":10,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_045","name":"종지기 집 안방 보관함","cell":[47,80],"building":11,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_046","name":"그물 말림 헛간 앞방 보관함","cell":[61,96],"building":12,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_047","name":"그물 말림 헛간 뒷방 보관함","cell":[73,95],"building":12,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_048","name":"선구 헛간 안방 보관함","cell":[88,95],"building":13,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_049","name":"우물집 안방 보관함","cell":[109,81],"building":14,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_050","name":"승강장 남은 상자","cell":[51,10],"building":-1,"search":3,"items":["plank","cloth"],"locked":false,"level":0,"searched":false}
	],
	"entries": [
		{"id":"west_coast","cells":[[0,87],[0,88],[0,89],[0,90]],"gap":0.6},
		{"id":"east_coast","cells":[[179,77],[179,78],[179,79],[179,80]],"gap":0.6},
		{"id":"west_pass","cells":[[0,65],[0,66],[0,67]],"gap":2}
	],
	"holes": [
		{"id":"manhole_01","cell":[118,89],"name":"해안 길 맨홀","level":0,"gap":3}
	],
	"slots": [
		[86,18],
		[88,18],
		[86,23],
		[88,23],
		[84,28],
		[85,28]
	],
	"dead": [
		[2,88],
		[176,79],
		[1,67],
		[130,88],
		[169,66]
	],
	"deep": [
		"C",
		"E"
	],
	"work": {"cell":[118,72],"rect":[96,58,26,16]}
}

# 위쪽 일터의 독립 평면. 아래쪽 계획의 건물 번호 뒤에만 덧붙인다.
const NORTH: Dictionary = {
	"names": {"H":"북쪽 밭 마당","I":"동쪽 둑 마을"},
	"zones": [
		{"id":"H","rect":[0,0,116,46]},
		{"id":"I","rect":[116,0,64,46]}
	],
	"ground": [
		{"rect":[0,0,116,21],"kind":"DEEP_SNOW"},
		{"rect":[116,0,64,45],"kind":"GRAVEL"},
		{"rect":[62,0,6,43],"kind":"ROAD"},
		{"rect":[0,1,62,4],"kind":"ROAD"},
		{"rect":[98,17,82,4],"kind":"ROAD"},
		{"rect":[98,21,4,22],"kind":"WOOD"},
		{"rect":[62,21,6,3],"kind":"WOOD"},
		{"rect":[13,8,7,7],"kind":"GRAVEL"},
		{"rect":[112,24,4,21],"kind":"ROAD"},
		{"rect":[10,24,6,21],"kind":"ROAD"},
		{"rect":[96,34,6,11],"kind":"ROAD"}
	],
	"buildings": [
		{"id":15,"name":"종자 창고","rect":[92,1,24,12],"warm":false,"window_broken":false},
		{"id":16,"name":"간척 농가","rect":[28,5,18,8],"warm":false,"window_broken":false},
		{"id":17,"name":"사일로","rect":[4,5,10,10],"warm":false,"window_broken":false},
		{"id":18,"name":"배수 펌프 오두막","rect":[54,15,8,6],"warm":false,"window_broken":false},
		{"id":19,"name":"건초 헛간","rect":[70,3,20,9],"warm":false,"window_broken":false},
		{"id":20,"name":"농기구 헛간","rect":[120,3,14,8],"warm":false,"window_broken":false},
		{"id":21,"name":"둑 마을 농가","rect":[116,26,22,12],"warm":false,"window_broken":false},
		{"id":22,"name":"둑지기 집","rect":[150,28,12,10],"warm":false,"window_broken":false}
	],
	"shells": [
		{"building":15,"level":-1,"rect":[92,1,24,12]},
		{"building":15,"level":0,"rect":[92,1,24,12]},
		{"building":15,"level":1,"rect":[92,1,24,12]},
		{"building":16,"level":0,"rect":[28,5,18,8]},
		{"building":16,"level":1,"rect":[28,5,18,8]},
		{"building":17,"level":0,"rect":[4,5,10,10]},
		{"building":17,"level":1,"rect":[4,5,10,10]},
		{"building":17,"level":2,"rect":[4,5,10,10]},
		{"building":18,"level":0,"rect":[54,15,8,6]},
		{"building":19,"level":0,"rect":[70,3,20,9]},
		{"building":20,"level":0,"rect":[120,3,14,8]},
		{"building":21,"level":0,"rect":[116,26,22,12]},
		{"building":21,"level":1,"rect":[116,26,22,12]},
		{"building":22,"level":0,"rect":[150,28,12,10]},
		{"building":22,"level":1,"rect":[150,28,12,10]}
	],
	"walls": [
		{"level":-1,"rect":[104,2,1,10]},
		{"level":0,"rect":[93,5,22,1]},
		{"level":0,"rect":[93,8,22,1]},
		{"level":0,"rect":[99,2,1,3]},
		{"level":0,"rect":[99,9,1,3]},
		{"level":0,"rect":[106,2,1,3]},
		{"level":0,"rect":[106,9,1,3]},
		{"level":1,"rect":[104,2,1,10]},
		{"level":0,"rect":[37,6,1,6]},
		{"level":1,"rect":[37,6,1,6]},
		{"level":0,"rect":[10,6,1,8]},
		{"level":0,"rect":[5,10,6,1]},
		{"level":1,"rect":[9,6,1,8]},
		{"level":2,"rect":[9,6,1,8]},
		{"level":0,"rect":[80,4,1,7]},
		{"level":0,"rect":[127,4,1,6]},
		{"level":0,"rect":[127,27,1,10]},
		{"level":1,"rect":[127,27,1,10]},
		{"level":0,"rect":[156,29,1,8]},
		{"level":1,"rect":[156,29,1,8]}
	],
	"doors": [
		{"building":15,"level":-1,"cell":[104,7],"side":[1,0],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[96,5],"side":[0,1],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[96,8],"side":[0,-1],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[103,5],"side":[0,1],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[103,8],"side":[0,-1],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[111,5],"side":[0,1],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[111,8],"side":[0,-1],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[104,12],"side":[0,1],"state":"open","outer":true},
		{"building":15,"level":1,"cell":[104,7],"side":[1,0],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[37,9],"side":[1,0],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[33,12],"side":[0,1],"state":"open","outer":true},
		{"building":16,"level":1,"cell":[37,9],"side":[1,0],"state":"open","outer":false},
		{"building":17,"level":0,"cell":[10,8],"side":[1,0],"state":"open","outer":false},
		{"building":17,"level":0,"cell":[10,12],"side":[1,0],"state":"open","outer":false},
		{"building":17,"level":0,"cell":[13,10],"side":[1,0],"state":"open","outer":true},
		{"building":17,"level":1,"cell":[9,10],"side":[1,0],"state":"open","outer":false},
		{"building":17,"level":2,"cell":[9,10],"side":[1,0],"state":"open","outer":false},
		{"building":18,"level":0,"cell":[58,15],"side":[0,-1],"state":"open","outer":true},
		{"building":19,"level":0,"cell":[80,7],"side":[1,0],"state":"open","outer":false},
		{"building":19,"level":0,"cell":[75,11],"side":[0,1],"state":"open","outer":true},
		{"building":20,"level":0,"cell":[127,7],"side":[1,0],"state":"open","outer":false},
		{"building":20,"level":0,"cell":[124,10],"side":[0,1],"state":"open","outer":true},
		{"building":21,"level":0,"cell":[127,32],"side":[1,0],"state":"open","outer":false},
		{"building":21,"level":0,"cell":[137,32],"side":[1,0],"state":"open","outer":true},
		{"building":21,"level":1,"cell":[127,32],"side":[1,0],"state":"open","outer":false},
		{"building":22,"level":0,"cell":[156,33],"side":[1,0],"state":"open","outer":false},
		{"building":22,"level":0,"cell":[150,33],"side":[-1,0],"state":"open","outer":true},
		{"building":22,"level":1,"cell":[156,33],"side":[1,0],"state":"open","outer":false}
	],
	"windows": [
		{"building":15,"level":-1,"cell":[98,1],"broken":false},
		{"building":15,"level":-1,"cell":[110,1],"broken":false},
		{"building":15,"level":0,"cell":[96,1],"broken":false},
		{"building":15,"level":0,"cell":[103,1],"broken":false},
		{"building":15,"level":0,"cell":[111,1],"broken":false},
		{"building":15,"level":1,"cell":[98,1],"broken":false},
		{"building":15,"level":1,"cell":[110,1],"broken":false},
		{"building":16,"level":0,"cell":[33,5],"broken":false},
		{"building":16,"level":0,"cell":[41,5],"broken":false},
		{"building":16,"level":1,"cell":[33,5],"broken":false},
		{"building":16,"level":1,"cell":[41,5],"broken":false},
		{"building":17,"level":0,"cell":[7,5],"broken":false},
		{"building":17,"level":1,"cell":[7,5],"broken":false},
		{"building":17,"level":1,"cell":[11,5],"broken":false},
		{"building":17,"level":2,"cell":[7,5],"broken":false},
		{"building":17,"level":2,"cell":[11,5],"broken":false},
		{"building":18,"level":0,"cell":[58,20],"broken":false},
		{"building":19,"level":0,"cell":[75,3],"broken":false},
		{"building":19,"level":0,"cell":[85,3],"broken":false},
		{"building":20,"level":0,"cell":[124,3],"broken":false},
		{"building":20,"level":0,"cell":[130,3],"broken":false},
		{"building":21,"level":0,"cell":[122,26],"broken":false},
		{"building":21,"level":0,"cell":[132,26],"broken":false},
		{"building":21,"level":1,"cell":[122,26],"broken":false},
		{"building":21,"level":1,"cell":[132,26],"broken":false},
		{"building":22,"level":0,"cell":[153,28],"broken":false},
		{"building":22,"level":0,"cell":[159,28],"broken":false},
		{"building":22,"level":1,"cell":[153,28],"broken":false},
		{"building":22,"level":1,"cell":[159,28],"broken":false}
	],
	"stairs": [
		{"cell":[93,2],"low":-1,"high":0,"ladder":false},
		{"cell":[93,2],"low":0,"high":1,"ladder":false},
		{"cell":[29,6],"low":0,"high":1,"ladder":false},
		{"cell":[5,6],"low":0,"high":1,"ladder":false},
		{"cell":[5,6],"low":1,"high":2,"ladder":false},
		{"cell":[117,27],"low":0,"high":1,"ladder":false},
		{"cell":[151,29],"low":0,"high":1,"ladder":false}
	],
	"props": [
		{"kind":"water","rect":[24,21,38,3],"solid":"low","facing":0,"note":"눈과 얼음으로 덮인 물","level":0},
		{"kind":"water","rect":[68,21,30,3],"solid":"low","facing":0,"note":"눈과 얼음으로 덮인 물","level":0},
		{"kind":"water","rect":[102,21,14,3],"solid":"low","facing":0,"note":"눈과 얼음으로 덮인 물","level":0},
		{"kind":"reed_bundle","rect":[72,40,2,2],"solid":"low","facing":0,"note":"물가에서 묶은 갈대","level":0},
		{"kind":"plank_fence","rect":[28,36,6,1],"solid":"low","facing":0,"note":"비껴 받친 낮은 판자 울타리","level":0},
		{"kind":"bench","rect":[52,30,3,1],"solid":"low","facing":0,"note":"쉬어 가던 긴 의자","level":0},
		{"kind":"farm_cart","rect":[104,26,2,4],"solid":"low","facing":0,"note":"운반하다 세워 둔 짐수레","level":0},
		{"kind":"reed_bundle","rect":[45,16,2,2],"solid":"low","facing":0,"note":"물가에서 묶은 갈대","level":0},
		{"kind":"reed_bundle","rect":[48,19,2,2],"solid":"low","facing":0,"note":"물가에서 묶은 갈대","level":0},
		{"kind":"lamp_shelf","rect":[42,19,2,1],"solid":"low","facing":0,"note":"꺼진 등잔 선반","level":0},
		{"kind":"bench","rect":[37,18,3,1],"solid":"low","facing":0,"note":"쉬어 가던 긴 의자","level":0},
		{"kind":"firewood_pile","rect":[39,15,2,1],"solid":"low","facing":0,"note":"처마 밑 마른 장작","level":0},
		{"kind":"handcart","rect":[118,14,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"crate_stack","rect":[121,13,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"sack_pile","rect":[126,13,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"barrel","rect":[130,15,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"fieldstone_wall","rect":[116,24,1,2],"solid":"low","facing":0,"note":"글씨 없는 들돌 담 토막","level":0},
		{"kind":"bare_tree","rect":[137,2,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[143,5,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[153,3,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[160,9,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[2,17,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[9,20,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[16,18,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[20,22,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[164,27,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[171,30,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[167,38,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[176,42,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"sack_pile","rect":[93,10,2,2],"solid":"none","facing":0,"note":"물자를 담은 자루","level":-1},
		{"kind":"shelf","rect":[94,2,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":-1},
		{"kind":"barrel","rect":[103,11,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":-1},
		{"kind":"sack_pile","rect":[105,2,2,2],"solid":"none","facing":0,"note":"물자를 담은 자루","level":-1},
		{"kind":"shelf","rect":[105,11,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":-1},
		{"kind":"barrel","rect":[114,2,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":-1},
		{"kind":"shelf","rect":[93,3,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[97,2,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[97,4,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"handcart","rect":[93,11,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"crate_stack","rect":[93,9,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"sack_pile","rect":[97,9,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[100,4,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[100,2,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[104,2,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"shelf","rect":[100,11,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[100,9,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[107,2,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"shelf","rect":[108,4,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"shelf","rect":[107,9,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[113,9,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[108,11,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"desk","rect":[93,11,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":1},
		{"kind":"shelf","rect":[93,3,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"shelf","rect":[105,2,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"barrel","rect":[114,11,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":1},
		{"kind":"crate_stack","rect":[105,10,2,2],"solid":"none","facing":0,"note":"종류별 물자를 담은 나무 상자","level":1},
		{"kind":"cold_stove","rect":[29,11,1,1],"solid":"low","facing":0,"note":"작게 식은 난로","level":0},
		{"kind":"shelf","rect":[29,10,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"barrel","rect":[36,11,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"sack_pile","rect":[38,6,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[38,11,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"bed","rect":[29,11,2,1],"solid":"none","facing":0,"note":"숙직하는 이의 침대","level":1},
		{"kind":"desk","rect":[29,10,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":1},
		{"kind":"bed","rect":[38,11,2,1],"solid":"none","facing":0,"note":"숙직하는 이의 침대","level":1},
		{"kind":"shelf","rect":[39,6,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"sack_pile","rect":[6,6,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"barrel","rect":[5,9,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"shelf","rect":[6,9,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"sack_pile","rect":[5,11,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"barrel","rect":[9,13,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"shelf","rect":[7,11,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"desk","rect":[5,13,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":1},
		{"kind":"shelf","rect":[5,7,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"shelf","rect":[10,6,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"barrel","rect":[12,13,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":1},
		{"kind":"crate_stack","rect":[10,7,2,2],"solid":"none","facing":0,"note":"종류별 물자를 담은 나무 상자","level":1},
		{"kind":"desk","rect":[5,13,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":2},
		{"kind":"shelf","rect":[5,12,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":2},
		{"kind":"shelf","rect":[10,6,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":2},
		{"kind":"barrel","rect":[12,13,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":2},
		{"kind":"crate_stack","rect":[10,7,2,2],"solid":"none","facing":0,"note":"종류별 물자를 담은 나무 상자","level":2},
		{"kind":"shelf","rect":[55,16,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[55,18,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[59,16,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"sack_pile","rect":[71,4,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"handcart","rect":[78,10,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"barrel","rect":[79,4,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"sack_pile","rect":[81,4,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"handcart","rect":[87,10,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"barrel","rect":[88,4,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"shelf","rect":[121,4,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[121,5,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[125,9,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"shelf","rect":[128,9,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[128,4,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[131,9,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"cold_stove","rect":[126,36,1,1],"solid":"low","facing":0,"note":"작게 식은 난로","level":0},
		{"kind":"shelf","rect":[117,36,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"barrel","rect":[125,27,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"sack_pile","rect":[135,27,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[128,36,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"bed","rect":[118,27,2,1],"solid":"none","facing":0,"note":"숙직하는 이의 침대","level":1},
		{"kind":"desk","rect":[125,27,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":1},
		{"kind":"bed","rect":[128,36,2,1],"solid":"none","facing":0,"note":"숙직하는 이의 침대","level":1},
		{"kind":"shelf","rect":[129,27,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"cold_stove","rect":[151,36,1,1],"solid":"low","facing":0,"note":"작게 식은 난로","level":0},
		{"kind":"shelf","rect":[152,29,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"barrel","rect":[155,36,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"sack_pile","rect":[157,29,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[157,36,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"bed","rect":[151,36,2,1],"solid":"none","facing":0,"note":"숙직하는 이의 침대","level":1},
		{"kind":"desk","rect":[151,35,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":1},
		{"kind":"bed","rect":[157,36,2,1],"solid":"none","facing":0,"note":"숙직하는 이의 침대","level":1},
		{"kind":"shelf","rect":[158,29,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1}
	],
	"rooms": [
		{"building":15,"level":-1,"rect":[93,2,11,10],"name":"종자 창고 지하 앞방","theme":"seed"},
		{"building":15,"level":-1,"rect":[105,2,10,10],"name":"종자 창고 지하 뒷방","theme":"seed"},
		{"building":15,"level":0,"rect":[93,2,6,3],"name":"종자 창고 계량방","theme":"seed"},
		{"building":15,"level":0,"rect":[93,9,6,3],"name":"종자 창고 하역방","theme":"seed"},
		{"building":15,"level":0,"rect":[100,2,6,3],"name":"종자 창고 작업방","theme":"seed"},
		{"building":15,"level":0,"rect":[100,9,6,3],"name":"종자 창고 재료방","theme":"seed"},
		{"building":15,"level":0,"rect":[107,2,8,3],"name":"종자 창고 사무방","theme":"seed"},
		{"building":15,"level":0,"rect":[107,9,8,3],"name":"종자 창고 안쪽 저장방","theme":"seed"},
		{"building":15,"level":1,"rect":[93,2,11,10],"name":"종자 창고 위층 앞방","theme":"seed"},
		{"building":15,"level":1,"rect":[105,2,10,10],"name":"종자 창고 위층 뒷방","theme":"seed"},
		{"building":16,"level":0,"rect":[29,6,8,6],"name":"간척 농가 앞방","theme":"house"},
		{"building":16,"level":0,"rect":[38,6,7,6],"name":"간척 농가 뒷방","theme":"house"},
		{"building":16,"level":1,"rect":[29,6,8,6],"name":"간척 농가 위층 앞방","theme":"house"},
		{"building":16,"level":1,"rect":[38,6,7,6],"name":"간척 농가 위층 뒷방","theme":"house"},
		{"building":17,"level":0,"rect":[5,6,5,4],"name":"사일로 앞 작업방","theme":"grain"},
		{"building":17,"level":0,"rect":[5,11,5,3],"name":"사일로 안쪽 보관방","theme":"grain"},
		{"building":17,"level":1,"rect":[5,6,4,8],"name":"사일로 위층 앞방","theme":"grain"},
		{"building":17,"level":1,"rect":[10,6,3,8],"name":"사일로 위층 뒷방","theme":"grain"},
		{"building":17,"level":2,"rect":[5,6,4,8],"name":"사일로 다락 앞방","theme":"grain"},
		{"building":17,"level":2,"rect":[10,6,3,8],"name":"사일로 다락 뒷방","theme":"grain"},
		{"building":18,"level":0,"rect":[55,16,6,4],"name":"배수 펌프 오두막 작업방","theme":"tools"},
		{"building":19,"level":0,"rect":[71,4,9,7],"name":"건초 헛간 앞방","theme":"hay"},
		{"building":19,"level":0,"rect":[81,4,8,7],"name":"건초 헛간 뒷방","theme":"hay"},
		{"building":20,"level":0,"rect":[121,4,6,6],"name":"농기구 헛간 앞방","theme":"tools"},
		{"building":20,"level":0,"rect":[128,4,5,6],"name":"농기구 헛간 뒷방","theme":"tools"},
		{"building":21,"level":0,"rect":[117,27,10,10],"name":"둑 마을 농가 앞방","theme":"house"},
		{"building":21,"level":0,"rect":[128,27,9,10],"name":"둑 마을 농가 뒷방","theme":"house"},
		{"building":21,"level":1,"rect":[117,27,10,10],"name":"둑 마을 농가 위층 앞방","theme":"house"},
		{"building":21,"level":1,"rect":[128,27,9,10],"name":"둑 마을 농가 위층 뒷방","theme":"house"},
		{"building":22,"level":0,"rect":[151,29,5,8],"name":"둑지기 집 앞방","theme":"house"},
		{"building":22,"level":0,"rect":[157,29,4,8],"name":"둑지기 집 뒷방","theme":"house"},
		{"building":22,"level":1,"rect":[151,29,5,8],"name":"둑지기 집 위층 앞방","theme":"house"},
		{"building":22,"level":1,"rect":[157,29,4,8],"name":"둑지기 집 위층 뒷방","theme":"house"}
	],
	"containers": [
		{"id":"north_box_006","name":"종자 창고 재료방 보관함","cell":[105,11],"building":15,"search":6,"items":["needle_thread","food_pack"],"locked":false,"level":0,"searched":false},
		{"id":"north_box_015","name":"사일로 앞 작업방 보관함","cell":[9,6],"building":17,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"north_box_016","name":"사일로 안쪽 보관방 보관함","cell":[5,13],"building":17,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"north_box_017","name":"사일로 위층 앞방 보관함","cell":[8,6],"building":17,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"north_box_018","name":"사일로 위층 뒷방 보관함","cell":[10,13],"building":17,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"north_box_019","name":"사일로 다락 앞방 보관함","cell":[8,6],"building":17,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"north_box_020","name":"사일로 막다른 물자 보관함","cell":[10,13],"building":17,"search":8,"items":["food_pack","needle_thread"],"locked":false,"level":2,"searched":false},
		{"id":"north_box_021","name":"배수 펌프 오두막 작업방 보관함","cell":[60,19],"building":18,"search":6,"items":["needle_thread","food_pack"],"locked":false,"level":0,"searched":false},
		{"id":"north_box_022","name":"건초 헛간 앞방 보관함","cell":[71,10],"building":19,"search":6,"items":["needle_thread","food_pack"],"locked":false,"level":0,"searched":false},
		{"id":"north_shallow","name":"운반 도중 내려둔 물자 보관함","cell":[73,38],"building":-1,"search":2,"items":["needle_thread"],"locked":false,"level":0,"searched":false}
	],
	"entries": [
		{"id":"북쪽 간척 둑길","cells":[[63,0],[64,0],[65,0],[66,0]],"gap":0.6},
		{"id":"서쪽 샛둑","cells":[[0,1],[0,2],[0,3]],"gap":0.6},
		{"id":"동쪽 둑마을 길","cells":[[179,17],[179,18],[179,19]],"gap":0.6}
	],
	"holes": [

	],
	"slots": [
		[63,24],
		[66,25],
		[99,24],
		[100,25],
		[116,40],
		[117,42],
		[34,44],
		[34,50],
		[50,44],
		[50,50],
		[66,44],
		[66,50]
	],
	"crossings": [
		32,
		64
	],
	"deep": "H",
	"salvage": [

	]
}

static func _build_plain() -> Dictionary:
	var g := FieldGrid.new(WIDTH, SOUTH_HEIGHT)
	var cellar := FieldGrid.new(WIDTH, SOUTH_HEIGHT)
	cellar.solid.fill(S.BLOCK)
	cellar.opq.fill(1)
	var first := FieldGrid.new(WIDTH, SOUTH_HEIGHT)
	var second := FieldGrid.new(WIDTH, SOUTH_HEIGHT)
	first.solid.fill(S.AIR)
	second.solid.fill(S.AIR)
	var data: Dictionary = {
		"grid": g, "levels": {-1: cellar, 0: g, 1: first, 2: second},
		"stairs": [], "containers": {}, "spots": {}, "stoves": [],
		"entries": {}, "entry_gap": {}, "entry_levels": {},
		"buildings": [], "wagons": [], "train": Rect2i(16, 1, 80, 3),
		"platform": Rect2i(16, 4, 82, 6), "unload": Rect2i(16, 4, 82, 3),
		"train_cars": [], "spawns": {}, "labels": [], "trees": [],
		"low_blocks": [], "upper_rects": [], "lights": [],
		"manholes": {}, "manhole_levels": {}, "sewer_names": {},
		"anchors": {"horde_home": Vector2i(50, 10), "whistle": Vector2i(90, 4),
			"flee_exit": Vector2i(WIDTH - 1, SOUTH_HEIGHT - 1), "engine": Vector2i(92, 2)},
		"zone_names": PLAN["names"].duplicate(),
		"place_id": PLACE_ID, "place_kind": "church",
		"bands": {"lower": Rect2i(-4, 4, 120, 26).intersection(Rect2i(0, 0, WIDTH, SOUTH_HEIGHT))},
		"train_doors": {"lower": [Vector2i(34, 4), Vector2i(50, 4), Vector2i(66, 4)]},
		"crossings": [], "barricade_slots": [], "interior_kind_slots": [],
		"props": [], "hole_faces": {},
	}
	g.zone.fill("A")
	for row: Dictionary in PLAN["zones"]:
		for c: Vector2i in _cells(_rect(row["rect"])):
			g.zone[g.index(c)] = row["id"]
	for row: Dictionary in PLAN["ground"]:
		_fill_floor(g, _rect(row["rect"]), F[row["kind"]])
	_fill_floor(g, Rect2i(0, 1, WIDTH, 3), F.RAIL)
	_fill_solid(g, data["train"], S.BLOCK)
	_fill_floor(g, data["platform"], F.PLATFORM)
	for row: Dictionary in PLAN["buildings"]:
		data["buildings"].append({"id": row["id"], "name": row["name"],
			"rect": _rect(row["rect"]), "warm": row["warm"], "window_broken": row["window_broken"]})
		data["labels"].append({"text": row["name"], "cell": _rect(row["rect"]).position})
	for row: Dictionary in PLAN["shells"]:
		var level: int = row["level"]
		var r: Rect2i = _rect(row["rect"])
		_shell(data["levels"][level], row["building"], r, level)
		if level > 0:
			data["upper_rects"].append({"building": row["building"], "rect": r})
	for row: Dictionary in PLAN["walls"]:
		_fill_solid(data["levels"][row["level"]], _rect(row["rect"]), S.WALL)
	for row: Dictionary in PLAN["windows"]:
		var lg: FieldGrid = data["levels"][row["level"]]
		var c: Vector2i = _cell(row["cell"])
		lg.set_solid(c, S.WINDOW)
		lg.windows[c] = {"broken": row["broken"], "glass": false, "building": row["building"], "cell": c}
	for row: Dictionary in PLAN["doors"]:
		var lg: FieldGrid = data["levels"][row["level"]]
		var c: Vector2i = _cell(row["cell"])
		lg.set_solid(c, S.DOOR)
		lg.doors[c] = {"state": row["state"], "hp": 8, "building": row["building"], "cell": c}
	for row: Dictionary in PLAN.get("finishes", []):
		_fill_floor(data["levels"][row["level"]], _rect(row["rect"]), F[row["kind"]])
	for row: Dictionary in PLAN["props"]:
		var r: Rect2i = _rect(row["rect"])
		var level: int = row["level"]
		data["props"].append({"kind": row["kind"], "rect": r, "solid": row["solid"],
			"facing": row["facing"], "note": row["note"], "level": level})
		if level != 0:
			continue
		match row["solid"]:
			"low":
				_fill_solid(g, r, S.LOW)
				if row["kind"] == "water":
					_fill_floor(g, r, F.ICE)
				else:
					data["low_blocks"].append(r)
			"wall":
				_fill_solid(g, r, S.WALL)
			"tree":
				for c: Vector2i in _cells(r):
					g.set_solid(c, S.BLOCK)
					data["trees"].append(c)
	for row: Dictionary in PLAN["stairs"]:
		data["stairs"].append({"cell": _cell(row["cell"]), "low": row["low"],
			"high": row["high"], "ladder": row["ladder"]})
	for row: Dictionary in PLAN["containers"]:
		var box: Dictionary = row.duplicate(true)
		box["cell"] = _cell(row["cell"])
		data["containers"][row["id"]] = box
	for row: Dictionary in PLAN["entries"]:
		var cc: Array = []
		for c: Array in row["cells"]:
			cc.append(_cell(c))
		data["entries"][row["id"]] = cc
		data["entry_gap"][row["id"]] = float(row["gap"])
	for row: Dictionary in PLAN["holes"]:
		var c: Vector2i = _cell(row["cell"])
		data["manholes"][row["id"]] = c
		data["entries"][row["id"]] = [c]
		data["entry_gap"][row["id"]] = float(row["gap"])
		data["sewer_names"][row["id"]] = row["name"]
		data["labels"].append({"text": "맨홀", "cell": c + Vector2i(0, -1)})
		if int(row["level"]) != 0:
			data["manhole_levels"][row["id"]] = row["level"]
			data["entry_levels"][row["id"]] = row["level"]
	for c: Array in PLAN["slots"]:
		data["barricade_slots"].append(_cell(c))
	for z: String in PLAN["deep"]:
		data["interior_kind_slots"].append({"zone": z, "kinds": ["empty", "raiders", "nest", "beasts"]})
	var dead: Array = []
	for c: Array in PLAN["dead"]:
		dead.append(_cell(c))
	data["spawns"] = {"squad": [Vector2i(50, 6), Vector2i(48, 7), Vector2i(52, 7), Vector2i(50, 8)],
		"train_door": data["train_doors"]["lower"].duplicate(),
		"dead_street": dead, "dead_levels": []}
	data["spots"]["work_site"] = {"kind": "work_site", "name": "수거 작업 구역",
		"cell": _cell(PLAN["work"]["cell"]), "zone_rect": _rect(PLAN["work"]["rect"]), "state": "closed"}
	for row: Dictionary in PLAN.get("salvage", []):
		data["spots"][row["id"]] = {"kind": "salvage", "name": row["name"],
			"cell": _cell(row["cell"]), "material": row["material"], "amount": row["amount"], "state": "intact"}
	_train_lights(data)
	for level: int in data["levels"]:
		var lg: FieldGrid = data["levels"][level]
		if level != 0:
			lg.zone = g.zone.duplicate()
		lg.refresh_paths()
	# 여기까지는 옛 좌표(열차가 맨 위 y 1~3), 아래부터는 새 좌표(열차 y 46~48)
	data = MapShift.shift_rows(data, 45)
	assert(data["train"] == Rect2i(16, 46, 80, 3))
	assert(data["grid"].height == HEIGHT)
	_add_north(data)
	return data


static func _cell(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


static func _rect(a: Array) -> Rect2i:
	return Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))


static func _cells(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2i(x, y))
	return out


static func _fill_floor(g: FieldGrid, r: Rect2i, kind: int) -> void:
	for c: Vector2i in _cells(r):
		g.floor[g.index(c)] = kind


static func _fill_solid(g: FieldGrid, r: Rect2i, kind: int) -> void:
	for c: Vector2i in _cells(r):
		g.set_solid(c, kind)


static func _shell(g: FieldGrid, id: int, r: Rect2i, level: int) -> void:
	for c: Vector2i in _cells(r):
		g.building[g.index(c)] = id
		g.floor[g.index(c)] = F.GRAVEL if level < 0 else F.WOOD
		var edge: bool = c.x == r.position.x or c.x == r.end.x - 1 or c.y == r.position.y or c.y == r.end.y - 1
		g.set_solid(c, S.WALL if edge else S.NONE)


static func _train_lights(d: Dictionary) -> void:
	for k in range(5):
		var r := Rect2i(16 + k * 16, 1, 16, 3)
		d["train_cars"].append({"rect": r, "kind": "engine" if k == 4 else "car"})
		if k == 4:
			d["lights"].append({"id": "firebox", "kind": "firebox", "cell": Vector2i(r.position.x + 2, 3),
				"side": Vector2i(0, 1), "strength": 0.8, "falls": 0.8, "reach": 4.0, "when": "always", "from_min": 0})
		else:
			for w in range(4):
				d["lights"].append({"id": "car%d_window%d" % [k, w], "kind": "car_window",
					"cell": Vector2i(r.position.x + 3 + w * 3, 3), "side": Vector2i(0, 1),
					"strength": 1.0, "falls": 0.6, "reach": 3.0, "when": "dusk", "from_min": 890})


static func _add_north(data: Dictionary) -> void:
	# 위쪽의 땅은 새 좌표로만 짓는다. 남쪽 격자를 다시 사용하지 않는다.
	var g: FieldGrid = data["grid"]
	# 이동 함수가 옮긴 사전의 좌표 키에 내부 자리표도 맞춘다.
	for level: int in data["levels"]:
		var lg: FieldGrid = data["levels"][level]
		for c: Vector2i in lg.doors:
			lg.doors[c] = lg.doors[c].duplicate(true)
			lg.doors[c]["cell"] = c
		for c: Vector2i in lg.windows:
			lg.windows[c] = lg.windows[c].duplicate(true)
			lg.windows[c]["cell"] = c
	data["zone_names"].merge(NORTH["names"])
	for row: Dictionary in NORTH["zones"]:
		for c: Vector2i in _cells(_rect(row["rect"])):
			g.zone[g.index(c)] = row["id"]
	for row: Dictionary in NORTH["ground"]:
		_fill_floor(g, _rect(row["rect"]), F[row["kind"]])
	for row: Dictionary in NORTH["buildings"]:
		data["buildings"].append({"id": row["id"], "name": row["name"], "rect": _rect(row["rect"]), "warm": row["warm"], "window_broken": row["window_broken"]})
		data["labels"].append({"text": row["name"], "cell": _rect(row["rect"]).position})
	for row: Dictionary in NORTH["shells"]:
		_shell(data["levels"][row["level"]], row["building"], _rect(row["rect"]), row["level"])
		if int(row["level"]) > 0:
			data["upper_rects"].append({"building": row["building"], "rect": _rect(row["rect"])})
	for row: Dictionary in NORTH["walls"]:
		_fill_solid(data["levels"][row["level"]], _rect(row["rect"]), S.WALL)
	for row: Dictionary in NORTH["windows"]:
		var lg: FieldGrid = data["levels"][row["level"]]
		var c: Vector2i = _cell(row["cell"])
		lg.set_solid(c, S.WINDOW)
		lg.windows[c] = {"broken": row["broken"], "glass": false, "building": row["building"], "cell": c}
	for row: Dictionary in NORTH["doors"]:
		var lg: FieldGrid = data["levels"][row["level"]]
		var c: Vector2i = _cell(row["cell"])
		lg.set_solid(c, S.DOOR)
		lg.doors[c] = {"state": row["state"], "hp": 8, "building": row["building"], "cell": c}
	for row: Dictionary in NORTH["props"]:
		var r: Rect2i = _rect(row["rect"])
		var level: int = int(row["level"])
		data["props"].append({"kind": row["kind"], "rect": r, "solid": row["solid"], "facing": row["facing"], "note": row["note"], "level": level})
		if level != 0:
			continue
		match row["solid"]:
			"low":
				_fill_solid(g, r, S.LOW)
				if row["kind"] == "water":
					_fill_floor(g, r, F.ICE)
				else:
					data["low_blocks"].append(r)
			"wall":
				_fill_solid(g, r, S.WALL)
			"tree":
				for c: Vector2i in _cells(r):
					g.set_solid(c, S.BLOCK)
					data["trees"].append(c)
			"wagon":
				_fill_solid(g, r, S.BLOCK)
				data["wagons"].append({"rect": r, "coal": 1.0})
	for row: Dictionary in NORTH["stairs"]:
		data["stairs"].append({"cell": _cell(row["cell"]), "low": row["low"], "high": row["high"], "ladder": row["ladder"]})
	for row: Dictionary in NORTH["containers"]:
		var box: Dictionary = row.duplicate(true)
		box["cell"] = _cell(row["cell"])
		data["containers"][row["id"]] = box
	for row: Dictionary in NORTH["entries"]:
		var cc: Array = []
		for c: Array in row["cells"]:
			cc.append(_cell(c))
		data["entries"][row["id"]] = cc
		data["entry_gap"][row["id"]] = float(row["gap"])
	for row: Dictionary in NORTH["holes"]:
		var c: Vector2i = _cell(row["cell"])
		data["manholes"][row["id"]] = c
		data["entries"][row["id"]] = [c]
		data["entry_gap"][row["id"]] = float(row["gap"])
		data["sewer_names"][row["id"]] = row["name"]
	for c: Array in NORTH["slots"]:
		data["barricade_slots"].append(_cell(c))
	data["interior_kind_slots"].append({"zone": NORTH["deep"], "kinds": ["empty", "raiders", "nest", "beasts"]})
	data["bands"]["upper"] = Rect2i(-4, 24, 120, 22).intersection(Rect2i(0, 0, WIDTH, HEIGHT))
	data["train_doors"]["upper"] = []
	for c: Vector2i in data["train_doors"]["lower"]:
		data["train_doors"]["upper"].append(Vector2i(c.x, 45))
	for x: int in NORTH["crossings"]:
		data["crossings"].append({"cells": [Vector2i(x, 46), Vector2i(x, 47), Vector2i(x, 48)], "who": {"person": true, "zombie": false, "carrying": true, "wounded": false, "sled": false}})
	for row: Dictionary in NORTH["salvage"]:
		data["spots"][row["id"]] = {"kind": "salvage", "name": row["name"], "cell": _cell(row["cell"]), "material": row["material"], "amount": row["amount"], "state": "intact"}
	for level: int in data["levels"]:
		var lg: FieldGrid = data["levels"][level]
		if level != 0:
			lg.zone = g.zone.duplicate()
		lg.refresh_paths()


## 무전 문장에 쓰는 들어오는 길의 이름, 길마다의 비중, 첫 물결이 오는 길.
const ENTRY_NAMES: Dictionary = {"west_coast": "서쪽 물가", "east_coast": "동쪽 물가", "west_pass": "서쪽 고갯길", "manhole_01": "맨홀", "북쪽 간척 둑길": "북쪽 간척 둑길", "서쪽 샛둑": "서쪽 샛둑", "동쪽 둑마을 길": "동쪽 둑마을 길"}
const ENTRY_WEIGHTS: Dictionary = {"west_coast": 1.0, "east_coast": 1.0, "west_pass": 0.5, "manhole_01": 0.3, "북쪽 간척 둑길": 1.0, "서쪽 샛둑": 1.0, "동쪽 둑마을 길": 1.0}
const FIRST_ENTRY: String = "west_coast"


static func build() -> Dictionary:
	var data: Dictionary = _build_plain()
	data["entry_names"] = ENTRY_NAMES.duplicate()
	data["entry_weights"] = ENTRY_WEIGHTS.duplicate()
	data["first_entry"] = FIRST_ENTRY
	return data
