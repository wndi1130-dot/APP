# 이 지도가 다른 판단을 만드는 것: 큰길은 빠르나 시끄럽고 뒷골목은 조용하나 길다.
# 위쪽의 판단: 철물과 부품을 얻는 대신 아래쪽 목공방 앞의 목재 한 짐을 놓치고, 가장 값진 부품은 막다른 뒷거리 끝 창고에 있어 걸음이 길다.
extends RefCounted

const FieldGrid = preload("res://game/world/field_grid.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 170
const SOUTH_HEIGHT: int = 100
const HEIGHT: int = SOUTH_HEIGHT + 45
const PLACE_ID: String = "houses_01"

# 각 좌표는 이 지도의 독립 평면이다. 위층 장식은 충돌을 만들지 않는다.
const PLAN: Dictionary = {
	"number": 1,
	"width": 170,
	"height": 100,
	"judgment": "큰길은 빠르나 시끄럽고 뒷골목은 조용하나 길다.",
	"zones": [{"id":"A","name":"승강장 앞","rect":[0,0,170,30]},
		{"id":"B","name":"가게 뒷골목","rect":[0,30,70,18]},
		{"id":"C","name":"목공 마당","rect":[70,30,100,18]},
		{"id":"D","name":"연립 마당","rect":[0,48,35,52]},
		{"id":"E","name":"우물 마당","rect":[35,48,35,52]},
		{"id":"F","name":"동쪽 살림 골목","rect":[70,48,100,52]},
		{"id":"G","name":"강둑","rect":[0,82,170,18]},
		{"id":"H","name":"동쪽 연립","rect":[130,4,40,26]}],
	"grounds": [{"rect":[64,10,6,90],"floor":1},
		{"rect":[0,43,170,5],"floor":1},
		{"rect":[0,77,170,5],"floor":1},
		{"rect":[6,18,4,59],"floor":1},
		{"rect":[0,30,20,4],"floor":1},
		{"rect":[6,39,58,4],"floor":1},
		{"rect":[138,43,4,34],"floor":1},
		{"rect":[138,59,32,4],"floor":1},
		{"rect":[0,10,28,18],"floor":5},
		{"rect":[116,10,12,16],"floor":7}],
	"buildings": [{"name":"빵집","rect":[48,28,16,12],"top":2,"basement":false,"role":"shop","stock":["bread_rack","shop_counter","crate_stack"],"id":0},
		{"name":"식료품점","rect":[30,10,24,14],"top":2,"basement":true,"role":"shop","stock":["display_shelf","shop_counter","tin_crate"],"id":1},
		{"name":"철물점","rect":[20,28,22,12],"top":2,"basement":false,"role":"shop","stock":["hardware_rack","desk","barrel"],"id":2},
		{"name":"잡화점","rect":[100,29,16,10],"top":2,"basement":false,"role":"shop","stock":["display_shelf","shop_counter","shelf"],"id":3},
		{"name":"목공방","rect":[70,28,24,14],"top":1,"basement":false,"role":"shed","stock":["door_pile","desk","firewood_pile"],"id":4},
		{"name":"하숙집","rect":[88,10,22,14],"top":3,"basement":false,"role":"home","id":5},
		{"name":"연립 가 동","rect":[10,49,40,24],"top":3,"basement":true,"role":"home","main":true,"id":6},
		{"name":"연립 나 동","rect":[110,50,28,20],"top":3,"basement":false,"role":"home","id":7},
		{"name":"연립 다 동","rect":[130,10,30,18],"top":3,"basement":false,"role":"home","id":8},
		{"name":"연립 라 동","rect":[76,52,28,18],"top":3,"basement":false,"role":"home","id":9},
		{"name":"공동 세탁장","rect":[120,32,12,8],"top":1,"basement":false,"role":"shed","mode":"vertical","id":10},
		{"name":"공동 창고","rect":[70,12,14,10],"top":1,"basement":false,"role":"shed","id":11},
		{"name":"차고","rect":[136,32,12,8],"top":1,"basement":false,"role":"shed","id":12},
		{"name":"차고","rect":[154,50,12,8],"top":1,"basement":false,"role":"shed","id":13},
		{"name":"우물집","rect":[54,57,8,8],"top":1,"basement":false,"role":"shed","id":14},
		{"name":"장작 헛간","rect":[154,32,12,8],"top":1,"basement":false,"role":"shed","id":15},
		{"name":"강변 창고","rect":[142,63,24,12],"top":1,"basement":false,"role":"shed","stock":["barrel","sack_pile","ice_sled_load"],"id":16},
		{"name":"다리 어귀 매점","rect":[114,12,12,10],"top":1,"basement":false,"role":"shop","stock":["shop_counter","bread_rack","barrel"],"id":17}],
	"entries": [{"id":"west_alley","cells":[[0,30],[0,31],[0,32]],"gap":2},
		{"id":"west_bank","cells":[[0,77],[0,78],[0,79],[0,80]],"gap":0.6},
		{"id":"east_street","cells":[[169,44],[169,45],[169,46],[169,47]],"gap":0.6},
		{"id":"east_back","cells":[[169,59],[169,60],[169,61]],"gap":2},
		{"id":"south_bridge","cells":[[64,99],[65,99],[66,99],[67,99]],"gap":0.6}],
	"holes": [{"id":"manhole_01","cell":[71,47],"name":"네거리 맨홀","level":0},
		{"id":"manhole_02","cell":[56,69],"name":"우물 곁 맨홀","level":0},
		{"id":"manhole_03","cell":[58,79],"name":"다리 어귀 맨홀","level":0},
		{"id":"manhole_04","cell":[118,74],"name":"안마당 맨홀","level":0}],
	"barricades": [[65,29],[67,29],[44,29],[46,29],[95,29],[97,29]],
	"deepBuildings": [6,16],
	"deepLevels": [2,0],
	"assumptions": ["띠 안이던 서쪽 진입점은 서쪽 가장자리의 남쪽 굽이로 옮겼다.","건물 사이 보행 틈을 확보하고 우물 곁과 안마당 맨홀을 열린 마당으로 옮겼다.","강둑 길은 창고 남쪽으로 내려 다리 어귀의 빈 땅을 확보했다.","동쪽 강둑이 남쪽으로 휘어 강의 북쪽 가장자리를 좌우 다르게 만들었다."],
	"tx": 16,
	"band": [0,4,116,26],
	"shells": [{"building":0,"level":0,"rect":[48,28,16,12]},
		{"building":0,"level":1,"rect":[48,28,16,12]},
		{"building":1,"level":0,"rect":[30,10,24,14]},
		{"building":1,"level":1,"rect":[30,10,24,14]},
		{"building":1,"level":-1,"rect":[30,10,24,14]},
		{"building":2,"level":0,"rect":[20,28,22,12]},
		{"building":2,"level":1,"rect":[20,28,22,12]},
		{"building":3,"level":0,"rect":[100,29,16,10]},
		{"building":3,"level":1,"rect":[100,29,16,10]},
		{"building":4,"level":0,"rect":[70,28,24,14]},
		{"building":5,"level":0,"rect":[88,10,22,14]},
		{"building":5,"level":1,"rect":[88,10,22,14]},
		{"building":5,"level":2,"rect":[88,10,22,14]},
		{"building":6,"level":0,"rect":[10,49,40,24]},
		{"building":6,"level":1,"rect":[10,49,40,24]},
		{"building":6,"level":2,"rect":[10,49,40,24]},
		{"building":6,"level":-1,"rect":[10,49,40,24]},
		{"building":7,"level":0,"rect":[110,50,28,20]},
		{"building":7,"level":1,"rect":[110,50,28,20]},
		{"building":7,"level":2,"rect":[110,50,28,20]},
		{"building":8,"level":0,"rect":[130,10,30,18]},
		{"building":8,"level":1,"rect":[130,10,30,18]},
		{"building":8,"level":2,"rect":[130,10,30,18]},
		{"building":9,"level":0,"rect":[76,52,28,18]},
		{"building":9,"level":1,"rect":[76,52,28,18]},
		{"building":9,"level":2,"rect":[76,52,28,18]},
		{"building":10,"level":0,"rect":[120,32,12,8]},
		{"building":11,"level":0,"rect":[70,12,14,10]},
		{"building":12,"level":0,"rect":[136,32,12,8]},
		{"building":13,"level":0,"rect":[154,50,12,8]},
		{"building":14,"level":0,"rect":[54,57,8,8]},
		{"building":15,"level":0,"rect":[154,32,12,8]},
		{"building":16,"level":0,"rect":[142,63,24,12]},
		{"building":17,"level":0,"rect":[114,12,12,10]}],
	"walls": [{"building":0,"level":0,"rect":[49,32,14,1]},
		{"building":0,"level":0,"rect":[49,35,14,1]},
		{"building":0,"level":1,"rect":[49,32,14,1]},
		{"building":0,"level":1,"rect":[49,35,14,1]},
		{"building":1,"level":0,"rect":[31,14,22,1]},
		{"building":1,"level":0,"rect":[31,19,22,1]},
		{"building":1,"level":0,"rect":[42,11,1,3]},
		{"building":1,"level":0,"rect":[42,20,1,3]},
		{"building":1,"level":1,"rect":[31,14,22,1]},
		{"building":1,"level":1,"rect":[31,19,22,1]},
		{"building":1,"level":1,"rect":[42,11,1,3]},
		{"building":1,"level":1,"rect":[42,20,1,3]},
		{"building":1,"level":-1,"rect":[31,14,22,1]},
		{"building":1,"level":-1,"rect":[31,19,22,1]},
		{"building":1,"level":-1,"rect":[42,11,1,3]},
		{"building":1,"level":-1,"rect":[42,20,1,3]},
		{"building":2,"level":0,"rect":[21,32,20,1]},
		{"building":2,"level":0,"rect":[21,35,20,1]},
		{"building":2,"level":0,"rect":[31,29,1,3]},
		{"building":2,"level":0,"rect":[31,36,1,3]},
		{"building":2,"level":1,"rect":[21,32,20,1]},
		{"building":2,"level":1,"rect":[21,35,20,1]},
		{"building":2,"level":1,"rect":[31,29,1,3]},
		{"building":2,"level":1,"rect":[31,36,1,3]},
		{"building":3,"level":0,"rect":[108,30,1,8]},
		{"building":3,"level":1,"rect":[108,30,1,8]},
		{"building":4,"level":0,"rect":[71,33,22,1]},
		{"building":4,"level":0,"rect":[71,36,22,1]},
		{"building":4,"level":0,"rect":[82,29,1,4]},
		{"building":4,"level":0,"rect":[82,37,1,4]},
		{"building":5,"level":0,"rect":[89,15,20,1]},
		{"building":5,"level":0,"rect":[89,18,20,1]},
		{"building":5,"level":0,"rect":[99,11,1,4]},
		{"building":5,"level":0,"rect":[99,19,1,4]},
		{"building":5,"level":1,"rect":[89,15,20,1]},
		{"building":5,"level":1,"rect":[89,18,20,1]},
		{"building":5,"level":1,"rect":[99,11,1,4]},
		{"building":5,"level":1,"rect":[99,19,1,4]},
		{"building":5,"level":2,"rect":[89,15,20,1]},
		{"building":5,"level":2,"rect":[89,18,20,1]},
		{"building":5,"level":2,"rect":[99,11,1,4]},
		{"building":5,"level":2,"rect":[99,19,1,4]},
		{"building":6,"level":0,"rect":[11,59,38,1]},
		{"building":6,"level":0,"rect":[11,62,38,1]},
		{"building":6,"level":0,"rect":[11,54,6,1]},
		{"building":6,"level":0,"rect":[17,50,1,9]},
		{"building":6,"level":0,"rect":[18,54,6,1]},
		{"building":6,"level":0,"rect":[24,50,1,9]},
		{"building":6,"level":0,"rect":[25,54,6,1]},
		{"building":6,"level":0,"rect":[31,50,1,9]},
		{"building":6,"level":0,"rect":[32,54,5,1]},
		{"building":6,"level":0,"rect":[37,50,1,9]},
		{"building":6,"level":0,"rect":[38,54,5,1]},
		{"building":6,"level":0,"rect":[43,50,1,9]},
		{"building":6,"level":0,"rect":[44,54,5,1]},
		{"building":6,"level":0,"rect":[11,67,6,1]},
		{"building":6,"level":0,"rect":[17,63,1,9]},
		{"building":6,"level":0,"rect":[18,67,6,1]},
		{"building":6,"level":0,"rect":[24,63,1,9]},
		{"building":6,"level":0,"rect":[25,67,6,1]},
		{"building":6,"level":0,"rect":[31,63,1,9]},
		{"building":6,"level":0,"rect":[32,67,5,1]},
		{"building":6,"level":0,"rect":[37,63,1,9]},
		{"building":6,"level":0,"rect":[38,67,5,1]},
		{"building":6,"level":0,"rect":[43,63,1,9]},
		{"building":6,"level":0,"rect":[44,67,5,1]},
		{"building":6,"level":1,"rect":[11,59,38,1]},
		{"building":6,"level":1,"rect":[11,62,38,1]},
		{"building":6,"level":1,"rect":[11,54,6,1]},
		{"building":6,"level":1,"rect":[17,50,1,9]},
		{"building":6,"level":1,"rect":[18,54,6,1]},
		{"building":6,"level":1,"rect":[24,50,1,9]},
		{"building":6,"level":1,"rect":[25,54,6,1]},
		{"building":6,"level":1,"rect":[31,50,1,9]},
		{"building":6,"level":1,"rect":[32,54,5,1]},
		{"building":6,"level":1,"rect":[37,50,1,9]},
		{"building":6,"level":1,"rect":[38,54,5,1]},
		{"building":6,"level":1,"rect":[43,50,1,9]},
		{"building":6,"level":1,"rect":[44,54,5,1]},
		{"building":6,"level":1,"rect":[11,67,6,1]},
		{"building":6,"level":1,"rect":[17,63,1,9]},
		{"building":6,"level":1,"rect":[18,67,6,1]},
		{"building":6,"level":1,"rect":[24,63,1,9]},
		{"building":6,"level":1,"rect":[25,67,6,1]},
		{"building":6,"level":1,"rect":[31,63,1,9]},
		{"building":6,"level":1,"rect":[32,67,5,1]},
		{"building":6,"level":1,"rect":[37,63,1,9]},
		{"building":6,"level":1,"rect":[38,67,5,1]},
		{"building":6,"level":1,"rect":[43,63,1,9]},
		{"building":6,"level":1,"rect":[44,67,5,1]},
		{"building":6,"level":2,"rect":[11,59,38,1]},
		{"building":6,"level":2,"rect":[11,62,38,1]},
		{"building":6,"level":2,"rect":[11,54,6,1]},
		{"building":6,"level":2,"rect":[17,50,1,9]},
		{"building":6,"level":2,"rect":[18,54,6,1]},
		{"building":6,"level":2,"rect":[24,50,1,9]},
		{"building":6,"level":2,"rect":[25,54,6,1]},
		{"building":6,"level":2,"rect":[31,50,1,9]},
		{"building":6,"level":2,"rect":[32,54,5,1]},
		{"building":6,"level":2,"rect":[37,50,1,9]},
		{"building":6,"level":2,"rect":[38,54,5,1]},
		{"building":6,"level":2,"rect":[43,50,1,9]},
		{"building":6,"level":2,"rect":[44,54,5,1]},
		{"building":6,"level":2,"rect":[11,67,6,1]},
		{"building":6,"level":2,"rect":[17,63,1,9]},
		{"building":6,"level":2,"rect":[18,67,6,1]},
		{"building":6,"level":2,"rect":[24,63,1,9]},
		{"building":6,"level":2,"rect":[25,67,6,1]},
		{"building":6,"level":2,"rect":[31,63,1,9]},
		{"building":6,"level":2,"rect":[32,67,5,1]},
		{"building":6,"level":2,"rect":[37,63,1,9]},
		{"building":6,"level":2,"rect":[38,67,5,1]},
		{"building":6,"level":2,"rect":[43,63,1,9]},
		{"building":6,"level":2,"rect":[44,67,5,1]},
		{"building":6,"level":-1,"rect":[11,59,38,1]},
		{"building":6,"level":-1,"rect":[11,62,38,1]},
		{"building":6,"level":-1,"rect":[11,54,6,1]},
		{"building":6,"level":-1,"rect":[17,50,1,9]},
		{"building":6,"level":-1,"rect":[18,54,6,1]},
		{"building":6,"level":-1,"rect":[24,50,1,9]},
		{"building":6,"level":-1,"rect":[25,54,6,1]},
		{"building":6,"level":-1,"rect":[31,50,1,9]},
		{"building":6,"level":-1,"rect":[32,54,5,1]},
		{"building":6,"level":-1,"rect":[37,50,1,9]},
		{"building":6,"level":-1,"rect":[38,54,5,1]},
		{"building":6,"level":-1,"rect":[43,50,1,9]},
		{"building":6,"level":-1,"rect":[44,54,5,1]},
		{"building":6,"level":-1,"rect":[11,67,6,1]},
		{"building":6,"level":-1,"rect":[17,63,1,9]},
		{"building":6,"level":-1,"rect":[18,67,6,1]},
		{"building":6,"level":-1,"rect":[24,63,1,9]},
		{"building":6,"level":-1,"rect":[25,67,6,1]},
		{"building":6,"level":-1,"rect":[31,63,1,9]},
		{"building":6,"level":-1,"rect":[32,67,5,1]},
		{"building":6,"level":-1,"rect":[37,63,1,9]},
		{"building":6,"level":-1,"rect":[38,67,5,1]},
		{"building":6,"level":-1,"rect":[43,63,1,9]},
		{"building":6,"level":-1,"rect":[44,67,5,1]},
		{"building":7,"level":0,"rect":[111,58,26,1]},
		{"building":7,"level":0,"rect":[111,61,26,1]},
		{"building":7,"level":0,"rect":[119,51,1,7]},
		{"building":7,"level":0,"rect":[128,51,1,7]},
		{"building":7,"level":0,"rect":[119,62,1,7]},
		{"building":7,"level":0,"rect":[128,62,1,7]},
		{"building":7,"level":1,"rect":[111,58,26,1]},
		{"building":7,"level":1,"rect":[111,61,26,1]},
		{"building":7,"level":1,"rect":[119,51,1,7]},
		{"building":7,"level":1,"rect":[128,51,1,7]},
		{"building":7,"level":1,"rect":[119,62,1,7]},
		{"building":7,"level":1,"rect":[128,62,1,7]},
		{"building":7,"level":2,"rect":[111,58,26,1]},
		{"building":7,"level":2,"rect":[111,61,26,1]},
		{"building":7,"level":2,"rect":[119,51,1,7]},
		{"building":7,"level":2,"rect":[128,51,1,7]},
		{"building":7,"level":2,"rect":[119,62,1,7]},
		{"building":7,"level":2,"rect":[128,62,1,7]},
		{"building":8,"level":0,"rect":[131,17,28,1]},
		{"building":8,"level":0,"rect":[131,20,28,1]},
		{"building":8,"level":0,"rect":[140,11,1,6]},
		{"building":8,"level":0,"rect":[150,11,1,6]},
		{"building":8,"level":0,"rect":[140,21,1,6]},
		{"building":8,"level":0,"rect":[150,21,1,6]},
		{"building":8,"level":1,"rect":[131,17,28,1]},
		{"building":8,"level":1,"rect":[131,20,28,1]},
		{"building":8,"level":1,"rect":[140,11,1,6]},
		{"building":8,"level":1,"rect":[150,11,1,6]},
		{"building":8,"level":1,"rect":[140,21,1,6]},
		{"building":8,"level":1,"rect":[150,21,1,6]},
		{"building":8,"level":2,"rect":[131,17,28,1]},
		{"building":8,"level":2,"rect":[131,20,28,1]},
		{"building":8,"level":2,"rect":[140,11,1,6]},
		{"building":8,"level":2,"rect":[150,11,1,6]},
		{"building":8,"level":2,"rect":[140,21,1,6]},
		{"building":8,"level":2,"rect":[150,21,1,6]},
		{"building":9,"level":0,"rect":[77,59,26,1]},
		{"building":9,"level":0,"rect":[77,62,26,1]},
		{"building":9,"level":0,"rect":[85,53,1,6]},
		{"building":9,"level":0,"rect":[94,53,1,6]},
		{"building":9,"level":0,"rect":[85,63,1,6]},
		{"building":9,"level":0,"rect":[94,63,1,6]},
		{"building":9,"level":1,"rect":[77,59,26,1]},
		{"building":9,"level":1,"rect":[77,62,26,1]},
		{"building":9,"level":1,"rect":[85,53,1,6]},
		{"building":9,"level":1,"rect":[94,53,1,6]},
		{"building":9,"level":1,"rect":[85,63,1,6]},
		{"building":9,"level":1,"rect":[94,63,1,6]},
		{"building":9,"level":2,"rect":[77,59,26,1]},
		{"building":9,"level":2,"rect":[77,62,26,1]},
		{"building":9,"level":2,"rect":[85,53,1,6]},
		{"building":9,"level":2,"rect":[94,53,1,6]},
		{"building":9,"level":2,"rect":[85,63,1,6]},
		{"building":9,"level":2,"rect":[94,63,1,6]},
		{"building":10,"level":0,"rect":[124,33,1,6]},
		{"building":10,"level":0,"rect":[127,33,1,6]},
		{"building":11,"level":0,"rect":[77,13,1,8]},
		{"building":12,"level":0,"rect":[142,33,1,6]},
		{"building":13,"level":0,"rect":[160,51,1,6]},
		{"building":15,"level":0,"rect":[160,33,1,6]},
		{"building":16,"level":0,"rect":[143,67,22,1]},
		{"building":16,"level":0,"rect":[143,70,22,1]},
		{"building":16,"level":0,"rect":[154,64,1,3]},
		{"building":16,"level":0,"rect":[154,71,1,3]},
		{"building":17,"level":0,"rect":[120,13,1,8]}],
	"doors": [{"cell":[56,32],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[56,35],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[48,33],"building":0,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[63,33],"building":0,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[56,32],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[56,35],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[36,14],"building":1,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[48,14],"building":1,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[36,19],"building":1,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[48,19],"building":1,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[30,15],"building":1,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[53,15],"building":1,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[36,14],"building":1,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[48,14],"building":1,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[36,19],"building":1,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[48,19],"building":1,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[36,14],"building":1,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[48,14],"building":1,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[36,19],"building":1,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[48,19],"building":1,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[26,32],"building":2,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[36,32],"building":2,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[26,35],"building":2,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[36,35],"building":2,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[20,33],"building":2,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[41,33],"building":2,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[26,32],"building":2,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[36,32],"building":2,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[26,35],"building":2,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[36,35],"building":2,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[108,34],"building":3,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[100,34],"building":3,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[115,34],"building":3,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[108,34],"building":3,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[76,33],"building":4,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[88,33],"building":4,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[76,36],"building":4,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[88,36],"building":4,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[70,34],"building":4,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[93,34],"building":4,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[94,15],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[104,15],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[94,18],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[104,18],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[88,16],"building":5,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[109,16],"building":5,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[94,15],"building":5,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[104,15],"building":5,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[94,18],"building":5,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[104,18],"building":5,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[94,15],"building":5,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[104,15],"building":5,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[94,18],"building":5,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[104,18],"building":5,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[14,54],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[14,59],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[21,54],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[21,59],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[28,54],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[28,59],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,54],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,59],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[40,54],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[40,59],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[46,54],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[46,59],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[14,67],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[14,62],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[21,67],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[21,62],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[28,67],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[28,62],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,67],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,62],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[40,67],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[40,62],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[46,67],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[46,62],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[10,60],"building":6,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[49,60],"building":6,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[14,54],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[14,59],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[21,54],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[21,59],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[28,54],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[28,59],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,54],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,59],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[40,54],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[40,59],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[46,54],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[46,59],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[14,67],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[14,62],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[21,67],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[21,62],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[28,67],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[28,62],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,67],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,62],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[40,67],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[40,62],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[46,67],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[46,62],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[14,54],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[14,59],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[21,54],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[21,59],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[28,54],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[28,59],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,54],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,59],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[40,54],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[40,59],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[46,54],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[46,59],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[14,67],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[14,62],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[21,67],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[21,62],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[28,67],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[28,62],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,67],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,62],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[40,67],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[40,62],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[46,67],"building":6,"level":2,"state":"closed","normal":[0,1],"external":false},
		{"cell":[46,62],"building":6,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[14,54],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[14,59],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[21,54],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[21,59],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[28,54],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[28,59],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,54],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,59],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[40,54],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[40,59],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[46,54],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[46,59],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[14,67],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[14,62],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[21,67],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[21,62],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[28,67],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[28,62],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,67],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,62],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[40,67],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[40,62],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[46,67],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[46,62],"building":6,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[115,58],"building":7,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[124,58],"building":7,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[133,58],"building":7,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[115,61],"building":7,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[124,61],"building":7,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[133,61],"building":7,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[110,59],"building":7,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[137,59],"building":7,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[115,58],"building":7,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[124,58],"building":7,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[133,58],"building":7,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[115,61],"building":7,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[124,61],"building":7,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[133,61],"building":7,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[115,58],"building":7,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[124,58],"building":7,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[133,58],"building":7,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[115,61],"building":7,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[124,61],"building":7,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[133,61],"building":7,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[135,17],"building":8,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[145,17],"building":8,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[155,17],"building":8,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[135,20],"building":8,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[145,20],"building":8,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[155,20],"building":8,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[130,18],"building":8,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[159,18],"building":8,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[135,17],"building":8,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[145,17],"building":8,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[155,17],"building":8,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[135,20],"building":8,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[145,20],"building":8,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[155,20],"building":8,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[135,17],"building":8,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[145,17],"building":8,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[155,17],"building":8,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[135,20],"building":8,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[145,20],"building":8,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[155,20],"building":8,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[81,59],"building":9,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[90,59],"building":9,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[99,59],"building":9,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[81,62],"building":9,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[90,62],"building":9,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[99,62],"building":9,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[76,60],"building":9,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[103,60],"building":9,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[81,59],"building":9,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[90,59],"building":9,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[99,59],"building":9,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[81,62],"building":9,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[90,62],"building":9,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[99,62],"building":9,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[81,59],"building":9,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[90,59],"building":9,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[99,59],"building":9,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[81,62],"building":9,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[90,62],"building":9,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[99,62],"building":9,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[124,36],"building":10,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[127,36],"building":10,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[125,32],"building":10,"level":0,"state":"open","normal":[0,-1],"external":true},
		{"cell":[125,39],"building":10,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[77,17],"building":11,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[70,17],"building":11,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[83,17],"building":11,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[142,36],"building":12,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[136,36],"building":12,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[147,36],"building":12,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[160,54],"building":13,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[154,54],"building":13,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[165,54],"building":13,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[54,61],"building":14,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[61,61],"building":14,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[160,36],"building":15,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[154,36],"building":15,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[165,36],"building":15,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[148,67],"building":16,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[160,67],"building":16,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[148,70],"building":16,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[160,70],"building":16,"level":0,"state":"closed","normal":[0,1],"external":false},
		{"cell":[142,68],"building":16,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[165,68],"building":16,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[120,17],"building":17,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[114,17],"building":17,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[125,17],"building":17,"level":0,"state":"open","normal":[1,0],"external":true}],
	"windows": [{"cell":[51,28],"building":0,"level":0},
		{"cell":[60,39],"building":0,"level":0},
		{"cell":[51,28],"building":0,"level":1},
		{"cell":[60,39],"building":0,"level":1},
		{"cell":[33,10],"building":1,"level":0},
		{"cell":[50,23],"building":1,"level":0},
		{"cell":[33,10],"building":1,"level":1},
		{"cell":[50,23],"building":1,"level":1},
		{"cell":[33,10],"building":1,"level":-1},
		{"cell":[50,23],"building":1,"level":-1},
		{"cell":[23,28],"building":2,"level":0},
		{"cell":[38,39],"building":2,"level":0},
		{"cell":[23,28],"building":2,"level":1},
		{"cell":[38,39],"building":2,"level":1},
		{"cell":[102,29],"building":3,"level":0},
		{"cell":[102,29],"building":3,"level":1},
		{"cell":[73,28],"building":4,"level":0},
		{"cell":[90,41],"building":4,"level":0},
		{"cell":[91,10],"building":5,"level":0},
		{"cell":[106,23],"building":5,"level":0},
		{"cell":[91,10],"building":5,"level":1},
		{"cell":[106,23],"building":5,"level":1},
		{"cell":[91,10],"building":5,"level":2},
		{"cell":[106,23],"building":5,"level":2},
		{"cell":[13,49],"building":6,"level":0},
		{"cell":[46,72],"building":6,"level":0},
		{"cell":[13,49],"building":6,"level":1},
		{"cell":[46,72],"building":6,"level":1},
		{"cell":[13,49],"building":6,"level":2},
		{"cell":[46,72],"building":6,"level":2},
		{"cell":[13,49],"building":6,"level":-1},
		{"cell":[46,72],"building":6,"level":-1},
		{"cell":[113,50],"building":7,"level":0},
		{"cell":[134,69],"building":7,"level":0},
		{"cell":[113,50],"building":7,"level":1},
		{"cell":[134,69],"building":7,"level":1},
		{"cell":[113,50],"building":7,"level":2},
		{"cell":[134,69],"building":7,"level":2},
		{"cell":[133,10],"building":8,"level":0},
		{"cell":[156,27],"building":8,"level":0},
		{"cell":[133,10],"building":8,"level":1},
		{"cell":[156,27],"building":8,"level":1},
		{"cell":[133,10],"building":8,"level":2},
		{"cell":[156,27],"building":8,"level":2},
		{"cell":[79,52],"building":9,"level":0},
		{"cell":[100,69],"building":9,"level":0},
		{"cell":[79,52],"building":9,"level":1},
		{"cell":[100,69],"building":9,"level":1},
		{"cell":[79,52],"building":9,"level":2},
		{"cell":[100,69],"building":9,"level":2},
		{"cell":[120,35],"building":10,"level":0},
		{"cell":[131,36],"building":10,"level":0},
		{"cell":[72,12],"building":11,"level":0},
		{"cell":[138,32],"building":12,"level":0},
		{"cell":[156,50],"building":13,"level":0},
		{"cell":[56,57],"building":14,"level":0},
		{"cell":[156,32],"building":15,"level":0},
		{"cell":[145,63],"building":16,"level":0},
		{"cell":[162,74],"building":16,"level":0},
		{"cell":[116,12],"building":17,"level":0}],
	"stairs": [{"cell":[50,33],"low":0,"high":1,"ladder":false},
		{"cell":[32,15],"low":-1,"high":0,"ladder":false},
		{"cell":[32,15],"low":0,"high":1,"ladder":false},
		{"cell":[22,33],"low":0,"high":1,"ladder":false},
		{"cell":[101,34],"low":0,"high":1,"ladder":false},
		{"cell":[90,16],"low":0,"high":1,"ladder":false},
		{"cell":[90,16],"low":1,"high":2,"ladder":false},
		{"cell":[107,17],"low":0,"high":1,"ladder":false},
		{"cell":[107,17],"low":1,"high":2,"ladder":false},
		{"cell":[16,60],"low":-1,"high":0,"ladder":false},
		{"cell":[16,60],"low":0,"high":1,"ladder":false},
		{"cell":[16,60],"low":1,"high":2,"ladder":false},
		{"cell":[40,61],"low":-1,"high":0,"ladder":false},
		{"cell":[40,61],"low":0,"high":1,"ladder":false},
		{"cell":[40,61],"low":1,"high":2,"ladder":false},
		{"cell":[112,59],"low":0,"high":1,"ladder":false},
		{"cell":[112,59],"low":1,"high":2,"ladder":false},
		{"cell":[135,60],"low":0,"high":1,"ladder":false},
		{"cell":[135,60],"low":1,"high":2,"ladder":false},
		{"cell":[132,18],"low":0,"high":1,"ladder":false},
		{"cell":[132,18],"low":1,"high":2,"ladder":false},
		{"cell":[157,19],"low":0,"high":1,"ladder":false},
		{"cell":[157,19],"low":1,"high":2,"ladder":false},
		{"cell":[78,60],"low":0,"high":1,"ladder":false},
		{"cell":[78,60],"low":1,"high":2,"ladder":false},
		{"cell":[101,61],"low":0,"high":1,"ladder":false},
		{"cell":[101,61],"low":1,"high":2,"ladder":false}],
	"rooms": [{"building":0,"level":0,"rect":[49,29,14,3],"use":"매장"},
		{"building":0,"level":0,"rect":[49,36,14,3],"use":"매장"},
		{"building":0,"level":1,"rect":[49,29,14,3],"use":"매장"},
		{"building":0,"level":1,"rect":[49,36,14,3],"use":"매장"},
		{"building":1,"level":0,"rect":[31,11,11,3],"use":"매장"},
		{"building":1,"level":0,"rect":[43,11,10,3],"use":"뒤 창고"},
		{"building":1,"level":0,"rect":[31,20,11,3],"use":"매장"},
		{"building":1,"level":0,"rect":[43,20,10,3],"use":"뒤 창고"},
		{"building":1,"level":1,"rect":[31,11,11,3],"use":"매장"},
		{"building":1,"level":1,"rect":[43,11,10,3],"use":"뒤 창고"},
		{"building":1,"level":1,"rect":[31,20,11,3],"use":"매장"},
		{"building":1,"level":1,"rect":[43,20,10,3],"use":"뒤 창고"},
		{"building":1,"level":-1,"rect":[31,11,11,3],"use":"저장 칸"},
		{"building":1,"level":-1,"rect":[43,11,10,3],"use":"저장 칸"},
		{"building":1,"level":-1,"rect":[31,20,11,3],"use":"저장 칸"},
		{"building":1,"level":-1,"rect":[43,20,10,3],"use":"저장 칸"},
		{"building":2,"level":0,"rect":[21,29,10,3],"use":"매장"},
		{"building":2,"level":0,"rect":[32,29,9,3],"use":"뒤 창고"},
		{"building":2,"level":0,"rect":[21,36,10,3],"use":"매장"},
		{"building":2,"level":0,"rect":[32,36,9,3],"use":"뒤 창고"},
		{"building":2,"level":1,"rect":[21,29,10,3],"use":"매장"},
		{"building":2,"level":1,"rect":[32,29,9,3],"use":"뒤 창고"},
		{"building":2,"level":1,"rect":[21,36,10,3],"use":"매장"},
		{"building":2,"level":1,"rect":[32,36,9,3],"use":"뒤 창고"},
		{"building":3,"level":0,"rect":[101,30,7,8],"use":"작업실"},
		{"building":3,"level":0,"rect":[109,30,6,8],"use":"뒤 창고"},
		{"building":3,"level":1,"rect":[101,30,7,8],"use":"작업실"},
		{"building":3,"level":1,"rect":[109,30,6,8],"use":"뒤 창고"},
		{"building":4,"level":0,"rect":[71,29,11,4],"use":"매장"},
		{"building":4,"level":0,"rect":[83,29,10,4],"use":"뒤 창고"},
		{"building":4,"level":0,"rect":[71,37,11,4],"use":"매장"},
		{"building":4,"level":0,"rect":[83,37,10,4],"use":"뒤 창고"},
		{"building":5,"level":0,"rect":[89,11,10,4],"use":"안방"},
		{"building":5,"level":0,"rect":[100,11,9,4],"use":"부엌"},
		{"building":5,"level":0,"rect":[89,19,10,4],"use":"안방"},
		{"building":5,"level":0,"rect":[100,19,9,4],"use":"부엌"},
		{"building":5,"level":1,"rect":[89,11,10,4],"use":"안방"},
		{"building":5,"level":1,"rect":[100,11,9,4],"use":"부엌"},
		{"building":5,"level":1,"rect":[89,19,10,4],"use":"안방"},
		{"building":5,"level":1,"rect":[100,19,9,4],"use":"부엌"},
		{"building":5,"level":2,"rect":[89,11,10,4],"use":"안방"},
		{"building":5,"level":2,"rect":[100,11,9,4],"use":"부엌"},
		{"building":5,"level":2,"rect":[89,19,10,4],"use":"안방"},
		{"building":5,"level":2,"rect":[100,19,9,4],"use":"부엌"},
		{"building":6,"level":0,"rect":[11,50,6,4],"use":"부엌"},
		{"building":6,"level":0,"rect":[11,55,6,4],"use":"안방"},
		{"building":6,"level":0,"rect":[18,50,6,4],"use":"부엌"},
		{"building":6,"level":0,"rect":[18,55,6,4],"use":"안방"},
		{"building":6,"level":0,"rect":[25,50,6,4],"use":"부엌"},
		{"building":6,"level":0,"rect":[25,55,6,4],"use":"안방"},
		{"building":6,"level":0,"rect":[32,50,5,4],"use":"부엌"},
		{"building":6,"level":0,"rect":[32,55,5,4],"use":"안방"},
		{"building":6,"level":0,"rect":[38,50,5,4],"use":"부엌"},
		{"building":6,"level":0,"rect":[38,55,5,4],"use":"안방"},
		{"building":6,"level":0,"rect":[44,50,5,4],"use":"부엌"},
		{"building":6,"level":0,"rect":[44,55,5,4],"use":"안방"},
		{"building":6,"level":0,"rect":[11,63,6,4],"use":"부엌"},
		{"building":6,"level":0,"rect":[11,68,6,4],"use":"안방"},
		{"building":6,"level":0,"rect":[18,63,6,4],"use":"부엌"},
		{"building":6,"level":0,"rect":[18,68,6,4],"use":"안방"},
		{"building":6,"level":0,"rect":[25,63,6,4],"use":"부엌"},
		{"building":6,"level":0,"rect":[25,68,6,4],"use":"안방"},
		{"building":6,"level":0,"rect":[32,63,5,4],"use":"부엌"},
		{"building":6,"level":0,"rect":[32,68,5,4],"use":"안방"},
		{"building":6,"level":0,"rect":[38,63,5,4],"use":"부엌"},
		{"building":6,"level":0,"rect":[38,68,5,4],"use":"안방"},
		{"building":6,"level":0,"rect":[44,63,5,4],"use":"부엌"},
		{"building":6,"level":0,"rect":[44,68,5,4],"use":"안방"},
		{"building":6,"level":1,"rect":[11,50,6,4],"use":"부엌"},
		{"building":6,"level":1,"rect":[11,55,6,4],"use":"안방"},
		{"building":6,"level":1,"rect":[18,50,6,4],"use":"부엌"},
		{"building":6,"level":1,"rect":[18,55,6,4],"use":"안방"},
		{"building":6,"level":1,"rect":[25,50,6,4],"use":"부엌"},
		{"building":6,"level":1,"rect":[25,55,6,4],"use":"안방"},
		{"building":6,"level":1,"rect":[32,50,5,4],"use":"부엌"},
		{"building":6,"level":1,"rect":[32,55,5,4],"use":"안방"},
		{"building":6,"level":1,"rect":[38,50,5,4],"use":"부엌"},
		{"building":6,"level":1,"rect":[38,55,5,4],"use":"안방"},
		{"building":6,"level":1,"rect":[44,50,5,4],"use":"부엌"},
		{"building":6,"level":1,"rect":[44,55,5,4],"use":"안방"},
		{"building":6,"level":1,"rect":[11,63,6,4],"use":"부엌"},
		{"building":6,"level":1,"rect":[11,68,6,4],"use":"안방"},
		{"building":6,"level":1,"rect":[18,63,6,4],"use":"부엌"},
		{"building":6,"level":1,"rect":[18,68,6,4],"use":"안방"},
		{"building":6,"level":1,"rect":[25,63,6,4],"use":"부엌"},
		{"building":6,"level":1,"rect":[25,68,6,4],"use":"안방"},
		{"building":6,"level":1,"rect":[32,63,5,4],"use":"부엌"},
		{"building":6,"level":1,"rect":[32,68,5,4],"use":"안방"},
		{"building":6,"level":1,"rect":[38,63,5,4],"use":"부엌"},
		{"building":6,"level":1,"rect":[38,68,5,4],"use":"안방"},
		{"building":6,"level":1,"rect":[44,63,5,4],"use":"부엌"},
		{"building":6,"level":1,"rect":[44,68,5,4],"use":"안방"},
		{"building":6,"level":2,"rect":[11,50,6,4],"use":"부엌"},
		{"building":6,"level":2,"rect":[11,55,6,4],"use":"안방"},
		{"building":6,"level":2,"rect":[18,50,6,4],"use":"부엌"},
		{"building":6,"level":2,"rect":[18,55,6,4],"use":"안방"},
		{"building":6,"level":2,"rect":[25,50,6,4],"use":"부엌"},
		{"building":6,"level":2,"rect":[25,55,6,4],"use":"안방"},
		{"building":6,"level":2,"rect":[32,50,5,4],"use":"부엌"},
		{"building":6,"level":2,"rect":[32,55,5,4],"use":"안방"},
		{"building":6,"level":2,"rect":[38,50,5,4],"use":"부엌"},
		{"building":6,"level":2,"rect":[38,55,5,4],"use":"안방"},
		{"building":6,"level":2,"rect":[44,50,5,4],"use":"부엌"},
		{"building":6,"level":2,"rect":[44,55,5,4],"use":"안방"},
		{"building":6,"level":2,"rect":[11,63,6,4],"use":"부엌"},
		{"building":6,"level":2,"rect":[11,68,6,4],"use":"안방"},
		{"building":6,"level":2,"rect":[18,63,6,4],"use":"부엌"},
		{"building":6,"level":2,"rect":[18,68,6,4],"use":"안방"},
		{"building":6,"level":2,"rect":[25,63,6,4],"use":"부엌"},
		{"building":6,"level":2,"rect":[25,68,6,4],"use":"안방"},
		{"building":6,"level":2,"rect":[32,63,5,4],"use":"부엌"},
		{"building":6,"level":2,"rect":[32,68,5,4],"use":"안방"},
		{"building":6,"level":2,"rect":[38,63,5,4],"use":"부엌"},
		{"building":6,"level":2,"rect":[38,68,5,4],"use":"안방"},
		{"building":6,"level":2,"rect":[44,63,5,4],"use":"부엌"},
		{"building":6,"level":2,"rect":[44,68,5,4],"use":"안방"},
		{"building":6,"level":-1,"rect":[11,50,6,4],"use":"부엌"},
		{"building":6,"level":-1,"rect":[11,55,6,4],"use":"안방"},
		{"building":6,"level":-1,"rect":[18,50,6,4],"use":"부엌"},
		{"building":6,"level":-1,"rect":[18,55,6,4],"use":"안방"},
		{"building":6,"level":-1,"rect":[25,50,6,4],"use":"부엌"},
		{"building":6,"level":-1,"rect":[25,55,6,4],"use":"안방"},
		{"building":6,"level":-1,"rect":[32,50,5,4],"use":"부엌"},
		{"building":6,"level":-1,"rect":[32,55,5,4],"use":"안방"},
		{"building":6,"level":-1,"rect":[38,50,5,4],"use":"부엌"},
		{"building":6,"level":-1,"rect":[38,55,5,4],"use":"안방"},
		{"building":6,"level":-1,"rect":[44,50,5,4],"use":"부엌"},
		{"building":6,"level":-1,"rect":[44,55,5,4],"use":"안방"},
		{"building":6,"level":-1,"rect":[11,63,6,4],"use":"부엌"},
		{"building":6,"level":-1,"rect":[11,68,6,4],"use":"안방"},
		{"building":6,"level":-1,"rect":[18,63,6,4],"use":"부엌"},
		{"building":6,"level":-1,"rect":[18,68,6,4],"use":"안방"},
		{"building":6,"level":-1,"rect":[25,63,6,4],"use":"부엌"},
		{"building":6,"level":-1,"rect":[25,68,6,4],"use":"안방"},
		{"building":6,"level":-1,"rect":[32,63,5,4],"use":"부엌"},
		{"building":6,"level":-1,"rect":[32,68,5,4],"use":"안방"},
		{"building":6,"level":-1,"rect":[38,63,5,4],"use":"부엌"},
		{"building":6,"level":-1,"rect":[38,68,5,4],"use":"안방"},
		{"building":6,"level":-1,"rect":[44,63,5,4],"use":"부엌"},
		{"building":6,"level":-1,"rect":[44,68,5,4],"use":"안방"},
		{"building":7,"level":0,"rect":[111,51,8,7],"use":"안방"},
		{"building":7,"level":0,"rect":[120,51,8,7],"use":"부엌"},
		{"building":7,"level":0,"rect":[129,51,8,7],"use":"안방"},
		{"building":7,"level":0,"rect":[111,62,8,7],"use":"안방"},
		{"building":7,"level":0,"rect":[120,62,8,7],"use":"부엌"},
		{"building":7,"level":0,"rect":[129,62,8,7],"use":"안방"},
		{"building":7,"level":1,"rect":[111,51,8,7],"use":"안방"},
		{"building":7,"level":1,"rect":[120,51,8,7],"use":"부엌"},
		{"building":7,"level":1,"rect":[129,51,8,7],"use":"안방"},
		{"building":7,"level":1,"rect":[111,62,8,7],"use":"안방"},
		{"building":7,"level":1,"rect":[120,62,8,7],"use":"부엌"},
		{"building":7,"level":1,"rect":[129,62,8,7],"use":"안방"},
		{"building":7,"level":2,"rect":[111,51,8,7],"use":"안방"},
		{"building":7,"level":2,"rect":[120,51,8,7],"use":"부엌"},
		{"building":7,"level":2,"rect":[129,51,8,7],"use":"안방"},
		{"building":7,"level":2,"rect":[111,62,8,7],"use":"안방"},
		{"building":7,"level":2,"rect":[120,62,8,7],"use":"부엌"},
		{"building":7,"level":2,"rect":[129,62,8,7],"use":"안방"},
		{"building":8,"level":0,"rect":[131,11,9,6],"use":"안방"},
		{"building":8,"level":0,"rect":[141,11,9,6],"use":"부엌"},
		{"building":8,"level":0,"rect":[151,11,8,6],"use":"안방"},
		{"building":8,"level":0,"rect":[131,21,9,6],"use":"안방"},
		{"building":8,"level":0,"rect":[141,21,9,6],"use":"부엌"},
		{"building":8,"level":0,"rect":[151,21,8,6],"use":"안방"},
		{"building":8,"level":1,"rect":[131,11,9,6],"use":"안방"},
		{"building":8,"level":1,"rect":[141,11,9,6],"use":"부엌"},
		{"building":8,"level":1,"rect":[151,11,8,6],"use":"안방"},
		{"building":8,"level":1,"rect":[131,21,9,6],"use":"안방"},
		{"building":8,"level":1,"rect":[141,21,9,6],"use":"부엌"},
		{"building":8,"level":1,"rect":[151,21,8,6],"use":"안방"},
		{"building":8,"level":2,"rect":[131,11,9,6],"use":"안방"},
		{"building":8,"level":2,"rect":[141,11,9,6],"use":"부엌"},
		{"building":8,"level":2,"rect":[151,11,8,6],"use":"안방"},
		{"building":8,"level":2,"rect":[131,21,9,6],"use":"안방"},
		{"building":8,"level":2,"rect":[141,21,9,6],"use":"부엌"},
		{"building":8,"level":2,"rect":[151,21,8,6],"use":"안방"},
		{"building":9,"level":0,"rect":[77,53,8,6],"use":"안방"},
		{"building":9,"level":0,"rect":[86,53,8,6],"use":"부엌"},
		{"building":9,"level":0,"rect":[95,53,8,6],"use":"안방"},
		{"building":9,"level":0,"rect":[77,63,8,6],"use":"안방"},
		{"building":9,"level":0,"rect":[86,63,8,6],"use":"부엌"},
		{"building":9,"level":0,"rect":[95,63,8,6],"use":"안방"},
		{"building":9,"level":1,"rect":[77,53,8,6],"use":"안방"},
		{"building":9,"level":1,"rect":[86,53,8,6],"use":"부엌"},
		{"building":9,"level":1,"rect":[95,53,8,6],"use":"안방"},
		{"building":9,"level":1,"rect":[77,63,8,6],"use":"안방"},
		{"building":9,"level":1,"rect":[86,63,8,6],"use":"부엌"},
		{"building":9,"level":1,"rect":[95,63,8,6],"use":"안방"},
		{"building":9,"level":2,"rect":[77,53,8,6],"use":"안방"},
		{"building":9,"level":2,"rect":[86,53,8,6],"use":"부엌"},
		{"building":9,"level":2,"rect":[95,53,8,6],"use":"안방"},
		{"building":9,"level":2,"rect":[77,63,8,6],"use":"안방"},
		{"building":9,"level":2,"rect":[86,63,8,6],"use":"부엌"},
		{"building":9,"level":2,"rect":[95,63,8,6],"use":"안방"},
		{"building":10,"level":0,"rect":[121,33,3,6],"use":"매장"},
		{"building":10,"level":0,"rect":[128,33,3,6],"use":"매장"},
		{"building":11,"level":0,"rect":[71,13,6,8],"use":"작업실"},
		{"building":11,"level":0,"rect":[78,13,5,8],"use":"뒤 창고"},
		{"building":12,"level":0,"rect":[137,33,5,6],"use":"작업실"},
		{"building":12,"level":0,"rect":[143,33,4,6],"use":"뒤 창고"},
		{"building":13,"level":0,"rect":[155,51,5,6],"use":"작업실"},
		{"building":13,"level":0,"rect":[161,51,4,6],"use":"뒤 창고"},
		{"building":14,"level":0,"rect":[55,58,6,6],"use":"작업실"},
		{"building":15,"level":0,"rect":[155,33,5,6],"use":"작업실"},
		{"building":15,"level":0,"rect":[161,33,4,6],"use":"뒤 창고"},
		{"building":16,"level":0,"rect":[143,64,11,3],"use":"매장"},
		{"building":16,"level":0,"rect":[155,64,10,3],"use":"뒤 창고"},
		{"building":16,"level":0,"rect":[143,71,11,3],"use":"매장"},
		{"building":16,"level":0,"rect":[155,71,10,3],"use":"뒤 창고"},
		{"building":17,"level":0,"rect":[115,13,5,8],"use":"작업실"},
		{"building":17,"level":0,"rect":[121,13,4,8],"use":"뒤 창고"}],
	"props": [{"kind":"water","rect":[0,84,64,16],"solid":"low","facing":0,"note":"언 물","level":0},
		{"kind":"water","rect":[70,90,100,10],"solid":"low","facing":1,"note":"언 물","level":0},
		{"kind":"bread_rack","rect":[49,29,1,1],"solid":"none","facing":0,"note":"매장의 빵 선반","level":0},
		{"kind":"shop_counter","rect":[60,31,3,1],"solid":"low","facing":1,"note":"매장의 가게 계산대","level":0},
		{"kind":"crate_stack","rect":[49,30,2,2],"solid":"low","facing":2,"note":"매장의 나무 상자 더미","level":0},
		{"kind":"bread_rack","rect":[49,36,1,1],"solid":"low","facing":0,"note":"매장의 빵 선반","level":0},
		{"kind":"shelf","rect":[60,38,3,1],"solid":"low","facing":1,"note":"매장의 선반","level":0},
		{"kind":"crate_stack","rect":[49,37,2,2],"solid":"low","facing":2,"note":"매장의 나무 상자 더미","level":0},
		{"kind":"bed","rect":[49,29,2,1],"solid":"none","facing":0,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[62,31,1,1],"solid":"none","facing":1,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[49,31,2,1],"solid":"none","facing":2,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[49,36,2,1],"solid":"none","facing":0,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[62,38,1,1],"solid":"none","facing":1,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[49,38,2,1],"solid":"none","facing":2,"note":"매장의 장롱","level":1},
		{"kind":"display_shelf","rect":[38,11,4,1],"solid":"none","facing":1,"note":"매장의 진열대","level":0},
		{"kind":"shop_counter","rect":[31,13,3,1],"solid":"none","facing":2,"note":"매장의 가게 계산대","level":0},
		{"kind":"tin_crate","rect":[40,13,2,1],"solid":"none","facing":3,"note":"매장의 통조림 상자","level":0},
		{"kind":"display_shelf","rect":[49,11,4,1],"solid":"none","facing":1,"note":"뒤 창고의 진열대","level":0},
		{"kind":"shelf","rect":[43,13,3,1],"solid":"none","facing":2,"note":"뒤 창고의 선반","level":0},
		{"kind":"tin_crate","rect":[51,13,2,1],"solid":"none","facing":3,"note":"뒤 창고의 통조림 상자","level":0},
		{"kind":"display_shelf","rect":[38,20,4,1],"solid":"none","facing":1,"note":"매장의 진열대","level":0},
		{"kind":"shelf","rect":[31,22,3,1],"solid":"none","facing":2,"note":"매장의 선반","level":0},
		{"kind":"tin_crate","rect":[40,22,2,1],"solid":"none","facing":3,"note":"매장의 통조림 상자","level":0},
		{"kind":"display_shelf","rect":[49,20,4,1],"solid":"none","facing":1,"note":"뒤 창고의 진열대","level":0},
		{"kind":"shelf","rect":[43,22,3,1],"solid":"none","facing":2,"note":"뒤 창고의 선반","level":0},
		{"kind":"tin_crate","rect":[51,22,2,1],"solid":"none","facing":3,"note":"뒤 창고의 통조림 상자","level":0},
		{"kind":"bed","rect":[40,11,2,1],"solid":"none","facing":1,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[31,13,1,1],"solid":"none","facing":2,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[40,13,2,1],"solid":"none","facing":3,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[51,11,2,1],"solid":"none","facing":1,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[43,13,1,1],"solid":"none","facing":2,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[51,13,2,1],"solid":"none","facing":3,"note":"뒤 창고의 장롱","level":1},
		{"kind":"bed","rect":[40,20,2,1],"solid":"none","facing":1,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[31,22,1,1],"solid":"none","facing":2,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[40,22,2,1],"solid":"none","facing":3,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[51,20,2,1],"solid":"none","facing":1,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[43,22,1,1],"solid":"none","facing":2,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[51,22,2,1],"solid":"none","facing":3,"note":"뒤 창고의 장롱","level":1},
		{"kind":"jar_shelf","rect":[39,11,3,1],"solid":"none","facing":1,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[31,13,1,1],"solid":"none","facing":2,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[40,13,2,1],"solid":"none","facing":3,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[50,11,3,1],"solid":"none","facing":1,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[43,13,1,1],"solid":"none","facing":2,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[51,13,2,1],"solid":"none","facing":3,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[39,20,3,1],"solid":"none","facing":1,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[31,22,1,1],"solid":"none","facing":2,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[40,22,2,1],"solid":"none","facing":3,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[50,20,3,1],"solid":"none","facing":1,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[43,22,1,1],"solid":"none","facing":2,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[51,22,2,1],"solid":"none","facing":3,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"hardware_rack","rect":[21,29,3,1],"solid":"none","facing":2,"note":"매장의 철물 걸이대","level":0},
		{"kind":"shop_counter","rect":[28,31,3,1],"solid":"low","facing":3,"note":"매장의 가게 계산대","level":0},
		{"kind":"barrel","rect":[21,31,1,1],"solid":"low","facing":0,"note":"매장의 통","level":0},
		{"kind":"hardware_rack","rect":[32,29,3,1],"solid":"none","facing":2,"note":"뒤 창고의 철물 걸이대","level":0},
		{"kind":"desk","rect":[39,31,2,1],"solid":"low","facing":3,"note":"뒤 창고의 책상","level":0},
		{"kind":"barrel","rect":[32,31,1,1],"solid":"low","facing":0,"note":"뒤 창고의 통","level":0},
		{"kind":"hardware_rack","rect":[21,36,3,1],"solid":"low","facing":2,"note":"매장의 철물 걸이대","level":0},
		{"kind":"desk","rect":[29,38,2,1],"solid":"low","facing":3,"note":"매장의 책상","level":0},
		{"kind":"barrel","rect":[21,38,1,1],"solid":"low","facing":0,"note":"매장의 통","level":0},
		{"kind":"hardware_rack","rect":[32,36,3,1],"solid":"low","facing":2,"note":"뒤 창고의 철물 걸이대","level":0},
		{"kind":"desk","rect":[39,38,2,1],"solid":"low","facing":3,"note":"뒤 창고의 책상","level":0},
		{"kind":"barrel","rect":[32,38,1,1],"solid":"low","facing":0,"note":"뒤 창고의 통","level":0},
		{"kind":"bed","rect":[21,29,2,1],"solid":"none","facing":2,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[30,31,1,1],"solid":"none","facing":3,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[21,31,2,1],"solid":"none","facing":0,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[32,29,2,1],"solid":"none","facing":2,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[40,31,1,1],"solid":"none","facing":3,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[32,31,2,1],"solid":"none","facing":0,"note":"뒤 창고의 장롱","level":1},
		{"kind":"bed","rect":[21,36,2,1],"solid":"none","facing":2,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[30,38,1,1],"solid":"none","facing":3,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[21,38,2,1],"solid":"none","facing":0,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[32,36,2,1],"solid":"none","facing":2,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[40,38,1,1],"solid":"none","facing":3,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[32,38,2,1],"solid":"none","facing":0,"note":"뒤 창고의 장롱","level":1},
		{"kind":"shop_counter","rect":[105,30,3,1],"solid":"low","facing":3,"note":"작업실의 가게 계산대","level":0},
		{"kind":"shelf","rect":[101,37,3,1],"solid":"low","facing":0,"note":"작업실의 선반","level":0},
		{"kind":"display_shelf","rect":[104,37,4,1],"solid":"low","facing":1,"note":"작업실의 진열대","level":0},
		{"kind":"display_shelf","rect":[111,30,4,1],"solid":"low","facing":3,"note":"뒤 창고의 진열대","level":0},
		{"kind":"shelf","rect":[109,37,3,1],"solid":"low","facing":0,"note":"뒤 창고의 선반","level":0},
		{"kind":"shelf","rect":[112,37,3,1],"solid":"low","facing":1,"note":"뒤 창고의 선반","level":0},
		{"kind":"fridge_open","rect":[107,30,1,1],"solid":"none","facing":3,"note":"작업실의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[101,37,2,1],"solid":"none","facing":0,"note":"작업실의 장롱","level":1},
		{"kind":"bed","rect":[106,37,2,1],"solid":"none","facing":1,"note":"작업실의 침대","level":1},
		{"kind":"bed","rect":[113,30,2,1],"solid":"none","facing":3,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[109,37,1,1],"solid":"none","facing":0,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[113,37,2,1],"solid":"none","facing":1,"note":"뒤 창고의 장롱","level":1},
		{"kind":"door_pile","rect":[71,29,2,1],"solid":"none","facing":0,"note":"매장의 문짝 더미","level":0},
		{"kind":"desk","rect":[80,32,2,1],"solid":"low","facing":1,"note":"매장의 책상","level":0},
		{"kind":"firewood_pile","rect":[71,32,2,1],"solid":"low","facing":2,"note":"매장의 장작 더미","level":0},
		{"kind":"door_pile","rect":[83,29,2,1],"solid":"none","facing":0,"note":"뒤 창고의 문짝 더미","level":0},
		{"kind":"desk","rect":[91,32,2,1],"solid":"low","facing":1,"note":"뒤 창고의 책상","level":0},
		{"kind":"firewood_pile","rect":[83,32,2,1],"solid":"low","facing":2,"note":"뒤 창고의 장작 더미","level":0},
		{"kind":"door_pile","rect":[71,37,2,1],"solid":"low","facing":0,"note":"매장의 문짝 더미","level":0},
		{"kind":"desk","rect":[80,40,2,1],"solid":"low","facing":1,"note":"매장의 책상","level":0},
		{"kind":"firewood_pile","rect":[71,40,2,1],"solid":"low","facing":2,"note":"매장의 장작 더미","level":0},
		{"kind":"door_pile","rect":[83,37,2,1],"solid":"low","facing":0,"note":"뒤 창고의 문짝 더미","level":0},
		{"kind":"desk","rect":[91,40,2,1],"solid":"low","facing":1,"note":"뒤 창고의 책상","level":0},
		{"kind":"firewood_pile","rect":[83,40,2,1],"solid":"low","facing":2,"note":"뒤 창고의 장작 더미","level":0},
		{"kind":"bed","rect":[97,11,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[89,14,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[97,14,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[107,11,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[100,14,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[108,14,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[97,19,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[89,22,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[97,22,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[107,19,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[100,22,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[108,22,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[97,11,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[89,14,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[97,14,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[107,11,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[100,14,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[108,14,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[97,19,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[89,22,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[97,22,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[107,19,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[100,22,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[108,22,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[97,11,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[89,14,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[97,14,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[107,11,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[100,14,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[108,14,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[97,19,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[89,22,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[97,22,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[107,19,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[100,22,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[108,22,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"dining_set","rect":[11,50,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[16,53,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[11,53,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[11,55,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[16,58,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[11,58,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[18,50,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[23,53,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[18,53,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[18,55,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[23,58,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[18,58,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[25,50,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[30,53,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[25,53,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[25,55,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[30,58,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[25,58,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[32,50,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[36,53,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[32,53,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[32,55,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[36,58,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[32,58,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[38,50,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[42,53,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[38,53,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[38,55,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[42,58,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[38,58,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[44,50,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[48,53,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[44,53,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[44,55,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[48,58,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[44,58,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[11,63,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[16,66,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[11,66,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[11,68,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[16,71,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[11,71,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[18,63,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[23,66,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[18,66,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[18,68,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[23,71,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[18,71,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[25,63,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[30,66,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[25,66,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[25,68,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[30,71,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[25,71,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[32,63,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[36,66,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[32,66,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[32,68,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[36,71,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[32,71,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[38,63,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[42,66,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[38,66,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[38,68,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[42,71,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[38,71,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[44,63,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[48,66,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[44,66,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[44,68,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[48,71,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[44,71,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[11,50,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[16,53,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[11,53,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[11,55,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[16,58,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[11,58,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[18,50,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[23,53,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[18,53,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[18,55,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[23,58,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[18,58,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[25,50,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[30,53,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[25,53,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[25,55,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[30,58,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[25,58,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[32,50,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[36,53,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[32,53,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[32,55,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[36,58,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[32,58,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[38,50,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[42,53,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[38,53,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[38,55,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[42,58,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[38,58,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[44,50,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[48,53,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[44,53,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[44,55,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[48,58,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[44,58,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[11,63,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[16,66,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[11,66,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[11,68,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[16,71,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[11,71,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[18,63,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[23,66,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[18,66,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[18,68,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[23,71,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[18,71,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[25,63,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[30,66,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[25,66,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[25,68,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[30,71,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[25,71,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[32,63,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[36,66,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[32,66,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[32,68,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[36,71,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[32,71,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[38,63,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[42,66,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[38,66,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[38,68,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[42,71,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[38,71,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[44,63,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[48,66,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[44,66,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[44,68,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[48,71,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[44,71,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[11,50,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[16,53,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[11,53,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[11,55,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[16,58,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[11,58,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[18,50,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[23,53,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[18,53,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[18,55,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[23,58,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[18,58,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[25,50,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[30,53,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[25,53,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[25,55,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[30,58,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[25,58,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[32,50,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[36,53,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[32,53,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[32,55,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[36,58,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[32,58,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[38,50,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[42,53,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[38,53,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[38,55,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[42,58,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[38,58,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[44,50,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[48,53,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[44,53,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[44,55,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[48,58,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[44,58,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[11,63,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[16,66,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[11,66,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[11,68,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[16,71,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[11,71,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[18,63,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[23,66,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[18,66,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[18,68,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[23,71,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[18,71,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[25,63,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[30,66,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[25,66,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[25,68,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[30,71,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[25,71,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[32,63,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[36,66,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[32,66,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[32,68,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[36,71,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[32,71,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[38,63,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[42,66,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[38,66,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[38,68,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[42,71,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[38,71,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[44,63,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[48,66,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[44,66,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[44,68,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[48,71,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[44,71,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[11,50,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":-1},
		{"kind":"fridge_open","rect":[16,53,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":-1},
		{"kind":"cold_stove","rect":[11,53,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":-1},
		{"kind":"jar_shelf","rect":[11,55,3,1],"solid":"none","facing":2,"note":"안방의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[16,58,1,1],"solid":"none","facing":3,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[11,58,2,1],"solid":"none","facing":0,"note":"안방의 통조림 상자","level":-1},
		{"kind":"dining_set","rect":[18,50,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":-1},
		{"kind":"fridge_open","rect":[23,53,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":-1},
		{"kind":"cold_stove","rect":[18,53,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":-1},
		{"kind":"jar_shelf","rect":[18,55,3,1],"solid":"none","facing":2,"note":"안방의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[23,58,1,1],"solid":"none","facing":3,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[18,58,2,1],"solid":"none","facing":0,"note":"안방의 통조림 상자","level":-1},
		{"kind":"dining_set","rect":[25,50,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":-1},
		{"kind":"fridge_open","rect":[30,53,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":-1},
		{"kind":"cold_stove","rect":[25,53,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":-1},
		{"kind":"jar_shelf","rect":[25,55,3,1],"solid":"none","facing":2,"note":"안방의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[30,58,1,1],"solid":"none","facing":3,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[25,58,2,1],"solid":"none","facing":0,"note":"안방의 통조림 상자","level":-1},
		{"kind":"dining_set","rect":[32,50,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":-1},
		{"kind":"fridge_open","rect":[36,53,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":-1},
		{"kind":"cold_stove","rect":[32,53,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":-1},
		{"kind":"barrel","rect":[32,55,1,1],"solid":"none","facing":0,"note":"안방의 통","level":-1},
		{"kind":"barrel","rect":[36,58,1,1],"solid":"none","facing":3,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[32,58,2,1],"solid":"none","facing":0,"note":"안방의 통조림 상자","level":-1},
		{"kind":"dining_set","rect":[38,50,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":-1},
		{"kind":"fridge_open","rect":[42,53,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":-1},
		{"kind":"cold_stove","rect":[38,53,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":-1},
		{"kind":"barrel","rect":[38,55,1,1],"solid":"none","facing":0,"note":"안방의 통","level":-1},
		{"kind":"barrel","rect":[42,58,1,1],"solid":"none","facing":3,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[38,58,2,1],"solid":"none","facing":0,"note":"안방의 통조림 상자","level":-1},
		{"kind":"dining_set","rect":[44,50,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":-1},
		{"kind":"fridge_open","rect":[48,53,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":-1},
		{"kind":"cold_stove","rect":[44,53,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":-1},
		{"kind":"barrel","rect":[44,55,1,1],"solid":"none","facing":0,"note":"안방의 통","level":-1},
		{"kind":"barrel","rect":[48,58,1,1],"solid":"none","facing":3,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[44,58,2,1],"solid":"none","facing":0,"note":"안방의 통조림 상자","level":-1},
		{"kind":"dining_set","rect":[11,63,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":-1},
		{"kind":"fridge_open","rect":[16,66,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":-1},
		{"kind":"cold_stove","rect":[11,66,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":-1},
		{"kind":"jar_shelf","rect":[11,68,3,1],"solid":"none","facing":2,"note":"안방의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[16,71,1,1],"solid":"none","facing":3,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[11,71,2,1],"solid":"none","facing":0,"note":"안방의 통조림 상자","level":-1},
		{"kind":"dining_set","rect":[18,63,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":-1},
		{"kind":"fridge_open","rect":[23,66,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":-1},
		{"kind":"cold_stove","rect":[18,66,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":-1},
		{"kind":"jar_shelf","rect":[18,68,3,1],"solid":"none","facing":2,"note":"안방의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[23,71,1,1],"solid":"none","facing":3,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[18,71,2,1],"solid":"none","facing":0,"note":"안방의 통조림 상자","level":-1},
		{"kind":"dining_set","rect":[25,63,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":-1},
		{"kind":"fridge_open","rect":[30,66,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":-1},
		{"kind":"cold_stove","rect":[25,66,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":-1},
		{"kind":"jar_shelf","rect":[25,68,3,1],"solid":"none","facing":2,"note":"안방의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[30,71,1,1],"solid":"none","facing":3,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[25,71,2,1],"solid":"none","facing":0,"note":"안방의 통조림 상자","level":-1},
		{"kind":"dining_set","rect":[32,63,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":-1},
		{"kind":"fridge_open","rect":[36,66,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":-1},
		{"kind":"cold_stove","rect":[32,66,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":-1},
		{"kind":"jar_shelf","rect":[34,71,3,1],"solid":"none","facing":2,"note":"안방의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[32,68,1,1],"solid":"none","facing":3,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[32,71,2,1],"solid":"none","facing":0,"note":"안방의 통조림 상자","level":-1},
		{"kind":"dining_set","rect":[38,63,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":-1},
		{"kind":"fridge_open","rect":[42,66,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":-1},
		{"kind":"cold_stove","rect":[38,66,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":-1},
		{"kind":"jar_shelf","rect":[40,71,3,1],"solid":"none","facing":2,"note":"안방의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[38,68,1,1],"solid":"none","facing":3,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[38,71,2,1],"solid":"none","facing":0,"note":"안방의 통조림 상자","level":-1},
		{"kind":"dining_set","rect":[44,63,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":-1},
		{"kind":"fridge_open","rect":[48,66,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":-1},
		{"kind":"cold_stove","rect":[44,66,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":-1},
		{"kind":"jar_shelf","rect":[46,71,3,1],"solid":"none","facing":2,"note":"안방의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[44,68,1,1],"solid":"none","facing":3,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[44,71,2,1],"solid":"none","facing":0,"note":"안방의 통조림 상자","level":-1},
		{"kind":"bed","rect":[117,51,2,1],"solid":"low","facing":3,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[111,57,1,1],"solid":"low","facing":0,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[117,57,2,1],"solid":"low","facing":1,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[126,51,2,2],"solid":"low","facing":3,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[120,57,1,1],"solid":"low","facing":0,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[127,57,1,1],"solid":"low","facing":1,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[135,51,2,1],"solid":"low","facing":3,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[129,57,1,1],"solid":"low","facing":0,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[135,57,2,1],"solid":"low","facing":1,"note":"안방의 장롱","level":0},
		{"kind":"bed","rect":[117,62,2,1],"solid":"low","facing":3,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[111,68,1,1],"solid":"low","facing":0,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[117,68,2,1],"solid":"low","facing":1,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[126,62,2,2],"solid":"low","facing":3,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[120,68,1,1],"solid":"low","facing":0,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[127,68,1,1],"solid":"low","facing":1,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[135,62,2,1],"solid":"low","facing":3,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[129,68,1,1],"solid":"low","facing":0,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[135,68,2,1],"solid":"low","facing":1,"note":"안방의 장롱","level":0},
		{"kind":"bed","rect":[117,51,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[111,57,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[117,57,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[126,51,2,2],"solid":"none","facing":3,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[120,57,1,1],"solid":"none","facing":0,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[127,57,1,1],"solid":"none","facing":1,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[135,51,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[129,57,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[135,57,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":1},
		{"kind":"bed","rect":[117,62,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[111,68,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[117,68,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[126,62,2,2],"solid":"none","facing":3,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[120,68,1,1],"solid":"none","facing":0,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[127,68,1,1],"solid":"none","facing":1,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[135,62,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[129,68,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[135,68,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":1},
		{"kind":"bed","rect":[117,51,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[111,57,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[117,57,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[126,51,2,2],"solid":"none","facing":3,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[120,57,1,1],"solid":"none","facing":0,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[127,57,1,1],"solid":"none","facing":1,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[135,51,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[129,57,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[135,57,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":2},
		{"kind":"bed","rect":[117,62,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[111,68,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[117,68,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[126,62,2,2],"solid":"none","facing":3,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[120,68,1,1],"solid":"none","facing":0,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[127,68,1,1],"solid":"none","facing":1,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[135,62,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[129,68,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[135,68,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":2},
		{"kind":"bed","rect":[131,11,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[139,16,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[131,16,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[141,11,2,2],"solid":"low","facing":0,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[149,16,1,1],"solid":"low","facing":1,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[141,16,1,1],"solid":"low","facing":2,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[151,11,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[158,16,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[151,16,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"bed","rect":[131,21,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[139,26,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[131,26,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[141,21,2,2],"solid":"low","facing":0,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[149,26,1,1],"solid":"low","facing":1,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[141,26,1,1],"solid":"low","facing":2,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[151,21,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[158,26,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[151,26,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"bed","rect":[131,11,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[139,16,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[131,16,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[141,11,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[149,16,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[141,16,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[151,11,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[158,16,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[151,16,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"bed","rect":[131,21,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[139,26,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[131,26,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[141,21,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[149,26,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[141,26,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[151,21,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[158,26,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[151,26,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"bed","rect":[131,11,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[139,16,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[131,16,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[141,11,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[149,16,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[141,16,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[151,11,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[158,16,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[151,16,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":2},
		{"kind":"bed","rect":[131,21,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[139,26,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[131,26,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[141,21,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[149,26,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[141,26,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[151,21,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[158,26,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[151,26,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":2},
		{"kind":"bed","rect":[83,53,2,1],"solid":"low","facing":1,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[77,58,1,1],"solid":"low","facing":2,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[83,58,2,1],"solid":"low","facing":3,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[92,53,2,2],"solid":"low","facing":1,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[86,58,1,1],"solid":"low","facing":2,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[93,58,1,1],"solid":"low","facing":3,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[101,53,2,1],"solid":"low","facing":1,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[95,58,1,1],"solid":"low","facing":2,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[101,58,2,1],"solid":"low","facing":3,"note":"안방의 장롱","level":0},
		{"kind":"bed","rect":[83,63,2,1],"solid":"low","facing":1,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[77,68,1,1],"solid":"low","facing":2,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[83,68,2,1],"solid":"low","facing":3,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[92,63,2,2],"solid":"low","facing":1,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[86,68,1,1],"solid":"low","facing":2,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[93,68,1,1],"solid":"low","facing":3,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[101,63,2,1],"solid":"low","facing":1,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[95,68,1,1],"solid":"low","facing":2,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[101,68,2,1],"solid":"low","facing":3,"note":"안방의 장롱","level":0},
		{"kind":"bed","rect":[83,53,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[77,58,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[83,58,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[92,53,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[86,58,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[93,58,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[101,53,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[95,58,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[101,58,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":1},
		{"kind":"bed","rect":[83,63,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[77,68,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[83,68,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[92,63,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[86,68,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[93,68,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[101,63,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[95,68,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[101,68,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":1},
		{"kind":"bed","rect":[83,53,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[77,58,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[83,58,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[92,53,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[86,58,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[93,58,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[101,53,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[95,58,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[101,58,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":2},
		{"kind":"bed","rect":[83,63,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[77,68,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[83,68,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[92,63,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[86,68,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[93,68,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[101,63,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[95,68,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[101,68,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":2},
		{"kind":"shelf","rect":[121,33,3,1],"solid":"low","facing":2,"note":"매장의 선반","level":0},
		{"kind":"desk","rect":[122,38,2,1],"solid":"low","facing":3,"note":"매장의 책상","level":0},
		{"kind":"shelf","rect":[128,33,3,1],"solid":"low","facing":2,"note":"매장의 선반","level":0},
		{"kind":"desk","rect":[129,38,2,1],"solid":"low","facing":3,"note":"매장의 책상","level":0},
		{"kind":"desk","rect":[75,13,2,1],"solid":"none","facing":3,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[71,19,2,2],"solid":"none","facing":0,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[74,20,3,1],"solid":"none","facing":1,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[80,13,3,1],"solid":"none","facing":3,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[78,20,2,1],"solid":"none","facing":0,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[81,19,2,2],"solid":"none","facing":1,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"desk","rect":[137,33,2,1],"solid":"low","facing":0,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[140,37,2,2],"solid":"low","facing":1,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[137,38,3,1],"solid":"low","facing":2,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[143,33,3,1],"solid":"low","facing":0,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[145,38,2,1],"solid":"low","facing":1,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[143,37,2,2],"solid":"low","facing":2,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"desk","rect":[158,51,2,1],"solid":"low","facing":1,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[155,55,2,2],"solid":"low","facing":2,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[157,56,3,1],"solid":"low","facing":3,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[162,51,3,1],"solid":"low","facing":1,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[161,56,2,1],"solid":"low","facing":2,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[163,55,2,2],"solid":"low","facing":3,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"desk","rect":[55,58,2,1],"solid":"low","facing":2,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[59,62,2,2],"solid":"low","facing":3,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[55,63,3,1],"solid":"low","facing":0,"note":"작업실의 선반","level":0},
		{"kind":"desk","rect":[158,33,2,1],"solid":"low","facing":3,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[155,37,2,2],"solid":"low","facing":0,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[157,38,3,1],"solid":"low","facing":1,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[162,33,3,1],"solid":"low","facing":3,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[161,38,2,1],"solid":"low","facing":0,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[163,37,2,2],"solid":"low","facing":1,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"barrel","rect":[143,64,1,1],"solid":"low","facing":0,"note":"매장의 통","level":0},
		{"kind":"sack_pile","rect":[152,65,2,2],"solid":"low","facing":1,"note":"매장의 자루 더미","level":0},
		{"kind":"ice_sled_load","rect":[143,66,3,1],"solid":"low","facing":2,"note":"매장의 짐 실은 썰매","level":0},
		{"kind":"barrel","rect":[155,64,1,1],"solid":"low","facing":0,"note":"뒤 창고의 통","level":0},
		{"kind":"sack_pile","rect":[163,65,2,2],"solid":"low","facing":1,"note":"뒤 창고의 자루 더미","level":0},
		{"kind":"ice_sled_load","rect":[155,66,3,1],"solid":"low","facing":2,"note":"뒤 창고의 짐 실은 썰매","level":0},
		{"kind":"barrel","rect":[143,71,1,1],"solid":"low","facing":0,"note":"매장의 통","level":0},
		{"kind":"sack_pile","rect":[152,72,2,2],"solid":"low","facing":1,"note":"매장의 자루 더미","level":0},
		{"kind":"ice_sled_load","rect":[143,73,3,1],"solid":"low","facing":2,"note":"매장의 짐 실은 썰매","level":0},
		{"kind":"barrel","rect":[155,71,1,1],"solid":"low","facing":0,"note":"뒤 창고의 통","level":0},
		{"kind":"sack_pile","rect":[163,72,2,2],"solid":"low","facing":1,"note":"뒤 창고의 자루 더미","level":0},
		{"kind":"ice_sled_load","rect":[155,73,3,1],"solid":"low","facing":2,"note":"뒤 창고의 짐 실은 썰매","level":0},
		{"kind":"shop_counter","rect":[117,13,3,1],"solid":"low","facing":1,"note":"작업실의 가게 계산대","level":0},
		{"kind":"barrel","rect":[115,20,1,1],"solid":"none","facing":2,"note":"작업실의 통","level":0},
		{"kind":"shop_counter","rect":[117,20,3,1],"solid":"low","facing":3,"note":"작업실의 가게 계산대","level":0},
		{"kind":"shelf","rect":[122,13,3,1],"solid":"low","facing":1,"note":"뒤 창고의 선반","level":0},
		{"kind":"bread_rack","rect":[121,20,1,1],"solid":"low","facing":2,"note":"뒤 창고의 빵 선반","level":0},
		{"kind":"barrel","rect":[124,20,1,1],"solid":"low","facing":3,"note":"뒤 창고의 통","level":0},
		{"kind":"car","rect":[54,11,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
		{"kind":"bench","rect":[60,10,1,3],"solid":"low","facing":1,"note":"긴 의자","level":0},
		{"kind":"crate_stack","rect":[86,12,2,2],"solid":"low","facing":2,"note":"나무 상자 더미","level":0},
		{"kind":"ice_sled_load","rect":[107,24,3,1],"solid":"low","facing":3,"note":"짐 실은 썰매","level":0},
		{"kind":"door_pile","rect":[48,25,2,1],"solid":"none","facing":1,"note":"문짝 더미","level":0},
		{"kind":"firewood_pile","rect":[53,24,2,1],"solid":"none","facing":2,"note":"장작 더미","level":0},
		{"kind":"handcart","rect":[57,26,2,1],"solid":"none","facing":3,"note":"손수레","level":0},
		{"kind":"door_pile","rect":[20,25,2,1],"solid":"none","facing":0,"note":"문짝 더미","level":0},
		{"kind":"firewood_pile","rect":[25,24,2,1],"solid":"none","facing":1,"note":"장작 더미","level":0},
		{"kind":"handcart","rect":[29,26,2,1],"solid":"none","facing":2,"note":"손수레","level":0},
		{"kind":"door_pile","rect":[70,25,2,1],"solid":"none","facing":3,"note":"문짝 더미","level":0},
		{"kind":"firewood_pile","rect":[75,24,2,1],"solid":"none","facing":0,"note":"장작 더미","level":0},
		{"kind":"handcart","rect":[79,26,2,1],"solid":"none","facing":1,"note":"손수레","level":0},
		{"kind":"door_pile","rect":[76,49,2,1],"solid":"low","facing":2,"note":"문짝 더미","level":0},
		{"kind":"firewood_pile","rect":[81,48,2,1],"solid":"low","facing":3,"note":"장작 더미","level":0},
		{"kind":"handcart","rect":[85,50,2,1],"solid":"low","facing":0,"note":"손수레","level":0},
		{"kind":"car","rect":[52,43,4,2],"solid":"low","facing":1,"note":"버려진 차","level":0},
		{"kind":"bridge_rail","rect":[71,83,6,1],"solid":"low","facing":2,"note":"다리 난간","level":0},
		{"kind":"ice_sled_load","rect":[75,80,3,1],"solid":"low","facing":3,"note":"짐 실은 썰매","level":0},
		{"kind":"lamp_post","rect":[73,46,1,1],"solid":"none","facing":0,"note":"꺼진 등잔","level":0},
		{"kind":"crate_stack","rect":[74,48,2,2],"solid":"low","facing":1,"note":"나무 상자 더미","level":0},
		{"kind":"lamp_post","rect":[58,68,1,1],"solid":"none","facing":2,"note":"꺼진 등잔","level":0},
		{"kind":"crate_stack","rect":[59,70,2,2],"solid":"low","facing":3,"note":"나무 상자 더미","level":0},
		{"kind":"lamp_post","rect":[60,78,1,1],"solid":"none","facing":0,"note":"꺼진 등잔","level":0},
		{"kind":"crate_stack","rect":[61,80,2,2],"solid":"low","facing":1,"note":"나무 상자 더미","level":0},
		{"kind":"lamp_post","rect":[120,73,1,1],"solid":"none","facing":2,"note":"꺼진 등잔","level":0},
		{"kind":"crate_stack","rect":[121,75,2,2],"solid":"low","facing":3,"note":"나무 상자 더미","level":0},
		{"kind":"street_tree","rect":[70,23,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[128,23,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[119,27,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[13,29,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[14,35,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[5,39,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[102,41,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[131,41,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[160,41,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[78,42,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[107,42,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[136,42,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[165,42,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[21,48,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[50,48,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[79,48,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[108,48,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[137,48,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[166,48,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[55,49,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[84,49,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[113,49,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[142,49,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[70,52,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[143,55,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[153,57,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[71,58,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[158,58,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[4,62,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[5,68,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[63,68,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[136,71,1,1],"solid":"tree","facing":3,"note":"가로수","level":0}],
	"containers": [{"id":"cache_0","name":"매장 상자","cell":[59,31],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_1","name":"매장 상자","cell":[59,38],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_2","name":"매장 상자","cell":[61,31],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_3","name":"매장 상자","cell":[61,38],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_4","name":"매장 상자","cell":[39,13],"level":0,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_5","name":"뒤 창고 상자","cell":[50,13],"level":0,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_6","name":"매장 상자","cell":[39,22],"level":0,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_7","name":"뒤 창고 상자","cell":[50,22],"level":0,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_8","name":"매장 상자","cell":[39,13],"level":1,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_9","name":"뒤 창고 상자","cell":[50,13],"level":1,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_10","name":"매장 상자","cell":[39,22],"level":1,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_11","name":"뒤 창고 상자","cell":[50,22],"level":1,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_12","name":"저장 칸 상자","cell":[39,13],"level":-1,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_13","name":"저장 칸 상자","cell":[50,13],"level":-1,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_14","name":"저장 칸 상자","cell":[39,22],"level":-1,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_15","name":"저장 칸 상자","cell":[50,22],"level":-1,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_16","name":"매장 상자","cell":[27,31],"level":0,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_17","name":"뒤 창고 상자","cell":[38,31],"level":0,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_18","name":"매장 상자","cell":[28,38],"level":0,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_19","name":"뒤 창고 상자","cell":[38,38],"level":0,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_20","name":"매장 상자","cell":[29,31],"level":1,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_21","name":"뒤 창고 상자","cell":[39,31],"level":1,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_22","name":"매장 상자","cell":[29,38],"level":1,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_23","name":"뒤 창고 상자","cell":[39,38],"level":1,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_24","name":"작업실 상자","cell":[107,36],"level":0,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_25","name":"뒤 창고 상자","cell":[114,36],"level":0,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_26","name":"작업실 상자","cell":[105,37],"level":1,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_27","name":"뒤 창고 상자","cell":[112,37],"level":1,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_28","name":"매장 상자","cell":[79,32],"level":0,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_29","name":"뒤 창고 상자","cell":[90,32],"level":0,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_30","name":"매장 상자","cell":[79,40],"level":0,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_31","name":"뒤 창고 상자","cell":[90,40],"level":0,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_32","name":"안방 상자","cell":[96,14],"level":0,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_33","name":"부엌 상자","cell":[107,14],"level":0,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_34","name":"안방 상자","cell":[96,22],"level":0,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_35","name":"부엌 상자","cell":[107,22],"level":0,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_36","name":"안방 상자","cell":[96,14],"level":1,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_37","name":"부엌 상자","cell":[107,14],"level":1,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_38","name":"안방 상자","cell":[96,22],"level":1,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_39","name":"부엌 상자","cell":[107,22],"level":1,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_40","name":"안방 상자","cell":[96,14],"level":2,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_41","name":"부엌 상자","cell":[107,14],"level":2,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_42","name":"안방 상자","cell":[96,22],"level":2,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_43","name":"부엌 상자","cell":[107,22],"level":2,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_44","name":"부엌 상자","cell":[15,53],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_45","name":"안방 상자","cell":[15,58],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_46","name":"부엌 상자","cell":[22,53],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_47","name":"안방 상자","cell":[22,58],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_48","name":"부엌 상자","cell":[29,53],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_49","name":"안방 상자","cell":[29,58],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_50","name":"부엌 상자","cell":[35,53],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_51","name":"안방 상자","cell":[35,58],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_52","name":"부엌 상자","cell":[41,53],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_53","name":"안방 상자","cell":[41,58],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_54","name":"부엌 상자","cell":[47,53],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_55","name":"안방 상자","cell":[47,58],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_56","name":"부엌 상자","cell":[15,66],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_57","name":"안방 상자","cell":[15,71],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_58","name":"부엌 상자","cell":[22,66],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_59","name":"안방 상자","cell":[22,71],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_60","name":"부엌 상자","cell":[29,66],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_61","name":"안방 상자","cell":[29,71],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_62","name":"부엌 상자","cell":[35,66],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_63","name":"안방 상자","cell":[35,71],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_64","name":"부엌 상자","cell":[41,66],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_65","name":"안방 상자","cell":[41,71],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_66","name":"부엌 상자","cell":[47,66],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_67","name":"안방 상자","cell":[47,71],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_68","name":"부엌 상자","cell":[15,53],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_69","name":"안방 상자","cell":[15,58],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_70","name":"부엌 상자","cell":[22,53],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_71","name":"안방 상자","cell":[22,58],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_72","name":"부엌 상자","cell":[29,53],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_73","name":"안방 상자","cell":[29,58],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_74","name":"부엌 상자","cell":[35,53],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_75","name":"안방 상자","cell":[35,58],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_76","name":"부엌 상자","cell":[41,53],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_77","name":"안방 상자","cell":[41,58],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_78","name":"부엌 상자","cell":[47,53],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_79","name":"안방 상자","cell":[47,58],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_80","name":"부엌 상자","cell":[15,66],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_81","name":"안방 상자","cell":[15,71],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_82","name":"부엌 상자","cell":[22,66],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_83","name":"안방 상자","cell":[22,71],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_84","name":"부엌 상자","cell":[29,66],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_85","name":"안방 상자","cell":[29,71],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_86","name":"부엌 상자","cell":[35,66],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_87","name":"안방 상자","cell":[35,71],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_88","name":"부엌 상자","cell":[41,66],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_89","name":"안방 상자","cell":[41,71],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_90","name":"부엌 상자","cell":[47,66],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_91","name":"안방 상자","cell":[47,71],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_92","name":"부엌 상자","cell":[15,53],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_93","name":"안방 상자","cell":[15,58],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_94","name":"부엌 상자","cell":[22,53],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_95","name":"안방 상자","cell":[22,58],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_96","name":"부엌 상자","cell":[29,53],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_97","name":"안방 상자","cell":[29,58],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_98","name":"부엌 상자","cell":[35,53],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_99","name":"안방 상자","cell":[35,58],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_100","name":"부엌 상자","cell":[41,53],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_101","name":"안방 상자","cell":[41,58],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_102","name":"부엌 상자","cell":[47,53],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_103","name":"안방 상자","cell":[47,58],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_104","name":"부엌 상자","cell":[15,66],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_105","name":"안방 상자","cell":[15,71],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_106","name":"부엌 상자","cell":[22,66],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_107","name":"안방 상자","cell":[22,71],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_108","name":"부엌 상자","cell":[29,66],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_109","name":"안방 상자","cell":[29,71],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_110","name":"부엌 상자","cell":[35,66],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_111","name":"안방 상자","cell":[35,71],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_112","name":"부엌 상자","cell":[41,66],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_113","name":"안방 상자","cell":[41,71],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_114","name":"부엌 상자","cell":[47,66],"level":2,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_115","name":"안쪽 저장 상자","cell":[47,71],"level":2,"building":6,"search":4,"items":["plank","plank","plank","plank"],"locked":true,"searched":false},
		{"id":"cache_116","name":"부엌 상자","cell":[15,53],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_117","name":"안방 상자","cell":[15,58],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_118","name":"부엌 상자","cell":[22,53],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_119","name":"안방 상자","cell":[22,58],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_120","name":"부엌 상자","cell":[29,53],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_121","name":"안방 상자","cell":[29,58],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_122","name":"부엌 상자","cell":[35,53],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_123","name":"안방 상자","cell":[35,58],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_124","name":"부엌 상자","cell":[41,53],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_125","name":"안방 상자","cell":[41,58],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_126","name":"부엌 상자","cell":[47,53],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_127","name":"안방 상자","cell":[47,58],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_128","name":"부엌 상자","cell":[15,66],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_129","name":"안방 상자","cell":[15,71],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_130","name":"부엌 상자","cell":[22,66],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_131","name":"안방 상자","cell":[22,71],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_132","name":"부엌 상자","cell":[29,66],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_133","name":"안방 상자","cell":[29,71],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_134","name":"부엌 상자","cell":[35,66],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_135","name":"안방 상자","cell":[36,70],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_136","name":"부엌 상자","cell":[41,66],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_137","name":"안방 상자","cell":[42,70],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_138","name":"부엌 상자","cell":[47,66],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_139","name":"안방 상자","cell":[48,70],"level":-1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_140","name":"안방 상자","cell":[116,57],"level":0,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_141","name":"부엌 상자","cell":[126,57],"level":0,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_142","name":"안방 상자","cell":[134,57],"level":0,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_143","name":"안방 상자","cell":[116,68],"level":0,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_144","name":"부엌 상자","cell":[126,68],"level":0,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_145","name":"안방 상자","cell":[134,68],"level":0,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_146","name":"안방 상자","cell":[116,57],"level":1,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_147","name":"부엌 상자","cell":[126,57],"level":1,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_148","name":"안방 상자","cell":[134,57],"level":1,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_149","name":"안방 상자","cell":[116,68],"level":1,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_150","name":"부엌 상자","cell":[126,68],"level":1,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_151","name":"안방 상자","cell":[134,68],"level":1,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_152","name":"안방 상자","cell":[116,57],"level":2,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_153","name":"부엌 상자","cell":[126,57],"level":2,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_154","name":"안방 상자","cell":[134,57],"level":2,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_155","name":"안방 상자","cell":[116,68],"level":2,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_156","name":"부엌 상자","cell":[126,68],"level":2,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_157","name":"안방 상자","cell":[134,68],"level":2,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_158","name":"안방 상자","cell":[138,16],"level":0,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_159","name":"부엌 상자","cell":[148,16],"level":0,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_160","name":"안방 상자","cell":[157,16],"level":0,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_161","name":"안방 상자","cell":[138,26],"level":0,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_162","name":"부엌 상자","cell":[148,26],"level":0,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_163","name":"안방 상자","cell":[157,26],"level":0,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_164","name":"안방 상자","cell":[138,16],"level":1,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_165","name":"부엌 상자","cell":[148,16],"level":1,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_166","name":"안방 상자","cell":[157,16],"level":1,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_167","name":"안방 상자","cell":[138,26],"level":1,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_168","name":"부엌 상자","cell":[148,26],"level":1,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_169","name":"안방 상자","cell":[157,26],"level":1,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_170","name":"안방 상자","cell":[138,16],"level":2,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_171","name":"부엌 상자","cell":[148,16],"level":2,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_172","name":"안방 상자","cell":[157,16],"level":2,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_173","name":"안방 상자","cell":[138,26],"level":2,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_174","name":"부엌 상자","cell":[148,26],"level":2,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_175","name":"안방 상자","cell":[157,26],"level":2,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_176","name":"안방 상자","cell":[82,58],"level":0,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_177","name":"부엌 상자","cell":[92,58],"level":0,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_178","name":"안방 상자","cell":[100,58],"level":0,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_179","name":"안방 상자","cell":[82,68],"level":0,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_180","name":"부엌 상자","cell":[92,68],"level":0,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_181","name":"안방 상자","cell":[100,68],"level":0,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_182","name":"안방 상자","cell":[82,58],"level":1,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_183","name":"부엌 상자","cell":[92,58],"level":1,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_184","name":"안방 상자","cell":[100,58],"level":1,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_185","name":"안방 상자","cell":[82,68],"level":1,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_186","name":"부엌 상자","cell":[92,68],"level":1,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_187","name":"안방 상자","cell":[100,68],"level":1,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_188","name":"안방 상자","cell":[82,58],"level":2,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_189","name":"부엌 상자","cell":[92,58],"level":2,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_190","name":"안방 상자","cell":[100,58],"level":2,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_191","name":"안방 상자","cell":[82,68],"level":2,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_192","name":"부엌 상자","cell":[92,68],"level":2,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_193","name":"안방 상자","cell":[100,68],"level":2,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_194","name":"매장 상자","cell":[121,38],"level":0,"building":10,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_195","name":"매장 상자","cell":[128,38],"level":0,"building":10,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_196","name":"작업실 상자","cell":[73,20],"level":0,"building":11,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_197","name":"뒤 창고 상자","cell":[80,20],"level":0,"building":11,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_198","name":"작업실 상자","cell":[139,37],"level":0,"building":12,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_199","name":"뒤 창고 상자","cell":[146,37],"level":0,"building":12,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_200","name":"작업실 상자","cell":[159,55],"level":0,"building":13,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_201","name":"뒤 창고 상자","cell":[162,55],"level":0,"building":13,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_202","name":"작업실 상자","cell":[58,63],"level":0,"building":14,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_203","name":"작업실 상자","cell":[159,37],"level":0,"building":15,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_204","name":"뒤 창고 상자","cell":[162,37],"level":0,"building":15,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_205","name":"매장 상자","cell":[151,66],"level":0,"building":16,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_206","name":"뒤 창고 상자","cell":[162,66],"level":0,"building":16,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_207","name":"매장 상자","cell":[151,73],"level":0,"building":16,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_208","name":"먼 끝 저장 상자","cell":[162,73],"level":0,"building":16,"search":4,"items":["plank","plank","plank","plank"],"locked":true,"searched":false},
		{"id":"cache_209","name":"작업실 상자","cell":[116,20],"level":0,"building":17,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_210","name":"뒤 창고 상자","cell":[123,20],"level":0,"building":17,"search":4,"items":["plank"],"locked":false,"searched":false}],
	"spots": [{"id":"salvage_0","kind":"salvage","name":"남은 목재","cell":[59,31],"material":"wood","amount":2,"state":"intact"},
		{"id":"salvage_1","kind":"salvage","name":"남은 목재","cell":[59,38],"material":"wood","amount":2,"state":"intact"}],
	"slots": ["E","F"],
	"dead": [[0,30],[0,77],[169,44],[169,59],[64,99],[71,47],[56,69],[58,79],[118,74]],
	"forecourts": [{"cell":[48,33],"normal":[-1,0],"cells":[[47,35],[47,34],[47,33],[47,32],[47,31],[46,35],[46,34],[46,33],[46,32],[46,31],[45,35],[45,34],[45,33],[45,32],[45,31],[44,35],[44,34],[44,33],[44,32],[44,31]],"building":0},
		{"cell":[63,33],"normal":[1,0],"cells":[[64,31],[64,32],[64,33],[64,34],[64,35],[65,31],[65,32],[65,33],[65,34],[65,35],[66,31],[66,32],[66,33],[66,34],[66,35],[67,31],[67,32],[67,33],[67,34],[67,35]],"building":0},
		{"cell":[30,15],"normal":[-1,0],"cells":[[29,17],[29,16],[29,15],[29,14],[29,13],[28,17],[28,16],[28,15],[28,14],[28,13],[27,17],[27,16],[27,15],[27,14],[27,13],[26,17],[26,16],[26,15],[26,14],[26,13]],"building":1},
		{"cell":[53,15],"normal":[1,0],"cells":[[54,13],[54,14],[54,15],[54,16],[54,17],[55,13],[55,14],[55,15],[55,16],[55,17],[56,13],[56,14],[56,15],[56,16],[56,17],[57,13],[57,14],[57,15],[57,16],[57,17]],"building":1},
		{"cell":[20,33],"normal":[-1,0],"cells":[[19,35],[19,34],[19,33],[19,32],[19,31],[18,35],[18,34],[18,33],[18,32],[18,31],[17,35],[17,34],[17,33],[17,32],[17,31],[16,35],[16,34],[16,33],[16,32],[16,31]],"building":2},
		{"cell":[41,33],"normal":[1,0],"cells":[[42,31],[42,32],[42,33],[42,34],[42,35],[43,31],[43,32],[43,33],[43,34],[43,35],[44,31],[44,32],[44,33],[44,34],[44,35],[45,31],[45,32],[45,33],[45,34],[45,35]],"building":2},
		{"cell":[100,34],"normal":[-1,0],"cells":[[99,36],[99,35],[99,34],[99,33],[99,32],[98,36],[98,35],[98,34],[98,33],[98,32],[97,36],[97,35],[97,34],[97,33],[97,32],[96,36],[96,35],[96,34],[96,33],[96,32]],"building":3},
		{"cell":[115,34],"normal":[1,0],"cells":[[116,32],[116,33],[116,34],[116,35],[116,36],[117,32],[117,33],[117,34],[117,35],[117,36],[118,32],[118,33],[118,34],[118,35],[118,36],[119,32],[119,33],[119,34],[119,35],[119,36]],"building":3},
		{"cell":[70,34],"normal":[-1,0],"cells":[[69,36],[69,35],[69,34],[69,33],[69,32],[68,36],[68,35],[68,34],[68,33],[68,32],[67,36],[67,35],[67,34],[67,33],[67,32],[66,36],[66,35],[66,34],[66,33],[66,32]],"building":4},
		{"cell":[93,34],"normal":[1,0],"cells":[[94,32],[94,33],[94,34],[94,35],[94,36],[95,32],[95,33],[95,34],[95,35],[95,36],[96,32],[96,33],[96,34],[96,35],[96,36],[97,32],[97,33],[97,34],[97,35],[97,36]],"building":4},
		{"cell":[88,16],"normal":[-1,0],"cells":[[87,18],[87,17],[87,16],[87,15],[87,14],[86,18],[86,17],[86,16],[86,15],[86,14],[85,18],[85,17],[85,16],[85,15],[85,14],[84,18],[84,17],[84,16],[84,15],[84,14]],"building":5},
		{"cell":[109,16],"normal":[1,0],"cells":[[110,14],[110,15],[110,16],[110,17],[110,18],[111,14],[111,15],[111,16],[111,17],[111,18],[112,14],[112,15],[112,16],[112,17],[112,18],[113,14],[113,15],[113,16],[113,17],[113,18]],"building":5},
		{"cell":[10,60],"normal":[-1,0],"cells":[[9,62],[9,61],[9,60],[9,59],[9,58],[8,62],[8,61],[8,60],[8,59],[8,58],[7,62],[7,61],[7,60],[7,59],[7,58],[6,62],[6,61],[6,60],[6,59],[6,58]],"building":6},
		{"cell":[49,60],"normal":[1,0],"cells":[[50,58],[50,59],[50,60],[50,61],[50,62],[51,58],[51,59],[51,60],[51,61],[51,62],[52,58],[52,59],[52,60],[52,61],[52,62],[53,58],[53,59],[53,60],[53,61],[53,62]],"building":6},
		{"cell":[110,59],"normal":[-1,0],"cells":[[109,61],[109,60],[109,59],[109,58],[109,57],[108,61],[108,60],[108,59],[108,58],[108,57],[107,61],[107,60],[107,59],[107,58],[107,57],[106,61],[106,60],[106,59],[106,58],[106,57]],"building":7},
		{"cell":[137,59],"normal":[1,0],"cells":[[138,57],[138,58],[138,59],[138,60],[138,61],[139,57],[139,58],[139,59],[139,60],[139,61],[140,57],[140,58],[140,59],[140,60],[140,61],[141,57],[141,58],[141,59],[141,60],[141,61]],"building":7},
		{"cell":[130,18],"normal":[-1,0],"cells":[[129,20],[129,19],[129,18],[129,17],[129,16],[128,20],[128,19],[128,18],[128,17],[128,16],[127,20],[127,19],[127,18],[127,17],[127,16],[126,20],[126,19],[126,18],[126,17],[126,16]],"building":8},
		{"cell":[159,18],"normal":[1,0],"cells":[[160,16],[160,17],[160,18],[160,19],[160,20],[161,16],[161,17],[161,18],[161,19],[161,20],[162,16],[162,17],[162,18],[162,19],[162,20],[163,16],[163,17],[163,18],[163,19],[163,20]],"building":8},
		{"cell":[76,60],"normal":[-1,0],"cells":[[75,62],[75,61],[75,60],[75,59],[75,58],[74,62],[74,61],[74,60],[74,59],[74,58],[73,62],[73,61],[73,60],[73,59],[73,58],[72,62],[72,61],[72,60],[72,59],[72,58]],"building":9},
		{"cell":[103,60],"normal":[1,0],"cells":[[104,58],[104,59],[104,60],[104,61],[104,62],[105,58],[105,59],[105,60],[105,61],[105,62],[106,58],[106,59],[106,60],[106,61],[106,62],[107,58],[107,59],[107,60],[107,61],[107,62]],"building":9},
		{"cell":[125,32],"normal":[0,-1],"cells":[[123,31],[124,31],[125,31],[126,31],[127,31],[123,30],[124,30],[125,30],[126,30],[127,30],[123,29],[124,29],[125,29],[126,29],[127,29],[123,28],[124,28],[125,28],[126,28],[127,28]],"building":10},
		{"cell":[125,39],"normal":[0,1],"cells":[[127,40],[126,40],[125,40],[124,40],[123,40],[127,41],[126,41],[125,41],[124,41],[123,41],[127,42],[126,42],[125,42],[124,42],[123,42],[127,43],[126,43],[125,43],[124,43],[123,43]],"building":10},
		{"cell":[70,17],"normal":[-1,0],"cells":[[69,19],[69,18],[69,17],[69,16],[69,15],[68,19],[68,18],[68,17],[68,16],[68,15],[67,19],[67,18],[67,17],[67,16],[67,15],[66,19],[66,18],[66,17],[66,16],[66,15]],"building":11},
		{"cell":[83,17],"normal":[1,0],"cells":[[84,15],[84,16],[84,17],[84,18],[84,19],[85,15],[85,16],[85,17],[85,18],[85,19],[86,15],[86,16],[86,17],[86,18],[86,19],[87,15],[87,16],[87,17],[87,18],[87,19]],"building":11},
		{"cell":[136,36],"normal":[-1,0],"cells":[[135,38],[135,37],[135,36],[135,35],[135,34],[134,38],[134,37],[134,36],[134,35],[134,34],[133,38],[133,37],[133,36],[133,35],[133,34],[132,38],[132,37],[132,36],[132,35],[132,34]],"building":12},
		{"cell":[147,36],"normal":[1,0],"cells":[[148,34],[148,35],[148,36],[148,37],[148,38],[149,34],[149,35],[149,36],[149,37],[149,38],[150,34],[150,35],[150,36],[150,37],[150,38],[151,34],[151,35],[151,36],[151,37],[151,38]],"building":12},
		{"cell":[154,54],"normal":[-1,0],"cells":[[153,56],[153,55],[153,54],[153,53],[153,52],[152,56],[152,55],[152,54],[152,53],[152,52],[151,56],[151,55],[151,54],[151,53],[151,52],[150,56],[150,55],[150,54],[150,53],[150,52]],"building":13},
		{"cell":[165,54],"normal":[1,0],"cells":[[166,52],[166,53],[166,54],[166,55],[166,56],[167,52],[167,53],[167,54],[167,55],[167,56],[168,52],[168,53],[168,54],[168,55],[168,56],[169,52],[169,53],[169,54],[169,55],[169,56]],"building":13},
		{"cell":[54,61],"normal":[-1,0],"cells":[[53,63],[53,62],[53,61],[53,60],[53,59],[52,63],[52,62],[52,61],[52,60],[52,59],[51,63],[51,62],[51,61],[51,60],[51,59],[50,63],[50,62],[50,61],[50,60],[50,59]],"building":14},
		{"cell":[61,61],"normal":[1,0],"cells":[[62,59],[62,60],[62,61],[62,62],[62,63],[63,59],[63,60],[63,61],[63,62],[63,63],[64,59],[64,60],[64,61],[64,62],[64,63],[65,59],[65,60],[65,61],[65,62],[65,63]],"building":14},
		{"cell":[154,36],"normal":[-1,0],"cells":[[153,38],[153,37],[153,36],[153,35],[153,34],[152,38],[152,37],[152,36],[152,35],[152,34],[151,38],[151,37],[151,36],[151,35],[151,34],[150,38],[150,37],[150,36],[150,35],[150,34]],"building":15},
		{"cell":[165,36],"normal":[1,0],"cells":[[166,34],[166,35],[166,36],[166,37],[166,38],[167,34],[167,35],[167,36],[167,37],[167,38],[168,34],[168,35],[168,36],[168,37],[168,38],[169,34],[169,35],[169,36],[169,37],[169,38]],"building":15},
		{"cell":[142,68],"normal":[-1,0],"cells":[[141,70],[141,69],[141,68],[141,67],[141,66],[140,70],[140,69],[140,68],[140,67],[140,66],[139,70],[139,69],[139,68],[139,67],[139,66],[138,70],[138,69],[138,68],[138,67],[138,66]],"building":16},
		{"cell":[165,68],"normal":[1,0],"cells":[[166,66],[166,67],[166,68],[166,69],[166,70],[167,66],[167,67],[167,68],[167,69],[167,70],[168,66],[168,67],[168,68],[168,69],[168,70],[169,66],[169,67],[169,68],[169,69],[169,70]],"building":16},
		{"cell":[114,17],"normal":[-1,0],"cells":[[113,19],[113,18],[113,17],[113,16],[113,15],[112,19],[112,18],[112,17],[112,16],[112,15],[111,19],[111,18],[111,17],[111,16],[111,15],[110,19],[110,18],[110,17],[110,16],[110,15]],"building":17},
		{"cell":[125,17],"normal":[1,0],"cells":[[126,15],[126,16],[126,17],[126,18],[126,19],[127,15],[127,16],[127,17],[127,18],[127,19],[128,15],[128,16],[128,17],[128,18],[128,19],[129,15],[129,16],[129,17],[129,18],[129,19]],"building":17}],
	"logs": ["snow_drifts_0"],
	"deep": [{"cell":[47,71],"level":2,"id":"cache_115","distance":102},
		{"cell":[162,73],"level":0,"id":"cache_208","distance":149}]
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
	"number": 1,
	"width": 170,
	"height": 46,
	"judgment": "철물과 부품을 얻는 대신 아래쪽 목공방 앞의 목재 한 짐을 놓치고, 가장 값진 부품은 막다른 뒷거리 끝 창고에 있어 걸음이 길다.",
	"zones": [
		{
			"id": "I",
			"name": "수리 구역",
			"rect": [
				0,
				0,
				120,
				46
			]
		},
		{
			"id": "J",
			"name": "동쪽 뒤뜰",
			"rect": [
				120,
				0,
				50,
				46
			]
		}
	],
	"grounds": [
		{
			"rect": [
				0,
				2,
				153,
				5
			],
			"floor": 1
		},
		{
			"rect": [
				39,
				7,
				6,
				36
			],
			"floor": 1
		},
		{
			"rect": [
				89,
				7,
				5,
				36
			],
			"floor": 1
		},
		{
			"rect": [
				124,
				9,
				46,
				4
			],
			"floor": 1
		},
		{
			"rect": [
				70,
				0,
				4,
				3
			],
			"floor": 1
		},
		{
			"rect": [
				120,
				14,
				50,
				30
			],
			"floor": 7
		},
		{
			"rect": [
				6,
				33,
				15,
				10
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
			"id": 18,
			"name": "철물 도매동",
			"rect": [
				0,
				9,
				39,
				15
			],
			"top": 3,
			"basement": true,
			"role": "store",
			"stock": [
				"parts_rack",
				"hardware_rack",
				"desk",
				"crate_stack"
			]
		},
		{
			"id": 19,
			"name": "부품 가게",
			"rect": [
				45,
				13,
				14,
				11
			],
			"top": 2,
			"basement": false,
			"role": "shop",
			"stock": [
				"parts_rack",
				"hardware_rack",
				"barrel"
			]
		},
		{
			"id": 20,
			"name": "정비 차고",
			"rect": [
				59,
				12,
				18,
				12
			],
			"top": 1,
			"basement": false,
			"role": "store",
			"stock": [
				"parts_rack",
				"desk",
				"barrel"
			]
		},
		{
			"id": 21,
			"name": "공구장이 살림집",
			"rect": [
				77,
				11,
				12,
				13
			],
			"top": 2,
			"basement": false,
			"role": "home",
			"stock": [
				"parts_rack",
				"hardware_rack",
				"desk",
				"crate_stack"
			]
		},
		{
			"id": 22,
			"name": "살림집",
			"rect": [
				94,
				10,
				16,
				14
			],
			"top": 2,
			"basement": false,
			"role": "home",
			"stock": [
				"parts_rack",
				"hardware_rack",
				"desk",
				"crate_stack"
			]
		},
		{
			"id": 23,
			"name": "텃밭 헛간",
			"rect": [
				110,
				15,
				10,
				9
			],
			"top": 1,
			"basement": false,
			"role": "store",
			"stock": [
				"garden_rack",
				"sack_pile",
				"barrel"
			]
		},
		{
			"id": 24,
			"name": "공동 차고",
			"rect": [
				132,
				15,
				14,
				9
			],
			"top": 1,
			"basement": false,
			"role": "store",
			"stock": [
				"parts_rack",
				"barrel",
				"desk"
			]
		},
		{
			"id": 25,
			"name": "부품 창고",
			"rect": [
				153,
				0,
				14,
				8
			],
			"top": 1,
			"basement": true,
			"role": "store",
			"stock": [
				"parts_rack",
				"hardware_rack",
				"crate_stack"
			]
		}
	],
	"shells": [
		{
			"rect": [
				0,
				9,
				39,
				15
			],
			"building": 18,
			"level": -1
		},
		{
			"rect": [
				0,
				9,
				39,
				15
			],
			"building": 18,
			"level": 0
		},
		{
			"rect": [
				0,
				9,
				39,
				15
			],
			"building": 18,
			"level": 1
		},
		{
			"rect": [
				0,
				9,
				39,
				15
			],
			"building": 18,
			"level": 2
		},
		{
			"rect": [
				45,
				13,
				14,
				11
			],
			"building": 19,
			"level": 0
		},
		{
			"rect": [
				45,
				13,
				14,
				11
			],
			"building": 19,
			"level": 1
		},
		{
			"rect": [
				59,
				12,
				18,
				12
			],
			"building": 20,
			"level": 0
		},
		{
			"rect": [
				77,
				11,
				12,
				13
			],
			"building": 21,
			"level": 0
		},
		{
			"rect": [
				77,
				11,
				12,
				13
			],
			"building": 21,
			"level": 1
		},
		{
			"rect": [
				94,
				10,
				16,
				14
			],
			"building": 22,
			"level": 0
		},
		{
			"rect": [
				94,
				10,
				16,
				14
			],
			"building": 22,
			"level": 1
		},
		{
			"rect": [
				110,
				15,
				10,
				9
			],
			"building": 23,
			"level": 0
		},
		{
			"rect": [
				132,
				15,
				14,
				9
			],
			"building": 24,
			"level": 0
		},
		{
			"rect": [
				153,
				0,
				14,
				8
			],
			"building": 25,
			"level": -1
		},
		{
			"rect": [
				153,
				0,
				14,
				8
			],
			"building": 25,
			"level": 0
		}
	],
	"walls": [
		{
			"rect": [
				1,
				20,
				37,
				1
			],
			"level": -1
		},
		{
			"rect": [
				7,
				10,
				1,
				10
			],
			"level": -1
		},
		{
			"rect": [
				14,
				10,
				1,
				10
			],
			"level": -1
		},
		{
			"rect": [
				20,
				10,
				1,
				10
			],
			"level": -1
		},
		{
			"rect": [
				26,
				10,
				1,
				10
			],
			"level": -1
		},
		{
			"rect": [
				32,
				10,
				1,
				10
			],
			"level": -1
		},
		{
			"rect": [
				1,
				20,
				37,
				1
			],
			"level": 0
		},
		{
			"rect": [
				7,
				10,
				1,
				10
			],
			"level": 0
		},
		{
			"rect": [
				14,
				10,
				1,
				10
			],
			"level": 0
		},
		{
			"rect": [
				20,
				10,
				1,
				10
			],
			"level": 0
		},
		{
			"rect": [
				26,
				10,
				1,
				10
			],
			"level": 0
		},
		{
			"rect": [
				32,
				10,
				1,
				10
			],
			"level": 0
		},
		{
			"rect": [
				1,
				20,
				37,
				1
			],
			"level": 1
		},
		{
			"rect": [
				7,
				10,
				1,
				10
			],
			"level": 1
		},
		{
			"rect": [
				14,
				10,
				1,
				10
			],
			"level": 1
		},
		{
			"rect": [
				20,
				10,
				1,
				10
			],
			"level": 1
		},
		{
			"rect": [
				26,
				10,
				1,
				10
			],
			"level": 1
		},
		{
			"rect": [
				32,
				10,
				1,
				10
			],
			"level": 1
		},
		{
			"rect": [
				1,
				20,
				37,
				1
			],
			"level": 2
		},
		{
			"rect": [
				7,
				10,
				1,
				10
			],
			"level": 2
		},
		{
			"rect": [
				14,
				10,
				1,
				10
			],
			"level": 2
		},
		{
			"rect": [
				20,
				10,
				1,
				10
			],
			"level": 2
		},
		{
			"rect": [
				26,
				10,
				1,
				10
			],
			"level": 2
		},
		{
			"rect": [
				32,
				10,
				1,
				10
			],
			"level": 2
		},
		{
			"rect": [
				46,
				18,
				12,
				1
			],
			"level": 0
		},
		{
			"rect": [
				46,
				18,
				12,
				1
			],
			"level": 1
		},
		{
			"rect": [
				60,
				20,
				16,
				1
			],
			"level": 0
		},
		{
			"rect": [
				68,
				13,
				1,
				7
			],
			"level": 0
		},
		{
			"rect": [
				78,
				20,
				10,
				1
			],
			"level": 0
		},
		{
			"rect": [
				83,
				12,
				1,
				8
			],
			"level": 0
		},
		{
			"rect": [
				78,
				20,
				10,
				1
			],
			"level": 1
		},
		{
			"rect": [
				83,
				12,
				1,
				8
			],
			"level": 1
		},
		{
			"rect": [
				95,
				20,
				14,
				1
			],
			"level": 0
		},
		{
			"rect": [
				102,
				11,
				1,
				9
			],
			"level": 0
		},
		{
			"rect": [
				95,
				20,
				14,
				1
			],
			"level": 1
		},
		{
			"rect": [
				102,
				11,
				1,
				9
			],
			"level": 1
		},
		{
			"rect": [
				111,
				20,
				8,
				1
			],
			"level": 0
		},
		{
			"rect": [
				115,
				16,
				1,
				4
			],
			"level": 0
		},
		{
			"rect": [
				133,
				20,
				12,
				1
			],
			"level": 0
		},
		{
			"rect": [
				139,
				16,
				1,
				4
			],
			"level": 0
		},
		{
			"rect": [
				154,
				4,
				12,
				1
			],
			"level": -1
		},
		{
			"rect": [
				160,
				1,
				1,
				3
			],
			"level": -1
		},
		{
			"rect": [
				154,
				4,
				12,
				1
			],
			"level": 0
		},
		{
			"rect": [
				160,
				1,
				1,
				3
			],
			"level": 0
		}
	],
	"doors": [
		{
			"cell": [
				4,
				20
			],
			"level": -1,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				11,
				20
			],
			"level": -1,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				17,
				20
			],
			"level": -1,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				23,
				20
			],
			"level": -1,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				29,
				20
			],
			"level": -1,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				35,
				20
			],
			"level": -1,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				4,
				20
			],
			"level": 0,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				11,
				20
			],
			"level": 0,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				17,
				20
			],
			"level": 0,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				23,
				20
			],
			"level": 0,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				29,
				20
			],
			"level": 0,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				35,
				20
			],
			"level": 0,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				19,
				23
			],
			"level": 0,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				4,
				20
			],
			"level": 1,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				11,
				20
			],
			"level": 1,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				17,
				20
			],
			"level": 1,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				23,
				20
			],
			"level": 1,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				29,
				20
			],
			"level": 1,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				35,
				20
			],
			"level": 1,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				4,
				20
			],
			"level": 2,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				11,
				20
			],
			"level": 2,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				17,
				20
			],
			"level": 2,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				23,
				20
			],
			"level": 2,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				29,
				20
			],
			"level": 2,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				35,
				20
			],
			"level": 2,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				52,
				18
			],
			"level": 0,
			"building": 19,
			"state": "closed"
		},
		{
			"cell": [
				52,
				23
			],
			"level": 0,
			"building": 19,
			"state": "closed"
		},
		{
			"cell": [
				52,
				13
			],
			"level": 0,
			"building": 19,
			"state": "closed"
		},
		{
			"cell": [
				52,
				18
			],
			"level": 1,
			"building": 19,
			"state": "closed"
		},
		{
			"cell": [
				64,
				20
			],
			"level": 0,
			"building": 20,
			"state": "closed"
		},
		{
			"cell": [
				72,
				20
			],
			"level": 0,
			"building": 20,
			"state": "closed"
		},
		{
			"cell": [
				68,
				23
			],
			"level": 0,
			"building": 20,
			"state": "closed"
		},
		{
			"cell": [
				80,
				20
			],
			"level": 0,
			"building": 21,
			"state": "closed"
		},
		{
			"cell": [
				86,
				20
			],
			"level": 0,
			"building": 21,
			"state": "closed"
		},
		{
			"cell": [
				83,
				23
			],
			"level": 0,
			"building": 21,
			"state": "closed"
		},
		{
			"cell": [
				80,
				20
			],
			"level": 1,
			"building": 21,
			"state": "closed"
		},
		{
			"cell": [
				86,
				20
			],
			"level": 1,
			"building": 21,
			"state": "closed"
		},
		{
			"cell": [
				98,
				20
			],
			"level": 0,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				106,
				20
			],
			"level": 0,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				102,
				23
			],
			"level": 0,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				98,
				20
			],
			"level": 1,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				106,
				20
			],
			"level": 1,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				113,
				20
			],
			"level": 0,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				117,
				20
			],
			"level": 0,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				115,
				23
			],
			"level": 0,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				136,
				20
			],
			"level": 0,
			"building": 24,
			"state": "closed"
		},
		{
			"cell": [
				142,
				20
			],
			"level": 0,
			"building": 24,
			"state": "closed"
		},
		{
			"cell": [
				139,
				23
			],
			"level": 0,
			"building": 24,
			"state": "closed"
		},
		{
			"cell": [
				157,
				4
			],
			"level": -1,
			"building": 25,
			"state": "closed"
		},
		{
			"cell": [
				163,
				4
			],
			"level": -1,
			"building": 25,
			"state": "closed"
		},
		{
			"cell": [
				157,
				4
			],
			"level": 0,
			"building": 25,
			"state": "closed"
		},
		{
			"cell": [
				163,
				4
			],
			"level": 0,
			"building": 25,
			"state": "closed"
		},
		{
			"cell": [
				160,
				7
			],
			"level": 0,
			"building": 25,
			"state": "closed"
		},
		{
			"cell": [
				4,
				9
			],
			"level": 0,
			"building": 18,
			"state": "closed"
		}
	],
	"windows": [
		{
			"cell": [
				11,
				9
			],
			"level": 0,
			"building": 18
		},
		{
			"cell": [
				17,
				9
			],
			"level": 0,
			"building": 18
		},
		{
			"cell": [
				23,
				9
			],
			"level": 0,
			"building": 18
		},
		{
			"cell": [
				29,
				9
			],
			"level": 0,
			"building": 18
		},
		{
			"cell": [
				35,
				9
			],
			"level": 0,
			"building": 18
		},
		{
			"cell": [
				64,
				12
			],
			"level": 0,
			"building": 20
		},
		{
			"cell": [
				72,
				12
			],
			"level": 0,
			"building": 20
		},
		{
			"cell": [
				80,
				11
			],
			"level": 0,
			"building": 21
		},
		{
			"cell": [
				86,
				11
			],
			"level": 0,
			"building": 21
		},
		{
			"cell": [
				98,
				10
			],
			"level": 0,
			"building": 22
		},
		{
			"cell": [
				106,
				10
			],
			"level": 0,
			"building": 22
		},
		{
			"cell": [
				113,
				15
			],
			"level": 0,
			"building": 23
		},
		{
			"cell": [
				117,
				15
			],
			"level": 0,
			"building": 23
		},
		{
			"cell": [
				136,
				15
			],
			"level": 0,
			"building": 24
		},
		{
			"cell": [
				142,
				15
			],
			"level": 0,
			"building": 24
		},
		{
			"cell": [
				157,
				0
			],
			"level": 0,
			"building": 25
		},
		{
			"cell": [
				163,
				0
			],
			"level": 0,
			"building": 25
		}
	],
	"stairs": [
		{
			"cell": [
				2,
				21
			],
			"low": -1,
			"high": 0
		},
		{
			"cell": [
				2,
				21
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				2,
				21
			],
			"low": 1,
			"high": 2
		},
		{
			"cell": [
				36,
				21
			],
			"low": -1,
			"high": 0
		},
		{
			"cell": [
				36,
				21
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				36,
				21
			],
			"low": 1,
			"high": 2
		},
		{
			"cell": [
				56,
				15
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				79,
				21
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				96,
				21
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				155,
				5
			],
			"low": -1,
			"high": 0
		}
	],
	"rooms": [
		{
			"rect": [
				1,
				10,
				6,
				10
			],
			"building": 18,
			"level": -1,
			"use": "입고 방"
		},
		{
			"rect": [
				8,
				10,
				6,
				10
			],
			"building": 18,
			"level": -1,
			"use": "비축 방"
		},
		{
			"rect": [
				15,
				10,
				5,
				10
			],
			"building": 18,
			"level": -1,
			"use": "작업 방"
		},
		{
			"rect": [
				21,
				10,
				5,
				10
			],
			"building": 18,
			"level": -1,
			"use": "접수 방"
		},
		{
			"rect": [
				27,
				10,
				5,
				10
			],
			"building": 18,
			"level": -1,
			"use": "보관 방"
		},
		{
			"rect": [
				33,
				10,
				5,
				10
			],
			"building": 18,
			"level": -1,
			"use": "안쪽 광"
		},
		{
			"rect": [
				1,
				10,
				6,
				10
			],
			"building": 18,
			"level": 0,
			"use": "입고 방"
		},
		{
			"rect": [
				8,
				10,
				6,
				10
			],
			"building": 18,
			"level": 0,
			"use": "비축 방"
		},
		{
			"rect": [
				15,
				10,
				5,
				10
			],
			"building": 18,
			"level": 0,
			"use": "작업 방"
		},
		{
			"rect": [
				21,
				10,
				5,
				10
			],
			"building": 18,
			"level": 0,
			"use": "접수 방"
		},
		{
			"rect": [
				27,
				10,
				5,
				10
			],
			"building": 18,
			"level": 0,
			"use": "보관 방"
		},
		{
			"rect": [
				33,
				10,
				5,
				10
			],
			"building": 18,
			"level": 0,
			"use": "안쪽 광"
		},
		{
			"rect": [
				1,
				10,
				6,
				10
			],
			"building": 18,
			"level": 1,
			"use": "입고 방"
		},
		{
			"rect": [
				8,
				10,
				6,
				10
			],
			"building": 18,
			"level": 1,
			"use": "비축 방"
		},
		{
			"rect": [
				15,
				10,
				5,
				10
			],
			"building": 18,
			"level": 1,
			"use": "작업 방"
		},
		{
			"rect": [
				21,
				10,
				5,
				10
			],
			"building": 18,
			"level": 1,
			"use": "접수 방"
		},
		{
			"rect": [
				27,
				10,
				5,
				10
			],
			"building": 18,
			"level": 1,
			"use": "보관 방"
		},
		{
			"rect": [
				33,
				10,
				5,
				10
			],
			"building": 18,
			"level": 1,
			"use": "안쪽 광"
		},
		{
			"rect": [
				1,
				10,
				6,
				10
			],
			"building": 18,
			"level": 2,
			"use": "입고 방"
		},
		{
			"rect": [
				8,
				10,
				6,
				10
			],
			"building": 18,
			"level": 2,
			"use": "비축 방"
		},
		{
			"rect": [
				15,
				10,
				5,
				10
			],
			"building": 18,
			"level": 2,
			"use": "작업 방"
		},
		{
			"rect": [
				21,
				10,
				5,
				10
			],
			"building": 18,
			"level": 2,
			"use": "접수 방"
		},
		{
			"rect": [
				27,
				10,
				5,
				10
			],
			"building": 18,
			"level": 2,
			"use": "보관 방"
		},
		{
			"rect": [
				33,
				10,
				5,
				10
			],
			"building": 18,
			"level": 2,
			"use": "안쪽 광"
		},
		{
			"rect": [
				46,
				14,
				12,
				4
			],
			"building": 19,
			"level": 0,
			"use": "뒤 창고"
		},
		{
			"rect": [
				46,
				19,
				12,
				4
			],
			"building": 19,
			"level": 0,
			"use": "매장"
		},
		{
			"rect": [
				46,
				14,
				12,
				4
			],
			"building": 19,
			"level": 1,
			"use": "뒤 창고"
		},
		{
			"rect": [
				46,
				19,
				12,
				4
			],
			"building": 19,
			"level": 1,
			"use": "매장"
		},
		{
			"rect": [
				60,
				13,
				8,
				7
			],
			"building": 20,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				69,
				13,
				7,
				7
			],
			"building": 20,
			"level": 0,
			"use": "보관 칸"
		},
		{
			"rect": [
				78,
				12,
				5,
				8
			],
			"building": 21,
			"level": 0,
			"use": "살림방"
		},
		{
			"rect": [
				84,
				12,
				4,
				8
			],
			"building": 21,
			"level": 0,
			"use": "부엌"
		},
		{
			"rect": [
				78,
				12,
				5,
				8
			],
			"building": 21,
			"level": 1,
			"use": "살림방"
		},
		{
			"rect": [
				84,
				12,
				4,
				8
			],
			"building": 21,
			"level": 1,
			"use": "부엌"
		},
		{
			"rect": [
				95,
				11,
				7,
				9
			],
			"building": 22,
			"level": 0,
			"use": "살림방"
		},
		{
			"rect": [
				103,
				11,
				6,
				9
			],
			"building": 22,
			"level": 0,
			"use": "부엌"
		},
		{
			"rect": [
				95,
				11,
				7,
				9
			],
			"building": 22,
			"level": 1,
			"use": "살림방"
		},
		{
			"rect": [
				103,
				11,
				6,
				9
			],
			"building": 22,
			"level": 1,
			"use": "부엌"
		},
		{
			"rect": [
				111,
				16,
				4,
				4
			],
			"building": 23,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				116,
				16,
				3,
				4
			],
			"building": 23,
			"level": 0,
			"use": "보관 칸"
		},
		{
			"rect": [
				133,
				16,
				6,
				4
			],
			"building": 24,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				140,
				16,
				5,
				4
			],
			"building": 24,
			"level": 0,
			"use": "보관 칸"
		},
		{
			"rect": [
				154,
				1,
				6,
				3
			],
			"building": 25,
			"level": -1,
			"use": "작업 칸"
		},
		{
			"rect": [
				161,
				1,
				5,
				3
			],
			"building": 25,
			"level": -1,
			"use": "보관 칸"
		},
		{
			"rect": [
				154,
				1,
				6,
				3
			],
			"building": 25,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				161,
				1,
				5,
				3
			],
			"building": 25,
			"level": 0,
			"use": "보관 칸"
		}
	],
	"props": [
		{
			"kind": "parts_rack",
			"rect": [
				1,
				10,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 입고 방의 부품 서랍 선반",
			"level": -1
		},
		{
			"kind": "hardware_rack",
			"rect": [
				1,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 입고 방의 철물 걸이대",
			"level": -1
		},
		{
			"kind": "desk",
			"rect": [
				5,
				10,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 입고 방의 책상",
			"level": -1
		},
		{
			"kind": "parts_rack",
			"rect": [
				8,
				10,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 비축 방의 부품 서랍 선반",
			"level": -1
		},
		{
			"kind": "hardware_rack",
			"rect": [
				8,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 비축 방의 철물 걸이대",
			"level": -1
		},
		{
			"kind": "desk",
			"rect": [
				12,
				10,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 비축 방의 책상",
			"level": -1
		},
		{
			"kind": "parts_rack",
			"rect": [
				15,
				10,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 작업 방의 부품 서랍 선반",
			"level": -1
		},
		{
			"kind": "hardware_rack",
			"rect": [
				15,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 작업 방의 철물 걸이대",
			"level": -1
		},
		{
			"kind": "desk",
			"rect": [
				18,
				10,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 작업 방의 책상",
			"level": -1
		},
		{
			"kind": "parts_rack",
			"rect": [
				21,
				10,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 접수 방의 부품 서랍 선반",
			"level": -1
		},
		{
			"kind": "hardware_rack",
			"rect": [
				21,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 접수 방의 철물 걸이대",
			"level": -1
		},
		{
			"kind": "desk",
			"rect": [
				24,
				10,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 접수 방의 책상",
			"level": -1
		},
		{
			"kind": "parts_rack",
			"rect": [
				27,
				10,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 보관 방의 부품 서랍 선반",
			"level": -1
		},
		{
			"kind": "hardware_rack",
			"rect": [
				27,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 보관 방의 철물 걸이대",
			"level": -1
		},
		{
			"kind": "desk",
			"rect": [
				30,
				10,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 보관 방의 책상",
			"level": -1
		},
		{
			"kind": "parts_rack",
			"rect": [
				33,
				10,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 안쪽 광의 부품 서랍 선반",
			"level": -1
		},
		{
			"kind": "hardware_rack",
			"rect": [
				33,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 안쪽 광의 철물 걸이대",
			"level": -1
		},
		{
			"kind": "desk",
			"rect": [
				36,
				10,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 안쪽 광의 책상",
			"level": -1
		},
		{
			"kind": "parts_rack",
			"rect": [
				1,
				10,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "철물 도매동 입고 방의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "hardware_rack",
			"rect": [
				1,
				19,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "철물 도매동 입고 방의 철물 걸이대",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				5,
				10,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "철물 도매동 입고 방의 책상",
			"level": 0
		},
		{
			"kind": "parts_rack",
			"rect": [
				8,
				10,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "철물 도매동 비축 방의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "hardware_rack",
			"rect": [
				8,
				19,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "철물 도매동 비축 방의 철물 걸이대",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				12,
				10,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "철물 도매동 비축 방의 책상",
			"level": 0
		},
		{
			"kind": "parts_rack",
			"rect": [
				15,
				10,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "철물 도매동 작업 방의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "hardware_rack",
			"rect": [
				15,
				11,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "철물 도매동 작업 방의 철물 걸이대",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				15,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "철물 도매동 작업 방의 책상",
			"level": 0
		},
		{
			"kind": "parts_rack",
			"rect": [
				21,
				10,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "철물 도매동 접수 방의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "hardware_rack",
			"rect": [
				21,
				11,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "철물 도매동 접수 방의 철물 걸이대",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				21,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "철물 도매동 접수 방의 책상",
			"level": 0
		},
		{
			"kind": "parts_rack",
			"rect": [
				27,
				10,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "철물 도매동 보관 방의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "hardware_rack",
			"rect": [
				27,
				11,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "철물 도매동 보관 방의 철물 걸이대",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				27,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "철물 도매동 보관 방의 책상",
			"level": 0
		},
		{
			"kind": "parts_rack",
			"rect": [
				33,
				10,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "철물 도매동 안쪽 광의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "hardware_rack",
			"rect": [
				33,
				11,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "철물 도매동 안쪽 광의 철물 걸이대",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				33,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "철물 도매동 안쪽 광의 책상",
			"level": 0
		},
		{
			"kind": "parts_rack",
			"rect": [
				1,
				10,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 입고 방의 부품 서랍 선반",
			"level": 1
		},
		{
			"kind": "hardware_rack",
			"rect": [
				1,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 입고 방의 철물 걸이대",
			"level": 1
		},
		{
			"kind": "desk",
			"rect": [
				5,
				10,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 입고 방의 책상",
			"level": 1
		},
		{
			"kind": "parts_rack",
			"rect": [
				8,
				10,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 비축 방의 부품 서랍 선반",
			"level": 1
		},
		{
			"kind": "hardware_rack",
			"rect": [
				8,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 비축 방의 철물 걸이대",
			"level": 1
		},
		{
			"kind": "desk",
			"rect": [
				12,
				10,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 비축 방의 책상",
			"level": 1
		},
		{
			"kind": "parts_rack",
			"rect": [
				15,
				10,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 작업 방의 부품 서랍 선반",
			"level": 1
		},
		{
			"kind": "hardware_rack",
			"rect": [
				15,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 작업 방의 철물 걸이대",
			"level": 1
		},
		{
			"kind": "desk",
			"rect": [
				18,
				10,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 작업 방의 책상",
			"level": 1
		},
		{
			"kind": "parts_rack",
			"rect": [
				21,
				10,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 접수 방의 부품 서랍 선반",
			"level": 1
		},
		{
			"kind": "hardware_rack",
			"rect": [
				21,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 접수 방의 철물 걸이대",
			"level": 1
		},
		{
			"kind": "desk",
			"rect": [
				24,
				10,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 접수 방의 책상",
			"level": 1
		},
		{
			"kind": "parts_rack",
			"rect": [
				27,
				10,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 보관 방의 부품 서랍 선반",
			"level": 1
		},
		{
			"kind": "hardware_rack",
			"rect": [
				27,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 보관 방의 철물 걸이대",
			"level": 1
		},
		{
			"kind": "desk",
			"rect": [
				30,
				10,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 보관 방의 책상",
			"level": 1
		},
		{
			"kind": "parts_rack",
			"rect": [
				33,
				10,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 안쪽 광의 부품 서랍 선반",
			"level": 1
		},
		{
			"kind": "hardware_rack",
			"rect": [
				33,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 안쪽 광의 철물 걸이대",
			"level": 1
		},
		{
			"kind": "desk",
			"rect": [
				36,
				10,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 안쪽 광의 책상",
			"level": 1
		},
		{
			"kind": "parts_rack",
			"rect": [
				1,
				10,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 입고 방의 부품 서랍 선반",
			"level": 2
		},
		{
			"kind": "hardware_rack",
			"rect": [
				1,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 입고 방의 철물 걸이대",
			"level": 2
		},
		{
			"kind": "desk",
			"rect": [
				5,
				10,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 입고 방의 책상",
			"level": 2
		},
		{
			"kind": "parts_rack",
			"rect": [
				8,
				10,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 비축 방의 부품 서랍 선반",
			"level": 2
		},
		{
			"kind": "hardware_rack",
			"rect": [
				8,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 비축 방의 철물 걸이대",
			"level": 2
		},
		{
			"kind": "desk",
			"rect": [
				12,
				10,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 비축 방의 책상",
			"level": 2
		},
		{
			"kind": "parts_rack",
			"rect": [
				15,
				10,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 작업 방의 부품 서랍 선반",
			"level": 2
		},
		{
			"kind": "hardware_rack",
			"rect": [
				15,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 작업 방의 철물 걸이대",
			"level": 2
		},
		{
			"kind": "desk",
			"rect": [
				18,
				10,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 작업 방의 책상",
			"level": 2
		},
		{
			"kind": "parts_rack",
			"rect": [
				21,
				10,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 접수 방의 부품 서랍 선반",
			"level": 2
		},
		{
			"kind": "hardware_rack",
			"rect": [
				21,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 접수 방의 철물 걸이대",
			"level": 2
		},
		{
			"kind": "desk",
			"rect": [
				24,
				10,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 접수 방의 책상",
			"level": 2
		},
		{
			"kind": "parts_rack",
			"rect": [
				27,
				10,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 보관 방의 부품 서랍 선반",
			"level": 2
		},
		{
			"kind": "hardware_rack",
			"rect": [
				27,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 보관 방의 철물 걸이대",
			"level": 2
		},
		{
			"kind": "desk",
			"rect": [
				30,
				10,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 보관 방의 책상",
			"level": 2
		},
		{
			"kind": "parts_rack",
			"rect": [
				33,
				10,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 안쪽 광의 부품 서랍 선반",
			"level": 2
		},
		{
			"kind": "hardware_rack",
			"rect": [
				33,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 안쪽 광의 철물 걸이대",
			"level": 2
		},
		{
			"kind": "desk",
			"rect": [
				36,
				10,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "철물 도매동 안쪽 광의 책상",
			"level": 2
		},
		{
			"kind": "parts_rack",
			"rect": [
				46,
				14,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "부품 가게 뒤 창고의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "hardware_rack",
			"rect": [
				46,
				17,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "부품 가게 뒤 창고의 철물 걸이대",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				57,
				14,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "부품 가게 뒤 창고의 통",
			"level": 0
		},
		{
			"kind": "display_shelf",
			"rect": [
				46,
				19,
				4,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "부품 가게 매장의 진열대",
			"level": 0
		},
		{
			"kind": "shop_counter",
			"rect": [
				46,
				22,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "부품 가게 매장의 계산대",
			"level": 0
		},
		{
			"kind": "parts_rack",
			"rect": [
				46,
				20,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "부품 가게 매장의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "parts_rack",
			"rect": [
				46,
				14,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "부품 가게 뒤 창고의 부품 서랍 선반",
			"level": 1
		},
		{
			"kind": "hardware_rack",
			"rect": [
				46,
				17,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "부품 가게 뒤 창고의 철물 걸이대",
			"level": 1
		},
		{
			"kind": "barrel",
			"rect": [
				57,
				14,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "부품 가게 뒤 창고의 통",
			"level": 1
		},
		{
			"kind": "display_shelf",
			"rect": [
				46,
				19,
				4,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "부품 가게 매장의 진열대",
			"level": 1
		},
		{
			"kind": "shop_counter",
			"rect": [
				46,
				22,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "부품 가게 매장의 계산대",
			"level": 1
		},
		{
			"kind": "parts_rack",
			"rect": [
				46,
				20,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "부품 가게 매장의 부품 서랍 선반",
			"level": 1
		},
		{
			"kind": "parts_rack",
			"rect": [
				60,
				13,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "정비 차고 작업 칸의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				60,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "정비 차고 작업 칸의 책상",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				67,
				13,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "정비 차고 작업 칸의 통",
			"level": 0
		},
		{
			"kind": "parts_rack",
			"rect": [
				69,
				13,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "정비 차고 보관 칸의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				69,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "정비 차고 보관 칸의 책상",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				75,
				13,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "정비 차고 보관 칸의 통",
			"level": 0
		},
		{
			"kind": "bed",
			"rect": [
				78,
				12,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "공구장이 살림집 살림방의 침대",
			"level": 0
		},
		{
			"kind": "wardrobe",
			"rect": [
				78,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "공구장이 살림집 살림방의 장롱",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				81,
				12,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "공구장이 살림집 살림방의 책상",
			"level": 0
		},
		{
			"kind": "dining_set",
			"rect": [
				84,
				12,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "공구장이 살림집 부엌의 식탁",
			"level": 0
		},
		{
			"kind": "fridge_open",
			"rect": [
				87,
				12,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "공구장이 살림집 부엌의 냉장고",
			"level": 0
		},
		{
			"kind": "cold_stove",
			"rect": [
				87,
				19,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "공구장이 살림집 부엌의 꺼진 난로",
			"level": 0
		},
		{
			"kind": "bed",
			"rect": [
				78,
				12,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "공구장이 살림집 살림방의 침대",
			"level": 1
		},
		{
			"kind": "wardrobe",
			"rect": [
				78,
				19,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "공구장이 살림집 살림방의 장롱",
			"level": 1
		},
		{
			"kind": "desk",
			"rect": [
				81,
				12,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "공구장이 살림집 살림방의 책상",
			"level": 1
		},
		{
			"kind": "dining_set",
			"rect": [
				84,
				12,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "공구장이 살림집 부엌의 식탁",
			"level": 1
		},
		{
			"kind": "fridge_open",
			"rect": [
				87,
				12,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "공구장이 살림집 부엌의 냉장고",
			"level": 1
		},
		{
			"kind": "cold_stove",
			"rect": [
				87,
				19,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "공구장이 살림집 부엌의 꺼진 난로",
			"level": 1
		},
		{
			"kind": "bed",
			"rect": [
				95,
				11,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "살림집 살림방의 침대",
			"level": 0
		},
		{
			"kind": "wardrobe",
			"rect": [
				95,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "살림집 살림방의 장롱",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				100,
				11,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "살림집 살림방의 책상",
			"level": 0
		},
		{
			"kind": "dining_set",
			"rect": [
				103,
				11,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "살림집 부엌의 식탁",
			"level": 0
		},
		{
			"kind": "fridge_open",
			"rect": [
				108,
				11,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "살림집 부엌의 냉장고",
			"level": 0
		},
		{
			"kind": "cold_stove",
			"rect": [
				103,
				19,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "살림집 부엌의 꺼진 난로",
			"level": 0
		},
		{
			"kind": "bed",
			"rect": [
				95,
				11,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "살림집 살림방의 침대",
			"level": 1
		},
		{
			"kind": "wardrobe",
			"rect": [
				95,
				19,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "살림집 살림방의 장롱",
			"level": 1
		},
		{
			"kind": "desk",
			"rect": [
				100,
				11,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "살림집 살림방의 책상",
			"level": 1
		},
		{
			"kind": "dining_set",
			"rect": [
				103,
				11,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "살림집 부엌의 식탁",
			"level": 1
		},
		{
			"kind": "fridge_open",
			"rect": [
				108,
				11,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "살림집 부엌의 냉장고",
			"level": 1
		},
		{
			"kind": "cold_stove",
			"rect": [
				103,
				19,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "살림집 부엌의 꺼진 난로",
			"level": 1
		},
		{
			"kind": "garden_rack",
			"rect": [
				111,
				16,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "텃밭 헛간 작업 칸의 원예 선반",
			"level": 0
		},
		{
			"kind": "sack_pile",
			"rect": [
				111,
				17,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "텃밭 헛간 작업 칸의 자루 더미",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				114,
				16,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "텃밭 헛간 작업 칸의 통",
			"level": 0
		},
		{
			"kind": "garden_rack",
			"rect": [
				116,
				16,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "텃밭 헛간 보관 칸의 원예 선반",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				118,
				19,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "텃밭 헛간 보관 칸의 통",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				116,
				19,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "텃밭 헛간 보관 칸의 통",
			"level": 0
		},
		{
			"kind": "parts_rack",
			"rect": [
				133,
				16,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "공동 차고 작업 칸의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				138,
				16,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "공동 차고 작업 칸의 통",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				133,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "공동 차고 작업 칸의 책상",
			"level": 0
		},
		{
			"kind": "parts_rack",
			"rect": [
				140,
				16,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "공동 차고 보관 칸의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				144,
				16,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "공동 차고 보관 칸의 통",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				140,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "공동 차고 보관 칸의 책상",
			"level": 0
		},
		{
			"kind": "parts_rack",
			"rect": [
				154,
				1,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "부품 창고 작업 칸의 부품 서랍 선반",
			"level": -1
		},
		{
			"kind": "hardware_rack",
			"rect": [
				154,
				3,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "부품 창고 작업 칸의 철물 걸이대",
			"level": -1
		},
		{
			"kind": "crate_stack",
			"rect": [
				158,
				1,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "부품 창고 작업 칸의 나무 상자 더미",
			"level": -1
		},
		{
			"kind": "parts_rack",
			"rect": [
				161,
				1,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "부품 창고 보관 칸의 부품 서랍 선반",
			"level": -1
		},
		{
			"kind": "hardware_rack",
			"rect": [
				161,
				2,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "부품 창고 보관 칸의 철물 걸이대",
			"level": -1
		},
		{
			"kind": "crate_stack",
			"rect": [
				164,
				1,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "부품 창고 보관 칸의 나무 상자 더미",
			"level": -1
		},
		{
			"kind": "parts_rack",
			"rect": [
				154,
				1,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "부품 창고 작업 칸의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "hardware_rack",
			"rect": [
				154,
				3,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "부품 창고 작업 칸의 철물 걸이대",
			"level": 0
		},
		{
			"kind": "crate_stack",
			"rect": [
				158,
				1,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "부품 창고 작업 칸의 나무 상자 더미",
			"level": 0
		},
		{
			"kind": "crate_stack",
			"rect": [
				161,
				1,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "부품 창고 보관 칸의 나무 상자 더미",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				165,
				1,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "부품 창고 보관 칸의 통",
			"level": 0
		},
		{
			"kind": "cold_stove",
			"rect": [
				165,
				3,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "부품 창고 보관 칸의 꺼진 난로",
			"level": 0
		},
		{
			"kind": "crate_stack",
			"rect": [
				24,
				40,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "나무 상자 더미",
			"level": 0
		},
		{
			"kind": "car",
			"rect": [
				58,
				36,
				4,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "버려진 차",
			"level": 0
		},
		{
			"kind": "bench",
			"rect": [
				80,
				40,
				1,
				3
			],
			"solid": "low",
			"facing": 0,
			"note": "긴 의자",
			"level": 0
		},
		{
			"kind": "handcart",
			"rect": [
				101,
				29,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "손수레",
			"level": 0
		},
		{
			"kind": "car",
			"rect": [
				125,
				31,
				4,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "버려진 차",
			"level": 0
		},
		{
			"kind": "pallet_stack",
			"rect": [
				125,
				35,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "팰릿 더미",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				130,
				33,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "통",
			"level": 0
		},
		{
			"kind": "handcart",
			"rect": [
				126,
				38,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "손수레",
			"level": 0
		},
		{
			"kind": "street_tree",
			"rect": [
				56,
				0,
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
				58,
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
				61,
				0,
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
				64,
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
				67,
				0,
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
				134,
				30,
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
				137,
				32,
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
				140,
				30,
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
				139,
				36,
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
				151,
				26,
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
				155,
				28,
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
				153,
				32,
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
				158,
				30,
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
				121,
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
				124,
				19,
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
				121,
				22,
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
			"name": "철물 도매동 입고 방 상자",
			"cell": [
				6,
				19
			],
			"level": -1,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_1",
			"name": "철물 도매동 비축 방 상자",
			"cell": [
				13,
				19
			],
			"level": -1,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_2",
			"name": "철물 도매동 작업 방 상자",
			"cell": [
				19,
				19
			],
			"level": -1,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_3",
			"name": "철물 도매동 접수 방 상자",
			"cell": [
				25,
				19
			],
			"level": -1,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_4",
			"name": "철물 도매동 보관 방 상자",
			"cell": [
				31,
				19
			],
			"level": -1,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_5",
			"name": "철물 도매동 안쪽 광 상자",
			"cell": [
				37,
				19
			],
			"level": -1,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_6",
			"name": "철물 도매동 입고 방 상자",
			"cell": [
				6,
				19
			],
			"level": 0,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_7",
			"name": "철물 도매동 비축 방 상자",
			"cell": [
				13,
				19
			],
			"level": 0,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_8",
			"name": "철물 도매동 작업 방 상자",
			"cell": [
				19,
				10
			],
			"level": 0,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_9",
			"name": "철물 도매동 접수 방 상자",
			"cell": [
				25,
				10
			],
			"level": 0,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_10",
			"name": "철물 도매동 보관 방 상자",
			"cell": [
				31,
				10
			],
			"level": 0,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_11",
			"name": "철물 도매동 안쪽 광 상자",
			"cell": [
				37,
				10
			],
			"level": 0,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_12",
			"name": "철물 도매동 입고 방 상자",
			"cell": [
				6,
				19
			],
			"level": 1,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_13",
			"name": "철물 도매동 비축 방 상자",
			"cell": [
				13,
				19
			],
			"level": 1,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_14",
			"name": "철물 도매동 작업 방 상자",
			"cell": [
				19,
				19
			],
			"level": 1,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_15",
			"name": "철물 도매동 접수 방 상자",
			"cell": [
				25,
				19
			],
			"level": 1,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_16",
			"name": "철물 도매동 보관 방 상자",
			"cell": [
				31,
				19
			],
			"level": 1,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_17",
			"name": "철물 도매동 안쪽 광 상자",
			"cell": [
				37,
				19
			],
			"level": 1,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_18",
			"name": "철물 도매동 입고 방 상자",
			"cell": [
				6,
				19
			],
			"level": 2,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_19",
			"name": "철물 도매동 비축 방 상자",
			"cell": [
				13,
				19
			],
			"level": 2,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_20",
			"name": "철물 도매동 작업 방 상자",
			"cell": [
				19,
				19
			],
			"level": 2,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_21",
			"name": "철물 도매동 접수 방 상자",
			"cell": [
				25,
				19
			],
			"level": 2,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_22",
			"name": "철물 도매동 보관 방 상자",
			"cell": [
				31,
				19
			],
			"level": 2,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_23",
			"name": "철물 도매동 안쪽 광 상자",
			"cell": [
				37,
				19
			],
			"level": 2,
			"building": 18,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_24",
			"name": "부품 가게 뒤 창고 상자",
			"cell": [
				57,
				17
			],
			"level": 0,
			"building": 19,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_25",
			"name": "부품 가게 매장 상자",
			"cell": [
				57,
				19
			],
			"level": 0,
			"building": 19,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_26",
			"name": "부품 가게 뒤 창고 상자",
			"cell": [
				57,
				17
			],
			"level": 1,
			"building": 19,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_27",
			"name": "부품 가게 매장 상자",
			"cell": [
				57,
				19
			],
			"level": 1,
			"building": 19,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_28",
			"name": "정비 차고 작업 칸 상자",
			"cell": [
				67,
				19
			],
			"level": 0,
			"building": 20,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_29",
			"name": "정비 차고 보관 칸 상자",
			"cell": [
				75,
				19
			],
			"level": 0,
			"building": 20,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_30",
			"name": "공구장이 살림집 살림방 상자",
			"cell": [
				82,
				19
			],
			"level": 0,
			"building": 21,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_31",
			"name": "공구장이 살림집 부엌 상자",
			"cell": [
				84,
				19
			],
			"level": 0,
			"building": 21,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_32",
			"name": "공구장이 살림집 살림방 상자",
			"cell": [
				82,
				19
			],
			"level": 1,
			"building": 21,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_33",
			"name": "공구장이 살림집 부엌 상자",
			"cell": [
				84,
				19
			],
			"level": 1,
			"building": 21,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_34",
			"name": "살림집 살림방 상자",
			"cell": [
				101,
				19
			],
			"level": 0,
			"building": 22,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_35",
			"name": "살림집 부엌 상자",
			"cell": [
				108,
				19
			],
			"level": 0,
			"building": 22,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_36",
			"name": "살림집 살림방 상자",
			"cell": [
				101,
				19
			],
			"level": 1,
			"building": 22,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_37",
			"name": "살림집 부엌 상자",
			"cell": [
				108,
				19
			],
			"level": 1,
			"building": 22,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_38",
			"name": "텃밭 헛간 작업 칸 상자",
			"cell": [
				114,
				19
			],
			"level": 0,
			"building": 23,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_39",
			"name": "텃밭 헛간 보관 칸 상자",
			"cell": [
				118,
				17
			],
			"level": 0,
			"building": 23,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_40",
			"name": "공동 차고 작업 칸 상자",
			"cell": [
				138,
				19
			],
			"level": 0,
			"building": 24,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_41",
			"name": "공동 차고 보관 칸 상자",
			"cell": [
				144,
				19
			],
			"level": 0,
			"building": 24,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_42",
			"name": "부품 창고 작업 칸 상자",
			"cell": [
				159,
				3
			],
			"level": -1,
			"building": 25,
			"search": 7,
			"items": [
				"scrap",
				"plank",
				"scrap",
				"plank"
			],
			"locked": true,
			"searched": false
		},
		{
			"id": "north_cache_43",
			"name": "부품 창고 보관 칸 상자",
			"cell": [
				165,
				3
			],
			"level": -1,
			"building": 25,
			"search": 7,
			"items": [
				"scrap",
				"plank",
				"scrap",
				"plank"
			],
			"locked": true,
			"searched": false
		},
		{
			"id": "north_cache_44",
			"name": "부품 창고 작업 칸 상자",
			"cell": [
				159,
				3
			],
			"level": 0,
			"building": 25,
			"search": 4,
			"items": [
				"scrap"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_45",
			"name": "부품 창고 보관 칸 상자",
			"cell": [
				161,
				3
			],
			"level": 0,
			"building": 25,
			"search": 4,
			"items": [
				"scrap"
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
				"scrap"
			],
			"locked": false,
			"searched": false
		}
	],
	"entries": [
		{
			"id": "뒷거리 서쪽 어귀",
			"name": "뒷거리 서쪽 어귀",
			"cells": [
				[
					0,
					3
				],
				[
					0,
					4
				],
				[
					0,
					5
				],
				[
					0,
					6
				]
			],
			"gap": 0.6
		},
		{
			"id": "뒷거리 북쪽 곁길",
			"name": "뒷거리 북쪽 곁길",
			"cells": [
				[
					70,
					0
				],
				[
					71,
					0
				],
				[
					72,
					0
				],
				[
					73,
					0
				]
			],
			"gap": 2.5
		},
		{
			"id": "동쪽 샛길",
			"name": "동쪽 샛길",
			"cells": [
				[
					169,
					9
				],
				[
					169,
					10
				],
				[
					169,
					11
				],
				[
					169,
					12
				]
			],
			"gap": 2.5
		}
	],
	"holes": [],
	"barricades": [
		[
			40,
			22
		],
		[
			43,
			22
		],
		[
			90,
			22
		],
		[
			92,
			22
		]
	],
	"slots": [
		"J"
	],
	"deep": 7,
	"forecourts": [
		[
			17,
			24,
			5,
			4
		],
		[
			50,
			24,
			5,
			4
		],
		[
			66,
			24,
			5,
			4
		],
		[
			81,
			24,
			5,
			4
		],
		[
			100,
			24,
			5,
			4
		],
		[
			113,
			24,
			5,
			4
		],
		[
			137,
			24,
			5,
			4
		],
		[
			158,
			8,
			5,
			4
		]
	],
	"crossings": [
		32,
		64
	],
	"stock": [
		"parts_rack",
		"hardware_rack",
		"desk",
		"crate_stack"
	],
	"loot": [
		"scrap",
		"plank"
	],
	"assumptions": [
		"북서 세 칸 틈은 도매동을 서쪽 경계까지 늘려 닫았다. 그 자리에 제시된 나무는 동쪽 뒤뜰 무리로 옮겼다.",
		"띠를 닫는 건물 남쪽 벽을 새 좌표 스물셋째 줄에 맞췄다.",
		"위쪽 문 앞 세 칸을 비우려고 띠 안 긴 의자를 두 칸 서쪽으로 옮겼다.",
		"앞쪽 복도 출입문과 북쪽 입고 문을 따로 두었다."
	]
}

const SOUTH_TREE_MOVES: Array = [[[131,41],[134,39]],[[136,42],[132,36]],[[78,42],[82,50]],[[79,48],[87,51]],[[108,48],[108,50]],[[71,58],[73,54]],[[84,49],[77,51]]]
const SOUTH_WORK: Dictionary = {"name":"목공방 작업 구역","cell":[82,44],"rect":[74,42,20,10]}

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
const ENTRY_NAMES: Dictionary = {"west_alley": "서쪽 골목", "west_bank": "서쪽 둑", "east_street": "동쪽 거리", "east_back": "동쪽 뒷길", "south_bridge": "남쪽 다리", "manhole_01": "첫째 맨홀", "manhole_02": "둘째 맨홀", "manhole_03": "셋째 맨홀", "manhole_04": "넷째 맨홀", "뒷거리 서쪽 어귀": "뒷거리 서쪽 어귀", "뒷거리 북쪽 곁길": "뒷거리 북쪽 곁길", "동쪽 샛길": "동쪽 샛길"}
const ENTRY_WEIGHTS: Dictionary = {"west_alley": 0.5, "west_bank": 1.0, "east_street": 1.0, "east_back": 0.5, "south_bridge": 1.0, "manhole_01": 0.3, "manhole_02": 0.3, "manhole_03": 0.3, "manhole_04": 0.3, "뒷거리 서쪽 어귀": 1.0, "뒷거리 북쪽 곁길": 0.5, "동쪽 샛길": 0.5}
const FIRST_ENTRY: String = "west_bank"


static func build() -> Dictionary:
	var data: Dictionary = _build_plain()
	data["entry_names"] = ENTRY_NAMES.duplicate()
	data["entry_weights"] = ENTRY_WEIGHTS.duplicate()
	data["first_entry"] = FIRST_ENTRY
	return data
