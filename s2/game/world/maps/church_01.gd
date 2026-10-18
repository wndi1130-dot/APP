# 이 지도가 다른 판단을 만드는 것: 종을 치면 무리가 교회로 몰려 마을이 조용해지나 탑에 오른 사람은 내려올 길이 하나다.
# 위쪽의 판단: 밀가루 자루를 넉넉히 얻는 대신 무거운 자루를 여러 번 날라야 하고, 그동안 아래쪽 상징물 구역을 비워 두게 된다.
extends RefCounted

const FieldGrid = preload("res://game/world/field_grid.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const PLACE_ID: String = "church_01"
const WIDTH: int = 150
const SOUTH_HEIGHT: int = 90
const HEIGHT: int = SOUTH_HEIGHT + 45

# 각 방과 마당의 좌표는 이 지도에서만 쓰는 독립 평면이다.
# 종소리와 덧댄 문 해체는 자리만 남기며 여기서 실행하지 않는다.
const PLAN: Dictionary = {
	"id": "church_01",
	"size": [
		150,
		90
	],
	"names": {"A":"마을 어귀","B":"묘지 마당","C":"서쪽 농가 거리","D":"못가","E":"사제관 마당","F":"남동 헛간 마당"},
	"zones": [
		{"id":"A","rect":[0,0,150,90]},
		{"id":"B","rect":[55,35,76,50]},
		{"id":"C","rect":[0,36,55,29]},
		{"id":"D","rect":[0,65,47,25]},
		{"id":"E","rect":[131,30,19,35]},
		{"id":"F","rect":[47,65,103,25]},
		{"id":"B","rect":[60,40,65,29]}
	],
	"ground": [
		{"rect":[60,36,65,44],"kind":"GRAVEL"},
		{"rect":[0,63,47,27],"kind":"DEEP_SNOW"},
		{"rect":[0,10,18,24],"kind":"DEEP_SNOW"},
		{"rect":[118,10,32,20],"kind":"DEEP_SNOW"},
		{"rect":[126,60,24,25],"kind":"GRAVEL"},
		{"rect":[0,30,63,6],"kind":"ROAD"},
		{"rect":[38,10,5,25],"kind":"ROAD"},
		{"rect":[55,35,5,50],"kind":"ROAD"},
		{"rect":[55,35,76,5],"kind":"ROAD"},
		{"rect":[126,35,5,50],"kind":"ROAD"},
		{"rect":[55,80,76,5],"kind":"ROAD"},
		{"rect":[0,57,60,5],"kind":"ROAD"},
		{"rect":[94,80,6,10],"kind":"ROAD"},
		{"rect":[130,64,20,5],"kind":"ROAD"},
		{"rect":[130,64,5,20],"kind":"ROAD"}
	],
	"buildings": [
		{"id":0,"name":"교회 본당","rect":[72,42,42,26],"warm":true,"window_broken":false},
		{"id":1,"name":"종탑","rect":[60,43,10,10],"warm":false,"window_broken":false},
		{"id":2,"name":"종지기 집","rect":[116,57,8,6],"warm":false,"window_broken":false},
		{"id":3,"name":"묘지 도구 창고","rect":[116,41,8,6],"warm":false,"window_broken":false},
		{"id":4,"name":"사제관","rect":[132,42,14,14],"warm":false,"window_broken":false},
		{"id":5,"name":"헛간","rect":[84,18,16,10],"warm":false,"window_broken":false},
		{"id":6,"name":"빵집","rect":[24,36,14,12],"warm":false,"window_broken":false},
		{"id":7,"name":"농가 가","rect":[64,16,16,12],"warm":false,"window_broken":false},
		{"id":8,"name":"농가 나","rect":[4,17,14,12],"warm":false,"window_broken":false},
		{"id":9,"name":"농가 다","rect":[39,43,14,12],"warm":false,"window_broken":false},
		{"id":10,"name":"농가 라","rect":[4,70,14,12],"warm":false,"window_broken":false},
		{"id":11,"name":"외양간","rect":[47,66,14,10],"warm":false,"window_broken":false},
		{"id":12,"name":"장작 창고","rect":[44,18,14,10],"warm":false,"window_broken":false},
		{"id":13,"name":"곡물 창고","rect":[91,69,18,10],"warm":false,"window_broken":false},
		{"id":14,"name":"우물집","rect":[27,50,6,6],"warm":false,"window_broken":false},
		{"id":15,"name":"수레 헛간","rect":[132,69,12,8],"warm":false,"window_broken":false}
	],
	"shells": [
		{"building":0,"level":0,"rect":[72,42,42,26]},
		{"building":0,"level":1,"rect":[72,42,8,26]},
		{"building":0,"level":-1,"rect":[90,42,24,26]},
		{"building":1,"level":0,"rect":[60,43,10,10]},
		{"building":1,"level":1,"rect":[60,43,10,10]},
		{"building":1,"level":2,"rect":[60,43,10,10]},
		{"building":2,"level":0,"rect":[116,57,8,6]},
		{"building":3,"level":0,"rect":[116,41,8,6]},
		{"building":4,"level":0,"rect":[132,42,14,14]},
		{"building":4,"level":1,"rect":[132,42,14,14]},
		{"building":5,"level":0,"rect":[84,18,16,10]},
		{"building":6,"level":0,"rect":[24,36,14,12]},
		{"building":6,"level":1,"rect":[24,36,14,12]},
		{"building":7,"level":0,"rect":[64,16,16,12]},
		{"building":7,"level":1,"rect":[64,16,16,12]},
		{"building":8,"level":0,"rect":[4,17,14,12]},
		{"building":9,"level":0,"rect":[39,43,14,12]},
		{"building":9,"level":1,"rect":[39,43,14,12]},
		{"building":10,"level":0,"rect":[4,70,14,12]},
		{"building":11,"level":0,"rect":[47,66,14,10]},
		{"building":12,"level":0,"rect":[44,18,14,10]},
		{"building":13,"level":0,"rect":[91,69,18,10]},
		{"building":14,"level":0,"rect":[27,50,6,6]},
		{"building":15,"level":0,"rect":[132,69,12,8]}
	],
	"walls": [
		{"level":0,"rect":[73,48,40,1]},
		{"level":0,"rect":[73,61,40,1]},
		{"level":0,"rect":[80,43,1,5]},
		{"level":0,"rect":[80,62,1,5]},
		{"level":0,"rect":[88,43,1,5]},
		{"level":0,"rect":[88,62,1,5]},
		{"level":0,"rect":[96,43,1,5]},
		{"level":0,"rect":[96,62,1,5]},
		{"level":0,"rect":[104,43,1,5]},
		{"level":0,"rect":[104,62,1,5]},
		{"level":1,"rect":[73,55,6,1]},
		{"level":-1,"rect":[93,45,18,1]},
		{"level":-1,"rect":[93,64,18,1]},
		{"level":-1,"rect":[93,45,1,20]},
		{"level":-1,"rect":[110,45,1,20]},
		{"level":-1,"rect":[102,46,1,18]},
		{"level":0,"rect":[64,44,1,8]},
		{"level":1,"rect":[64,44,1,8]},
		{"level":2,"rect":[64,44,1,8]},
		{"level":0,"rect":[133,47,12,1]},
		{"level":0,"rect":[133,50,12,1]},
		{"level":1,"rect":[133,47,12,1]},
		{"level":1,"rect":[133,50,12,1]},
		{"level":0,"rect":[92,19,1,8]},
		{"level":0,"rect":[25,40,12,1]},
		{"level":0,"rect":[25,43,12,1]},
		{"level":1,"rect":[25,40,12,1]},
		{"level":1,"rect":[25,43,12,1]},
		{"level":0,"rect":[65,20,14,1]},
		{"level":0,"rect":[65,23,14,1]},
		{"level":1,"rect":[65,20,14,1]},
		{"level":1,"rect":[65,23,14,1]},
		{"level":0,"rect":[5,21,12,1]},
		{"level":0,"rect":[5,24,12,1]},
		{"level":0,"rect":[40,47,12,1]},
		{"level":0,"rect":[40,50,12,1]},
		{"level":1,"rect":[40,47,12,1]},
		{"level":1,"rect":[40,50,12,1]},
		{"level":0,"rect":[5,74,12,1]},
		{"level":0,"rect":[5,77,12,1]},
		{"level":0,"rect":[54,67,1,8]},
		{"level":0,"rect":[51,19,1,8]},
		{"level":0,"rect":[100,70,1,8]}
	],
	"doors": [
		{"building":0,"level":0,"cell":[76,48],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[76,61],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[84,48],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[84,61],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[92,48],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[92,61],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[100,48],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[100,61],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[109,48],"side":[0,1],"state":"closed","outer":false},
		{"building":0,"level":0,"cell":[109,61],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[72,55],"side":[-1,0],"state":"open","outer":true},
		{"building":0,"level":0,"cell":[113,55],"side":[1,0],"state":"open","outer":true},
		{"building":0,"level":1,"cell":[75,55],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":-1,"cell":[93,55],"side":[-1,0],"state":"open","outer":false},
		{"building":0,"level":-1,"cell":[110,55],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":0,"cell":[64,50],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":1,"cell":[64,50],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":2,"cell":[64,50],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":0,"cell":[68,52],"side":[0,1],"state":"open","outer":true},
		{"building":2,"level":0,"cell":[116,60],"side":[-1,0],"state":"open","outer":true},
		{"building":3,"level":0,"cell":[116,44],"side":[-1,0],"state":"open","outer":true},
		{"building":4,"level":0,"cell":[139,47],"side":[0,1],"state":"open","outer":false},
		{"building":4,"level":0,"cell":[139,50],"side":[0,-1],"state":"open","outer":false},
		{"building":4,"level":0,"cell":[132,48],"side":[-1,0],"state":"open","outer":true},
		{"building":4,"level":0,"cell":[145,48],"side":[1,0],"state":"open","outer":true},
		{"building":4,"level":1,"cell":[139,47],"side":[0,1],"state":"open","outer":false},
		{"building":4,"level":1,"cell":[139,50],"side":[0,-1],"state":"open","outer":false},
		{"building":5,"level":0,"cell":[92,23],"side":[1,0],"state":"open","outer":false},
		{"building":5,"level":0,"cell":[84,23],"side":[-1,0],"state":"open","outer":true},
		{"building":5,"level":0,"cell":[99,23],"side":[1,0],"state":"open","outer":true},
		{"building":6,"level":0,"cell":[31,40],"side":[0,1],"state":"open","outer":false},
		{"building":6,"level":0,"cell":[31,43],"side":[0,-1],"state":"open","outer":false},
		{"building":6,"level":0,"cell":[24,41],"side":[-1,0],"state":"open","outer":true},
		{"building":6,"level":0,"cell":[37,41],"side":[1,0],"state":"open","outer":true},
		{"building":6,"level":1,"cell":[31,40],"side":[0,1],"state":"open","outer":false},
		{"building":6,"level":1,"cell":[31,43],"side":[0,-1],"state":"open","outer":false},
		{"building":7,"level":0,"cell":[72,20],"side":[0,1],"state":"open","outer":false},
		{"building":7,"level":0,"cell":[72,23],"side":[0,-1],"state":"open","outer":false},
		{"building":7,"level":0,"cell":[64,21],"side":[-1,0],"state":"open","outer":true},
		{"building":7,"level":0,"cell":[79,21],"side":[1,0],"state":"open","outer":true},
		{"building":7,"level":1,"cell":[72,20],"side":[0,1],"state":"open","outer":false},
		{"building":7,"level":1,"cell":[72,23],"side":[0,-1],"state":"open","outer":false},
		{"building":8,"level":0,"cell":[11,21],"side":[0,1],"state":"open","outer":false},
		{"building":8,"level":0,"cell":[11,24],"side":[0,-1],"state":"open","outer":false},
		{"building":8,"level":0,"cell":[4,22],"side":[-1,0],"state":"open","outer":true},
		{"building":8,"level":0,"cell":[17,22],"side":[1,0],"state":"open","outer":true},
		{"building":9,"level":0,"cell":[46,47],"side":[0,1],"state":"open","outer":false},
		{"building":9,"level":0,"cell":[46,50],"side":[0,-1],"state":"open","outer":false},
		{"building":9,"level":0,"cell":[39,48],"side":[-1,0],"state":"open","outer":true},
		{"building":9,"level":0,"cell":[52,48],"side":[1,0],"state":"open","outer":true},
		{"building":9,"level":1,"cell":[46,47],"side":[0,1],"state":"open","outer":false},
		{"building":9,"level":1,"cell":[46,50],"side":[0,-1],"state":"open","outer":false},
		{"building":10,"level":0,"cell":[11,74],"side":[0,1],"state":"open","outer":false},
		{"building":10,"level":0,"cell":[11,77],"side":[0,-1],"state":"open","outer":false},
		{"building":10,"level":0,"cell":[4,75],"side":[-1,0],"state":"open","outer":true},
		{"building":10,"level":0,"cell":[17,75],"side":[1,0],"state":"open","outer":true},
		{"building":11,"level":0,"cell":[54,71],"side":[1,0],"state":"open","outer":false},
		{"building":11,"level":0,"cell":[47,71],"side":[-1,0],"state":"open","outer":true},
		{"building":11,"level":0,"cell":[60,71],"side":[1,0],"state":"open","outer":true},
		{"building":12,"level":0,"cell":[51,23],"side":[1,0],"state":"open","outer":false},
		{"building":12,"level":0,"cell":[44,23],"side":[-1,0],"state":"open","outer":true},
		{"building":12,"level":0,"cell":[57,23],"side":[1,0],"state":"open","outer":true},
		{"building":13,"level":0,"cell":[100,74],"side":[1,0],"state":"open","outer":false},
		{"building":13,"level":0,"cell":[91,74],"side":[-1,0],"state":"open","outer":true},
		{"building":13,"level":0,"cell":[108,74],"side":[1,0],"state":"open","outer":true},
		{"building":14,"level":0,"cell":[27,53],"side":[-1,0],"state":"open","outer":true},
		{"building":15,"level":0,"cell":[132,73],"side":[-1,0],"state":"open","outer":true},
		{"building":15,"level":0,"cell":[143,73],"side":[1,0],"state":"open","outer":true}
	],
	"windows": [
		{"building":0,"level":0,"cell":[83,42],"broken":false},
		{"building":0,"level":0,"cell":[83,67],"broken":false},
		{"building":0,"level":0,"cell":[101,42],"broken":false},
		{"building":0,"level":0,"cell":[101,67],"broken":false},
		{"building":0,"level":0,"cell":[72,44],"broken":false},
		{"building":0,"level":1,"cell":[74,42],"broken":false},
		{"building":0,"level":1,"cell":[74,67],"broken":false},
		{"building":0,"level":1,"cell":[77,42],"broken":false},
		{"building":0,"level":1,"cell":[77,67],"broken":false},
		{"building":0,"level":1,"cell":[72,44],"broken":false},
		{"building":1,"level":0,"cell":[63,43],"broken":false},
		{"building":1,"level":0,"cell":[63,52],"broken":false},
		{"building":1,"level":0,"cell":[66,43],"broken":false},
		{"building":1,"level":0,"cell":[66,52],"broken":false},
		{"building":1,"level":0,"cell":[60,45],"broken":false},
		{"building":1,"level":1,"cell":[63,43],"broken":false},
		{"building":1,"level":1,"cell":[63,52],"broken":false},
		{"building":1,"level":1,"cell":[66,43],"broken":false},
		{"building":1,"level":1,"cell":[66,52],"broken":false},
		{"building":1,"level":1,"cell":[60,45],"broken":false},
		{"building":1,"level":2,"cell":[63,43],"broken":false},
		{"building":1,"level":2,"cell":[63,52],"broken":false},
		{"building":1,"level":2,"cell":[66,43],"broken":false},
		{"building":1,"level":2,"cell":[66,52],"broken":false},
		{"building":1,"level":2,"cell":[60,45],"broken":false},
		{"building":2,"level":0,"cell":[118,57],"broken":false},
		{"building":2,"level":0,"cell":[118,62],"broken":false},
		{"building":2,"level":0,"cell":[121,57],"broken":false},
		{"building":2,"level":0,"cell":[121,62],"broken":false},
		{"building":2,"level":0,"cell":[116,59],"broken":false},
		{"building":3,"level":0,"cell":[118,41],"broken":false},
		{"building":3,"level":0,"cell":[118,46],"broken":false},
		{"building":3,"level":0,"cell":[121,41],"broken":false},
		{"building":3,"level":0,"cell":[121,46],"broken":false},
		{"building":3,"level":0,"cell":[116,43],"broken":false},
		{"building":4,"level":0,"cell":[136,42],"broken":false},
		{"building":4,"level":0,"cell":[136,55],"broken":false},
		{"building":4,"level":0,"cell":[141,42],"broken":false},
		{"building":4,"level":0,"cell":[141,55],"broken":false},
		{"building":4,"level":0,"cell":[132,44],"broken":false},
		{"building":4,"level":1,"cell":[136,42],"broken":false},
		{"building":4,"level":1,"cell":[136,55],"broken":false},
		{"building":4,"level":1,"cell":[141,42],"broken":false},
		{"building":4,"level":1,"cell":[141,55],"broken":false},
		{"building":4,"level":1,"cell":[132,44],"broken":false},
		{"building":5,"level":0,"cell":[88,18],"broken":false},
		{"building":5,"level":0,"cell":[88,27],"broken":false},
		{"building":5,"level":0,"cell":[95,18],"broken":false},
		{"building":5,"level":0,"cell":[95,27],"broken":false},
		{"building":5,"level":0,"cell":[84,20],"broken":false},
		{"building":6,"level":0,"cell":[28,36],"broken":false},
		{"building":6,"level":0,"cell":[28,47],"broken":false},
		{"building":6,"level":0,"cell":[33,36],"broken":false},
		{"building":6,"level":0,"cell":[33,47],"broken":false},
		{"building":6,"level":0,"cell":[24,38],"broken":false},
		{"building":6,"level":1,"cell":[28,36],"broken":false},
		{"building":6,"level":1,"cell":[28,47],"broken":false},
		{"building":6,"level":1,"cell":[33,36],"broken":false},
		{"building":6,"level":1,"cell":[33,47],"broken":false},
		{"building":6,"level":1,"cell":[24,38],"broken":false},
		{"building":7,"level":0,"cell":[68,16],"broken":false},
		{"building":7,"level":0,"cell":[68,27],"broken":false},
		{"building":7,"level":0,"cell":[75,16],"broken":false},
		{"building":7,"level":0,"cell":[75,27],"broken":false},
		{"building":7,"level":0,"cell":[64,18],"broken":false},
		{"building":7,"level":1,"cell":[68,16],"broken":false},
		{"building":7,"level":1,"cell":[68,27],"broken":false},
		{"building":7,"level":1,"cell":[75,16],"broken":false},
		{"building":7,"level":1,"cell":[75,27],"broken":false},
		{"building":7,"level":1,"cell":[64,18],"broken":false},
		{"building":8,"level":0,"cell":[8,17],"broken":false},
		{"building":8,"level":0,"cell":[8,28],"broken":false},
		{"building":8,"level":0,"cell":[13,17],"broken":false},
		{"building":8,"level":0,"cell":[13,28],"broken":false},
		{"building":8,"level":0,"cell":[4,19],"broken":false},
		{"building":9,"level":0,"cell":[43,43],"broken":false},
		{"building":9,"level":0,"cell":[43,54],"broken":false},
		{"building":9,"level":0,"cell":[48,43],"broken":false},
		{"building":9,"level":0,"cell":[48,54],"broken":false},
		{"building":9,"level":0,"cell":[39,45],"broken":false},
		{"building":9,"level":1,"cell":[43,43],"broken":false},
		{"building":9,"level":1,"cell":[43,54],"broken":false},
		{"building":9,"level":1,"cell":[48,43],"broken":false},
		{"building":9,"level":1,"cell":[48,54],"broken":false},
		{"building":9,"level":1,"cell":[39,45],"broken":false},
		{"building":10,"level":0,"cell":[8,70],"broken":false},
		{"building":10,"level":0,"cell":[8,81],"broken":false},
		{"building":10,"level":0,"cell":[13,70],"broken":false},
		{"building":10,"level":0,"cell":[13,81],"broken":false},
		{"building":10,"level":0,"cell":[4,72],"broken":false},
		{"building":11,"level":0,"cell":[51,66],"broken":false},
		{"building":11,"level":0,"cell":[51,75],"broken":false},
		{"building":11,"level":0,"cell":[56,66],"broken":false},
		{"building":11,"level":0,"cell":[56,75],"broken":false},
		{"building":11,"level":0,"cell":[47,68],"broken":false},
		{"building":12,"level":0,"cell":[48,18],"broken":false},
		{"building":12,"level":0,"cell":[48,27],"broken":false},
		{"building":12,"level":0,"cell":[53,18],"broken":false},
		{"building":12,"level":0,"cell":[53,27],"broken":false},
		{"building":12,"level":0,"cell":[44,20],"broken":false},
		{"building":13,"level":0,"cell":[96,69],"broken":false},
		{"building":13,"level":0,"cell":[96,78],"broken":false},
		{"building":13,"level":0,"cell":[103,69],"broken":false},
		{"building":13,"level":0,"cell":[103,78],"broken":false},
		{"building":13,"level":0,"cell":[91,71],"broken":false},
		{"building":14,"level":0,"cell":[29,50],"broken":false},
		{"building":14,"level":0,"cell":[29,55],"broken":false},
		{"building":14,"level":0,"cell":[30,50],"broken":false},
		{"building":14,"level":0,"cell":[30,55],"broken":false},
		{"building":14,"level":0,"cell":[27,52],"broken":false},
		{"building":15,"level":0,"cell":[135,69],"broken":false},
		{"building":15,"level":0,"cell":[135,76],"broken":false},
		{"building":15,"level":0,"cell":[140,69],"broken":false},
		{"building":15,"level":0,"cell":[140,76],"broken":false},
		{"building":15,"level":0,"cell":[132,71],"broken":false}
	],
	"stairs": [
		{"cell":[73,44],"low":0,"high":1,"ladder":false},
		{"cell":[91,44],"low":-1,"high":0,"ladder":false},
		{"cell":[112,65],"low":-1,"high":0,"ladder":false},
		{"cell":[61,44],"low":0,"high":1,"ladder":false},
		{"cell":[68,51],"low":1,"high":2,"ladder":false},
		{"cell":[134,48],"low":0,"high":1,"ladder":false},
		{"cell":[26,41],"low":0,"high":1,"ladder":false},
		{"cell":[66,21],"low":0,"high":1,"ladder":false},
		{"cell":[41,48],"low":0,"high":1,"ladder":false}
	],
	"props": [
		{"kind":"bell_rope","rect":[62,46,1,1],"solid":"none","facing":0,"note":"종 줄 한 가닥","level":1},
		{"kind":"bell_frame","rect":[65,45,3,3],"solid":"none","facing":1,"note":"종을 거는 나무 틀","level":2},
		{"kind":"car","rect":[31,11,4,2],"solid":"low","facing":2,"note":"길가에 선 차","level":0},
		{"kind":"bench","rect":[50,12,3,1],"solid":"low","facing":3,"note":"긴 의자","level":0},
		{"kind":"crate_stack","rect":[66,12,2,2],"solid":"low","facing":0,"note":"나무 상자","level":0},
		{"kind":"firewood_pile","rect":[97,25,2,1],"solid":"low","facing":1,"note":"처마 밑 장작","level":0},
		{"kind":"water","rect":[21,67,22,20],"solid":"low","facing":2,"note":"언 물","level":0},
		{"kind":"fieldstone_wall","rect":[65,37,8,1],"solid":"low","facing":3,"note":"들돌 담 토막","level":0},
		{"kind":"fieldstone_wall","rect":[79,37,8,1],"solid":"low","facing":0,"note":"들돌 담 토막","level":0},
		{"kind":"fieldstone_wall","rect":[102,37,8,1],"solid":"low","facing":1,"note":"들돌 담 토막","level":0},
		{"kind":"fieldstone_wall","rect":[114,37,8,1],"solid":"low","facing":2,"note":"들돌 담 토막","level":0},
		{"kind":"fieldstone_wall","rect":[65,78,8,1],"solid":"low","facing":3,"note":"들돌 담 토막","level":0},
		{"kind":"fieldstone_wall","rect":[78,78,8,1],"solid":"low","facing":0,"note":"들돌 담 토막","level":0},
		{"kind":"fieldstone_wall","rect":[113,78,8,1],"solid":"low","facing":1,"note":"들돌 담 토막","level":0},
		{"kind":"grave_plot","rect":[67,69,4,3],"solid":"low","facing":2,"note":"눈 덮인 돌판의 낮은 돌 테두리","level":0},
		{"kind":"grave_plot","rect":[75,73,4,3],"solid":"low","facing":3,"note":"눈 덮인 돌판의 낮은 돌 테두리","level":0},
		{"kind":"grave_plot","rect":[115,69,4,3],"solid":"low","facing":0,"note":"눈 덮인 돌판의 낮은 돌 테두리","level":0},
		{"kind":"grave_slab","rect":[65,71,2,1],"solid":"none","facing":1,"note":"글씨와 무늬 없는 낮은 돌판","level":0},
		{"kind":"grave_slab","rect":[75,76,2,1],"solid":"none","facing":2,"note":"글씨와 무늬 없는 낮은 돌판","level":0},
		{"kind":"grave_slab","rect":[116,72,2,1],"solid":"none","facing":3,"note":"글씨와 무늬 없는 낮은 돌판","level":0},
		{"kind":"grave_slab","rect":[70,75,2,1],"solid":"none","facing":0,"note":"글씨와 무늬 없는 낮은 돌판","level":0},
		{"kind":"lamp_post","rect":[63,81,1,1],"solid":"none","facing":1,"note":"꺼진 등잔 기둥","level":0},
		{"kind":"crate_stack","rect":[67,85,2,2],"solid":"low","facing":2,"note":"나무 상자","level":0},
		{"kind":"snow_drift","rect":[59,85,4,2],"solid":"none","facing":3,"note":"모서리의 눈더미","level":0},
		{"kind":"shop_awning","rect":[26,33,3,1],"solid":"none","facing":0,"note":"가게 차양","level":0},
		{"kind":"car","rect":[111,81,4,2],"solid":"low","facing":1,"note":"길가에 선 차","level":0},
		{"kind":"car","rect":[118,82,4,2],"solid":"low","facing":2,"note":"길가에 선 차","level":0},
		{"kind":"bare_tree","rect":[15,29,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[4,37,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[6,56,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[23,55,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[26,63,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[3,65,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[18,86,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[45,85,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[50,83,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[54,79,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[68,87,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[82,86,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[110,88,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[145,82,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[145,74,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[148,59,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[136,59,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[139,32,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[142,29,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[146,20,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[132,17,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[121,20,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[108,18,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[110,22,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[109,27,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[114,25,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[124,52,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[122,65,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[63,77,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[121,76,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"hymn_shelf","rect":[73,43,2,1],"solid":"low","facing":1,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[79,47,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[73,47,2,1],"solid":"low","facing":3,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[79,43,1,1],"solid":"low","facing":0,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[78,66,2,1],"solid":"low","facing":1,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[73,66,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[78,62,2,1],"solid":"low","facing":3,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[74,62,1,1],"solid":"low","facing":0,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[81,47,2,1],"solid":"low","facing":1,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[87,43,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[82,43,2,1],"solid":"low","facing":3,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[86,47,1,1],"solid":"low","facing":0,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[86,62,2,1],"solid":"low","facing":1,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[82,62,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[85,66,2,1],"solid":"low","facing":3,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[81,62,1,1],"solid":"low","facing":0,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[90,43,2,1],"solid":"low","facing":1,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[94,47,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[89,47,2,1],"solid":"low","facing":3,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[95,47,1,1],"solid":"low","facing":0,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[93,66,2,1],"solid":"low","facing":1,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[89,62,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[89,66,2,1],"solid":"low","facing":3,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[95,62,1,1],"solid":"low","facing":0,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[97,43,2,1],"solid":"low","facing":1,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[103,47,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[97,47,2,1],"solid":"low","facing":3,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[103,43,1,1],"solid":"low","facing":0,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[102,66,2,1],"solid":"low","facing":1,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[97,66,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[102,62,2,1],"solid":"low","facing":3,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[98,62,1,1],"solid":"low","facing":0,"note":"글씨 없는 손종","level":0},
		{"kind":"parish_chest","rect":[105,47,2,1],"solid":"low","facing":1,"note":"회중 기록 궤","level":0},
		{"kind":"hymn_shelf","rect":[111,43,2,1],"solid":"low","facing":2,"note":"찬송집 선반","level":0},
		{"kind":"desk","rect":[106,43,2,1],"solid":"low","facing":3,"note":"책상","level":0},
		{"kind":"candle_stand","rect":[111,47,1,1],"solid":"low","facing":0,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"hymn_shelf","rect":[111,62,2,1],"solid":"low","facing":1,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[106,62,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[110,66,2,1],"solid":"low","facing":3,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[105,62,1,1],"solid":"low","facing":0,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[76,54,2,1],"solid":"none","facing":1,"note":"찬송집 선반","level":1},
		{"kind":"candle_stand","rect":[73,43,1,1],"solid":"none","facing":2,"note":"초 하나가 선 외줄기 촛대","level":1},
		{"kind":"vestry_chest","rect":[73,54,2,1],"solid":"none","facing":3,"note":"제의실 궤","level":1},
		{"kind":"hand_bell","rect":[78,43,1,1],"solid":"none","facing":0,"note":"글씨 없는 손종","level":1},
		{"kind":"hymn_shelf","rect":[73,56,2,1],"solid":"none","facing":1,"note":"찬송집 선반","level":1},
		{"kind":"candle_stand","rect":[78,66,1,1],"solid":"none","facing":2,"note":"초 하나가 선 외줄기 촛대","level":1},
		{"kind":"vestry_chest","rect":[73,66,2,1],"solid":"none","facing":3,"note":"제의실 궤","level":1},
		{"kind":"hand_bell","rect":[78,56,1,1],"solid":"none","facing":0,"note":"글씨 없는 손종","level":1},
		{"kind":"cold_stove","rect":[101,63,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":-1},
		{"kind":"coal_bin","rect":[94,62,3,2],"solid":"none","facing":2,"note":"난방용 석탄","level":-1},
		{"kind":"firewood_pile","rect":[100,46,2,1],"solid":"none","facing":3,"note":"처마 밑 장작","level":-1},
		{"kind":"barrel","rect":[95,46,1,1],"solid":"none","facing":0,"note":"저장 통","level":-1},
		{"kind":"cask_stack","rect":[103,62,2,2],"solid":"none","facing":1,"note":"저장고 큰 통","level":-1},
		{"kind":"sack_pile","rect":[108,46,2,2],"solid":"none","facing":2,"note":"곡물 자루","level":-1},
		{"kind":"relief_crate","rect":[104,46,2,1],"solid":"none","facing":3,"note":"남은 구호 식량 상자","level":-1},
		{"kind":"barrel","rect":[108,63,1,1],"solid":"none","facing":0,"note":"저장 통","level":-1},
		{"kind":"hand_bell","rect":[62,44,1,1],"solid":"low","facing":1,"note":"글씨 없는 손종","level":0},
		{"kind":"lamp_shelf","rect":[61,51,2,1],"solid":"low","facing":2,"note":"꺼진 등잔 선반","level":0},
		{"kind":"candle_stand","rect":[63,51,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"hand_bell","rect":[67,51,1,1],"solid":"low","facing":0,"note":"글씨 없는 손종","level":0},
		{"kind":"lamp_shelf","rect":[65,44,2,1],"solid":"low","facing":1,"note":"꺼진 등잔 선반","level":0},
		{"kind":"candle_stand","rect":[65,51,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"hand_bell","rect":[63,51,1,1],"solid":"none","facing":3,"note":"글씨 없는 손종","level":1},
		{"kind":"lamp_shelf","rect":[61,51,2,1],"solid":"none","facing":0,"note":"꺼진 등잔 선반","level":1},
		{"kind":"candle_stand","rect":[63,44,1,1],"solid":"none","facing":1,"note":"초 하나가 선 외줄기 촛대","level":1},
		{"kind":"hand_bell","rect":[65,51,1,1],"solid":"none","facing":2,"note":"글씨 없는 손종","level":1},
		{"kind":"lamp_shelf","rect":[67,44,2,1],"solid":"none","facing":3,"note":"꺼진 등잔 선반","level":1},
		{"kind":"candle_stand","rect":[66,44,1,1],"solid":"none","facing":0,"note":"초 하나가 선 외줄기 촛대","level":1},
		{"kind":"hand_bell","rect":[61,51,1,1],"solid":"none","facing":1,"note":"글씨 없는 손종","level":2},
		{"kind":"lamp_shelf","rect":[62,44,2,1],"solid":"none","facing":2,"note":"꺼진 등잔 선반","level":2},
		{"kind":"candle_stand","rect":[62,51,1,1],"solid":"none","facing":3,"note":"초 하나가 선 외줄기 촛대","level":2},
		{"kind":"hand_bell","rect":[68,44,1,1],"solid":"none","facing":0,"note":"글씨 없는 손종","level":2},
		{"kind":"lamp_shelf","rect":[66,44,2,1],"solid":"none","facing":1,"note":"꺼진 등잔 선반","level":2},
		{"kind":"bench","rect":[65,51,3,1],"solid":"none","facing":2,"note":"긴 의자","level":2},
		{"kind":"candle_stand","rect":[65,44,1,1],"solid":"none","facing":3,"note":"초 하나가 선 외줄기 촛대","level":2},
		{"kind":"bed","rect":[118,58,2,1],"solid":"low","facing":0,"note":"침대","level":0},
		{"kind":"desk","rect":[120,61,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[117,58,1,1],"solid":"low","facing":2,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[117,61,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"shelf","rect":[119,45,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"crate_stack","rect":[117,42,2,2],"solid":"low","facing":1,"note":"나무 상자","level":0},
		{"kind":"barrel","rect":[122,45,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"handcart","rect":[117,45,2,1],"solid":"low","facing":3,"note":"뒷문 곁 손수레","level":0},
		{"kind":"bed","rect":[133,43,2,1],"solid":"low","facing":0,"note":"침대","level":0},
		{"kind":"desk","rect":[143,46,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[133,46,1,1],"solid":"low","facing":2,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[142,43,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[143,54,2,1],"solid":"low","facing":0,"note":"침대","level":0},
		{"kind":"desk","rect":[133,54,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[144,51,1,1],"solid":"low","facing":2,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[134,51,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[133,46,2,1],"solid":"none","facing":0,"note":"침대","level":1},
		{"kind":"desk","rect":[143,43,2,1],"solid":"none","facing":1,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[134,43,1,1],"solid":"none","facing":2,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[141,46,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[143,51,2,1],"solid":"none","facing":0,"note":"침대","level":1},
		{"kind":"desk","rect":[134,51,2,1],"solid":"none","facing":1,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[143,54,1,1],"solid":"none","facing":2,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[133,54,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"bread_rack","rect":[25,37,1,1],"solid":"low","facing":0,"note":"빵 선반","level":0},
		{"kind":"bread_rack","rect":[36,39,1,1],"solid":"low","facing":1,"note":"빵 선반","level":0},
		{"kind":"dough_table","rect":[25,39,2,1],"solid":"low","facing":2,"note":"반죽대","level":0},
		{"kind":"sack_pile","rect":[35,37,2,2],"solid":"low","facing":3,"note":"곡물 자루","level":0},
		{"kind":"bread_rack","rect":[36,46,1,1],"solid":"low","facing":0,"note":"빵 선반","level":0},
		{"kind":"dough_table","rect":[35,44,2,1],"solid":"low","facing":2,"note":"반죽대","level":0},
		{"kind":"sack_pile","rect":[26,44,2,2],"solid":"low","facing":3,"note":"곡물 자루","level":0},
		{"kind":"bed","rect":[25,39,2,1],"solid":"none","facing":0,"note":"침대","level":1},
		{"kind":"desk","rect":[35,37,2,1],"solid":"none","facing":1,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[26,37,1,1],"solid":"none","facing":2,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[33,39,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[35,44,2,1],"solid":"none","facing":0,"note":"침대","level":1},
		{"kind":"desk","rect":[26,44,2,1],"solid":"none","facing":1,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[35,46,1,1],"solid":"none","facing":2,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[25,46,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[65,17,2,1],"solid":"none","facing":0,"note":"침대","level":1},
		{"kind":"desk","rect":[77,19,2,1],"solid":"none","facing":1,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[65,19,1,1],"solid":"none","facing":2,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[76,17,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[77,26,2,1],"solid":"none","facing":0,"note":"침대","level":1},
		{"kind":"desk","rect":[65,26,2,1],"solid":"none","facing":1,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[78,24,1,1],"solid":"none","facing":2,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[66,24,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[41,44,2,1],"solid":"low","facing":0,"note":"침대","level":0},
		{"kind":"desk","rect":[49,46,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[40,44,1,1],"solid":"low","facing":2,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[40,46,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[49,53,2,1],"solid":"low","facing":0,"note":"침대","level":0},
		{"kind":"desk","rect":[40,51,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[51,53,1,1],"solid":"low","facing":2,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[40,53,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[40,44,2,1],"solid":"none","facing":0,"note":"침대","level":1},
		{"kind":"desk","rect":[50,46,2,1],"solid":"none","facing":1,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[40,46,1,1],"solid":"none","facing":2,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[49,44,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[50,53,2,1],"solid":"none","facing":0,"note":"침대","level":1},
		{"kind":"desk","rect":[40,53,2,1],"solid":"none","facing":1,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[51,51,1,1],"solid":"none","facing":2,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[41,51,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[5,73,2,1],"solid":"low","facing":0,"note":"침대","level":0},
		{"kind":"desk","rect":[15,71,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[6,71,1,1],"solid":"low","facing":2,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[13,73,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[15,78,2,1],"solid":"low","facing":0,"note":"침대","level":0},
		{"kind":"desk","rect":[6,78,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[15,80,1,1],"solid":"low","facing":2,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[5,80,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"shelf","rect":[49,67,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"crate_stack","rect":[51,73,2,2],"solid":"low","facing":1,"note":"나무 상자","level":0},
		{"kind":"barrel","rect":[48,67,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"handcart","rect":[48,74,2,1],"solid":"low","facing":3,"note":"뒷문 곁 손수레","level":0},
		{"kind":"shelf","rect":[56,74,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"crate_stack","rect":[55,67,2,2],"solid":"low","facing":1,"note":"나무 상자","level":0},
		{"kind":"barrel","rect":[59,74,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"handcart","rect":[58,67,2,1],"solid":"low","facing":3,"note":"뒷문 곁 손수레","level":0},
		{"kind":"cask_stack","rect":[92,76,2,2],"solid":"low","facing":0,"note":"저장고 큰 통","level":0},
		{"kind":"sack_pile","rect":[98,70,2,2],"solid":"low","facing":1,"note":"곡물 자루","level":0},
		{"kind":"relief_crate","rect":[93,70,2,1],"solid":"low","facing":2,"note":"남은 구호 식량 상자","level":0},
		{"kind":"barrel","rect":[98,77,1,1],"solid":"low","facing":3,"note":"저장 통","level":0},
		{"kind":"cask_stack","rect":[106,70,2,2],"solid":"low","facing":0,"note":"저장고 큰 통","level":0},
		{"kind":"sack_pile","rect":[102,70,2,2],"solid":"low","facing":1,"note":"곡물 자루","level":0},
		{"kind":"relief_crate","rect":[105,77,2,1],"solid":"low","facing":2,"note":"남은 구호 식량 상자","level":0},
		{"kind":"barrel","rect":[101,70,1,1],"solid":"low","facing":3,"note":"저장 통","level":0},
		{"kind":"bed","rect":[29,51,2,1],"solid":"low","facing":0,"note":"침대","level":0},
		{"kind":"desk","rect":[29,54,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[28,51,1,1],"solid":"low","facing":2,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[139,75,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"crate_stack","rect":[133,70,2,2],"solid":"low","facing":0,"note":"나무 상자","level":0},
		{"kind":"barrel","rect":[142,75,1,1],"solid":"low","facing":1,"note":"저장 통","level":0},
		{"kind":"handcart","rect":[133,75,2,1],"solid":"low","facing":2,"note":"뒷문 곁 손수레","level":0},
		{"kind":"shop_counter","rect":[26,37,3,1],"solid":"low","facing":1,"note":"가게 계산대","level":0},
		{"kind":"display_shelf","rect":[25,38,4,1],"solid":"low","facing":2,"note":"가게 진열대","level":0},
		{"kind":"bread_rack","rect":[29,37,1,1],"solid":"low","facing":3,"note":"빵 선반","level":0},
		{"kind":"bread_rack","rect":[30,37,1,1],"solid":"low","facing":0,"note":"빵 선반","level":0},
		{"kind":"dough_table","rect":[32,37,2,1],"solid":"low","facing":1,"note":"반죽대","level":0},
		{"kind":"community_banner","rect":[5,71,1,2],"solid":"none","facing":3,"note":"무늬 없는 바랜 천 깃발","level":0},
		{"kind":"hand_bell","rect":[42,44,1,1],"solid":"none","facing":0,"note":"글씨 없는 손종","level":1},
		{"kind":"hymn_shelf","rect":[27,37,2,1],"solid":"none","facing":1,"note":"찬송집 선반","level":1},
		{"kind":"pew_row","rect":[77,49,6,1],"solid":"low","facing":0,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[101,49,6,1],"solid":"low","facing":1,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[77,51,6,1],"solid":"low","facing":2,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[101,51,6,1],"solid":"low","facing":3,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[74,53,6,1],"solid":"low","facing":0,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[97,53,6,1],"solid":"low","facing":1,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[76,55,6,1],"solid":"low","facing":2,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[97,55,6,1],"solid":"low","facing":3,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[74,57,6,1],"solid":"low","facing":0,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[97,57,6,1],"solid":"low","facing":1,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"bread_rack","rect":[25,44,1,1],"solid":"low","facing":1,"note":"빵 선반","level":0},
		{"kind":"bare_tree","rect":[106,27,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"altar_table","rect":[106,50,3,1],"solid":"low","facing":2,"note":"무늬 없는 천을 덮은 제단 탁자","level":0},
		{"kind":"pulpit","rect":[110,50,2,2],"solid":"low","facing":3,"note":"설교단","level":0},
		{"kind":"candle_stand","rect":[105,50,1,1],"solid":"low","facing":0,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"candle_stand","rect":[104,50,1,1],"solid":"low","facing":1,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"community_banner","rect":[108,51,1,2],"solid":"none","facing":2,"note":"무늬 없는 바랜 천 깃발","level":0},
		{"kind":"lamp_shelf","rect":[66,87,2,1],"solid":"low","facing":3,"note":"맨홀 곁 꺼진 등잔","level":0},
		{"kind":"crate_stack","rect":[60,78,2,2],"solid":"low","facing":0,"note":"맨홀 곁 나무 상자","level":0}
	],
	"rooms": [
		{"building":0,"level":0,"rect":[73,43,7,5],"name":"찬송집 방","theme":"church"},
		{"building":0,"level":0,"rect":[73,62,7,5],"name":"종지기 방","theme":"church"},
		{"building":0,"level":0,"rect":[81,43,7,5],"name":"현관 방","theme":"church"},
		{"building":0,"level":0,"rect":[81,62,7,5],"name":"옆 예배실","theme":"church"},
		{"building":0,"level":0,"rect":[89,43,7,5],"name":"제의실","theme":"church"},
		{"building":0,"level":0,"rect":[89,62,7,5],"name":"회중 준비방","theme":"church"},
		{"building":0,"level":0,"rect":[97,43,7,5],"name":"교구 사무방","theme":"church"},
		{"building":0,"level":0,"rect":[97,62,7,5],"name":"성가대방","theme":"church"},
		{"building":0,"level":0,"rect":[105,43,8,5],"name":"기록방","theme":"archive"},
		{"building":0,"level":0,"rect":[105,62,8,5],"name":"안쪽 저장실","theme":"church"},
		{"building":0,"level":0,"rect":[73,49,40,12],"name":"회중석","theme":"nave"},
		{"building":0,"level":1,"rect":[73,43,6,12],"name":"합창 다락 앞방","theme":"church"},
		{"building":0,"level":1,"rect":[73,56,6,11],"name":"합창 다락 뒷방","theme":"church"},
		{"building":0,"level":-1,"rect":[94,46,8,18],"name":"난방실","theme":"heat"},
		{"building":0,"level":-1,"rect":[103,46,7,18],"name":"막다른 식량 저장실","theme":"cellar"},
		{"building":0,"level":-1,"rect":[91,43,22,2],"name":"저장고 둘레 통로","theme":"corridor"},
		{"building":1,"level":0,"rect":[61,44,3,8],"name":"탑 아래 앞방","theme":"tower"},
		{"building":1,"level":0,"rect":[65,44,4,8],"name":"탑 아래 뒷방","theme":"tower"},
		{"building":1,"level":1,"rect":[61,44,3,8],"name":"종 줄 방","theme":"tower"},
		{"building":1,"level":1,"rect":[65,44,4,8],"name":"종 줄 방의 돌아가는 길","theme":"tower"},
		{"building":1,"level":2,"rect":[61,44,3,8],"name":"종 다락 앞방","theme":"tower"},
		{"building":1,"level":2,"rect":[65,44,4,8],"name":"종 다락","theme":"tower"},
		{"building":2,"level":0,"rect":[117,58,6,4],"name":"종지기 집 안방","theme":"home"},
		{"building":3,"level":0,"rect":[117,42,6,4],"name":"묘지 도구 창고 안방","theme":"store"},
		{"building":4,"level":0,"rect":[133,43,12,4],"name":"사제관 앞방","theme":"home"},
		{"building":4,"level":0,"rect":[133,51,12,4],"name":"사제관 뒷방","theme":"home"},
		{"building":4,"level":1,"rect":[133,43,12,4],"name":"사제관 앞방","theme":"home"},
		{"building":4,"level":1,"rect":[133,51,12,4],"name":"사제관 뒷방","theme":"home"},
		{"building":5,"level":0,"rect":[85,19,7,8],"name":"헛간 앞방","theme":"store"},
		{"building":5,"level":0,"rect":[93,19,6,8],"name":"헛간 뒷방","theme":"store"},
		{"building":6,"level":0,"rect":[25,37,12,3],"name":"빵집 앞방","theme":"bakery"},
		{"building":6,"level":0,"rect":[25,44,12,3],"name":"빵집 뒷방","theme":"bakery"},
		{"building":6,"level":1,"rect":[25,37,12,3],"name":"빵집 앞방","theme":"home"},
		{"building":6,"level":1,"rect":[25,44,12,3],"name":"빵집 뒷방","theme":"home"},
		{"building":7,"level":0,"rect":[65,17,14,3],"name":"농가 가 앞방","theme":"home"},
		{"building":7,"level":0,"rect":[65,24,14,3],"name":"농가 가 뒷방","theme":"home"},
		{"building":7,"level":1,"rect":[65,17,14,3],"name":"농가 가 앞방","theme":"home"},
		{"building":7,"level":1,"rect":[65,24,14,3],"name":"농가 가 뒷방","theme":"home"},
		{"building":8,"level":0,"rect":[5,18,12,3],"name":"농가 나 앞방","theme":"home"},
		{"building":8,"level":0,"rect":[5,25,12,3],"name":"농가 나 뒷방","theme":"home"},
		{"building":9,"level":0,"rect":[40,44,12,3],"name":"농가 다 앞방","theme":"home"},
		{"building":9,"level":0,"rect":[40,51,12,3],"name":"농가 다 뒷방","theme":"home"},
		{"building":9,"level":1,"rect":[40,44,12,3],"name":"농가 다 앞방","theme":"home"},
		{"building":9,"level":1,"rect":[40,51,12,3],"name":"농가 다 뒷방","theme":"home"},
		{"building":10,"level":0,"rect":[5,71,12,3],"name":"농가 라 앞방","theme":"home"},
		{"building":10,"level":0,"rect":[5,78,12,3],"name":"농가 라 뒷방","theme":"home"},
		{"building":11,"level":0,"rect":[48,67,6,8],"name":"외양간 앞방","theme":"store"},
		{"building":11,"level":0,"rect":[55,67,5,8],"name":"외양간 뒷방","theme":"store"},
		{"building":12,"level":0,"rect":[45,19,6,8],"name":"장작 창고 앞방","theme":"store"},
		{"building":12,"level":0,"rect":[52,19,5,8],"name":"장작 창고 뒷방","theme":"store"},
		{"building":13,"level":0,"rect":[92,70,8,8],"name":"곡물 창고 앞방","theme":"cellar"},
		{"building":13,"level":0,"rect":[101,70,7,8],"name":"곡물 창고 뒷방","theme":"cellar"},
		{"building":14,"level":0,"rect":[28,51,4,4],"name":"우물집 안방","theme":"home"},
		{"building":15,"level":0,"rect":[133,70,10,6],"name":"수레 헛간 안방","theme":"store"}
	],
	"containers": [
		{"id":"box_001","name":"찬송집 방 보관함","cell":[73,46],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_002","name":"종지기 방 보관함","cell":[74,65],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_003","name":"현관 방 보관함","cell":[87,45],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_004","name":"옆 예배실 보관함","cell":[83,65],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_005","name":"제의실 보관함","cell":[95,45],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_006","name":"회중 준비방 보관함","cell":[89,65],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_007","name":"교구 사무방 보관함","cell":[103,45],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_008","name":"성가대방 보관함","cell":[98,65],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_009","name":"기록방 보관함","cell":[105,46],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_010","name":"안쪽 저장실 보관함","cell":[107,65],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_011","name":"회중석 보관함","cell":[102,56],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_012","name":"합창 다락 앞방 보관함","cell":[76,50],"building":0,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_013","name":"합창 다락 뒷방 보관함","cell":[74,63],"building":0,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_014","name":"난방실 보관함","cell":[100,57],"building":0,"search":4,"items":["document"],"locked":false,"level":-1,"searched":false},
		{"id":"box_015","name":"막다른 식량 저장실 보관함","cell":[108,57],"building":0,"search":6,"items":["document","symbol_bell","food_pack"],"locked":false,"level":-1,"searched":false},
		{"id":"box_016","name":"탑 아래 앞방 보관함","cell":[61,48],"building":1,"search":4,"items":["symbol_bell"],"locked":false,"level":0,"searched":false},
		{"id":"box_017","name":"탑 아래 뒷방 보관함","cell":[67,48],"building":1,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_018","name":"종 줄 방 보관함","cell":[63,48],"building":1,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_019","name":"종 줄 방의 돌아가는 길 보관함","cell":[67,48],"building":1,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_020","name":"종 다락 앞방 보관함","cell":[62,48],"building":1,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_021","name":"종 다락 보관함","cell":[67,48],"building":1,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_022","name":"종지기 집 안방 보관함","cell":[122,59],"building":2,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_023","name":"묘지 도구 창고 안방 보관함","cell":[122,43],"building":3,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_024","name":"사제관 앞방 보관함","cell":[140,45],"building":4,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_025","name":"사제관 뒷방 보관함","cell":[140,53],"building":4,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_026","name":"사제관 앞방 보관함","cell":[140,45],"building":4,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_027","name":"사제관 뒷방 보관함","cell":[141,53],"building":4,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_028","name":"헛간 앞방 보관함","cell":[88,24],"building":5,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_029","name":"헛간 뒷방 보관함","cell":[95,24],"building":5,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_030","name":"빵집 앞방 보관함","cell":[34,38],"building":6,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_031","name":"빵집 뒷방 보관함","cell":[26,46],"building":6,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_032","name":"빵집 앞방 보관함","cell":[36,38],"building":6,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_033","name":"빵집 뒷방 보관함","cell":[36,45],"building":6,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_034","name":"농가 가 앞방 보관함","cell":[78,18],"building":7,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_035","name":"농가 가 뒷방 보관함","cell":[78,25],"building":7,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_036","name":"농가 가 앞방 보관함","cell":[78,18],"building":7,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_037","name":"농가 가 뒷방 보관함","cell":[78,25],"building":7,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_038","name":"농가 나 앞방 보관함","cell":[16,19],"building":8,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_039","name":"농가 나 뒷방 보관함","cell":[16,26],"building":8,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_040","name":"농가 다 앞방 보관함","cell":[49,45],"building":9,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_041","name":"농가 다 뒷방 보관함","cell":[48,52],"building":9,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_042","name":"농가 다 앞방 보관함","cell":[51,45],"building":9,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_043","name":"농가 다 뒷방 보관함","cell":[51,52],"building":9,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_044","name":"농가 라 앞방 보관함","cell":[14,72],"building":10,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_045","name":"농가 라 뒷방 보관함","cell":[15,79],"building":10,"search":6,"items":["cloth","symbol_bell","food_pack"],"locked":false,"level":0,"searched":false},
		{"id":"box_046","name":"외양간 앞방 보관함","cell":[48,72],"building":11,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_047","name":"외양간 뒷방 보관함","cell":[57,72],"building":11,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_048","name":"장작 창고 앞방 보관함","cell":[48,24],"building":12,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_049","name":"장작 창고 뒷방 보관함","cell":[54,24],"building":12,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_050","name":"곡물 창고 앞방 보관함","cell":[94,75],"building":13,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_051","name":"곡물 창고 뒷방 보관함","cell":[106,75],"building":13,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_052","name":"우물집 안방 보관함","cell":[31,53],"building":14,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_053","name":"수레 헛간 안방 보관함","cell":[138,73],"building":15,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_054","name":"승강장 남은 상자","cell":[51,10],"building":-1,"search":3,"items":["plank","cloth"],"locked":false,"level":0,"searched":false}
	],
	"entries": [
		{"id":"west_road","cells":[[0,31],[0,32],[0,33],[0,34]],"gap":0.6},
		{"id":"village_road","cells":[[0,58],[0,59],[0,60],[0,61]],"gap":0.6},
		{"id":"south_road","cells":[[96,89],[97,89],[98,89],[99,89]],"gap":0.6},
		{"id":"east_lane","cells":[[149,66],[149,67],[149,68]],"gap":2}
	],
	"holes": [
		{"id":"manhole_01","cell":[64,83],"name":"길가 맨홀","level":0,"gap":3}
	],
	"slots": [
		[59,26],
		[61,26],
		[81,25],
		[82,25],
		[102,27],
		[104,27]
	],
	"dead": [
		[3,32],
		[5,59],
		[96,86],
		[147,66],
		[124,77],
		[63,79]
	],
	"deep": [
		"B",
		"D"
	],
	"work": {"cell":[34,55],"rect":[28,46,22,12]}
}

# 위쪽 일터의 독립 평면. 아래쪽 계획의 건물 번호 뒤에만 덧붙인다.
const NORTH: Dictionary = {
	"names": {"H":"곡물 마당","I":"방앗간 못","J":"농가 골"},
	"zones": [
		{"id":"H","rect":[0,0,40,46]},
		{"id":"I","rect":[40,0,70,46]},
		{"id":"J","rect":[110,0,40,46]}
	],
	"ground": [
		{"rect":[0,0,40,24],"kind":"GRAVEL"},
		{"rect":[110,0,40,45],"kind":"DEEP_SNOW"},
		{"rect":[104,0,6,43],"kind":"ROAD"},
		{"rect":[0,9,40,5],"kind":"ROAD"},
		{"rect":[35,9,5,34],"kind":"ROAD"},
		{"rect":[58,4,46,4],"kind":"ROAD"},
		{"rect":[110,3,40,4],"kind":"ROAD"},
		{"rect":[130,17,17,7],"kind":"GRAVEL"},
		{"rect":[112,24,4,21],"kind":"ROAD"},
		{"rect":[112,38,22,4],"kind":"ROAD"},
		{"rect":[146,7,4,38],"kind":"ROAD"},
		{"rect":[134,29,12,4],"kind":"GRAVEL"},
		{"rect":[10,24,6,21],"kind":"ROAD"},
		{"rect":[96,34,6,11],"kind":"ROAD"}
	],
	"buildings": [
		{"id":16,"name":"방앗간","rect":[80,10,24,14],"warm":false,"window_broken":false},
		{"id":17,"name":"곡물 곳간","rect":[110,8,18,16],"warm":false,"window_broken":false},
		{"id":18,"name":"일꾼 집","rect":[22,15,12,9],"warm":false,"window_broken":false},
		{"id":19,"name":"건초 헛간","rect":[4,0,16,8],"warm":false,"window_broken":false},
		{"id":20,"name":"연장 창고","rect":[6,16,8,6],"warm":false,"window_broken":false},
		{"id":21,"name":"맷돌 헛간","rect":[48,4,10,10],"warm":false,"window_broken":false},
		{"id":22,"name":"농가","rect":[116,26,18,12],"warm":false,"window_broken":false},
		{"id":23,"name":"외양간","rect":[134,38,12,7],"warm":false,"window_broken":false}
	],
	"shells": [
		{"building":16,"level":-1,"rect":[80,10,24,14]},
		{"building":16,"level":0,"rect":[80,10,24,14]},
		{"building":16,"level":1,"rect":[80,10,24,14]},
		{"building":16,"level":2,"rect":[80,10,24,14]},
		{"building":17,"level":0,"rect":[110,8,18,16]},
		{"building":17,"level":1,"rect":[110,8,18,16]},
		{"building":18,"level":0,"rect":[22,15,12,9]},
		{"building":18,"level":1,"rect":[22,15,12,9]},
		{"building":19,"level":0,"rect":[4,0,16,8]},
		{"building":20,"level":0,"rect":[6,16,8,6]},
		{"building":21,"level":0,"rect":[48,4,10,10]},
		{"building":22,"level":0,"rect":[116,26,18,12]},
		{"building":22,"level":1,"rect":[116,26,18,12]},
		{"building":23,"level":0,"rect":[134,38,12,7]}
	],
	"walls": [
		{"level":-1,"rect":[92,11,1,12]},
		{"level":0,"rect":[81,15,22,1]},
		{"level":0,"rect":[81,18,22,1]},
		{"level":0,"rect":[87,11,1,4]},
		{"level":0,"rect":[87,19,1,4]},
		{"level":0,"rect":[94,11,1,4]},
		{"level":0,"rect":[94,19,1,4]},
		{"level":1,"rect":[92,11,1,12]},
		{"level":2,"rect":[92,11,1,12]},
		{"level":0,"rect":[119,9,1,14]},
		{"level":1,"rect":[119,9,1,14]},
		{"level":0,"rect":[28,16,1,7]},
		{"level":1,"rect":[28,16,1,7]},
		{"level":0,"rect":[12,1,1,6]},
		{"level":0,"rect":[54,5,1,8]},
		{"level":0,"rect":[49,9,6,1]},
		{"level":0,"rect":[125,27,1,10]},
		{"level":1,"rect":[125,27,1,10]},
		{"level":0,"rect":[140,39,1,5]}
	],
	"doors": [
		{"building":16,"level":-1,"cell":[92,17],"side":[1,0],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[84,15],"side":[0,1],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[84,18],"side":[0,-1],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[91,15],"side":[0,1],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[91,18],"side":[0,-1],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[99,15],"side":[0,1],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[99,18],"side":[0,-1],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[92,23],"side":[0,1],"state":"open","outer":true},
		{"building":16,"level":1,"cell":[92,17],"side":[1,0],"state":"open","outer":false},
		{"building":16,"level":2,"cell":[92,17],"side":[1,0],"state":"open","outer":false},
		{"building":17,"level":0,"cell":[119,16],"side":[1,0],"state":"open","outer":false},
		{"building":17,"level":0,"cell":[115,23],"side":[0,1],"state":"open","outer":true},
		{"building":17,"level":1,"cell":[119,16],"side":[1,0],"state":"open","outer":false},
		{"building":18,"level":0,"cell":[28,19],"side":[1,0],"state":"open","outer":false},
		{"building":18,"level":0,"cell":[25,15],"side":[0,-1],"state":"open","outer":true},
		{"building":18,"level":1,"cell":[28,19],"side":[1,0],"state":"open","outer":false},
		{"building":19,"level":0,"cell":[12,4],"side":[1,0],"state":"open","outer":false},
		{"building":19,"level":0,"cell":[8,7],"side":[0,1],"state":"open","outer":true},
		{"building":20,"level":0,"cell":[10,16],"side":[0,-1],"state":"open","outer":true},
		{"building":21,"level":0,"cell":[54,7],"side":[1,0],"state":"open","outer":false},
		{"building":21,"level":0,"cell":[54,11],"side":[1,0],"state":"open","outer":false},
		{"building":21,"level":0,"cell":[57,6],"side":[1,0],"state":"open","outer":true},
		{"building":22,"level":0,"cell":[125,32],"side":[1,0],"state":"open","outer":false},
		{"building":22,"level":0,"cell":[133,32],"side":[1,0],"state":"open","outer":true},
		{"building":22,"level":0,"cell":[124,37],"side":[0,1],"state":"open","outer":true},
		{"building":22,"level":1,"cell":[125,32],"side":[1,0],"state":"open","outer":false},
		{"building":23,"level":0,"cell":[140,41],"side":[1,0],"state":"open","outer":false},
		{"building":23,"level":0,"cell":[137,38],"side":[0,-1],"state":"open","outer":true}
	],
	"windows": [
		{"building":16,"level":-1,"cell":[86,10],"broken":false},
		{"building":16,"level":-1,"cell":[98,10],"broken":false},
		{"building":16,"level":0,"cell":[84,10],"broken":false},
		{"building":16,"level":0,"cell":[91,10],"broken":false},
		{"building":16,"level":0,"cell":[99,10],"broken":false},
		{"building":16,"level":1,"cell":[86,10],"broken":false},
		{"building":16,"level":1,"cell":[98,10],"broken":false},
		{"building":16,"level":2,"cell":[86,10],"broken":false},
		{"building":16,"level":2,"cell":[98,10],"broken":false},
		{"building":17,"level":0,"cell":[115,8],"broken":false},
		{"building":17,"level":0,"cell":[123,8],"broken":false},
		{"building":17,"level":1,"cell":[115,8],"broken":false},
		{"building":17,"level":1,"cell":[123,8],"broken":false},
		{"building":18,"level":0,"cell":[31,15],"broken":false},
		{"building":18,"level":1,"cell":[25,15],"broken":false},
		{"building":18,"level":1,"cell":[31,15],"broken":false},
		{"building":19,"level":0,"cell":[8,0],"broken":false},
		{"building":19,"level":0,"cell":[16,0],"broken":false},
		{"building":20,"level":0,"cell":[10,21],"broken":false},
		{"building":21,"level":0,"cell":[51,4],"broken":false},
		{"building":22,"level":0,"cell":[121,26],"broken":false},
		{"building":22,"level":0,"cell":[129,26],"broken":false},
		{"building":22,"level":1,"cell":[121,26],"broken":false},
		{"building":22,"level":1,"cell":[129,26],"broken":false},
		{"building":23,"level":0,"cell":[143,38],"broken":false}
	],
	"stairs": [
		{"cell":[81,11],"low":-1,"high":0,"ladder":false},
		{"cell":[81,11],"low":0,"high":1,"ladder":false},
		{"cell":[81,11],"low":1,"high":2,"ladder":false},
		{"cell":[111,9],"low":0,"high":1,"ladder":false},
		{"cell":[23,16],"low":0,"high":1,"ladder":false},
		{"cell":[117,27],"low":0,"high":1,"ladder":false}
	],
	"props": [
		{"kind":"water","rect":[40,0,64,4],"solid":"low","facing":0,"note":"눈과 얼음으로 덮인 물","level":0},
		{"kind":"water","rect":[40,4,8,20],"solid":"low","facing":0,"note":"눈과 얼음으로 덮인 물","level":0},
		{"kind":"water","rect":[58,8,22,16],"solid":"low","facing":0,"note":"눈과 얼음으로 덮인 물","level":0},
		{"kind":"water","rect":[48,14,10,10],"solid":"low","facing":0,"note":"눈과 얼음으로 덮인 물","level":0},
		{"kind":"farm_cart","rect":[59,37,4,2],"solid":"low","facing":0,"note":"운반하다 세워 둔 짐수레","level":0},
		{"kind":"sack_pile","rect":[70,40,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"fieldstone_wall","rect":[100,28,1,6],"solid":"low","facing":0,"note":"글씨 없는 들돌 담 토막","level":0},
		{"kind":"firewood_pile","rect":[10,30,2,1],"solid":"low","facing":0,"note":"처마 밑 마른 장작","level":0},
		{"kind":"handcart","rect":[132,18,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"sack_pile","rect":[135,20,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"barrel","rect":[139,18,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"crate_stack","rect":[142,20,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"lamp_post","rect":[118,41,1,1],"solid":"none","facing":0,"note":"꺼진 등잔 기둥","level":0},
		{"kind":"fieldstone_wall","rect":[116,24,1,2],"solid":"low","facing":0,"note":"글씨 없는 들돌 담 토막","level":0},
		{"kind":"bare_tree","rect":[24,1,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[29,3,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[34,1,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[36,6,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[136,25,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[141,27,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[138,34,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[143,34,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[112,1,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[117,2,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[124,0,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[126,2,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"sack_pile","rect":[82,11,2,2],"solid":"none","facing":0,"note":"물자를 담은 자루","level":-1},
		{"kind":"shelf","rect":[82,22,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":-1},
		{"kind":"barrel","rect":[91,22,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":-1},
		{"kind":"sack_pile","rect":[93,11,2,2],"solid":"none","facing":0,"note":"물자를 담은 자루","level":-1},
		{"kind":"shelf","rect":[93,22,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":-1},
		{"kind":"barrel","rect":[102,22,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":-1},
		{"kind":"desk","rect":[85,11,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"sack_pile","rect":[82,11,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"barrel","rect":[86,14,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"sack_pile","rect":[81,19,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"sack_pile","rect":[85,19,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"handcart","rect":[85,22,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"millstone","rect":[88,11,2,2],"solid":"low","facing":0,"note":"닳은 맷돌","level":0},
		{"kind":"millstone","rect":[88,13,2,2],"solid":"low","facing":0,"note":"닳은 맷돌","level":0},
		{"kind":"handcart","rect":[92,11,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"sack_pile","rect":[88,19,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[88,22,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"barrel","rect":[93,19,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"desk","rect":[95,11,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"shelf","rect":[95,14,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"sack_pile","rect":[101,19,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[95,22,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"barrel","rect":[102,22,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"shelf","rect":[81,22,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"sack_pile","rect":[82,11,2,2],"solid":"none","facing":0,"note":"물자를 담은 자루","level":1},
		{"kind":"barrel","rect":[91,22,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":1},
		{"kind":"shelf","rect":[93,11,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"sack_pile","rect":[101,11,2,2],"solid":"none","facing":0,"note":"물자를 담은 자루","level":1},
		{"kind":"barrel","rect":[102,22,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":1},
		{"kind":"barrel","rect":[81,22,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":2},
		{"kind":"barrel","rect":[91,22,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":2},
		{"kind":"shelf","rect":[81,21,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":2},
		{"kind":"barrel","rect":[102,22,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":2},
		{"kind":"barrel","rect":[93,22,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":2},
		{"kind":"shelf","rect":[94,11,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":2},
		{"kind":"sack_pile","rect":[111,10,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"barrel","rect":[111,22,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"shelf","rect":[112,22,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"sack_pile","rect":[120,9,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"barrel","rect":[126,22,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"shelf","rect":[120,22,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"desk","rect":[111,22,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":1},
		{"kind":"shelf","rect":[112,9,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"shelf","rect":[120,9,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"barrel","rect":[126,22,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":1},
		{"kind":"crate_stack","rect":[120,21,2,2],"solid":"none","facing":0,"note":"종류별 물자를 담은 나무 상자","level":1},
		{"kind":"cold_stove","rect":[27,22,1,1],"solid":"low","facing":0,"note":"작게 식은 난로","level":0},
		{"kind":"shelf","rect":[24,22,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"barrel","rect":[27,16,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"sack_pile","rect":[29,16,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[29,22,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"bed","rect":[26,22,2,1],"solid":"none","facing":0,"note":"숙직하는 이의 침대","level":1},
		{"kind":"desk","rect":[26,16,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":1},
		{"kind":"bed","rect":[29,22,2,1],"solid":"none","facing":0,"note":"숙직하는 이의 침대","level":1},
		{"kind":"shelf","rect":[29,16,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"sack_pile","rect":[5,1,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"handcart","rect":[5,6,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"barrel","rect":[11,1,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"sack_pile","rect":[13,1,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"handcart","rect":[13,6,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"barrel","rect":[18,1,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"shelf","rect":[7,17,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[7,19,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[11,17,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"millstone","rect":[52,5,2,2],"solid":"low","facing":0,"note":"닳은 맷돌","level":0},
		{"kind":"millstone","rect":[49,7,2,2],"solid":"low","facing":0,"note":"닳은 맷돌","level":0},
		{"kind":"handcart","rect":[50,5,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"millstone","rect":[49,10,2,2],"solid":"low","facing":0,"note":"닳은 맷돌","level":0},
		{"kind":"barrel","rect":[53,12,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"cold_stove","rect":[124,27,1,1],"solid":"low","facing":0,"note":"작게 식은 난로","level":0},
		{"kind":"shelf","rect":[117,36,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"barrel","rect":[117,28,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"sack_pile","rect":[126,27,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[126,36,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"bed","rect":[118,27,2,1],"solid":"none","facing":0,"note":"숙직하는 이의 침대","level":1},
		{"kind":"desk","rect":[117,28,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":1},
		{"kind":"bed","rect":[126,27,2,1],"solid":"none","facing":0,"note":"숙직하는 이의 침대","level":1},
		{"kind":"shelf","rect":[126,36,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"sack_pile","rect":[135,42,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"handcart","rect":[135,40,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"barrel","rect":[139,43,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"sack_pile","rect":[141,39,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"handcart","rect":[141,43,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"barrel","rect":[144,39,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0}
	],
	"rooms": [
		{"building":16,"level":-1,"rect":[81,11,11,12],"name":"방앗간 지하 앞방","theme":"mill"},
		{"building":16,"level":-1,"rect":[93,11,10,12],"name":"방앗간 지하 뒷방","theme":"mill"},
		{"building":16,"level":0,"rect":[81,11,6,4],"name":"방앗간 계량방","theme":"mill"},
		{"building":16,"level":0,"rect":[81,19,6,4],"name":"방앗간 하역방","theme":"mill"},
		{"building":16,"level":0,"rect":[88,11,6,4],"name":"방앗간 작업방","theme":"mill"},
		{"building":16,"level":0,"rect":[88,19,6,4],"name":"방앗간 재료방","theme":"mill"},
		{"building":16,"level":0,"rect":[95,11,8,4],"name":"방앗간 사무방","theme":"mill"},
		{"building":16,"level":0,"rect":[95,19,8,4],"name":"방앗간 안쪽 저장방","theme":"mill"},
		{"building":16,"level":1,"rect":[81,11,11,12],"name":"방앗간 위층 체 다락 앞방","theme":"mill"},
		{"building":16,"level":1,"rect":[93,11,10,12],"name":"방앗간 위층 체 다락 뒷방","theme":"mill"},
		{"building":16,"level":2,"rect":[81,11,11,12],"name":"방앗간 다락 곡물 통 앞다락","theme":"mill"},
		{"building":16,"level":2,"rect":[93,11,10,12],"name":"방앗간 다락 곡물 통 뒷다락","theme":"mill"},
		{"building":17,"level":0,"rect":[111,9,8,14],"name":"곡물 곳간 앞방","theme":"grain"},
		{"building":17,"level":0,"rect":[120,9,7,14],"name":"곡물 곳간 뒷방","theme":"grain"},
		{"building":17,"level":1,"rect":[111,9,8,14],"name":"곡물 곳간 위층 앞방","theme":"grain"},
		{"building":17,"level":1,"rect":[120,9,7,14],"name":"곡물 곳간 위층 뒷방","theme":"grain"},
		{"building":18,"level":0,"rect":[23,16,5,7],"name":"일꾼 집 앞방","theme":"house"},
		{"building":18,"level":0,"rect":[29,16,4,7],"name":"일꾼 집 뒷방","theme":"house"},
		{"building":18,"level":1,"rect":[23,16,5,7],"name":"일꾼 집 위층 앞방","theme":"house"},
		{"building":18,"level":1,"rect":[29,16,4,7],"name":"일꾼 집 위층 뒷방","theme":"house"},
		{"building":19,"level":0,"rect":[5,1,7,6],"name":"건초 헛간 앞방","theme":"hay"},
		{"building":19,"level":0,"rect":[13,1,6,6],"name":"건초 헛간 뒷방","theme":"hay"},
		{"building":20,"level":0,"rect":[7,17,6,4],"name":"연장 창고 작업방","theme":"tools"},
		{"building":21,"level":0,"rect":[49,5,5,4],"name":"맷돌 헛간 앞 작업방","theme":"mill"},
		{"building":21,"level":0,"rect":[49,10,5,3],"name":"맷돌 헛간 안쪽 보관방","theme":"mill"},
		{"building":22,"level":0,"rect":[117,27,8,10],"name":"농가 앞방","theme":"house"},
		{"building":22,"level":0,"rect":[126,27,7,10],"name":"농가 뒷방","theme":"house"},
		{"building":22,"level":1,"rect":[117,27,8,10],"name":"농가 위층 앞방","theme":"house"},
		{"building":22,"level":1,"rect":[126,27,7,10],"name":"농가 위층 뒷방","theme":"house"},
		{"building":23,"level":0,"rect":[135,39,5,5],"name":"외양간 앞방","theme":"hay"},
		{"building":23,"level":0,"rect":[141,39,4,5],"name":"외양간 뒷방","theme":"hay"}
	],
	"containers": [
		{"id":"north_box_006","name":"방앗간 재료방 보관함","cell":[93,22],"building":16,"search":6,"items":["food_pack","food_pack","food_pack"],"locked":false,"level":0,"searched":false},
		{"id":"north_box_021","name":"건초 헛간 앞방 보관함","cell":[11,6],"building":19,"search":6,"items":["food_pack","food_pack","food_pack"],"locked":false,"level":0,"searched":false},
		{"id":"north_box_023","name":"연장 창고 작업방 보관함","cell":[12,20],"building":20,"search":6,"items":["food_pack","food_pack","food_pack"],"locked":false,"level":0,"searched":false},
		{"id":"north_box_024","name":"맷돌 헛간 앞 작업방 보관함","cell":[49,5],"building":21,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"north_box_025","name":"맷돌 헛간 막다른 물자 보관함","cell":[49,12],"building":21,"search":8,"items":["scrap"],"locked":false,"level":0,"searched":false},
		{"id":"north_shallow","name":"운반 도중 내려둔 물자 보관함","cell":[61,35],"building":-1,"search":2,"items":["food_pack"],"locked":false,"level":0,"searched":false}
	],
	"entries": [
		{"id":"북쪽 곡물 길","cells":[[104,0],[105,0],[106,0],[107,0]],"gap":0.6},
		{"id":"서쪽 마차 길","cells":[[0,10],[0,11],[0,12]],"gap":0.6},
		{"id":"동쪽 들길","cells":[[149,4],[149,5],[149,6]],"gap":0.6}
	],
	"holes": [

	],
	"slots": [
		[35,24],
		[38,25],
		[105,24],
		[108,25],
		[116,39],
		[117,41],
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
	"deep": "I",
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
const ENTRY_NAMES: Dictionary = {"west_road": "서쪽 길", "village_road": "마을 길", "south_road": "남쪽 길", "east_lane": "동쪽 샛길", "manhole_01": "맨홀", "북쪽 곡물 길": "북쪽 곡물 길", "서쪽 마차 길": "서쪽 마차 길", "동쪽 들길": "동쪽 들길"}
const ENTRY_WEIGHTS: Dictionary = {"west_road": 1.0, "village_road": 1.0, "south_road": 1.0, "east_lane": 0.5, "manhole_01": 0.3, "북쪽 곡물 길": 1.0, "서쪽 마차 길": 1.0, "동쪽 들길": 1.0}
const FIRST_ENTRY: String = "west_road"


static func build() -> Dictionary:
	var data: Dictionary = _build_plain()
	data["entry_names"] = ENTRY_NAMES.duplicate()
	data["entry_weights"] = ENTRY_WEIGHTS.duplicate()
	data["first_entry"] = FIRST_ENTRY
	return data
