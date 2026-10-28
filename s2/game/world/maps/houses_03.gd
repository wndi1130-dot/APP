# 이 지도가 다른 판단을 만드는 것: 담 안 마당은 대문만 막으면 안전하나 나올 길도 그뿐이다.
# 위쪽의 판단: 담요와 천을 얻는 대신 아래쪽 농가 마당의 장작을 놓치고, 층층 꺾인 길을 들어갔다 나오는 걸음이 길다.
extends RefCounted

const FieldGrid = preload("res://game/world/field_grid.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 165
const SOUTH_HEIGHT: int = 100
const HEIGHT: int = SOUTH_HEIGHT + 45
const PLACE_ID: String = "houses_03"

# 각 좌표는 이 지도의 독립 평면이다. 위층 장식은 충돌을 만들지 않는다.
const PLAN: Dictionary = {
	"number": 3,
	"width": 165,
	"height": 100,
	"judgment": "담 안 마당은 대문만 막으면 안전하나 나올 길도 그뿐이다.",
	"zones": [{"id":"A","name":"승강장 앞 농가","rect":[0,0,165,30]},
		{"id":"B","name":"서쪽 농가","rect":[0,30,106,26]},
		{"id":"C","name":"주막 앞길","rect":[106,30,59,26]},
		{"id":"D","name":"못 뒤 마당","rect":[0,56,53,44]},
		{"id":"E","name":"우물 마당","rect":[53,56,53,44]},
		{"id":"F","name":"연립 안뜰","rect":[106,56,59,44]},
		{"id":"G","name":"남쪽 농가","rect":[0,82,165,18]},
		{"id":"H","name":"동쪽 밭길","rect":[125,4,40,26]}],
	"grounds": [{"rect":[58,10,6,24],"floor":1},
		{"rect":[58,30,47,5],"floor":1},
		{"rect":[100,30,5,45],"floor":1},
		{"rect":[0,70,105,5],"floor":1},
		{"rect":[98,70,4,30],"floor":1},
		{"rect":[158,16,7,32],"floor":1},
		{"rect":[105,30,60,4],"floor":1},
		{"rect":[158,44,7,4],"floor":1},
		{"rect":[30,54,6,18],"floor":1},
		{"rect":[34,62,12,4],"floor":7},
		{"rect":[106,74,55,4],"floor":1},
		{"rect":[0,28,58,5],"floor":1},
		{"rect":[64,26,36,4],"floor":1},
		{"rect":[108,4,16,23],"floor":5},
		{"rect":[37,35,4,40],"floor":1},
		{"rect":[53,28,11,4],"floor":1},
		{"rect":[48,74,4,4],"floor":1},
		{"rect":[102,84,6,5],"floor":1},
		{"rect":[137,13,6,4],"floor":5},
		{"rect":[147,88,6,4],"floor":5}],
	"buildings": [{"name":"회칠 연립 가 동","rect":[116,34,40,20],"top":3,"basement":true,"role":"home","main":true,"id":0},
		{"name":"연립 나 동","rect":[112,58,24,16],"top":3,"basement":false,"role":"home","id":1},
		{"name":"연립 다 동","rect":[142,58,18,18],"top":3,"basement":false,"role":"home","mode":"vertical","id":2},
		{"name":"농가 가","rect":[12,12,22,14],"top":2,"basement":false,"role":"home","mode":"vertical","id":3},
		{"name":"농가 나","rect":[68,12,22,14],"top":2,"basement":false,"role":"home","mode":"vertical","id":4},
		{"name":"농가 다","rect":[10,39,22,14],"top":2,"basement":true,"role":"home","id":5},
		{"name":"농가 라","rect":[4,80,22,14],"top":2,"basement":false,"role":"home","mode":"vertical","id":6},
		{"name":"주막","rect":[42,35,26,16],"top":2,"basement":false,"role":"shop","stock":["bench","desk","cold_stove"],"id":7},
		{"name":"잡화점","rect":[74,38,20,12],"top":2,"basement":false,"role":"shop","stock":["display_shelf","shop_counter","shelf"],"id":8},
		{"name":"대장간","rect":[74,80,18,12],"top":1,"basement":false,"role":"shed","stock":["anvil_block","barrel","firewood_pile"],"id":9},
		{"name":"외양간","rect":[40,12,14,14],"top":1,"basement":false,"role":"shed","mode":"vertical","id":10},
		{"name":"곡식 곳간","rect":[34,80,24,14],"top":1,"basement":false,"role":"shed","stock":["sack_pile","firewood_pile","hay_cart"],"id":11},
		{"name":"헛간","rect":[6,57,20,10],"top":1,"basement":false,"role":"shed","id":12},
		{"name":"헛간","rect":[112,80,20,12],"top":1,"basement":false,"role":"shed","id":13},
		{"name":"장작 헛간","rect":[62,82,8,12],"top":1,"basement":false,"role":"shed","mode":"vertical","id":14},
		{"name":"우물 정자","rect":[84,56,8,8],"top":1,"basement":false,"role":"shed","id":15}],
	"entries": [{"id":"west_road","cells":[[0,70],[0,71],[0,72],[0,73]],"gap":0.6},
		{"id":"south_path","cells":[[98,99],[99,99],[100,99],[101,99]],"gap":2},
		{"id":"east_village","cells":[[164,44],[164,45],[164,46],[164,47]],"gap":0.6},
		{"id":"east_field","cells":[[164,16],[164,17],[164,18],[164,19]],"gap":2}],
	"holes": [{"id":"manhole_01","cell":[102,52],"name":"길 굽이 맨홀","level":0},
		{"id":"manhole_02","cell":[70,38],"name":"주막 앞 맨홀","level":0},
		{"id":"drain_01","cell":[34,62],"name":"도랑 끝 배수구","level":0}],
	"barricades": [[59,26],[61,26],[63,26],[4,26],[6,26]],
	"deepBuildings": [0,11],
	"deepLevels": [-1,0],
	"assumptions": ["주 건물은 실내 육백 칸 기준에 맞춰 마흔 곱하기 스무 칸으로 넓혔다.","주막 뒤 못을 남쪽으로 옮겨 가게와 물이 겹치지 않게 했다.","가로수 길의 북쪽 줄은 큰길 기준에 맞춰 여섯 칸으로 넓혔다.","띠 안 마당은 건물 벽과 높은 담으로 둘러 낮은 엄폐 수를 지켰다. 나머지 담은 낮은 들돌 토막과 벽을 번갈아 썼다. 두 마당은 농가의 뒤쪽 저장 방을 비상 통로로 쓴다.","띠의 물리적 길목은 두 곳으로 모아 각 틈을 네 칸에서 여섯 칸으로 유지하고 트인 변은 남겼다."],
	"tx": 16,
	"band": [0,4,116,26],
	"shells": [{"building":0,"level":0,"rect":[116,34,40,20]},
		{"building":0,"level":1,"rect":[116,34,40,20]},
		{"building":0,"level":2,"rect":[116,34,40,20]},
		{"building":0,"level":-1,"rect":[116,34,40,20]},
		{"building":1,"level":0,"rect":[112,58,24,16]},
		{"building":1,"level":1,"rect":[112,58,24,16]},
		{"building":1,"level":2,"rect":[112,58,24,16]},
		{"building":2,"level":0,"rect":[142,58,18,18]},
		{"building":2,"level":1,"rect":[142,58,18,18]},
		{"building":2,"level":2,"rect":[142,58,18,18]},
		{"building":3,"level":0,"rect":[12,12,22,14]},
		{"building":3,"level":1,"rect":[12,12,22,14]},
		{"building":4,"level":0,"rect":[68,12,22,14]},
		{"building":4,"level":1,"rect":[68,12,22,14]},
		{"building":5,"level":0,"rect":[10,39,22,14]},
		{"building":5,"level":1,"rect":[10,39,22,14]},
		{"building":5,"level":-1,"rect":[10,39,22,14]},
		{"building":6,"level":0,"rect":[4,80,22,14]},
		{"building":6,"level":1,"rect":[4,80,22,14]},
		{"building":7,"level":0,"rect":[42,35,26,16]},
		{"building":7,"level":1,"rect":[42,35,26,16]},
		{"building":8,"level":0,"rect":[74,38,20,12]},
		{"building":8,"level":1,"rect":[74,38,20,12]},
		{"building":9,"level":0,"rect":[74,80,18,12]},
		{"building":10,"level":0,"rect":[40,12,14,14]},
		{"building":11,"level":0,"rect":[34,80,24,14]},
		{"building":12,"level":0,"rect":[6,57,20,10]},
		{"building":13,"level":0,"rect":[112,80,20,12]},
		{"building":14,"level":0,"rect":[62,82,8,12]},
		{"building":15,"level":0,"rect":[84,56,8,8]}],
	"walls": [{"building":0,"level":0,"rect":[117,42,38,1]},
		{"building":0,"level":0,"rect":[117,45,38,1]},
		{"building":0,"level":0,"rect":[123,35,1,7]},
		{"building":0,"level":0,"rect":[130,35,1,7]},
		{"building":0,"level":0,"rect":[137,35,1,7]},
		{"building":0,"level":0,"rect":[143,35,1,7]},
		{"building":0,"level":0,"rect":[149,35,1,7]},
		{"building":0,"level":0,"rect":[123,46,1,7]},
		{"building":0,"level":0,"rect":[130,46,1,7]},
		{"building":0,"level":0,"rect":[137,46,1,7]},
		{"building":0,"level":0,"rect":[143,46,1,7]},
		{"building":0,"level":0,"rect":[149,46,1,7]},
		{"building":0,"level":1,"rect":[117,42,38,1]},
		{"building":0,"level":1,"rect":[117,45,38,1]},
		{"building":0,"level":1,"rect":[123,35,1,7]},
		{"building":0,"level":1,"rect":[130,35,1,7]},
		{"building":0,"level":1,"rect":[137,35,1,7]},
		{"building":0,"level":1,"rect":[143,35,1,7]},
		{"building":0,"level":1,"rect":[149,35,1,7]},
		{"building":0,"level":1,"rect":[123,46,1,7]},
		{"building":0,"level":1,"rect":[130,46,1,7]},
		{"building":0,"level":1,"rect":[137,46,1,7]},
		{"building":0,"level":1,"rect":[143,46,1,7]},
		{"building":0,"level":1,"rect":[149,46,1,7]},
		{"building":0,"level":2,"rect":[117,42,38,1]},
		{"building":0,"level":2,"rect":[117,45,38,1]},
		{"building":0,"level":2,"rect":[123,35,1,7]},
		{"building":0,"level":2,"rect":[130,35,1,7]},
		{"building":0,"level":2,"rect":[137,35,1,7]},
		{"building":0,"level":2,"rect":[143,35,1,7]},
		{"building":0,"level":2,"rect":[149,35,1,7]},
		{"building":0,"level":2,"rect":[123,46,1,7]},
		{"building":0,"level":2,"rect":[130,46,1,7]},
		{"building":0,"level":2,"rect":[137,46,1,7]},
		{"building":0,"level":2,"rect":[143,46,1,7]},
		{"building":0,"level":2,"rect":[149,46,1,7]},
		{"building":0,"level":-1,"rect":[117,42,38,1]},
		{"building":0,"level":-1,"rect":[117,45,38,1]},
		{"building":0,"level":-1,"rect":[123,35,1,7]},
		{"building":0,"level":-1,"rect":[130,35,1,7]},
		{"building":0,"level":-1,"rect":[137,35,1,7]},
		{"building":0,"level":-1,"rect":[143,35,1,7]},
		{"building":0,"level":-1,"rect":[149,35,1,7]},
		{"building":0,"level":-1,"rect":[123,46,1,7]},
		{"building":0,"level":-1,"rect":[130,46,1,7]},
		{"building":0,"level":-1,"rect":[137,46,1,7]},
		{"building":0,"level":-1,"rect":[143,46,1,7]},
		{"building":0,"level":-1,"rect":[149,46,1,7]},
		{"building":1,"level":0,"rect":[113,64,22,1]},
		{"building":1,"level":0,"rect":[113,67,22,1]},
		{"building":1,"level":0,"rect":[124,59,1,5]},
		{"building":1,"level":0,"rect":[124,68,1,5]},
		{"building":1,"level":1,"rect":[113,64,22,1]},
		{"building":1,"level":1,"rect":[113,67,22,1]},
		{"building":1,"level":1,"rect":[124,59,1,5]},
		{"building":1,"level":1,"rect":[124,68,1,5]},
		{"building":1,"level":2,"rect":[113,64,22,1]},
		{"building":1,"level":2,"rect":[113,67,22,1]},
		{"building":1,"level":2,"rect":[124,59,1,5]},
		{"building":1,"level":2,"rect":[124,68,1,5]},
		{"building":2,"level":0,"rect":[149,59,1,16]},
		{"building":2,"level":0,"rect":[152,59,1,16]},
		{"building":2,"level":0,"rect":[143,67,6,1]},
		{"building":2,"level":0,"rect":[153,67,6,1]},
		{"building":2,"level":1,"rect":[149,59,1,16]},
		{"building":2,"level":1,"rect":[152,59,1,16]},
		{"building":2,"level":1,"rect":[143,67,6,1]},
		{"building":2,"level":1,"rect":[153,67,6,1]},
		{"building":2,"level":2,"rect":[149,59,1,16]},
		{"building":2,"level":2,"rect":[152,59,1,16]},
		{"building":2,"level":2,"rect":[143,67,6,1]},
		{"building":2,"level":2,"rect":[153,67,6,1]},
		{"building":3,"level":0,"rect":[21,13,1,12]},
		{"building":3,"level":0,"rect":[24,13,1,12]},
		{"building":3,"level":1,"rect":[21,13,1,12]},
		{"building":3,"level":1,"rect":[24,13,1,12]},
		{"building":4,"level":0,"rect":[77,13,1,12]},
		{"building":4,"level":0,"rect":[80,13,1,12]},
		{"building":4,"level":1,"rect":[77,13,1,12]},
		{"building":4,"level":1,"rect":[80,13,1,12]},
		{"building":5,"level":0,"rect":[11,44,20,1]},
		{"building":5,"level":0,"rect":[11,47,20,1]},
		{"building":5,"level":0,"rect":[21,40,1,4]},
		{"building":5,"level":0,"rect":[21,48,1,4]},
		{"building":5,"level":1,"rect":[11,44,20,1]},
		{"building":5,"level":1,"rect":[11,47,20,1]},
		{"building":5,"level":1,"rect":[21,40,1,4]},
		{"building":5,"level":1,"rect":[21,48,1,4]},
		{"building":5,"level":-1,"rect":[11,44,20,1]},
		{"building":5,"level":-1,"rect":[11,47,20,1]},
		{"building":5,"level":-1,"rect":[21,40,1,4]},
		{"building":5,"level":-1,"rect":[21,48,1,4]},
		{"building":6,"level":0,"rect":[13,81,1,12]},
		{"building":6,"level":0,"rect":[16,81,1,12]},
		{"building":6,"level":1,"rect":[13,81,1,12]},
		{"building":6,"level":1,"rect":[16,81,1,12]},
		{"building":7,"level":0,"rect":[43,41,24,1]},
		{"building":7,"level":0,"rect":[43,44,24,1]},
		{"building":7,"level":0,"rect":[51,36,1,5]},
		{"building":7,"level":0,"rect":[59,36,1,5]},
		{"building":7,"level":0,"rect":[51,45,1,5]},
		{"building":7,"level":0,"rect":[59,45,1,5]},
		{"building":7,"level":1,"rect":[43,41,24,1]},
		{"building":7,"level":1,"rect":[43,44,24,1]},
		{"building":7,"level":1,"rect":[51,36,1,5]},
		{"building":7,"level":1,"rect":[59,36,1,5]},
		{"building":7,"level":1,"rect":[51,45,1,5]},
		{"building":7,"level":1,"rect":[59,45,1,5]},
		{"building":8,"level":0,"rect":[75,42,18,1]},
		{"building":8,"level":0,"rect":[75,45,18,1]},
		{"building":8,"level":0,"rect":[84,39,1,3]},
		{"building":8,"level":0,"rect":[84,46,1,3]},
		{"building":8,"level":1,"rect":[75,42,18,1]},
		{"building":8,"level":1,"rect":[75,45,18,1]},
		{"building":8,"level":1,"rect":[84,39,1,3]},
		{"building":8,"level":1,"rect":[84,46,1,3]},
		{"building":9,"level":0,"rect":[75,84,16,1]},
		{"building":9,"level":0,"rect":[75,87,16,1]},
		{"building":9,"level":0,"rect":[83,81,1,3]},
		{"building":9,"level":0,"rect":[83,88,1,3]},
		{"building":10,"level":0,"rect":[45,13,1,12]},
		{"building":10,"level":0,"rect":[48,13,1,12]},
		{"building":11,"level":0,"rect":[35,85,22,1]},
		{"building":11,"level":0,"rect":[35,88,22,1]},
		{"building":11,"level":0,"rect":[46,81,1,4]},
		{"building":11,"level":0,"rect":[46,89,1,4]},
		{"building":12,"level":0,"rect":[13,58,1,8]},
		{"building":12,"level":0,"rect":[19,58,1,8]},
		{"building":13,"level":0,"rect":[113,84,18,1]},
		{"building":13,"level":0,"rect":[113,87,18,1]},
		{"building":13,"level":0,"rect":[122,81,1,3]},
		{"building":13,"level":0,"rect":[122,88,1,3]},
		{"building":14,"level":0,"rect":[63,88,6,1]},
		{"building":-1,"level":0,"rect":[8,10,1,1]},
		{"building":-1,"level":0,"rect":[9,10,1,1]},
		{"building":-1,"level":0,"rect":[10,10,1,1]},
		{"building":-1,"level":0,"rect":[11,10,1,1]},
		{"building":-1,"level":0,"rect":[12,10,1,1]},
		{"building":-1,"level":0,"rect":[13,10,1,1]},
		{"building":-1,"level":0,"rect":[14,10,1,1]},
		{"building":-1,"level":0,"rect":[15,10,1,1]},
		{"building":-1,"level":0,"rect":[16,10,1,1]},
		{"building":-1,"level":0,"rect":[17,10,1,1]},
		{"building":-1,"level":0,"rect":[18,10,1,1]},
		{"building":-1,"level":0,"rect":[19,10,1,1]},
		{"building":-1,"level":0,"rect":[20,10,1,1]},
		{"building":-1,"level":0,"rect":[21,10,1,1]},
		{"building":-1,"level":0,"rect":[22,10,1,1]},
		{"building":-1,"level":0,"rect":[23,10,1,1]},
		{"building":-1,"level":0,"rect":[24,10,1,1]},
		{"building":-1,"level":0,"rect":[25,10,1,1]},
		{"building":-1,"level":0,"rect":[26,10,1,1]},
		{"building":-1,"level":0,"rect":[27,10,1,1]},
		{"building":-1,"level":0,"rect":[28,10,1,1]},
		{"building":-1,"level":0,"rect":[29,10,1,1]},
		{"building":-1,"level":0,"rect":[30,10,1,1]},
		{"building":-1,"level":0,"rect":[31,10,1,1]},
		{"building":-1,"level":0,"rect":[32,10,1,1]},
		{"building":-1,"level":0,"rect":[33,10,1,1]},
		{"building":-1,"level":0,"rect":[34,10,1,1]},
		{"building":-1,"level":0,"rect":[35,10,1,1]},
		{"building":-1,"level":0,"rect":[36,10,1,1]},
		{"building":-1,"level":0,"rect":[37,10,1,1]},
		{"building":-1,"level":0,"rect":[38,10,1,1]},
		{"building":-1,"level":0,"rect":[39,10,1,1]},
		{"building":-1,"level":0,"rect":[40,10,1,1]},
		{"building":-1,"level":0,"rect":[41,10,1,1]},
		{"building":-1,"level":0,"rect":[42,10,1,1]},
		{"building":-1,"level":0,"rect":[43,10,1,1]},
		{"building":-1,"level":0,"rect":[44,10,1,1]},
		{"building":-1,"level":0,"rect":[45,10,1,1]},
		{"building":-1,"level":0,"rect":[46,10,1,1]},
		{"building":-1,"level":0,"rect":[47,10,1,1]},
		{"building":-1,"level":0,"rect":[48,10,1,1]},
		{"building":-1,"level":0,"rect":[49,10,1,1]},
		{"building":-1,"level":0,"rect":[50,10,1,1]},
		{"building":-1,"level":0,"rect":[51,10,1,1]},
		{"building":-1,"level":0,"rect":[52,10,1,1]},
		{"building":-1,"level":0,"rect":[53,10,1,1]},
		{"building":-1,"level":0,"rect":[8,34,1,1]},
		{"building":-1,"level":0,"rect":[9,34,1,1]},
		{"building":-1,"level":0,"rect":[10,34,1,1]},
		{"building":-1,"level":0,"rect":[11,34,1,1]},
		{"building":-1,"level":0,"rect":[12,34,1,1]},
		{"building":-1,"level":0,"rect":[13,34,1,1]},
		{"building":-1,"level":0,"rect":[14,34,1,1]},
		{"building":-1,"level":0,"rect":[15,34,1,1]},
		{"building":-1,"level":0,"rect":[24,34,1,1]},
		{"building":-1,"level":0,"rect":[25,34,1,1]},
		{"building":-1,"level":0,"rect":[26,34,1,1]},
		{"building":-1,"level":0,"rect":[27,34,1,1]},
		{"building":-1,"level":0,"rect":[28,34,1,1]},
		{"building":-1,"level":0,"rect":[29,34,1,1]},
		{"building":-1,"level":0,"rect":[30,34,1,1]},
		{"building":-1,"level":0,"rect":[31,34,1,1]},
		{"building":-1,"level":0,"rect":[40,34,1,1]},
		{"building":-1,"level":0,"rect":[41,34,1,1]},
		{"building":-1,"level":0,"rect":[42,34,1,1]},
		{"building":-1,"level":0,"rect":[43,34,1,1]},
		{"building":-1,"level":0,"rect":[44,34,1,1]},
		{"building":-1,"level":0,"rect":[45,34,1,1]},
		{"building":-1,"level":0,"rect":[46,34,1,1]},
		{"building":-1,"level":0,"rect":[47,34,1,1]},
		{"building":-1,"level":0,"rect":[48,34,1,1]},
		{"building":-1,"level":0,"rect":[49,34,1,1]},
		{"building":-1,"level":0,"rect":[50,34,1,1]},
		{"building":-1,"level":0,"rect":[51,34,1,1]},
		{"building":-1,"level":0,"rect":[52,34,1,1]},
		{"building":-1,"level":0,"rect":[53,34,1,1]},
		{"building":-1,"level":0,"rect":[8,11,1,1]},
		{"building":-1,"level":0,"rect":[8,12,1,1]},
		{"building":-1,"level":0,"rect":[8,13,1,1]},
		{"building":-1,"level":0,"rect":[8,14,1,1]},
		{"building":-1,"level":0,"rect":[8,15,1,1]},
		{"building":-1,"level":0,"rect":[8,16,1,1]},
		{"building":-1,"level":0,"rect":[8,17,1,1]},
		{"building":-1,"level":0,"rect":[8,18,1,1]},
		{"building":-1,"level":0,"rect":[8,19,1,1]},
		{"building":-1,"level":0,"rect":[8,20,1,1]},
		{"building":-1,"level":0,"rect":[8,21,1,1]},
		{"building":-1,"level":0,"rect":[8,22,1,1]},
		{"building":-1,"level":0,"rect":[8,23,1,1]},
		{"building":-1,"level":0,"rect":[8,24,1,1]},
		{"building":-1,"level":0,"rect":[8,25,1,1]},
		{"building":-1,"level":0,"rect":[8,26,1,1]},
		{"building":-1,"level":0,"rect":[8,27,1,1]},
		{"building":-1,"level":0,"rect":[8,28,1,1]},
		{"building":-1,"level":0,"rect":[8,29,1,1]},
		{"building":-1,"level":0,"rect":[8,30,1,1]},
		{"building":-1,"level":0,"rect":[8,31,1,1]},
		{"building":-1,"level":0,"rect":[8,32,1,1]},
		{"building":-1,"level":0,"rect":[8,33,1,1]},
		{"building":-1,"level":0,"rect":[53,11,1,1]},
		{"building":-1,"level":0,"rect":[53,26,1,1]},
		{"building":-1,"level":0,"rect":[53,27,1,1]},
		{"building":-1,"level":0,"rect":[53,32,1,1]},
		{"building":-1,"level":0,"rect":[53,33,1,1]},
		{"building":-1,"level":0,"rect":[66,12,1,1]},
		{"building":-1,"level":0,"rect":[67,12,1,1]},
		{"building":-1,"level":0,"rect":[90,12,1,1]},
		{"building":-1,"level":0,"rect":[91,12,1,1]},
		{"building":-1,"level":0,"rect":[92,12,1,1]},
		{"building":-1,"level":0,"rect":[93,12,1,1]},
		{"building":-1,"level":0,"rect":[94,12,1,1]},
		{"building":-1,"level":0,"rect":[95,12,1,1]},
		{"building":-1,"level":0,"rect":[66,30,1,1]},
		{"building":-1,"level":0,"rect":[67,30,1,1]},
		{"building":-1,"level":0,"rect":[68,30,1,1]},
		{"building":-1,"level":0,"rect":[69,30,1,1]},
		{"building":-1,"level":0,"rect":[70,30,1,1]},
		{"building":-1,"level":0,"rect":[71,30,1,1]},
		{"building":-1,"level":0,"rect":[72,30,1,1]},
		{"building":-1,"level":0,"rect":[73,30,1,1]},
		{"building":-1,"level":0,"rect":[74,30,1,1]},
		{"building":-1,"level":0,"rect":[75,30,1,1]},
		{"building":-1,"level":0,"rect":[76,30,1,1]},
		{"building":-1,"level":0,"rect":[81,30,1,1]},
		{"building":-1,"level":0,"rect":[82,30,1,1]},
		{"building":-1,"level":0,"rect":[83,30,1,1]},
		{"building":-1,"level":0,"rect":[84,30,1,1]},
		{"building":-1,"level":0,"rect":[85,30,1,1]},
		{"building":-1,"level":0,"rect":[86,30,1,1]},
		{"building":-1,"level":0,"rect":[87,30,1,1]},
		{"building":-1,"level":0,"rect":[88,30,1,1]},
		{"building":-1,"level":0,"rect":[89,30,1,1]},
		{"building":-1,"level":0,"rect":[90,30,1,1]},
		{"building":-1,"level":0,"rect":[91,30,1,1]},
		{"building":-1,"level":0,"rect":[92,30,1,1]},
		{"building":-1,"level":0,"rect":[93,30,1,1]},
		{"building":-1,"level":0,"rect":[94,30,1,1]},
		{"building":-1,"level":0,"rect":[95,30,1,1]},
		{"building":-1,"level":0,"rect":[66,13,1,1]},
		{"building":-1,"level":0,"rect":[66,14,1,1]},
		{"building":-1,"level":0,"rect":[66,15,1,1]},
		{"building":-1,"level":0,"rect":[66,16,1,1]},
		{"building":-1,"level":0,"rect":[66,17,1,1]},
		{"building":-1,"level":0,"rect":[66,18,1,1]},
		{"building":-1,"level":0,"rect":[66,19,1,1]},
		{"building":-1,"level":0,"rect":[66,20,1,1]},
		{"building":-1,"level":0,"rect":[66,21,1,1]},
		{"building":-1,"level":0,"rect":[66,22,1,1]},
		{"building":-1,"level":0,"rect":[66,23,1,1]},
		{"building":-1,"level":0,"rect":[66,24,1,1]},
		{"building":-1,"level":0,"rect":[66,25,1,1]},
		{"building":-1,"level":0,"rect":[66,26,1,1]},
		{"building":-1,"level":0,"rect":[66,27,1,1]},
		{"building":-1,"level":0,"rect":[66,28,1,1]},
		{"building":-1,"level":0,"rect":[66,29,1,1]},
		{"building":-1,"level":0,"rect":[95,13,1,1]},
		{"building":-1,"level":0,"rect":[95,14,1,1]},
		{"building":-1,"level":0,"rect":[95,15,1,1]},
		{"building":-1,"level":0,"rect":[95,16,1,1]},
		{"building":-1,"level":0,"rect":[95,17,1,1]},
		{"building":-1,"level":0,"rect":[95,18,1,1]},
		{"building":-1,"level":0,"rect":[95,19,1,1]},
		{"building":-1,"level":0,"rect":[95,20,1,1]},
		{"building":-1,"level":0,"rect":[95,21,1,1]},
		{"building":-1,"level":0,"rect":[95,22,1,1]},
		{"building":-1,"level":0,"rect":[95,23,1,1]},
		{"building":-1,"level":0,"rect":[95,24,1,1]},
		{"building":-1,"level":0,"rect":[95,25,1,1]},
		{"building":-1,"level":0,"rect":[95,26,1,1]},
		{"building":-1,"level":0,"rect":[95,27,1,1]},
		{"building":-1,"level":0,"rect":[95,28,1,1]},
		{"building":-1,"level":0,"rect":[95,29,1,1]},
		{"building":-1,"level":0,"rect":[5,37,1,1]},
		{"building":-1,"level":0,"rect":[6,37,1,1]},
		{"building":-1,"level":0,"rect":[7,37,1,1]},
		{"building":-1,"level":0,"rect":[8,37,1,1]},
		{"building":-1,"level":0,"rect":[9,37,1,1]},
		{"building":-1,"level":0,"rect":[10,37,1,1]},
		{"building":-1,"level":0,"rect":[11,37,1,1]},
		{"building":-1,"level":0,"rect":[12,37,1,1]},
		{"building":-1,"level":0,"rect":[21,37,1,1]},
		{"building":-1,"level":0,"rect":[22,37,1,1]},
		{"building":-1,"level":0,"rect":[23,37,1,1]},
		{"building":-1,"level":0,"rect":[24,37,1,1]},
		{"building":-1,"level":0,"rect":[25,37,1,1]},
		{"building":-1,"level":0,"rect":[26,37,1,1]},
		{"building":-1,"level":0,"rect":[27,37,1,1]},
		{"building":-1,"level":0,"rect":[28,37,1,1]},
		{"building":-1,"level":0,"rect":[5,66,1,1]},
		{"building":-1,"level":0,"rect":[26,66,1,1]},
		{"building":-1,"level":0,"rect":[27,66,1,1]},
		{"building":-1,"level":0,"rect":[28,66,1,1]},
		{"building":-1,"level":0,"rect":[5,38,1,1]},
		{"building":-1,"level":0,"rect":[5,39,1,1]},
		{"building":-1,"level":0,"rect":[5,40,1,1]},
		{"building":-1,"level":0,"rect":[5,41,1,1]},
		{"building":-1,"level":0,"rect":[5,42,1,1]},
		{"building":-1,"level":0,"rect":[5,43,1,1]},
		{"building":-1,"level":0,"rect":[5,44,1,1]},
		{"building":-1,"level":0,"rect":[5,45,1,1]},
		{"building":-1,"level":0,"rect":[5,54,1,1]},
		{"building":-1,"level":0,"rect":[5,55,1,1]},
		{"building":-1,"level":0,"rect":[5,56,1,1]},
		{"building":-1,"level":0,"rect":[5,57,1,1]},
		{"building":-1,"level":0,"rect":[5,58,1,1]},
		{"building":-1,"level":0,"rect":[5,59,1,1]},
		{"building":-1,"level":0,"rect":[5,65,1,1]},
		{"building":-1,"level":0,"rect":[36,38,1,1]},
		{"building":-1,"level":0,"rect":[36,39,1,1]},
		{"building":-1,"level":0,"rect":[36,44,1,1]},
		{"building":-1,"level":0,"rect":[36,45,1,1]},
		{"building":-1,"level":0,"rect":[36,54,1,1]},
		{"building":-1,"level":0,"rect":[36,55,1,1]},
		{"building":-1,"level":0,"rect":[36,56,1,1]},
		{"building":-1,"level":0,"rect":[36,57,1,1]},
		{"building":-1,"level":0,"rect":[36,58,1,1]},
		{"building":-1,"level":0,"rect":[36,59,1,1]},
		{"building":-1,"level":0,"rect":[36,60,1,1]},
		{"building":-1,"level":0,"rect":[36,61,1,1]},
		{"building":-1,"level":0,"rect":[36,62,1,1]},
		{"building":-1,"level":0,"rect":[36,63,1,1]},
		{"building":-1,"level":0,"rect":[36,64,1,1]},
		{"building":-1,"level":0,"rect":[36,65,1,1]},
		{"building":-1,"level":0,"rect":[0,75,1,1]},
		{"building":-1,"level":0,"rect":[1,75,1,1]},
		{"building":-1,"level":0,"rect":[2,75,1,1]},
		{"building":-1,"level":0,"rect":[3,75,1,1]},
		{"building":-1,"level":0,"rect":[4,75,1,1]},
		{"building":-1,"level":0,"rect":[5,75,1,1]},
		{"building":-1,"level":0,"rect":[6,75,1,1]},
		{"building":-1,"level":0,"rect":[7,75,1,1]},
		{"building":-1,"level":0,"rect":[8,75,1,1]},
		{"building":-1,"level":0,"rect":[9,75,1,1]},
		{"building":-1,"level":0,"rect":[10,75,1,1]},
		{"building":-1,"level":0,"rect":[11,75,1,1]},
		{"building":-1,"level":0,"rect":[16,75,1,1]},
		{"building":-1,"level":0,"rect":[17,75,1,1]},
		{"building":-1,"level":0,"rect":[18,75,1,1]},
		{"building":-1,"level":0,"rect":[19,75,1,1]},
		{"building":-1,"level":0,"rect":[20,75,1,1]},
		{"building":-1,"level":0,"rect":[21,75,1,1]},
		{"building":-1,"level":0,"rect":[22,75,1,1]},
		{"building":-1,"level":0,"rect":[23,75,1,1]},
		{"building":-1,"level":0,"rect":[24,75,1,1]},
		{"building":-1,"level":0,"rect":[25,75,1,1]},
		{"building":-1,"level":0,"rect":[26,75,1,1]},
		{"building":-1,"level":0,"rect":[27,75,1,1]},
		{"building":-1,"level":0,"rect":[28,75,1,1]},
		{"building":-1,"level":0,"rect":[0,93,1,1]},
		{"building":-1,"level":0,"rect":[1,93,1,1]},
		{"building":-1,"level":0,"rect":[2,93,1,1]},
		{"building":-1,"level":0,"rect":[3,93,1,1]},
		{"building":-1,"level":0,"rect":[26,93,1,1]},
		{"building":-1,"level":0,"rect":[27,93,1,1]},
		{"building":-1,"level":0,"rect":[28,93,1,1]},
		{"building":-1,"level":0,"rect":[0,76,1,1]},
		{"building":-1,"level":0,"rect":[0,77,1,1]},
		{"building":-1,"level":0,"rect":[0,78,1,1]},
		{"building":-1,"level":0,"rect":[0,79,1,1]},
		{"building":-1,"level":0,"rect":[0,80,1,1]},
		{"building":-1,"level":0,"rect":[0,81,1,1]},
		{"building":-1,"level":0,"rect":[0,82,1,1]},
		{"building":-1,"level":0,"rect":[0,83,1,1]},
		{"building":-1,"level":0,"rect":[0,92,1,1]},
		{"building":-1,"level":0,"rect":[28,76,1,1]},
		{"building":-1,"level":0,"rect":[28,77,1,1]},
		{"building":-1,"level":0,"rect":[28,78,1,1]},
		{"building":-1,"level":0,"rect":[28,79,1,1]},
		{"building":-1,"level":0,"rect":[28,80,1,1]},
		{"building":-1,"level":0,"rect":[28,81,1,1]},
		{"building":-1,"level":0,"rect":[28,82,1,1]},
		{"building":-1,"level":0,"rect":[28,83,1,1]},
		{"building":-1,"level":0,"rect":[28,92,1,1]},
		{"building":-1,"level":0,"rect":[28,76,1,1]},
		{"building":-1,"level":0,"rect":[29,76,1,1]},
		{"building":-1,"level":0,"rect":[30,76,1,1]},
		{"building":-1,"level":0,"rect":[31,76,1,1]},
		{"building":-1,"level":0,"rect":[32,76,1,1]},
		{"building":-1,"level":0,"rect":[33,76,1,1]},
		{"building":-1,"level":0,"rect":[34,76,1,1]},
		{"building":-1,"level":0,"rect":[35,76,1,1]},
		{"building":-1,"level":0,"rect":[44,76,1,1]},
		{"building":-1,"level":0,"rect":[45,76,1,1]},
		{"building":-1,"level":0,"rect":[46,76,1,1]},
		{"building":-1,"level":0,"rect":[47,76,1,1]},
		{"building":-1,"level":0,"rect":[60,76,1,1]},
		{"building":-1,"level":0,"rect":[61,76,1,1]},
		{"building":-1,"level":0,"rect":[62,76,1,1]},
		{"building":-1,"level":0,"rect":[63,76,1,1]},
		{"building":-1,"level":0,"rect":[64,76,1,1]},
		{"building":-1,"level":0,"rect":[65,76,1,1]},
		{"building":-1,"level":0,"rect":[66,76,1,1]},
		{"building":-1,"level":0,"rect":[67,76,1,1]},
		{"building":-1,"level":0,"rect":[68,76,1,1]},
		{"building":-1,"level":0,"rect":[69,76,1,1]},
		{"building":-1,"level":0,"rect":[28,93,1,1]},
		{"building":-1,"level":0,"rect":[29,93,1,1]},
		{"building":-1,"level":0,"rect":[30,93,1,1]},
		{"building":-1,"level":0,"rect":[31,93,1,1]},
		{"building":-1,"level":0,"rect":[32,93,1,1]},
		{"building":-1,"level":0,"rect":[33,93,1,1]},
		{"building":-1,"level":0,"rect":[58,93,1,1]},
		{"building":-1,"level":0,"rect":[59,93,1,1]},
		{"building":-1,"level":0,"rect":[60,93,1,1]},
		{"building":-1,"level":0,"rect":[61,93,1,1]},
		{"building":-1,"level":0,"rect":[28,77,1,1]},
		{"building":-1,"level":0,"rect":[28,78,1,1]},
		{"building":-1,"level":0,"rect":[28,79,1,1]},
		{"building":-1,"level":0,"rect":[28,80,1,1]},
		{"building":-1,"level":0,"rect":[28,81,1,1]},
		{"building":-1,"level":0,"rect":[28,82,1,1]},
		{"building":-1,"level":0,"rect":[28,83,1,1]},
		{"building":-1,"level":0,"rect":[28,84,1,1]},
		{"building":-1,"level":0,"rect":[69,77,1,1]},
		{"building":-1,"level":0,"rect":[69,78,1,1]},
		{"building":-1,"level":0,"rect":[69,79,1,1]},
		{"building":-1,"level":0,"rect":[69,80,1,1]},
		{"building":-1,"level":0,"rect":[69,81,1,1]},
		{"building":-1,"level":0,"rect":[107,76,1,1]},
		{"building":-1,"level":0,"rect":[108,76,1,1]},
		{"building":-1,"level":0,"rect":[109,76,1,1]},
		{"building":-1,"level":0,"rect":[110,76,1,1]},
		{"building":-1,"level":0,"rect":[111,76,1,1]},
		{"building":-1,"level":0,"rect":[112,76,1,1]},
		{"building":-1,"level":0,"rect":[113,76,1,1]},
		{"building":-1,"level":0,"rect":[114,76,1,1]},
		{"building":-1,"level":0,"rect":[123,76,1,1]},
		{"building":-1,"level":0,"rect":[124,76,1,1]},
		{"building":-1,"level":0,"rect":[125,76,1,1]},
		{"building":-1,"level":0,"rect":[126,76,1,1]},
		{"building":-1,"level":0,"rect":[127,76,1,1]},
		{"building":-1,"level":0,"rect":[128,76,1,1]},
		{"building":-1,"level":0,"rect":[129,76,1,1]},
		{"building":-1,"level":0,"rect":[130,76,1,1]},
		{"building":-1,"level":0,"rect":[131,76,1,1]},
		{"building":-1,"level":0,"rect":[107,99,1,1]},
		{"building":-1,"level":0,"rect":[108,99,1,1]},
		{"building":-1,"level":0,"rect":[109,99,1,1]},
		{"building":-1,"level":0,"rect":[110,99,1,1]},
		{"building":-1,"level":0,"rect":[111,99,1,1]},
		{"building":-1,"level":0,"rect":[112,99,1,1]},
		{"building":-1,"level":0,"rect":[113,99,1,1]},
		{"building":-1,"level":0,"rect":[114,99,1,1]},
		{"building":-1,"level":0,"rect":[123,99,1,1]},
		{"building":-1,"level":0,"rect":[124,99,1,1]},
		{"building":-1,"level":0,"rect":[125,99,1,1]},
		{"building":-1,"level":0,"rect":[126,99,1,1]},
		{"building":-1,"level":0,"rect":[127,99,1,1]},
		{"building":-1,"level":0,"rect":[128,99,1,1]},
		{"building":-1,"level":0,"rect":[129,99,1,1]},
		{"building":-1,"level":0,"rect":[130,99,1,1]},
		{"building":-1,"level":0,"rect":[131,99,1,1]},
		{"building":-1,"level":0,"rect":[107,77,1,1]},
		{"building":-1,"level":0,"rect":[107,78,1,1]},
		{"building":-1,"level":0,"rect":[107,79,1,1]},
		{"building":-1,"level":0,"rect":[107,80,1,1]},
		{"building":-1,"level":0,"rect":[107,81,1,1]},
		{"building":-1,"level":0,"rect":[107,82,1,1]},
		{"building":-1,"level":0,"rect":[107,83,1,1]},
		{"building":-1,"level":0,"rect":[107,84,1,1]},
		{"building":-1,"level":0,"rect":[107,89,1,1]},
		{"building":-1,"level":0,"rect":[107,90,1,1]},
		{"building":-1,"level":0,"rect":[107,91,1,1]},
		{"building":-1,"level":0,"rect":[107,92,1,1]},
		{"building":-1,"level":0,"rect":[107,93,1,1]},
		{"building":-1,"level":0,"rect":[107,94,1,1]},
		{"building":-1,"level":0,"rect":[107,95,1,1]},
		{"building":-1,"level":0,"rect":[107,96,1,1]},
		{"building":-1,"level":0,"rect":[107,97,1,1]},
		{"building":-1,"level":0,"rect":[107,98,1,1]},
		{"building":-1,"level":0,"rect":[131,77,1,1]},
		{"building":-1,"level":0,"rect":[131,78,1,1]},
		{"building":-1,"level":0,"rect":[131,79,1,1]},
		{"building":-1,"level":0,"rect":[131,92,1,1]},
		{"building":-1,"level":0,"rect":[131,93,1,1]},
		{"building":-1,"level":0,"rect":[131,94,1,1]},
		{"building":-1,"level":0,"rect":[131,95,1,1]},
		{"building":-1,"level":0,"rect":[131,96,1,1]},
		{"building":-1,"level":0,"rect":[131,97,1,1]},
		{"building":-1,"level":0,"rect":[131,98,1,1]}],
	"doors": [{"cell":[120,42],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[127,42],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[134,42],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[140,42],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[146,42],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[152,42],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[120,45],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[127,45],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[134,45],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[140,45],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[146,45],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[152,45],"building":0,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[116,43],"building":0,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[155,43],"building":0,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[120,42],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[127,42],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[134,42],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[140,42],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[146,42],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[152,42],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[120,45],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[127,45],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[134,45],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[140,45],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[146,45],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[152,45],"building":0,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[120,42],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[127,42],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[134,42],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[140,42],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[146,42],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[152,42],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[120,45],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[127,45],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[134,45],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[140,45],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[146,45],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[152,45],"building":0,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[120,42],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[127,42],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[134,42],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[140,42],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[146,42],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[152,42],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[120,45],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[127,45],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[134,45],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[140,45],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[146,45],"building":0,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[152,45],"building":0,"level":-1,"state":"closed","normal":[0,1],"external":false},
		{"cell":[118,64],"building":1,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[130,64],"building":1,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[118,67],"building":1,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[130,67],"building":1,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[112,65],"building":1,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[135,65],"building":1,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[118,64],"building":1,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[130,64],"building":1,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[118,67],"building":1,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[130,67],"building":1,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[118,64],"building":1,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[130,64],"building":1,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[118,67],"building":1,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[130,67],"building":1,"level":2,"state":"open","normal":[0,1],"external":false},
		{"cell":[149,63],"building":2,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[149,71],"building":2,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[152,63],"building":2,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[152,71],"building":2,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[150,58],"building":2,"level":0,"state":"open","normal":[0,-1],"external":true},
		{"cell":[150,75],"building":2,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[149,63],"building":2,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[149,71],"building":2,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[152,63],"building":2,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[152,71],"building":2,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[149,63],"building":2,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[149,71],"building":2,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[152,63],"building":2,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[152,71],"building":2,"level":2,"state":"open","normal":[1,0],"external":false},
		{"cell":[21,19],"building":3,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[24,19],"building":3,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[22,25],"building":3,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[21,19],"building":3,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[24,19],"building":3,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[77,19],"building":4,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[80,19],"building":4,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[78,12],"building":4,"level":0,"state":"open","normal":[0,-1],"external":true},
		{"cell":[78,25],"building":4,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[77,19],"building":4,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[80,19],"building":4,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[16,44],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[26,44],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[16,47],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[26,47],"building":5,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[10,45],"building":5,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[31,45],"building":5,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[16,44],"building":5,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[26,44],"building":5,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[16,47],"building":5,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[26,47],"building":5,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[16,44],"building":5,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[26,44],"building":5,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[16,47],"building":5,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[26,47],"building":5,"level":-1,"state":"open","normal":[0,1],"external":false},
		{"cell":[13,87],"building":6,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[16,87],"building":6,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[14,80],"building":6,"level":0,"state":"open","normal":[0,-1],"external":true},
		{"cell":[14,93],"building":6,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[13,87],"building":6,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[16,87],"building":6,"level":1,"state":"open","normal":[1,0],"external":false},
		{"cell":[47,41],"building":7,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[55,41],"building":7,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[63,41],"building":7,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[47,44],"building":7,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[55,44],"building":7,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[63,44],"building":7,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[42,42],"building":7,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[67,42],"building":7,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[47,41],"building":7,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[55,41],"building":7,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[63,41],"building":7,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[47,44],"building":7,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[55,44],"building":7,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[63,44],"building":7,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[79,42],"building":8,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[89,42],"building":8,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[79,45],"building":8,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[89,45],"building":8,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[74,43],"building":8,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[93,43],"building":8,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[79,42],"building":8,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[89,42],"building":8,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[79,45],"building":8,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[89,45],"building":8,"level":1,"state":"open","normal":[0,1],"external":false},
		{"cell":[79,84],"building":9,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[87,84],"building":9,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[79,87],"building":9,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[87,87],"building":9,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[74,85],"building":9,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[91,85],"building":9,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[45,19],"building":10,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[48,19],"building":10,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[46,25],"building":10,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[40,85],"building":11,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[52,85],"building":11,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[40,88],"building":11,"level":0,"state":"closed","normal":[0,1],"external":false},
		{"cell":[52,88],"building":11,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[34,86],"building":11,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[57,86],"building":11,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[13,62],"building":12,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[19,62],"building":12,"level":0,"state":"open","normal":[1,0],"external":false},
		{"cell":[6,62],"building":12,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[25,62],"building":12,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[117,84],"building":13,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[127,84],"building":13,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[117,87],"building":13,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[127,87],"building":13,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[112,85],"building":13,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[131,85],"building":13,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[66,88],"building":14,"level":0,"state":"open","normal":[0,1],"external":false},
		{"cell":[66,82],"building":14,"level":0,"state":"open","normal":[0,-1],"external":true},
		{"cell":[66,93],"building":14,"level":0,"state":"open","normal":[0,1],"external":true},
		{"cell":[84,60],"building":15,"level":0,"state":"open","normal":[-1,0],"external":true},
		{"cell":[91,60],"building":15,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[53,18],"building":10,"level":0,"state":"open","normal":[1,0],"external":true},
		{"cell":[69,90],"building":14,"level":0,"state":"open","normal":[1,0],"external":true}],
	"windows": [{"cell":[119,34],"building":0,"level":0},
		{"cell":[152,53],"building":0,"level":0},
		{"cell":[119,34],"building":0,"level":1},
		{"cell":[152,53],"building":0,"level":1},
		{"cell":[119,34],"building":0,"level":2},
		{"cell":[152,53],"building":0,"level":2},
		{"cell":[119,34],"building":0,"level":-1},
		{"cell":[152,53],"building":0,"level":-1},
		{"cell":[115,58],"building":1,"level":0},
		{"cell":[132,73],"building":1,"level":0},
		{"cell":[115,58],"building":1,"level":1},
		{"cell":[132,73],"building":1,"level":1},
		{"cell":[115,58],"building":1,"level":2},
		{"cell":[132,73],"building":1,"level":2},
		{"cell":[142,61],"building":2,"level":0},
		{"cell":[159,72],"building":2,"level":0},
		{"cell":[142,61],"building":2,"level":1},
		{"cell":[159,72],"building":2,"level":1},
		{"cell":[142,61],"building":2,"level":2},
		{"cell":[159,72],"building":2,"level":2},
		{"cell":[12,15],"building":3,"level":0},
		{"cell":[33,22],"building":3,"level":0},
		{"cell":[12,15],"building":3,"level":1},
		{"cell":[33,22],"building":3,"level":1},
		{"cell":[68,15],"building":4,"level":0},
		{"cell":[89,22],"building":4,"level":0},
		{"cell":[68,15],"building":4,"level":1},
		{"cell":[89,22],"building":4,"level":1},
		{"cell":[13,39],"building":5,"level":0},
		{"cell":[28,52],"building":5,"level":0},
		{"cell":[13,39],"building":5,"level":1},
		{"cell":[28,52],"building":5,"level":1},
		{"cell":[13,39],"building":5,"level":-1},
		{"cell":[28,52],"building":5,"level":-1},
		{"cell":[4,83],"building":6,"level":0},
		{"cell":[25,90],"building":6,"level":0},
		{"cell":[4,83],"building":6,"level":1},
		{"cell":[25,90],"building":6,"level":1},
		{"cell":[45,35],"building":7,"level":0},
		{"cell":[64,50],"building":7,"level":0},
		{"cell":[45,35],"building":7,"level":1},
		{"cell":[64,50],"building":7,"level":1},
		{"cell":[77,38],"building":8,"level":0},
		{"cell":[90,49],"building":8,"level":0},
		{"cell":[77,38],"building":8,"level":1},
		{"cell":[90,49],"building":8,"level":1},
		{"cell":[77,80],"building":9,"level":0},
		{"cell":[88,91],"building":9,"level":0},
		{"cell":[40,15],"building":10,"level":0},
		{"cell":[53,22],"building":10,"level":0},
		{"cell":[37,80],"building":11,"level":0},
		{"cell":[54,93],"building":11,"level":0},
		{"cell":[8,57],"building":12,"level":0},
		{"cell":[115,80],"building":13,"level":0},
		{"cell":[128,91],"building":13,"level":0},
		{"cell":[62,84],"building":14,"level":0},
		{"cell":[86,56],"building":15,"level":0}],
	"stairs": [{"cell":[118,43],"low":-1,"high":0,"ladder":false},
		{"cell":[118,43],"low":0,"high":1,"ladder":false},
		{"cell":[118,43],"low":1,"high":2,"ladder":false},
		{"cell":[153,44],"low":-1,"high":0,"ladder":false},
		{"cell":[153,44],"low":0,"high":1,"ladder":false},
		{"cell":[153,44],"low":1,"high":2,"ladder":false},
		{"cell":[114,65],"low":0,"high":1,"ladder":false},
		{"cell":[114,65],"low":1,"high":2,"ladder":false},
		{"cell":[133,66],"low":0,"high":1,"ladder":false},
		{"cell":[133,66],"low":1,"high":2,"ladder":false},
		{"cell":[150,60],"low":0,"high":1,"ladder":false},
		{"cell":[150,60],"low":1,"high":2,"ladder":false},
		{"cell":[151,73],"low":0,"high":1,"ladder":false},
		{"cell":[151,73],"low":1,"high":2,"ladder":false},
		{"cell":[22,14],"low":0,"high":1,"ladder":false},
		{"cell":[78,14],"low":0,"high":1,"ladder":false},
		{"cell":[12,45],"low":-1,"high":0,"ladder":false},
		{"cell":[12,45],"low":0,"high":1,"ladder":false},
		{"cell":[14,82],"low":0,"high":1,"ladder":false},
		{"cell":[44,42],"low":0,"high":1,"ladder":false},
		{"cell":[76,43],"low":0,"high":1,"ladder":false}],
	"rooms": [{"building":0,"level":0,"rect":[117,35,6,7],"use":"안방"},
		{"building":0,"level":0,"rect":[124,35,6,7],"use":"부엌"},
		{"building":0,"level":0,"rect":[131,35,6,7],"use":"안방"},
		{"building":0,"level":0,"rect":[138,35,5,7],"use":"부엌"},
		{"building":0,"level":0,"rect":[144,35,5,7],"use":"안방"},
		{"building":0,"level":0,"rect":[150,35,5,7],"use":"부엌"},
		{"building":0,"level":0,"rect":[117,46,6,7],"use":"안방"},
		{"building":0,"level":0,"rect":[124,46,6,7],"use":"부엌"},
		{"building":0,"level":0,"rect":[131,46,6,7],"use":"안방"},
		{"building":0,"level":0,"rect":[138,46,5,7],"use":"부엌"},
		{"building":0,"level":0,"rect":[144,46,5,7],"use":"안방"},
		{"building":0,"level":0,"rect":[150,46,5,7],"use":"부엌"},
		{"building":0,"level":1,"rect":[117,35,6,7],"use":"안방"},
		{"building":0,"level":1,"rect":[124,35,6,7],"use":"부엌"},
		{"building":0,"level":1,"rect":[131,35,6,7],"use":"안방"},
		{"building":0,"level":1,"rect":[138,35,5,7],"use":"부엌"},
		{"building":0,"level":1,"rect":[144,35,5,7],"use":"안방"},
		{"building":0,"level":1,"rect":[150,35,5,7],"use":"부엌"},
		{"building":0,"level":1,"rect":[117,46,6,7],"use":"안방"},
		{"building":0,"level":1,"rect":[124,46,6,7],"use":"부엌"},
		{"building":0,"level":1,"rect":[131,46,6,7],"use":"안방"},
		{"building":0,"level":1,"rect":[138,46,5,7],"use":"부엌"},
		{"building":0,"level":1,"rect":[144,46,5,7],"use":"안방"},
		{"building":0,"level":1,"rect":[150,46,5,7],"use":"부엌"},
		{"building":0,"level":2,"rect":[117,35,6,7],"use":"안방"},
		{"building":0,"level":2,"rect":[124,35,6,7],"use":"부엌"},
		{"building":0,"level":2,"rect":[131,35,6,7],"use":"안방"},
		{"building":0,"level":2,"rect":[138,35,5,7],"use":"부엌"},
		{"building":0,"level":2,"rect":[144,35,5,7],"use":"안방"},
		{"building":0,"level":2,"rect":[150,35,5,7],"use":"부엌"},
		{"building":0,"level":2,"rect":[117,46,6,7],"use":"안방"},
		{"building":0,"level":2,"rect":[124,46,6,7],"use":"부엌"},
		{"building":0,"level":2,"rect":[131,46,6,7],"use":"안방"},
		{"building":0,"level":2,"rect":[138,46,5,7],"use":"부엌"},
		{"building":0,"level":2,"rect":[144,46,5,7],"use":"안방"},
		{"building":0,"level":2,"rect":[150,46,5,7],"use":"부엌"},
		{"building":0,"level":-1,"rect":[117,35,6,7],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[124,35,6,7],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[131,35,6,7],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[138,35,5,7],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[144,35,5,7],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[150,35,5,7],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[117,46,6,7],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[124,46,6,7],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[131,46,6,7],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[138,46,5,7],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[144,46,5,7],"use":"저장 칸"},
		{"building":0,"level":-1,"rect":[150,46,5,7],"use":"저장 칸"},
		{"building":1,"level":0,"rect":[113,59,11,5],"use":"안방"},
		{"building":1,"level":0,"rect":[125,59,10,5],"use":"부엌"},
		{"building":1,"level":0,"rect":[113,68,11,5],"use":"안방"},
		{"building":1,"level":0,"rect":[125,68,10,5],"use":"부엌"},
		{"building":1,"level":1,"rect":[113,59,11,5],"use":"안방"},
		{"building":1,"level":1,"rect":[125,59,10,5],"use":"부엌"},
		{"building":1,"level":1,"rect":[113,68,11,5],"use":"안방"},
		{"building":1,"level":1,"rect":[125,68,10,5],"use":"부엌"},
		{"building":1,"level":2,"rect":[113,59,11,5],"use":"안방"},
		{"building":1,"level":2,"rect":[125,59,10,5],"use":"부엌"},
		{"building":1,"level":2,"rect":[113,68,11,5],"use":"안방"},
		{"building":1,"level":2,"rect":[125,68,10,5],"use":"부엌"},
		{"building":2,"level":0,"rect":[143,59,6,8],"use":"안방"},
		{"building":2,"level":0,"rect":[143,68,6,7],"use":"부엌"},
		{"building":2,"level":0,"rect":[153,59,6,8],"use":"안방"},
		{"building":2,"level":0,"rect":[153,68,6,7],"use":"부엌"},
		{"building":2,"level":1,"rect":[143,59,6,8],"use":"안방"},
		{"building":2,"level":1,"rect":[143,68,6,7],"use":"부엌"},
		{"building":2,"level":1,"rect":[153,59,6,8],"use":"안방"},
		{"building":2,"level":1,"rect":[153,68,6,7],"use":"부엌"},
		{"building":2,"level":2,"rect":[143,59,6,8],"use":"안방"},
		{"building":2,"level":2,"rect":[143,68,6,7],"use":"부엌"},
		{"building":2,"level":2,"rect":[153,59,6,8],"use":"안방"},
		{"building":2,"level":2,"rect":[153,68,6,7],"use":"부엌"},
		{"building":3,"level":0,"rect":[13,13,8,12],"use":"안방"},
		{"building":3,"level":0,"rect":[25,13,8,12],"use":"안방"},
		{"building":3,"level":1,"rect":[13,13,8,12],"use":"안방"},
		{"building":3,"level":1,"rect":[25,13,8,12],"use":"안방"},
		{"building":4,"level":0,"rect":[69,13,8,12],"use":"안방"},
		{"building":4,"level":0,"rect":[81,13,8,12],"use":"안방"},
		{"building":4,"level":1,"rect":[69,13,8,12],"use":"안방"},
		{"building":4,"level":1,"rect":[81,13,8,12],"use":"안방"},
		{"building":5,"level":0,"rect":[11,40,10,4],"use":"안방"},
		{"building":5,"level":0,"rect":[22,40,9,4],"use":"부엌"},
		{"building":5,"level":0,"rect":[11,48,10,4],"use":"안방"},
		{"building":5,"level":0,"rect":[22,48,9,4],"use":"부엌"},
		{"building":5,"level":1,"rect":[11,40,10,4],"use":"안방"},
		{"building":5,"level":1,"rect":[22,40,9,4],"use":"부엌"},
		{"building":5,"level":1,"rect":[11,48,10,4],"use":"안방"},
		{"building":5,"level":1,"rect":[22,48,9,4],"use":"부엌"},
		{"building":5,"level":-1,"rect":[11,40,10,4],"use":"저장 칸"},
		{"building":5,"level":-1,"rect":[22,40,9,4],"use":"저장 칸"},
		{"building":5,"level":-1,"rect":[11,48,10,4],"use":"저장 칸"},
		{"building":5,"level":-1,"rect":[22,48,9,4],"use":"저장 칸"},
		{"building":6,"level":0,"rect":[5,81,8,12],"use":"안방"},
		{"building":6,"level":0,"rect":[17,81,8,12],"use":"안방"},
		{"building":6,"level":1,"rect":[5,81,8,12],"use":"안방"},
		{"building":6,"level":1,"rect":[17,81,8,12],"use":"안방"},
		{"building":7,"level":0,"rect":[43,36,8,5],"use":"매장"},
		{"building":7,"level":0,"rect":[52,36,7,5],"use":"뒤 창고"},
		{"building":7,"level":0,"rect":[60,36,7,5],"use":"작업실"},
		{"building":7,"level":0,"rect":[43,45,8,5],"use":"매장"},
		{"building":7,"level":0,"rect":[52,45,7,5],"use":"뒤 창고"},
		{"building":7,"level":0,"rect":[60,45,7,5],"use":"작업실"},
		{"building":7,"level":1,"rect":[43,36,8,5],"use":"매장"},
		{"building":7,"level":1,"rect":[52,36,7,5],"use":"뒤 창고"},
		{"building":7,"level":1,"rect":[60,36,7,5],"use":"작업실"},
		{"building":7,"level":1,"rect":[43,45,8,5],"use":"매장"},
		{"building":7,"level":1,"rect":[52,45,7,5],"use":"뒤 창고"},
		{"building":7,"level":1,"rect":[60,45,7,5],"use":"작업실"},
		{"building":8,"level":0,"rect":[75,39,9,3],"use":"매장"},
		{"building":8,"level":0,"rect":[85,39,8,3],"use":"뒤 창고"},
		{"building":8,"level":0,"rect":[75,46,9,3],"use":"매장"},
		{"building":8,"level":0,"rect":[85,46,8,3],"use":"뒤 창고"},
		{"building":8,"level":1,"rect":[75,39,9,3],"use":"매장"},
		{"building":8,"level":1,"rect":[85,39,8,3],"use":"뒤 창고"},
		{"building":8,"level":1,"rect":[75,46,9,3],"use":"매장"},
		{"building":8,"level":1,"rect":[85,46,8,3],"use":"뒤 창고"},
		{"building":9,"level":0,"rect":[75,81,8,3],"use":"매장"},
		{"building":9,"level":0,"rect":[84,81,7,3],"use":"뒤 창고"},
		{"building":9,"level":0,"rect":[75,88,8,3],"use":"매장"},
		{"building":9,"level":0,"rect":[84,88,7,3],"use":"뒤 창고"},
		{"building":10,"level":0,"rect":[41,13,4,12],"use":"매장"},
		{"building":10,"level":0,"rect":[49,13,4,12],"use":"매장"},
		{"building":11,"level":0,"rect":[35,81,11,4],"use":"매장"},
		{"building":11,"level":0,"rect":[47,81,10,4],"use":"뒤 창고"},
		{"building":11,"level":0,"rect":[35,89,11,4],"use":"매장"},
		{"building":11,"level":0,"rect":[47,89,10,4],"use":"뒤 창고"},
		{"building":12,"level":0,"rect":[7,58,6,8],"use":"작업실"},
		{"building":12,"level":0,"rect":[14,58,5,8],"use":"뒤 창고"},
		{"building":12,"level":0,"rect":[20,58,5,8],"use":"뒤 창고"},
		{"building":13,"level":0,"rect":[113,81,9,3],"use":"매장"},
		{"building":13,"level":0,"rect":[123,81,8,3],"use":"뒤 창고"},
		{"building":13,"level":0,"rect":[113,88,9,3],"use":"매장"},
		{"building":13,"level":0,"rect":[123,88,8,3],"use":"뒤 창고"},
		{"building":14,"level":0,"rect":[63,83,6,5],"use":"작업실"},
		{"building":14,"level":0,"rect":[63,89,6,4],"use":"뒤 창고"},
		{"building":15,"level":0,"rect":[85,57,6,6],"use":"작업실"}],
	"props": [{"kind":"water","rect":[42,55,12,12],"solid":"low","facing":0,"note":"언 물","level":0},
		{"kind":"water","rect":[54,55,12,12],"solid":"low","facing":1,"note":"언 물","level":0},
		{"kind":"water","rect":[66,55,12,12],"solid":"low","facing":2,"note":"언 물","level":0},
		{"kind":"fieldstone_wall","rect":[16,34,8,1],"solid":"low","facing":0,"note":"마당의 들돌 담 토막","level":0},
		{"kind":"fieldstone_wall","rect":[32,34,8,1],"solid":"low","facing":0,"note":"마당의 들돌 담 토막","level":0},
		{"kind":"fieldstone_wall","rect":[13,37,8,1],"solid":"low","facing":0,"note":"마당의 들돌 담 토막","level":0},
		{"kind":"fieldstone_wall","rect":[29,37,8,1],"solid":"low","facing":0,"note":"마당의 들돌 담 토막","level":0},
		{"kind":"fieldstone_wall","rect":[29,66,8,1],"solid":"low","facing":0,"note":"마당의 들돌 담 토막","level":0},
		{"kind":"fieldstone_wall","rect":[5,46,1,8],"solid":"low","facing":1,"note":"마당의 들돌 담 토막","level":0},
		{"kind":"fieldstone_wall","rect":[36,46,1,8],"solid":"low","facing":1,"note":"마당의 들돌 담 토막","level":0},
		{"kind":"fieldstone_wall","rect":[0,84,1,8],"solid":"low","facing":1,"note":"마당의 들돌 담 토막","level":0},
		{"kind":"fieldstone_wall","rect":[27,84,1,8],"solid":"low","facing":1,"note":"마당의 들돌 담 토막","level":0},
		{"kind":"fieldstone_wall","rect":[36,76,8,1],"solid":"low","facing":0,"note":"마당의 들돌 담 토막","level":0},
		{"kind":"fieldstone_wall","rect":[52,76,8,1],"solid":"low","facing":0,"note":"마당의 들돌 담 토막","level":0},
		{"kind":"fieldstone_wall","rect":[29,83,1,8],"solid":"low","facing":1,"note":"마당의 들돌 담 토막","level":0},
		{"kind":"fieldstone_wall","rect":[115,76,8,1],"solid":"low","facing":0,"note":"마당의 들돌 담 토막","level":0},
		{"kind":"fieldstone_wall","rect":[115,99,8,1],"solid":"low","facing":0,"note":"마당의 들돌 담 토막","level":0},
		{"kind":"bed","rect":[117,35,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[122,41,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[117,41,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[124,35,2,2],"solid":"low","facing":0,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[129,41,1,1],"solid":"low","facing":1,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[124,41,1,1],"solid":"low","facing":2,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[131,35,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[136,41,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[131,41,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[138,35,2,2],"solid":"low","facing":0,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[142,41,1,1],"solid":"low","facing":1,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[138,41,1,1],"solid":"low","facing":2,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[144,35,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[148,41,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[144,41,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[150,35,2,2],"solid":"low","facing":0,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[154,41,1,1],"solid":"low","facing":1,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[150,41,1,1],"solid":"low","facing":2,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[117,46,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[122,52,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[117,52,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[124,46,2,2],"solid":"low","facing":0,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[129,52,1,1],"solid":"low","facing":1,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[124,52,1,1],"solid":"low","facing":2,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[131,46,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[136,52,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[131,52,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[138,46,2,2],"solid":"low","facing":0,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[142,52,1,1],"solid":"low","facing":1,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[138,52,1,1],"solid":"low","facing":2,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[144,46,2,1],"solid":"low","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[148,52,1,1],"solid":"low","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[144,52,2,1],"solid":"low","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[150,46,2,2],"solid":"low","facing":0,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[154,52,1,1],"solid":"low","facing":1,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[150,52,1,1],"solid":"low","facing":2,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[117,35,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[122,41,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[117,41,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[124,35,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[129,41,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[124,41,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[131,35,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[136,41,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[131,41,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[138,35,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[142,41,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[138,41,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[144,35,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[148,41,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[144,41,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[150,35,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[154,41,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[150,41,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[117,46,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[122,52,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[117,52,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[124,46,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[129,52,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[124,52,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[131,46,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[136,52,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[131,52,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[138,46,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[142,52,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[138,52,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[144,46,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[148,52,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[144,52,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[150,46,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[154,52,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[150,52,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[117,35,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[122,41,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[117,41,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[124,35,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[129,41,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[124,41,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[131,35,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[136,41,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[131,41,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[138,35,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[142,41,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[138,41,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[144,35,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[148,41,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[144,41,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[150,35,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[154,41,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[150,41,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[117,46,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[122,52,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[117,52,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[124,46,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[129,52,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[124,52,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[131,46,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[136,52,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[131,52,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[138,46,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[142,52,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[138,52,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[144,46,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[148,52,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[144,52,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[150,46,2,2],"solid":"none","facing":0,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[154,52,1,1],"solid":"none","facing":1,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[150,52,1,1],"solid":"none","facing":2,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"jar_shelf","rect":[117,35,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[122,41,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[117,41,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[124,35,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[129,41,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[124,41,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[131,35,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[136,41,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[131,41,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[138,35,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[142,41,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[138,41,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[144,35,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[148,41,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[144,41,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[150,35,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[154,41,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[150,41,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[117,46,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[122,52,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[117,52,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[124,46,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[129,52,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[124,52,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[131,46,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[136,52,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[131,52,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[140,52,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[138,46,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[138,52,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[146,52,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[144,46,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[144,52,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[152,52,3,1],"solid":"none","facing":0,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[150,46,1,1],"solid":"none","facing":1,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[150,52,2,1],"solid":"none","facing":2,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"bed","rect":[122,59,2,1],"solid":"low","facing":1,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[113,63,1,1],"solid":"low","facing":2,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[122,63,2,1],"solid":"low","facing":3,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[133,59,2,2],"solid":"low","facing":1,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[125,63,1,1],"solid":"low","facing":2,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[134,63,1,1],"solid":"low","facing":3,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[122,68,2,1],"solid":"low","facing":1,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[113,72,1,1],"solid":"low","facing":2,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[122,72,2,1],"solid":"low","facing":3,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[133,68,2,2],"solid":"low","facing":1,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[125,72,1,1],"solid":"low","facing":2,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[134,72,1,1],"solid":"low","facing":3,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[122,59,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[113,63,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[122,63,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[133,59,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[125,63,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[134,63,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[122,68,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[113,72,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[122,72,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[133,68,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[125,72,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[134,72,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[122,59,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[113,63,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[122,63,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[133,59,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[125,63,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[134,63,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[122,68,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[113,72,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[122,72,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[133,68,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[125,72,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[134,72,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[143,59,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[148,66,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[143,66,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[143,68,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[148,74,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[143,74,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[153,59,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[158,66,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[153,66,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[153,68,2,2],"solid":"low","facing":2,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[158,74,1,1],"solid":"low","facing":3,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[153,74,1,1],"solid":"low","facing":0,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[143,59,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[148,66,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[143,66,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[143,68,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[148,74,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[143,74,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[153,59,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[158,66,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[153,66,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[153,68,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[158,74,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[153,74,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[143,59,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[148,66,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[143,66,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[143,68,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[148,74,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[143,74,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[153,59,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":2},
		{"kind":"cold_stove","rect":[158,66,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":2},
		{"kind":"wardrobe","rect":[153,66,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":2},
		{"kind":"dining_set","rect":[153,68,2,2],"solid":"none","facing":2,"note":"부엌의 식탁과 의자","level":2},
		{"kind":"fridge_open","rect":[158,74,1,1],"solid":"none","facing":3,"note":"부엌의 문 열린 냉장고","level":2},
		{"kind":"cold_stove","rect":[153,74,1,1],"solid":"none","facing":0,"note":"부엌의 꺼진 난로","level":2},
		{"kind":"bed","rect":[19,13,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[13,24,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[19,24,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":0},
		{"kind":"bed","rect":[31,13,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[25,24,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[31,24,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":0},
		{"kind":"bed","rect":[19,13,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[13,24,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[19,24,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":1},
		{"kind":"bed","rect":[31,13,2,1],"solid":"none","facing":3,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[25,24,1,1],"solid":"none","facing":0,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[31,24,2,1],"solid":"none","facing":1,"note":"안방의 장롱","level":1},
		{"kind":"bed","rect":[69,13,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[76,24,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[69,24,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"bed","rect":[81,13,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[88,24,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[81,24,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":0},
		{"kind":"bed","rect":[69,13,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[76,24,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[69,24,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"bed","rect":[81,13,2,1],"solid":"none","facing":0,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[88,24,1,1],"solid":"none","facing":1,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[81,24,2,1],"solid":"none","facing":2,"note":"안방의 장롱","level":1},
		{"kind":"bed","rect":[19,40,2,1],"solid":"low","facing":1,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[11,43,1,1],"solid":"low","facing":2,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[19,43,2,1],"solid":"low","facing":3,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[29,40,2,2],"solid":"low","facing":1,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[22,43,1,1],"solid":"low","facing":2,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[30,43,1,1],"solid":"low","facing":3,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[19,48,2,1],"solid":"low","facing":1,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[11,51,1,1],"solid":"low","facing":2,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[19,51,2,1],"solid":"low","facing":3,"note":"안방의 장롱","level":0},
		{"kind":"dining_set","rect":[29,48,2,2],"solid":"low","facing":1,"note":"부엌의 식탁과 의자","level":0},
		{"kind":"fridge_open","rect":[22,51,1,1],"solid":"low","facing":2,"note":"부엌의 문 열린 냉장고","level":0},
		{"kind":"cold_stove","rect":[30,51,1,1],"solid":"low","facing":3,"note":"부엌의 꺼진 난로","level":0},
		{"kind":"bed","rect":[19,40,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[11,43,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[19,43,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[29,40,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[22,43,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[30,43,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"bed","rect":[19,48,2,1],"solid":"none","facing":1,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[11,51,1,1],"solid":"none","facing":2,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[19,51,2,1],"solid":"none","facing":3,"note":"안방의 장롱","level":1},
		{"kind":"dining_set","rect":[29,48,2,2],"solid":"none","facing":1,"note":"부엌의 식탁과 의자","level":1},
		{"kind":"fridge_open","rect":[22,51,1,1],"solid":"none","facing":2,"note":"부엌의 문 열린 냉장고","level":1},
		{"kind":"cold_stove","rect":[30,51,1,1],"solid":"none","facing":3,"note":"부엌의 꺼진 난로","level":1},
		{"kind":"jar_shelf","rect":[18,40,3,1],"solid":"none","facing":1,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[11,43,1,1],"solid":"none","facing":2,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[19,43,2,1],"solid":"none","facing":3,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[28,40,3,1],"solid":"none","facing":1,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[22,43,1,1],"solid":"none","facing":2,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[29,43,2,1],"solid":"none","facing":3,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[18,48,3,1],"solid":"none","facing":1,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[11,51,1,1],"solid":"none","facing":2,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[19,51,2,1],"solid":"none","facing":3,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"jar_shelf","rect":[28,48,3,1],"solid":"none","facing":1,"note":"저장 칸의 병조림 선반","level":-1},
		{"kind":"barrel","rect":[22,51,1,1],"solid":"none","facing":2,"note":"저장 칸의 통","level":-1},
		{"kind":"tin_crate","rect":[29,51,2,1],"solid":"none","facing":3,"note":"저장 칸의 통조림 상자","level":-1},
		{"kind":"bed","rect":[5,81,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[12,92,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[5,92,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"bed","rect":[17,81,2,1],"solid":"low","facing":2,"note":"안방의 침대","level":0},
		{"kind":"cold_stove","rect":[24,92,1,1],"solid":"low","facing":3,"note":"안방의 꺼진 난로","level":0},
		{"kind":"wardrobe","rect":[17,92,2,1],"solid":"low","facing":0,"note":"안방의 장롱","level":0},
		{"kind":"bed","rect":[5,81,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[12,92,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[5,92,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"bed","rect":[17,81,2,1],"solid":"none","facing":2,"note":"안방의 침대","level":1},
		{"kind":"cold_stove","rect":[24,92,1,1],"solid":"none","facing":3,"note":"안방의 꺼진 난로","level":1},
		{"kind":"wardrobe","rect":[17,92,2,1],"solid":"none","facing":0,"note":"안방의 장롱","level":1},
		{"kind":"bench","rect":[48,36,3,1],"solid":"low","facing":3,"note":"매장의 긴 의자","level":0},
		{"kind":"shop_counter","rect":[43,40,3,1],"solid":"low","facing":0,"note":"매장의 가게 계산대","level":0},
		{"kind":"cold_stove","rect":[50,40,1,1],"solid":"low","facing":1,"note":"매장의 꺼진 난로","level":0},
		{"kind":"bench","rect":[56,36,3,1],"solid":"low","facing":3,"note":"뒤 창고의 긴 의자","level":0},
		{"kind":"desk","rect":[52,40,2,1],"solid":"low","facing":0,"note":"뒤 창고의 책상","level":0},
		{"kind":"cold_stove","rect":[58,40,1,1],"solid":"low","facing":1,"note":"뒤 창고의 꺼진 난로","level":0},
		{"kind":"desk","rect":[65,36,2,1],"solid":"low","facing":3,"note":"작업실의 책상","level":0},
		{"kind":"cold_stove","rect":[60,40,1,1],"solid":"low","facing":0,"note":"작업실의 꺼진 난로","level":0},
		{"kind":"bench","rect":[64,40,3,1],"solid":"low","facing":1,"note":"작업실의 긴 의자","level":0},
		{"kind":"bench","rect":[48,45,3,1],"solid":"low","facing":3,"note":"매장의 긴 의자","level":0},
		{"kind":"desk","rect":[43,49,2,1],"solid":"low","facing":0,"note":"매장의 책상","level":0},
		{"kind":"cold_stove","rect":[50,49,1,1],"solid":"low","facing":1,"note":"매장의 꺼진 난로","level":0},
		{"kind":"bench","rect":[56,45,3,1],"solid":"low","facing":3,"note":"뒤 창고의 긴 의자","level":0},
		{"kind":"desk","rect":[52,49,2,1],"solid":"low","facing":0,"note":"뒤 창고의 책상","level":0},
		{"kind":"cold_stove","rect":[58,49,1,1],"solid":"low","facing":1,"note":"뒤 창고의 꺼진 난로","level":0},
		{"kind":"desk","rect":[65,45,2,1],"solid":"low","facing":3,"note":"작업실의 책상","level":0},
		{"kind":"cold_stove","rect":[60,49,1,1],"solid":"low","facing":0,"note":"작업실의 꺼진 난로","level":0},
		{"kind":"bench","rect":[64,49,3,1],"solid":"low","facing":1,"note":"작업실의 긴 의자","level":0},
		{"kind":"bed","rect":[49,36,2,1],"solid":"none","facing":3,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[43,40,1,1],"solid":"none","facing":0,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[49,40,2,1],"solid":"none","facing":1,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[57,36,2,1],"solid":"none","facing":3,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[52,40,1,1],"solid":"none","facing":0,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[57,40,2,1],"solid":"none","facing":1,"note":"뒤 창고의 장롱","level":1},
		{"kind":"fridge_open","rect":[66,36,1,1],"solid":"none","facing":3,"note":"작업실의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[60,40,2,1],"solid":"none","facing":0,"note":"작업실의 장롱","level":1},
		{"kind":"bed","rect":[65,40,2,1],"solid":"none","facing":1,"note":"작업실의 침대","level":1},
		{"kind":"bed","rect":[49,45,2,1],"solid":"none","facing":3,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[43,49,1,1],"solid":"none","facing":0,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[49,49,2,1],"solid":"none","facing":1,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[57,45,2,1],"solid":"none","facing":3,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[52,49,1,1],"solid":"none","facing":0,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[57,49,2,1],"solid":"none","facing":1,"note":"뒤 창고의 장롱","level":1},
		{"kind":"fridge_open","rect":[66,45,1,1],"solid":"none","facing":3,"note":"작업실의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[60,49,2,1],"solid":"none","facing":0,"note":"작업실의 장롱","level":1},
		{"kind":"bed","rect":[65,49,2,1],"solid":"none","facing":1,"note":"작업실의 침대","level":1},
		{"kind":"display_shelf","rect":[75,39,4,1],"solid":"low","facing":0,"note":"매장의 진열대","level":0},
		{"kind":"shop_counter","rect":[81,41,3,1],"solid":"low","facing":1,"note":"매장의 가게 계산대","level":0},
		{"kind":"shelf","rect":[75,41,3,1],"solid":"low","facing":2,"note":"매장의 선반","level":0},
		{"kind":"display_shelf","rect":[85,39,4,1],"solid":"low","facing":0,"note":"뒤 창고의 진열대","level":0},
		{"kind":"shelf","rect":[90,41,3,1],"solid":"low","facing":1,"note":"뒤 창고의 선반","level":0},
		{"kind":"shelf","rect":[85,41,3,1],"solid":"low","facing":2,"note":"뒤 창고의 선반","level":0},
		{"kind":"display_shelf","rect":[75,46,4,1],"solid":"low","facing":0,"note":"매장의 진열대","level":0},
		{"kind":"shelf","rect":[81,48,3,1],"solid":"low","facing":1,"note":"매장의 선반","level":0},
		{"kind":"shelf","rect":[75,48,3,1],"solid":"low","facing":2,"note":"매장의 선반","level":0},
		{"kind":"display_shelf","rect":[85,46,4,1],"solid":"low","facing":0,"note":"뒤 창고의 진열대","level":0},
		{"kind":"shelf","rect":[90,48,3,1],"solid":"low","facing":1,"note":"뒤 창고의 선반","level":0},
		{"kind":"shelf","rect":[85,48,3,1],"solid":"low","facing":2,"note":"뒤 창고의 선반","level":0},
		{"kind":"bed","rect":[75,39,2,1],"solid":"none","facing":0,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[83,41,1,1],"solid":"none","facing":1,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[75,41,2,1],"solid":"none","facing":2,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[85,39,2,1],"solid":"none","facing":0,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[92,41,1,1],"solid":"none","facing":1,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[85,41,2,1],"solid":"none","facing":2,"note":"뒤 창고의 장롱","level":1},
		{"kind":"bed","rect":[75,46,2,1],"solid":"none","facing":0,"note":"매장의 침대","level":1},
		{"kind":"fridge_open","rect":[83,48,1,1],"solid":"none","facing":1,"note":"매장의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[75,48,2,1],"solid":"none","facing":2,"note":"매장의 장롱","level":1},
		{"kind":"bed","rect":[85,46,2,1],"solid":"none","facing":0,"note":"뒤 창고의 침대","level":1},
		{"kind":"fridge_open","rect":[92,48,1,1],"solid":"none","facing":1,"note":"뒤 창고의 문 열린 냉장고","level":1},
		{"kind":"wardrobe","rect":[85,48,2,1],"solid":"none","facing":2,"note":"뒤 창고의 장롱","level":1},
		{"kind":"anvil_block","rect":[82,81,1,1],"solid":"low","facing":1,"note":"매장의 모루","level":0},
		{"kind":"barrel","rect":[75,83,1,1],"solid":"low","facing":2,"note":"매장의 통","level":0},
		{"kind":"firewood_pile","rect":[81,83,2,1],"solid":"low","facing":3,"note":"매장의 장작 더미","level":0},
		{"kind":"anvil_block","rect":[90,81,1,1],"solid":"low","facing":1,"note":"뒤 창고의 모루","level":0},
		{"kind":"barrel","rect":[84,83,1,1],"solid":"low","facing":2,"note":"뒤 창고의 통","level":0},
		{"kind":"firewood_pile","rect":[89,83,2,1],"solid":"low","facing":3,"note":"뒤 창고의 장작 더미","level":0},
		{"kind":"anvil_block","rect":[82,88,1,1],"solid":"low","facing":1,"note":"매장의 모루","level":0},
		{"kind":"barrel","rect":[75,90,1,1],"solid":"low","facing":2,"note":"매장의 통","level":0},
		{"kind":"firewood_pile","rect":[81,90,2,1],"solid":"low","facing":3,"note":"매장의 장작 더미","level":0},
		{"kind":"anvil_block","rect":[90,88,1,1],"solid":"low","facing":1,"note":"뒤 창고의 모루","level":0},
		{"kind":"barrel","rect":[84,90,1,1],"solid":"low","facing":2,"note":"뒤 창고의 통","level":0},
		{"kind":"firewood_pile","rect":[89,90,2,1],"solid":"low","facing":3,"note":"뒤 창고의 장작 더미","level":0},
		{"kind":"shelf","rect":[41,13,3,1],"solid":"none","facing":2,"note":"매장의 선반","level":0},
		{"kind":"desk","rect":[43,24,2,1],"solid":"none","facing":3,"note":"매장의 책상","level":0},
		{"kind":"crate_stack","rect":[41,23,2,2],"solid":"none","facing":0,"note":"매장의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[49,13,3,1],"solid":"none","facing":2,"note":"매장의 선반","level":0},
		{"kind":"desk","rect":[51,24,2,1],"solid":"none","facing":3,"note":"매장의 책상","level":0},
		{"kind":"crate_stack","rect":[49,23,2,2],"solid":"none","facing":0,"note":"매장의 나무 상자 더미","level":0},
		{"kind":"sack_pile","rect":[44,81,2,2],"solid":"low","facing":3,"note":"매장의 자루 더미","level":0},
		{"kind":"firewood_pile","rect":[35,84,2,1],"solid":"low","facing":0,"note":"매장의 장작 더미","level":0},
		{"kind":"hay_cart","rect":[42,83,4,2],"solid":"low","facing":1,"note":"매장의 건초 수레","level":0},
		{"kind":"sack_pile","rect":[55,81,2,2],"solid":"low","facing":3,"note":"뒤 창고의 자루 더미","level":0},
		{"kind":"firewood_pile","rect":[47,84,2,1],"solid":"low","facing":0,"note":"뒤 창고의 장작 더미","level":0},
		{"kind":"hay_cart","rect":[53,83,4,2],"solid":"low","facing":1,"note":"뒤 창고의 건초 수레","level":0},
		{"kind":"sack_pile","rect":[44,89,2,2],"solid":"low","facing":3,"note":"매장의 자루 더미","level":0},
		{"kind":"firewood_pile","rect":[35,92,2,1],"solid":"low","facing":0,"note":"매장의 장작 더미","level":0},
		{"kind":"hay_cart","rect":[42,91,4,2],"solid":"low","facing":1,"note":"매장의 건초 수레","level":0},
		{"kind":"sack_pile","rect":[55,89,2,2],"solid":"low","facing":3,"note":"뒤 창고의 자루 더미","level":0},
		{"kind":"firewood_pile","rect":[47,92,2,1],"solid":"low","facing":0,"note":"뒤 창고의 장작 더미","level":0},
		{"kind":"hay_cart","rect":[53,91,4,2],"solid":"low","facing":1,"note":"뒤 창고의 건초 수레","level":0},
		{"kind":"desk","rect":[7,58,2,1],"solid":"low","facing":0,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[11,64,2,2],"solid":"low","facing":1,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[7,65,3,1],"solid":"low","facing":2,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[14,58,3,1],"solid":"low","facing":0,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[17,65,2,1],"solid":"low","facing":1,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[14,64,2,2],"solid":"low","facing":2,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[20,58,3,1],"solid":"low","facing":0,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[23,65,2,1],"solid":"low","facing":1,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[20,64,2,2],"solid":"low","facing":2,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[119,81,3,1],"solid":"low","facing":1,"note":"매장의 선반","level":0},
		{"kind":"desk","rect":[113,83,2,1],"solid":"low","facing":2,"note":"매장의 책상","level":0},
		{"kind":"crate_stack","rect":[120,82,2,2],"solid":"low","facing":3,"note":"매장의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[128,81,3,1],"solid":"low","facing":1,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[123,83,2,1],"solid":"low","facing":2,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[129,82,2,2],"solid":"low","facing":3,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[119,88,3,1],"solid":"low","facing":1,"note":"매장의 선반","level":0},
		{"kind":"desk","rect":[113,90,2,1],"solid":"low","facing":2,"note":"매장의 책상","level":0},
		{"kind":"crate_stack","rect":[120,89,2,2],"solid":"low","facing":3,"note":"매장의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[128,88,3,1],"solid":"low","facing":1,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[123,90,2,1],"solid":"low","facing":2,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[129,89,2,2],"solid":"low","facing":3,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"desk","rect":[63,83,2,1],"solid":"low","facing":2,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[67,86,2,2],"solid":"low","facing":3,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[63,87,3,1],"solid":"low","facing":0,"note":"작업실의 선반","level":0},
		{"kind":"shelf","rect":[63,89,3,1],"solid":"low","facing":2,"note":"뒤 창고의 선반","level":0},
		{"kind":"desk","rect":[67,92,2,1],"solid":"low","facing":3,"note":"뒤 창고의 책상","level":0},
		{"kind":"crate_stack","rect":[63,91,2,2],"solid":"low","facing":0,"note":"뒤 창고의 나무 상자 더미","level":0},
		{"kind":"desk","rect":[89,57,2,1],"solid":"low","facing":3,"note":"작업실의 책상","level":0},
		{"kind":"crate_stack","rect":[85,61,2,2],"solid":"low","facing":0,"note":"작업실의 나무 상자 더미","level":0},
		{"kind":"shelf","rect":[88,62,3,1],"solid":"low","facing":1,"note":"작업실의 선반","level":0},
		{"kind":"car","rect":[34,12,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
		{"kind":"bench","rect":[56,10,1,3],"solid":"low","facing":1,"note":"긴 의자","level":0},
		{"kind":"car","rect":[54,26,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
		{"kind":"crate_stack","rect":[64,26,2,2],"solid":"low","facing":0,"note":"나무 상자 더미","level":0},
		{"kind":"car","rect":[0,26,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
		{"kind":"door_pile","rect":[116,31,2,1],"solid":"low","facing":2,"note":"문짝 더미","level":0},
		{"kind":"firewood_pile","rect":[121,30,2,1],"solid":"low","facing":3,"note":"장작 더미","level":0},
		{"kind":"handcart","rect":[125,32,2,1],"solid":"low","facing":0,"note":"손수레","level":0},
		{"kind":"door_pile","rect":[142,55,2,1],"solid":"low","facing":1,"note":"문짝 더미","level":0},
		{"kind":"door_pile","rect":[68,9,2,1],"solid":"none","facing":2,"note":"문짝 더미","level":0},
		{"kind":"firewood_pile","rect":[73,8,2,1],"solid":"none","facing":3,"note":"장작 더미","level":0},
		{"kind":"door_pile","rect":[74,77,2,1],"solid":"low","facing":0,"note":"문짝 더미","level":0},
		{"kind":"firewood_pile","rect":[79,76,2,1],"solid":"low","facing":1,"note":"장작 더미","level":0},
		{"kind":"handcart","rect":[83,78,2,1],"solid":"low","facing":2,"note":"손수레","level":0},
		{"kind":"well_cover","rect":[87,67,2,2],"solid":"low","facing":3,"note":"우물 뚜껑","level":0},
		{"kind":"bench","rect":[92,66,3,1],"solid":"low","facing":0,"note":"긴 의자","level":0},
		{"kind":"barrel","rect":[85,68,1,1],"solid":"low","facing":1,"note":"통","level":0},
		{"kind":"barrel","rect":[91,68,1,1],"solid":"low","facing":2,"note":"통","level":0},
		{"kind":"fieldstone_wall","rect":[4,35,8,1],"solid":"low","facing":3,"note":"들돌 담","level":0},
		{"kind":"fieldstone_wall","rect":[19,35,8,1],"solid":"low","facing":0,"note":"들돌 담","level":0},
		{"kind":"fieldstone_wall","rect":[4,96,8,1],"solid":"low","facing":1,"note":"들돌 담","level":0},
		{"kind":"fieldstone_wall","rect":[17,96,8,1],"solid":"low","facing":2,"note":"들돌 담","level":0},
		{"kind":"fieldstone_wall","rect":[36,94,8,1],"solid":"low","facing":3,"note":"들돌 담","level":0},
		{"kind":"fieldstone_wall","rect":[47,94,8,1],"solid":"low","facing":0,"note":"들돌 담","level":0},
		{"kind":"firewood_pile","rect":[59,94,2,1],"solid":"low","facing":1,"note":"장작 더미","level":0},
		{"kind":"firewood_pile","rect":[59,97,2,1],"solid":"low","facing":2,"note":"장작 더미","level":0},
		{"kind":"firewood_pile","rect":[71,94,2,1],"solid":"low","facing":3,"note":"장작 더미","level":0},
		{"kind":"firewood_pile","rect":[71,97,2,1],"solid":"low","facing":0,"note":"장작 더미","level":0},
		{"kind":"firewood_pile","rect":[75,94,2,1],"solid":"low","facing":1,"note":"장작 더미","level":0},
		{"kind":"firewood_pile","rect":[75,97,2,1],"solid":"low","facing":2,"note":"장작 더미","level":0},
		{"kind":"lamp_post","rect":[104,51,1,1],"solid":"none","facing":3,"note":"꺼진 등잔","level":0},
		{"kind":"crate_stack","rect":[105,53,2,2],"solid":"low","facing":0,"note":"나무 상자 더미","level":0},
		{"kind":"lamp_post","rect":[72,37,1,1],"solid":"none","facing":1,"note":"꺼진 등잔","level":0},
		{"kind":"crate_stack","rect":[37,63,2,2],"solid":"low","facing":2,"note":"나무 상자 더미","level":0},
		{"kind":"bare_orchard_tree","rect":[56,15,1,1],"solid":"tree","facing":3,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[57,21,1,1],"solid":"tree","facing":0,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[29,27,1,1],"solid":"tree","facing":1,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[121,28,1,1],"solid":"tree","facing":2,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[150,28,1,1],"solid":"tree","facing":3,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[126,29,1,1],"solid":"tree","facing":0,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[155,29,1,1],"solid":"tree","facing":1,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[30,33,1,1],"solid":"tree","facing":2,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[6,34,1,1],"solid":"tree","facing":3,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[69,35,1,1],"solid":"tree","facing":0,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[98,35,1,1],"solid":"tree","facing":1,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[156,35,1,1],"solid":"tree","facing":2,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[74,36,1,1],"solid":"tree","facing":3,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[99,41,1,1],"solid":"tree","facing":0,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[105,48,1,1],"solid":"tree","facing":1,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[29,56,1,1],"solid":"tree","facing":2,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[98,64,1,1],"solid":"tree","facing":3,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[60,68,1,1],"solid":"tree","facing":0,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[89,68,1,1],"solid":"tree","facing":1,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[7,69,1,1],"solid":"tree","facing":2,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[36,69,1,1],"solid":"tree","facing":3,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[65,69,1,1],"solid":"tree","facing":0,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[94,69,1,1],"solid":"tree","facing":1,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[109,72,1,1],"solid":"tree","facing":2,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[138,72,1,1],"solid":"tree","facing":3,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[37,75,1,1],"solid":"tree","facing":0,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[66,75,1,1],"solid":"tree","facing":1,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[95,75,1,1],"solid":"tree","facing":2,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[71,76,1,1],"solid":"tree","facing":3,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[47,77,1,1],"solid":"tree","facing":0,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[105,77,1,1],"solid":"tree","facing":1,"note":"마른 과수","level":0},
		{"kind":"bare_orchard_tree","rect":[110,78,1,1],"solid":"tree","facing":2,"note":"마른 과수","level":0}],
	"containers": [{"id":"cache_0","name":"안방 상자","cell":[121,41],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_1","name":"부엌 상자","cell":[128,41],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_2","name":"안방 상자","cell":[135,41],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_3","name":"부엌 상자","cell":[141,41],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_4","name":"안방 상자","cell":[147,41],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_5","name":"부엌 상자","cell":[153,41],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_6","name":"안방 상자","cell":[121,52],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_7","name":"부엌 상자","cell":[128,52],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_8","name":"안방 상자","cell":[135,52],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_9","name":"부엌 상자","cell":[141,52],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_10","name":"안방 상자","cell":[147,52],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_11","name":"부엌 상자","cell":[153,52],"level":0,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_12","name":"안방 상자","cell":[121,41],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_13","name":"부엌 상자","cell":[128,41],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_14","name":"안방 상자","cell":[135,41],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_15","name":"부엌 상자","cell":[141,41],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_16","name":"안방 상자","cell":[147,41],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_17","name":"부엌 상자","cell":[153,41],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_18","name":"안방 상자","cell":[121,52],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_19","name":"부엌 상자","cell":[128,52],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_20","name":"안방 상자","cell":[135,52],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_21","name":"부엌 상자","cell":[141,52],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_22","name":"안방 상자","cell":[147,52],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_23","name":"부엌 상자","cell":[153,52],"level":1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_24","name":"안방 상자","cell":[121,41],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_25","name":"부엌 상자","cell":[128,41],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_26","name":"안방 상자","cell":[135,41],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_27","name":"부엌 상자","cell":[141,41],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_28","name":"안방 상자","cell":[147,41],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_29","name":"부엌 상자","cell":[153,41],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_30","name":"안방 상자","cell":[121,52],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_31","name":"부엌 상자","cell":[128,52],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_32","name":"안방 상자","cell":[135,52],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_33","name":"부엌 상자","cell":[141,52],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_34","name":"안방 상자","cell":[147,52],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_35","name":"부엌 상자","cell":[153,52],"level":2,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_36","name":"저장 칸 상자","cell":[121,41],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_37","name":"저장 칸 상자","cell":[128,41],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_38","name":"저장 칸 상자","cell":[135,41],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_39","name":"저장 칸 상자","cell":[141,41],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_40","name":"저장 칸 상자","cell":[147,41],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_41","name":"저장 칸 상자","cell":[153,41],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_42","name":"저장 칸 상자","cell":[121,52],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_43","name":"저장 칸 상자","cell":[128,52],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_44","name":"저장 칸 상자","cell":[135,52],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_45","name":"저장 칸 상자","cell":[142,51],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_46","name":"저장 칸 상자","cell":[148,51],"level":-1,"building":0,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_47","name":"안쪽 저장 상자","cell":[154,51],"level":-1,"building":0,"search":4,"items":["plank","plank","plank","plank"],"locked":true,"searched":false},
		{"id":"cache_48","name":"안방 상자","cell":[121,63],"level":0,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_49","name":"부엌 상자","cell":[133,63],"level":0,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_50","name":"안방 상자","cell":[121,72],"level":0,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_51","name":"부엌 상자","cell":[133,72],"level":0,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_52","name":"안방 상자","cell":[121,63],"level":1,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_53","name":"부엌 상자","cell":[133,63],"level":1,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_54","name":"안방 상자","cell":[121,72],"level":1,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_55","name":"부엌 상자","cell":[133,72],"level":1,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_56","name":"안방 상자","cell":[121,63],"level":2,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_57","name":"부엌 상자","cell":[133,63],"level":2,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_58","name":"안방 상자","cell":[121,72],"level":2,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_59","name":"부엌 상자","cell":[133,72],"level":2,"building":1,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_60","name":"안방 상자","cell":[147,66],"level":0,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_61","name":"부엌 상자","cell":[147,74],"level":0,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_62","name":"안방 상자","cell":[157,66],"level":0,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_63","name":"부엌 상자","cell":[157,74],"level":0,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_64","name":"안방 상자","cell":[147,66],"level":1,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_65","name":"부엌 상자","cell":[147,74],"level":1,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_66","name":"안방 상자","cell":[157,66],"level":1,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_67","name":"부엌 상자","cell":[157,74],"level":1,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_68","name":"안방 상자","cell":[147,66],"level":2,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_69","name":"부엌 상자","cell":[147,74],"level":2,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_70","name":"안방 상자","cell":[157,66],"level":2,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_71","name":"부엌 상자","cell":[157,74],"level":2,"building":2,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_72","name":"안방 상자","cell":[18,24],"level":0,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_73","name":"안방 상자","cell":[30,24],"level":0,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_74","name":"안방 상자","cell":[18,24],"level":1,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_75","name":"안방 상자","cell":[30,24],"level":1,"building":3,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_76","name":"안방 상자","cell":[75,24],"level":0,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_77","name":"안방 상자","cell":[87,24],"level":0,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_78","name":"안방 상자","cell":[75,24],"level":1,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_79","name":"안방 상자","cell":[87,24],"level":1,"building":4,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_80","name":"안방 상자","cell":[18,43],"level":0,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_81","name":"부엌 상자","cell":[29,43],"level":0,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_82","name":"안방 상자","cell":[18,51],"level":0,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_83","name":"부엌 상자","cell":[29,51],"level":0,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_84","name":"안방 상자","cell":[18,43],"level":1,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_85","name":"부엌 상자","cell":[29,43],"level":1,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_86","name":"안방 상자","cell":[18,51],"level":1,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_87","name":"부엌 상자","cell":[29,51],"level":1,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_88","name":"저장 칸 상자","cell":[18,43],"level":-1,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_89","name":"저장 칸 상자","cell":[28,43],"level":-1,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_90","name":"저장 칸 상자","cell":[18,51],"level":-1,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_91","name":"저장 칸 상자","cell":[28,51],"level":-1,"building":5,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_92","name":"안방 상자","cell":[11,92],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_93","name":"안방 상자","cell":[23,92],"level":0,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_94","name":"안방 상자","cell":[11,92],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_95","name":"안방 상자","cell":[23,92],"level":1,"building":6,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_96","name":"매장 상자","cell":[49,40],"level":0,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_97","name":"뒤 창고 상자","cell":[57,40],"level":0,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_98","name":"작업실 상자","cell":[62,40],"level":0,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_99","name":"매장 상자","cell":[49,49],"level":0,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_100","name":"뒤 창고 상자","cell":[57,49],"level":0,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_101","name":"작업실 상자","cell":[63,49],"level":0,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_102","name":"매장 상자","cell":[48,40],"level":1,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_103","name":"뒤 창고 상자","cell":[56,40],"level":1,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_104","name":"작업실 상자","cell":[64,40],"level":1,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_105","name":"매장 상자","cell":[48,49],"level":1,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_106","name":"뒤 창고 상자","cell":[56,49],"level":1,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_107","name":"작업실 상자","cell":[64,49],"level":1,"building":7,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_108","name":"매장 상자","cell":[80,41],"level":0,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_109","name":"뒤 창고 상자","cell":[88,41],"level":0,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_110","name":"매장 상자","cell":[80,48],"level":0,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_111","name":"뒤 창고 상자","cell":[88,48],"level":0,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_112","name":"매장 상자","cell":[82,41],"level":1,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_113","name":"뒤 창고 상자","cell":[91,41],"level":1,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_114","name":"매장 상자","cell":[82,48],"level":1,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_115","name":"뒤 창고 상자","cell":[91,48],"level":1,"building":8,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_116","name":"매장 상자","cell":[80,83],"level":0,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_117","name":"뒤 창고 상자","cell":[88,83],"level":0,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_118","name":"매장 상자","cell":[80,90],"level":0,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_119","name":"뒤 창고 상자","cell":[88,90],"level":0,"building":9,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_120","name":"매장 상자","cell":[44,23],"level":0,"building":10,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_121","name":"매장 상자","cell":[52,23],"level":0,"building":10,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_122","name":"매장 상자","cell":[41,84],"level":0,"building":11,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_123","name":"뒤 창고 상자","cell":[51,84],"level":0,"building":11,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_124","name":"먼 끝 저장 상자","cell":[41,92],"level":0,"building":11,"search":4,"items":["plank","plank","plank","plank"],"locked":true,"searched":false},
		{"id":"cache_125","name":"뒤 창고 상자","cell":[52,92],"level":0,"building":11,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_126","name":"작업실 상자","cell":[10,65],"level":0,"building":12,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_127","name":"뒤 창고 상자","cell":[16,65],"level":0,"building":12,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_128","name":"뒤 창고 상자","cell":[22,65],"level":0,"building":12,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_129","name":"매장 상자","cell":[119,83],"level":0,"building":13,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_130","name":"뒤 창고 상자","cell":[128,83],"level":0,"building":13,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_131","name":"매장 상자","cell":[119,90],"level":0,"building":13,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_132","name":"뒤 창고 상자","cell":[128,90],"level":0,"building":13,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_133","name":"작업실 상자","cell":[65,86],"level":0,"building":14,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_134","name":"뒤 창고 상자","cell":[65,92],"level":0,"building":14,"search":4,"items":["plank"],"locked":false,"searched":false},
		{"id":"cache_135","name":"작업실 상자","cell":[87,62],"level":0,"building":15,"search":4,"items":["plank"],"locked":false,"searched":false}],
	"spots": [{"id":"salvage_0","kind":"salvage","name":"남은 목재","cell":[121,41],"material":"wood","amount":2,"state":"intact"},
		{"id":"salvage_1","kind":"salvage","name":"남은 목재","cell":[128,41],"material":"wood","amount":2,"state":"intact"}],
	"slots": ["C","G"],
	"dead": [[0,70],[98,99],[164,44],[164,16],[102,52],[70,38],[34,62]],
	"forecourts": [{"cell":[116,43],"normal":[-1,0],"cells":[[115,45],[115,44],[115,43],[115,42],[115,41],[114,45],[114,44],[114,43],[114,42],[114,41],[113,45],[113,44],[113,43],[113,42],[113,41],[112,45],[112,44],[112,43],[112,42],[112,41]],"building":0},
		{"cell":[155,43],"normal":[1,0],"cells":[[156,41],[156,42],[156,43],[156,44],[156,45],[157,41],[157,42],[157,43],[157,44],[157,45],[158,41],[158,42],[158,43],[158,44],[158,45],[159,41],[159,42],[159,43],[159,44],[159,45]],"building":0},
		{"cell":[112,65],"normal":[-1,0],"cells":[[111,67],[111,66],[111,65],[111,64],[111,63],[110,67],[110,66],[110,65],[110,64],[110,63],[109,67],[109,66],[109,65],[109,64],[109,63],[108,67],[108,66],[108,65],[108,64],[108,63]],"building":1},
		{"cell":[135,65],"normal":[1,0],"cells":[[136,63],[136,64],[136,65],[136,66],[136,67],[137,63],[137,64],[137,65],[137,66],[137,67],[138,63],[138,64],[138,65],[138,66],[138,67],[139,63],[139,64],[139,65],[139,66],[139,67]],"building":1},
		{"cell":[150,58],"normal":[0,-1],"cells":[[148,57],[149,57],[150,57],[151,57],[152,57],[148,56],[149,56],[150,56],[151,56],[152,56],[148,55],[149,55],[150,55],[151,55],[152,55],[148,54],[149,54],[150,54],[151,54],[152,54]],"building":2},
		{"cell":[150,75],"normal":[0,1],"cells":[[152,76],[151,76],[150,76],[149,76],[148,76],[152,77],[151,77],[150,77],[149,77],[148,77],[152,78],[151,78],[150,78],[149,78],[148,78],[152,79],[151,79],[150,79],[149,79],[148,79]],"building":2},
		{"cell":[22,25],"normal":[0,1],"cells":[[24,26],[23,26],[22,26],[21,26],[20,26],[24,27],[23,27],[22,27],[21,27],[20,27],[24,28],[23,28],[22,28],[21,28],[20,28],[24,29],[23,29],[22,29],[21,29],[20,29]],"building":3},
		{"cell":[78,12],"normal":[0,-1],"cells":[[76,11],[77,11],[78,11],[79,11],[80,11],[76,10],[77,10],[78,10],[79,10],[80,10],[76,9],[77,9],[78,9],[79,9],[80,9],[76,8],[77,8],[78,8],[79,8],[80,8]],"building":4},
		{"cell":[78,25],"normal":[0,1],"cells":[[80,26],[79,26],[78,26],[77,26],[76,26],[80,27],[79,27],[78,27],[77,27],[76,27],[80,28],[79,28],[78,28],[77,28],[76,28],[80,29],[79,29],[78,29],[77,29],[76,29]],"building":4},
		{"cell":[10,45],"normal":[-1,0],"cells":[[9,47],[9,46],[9,45],[9,44],[9,43],[8,47],[8,46],[8,45],[8,44],[8,43],[7,47],[7,46],[7,45],[7,44],[7,43],[6,47],[6,46],[6,45],[6,44],[6,43]],"building":5},
		{"cell":[31,45],"normal":[1,0],"cells":[[32,43],[32,44],[32,45],[32,46],[32,47],[33,43],[33,44],[33,45],[33,46],[33,47],[34,43],[34,44],[34,45],[34,46],[34,47],[35,43],[35,44],[35,45],[35,46],[35,47]],"building":5},
		{"cell":[14,80],"normal":[0,-1],"cells":[[12,79],[13,79],[14,79],[15,79],[16,79],[12,78],[13,78],[14,78],[15,78],[16,78],[12,77],[13,77],[14,77],[15,77],[16,77],[12,76],[13,76],[14,76],[15,76],[16,76]],"building":6},
		{"cell":[14,93],"normal":[0,1],"cells":[[16,94],[15,94],[14,94],[13,94],[12,94],[16,95],[15,95],[14,95],[13,95],[12,95],[16,96],[15,96],[14,96],[13,96],[12,96],[16,97],[15,97],[14,97],[13,97],[12,97]],"building":6},
		{"cell":[42,42],"normal":[-1,0],"cells":[[41,44],[41,43],[41,42],[41,41],[41,40],[40,44],[40,43],[40,42],[40,41],[40,40],[39,44],[39,43],[39,42],[39,41],[39,40],[38,44],[38,43],[38,42],[38,41],[38,40]],"building":7},
		{"cell":[67,42],"normal":[1,0],"cells":[[68,40],[68,41],[68,42],[68,43],[68,44],[69,40],[69,41],[69,42],[69,43],[69,44],[70,40],[70,41],[70,42],[70,43],[70,44],[71,40],[71,41],[71,42],[71,43],[71,44]],"building":7},
		{"cell":[74,43],"normal":[-1,0],"cells":[[73,45],[73,44],[73,43],[73,42],[73,41],[72,45],[72,44],[72,43],[72,42],[72,41],[71,45],[71,44],[71,43],[71,42],[71,41],[70,45],[70,44],[70,43],[70,42],[70,41]],"building":8},
		{"cell":[93,43],"normal":[1,0],"cells":[[94,41],[94,42],[94,43],[94,44],[94,45],[95,41],[95,42],[95,43],[95,44],[95,45],[96,41],[96,42],[96,43],[96,44],[96,45],[97,41],[97,42],[97,43],[97,44],[97,45]],"building":8},
		{"cell":[74,85],"normal":[-1,0],"cells":[[73,87],[73,86],[73,85],[73,84],[73,83],[72,87],[72,86],[72,85],[72,84],[72,83],[71,87],[71,86],[71,85],[71,84],[71,83],[70,87],[70,86],[70,85],[70,84],[70,83]],"building":9},
		{"cell":[91,85],"normal":[1,0],"cells":[[92,83],[92,84],[92,85],[92,86],[92,87],[93,83],[93,84],[93,85],[93,86],[93,87],[94,83],[94,84],[94,85],[94,86],[94,87],[95,83],[95,84],[95,85],[95,86],[95,87]],"building":9},
		{"cell":[46,25],"normal":[0,1],"cells":[[48,26],[47,26],[46,26],[45,26],[44,26],[48,27],[47,27],[46,27],[45,27],[44,27],[48,28],[47,28],[46,28],[45,28],[44,28],[48,29],[47,29],[46,29],[45,29],[44,29]],"building":10},
		{"cell":[34,86],"normal":[-1,0],"cells":[[33,88],[33,87],[33,86],[33,85],[33,84],[32,88],[32,87],[32,86],[32,85],[32,84],[31,88],[31,87],[31,86],[31,85],[31,84],[30,88],[30,87],[30,86],[30,85],[30,84]],"building":11},
		{"cell":[57,86],"normal":[1,0],"cells":[[58,84],[58,85],[58,86],[58,87],[58,88],[59,84],[59,85],[59,86],[59,87],[59,88],[60,84],[60,85],[60,86],[60,87],[60,88],[61,84],[61,85],[61,86],[61,87],[61,88]],"building":11},
		{"cell":[6,62],"normal":[-1,0],"cells":[[5,64],[5,63],[5,62],[5,61],[5,60],[4,64],[4,63],[4,62],[4,61],[4,60],[3,64],[3,63],[3,62],[3,61],[3,60],[2,64],[2,63],[2,62],[2,61],[2,60]],"building":12},
		{"cell":[25,62],"normal":[1,0],"cells":[[26,60],[26,61],[26,62],[26,63],[26,64],[27,60],[27,61],[27,62],[27,63],[27,64],[28,60],[28,61],[28,62],[28,63],[28,64],[29,60],[29,61],[29,62],[29,63],[29,64]],"building":12},
		{"cell":[112,85],"normal":[-1,0],"cells":[[111,87],[111,86],[111,85],[111,84],[111,83],[110,87],[110,86],[110,85],[110,84],[110,83],[109,87],[109,86],[109,85],[109,84],[109,83],[108,87],[108,86],[108,85],[108,84],[108,83]],"building":13},
		{"cell":[131,85],"normal":[1,0],"cells":[[132,83],[132,84],[132,85],[132,86],[132,87],[133,83],[133,84],[133,85],[133,86],[133,87],[134,83],[134,84],[134,85],[134,86],[134,87],[135,83],[135,84],[135,85],[135,86],[135,87]],"building":13},
		{"cell":[66,82],"normal":[0,-1],"cells":[[64,81],[65,81],[66,81],[67,81],[68,81],[64,80],[65,80],[66,80],[67,80],[68,80],[64,79],[65,79],[66,79],[67,79],[68,79],[64,78],[65,78],[66,78],[67,78],[68,78]],"building":14},
		{"cell":[66,93],"normal":[0,1],"cells":[[68,94],[67,94],[66,94],[65,94],[64,94],[68,95],[67,95],[66,95],[65,95],[64,95],[68,96],[67,96],[66,96],[65,96],[64,96],[68,97],[67,97],[66,97],[65,97],[64,97]],"building":14},
		{"cell":[84,60],"normal":[-1,0],"cells":[[83,62],[83,61],[83,60],[83,59],[83,58],[82,62],[82,61],[82,60],[82,59],[82,58],[81,62],[81,61],[81,60],[81,59],[81,58],[80,62],[80,61],[80,60],[80,59],[80,58]],"building":15},
		{"cell":[91,60],"normal":[1,0],"cells":[[92,58],[92,59],[92,60],[92,61],[92,62],[93,58],[93,59],[93,60],[93,61],[93,62],[94,58],[94,59],[94,60],[94,61],[94,62],[95,58],[95,59],[95,60],[95,61],[95,62]],"building":15},
		{"cell":[53,18],"normal":[1,0],"cells":[[54,16],[54,17],[54,18],[54,19],[54,20],[55,16],[55,17],[55,18],[55,19],[55,20],[56,16],[56,17],[56,18],[56,19],[56,20],[57,16],[57,17],[57,18],[57,19],[57,20]],"building":10},
		{"cell":[69,90],"normal":[1,0],"cells":[[70,88],[70,89],[70,90],[70,91],[70,92],[71,88],[71,89],[71,90],[71,91],[71,92],[72,88],[72,89],[72,90],[72,91],[72,92],[73,88],[73,89],[73,90],[73,91],[73,92]],"building":14}],
	"logs": ["snow_drifts_2"],
	"courtyards": [{"rect":[8,10,46,25],"gate":[53,28,1,4],"escape":[]},
		{"rect":[66,12,30,19],"gate":[77,30,4,1],"escape":[]},
		{"rect":[5,37,32,30],"gate":[36,40,1,4],"escape":[[5,60],[5,61],[5,62],[5,63],[5,64]]},
		{"rect":[0,75,29,19],"gate":[12,75,4,1],"escape":[]},
		{"rect":[28,76,42,18],"gate":[48,76,4,1],"escape":[]},
		{"rect":[107,76,25,24],"gate":[107,85,1,4],"escape":[]}],
	"deep": [{"cell":[154,51],"level":-1,"id":"cache_47","distance":120},
		{"cell":[41,92],"level":0,"id":"cache_124","distance":153}]
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
	"number": 3,
	"width": 165,
	"height": 46,
	"judgment": "담요와 천을 얻는 대신 아래쪽 농가 마당의 장작을 놓치고, 층층 꺾인 길을 들어갔다 나오는 걸음이 길다.",
	"zones": [
		{
			"id": "I",
			"name": "방직 마을",
			"rect": [
				0,
				0,
				99,
				46
			]
		},
		{
			"id": "J",
			"name": "눈 덮인 과수밭",
			"rect": [
				99,
				0,
				17,
				46
			]
		},
		{
			"id": "K",
			"name": "동쪽 곳간",
			"rect": [
				116,
				0,
				49,
				46
			]
		}
	],
	"grounds": [
		{
			"rect": [
				10,
				0,
				5,
				9
			],
			"floor": 1
		},
		{
			"rect": [
				10,
				4,
				47,
				5
			],
			"floor": 1
		},
		{
			"rect": [
				52,
				4,
				6,
				39
			],
			"floor": 1
		},
		{
			"rect": [
				58,
				11,
				51,
				4
			],
			"floor": 1
		},
		{
			"rect": [
				104,
				11,
				5,
				10
			],
			"floor": 1
		},
		{
			"rect": [
				104,
				16,
				61,
				5
			],
			"floor": 1
		},
		{
			"rect": [
				118,
				0,
				4,
				16
			],
			"floor": 1
		},
		{
			"rect": [
				146,
				12,
				4,
				4
			],
			"floor": 1
		},
		{
			"rect": [
				72,
				15,
				4,
				28
			],
			"floor": 1
		},
		{
			"rect": [
				14,
				9,
				6,
				15
			],
			"floor": 7
		},
		{
			"rect": [
				99,
				21,
				17,
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
		},
		{
			"rect": [
				138,
				20,
				4,
				26
			],
			"floor": 7
		}
	],
	"buildings": [
		{
			"id": 16,
			"name": "방직 공방",
			"rect": [
				58,
				0,
				30,
				10
			],
			"top": 3,
			"basement": true,
			"role": "store",
			"stock": [
				"loom",
				"blanket_crate",
				"cloth_bolt_rack",
				"desk"
			]
		},
		{
			"id": 17,
			"name": "우물 정자",
			"rect": [
				92,
				2,
				8,
				8
			],
			"top": 1,
			"basement": false,
			"role": "store",
			"stock": [
				"barrel",
				"bench",
				"shelf"
			]
		},
		{
			"id": 18,
			"name": "농가",
			"rect": [
				22,
				12,
				18,
				12
			],
			"top": 2,
			"basement": true,
			"role": "home",
			"stock": [
				"loom",
				"blanket_crate",
				"cloth_bolt_rack",
				"desk"
			]
		},
		{
			"id": 19,
			"name": "헛간",
			"rect": [
				40,
				14,
				12,
				10
			],
			"top": 1,
			"basement": false,
			"role": "store",
			"stock": [
				"loom",
				"blanket_crate",
				"cloth_bolt_rack",
				"desk"
			]
		},
		{
			"id": 20,
			"name": "잡화 가게",
			"rect": [
				58,
				15,
				14,
				9
			],
			"top": 2,
			"basement": false,
			"role": "shop",
			"stock": [
				"cloth_bolt_rack",
				"blanket_crate",
				"shelf"
			]
		},
		{
			"id": 21,
			"name": "직조 창고",
			"rect": [
				76,
				16,
				13,
				8
			],
			"top": 1,
			"basement": false,
			"role": "store",
			"stock": [
				"loom",
				"blanket_crate",
				"cloth_bolt_rack",
				"desk"
			]
		},
		{
			"id": 22,
			"name": "작은 집",
			"rect": [
				89,
				16,
				10,
				8
			],
			"top": 2,
			"basement": false,
			"role": "home",
			"stock": [
				"loom",
				"blanket_crate",
				"cloth_bolt_rack",
				"desk"
			]
		},
		{
			"id": 23,
			"name": "외딴 곳간 농가",
			"rect": [
				140,
				0,
				20,
				12
			],
			"top": 2,
			"basement": true,
			"role": "store",
			"stock": [
				"blanket_crate",
				"cloth_bolt_rack",
				"jar_shelf"
			]
		},
		{
			"id": 24,
			"name": "외양간",
			"rect": [
				116,
				27,
				18,
				12
			],
			"top": 1,
			"basement": false,
			"role": "store",
			"stock": [
				"sack_pile",
				"barrel",
				"shelf"
			]
		}
	],
	"shells": [
		{
			"rect": [
				58,
				0,
				30,
				10
			],
			"building": 16,
			"level": -1
		},
		{
			"rect": [
				58,
				0,
				30,
				10
			],
			"building": 16,
			"level": 0
		},
		{
			"rect": [
				58,
				0,
				30,
				10
			],
			"building": 16,
			"level": 1
		},
		{
			"rect": [
				58,
				0,
				30,
				10
			],
			"building": 16,
			"level": 2
		},
		{
			"rect": [
				92,
				2,
				8,
				8
			],
			"building": 17,
			"level": 0
		},
		{
			"rect": [
				22,
				12,
				18,
				12
			],
			"building": 18,
			"level": -1
		},
		{
			"rect": [
				22,
				12,
				18,
				12
			],
			"building": 18,
			"level": 0
		},
		{
			"rect": [
				22,
				12,
				18,
				12
			],
			"building": 18,
			"level": 1
		},
		{
			"rect": [
				40,
				14,
				12,
				10
			],
			"building": 19,
			"level": 0
		},
		{
			"rect": [
				58,
				15,
				14,
				9
			],
			"building": 20,
			"level": 0
		},
		{
			"rect": [
				58,
				15,
				14,
				9
			],
			"building": 20,
			"level": 1
		},
		{
			"rect": [
				76,
				16,
				13,
				8
			],
			"building": 21,
			"level": 0
		},
		{
			"rect": [
				89,
				16,
				10,
				8
			],
			"building": 22,
			"level": 0
		},
		{
			"rect": [
				89,
				16,
				10,
				8
			],
			"building": 22,
			"level": 1
		},
		{
			"rect": [
				140,
				0,
				20,
				12
			],
			"building": 23,
			"level": -1
		},
		{
			"rect": [
				140,
				0,
				20,
				12
			],
			"building": 23,
			"level": 0
		},
		{
			"rect": [
				140,
				0,
				20,
				12
			],
			"building": 23,
			"level": 1
		},
		{
			"rect": [
				116,
				27,
				18,
				12
			],
			"building": 24,
			"level": 0
		}
	],
	"walls": [
		{
			"rect": [
				59,
				6,
				28,
				1
			],
			"level": -1
		},
		{
			"rect": [
				63,
				1,
				1,
				5
			],
			"level": -1
		},
		{
			"rect": [
				68,
				1,
				1,
				5
			],
			"level": -1
		},
		{
			"rect": [
				73,
				1,
				1,
				5
			],
			"level": -1
		},
		{
			"rect": [
				78,
				1,
				1,
				5
			],
			"level": -1
		},
		{
			"rect": [
				83,
				1,
				1,
				5
			],
			"level": -1
		},
		{
			"rect": [
				59,
				6,
				28,
				1
			],
			"level": 0
		},
		{
			"rect": [
				63,
				1,
				1,
				5
			],
			"level": 0
		},
		{
			"rect": [
				68,
				1,
				1,
				5
			],
			"level": 0
		},
		{
			"rect": [
				73,
				1,
				1,
				5
			],
			"level": 0
		},
		{
			"rect": [
				78,
				1,
				1,
				5
			],
			"level": 0
		},
		{
			"rect": [
				83,
				1,
				1,
				5
			],
			"level": 0
		},
		{
			"rect": [
				59,
				6,
				28,
				1
			],
			"level": 1
		},
		{
			"rect": [
				63,
				1,
				1,
				5
			],
			"level": 1
		},
		{
			"rect": [
				68,
				1,
				1,
				5
			],
			"level": 1
		},
		{
			"rect": [
				73,
				1,
				1,
				5
			],
			"level": 1
		},
		{
			"rect": [
				78,
				1,
				1,
				5
			],
			"level": 1
		},
		{
			"rect": [
				83,
				1,
				1,
				5
			],
			"level": 1
		},
		{
			"rect": [
				59,
				6,
				28,
				1
			],
			"level": 2
		},
		{
			"rect": [
				63,
				1,
				1,
				5
			],
			"level": 2
		},
		{
			"rect": [
				68,
				1,
				1,
				5
			],
			"level": 2
		},
		{
			"rect": [
				73,
				1,
				1,
				5
			],
			"level": 2
		},
		{
			"rect": [
				78,
				1,
				1,
				5
			],
			"level": 2
		},
		{
			"rect": [
				83,
				1,
				1,
				5
			],
			"level": 2
		},
		{
			"rect": [
				23,
				20,
				16,
				1
			],
			"level": -1
		},
		{
			"rect": [
				31,
				13,
				1,
				7
			],
			"level": -1
		},
		{
			"rect": [
				23,
				20,
				16,
				1
			],
			"level": 0
		},
		{
			"rect": [
				31,
				13,
				1,
				7
			],
			"level": 0
		},
		{
			"rect": [
				23,
				20,
				16,
				1
			],
			"level": 1
		},
		{
			"rect": [
				31,
				13,
				1,
				7
			],
			"level": 1
		},
		{
			"rect": [
				41,
				20,
				10,
				1
			],
			"level": 0
		},
		{
			"rect": [
				46,
				15,
				1,
				5
			],
			"level": 0
		},
		{
			"rect": [
				59,
				19,
				12,
				1
			],
			"level": 0
		},
		{
			"rect": [
				59,
				19,
				12,
				1
			],
			"level": 1
		},
		{
			"rect": [
				77,
				20,
				11,
				1
			],
			"level": 0
		},
		{
			"rect": [
				82,
				17,
				1,
				3
			],
			"level": 0
		},
		{
			"rect": [
				90,
				20,
				8,
				1
			],
			"level": 0
		},
		{
			"rect": [
				94,
				17,
				1,
				3
			],
			"level": 0
		},
		{
			"rect": [
				90,
				20,
				8,
				1
			],
			"level": 1
		},
		{
			"rect": [
				94,
				17,
				1,
				3
			],
			"level": 1
		},
		{
			"rect": [
				141,
				8,
				18,
				1
			],
			"level": -1
		},
		{
			"rect": [
				150,
				1,
				1,
				7
			],
			"level": -1
		},
		{
			"rect": [
				141,
				8,
				18,
				1
			],
			"level": 0
		},
		{
			"rect": [
				150,
				1,
				1,
				7
			],
			"level": 0
		},
		{
			"rect": [
				141,
				8,
				18,
				1
			],
			"level": 1
		},
		{
			"rect": [
				150,
				1,
				1,
				7
			],
			"level": 1
		},
		{
			"rect": [
				117,
				35,
				16,
				1
			],
			"level": 0
		},
		{
			"rect": [
				125,
				28,
				1,
				7
			],
			"level": 0
		}
	],
	"doors": [
		{
			"cell": [
				61,
				6
			],
			"level": -1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				66,
				6
			],
			"level": -1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				71,
				6
			],
			"level": -1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				76,
				6
			],
			"level": -1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				81,
				6
			],
			"level": -1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				85,
				6
			],
			"level": -1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				61,
				6
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				66,
				6
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				71,
				6
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				76,
				6
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				81,
				6
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				85,
				6
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				73,
				9
			],
			"level": 0,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				61,
				6
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				66,
				6
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				71,
				6
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				76,
				6
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				81,
				6
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				85,
				6
			],
			"level": 1,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				61,
				6
			],
			"level": 2,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				66,
				6
			],
			"level": 2,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				71,
				6
			],
			"level": 2,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				76,
				6
			],
			"level": 2,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				81,
				6
			],
			"level": 2,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				85,
				6
			],
			"level": 2,
			"building": 16,
			"state": "closed"
		},
		{
			"cell": [
				96,
				9
			],
			"level": 0,
			"building": 17,
			"state": "closed"
		},
		{
			"cell": [
				27,
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
				27,
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
				31,
				23
			],
			"level": 0,
			"building": 18,
			"state": "closed"
		},
		{
			"cell": [
				27,
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
				43,
				20
			],
			"level": 0,
			"building": 19,
			"state": "closed"
		},
		{
			"cell": [
				49,
				20
			],
			"level": 0,
			"building": 19,
			"state": "closed"
		},
		{
			"cell": [
				46,
				23
			],
			"level": 0,
			"building": 19,
			"state": "closed"
		},
		{
			"cell": [
				65,
				19
			],
			"level": 0,
			"building": 20,
			"state": "closed"
		},
		{
			"cell": [
				65,
				23
			],
			"level": 0,
			"building": 20,
			"state": "closed"
		},
		{
			"cell": [
				65,
				15
			],
			"level": 0,
			"building": 20,
			"state": "closed"
		},
		{
			"cell": [
				65,
				19
			],
			"level": 1,
			"building": 20,
			"state": "closed"
		},
		{
			"cell": [
				79,
				20
			],
			"level": 0,
			"building": 21,
			"state": "closed"
		},
		{
			"cell": [
				85,
				20
			],
			"level": 0,
			"building": 21,
			"state": "closed"
		},
		{
			"cell": [
				82,
				23
			],
			"level": 0,
			"building": 21,
			"state": "closed"
		},
		{
			"cell": [
				92,
				20
			],
			"level": 0,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				96,
				20
			],
			"level": 0,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				94,
				23
			],
			"level": 0,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				92,
				20
			],
			"level": 1,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				96,
				20
			],
			"level": 1,
			"building": 22,
			"state": "closed"
		},
		{
			"cell": [
				145,
				8
			],
			"level": -1,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				155,
				8
			],
			"level": -1,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				145,
				8
			],
			"level": 0,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				155,
				8
			],
			"level": 0,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				150,
				11
			],
			"level": 0,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				145,
				8
			],
			"level": 1,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				155,
				8
			],
			"level": 1,
			"building": 23,
			"state": "closed"
		},
		{
			"cell": [
				121,
				35
			],
			"level": 0,
			"building": 24,
			"state": "closed"
		},
		{
			"cell": [
				129,
				35
			],
			"level": 0,
			"building": 24,
			"state": "closed"
		},
		{
			"cell": [
				125,
				38
			],
			"level": 0,
			"building": 24,
			"state": "closed"
		}
	],
	"windows": [
		{
			"cell": [
				61,
				0
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				66,
				0
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				71,
				0
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				76,
				0
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				81,
				0
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				85,
				0
			],
			"level": 0,
			"building": 16
		},
		{
			"cell": [
				96,
				2
			],
			"level": 0,
			"building": 17
		},
		{
			"cell": [
				27,
				12
			],
			"level": 0,
			"building": 18
		},
		{
			"cell": [
				35,
				12
			],
			"level": 0,
			"building": 18
		},
		{
			"cell": [
				43,
				14
			],
			"level": 0,
			"building": 19
		},
		{
			"cell": [
				49,
				14
			],
			"level": 0,
			"building": 19
		},
		{
			"cell": [
				79,
				16
			],
			"level": 0,
			"building": 21
		},
		{
			"cell": [
				85,
				16
			],
			"level": 0,
			"building": 21
		},
		{
			"cell": [
				92,
				16
			],
			"level": 0,
			"building": 22
		},
		{
			"cell": [
				96,
				16
			],
			"level": 0,
			"building": 22
		},
		{
			"cell": [
				145,
				0
			],
			"level": 0,
			"building": 23
		},
		{
			"cell": [
				155,
				0
			],
			"level": 0,
			"building": 23
		},
		{
			"cell": [
				121,
				27
			],
			"level": 0,
			"building": 24
		},
		{
			"cell": [
				129,
				27
			],
			"level": 0,
			"building": 24
		}
	],
	"stairs": [
		{
			"cell": [
				60,
				7
			],
			"low": -1,
			"high": 0
		},
		{
			"cell": [
				60,
				7
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				60,
				7
			],
			"low": 1,
			"high": 2
		},
		{
			"cell": [
				85,
				7
			],
			"low": -1,
			"high": 0
		},
		{
			"cell": [
				85,
				7
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				85,
				7
			],
			"low": 1,
			"high": 2
		},
		{
			"cell": [
				24,
				21
			],
			"low": -1,
			"high": 0
		},
		{
			"cell": [
				24,
				21
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				69,
				17
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				91,
				21
			],
			"low": 0,
			"high": 1
		},
		{
			"cell": [
				142,
				9
			],
			"low": -1,
			"high": 0
		},
		{
			"cell": [
				142,
				9
			],
			"low": 0,
			"high": 1
		}
	],
	"rooms": [
		{
			"rect": [
				59,
				1,
				4,
				5
			],
			"building": 16,
			"level": -1,
			"use": "입고 방"
		},
		{
			"rect": [
				64,
				1,
				4,
				5
			],
			"building": 16,
			"level": -1,
			"use": "비축 방"
		},
		{
			"rect": [
				69,
				1,
				4,
				5
			],
			"building": 16,
			"level": -1,
			"use": "작업 방"
		},
		{
			"rect": [
				74,
				1,
				4,
				5
			],
			"building": 16,
			"level": -1,
			"use": "접수 방"
		},
		{
			"rect": [
				79,
				1,
				4,
				5
			],
			"building": 16,
			"level": -1,
			"use": "보관 방"
		},
		{
			"rect": [
				84,
				1,
				3,
				5
			],
			"building": 16,
			"level": -1,
			"use": "안쪽 광"
		},
		{
			"rect": [
				59,
				1,
				4,
				5
			],
			"building": 16,
			"level": 0,
			"use": "입고 방"
		},
		{
			"rect": [
				64,
				1,
				4,
				5
			],
			"building": 16,
			"level": 0,
			"use": "비축 방"
		},
		{
			"rect": [
				69,
				1,
				4,
				5
			],
			"building": 16,
			"level": 0,
			"use": "작업 방"
		},
		{
			"rect": [
				74,
				1,
				4,
				5
			],
			"building": 16,
			"level": 0,
			"use": "접수 방"
		},
		{
			"rect": [
				79,
				1,
				4,
				5
			],
			"building": 16,
			"level": 0,
			"use": "보관 방"
		},
		{
			"rect": [
				84,
				1,
				3,
				5
			],
			"building": 16,
			"level": 0,
			"use": "안쪽 광"
		},
		{
			"rect": [
				59,
				1,
				4,
				5
			],
			"building": 16,
			"level": 1,
			"use": "입고 방"
		},
		{
			"rect": [
				64,
				1,
				4,
				5
			],
			"building": 16,
			"level": 1,
			"use": "비축 방"
		},
		{
			"rect": [
				69,
				1,
				4,
				5
			],
			"building": 16,
			"level": 1,
			"use": "작업 방"
		},
		{
			"rect": [
				74,
				1,
				4,
				5
			],
			"building": 16,
			"level": 1,
			"use": "접수 방"
		},
		{
			"rect": [
				79,
				1,
				4,
				5
			],
			"building": 16,
			"level": 1,
			"use": "보관 방"
		},
		{
			"rect": [
				84,
				1,
				3,
				5
			],
			"building": 16,
			"level": 1,
			"use": "안쪽 광"
		},
		{
			"rect": [
				59,
				1,
				4,
				5
			],
			"building": 16,
			"level": 2,
			"use": "입고 방"
		},
		{
			"rect": [
				64,
				1,
				4,
				5
			],
			"building": 16,
			"level": 2,
			"use": "비축 방"
		},
		{
			"rect": [
				69,
				1,
				4,
				5
			],
			"building": 16,
			"level": 2,
			"use": "작업 방"
		},
		{
			"rect": [
				74,
				1,
				4,
				5
			],
			"building": 16,
			"level": 2,
			"use": "접수 방"
		},
		{
			"rect": [
				79,
				1,
				4,
				5
			],
			"building": 16,
			"level": 2,
			"use": "보관 방"
		},
		{
			"rect": [
				84,
				1,
				3,
				5
			],
			"building": 16,
			"level": 2,
			"use": "안쪽 광"
		},
		{
			"rect": [
				93,
				3,
				6,
				6
			],
			"building": 17,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				23,
				13,
				8,
				7
			],
			"building": 18,
			"level": -1,
			"use": "살림방"
		},
		{
			"rect": [
				32,
				13,
				7,
				7
			],
			"building": 18,
			"level": -1,
			"use": "부엌"
		},
		{
			"rect": [
				23,
				13,
				8,
				7
			],
			"building": 18,
			"level": 0,
			"use": "살림방"
		},
		{
			"rect": [
				32,
				13,
				7,
				7
			],
			"building": 18,
			"level": 0,
			"use": "부엌"
		},
		{
			"rect": [
				23,
				13,
				8,
				7
			],
			"building": 18,
			"level": 1,
			"use": "살림방"
		},
		{
			"rect": [
				32,
				13,
				7,
				7
			],
			"building": 18,
			"level": 1,
			"use": "부엌"
		},
		{
			"rect": [
				41,
				15,
				5,
				5
			],
			"building": 19,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				47,
				15,
				4,
				5
			],
			"building": 19,
			"level": 0,
			"use": "보관 칸"
		},
		{
			"rect": [
				59,
				16,
				12,
				3
			],
			"building": 20,
			"level": 0,
			"use": "뒤 창고"
		},
		{
			"rect": [
				59,
				20,
				12,
				3
			],
			"building": 20,
			"level": 0,
			"use": "매장"
		},
		{
			"rect": [
				59,
				16,
				12,
				3
			],
			"building": 20,
			"level": 1,
			"use": "뒤 창고"
		},
		{
			"rect": [
				59,
				20,
				12,
				3
			],
			"building": 20,
			"level": 1,
			"use": "매장"
		},
		{
			"rect": [
				77,
				17,
				5,
				3
			],
			"building": 21,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				83,
				17,
				5,
				3
			],
			"building": 21,
			"level": 0,
			"use": "보관 칸"
		},
		{
			"rect": [
				90,
				17,
				4,
				3
			],
			"building": 22,
			"level": 0,
			"use": "살림방"
		},
		{
			"rect": [
				95,
				17,
				3,
				3
			],
			"building": 22,
			"level": 0,
			"use": "부엌"
		},
		{
			"rect": [
				90,
				17,
				4,
				3
			],
			"building": 22,
			"level": 1,
			"use": "살림방"
		},
		{
			"rect": [
				95,
				17,
				3,
				3
			],
			"building": 22,
			"level": 1,
			"use": "부엌"
		},
		{
			"rect": [
				141,
				1,
				9,
				7
			],
			"building": 23,
			"level": -1,
			"use": "작업 칸"
		},
		{
			"rect": [
				151,
				1,
				8,
				7
			],
			"building": 23,
			"level": -1,
			"use": "보관 칸"
		},
		{
			"rect": [
				141,
				1,
				9,
				7
			],
			"building": 23,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				151,
				1,
				8,
				7
			],
			"building": 23,
			"level": 0,
			"use": "보관 칸"
		},
		{
			"rect": [
				141,
				1,
				9,
				7
			],
			"building": 23,
			"level": 1,
			"use": "작업 칸"
		},
		{
			"rect": [
				151,
				1,
				8,
				7
			],
			"building": 23,
			"level": 1,
			"use": "보관 칸"
		},
		{
			"rect": [
				117,
				28,
				8,
				7
			],
			"building": 24,
			"level": 0,
			"use": "작업 칸"
		},
		{
			"rect": [
				126,
				28,
				7,
				7
			],
			"building": 24,
			"level": 0,
			"use": "보관 칸"
		}
	],
	"props": [
		{
			"kind": "loom",
			"rect": [
				59,
				1,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 입고 방의 베틀",
			"level": -1
		},
		{
			"kind": "blanket_crate",
			"rect": [
				59,
				5,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 입고 방의 담요 상자",
			"level": -1
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				59,
				4,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 입고 방의 천 두루마리 선반",
			"level": -1
		},
		{
			"kind": "loom",
			"rect": [
				64,
				1,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 비축 방의 베틀",
			"level": -1
		},
		{
			"kind": "blanket_crate",
			"rect": [
				64,
				5,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 비축 방의 담요 상자",
			"level": -1
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				64,
				4,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 비축 방의 천 두루마리 선반",
			"level": -1
		},
		{
			"kind": "loom",
			"rect": [
				69,
				1,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 작업 방의 베틀",
			"level": -1
		},
		{
			"kind": "blanket_crate",
			"rect": [
				69,
				5,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 작업 방의 담요 상자",
			"level": -1
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				69,
				4,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 작업 방의 천 두루마리 선반",
			"level": -1
		},
		{
			"kind": "loom",
			"rect": [
				74,
				1,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 접수 방의 베틀",
			"level": -1
		},
		{
			"kind": "blanket_crate",
			"rect": [
				74,
				5,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 접수 방의 담요 상자",
			"level": -1
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				74,
				4,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 접수 방의 천 두루마리 선반",
			"level": -1
		},
		{
			"kind": "loom",
			"rect": [
				79,
				1,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 보관 방의 베틀",
			"level": -1
		},
		{
			"kind": "blanket_crate",
			"rect": [
				79,
				5,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 보관 방의 담요 상자",
			"level": -1
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				79,
				4,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 보관 방의 천 두루마리 선반",
			"level": -1
		},
		{
			"kind": "loom",
			"rect": [
				84,
				1,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 안쪽 광의 베틀",
			"level": -1
		},
		{
			"kind": "blanket_crate",
			"rect": [
				84,
				3,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 안쪽 광의 담요 상자",
			"level": -1
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				84,
				4,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 안쪽 광의 천 두루마리 선반",
			"level": -1
		},
		{
			"kind": "loom",
			"rect": [
				59,
				1,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "방직 공방 입고 방의 베틀",
			"level": 0
		},
		{
			"kind": "blanket_crate",
			"rect": [
				59,
				5,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "방직 공방 입고 방의 담요 상자",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				59,
				4,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "방직 공방 입고 방의 책상",
			"level": 0
		},
		{
			"kind": "loom",
			"rect": [
				64,
				1,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "방직 공방 비축 방의 베틀",
			"level": 0
		},
		{
			"kind": "blanket_crate",
			"rect": [
				64,
				5,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "방직 공방 비축 방의 담요 상자",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				64,
				4,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "방직 공방 비축 방의 책상",
			"level": 0
		},
		{
			"kind": "loom",
			"rect": [
				69,
				1,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "방직 공방 작업 방의 베틀",
			"level": 0
		},
		{
			"kind": "blanket_crate",
			"rect": [
				69,
				5,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "방직 공방 작업 방의 담요 상자",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				69,
				4,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "방직 공방 작업 방의 책상",
			"level": 0
		},
		{
			"kind": "loom",
			"rect": [
				74,
				1,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "방직 공방 접수 방의 베틀",
			"level": 0
		},
		{
			"kind": "blanket_crate",
			"rect": [
				74,
				5,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "방직 공방 접수 방의 담요 상자",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				74,
				4,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "방직 공방 접수 방의 책상",
			"level": 0
		},
		{
			"kind": "loom",
			"rect": [
				79,
				1,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "방직 공방 보관 방의 베틀",
			"level": 0
		},
		{
			"kind": "blanket_crate",
			"rect": [
				79,
				5,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "방직 공방 보관 방의 담요 상자",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				79,
				4,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "방직 공방 보관 방의 책상",
			"level": 0
		},
		{
			"kind": "loom",
			"rect": [
				84,
				1,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "방직 공방 안쪽 광의 베틀",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				84,
				5,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "방직 공방 안쪽 광의 통",
			"level": 0
		},
		{
			"kind": "cold_stove",
			"rect": [
				86,
				5,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "방직 공방 안쪽 광의 꺼진 난로",
			"level": 0
		},
		{
			"kind": "loom",
			"rect": [
				59,
				1,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 입고 방의 베틀",
			"level": 1
		},
		{
			"kind": "blanket_crate",
			"rect": [
				59,
				5,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 입고 방의 담요 상자",
			"level": 1
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				59,
				4,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 입고 방의 천 두루마리 선반",
			"level": 1
		},
		{
			"kind": "loom",
			"rect": [
				64,
				1,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 비축 방의 베틀",
			"level": 1
		},
		{
			"kind": "blanket_crate",
			"rect": [
				64,
				5,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 비축 방의 담요 상자",
			"level": 1
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				64,
				4,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 비축 방의 천 두루마리 선반",
			"level": 1
		},
		{
			"kind": "loom",
			"rect": [
				69,
				1,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 작업 방의 베틀",
			"level": 1
		},
		{
			"kind": "blanket_crate",
			"rect": [
				69,
				5,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 작업 방의 담요 상자",
			"level": 1
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				69,
				4,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 작업 방의 천 두루마리 선반",
			"level": 1
		},
		{
			"kind": "loom",
			"rect": [
				74,
				1,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 접수 방의 베틀",
			"level": 1
		},
		{
			"kind": "blanket_crate",
			"rect": [
				74,
				5,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 접수 방의 담요 상자",
			"level": 1
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				74,
				4,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 접수 방의 천 두루마리 선반",
			"level": 1
		},
		{
			"kind": "loom",
			"rect": [
				79,
				1,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 보관 방의 베틀",
			"level": 1
		},
		{
			"kind": "blanket_crate",
			"rect": [
				79,
				5,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 보관 방의 담요 상자",
			"level": 1
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				79,
				4,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 보관 방의 천 두루마리 선반",
			"level": 1
		},
		{
			"kind": "loom",
			"rect": [
				84,
				1,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 안쪽 광의 베틀",
			"level": 1
		},
		{
			"kind": "blanket_crate",
			"rect": [
				84,
				3,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 안쪽 광의 담요 상자",
			"level": 1
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				84,
				4,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 안쪽 광의 천 두루마리 선반",
			"level": 1
		},
		{
			"kind": "loom",
			"rect": [
				59,
				1,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 입고 방의 베틀",
			"level": 2
		},
		{
			"kind": "blanket_crate",
			"rect": [
				59,
				5,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 입고 방의 담요 상자",
			"level": 2
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				59,
				4,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 입고 방의 천 두루마리 선반",
			"level": 2
		},
		{
			"kind": "loom",
			"rect": [
				64,
				1,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 비축 방의 베틀",
			"level": 2
		},
		{
			"kind": "blanket_crate",
			"rect": [
				64,
				5,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 비축 방의 담요 상자",
			"level": 2
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				64,
				4,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 비축 방의 천 두루마리 선반",
			"level": 2
		},
		{
			"kind": "loom",
			"rect": [
				69,
				1,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 작업 방의 베틀",
			"level": 2
		},
		{
			"kind": "blanket_crate",
			"rect": [
				69,
				5,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 작업 방의 담요 상자",
			"level": 2
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				69,
				4,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 작업 방의 천 두루마리 선반",
			"level": 2
		},
		{
			"kind": "loom",
			"rect": [
				74,
				1,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 접수 방의 베틀",
			"level": 2
		},
		{
			"kind": "blanket_crate",
			"rect": [
				74,
				5,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 접수 방의 담요 상자",
			"level": 2
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				74,
				4,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 접수 방의 천 두루마리 선반",
			"level": 2
		},
		{
			"kind": "loom",
			"rect": [
				79,
				1,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 보관 방의 베틀",
			"level": 2
		},
		{
			"kind": "blanket_crate",
			"rect": [
				79,
				5,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 보관 방의 담요 상자",
			"level": 2
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				79,
				4,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 보관 방의 천 두루마리 선반",
			"level": 2
		},
		{
			"kind": "loom",
			"rect": [
				84,
				1,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 안쪽 광의 베틀",
			"level": 2
		},
		{
			"kind": "blanket_crate",
			"rect": [
				84,
				3,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 안쪽 광의 담요 상자",
			"level": 2
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				84,
				4,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "방직 공방 안쪽 광의 천 두루마리 선반",
			"level": 2
		},
		{
			"kind": "barrel",
			"rect": [
				98,
				3,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "우물 정자 작업 칸의 통",
			"level": 0
		},
		{
			"kind": "bench",
			"rect": [
				93,
				3,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "우물 정자 작업 칸의 긴 의자",
			"level": 0
		},
		{
			"kind": "shelf",
			"rect": [
				93,
				8,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "우물 정자 작업 칸의 선반",
			"level": 0
		},
		{
			"kind": "bed",
			"rect": [
				23,
				13,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "농가 살림방의 침대",
			"level": -1
		},
		{
			"kind": "wardrobe",
			"rect": [
				23,
				19,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "농가 살림방의 장롱",
			"level": -1
		},
		{
			"kind": "desk",
			"rect": [
				29,
				13,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "농가 살림방의 책상",
			"level": -1
		},
		{
			"kind": "dining_set",
			"rect": [
				32,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "농가 부엌의 식탁",
			"level": -1
		},
		{
			"kind": "fridge_open",
			"rect": [
				38,
				13,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "농가 부엌의 냉장고",
			"level": -1
		},
		{
			"kind": "cold_stove",
			"rect": [
				32,
				19,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "농가 부엌의 꺼진 난로",
			"level": -1
		},
		{
			"kind": "bed",
			"rect": [
				23,
				13,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "농가 살림방의 침대",
			"level": 0
		},
		{
			"kind": "wardrobe",
			"rect": [
				23,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "농가 살림방의 장롱",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				29,
				13,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "농가 살림방의 책상",
			"level": 0
		},
		{
			"kind": "dining_set",
			"rect": [
				32,
				13,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "농가 부엌의 식탁",
			"level": 0
		},
		{
			"kind": "fridge_open",
			"rect": [
				38,
				13,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "농가 부엌의 냉장고",
			"level": 0
		},
		{
			"kind": "cold_stove",
			"rect": [
				32,
				19,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "농가 부엌의 꺼진 난로",
			"level": 0
		},
		{
			"kind": "bed",
			"rect": [
				23,
				13,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "농가 살림방의 침대",
			"level": 1
		},
		{
			"kind": "wardrobe",
			"rect": [
				23,
				19,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "농가 살림방의 장롱",
			"level": 1
		},
		{
			"kind": "desk",
			"rect": [
				29,
				13,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "농가 살림방의 책상",
			"level": 1
		},
		{
			"kind": "dining_set",
			"rect": [
				32,
				13,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "농가 부엌의 식탁",
			"level": 1
		},
		{
			"kind": "fridge_open",
			"rect": [
				38,
				13,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "농가 부엌의 냉장고",
			"level": 1
		},
		{
			"kind": "cold_stove",
			"rect": [
				32,
				19,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "농가 부엌의 꺼진 난로",
			"level": 1
		},
		{
			"kind": "loom",
			"rect": [
				41,
				15,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "헛간 작업 칸의 베틀",
			"level": 0
		},
		{
			"kind": "blanket_crate",
			"rect": [
				41,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "헛간 작업 칸의 담요 상자",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				44,
				15,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "헛간 작업 칸의 책상",
			"level": 0
		},
		{
			"kind": "loom",
			"rect": [
				47,
				15,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "헛간 보관 칸의 베틀",
			"level": 0
		},
		{
			"kind": "blanket_crate",
			"rect": [
				47,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "헛간 보관 칸의 담요 상자",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				47,
				18,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "헛간 보관 칸의 책상",
			"level": 0
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				59,
				16,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "잡화 가게 뒤 창고의 천 두루마리 선반",
			"level": 0
		},
		{
			"kind": "blanket_crate",
			"rect": [
				59,
				18,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "잡화 가게 뒤 창고의 담요 상자",
			"level": 0
		},
		{
			"kind": "shelf",
			"rect": [
				59,
				17,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "잡화 가게 뒤 창고의 선반",
			"level": 0
		},
		{
			"kind": "display_shelf",
			"rect": [
				59,
				20,
				4,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "잡화 가게 매장의 진열대",
			"level": 0
		},
		{
			"kind": "shop_counter",
			"rect": [
				59,
				22,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "잡화 가게 매장의 계산대",
			"level": 0
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				59,
				21,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "잡화 가게 매장의 천 두루마리 선반",
			"level": 0
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				59,
				16,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "잡화 가게 뒤 창고의 천 두루마리 선반",
			"level": 1
		},
		{
			"kind": "blanket_crate",
			"rect": [
				59,
				18,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "잡화 가게 뒤 창고의 담요 상자",
			"level": 1
		},
		{
			"kind": "shelf",
			"rect": [
				59,
				17,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "잡화 가게 뒤 창고의 선반",
			"level": 1
		},
		{
			"kind": "display_shelf",
			"rect": [
				59,
				20,
				4,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "잡화 가게 매장의 진열대",
			"level": 1
		},
		{
			"kind": "shop_counter",
			"rect": [
				59,
				22,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "잡화 가게 매장의 계산대",
			"level": 1
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				59,
				21,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "잡화 가게 매장의 천 두루마리 선반",
			"level": 1
		},
		{
			"kind": "blanket_crate",
			"rect": [
				77,
				17,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "직조 창고 작업 칸의 담요 상자",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				77,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "직조 창고 작업 칸의 책상",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				81,
				17,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "직조 창고 작업 칸의 통",
			"level": 0
		},
		{
			"kind": "blanket_crate",
			"rect": [
				83,
				17,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "직조 창고 보관 칸의 담요 상자",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				83,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "직조 창고 보관 칸의 책상",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				87,
				17,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "직조 창고 보관 칸의 통",
			"level": 0
		},
		{
			"kind": "bed",
			"rect": [
				90,
				17,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "작은 집 살림방의 침대",
			"level": 0
		},
		{
			"kind": "wardrobe",
			"rect": [
				90,
				19,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "작은 집 살림방의 장롱",
			"level": 0
		},
		{
			"kind": "desk",
			"rect": [
				90,
				18,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "작은 집 살림방의 책상",
			"level": 0
		},
		{
			"kind": "fridge_open",
			"rect": [
				95,
				17,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "작은 집 부엌의 냉장고",
			"level": 0
		},
		{
			"kind": "cold_stove",
			"rect": [
				97,
				17,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "작은 집 부엌의 꺼진 난로",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				95,
				19,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "작은 집 부엌의 통",
			"level": 0
		},
		{
			"kind": "bed",
			"rect": [
				90,
				17,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "작은 집 살림방의 침대",
			"level": 1
		},
		{
			"kind": "wardrobe",
			"rect": [
				90,
				19,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "작은 집 살림방의 장롱",
			"level": 1
		},
		{
			"kind": "desk",
			"rect": [
				92,
				17,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "작은 집 살림방의 책상",
			"level": 1
		},
		{
			"kind": "dining_set",
			"rect": [
				95,
				17,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "작은 집 부엌의 식탁",
			"level": 1
		},
		{
			"kind": "fridge_open",
			"rect": [
				97,
				17,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "작은 집 부엌의 냉장고",
			"level": 1
		},
		{
			"kind": "cold_stove",
			"rect": [
				95,
				19,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "작은 집 부엌의 꺼진 난로",
			"level": 1
		},
		{
			"kind": "blanket_crate",
			"rect": [
				141,
				1,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "외딴 곳간 농가 작업 칸의 담요 상자",
			"level": -1
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				141,
				7,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "외딴 곳간 농가 작업 칸의 천 두루마리 선반",
			"level": -1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				141,
				2,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "외딴 곳간 농가 작업 칸의 병조림 선반",
			"level": -1
		},
		{
			"kind": "blanket_crate",
			"rect": [
				151,
				1,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "외딴 곳간 농가 보관 칸의 담요 상자",
			"level": -1
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				151,
				7,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "외딴 곳간 농가 보관 칸의 천 두루마리 선반",
			"level": -1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				151,
				2,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "외딴 곳간 농가 보관 칸의 병조림 선반",
			"level": -1
		},
		{
			"kind": "blanket_crate",
			"rect": [
				141,
				1,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "외딴 곳간 농가 작업 칸의 담요 상자",
			"level": 0
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				141,
				7,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "외딴 곳간 농가 작업 칸의 천 두루마리 선반",
			"level": 0
		},
		{
			"kind": "jar_shelf",
			"rect": [
				141,
				2,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "외딴 곳간 농가 작업 칸의 병조림 선반",
			"level": 0
		},
		{
			"kind": "blanket_crate",
			"rect": [
				151,
				1,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "외딴 곳간 농가 보관 칸의 담요 상자",
			"level": 0
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				151,
				7,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "외딴 곳간 농가 보관 칸의 천 두루마리 선반",
			"level": 0
		},
		{
			"kind": "jar_shelf",
			"rect": [
				151,
				2,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "외딴 곳간 농가 보관 칸의 병조림 선반",
			"level": 0
		},
		{
			"kind": "blanket_crate",
			"rect": [
				141,
				1,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "외딴 곳간 농가 작업 칸의 담요 상자",
			"level": 1
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				141,
				7,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "외딴 곳간 농가 작업 칸의 천 두루마리 선반",
			"level": 1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				141,
				2,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "외딴 곳간 농가 작업 칸의 병조림 선반",
			"level": 1
		},
		{
			"kind": "blanket_crate",
			"rect": [
				151,
				1,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "외딴 곳간 농가 보관 칸의 담요 상자",
			"level": 1
		},
		{
			"kind": "cloth_bolt_rack",
			"rect": [
				151,
				7,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "외딴 곳간 농가 보관 칸의 천 두루마리 선반",
			"level": 1
		},
		{
			"kind": "jar_shelf",
			"rect": [
				151,
				2,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "외딴 곳간 농가 보관 칸의 병조림 선반",
			"level": 1
		},
		{
			"kind": "sack_pile",
			"rect": [
				117,
				28,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "외양간 작업 칸의 자루 더미",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				124,
				28,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "외양간 작업 칸의 통",
			"level": 0
		},
		{
			"kind": "shelf",
			"rect": [
				117,
				34,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "외양간 작업 칸의 선반",
			"level": 0
		},
		{
			"kind": "sack_pile",
			"rect": [
				126,
				28,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "외양간 보관 칸의 자루 더미",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				132,
				28,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "외양간 보관 칸의 통",
			"level": 0
		},
		{
			"kind": "shelf",
			"rect": [
				126,
				34,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "외양간 보관 칸의 선반",
			"level": 0
		},
		{
			"kind": "hay_cart",
			"rect": [
				30,
				38,
				4,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "마당의 작업 물건",
			"level": 0
		},
		{
			"kind": "fieldstone_wall",
			"rect": [
				62,
				36,
				1,
				6
			],
			"solid": "low",
			"facing": 0,
			"note": "마당의 작업 물건",
			"level": 0
		},
		{
			"kind": "firewood_pile",
			"rect": [
				84,
				41,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "장작 더미",
			"level": 0
		},
		{
			"kind": "handcart",
			"rect": [
				96,
				30,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "손수레",
			"level": 0
		},
		{
			"kind": "box_truck",
			"rect": [
				0,
				21,
				6,
				3
			],
			"solid": "wall",
			"facing": 0,
			"note": "마당의 작업 물건",
			"level": 0
		},
		{
			"kind": "fieldstone_wall",
			"rect": [
				6,
				23,
				8,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "마당의 작업 물건",
			"level": 0
		},
		{
			"kind": "firewood_pile",
			"rect": [
				20,
				23,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "장작 더미",
			"level": 0
		},
		{
			"kind": "hay_cart",
			"rect": [
				116,
				23,
				4,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "마당의 작업 물건",
			"level": 0
		},
		{
			"kind": "hay_cart",
			"rect": [
				116,
				25,
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
				39,
				6,
				3
			],
			"solid": "wall",
			"facing": 0,
			"note": "마당의 작업 물건",
			"level": 0
		},
		{
			"kind": "hay_cart",
			"rect": [
				116,
				42,
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
				116,
				44,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "나무 상자 더미",
			"level": 0
		},
		{
			"kind": "well_cover",
			"rect": [
				93,
				11,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "우물 뚜껑",
			"level": 0
		},
		{
			"kind": "barrel",
			"rect": [
				98,
				12,
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
				90,
				12,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "긴 의자",
			"level": 0
		},
		{
			"kind": "laundry_line",
			"rect": [
				93,
				13,
				6,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "언 천 조각 빨랫줄",
			"level": 0
		},
		{
			"kind": "bare_orchard_tree",
			"rect": [
				109,
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
				112,
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
				115,
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
				110,
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
				114,
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
				99,
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
				102,
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
				100,
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
			"kind": "street_tree",
			"rect": [
				26,
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
				29,
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
				33,
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
				36,
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
				38,
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
				2,
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
			"kind": "street_tree",
			"rect": [
				6,
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
				8,
				14,
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
			"name": "방직 공방 입고 방 상자",
			"cell": [
				62,
				1
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_1",
			"name": "방직 공방 비축 방 상자",
			"cell": [
				67,
				1
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_2",
			"name": "방직 공방 작업 방 상자",
			"cell": [
				72,
				1
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_3",
			"name": "방직 공방 접수 방 상자",
			"cell": [
				77,
				1
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_4",
			"name": "방직 공방 보관 방 상자",
			"cell": [
				82,
				1
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_5",
			"name": "방직 공방 안쪽 광 상자",
			"cell": [
				86,
				5
			],
			"level": -1,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_6",
			"name": "방직 공방 입고 방 상자",
			"cell": [
				62,
				1
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_7",
			"name": "방직 공방 비축 방 상자",
			"cell": [
				67,
				1
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_8",
			"name": "방직 공방 작업 방 상자",
			"cell": [
				72,
				1
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_9",
			"name": "방직 공방 접수 방 상자",
			"cell": [
				77,
				1
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_10",
			"name": "방직 공방 보관 방 상자",
			"cell": [
				82,
				1
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_11",
			"name": "방직 공방 안쪽 광 상자",
			"cell": [
				84,
				4
			],
			"level": 0,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_12",
			"name": "방직 공방 입고 방 상자",
			"cell": [
				62,
				1
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_13",
			"name": "방직 공방 비축 방 상자",
			"cell": [
				67,
				1
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_14",
			"name": "방직 공방 작업 방 상자",
			"cell": [
				72,
				1
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_15",
			"name": "방직 공방 접수 방 상자",
			"cell": [
				77,
				1
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_16",
			"name": "방직 공방 보관 방 상자",
			"cell": [
				82,
				1
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_17",
			"name": "방직 공방 안쪽 광 상자",
			"cell": [
				86,
				5
			],
			"level": 1,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_18",
			"name": "방직 공방 입고 방 상자",
			"cell": [
				62,
				1
			],
			"level": 2,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_19",
			"name": "방직 공방 비축 방 상자",
			"cell": [
				67,
				1
			],
			"level": 2,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_20",
			"name": "방직 공방 작업 방 상자",
			"cell": [
				72,
				1
			],
			"level": 2,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_21",
			"name": "방직 공방 접수 방 상자",
			"cell": [
				77,
				1
			],
			"level": 2,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_22",
			"name": "방직 공방 보관 방 상자",
			"cell": [
				82,
				1
			],
			"level": 2,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_23",
			"name": "방직 공방 안쪽 광 상자",
			"cell": [
				86,
				5
			],
			"level": 2,
			"building": 16,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_24",
			"name": "우물 정자 작업 칸 상자",
			"cell": [
				98,
				8
			],
			"level": 0,
			"building": 17,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_25",
			"name": "농가 살림방 상자",
			"cell": [
				30,
				19
			],
			"level": -1,
			"building": 18,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_26",
			"name": "농가 부엌 상자",
			"cell": [
				38,
				19
			],
			"level": -1,
			"building": 18,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_27",
			"name": "농가 살림방 상자",
			"cell": [
				30,
				19
			],
			"level": 0,
			"building": 18,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_28",
			"name": "농가 부엌 상자",
			"cell": [
				38,
				19
			],
			"level": 0,
			"building": 18,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_29",
			"name": "농가 살림방 상자",
			"cell": [
				30,
				19
			],
			"level": 1,
			"building": 18,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_30",
			"name": "농가 부엌 상자",
			"cell": [
				38,
				19
			],
			"level": 1,
			"building": 18,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_31",
			"name": "헛간 작업 칸 상자",
			"cell": [
				45,
				19
			],
			"level": 0,
			"building": 19,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_32",
			"name": "헛간 보관 칸 상자",
			"cell": [
				50,
				15
			],
			"level": 0,
			"building": 19,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_33",
			"name": "잡화 가게 뒤 창고 상자",
			"cell": [
				70,
				16
			],
			"level": 0,
			"building": 20,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_34",
			"name": "잡화 가게 매장 상자",
			"cell": [
				70,
				20
			],
			"level": 0,
			"building": 20,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_35",
			"name": "잡화 가게 뒤 창고 상자",
			"cell": [
				70,
				16
			],
			"level": 1,
			"building": 20,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_36",
			"name": "잡화 가게 매장 상자",
			"cell": [
				70,
				20
			],
			"level": 1,
			"building": 20,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_37",
			"name": "직조 창고 작업 칸 상자",
			"cell": [
				81,
				19
			],
			"level": 0,
			"building": 21,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_38",
			"name": "직조 창고 보관 칸 상자",
			"cell": [
				87,
				19
			],
			"level": 0,
			"building": 21,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_39",
			"name": "작은 집 살림방 상자",
			"cell": [
				93,
				17
			],
			"level": 0,
			"building": 22,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_40",
			"name": "작은 집 부엌 상자",
			"cell": [
				97,
				19
			],
			"level": 0,
			"building": 22,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_41",
			"name": "작은 집 살림방 상자",
			"cell": [
				93,
				19
			],
			"level": 1,
			"building": 22,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_42",
			"name": "작은 집 부엌 상자",
			"cell": [
				97,
				19
			],
			"level": 1,
			"building": 22,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_43",
			"name": "외딴 곳간 농가 작업 칸 상자",
			"cell": [
				149,
				1
			],
			"level": -1,
			"building": 23,
			"search": 7,
			"items": [
				"cloth",
				"needle_thread",
				"cloth",
				"needle_thread"
			],
			"locked": true,
			"searched": false
		},
		{
			"id": "north_cache_44",
			"name": "외딴 곳간 농가 보관 칸 상자",
			"cell": [
				158,
				1
			],
			"level": -1,
			"building": 23,
			"search": 7,
			"items": [
				"cloth",
				"needle_thread",
				"cloth",
				"needle_thread"
			],
			"locked": true,
			"searched": false
		},
		{
			"id": "north_cache_45",
			"name": "외딴 곳간 농가 작업 칸 상자",
			"cell": [
				149,
				1
			],
			"level": 0,
			"building": 23,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_46",
			"name": "외딴 곳간 농가 보관 칸 상자",
			"cell": [
				158,
				1
			],
			"level": 0,
			"building": 23,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_47",
			"name": "외딴 곳간 농가 작업 칸 상자",
			"cell": [
				149,
				1
			],
			"level": 1,
			"building": 23,
			"search": 7,
			"items": [
				"cloth",
				"needle_thread",
				"cloth",
				"needle_thread"
			],
			"locked": true,
			"searched": false
		},
		{
			"id": "north_cache_48",
			"name": "외딴 곳간 농가 보관 칸 상자",
			"cell": [
				158,
				1
			],
			"level": 1,
			"building": 23,
			"search": 7,
			"items": [
				"cloth",
				"needle_thread",
				"cloth",
				"needle_thread"
			],
			"locked": true,
			"searched": false
		},
		{
			"id": "north_cache_49",
			"name": "외양간 작업 칸 상자",
			"cell": [
				124,
				34
			],
			"level": 0,
			"building": 24,
			"search": 4,
			"items": [
				"cloth"
			],
			"locked": false,
			"searched": false
		},
		{
			"id": "north_cache_50",
			"name": "외양간 보관 칸 상자",
			"cell": [
				132,
				34
			],
			"level": 0,
			"building": 24,
			"search": 4,
			"items": [
				"cloth"
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
				"cloth"
			],
			"locked": false,
			"searched": false
		}
	],
	"entries": [
		{
			"id": "층층 길 북쪽 어귀",
			"name": "층층 길 북쪽 어귀",
			"cells": [
				[
					10,
					0
				],
				[
					11,
					0
				],
				[
					12,
					0
				],
				[
					13,
					0
				]
			],
			"gap": 2.5
		},
		{
			"id": "북쪽 밭길",
			"name": "북쪽 밭길",
			"cells": [
				[
					118,
					0
				],
				[
					119,
					0
				],
				[
					120,
					0
				],
				[
					121,
					0
				]
			],
			"gap": 2.5
		},
		{
			"id": "동쪽 곳간 길",
			"name": "동쪽 곳간 길",
			"cells": [
				[
					164,
					16
				],
				[
					164,
					17
				],
				[
					164,
					18
				],
				[
					164,
					19
				]
			],
			"gap": 0.6
		}
	],
	"holes": [
		{
			"id": "manhole_03",
			"name": "우물 동쪽 맨홀",
			"cell": [
				101,
				6
			],
			"level": 0
		}
	],
	"barricades": [
		[
			53,
			22
		],
		[
			56,
			22
		],
		[
			72,
			22
		],
		[
			75,
			22
		],
		[
			15,
			23
		],
		[
			18,
			23
		]
	],
	"slots": [
		"K"
	],
	"deep": 7,
	"forecourts": [
		[
			71,
			10,
			5,
			4
		],
		[
			94,
			10,
			5,
			4
		],
		[
			29,
			24,
			5,
			4
		],
		[
			44,
			24,
			5,
			4
		],
		[
			63,
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
			92,
			24,
			5,
			4
		],
		[
			148,
			12,
			5,
			4
		],
		[
			123,
			39,
			5,
			4
		]
	],
	"crossings": [
		48,
		64
	],
	"stock": [
		"loom",
		"blanket_crate",
		"cloth_bolt_rack",
		"desk"
	],
	"loot": [
		"cloth",
		"needle_thread"
	],
	"assumptions": [
		"좁은 가게는 방 깊이 세 칸을 확보하도록 한 줄 북쪽으로 늘리고 곁길 폭은 네 칸으로 유지했다.",
		"서쪽의 남은 여섯 칸 틈은 추가 길목으로 남기고 방벽 자리 두 칸을 주었다. 두 차량과 짧은 담으로 긴 울타리를 피했다.",
		"동쪽 곳간 앞 빈 화면 구간에는 네 칸 폭의 자갈 작업 길을 더했다."
	]
}

const SOUTH_TREE_MOVES: Array = [[[105,48],[97,38]],[[36,69],[40,77]],[[66,75],[74,78]],[[71,76],[71,80]]]
const SOUTH_WORK: Dictionary = {"name":"장작 헛간 작업 구역","cell":[66,96],"rect":[60,94,14,6]}

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
const ENTRY_NAMES: Dictionary = {"west_road": "서쪽 길", "south_path": "남쪽 오솔길", "east_village": "동쪽 마을", "east_field": "동쪽 들판", "manhole_01": "첫째 맨홀", "manhole_02": "둘째 맨홀", "drain_01": "배수구", "층층 길 북쪽 어귀": "층층 길 북쪽 어귀", "북쪽 밭길": "북쪽 밭길", "동쪽 곳간 길": "동쪽 곳간 길", "manhole_03": "셋째 맨홀"}
const ENTRY_WEIGHTS: Dictionary = {"west_road": 1.0, "south_path": 0.5, "east_village": 1.0, "east_field": 0.5, "manhole_01": 0.3, "manhole_02": 0.3, "drain_01": 1.0, "층층 길 북쪽 어귀": 0.5, "북쪽 밭길": 0.5, "동쪽 곳간 길": 1.0, "manhole_03": 0.3}
const FIRST_ENTRY: String = "west_road"


static func build() -> Dictionary:
	var data: Dictionary = _build_plain()
	data["entry_names"] = ENTRY_NAMES.duplicate()
	data["entry_weights"] = ENTRY_WEIGHTS.duplicate()
	data["first_entry"] = FIRST_ENTRY
	return data
