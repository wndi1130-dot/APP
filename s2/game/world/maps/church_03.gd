# 이 지도가 다른 판단을 만드는 것: 회랑은 고리라 돌 수 있으나 문이 모두 안뜰로 열린다. 지하에 식량이 있다.
# 위쪽의 판단: 모직 천과 털실(가볍고 부피가 있다)을 얻는 대신, 사방이 트인 풀밭을 오래 걷고 아래쪽 수도원의 식량 구역을 비워 둔다.
extends RefCounted

const FieldGrid = preload("res://game/world/field_grid.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const PLACE_ID: String = "church_03"
const WIDTH: int = 170
const SOUTH_HEIGHT: int = 100
const HEIGHT: int = SOUTH_HEIGHT + 45

# 각 방과 마당의 좌표는 이 지도에서만 쓰는 독립 평면이다.
# 종소리와 덧댄 문 해체는 자리만 남기며 여기서 실행하지 않는다.
const PLAN: Dictionary = {
	"id": "church_03",
	"size": [
		170,
		100
	],
	"names": {"A":"열차 곁 띠","B":"큰길","C":"교회","D":"회랑과 안뜰","E":"서채 지하 저장고","F":"약초밭"},
	"zones": [
		{"id":"A","rect":[0,0,170,100]},
		{"id":"B","rect":[0,30,170,12]},
		{"id":"C","rect":[38,38,69,24]},
		{"id":"D","rect":[62,62,48,38]},
		{"id":"E","rect":[0,42,62,58]},
		{"id":"F","rect":[110,42,60,58]}
	],
	"ground": [
		{"rect":[0,10,20,88],"kind":"DEEP_SNOW"},
		{"rect":[122,10,48,20],"kind":"DEEP_SNOW"},
		{"rect":[36,38,131,60],"kind":"GRAVEL"},
		{"rect":[0,30,106,6],"kind":"ROAD"},
		{"rect":[100,30,6,12],"kind":"ROAD"},
		{"rect":[100,36,70,6],"kind":"ROAD"},
		{"rect":[38,10,5,26],"kind":"ROAD"},
		{"rect":[30,35,5,65],"kind":"ROAD"},
		{"rect":[120,88,4,12],"kind":"ROAD"},
		{"rect":[124,38,6,24],"kind":"ROAD"},
		{"rect":[130,56,36,5],"kind":"ROAD"},
		{"rect":[35,88,27,5],"kind":"ROAD"},
		{"rect":[106,61,4,29],"kind":"ROAD"},
		{"rect":[66,62,40,28],"kind":"WOOD"},
		{"rect":[70,66,32,20],"kind":"SNOW"},
		{"rect":[132,75,34,20],"kind":"DEEP_SNOW"}
	],
	"buildings": [
		{"id":0,"name":"교회 본당","rect":[54,38,50,24],"warm":true,"window_broken":false},
		{"id":1,"name":"종탑","rect":[40,40,12,12],"warm":false,"window_broken":false},
		{"id":2,"name":"서채 저장고","rect":[40,62,22,30],"warm":false,"window_broken":false},
		{"id":3,"name":"동채 식당","rect":[110,57,22,14],"warm":false,"window_broken":false},
		{"id":4,"name":"동채 부엌","rect":[110,73,22,14],"warm":false,"window_broken":false},
		{"id":5,"name":"남채 도서실","rect":[63,90,20,10],"warm":false,"window_broken":false},
		{"id":6,"name":"수도자 방 가","rect":[85,90,14,10],"warm":false,"window_broken":false},
		{"id":7,"name":"수도자 방 나","rect":[133,84,14,10],"warm":false,"window_broken":false},
		{"id":8,"name":"문간 빵 가게","rect":[139,43,14,10],"warm":false,"window_broken":false},
		{"id":9,"name":"손님채","rect":[107,42,16,12],"warm":false,"window_broken":false},
		{"id":10,"name":"약초 창고","rect":[153,82,12,12],"warm":false,"window_broken":false},
		{"id":11,"name":"장작 창고","rect":[136,65,12,8],"warm":false,"window_broken":false},
		{"id":12,"name":"마구간","rect":[48,18,16,10],"warm":false,"window_broken":false},
		{"id":13,"name":"관리인 집","rect":[80,18,12,10],"warm":false,"window_broken":false},
		{"id":14,"name":"농가 가","rect":[22,17,14,12],"warm":false,"window_broken":false},
		{"id":15,"name":"농가 나","rect":[100,17,14,12],"warm":false,"window_broken":false}
	],
	"shells": [
		{"building":0,"level":0,"rect":[54,38,50,24]},
		{"building":0,"level":1,"rect":[54,38,8,24]},
		{"building":0,"level":-1,"rect":[80,38,24,24]},
		{"building":1,"level":0,"rect":[40,40,12,12]},
		{"building":1,"level":1,"rect":[40,40,12,12]},
		{"building":1,"level":2,"rect":[40,40,12,12]},
		{"building":2,"level":0,"rect":[40,62,22,30]},
		{"building":2,"level":1,"rect":[40,62,22,30]},
		{"building":2,"level":-1,"rect":[40,62,22,30]},
		{"building":3,"level":0,"rect":[110,57,22,14]},
		{"building":3,"level":1,"rect":[110,57,22,14]},
		{"building":4,"level":0,"rect":[110,73,22,14]},
		{"building":4,"level":1,"rect":[110,73,22,14]},
		{"building":5,"level":0,"rect":[63,90,20,10]},
		{"building":5,"level":1,"rect":[63,90,20,10]},
		{"building":6,"level":0,"rect":[85,90,14,10]},
		{"building":6,"level":1,"rect":[85,90,14,10]},
		{"building":7,"level":0,"rect":[133,84,14,10]},
		{"building":7,"level":1,"rect":[133,84,14,10]},
		{"building":8,"level":0,"rect":[139,43,14,10]},
		{"building":8,"level":1,"rect":[139,43,14,10]},
		{"building":9,"level":0,"rect":[107,42,16,12]},
		{"building":9,"level":1,"rect":[107,42,16,12]},
		{"building":10,"level":0,"rect":[153,82,12,12]},
		{"building":11,"level":0,"rect":[136,65,12,8]},
		{"building":12,"level":0,"rect":[48,18,16,10]},
		{"building":13,"level":0,"rect":[80,18,12,10]},
		{"building":13,"level":1,"rect":[80,18,12,10]},
		{"building":14,"level":0,"rect":[22,17,14,12]},
		{"building":14,"level":1,"rect":[22,17,14,12]},
		{"building":15,"level":0,"rect":[100,17,14,12]}
	],
	"walls": [
		{"level":0,"rect":[55,44,48,1]},
		{"level":0,"rect":[55,55,48,1]},
		{"level":0,"rect":[63,39,1,5]},
		{"level":0,"rect":[63,56,1,5]},
		{"level":0,"rect":[73,39,1,5]},
		{"level":0,"rect":[73,56,1,5]},
		{"level":0,"rect":[83,39,1,5]},
		{"level":0,"rect":[83,56,1,5]},
		{"level":0,"rect":[93,39,1,5]},
		{"level":0,"rect":[93,56,1,5]},
		{"level":1,"rect":[55,50,6,1]},
		{"level":-1,"rect":[83,41,18,1]},
		{"level":-1,"rect":[83,58,18,1]},
		{"level":-1,"rect":[83,41,1,18]},
		{"level":-1,"rect":[100,41,1,18]},
		{"level":-1,"rect":[92,42,1,16]},
		{"level":0,"rect":[45,41,1,10]},
		{"level":1,"rect":[45,41,1,10]},
		{"level":2,"rect":[45,41,1,10]},
		{"level":0,"rect":[41,75,20,1]},
		{"level":0,"rect":[41,78,20,1]},
		{"level":0,"rect":[50,63,1,12]},
		{"level":0,"rect":[50,79,1,12]},
		{"level":1,"rect":[41,75,20,1]},
		{"level":1,"rect":[41,78,20,1]},
		{"level":1,"rect":[50,63,1,12]},
		{"level":1,"rect":[50,79,1,12]},
		{"level":-1,"rect":[43,65,16,1]},
		{"level":-1,"rect":[43,88,16,1]},
		{"level":-1,"rect":[43,65,1,24]},
		{"level":-1,"rect":[58,65,1,24]},
		{"level":-1,"rect":[51,66,1,22]},
		{"level":0,"rect":[111,62,20,1]},
		{"level":0,"rect":[111,65,20,1]},
		{"level":1,"rect":[111,62,20,1]},
		{"level":1,"rect":[111,65,20,1]},
		{"level":0,"rect":[111,78,20,1]},
		{"level":0,"rect":[111,81,20,1]},
		{"level":1,"rect":[111,78,20,1]},
		{"level":1,"rect":[111,81,20,1]},
		{"level":0,"rect":[73,91,1,8]},
		{"level":1,"rect":[73,91,1,8]},
		{"level":0,"rect":[92,91,1,8]},
		{"level":1,"rect":[92,91,1,8]},
		{"level":0,"rect":[140,85,1,8]},
		{"level":1,"rect":[140,85,1,8]},
		{"level":0,"rect":[146,44,1,8]},
		{"level":1,"rect":[146,44,1,8]},
		{"level":0,"rect":[108,46,14,1]},
		{"level":0,"rect":[108,49,14,1]},
		{"level":1,"rect":[108,46,14,1]},
		{"level":1,"rect":[108,49,14,1]},
		{"level":0,"rect":[154,86,10,1]},
		{"level":0,"rect":[154,89,10,1]},
		{"level":0,"rect":[56,19,1,8]},
		{"level":0,"rect":[86,19,1,8]},
		{"level":1,"rect":[86,19,1,8]},
		{"level":0,"rect":[23,21,12,1]},
		{"level":0,"rect":[23,24,12,1]},
		{"level":1,"rect":[23,21,12,1]},
		{"level":1,"rect":[23,24,12,1]},
		{"level":0,"rect":[101,21,12,1]},
		{"level":0,"rect":[101,24,12,1]},
		{"level":0,"rect":[36,38,1,48]},
		{"level":0,"rect":[36,37,90,1]},
		{"level":0,"rect":[132,37,34,1]},
		{"level":0,"rect":[166,43,1,51]},
		{"level":0,"rect":[105,94,45,1]}
	],
	"doors": [
		{"building":0,"level":0,"cell":[59,44],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[59,55],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[68,44],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[68,55],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[78,44],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[78,55],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[88,44],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[88,55],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[98,44],"side":[0,1],"state":"closed","outer":false},
		{"building":0,"level":0,"cell":[98,55],"side":[0,-1],"state":"open","outer":false},
		{"building":0,"level":0,"cell":[54,50],"side":[-1,0],"state":"open","outer":true},
		{"building":0,"level":0,"cell":[103,50],"side":[1,0],"state":"open","outer":true},
		{"building":0,"level":1,"cell":[57,50],"side":[0,1],"state":"open","outer":false},
		{"building":0,"level":-1,"cell":[83,50],"side":[-1,0],"state":"open","outer":false},
		{"building":0,"level":-1,"cell":[100,50],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":0,"cell":[45,49],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":1,"cell":[45,49],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":2,"cell":[45,49],"side":[1,0],"state":"open","outer":false},
		{"building":1,"level":0,"cell":[50,51],"side":[0,1],"state":"open","outer":true},
		{"building":2,"level":0,"cell":[45,75],"side":[0,1],"state":"open","outer":false},
		{"building":2,"level":0,"cell":[45,78],"side":[0,-1],"state":"open","outer":false},
		{"building":2,"level":0,"cell":[56,75],"side":[0,1],"state":"open","outer":false},
		{"building":2,"level":0,"cell":[56,78],"side":[0,-1],"state":"open","outer":false},
		{"building":2,"level":0,"cell":[40,76],"side":[-1,0],"state":"open","outer":true},
		{"building":2,"level":0,"cell":[61,76],"side":[1,0],"state":"open","outer":true},
		{"building":2,"level":1,"cell":[45,75],"side":[0,1],"state":"open","outer":false},
		{"building":2,"level":1,"cell":[45,78],"side":[0,-1],"state":"open","outer":false},
		{"building":2,"level":1,"cell":[56,75],"side":[0,1],"state":"open","outer":false},
		{"building":2,"level":1,"cell":[56,78],"side":[0,-1],"state":"open","outer":false},
		{"building":2,"level":-1,"cell":[43,77],"side":[-1,0],"state":"open","outer":false},
		{"building":2,"level":-1,"cell":[58,77],"side":[1,0],"state":"open","outer":false},
		{"building":3,"level":0,"cell":[121,62],"side":[0,1],"state":"open","outer":false},
		{"building":3,"level":0,"cell":[121,65],"side":[0,-1],"state":"open","outer":false},
		{"building":3,"level":0,"cell":[110,63],"side":[-1,0],"state":"open","outer":true},
		{"building":3,"level":1,"cell":[121,62],"side":[0,1],"state":"open","outer":false},
		{"building":3,"level":1,"cell":[121,65],"side":[0,-1],"state":"open","outer":false},
		{"building":4,"level":0,"cell":[121,78],"side":[0,1],"state":"open","outer":false},
		{"building":4,"level":0,"cell":[121,81],"side":[0,-1],"state":"open","outer":false},
		{"building":4,"level":0,"cell":[110,79],"side":[-1,0],"state":"open","outer":true},
		{"building":4,"level":1,"cell":[121,78],"side":[0,1],"state":"open","outer":false},
		{"building":4,"level":1,"cell":[121,81],"side":[0,-1],"state":"open","outer":false},
		{"building":5,"level":0,"cell":[73,95],"side":[1,0],"state":"open","outer":false},
		{"building":5,"level":0,"cell":[63,95],"side":[-1,0],"state":"open","outer":true},
		{"building":5,"level":0,"cell":[82,95],"side":[1,0],"state":"open","outer":true},
		{"building":5,"level":1,"cell":[73,95],"side":[1,0],"state":"open","outer":false},
		{"building":6,"level":0,"cell":[92,95],"side":[1,0],"state":"open","outer":false},
		{"building":6,"level":0,"cell":[85,95],"side":[-1,0],"state":"open","outer":true},
		{"building":6,"level":0,"cell":[98,95],"side":[1,0],"state":"open","outer":true},
		{"building":6,"level":1,"cell":[92,95],"side":[1,0],"state":"open","outer":false},
		{"building":7,"level":0,"cell":[140,89],"side":[1,0],"state":"open","outer":false},
		{"building":7,"level":0,"cell":[133,89],"side":[-1,0],"state":"open","outer":true},
		{"building":7,"level":0,"cell":[146,89],"side":[1,0],"state":"open","outer":true},
		{"building":7,"level":1,"cell":[140,89],"side":[1,0],"state":"open","outer":false},
		{"building":8,"level":0,"cell":[146,48],"side":[1,0],"state":"open","outer":false},
		{"building":8,"level":0,"cell":[139,48],"side":[-1,0],"state":"open","outer":true},
		{"building":8,"level":0,"cell":[152,48],"side":[1,0],"state":"open","outer":true},
		{"building":8,"level":1,"cell":[146,48],"side":[1,0],"state":"open","outer":false},
		{"building":9,"level":0,"cell":[115,46],"side":[0,1],"state":"open","outer":false},
		{"building":9,"level":0,"cell":[115,49],"side":[0,-1],"state":"open","outer":false},
		{"building":9,"level":0,"cell":[107,47],"side":[-1,0],"state":"open","outer":true},
		{"building":9,"level":0,"cell":[122,47],"side":[1,0],"state":"open","outer":true},
		{"building":9,"level":1,"cell":[115,46],"side":[0,1],"state":"open","outer":false},
		{"building":9,"level":1,"cell":[115,49],"side":[0,-1],"state":"open","outer":false},
		{"building":10,"level":0,"cell":[159,86],"side":[0,1],"state":"open","outer":false},
		{"building":10,"level":0,"cell":[159,89],"side":[0,-1],"state":"open","outer":false},
		{"building":10,"level":0,"cell":[153,87],"side":[-1,0],"state":"open","outer":true},
		{"building":10,"level":0,"cell":[164,87],"side":[1,0],"state":"open","outer":true},
		{"building":11,"level":0,"cell":[136,69],"side":[-1,0],"state":"open","outer":true},
		{"building":11,"level":0,"cell":[147,69],"side":[1,0],"state":"open","outer":true},
		{"building":12,"level":0,"cell":[56,23],"side":[1,0],"state":"open","outer":false},
		{"building":12,"level":0,"cell":[48,23],"side":[-1,0],"state":"open","outer":true},
		{"building":12,"level":0,"cell":[63,23],"side":[1,0],"state":"open","outer":true},
		{"building":13,"level":0,"cell":[86,23],"side":[1,0],"state":"open","outer":false},
		{"building":13,"level":0,"cell":[80,23],"side":[-1,0],"state":"open","outer":true},
		{"building":13,"level":0,"cell":[91,23],"side":[1,0],"state":"open","outer":true},
		{"building":13,"level":1,"cell":[86,23],"side":[1,0],"state":"open","outer":false},
		{"building":14,"level":0,"cell":[29,21],"side":[0,1],"state":"open","outer":false},
		{"building":14,"level":0,"cell":[29,24],"side":[0,-1],"state":"open","outer":false},
		{"building":14,"level":0,"cell":[22,22],"side":[-1,0],"state":"open","outer":true},
		{"building":14,"level":0,"cell":[35,22],"side":[1,0],"state":"open","outer":true},
		{"building":14,"level":1,"cell":[29,21],"side":[0,1],"state":"open","outer":false},
		{"building":14,"level":1,"cell":[29,24],"side":[0,-1],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[107,21],"side":[0,1],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[107,24],"side":[0,-1],"state":"open","outer":false},
		{"building":15,"level":0,"cell":[100,22],"side":[-1,0],"state":"open","outer":true},
		{"building":15,"level":0,"cell":[113,22],"side":[1,0],"state":"open","outer":true},
		{"building":0,"level":0,"cell":[78,61],"side":[0,1],"state":"open","outer":true},
		{"building":5,"level":0,"cell":[68,90],"side":[0,-1],"state":"open","outer":true},
		{"building":6,"level":0,"cell":[91,90],"side":[0,-1],"state":"open","outer":true}
	],
	"windows": [
		{"building":0,"level":0,"cell":[67,38],"broken":false},
		{"building":0,"level":0,"cell":[67,61],"broken":false},
		{"building":0,"level":0,"cell":[89,38],"broken":false},
		{"building":0,"level":0,"cell":[89,61],"broken":false},
		{"building":0,"level":0,"cell":[54,40],"broken":false},
		{"building":0,"level":1,"cell":[56,38],"broken":false},
		{"building":0,"level":1,"cell":[56,61],"broken":false},
		{"building":0,"level":1,"cell":[59,38],"broken":false},
		{"building":0,"level":1,"cell":[59,61],"broken":false},
		{"building":0,"level":1,"cell":[54,40],"broken":false},
		{"building":1,"level":0,"cell":[43,40],"broken":false},
		{"building":1,"level":0,"cell":[43,51],"broken":false},
		{"building":1,"level":0,"cell":[48,40],"broken":false},
		{"building":1,"level":0,"cell":[48,51],"broken":false},
		{"building":1,"level":0,"cell":[40,42],"broken":false},
		{"building":1,"level":1,"cell":[43,40],"broken":false},
		{"building":1,"level":1,"cell":[43,51],"broken":false},
		{"building":1,"level":1,"cell":[48,40],"broken":false},
		{"building":1,"level":1,"cell":[48,51],"broken":false},
		{"building":1,"level":1,"cell":[40,42],"broken":false},
		{"building":1,"level":2,"cell":[43,40],"broken":false},
		{"building":1,"level":2,"cell":[43,51],"broken":false},
		{"building":1,"level":2,"cell":[48,40],"broken":false},
		{"building":1,"level":2,"cell":[48,51],"broken":false},
		{"building":1,"level":2,"cell":[40,42],"broken":false},
		{"building":2,"level":0,"cell":[46,62],"broken":false},
		{"building":2,"level":0,"cell":[46,91],"broken":false},
		{"building":2,"level":0,"cell":[55,62],"broken":false},
		{"building":2,"level":0,"cell":[55,91],"broken":false},
		{"building":2,"level":0,"cell":[40,64],"broken":false},
		{"building":2,"level":1,"cell":[46,62],"broken":false},
		{"building":2,"level":1,"cell":[46,91],"broken":false},
		{"building":2,"level":1,"cell":[55,62],"broken":false},
		{"building":2,"level":1,"cell":[55,91],"broken":false},
		{"building":2,"level":1,"cell":[40,64],"broken":false},
		{"building":3,"level":0,"cell":[116,57],"broken":false},
		{"building":3,"level":0,"cell":[116,70],"broken":false},
		{"building":3,"level":0,"cell":[125,57],"broken":false},
		{"building":3,"level":0,"cell":[125,70],"broken":false},
		{"building":3,"level":0,"cell":[110,59],"broken":false},
		{"building":3,"level":1,"cell":[116,57],"broken":false},
		{"building":3,"level":1,"cell":[116,70],"broken":false},
		{"building":3,"level":1,"cell":[125,57],"broken":false},
		{"building":3,"level":1,"cell":[125,70],"broken":false},
		{"building":3,"level":1,"cell":[110,59],"broken":false},
		{"building":4,"level":0,"cell":[116,73],"broken":false},
		{"building":4,"level":0,"cell":[116,86],"broken":false},
		{"building":4,"level":0,"cell":[125,73],"broken":false},
		{"building":4,"level":0,"cell":[125,86],"broken":false},
		{"building":4,"level":0,"cell":[110,75],"broken":false},
		{"building":4,"level":1,"cell":[116,73],"broken":false},
		{"building":4,"level":1,"cell":[116,86],"broken":false},
		{"building":4,"level":1,"cell":[125,73],"broken":false},
		{"building":4,"level":1,"cell":[125,86],"broken":false},
		{"building":4,"level":1,"cell":[110,75],"broken":false},
		{"building":5,"level":0,"cell":[68,90],"broken":false},
		{"building":5,"level":0,"cell":[68,99],"broken":false},
		{"building":5,"level":0,"cell":[76,90],"broken":false},
		{"building":5,"level":0,"cell":[76,99],"broken":false},
		{"building":5,"level":0,"cell":[63,92],"broken":false},
		{"building":5,"level":1,"cell":[68,90],"broken":false},
		{"building":5,"level":1,"cell":[68,99],"broken":false},
		{"building":5,"level":1,"cell":[76,90],"broken":false},
		{"building":5,"level":1,"cell":[76,99],"broken":false},
		{"building":5,"level":1,"cell":[63,92],"broken":false},
		{"building":6,"level":0,"cell":[89,90],"broken":false},
		{"building":6,"level":0,"cell":[89,99],"broken":false},
		{"building":6,"level":0,"cell":[94,90],"broken":false},
		{"building":6,"level":0,"cell":[94,99],"broken":false},
		{"building":6,"level":0,"cell":[85,92],"broken":false},
		{"building":6,"level":1,"cell":[89,90],"broken":false},
		{"building":6,"level":1,"cell":[89,99],"broken":false},
		{"building":6,"level":1,"cell":[94,90],"broken":false},
		{"building":6,"level":1,"cell":[94,99],"broken":false},
		{"building":6,"level":1,"cell":[85,92],"broken":false},
		{"building":7,"level":0,"cell":[137,84],"broken":false},
		{"building":7,"level":0,"cell":[137,93],"broken":false},
		{"building":7,"level":0,"cell":[142,84],"broken":false},
		{"building":7,"level":0,"cell":[142,93],"broken":false},
		{"building":7,"level":0,"cell":[133,86],"broken":false},
		{"building":7,"level":1,"cell":[137,84],"broken":false},
		{"building":7,"level":1,"cell":[137,93],"broken":false},
		{"building":7,"level":1,"cell":[142,84],"broken":false},
		{"building":7,"level":1,"cell":[142,93],"broken":false},
		{"building":7,"level":1,"cell":[133,86],"broken":false},
		{"building":8,"level":0,"cell":[143,43],"broken":false},
		{"building":8,"level":0,"cell":[143,52],"broken":false},
		{"building":8,"level":0,"cell":[148,43],"broken":false},
		{"building":8,"level":0,"cell":[148,52],"broken":false},
		{"building":8,"level":0,"cell":[139,45],"broken":false},
		{"building":8,"level":1,"cell":[143,43],"broken":false},
		{"building":8,"level":1,"cell":[143,52],"broken":false},
		{"building":8,"level":1,"cell":[148,43],"broken":false},
		{"building":8,"level":1,"cell":[148,52],"broken":false},
		{"building":8,"level":1,"cell":[139,45],"broken":false},
		{"building":9,"level":0,"cell":[111,42],"broken":false},
		{"building":9,"level":0,"cell":[111,53],"broken":false},
		{"building":9,"level":0,"cell":[118,42],"broken":false},
		{"building":9,"level":0,"cell":[118,53],"broken":false},
		{"building":9,"level":0,"cell":[107,44],"broken":false},
		{"building":9,"level":1,"cell":[111,42],"broken":false},
		{"building":9,"level":1,"cell":[111,53],"broken":false},
		{"building":9,"level":1,"cell":[118,42],"broken":false},
		{"building":9,"level":1,"cell":[118,53],"broken":false},
		{"building":9,"level":1,"cell":[107,44],"broken":false},
		{"building":10,"level":0,"cell":[156,82],"broken":false},
		{"building":10,"level":0,"cell":[156,93],"broken":false},
		{"building":10,"level":0,"cell":[161,82],"broken":false},
		{"building":10,"level":0,"cell":[161,93],"broken":false},
		{"building":10,"level":0,"cell":[153,84],"broken":false},
		{"building":11,"level":0,"cell":[139,65],"broken":false},
		{"building":11,"level":0,"cell":[139,72],"broken":false},
		{"building":11,"level":0,"cell":[144,65],"broken":false},
		{"building":11,"level":0,"cell":[144,72],"broken":false},
		{"building":11,"level":0,"cell":[136,67],"broken":false},
		{"building":12,"level":0,"cell":[52,18],"broken":false},
		{"building":12,"level":0,"cell":[52,27],"broken":false},
		{"building":12,"level":0,"cell":[59,18],"broken":false},
		{"building":12,"level":0,"cell":[59,27],"broken":false},
		{"building":12,"level":0,"cell":[48,20],"broken":false},
		{"building":13,"level":0,"cell":[83,18],"broken":false},
		{"building":13,"level":0,"cell":[83,27],"broken":false},
		{"building":13,"level":0,"cell":[88,18],"broken":false},
		{"building":13,"level":0,"cell":[88,27],"broken":false},
		{"building":13,"level":0,"cell":[80,20],"broken":false},
		{"building":13,"level":1,"cell":[83,18],"broken":false},
		{"building":13,"level":1,"cell":[83,27],"broken":false},
		{"building":13,"level":1,"cell":[88,18],"broken":false},
		{"building":13,"level":1,"cell":[88,27],"broken":false},
		{"building":13,"level":1,"cell":[80,20],"broken":false},
		{"building":14,"level":0,"cell":[26,17],"broken":false},
		{"building":14,"level":0,"cell":[26,28],"broken":false},
		{"building":14,"level":0,"cell":[31,17],"broken":false},
		{"building":14,"level":0,"cell":[31,28],"broken":false},
		{"building":14,"level":0,"cell":[22,19],"broken":false},
		{"building":14,"level":1,"cell":[26,17],"broken":false},
		{"building":14,"level":1,"cell":[26,28],"broken":false},
		{"building":14,"level":1,"cell":[31,17],"broken":false},
		{"building":14,"level":1,"cell":[31,28],"broken":false},
		{"building":14,"level":1,"cell":[22,19],"broken":false},
		{"building":15,"level":0,"cell":[104,17],"broken":false},
		{"building":15,"level":0,"cell":[104,28],"broken":false},
		{"building":15,"level":0,"cell":[109,17],"broken":false},
		{"building":15,"level":0,"cell":[109,28],"broken":false},
		{"building":15,"level":0,"cell":[100,19],"broken":false}
	],
	"stairs": [
		{"cell":[55,40],"low":0,"high":1,"ladder":false},
		{"cell":[81,40],"low":-1,"high":0,"ladder":false},
		{"cell":[102,59],"low":-1,"high":0,"ladder":false},
		{"cell":[41,41],"low":0,"high":1,"ladder":false},
		{"cell":[50,50],"low":1,"high":2,"ladder":false},
		{"cell":[42,76],"low":0,"high":1,"ladder":false},
		{"cell":[41,64],"low":-1,"high":0,"ladder":false},
		{"cell":[60,89],"low":-1,"high":0,"ladder":false},
		{"cell":[112,63],"low":0,"high":1,"ladder":false},
		{"cell":[112,79],"low":0,"high":1,"ladder":false},
		{"cell":[65,94],"low":0,"high":1,"ladder":false},
		{"cell":[87,94],"low":0,"high":1,"ladder":false},
		{"cell":[135,88],"low":0,"high":1,"ladder":false},
		{"cell":[141,47],"low":0,"high":1,"ladder":false},
		{"cell":[109,47],"low":0,"high":1,"ladder":false},
		{"cell":[82,22],"low":0,"high":1,"ladder":false},
		{"cell":[24,22],"low":0,"high":1,"ladder":false}
	],
	"props": [
		{"kind":"bell_rope","rect":[42,43,1,1],"solid":"none","facing":0,"note":"종 줄 한 가닥","level":1},
		{"kind":"bell_frame","rect":[46,42,4,3],"solid":"none","facing":1,"note":"종을 거는 나무 틀","level":2},
		{"kind":"car","rect":[31,11,4,2],"solid":"low","facing":2,"note":"길가에 선 차","level":0},
		{"kind":"bench","rect":[50,12,3,1],"solid":"low","facing":3,"note":"긴 의자","level":0},
		{"kind":"car","rect":[38,24,4,2],"solid":"low","facing":1,"note":"길가에 선 차","level":0},
		{"kind":"farm_cart","rect":[70,24,4,2],"solid":"low","facing":2,"note":"농가 짐수레","level":0},
		{"kind":"cloister_post","rect":[67,63,1,1],"solid":"wall","facing":3,"note":"회랑 기둥","level":0},
		{"kind":"cloister_post","rect":[103,63,1,1],"solid":"wall","facing":0,"note":"회랑 기둥","level":0},
		{"kind":"cloister_post","rect":[67,87,1,1],"solid":"wall","facing":1,"note":"회랑 기둥","level":0},
		{"kind":"cloister_post","rect":[103,87,1,1],"solid":"wall","facing":2,"note":"회랑 기둥","level":0},
		{"kind":"cloister_post","rect":[67,74,1,1],"solid":"wall","facing":3,"note":"회랑 기둥","level":0},
		{"kind":"cloister_post","rect":[103,78,1,1],"solid":"wall","facing":0,"note":"회랑 기둥","level":0},
		{"kind":"herb_bed","rect":[139,76,4,2],"solid":"none","facing":1,"note":"약초밭 두둑","level":0},
		{"kind":"herb_bed","rect":[148,76,4,2],"solid":"none","facing":2,"note":"약초밭 두둑","level":0},
		{"kind":"herb_rack","rect":[144,74,3,1],"solid":"low","facing":3,"note":"약초 건조대","level":0},
		{"kind":"herb_rack","rect":[155,78,3,1],"solid":"low","facing":0,"note":"약초 건조대","level":0},
		{"kind":"handcart","rect":[159,75,2,1],"solid":"low","facing":1,"note":"뒷문 곁 손수레","level":0},
		{"kind":"crate_stack","rect":[163,76,2,2],"solid":"low","facing":2,"note":"나무 상자","level":0},
		{"kind":"lamp_post","rect":[124,43,1,1],"solid":"none","facing":3,"note":"꺼진 등잔 기둥","level":0},
		{"kind":"crate_stack","rect":[130,44,2,2],"solid":"low","facing":0,"note":"나무 상자","level":0},
		{"kind":"community_banner","rect":[96,84,1,2],"solid":"none","facing":1,"note":"무늬 없는 바랜 천 깃발","level":0},
		{"kind":"bare_tree","rect":[3,18,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[7,21,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[11,18,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[5,26,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[14,27,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[4,43,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[8,46,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[14,44,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[5,51,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[18,52,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[4,80,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[9,83,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[15,81,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[8,88,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[19,91,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[39,57,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[65,36,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[76,36,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[93,36,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[123,17,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[130,24,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[143,18,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[155,23,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[165,15,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[163,29,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[168,58,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[155,66,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[151,72,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[132,93,1,1],"solid":"tree","facing":2,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[107,92,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[105,70,1,1],"solid":"tree","facing":0,"note":"헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[70,84,1,1],"solid":"tree","facing":1,"note":"헐벗은 나무","level":0},
		{"kind":"hymn_shelf","rect":[55,39,2,1],"solid":"low","facing":2,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[62,43,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[55,43,2,1],"solid":"low","facing":0,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[62,39,1,1],"solid":"low","facing":1,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[61,60,2,1],"solid":"low","facing":2,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[55,60,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[61,56,2,1],"solid":"low","facing":0,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[56,56,1,1],"solid":"low","facing":1,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[64,43,2,1],"solid":"low","facing":2,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[72,39,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[65,39,2,1],"solid":"low","facing":0,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[71,43,1,1],"solid":"low","facing":1,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[71,56,2,1],"solid":"low","facing":2,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[65,56,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[70,60,2,1],"solid":"low","facing":0,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[64,56,1,1],"solid":"low","facing":1,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[75,39,2,1],"solid":"low","facing":2,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[81,43,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[74,43,2,1],"solid":"low","facing":0,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[82,43,1,1],"solid":"low","facing":1,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[80,60,2,1],"solid":"low","facing":2,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[74,56,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[74,60,2,1],"solid":"low","facing":0,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[82,56,1,1],"solid":"low","facing":1,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[84,39,2,1],"solid":"low","facing":2,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[92,43,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[84,43,2,1],"solid":"low","facing":0,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[92,39,1,1],"solid":"low","facing":1,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[91,60,2,1],"solid":"low","facing":2,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[84,60,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[91,56,2,1],"solid":"low","facing":0,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[85,56,1,1],"solid":"low","facing":1,"note":"글씨 없는 손종","level":0},
		{"kind":"parish_chest","rect":[94,43,2,1],"solid":"low","facing":2,"note":"회중 기록 궤","level":0},
		{"kind":"hymn_shelf","rect":[101,39,2,1],"solid":"low","facing":3,"note":"찬송집 선반","level":0},
		{"kind":"desk","rect":[95,39,2,1],"solid":"low","facing":0,"note":"책상","level":0},
		{"kind":"candle_stand","rect":[101,43,1,1],"solid":"low","facing":1,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"hymn_shelf","rect":[101,56,2,1],"solid":"low","facing":2,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[95,56,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"vestry_chest","rect":[100,60,2,1],"solid":"low","facing":0,"note":"제의실 궤","level":0},
		{"kind":"hand_bell","rect":[94,56,1,1],"solid":"low","facing":1,"note":"글씨 없는 손종","level":0},
		{"kind":"hymn_shelf","rect":[58,49,2,1],"solid":"none","facing":2,"note":"찬송집 선반","level":1},
		{"kind":"candle_stand","rect":[55,39,1,1],"solid":"none","facing":3,"note":"초 하나가 선 외줄기 촛대","level":1},
		{"kind":"vestry_chest","rect":[55,49,2,1],"solid":"none","facing":0,"note":"제의실 궤","level":1},
		{"kind":"hand_bell","rect":[60,39,1,1],"solid":"none","facing":1,"note":"글씨 없는 손종","level":1},
		{"kind":"hymn_shelf","rect":[55,51,2,1],"solid":"none","facing":2,"note":"찬송집 선반","level":1},
		{"kind":"candle_stand","rect":[60,60,1,1],"solid":"none","facing":3,"note":"초 하나가 선 외줄기 촛대","level":1},
		{"kind":"vestry_chest","rect":[55,60,2,1],"solid":"none","facing":0,"note":"제의실 궤","level":1},
		{"kind":"hand_bell","rect":[60,51,1,1],"solid":"none","facing":1,"note":"글씨 없는 손종","level":1},
		{"kind":"cold_stove","rect":[91,57,1,1],"solid":"none","facing":2,"note":"꺼진 난로","level":-1},
		{"kind":"coal_bin","rect":[84,56,3,2],"solid":"none","facing":3,"note":"난방용 석탄","level":-1},
		{"kind":"firewood_pile","rect":[90,42,2,1],"solid":"none","facing":0,"note":"처마 밑 장작","level":-1},
		{"kind":"barrel","rect":[85,42,1,1],"solid":"none","facing":1,"note":"저장 통","level":-1},
		{"kind":"cask_stack","rect":[93,56,2,2],"solid":"none","facing":2,"note":"저장고 큰 통","level":-1},
		{"kind":"sack_pile","rect":[98,42,2,2],"solid":"none","facing":3,"note":"곡물 자루","level":-1},
		{"kind":"relief_crate","rect":[94,42,2,1],"solid":"none","facing":0,"note":"남은 구호 식량 상자","level":-1},
		{"kind":"barrel","rect":[98,57,1,1],"solid":"none","facing":1,"note":"저장 통","level":-1},
		{"kind":"hand_bell","rect":[42,41,1,1],"solid":"low","facing":2,"note":"글씨 없는 손종","level":0},
		{"kind":"lamp_shelf","rect":[42,50,2,1],"solid":"low","facing":3,"note":"꺼진 등잔 선반","level":0},
		{"kind":"candle_stand","rect":[44,50,1,1],"solid":"low","facing":0,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"hand_bell","rect":[49,50,1,1],"solid":"low","facing":1,"note":"글씨 없는 손종","level":0},
		{"kind":"lamp_shelf","rect":[46,41,2,1],"solid":"low","facing":2,"note":"꺼진 등잔 선반","level":0},
		{"kind":"bench","rect":[46,50,3,1],"solid":"low","facing":3,"note":"긴 의자","level":0},
		{"kind":"candle_stand","rect":[50,41,1,1],"solid":"low","facing":0,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"hand_bell","rect":[44,50,1,1],"solid":"none","facing":1,"note":"글씨 없는 손종","level":1},
		{"kind":"lamp_shelf","rect":[41,50,2,1],"solid":"none","facing":2,"note":"꺼진 등잔 선반","level":1},
		{"kind":"bench","rect":[42,41,3,1],"solid":"none","facing":3,"note":"긴 의자","level":1},
		{"kind":"candle_stand","rect":[43,50,1,1],"solid":"none","facing":0,"note":"초 하나가 선 외줄기 촛대","level":1},
		{"kind":"hand_bell","rect":[46,50,1,1],"solid":"none","facing":1,"note":"글씨 없는 손종","level":1},
		{"kind":"lamp_shelf","rect":[49,41,2,1],"solid":"none","facing":2,"note":"꺼진 등잔 선반","level":1},
		{"kind":"bench","rect":[47,50,3,1],"solid":"none","facing":3,"note":"긴 의자","level":1},
		{"kind":"candle_stand","rect":[47,41,1,1],"solid":"none","facing":0,"note":"초 하나가 선 외줄기 촛대","level":1},
		{"kind":"hand_bell","rect":[41,50,1,1],"solid":"none","facing":1,"note":"글씨 없는 손종","level":2},
		{"kind":"lamp_shelf","rect":[43,41,2,1],"solid":"none","facing":2,"note":"꺼진 등잔 선반","level":2},
		{"kind":"bench","rect":[42,50,3,1],"solid":"none","facing":3,"note":"긴 의자","level":2},
		{"kind":"candle_stand","rect":[41,41,1,1],"solid":"none","facing":0,"note":"초 하나가 선 외줄기 촛대","level":2},
		{"kind":"hand_bell","rect":[50,41,1,1],"solid":"none","facing":1,"note":"글씨 없는 손종","level":2},
		{"kind":"lamp_shelf","rect":[47,41,2,1],"solid":"none","facing":2,"note":"꺼진 등잔 선반","level":2},
		{"kind":"bench","rect":[47,50,3,1],"solid":"none","facing":3,"note":"긴 의자","level":2},
		{"kind":"candle_stand","rect":[46,41,1,1],"solid":"none","facing":0,"note":"초 하나가 선 외줄기 촛대","level":2},
		{"kind":"cask_stack","rect":[42,63,2,2],"solid":"low","facing":1,"note":"저장고 큰 통","level":0},
		{"kind":"sack_pile","rect":[47,73,2,2],"solid":"low","facing":2,"note":"곡물 자루","level":0},
		{"kind":"relief_crate","rect":[41,74,2,1],"solid":"low","facing":3,"note":"남은 구호 식량 상자","level":0},
		{"kind":"barrel","rect":[49,74,1,1],"solid":"low","facing":0,"note":"저장 통","level":0},
		{"kind":"cask_stack","rect":[47,89,2,2],"solid":"low","facing":1,"note":"저장고 큰 통","level":0},
		{"kind":"sack_pile","rect":[41,79,2,2],"solid":"low","facing":2,"note":"곡물 자루","level":0},
		{"kind":"relief_crate","rect":[41,90,2,1],"solid":"low","facing":3,"note":"남은 구호 식량 상자","level":0},
		{"kind":"barrel","rect":[49,79,1,1],"solid":"low","facing":0,"note":"저장 통","level":0},
		{"kind":"cask_stack","rect":[51,63,2,2],"solid":"low","facing":1,"note":"저장고 큰 통","level":0},
		{"kind":"sack_pile","rect":[59,73,2,2],"solid":"low","facing":2,"note":"곡물 자루","level":0},
		{"kind":"relief_crate","rect":[51,74,2,1],"solid":"low","facing":3,"note":"남은 구호 식량 상자","level":0},
		{"kind":"barrel","rect":[60,63,1,1],"solid":"low","facing":0,"note":"저장 통","level":0},
		{"kind":"cask_stack","rect":[51,89,2,2],"solid":"low","facing":1,"note":"저장고 큰 통","level":0},
		{"kind":"sack_pile","rect":[59,79,2,2],"solid":"low","facing":2,"note":"곡물 자루","level":0},
		{"kind":"relief_crate","rect":[52,79,2,1],"solid":"low","facing":3,"note":"남은 구호 식량 상자","level":0},
		{"kind":"barrel","rect":[59,90,1,1],"solid":"low","facing":0,"note":"저장 통","level":0},
		{"kind":"bed","rect":[41,74,2,1],"solid":"none","facing":1,"note":"침대","level":1},
		{"kind":"desk","rect":[48,63,2,1],"solid":"none","facing":2,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[42,63,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[46,74,3,1],"solid":"none","facing":0,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[48,79,2,1],"solid":"none","facing":1,"note":"침대","level":1},
		{"kind":"desk","rect":[42,79,2,1],"solid":"none","facing":2,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[48,90,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[41,90,3,1],"solid":"none","facing":0,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[52,63,2,1],"solid":"none","facing":1,"note":"침대","level":1},
		{"kind":"desk","rect":[58,74,2,1],"solid":"none","facing":2,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[51,63,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[51,74,3,1],"solid":"none","facing":0,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[58,90,2,1],"solid":"none","facing":1,"note":"침대","level":1},
		{"kind":"desk","rect":[51,79,2,1],"solid":"none","facing":2,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[60,90,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[51,90,3,1],"solid":"none","facing":0,"note":"물건 선반","level":1},
		{"kind":"cold_stove","rect":[44,66,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":-1},
		{"kind":"coal_bin","rect":[48,86,3,2],"solid":"none","facing":2,"note":"난방용 석탄","level":-1},
		{"kind":"firewood_pile","rect":[44,87,2,1],"solid":"none","facing":3,"note":"처마 밑 장작","level":-1},
		{"kind":"barrel","rect":[50,66,1,1],"solid":"none","facing":0,"note":"저장 통","level":-1},
		{"kind":"cask_stack","rect":[56,86,2,2],"solid":"none","facing":1,"note":"저장고 큰 통","level":-1},
		{"kind":"sack_pile","rect":[52,86,2,2],"solid":"none","facing":2,"note":"곡물 자루","level":-1},
		{"kind":"relief_crate","rect":[56,66,2,1],"solid":"none","facing":3,"note":"남은 구호 식량 상자","level":-1},
		{"kind":"barrel","rect":[53,66,1,1],"solid":"none","facing":0,"note":"저장 통","level":-1},
		{"kind":"cooking_pot","rect":[129,58,2,2],"solid":"low","facing":1,"note":"음식을 나누던 작은 솥","level":0},
		{"kind":"barrel","rect":[129,61,1,1],"solid":"low","facing":3,"note":"저장 통","level":0},
		{"kind":"long_table","rect":[111,60,4,2],"solid":"low","facing":0,"note":"어긋나게 놓은 식탁","level":0},
		{"kind":"sack_pile","rect":[128,68,2,2],"solid":"low","facing":2,"note":"곡물 자루","level":0},
		{"kind":"barrel","rect":[111,66,1,1],"solid":"low","facing":3,"note":"저장 통","level":0},
		{"kind":"long_table","rect":[111,68,4,2],"solid":"low","facing":0,"note":"어긋나게 놓은 식탁","level":0},
		{"kind":"bed","rect":[128,61,2,1],"solid":"none","facing":1,"note":"침대","level":1},
		{"kind":"desk","rect":[111,58,2,1],"solid":"none","facing":2,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[130,61,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[111,61,3,1],"solid":"none","facing":0,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[111,66,2,1],"solid":"none","facing":1,"note":"침대","level":1},
		{"kind":"desk","rect":[129,69,2,1],"solid":"none","facing":2,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[111,69,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[128,66,3,1],"solid":"none","facing":0,"note":"물건 선반","level":1},
		{"kind":"cooking_pot","rect":[129,76,2,2],"solid":"low","facing":1,"note":"음식을 나누던 작은 솥","level":0},
		{"kind":"barrel","rect":[130,74,1,1],"solid":"low","facing":3,"note":"저장 통","level":0},
		{"kind":"long_table","rect":[112,74,4,2],"solid":"low","facing":0,"note":"어긋나게 놓은 식탁","level":0},
		{"kind":"cooking_pot","rect":[111,84,2,2],"solid":"low","facing":1,"note":"음식을 나누던 작은 솥","level":0},
		{"kind":"barrel","rect":[112,82,1,1],"solid":"low","facing":3,"note":"저장 통","level":0},
		{"kind":"long_table","rect":[126,84,4,2],"solid":"low","facing":0,"note":"어긋나게 놓은 식탁","level":0},
		{"kind":"bed","rect":[129,74,2,1],"solid":"none","facing":1,"note":"침대","level":1},
		{"kind":"desk","rect":[112,74,2,1],"solid":"none","facing":2,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[129,77,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[111,77,3,1],"solid":"none","facing":0,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[112,82,2,1],"solid":"none","facing":1,"note":"침대","level":1},
		{"kind":"desk","rect":[128,85,2,1],"solid":"none","facing":2,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[111,82,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[111,85,3,1],"solid":"none","facing":0,"note":"물건 선반","level":1},
		{"kind":"bookcase","rect":[70,98,2,1],"solid":"low","facing":1,"note":"책장","level":0},
		{"kind":"desk","rect":[64,91,2,1],"solid":"low","facing":2,"note":"책상","level":0},
		{"kind":"hymn_shelf","rect":[64,98,2,1],"solid":"low","facing":3,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[72,91,1,1],"solid":"low","facing":0,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"bookcase","rect":[74,91,2,1],"solid":"low","facing":1,"note":"책장","level":0},
		{"kind":"desk","rect":[80,98,2,1],"solid":"low","facing":2,"note":"책상","level":0},
		{"kind":"hymn_shelf","rect":[74,98,2,1],"solid":"low","facing":3,"note":"찬송집 선반","level":0},
		{"kind":"candle_stand","rect":[81,91,1,1],"solid":"low","facing":0,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"bed","rect":[71,98,2,1],"solid":"none","facing":1,"note":"침대","level":1},
		{"kind":"desk","rect":[64,98,2,1],"solid":"none","facing":2,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[72,91,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[65,91,3,1],"solid":"none","facing":0,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[74,98,2,1],"solid":"none","facing":1,"note":"침대","level":1},
		{"kind":"desk","rect":[80,91,2,1],"solid":"none","facing":2,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[75,91,1,1],"solid":"none","facing":3,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[78,98,3,1],"solid":"none","facing":0,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[87,91,2,1],"solid":"low","facing":1,"note":"침대","level":0},
		{"kind":"desk","rect":[89,98,2,1],"solid":"low","facing":2,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[86,91,1,1],"solid":"low","facing":3,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[86,98,3,1],"solid":"low","facing":0,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[94,91,2,1],"solid":"low","facing":1,"note":"침대","level":0},
		{"kind":"desk","rect":[95,98,2,1],"solid":"low","facing":2,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[93,91,1,1],"solid":"low","facing":3,"note":"꺼진 난로","level":0},
		{"kind":"bed","rect":[89,98,2,1],"solid":"none","facing":0,"note":"침대","level":1},
		{"kind":"desk","rect":[86,91,2,1],"solid":"none","facing":1,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[91,98,1,1],"solid":"none","facing":2,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[86,98,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[93,91,2,1],"solid":"none","facing":0,"note":"침대","level":1},
		{"kind":"desk","rect":[96,98,2,1],"solid":"none","facing":1,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[93,98,1,1],"solid":"none","facing":2,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[95,91,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[138,92,2,1],"solid":"low","facing":0,"note":"침대","level":0},
		{"kind":"desk","rect":[134,92,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[139,85,1,1],"solid":"low","facing":2,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[135,85,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[141,92,2,1],"solid":"low","facing":0,"note":"침대","level":0},
		{"kind":"desk","rect":[144,85,2,1],"solid":"low","facing":1,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[142,85,1,1],"solid":"low","facing":2,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[143,92,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[138,85,2,1],"solid":"none","facing":0,"note":"침대","level":1},
		{"kind":"desk","rect":[135,85,2,1],"solid":"none","facing":1,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[138,92,1,1],"solid":"none","facing":2,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[134,92,3,1],"solid":"none","facing":3,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[142,85,2,1],"solid":"none","facing":0,"note":"침대","level":1},
		{"kind":"desk","rect":[143,92,2,1],"solid":"none","facing":1,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[141,85,1,1],"solid":"none","facing":2,"note":"꺼진 난로","level":1},
		{"kind":"bread_rack","rect":[144,51,1,1],"solid":"low","facing":3,"note":"빵 선반","level":0},
		{"kind":"bread_rack","rect":[140,44,1,1],"solid":"low","facing":0,"note":"빵 선반","level":0},
		{"kind":"dough_table","rect":[140,51,2,1],"solid":"low","facing":1,"note":"반죽대","level":0},
		{"kind":"sack_pile","rect":[144,44,2,2],"solid":"low","facing":2,"note":"곡물 자루","level":0},
		{"kind":"bread_rack","rect":[147,44,1,1],"solid":"low","facing":3,"note":"빵 선반","level":0},
		{"kind":"bread_rack","rect":[151,51,1,1],"solid":"low","facing":0,"note":"빵 선반","level":0},
		{"kind":"dough_table","rect":[147,51,2,1],"solid":"low","facing":1,"note":"반죽대","level":0},
		{"kind":"sack_pile","rect":[150,44,2,2],"solid":"low","facing":2,"note":"곡물 자루","level":0},
		{"kind":"bed","rect":[144,51,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[140,51,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[145,44,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[141,44,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[147,51,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[150,44,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[148,44,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[149,51,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[120,43,2,1],"solid":"low","facing":3,"note":"침대","level":0},
		{"kind":"desk","rect":[109,43,2,1],"solid":"low","facing":0,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[120,45,1,1],"solid":"low","facing":1,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[108,45,3,1],"solid":"low","facing":2,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[109,50,2,1],"solid":"low","facing":3,"note":"침대","level":0},
		{"kind":"desk","rect":[119,52,2,1],"solid":"low","facing":0,"note":"책상","level":0},
		{"kind":"cold_stove","rect":[108,50,1,1],"solid":"low","facing":1,"note":"꺼진 난로","level":0},
		{"kind":"shelf","rect":[108,52,3,1],"solid":"low","facing":2,"note":"물건 선반","level":0},
		{"kind":"bed","rect":[119,45,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[108,43,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[121,45,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[108,45,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[108,50,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[120,52,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[108,52,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[119,50,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"shelf","rect":[161,85,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"crate_stack","rect":[154,84,2,2],"solid":"low","facing":0,"note":"나무 상자","level":0},
		{"kind":"barrel","rect":[163,83,1,1],"solid":"low","facing":1,"note":"저장 통","level":0},
		{"kind":"handcart","rect":[155,83,2,1],"solid":"low","facing":2,"note":"뒷문 곁 손수레","level":0},
		{"kind":"shelf","rect":[154,92,3,1],"solid":"low","facing":3,"note":"물건 선반","level":0},
		{"kind":"barrel","rect":[155,90,1,1],"solid":"low","facing":1,"note":"저장 통","level":0},
		{"kind":"handcart","rect":[161,92,2,1],"solid":"low","facing":2,"note":"뒷문 곁 손수레","level":0},
		{"kind":"cold_stove","rect":[146,66,1,1],"solid":"low","facing":3,"note":"꺼진 난로","level":0},
		{"kind":"coal_bin","rect":[138,66,3,2],"solid":"low","facing":0,"note":"난방용 석탄","level":0},
		{"kind":"firewood_pile","rect":[144,71,2,1],"solid":"low","facing":1,"note":"처마 밑 장작","level":0},
		{"kind":"barrel","rect":[137,66,1,1],"solid":"low","facing":2,"note":"저장 통","level":0},
		{"kind":"bed","rect":[81,26,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[84,19,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[82,19,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[83,26,3,1],"solid":"none","facing":2,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[89,19,2,1],"solid":"none","facing":3,"note":"침대","level":1},
		{"kind":"desk","rect":[88,26,2,1],"solid":"none","facing":0,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[87,19,1,1],"solid":"none","facing":1,"note":"꺼진 난로","level":1},
		{"kind":"bed","rect":[23,18,2,1],"solid":"none","facing":2,"note":"침대","level":1},
		{"kind":"desk","rect":[33,20,2,1],"solid":"none","facing":3,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[23,20,1,1],"solid":"none","facing":0,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[32,18,3,1],"solid":"none","facing":1,"note":"물건 선반","level":1},
		{"kind":"bed","rect":[33,27,2,1],"solid":"none","facing":2,"note":"침대","level":1},
		{"kind":"desk","rect":[23,27,2,1],"solid":"none","facing":3,"note":"책상","level":1},
		{"kind":"cold_stove","rect":[34,25,1,1],"solid":"none","facing":0,"note":"꺼진 난로","level":1},
		{"kind":"shelf","rect":[24,25,3,1],"solid":"none","facing":1,"note":"물건 선반","level":1},
		{"kind":"shop_counter","rect":[141,44,3,1],"solid":"low","facing":1,"note":"가게 계산대","level":0},
		{"kind":"display_shelf","rect":[140,45,4,1],"solid":"low","facing":2,"note":"가게 진열대","level":0},
		{"kind":"bread_rack","rect":[140,46,1,1],"solid":"low","facing":3,"note":"빵 선반","level":0},
		{"kind":"bread_rack","rect":[141,46,1,1],"solid":"low","facing":0,"note":"빵 선반","level":0},
		{"kind":"dough_table","rect":[142,46,2,1],"solid":"low","facing":1,"note":"반죽대","level":0},
		{"kind":"sack_pile","rect":[144,46,2,2],"solid":"low","facing":2,"note":"곡물 자루","level":0},
		{"kind":"hand_bell","rect":[154,83,1,1],"solid":"low","facing":3,"note":"글씨 없는 손종","level":0},
		{"kind":"parish_chest","rect":[45,66,2,1],"solid":"none","facing":0,"note":"회중 기록 궤","level":-1},
		{"kind":"hymn_shelf","rect":[140,45,2,1],"solid":"none","facing":1,"note":"찬송집 선반","level":1},
		{"kind":"pew_row","rect":[60,45,6,1],"solid":"low","facing":1,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[89,45,6,1],"solid":"low","facing":2,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[60,47,6,1],"solid":"low","facing":3,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[89,47,6,1],"solid":"low","facing":0,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[56,49,6,1],"solid":"low","facing":1,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[83,49,6,1],"solid":"low","facing":2,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[56,51,6,1],"solid":"low","facing":3,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[83,51,6,1],"solid":"low","facing":0,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[60,53,6,1],"solid":"low","facing":1,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"pew_row","rect":[89,53,6,1],"solid":"low","facing":2,"note":"비껴 놓은 긴 의자","level":0},
		{"kind":"sack_pile","rect":[111,58,2,2],"solid":"low","facing":2,"note":"곡물 자루","level":0},
		{"kind":"sack_pile","rect":[116,74,2,2],"solid":"low","facing":2,"note":"곡물 자루","level":0},
		{"kind":"sack_pile","rect":[114,82,2,2],"solid":"low","facing":2,"note":"곡물 자루","level":0},
		{"kind":"cooking_pot","rect":[116,66,2,2],"solid":"low","facing":1,"note":"음식을 나누던 작은 솥","level":0},
		{"kind":"crate_stack","rect":[157,91,2,2],"solid":"low","facing":0,"note":"나무 상자","level":0},
		{"kind":"bare_tree","rect":[85,76,1,1],"solid":"tree","facing":3,"note":"헐벗은 나무","level":0},
		{"kind":"altar_table","rect":[99,46,3,1],"solid":"low","facing":0,"note":"무늬 없는 천을 덮은 제단 탁자","level":0},
		{"kind":"pulpit","rect":[96,46,2,2],"solid":"low","facing":1,"note":"설교단","level":0},
		{"kind":"candle_stand","rect":[95,46,1,1],"solid":"low","facing":2,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"candle_stand","rect":[94,46,1,1],"solid":"low","facing":3,"note":"초 하나가 선 외줄기 촛대","level":0},
		{"kind":"community_banner","rect":[101,47,1,2],"solid":"none","facing":0,"note":"무늬 없는 바랜 천 깃발","level":0},
		{"kind":"lamp_shelf","rect":[127,35,2,1],"solid":"low","facing":1,"note":"맨홀 곁 꺼진 등잔","level":0},
		{"kind":"crate_stack","rect":[120,33,2,2],"solid":"low","facing":2,"note":"맨홀 곁 나무 상자","level":0},
		{"kind":"blanket_screen","rect":[119,35,3,1],"solid":"low","facing":3,"note":"맨홀 곁 반쯤 접힌 젖은 담요","level":0},
		{"kind":"firewood_pile","rect":[92,25,2,1],"solid":"low","facing":3,"note":"처마 밑 장작","level":0}
	],
	"rooms": [
		{"building":0,"level":0,"rect":[55,39,8,5],"name":"찬송집 방","theme":"church"},
		{"building":0,"level":0,"rect":[55,56,8,5],"name":"종지기 방","theme":"church"},
		{"building":0,"level":0,"rect":[64,39,9,5],"name":"현관 방","theme":"church"},
		{"building":0,"level":0,"rect":[64,56,9,5],"name":"옆 예배실","theme":"church"},
		{"building":0,"level":0,"rect":[74,39,9,5],"name":"제의실","theme":"church"},
		{"building":0,"level":0,"rect":[74,56,9,5],"name":"회중 준비방","theme":"church"},
		{"building":0,"level":0,"rect":[84,39,9,5],"name":"교구 사무방","theme":"church"},
		{"building":0,"level":0,"rect":[84,56,9,5],"name":"성가대방","theme":"church"},
		{"building":0,"level":0,"rect":[94,39,9,5],"name":"기록방","theme":"archive"},
		{"building":0,"level":0,"rect":[94,56,9,5],"name":"안쪽 저장실","theme":"church"},
		{"building":0,"level":0,"rect":[55,45,48,10],"name":"회중석","theme":"nave"},
		{"building":0,"level":1,"rect":[55,39,6,11],"name":"합창 다락 앞방","theme":"church"},
		{"building":0,"level":1,"rect":[55,51,6,10],"name":"합창 다락 뒷방","theme":"church"},
		{"building":0,"level":-1,"rect":[84,42,8,16],"name":"난방실","theme":"heat"},
		{"building":0,"level":-1,"rect":[93,42,7,16],"name":"막다른 식량 저장실","theme":"cellar"},
		{"building":0,"level":-1,"rect":[81,39,22,2],"name":"저장고 둘레 통로","theme":"corridor"},
		{"building":1,"level":0,"rect":[41,41,4,10],"name":"탑 아래 앞방","theme":"tower"},
		{"building":1,"level":0,"rect":[46,41,5,10],"name":"탑 아래 뒷방","theme":"tower"},
		{"building":1,"level":1,"rect":[41,41,4,10],"name":"종 줄 방","theme":"tower"},
		{"building":1,"level":1,"rect":[46,41,5,10],"name":"종 줄 방의 돌아가는 길","theme":"tower"},
		{"building":1,"level":2,"rect":[41,41,4,10],"name":"종 다락 앞방","theme":"tower"},
		{"building":1,"level":2,"rect":[46,41,5,10],"name":"종 다락","theme":"tower"},
		{"building":2,"level":0,"rect":[41,63,9,12],"name":"서채 저장고 앞방","theme":"cellar"},
		{"building":2,"level":0,"rect":[41,79,9,12],"name":"서채 저장고 뒷방","theme":"cellar"},
		{"building":2,"level":0,"rect":[51,63,10,12],"name":"서채 저장고 앞방","theme":"cellar"},
		{"building":2,"level":0,"rect":[51,79,10,12],"name":"서채 저장고 뒷방","theme":"cellar"},
		{"building":2,"level":1,"rect":[41,63,9,12],"name":"서채 저장고 앞방","theme":"home"},
		{"building":2,"level":1,"rect":[41,79,9,12],"name":"서채 저장고 뒷방","theme":"home"},
		{"building":2,"level":1,"rect":[51,63,10,12],"name":"서채 저장고 앞방","theme":"home"},
		{"building":2,"level":1,"rect":[51,79,10,12],"name":"서채 저장고 뒷방","theme":"home"},
		{"building":2,"level":-1,"rect":[44,66,7,22],"name":"난방실","theme":"heat"},
		{"building":2,"level":-1,"rect":[52,66,6,22],"name":"막다른 식량 저장실","theme":"cellar"},
		{"building":2,"level":-1,"rect":[41,63,20,2],"name":"저장고 둘레 통로","theme":"corridor"},
		{"building":3,"level":0,"rect":[111,58,20,4],"name":"동채 식당 앞방","theme":"kitchen"},
		{"building":3,"level":0,"rect":[111,66,20,4],"name":"동채 식당 뒷방","theme":"kitchen"},
		{"building":3,"level":1,"rect":[111,58,20,4],"name":"동채 식당 앞방","theme":"home"},
		{"building":3,"level":1,"rect":[111,66,20,4],"name":"동채 식당 뒷방","theme":"home"},
		{"building":4,"level":0,"rect":[111,74,20,4],"name":"동채 부엌 앞방","theme":"kitchen"},
		{"building":4,"level":0,"rect":[111,82,20,4],"name":"동채 부엌 뒷방","theme":"kitchen"},
		{"building":4,"level":1,"rect":[111,74,20,4],"name":"동채 부엌 앞방","theme":"home"},
		{"building":4,"level":1,"rect":[111,82,20,4],"name":"동채 부엌 뒷방","theme":"home"},
		{"building":5,"level":0,"rect":[64,91,9,8],"name":"남채 도서실 앞방","theme":"library"},
		{"building":5,"level":0,"rect":[74,91,8,8],"name":"남채 도서실 뒷방","theme":"library"},
		{"building":5,"level":1,"rect":[64,91,9,8],"name":"남채 도서실 앞방","theme":"home"},
		{"building":5,"level":1,"rect":[74,91,8,8],"name":"남채 도서실 뒷방","theme":"home"},
		{"building":6,"level":0,"rect":[86,91,6,8],"name":"수도자 방 가 앞방","theme":"home"},
		{"building":6,"level":0,"rect":[93,91,5,8],"name":"수도자 방 가 뒷방","theme":"home"},
		{"building":6,"level":1,"rect":[86,91,6,8],"name":"수도자 방 가 앞방","theme":"home"},
		{"building":6,"level":1,"rect":[93,91,5,8],"name":"수도자 방 가 뒷방","theme":"home"},
		{"building":7,"level":0,"rect":[134,85,6,8],"name":"수도자 방 나 앞방","theme":"home"},
		{"building":7,"level":0,"rect":[141,85,5,8],"name":"수도자 방 나 뒷방","theme":"home"},
		{"building":7,"level":1,"rect":[134,85,6,8],"name":"수도자 방 나 앞방","theme":"home"},
		{"building":7,"level":1,"rect":[141,85,5,8],"name":"수도자 방 나 뒷방","theme":"home"},
		{"building":8,"level":0,"rect":[140,44,6,8],"name":"문간 빵 가게 앞방","theme":"bakery"},
		{"building":8,"level":0,"rect":[147,44,5,8],"name":"문간 빵 가게 뒷방","theme":"bakery"},
		{"building":8,"level":1,"rect":[140,44,6,8],"name":"문간 빵 가게 앞방","theme":"home"},
		{"building":8,"level":1,"rect":[147,44,5,8],"name":"문간 빵 가게 뒷방","theme":"home"},
		{"building":9,"level":0,"rect":[108,43,14,3],"name":"손님채 앞방","theme":"home"},
		{"building":9,"level":0,"rect":[108,50,14,3],"name":"손님채 뒷방","theme":"home"},
		{"building":9,"level":1,"rect":[108,43,14,3],"name":"손님채 앞방","theme":"home"},
		{"building":9,"level":1,"rect":[108,50,14,3],"name":"손님채 뒷방","theme":"home"},
		{"building":10,"level":0,"rect":[154,83,10,3],"name":"약초 창고 앞방","theme":"store"},
		{"building":10,"level":0,"rect":[154,90,10,3],"name":"약초 창고 뒷방","theme":"store"},
		{"building":11,"level":0,"rect":[137,66,10,6],"name":"장작 창고 안방","theme":"heat"},
		{"building":12,"level":0,"rect":[49,19,7,8],"name":"마구간 앞방","theme":"store"},
		{"building":12,"level":0,"rect":[57,19,6,8],"name":"마구간 뒷방","theme":"store"},
		{"building":13,"level":0,"rect":[81,19,5,8],"name":"관리인 집 앞방","theme":"home"},
		{"building":13,"level":0,"rect":[87,19,4,8],"name":"관리인 집 뒷방","theme":"home"},
		{"building":13,"level":1,"rect":[81,19,5,8],"name":"관리인 집 앞방","theme":"home"},
		{"building":13,"level":1,"rect":[87,19,4,8],"name":"관리인 집 뒷방","theme":"home"},
		{"building":14,"level":0,"rect":[23,18,12,3],"name":"농가 가 앞방","theme":"home"},
		{"building":14,"level":0,"rect":[23,25,12,3],"name":"농가 가 뒷방","theme":"home"},
		{"building":14,"level":1,"rect":[23,18,12,3],"name":"농가 가 앞방","theme":"home"},
		{"building":14,"level":1,"rect":[23,25,12,3],"name":"농가 가 뒷방","theme":"home"},
		{"building":15,"level":0,"rect":[101,18,12,3],"name":"농가 나 앞방","theme":"home"},
		{"building":15,"level":0,"rect":[101,25,12,3],"name":"농가 나 뒷방","theme":"home"}
	],
	"containers": [
		{"id":"box_001","name":"찬송집 방 보관함","cell":[55,42],"building":0,"search":4,"items":["food_pack"],"locked":false,"level":0,"searched":false},
		{"id":"box_002","name":"종지기 방 보관함","cell":[57,59],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_003","name":"현관 방 보관함","cell":[64,42],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_004","name":"옆 예배실 보관함","cell":[67,59],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_005","name":"제의실 보관함","cell":[82,41],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_006","name":"회중 준비방 보관함","cell":[74,59],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_007","name":"교구 사무방 보관함","cell":[84,42],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_008","name":"성가대방 보관함","cell":[86,59],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_009","name":"기록방 보관함","cell":[94,42],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_010","name":"안쪽 저장실 보관함","cell":[96,59],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_011","name":"회중석 보관함","cell":[76,51],"building":0,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_012","name":"합창 다락 앞방 보관함","cell":[60,45],"building":0,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_013","name":"합창 다락 뒷방 보관함","cell":[59,57],"building":0,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_014","name":"난방실 보관함","cell":[88,52],"building":0,"search":4,"items":[],"locked":false,"level":-1,"searched":false},
		{"id":"box_015","name":"막다른 식량 저장실 보관함","cell":[96,52],"building":0,"search":4,"items":[],"locked":false,"level":-1,"searched":false},
		{"id":"box_016","name":"탑 아래 앞방 보관함","cell":[43,46],"building":1,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_017","name":"탑 아래 뒷방 보관함","cell":[50,46],"building":1,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_018","name":"종 줄 방 보관함","cell":[41,47],"building":1,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_019","name":"종 줄 방의 돌아가는 길 보관함","cell":[50,46],"building":1,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_020","name":"종 다락 앞방 보관함","cell":[41,47],"building":1,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_021","name":"종 다락 보관함","cell":[50,46],"building":1,"search":4,"items":[],"locked":false,"level":2,"searched":false},
		{"id":"box_022","name":"서채 저장고 앞방 보관함","cell":[43,70],"building":2,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_023","name":"서채 저장고 뒷방 보관함","cell":[47,86],"building":2,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_024","name":"서채 저장고 앞방 보관함","cell":[54,70],"building":2,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_025","name":"서채 저장고 뒷방 보관함","cell":[58,86],"building":2,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_026","name":"서채 저장고 앞방 보관함","cell":[46,70],"building":2,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_027","name":"서채 저장고 뒷방 보관함","cell":[49,86],"building":2,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_028","name":"서채 저장고 앞방 보관함","cell":[57,70],"building":2,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_029","name":"서채 저장고 뒷방 보관함","cell":[60,86],"building":2,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_030","name":"난방실 보관함","cell":[47,80],"building":2,"search":4,"items":["food_pack","food_pack"],"locked":false,"level":-1,"searched":false},
		{"id":"box_031","name":"막다른 식량 저장실 보관함","cell":[54,80],"building":2,"search":6,"items":["food_pack","food_pack","food_pack"],"locked":false,"level":-1,"searched":false},
		{"id":"box_032","name":"동채 식당 앞방 보관함","cell":[124,60],"building":3,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_033","name":"동채 식당 뒷방 보관함","cell":[122,68],"building":3,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_034","name":"동채 식당 앞방 보관함","cell":[123,60],"building":3,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_035","name":"동채 식당 뒷방 보관함","cell":[124,68],"building":3,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_036","name":"동채 부엌 앞방 보관함","cell":[123,76],"building":4,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_037","name":"동채 부엌 뒷방 보관함","cell":[119,84],"building":4,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_038","name":"동채 부엌 앞방 보관함","cell":[123,76],"building":4,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_039","name":"동채 부엌 뒷방 보관함","cell":[124,84],"building":4,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_040","name":"남채 도서실 앞방 보관함","cell":[67,96],"building":5,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_041","name":"남채 도서실 뒷방 보관함","cell":[76,96],"building":5,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_042","name":"남채 도서실 앞방 보관함","cell":[67,96],"building":5,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_043","name":"남채 도서실 뒷방 보관함","cell":[76,96],"building":5,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_044","name":"수도자 방 가 앞방 보관함","cell":[88,96],"building":6,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_045","name":"수도자 방 가 뒷방 보관함","cell":[95,96],"building":6,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_046","name":"수도자 방 가 앞방 보관함","cell":[88,96],"building":6,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_047","name":"수도자 방 가 뒷방 보관함","cell":[95,96],"building":6,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_048","name":"수도자 방 나 앞방 보관함","cell":[136,90],"building":7,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_049","name":"수도자 방 나 뒷방 보관함","cell":[141,90],"building":7,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_050","name":"수도자 방 나 앞방 보관함","cell":[136,90],"building":7,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_051","name":"수도자 방 나 뒷방 보관함","cell":[143,90],"building":7,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_052","name":"문간 빵 가게 앞방 보관함","cell":[143,49],"building":8,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_053","name":"문간 빵 가게 뒷방 보관함","cell":[149,49],"building":8,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_054","name":"문간 빵 가게 앞방 보관함","cell":[142,49],"building":8,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_055","name":"문간 빵 가게 뒷방 보관함","cell":[149,49],"building":8,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_056","name":"손님채 앞방 보관함","cell":[120,44],"building":9,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_057","name":"손님채 뒷방 보관함","cell":[119,51],"building":9,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_058","name":"손님채 앞방 보관함","cell":[121,44],"building":9,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_059","name":"손님채 뒷방 보관함","cell":[121,51],"building":9,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_060","name":"약초 창고 앞방 보관함","cell":[162,84],"building":10,"search":6,"items":["food_pack","food_pack","food_pack"],"locked":false,"level":0,"searched":false},
		{"id":"box_061","name":"약초 창고 뒷방 보관함","cell":[160,91],"building":10,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_062","name":"장작 창고 안방 보관함","cell":[139,70],"building":11,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_063","name":"마구간 앞방 보관함","cell":[52,24],"building":12,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_064","name":"마구간 뒷방 보관함","cell":[60,24],"building":12,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_065","name":"관리인 집 앞방 보관함","cell":[84,24],"building":13,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_066","name":"관리인 집 뒷방 보관함","cell":[89,24],"building":13,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_067","name":"관리인 집 앞방 보관함","cell":[83,24],"building":13,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_068","name":"관리인 집 뒷방 보관함","cell":[88,24],"building":13,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_069","name":"농가 가 앞방 보관함","cell":[34,19],"building":14,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_070","name":"농가 가 뒷방 보관함","cell":[34,26],"building":14,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_071","name":"농가 가 앞방 보관함","cell":[34,19],"building":14,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_072","name":"농가 가 뒷방 보관함","cell":[34,26],"building":14,"search":4,"items":[],"locked":false,"level":1,"searched":false},
		{"id":"box_073","name":"농가 나 앞방 보관함","cell":[111,19],"building":15,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_074","name":"농가 나 뒷방 보관함","cell":[111,26],"building":15,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"box_075","name":"승강장 남은 상자","cell":[51,10],"building":-1,"search":3,"items":["plank","cloth"],"locked":false,"level":0,"searched":false}
	],
	"entries": [
		{"id":"west_road","cells":[[0,31],[0,32],[0,33],[0,34]],"gap":0.6},
		{"id":"east_road","cells":[[169,38],[169,39],[169,40],[169,41]],"gap":0.6},
		{"id":"south_farm","cells":[[120,99],[121,99],[122,99],[123,99]],"gap":0.6},
		{"id":"southwest_lane","cells":[[30,99],[31,99],[32,99]],"gap":2}
	],
	"holes": [
		{"id":"manhole_01","cell":[124,38],"name":"문간 앞 맨홀","level":0,"gap":3}
	],
	"slots": [
		[43,25],
		[45,25],
		[74,25],
		[76,25],
		[96,25],
		[98,25]
	],
	"dead": [
		[4,32],
		[165,39],
		[121,97],
		[31,95],
		[125,56],
		[158,76]
	],
	"deep": [
		"E",
		"F"
	],
	"work": {"cell":[42,94],"rect":[40,88,18,10]}
}

# 위쪽 일터의 독립 평면. 아래쪽 계획의 건물 번호 뒤에만 덧붙인다.
const NORTH: Dictionary = {
	"names": {"H":"양 우리 구역","I":"방직 구내","J":"겨울 우리 마당"},
	"zones": [
		{"id":"H","rect":[0,0,84,46]},
		{"id":"I","rect":[84,0,32,46]},
		{"id":"J","rect":[116,0,54,46]}
	],
	"ground": [
		{"rect":[0,0,84,24],"kind":"DEEP_SNOW"},
		{"rect":[90,0,26,24],"kind":"GRAVEL"},
		{"rect":[116,12,54,33],"kind":"DEEP_SNOW"},
		{"rect":[84,0,6,43],"kind":"ROAD"},
		{"rect":[0,8,84,5],"kind":"ROAD"},
		{"rect":[90,8,80,4],"kind":"ROAD"},
		{"rect":[124,12,5,33],"kind":"ROAD"},
		{"rect":[22,13,6,30],"kind":"ROAD"},
		{"rect":[106,20,18,4],"kind":"GRAVEL"},
		{"rect":[10,24,6,21],"kind":"ROAD"},
		{"rect":[96,34,6,11],"kind":"ROAD"}
	],
	"buildings": [
		{"id":16,"name":"돌담 우리","rect":[66,13,18,11],"warm":false,"window_broken":false},
		{"id":17,"name":"방직 작업장","rect":[134,12,30,12],"warm":false,"window_broken":false},
		{"id":18,"name":"모직 곳간","rect":[90,13,16,11],"warm":false,"window_broken":false},
		{"id":19,"name":"양모 헛간","rect":[40,13,26,11],"warm":false,"window_broken":false},
		{"id":20,"name":"양치기 집","rect":[28,13,12,11],"warm":false,"window_broken":false},
		{"id":21,"name":"건초 헛간","rect":[4,13,18,11],"warm":false,"window_broken":false},
		{"id":22,"name":"외딴 오두막","rect":[6,0,19,12],"warm":false,"window_broken":false},
		{"id":23,"name":"겨울 우리 헛간","rect":[140,29,20,8],"warm":false,"window_broken":false},
		{"id":24,"name":"농기구 헛간","rect":[132,38,10,7],"warm":false,"window_broken":false}
	],
	"shells": [
		{"building":16,"level":0,"rect":[66,13,18,11]},
		{"building":17,"level":-1,"rect":[134,12,30,12]},
		{"building":17,"level":0,"rect":[134,12,30,12]},
		{"building":17,"level":1,"rect":[134,12,30,12]},
		{"building":17,"level":2,"rect":[134,12,30,12]},
		{"building":18,"level":0,"rect":[90,13,16,11]},
		{"building":18,"level":1,"rect":[90,13,16,11]},
		{"building":19,"level":0,"rect":[40,13,26,11]},
		{"building":20,"level":0,"rect":[28,13,12,11]},
		{"building":20,"level":1,"rect":[28,13,12,11]},
		{"building":21,"level":0,"rect":[4,13,18,11]},
		{"building":22,"level":-1,"rect":[6,0,19,12]},
		{"building":22,"level":0,"rect":[6,0,10,7]},
		{"building":23,"level":0,"rect":[140,29,20,8]},
		{"building":24,"level":0,"rect":[132,38,10,7]}
	],
	"walls": [
		{"level":0,"rect":[75,14,1,9]},
		{"level":-1,"rect":[149,13,1,10]},
		{"level":0,"rect":[135,16,28,1]},
		{"level":0,"rect":[135,19,28,1]},
		{"level":0,"rect":[143,13,1,3]},
		{"level":0,"rect":[143,20,1,3]},
		{"level":0,"rect":[152,13,1,3]},
		{"level":0,"rect":[152,20,1,3]},
		{"level":1,"rect":[149,13,1,10]},
		{"level":2,"rect":[149,13,1,10]},
		{"level":0,"rect":[98,14,1,9]},
		{"level":1,"rect":[98,14,1,9]},
		{"level":0,"rect":[41,20,24,1]},
		{"level":0,"rect":[48,14,1,6]},
		{"level":0,"rect":[56,14,1,6]},
		{"level":0,"rect":[34,14,1,9]},
		{"level":1,"rect":[34,14,1,9]},
		{"level":0,"rect":[13,14,1,9]},
		{"level":-1,"rect":[7,3,17,1]},
		{"level":-1,"rect":[15,4,1,7]},
		{"level":0,"rect":[150,30,1,6]}
	],
	"doors": [
		{"building":16,"level":0,"cell":[75,18],"side":[1,0],"state":"open","outer":false},
		{"building":16,"level":0,"cell":[71,13],"side":[0,-1],"state":"open","outer":true},
		{"building":17,"level":-1,"cell":[149,18],"side":[1,0],"state":"open","outer":false},
		{"building":17,"level":0,"cell":[139,16],"side":[0,1],"state":"open","outer":false},
		{"building":17,"level":0,"cell":[139,19],"side":[0,-1],"state":"open","outer":false},
		{"building":17,"level":0,"cell":[148,16],"side":[0,1],"state":"open","outer":false},
		{"building":17,"level":0,"cell":[148,19],"side":[0,-1],"state":"open","outer":false},
		{"building":17,"level":0,"cell":[158,16],"side":[0,1],"state":"open","outer":false},
		{"building":17,"level":0,"cell":[158,19],"side":[0,-1],"state":"open","outer":false},
		{"building":17,"level":0,"cell":[149,23],"side":[0,1],"state":"open","outer":true},
		{"building":17,"level":1,"cell":[149,18],"side":[1,0],"state":"open","outer":false},
		{"building":17,"level":2,"cell":[149,18],"side":[1,0],"state":"open","outer":false},
		{"building":18,"level":0,"cell":[98,18],"side":[1,0],"state":"open","outer":false},
		{"building":18,"level":0,"cell":[94,13],"side":[0,-1],"state":"open","outer":true},
		{"building":18,"level":1,"cell":[98,18],"side":[1,0],"state":"open","outer":false},
		{"building":19,"level":0,"cell":[44,20],"side":[0,1],"state":"open","outer":false},
		{"building":19,"level":0,"cell":[52,20],"side":[0,1],"state":"open","outer":false},
		{"building":19,"level":0,"cell":[61,20],"side":[0,1],"state":"open","outer":false},
		{"building":19,"level":0,"cell":[53,13],"side":[0,-1],"state":"open","outer":true},
		{"building":20,"level":0,"cell":[34,18],"side":[1,0],"state":"open","outer":false},
		{"building":20,"level":0,"cell":[31,13],"side":[0,-1],"state":"open","outer":true},
		{"building":20,"level":1,"cell":[34,18],"side":[1,0],"state":"open","outer":false},
		{"building":21,"level":0,"cell":[13,18],"side":[1,0],"state":"open","outer":false},
		{"building":21,"level":0,"cell":[9,13],"side":[0,-1],"state":"open","outer":true},
		{"building":22,"level":-1,"cell":[11,3],"side":[0,-1],"state":"open","outer":false},
		{"building":22,"level":-1,"cell":[20,3],"side":[0,-1],"state":"open","outer":false},
		{"building":22,"level":0,"cell":[11,6],"side":[0,1],"state":"open","outer":true},
		{"building":23,"level":0,"cell":[150,33],"side":[1,0],"state":"open","outer":false},
		{"building":23,"level":0,"cell":[140,33],"side":[-1,0],"state":"open","outer":true},
		{"building":24,"level":0,"cell":[132,41],"side":[-1,0],"state":"open","outer":true}
	],
	"windows": [
		{"building":16,"level":0,"cell":[79,13],"broken":false},
		{"building":17,"level":-1,"cell":[142,12],"broken":false},
		{"building":17,"level":-1,"cell":[156,12],"broken":false},
		{"building":17,"level":0,"cell":[139,12],"broken":false},
		{"building":17,"level":0,"cell":[148,12],"broken":false},
		{"building":17,"level":0,"cell":[158,12],"broken":false},
		{"building":17,"level":1,"cell":[142,12],"broken":false},
		{"building":17,"level":1,"cell":[156,12],"broken":false},
		{"building":17,"level":2,"cell":[142,12],"broken":false},
		{"building":17,"level":2,"cell":[156,12],"broken":false},
		{"building":18,"level":0,"cell":[102,13],"broken":false},
		{"building":18,"level":1,"cell":[94,13],"broken":false},
		{"building":18,"level":1,"cell":[102,13],"broken":false},
		{"building":19,"level":0,"cell":[44,13],"broken":false},
		{"building":19,"level":0,"cell":[52,13],"broken":false},
		{"building":19,"level":0,"cell":[61,13],"broken":false},
		{"building":20,"level":0,"cell":[37,13],"broken":false},
		{"building":20,"level":1,"cell":[31,13],"broken":false},
		{"building":20,"level":1,"cell":[37,13],"broken":false},
		{"building":21,"level":0,"cell":[17,13],"broken":false},
		{"building":22,"level":-1,"cell":[11,0],"broken":false},
		{"building":22,"level":-1,"cell":[20,0],"broken":false},
		{"building":22,"level":0,"cell":[11,0],"broken":false},
		{"building":23,"level":0,"cell":[145,29],"broken":false},
		{"building":23,"level":0,"cell":[155,29],"broken":false},
		{"building":24,"level":0,"cell":[137,38],"broken":false}
	],
	"stairs": [
		{"cell":[135,13],"low":-1,"high":0,"ladder":false},
		{"cell":[135,13],"low":0,"high":1,"ladder":false},
		{"cell":[135,13],"low":1,"high":2,"ladder":false},
		{"cell":[91,14],"low":0,"high":1,"ladder":false},
		{"cell":[29,14],"low":0,"high":1,"ladder":false},
		{"cell":[7,1],"low":-1,"high":0,"ladder":false}
	],
	"props": [
		{"kind":"plank_fence","rect":[30,38,6,1],"solid":"low","facing":0,"note":"비껴 받친 낮은 판자 울타리","level":0},
		{"kind":"farm_cart","rect":[70,30,2,4],"solid":"low","facing":0,"note":"운반하다 세워 둔 짐수레","level":0},
		{"kind":"crate_stack","rect":[56,41,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"bench","rect":[104,27,3,1],"solid":"low","facing":0,"note":"쉬어 가던 긴 의자","level":0},
		{"kind":"loom","rect":[130,26,3,2],"solid":"low","facing":0,"note":"무늬 없는 천을 짜던 베틀","level":0},
		{"kind":"crate_stack","rect":[135,26,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"barrel","rect":[138,27,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"shelf","rect":[142,26,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"handcart","rect":[161,27,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"snow_drift","rect":[112,12,3,2],"solid":"none","facing":0,"note":"바람이 모아 둔 눈","level":0},
		{"kind":"fieldstone_wall","rect":[0,23,4,1],"solid":"low","facing":0,"note":"글씨 없는 들돌 담 토막","level":0},
		{"kind":"farm_cart","rect":[106,22,4,2],"solid":"low","facing":0,"note":"운반하다 세워 둔 짐수레","level":0},
		{"kind":"bare_tree","rect":[44,1,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[49,4,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[56,2,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[61,6,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[94,2,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[100,5,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[109,1,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[112,6,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[146,39,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[154,41,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[163,38,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"bare_tree","rect":[166,44,1,1],"solid":"tree","facing":0,"note":"비뚤어진 무리의 헐벗은 나무","level":0},
		{"kind":"sack_pile","rect":[67,14,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"handcart","rect":[67,22,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"barrel","rect":[74,14,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"sack_pile","rect":[76,14,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"handcart","rect":[76,22,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"barrel","rect":[82,14,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"sack_pile","rect":[135,21,2,2],"solid":"none","facing":0,"note":"물자를 담은 자루","level":-1},
		{"kind":"shelf","rect":[136,13,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":-1},
		{"kind":"barrel","rect":[148,22,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":-1},
		{"kind":"sack_pile","rect":[151,13,2,2],"solid":"none","facing":0,"note":"물자를 담은 자루","level":-1},
		{"kind":"shelf","rect":[150,22,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":-1},
		{"kind":"barrel","rect":[162,13,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":-1},
		{"kind":"loom","rect":[136,13,3,2],"solid":"low","facing":0,"note":"무늬 없는 천을 짜던 베틀","level":0},
		{"kind":"sack_pile","rect":[141,13,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[140,15,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"handcart","rect":[135,22,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"crate_stack","rect":[135,20,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"sack_pile","rect":[141,21,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"loom","rect":[144,13,3,2],"solid":"low","facing":0,"note":"무늬 없는 천을 짜던 베틀","level":0},
		{"kind":"sack_pile","rect":[150,13,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[149,15,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"loom","rect":[144,20,3,2],"solid":"low","facing":0,"note":"무늬 없는 천을 짜던 베틀","level":0},
		{"kind":"sack_pile","rect":[150,20,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[147,20,1,2],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"desk","rect":[153,13,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0},
		{"kind":"shelf","rect":[154,15,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"loom","rect":[153,20,3,2],"solid":"low","facing":0,"note":"무늬 없는 천을 짜던 베틀","level":0},
		{"kind":"sack_pile","rect":[161,20,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[153,22,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"desk","rect":[135,22,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":1},
		{"kind":"loom","rect":[136,13,3,2],"solid":"none","facing":0,"note":"무늬 없는 천을 짜던 베틀","level":1},
		{"kind":"shelf","rect":[135,21,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"bed","rect":[150,13,2,1],"solid":"none","facing":0,"note":"숙직하는 이의 침대","level":1},
		{"kind":"bed","rect":[150,22,2,1],"solid":"none","facing":0,"note":"숙직하는 이의 침대","level":1},
		{"kind":"cold_stove","rect":[162,22,1,1],"solid":"none","facing":0,"note":"작게 식은 난로","level":1},
		{"kind":"loom","rect":[136,13,3,2],"solid":"none","facing":0,"note":"무늬 없는 천을 짜던 베틀","level":2},
		{"kind":"sack_pile","rect":[147,13,2,2],"solid":"none","facing":0,"note":"물자를 담은 자루","level":2},
		{"kind":"shelf","rect":[135,22,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":2},
		{"kind":"loom","rect":[150,13,3,2],"solid":"none","facing":0,"note":"무늬 없는 천을 짜던 베틀","level":2},
		{"kind":"sack_pile","rect":[150,21,2,2],"solid":"none","facing":0,"note":"물자를 담은 자루","level":2},
		{"kind":"shelf","rect":[152,22,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":2},
		{"kind":"sack_pile","rect":[92,14,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[91,22,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[96,14,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"sack_pile","rect":[99,14,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[99,22,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[103,21,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[91,22,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":1},
		{"kind":"shelf","rect":[92,14,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"shelf","rect":[99,22,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"barrel","rect":[99,14,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":1},
		{"kind":"crate_stack","rect":[99,15,2,2],"solid":"none","facing":0,"note":"종류별 물자를 담은 나무 상자","level":1},
		{"kind":"sack_pile","rect":[41,14,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[41,19,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[46,14,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"sack_pile","rect":[49,14,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[49,19,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[51,14,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"sack_pile","rect":[57,14,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[57,19,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[63,15,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"cold_stove","rect":[33,22,1,1],"solid":"low","facing":0,"note":"작게 식은 난로","level":0},
		{"kind":"shelf","rect":[30,22,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"barrel","rect":[33,14,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"sack_pile","rect":[35,14,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[35,22,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"bed","rect":[29,15,2,1],"solid":"none","facing":0,"note":"숙직하는 이의 침대","level":1},
		{"kind":"desk","rect":[32,22,2,1],"solid":"none","facing":0,"note":"장부를 펴던 책상","level":1},
		{"kind":"bed","rect":[35,22,2,1],"solid":"none","facing":0,"note":"숙직하는 이의 침대","level":1},
		{"kind":"shelf","rect":[35,14,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":1},
		{"kind":"sack_pile","rect":[5,14,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"handcart","rect":[11,14,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"barrel","rect":[12,22,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"sack_pile","rect":[15,14,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"handcart","rect":[14,22,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"barrel","rect":[20,22,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"sack_pile","rect":[7,4,2,2],"solid":"none","facing":0,"note":"물자를 담은 자루","level":-1},
		{"kind":"shelf","rect":[8,10,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":-1},
		{"kind":"barrel","rect":[14,10,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":-1},
		{"kind":"sack_pile","rect":[17,4,2,2],"solid":"none","facing":0,"note":"물자를 담은 자루","level":-1},
		{"kind":"shelf","rect":[16,10,3,1],"solid":"none","facing":0,"note":"물품을 나누어 둔 선반","level":-1},
		{"kind":"barrel","rect":[23,10,1,1],"solid":"none","facing":0,"note":"작업에 쓰던 통","level":-1},
		{"kind":"sack_pile","rect":[8,1,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"shelf","rect":[7,5,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[13,4,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"sack_pile","rect":[141,30,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"handcart","rect":[141,35,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"barrel","rect":[149,35,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"sack_pile","rect":[151,30,2,2],"solid":"low","facing":0,"note":"물자를 담은 자루","level":0},
		{"kind":"handcart","rect":[152,35,2,1],"solid":"low","facing":0,"note":"하역 문 곁 손수레","level":0},
		{"kind":"barrel","rect":[158,35,1,1],"solid":"low","facing":0,"note":"작업에 쓰던 통","level":0},
		{"kind":"shelf","rect":[133,39,3,1],"solid":"low","facing":0,"note":"물품을 나누어 둔 선반","level":0},
		{"kind":"crate_stack","rect":[139,39,2,2],"solid":"low","facing":0,"note":"종류별 물자를 담은 나무 상자","level":0},
		{"kind":"desk","rect":[133,40,2,1],"solid":"low","facing":0,"note":"장부를 펴던 책상","level":0}
	],
	"rooms": [
		{"building":16,"level":0,"rect":[67,14,8,9],"name":"돌담 우리 앞방","theme":"hay"},
		{"building":16,"level":0,"rect":[76,14,7,9],"name":"돌담 우리 뒷방","theme":"hay"},
		{"building":17,"level":-1,"rect":[135,13,14,10],"name":"방직 작업장 지하 앞방","theme":"weave"},
		{"building":17,"level":-1,"rect":[150,13,13,10],"name":"방직 작업장 지하 뒷방","theme":"weave"},
		{"building":17,"level":0,"rect":[135,13,8,3],"name":"방직 작업장 계량방","theme":"weave"},
		{"building":17,"level":0,"rect":[135,20,8,3],"name":"방직 작업장 하역방","theme":"weave"},
		{"building":17,"level":0,"rect":[144,13,8,3],"name":"방직 작업장 작업방","theme":"weave"},
		{"building":17,"level":0,"rect":[144,20,8,3],"name":"방직 작업장 재료방","theme":"weave"},
		{"building":17,"level":0,"rect":[153,13,10,3],"name":"방직 작업장 사무방","theme":"weave"},
		{"building":17,"level":0,"rect":[153,20,10,3],"name":"방직 작업장 안쪽 저장방","theme":"weave"},
		{"building":17,"level":1,"rect":[135,13,14,10],"name":"방직 작업장 위층 재단방","theme":"weave"},
		{"building":17,"level":1,"rect":[150,13,13,10],"name":"방직 작업장 위층 숙직방","theme":"weave"},
		{"building":17,"level":2,"rect":[135,13,14,10],"name":"방직 작업장 다락 앞방","theme":"weave"},
		{"building":17,"level":2,"rect":[150,13,13,10],"name":"방직 작업장 다락 뒷방","theme":"weave"},
		{"building":18,"level":0,"rect":[91,14,7,9],"name":"모직 곳간 앞방","theme":"cloth"},
		{"building":18,"level":0,"rect":[99,14,6,9],"name":"모직 곳간 뒷방","theme":"cloth"},
		{"building":18,"level":1,"rect":[91,14,7,9],"name":"모직 곳간 위층 앞방","theme":"cloth"},
		{"building":18,"level":1,"rect":[99,14,6,9],"name":"모직 곳간 위층 뒷방","theme":"cloth"},
		{"building":19,"level":0,"rect":[41,14,7,6],"name":"양모 헛간 선별방","theme":"cloth"},
		{"building":19,"level":0,"rect":[49,14,7,6],"name":"양모 헛간 건조방","theme":"cloth"},
		{"building":19,"level":0,"rect":[57,14,8,6],"name":"양모 헛간 포장방","theme":"cloth"},
		{"building":20,"level":0,"rect":[29,14,5,9],"name":"양치기 집 앞방","theme":"house"},
		{"building":20,"level":0,"rect":[35,14,4,9],"name":"양치기 집 뒷방","theme":"house"},
		{"building":20,"level":1,"rect":[29,14,5,9],"name":"양치기 집 위층 앞방","theme":"house"},
		{"building":20,"level":1,"rect":[35,14,4,9],"name":"양치기 집 위층 뒷방","theme":"house"},
		{"building":21,"level":0,"rect":[5,14,8,9],"name":"건초 헛간 앞방","theme":"hay"},
		{"building":21,"level":0,"rect":[14,14,7,9],"name":"건초 헛간 뒷방","theme":"hay"},
		{"building":22,"level":-1,"rect":[7,4,8,7],"name":"외딴 오두막 지하 통로 옆 저장방","theme":"cloth"},
		{"building":22,"level":-1,"rect":[16,4,8,7],"name":"외딴 오두막 지하 막다른 저장방","theme":"cloth"},
		{"building":22,"level":0,"rect":[7,1,8,5],"name":"외딴 오두막 작업방","theme":"cloth"},
		{"building":23,"level":0,"rect":[141,30,9,6],"name":"겨울 우리 헛간 앞방","theme":"hay"},
		{"building":23,"level":0,"rect":[151,30,8,6],"name":"겨울 우리 헛간 뒷방","theme":"hay"},
		{"building":24,"level":0,"rect":[133,39,8,5],"name":"농기구 헛간 작업방","theme":"tools"}
	],
	"containers": [
		{"id":"north_box_020","name":"양모 헛간 건조방 보관함","cell":[55,14],"building":19,"search":6,"items":["cloth","cloth"],"locked":false,"level":0,"searched":false},
		{"id":"north_box_026","name":"건초 헛간 앞방 보관함","cell":[5,22],"building":21,"search":6,"items":["cloth","cloth"],"locked":false,"level":0,"searched":false},
		{"id":"north_box_028","name":"외딴 오두막 지하 통로 옆 저장방 보관함","cell":[7,10],"building":22,"search":4,"items":[],"locked":false,"level":-1,"searched":false},
		{"id":"north_box_029","name":"외딴 오두막 막다른 물자 보관함","cell":[16,4],"building":22,"search":8,"items":["cloth","needle_thread"],"locked":false,"level":-1,"searched":false},
		{"id":"north_box_030","name":"외딴 오두막 작업방 보관함","cell":[14,1],"building":22,"search":4,"items":[],"locked":false,"level":0,"searched":false},
		{"id":"north_box_033","name":"농기구 헛간 작업방 보관함","cell":[133,43],"building":24,"search":6,"items":["cloth","cloth"],"locked":false,"level":0,"searched":false},
		{"id":"north_shallow","name":"운반 도중 내려둔 물자 보관함","cell":[55,39],"building":-1,"search":2,"items":["cloth"],"locked":false,"level":0,"searched":false}
	],
	"entries": [
		{"id":"북쪽 방직 길","cells":[[85,0],[86,0],[87,0],[88,0]],"gap":0.6},
		{"id":"서쪽 양모 길","cells":[[0,9],[0,10],[0,11]],"gap":0.6},
		{"id":"동쪽 겨울 우리 길","cells":[[169,8],[169,9],[169,10]],"gap":0.6}
	],
	"holes": [

	],
	"slots": [
		[23,24],
		[26,25],
		[85,24],
		[88,25],
		[111,24],
		[114,25],
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
const ENTRY_NAMES: Dictionary = {"west_road": "서쪽 길", "east_road": "동쪽 길", "south_farm": "남쪽 농장", "southwest_lane": "남서쪽 샛길", "manhole_01": "맨홀", "북쪽 방직 길": "북쪽 방직 길", "서쪽 양모 길": "서쪽 양모 길", "동쪽 겨울 우리 길": "동쪽 겨울 우리 길"}
const ENTRY_WEIGHTS: Dictionary = {"west_road": 1.0, "east_road": 1.0, "south_farm": 1.0, "southwest_lane": 0.5, "manhole_01": 0.3, "북쪽 방직 길": 1.0, "서쪽 양모 길": 1.0, "동쪽 겨울 우리 길": 1.0}
const FIRST_ENTRY: String = "west_road"


static func build() -> Dictionary:
	var data: Dictionary = _build_plain()
	data["entry_names"] = ENTRY_NAMES.duplicate()
	data["entry_weights"] = ENTRY_WEIGHTS.duplicate()
	data["first_entry"] = FIRST_ENTRY
	return data
