# 이 지도가 다른 판단을 만드는 것: 출입구가 똑같다. 한 계단실을 3층까지 오를지 1층만 훑고 옮길지 고른다.
# 위쪽의 판단: 식량이 아래쪽 목재보다 훨씬 많은 대신 자루와 궤가 무거워 여러 번 날라야 하고, 날라 오는 사람이 빠진 아래쪽 문 곁은 비어 있다.
extends RefCounted

const FieldGrid = preload("res://game/world/field_grid.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 180
const SOUTH_HEIGHT: int = 110
const HEIGHT: int = SOUTH_HEIGHT + 45
const PLACE_ID: String = "houses_02"

# 각 좌표는 이 지도의 독립 평면이다. 위층 장식은 충돌을 만들지 않는다.
const PLAN: Dictionary = {
	"number": 2,
	"width": 180,
	"height": 110,
	"judgment": "출입구가 똑같다. 한 계단실을 3층까지 오를지 1층만 훑고 옮길지 고른다.",
	"zones": [{"id":"A","name":"승강장 앞","rect":[0,0,180,30]},
		{"id":"B","name":"차고 뒤편","rect":[0,30,116,30]},
		{"id":"C","name":"긴 동 앞길","rect":[116,30,64,30]},
		{"id":"D","name":"차고 마당","rect":[0,60,58,50]},
		{"id":"E","name":"공동 마당","rect":[58,60,58,50]},
		{"id":"F","name":"동쪽 순환길","rect":[116,60,64,50]},
		{"id":"G","name":"남쪽 굽이","rect":[0,92,180,18]},
		{"id":"H","name":"동쪽 살림 동","rect":[140,4,40,26]}],
	"grounds": [{"rect":[74,10,6,28],"floor":1},
		{"rect":[42,34,116,5],"floor":1},
		{"rect":[48,34,5,60],"floor":1},
		{"rect":[48,88,132,5],"floor":1},
		{"rect":[120,88,5,22],"floor":1},
		{"rect":[134,38,5,55],"floor":1},
		{"rect":[154,38,5,36],"floor":1},
		{"rect":[134,55,29,5],"floor":1},
		{"rect":[134,67,29,5],"floor":1},
		{"rect":[0,76,52,4],"floor":1},
		{"rect":[18,38,4,42],"floor":1},
		{"rect":[159,44,21,4],"floor":1},
		{"rect":[170,94,10,4],"floor":1},
		{"rect":[56,60,58,27],"floor":0},
		{"rect":[100,10,28,20],"floor":5},
		{"rect":[12,23,6,4],"floor":5}],
	"buildings": [{"name":"동 가 긴 날개","rect":[56,43,56,16],"top":4,"basement":true,"role":"home","main":true,"id":0},
		{"name":"동 가 꺾인 날개","rect":[116,43,16,40],"top":4,"basement":false,"role":"home","mode":"vertical","id":1},
		{"name":"동 나","rect":[136,12,36,18],"top":4,"basement":false,"role":"home","mode":"vertical","id":2},
		{"name":"동 다","rect":[136,72,34,16],"top":4,"basement":true,"role":"home","id":3},
		{"name":"동 라","rect":[64,94,44,14],"top":4,"basement":false,"role":"home","upper_rect":[64,94,22,14],"id":4},
		{"name":"단지 식료품점","rect":[138,95,30,14],"top":2,"basement":false,"role":"shop","stock":["display_shelf","shop_counter","tin_crate"],"id":5},
		{"name":"관리동","rect":[60,20,14,10],"top":1,"basement":false,"role":"shed","id":6},
		{"name":"차고","rect":[6,42,12,8],"top":1,"basement":false,"role":"shed","id":7},
		{"name":"차고","rect":[26,46,12,8],"top":1,"basement":false,"role":"shed","id":8},
		{"name":"차고","rect":[8,61,12,8],"top":1,"basement":false,"role":"shed","id":9},
		{"name":"차고","rect":[28,65,12,8],"top":1,"basement":false,"role":"shed","id":10},
		{"name":"세탁 보일러동","rect":[24,84,16,12],"top":1,"basement":false,"role":"shed","id":11},
		{"name":"노인정","rect":[62,64,12,10],"top":1,"basement":false,"role":"shed","id":12},
		{"name":"공동 목공 작업장","rect":[80,66,20,12],"top":1,"basement":false,"role":"shed","stock":["door_pile","desk","firewood_pile"],"id":13},
		{"name":"자전거 보관소","rect":[80,20,14,8],"top":1,"basement":false,"role":"shed","id":14},
		{"name":"장작 헛간","rect":[42,22,12,8],"top":1,"basement":false,"role":"shed","id":15}],
	"entries": [{"id":"west_path","cells":[[0,76],[0,77],[0,78],[0,79]],"gap":2},
		{"id":"south_road","cells":[[120,109],[121,109],[122,109],[123,109]],"gap":0.6},
		{"id":"east_path","cells":[[179,44],[179,45],[179,46],[179,47]],"gap":0.6},
		{"id":"east_lower","cells":[[179,94],[179,95],[179,96],[179,97]],"gap":2}],
	"holes": [{"id":"manhole_01","cell":[60,62],"name":"마당 맨홀","level":0},
		{"id":"manhole_02","cell":[50,90],"name":"굽이 맨홀","level":0},
		{"id":"manhole_03","cell":[22,78],"name":"차고 샛길 맨홀","level":0},
		{"id":"manhole_04","cell":[124,96],"name":"남동 굽이 맨홀","level":0}],
	"barricades": [[55,28],[57,28],[75,27],[77,27],[95,26],[97,26]],
	"deepBuildings": [0,3],
	"deepLevels": [2,-1],
	"assumptions": ["긴 날개와 꺾인 날개 사이에는 네 칸의 연결 마당을 남겼다.","동 라의 동쪽은 일층만 남기고 서쪽 절반에만 위층과 사층 겉모양을 올렸다.","남쪽 진입점은 꺾인 순환길의 남단에 맞췄다."],
	"tx": 16,
	"band": [0,4,116,26],
	"shells": [{"building":0,"level":0,"rect":[56,43,56,16]},
		{"building":0,"level":1,"rect":[56,43,56,16]},
		{"building":0,"level":2,"rect":[56,43,56,16]},
		{"building":0,"level":-1,"rect":[56,43,56,16]},
		{"building":1,"level":0,"rect":[116,43,16,40]},
		{"building":1,"level":1,"rect":[116,43,16,40]},
		{"building":1,"level":2,"rect":[116,43,16,40]},
		{"building":2,"level":0,"rect":[136,12,36,18]},
		{"building":2,"level":1,"rect":[136,12,36,18]},
		{"building":2,"level":2,"rect":[136,12,36,18]},
		{"building":3,"level":0,"rect":[136,72,34,16]},
		{"building":3,"level":1,"rect":[136,72,34,16]},
		{"building":3,"level":2,"rect":[136,72,34,16]},
		{"building":3,"level":-1,"rect":[136,72,34,16]},
		{"building":4,"level":0,"rect":[64,94,44,14]},
		{"building":4,"level":1,"rect":[64,94,22,14]},
		{"building":4,"level":2,"rect":[64,94,22,14]},
		{"building":5,"level":0,"rect":[138,95,30,14]},
		{"building":5,"level":1,"rect":[138,95,30,14]},
		{"building":6,"level":0,"rect":[60,20,14,10]},
		{"building":7,"level":0,"rect":[6,42,12,8]},
		{"building":8,"level":0,"rect":[26,46,12,8]},
		{"building":9,"level":0,"rect":[8,61,12,8]},
		{"building":10,"level":0,"rect":[28,65,12,8]},
		{"building":11,"level":0,"rect":[24,84,16,12]},
		{"building":12,"level":0,"rect":[62,64,12,10]},
		{"building":13,"level":0,"rect":[80,66,20,12]},
		{"building":14,"level":0,"rect":[80,20,14,8]},
		{"building":15,"level":0,"rect":[42,22,12,8]}],
	"walls": [{"building":0,"level":0,"rect":[57,49,54,1]},
		{"building":0,"level":0,"rect":[57,52,54,1]},
		{"building":0,"level":0,"rect":[66,44,1,5]},
		{"building":0,"level":0,"rect":[75,44,1,5]},
		{"building":0,"level":0,"rect":[84,44,1,5]},
		{"building":0,"level":0,"rect":[93,44,1,5]},
		{"building":0,"level":0,"rect":[102,44,1,5]},
		{"building":0,"level":0,"rect":[66,53,1,5]},
		{"building":0,"level":0,"rect":[75,53,1,5]},
		{"building":0,"level":0,"rect":[84,53,1,5]},
		{"building":0,"level":0,"rect":[93,53,1,5]},
		{"building":0,"level":0,"rect":[102,53,1,5]},
		{"building":0,"level":1,"rect":[57,49,54,1]},
		{"building":0,"level":1,"rect":[57,52,54,1]},
		{"building":0,"level":1,"rect":[66,44,1,5]},
		{"building":0,"level":1,"rect":[75,44,1,5]},
		{"building":0,"level":1,"rect":[84,44,1,5]},
		{"building":0,"level":1,"rect":[93,44,1,5]},
		{"building":0,"level":1,"rect":[102,44,1,5]},
		{"building":0,"level":1,"rect":[66,53,1,5]},
		{"building":0,"level":1,"rect":[75,53,1,5]},
		{"building":0,"level":1,"rect":[84,53,1,5]},
		{"building":0,"level":1,"rect":[93,53,1,5]},
		{"building":0,"level":1,"rect":[102,53,1,5]},
		{"building":0,"level":2,"rect":[57,49,54,1]},
		{"building":0,"level":2,"rect":[57,52,54,1]},
		{"building":0,"level":2,"rect":[66,44,1,5]},
		{"building":0,"level":2,"rect":[75,44,1,5]},
		{"building":0,"level":2,"rect":[84,44,1,5]},
		{"building":0,"level":2,"rect":[93,44,1,5]},
		{"building":0,"level":2,"rect":[102,44,1,5]},
		{"building":0,"level":2,"rect":[66,53,1,5]},
		{"building":0,"level":2,"rect":[75,53,1,5]},
		{"building":0,"level":2,"rect":[84,53,1,5]},
		{"building":0,"level":2,"rect":[93,53,1,5]},
		{"building":0,"level":2,"rect":[102,53,1,5]},
		{"building":0,"level":-1,"rect":[57,49,54,1]},
		{"building":0,"level":-1,"rect":[57,52,54,1]},
		{"building":0,"level":-1,"rect":[66,44,1,5]},
		{"building":0,"level":-1,"rect":[75,44,1,5]},
		{"building":0,"level":-1,"rect":[84,44,1,5]},
		{"building":0,"level":-1,"rect":[93,44,1,5]},
		{"building":0,"level":-1,"rect":[102,44,1,5]},
		{"building":0,"level":-1,"rect":[66,53,1,5]},
		{"building":0,"level":-1,"rect":[75,53,1,5]},
		{"building":0,"level":-1,"rect":[84,53,1,5]},
		{"building":0,"level":-1,"rect":[93,53,1,5]},
		{"building":0,"level":-1,"rect":[102,53,1,5]},
		{"building":1,"level":0,"rect":[122,44,1,38]},
		{"building":1,"level":0,"rect":[125,44,1,38]},
		{"building":1,"level":0,"rect":[117,53,5,1]},
		{"building":1,"level":0,"rect":[117,63,5,1]},
		{"building":1,"level":0,"rect":[117,73,5,1]},
		{"building":1,"level":0,"rect":[126,53,5,1]},
		{"building":1,"level":0,"rect":[126,63,5,1]},
		{"building":1,"level":0,"rect":[126,73,5,1]},
		{"building":1,"level":1,"rect":[122,44,1,38]},
		{"building":1,"level":1,"rect":[125,44,1,38]},
		{"building":1,"level":1,"rect":[117,53,5,1]},
		{"building":1,"level":1,"rect":[117,63,5,1]},
		{"building":1,"level":1,"rect":[117,73,5,1]},
		{"building":1,"level":1,"rect":[126,53,5,1]},
		{"building":1,"level":1,"rect":[126,63,5,1]},
		{"building":1,"level":1,"rect":[126,73,5,1]},
		{"building":1,"level":2,"rect":[122,44,1,38]},
		{"building":1,"level":2,"rect":[125,44,1,38]},
		{"building":1,"level":2,"rect":[117,53,5,1]},
		{"building":1,"level":2,"rect":[117,63,5,1]},
		{"building":1,"level":2,"rect":[117,73,5,1]},
		{"building":1,"level":2,"rect":[126,53,5,1]},
		{"building":1,"level":2,"rect":[126,63,5,1]},
		{"building":1,"level":2,"rect":[126,73,5,1]},
		{"building":2,"level":0,"rect":[152,13,1,16]},
		{"building":2,"level":0,"rect":[155,13,1,16]},
		{"building":2,"level":0,"rect":[144,13,1,8]},
		{"building":2,"level":0,"rect":[137,21,15,1]},
		{"building":2,"level":0,"rect":[144,22,1,7]},
		{"building":2,"level":0,"rect":[163,13,1,8]},
		{"building":2,"level":0,"rect":[156,21,15,1]},
		{"building":2,"level":0,"rect":[163,22,1,7]},
		{"building":2,"level":1,"rect":[152,13,1,16]},
		{"building":2,"level":1,"rect":[155,13,1,16]},
		{"building":2,"level":1,"rect":[144,13,1,8]},
		{"building":2,"level":1,"rect":[137,21,15,1]},
		{"building":2,"level":1,"rect":[144,22,1,7]},
		{"building":2,"level":1,"rect":[163,13,1,8]},
		{"building":2,"level":1,"rect":[156,21,15,1]},
		{"building":2,"level":1,"rect":[163,22,1,7]},
		{"building":2,"level":2,"rect":[152,13,1,16]},
		{"building":2,"level":2,"rect":[155,13,1,16]},
		{"building":2,"level":2,"rect":[144,13,1,8]},
		{"building":2,"level":2,"rect":[137,21,15,1]},
		{"building":2,"level":2,"rect":[144,22,1,7]},
		{"building":2,"level":2,"rect":[163,13,1,8]},
		{"building":2,"level":2,"rect":[156,21,15,1]},
		{"building":2,"level":2,"rect":[163,22,1,7]},
		{"building":3,"level":0,"rect":[137,78,32,1]},
		{"building":3,"level":0,"rect":[137,81,32,1]},
		{"building":3,"level":0,"rect":[145,73,1,5]},
		{"building":3,"level":0,"rect":[153,73,1,5]},
		{"building":3,"level":0,"rect":[161,73,1,5]},
		{"building":3,"level":0,"rect":[145,82,1,5]},
		{"building":3,"level":0,"rect":[153,82,1,5]},
		{"building":3,"level":0,"rect":[161,82,1,5]},
		{"building":3,"level":1,"rect":[137,78,32,1]},
		{"building":3,"level":1,"rect":[137,81,32,1]},
		{"building":3,"level":1,"rect":[145,73,1,5]},
		{"building":3,"level":1,"rect":[153,73,1,5]},
		{"building":3,"level":1,"rect":[161,73,1,5]},
		{"building":3,"level":1,"rect":[145,82,1,5]},
		{"building":3,"level":1,"rect":[153,82,1,5]},
		{"building":3,"level":1,"rect":[161,82,1,5]},
		{"building":3,"level":2,"rect":[137,78,32,1]},
		{"building":3,"level":2,"rect":[137,81,32,1]},
		{"building":3,"level":2,"rect":[145,73,1,5]},
		{"building":3,"level":2,"rect":[153,73,1,5]},
		{"building":3,"level":2,"rect":[161,73,1,5]},
		{"building":3,"level":2,"rect":[145,82,1,5]},
		{"building":3,"level":2,"rect":[153,82,1,5]},
		{"building":3,"level":2,"rect":[161,82,1,5]},
		{"building":3,"level":-1,"rect":[137,78,32,1]},
		{"building":3,"level":-1,"rect":[137,81,32,1]},
		{"building":3,"level":-1,"rect":[145,73,1,5]},
		{"building":3,"level":-1,"rect":[153,73,1,5]},
		{"building":3,"level":-1,"rect":[161,73,1,5]},
		{"building":3,"level":-1,"rect":[145,82,1,5]},
		{"building":3,"level":-1,"rect":[153,82,1,5]},
		{"building":3,"level":-1,"rect":[161,82,1,5]},
		{"building":4,"level":0,"rect":[65,99,42,1]},
		{"building":4,"level":0,"rect":[65,102,42,1]},
		{"building":4,"level":0,"rect":[73,95,1,4]},
		{"building":4,"level":0,"rect":[82,95,1,4]},
		{"building":4,"level":0,"rect":[91,95,1,4]},
		{"building":4,"level":0,"rect":[99,95,1,4]},
		{"building":4,"level":0,"rect":[73,103,1,4]},
		{"building":4,"level":0,"rect":[82,103,1,4]},
		{"building":4,"level":0,"rect":[91,103,1,4]},
		{"building":4,"level":0,"rect":[99,103,1,4]},
		{"building":4,"level":1,"rect":[65,99,20,1]},
		{"building":4,"level":1,"rect":[65,102,20,1]},
		{"building":4,"level":1,"rect":[75,95,1,4]},
		{"building":4,"level":1,"rect":[75,103,1,4]},
		{"building":4,"level":2,"rect":[65,99,20,1]},
		{"building":4,"level":2,"rect":[65,102,20,1]},
		{"building":4,"level":2,"rect":[75,95,1,4]},
		{"building":4,"level":2,"rect":[75,103,1,4]},
		{"building":5,"level":0,"rect":[139,99,28,1]},
		{"building":5,"level":0,"rect":[139,104,28,1]},
		{"building":5,"level":0,"rect":[148,96,1,3]},
		{"building":5,"level":0,"rect":[158,96,1,3]},
		{"building":5,"level":0,"rect":[148,105,1,3]},
		{"building":5,"level":0,"rect":[158,105,1,3]},
		{"building":5,"level":1,"rect":[139,99,28,1]},
		{"building":5,"level":1,"rect":[139,104,28,1]},
		{"building":5,"level":1,"rect":[148,96,1,3]},
		{"building":5,"level":1,"rect":[158,96,1,3]},
		{"building":5,"level":1,"rect":[148,105,1,3]},
		{"building":5,"level":1,"rect":[158,105,1,3]},
		{"building":6,"level":0,"rect":[67,21,1,8]},
		{"building":7,"level":0,"rect":[12,43,1,6]},
		{"building":8,"level":0,"rect":[32,47,1,6]},
		{"building":9,"level":0,"rect":[14,62,1,6]},
		{"building":10,"level":0,"rect":[34,66,1,6]},
		{"building":11,"level":0,"rect":[25,88,14,1]},
		{"building":11,"level":0,"rect":[25,91,14,1]},
		{"building":12,"level":0,"rect":[68,65,1,8]},
		{"building":13,"level":0,"rect":[81,70,18,1]},
		{"building":13,"level":0,"rect":[81,73,18,1]},
		{"building":13,"level":0,"rect":[90,67,1,3]},
		{"building":13,"level":0,"rect":[90,74,1,3]},
		{"building":14,"level":0,"rect":[87,21,1,6]},
		{"building":15,"level":0,"rect":[48,23,1,6]}],
	"doors": [{"cell":[61,49],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[71,49],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[80,49],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[89,49],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[98,49],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[107,49],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[61,52],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[71,52],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[80,52],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[89,52],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[98,52],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[107,52],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[56,50],"building":0,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[111,50],"building":0,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[61,49],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[71,49],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[80,49],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[89,49],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[98,49],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[107,49],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[61,52],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[71,52],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[80,52],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[89,52],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[98,52],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[107,52],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[61,49],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[71,49],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[80,49],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[89,49],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[98,49],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[107,49],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[61,52],"building":0,"level":2,"state":"closed","normal":[0,1],"external":false},
		{"cell":[71,52],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[80,52],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[89,52],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[98,52],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[107,52],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[61,49],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[71,49],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[80,49],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[89,49],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[98,49],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[107,49],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[61,52],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[71,52],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[80,52],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[89,52],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[98,52],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[107,52],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[122,48],"building":1,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[122,58],"building":1,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[122,68],"building":1,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[122,78],"building":1,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[125,48],"building":1,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[125,58],"building":1,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[125,68],"building":1,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[125,78],"building":1,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[123,43],"building":1,"level":0,"state":"open","normal":[0,-1],"external":true},
		{"cell":[123,82],"building":1,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[122,48],"building":1,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[122,58],"building":1,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[122,68],"building":1,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[122,78],"building":1,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[125,48],"building":1,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[125,58],"building":1,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[125,68],"building":1,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[125,78],"building":1,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[122,48],"building":1,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[122,58],"building":1,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[122,68],"building":1,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[122,78],"building":1,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[125,48],"building":1,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[125,58],"building":1,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[125,68],"building":1,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[125,78],"building":1,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[144,17],"building":2,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[152,17],"building":2,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[144,25],"building":2,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[152,25],"building":2,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[163,17],"building":2,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[155,17],"building":2,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[163,25],"building":2,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[155,25],"building":2,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[153,12],"building":2,"level":0,"state":"open","normal":[0,-1],"external":true},
		{"cell":[153,29],"building":2,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[144,17],"building":2,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[152,17],"building":2,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[144,25],"building":2,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[152,25],"building":2,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[163,17],"building":2,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[155,17],"building":2,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[163,25],"building":2,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[155,25],"building":2,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[144,17],"building":2,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[152,17],"building":2,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[144,25],"building":2,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[152,25],"building":2,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[163,17],"building":2,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[155,17],"building":2,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[163,25],"building":2,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[155,25],"building":2,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[141,78],"building":3,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[149,78],"building":3,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[157,78],"building":3,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[165,78],"building":3,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[141,81],"building":3,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[149,81],"building":3,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[157,81],"building":3,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[165,81],"building":3,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[136,79],"building":3,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[169,79],"building":3,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[141,78],"building":3,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[149,78],"building":3,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[157,78],"building":3,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[165,78],"building":3,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[141,81],"building":3,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[149,81],"building":3,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[157,81],"building":3,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[165,81],"building":3,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[141,78],"building":3,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[149,78],"building":3,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[157,78],"building":3,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[165,78],"building":3,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[141,81],"building":3,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[149,81],"building":3,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[157,81],"building":3,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[165,81],"building":3,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[141,78],"building":3,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[149,78],"building":3,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[157,78],"building":3,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[165,78],"building":3,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[141,81],"building":3,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[149,81],"building":3,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[157,81],"building":3,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[165,81],"building":3,"level":-1,"state":"closed","normal":[0,1],"external":false},
		{"cell":[69,99],"building":4,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[78,99],"building":4,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[87,99],"building":4,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[95,99],"building":4,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[103,99],"building":4,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[69,102],"building":4,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[78,102],"building":4,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[87,102],"building":4,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[95,102],"building":4,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[103,102],"building":4,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[64,100],"building":4,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[107,100],"building":4,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[70,99],"building":4,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[80,99],"building":4,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[70,102],"building":4,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[80,102],"building":4,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[70,99],"building":4,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[80,99],"building":4,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[70,102],"building":4,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[80,102],"building":4,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[143,99],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[153,99],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[163,99],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[143,104],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[153,104],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[163,104],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[138,100],"building":5,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[167,100],"building":5,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[143,99],"building":5,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[153,99],"building":5,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[163,99],"building":5,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[143,104],"building":5,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[153,104],"building":5,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[163,104],"building":5,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[67,25],"building":6,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[60,25],"building":6,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[73,25],"building":6,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[12,46],"building":7,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[6,46],"building":7,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[17,46],"building":7,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[32,50],"building":8,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[26,50],"building":8,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[37,50],"building":8,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[14,65],"building":9,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[8,65],"building":9,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[19,65],"building":9,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[34,69],"building":10,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[28,69],"building":10,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[39,69],"building":10,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[32,88],"building":11,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[32,91],"building":11,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[24,89],"building":11,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[39,89],"building":11,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[68,69],"building":12,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[62,69],"building":12,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[73,69],"building":12,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[85,70],"building":13,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[95,70],"building":13,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[85,73],"building":13,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[95,73],"building":13,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[80,71],"building":13,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[99,71],"building":13,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[87,24],"building":14,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[80,24],"building":14,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[93,24],"building":14,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[48,26],"building":15,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[42,26],"building":15,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[53,26],"building":15,"level":0,"state":"open","normal":[1,0],"external":true}],
	"windows": [{"cell":[59,43],"building":0,"level":0},
		{"cell":[108,58],"building":0,"level":0},
		{"cell":[59,43],"building":0,"level":1},
		{"cell":[108,58],"building":0,"level":1},
		{"cell":[59,43],"building":0,"level":2},
		{"cell":[108,58],"building":0,"level":2},
		{"cell":[59,43],"building":0,"level":-1},
		{"cell":[108,58],"building":0,"level":-1},
		{"cell":[116,46],"building":1,"level":0},
		{"cell":[131,79],"building":1,"level":0},
		{"cell":[116,46],"building":1,"level":1},
		{"cell":[131,79],"building":1,"level":1},
		{"cell":[116,46],"building":1,"level":2},
		{"cell":[131,79],"building":1,"level":2},
		{"cell":[136,15],"building":2,"level":0},
		{"cell":[171,26],"building":2,"level":0},
		{"cell":[136,15],"building":2,"level":1},
		{"cell":[171,26],"building":2,"level":1},
		{"cell":[136,15],"building":2,"level":2},
		{"cell":[171,26],"building":2,"level":2},
		{"cell":[139,72],"building":3,"level":0},
		{"cell":[166,87],"building":3,"level":0},
		{"cell":[139,72],"building":3,"level":1},
		{"cell":[166,87],"building":3,"level":1},
		{"cell":[139,72],"building":3,"level":2},
		{"cell":[166,87],"building":3,"level":2},
		{"cell":[139,72],"building":3,"level":-1},
		{"cell":[166,87],"building":3,"level":-1},
		{"cell":[67,94],"building":4,"level":0},
		{"cell":[104,107],"building":4,"level":0},
		{"cell":[67,94],"building":4,"level":1},
		{"cell":[82,107],"building":4,"level":1},
		{"cell":[67,94],"building":4,"level":2},
		{"cell":[82,107],"building":4,"level":2},
		{"cell":[141,95],"building":5,"level":0},
		{"cell":[164,108],"building":5,"level":0},
		{"cell":[141,95],"building":5,"level":1},
		{"cell":[164,108],"building":5,"level":1},
		{"cell":[62,20],"building":6,"level":0},
		{"cell":[8,42],"building":7,"level":0},
		{"cell":[28,46],"building":8,"level":0},
		{"cell":[10,61],"building":9,"level":0},
		{"cell":[30,65],"building":10,"level":0},
		{"cell":[27,84],"building":11,"level":0},
		{"cell":[36,95],"building":11,"level":0},
		{"cell":[64,64],"building":12,"level":0},
		{"cell":[83,66],"building":13,"level":0},
		{"cell":[96,77],"building":13,"level":0},
		{"cell":[82,20],"building":14,"level":0},
		{"cell":[44,22],"building":15,"level":0}],
	"stairs": [{"cell":[74,50],"low":-1,"high":0,"ladder":false},
		{"cell":[74,50],"low":0,"high":1,"ladder":false},
		{"cell":[74,50],"low":1,"high":2,"ladder":false},
		{"cell":[93,51],"low":-1,"high":0,"ladder":false},
		{"cell":[93,51],"low":0,"high":1,"ladder":false},
		{"cell":[93,51],"low":1,"high":2,"ladder":false},
		{"cell":[123,45],"low":0,"high":1,"ladder":false},
		{"cell":[123,45],"low":1,"high":2,"ladder":false},
		{"cell":[124,80],"low":0,"high":1,"ladder":false},
		{"cell":[124,80],"low":1,"high":2,"ladder":false},
		{"cell":[153,14],"low":0,"high":1,"ladder":false},
		{"cell":[153,14],"low":1,"high":2,"ladder":false},
		{"cell":[154,27],"low":0,"high":1,"ladder":false},
		{"cell":[154,27],"low":1,"high":2,"ladder":false},
		{"cell":[138,79],"low":-1,"high":0,"ladder":false},
		{"cell":[138,79],"low":0,"high":1,"ladder":false},
		{"cell":[138,79],"low":1,"high":2,"ladder":false},
		{"cell":[167,80],"low":-1,"high":0,"ladder":false},
		{"cell":[167,80],"low":0,"high":1,"ladder":false},
		{"cell":[167,80],"low":1,"high":2,"ladder":false},
		{"cell":[66,100],"low":0,"high":1,"ladder":false},
		{"cell":[66,100],"low":1,"high":2,"ladder":false},
		{"cell":[140,100],"low":0,"high":1,"ladder":false}],
	"rooms": [{"building":0,"level":0,"rect":[57,44,9,5],"use":"안방"},
		{"building":0,"level":0,"rect":[67,44,8,5],"use":"부엌"},
		{"building":0,"level":0,"rect":[76,44,8,5],"use":"안방"},
		{"building":0,"level":0,"rect":[85,44,8,5],"use":"부엌"},
		{"building":0,"level":0,"rect":[94,44,8,5],"use":"안방"},
		{"building":0,"level":0,"rect":[103,44,8,5],"use":"부엌"},
		{"building":0,"level":0,"rect":[57,53,9,5],"use":"안방"},
		{"building":0,"level":0,"rect":[67,53,8,5],"use":"부엌"},
		{"building":0,"level":0,"rect":[76,53,8,5],"use":"안방"},
		{"building":0,"level":0,"rect":[85,53,8,5],"use":"부엌"},
		{"building":0,"level":0,"rect":[94,53,8,5],"use":"안방"},
		{"building":0,"level":0,"rect":[103,53,8,5],"use":"부엌"},
		{"building":0,"level":1,"rect":[57,44,9,5],"use":"안방"},
		{"building":0,"level":1,"rect":[67,44,8,5],"use":"부엌"},
		{"building":0,"level":1,"rect":[76,44,8,5],"use":"안방"},
		{"building":0,"level":1,"rect":[85,44,8,5],"use":"부엌"},
		{"building":0,"level":1,"rect":[94,44,8,5],"use":"안방"},
		{"building":0,"level":1,"rect":[103,44,8,5],"use":"부엌"},
		{"building":0,"level":1,"rect":[57,53,9,5],"use":"안방"},
		{"building":0,"level":1,"rect":[67,53,8,5],"use":"부엌"},
		{"building":0,"level":1,"rect":[76,53,8,5],"use":"안방"},
		{"building":0,"level":1,"rect":[85,53,8,5],"use":"부엌"},
		{"building":0,"level":1,"rect":[94,53,8,5],"use":"안방"},
		{"building":0,"level":1,"rect":[103,53,8,5],"use":"부엌"},
		{"building":0,"level":2,"rect":[57,44,9,5],"use":"안방"},
		{"building":0,"level":2,"rect":[67,44,8,5],"use":"부엌"},
		{"building":0,"level":2,"rect":[76,44,8,5],"use":"안방"},
		{"building":0,"level":2,"rect":[85,44,8,5],"use":"부엌"},
		{"building":0,"level":2,"rect":[94,44,8,5],"use":"안방"},
		{"building":0,"level":2,"rect":[103,44,8,5],"use":"부엌"},
		{"building":0,"level":2,"rect":[57,53,9,5],"use":"안방"},
		{"building":0,"level":2,"rect":[67,53,8,5],"use":"부엌"},
		{"building":0,"level":2,"rect":[76,53,8,5],"use":"안방"},
		{"building":0,"level":2,"rect":[85,53,8,5],"use":"부엌"},
		{"building":0,"level":2,"rect":[94,53,8,5],"use":"안방"},
		{"building":0,"level":2,"rect":[103,53,8,5],"use":"부엌"},
		{"building":0,"level":-1,"rect":[57,44,9,5],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[67,44,8,5],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[76,44,8,5],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[85,44,8,5],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[94,44,8,5],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[103,44,8,5],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[57,53,9,5],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[67,53,8,5],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[76,53,8,5],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[85,53,8,5],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[94,53,8,5],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[103,53,8,5],"use":"저장 칸"},
		{"building":1,"level":0,"rect":[117,44,5,9],"use":"안방"},
		{"building":1,"level":0,"rect":[117,54,5,9],"use":"부엌"},
		{"building":1,"level":0,"rect":[117,64,5,9],"use":"안방"},
		{"building":1,"level":0,"rect":[117,74,5,8],"use":"부엌"},
		{"building":1,"level":0,"rect":[126,44,5,9],"use":"안방"},
		{"building":1,"level":0,"rect":[126,54,5,9],"use":"부엌"},
		{"building":1,"level":0,"rect":[126,64,5,9],"use":"안방"},
		{"building":1,"level":0,"rect":[126,74,5,8],"use":"부엌"},
		{"building":1,"level":1,"rect":[117,44,5,9],"use":"안방"},
		{"building":1,"level":1,"rect":[117,54,5,9],"use":"부엌"},
		{"building":1,"level":1,"rect":[117,64,5,9],"use":"안방"},
		{"building":1,"level":1,"rect":[117,74,5,8],"use":"부엌"},
		{"building":1,"level":1,"rect":[126,44,5,9],"use":"안방"},
		{"building":1,"level":1,"rect":[126,54,5,9],"use":"부엌"},
		{"building":1,"level":1,"rect":[126,64,5,9],"use":"안방"},
		{"building":1,"level":1,"rect":[126,74,5,8],"use":"부엌"},
		{"building":1,"level":2,"rect":[117,44,5,9],"use":"안방"},
		{"building":1,"level":2,"rect":[117,54,5,9],"use":"부엌"},
		{"building":1,"level":2,"rect":[117,64,5,9],"use":"안방"},
		{"building":1,"level":2,"rect":[117,74,5,8],"use":"부엌"},
		{"building":1,"level":2,"rect":[126,44,5,9],"use":"안방"},
		{"building":1,"level":2,"rect":[126,54,5,9],"use":"부엌"},
		{"building":1,"level":2,"rect":[126,64,5,9],"use":"안방"},
		{"building":1,"level":2,"rect":[126,74,5,8],"use":"부엌"},
		{"building":2,"level":0,"rect":[137,13,7,8],"use":"부엌"},
		{"building":2,"level":0,"rect":[145,13,7,8],"use":"안방"},
		{"building":2,"level":0,"rect":[137,22,7,7],"use":"부엌"},
		{"building":2,"level":0,"rect":[145,22,7,7],"use":"안방"},
		{"building":2,"level":0,"rect":[156,13,7,8],"use":"부엌"},
		{"building":2,"level":0,"rect":[164,13,7,8],"use":"안방"},
		{"building":2,"level":0,"rect":[156,22,7,7],"use":"부엌"},
		{"building":2,"level":0,"rect":[164,22,7,7],"use":"안방"},
		{"building":2,"level":1,"rect":[137,13,7,8],"use":"부엌"},
		{"building":2,"level":1,"rect":[145,13,7,8],"use":"안방"},
		{"building":2,"level":1,"rect":[137,22,7,7],"use":"부엌"},
		{"building":2,"level":1,"rect":[145,22,7,7],"use":"안방"},
		{"building":2,"level":1,"rect":[156,13,7,8],"use":"부엌"},
		{"building":2,"level":1,"rect":[164,13,7,8],"use":"안방"},
		{"building":2,"level":1,"rect":[156,22,7,7],"use":"부엌"},
		{"building":2,"level":1,"rect":[164,22,7,7],"use":"안방"},
		{"building":2,"level":2,"rect":[137,13,7,8],"use":"부엌"},
		{"building":2,"level":2,"rect":[145,13,7,8],"use":"안방"},
		{"building":2,"level":2,"rect":[137,22,7,7],"use":"부엌"},
		{"building":2,"level":2,"rect":[145,22,7,7],"use":"안방"},
		{"building":2,"level":2,"rect":[156,13,7,8],"use":"부엌"},
		{"building":2,"level":2,"rect":[164,13,7,8],"use":"안방"},
		{"building":2,"level":2,"rect":[156,22,7,7],"use":"부엌"},
		{"building":2,"level":2,"rect":[164,22,7,7],"use":"안방"},
		{"building":3,"level":0,"rect":[137,73,8,5],"use":"안방"},
		{"building":3,"level":0,"rect":[146,73,7,5],"use":"부엌"},
		{"building":3,"level":0,"rect":[154,73,7,5],"use":"안방"},
		{"building":3,"level":0,"rect":[162,73,7,5],"use":"부엌"},
		{"building":3,"level":0,"rect":[137,82,8,5],"use":"안방"},
		{"building":3,"level":0,"rect":[146,82,7,5],"use":"부엌"},
		{"building":3,"level":0,"rect":[154,82,7,5],"use":"안방"},
		{"building":3,"level":0,"rect":[162,82,7,5],"use":"부엌"},
		{"building":3,"level":1,"rect":[137,73,8,5],"use":"안방"},
		{"building":3,"level":1,"rect":[146,73,7,5],"use":"부엌"},
		{"building":3,"level":1,"rect":[154,73,7,5],"use":"안방"},
		{"building":3,"level":1,"rect":[162,73,7,5],"use":"부엌"},
		{"building":3,"level":1,"rect":[137,82,8,5],"use":"안방"},
		{"building":3,"level":1,"rect":[146,82,7,5],"use":"부엌"},
		{"building":3,"level":1,"rect":[154,82,7,5],"use":"안방"},
		{"building":3,"level":1,"rect":[162,82,7,5],"use":"부엌"},
		{"building":3,"level":2,"rect":[137,73,8,5],"use":"안방"},
		{"building":3,"level":2,"rect":[146,73,7,5],"use":"부엌"},
		{"building":3,"level":2,"rect":[154,73,7,5],"use":"안방"},
		{"building":3,"level":2,"rect":[162,73,7,5],"use":"부엌"},
		{"building":3,"level":2,"rect":[137,82,8,5],"use":"안방"},
		{"building":3,"level":2,"rect":[146,82,7,5],"use":"부엌"},
		{"building":3,"level":2,"rect":[154,82,7,5],"use":"안방"},
		{"building":3,"level":2,"rect":[162,82,7,5],"use":"부엌"},
		{"building":3,"level":-1,"rect":[137,73,8,5],"use":"저장 칸"},
		{"building":3,"level":-1,"rect":[146,73,7,5],"use":"저장 칸"},
		{"building":3,"level":-1,"rect":[154,73,7,5],"use":"저장 칸"},
		{"building":3,"level":-1,"rect":[162,73,7,5],"use":"저장 칸"},
		{"building":3,"level":-1,"rect":[137,82,8,5],"use":"저장 칸"},
		{"building":3,"level":-1,"rect":[146,82,7,5],"use":"저장 칸"},
		{"building":3,"level":-1,"rect":[154,82,7,5],"use":"저장 칸"},
		{"building":3,"level":-1,"rect":[162,82,7,5],"use":"저장 칸"},
		{"building":4,"level":0,"rect":[65,95,8,4],"use":"안방"},
		{"building":4,"level":0,"rect":[74,95,8,4],"use":"부엌"},
		{"building":4,"level":0,"rect":[83,95,8,4],"use":"안방"},
		{"building":4,"level":0,"rect":[92,95,7,4],"use":"부엌"},
		{"building":4,"level":0,"rect":[100,95,7,4],"use":"안방"},
		{"building":4,"level":0,"rect":[65,103,8,4],"use":"안방"},
		{"building":4,"level":0,"rect":[74,103,8,4],"use":"부엌"},
		{"building":4,"level":0,"rect":[83,103,8,4],"use":"안방"},
		{"building":4,"level":0,"rect":[92,103,7,4],"use":"부엌"},
		{"building":4,"level":0,"rect":[100,103,7,4],"use":"안방"},
		{"building":4,"level":1,"rect":[65,95,10,4],"use":"안방"},
		{"building":4,"level":1,"rect":[76,95,9,4],"use":"부엌"},
		{"building":4,"level":1,"rect":[65,103,10,4],"use":"안방"},
		{"building":4,"level":1,"rect":[76,103,9,4],"use":"부엌"},
		{"building":4,"level":2,"rect":[65,95,10,4],"use":"안방"},
		{"building":4,"level":2,"rect":[76,95,9,4],"use":"부엌"},
		{"building":4,"level":2,"rect":[65,103,10,4],"use":"안방"},
		{"building":4,"level":2,"rect":[76,103,9,4],"use":"부엌"},
		{"building":5,"level":0,"rect":[139,96,9,3],"use":"매장"},
		{"building":5,"level":0,"rect":[149,96,9,3],"use":"뒤 창고"},
		{"building":5,"level":0,"rect":[159,96,8,3],"use":"작업실"},
		{"building":5,"level":0,"rect":[139,105,9,3],"use":"매장"},
		{"building":5,"level":0,"rect":[149,105,9,3],"use":"뒤 창고"},
		{"building":5,"level":0,"rect":[159,105,8,3],"use":"작업실"},
		{"building":5,"level":1,"rect":[139,96,9,3],"use":"매장"},
		{"building":5,"level":1,"rect":[149,96,9,3],"use":"뒤 창고"},
		{"building":5,"level":1,"rect":[159,96,8,3],"use":"작업실"},
		{"building":5,"level":1,"rect":[139,105,9,3],"use":"매장"},
		{"building":5,"level":1,"rect":[149,105,9,3],"use":"뒤 창고"},
		{"building":5,"level":1,"rect":[159,105,8,3],"use":"작업실"},
		{"building":6,"level":0,"rect":[61,21,6,8],"use":"작업실"},
		{"building":6,"level":0,"rect":[68,21,5,8],"use":"뒤 창고"},
		{"building":7,"level":0,"rect":[7,43,5,6],"use":"작업실"},
		{"building":7,"level":0,"rect":[13,43,4,6],"use":"뒤 창고"},
		{"building":8,"level":0,"rect":[27,47,5,6],"use":"작업실"},
		{"building":8,"level":0,"rect":[33,47,4,6],"use":"뒤 창고"},
		{"building":9,"level":0,"rect":[9,62,5,6],"use":"작업실"},
		{"building":9,"level":0,"rect":[15,62,4,6],"use":"뒤 창고"},
		{"building":10,"level":0,"rect":[29,66,5,6],"use":"작업실"},
		{"building":10,"level":0,"rect":[35,66,4,6],"use":"뒤 창고"},
		{"building":11,"level":0,"rect":[25,85,14,3],"use":"매장"},
		{"building":11,"level":0,"rect":[25,92,14,3],"use":"매장"},
		{"building":12,"level":0,"rect":[63,65,5,8],"use":"작업실"},
		{"building":12,"level":0,"rect":[69,65,4,8],"use":"뒤 창고"},
		{"building":13,"level":0,"rect":[81,67,9,3],"use":"매장"},
		{"building":13,"level":0,"rect":[91,67,8,3],"use":"뒤 창고"},
		{"building":13,"level":0,"rect":[81,74,9,3],"use":"매장"},
		{"building":13,"level":0,"rect":[91,74,8,3],"use":"뒤 창고"},
		{"building":14,"level":0,"rect":[81,21,6,6],"use":"작업실"},
		{"building":14,"level":0,"rect":[88,21,5,6],"use":"뒤 창고"},
		{"building":15,"level":0,"rect":[43,23,5,6],"use":"작업실"},
		{"building":15,"level":0,"rect":[49,23,4,6],"use":"뒤 창고"}],
	"props": [{"kind":"floor_shell","rect":[56,43,56,16],"solid":"none","facing":0,"note":"사층 겉모양","level":3},
		{"kind":"stair_stub","rect":[73,50,1,2],"solid":"none","facing":0,"note":"계단 자리","level":2},
		{"kind":"floor_shell","rect":[116,43,16,40],"solid":"none","facing":0,"note":"사층 겉모양","level":3},
		{"kind":"stair_stub","rect":[124,45,1,2],"solid":"none","facing":0,"note":"계단 자리","level":2},
		{"kind":"floor_shell","rect":[136,12,36,18],"solid":"none","facing":0,"note":"사층 겉모양","level":3},
		{"kind":"stair_stub","rect":[154,14,1,2],"solid":"none","facing":0,"note":"계단 자리","level":2},
		{"kind":"floor_shell","rect":[136,72,34,16],"solid":"none","facing":0,"note":"사층 겉모양","level":3},
		{"kind":"stair_stub","rect":[137,79,1,2],"solid":"none","facing":0,"note":"계단 자리","level":2},
		{"kind":"floor_shell","rect":[64,94,44,14],"solid":"none","facing":0,"note":"사층 겉모양","level":3},
		{"kind":"stair_stub","rect":[65,100,1,2],"solid":"none","facing":0,"note":"계단 자리","level":2},
		{"kind":"stalled_tram","rect":[142,60,12,3],"solid":"wall","facing":2,"note":"멈춘 전차","level":0},
		{"kind":"bed","rect":[57,44,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[65,48,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[57,48,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[67,44,2,2],"solid":"low","facing":0,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[74,48,1,1],"solid":"low","facing":1,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[67,48,1,1],"solid":"low","facing":2,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[76,44,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[83,48,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[76,48,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[85,44,2,2],"solid":"low","facing":0,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[92,48,1,1],"solid":"low","facing":1,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[85,48,1,1],"solid":"low","facing":2,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[94,44,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[101,48,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[94,48,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[103,44,2,2],"solid":"low","facing":0,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[110,48,1,1],"solid":"low","facing":1,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[103,48,1,1],"solid":"low","facing":2,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[57,53,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[65,57,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[57,57,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[67,53,2,2],"solid":"low","facing":0,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[74,57,1,1],"solid":"low","facing":1,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[67,57,1,1],"solid":"low","facing":2,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[76,53,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[83,57,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[76,57,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[85,53,2,2],"solid":"low","facing":0,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[92,57,1,1],"solid":"low","facing":1,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[85,57,1,1],"solid":"low","facing":2,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[94,53,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[101,57,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[94,57,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[103,53,2,2],"solid":"low","facing":0,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[110,57,1,1],"solid":"low","facing":1,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[103,57,1,1],"solid":"low","facing":2,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[57,44,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[65,48,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[57,48,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[67,44,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[74,48,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[67,48,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[76,44,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[83,48,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[76,48,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[85,44,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[92,48,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[85,48,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[94,44,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[101,48,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[94,48,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[103,44,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[110,48,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[103,48,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[57,53,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[65,57,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[57,57,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[67,53,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[74,57,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[67,57,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[76,53,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[83,57,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[76,57,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[85,53,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[92,57,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[85,57,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[94,53,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[101,57,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[94,57,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[103,53,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[110,57,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[103,57,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[57,44,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[65,48,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[57,48,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[67,44,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[74,48,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[67,48,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[76,44,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[83,48,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[76,48,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[85,44,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[92,48,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[85,48,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[94,44,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[101,48,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[94,48,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[103,44,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[110,48,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[103,48,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[57,53,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[65,57,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[57,57,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[67,53,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[74,57,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[67,57,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[76,53,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[83,57,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[76,57,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[85,53,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[92,57,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[85,57,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[94,53,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[101,57,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[94,57,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[103,53,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[110,57,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[103,57,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"jar_shelf","rect":[57,44,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[65,48,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[57,48,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[67,44,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[74,48,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[67,48,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[76,44,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[83,48,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[76,48,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[85,44,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[92,48,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[85,48,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[94,44,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[101,48,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[94,48,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[103,44,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[110,48,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[103,48,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[57,53,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[65,57,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[57,57,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[67,53,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[74,57,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[67,57,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[76,53,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[83,57,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[76,57,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[85,53,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[92,57,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[85,57,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[94,53,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[101,57,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[94,57,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[103,53,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[110,57,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[103,57,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"bed","rect":[120,44,2,1],"solid":"low","facing":1,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[117,52,1,1],"solid":"low","facing":2,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[120,52,2,1],"solid":"low","facing":3,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[120,54,2,2],"solid":"low","facing":1,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[117,62,1,1],"solid":"low","facing":2,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[121,62,1,1],"solid":"low","facing":3,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[120,64,2,1],"solid":"low","facing":1,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[117,72,1,1],"solid":"low","facing":2,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[120,72,2,1],"solid":"low","facing":3,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[120,74,2,2],"solid":"low","facing":1,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[117,81,1,1],"solid":"low","facing":2,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[121,81,1,1],"solid":"low","facing":3,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[129,44,2,1],"solid":"low","facing":1,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[126,52,1,1],"solid":"low","facing":2,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[129,52,2,1],"solid":"low","facing":3,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[129,54,2,2],"solid":"low","facing":1,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[126,62,1,1],"solid":"low","facing":2,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[130,62,1,1],"solid":"low","facing":3,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[129,64,2,1],"solid":"low","facing":1,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[126,72,1,1],"solid":"low","facing":2,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[129,72,2,1],"solid":"low","facing":3,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[129,74,2,2],"solid":"low","facing":1,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[126,81,1,1],"solid":"low","facing":2,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[130,81,1,1],"solid":"low","facing":3,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[120,44,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[117,52,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[120,52,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[120,54,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[117,62,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[121,62,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[120,64,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[117,72,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[120,72,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[120,74,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[117,81,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[121,81,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[129,44,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[126,52,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[129,52,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[129,54,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[126,62,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[130,62,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[129,64,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[126,72,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[129,72,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[129,74,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[126,81,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[130,81,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[120,44,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[117,52,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[120,52,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[120,54,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[117,62,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[121,62,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[120,64,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[117,72,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[120,72,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[120,74,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[117,81,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[121,81,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[129,44,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[126,52,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[129,52,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[129,54,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[126,62,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[130,62,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[129,64,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[126,72,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[129,72,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[129,74,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[126,81,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[130,81,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"dining_set","rect":[137,13,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[143,20,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[137,20,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[145,13,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[151,20,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[145,20,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[137,22,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[143,28,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[137,28,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[145,22,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[151,28,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[145,28,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[156,13,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[162,20,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[156,20,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[164,13,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[170,20,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[164,20,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[156,22,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[162,28,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[156,28,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[164,22,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[170,28,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[164,28,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[137,13,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[143,20,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[137,20,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[145,13,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[151,20,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[145,20,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[137,22,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[143,28,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[137,28,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[145,22,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[151,28,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[145,28,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[156,13,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[162,20,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[156,20,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[164,13,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[170,20,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[164,20,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[156,22,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[162,28,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[156,28,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[164,22,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[170,28,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[164,28,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[137,13,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[143,20,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[137,20,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[145,13,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[151,20,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[145,20,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[137,22,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[143,28,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[137,28,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[145,22,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[151,28,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[145,28,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[156,13,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[162,20,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[156,20,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[164,13,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[170,20,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[164,20,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[156,22,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[162,28,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[156,28,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[164,22,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[170,28,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[164,28,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":2},
		{"kind":"bed","rect":[143,73,2,1],"solid":"low","facing":3,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[137,77,1,1],"solid":"low","facing":0,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[143,77,2,1],"solid":"low","facing":1,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[151,73,2,2],"solid":"low","facing":3,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[146,77,1,1],"solid":"low","facing":0,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[152,77,1,1],"solid":"low","facing":1,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[159,73,2,1],"solid":"low","facing":3,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[154,77,1,1],"solid":"low","facing":0,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[159,77,2,1],"solid":"low","facing":1,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[167,73,2,2],"solid":"low","facing":3,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[162,77,1,1],"solid":"low","facing":0,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[168,77,1,1],"solid":"low","facing":1,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[143,82,2,1],"solid":"low","facing":3,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[137,86,1,1],"solid":"low","facing":0,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[143,86,2,1],"solid":"low","facing":1,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[151,82,2,2],"solid":"low","facing":3,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[146,86,1,1],"solid":"low","facing":0,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[152,86,1,1],"solid":"low","facing":1,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[159,82,2,1],"solid":"low","facing":3,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[154,86,1,1],"solid":"low","facing":0,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[159,86,2,1],"solid":"low","facing":1,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[167,82,2,2],"solid":"low","facing":3,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[162,86,1,1],"solid":"low","facing":0,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[168,86,1,1],"solid":"low","facing":1,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[143,73,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[137,77,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[143,77,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[151,73,2,2],"solid":"none","facing":3,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[146,77,1,1],"solid":"none","facing":0,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[152,77,1,1],"solid":"none","facing":1,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[159,73,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[154,77,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[159,77,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[167,73,2,2],"solid":"none","facing":3,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[162,77,1,1],"solid":"none","facing":0,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[168,77,1,1],"solid":"none","facing":1,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[143,82,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[137,86,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[143,86,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[151,82,2,2],"solid":"none","facing":3,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[146,86,1,1],"solid":"none","facing":0,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[152,86,1,1],"solid":"none","facing":1,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[159,82,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[154,86,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[159,86,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[167,82,2,2],"solid":"none","facing":3,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[162,86,1,1],"solid":"none","facing":0,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[168,86,1,1],"solid":"none","facing":1,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[143,73,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[137,77,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[143,77,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[151,73,2,2],"solid":"none","facing":3,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[146,77,1,1],"solid":"none","facing":0,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[152,77,1,1],"solid":"none","facing":1,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[159,73,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[154,77,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[159,77,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[167,73,2,2],"solid":"none","facing":3,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[162,77,1,1],"solid":"none","facing":0,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[168,77,1,1],"solid":"none","facing":1,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[143,82,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[137,86,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[143,86,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[151,82,2,2],"solid":"none","facing":3,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[146,86,1,1],"solid":"none","facing":0,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[152,86,1,1],"solid":"none","facing":1,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[159,82,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[154,86,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[159,86,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[167,82,2,2],"solid":"none","facing":3,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[162,86,1,1],"solid":"none","facing":0,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[168,86,1,1],"solid":"none","facing":1,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"jar_shelf","rect":[142,73,3,1],"solid":"none","facing":3,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[137,77,1,1],"solid":"none","facing":0,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[143,77,2,1],"solid":"none","facing":1,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[150,73,3,1],"solid":"none","facing":3,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[146,77,1,1],"solid":"none","facing":0,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[151,77,2,1],"solid":"none","facing":1,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[158,73,3,1],"solid":"none","facing":3,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[154,77,1,1],"solid":"none","facing":0,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[159,77,2,1],"solid":"none","facing":1,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[166,73,3,1],"solid":"none","facing":3,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[162,77,1,1],"solid":"none","facing":0,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[167,77,2,1],"solid":"none","facing":1,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[142,82,3,1],"solid":"none","facing":3,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[137,86,1,1],"solid":"none","facing":0,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[143,86,2,1],"solid":"none","facing":1,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[150,82,3,1],"solid":"none","facing":3,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[146,86,1,1],"solid":"none","facing":0,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[151,86,2,1],"solid":"none","facing":1,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[158,82,3,1],"solid":"none","facing":3,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[154,86,1,1],"solid":"none","facing":0,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[159,86,2,1],"solid":"none","facing":1,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[166,82,3,1],"solid":"none","facing":3,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[162,86,1,1],"solid":"none","facing":0,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[167,86,2,1],"solid":"none","facing":1,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"bed","rect":[65,95,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[72,98,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[65,98,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[74,95,2,2],"solid":"low","facing":0,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[81,98,1,1],"solid":"low","facing":1,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[74,98,1,1],"solid":"low","facing":2,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[83,95,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[90,98,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[83,98,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[92,95,2,2],"solid":"low","facing":0,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[98,98,1,1],"solid":"low","facing":1,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[92,98,1,1],"solid":"low","facing":2,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[100,95,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[106,98,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[100,98,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"bed","rect":[65,103,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[72,106,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[65,106,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[74,103,2,2],"solid":"low","facing":0,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[81,106,1,1],"solid":"low","facing":1,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[74,106,1,1],"solid":"low","facing":2,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[83,103,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[90,106,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[83,106,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[92,103,2,2],"solid":"low","facing":0,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[98,106,1,1],"solid":"low","facing":1,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[92,106,1,1],"solid":"low","facing":2,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[100,103,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[106,106,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[100,106,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"bed","rect":[65,95,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[74,98,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[65,98,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[76,95,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[84,98,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[76,98,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[65,103,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[74,106,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[65,106,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[76,103,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[84,106,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[76,106,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[65,95,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[74,98,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[65,98,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[76,95,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[84,98,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[76,98,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[65,103,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[74,106,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[65,106,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[76,103,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[84,106,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[76,106,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"display_shelf","rect":[144,96,4,1],"solid":"low","facing":1,"note":"매장의 진열대","level":0},
		{"kind":"shop_counter","rect":[139,98,3,1],"solid":"low","facing":2,"note":"매장의 가게 계산대","level":0},
		{"kind":"tin_crate","rect":[146,98,2,1],"solid":"low","facing":3,"note":"매장의 통조림 상자","level":0},
		{"kind":"display_shelf","rect":[154,96,4,1],"solid":"low","facing":1,"note":"뒤 창고의 진열대","level":0},
		{"kind":"shelf","rect":[149,98,3,1],"solid":"low","facing":2,"note":"뒤 창고의 선반","level":0},
		{"kind":"tin_crate","rect":[156,98,2,1],"solid":"low","facing":3,"note":"뒤 창고의 통조림 상자","level":0},
		{"kind":"shelf","rect":[164,96,3,1],"solid":"low","facing":1,"note":"작업실의 선반","level":0},
		{"kind":"tin_crate","rect":[159,98,2,1],"solid":"low","facing":2,"note":"작업실의 통조림 상자","level":0},
		{"kind":"display_shelf","rect":[159,96,4,1],"solid":"low","facing":3,"note":"작업실의 진열대","level":0},
		{"kind":"display_shelf","rect":[144,105,4,1],"solid":"low","facing":1,"note":"매장의 진열대","level":0},
		{"kind":"shelf","rect":[139,107,3,1],"solid":"low","facing":2,"note":"매장의 선반","level":0},
		{"kind":"tin_crate","rect":[146,107,2,1],"solid":"low","facing":3,"note":"매장의 통조림 상자","level":0},
		{"kind":"display_shelf","rect":[154,105,4,1],"solid":"low","facing":1,"note":"뒤 창고의 진열대","level":0},
		{"kind":"shelf","rect":[149,107,3,1],"solid":"low","facing":2,"note":"뒤 창고의 선반","level":0},
		{"kind":"tin_crate","rect":[156,107,2,1],"solid":"low","facing":3,"note":"뒤 창고의 통조림 상자","level":0},
		{"kind":"shelf","rect":[164,105,3,1],"solid":"low","facing":1,"note":"작업실의 선반","level":0},
		{"kind":"tin_crate","rect":[159,107,2,1],"solid":"low","facing":2,"note":"작업실의 통조림 상자","level":0},
		{"kind":"display_shelf","rect":[159,105,4,1],"solid":"low","facing":3,"note":"작업실의 진열대","level":0},
		{"kind":"bed","rect":[146,96,2,1],"solid":"none","facing":1,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[139,98,1,1],"solid":"none","facing":2,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[146,98,2,1],"solid":"none","facing":3,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[156,96,2,1],"solid":"none","facing":1,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[149,98,1,1],"solid":"none","facing":2,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[156,98,2,1],"solid":"none","facing":3,"note":"뒤 창고의 장롱","level":1},
		{"kind":"fridge_open","rect":[166,96,1,1],"solid":"none","facing":1,"note":"작업실의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[159,98,2,1],"solid":"none","facing":2,"note":"작업실의 장롱","level":1},
		{"kind":"bed","rect":[165,98,2,1],"solid":"none","facing":3,"note":"작업실의 침대","level":1},
		{"kind":"bed","rect":[146,105,2,1],"solid":"none","facing":1,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[139,107,1,1],"solid":"none","facing":2,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[146,107,2,1],"solid":"none","facing":3,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[156,105,2,1],"solid":"none","facing":1,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[149,107,1,1],"solid":"none","facing":2,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[156,107,2,1],"solid":"none","facing":3,"note":"뒤 창고의 장롱","level":1},
		{"kind":"fridge_open","rect":[166,105,1,1],"solid":"none","facing":1,"note":"작업실의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[159,107,2,1],"solid":"none","facing":2,"note":"작업실의 장롱","level":1},
		{"kind":"bed","rect":[165,107,2,1],"solid":"none","facing":3,"note":"작업실의 침대","level":1},
		{"kind":"desk","rect":[61,21,2,1],"solid":"none","facing":2,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[65,27,2,2],"solid":"none","facing":3,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[61,28,3,1],"solid":"none","facing":0,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[68,21,3,1],"solid":"none","facing":2,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[71,28,2,1],"solid":"none","facing":3,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[68,27,2,2],"solid":"none","facing":0,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"desk","rect":[10,43,2,1],"solid":"low","facing":3,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[7,47,2,2],"solid":"low","facing":0,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[9,48,3,1],"solid":"low","facing":1,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[14,43,3,1],"solid":"low","facing":3,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[13,48,2,1],"solid":"low","facing":0,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[15,47,2,2],"solid":"low","facing":1,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"desk","rect":[27,47,2,1],"solid":"low","facing":0,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[30,51,2,2],"solid":"low","facing":1,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[27,52,3,1],"solid":"low","facing":2,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[33,47,3,1],"solid":"low","facing":0,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[35,52,2,1],"solid":"low","facing":1,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[33,51,2,2],"solid":"low","facing":2,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"desk","rect":[12,62,2,1],"solid":"low","facing":1,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[9,66,2,2],"solid":"low","facing":2,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[11,67,3,1],"solid":"low","facing":3,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[16,62,3,1],"solid":"low","facing":1,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[15,67,2,1],"solid":"low","facing":2,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[17,66,2,2],"solid":"low","facing":3,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"desk","rect":[29,66,2,1],"solid":"low","facing":2,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[32,70,2,2],"solid":"low","facing":3,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[29,71,3,1],"solid":"low","facing":0,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[35,66,3,1],"solid":"low","facing":2,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[37,71,2,1],"solid":"low","facing":3,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[35,70,2,2],"solid":"low","facing":0,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[36,85,3,1],"solid":"low","facing":3,"note":"매장의 선반","level":0},
		{"kind":"desk","rect":[25,87,2,1],"solid":"low","facing":0,"note":"매장의 책상","level":0},
		{"kind":"crate_stack","rect":[37,86,2,2],"solid":"low","facing":1,"note":"매장의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[36,92,3,1],"solid":"low","facing":3,"note":"매장의 선반","level":0},
		{"kind":"desk","rect":[25,94,2,1],"solid":"low","facing":0,"note":"매장의 책상","level":0},
		{"kind":"crate_stack","rect":[37,93,2,2],"solid":"low","facing":1,"note":"매장의 나무 상자 더미","level":0},
		{"kind":"desk","rect":[63,65,2,1],"solid":"low","facing":0,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[66,71,2,2],"solid":"low","facing":1,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[63,72,3,1],"solid":"low","facing":2,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[69,65,3,1],"solid":"low","facing":0,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[71,72,2,1],"solid":"low","facing":1,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[69,71,2,2],"solid":"low","facing":2,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"door_pile","rect":[88,67,2,1],"solid":"low","facing":1,"note":"매장의 문짝 더미","level":0},
		{"kind":"desk","rect":[81,69,2,1],"solid":"low","facing":2,"note":"매장의 책상","level":0},
		{"kind":"firewood_pile","rect":[88,69,2,1],"solid":"low","facing":3,"note":"매장의 장작 더미","level":0},
		{"kind":"door_pile","rect":[97,67,2,1],"solid":"low","facing":1,"note":"뒤 창고의 문짝 더미","level":0},
		{"kind":"desk","rect":[91,69,2,1],"solid":"low","facing":2,"note":"뒤 창고의 책상","level":0},
		{"kind":"firewood_pile","rect":[97,69,2,1],"solid":"low","facing":3,"note":"뒤 창고의 장작 더미","level":0},
		{"kind":"door_pile","rect":[88,74,2,1],"solid":"low","facing":1,"note":"매장의 문짝 더미","level":0},
		{"kind":"desk","rect":[81,76,2,1],"solid":"low","facing":2,"note":"매장의 책상","level":0},
		{"kind":"firewood_pile","rect":[88,76,2,1],"solid":"low","facing":3,"note":"매장의 장작 더미","level":0},
		{"kind":"door_pile","rect":[97,74,2,1],"solid":"low","facing":1,"note":"뒤 창고의 문짝 더미","level":0},
		{"kind":"desk","rect":[91,76,2,1],"solid":"low","facing":2,"note":"뒤 창고의 책상","level":0},
		{"kind":"firewood_pile","rect":[97,76,2,1],"solid":"low","facing":3,"note":"뒤 창고의 장작 더미","level":0},
		{"kind":"desk","rect":[81,21,2,1],"solid":"none","facing":2,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[85,25,2,2],"solid":"none","facing":3,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[81,26,3,1],"solid":"none","facing":0,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[88,21,3,1],"solid":"none","facing":2,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[91,26,2,1],"solid":"none","facing":3,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[88,25,2,2],"solid":"none","facing":0,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"desk","rect":[46,23,2,1],"solid":"none","facing":3,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[43,27,2,2],"solid":"none","facing":0,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[45,28,3,1],"solid":"none","facing":1,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[50,23,3,1],"solid":"none","facing":3,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[49,28,2,1],"solid":"none","facing":0,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[51,27,2,2],"solid":"none","facing":1,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"car","rect":[28,10,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
		{"kind":"car","rect":[56,10,4,2],"solid":"low","facing":1,"note":"버려진 차","level":0},
		{"kind":"bench","rect":[86,14,3,1],"solid":"low","facing":2,"note":"긴 의자","level":0},
		{"kind":"car","rect":[99,26,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
		{"kind":"door_pile","rect":[56,40,2,1],"solid":"low","facing":3,"note":"문짝 더미","level":0},
		{"kind":"firewood_pile","rect":[61,39,2,1],"solid":"low","facing":0,"note":"장작 더미","level":0},
		{"kind":"handcart","rect":[65,41,2,1],"solid":"low","facing":1,"note":"손수레","level":0},
		{"kind":"door_pile","rect":[136,9,2,1],"solid":"low","facing":2,"note":"문짝 더미","level":0},
		{"kind":"firewood_pile","rect":[141,8,2,1],"solid":"low","facing":3,"note":"장작 더미","level":0},
		{"kind":"handcart","rect":[145,10,2,1],"solid":"low","facing":0,"note":"손수레","level":0},
		{"kind":"door_pile","rect":[64,91,2,1],"solid":"low","facing":1,"note":"문짝 더미","level":0},
		{"kind":"firewood_pile","rect":[69,90,2,1],"solid":"low","facing":2,"note":"장작 더미","level":0},
		{"kind":"handcart","rect":[73,92,2,1],"solid":"low","facing":3,"note":"손수레","level":0},
		{"kind":"door_pile","rect":[8,58,2,1],"solid":"low","facing":0,"note":"문짝 더미","level":0},
		{"kind":"firewood_pile","rect":[13,57,2,1],"solid":"low","facing":1,"note":"장작 더미","level":0},
		{"kind":"handcart","rect":[17,59,2,1],"solid":"low","facing":2,"note":"손수레","level":0},
		{"kind":"playground_frame","rect":[80,82,4,3],"solid":"low","facing":3,"note":"놀이터 틀","level":0},
		{"kind":"bench","rect":[87,84,3,1],"solid":"low","facing":0,"note":"긴 의자","level":0},
		{"kind":"laundry_line","rect":[96,82,6,1],"solid":"none","facing":1,"note":"언 천 조각","level":0},
		{"kind":"door_pile","rect":[109,96,2,1],"solid":"low","facing":2,"note":"문짝 더미","level":0},
		{"kind":"lamp_post","rect":[62,61,1,1],"solid":"none","facing":3,"note":"꺼진 등잔","level":0},
		{"kind":"lamp_post","rect":[52,89,1,1],"solid":"none","facing":0,"note":"꺼진 등잔","level":0},
		{"kind":"crate_stack","rect":[53,91,2,2],"solid":"low","facing":1,"note":"나무 상자 더미","level":0},
		{"kind":"lamp_post","rect":[24,77,1,1],"solid":"none","facing":2,"note":"꺼진 등잔","level":0},
		{"kind":"crate_stack","rect":[25,79,2,2],"solid":"low","facing":3,"note":"나무 상자 더미","level":0},
		{"kind":"lamp_post","rect":[126,95,1,1],"solid":"none","facing":0,"note":"꺼진 등잔","level":0},
		{"kind":"crate_stack","rect":[127,97,2,2],"solid":"low","facing":1,"note":"나무 상자 더미","level":0},
		{"kind":"street_tree","rect":[72,15,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[70,32,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[99,32,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[128,32,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[157,32,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[46,33,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[104,33,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[133,33,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[47,39,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[76,39,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[105,39,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[23,40,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[81,40,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[110,40,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[139,40,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[53,46,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[140,46,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[160,50,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[146,53,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[151,54,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[16,56,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[132,56,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[46,62,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[133,62,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[148,65,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[153,66,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[47,68,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[163,68,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[23,69,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[24,75,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[53,75,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[20,80,1,1],"solid":"tree","facing":1,"note":"가로수","level":0}],
	"containers": [{"id":"cache_0","name":"안방 상자","cell":[64,48],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_1","name":"부엌 상자","cell":[73,48],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_2","name":"안방 상자","cell":[82,48],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_3","name":"부엌 상자","cell":[91,48],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_4","name":"안방 상자","cell":[100,48],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_5","name":"부엌 상자","cell":[109,48],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_6","name":"안방 상자","cell":[64,57],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_7","name":"부엌 상자","cell":[73,57],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_8","name":"안방 상자","cell":[82,57],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_9","name":"부엌 상자","cell":[91,57],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_10","name":"안방 상자","cell":[100,57],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_11","name":"부엌 상자","cell":[109,57],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_12","name":"안방 상자","cell":[64,48],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_13","name":"부엌 상자","cell":[73,48],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_14","name":"안방 상자","cell":[82,48],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_15","name":"부엌 상자","cell":[91,48],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_16","name":"안방 상자","cell":[100,48],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_17","name":"부엌 상자","cell":[109,48],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_18","name":"안방 상자","cell":[64,57],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_19","name":"부엌 상자","cell":[73,57],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_20","name":"안방 상자","cell":[82,57],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_21","name":"부엌 상자","cell":[91,57],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_22","name":"안방 상자","cell":[100,57],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_23","name":"부엌 상자","cell":[109,57],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_24","name":"안방 상자","cell":[64,48],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_25","name":"부엌 상자","cell":[73,48],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_26","name":"안방 상자","cell":[82,48],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_27","name":"부엌 상자","cell":[91,48],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_28","name":"안방 상자","cell":[100,48],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_29","name":"부엌 상자","cell":[109,48],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_30","name":"안쪽 저장 상자","cell":[64,57],"level":2,"building":0,"search":4,"items":["plank","plank","plank","plank"],"locked":true,"searched":false},
		{"id":"cache_31","name":"부엌 상자","cell":[73,57],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_32","name":"안방 상자","cell":[82,57],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_33","name":"부엌 상자","cell":[91,57],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_34","name":"안방 상자","cell":[100,57],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_35","name":"부엌 상자","cell":[109,57],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_36","name":"저장 칸 상자","cell":[64,48],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_37","name":"저장 칸 상자","cell":[73,48],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_38","name":"저장 칸 상자","cell":[82,48],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_39","name":"저장 칸 상자","cell":[91,48],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_40","name":"저장 칸 상자","cell":[100,48],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_41","name":"저장 칸 상자","cell":[109,48],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_42","name":"저장 칸 상자","cell":[64,57],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_43","name":"저장 칸 상자","cell":[73,57],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_44","name":"저장 칸 상자","cell":[82,57],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_45","name":"저장 칸 상자","cell":[91,57],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_46","name":"저장 칸 상자","cell":[100,57],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_47","name":"저장 칸 상자","cell":[109,57],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_48","name":"안방 상자","cell":[119,52],"level":0,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_49","name":"부엌 상자","cell":[120,62],"level":0,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_50","name":"안방 상자","cell":[119,72],"level":0,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_51","name":"부엌 상자","cell":[120,81],"level":0,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_52","name":"안방 상자","cell":[128,52],"level":0,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_53","name":"부엌 상자","cell":[129,62],"level":0,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_54","name":"안방 상자","cell":[128,72],"level":0,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_55","name":"부엌 상자","cell":[129,81],"level":0,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_56","name":"안방 상자","cell":[119,52],"level":1,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_57","name":"부엌 상자","cell":[120,62],"level":1,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_58","name":"안방 상자","cell":[119,72],"level":1,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_59","name":"부엌 상자","cell":[120,81],"level":1,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_60","name":"안방 상자","cell":[128,52],"level":1,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_61","name":"부엌 상자","cell":[129,62],"level":1,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_62","name":"안방 상자","cell":[128,72],"level":1,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_63","name":"부엌 상자","cell":[129,81],"level":1,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_64","name":"안방 상자","cell":[119,52],"level":2,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_65","name":"부엌 상자","cell":[120,62],"level":2,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_66","name":"안방 상자","cell":[119,72],"level":2,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_67","name":"부엌 상자","cell":[120,81],"level":2,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_68","name":"안방 상자","cell":[128,52],"level":2,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_69","name":"부엌 상자","cell":[129,62],"level":2,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_70","name":"안방 상자","cell":[128,72],"level":2,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_71","name":"부엌 상자","cell":[129,81],"level":2,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_72","name":"부엌 상자","cell":[142,20],"level":0,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_73","name":"안방 상자","cell":[150,20],"level":0,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_74","name":"부엌 상자","cell":[142,28],"level":0,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_75","name":"안방 상자","cell":[150,28],"level":0,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_76","name":"부엌 상자","cell":[161,20],"level":0,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_77","name":"안방 상자","cell":[169,20],"level":0,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_78","name":"부엌 상자","cell":[161,28],"level":0,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_79","name":"안방 상자","cell":[169,28],"level":0,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_80","name":"부엌 상자","cell":[142,20],"level":1,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_81","name":"안방 상자","cell":[150,20],"level":1,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_82","name":"부엌 상자","cell":[142,28],"level":1,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_83","name":"안방 상자","cell":[150,28],"level":1,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_84","name":"부엌 상자","cell":[161,20],"level":1,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_85","name":"안방 상자","cell":[169,20],"level":1,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_86","name":"부엌 상자","cell":[161,28],"level":1,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_87","name":"안방 상자","cell":[169,28],"level":1,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_88","name":"부엌 상자","cell":[142,20],"level":2,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_89","name":"안방 상자","cell":[150,20],"level":2,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_90","name":"부엌 상자","cell":[142,28],"level":2,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_91","name":"안방 상자","cell":[150,28],"level":2,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_92","name":"부엌 상자","cell":[161,20],"level":2,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_93","name":"안방 상자","cell":[169,20],"level":2,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_94","name":"부엌 상자","cell":[161,28],"level":2,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_95","name":"안방 상자","cell":[169,28],"level":2,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_96","name":"안방 상자","cell":[142,77],"level":0,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_97","name":"부엌 상자","cell":[151,77],"level":0,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_98","name":"안방 상자","cell":[158,77],"level":0,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_99","name":"부엌 상자","cell":[167,77],"level":0,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_100","name":"안방 상자","cell":[142,86],"level":0,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_101","name":"부엌 상자","cell":[151,86],"level":0,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_102","name":"안방 상자","cell":[158,86],"level":0,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_103","name":"부엌 상자","cell":[167,86],"level":0,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_104","name":"안방 상자","cell":[142,77],"level":1,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_105","name":"부엌 상자","cell":[151,77],"level":1,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_106","name":"안방 상자","cell":[158,77],"level":1,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_107","name":"부엌 상자","cell":[167,77],"level":1,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_108","name":"안방 상자","cell":[142,86],"level":1,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_109","name":"부엌 상자","cell":[151,86],"level":1,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_110","name":"안방 상자","cell":[158,86],"level":1,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_111","name":"부엌 상자","cell":[167,86],"level":1,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_112","name":"안방 상자","cell":[142,77],"level":2,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_113","name":"부엌 상자","cell":[151,77],"level":2,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_114","name":"안방 상자","cell":[158,77],"level":2,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_115","name":"부엌 상자","cell":[167,77],"level":2,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_116","name":"안방 상자","cell":[142,86],"level":2,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_117","name":"부엌 상자","cell":[151,86],"level":2,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_118","name":"안방 상자","cell":[158,86],"level":2,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_119","name":"부엌 상자","cell":[167,86],"level":2,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_120","name":"저장 칸 상자","cell":[142,77],"level":-1,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_121","name":"저장 칸 상자","cell":[150,77],"level":-1,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_122","name":"저장 칸 상자","cell":[158,77],"level":-1,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_123","name":"저장 칸 상자","cell":[166,77],"level":-1,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_124","name":"저장 칸 상자","cell":[142,86],"level":-1,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_125","name":"저장 칸 상자","cell":[150,86],"level":-1,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_126","name":"저장 칸 상자","cell":[158,86],"level":-1,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_127","name":"먼 끝 저장 상자","cell":[166,86],"level":-1,"building":3,"search":4,"items":["plank","plank","plank","plank"],"locked":true,"searched":false},
		{"id":"cache_128","name":"안방 상자","cell":[71,98],"level":0,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_129","name":"부엌 상자","cell":[80,98],"level":0,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_130","name":"안방 상자","cell":[89,98],"level":0,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_131","name":"부엌 상자","cell":[97,98],"level":0,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_132","name":"안방 상자","cell":[105,98],"level":0,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_133","name":"안방 상자","cell":[71,106],"level":0,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_134","name":"부엌 상자","cell":[80,106],"level":0,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_135","name":"안방 상자","cell":[89,106],"level":0,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_136","name":"부엌 상자","cell":[97,106],"level":0,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_137","name":"안방 상자","cell":[105,106],"level":0,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_138","name":"안방 상자","cell":[73,98],"level":1,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_139","name":"부엌 상자","cell":[83,98],"level":1,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_140","name":"안방 상자","cell":[73,106],"level":1,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_141","name":"부엌 상자","cell":[83,106],"level":1,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_142","name":"안방 상자","cell":[73,98],"level":2,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_143","name":"부엌 상자","cell":[83,98],"level":2,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_144","name":"안방 상자","cell":[73,106],"level":2,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_145","name":"부엌 상자","cell":[83,106],"level":2,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_146","name":"매장 상자","cell":[145,98],"level":0,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_147","name":"뒤 창고 상자","cell":[155,98],"level":0,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_148","name":"작업실 상자","cell":[166,98],"level":0,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_149","name":"매장 상자","cell":[145,107],"level":0,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_150","name":"뒤 창고 상자","cell":[155,107],"level":0,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_151","name":"작업실 상자","cell":[166,107],"level":0,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_152","name":"매장 상자","cell":[145,98],"level":1,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_153","name":"뒤 창고 상자","cell":[155,98],"level":1,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_154","name":"작업실 상자","cell":[164,98],"level":1,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_155","name":"매장 상자","cell":[145,107],"level":1,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_156","name":"뒤 창고 상자","cell":[155,107],"level":1,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_157","name":"작업실 상자","cell":[164,107],"level":1,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_158","name":"작업실 상자","cell":[64,28],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_159","name":"뒤 창고 상자","cell":[70,28],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_160","name":"작업실 상자","cell":[11,47],"level":0,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_161","name":"뒤 창고 상자","cell":[14,47],"level":0,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_162","name":"작업실 상자","cell":[29,51],"level":0,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_163","name":"뒤 창고 상자","cell":[36,51],"level":0,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_164","name":"작업실 상자","cell":[13,66],"level":0,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_165","name":"뒤 창고 상자","cell":[16,66],"level":0,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_166","name":"작업실 상자","cell":[31,70],"level":0,"building":10,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_167","name":"뒤 창고 상자","cell":[38,70],"level":0,"building":10,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_168","name":"매장 상자","cell":[36,87],"level":0,"building":11,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_169","name":"매장 상자","cell":[36,94],"level":0,"building":11,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_170","name":"작업실 상자","cell":[65,71],"level":0,"building":12,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_171","name":"뒤 창고 상자","cell":[72,71],"level":0,"building":12,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_172","name":"매장 상자","cell":[87,69],"level":0,"building":13,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_173","name":"뒤 창고 상자","cell":[96,69],"level":0,"building":13,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_174","name":"매장 상자","cell":[87,76],"level":0,"building":13,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_175","name":"뒤 창고 상자","cell":[96,76],"level":0,"building":13,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_176","name":"작업실 상자","cell":[84,26],"level":0,"building":14,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_177","name":"뒤 창고 상자","cell":[90,26],"level":0,"building":14,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_178","name":"작업실 상자","cell":[47,27],"level":0,"building":15,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_179","name":"뒤 창고 상자","cell":[50,27],"level":0,"building":15,"search":4,"items":["plank"],"locked":false,"searched":false}],
	"spots": [{"id":"salvage_0","kind":"salvage","name":"남은 목재","cell":[64,48],"material":"wood","amount":2,"state":"intact"},
		{"id":"salvage_1","kind":"salvage","name":"남은 목재","cell":[73,48],"material":"wood","amount":2,"state":"intact"}],
	"slots": ["B","F"],
	"dead": [[0,76],[120,109],[179,44],[179,94],[60,62],[50,90],[22,78],[124,96]],
	"forecourts": [{"cell":[56,50],"normal":[-1,0],"cells":[[55,52],[55,51],[55,50],[55,49],[55,48],[54,52],[54,51],[54,50],[54,49],[54,48],[53,52],[53,51],[53,50],[53,49],[53,48],[52,52],[52,51],[52,50],[52,49],[52,48]],"building":0},
		{"cell":[111,50],"normal":[1,0],"cells":[[112,48],[112,49],[112,50],[112,51],[112,52],[113,48],[113,49],[113,50],[113,51],[113,52],[114,48],[114,49],[114,50],[114,51],[114,52],[115,48],[115,49],[115,50],[115,51],[115,52]],"building":0},
		{"cell":[123,43],"normal":[0,-1],"cells":[[121,42],[122,42],[123,42],[124,42],[125,42],[121,41],[122,41],[123,41],[124,41],[125,41],[121,40],[122,40],[123,40],[124,40],[125,40],[121,39],[122,39],[123,39],[124,39],[125,39]],"building":1},
		{"cell":[123,82],"normal":[0,1],"cells":[[125,83],[124,83],[123,83],[122,83],[121,83],[125,84],[124,84],[123,84],[122,84],[121,84],[125,85],[124,85],[123,85],[122,85],[121,85],[125,86],[124,86],[123,86],[122,86],[121,86]],"building":1},
		{"cell":[153,12],"normal":[0,-1],"cells":[[151,11],[152,11],[153,11],[154,11],[155,11],[151,10],[152,10],[153,10],[154,10],[155,10],[151,9],[152,9],[153,9],[154,9],[155,9],[151,8],[152,8],[153,8],[154,8],[155,8]],"building":2},
		{"cell":[153,29],"normal":[0,1],"cells":[[155,30],[154,30],[153,30],[152,30],[151,30],[155,31],[154,31],[153,31],[152,31],[151,31],[155,32],[154,32],[153,32],[152,32],[151,32],[155,33],[154,33],[153,33],[152,33],[151,33]],"building":2},
		{"cell":[136,79],"normal":[-1,0],"cells":[[135,81],[135,80],[135,79],[135,78],[135,77],[134,81],[134,80],[134,79],[134,78],[134,77],[133,81],[133,80],[133,79],[133,78],[133,77],[132,81],[132,80],[132,79],[132,78],[132,77]],"building":3},
		{"cell":[169,79],"normal":[1,0],"cells":[[170,77],[170,78],[170,79],[170,80],[170,81],[171,77],[171,78],[171,79],[171,80],[171,81],[172,77],[172,78],[172,79],[172,80],[172,81],[173,77],[173,78],[173,79],[173,80],[173,81]],"building":3},
		{"cell":[64,100],"normal":[-1,0],"cells":[[63,102],[63,101],[63,100],[63,99],[63,98],[62,102],[62,101],[62,100],[62,99],[62,98],[61,102],[61,101],[61,100],[61,99],[61,98],[60,102],[60,101],[60,100],[60,99],[60,98]],"building":4},
		{"cell":[107,100],"normal":[1,0],"cells":[[108,98],[108,99],[108,100],[108,101],[108,102],[109,98],[109,99],[109,100],[109,101],[109,102],[110,98],[110,99],[110,100],[110,101],[110,102],[111,98],[111,99],[111,100],[111,101],[111,102]],"building":4},
		{"cell":[138,100],"normal":[-1,0],"cells":[[137,102],[137,101],[137,100],[137,99],[137,98],[136,102],[136,101],[136,100],[136,99],[136,98],[135,102],[135,101],[135,100],[135,99],[135,98],[134,102],[134,101],[134,100],[134,99],[134,98]],"building":5},
		{"cell":[167,100],"normal":[1,0],"cells":[[168,98],[168,99],[168,100],[168,101],[168,102],[169,98],[169,99],[169,100],[169,101],[169,102],[170,98],[170,99],[170,100],[170,101],[170,102],[171,98],[171,99],[171,100],[171,101],[171,102]],"building":5},
		{"cell":[60,25],"normal":[-1,0],"cells":[[59,27],[59,26],[59,25],[59,24],[59,23],[58,27],[58,26],[58,25],[58,24],[58,23],[57,27],[57,26],[57,25],[57,24],[57,23],[56,27],[56,26],[56,25],[56,24],[56,23]],"building":6},
		{"cell":[73,25],"normal":[1,0],"cells":[[74,23],[74,24],[74,25],[74,26],[74,27],[75,23],[75,24],[75,25],[75,26],[75,27],[76,23],[76,24],[76,25],[76,26],[76,27],[77,23],[77,24],[77,25],[77,26],[77,27]],"building":6},
		{"cell":[6,46],"normal":[-1,0],"cells":[[5,48],[5,47],[5,46],[5,45],[5,44],[4,48],[4,47],[4,46],[4,45],[4,44],[3,48],[3,47],[3,46],[3,45],[3,44],[2,48],[2,47],[2,46],[2,45],[2,44]],"building":7},
		{"cell":[17,46],"normal":[1,0],"cells":[[18,44],[18,45],[18,46],[18,47],[18,48],[19,44],[19,45],[19,46],[19,47],[19,48],[20,44],[20,45],[20,46],[20,47],[20,48],[21,44],[21,45],[21,46],[21,47],[21,48]],"building":7},
		{"cell":[26,50],"normal":[-1,0],"cells":[[25,52],[25,51],[25,50],[25,49],[25,48],[24,52],[24,51],[24,50],[24,49],[24,48],[23,52],[23,51],[23,50],[23,49],[23,48],[22,52],[22,51],[22,50],[22,49],[22,48]],"building":8},
		{"cell":[37,50],"normal":[1,0],"cells":[[38,48],[38,49],[38,50],[38,51],[38,52],[39,48],[39,49],[39,50],[39,51],[39,52],[40,48],[40,49],[40,50],[40,51],[40,52],[41,48],[41,49],[41,50],[41,51],[41,52]],"building":8},
		{"cell":[8,65],"normal":[-1,0],"cells":[[7,67],[7,66],[7,65],[7,64],[7,63],[6,67],[6,66],[6,65],[6,64],[6,63],[5,67],[5,66],[5,65],[5,64],[5,63],[4,67],[4,66],[4,65],[4,64],[4,63]],"building":9},
		{"cell":[19,65],"normal":[1,0],"cells":[[20,63],[20,64],[20,65],[20,66],[20,67],[21,63],[21,64],[21,65],[21,66],[21,67],[22,63],[22,64],[22,65],[22,66],[22,67],[23,63],[23,64],[23,65],[23,66],[23,67]],"building":9},
		{"cell":[28,69],"normal":[-1,0],"cells":[[27,71],[27,70],[27,69],[27,68],[27,67],[26,71],[26,70],[26,69],[26,68],[26,67],[25,71],[25,70],[25,69],[25,68],[25,67],[24,71],[24,70],[24,69],[24,68],[24,67]],"building":10},
		{"cell":[39,69],"normal":[1,0],"cells":[[40,67],[40,68],[40,69],[40,70],[40,71],[41,67],[41,68],[41,69],[41,70],[41,71],[42,67],[42,68],[42,69],[42,70],[42,71],[43,67],[43,68],[43,69],[43,70],[43,71]],"building":10},
		{"cell":[24,89],"normal":[-1,0],"cells":[[23,91],[23,90],[23,89],[23,88],[23,87],[22,91],[22,90],[22,89],[22,88],[22,87],[21,91],[21,90],[21,89],[21,88],[21,87],[20,91],[20,90],[20,89],[20,88],[20,87]],"building":11},
		{"cell":[39,89],"normal":[1,0],"cells":[[40,87],[40,88],[40,89],[40,90],[40,91],[41,87],[41,88],[41,89],[41,90],[41,91],[42,87],[42,88],[42,89],[42,90],[42,91],[43,87],[43,88],[43,89],[43,90],[43,91]],"building":11},
		{"cell":[62,69],"normal":[-1,0],"cells":[[61,71],[61,70],[61,69],[61,68],[61,67],[60,71],[60,70],[60,69],[60,68],[60,67],[59,71],[59,70],[59,69],[59,68],[59,67],[58,71],[58,70],[58,69],[58,68],[58,67]],"building":12},
		{"cell":[73,69],"normal":[1,0],"cells":[[74,67],[74,68],[74,69],[74,70],[74,71],[75,67],[75,68],[75,69],[75,70],[75,71],[76,67],[76,68],[76,69],[76,70],[76,71],[77,67],[77,68],[77,69],[77,70],[77,71]],"building":12},
		{"cell":[80,71],"normal":[-1,0],"cells":[[79,73],[79,72],[79,71],[79,70],[79,69],[78,73],[78,72],[78,71],[78,70],[78,69],[77,73],[77,72],[77,71],[77,70],[77,69],[76,73],[76,72],[76,71],[76,70],[76,69]],"building":13},
		{"cell":[99,71],"normal":[1,0],"cells":[[100,69],[100,70],[100,71],[100,72],[100,73],[101,69],[101,70],[101,71],[101,72],[101,73],[102,69],[102,70],[102,71],[102,72],[102,73],[103,69],[103,70],[103,71],[103,72],[103,73]],"building":13},
		{"cell":[80,24],"normal":[-1,0],"cells":[[79,26],[79,25],[79,24],[79,23],[79,22],[78,26],[78,25],[78,24],[78,23],[78,22],[77,26],[77,25],[77,24],[77,23],[77,22],[76,26],[76,25],[76,24],[76,23],[76,22]],"building":14},
		{"cell":[93,24],"normal":[1,0],"cells":[[94,22],[94,23],[94,24],[94,25],[94,26],[95,22],[95,23],[95,24],[95,25],[95,26],[96,22],[96,23],[96,24],[96,25],[96,26],[97,22],[97,23],[97,24],[97,25],[97,26]],"building":14},
		{"cell":[42,26],"normal":[-1,0],"cells":[[41,28],[41,27],[41,26],[41,25],[41,24],[40,28],[40,27],[40,26],[40,25],[40,24],[39,28],[39,27],[39,26],[39,25],[39,24],[38,28],[38,27],[38,26],[38,25],[38,24]],"building":15},
		{"cell":[53,26],"normal":[1,0],"cells":[[54,24],[54,25],[54,26],[54,27],[54,28],[55,24],[55,25],[55,26],[55,27],[55,28],[56,24],[56,25],[56,26],[56,27],[56,28],[57,24],[57,25],[57,26],[57,27],[57,28]],"building":15}],
	"logs": ["snow_drifts_1"],
	"deep": [{"cell":[64,57],"level":2,"id":"cache_30","distance":95},
		{"cell":[166,86],"level":-1,"id":"cache_127","distance":167}]
}

static func _build_south(repair: bool = true) -> Dictionary:
	var g := FieldGrid.new(WIDTH, SOUTH_HEIGHT)
	var upper := FieldGrid.new(WIDTH, SOUTH_HEIGHT)
	var top := FieldGrid.new(WIDTH, SOUTH_HEIGHT)
	var cellar := FieldGrid.new(WIDTH, SOUTH_HEIGHT)
	upper.solid.fill(S.AIR)
	top.solid.fill(S.AIR)
	cellar.solid.fill(S.BLOCK)
	cellar.opq.fill(1)
	var d := {
		"grid": g, "levels": {0: g, 1: upper, 2: top, -1: cellar},
		"stairs": [], "containers": {}, "spots": {}, "stoves": [],
		"entries": {}, "entry_gap": {}, "entry_levels": {},
		"buildings": [], "wagons": [], "train": Rect2i(16, 1, 80, 3),
		"platform": Rect2i(16, 4, 82, 6), "unload": Rect2i(16, 4, 82, 3),
		"train_cars": [], "spawns": {}, "labels": [], "trees": [],
		"low_blocks": [], "upper_rects": [], "lights": [],
		"manholes": {}, "manhole_levels": {}, "sewer_names": {},
		"anchors": {}, "zone_names": {},
		"place_id": PLACE_ID, "place_kind": "houses",
		"bands": {"lower": Rect2i(0, 4, 116, 26)},
		"train_doors": {"lower": []}, "crossings": [],
		"barricade_slots": [], "interior_kind_slots": [],
		"props": [], "hole_faces": {},
	}
	g.zone.fill("A")
	for row in PLAN["zones"]:
		d["zone_names"][row["id"]] = row["name"]
		var r := _rect(row["rect"])
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				g.zone[g.index(Vector2i(x, y))] = row["id"]
	for row in PLAN["grounds"]:
		_floor(g, _rect(row["rect"]), row["floor"])
	_floor(g, Rect2i(0, 1, WIDTH, 3), F.RAIL)
	_solid(g, d["train"], S.BLOCK)
	_floor(g, d["platform"], F.PLATFORM)
	for n in range(5):
		d["train_cars"].append({"rect": Rect2i(16 + n * 16, 1, 16, 3), "kind": "engine" if n == 4 else "car"})
	for row in PLAN["buildings"]:
		d["buildings"].append({"id": row["id"], "name": row["name"], "rect": _rect(row["rect"]), "warm": false, "window_broken": false,
			"role": String(row.get("role", "")), "top": int(row.get("top", 1))})
	for row in PLAN["shells"]:
		var lg: FieldGrid = d["levels"][row["level"]]
		var r := _rect(row["rect"])
		_shell(lg, r, row["building"], row["level"])
		if row["level"] > 0:
			d["upper_rects"].append({"building": row["building"], "rect": r})
	for row in PLAN["walls"]:
		_solid(d["levels"][row["level"]], _rect(row["rect"]), S.WALL)
	for row in PLAN["doors"]:
		var lg: FieldGrid = d["levels"][row["level"]]
		var c := _cell(row["cell"])
		lg.set_solid(c, S.DOOR)
		lg.doors[c] = {"state": row["state"], "hp": 8, "building": row["building"], "cell": c}
	for row in PLAN["windows"]:
		var lg: FieldGrid = d["levels"][row["level"]]
		var c := _cell(row["cell"])
		lg.set_solid(c, S.WINDOW)
		lg.windows[c] = {"broken": false, "glass": false, "building": row["building"], "cell": c}
	for row in PLAN["stairs"]:
		d["stairs"].append({"cell": _cell(row["cell"]), "low": row["low"], "high": row["high"], "ladder": false})
	for row in PLAN["props"]:
		var prop: Dictionary = row.duplicate(true)
		var r := _rect(row["rect"])
		prop["rect"] = r
		d["props"].append(prop)
		if row["level"] != 0:
			continue
		if row["kind"] == "water":
			_solid(g, r, S.LOW)
			_floor(g, r, F.ICE)
		elif row["solid"] == "low":
			d["low_blocks"].append(r)
			_solid(g, r, S.LOW)
		elif row["solid"] == "wall":
			_solid(g, r, S.WALL)
		elif row["solid"] == "tree":
			d["trees"].append(r.position)
			_solid(g, r, S.BLOCK)
	for row in PLAN["containers"]:
		var box: Dictionary = row.duplicate(true)
		box["cell"] = _cell(row["cell"])
		d["containers"][row["id"]] = box
	for row in PLAN["spots"]:
		var spot: Dictionary = row.duplicate(true)
		spot["cell"] = _cell(row["cell"])
		d["spots"][row["id"]] = spot
		d["spots"][row["id"]].erase("id")
	for row in PLAN["entries"]:
		var cs: Array = []
		for value in row["cells"]:
			cs.append(_cell(value))
		d["entries"][row["id"]] = cs
		d["entry_gap"][row["id"]] = float(row["gap"])
	for row in PLAN["holes"]:
		var c := _cell(row["cell"])
		var id: String = row["id"]
		d["manholes"][id] = c
		d["entries"][id] = [c]
		d["entry_gap"][id] = 3.0 if id.begins_with("manhole_") else 0.6
		d["sewer_names"][id] = row["name"]
		if row["level"] == -1:
			d["manhole_levels"][id] = -1
			d["entry_levels"][id] = -1
		if id.begins_with("manhole_") and row["level"] == 0:
			d["labels"].append({"text": "맨홀", "cell": c + Vector2i(0, -1)})
	for value in PLAN["barricades"]:
		d["barricade_slots"].append(_cell(value))
	for value in PLAN["slots"]:
		d["interior_kind_slots"].append({"zone": value, "kinds": ["empty", "raiders", "nest", "beasts"]})
	var doors: Array = [Vector2i(34, 4), Vector2i(50, 4), Vector2i(66, 4), Vector2i(82, 4)]
	d["train_doors"]["lower"] = doors
	d["spawns"] = {
		"squad": [Vector2i(50, 6), Vector2i(48, 7), Vector2i(52, 7), Vector2i(50, 8)],
		"train_door": doors.duplicate(), "dead_street": [], "dead_levels": [],
	}
	for value in PLAN["dead"]:
		d["spawns"]["dead_street"].append(_cell(value))
	d["anchors"] = {"horde_home": Vector2i(50, 8), "whistle": Vector2i(90, 4), "flee_exit": _cell(PLAN["entries"][0]["cells"][0]), "engine": Vector2i(92, 2)}
	if repair:
		_repair_south(d)
	for lv in d["levels"]:
		var lg: FieldGrid = d["levels"][lv]
		if lv != 0:
			lg.zone = g.zone
		lg.refresh_paths()
	return d


static func _cell(a: Array) -> Vector2i:
	return Vector2i(a[0], a[1])


static func _rect(a: Array) -> Rect2i:
	return Rect2i(a[0], a[1], a[2], a[3])


static func _floor(g: FieldGrid, r: Rect2i, value: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			g.floor[g.index(Vector2i(x, y))] = value


static func _solid(g: FieldGrid, r: Rect2i, value: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			g.set_solid(Vector2i(x, y), value)


static func _shell(g: FieldGrid, r: Rect2i, id: int, level: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			g.building[g.index(c)] = id
			g.floor[g.index(c)] = F.GRAVEL if level < 0 else F.WOOD
			var wall: bool = x == r.position.x or x == r.end.x - 1 or y == r.position.y or y == r.end.y - 1
			g.set_solid(c, S.WALL if wall else S.NONE)

# 북쪽은 새 좌표이며 각 방과 길은 이 지도만의 평면이다.
const NORTH: Dictionary = {
	"number": 2,
	"width": 180,
	"height": 46,
	"judgment": "식량이 아래쪽 목재보다 훨씬 많은 대신 자루와 궤가 무거워 여러 번 날라야 하고, 날라 오는 사람이 빠진 아래쪽 문 곁은 비어 있다.",
	"zones": [
		{
			"id": "I",
			"name": "서쪽 공터",
			"rect": [
				0,
				0,
				22,
				46
			]
		},
		{
			"id": "J",
			"name": "저장 마당",
			"rect": [
				22,
				0,
				94,
				46
			]
		},
		{
			"id": "K",
			"name": "동쪽 텃밭",
			"rect": [
				116,
				0,
				64,
				46
			]
		}
	],
	"grounds": [
		{
			"rect": [
				22,
				0,
				5,
				13
			],
			"floor": 1
		},
		{
			"rect": [
				22,
				8,
				83,
				5
			],
			"floor": 1
		},
		{
			"rect": [
				100,
				0,
				5,
				13
			],
			"floor": 1
		},
		{
			"rect": [
				105,
				10,
				75,
				4
			],
			"floor": 1
		},
		{
			"rect": [
				60,
				13,
				6,
				30
			],
			"floor": 1
		},
		{
			"rect": [
				92,
				13,
				5,
				30
			],
			"floor": 1
		},
		{
			"rect": [
				0,
				24,
				22,
				19
			],
			"floor": 5
		},
		{
			"rect": [
				120,
				14,
				34,
				10
			],
			"floor": 7
		},
		{
			"rect": [
				134,
				25,
				35,
				15
			],
			"floor": 5
		},
		{
			"rect": [
				12,
				39,
				4,
				7
			],
			"floor": 1
		},
		{
			"rect": [
				96,
				39,
				4,
				7
			],
			"floor": 1
		},
		{
			"rect": [
				16,
				43,
				80,
				3
			],
			"floor": 7
		}
	],
	"buildings": [
		{
			"id": 16,
			"name": "저장 광 가",
			"rect": [
				30,
				14,
				30,
				10
			],
			"top": 2,
			"basement": true,
			"role": "store",
			"stock": [
				"sack_pile",
				"tin_crate",
				"jar_shelf",
				"flour_sack_pile"
			]
		},
		{
			"id": 17,
			"name": "관리 사무실",
			"rect": [
				66,
				15,
				12,
				9
			],
			"top": 1,
			"basement": false,
			"role": "store",
			"stock": [
				"desk",
				"office_cabinet",
				"shelf"
			]
		},
		{
			"id": 18,
			"name": "식품 조합 가게",
			"rect": [
				78,
				14,
				14,
				10
			],
			"top": 2,
			"basement": false,
			"role": "shop",
			"stock": [
				"tin_crate",
				"flour_sack_pile",
				"shelf"
			]
		},
		{
			"id": 19,
			"name": "차고",
			"rect": [
				97,
				15,
				23,
				9
			],
			"top": 1,
			"basement": false,
			"role": "store",
			"stock": [
				"parts_rack",
				"barrel",
				"handcart"
			]
		},
		{
			"id": 20,
			"name": "사일로 가",
			"rect": [
				38,
				1,
				6,
				6
			],
			"top": 1,
			"basement": false,
			"role": "store",
			"stock": [
				"sack_pile",
				"barrel",
				"shelf"
			]
		},
		{
			"id": 21,
			"name": "사일로 나",
			"rect": [
				70,
				1,
				6,
				6
			],
			"top": 1,
			"basement": false,
			"role": "store",
			"stock": [
				"flour_sack_pile",
				"barrel",
				"shelf"
			]
		},
		{
			"id": 22,
			"name": "연립 집",
			"rect": [
				116,
				24,
				18,
				16
			],
			"top": 2,
			"basement": true,
			"role": "home",
			"stock": [
				"sack_pile",
				"tin_crate",
				"jar_shelf",
				"flour_sack_pile"
			]
		},
		{
			"id": 23,
			"name": "서북 저장 광 나",
			"rect": [
				3,
				1,
				16,
				9
			],
			"top": 1,
			"basement": true,
			"role": "store",
			"stock": [
				"sack_pile",
				"tin_crate",
				"jar_shelf",
				"flour_sack_pile"
			]
		}
	],
	"shells": [
		{
			"rect": [
				30,
				14,
				30,
				10
			],
			"building": 16,
			"level": -1
		},
		{
			"rect": [
				30,
				14,
				30,
				10
			],
			"building": 16,
			"level": 0
		},
		{
			"rect": [
				30,
				14,
				30,
				10
			],
			"building": 16,
			"level": 1
		},
		{
			"rect": [
				66,
				15,
				12,
				9
			],
			"building": 17,
			"level": 0
		},
		{
			"rect": [
				78,
				14,
				14,
				10
			],
			"building": 18,
			"level": 0
		},
		{
			"rect": [
				78,
				14,
				14,
				10
			],
			"building": 18,
			"level": 1
		},
		{
			"rect": [
				97,
				15,
				23,
				9
			],
			"building": 19,
			"level": 0
		},
		{
			"rect": [
				38,
				1,
				6,
				6
			],
			"building": 20,
			"level": 0
		},
		{
			"rect": [
				70,
				1,
				6,
				6
			],
			"building": 21,
			"level": 0
		},
		{
			"rect": [
				116,
				24,
				18,
				16
			],
			"building": 22,
			"level": -1
		},
		{
			"rect": [
				116,
				24,
				18,
				16
			],
			"building": 22,
			"level": 0
		},
		{
			"rect": [
				116,
				24,
				18,
				16
			],
			"building": 22,
			"level": 1
		},
		{
			"rect": [
				3,
				1,
				16,
				9
			],
			"building": 23,
			"level": -1
		},
		{
			"rect": [
				3,
				1,
				16,
				9
			],
			"building": 23,
			"level": 0
		}
	],
	"walls": [
		{
			"rect": [
				31,
				20,
				28,
				1
			],
			"level": -1
		},
		{
			"rect": [
				35,
				15,
				1,
				5
			],
			"level": -1
		},
		{
			"rect": [
				40,
				15,
				1,
				5
			],
			"level": -1
		},
		{
			"rect": [
				45,
				15,
				1,
				5
			],
			"level": -1
		},
		{
			"rect": [
				50,
				15,
				1,
				5
			],
			"level": -1
		},
		{
			"rect": [
				55,
				15,
				1,
				5
			],
			"level": -1
		},
		{
			"rect": [
				31,
				20,
				28,
				1
			],
			"level": 0
		},
		{
			"rect": [
				35,
				15,
				1,
				5
			],
			"level": 0
		},
		{
			"rect": [
				40,
				15,
				1,
				5
			],
			"level": 0
		},
		{
			"rect": [
				45,
				15,
				1,
				5
			],
			"level": 0
		},
		{
			"rect": [
				50,
				15,
				1,
				5
			],
			"level": 0
		},
		{
			"rect": [
				55,
				15,
				1,
				5
			],
			"level": 0
		},
		{
			"rect": [
				31,
				20,
				28,
				1
			],
			"level": 1
		},
		{
			"rect": [
				35,
				15,
				1,
				5
			],
			"level": 1
		},
		{
			"rect": [
				40,
				15,
				1,
				5
			],
			"level": 1
		},
		{
			"rect": [
				45,
				15,
				1,
				5
			],
			"level": 1
		},
		{
			"rect": [
				50,
				15,
				1,
				5
			],
			"level": 1
		},
		{
			"rect": [
				55,
				15,
				1,
				5
			],
			"level": 1
		},
		{
			"rect": [
				67,
				20,
				10,
				1
			],
			"level": 0
		},
		{
			"rect": [
				72,
				16,
				1,
				4
			],
			"level": 0
		},
		{
			"rect": [
				79,
				19,
				12,
				1
			],
			"level": 0
		},
		{
			"rect": [
				79,
				19,
				12,
				1
			],
			"level": 1
		},
		{
			"rect": [
				98,
				20,
				21,
				1
			],
			"level": 0
		},
		{
			"rect": [
				105,
				16,
				1,
				4
			],
			"level": 0
		},
		{
			"rect": [
				112,
				16,
				1,
				4
			],
			"level": 0
		},
		{
			"rect": [
				117,
				36,
				16,
				1
			],
			"level": -1
		},
		{
			"rect": [
				125,
				25,
				1,
				11
			],
			"level": -1
		},
		{
			"rect": [
				117,
				36,
				16,
				1
			],
			"level": 0
		},
		{
			"rect": [
				125,
				25,
				1,
				11
			],
			"level": 0
		},
		{
			"rect": [
				117,
				36,
				16,
				1
			],
			"level": 1
		},
		{
			"rect": [
				125,
				25,
				1,
				11
			],
			"level": 1
		},
		{
			"rect": [
				4,
				6,
				14,
				1
			],
			"level": -1
		},
		{
			"rect": [
				11,
				2,
				1,
				4
			],
			"level": -1
		},
		{
			"rect": [
				4,
				6,
				14,
				1
			],
			"level": 0
		},
		{
			"rect": [
				11,
				2,
				1,
				4
			],
			"level": 0
		}
	],
	"doors": [
		{
			"cell": [
				33,
				20
			],
			"level": -1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				38,
				20
			],
			"level": -1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				43,
				20
			],
			"level": -1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				48,
				20
			],
			"level": -1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				53,
				20
			],
			"level": -1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				57,
				20
			],
			"level": -1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				33,
				20
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				38,
				20
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				43,
				20
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				48,
				20
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				53,
				20
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				57,
				20
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				45,
				23
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				33,
				20
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				38,
				20
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				43,
				20
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				48,
				20
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				53,
				20
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				57,
				20
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				69,
				20
			],
			"level": 0,
			"building": 17,
			"state": "closed"
		},
		{
			"cell": [
				75,
				20
			],
			"level": 0,
			"building": 17,
			"state": "closed"
		},
		{
			"cell": [
				72,
				23
			],
			"level": 0,
			"building": 17,
			"state": "closed"
		},
		{
			"cell": [
				85,
				19
			],
			"level": 0,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				85,
				23
			],
			"level": 0,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				85,
				14
			],
			"level": 0,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				85,
				19
			],
			"level": 1,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				101,
				20
			],
			"level": 0,
			"building": 19,
			"state": "closed"
		},
		{
			"cell": [
				109,
				20
			],
			"level": 0,
			"building": 19,
			"state": "closed"
		},
		{
			"cell": [
				116,
				20
			],
			"level": 0,
			"building": 19,
			"state": "closed"
		},
		{
			"cell": [
				108,
				23
			],
			"level": 0,
			"building": 19,
			"state": "closed"
		},
		{
			"cell": [
				40,
				6
			],
			"level": 0,
			"building": 20,
			"state": "closed"
		},
		{
			"cell": [
				72,
				6
			],
			"level": 0,
			"building": 21,
			"state": "closed"
		},
		{
			"cell": [
				121,
				36
			],
			"level": -1,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				129,
				36
			],
			"level": -1,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				121,
				36
			],
			"level": 0,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				129,
				36
			],
			"level": 0,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				125,
				39
			],
			"level": 0,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				121,
				36
			],
			"level": 1,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				129,
				36
			],
			"level": 1,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				7,
				6
			],
			"level": -1,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				15,
				6
			],
			"level": -1,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				7,
				6
			],
			"level": 0,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				15,
				6
			],
			"level": 0,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				11,
				9
			],
			"level": 0,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				33,
				14
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		}
	],
	"windows": [
		{
			"cell": [
				38,
				14
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				43,
				14
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				48,
				14
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				53,
				14
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				57,
				14
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				69,
				15
			],
			"level": 0,
			"building": 17
		},
		{
			"cell": [
				75,
				15
			],
			"level": 0,
			"building": 17
		},
		{
			"cell": [
				101,
				15
			],
			"level": 0,
			"building": 19
		},
		{
			"cell": [
				109,
				15
			],
			"level": 0,
			"building": 19
		},
		{
			"cell": [
				116,
				15
			],
			"level": 0,
			"building": 19
		},
		{
			"cell": [
				41,
				1
			],
			"level": 0,
			"building": 20
		},
		{
			"cell": [
				73,
				1
			],
			"level": 0,
			"building": 21
		},
		{
			"cell": [
				121,
				24
			],
			"level": 0,
			"building": 22
		},
		{
			"cell": [
				129,
				24
			],
			"level": 0,
			"building": 22
		},
		{
			"cell": [
				7,
				1
			],
			"level": 0,
			"building": 23
		},
		{
			"cell": [
				15,
				1
			],
			"level": 0,
			"building": 23
		}
	],
	"stairs": [
		{
			"cell": [
				32,
				21
			],
			"low": -1,
			"high": 0
		},
		{
			"cell": [
				32,
				21
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				57,
				21
			],
			"low": -1,
			"high": 0
		},
		{
			"cell": [
				57,
				21
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				89,
				16
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				118,
				37
			],
			"low": -1,
			"high": 0
		},
		{
			"cell": [
				118,
				37
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				5,
				7
			],
			"low": -1,
			"high": 0
		}
	],
	"rooms": [
		{
			"rect": [
				31,
				15,
				4,
				5
			],
			"building": 16,
			"level": -1,
			"use": "입고 방"
		},
		{
			"rect": [
				36,
				15,
				4,
				5
			],
			"building": 16,
			"level": -1,
			"use": "비축 방"
		},
		{
			"rect": [
				41,
				15,
				4,
				5
			],
			"building": 16,
			"level": -1,
			"use": "작업 방"
		},
		{
			"rect": [
				46,
				15,
				4,
				5
			],
			"building": 16,
			"level": -1,
			"use": "접수 방"
		},
		{
			"rect": [
				51,
				15,
				4,
				5
			],
			"building": 16,
			"level": -1,
			"use": "보관 방"
		},
		{
			"rect": [
				56,
				15,
				3,
				5
			],
			"building": 16,
			"level": -1,
			"use": "안쪽 광"
		},
		{
			"rect": [
				31,
				15,
				4,
				5
			],
			"building": 16,
			"level": 0,
			"use": "입고 방"
		},
		{
			"rect": [
				36,
				15,
				4,
				5
			],
			"building": 16,
			"level": 0,
			"use": "비축 방"
		},
		{
			"rect": [
				41,
				15,
				4,
				5
			],
			"building": 16,
			"level": 0,
			"use": "작업 방"
		},
		{
			"rect": [
				46,
				15,
				4,
				5
			],
			"building": 16,
			"level": 0,
			"use": "접수 방"
		},
		{
			"rect": [
				51,
				15,
				4,
				5
			],
			"building": 16,
			"level": 0,
			"use": "보관 방"
		},
		{
			"rect": [
				56,
				15,
				3,
				5
			],
			"building": 16,
			"level": 0,
			"use": "안쪽 광"
		},
		{
			"rect": [
				31,
				15,
				4,
				5
			],
			"building": 16,
			"level": 1,
			"use": "입고 방"
		},
		{
			"rect": [
				36,
				15,
				4,
				5
			],
			"building": 16,
			"level": 1,
			"use": "비축 방"
		},
		{
			"rect": [
				41,
				15,
				4,
				5
			],
			"building": 16,
			"level": 1,
			"use": "작업 방"
		},
		{
			"rect": [
				46,
				15,
				4,
				5
			],
			"building": 16,
			"level": 1,
			"use": "접수 방"
		},
		{
			"rect": [
				51,
				15,
				4,
				5
			],
			"building": 16,
			"level": 1,
			"use": "보관 방"
		},
		{
			"rect": [
				56,
				15,
				3,
				5
			],
			"building": 16,
			"level": 1,
			"use": "안쪽 광"
		},
		{
			"rect": [
				67,
				16,
				5,
				4
			],
			"building": 17,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				73,
				16,
				4,
				4
			],
			"building": 17,
			"level": 0,
			"use": "보관 칸"
		},
		{
			"rect": [
				79,
				15,
				12,
				4
			],
			"building": 18,
			"level": 0,
			"use": "뒤 창고"
		},
		{
			"rect": [
				79,
				20,
				12,
				3
			],
			"building": 18,
			"level": 0,
			"use": "매장"
		},
		{
			"rect": [
				79,
				15,
				12,
				4
			],
			"building": 18,
			"level": 1,
			"use": "뒤 창고"
		},
		{
			"rect": [
				79,
				20,
				12,
				3
			],
			"building": 18,
			"level": 1,
			"use": "매장"
		},
		{
			"rect": [
				98,
				16,
				7,
				4
			],
			"building": 19,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				106,
				16,
				6,
				4
			],
			"building": 19,
			"level": 0,
			"use": "보관 칸"
		},
		{
			"rect": [
				113,
				16,
				6,
				4
			],
			"building": 19,
			"level": 0,
			"use": "보관 칸"
		},
		{
			"rect": [
				39,
				2,
				4,
				4
			],
			"building": 20,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				71,
				2,
				4,
				4
			],
			"building": 21,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				117,
				25,
				8,
				11
			],
			"building": 22,
			"level": -1,
			"use": "살림방"
		},
		{
			"rect": [
				126,
				25,
				7,
				11
			],
			"building": 22,
			"level": -1,
			"use": "부엌"
		},
		{
			"rect": [
				117,
				25,
				8,
				11
			],
			"building": 22,
			"level": 0,
			"use": "살림방"
		},
		{
			"rect": [
				126,
				25,
				7,
				11
			],
			"building": 22,
			"level": 0,
			"use": "부엌"
		},
		{
			"rect": [
				117,
				25,
				8,
				11
			],
			"building": 22,
			"level": 1,
			"use": "살림방"
		},
		{
			"rect": [
				126,
				25,
				7,
				11
			],
			"building": 22,
			"level": 1,
			"use": "부엌"
		},
		{
			"rect": [
				4,
				2,
				7,
				4
			],
			"building": 23,
			"level": -1,
			"use": "작업 칸"
		},
		{
			"rect": [
				12,
				2,
				6,
				4
			],
			"building": 23,
			"level": -1,
			"use": "보관 칸"
		},
		{
			"rect": [
				4,
				2,
				7,
				4
			],
			"building": 23,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				12,
				2,
				6,
				4
			],
			"building": 23,
			"level": 0,
			"use": "보관 칸"
		}
	],
	"props": [
		{
			"kind": "sack_pile",
			"rect": [
				31,
				15,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 입고 방의 자루 더미",
			"level": -1
		},
		{
			"kind": "tin_crate",
			"rect": [
				31,
				19,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 입고 방의 통조림 상자",
			"level": -1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				31,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 입고 방의 병조림 선반",
			"level": -1
		},
		{
			"kind": "sack_pile",
			"rect": [
				36,
				15,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 비축 방의 자루 더미",
			"level": -1
		},
		{
			"kind": "tin_crate",
			"rect": [
				36,
				19,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 비축 방의 통조림 상자",
			"level": -1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				36,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 비축 방의 병조림 선반",
			"level": -1
		},
		{
			"kind": "sack_pile",
			"rect": [
				41,
				15,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 작업 방의 자루 더미",
			"level": -1
		},
		{
			"kind": "tin_crate",
			"rect": [
				41,
				19,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 작업 방의 통조림 상자",
			"level": -1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				41,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 작업 방의 병조림 선반",
			"level": -1
		},
		{
			"kind": "sack_pile",
			"rect": [
				46,
				15,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 접수 방의 자루 더미",
			"level": -1
		},
		{
			"kind": "tin_crate",
			"rect": [
				46,
				19,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 접수 방의 통조림 상자",
			"level": -1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				46,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 접수 방의 병조림 선반",
			"level": -1
		},
		{
			"kind": "sack_pile",
			"rect": [
				51,
				15,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 보관 방의 자루 더미",
			"level": -1
		},
		{
			"kind": "tin_crate",
			"rect": [
				51,
				19,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 보관 방의 통조림 상자",
			"level": -1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				51,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 보관 방의 병조림 선반",
			"level": -1
		},
		{
			"kind": "sack_pile",
			"rect": [
				56,
				15,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 안쪽 광의 자루 더미",
			"level": -1
		},
		{
			"kind": "tin_crate",
			"rect": [
				56,
				17,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 안쪽 광의 통조림 상자",
			"level": -1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				56,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 안쪽 광의 병조림 선반",
			"level": -1
		},
		{
			"kind": "sack_pile",
			"rect": [
				31,
				15,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "저장 광 가 입고 방의 자루 더미",
			"level": 0
		},
		{
			"kind": "tin_crate",
			"rect": [
				31,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "저장 광 가 입고 방의 통조림 상자",
			"level": 0
		},
		{
			"kind": "sack_pile",
			"rect": [
				36,
				15,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "저장 광 가 비축 방의 자루 더미",
			"level": 0
		},
		{
			"kind": "tin_crate",
			"rect": [
				36,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "저장 광 가 비축 방의 통조림 상자",
			"level": 0
		},
		{
			"kind": "flour_sack_pile",
			"rect": [
				38,
				15,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "저장 광 가 비축 방의 밀가루 자루",
			"level": 0
		},
		{
			"kind": "sack_pile",
			"rect": [
				41,
				15,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "저장 광 가 작업 방의 자루 더미",
			"level": 0
		},
		{
			"kind": "tin_crate",
			"rect": [
				41,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "저장 광 가 작업 방의 통조림 상자",
			"level": 0
		},
		{
			"kind": "flour_sack_pile",
			"rect": [
				43,
				15,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "저장 광 가 작업 방의 밀가루 자루",
			"level": 0
		},
		{
			"kind": "sack_pile",
			"rect": [
				46,
				15,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "저장 광 가 접수 방의 자루 더미",
			"level": 0
		},
		{
			"kind": "tin_crate",
			"rect": [
				46,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "저장 광 가 접수 방의 통조림 상자",
			"level": 0
		},
		{
			"kind": "flour_sack_pile",
			"rect": [
				48,
				15,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "저장 광 가 접수 방의 밀가루 자루",
			"level": 0
		},
		{
			"kind": "sack_pile",
			"rect": [
				51,
				15,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "저장 광 가 보관 방의 자루 더미",
			"level": 0
		},
		{
			"kind": "tin_crate",
			"rect": [
				51,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "저장 광 가 보관 방의 통조림 상자",
			"level": 0
		},
		{
			"kind": "flour_sack_pile",
			"rect": [
				53,
				15,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "저장 광 가 보관 방의 밀가루 자루",
			"level": 0
		},
		{
			"kind": "sack_pile",
			"rect": [
				56,
				15,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "저장 광 가 안쪽 광의 자루 더미",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				58,
				15,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "저장 광 가 안쪽 광의 통",
			"level": 0
		},
		{
			"kind": "cold_stove",
			"rect": [
				56,
				19,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "저장 광 가 안쪽 광의 꺼진 난로",
			"level": 0
		},
		{
			"kind": "sack_pile",
			"rect": [
				31,
				15,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 입고 방의 자루 더미",
			"level": 1
		},
		{
			"kind": "tin_crate",
			"rect": [
				31,
				19,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 입고 방의 통조림 상자",
			"level": 1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				31,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 입고 방의 병조림 선반",
			"level": 1
		},
		{
			"kind": "sack_pile",
			"rect": [
				36,
				15,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 비축 방의 자루 더미",
			"level": 1
		},
		{
			"kind": "tin_crate",
			"rect": [
				36,
				19,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 비축 방의 통조림 상자",
			"level": 1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				36,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 비축 방의 병조림 선반",
			"level": 1
		},
		{
			"kind": "sack_pile",
			"rect": [
				41,
				15,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 작업 방의 자루 더미",
			"level": 1
		},
		{
			"kind": "tin_crate",
			"rect": [
				41,
				19,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 작업 방의 통조림 상자",
			"level": 1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				41,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 작업 방의 병조림 선반",
			"level": 1
		},
		{
			"kind": "sack_pile",
			"rect": [
				46,
				15,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 접수 방의 자루 더미",
			"level": 1
		},
		{
			"kind": "tin_crate",
			"rect": [
				46,
				19,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 접수 방의 통조림 상자",
			"level": 1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				46,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 접수 방의 병조림 선반",
			"level": 1
		},
		{
			"kind": "sack_pile",
			"rect": [
				51,
				15,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 보관 방의 자루 더미",
			"level": 1
		},
		{
			"kind": "tin_crate",
			"rect": [
				51,
				19,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 보관 방의 통조림 상자",
			"level": 1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				51,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 보관 방의 병조림 선반",
			"level": 1
		},
		{
			"kind": "sack_pile",
			"rect": [
				56,
				15,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 안쪽 광의 자루 더미",
			"level": 1
		},
		{
			"kind": "tin_crate",
			"rect": [
				56,
				17,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 안쪽 광의 통조림 상자",
			"level": 1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				56,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "저장 광 가 안쪽 광의 병조림 선반",
			"level": 1
		},
		{
			"kind": "desk",
			"rect": [
				67,
				16,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "관리 사무실 작업 칸의 책상",
			"level": 0
		},
		{
			"kind": "office_cabinet",
			"rect": [
				67,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "관리 사무실 작업 칸의 서류장",
			"level": 0
		},
		{
			"kind": "shelf",
			"rect": [
				69,
				16,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "관리 사무실 작업 칸의 선반",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				73,
				16,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "관리 사무실 보관 칸의 책상",
			"level": 0
		},
		{
			"kind": "office_cabinet",
			"rect": [
				73,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "관리 사무실 보관 칸의 서류장",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				76,
				16,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "관리 사무실 보관 칸의 통",
			"level": 0
		},
		{
			"kind": "tin_crate",
			"rect": [
				79,
				15,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "식품 조합 가게 뒤 창고의 통조림 상자",
			"level": 0
		},
		{
			"kind": "flour_sack_pile",
			"rect": [
				79,
				16,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "식품 조합 가게 뒤 창고의 밀가루 자루",
			"level": 0
		},
		{
			"kind": "shelf",
			"rect": [
				79,
				18,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "식품 조합 가게 뒤 창고의 선반",
			"level": 0
		},
		{
			"kind": "display_shelf",
			"rect": [
				79,
				20,
				4,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "식품 조합 가게 매장의 진열대",
			"level": 0
		},
		{
			"kind": "shop_counter",
			"rect": [
				79,
				22,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "식품 조합 가게 매장의 계산대",
			"level": 0
		},
		{
			"kind": "tin_crate",
			"rect": [
				89,
				20,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "식품 조합 가게 매장의 통조림 상자",
			"level": 0
		},
		{
			"kind": "tin_crate",
			"rect": [
				79,
				15,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "식품 조합 가게 뒤 창고의 통조림 상자",
			"level": 1
		},
		{
			"kind": "flour_sack_pile",
			"rect": [
				79,
				16,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "식품 조합 가게 뒤 창고의 밀가루 자루",
			"level": 1
		},
		{
			"kind": "shelf",
			"rect": [
				79,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "식품 조합 가게 뒤 창고의 선반",
			"level": 1
		},
		{
			"kind": "display_shelf",
			"rect": [
				79,
				20,
				4,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "식품 조합 가게 매장의 진열대",
			"level": 1
		},
		{
			"kind": "shop_counter",
			"rect": [
				79,
				22,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "식품 조합 가게 매장의 계산대",
			"level": 1
		},
		{
			"kind": "tin_crate",
			"rect": [
				89,
				20,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "식품 조합 가게 매장의 통조림 상자",
			"level": 1
		},
		{
			"kind": "parts_rack",
			"rect": [
				98,
				16,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "차고 작업 칸의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				104,
				16,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "차고 작업 칸의 통",
			"level": 0
		},
		{
			"kind": "handcart",
			"rect": [
				98,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "차고 작업 칸의 손수레",
			"level": 0
		},
		{
			"kind": "parts_rack",
			"rect": [
				106,
				16,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "차고 보관 칸의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				111,
				16,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "차고 보관 칸의 통",
			"level": 0
		},
		{
			"kind": "handcart",
			"rect": [
				106,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "차고 보관 칸의 손수레",
			"level": 0
		},
		{
			"kind": "parts_rack",
			"rect": [
				113,
				16,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "차고 보관 칸의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				118,
				16,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "차고 보관 칸의 통",
			"level": 0
		},
		{
			"kind": "handcart",
			"rect": [
				113,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "차고 보관 칸의 손수레",
			"level": 0
		},
		{
			"kind": "sack_pile",
			"rect": [
				41,
				2,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "사일로 가 작업 칸의 자루 더미",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				39,
				2,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "사일로 가 작업 칸의 통",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				39,
				5,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "사일로 가 작업 칸의 통",
			"level": 0
		},
		{
			"kind": "flour_sack_pile",
			"rect": [
				73,
				2,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "사일로 나 작업 칸의 밀가루 자루",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				71,
				2,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "사일로 나 작업 칸의 통",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				74,
				5,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "사일로 나 작업 칸의 통",
			"level": 0
		},
		{
			"kind": "bed",
			"rect": [
				117,
				25,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 살림방의 침대",
			"level": -1
		},
		{
			"kind": "wardrobe",
			"rect": [
				117,
				35,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 살림방의 장롱",
			"level": -1
		},
		{
			"kind": "desk",
			"rect": [
				123,
				25,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 살림방의 책상",
			"level": -1
		},
		{
			"kind": "dining_set",
			"rect": [
				126,
				25,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 부엌의 식탁",
			"level": -1
		},
		{
			"kind": "fridge_open",
			"rect": [
				132,
				25,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 부엌의 냉장고",
			"level": -1
		},
		{
			"kind": "cold_stove",
			"rect": [
				126,
				35,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 부엌의 꺼진 난로",
			"level": -1
		},
		{
			"kind": "bed",
			"rect": [
				117,
				25,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "연립 집 살림방의 침대",
			"level": 0
		},
		{
			"kind": "wardrobe",
			"rect": [
				117,
				35,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "연립 집 살림방의 장롱",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				123,
				25,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "연립 집 살림방의 책상",
			"level": 0
		},
		{
			"kind": "dining_set",
			"rect": [
				126,
				25,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "연립 집 부엌의 식탁",
			"level": 0
		},
		{
			"kind": "fridge_open",
			"rect": [
				132,
				25,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "연립 집 부엌의 냉장고",
			"level": 0
		},
		{
			"kind": "cold_stove",
			"rect": [
				126,
				35,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "연립 집 부엌의 꺼진 난로",
			"level": 0
		},
		{
			"kind": "bed",
			"rect": [
				117,
				25,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 살림방의 침대",
			"level": 1
		},
		{
			"kind": "wardrobe",
			"rect": [
				117,
				35,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 살림방의 장롱",
			"level": 1
		},
		{
			"kind": "desk",
			"rect": [
				123,
				25,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 살림방의 책상",
			"level": 1
		},
		{
			"kind": "dining_set",
			"rect": [
				126,
				25,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 부엌의 식탁",
			"level": 1
		},
		{
			"kind": "fridge_open",
			"rect": [
				132,
				25,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 부엌의 냉장고",
			"level": 1
		},
		{
			"kind": "cold_stove",
			"rect": [
				126,
				35,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 부엌의 꺼진 난로",
			"level": 1
		},
		{
			"kind": "sack_pile",
			"rect": [
				4,
				2,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "서북 저장 광 나 작업 칸의 자루 더미",
			"level": -1
		},
		{
			"kind": "tin_crate",
			"rect": [
				4,
				5,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "서북 저장 광 나 작업 칸의 통조림 상자",
			"level": -1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				4,
				4,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "서북 저장 광 나 작업 칸의 병조림 선반",
			"level": -1
		},
		{
			"kind": "sack_pile",
			"rect": [
				12,
				2,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "서북 저장 광 나 보관 칸의 자루 더미",
			"level": -1
		},
		{
			"kind": "tin_crate",
			"rect": [
				12,
				5,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "서북 저장 광 나 보관 칸의 통조림 상자",
			"level": -1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				12,
				4,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "서북 저장 광 나 보관 칸의 병조림 선반",
			"level": -1
		},
		{
			"kind": "sack_pile",
			"rect": [
				4,
				2,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "서북 저장 광 나 작업 칸의 자루 더미",
			"level": 0
		},
		{
			"kind": "tin_crate",
			"rect": [
				4,
				5,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "서북 저장 광 나 작업 칸의 통조림 상자",
			"level": 0
		},
		{
			"kind": "jar_shelf",
			"rect": [
				4,
				4,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "서북 저장 광 나 작업 칸의 병조림 선반",
			"level": 0
		},
		{
			"kind": "sack_pile",
			"rect": [
				12,
				2,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "서북 저장 광 나 보관 칸의 자루 더미",
			"level": 0
		},
		{
			"kind": "tin_crate",
			"rect": [
				12,
				5,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "서북 저장 광 나 보관 칸의 통조림 상자",
			"level": 0
		},
		{
			"kind": "jar_shelf",
			"rect": [
				12,
				4,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "서북 저장 광 나 보관 칸의 병조림 선반",
			"level": 0
		},
		{
			"kind": "sack_pile",
			"rect": [
				22,
				40,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "자루 더미",
			"level": 0
		},
		{
			"kind": "car",
			"rect": [
				46,
				35,
				2,
				4
			],
			"solid": "low",
			"facing": 0,
			"note": "버려진 차",
			"level": 0
		},
		{
			"kind": "pallet_stack",
			"rect": [
				72,
				39,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "팰릿 더미",
			"level": 0
		},
		{
			"kind": "bench",
			"rect": [
				92,
				29,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "긴 의자",
			"level": 0
		},
		{
			"kind": "fieldstone_wall",
			"rect": [
				116,
				40,
				1,
				6
			],
			"solid": "low",
			"facing": 0,
			"note": "마당의 작업 물건",
			"level": 0
		},
		{
			"kind": "garden_bed",
			"rect": [
				123,
				16,
				4,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "텃밭 틀",
			"level": 0
		},
		{
			"kind": "garden_bed",
			"rect": [
				130,
				20,
				4,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "텃밭 틀",
			"level": 0
		},
		{
			"kind": "bench",
			"rect": [
				137,
				20,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "긴 의자",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				130,
				16,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "통",
			"level": 0
		},
		{
			"kind": "well_cover",
			"rect": [
				136,
				16,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "우물 뚜껑",
			"level": 0
		},
		{
			"kind": "street_tree",
			"rect": [
				3,
				16,
				1,
				1
			],
			"solid": "tree",
			"facing": 0,
			"note": "눈 덮인 마른 나무 무리",
			"level": 0
		},
		{
			"kind": "street_tree",
			"rect": [
				7,
				18,
				1,
				1
			],
			"solid": "tree",
			"facing": 0,
			"note": "눈 덮인 마른 나무 무리",
			"level": 0
		},
		{
			"kind": "street_tree",
			"rect": [
				10,
				21,
				1,
				1
			],
			"solid": "tree",
			"facing": 0,
			"note": "눈 덮인 마른 나무 무리",
			"level": 0
		},
		{
			"kind": "street_tree",
			"rect": [
				4,
				23,
				1,
				1
			],
			"solid": "tree",
			"facing": 0,
			"note": "눈 덮인 마른 나무 무리",
			"level": 0
		},
		{
			"kind": "street_tree",
			"rect": [
				28,
				1,
				1,
				1
			],
			"solid": "tree",
			"facing": 0,
			"note": "눈 덮인 마른 나무 무리",
			"level": 0
		},
		{
			"kind": "street_tree",
			"rect": [
				31,
				3,
				1,
				1
			],
			"solid": "tree",
			"facing": 0,
			"note": "눈 덮인 마른 나무 무리",
			"level": 0
		},
		{
			"kind": "street_tree",
			"rect": [
				33,
				6,
				1,
				1
			],
			"solid": "tree",
			"facing": 0,
			"note": "눈 덮인 마른 나무 무리",
			"level": 0
		},
		{
			"kind": "bare_orchard_tree",
			"rect": [
				142,
				16,
				1,
				1
			],
			"solid": "tree",
			"facing": 0,
			"note": "눈 덮인 마른 나무 무리",
			"level": 0
		},
		{
			"kind": "bare_orchard_tree",
			"rect": [
				146,
				18,
				1,
				1
			],
			"solid": "tree",
			"facing": 0,
			"note": "눈 덮인 마른 나무 무리",
			"level": 0
		},
		{
			"kind": "bare_orchard_tree",
			"rect": [
				150,
				16,
				1,
				1
			],
			"solid": "tree",
			"facing": 0,
			"note": "눈 덮인 마른 나무 무리",
			"level": 0
		},
		{
			"kind": "bare_orchard_tree",
			"rect": [
				144,
				22,
				1,
				1
			],
			"solid": "tree",
			"facing": 0,
			"note": "눈 덮인 마른 나무 무리",
			"level": 0
		},
		{
			"kind": "bare_orchard_tree",
			"rect": [
				149,
				21,
				1,
				1
			],
			"solid": "tree",
			"facing": 0,
			"note": "눈 덮인 마른 나무 무리",
			"level": 0
		}
	],
	"containers": [
		{
			"id": "north_cache_0",
			"name": "저장 광 가 입고 방 상자",
			"cell": [
				34,
				15
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_1",
			"name": "저장 광 가 비축 방 상자",
			"cell": [
				39,
				15
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_2",
			"name": "저장 광 가 작업 방 상자",
			"cell": [
				44,
				15
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_3",
			"name": "저장 광 가 접수 방 상자",
			"cell": [
				49,
				15
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_4",
			"name": "저장 광 가 보관 방 상자",
			"cell": [
				54,
				15
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_5",
			"name": "저장 광 가 안쪽 광 상자",
			"cell": [
				58,
				15
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_6",
			"name": "저장 광 가 입고 방 상자",
			"cell": [
				34,
				19
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_7",
			"name": "저장 광 가 비축 방 상자",
			"cell": [
				39,
				19
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_8",
			"name": "저장 광 가 작업 방 상자",
			"cell": [
				44,
				19
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_9",
			"name": "저장 광 가 접수 방 상자",
			"cell": [
				49,
				19
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_10",
			"name": "저장 광 가 보관 방 상자",
			"cell": [
				54,
				19
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_11",
			"name": "저장 광 가 안쪽 광 상자",
			"cell": [
				58,
				19
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_12",
			"name": "저장 광 가 입고 방 상자",
			"cell": [
				34,
				15
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_13",
			"name": "저장 광 가 비축 방 상자",
			"cell": [
				39,
				15
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_14",
			"name": "저장 광 가 작업 방 상자",
			"cell": [
				44,
				15
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_15",
			"name": "저장 광 가 접수 방 상자",
			"cell": [
				49,
				15
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_16",
			"name": "저장 광 가 보관 방 상자",
			"cell": [
				54,
				15
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_17",
			"name": "저장 광 가 안쪽 광 상자",
			"cell": [
				58,
				15
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_18",
			"name": "관리 사무실 작업 칸 상자",
			"cell": [
				71,
				19
			],
			"level": 0,
			"building": 17,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_19",
			"name": "관리 사무실 보관 칸 상자",
			"cell": [
				76,
				19
			],
			"level": 0,
			"building": 17,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_20",
			"name": "식품 조합 가게 뒤 창고 상자",
			"cell": [
				90,
				15
			],
			"level": 0,
			"building": 18,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_21",
			"name": "식품 조합 가게 매장 상자",
			"cell": [
				90,
				22
			],
			"level": 0,
			"building": 18,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_22",
			"name": "식품 조합 가게 뒤 창고 상자",
			"cell": [
				90,
				15
			],
			"level": 1,
			"building": 18,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_23",
			"name": "식품 조합 가게 매장 상자",
			"cell": [
				90,
				22
			],
			"level": 1,
			"building": 18,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_24",
			"name": "차고 작업 칸 상자",
			"cell": [
				104,
				19
			],
			"level": 0,
			"building": 19,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_25",
			"name": "차고 보관 칸 상자",
			"cell": [
				111,
				19
			],
			"level": 0,
			"building": 19,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_26",
			"name": "차고 보관 칸 상자",
			"cell": [
				118,
				19
			],
			"level": 0,
			"building": 19,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_27",
			"name": "사일로 가 작업 칸 상자",
			"cell": [
				42,
				5
			],
			"level": 0,
			"building": 20,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_28",
			"name": "사일로 나 작업 칸 상자",
			"cell": [
				71,
				5
			],
			"level": 0,
			"building": 21,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_29",
			"name": "연립 집 살림방 상자",
			"cell": [
				124,
				35
			],
			"level": -1,
			"building": 22,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_30",
			"name": "연립 집 부엌 상자",
			"cell": [
				132,
				35
			],
			"level": -1,
			"building": 22,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_31",
			"name": "연립 집 살림방 상자",
			"cell": [
				124,
				35
			],
			"level": 0,
			"building": 22,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_32",
			"name": "연립 집 부엌 상자",
			"cell": [
				132,
				35
			],
			"level": 0,
			"building": 22,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_33",
			"name": "연립 집 살림방 상자",
			"cell": [
				124,
				35
			],
			"level": 1,
			"building": 22,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_34",
			"name": "연립 집 부엌 상자",
			"cell": [
				132,
				35
			],
			"level": 1,
			"building": 22,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_35",
			"name": "서북 저장 광 나 작업 칸 상자",
			"cell": [
				10,
				2
			],
			"level": -1,
			"building": 23,
			"search": 7,
			"items": [
				"food_pack",
				"food_pack"
			],
			"locked": true,
			"searched": false
		},
		{
			"id": "north_cache_36",
			"name": "서북 저장 광 나 보관 칸 상자",
			"cell": [
				17,
				2
			],
			"level": -1,
			"building": 23,
			"search": 7,
			"items": [
				"food_pack",
				"food_pack"
			],
			"locked": true,
			"searched": false
		},
		{
			"id": "north_cache_37",
			"name": "서북 저장 광 나 작업 칸 상자",
			"cell": [
				10,
				2
			],
			"level": 0,
			"building": 23,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_38",
			"name": "서북 저장 광 나 보관 칸 상자",
			"cell": [
				17,
				2
			],
			"level": 0,
			"building": 23,
			"search": 4,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_shallow",
			"name": "승강장 뒤 작은 보급 상자",
			"cell": [
				41,
				36
			],
			"level": 0,
			"building": -1,
			"search": 2,
			"items": [
				"food_pack"
			],
			"locked": false,
			"searched": false
		}
	],
	"entries": [
		{
			"id": "서쪽 저장 길",
			"name": "서쪽 저장 길",
			"cells": [
				[
					23,
					0
				],
				[
					24,
					0
				],
				[
					25,
					0
				],
				[
					26,
					0
				]
			],
			"gap": 0.6
		},
		{
			"id": "동쪽 저장 길",
			"name": "동쪽 저장 길",
			"cells": [
				[
					101,
					0
				],
				[
					102,
					0
				],
				[
					103,
					0
				],
				[
					104,
					0
				]
			],
			"gap": 0.6
		},
		{
			"id": "텃밭 샛길",
			"name": "텃밭 샛길",
			"cells": [
				[
					179,
					10
				],
				[
					179,
					11
				],
				[
					179,
					12
				],
				[
					179,
					13
				]
			],
			"gap": 2.5
		}
	],
	"holes": [],
	"barricades": [
		[
			61,
			22
		],
		[
			64,
			22
		],
		[
			93,
			22
		],
		[
			95,
			22
		]
	],
	"slots": [
		"I"
	],
	"deep": 7,
	"forecourts": [
		[
			43,
			24,
			5,
			4
		],
		[
			70,
			24,
			5,
			4
		],
		[
			83,
			24,
			5,
			4
		],
		[
			106,
			24,
			5,
			4
		],
		[
			38,
			7,
			5,
			4
		],
		[
			70,
			7,
			5,
			4
		],
		[
			123,
			40,
			5,
			4
		],
		[
			9,
			10,
			5,
			4
		]
	],
	"crossings": [
		32,
		48
	],
	"stock": [
		"sack_pile",
		"tin_crate",
		"jar_shelf",
		"flour_sack_pile"
	],
	"loot": [
		"food_pack"
	],
	"assumptions": [
		"동쪽 연립의 서쪽 벽을 띠 바깥 한 줄에 붙이고 아래 여섯 칸은 짧은 들돌 담으로 닫았다.",
		"사일로는 들어갈 수 있는 작은 저장 몸통이며 연기나 이름표를 두지 않았다.",
		"앞쪽 복도 출입문과 북쪽 입고 문을 따로 두었다."
	]
}

const SOUTH_TREE_MOVES: Array = [[[110,40],[108,41]],[[99,32],[106,30]],[[105,39],[113,42]],[[160,50],[153,51]],[[81,40],[79,41]],[[146,53],[149,51]],[[151,54],[151,48]],[[148,65],[151,63]]]
const SOUTH_WORK: Dictionary = {"name":"공동 목공 작업 구역","cell":[90,81],"rect":[78,79,24,10]}

static func _build_plain() -> Dictionary:
	var data: Dictionary = _build_south()
	# 여기까지는 옛 좌표(열차가 맨 위 y 1~3), 아래부터는 새 좌표(열차 y 46~48)
	data = MapShift.shift_rows(data, 45)
	assert(data["train"] == Rect2i(16, 46, 80, 3))
	assert(data["grid"].height == HEIGHT)
	_add_north(data)
	for lv in data["levels"]:
		var grid: FieldGrid = data["levels"][lv]
		if lv != 0:
			grid.zone = data["grid"].zone.duplicate()
		# 이동된 격자의 문과 창은 내부 좌표도 새 사전 키와 맞춘다.
		for c in grid.doors:
			grid.doors[c]["cell"] = c
		for c in grid.windows:
			grid.windows[c]["cell"] = c
		grid.refresh_paths()
	return data


static func _repair_south(data: Dictionary) -> void:
	var grid: FieldGrid = data["grid"]
	for row in SOUTH_TREE_MOVES:
		var before := _cell(row[0])
		var after := _cell(row[1])
		grid.set_solid(before, S.NONE)
		grid.set_solid(after, S.BLOCK)
		var index: int = data["trees"].find(before)
		assert(index >= 0)
		data["trees"][index] = after
		for prop in data["props"]:
			if prop["solid"] == "tree" and prop["rect"].position == before:
				prop["rect"] = Rect2i(after, Vector2i.ONE)
	data["spots"]["work_site"] = {
		"kind": "work_site", "name": SOUTH_WORK["name"], "state": "closed",
		"cell": _cell(SOUTH_WORK["cell"]), "zone_rect": _rect(SOUTH_WORK["rect"]),
	}


static func _add_north(data: Dictionary) -> void:
	var g: FieldGrid = data["grid"]
	data["bands"]["upper"] = Rect2i(-4, 24, 120, 22).intersection(Rect2i(0, 0, WIDTH, HEIGHT))
	data["train_doors"]["upper"] = []
	for c: Vector2i in data["train_doors"]["lower"]:
		data["train_doors"]["upper"].append(Vector2i(c.x, 45))
		data["barricade_slots"].append(Vector2i(c.x, 44))
		data["barricade_slots"].append(Vector2i(c.x, 50))
	for x in NORTH["crossings"]:
		data["crossings"].append({
			"cells": [Vector2i(x, 46), Vector2i(x, 47), Vector2i(x, 48)],
			"who": {"person": true, "zombie": false, "carrying": true, "wounded": false, "sled": false},
		})
	for row in NORTH["zones"]:
		data["zone_names"][row["id"]] = row["name"]
		var r := _rect(row["rect"])
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				g.zone[g.index(Vector2i(x, y))] = row["id"]
	for row in NORTH["grounds"]:
		_floor(g, _rect(row["rect"]), row["floor"])
	for row in NORTH["buildings"]:
		data["buildings"].append({"id": row["id"], "name": row["name"], "rect": _rect(row["rect"]), "warm": false, "window_broken": false,
			"role": String(row.get("role", "")), "top": int(row.get("top", 1))})
	for row in NORTH["shells"]:
		var grid: FieldGrid = data["levels"][row["level"]]
		var r := _rect(row["rect"])
		_shell(grid, r, row["building"], row["level"])
		if row["level"] > 0:
			data["upper_rects"].append({"building": row["building"], "rect": r})
	for row in NORTH["walls"]:
		_solid(data["levels"][row["level"]], _rect(row["rect"]), S.WALL)
	for row in NORTH["doors"]:
		var grid: FieldGrid = data["levels"][row["level"]]
		var c := _cell(row["cell"])
		grid.set_solid(c, S.DOOR)
		grid.doors[c] = {"state": row["state"], "hp": 8, "building": row["building"], "cell": c}
	for row in NORTH["windows"]:
		var grid: FieldGrid = data["levels"][row["level"]]
		var c := _cell(row["cell"])
		grid.set_solid(c, S.WINDOW)
		grid.windows[c] = {"broken": false, "glass": false, "building": row["building"], "cell": c}
	for row in NORTH["stairs"]:
		data["stairs"].append({"cell": _cell(row["cell"]), "low": row["low"], "high": row["high"], "ladder": false})
	for row in NORTH["props"]:
		var prop: Dictionary = row.duplicate(true)
		var r := _rect(row["rect"])
		prop["rect"] = r
		data["props"].append(prop)
		if row["level"] != 0:
			continue
		match row["solid"]:
			"low":
				_solid(g, r, S.LOW)
				if row["kind"] == "water":
					_floor(g, r, F.ICE)
				else:
					data["low_blocks"].append(r)
			"wall":
				_solid(g, r, S.WALL)
			"tree":
				data["trees"].append(r.position)
				_solid(g, r, S.BLOCK)
	for row in NORTH["containers"]:
		var box: Dictionary = row.duplicate(true)
		box["cell"] = _cell(row["cell"])
		data["containers"][row["id"]] = box
	for row in NORTH["entries"]:
		var cs: Array = []
		for c in row["cells"]:
			cs.append(_cell(c))
		data["entries"][row["id"]] = cs
		data["entry_gap"][row["id"]] = float(row["gap"])
	for row in NORTH["holes"]:
		var c := _cell(row["cell"])
		var id: String = row["id"]
		data["manholes"][id] = c
		data["entries"][id] = [c]
		data["entry_gap"][id] = 3.0
		data["sewer_names"][id] = row["name"]
	for c in NORTH["barricades"]:
		data["barricade_slots"].append(_cell(c))
	for zone in NORTH["slots"]:
		data["interior_kind_slots"].append({"zone": zone, "kinds": ["empty", "raiders", "nest", "beasts"]})
	# 승차 구역은 가구와 건물에서 떨어져 있으며 옛 맨 위 줄도 연다.
	_solid(g, Rect2i(16, 43, 80, 3), S.NONE)
	data["anchors"]["horde_home_upper"] = Vector2i(66, 45)


## 무전 문장에 쓰는 들어오는 길의 이름, 길마다의 비중, 첫 물결이 오는 길.
const ENTRY_NAMES: Dictionary = {"west_path": "서쪽 오솔길", "south_road": "남쪽 길", "east_path": "동쪽 오솔길", "east_lower": "동쪽 아랫길", "manhole_01": "첫째 맨홀", "manhole_02": "둘째 맨홀", "manhole_03": "셋째 맨홀", "manhole_04": "넷째 맨홀", "서쪽 저장 길": "서쪽 저장 길", "동쪽 저장 길": "동쪽 저장 길", "텃밭 샛길": "텃밭 샛길"}
const ENTRY_WEIGHTS: Dictionary = {"west_path": 0.5, "south_road": 1.0, "east_path": 1.0, "east_lower": 0.5, "manhole_01": 0.3, "manhole_02": 0.3, "manhole_03": 0.3, "manhole_04": 0.3, "서쪽 저장 길": 1.0, "동쪽 저장 길": 1.0, "텃밭 샛길": 0.5}
const FIRST_ENTRY: String = "south_road"


static func build() -> Dictionary:
	var data: Dictionary = _build_plain()
	data["entry_names"] = ENTRY_NAMES.duplicate()
	data["entry_weights"] = ENTRY_WEIGHTS.duplicate()
	data["first_entry"] = FIRST_ENTRY
	return data
