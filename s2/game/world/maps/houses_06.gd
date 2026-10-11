# 이 지도가 다른 판단을 만드는 것: 잔교는 외길이라 막기 쉬우나 끝에서 물러날 곳이 없다.
# 위쪽의 판단: 약품을 얻는 대신, 손가락처럼 갈라진 길 셋이 서로 길로 이어지지 않아 한 길을 고르면 나머지 길의 집을 못 본다.
extends RefCounted

const FieldGrid = preload("res://game/world/field_grid.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 160
const SOUTH_HEIGHT: int = 95
const HEIGHT: int = SOUTH_HEIGHT + 45
const PLACE_ID: String = "houses_06"

# 각 좌표는 이 지도의 독립 평면이다. 위층 장식은 충돌을 만들지 않는다.
const PLAN: Dictionary = {
	"number": 6,
	"width": 160,
	"height": 95,
	"judgment": "잔교는 외길이라 막기 쉬우나 끝에서 물러날 곳이 없다.",
	"zones": [{"id":"A","name":"승강장 앞 농가","rect":[0,0,160,30]},
		{"id":"B","name":"서쪽 모래길","rect":[0,30,104,18]},
		{"id":"C","name":"얼음 작업장","rect":[104,30,56,18]},
		{"id":"D","name":"서쪽 물가","rect":[0,48,52,47]},
		{"id":"E","name":"잔교 어귀","rect":[52,48,52,47]},
		{"id":"F","name":"동쪽 물가","rect":[104,48,56,47]},
		{"id":"G","name":"잔교 끝","rect":[0,77,160,18]},
		{"id":"H","name":"북동 농가","rect":[120,4,40,26]}],
	"grounds": [{"rect":[60,10,6,26],"floor":1},
		{"rect":[18,32,91,5],"floor":7},
		{"rect":[104,32,5,23],"floor":7},
		{"rect":[18,50,91,5],"floor":7},
		{"rect":[18,32,5,23],"floor":7},
		{"rect":[0,38,23,4],"floor":7},
		{"rect":[0,48,23,4],"floor":7},
		{"rect":[128,4,4,32],"floor":7},
		{"rect":[128,14,32,4],"floor":7},
		{"rect":[62,52,3,22],"floor":3},
		{"rect":[40,71,52,24],"floor":3},
		{"rect":[28,28,32,4],"floor":7},
		{"rect":[20,52,5,40],"floor":7}],
	"buildings": [{"name":"어구 창고","rect":[44,76,44,18],"top":3,"basement":false,"role":"shed","main":true,"stock":["net_pile","desk","shelf"],"id":0},
		{"name":"얼음 창고","rect":[110,40,18,12],"top":1,"basement":true,"role":"shed","mode":"vertical","stock":["ice_block_stack","barrel","freezer_chest"],"id":1},
		{"name":"생선 가게","rect":[68,14,18,12],"top":2,"basement":false,"role":"shop","stock":["fish_crate_stack","shop_counter","freezer_chest"],"id":2},
		{"name":"잡화점","rect":[90,14,14,10],"top":1,"basement":false,"role":"shop","stock":["display_shelf","shop_counter","shelf"],"id":3},
		{"name":"농가 가","rect":[4,10,24,18],"top":2,"basement":false,"role":"home","mode":"vertical","single_entry":true,"id":4},
		{"name":"농가 나","rect":[36,14,22,12],"top":2,"basement":false,"role":"home","mode":"vertical","id":5},
		{"name":"농가 다","rect":[134,8,22,12],"top":2,"basement":false,"role":"home","id":6},
		{"name":"농가 라","rect":[134,22,22,8],"top":2,"basement":false,"role":"home","id":7},
		{"name":"농가 마","rect":[2,34,14,10],"top":1,"basement":false,"role":"home","mode":"vertical","id":8},
		{"name":"농가 바","rect":[32,38,18,10],"top":1,"basement":false,"role":"shed","id":9},
		{"name":"농가 사","rect":[56,38,18,10],"top":1,"basement":false,"role":"shed","id":10},
		{"name":"농가 아","rect":[82,38,18,10],"top":1,"basement":false,"role":"shed","id":11},
		{"name":"기둥 헛간 건조장","rect":[116,12,14,10],"top":1,"basement":false,"role":"shed","id":12},
		{"name":"그물 수선 헛간","rect":[116,26,12,10],"top":1,"basement":false,"role":"shed","mode":"vertical","id":13},
		{"name":"절임 헛간","rect":[90,26,12,6],"top":1,"basement":false,"role":"shed","stock":["curing_barrel","sack_pile","barrel"],"id":14},
		{"name":"장작 헛간","rect":[30,12,6,14],"top":1,"basement":false,"role":"shed","mode":"vertical","id":15}],
	"entries": [{"id":"west_sand","cells":[[0,38],[0,39],[0,40],[0,41]],"gap":2},
		{"id":"west_lower","cells":[[0,48],[0,49],[0,50],[0,51]],"gap":0.6},
		{"id":"east_track","cells":[[159,1],[159,2],[159,3]],"gap":0.6},
		{"id":"east_field","cells":[[159,14],[159,15],[159,16],[159,17]],"gap":2}],
	"holes": [{"id":"manhole_01","cell":[30,42],"name":"고리 서쪽 맨홀","level":0},
		{"id":"drain_01","cell":[106,46],"name":"얼음 창고 배수구","level":0},
		{"id":"drain_02","cell":[20,52],"name":"도랑 끝 배수구","level":0}],
	"barricades": [[61,24],[63,24],[87,22],[89,22],[105,22],[107,22]],
	"deepBuildings": [0,4],
	"deepLevels": [2,1],
	"assumptions": ["잔교 끝 판은 주 건물 양쪽에 네 칸씩 하역 앞마당이 남도록 넓혔다.","얼음 창고를 고리 바깥 동편으로 옮겨 고리 길을 보존했다.","북서 농가는 긴 다락 곳간을 가진 남문 하나의 집으로 조정했다.","잔교 어귀까지는 고리의 두 길이 이어지고 마지막 잔교만 외길이다.","좌우 고체 겹침 기준을 지키도록 서남쪽 해안선을 길게 내밀었다. 잔교 끝 판과는 다섯 칸 물길로 분리했다."],
	"tx": 16,
	"band": [0,4,116,26],
	"shells": [{"building":0,"level":0,"rect":[44,76,44,18]},
		{"building":0,"level":1,"rect":[44,76,44,18]},
		{"building":0,"level":2,"rect":[44,76,44,18]},
		{"building":1,"level":0,"rect":[110,40,18,12]},
		{"building":1,"level":-1,"rect":[110,40,18,12]},
		{"building":2,"level":0,"rect":[68,14,18,12]},
		{"building":2,"level":1,"rect":[68,14,18,12]},
		{"building":3,"level":0,"rect":[90,14,14,10]},
		{"building":4,"level":0,"rect":[4,10,24,18]},
		{"building":4,"level":1,"rect":[4,10,24,18]},
		{"building":5,"level":0,"rect":[36,14,22,12]},
		{"building":5,"level":1,"rect":[36,14,22,12]},
		{"building":6,"level":0,"rect":[134,8,22,12]},
		{"building":6,"level":1,"rect":[134,8,22,12]},
		{"building":7,"level":0,"rect":[134,22,22,8]},
		{"building":7,"level":1,"rect":[134,22,22,8]},
		{"building":8,"level":0,"rect":[2,34,14,10]},
		{"building":9,"level":0,"rect":[32,38,18,10]},
		{"building":10,"level":0,"rect":[56,38,18,10]},
		{"building":11,"level":0,"rect":[82,38,18,10]},
		{"building":12,"level":0,"rect":[116,12,14,10]},
		{"building":13,"level":0,"rect":[116,26,12,10]},
		{"building":14,"level":0,"rect":[90,26,12,6]},
		{"building":15,"level":0,"rect":[30,12,6,14]}],
	"walls": [{"building":0,"level":0,"rect":[45,83,42,1]},
		{"building":0,"level":0,"rect":[45,86,42,1]},
		{"building":0,"level":0,"rect":[52,77,1,6]},
		{"building":0,"level":0,"rect":[59,77,1,6]},
		{"building":0,"level":0,"rect":[66,77,1,6]},
		{"building":0,"level":0,"rect":[73,77,1,6]},
		{"building":0,"level":0,"rect":[80,77,1,6]},
		{"building":0,"level":0,"rect":[52,87,1,6]},
		{"building":0,"level":0,"rect":[59,87,1,6]},
		{"building":0,"level":0,"rect":[66,87,1,6]},
		{"building":0,"level":0,"rect":[73,87,1,6]},
		{"building":0,"level":0,"rect":[80,87,1,6]},
		{"building":0,"level":1,"rect":[45,83,42,1]},
		{"building":0,"level":1,"rect":[45,86,42,1]},
		{"building":0,"level":1,"rect":[52,77,1,6]},
		{"building":0,"level":1,"rect":[59,77,1,6]},
		{"building":0,"level":1,"rect":[66,77,1,6]},
		{"building":0,"level":1,"rect":[73,77,1,6]},
		{"building":0,"level":1,"rect":[80,77,1,6]},
		{"building":0,"level":1,"rect":[52,87,1,6]},
		{"building":0,"level":1,"rect":[59,87,1,6]},
		{"building":0,"level":1,"rect":[66,87,1,6]},
		{"building":0,"level":1,"rect":[73,87,1,6]},
		{"building":0,"level":1,"rect":[80,87,1,6]},
		{"building":0,"level":2,"rect":[45,83,42,1]},
		{"building":0,"level":2,"rect":[45,86,42,1]},
		{"building":0,"level":2,"rect":[52,77,1,6]},
		{"building":0,"level":2,"rect":[59,77,1,6]},
		{"building":0,"level":2,"rect":[66,77,1,6]},
		{"building":0,"level":2,"rect":[73,77,1,6]},
		{"building":0,"level":2,"rect":[80,77,1,6]},
		{"building":0,"level":2,"rect":[52,87,1,6]},
		{"building":0,"level":2,"rect":[59,87,1,6]},
		{"building":0,"level":2,"rect":[66,87,1,6]},
		{"building":0,"level":2,"rect":[73,87,1,6]},
		{"building":0,"level":2,"rect":[80,87,1,6]},
		{"building":1,"level":0,"rect":[117,41,1,10]},
		{"building":1,"level":0,"rect":[120,41,1,10]},
		{"building":1,"level":-1,"rect":[117,41,1,10]},
		{"building":1,"level":-1,"rect":[120,41,1,10]},
		{"building":2,"level":0,"rect":[69,18,16,1]},
		{"building":2,"level":0,"rect":[69,21,16,1]},
		{"building":2,"level":0,"rect":[77,15,1,3]},
		{"building":2,"level":0,"rect":[77,22,1,3]},
		{"building":2,"level":1,"rect":[69,18,16,1]},
		{"building":2,"level":1,"rect":[69,21,16,1]},
		{"building":2,"level":1,"rect":[77,15,1,3]},
		{"building":2,"level":1,"rect":[77,22,1,3]},
		{"building":3,"level":0,"rect":[97,15,1,8]},
		{"building":4,"level":0,"rect":[14,11,1,16]},
		{"building":4,"level":0,"rect":[17,11,1,16]},
		{"building":4,"level":0,"rect":[9,11,1,8]},
		{"building":4,"level":0,"rect":[5,19,9,1]},
		{"building":4,"level":0,"rect":[9,20,1,7]},
		{"building":4,"level":0,"rect":[22,11,1,8]},
		{"building":4,"level":0,"rect":[18,19,9,1]},
		{"building":4,"level":0,"rect":[22,20,1,7]},
		{"building":4,"level":1,"rect":[14,11,1,16]},
		{"building":4,"level":1,"rect":[17,11,1,16]},
		{"building":4,"level":1,"rect":[9,11,1,8]},
		{"building":4,"level":1,"rect":[5,19,9,1]},
		{"building":4,"level":1,"rect":[9,20,1,7]},
		{"building":4,"level":1,"rect":[22,11,1,8]},
		{"building":4,"level":1,"rect":[18,19,9,1]},
		{"building":4,"level":1,"rect":[22,20,1,7]},
		{"building":5,"level":0,"rect":[45,15,1,10]},
		{"building":5,"level":0,"rect":[48,15,1,10]},
		{"building":5,"level":1,"rect":[45,15,1,10]},
		{"building":5,"level":1,"rect":[48,15,1,10]},
		{"building":6,"level":0,"rect":[135,12,20,1]},
		{"building":6,"level":0,"rect":[135,15,20,1]},
		{"building":6,"level":0,"rect":[145,9,1,3]},
		{"building":6,"level":0,"rect":[145,16,1,3]},
		{"building":6,"level":1,"rect":[135,12,20,1]},
		{"building":6,"level":1,"rect":[135,15,20,1]},
		{"building":6,"level":1,"rect":[145,9,1,3]},
		{"building":6,"level":1,"rect":[145,16,1,3]},
		{"building":7,"level":0,"rect":[140,23,1,6]},
		{"building":7,"level":0,"rect":[145,23,1,6]},
		{"building":7,"level":0,"rect":[150,23,1,6]},
		{"building":7,"level":1,"rect":[140,23,1,6]},
		{"building":7,"level":1,"rect":[145,23,1,6]},
		{"building":7,"level":1,"rect":[150,23,1,6]},
		{"building":8,"level":0,"rect":[7,35,1,8]},
		{"building":8,"level":0,"rect":[10,35,1,8]},
		{"building":9,"level":0,"rect":[38,39,1,8]},
		{"building":9,"level":0,"rect":[44,39,1,8]},
		{"building":10,"level":0,"rect":[62,39,1,8]},
		{"building":10,"level":0,"rect":[68,39,1,8]},
		{"building":11,"level":0,"rect":[88,39,1,8]},
		{"building":11,"level":0,"rect":[94,39,1,8]},
		{"building":12,"level":0,"rect":[123,13,1,8]},
		{"building":13,"level":0,"rect":[120,27,1,8]},
		{"building":13,"level":0,"rect":[123,27,1,8]},
		{"building":14,"level":0,"rect":[96,27,1,4]},
		{"building":15,"level":0,"rect":[31,19,4,1]}],
	"doors": [{"cell":[48,83],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[56,83],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[63,83],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[70,83],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[77,83],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[84,83],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[48,86],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[56,86],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[63,86],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[70,86],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[77,86],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[84,86],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[44,84],"building":0,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[87,84],"building":0,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[48,83],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[56,83],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[63,83],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[70,83],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[77,83],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[84,83],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[48,86],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[56,86],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[63,86],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[70,86],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[77,86],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[84,86],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[48,83],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[56,83],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[63,83],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[70,83],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[77,83],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[84,83],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[48,86],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[56,86],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[63,86],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[70,86],"building":0,"level":2,"state":"closed","normal":[0,1],"external":false},
		{"cell":[77,86],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[84,86],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[117,46],"building":1,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[120,46],"building":1,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[118,40],"building":1,"level":0,"state":"open","normal":[0,-1],"external":true},
		{"cell":[118,51],"building":1,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[117,46],"building":1,"level":-1,"state":"open","normal":[1,0],"external":false},
		{"cell":[120,46],"building":1,"level":-1,"state":"open","normal":[1,0],"external":false},
		{"cell":[73,18],"building":2,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[81,18],"building":2,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[73,21],"building":2,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[81,21],"building":2,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[68,19],"building":2,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[85,19],"building":2,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[73,18],"building":2,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[81,18],"building":2,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[73,21],"building":2,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[81,21],"building":2,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[97,19],"building":3,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[90,19],"building":3,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[103,19],"building":3,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[9,15],"building":4,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[14,15],"building":4,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[9,23],"building":4,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[14,23],"building":4,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[22,15],"building":4,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[17,15],"building":4,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[22,23],"building":4,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[17,23],"building":4,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[15,27],"building":4,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[9,15],"building":4,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[14,15],"building":4,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[9,23],"building":4,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[14,23],"building":4,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[22,15],"building":4,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[17,15],"building":4,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[22,23],"building":4,"level":1,"state":"closed","normal":[1,0],"external":false},
		{"cell":[17,23],"building":4,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[45,20],"building":5,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[48,20],"building":5,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[46,14],"building":5,"level":0,"state":"open","normal":[0,-1],"external":true},
		{"cell":[46,25],"building":5,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[45,20],"building":5,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[48,20],"building":5,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[140,12],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[150,12],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[140,15],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[150,15],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[134,13],"building":6,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[155,13],"building":6,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[140,12],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[150,12],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[140,15],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[150,15],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[140,26],"building":7,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[145,26],"building":7,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[150,26],"building":7,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[134,26],"building":7,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[155,26],"building":7,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[140,26],"building":7,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[145,26],"building":7,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[150,26],"building":7,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[7,39],"building":8,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[10,39],"building":8,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[8,34],"building":8,"level":0,"state":"open","normal":[0,-1],"external":true},
		{"cell":[8,43],"building":8,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[38,43],"building":9,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[44,43],"building":9,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[32,43],"building":9,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[49,43],"building":9,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[62,43],"building":10,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[68,43],"building":10,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[56,43],"building":10,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[73,43],"building":10,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[88,43],"building":11,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[94,43],"building":11,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[82,43],"building":11,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[99,43],"building":11,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[123,17],"building":12,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[116,17],"building":12,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[129,17],"building":12,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[120,31],"building":13,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[123,31],"building":13,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[121,26],"building":13,"level":0,"state":"open","normal":[0,-1],"external":true},
		{"cell":[121,35],"building":13,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[96,29],"building":14,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[90,29],"building":14,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[101,29],"building":14,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[33,19],"building":15,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[33,12],"building":15,"level":0,"state":"open","normal":[0,-1],"external":true},
		{"cell":[33,25],"building":15,"level":0,"state":"open","normal":[0,1],"external":true}],
	"windows": [{"cell":[47,76],"building":0,"level":0},
		{"cell":[84,93],"building":0,"level":0},
		{"cell":[47,76],"building":0,"level":1},
		{"cell":[84,93],"building":0,"level":1},
		{"cell":[47,76],"building":0,"level":2},
		{"cell":[84,93],"building":0,"level":2},
		{"cell":[110,43],"building":1,"level":0},
		{"cell":[127,48],"building":1,"level":0},
		{"cell":[110,43],"building":1,"level":-1},
		{"cell":[127,48],"building":1,"level":-1},
		{"cell":[71,14],"building":2,"level":0},
		{"cell":[82,25],"building":2,"level":0},
		{"cell":[71,14],"building":2,"level":1},
		{"cell":[82,25],"building":2,"level":1},
		{"cell":[92,14],"building":3,"level":0},
		{"cell":[4,13],"building":4,"level":0},
		{"cell":[27,24],"building":4,"level":0},
		{"cell":[4,13],"building":4,"level":1},
		{"cell":[27,24],"building":4,"level":1},
		{"cell":[36,17],"building":5,"level":0},
		{"cell":[57,22],"building":5,"level":0},
		{"cell":[36,17],"building":5,"level":1},
		{"cell":[57,22],"building":5,"level":1},
		{"cell":[137,8],"building":6,"level":0},
		{"cell":[152,19],"building":6,"level":0},
		{"cell":[137,8],"building":6,"level":1},
		{"cell":[152,19],"building":6,"level":1},
		{"cell":[136,22],"building":7,"level":0},
		{"cell":[136,22],"building":7,"level":1},
		{"cell":[2,37],"building":8,"level":0},
		{"cell":[15,40],"building":8,"level":0},
		{"cell":[34,38],"building":9,"level":0},
		{"cell":[58,38],"building":10,"level":0},
		{"cell":[84,38],"building":11,"level":0},
		{"cell":[118,12],"building":12,"level":0},
		{"cell":[116,29],"building":13,"level":0},
		{"cell":[127,32],"building":13,"level":0},
		{"cell":[92,26],"building":14,"level":0},
		{"cell":[30,14],"building":15,"level":0}],
	"stairs": [{"cell":[46,84],"low":0,"high":1,"ladder":false},
		{"cell":[46,84],"low":1,"high":2,"ladder":false},
		{"cell":[85,85],"low":0,"high":1,"ladder":false},
		{"cell":[85,85],"low":1,"high":2,"ladder":false},
		{"cell":[118,42],"low":-1,"high":0,"ladder":false},
		{"cell":[70,19],"low":0,"high":1,"ladder":false},
		{"cell":[15,12],"low":0,"high":1,"ladder":false},
		{"cell":[46,16],"low":0,"high":1,"ladder":false},
		{"cell":[136,13],"low":0,"high":1,"ladder":false},
		{"cell":[135,26],"low":0,"high":1,"ladder":false}],
	"rooms": [{"building":0,"level":0,"rect":[45,77,7,6],"use":"매장"},
		{"building":0,"level":0,"rect":[53,77,6,6],"use":"뒤 창고"},
		{"building":0,"level":0,"rect":[60,77,6,6],"use":"작업실"},
		{"building":0,"level":0,"rect":[67,77,6,6],"use":"매장"},
		{"building":0,"level":0,"rect":[74,77,6,6],"use":"뒤 창고"},
		{"building":0,"level":0,"rect":[81,77,6,6],"use":"작업실"},
		{"building":0,"level":0,"rect":[45,87,7,6],"use":"매장"},
		{"building":0,"level":0,"rect":[53,87,6,6],"use":"뒤 창고"},
		{"building":0,"level":0,"rect":[60,87,6,6],"use":"작업실"},
		{"building":0,"level":0,"rect":[67,87,6,6],"use":"매장"},
		{"building":0,"level":0,"rect":[74,87,6,6],"use":"뒤 창고"},
		{"building":0,"level":0,"rect":[81,87,6,6],"use":"작업실"},
		{"building":0,"level":1,"rect":[45,77,7,6],"use":"매장"},
		{"building":0,"level":1,"rect":[53,77,6,6],"use":"뒤 창고"},
		{"building":0,"level":1,"rect":[60,77,6,6],"use":"작업실"},
		{"building":0,"level":1,"rect":[67,77,6,6],"use":"매장"},
		{"building":0,"level":1,"rect":[74,77,6,6],"use":"뒤 창고"},
		{"building":0,"level":1,"rect":[81,77,6,6],"use":"작업실"},
		{"building":0,"level":1,"rect":[45,87,7,6],"use":"매장"},
		{"building":0,"level":1,"rect":[53,87,6,6],"use":"뒤 창고"},
		{"building":0,"level":1,"rect":[60,87,6,6],"use":"작업실"},
		{"building":0,"level":1,"rect":[67,87,6,6],"use":"매장"},
		{"building":0,"level":1,"rect":[74,87,6,6],"use":"뒤 창고"},
		{"building":0,"level":1,"rect":[81,87,6,6],"use":"작업실"},
		{"building":0,"level":2,"rect":[45,77,7,6],"use":"매장"},
		{"building":0,"level":2,"rect":[53,77,6,6],"use":"뒤 창고"},
		{"building":0,"level":2,"rect":[60,77,6,6],"use":"작업실"},
		{"building":0,"level":2,"rect":[67,77,6,6],"use":"매장"},
		{"building":0,"level":2,"rect":[74,77,6,6],"use":"뒤 창고"},
		{"building":0,"level":2,"rect":[81,77,6,6],"use":"작업실"},
		{"building":0,"level":2,"rect":[45,87,7,6],"use":"매장"},
		{"building":0,"level":2,"rect":[53,87,6,6],"use":"뒤 창고"},
		{"building":0,"level":2,"rect":[60,87,6,6],"use":"작업실"},
		{"building":0,"level":2,"rect":[67,87,6,6],"use":"매장"},
		{"building":0,"level":2,"rect":[74,87,6,6],"use":"뒤 창고"},
		{"building":0,"level":2,"rect":[81,87,6,6],"use":"작업실"},
		{"building":1,"level":0,"rect":[111,41,6,10],"use":"매장"},
		{"building":1,"level":0,"rect":[121,41,6,10],"use":"매장"},
		{"building":1,"level":-1,"rect":[111,41,6,10],"use":"저장 칸"},
		{"building":1,"level":-1,"rect":[121,41,6,10],"use":"저장 칸"},
		{"building":2,"level":0,"rect":[69,15,8,3],"use":"매장"},
		{"building":2,"level":0,"rect":[78,15,7,3],"use":"뒤 창고"},
		{"building":2,"level":0,"rect":[69,22,8,3],"use":"매장"},
		{"building":2,"level":0,"rect":[78,22,7,3],"use":"뒤 창고"},
		{"building":2,"level":1,"rect":[69,15,8,3],"use":"매장"},
		{"building":2,"level":1,"rect":[78,15,7,3],"use":"뒤 창고"},
		{"building":2,"level":1,"rect":[69,22,8,3],"use":"매장"},
		{"building":2,"level":1,"rect":[78,22,7,3],"use":"뒤 창고"},
		{"building":3,"level":0,"rect":[91,15,6,8],"use":"작업실"},
		{"building":3,"level":0,"rect":[98,15,5,8],"use":"뒤 창고"},
		{"building":4,"level":0,"rect":[5,11,4,8],"use":"부엌"},
		{"building":4,"level":0,"rect":[10,11,4,8],"use":"안방"},
		{"building":4,"level":0,"rect":[5,20,4,7],"use":"부엌"},
		{"building":4,"level":0,"rect":[10,20,4,7],"use":"안방"},
		{"building":4,"level":0,"rect":[18,11,4,8],"use":"부엌"},
		{"building":4,"level":0,"rect":[23,11,4,8],"use":"안방"},
		{"building":4,"level":0,"rect":[18,20,4,7],"use":"부엌"},
		{"building":4,"level":0,"rect":[23,20,4,7],"use":"안방"},
		{"building":4,"level":1,"rect":[5,11,4,8],"use":"부엌"},
		{"building":4,"level":1,"rect":[10,11,4,8],"use":"안방"},
		{"building":4,"level":1,"rect":[5,20,4,7],"use":"부엌"},
		{"building":4,"level":1,"rect":[10,20,4,7],"use":"안방"},
		{"building":4,"level":1,"rect":[18,11,4,8],"use":"부엌"},
		{"building":4,"level":1,"rect":[23,11,4,8],"use":"안방"},
		{"building":4,"level":1,"rect":[18,20,4,7],"use":"부엌"},
		{"building":4,"level":1,"rect":[23,20,4,7],"use":"안방"},
		{"building":5,"level":0,"rect":[37,15,8,10],"use":"안방"},
		{"building":5,"level":0,"rect":[49,15,8,10],"use":"안방"},
		{"building":5,"level":1,"rect":[37,15,8,10],"use":"안방"},
		{"building":5,"level":1,"rect":[49,15,8,10],"use":"안방"},
		{"building":6,"level":0,"rect":[135,9,10,3],"use":"안방"},
		{"building":6,"level":0,"rect":[146,9,9,3],"use":"부엌"},
		{"building":6,"level":0,"rect":[135,16,10,3],"use":"안방"},
		{"building":6,"level":0,"rect":[146,16,9,3],"use":"부엌"},
		{"building":6,"level":1,"rect":[135,9,10,3],"use":"안방"},
		{"building":6,"level":1,"rect":[146,9,9,3],"use":"부엌"},
		{"building":6,"level":1,"rect":[135,16,10,3],"use":"안방"},
		{"building":6,"level":1,"rect":[146,16,9,3],"use":"부엌"},
		{"building":7,"level":0,"rect":[135,23,5,6],"use":"작업실"},
		{"building":7,"level":0,"rect":[141,23,4,6],"use":"뒤 창고"},
		{"building":7,"level":0,"rect":[146,23,4,6],"use":"뒤 창고"},
		{"building":7,"level":0,"rect":[151,23,4,6],"use":"뒤 창고"},
		{"building":7,"level":1,"rect":[135,23,5,6],"use":"작업실"},
		{"building":7,"level":1,"rect":[141,23,4,6],"use":"뒤 창고"},
		{"building":7,"level":1,"rect":[146,23,4,6],"use":"뒤 창고"},
		{"building":7,"level":1,"rect":[151,23,4,6],"use":"뒤 창고"},
		{"building":8,"level":0,"rect":[3,35,4,8],"use":"안방"},
		{"building":8,"level":0,"rect":[11,35,4,8],"use":"안방"},
		{"building":9,"level":0,"rect":[33,39,5,8],"use":"작업실"},
		{"building":9,"level":0,"rect":[39,39,5,8],"use":"뒤 창고"},
		{"building":9,"level":0,"rect":[45,39,4,8],"use":"뒤 창고"},
		{"building":10,"level":0,"rect":[57,39,5,8],"use":"작업실"},
		{"building":10,"level":0,"rect":[63,39,5,8],"use":"뒤 창고"},
		{"building":10,"level":0,"rect":[69,39,4,8],"use":"뒤 창고"},
		{"building":11,"level":0,"rect":[83,39,5,8],"use":"작업실"},
		{"building":11,"level":0,"rect":[89,39,5,8],"use":"뒤 창고"},
		{"building":11,"level":0,"rect":[95,39,4,8],"use":"뒤 창고"},
		{"building":12,"level":0,"rect":[117,13,6,8],"use":"작업실"},
		{"building":12,"level":0,"rect":[124,13,5,8],"use":"뒤 창고"},
		{"building":13,"level":0,"rect":[117,27,3,8],"use":"매장"},
		{"building":13,"level":0,"rect":[124,27,3,8],"use":"매장"},
		{"building":14,"level":0,"rect":[91,27,5,4],"use":"작업실"},
		{"building":14,"level":0,"rect":[97,27,4,4],"use":"뒤 창고"},
		{"building":15,"level":0,"rect":[31,13,4,6],"use":"작업실"},
		{"building":15,"level":0,"rect":[31,20,4,5],"use":"뒤 창고"}],
	"props": [{"kind":"water","rect":[35,56,27,15],"solid":"low","facing":0,"note":"언 물","level":0},
		{"kind":"water","rect":[65,56,95,15],"solid":"low","facing":1,"note":"언 물","level":0},
		{"kind":"water","rect":[35,71,5,24],"solid":"low","facing":2,"note":"언 물","level":0},
		{"kind":"water","rect":[92,71,68,24],"solid":"low","facing":3,"note":"언 물","level":0},
		{"kind":"water","rect":[130,30,30,26],"solid":"low","facing":0,"note":"언 물","level":0},
		{"kind":"pier_deck","rect":[62,52,3,22],"solid":"none","facing":1,"note":"잔교","level":0},
		{"kind":"net_pile","rect":[45,77,2,2],"solid":"low","facing":0,"note":"매장의 그물 더미","level":0},
		{"kind":"desk","rect":[50,82,2,1],"solid":"low","facing":1,"note":"매장의 책상","level":0},
		{"kind":"shelf","rect":[45,82,3,1],"solid":"low","facing":2,"note":"매장의 선반","level":0},
		{"kind":"net_pile","rect":[53,77,2,2],"solid":"low","facing":0,"note":"뒤 창고의 그물 더미","level":0},
		{"kind":"desk","rect":[57,82,2,1],"solid":"low","facing":1,"note":"뒤 창고의 책상","level":0},
		{"kind":"shelf","rect":[53,82,3,1],"solid":"low","facing":2,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[60,77,2,1],"solid":"low","facing":0,"note":"작업실의 책상","level":0},
		{"kind":"shelf","rect":[60,82,3,1],"solid":"low","facing":1,"note":"작업실의 선반","level":0},
		{"kind":"net_pile","rect":[64,81,2,2],"solid":"low","facing":2,"note":"작업실의 그물 더미","level":0},
		{"kind":"net_pile","rect":[67,77,2,2],"solid":"low","facing":0,"note":"매장의 그물 더미","level":0},
		{"kind":"desk","rect":[71,82,2,1],"solid":"low","facing":1,"note":"매장의 책상","level":0},
		{"kind":"shelf","rect":[67,82,3,1],"solid":"low","facing":2,"note":"매장의 선반","level":0},
		{"kind":"net_pile","rect":[74,77,2,2],"solid":"low","facing":0,"note":"뒤 창고의 그물 더미","level":0},
		{"kind":"desk","rect":[78,82,2,1],"solid":"low","facing":1,"note":"뒤 창고의 책상","level":0},
		{"kind":"shelf","rect":[74,82,3,1],"solid":"low","facing":2,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[81,77,2,1],"solid":"low","facing":0,"note":"작업실의 책상","level":0},
		{"kind":"shelf","rect":[81,82,3,1],"solid":"low","facing":1,"note":"작업실의 선반","level":0},
		{"kind":"net_pile","rect":[85,81,2,2],"solid":"low","facing":2,"note":"작업실의 그물 더미","level":0},
		{"kind":"net_pile","rect":[45,87,2,2],"solid":"low","facing":0,"note":"매장의 그물 더미","level":0},
		{"kind":"desk","rect":[50,92,2,1],"solid":"low","facing":1,"note":"매장의 책상","level":0},
		{"kind":"shelf","rect":[45,92,3,1],"solid":"low","facing":2,"note":"매장의 선반","level":0},
		{"kind":"net_pile","rect":[53,87,2,2],"solid":"low","facing":0,"note":"뒤 창고의 그물 더미","level":0},
		{"kind":"desk","rect":[57,92,2,1],"solid":"low","facing":1,"note":"뒤 창고의 책상","level":0},
		{"kind":"shelf","rect":[53,92,3,1],"solid":"low","facing":2,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[60,87,2,1],"solid":"low","facing":0,"note":"작업실의 책상","level":0},
		{"kind":"shelf","rect":[63,92,3,1],"solid":"low","facing":1,"note":"작업실의 선반","level":0},
		{"kind":"net_pile","rect":[60,91,2,2],"solid":"low","facing":2,"note":"작업실의 그물 더미","level":0},
		{"kind":"net_pile","rect":[67,87,2,2],"solid":"low","facing":0,"note":"매장의 그물 더미","level":0},
		{"kind":"desk","rect":[71,92,2,1],"solid":"low","facing":1,"note":"매장의 책상","level":0},
		{"kind":"shelf","rect":[67,92,3,1],"solid":"low","facing":2,"note":"매장의 선반","level":0},
		{"kind":"net_pile","rect":[74,87,2,2],"solid":"low","facing":0,"note":"뒤 창고의 그물 더미","level":0},
		{"kind":"desk","rect":[78,92,2,1],"solid":"low","facing":1,"note":"뒤 창고의 책상","level":0},
		{"kind":"shelf","rect":[74,92,3,1],"solid":"low","facing":2,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[81,87,2,1],"solid":"low","facing":0,"note":"작업실의 책상","level":0},
		{"kind":"shelf","rect":[84,92,3,1],"solid":"low","facing":1,"note":"작업실의 선반","level":0},
		{"kind":"net_pile","rect":[81,91,2,2],"solid":"low","facing":2,"note":"작업실의 그물 더미","level":0},
		{"kind":"net_pile","rect":[45,77,2,2],"solid":"none","facing":0,"note":"매장의 그물 더미","level":1},
		{"kind":"desk","rect":[50,82,2,1],"solid":"none","facing":1,"note":"매장의 책상","level":1},
		{"kind":"shelf","rect":[45,82,3,1],"solid":"none","facing":2,"note":"매장의 선반","level":1},
		{"kind":"net_pile","rect":[53,77,2,2],"solid":"none","facing":0,"note":"뒤 창고의 그물 더미","level":1},
		{"kind":"desk","rect":[57,82,2,1],"solid":"none","facing":1,"note":"뒤 창고의 책상","level":1},
		{"kind":"shelf","rect":[53,82,3,1],"solid":"none","facing":2,"note":"뒤 창고의 선반","level":1},
		{"kind":"desk","rect":[60,77,2,1],"solid":"none","facing":0,"note":"작업실의 책상","level":1},
		{"kind":"shelf","rect":[60,82,3,1],"solid":"none","facing":1,"note":"작업실의 선반","level":1},
		{"kind":"net_pile","rect":[64,81,2,2],"solid":"none","facing":2,"note":"작업실의 그물 더미","level":1},
		{"kind":"net_pile","rect":[67,77,2,2],"solid":"none","facing":0,"note":"매장의 그물 더미","level":1},
		{"kind":"desk","rect":[71,82,2,1],"solid":"none","facing":1,"note":"매장의 책상","level":1},
		{"kind":"shelf","rect":[67,82,3,1],"solid":"none","facing":2,"note":"매장의 선반","level":1},
		{"kind":"net_pile","rect":[74,77,2,2],"solid":"none","facing":0,"note":"뒤 창고의 그물 더미","level":1},
		{"kind":"desk","rect":[78,82,2,1],"solid":"none","facing":1,"note":"뒤 창고의 책상","level":1},
		{"kind":"shelf","rect":[74,82,3,1],"solid":"none","facing":2,"note":"뒤 창고의 선반","level":1},
		{"kind":"desk","rect":[81,77,2,1],"solid":"none","facing":0,"note":"작업실의 책상","level":1},
		{"kind":"shelf","rect":[81,82,3,1],"solid":"none","facing":1,"note":"작업실의 선반","level":1},
		{"kind":"net_pile","rect":[85,81,2,2],"solid":"none","facing":2,"note":"작업실의 그물 더미","level":1},
		{"kind":"net_pile","rect":[45,87,2,2],"solid":"none","facing":0,"note":"매장의 그물 더미","level":1},
		{"kind":"desk","rect":[50,92,2,1],"solid":"none","facing":1,"note":"매장의 책상","level":1},
		{"kind":"shelf","rect":[45,92,3,1],"solid":"none","facing":2,"note":"매장의 선반","level":1},
		{"kind":"net_pile","rect":[53,87,2,2],"solid":"none","facing":0,"note":"뒤 창고의 그물 더미","level":1},
		{"kind":"desk","rect":[57,92,2,1],"solid":"none","facing":1,"note":"뒤 창고의 책상","level":1},
		{"kind":"shelf","rect":[53,92,3,1],"solid":"none","facing":2,"note":"뒤 창고의 선반","level":1},
		{"kind":"desk","rect":[60,87,2,1],"solid":"none","facing":0,"note":"작업실의 책상","level":1},
		{"kind":"shelf","rect":[63,92,3,1],"solid":"none","facing":1,"note":"작업실의 선반","level":1},
		{"kind":"net_pile","rect":[60,91,2,2],"solid":"none","facing":2,"note":"작업실의 그물 더미","level":1},
		{"kind":"net_pile","rect":[67,87,2,2],"solid":"none","facing":0,"note":"매장의 그물 더미","level":1},
		{"kind":"desk","rect":[71,92,2,1],"solid":"none","facing":1,"note":"매장의 책상","level":1},
		{"kind":"shelf","rect":[67,92,3,1],"solid":"none","facing":2,"note":"매장의 선반","level":1},
		{"kind":"net_pile","rect":[74,87,2,2],"solid":"none","facing":0,"note":"뒤 창고의 그물 더미","level":1},
		{"kind":"desk","rect":[78,92,2,1],"solid":"none","facing":1,"note":"뒤 창고의 책상","level":1},
		{"kind":"shelf","rect":[74,92,3,1],"solid":"none","facing":2,"note":"뒤 창고의 선반","level":1},
		{"kind":"desk","rect":[81,87,2,1],"solid":"none","facing":0,"note":"작업실의 책상","level":1},
		{"kind":"shelf","rect":[84,92,3,1],"solid":"none","facing":1,"note":"작업실의 선반","level":1},
		{"kind":"net_pile","rect":[81,91,2,2],"solid":"none","facing":2,"note":"작업실의 그물 더미","level":1},
		{"kind":"bed","rect":[45,77,2,1],"solid":"none","facing":0,"note":"매장의 침대","level":2},
		{"kind":"desk","rect":[50,82,2,1],"solid":"none","facing":1,"note":"매장의 책상","level":2},
		{"kind":"shelf","rect":[45,82,3,1],"solid":"none","facing":2,"note":"매장의 선반","level":2},
		{"kind":"bed","rect":[53,77,2,1],"solid":"none","facing":0,"note":"뒤 창고의 침대","level":2},
		{"kind":"desk","rect":[57,82,2,1],"solid":"none","facing":1,"note":"뒤 창고의 책상","level":2},
		{"kind":"shelf","rect":[53,82,3,1],"solid":"none","facing":2,"note":"뒤 창고의 선반","level":2},
		{"kind":"desk","rect":[60,77,2,1],"solid":"none","facing":0,"note":"작업실의 책상","level":2},
		{"kind":"shelf","rect":[60,82,3,1],"solid":"none","facing":1,"note":"작업실의 선반","level":2},
		{"kind":"bed","rect":[64,82,2,1],"solid":"none","facing":2,"note":"작업실의 침대","level":2},
		{"kind":"bed","rect":[67,77,2,1],"solid":"none","facing":0,"note":"매장의 침대","level":2},
		{"kind":"desk","rect":[71,82,2,1],"solid":"none","facing":1,"note":"매장의 책상","level":2},
		{"kind":"shelf","rect":[67,82,3,1],"solid":"none","facing":2,"note":"매장의 선반","level":2},
		{"kind":"bed","rect":[74,77,2,1],"solid":"none","facing":0,"note":"뒤 창고의 침대","level":2},
		{"kind":"desk","rect":[78,82,2,1],"solid":"none","facing":1,"note":"뒤 창고의 책상","level":2},
		{"kind":"shelf","rect":[74,82,3,1],"solid":"none","facing":2,"note":"뒤 창고의 선반","level":2},
		{"kind":"desk","rect":[81,77,2,1],"solid":"none","facing":0,"note":"작업실의 책상","level":2},
		{"kind":"shelf","rect":[81,82,3,1],"solid":"none","facing":1,"note":"작업실의 선반","level":2},
		{"kind":"bed","rect":[85,82,2,1],"solid":"none","facing":2,"note":"작업실의 침대","level":2},
		{"kind":"bed","rect":[45,87,2,1],"solid":"none","facing":0,"note":"매장의 침대","level":2},
		{"kind":"desk","rect":[50,92,2,1],"solid":"none","facing":1,"note":"매장의 책상","level":2},
		{"kind":"shelf","rect":[45,92,3,1],"solid":"none","facing":2,"note":"매장의 선반","level":2},
		{"kind":"bed","rect":[53,87,2,1],"solid":"none","facing":0,"note":"뒤 창고의 침대","level":2},
		{"kind":"desk","rect":[57,92,2,1],"solid":"none","facing":1,"note":"뒤 창고의 책상","level":2},
		{"kind":"shelf","rect":[53,92,3,1],"solid":"none","facing":2,"note":"뒤 창고의 선반","level":2},
		{"kind":"desk","rect":[60,87,2,1],"solid":"none","facing":0,"note":"작업실의 책상","level":2},
		{"kind":"shelf","rect":[63,92,3,1],"solid":"none","facing":1,"note":"작업실의 선반","level":2},
		{"kind":"bed","rect":[60,92,2,1],"solid":"none","facing":2,"note":"작업실의 침대","level":2},
		{"kind":"bed","rect":[67,87,2,1],"solid":"none","facing":0,"note":"매장의 침대","level":2},
		{"kind":"desk","rect":[71,92,2,1],"solid":"none","facing":1,"note":"매장의 책상","level":2},
		{"kind":"shelf","rect":[67,92,3,1],"solid":"none","facing":2,"note":"매장의 선반","level":2},
		{"kind":"bed","rect":[74,87,2,1],"solid":"none","facing":0,"note":"뒤 창고의 침대","level":2},
		{"kind":"desk","rect":[78,92,2,1],"solid":"none","facing":1,"note":"뒤 창고의 책상","level":2},
		{"kind":"shelf","rect":[74,92,3,1],"solid":"none","facing":2,"note":"뒤 창고의 선반","level":2},
		{"kind":"desk","rect":[81,87,2,1],"solid":"none","facing":0,"note":"작업실의 책상","level":2},
		{"kind":"shelf","rect":[84,92,3,1],"solid":"none","facing":1,"note":"작업실의 선반","level":2},
		{"kind":"bed","rect":[81,92,2,1],"solid":"none","facing":2,"note":"작업실의 침대","level":2},
		{"kind":"ice_block_stack","rect":[114,41,3,2],"solid":"low","facing":1,"note":"매장의 얼음 덩이 쌓음","level":0},
		{"kind":"barrel","rect":[111,50,1,1],"solid":"low","facing":2,"note":"매장의 통","level":0},
		{"kind":"freezer_chest","rect":[115,50,2,1],"solid":"low","facing":3,"note":"매장의 냉동 궤","level":0},
		{"kind":"ice_block_stack","rect":[124,41,3,2],"solid":"low","facing":1,"note":"매장의 얼음 덩이 쌓음","level":0},
		{"kind":"barrel","rect":[121,50,1,1],"solid":"low","facing":2,"note":"매장의 통","level":0},
		{"kind":"freezer_chest","rect":[125,50,2,1],"solid":"low","facing":3,"note":"매장의 냉동 궤","level":0},
		{"kind":"jar_shelf","rect":[114,41,3,1],"solid":"none","facing":1,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[111,50,1,1],"solid":"none","facing":2,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[115,50,2,1],"solid":"none","facing":3,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[124,41,3,1],"solid":"none","facing":1,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[121,50,1,1],"solid":"none","facing":2,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[125,50,2,1],"solid":"none","facing":3,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"fish_crate_stack","rect":[69,15,2,2],"solid":"none","facing":2,"note":"매장의 생선 상자 더미","level":0},
		{"kind":"shop_counter","rect":[74,17,3,1],"solid":"none","facing":3,"note":"매장의 가게 계산대","level":0},
		{"kind":"freezer_chest","rect":[69,17,2,1],"solid":"none","facing":0,"note":"매장의 냉동 궤","level":0},
		{"kind":"fish_crate_stack","rect":[78,15,2,2],"solid":"none","facing":2,"note":"뒤 창고의 생선 상자 더미","level":0},
		{"kind":"shelf","rect":[82,17,3,1],"solid":"none","facing":3,"note":"뒤 창고의 선반","level":0},
		{"kind":"freezer_chest","rect":[78,17,2,1],"solid":"none","facing":0,"note":"뒤 창고의 냉동 궤","level":0},
		{"kind":"fish_crate_stack","rect":[69,22,2,2],"solid":"none","facing":2,"note":"매장의 생선 상자 더미","level":0},
		{"kind":"shelf","rect":[74,24,3,1],"solid":"none","facing":3,"note":"매장의 선반","level":0},
		{"kind":"freezer_chest","rect":[69,24,2,1],"solid":"none","facing":0,"note":"매장의 냉동 궤","level":0},
		{"kind":"fish_crate_stack","rect":[78,22,2,2],"solid":"none","facing":2,"note":"뒤 창고의 생선 상자 더미","level":0},
		{"kind":"shelf","rect":[82,24,3,1],"solid":"none","facing":3,"note":"뒤 창고의 선반","level":0},
		{"kind":"freezer_chest","rect":[78,24,2,1],"solid":"none","facing":0,"note":"뒤 창고의 냉동 궤","level":0},
		{"kind":"bed","rect":[69,15,2,1],"solid":"none","facing":2,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[76,17,1,1],"solid":"none","facing":3,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[69,17,2,1],"solid":"none","facing":0,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[78,15,2,1],"solid":"none","facing":2,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[84,17,1,1],"solid":"none","facing":3,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[78,17,2,1],"solid":"none","facing":0,"note":"뒤 창고의 장롱","level":1},
		{"kind":"bed","rect":[69,22,2,1],"solid":"none","facing":2,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[76,24,1,1],"solid":"none","facing":3,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[69,24,2,1],"solid":"none","facing":0,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[78,22,2,1],"solid":"none","facing":2,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[84,24,1,1],"solid":"none","facing":3,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[78,24,2,1],"solid":"none","facing":0,"note":"뒤 창고의 장롱","level":1},
		{"kind":"shop_counter","rect":[94,15,3,1],"solid":"none","facing":3,"note":"작업실의 가게 계산대","level":0},
		{"kind":"shelf","rect":[91,22,3,1],"solid":"none","facing":0,"note":"작업실의 선반","level":0},
		{"kind":"display_shelf","rect":[99,15,4,1],"solid":"none","facing":3,"note":"뒤 창고의 진열대","level":0},
		{"kind":"shelf","rect":[98,22,3,1],"solid":"none","facing":0,"note":"뒤 창고의 선반","level":0},
		{"kind":"dining_set","rect":[5,11,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[8,18,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[5,18,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[10,11,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[13,18,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[10,18,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[5,20,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[8,26,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[5,26,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[10,20,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[13,26,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[10,26,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[18,11,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[21,18,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[18,18,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[23,11,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[26,18,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[23,18,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[18,20,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[21,26,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[18,26,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[23,20,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[26,26,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[23,26,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[5,11,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[8,18,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[5,18,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[10,11,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[13,18,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[10,18,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[5,20,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[8,26,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[5,26,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[10,20,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[13,26,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[10,26,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[18,11,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[21,18,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[18,18,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[23,11,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[26,18,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[23,18,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[18,20,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[21,26,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[18,26,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[23,20,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[26,26,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[23,26,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"bed","rect":[43,15,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[37,24,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[43,24,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":0},
		{"kind":"bed","rect":[55,15,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[49,24,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[55,24,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":0},
		{"kind":"bed","rect":[43,15,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[37,24,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[43,24,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":1},
		{"kind":"bed","rect":[55,15,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[49,24,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[55,24,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":1},
		{"kind":"bed","rect":[135,9,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[144,11,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[135,11,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[146,9,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[154,11,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[146,11,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[135,16,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[144,18,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[135,18,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[146,16,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[154,18,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[146,18,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[135,9,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[144,11,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[135,11,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[146,9,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[154,11,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[146,11,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[135,16,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[144,18,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[135,18,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[146,16,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[154,18,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[146,18,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"cold_stove","rect":[139,23,1,1],"solid":"low","facing":3,"note":"작업실의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[135,28,2,1],"solid":"low","facing":0,"note":"작업실의 장롱","level":0},
		{"kind":"bed","rect":[138,28,2,1],"solid":"low","facing":1,"note":"작업실의 침대","level":0},
		{"kind":"bed","rect":[143,23,2,1],"solid":"low","facing":3,"note":"뒤 창고의 침대","level":0},
		{"kind":"cold_stove","rect":[141,28,1,1],"solid":"low","facing":0,"note":"뒤 창고의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[143,28,2,1],"solid":"low","facing":1,"note":"뒤 창고의 장롱","level":0},
		{"kind":"bed","rect":[148,23,2,1],"solid":"low","facing":3,"note":"뒤 창고의 침대","level":0},
		{"kind":"cold_stove","rect":[146,28,1,1],"solid":"low","facing":0,"note":"뒤 창고의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[148,28,2,1],"solid":"low","facing":1,"note":"뒤 창고의 장롱","level":0},
		{"kind":"bed","rect":[153,23,2,1],"solid":"low","facing":3,"note":"뒤 창고의 침대","level":0},
		{"kind":"cold_stove","rect":[151,28,1,1],"solid":"low","facing":0,"note":"뒤 창고의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[153,28,2,1],"solid":"low","facing":1,"note":"뒤 창고의 장롱","level":0},
		{"kind":"cold_stove","rect":[139,23,1,1],"solid":"none","facing":3,"note":"작업실의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[135,28,2,1],"solid":"none","facing":0,"note":"작업실의 장롱","level":1},
		{"kind":"bed","rect":[138,28,2,1],"solid":"none","facing":1,"note":"작업실의 침대","level":1},
		{"kind":"bed","rect":[143,23,2,1],"solid":"none","facing":3,"note":"뒤 창고의 침대","level":1},
		{"kind":"cold_stove","rect":[141,28,1,1],"solid":"none","facing":0,"note":"뒤 창고의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[143,28,2,1],"solid":"none","facing":1,"note":"뒤 창고의 장롱","level":1},
		{"kind":"bed","rect":[148,23,2,1],"solid":"none","facing":3,"note":"뒤 창고의 침대","level":1},
		{"kind":"cold_stove","rect":[146,28,1,1],"solid":"none","facing":0,"note":"뒤 창고의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[148,28,2,1],"solid":"none","facing":1,"note":"뒤 창고의 장롱","level":1},
		{"kind":"bed","rect":[153,23,2,1],"solid":"none","facing":3,"note":"뒤 창고의 침대","level":1},
		{"kind":"cold_stove","rect":[151,28,1,1],"solid":"none","facing":0,"note":"뒤 창고의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[153,28,2,1],"solid":"none","facing":1,"note":"뒤 창고의 장롱","level":1},
		{"kind":"bed","rect":[3,35,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[6,42,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[3,42,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"bed","rect":[11,35,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[14,42,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[11,42,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"desk","rect":[36,39,2,1],"solid":"low","facing":1,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[33,45,2,2],"solid":"low","facing":2,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[35,46,3,1],"solid":"low","facing":3,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[41,39,3,1],"solid":"low","facing":1,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[39,46,2,1],"solid":"low","facing":2,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[42,45,2,2],"solid":"low","facing":3,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[46,39,3,1],"solid":"low","facing":1,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[45,46,2,1],"solid":"low","facing":2,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[47,45,2,2],"solid":"low","facing":3,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"desk","rect":[57,39,2,1],"solid":"low","facing":2,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[60,45,2,2],"solid":"low","facing":3,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[57,46,3,1],"solid":"low","facing":0,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[63,39,3,1],"solid":"low","facing":2,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[66,46,2,1],"solid":"low","facing":3,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[63,45,2,2],"solid":"low","facing":0,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[69,39,3,1],"solid":"low","facing":2,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[71,46,2,1],"solid":"low","facing":3,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[69,45,2,2],"solid":"low","facing":0,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"desk","rect":[86,39,2,1],"solid":"low","facing":3,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[83,45,2,2],"solid":"low","facing":0,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[85,46,3,1],"solid":"low","facing":1,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[91,39,3,1],"solid":"low","facing":3,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[89,46,2,1],"solid":"low","facing":0,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[92,45,2,2],"solid":"low","facing":1,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[96,39,3,1],"solid":"low","facing":3,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[95,46,2,1],"solid":"low","facing":0,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[97,45,2,2],"solid":"low","facing":1,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"desk","rect":[117,13,2,1],"solid":"low","facing":0,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[121,19,2,2],"solid":"low","facing":1,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[117,20,3,1],"solid":"low","facing":2,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[124,13,3,1],"solid":"low","facing":0,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[127,20,2,1],"solid":"low","facing":1,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[124,19,2,2],"solid":"low","facing":2,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[117,27,3,1],"solid":"low","facing":1,"note":"매장의 선반","level":0},
		{"kind":"desk","rect":[117,34,2,1],"solid":"low","facing":2,"note":"매장의 책상","level":0},
		{"kind":"shelf","rect":[124,27,3,1],"solid":"low","facing":1,"note":"매장의 선반","level":0},
		{"kind":"desk","rect":[124,34,2,1],"solid":"low","facing":2,"note":"매장의 책상","level":0},
		{"kind":"sack_pile","rect":[91,27,2,2],"solid":"none","facing":2,"note":"작업실의 자루 더미","level":0},
		{"kind":"barrel","rect":[95,30,1,1],"solid":"low","facing":3,"note":"작업실의 통","level":0},
		{"kind":"curing_barrel","rect":[91,30,1,1],"solid":"low","facing":0,"note":"작업실의 생선 절임 통","level":0},
		{"kind":"curing_barrel","rect":[97,27,1,1],"solid":"none","facing":2,"note":"뒤 창고의 생선 절임 통","level":0},
		{"kind":"sack_pile","rect":[99,27,2,2],"solid":"none","facing":3,"note":"뒤 창고의 자루 더미","level":0},
		{"kind":"barrel","rect":[100,30,1,1],"solid":"low","facing":0,"note":"뒤 창고의 통","level":0},
		{"kind":"desk","rect":[31,18,2,1],"solid":"none","facing":3,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[31,13,2,2],"solid":"none","facing":0,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"barrel","rect":[31,20,1,1],"solid":"none","facing":0,"note":"뒤 창고의 통","level":0},
		{"kind":"desk","rect":[31,24,2,1],"solid":"none","facing":0,"note":"뒤 창고의 책상","level":0},
		{"kind":"car","rect":[36,12,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
		{"kind":"bench","rect":[56,10,1,3],"solid":"low","facing":1,"note":"긴 의자","level":0},
		{"kind":"crate_stack","rect":[58,24,2,2],"solid":"low","facing":0,"note":"나무 상자 더미","level":0},
		{"kind":"firewood_pile","rect":[66,24,2,1],"solid":"low","facing":0,"note":"장작 더미","level":0},
		{"kind":"car","rect":[110,22,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
		{"kind":"fish_crate_stack","rect":[44,73,2,2],"solid":"low","facing":0,"note":"생선 상자 더미","level":0},
		{"kind":"barrel","rect":[49,72,1,1],"solid":"low","facing":1,"note":"통","level":0},
		{"kind":"ice_sled_load","rect":[53,74,3,1],"solid":"low","facing":2,"note":"짐 실은 썰매","level":0},
		{"kind":"fish_crate_stack","rect":[68,11,2,2],"solid":"none","facing":3,"note":"생선 상자 더미","level":0},
		{"kind":"barrel","rect":[73,10,1,1],"solid":"none","facing":0,"note":"통","level":0},
		{"kind":"ice_sled_load","rect":[77,12,3,1],"solid":"none","facing":1,"note":"짐 실은 썰매","level":0},
		{"kind":"fish_crate_stack","rect":[4,7,2,2],"solid":"none","facing":2,"note":"생선 상자 더미","level":0},
		{"kind":"barrel","rect":[9,6,1,1],"solid":"none","facing":3,"note":"통","level":0},
		{"kind":"fish_crate_stack","rect":[32,35,2,2],"solid":"low","facing":0,"note":"생선 상자 더미","level":0},
		{"kind":"barrel","rect":[37,34,1,1],"solid":"low","facing":1,"note":"통","level":0},
		{"kind":"ice_sled_load","rect":[41,36,3,1],"solid":"low","facing":2,"note":"짐 실은 썰매","level":0},
		{"kind":"fishing_boat","rect":[4,51,9,3],"solid":"wall","facing":3,"note":"뭍에 받친 어선","level":0},
		{"kind":"anchor","rect":[14,53,2,1],"solid":"low","facing":0,"note":"닻","level":0},
		{"kind":"mooring_post","rect":[58,53,1,1],"solid":"low","facing":1,"note":"계류 말뚝","level":0},
		{"kind":"mooring_post","rect":[67,54,1,1],"solid":"low","facing":2,"note":"계류 말뚝","level":0},
		{"kind":"rope_coil","rect":[68,53,1,1],"solid":"low","facing":3,"note":"밧줄 타래","level":0},
		{"kind":"barrel","rect":[60,53,1,1],"solid":"low","facing":0,"note":"통","level":0},
		{"kind":"crate_stack","rect":[70,52,2,2],"solid":"low","facing":1,"note":"나무 상자 더미","level":0},
		{"kind":"mooring_post","rect":[61,54,1,1],"solid":"low","facing":2,"note":"계류 말뚝","level":0},
		{"kind":"net_drying_rack","rect":[6,59,4,1],"solid":"low","facing":3,"note":"그물 건조대","level":0},
		{"kind":"net_pile","rect":[10,57,2,2],"solid":"low","facing":0,"note":"그물 더미","level":0},
		{"kind":"lamp_post","rect":[108,45,1,1],"solid":"none","facing":1,"note":"꺼진 등잔","level":0},
		{"kind":"lamp_post","rect":[22,51,1,1],"solid":"none","facing":2,"note":"꺼진 등잔","level":0},
		{"kind":"crate_stack","rect":[23,53,2,2],"solid":"low","facing":3,"note":"나무 상자 더미","level":0},
		{"kind":"street_tree","rect":[66,15,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[39,27,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[25,30,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[83,30,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[16,34,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[31,37,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[60,37,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[89,37,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[109,41,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[23,47,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[28,48,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[57,48,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[86,48,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[33,49,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[62,49,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[91,49,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[34,55,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[92,55,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[25,59,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[26,65,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[18,75,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[19,81,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[25,88,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[67,15,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[88,15,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[109,15,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[109,19,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[67,23,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[88,23,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[109,23,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[116,23,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[53,27,1,1],"solid":"tree","facing":3,"note":"가로수","level":0}],
	"containers": [{"id":"cache_0","name":"매장 상자","cell":[49,82],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_1","name":"뒤 창고 상자","cell":[58,81],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_2","name":"작업실 상자","cell":[62,81],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_3","name":"매장 상자","cell":[72,81],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_4","name":"뒤 창고 상자","cell":[79,81],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_5","name":"작업실 상자","cell":[83,81],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_6","name":"매장 상자","cell":[49,92],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_7","name":"뒤 창고 상자","cell":[56,92],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_8","name":"작업실 상자","cell":[62,92],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_9","name":"매장 상자","cell":[70,92],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_10","name":"뒤 창고 상자","cell":[77,92],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_11","name":"작업실 상자","cell":[83,92],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_12","name":"매장 상자","cell":[49,82],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_13","name":"뒤 창고 상자","cell":[58,81],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_14","name":"작업실 상자","cell":[62,81],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_15","name":"매장 상자","cell":[72,81],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_16","name":"뒤 창고 상자","cell":[79,81],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_17","name":"작업실 상자","cell":[83,81],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_18","name":"매장 상자","cell":[49,92],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_19","name":"뒤 창고 상자","cell":[56,92],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_20","name":"작업실 상자","cell":[62,92],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_21","name":"매장 상자","cell":[70,92],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_22","name":"뒤 창고 상자","cell":[77,92],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_23","name":"작업실 상자","cell":[83,92],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_24","name":"매장 상자","cell":[49,82],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_25","name":"뒤 창고 상자","cell":[58,81],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_26","name":"작업실 상자","cell":[65,81],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_27","name":"매장 상자","cell":[72,81],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_28","name":"뒤 창고 상자","cell":[79,81],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_29","name":"작업실 상자","cell":[86,81],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_30","name":"매장 상자","cell":[49,92],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_31","name":"뒤 창고 상자","cell":[56,92],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_32","name":"작업실 상자","cell":[62,92],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_33","name":"안쪽 저장 상자","cell":[70,92],"level":2,"building":0,"search":4,"items":["food_pack","food_pack","food_pack","food_pack"],"locked":true,"searched":false},
		{"id":"cache_34","name":"뒤 창고 상자","cell":[77,92],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_35","name":"작업실 상자","cell":[83,92],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_36","name":"매장 상자","cell":[114,50],"level":0,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_37","name":"매장 상자","cell":[124,50],"level":0,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_38","name":"저장 칸 상자","cell":[114,50],"level":-1,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_39","name":"저장 칸 상자","cell":[124,50],"level":-1,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_40","name":"매장 상자","cell":[72,17],"level":0,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_41","name":"뒤 창고 상자","cell":[80,17],"level":0,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_42","name":"매장 상자","cell":[72,24],"level":0,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_43","name":"뒤 창고 상자","cell":[80,24],"level":0,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_44","name":"매장 상자","cell":[75,17],"level":1,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_45","name":"뒤 창고 상자","cell":[83,17],"level":1,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_46","name":"매장 상자","cell":[75,24],"level":1,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_47","name":"뒤 창고 상자","cell":[83,24],"level":1,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_48","name":"작업실 상자","cell":[96,22],"level":0,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_49","name":"뒤 창고 상자","cell":[102,22],"level":0,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_50","name":"부엌 상자","cell":[7,18],"level":0,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_51","name":"안방 상자","cell":[12,18],"level":0,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_52","name":"부엌 상자","cell":[7,26],"level":0,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_53","name":"안방 상자","cell":[12,26],"level":0,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_54","name":"부엌 상자","cell":[20,18],"level":0,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_55","name":"안방 상자","cell":[25,18],"level":0,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_56","name":"부엌 상자","cell":[20,26],"level":0,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_57","name":"안방 상자","cell":[25,26],"level":0,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_58","name":"부엌 상자","cell":[7,18],"level":1,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_59","name":"안방 상자","cell":[12,18],"level":1,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_60","name":"부엌 상자","cell":[7,26],"level":1,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_61","name":"안방 상자","cell":[12,26],"level":1,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_62","name":"부엌 상자","cell":[20,18],"level":1,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_63","name":"안방 상자","cell":[25,18],"level":1,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_64","name":"부엌 상자","cell":[20,26],"level":1,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_65","name":"먼 끝 저장 상자","cell":[25,26],"level":1,"building":4,"search":4,"items":["food_pack","food_pack","food_pack","food_pack"],"locked":true,"searched":false},
		{"id":"cache_66","name":"안방 상자","cell":[42,24],"level":0,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_67","name":"안방 상자","cell":[54,24],"level":0,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_68","name":"안방 상자","cell":[42,24],"level":1,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_69","name":"안방 상자","cell":[54,24],"level":1,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_70","name":"안방 상자","cell":[143,11],"level":0,"building":6,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_71","name":"부엌 상자","cell":[153,11],"level":0,"building":6,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_72","name":"안방 상자","cell":[143,18],"level":0,"building":6,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_73","name":"부엌 상자","cell":[153,18],"level":0,"building":6,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_74","name":"안방 상자","cell":[143,11],"level":1,"building":6,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_75","name":"부엌 상자","cell":[153,11],"level":1,"building":6,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_76","name":"안방 상자","cell":[143,18],"level":1,"building":6,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_77","name":"부엌 상자","cell":[153,18],"level":1,"building":6,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_78","name":"작업실 상자","cell":[137,28],"level":0,"building":7,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_79","name":"뒤 창고 상자","cell":[142,28],"level":0,"building":7,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_80","name":"뒤 창고 상자","cell":[147,28],"level":0,"building":7,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_81","name":"뒤 창고 상자","cell":[152,28],"level":0,"building":7,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_82","name":"작업실 상자","cell":[137,28],"level":1,"building":7,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_83","name":"뒤 창고 상자","cell":[142,28],"level":1,"building":7,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_84","name":"뒤 창고 상자","cell":[147,28],"level":1,"building":7,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_85","name":"뒤 창고 상자","cell":[152,28],"level":1,"building":7,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_86","name":"안방 상자","cell":[5,42],"level":0,"building":8,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_87","name":"안방 상자","cell":[13,42],"level":0,"building":8,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_88","name":"작업실 상자","cell":[37,45],"level":0,"building":9,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_89","name":"뒤 창고 상자","cell":[41,46],"level":0,"building":9,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_90","name":"뒤 창고 상자","cell":[46,45],"level":0,"building":9,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_91","name":"작업실 상자","cell":[59,45],"level":0,"building":10,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_92","name":"뒤 창고 상자","cell":[65,46],"level":0,"building":10,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_93","name":"뒤 창고 상자","cell":[72,45],"level":0,"building":10,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_94","name":"작업실 상자","cell":[87,45],"level":0,"building":11,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_95","name":"뒤 창고 상자","cell":[91,46],"level":0,"building":11,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_96","name":"뒤 창고 상자","cell":[96,45],"level":0,"building":11,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_97","name":"작업실 상자","cell":[120,20],"level":0,"building":12,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_98","name":"뒤 창고 상자","cell":[126,20],"level":0,"building":12,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_99","name":"매장 상자","cell":[119,34],"level":0,"building":13,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_100","name":"매장 상자","cell":[126,34],"level":0,"building":13,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_101","name":"작업실 상자","cell":[94,30],"level":0,"building":14,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_102","name":"뒤 창고 상자","cell":[99,30],"level":0,"building":14,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_103","name":"작업실 상자","cell":[34,18],"level":0,"building":15,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_104","name":"뒤 창고 상자","cell":[34,24],"level":0,"building":15,"search":4,"items":["food_pack"],"locked":false,"searched":false}],
	"spots": [{"id":"salvage_0","kind":"salvage","name":"포장 나무","cell":[49,82],"material":"wood","amount":2,"state":"intact"},
		{"id":"salvage_1","kind":"salvage","name":"포장 나무","cell":[58,81],"material":"wood","amount":2,"state":"intact"}],
	"slots": ["G","A"],
	"dead": [[0,38],[0,48],[159,1],[159,14],[30,42],[106,46],[20,52]],
	"forecourts": [{"cell":[44,84],"normal":[-1,0],"cells":[[43,86],[43,85],[43,84],[43,83],[43,82],[42,86],[42,85],[42,84],[42,83],[42,82],[41,86],[41,85],[41,84],[41,83],[41,82],[40,86],[40,85],[40,84],[40,83],[40,82]],"building":0},
		{"cell":[87,84],"normal":[1,0],"cells":[[88,82],[88,83],[88,84],[88,85],[88,86],[89,82],[89,83],[89,84],[89,85],[89,86],[90,82],[90,83],[90,84],[90,85],[90,86],[91,82],[91,83],[91,84],[91,85],[91,86]],"building":0},
		{"cell":[118,40],"normal":[0,-1],"cells":[[116,39],[117,39],[118,39],[119,39],[120,39],[116,38],[117,38],[118,38],[119,38],[120,38],[116,37],[117,37],[118,37],[119,37],[120,37],[116,36],[117,36],[118,36],[119,36],[120,36]],"building":1},
		{"cell":[118,51],"normal":[0,1],"cells":[[120,52],[119,52],[118,52],[117,52],[116,52],[120,53],[119,53],[118,53],[117,53],[116,53],[120,54],[119,54],[118,54],[117,54],[116,54],[120,55],[119,55],[118,55],[117,55],[116,55]],"building":1},
		{"cell":[68,19],"normal":[-1,0],"cells":[[67,21],[67,20],[67,19],[67,18],[67,17],[66,21],[66,20],[66,19],[66,18],[66,17],[65,21],[65,20],[65,19],[65,18],[65,17],[64,21],[64,20],[64,19],[64,18],[64,17]],"building":2},
		{"cell":[85,19],"normal":[1,0],"cells":[[86,17],[86,18],[86,19],[86,20],[86,21],[87,17],[87,18],[87,19],[87,20],[87,21],[88,17],[88,18],[88,19],[88,20],[88,21],[89,17],[89,18],[89,19],[89,20],[89,21]],"building":2},
		{"cell":[90,19],"normal":[-1,0],"cells":[[89,21],[89,20],[89,19],[89,18],[89,17],[88,21],[88,20],[88,19],[88,18],[88,17],[87,21],[87,20],[87,19],[87,18],[87,17],[86,21],[86,20],[86,19],[86,18],[86,17]],"building":3},
		{"cell":[103,19],"normal":[1,0],"cells":[[104,17],[104,18],[104,19],[104,20],[104,21],[105,17],[105,18],[105,19],[105,20],[105,21],[106,17],[106,18],[106,19],[106,20],[106,21],[107,17],[107,18],[107,19],[107,20],[107,21]],"building":3},
		{"cell":[15,27],"normal":[0,1],"cells":[[17,28],[16,28],[15,28],[14,28],[13,28],[17,29],[16,29],[15,29],[14,29],[13,29],[17,30],[16,30],[15,30],[14,30],[13,30],[17,31],[16,31],[15,31],[14,31],[13,31]],"building":4},
		{"cell":[46,14],"normal":[0,-1],"cells":[[44,13],[45,13],[46,13],[47,13],[48,13],[44,12],[45,12],[46,12],[47,12],[48,12],[44,11],[45,11],[46,11],[47,11],[48,11],[44,10],[45,10],[46,10],[47,10],[48,10]],"building":5},
		{"cell":[46,25],"normal":[0,1],"cells":[[48,26],[47,26],[46,26],[45,26],[44,26],[48,27],[47,27],[46,27],[45,27],[44,27],[48,28],[47,28],[46,28],[45,28],[44,28],[48,29],[47,29],[46,29],[45,29],[44,29]],"building":5},
		{"cell":[134,13],"normal":[-1,0],"cells":[[133,15],[133,14],[133,13],[133,12],[133,11],[132,15],[132,14],[132,13],[132,12],[132,11],[131,15],[131,14],[131,13],[131,12],[131,11],[130,15],[130,14],[130,13],[130,12],[130,11]],"building":6},
		{"cell":[155,13],"normal":[1,0],"cells":[[156,11],[156,12],[156,13],[156,14],[156,15],[157,11],[157,12],[157,13],[157,14],[157,15],[158,11],[158,12],[158,13],[158,14],[158,15],[159,11],[159,12],[159,13],[159,14],[159,15]],"building":6},
		{"cell":[134,26],"normal":[-1,0],"cells":[[133,28],[133,27],[133,26],[133,25],[133,24],[132,28],[132,27],[132,26],[132,25],[132,24],[131,28],[131,27],[131,26],[131,25],[131,24],[130,28],[130,27],[130,26],[130,25],[130,24]],"building":7},
		{"cell":[155,26],"normal":[1,0],"cells":[[156,24],[156,25],[156,26],[156,27],[156,28],[157,24],[157,25],[157,26],[157,27],[157,28],[158,24],[158,25],[158,26],[158,27],[158,28],[159,24],[159,25],[159,26],[159,27],[159,28]],"building":7},
		{"cell":[8,34],"normal":[0,-1],"cells":[[6,33],[7,33],[8,33],[9,33],[10,33],[6,32],[7,32],[8,32],[9,32],[10,32],[6,31],[7,31],[8,31],[9,31],[10,31],[6,30],[7,30],[8,30],[9,30],[10,30]],"building":8},
		{"cell":[8,43],"normal":[0,1],"cells":[[10,44],[9,44],[8,44],[7,44],[6,44],[10,45],[9,45],[8,45],[7,45],[6,45],[10,46],[9,46],[8,46],[7,46],[6,46],[10,47],[9,47],[8,47],[7,47],[6,47]],"building":8},
		{"cell":[32,43],"normal":[-1,0],"cells":[[31,45],[31,44],[31,43],[31,42],[31,41],[30,45],[30,44],[30,43],[30,42],[30,41],[29,45],[29,44],[29,43],[29,42],[29,41],[28,45],[28,44],[28,43],[28,42],[28,41]],"building":9},
		{"cell":[49,43],"normal":[1,0],"cells":[[50,41],[50,42],[50,43],[50,44],[50,45],[51,41],[51,42],[51,43],[51,44],[51,45],[52,41],[52,42],[52,43],[52,44],[52,45],[53,41],[53,42],[53,43],[53,44],[53,45]],"building":9},
		{"cell":[56,43],"normal":[-1,0],"cells":[[55,45],[55,44],[55,43],[55,42],[55,41],[54,45],[54,44],[54,43],[54,42],[54,41],[53,45],[53,44],[53,43],[53,42],[53,41],[52,45],[52,44],[52,43],[52,42],[52,41]],"building":10},
		{"cell":[73,43],"normal":[1,0],"cells":[[74,41],[74,42],[74,43],[74,44],[74,45],[75,41],[75,42],[75,43],[75,44],[75,45],[76,41],[76,42],[76,43],[76,44],[76,45],[77,41],[77,42],[77,43],[77,44],[77,45]],"building":10},
		{"cell":[82,43],"normal":[-1,0],"cells":[[81,45],[81,44],[81,43],[81,42],[81,41],[80,45],[80,44],[80,43],[80,42],[80,41],[79,45],[79,44],[79,43],[79,42],[79,41],[78,45],[78,44],[78,43],[78,42],[78,41]],"building":11},
		{"cell":[99,43],"normal":[1,0],"cells":[[100,41],[100,42],[100,43],[100,44],[100,45],[101,41],[101,42],[101,43],[101,44],[101,45],[102,41],[102,42],[102,43],[102,44],[102,45],[103,41],[103,42],[103,43],[103,44],[103,45]],"building":11},
		{"cell":[116,17],"normal":[-1,0],"cells":[[115,19],[115,18],[115,17],[115,16],[115,15],[114,19],[114,18],[114,17],[114,16],[114,15],[113,19],[113,18],[113,17],[113,16],[113,15],[112,19],[112,18],[112,17],[112,16],[112,15]],"building":12},
		{"cell":[129,17],"normal":[1,0],"cells":[[130,15],[130,16],[130,17],[130,18],[130,19],[131,15],[131,16],[131,17],[131,18],[131,19],[132,15],[132,16],[132,17],[132,18],[132,19],[133,15],[133,16],[133,17],[133,18],[133,19]],"building":12},
		{"cell":[121,26],"normal":[0,-1],"cells":[[119,25],[120,25],[121,25],[122,25],[123,25],[119,24],[120,24],[121,24],[122,24],[123,24],[119,23],[120,23],[121,23],[122,23],[123,23],[119,22],[120,22],[121,22],[122,22],[123,22]],"building":13},
		{"cell":[121,35],"normal":[0,1],"cells":[[123,36],[122,36],[121,36],[120,36],[119,36],[123,37],[122,37],[121,37],[120,37],[119,37],[123,38],[122,38],[121,38],[120,38],[119,38],[123,39],[122,39],[121,39],[120,39],[119,39]],"building":13},
		{"cell":[90,29],"normal":[-1,0],"cells":[[89,31],[89,30],[89,29],[89,28],[89,27],[88,31],[88,30],[88,29],[88,28],[88,27],[87,31],[87,30],[87,29],[87,28],[87,27],[86,31],[86,30],[86,29],[86,28],[86,27]],"building":14},
		{"cell":[101,29],"normal":[1,0],"cells":[[102,27],[102,28],[102,29],[102,30],[102,31],[103,27],[103,28],[103,29],[103,30],[103,31],[104,27],[104,28],[104,29],[104,30],[104,31],[105,27],[105,28],[105,29],[105,30],[105,31]],"building":14},
		{"cell":[33,12],"normal":[0,-1],"cells":[[31,11],[32,11],[33,11],[34,11],[35,11],[31,10],[32,10],[33,10],[34,10],[35,10],[31,9],[32,9],[33,9],[34,9],[35,9],[31,8],[32,8],[33,8],[34,8],[35,8]],"building":15},
		{"cell":[33,25],"normal":[0,1],"cells":[[35,26],[34,26],[33,26],[32,26],[31,26],[35,27],[34,27],[33,27],[32,27],[31,27],[35,28],[34,28],[33,28],[32,28],[31,28],[35,29],[34,29],[33,29],[32,29],[31,29]],"building":15}],
	"logs": ["snow_drifts_0"],
	"deep": [{"cell":[70,92],"level":2,"id":"cache_33","distance":152},
		{"cell":[25,26],"level":1,"id":"cache_65","distance":84}]
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
		d["buildings"].append({"id": row["id"], "name": row["name"], "rect": _rect(row["rect"]), "warm": false, "window_broken": false})
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
	"number": 6,
	"width": 160,
	"height": 46,
	"judgment": "약품을 얻는 대신, 손가락처럼 갈라진 길 셋이 서로 길로 이어지지 않아 한 길을 고르면 나머지 길의 집을 못 본다.",
	"zones": [
		{
			"id": "I",
			"name": "서쪽 약방 구역",
			"rect": [
				0,
				0,
				72,
				46
			]
		},
		{
			"id": "J",
			"name": "얼어붙은 못가",
			"rect": [
				72,
				0,
				44,
				46
			]
		},
		{
			"id": "K",
			"name": "갈대 들판과 농가",
			"rect": [
				116,
				0,
				44,
				46
			]
		}
	],
	"grounds": [
		{
			"rect": [
				18,
				0,
				5,
				43
			],
			"floor": 1
		},
		{
			"rect": [
				72,
				0,
				6,
				43
			],
			"floor": 1
		},
		{
			"rect": [
				124,
				0,
				5,
				31
			],
			"floor": 1
		},
		{
			"rect": [
				6,
				9,
				12,
				4
			],
			"floor": 7
		},
		{
			"rect": [
				116,
				31,
				44,
				15
			],
			"floor": 5
		},
		{
			"rect": [
				0,
				32,
				14,
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
			"id": 16,
			"name": "마을 약방 동",
			"rect": [
				23,
				12,
				28,
				12
			],
			"top": 3,
			"basement": true,
			"role": "store",
			"stock": [
				"glass_cabinet",
				"herb_drying_rack",
				"jar_shelf",
				"blanket_crate"
			]
		},
		{
			"id": 17,
			"name": "약초 말림 헛간",
			"rect": [
				0,
				13,
				18,
				11
			],
			"top": 1,
			"basement": false,
			"role": "store",
			"stock": [
				"herb_drying_rack",
				"crate_stack",
				"shelf"
			]
		},
		{
			"id": 18,
			"name": "집",
			"rect": [
				51,
				14,
				13,
				10
			],
			"top": 2,
			"basement": false,
			"role": "home",
			"stock": [
				"glass_cabinet",
				"herb_drying_rack",
				"jar_shelf",
				"blanket_crate"
			]
		},
		{
			"id": 19,
			"name": "장작 헛간",
			"rect": [
				64,
				15,
				8,
				9
			],
			"top": 1,
			"basement": false,
			"role": "store",
			"stock": [
				"firewood_pile",
				"barrel",
				"shelf"
			]
		},
		{
			"id": 20,
			"name": "얼음 창고",
			"rect": [
				109,
				14,
				12,
				10
			],
			"top": 1,
			"basement": false,
			"role": "store",
			"stock": [
				"ice_block_stack",
				"sack_pile",
				"barrel"
			]
		},
		{
			"id": 21,
			"name": "낚시 헛간",
			"rect": [
				90,
				3,
				10,
				7
			],
			"top": 1,
			"basement": false,
			"role": "store",
			"stock": [
				"net_pile",
				"rope_coil",
				"barrel"
			]
		},
		{
			"id": 22,
			"name": "서북 외딴 집",
			"rect": [
				0,
				0,
				18,
				13
			],
			"top": 2,
			"basement": true,
			"role": "store",
			"stock": [
				"glass_cabinet",
				"jar_shelf",
				"blanket_crate"
			]
		},
		{
			"id": 23,
			"name": "북동 농가",
			"rect": [
				135,
				4,
				18,
				10
			],
			"top": 2,
			"basement": false,
			"role": "home",
			"stock": [
				"glass_cabinet",
				"herb_drying_rack",
				"jar_shelf",
				"blanket_crate"
			]
		}
	],
	"shells": [
		{
			"rect": [
				23,
				12,
				28,
				12
			],
			"building": 16,
			"level": -1
		},
		{
			"rect": [
				23,
				12,
				28,
				12
			],
			"building": 16,
			"level": 0
		},
		{
			"rect": [
				23,
				12,
				28,
				12
			],
			"building": 16,
			"level": 1
		},
		{
			"rect": [
				23,
				12,
				28,
				12
			],
			"building": 16,
			"level": 2
		},
		{
			"rect": [
				0,
				13,
				18,
				11
			],
			"building": 17,
			"level": 0
		},
		{
			"rect": [
				51,
				14,
				13,
				10
			],
			"building": 18,
			"level": 0
		},
		{
			"rect": [
				51,
				14,
				13,
				10
			],
			"building": 18,
			"level": 1
		},
		{
			"rect": [
				64,
				15,
				8,
				9
			],
			"building": 19,
			"level": 0
		},
		{
			"rect": [
				109,
				14,
				12,
				10
			],
			"building": 20,
			"level": 0
		},
		{
			"rect": [
				90,
				3,
				10,
				7
			],
			"building": 21,
			"level": 0
		},
		{
			"rect": [
				135,
				4,
				18,
				10
			],
			"building": 23,
			"level": 0
		},
		{
			"rect": [
				135,
				4,
				18,
				10
			],
			"building": 23,
			"level": 1
		},
		{
			"rect": [
				0,
				0,
				18,
				13
			],
			"building": 22,
			"level": -1
		},
		{
			"rect": [
				0,
				0,
				18,
				13
			],
			"building": 22,
			"level": 0
		},
		{
			"rect": [
				0,
				0,
				18,
				13
			],
			"building": 22,
			"level": 1
		}
	],
	"walls": [
		{
			"rect": [
				24,
				20,
				26,
				1
			],
			"level": -1
		},
		{
			"rect": [
				28,
				13,
				1,
				7
			],
			"level": -1
		},
		{
			"rect": [
				33,
				13,
				1,
				7
			],
			"level": -1
		},
		{
			"rect": [
				38,
				13,
				1,
				7
			],
			"level": -1
		},
		{
			"rect": [
				42,
				13,
				1,
				7
			],
			"level": -1
		},
		{
			"rect": [
				46,
				13,
				1,
				7
			],
			"level": -1
		},
		{
			"rect": [
				24,
				20,
				26,
				1
			],
			"level": 0
		},
		{
			"rect": [
				28,
				13,
				1,
				7
			],
			"level": 0
		},
		{
			"rect": [
				33,
				13,
				1,
				7
			],
			"level": 0
		},
		{
			"rect": [
				38,
				13,
				1,
				7
			],
			"level": 0
		},
		{
			"rect": [
				42,
				13,
				1,
				7
			],
			"level": 0
		},
		{
			"rect": [
				46,
				13,
				1,
				7
			],
			"level": 0
		},
		{
			"rect": [
				24,
				20,
				26,
				1
			],
			"level": 1
		},
		{
			"rect": [
				28,
				13,
				1,
				7
			],
			"level": 1
		},
		{
			"rect": [
				33,
				13,
				1,
				7
			],
			"level": 1
		},
		{
			"rect": [
				38,
				13,
				1,
				7
			],
			"level": 1
		},
		{
			"rect": [
				42,
				13,
				1,
				7
			],
			"level": 1
		},
		{
			"rect": [
				46,
				13,
				1,
				7
			],
			"level": 1
		},
		{
			"rect": [
				24,
				20,
				26,
				1
			],
			"level": 2
		},
		{
			"rect": [
				28,
				13,
				1,
				7
			],
			"level": 2
		},
		{
			"rect": [
				33,
				13,
				1,
				7
			],
			"level": 2
		},
		{
			"rect": [
				38,
				13,
				1,
				7
			],
			"level": 2
		},
		{
			"rect": [
				42,
				13,
				1,
				7
			],
			"level": 2
		},
		{
			"rect": [
				46,
				13,
				1,
				7
			],
			"level": 2
		},
		{
			"rect": [
				1,
				20,
				16,
				1
			],
			"level": 0
		},
		{
			"rect": [
				9,
				14,
				1,
				6
			],
			"level": 0
		},
		{
			"rect": [
				52,
				20,
				11,
				1
			],
			"level": 0
		},
		{
			"rect": [
				57,
				15,
				1,
				5
			],
			"level": 0
		},
		{
			"rect": [
				52,
				20,
				11,
				1
			],
			"level": 1
		},
		{
			"rect": [
				57,
				15,
				1,
				5
			],
			"level": 1
		},
		{
			"rect": [
				110,
				20,
				10,
				1
			],
			"level": 0
		},
		{
			"rect": [
				115,
				15,
				1,
				5
			],
			"level": 0
		},
		{
			"rect": [
				95,
				4,
				1,
				5
			],
			"level": 0
		},
		{
			"rect": [
				136,
				10,
				16,
				1
			],
			"level": 0
		},
		{
			"rect": [
				144,
				5,
				1,
				5
			],
			"level": 0
		},
		{
			"rect": [
				136,
				10,
				16,
				1
			],
			"level": 1
		},
		{
			"rect": [
				144,
				5,
				1,
				5
			],
			"level": 1
		},
		{
			"rect": [
				4,
				1,
				1,
				10
			],
			"level": -1
		},
		{
			"rect": [
				1,
				4,
				3,
				4
			],
			"level": -1
		},
		{
			"rect": [
				5,
				3,
				10,
				2
			],
			"level": -1
		},
		{
			"rect": [
				7,
				7,
				10,
				2
			],
			"level": -1
		},
		{
			"rect": [
				1,
				11,
				16,
				1
			],
			"level": -1
		},
		{
			"rect": [
				4,
				1,
				1,
				10
			],
			"level": 0
		},
		{
			"rect": [
				1,
				4,
				3,
				4
			],
			"level": 0
		},
		{
			"rect": [
				5,
				3,
				10,
				2
			],
			"level": 0
		},
		{
			"rect": [
				7,
				7,
				10,
				2
			],
			"level": 0
		},
		{
			"rect": [
				1,
				11,
				16,
				1
			],
			"level": 0
		},
		{
			"rect": [
				4,
				1,
				1,
				10
			],
			"level": 1
		},
		{
			"rect": [
				1,
				4,
				3,
				4
			],
			"level": 1
		},
		{
			"rect": [
				5,
				3,
				10,
				2
			],
			"level": 1
		},
		{
			"rect": [
				7,
				7,
				10,
				2
			],
			"level": 1
		},
		{
			"rect": [
				1,
				11,
				16,
				1
			],
			"level": 1
		}
	],
	"doors": [
		{
			"cell": [
				26,
				20
			],
			"level": -1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				31,
				20
			],
			"level": -1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				36,
				20
			],
			"level": -1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				40,
				20
			],
			"level": -1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				44,
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
				26,
				20
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				31,
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
				40,
				20
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				44,
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
				37,
				23
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				26,
				20
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				31,
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
				40,
				20
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				44,
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
				26,
				20
			],
			"level": 2,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				31,
				20
			],
			"level": 2,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				36,
				20
			],
			"level": 2,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				40,
				20
			],
			"level": 2,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				44,
				20
			],
			"level": 2,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				48,
				20
			],
			"level": 2,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				5,
				20
			],
			"level": 0,
			"building": 17,
			"state": "closed"
		},
		{
			"cell": [
				13,
				20
			],
			"level": 0,
			"building": 17,
			"state": "closed"
		},
		{
			"cell": [
				9,
				23
			],
			"level": 0,
			"building": 17,
			"state": "closed"
		},
		{
			"cell": [
				54,
				20
			],
			"level": 0,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				60,
				20
			],
			"level": 0,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				57,
				23
			],
			"level": 0,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				54,
				20
			],
			"level": 1,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				60,
				20
			],
			"level": 1,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				68,
				23
			],
			"level": 0,
			"building": 19,
			"state": "closed"
		},
		{
			"cell": [
				112,
				20
			],
			"level": 0,
			"building": 20,
			"state": "closed"
		},
		{
			"cell": [
				118,
				20
			],
			"level": 0,
			"building": 20,
			"state": "closed"
		},
		{
			"cell": [
				115,
				23
			],
			"level": 0,
			"building": 20,
			"state": "closed"
		},
		{
			"cell": [
				95,
				6
			],
			"level": 0,
			"building": 21,
			"state": "closed"
		},
		{
			"cell": [
				92,
				9
			],
			"level": 0,
			"building": 21,
			"state": "closed"
		},
		{
			"cell": [
				140,
				10
			],
			"level": 0,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				148,
				10
			],
			"level": 0,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				144,
				13
			],
			"level": 0,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				140,
				10
			],
			"level": 1,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				148,
				10
			],
			"level": 1,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				44,
				12
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				4,
				2
			],
			"level": -1,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				4,
				9
			],
			"level": -1,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				4,
				2
			],
			"level": 0,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				4,
				9
			],
			"level": 0,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				4,
				2
			],
			"level": 1,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				4,
				9
			],
			"level": 1,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				17,
				9
			],
			"level": 0,
			"building": 22,
			"state": "closed"
		}
	],
	"windows": [
		{
			"cell": [
				26,
				12
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				31,
				12
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				36,
				12
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				40,
				12
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				48,
				12
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				5,
				13
			],
			"level": 0,
			"building": 17
		},
		{
			"cell": [
				13,
				13
			],
			"level": 0,
			"building": 17
		},
		{
			"cell": [
				54,
				14
			],
			"level": 0,
			"building": 18
		},
		{
			"cell": [
				60,
				14
			],
			"level": 0,
			"building": 18
		},
		{
			"cell": [
				68,
				15
			],
			"level": 0,
			"building": 19
		},
		{
			"cell": [
				112,
				14
			],
			"level": 0,
			"building": 20
		},
		{
			"cell": [
				118,
				14
			],
			"level": 0,
			"building": 20
		},
		{
			"cell": [
				93,
				3
			],
			"level": 0,
			"building": 21
		},
		{
			"cell": [
				97,
				3
			],
			"level": 0,
			"building": 21
		},
		{
			"cell": [
				140,
				4
			],
			"level": 0,
			"building": 23
		},
		{
			"cell": [
				148,
				4
			],
			"level": 0,
			"building": 23
		},
		{
			"cell": [
				2,
				0
			],
			"level": 0,
			"building": 22
		},
		{
			"cell": [
				0,
				9
			],
			"level": 0,
			"building": 22
		}
	],
	"stairs": [
		{
			"cell": [
				25,
				21
			],
			"low": -1,
			"high": 0
		},
		{
			"cell": [
				25,
				21
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				25,
				21
			],
			"low": 1,
			"high": 2
		},
		{
			"cell": [
				48,
				21
			],
			"low": -1,
			"high": 0
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
				48,
				21
			],
			"low": 1,
			"high": 2
		},
		{
			"cell": [
				53,
				21
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				137,
				11
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				5,
				1
			],
			"low": -1,
			"high": 0
		},
		{
			"cell": [
				5,
				1
			],
			"low": 0,
			"high": 1
		}
	],
	"rooms": [
		{
			"rect": [
				24,
				13,
				4,
				7
			],
			"building": 16,
			"level": -1,
			"use": "입고 방"
		},
		{
			"rect": [
				29,
				13,
				4,
				7
			],
			"building": 16,
			"level": -1,
			"use": "비축 방"
		},
		{
			"rect": [
				34,
				13,
				4,
				7
			],
			"building": 16,
			"level": -1,
			"use": "작업 방"
		},
		{
			"rect": [
				39,
				13,
				3,
				7
			],
			"building": 16,
			"level": -1,
			"use": "접수 방"
		},
		{
			"rect": [
				43,
				13,
				3,
				7
			],
			"building": 16,
			"level": -1,
			"use": "보관 방"
		},
		{
			"rect": [
				47,
				13,
				3,
				7
			],
			"building": 16,
			"level": -1,
			"use": "안쪽 광"
		},
		{
			"rect": [
				24,
				13,
				4,
				7
			],
			"building": 16,
			"level": 0,
			"use": "입고 방"
		},
		{
			"rect": [
				29,
				13,
				4,
				7
			],
			"building": 16,
			"level": 0,
			"use": "비축 방"
		},
		{
			"rect": [
				34,
				13,
				4,
				7
			],
			"building": 16,
			"level": 0,
			"use": "작업 방"
		},
		{
			"rect": [
				39,
				13,
				3,
				7
			],
			"building": 16,
			"level": 0,
			"use": "접수 방"
		},
		{
			"rect": [
				43,
				13,
				3,
				7
			],
			"building": 16,
			"level": 0,
			"use": "보관 방"
		},
		{
			"rect": [
				47,
				13,
				3,
				7
			],
			"building": 16,
			"level": 0,
			"use": "안쪽 광"
		},
		{
			"rect": [
				24,
				13,
				4,
				7
			],
			"building": 16,
			"level": 1,
			"use": "입고 방"
		},
		{
			"rect": [
				29,
				13,
				4,
				7
			],
			"building": 16,
			"level": 1,
			"use": "비축 방"
		},
		{
			"rect": [
				34,
				13,
				4,
				7
			],
			"building": 16,
			"level": 1,
			"use": "작업 방"
		},
		{
			"rect": [
				39,
				13,
				3,
				7
			],
			"building": 16,
			"level": 1,
			"use": "접수 방"
		},
		{
			"rect": [
				43,
				13,
				3,
				7
			],
			"building": 16,
			"level": 1,
			"use": "보관 방"
		},
		{
			"rect": [
				47,
				13,
				3,
				7
			],
			"building": 16,
			"level": 1,
			"use": "안쪽 광"
		},
		{
			"rect": [
				24,
				13,
				4,
				7
			],
			"building": 16,
			"level": 2,
			"use": "입고 방"
		},
		{
			"rect": [
				29,
				13,
				4,
				7
			],
			"building": 16,
			"level": 2,
			"use": "비축 방"
		},
		{
			"rect": [
				34,
				13,
				4,
				7
			],
			"building": 16,
			"level": 2,
			"use": "작업 방"
		},
		{
			"rect": [
				39,
				13,
				3,
				7
			],
			"building": 16,
			"level": 2,
			"use": "접수 방"
		},
		{
			"rect": [
				43,
				13,
				3,
				7
			],
			"building": 16,
			"level": 2,
			"use": "보관 방"
		},
		{
			"rect": [
				47,
				13,
				3,
				7
			],
			"building": 16,
			"level": 2,
			"use": "안쪽 광"
		},
		{
			"rect": [
				1,
				14,
				8,
				6
			],
			"building": 17,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				10,
				14,
				7,
				6
			],
			"building": 17,
			"level": 0,
			"use": "보관 칸"
		},
		{
			"rect": [
				52,
				15,
				5,
				5
			],
			"building": 18,
			"level": 0,
			"use": "살림방"
		},
		{
			"rect": [
				58,
				15,
				5,
				5
			],
			"building": 18,
			"level": 0,
			"use": "부엌"
		},
		{
			"rect": [
				52,
				15,
				5,
				5
			],
			"building": 18,
			"level": 1,
			"use": "살림방"
		},
		{
			"rect": [
				58,
				15,
				5,
				5
			],
			"building": 18,
			"level": 1,
			"use": "부엌"
		},
		{
			"rect": [
				65,
				16,
				6,
				7
			],
			"building": 19,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				110,
				15,
				5,
				5
			],
			"building": 20,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				116,
				15,
				4,
				5
			],
			"building": 20,
			"level": 0,
			"use": "보관 칸"
		},
		{
			"rect": [
				91,
				4,
				4,
				5
			],
			"building": 21,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				96,
				4,
				3,
				5
			],
			"building": 21,
			"level": 0,
			"use": "보관 칸"
		},
		{
			"rect": [
				136,
				5,
				8,
				5
			],
			"building": 23,
			"level": 0,
			"use": "살림방"
		},
		{
			"rect": [
				145,
				5,
				7,
				5
			],
			"building": 23,
			"level": 0,
			"use": "부엌"
		},
		{
			"rect": [
				136,
				5,
				8,
				5
			],
			"building": 23,
			"level": 1,
			"use": "살림방"
		},
		{
			"rect": [
				145,
				5,
				7,
				5
			],
			"building": 23,
			"level": 1,
			"use": "부엌"
		},
		{
			"rect": [
				1,
				1,
				3,
				3
			],
			"building": 22,
			"level": -1,
			"use": "병 저장 칸"
		},
		{
			"rect": [
				1,
				8,
				3,
				3
			],
			"building": 22,
			"level": -1,
			"use": "안쪽 비축 방"
		},
		{
			"rect": [
				1,
				1,
				3,
				3
			],
			"building": 22,
			"level": 0,
			"use": "병 저장 칸"
		},
		{
			"rect": [
				1,
				8,
				3,
				3
			],
			"building": 22,
			"level": 0,
			"use": "안쪽 비축 방"
		},
		{
			"rect": [
				1,
				1,
				3,
				3
			],
			"building": 22,
			"level": 1,
			"use": "병 저장 칸"
		},
		{
			"rect": [
				1,
				8,
				3,
				3
			],
			"building": 22,
			"level": 1,
			"use": "안쪽 비축 방"
		}
	],
	"props": [
		{
			"kind": "glass_cabinet",
			"rect": [
				24,
				13,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 입고 방의 약장",
			"level": -1
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				24,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 입고 방의 약초 건조대",
			"level": -1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				24,
				14,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 입고 방의 병조림 선반",
			"level": -1
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				29,
				13,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 비축 방의 약장",
			"level": -1
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				29,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 비축 방의 약초 건조대",
			"level": -1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				29,
				14,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 비축 방의 병조림 선반",
			"level": -1
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				34,
				13,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 작업 방의 약장",
			"level": -1
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				34,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 작업 방의 약초 건조대",
			"level": -1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				34,
				14,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 작업 방의 병조림 선반",
			"level": -1
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				39,
				13,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 접수 방의 약장",
			"level": -1
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				39,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 접수 방의 약초 건조대",
			"level": -1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				39,
				14,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 접수 방의 병조림 선반",
			"level": -1
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				43,
				13,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 보관 방의 약장",
			"level": -1
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				43,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 보관 방의 약초 건조대",
			"level": -1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				43,
				14,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 보관 방의 병조림 선반",
			"level": -1
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				47,
				13,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 안쪽 광의 약장",
			"level": -1
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				47,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 안쪽 광의 약초 건조대",
			"level": -1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				47,
				14,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 안쪽 광의 병조림 선반",
			"level": -1
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				24,
				13,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "마을 약방 동 입고 방의 약장",
			"level": 0
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				24,
				14,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "마을 약방 동 입고 방의 약초 건조대",
			"level": 0
		},
		{
			"kind": "shop_counter",
			"rect": [
				24,
				15,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "마을 약방 동 진열 홀의 계산대",
			"level": 0
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				29,
				13,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "마을 약방 동 비축 방의 약장",
			"level": 0
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				29,
				14,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "마을 약방 동 비축 방의 약초 건조대",
			"level": 0
		},
		{
			"kind": "jar_shelf",
			"rect": [
				29,
				15,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "마을 약방 동 비축 방의 병조림 선반",
			"level": 0
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				34,
				13,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "마을 약방 동 작업 방의 약장",
			"level": 0
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				34,
				14,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "마을 약방 동 작업 방의 약초 건조대",
			"level": 0
		},
		{
			"kind": "jar_shelf",
			"rect": [
				34,
				15,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "마을 약방 동 작업 방의 병조림 선반",
			"level": 0
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				39,
				13,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "마을 약방 동 접수 방의 약장",
			"level": 0
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				39,
				14,
				1,
				3
			],
			"solid": "low",
			"facing": 0,
			"note": "마을 약방 동 접수 방의 약초 건조대",
			"level": 0
		},
		{
			"kind": "jar_shelf",
			"rect": [
				41,
				14,
				1,
				3
			],
			"solid": "low",
			"facing": 0,
			"note": "마을 약방 동 접수 방의 병조림 선반",
			"level": 0
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				43,
				16,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "마을 약방 동 보관 방의 약장",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				43,
				13,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "마을 약방 동 보관 방의 통",
			"level": 0
		},
		{
			"kind": "cold_stove",
			"rect": [
				45,
				13,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "마을 약방 동 보관 방의 꺼진 난로",
			"level": 0
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				47,
				13,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "마을 약방 동 안쪽 광의 약장",
			"level": 0
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				47,
				14,
				1,
				3
			],
			"solid": "low",
			"facing": 0,
			"note": "마을 약방 동 안쪽 광의 약초 건조대",
			"level": 0
		},
		{
			"kind": "jar_shelf",
			"rect": [
				49,
				14,
				1,
				3
			],
			"solid": "low",
			"facing": 0,
			"note": "마을 약방 동 안쪽 광의 병조림 선반",
			"level": 0
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				24,
				13,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 입고 방의 약장",
			"level": 1
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				24,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 입고 방의 약초 건조대",
			"level": 1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				24,
				14,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 입고 방의 병조림 선반",
			"level": 1
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				29,
				13,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 비축 방의 약장",
			"level": 1
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				29,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 비축 방의 약초 건조대",
			"level": 1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				29,
				14,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 비축 방의 병조림 선반",
			"level": 1
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				34,
				13,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 작업 방의 약장",
			"level": 1
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				34,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 작업 방의 약초 건조대",
			"level": 1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				34,
				14,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 작업 방의 병조림 선반",
			"level": 1
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				39,
				13,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 접수 방의 약장",
			"level": 1
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				39,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 접수 방의 약초 건조대",
			"level": 1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				39,
				14,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 접수 방의 병조림 선반",
			"level": 1
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				43,
				13,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 보관 방의 약장",
			"level": 1
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				43,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 보관 방의 약초 건조대",
			"level": 1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				43,
				14,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 보관 방의 병조림 선반",
			"level": 1
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				47,
				13,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 안쪽 광의 약장",
			"level": 1
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				47,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 안쪽 광의 약초 건조대",
			"level": 1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				47,
				14,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 안쪽 광의 병조림 선반",
			"level": 1
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				24,
				13,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 입고 방의 약장",
			"level": 2
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				24,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 입고 방의 약초 건조대",
			"level": 2
		},
		{
			"kind": "jar_shelf",
			"rect": [
				24,
				14,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 입고 방의 병조림 선반",
			"level": 2
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				29,
				13,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 비축 방의 약장",
			"level": 2
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				29,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 비축 방의 약초 건조대",
			"level": 2
		},
		{
			"kind": "jar_shelf",
			"rect": [
				29,
				14,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 비축 방의 병조림 선반",
			"level": 2
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				34,
				13,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 작업 방의 약장",
			"level": 2
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				34,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 작업 방의 약초 건조대",
			"level": 2
		},
		{
			"kind": "jar_shelf",
			"rect": [
				34,
				14,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 작업 방의 병조림 선반",
			"level": 2
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				39,
				13,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 접수 방의 약장",
			"level": 2
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				39,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 접수 방의 약초 건조대",
			"level": 2
		},
		{
			"kind": "jar_shelf",
			"rect": [
				39,
				14,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 접수 방의 병조림 선반",
			"level": 2
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				43,
				13,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 보관 방의 약장",
			"level": 2
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				43,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 보관 방의 약초 건조대",
			"level": 2
		},
		{
			"kind": "jar_shelf",
			"rect": [
				43,
				14,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 보관 방의 병조림 선반",
			"level": 2
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				47,
				13,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 안쪽 광의 약장",
			"level": 2
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				47,
				19,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 안쪽 광의 약초 건조대",
			"level": 2
		},
		{
			"kind": "jar_shelf",
			"rect": [
				47,
				14,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "마을 약방 동 안쪽 광의 병조림 선반",
			"level": 2
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				1,
				14,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "약초 말림 헛간 작업 칸의 약초 건조대",
			"level": 0
		},
		{
			"kind": "crate_stack",
			"rect": [
				7,
				14,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "약초 말림 헛간 작업 칸의 나무 상자 더미",
			"level": 0
		},
		{
			"kind": "shelf",
			"rect": [
				1,
				19,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "약초 말림 헛간 작업 칸의 선반",
			"level": 0
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				10,
				14,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "약초 말림 헛간 보관 칸의 약초 건조대",
			"level": 0
		},
		{
			"kind": "crate_stack",
			"rect": [
				15,
				14,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "약초 말림 헛간 보관 칸의 나무 상자 더미",
			"level": 0
		},
		{
			"kind": "shelf",
			"rect": [
				10,
				19,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "약초 말림 헛간 보관 칸의 선반",
			"level": 0
		},
		{
			"kind": "bed",
			"rect": [
				52,
				15,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "집 살림방의 침대",
			"level": 0
		},
		{
			"kind": "wardrobe",
			"rect": [
				52,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "집 살림방의 장롱",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				55,
				15,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "집 살림방의 책상",
			"level": 0
		},
		{
			"kind": "dining_set",
			"rect": [
				58,
				15,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "집 부엌의 식탁",
			"level": 0
		},
		{
			"kind": "fridge_open",
			"rect": [
				62,
				15,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "집 부엌의 냉장고",
			"level": 0
		},
		{
			"kind": "cold_stove",
			"rect": [
				58,
				19,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "집 부엌의 꺼진 난로",
			"level": 0
		},
		{
			"kind": "bed",
			"rect": [
				52,
				15,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "집 살림방의 침대",
			"level": 1
		},
		{
			"kind": "wardrobe",
			"rect": [
				52,
				19,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "집 살림방의 장롱",
			"level": 1
		},
		{
			"kind": "desk",
			"rect": [
				55,
				15,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "집 살림방의 책상",
			"level": 1
		},
		{
			"kind": "dining_set",
			"rect": [
				58,
				15,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "집 부엌의 식탁",
			"level": 1
		},
		{
			"kind": "fridge_open",
			"rect": [
				62,
				15,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "집 부엌의 냉장고",
			"level": 1
		},
		{
			"kind": "cold_stove",
			"rect": [
				58,
				19,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "집 부엌의 꺼진 난로",
			"level": 1
		},
		{
			"kind": "firewood_pile",
			"rect": [
				65,
				16,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "장작 헛간 작업 칸의 장작 더미",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				70,
				16,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "장작 헛간 작업 칸의 통",
			"level": 0
		},
		{
			"kind": "shelf",
			"rect": [
				65,
				22,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "장작 헛간 작업 칸의 선반",
			"level": 0
		},
		{
			"kind": "ice_block_stack",
			"rect": [
				110,
				15,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "얼음 창고 작업 칸의 얼음 덩이 쌓음",
			"level": 0
		},
		{
			"kind": "sack_pile",
			"rect": [
				113,
				15,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "얼음 창고 작업 칸의 자루 더미",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				110,
				19,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "얼음 창고 작업 칸의 통",
			"level": 0
		},
		{
			"kind": "ice_block_stack",
			"rect": [
				116,
				15,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "얼음 창고 보관 칸의 얼음 덩이 쌓음",
			"level": 0
		},
		{
			"kind": "sack_pile",
			"rect": [
				116,
				18,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "얼음 창고 보관 칸의 자루 더미",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				119,
				15,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "얼음 창고 보관 칸의 통",
			"level": 0
		},
		{
			"kind": "net_pile",
			"rect": [
				91,
				4,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "낚시 헛간 작업 칸의 그물 더미",
			"level": 0
		},
		{
			"kind": "rope_coil",
			"rect": [
				94,
				4,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "낚시 헛간 작업 칸의 밧줄 타래",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				94,
				8,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "낚시 헛간 작업 칸의 통",
			"level": 0
		},
		{
			"kind": "net_pile",
			"rect": [
				96,
				4,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "낚시 헛간 보관 칸의 그물 더미",
			"level": 0
		},
		{
			"kind": "rope_coil",
			"rect": [
				98,
				4,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "낚시 헛간 보관 칸의 밧줄 타래",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				98,
				8,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "낚시 헛간 보관 칸의 통",
			"level": 0
		},
		{
			"kind": "bed",
			"rect": [
				136,
				5,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "북동 농가 살림방의 침대",
			"level": 0
		},
		{
			"kind": "wardrobe",
			"rect": [
				136,
				9,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "북동 농가 살림방의 장롱",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				142,
				5,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "북동 농가 살림방의 책상",
			"level": 0
		},
		{
			"kind": "dining_set",
			"rect": [
				145,
				5,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "북동 농가 부엌의 식탁",
			"level": 0
		},
		{
			"kind": "fridge_open",
			"rect": [
				151,
				5,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "북동 농가 부엌의 냉장고",
			"level": 0
		},
		{
			"kind": "cold_stove",
			"rect": [
				151,
				9,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "북동 농가 부엌의 꺼진 난로",
			"level": 0
		},
		{
			"kind": "bed",
			"rect": [
				136,
				5,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "북동 농가 살림방의 침대",
			"level": 1
		},
		{
			"kind": "wardrobe",
			"rect": [
				136,
				9,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "북동 농가 살림방의 장롱",
			"level": 1
		},
		{
			"kind": "desk",
			"rect": [
				142,
				5,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "북동 농가 살림방의 책상",
			"level": 1
		},
		{
			"kind": "dining_set",
			"rect": [
				145,
				5,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "북동 농가 부엌의 식탁",
			"level": 1
		},
		{
			"kind": "fridge_open",
			"rect": [
				151,
				5,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "북동 농가 부엌의 냉장고",
			"level": 1
		},
		{
			"kind": "cold_stove",
			"rect": [
				151,
				9,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "북동 농가 부엌의 꺼진 난로",
			"level": 1
		},
		{
			"kind": "ice_sled_load",
			"rect": [
				28,
				38,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "짐 실은 썰매",
			"level": 0
		},
		{
			"kind": "crate_stack",
			"rect": [
				52,
				41,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "나무 상자 더미",
			"level": 0
		},
		{
			"kind": "garden_bed",
			"rect": [
				68,
				35,
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
				96,
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
			"kind": "water",
			"rect": [
				78,
				14,
				31,
				10
			],
			"solid": "low",
			"facing": 0,
			"note": "마당의 작업 물건",
			"level": 0
		},
		{
			"kind": "herb_drying_rack",
			"rect": [
				35,
				10,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "약초 건조대",
			"level": 0
		},
		{
			"kind": "jar_shelf",
			"rect": [
				38,
				8,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "병조림 선반",
			"level": 0
		},
		{
			"kind": "crate_stack",
			"rect": [
				36,
				5,
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
				40,
				10,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "통",
			"level": 0
		},
		{
			"kind": "bench",
			"rect": [
				80,
				11,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "긴 의자",
			"level": 0
		},
		{
			"kind": "ice_sled_load",
			"rect": [
				85,
				12,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "짐 실은 썰매",
			"level": 0
		},
		{
			"kind": "rope_coil",
			"rect": [
				83,
				9,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "밧줄 타래",
			"level": 0
		},
		{
			"kind": "street_tree",
			"rect": [
				24,
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
				27,
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
				30,
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
				25,
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
			"kind": "street_tree",
			"rect": [
				31,
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
				130,
				15,
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
				133,
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
				131,
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
			"kind": "bare_orchard_tree",
			"rect": [
				154,
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
				157,
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
				155,
				9,
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
				11,
				1,
				1
			],
			"solid": "tree",
			"facing": 0,
			"note": "눈 덮인 마른 나무 무리",
			"level": 0
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				1,
				1,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "서북 외딴 집 병 저장 칸의 약장",
			"level": -1
		},
		{
			"kind": "barrel",
			"rect": [
				3,
				1,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "서북 외딴 집 병 저장 칸의 통",
			"level": -1
		},
		{
			"kind": "blanket_crate",
			"rect": [
				1,
				3,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "서북 외딴 집 병 저장 칸의 담요 상자",
			"level": -1
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				1,
				8,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "서북 외딴 집 안쪽 비축 방의 약장",
			"level": -1
		},
		{
			"kind": "barrel",
			"rect": [
				3,
				8,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "서북 외딴 집 안쪽 비축 방의 통",
			"level": -1
		},
		{
			"kind": "blanket_crate",
			"rect": [
				1,
				10,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "서북 외딴 집 안쪽 비축 방의 담요 상자",
			"level": -1
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				1,
				1,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "서북 외딴 집 병 저장 칸의 약장",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				3,
				1,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "서북 외딴 집 병 저장 칸의 통",
			"level": 0
		},
		{
			"kind": "blanket_crate",
			"rect": [
				1,
				3,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "서북 외딴 집 병 저장 칸의 담요 상자",
			"level": 0
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				1,
				8,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "서북 외딴 집 안쪽 비축 방의 약장",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				3,
				8,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "서북 외딴 집 안쪽 비축 방의 통",
			"level": 0
		},
		{
			"kind": "blanket_crate",
			"rect": [
				1,
				10,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "서북 외딴 집 안쪽 비축 방의 담요 상자",
			"level": 0
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				1,
				1,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "서북 외딴 집 병 저장 칸의 약장",
			"level": 1
		},
		{
			"kind": "barrel",
			"rect": [
				3,
				1,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "서북 외딴 집 병 저장 칸의 통",
			"level": 1
		},
		{
			"kind": "blanket_crate",
			"rect": [
				1,
				3,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "서북 외딴 집 병 저장 칸의 담요 상자",
			"level": 1
		},
		{
			"kind": "glass_cabinet",
			"rect": [
				1,
				8,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "서북 외딴 집 안쪽 비축 방의 약장",
			"level": 1
		},
		{
			"kind": "barrel",
			"rect": [
				3,
				8,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "서북 외딴 집 안쪽 비축 방의 통",
			"level": 1
		},
		{
			"kind": "blanket_crate",
			"rect": [
				1,
				10,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "서북 외딴 집 안쪽 비축 방의 담요 상자",
			"level": 1
		}
	],
	"containers": [
		{
			"id": "north_cache_0",
			"name": "마을 약방 동 입고 방 상자",
			"cell": [
				27,
				13
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_1",
			"name": "마을 약방 동 비축 방 상자",
			"cell": [
				32,
				13
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_2",
			"name": "마을 약방 동 작업 방 상자",
			"cell": [
				37,
				13
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_3",
			"name": "마을 약방 동 접수 방 상자",
			"cell": [
				41,
				13
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_4",
			"name": "마을 약방 동 보관 방 상자",
			"cell": [
				45,
				13
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_5",
			"name": "마을 약방 동 안쪽 광 상자",
			"cell": [
				49,
				13
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_6",
			"name": "마을 약방 동 입고 방 상자",
			"cell": [
				27,
				13
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_7",
			"name": "마을 약방 동 비축 방 상자",
			"cell": [
				32,
				13
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_8",
			"name": "마을 약방 동 작업 방 상자",
			"cell": [
				37,
				13
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_9",
			"name": "마을 약방 동 접수 방 상자",
			"cell": [
				40,
				16
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_10",
			"name": "마을 약방 동 보관 방 상자",
			"cell": [
				43,
				19
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_11",
			"name": "마을 약방 동 안쪽 광 상자",
			"cell": [
				48,
				16
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_12",
			"name": "마을 약방 동 입고 방 상자",
			"cell": [
				27,
				13
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_13",
			"name": "마을 약방 동 비축 방 상자",
			"cell": [
				32,
				13
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_14",
			"name": "마을 약방 동 작업 방 상자",
			"cell": [
				37,
				13
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_15",
			"name": "마을 약방 동 접수 방 상자",
			"cell": [
				41,
				13
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_16",
			"name": "마을 약방 동 보관 방 상자",
			"cell": [
				45,
				13
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_17",
			"name": "마을 약방 동 안쪽 광 상자",
			"cell": [
				49,
				13
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_18",
			"name": "마을 약방 동 입고 방 상자",
			"cell": [
				27,
				13
			],
			"level": 2,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_19",
			"name": "마을 약방 동 비축 방 상자",
			"cell": [
				32,
				13
			],
			"level": 2,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_20",
			"name": "마을 약방 동 작업 방 상자",
			"cell": [
				37,
				13
			],
			"level": 2,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_21",
			"name": "마을 약방 동 접수 방 상자",
			"cell": [
				41,
				13
			],
			"level": 2,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_22",
			"name": "마을 약방 동 보관 방 상자",
			"cell": [
				45,
				13
			],
			"level": 2,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_23",
			"name": "마을 약방 동 안쪽 광 상자",
			"cell": [
				49,
				13
			],
			"level": 2,
			"building": 16,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_24",
			"name": "약초 말림 헛간 작업 칸 상자",
			"cell": [
				8,
				19
			],
			"level": 0,
			"building": 17,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_25",
			"name": "약초 말림 헛간 보관 칸 상자",
			"cell": [
				16,
				19
			],
			"level": 0,
			"building": 17,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_26",
			"name": "집 살림방 상자",
			"cell": [
				56,
				19
			],
			"level": 0,
			"building": 18,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_27",
			"name": "집 부엌 상자",
			"cell": [
				62,
				19
			],
			"level": 0,
			"building": 18,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_28",
			"name": "집 살림방 상자",
			"cell": [
				56,
				19
			],
			"level": 1,
			"building": 18,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_29",
			"name": "집 부엌 상자",
			"cell": [
				62,
				19
			],
			"level": 1,
			"building": 18,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_30",
			"name": "장작 헛간 작업 칸 상자",
			"cell": [
				70,
				22
			],
			"level": 0,
			"building": 19,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_31",
			"name": "얼음 창고 작업 칸 상자",
			"cell": [
				114,
				19
			],
			"level": 0,
			"building": 20,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_32",
			"name": "얼음 창고 보관 칸 상자",
			"cell": [
				119,
				19
			],
			"level": 0,
			"building": 20,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_33",
			"name": "낚시 헛간 작업 칸 상자",
			"cell": [
				91,
				8
			],
			"level": 0,
			"building": 21,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_34",
			"name": "낚시 헛간 보관 칸 상자",
			"cell": [
				96,
				8
			],
			"level": 0,
			"building": 21,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_41",
			"name": "북동 농가 살림방 상자",
			"cell": [
				143,
				9
			],
			"level": 0,
			"building": 23,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_42",
			"name": "북동 농가 부엌 상자",
			"cell": [
				145,
				9
			],
			"level": 0,
			"building": 23,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_43",
			"name": "북동 농가 살림방 상자",
			"cell": [
				143,
				9
			],
			"level": 1,
			"building": 23,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_44",
			"name": "북동 농가 부엌 상자",
			"cell": [
				145,
				9
			],
			"level": 1,
			"building": 23,
			"search": 4,
			"items": [
				"med_box"
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
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_remote_-1_1",
			"name": "서북 외딴 집 병 저장 칸 상자",
			"cell": [
				3,
				3
			],
			"level": -1,
			"building": 22,
			"search": 8,
			"items": [
				"med_box",
				"med_box",
				"bandage",
				"tweezers"
			],
			"locked": true,
			"searched": false
		},
		{
			"id": "north_remote_-1_8",
			"name": "서북 외딴 집 안쪽 비축 방 상자",
			"cell": [
				3,
				10
			],
			"level": -1,
			"building": 22,
			"search": 8,
			"items": [
				"med_box",
				"med_box",
				"bandage",
				"tweezers"
			],
			"locked": true,
			"searched": false
		},
		{
			"id": "north_remote_0_1",
			"name": "서북 외딴 집 병 저장 칸 상자",
			"cell": [
				3,
				3
			],
			"level": 0,
			"building": 22,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_remote_0_8",
			"name": "서북 외딴 집 안쪽 비축 방 상자",
			"cell": [
				3,
				10
			],
			"level": 0,
			"building": 22,
			"search": 4,
			"items": [
				"med_box"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_remote_1_1",
			"name": "서북 외딴 집 병 저장 칸 상자",
			"cell": [
				3,
				3
			],
			"level": 1,
			"building": 22,
			"search": 8,
			"items": [
				"med_box",
				"med_box",
				"bandage",
				"tweezers"
			],
			"locked": true,
			"searched": false
		},
		{
			"id": "north_remote_1_8",
			"name": "서북 외딴 집 안쪽 비축 방 상자",
			"cell": [
				3,
				10
			],
			"level": 1,
			"building": 22,
			"search": 8,
			"items": [
				"med_box",
				"med_box",
				"bandage",
				"tweezers"
			],
			"locked": true,
			"searched": false
		}
	],
	"entries": [
		{
			"id": "서쪽 약방 길",
			"name": "서쪽 약방 길",
			"cells": [
				[
					19,
					0
				],
				[
					20,
					0
				],
				[
					21,
					0
				],
				[
					22,
					0
				]
			],
			"gap": 2.5
		},
		{
			"id": "못가 약초 길",
			"name": "못가 약초 길",
			"cells": [
				[
					73,
					0
				],
				[
					74,
					0
				],
				[
					75,
					0
				],
				[
					76,
					0
				]
			],
			"gap": 2.5
		},
		{
			"id": "북동 농가 길",
			"name": "북동 농가 길",
			"cells": [
				[
					125,
					0
				],
				[
					126,
					0
				],
				[
					127,
					0
				],
				[
					128,
					0
				]
			],
			"gap": 0.6
		}
	],
	"holes": [
		{
			"id": "manhole_02",
			"name": "못가 길 맨홀",
			"cell": [
				74,
				12
			],
			"level": 0
		}
	],
	"barricades": [
		[
			19,
			22
		],
		[
			21,
			22
		],
		[
			73,
			22
		],
		[
			76,
			22
		]
	],
	"slots": [
		"I"
	],
	"deep": 6,
	"forecourts": [
		[
			35,
			24,
			5,
			4
		],
		[
			7,
			24,
			5,
			4
		],
		[
			55,
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
			113,
			24,
			5,
			4
		],
		[
			90,
			10,
			5,
			4
		],
		[
			18,
			7,
			4,
			5
		],
		[
			142,
			14,
			5,
			4
		]
	],
	"crossings": [
		32,
		64
	],
	"stock": [
		"glass_cabinet",
		"herb_drying_rack",
		"jar_shelf",
		"blanket_crate"
	],
	"loot": [
		"med_box",
		"bandage",
		"tweezers"
	],
	"assumptions": [
		"나무는 서쪽 길 곁 두 그루를 보충하여 열두 그루다. 새 맨홀을 더한 전체 구멍 수는 넷이다.",
		"위쪽 문 앞 세 칸을 비우려고 띠 안 상자 더미를 두 칸 동쪽으로 옮겼다.",
		"위쪽 문 앞 세 칸을 비우려고 띠 안 상자 더미를 두 칸 동쪽으로 옮겼다.",
		"서북 집은 서쪽 가장자리의 열여덟 칸 곱하기 열세 칸으로 넓히고 동쪽 문, 폭 두 칸의 굽은 복도와 겹친 계단실을 두었다. 북동 농가보다 서북 비축 방이 실제로 더 깊도록 조정했다."
	]
}

const SOUTH_TREE_MOVES: Array = [[[31,37],[20,31]],[[25,59],[29,67]],[[28,48],[26,49]],[[57,48],[55,38]],[[62,49],[52,40]],[[26,65],[32,69]],[[88,15],[88,31]],[[109,19],[119,25]],[[88,23],[78,31]],[[52,40],[50,39]],[[55,38],[53,41]]]
const SOUTH_WORK: Dictionary = {"name":"얼음 창고 작업 구역","cell":[116,54],"rect":[109,52,19,4]}

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
		data["buildings"].append({"id": row["id"], "name": row["name"], "rect": _rect(row["rect"]), "warm": false, "window_broken": false})
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
const ENTRY_NAMES: Dictionary = {"west_sand": "서쪽 모래밭", "west_lower": "서쪽 아랫길", "east_track": "동쪽 선로", "east_field": "동쪽 들판", "manhole_01": "첫째 맨홀", "drain_01": "첫째 배수구", "drain_02": "둘째 배수구", "서쪽 약방 길": "서쪽 약방 길", "못가 약초 길": "못가 약초 길", "북동 농가 길": "북동 농가 길", "manhole_02": "둘째 맨홀"}
const ENTRY_WEIGHTS: Dictionary = {"west_sand": 0.5, "west_lower": 1.0, "east_track": 1.0, "east_field": 0.5, "manhole_01": 0.3, "drain_01": 1.0, "drain_02": 1.0, "서쪽 약방 길": 0.5, "못가 약초 길": 0.5, "북동 농가 길": 1.0, "manhole_02": 0.3}
const FIRST_ENTRY: String = "west_lower"


static func build() -> Dictionary:
	var data: Dictionary = _build_plain()
	data["entry_names"] = ENTRY_NAMES.duplicate()
	data["entry_weights"] = ENTRY_WEIGHTS.duplicate()
	data["first_entry"] = FIRST_ENTRY
	return data
