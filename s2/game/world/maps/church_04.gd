# 이 지도가 다른 판단을 만드는 것: 더미를 넘으면 빠르나 시끄럽고 돌면 조용하나 길다. 종이 없어 무리를 못 끈다.
# 위쪽의 판단: 석탄을 산더미로 얻는 대신 무거워 여럿이 여러 번 날라야 하고, 석탄 쏟는 소리가 야적장 구멍을 깨운다.
extends RefCounted

const FieldGrid = preload("res://game/world/field_grid.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const PLACE_ID: String = "church_04"
const WIDTH: int = 160
const SOUTH_HEIGHT: int = 95
const HEIGHT: int = SOUTH_HEIGHT + 45

# 각 방과 마당의 좌표는 이 지도에서만 쓰는 독립 평면이다.
# 종소리와 덧댄 문 해체는 자리만 남기며 여기서 실행하지 않는다.
const PLAN: Dictionary = {
	"id": "church_04",
	"size": [
		160,
		95
	],
	"names": {"A":"수리 마당","B":"교회","C":"교구 회관 마당","D":"잡화점 거리","E":"서쪽 주택 거리","F":"묘지"},
	"zones": [
		{"id":"A","rect":[0,0,160,95]},
		{"id":"D","rect":[0,42,62,28]},
		{"id":"B","rect":[60,50,64,30]},
		{"id":"C","rect":[124,49,36,33]},
		{"id":"E","rect":[0,70,60,25]},
		{"id":"F","rect":[40,78,120,17]}
	],
	"ground": [
		{"rect":[0,10,30,20],"kind":"DEEP_SNOW"},
		{"rect":[116,10,44,28],"kind":"DEEP_SNOW"},
		{"rect":[56,30,40,12],"kind":"GRAVEL"},
		{"rect":[40,78,110,17],"kind":"SNOW"},
		{"rect":[0,67,40,28],"kind":"DEEP_SNOW"},
		{"rect":[58,10,5,36],"kind":"ROAD"},
		{"rect":[0,44,156,6],"kind":"ROAD"},
		{"rect":[150,44,6,51],"kind":"ROAD"},
		{"rect":[0,79,45,5],"kind":"ROAD"},
		{"rect":[154,37,6,7],"kind":"ROAD"},
		{"rect":[112,37,48,5],"kind":"ROAD"},
		{"rect":[32,49,5,43],"kind":"ROAD"},
		{"rect":[56,50,5,45],"kind":"ROAD"},
		{"rect":[122,50,4,45],"kind":"ROAD"}
	],
	"buildings": [
		{"id":0,"name":"교회 본당","rect":[62,52,50,26],"warm":true,"window_broken":false},
		{"id":1,"name":"종탑","rect":[113,52,10,10],"warm":false,"window_broken":false},
		{"id":2,"name":"교구 회관","rect":[126,55,22,20],"warm":false,"window_broken":false},
		{"id":3,"name":"잡화점","rect":[12,54,16,12],"warm":false,"window_broken":false},
		{"id":4,"name":"비어 있는 사제관","rect":[40,54,16,12],"warm":false,"window_broken":false},
		{"id":5,"name":"수리 작업장","rect":[38,18,16,10],"warm":false,"window_broken":false},
		{"id":6,"name":"자재 창고","rect":[66,18,20,10],"warm":false,"window_broken":false},
		{"id":7,"name":"농가 가","rect":[96,17,14,12],"warm":false,"window_broken":false},
		{"id":8,"name":"농가 나","rect":[12,30,14,12],"warm":false,"window_broken":false},
		{"id":9,"name":"주택 가","rect":[12,68,14,10],"warm":false,"window_broken":false},
		{"id":10,"name":"주택 나","rect":[5,83,14,10],"warm":false,"window_broken":false},
		{"id":11,"name":"마구간","rect":[130,78,14,10],"warm":false,"window_broken":false},
		{"id":12,"name":"장작 헛간","rect":[30,84,12,8],"warm":false,"window_broken":false},
		{"id":13,"name":"묘지 관리 창고","rect":[46,83,8,6],"warm":false,"window_broken":false},
		{"id":14,"name":"우물집","rect":[28,35,6,6],"warm":false,"window_broken":false}
	],
	"shells": [
		{"building":0,"level":0,"rect":[62,52,50,26]},
		{"building":0,"level":1,"rect":[62,52,8,26]},
		{"building":0,"level":-1,"rect":[88,52,24,26]},
		{"building":1,"level":0,"rect":[113,52,10,10]},
		{"building":1,"level":1,"rect":[113,52,10,10]},
		{"building":1,"level":2,"rect":[113,52,10,10]},
		{"building":2,"level":0,"rect":[126,55,22,20]},
		{"building":2,"level":1,"rect":[126,55,22,20]},
		{"building":2,"level":2,"rect":[126,55,22,20]},
		{"building":2,"level":-1,"rect":[126,55,22,20]},
		{"building":3,"level":0,"rect":[12,54,16,12]},
		{"building":4,"level":0,"rect":[40,54,16,12]},
		{"building":4,"level":1,"rect":[40,54,16,12]},
		{"building":5,"level":0,"rect":[38,18,16,10]},
		{"building":6,"level":0,"rect":[66,18,20,10]},
		{"building":7,"level":0,"rect":[96,17,14,12]},
		{"building":7,"level":1,"rect":[96,17,14,12]},
		{"building":8,"level":0,"rect":[12,30,14,12]},
		{"building":9,"level":0,"rect":[12,68,14,10]},
		{"building":9,"level":1,"rect":[12,68,14,10]},
		{"building":10,"level":0,"rect":[5,83,14,10]},
		{"building":11,"level":0,"rect":[130,78,14,10]},
		{"building":12,"level":0,"rect":[30,84,12,8]},
		{"building":13,"level":0,"rect":[46,83,8,6]},
		{"building":14,"level":0,"rect":[28,35,6,6]}
	],
	"walls": [
		{"level":0,"rect":[63,58,48,1]},
		{"level":0,"rect":[63,71,48,1]},
		{"level":0,"rect":[71,53,1,5]},
		{"level":0,"rect":[71,72,1,5]},
		{"level":0,"rect":[81,53,1,5]},
		{"level":0,"rect":[81,72,1,5]},
		{"level":0,"rect":[91,53,1,5]},
		{"level":0,"rect":[91,72,1,5]},
		{"level":0,"rect":[101,53,1,5]},
		{"level":0,"rect":[101,72,1,5]},
		{"level":1,"rect":[63,65,6,1]},
		{"level":-1,"rect":[91,55,18,1]},
		{"level":-1,"rect":[91,74,18,1]},
		{"level":-1,"rect":[91,55,1,20]},
		{"level":-1,"rect":[108,55,1,20]},
		{"level":-1,"rect":[100,56,1,18]},
		{"level":0,"rect":[117,53,1,8]},
		{"level":1,"rect":[117,53,1,8]},
		{"level":2,"rect":[117,53,1,8]},
		{"level":0,"rect":[127,63,20,1]},
		{"level":0,"rect":[127,66,20,1]},
		{"level":0,"rect":[136,56,1,7]},
		{"level":0,"rect":[136,67,1,7]},
		{"level":1,"rect":[127,63,20,1]},
		{"level":1,"rect":[127,66,20,1]},
		{"level":1,"rect":[136,56,1,7]},
		{"level":1,"rect":[136,67,1,7]},
		{"level":2,"rect":[127,63,20,1]},
		{"level":2,"rect":[127,66,20,1]},
		{"level":2,"rect":[136,56,1,7]},
		{"level":2,"rect":[136,67,1,7]},
		{"level":-1,"rect":[129,58,16,1]},
		{"level":-1,"rect":[129,71,16,1]},
		{"level":-1,"rect":[129,58,1,14]},
		{"level":-1,"rect":[144,58,1,14]},
		{"level":-1,"rect":[137,59,1,12]},
		{"level":0,"rect":[13,58,14,1]},
		{"level":0,"rect":[13,61,14,1]},
		{"level":0,"rect":[41,58,14,1]},
		{"level":0,"rect":[41,61,14,1]},
		{"level":1,"rect":[41,58,14,1]},
		{"level":1,"rect":[41,61,14,1]},
		{"level":0,"rect":[46,19,1,8]},
		{"level":0,"rect":[76,19,1,8]},
		{"level":0,"rect":[97,21,12,1]},
		{"level":0,"rect":[97,24,12,1]},
		{"level":1,"rect":[97,21,12,1]},
		{"level":1,"rect":[97,24,12,1]},
		{"level":0,"rect":[13,34,12,1]},
		{"level":0,"rect":[13,37,12,1]},
		{"level":0,"rect":[19,69,1,8]},
		{"level":1,"rect":[19,69,1,8]},
		{"level":0,"rect":[12,84,1,8]},
		{"level":0,"rect":[137,79,1,8]}
	],
	"doors": [
		{"building":0,"level":0,"cell":[67,58],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[67,71],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[76,58],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[76,71],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[86,58],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[86,71],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[96,58],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[96,71],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[106,58],"side":[0,1],"state":"closed","outer":false},
		{"building":0,"level":0,"cell":[106,71],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[62,65],"side":[-1,0],"state":"open","outer":true},
		{"building":0,"level":0,"cell":[111,65],"side":[1,0],"state":"open","outer":true},
		{"building":0,"level":1,"cell":[65,65],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":-1,"cell":[91,65],"side":[-1,0],"state":"open","outer":false},
		{"building":0,"level":-1,"cell":[108,65],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":0,"cell":[117,59],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":1,"cell":[117,59],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":2,"cell":[117,59],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":0,"cell":[122,59],"side":[1,0],"state":"open","outer":true},
		{"building":2,"level":0,"cell":[131,63],"side":[0,1],"state":"open","outer":false},
		{"building":2,"level":0,"cell":[131,66],"side":[0,-1],"state":"open","outer":false},
		{"building":2,"level":0,"cell":[142,63],"side":[0,1],"state":"open","outer":false},
		{"building":2,"level":0,"cell":[142,66],"side":[0,-1],"state":"open","outer":false},
		{"building":2,"level":0,"cell":[126,64],"side":[-1,0],"state":"open","outer":true},
		{"building":2,"level":0,"cell":[147,64],"side":[1,0],"state":"open","outer":true},
		{"building":2,"level":1,"cell":[131,63],"side":[0,1],"state":"open","outer":false},
		{"building":2,"level":1,"cell":[131,66],"side":[0,-1],"state":"open","outer":false},
		{"building":2,"level":1,"cell":[142,63],"side":[0,1],"state":"open","outer":false},
		{"building":2,"level":1,"cell":[142,66],"side":[0,-1],"state":"open","outer":false},
		{"building":2,"level":2,"cell":[131,63],"side":[0,1],"state":"open","outer":false},
		{"building":2,"level":2,"cell":[131,66],"side":[0,-1],"state":"open","outer":false},
		{"building":2,"level":2,"cell":[142,63],"side":[0,1],"state":"open","outer":false},
		{"building":2,"level":2,"cell":[142,66],"side":[0,-1],"state":"open","outer":false},
		{"building":2,"level":-1,"cell":[129,65],"side":[-1,0],"state":"open","outer":false},
		{"building":2,"level":-1,"cell":[144,65],"side":[1,0],"state":"open","outer":false},
		{"building":3,"level":0,"cell":[20,58],"side":[0,1],"state":"open","outer":false},
		{"building":3,"level":0,"cell":[20,61],"side":[0,-1],"state":"open","outer":false},
		{"building":3,"level":0,"cell":[12,59],"side":[-1,0],"state":"open","outer":true},
		{"building":3,"level":0,"cell":[27,59],"side":[1,0],"state":"open","outer":true},
		{"building":4,"level":0,"cell":[48,58],"side":[0,1],"state":"open","outer":false},
		{"building":4,"level":0,"cell":[48,61],"side":[0,-1],"state":"open","outer":false},
		{"building":4,"level":0,"cell":[40,59],"side":[-1,0],"state":"open","outer":true},
		{"building":4,"level":0,"cell":[55,59],"side":[1,0],"state":"open","outer":true},
		{"building":4,"level":1,"cell":[48,58],"side":[0,1],"state":"open","outer":false},
		{"building":4,"level":1,"cell":[48,61],"side":[0,-1],"state":"open","outer":false},
		{"building":5,"level":0,"cell":[46,23],"side":[1,0],"state":"open","outer":false},
		{"building":5,"level":0,"cell":[38,23],"side":[-1,0],"state":"open","outer":true},
		{"building":5,"level":0,"cell":[53,23],"side":[1,0],"state":"open","outer":true},
		{"building":6,"level":0,"cell":[76,23],"side":[1,0],"state":"open","outer":false},
		{"building":6,"level":0,"cell":[66,23],"side":[-1,0],"state":"open","outer":true},
		{"building":6,"level":0,"cell":[85,23],"side":[1,0],"state":"open","outer":true},
		{"building":7,"level":0,"cell":[103,21],"side":[0,1],"state":"open","outer":false},
		{"building":7,"level":0,"cell":[103,24],"side":[0,-1],"state":"open","outer":false},
		{"building":7,"level":0,"cell":[96,22],"side":[-1,0],"state":"open","outer":true},
		{"building":7,"level":0,"cell":[109,22],"side":[1,0],"state":"open","outer":true},
		{"building":7,"level":1,"cell":[103,21],"side":[0,1],"state":"open","outer":false},
		{"building":7,"level":1,"cell":[103,24],"side":[0,-1],"state":"open","outer":false},
		{"building":8,"level":0,"cell":[19,34],"side":[0,1],"state":"open","outer":false},
		{"building":8,"level":0,"cell":[19,37],"side":[0,-1],"state":"open","outer":false},
		{"building":8,"level":0,"cell":[12,35],"side":[-1,0],"state":"open","outer":true},
		{"building":8,"level":0,"cell":[25,35],"side":[1,0],"state":"open","outer":true},
		{"building":9,"level":0,"cell":[19,73],"side":[1,0],"state":"open","outer":false},
		{"building":9,"level":0,"cell":[12,73],"side":[-1,0],"state":"open","outer":true},
		{"building":9,"level":0,"cell":[25,73],"side":[1,0],"state":"open","outer":true},
		{"building":9,"level":1,"cell":[19,73],"side":[1,0],"state":"open","outer":false},
		{"building":10,"level":0,"cell":[12,88],"side":[1,0],"state":"open","outer":false},
		{"building":10,"level":0,"cell":[5,88],"side":[-1,0],"state":"open","outer":true},
		{"building":10,"level":0,"cell":[18,88],"side":[1,0],"state":"open","outer":true},
		{"building":11,"level":0,"cell":[137,83],"side":[1,0],"state":"open","outer":false},
		{"building":11,"level":0,"cell":[130,83],"side":[-1,0],"state":"open","outer":true},
		{"building":11,"level":0,"cell":[143,83],"side":[1,0],"state":"open","outer":true},
		{"building":12,"level":0,"cell":[30,88],"side":[-1,0],"state":"open","outer":true},
		{"building":12,"level":0,"cell":[41,88],"side":[1,0],"state":"open","outer":true},
		{"building":13,"level":0,"cell":[46,86],"side":[-1,0],"state":"open","outer":true},
		{"building":14,"level":0,"cell":[28,38],"side":[-1,0],"state":"open","outer":true}
	],
	"windows": [
		{"building":0,"level":0,"cell":[75,52],"broken":false},
		{"building":0,"level":0,"cell":[75,77],"broken":false},
		{"building":0,"level":0,"cell":[97,52],"broken":false},
		{"building":0,"level":0,"cell":[97,77],"broken":false},
		{"building":0,"level":0,"cell":[62,54],"broken":false},
		{"building":0,"level":1,"cell":[64,52],"broken":false},
		{"building":0,"level":1,"cell":[64,77],"broken":false},
		{"building":0,"level":1,"cell":[67,52],"broken":false},
		{"building":0,"level":1,"cell":[67,77],"broken":false},
		{"building":0,"level":1,"cell":[62,54],"broken":false},
		{"building":1,"level":0,"cell":[116,52],"broken":false},
		{"building":1,"level":0,"cell":[116,61],"broken":false},
		{"building":1,"level":0,"cell":[119,52],"broken":false},
		{"building":1,"level":0,"cell":[119,61],"broken":false},
		{"building":1,"level":0,"cell":[113,54],"broken":false},
		{"building":1,"level":1,"cell":[116,52],"broken":false},
		{"building":1,"level":1,"cell":[116,61],"broken":false},
		{"building":1,"level":1,"cell":[119,52],"broken":false},
		{"building":1,"level":1,"cell":[119,61],"broken":false},
		{"building":1,"level":1,"cell":[113,54],"broken":false},
		{"building":1,"level":2,"cell":[116,52],"broken":false},
		{"building":1,"level":2,"cell":[116,61],"broken":false},
		{"building":1,"level":2,"cell":[119,52],"broken":false},
		{"building":1,"level":2,"cell":[119,61],"broken":false},
		{"building":1,"level":2,"cell":[113,54],"broken":false},
		{"building":2,"level":0,"cell":[132,55],"broken":false},
		{"building":2,"level":0,"cell":[132,74],"broken":false},
		{"building":2,"level":0,"cell":[141,55],"broken":false},
		{"building":2,"level":0,"cell":[141,74],"broken":false},
		{"building":2,"level":0,"cell":[126,57],"broken":false},
		{"building":2,"level":1,"cell":[132,55],"broken":false},
		{"building":2,"level":1,"cell":[132,74],"broken":false},
		{"building":2,"level":1,"cell":[141,55],"broken":false},
		{"building":2,"level":1,"cell":[141,74],"broken":false},
		{"building":2,"level":1,"cell":[126,57],"broken":false},
		{"building":2,"level":2,"cell":[132,55],"broken":false},
		{"building":2,"level":2,"cell":[132,74],"broken":false},
		{"building":2,"level":2,"cell":[141,55],"broken":false},
		{"building":2,"level":2,"cell":[141,74],"broken":false},
		{"building":2,"level":2,"cell":[126,57],"broken":false},
		{"building":3,"level":0,"cell":[16,54],"broken":false},
		{"building":3,"level":0,"cell":[16,65],"broken":false},
		{"building":3,"level":0,"cell":[23,54],"broken":false},
		{"building":3,"level":0,"cell":[23,65],"broken":false},
		{"building":3,"level":0,"cell":[12,56],"broken":false},
		{"building":4,"level":0,"cell":[44,54],"broken":false},
		{"building":4,"level":0,"cell":[44,65],"broken":false},
		{"building":4,"level":0,"cell":[51,54],"broken":false},
		{"building":4,"level":0,"cell":[51,65],"broken":false},
		{"building":4,"level":0,"cell":[40,56],"broken":false},
		{"building":4,"level":1,"cell":[44,54],"broken":false},
		{"building":4,"level":1,"cell":[44,65],"broken":false},
		{"building":4,"level":1,"cell":[51,54],"broken":false},
		{"building":4,"level":1,"cell":[51,65],"broken":false},
		{"building":4,"level":1,"cell":[40,56],"broken":false},
		{"building":5,"level":0,"cell":[42,18],"broken":false},
		{"building":5,"level":0,"cell":[42,27],"broken":false},
		{"building":5,"level":0,"cell":[49,18],"broken":false},
		{"building":5,"level":0,"cell":[49,27],"broken":false},
		{"building":5,"level":0,"cell":[38,20],"broken":false},
		{"building":6,"level":0,"cell":[71,18],"broken":false},
		{"building":6,"level":0,"cell":[71,27],"broken":false},
		{"building":6,"level":0,"cell":[79,18],"broken":false},
		{"building":6,"level":0,"cell":[79,27],"broken":false},
		{"building":6,"level":0,"cell":[66,20],"broken":false},
		{"building":7,"level":0,"cell":[100,17],"broken":false},
		{"building":7,"level":0,"cell":[100,28],"broken":false},
		{"building":7,"level":0,"cell":[105,17],"broken":false},
		{"building":7,"level":0,"cell":[105,28],"broken":false},
		{"building":7,"level":0,"cell":[96,19],"broken":false},
		{"building":7,"level":1,"cell":[100,17],"broken":false},
		{"building":7,"level":1,"cell":[100,28],"broken":false},
		{"building":7,"level":1,"cell":[105,17],"broken":false},
		{"building":7,"level":1,"cell":[105,28],"broken":false},
		{"building":7,"level":1,"cell":[96,19],"broken":false},
		{"building":8,"level":0,"cell":[16,30],"broken":false},
		{"building":8,"level":0,"cell":[16,41],"broken":false},
		{"building":8,"level":0,"cell":[21,30],"broken":false},
		{"building":8,"level":0,"cell":[21,41],"broken":false},
		{"building":8,"level":0,"cell":[12,32],"broken":false},
		{"building":9,"level":0,"cell":[16,68],"broken":false},
		{"building":9,"level":0,"cell":[16,77],"broken":false},
		{"building":9,"level":0,"cell":[21,68],"broken":false},
		{"building":9,"level":0,"cell":[21,77],"broken":false},
		{"building":9,"level":0,"cell":[12,70],"broken":false},
		{"building":9,"level":1,"cell":[16,68],"broken":false},
		{"building":9,"level":1,"cell":[16,77],"broken":false},
		{"building":9,"level":1,"cell":[21,68],"broken":false},
		{"building":9,"level":1,"cell":[21,77],"broken":false},
		{"building":9,"level":1,"cell":[12,70],"broken":false},
		{"building":10,"level":0,"cell":[9,83],"broken":false},
		{"building":10,"level":0,"cell":[9,92],"broken":false},
		{"building":10,"level":0,"cell":[14,83],"broken":false},
		{"building":10,"level":0,"cell":[14,92],"broken":false},
		{"building":10,"level":0,"cell":[5,85],"broken":false},
		{"building":11,"level":0,"cell":[134,78],"broken":false},
		{"building":11,"level":0,"cell":[134,87],"broken":false},
		{"building":11,"level":0,"cell":[139,78],"broken":false},
		{"building":11,"level":0,"cell":[139,87],"broken":false},
		{"building":11,"level":0,"cell":[130,80],"broken":false},
		{"building":12,"level":0,"cell":[33,84],"broken":false},
		{"building":12,"level":0,"cell":[33,91],"broken":false},
		{"building":12,"level":0,"cell":[38,84],"broken":false},
		{"building":12,"level":0,"cell":[38,91],"broken":false},
		{"building":12,"level":0,"cell":[30,86],"broken":false},
		{"building":13,"level":0,"cell":[48,83],"broken":false},
		{"building":13,"level":0,"cell":[48,88],"broken":false},
		{"building":13,"level":0,"cell":[51,83],"broken":false},
		{"building":13,"level":0,"cell":[51,88],"broken":false},
		{"building":13,"level":0,"cell":[46,85],"broken":false},
		{"building":14,"level":0,"cell":[30,35],"broken":false},
		{"building":14,"level":0,"cell":[30,40],"broken":false},
		{"building":14,"level":0,"cell":[31,35],"broken":false},
		{"building":14,"level":0,"cell":[31,40],"broken":false},
		{"building":14,"level":0,"cell":[28,37],"broken":false}
	],
	"stairs": [
		{"cell":[63,54],"low":0,"high":1,"ladder":false},
		{"cell":[89,54],"low":-1,"high":0,"ladder":false},
		{"cell":[110,75],"low":-1,"high":0,"ladder":false},
		{"cell":[114,53],"low":0,"high":1,"ladder":false},
		{"cell":[121,60],"low":1,"high":2,"ladder":false},
		{"cell":[128,64],"low":0,"high":1,"ladder":false},
		{"cell":[145,64],"low":1,"high":2,"ladder":false},
		{"cell":[127,57],"low":-1,"high":0,"ladder":false},
		{"cell":[146,72],"low":-1,"high":0,"ladder":false},
		{"cell":[42,59],"low":0,"high":1,"ladder":false},
		{"cell":[98,22],"low":0,"high":1,"ladder":false},
		{"cell":[14,72],"low":0,"high":1,"ladder":false}
	],
	"props": [
		{"kind":"bell_rope","rect":[115,55,1,1],"solid":"none","facing":0,"note":"종이 사라진 끊어진 줄","level":1},
		{"kind":"bell_frame","rect":[118,54,3,3],"solid":"none","facing":1,"note":"종이 없는 빈 나무 틀","level":2},
		{"kind":"car","rect":[31,11,4,2],"solid":"low","facing":2,"note":"길가에 선 차","level":0},
		{"kind":"bench","rect":[50,12,3,1],"solid":"low","facing":3,"note":"긴 의자","level":0},
		{"kind":"crate_stack","rect":[66,12,2,2],"solid":"low","facing":0,"note":"나무 상자","level":0},
		{"kind":"repair_lumber","rect":[86,24,4,2],"solid":"low","facing":1,"note":"수리할 목재","level":0},
		{"kind":"repair_scaffold","rect":[66,32,4,2],"solid":"low","facing":2,"note":"낮은 수리 발판","level":0},
		{"kind":"repair_scaffold","rect":[76,35,4,2],"solid":"low","facing":3,"note":"낮은 수리 발판","level":0},
		{"kind":"repair_lumber","rect":[70,30,4,2],"solid":"low","facing":0,"note":"수리할 목재","level":0},
		{"kind":"repair_lumber","rect":[87,33,4,2],"solid":"low","facing":1,"note":"수리할 목재","level":0},
		{"kind":"repair_lumber","rect":[89,38,4,2],"solid":"low","facing":2,"note":"수리할 목재","level":0},
		{"kind":"handcart","rect":[80,40,2,1],"solid":"low","facing":3,"note":"뒷문 곁 손수레","level":0},
		{"kind":"firewood_pile","rect":[64,39,2,1],"solid":"low","facing":0,"note":"처마 밑 장작","level":0},
		{"kind":"lamp_post","rect":[79,43,1,1],"solid":"none","facing":2,"note":"꺼진 등잔 기둥","level":0},
		{"kind":"crate_stack","rect":[85,50,2,2],"solid":"low","facing":3,"note":"나무 상자","level":0},
		{"kind":"snow_drift","rect":[78,50,4,2],"solid":"none","facing":0,"note":"모서리의 눈더미","level":0},
		{"kind":"car","rect":[143,45,4,2],"solid":"low","facing":1,"note":"길가에 선 차","level":0},
		{"kind":"bench","rect":[125,77,3,1],"solid":"low","facing":2,"note":"긴 의자","level":0},
		{"kind":"barrel","rect":[145,78,1,1],"solid":"low","facing":3,"note":"저장 통","level":0},
		{"kind":"grave_plot","rect":[64,82,4,3],"solid":"low","facing":0,"note":"눈 덮인 돌판의 낮은 돌 테두리","level":0},
		{"kind":"grave_plot","rect":[75,86,4,3],"solid":"low","facing":1,"note":"눈 덮인 돌판의 낮은 돌 테두리","level":0},
		{"kind":"grave_plot","rect":[88,81,4,3],"solid":"low","facing":2,"note":"눈 덮인 돌판의 낮은 돌 테두리","level":0},
		{"kind":"grave_plot","rect":[105,86,4,3],"solid":"low","facing":3,"note":"눈 덮인 돌판의 낮은 돌 테두리","level":0},
		{"kind":"grave_plot","rect":[116,81,4,3],"solid":"low","facing":0,"note":"눈 덮인 돌판의 낮은 돌 테두리","level":0},
		{"kind":"grave_slab","rect":[92,84,2,1],"solid":"none","facing":1,"note":"글씨와 무늬 없는 낮은 돌판","level":0},
		{"kind":"grave_slab","rect":[107,89,2,1],"solid":"none","facing":2,"note":"글씨와 무늬 없는 낮은 돌판","level":0},
		{"kind":"grave_slab","rect":[115,91,2,1],"solid":"none","facing":3,"note":"글씨와 무늬 없는 낮은 돌판","level":0},
		{"kind":"bare_tree","rect":[6,16,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[11,22,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[21,25,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[4,28,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[7,38,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[26,43,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[3,54,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[6,63,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[4,75,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[24,90,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[44,92,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[68,91,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[83,93,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[99,90,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[147,88,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[158,86,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[159,69,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[145,51,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[155,30,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[142,22,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[131,27,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[121,17,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[115,20,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[115,26,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[113,34,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[34,16,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[35,30,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[42,36,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[50,39,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[27,13,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"hymn_shelf","rect":[63,53,2,1],"solid":"low","facing":2,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[70,57,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[63,57,2,1],"solid":"low","facing":0,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[70,53,1,1],"solid":"low","facing":1,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[69,76,2,1],"solid":"low","facing":2,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[63,76,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[69,72,2,1],"solid":"low","facing":0,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[64,72,1,1],"solid":"low","facing":1,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[72,57,2,1],"solid":"low","facing":2,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[80,53,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[73,53,2,1],"solid":"low","facing":0,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[79,57,1,1],"solid":"low","facing":1,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[79,72,2,1],"solid":"low","facing":2,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[73,72,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[78,76,2,1],"solid":"low","facing":0,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[72,72,1,1],"solid":"low","facing":1,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[83,53,2,1],"solid":"low","facing":2,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[89,57,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[82,57,2,1],"solid":"low","facing":0,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[90,57,1,1],"solid":"low","facing":1,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[88,76,2,1],"solid":"low","facing":2,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[82,72,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[82,76,2,1],"solid":"low","facing":0,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[90,72,1,1],"solid":"low","facing":1,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[92,53,2,1],"solid":"low","facing":2,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[100,57,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[92,57,2,1],"solid":"low","facing":0,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[100,53,1,1],"solid":"low","facing":1,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[99,76,2,1],"solid":"low","facing":2,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[92,76,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[99,72,2,1],"solid":"low","facing":0,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[93,72,1,1],"solid":"low","facing":1,"note":"글씨 없는 손종","level":0},
		{"kind":"parish_chest","rect":[102,57,2,1],"solid":"low","facing":2,"note":"회중 기록 궤","level":0},
		{"kind":"hymn_shelf","rect":[109,53,2,1],"solid":"low","facing":3,"note":"찬송집 선반","level":0},
		{"kind":"desk","rect":[103,53,2,1],"solid":"low","facing":0,"note":"책상","level":0},
		{"kind":"candle_stand","rect":[109,57,1,1],"solid":"low","facing":1,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"hymn_shelf","rect":[109,72,2,1],"solid":"low","facing":2,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[103,72,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[108,76,2,1],"solid":"low","facing":0,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[102,72,1,1],"solid":"low","facing":1,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[66,64,2,1],"solid":"none","facing":2,"note":"찬송집 선반","level":1},
		{"kind":"candle_stand","rect":[63,53,1,1],"solid":"none","facing":3,"note":"초 하나가 선 외줄기 촛대","level":1},
		{"kind":"vestry_chest","rect":[63,64,2,1],"solid":"none","facing":0,"note":"제의실 궤","level":1},
		{"kind":"hand_bell","rect":[68,53,1,1],"solid":"none","facing":1,"note":"글씨 없는 손종","level":1},
		{"kind":"hymn_shelf","rect":[63,66,2,1],"solid":"none","facing":2,"note":"찬송집 선반","level":1},
		{"kind":"candle_stand","rect":[68,76,1,1],"solid":"none","facing":3,"note":"초 하나가 선 외줄기 촛대","level":1},
		{"kind":"vestry_chest","rect":[63,76,2,1],"solid":"none","facing":0,"note":"제의실 궤","level":1},
		{"kind":"hand_bell","rect":[68,66,1,1],"solid":"none","facing":1,"note":"글씨 없는 손종","level":1},
		{"kind":"cold_stove","rect":[99,73,1,1],"solid":"none","facing":2,"note":"꺼진 난로","level":-1},
		{"kind":"coal_bin","rect":[92,72,3,2],"solid":"none","facing":3,"note":"난방용 석탄","level":-1},
		{"kind":"firewood_pile","rect":[98,56,2,1],"solid":"none","facing":0,"note":"처마 밑 장작","level":-1},
		{"kind":"barrel","rect":[93,56,1,1],"solid":"none","facing":1,"note":"저장 통","level":-1},
		{"kind":"cask_stack","rect":[101,72,2,2],"solid":"none","facing":2,"note":"저장고 큰 통","level":-1},
		{"kind":"sack_pile","rect":[106,56,2,2],"solid":"none","facing":3,"note":"곡물 자루","level":-1},
		{"kind":"relief_crate","rect":[102,56,2,1],"solid":"none","facing":0,"note":"남은 구호 식량 상자","level":-1},
		{"kind":"barrel","rect":[106,73,1,1],"solid":"none","facing":1,"note":"저장 통","level":-1},
		{"kind":"hand_bell","rect":[115,53,1,1],"solid":"low","facing":2,"note":"글씨 없는 손종","level":0},
		{"kind":"lamp_shelf","rect":[114,60,2,1],"solid":"low","facing":3,"note":"꺼진 등잔 선반","level":0},
		{"kind":"candle_stand","rect":[116,60,1,1],"solid":"low","facing":0,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"hand_bell","rect":[120,60,1,1],"solid":"low","facing":1,"note":"글씨 없는 손종","level":0},
		{"kind":"lamp_shelf","rect":[118,53,2,1],"solid":"low","facing":2,"note":"꺼진 등잔 선반","level":0},
		{"kind":"candle_stand","rect":[118,60,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"hand_bell","rect":[116,60,1,1],"solid":"none","facing":0,"note":"글씨 없는 손종","level":1},
		{"kind":"lamp_shelf","rect":[114,60,2,1],"solid":"none","facing":1,"note":"꺼진 등잔 선반","level":1},
		{"kind":"candle_stand","rect":[116,53,1,1],"solid":"none","facing":2,"note":"초 하나가 선 외줄기 촛대","level":1},
		{"kind":"hand_bell","rect":[118,60,1,1],"solid":"none","facing":3,"note":"글씨 없는 손종","level":1},
		{"kind":"lamp_shelf","rect":[120,53,2,1],"solid":"none","facing":0,"note":"꺼진 등잔 선반","level":1},
		{"kind":"candle_stand","rect":[119,53,1,1],"solid":"none","facing":1,"note":"초 하나가 선 외줄기 촛대","level":1},
		{"kind":"hand_bell","rect":[114,60,1,1],"solid":"none","facing":2,"note":"글씨 없는 손종","level":2},
		{"kind":"lamp_shelf","rect":[115,53,2,1],"solid":"none","facing":3,"note":"꺼진 등잔 선반","level":2},
		{"kind":"candle_stand","rect":[115,60,1,1],"solid":"none","facing":0,"note":"초 하나가 선 외줄기 촛대","level":2},
		{"kind":"hand_bell","rect":[121,53,1,1],"solid":"none","facing":1,"note":"글씨 없는 손종","level":2},
		{"kind":"lamp_shelf","rect":[119,53,2,1],"solid":"none","facing":2,"note":"꺼진 등잔 선반","level":2},
		{"kind":"bench","rect":[118,60,3,1],"solid":"none","facing":3,"note":"긴 의자","level":2},
		{"kind":"candle_stand","rect":[118,53,1,1],"solid":"none","facing":0,"note":"초 하나가 선 외줄기 촛대","level":2},
		{"kind":"bed","rect":[128,56,2,1],"solid":"low","facing":1,"note":"침대","level":0},
		{"kind":"desk","rect":[133,62,2,1],"solid":"low","facing":2,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[127,56,1,1],"solid":"low","facing":3,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[127,62,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[133,73,2,1],"solid":"low","facing":1,"note":"침대","level":0},
		{"kind":"desk","rect":[127,67,2,1],"solid":"low","facing":2,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[135,73,1,1],"solid":"low","facing":3,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[127,73,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[137,56,2,1],"solid":"low","facing":1,"note":"침대","level":0},
		{"kind":"desk","rect":[145,62,2,1],"solid":"low","facing":2,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[137,62,1,1],"solid":"low","facing":3,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[144,56,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[145,73,2,1],"solid":"low","facing":1,"note":"침대","level":0},
		{"kind":"desk","rect":[137,73,2,1],"solid":"low","facing":2,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[146,67,1,1],"solid":"low","facing":3,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[138,67,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[127,62,2,1],"solid":"none","facing":1,"note":"침대","level":1},
		{"kind":"desk","rect":[134,56,2,1],"solid":"none","facing":2,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[128,56,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[132,62,3,1],"solid":"none","facing":0,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[134,67,2,1],"solid":"none","facing":1,"note":"침대","level":1},
		{"kind":"desk","rect":[128,67,2,1],"solid":"none","facing":2,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[134,73,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[127,73,3,1],"solid":"none","facing":0,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[138,56,2,1],"solid":"none","facing":1,"note":"침대","level":1},
		{"kind":"desk","rect":[144,62,2,1],"solid":"none","facing":2,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[137,56,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[137,62,3,1],"solid":"none","facing":0,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[144,73,2,1],"solid":"none","facing":1,"note":"침대","level":1},
		{"kind":"desk","rect":[137,67,2,1],"solid":"none","facing":2,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[146,73,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[137,73,3,1],"solid":"none","facing":0,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[127,56,2,1],"solid":"none","facing":1,"note":"침대","level":2},
		{"kind":"desk","rect":[134,62,2,1],"solid":"none","facing":2,"note":"책상","level":2},
		{"kind":"cold_stove","rect":[127,62,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":2},
		{"kind":"shelf","rect":[133,56,3,1],"solid":"none","facing":0,"note":"물건 선반","level":2},
		{"kind":"bed","rect":[134,73,2,1],"solid":"none","facing":1,"note":"침대","level":2},
		{"kind":"desk","rect":[127,73,2,1],"solid":"none","facing":2,"note":"책상","level":2},
		{"kind":"cold_stove","rect":[135,67,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":2},
		{"kind":"shelf","rect":[128,67,3,1],"solid":"none","facing":0,"note":"물건 선반","level":2},
		{"kind":"bed","rect":[137,62,2,1],"solid":"none","facing":1,"note":"침대","level":2},
		{"kind":"desk","rect":[145,56,2,1],"solid":"none","facing":2,"note":"책상","level":2},
		{"kind":"cold_stove","rect":[138,56,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":2},
		{"kind":"shelf","rect":[143,62,3,1],"solid":"none","facing":0,"note":"물건 선반","level":2},
		{"kind":"bed","rect":[145,67,2,1],"solid":"none","facing":1,"note":"침대","level":2},
		{"kind":"desk","rect":[138,67,2,1],"solid":"none","facing":2,"note":"책상","level":2},
		{"kind":"cold_stove","rect":[145,73,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":2},
		{"kind":"shelf","rect":[137,73,3,1],"solid":"none","facing":0,"note":"물건 선반","level":2},
		{"kind":"cold_stove","rect":[131,59,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":-1},
		{"kind":"coal_bin","rect":[133,69,3,2],"solid":"none","facing":2,"note":"난방용 석탄","level":-1},
		{"kind":"firewood_pile","rect":[130,70,2,1],"solid":"none","facing":3,"note":"처마 밑 장작","level":-1},
		{"kind":"barrel","rect":[136,70,1,1],"solid":"none","facing":0,"note":"저장 통","level":-1},
		{"kind":"cask_stack","rect":[141,69,2,2],"solid":"none","facing":1,"note":"저장고 큰 통","level":-1},
		{"kind":"sack_pile","rect":[138,59,2,2],"solid":"none","facing":2,"note":"곡물 자루","level":-1},
		{"kind":"relief_crate","rect":[138,70,2,1],"solid":"none","facing":3,"note":"남은 구호 식량 상자","level":-1},
		{"kind":"barrel","rect":[143,59,1,1],"solid":"none","facing":0,"note":"저장 통","level":-1},
		{"kind":"display_shelf","rect":[23,57,4,1],"solid":"low","facing":1,"note":"가게 진열대","level":0},
		{"kind":"shop_counter","rect":[13,57,3,1],"solid":"low","facing":2,"note":"가게 계산대","level":0},
		{"kind":"freezer_chest","rect":[25,55,2,1],"solid":"low","facing":3,"note":"냉동 궤","level":0},
		{"kind":"barrel","rect":[14,55,1,1],"solid":"low","facing":0,"note":"저장 통","level":0},
		{"kind":"display_shelf","rect":[13,64,4,1],"solid":"low","facing":1,"note":"가게 진열대","level":0},
		{"kind":"shop_counter","rect":[24,62,3,1],"solid":"low","facing":2,"note":"가게 계산대","level":0},
		{"kind":"freezer_chest","rect":[14,62,2,1],"solid":"low","facing":3,"note":"냉동 궤","level":0},
		{"kind":"barrel","rect":[25,64,1,1],"solid":"low","facing":0,"note":"저장 통","level":0},
		{"kind":"bed","rect":[53,55,2,1],"solid":"low","facing":1,"note":"침대","level":0},
		{"kind":"desk","rect":[42,55,2,1],"solid":"low","facing":2,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[53,57,1,1],"solid":"low","facing":3,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[41,57,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[42,62,2,1],"solid":"low","facing":1,"note":"침대","level":0},
		{"kind":"desk","rect":[52,64,2,1],"solid":"low","facing":2,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[41,62,1,1],"solid":"low","facing":3,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[41,64,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[52,57,2,1],"solid":"none","facing":1,"note":"침대","level":1},
		{"kind":"desk","rect":[41,55,2,1],"solid":"none","facing":2,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[54,57,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[41,57,3,1],"solid":"none","facing":0,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[41,62,2,1],"solid":"none","facing":1,"note":"침대","level":1},
		{"kind":"desk","rect":[53,64,2,1],"solid":"none","facing":2,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[41,64,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[52,62,3,1],"solid":"none","facing":0,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[107,20,2,1],"solid":"none","facing":1,"note":"침대","level":1},
		{"kind":"desk","rect":[97,20,2,1],"solid":"none","facing":2,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[108,18,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[98,18,3,1],"solid":"none","facing":0,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[97,27,2,1],"solid":"none","facing":1,"note":"침대","level":1},
		{"kind":"desk","rect":[107,25,2,1],"solid":"none","facing":2,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[98,25,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[105,27,3,1],"solid":"none","facing":0,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[23,31,2,1],"solid":"low","facing":1,"note":"침대","level":0},
		{"kind":"desk","rect":[14,31,2,1],"solid":"low","facing":2,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[23,33,1,1],"solid":"low","facing":3,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[13,33,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[14,38,2,1],"solid":"low","facing":1,"note":"침대","level":0},
		{"kind":"desk","rect":[22,40,2,1],"solid":"low","facing":2,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[13,38,1,1],"solid":"low","facing":3,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[13,40,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[16,76,2,1],"solid":"low","facing":1,"note":"침대","level":0},
		{"kind":"desk","rect":[13,69,2,1],"solid":"low","facing":2,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[18,76,1,1],"solid":"low","facing":3,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[13,76,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[20,69,2,1],"solid":"low","facing":1,"note":"침대","level":0},
		{"kind":"desk","rect":[23,76,2,1],"solid":"low","facing":2,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[20,76,1,1],"solid":"low","facing":3,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[22,69,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[17,76,2,1],"solid":"none","facing":1,"note":"침대","level":1},
		{"kind":"desk","rect":[13,76,2,1],"solid":"none","facing":2,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[18,69,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[14,69,3,1],"solid":"none","facing":0,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[20,76,2,1],"solid":"none","facing":1,"note":"침대","level":1},
		{"kind":"desk","rect":[23,69,2,1],"solid":"none","facing":2,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[21,69,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[22,76,3,1],"solid":"none","facing":0,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[10,84,2,1],"solid":"low","facing":1,"note":"침대","level":0},
		{"kind":"desk","rect":[7,84,2,1],"solid":"low","facing":2,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[10,91,1,1],"solid":"low","facing":3,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[6,91,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[14,84,2,1],"solid":"low","facing":1,"note":"침대","level":0},
		{"kind":"desk","rect":[15,91,2,1],"solid":"low","facing":2,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[13,84,1,1],"solid":"low","facing":3,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[133,86,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"crate_stack","rect":[131,79,2,2],"solid":"low","facing":1,"note":"나무 상자","level":0},
		{"kind":"barrel","rect":[136,86,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"handcart","rect":[131,86,2,1],"solid":"low","facing":3,"note":"뒷문 곁 손수레","level":0},
		{"kind":"shelf","rect":[138,79,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"crate_stack","rect":[141,85,2,2],"solid":"low","facing":1,"note":"나무 상자","level":0},
		{"kind":"barrel","rect":[138,86,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"handcart","rect":[141,79,2,1],"solid":"low","facing":3,"note":"뒷문 곁 손수레","level":0},
		{"kind":"cold_stove","rect":[40,90,1,1],"solid":"low","facing":0,"note":"꺼진 난로","level":0},
		{"kind":"coal_bin","rect":[31,89,3,2],"solid":"low","facing":1,"note":"난방용 석탄","level":0},
		{"kind":"firewood_pile","rect":[39,85,2,1],"solid":"low","facing":2,"note":"처마 밑 장작","level":0},
		{"kind":"barrel","rect":[32,85,1,1],"solid":"low","facing":3,"note":"저장 통","level":0},
		{"kind":"shelf","rect":[47,87,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"crate_stack","rect":[51,84,2,2],"solid":"low","facing":1,"note":"나무 상자","level":0},
		{"kind":"barrel","rect":[48,84,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"handcart","rect":[50,87,2,1],"solid":"low","facing":3,"note":"뒷문 곁 손수레","level":0},
		{"kind":"bed","rect":[31,36,2,1],"solid":"low","facing":0,"note":"침대","level":0},
		{"kind":"desk","rect":[30,39,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[29,36,1,1],"solid":"low","facing":2,"note":"꺼진 난로","level":0},
		{"kind":"community_banner","rect":[6,84,1,2],"solid":"none","facing":0,"note":"무늬 없는 바랜 천 깃발","level":0},
		{"kind":"hand_bell","rect":[127,56,1,1],"solid":"none","facing":1,"note":"글씨 없는 손종","level":1},
		{"kind":"hymn_shelf","rect":[15,55,2,1],"solid":"low","facing":2,"note":"찬송집 선반","level":0},
		{"kind":"pew_row","rect":[64,67,6,1],"solid":"low","facing":2,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"lamp_shelf","rect":[85,42,2,1],"solid":"low","facing":1,"note":"맨홀 곁 꺼진 등잔","level":0},
		{"kind":"crate_stack","rect":[77,42,2,2],"solid":"low","facing":2,"note":"맨홀 곁 나무 상자","level":0},
		{"kind":"shelf","rect":[17,55,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"shelf","rect":[21,55,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"shelf","rect":[13,56,3,1],"solid":"low","facing":1,"note":"물건 선반","level":0},
		{"kind":"crate_stack","rect":[16,56,2,2],"solid":"low","facing":2,"note":"나무 상자","level":0},
		{"kind":"pallet_stack","rect":[18,56,2,2],"solid":"low","facing":3,"note":"평평한 하역 문 곁 팰릿","level":0},
		{"kind":"barrel","rect":[13,55,1,1],"solid":"low","facing":0,"note":"저장 통","level":0},
		{"kind":"roof_beam_pile","rect":[72,61,2,3],"solid":"low","facing":0,"note":"눈 무게에 내려앉아 길을 꺾는 지붕 더미","level":0},
		{"kind":"roof_tile_heap","rect":[72,66,2,5],"solid":"low","facing":1,"note":"눈 무게에 내려앉아 길을 꺾는 지붕 더미","level":0},
		{"kind":"rubble_heap","rect":[88,59,2,5],"solid":"low","facing":0,"note":"눈 무게에 내려앉아 길을 꺾는 지붕 더미","level":0},
		{"kind":"roof_beam_pile","rect":[88,66,2,3],"solid":"low","facing":1,"note":"눈 무게에 내려앉아 길을 꺾는 지붕 더미","level":0},
		{"kind":"roof_tile_heap","rect":[100,61,2,3],"solid":"low","facing":0,"note":"눈 무게에 내려앉아 길을 꺾는 지붕 더미","level":0},
		{"kind":"rubble_heap","rect":[100,66,2,5],"solid":"low","facing":1,"note":"눈 무게에 내려앉아 길을 꺾는 지붕 더미","level":0},
		{"kind":"fallen_bell","rect":[93,66,3,3],"solid":"low","facing":0,"note":"눈 무게로 떨어진 종","level":0},
		{"kind":"snow_drift","rect":[102,67,4,2],"solid":"none","facing":1,"note":"모서리의 눈더미","level":0},
		{"kind":"pew_row","rect":[66,62,6,1],"solid":"low","facing":2,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[90,59,6,1],"solid":"low","facing":3,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[66,63,6,1],"solid":"low","facing":0,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[102,62,6,1],"solid":"low","facing":1,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[63,66,6,1],"solid":"low","facing":2,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[90,63,6,1],"solid":"low","facing":3,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[78,66,6,1],"solid":"low","facing":0,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[102,66,6,1],"solid":"low","facing":1,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[82,67,6,1],"solid":"low","facing":3,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"altar_table","rect":[106,63,3,1],"solid":"low","facing":0,"note":"무늬 없는 천을 덮은 제단 탁자","level":0},
		{"kind":"pulpit","rect":[98,61,2,2],"solid":"low","facing":1,"note":"설교단","level":0},
		{"kind":"candle_stand","rect":[103,61,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"candle_stand","rect":[102,61,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"community_banner","rect":[108,61,1,2],"solid":"none","facing":0,"note":"무늬 없는 바랜 천 깃발","level":0}
	],
	"rooms": [
		{"building":0,"level":0,"rect":[63,53,8,5],"name":"찬송집 방","theme":"church"},
		{"building":0,"level":0,"rect":[63,72,8,5],"name":"종지기 방","theme":"church"},
		{"building":0,"level":0,"rect":[72,53,9,5],"name":"현관 방","theme":"church"},
		{"building":0,"level":0,"rect":[72,72,9,5],"name":"옆 예배실","theme":"church"},
		{"building":0,"level":0,"rect":[82,53,9,5],"name":"제의실","theme":"church"},
		{"building":0,"level":0,"rect":[82,72,9,5],"name":"회중 준비방","theme":"church"},
		{"building":0,"level":0,"rect":[92,53,9,5],"name":"교구 사무방","theme":"church"},
		{"building":0,"level":0,"rect":[92,72,9,5],"name":"성가대방","theme":"church"},
		{"building":0,"level":0,"rect":[102,53,9,5],"name":"기록방","theme":"archive"},
		{"building":0,"level":0,"rect":[102,72,9,5],"name":"안쪽 저장실","theme":"church"},
		{"building":0,"level":0,"rect":[63,59,48,12],"name":"회중석","theme":"nave"},
		{"building":0,"level":1,"rect":[63,53,6,12],"name":"합창 다락 앞방","theme":"church"},
		{"building":0,"level":1,"rect":[63,66,6,11],"name":"합창 다락 뒷방","theme":"church"},
		{"building":0,"level":-1,"rect":[92,56,8,18],"name":"난방실","theme":"heat"},
		{"building":0,"level":-1,"rect":[101,56,7,18],"name":"막다른 식량 저장실","theme":"cellar"},
		{"building":0,"level":-1,"rect":[89,53,22,2],"name":"저장고 둘레 통로","theme":"corridor"},
		{"building":1,"level":0,"rect":[114,53,3,8],"name":"탑 아래 앞방","theme":"tower"},
		{"building":1,"level":0,"rect":[118,53,4,8],"name":"탑 아래 뒷방","theme":"tower"},
		{"building":1,"level":1,"rect":[114,53,3,8],"name":"종 줄 방","theme":"tower"},
		{"building":1,"level":1,"rect":[118,53,4,8],"name":"종 줄 방의 돌아가는 길","theme":"tower"},
		{"building":1,"level":2,"rect":[114,53,3,8],"name":"종 다락 앞방","theme":"tower"},
		{"building":1,"level":2,"rect":[118,53,4,8],"name":"종 다락","theme":"tower"},
		{"building":2,"level":0,"rect":[127,56,9,7],"name":"교구 회관 앞방","theme":"home"},
		{"building":2,"level":0,"rect":[127,67,9,7],"name":"교구 회관 뒷방","theme":"home"},
		{"building":2,"level":0,"rect":[137,56,10,7],"name":"교구 회관 앞방","theme":"home"},
		{"building":2,"level":0,"rect":[137,67,10,7],"name":"교구 회관 뒷방","theme":"home"},
		{"building":2,"level":1,"rect":[127,56,9,7],"name":"교구 회관 앞방","theme":"home"},
		{"building":2,"level":1,"rect":[127,67,9,7],"name":"교구 회관 뒷방","theme":"home"},
		{"building":2,"level":1,"rect":[137,56,10,7],"name":"교구 회관 앞방","theme":"home"},
		{"building":2,"level":1,"rect":[137,67,10,7],"name":"교구 회관 뒷방","theme":"home"},
		{"building":2,"level":2,"rect":[127,56,9,7],"name":"교구 회관 앞방","theme":"home"},
		{"building":2,"level":2,"rect":[127,67,9,7],"name":"교구 회관 뒷방","theme":"home"},
		{"building":2,"level":2,"rect":[137,56,10,7],"name":"교구 회관 앞방","theme":"home"},
		{"building":2,"level":2,"rect":[137,67,10,7],"name":"교구 회관 뒷방","theme":"home"},
		{"building":2,"level":-1,"rect":[130,59,7,12],"name":"난방실","theme":"heat"},
		{"building":2,"level":-1,"rect":[138,59,6,12],"name":"막다른 식량 저장실","theme":"cellar"},
		{"building":2,"level":-1,"rect":[127,56,20,2],"name":"저장고 둘레 통로","theme":"corridor"},
		{"building":3,"level":0,"rect":[13,55,14,3],"name":"잡화점 앞방","theme":"shop"},
		{"building":3,"level":0,"rect":[13,62,14,3],"name":"잡화점 뒷방","theme":"shop"},
		{"building":4,"level":0,"rect":[41,55,14,3],"name":"비어 있는 사제관 앞방","theme":"home"},
		{"building":4,"level":0,"rect":[41,62,14,3],"name":"비어 있는 사제관 뒷방","theme":"home"},
		{"building":4,"level":1,"rect":[41,55,14,3],"name":"비어 있는 사제관 앞방","theme":"home"},
		{"building":4,"level":1,"rect":[41,62,14,3],"name":"비어 있는 사제관 뒷방","theme":"home"},
		{"building":5,"level":0,"rect":[39,19,7,8],"name":"수리 작업장 앞방","theme":"store"},
		{"building":5,"level":0,"rect":[47,19,6,8],"name":"수리 작업장 뒷방","theme":"store"},
		{"building":6,"level":0,"rect":[67,19,9,8],"name":"자재 창고 앞방","theme":"store"},
		{"building":6,"level":0,"rect":[77,19,8,8],"name":"자재 창고 뒷방","theme":"store"},
		{"building":7,"level":0,"rect":[97,18,12,3],"name":"농가 가 앞방","theme":"home"},
		{"building":7,"level":0,"rect":[97,25,12,3],"name":"농가 가 뒷방","theme":"home"},
		{"building":7,"level":1,"rect":[97,18,12,3],"name":"농가 가 앞방","theme":"home"},
		{"building":7,"level":1,"rect":[97,25,12,3],"name":"농가 가 뒷방","theme":"home"},
		{"building":8,"level":0,"rect":[13,31,12,3],"name":"농가 나 앞방","theme":"home"},
		{"building":8,"level":0,"rect":[13,38,12,3],"name":"농가 나 뒷방","theme":"home"},
		{"building":9,"level":0,"rect":[13,69,6,8],"name":"주택 가 앞방","theme":"home"},
		{"building":9,"level":0,"rect":[20,69,5,8],"name":"주택 가 뒷방","theme":"home"},
		{"building":9,"level":1,"rect":[13,69,6,8],"name":"주택 가 앞방","theme":"home"},
		{"building":9,"level":1,"rect":[20,69,5,8],"name":"주택 가 뒷방","theme":"home"},
		{"building":10,"level":0,"rect":[6,84,6,8],"name":"주택 나 앞방","theme":"home"},
		{"building":10,"level":0,"rect":[13,84,5,8],"name":"주택 나 뒷방","theme":"home"},
		{"building":11,"level":0,"rect":[131,79,6,8],"name":"마구간 앞방","theme":"store"},
		{"building":11,"level":0,"rect":[138,79,5,8],"name":"마구간 뒷방","theme":"store"},
		{"building":12,"level":0,"rect":[31,85,10,6],"name":"장작 헛간 안방","theme":"heat"},
		{"building":13,"level":0,"rect":[47,84,6,4],"name":"묘지 관리 창고 안방","theme":"store"},
		{"building":14,"level":0,"rect":[29,36,4,4],"name":"우물집 안방","theme":"home"}
	],
	"containers": [
		{"id":"box_001","name":"찬송집 방 보관함","cell":[63,56],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_002","name":"종지기 방 보관함","cell":[65,75],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_003","name":"현관 방 보관함","cell":[72,56],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_004","name":"옆 예배실 보관함","cell":[75,75],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_005","name":"제의실 보관함","cell":[90,55],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_006","name":"회중 준비방 보관함","cell":[83,75],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_007","name":"교구 사무방 보관함","cell":[92,56],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_008","name":"성가대방 보관함","cell":[94,75],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_009","name":"기록방 보관함","cell":[102,56],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_010","name":"안쪽 저장실 보관함","cell":[104,75],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_011","name":"회중석 보관함","cell":[69,66],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_012","name":"합창 다락 앞방 보관함","cell":[66,60],"building":0,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_013","name":"합창 다락 뒷방 보관함","cell":[64,73],"building":0,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_014","name":"난방실 보관함","cell":[98,67],"building":0,"search":4,"items":["document"],"locked":false,"level":-1,"searched":false},
		{"id":"box_015","name":"막다른 식량 저장실 보관함","cell":[106,67],"building":0,"search":6,"items":["plank","plank","document"],"locked":false,"level":-1,"searched":false},
		{"id":"box_016","name":"탑 아래 앞방 보관함","cell":[114,57],"building":1,"search":4,"items":["symbol_bell"],"locked":false,"level":0,"searched":false},
		{"id":"box_017","name":"탑 아래 뒷방 보관함","cell":[120,57],"building":1,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_018","name":"종 줄 방 보관함","cell":[116,57],"building":1,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_019","name":"종 줄 방의 돌아가는 길 보관함","cell":[120,57],"building":1,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_020","name":"종 다락 앞방 보관함","cell":[115,57],"building":1,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_021","name":"종 다락 보관함","cell":[120,57],"building":1,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_022","name":"교구 회관 앞방 보관함","cell":[128,60],"building":2,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_023","name":"교구 회관 뒷방 보관함","cell":[129,71],"building":2,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_024","name":"교구 회관 앞방 보관함","cell":[140,60],"building":2,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_025","name":"교구 회관 뒷방 보관함","cell":[141,71],"building":2,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_026","name":"교구 회관 앞방 보관함","cell":[130,60],"building":2,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_027","name":"교구 회관 뒷방 보관함","cell":[133,71],"building":2,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_028","name":"교구 회관 앞방 보관함","cell":[140,60],"building":2,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_029","name":"교구 회관 뒷방 보관함","cell":[143,71],"building":2,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_030","name":"교구 회관 앞방 보관함","cell":[130,60],"building":2,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_031","name":"교구 회관 뒷방 보관함","cell":[133,71],"building":2,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_032","name":"교구 회관 앞방 보관함","cell":[140,60],"building":2,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_033","name":"교구 회관 뒷방 보관함","cell":[143,71],"building":2,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_034","name":"난방실 보관함","cell":[136,66],"building":2,"search":4,"items":[],"locked":false,"level":-1,"searched":false},
		{"id":"box_035","name":"막다른 식량 저장실 보관함","cell":[143,66],"building":2,"search":4,"items":[],"locked":false,"level":-1,"searched":false},
		{"id":"box_036","name":"잡화점 앞방 보관함","cell":[22,56],"building":3,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_037","name":"잡화점 뒷방 보관함","cell":[24,63],"building":3,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_038","name":"비어 있는 사제관 앞방 보관함","cell":[53,56],"building":4,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_039","name":"비어 있는 사제관 뒷방 보관함","cell":[52,63],"building":4,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_040","name":"비어 있는 사제관 앞방 보관함","cell":[54,56],"building":4,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_041","name":"비어 있는 사제관 뒷방 보관함","cell":[54,63],"building":4,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_042","name":"수리 작업장 앞방 보관함","cell":[42,24],"building":5,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_043","name":"수리 작업장 뒷방 보관함","cell":[50,24],"building":5,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_044","name":"자재 창고 앞방 보관함","cell":[70,24],"building":6,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_045","name":"자재 창고 뒷방 보관함","cell":[80,24],"building":6,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_046","name":"농가 가 앞방 보관함","cell":[108,19],"building":7,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_047","name":"농가 가 뒷방 보관함","cell":[108,26],"building":7,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_048","name":"농가 가 앞방 보관함","cell":[108,19],"building":7,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_049","name":"농가 가 뒷방 보관함","cell":[108,26],"building":7,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_050","name":"농가 나 앞방 보관함","cell":[23,32],"building":8,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_051","name":"농가 나 뒷방 보관함","cell":[22,39],"building":8,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_052","name":"주택 가 앞방 보관함","cell":[13,74],"building":9,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_053","name":"주택 가 뒷방 보관함","cell":[22,74],"building":9,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_054","name":"주택 가 앞방 보관함","cell":[15,74],"building":9,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_055","name":"주택 가 뒷방 보관함","cell":[22,74],"building":9,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_056","name":"주택 나 앞방 보관함","cell":[8,89],"building":10,"search":6,"items":["plank","plank","document"],"locked":false,"level":0,"searched":false},
		{"id":"box_057","name":"주택 나 뒷방 보관함","cell":[15,89],"building":10,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_058","name":"마구간 앞방 보관함","cell":[131,84],"building":11,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_059","name":"마구간 뒷방 보관함","cell":[139,84],"building":11,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_060","name":"장작 헛간 안방 보관함","cell":[35,88],"building":12,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_061","name":"묘지 관리 창고 안방 보관함","cell":[50,86],"building":13,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_062","name":"우물집 안방 보관함","cell":[32,38],"building":14,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_063","name":"승강장 남은 상자","cell":[51,10],"building":-1,"search":3,"items":["plank","cloth"],"locked":false,"level":0,"searched":false}
	],
	"entries": [
		{"id":"west_road","cells":[[0,44],[0,45],[0,46],[0,47]],"gap":0.6},
		{"id":"south_road","cells":[[152,94],[153,94],[154,94],[155,94]],"gap":0.6},
		{"id":"southwest_path","cells":[[0,80],[0,81],[0,82]],"gap":2},
		{"id":"northeast_path","cells":[[159,38],[159,39],[159,40]],"gap":2}
	],
	"holes": [
		{"id":"manhole_01","cell":[82,45],"name":"수리 마당 앞 맨홀","level":0,"gap":3}
	],
	"slots": [
		[55,26],
		[56,26],
		[92,27],
		[94,27],
		[111,26],
		[113,26]
	],
	"dead": [
		[4,46],
		[153,91],
		[4,81],
		[157,38],
		[42,74],
		[116,85]
	],
	"deep": [
		"B",
		"E"
	],
	"work": {"cell":[70,39],"rect":[56,30,40,12]},
	"finishes": [
		{"level":0,"rect":[88,59,23,11],"kind":"SNOW"},
		{"level":0,"rect":[63,69,48,2],"kind":"WOOD"},
		{"level":0,"rect":[63,59,15,2],"kind":"WOOD"},
		{"level":0,"rect":[63,59,2,7],"kind":"WOOD"},
		{"level":0,"rect":[76,59,2,12],"kind":"WOOD"},
		{"level":0,"rect":[76,69,22,2],"kind":"WOOD"},
		{"level":0,"rect":[96,59,2,12],"kind":"WOOD"},
		{"level":0,"rect":[96,59,15,2],"kind":"WOOD"},
		{"level":0,"rect":[109,59,2,7],"kind":"WOOD"},
		{"level":0,"rect":[72,64,2,2],"kind":"GRAVEL"},
		{"level":0,"rect":[88,64,2,2],"kind":"GRAVEL"},
		{"level":0,"rect":[100,64,2,2],"kind":"GRAVEL"},
		{"level":0,"rect":[96,64,2,1],"kind":"GRAVEL"}
	],
	"salvage": [
		{"id":"repair_wood","name":"수리 목재 회수 자리","cell":[72,39],"material":"wood","amount":3},
		{"id":"fallen_beams","name":"내려앉은 들보 회수 자리","cell":[85,63],"material":"wood","amount":3}
	]
}

# 위쪽 일터의 독립 평면. 아래쪽 계획의 건물 번호 뒤에만 덧붙인다.
const NORTH: Dictionary = {
	"names": {"H":"상회와 마구간 구역","I":"석탄 야적장","J":"동쪽 벌판"},
	"zones": [
		{"id":"H","rect":[0,0,60,46]},
		{"id":"I","rect":[60,0,56,46]},
		{"id":"J","rect":[116,0,44,46]}
	],
	"ground": [
		{"rect":[60,0,56,24],"kind":"GRAVEL"},
		{"rect":[116,0,44,45],"kind":"DEEP_SNOW"},
		{"rect":[60,0,6,43],"kind":"ROAD"},
		{"rect":[66,10,94,4],"kind":"ROAD"},
		{"rect":[0,19,36,4],"kind":"ROAD"},
		{"rect":[100,14,6,29],"kind":"GRAVEL"},
		{"rect":[134,24,6,21],"kind":"ROAD"},
		{"rect":[114,14,6,14],"kind":"ROAD"},
		{"rect":[110,24,10,4],"kind":"ROAD"},
		{"rect":[110,24,6,21],"kind":"ROAD"},
		{"rect":[10,24,6,21],"kind":"ROAD"},
		{"rect":[96,34,6,11],"kind":"ROAD"}
	],
	"buildings": [
		{"id":15,"name":"연료 상회 본관","rect":[36,10,24,14],"warm":false,"window_broken":false},
		{"id":16,"name":"석탄 광","rect":[74,16,26,8],"warm":false,"window_broken":false},
		{"id":17,"name":"관리인 집","rect":[104,1,12,8],"warm":false,"window_broken":false},
		{"id":18,"name":"마구간","rect":[5,3,14,9],"warm":false,"window_broken":false},
		{"id":19,"name":"마차 헛간","rect":[20,12,16,6],"warm":false,"window_broken":false},
		{"id":20,"name":"외딴 계량소","rect":[148,0,10,10],"warm":false,"window_broken":false},
		{"id":21,"name":"농가","rect":[116,28,18,12],"warm":false,"window_broken":false},
		{"id":22,"name":"연장 헛간","rect":[142,36,10,8],"warm":false,"window_broken":false}
	],
	"shells": [
		{"building":15,"level":-1,"rect":[36,10,24,14]},
		{"building":15,"level":0,"rect":[36,10,24,14]},
		{"building":15,"level":1,"rect":[36,10,24,14]},
		{"building":16,"level":0,"rect":[74,16,26,8]},
		{"building":17,"level":0,"rect":[104,1,12,8]},
		{"building":17,"level":1,"rect":[104,1,12,8]},
		{"building":18,"level":0,"rect":[5,3,14,9]},
		{"building":19,"level":0,"rect":[20,12,16,6]},
		{"building":20,"level":0,"rect":[148,0,10,10]},
		{"building":21,"level":0,"rect":[116,28,18,12]},
		{"building":21,"level":1,"rect":[116,28,18,12]},
		{"building":22,"level":0,"rect":[142,36,10,8]}
	],
	"walls": [
		{"level":-1,"rect":[39,13,18,1]},
		{"level":-1,"rect":[39,20,18,1]},
		{"level":-1,"rect":[39,13,1,8]},
		{"level":-1,"rect":[56,13,1,8]},
		{"level":-1,"rect":[48,14,1,6]},
		{"level":0,"rect":[37,15,22,1]},
		{"level":0,"rect":[37,18,22,1]},
		{"level":0,"rect":[43,11,1,4]},
		{"level":0,"rect":[43,19,1,4]},
		{"level":0,"rect":[50,11,1,4]},
		{"level":0,"rect":[50,19,1,4]},
		{"level":1,"rect":[48,11,1,12]},
		{"level":0,"rect":[75,20,24,1]},
		{"level":0,"rect":[82,17,1,3]},
		{"level":0,"rect":[90,17,1,3]},
		{"level":0,"rect":[110,2,1,6]},
		{"level":1,"rect":[110,2,1,6]},
		{"level":0,"rect":[12,4,1,7]},
		{"level":0,"rect":[154,1,1,8]},
		{"level":0,"rect":[149,5,6,1]},
		{"level":0,"rect":[125,29,1,10]},
		{"level":1,"rect":[125,29,1,10]}
	],
	"doors": [
		{"building":15,"level":-1,"cell":[39,15],"side":[-1,0],"state":"open","outer":false},
		{"building":15,"level":-1,"cell":[48,16],"side":[1,0],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[40,15],"side":[0,1],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[40,18],"side":[0,-1],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[47,15],"side":[0,1],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[47,18],"side":[0,-1],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[55,15],"side":[0,1],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[55,18],"side":[0,-1],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[36,16],"side":[-1,0],"state":"open","outer":true},
		{"building":15,"level":0,"cell":[59,16],"side":[1,0],"state":"open","outer":true},
		{"building":15,"level":1,"cell":[48,17],"side":[1,0],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[78,20],"side":[0,1],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[86,20],"side":[0,1],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[95,20],"side":[0,1],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[87,16],"side":[0,-1],"state":"open","outer":true},
		{"building":17,"level":0,"cell":[110,5],"side":[1,0],"state":"open","outer":false},
		{"building":17,"level":0,"cell":[107,8],"side":[0,1],"state":"open","outer":true},
		{"building":17,"level":1,"cell":[110,5],"side":[1,0],"state":"open","outer":false},
		{"building":18,"level":0,"cell":[12,7],"side":[1,0],"state":"open","outer":false},
		{"building":18,"level":0,"cell":[9,11],"side":[0,1],"state":"open","outer":true},
		{"building":19,"level":0,"cell":[28,17],"side":[0,1],"state":"open","outer":true},
		{"building":20,"level":0,"cell":[154,3],"side":[1,0],"state":"open","outer":false},
		{"building":20,"level":0,"cell":[154,7],"side":[1,0],"state":"open","outer":false},
		{"building":20,"level":0,"cell":[148,6],"side":[-1,0],"state":"open","outer":true},
		{"building":21,"level":0,"cell":[125,34],"side":[1,0],"state":"open","outer":false},
		{"building":21,"level":0,"cell":[133,34],"side":[1,0],"state":"open","outer":true},
		{"building":21,"level":1,"cell":[125,34],"side":[1,0],"state":"open","outer":false},
		{"building":22,"level":0,"cell":[142,40],"side":[-1,0],"state":"open","outer":true}
	],
	"windows": [
		{"building":15,"level":-1,"cell":[44,10],"broken":false},
		{"building":15,"level":-1,"cell":[52,10],"broken":false},
		{"building":15,"level":0,"cell":[40,10],"broken":false},
		{"building":15,"level":0,"cell":[47,10],"broken":false},
		{"building":15,"level":0,"cell":[55,10],"broken":false},
		{"building":15,"level":1,"cell":[42,10],"broken":false},
		{"building":15,"level":1,"cell":[54,10],"broken":false},
		{"building":16,"level":0,"cell":[78,16],"broken":false},
		{"building":16,"level":0,"cell":[86,16],"broken":false},
		{"building":16,"level":0,"cell":[95,16],"broken":false},
		{"building":17,"level":0,"cell":[107,1],"broken":false},
		{"building":17,"level":0,"cell":[113,1],"broken":false},
		{"building":17,"level":1,"cell":[107,1],"broken":false},
		{"building":17,"level":1,"cell":[113,1],"broken":false},
		{"building":18,"level":0,"cell":[9,3],"broken":false},
		{"building":18,"level":0,"cell":[15,3],"broken":false},
		{"building":19,"level":0,"cell":[28,12],"broken":false},
		{"building":20,"level":0,"cell":[151,0],"broken":false},
		{"building":21,"level":0,"cell":[121,28],"broken":false},
		{"building":21,"level":0,"cell":[129,28],"broken":false},
		{"building":21,"level":1,"cell":[121,28],"broken":false},
		{"building":21,"level":1,"cell":[129,28],"broken":false},
		{"building":22,"level":0,"cell":[147,36],"broken":false}
	],
	"stairs": [
		{"cell":[37,11],"low":-1,"high":0,"ladder":false},
		{"cell":[58,22],"low":-1,"high":0,"ladder":false},
		{"cell":[37,11],"low":0,"high":1,"ladder":false},
		{"cell":[105,2],"low":0,"high":1,"ladder":false},
		{"cell":[117,29],"low":0,"high":1,"ladder":false}
	],
	"props": [
		{"kind":"coal_heap","rect":[70,38,4,3],"solid":"low","facing":0,"note":"식은 석탄 더미","level":0},
		{"kind":"crate_stack","rect":[48,41,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"farm_cart","rect":[98,28,2,4],"solid":"low","facing":0,"note":"운반하다 세워 둔 짐수레","level":0},
		{"kind":"handcart","rect":[30,31,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"coal_wagon","rect":[76,4,8,3],"solid":"wagon","facing":0,"note":"문이 열린 석탄만 담은 화차","level":0},
		{"kind":"coal_wagon","rect":[88,7,8,3],"solid":"wagon","facing":0,"note":"문이 열린 석탄만 담은 화차","level":0},
		{"kind":"coal_wagon","rect":[106,21,8,3],"solid":"wagon","facing":0,"note":"문이 열린 석탄만 담은 화차","level":0},
		{"kind":"coal_heap","rect":[66,21,4,3],"solid":"low","facing":0,"note":"식은 석탄 더미","level":0},
		{"kind":"coal_heap","rect":[70,21,4,3],"solid":"low","facing":0,"note":"식은 석탄 더미","level":0},
		{"kind":"coal_heap","rect":[68,2,4,3],"solid":"low","facing":0,"note":"식은 석탄 더미","level":0},
		{"kind":"crate_stack","rect":[70,7,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"handcart","rect":[73,8,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"farm_cart","rect":[22,3,4,2],"solid":"low","facing":0,"note":"운반하다 세워 둔 짐수레","level":0},
		{"kind":"sack_pile","rect":[28,4,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"barrel","rect":[31,6,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"bench","rect":[26,8,3,1],"solid":"low","facing":0,"note":"쉬어 가던 긴 의자","level":0},
		{"kind":"lamp_post","rect":[59,8,1,1],"solid":"none","facing":0,"note":"꺼진 등잔 기둥","level":0},
		{"kind":"fieldstone_wall","rect":[114,23,2,1],"solid":"low","facing":0,"note":"글씨 없는 들돌 담 토막","level":0},
		{"kind":"bare_tree","rect":[2,14,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[8,16,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[13,14,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[16,17,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[118,1,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[123,3,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[127,0,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[130,6,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[154,28,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[157,33,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[155,41,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[158,44,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"sack_pile","rect":[41,14,2,2],"solid":"none","facing":0,"note":"물자를 담은 자루","level":-1},
		{"kind":"shelf","rect":[40,19,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":-1},
		{"kind":"barrel","rect":[47,19,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":-1},
		{"kind":"sack_pile","rect":[49,14,2,2],"solid":"none","facing":0,"note":"물자를 담은 자루","level":-1},
		{"kind":"shelf","rect":[50,19,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":-1},
		{"kind":"barrel","rect":[55,14,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":-1},
		{"kind":"display_shelf","rect":[38,11,4,1],"solid":"low","facing":0,"note":"가게 앞방 진열대","level":0},
		{"kind":"shop_counter","rect":[37,13,3,1],"solid":"low","facing":0,"note":"매장 계산대","level":0},
		{"kind":"barrel","rect":[42,11,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"bench","rect":[37,19,3,1],"solid":"low","facing":0,"note":"쉬어 가던 긴 의자","level":0},
		{"kind":"cold_stove","rect":[42,22,1,1],"solid":"low","facing":0,"note":"작게 식은 난로","level":0},
		{"kind":"desk","rect":[44,11,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"barrel","rect":[49,11,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"sack_pile","rect":[44,12,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"sack_pile","rect":[44,19,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"barrel","rect":[49,19,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"desk","rect":[51,14,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"shelf","rect":[51,13,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"handcart","rect":[51,22,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"crate_stack","rect":[51,19,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"sack_pile","rect":[57,20,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"desk","rect":[38,11,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":1},
		{"kind":"shelf","rect":[37,12,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"shelf","rect":[49,11,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"barrel","rect":[58,22,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":1},
		{"kind":"crate_stack","rect":[49,12,2,2],"solid":"none","facing":0,"note":"종류별 물자를 담은 나무 상자","level":1},
		{"kind":"coal_bin","rect":[75,17,3,2],"solid":"low","facing":0,"note":"난방용 석탄 칸","level":0},
		{"kind":"sack_pile","rect":[80,17,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"barrel","rect":[75,19,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"coal_bin","rect":[83,17,3,2],"solid":"low","facing":0,"note":"난방용 석탄 칸","level":0},
		{"kind":"sack_pile","rect":[88,17,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"barrel","rect":[83,19,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"coal_bin","rect":[91,17,3,2],"solid":"low","facing":0,"note":"난방용 석탄 칸","level":0},
		{"kind":"sack_pile","rect":[97,17,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"barrel","rect":[98,19,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"cold_stove","rect":[109,2,1,1],"solid":"low","facing":0,"note":"작게 식은 난로","level":0},
		{"kind":"shelf","rect":[106,2,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"barrel","rect":[105,7,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"sack_pile","rect":[111,2,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[111,7,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"bed","rect":[105,7,2,1],"solid":"none","facing":0,"note":"숙직하는 이의 침대","level":1},
		{"kind":"desk","rect":[105,3,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":1},
		{"kind":"bed","rect":[111,2,2,1],"solid":"none","facing":0,"note":"숙직하는 이의 침대","level":1},
		{"kind":"shelf","rect":[111,7,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"sack_pile","rect":[6,4,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"handcart","rect":[6,10,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"barrel","rect":[11,10,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"sack_pile","rect":[13,4,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"handcart","rect":[13,9,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"barrel","rect":[17,10,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"shelf","rect":[21,13,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[21,15,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[21,14,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"shelf","rect":[149,1,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[149,2,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[152,4,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"shelf","rect":[150,8,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"desk","rect":[152,6,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"cold_stove","rect":[117,38,1,1],"solid":"low","facing":0,"note":"작게 식은 난로","level":0},
		{"kind":"shelf","rect":[118,38,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"barrel","rect":[124,38,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"sack_pile","rect":[126,29,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[126,38,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"bed","rect":[117,38,2,1],"solid":"none","facing":0,"note":"숙직하는 이의 침대","level":1},
		{"kind":"desk","rect":[117,30,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":1},
		{"kind":"bed","rect":[126,29,2,1],"solid":"none","facing":0,"note":"숙직하는 이의 침대","level":1},
		{"kind":"shelf","rect":[126,38,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"shelf","rect":[143,42,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[149,37,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[143,41,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0}
	],
	"rooms": [
		{"building":15,"level":-1,"rect":[40,14,8,6],"name":"연료 상회 본관 지하 통 저장방","theme":"coalshop"},
		{"building":15,"level":-1,"rect":[49,14,7,6],"name":"연료 상회 본관 지하 막다른 저장방","theme":"coalshop"},
		{"building":15,"level":0,"rect":[37,11,6,4],"name":"연료 상회 본관 가게방","theme":"coalshop"},
		{"building":15,"level":0,"rect":[37,19,6,4],"name":"연료 상회 본관 휴게방","theme":"coalshop"},
		{"building":15,"level":0,"rect":[44,11,6,4],"name":"연료 상회 본관 계량방","theme":"coalshop"},
		{"building":15,"level":0,"rect":[44,19,6,4],"name":"연료 상회 본관 연료 창고","theme":"coalshop"},
		{"building":15,"level":0,"rect":[51,11,8,4],"name":"연료 상회 본관 사무방","theme":"coalshop"},
		{"building":15,"level":0,"rect":[51,19,8,4],"name":"연료 상회 본관 하역방","theme":"coalshop"},
		{"building":15,"level":1,"rect":[37,11,11,12],"name":"연료 상회 본관 위층 앞방","theme":"coalshop"},
		{"building":15,"level":1,"rect":[49,11,10,12],"name":"연료 상회 본관 위층 뒷방","theme":"coalshop"},
		{"building":16,"level":0,"rect":[75,17,7,3],"name":"석탄 광 선별방","theme":"coal"},
		{"building":16,"level":0,"rect":[83,17,7,3],"name":"석탄 광 건조방","theme":"coal"},
		{"building":16,"level":0,"rect":[91,17,8,3],"name":"석탄 광 포장방","theme":"coal"},
		{"building":17,"level":0,"rect":[105,2,5,6],"name":"관리인 집 앞방","theme":"house"},
		{"building":17,"level":0,"rect":[111,2,4,6],"name":"관리인 집 뒷방","theme":"house"},
		{"building":17,"level":1,"rect":[105,2,5,6],"name":"관리인 집 위층 앞방","theme":"house"},
		{"building":17,"level":1,"rect":[111,2,4,6],"name":"관리인 집 위층 뒷방","theme":"house"},
		{"building":18,"level":0,"rect":[6,4,6,7],"name":"마구간 앞방","theme":"hay"},
		{"building":18,"level":0,"rect":[13,4,5,7],"name":"마구간 뒷방","theme":"hay"},
		{"building":19,"level":0,"rect":[21,13,14,4],"name":"마차 헛간 작업방","theme":"tools"},
		{"building":20,"level":0,"rect":[149,1,5,4],"name":"외딴 계량소 앞 작업방","theme":"tools"},
		{"building":20,"level":0,"rect":[149,6,5,3],"name":"외딴 계량소 안쪽 보관방","theme":"tools"},
		{"building":21,"level":0,"rect":[117,29,8,10],"name":"농가 앞방","theme":"house"},
		{"building":21,"level":0,"rect":[126,29,7,10],"name":"농가 뒷방","theme":"house"},
		{"building":21,"level":1,"rect":[117,29,8,10],"name":"농가 위층 앞방","theme":"house"},
		{"building":21,"level":1,"rect":[126,29,7,10],"name":"농가 위층 뒷방","theme":"house"},
		{"building":22,"level":0,"rect":[143,37,8,6],"name":"연장 헛간 작업방","theme":"tools"}
	],
	"containers": [
		{"id":"north_box_008","name":"연료 상회 본관 하역방 보관함","cell":[58,19],"building":15,"search":6,"items":["scrap"],"locked":false,"level":0,"searched":false},
		{"id":"north_box_012","name":"석탄 광 건조방 보관함","cell":[89,19],"building":16,"search":6,"items":["scrap"],"locked":false,"level":0,"searched":false},
		{"id":"north_box_020","name":"마차 헛간 작업방 보관함","cell":[34,13],"building":19,"search":6,"items":["scrap"],"locked":false,"level":0,"searched":false},
		{"id":"north_box_021","name":"외딴 계량소 막다른 물자 보관함","cell":[149,4],"building":20,"search":8,"items":["tweezers","needle_thread"],"locked":false,"level":0,"searched":false},
		{"id":"north_box_022","name":"외딴 계량소 안쪽 보관방 보관함","cell":[149,8],"building":20,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"north_shallow","name":"운반 도중 내려둔 물자 보관함","cell":[49,39],"building":-1,"search":2,"items":["needle_thread"],"locked":false,"level":0,"searched":false}
	],
	"entries": [
		{"id":"북쪽 야적장 길","cells":[[61,0],[62,0],[63,0],[64,0]],"gap":0.6},
		{"id":"서쪽 상회 샛길","cells":[[0,20],[0,21],[0,22]],"gap":2.5},
		{"id":"동쪽 석탄 들길","cells":[[159,11],[159,12],[159,13]],"gap":0.6}
	],
	"holes": [
		{"id":"manhole_02","cell":[62,12],"name":"석탄 야적장 맨홀","level":0,"gap":3}
	],
	"slots": [
		[61,24],
		[64,25],
		[101,24],
		[104,25],
		[116,25],
		[117,27],
		[34,44],
		[34,50],
		[50,44],
		[50,50],
		[66,44],
		[66,50]
	],
	"crossings": [
		32,
		48
	],
	"deep": "J",
	"salvage": [
		{"id":"north_coal","name":"야적장 석탄 자루","cell":[68,18],"material":"coal","amount":12}
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
const ENTRY_NAMES: Dictionary = {"west_road": "서쪽 길", "south_road": "남쪽 길", "southwest_path": "남서쪽 오솔길", "northeast_path": "북동쪽 오솔길", "manhole_01": "첫째 맨홀", "북쪽 야적장 길": "북쪽 야적장 길", "서쪽 상회 샛길": "서쪽 상회 샛길", "동쪽 석탄 들길": "동쪽 석탄 들길", "manhole_02": "둘째 맨홀"}
const ENTRY_WEIGHTS: Dictionary = {"west_road": 1.0, "south_road": 1.0, "southwest_path": 0.5, "northeast_path": 0.5, "manhole_01": 0.3, "북쪽 야적장 길": 1.0, "서쪽 상회 샛길": 0.5, "동쪽 석탄 들길": 1.0, "manhole_02": 0.3}
const FIRST_ENTRY: String = "west_road"


static func build() -> Dictionary:
	var data: Dictionary = _build_plain()
	data["entry_names"] = ENTRY_NAMES.duplicate()
	data["entry_weights"] = ENTRY_WEIGHTS.duplicate()
	data["first_entry"] = FIRST_ENTRY
	return data
