# 이 지도가 다른 판단을 만드는 것: 정문은 넓고 멀며 하역 문은 가깝지만 올리는 소리가 크다. 좋은 것은 뒤쪽 창고에 있다.
# 위쪽의 판단: 목재가 가장 많이 쌓인 곳을 얻는 대신, 하치장 평판이 트인 땅이라 가장 많이 얻는 자리가 가장 드러난다.
extends RefCounted

const FieldGrid = preload("res://game/world/field_grid.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 180
const SOUTH_HEIGHT: int = 105
const HEIGHT: int = SOUTH_HEIGHT + 45
const PLACE_ID: String = "houses_05"

# 각 좌표는 이 지도의 독립 평면이다. 위층 장식은 충돌을 만들지 않는다.
const PLAN: Dictionary = {
	"number": 5,
	"width": 180,
	"height": 105,
	"judgment": "정문은 넓고 멀며 하역 문은 가깝지만 올리는 소리가 크다. 좋은 것은 뒤쪽 창고에 있다.",
	"zones": [{"id":"A","name":"승강장 앞","rect":[0,0,180,30]},
		{"id":"B","name":"정비 골목","rect":[0,30,134,24]},
		{"id":"C","name":"하역장","rect":[134,30,46,24]},
		{"id":"D","name":"원예 뒤편","rect":[0,54,67,51]},
		{"id":"E","name":"마트 판매장","rect":[67,54,67,51]},
		{"id":"F","name":"동쪽 살림길","rect":[134,54,46,51]},
		{"id":"G","name":"주차장","rect":[0,87,180,18]},
		{"id":"H","name":"동쪽 공동주택","rect":[140,4,40,26]}],
	"grounds": [{"rect":[36,10,6,95],"floor":1},
		{"rect":[36,23,104,5],"floor":1},
		{"rect":[134,4,5,101],"floor":1},
		{"rect":[36,99,144,5],"floor":1},
		{"rect":[0,90,42,4],"floor":1},
		{"rect":[139,66,41,4],"floor":1},
		{"rect":[70,28,64,8],"floor":7},
		{"rect":[66,76,68,23],"floor":7},
		{"rect":[16,39,20,4],"floor":1},
		{"rect":[42,52,28,5],"floor":1},
		{"rect":[98,12,4,22],"floor":1},
		{"rect":[0,4,14,7],"floor":5}],
	"buildings": [{"name":"창고형 매장","rect":[70,36,64,40],"top":1,"basement":true,"role":"market","main":true,"id":0},
		{"name":"매장 사무동","rect":[144,34,28,16],"top":3,"basement":false,"role":"office","mode":"vertical","stock":["desk","office_cabinet","shelf"],"id":1},
		{"name":"공동주택 갑 동","rect":[140,10,38,18],"top":4,"basement":false,"role":"home","mode":"vertical","id":2},
		{"name":"공동주택 을 동","rect":[140,76,36,16],"top":4,"basement":false,"role":"home","mode":"vertical","id":3},
		{"name":"주유소 매점","rect":[16,28,14,10],"top":1,"basement":false,"role":"shop","stock":["display_shelf","chiller_case","shop_counter"],"id":4},
		{"name":"원예 매장","rect":[4,72,26,24],"top":1,"basement":false,"role":"shop","stock":["garden_rack","sack_pile","shop_counter"],"id":5},
		{"name":"정비 헛간","rect":[44,12,16,10],"top":1,"basement":false,"role":"shed","id":6},
		{"name":"카트 보관소","rect":[54,84,12,8],"top":1,"basement":false,"role":"shed","id":7},
		{"name":"빵집","rect":[44,28,16,10],"top":1,"basement":false,"role":"shop","stock":["bread_rack","shop_counter","barrel"],"id":8},
		{"name":"주차 관리실","rect":[24,12,8,8],"top":1,"basement":false,"role":"shed","id":9},
		{"name":"직원 휴게소","rect":[146,55,12,8],"top":1,"basement":false,"role":"shed","id":10},
		{"name":"장작 헛간","rect":[2,12,12,8],"top":1,"basement":false,"role":"shed","mode":"vertical","id":11},
		{"name":"자전거 보관소","rect":[44,44,12,8],"top":1,"basement":false,"role":"shed","id":12},
		{"name":"하역 지원 창고","rect":[44,58,20,10],"top":1,"basement":false,"role":"shed","id":13},
		{"name":"약국 상가","rect":[4,44,24,12],"top":2,"basement":false,"role":"shop","stock":["glass_cabinet","shop_counter","shelf"],"id":14},
		{"name":"연립 집","rect":[144,96,30,8],"top":2,"basement":false,"role":"home","mode":"horizontal","id":15}],
	"entries": [{"id":"east_track","cells":[[179,1],[179,2],[179,3]],"gap":0.6},
		{"id":"west_lower","cells":[[0,90],[0,91],[0,92],[0,93]],"gap":2},
		{"id":"south_main","cells":[[36,104],[37,104],[38,104],[39,104]],"gap":0.6},
		{"id":"parking_exit","cells":[[100,104],[101,104],[102,104],[103,104]],"gap":0.6},
		{"id":"east_path","cells":[[179,66],[179,67],[179,68],[179,69]],"gap":2}],
	"holes": [{"id":"manhole_01","cell":[72,88],"name":"주차장 서쪽 맨홀","level":0},
		{"id":"manhole_02","cell":[146,29],"name":"서비스 길 맨홀","level":0},
		{"id":"manhole_03","cell":[130,96],"name":"주차장 동쪽 맨홀","level":0},
		{"id":"drain_01","cell":[140,60],"name":"매장 배수구","level":0}],
	"barricades": [[37,28],[39,28],[61,29],[63,29]],
	"deepBuildings": [0,5],
	"deepLevels": [-1,0],
	"assumptions": ["사무동은 동쪽 길 건너 북동쪽에 두어 서비스 길과 공동주택이 겹치지 않게 했다.","서비스 길 동쪽 맨홀은 공동주택 남쪽의 열린 길로 옮겼다.","판매장 위에는 층을 만들지 않았다.","띠의 물리적 길목은 두 곳으로 모아 각 틈을 네 칸에서 여섯 칸으로 유지하고 트인 변은 남겼다."],
	"tx": 16,
	"band": [0,4,116,26],
	"shells": [{"building":1,"level":0,"rect":[144,34,28,16]},
		{"building":1,"level":1,"rect":[144,34,28,16]},
		{"building":1,"level":2,"rect":[144,34,28,16]},
		{"building":2,"level":0,"rect":[140,10,38,18]},
		{"building":2,"level":1,"rect":[140,10,38,18]},
		{"building":2,"level":2,"rect":[140,10,38,18]},
		{"building":3,"level":0,"rect":[140,76,36,16]},
		{"building":3,"level":1,"rect":[140,76,36,16]},
		{"building":3,"level":2,"rect":[140,76,36,16]},
		{"building":4,"level":0,"rect":[16,28,14,10]},
		{"building":5,"level":0,"rect":[4,72,26,24]},
		{"building":6,"level":0,"rect":[44,12,16,10]},
		{"building":7,"level":0,"rect":[54,84,12,8]},
		{"building":8,"level":0,"rect":[44,28,16,10]},
		{"building":9,"level":0,"rect":[24,12,8,8]},
		{"building":10,"level":0,"rect":[146,55,12,8]},
		{"building":11,"level":0,"rect":[2,12,12,8]},
		{"building":12,"level":0,"rect":[44,44,12,8]},
		{"building":13,"level":0,"rect":[44,58,20,10]},
		{"building":14,"level":0,"rect":[4,44,24,12]},
		{"building":14,"level":1,"rect":[4,44,24,12]},
		{"building":15,"level":0,"rect":[144,96,30,8]},
		{"building":15,"level":1,"rect":[144,96,30,8]},
		{"building":0,"level":0,"rect":[70,36,64,40]},
		{"building":0,"level":-1,"rect":[70,36,64,40]}],
	"walls": [{"building":1,"level":0,"rect":[156,35,1,14]},
		{"building":1,"level":0,"rect":[159,35,1,14]},
		{"building":1,"level":1,"rect":[156,35,1,14]},
		{"building":1,"level":1,"rect":[159,35,1,14]},
		{"building":1,"level":2,"rect":[156,35,1,14]},
		{"building":1,"level":2,"rect":[159,35,1,14]},
		{"building":2,"level":0,"rect":[157,11,1,16]},
		{"building":2,"level":0,"rect":[160,11,1,16]},
		{"building":2,"level":0,"rect":[149,11,1,8]},
		{"building":2,"level":0,"rect":[141,19,16,1]},
		{"building":2,"level":0,"rect":[149,20,1,7]},
		{"building":2,"level":0,"rect":[169,11,1,8]},
		{"building":2,"level":0,"rect":[161,19,16,1]},
		{"building":2,"level":0,"rect":[169,20,1,7]},
		{"building":2,"level":1,"rect":[157,11,1,16]},
		{"building":2,"level":1,"rect":[160,11,1,16]},
		{"building":2,"level":1,"rect":[149,11,1,8]},
		{"building":2,"level":1,"rect":[141,19,16,1]},
		{"building":2,"level":1,"rect":[149,20,1,7]},
		{"building":2,"level":1,"rect":[169,11,1,8]},
		{"building":2,"level":1,"rect":[161,19,16,1]},
		{"building":2,"level":1,"rect":[169,20,1,7]},
		{"building":2,"level":2,"rect":[157,11,1,16]},
		{"building":2,"level":2,"rect":[160,11,1,16]},
		{"building":2,"level":2,"rect":[149,11,1,8]},
		{"building":2,"level":2,"rect":[141,19,16,1]},
		{"building":2,"level":2,"rect":[149,20,1,7]},
		{"building":2,"level":2,"rect":[169,11,1,8]},
		{"building":2,"level":2,"rect":[161,19,16,1]},
		{"building":2,"level":2,"rect":[169,20,1,7]},
		{"building":3,"level":0,"rect":[156,77,1,14]},
		{"building":3,"level":0,"rect":[159,77,1,14]},
		{"building":3,"level":0,"rect":[148,77,1,14]},
		{"building":3,"level":0,"rect":[167,77,1,14]},
		{"building":3,"level":1,"rect":[156,77,1,14]},
		{"building":3,"level":1,"rect":[159,77,1,14]},
		{"building":3,"level":1,"rect":[148,77,1,14]},
		{"building":3,"level":1,"rect":[167,77,1,14]},
		{"building":3,"level":2,"rect":[156,77,1,14]},
		{"building":3,"level":2,"rect":[159,77,1,14]},
		{"building":3,"level":2,"rect":[148,77,1,14]},
		{"building":3,"level":2,"rect":[167,77,1,14]},
		{"building":4,"level":0,"rect":[23,29,1,8]},
		{"building":5,"level":0,"rect":[5,82,24,1]},
		{"building":5,"level":0,"rect":[5,85,24,1]},
		{"building":5,"level":0,"rect":[13,73,1,9]},
		{"building":5,"level":0,"rect":[21,73,1,9]},
		{"building":5,"level":0,"rect":[13,86,1,9]},
		{"building":5,"level":0,"rect":[21,86,1,9]},
		{"building":6,"level":0,"rect":[52,13,1,8]},
		{"building":7,"level":0,"rect":[60,85,1,6]},
		{"building":8,"level":0,"rect":[52,29,1,8]},
		{"building":10,"level":0,"rect":[152,56,1,6]},
		{"building":11,"level":0,"rect":[6,13,1,6]},
		{"building":11,"level":0,"rect":[9,13,1,6]},
		{"building":12,"level":0,"rect":[50,45,1,6]},
		{"building":13,"level":0,"rect":[51,59,1,8]},
		{"building":13,"level":0,"rect":[57,59,1,8]},
		{"building":14,"level":0,"rect":[5,48,22,1]},
		{"building":14,"level":0,"rect":[5,51,22,1]},
		{"building":14,"level":0,"rect":[16,45,1,3]},
		{"building":14,"level":0,"rect":[16,52,1,3]},
		{"building":14,"level":1,"rect":[5,48,22,1]},
		{"building":14,"level":1,"rect":[5,51,22,1]},
		{"building":14,"level":1,"rect":[16,45,1,3]},
		{"building":14,"level":1,"rect":[16,52,1,3]},
		{"building":15,"level":0,"rect":[150,97,1,6]},
		{"building":15,"level":0,"rect":[156,97,1,6]},
		{"building":15,"level":0,"rect":[162,97,1,6]},
		{"building":15,"level":0,"rect":[168,97,1,6]},
		{"building":15,"level":1,"rect":[150,97,1,6]},
		{"building":15,"level":1,"rect":[156,97,1,6]},
		{"building":15,"level":1,"rect":[162,97,1,6]},
		{"building":15,"level":1,"rect":[168,97,1,6]},
		{"building":0,"level":0,"rect":[71,49,62,1]},
		{"building":0,"level":0,"rect":[71,42,62,1]},
		{"building":0,"level":0,"rect":[89,37,1,12]},
		{"building":0,"level":0,"rect":[110,37,1,12]},
		{"building":0,"level":0,"rect":[79,54,1,11]},
		{"building":0,"level":0,"rect":[71,64,8,1]},
		{"building":0,"level":0,"rect":[124,54,1,11]},
		{"building":0,"level":0,"rect":[125,64,8,1]},
		{"building":0,"level":0,"rect":[79,66,1,9]},
		{"building":0,"level":0,"rect":[71,65,9,1]},
		{"building":0,"level":-1,"rect":[71,58,62,1]},
		{"building":0,"level":-1,"rect":[71,45,10,1]},
		{"building":0,"level":-1,"rect":[81,37,1,16]},
		{"building":0,"level":-1,"rect":[82,45,10,1]},
		{"building":0,"level":-1,"rect":[92,37,1,16]},
		{"building":0,"level":-1,"rect":[93,45,10,1]},
		{"building":0,"level":-1,"rect":[103,37,1,16]},
		{"building":0,"level":-1,"rect":[104,45,9,1]},
		{"building":0,"level":-1,"rect":[113,37,1,16]},
		{"building":0,"level":-1,"rect":[114,45,9,1]},
		{"building":0,"level":-1,"rect":[123,37,1,16]},
		{"building":0,"level":-1,"rect":[124,45,9,1]},
		{"building":0,"level":-1,"rect":[71,67,10,1]},
		{"building":0,"level":-1,"rect":[81,59,1,16]},
		{"building":0,"level":-1,"rect":[82,67,10,1]},
		{"building":0,"level":-1,"rect":[92,59,1,16]},
		{"building":0,"level":-1,"rect":[93,67,10,1]},
		{"building":0,"level":-1,"rect":[103,59,1,16]},
		{"building":0,"level":-1,"rect":[104,67,9,1]},
		{"building":0,"level":-1,"rect":[113,59,1,16]},
		{"building":0,"level":-1,"rect":[114,67,9,1]},
		{"building":0,"level":-1,"rect":[123,59,1,16]},
		{"building":0,"level":-1,"rect":[124,67,9,1]}],
	"doors": [{"cell":[156,42],"building":1,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[159,42],"building":1,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[157,34],"building":1,"level":0,"state":"open","normal":[0,-1],"external":true},
		{"cell":[157,49],"building":1,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[156,42],"building":1,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[159,42],"building":1,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[156,42],"building":1,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[159,42],"building":1,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[149,15],"building":2,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[157,15],"building":2,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[149,23],"building":2,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[157,23],"building":2,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[169,15],"building":2,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[160,15],"building":2,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[169,23],"building":2,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[160,23],"building":2,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[158,10],"building":2,"level":0,"state":"open","normal":[0,-1],"external":true},
		{"cell":[158,27],"building":2,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[149,15],"building":2,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[157,15],"building":2,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[149,23],"building":2,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[157,23],"building":2,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[169,15],"building":2,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[160,15],"building":2,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[169,23],"building":2,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[160,23],"building":2,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[149,15],"building":2,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[157,15],"building":2,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[149,23],"building":2,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[157,23],"building":2,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[169,15],"building":2,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[160,15],"building":2,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[169,23],"building":2,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[160,23],"building":2,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[148,84],"building":3,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[156,84],"building":3,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[167,84],"building":3,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[159,84],"building":3,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[157,76],"building":3,"level":0,"state":"open","normal":[0,-1],"external":true},
		{"cell":[157,91],"building":3,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[148,84],"building":3,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[156,84],"building":3,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[167,84],"building":3,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[159,84],"building":3,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[148,84],"building":3,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[156,84],"building":3,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[167,84],"building":3,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[159,84],"building":3,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[23,33],"building":4,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[16,33],"building":4,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[29,33],"building":4,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[9,82],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[17,82],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[25,82],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[9,85],"building":5,"level":0,"state":"closed","normal":[0,1],"external":false},
		{"cell":[17,85],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[25,85],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[4,83],"building":5,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[29,83],"building":5,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[52,17],"building":6,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[44,17],"building":6,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[59,17],"building":6,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[60,88],"building":7,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[54,88],"building":7,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[65,88],"building":7,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[52,33],"building":8,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[44,33],"building":8,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[59,33],"building":8,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[24,16],"building":9,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[31,16],"building":9,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[152,59],"building":10,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[146,59],"building":10,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[157,59],"building":10,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[6,16],"building":11,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[9,16],"building":11,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[7,12],"building":11,"level":0,"state":"open","normal":[0,-1],"external":true},
		{"cell":[7,19],"building":11,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[50,48],"building":12,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[44,48],"building":12,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[55,48],"building":12,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[51,63],"building":13,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[57,63],"building":13,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[44,63],"building":13,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[63,63],"building":13,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[10,48],"building":14,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[22,48],"building":14,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[10,51],"building":14,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[22,51],"building":14,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[4,49],"building":14,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[27,49],"building":14,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[10,48],"building":14,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[22,48],"building":14,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[10,51],"building":14,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[22,51],"building":14,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[150,100],"building":15,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[156,100],"building":15,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[162,100],"building":15,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[168,100],"building":15,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[144,100],"building":15,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[173,100],"building":15,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[150,100],"building":15,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[156,100],"building":15,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[162,100],"building":15,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[168,100],"building":15,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[78,36],"building":0,"level":0,"state":"open","normal":[0,-1],"external":true},
		{"cell":[78,42],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[78,49],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[98,36],"building":0,"level":0,"state":"open","normal":[0,-1],"external":true},
		{"cell":[98,42],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[98,49],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[118,36],"building":0,"level":0,"state":"open","normal":[0,-1],"external":true},
		{"cell":[118,42],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[118,49],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[79,59],"building":0,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[124,59],"building":0,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[79,70],"building":0,"level":0,"state":"closed","normal":[1,0],"external":false},
		{"cell":[94,75],"building":0,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[96,75],"building":0,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[98,75],"building":0,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[100,75],"building":0,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[102,75],"building":0,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[104,75],"building":0,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[76,45],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[76,53],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[87,45],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[87,53],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[98,45],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[98,53],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[108,45],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[108,53],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[118,45],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[118,53],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[128,45],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[128,53],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[76,67],"building":0,"level":-1,"state":"closed","normal":[0,1],"external":false},
		{"cell":[76,58],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[87,67],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[87,58],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[98,67],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[98,58],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[108,67],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[108,58],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[118,67],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[118,58],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[128,67],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[128,58],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false}],
	"windows": [{"cell":[144,37],"building":1,"level":0},
		{"cell":[171,46],"building":1,"level":0},
		{"cell":[144,37],"building":1,"level":1},
		{"cell":[171,46],"building":1,"level":1},
		{"cell":[144,37],"building":1,"level":2},
		{"cell":[171,46],"building":1,"level":2},
		{"cell":[140,13],"building":2,"level":0},
		{"cell":[177,24],"building":2,"level":0},
		{"cell":[140,13],"building":2,"level":1},
		{"cell":[177,24],"building":2,"level":1},
		{"cell":[140,13],"building":2,"level":2},
		{"cell":[177,24],"building":2,"level":2},
		{"cell":[140,79],"building":3,"level":0},
		{"cell":[175,88],"building":3,"level":0},
		{"cell":[140,79],"building":3,"level":1},
		{"cell":[175,88],"building":3,"level":1},
		{"cell":[140,79],"building":3,"level":2},
		{"cell":[175,88],"building":3,"level":2},
		{"cell":[18,28],"building":4,"level":0},
		{"cell":[7,72],"building":5,"level":0},
		{"cell":[26,95],"building":5,"level":0},
		{"cell":[46,12],"building":6,"level":0},
		{"cell":[56,84],"building":7,"level":0},
		{"cell":[46,28],"building":8,"level":0},
		{"cell":[26,12],"building":9,"level":0},
		{"cell":[148,55],"building":10,"level":0},
		{"cell":[2,15],"building":11,"level":0},
		{"cell":[13,16],"building":11,"level":0},
		{"cell":[46,44],"building":12,"level":0},
		{"cell":[46,58],"building":13,"level":0},
		{"cell":[7,44],"building":14,"level":0},
		{"cell":[24,55],"building":14,"level":0},
		{"cell":[7,44],"building":14,"level":1},
		{"cell":[24,55],"building":14,"level":1},
		{"cell":[146,96],"building":15,"level":0},
		{"cell":[146,96],"building":15,"level":1},
		{"cell":[70,60],"building":0,"level":0},
		{"cell":[133,68],"building":0,"level":0},
		{"cell":[73,36],"building":0,"level":-1},
		{"cell":[130,75],"building":0,"level":-1}],
	"stairs": [{"cell":[157,36],"low":0,"high":1,"ladder":false},
		{"cell":[157,36],"low":1,"high":2,"ladder":false},
		{"cell":[158,47],"low":0,"high":1,"ladder":false},
		{"cell":[158,47],"low":1,"high":2,"ladder":false},
		{"cell":[158,12],"low":0,"high":1,"ladder":false},
		{"cell":[158,12],"low":1,"high":2,"ladder":false},
		{"cell":[159,25],"low":0,"high":1,"ladder":false},
		{"cell":[159,25],"low":1,"high":2,"ladder":false},
		{"cell":[157,78],"low":0,"high":1,"ladder":false},
		{"cell":[157,78],"low":1,"high":2,"ladder":false},
		{"cell":[158,89],"low":0,"high":1,"ladder":false},
		{"cell":[158,89],"low":1,"high":2,"ladder":false},
		{"cell":[6,49],"low":0,"high":1,"ladder":false},
		{"cell":[145,100],"low":0,"high":1,"ladder":false},
		{"cell":[112,51],"low":-1,"high":0,"ladder":false}],
	"rooms": [{"building":1,"level":0,"rect":[145,35,11,14],"use":"매장"},
		{"building":1,"level":0,"rect":[160,35,11,14],"use":"매장"},
		{"building":1,"level":1,"rect":[145,35,11,14],"use":"매장"},
		{"building":1,"level":1,"rect":[160,35,11,14],"use":"매장"},
		{"building":1,"level":2,"rect":[145,35,11,14],"use":"매장"},
		{"building":1,"level":2,"rect":[160,35,11,14],"use":"매장"},
		{"building":2,"level":0,"rect":[141,11,8,8],"use":"부엌"},
		{"building":2,"level":0,"rect":[150,11,7,8],"use":"안방"},
		{"building":2,"level":0,"rect":[141,20,8,7],"use":"부엌"},
		{"building":2,"level":0,"rect":[150,20,7,7],"use":"안방"},
		{"building":2,"level":0,"rect":[161,11,8,8],"use":"부엌"},
		{"building":2,"level":0,"rect":[170,11,7,8],"use":"안방"},
		{"building":2,"level":0,"rect":[161,20,8,7],"use":"부엌"},
		{"building":2,"level":0,"rect":[170,20,7,7],"use":"안방"},
		{"building":2,"level":1,"rect":[141,11,8,8],"use":"부엌"},
		{"building":2,"level":1,"rect":[150,11,7,8],"use":"안방"},
		{"building":2,"level":1,"rect":[141,20,8,7],"use":"부엌"},
		{"building":2,"level":1,"rect":[150,20,7,7],"use":"안방"},
		{"building":2,"level":1,"rect":[161,11,8,8],"use":"부엌"},
		{"building":2,"level":1,"rect":[170,11,7,8],"use":"안방"},
		{"building":2,"level":1,"rect":[161,20,8,7],"use":"부엌"},
		{"building":2,"level":1,"rect":[170,20,7,7],"use":"안방"},
		{"building":2,"level":2,"rect":[141,11,8,8],"use":"부엌"},
		{"building":2,"level":2,"rect":[150,11,7,8],"use":"안방"},
		{"building":2,"level":2,"rect":[141,20,8,7],"use":"부엌"},
		{"building":2,"level":2,"rect":[150,20,7,7],"use":"안방"},
		{"building":2,"level":2,"rect":[161,11,8,8],"use":"부엌"},
		{"building":2,"level":2,"rect":[170,11,7,8],"use":"안방"},
		{"building":2,"level":2,"rect":[161,20,8,7],"use":"부엌"},
		{"building":2,"level":2,"rect":[170,20,7,7],"use":"안방"},
		{"building":3,"level":0,"rect":[141,77,7,14],"use":"부엌"},
		{"building":3,"level":0,"rect":[149,77,7,14],"use":"안방"},
		{"building":3,"level":0,"rect":[160,77,7,14],"use":"부엌"},
		{"building":3,"level":0,"rect":[168,77,7,14],"use":"안방"},
		{"building":3,"level":1,"rect":[141,77,7,14],"use":"부엌"},
		{"building":3,"level":1,"rect":[149,77,7,14],"use":"안방"},
		{"building":3,"level":1,"rect":[160,77,7,14],"use":"부엌"},
		{"building":3,"level":1,"rect":[168,77,7,14],"use":"안방"},
		{"building":3,"level":2,"rect":[141,77,7,14],"use":"부엌"},
		{"building":3,"level":2,"rect":[149,77,7,14],"use":"안방"},
		{"building":3,"level":2,"rect":[160,77,7,14],"use":"부엌"},
		{"building":3,"level":2,"rect":[168,77,7,14],"use":"안방"},
		{"building":4,"level":0,"rect":[17,29,6,8],"use":"작업실"},
		{"building":4,"level":0,"rect":[24,29,5,8],"use":"뒤 창고"},
		{"building":5,"level":0,"rect":[5,73,8,9],"use":"매장"},
		{"building":5,"level":0,"rect":[14,73,7,9],"use":"뒤 창고"},
		{"building":5,"level":0,"rect":[22,73,7,9],"use":"작업실"},
		{"building":5,"level":0,"rect":[5,86,8,9],"use":"매장"},
		{"building":5,"level":0,"rect":[14,86,7,9],"use":"뒤 창고"},
		{"building":5,"level":0,"rect":[22,86,7,9],"use":"작업실"},
		{"building":6,"level":0,"rect":[45,13,7,8],"use":"작업실"},
		{"building":6,"level":0,"rect":[53,13,6,8],"use":"뒤 창고"},
		{"building":7,"level":0,"rect":[55,85,5,6],"use":"작업실"},
		{"building":7,"level":0,"rect":[61,85,4,6],"use":"뒤 창고"},
		{"building":8,"level":0,"rect":[45,29,7,8],"use":"작업실"},
		{"building":8,"level":0,"rect":[53,29,6,8],"use":"뒤 창고"},
		{"building":9,"level":0,"rect":[25,13,6,6],"use":"작업실"},
		{"building":10,"level":0,"rect":[147,56,5,6],"use":"작업실"},
		{"building":10,"level":0,"rect":[153,56,4,6],"use":"뒤 창고"},
		{"building":11,"level":0,"rect":[3,13,3,6],"use":"매장"},
		{"building":11,"level":0,"rect":[10,13,3,6],"use":"매장"},
		{"building":12,"level":0,"rect":[45,45,5,6],"use":"작업실"},
		{"building":12,"level":0,"rect":[51,45,4,6],"use":"뒤 창고"},
		{"building":13,"level":0,"rect":[45,59,6,8],"use":"작업실"},
		{"building":13,"level":0,"rect":[52,59,5,8],"use":"뒤 창고"},
		{"building":13,"level":0,"rect":[58,59,5,8],"use":"뒤 창고"},
		{"building":14,"level":0,"rect":[5,45,11,3],"use":"매장"},
		{"building":14,"level":0,"rect":[17,45,10,3],"use":"뒤 창고"},
		{"building":14,"level":0,"rect":[5,52,11,3],"use":"매장"},
		{"building":14,"level":0,"rect":[17,52,10,3],"use":"뒤 창고"},
		{"building":14,"level":1,"rect":[5,45,11,3],"use":"매장"},
		{"building":14,"level":1,"rect":[17,45,10,3],"use":"뒤 창고"},
		{"building":14,"level":1,"rect":[5,52,11,3],"use":"매장"},
		{"building":14,"level":1,"rect":[17,52,10,3],"use":"뒤 창고"},
		{"building":15,"level":0,"rect":[145,97,5,6],"use":"작업실"},
		{"building":15,"level":0,"rect":[151,97,5,6],"use":"뒤 창고"},
		{"building":15,"level":0,"rect":[157,97,5,6],"use":"뒤 창고"},
		{"building":15,"level":0,"rect":[163,97,5,6],"use":"뒤 창고"},
		{"building":15,"level":0,"rect":[169,97,4,6],"use":"뒤 창고"},
		{"building":15,"level":1,"rect":[145,97,5,6],"use":"작업실"},
		{"building":15,"level":1,"rect":[151,97,5,6],"use":"뒤 창고"},
		{"building":15,"level":1,"rect":[157,97,5,6],"use":"뒤 창고"},
		{"building":15,"level":1,"rect":[163,97,5,6],"use":"뒤 창고"},
		{"building":15,"level":1,"rect":[169,97,4,6],"use":"뒤 창고"},
		{"building":0,"level":0,"rect":[71,37,18,5],"use":"하역 안쪽 칸"},
		{"building":0,"level":0,"rect":[71,43,18,6],"use":"뒤 창고"},
		{"building":0,"level":0,"rect":[90,37,20,5],"use":"하역 안쪽 칸"},
		{"building":0,"level":0,"rect":[90,43,20,6],"use":"뒤 창고"},
		{"building":0,"level":0,"rect":[111,37,22,5],"use":"하역 안쪽 칸"},
		{"building":0,"level":0,"rect":[111,43,22,6],"use":"냉동 창고"},
		{"building":0,"level":0,"rect":[71,54,8,10],"use":"냉장 구역"},
		{"building":0,"level":0,"rect":[125,54,8,10],"use":"빵 구역"},
		{"building":0,"level":0,"rect":[71,66,8,9],"use":"사무실"},
		{"building":0,"level":0,"rect":[81,54,42,15],"use":"판매장"},
		{"building":0,"level":0,"rect":[81,70,52,5],"use":"계산대 구역"},
		{"building":0,"level":-1,"rect":[71,37,10,8],"use":"부엌"},
		{"building":0,"level":-1,"rect":[71,46,10,7],"use":"안방"},
		{"building":0,"level":-1,"rect":[82,37,10,8],"use":"부엌"},
		{"building":0,"level":-1,"rect":[82,46,10,7],"use":"안방"},
		{"building":0,"level":-1,"rect":[93,37,10,8],"use":"부엌"},
		{"building":0,"level":-1,"rect":[93,46,10,7],"use":"안방"},
		{"building":0,"level":-1,"rect":[104,37,9,8],"use":"부엌"},
		{"building":0,"level":-1,"rect":[104,46,9,7],"use":"안방"},
		{"building":0,"level":-1,"rect":[114,37,9,8],"use":"부엌"},
		{"building":0,"level":-1,"rect":[114,46,9,7],"use":"안방"},
		{"building":0,"level":-1,"rect":[124,37,9,8],"use":"부엌"},
		{"building":0,"level":-1,"rect":[124,46,9,7],"use":"안방"},
		{"building":0,"level":-1,"rect":[71,59,10,8],"use":"부엌"},
		{"building":0,"level":-1,"rect":[71,68,10,7],"use":"안방"},
		{"building":0,"level":-1,"rect":[82,59,10,8],"use":"부엌"},
		{"building":0,"level":-1,"rect":[82,68,10,7],"use":"안방"},
		{"building":0,"level":-1,"rect":[93,59,10,8],"use":"부엌"},
		{"building":0,"level":-1,"rect":[93,68,10,7],"use":"안방"},
		{"building":0,"level":-1,"rect":[104,59,9,8],"use":"부엌"},
		{"building":0,"level":-1,"rect":[104,68,9,7],"use":"안방"},
		{"building":0,"level":-1,"rect":[114,59,9,8],"use":"부엌"},
		{"building":0,"level":-1,"rect":[114,68,9,7],"use":"안방"},
		{"building":0,"level":-1,"rect":[124,59,9,8],"use":"부엌"},
		{"building":0,"level":-1,"rect":[124,68,9,7],"use":"안방"}],
	"props": [{"kind":"floor_shell","rect":[140,10,38,18],"solid":"none","facing":0,"note":"사층 겉모양","level":3},
		{"kind":"stair_stub","rect":[159,12,1,2],"solid":"none","facing":0,"note":"계단 자리","level":2},
		{"kind":"floor_shell","rect":[140,76,36,16],"solid":"none","facing":0,"note":"사층 겉모양","level":3},
		{"kind":"stair_stub","rect":[158,78,1,2],"solid":"none","facing":0,"note":"계단 자리","level":2},
		{"kind":"display_shelf","rect":[82,55,4,1],"solid":"low","facing":0,"note":"진열대","level":0},
		{"kind":"display_shelf","rect":[89,55,4,1],"solid":"low","facing":1,"note":"진열대","level":0},
		{"kind":"display_shelf","rect":[106,55,4,1],"solid":"low","facing":2,"note":"진열대","level":0},
		{"kind":"display_shelf","rect":[89,59,4,1],"solid":"low","facing":3,"note":"진열대","level":0},
		{"kind":"display_shelf","rect":[106,59,4,1],"solid":"low","facing":0,"note":"진열대","level":0},
		{"kind":"display_shelf","rect":[113,59,4,1],"solid":"low","facing":1,"note":"진열대","level":0},
		{"kind":"display_shelf","rect":[82,63,4,1],"solid":"low","facing":2,"note":"진열대","level":0},
		{"kind":"display_shelf","rect":[89,63,4,1],"solid":"low","facing":3,"note":"진열대","level":0},
		{"kind":"display_shelf","rect":[106,63,4,1],"solid":"low","facing":0,"note":"진열대","level":0},
		{"kind":"display_shelf","rect":[113,63,4,1],"solid":"low","facing":1,"note":"진열대","level":0},
		{"kind":"display_shelf","rect":[82,67,4,1],"solid":"low","facing":2,"note":"진열대","level":0},
		{"kind":"display_shelf","rect":[89,67,4,1],"solid":"low","facing":3,"note":"진열대","level":0},
		{"kind":"display_shelf","rect":[106,67,4,1],"solid":"low","facing":0,"note":"진열대","level":0},
		{"kind":"display_shelf","rect":[113,67,4,1],"solid":"low","facing":1,"note":"진열대","level":0},
		{"kind":"checkout","rect":[88,70,2,1],"solid":"low","facing":2,"note":"마트 계산대","level":0},
		{"kind":"checkout","rect":[94,70,2,1],"solid":"low","facing":3,"note":"마트 계산대","level":0},
		{"kind":"checkout","rect":[106,70,2,1],"solid":"low","facing":0,"note":"마트 계산대","level":0},
		{"kind":"checkout","rect":[112,70,2,1],"solid":"low","facing":1,"note":"마트 계산대","level":0},
		{"kind":"checkout","rect":[118,70,2,1],"solid":"low","facing":2,"note":"마트 계산대","level":0},
		{"kind":"chiller_case","rect":[72,55,4,1],"solid":"low","facing":3,"note":"냉장 진열대","level":0},
		{"kind":"chiller_case","rect":[72,61,4,1],"solid":"low","facing":0,"note":"냉장 진열대","level":0},
		{"kind":"bread_rack","rect":[126,55,1,1],"solid":"low","facing":1,"note":"빵 선반","level":0},
		{"kind":"bread_rack","rect":[130,55,1,1],"solid":"low","facing":2,"note":"빵 선반","level":0},
		{"kind":"bread_rack","rect":[130,62,1,1],"solid":"low","facing":3,"note":"빵 선반","level":0},
		{"kind":"high_rack","rect":[72,38,4,1],"solid":"wall","facing":0,"note":"창고 높은 선반","level":0},
		{"kind":"high_rack","rect":[82,44,4,1],"solid":"wall","facing":1,"note":"창고 높은 선반","level":0},
		{"kind":"high_rack","rect":[91,38,4,1],"solid":"wall","facing":2,"note":"창고 높은 선반","level":0},
		{"kind":"high_rack","rect":[102,44,4,1],"solid":"wall","facing":3,"note":"창고 높은 선반","level":0},
		{"kind":"high_rack","rect":[111,38,4,1],"solid":"wall","facing":0,"note":"창고 높은 선반","level":0},
		{"kind":"high_rack","rect":[126,44,4,1],"solid":"wall","facing":1,"note":"창고 높은 선반","level":0},
		{"kind":"freezer_chest","rect":[122,47,2,1],"solid":"low","facing":2,"note":"냉동 궤","level":0},
		{"kind":"freezer_chest","rect":[126,47,2,1],"solid":"low","facing":3,"note":"냉동 궤","level":0},
		{"kind":"desk","rect":[154,35,2,1],"solid":"low","facing":1,"note":"매장의 책상","level":0},
		{"kind":"office_cabinet","rect":[145,48,2,1],"solid":"low","facing":2,"note":"매장의 사무실 서류장","level":0},
		{"kind":"shelf","rect":[153,48,3,1],"solid":"low","facing":3,"note":"매장의 선반","level":0},
		{"kind":"desk","rect":[169,35,2,1],"solid":"low","facing":1,"note":"매장의 책상","level":0},
		{"kind":"office_cabinet","rect":[160,48,2,1],"solid":"low","facing":2,"note":"매장의 사무실 서류장","level":0},
		{"kind":"shelf","rect":[168,48,3,1],"solid":"low","facing":3,"note":"매장의 선반","level":0},
		{"kind":"desk","rect":[154,35,2,1],"solid":"none","facing":1,"note":"매장의 책상","level":1},
		{"kind":"office_cabinet","rect":[145,48,2,1],"solid":"none","facing":2,"note":"매장의 사무실 서류장","level":1},
		{"kind":"shelf","rect":[153,48,3,1],"solid":"none","facing":3,"note":"매장의 선반","level":1},
		{"kind":"desk","rect":[169,35,2,1],"solid":"none","facing":1,"note":"매장의 책상","level":1},
		{"kind":"office_cabinet","rect":[160,48,2,1],"solid":"none","facing":2,"note":"매장의 사무실 서류장","level":1},
		{"kind":"shelf","rect":[168,48,3,1],"solid":"none","facing":3,"note":"매장의 선반","level":1},
		{"kind":"desk","rect":[154,35,2,1],"solid":"none","facing":1,"note":"매장의 책상","level":2},
		{"kind":"office_cabinet","rect":[145,48,2,1],"solid":"none","facing":2,"note":"매장의 사무실 서류장","level":2},
		{"kind":"shelf","rect":[153,48,3,1],"solid":"none","facing":3,"note":"매장의 선반","level":2},
		{"kind":"desk","rect":[169,35,2,1],"solid":"none","facing":1,"note":"매장의 책상","level":2},
		{"kind":"office_cabinet","rect":[160,48,2,1],"solid":"none","facing":2,"note":"매장의 사무실 서류장","level":2},
		{"kind":"shelf","rect":[168,48,3,1],"solid":"none","facing":3,"note":"매장의 선반","level":2},
		{"kind":"dining_set","rect":[141,11,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[148,18,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[141,18,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[150,11,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[156,18,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[150,18,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[141,20,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[148,26,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[141,26,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[150,20,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[156,26,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[150,26,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[161,11,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[168,18,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[161,18,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[170,11,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[176,18,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[170,18,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[161,20,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[168,26,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[161,26,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[170,20,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[176,26,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[170,26,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[141,11,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[148,18,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[141,18,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[150,11,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[156,18,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[150,18,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[141,20,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[148,26,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[141,26,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[150,20,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[156,26,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[150,26,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[161,11,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[168,18,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[161,18,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[170,11,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[176,18,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[170,18,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[161,20,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[168,26,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[161,26,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[170,20,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[176,26,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[170,26,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[141,11,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[148,18,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[141,18,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[150,11,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[156,18,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[150,18,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[141,20,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[148,26,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[141,26,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[150,20,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[156,26,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[150,26,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[161,11,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[168,18,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[161,18,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[170,11,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[176,18,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[170,18,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[161,20,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[168,26,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[161,26,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[170,20,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[176,26,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[170,26,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[146,77,2,2],"solid":"low","facing":3,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[141,90,1,1],"solid":"low","facing":0,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[147,90,1,1],"solid":"low","facing":1,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[154,77,2,1],"solid":"low","facing":3,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[149,90,1,1],"solid":"low","facing":0,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[154,90,2,1],"solid":"low","facing":1,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[165,77,2,2],"solid":"low","facing":3,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[160,90,1,1],"solid":"low","facing":0,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[166,90,1,1],"solid":"low","facing":1,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[173,77,2,1],"solid":"low","facing":3,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[168,90,1,1],"solid":"low","facing":0,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[173,90,2,1],"solid":"low","facing":1,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[146,77,2,2],"solid":"none","facing":3,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[141,90,1,1],"solid":"none","facing":0,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[147,90,1,1],"solid":"none","facing":1,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[154,77,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[149,90,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[154,90,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[165,77,2,2],"solid":"none","facing":3,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[160,90,1,1],"solid":"none","facing":0,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[166,90,1,1],"solid":"none","facing":1,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[173,77,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[168,90,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[173,90,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[146,77,2,2],"solid":"none","facing":3,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[141,90,1,1],"solid":"none","facing":0,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[147,90,1,1],"solid":"none","facing":1,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[154,77,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[149,90,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[154,90,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[165,77,2,2],"solid":"none","facing":3,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[160,90,1,1],"solid":"none","facing":0,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[166,90,1,1],"solid":"none","facing":1,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[173,77,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[168,90,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[173,90,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":2},
		{"kind":"shop_counter","rect":[17,29,3,1],"solid":"none","facing":0,"note":"작업실의 가게 계산대","level":0},
		{"kind":"shop_counter","rect":[20,36,3,1],"solid":"low","facing":1,"note":"작업실의 가게 계산대","level":0},
		{"kind":"display_shelf","rect":[24,29,4,1],"solid":"none","facing":0,"note":"뒤 창고의 진열대","level":0},
		{"kind":"chiller_case","rect":[25,36,4,1],"solid":"low","facing":1,"note":"뒤 창고의 냉장 진열대","level":0},
		{"kind":"garden_rack","rect":[10,73,3,1],"solid":"low","facing":1,"note":"매장의 원예 화분 선반","level":0},
		{"kind":"shop_counter","rect":[5,81,3,1],"solid":"low","facing":2,"note":"매장의 가게 계산대","level":0},
		{"kind":"shop_counter","rect":[10,81,3,1],"solid":"low","facing":3,"note":"매장의 가게 계산대","level":0},
		{"kind":"garden_rack","rect":[18,73,3,1],"solid":"low","facing":1,"note":"뒤 창고의 원예 화분 선반","level":0},
		{"kind":"sack_pile","rect":[14,80,2,2],"solid":"low","facing":2,"note":"뒤 창고의 자루 더미","level":0},
		{"kind":"shelf","rect":[18,81,3,1],"solid":"low","facing":3,"note":"뒤 창고의 선반","level":0},
		{"kind":"sack_pile","rect":[27,73,2,2],"solid":"low","facing":1,"note":"작업실의 자루 더미","level":0},
		{"kind":"shelf","rect":[22,81,3,1],"solid":"low","facing":2,"note":"작업실의 선반","level":0},
		{"kind":"garden_rack","rect":[26,81,3,1],"solid":"low","facing":3,"note":"작업실의 원예 화분 선반","level":0},
		{"kind":"garden_rack","rect":[10,86,3,1],"solid":"low","facing":1,"note":"매장의 원예 화분 선반","level":0},
		{"kind":"sack_pile","rect":[5,93,2,2],"solid":"low","facing":2,"note":"매장의 자루 더미","level":0},
		{"kind":"shelf","rect":[10,94,3,1],"solid":"low","facing":3,"note":"매장의 선반","level":0},
		{"kind":"garden_rack","rect":[18,86,3,1],"solid":"low","facing":1,"note":"뒤 창고의 원예 화분 선반","level":0},
		{"kind":"sack_pile","rect":[14,93,2,2],"solid":"low","facing":2,"note":"뒤 창고의 자루 더미","level":0},
		{"kind":"shelf","rect":[18,94,3,1],"solid":"low","facing":3,"note":"뒤 창고의 선반","level":0},
		{"kind":"sack_pile","rect":[27,86,2,2],"solid":"low","facing":1,"note":"작업실의 자루 더미","level":0},
		{"kind":"shelf","rect":[22,94,3,1],"solid":"low","facing":2,"note":"작업실의 선반","level":0},
		{"kind":"garden_rack","rect":[26,94,3,1],"solid":"low","facing":3,"note":"작업실의 원예 화분 선반","level":0},
		{"kind":"desk","rect":[45,13,2,1],"solid":"none","facing":2,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[50,19,2,2],"solid":"none","facing":3,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[45,20,3,1],"solid":"none","facing":0,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[53,13,3,1],"solid":"none","facing":2,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[57,20,2,1],"solid":"none","facing":3,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[53,19,2,2],"solid":"none","facing":0,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"desk","rect":[58,85,2,1],"solid":"low","facing":3,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[55,89,2,2],"solid":"low","facing":0,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[57,90,3,1],"solid":"low","facing":1,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[62,85,3,1],"solid":"low","facing":3,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[61,90,2,1],"solid":"low","facing":0,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[63,89,2,2],"solid":"low","facing":1,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"shop_counter","rect":[45,29,3,1],"solid":"none","facing":0,"note":"작업실의 가게 계산대","level":0},
		{"kind":"barrel","rect":[51,36,1,1],"solid":"low","facing":1,"note":"작업실의 통","level":0},
		{"kind":"bread_rack","rect":[45,36,1,1],"solid":"low","facing":2,"note":"작업실의 빵 선반","level":0},
		{"kind":"bread_rack","rect":[53,29,1,1],"solid":"none","facing":0,"note":"뒤 창고의 빵 선반","level":0},
		{"kind":"shelf","rect":[56,36,3,1],"solid":"low","facing":1,"note":"뒤 창고의 선반","level":0},
		{"kind":"barrel","rect":[53,36,1,1],"solid":"low","facing":2,"note":"뒤 창고의 통","level":0},
		{"kind":"desk","rect":[29,13,2,1],"solid":"none","facing":1,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[25,17,2,2],"solid":"none","facing":2,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[28,18,3,1],"solid":"none","facing":3,"note":"작업실의 선반","level":0},
		{"kind":"desk","rect":[147,56,2,1],"solid":"low","facing":2,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[150,60,2,2],"solid":"low","facing":3,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[147,61,3,1],"solid":"low","facing":0,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[153,56,3,1],"solid":"low","facing":2,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[155,61,2,1],"solid":"low","facing":3,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[153,60,2,2],"solid":"low","facing":0,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[3,13,3,1],"solid":"none","facing":3,"note":"매장의 선반","level":0},
		{"kind":"desk","rect":[3,18,2,1],"solid":"none","facing":0,"note":"매장의 책상","level":0},
		{"kind":"shelf","rect":[10,13,3,1],"solid":"none","facing":3,"note":"매장의 선반","level":0},
		{"kind":"desk","rect":[10,18,2,1],"solid":"none","facing":0,"note":"매장의 책상","level":0},
		{"kind":"desk","rect":[45,45,2,1],"solid":"low","facing":0,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[48,49,2,2],"solid":"low","facing":1,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[45,50,3,1],"solid":"low","facing":2,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[51,45,3,1],"solid":"low","facing":0,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[53,50,2,1],"solid":"low","facing":1,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[51,49,2,2],"solid":"low","facing":2,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"desk","rect":[49,59,2,1],"solid":"low","facing":1,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[45,65,2,2],"solid":"low","facing":2,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[48,66,3,1],"solid":"low","facing":3,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[54,59,3,1],"solid":"low","facing":1,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[52,66,2,1],"solid":"low","facing":2,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[55,65,2,2],"solid":"low","facing":3,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[60,59,3,1],"solid":"low","facing":1,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[58,66,2,1],"solid":"low","facing":2,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[61,65,2,2],"solid":"low","facing":3,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"glass_cabinet","rect":[5,45,2,1],"solid":"low","facing":2,"note":"매장의 진열장","level":0},
		{"kind":"shop_counter","rect":[13,47,3,1],"solid":"low","facing":3,"note":"매장의 가게 계산대","level":0},
		{"kind":"shelf","rect":[5,47,3,1],"solid":"low","facing":0,"note":"매장의 선반","level":0},
		{"kind":"glass_cabinet","rect":[17,45,2,1],"solid":"low","facing":2,"note":"뒤 창고의 진열장","level":0},
		{"kind":"shelf","rect":[24,47,3,1],"solid":"low","facing":3,"note":"뒤 창고의 선반","level":0},
		{"kind":"shelf","rect":[17,47,3,1],"solid":"low","facing":0,"note":"뒤 창고의 선반","level":0},
		{"kind":"glass_cabinet","rect":[5,52,2,1],"solid":"low","facing":2,"note":"매장의 진열장","level":0},
		{"kind":"shelf","rect":[13,54,3,1],"solid":"low","facing":3,"note":"매장의 선반","level":0},
		{"kind":"shelf","rect":[5,54,3,1],"solid":"low","facing":0,"note":"매장의 선반","level":0},
		{"kind":"glass_cabinet","rect":[17,52,2,1],"solid":"low","facing":2,"note":"뒤 창고의 진열장","level":0},
		{"kind":"shelf","rect":[24,54,3,1],"solid":"low","facing":3,"note":"뒤 창고의 선반","level":0},
		{"kind":"shelf","rect":[17,54,3,1],"solid":"low","facing":0,"note":"뒤 창고의 선반","level":0},
		{"kind":"bed","rect":[5,45,2,1],"solid":"none","facing":2,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[15,47,1,1],"solid":"none","facing":3,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[5,47,2,1],"solid":"none","facing":0,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[17,45,2,1],"solid":"none","facing":2,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[26,47,1,1],"solid":"none","facing":3,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[17,47,2,1],"solid":"none","facing":0,"note":"뒤 창고의 장롱","level":1},
		{"kind":"bed","rect":[5,52,2,1],"solid":"none","facing":2,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[15,54,1,1],"solid":"none","facing":3,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[5,54,2,1],"solid":"none","facing":0,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[17,52,2,1],"solid":"none","facing":2,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[26,54,1,1],"solid":"none","facing":3,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[17,54,2,1],"solid":"none","facing":0,"note":"뒤 창고의 장롱","level":1},
		{"kind":"cold_stove","rect":[149,97,1,1],"solid":"low","facing":3,"note":"작업실의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[145,102,2,1],"solid":"low","facing":0,"note":"작업실의 장롱","level":0},
		{"kind":"bed","rect":[148,102,2,1],"solid":"low","facing":1,"note":"작업실의 침대","level":0},
		{"kind":"bed","rect":[154,97,2,1],"solid":"low","facing":3,"note":"뒤 창고의 침대","level":0},
		{"kind":"cold_stove","rect":[151,102,1,1],"solid":"low","facing":0,"note":"뒤 창고의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[154,102,2,1],"solid":"low","facing":1,"note":"뒤 창고의 장롱","level":0},
		{"kind":"bed","rect":[160,97,2,1],"solid":"low","facing":3,"note":"뒤 창고의 침대","level":0},
		{"kind":"cold_stove","rect":[157,102,1,1],"solid":"low","facing":0,"note":"뒤 창고의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[160,102,2,1],"solid":"low","facing":1,"note":"뒤 창고의 장롱","level":0},
		{"kind":"bed","rect":[166,97,2,1],"solid":"low","facing":3,"note":"뒤 창고의 침대","level":0},
		{"kind":"cold_stove","rect":[163,102,1,1],"solid":"low","facing":0,"note":"뒤 창고의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[166,102,2,1],"solid":"low","facing":1,"note":"뒤 창고의 장롱","level":0},
		{"kind":"bed","rect":[171,97,2,1],"solid":"low","facing":3,"note":"뒤 창고의 침대","level":0},
		{"kind":"cold_stove","rect":[169,102,1,1],"solid":"low","facing":0,"note":"뒤 창고의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[171,102,2,1],"solid":"low","facing":1,"note":"뒤 창고의 장롱","level":0},
		{"kind":"cold_stove","rect":[149,97,1,1],"solid":"none","facing":3,"note":"작업실의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[145,102,2,1],"solid":"none","facing":0,"note":"작업실의 장롱","level":1},
		{"kind":"bed","rect":[148,102,2,1],"solid":"none","facing":1,"note":"작업실의 침대","level":1},
		{"kind":"bed","rect":[154,97,2,1],"solid":"none","facing":3,"note":"뒤 창고의 침대","level":1},
		{"kind":"cold_stove","rect":[151,102,1,1],"solid":"none","facing":0,"note":"뒤 창고의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[154,102,2,1],"solid":"none","facing":1,"note":"뒤 창고의 장롱","level":1},
		{"kind":"bed","rect":[160,97,2,1],"solid":"none","facing":3,"note":"뒤 창고의 침대","level":1},
		{"kind":"cold_stove","rect":[157,102,1,1],"solid":"none","facing":0,"note":"뒤 창고의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[160,102,2,1],"solid":"none","facing":1,"note":"뒤 창고의 장롱","level":1},
		{"kind":"bed","rect":[166,97,2,1],"solid":"none","facing":3,"note":"뒤 창고의 침대","level":1},
		{"kind":"cold_stove","rect":[163,102,1,1],"solid":"none","facing":0,"note":"뒤 창고의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[166,102,2,1],"solid":"none","facing":1,"note":"뒤 창고의 장롱","level":1},
		{"kind":"bed","rect":[171,97,2,1],"solid":"none","facing":3,"note":"뒤 창고의 침대","level":1},
		{"kind":"cold_stove","rect":[169,102,1,1],"solid":"none","facing":0,"note":"뒤 창고의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[171,102,2,1],"solid":"none","facing":1,"note":"뒤 창고의 장롱","level":1},
		{"kind":"shelf","rect":[71,37,3,1],"solid":"low","facing":0,"note":"하역 안쪽 칸의 선반","level":0},
		{"kind":"desk","rect":[87,41,2,1],"solid":"low","facing":1,"note":"하역 안쪽 칸의 책상","level":0},
		{"kind":"crate_stack","rect":[71,40,2,2],"solid":"low","facing":2,"note":"하역 안쪽 칸의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[71,43,3,1],"solid":"low","facing":0,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[87,48,2,1],"solid":"low","facing":1,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[71,47,2,2],"solid":"low","facing":2,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[90,37,3,1],"solid":"low","facing":0,"note":"하역 안쪽 칸의 선반","level":0},
		{"kind":"desk","rect":[108,41,2,1],"solid":"low","facing":1,"note":"하역 안쪽 칸의 책상","level":0},
		{"kind":"crate_stack","rect":[90,40,2,2],"solid":"low","facing":2,"note":"하역 안쪽 칸의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[90,43,3,1],"solid":"low","facing":0,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[108,48,2,1],"solid":"low","facing":1,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[90,47,2,2],"solid":"low","facing":2,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[111,37,3,1],"solid":"low","facing":0,"note":"하역 안쪽 칸의 선반","level":0},
		{"kind":"desk","rect":[131,41,2,1],"solid":"low","facing":1,"note":"하역 안쪽 칸의 책상","level":0},
		{"kind":"crate_stack","rect":[111,40,2,2],"solid":"low","facing":2,"note":"하역 안쪽 칸의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[111,43,3,1],"solid":"low","facing":0,"note":"냉동 창고의 선반","level":0},
		{"kind":"desk","rect":[131,48,2,1],"solid":"low","facing":1,"note":"냉동 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[111,47,2,2],"solid":"low","facing":2,"note":"냉동 창고의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[71,54,3,1],"solid":"low","facing":0,"note":"냉장 구역의 선반","level":0},
		{"kind":"desk","rect":[77,63,2,1],"solid":"low","facing":1,"note":"냉장 구역의 책상","level":0},
		{"kind":"crate_stack","rect":[71,62,2,2],"solid":"low","facing":2,"note":"냉장 구역의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[125,54,3,1],"solid":"low","facing":0,"note":"빵 구역의 선반","level":0},
		{"kind":"desk","rect":[131,63,2,1],"solid":"low","facing":1,"note":"빵 구역의 책상","level":0},
		{"kind":"crate_stack","rect":[125,62,2,2],"solid":"low","facing":2,"note":"빵 구역의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[71,66,3,1],"solid":"low","facing":0,"note":"사무실의 선반","level":0},
		{"kind":"desk","rect":[77,74,2,1],"solid":"low","facing":1,"note":"사무실의 책상","level":0},
		{"kind":"crate_stack","rect":[71,73,2,2],"solid":"low","facing":2,"note":"사무실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[81,54,3,1],"solid":"low","facing":0,"note":"판매장의 선반","level":0},
		{"kind":"desk","rect":[121,68,2,1],"solid":"low","facing":1,"note":"판매장의 책상","level":0},
		{"kind":"crate_stack","rect":[121,54,2,2],"solid":"low","facing":2,"note":"판매장의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[130,74,3,1],"solid":"low","facing":0,"note":"계산대 구역의 선반","level":0},
		{"kind":"desk","rect":[81,74,2,1],"solid":"low","facing":1,"note":"계산대 구역의 책상","level":0},
		{"kind":"crate_stack","rect":[131,70,2,2],"solid":"low","facing":2,"note":"계산대 구역의 나무 상자 더미","level":0},
		{"kind":"jar_shelf","rect":[71,37,3,1],"solid":"none","facing":0,"note":"부엌의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[80,44,1,1],"solid":"none","facing":1,"note":"부엌의 통","level":-1},
		{"kind":"tin_crate","rect":[71,44,2,1],"solid":"none","facing":2,"note":"부엌의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[71,46,3,1],"solid":"none","facing":0,"note":"안방의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[80,52,1,1],"solid":"none","facing":1,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[71,52,2,1],"solid":"none","facing":2,"note":"안방의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[82,37,3,1],"solid":"none","facing":0,"note":"부엌의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[91,44,1,1],"solid":"none","facing":1,"note":"부엌의 통","level":-1},
		{"kind":"tin_crate","rect":[82,44,2,1],"solid":"none","facing":2,"note":"부엌의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[82,46,3,1],"solid":"none","facing":0,"note":"안방의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[91,52,1,1],"solid":"none","facing":1,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[82,52,2,1],"solid":"none","facing":2,"note":"안방의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[93,37,3,1],"solid":"none","facing":0,"note":"부엌의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[102,44,1,1],"solid":"none","facing":1,"note":"부엌의 통","level":-1},
		{"kind":"tin_crate","rect":[93,44,2,1],"solid":"none","facing":2,"note":"부엌의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[93,46,3,1],"solid":"none","facing":0,"note":"안방의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[102,52,1,1],"solid":"none","facing":1,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[93,52,2,1],"solid":"none","facing":2,"note":"안방의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[104,37,3,1],"solid":"none","facing":0,"note":"부엌의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[112,44,1,1],"solid":"none","facing":1,"note":"부엌의 통","level":-1},
		{"kind":"tin_crate","rect":[104,44,2,1],"solid":"none","facing":2,"note":"부엌의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[104,46,3,1],"solid":"none","facing":0,"note":"안방의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[104,52,1,1],"solid":"none","facing":1,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[111,46,2,1],"solid":"none","facing":2,"note":"안방의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[114,37,3,1],"solid":"none","facing":0,"note":"부엌의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[122,44,1,1],"solid":"none","facing":1,"note":"부엌의 통","level":-1},
		{"kind":"tin_crate","rect":[114,44,2,1],"solid":"none","facing":2,"note":"부엌의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[114,46,3,1],"solid":"none","facing":0,"note":"안방의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[122,52,1,1],"solid":"none","facing":1,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[114,52,2,1],"solid":"none","facing":2,"note":"안방의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[124,37,3,1],"solid":"none","facing":0,"note":"부엌의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[132,44,1,1],"solid":"none","facing":1,"note":"부엌의 통","level":-1},
		{"kind":"tin_crate","rect":[124,44,2,1],"solid":"none","facing":2,"note":"부엌의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[124,46,3,1],"solid":"none","facing":0,"note":"안방의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[132,52,1,1],"solid":"none","facing":1,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[124,52,2,1],"solid":"none","facing":2,"note":"안방의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[71,59,3,1],"solid":"none","facing":0,"note":"부엌의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[80,66,1,1],"solid":"none","facing":1,"note":"부엌의 통","level":-1},
		{"kind":"tin_crate","rect":[71,66,2,1],"solid":"none","facing":2,"note":"부엌의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[71,68,3,1],"solid":"none","facing":0,"note":"안방의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[80,74,1,1],"solid":"none","facing":1,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[71,74,2,1],"solid":"none","facing":2,"note":"안방의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[82,59,3,1],"solid":"none","facing":0,"note":"부엌의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[91,66,1,1],"solid":"none","facing":1,"note":"부엌의 통","level":-1},
		{"kind":"tin_crate","rect":[82,66,2,1],"solid":"none","facing":2,"note":"부엌의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[82,68,3,1],"solid":"none","facing":0,"note":"안방의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[91,74,1,1],"solid":"none","facing":1,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[82,74,2,1],"solid":"none","facing":2,"note":"안방의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[93,59,3,1],"solid":"none","facing":0,"note":"부엌의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[102,66,1,1],"solid":"none","facing":1,"note":"부엌의 통","level":-1},
		{"kind":"tin_crate","rect":[93,66,2,1],"solid":"none","facing":2,"note":"부엌의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[93,68,3,1],"solid":"none","facing":0,"note":"안방의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[102,74,1,1],"solid":"none","facing":1,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[93,74,2,1],"solid":"none","facing":2,"note":"안방의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[104,59,3,1],"solid":"none","facing":0,"note":"부엌의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[112,66,1,1],"solid":"none","facing":1,"note":"부엌의 통","level":-1},
		{"kind":"tin_crate","rect":[104,66,2,1],"solid":"none","facing":2,"note":"부엌의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[104,68,3,1],"solid":"none","facing":0,"note":"안방의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[112,74,1,1],"solid":"none","facing":1,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[104,74,2,1],"solid":"none","facing":2,"note":"안방의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[114,59,3,1],"solid":"none","facing":0,"note":"부엌의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[122,66,1,1],"solid":"none","facing":1,"note":"부엌의 통","level":-1},
		{"kind":"tin_crate","rect":[114,66,2,1],"solid":"none","facing":2,"note":"부엌의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[114,68,3,1],"solid":"none","facing":0,"note":"안방의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[122,74,1,1],"solid":"none","facing":1,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[114,74,2,1],"solid":"none","facing":2,"note":"안방의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[124,59,3,1],"solid":"none","facing":0,"note":"부엌의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[132,66,1,1],"solid":"none","facing":1,"note":"부엌의 통","level":-1},
		{"kind":"tin_crate","rect":[124,66,2,1],"solid":"none","facing":2,"note":"부엌의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[124,68,3,1],"solid":"none","facing":0,"note":"안방의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[132,74,1,1],"solid":"none","facing":1,"note":"안방의 통","level":-1},
		{"kind":"tin_crate","rect":[124,74,2,1],"solid":"none","facing":2,"note":"안방의 통조림 상자","level":-1},
		{"kind":"car","rect":[28,10,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
		{"kind":"bench","rect":[60,10,1,3],"solid":"low","facing":1,"note":"긴 의자","level":0},
		{"kind":"car","rect":[30,28,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
		{"kind":"firewood_pile","rect":[34,28,2,1],"solid":"low","facing":0,"note":"장작 더미","level":0},
		{"kind":"crate_stack","rect":[42,28,2,2],"solid":"low","facing":0,"note":"나무 상자 더미","level":0},
		{"kind":"street_tree","rect":[65,29,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"pallet_stack","rect":[70,33,2,2],"solid":"low","facing":3,"note":"팰릿 더미","level":0},
		{"kind":"pallet_stack","rect":[140,7,2,2],"solid":"low","facing":0,"note":"팰릿 더미","level":0},
		{"kind":"crate_stack","rect":[145,6,2,2],"solid":"low","facing":1,"note":"나무 상자 더미","level":0},
		{"kind":"handcart","rect":[149,8,2,1],"solid":"low","facing":2,"note":"손수레","level":0},
		{"kind":"pallet_stack","rect":[16,25,2,2],"solid":"none","facing":3,"note":"팰릿 더미","level":0},
		{"kind":"crate_stack","rect":[21,24,2,2],"solid":"none","facing":0,"note":"나무 상자 더미","level":0},
		{"kind":"handcart","rect":[25,26,2,1],"solid":"none","facing":1,"note":"손수레","level":0},
		{"kind":"pallet_stack","rect":[24,9,2,2],"solid":"none","facing":2,"note":"팰릿 더미","level":0},
		{"kind":"crate_stack","rect":[29,8,2,2],"solid":"none","facing":3,"note":"나무 상자 더미","level":0},
		{"kind":"handcart","rect":[33,10,2,1],"solid":"none","facing":0,"note":"손수레","level":0},
		{"kind":"car","rect":[70,80,4,2],"solid":"low","facing":1,"note":"버려진 차","level":0},
		{"kind":"car","rect":[79,80,4,2],"solid":"low","facing":2,"note":"버려진 차","level":0},
		{"kind":"car","rect":[88,80,4,2],"solid":"low","facing":3,"note":"버려진 차","level":0},
		{"kind":"car","rect":[112,80,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
		{"kind":"car","rect":[121,80,4,2],"solid":"low","facing":1,"note":"버려진 차","level":0},
		{"kind":"car","rect":[71,85,4,2],"solid":"low","facing":2,"note":"버려진 차","level":0},
		{"kind":"car","rect":[80,85,4,2],"solid":"low","facing":3,"note":"버려진 차","level":0},
		{"kind":"car","rect":[89,85,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
		{"kind":"car","rect":[113,85,4,2],"solid":"low","facing":1,"note":"버려진 차","level":0},
		{"kind":"car","rect":[122,85,4,2],"solid":"low","facing":2,"note":"버려진 차","level":0},
		{"kind":"car","rect":[70,90,4,2],"solid":"low","facing":3,"note":"버려진 차","level":0},
		{"kind":"car","rect":[79,90,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
		{"kind":"car","rect":[88,90,4,2],"solid":"low","facing":1,"note":"버려진 차","level":0},
		{"kind":"car","rect":[112,90,4,2],"solid":"low","facing":2,"note":"버려진 차","level":0},
		{"kind":"car","rect":[121,90,4,2],"solid":"low","facing":3,"note":"버려진 차","level":0},
		{"kind":"car","rect":[71,95,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
		{"kind":"car","rect":[80,95,4,2],"solid":"low","facing":1,"note":"버려진 차","level":0},
		{"kind":"car","rect":[89,95,4,2],"solid":"low","facing":2,"note":"버려진 차","level":0},
		{"kind":"car","rect":[113,95,4,2],"solid":"low","facing":3,"note":"버려진 차","level":0},
		{"kind":"car","rect":[122,95,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
		{"kind":"shopping_cart","rect":[80,78,1,1],"solid":"low","facing":1,"note":"장보기 수레","level":0},
		{"kind":"shopping_cart","rect":[83,78,1,1],"solid":"low","facing":2,"note":"장보기 수레","level":0},
		{"kind":"shopping_cart","rect":[86,78,1,1],"solid":"low","facing":3,"note":"장보기 수레","level":0},
		{"kind":"shopping_cart","rect":[109,78,1,1],"solid":"low","facing":0,"note":"장보기 수레","level":0},
		{"kind":"shopping_cart","rect":[112,78,1,1],"solid":"low","facing":1,"note":"장보기 수레","level":0},
		{"kind":"shopping_cart","rect":[115,78,1,1],"solid":"low","facing":2,"note":"장보기 수레","level":0},
		{"kind":"shopping_cart","rect":[118,78,1,1],"solid":"low","facing":3,"note":"장보기 수레","level":0},
		{"kind":"dock_door","rect":[77,38,4,1],"solid":"none","facing":0,"note":"평평한 하역 문","level":0},
		{"kind":"dock_plate","rect":[77,29,4,3],"solid":"none","facing":1,"note":"하역 평판","level":0},
		{"kind":"pallet_stack","rect":[72,31,2,2],"solid":"low","facing":2,"note":"팰릿 더미","level":0},
		{"kind":"dock_door","rect":[97,38,4,1],"solid":"none","facing":3,"note":"평평한 하역 문","level":0},
		{"kind":"dock_plate","rect":[97,29,4,3],"solid":"none","facing":0,"note":"하역 평판","level":0},
		{"kind":"pallet_stack","rect":[92,31,2,2],"solid":"low","facing":1,"note":"팰릿 더미","level":0},
		{"kind":"dock_door","rect":[117,38,4,1],"solid":"none","facing":2,"note":"평평한 하역 문","level":0},
		{"kind":"dock_plate","rect":[117,29,4,3],"solid":"none","facing":3,"note":"하역 평판","level":0},
		{"kind":"pallet_stack","rect":[112,31,2,2],"solid":"low","facing":0,"note":"팰릿 더미","level":0},
		{"kind":"fuel_pump","rect":[18,40,1,2],"solid":"low","facing":1,"note":"주유기","level":0},
		{"kind":"fuel_pump","rect":[22,40,1,2],"solid":"low","facing":2,"note":"주유기","level":0},
		{"kind":"fuel_pump","rect":[26,40,1,2],"solid":"low","facing":3,"note":"주유기","level":0},
		{"kind":"forklift","rect":[126,31,3,2],"solid":"wall","facing":0,"note":"지게차","level":0},
		{"kind":"lamp_post","rect":[74,87,1,1],"solid":"none","facing":1,"note":"꺼진 등잔","level":0},
		{"kind":"crate_stack","rect":[75,89,2,2],"solid":"low","facing":2,"note":"나무 상자 더미","level":0},
		{"kind":"lamp_post","rect":[148,28,1,1],"solid":"none","facing":3,"note":"꺼진 등잔","level":0},
		{"kind":"crate_stack","rect":[149,30,2,2],"solid":"low","facing":0,"note":"나무 상자 더미","level":0},
		{"kind":"lamp_post","rect":[132,95,1,1],"solid":"none","facing":1,"note":"꺼진 등잔","level":0},
		{"kind":"crate_stack","rect":[133,97,2,2],"solid":"low","facing":2,"note":"나무 상자 더미","level":0},
		{"kind":"street_tree","rect":[96,12,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[43,13,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[97,18,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[102,19,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[83,21,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[112,21,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[59,22,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[88,22,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[117,22,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[35,23,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[60,28,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[42,36,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[23,38,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[139,38,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[14,42,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[43,42,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[19,43,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[140,44,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[34,46,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[59,51,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[35,52,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[60,57,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[65,58,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[153,64,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[158,65,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[154,70,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[43,71,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[159,71,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[140,73,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[34,75,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[35,81,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[64,81,1,1],"solid":"tree","facing":2,"note":"가로수","level":0}],
	"containers": [{"id":"cache_0","name":"매장 상자","cell":[152,48],"level":0,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_1","name":"매장 상자","cell":[167,48],"level":0,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_2","name":"매장 상자","cell":[152,48],"level":1,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_3","name":"매장 상자","cell":[167,48],"level":1,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_4","name":"매장 상자","cell":[152,48],"level":2,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_5","name":"매장 상자","cell":[167,48],"level":2,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_6","name":"부엌 상자","cell":[147,18],"level":0,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_7","name":"안방 상자","cell":[155,18],"level":0,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_8","name":"부엌 상자","cell":[147,26],"level":0,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_9","name":"안방 상자","cell":[155,26],"level":0,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_10","name":"부엌 상자","cell":[167,18],"level":0,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_11","name":"안방 상자","cell":[175,18],"level":0,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_12","name":"부엌 상자","cell":[167,26],"level":0,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_13","name":"안방 상자","cell":[175,26],"level":0,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_14","name":"부엌 상자","cell":[147,18],"level":1,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_15","name":"안방 상자","cell":[155,18],"level":1,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_16","name":"부엌 상자","cell":[147,26],"level":1,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_17","name":"안방 상자","cell":[155,26],"level":1,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_18","name":"부엌 상자","cell":[167,18],"level":1,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_19","name":"안방 상자","cell":[175,18],"level":1,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_20","name":"부엌 상자","cell":[167,26],"level":1,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_21","name":"안방 상자","cell":[175,26],"level":1,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_22","name":"부엌 상자","cell":[147,18],"level":2,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_23","name":"안방 상자","cell":[155,18],"level":2,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_24","name":"부엌 상자","cell":[147,26],"level":2,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_25","name":"안방 상자","cell":[155,26],"level":2,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_26","name":"부엌 상자","cell":[167,18],"level":2,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_27","name":"안방 상자","cell":[175,18],"level":2,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_28","name":"부엌 상자","cell":[167,26],"level":2,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_29","name":"안방 상자","cell":[175,26],"level":2,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_30","name":"부엌 상자","cell":[146,90],"level":0,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_31","name":"안방 상자","cell":[153,90],"level":0,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_32","name":"부엌 상자","cell":[165,90],"level":0,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_33","name":"안방 상자","cell":[172,90],"level":0,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_34","name":"부엌 상자","cell":[146,90],"level":1,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_35","name":"안방 상자","cell":[153,90],"level":1,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_36","name":"부엌 상자","cell":[165,90],"level":1,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_37","name":"안방 상자","cell":[172,90],"level":1,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_38","name":"부엌 상자","cell":[146,90],"level":2,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_39","name":"안방 상자","cell":[153,90],"level":2,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_40","name":"부엌 상자","cell":[165,90],"level":2,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_41","name":"안방 상자","cell":[172,90],"level":2,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_42","name":"작업실 상자","cell":[19,36],"level":0,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_43","name":"뒤 창고 상자","cell":[24,36],"level":0,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_44","name":"매장 상자","cell":[8,81],"level":0,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_45","name":"뒤 창고 상자","cell":[16,81],"level":0,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_46","name":"작업실 상자","cell":[28,80],"level":0,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_47","name":"먼 끝 저장 상자","cell":[9,94],"level":0,"building":5,"search":4,"items":["food_pack","food_pack","food_pack","food_pack"],"locked":true,"searched":false},
		{"id":"cache_48","name":"뒤 창고 상자","cell":[17,94],"level":0,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_49","name":"작업실 상자","cell":[25,94],"level":0,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_50","name":"작업실 상자","cell":[49,20],"level":0,"building":6,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_51","name":"뒤 창고 상자","cell":[56,20],"level":0,"building":6,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_52","name":"작업실 상자","cell":[59,89],"level":0,"building":7,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_53","name":"뒤 창고 상자","cell":[62,89],"level":0,"building":7,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_54","name":"작업실 상자","cell":[50,36],"level":0,"building":8,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_55","name":"뒤 창고 상자","cell":[55,36],"level":0,"building":8,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_56","name":"작업실 상자","cell":[27,18],"level":0,"building":9,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_57","name":"작업실 상자","cell":[149,60],"level":0,"building":10,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_58","name":"뒤 창고 상자","cell":[156,60],"level":0,"building":10,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_59","name":"매장 상자","cell":[5,18],"level":0,"building":11,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_60","name":"매장 상자","cell":[12,18],"level":0,"building":11,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_61","name":"작업실 상자","cell":[47,49],"level":0,"building":12,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_62","name":"뒤 창고 상자","cell":[54,49],"level":0,"building":12,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_63","name":"작업실 상자","cell":[47,66],"level":0,"building":13,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_64","name":"뒤 창고 상자","cell":[54,66],"level":0,"building":13,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_65","name":"뒤 창고 상자","cell":[60,66],"level":0,"building":13,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_66","name":"매장 상자","cell":[12,47],"level":0,"building":14,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_67","name":"뒤 창고 상자","cell":[23,47],"level":0,"building":14,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_68","name":"매장 상자","cell":[12,54],"level":0,"building":14,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_69","name":"뒤 창고 상자","cell":[23,54],"level":0,"building":14,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_70","name":"매장 상자","cell":[14,47],"level":1,"building":14,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_71","name":"뒤 창고 상자","cell":[25,47],"level":1,"building":14,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_72","name":"매장 상자","cell":[14,54],"level":1,"building":14,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_73","name":"뒤 창고 상자","cell":[25,54],"level":1,"building":14,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_74","name":"작업실 상자","cell":[147,102],"level":0,"building":15,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_75","name":"뒤 창고 상자","cell":[153,102],"level":0,"building":15,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_76","name":"뒤 창고 상자","cell":[159,102],"level":0,"building":15,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_77","name":"뒤 창고 상자","cell":[165,102],"level":0,"building":15,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_78","name":"뒤 창고 상자","cell":[170,102],"level":0,"building":15,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_79","name":"작업실 상자","cell":[147,102],"level":1,"building":15,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_80","name":"뒤 창고 상자","cell":[153,102],"level":1,"building":15,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_81","name":"뒤 창고 상자","cell":[159,102],"level":1,"building":15,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_82","name":"뒤 창고 상자","cell":[165,102],"level":1,"building":15,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_83","name":"뒤 창고 상자","cell":[170,102],"level":1,"building":15,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_84","name":"하역 안쪽 칸 상자","cell":[86,41],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_85","name":"뒤 창고 상자","cell":[86,48],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_86","name":"하역 안쪽 칸 상자","cell":[107,41],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_87","name":"뒤 창고 상자","cell":[107,48],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_88","name":"하역 안쪽 칸 상자","cell":[130,41],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_89","name":"냉동 창고 상자","cell":[130,48],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_90","name":"냉장 구역 상자","cell":[76,63],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_91","name":"빵 구역 상자","cell":[130,63],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_92","name":"사무실 상자","cell":[76,74],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_93","name":"판매장 상자","cell":[120,68],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_94","name":"계산대 구역 상자","cell":[129,74],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_95","name":"부엌 상자","cell":[79,44],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_96","name":"안방 상자","cell":[79,52],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_97","name":"부엌 상자","cell":[90,44],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_98","name":"안방 상자","cell":[90,52],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_99","name":"부엌 상자","cell":[101,44],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_100","name":"안방 상자","cell":[101,52],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_101","name":"부엌 상자","cell":[111,44],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_102","name":"안방 상자","cell":[110,52],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_103","name":"부엌 상자","cell":[121,44],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_104","name":"안방 상자","cell":[121,52],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_105","name":"부엌 상자","cell":[131,44],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_106","name":"안방 상자","cell":[131,52],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_107","name":"부엌 상자","cell":[79,66],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_108","name":"안쪽 저장 상자","cell":[79,74],"level":-1,"building":0,"search":4,"items":["food_pack","food_pack","food_pack","food_pack"],"locked":true,"searched":false},
		{"id":"cache_109","name":"부엌 상자","cell":[90,66],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_110","name":"안방 상자","cell":[90,74],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_111","name":"부엌 상자","cell":[101,66],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_112","name":"안방 상자","cell":[101,74],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_113","name":"부엌 상자","cell":[111,66],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_114","name":"안방 상자","cell":[111,74],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_115","name":"부엌 상자","cell":[121,66],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_116","name":"안방 상자","cell":[121,74],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_117","name":"부엌 상자","cell":[131,66],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_118","name":"안방 상자","cell":[131,74],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false}],
	"spots": [{"id":"salvage_0","kind":"salvage","name":"포장 나무","cell":[152,48],"material":"wood","amount":2,"state":"intact"},
		{"id":"salvage_1","kind":"salvage","name":"포장 나무","cell":[167,48],"material":"wood","amount":2,"state":"intact"}],
	"slots": ["E","G"],
	"dead": [[179,1],[0,90],[36,104],[100,104],[179,66],[72,88],[146,29],[130,96],[140,60]],
	"forecourts": [{"cell":[157,34],"normal":[0,-1],"cells":[[155,33],[156,33],[157,33],[158,33],[159,33],[155,32],[156,32],[157,32],[158,32],[159,32],[155,31],[156,31],[157,31],[158,31],[159,31],[155,30],[156,30],[157,30],[158,30],[159,30]],"building":1},
		{"cell":[157,49],"normal":[0,1],"cells":[[159,50],[158,50],[157,50],[156,50],[155,50],[159,51],[158,51],[157,51],[156,51],[155,51],[159,52],[158,52],[157,52],[156,52],[155,52],[159,53],[158,53],[157,53],[156,53],[155,53]],"building":1},
		{"cell":[158,10],"normal":[0,-1],"cells":[[156,9],[157,9],[158,9],[159,9],[160,9],[156,8],[157,8],[158,8],[159,8],[160,8],[156,7],[157,7],[158,7],[159,7],[160,7],[156,6],[157,6],[158,6],[159,6],[160,6]],"building":2},
		{"cell":[158,27],"normal":[0,1],"cells":[[160,28],[159,28],[158,28],[157,28],[156,28],[160,29],[159,29],[158,29],[157,29],[156,29],[160,30],[159,30],[158,30],[157,30],[156,30],[160,31],[159,31],[158,31],[157,31],[156,31]],"building":2},
		{"cell":[157,76],"normal":[0,-1],"cells":[[155,75],[156,75],[157,75],[158,75],[159,75],[155,74],[156,74],[157,74],[158,74],[159,74],[155,73],[156,73],[157,73],[158,73],[159,73],[155,72],[156,72],[157,72],[158,72],[159,72]],"building":3},
		{"cell":[157,91],"normal":[0,1],"cells":[[159,92],[158,92],[157,92],[156,92],[155,92],[159,93],[158,93],[157,93],[156,93],[155,93],[159,94],[158,94],[157,94],[156,94],[155,94],[159,95],[158,95],[157,95],[156,95],[155,95]],"building":3},
		{"cell":[16,33],"normal":[-1,0],"cells":[[15,35],[15,34],[15,33],[15,32],[15,31],[14,35],[14,34],[14,33],[14,32],[14,31],[13,35],[13,34],[13,33],[13,32],[13,31],[12,35],[12,34],[12,33],[12,32],[12,31]],"building":4},
		{"cell":[29,33],"normal":[1,0],"cells":[[30,31],[30,32],[30,33],[30,34],[30,35],[31,31],[31,32],[31,33],[31,34],[31,35],[32,31],[32,32],[32,33],[32,34],[32,35],[33,31],[33,32],[33,33],[33,34],[33,35]],"building":4},
		{"cell":[4,83],"normal":[-1,0],"cells":[[3,85],[3,84],[3,83],[3,82],[3,81],[2,85],[2,84],[2,83],[2,82],[2,81],[1,85],[1,84],[1,83],[1,82],[1,81],[0,85],[0,84],[0,83],[0,82],[0,81]],"building":5},
		{"cell":[29,83],"normal":[1,0],"cells":[[30,81],[30,82],[30,83],[30,84],[30,85],[31,81],[31,82],[31,83],[31,84],[31,85],[32,81],[32,82],[32,83],[32,84],[32,85],[33,81],[33,82],[33,83],[33,84],[33,85]],"building":5},
		{"cell":[44,17],"normal":[-1,0],"cells":[[43,19],[43,18],[43,17],[43,16],[43,15],[42,19],[42,18],[42,17],[42,16],[42,15],[41,19],[41,18],[41,17],[41,16],[41,15],[40,19],[40,18],[40,17],[40,16],[40,15]],"building":6},
		{"cell":[59,17],"normal":[1,0],"cells":[[60,15],[60,16],[60,17],[60,18],[60,19],[61,15],[61,16],[61,17],[61,18],[61,19],[62,15],[62,16],[62,17],[62,18],[62,19],[63,15],[63,16],[63,17],[63,18],[63,19]],"building":6},
		{"cell":[54,88],"normal":[-1,0],"cells":[[53,90],[53,89],[53,88],[53,87],[53,86],[52,90],[52,89],[52,88],[52,87],[52,86],[51,90],[51,89],[51,88],[51,87],[51,86],[50,90],[50,89],[50,88],[50,87],[50,86]],"building":7},
		{"cell":[65,88],"normal":[1,0],"cells":[[66,86],[66,87],[66,88],[66,89],[66,90],[67,86],[67,87],[67,88],[67,89],[67,90],[68,86],[68,87],[68,88],[68,89],[68,90],[69,86],[69,87],[69,88],[69,89],[69,90]],"building":7},
		{"cell":[44,33],"normal":[-1,0],"cells":[[43,35],[43,34],[43,33],[43,32],[43,31],[42,35],[42,34],[42,33],[42,32],[42,31],[41,35],[41,34],[41,33],[41,32],[41,31],[40,35],[40,34],[40,33],[40,32],[40,31]],"building":8},
		{"cell":[59,33],"normal":[1,0],"cells":[[60,31],[60,32],[60,33],[60,34],[60,35],[61,31],[61,32],[61,33],[61,34],[61,35],[62,31],[62,32],[62,33],[62,34],[62,35],[63,31],[63,32],[63,33],[63,34],[63,35]],"building":8},
		{"cell":[24,16],"normal":[-1,0],"cells":[[23,18],[23,17],[23,16],[23,15],[23,14],[22,18],[22,17],[22,16],[22,15],[22,14],[21,18],[21,17],[21,16],[21,15],[21,14],[20,18],[20,17],[20,16],[20,15],[20,14]],"building":9},
		{"cell":[31,16],"normal":[1,0],"cells":[[32,14],[32,15],[32,16],[32,17],[32,18],[33,14],[33,15],[33,16],[33,17],[33,18],[34,14],[34,15],[34,16],[34,17],[34,18],[35,14],[35,15],[35,16],[35,17],[35,18]],"building":9},
		{"cell":[146,59],"normal":[-1,0],"cells":[[145,61],[145,60],[145,59],[145,58],[145,57],[144,61],[144,60],[144,59],[144,58],[144,57],[143,61],[143,60],[143,59],[143,58],[143,57],[142,61],[142,60],[142,59],[142,58],[142,57]],"building":10},
		{"cell":[157,59],"normal":[1,0],"cells":[[158,57],[158,58],[158,59],[158,60],[158,61],[159,57],[159,58],[159,59],[159,60],[159,61],[160,57],[160,58],[160,59],[160,60],[160,61],[161,57],[161,58],[161,59],[161,60],[161,61]],"building":10},
		{"cell":[7,12],"normal":[0,-1],"cells":[[5,11],[6,11],[7,11],[8,11],[9,11],[5,10],[6,10],[7,10],[8,10],[9,10],[5,9],[6,9],[7,9],[8,9],[9,9],[5,8],[6,8],[7,8],[8,8],[9,8]],"building":11},
		{"cell":[7,19],"normal":[0,1],"cells":[[9,20],[8,20],[7,20],[6,20],[5,20],[9,21],[8,21],[7,21],[6,21],[5,21],[9,22],[8,22],[7,22],[6,22],[5,22],[9,23],[8,23],[7,23],[6,23],[5,23]],"building":11},
		{"cell":[44,48],"normal":[-1,0],"cells":[[43,50],[43,49],[43,48],[43,47],[43,46],[42,50],[42,49],[42,48],[42,47],[42,46],[41,50],[41,49],[41,48],[41,47],[41,46],[40,50],[40,49],[40,48],[40,47],[40,46]],"building":12},
		{"cell":[55,48],"normal":[1,0],"cells":[[56,46],[56,47],[56,48],[56,49],[56,50],[57,46],[57,47],[57,48],[57,49],[57,50],[58,46],[58,47],[58,48],[58,49],[58,50],[59,46],[59,47],[59,48],[59,49],[59,50]],"building":12},
		{"cell":[44,63],"normal":[-1,0],"cells":[[43,65],[43,64],[43,63],[43,62],[43,61],[42,65],[42,64],[42,63],[42,62],[42,61],[41,65],[41,64],[41,63],[41,62],[41,61],[40,65],[40,64],[40,63],[40,62],[40,61]],"building":13},
		{"cell":[63,63],"normal":[1,0],"cells":[[64,61],[64,62],[64,63],[64,64],[64,65],[65,61],[65,62],[65,63],[65,64],[65,65],[66,61],[66,62],[66,63],[66,64],[66,65],[67,61],[67,62],[67,63],[67,64],[67,65]],"building":13},
		{"cell":[4,49],"normal":[-1,0],"cells":[[3,51],[3,50],[3,49],[3,48],[3,47],[2,51],[2,50],[2,49],[2,48],[2,47],[1,51],[1,50],[1,49],[1,48],[1,47],[0,51],[0,50],[0,49],[0,48],[0,47]],"building":14},
		{"cell":[27,49],"normal":[1,0],"cells":[[28,47],[28,48],[28,49],[28,50],[28,51],[29,47],[29,48],[29,49],[29,50],[29,51],[30,47],[30,48],[30,49],[30,50],[30,51],[31,47],[31,48],[31,49],[31,50],[31,51]],"building":14},
		{"cell":[144,100],"normal":[-1,0],"cells":[[143,102],[143,101],[143,100],[143,99],[143,98],[142,102],[142,101],[142,100],[142,99],[142,98],[141,102],[141,101],[141,100],[141,99],[141,98],[140,102],[140,101],[140,100],[140,99],[140,98]],"building":15},
		{"cell":[173,100],"normal":[1,0],"cells":[[174,98],[174,99],[174,100],[174,101],[174,102],[175,98],[175,99],[175,100],[175,101],[175,102],[176,98],[176,99],[176,100],[176,101],[176,102],[177,98],[177,99],[177,100],[177,101],[177,102]],"building":15},
		{"cell":[78,36],"normal":[0,-1],"cells":[[76,35],[77,35],[78,35],[79,35],[80,35],[76,34],[77,34],[78,34],[79,34],[80,34],[76,33],[77,33],[78,33],[79,33],[80,33],[76,32],[77,32],[78,32],[79,32],[80,32]],"building":0},
		{"cell":[98,36],"normal":[0,-1],"cells":[[96,35],[97,35],[98,35],[99,35],[100,35],[96,34],[97,34],[98,34],[99,34],[100,34],[96,33],[97,33],[98,33],[99,33],[100,33],[96,32],[97,32],[98,32],[99,32],[100,32]],"building":0},
		{"cell":[118,36],"normal":[0,-1],"cells":[[116,35],[117,35],[118,35],[119,35],[120,35],[116,34],[117,34],[118,34],[119,34],[120,34],[116,33],[117,33],[118,33],[119,33],[120,33],[116,32],[117,32],[118,32],[119,32],[120,32]],"building":0},
		{"cell":[94,75],"normal":[0,1],"cells":[[96,76],[95,76],[94,76],[93,76],[92,76],[96,77],[95,77],[94,77],[93,77],[92,77],[96,78],[95,78],[94,78],[93,78],[92,78],[96,79],[95,79],[94,79],[93,79],[92,79]],"building":0},
		{"cell":[96,75],"normal":[0,1],"cells":[[98,76],[97,76],[96,76],[95,76],[94,76],[98,77],[97,77],[96,77],[95,77],[94,77],[98,78],[97,78],[96,78],[95,78],[94,78],[98,79],[97,79],[96,79],[95,79],[94,79]],"building":0},
		{"cell":[98,75],"normal":[0,1],"cells":[[100,76],[99,76],[98,76],[97,76],[96,76],[100,77],[99,77],[98,77],[97,77],[96,77],[100,78],[99,78],[98,78],[97,78],[96,78],[100,79],[99,79],[98,79],[97,79],[96,79]],"building":0},
		{"cell":[100,75],"normal":[0,1],"cells":[[102,76],[101,76],[100,76],[99,76],[98,76],[102,77],[101,77],[100,77],[99,77],[98,77],[102,78],[101,78],[100,78],[99,78],[98,78],[102,79],[101,79],[100,79],[99,79],[98,79]],"building":0},
		{"cell":[102,75],"normal":[0,1],"cells":[[104,76],[103,76],[102,76],[101,76],[100,76],[104,77],[103,77],[102,77],[101,77],[100,77],[104,78],[103,78],[102,78],[101,78],[100,78],[104,79],[103,79],[102,79],[101,79],[100,79]],"building":0},
		{"cell":[104,75],"normal":[0,1],"cells":[[106,76],[105,76],[104,76],[103,76],[102,76],[106,77],[105,77],[104,77],[103,77],[102,77],[106,78],[105,78],[104,78],[103,78],[102,78],[106,79],[105,79],[104,79],[103,79],[102,79]],"building":0}],
	"logs": ["snow_drifts_0"],
	"deep": [{"cell":[79,74],"level":-1,"id":"cache_108","distance":140},
		{"cell":[9,94],"level":0,"id":"cache_47","distance":119}]
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
	"number": 5,
	"width": 180,
	"height": 46,
	"judgment": "목재가 가장 많이 쌓인 곳을 얻는 대신, 하치장 평판이 트인 땅이라 가장 많이 얻는 자리가 가장 드러난다.",
	"zones": [
		{
			"id": "I",
			"name": "자재 작업 구역",
			"rect": [
				0,
				0,
				105,
				46
			]
		},
		{
			"id": "J",
			"name": "동쪽 하치장",
			"rect": [
				105,
				0,
				75,
				46
			]
		}
	],
	"grounds": [
		{
			"rect": [
				0,
				6,
				117,
				6
			],
			"floor": 1
		},
		{
			"rect": [
				116,
				2,
				23,
				5
			],
			"floor": 1
		},
		{
			"rect": [
				116,
				14,
				23,
				5
			],
			"floor": 1
		},
		{
			"rect": [
				116,
				2,
				5,
				17
			],
			"floor": 1
		},
		{
			"rect": [
				134,
				2,
				5,
				17
			],
			"floor": 1
		},
		{
			"rect": [
				150,
				0,
				4,
				46
			],
			"floor": 1
		},
		{
			"rect": [
				154,
				18,
				26,
				4
			],
			"floor": 1
		},
		{
			"rect": [
				105,
				19,
				45,
				27
			],
			"floor": 7
		},
		{
			"rect": [
				40,
				12,
				6,
				31
			],
			"floor": 1
		},
		{
			"rect": [
				88,
				12,
				5,
				31
			],
			"floor": 1
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
			"name": "자재 창고",
			"rect": [
				0,
				13,
				40,
				11
			],
			"top": 2,
			"basement": false,
			"role": "store",
			"stock": [
				"lumber_stack",
				"parts_rack",
				"shelf",
				"crate_stack"
			]
		},
		{
			"id": 17,
			"name": "목공 작업장",
			"rect": [
				46,
				14,
				18,
				10
			],
			"top": 2,
			"basement": false,
			"role": "store",
			"stock": [
				"door_pile",
				"desk",
				"firewood_pile"
			]
		},
		{
			"id": 18,
			"name": "지게차 차고",
			"rect": [
				64,
				15,
				12,
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
			"id": 19,
			"name": "살림집",
			"rect": [
				76,
				12,
				12,
				12
			],
			"top": 2,
			"basement": false,
			"role": "home",
			"stock": [
				"lumber_stack",
				"parts_rack",
				"shelf",
				"crate_stack"
			]
		},
		{
			"id": 20,
			"name": "자재 사무 집",
			"rect": [
				93,
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
				"parts_rack"
			]
		},
		{
			"id": 21,
			"name": "고리 섬 관리 집",
			"rect": [
				123,
				8,
				10,
				6
			],
			"top": 1,
			"basement": false,
			"role": "home",
			"stock": [
				"lumber_stack",
				"parts_rack",
				"shelf",
				"crate_stack"
			]
		},
		{
			"id": 22,
			"name": "건조 헛간",
			"rect": [
				156,
				28,
				24,
				10
			],
			"top": 1,
			"basement": false,
			"role": "store",
			"stock": [
				"lumber_stack",
				"pallet_stack",
				"barrel"
			]
		},
		{
			"id": 23,
			"name": "자재 사무동",
			"rect": [
				158,
				0,
				20,
				11
			],
			"top": 3,
			"basement": true,
			"role": "store",
			"stock": [
				"hardware_rack",
				"office_cabinet",
				"desk"
			]
		}
	],
	"shells": [
		{
			"rect": [
				0,
				13,
				40,
				11
			],
			"building": 16,
			"level": 0
		},
		{
			"rect": [
				0,
				13,
				40,
				11
			],
			"building": 16,
			"level": 1
		},
		{
			"rect": [
				46,
				14,
				18,
				10
			],
			"building": 17,
			"level": 0
		},
		{
			"rect": [
				46,
				14,
				18,
				10
			],
			"building": 17,
			"level": 1
		},
		{
			"rect": [
				64,
				15,
				12,
				9
			],
			"building": 18,
			"level": 0
		},
		{
			"rect": [
				76,
				12,
				12,
				12
			],
			"building": 19,
			"level": 0
		},
		{
			"rect": [
				76,
				12,
				12,
				12
			],
			"building": 19,
			"level": 1
		},
		{
			"rect": [
				93,
				15,
				12,
				9
			],
			"building": 20,
			"level": 0
		},
		{
			"rect": [
				123,
				8,
				10,
				6
			],
			"building": 21,
			"level": 0
		},
		{
			"rect": [
				156,
				28,
				24,
				10
			],
			"building": 22,
			"level": 0
		},
		{
			"rect": [
				158,
				0,
				20,
				11
			],
			"building": 23,
			"level": -1
		},
		{
			"rect": [
				158,
				0,
				20,
				11
			],
			"building": 23,
			"level": 0
		},
		{
			"rect": [
				158,
				0,
				20,
				11
			],
			"building": 23,
			"level": 1
		},
		{
			"rect": [
				158,
				0,
				20,
				11
			],
			"building": 23,
			"level": 2
		}
	],
	"walls": [
		{
			"rect": [
				1,
				20,
				38,
				1
			],
			"level": 0
		},
		{
			"rect": [
				7,
				14,
				1,
				6
			],
			"level": 0
		},
		{
			"rect": [
				14,
				14,
				1,
				6
			],
			"level": 0
		},
		{
			"rect": [
				21,
				14,
				1,
				6
			],
			"level": 0
		},
		{
			"rect": [
				27,
				14,
				1,
				6
			],
			"level": 0
		},
		{
			"rect": [
				33,
				14,
				1,
				6
			],
			"level": 0
		},
		{
			"rect": [
				1,
				20,
				38,
				1
			],
			"level": 1
		},
		{
			"rect": [
				7,
				14,
				1,
				6
			],
			"level": 1
		},
		{
			"rect": [
				14,
				14,
				1,
				6
			],
			"level": 1
		},
		{
			"rect": [
				21,
				14,
				1,
				6
			],
			"level": 1
		},
		{
			"rect": [
				27,
				14,
				1,
				6
			],
			"level": 1
		},
		{
			"rect": [
				33,
				14,
				1,
				6
			],
			"level": 1
		},
		{
			"rect": [
				47,
				20,
				16,
				1
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
				47,
				20,
				16,
				1
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
				65,
				20,
				10,
				1
			],
			"level": 0
		},
		{
			"rect": [
				70,
				16,
				1,
				4
			],
			"level": 0
		},
		{
			"rect": [
				77,
				20,
				10,
				1
			],
			"level": 0
		},
		{
			"rect": [
				82,
				13,
				1,
				7
			],
			"level": 0
		},
		{
			"rect": [
				77,
				20,
				10,
				1
			],
			"level": 1
		},
		{
			"rect": [
				82,
				13,
				1,
				7
			],
			"level": 1
		},
		{
			"rect": [
				94,
				20,
				10,
				1
			],
			"level": 0
		},
		{
			"rect": [
				99,
				16,
				1,
				4
			],
			"level": 0
		},
		{
			"rect": [
				128,
				9,
				1,
				4
			],
			"level": 0
		},
		{
			"rect": [
				157,
				34,
				22,
				1
			],
			"level": 0
		},
		{
			"rect": [
				164,
				29,
				1,
				5
			],
			"level": 0
		},
		{
			"rect": [
				172,
				29,
				1,
				5
			],
			"level": 0
		},
		{
			"rect": [
				159,
				7,
				18,
				1
			],
			"level": -1
		},
		{
			"rect": [
				168,
				1,
				1,
				6
			],
			"level": -1
		},
		{
			"rect": [
				159,
				7,
				18,
				1
			],
			"level": 0
		},
		{
			"rect": [
				168,
				1,
				1,
				6
			],
			"level": 0
		},
		{
			"rect": [
				159,
				7,
				18,
				1
			],
			"level": 1
		},
		{
			"rect": [
				168,
				1,
				1,
				6
			],
			"level": 1
		},
		{
			"rect": [
				159,
				7,
				18,
				1
			],
			"level": 2
		},
		{
			"rect": [
				168,
				1,
				1,
				6
			],
			"level": 2
		}
	],
	"doors": [
		{
			"cell": [
				4,
				20
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				11,
				20
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				18,
				20
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				24,
				20
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				30,
				20
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				36,
				20
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				20,
				23
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				4,
				20
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				11,
				20
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				18,
				20
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				24,
				20
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				30,
				20
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				36,
				20
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				51,
				20
			],
			"level": 0,
			"building": 17,
			"state": "closed"
		},
		{
			"cell": [
				59,
				20
			],
			"level": 0,
			"building": 17,
			"state": "closed"
		},
		{
			"cell": [
				55,
				23
			],
			"level": 0,
			"building": 17,
			"state": "closed"
		},
		{
			"cell": [
				51,
				20
			],
			"level": 1,
			"building": 17,
			"state": "closed"
		},
		{
			"cell": [
				59,
				20
			],
			"level": 1,
			"building": 17,
			"state": "closed"
		},
		{
			"cell": [
				67,
				20
			],
			"level": 0,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				73,
				20
			],
			"level": 0,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				70,
				23
			],
			"level": 0,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				79,
				20
			],
			"level": 0,
			"building": 19,
			"state": "closed"
		},
		{
			"cell": [
				85,
				20
			],
			"level": 0,
			"building": 19,
			"state": "closed"
		},
		{
			"cell": [
				82,
				23
			],
			"level": 0,
			"building": 19,
			"state": "closed"
		},
		{
			"cell": [
				79,
				20
			],
			"level": 1,
			"building": 19,
			"state": "closed"
		},
		{
			"cell": [
				85,
				20
			],
			"level": 1,
			"building": 19,
			"state": "closed"
		},
		{
			"cell": [
				96,
				20
			],
			"level": 0,
			"building": 20,
			"state": "closed"
		},
		{
			"cell": [
				102,
				20
			],
			"level": 0,
			"building": 20,
			"state": "closed"
		},
		{
			"cell": [
				99,
				23
			],
			"level": 0,
			"building": 20,
			"state": "closed"
		},
		{
			"cell": [
				128,
				11
			],
			"level": 0,
			"building": 21,
			"state": "closed"
		},
		{
			"cell": [
				125,
				13
			],
			"level": 0,
			"building": 21,
			"state": "closed"
		},
		{
			"cell": [
				160,
				34
			],
			"level": 0,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				168,
				34
			],
			"level": 0,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				176,
				34
			],
			"level": 0,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				168,
				37
			],
			"level": 0,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				163,
				7
			],
			"level": -1,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				173,
				7
			],
			"level": -1,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				163,
				7
			],
			"level": 0,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				173,
				7
			],
			"level": 0,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				168,
				10
			],
			"level": 0,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				163,
				7
			],
			"level": 1,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				173,
				7
			],
			"level": 1,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				163,
				7
			],
			"level": 2,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				173,
				7
			],
			"level": 2,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				4,
				13
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		}
	],
	"windows": [
		{
			"cell": [
				11,
				13
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				18,
				13
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				24,
				13
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				30,
				13
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				36,
				13
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				51,
				14
			],
			"level": 0,
			"building": 17
		},
		{
			"cell": [
				59,
				14
			],
			"level": 0,
			"building": 17
		},
		{
			"cell": [
				67,
				15
			],
			"level": 0,
			"building": 18
		},
		{
			"cell": [
				73,
				15
			],
			"level": 0,
			"building": 18
		},
		{
			"cell": [
				79,
				12
			],
			"level": 0,
			"building": 19
		},
		{
			"cell": [
				85,
				12
			],
			"level": 0,
			"building": 19
		},
		{
			"cell": [
				96,
				15
			],
			"level": 0,
			"building": 20
		},
		{
			"cell": [
				102,
				15
			],
			"level": 0,
			"building": 20
		},
		{
			"cell": [
				126,
				8
			],
			"level": 0,
			"building": 21
		},
		{
			"cell": [
				130,
				8
			],
			"level": 0,
			"building": 21
		},
		{
			"cell": [
				160,
				28
			],
			"level": 0,
			"building": 22
		},
		{
			"cell": [
				168,
				28
			],
			"level": 0,
			"building": 22
		},
		{
			"cell": [
				176,
				28
			],
			"level": 0,
			"building": 22
		},
		{
			"cell": [
				163,
				0
			],
			"level": 0,
			"building": 23
		},
		{
			"cell": [
				173,
				0
			],
			"level": 0,
			"building": 23
		}
	],
	"stairs": [
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
				37,
				21
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				48,
				21
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				78,
				21
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				160,
				8
			],
			"low": -1,
			"high": 0
		},
		{
			"cell": [
				160,
				8
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				160,
				8
			],
			"low": 1,
			"high": 2
		},
		{
			"cell": [
				175,
				8
			],
			"low": -1,
			"high": 0
		},
		{
			"cell": [
				175,
				8
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				175,
				8
			],
			"low": 1,
			"high": 2
		}
	],
	"rooms": [
		{
			"rect": [
				1,
				14,
				6,
				6
			],
			"building": 16,
			"level": 0,
			"use": "입고 방"
		},
		{
			"rect": [
				8,
				14,
				6,
				6
			],
			"building": 16,
			"level": 0,
			"use": "비축 방"
		},
		{
			"rect": [
				15,
				14,
				6,
				6
			],
			"building": 16,
			"level": 0,
			"use": "작업 방"
		},
		{
			"rect": [
				22,
				14,
				5,
				6
			],
			"building": 16,
			"level": 0,
			"use": "접수 방"
		},
		{
			"rect": [
				28,
				14,
				5,
				6
			],
			"building": 16,
			"level": 0,
			"use": "보관 방"
		},
		{
			"rect": [
				34,
				14,
				5,
				6
			],
			"building": 16,
			"level": 0,
			"use": "안쪽 광"
		},
		{
			"rect": [
				1,
				14,
				6,
				6
			],
			"building": 16,
			"level": 1,
			"use": "입고 방"
		},
		{
			"rect": [
				8,
				14,
				6,
				6
			],
			"building": 16,
			"level": 1,
			"use": "비축 방"
		},
		{
			"rect": [
				15,
				14,
				6,
				6
			],
			"building": 16,
			"level": 1,
			"use": "작업 방"
		},
		{
			"rect": [
				22,
				14,
				5,
				6
			],
			"building": 16,
			"level": 1,
			"use": "접수 방"
		},
		{
			"rect": [
				28,
				14,
				5,
				6
			],
			"building": 16,
			"level": 1,
			"use": "보관 방"
		},
		{
			"rect": [
				34,
				14,
				5,
				6
			],
			"building": 16,
			"level": 1,
			"use": "안쪽 광"
		},
		{
			"rect": [
				47,
				15,
				8,
				5
			],
			"building": 17,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				56,
				15,
				7,
				5
			],
			"building": 17,
			"level": 0,
			"use": "보관 칸"
		},
		{
			"rect": [
				47,
				15,
				8,
				5
			],
			"building": 17,
			"level": 1,
			"use": "작업 칸"
		},
		{
			"rect": [
				56,
				15,
				7,
				5
			],
			"building": 17,
			"level": 1,
			"use": "보관 칸"
		},
		{
			"rect": [
				65,
				16,
				5,
				4
			],
			"building": 18,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				71,
				16,
				4,
				4
			],
			"building": 18,
			"level": 0,
			"use": "보관 칸"
		},
		{
			"rect": [
				77,
				13,
				5,
				7
			],
			"building": 19,
			"level": 0,
			"use": "살림방"
		},
		{
			"rect": [
				83,
				13,
				4,
				7
			],
			"building": 19,
			"level": 0,
			"use": "부엌"
		},
		{
			"rect": [
				77,
				13,
				5,
				7
			],
			"building": 19,
			"level": 1,
			"use": "살림방"
		},
		{
			"rect": [
				83,
				13,
				4,
				7
			],
			"building": 19,
			"level": 1,
			"use": "부엌"
		},
		{
			"rect": [
				94,
				16,
				5,
				4
			],
			"building": 20,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				100,
				16,
				4,
				4
			],
			"building": 20,
			"level": 0,
			"use": "보관 칸"
		},
		{
			"rect": [
				124,
				9,
				4,
				4
			],
			"building": 21,
			"level": 0,
			"use": "살림방"
		},
		{
			"rect": [
				129,
				9,
				3,
				4
			],
			"building": 21,
			"level": 0,
			"use": "부엌"
		},
		{
			"rect": [
				157,
				29,
				7,
				5
			],
			"building": 22,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				165,
				29,
				7,
				5
			],
			"building": 22,
			"level": 0,
			"use": "보관 칸"
		},
		{
			"rect": [
				173,
				29,
				6,
				5
			],
			"building": 22,
			"level": 0,
			"use": "보관 칸"
		},
		{
			"rect": [
				159,
				1,
				9,
				6
			],
			"building": 23,
			"level": -1,
			"use": "작업 칸"
		},
		{
			"rect": [
				169,
				1,
				8,
				6
			],
			"building": 23,
			"level": -1,
			"use": "보관 칸"
		},
		{
			"rect": [
				159,
				1,
				9,
				6
			],
			"building": 23,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				169,
				1,
				8,
				6
			],
			"building": 23,
			"level": 0,
			"use": "보관 칸"
		},
		{
			"rect": [
				159,
				1,
				9,
				6
			],
			"building": 23,
			"level": 1,
			"use": "작업 칸"
		},
		{
			"rect": [
				169,
				1,
				8,
				6
			],
			"building": 23,
			"level": 1,
			"use": "보관 칸"
		},
		{
			"rect": [
				159,
				1,
				9,
				6
			],
			"building": 23,
			"level": 2,
			"use": "작업 칸"
		},
		{
			"rect": [
				169,
				1,
				8,
				6
			],
			"building": 23,
			"level": 2,
			"use": "보관 칸"
		}
	],
	"props": [
		{
			"kind": "parts_rack",
			"rect": [
				1,
				19,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 창고 입고 방의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "shelf",
			"rect": [
				1,
				18,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 창고 입고 방의 선반",
			"level": 0
		},
		{
			"kind": "lumber_stack",
			"rect": [
				8,
				14,
				4,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 창고 비축 방의 목재 더미",
			"level": 0
		},
		{
			"kind": "parts_rack",
			"rect": [
				8,
				19,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 창고 비축 방의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "shelf",
			"rect": [
				8,
				18,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 창고 비축 방의 선반",
			"level": 0
		},
		{
			"kind": "lumber_stack",
			"rect": [
				15,
				14,
				4,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 창고 작업 방의 목재 더미",
			"level": 0
		},
		{
			"kind": "parts_rack",
			"rect": [
				15,
				19,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 창고 작업 방의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "shelf",
			"rect": [
				15,
				18,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 창고 작업 방의 선반",
			"level": 0
		},
		{
			"kind": "lumber_stack",
			"rect": [
				22,
				14,
				4,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 창고 접수 방의 목재 더미",
			"level": 0
		},
		{
			"kind": "parts_rack",
			"rect": [
				22,
				16,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 창고 접수 방의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "crate_stack",
			"rect": [
				22,
				18,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 창고 접수 방의 나무 상자 더미",
			"level": 0
		},
		{
			"kind": "lumber_stack",
			"rect": [
				28,
				14,
				4,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 창고 보관 방의 목재 더미",
			"level": 0
		},
		{
			"kind": "parts_rack",
			"rect": [
				28,
				16,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 창고 보관 방의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "crate_stack",
			"rect": [
				28,
				18,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 창고 보관 방의 나무 상자 더미",
			"level": 0
		},
		{
			"kind": "lumber_stack",
			"rect": [
				34,
				14,
				4,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 창고 안쪽 광의 목재 더미",
			"level": 0
		},
		{
			"kind": "parts_rack",
			"rect": [
				34,
				16,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 창고 안쪽 광의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "crate_stack",
			"rect": [
				34,
				18,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 창고 안쪽 광의 나무 상자 더미",
			"level": 0
		},
		{
			"kind": "lumber_stack",
			"rect": [
				1,
				14,
				4,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 창고 입고 방의 목재 더미",
			"level": 1
		},
		{
			"kind": "parts_rack",
			"rect": [
				1,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 창고 입고 방의 부품 서랍 선반",
			"level": 1
		},
		{
			"kind": "shelf",
			"rect": [
				1,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 창고 입고 방의 선반",
			"level": 1
		},
		{
			"kind": "lumber_stack",
			"rect": [
				8,
				14,
				4,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 창고 비축 방의 목재 더미",
			"level": 1
		},
		{
			"kind": "parts_rack",
			"rect": [
				8,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 창고 비축 방의 부품 서랍 선반",
			"level": 1
		},
		{
			"kind": "shelf",
			"rect": [
				8,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 창고 비축 방의 선반",
			"level": 1
		},
		{
			"kind": "lumber_stack",
			"rect": [
				15,
				14,
				4,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 창고 작업 방의 목재 더미",
			"level": 1
		},
		{
			"kind": "parts_rack",
			"rect": [
				15,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 창고 작업 방의 부품 서랍 선반",
			"level": 1
		},
		{
			"kind": "shelf",
			"rect": [
				15,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 창고 작업 방의 선반",
			"level": 1
		},
		{
			"kind": "lumber_stack",
			"rect": [
				22,
				14,
				4,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 창고 접수 방의 목재 더미",
			"level": 1
		},
		{
			"kind": "parts_rack",
			"rect": [
				22,
				17,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 창고 접수 방의 부품 서랍 선반",
			"level": 1
		},
		{
			"kind": "shelf",
			"rect": [
				22,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 창고 접수 방의 선반",
			"level": 1
		},
		{
			"kind": "lumber_stack",
			"rect": [
				28,
				14,
				4,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 창고 보관 방의 목재 더미",
			"level": 1
		},
		{
			"kind": "parts_rack",
			"rect": [
				28,
				17,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 창고 보관 방의 부품 서랍 선반",
			"level": 1
		},
		{
			"kind": "shelf",
			"rect": [
				28,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 창고 보관 방의 선반",
			"level": 1
		},
		{
			"kind": "lumber_stack",
			"rect": [
				34,
				14,
				4,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 창고 안쪽 광의 목재 더미",
			"level": 1
		},
		{
			"kind": "parts_rack",
			"rect": [
				34,
				17,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 창고 안쪽 광의 부품 서랍 선반",
			"level": 1
		},
		{
			"kind": "shelf",
			"rect": [
				34,
				18,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 창고 안쪽 광의 선반",
			"level": 1
		},
		{
			"kind": "door_pile",
			"rect": [
				47,
				15,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "목공 작업장 작업 칸의 문짝 더미",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				47,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "목공 작업장 작업 칸의 책상",
			"level": 0
		},
		{
			"kind": "firewood_pile",
			"rect": [
				53,
				15,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "목공 작업장 작업 칸의 장작 더미",
			"level": 0
		},
		{
			"kind": "door_pile",
			"rect": [
				56,
				15,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "목공 작업장 보관 칸의 문짝 더미",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				56,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "목공 작업장 보관 칸의 책상",
			"level": 0
		},
		{
			"kind": "firewood_pile",
			"rect": [
				61,
				15,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "목공 작업장 보관 칸의 장작 더미",
			"level": 0
		},
		{
			"kind": "door_pile",
			"rect": [
				47,
				15,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "목공 작업장 작업 칸의 문짝 더미",
			"level": 1
		},
		{
			"kind": "desk",
			"rect": [
				47,
				19,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "목공 작업장 작업 칸의 책상",
			"level": 1
		},
		{
			"kind": "firewood_pile",
			"rect": [
				53,
				15,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "목공 작업장 작업 칸의 장작 더미",
			"level": 1
		},
		{
			"kind": "door_pile",
			"rect": [
				56,
				15,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "목공 작업장 보관 칸의 문짝 더미",
			"level": 1
		},
		{
			"kind": "desk",
			"rect": [
				56,
				19,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "목공 작업장 보관 칸의 책상",
			"level": 1
		},
		{
			"kind": "firewood_pile",
			"rect": [
				61,
				15,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "목공 작업장 보관 칸의 장작 더미",
			"level": 1
		},
		{
			"kind": "parts_rack",
			"rect": [
				65,
				16,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "지게차 차고 작업 칸의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				69,
				16,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "지게차 차고 작업 칸의 통",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				65,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "지게차 차고 작업 칸의 책상",
			"level": 0
		},
		{
			"kind": "parts_rack",
			"rect": [
				71,
				16,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "지게차 차고 보관 칸의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				74,
				16,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "지게차 차고 보관 칸의 통",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				71,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "지게차 차고 보관 칸의 책상",
			"level": 0
		},
		{
			"kind": "bed",
			"rect": [
				77,
				13,
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
				77,
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
				80,
				13,
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
				83,
				13,
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
				86,
				13,
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
				86,
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
				77,
				13,
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
				77,
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
				80,
				13,
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
				83,
				13,
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
				86,
				13,
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
				86,
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
			"kind": "desk",
			"rect": [
				94,
				16,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 사무 집 작업 칸의 책상",
			"level": 0
		},
		{
			"kind": "office_cabinet",
			"rect": [
				94,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 사무 집 작업 칸의 서류장",
			"level": 0
		},
		{
			"kind": "parts_rack",
			"rect": [
				96,
				16,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 사무 집 작업 칸의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				100,
				16,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 사무 집 보관 칸의 책상",
			"level": 0
		},
		{
			"kind": "office_cabinet",
			"rect": [
				100,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 사무 집 보관 칸의 서류장",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				103,
				16,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 사무 집 보관 칸의 통",
			"level": 0
		},
		{
			"kind": "bed",
			"rect": [
				124,
				9,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "고리 섬 관리 집 살림방의 침대",
			"level": 0
		},
		{
			"kind": "wardrobe",
			"rect": [
				126,
				9,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "고리 섬 관리 집 살림방의 장롱",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				126,
				12,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "고리 섬 관리 집 살림방의 책상",
			"level": 0
		},
		{
			"kind": "dining_set",
			"rect": [
				129,
				9,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "고리 섬 관리 집 부엌의 식탁",
			"level": 0
		},
		{
			"kind": "fridge_open",
			"rect": [
				131,
				9,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "고리 섬 관리 집 부엌의 냉장고",
			"level": 0
		},
		{
			"kind": "cold_stove",
			"rect": [
				131,
				12,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "고리 섬 관리 집 부엌의 꺼진 난로",
			"level": 0
		},
		{
			"kind": "lumber_stack",
			"rect": [
				157,
				29,
				4,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "건조 헛간 작업 칸의 목재 더미",
			"level": 0
		},
		{
			"kind": "pallet_stack",
			"rect": [
				162,
				29,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "건조 헛간 작업 칸의 팰릿 더미",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				157,
				33,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "건조 헛간 작업 칸의 통",
			"level": 0
		},
		{
			"kind": "lumber_stack",
			"rect": [
				165,
				29,
				4,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "건조 헛간 보관 칸의 목재 더미",
			"level": 0
		},
		{
			"kind": "pallet_stack",
			"rect": [
				170,
				29,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "건조 헛간 보관 칸의 팰릿 더미",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				165,
				33,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "건조 헛간 보관 칸의 통",
			"level": 0
		},
		{
			"kind": "lumber_stack",
			"rect": [
				173,
				29,
				4,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "건조 헛간 보관 칸의 목재 더미",
			"level": 0
		},
		{
			"kind": "pallet_stack",
			"rect": [
				177,
				29,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "건조 헛간 보관 칸의 팰릿 더미",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				173,
				33,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "건조 헛간 보관 칸의 통",
			"level": 0
		},
		{
			"kind": "hardware_rack",
			"rect": [
				159,
				1,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 사무동 작업 칸의 철물 걸이대",
			"level": -1
		},
		{
			"kind": "office_cabinet",
			"rect": [
				159,
				6,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 사무동 작업 칸의 서류장",
			"level": -1
		},
		{
			"kind": "desk",
			"rect": [
				166,
				1,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 사무동 작업 칸의 책상",
			"level": -1
		},
		{
			"kind": "hardware_rack",
			"rect": [
				169,
				1,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 사무동 보관 칸의 철물 걸이대",
			"level": -1
		},
		{
			"kind": "office_cabinet",
			"rect": [
				169,
				6,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 사무동 보관 칸의 서류장",
			"level": -1
		},
		{
			"kind": "desk",
			"rect": [
				175,
				1,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 사무동 보관 칸의 책상",
			"level": -1
		},
		{
			"kind": "hardware_rack",
			"rect": [
				159,
				1,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 사무동 작업 칸의 철물 걸이대",
			"level": 0
		},
		{
			"kind": "office_cabinet",
			"rect": [
				159,
				6,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 사무동 작업 칸의 서류장",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				166,
				1,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 사무동 작업 칸의 책상",
			"level": 0
		},
		{
			"kind": "hardware_rack",
			"rect": [
				169,
				1,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 사무동 보관 칸의 철물 걸이대",
			"level": 0
		},
		{
			"kind": "office_cabinet",
			"rect": [
				169,
				6,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 사무동 보관 칸의 서류장",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				175,
				1,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 사무동 보관 칸의 책상",
			"level": 0
		},
		{
			"kind": "hardware_rack",
			"rect": [
				159,
				1,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 사무동 작업 칸의 철물 걸이대",
			"level": 1
		},
		{
			"kind": "office_cabinet",
			"rect": [
				159,
				6,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 사무동 작업 칸의 서류장",
			"level": 1
		},
		{
			"kind": "desk",
			"rect": [
				166,
				1,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 사무동 작업 칸의 책상",
			"level": 1
		},
		{
			"kind": "hardware_rack",
			"rect": [
				169,
				1,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 사무동 보관 칸의 철물 걸이대",
			"level": 1
		},
		{
			"kind": "office_cabinet",
			"rect": [
				169,
				6,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 사무동 보관 칸의 서류장",
			"level": 1
		},
		{
			"kind": "desk",
			"rect": [
				175,
				1,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 사무동 보관 칸의 책상",
			"level": 1
		},
		{
			"kind": "hardware_rack",
			"rect": [
				159,
				1,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 사무동 작업 칸의 철물 걸이대",
			"level": 2
		},
		{
			"kind": "office_cabinet",
			"rect": [
				159,
				6,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 사무동 작업 칸의 서류장",
			"level": 2
		},
		{
			"kind": "desk",
			"rect": [
				166,
				1,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 사무동 작업 칸의 책상",
			"level": 2
		},
		{
			"kind": "hardware_rack",
			"rect": [
				169,
				1,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 사무동 보관 칸의 철물 걸이대",
			"level": 2
		},
		{
			"kind": "office_cabinet",
			"rect": [
				169,
				6,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 사무동 보관 칸의 서류장",
			"level": 2
		},
		{
			"kind": "desk",
			"rect": [
				175,
				1,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "자재 사무동 보관 칸의 책상",
			"level": 2
		},
		{
			"kind": "pallet_stack",
			"rect": [
				18,
				40,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "팰릿 더미",
			"level": 0
		},
		{
			"kind": "lumber_stack",
			"rect": [
				40,
				35,
				2,
				4
			],
			"solid": "low",
			"facing": 0,
			"note": "목재 더미",
			"level": 0
		},
		{
			"kind": "pallet_truck",
			"rect": [
				84,
				41,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "마당의 작업 물건",
			"level": 0
		},
		{
			"kind": "crate_stack",
			"rect": [
				104,
				30,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "나무 상자 더미",
			"level": 0
		},
		{
			"kind": "forklift",
			"rect": [
				124,
				30,
				3,
				2
			],
			"solid": "wall",
			"facing": 0,
			"note": "마당의 작업 물건",
			"level": 0
		},
		{
			"kind": "pallet_stack",
			"rect": [
				128,
				34,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "팰릿 더미",
			"level": 0
		},
		{
			"kind": "lumber_stack",
			"rect": [
				136,
				36,
				4,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "목재 더미",
			"level": 0
		},
		{
			"kind": "crate_stack",
			"rect": [
				140,
				30,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "나무 상자 더미",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				130,
				29,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "통",
			"level": 0
		},
		{
			"kind": "dock_plate",
			"rect": [
				122,
				25,
				12,
				3
			],
			"solid": "none",
			"facing": 0,
			"note": "마당의 작업 물건",
			"level": 0
		},
		{
			"kind": "street_tree",
			"rect": [
				14,
				2,
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
				17,
				4,
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
				21,
				2,
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
				24,
				4,
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
				40,
				2,
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
				43,
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
				47,
				2,
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
				50,
				4,
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
			"kind": "bare_orchard_tree",
			"rect": [
				144,
				5,
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
				141,
				8,
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
				7,
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
			"name": "자재 창고 입고 방 상자",
			"cell": [
				6,
				14
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_1",
			"name": "자재 창고 비축 방 상자",
			"cell": [
				13,
				14
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_2",
			"name": "자재 창고 작업 방 상자",
			"cell": [
				20,
				14
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_3",
			"name": "자재 창고 접수 방 상자",
			"cell": [
				26,
				14
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_4",
			"name": "자재 창고 보관 방 상자",
			"cell": [
				32,
				14
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_5",
			"name": "자재 창고 안쪽 광 상자",
			"cell": [
				38,
				14
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_6",
			"name": "자재 창고 입고 방 상자",
			"cell": [
				6,
				14
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_7",
			"name": "자재 창고 비축 방 상자",
			"cell": [
				13,
				14
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_8",
			"name": "자재 창고 작업 방 상자",
			"cell": [
				20,
				14
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_9",
			"name": "자재 창고 접수 방 상자",
			"cell": [
				26,
				14
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_10",
			"name": "자재 창고 보관 방 상자",
			"cell": [
				32,
				14
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_11",
			"name": "자재 창고 안쪽 광 상자",
			"cell": [
				38,
				14
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_12",
			"name": "목공 작업장 작업 칸 상자",
			"cell": [
				54,
				19
			],
			"level": 0,
			"building": 17,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_13",
			"name": "목공 작업장 보관 칸 상자",
			"cell": [
				62,
				19
			],
			"level": 0,
			"building": 17,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_14",
			"name": "목공 작업장 작업 칸 상자",
			"cell": [
				54,
				19
			],
			"level": 1,
			"building": 17,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_15",
			"name": "목공 작업장 보관 칸 상자",
			"cell": [
				62,
				19
			],
			"level": 1,
			"building": 17,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_16",
			"name": "지게차 차고 작업 칸 상자",
			"cell": [
				69,
				19
			],
			"level": 0,
			"building": 18,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_17",
			"name": "지게차 차고 보관 칸 상자",
			"cell": [
				74,
				19
			],
			"level": 0,
			"building": 18,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_18",
			"name": "살림집 살림방 상자",
			"cell": [
				81,
				19
			],
			"level": 0,
			"building": 19,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_19",
			"name": "살림집 부엌 상자",
			"cell": [
				83,
				19
			],
			"level": 0,
			"building": 19,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_20",
			"name": "살림집 살림방 상자",
			"cell": [
				81,
				19
			],
			"level": 1,
			"building": 19,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_21",
			"name": "살림집 부엌 상자",
			"cell": [
				83,
				19
			],
			"level": 1,
			"building": 19,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_22",
			"name": "자재 사무 집 작업 칸 상자",
			"cell": [
				98,
				19
			],
			"level": 0,
			"building": 20,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_23",
			"name": "자재 사무 집 보관 칸 상자",
			"cell": [
				103,
				19
			],
			"level": 0,
			"building": 20,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_24",
			"name": "고리 섬 관리 집 살림방 상자",
			"cell": [
				124,
				12
			],
			"level": 0,
			"building": 21,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_25",
			"name": "고리 섬 관리 집 부엌 상자",
			"cell": [
				129,
				12
			],
			"level": 0,
			"building": 21,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_26",
			"name": "건조 헛간 작업 칸 상자",
			"cell": [
				163,
				33
			],
			"level": 0,
			"building": 22,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_27",
			"name": "건조 헛간 보관 칸 상자",
			"cell": [
				171,
				33
			],
			"level": 0,
			"building": 22,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_28",
			"name": "건조 헛간 보관 칸 상자",
			"cell": [
				178,
				33
			],
			"level": 0,
			"building": 22,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_29",
			"name": "자재 사무동 작업 칸 상자",
			"cell": [
				167,
				6
			],
			"level": -1,
			"building": 23,
			"search": 7,
			"items": [
				"plank",
				"scrap",
				"plank",
				"scrap"
			],
			"locked": true,
			"searched": false
		},
		{
			"id": "north_cache_30",
			"name": "자재 사무동 보관 칸 상자",
			"cell": [
				176,
				6
			],
			"level": -1,
			"building": 23,
			"search": 7,
			"items": [
				"plank",
				"scrap",
				"plank",
				"scrap"
			],
			"locked": true,
			"searched": false
		},
		{
			"id": "north_cache_31",
			"name": "자재 사무동 작업 칸 상자",
			"cell": [
				167,
				6
			],
			"level": 0,
			"building": 23,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_32",
			"name": "자재 사무동 보관 칸 상자",
			"cell": [
				176,
				6
			],
			"level": 0,
			"building": 23,
			"search": 4,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_33",
			"name": "자재 사무동 작업 칸 상자",
			"cell": [
				167,
				6
			],
			"level": 1,
			"building": 23,
			"search": 7,
			"items": [
				"plank",
				"scrap",
				"plank",
				"scrap"
			],
			"locked": true,
			"searched": false
		},
		{
			"id": "north_cache_34",
			"name": "자재 사무동 보관 칸 상자",
			"cell": [
				176,
				6
			],
			"level": 1,
			"building": 23,
			"search": 7,
			"items": [
				"plank",
				"scrap",
				"plank",
				"scrap"
			],
			"locked": true,
			"searched": false
		},
		{
			"id": "north_cache_35",
			"name": "자재 사무동 작업 칸 상자",
			"cell": [
				167,
				6
			],
			"level": 2,
			"building": 23,
			"search": 7,
			"items": [
				"plank",
				"scrap",
				"plank",
				"scrap"
			],
			"locked": true,
			"searched": false
		},
		{
			"id": "north_cache_36",
			"name": "자재 사무동 보관 칸 상자",
			"cell": [
				176,
				6
			],
			"level": 2,
			"building": 23,
			"search": 7,
			"items": [
				"plank",
				"scrap",
				"plank",
				"scrap"
			],
			"locked": true,
			"searched": false
		},
		{
			"id": "north_shallow",
			"name": "승강장 뒤 작은 보급 상자",
			"cell": [
				52,
				37
			],
			"level": 0,
			"building": -1,
			"search": 2,
			"items": [
				"plank"
			],
			"locked": false,
			"searched": false
		}
	],
	"entries": [
		{
			"id": "자재 큰길 서쪽 어귀",
			"name": "자재 큰길 서쪽 어귀",
			"cells": [
				[
					0,
					6
				],
				[
					0,
					7
				],
				[
					0,
					8
				],
				[
					0,
					9
				]
			],
			"gap": 0.6
		},
		{
			"id": "북쪽 자재 샛길",
			"name": "북쪽 자재 샛길",
			"cells": [
				[
					150,
					0
				],
				[
					151,
					0
				],
				[
					152,
					0
				],
				[
					153,
					0
				]
			],
			"gap": 2.5
		},
		{
			"id": "동쪽 짐길",
			"name": "동쪽 짐길",
			"cells": [
				[
					179,
					18
				],
				[
					179,
					19
				],
				[
					179,
					20
				],
				[
					179,
					21
				]
			],
			"gap": 0.6
		}
	],
	"holes": [],
	"barricades": [
		[
			41,
			22
		],
		[
			44,
			22
		],
		[
			89,
			22
		],
		[
			91,
			22
		]
	],
	"slots": [
		"J"
	],
	"deep": 7,
	"forecourts": [
		[
			18,
			24,
			5,
			4
		],
		[
			53,
			24,
			5,
			4
		],
		[
			68,
			24,
			5,
			4
		],
		[
			80,
			24,
			5,
			4
		],
		[
			97,
			24,
			5,
			4
		],
		[
			123,
			14,
			5,
			4
		],
		[
			166,
			38,
			5,
			4
		],
		[
			166,
			11,
			5,
			4
		]
	],
	"crossings": [
		48,
		64
	],
	"stock": [
		"lumber_stack",
		"parts_rack",
		"shelf",
		"crate_stack"
	],
	"loot": [
		"plank",
		"scrap"
	],
	"assumptions": [
		"서쪽 두 칸의 불필요한 틈을 자재 창고 벽으로 닫았다.",
		"고리 북쪽 나무를 네 그루로 보충해 북쪽 전체 열두 그루를 맞췄다.",
		"앞쪽 복도 출입문과 북쪽 입고 문을 따로 두었다.",
		"서쪽 두 나무 무리가 같은 꼴이 되지 않도록 한 그루의 줄을 달리했다."
	]
}

const SOUTH_TREE_MOVES: Array = [[[42,36],[45,39]],[[43,42],[48,41]],[[60,28],[68,31]],[[59,22],[62,31]],[[59,51],[64,60]],[[35,52],[31,48]]]
const SOUTH_WORK: Dictionary = {"name":"하역 평판 작업 구역","cell":[98,30],"rect":[72,28,60,7]}

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
const ENTRY_NAMES: Dictionary = {"east_track": "동쪽 선로", "west_lower": "서쪽 아랫길", "south_main": "남쪽 큰길", "parking_exit": "주차장 어귀", "east_path": "동쪽 오솔길", "manhole_01": "첫째 맨홀", "manhole_02": "둘째 맨홀", "manhole_03": "셋째 맨홀", "drain_01": "배수구", "자재 큰길 서쪽 어귀": "자재 큰길 서쪽 어귀", "북쪽 자재 샛길": "북쪽 자재 샛길", "동쪽 짐길": "동쪽 짐길"}
const ENTRY_WEIGHTS: Dictionary = {"east_track": 1.0, "west_lower": 0.5, "south_main": 1.0, "parking_exit": 1.0, "east_path": 0.5, "manhole_01": 0.3, "manhole_02": 0.3, "manhole_03": 0.3, "drain_01": 1.0, "자재 큰길 서쪽 어귀": 1.0, "북쪽 자재 샛길": 0.5, "동쪽 짐길": 1.0}
const FIRST_ENTRY: String = "east_track"


static func build() -> Dictionary:
	var data: Dictionary = _build_plain()
	data["entry_names"] = ENTRY_NAMES.duplicate()
	data["entry_weights"] = ENTRY_WEIGHTS.duplicate()
	data["first_entry"] = FIRST_ENTRY
	return data
