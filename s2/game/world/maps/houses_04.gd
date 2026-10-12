# 이 지도가 다른 판단을 만드는 것: 가게마다 앞문과 뒷문 가운데 고른다. 안마당은 통로문 하나가 길목이자 퇴로다.
# 위쪽의 판단: 기름과 석탄을 많이 얻는 대신, 쇠통을 끌고 골목 그물을 지나는 소리가 커서 무리를 불러들이고 아래쪽 가게 한 동을 놓친다.
extends RefCounted

const FieldGrid = preload("res://game/world/field_grid.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 175
const SOUTH_HEIGHT: int = 105
const HEIGHT: int = SOUTH_HEIGHT + 45
const PLACE_ID: String = "houses_04"

# 각 좌표는 이 지도의 독립 평면이다. 위층 장식은 충돌을 만들지 않는다.
const PLAN: Dictionary = {
	"number": 4,
	"width": 175,
	"height": 105,
	"judgment": "가게마다 앞문과 뒷문 가운데 고른다. 안마당은 통로문 하나가 길목이자 퇴로다.",
	"zones": [{"id":"A","name":"승강장 앞 상점","rect":[0,0,175,30]},
		{"id":"B","name":"서쪽 뒷골목","rect":[0,30,114,24]},
		{"id":"C","name":"시장 마당","rect":[114,30,61,24]},
		{"id":"D","name":"곡물 골목","rect":[0,54,57,51]},
		{"id":"E","name":"식료품점 뒤편","rect":[57,54,57,51]},
		{"id":"F","name":"안마당","rect":[114,54,61,51]},
		{"id":"G","name":"남쪽 창고","rect":[0,87,175,18]},
		{"id":"H","name":"동쪽 상점","rect":[135,4,40,26]}],
	"grounds": [{"rect":[56,10,6,38],"floor":1},
		{"rect":[34,44,141,5],"floor":1},
		{"rect":[114,44,6,61],"floor":1},
		{"rect":[0,60,40,4],"floor":1},
		{"rect":[30,56,4,49],"floor":1},
		{"rect":[36,36,4,48],"floor":1},
		{"rect":[120,80,55,4],"floor":1},
		{"rect":[84,49,29,5],"floor":1},
		{"rect":[104,24,24,19],"floor":0},
		{"rect":[100,10,16,20],"floor":5},
		{"rect":[58,48,6,10],"floor":1}],
	"buildings": [{"name":"식료품점동","rect":[40,58,44,22],"top":4,"basement":true,"role":"shopmain","main":true,"stock":["display_shelf","shop_counter","tin_crate"],"id":0},
		{"name":"빵집과 정육점동","rect":[18,20,32,16],"top":4,"basement":true,"role":"shop","stock":["bread_rack","butcher_block","freezer_chest"],"id":1},
		{"name":"약국동","rect":[66,20,32,16],"top":4,"basement":false,"role":"shop","stock":["glass_cabinet","shop_counter","shelf"],"id":2},
		{"name":"철물점동","rect":[4,40,30,16],"top":4,"basement":false,"role":"shop","stock":["hardware_rack","shop_counter","desk"],"id":3},
		{"name":"옷가게동","rect":[136,20,32,16],"top":4,"basement":false,"role":"shop","stock":["cloth_bolt_rack","shop_counter","desk"],"id":4},
		{"name":"가게 겸 살림 동","rect":[134,54,34,16],"top":4,"basement":false,"role":"shop","stock":["display_shelf","shop_counter","shelf"],"id":5},
		{"name":"곡물 가게","rect":[4,80,20,12],"top":2,"basement":false,"role":"shop","stock":["flour_sack_pile","shop_counter","shelf"],"id":6},
		{"name":"통조림 도매 창고","rect":[142,84,24,14],"top":1,"basement":true,"role":"shed","stock":["tin_crate","barrel","pallet_stack"],"id":7},
		{"name":"시장 창고","rect":[104,12,24,16],"top":1,"basement":false,"role":"shed","id":8},
		{"name":"시장 관리소","rect":[88,62,10,8],"top":1,"basement":false,"role":"shed","id":9},
		{"name":"우물집","rect":[100,54,8,8],"top":1,"basement":false,"role":"shed","id":10},
		{"name":"짐수레 차고","rect":[86,82,14,8],"top":1,"basement":false,"role":"shed","id":11},
		{"name":"장작 헛간","rect":[2,24,12,8],"top":1,"basement":false,"role":"shed","mode":"vertical","id":12},
		{"name":"공동 세탁장","rect":[42,86,14,10],"top":1,"basement":false,"role":"shed","id":13},
		{"name":"자전거 보관소","rect":[70,88,12,8],"top":1,"basement":false,"role":"shed","id":14},
		{"name":"안마당 헛간","rect":[122,74,10,8],"top":1,"basement":false,"role":"shed","id":15}],
	"entries": [{"id":"west_alley","cells":[[0,60],[0,61],[0,62],[0,63]],"gap":2},
		{"id":"southwest_alley","cells":[[30,104],[31,104],[32,104],[33,104]],"gap":2},
		{"id":"east_market","cells":[[174,44],[174,45],[174,46],[174,47]],"gap":0.6},
		{"id":"south_street","cells":[[114,104],[115,104],[116,104],[117,104]],"gap":0.6},
		{"id":"east_lower","cells":[[174,80],[174,81],[174,82],[174,83]],"gap":2}],
	"holes": [{"id":"manhole_01","cell":[84,50],"name":"시장 맨홀","level":0},
		{"id":"manhole_02","cell":[30,62],"name":"골목 끝 맨홀","level":0},
		{"id":"manhole_03","cell":[112,66],"name":"안마당 맨홀","level":0},
		{"id":"manhole_04","cell":[118,88],"name":"거리 끝 맨홀","level":0}],
	"barricades": [[57,23],[59,23],[14,29],[16,29],[99,26],[101,26]],
	"deepBuildings": [0,7],
	"deepLevels": [-1,-1],
	"assumptions": ["각 가장자리 진입 묶음은 최대 네 칸으로 줄이고 상점 거리의 첫 줄은 여섯 칸으로 넓혔다.","안쪽 방들은 한 칸 문과 네 칸 주 통로를 갖춘 판매 구획으로 나눴다.","식료품점 판매장을 넓게 열고 위층 계단실 두 곳은 남쪽 별도 현관으로 분리했다.","안마당 동쪽에 네 칸 통로를 남기고 가게 뒷문으로도 드나들게 했다."],
	"tx": 16,
	"band": [0,4,116,26],
	"shells": [{"building":0,"level":1,"rect":[40,58,44,22]},
		{"building":0,"level":2,"rect":[40,58,44,22]},
		{"building":0,"level":-1,"rect":[40,58,44,22]},
		{"building":1,"level":0,"rect":[18,20,32,16]},
		{"building":1,"level":1,"rect":[18,20,32,16]},
		{"building":1,"level":2,"rect":[18,20,32,16]},
		{"building":1,"level":-1,"rect":[18,20,32,16]},
		{"building":2,"level":0,"rect":[66,20,32,16]},
		{"building":2,"level":1,"rect":[66,20,32,16]},
		{"building":2,"level":2,"rect":[66,20,32,16]},
		{"building":3,"level":0,"rect":[4,40,30,16]},
		{"building":3,"level":1,"rect":[4,40,30,16]},
		{"building":3,"level":2,"rect":[4,40,30,16]},
		{"building":4,"level":0,"rect":[136,20,32,16]},
		{"building":4,"level":1,"rect":[136,20,32,16]},
		{"building":4,"level":2,"rect":[136,20,32,16]},
		{"building":5,"level":0,"rect":[134,54,34,16]},
		{"building":5,"level":1,"rect":[134,54,34,16]},
		{"building":5,"level":2,"rect":[134,54,34,16]},
		{"building":6,"level":0,"rect":[4,80,20,12]},
		{"building":6,"level":1,"rect":[4,80,20,12]},
		{"building":7,"level":0,"rect":[142,84,24,14]},
		{"building":7,"level":-1,"rect":[142,84,24,14]},
		{"building":8,"level":0,"rect":[104,12,24,16]},
		{"building":9,"level":0,"rect":[88,62,10,8]},
		{"building":10,"level":0,"rect":[100,54,8,8]},
		{"building":11,"level":0,"rect":[86,82,14,8]},
		{"building":12,"level":0,"rect":[2,24,12,8]},
		{"building":13,"level":0,"rect":[42,86,14,10]},
		{"building":14,"level":0,"rect":[70,88,12,8]},
		{"building":15,"level":0,"rect":[122,74,10,8]},
		{"building":0,"level":0,"rect":[40,58,44,22]}],
	"walls": [{"building":0,"level":1,"rect":[41,66,42,1]},
		{"building":0,"level":1,"rect":[41,71,42,1]},
		{"building":0,"level":1,"rect":[48,59,1,7]},
		{"building":0,"level":1,"rect":[55,59,1,7]},
		{"building":0,"level":1,"rect":[62,59,1,7]},
		{"building":0,"level":1,"rect":[69,59,1,7]},
		{"building":0,"level":1,"rect":[76,59,1,7]},
		{"building":0,"level":1,"rect":[48,72,1,7]},
		{"building":0,"level":1,"rect":[55,72,1,7]},
		{"building":0,"level":1,"rect":[62,72,1,7]},
		{"building":0,"level":1,"rect":[69,72,1,7]},
		{"building":0,"level":1,"rect":[76,72,1,7]},
		{"building":0,"level":2,"rect":[41,66,42,1]},
		{"building":0,"level":2,"rect":[41,71,42,1]},
		{"building":0,"level":2,"rect":[48,59,1,7]},
		{"building":0,"level":2,"rect":[55,59,1,7]},
		{"building":0,"level":2,"rect":[62,59,1,7]},
		{"building":0,"level":2,"rect":[69,59,1,7]},
		{"building":0,"level":2,"rect":[76,59,1,7]},
		{"building":0,"level":2,"rect":[48,72,1,7]},
		{"building":0,"level":2,"rect":[55,72,1,7]},
		{"building":0,"level":2,"rect":[62,72,1,7]},
		{"building":0,"level":2,"rect":[69,72,1,7]},
		{"building":0,"level":2,"rect":[76,72,1,7]},
		{"building":0,"level":-1,"rect":[41,66,42,1]},
		{"building":0,"level":-1,"rect":[41,71,42,1]},
		{"building":0,"level":-1,"rect":[48,59,1,7]},
		{"building":0,"level":-1,"rect":[55,59,1,7]},
		{"building":0,"level":-1,"rect":[62,59,1,7]},
		{"building":0,"level":-1,"rect":[69,59,1,7]},
		{"building":0,"level":-1,"rect":[76,59,1,7]},
		{"building":0,"level":-1,"rect":[48,72,1,7]},
		{"building":0,"level":-1,"rect":[55,72,1,7]},
		{"building":0,"level":-1,"rect":[62,72,1,7]},
		{"building":0,"level":-1,"rect":[69,72,1,7]},
		{"building":0,"level":-1,"rect":[76,72,1,7]},
		{"building":1,"level":0,"rect":[19,26,30,1]},
		{"building":1,"level":0,"rect":[19,29,30,1]},
		{"building":1,"level":0,"rect":[29,21,1,5]},
		{"building":1,"level":0,"rect":[39,21,1,5]},
		{"building":1,"level":0,"rect":[29,30,1,5]},
		{"building":1,"level":0,"rect":[39,30,1,5]},
		{"building":1,"level":1,"rect":[19,26,30,1]},
		{"building":1,"level":1,"rect":[19,29,30,1]},
		{"building":1,"level":1,"rect":[29,21,1,5]},
		{"building":1,"level":1,"rect":[39,21,1,5]},
		{"building":1,"level":1,"rect":[29,30,1,5]},
		{"building":1,"level":1,"rect":[39,30,1,5]},
		{"building":1,"level":2,"rect":[19,26,30,1]},
		{"building":1,"level":2,"rect":[19,29,30,1]},
		{"building":1,"level":2,"rect":[29,21,1,5]},
		{"building":1,"level":2,"rect":[39,21,1,5]},
		{"building":1,"level":2,"rect":[29,30,1,5]},
		{"building":1,"level":2,"rect":[39,30,1,5]},
		{"building":1,"level":-1,"rect":[19,26,30,1]},
		{"building":1,"level":-1,"rect":[19,29,30,1]},
		{"building":1,"level":-1,"rect":[29,21,1,5]},
		{"building":1,"level":-1,"rect":[39,21,1,5]},
		{"building":1,"level":-1,"rect":[29,30,1,5]},
		{"building":1,"level":-1,"rect":[39,30,1,5]},
		{"building":2,"level":0,"rect":[67,26,30,1]},
		{"building":2,"level":0,"rect":[67,29,30,1]},
		{"building":2,"level":0,"rect":[77,21,1,5]},
		{"building":2,"level":0,"rect":[87,21,1,5]},
		{"building":2,"level":0,"rect":[77,30,1,5]},
		{"building":2,"level":0,"rect":[87,30,1,5]},
		{"building":2,"level":1,"rect":[67,26,30,1]},
		{"building":2,"level":1,"rect":[67,29,30,1]},
		{"building":2,"level":1,"rect":[77,21,1,5]},
		{"building":2,"level":1,"rect":[87,21,1,5]},
		{"building":2,"level":1,"rect":[77,30,1,5]},
		{"building":2,"level":1,"rect":[87,30,1,5]},
		{"building":2,"level":2,"rect":[67,26,30,1]},
		{"building":2,"level":2,"rect":[67,29,30,1]},
		{"building":2,"level":2,"rect":[77,21,1,5]},
		{"building":2,"level":2,"rect":[87,21,1,5]},
		{"building":2,"level":2,"rect":[77,30,1,5]},
		{"building":2,"level":2,"rect":[87,30,1,5]},
		{"building":3,"level":0,"rect":[5,46,28,1]},
		{"building":3,"level":0,"rect":[5,49,28,1]},
		{"building":3,"level":0,"rect":[14,41,1,5]},
		{"building":3,"level":0,"rect":[24,41,1,5]},
		{"building":3,"level":0,"rect":[14,50,1,5]},
		{"building":3,"level":0,"rect":[24,50,1,5]},
		{"building":3,"level":1,"rect":[5,46,28,1]},
		{"building":3,"level":1,"rect":[5,49,28,1]},
		{"building":3,"level":1,"rect":[14,41,1,5]},
		{"building":3,"level":1,"rect":[24,41,1,5]},
		{"building":3,"level":1,"rect":[14,50,1,5]},
		{"building":3,"level":1,"rect":[24,50,1,5]},
		{"building":3,"level":2,"rect":[5,46,28,1]},
		{"building":3,"level":2,"rect":[5,49,28,1]},
		{"building":3,"level":2,"rect":[14,41,1,5]},
		{"building":3,"level":2,"rect":[24,41,1,5]},
		{"building":3,"level":2,"rect":[14,50,1,5]},
		{"building":3,"level":2,"rect":[24,50,1,5]},
		{"building":4,"level":0,"rect":[137,26,30,1]},
		{"building":4,"level":0,"rect":[137,29,30,1]},
		{"building":4,"level":0,"rect":[147,21,1,5]},
		{"building":4,"level":0,"rect":[157,21,1,5]},
		{"building":4,"level":0,"rect":[147,30,1,5]},
		{"building":4,"level":0,"rect":[157,30,1,5]},
		{"building":4,"level":1,"rect":[137,26,30,1]},
		{"building":4,"level":1,"rect":[137,29,30,1]},
		{"building":4,"level":1,"rect":[147,21,1,5]},
		{"building":4,"level":1,"rect":[157,21,1,5]},
		{"building":4,"level":1,"rect":[147,30,1,5]},
		{"building":4,"level":1,"rect":[157,30,1,5]},
		{"building":4,"level":2,"rect":[137,26,30,1]},
		{"building":4,"level":2,"rect":[137,29,30,1]},
		{"building":4,"level":2,"rect":[147,21,1,5]},
		{"building":4,"level":2,"rect":[157,21,1,5]},
		{"building":4,"level":2,"rect":[147,30,1,5]},
		{"building":4,"level":2,"rect":[157,30,1,5]},
		{"building":5,"level":0,"rect":[135,60,32,1]},
		{"building":5,"level":0,"rect":[135,63,32,1]},
		{"building":5,"level":0,"rect":[143,55,1,5]},
		{"building":5,"level":0,"rect":[151,55,1,5]},
		{"building":5,"level":0,"rect":[159,55,1,5]},
		{"building":5,"level":0,"rect":[143,64,1,5]},
		{"building":5,"level":0,"rect":[151,64,1,5]},
		{"building":5,"level":0,"rect":[159,64,1,5]},
		{"building":5,"level":1,"rect":[135,60,32,1]},
		{"building":5,"level":1,"rect":[135,63,32,1]},
		{"building":5,"level":1,"rect":[143,55,1,5]},
		{"building":5,"level":1,"rect":[151,55,1,5]},
		{"building":5,"level":1,"rect":[159,55,1,5]},
		{"building":5,"level":1,"rect":[143,64,1,5]},
		{"building":5,"level":1,"rect":[151,64,1,5]},
		{"building":5,"level":1,"rect":[159,64,1,5]},
		{"building":5,"level":2,"rect":[135,60,32,1]},
		{"building":5,"level":2,"rect":[135,63,32,1]},
		{"building":5,"level":2,"rect":[143,55,1,5]},
		{"building":5,"level":2,"rect":[151,55,1,5]},
		{"building":5,"level":2,"rect":[159,55,1,5]},
		{"building":5,"level":2,"rect":[143,64,1,5]},
		{"building":5,"level":2,"rect":[151,64,1,5]},
		{"building":5,"level":2,"rect":[159,64,1,5]},
		{"building":6,"level":0,"rect":[5,84,18,1]},
		{"building":6,"level":0,"rect":[5,87,18,1]},
		{"building":6,"level":0,"rect":[14,81,1,3]},
		{"building":6,"level":0,"rect":[14,88,1,3]},
		{"building":6,"level":1,"rect":[5,84,18,1]},
		{"building":6,"level":1,"rect":[5,87,18,1]},
		{"building":6,"level":1,"rect":[14,81,1,3]},
		{"building":6,"level":1,"rect":[14,88,1,3]},
		{"building":7,"level":0,"rect":[143,89,22,1]},
		{"building":7,"level":0,"rect":[143,92,22,1]},
		{"building":7,"level":0,"rect":[154,85,1,4]},
		{"building":7,"level":0,"rect":[154,93,1,4]},
		{"building":7,"level":-1,"rect":[143,89,22,1]},
		{"building":7,"level":-1,"rect":[143,92,22,1]},
		{"building":7,"level":-1,"rect":[154,85,1,4]},
		{"building":7,"level":-1,"rect":[154,93,1,4]},
		{"building":8,"level":0,"rect":[105,18,22,1]},
		{"building":8,"level":0,"rect":[105,21,22,1]},
		{"building":8,"level":0,"rect":[116,13,1,5]},
		{"building":8,"level":0,"rect":[116,22,1,5]},
		{"building":11,"level":0,"rect":[93,83,1,6]},
		{"building":12,"level":0,"rect":[6,25,1,6]},
		{"building":12,"level":0,"rect":[9,25,1,6]},
		{"building":13,"level":0,"rect":[49,87,1,8]},
		{"building":14,"level":0,"rect":[76,89,1,6]},
		{"building":0,"level":0,"rect":[69,59,1,20]},
		{"building":0,"level":0,"rect":[70,66,13,1]},
		{"building":0,"level":0,"rect":[70,71,13,1]},
		{"building":0,"level":0,"rect":[76,72,1,7]},
		{"building":0,"level":0,"rect":[41,74,28,1]},
		{"building":0,"level":0,"rect":[50,75,1,4]},
		{"building":0,"level":0,"rect":[60,75,1,4]},
		{"building":-1,"level":0,"rect":[84,52,29,1]},
		{"building":-1,"level":0,"rect":[112,52,1,12]},
		{"building":-1,"level":0,"rect":[112,68,1,9]},
		{"building":-1,"level":0,"rect":[84,76,29,1]},
		{"building":-1,"level":0,"rect":[84,52,1,12]},
		{"building":-1,"level":0,"rect":[84,70,1,7]}],
	"doors": [{"cell":[44,66],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[52,66],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[59,66],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[66,66],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[73,66],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[80,66],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[44,71],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[52,71],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[59,71],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[66,71],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[73,71],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[80,71],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[44,66],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[52,66],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[59,66],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[66,66],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[73,66],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[80,66],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[44,71],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[52,71],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[59,71],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[66,71],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[73,71],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[80,71],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[44,66],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[52,66],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[59,66],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[66,66],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[73,66],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[80,66],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[44,71],"building":0,"level":-1,"state":"closed","normal":[0,1],"external":false},
		{"cell":[52,71],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[59,71],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[66,71],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[73,71],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[80,71],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[24,26],"building":1,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,26],"building":1,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[44,26],"building":1,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[24,29],"building":1,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,29],"building":1,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[44,29],"building":1,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[18,27],"building":1,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[49,27],"building":1,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[24,26],"building":1,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,26],"building":1,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[44,26],"building":1,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[24,29],"building":1,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,29],"building":1,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[44,29],"building":1,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[24,26],"building":1,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,26],"building":1,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[44,26],"building":1,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[24,29],"building":1,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,29],"building":1,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[44,29],"building":1,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[24,26],"building":1,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,26],"building":1,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[44,26],"building":1,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[24,29],"building":1,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,29],"building":1,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[44,29],"building":1,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[72,26],"building":2,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[82,26],"building":2,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[92,26],"building":2,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[72,29],"building":2,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[82,29],"building":2,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[92,29],"building":2,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[66,27],"building":2,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[97,27],"building":2,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[72,26],"building":2,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[82,26],"building":2,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[92,26],"building":2,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[72,29],"building":2,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[82,29],"building":2,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[92,29],"building":2,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[72,26],"building":2,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[82,26],"building":2,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[92,26],"building":2,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[72,29],"building":2,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[82,29],"building":2,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[92,29],"building":2,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[9,46],"building":3,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[19,46],"building":3,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[29,46],"building":3,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[9,49],"building":3,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[19,49],"building":3,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[29,49],"building":3,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[4,47],"building":3,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[33,47],"building":3,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[9,46],"building":3,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[19,46],"building":3,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[29,46],"building":3,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[9,49],"building":3,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[19,49],"building":3,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[29,49],"building":3,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[9,46],"building":3,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[19,46],"building":3,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[29,46],"building":3,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[9,49],"building":3,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[19,49],"building":3,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[29,49],"building":3,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[142,26],"building":4,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[152,26],"building":4,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[162,26],"building":4,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[142,29],"building":4,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[152,29],"building":4,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[162,29],"building":4,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[136,27],"building":4,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[167,27],"building":4,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[142,26],"building":4,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[152,26],"building":4,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[162,26],"building":4,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[142,29],"building":4,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[152,29],"building":4,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[162,29],"building":4,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[142,26],"building":4,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[152,26],"building":4,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[162,26],"building":4,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[142,29],"building":4,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[152,29],"building":4,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[162,29],"building":4,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[139,60],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[147,60],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[155,60],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[163,60],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[139,63],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[147,63],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[155,63],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[163,63],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[134,61],"building":5,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[167,61],"building":5,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[139,60],"building":5,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[147,60],"building":5,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[155,60],"building":5,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[163,60],"building":5,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[139,63],"building":5,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[147,63],"building":5,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[155,63],"building":5,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[163,63],"building":5,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[139,60],"building":5,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[147,60],"building":5,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[155,60],"building":5,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[163,60],"building":5,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[139,63],"building":5,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[147,63],"building":5,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[155,63],"building":5,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[163,63],"building":5,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[9,84],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[19,84],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[9,87],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[19,87],"building":6,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[4,85],"building":6,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[23,85],"building":6,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[9,84],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[19,84],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[9,87],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[19,87],"building":6,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[148,89],"building":7,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[160,89],"building":7,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[148,92],"building":7,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[160,92],"building":7,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[142,90],"building":7,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[165,90],"building":7,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[148,89],"building":7,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[160,89],"building":7,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[148,92],"building":7,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[160,92],"building":7,"level":-1,"state":"closed","normal":[0,1],"external":false},
		{"cell":[110,18],"building":8,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[122,18],"building":8,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[110,21],"building":8,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[122,21],"building":8,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[104,19],"building":8,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[127,19],"building":8,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[88,66],"building":9,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[97,66],"building":9,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[100,58],"building":10,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[107,58],"building":10,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[93,86],"building":11,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[86,86],"building":11,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[99,86],"building":11,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[6,28],"building":12,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[9,28],"building":12,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[7,24],"building":12,"level":0,"state":"open","normal":[0,-1],"external":true},
		{"cell":[7,31],"building":12,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[49,91],"building":13,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[42,91],"building":13,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[55,91],"building":13,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[76,92],"building":14,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[70,92],"building":14,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[81,92],"building":14,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[122,78],"building":15,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[131,78],"building":15,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[62,58],"building":0,"level":0,"state":"open","normal":[0,-1],"external":true},
		{"cell":[83,67],"building":0,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[45,79],"building":0,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[64,79],"building":0,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[76,66],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[73,71],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[80,71],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[55,74],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[69,67],"building":0,"level":0,"state":"open","normal":[1,0],"external":false}],
	"windows": [{"cell":[43,58],"building":0,"level":1},
		{"cell":[80,79],"building":0,"level":1},
		{"cell":[43,58],"building":0,"level":2},
		{"cell":[80,79],"building":0,"level":2},
		{"cell":[43,58],"building":0,"level":-1},
		{"cell":[80,79],"building":0,"level":-1},
		{"cell":[21,20],"building":1,"level":0},
		{"cell":[46,35],"building":1,"level":0},
		{"cell":[21,20],"building":1,"level":1},
		{"cell":[46,35],"building":1,"level":1},
		{"cell":[21,20],"building":1,"level":2},
		{"cell":[46,35],"building":1,"level":2},
		{"cell":[21,20],"building":1,"level":-1},
		{"cell":[46,35],"building":1,"level":-1},
		{"cell":[69,20],"building":2,"level":0},
		{"cell":[94,35],"building":2,"level":0},
		{"cell":[69,20],"building":2,"level":1},
		{"cell":[94,35],"building":2,"level":1},
		{"cell":[69,20],"building":2,"level":2},
		{"cell":[94,35],"building":2,"level":2},
		{"cell":[7,40],"building":3,"level":0},
		{"cell":[30,55],"building":3,"level":0},
		{"cell":[7,40],"building":3,"level":1},
		{"cell":[30,55],"building":3,"level":1},
		{"cell":[7,40],"building":3,"level":2},
		{"cell":[30,55],"building":3,"level":2},
		{"cell":[139,20],"building":4,"level":0},
		{"cell":[164,35],"building":4,"level":0},
		{"cell":[139,20],"building":4,"level":1},
		{"cell":[164,35],"building":4,"level":1},
		{"cell":[139,20],"building":4,"level":2},
		{"cell":[164,35],"building":4,"level":2},
		{"cell":[137,54],"building":5,"level":0},
		{"cell":[164,69],"building":5,"level":0},
		{"cell":[137,54],"building":5,"level":1},
		{"cell":[164,69],"building":5,"level":1},
		{"cell":[137,54],"building":5,"level":2},
		{"cell":[164,69],"building":5,"level":2},
		{"cell":[7,80],"building":6,"level":0},
		{"cell":[20,91],"building":6,"level":0},
		{"cell":[7,80],"building":6,"level":1},
		{"cell":[20,91],"building":6,"level":1},
		{"cell":[145,84],"building":7,"level":0},
		{"cell":[162,97],"building":7,"level":0},
		{"cell":[145,84],"building":7,"level":-1},
		{"cell":[162,97],"building":7,"level":-1},
		{"cell":[107,12],"building":8,"level":0},
		{"cell":[124,27],"building":8,"level":0},
		{"cell":[90,62],"building":9,"level":0},
		{"cell":[102,54],"building":10,"level":0},
		{"cell":[88,82],"building":11,"level":0},
		{"cell":[2,27],"building":12,"level":0},
		{"cell":[13,28],"building":12,"level":0},
		{"cell":[44,86],"building":13,"level":0},
		{"cell":[72,88],"building":14,"level":0},
		{"cell":[124,74],"building":15,"level":0},
		{"cell":[46,58],"building":0,"level":0},
		{"cell":[40,64],"building":0,"level":0},
		{"cell":[83,74],"building":0,"level":0}],
	"stairs": [{"cell":[20,27],"low":-1,"high":0,"ladder":false},
		{"cell":[20,27],"low":0,"high":1,"ladder":false},
		{"cell":[20,27],"low":1,"high":2,"ladder":false},
		{"cell":[47,28],"low":-1,"high":0,"ladder":false},
		{"cell":[47,28],"low":0,"high":1,"ladder":false},
		{"cell":[47,28],"low":1,"high":2,"ladder":false},
		{"cell":[68,27],"low":0,"high":1,"ladder":false},
		{"cell":[68,27],"low":1,"high":2,"ladder":false},
		{"cell":[95,28],"low":0,"high":1,"ladder":false},
		{"cell":[95,28],"low":1,"high":2,"ladder":false},
		{"cell":[6,47],"low":0,"high":1,"ladder":false},
		{"cell":[6,47],"low":1,"high":2,"ladder":false},
		{"cell":[31,48],"low":0,"high":1,"ladder":false},
		{"cell":[31,48],"low":1,"high":2,"ladder":false},
		{"cell":[138,27],"low":0,"high":1,"ladder":false},
		{"cell":[138,27],"low":1,"high":2,"ladder":false},
		{"cell":[165,28],"low":0,"high":1,"ladder":false},
		{"cell":[165,28],"low":1,"high":2,"ladder":false},
		{"cell":[136,61],"low":0,"high":1,"ladder":false},
		{"cell":[136,61],"low":1,"high":2,"ladder":false},
		{"cell":[165,62],"low":0,"high":1,"ladder":false},
		{"cell":[165,62],"low":1,"high":2,"ladder":false},
		{"cell":[6,85],"low":0,"high":1,"ladder":false},
		{"cell":[144,90],"low":-1,"high":0,"ladder":false},
		{"cell":[45,76],"low":0,"high":1,"ladder":false},
		{"cell":[45,76],"low":1,"high":2,"ladder":false},
		{"cell":[64,76],"low":0,"high":1,"ladder":false},
		{"cell":[64,76],"low":1,"high":2,"ladder":false},
		{"cell":[79,63],"low":-1,"high":0,"ladder":false}],
	"rooms": [{"building":0,"level":1,"rect":[41,59,7,7],"use":"매장"},
		{"building":0,"level":1,"rect":[49,59,6,7],"use":"뒤 창고"},
		{"building":0,"level":1,"rect":[56,59,6,7],"use":"작업실"},
		{"building":0,"level":1,"rect":[63,59,6,7],"use":"매장"},
		{"building":0,"level":1,"rect":[70,59,6,7],"use":"뒤 창고"},
		{"building":0,"level":1,"rect":[77,59,6,7],"use":"작업실"},
		{"building":0,"level":1,"rect":[41,72,7,7],"use":"매장"},
		{"building":0,"level":1,"rect":[49,72,6,7],"use":"뒤 창고"},
		{"building":0,"level":1,"rect":[56,72,6,7],"use":"작업실"},
		{"building":0,"level":1,"rect":[63,72,6,7],"use":"매장"},
		{"building":0,"level":1,"rect":[70,72,6,7],"use":"뒤 창고"},
		{"building":0,"level":1,"rect":[77,72,6,7],"use":"작업실"},
		{"building":0,"level":2,"rect":[41,59,7,7],"use":"매장"},
		{"building":0,"level":2,"rect":[49,59,6,7],"use":"뒤 창고"},
		{"building":0,"level":2,"rect":[56,59,6,7],"use":"작업실"},
		{"building":0,"level":2,"rect":[63,59,6,7],"use":"매장"},
		{"building":0,"level":2,"rect":[70,59,6,7],"use":"뒤 창고"},
		{"building":0,"level":2,"rect":[77,59,6,7],"use":"작업실"},
		{"building":0,"level":2,"rect":[41,72,7,7],"use":"매장"},
		{"building":0,"level":2,"rect":[49,72,6,7],"use":"뒤 창고"},
		{"building":0,"level":2,"rect":[56,72,6,7],"use":"작업실"},
		{"building":0,"level":2,"rect":[63,72,6,7],"use":"매장"},
		{"building":0,"level":2,"rect":[70,72,6,7],"use":"뒤 창고"},
		{"building":0,"level":2,"rect":[77,72,6,7],"use":"작업실"},
		{"building":0,"level":-1,"rect":[41,59,7,7],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[49,59,6,7],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[56,59,6,7],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[63,59,6,7],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[70,59,6,7],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[77,59,6,7],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[41,72,7,7],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[49,72,6,7],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[56,72,6,7],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[63,72,6,7],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[70,72,6,7],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[77,72,6,7],"use":"저장 칸"},
		{"building":1,"level":0,"rect":[19,21,10,5],"use":"매장"},
		{"building":1,"level":0,"rect":[30,21,9,5],"use":"뒤 창고"},
		{"building":1,"level":0,"rect":[40,21,9,5],"use":"작업실"},
		{"building":1,"level":0,"rect":[19,30,10,5],"use":"매장"},
		{"building":1,"level":0,"rect":[30,30,9,5],"use":"뒤 창고"},
		{"building":1,"level":0,"rect":[40,30,9,5],"use":"작업실"},
		{"building":1,"level":1,"rect":[19,21,10,5],"use":"매장"},
		{"building":1,"level":1,"rect":[30,21,9,5],"use":"뒤 창고"},
		{"building":1,"level":1,"rect":[40,21,9,5],"use":"작업실"},
		{"building":1,"level":1,"rect":[19,30,10,5],"use":"매장"},
		{"building":1,"level":1,"rect":[30,30,9,5],"use":"뒤 창고"},
		{"building":1,"level":1,"rect":[40,30,9,5],"use":"작업실"},
		{"building":1,"level":2,"rect":[19,21,10,5],"use":"매장"},
		{"building":1,"level":2,"rect":[30,21,9,5],"use":"뒤 창고"},
		{"building":1,"level":2,"rect":[40,21,9,5],"use":"작업실"},
		{"building":1,"level":2,"rect":[19,30,10,5],"use":"매장"},
		{"building":1,"level":2,"rect":[30,30,9,5],"use":"뒤 창고"},
		{"building":1,"level":2,"rect":[40,30,9,5],"use":"작업실"},
		{"building":1,"level":-1,"rect":[19,21,10,5],"use":"저장 칸"},
		{"building":1,"level":-1,"rect":[30,21,9,5],"use":"저장 칸"},
		{"building":1,"level":-1,"rect":[40,21,9,5],"use":"저장 칸"},
		{"building":1,"level":-1,"rect":[19,30,10,5],"use":"저장 칸"},
		{"building":1,"level":-1,"rect":[30,30,9,5],"use":"저장 칸"},
		{"building":1,"level":-1,"rect":[40,30,9,5],"use":"저장 칸"},
		{"building":2,"level":0,"rect":[67,21,10,5],"use":"매장"},
		{"building":2,"level":0,"rect":[78,21,9,5],"use":"뒤 창고"},
		{"building":2,"level":0,"rect":[88,21,9,5],"use":"작업실"},
		{"building":2,"level":0,"rect":[67,30,10,5],"use":"매장"},
		{"building":2,"level":0,"rect":[78,30,9,5],"use":"뒤 창고"},
		{"building":2,"level":0,"rect":[88,30,9,5],"use":"작업실"},
		{"building":2,"level":1,"rect":[67,21,10,5],"use":"매장"},
		{"building":2,"level":1,"rect":[78,21,9,5],"use":"뒤 창고"},
		{"building":2,"level":1,"rect":[88,21,9,5],"use":"작업실"},
		{"building":2,"level":1,"rect":[67,30,10,5],"use":"매장"},
		{"building":2,"level":1,"rect":[78,30,9,5],"use":"뒤 창고"},
		{"building":2,"level":1,"rect":[88,30,9,5],"use":"작업실"},
		{"building":2,"level":2,"rect":[67,21,10,5],"use":"매장"},
		{"building":2,"level":2,"rect":[78,21,9,5],"use":"뒤 창고"},
		{"building":2,"level":2,"rect":[88,21,9,5],"use":"작업실"},
		{"building":2,"level":2,"rect":[67,30,10,5],"use":"매장"},
		{"building":2,"level":2,"rect":[78,30,9,5],"use":"뒤 창고"},
		{"building":2,"level":2,"rect":[88,30,9,5],"use":"작업실"},
		{"building":3,"level":0,"rect":[5,41,9,5],"use":"매장"},
		{"building":3,"level":0,"rect":[15,41,9,5],"use":"뒤 창고"},
		{"building":3,"level":0,"rect":[25,41,8,5],"use":"작업실"},
		{"building":3,"level":0,"rect":[5,50,9,5],"use":"매장"},
		{"building":3,"level":0,"rect":[15,50,9,5],"use":"뒤 창고"},
		{"building":3,"level":0,"rect":[25,50,8,5],"use":"작업실"},
		{"building":3,"level":1,"rect":[5,41,9,5],"use":"매장"},
		{"building":3,"level":1,"rect":[15,41,9,5],"use":"뒤 창고"},
		{"building":3,"level":1,"rect":[25,41,8,5],"use":"작업실"},
		{"building":3,"level":1,"rect":[5,50,9,5],"use":"매장"},
		{"building":3,"level":1,"rect":[15,50,9,5],"use":"뒤 창고"},
		{"building":3,"level":1,"rect":[25,50,8,5],"use":"작업실"},
		{"building":3,"level":2,"rect":[5,41,9,5],"use":"매장"},
		{"building":3,"level":2,"rect":[15,41,9,5],"use":"뒤 창고"},
		{"building":3,"level":2,"rect":[25,41,8,5],"use":"작업실"},
		{"building":3,"level":2,"rect":[5,50,9,5],"use":"매장"},
		{"building":3,"level":2,"rect":[15,50,9,5],"use":"뒤 창고"},
		{"building":3,"level":2,"rect":[25,50,8,5],"use":"작업실"},
		{"building":4,"level":0,"rect":[137,21,10,5],"use":"매장"},
		{"building":4,"level":0,"rect":[148,21,9,5],"use":"뒤 창고"},
		{"building":4,"level":0,"rect":[158,21,9,5],"use":"작업실"},
		{"building":4,"level":0,"rect":[137,30,10,5],"use":"매장"},
		{"building":4,"level":0,"rect":[148,30,9,5],"use":"뒤 창고"},
		{"building":4,"level":0,"rect":[158,30,9,5],"use":"작업실"},
		{"building":4,"level":1,"rect":[137,21,10,5],"use":"매장"},
		{"building":4,"level":1,"rect":[148,21,9,5],"use":"뒤 창고"},
		{"building":4,"level":1,"rect":[158,21,9,5],"use":"작업실"},
		{"building":4,"level":1,"rect":[137,30,10,5],"use":"매장"},
		{"building":4,"level":1,"rect":[148,30,9,5],"use":"뒤 창고"},
		{"building":4,"level":1,"rect":[158,30,9,5],"use":"작업실"},
		{"building":4,"level":2,"rect":[137,21,10,5],"use":"매장"},
		{"building":4,"level":2,"rect":[148,21,9,5],"use":"뒤 창고"},
		{"building":4,"level":2,"rect":[158,21,9,5],"use":"작업실"},
		{"building":4,"level":2,"rect":[137,30,10,5],"use":"매장"},
		{"building":4,"level":2,"rect":[148,30,9,5],"use":"뒤 창고"},
		{"building":4,"level":2,"rect":[158,30,9,5],"use":"작업실"},
		{"building":5,"level":0,"rect":[135,55,8,5],"use":"매장"},
		{"building":5,"level":0,"rect":[144,55,7,5],"use":"뒤 창고"},
		{"building":5,"level":0,"rect":[152,55,7,5],"use":"작업실"},
		{"building":5,"level":0,"rect":[160,55,7,5],"use":"매장"},
		{"building":5,"level":0,"rect":[135,64,8,5],"use":"매장"},
		{"building":5,"level":0,"rect":[144,64,7,5],"use":"뒤 창고"},
		{"building":5,"level":0,"rect":[152,64,7,5],"use":"작업실"},
		{"building":5,"level":0,"rect":[160,64,7,5],"use":"매장"},
		{"building":5,"level":1,"rect":[135,55,8,5],"use":"매장"},
		{"building":5,"level":1,"rect":[144,55,7,5],"use":"뒤 창고"},
		{"building":5,"level":1,"rect":[152,55,7,5],"use":"작업실"},
		{"building":5,"level":1,"rect":[160,55,7,5],"use":"매장"},
		{"building":5,"level":1,"rect":[135,64,8,5],"use":"매장"},
		{"building":5,"level":1,"rect":[144,64,7,5],"use":"뒤 창고"},
		{"building":5,"level":1,"rect":[152,64,7,5],"use":"작업실"},
		{"building":5,"level":1,"rect":[160,64,7,5],"use":"매장"},
		{"building":5,"level":2,"rect":[135,55,8,5],"use":"매장"},
		{"building":5,"level":2,"rect":[144,55,7,5],"use":"뒤 창고"},
		{"building":5,"level":2,"rect":[152,55,7,5],"use":"작업실"},
		{"building":5,"level":2,"rect":[160,55,7,5],"use":"매장"},
		{"building":5,"level":2,"rect":[135,64,8,5],"use":"매장"},
		{"building":5,"level":2,"rect":[144,64,7,5],"use":"뒤 창고"},
		{"building":5,"level":2,"rect":[152,64,7,5],"use":"작업실"},
		{"building":5,"level":2,"rect":[160,64,7,5],"use":"매장"},
		{"building":6,"level":0,"rect":[5,81,9,3],"use":"매장"},
		{"building":6,"level":0,"rect":[15,81,8,3],"use":"뒤 창고"},
		{"building":6,"level":0,"rect":[5,88,9,3],"use":"매장"},
		{"building":6,"level":0,"rect":[15,88,8,3],"use":"뒤 창고"},
		{"building":6,"level":1,"rect":[5,81,9,3],"use":"매장"},
		{"building":6,"level":1,"rect":[15,81,8,3],"use":"뒤 창고"},
		{"building":6,"level":1,"rect":[5,88,9,3],"use":"매장"},
		{"building":6,"level":1,"rect":[15,88,8,3],"use":"뒤 창고"},
		{"building":7,"level":0,"rect":[143,85,11,4],"use":"매장"},
		{"building":7,"level":0,"rect":[155,85,10,4],"use":"뒤 창고"},
		{"building":7,"level":0,"rect":[143,93,11,4],"use":"매장"},
		{"building":7,"level":0,"rect":[155,93,10,4],"use":"뒤 창고"},
		{"building":7,"level":-1,"rect":[143,85,11,4],"use":"저장 칸"},
		{"building":7,"level":-1,"rect":[155,85,10,4],"use":"저장 칸"},
		{"building":7,"level":-1,"rect":[143,93,11,4],"use":"저장 칸"},
		{"building":7,"level":-1,"rect":[155,93,10,4],"use":"저장 칸"},
		{"building":8,"level":0,"rect":[105,13,11,5],"use":"매장"},
		{"building":8,"level":0,"rect":[117,13,10,5],"use":"뒤 창고"},
		{"building":8,"level":0,"rect":[105,22,11,5],"use":"매장"},
		{"building":8,"level":0,"rect":[117,22,10,5],"use":"뒤 창고"},
		{"building":9,"level":0,"rect":[89,63,8,6],"use":"작업실"},
		{"building":10,"level":0,"rect":[101,55,6,6],"use":"작업실"},
		{"building":11,"level":0,"rect":[87,83,6,6],"use":"작업실"},
		{"building":11,"level":0,"rect":[94,83,5,6],"use":"뒤 창고"},
		{"building":12,"level":0,"rect":[3,25,3,6],"use":"매장"},
		{"building":12,"level":0,"rect":[10,25,3,6],"use":"매장"},
		{"building":13,"level":0,"rect":[43,87,6,8],"use":"작업실"},
		{"building":13,"level":0,"rect":[50,87,5,8],"use":"뒤 창고"},
		{"building":14,"level":0,"rect":[71,89,5,6],"use":"작업실"},
		{"building":14,"level":0,"rect":[77,89,4,6],"use":"뒤 창고"},
		{"building":15,"level":0,"rect":[123,75,8,6],"use":"작업실"},
		{"building":0,"level":0,"rect":[41,59,28,15],"use":"판매장"},
		{"building":0,"level":0,"rect":[70,59,13,7],"use":"뒤 창고"},
		{"building":0,"level":0,"rect":[70,67,13,4],"use":"뒷문 홀"},
		{"building":0,"level":0,"rect":[70,72,6,7],"use":"사무 방"},
		{"building":0,"level":0,"rect":[77,72,6,7],"use":"냉동 칸"},
		{"building":0,"level":0,"rect":[41,75,9,4],"use":"서쪽 계단실"},
		{"building":0,"level":0,"rect":[51,75,9,4],"use":"저장 칸"},
		{"building":0,"level":0,"rect":[61,75,8,4],"use":"동쪽 계단실"}],
	"props": [{"kind":"floor_shell","rect":[40,58,44,22],"solid":"none","facing":0,"note":"사층 겉모양","level":3},
		{"kind":"floor_shell","rect":[18,20,32,16],"solid":"none","facing":0,"note":"사층 겉모양","level":3},
		{"kind":"stair_stub","rect":[20,27,1,2],"solid":"none","facing":0,"note":"계단 자리","level":2},
		{"kind":"floor_shell","rect":[66,20,32,16],"solid":"none","facing":0,"note":"사층 겉모양","level":3},
		{"kind":"stair_stub","rect":[68,27,1,2],"solid":"none","facing":0,"note":"계단 자리","level":2},
		{"kind":"floor_shell","rect":[4,40,30,16],"solid":"none","facing":0,"note":"사층 겉모양","level":3},
		{"kind":"stair_stub","rect":[6,47,1,2],"solid":"none","facing":0,"note":"계단 자리","level":2},
		{"kind":"floor_shell","rect":[136,20,32,16],"solid":"none","facing":0,"note":"사층 겉모양","level":3},
		{"kind":"stair_stub","rect":[138,27,1,2],"solid":"none","facing":0,"note":"계단 자리","level":2},
		{"kind":"floor_shell","rect":[134,54,34,16],"solid":"none","facing":0,"note":"사층 겉모양","level":3},
		{"kind":"stair_stub","rect":[136,61,1,2],"solid":"none","facing":0,"note":"계단 자리","level":2},
		{"kind":"stair_stub","rect":[45,76,1,2],"solid":"none","facing":0,"note":"계단 자리","level":2},
		{"kind":"display_shelf","rect":[42,62,4,1],"solid":"low","facing":0,"note":"진열대","level":0},
		{"kind":"display_shelf","rect":[47,62,4,1],"solid":"low","facing":1,"note":"진열대","level":0},
		{"kind":"display_shelf","rect":[60,62,4,1],"solid":"low","facing":2,"note":"진열대","level":0},
		{"kind":"display_shelf","rect":[42,66,4,1],"solid":"low","facing":3,"note":"진열대","level":0},
		{"kind":"display_shelf","rect":[47,66,4,1],"solid":"low","facing":0,"note":"진열대","level":0},
		{"kind":"display_shelf","rect":[60,66,4,1],"solid":"low","facing":1,"note":"진열대","level":0},
		{"kind":"display_shelf","rect":[42,70,4,1],"solid":"low","facing":2,"note":"진열대","level":0},
		{"kind":"display_shelf","rect":[47,70,4,1],"solid":"low","facing":3,"note":"진열대","level":0},
		{"kind":"display_shelf","rect":[60,70,4,1],"solid":"low","facing":0,"note":"진열대","level":0},
		{"kind":"shop_counter","rect":[65,60,3,1],"solid":"low","facing":1,"note":"가게 계산대","level":0},
		{"kind":"freezer_chest","rect":[78,74,2,1],"solid":"low","facing":2,"note":"냉동 궤","level":0},
		{"kind":"freezer_chest","rect":[78,77,2,1],"solid":"low","facing":3,"note":"냉동 궤","level":0},
		{"kind":"bed","rect":[41,59,2,1],"solid":"none","facing":0,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[47,65,1,1],"solid":"none","facing":1,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[41,65,2,1],"solid":"none","facing":2,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[49,59,2,1],"solid":"none","facing":0,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[54,65,1,1],"solid":"none","facing":1,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[49,65,2,1],"solid":"none","facing":2,"note":"뒤 창고의 장롱","level":1},
		{"kind":"fridge_open","rect":[56,59,1,1],"solid":"none","facing":0,"note":"작업실의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[60,65,2,1],"solid":"none","facing":1,"note":"작업실의 장롱","level":1},
		{"kind":"bed","rect":[56,65,2,1],"solid":"none","facing":2,"note":"작업실의 침대","level":1},
		{"kind":"bed","rect":[63,59,2,1],"solid":"none","facing":0,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[68,65,1,1],"solid":"none","facing":1,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[63,65,2,1],"solid":"none","facing":2,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[70,59,2,1],"solid":"none","facing":0,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[75,65,1,1],"solid":"none","facing":1,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[70,65,2,1],"solid":"none","facing":2,"note":"뒤 창고의 장롱","level":1},
		{"kind":"fridge_open","rect":[77,59,1,1],"solid":"none","facing":0,"note":"작업실의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[81,65,2,1],"solid":"none","facing":1,"note":"작업실의 장롱","level":1},
		{"kind":"bed","rect":[77,65,2,1],"solid":"none","facing":2,"note":"작업실의 침대","level":1},
		{"kind":"bed","rect":[41,72,2,1],"solid":"none","facing":0,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[47,78,1,1],"solid":"none","facing":1,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[41,78,2,1],"solid":"none","facing":2,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[49,72,2,1],"solid":"none","facing":0,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[54,78,1,1],"solid":"none","facing":1,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[49,78,2,1],"solid":"none","facing":2,"note":"뒤 창고의 장롱","level":1},
		{"kind":"fridge_open","rect":[56,72,1,1],"solid":"none","facing":0,"note":"작업실의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[60,78,2,1],"solid":"none","facing":1,"note":"작업실의 장롱","level":1},
		{"kind":"bed","rect":[56,78,2,1],"solid":"none","facing":2,"note":"작업실의 침대","level":1},
		{"kind":"bed","rect":[63,72,2,1],"solid":"none","facing":0,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[68,78,1,1],"solid":"none","facing":1,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[63,78,2,1],"solid":"none","facing":2,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[70,72,2,1],"solid":"none","facing":0,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[75,78,1,1],"solid":"none","facing":1,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[70,78,2,1],"solid":"none","facing":2,"note":"뒤 창고의 장롱","level":1},
		{"kind":"fridge_open","rect":[77,72,1,1],"solid":"none","facing":0,"note":"작업실의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[81,78,2,1],"solid":"none","facing":1,"note":"작업실의 장롱","level":1},
		{"kind":"bed","rect":[77,78,2,1],"solid":"none","facing":2,"note":"작업실의 침대","level":1},
		{"kind":"bed","rect":[41,59,2,1],"solid":"none","facing":0,"note":"매장의 침대","level":2},
		{"kind":"fridge_open","rect":[47,65,1,1],"solid":"none","facing":1,"note":"매장의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[41,65,2,1],"solid":"none","facing":2,"note":"매장의 장롱","level":2},
		{"kind":"bed","rect":[49,59,2,1],"solid":"none","facing":0,"note":"뒤 창고의 침대","level":2},
		{"kind":"fridge_open","rect":[54,65,1,1],"solid":"none","facing":1,"note":"뒤 창고의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[49,65,2,1],"solid":"none","facing":2,"note":"뒤 창고의 장롱","level":2},
		{"kind":"fridge_open","rect":[56,59,1,1],"solid":"none","facing":0,"note":"작업실의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[60,65,2,1],"solid":"none","facing":1,"note":"작업실의 장롱","level":2},
		{"kind":"bed","rect":[56,65,2,1],"solid":"none","facing":2,"note":"작업실의 침대","level":2},
		{"kind":"bed","rect":[63,59,2,1],"solid":"none","facing":0,"note":"매장의 침대","level":2},
		{"kind":"fridge_open","rect":[68,65,1,1],"solid":"none","facing":1,"note":"매장의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[63,65,2,1],"solid":"none","facing":2,"note":"매장의 장롱","level":2},
		{"kind":"bed","rect":[70,59,2,1],"solid":"none","facing":0,"note":"뒤 창고의 침대","level":2},
		{"kind":"fridge_open","rect":[75,65,1,1],"solid":"none","facing":1,"note":"뒤 창고의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[70,65,2,1],"solid":"none","facing":2,"note":"뒤 창고의 장롱","level":2},
		{"kind":"fridge_open","rect":[77,59,1,1],"solid":"none","facing":0,"note":"작업실의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[81,65,2,1],"solid":"none","facing":1,"note":"작업실의 장롱","level":2},
		{"kind":"bed","rect":[77,65,2,1],"solid":"none","facing":2,"note":"작업실의 침대","level":2},
		{"kind":"bed","rect":[41,72,2,1],"solid":"none","facing":0,"note":"매장의 침대","level":2},
		{"kind":"fridge_open","rect":[47,78,1,1],"solid":"none","facing":1,"note":"매장의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[41,78,2,1],"solid":"none","facing":2,"note":"매장의 장롱","level":2},
		{"kind":"bed","rect":[49,72,2,1],"solid":"none","facing":0,"note":"뒤 창고의 침대","level":2},
		{"kind":"fridge_open","rect":[54,78,1,1],"solid":"none","facing":1,"note":"뒤 창고의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[49,78,2,1],"solid":"none","facing":2,"note":"뒤 창고의 장롱","level":2},
		{"kind":"fridge_open","rect":[56,72,1,1],"solid":"none","facing":0,"note":"작업실의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[60,78,2,1],"solid":"none","facing":1,"note":"작업실의 장롱","level":2},
		{"kind":"bed","rect":[56,78,2,1],"solid":"none","facing":2,"note":"작업실의 침대","level":2},
		{"kind":"bed","rect":[63,72,2,1],"solid":"none","facing":0,"note":"매장의 침대","level":2},
		{"kind":"fridge_open","rect":[68,78,1,1],"solid":"none","facing":1,"note":"매장의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[63,78,2,1],"solid":"none","facing":2,"note":"매장의 장롱","level":2},
		{"kind":"bed","rect":[70,72,2,1],"solid":"none","facing":0,"note":"뒤 창고의 침대","level":2},
		{"kind":"fridge_open","rect":[75,78,1,1],"solid":"none","facing":1,"note":"뒤 창고의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[70,78,2,1],"solid":"none","facing":2,"note":"뒤 창고의 장롱","level":2},
		{"kind":"fridge_open","rect":[77,72,1,1],"solid":"none","facing":0,"note":"작업실의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[81,78,2,1],"solid":"none","facing":1,"note":"작업실의 장롱","level":2},
		{"kind":"bed","rect":[77,78,2,1],"solid":"none","facing":2,"note":"작업실의 침대","level":2},
		{"kind":"jar_shelf","rect":[41,59,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[47,65,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[41,65,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[49,59,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[54,65,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[49,65,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[56,59,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[61,65,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[56,65,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[63,59,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[68,65,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[63,65,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[70,59,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[75,65,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[70,65,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[77,59,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[82,65,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[77,65,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[41,72,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[47,78,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[41,78,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[49,72,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[54,78,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[49,78,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[56,72,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[61,78,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[56,78,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[63,72,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[68,78,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[63,78,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[70,72,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[75,78,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[70,78,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[77,72,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[82,78,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[77,78,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"bread_rack","rect":[28,21,1,1],"solid":"none","facing":1,"note":"매장의 빵 선반","level":0},
		{"kind":"shop_counter","rect":[19,25,3,1],"solid":"none","facing":2,"note":"매장의 가게 계산대","level":0},
		{"kind":"freezer_chest","rect":[27,25,2,1],"solid":"none","facing":3,"note":"매장의 냉동 궤","level":0},
		{"kind":"bread_rack","rect":[38,21,1,1],"solid":"none","facing":1,"note":"뒤 창고의 빵 선반","level":0},
		{"kind":"butcher_block","rect":[30,25,2,1],"solid":"none","facing":2,"note":"뒤 창고의 정육 도마대","level":0},
		{"kind":"freezer_chest","rect":[37,25,2,1],"solid":"none","facing":3,"note":"뒤 창고의 냉동 궤","level":0},
		{"kind":"butcher_block","rect":[47,21,2,1],"solid":"none","facing":1,"note":"작업실의 정육 도마대","level":0},
		{"kind":"freezer_chest","rect":[40,25,2,1],"solid":"none","facing":2,"note":"작업실의 냉동 궤","level":0},
		{"kind":"bread_rack","rect":[48,25,1,1],"solid":"none","facing":3,"note":"작업실의 빵 선반","level":0},
		{"kind":"bread_rack","rect":[28,30,1,1],"solid":"low","facing":1,"note":"매장의 빵 선반","level":0},
		{"kind":"butcher_block","rect":[19,34,2,1],"solid":"low","facing":2,"note":"매장의 정육 도마대","level":0},
		{"kind":"freezer_chest","rect":[27,34,2,1],"solid":"low","facing":3,"note":"매장의 냉동 궤","level":0},
		{"kind":"bread_rack","rect":[38,30,1,1],"solid":"low","facing":1,"note":"뒤 창고의 빵 선반","level":0},
		{"kind":"butcher_block","rect":[30,34,2,1],"solid":"low","facing":2,"note":"뒤 창고의 정육 도마대","level":0},
		{"kind":"freezer_chest","rect":[37,34,2,1],"solid":"low","facing":3,"note":"뒤 창고의 냉동 궤","level":0},
		{"kind":"butcher_block","rect":[47,30,2,1],"solid":"low","facing":1,"note":"작업실의 정육 도마대","level":0},
		{"kind":"freezer_chest","rect":[40,34,2,1],"solid":"low","facing":2,"note":"작업실의 냉동 궤","level":0},
		{"kind":"bread_rack","rect":[48,34,1,1],"solid":"low","facing":3,"note":"작업실의 빵 선반","level":0},
		{"kind":"bed","rect":[27,21,2,1],"solid":"none","facing":1,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[19,25,1,1],"solid":"none","facing":2,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[27,25,2,1],"solid":"none","facing":3,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[37,21,2,1],"solid":"none","facing":1,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[30,25,1,1],"solid":"none","facing":2,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[37,25,2,1],"solid":"none","facing":3,"note":"뒤 창고의 장롱","level":1},
		{"kind":"fridge_open","rect":[48,21,1,1],"solid":"none","facing":1,"note":"작업실의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[40,25,2,1],"solid":"none","facing":2,"note":"작업실의 장롱","level":1},
		{"kind":"bed","rect":[47,25,2,1],"solid":"none","facing":3,"note":"작업실의 침대","level":1},
		{"kind":"bed","rect":[27,30,2,1],"solid":"none","facing":1,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[19,34,1,1],"solid":"none","facing":2,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[27,34,2,1],"solid":"none","facing":3,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[37,30,2,1],"solid":"none","facing":1,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[30,34,1,1],"solid":"none","facing":2,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[37,34,2,1],"solid":"none","facing":3,"note":"뒤 창고의 장롱","level":1},
		{"kind":"fridge_open","rect":[48,30,1,1],"solid":"none","facing":1,"note":"작업실의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[40,34,2,1],"solid":"none","facing":2,"note":"작업실의 장롱","level":1},
		{"kind":"bed","rect":[47,34,2,1],"solid":"none","facing":3,"note":"작업실의 침대","level":1},
		{"kind":"bed","rect":[27,21,2,1],"solid":"none","facing":1,"note":"매장의 침대","level":2},
		{"kind":"fridge_open","rect":[19,25,1,1],"solid":"none","facing":2,"note":"매장의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[27,25,2,1],"solid":"none","facing":3,"note":"매장의 장롱","level":2},
		{"kind":"bed","rect":[37,21,2,1],"solid":"none","facing":1,"note":"뒤 창고의 침대","level":2},
		{"kind":"fridge_open","rect":[30,25,1,1],"solid":"none","facing":2,"note":"뒤 창고의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[37,25,2,1],"solid":"none","facing":3,"note":"뒤 창고의 장롱","level":2},
		{"kind":"fridge_open","rect":[48,21,1,1],"solid":"none","facing":1,"note":"작업실의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[40,25,2,1],"solid":"none","facing":2,"note":"작업실의 장롱","level":2},
		{"kind":"bed","rect":[47,25,2,1],"solid":"none","facing":3,"note":"작업실의 침대","level":2},
		{"kind":"bed","rect":[27,30,2,1],"solid":"none","facing":1,"note":"매장의 침대","level":2},
		{"kind":"fridge_open","rect":[19,34,1,1],"solid":"none","facing":2,"note":"매장의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[27,34,2,1],"solid":"none","facing":3,"note":"매장의 장롱","level":2},
		{"kind":"bed","rect":[37,30,2,1],"solid":"none","facing":1,"note":"뒤 창고의 침대","level":2},
		{"kind":"fridge_open","rect":[30,34,1,1],"solid":"none","facing":2,"note":"뒤 창고의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[37,34,2,1],"solid":"none","facing":3,"note":"뒤 창고의 장롱","level":2},
		{"kind":"fridge_open","rect":[48,30,1,1],"solid":"none","facing":1,"note":"작업실의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[40,34,2,1],"solid":"none","facing":2,"note":"작업실의 장롱","level":2},
		{"kind":"bed","rect":[47,34,2,1],"solid":"none","facing":3,"note":"작업실의 침대","level":2},
		{"kind":"jar_shelf","rect":[26,21,3,1],"solid":"none","facing":1,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[19,25,1,1],"solid":"none","facing":2,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[27,25,2,1],"solid":"none","facing":3,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[36,21,3,1],"solid":"none","facing":1,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[30,25,1,1],"solid":"none","facing":2,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[37,25,2,1],"solid":"none","facing":3,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[46,21,3,1],"solid":"none","facing":1,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[40,25,1,1],"solid":"none","facing":2,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[47,25,2,1],"solid":"none","facing":3,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[26,30,3,1],"solid":"none","facing":1,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[19,34,1,1],"solid":"none","facing":2,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[27,34,2,1],"solid":"none","facing":3,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[36,30,3,1],"solid":"none","facing":1,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[30,34,1,1],"solid":"none","facing":2,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[37,34,2,1],"solid":"none","facing":3,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[46,30,3,1],"solid":"none","facing":1,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[40,34,1,1],"solid":"none","facing":2,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[47,34,2,1],"solid":"none","facing":3,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"glass_cabinet","rect":[67,21,2,1],"solid":"none","facing":2,"note":"매장의 진열장","level":0},
		{"kind":"shop_counter","rect":[74,25,3,1],"solid":"none","facing":3,"note":"매장의 가게 계산대","level":0},
		{"kind":"shelf","rect":[67,25,3,1],"solid":"none","facing":0,"note":"매장의 선반","level":0},
		{"kind":"glass_cabinet","rect":[78,21,2,1],"solid":"none","facing":2,"note":"뒤 창고의 진열장","level":0},
		{"kind":"shelf","rect":[84,25,3,1],"solid":"none","facing":3,"note":"뒤 창고의 선반","level":0},
		{"kind":"shelf","rect":[78,25,3,1],"solid":"none","facing":0,"note":"뒤 창고의 선반","level":0},
		{"kind":"shelf","rect":[88,21,3,1],"solid":"none","facing":2,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[94,25,3,1],"solid":"none","facing":3,"note":"작업실의 선반","level":0},
		{"kind":"glass_cabinet","rect":[88,25,2,1],"solid":"none","facing":0,"note":"작업실의 진열장","level":0},
		{"kind":"glass_cabinet","rect":[67,30,2,1],"solid":"low","facing":2,"note":"매장의 진열장","level":0},
		{"kind":"shelf","rect":[74,34,3,1],"solid":"low","facing":3,"note":"매장의 선반","level":0},
		{"kind":"shelf","rect":[67,34,3,1],"solid":"low","facing":0,"note":"매장의 선반","level":0},
		{"kind":"glass_cabinet","rect":[78,30,2,1],"solid":"low","facing":2,"note":"뒤 창고의 진열장","level":0},
		{"kind":"shelf","rect":[84,34,3,1],"solid":"low","facing":3,"note":"뒤 창고의 선반","level":0},
		{"kind":"shelf","rect":[78,34,3,1],"solid":"low","facing":0,"note":"뒤 창고의 선반","level":0},
		{"kind":"shelf","rect":[88,30,3,1],"solid":"low","facing":2,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[94,34,3,1],"solid":"low","facing":3,"note":"작업실의 선반","level":0},
		{"kind":"glass_cabinet","rect":[88,34,2,1],"solid":"low","facing":0,"note":"작업실의 진열장","level":0},
		{"kind":"bed","rect":[67,21,2,1],"solid":"none","facing":2,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[76,25,1,1],"solid":"none","facing":3,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[67,25,2,1],"solid":"none","facing":0,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[78,21,2,1],"solid":"none","facing":2,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[86,25,1,1],"solid":"none","facing":3,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[78,25,2,1],"solid":"none","facing":0,"note":"뒤 창고의 장롱","level":1},
		{"kind":"fridge_open","rect":[88,21,1,1],"solid":"none","facing":2,"note":"작업실의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[95,25,2,1],"solid":"none","facing":3,"note":"작업실의 장롱","level":1},
		{"kind":"bed","rect":[88,25,2,1],"solid":"none","facing":0,"note":"작업실의 침대","level":1},
		{"kind":"bed","rect":[67,30,2,1],"solid":"none","facing":2,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[76,34,1,1],"solid":"none","facing":3,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[67,34,2,1],"solid":"none","facing":0,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[78,30,2,1],"solid":"none","facing":2,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[86,34,1,1],"solid":"none","facing":3,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[78,34,2,1],"solid":"none","facing":0,"note":"뒤 창고의 장롱","level":1},
		{"kind":"fridge_open","rect":[88,30,1,1],"solid":"none","facing":2,"note":"작업실의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[95,34,2,1],"solid":"none","facing":3,"note":"작업실의 장롱","level":1},
		{"kind":"bed","rect":[88,34,2,1],"solid":"none","facing":0,"note":"작업실의 침대","level":1},
		{"kind":"bed","rect":[67,21,2,1],"solid":"none","facing":2,"note":"매장의 침대","level":2},
		{"kind":"fridge_open","rect":[76,25,1,1],"solid":"none","facing":3,"note":"매장의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[67,25,2,1],"solid":"none","facing":0,"note":"매장의 장롱","level":2},
		{"kind":"bed","rect":[78,21,2,1],"solid":"none","facing":2,"note":"뒤 창고의 침대","level":2},
		{"kind":"fridge_open","rect":[86,25,1,1],"solid":"none","facing":3,"note":"뒤 창고의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[78,25,2,1],"solid":"none","facing":0,"note":"뒤 창고의 장롱","level":2},
		{"kind":"fridge_open","rect":[88,21,1,1],"solid":"none","facing":2,"note":"작업실의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[95,25,2,1],"solid":"none","facing":3,"note":"작업실의 장롱","level":2},
		{"kind":"bed","rect":[88,25,2,1],"solid":"none","facing":0,"note":"작업실의 침대","level":2},
		{"kind":"bed","rect":[67,30,2,1],"solid":"none","facing":2,"note":"매장의 침대","level":2},
		{"kind":"fridge_open","rect":[76,34,1,1],"solid":"none","facing":3,"note":"매장의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[67,34,2,1],"solid":"none","facing":0,"note":"매장의 장롱","level":2},
		{"kind":"bed","rect":[78,30,2,1],"solid":"none","facing":2,"note":"뒤 창고의 침대","level":2},
		{"kind":"fridge_open","rect":[86,34,1,1],"solid":"none","facing":3,"note":"뒤 창고의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[78,34,2,1],"solid":"none","facing":0,"note":"뒤 창고의 장롱","level":2},
		{"kind":"fridge_open","rect":[88,30,1,1],"solid":"none","facing":2,"note":"작업실의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[95,34,2,1],"solid":"none","facing":3,"note":"작업실의 장롱","level":2},
		{"kind":"bed","rect":[88,34,2,1],"solid":"none","facing":0,"note":"작업실의 침대","level":2},
		{"kind":"hardware_rack","rect":[11,41,3,1],"solid":"low","facing":3,"note":"매장의 철물 걸이대","level":0},
		{"kind":"shop_counter","rect":[5,45,3,1],"solid":"low","facing":0,"note":"매장의 가게 계산대","level":0},
		{"kind":"desk","rect":[12,45,2,1],"solid":"low","facing":1,"note":"매장의 책상","level":0},
		{"kind":"hardware_rack","rect":[21,41,3,1],"solid":"low","facing":3,"note":"뒤 창고의 철물 걸이대","level":0},
		{"kind":"shelf","rect":[15,45,3,1],"solid":"low","facing":0,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[22,45,2,1],"solid":"low","facing":1,"note":"뒤 창고의 책상","level":0},
		{"kind":"shelf","rect":[30,41,3,1],"solid":"low","facing":3,"note":"작업실의 선반","level":0},
		{"kind":"desk","rect":[25,45,2,1],"solid":"low","facing":0,"note":"작업실의 책상","level":0},
		{"kind":"hardware_rack","rect":[30,45,3,1],"solid":"low","facing":1,"note":"작업실의 철물 걸이대","level":0},
		{"kind":"hardware_rack","rect":[11,50,3,1],"solid":"low","facing":3,"note":"매장의 철물 걸이대","level":0},
		{"kind":"shelf","rect":[5,54,3,1],"solid":"low","facing":0,"note":"매장의 선반","level":0},
		{"kind":"desk","rect":[12,54,2,1],"solid":"low","facing":1,"note":"매장의 책상","level":0},
		{"kind":"hardware_rack","rect":[21,50,3,1],"solid":"low","facing":3,"note":"뒤 창고의 철물 걸이대","level":0},
		{"kind":"shelf","rect":[15,54,3,1],"solid":"low","facing":0,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[22,54,2,1],"solid":"low","facing":1,"note":"뒤 창고의 책상","level":0},
		{"kind":"shelf","rect":[30,50,3,1],"solid":"low","facing":3,"note":"작업실의 선반","level":0},
		{"kind":"desk","rect":[25,54,2,1],"solid":"low","facing":0,"note":"작업실의 책상","level":0},
		{"kind":"hardware_rack","rect":[30,54,3,1],"solid":"low","facing":1,"note":"작업실의 철물 걸이대","level":0},
		{"kind":"bed","rect":[12,41,2,1],"solid":"none","facing":3,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[5,45,1,1],"solid":"none","facing":0,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[12,45,2,1],"solid":"none","facing":1,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[22,41,2,1],"solid":"none","facing":3,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[15,45,1,1],"solid":"none","facing":0,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[22,45,2,1],"solid":"none","facing":1,"note":"뒤 창고의 장롱","level":1},
		{"kind":"fridge_open","rect":[32,41,1,1],"solid":"none","facing":3,"note":"작업실의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[25,45,2,1],"solid":"none","facing":0,"note":"작업실의 장롱","level":1},
		{"kind":"bed","rect":[31,45,2,1],"solid":"none","facing":1,"note":"작업실의 침대","level":1},
		{"kind":"bed","rect":[12,50,2,1],"solid":"none","facing":3,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[5,54,1,1],"solid":"none","facing":0,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[12,54,2,1],"solid":"none","facing":1,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[22,50,2,1],"solid":"none","facing":3,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[15,54,1,1],"solid":"none","facing":0,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[22,54,2,1],"solid":"none","facing":1,"note":"뒤 창고의 장롱","level":1},
		{"kind":"fridge_open","rect":[32,50,1,1],"solid":"none","facing":3,"note":"작업실의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[25,54,2,1],"solid":"none","facing":0,"note":"작업실의 장롱","level":1},
		{"kind":"bed","rect":[31,54,2,1],"solid":"none","facing":1,"note":"작업실의 침대","level":1},
		{"kind":"bed","rect":[12,41,2,1],"solid":"none","facing":3,"note":"매장의 침대","level":2},
		{"kind":"fridge_open","rect":[5,45,1,1],"solid":"none","facing":0,"note":"매장의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[12,45,2,1],"solid":"none","facing":1,"note":"매장의 장롱","level":2},
		{"kind":"bed","rect":[22,41,2,1],"solid":"none","facing":3,"note":"뒤 창고의 침대","level":2},
		{"kind":"fridge_open","rect":[15,45,1,1],"solid":"none","facing":0,"note":"뒤 창고의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[22,45,2,1],"solid":"none","facing":1,"note":"뒤 창고의 장롱","level":2},
		{"kind":"fridge_open","rect":[32,41,1,1],"solid":"none","facing":3,"note":"작업실의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[25,45,2,1],"solid":"none","facing":0,"note":"작업실의 장롱","level":2},
		{"kind":"bed","rect":[31,45,2,1],"solid":"none","facing":1,"note":"작업실의 침대","level":2},
		{"kind":"bed","rect":[12,50,2,1],"solid":"none","facing":3,"note":"매장의 침대","level":2},
		{"kind":"fridge_open","rect":[5,54,1,1],"solid":"none","facing":0,"note":"매장의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[12,54,2,1],"solid":"none","facing":1,"note":"매장의 장롱","level":2},
		{"kind":"bed","rect":[22,50,2,1],"solid":"none","facing":3,"note":"뒤 창고의 침대","level":2},
		{"kind":"fridge_open","rect":[15,54,1,1],"solid":"none","facing":0,"note":"뒤 창고의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[22,54,2,1],"solid":"none","facing":1,"note":"뒤 창고의 장롱","level":2},
		{"kind":"fridge_open","rect":[32,50,1,1],"solid":"none","facing":3,"note":"작업실의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[25,54,2,1],"solid":"none","facing":0,"note":"작업실의 장롱","level":2},
		{"kind":"bed","rect":[31,54,2,1],"solid":"none","facing":1,"note":"작업실의 침대","level":2},
		{"kind":"cloth_bolt_rack","rect":[137,21,3,1],"solid":"low","facing":0,"note":"매장의 천 두루마리 선반","level":0},
		{"kind":"shop_counter","rect":[144,25,3,1],"solid":"low","facing":1,"note":"매장의 가게 계산대","level":0},
		{"kind":"desk","rect":[137,25,2,1],"solid":"low","facing":2,"note":"매장의 책상","level":0},
		{"kind":"cloth_bolt_rack","rect":[148,21,3,1],"solid":"low","facing":0,"note":"뒤 창고의 천 두루마리 선반","level":0},
		{"kind":"shelf","rect":[154,25,3,1],"solid":"low","facing":1,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[148,25,2,1],"solid":"low","facing":2,"note":"뒤 창고의 책상","level":0},
		{"kind":"shelf","rect":[158,21,3,1],"solid":"low","facing":0,"note":"작업실의 선반","level":0},
		{"kind":"desk","rect":[165,25,2,1],"solid":"low","facing":1,"note":"작업실의 책상","level":0},
		{"kind":"cloth_bolt_rack","rect":[158,25,3,1],"solid":"low","facing":2,"note":"작업실의 천 두루마리 선반","level":0},
		{"kind":"cloth_bolt_rack","rect":[137,30,3,1],"solid":"low","facing":0,"note":"매장의 천 두루마리 선반","level":0},
		{"kind":"shelf","rect":[144,34,3,1],"solid":"low","facing":1,"note":"매장의 선반","level":0},
		{"kind":"desk","rect":[137,34,2,1],"solid":"low","facing":2,"note":"매장의 책상","level":0},
		{"kind":"cloth_bolt_rack","rect":[148,30,3,1],"solid":"low","facing":0,"note":"뒤 창고의 천 두루마리 선반","level":0},
		{"kind":"shelf","rect":[154,34,3,1],"solid":"low","facing":1,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[148,34,2,1],"solid":"low","facing":2,"note":"뒤 창고의 책상","level":0},
		{"kind":"shelf","rect":[158,30,3,1],"solid":"low","facing":0,"note":"작업실의 선반","level":0},
		{"kind":"desk","rect":[165,34,2,1],"solid":"low","facing":1,"note":"작업실의 책상","level":0},
		{"kind":"cloth_bolt_rack","rect":[158,34,3,1],"solid":"low","facing":2,"note":"작업실의 천 두루마리 선반","level":0},
		{"kind":"bed","rect":[137,21,2,1],"solid":"none","facing":0,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[146,25,1,1],"solid":"none","facing":1,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[137,25,2,1],"solid":"none","facing":2,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[148,21,2,1],"solid":"none","facing":0,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[156,25,1,1],"solid":"none","facing":1,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[148,25,2,1],"solid":"none","facing":2,"note":"뒤 창고의 장롱","level":1},
		{"kind":"fridge_open","rect":[158,21,1,1],"solid":"none","facing":0,"note":"작업실의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[165,25,2,1],"solid":"none","facing":1,"note":"작업실의 장롱","level":1},
		{"kind":"bed","rect":[158,25,2,1],"solid":"none","facing":2,"note":"작업실의 침대","level":1},
		{"kind":"bed","rect":[137,30,2,1],"solid":"none","facing":0,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[146,34,1,1],"solid":"none","facing":1,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[137,34,2,1],"solid":"none","facing":2,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[148,30,2,1],"solid":"none","facing":0,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[156,34,1,1],"solid":"none","facing":1,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[148,34,2,1],"solid":"none","facing":2,"note":"뒤 창고의 장롱","level":1},
		{"kind":"fridge_open","rect":[158,30,1,1],"solid":"none","facing":0,"note":"작업실의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[165,34,2,1],"solid":"none","facing":1,"note":"작업실의 장롱","level":1},
		{"kind":"bed","rect":[158,34,2,1],"solid":"none","facing":2,"note":"작업실의 침대","level":1},
		{"kind":"bed","rect":[137,21,2,1],"solid":"none","facing":0,"note":"매장의 침대","level":2},
		{"kind":"fridge_open","rect":[146,25,1,1],"solid":"none","facing":1,"note":"매장의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[137,25,2,1],"solid":"none","facing":2,"note":"매장의 장롱","level":2},
		{"kind":"bed","rect":[148,21,2,1],"solid":"none","facing":0,"note":"뒤 창고의 침대","level":2},
		{"kind":"fridge_open","rect":[156,25,1,1],"solid":"none","facing":1,"note":"뒤 창고의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[148,25,2,1],"solid":"none","facing":2,"note":"뒤 창고의 장롱","level":2},
		{"kind":"fridge_open","rect":[158,21,1,1],"solid":"none","facing":0,"note":"작업실의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[165,25,2,1],"solid":"none","facing":1,"note":"작업실의 장롱","level":2},
		{"kind":"bed","rect":[158,25,2,1],"solid":"none","facing":2,"note":"작업실의 침대","level":2},
		{"kind":"bed","rect":[137,30,2,1],"solid":"none","facing":0,"note":"매장의 침대","level":2},
		{"kind":"fridge_open","rect":[146,34,1,1],"solid":"none","facing":1,"note":"매장의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[137,34,2,1],"solid":"none","facing":2,"note":"매장의 장롱","level":2},
		{"kind":"bed","rect":[148,30,2,1],"solid":"none","facing":0,"note":"뒤 창고의 침대","level":2},
		{"kind":"fridge_open","rect":[156,34,1,1],"solid":"none","facing":1,"note":"뒤 창고의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[148,34,2,1],"solid":"none","facing":2,"note":"뒤 창고의 장롱","level":2},
		{"kind":"fridge_open","rect":[158,30,1,1],"solid":"none","facing":0,"note":"작업실의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[165,34,2,1],"solid":"none","facing":1,"note":"작업실의 장롱","level":2},
		{"kind":"bed","rect":[158,34,2,1],"solid":"none","facing":2,"note":"작업실의 침대","level":2},
		{"kind":"display_shelf","rect":[139,55,4,1],"solid":"low","facing":1,"note":"매장의 진열대","level":0},
		{"kind":"shop_counter","rect":[135,59,3,1],"solid":"low","facing":2,"note":"매장의 가게 계산대","level":0},
		{"kind":"shelf","rect":[140,59,3,1],"solid":"low","facing":3,"note":"매장의 선반","level":0},
		{"kind":"display_shelf","rect":[147,55,4,1],"solid":"low","facing":1,"note":"뒤 창고의 진열대","level":0},
		{"kind":"shelf","rect":[144,59,3,1],"solid":"low","facing":2,"note":"뒤 창고의 선반","level":0},
		{"kind":"shelf","rect":[148,59,3,1],"solid":"low","facing":3,"note":"뒤 창고의 선반","level":0},
		{"kind":"shelf","rect":[156,55,3,1],"solid":"low","facing":1,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[152,59,3,1],"solid":"low","facing":2,"note":"작업실의 선반","level":0},
		{"kind":"display_shelf","rect":[152,55,4,1],"solid":"low","facing":3,"note":"작업실의 진열대","level":0},
		{"kind":"display_shelf","rect":[163,55,4,1],"solid":"low","facing":1,"note":"매장의 진열대","level":0},
		{"kind":"shelf","rect":[160,59,3,1],"solid":"low","facing":2,"note":"매장의 선반","level":0},
		{"kind":"shelf","rect":[164,59,3,1],"solid":"low","facing":3,"note":"매장의 선반","level":0},
		{"kind":"display_shelf","rect":[135,68,4,1],"solid":"low","facing":1,"note":"매장의 진열대","level":0},
		{"kind":"shelf","rect":[140,64,3,1],"solid":"low","facing":2,"note":"매장의 선반","level":0},
		{"kind":"shelf","rect":[140,68,3,1],"solid":"low","facing":3,"note":"매장의 선반","level":0},
		{"kind":"display_shelf","rect":[144,68,4,1],"solid":"low","facing":1,"note":"뒤 창고의 진열대","level":0},
		{"kind":"shelf","rect":[148,64,3,1],"solid":"low","facing":2,"note":"뒤 창고의 선반","level":0},
		{"kind":"shelf","rect":[148,68,3,1],"solid":"low","facing":3,"note":"뒤 창고의 선반","level":0},
		{"kind":"shelf","rect":[156,64,3,1],"solid":"low","facing":1,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[152,68,3,1],"solid":"low","facing":2,"note":"작업실의 선반","level":0},
		{"kind":"display_shelf","rect":[155,68,4,1],"solid":"low","facing":3,"note":"작업실의 진열대","level":0},
		{"kind":"display_shelf","rect":[160,68,4,1],"solid":"low","facing":1,"note":"매장의 진열대","level":0},
		{"kind":"shelf","rect":[164,64,3,1],"solid":"low","facing":2,"note":"매장의 선반","level":0},
		{"kind":"shelf","rect":[164,68,3,1],"solid":"low","facing":3,"note":"매장의 선반","level":0},
		{"kind":"bed","rect":[141,55,2,1],"solid":"none","facing":1,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[135,59,1,1],"solid":"none","facing":2,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[141,59,2,1],"solid":"none","facing":3,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[149,55,2,1],"solid":"none","facing":1,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[144,59,1,1],"solid":"none","facing":2,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[149,59,2,1],"solid":"none","facing":3,"note":"뒤 창고의 장롱","level":1},
		{"kind":"fridge_open","rect":[158,55,1,1],"solid":"none","facing":1,"note":"작업실의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[152,59,2,1],"solid":"none","facing":2,"note":"작업실의 장롱","level":1},
		{"kind":"bed","rect":[157,59,2,1],"solid":"none","facing":3,"note":"작업실의 침대","level":1},
		{"kind":"bed","rect":[165,55,2,1],"solid":"none","facing":1,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[160,59,1,1],"solid":"none","facing":2,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[165,59,2,1],"solid":"none","facing":3,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[141,64,2,1],"solid":"none","facing":1,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[135,68,1,1],"solid":"none","facing":2,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[141,68,2,1],"solid":"none","facing":3,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[149,64,2,1],"solid":"none","facing":1,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[144,68,1,1],"solid":"none","facing":2,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[149,68,2,1],"solid":"none","facing":3,"note":"뒤 창고의 장롱","level":1},
		{"kind":"fridge_open","rect":[158,64,1,1],"solid":"none","facing":1,"note":"작업실의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[152,68,2,1],"solid":"none","facing":2,"note":"작업실의 장롱","level":1},
		{"kind":"bed","rect":[157,68,2,1],"solid":"none","facing":3,"note":"작업실의 침대","level":1},
		{"kind":"bed","rect":[165,64,2,1],"solid":"none","facing":1,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[160,68,1,1],"solid":"none","facing":2,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[165,68,2,1],"solid":"none","facing":3,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[141,55,2,1],"solid":"none","facing":1,"note":"매장의 침대","level":2},
		{"kind":"fridge_open","rect":[135,59,1,1],"solid":"none","facing":2,"note":"매장의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[141,59,2,1],"solid":"none","facing":3,"note":"매장의 장롱","level":2},
		{"kind":"bed","rect":[149,55,2,1],"solid":"none","facing":1,"note":"뒤 창고의 침대","level":2},
		{"kind":"fridge_open","rect":[144,59,1,1],"solid":"none","facing":2,"note":"뒤 창고의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[149,59,2,1],"solid":"none","facing":3,"note":"뒤 창고의 장롱","level":2},
		{"kind":"fridge_open","rect":[158,55,1,1],"solid":"none","facing":1,"note":"작업실의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[152,59,2,1],"solid":"none","facing":2,"note":"작업실의 장롱","level":2},
		{"kind":"bed","rect":[157,59,2,1],"solid":"none","facing":3,"note":"작업실의 침대","level":2},
		{"kind":"bed","rect":[165,55,2,1],"solid":"none","facing":1,"note":"매장의 침대","level":2},
		{"kind":"fridge_open","rect":[160,59,1,1],"solid":"none","facing":2,"note":"매장의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[165,59,2,1],"solid":"none","facing":3,"note":"매장의 장롱","level":2},
		{"kind":"bed","rect":[141,64,2,1],"solid":"none","facing":1,"note":"매장의 침대","level":2},
		{"kind":"fridge_open","rect":[135,68,1,1],"solid":"none","facing":2,"note":"매장의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[141,68,2,1],"solid":"none","facing":3,"note":"매장의 장롱","level":2},
		{"kind":"bed","rect":[149,64,2,1],"solid":"none","facing":1,"note":"뒤 창고의 침대","level":2},
		{"kind":"fridge_open","rect":[144,68,1,1],"solid":"none","facing":2,"note":"뒤 창고의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[149,68,2,1],"solid":"none","facing":3,"note":"뒤 창고의 장롱","level":2},
		{"kind":"fridge_open","rect":[158,64,1,1],"solid":"none","facing":1,"note":"작업실의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[152,68,2,1],"solid":"none","facing":2,"note":"작업실의 장롱","level":2},
		{"kind":"bed","rect":[157,68,2,1],"solid":"none","facing":3,"note":"작업실의 침대","level":2},
		{"kind":"bed","rect":[165,64,2,1],"solid":"none","facing":1,"note":"매장의 침대","level":2},
		{"kind":"fridge_open","rect":[160,68,1,1],"solid":"none","facing":2,"note":"매장의 문 열린 냉장고","level":2},
		{"kind":"wardrobe","rect":[165,68,2,1],"solid":"none","facing":3,"note":"매장의 장롱","level":2},
		{"kind":"flour_sack_pile","rect":[5,81,2,2],"solid":"low","facing":2,"note":"매장의 밀가루 자루 더미","level":0},
		{"kind":"shop_counter","rect":[11,83,3,1],"solid":"low","facing":3,"note":"매장의 가게 계산대","level":0},
		{"kind":"shelf","rect":[5,83,3,1],"solid":"low","facing":0,"note":"매장의 선반","level":0},
		{"kind":"flour_sack_pile","rect":[15,81,2,2],"solid":"low","facing":2,"note":"뒤 창고의 밀가루 자루 더미","level":0},
		{"kind":"shelf","rect":[20,83,3,1],"solid":"low","facing":3,"note":"뒤 창고의 선반","level":0},
		{"kind":"shelf","rect":[15,83,3,1],"solid":"low","facing":0,"note":"뒤 창고의 선반","level":0},
		{"kind":"flour_sack_pile","rect":[5,88,2,2],"solid":"low","facing":2,"note":"매장의 밀가루 자루 더미","level":0},
		{"kind":"shelf","rect":[11,90,3,1],"solid":"low","facing":3,"note":"매장의 선반","level":0},
		{"kind":"shelf","rect":[5,90,3,1],"solid":"low","facing":0,"note":"매장의 선반","level":0},
		{"kind":"flour_sack_pile","rect":[15,88,2,2],"solid":"low","facing":2,"note":"뒤 창고의 밀가루 자루 더미","level":0},
		{"kind":"shelf","rect":[20,90,3,1],"solid":"low","facing":3,"note":"뒤 창고의 선반","level":0},
		{"kind":"shelf","rect":[15,90,3,1],"solid":"low","facing":0,"note":"뒤 창고의 선반","level":0},
		{"kind":"bed","rect":[5,81,2,1],"solid":"none","facing":2,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[13,83,1,1],"solid":"none","facing":3,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[5,83,2,1],"solid":"none","facing":0,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[15,81,2,1],"solid":"none","facing":2,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[22,83,1,1],"solid":"none","facing":3,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[15,83,2,1],"solid":"none","facing":0,"note":"뒤 창고의 장롱","level":1},
		{"kind":"bed","rect":[5,88,2,1],"solid":"none","facing":2,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[13,90,1,1],"solid":"none","facing":3,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[5,90,2,1],"solid":"none","facing":0,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[15,88,2,1],"solid":"none","facing":2,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[22,90,1,1],"solid":"none","facing":3,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[15,90,2,1],"solid":"none","facing":0,"note":"뒤 창고의 장롱","level":1},
		{"kind":"tin_crate","rect":[152,85,2,1],"solid":"low","facing":3,"note":"매장의 통조림 상자","level":0},
		{"kind":"barrel","rect":[143,88,1,1],"solid":"low","facing":0,"note":"매장의 통","level":0},
		{"kind":"pallet_stack","rect":[152,87,2,2],"solid":"low","facing":1,"note":"매장의 팰릿 더미","level":0},
		{"kind":"tin_crate","rect":[163,85,2,1],"solid":"low","facing":3,"note":"뒤 창고의 통조림 상자","level":0},
		{"kind":"barrel","rect":[155,88,1,1],"solid":"low","facing":0,"note":"뒤 창고의 통","level":0},
		{"kind":"pallet_stack","rect":[163,87,2,2],"solid":"low","facing":1,"note":"뒤 창고의 팰릿 더미","level":0},
		{"kind":"tin_crate","rect":[152,93,2,1],"solid":"low","facing":3,"note":"매장의 통조림 상자","level":0},
		{"kind":"barrel","rect":[143,96,1,1],"solid":"low","facing":0,"note":"매장의 통","level":0},
		{"kind":"pallet_stack","rect":[152,95,2,2],"solid":"low","facing":1,"note":"매장의 팰릿 더미","level":0},
		{"kind":"tin_crate","rect":[163,93,2,1],"solid":"low","facing":3,"note":"뒤 창고의 통조림 상자","level":0},
		{"kind":"barrel","rect":[155,96,1,1],"solid":"low","facing":0,"note":"뒤 창고의 통","level":0},
		{"kind":"pallet_stack","rect":[163,95,2,2],"solid":"low","facing":1,"note":"뒤 창고의 팰릿 더미","level":0},
		{"kind":"jar_shelf","rect":[151,85,3,1],"solid":"none","facing":3,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[143,88,1,1],"solid":"none","facing":0,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[152,88,2,1],"solid":"none","facing":1,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[162,85,3,1],"solid":"none","facing":3,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[155,88,1,1],"solid":"none","facing":0,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[163,88,2,1],"solid":"none","facing":1,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[151,93,3,1],"solid":"none","facing":3,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[143,96,1,1],"solid":"none","facing":0,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[152,96,2,1],"solid":"none","facing":1,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[162,93,3,1],"solid":"none","facing":3,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[155,96,1,1],"solid":"none","facing":0,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[163,96,2,1],"solid":"none","facing":1,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"shelf","rect":[105,13,3,1],"solid":"none","facing":0,"note":"매장의 선반","level":0},
		{"kind":"desk","rect":[114,17,2,1],"solid":"none","facing":1,"note":"매장의 책상","level":0},
		{"kind":"crate_stack","rect":[105,16,2,2],"solid":"none","facing":2,"note":"매장의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[117,13,3,1],"solid":"low","facing":0,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[125,17,2,1],"solid":"low","facing":1,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[117,16,2,2],"solid":"low","facing":2,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[105,22,3,1],"solid":"none","facing":0,"note":"매장의 선반","level":0},
		{"kind":"desk","rect":[114,26,2,1],"solid":"none","facing":1,"note":"매장의 책상","level":0},
		{"kind":"crate_stack","rect":[105,25,2,2],"solid":"none","facing":2,"note":"매장의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[117,22,3,1],"solid":"low","facing":0,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[125,26,2,1],"solid":"low","facing":1,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[117,25,2,2],"solid":"low","facing":2,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"desk","rect":[95,63,2,1],"solid":"low","facing":1,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[89,67,2,2],"solid":"low","facing":2,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[94,68,3,1],"solid":"low","facing":3,"note":"작업실의 선반","level":0},
		{"kind":"desk","rect":[101,55,2,1],"solid":"low","facing":2,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[105,59,2,2],"solid":"low","facing":3,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[101,60,3,1],"solid":"low","facing":0,"note":"작업실의 선반","level":0},
		{"kind":"desk","rect":[91,83,2,1],"solid":"low","facing":3,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[87,87,2,2],"solid":"low","facing":0,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[90,88,3,1],"solid":"low","facing":1,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[96,83,3,1],"solid":"low","facing":3,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[94,88,2,1],"solid":"low","facing":0,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[97,87,2,2],"solid":"low","facing":1,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[3,25,3,1],"solid":"none","facing":0,"note":"매장의 선반","level":0},
		{"kind":"desk","rect":[4,30,2,1],"solid":"low","facing":1,"note":"매장의 책상","level":0},
		{"kind":"shelf","rect":[10,25,3,1],"solid":"none","facing":0,"note":"매장의 선반","level":0},
		{"kind":"desk","rect":[11,30,2,1],"solid":"low","facing":1,"note":"매장의 책상","level":0},
		{"kind":"desk","rect":[47,87,2,1],"solid":"low","facing":1,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[43,93,2,2],"solid":"low","facing":2,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[46,94,3,1],"solid":"low","facing":3,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[52,87,3,1],"solid":"low","facing":1,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[50,94,2,1],"solid":"low","facing":2,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[53,93,2,2],"solid":"low","facing":3,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"desk","rect":[71,89,2,1],"solid":"low","facing":2,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[74,93,2,2],"solid":"low","facing":3,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[71,94,3,1],"solid":"low","facing":0,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[77,89,3,1],"solid":"low","facing":2,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[79,94,2,1],"solid":"low","facing":3,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[77,93,2,2],"solid":"low","facing":0,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"desk","rect":[129,75,2,1],"solid":"low","facing":3,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[123,79,2,2],"solid":"low","facing":0,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[128,80,3,1],"solid":"low","facing":1,"note":"작업실의 선반","level":0},
		{"kind":"shopping_cart","rect":[41,59,1,1],"solid":"low","facing":0,"note":"판매장의 장보기 수레","level":0},
		{"kind":"lamp_post","rect":[68,73,1,1],"solid":"none","facing":1,"note":"판매장의 꺼진 등잔","level":0},
		{"kind":"shelf","rect":[41,73,3,1],"solid":"low","facing":2,"note":"판매장의 선반","level":0},
		{"kind":"tin_crate","rect":[70,59,2,1],"solid":"low","facing":0,"note":"뒤 창고의 통조림 상자","level":0},
		{"kind":"flour_sack_pile","rect":[81,64,2,2],"solid":"low","facing":1,"note":"뒤 창고의 밀가루 자루 더미","level":0},
		{"kind":"pallet_stack","rect":[70,64,2,2],"solid":"low","facing":2,"note":"뒤 창고의 팰릿 더미","level":0},
		{"kind":"bench","rect":[70,70,3,1],"solid":"low","facing":0,"note":"뒷문 홀의 긴 의자","level":0},
		{"kind":"lamp_post","rect":[82,70,1,1],"solid":"none","facing":1,"note":"뒷문 홀의 꺼진 등잔","level":0},
		{"kind":"desk","rect":[70,72,2,1],"solid":"low","facing":0,"note":"사무 방의 책상","level":0},
		{"kind":"office_cabinet","rect":[74,78,2,1],"solid":"low","facing":1,"note":"사무 방의 사무실 서류장","level":0},
		{"kind":"shelf","rect":[70,78,3,1],"solid":"low","facing":2,"note":"사무 방의 선반","level":0},
		{"kind":"freezer_chest","rect":[77,72,2,1],"solid":"low","facing":0,"note":"냉동 칸의 냉동 궤","level":0},
		{"kind":"barrel","rect":[82,78,1,1],"solid":"low","facing":1,"note":"냉동 칸의 통","level":0},
		{"kind":"tin_crate","rect":[77,78,2,1],"solid":"low","facing":2,"note":"냉동 칸의 통조림 상자","level":0},
		{"kind":"desk","rect":[41,75,2,1],"solid":"low","facing":0,"note":"서쪽 계단실의 책상","level":0},
		{"kind":"office_cabinet","rect":[48,78,2,1],"solid":"low","facing":1,"note":"서쪽 계단실의 사무실 서류장","level":0},
		{"kind":"lamp_post","rect":[41,78,1,1],"solid":"none","facing":2,"note":"서쪽 계단실의 꺼진 등잔","level":0},
		{"kind":"tin_crate","rect":[51,75,2,1],"solid":"low","facing":0,"note":"저장 칸의 통조림 상자","level":0},
		{"kind":"sack_pile","rect":[58,77,2,2],"solid":"low","facing":1,"note":"저장 칸의 자루 더미","level":0},
		{"kind":"barrel","rect":[51,78,1,1],"solid":"low","facing":2,"note":"저장 칸의 통","level":0},
		{"kind":"desk","rect":[61,75,2,1],"solid":"low","facing":0,"note":"동쪽 계단실의 책상","level":0},
		{"kind":"office_cabinet","rect":[67,78,2,1],"solid":"low","facing":1,"note":"동쪽 계단실의 사무실 서류장","level":0},
		{"kind":"lamp_post","rect":[61,78,1,1],"solid":"none","facing":2,"note":"동쪽 계단실의 꺼진 등잔","level":0},
		{"kind":"car","rect":[28,10,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
		{"kind":"bench","rect":[55,11,1,3],"solid":"low","facing":1,"note":"긴 의자","level":0},
		{"kind":"car","rect":[50,23,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
		{"kind":"firewood_pile","rect":[54,23,2,1],"solid":"low","facing":0,"note":"장작 더미","level":0},
		{"kind":"car","rect":[62,23,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
		{"kind":"pallet_stack","rect":[40,55,2,2],"solid":"low","facing":1,"note":"팰릿 더미","level":0},
		{"kind":"crate_stack","rect":[45,54,2,2],"solid":"low","facing":2,"note":"나무 상자 더미","level":0},
		{"kind":"handcart","rect":[49,56,2,1],"solid":"low","facing":3,"note":"손수레","level":0},
		{"kind":"pallet_stack","rect":[66,17,2,2],"solid":"none","facing":0,"note":"팰릿 더미","level":0},
		{"kind":"crate_stack","rect":[71,16,2,2],"solid":"none","facing":1,"note":"나무 상자 더미","level":0},
		{"kind":"handcart","rect":[75,18,2,1],"solid":"none","facing":2,"note":"손수레","level":0},
		{"kind":"pallet_stack","rect":[136,17,2,2],"solid":"low","facing":3,"note":"팰릿 더미","level":0},
		{"kind":"crate_stack","rect":[141,16,2,2],"solid":"low","facing":0,"note":"나무 상자 더미","level":0},
		{"kind":"handcart","rect":[145,18,2,1],"solid":"low","facing":1,"note":"손수레","level":0},
		{"kind":"pallet_stack","rect":[88,59,2,2],"solid":"low","facing":2,"note":"팰릿 더미","level":0},
		{"kind":"crate_stack","rect":[93,58,2,2],"solid":"low","facing":3,"note":"나무 상자 더미","level":0},
		{"kind":"market_stall","rect":[76,48,3,2],"solid":"low","facing":0,"note":"시장 좌판","level":0},
		{"kind":"market_stall","rect":[92,49,3,2],"solid":"low","facing":1,"note":"시장 좌판","level":0},
		{"kind":"barrel","rect":[80,50,1,1],"solid":"low","facing":2,"note":"통","level":0},
		{"kind":"crate_stack","rect":[88,49,2,2],"solid":"low","facing":3,"note":"나무 상자 더미","level":0},
		{"kind":"laundry_line","rect":[94,72,6,1],"solid":"none","facing":0,"note":"언 천 조각","level":0},
		{"kind":"bin_bay","rect":[104,72,4,2],"solid":"low","facing":1,"note":"쓰레기통 칸","level":0},
		{"kind":"car","rect":[110,86,4,2],"solid":"low","facing":2,"note":"버려진 차","level":0},
		{"kind":"car","rect":[121,90,4,2],"solid":"low","facing":3,"note":"버려진 차","level":0},
		{"kind":"lamp_post","rect":[86,49,1,1],"solid":"none","facing":0,"note":"꺼진 등잔","level":0},
		{"kind":"lamp_post","rect":[32,61,1,1],"solid":"none","facing":1,"note":"꺼진 등잔","level":0},
		{"kind":"crate_stack","rect":[33,63,2,2],"solid":"low","facing":2,"note":"나무 상자 더미","level":0},
		{"kind":"lamp_post","rect":[114,65,1,1],"solid":"none","facing":3,"note":"꺼진 등잔","level":0},
		{"kind":"crate_stack","rect":[115,67,2,2],"solid":"low","facing":0,"note":"나무 상자 더미","level":0},
		{"kind":"lamp_post","rect":[120,87,1,1],"solid":"none","facing":1,"note":"꺼진 등잔","level":0},
		{"kind":"street_tree","rect":[54,12,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[55,18,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[62,31,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[34,37,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[63,37,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[54,41,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[88,42,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[117,42,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[146,42,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[35,43,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[64,43,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[93,43,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[122,43,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[151,43,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[65,49,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[123,49,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[152,49,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[41,50,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[70,50,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[128,50,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[157,50,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[56,53,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[90,54,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[95,55,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[23,58,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[28,59,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[120,60,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[24,64,1,1],"solid":"tree","facing":1,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[29,65,1,1],"solid":"tree","facing":2,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[34,66,1,1],"solid":"tree","facing":3,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[121,66,1,1],"solid":"tree","facing":0,"note":"가로수","level":0},
		{"kind":"street_tree","rect":[35,72,1,1],"solid":"tree","facing":1,"note":"가로수","level":0}],
	"containers": [{"id":"cache_0","name":"매장 상자","cell":[46,65],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_1","name":"뒤 창고 상자","cell":[53,65],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_2","name":"작업실 상자","cell":[58,65],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_3","name":"매장 상자","cell":[67,65],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_4","name":"뒤 창고 상자","cell":[74,65],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_5","name":"작업실 상자","cell":[79,65],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_6","name":"매장 상자","cell":[46,78],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_7","name":"뒤 창고 상자","cell":[53,78],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_8","name":"작업실 상자","cell":[59,78],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_9","name":"매장 상자","cell":[67,78],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_10","name":"뒤 창고 상자","cell":[74,78],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_11","name":"작업실 상자","cell":[80,78],"level":1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_12","name":"매장 상자","cell":[46,65],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_13","name":"뒤 창고 상자","cell":[53,65],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_14","name":"작업실 상자","cell":[58,65],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_15","name":"매장 상자","cell":[67,65],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_16","name":"뒤 창고 상자","cell":[74,65],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_17","name":"작업실 상자","cell":[79,65],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_18","name":"매장 상자","cell":[46,78],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_19","name":"뒤 창고 상자","cell":[53,78],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_20","name":"작업실 상자","cell":[59,78],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_21","name":"매장 상자","cell":[67,78],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_22","name":"뒤 창고 상자","cell":[74,78],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_23","name":"작업실 상자","cell":[80,78],"level":2,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_24","name":"저장 칸 상자","cell":[46,65],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_25","name":"저장 칸 상자","cell":[53,65],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_26","name":"저장 칸 상자","cell":[60,65],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_27","name":"저장 칸 상자","cell":[67,65],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_28","name":"저장 칸 상자","cell":[74,65],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_29","name":"저장 칸 상자","cell":[81,65],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_30","name":"안쪽 저장 상자","cell":[46,78],"level":-1,"building":0,"search":4,"items":["food_pack","food_pack","food_pack","food_pack"],"locked":true,"searched":false},
		{"id":"cache_31","name":"저장 칸 상자","cell":[53,78],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_32","name":"저장 칸 상자","cell":[60,78],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_33","name":"저장 칸 상자","cell":[67,78],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_34","name":"저장 칸 상자","cell":[74,78],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_35","name":"저장 칸 상자","cell":[81,78],"level":-1,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_36","name":"매장 상자","cell":[26,25],"level":0,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_37","name":"뒤 창고 상자","cell":[36,25],"level":0,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_38","name":"작업실 상자","cell":[47,25],"level":0,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_39","name":"매장 상자","cell":[26,34],"level":0,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_40","name":"뒤 창고 상자","cell":[36,34],"level":0,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_41","name":"작업실 상자","cell":[47,34],"level":0,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_42","name":"매장 상자","cell":[26,25],"level":1,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_43","name":"뒤 창고 상자","cell":[36,25],"level":1,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_44","name":"작업실 상자","cell":[46,25],"level":1,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_45","name":"매장 상자","cell":[26,34],"level":1,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_46","name":"뒤 창고 상자","cell":[36,34],"level":1,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_47","name":"작업실 상자","cell":[46,34],"level":1,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_48","name":"매장 상자","cell":[26,25],"level":2,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_49","name":"뒤 창고 상자","cell":[36,25],"level":2,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_50","name":"작업실 상자","cell":[46,25],"level":2,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_51","name":"매장 상자","cell":[26,34],"level":2,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_52","name":"뒤 창고 상자","cell":[36,34],"level":2,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_53","name":"작업실 상자","cell":[46,34],"level":2,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_54","name":"저장 칸 상자","cell":[26,25],"level":-1,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_55","name":"저장 칸 상자","cell":[36,25],"level":-1,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_56","name":"저장 칸 상자","cell":[46,25],"level":-1,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_57","name":"저장 칸 상자","cell":[26,34],"level":-1,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_58","name":"저장 칸 상자","cell":[36,34],"level":-1,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_59","name":"저장 칸 상자","cell":[46,34],"level":-1,"building":1,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_60","name":"매장 상자","cell":[73,25],"level":0,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_61","name":"뒤 창고 상자","cell":[83,25],"level":0,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_62","name":"작업실 상자","cell":[93,25],"level":0,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_63","name":"매장 상자","cell":[73,34],"level":0,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_64","name":"뒤 창고 상자","cell":[83,34],"level":0,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_65","name":"작업실 상자","cell":[93,34],"level":0,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_66","name":"매장 상자","cell":[75,25],"level":1,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_67","name":"뒤 창고 상자","cell":[85,25],"level":1,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_68","name":"작업실 상자","cell":[94,25],"level":1,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_69","name":"매장 상자","cell":[75,34],"level":1,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_70","name":"뒤 창고 상자","cell":[85,34],"level":1,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_71","name":"작업실 상자","cell":[94,34],"level":1,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_72","name":"매장 상자","cell":[75,25],"level":2,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_73","name":"뒤 창고 상자","cell":[85,25],"level":2,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_74","name":"작업실 상자","cell":[94,25],"level":2,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_75","name":"매장 상자","cell":[75,34],"level":2,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_76","name":"뒤 창고 상자","cell":[85,34],"level":2,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_77","name":"작업실 상자","cell":[94,34],"level":2,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_78","name":"매장 상자","cell":[11,45],"level":0,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_79","name":"뒤 창고 상자","cell":[21,45],"level":0,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_80","name":"작업실 상자","cell":[28,45],"level":0,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_81","name":"매장 상자","cell":[11,54],"level":0,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_82","name":"뒤 창고 상자","cell":[21,54],"level":0,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_83","name":"작업실 상자","cell":[29,54],"level":0,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_84","name":"매장 상자","cell":[11,45],"level":1,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_85","name":"뒤 창고 상자","cell":[21,45],"level":1,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_86","name":"작업실 상자","cell":[30,45],"level":1,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_87","name":"매장 상자","cell":[11,54],"level":1,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_88","name":"뒤 창고 상자","cell":[21,54],"level":1,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_89","name":"작업실 상자","cell":[30,54],"level":1,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_90","name":"매장 상자","cell":[11,45],"level":2,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_91","name":"뒤 창고 상자","cell":[21,45],"level":2,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_92","name":"작업실 상자","cell":[30,45],"level":2,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_93","name":"매장 상자","cell":[11,54],"level":2,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_94","name":"뒤 창고 상자","cell":[21,54],"level":2,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_95","name":"작업실 상자","cell":[30,54],"level":2,"building":3,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_96","name":"매장 상자","cell":[143,25],"level":0,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_97","name":"뒤 창고 상자","cell":[153,25],"level":0,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_98","name":"작업실 상자","cell":[164,25],"level":0,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_99","name":"매장 상자","cell":[143,34],"level":0,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_100","name":"뒤 창고 상자","cell":[153,34],"level":0,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_101","name":"작업실 상자","cell":[164,34],"level":0,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_102","name":"매장 상자","cell":[145,25],"level":1,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_103","name":"뒤 창고 상자","cell":[155,25],"level":1,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_104","name":"작업실 상자","cell":[164,25],"level":1,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_105","name":"매장 상자","cell":[145,34],"level":1,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_106","name":"뒤 창고 상자","cell":[155,34],"level":1,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_107","name":"작업실 상자","cell":[164,34],"level":1,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_108","name":"매장 상자","cell":[145,25],"level":2,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_109","name":"뒤 창고 상자","cell":[155,25],"level":2,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_110","name":"작업실 상자","cell":[164,25],"level":2,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_111","name":"매장 상자","cell":[145,34],"level":2,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_112","name":"뒤 창고 상자","cell":[155,34],"level":2,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_113","name":"작업실 상자","cell":[164,34],"level":2,"building":4,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_114","name":"매장 상자","cell":[138,59],"level":0,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_115","name":"뒤 창고 상자","cell":[150,58],"level":0,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_116","name":"작업실 상자","cell":[158,59],"level":0,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_117","name":"매장 상자","cell":[166,58],"level":0,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_118","name":"매장 상자","cell":[139,68],"level":0,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_119","name":"뒤 창고 상자","cell":[150,67],"level":0,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_120","name":"작업실 상자","cell":[158,67],"level":0,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_121","name":"매장 상자","cell":[166,67],"level":0,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_122","name":"매장 상자","cell":[140,59],"level":1,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_123","name":"뒤 창고 상자","cell":[148,59],"level":1,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_124","name":"작업실 상자","cell":[156,59],"level":1,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_125","name":"매장 상자","cell":[164,59],"level":1,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_126","name":"매장 상자","cell":[140,68],"level":1,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_127","name":"뒤 창고 상자","cell":[148,68],"level":1,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_128","name":"작업실 상자","cell":[156,68],"level":1,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_129","name":"매장 상자","cell":[164,68],"level":1,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_130","name":"매장 상자","cell":[140,59],"level":2,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_131","name":"뒤 창고 상자","cell":[148,59],"level":2,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_132","name":"작업실 상자","cell":[156,59],"level":2,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_133","name":"매장 상자","cell":[164,59],"level":2,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_134","name":"매장 상자","cell":[140,68],"level":2,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_135","name":"뒤 창고 상자","cell":[148,68],"level":2,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_136","name":"작업실 상자","cell":[156,68],"level":2,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_137","name":"매장 상자","cell":[164,68],"level":2,"building":5,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_138","name":"매장 상자","cell":[10,83],"level":0,"building":6,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_139","name":"뒤 창고 상자","cell":[18,83],"level":0,"building":6,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_140","name":"매장 상자","cell":[10,90],"level":0,"building":6,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_141","name":"뒤 창고 상자","cell":[18,90],"level":0,"building":6,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_142","name":"매장 상자","cell":[12,83],"level":1,"building":6,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_143","name":"뒤 창고 상자","cell":[21,83],"level":1,"building":6,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_144","name":"매장 상자","cell":[12,90],"level":1,"building":6,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_145","name":"뒤 창고 상자","cell":[21,90],"level":1,"building":6,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_146","name":"매장 상자","cell":[151,88],"level":0,"building":7,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_147","name":"뒤 창고 상자","cell":[162,88],"level":0,"building":7,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_148","name":"매장 상자","cell":[151,96],"level":0,"building":7,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_149","name":"뒤 창고 상자","cell":[162,96],"level":0,"building":7,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_150","name":"저장 칸 상자","cell":[151,88],"level":-1,"building":7,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_151","name":"저장 칸 상자","cell":[162,88],"level":-1,"building":7,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_152","name":"저장 칸 상자","cell":[151,96],"level":-1,"building":7,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_153","name":"먼 끝 저장 상자","cell":[162,96],"level":-1,"building":7,"search":4,"items":["food_pack","food_pack","food_pack","food_pack"],"locked":true,"searched":false},
		{"id":"cache_154","name":"매장 상자","cell":[113,17],"level":0,"building":8,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_155","name":"뒤 창고 상자","cell":[124,17],"level":0,"building":8,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_156","name":"매장 상자","cell":[113,26],"level":0,"building":8,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_157","name":"뒤 창고 상자","cell":[124,26],"level":0,"building":8,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_158","name":"작업실 상자","cell":[93,68],"level":0,"building":9,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_159","name":"작업실 상자","cell":[104,60],"level":0,"building":10,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_160","name":"작업실 상자","cell":[89,88],"level":0,"building":11,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_161","name":"뒤 창고 상자","cell":[96,88],"level":0,"building":11,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_162","name":"매장 상자","cell":[3,30],"level":0,"building":12,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_163","name":"매장 상자","cell":[10,30],"level":0,"building":12,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_164","name":"작업실 상자","cell":[45,94],"level":0,"building":13,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_165","name":"뒤 창고 상자","cell":[52,94],"level":0,"building":13,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_166","name":"작업실 상자","cell":[73,93],"level":0,"building":14,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_167","name":"뒤 창고 상자","cell":[80,93],"level":0,"building":14,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_168","name":"작업실 상자","cell":[127,80],"level":0,"building":15,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_169","name":"판매장 상자","cell":[67,73],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_170","name":"뒤 창고 상자","cell":[80,65],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_171","name":"뒷문 홀 상자","cell":[81,70],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_172","name":"사무 방 상자","cell":[73,78],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_173","name":"냉동 칸 상자","cell":[81,78],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_174","name":"서쪽 계단실 상자","cell":[47,78],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_175","name":"저장 칸 상자","cell":[57,78],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"cache_176","name":"동쪽 계단실 상자","cell":[66,78],"level":0,"building":0,"search":4,"items":["food_pack"],"locked":false,"searched":false},
		{"id":"entry_cache","name":"현관 상자","cell":[67,28],"level":0,"building":2,"search":4,"items":["food_pack"],"locked":false,"searched":false}],
	"spots": [{"id":"salvage_0","kind":"salvage","name":"포장 나무","cell":[26,25],"material":"wood","amount":2,"state":"intact"},
		{"id":"salvage_1","kind":"salvage","name":"포장 나무","cell":[36,25],"material":"wood","amount":2,"state":"intact"}],
	"slots": ["D","G"],
	"dead": [[0,60],[30,104],[174,44],[114,104],[174,80],[84,50],[30,62],[112,66],[118,88]],
	"forecourts": [{"cell":[18,27],"normal":[-1,0],"cells":[[17,29],[17,28],[17,27],[17,26],[17,25],[16,29],[16,28],[16,27],[16,26],[16,25],[15,29],[15,28],[15,27],[15,26],[15,25],[14,29],[14,28],[14,27],[14,26],[14,25]],"building":1},
		{"cell":[49,27],"normal":[1,0],"cells":[[50,25],[50,26],[50,27],[50,28],[50,29],[51,25],[51,26],[51,27],[51,28],[51,29],[52,25],[52,26],[52,27],[52,28],[52,29],[53,25],[53,26],[53,27],[53,28],[53,29]],"building":1},
		{"cell":[66,27],"normal":[-1,0],"cells":[[65,29],[65,28],[65,27],[65,26],[65,25],[64,29],[64,28],[64,27],[64,26],[64,25],[63,29],[63,28],[63,27],[63,26],[63,25],[62,29],[62,28],[62,27],[62,26],[62,25]],"building":2},
		{"cell":[97,27],"normal":[1,0],"cells":[[98,25],[98,26],[98,27],[98,28],[98,29],[99,25],[99,26],[99,27],[99,28],[99,29],[100,25],[100,26],[100,27],[100,28],[100,29],[101,25],[101,26],[101,27],[101,28],[101,29]],"building":2},
		{"cell":[4,47],"normal":[-1,0],"cells":[[3,49],[3,48],[3,47],[3,46],[3,45],[2,49],[2,48],[2,47],[2,46],[2,45],[1,49],[1,48],[1,47],[1,46],[1,45],[0,49],[0,48],[0,47],[0,46],[0,45]],"building":3},
		{"cell":[33,47],"normal":[1,0],"cells":[[34,45],[34,46],[34,47],[34,48],[34,49],[35,45],[35,46],[35,47],[35,48],[35,49],[36,45],[36,46],[36,47],[36,48],[36,49],[37,45],[37,46],[37,47],[37,48],[37,49]],"building":3},
		{"cell":[136,27],"normal":[-1,0],"cells":[[135,29],[135,28],[135,27],[135,26],[135,25],[134,29],[134,28],[134,27],[134,26],[134,25],[133,29],[133,28],[133,27],[133,26],[133,25],[132,29],[132,28],[132,27],[132,26],[132,25]],"building":4},
		{"cell":[167,27],"normal":[1,0],"cells":[[168,25],[168,26],[168,27],[168,28],[168,29],[169,25],[169,26],[169,27],[169,28],[169,29],[170,25],[170,26],[170,27],[170,28],[170,29],[171,25],[171,26],[171,27],[171,28],[171,29]],"building":4},
		{"cell":[134,61],"normal":[-1,0],"cells":[[133,63],[133,62],[133,61],[133,60],[133,59],[132,63],[132,62],[132,61],[132,60],[132,59],[131,63],[131,62],[131,61],[131,60],[131,59],[130,63],[130,62],[130,61],[130,60],[130,59]],"building":5},
		{"cell":[167,61],"normal":[1,0],"cells":[[168,59],[168,60],[168,61],[168,62],[168,63],[169,59],[169,60],[169,61],[169,62],[169,63],[170,59],[170,60],[170,61],[170,62],[170,63],[171,59],[171,60],[171,61],[171,62],[171,63]],"building":5},
		{"cell":[4,85],"normal":[-1,0],"cells":[[3,87],[3,86],[3,85],[3,84],[3,83],[2,87],[2,86],[2,85],[2,84],[2,83],[1,87],[1,86],[1,85],[1,84],[1,83],[0,87],[0,86],[0,85],[0,84],[0,83]],"building":6},
		{"cell":[23,85],"normal":[1,0],"cells":[[24,83],[24,84],[24,85],[24,86],[24,87],[25,83],[25,84],[25,85],[25,86],[25,87],[26,83],[26,84],[26,85],[26,86],[26,87],[27,83],[27,84],[27,85],[27,86],[27,87]],"building":6},
		{"cell":[142,90],"normal":[-1,0],"cells":[[141,92],[141,91],[141,90],[141,89],[141,88],[140,92],[140,91],[140,90],[140,89],[140,88],[139,92],[139,91],[139,90],[139,89],[139,88],[138,92],[138,91],[138,90],[138,89],[138,88]],"building":7},
		{"cell":[165,90],"normal":[1,0],"cells":[[166,88],[166,89],[166,90],[166,91],[166,92],[167,88],[167,89],[167,90],[167,91],[167,92],[168,88],[168,89],[168,90],[168,91],[168,92],[169,88],[169,89],[169,90],[169,91],[169,92]],"building":7},
		{"cell":[104,19],"normal":[-1,0],"cells":[[103,21],[103,20],[103,19],[103,18],[103,17],[102,21],[102,20],[102,19],[102,18],[102,17],[101,21],[101,20],[101,19],[101,18],[101,17],[100,21],[100,20],[100,19],[100,18],[100,17]],"building":8},
		{"cell":[127,19],"normal":[1,0],"cells":[[128,17],[128,18],[128,19],[128,20],[128,21],[129,17],[129,18],[129,19],[129,20],[129,21],[130,17],[130,18],[130,19],[130,20],[130,21],[131,17],[131,18],[131,19],[131,20],[131,21]],"building":8},
		{"cell":[88,66],"normal":[-1,0],"cells":[[87,68],[87,67],[87,66],[87,65],[87,64],[86,68],[86,67],[86,66],[86,65],[86,64],[85,68],[85,67],[85,66],[85,65],[85,64],[84,68],[84,67],[84,66],[84,65],[84,64]],"building":9},
		{"cell":[97,66],"normal":[1,0],"cells":[[98,64],[98,65],[98,66],[98,67],[98,68],[99,64],[99,65],[99,66],[99,67],[99,68],[100,64],[100,65],[100,66],[100,67],[100,68],[101,64],[101,65],[101,66],[101,67],[101,68]],"building":9},
		{"cell":[100,58],"normal":[-1,0],"cells":[[99,60],[99,59],[99,58],[99,57],[99,56],[98,60],[98,59],[98,58],[98,57],[98,56],[97,60],[97,59],[97,58],[97,57],[97,56],[96,60],[96,59],[96,58],[96,57],[96,56]],"building":10},
		{"cell":[107,58],"normal":[1,0],"cells":[[108,56],[108,57],[108,58],[108,59],[108,60],[109,56],[109,57],[109,58],[109,59],[109,60],[110,56],[110,57],[110,58],[110,59],[110,60],[111,56],[111,57],[111,58],[111,59],[111,60]],"building":10},
		{"cell":[86,86],"normal":[-1,0],"cells":[[85,88],[85,87],[85,86],[85,85],[85,84],[84,88],[84,87],[84,86],[84,85],[84,84],[83,88],[83,87],[83,86],[83,85],[83,84],[82,88],[82,87],[82,86],[82,85],[82,84]],"building":11},
		{"cell":[99,86],"normal":[1,0],"cells":[[100,84],[100,85],[100,86],[100,87],[100,88],[101,84],[101,85],[101,86],[101,87],[101,88],[102,84],[102,85],[102,86],[102,87],[102,88],[103,84],[103,85],[103,86],[103,87],[103,88]],"building":11},
		{"cell":[7,24],"normal":[0,-1],"cells":[[5,23],[6,23],[7,23],[8,23],[9,23],[5,22],[6,22],[7,22],[8,22],[9,22],[5,21],[6,21],[7,21],[8,21],[9,21],[5,20],[6,20],[7,20],[8,20],[9,20]],"building":12},
		{"cell":[7,31],"normal":[0,1],"cells":[[9,32],[8,32],[7,32],[6,32],[5,32],[9,33],[8,33],[7,33],[6,33],[5,33],[9,34],[8,34],[7,34],[6,34],[5,34],[9,35],[8,35],[7,35],[6,35],[5,35]],"building":12},
		{"cell":[42,91],"normal":[-1,0],"cells":[[41,93],[41,92],[41,91],[41,90],[41,89],[40,93],[40,92],[40,91],[40,90],[40,89],[39,93],[39,92],[39,91],[39,90],[39,89],[38,93],[38,92],[38,91],[38,90],[38,89]],"building":13},
		{"cell":[55,91],"normal":[1,0],"cells":[[56,89],[56,90],[56,91],[56,92],[56,93],[57,89],[57,90],[57,91],[57,92],[57,93],[58,89],[58,90],[58,91],[58,92],[58,93],[59,89],[59,90],[59,91],[59,92],[59,93]],"building":13},
		{"cell":[70,92],"normal":[-1,0],"cells":[[69,94],[69,93],[69,92],[69,91],[69,90],[68,94],[68,93],[68,92],[68,91],[68,90],[67,94],[67,93],[67,92],[67,91],[67,90],[66,94],[66,93],[66,92],[66,91],[66,90]],"building":14},
		{"cell":[81,92],"normal":[1,0],"cells":[[82,90],[82,91],[82,92],[82,93],[82,94],[83,90],[83,91],[83,92],[83,93],[83,94],[84,90],[84,91],[84,92],[84,93],[84,94],[85,90],[85,91],[85,92],[85,93],[85,94]],"building":14},
		{"cell":[122,78],"normal":[-1,0],"cells":[[121,80],[121,79],[121,78],[121,77],[121,76],[120,80],[120,79],[120,78],[120,77],[120,76],[119,80],[119,79],[119,78],[119,77],[119,76],[118,80],[118,79],[118,78],[118,77],[118,76]],"building":15},
		{"cell":[131,78],"normal":[1,0],"cells":[[132,76],[132,77],[132,78],[132,79],[132,80],[133,76],[133,77],[133,78],[133,79],[133,80],[134,76],[134,77],[134,78],[134,79],[134,80],[135,76],[135,77],[135,78],[135,79],[135,80]],"building":15},
		{"cell":[62,58],"normal":[0,-1],"cells":[[60,57],[61,57],[62,57],[63,57],[64,57],[60,56],[61,56],[62,56],[63,56],[64,56],[60,55],[61,55],[62,55],[63,55],[64,55],[60,54],[61,54],[62,54],[63,54],[64,54]],"building":0},
		{"cell":[83,67],"normal":[1,0],"cells":[[84,65],[84,66],[84,67],[84,68],[84,69],[85,65],[85,66],[85,67],[85,68],[85,69],[86,65],[86,66],[86,67],[86,68],[86,69],[87,65],[87,66],[87,67],[87,68],[87,69]],"building":0},
		{"cell":[45,79],"normal":[0,1],"cells":[[47,80],[46,80],[45,80],[44,80],[43,80],[47,81],[46,81],[45,81],[44,81],[43,81],[47,82],[46,82],[45,82],[44,82],[43,82],[47,83],[46,83],[45,83],[44,83],[43,83]],"building":0},
		{"cell":[64,79],"normal":[0,1],"cells":[[66,80],[65,80],[64,80],[63,80],[62,80],[66,81],[65,81],[64,81],[63,81],[62,81],[66,82],[65,82],[64,82],[63,82],[62,82],[66,83],[65,83],[64,83],[63,83],[62,83]],"building":0}],
	"logs": ["snow_drifts_0"],
	"deep": [{"cell":[46,78],"level":-1,"id":"cache_30","distance":145},
		{"cell":[162,96],"level":-1,"id":"cache_153","distance":173}]
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
	"number": 4,
	"width": 175,
	"height": 46,
	"judgment": "기름과 석탄을 많이 얻는 대신, 쇠통을 끌고 골목 그물을 지나는 소리가 커서 무리를 불러들이고 아래쪽 가게 한 동을 놓친다.",
	"zones": [
		{
			"id": "I",
			"name": "서쪽 살림 구역",
			"rect": [
				0,
				0,
				36,
				46
			]
		},
		{
			"id": "J",
			"name": "연료 구역",
			"rect": [
				36,
				0,
				61,
				46
			]
		},
		{
			"id": "K",
			"name": "동쪽 광장",
			"rect": [
				97,
				0,
				78,
				46
			]
		}
	],
	"grounds": [
		{
			"rect": [
				0,
				8,
				101,
				4
			],
			"floor": 1
		},
		{
			"rect": [
				97,
				8,
				4,
				10
			],
			"floor": 1
		},
		{
			"rect": [
				97,
				14,
				78,
				4
			],
			"floor": 1
		},
		{
			"rect": [
				30,
				0,
				6,
				43
			],
			"floor": 1
		},
		{
			"rect": [
				78,
				0,
				5,
				43
			],
			"floor": 1
		},
		{
			"rect": [
				146,
				4,
				4,
				14
			],
			"floor": 1
		},
		{
			"rect": [
				149,
				8,
				23,
				4
			],
			"floor": 7
		},
		{
			"rect": [
				97,
				18,
				19,
				25
			],
			"floor": 7
		},
		{
			"rect": [
				140,
				24,
				30,
				16
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
			"name": "연료 도매 창고",
			"rect": [
				36,
				12,
				34,
				12
			],
			"top": 2,
			"basement": true,
			"role": "store",
			"stock": [
				"fuel_drum_stack",
				"coal_heap",
				"sack_pile",
				"barrel"
			]
		},
		{
			"id": 17,
			"name": "석탄 헛간",
			"rect": [
				70,
				12,
				8,
				12
			],
			"top": 1,
			"basement": false,
			"role": "store",
			"stock": [
				"coal_heap",
				"sack_pile",
				"barrel"
			]
		},
		{
			"id": 18,
			"name": "살림집",
			"rect": [
				6,
				13,
				16,
				11
			],
			"top": 3,
			"basement": true,
			"role": "home",
			"stock": [
				"fuel_drum_stack",
				"coal_heap",
				"sack_pile",
				"barrel"
			]
		},
		{
			"id": 19,
			"name": "차고",
			"rect": [
				22,
				15,
				8,
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
			"id": 20,
			"name": "기름 가게",
			"rect": [
				83,
				13,
				14,
				11
			],
			"top": 2,
			"basement": false,
			"role": "shop",
			"stock": [
				"fuel_drum_stack",
				"shelf",
				"barrel"
			]
		},
		{
			"id": 21,
			"name": "온수 설비동",
			"rect": [
				36,
				1,
				12,
				7
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
			"id": 22,
			"name": "가게 겸 집",
			"rect": [
				50,
				0,
				18,
				8
			],
			"top": 2,
			"basement": false,
			"role": "shop",
			"stock": [
				"fuel_drum_stack",
				"shelf",
				"desk"
			]
		},
		{
			"id": 23,
			"name": "연립 집",
			"rect": [
				118,
				2,
				22,
				12
			],
			"top": 3,
			"basement": false,
			"role": "home",
			"stock": [
				"fuel_drum_stack",
				"coal_heap",
				"sack_pile",
				"barrel"
			]
		},
		{
			"id": 24,
			"name": "석탄 광",
			"rect": [
				156,
				0,
				16,
				8
			],
			"top": 1,
			"basement": true,
			"role": "store",
			"stock": [
				"coal_heap",
				"fuel_drum_stack",
				"sack_pile"
			]
		}
	],
	"shells": [
		{
			"rect": [
				36,
				12,
				34,
				12
			],
			"building": 16,
			"level": -1
		},
		{
			"rect": [
				36,
				12,
				34,
				12
			],
			"building": 16,
			"level": 0
		},
		{
			"rect": [
				36,
				12,
				34,
				12
			],
			"building": 16,
			"level": 1
		},
		{
			"rect": [
				70,
				12,
				8,
				12
			],
			"building": 17,
			"level": 0
		},
		{
			"rect": [
				6,
				13,
				16,
				11
			],
			"building": 18,
			"level": -1
		},
		{
			"rect": [
				6,
				13,
				16,
				11
			],
			"building": 18,
			"level": 0
		},
		{
			"rect": [
				6,
				13,
				16,
				11
			],
			"building": 18,
			"level": 1
		},
		{
			"rect": [
				6,
				13,
				16,
				11
			],
			"building": 18,
			"level": 2
		},
		{
			"rect": [
				22,
				15,
				8,
				9
			],
			"building": 19,
			"level": 0
		},
		{
			"rect": [
				83,
				13,
				14,
				11
			],
			"building": 20,
			"level": 0
		},
		{
			"rect": [
				83,
				13,
				14,
				11
			],
			"building": 20,
			"level": 1
		},
		{
			"rect": [
				36,
				1,
				12,
				7
			],
			"building": 21,
			"level": 0
		},
		{
			"rect": [
				50,
				0,
				18,
				8
			],
			"building": 22,
			"level": 0
		},
		{
			"rect": [
				50,
				0,
				18,
				8
			],
			"building": 22,
			"level": 1
		},
		{
			"rect": [
				118,
				2,
				22,
				12
			],
			"building": 23,
			"level": 0
		},
		{
			"rect": [
				118,
				2,
				22,
				12
			],
			"building": 23,
			"level": 1
		},
		{
			"rect": [
				118,
				2,
				22,
				12
			],
			"building": 23,
			"level": 2
		},
		{
			"rect": [
				156,
				0,
				16,
				8
			],
			"building": 24,
			"level": -1
		},
		{
			"rect": [
				156,
				0,
				16,
				8
			],
			"building": 24,
			"level": 0
		}
	],
	"walls": [
		{
			"rect": [
				37,
				20,
				32,
				1
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
				48,
				13,
				1,
				7
			],
			"level": -1
		},
		{
			"rect": [
				54,
				13,
				1,
				7
			],
			"level": -1
		},
		{
			"rect": [
				59,
				13,
				1,
				7
			],
			"level": -1
		},
		{
			"rect": [
				64,
				13,
				1,
				7
			],
			"level": -1
		},
		{
			"rect": [
				37,
				20,
				32,
				1
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
				48,
				13,
				1,
				7
			],
			"level": 0
		},
		{
			"rect": [
				54,
				13,
				1,
				7
			],
			"level": 0
		},
		{
			"rect": [
				59,
				13,
				1,
				7
			],
			"level": 0
		},
		{
			"rect": [
				64,
				13,
				1,
				7
			],
			"level": 0
		},
		{
			"rect": [
				37,
				20,
				32,
				1
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
				48,
				13,
				1,
				7
			],
			"level": 1
		},
		{
			"rect": [
				54,
				13,
				1,
				7
			],
			"level": 1
		},
		{
			"rect": [
				59,
				13,
				1,
				7
			],
			"level": 1
		},
		{
			"rect": [
				64,
				13,
				1,
				7
			],
			"level": 1
		},
		{
			"rect": [
				7,
				20,
				14,
				1
			],
			"level": -1
		},
		{
			"rect": [
				14,
				14,
				1,
				6
			],
			"level": -1
		},
		{
			"rect": [
				7,
				20,
				14,
				1
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
				7,
				20,
				14,
				1
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
				7,
				20,
				14,
				1
			],
			"level": 2
		},
		{
			"rect": [
				14,
				14,
				1,
				6
			],
			"level": 2
		},
		{
			"rect": [
				84,
				18,
				12,
				1
			],
			"level": 0
		},
		{
			"rect": [
				84,
				18,
				12,
				1
			],
			"level": 1
		},
		{
			"rect": [
				42,
				2,
				1,
				5
			],
			"level": 0
		},
		{
			"rect": [
				59,
				1,
				1,
				6
			],
			"level": 0
		},
		{
			"rect": [
				59,
				1,
				1,
				6
			],
			"level": 1
		},
		{
			"rect": [
				119,
				10,
				20,
				1
			],
			"level": 0
		},
		{
			"rect": [
				125,
				3,
				1,
				7
			],
			"level": 0
		},
		{
			"rect": [
				132,
				3,
				1,
				7
			],
			"level": 0
		},
		{
			"rect": [
				119,
				10,
				20,
				1
			],
			"level": 1
		},
		{
			"rect": [
				125,
				3,
				1,
				7
			],
			"level": 1
		},
		{
			"rect": [
				132,
				3,
				1,
				7
			],
			"level": 1
		},
		{
			"rect": [
				119,
				10,
				20,
				1
			],
			"level": 2
		},
		{
			"rect": [
				125,
				3,
				1,
				7
			],
			"level": 2
		},
		{
			"rect": [
				132,
				3,
				1,
				7
			],
			"level": 2
		},
		{
			"rect": [
				157,
				4,
				14,
				1
			],
			"level": -1
		},
		{
			"rect": [
				164,
				1,
				1,
				3
			],
			"level": -1
		},
		{
			"rect": [
				157,
				4,
				14,
				1
			],
			"level": 0
		},
		{
			"rect": [
				164,
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
				39,
				20
			],
			"level": -1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				45,
				20
			],
			"level": -1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				51,
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
				62,
				20
			],
			"level": -1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				67,
				20
			],
			"level": -1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				39,
				20
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				45,
				20
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				51,
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
				62,
				20
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				67,
				20
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				53,
				23
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				39,
				20
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				45,
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
				62,
				20
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				67,
				20
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				74,
				23
			],
			"level": 0,
			"building": 17,
			"state": "closed"
		},
		{
			"cell": [
				10,
				20
			],
			"level": -1,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				18,
				20
			],
			"level": -1,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				10,
				20
			],
			"level": 0,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				18,
				20
			],
			"level": 0,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				14,
				23
			],
			"level": 0,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				10,
				20
			],
			"level": 1,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				18,
				20
			],
			"level": 1,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				10,
				20
			],
			"level": 2,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				18,
				20
			],
			"level": 2,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				26,
				23
			],
			"level": 0,
			"building": 19,
			"state": "closed"
		},
		{
			"cell": [
				90,
				18
			],
			"level": 0,
			"building": 20,
			"state": "closed"
		},
		{
			"cell": [
				90,
				23
			],
			"level": 0,
			"building": 20,
			"state": "closed"
		},
		{
			"cell": [
				90,
				13
			],
			"level": 0,
			"building": 20,
			"state": "closed"
		},
		{
			"cell": [
				90,
				18
			],
			"level": 1,
			"building": 20,
			"state": "closed"
		},
		{
			"cell": [
				42,
				4
			],
			"level": 0,
			"building": 21,
			"state": "closed"
		},
		{
			"cell": [
				38,
				7
			],
			"level": 0,
			"building": 21,
			"state": "closed"
		},
		{
			"cell": [
				59,
				4
			],
			"level": 0,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				65,
				7
			],
			"level": 0,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				52,
				0
			],
			"level": 0,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				59,
				4
			],
			"level": 1,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				122,
				10
			],
			"level": 0,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				129,
				10
			],
			"level": 0,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				136,
				10
			],
			"level": 0,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				129,
				13
			],
			"level": 0,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				122,
				10
			],
			"level": 1,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				129,
				10
			],
			"level": 1,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				136,
				10
			],
			"level": 1,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				122,
				10
			],
			"level": 2,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				129,
				10
			],
			"level": 2,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				136,
				10
			],
			"level": 2,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				160,
				4
			],
			"level": -1,
			"building": 24,
			"state": "closed"
		},
		{
			"cell": [
				168,
				4
			],
			"level": -1,
			"building": 24,
			"state": "closed"
		},
		{
			"cell": [
				160,
				4
			],
			"level": 0,
			"building": 24,
			"state": "closed"
		},
		{
			"cell": [
				168,
				4
			],
			"level": 0,
			"building": 24,
			"state": "closed"
		},
		{
			"cell": [
				164,
				7
			],
			"level": 0,
			"building": 24,
			"state": "closed"
		},
		{
			"cell": [
				39,
				12
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		}
	],
	"windows": [
		{
			"cell": [
				45,
				12
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				51,
				12
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				57,
				12
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				62,
				12
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				67,
				12
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				74,
				12
			],
			"level": 0,
			"building": 17
		},
		{
			"cell": [
				10,
				13
			],
			"level": 0,
			"building": 18
		},
		{
			"cell": [
				18,
				13
			],
			"level": 0,
			"building": 18
		},
		{
			"cell": [
				26,
				15
			],
			"level": 0,
			"building": 19
		},
		{
			"cell": [
				39,
				1
			],
			"level": 0,
			"building": 21
		},
		{
			"cell": [
				45,
				1
			],
			"level": 0,
			"building": 21
		},
		{
			"cell": [
				55,
				0
			],
			"level": 0,
			"building": 22
		},
		{
			"cell": [
				63,
				0
			],
			"level": 0,
			"building": 22
		},
		{
			"cell": [
				122,
				2
			],
			"level": 0,
			"building": 23
		},
		{
			"cell": [
				129,
				2
			],
			"level": 0,
			"building": 23
		},
		{
			"cell": [
				136,
				2
			],
			"level": 0,
			"building": 23
		},
		{
			"cell": [
				160,
				0
			],
			"level": 0,
			"building": 24
		},
		{
			"cell": [
				168,
				0
			],
			"level": 0,
			"building": 24
		}
	],
	"stairs": [
		{
			"cell": [
				38,
				21
			],
			"low": -1,
			"high": 0
		},
		{
			"cell": [
				38,
				21
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				67,
				21
			],
			"low": -1,
			"high": 0
		},
		{
			"cell": [
				67,
				21
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				8,
				21
			],
			"low": -1,
			"high": 0
		},
		{
			"cell": [
				8,
				21
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				8,
				21
			],
			"low": 1,
			"high": 2
		},
		{
			"cell": [
				19,
				21
			],
			"low": -1,
			"high": 0
		},
		{
			"cell": [
				19,
				21
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				19,
				21
			],
			"low": 1,
			"high": 2
		},
		{
			"cell": [
				94,
				15
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				65,
				2
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				120,
				11
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				120,
				11
			],
			"low": 1,
			"high": 2
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
				137,
				11
			],
			"low": 1,
			"high": 2
		},
		{
			"cell": [
				158,
				5
			],
			"low": -1,
			"high": 0
		}
	],
	"rooms": [
		{
			"rect": [
				37,
				13,
				5,
				7
			],
			"building": 16,
			"level": -1,
			"use": "입고 방"
		},
		{
			"rect": [
				43,
				13,
				5,
				7
			],
			"building": 16,
			"level": -1,
			"use": "비축 방"
		},
		{
			"rect": [
				49,
				13,
				5,
				7
			],
			"building": 16,
			"level": -1,
			"use": "작업 방"
		},
		{
			"rect": [
				55,
				13,
				4,
				7
			],
			"building": 16,
			"level": -1,
			"use": "접수 방"
		},
		{
			"rect": [
				60,
				13,
				4,
				7
			],
			"building": 16,
			"level": -1,
			"use": "보관 방"
		},
		{
			"rect": [
				65,
				13,
				4,
				7
			],
			"building": 16,
			"level": -1,
			"use": "안쪽 광"
		},
		{
			"rect": [
				37,
				13,
				5,
				7
			],
			"building": 16,
			"level": 0,
			"use": "입고 방"
		},
		{
			"rect": [
				43,
				13,
				5,
				7
			],
			"building": 16,
			"level": 0,
			"use": "비축 방"
		},
		{
			"rect": [
				49,
				13,
				5,
				7
			],
			"building": 16,
			"level": 0,
			"use": "작업 방"
		},
		{
			"rect": [
				55,
				13,
				4,
				7
			],
			"building": 16,
			"level": 0,
			"use": "접수 방"
		},
		{
			"rect": [
				60,
				13,
				4,
				7
			],
			"building": 16,
			"level": 0,
			"use": "보관 방"
		},
		{
			"rect": [
				65,
				13,
				4,
				7
			],
			"building": 16,
			"level": 0,
			"use": "안쪽 광"
		},
		{
			"rect": [
				37,
				13,
				5,
				7
			],
			"building": 16,
			"level": 1,
			"use": "입고 방"
		},
		{
			"rect": [
				43,
				13,
				5,
				7
			],
			"building": 16,
			"level": 1,
			"use": "비축 방"
		},
		{
			"rect": [
				49,
				13,
				5,
				7
			],
			"building": 16,
			"level": 1,
			"use": "작업 방"
		},
		{
			"rect": [
				55,
				13,
				4,
				7
			],
			"building": 16,
			"level": 1,
			"use": "접수 방"
		},
		{
			"rect": [
				60,
				13,
				4,
				7
			],
			"building": 16,
			"level": 1,
			"use": "보관 방"
		},
		{
			"rect": [
				65,
				13,
				4,
				7
			],
			"building": 16,
			"level": 1,
			"use": "안쪽 광"
		},
		{
			"rect": [
				71,
				13,
				6,
				10
			],
			"building": 17,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				7,
				14,
				7,
				6
			],
			"building": 18,
			"level": -1,
			"use": "살림방"
		},
		{
			"rect": [
				15,
				14,
				6,
				6
			],
			"building": 18,
			"level": -1,
			"use": "부엌"
		},
		{
			"rect": [
				7,
				14,
				7,
				6
			],
			"building": 18,
			"level": 0,
			"use": "살림방"
		},
		{
			"rect": [
				15,
				14,
				6,
				6
			],
			"building": 18,
			"level": 0,
			"use": "부엌"
		},
		{
			"rect": [
				7,
				14,
				7,
				6
			],
			"building": 18,
			"level": 1,
			"use": "살림방"
		},
		{
			"rect": [
				15,
				14,
				6,
				6
			],
			"building": 18,
			"level": 1,
			"use": "부엌"
		},
		{
			"rect": [
				7,
				14,
				7,
				6
			],
			"building": 18,
			"level": 2,
			"use": "살림방"
		},
		{
			"rect": [
				15,
				14,
				6,
				6
			],
			"building": 18,
			"level": 2,
			"use": "부엌"
		},
		{
			"rect": [
				23,
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
				84,
				14,
				12,
				4
			],
			"building": 20,
			"level": 0,
			"use": "뒤 창고"
		},
		{
			"rect": [
				84,
				19,
				12,
				4
			],
			"building": 20,
			"level": 0,
			"use": "매장"
		},
		{
			"rect": [
				84,
				14,
				12,
				4
			],
			"building": 20,
			"level": 1,
			"use": "뒤 창고"
		},
		{
			"rect": [
				84,
				19,
				12,
				4
			],
			"building": 20,
			"level": 1,
			"use": "매장"
		},
		{
			"rect": [
				37,
				2,
				5,
				5
			],
			"building": 21,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				43,
				2,
				4,
				5
			],
			"building": 21,
			"level": 0,
			"use": "보관 칸"
		},
		{
			"rect": [
				51,
				1,
				8,
				6
			],
			"building": 22,
			"level": 0,
			"use": "뒤 창고"
		},
		{
			"rect": [
				60,
				1,
				7,
				6
			],
			"building": 22,
			"level": 0,
			"use": "매장"
		},
		{
			"rect": [
				51,
				1,
				8,
				6
			],
			"building": 22,
			"level": 1,
			"use": "뒤 창고"
		},
		{
			"rect": [
				60,
				1,
				7,
				6
			],
			"building": 22,
			"level": 1,
			"use": "매장"
		},
		{
			"rect": [
				119,
				3,
				6,
				7
			],
			"building": 23,
			"level": 0,
			"use": "살림방"
		},
		{
			"rect": [
				126,
				3,
				6,
				7
			],
			"building": 23,
			"level": 0,
			"use": "부엌"
		},
		{
			"rect": [
				133,
				3,
				6,
				7
			],
			"building": 23,
			"level": 0,
			"use": "부엌"
		},
		{
			"rect": [
				119,
				3,
				6,
				7
			],
			"building": 23,
			"level": 1,
			"use": "살림방"
		},
		{
			"rect": [
				126,
				3,
				6,
				7
			],
			"building": 23,
			"level": 1,
			"use": "부엌"
		},
		{
			"rect": [
				133,
				3,
				6,
				7
			],
			"building": 23,
			"level": 1,
			"use": "부엌"
		},
		{
			"rect": [
				119,
				3,
				6,
				7
			],
			"building": 23,
			"level": 2,
			"use": "살림방"
		},
		{
			"rect": [
				126,
				3,
				6,
				7
			],
			"building": 23,
			"level": 2,
			"use": "부엌"
		},
		{
			"rect": [
				133,
				3,
				6,
				7
			],
			"building": 23,
			"level": 2,
			"use": "부엌"
		},
		{
			"rect": [
				157,
				1,
				7,
				3
			],
			"building": 24,
			"level": -1,
			"use": "작업 칸"
		},
		{
			"rect": [
				165,
				1,
				6,
				3
			],
			"building": 24,
			"level": -1,
			"use": "보관 칸"
		},
		{
			"rect": [
				157,
				1,
				7,
				3
			],
			"building": 24,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				165,
				1,
				6,
				3
			],
			"building": 24,
			"level": 0,
			"use": "보관 칸"
		}
	],
	"props": [
		{
			"kind": "fuel_drum_stack",
			"rect": [
				37,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 입고 방의 기름통 쌓음",
			"level": -1
		},
		{
			"kind": "coal_heap",
			"rect": [
				37,
				18,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 입고 방의 석탄 더미",
			"level": -1
		},
		{
			"kind": "sack_pile",
			"rect": [
				40,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 입고 방의 자루 더미",
			"level": -1
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				43,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 비축 방의 기름통 쌓음",
			"level": -1
		},
		{
			"kind": "coal_heap",
			"rect": [
				43,
				18,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 비축 방의 석탄 더미",
			"level": -1
		},
		{
			"kind": "sack_pile",
			"rect": [
				46,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 비축 방의 자루 더미",
			"level": -1
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				49,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 작업 방의 기름통 쌓음",
			"level": -1
		},
		{
			"kind": "coal_heap",
			"rect": [
				49,
				18,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 작업 방의 석탄 더미",
			"level": -1
		},
		{
			"kind": "sack_pile",
			"rect": [
				52,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 작업 방의 자루 더미",
			"level": -1
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				55,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 접수 방의 기름통 쌓음",
			"level": -1
		},
		{
			"kind": "coal_heap",
			"rect": [
				55,
				18,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 접수 방의 석탄 더미",
			"level": -1
		},
		{
			"kind": "sack_pile",
			"rect": [
				57,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 접수 방의 자루 더미",
			"level": -1
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				60,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 보관 방의 기름통 쌓음",
			"level": -1
		},
		{
			"kind": "coal_heap",
			"rect": [
				60,
				18,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 보관 방의 석탄 더미",
			"level": -1
		},
		{
			"kind": "sack_pile",
			"rect": [
				62,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 보관 방의 자루 더미",
			"level": -1
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				65,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 안쪽 광의 기름통 쌓음",
			"level": -1
		},
		{
			"kind": "coal_heap",
			"rect": [
				65,
				18,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 안쪽 광의 석탄 더미",
			"level": -1
		},
		{
			"kind": "sack_pile",
			"rect": [
				67,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 안쪽 광의 자루 더미",
			"level": -1
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				37,
				13,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 도매 창고 입고 방의 기름통 쌓음",
			"level": 0
		},
		{
			"kind": "sack_pile",
			"rect": [
				37,
				18,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 도매 창고 입고 방의 자루 더미",
			"level": 0
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				43,
				13,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 도매 창고 비축 방의 기름통 쌓음",
			"level": 0
		},
		{
			"kind": "coal_heap",
			"rect": [
				45,
				13,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 도매 창고 비축 방의 석탄 더미",
			"level": 0
		},
		{
			"kind": "sack_pile",
			"rect": [
				43,
				18,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 도매 창고 비축 방의 자루 더미",
			"level": 0
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				49,
				13,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 도매 창고 작업 방의 기름통 쌓음",
			"level": 0
		},
		{
			"kind": "coal_heap",
			"rect": [
				51,
				13,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 도매 창고 작업 방의 석탄 더미",
			"level": 0
		},
		{
			"kind": "sack_pile",
			"rect": [
				49,
				18,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 도매 창고 작업 방의 자루 더미",
			"level": 0
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				55,
				13,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 도매 창고 접수 방의 기름통 쌓음",
			"level": 0
		},
		{
			"kind": "coal_heap",
			"rect": [
				55,
				15,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 도매 창고 접수 방의 석탄 더미",
			"level": 0
		},
		{
			"kind": "sack_pile",
			"rect": [
				57,
				13,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 도매 창고 접수 방의 자루 더미",
			"level": 0
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				60,
				13,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 도매 창고 보관 방의 기름통 쌓음",
			"level": 0
		},
		{
			"kind": "coal_heap",
			"rect": [
				60,
				15,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 도매 창고 보관 방의 석탄 더미",
			"level": 0
		},
		{
			"kind": "sack_pile",
			"rect": [
				62,
				13,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 도매 창고 보관 방의 자루 더미",
			"level": 0
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				65,
				13,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 도매 창고 안쪽 광의 기름통 쌓음",
			"level": 0
		},
		{
			"kind": "coal_heap",
			"rect": [
				65,
				15,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 도매 창고 안쪽 광의 석탄 더미",
			"level": 0
		},
		{
			"kind": "sack_pile",
			"rect": [
				67,
				13,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 도매 창고 안쪽 광의 자루 더미",
			"level": 0
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				37,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 입고 방의 기름통 쌓음",
			"level": 1
		},
		{
			"kind": "coal_heap",
			"rect": [
				37,
				18,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 입고 방의 석탄 더미",
			"level": 1
		},
		{
			"kind": "sack_pile",
			"rect": [
				40,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 입고 방의 자루 더미",
			"level": 1
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				43,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 비축 방의 기름통 쌓음",
			"level": 1
		},
		{
			"kind": "coal_heap",
			"rect": [
				43,
				18,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 비축 방의 석탄 더미",
			"level": 1
		},
		{
			"kind": "sack_pile",
			"rect": [
				46,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 비축 방의 자루 더미",
			"level": 1
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				49,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 작업 방의 기름통 쌓음",
			"level": 1
		},
		{
			"kind": "coal_heap",
			"rect": [
				49,
				18,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 작업 방의 석탄 더미",
			"level": 1
		},
		{
			"kind": "sack_pile",
			"rect": [
				52,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 작업 방의 자루 더미",
			"level": 1
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				55,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 접수 방의 기름통 쌓음",
			"level": 1
		},
		{
			"kind": "coal_heap",
			"rect": [
				55,
				18,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 접수 방의 석탄 더미",
			"level": 1
		},
		{
			"kind": "sack_pile",
			"rect": [
				57,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 접수 방의 자루 더미",
			"level": 1
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				60,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 보관 방의 기름통 쌓음",
			"level": 1
		},
		{
			"kind": "coal_heap",
			"rect": [
				60,
				18,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 보관 방의 석탄 더미",
			"level": 1
		},
		{
			"kind": "sack_pile",
			"rect": [
				62,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 보관 방의 자루 더미",
			"level": 1
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				65,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 안쪽 광의 기름통 쌓음",
			"level": 1
		},
		{
			"kind": "coal_heap",
			"rect": [
				65,
				18,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 안쪽 광의 석탄 더미",
			"level": 1
		},
		{
			"kind": "sack_pile",
			"rect": [
				67,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연료 도매 창고 안쪽 광의 자루 더미",
			"level": 1
		},
		{
			"kind": "coal_heap",
			"rect": [
				71,
				13,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "석탄 헛간 작업 칸의 석탄 더미",
			"level": 0
		},
		{
			"kind": "sack_pile",
			"rect": [
				75,
				13,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "석탄 헛간 작업 칸의 자루 더미",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				76,
				22,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "석탄 헛간 작업 칸의 통",
			"level": 0
		},
		{
			"kind": "bed",
			"rect": [
				7,
				14,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "살림집 살림방의 침대",
			"level": -1
		},
		{
			"kind": "wardrobe",
			"rect": [
				7,
				19,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "살림집 살림방의 장롱",
			"level": -1
		},
		{
			"kind": "desk",
			"rect": [
				12,
				14,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "살림집 살림방의 책상",
			"level": -1
		},
		{
			"kind": "dining_set",
			"rect": [
				15,
				14,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "살림집 부엌의 식탁",
			"level": -1
		},
		{
			"kind": "fridge_open",
			"rect": [
				20,
				14,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "살림집 부엌의 냉장고",
			"level": -1
		},
		{
			"kind": "cold_stove",
			"rect": [
				15,
				19,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "살림집 부엌의 꺼진 난로",
			"level": -1
		},
		{
			"kind": "bed",
			"rect": [
				7,
				14,
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
				7,
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
				12,
				14,
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
				15,
				14,
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
				20,
				14,
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
				15,
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
				7,
				14,
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
				7,
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
				12,
				14,
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
				15,
				14,
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
				20,
				14,
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
				15,
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
			"kind": "bed",
			"rect": [
				7,
				14,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "살림집 살림방의 침대",
			"level": 2
		},
		{
			"kind": "wardrobe",
			"rect": [
				7,
				19,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "살림집 살림방의 장롱",
			"level": 2
		},
		{
			"kind": "desk",
			"rect": [
				12,
				14,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "살림집 살림방의 책상",
			"level": 2
		},
		{
			"kind": "dining_set",
			"rect": [
				15,
				14,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "살림집 부엌의 식탁",
			"level": 2
		},
		{
			"kind": "fridge_open",
			"rect": [
				20,
				14,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "살림집 부엌의 냉장고",
			"level": 2
		},
		{
			"kind": "cold_stove",
			"rect": [
				15,
				19,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "살림집 부엌의 꺼진 난로",
			"level": 2
		},
		{
			"kind": "parts_rack",
			"rect": [
				23,
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
				28,
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
			"kind": "desk",
			"rect": [
				23,
				22,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "차고 작업 칸의 책상",
			"level": 0
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				84,
				14,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "기름 가게 뒤 창고의 기름통 쌓음",
			"level": 0
		},
		{
			"kind": "shelf",
			"rect": [
				84,
				17,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "기름 가게 뒤 창고의 선반",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				95,
				14,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "기름 가게 뒤 창고의 통",
			"level": 0
		},
		{
			"kind": "display_shelf",
			"rect": [
				84,
				19,
				4,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "기름 가게 매장의 진열대",
			"level": 0
		},
		{
			"kind": "shop_counter",
			"rect": [
				84,
				22,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "기름 가게 매장의 계산대",
			"level": 0
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				94,
				19,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "기름 가게 매장의 기름통 쌓음",
			"level": 0
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				84,
				14,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "기름 가게 뒤 창고의 기름통 쌓음",
			"level": 1
		},
		{
			"kind": "shelf",
			"rect": [
				84,
				17,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "기름 가게 뒤 창고의 선반",
			"level": 1
		},
		{
			"kind": "barrel",
			"rect": [
				95,
				14,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "기름 가게 뒤 창고의 통",
			"level": 1
		},
		{
			"kind": "display_shelf",
			"rect": [
				84,
				19,
				4,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "기름 가게 매장의 진열대",
			"level": 1
		},
		{
			"kind": "shop_counter",
			"rect": [
				84,
				22,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "기름 가게 매장의 계산대",
			"level": 1
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				94,
				19,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "기름 가게 매장의 기름통 쌓음",
			"level": 1
		},
		{
			"kind": "parts_rack",
			"rect": [
				37,
				2,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "온수 설비동 작업 칸의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				41,
				2,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "온수 설비동 작업 칸의 통",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				37,
				3,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "온수 설비동 작업 칸의 책상",
			"level": 0
		},
		{
			"kind": "parts_rack",
			"rect": [
				43,
				2,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "온수 설비동 보관 칸의 부품 서랍 선반",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				46,
				2,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "온수 설비동 보관 칸의 통",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				43,
				6,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "온수 설비동 보관 칸의 책상",
			"level": 0
		},
		{
			"kind": "shelf",
			"rect": [
				53,
				1,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "가게 겸 집 뒤 창고의 선반",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				57,
				1,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "가게 겸 집 뒤 창고의 책상",
			"level": 0
		},
		{
			"kind": "display_shelf",
			"rect": [
				60,
				1,
				4,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "가게 겸 집 매장의 진열대",
			"level": 0
		},
		{
			"kind": "shop_counter",
			"rect": [
				60,
				6,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "가게 겸 집 매장의 계산대",
			"level": 0
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				60,
				2,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "가게 겸 집 매장의 기름통 쌓음",
			"level": 0
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				51,
				1,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "가게 겸 집 뒤 창고의 기름통 쌓음",
			"level": 1
		},
		{
			"kind": "shelf",
			"rect": [
				51,
				6,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "가게 겸 집 뒤 창고의 선반",
			"level": 1
		},
		{
			"kind": "desk",
			"rect": [
				57,
				1,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "가게 겸 집 뒤 창고의 책상",
			"level": 1
		},
		{
			"kind": "display_shelf",
			"rect": [
				60,
				1,
				4,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "가게 겸 집 매장의 진열대",
			"level": 1
		},
		{
			"kind": "shop_counter",
			"rect": [
				60,
				6,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "가게 겸 집 매장의 계산대",
			"level": 1
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				60,
				2,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "가게 겸 집 매장의 기름통 쌓음",
			"level": 1
		},
		{
			"kind": "bed",
			"rect": [
				119,
				3,
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
				119,
				9,
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
				3,
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
				3,
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
				131,
				3,
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
				131,
				9,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "연립 집 부엌의 꺼진 난로",
			"level": 0
		},
		{
			"kind": "dining_set",
			"rect": [
				133,
				3,
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
				138,
				3,
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
				138,
				9,
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
				119,
				3,
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
				119,
				9,
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
				3,
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
				3,
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
				131,
				3,
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
				131,
				9,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 부엌의 꺼진 난로",
			"level": 1
		},
		{
			"kind": "dining_set",
			"rect": [
				133,
				3,
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
				138,
				3,
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
				138,
				9,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 부엌의 꺼진 난로",
			"level": 1
		},
		{
			"kind": "bed",
			"rect": [
				119,
				3,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 살림방의 침대",
			"level": 2
		},
		{
			"kind": "wardrobe",
			"rect": [
				119,
				9,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 살림방의 장롱",
			"level": 2
		},
		{
			"kind": "desk",
			"rect": [
				123,
				3,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 살림방의 책상",
			"level": 2
		},
		{
			"kind": "dining_set",
			"rect": [
				126,
				3,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 부엌의 식탁",
			"level": 2
		},
		{
			"kind": "fridge_open",
			"rect": [
				131,
				3,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 부엌의 냉장고",
			"level": 2
		},
		{
			"kind": "cold_stove",
			"rect": [
				131,
				9,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 부엌의 꺼진 난로",
			"level": 2
		},
		{
			"kind": "dining_set",
			"rect": [
				133,
				3,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 부엌의 식탁",
			"level": 2
		},
		{
			"kind": "fridge_open",
			"rect": [
				138,
				3,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 부엌의 냉장고",
			"level": 2
		},
		{
			"kind": "cold_stove",
			"rect": [
				138,
				9,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "연립 집 부엌의 꺼진 난로",
			"level": 2
		},
		{
			"kind": "coal_heap",
			"rect": [
				157,
				1,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "석탄 광 작업 칸의 석탄 더미",
			"level": -1
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				162,
				1,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "석탄 광 작업 칸의 기름통 쌓음",
			"level": -1
		},
		{
			"kind": "sack_pile",
			"rect": [
				160,
				1,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "석탄 광 작업 칸의 자루 더미",
			"level": -1
		},
		{
			"kind": "coal_heap",
			"rect": [
				165,
				1,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "석탄 광 보관 칸의 석탄 더미",
			"level": -1
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				169,
				1,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "석탄 광 보관 칸의 기름통 쌓음",
			"level": -1
		},
		{
			"kind": "barrel",
			"rect": [
				165,
				3,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "석탄 광 보관 칸의 통",
			"level": -1
		},
		{
			"kind": "coal_heap",
			"rect": [
				157,
				1,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "석탄 광 작업 칸의 석탄 더미",
			"level": 0
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				162,
				1,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "석탄 광 작업 칸의 기름통 쌓음",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				157,
				3,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "석탄 광 작업 칸의 통",
			"level": 0
		},
		{
			"kind": "coal_heap",
			"rect": [
				165,
				1,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "석탄 광 보관 칸의 석탄 더미",
			"level": 0
		},
		{
			"kind": "fuel_drum_stack",
			"rect": [
				169,
				1,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "석탄 광 보관 칸의 기름통 쌓음",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				165,
				3,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "석탄 광 보관 칸의 통",
			"level": 0
		},
		{
			"kind": "bin_bay",
			"rect": [
				22,
				37,
				4,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "마당의 작업 물건",
			"level": 0
		},
		{
			"kind": "crate_stack",
			"rect": [
				50,
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
			"kind": "fuel_drum_stack",
			"rect": [
				74,
				36,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "기름통 쌓음",
			"level": 0
		},
		{
			"kind": "bench",
			"rect": [
				100,
				30,
				1,
				3
			],
			"solid": "low",
			"facing": 0,
			"note": "긴 의자",
			"level": 0
		},
		{
			"kind": "fieldstone_wall",
			"rect": [
				0,
				23,
				6,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "마당의 작업 물건",
			"level": 0
		},
		{
			"kind": "bin_bay",
			"rect": [
				116,
				34,
				4,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "마당의 작업 물건",
			"level": 0
		},
		{
			"kind": "box_truck",
			"rect": [
				116,
				36,
				6,
				3
			],
			"solid": "wall",
			"facing": 0,
			"note": "마당의 작업 물건",
			"level": 0
		},
		{
			"kind": "car",
			"rect": [
				116,
				39,
				4,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "버려진 차",
			"level": 0
		},
		{
			"kind": "crate_stack",
			"rect": [
				116,
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
			"kind": "firewood_pile",
			"rect": [
				116,
				43,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "장작 더미",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				116,
				45,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "통",
			"level": 0
		},
		{
			"kind": "market_stall",
			"rect": [
				103,
				19,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "마당의 작업 물건",
			"level": 0
		},
		{
			"kind": "market_stall",
			"rect": [
				107,
				21,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "마당의 작업 물건",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				103,
				22,
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
				101,
				18,
				1,
				3
			],
			"solid": "low",
			"facing": 0,
			"note": "긴 의자",
			"level": 0
		},
		{
			"kind": "street_tree",
			"rect": [
				1,
				14,
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
				3,
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
				1,
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
				150,
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
				153,
				7,
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
				152,
				12,
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
				12,
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
				160,
				13,
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
				111,
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
				114,
				20,
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
				111,
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
			"name": "연료 도매 창고 입고 방 상자",
			"cell": [
				41,
				19
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_1",
			"name": "연료 도매 창고 비축 방 상자",
			"cell": [
				47,
				19
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_2",
			"name": "연료 도매 창고 작업 방 상자",
			"cell": [
				53,
				19
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_3",
			"name": "연료 도매 창고 접수 방 상자",
			"cell": [
				58,
				19
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_4",
			"name": "연료 도매 창고 보관 방 상자",
			"cell": [
				63,
				19
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_5",
			"name": "연료 도매 창고 안쪽 광 상자",
			"cell": [
				68,
				19
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_6",
			"name": "연료 도매 창고 입고 방 상자",
			"cell": [
				41,
				19
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_7",
			"name": "연료 도매 창고 비축 방 상자",
			"cell": [
				47,
				19
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_8",
			"name": "연료 도매 창고 작업 방 상자",
			"cell": [
				53,
				19
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_9",
			"name": "연료 도매 창고 접수 방 상자",
			"cell": [
				55,
				19
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_10",
			"name": "연료 도매 창고 보관 방 상자",
			"cell": [
				60,
				19
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_11",
			"name": "연료 도매 창고 안쪽 광 상자",
			"cell": [
				65,
				19
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_12",
			"name": "연료 도매 창고 입고 방 상자",
			"cell": [
				41,
				19
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_13",
			"name": "연료 도매 창고 비축 방 상자",
			"cell": [
				47,
				19
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_14",
			"name": "연료 도매 창고 작업 방 상자",
			"cell": [
				53,
				19
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_15",
			"name": "연료 도매 창고 접수 방 상자",
			"cell": [
				58,
				19
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_16",
			"name": "연료 도매 창고 보관 방 상자",
			"cell": [
				63,
				19
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_17",
			"name": "연료 도매 창고 안쪽 광 상자",
			"cell": [
				68,
				19
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_18",
			"name": "석탄 헛간 작업 칸 상자",
			"cell": [
				71,
				22
			],
			"level": 0,
			"building": 17,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_19",
			"name": "살림집 살림방 상자",
			"cell": [
				13,
				19
			],
			"level": -1,
			"building": 18,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_20",
			"name": "살림집 부엌 상자",
			"cell": [
				20,
				19
			],
			"level": -1,
			"building": 18,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_21",
			"name": "살림집 살림방 상자",
			"cell": [
				13,
				19
			],
			"level": 0,
			"building": 18,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_22",
			"name": "살림집 부엌 상자",
			"cell": [
				20,
				19
			],
			"level": 0,
			"building": 18,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_23",
			"name": "살림집 살림방 상자",
			"cell": [
				13,
				19
			],
			"level": 1,
			"building": 18,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_24",
			"name": "살림집 부엌 상자",
			"cell": [
				20,
				19
			],
			"level": 1,
			"building": 18,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_25",
			"name": "살림집 살림방 상자",
			"cell": [
				13,
				19
			],
			"level": 2,
			"building": 18,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_26",
			"name": "살림집 부엌 상자",
			"cell": [
				20,
				19
			],
			"level": 2,
			"building": 18,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_27",
			"name": "차고 작업 칸 상자",
			"cell": [
				28,
				22
			],
			"level": 0,
			"building": 19,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_28",
			"name": "기름 가게 뒤 창고 상자",
			"cell": [
				95,
				17
			],
			"level": 0,
			"building": 20,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_29",
			"name": "기름 가게 매장 상자",
			"cell": [
				95,
				22
			],
			"level": 0,
			"building": 20,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_30",
			"name": "기름 가게 뒤 창고 상자",
			"cell": [
				95,
				17
			],
			"level": 1,
			"building": 20,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_31",
			"name": "기름 가게 매장 상자",
			"cell": [
				95,
				22
			],
			"level": 1,
			"building": 20,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_32",
			"name": "온수 설비동 작업 칸 상자",
			"cell": [
				41,
				6
			],
			"level": 0,
			"building": 21,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_33",
			"name": "온수 설비동 보관 칸 상자",
			"cell": [
				46,
				6
			],
			"level": 0,
			"building": 21,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_34",
			"name": "가게 겸 집 뒤 창고 상자",
			"cell": [
				51,
				6
			],
			"level": 0,
			"building": 22,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_35",
			"name": "가게 겸 집 매장 상자",
			"cell": [
				66,
				1
			],
			"level": 0,
			"building": 22,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_36",
			"name": "가게 겸 집 뒤 창고 상자",
			"cell": [
				58,
				6
			],
			"level": 1,
			"building": 22,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_37",
			"name": "가게 겸 집 매장 상자",
			"cell": [
				66,
				1
			],
			"level": 1,
			"building": 22,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_38",
			"name": "연립 집 살림방 상자",
			"cell": [
				124,
				9
			],
			"level": 0,
			"building": 23,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_39",
			"name": "연립 집 부엌 상자",
			"cell": [
				126,
				9
			],
			"level": 0,
			"building": 23,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_40",
			"name": "연립 집 부엌 상자",
			"cell": [
				133,
				9
			],
			"level": 0,
			"building": 23,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_41",
			"name": "연립 집 살림방 상자",
			"cell": [
				124,
				9
			],
			"level": 1,
			"building": 23,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_42",
			"name": "연립 집 부엌 상자",
			"cell": [
				126,
				9
			],
			"level": 1,
			"building": 23,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_43",
			"name": "연립 집 부엌 상자",
			"cell": [
				133,
				9
			],
			"level": 1,
			"building": 23,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_44",
			"name": "연립 집 살림방 상자",
			"cell": [
				124,
				9
			],
			"level": 2,
			"building": 23,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_45",
			"name": "연립 집 부엌 상자",
			"cell": [
				126,
				9
			],
			"level": 2,
			"building": 23,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_46",
			"name": "연립 집 부엌 상자",
			"cell": [
				133,
				9
			],
			"level": 2,
			"building": 23,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_47",
			"name": "석탄 광 작업 칸 상자",
			"cell": [
				157,
				3
			],
			"level": -1,
			"building": 24,
			"search": 7,
			"items": [
				"bottle_spirit",
				"plank",
				"bottle_spirit",
				"plank"
			],
			"locked": true,
			"searched": false
		},
		{
			"id": "north_cache_48",
			"name": "석탄 광 보관 칸 상자",
			"cell": [
				170,
				3
			],
			"level": -1,
			"building": 24,
			"search": 7,
			"items": [
				"bottle_spirit",
				"plank",
				"bottle_spirit",
				"plank"
			],
			"locked": true,
			"searched": false
		},
		{
			"id": "north_cache_49",
			"name": "석탄 광 작업 칸 상자",
			"cell": [
				163,
				3
			],
			"level": 0,
			"building": 24,
			"search": 4,
			"items": [
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_50",
			"name": "석탄 광 보관 칸 상자",
			"cell": [
				170,
				3
			],
			"level": 0,
			"building": 24,
			"search": 4,
			"items": [
				"bottle_spirit"
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
				"bottle_spirit"
			],
			"locked": false,
			"searched": false
		}
	],
	"entries": [
		{
			"id": "서쪽 연료 골목",
			"name": "서쪽 연료 골목",
			"cells": [
				[
					0,
					8
				],
				[
					0,
					9
				],
				[
					0,
					10
				],
				[
					0,
					11
				]
			],
			"gap": 2.5
		},
		{
			"id": "북쪽 연료 길",
			"name": "북쪽 연료 길",
			"cells": [
				[
					79,
					0
				],
				[
					80,
					0
				],
				[
					81,
					0
				],
				[
					82,
					0
				]
			],
			"gap": 2.5
		},
		{
			"id": "동쪽 광장 길",
			"name": "동쪽 광장 길",
			"cells": [
				[
					174,
					14
				],
				[
					174,
					15
				],
				[
					174,
					16
				],
				[
					174,
					17
				]
			],
			"gap": 0.6
		}
	],
	"holes": [],
	"barricades": [
		[
			31,
			22
		],
		[
			34,
			22
		],
		[
			79,
			22
		],
		[
			81,
			22
		]
	],
	"slots": [
		"K"
	],
	"deep": 8,
	"forecourts": [
		[
			51,
			24,
			5,
			4
		],
		[
			72,
			24,
			5,
			4
		],
		[
			12,
			24,
			5,
			4
		],
		[
			24,
			24,
			5,
			4
		],
		[
			88,
			24,
			5,
			4
		],
		[
			36,
			8,
			5,
			4
		],
		[
			50,
			8,
			5,
			4
		],
		[
			127,
			14,
			5,
			4
		],
		[
			162,
			8,
			5,
			4
		]
	],
	"crossings": [
		32,
		48
	],
	"stock": [
		"fuel_drum_stack",
		"coal_heap",
		"sack_pile",
		"barrel"
	],
	"loot": [
		"bottle_spirit",
		"plank"
	],
	"assumptions": [
		"북서 나무는 급수탑 예외를 피하도록 살림집 서쪽의 열넷째 줄 아래로 옮기고 네 그루로 보충했다.",
		"기름과 석탄의 외형은 새 물건 자리로 표현하고 상자에는 본에 있는 병과 목재 자원만 넣었다.",
		"앞쪽 복도 출입문과 북쪽 입고 문을 따로 두었다."
	]
}

const SOUTH_TREE_MOVES: Array = [[[62,31],[66,39]],[[88,42],[95,40]],[[93,43],[98,42]],[[64,43],[69,41]],[[41,50],[31,39]],[[70,50],[68,51]],[[90,54],[98,57]],[[65,49],[71,53]],[[123,49],[131,52]],[[29,65],[27,66]]]
const SOUTH_WORK: Dictionary = {"name":"시장 창고 작업 구역","cell":[116,30],"rect":[104,28,24,8]}

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
const ENTRY_NAMES: Dictionary = {"west_alley": "서쪽 골목", "southwest_alley": "남서쪽 골목", "east_market": "동쪽 시장", "south_street": "남쪽 거리", "east_lower": "동쪽 아랫길", "manhole_01": "첫째 맨홀", "manhole_02": "둘째 맨홀", "manhole_03": "셋째 맨홀", "manhole_04": "넷째 맨홀", "서쪽 연료 골목": "서쪽 연료 골목", "북쪽 연료 길": "북쪽 연료 길", "동쪽 광장 길": "동쪽 광장 길"}
const ENTRY_WEIGHTS: Dictionary = {"west_alley": 0.5, "southwest_alley": 0.5, "east_market": 1.0, "south_street": 1.0, "east_lower": 0.5, "manhole_01": 0.3, "manhole_02": 0.3, "manhole_03": 0.3, "manhole_04": 0.3, "서쪽 연료 골목": 0.5, "북쪽 연료 길": 0.5, "동쪽 광장 길": 1.0}
const FIRST_ENTRY: String = "east_market"


static func build() -> Dictionary:
	var data: Dictionary = _build_plain()
	data["entry_names"] = ENTRY_NAMES.duplicate()
	data["entry_weights"] = ENTRY_WEIGHTS.duplicate()
	data["first_entry"] = FIRST_ENTRY
	return data
