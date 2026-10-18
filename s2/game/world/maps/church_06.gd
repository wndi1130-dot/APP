# 이 지도가 다른 판단을 만드는 것: 기록은 가장 안쪽인데 열린 문은 하나다. 널을 덧댄 남쪽 옆문을 열면 시끄럽지만 퇴로가 생긴다.
# 위쪽의 판단: 말린 과일 항아리와 꿀 병(가볍고 값지다)을 얻는 대신, 나무 사이로 길이 비뚤어져 무리가 오는 쪽을 늦게 보고 아래쪽 피난처 구역을 비워 둔다.
extends RefCounted

const FieldGrid = preload("res://game/world/field_grid.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const PLACE_ID: String = "church_06"
const WIDTH: int = 165
const SOUTH_HEIGHT: int = 95
const HEIGHT: int = SOUTH_HEIGHT + 45

# 각 방과 마당의 좌표는 이 지도에서만 쓰는 독립 평면이다.
# 종소리와 덧댄 문 해체는 자리만 남기며 여기서 실행하지 않는다.
const PLAN: Dictionary = {
	"id": "church_06",
	"size": [
		165,
		95
	],
	"names": {"A":"열차 곁 띠","B":"식료품점 거리","C":"교회","D":"학교 마당","E":"급식 부엌 마당","F":"서쪽 주택 거리"},
	"zones": [
		{"id":"A","rect":[0,0,165,95]},
		{"id":"B","rect":[0,30,165,22]},
		{"id":"C","rect":[48,52,57,28]},
		{"id":"D","rect":[105,52,60,29]},
		{"id":"E","rect":[48,80,117,15]},
		{"id":"F","rect":[0,52,48,43]}
	],
	"ground": [
		{"rect":[0,10,24,32],"kind":"DEEP_SNOW"},
		{"rect":[108,10,57,30],"kind":"DEEP_SNOW"},
		{"rect":[45,78,118,17],"kind":"GRAVEL"},
		{"rect":[0,85,45,10],"kind":"DEEP_SNOW"},
		{"rect":[100,10,5,42],"kind":"ROAD"},
		{"rect":[64,10,41,4],"kind":"ROAD"},
		{"rect":[0,46,165,6],"kind":"ROAD"},
		{"rect":[156,44,9,6],"kind":"ROAD"},
		{"rect":[52,78,4,17],"kind":"ROAD"},
		{"rect":[42,52,5,42],"kind":"ROAD"},
		{"rect":[132,52,4,42],"kind":"ROAD"},
		{"rect":[132,64,33,5],"kind":"ROAD"},
		{"rect":[48,78,87,4],"kind":"ROAD"},
		{"rect":[18,70,26,4],"kind":"ROAD"}
	],
	"buildings": [
		{"id":0,"name":"교회 본당","rect":[60,54,40,24],"warm":true,"window_broken":false},
		{"id":1,"name":"종탑","rect":[48,54,10,10],"warm":false,"window_broken":false},
		{"id":2,"name":"교구 학교","rect":[110,54,22,20],"warm":false,"window_broken":false},
		{"id":3,"name":"교구 회관","rect":[25,55,18,14],"warm":false,"window_broken":false},
		{"id":4,"name":"급식 부엌","rect":[70,82,16,12],"warm":false,"window_broken":false},
		{"id":5,"name":"식료품점","rect":[64,30,34,14],"warm":false,"window_broken":false},
		{"id":6,"name":"주택 가","rect":[28,17,14,12],"warm":false,"window_broken":false},
		{"id":7,"name":"주택 나","rect":[84,17,12,12],"warm":false,"window_broken":false},
		{"id":8,"name":"차고","rect":[54,20,16,8],"warm":false,"window_broken":false},
		{"id":9,"name":"사제관","rect":[26,75,16,12],"warm":false,"window_broken":false},
		{"id":10,"name":"서쪽 주택 다","rect":[4,55,14,12],"warm":false,"window_broken":false},
		{"id":11,"name":"서쪽 주택 라","rect":[5,75,14,10],"warm":false,"window_broken":false},
		{"id":12,"name":"장작 헛간","rect":[92,83,12,8],"warm":false,"window_broken":false},
		{"id":13,"name":"학교 숙직 헛간","rect":[137,70,8,6],"warm":false,"window_broken":false},
		{"id":14,"name":"우물집","rect":[108,83,6,6],"warm":false,"window_broken":false}
	],
	"shells": [
		{"building":0,"level":0,"rect":[60,54,40,24]},
		{"building":0,"level":1,"rect":[60,54,8,24]},
		{"building":0,"level":-1,"rect":[76,54,24,24]},
		{"building":1,"level":0,"rect":[48,54,10,10]},
		{"building":1,"level":1,"rect":[48,54,10,10]},
		{"building":1,"level":2,"rect":[48,54,10,10]},
		{"building":2,"level":0,"rect":[110,54,22,20]},
		{"building":2,"level":1,"rect":[110,54,22,20]},
		{"building":2,"level":2,"rect":[110,54,22,20]},
		{"building":3,"level":0,"rect":[25,55,18,14]},
		{"building":3,"level":1,"rect":[25,55,18,14]},
		{"building":4,"level":0,"rect":[70,82,16,12]},
		{"building":5,"level":0,"rect":[64,30,34,14]},
		{"building":6,"level":0,"rect":[28,17,14,12]},
		{"building":6,"level":1,"rect":[28,17,14,12]},
		{"building":7,"level":0,"rect":[84,17,12,12]},
		{"building":7,"level":1,"rect":[84,17,12,12]},
		{"building":8,"level":0,"rect":[54,20,16,8]},
		{"building":9,"level":0,"rect":[26,75,16,12]},
		{"building":9,"level":1,"rect":[26,75,16,12]},
		{"building":10,"level":0,"rect":[4,55,14,12]},
		{"building":10,"level":1,"rect":[4,55,14,12]},
		{"building":11,"level":0,"rect":[5,75,14,10]},
		{"building":12,"level":0,"rect":[92,83,12,8]},
		{"building":13,"level":0,"rect":[137,70,8,6]},
		{"building":14,"level":0,"rect":[108,83,6,6]}
	],
	"walls": [
		{"level":0,"rect":[61,60,38,1]},
		{"level":0,"rect":[61,71,38,1]},
		{"level":0,"rect":[67,55,1,5]},
		{"level":0,"rect":[67,72,1,5]},
		{"level":0,"rect":[75,55,1,5]},
		{"level":0,"rect":[75,72,1,5]},
		{"level":0,"rect":[83,55,1,5]},
		{"level":0,"rect":[83,72,1,5]},
		{"level":0,"rect":[91,55,1,5]},
		{"level":0,"rect":[91,72,1,5]},
		{"level":1,"rect":[61,66,6,1]},
		{"level":-1,"rect":[79,57,18,1]},
		{"level":-1,"rect":[79,74,18,1]},
		{"level":-1,"rect":[79,57,1,18]},
		{"level":-1,"rect":[96,57,1,18]},
		{"level":-1,"rect":[88,58,1,16]},
		{"level":0,"rect":[52,55,1,8]},
		{"level":1,"rect":[52,55,1,8]},
		{"level":2,"rect":[52,55,1,8]},
		{"level":0,"rect":[111,62,20,1]},
		{"level":0,"rect":[111,65,20,1]},
		{"level":0,"rect":[120,55,1,7]},
		{"level":0,"rect":[120,66,1,7]},
		{"level":1,"rect":[111,62,20,1]},
		{"level":1,"rect":[111,65,20,1]},
		{"level":1,"rect":[120,55,1,7]},
		{"level":1,"rect":[120,66,1,7]},
		{"level":2,"rect":[111,62,20,1]},
		{"level":2,"rect":[111,65,20,1]},
		{"level":2,"rect":[120,55,1,7]},
		{"level":2,"rect":[120,66,1,7]},
		{"level":0,"rect":[26,60,16,1]},
		{"level":0,"rect":[26,63,16,1]},
		{"level":1,"rect":[26,60,16,1]},
		{"level":1,"rect":[26,63,16,1]},
		{"level":0,"rect":[71,86,14,1]},
		{"level":0,"rect":[71,89,14,1]},
		{"level":0,"rect":[29,21,12,1]},
		{"level":0,"rect":[29,24,12,1]},
		{"level":1,"rect":[29,21,12,1]},
		{"level":1,"rect":[29,24,12,1]},
		{"level":0,"rect":[85,21,10,1]},
		{"level":0,"rect":[85,24,10,1]},
		{"level":1,"rect":[85,21,10,1]},
		{"level":1,"rect":[85,24,10,1]},
		{"level":0,"rect":[62,21,1,6]},
		{"level":0,"rect":[27,79,14,1]},
		{"level":0,"rect":[27,82,14,1]},
		{"level":1,"rect":[27,79,14,1]},
		{"level":1,"rect":[27,82,14,1]},
		{"level":0,"rect":[5,59,12,1]},
		{"level":0,"rect":[5,62,12,1]},
		{"level":1,"rect":[5,59,12,1]},
		{"level":1,"rect":[5,62,12,1]},
		{"level":0,"rect":[12,76,1,8]},
		{"level":0,"rect":[65,39,32,1]},
		{"level":0,"rect":[89,40,1,3]}
	],
	"doors": [
		{"building":0,"level":0,"cell":[64,60],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[64,71],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[71,60],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[71,71],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[79,60],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[79,71],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[87,60],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[87,71],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[95,60],"side":[0,1],"state":"closed","outer":false},
		{"building":0,"level":0,"cell":[95,71],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[60,66],"side":[-1,0],"state":"open","outer":true},
		{"building":0,"level":0,"cell":[80,77],"side":[0,1],"state":"closed","outer":true},
		{"building":0,"level":1,"cell":[63,66],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":-1,"cell":[79,66],"side":[-1,0],"state":"open","outer":false},
		{"building":0,"level":-1,"cell":[96,66],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":0,"cell":[52,61],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":1,"cell":[52,61],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":2,"cell":[52,61],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":0,"cell":[56,63],"side":[0,1],"state":"open","outer":true},
		{"building":2,"level":0,"cell":[115,62],"side":[0,1],"state":"open","outer":false},
		{"building":2,"level":0,"cell":[115,65],"side":[0,-1],"state":"open","outer":false},
		{"building":2,"level":0,"cell":[126,62],"side":[0,1],"state":"open","outer":false},
		{"building":2,"level":0,"cell":[126,65],"side":[0,-1],"state":"open","outer":false},
		{"building":2,"level":0,"cell":[110,63],"side":[-1,0],"state":"open","outer":true},
		{"building":2,"level":0,"cell":[131,63],"side":[1,0],"state":"open","outer":true},
		{"building":2,"level":1,"cell":[115,62],"side":[0,1],"state":"open","outer":false},
		{"building":2,"level":1,"cell":[115,65],"side":[0,-1],"state":"open","outer":false},
		{"building":2,"level":1,"cell":[126,62],"side":[0,1],"state":"open","outer":false},
		{"building":2,"level":1,"cell":[126,65],"side":[0,-1],"state":"open","outer":false},
		{"building":2,"level":2,"cell":[115,62],"side":[0,1],"state":"open","outer":false},
		{"building":2,"level":2,"cell":[115,65],"side":[0,-1],"state":"open","outer":false},
		{"building":2,"level":2,"cell":[126,62],"side":[0,1],"state":"open","outer":false},
		{"building":2,"level":2,"cell":[126,65],"side":[0,-1],"state":"open","outer":false},
		{"building":3,"level":0,"cell":[34,60],"side":[0,1],"state":"open","outer":false},
		{"building":3,"level":0,"cell":[34,63],"side":[0,-1],"state":"open","outer":false},
		{"building":3,"level":0,"cell":[25,61],"side":[-1,0],"state":"open","outer":true},
		{"building":3,"level":0,"cell":[42,61],"side":[1,0],"state":"open","outer":true},
		{"building":3,"level":1,"cell":[34,60],"side":[0,1],"state":"open","outer":false},
		{"building":3,"level":1,"cell":[34,63],"side":[0,-1],"state":"open","outer":false},
		{"building":4,"level":0,"cell":[78,86],"side":[0,1],"state":"open","outer":false},
		{"building":4,"level":0,"cell":[78,89],"side":[0,-1],"state":"open","outer":false},
		{"building":4,"level":0,"cell":[70,87],"side":[-1,0],"state":"open","outer":true},
		{"building":4,"level":0,"cell":[85,87],"side":[1,0],"state":"open","outer":true},
		{"building":5,"level":0,"cell":[64,36],"side":[-1,0],"state":"open","outer":true},
		{"building":5,"level":0,"cell":[97,36],"side":[1,0],"state":"open","outer":true},
		{"building":6,"level":0,"cell":[35,21],"side":[0,1],"state":"open","outer":false},
		{"building":6,"level":0,"cell":[35,24],"side":[0,-1],"state":"open","outer":false},
		{"building":6,"level":0,"cell":[28,22],"side":[-1,0],"state":"open","outer":true},
		{"building":6,"level":0,"cell":[41,22],"side":[1,0],"state":"open","outer":true},
		{"building":6,"level":1,"cell":[35,21],"side":[0,1],"state":"open","outer":false},
		{"building":6,"level":1,"cell":[35,24],"side":[0,-1],"state":"open","outer":false},
		{"building":7,"level":0,"cell":[90,21],"side":[0,1],"state":"open","outer":false},
		{"building":7,"level":0,"cell":[90,24],"side":[0,-1],"state":"open","outer":false},
		{"building":7,"level":0,"cell":[84,22],"side":[-1,0],"state":"open","outer":true},
		{"building":7,"level":0,"cell":[95,22],"side":[1,0],"state":"open","outer":true},
		{"building":7,"level":1,"cell":[90,21],"side":[0,1],"state":"open","outer":false},
		{"building":7,"level":1,"cell":[90,24],"side":[0,-1],"state":"open","outer":false},
		{"building":8,"level":0,"cell":[62,24],"side":[1,0],"state":"open","outer":false},
		{"building":8,"level":0,"cell":[54,24],"side":[-1,0],"state":"open","outer":true},
		{"building":8,"level":0,"cell":[69,24],"side":[1,0],"state":"open","outer":true},
		{"building":9,"level":0,"cell":[34,79],"side":[0,1],"state":"open","outer":false},
		{"building":9,"level":0,"cell":[34,82],"side":[0,-1],"state":"open","outer":false},
		{"building":9,"level":0,"cell":[26,80],"side":[-1,0],"state":"open","outer":true},
		{"building":9,"level":0,"cell":[41,80],"side":[1,0],"state":"open","outer":true},
		{"building":9,"level":1,"cell":[34,79],"side":[0,1],"state":"open","outer":false},
		{"building":9,"level":1,"cell":[34,82],"side":[0,-1],"state":"open","outer":false},
		{"building":10,"level":0,"cell":[11,59],"side":[0,1],"state":"open","outer":false},
		{"building":10,"level":0,"cell":[11,62],"side":[0,-1],"state":"open","outer":false},
		{"building":10,"level":0,"cell":[4,60],"side":[-1,0],"state":"open","outer":true},
		{"building":10,"level":0,"cell":[17,60],"side":[1,0],"state":"open","outer":true},
		{"building":10,"level":1,"cell":[11,59],"side":[0,1],"state":"open","outer":false},
		{"building":10,"level":1,"cell":[11,62],"side":[0,-1],"state":"open","outer":false},
		{"building":11,"level":0,"cell":[12,80],"side":[1,0],"state":"open","outer":false},
		{"building":11,"level":0,"cell":[5,80],"side":[-1,0],"state":"open","outer":true},
		{"building":11,"level":0,"cell":[18,80],"side":[1,0],"state":"open","outer":true},
		{"building":12,"level":0,"cell":[92,87],"side":[-1,0],"state":"open","outer":true},
		{"building":12,"level":0,"cell":[103,87],"side":[1,0],"state":"open","outer":true},
		{"building":13,"level":0,"cell":[137,73],"side":[-1,0],"state":"open","outer":true},
		{"building":14,"level":0,"cell":[108,86],"side":[-1,0],"state":"open","outer":true},
		{"building":5,"level":0,"cell":[70,39],"side":[0,-1],"state":"open","outer":false},
		{"building":5,"level":0,"cell":[93,39],"side":[0,-1],"state":"open","outer":false},
		{"building":5,"level":0,"cell":[76,43],"side":[0,1],"state":"open","outer":true}
	],
	"windows": [
		{"building":0,"level":0,"cell":[71,54],"broken":false},
		{"building":0,"level":0,"cell":[71,77],"broken":false},
		{"building":0,"level":0,"cell":[88,54],"broken":false},
		{"building":0,"level":0,"cell":[88,77],"broken":false},
		{"building":0,"level":0,"cell":[60,56],"broken":false},
		{"building":0,"level":1,"cell":[62,54],"broken":false},
		{"building":0,"level":1,"cell":[62,77],"broken":false},
		{"building":0,"level":1,"cell":[65,54],"broken":false},
		{"building":0,"level":1,"cell":[65,77],"broken":false},
		{"building":0,"level":1,"cell":[60,56],"broken":false},
		{"building":1,"level":0,"cell":[51,54],"broken":false},
		{"building":1,"level":0,"cell":[51,63],"broken":false},
		{"building":1,"level":0,"cell":[54,54],"broken":false},
		{"building":1,"level":0,"cell":[54,63],"broken":false},
		{"building":1,"level":0,"cell":[48,56],"broken":false},
		{"building":1,"level":1,"cell":[51,54],"broken":false},
		{"building":1,"level":1,"cell":[51,63],"broken":false},
		{"building":1,"level":1,"cell":[54,54],"broken":false},
		{"building":1,"level":1,"cell":[54,63],"broken":false},
		{"building":1,"level":1,"cell":[48,56],"broken":false},
		{"building":1,"level":2,"cell":[51,54],"broken":false},
		{"building":1,"level":2,"cell":[51,63],"broken":false},
		{"building":1,"level":2,"cell":[54,54],"broken":false},
		{"building":1,"level":2,"cell":[54,63],"broken":false},
		{"building":1,"level":2,"cell":[48,56],"broken":false},
		{"building":2,"level":0,"cell":[116,54],"broken":false},
		{"building":2,"level":0,"cell":[116,73],"broken":false},
		{"building":2,"level":0,"cell":[125,54],"broken":false},
		{"building":2,"level":0,"cell":[125,73],"broken":false},
		{"building":2,"level":0,"cell":[110,56],"broken":false},
		{"building":2,"level":1,"cell":[116,54],"broken":false},
		{"building":2,"level":1,"cell":[116,73],"broken":false},
		{"building":2,"level":1,"cell":[125,54],"broken":false},
		{"building":2,"level":1,"cell":[125,73],"broken":false},
		{"building":2,"level":1,"cell":[110,56],"broken":false},
		{"building":2,"level":2,"cell":[116,54],"broken":false},
		{"building":2,"level":2,"cell":[116,73],"broken":false},
		{"building":2,"level":2,"cell":[125,54],"broken":false},
		{"building":2,"level":2,"cell":[125,73],"broken":false},
		{"building":2,"level":2,"cell":[110,56],"broken":false},
		{"building":3,"level":0,"cell":[30,55],"broken":false},
		{"building":3,"level":0,"cell":[30,68],"broken":false},
		{"building":3,"level":0,"cell":[37,55],"broken":false},
		{"building":3,"level":0,"cell":[37,68],"broken":false},
		{"building":3,"level":0,"cell":[25,57],"broken":false},
		{"building":3,"level":1,"cell":[30,55],"broken":false},
		{"building":3,"level":1,"cell":[30,68],"broken":false},
		{"building":3,"level":1,"cell":[37,55],"broken":false},
		{"building":3,"level":1,"cell":[37,68],"broken":false},
		{"building":3,"level":1,"cell":[25,57],"broken":false},
		{"building":4,"level":0,"cell":[74,82],"broken":false},
		{"building":4,"level":0,"cell":[74,93],"broken":false},
		{"building":4,"level":0,"cell":[81,82],"broken":false},
		{"building":4,"level":0,"cell":[81,93],"broken":false},
		{"building":4,"level":0,"cell":[70,84],"broken":false},
		{"building":5,"level":0,"cell":[73,30],"broken":false},
		{"building":5,"level":0,"cell":[73,43],"broken":false},
		{"building":5,"level":0,"cell":[88,30],"broken":false},
		{"building":5,"level":0,"cell":[88,43],"broken":false},
		{"building":5,"level":0,"cell":[64,32],"broken":false},
		{"building":6,"level":0,"cell":[32,17],"broken":false},
		{"building":6,"level":0,"cell":[32,28],"broken":false},
		{"building":6,"level":0,"cell":[37,17],"broken":false},
		{"building":6,"level":0,"cell":[37,28],"broken":false},
		{"building":6,"level":0,"cell":[28,19],"broken":false},
		{"building":6,"level":1,"cell":[32,17],"broken":false},
		{"building":6,"level":1,"cell":[32,28],"broken":false},
		{"building":6,"level":1,"cell":[37,17],"broken":false},
		{"building":6,"level":1,"cell":[37,28],"broken":false},
		{"building":6,"level":1,"cell":[28,19],"broken":false},
		{"building":7,"level":0,"cell":[87,17],"broken":false},
		{"building":7,"level":0,"cell":[87,28],"broken":false},
		{"building":7,"level":0,"cell":[92,17],"broken":false},
		{"building":7,"level":0,"cell":[92,28],"broken":false},
		{"building":7,"level":0,"cell":[84,19],"broken":false},
		{"building":7,"level":1,"cell":[87,17],"broken":false},
		{"building":7,"level":1,"cell":[87,28],"broken":false},
		{"building":7,"level":1,"cell":[92,17],"broken":false},
		{"building":7,"level":1,"cell":[92,28],"broken":false},
		{"building":7,"level":1,"cell":[84,19],"broken":false},
		{"building":8,"level":0,"cell":[58,20],"broken":false},
		{"building":8,"level":0,"cell":[58,27],"broken":false},
		{"building":8,"level":0,"cell":[65,20],"broken":false},
		{"building":8,"level":0,"cell":[65,27],"broken":false},
		{"building":8,"level":0,"cell":[54,22],"broken":false},
		{"building":9,"level":0,"cell":[30,75],"broken":false},
		{"building":9,"level":0,"cell":[30,86],"broken":false},
		{"building":9,"level":0,"cell":[37,75],"broken":false},
		{"building":9,"level":0,"cell":[37,86],"broken":false},
		{"building":9,"level":0,"cell":[26,77],"broken":false},
		{"building":9,"level":1,"cell":[30,75],"broken":false},
		{"building":9,"level":1,"cell":[30,86],"broken":false},
		{"building":9,"level":1,"cell":[37,75],"broken":false},
		{"building":9,"level":1,"cell":[37,86],"broken":false},
		{"building":9,"level":1,"cell":[26,77],"broken":false},
		{"building":10,"level":0,"cell":[8,55],"broken":false},
		{"building":10,"level":0,"cell":[8,66],"broken":false},
		{"building":10,"level":0,"cell":[13,55],"broken":false},
		{"building":10,"level":0,"cell":[13,66],"broken":false},
		{"building":10,"level":0,"cell":[4,57],"broken":false},
		{"building":10,"level":1,"cell":[8,55],"broken":false},
		{"building":10,"level":1,"cell":[8,66],"broken":false},
		{"building":10,"level":1,"cell":[13,55],"broken":false},
		{"building":10,"level":1,"cell":[13,66],"broken":false},
		{"building":10,"level":1,"cell":[4,57],"broken":false},
		{"building":11,"level":0,"cell":[9,75],"broken":false},
		{"building":11,"level":0,"cell":[9,84],"broken":false},
		{"building":11,"level":0,"cell":[14,75],"broken":false},
		{"building":11,"level":0,"cell":[14,84],"broken":false},
		{"building":11,"level":0,"cell":[5,77],"broken":false},
		{"building":12,"level":0,"cell":[95,83],"broken":false},
		{"building":12,"level":0,"cell":[95,90],"broken":false},
		{"building":12,"level":0,"cell":[100,83],"broken":false},
		{"building":12,"level":0,"cell":[100,90],"broken":false},
		{"building":12,"level":0,"cell":[92,85],"broken":false},
		{"building":13,"level":0,"cell":[139,70],"broken":false},
		{"building":13,"level":0,"cell":[139,75],"broken":false},
		{"building":13,"level":0,"cell":[142,70],"broken":false},
		{"building":13,"level":0,"cell":[142,75],"broken":false},
		{"building":13,"level":0,"cell":[137,72],"broken":false},
		{"building":14,"level":0,"cell":[110,83],"broken":false},
		{"building":14,"level":0,"cell":[110,88],"broken":false},
		{"building":14,"level":0,"cell":[111,83],"broken":false},
		{"building":14,"level":0,"cell":[111,88],"broken":false},
		{"building":14,"level":0,"cell":[108,85],"broken":false}
	],
	"stairs": [
		{"cell":[61,56],"low":0,"high":1,"ladder":false},
		{"cell":[77,56],"low":-1,"high":0,"ladder":false},
		{"cell":[98,75],"low":-1,"high":0,"ladder":false},
		{"cell":[49,55],"low":0,"high":1,"ladder":false},
		{"cell":[56,62],"low":1,"high":2,"ladder":false},
		{"cell":[112,63],"low":0,"high":1,"ladder":false},
		{"cell":[129,63],"low":1,"high":2,"ladder":false},
		{"cell":[27,61],"low":0,"high":1,"ladder":false},
		{"cell":[30,22],"low":0,"high":1,"ladder":false},
		{"cell":[86,22],"low":0,"high":1,"ladder":false},
		{"cell":[28,80],"low":0,"high":1,"ladder":false},
		{"cell":[6,60],"low":0,"high":1,"ladder":false}
	],
	"props": [
		{"kind":"plank_patch","rect":[64,55,3,1],"solid":"wall","facing":0,"note":"안에서 덧댄 널판","level":0},
		{"kind":"plank_patch","rect":[79,55,3,1],"solid":"wall","facing":1,"note":"안에서 덧댄 널판","level":0},
		{"kind":"plank_patch","rect":[88,55,3,1],"solid":"wall","facing":2,"note":"안에서 덧댄 널판","level":0},
		{"kind":"plank_patch","rect":[77,75,3,1],"solid":"none","facing":3,"note":"안에서 덧댄 남쪽 옆문의 널","level":0},
		{"kind":"bell_rope","rect":[50,57,1,1],"solid":"none","facing":0,"note":"종 줄 한 가닥","level":1},
		{"kind":"bell_frame","rect":[53,56,3,3],"solid":"none","facing":1,"note":"종을 거는 나무 틀","level":2},
		{"kind":"car","rect":[31,11,4,2],"solid":"low","facing":2,"note":"길가에 선 차","level":0},
		{"kind":"bench","rect":[50,12,3,1],"solid":"low","facing":3,"note":"긴 의자","level":0},
		{"kind":"car","rect":[44,25,4,2],"solid":"low","facing":0,"note":"길가에 선 차","level":0},
		{"kind":"crate_stack","rect":[78,25,2,2],"solid":"low","facing":1,"note":"나무 상자","level":0},
		{"kind":"firewood_pile","rect":[74,25,2,1],"solid":"low","facing":2,"note":"처마 밑 장작","level":0},
		{"kind":"bench","rect":[66,61,3,1],"solid":"low","facing":3,"note":"긴 의자","level":0},
		{"kind":"bench","rect":[74,64,3,1],"solid":"low","facing":0,"note":"긴 의자","level":0},
		{"kind":"bench","rect":[82,61,3,1],"solid":"low","facing":1,"note":"긴 의자","level":0},
		{"kind":"bench","rect":[90,64,3,1],"solid":"low","facing":2,"note":"긴 의자","level":0},
		{"kind":"blanket_screen","rect":[66,64,3,1],"solid":"low","facing":3,"note":"반쯤 열린 잠자리 담요","level":0},
		{"kind":"blanket_screen","rect":[86,67,3,1],"solid":"low","facing":0,"note":"반쯤 열린 잠자리 담요","level":0},
		{"kind":"cooking_pot","rect":[82,65,2,2],"solid":"low","facing":1,"note":"음식을 나누던 작은 솥","level":0},
		{"kind":"firewood_pile","rect":[62,67,2,1],"solid":"low","facing":2,"note":"처마 밑 장작","level":0},
		{"kind":"firewood_pile","rect":[70,67,2,1],"solid":"low","facing":3,"note":"처마 밑 장작","level":0},
		{"kind":"firewood_pile","rect":[90,68,2,1],"solid":"low","facing":0,"note":"처마 밑 장작","level":0},
		{"kind":"lamp_post","rect":[33,44,1,1],"solid":"none","facing":1,"note":"꺼진 등잔 기둥","level":0},
		{"kind":"crate_stack","rect":[37,42,2,2],"solid":"low","facing":2,"note":"나무 상자","level":0},
		{"kind":"snow_drift","rect":[30,42,4,2],"solid":"none","facing":3,"note":"모서리의 눈더미","level":0},
		{"kind":"car","rect":[146,47,4,2],"solid":"low","facing":0,"note":"길가에 선 차","level":0},
		{"kind":"car","rect":[153,48,4,2],"solid":"low","facing":1,"note":"길가에 선 차","level":0},
		{"kind":"community_banner","rect":[148,73,1,2],"solid":"none","facing":2,"note":"무늬 없는 바랜 천 깃발","level":0},
		{"kind":"bare_tree","rect":[5,17,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[14,22,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[21,29,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[7,36,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[19,41,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[3,53,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[21,66,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[3,71,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[22,88,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[9,90,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[32,91,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[60,88,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[67,93,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[88,89,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[104,93,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[118,91,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[127,88,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[147,89,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[155,83,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[160,73,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[159,60,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[147,55,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[145,38,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[160,31,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[137,26,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[150,18,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[125,14,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[115,23,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[114,30,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[99,37,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[47,38,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[53,42,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"hymn_shelf","rect":[61,55,2,1],"solid":"low","facing":3,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[66,59,1,1],"solid":"low","facing":0,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[61,59,2,1],"solid":"low","facing":1,"note":"제의실 궤","level":0},
		{"kind":"candle_stand","rect":[61,76,1,1],"solid":"low","facing":0,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[65,72,2,1],"solid":"low","facing":1,"note":"제의실 궤","level":0},
		{"kind":"candle_stand","rect":[74,55,1,1],"solid":"low","facing":0,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[69,55,2,1],"solid":"low","facing":1,"note":"제의실 궤","level":0},
		{"kind":"candle_stand","rect":[69,72,1,1],"solid":"low","facing":0,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[72,76,2,1],"solid":"low","facing":1,"note":"제의실 궤","level":0},
		{"kind":"vestry_chest","rect":[76,59,2,1],"solid":"low","facing":1,"note":"제의실 궤","level":0},
		{"kind":"vestry_chest","rect":[76,76,2,1],"solid":"low","facing":1,"note":"제의실 궤","level":0},
		{"kind":"vestry_chest","rect":[84,59,2,1],"solid":"low","facing":1,"note":"제의실 궤","level":0},
		{"kind":"vestry_chest","rect":[89,72,2,1],"solid":"low","facing":1,"note":"제의실 궤","level":0},
		{"kind":"parish_chest","rect":[92,59,2,1],"solid":"low","facing":3,"note":"회중 기록 궤","level":0},
		{"kind":"desk","rect":[93,55,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"vestry_chest","rect":[96,76,2,1],"solid":"low","facing":1,"note":"제의실 궤","level":0},
		{"kind":"vestry_chest","rect":[61,65,2,1],"solid":"none","facing":1,"note":"제의실 궤","level":1},
		{"kind":"vestry_chest","rect":[61,76,2,1],"solid":"none","facing":1,"note":"제의실 궤","level":1},
		{"kind":"cold_stove","rect":[87,73,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":-1},
		{"kind":"coal_bin","rect":[80,72,3,2],"solid":"none","facing":0,"note":"난방용 석탄","level":-1},
		{"kind":"firewood_pile","rect":[86,58,2,1],"solid":"none","facing":1,"note":"처마 밑 장작","level":-1},
		{"kind":"barrel","rect":[81,58,1,1],"solid":"none","facing":2,"note":"저장 통","level":-1},
		{"kind":"cask_stack","rect":[89,72,2,2],"solid":"none","facing":3,"note":"저장고 큰 통","level":-1},
		{"kind":"sack_pile","rect":[94,58,2,2],"solid":"none","facing":0,"note":"곡물 자루","level":-1},
		{"kind":"relief_crate","rect":[90,58,2,1],"solid":"none","facing":1,"note":"남은 구호 식량 상자","level":-1},
		{"kind":"barrel","rect":[94,73,1,1],"solid":"none","facing":2,"note":"저장 통","level":-1},
		{"kind":"hand_bell","rect":[50,55,1,1],"solid":"low","facing":3,"note":"글씨 없는 손종","level":0},
		{"kind":"lamp_shelf","rect":[49,62,2,1],"solid":"low","facing":0,"note":"꺼진 등잔 선반","level":0},
		{"kind":"lamp_shelf","rect":[53,55,2,1],"solid":"low","facing":3,"note":"꺼진 등잔 선반","level":0},
		{"kind":"lamp_shelf","rect":[49,62,2,1],"solid":"none","facing":2,"note":"꺼진 등잔 선반","level":1},
		{"kind":"lamp_shelf","rect":[55,55,2,1],"solid":"none","facing":1,"note":"꺼진 등잔 선반","level":1},
		{"kind":"lamp_shelf","rect":[50,55,2,1],"solid":"none","facing":0,"note":"꺼진 등잔 선반","level":2},
		{"kind":"lamp_shelf","rect":[54,55,2,1],"solid":"none","facing":3,"note":"꺼진 등잔 선반","level":2},
		{"kind":"bench","rect":[53,62,3,1],"solid":"none","facing":0,"note":"긴 의자","level":2},
		{"kind":"slate_board","rect":[112,55,2,1],"solid":"low","facing":2,"note":"글씨 없는 칠판","level":0},
		{"kind":"shelf","rect":[117,55,3,1],"solid":"low","facing":1,"note":"물건 선반","level":0},
		{"kind":"slate_board","rect":[117,72,2,1],"solid":"low","facing":2,"note":"글씨 없는 칠판","level":0},
		{"kind":"shelf","rect":[117,66,3,1],"solid":"low","facing":1,"note":"물건 선반","level":0},
		{"kind":"slate_board","rect":[121,55,2,1],"solid":"low","facing":2,"note":"글씨 없는 칠판","level":0},
		{"kind":"shelf","rect":[128,55,3,1],"solid":"low","facing":1,"note":"물건 선반","level":0},
		{"kind":"slate_board","rect":[129,72,2,1],"solid":"low","facing":2,"note":"글씨 없는 칠판","level":0},
		{"kind":"shelf","rect":[122,66,3,1],"solid":"low","facing":1,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[111,61,2,1],"solid":"none","facing":2,"note":"침대","level":1},
		{"kind":"cold_stove","rect":[112,55,1,1],"solid":"none","facing":0,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[116,61,3,1],"solid":"none","facing":1,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[118,66,2,1],"solid":"none","facing":2,"note":"침대","level":1},
		{"kind":"shelf","rect":[111,72,3,1],"solid":"none","facing":1,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[122,55,2,1],"solid":"none","facing":2,"note":"침대","level":1},
		{"kind":"cold_stove","rect":[121,55,1,1],"solid":"none","facing":0,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[121,61,3,1],"solid":"none","facing":1,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[128,72,2,1],"solid":"none","facing":2,"note":"침대","level":1},
		{"kind":"shelf","rect":[121,72,3,1],"solid":"none","facing":1,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[111,55,2,1],"solid":"none","facing":2,"note":"침대","level":2},
		{"kind":"cold_stove","rect":[111,61,1,1],"solid":"none","facing":0,"note":"꺼진 난로","level":2},
		{"kind":"shelf","rect":[117,55,3,1],"solid":"none","facing":1,"note":"물건 선반","level":2},
		{"kind":"bed","rect":[118,72,2,1],"solid":"none","facing":2,"note":"침대","level":2},
		{"kind":"shelf","rect":[112,66,3,1],"solid":"none","facing":1,"note":"물건 선반","level":2},
		{"kind":"bed","rect":[121,61,2,1],"solid":"none","facing":2,"note":"침대","level":2},
		{"kind":"cold_stove","rect":[122,55,1,1],"solid":"none","facing":0,"note":"꺼진 난로","level":2},
		{"kind":"shelf","rect":[127,61,3,1],"solid":"none","facing":1,"note":"물건 선반","level":2},
		{"kind":"bed","rect":[129,66,2,1],"solid":"none","facing":2,"note":"침대","level":2},
		{"kind":"shelf","rect":[121,72,3,1],"solid":"none","facing":1,"note":"물건 선반","level":2},
		{"kind":"cold_stove","rect":[26,56,1,1],"solid":"low","facing":0,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[26,59,3,1],"solid":"low","facing":1,"note":"물건 선반","level":0},
		{"kind":"shelf","rect":[26,67,3,1],"solid":"low","facing":1,"note":"물건 선반","level":0},
		{"kind":"cold_stove","rect":[26,59,1,1],"solid":"none","facing":0,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[39,56,3,1],"solid":"none","facing":1,"note":"물건 선반","level":1},
		{"kind":"shelf","rect":[27,64,3,1],"solid":"none","facing":1,"note":"물건 선반","level":1},
		{"kind":"sack_pile","rect":[83,83,2,2],"solid":"low","facing":3,"note":"곡물 자루","level":0},
		{"kind":"barrel","rect":[72,83,1,1],"solid":"low","facing":0,"note":"저장 통","level":0},
		{"kind":"sack_pile","rect":[72,90,2,2],"solid":"low","facing":2,"note":"곡물 자루","level":0},
		{"kind":"barrel","rect":[83,92,1,1],"solid":"low","facing":3,"note":"저장 통","level":0},
		{"kind":"cold_stove","rect":[29,18,1,1],"solid":"none","facing":2,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[29,20,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"shelf","rect":[29,27,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"shelf","rect":[91,20,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"shelf","rect":[85,27,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"shelf","rect":[38,76,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"shelf","rect":[28,83,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"shelf","rect":[37,78,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"shelf","rect":[27,85,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"shelf","rect":[5,58,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"shelf","rect":[5,65,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"shelf","rect":[14,56,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"shelf","rect":[6,63,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"shelf","rect":[8,83,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"shelf","rect":[13,83,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"coal_bin","rect":[99,88,3,2],"solid":"low","facing":1,"note":"난방용 석탄","level":0},
		{"kind":"firewood_pile","rect":[93,89,2,1],"solid":"low","facing":2,"note":"처마 밑 장작","level":0},
		{"kind":"barrel","rect":[102,89,1,1],"solid":"low","facing":3,"note":"저장 통","level":0},
		{"kind":"shelf","rect":[138,74,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"display_shelf","rect":[67,32,1,4],"solid":"low","facing":1,"note":"가게 진열대","level":0},
		{"kind":"display_shelf","rect":[70,32,1,4],"solid":"low","facing":2,"note":"가게 진열대","level":0},
		{"kind":"display_shelf","rect":[73,32,1,4],"solid":"low","facing":3,"note":"가게 진열대","level":0},
		{"kind":"display_shelf","rect":[82,32,1,4],"solid":"low","facing":0,"note":"가게 진열대","level":0},
		{"kind":"display_shelf","rect":[85,32,1,4],"solid":"low","facing":1,"note":"가게 진열대","level":0},
		{"kind":"shopping_cart","rect":[65,31,1,1],"solid":"low","facing":2,"note":"장보기 수레","level":0},
		{"kind":"shopping_cart","rect":[65,33,1,1],"solid":"low","facing":3,"note":"장보기 수레","level":0},
		{"kind":"freezer_chest","rect":[90,31,2,1],"solid":"low","facing":0,"note":"냉동 궤","level":0},
		{"kind":"freezer_chest","rect":[90,35,2,1],"solid":"low","facing":1,"note":"냉동 궤","level":0},
		{"kind":"pallet_stack","rect":[65,40,2,2],"solid":"low","facing":2,"note":"평평한 하역 문 곁 팰릿","level":0},
		{"kind":"sack_pile","rect":[73,40,2,2],"solid":"low","facing":3,"note":"곡물 자루","level":0},
		{"kind":"desk","rect":[90,40,2,1],"solid":"low","facing":0,"note":"책상","level":0},
		{"kind":"shelf","rect":[94,41,3,1],"solid":"low","facing":1,"note":"물건 선반","level":0},
		{"kind":"hand_bell","rect":[27,76,1,1],"solid":"none","facing":3,"note":"글씨 없는 손종","level":1},
		{"kind":"hymn_shelf","rect":[66,31,2,1],"solid":"low","facing":0,"note":"찬송집 선반","level":0},
		{"kind":"pew_row","rect":[88,61,6,1],"solid":"low","facing":3,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[65,63,6,1],"solid":"low","facing":0,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[88,63,6,1],"solid":"low","facing":1,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[62,65,6,1],"solid":"low","facing":2,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[84,65,6,1],"solid":"low","facing":3,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[64,67,6,1],"solid":"low","facing":0,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[89,67,6,1],"solid":"low","facing":1,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[65,69,6,1],"solid":"low","facing":2,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[88,69,6,1],"solid":"low","facing":3,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"cooking_pot","rect":[73,83,2,2],"solid":"low","facing":2,"note":"음식을 나누던 작은 솥","level":0},
		{"kind":"cooking_pot","rect":[74,90,2,2],"solid":"low","facing":1,"note":"음식을 나누던 작은 솥","level":0},
		{"kind":"checkout","rect":[68,31,2,1],"solid":"low","facing":0,"note":"식료품 계산대","level":0},
		{"kind":"checkout","rect":[70,31,2,1],"solid":"low","facing":1,"note":"식료품 계산대","level":0},
		{"kind":"altar_table","rect":[92,62,3,1],"solid":"low","facing":2,"note":"무늬 없는 천을 덮은 제단 탁자","level":0},
		{"kind":"pulpit","rect":[96,62,2,2],"solid":"low","facing":3,"note":"설교단","level":0},
		{"kind":"community_banner","rect":[94,63,1,2],"solid":"none","facing":2,"note":"무늬 없는 바랜 천 깃발","level":0},
		{"kind":"lamp_shelf","rect":[32,52,2,1],"solid":"low","facing":3,"note":"맨홀 곁 꺼진 등잔","level":0},
		{"kind":"crate_stack","rect":[39,52,2,2],"solid":"low","facing":0,"note":"맨홀 곁 나무 상자","level":0}
	],
	"rooms": [
		{"building":0,"level":0,"rect":[61,55,6,5],"name":"찬송집 방","theme":"church"},
		{"building":0,"level":0,"rect":[61,72,6,5],"name":"종지기 방","theme":"church"},
		{"building":0,"level":0,"rect":[68,55,7,5],"name":"현관 방","theme":"church"},
		{"building":0,"level":0,"rect":[68,72,7,5],"name":"옆 예배실","theme":"church"},
		{"building":0,"level":0,"rect":[76,55,7,5],"name":"제의실","theme":"church"},
		{"building":0,"level":0,"rect":[76,72,7,5],"name":"회중 준비방","theme":"church"},
		{"building":0,"level":0,"rect":[84,55,7,5],"name":"교구 사무방","theme":"church"},
		{"building":0,"level":0,"rect":[84,72,7,5],"name":"성가대방","theme":"church"},
		{"building":0,"level":0,"rect":[92,55,7,5],"name":"기록방","theme":"archive"},
		{"building":0,"level":0,"rect":[92,72,7,5],"name":"안쪽 저장실","theme":"church"},
		{"building":0,"level":0,"rect":[61,61,38,10],"name":"회중석","theme":"nave"},
		{"building":0,"level":1,"rect":[61,55,6,11],"name":"합창 다락 앞방","theme":"church"},
		{"building":0,"level":1,"rect":[61,67,6,10],"name":"합창 다락 뒷방","theme":"church"},
		{"building":0,"level":-1,"rect":[80,58,8,16],"name":"난방실","theme":"heat"},
		{"building":0,"level":-1,"rect":[89,58,7,16],"name":"막다른 식량 저장실","theme":"cellar"},
		{"building":0,"level":-1,"rect":[77,55,22,2],"name":"저장고 둘레 통로","theme":"corridor"},
		{"building":1,"level":0,"rect":[49,55,3,8],"name":"탑 아래 앞방","theme":"tower"},
		{"building":1,"level":0,"rect":[53,55,4,8],"name":"탑 아래 뒷방","theme":"tower"},
		{"building":1,"level":1,"rect":[49,55,3,8],"name":"종 줄 방","theme":"tower"},
		{"building":1,"level":1,"rect":[53,55,4,8],"name":"종 줄 방의 돌아가는 길","theme":"tower"},
		{"building":1,"level":2,"rect":[49,55,3,8],"name":"종 다락 앞방","theme":"tower"},
		{"building":1,"level":2,"rect":[53,55,4,8],"name":"종 다락","theme":"tower"},
		{"building":2,"level":0,"rect":[111,55,9,7],"name":"교구 학교 앞방","theme":"school"},
		{"building":2,"level":0,"rect":[111,66,9,7],"name":"교구 학교 뒷방","theme":"school"},
		{"building":2,"level":0,"rect":[121,55,10,7],"name":"교구 학교 앞방","theme":"school"},
		{"building":2,"level":0,"rect":[121,66,10,7],"name":"교구 학교 뒷방","theme":"school"},
		{"building":2,"level":1,"rect":[111,55,9,7],"name":"교구 학교 앞방","theme":"home"},
		{"building":2,"level":1,"rect":[111,66,9,7],"name":"교구 학교 뒷방","theme":"home"},
		{"building":2,"level":1,"rect":[121,55,10,7],"name":"교구 학교 앞방","theme":"home"},
		{"building":2,"level":1,"rect":[121,66,10,7],"name":"교구 학교 뒷방","theme":"home"},
		{"building":2,"level":2,"rect":[111,55,9,7],"name":"교구 학교 앞방","theme":"home"},
		{"building":2,"level":2,"rect":[111,66,9,7],"name":"교구 학교 뒷방","theme":"home"},
		{"building":2,"level":2,"rect":[121,55,10,7],"name":"교구 학교 앞방","theme":"home"},
		{"building":2,"level":2,"rect":[121,66,10,7],"name":"교구 학교 뒷방","theme":"home"},
		{"building":3,"level":0,"rect":[26,56,16,4],"name":"교구 회관 앞방","theme":"home"},
		{"building":3,"level":0,"rect":[26,64,16,4],"name":"교구 회관 뒷방","theme":"home"},
		{"building":3,"level":1,"rect":[26,56,16,4],"name":"교구 회관 앞방","theme":"home"},
		{"building":3,"level":1,"rect":[26,64,16,4],"name":"교구 회관 뒷방","theme":"home"},
		{"building":4,"level":0,"rect":[71,83,14,3],"name":"급식 부엌 앞방","theme":"kitchen"},
		{"building":4,"level":0,"rect":[71,90,14,3],"name":"급식 부엌 뒷방","theme":"kitchen"},
		{"building":6,"level":0,"rect":[29,18,12,3],"name":"주택 가 앞방","theme":"home"},
		{"building":6,"level":0,"rect":[29,25,12,3],"name":"주택 가 뒷방","theme":"home"},
		{"building":6,"level":1,"rect":[29,18,12,3],"name":"주택 가 앞방","theme":"home"},
		{"building":6,"level":1,"rect":[29,25,12,3],"name":"주택 가 뒷방","theme":"home"},
		{"building":7,"level":0,"rect":[85,18,10,3],"name":"주택 나 앞방","theme":"home"},
		{"building":7,"level":0,"rect":[85,25,10,3],"name":"주택 나 뒷방","theme":"home"},
		{"building":7,"level":1,"rect":[85,18,10,3],"name":"주택 나 앞방","theme":"home"},
		{"building":7,"level":1,"rect":[85,25,10,3],"name":"주택 나 뒷방","theme":"home"},
		{"building":8,"level":0,"rect":[55,21,7,6],"name":"차고 앞방","theme":"store"},
		{"building":8,"level":0,"rect":[63,21,6,6],"name":"차고 뒷방","theme":"store"},
		{"building":9,"level":0,"rect":[27,76,14,3],"name":"사제관 앞방","theme":"home"},
		{"building":9,"level":0,"rect":[27,83,14,3],"name":"사제관 뒷방","theme":"home"},
		{"building":9,"level":1,"rect":[27,76,14,3],"name":"사제관 앞방","theme":"home"},
		{"building":9,"level":1,"rect":[27,83,14,3],"name":"사제관 뒷방","theme":"home"},
		{"building":10,"level":0,"rect":[5,56,12,3],"name":"서쪽 주택 다 앞방","theme":"home"},
		{"building":10,"level":0,"rect":[5,63,12,3],"name":"서쪽 주택 다 뒷방","theme":"home"},
		{"building":10,"level":1,"rect":[5,56,12,3],"name":"서쪽 주택 다 앞방","theme":"home"},
		{"building":10,"level":1,"rect":[5,63,12,3],"name":"서쪽 주택 다 뒷방","theme":"home"},
		{"building":11,"level":0,"rect":[6,76,6,8],"name":"서쪽 주택 라 앞방","theme":"home"},
		{"building":11,"level":0,"rect":[13,76,5,8],"name":"서쪽 주택 라 뒷방","theme":"home"},
		{"building":12,"level":0,"rect":[93,84,10,6],"name":"장작 헛간 안방","theme":"heat"},
		{"building":13,"level":0,"rect":[138,71,6,4],"name":"학교 숙직 헛간 안방","theme":"home"},
		{"building":14,"level":0,"rect":[109,84,4,4],"name":"우물집 안방","theme":"home"},
		{"building":5,"level":0,"rect":[65,31,32,8],"name":"진열 매장","theme":"nave"},
		{"building":5,"level":0,"rect":[65,40,23,3],"name":"뒤 창고","theme":"store"},
		{"building":5,"level":0,"rect":[90,40,7,3],"name":"가게 사무실","theme":"home"}
	],
	"containers": [
		{"id":"box_001","name":"찬송집 방 보관함","cell":[61,58],"building":0,"search":4,"items":["document"],"locked":false,"level":0,"searched":false},
		{"id":"box_002","name":"종지기 방 보관함","cell":[62,75],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_003","name":"현관 방 보관함","cell":[74,57],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_004","name":"옆 예배실 보관함","cell":[70,75],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_005","name":"제의실 보관함","cell":[82,57],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_006","name":"회중 준비방 보관함","cell":[76,75],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_007","name":"교구 사무방 보관함","cell":[90,57],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_008","name":"성가대방 보관함","cell":[85,75],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_009","name":"기록방 보관함","cell":[92,58],"building":0,"search":6,"items":["document","symbol_bell","food_pack"],"locked":false,"level":0,"searched":false},
		{"id":"box_010","name":"안쪽 저장실 보관함","cell":[94,75],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_011","name":"회중석 보관함","cell":[81,67],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_012","name":"합창 다락 앞방 보관함","cell":[66,61],"building":0,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_013","name":"합창 다락 뒷방 보관함","cell":[65,73],"building":0,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_014","name":"난방실 보관함","cell":[84,68],"building":0,"search":4,"items":[],"locked":false,"level":-1,"searched":false},
		{"id":"box_015","name":"막다른 식량 저장실 보관함","cell":[92,68],"building":0,"search":4,"items":[],"locked":false,"level":-1,"searched":false},
		{"id":"box_016","name":"탑 아래 앞방 보관함","cell":[49,59],"building":1,"search":4,"items":["symbol_bell"],"locked":false,"level":0,"searched":false},
		{"id":"box_017","name":"탑 아래 뒷방 보관함","cell":[55,59],"building":1,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_018","name":"종 줄 방 보관함","cell":[51,59],"building":1,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_019","name":"종 줄 방의 돌아가는 길 보관함","cell":[55,59],"building":1,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_020","name":"종 다락 앞방 보관함","cell":[50,59],"building":1,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_021","name":"종 다락 보관함","cell":[55,59],"building":1,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_022","name":"교구 학교 앞방 보관함","cell":[113,59],"building":2,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_023","name":"교구 학교 뒷방 보관함","cell":[116,70],"building":2,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_024","name":"교구 학교 앞방 보관함","cell":[123,59],"building":2,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_025","name":"교구 학교 뒷방 보관함","cell":[126,70],"building":2,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_026","name":"교구 학교 앞방 보관함","cell":[114,59],"building":2,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_027","name":"교구 학교 뒷방 보관함","cell":[117,70],"building":2,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_028","name":"교구 학교 앞방 보관함","cell":[124,59],"building":2,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_029","name":"교구 학교 뒷방 보관함","cell":[127,70],"building":2,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_030","name":"교구 학교 앞방 보관함","cell":[114,59],"building":2,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_031","name":"교구 학교 뒷방 보관함","cell":[117,70],"building":2,"search":6,"items":["cloth","symbol_bell","food_pack"],"locked":false,"level":2,"searched":false},
		{"id":"box_032","name":"교구 학교 앞방 보관함","cell":[124,59],"building":2,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_033","name":"교구 학교 뒷방 보관함","cell":[127,70],"building":2,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_034","name":"교구 회관 앞방 보관함","cell":[32,58],"building":3,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_035","name":"교구 회관 뒷방 보관함","cell":[32,66],"building":3,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_036","name":"교구 회관 앞방 보관함","cell":[35,58],"building":3,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_037","name":"교구 회관 뒷방 보관함","cell":[36,66],"building":3,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_038","name":"급식 부엌 앞방 보관함","cell":[73,85],"building":4,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_039","name":"급식 부엌 뒷방 보관함","cell":[72,92],"building":4,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_040","name":"주택 가 앞방 보관함","cell":[40,19],"building":6,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_041","name":"주택 가 뒷방 보관함","cell":[40,26],"building":6,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_042","name":"주택 가 앞방 보관함","cell":[40,19],"building":6,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_043","name":"주택 가 뒷방 보관함","cell":[40,26],"building":6,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_044","name":"주택 나 앞방 보관함","cell":[94,19],"building":7,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_045","name":"주택 나 뒷방 보관함","cell":[94,26],"building":7,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_046","name":"주택 나 앞방 보관함","cell":[94,19],"building":7,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_047","name":"주택 나 뒷방 보관함","cell":[94,26],"building":7,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_048","name":"차고 앞방 보관함","cell":[56,25],"building":8,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_049","name":"차고 뒷방 보관함","cell":[64,25],"building":8,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_050","name":"사제관 앞방 보관함","cell":[40,77],"building":9,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_051","name":"사제관 뒷방 보관함","cell":[39,84],"building":9,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_052","name":"사제관 앞방 보관함","cell":[40,77],"building":9,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_053","name":"사제관 뒷방 보관함","cell":[40,84],"building":9,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_054","name":"서쪽 주택 다 앞방 보관함","cell":[14,57],"building":10,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_055","name":"서쪽 주택 다 뒷방 보관함","cell":[13,64],"building":10,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_056","name":"서쪽 주택 다 앞방 보관함","cell":[16,57],"building":10,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_057","name":"서쪽 주택 다 뒷방 보관함","cell":[16,64],"building":10,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_058","name":"서쪽 주택 라 앞방 보관함","cell":[7,81],"building":11,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_059","name":"서쪽 주택 라 뒷방 보관함","cell":[14,81],"building":11,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_060","name":"장작 헛간 안방 보관함","cell":[102,86],"building":12,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_061","name":"학교 숙직 헛간 안방 보관함","cell":[142,72],"building":13,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_062","name":"우물집 안방 보관함","cell":[112,85],"building":14,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_063","name":"진열 매장 보관함","cell":[66,32],"building":5,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_064","name":"뒤 창고 보관함","cell":[67,40],"building":5,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_065","name":"가게 사무실 보관함","cell":[92,40],"building":5,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_066","name":"승강장 남은 상자","cell":[51,10],"building":-1,"search":3,"items":["plank","cloth"],"locked":false,"level":0,"searched":false}
	],
	"entries": [
		{"id":"west_road","cells":[[0,47],[0,48],[0,49],[0,50]],"gap":0.6},
		{"id":"east_road","cells":[[164,44],[164,45],[164,46],[164,47]],"gap":0.6},
		{"id":"south_path","cells":[[52,94],[53,94],[54,94],[55,94]],"gap":0.6},
		{"id":"northeast_lane","cells":[[164,66],[164,67],[164,68]],"gap":2}
	],
	"holes": [
		{"id":"manhole_01","cell":[36,49],"name":"서쪽 큰길 맨홀","level":0,"gap":3}
	],
	"slots": [
		[50,26],
		[52,26],
		[81,26],
		[82,26],
		[97,26],
		[99,26]
	],
	"dead": [
		[4,48],
		[160,45],
		[54,91],
		[160,67],
		[137,59],
		[46,83]
	],
	"deep": [
		"C",
		"D"
	],
	"work": {"cell":[132,78],"rect":[108,66,26,14]}
}

# 위쪽 일터의 독립 평면. 아래쪽 계획의 건물 번호 뒤에만 덧붙인다.
const NORTH: Dictionary = {
	"names": {"H":"묵은 과수원","I":"곳간 마당","J":"동쪽 건조 마당"},
	"zones": [
		{"id":"H","rect":[0,0,61,46]},
		{"id":"I","rect":[61,0,55,46]},
		{"id":"J","rect":[116,0,49,46]}
	],
	"ground": [
		{"rect":[0,0,61,24],"kind":"DEEP_SNOW"},
		{"rect":[67,0,49,24],"kind":"GRAVEL"},
		{"rect":[116,0,49,45],"kind":"DEEP_SNOW"},
		{"rect":[61,0,6,43],"kind":"ROAD"},
		{"rect":[0,8,33,4],"kind":"ROAD"},
		{"rect":[28,8,5,35],"kind":"ROAD"},
		{"rect":[67,10,98,4],"kind":"ROAD"},
		{"rect":[112,14,4,31],"kind":"ROAD"},
		{"rect":[134,22,5,23],"kind":"GRAVEL"},
		{"rect":[10,20,6,4],"kind":"GRAVEL"},
		{"rect":[10,24,6,21],"kind":"ROAD"},
		{"rect":[96,34,6,11],"kind":"ROAD"}
	],
	"buildings": [
		{"id":15,"name":"사과 저장 곳간","rect":[67,10,26,14],"warm":false,"window_broken":false},
		{"id":16,"name":"과수지기 집","rect":[16,14,12,10],"warm":false,"window_broken":false},
		{"id":17,"name":"짐수레 헛간","rect":[33,14,14,10],"warm":false,"window_broken":false},
		{"id":18,"name":"곳간 별채","rect":[47,14,14,10],"warm":false,"window_broken":false},
		{"id":19,"name":"벌통 헛간","rect":[30,2,12,6],"warm":false,"window_broken":false},
		{"id":20,"name":"굴 입구 집","rect":[6,2,19,12],"warm":false,"window_broken":false},
		{"id":21,"name":"건조 헛간","rect":[100,2,16,8],"warm":false,"window_broken":false},
		{"id":22,"name":"농가","rect":[116,27,18,12],"warm":false,"window_broken":false},
		{"id":23,"name":"우물집","rect":[142,30,6,6],"warm":false,"window_broken":false}
	],
	"shells": [
		{"building":15,"level":-1,"rect":[67,10,26,14]},
		{"building":15,"level":0,"rect":[67,14,26,10]},
		{"building":15,"level":1,"rect":[67,14,26,10]},
		{"building":16,"level":0,"rect":[16,14,12,10]},
		{"building":16,"level":1,"rect":[16,14,12,10]},
		{"building":17,"level":0,"rect":[33,14,14,10]},
		{"building":18,"level":0,"rect":[47,14,14,10]},
		{"building":18,"level":1,"rect":[47,14,14,10]},
		{"building":19,"level":0,"rect":[30,2,12,6]},
		{"building":20,"level":-1,"rect":[6,2,19,12]},
		{"building":20,"level":0,"rect":[6,2,8,6]},
		{"building":21,"level":0,"rect":[100,2,16,8]},
		{"building":22,"level":0,"rect":[116,27,18,12]},
		{"building":22,"level":1,"rect":[116,27,18,12]},
		{"building":23,"level":0,"rect":[142,30,6,6]}
	],
	"walls": [
		{"level":-1,"rect":[70,13,20,1]},
		{"level":-1,"rect":[70,20,20,1]},
		{"level":-1,"rect":[70,13,1,8]},
		{"level":-1,"rect":[89,13,1,8]},
		{"level":-1,"rect":[80,14,1,6]},
		{"level":0,"rect":[68,20,24,1]},
		{"level":0,"rect":[71,15,1,5]},
		{"level":0,"rect":[75,15,1,5]},
		{"level":0,"rect":[79,15,1,5]},
		{"level":0,"rect":[83,15,1,5]},
		{"level":0,"rect":[87,15,1,5]},
		{"level":1,"rect":[80,15,1,8]},
		{"level":0,"rect":[22,15,1,8]},
		{"level":1,"rect":[22,15,1,8]},
		{"level":0,"rect":[40,15,1,8]},
		{"level":0,"rect":[54,15,1,8]},
		{"level":1,"rect":[54,15,1,8]},
		{"level":-1,"rect":[7,5,17,1]},
		{"level":-1,"rect":[15,6,1,7]},
		{"level":0,"rect":[108,3,1,6]},
		{"level":0,"rect":[125,28,1,10]},
		{"level":1,"rect":[125,28,1,10]}
	],
	"doors": [
		{"building":15,"level":-1,"cell":[70,15],"side":[-1,0],"state":"open","outer":false},
		{"building":15,"level":-1,"cell":[80,16],"side":[1,0],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[69,20],"side":[0,1],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[73,20],"side":[0,1],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[77,20],"side":[0,1],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[81,20],"side":[0,1],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[85,20],"side":[0,1],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[90,20],"side":[0,1],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[80,23],"side":[0,1],"state":"open","outer":true},
		{"building":15,"level":1,"cell":[80,19],"side":[1,0],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[22,19],"side":[1,0],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[19,14],"side":[0,-1],"state":"open","outer":true},
		{"building":16,"level":1,"cell":[22,19],"side":[1,0],"state":"open","outer":false},
		{"building":17,"level":0,"cell":[40,19],"side":[1,0],"state":"open","outer":false},
		{"building":17,"level":0,"cell":[37,14],"side":[0,-1],"state":"open","outer":true},
		{"building":18,"level":0,"cell":[54,19],"side":[1,0],"state":"open","outer":false},
		{"building":18,"level":0,"cell":[51,14],"side":[0,-1],"state":"open","outer":true},
		{"building":18,"level":1,"cell":[54,19],"side":[1,0],"state":"open","outer":false},
		{"building":19,"level":0,"cell":[36,7],"side":[0,1],"state":"open","outer":true},
		{"building":20,"level":-1,"cell":[11,5],"side":[0,-1],"state":"open","outer":false},
		{"building":20,"level":-1,"cell":[20,5],"side":[0,-1],"state":"open","outer":false},
		{"building":20,"level":0,"cell":[10,7],"side":[0,1],"state":"open","outer":true},
		{"building":21,"level":0,"cell":[108,6],"side":[1,0],"state":"open","outer":false},
		{"building":21,"level":0,"cell":[104,9],"side":[0,1],"state":"open","outer":true},
		{"building":22,"level":0,"cell":[125,33],"side":[1,0],"state":"open","outer":false},
		{"building":22,"level":0,"cell":[133,33],"side":[1,0],"state":"open","outer":true},
		{"building":22,"level":1,"cell":[125,33],"side":[1,0],"state":"open","outer":false},
		{"building":23,"level":0,"cell":[145,35],"side":[0,1],"state":"open","outer":true}
	],
	"windows": [
		{"building":15,"level":-1,"cell":[75,10],"broken":false},
		{"building":15,"level":-1,"cell":[85,10],"broken":false},
		{"building":15,"level":0,"cell":[69,14],"broken":false},
		{"building":15,"level":0,"cell":[73,14],"broken":false},
		{"building":15,"level":0,"cell":[77,14],"broken":false},
		{"building":15,"level":0,"cell":[81,14],"broken":false},
		{"building":15,"level":0,"cell":[85,14],"broken":false},
		{"building":15,"level":0,"cell":[90,14],"broken":false},
		{"building":15,"level":1,"cell":[74,14],"broken":false},
		{"building":15,"level":1,"cell":[86,14],"broken":false},
		{"building":16,"level":0,"cell":[25,14],"broken":false},
		{"building":16,"level":1,"cell":[19,14],"broken":false},
		{"building":16,"level":1,"cell":[25,14],"broken":false},
		{"building":17,"level":0,"cell":[43,14],"broken":false},
		{"building":18,"level":0,"cell":[57,14],"broken":false},
		{"building":18,"level":1,"cell":[51,14],"broken":false},
		{"building":18,"level":1,"cell":[57,14],"broken":false},
		{"building":19,"level":0,"cell":[36,2],"broken":false},
		{"building":20,"level":-1,"cell":[11,2],"broken":false},
		{"building":20,"level":-1,"cell":[20,2],"broken":false},
		{"building":20,"level":0,"cell":[10,2],"broken":false},
		{"building":21,"level":0,"cell":[104,2],"broken":false},
		{"building":21,"level":0,"cell":[112,2],"broken":false},
		{"building":22,"level":0,"cell":[121,27],"broken":false},
		{"building":22,"level":0,"cell":[129,27],"broken":false},
		{"building":22,"level":1,"cell":[121,27],"broken":false},
		{"building":22,"level":1,"cell":[129,27],"broken":false},
		{"building":23,"level":0,"cell":[145,30],"broken":false}
	],
	"stairs": [
		{"cell":[68,15],"low":-1,"high":0,"ladder":false},
		{"cell":[91,22],"low":-1,"high":0,"ladder":false},
		{"cell":[68,15],"low":0,"high":1,"ladder":false},
		{"cell":[17,15],"low":0,"high":1,"ladder":false},
		{"cell":[48,15],"low":0,"high":1,"ladder":false},
		{"cell":[7,3],"low":-1,"high":0,"ladder":false},
		{"cell":[117,28],"low":0,"high":1,"ladder":false}
	],
	"props": [
		{"kind":"bench","rect":[33,38,3,1],"solid":"low","facing":0,"note":"쉬어 가던 긴 의자","level":0},
		{"kind":"sack_pile","rect":[67,41,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"hedge","rect":[84,27,1,6],"solid":"low","facing":0,"note":"눈 덮인 생울타리 토막","level":0},
		{"kind":"handcart","rect":[108,34,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"hive_box","rect":[20,3,1,1],"solid":"low","facing":0,"note":"짚으로 감싼 낮은 벌통","level":0},
		{"kind":"hive_box","rect":[23,5,1,1],"solid":"low","facing":0,"note":"짚으로 감싼 낮은 벌통","level":0},
		{"kind":"hive_box","rect":[26,2,1,1],"solid":"low","facing":0,"note":"짚으로 감싼 낮은 벌통","level":0},
		{"kind":"hive_box","rect":[27,6,1,1],"solid":"low","facing":0,"note":"짚으로 감싼 낮은 벌통","level":0},
		{"kind":"shelf","rect":[19,6,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"bench","rect":[23,0,3,1],"solid":"low","facing":0,"note":"쉬어 가던 긴 의자","level":0},
		{"kind":"hedge","rect":[0,23,6,1],"solid":"low","facing":0,"note":"눈 덮인 생울타리 토막","level":0},
		{"kind":"hedge","rect":[36,0,6,1],"solid":"low","facing":0,"note":"눈 덮인 생울타리 토막","level":0},
		{"kind":"crate_stack","rect":[121,18,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"crate_stack","rect":[126,21,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"crate_stack","rect":[131,18,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"barrel","rect":[134,21,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"handcart","rect":[138,18,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"sack_pile","rect":[140,21,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"farm_cart","rect":[6,22,4,2],"solid":"low","facing":0,"note":"운반하다 세워 둔 짐수레","level":0},
		{"kind":"fieldstone_wall","rect":[116,24,1,3],"solid":"low","facing":0,"note":"글씨 없는 들돌 담 토막","level":0},
		{"kind":"bare_tree","rect":[2,14,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[7,17,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[13,15,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[4,21,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[9,19,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[44,2,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[49,5,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[54,1,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[58,7,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[46,9,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[70,1,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[76,4,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[83,0,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[91,3,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[86,7,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[96,6,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[151,26,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[159,29,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[154,37,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[162,44,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"crate_stack","rect":[72,14,2,2],"solid":"none","facing":0,"note":"종류별 물자를 담은 나무 상자","level":-1},
		{"kind":"barrel","rect":[71,19,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":-1},
		{"kind":"shelf","rect":[72,19,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":-1},
		{"kind":"crate_stack","rect":[87,14,2,2],"solid":"none","facing":0,"note":"종류별 물자를 담은 나무 상자","level":-1},
		{"kind":"barrel","rect":[81,19,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":-1},
		{"kind":"shelf","rect":[82,19,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":-1},
		{"kind":"barrel","rect":[70,15,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"shelf","rect":[70,16,1,2],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"shelf","rect":[72,15,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"barrel","rect":[78,15,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"shelf","rect":[76,15,1,2],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"desk","rect":[80,15,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"shelf","rect":[82,15,1,2],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"barrel","rect":[86,19,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"crate_stack","rect":[85,15,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"shelf","rect":[84,18,1,2],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"barrel","rect":[91,15,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"crate_stack","rect":[88,15,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"shelf","rect":[91,16,1,2],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"shelf","rect":[68,22,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"barrel","rect":[79,22,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":1},
		{"kind":"crate_stack","rect":[69,15,2,2],"solid":"none","facing":0,"note":"종류별 물자를 담은 나무 상자","level":1},
		{"kind":"shelf","rect":[81,22,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"barrel","rect":[91,15,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":1},
		{"kind":"crate_stack","rect":[82,15,2,2],"solid":"none","facing":0,"note":"종류별 물자를 담은 나무 상자","level":1},
		{"kind":"cold_stove","rect":[17,22,1,1],"solid":"low","facing":0,"note":"작게 식은 난로","level":0},
		{"kind":"shelf","rect":[18,22,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"barrel","rect":[21,22,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"sack_pile","rect":[23,15,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[24,22,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"bed","rect":[17,22,2,1],"solid":"none","facing":0,"note":"숙직하는 이의 침대","level":1},
		{"kind":"desk","rect":[20,22,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":1},
		{"kind":"bed","rect":[23,22,2,1],"solid":"none","facing":0,"note":"숙직하는 이의 침대","level":1},
		{"kind":"shelf","rect":[23,15,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"shelf","rect":[34,15,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[34,21,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[38,15,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"shelf","rect":[41,22,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[44,15,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[41,21,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"barrel","rect":[53,22,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"crate_stack","rect":[48,21,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"shelf","rect":[48,16,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"barrel","rect":[59,22,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"crate_stack","rect":[55,15,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"shelf","rect":[56,22,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"shelf","rect":[48,22,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"barrel","rect":[53,22,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":1},
		{"kind":"crate_stack","rect":[48,16,2,2],"solid":"none","facing":0,"note":"종류별 물자를 담은 나무 상자","level":1},
		{"kind":"shelf","rect":[55,15,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"barrel","rect":[59,22,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":1},
		{"kind":"crate_stack","rect":[55,16,2,2],"solid":"none","facing":0,"note":"종류별 물자를 담은 나무 상자","level":1},
		{"kind":"hive_box","rect":[40,3,1,1],"solid":"low","facing":0,"note":"짚으로 감싼 낮은 벌통","level":0},
		{"kind":"shelf","rect":[31,3,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"barrel","rect":[40,6,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"crate_stack","rect":[7,6,2,2],"solid":"none","facing":0,"note":"종류별 물자를 담은 나무 상자","level":-1},
		{"kind":"barrel","rect":[7,12,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":-1},
		{"kind":"shelf","rect":[8,12,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":-1},
		{"kind":"crate_stack","rect":[16,6,2,2],"solid":"none","facing":0,"note":"종류별 물자를 담은 나무 상자","level":-1},
		{"kind":"barrel","rect":[23,12,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":-1},
		{"kind":"shelf","rect":[16,11,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":-1},
		{"kind":"barrel","rect":[12,3,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"crate_stack","rect":[7,4,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"shelf","rect":[12,5,1,2],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"shelf","rect":[101,3,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[101,7,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"shelf","rect":[109,3,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[109,4,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"cold_stove","rect":[117,37,1,1],"solid":"low","facing":0,"note":"작게 식은 난로","level":0},
		{"kind":"shelf","rect":[118,28,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"barrel","rect":[124,37,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"sack_pile","rect":[126,28,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[126,37,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"bed","rect":[117,37,2,1],"solid":"none","facing":0,"note":"숙직하는 이의 침대","level":1},
		{"kind":"desk","rect":[117,36,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":1},
		{"kind":"bed","rect":[126,37,2,1],"solid":"none","facing":0,"note":"숙직하는 이의 침대","level":1},
		{"kind":"shelf","rect":[127,28,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"shelf","rect":[143,31,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[143,32,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[143,34,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0}
	],
	"rooms": [
		{"building":15,"level":-1,"rect":[71,14,9,6],"name":"사과 저장 곳간 지하 통 저장방","theme":"fruit"},
		{"building":15,"level":-1,"rect":[81,14,8,6],"name":"사과 저장 곳간 지하 막다른 저장방","theme":"fruit"},
		{"building":15,"level":0,"rect":[68,15,3,5],"name":"사과 저장 곳간 선별방","theme":"fruit"},
		{"building":15,"level":0,"rect":[72,15,3,5],"name":"사과 저장 곳간 건조방","theme":"fruit"},
		{"building":15,"level":0,"rect":[76,15,3,5],"name":"사과 저장 곳간 포장방","theme":"fruit"},
		{"building":15,"level":0,"rect":[80,15,3,5],"name":"사과 저장 곳간 사무방","theme":"fruit"},
		{"building":15,"level":0,"rect":[84,15,3,5],"name":"사과 저장 곳간 작업방","theme":"fruit"},
		{"building":15,"level":0,"rect":[88,15,4,5],"name":"사과 저장 곳간 안쪽 저장방","theme":"fruit"},
		{"building":15,"level":1,"rect":[68,15,12,8],"name":"사과 저장 곳간 위층 항아리 보관방","theme":"fruit"},
		{"building":15,"level":1,"rect":[81,15,11,8],"name":"사과 저장 곳간 위층 도구방","theme":"fruit"},
		{"building":16,"level":0,"rect":[17,15,5,8],"name":"과수지기 집 앞방","theme":"house"},
		{"building":16,"level":0,"rect":[23,15,4,8],"name":"과수지기 집 뒷방","theme":"house"},
		{"building":16,"level":1,"rect":[17,15,5,8],"name":"과수지기 집 위층 앞방","theme":"house"},
		{"building":16,"level":1,"rect":[23,15,4,8],"name":"과수지기 집 위층 뒷방","theme":"house"},
		{"building":17,"level":0,"rect":[34,15,6,8],"name":"짐수레 헛간 앞방","theme":"tools"},
		{"building":17,"level":0,"rect":[41,15,5,8],"name":"짐수레 헛간 뒷방","theme":"tools"},
		{"building":18,"level":0,"rect":[48,15,6,8],"name":"곳간 별채 앞방","theme":"fruit"},
		{"building":18,"level":0,"rect":[55,15,5,8],"name":"곳간 별채 뒷방","theme":"fruit"},
		{"building":18,"level":1,"rect":[48,15,6,8],"name":"곳간 별채 위층 항아리 보관방","theme":"fruit"},
		{"building":18,"level":1,"rect":[55,15,5,8],"name":"곳간 별채 위층 도구방","theme":"fruit"},
		{"building":19,"level":0,"rect":[31,3,10,4],"name":"벌통 헛간 작업방","theme":"hive"},
		{"building":20,"level":-1,"rect":[7,6,8,7],"name":"굴 입구 집 지하 통로 옆 저장방","theme":"fruit"},
		{"building":20,"level":-1,"rect":[16,6,8,7],"name":"굴 입구 집 지하 막다른 저장방","theme":"fruit"},
		{"building":20,"level":0,"rect":[7,3,6,4],"name":"굴 입구 집 작업방","theme":"fruit"},
		{"building":21,"level":0,"rect":[101,3,7,6],"name":"건조 헛간 앞방","theme":"fruit"},
		{"building":21,"level":0,"rect":[109,3,6,6],"name":"건조 헛간 뒷방","theme":"fruit"},
		{"building":22,"level":0,"rect":[117,28,8,10],"name":"농가 앞방","theme":"house"},
		{"building":22,"level":0,"rect":[126,28,7,10],"name":"농가 뒷방","theme":"house"},
		{"building":22,"level":1,"rect":[117,28,8,10],"name":"농가 위층 앞방","theme":"house"},
		{"building":22,"level":1,"rect":[126,28,7,10],"name":"농가 위층 뒷방","theme":"house"},
		{"building":23,"level":0,"rect":[143,31,4,4],"name":"우물집 작업방","theme":"tools"}
	],
	"containers": [
		{"id":"north_box_006","name":"사과 저장 곳간 사무방 보관함","cell":[82,19],"building":15,"search":6,"items":["food_pack","food_pack","food_pack"],"locked":false,"level":0,"searched":false},
		{"id":"north_box_015","name":"짐수레 헛간 앞방 보관함","cell":[39,22],"building":17,"search":6,"items":["food_pack","food_pack","food_pack"],"locked":false,"level":0,"searched":false},
		{"id":"north_box_021","name":"벌통 헛간 작업방 보관함","cell":[31,6],"building":19,"search":6,"items":["food_pack","food_pack","food_pack"],"locked":false,"level":0,"searched":false},
		{"id":"north_box_022","name":"굴 입구 집 지하 통로 옆 저장방 보관함","cell":[14,6],"building":20,"search":4,"items":[],"locked":false,"level":-1,"searched":false},
		{"id":"north_box_023","name":"굴 입구 집 막다른 물자 보관함","cell":[16,12],"building":20,"search":8,"items":["food_pack","food_pack"],"locked":false,"level":-1,"searched":false},
		{"id":"north_box_024","name":"굴 입구 집 작업방 보관함","cell":[7,6],"building":20,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"north_shallow","name":"운반 도중 내려둔 물자 보관함","cell":[61,39],"building":-1,"search":2,"items":["food_pack"],"locked":false,"level":0,"searched":false}
	],
	"entries": [
		{"id":"서쪽 과수원 길","cells":[[0,8],[0,9],[0,10],[0,11]],"gap":0.6},
		{"id":"북쪽 수확 길","cells":[[62,0],[63,0],[64,0],[65,0]],"gap":0.6},
		{"id":"동쪽 건조장 길","cells":[[164,10],[164,11],[164,12]],"gap":0.6}
	],
	"holes": [

	],
	"slots": [
		[29,24],
		[31,25],
		[62,24],
		[65,25],
		[11,24],
		[14,25],
		[34,44],
		[34,50],
		[50,44],
		[50,50],
		[66,44],
		[66,50]
	],
	"crossings": [
		48,
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
const ENTRY_NAMES: Dictionary = {"west_road": "서쪽 길", "east_road": "동쪽 길", "south_path": "남쪽 오솔길", "northeast_lane": "북동쪽 샛길", "manhole_01": "맨홀", "서쪽 과수원 길": "서쪽 과수원 길", "북쪽 수확 길": "북쪽 수확 길", "동쪽 건조장 길": "동쪽 건조장 길"}
const ENTRY_WEIGHTS: Dictionary = {"west_road": 1.0, "east_road": 1.0, "south_path": 1.0, "northeast_lane": 0.5, "manhole_01": 0.3, "서쪽 과수원 길": 1.0, "북쪽 수확 길": 1.0, "동쪽 건조장 길": 1.0}
const FIRST_ENTRY: String = "west_road"


static func build() -> Dictionary:
	var data: Dictionary = _build_plain()
	data["entry_names"] = ENTRY_NAMES.duplicate()
	data["entry_weights"] = ENTRY_WEIGHTS.duplicate()
	data["first_entry"] = FIRST_ENTRY
	return data
