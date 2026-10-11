# 이 지도가 다른 판단을 만드는 것: 광장은 길 다섯이 모여 못 막고, 성당 안은 숨을 곳이 기둥뿐이다.
# 위쪽의 판단: 연장 상자와 등잔 기름은 한 사람이 가볍게 챙겨 올 수 있으나, 쇠 소리가 나는 골목에 오래 머물면 광장 쪽 작업조가 무리 앞에 홀로 남는다.
extends RefCounted

const FieldGrid = preload("res://game/world/field_grid.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const PLACE_ID: String = "church_02"
const WIDTH: int = 175
const SOUTH_HEIGHT: int = 105
const HEIGHT: int = SOUTH_HEIGHT + 45

# 각 방과 마당의 좌표는 이 지도에서만 쓰는 독립 평면이다.
# 종소리와 덧댄 문 해체는 자리만 남기며 여기서 실행하지 않는다.
const PLAN: Dictionary = {
	"id": "church_02",
	"size": [
		175,
		105
	],
	"names": {"A":"열차 곁 띠","B":"광장","C":"성당","D":"북서 공동주택","E":"북동 공동주택","F":"서쪽 뒷거리","G":"동쪽 뒷거리"},
	"zones": [
		{"id":"A","rect":[0,0,175,105]},
		{"id":"D","rect":[0,32,52,31]},
		{"id":"E","rect":[118,10,57,49]},
		{"id":"B","rect":[50,35,78,29]},
		{"id":"C","rect":[43,63,89,42]},
		{"id":"F","rect":[0,63,43,42]},
		{"id":"G","rect":[132,59,43,46]}
	],
	"ground": [
		{"rect":[0,10,22,20],"kind":"DEEP_SNOW"},
		{"rect":[0,97,35,8],"kind":"DEEP_SNOW"},
		{"rect":[146,10,29,20],"kind":"DEEP_SNOW"},
		{"rect":[118,37,29,12],"kind":"DEEP_SNOW"},
		{"rect":[163,88,12,17],"kind":"DEEP_SNOW"},
		{"rect":[52,36,70,25],"kind":"SNOW"},
		{"rect":[24,12,96,20],"kind":"GRAVEL"},
		{"rect":[143,83,25,16],"kind":"GRAVEL"},
		{"rect":[84,10,6,26],"kind":"ROAD"},
		{"rect":[0,44,25,5],"kind":"ROAD"},
		{"rect":[21,44,4,18],"kind":"ROAD"},
		{"rect":[21,58,31,4],"kind":"ROAD"},
		{"rect":[48,44,6,18],"kind":"ROAD"},
		{"rect":[122,52,53,5],"kind":"ROAD"},
		{"rect":[38,60,5,45],"kind":"ROAD"},
		{"rect":[41,63,7,5],"kind":"ROAD"},
		{"rect":[138,57,4,48],"kind":"ROAD"},
		{"rect":[128,81,47,4],"kind":"ROAD"},
		{"rect":[169,52,5,34],"kind":"ROAD"},
		{"rect":[122,39,5,18],"kind":"ROAD"}
	],
	"buildings": [
		{"id":0,"name":"성당 본당","rect":[48,66,80,36],"warm":true,"window_broken":false},
		{"id":1,"name":"종탑","rect":[48,52,12,12],"warm":false,"window_broken":false},
		{"id":2,"name":"성당 관리인 집","rect":[130,61,10,8],"warm":false,"window_broken":false},
		{"id":3,"name":"공동주택 가","rect":[26,35,22,18],"warm":false,"window_broken":false},
		{"id":4,"name":"공동주택 나","rect":[3,62,20,18],"warm":false,"window_broken":false},
		{"id":5,"name":"공동주택 다","rect":[123,15,24,20],"warm":false,"window_broken":false},
		{"id":6,"name":"공동주택 라","rect":[147,32,22,16],"warm":false,"window_broken":false},
		{"id":7,"name":"참사회관","rect":[143,68,20,14],"warm":false,"window_broken":false},
		{"id":8,"name":"사제관","rect":[25,73,16,12],"warm":false,"window_broken":false},
		{"id":9,"name":"시장 창고","rect":[28,18,20,12],"warm":false,"window_broken":false},
		{"id":10,"name":"차고 줄 가","rect":[53,20,16,8],"warm":false,"window_broken":false},
		{"id":11,"name":"차고 줄 나","rect":[97,18,13,10],"warm":false,"window_broken":false},
		{"id":12,"name":"연료 창고","rect":[146,87,12,8],"warm":false,"window_broken":false},
		{"id":13,"name":"주택 가","rect":[3,85,14,12],"warm":false,"window_broken":false},
		{"id":14,"name":"주택 나","rect":[152,57,14,10],"warm":false,"window_broken":false},
		{"id":15,"name":"주택 다","rect":[24,90,12,10],"warm":false,"window_broken":false}
	],
	"shells": [
		{"building":0,"level":0,"rect":[48,66,80,36]},
		{"building":0,"level":1,"rect":[48,66,8,36]},
		{"building":0,"level":-1,"rect":[104,66,24,36]},
		{"building":1,"level":0,"rect":[48,52,12,12]},
		{"building":1,"level":1,"rect":[48,52,12,12]},
		{"building":1,"level":2,"rect":[48,52,12,12]},
		{"building":2,"level":0,"rect":[130,61,10,8]},
		{"building":3,"level":0,"rect":[26,35,22,18]},
		{"building":3,"level":1,"rect":[26,35,22,18]},
		{"building":3,"level":2,"rect":[26,35,22,18]},
		{"building":4,"level":0,"rect":[3,62,20,18]},
		{"building":4,"level":1,"rect":[3,62,20,18]},
		{"building":4,"level":2,"rect":[3,62,20,18]},
		{"building":5,"level":0,"rect":[123,15,24,20]},
		{"building":5,"level":1,"rect":[123,15,24,20]},
		{"building":5,"level":2,"rect":[123,15,24,20]},
		{"building":6,"level":0,"rect":[147,32,22,16]},
		{"building":6,"level":1,"rect":[147,32,22,16]},
		{"building":6,"level":2,"rect":[147,32,22,16]},
		{"building":7,"level":0,"rect":[143,68,20,14]},
		{"building":7,"level":1,"rect":[143,68,20,14]},
		{"building":8,"level":0,"rect":[25,73,16,12]},
		{"building":8,"level":1,"rect":[25,73,16,12]},
		{"building":9,"level":0,"rect":[28,18,20,12]},
		{"building":10,"level":0,"rect":[53,20,16,8]},
		{"building":12,"level":0,"rect":[146,87,12,8]},
		{"building":13,"level":0,"rect":[3,85,14,12]},
		{"building":13,"level":1,"rect":[3,85,14,12]},
		{"building":14,"level":0,"rect":[152,57,14,10]},
		{"building":14,"level":1,"rect":[152,57,14,10]},
		{"building":15,"level":0,"rect":[24,90,12,10]},
		{"building":11,"level":0,"rect":[97,18,13,10]}
	],
	"walls": [
		{"level":0,"rect":[49,72,78,1]},
		{"level":0,"rect":[49,95,78,1]},
		{"level":0,"rect":[63,67,1,5]},
		{"level":0,"rect":[63,96,1,5]},
		{"level":0,"rect":[79,67,1,5]},
		{"level":0,"rect":[79,96,1,5]},
		{"level":0,"rect":[95,67,1,5]},
		{"level":0,"rect":[95,96,1,5]},
		{"level":0,"rect":[111,67,1,5]},
		{"level":0,"rect":[111,96,1,5]},
		{"level":1,"rect":[49,84,6,1]},
		{"level":-1,"rect":[107,69,18,1]},
		{"level":-1,"rect":[107,98,18,1]},
		{"level":-1,"rect":[107,69,1,30]},
		{"level":-1,"rect":[124,69,1,30]},
		{"level":-1,"rect":[116,70,1,28]},
		{"level":0,"rect":[53,53,1,10]},
		{"level":1,"rect":[53,53,1,10]},
		{"level":2,"rect":[53,53,1,10]},
		{"level":1,"rect":[27,42,20,1]},
		{"level":1,"rect":[27,45,20,1]},
		{"level":1,"rect":[36,36,1,6]},
		{"level":1,"rect":[36,46,1,6]},
		{"level":2,"rect":[27,42,20,1]},
		{"level":2,"rect":[27,45,20,1]},
		{"level":2,"rect":[36,36,1,6]},
		{"level":2,"rect":[36,46,1,6]},
		{"level":0,"rect":[4,69,18,1]},
		{"level":0,"rect":[4,72,18,1]},
		{"level":1,"rect":[4,69,18,1]},
		{"level":1,"rect":[4,72,18,1]},
		{"level":2,"rect":[4,69,18,1]},
		{"level":2,"rect":[4,72,18,1]},
		{"level":0,"rect":[124,23,22,1]},
		{"level":0,"rect":[124,26,22,1]},
		{"level":0,"rect":[134,16,1,7]},
		{"level":0,"rect":[134,27,1,7]},
		{"level":1,"rect":[124,23,22,1]},
		{"level":1,"rect":[124,26,22,1]},
		{"level":1,"rect":[134,16,1,7]},
		{"level":1,"rect":[134,27,1,7]},
		{"level":2,"rect":[124,23,22,1]},
		{"level":2,"rect":[124,26,22,1]},
		{"level":2,"rect":[134,16,1,7]},
		{"level":2,"rect":[134,27,1,7]},
		{"level":0,"rect":[148,38,20,1]},
		{"level":0,"rect":[148,41,20,1]},
		{"level":1,"rect":[148,38,20,1]},
		{"level":1,"rect":[148,41,20,1]},
		{"level":2,"rect":[148,38,20,1]},
		{"level":2,"rect":[148,41,20,1]},
		{"level":0,"rect":[144,73,18,1]},
		{"level":0,"rect":[144,76,18,1]},
		{"level":1,"rect":[144,73,18,1]},
		{"level":1,"rect":[144,76,18,1]},
		{"level":0,"rect":[26,77,14,1]},
		{"level":0,"rect":[26,80,14,1]},
		{"level":1,"rect":[26,77,14,1]},
		{"level":1,"rect":[26,80,14,1]},
		{"level":0,"rect":[29,22,18,1]},
		{"level":0,"rect":[29,25,18,1]},
		{"level":0,"rect":[61,21,1,6]},
		{"level":0,"rect":[4,89,12,1]},
		{"level":0,"rect":[4,92,12,1]},
		{"level":1,"rect":[4,89,12,1]},
		{"level":1,"rect":[4,92,12,1]},
		{"level":0,"rect":[159,58,1,8]},
		{"level":1,"rect":[159,58,1,8]},
		{"level":0,"rect":[30,91,1,8]},
		{"level":0,"rect":[27,48,20,1]},
		{"level":0,"rect":[39,49,1,3]},
		{"level":0,"rect":[103,19,1,8]}
	],
	"doors": [
		{"building":0,"level":0,"cell":[56,72],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[56,95],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[71,72],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[71,95],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[87,72],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[87,95],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[103,72],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[103,95],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[119,72],"side":[0,1],"state":"closed","outer":false},
		{"building":0,"level":0,"cell":[119,95],"side":[0,-1],"state":"closed","outer":false},
		{"building":0,"level":0,"cell":[48,84],"side":[-1,0],"state":"open","outer":true},
		{"building":0,"level":0,"cell":[88,66],"side":[0,-1],"state":"open","outer":true},
		{"building":0,"level":0,"cell":[127,84],"side":[1,0],"state":"open","outer":true},
		{"building":0,"level":1,"cell":[51,84],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":-1,"cell":[107,84],"side":[-1,0],"state":"open","outer":false},
		{"building":0,"level":-1,"cell":[124,84],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":0,"cell":[53,61],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":1,"cell":[53,61],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":2,"cell":[53,61],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":0,"cell":[59,61],"side":[1,0],"state":"open","outer":true},
		{"building":2,"level":0,"cell":[130,65],"side":[-1,0],"state":"open","outer":true},
		{"building":2,"level":0,"cell":[139,65],"side":[1,0],"state":"open","outer":true},
		{"building":3,"level":0,"cell":[26,43],"side":[-1,0],"state":"open","outer":true},
		{"building":3,"level":0,"cell":[47,43],"side":[1,0],"state":"open","outer":true},
		{"building":3,"level":1,"cell":[31,42],"side":[0,1],"state":"open","outer":false},
		{"building":3,"level":1,"cell":[31,45],"side":[0,-1],"state":"open","outer":false},
		{"building":3,"level":1,"cell":[42,42],"side":[0,1],"state":"open","outer":false},
		{"building":3,"level":1,"cell":[42,45],"side":[0,-1],"state":"open","outer":false},
		{"building":3,"level":2,"cell":[31,42],"side":[0,1],"state":"open","outer":false},
		{"building":3,"level":2,"cell":[31,45],"side":[0,-1],"state":"open","outer":false},
		{"building":3,"level":2,"cell":[42,42],"side":[0,1],"state":"open","outer":false},
		{"building":3,"level":2,"cell":[42,45],"side":[0,-1],"state":"open","outer":false},
		{"building":4,"level":0,"cell":[13,69],"side":[0,1],"state":"open","outer":false},
		{"building":4,"level":0,"cell":[13,72],"side":[0,-1],"state":"open","outer":false},
		{"building":4,"level":0,"cell":[3,70],"side":[-1,0],"state":"open","outer":true},
		{"building":4,"level":0,"cell":[22,70],"side":[1,0],"state":"open","outer":true},
		{"building":4,"level":1,"cell":[13,69],"side":[0,1],"state":"open","outer":false},
		{"building":4,"level":1,"cell":[13,72],"side":[0,-1],"state":"open","outer":false},
		{"building":4,"level":2,"cell":[13,69],"side":[0,1],"state":"open","outer":false},
		{"building":4,"level":2,"cell":[13,72],"side":[0,-1],"state":"open","outer":false},
		{"building":5,"level":0,"cell":[129,23],"side":[0,1],"state":"open","outer":false},
		{"building":5,"level":0,"cell":[129,26],"side":[0,-1],"state":"open","outer":false},
		{"building":5,"level":0,"cell":[140,23],"side":[0,1],"state":"open","outer":false},
		{"building":5,"level":0,"cell":[140,26],"side":[0,-1],"state":"open","outer":false},
		{"building":5,"level":0,"cell":[123,24],"side":[-1,0],"state":"open","outer":true},
		{"building":5,"level":0,"cell":[146,24],"side":[1,0],"state":"open","outer":true},
		{"building":5,"level":1,"cell":[129,23],"side":[0,1],"state":"open","outer":false},
		{"building":5,"level":1,"cell":[129,26],"side":[0,-1],"state":"open","outer":false},
		{"building":5,"level":1,"cell":[140,23],"side":[0,1],"state":"open","outer":false},
		{"building":5,"level":1,"cell":[140,26],"side":[0,-1],"state":"open","outer":false},
		{"building":5,"level":2,"cell":[129,23],"side":[0,1],"state":"open","outer":false},
		{"building":5,"level":2,"cell":[129,26],"side":[0,-1],"state":"open","outer":false},
		{"building":5,"level":2,"cell":[140,23],"side":[0,1],"state":"open","outer":false},
		{"building":5,"level":2,"cell":[140,26],"side":[0,-1],"state":"open","outer":false},
		{"building":6,"level":0,"cell":[158,38],"side":[0,1],"state":"open","outer":false},
		{"building":6,"level":0,"cell":[158,41],"side":[0,-1],"state":"open","outer":false},
		{"building":6,"level":0,"cell":[147,39],"side":[-1,0],"state":"open","outer":true},
		{"building":6,"level":0,"cell":[168,39],"side":[1,0],"state":"open","outer":true},
		{"building":6,"level":1,"cell":[158,38],"side":[0,1],"state":"open","outer":false},
		{"building":6,"level":1,"cell":[158,41],"side":[0,-1],"state":"open","outer":false},
		{"building":6,"level":2,"cell":[158,38],"side":[0,1],"state":"open","outer":false},
		{"building":6,"level":2,"cell":[158,41],"side":[0,-1],"state":"open","outer":false},
		{"building":7,"level":0,"cell":[153,73],"side":[0,1],"state":"open","outer":false},
		{"building":7,"level":0,"cell":[153,76],"side":[0,-1],"state":"open","outer":false},
		{"building":7,"level":0,"cell":[143,74],"side":[-1,0],"state":"open","outer":true},
		{"building":7,"level":0,"cell":[162,74],"side":[1,0],"state":"open","outer":true},
		{"building":7,"level":1,"cell":[153,73],"side":[0,1],"state":"open","outer":false},
		{"building":7,"level":1,"cell":[153,76],"side":[0,-1],"state":"open","outer":false},
		{"building":8,"level":0,"cell":[33,77],"side":[0,1],"state":"open","outer":false},
		{"building":8,"level":0,"cell":[33,80],"side":[0,-1],"state":"open","outer":false},
		{"building":8,"level":0,"cell":[25,78],"side":[-1,0],"state":"open","outer":true},
		{"building":8,"level":0,"cell":[40,78],"side":[1,0],"state":"open","outer":true},
		{"building":8,"level":1,"cell":[33,77],"side":[0,1],"state":"open","outer":false},
		{"building":8,"level":1,"cell":[33,80],"side":[0,-1],"state":"open","outer":false},
		{"building":9,"level":0,"cell":[38,22],"side":[0,1],"state":"open","outer":false},
		{"building":9,"level":0,"cell":[38,25],"side":[0,-1],"state":"open","outer":false},
		{"building":9,"level":0,"cell":[28,23],"side":[-1,0],"state":"open","outer":true},
		{"building":9,"level":0,"cell":[47,23],"side":[1,0],"state":"open","outer":true},
		{"building":10,"level":0,"cell":[61,24],"side":[1,0],"state":"open","outer":false},
		{"building":10,"level":0,"cell":[53,24],"side":[-1,0],"state":"open","outer":true},
		{"building":10,"level":0,"cell":[68,24],"side":[1,0],"state":"open","outer":true},
		{"building":12,"level":0,"cell":[146,91],"side":[-1,0],"state":"open","outer":true},
		{"building":12,"level":0,"cell":[157,91],"side":[1,0],"state":"open","outer":true},
		{"building":13,"level":0,"cell":[10,89],"side":[0,1],"state":"open","outer":false},
		{"building":13,"level":0,"cell":[10,92],"side":[0,-1],"state":"open","outer":false},
		{"building":13,"level":0,"cell":[3,90],"side":[-1,0],"state":"open","outer":true},
		{"building":13,"level":0,"cell":[16,90],"side":[1,0],"state":"open","outer":true},
		{"building":13,"level":1,"cell":[10,89],"side":[0,1],"state":"open","outer":false},
		{"building":13,"level":1,"cell":[10,92],"side":[0,-1],"state":"open","outer":false},
		{"building":14,"level":0,"cell":[159,62],"side":[1,0],"state":"open","outer":false},
		{"building":14,"level":0,"cell":[152,62],"side":[-1,0],"state":"open","outer":true},
		{"building":14,"level":0,"cell":[165,62],"side":[1,0],"state":"open","outer":true},
		{"building":14,"level":1,"cell":[159,62],"side":[1,0],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[30,95],"side":[1,0],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[24,95],"side":[-1,0],"state":"open","outer":true},
		{"building":15,"level":0,"cell":[35,95],"side":[1,0],"state":"open","outer":true},
		{"building":3,"level":0,"cell":[32,48],"side":[0,-1],"state":"open","outer":false},
		{"building":3,"level":0,"cell":[43,48],"side":[0,-1],"state":"open","outer":false},
		{"building":3,"level":0,"cell":[38,52],"side":[0,1],"state":"open","outer":true},
		{"building":11,"level":0,"cell":[103,23],"side":[1,0],"state":"open","outer":false},
		{"building":11,"level":0,"cell":[97,23],"side":[-1,0],"state":"open","outer":true},
		{"building":11,"level":0,"cell":[109,23],"side":[1,0],"state":"open","outer":true}
	],
	"windows": [
		{"building":0,"level":0,"cell":[70,66],"broken":false},
		{"building":0,"level":0,"cell":[70,101],"broken":false},
		{"building":0,"level":0,"cell":[105,66],"broken":false},
		{"building":0,"level":0,"cell":[105,101],"broken":false},
		{"building":0,"level":0,"cell":[48,68],"broken":false},
		{"building":0,"level":1,"cell":[50,66],"broken":false},
		{"building":0,"level":1,"cell":[50,101],"broken":false},
		{"building":0,"level":1,"cell":[53,66],"broken":false},
		{"building":0,"level":1,"cell":[53,101],"broken":false},
		{"building":0,"level":1,"cell":[48,68],"broken":false},
		{"building":1,"level":0,"cell":[51,52],"broken":false},
		{"building":1,"level":0,"cell":[51,63],"broken":false},
		{"building":1,"level":0,"cell":[56,52],"broken":false},
		{"building":1,"level":0,"cell":[56,63],"broken":false},
		{"building":1,"level":0,"cell":[48,54],"broken":false},
		{"building":1,"level":1,"cell":[51,52],"broken":false},
		{"building":1,"level":1,"cell":[51,63],"broken":false},
		{"building":1,"level":1,"cell":[56,52],"broken":false},
		{"building":1,"level":1,"cell":[56,63],"broken":false},
		{"building":1,"level":1,"cell":[48,54],"broken":false},
		{"building":1,"level":2,"cell":[51,52],"broken":false},
		{"building":1,"level":2,"cell":[51,63],"broken":false},
		{"building":1,"level":2,"cell":[56,52],"broken":false},
		{"building":1,"level":2,"cell":[56,63],"broken":false},
		{"building":1,"level":2,"cell":[48,54],"broken":false},
		{"building":2,"level":0,"cell":[133,61],"broken":false},
		{"building":2,"level":0,"cell":[133,68],"broken":false},
		{"building":2,"level":0,"cell":[136,61],"broken":false},
		{"building":2,"level":0,"cell":[136,68],"broken":false},
		{"building":2,"level":0,"cell":[130,63],"broken":false},
		{"building":3,"level":0,"cell":[32,35],"broken":false},
		{"building":3,"level":0,"cell":[32,52],"broken":false},
		{"building":3,"level":0,"cell":[41,35],"broken":false},
		{"building":3,"level":0,"cell":[41,52],"broken":false},
		{"building":3,"level":0,"cell":[26,37],"broken":false},
		{"building":3,"level":1,"cell":[32,35],"broken":false},
		{"building":3,"level":1,"cell":[32,52],"broken":false},
		{"building":3,"level":1,"cell":[41,35],"broken":false},
		{"building":3,"level":1,"cell":[41,52],"broken":false},
		{"building":3,"level":1,"cell":[26,37],"broken":false},
		{"building":3,"level":2,"cell":[32,35],"broken":false},
		{"building":3,"level":2,"cell":[32,52],"broken":false},
		{"building":3,"level":2,"cell":[41,35],"broken":false},
		{"building":3,"level":2,"cell":[41,52],"broken":false},
		{"building":3,"level":2,"cell":[26,37],"broken":false},
		{"building":4,"level":0,"cell":[8,62],"broken":false},
		{"building":4,"level":0,"cell":[8,79],"broken":false},
		{"building":4,"level":0,"cell":[16,62],"broken":false},
		{"building":4,"level":0,"cell":[16,79],"broken":false},
		{"building":4,"level":0,"cell":[3,64],"broken":false},
		{"building":4,"level":1,"cell":[8,62],"broken":false},
		{"building":4,"level":1,"cell":[8,79],"broken":false},
		{"building":4,"level":1,"cell":[16,62],"broken":false},
		{"building":4,"level":1,"cell":[16,79],"broken":false},
		{"building":4,"level":1,"cell":[3,64],"broken":false},
		{"building":4,"level":2,"cell":[8,62],"broken":false},
		{"building":4,"level":2,"cell":[8,79],"broken":false},
		{"building":4,"level":2,"cell":[16,62],"broken":false},
		{"building":4,"level":2,"cell":[16,79],"broken":false},
		{"building":4,"level":2,"cell":[3,64],"broken":false},
		{"building":5,"level":0,"cell":[129,15],"broken":false},
		{"building":5,"level":0,"cell":[129,34],"broken":false},
		{"building":5,"level":0,"cell":[139,15],"broken":false},
		{"building":5,"level":0,"cell":[139,34],"broken":false},
		{"building":5,"level":0,"cell":[123,17],"broken":false},
		{"building":5,"level":1,"cell":[129,15],"broken":false},
		{"building":5,"level":1,"cell":[129,34],"broken":false},
		{"building":5,"level":1,"cell":[139,15],"broken":false},
		{"building":5,"level":1,"cell":[139,34],"broken":false},
		{"building":5,"level":1,"cell":[123,17],"broken":false},
		{"building":5,"level":2,"cell":[129,15],"broken":false},
		{"building":5,"level":2,"cell":[129,34],"broken":false},
		{"building":5,"level":2,"cell":[139,15],"broken":false},
		{"building":5,"level":2,"cell":[139,34],"broken":false},
		{"building":5,"level":2,"cell":[123,17],"broken":false},
		{"building":6,"level":0,"cell":[153,32],"broken":false},
		{"building":6,"level":0,"cell":[153,47],"broken":false},
		{"building":6,"level":0,"cell":[162,32],"broken":false},
		{"building":6,"level":0,"cell":[162,47],"broken":false},
		{"building":6,"level":0,"cell":[147,34],"broken":false},
		{"building":6,"level":1,"cell":[153,32],"broken":false},
		{"building":6,"level":1,"cell":[153,47],"broken":false},
		{"building":6,"level":1,"cell":[162,32],"broken":false},
		{"building":6,"level":1,"cell":[162,47],"broken":false},
		{"building":6,"level":1,"cell":[147,34],"broken":false},
		{"building":6,"level":2,"cell":[153,32],"broken":false},
		{"building":6,"level":2,"cell":[153,47],"broken":false},
		{"building":6,"level":2,"cell":[162,32],"broken":false},
		{"building":6,"level":2,"cell":[162,47],"broken":false},
		{"building":6,"level":2,"cell":[147,34],"broken":false},
		{"building":7,"level":0,"cell":[148,68],"broken":false},
		{"building":7,"level":0,"cell":[148,81],"broken":false},
		{"building":7,"level":0,"cell":[156,68],"broken":false},
		{"building":7,"level":0,"cell":[156,81],"broken":false},
		{"building":7,"level":0,"cell":[143,70],"broken":false},
		{"building":7,"level":1,"cell":[148,68],"broken":false},
		{"building":7,"level":1,"cell":[148,81],"broken":false},
		{"building":7,"level":1,"cell":[156,68],"broken":false},
		{"building":7,"level":1,"cell":[156,81],"broken":false},
		{"building":7,"level":1,"cell":[143,70],"broken":false},
		{"building":8,"level":0,"cell":[29,73],"broken":false},
		{"building":8,"level":0,"cell":[29,84],"broken":false},
		{"building":8,"level":0,"cell":[36,73],"broken":false},
		{"building":8,"level":0,"cell":[36,84],"broken":false},
		{"building":8,"level":0,"cell":[25,75],"broken":false},
		{"building":8,"level":1,"cell":[29,73],"broken":false},
		{"building":8,"level":1,"cell":[29,84],"broken":false},
		{"building":8,"level":1,"cell":[36,73],"broken":false},
		{"building":8,"level":1,"cell":[36,84],"broken":false},
		{"building":8,"level":1,"cell":[25,75],"broken":false},
		{"building":9,"level":0,"cell":[33,18],"broken":false},
		{"building":9,"level":0,"cell":[33,29],"broken":false},
		{"building":9,"level":0,"cell":[41,18],"broken":false},
		{"building":9,"level":0,"cell":[41,29],"broken":false},
		{"building":9,"level":0,"cell":[28,20],"broken":false},
		{"building":10,"level":0,"cell":[57,20],"broken":false},
		{"building":10,"level":0,"cell":[57,27],"broken":false},
		{"building":10,"level":0,"cell":[64,20],"broken":false},
		{"building":10,"level":0,"cell":[64,27],"broken":false},
		{"building":10,"level":0,"cell":[53,22],"broken":false},
		{"building":12,"level":0,"cell":[149,87],"broken":false},
		{"building":12,"level":0,"cell":[149,94],"broken":false},
		{"building":12,"level":0,"cell":[154,87],"broken":false},
		{"building":12,"level":0,"cell":[154,94],"broken":false},
		{"building":12,"level":0,"cell":[146,89],"broken":false},
		{"building":13,"level":0,"cell":[7,85],"broken":false},
		{"building":13,"level":0,"cell":[7,96],"broken":false},
		{"building":13,"level":0,"cell":[12,85],"broken":false},
		{"building":13,"level":0,"cell":[12,96],"broken":false},
		{"building":13,"level":0,"cell":[3,87],"broken":false},
		{"building":13,"level":1,"cell":[7,85],"broken":false},
		{"building":13,"level":1,"cell":[7,96],"broken":false},
		{"building":13,"level":1,"cell":[12,85],"broken":false},
		{"building":13,"level":1,"cell":[12,96],"broken":false},
		{"building":13,"level":1,"cell":[3,87],"broken":false},
		{"building":14,"level":0,"cell":[156,57],"broken":false},
		{"building":14,"level":0,"cell":[156,66],"broken":false},
		{"building":14,"level":0,"cell":[161,57],"broken":false},
		{"building":14,"level":0,"cell":[161,66],"broken":false},
		{"building":14,"level":0,"cell":[152,59],"broken":false},
		{"building":14,"level":1,"cell":[156,57],"broken":false},
		{"building":14,"level":1,"cell":[156,66],"broken":false},
		{"building":14,"level":1,"cell":[161,57],"broken":false},
		{"building":14,"level":1,"cell":[161,66],"broken":false},
		{"building":14,"level":1,"cell":[152,59],"broken":false},
		{"building":15,"level":0,"cell":[27,90],"broken":false},
		{"building":15,"level":0,"cell":[27,99],"broken":false},
		{"building":15,"level":0,"cell":[32,90],"broken":false},
		{"building":15,"level":0,"cell":[32,99],"broken":false},
		{"building":15,"level":0,"cell":[24,92],"broken":false},
		{"building":11,"level":0,"cell":[100,18],"broken":false},
		{"building":11,"level":0,"cell":[100,27],"broken":false},
		{"building":11,"level":0,"cell":[105,18],"broken":false},
		{"building":11,"level":0,"cell":[105,27],"broken":false},
		{"building":11,"level":0,"cell":[97,20],"broken":false}
	],
	"stairs": [
		{"cell":[49,68],"low":0,"high":1,"ladder":false},
		{"cell":[105,68],"low":-1,"high":0,"ladder":false},
		{"cell":[126,99],"low":-1,"high":0,"ladder":false},
		{"cell":[49,53],"low":0,"high":1,"ladder":false},
		{"cell":[58,62],"low":1,"high":2,"ladder":false},
		{"cell":[28,43],"low":0,"high":1,"ladder":false},
		{"cell":[28,43],"low":1,"high":2,"ladder":false},
		{"cell":[5,70],"low":0,"high":1,"ladder":false},
		{"cell":[5,70],"low":1,"high":2,"ladder":false},
		{"cell":[125,24],"low":0,"high":1,"ladder":false},
		{"cell":[125,24],"low":1,"high":2,"ladder":false},
		{"cell":[149,39],"low":0,"high":1,"ladder":false},
		{"cell":[149,39],"low":1,"high":2,"ladder":false},
		{"cell":[145,74],"low":0,"high":1,"ladder":false},
		{"cell":[27,78],"low":0,"high":1,"ladder":false},
		{"cell":[5,90],"low":0,"high":1,"ladder":false},
		{"cell":[154,61],"low":0,"high":1,"ladder":false}
	],
	"props": [
		{"kind":"bell_rope","rect":[50,55,1,1],"solid":"none","facing":0,"note":"종 줄 한 가닥","level":1},
		{"kind":"bell_frame","rect":[54,54,4,3],"solid":"none","facing":1,"note":"종을 거는 나무 틀","level":2},
		{"kind":"floor_shell","rect":[26,35,22,18],"solid":"none","facing":2,"note":"살림집 사층 겉모양","level":3},
		{"kind":"stair_stub","rect":[27,43,1,2],"solid":"none","facing":3,"note":"사층 계단 예정 자리","level":2},
		{"kind":"floor_shell","rect":[3,62,20,18],"solid":"none","facing":0,"note":"살림집 사층 겉모양","level":3},
		{"kind":"stair_stub","rect":[4,70,1,2],"solid":"none","facing":1,"note":"사층 계단 예정 자리","level":2},
		{"kind":"floor_shell","rect":[123,15,24,20],"solid":"none","facing":2,"note":"살림집 사층 겉모양","level":3},
		{"kind":"stair_stub","rect":[124,24,1,2],"solid":"none","facing":3,"note":"사층 계단 예정 자리","level":2},
		{"kind":"floor_shell","rect":[147,32,22,16],"solid":"none","facing":0,"note":"살림집 사층 겉모양","level":3},
		{"kind":"stair_stub","rect":[148,39,1,2],"solid":"none","facing":1,"note":"사층 계단 예정 자리","level":2},
		{"kind":"car","rect":[31,11,4,2],"solid":"low","facing":2,"note":"길가에 선 차","level":0},
		{"kind":"bench","rect":[50,12,3,1],"solid":"low","facing":3,"note":"긴 의자","level":0},
		{"kind":"crate_stack","rect":[66,12,2,2],"solid":"low","facing":0,"note":"나무 상자","level":0},
		{"kind":"car","rect":[74,24,4,2],"solid":"low","facing":1,"note":"길가에 선 차","level":0},
		{"kind":"nave_pillar","rect":[62,78,2,2],"solid":"wall","facing":2,"note":"본당 돌기둥","level":0},
		{"kind":"nave_pillar","rect":[72,78,2,2],"solid":"wall","facing":3,"note":"본당 돌기둥","level":0},
		{"kind":"nave_pillar","rect":[82,78,2,2],"solid":"wall","facing":0,"note":"본당 돌기둥","level":0},
		{"kind":"nave_pillar","rect":[94,78,2,2],"solid":"wall","facing":1,"note":"본당 돌기둥","level":0},
		{"kind":"nave_pillar","rect":[104,78,2,2],"solid":"wall","facing":2,"note":"본당 돌기둥","level":0},
		{"kind":"nave_pillar","rect":[114,78,2,2],"solid":"wall","facing":3,"note":"본당 돌기둥","level":0},
		{"kind":"nave_pillar","rect":[62,88,2,2],"solid":"wall","facing":0,"note":"본당 돌기둥","level":0},
		{"kind":"nave_pillar","rect":[72,88,2,2],"solid":"wall","facing":1,"note":"본당 돌기둥","level":0},
		{"kind":"nave_pillar","rect":[82,88,2,2],"solid":"wall","facing":2,"note":"본당 돌기둥","level":0},
		{"kind":"nave_pillar","rect":[94,88,2,2],"solid":"wall","facing":3,"note":"본당 돌기둥","level":0},
		{"kind":"nave_pillar","rect":[104,88,2,2],"solid":"wall","facing":0,"note":"본당 돌기둥","level":0},
		{"kind":"nave_pillar","rect":[114,88,2,2],"solid":"wall","facing":1,"note":"본당 돌기둥","level":0},
		{"kind":"frozen_fountain","rect":[84,46,4,4],"solid":"low","facing":2,"note":"얼어 있는 분수","level":0},
		{"kind":"market_stall","rect":[61,39,3,2],"solid":"low","facing":3,"note":"시장 좌판","level":0},
		{"kind":"market_stall","rect":[70,41,3,2],"solid":"low","facing":0,"note":"시장 좌판","level":0},
		{"kind":"market_stall","rect":[63,46,3,2],"solid":"low","facing":1,"note":"시장 좌판","level":0},
		{"kind":"crate_stack","rect":[68,47,2,2],"solid":"low","facing":2,"note":"나무 상자","level":0},
		{"kind":"crate_stack","rect":[74,46,2,2],"solid":"low","facing":3,"note":"나무 상자","level":0},
		{"kind":"barrel","rect":[69,50,1,1],"solid":"low","facing":0,"note":"저장 통","level":0},
		{"kind":"pallet_stack","rect":[77,49,2,2],"solid":"low","facing":1,"note":"평평한 하역 문 곁 팰릿","level":0},
		{"kind":"car","rect":[134,53,4,2],"solid":"low","facing":2,"note":"길가에 선 차","level":0},
		{"kind":"car","rect":[143,54,4,2],"solid":"low","facing":3,"note":"길가에 선 차","level":0},
		{"kind":"lamp_post","rect":[39,58,1,1],"solid":"none","facing":0,"note":"꺼진 등잔 기둥","level":0},
		{"kind":"crate_stack","rect":[43,61,2,2],"solid":"low","facing":1,"note":"나무 상자","level":0},
		{"kind":"snow_drift","rect":[34,60,4,2],"solid":"none","facing":2,"note":"모서리의 눈더미","level":0},
		{"kind":"community_banner","rect":[101,59,1,2],"solid":"none","facing":3,"note":"무늬 없는 바랜 천 깃발","level":0},
		{"kind":"bare_tree","rect":[8,16,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[12,24,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[20,31,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[6,34,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[12,39,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[19,53,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[6,58,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[26,62,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[32,65,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[44,70,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[44,77,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[43,92,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[5,100,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[9,102,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[14,99,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[129,98,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[133,89,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[166,96,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[168,90,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[171,45,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[157,27,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[169,26,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[159,18,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[153,11,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[120,12,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[120,28,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[119,33,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[116,36,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[110,38,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[56,35,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[56,43,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[93,31,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"hymn_shelf","rect":[49,67,2,1],"solid":"low","facing":0,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[62,71,1,1],"solid":"low","facing":1,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[49,71,2,1],"solid":"low","facing":2,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[62,67,1,1],"solid":"low","facing":3,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[61,100,2,1],"solid":"low","facing":0,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[49,100,1,1],"solid":"low","facing":1,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[61,96,2,1],"solid":"low","facing":2,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[50,96,1,1],"solid":"low","facing":3,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[64,71,2,1],"solid":"low","facing":0,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[78,67,1,1],"solid":"low","facing":1,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[65,67,2,1],"solid":"low","facing":2,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[77,71,1,1],"solid":"low","facing":3,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[77,96,2,1],"solid":"low","facing":0,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[65,96,1,1],"solid":"low","facing":1,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[76,100,2,1],"solid":"low","facing":2,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[64,96,1,1],"solid":"low","facing":3,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[81,67,2,1],"solid":"low","facing":0,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[93,71,1,1],"solid":"low","facing":1,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[80,71,2,1],"solid":"low","facing":2,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[94,71,1,1],"solid":"low","facing":3,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[92,100,2,1],"solid":"low","facing":0,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[80,96,1,1],"solid":"low","facing":1,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[80,100,2,1],"solid":"low","facing":2,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[94,96,1,1],"solid":"low","facing":3,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[96,67,2,1],"solid":"low","facing":0,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[110,71,1,1],"solid":"low","facing":1,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[96,71,2,1],"solid":"low","facing":2,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[110,67,1,1],"solid":"low","facing":3,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[109,100,2,1],"solid":"low","facing":0,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[96,100,1,1],"solid":"low","facing":1,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[109,96,2,1],"solid":"low","facing":2,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[97,96,1,1],"solid":"low","facing":3,"note":"글씨 없는 손종","level":0},
		{"kind":"parish_chest","rect":[112,71,2,1],"solid":"low","facing":0,"note":"회중 기록 궤","level":0},
		{"kind":"hymn_shelf","rect":[125,67,2,1],"solid":"low","facing":1,"note":"찬송집 선반","level":0},
		{"kind":"desk","rect":[113,67,2,1],"solid":"low","facing":2,"note":"책상","level":0},
		{"kind":"candle_stand","rect":[125,71,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"hymn_shelf","rect":[125,96,2,1],"solid":"low","facing":0,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[113,96,1,1],"solid":"low","facing":1,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[124,100,2,1],"solid":"low","facing":2,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[112,96,1,1],"solid":"low","facing":3,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[52,83,2,1],"solid":"none","facing":0,"note":"찬송집 선반","level":1},
		{"kind":"candle_stand","rect":[49,67,1,1],"solid":"none","facing":1,"note":"초 하나가 선 외줄기 촛대","level":1},
		{"kind":"vestry_chest","rect":[49,83,2,1],"solid":"none","facing":2,"note":"제의실 궤","level":1},
		{"kind":"hand_bell","rect":[54,67,1,1],"solid":"none","facing":3,"note":"글씨 없는 손종","level":1},
		{"kind":"hymn_shelf","rect":[49,85,2,1],"solid":"none","facing":0,"note":"찬송집 선반","level":1},
		{"kind":"candle_stand","rect":[54,100,1,1],"solid":"none","facing":1,"note":"초 하나가 선 외줄기 촛대","level":1},
		{"kind":"vestry_chest","rect":[49,100,2,1],"solid":"none","facing":2,"note":"제의실 궤","level":1},
		{"kind":"hand_bell","rect":[54,85,1,1],"solid":"none","facing":3,"note":"글씨 없는 손종","level":1},
		{"kind":"cold_stove","rect":[115,97,1,1],"solid":"none","facing":0,"note":"꺼진 난로","level":-1},
		{"kind":"coal_bin","rect":[108,96,3,2],"solid":"none","facing":1,"note":"난방용 석탄","level":-1},
		{"kind":"firewood_pile","rect":[114,70,2,1],"solid":"none","facing":2,"note":"처마 밑 장작","level":-1},
		{"kind":"barrel","rect":[109,70,1,1],"solid":"none","facing":3,"note":"저장 통","level":-1},
		{"kind":"cask_stack","rect":[117,96,2,2],"solid":"none","facing":0,"note":"저장고 큰 통","level":-1},
		{"kind":"sack_pile","rect":[122,70,2,2],"solid":"none","facing":1,"note":"곡물 자루","level":-1},
		{"kind":"relief_crate","rect":[118,70,2,1],"solid":"none","facing":2,"note":"남은 구호 식량 상자","level":-1},
		{"kind":"barrel","rect":[122,97,1,1],"solid":"none","facing":3,"note":"저장 통","level":-1},
		{"kind":"hand_bell","rect":[50,53,1,1],"solid":"low","facing":0,"note":"글씨 없는 손종","level":0},
		{"kind":"lamp_shelf","rect":[50,62,2,1],"solid":"low","facing":1,"note":"꺼진 등잔 선반","level":0},
		{"kind":"candle_stand","rect":[52,62,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"hand_bell","rect":[57,62,1,1],"solid":"low","facing":3,"note":"글씨 없는 손종","level":0},
		{"kind":"lamp_shelf","rect":[54,53,2,1],"solid":"low","facing":0,"note":"꺼진 등잔 선반","level":0},
		{"kind":"bench","rect":[54,62,3,1],"solid":"low","facing":1,"note":"긴 의자","level":0},
		{"kind":"candle_stand","rect":[58,53,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"hand_bell","rect":[52,62,1,1],"solid":"none","facing":3,"note":"글씨 없는 손종","level":1},
		{"kind":"lamp_shelf","rect":[49,62,2,1],"solid":"none","facing":0,"note":"꺼진 등잔 선반","level":1},
		{"kind":"bench","rect":[50,53,3,1],"solid":"none","facing":1,"note":"긴 의자","level":1},
		{"kind":"candle_stand","rect":[51,62,1,1],"solid":"none","facing":2,"note":"초 하나가 선 외줄기 촛대","level":1},
		{"kind":"hand_bell","rect":[54,62,1,1],"solid":"none","facing":3,"note":"글씨 없는 손종","level":1},
		{"kind":"lamp_shelf","rect":[57,53,2,1],"solid":"none","facing":0,"note":"꺼진 등잔 선반","level":1},
		{"kind":"bench","rect":[55,62,3,1],"solid":"none","facing":1,"note":"긴 의자","level":1},
		{"kind":"candle_stand","rect":[55,53,1,1],"solid":"none","facing":2,"note":"초 하나가 선 외줄기 촛대","level":1},
		{"kind":"hand_bell","rect":[49,62,1,1],"solid":"none","facing":3,"note":"글씨 없는 손종","level":2},
		{"kind":"lamp_shelf","rect":[51,53,2,1],"solid":"none","facing":0,"note":"꺼진 등잔 선반","level":2},
		{"kind":"bench","rect":[50,62,3,1],"solid":"none","facing":1,"note":"긴 의자","level":2},
		{"kind":"candle_stand","rect":[49,53,1,1],"solid":"none","facing":2,"note":"초 하나가 선 외줄기 촛대","level":2},
		{"kind":"hand_bell","rect":[58,53,1,1],"solid":"none","facing":3,"note":"글씨 없는 손종","level":2},
		{"kind":"lamp_shelf","rect":[55,53,2,1],"solid":"none","facing":0,"note":"꺼진 등잔 선반","level":2},
		{"kind":"bench","rect":[55,62,3,1],"solid":"none","facing":1,"note":"긴 의자","level":2},
		{"kind":"candle_stand","rect":[54,53,1,1],"solid":"none","facing":2,"note":"초 하나가 선 외줄기 촛대","level":2},
		{"kind":"bed","rect":[132,62,2,1],"solid":"low","facing":3,"note":"침대","level":0},
		{"kind":"desk","rect":[136,67,2,1],"solid":"low","facing":0,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[131,62,1,1],"solid":"low","facing":1,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[131,67,3,1],"solid":"low","facing":2,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[34,36,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[28,36,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[34,41,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[27,41,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[28,46,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[33,51,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[27,46,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[27,51,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[44,41,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[37,36,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[46,41,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[37,41,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[37,46,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[45,51,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[37,51,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[44,46,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[34,41,2,1],"solid":"none","facing":3,"note":"침대","level":2},
		{"kind":"desk","rect":[27,41,2,1],"solid":"none","facing":0,"note":"책상","level":2},
		{"kind":"cold_stove","rect":[35,36,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":2},
		{"kind":"shelf","rect":[28,36,3,1],"solid":"none","facing":2,"note":"물건 선반","level":2},
		{"kind":"bed","rect":[27,51,2,1],"solid":"none","facing":3,"note":"침대","level":2},
		{"kind":"desk","rect":[34,46,2,1],"solid":"none","facing":0,"note":"책상","level":2},
		{"kind":"cold_stove","rect":[28,46,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":2},
		{"kind":"shelf","rect":[32,51,3,1],"solid":"none","facing":2,"note":"물건 선반","level":2},
		{"kind":"bed","rect":[45,36,2,1],"solid":"none","facing":3,"note":"침대","level":2},
		{"kind":"desk","rect":[38,36,2,1],"solid":"none","facing":0,"note":"책상","level":2},
		{"kind":"cold_stove","rect":[45,41,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":2},
		{"kind":"shelf","rect":[37,41,3,1],"solid":"none","facing":2,"note":"물건 선반","level":2},
		{"kind":"bed","rect":[38,46,2,1],"solid":"none","facing":3,"note":"침대","level":2},
		{"kind":"desk","rect":[44,51,2,1],"solid":"none","facing":0,"note":"책상","level":2},
		{"kind":"cold_stove","rect":[37,46,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":2},
		{"kind":"shelf","rect":[37,51,3,1],"solid":"none","facing":2,"note":"물건 선반","level":2},
		{"kind":"display_shelf","rect":[17,68,4,1],"solid":"low","facing":3,"note":"가게 진열대","level":0},
		{"kind":"shop_counter","rect":[4,63,3,1],"solid":"low","facing":0,"note":"가게 계산대","level":0},
		{"kind":"freezer_chest","rect":[4,68,2,1],"solid":"low","facing":1,"note":"냉동 궤","level":0},
		{"kind":"barrel","rect":[21,63,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"display_shelf","rect":[4,73,4,1],"solid":"low","facing":3,"note":"가게 진열대","level":0},
		{"kind":"shop_counter","rect":[19,78,3,1],"solid":"low","facing":0,"note":"가게 계산대","level":0},
		{"kind":"freezer_chest","rect":[4,78,2,1],"solid":"low","facing":1,"note":"냉동 궤","level":0},
		{"kind":"barrel","rect":[21,73,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"bed","rect":[20,68,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[4,68,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[21,63,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[5,63,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[4,78,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[20,73,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[5,73,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[18,78,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[20,63,2,1],"solid":"none","facing":3,"note":"침대","level":2},
		{"kind":"desk","rect":[5,63,2,1],"solid":"none","facing":0,"note":"책상","level":2},
		{"kind":"cold_stove","rect":[20,68,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":2},
		{"kind":"shelf","rect":[4,68,3,1],"solid":"none","facing":2,"note":"물건 선반","level":2},
		{"kind":"bed","rect":[5,73,2,1],"solid":"none","facing":3,"note":"침대","level":2},
		{"kind":"desk","rect":[19,78,2,1],"solid":"none","facing":0,"note":"책상","level":2},
		{"kind":"cold_stove","rect":[4,73,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":2},
		{"kind":"shelf","rect":[4,78,3,1],"solid":"none","facing":2,"note":"물건 선반","level":2},
		{"kind":"display_shelf","rect":[124,16,4,1],"solid":"low","facing":3,"note":"가게 진열대","level":0},
		{"kind":"shop_counter","rect":[131,22,3,1],"solid":"low","facing":0,"note":"가게 계산대","level":0},
		{"kind":"freezer_chest","rect":[124,22,2,1],"solid":"low","facing":1,"note":"냉동 궤","level":0},
		{"kind":"barrel","rect":[133,16,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"display_shelf","rect":[124,27,4,1],"solid":"low","facing":3,"note":"가게 진열대","level":0},
		{"kind":"shop_counter","rect":[131,33,3,1],"solid":"low","facing":0,"note":"가게 계산대","level":0},
		{"kind":"freezer_chest","rect":[124,33,2,1],"solid":"low","facing":1,"note":"냉동 궤","level":0},
		{"kind":"barrel","rect":[133,27,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"display_shelf","rect":[142,22,4,1],"solid":"low","facing":3,"note":"가게 진열대","level":0},
		{"kind":"shop_counter","rect":[135,22,3,1],"solid":"low","facing":0,"note":"가게 계산대","level":0},
		{"kind":"freezer_chest","rect":[144,16,2,1],"solid":"low","facing":1,"note":"냉동 궤","level":0},
		{"kind":"barrel","rect":[136,16,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"display_shelf","rect":[135,33,4,1],"solid":"low","facing":3,"note":"가게 진열대","level":0},
		{"kind":"shop_counter","rect":[143,27,3,1],"solid":"low","facing":0,"note":"가게 계산대","level":0},
		{"kind":"freezer_chest","rect":[136,27,2,1],"solid":"low","facing":1,"note":"냉동 궤","level":0},
		{"kind":"barrel","rect":[144,33,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"bed","rect":[132,16,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[125,16,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[132,22,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[124,22,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[125,27,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[131,33,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[124,27,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[124,33,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[143,22,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[135,16,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[145,22,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[135,22,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[135,27,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[144,33,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[135,33,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[143,27,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[132,22,2,1],"solid":"none","facing":3,"note":"침대","level":2},
		{"kind":"desk","rect":[124,22,2,1],"solid":"none","facing":0,"note":"책상","level":2},
		{"kind":"cold_stove","rect":[133,16,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":2},
		{"kind":"shelf","rect":[125,16,3,1],"solid":"none","facing":2,"note":"물건 선반","level":2},
		{"kind":"bed","rect":[124,33,2,1],"solid":"none","facing":3,"note":"침대","level":2},
		{"kind":"desk","rect":[132,27,2,1],"solid":"none","facing":0,"note":"책상","level":2},
		{"kind":"cold_stove","rect":[125,27,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":2},
		{"kind":"shelf","rect":[130,33,3,1],"solid":"none","facing":2,"note":"물건 선반","level":2},
		{"kind":"bed","rect":[144,16,2,1],"solid":"none","facing":3,"note":"침대","level":2},
		{"kind":"desk","rect":[136,16,2,1],"solid":"none","facing":0,"note":"책상","level":2},
		{"kind":"cold_stove","rect":[144,22,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":2},
		{"kind":"shelf","rect":[135,22,3,1],"solid":"none","facing":2,"note":"물건 선반","level":2},
		{"kind":"bed","rect":[136,27,2,1],"solid":"none","facing":3,"note":"침대","level":2},
		{"kind":"desk","rect":[143,33,2,1],"solid":"none","facing":0,"note":"책상","level":2},
		{"kind":"cold_stove","rect":[135,27,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":2},
		{"kind":"shelf","rect":[135,33,3,1],"solid":"none","facing":2,"note":"물건 선반","level":2},
		{"kind":"bed","rect":[165,37,2,1],"solid":"low","facing":3,"note":"침대","level":0},
		{"kind":"desk","rect":[148,33,2,1],"solid":"low","facing":0,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[167,37,1,1],"solid":"low","facing":1,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[148,37,3,1],"solid":"low","facing":2,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[148,42,2,1],"solid":"low","facing":3,"note":"침대","level":0},
		{"kind":"desk","rect":[166,46,2,1],"solid":"low","facing":0,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[148,46,1,1],"solid":"low","facing":1,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[165,42,3,1],"solid":"low","facing":2,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[166,37,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[148,37,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[167,33,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[149,33,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[148,46,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[166,42,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[149,42,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[164,46,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[166,33,2,1],"solid":"none","facing":3,"note":"침대","level":2},
		{"kind":"desk","rect":[149,33,2,1],"solid":"none","facing":0,"note":"책상","level":2},
		{"kind":"cold_stove","rect":[166,37,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":2},
		{"kind":"shelf","rect":[148,37,3,1],"solid":"none","facing":2,"note":"물건 선반","level":2},
		{"kind":"bed","rect":[149,42,2,1],"solid":"none","facing":3,"note":"침대","level":2},
		{"kind":"desk","rect":[165,46,2,1],"solid":"none","facing":0,"note":"책상","level":2},
		{"kind":"cold_stove","rect":[148,42,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":2},
		{"kind":"shelf","rect":[148,46,3,1],"solid":"none","facing":2,"note":"물건 선반","level":2},
		{"kind":"bed","rect":[159,72,2,1],"solid":"low","facing":3,"note":"침대","level":0},
		{"kind":"desk","rect":[144,69,2,1],"solid":"low","facing":0,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[161,72,1,1],"solid":"low","facing":1,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[144,72,3,1],"solid":"low","facing":2,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[144,77,2,1],"solid":"low","facing":3,"note":"침대","level":0},
		{"kind":"desk","rect":[160,80,2,1],"solid":"low","facing":0,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[144,80,1,1],"solid":"low","facing":1,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[159,77,3,1],"solid":"low","facing":2,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[160,72,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[144,72,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[161,69,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[145,69,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[144,80,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[160,77,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[145,77,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[158,80,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[38,74,2,1],"solid":"low","facing":3,"note":"침대","level":0},
		{"kind":"desk","rect":[27,74,2,1],"solid":"low","facing":0,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[38,76,1,1],"solid":"low","facing":1,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[26,76,3,1],"solid":"low","facing":2,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[27,81,2,1],"solid":"low","facing":3,"note":"침대","level":0},
		{"kind":"desk","rect":[37,83,2,1],"solid":"low","facing":0,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[26,81,1,1],"solid":"low","facing":1,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[26,83,3,1],"solid":"low","facing":2,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[37,76,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[26,74,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[39,76,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[26,76,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[26,81,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[38,83,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[26,83,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[37,81,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"cold_stove","rect":[156,93,1,1],"solid":"low","facing":3,"note":"꺼진 난로","level":0},
		{"kind":"coal_bin","rect":[147,92,3,2],"solid":"low","facing":0,"note":"난방용 석탄","level":0},
		{"kind":"firewood_pile","rect":[155,88,2,1],"solid":"low","facing":1,"note":"처마 밑 장작","level":0},
		{"kind":"barrel","rect":[148,88,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"bed","rect":[4,88,2,1],"solid":"low","facing":3,"note":"침대","level":0},
		{"kind":"desk","rect":[14,86,2,1],"solid":"low","facing":0,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[5,86,1,1],"solid":"low","facing":1,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[12,88,3,1],"solid":"low","facing":2,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[14,93,2,1],"solid":"low","facing":3,"note":"침대","level":0},
		{"kind":"desk","rect":[5,93,2,1],"solid":"low","facing":0,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[14,95,1,1],"solid":"low","facing":1,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[4,95,3,1],"solid":"low","facing":2,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[5,86,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[13,88,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[4,86,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[4,88,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[13,95,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[4,93,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[15,95,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[4,95,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[153,58,2,1],"solid":"low","facing":3,"note":"침대","level":0},
		{"kind":"desk","rect":[157,65,2,1],"solid":"low","facing":0,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[153,65,1,1],"solid":"low","facing":1,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[156,58,3,1],"solid":"low","facing":2,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[163,65,2,1],"solid":"low","facing":3,"note":"침대","level":0},
		{"kind":"desk","rect":[160,65,2,1],"solid":"low","facing":0,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[164,58,1,1],"solid":"low","facing":1,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[161,58,3,1],"solid":"low","facing":2,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[153,65,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[157,58,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[154,58,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[155,65,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[163,58,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[161,58,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[163,65,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[160,65,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[26,91,2,1],"solid":"low","facing":3,"note":"침대","level":0},
		{"kind":"desk","rect":[27,98,2,1],"solid":"low","facing":0,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[25,91,1,1],"solid":"low","facing":1,"note":"꺼진 난로","level":0},
		{"kind":"bed","rect":[32,98,2,1],"solid":"low","facing":2,"note":"침대","level":0},
		{"kind":"desk","rect":[31,91,2,1],"solid":"low","facing":3,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[34,98,1,1],"solid":"low","facing":0,"note":"꺼진 난로","level":0},
		{"kind":"display_shelf","rect":[29,37,1,4],"solid":"low","facing":1,"note":"가게 진열대","level":0},
		{"kind":"display_shelf","rect":[32,37,1,4],"solid":"low","facing":2,"note":"가게 진열대","level":0},
		{"kind":"display_shelf","rect":[35,37,1,4],"solid":"low","facing":3,"note":"가게 진열대","level":0},
		{"kind":"display_shelf","rect":[42,37,1,4],"solid":"low","facing":0,"note":"가게 진열대","level":0},
		{"kind":"display_shelf","rect":[45,37,1,4],"solid":"low","facing":1,"note":"가게 진열대","level":0},
		{"kind":"checkout","rect":[43,42,2,1],"solid":"low","facing":2,"note":"식료품 계산대","level":0},
		{"kind":"shopping_cart","rect":[27,36,1,1],"solid":"low","facing":3,"note":"장보기 수레","level":0},
		{"kind":"shopping_cart","rect":[27,38,1,1],"solid":"low","facing":0,"note":"장보기 수레","level":0},
		{"kind":"freezer_chest","rect":[40,36,2,1],"solid":"low","facing":1,"note":"냉동 궤","level":0},
		{"kind":"freezer_chest","rect":[40,40,2,1],"solid":"low","facing":2,"note":"냉동 궤","level":0},
		{"kind":"pallet_stack","rect":[27,49,2,2],"solid":"low","facing":3,"note":"평평한 하역 문 곁 팰릿","level":0},
		{"kind":"sack_pile","rect":[35,49,2,2],"solid":"low","facing":0,"note":"곡물 자루","level":0},
		{"kind":"desk","rect":[40,49,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"shelf","rect":[44,50,3,1],"solid":"low","facing":2,"note":"물건 선반","level":0},
		{"kind":"shop_counter","rect":[28,45,3,1],"solid":"low","facing":3,"note":"가게 계산대","level":0},
		{"kind":"dough_table","rect":[34,45,2,1],"solid":"low","facing":0,"note":"반죽대","level":0},
		{"kind":"community_banner","rect":[4,63,1,2],"solid":"none","facing":1,"note":"무늬 없는 바랜 천 깃발","level":2},
		{"kind":"hand_bell","rect":[124,16,1,1],"solid":"none","facing":2,"note":"글씨 없는 손종","level":1},
		{"kind":"hymn_shelf","rect":[30,36,2,1],"solid":"none","facing":3,"note":"찬송집 선반","level":1},
		{"kind":"pew_row","rect":[50,73,6,1],"solid":"low","facing":0,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[92,73,6,1],"solid":"low","facing":1,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[50,75,6,1],"solid":"low","facing":2,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[92,75,6,1],"solid":"low","facing":3,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[50,77,6,1],"solid":"low","facing":0,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[92,77,6,1],"solid":"low","facing":1,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[50,79,6,1],"solid":"low","facing":2,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[96,79,6,1],"solid":"low","facing":3,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[50,81,6,1],"solid":"low","facing":0,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[92,81,6,1],"solid":"low","facing":1,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"market_stall","rect":[106,49,3,2],"solid":"low","facing":2,"note":"시장 좌판","level":0},
		{"kind":"bread_rack","rect":[28,36,1,1],"solid":"low","facing":3,"note":"빵 선반","level":0},
		{"kind":"bread_rack","rect":[29,36,1,1],"solid":"low","facing":0,"note":"빵 선반","level":0},
		{"kind":"checkout","rect":[30,36,2,1],"solid":"low","facing":1,"note":"식료품 계산대","level":0},
		{"kind":"bare_tree","rect":[115,25,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[115,21,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"altar_table","rect":[123,74,3,1],"solid":"low","facing":0,"note":"무늬 없는 천을 덮은 제단 탁자","level":0},
		{"kind":"pulpit","rect":[121,74,2,2],"solid":"low","facing":1,"note":"설교단","level":0},
		{"kind":"candle_stand","rect":[120,74,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"candle_stand","rect":[118,74,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"community_banner","rect":[117,74,1,2],"solid":"none","facing":0,"note":"무늬 없는 바랜 천 깃발","level":0},
		{"kind":"lamp_shelf","rect":[43,57,2,1],"solid":"low","facing":1,"note":"맨홀 곁 꺼진 등잔","level":0},
		{"kind":"crate_stack","rect":[36,63,2,2],"solid":"low","facing":2,"note":"맨홀 곁 나무 상자","level":0},
		{"kind":"blanket_screen","rect":[35,57,3,1],"solid":"low","facing":3,"note":"맨홀 곁 반쯤 접힌 젖은 담요","level":0}
	],
	"rooms": [
		{"building":0,"level":0,"rect":[49,67,14,5],"name":"찬송집 방","theme":"church"},
		{"building":0,"level":0,"rect":[49,96,14,5],"name":"종지기 방","theme":"church"},
		{"building":0,"level":0,"rect":[64,67,15,5],"name":"현관 방","theme":"church"},
		{"building":0,"level":0,"rect":[64,96,15,5],"name":"옆 예배실","theme":"church"},
		{"building":0,"level":0,"rect":[80,67,15,5],"name":"제의실","theme":"church"},
		{"building":0,"level":0,"rect":[80,96,15,5],"name":"회중 준비방","theme":"church"},
		{"building":0,"level":0,"rect":[96,67,15,5],"name":"교구 사무방","theme":"church"},
		{"building":0,"level":0,"rect":[96,96,15,5],"name":"성가대방","theme":"church"},
		{"building":0,"level":0,"rect":[112,67,15,5],"name":"기록방","theme":"archive"},
		{"building":0,"level":0,"rect":[112,96,15,5],"name":"서고","theme":"church"},
		{"building":0,"level":0,"rect":[49,73,78,22],"name":"회중석","theme":"nave"},
		{"building":0,"level":1,"rect":[49,67,6,17],"name":"합창 다락 앞방","theme":"church"},
		{"building":0,"level":1,"rect":[49,85,6,16],"name":"합창 다락 뒷방","theme":"church"},
		{"building":0,"level":-1,"rect":[108,70,8,28],"name":"난방실","theme":"heat"},
		{"building":0,"level":-1,"rect":[117,70,7,28],"name":"막다른 식량 저장실","theme":"cellar"},
		{"building":0,"level":-1,"rect":[105,67,22,2],"name":"저장고 둘레 통로","theme":"corridor"},
		{"building":1,"level":0,"rect":[49,53,4,10],"name":"탑 아래 앞방","theme":"tower"},
		{"building":1,"level":0,"rect":[54,53,5,10],"name":"탑 아래 뒷방","theme":"tower"},
		{"building":1,"level":1,"rect":[49,53,4,10],"name":"종 줄 방","theme":"tower"},
		{"building":1,"level":1,"rect":[54,53,5,10],"name":"종 줄 방의 돌아가는 길","theme":"tower"},
		{"building":1,"level":2,"rect":[49,53,4,10],"name":"종 다락 앞방","theme":"tower"},
		{"building":1,"level":2,"rect":[54,53,5,10],"name":"종 다락","theme":"tower"},
		{"building":2,"level":0,"rect":[131,62,8,6],"name":"성당 관리인 집 안방","theme":"home"},
		{"building":3,"level":1,"rect":[27,36,9,6],"name":"공동주택 가 앞방","theme":"home"},
		{"building":3,"level":1,"rect":[27,46,9,6],"name":"공동주택 가 뒷방","theme":"home"},
		{"building":3,"level":1,"rect":[37,36,10,6],"name":"공동주택 가 앞방","theme":"home"},
		{"building":3,"level":1,"rect":[37,46,10,6],"name":"공동주택 가 뒷방","theme":"home"},
		{"building":3,"level":2,"rect":[27,36,9,6],"name":"공동주택 가 앞방","theme":"home"},
		{"building":3,"level":2,"rect":[27,46,9,6],"name":"공동주택 가 뒷방","theme":"home"},
		{"building":3,"level":2,"rect":[37,36,10,6],"name":"공동주택 가 앞방","theme":"home"},
		{"building":3,"level":2,"rect":[37,46,10,6],"name":"공동주택 가 뒷방","theme":"home"},
		{"building":4,"level":0,"rect":[4,63,18,6],"name":"공동주택 나 앞방","theme":"shop"},
		{"building":4,"level":0,"rect":[4,73,18,6],"name":"공동주택 나 뒷방","theme":"shop"},
		{"building":4,"level":1,"rect":[4,63,18,6],"name":"공동주택 나 앞방","theme":"home"},
		{"building":4,"level":1,"rect":[4,73,18,6],"name":"공동주택 나 뒷방","theme":"home"},
		{"building":4,"level":2,"rect":[4,63,18,6],"name":"공동주택 나 앞방","theme":"home"},
		{"building":4,"level":2,"rect":[4,73,18,6],"name":"공동주택 나 뒷방","theme":"home"},
		{"building":5,"level":0,"rect":[124,16,10,7],"name":"공동주택 다 앞방","theme":"shop"},
		{"building":5,"level":0,"rect":[124,27,10,7],"name":"공동주택 다 뒷방","theme":"shop"},
		{"building":5,"level":0,"rect":[135,16,11,7],"name":"공동주택 다 앞방","theme":"shop"},
		{"building":5,"level":0,"rect":[135,27,11,7],"name":"공동주택 다 뒷방","theme":"shop"},
		{"building":5,"level":1,"rect":[124,16,10,7],"name":"공동주택 다 앞방","theme":"home"},
		{"building":5,"level":1,"rect":[124,27,10,7],"name":"공동주택 다 뒷방","theme":"home"},
		{"building":5,"level":1,"rect":[135,16,11,7],"name":"공동주택 다 앞방","theme":"home"},
		{"building":5,"level":1,"rect":[135,27,11,7],"name":"공동주택 다 뒷방","theme":"home"},
		{"building":5,"level":2,"rect":[124,16,10,7],"name":"공동주택 다 앞방","theme":"home"},
		{"building":5,"level":2,"rect":[124,27,10,7],"name":"공동주택 다 뒷방","theme":"home"},
		{"building":5,"level":2,"rect":[135,16,11,7],"name":"공동주택 다 앞방","theme":"home"},
		{"building":5,"level":2,"rect":[135,27,11,7],"name":"공동주택 다 뒷방","theme":"home"},
		{"building":6,"level":0,"rect":[148,33,20,5],"name":"공동주택 라 앞방","theme":"home"},
		{"building":6,"level":0,"rect":[148,42,20,5],"name":"공동주택 라 뒷방","theme":"home"},
		{"building":6,"level":1,"rect":[148,33,20,5],"name":"공동주택 라 앞방","theme":"home"},
		{"building":6,"level":1,"rect":[148,42,20,5],"name":"공동주택 라 뒷방","theme":"home"},
		{"building":6,"level":2,"rect":[148,33,20,5],"name":"공동주택 라 앞방","theme":"home"},
		{"building":6,"level":2,"rect":[148,42,20,5],"name":"공동주택 라 뒷방","theme":"home"},
		{"building":7,"level":0,"rect":[144,69,18,4],"name":"참사회관 앞방","theme":"home"},
		{"building":7,"level":0,"rect":[144,77,18,4],"name":"참사회관 뒷방","theme":"home"},
		{"building":7,"level":1,"rect":[144,69,18,4],"name":"참사회관 앞방","theme":"home"},
		{"building":7,"level":1,"rect":[144,77,18,4],"name":"참사회관 뒷방","theme":"home"},
		{"building":8,"level":0,"rect":[26,74,14,3],"name":"사제관 앞방","theme":"home"},
		{"building":8,"level":0,"rect":[26,81,14,3],"name":"사제관 뒷방","theme":"home"},
		{"building":8,"level":1,"rect":[26,74,14,3],"name":"사제관 앞방","theme":"home"},
		{"building":8,"level":1,"rect":[26,81,14,3],"name":"사제관 뒷방","theme":"home"},
		{"building":9,"level":0,"rect":[29,19,18,3],"name":"시장 창고 앞방","theme":"store"},
		{"building":9,"level":0,"rect":[29,26,18,3],"name":"시장 창고 뒷방","theme":"store"},
		{"building":10,"level":0,"rect":[54,21,7,6],"name":"차고 줄 가 앞방","theme":"store"},
		{"building":10,"level":0,"rect":[62,21,6,6],"name":"차고 줄 가 뒷방","theme":"store"},
		{"building":12,"level":0,"rect":[147,88,10,6],"name":"연료 창고 안방","theme":"heat"},
		{"building":13,"level":0,"rect":[4,86,12,3],"name":"주택 가 앞방","theme":"home"},
		{"building":13,"level":0,"rect":[4,93,12,3],"name":"주택 가 뒷방","theme":"home"},
		{"building":13,"level":1,"rect":[4,86,12,3],"name":"주택 가 앞방","theme":"home"},
		{"building":13,"level":1,"rect":[4,93,12,3],"name":"주택 가 뒷방","theme":"home"},
		{"building":14,"level":0,"rect":[153,58,6,8],"name":"주택 나 앞방","theme":"home"},
		{"building":14,"level":0,"rect":[160,58,5,8],"name":"주택 나 뒷방","theme":"home"},
		{"building":14,"level":1,"rect":[153,58,6,8],"name":"주택 나 앞방","theme":"home"},
		{"building":14,"level":1,"rect":[160,58,5,8],"name":"주택 나 뒷방","theme":"home"},
		{"building":15,"level":0,"rect":[25,91,5,8],"name":"주택 다 앞방","theme":"home"},
		{"building":15,"level":0,"rect":[31,91,4,8],"name":"주택 다 뒷방","theme":"home"},
		{"building":3,"level":0,"rect":[27,36,20,12],"name":"진열 매장","theme":"nave"},
		{"building":3,"level":0,"rect":[27,49,11,3],"name":"뒤 창고","theme":"store"},
		{"building":3,"level":0,"rect":[40,49,7,3],"name":"가게 사무실","theme":"home"},
		{"building":11,"level":0,"rect":[98,19,5,8],"name":"차고 줄 나 앞방","theme":"store"},
		{"building":11,"level":0,"rect":[104,19,5,8],"name":"차고 줄 나 뒷방","theme":"store"}
	],
	"containers": [
		{"id":"box_001","name":"찬송집 방 보관함","cell":[51,70],"building":0,"search":4,"items":["document"],"locked":false,"level":0,"searched":false},
		{"id":"box_002","name":"종지기 방 보관함","cell":[52,99],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_003","name":"현관 방 보관함","cell":[65,70],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_004","name":"옆 예배실 보관함","cell":[68,99],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_005","name":"제의실 보관함","cell":[81,70],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_006","name":"회중 준비방 보관함","cell":[82,99],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_007","name":"교구 사무방 보관함","cell":[98,70],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_008","name":"성가대방 보관함","cell":[99,99],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_009","name":"기록방 보관함","cell":[114,70],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_010","name":"서고 기록 궤","cell":[116,99],"building":0,"search":6,"items":["document","symbol_bell","food_pack"],"locked":false,"level":0,"searched":false},
		{"id":"box_011","name":"회중석 보관함","cell":[62,87],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_012","name":"합창 다락 앞방 보관함","cell":[53,77],"building":0,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_013","name":"합창 다락 뒷방 보관함","cell":[52,95],"building":0,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_014","name":"난방실 보관함","cell":[110,88],"building":0,"search":4,"items":[],"locked":false,"level":-1,"searched":false},
		{"id":"box_015","name":"막다른 식량 저장실 보관함","cell":[119,88],"building":0,"search":4,"items":[],"locked":false,"level":-1,"searched":false},
		{"id":"box_016","name":"탑 아래 앞방 보관함","cell":[51,58],"building":1,"search":4,"items":["symbol_bell"],"locked":false,"level":0,"searched":false},
		{"id":"box_017","name":"탑 아래 뒷방 보관함","cell":[58,58],"building":1,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_018","name":"종 줄 방 보관함","cell":[49,59],"building":1,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_019","name":"종 줄 방의 돌아가는 길 보관함","cell":[58,58],"building":1,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_020","name":"종 다락 앞방 보관함","cell":[49,59],"building":1,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_021","name":"종 다락 보관함","cell":[58,58],"building":1,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_022","name":"성당 관리인 집 안방 보관함","cell":[135,65],"building":2,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_023","name":"공동주택 가 앞방 보관함","cell":[34,39],"building":3,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_024","name":"공동주택 가 뒷방 보관함","cell":[27,50],"building":3,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_025","name":"공동주택 가 앞방 보관함","cell":[45,39],"building":3,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_026","name":"공동주택 가 뒷방 보관함","cell":[37,50],"building":3,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_027","name":"공동주택 가 앞방 보관함","cell":[34,39],"building":3,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_028","name":"공동주택 가 뒷방 보관함","cell":[27,50],"building":3,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_029","name":"공동주택 가 앞방 보관함","cell":[45,39],"building":3,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_030","name":"공동주택 가 뒷방 보관함","cell":[37,50],"building":3,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_031","name":"공동주택 나 앞방 보관함","cell":[16,66],"building":4,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_032","name":"공동주택 나 뒷방 보관함","cell":[19,76],"building":4,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_033","name":"공동주택 나 앞방 보관함","cell":[19,66],"building":4,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_034","name":"공동주택 나 뒷방 보관함","cell":[21,76],"building":4,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_035","name":"공동주택 나 앞방 보관함","cell":[19,66],"building":4,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_036","name":"공동주택 나 뒷방 보관함","cell":[21,76],"building":4,"search":6,"items":["cloth","symbol_bell","food_pack"],"locked":false,"level":2,"searched":false},
		{"id":"box_037","name":"공동주택 다 앞방 보관함","cell":[126,20],"building":5,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_038","name":"공동주택 다 뒷방 보관함","cell":[129,31],"building":5,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_039","name":"공동주택 다 앞방 보관함","cell":[135,20],"building":5,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_040","name":"공동주택 다 뒷방 보관함","cell":[140,31],"building":5,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_041","name":"공동주택 다 앞방 보관함","cell":[127,20],"building":5,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_042","name":"공동주택 다 뒷방 보관함","cell":[130,31],"building":5,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_043","name":"공동주택 다 앞방 보관함","cell":[139,20],"building":5,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_044","name":"공동주택 다 뒷방 보관함","cell":[142,31],"building":5,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_045","name":"공동주택 다 앞방 보관함","cell":[127,20],"building":5,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_046","name":"공동주택 다 뒷방 보관함","cell":[130,31],"building":5,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_047","name":"공동주택 다 앞방 보관함","cell":[139,20],"building":5,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_048","name":"공동주택 다 뒷방 보관함","cell":[142,31],"building":5,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_049","name":"공동주택 라 앞방 보관함","cell":[148,36],"building":6,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_050","name":"공동주택 라 뒷방 보관함","cell":[153,45],"building":6,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_051","name":"공동주택 라 앞방 보관함","cell":[152,36],"building":6,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_052","name":"공동주택 라 뒷방 보관함","cell":[154,45],"building":6,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_053","name":"공동주택 라 앞방 보관함","cell":[152,36],"building":6,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_054","name":"공동주택 라 뒷방 보관함","cell":[154,45],"building":6,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_055","name":"참사회관 앞방 보관함","cell":[150,71],"building":7,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_056","name":"참사회관 뒷방 보관함","cell":[155,79],"building":7,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_057","name":"참사회관 앞방 보관함","cell":[154,71],"building":7,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_058","name":"참사회관 뒷방 보관함","cell":[155,79],"building":7,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_059","name":"사제관 앞방 보관함","cell":[38,75],"building":8,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_060","name":"사제관 뒷방 보관함","cell":[37,82],"building":8,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_061","name":"사제관 앞방 보관함","cell":[39,75],"building":8,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_062","name":"사제관 뒷방 보관함","cell":[39,82],"building":8,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_063","name":"시장 창고 앞방 보관함","cell":[46,20],"building":9,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_064","name":"시장 창고 뒷방 보관함","cell":[46,27],"building":9,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_065","name":"차고 줄 가 앞방 보관함","cell":[55,25],"building":10,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_066","name":"차고 줄 가 뒷방 보관함","cell":[63,25],"building":10,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_067","name":"연료 창고 안방 보관함","cell":[151,91],"building":12,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_068","name":"주택 가 앞방 보관함","cell":[13,87],"building":13,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_069","name":"주택 가 뒷방 보관함","cell":[14,94],"building":13,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_070","name":"주택 가 앞방 보관함","cell":[15,87],"building":13,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_071","name":"주택 가 뒷방 보관함","cell":[15,94],"building":13,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_072","name":"주택 나 앞방 보관함","cell":[156,63],"building":14,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_073","name":"주택 나 뒷방 보관함","cell":[161,63],"building":14,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_074","name":"주택 나 앞방 보관함","cell":[155,63],"building":14,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_075","name":"주택 나 뒷방 보관함","cell":[162,63],"building":14,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_076","name":"주택 다 앞방 보관함","cell":[27,96],"building":15,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_077","name":"주택 다 뒷방 보관함","cell":[31,96],"building":15,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_078","name":"진열 매장 보관함","cell":[28,37],"building":3,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_079","name":"뒤 창고 보관함","cell":[29,49],"building":3,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_080","name":"가게 사무실 보관함","cell":[42,49],"building":3,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_081","name":"승강장 남은 상자","cell":[51,10],"building":-1,"search":3,"items":["plank","cloth"],"locked":false,"level":0,"searched":false},
		{"id":"box_082","name":"차고 줄 나 앞방 보관함","cell":[100,24],"building":11,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_083","name":"차고 줄 나 뒷방 보관함","cell":[106,24],"building":11,"search":4,"items":[],"locked":false,"level":0,"searched":false}
	],
	"entries": [
		{"id":"west_street","cells":[[0,44],[0,45],[0,46],[0,47]],"gap":0.6},
		{"id":"east_street","cells":[[174,52],[174,53],[174,54],[174,55]],"gap":0.6},
		{"id":"southwest_lane","cells":[[38,104],[39,104],[40,104],[41,104]],"gap":0.6},
		{"id":"southeast_lane","cells":[[138,104],[139,104],[140,104]],"gap":2},
		{"id":"east_back","cells":[[174,82],[174,83],[174,84]],"gap":2}
	],
	"holes": [
		{"id":"manhole_01","cell":[40,60],"name":"광장 서쪽 맨홀","level":0,"gap":3}
	],
	"slots": [
		[49,27],
		[51,27],
		[70,25],
		[72,25],
		[111,25],
		[113,25]
	],
	"dead": [
		[5,46],
		[171,54],
		[39,101],
		[139,99],
		[170,83],
		[65,42],
		[111,56]
	],
	"deep": [
		"C",
		"F"
	],
	"work": {"cell":[101,48],"rect":[80,38,38,20]}
}

# 위쪽 일터의 독립 평면. 아래쪽 계획의 건물 번호 뒤에만 덧붙인다.
const NORTH: Dictionary = {
	"names": {"H":"목공과 대장간 거리","I":"기름 가게 좌판 터","J":"조합 마당"},
	"zones": [
		{"id":"H","rect":[0,0,65,46]},
		{"id":"I","rect":[65,0,51,46]},
		{"id":"J","rect":[116,0,59,46]}
	],
	"ground": [
		{"rect":[116,0,59,45],"kind":"GRAVEL"},
		{"rect":[0,8,175,6],"kind":"ROAD"},
		{"rect":[32,0,4,8],"kind":"ROAD"},
		{"rect":[24,14,5,29],"kind":"ROAD"},
		{"rect":[61,14,4,29],"kind":"ROAD"},
		{"rect":[110,14,6,31],"kind":"ROAD"},
		{"rect":[79,14,31,10],"kind":"SNOW"},
		{"rect":[154,16,21,9],"kind":"DEEP_SNOW"},
		{"rect":[47,24,18,4],"kind":"ROAD"},
		{"rect":[47,24,4,19],"kind":"ROAD"},
		{"rect":[47,24,18,4],"kind":"ROAD"},
		{"rect":[47,24,4,19],"kind":"ROAD"},
		{"rect":[10,24,6,21],"kind":"ROAD"},
		{"rect":[96,34,6,11],"kind":"ROAD"}
	],
	"buildings": [
		{"id":16,"name":"조합 공방 홀","rect":[116,25,34,20],"warm":false,"window_broken":false},
		{"id":17,"name":"목공소","rect":[4,14,20,10],"warm":false,"window_broken":false},
		{"id":18,"name":"대장간","rect":[29,14,14,10],"warm":false,"window_broken":false},
		{"id":19,"name":"철물점","rect":[43,14,18,10],"warm":false,"window_broken":false},
		{"id":20,"name":"기름 가게","rect":[65,14,14,10],"warm":false,"window_broken":false},
		{"id":21,"name":"판자 창고","rect":[4,0,18,8],"warm":false,"window_broken":false},
		{"id":22,"name":"자재 창고","rect":[46,0,16,8],"warm":false,"window_broken":false},
		{"id":23,"name":"연장 도매 창고","rect":[92,0,24,8],"warm":false,"window_broken":false}
	],
	"shells": [
		{"building":16,"level":-1,"rect":[116,25,34,20]},
		{"building":16,"level":0,"rect":[116,25,34,20]},
		{"building":16,"level":1,"rect":[116,25,34,20]},
		{"building":16,"level":2,"rect":[116,25,34,20]},
		{"building":17,"level":0,"rect":[4,14,20,10]},
		{"building":17,"level":1,"rect":[4,14,20,10]},
		{"building":18,"level":0,"rect":[29,14,14,10]},
		{"building":19,"level":0,"rect":[43,14,18,10]},
		{"building":19,"level":1,"rect":[43,14,18,10]},
		{"building":19,"level":2,"rect":[43,14,18,10]},
		{"building":20,"level":0,"rect":[65,14,14,10]},
		{"building":20,"level":1,"rect":[65,14,14,10]},
		{"building":21,"level":0,"rect":[4,0,18,8]},
		{"building":22,"level":0,"rect":[46,0,16,8]},
		{"building":23,"level":-1,"rect":[92,0,24,12]},
		{"building":23,"level":0,"rect":[92,0,24,8]},
		{"building":23,"level":1,"rect":[92,0,24,8]}
	],
	"walls": [
		{"level":-1,"rect":[133,26,1,18]},
		{"level":0,"rect":[117,33,32,1]},
		{"level":0,"rect":[117,36,32,1]},
		{"level":0,"rect":[127,26,1,7]},
		{"level":0,"rect":[127,37,1,7]},
		{"level":0,"rect":[138,26,1,7]},
		{"level":0,"rect":[138,37,1,7]},
		{"level":1,"rect":[133,26,1,18]},
		{"level":2,"rect":[133,26,1,18]},
		{"level":0,"rect":[14,15,1,8]},
		{"level":1,"rect":[14,15,1,8]},
		{"level":0,"rect":[36,15,1,8]},
		{"level":0,"rect":[57,15,1,8]},
		{"level":0,"rect":[44,19,14,1]},
		{"level":1,"rect":[52,15,1,8]},
		{"level":2,"rect":[52,15,1,8]},
		{"level":0,"rect":[75,15,1,8]},
		{"level":0,"rect":[66,19,10,1]},
		{"level":1,"rect":[72,15,1,8]},
		{"level":0,"rect":[13,1,1,6]},
		{"level":0,"rect":[54,1,1,6]},
		{"level":-1,"rect":[93,3,22,1]},
		{"level":-1,"rect":[104,4,1,7]},
		{"level":0,"rect":[93,4,22,1]},
		{"level":0,"rect":[103,1,1,3]},
		{"level":1,"rect":[104,1,1,6]}
	],
	"doors": [
		{"building":16,"level":-1,"cell":[133,35],"side":[1,0],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[122,33],"side":[0,1],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[122,36],"side":[0,-1],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[133,33],"side":[0,1],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[133,36],"side":[0,-1],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[144,33],"side":[0,1],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[144,36],"side":[0,-1],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[116,34],"side":[-1,0],"state":"open","outer":true},
		{"building":16,"level":1,"cell":[133,35],"side":[1,0],"state":"open","outer":false},
		{"building":16,"level":2,"cell":[133,35],"side":[1,0],"state":"open","outer":false},
		{"building":17,"level":0,"cell":[14,19],"side":[1,0],"state":"open","outer":false},
		{"building":17,"level":0,"cell":[9,14],"side":[0,-1],"state":"open","outer":true},
		{"building":17,"level":1,"cell":[14,19],"side":[1,0],"state":"open","outer":false},
		{"building":18,"level":0,"cell":[36,19],"side":[1,0],"state":"open","outer":false},
		{"building":18,"level":0,"cell":[33,14],"side":[0,-1],"state":"open","outer":true},
		{"building":19,"level":0,"cell":[57,17],"side":[1,0],"state":"open","outer":false},
		{"building":19,"level":0,"cell":[57,21],"side":[1,0],"state":"open","outer":false},
		{"building":19,"level":0,"cell":[52,14],"side":[0,-1],"state":"open","outer":true},
		{"building":19,"level":0,"cell":[58,23],"side":[0,1],"state":"open","outer":true},
		{"building":19,"level":1,"cell":[52,19],"side":[1,0],"state":"open","outer":false},
		{"building":19,"level":2,"cell":[52,19],"side":[1,0],"state":"open","outer":false},
		{"building":20,"level":0,"cell":[75,17],"side":[1,0],"state":"open","outer":false},
		{"building":20,"level":0,"cell":[75,21],"side":[1,0],"state":"open","outer":false},
		{"building":20,"level":0,"cell":[72,14],"side":[0,-1],"state":"open","outer":true},
		{"building":20,"level":0,"cell":[76,23],"side":[0,1],"state":"open","outer":true},
		{"building":20,"level":1,"cell":[72,19],"side":[1,0],"state":"open","outer":false},
		{"building":21,"level":0,"cell":[13,4],"side":[1,0],"state":"open","outer":false},
		{"building":21,"level":0,"cell":[9,7],"side":[0,1],"state":"open","outer":true},
		{"building":22,"level":0,"cell":[54,4],"side":[1,0],"state":"open","outer":false},
		{"building":22,"level":0,"cell":[50,7],"side":[0,1],"state":"open","outer":true},
		{"building":23,"level":-1,"cell":[98,3],"side":[0,-1],"state":"open","outer":false},
		{"building":23,"level":-1,"cell":[110,3],"side":[0,-1],"state":"open","outer":false},
		{"building":23,"level":0,"cell":[98,4],"side":[0,1],"state":"open","outer":false},
		{"building":23,"level":0,"cell":[109,4],"side":[0,1],"state":"open","outer":false},
		{"building":23,"level":0,"cell":[104,7],"side":[0,1],"state":"open","outer":true},
		{"building":23,"level":1,"cell":[104,4],"side":[1,0],"state":"open","outer":false}
	],
	"windows": [
		{"building":16,"level":-1,"cell":[125,25],"broken":false},
		{"building":16,"level":-1,"cell":[141,25],"broken":false},
		{"building":16,"level":0,"cell":[122,25],"broken":false},
		{"building":16,"level":0,"cell":[133,25],"broken":false},
		{"building":16,"level":0,"cell":[144,25],"broken":false},
		{"building":16,"level":1,"cell":[125,25],"broken":false},
		{"building":16,"level":1,"cell":[141,25],"broken":false},
		{"building":16,"level":2,"cell":[125,25],"broken":false},
		{"building":16,"level":2,"cell":[141,25],"broken":false},
		{"building":17,"level":0,"cell":[19,14],"broken":false},
		{"building":17,"level":1,"cell":[9,14],"broken":false},
		{"building":17,"level":1,"cell":[19,14],"broken":false},
		{"building":18,"level":0,"cell":[39,14],"broken":false},
		{"building":19,"level":0,"cell":[50,14],"broken":false},
		{"building":19,"level":1,"cell":[48,14],"broken":false},
		{"building":19,"level":1,"cell":[56,14],"broken":false},
		{"building":19,"level":2,"cell":[48,14],"broken":false},
		{"building":19,"level":2,"cell":[56,14],"broken":false},
		{"building":20,"level":0,"cell":[70,14],"broken":false},
		{"building":20,"level":1,"cell":[69,14],"broken":false},
		{"building":20,"level":1,"cell":[75,14],"broken":false},
		{"building":21,"level":0,"cell":[9,0],"broken":false},
		{"building":21,"level":0,"cell":[17,0],"broken":false},
		{"building":22,"level":0,"cell":[50,0],"broken":false},
		{"building":22,"level":0,"cell":[58,0],"broken":false},
		{"building":23,"level":-1,"cell":[98,0],"broken":false},
		{"building":23,"level":-1,"cell":[110,0],"broken":false},
		{"building":23,"level":0,"cell":[98,0],"broken":false},
		{"building":23,"level":0,"cell":[109,0],"broken":false},
		{"building":23,"level":1,"cell":[98,0],"broken":false},
		{"building":23,"level":1,"cell":[110,0],"broken":false}
	],
	"stairs": [
		{"cell":[117,26],"low":-1,"high":0,"ladder":false},
		{"cell":[117,26],"low":0,"high":1,"ladder":false},
		{"cell":[117,26],"low":1,"high":2,"ladder":false},
		{"cell":[5,15],"low":0,"high":1,"ladder":false},
		{"cell":[44,15],"low":0,"high":1,"ladder":false},
		{"cell":[44,15],"low":1,"high":2,"ladder":false},
		{"cell":[66,15],"low":0,"high":1,"ladder":false},
		{"cell":[93,1],"low":-1,"high":0,"ladder":false},
		{"cell":[93,1],"low":0,"high":1,"ladder":false}
	],
	"props": [
		{"kind":"car","rect":[70,36,4,2],"solid":"low","facing":0,"note":"길가에 비껴 세운 차","level":0},
		{"kind":"crate_stack","rect":[28,40,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"handcart","rect":[96,31,1,2],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"pallet_stack","rect":[104,28,2,2],"solid":"low","facing":0,"note":"빈 팰릿 더미","level":0},
		{"kind":"market_stall","rect":[81,15,3,2],"solid":"low","facing":0,"note":"눈 덮인 도구 좌판","level":0},
		{"kind":"market_stall","rect":[95,19,3,2],"solid":"low","facing":0,"note":"눈 덮인 도구 좌판","level":0},
		{"kind":"market_stall","rect":[103,15,3,2],"solid":"low","facing":0,"note":"눈 덮인 도구 좌판","level":0},
		{"kind":"barrel","rect":[88,17,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"handcart","rect":[90,18,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"cold_stove","rect":[31,5,1,1],"solid":"low","facing":0,"note":"작게 식은 난로","level":0},
		{"kind":"anvil_block","rect":[36,5,1,1],"solid":"low","facing":0,"note":"연장을 고치던 낮은 모루","level":0},
		{"kind":"crate_stack","rect":[38,5,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"firewood_pile","rect":[41,5,2,1],"solid":"low","facing":0,"note":"처마 밑 마른 장작","level":0},
		{"kind":"lamp_post","rect":[87,14,1,1],"solid":"none","facing":0,"note":"꺼진 등잔 기둥","level":0},
		{"kind":"fieldstone_wall","rect":[0,23,4,1],"solid":"low","facing":0,"note":"글씨 없는 들돌 담 토막","level":0},
		{"kind":"barrel","rect":[116,24,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"bare_tree","rect":[24,1,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[27,4,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[30,2,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[25,6,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[83,18,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[87,21,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[88,20,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[91,22,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[160,27,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[168,30,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[162,37,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[171,41,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"sack_pile","rect":[131,26,2,2],"solid":"none","facing":0,"note":"물자를 담은 자루","level":-1},
		{"kind":"shelf","rect":[118,26,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":-1},
		{"kind":"barrel","rect":[132,43,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":-1},
		{"kind":"sack_pile","rect":[147,26,2,2],"solid":"none","facing":0,"note":"물자를 담은 자루","level":-1},
		{"kind":"shelf","rect":[134,43,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":-1},
		{"kind":"barrel","rect":[148,43,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":-1},
		{"kind":"desk","rect":[118,32,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"shelf","rect":[118,26,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[125,26,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"handcart","rect":[117,43,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"crate_stack","rect":[117,37,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"sack_pile","rect":[125,37,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"desk","rect":[128,32,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"shelf","rect":[128,26,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[136,26,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[128,43,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"shelf","rect":[128,37,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[136,37,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[139,32,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"shelf","rect":[140,26,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"desk","rect":[139,43,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"shelf","rect":[139,37,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[139,38,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[117,43,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":1},
		{"kind":"shelf","rect":[117,42,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"shelf","rect":[134,26,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"barrel","rect":[134,43,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":1},
		{"kind":"crate_stack","rect":[134,27,2,2],"solid":"none","facing":0,"note":"종류별 물자를 담은 나무 상자","level":1},
		{"kind":"desk","rect":[117,43,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":2},
		{"kind":"shelf","rect":[117,42,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":2},
		{"kind":"shelf","rect":[134,26,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":2},
		{"kind":"barrel","rect":[134,43,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":2},
		{"kind":"crate_stack","rect":[134,27,2,2],"solid":"none","facing":0,"note":"종류별 물자를 담은 나무 상자","level":2},
		{"kind":"repair_lumber","rect":[5,21,4,2],"solid":"low","facing":0,"note":"수리용 널판 더미","level":0},
		{"kind":"shelf","rect":[6,15,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"handcart","rect":[12,15,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"repair_lumber","rect":[15,21,4,2],"solid":"low","facing":0,"note":"수리용 널판 더미","level":0},
		{"kind":"shelf","rect":[16,15,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"handcart","rect":[21,15,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"desk","rect":[5,22,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":1},
		{"kind":"shelf","rect":[5,21,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"shelf","rect":[15,22,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"barrel","rect":[22,15,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":1},
		{"kind":"crate_stack","rect":[16,15,2,2],"solid":"none","facing":0,"note":"종류별 물자를 담은 나무 상자","level":1},
		{"kind":"anvil_block","rect":[30,22,1,1],"solid":"low","facing":0,"note":"연장을 고치던 낮은 모루","level":0},
		{"kind":"cold_stove","rect":[35,15,1,1],"solid":"low","facing":0,"note":"작게 식은 난로","level":0},
		{"kind":"barrel","rect":[35,22,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"anvil_block","rect":[41,15,1,1],"solid":"low","facing":0,"note":"연장을 고치던 낮은 모루","level":0},
		{"kind":"cold_stove","rect":[37,22,1,1],"solid":"low","facing":0,"note":"작게 식은 난로","level":0},
		{"kind":"barrel","rect":[41,22,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"display_shelf","rect":[44,18,4,1],"solid":"low","facing":0,"note":"가게 앞방 진열대","level":0},
		{"kind":"shop_counter","rect":[44,17,3,1],"solid":"low","facing":0,"note":"매장 계산대","level":0},
		{"kind":"crate_stack","rect":[54,15,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"pallet_stack","rect":[56,20,1,1],"solid":"low","facing":0,"note":"빈 팰릿 더미","level":0},
		{"kind":"shelf","rect":[44,22,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[44,20,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[44,22,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":1},
		{"kind":"shelf","rect":[44,21,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"shelf","rect":[53,15,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"barrel","rect":[59,22,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":1},
		{"kind":"crate_stack","rect":[53,21,2,2],"solid":"none","facing":0,"note":"종류별 물자를 담은 나무 상자","level":1},
		{"kind":"desk","rect":[44,22,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":2},
		{"kind":"shelf","rect":[44,16,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":2},
		{"kind":"shelf","rect":[53,15,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":2},
		{"kind":"barrel","rect":[59,22,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":2},
		{"kind":"crate_stack","rect":[53,21,2,2],"solid":"none","facing":0,"note":"종류별 물자를 담은 나무 상자","level":2},
		{"kind":"shop_counter","rect":[66,18,3,1],"solid":"low","facing":0,"note":"매장 계산대","level":0},
		{"kind":"barrel","rect":[74,15,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"shelf","rect":[66,17,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"barrel","rect":[74,20,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"barrel","rect":[66,22,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"handcart","rect":[66,20,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"desk","rect":[66,22,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":1},
		{"kind":"shelf","rect":[66,21,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"shelf","rect":[73,15,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"barrel","rect":[77,15,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":1},
		{"kind":"crate_stack","rect":[73,16,2,2],"solid":"none","facing":0,"note":"종류별 물자를 담은 나무 상자","level":1},
		{"kind":"repair_lumber","rect":[5,5,4,2],"solid":"low","facing":0,"note":"수리용 널판 더미","level":0},
		{"kind":"shelf","rect":[6,1,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"handcart","rect":[11,1,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"repair_lumber","rect":[15,1,4,2],"solid":"low","facing":0,"note":"수리용 널판 더미","level":0},
		{"kind":"shelf","rect":[14,6,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"handcart","rect":[19,1,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"shelf","rect":[47,6,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[48,1,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[47,5,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"shelf","rect":[55,1,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[55,2,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[55,6,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"sack_pile","rect":[93,4,2,2],"solid":"none","facing":0,"note":"물자를 담은 자루","level":-1},
		{"kind":"shelf","rect":[93,9,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":-1},
		{"kind":"barrel","rect":[103,10,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":-1},
		{"kind":"sack_pile","rect":[105,4,2,2],"solid":"none","facing":0,"note":"물자를 담은 자루","level":-1},
		{"kind":"shelf","rect":[105,10,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":-1},
		{"kind":"barrel","rect":[114,10,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":-1},
		{"kind":"shelf","rect":[93,3,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[101,2,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[94,1,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"shelf","rect":[104,1,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[113,1,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[104,2,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"desk","rect":[93,6,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":1},
		{"kind":"shelf","rect":[93,5,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"shelf","rect":[105,6,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"barrel","rect":[114,6,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":1},
		{"kind":"crate_stack","rect":[106,1,2,2],"solid":"none","facing":0,"note":"종류별 물자를 담은 나무 상자","level":1}
	],
	"rooms": [
		{"building":16,"level":-1,"rect":[117,26,16,18],"name":"조합 공방 홀 지하 앞방","theme":"workshop"},
		{"building":16,"level":-1,"rect":[134,26,15,18],"name":"조합 공방 홀 지하 뒷방","theme":"workshop"},
		{"building":16,"level":0,"rect":[117,26,10,7],"name":"조합 공방 홀 계량방","theme":"workshop"},
		{"building":16,"level":0,"rect":[117,37,10,7],"name":"조합 공방 홀 하역방","theme":"workshop"},
		{"building":16,"level":0,"rect":[128,26,10,7],"name":"조합 공방 홀 작업방","theme":"workshop"},
		{"building":16,"level":0,"rect":[128,37,10,7],"name":"조합 공방 홀 재료방","theme":"workshop"},
		{"building":16,"level":0,"rect":[139,26,10,7],"name":"조합 공방 홀 사무방","theme":"workshop"},
		{"building":16,"level":0,"rect":[139,37,10,7],"name":"조합 공방 홀 안쪽 저장방","theme":"workshop"},
		{"building":16,"level":1,"rect":[117,26,16,18],"name":"조합 공방 홀 위층 견본방","theme":"workshop"},
		{"building":16,"level":1,"rect":[134,26,15,18],"name":"조합 공방 홀 위층 조립방","theme":"workshop"},
		{"building":16,"level":2,"rect":[117,26,16,18],"name":"조합 공방 홀 다락 앞방","theme":"workshop"},
		{"building":16,"level":2,"rect":[134,26,15,18],"name":"조합 공방 홀 다락 뒷방","theme":"workshop"},
		{"building":17,"level":0,"rect":[5,15,9,8],"name":"목공소 앞방","theme":"wood"},
		{"building":17,"level":0,"rect":[15,15,8,8],"name":"목공소 뒷방","theme":"wood"},
		{"building":17,"level":1,"rect":[5,15,9,8],"name":"목공소 위층 앞방","theme":"wood"},
		{"building":17,"level":1,"rect":[15,15,8,8],"name":"목공소 위층 뒷방","theme":"wood"},
		{"building":18,"level":0,"rect":[30,15,6,8],"name":"대장간 앞방","theme":"smith"},
		{"building":18,"level":0,"rect":[37,15,5,8],"name":"대장간 뒷방","theme":"smith"},
		{"building":19,"level":0,"rect":[44,15,13,4],"name":"철물점 매장","theme":"shop"},
		{"building":19,"level":0,"rect":[44,20,13,3],"name":"철물점 뒤 창고","theme":"shop"},
		{"building":19,"level":1,"rect":[44,15,8,8],"name":"철물점 위층 앞방","theme":"shop"},
		{"building":19,"level":1,"rect":[53,15,7,8],"name":"철물점 위층 뒷방","theme":"shop"},
		{"building":19,"level":2,"rect":[44,15,8,8],"name":"철물점 다락 앞방","theme":"shop"},
		{"building":19,"level":2,"rect":[53,15,7,8],"name":"철물점 다락 뒷방","theme":"shop"},
		{"building":20,"level":0,"rect":[66,15,9,4],"name":"기름 가게 매장","theme":"oilshop"},
		{"building":20,"level":0,"rect":[66,20,9,3],"name":"기름 가게 뒤 창고","theme":"oilshop"},
		{"building":20,"level":1,"rect":[66,15,6,8],"name":"기름 가게 위층 앞방","theme":"oilshop"},
		{"building":20,"level":1,"rect":[73,15,5,8],"name":"기름 가게 위층 뒷방","theme":"oilshop"},
		{"building":21,"level":0,"rect":[5,1,8,6],"name":"판자 창고 앞방","theme":"wood"},
		{"building":21,"level":0,"rect":[14,1,7,6],"name":"판자 창고 뒷방","theme":"wood"},
		{"building":22,"level":0,"rect":[47,1,7,6],"name":"자재 창고 앞방","theme":"tools"},
		{"building":22,"level":0,"rect":[55,1,6,6],"name":"자재 창고 뒷방","theme":"tools"},
		{"building":23,"level":-1,"rect":[93,4,11,7],"name":"연장 도매 창고 지하 통로 옆 저장방","theme":"tools"},
		{"building":23,"level":-1,"rect":[105,4,10,7],"name":"연장 도매 창고 지하 막다른 저장방","theme":"tools"},
		{"building":23,"level":0,"rect":[93,1,10,3],"name":"연장 도매 창고 선별방","theme":"tools"},
		{"building":23,"level":0,"rect":[104,1,11,3],"name":"연장 도매 창고 건조방","theme":"tools"},
		{"building":23,"level":1,"rect":[93,1,11,6],"name":"연장 도매 창고 위층 앞방","theme":"tools"},
		{"building":23,"level":1,"rect":[105,1,10,6],"name":"연장 도매 창고 위층 뒷방","theme":"tools"}
	],
	"containers": [
		{"id":"north_box_017","name":"대장간 앞방 보관함","cell":[30,15],"building":18,"search":6,"items":["scrap","needle_thread"],"locked":false,"level":0,"searched":false},
		{"id":"north_box_020","name":"철물점 뒤 창고 보관함","cell":[56,22],"building":19,"search":6,"items":["scrap","needle_thread"],"locked":false,"level":0,"searched":false},
		{"id":"north_box_026","name":"기름 가게 뒤 창고 보관함","cell":[74,22],"building":20,"search":6,"items":["scrap","needle_thread"],"locked":false,"level":0,"searched":false},
		{"id":"north_box_033","name":"연장 도매 창고 지하 통로 옆 저장방 보관함","cell":[93,10],"building":23,"search":4,"items":[],"locked":false,"level":-1,"searched":false},
		{"id":"north_box_034","name":"연장 도매 창고 막다른 물자 보관함","cell":[114,4],"building":23,"search":8,"items":["tweezers","bottle_spirit"],"locked":false,"level":-1,"searched":false},
		{"id":"north_box_035","name":"연장 도매 창고 선별방 보관함","cell":[102,1],"building":23,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"north_box_036","name":"연장 도매 창고 건조방 보관함","cell":[104,3],"building":23,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"north_box_037","name":"연장 도매 창고 위층 앞방 보관함","cell":[103,1],"building":23,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"north_box_038","name":"연장 도매 창고 위층 뒷방 보관함","cell":[105,1],"building":23,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"north_shallow","name":"운반 도중 내려둔 물자 보관함","cell":[30,38],"building":-1,"search":2,"items":["needle_thread"],"locked":false,"level":0,"searched":false}
	],
	"entries": [
		{"id":"서쪽 공방 뒷길","cells":[[0,9],[0,10],[0,11],[0,12]],"gap":0.6},
		{"id":"북쪽 공방 골목","cells":[[32,0],[33,0],[34,0],[35,0]],"gap":2.5},
		{"id":"동쪽 공방 뒷길","cells":[[174,9],[174,10],[174,11],[174,12]],"gap":0.6}
	],
	"holes": [
		{"id":"manhole_02","cell":[88,11],"name":"공방 뒷길 맨홀","level":0,"gap":3}
	],
	"slots": [
		[25,24],
		[27,25],
		[61,24],
		[64,25],
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
const ENTRY_NAMES: Dictionary = {"west_street": "서쪽 거리", "east_street": "동쪽 거리", "southwest_lane": "남서쪽 샛길", "southeast_lane": "남동쪽 샛길", "east_back": "동쪽 뒷길", "manhole_01": "첫째 맨홀", "서쪽 공방 뒷길": "서쪽 공방 뒷길", "북쪽 공방 골목": "북쪽 공방 골목", "동쪽 공방 뒷길": "동쪽 공방 뒷길", "manhole_02": "둘째 맨홀"}
const ENTRY_WEIGHTS: Dictionary = {"west_street": 1.0, "east_street": 1.0, "southwest_lane": 1.0, "southeast_lane": 0.5, "east_back": 0.5, "manhole_01": 0.3, "서쪽 공방 뒷길": 1.0, "북쪽 공방 골목": 0.5, "동쪽 공방 뒷길": 1.0, "manhole_02": 0.3}
const FIRST_ENTRY: String = "west_street"


static func build() -> Dictionary:
	var data: Dictionary = _build_plain()
	data["entry_names"] = ENTRY_NAMES.duplicate()
	data["entry_weights"] = ENTRY_WEIGHTS.duplicate()
	data["first_entry"] = FIRST_ENTRY
	return data
