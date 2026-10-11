# 이 지도가 다른 판단을 만드는 것: 격자 야적장에서 가로 골목으로 갈아타고, 작업동에서 떨어진 동남쪽 기계실까지 별도 운반 길을 확보한다.
extends RefCounted
## 1칸은 1m. 물건 이름표와 현재 그리는 고체를 함께 둔다.

const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 170
const HEIGHT: int = 102
const LEVEL_H: float = 3.0
const PLACE_ID: String = "sawmill_02"
const BUILDING_NAMES: Array[String] = ["제재동","기계실","건조장","건조장","건조장","야적 공구 작업장","야적 정비 작업장"]
const ZONE_NAMES: Dictionary = {"log_yard":"원목 야적장","drying":"건조장","saw_hall":"제재동","machine_room":"기계실","forest_edge":"벌목 숲가"}
## 무전 문장에 쓰는 들어오는 길의 이름, 길마다의 비중, 첫 물결이 오는 길.
const ENTRY_NAMES: Dictionary = {"west_logging": "서쪽 벌목길", "south_logging": "남쪽 벌목길", "forest_edge": "숲 가장자리"}
const ENTRY_WEIGHTS: Dictionary = {"west_logging": 0.3, "south_logging": 0.3, "forest_edge": 0.4}
const FIRST_ENTRY: String = "west_logging"

## 사각형은 x, y, 너비, 높이. doors의 마지막 값은 초기 문 상태다.
const LAYOUT: Dictionary = {
	"size": [170,102],
	"train": [45,47,80,3],
	"bands": {"upper":[25,25,120,22],"lower":[25,50,120,22]},
	"floors": [[15,12,140,4,5],[15,95,140,5,5],[15,22,13,8,5],[142,17,13,10,5],[33,26,104,16,7],[25,41,120,3,7],[25,53,120,4,7],[38,41,4,18,7],[128,41,4,18,7],[15,20,27,4,1],[38,20,4,25,1],[89,59,4,41,1],[89,59,20,4,1],[142,37,13,4,7],[142,37,4,34,7],[142,65,13,3,7],[142,55,13,3,7],[26,71,54,5,7],[26,94,54,3,7],[26,71,3,26,7],[77,71,3,26,7],[106,64,42,5,7],[106,96,42,3,7],[106,64,5,35,7],[143,64,4,35,7],[58,61,10,2,7],[69,61,10,2,7],[80,61,10,2,7],[25,55,124,5,7],[97,55,6,39,7],[25,59,120,4,7],[97,62,16,4,7],[25,59,4,36,7],[15,47,140,3,4],[45,44,80,3,2],[45,50,80,3,2],[42,45,3,7,3],[125,45,3,7,3],[0,20,16,1,1],[0,22,16,1,1],[89,99,1,3,1],[91,99,1,3,1],[154,37,16,1,1],[154,57,16,1,1],[154,66,16,1,1],[0,40,170,4,7],[0,55,170,4,7],[42,39,3,25,7],[126,39,3,25,7],[0,47,170,3,4],[45,44,80,3,2],[45,50,80,3,2],[42,45,3,7,3],[125,45,3,7,3],[105,66,1,1,7],[105,67,1,1,7],[104,66,1,1,7],[104,67,1,1,7],[103,66,1,1,7],[103,67,1,1,7],[96,65,1,1,7],[96,66,1,1,7],[96,67,1,1,7],[95,65,1,1,7],[95,66,1,1,7],[95,67,1,1,7],[94,65,1,1,7],[94,66,1,1,7],[94,67,1,1,7],[93,65,1,1,7],[93,66,1,1,7],[93,67,1,1,7],[80,63,1,1,7],[79,63,1,1,7],[78,63,1,1,7],[69,63,1,1,7],[68,63,1,1,7],[67,63,1,1,7],[58,63,1,1,7],[57,63,1,1,7],[56,63,1,1,7],[55,63,1,1,7],[54,63,1,1,7],[53,63,1,1,7],[52,63,1,1,7],[51,63,1,1,7],[50,63,1,1,7],[49,63,1,1,7],[48,63,1,1,7],[47,63,1,1,7],[46,63,1,1,7],[45,63,1,1,7],[125,63,1,1,7],[125,52,1,1,7],[105,81,1,1,7],[105,82,1,1,7],[105,83,1,1,7],[104,81,1,1,7],[104,82,1,1,7],[104,83,1,1,7],[103,81,1,1,7],[103,82,1,1,7],[103,83,1,1,7],[96,77,1,1,7],[96,78,1,1,7],[95,77,1,1,7],[95,78,1,1,7],[94,77,1,1,7],[94,78,1,1,7],[93,77,1,1,7],[93,78,1,1,7],[93,79,1,1,7],[88,77,1,1,7],[88,78,1,1,7],[87,77,1,1,7],[87,78,1,1,7],[86,77,1,1,7],[86,78,1,1,7],[85,77,1,1,7],[85,78,1,1,7],[84,77,1,1,7],[84,78,1,1,7],[83,77,1,1,7],[83,78,1,1,7],[82,77,1,1,7],[82,78,1,1,7],[82,79,1,1,7],[81,77,1,1,7],[81,78,1,1,7],[81,79,1,1,7],[80,77,1,1,7],[80,78,1,1,7],[80,79,1,1,7],[44,70,1,1,7],[45,70,1,1,7],[46,70,1,1,7],[43,70,1,1,7],[42,70,1,1,7],[42,69,1,1,7],[43,69,1,1,7],[44,69,1,1,7],[42,68,1,1,7],[43,68,1,1,7],[44,68,1,1,7],[42,67,1,1,7],[43,67,1,1,7],[44,67,1,1,7],[42,66,1,1,7],[43,66,1,1,7],[44,66,1,1,7],[42,65,1,1,7],[43,65,1,1,7],[44,65,1,1,7],[42,64,1,1,7],[43,64,1,1,7],[44,64,1,1,7],[0,19,1,1,7],[1,19,1,1,7],[0,21,1,1,7],[1,21,1,1,7],[2,19,1,1,7],[2,21,1,1,7],[3,19,1,1,7],[3,21,1,1,7],[4,19,1,1,7],[4,21,1,1,7],[5,19,1,1,7],[5,21,1,1,7],[6,19,1,1,7],[6,21,1,1,7],[7,19,1,1,7],[7,21,1,1,7],[8,19,1,1,7],[8,21,1,1,7],[9,19,1,1,7],[9,21,1,1,7],[10,19,1,1,7],[10,21,1,1,7],[11,19,1,1,7],[11,21,1,1,7],[12,19,1,1,7],[12,21,1,1,7],[13,19,1,1,7],[13,21,1,1,7],[14,19,1,1,7],[14,21,1,1,7],[15,19,1,1,7],[16,19,1,1,7],[17,19,1,1,7],[18,19,1,1,7],[19,19,1,1,7],[20,19,1,1,7],[21,19,1,1,7],[22,19,1,1,7],[23,19,1,1,7],[24,19,1,1,7],[25,19,1,1,7],[26,19,1,1,7],[27,19,1,1,7],[28,19,1,1,7],[29,19,1,1,7],[30,19,1,1,7],[31,19,1,1,7],[32,19,1,1,7],[33,19,1,1,7],[34,19,1,1,7],[35,19,1,1,7],[36,19,1,1,7],[37,19,1,1,7],[38,19,1,1,7],[39,19,1,1,7],[40,19,1,1,7],[41,19,1,1,7],[42,19,1,1,7],[42,20,1,1,7],[42,21,1,1,7],[43,19,1,1,7],[43,20,1,1,7],[43,21,1,1,7],[44,19,1,1,7],[44,20,1,1,7],[44,21,1,1,7],[42,22,1,1,7],[43,22,1,1,7],[44,22,1,1,7],[42,23,1,1,7],[43,23,1,1,7],[44,23,1,1,7],[42,24,1,1,7],[43,24,1,1,7],[44,24,1,1,7],[42,25,1,1,7],[43,25,1,1,7],[44,25,1,1,7],[0,23,1,1,7],[1,23,1,1,7],[2,23,1,1,7],[3,23,1,1,7],[4,23,1,1,7],[5,23,1,1,7],[6,23,1,1,7],[7,23,1,1,7],[8,23,1,1,7],[9,23,1,1,7],[10,23,1,1,7],[11,23,1,1,7],[12,23,1,1,7],[13,23,1,1,7],[14,23,1,1,7],[88,100,1,1,7],[90,100,1,1,7],[88,101,1,1,7],[90,101,1,1,7],[87,100,1,1,7],[87,101,1,1,7],[86,100,1,1,7],[86,101,1,1,7],[85,100,1,1,7],[85,101,1,1,7],[84,100,1,1,7],[84,101,1,1,7],[83,100,1,1,7],[83,101,1,1,7],[82,100,1,1,7],[82,101,1,1,7],[81,100,1,1,7],[81,101,1,1,7],[80,100,1,1,7],[80,101,1,1,7],[79,100,1,1,7],[79,101,1,1,7],[78,100,1,1,7],[78,101,1,1,7],[77,100,1,1,7],[77,101,1,1,7],[76,100,1,1,7],[76,101,1,1,7],[77,99,1,1,7],[78,99,1,1,7],[77,98,1,1,7],[78,98,1,1,7],[77,97,1,1,7],[78,97,1,1,7],[92,100,1,1,7],[92,101,1,1,7],[168,36,1,1,7],[169,36,1,1,7],[168,38,1,1,7],[169,38,1,1,7],[167,36,1,1,7],[167,38,1,1,7],[166,36,1,1,7],[166,38,1,1,7],[165,36,1,1,7],[165,38,1,1,7],[164,36,1,1,7],[164,38,1,1,7],[163,36,1,1,7],[163,38,1,1,7],[162,36,1,1,7],[162,38,1,1,7],[161,36,1,1,7],[161,38,1,1,7],[160,36,1,1,7],[160,38,1,1,7],[159,36,1,1,7],[159,38,1,1,7],[158,36,1,1,7],[158,38,1,1,7],[157,36,1,1,7],[157,38,1,1,7],[156,36,1,1,7],[156,38,1,1,7],[155,36,1,1,7],[155,38,1,1,7],[154,36,1,1,7],[153,36,1,1,7],[152,36,1,1,7],[151,36,1,1,7],[150,36,1,1,7],[149,36,1,1,7],[148,36,1,1,7],[147,36,1,1,7],[146,36,1,1,7],[145,36,1,1,7],[144,36,1,1,7],[143,36,1,1,7],[142,36,1,1,7],[141,36,1,1,7],[141,37,1,1,7],[141,38,1,1,7],[140,36,1,1,7],[140,37,1,1,7],[140,38,1,1,7],[139,36,1,1,7],[139,37,1,1,7],[139,38,1,1,7],[138,36,1,1,7],[138,37,1,1,7],[138,38,1,1,7],[137,36,1,1,7],[137,37,1,1,7],[137,38,1,1,7],[168,65,1,1,7],[169,65,1,1,7],[168,67,1,1,7],[169,67,1,1,7],[167,65,1,1,7],[167,67,1,1,7],[166,65,1,1,7],[166,67,1,1,7],[165,65,1,1,7],[165,67,1,1,7],[164,65,1,1,7],[164,67,1,1,7],[163,65,1,1,7],[163,67,1,1,7],[162,65,1,1,7],[162,67,1,1,7],[161,65,1,1,7],[161,67,1,1,7],[160,65,1,1,7],[160,67,1,1,7],[159,65,1,1,7],[159,67,1,1,7],[158,65,1,1,7],[158,67,1,1,7],[157,65,1,1,7],[157,67,1,1,7],[156,65,1,1,7],[156,67,1,1,7],[155,65,1,1,7],[155,67,1,1,7],[151,64,1,1,7],[152,64,1,1,7],[153,64,1,1,7],[150,64,1,1,7],[149,64,1,1,7],[148,64,1,1,7],[96,64,1,1,7],[95,64,1,1,7],[94,64,1,1,7],[93,64,1,1,7],[84,2,1,1,7],[85,2,1,1,7],[86,2,1,1,7],[84,3,1,1,7],[85,3,1,1,7],[86,3,1,1,7],[84,4,1,1,7],[83,2,1,1,7],[83,3,1,1,7],[83,4,1,1,7],[82,2,1,1,7],[82,3,1,1,7],[82,4,1,1,7],[81,2,1,1,7],[81,3,1,1,7],[80,2,1,1,7],[80,3,1,1,7],[79,2,1,1,7],[79,3,1,1,7],[79,4,1,1,7],[78,2,1,1,7],[78,3,1,1,7],[78,4,1,1,7],[77,2,1,1,7],[77,3,1,1,7],[77,4,1,1,7],[76,2,1,1,7],[76,3,1,1,7],[76,4,1,1,7],[75,2,1,1,7],[75,3,1,1,7],[75,4,1,1,7],[74,2,1,1,7],[74,3,1,1,7],[74,4,1,1,7],[73,2,1,1,7],[73,3,1,1,7],[73,4,1,1,7],[72,2,1,1,7],[72,3,1,1,7],[72,4,1,1,7],[71,2,1,1,7],[71,3,1,1,7],[71,4,1,1,7],[70,2,1,1,7],[70,3,1,1,7],[70,4,1,1,7],[69,2,1,1,7],[69,3,1,1,7],[69,4,1,1,7],[68,2,1,1,7],[68,3,1,1,7],[68,4,1,1,7],[67,2,1,1,7],[67,3,1,1,7],[67,4,1,1,7],[66,2,1,1,7],[66,3,1,1,7],[66,4,1,1,7],[65,2,1,1,7],[65,3,1,1,7],[65,4,1,1,7],[64,2,1,1,7],[64,3,1,1,7],[64,4,1,1,7],[63,2,1,1,7],[63,3,1,1,7],[63,4,1,1,7],[62,2,1,1,7],[62,3,1,1,7],[62,4,1,1,7],[61,2,1,1,7],[61,3,1,1,7],[60,2,1,1,7],[60,3,1,1,7],[59,2,1,1,7],[59,3,1,1,7],[59,4,1,1,7],[58,2,1,1,7],[58,3,1,1,7],[58,4,1,1,7],[57,2,1,1,7],[57,3,1,1,7],[57,4,1,1,7],[56,2,1,1,7],[56,3,1,1,7],[55,2,1,1,7],[55,3,1,1,7],[54,2,1,1,7],[54,3,1,1,7],[54,4,1,1,7],[53,2,1,1,7],[53,3,1,1,7],[53,4,1,1,7],[52,2,1,1,7],[52,3,1,1,7],[52,4,1,1,7],[51,2,1,1,7],[51,3,1,1,7],[50,2,1,1,7],[50,3,1,1,7],[49,2,1,1,7],[49,3,1,1,7],[49,4,1,1,7],[48,2,1,1,7],[48,3,1,1,7],[48,4,1,1,7],[47,2,1,1,7],[47,3,1,1,7],[47,4,1,1,7],[46,2,1,1,7],[46,3,1,1,7],[46,4,1,1,7],[45,2,1,1,7],[45,3,1,1,7],[45,4,1,1,7],[44,2,1,1,7],[44,3,1,1,7],[44,4,1,1,7],[43,2,1,1,7],[43,3,1,1,7],[43,4,1,1,7],[42,2,1,1,7],[42,3,1,1,7],[42,4,1,1,7],[42,5,1,1,7],[43,5,1,1,7],[44,5,1,1,7],[42,6,1,1,7],[43,6,1,1,7],[44,6,1,1,7],[42,7,1,1,7],[43,7,1,1,7],[44,7,1,1,7],[42,8,1,1,7],[43,8,1,1,7],[44,8,1,1,7],[42,9,1,1,7],[43,9,1,1,7],[44,9,1,1,7],[42,10,1,1,7],[43,10,1,1,7],[44,10,1,1,7],[42,11,1,1,7],[43,11,1,1,7],[44,11,1,1,7],[42,12,1,1,7],[43,12,1,1,7],[44,12,1,1,7],[42,13,1,1,7],[43,13,1,1,7],[44,13,1,1,7],[42,14,1,1,7],[43,14,1,1,7],[44,14,1,1,7],[42,15,1,1,7],[43,15,1,1,7],[44,15,1,1,7],[42,16,1,1,7],[43,16,1,1,7],[44,16,1,1,7],[42,17,1,1,7],[43,17,1,1,7],[44,17,1,1,7],[42,18,1,1,7],[43,18,1,1,7],[44,18,1,1,7],[92,17,1,1,7],[93,17,1,1,7],[92,18,1,1,7],[93,18,1,1,7],[92,19,1,1,7],[93,19,1,1,7],[91,17,1,1,7],[91,18,1,1,7],[90,17,1,1,7],[90,18,1,1,7],[89,17,1,1,7],[89,18,1,1,7],[89,19,1,1,7],[88,18,1,1,7],[88,19,1,1,7],[87,18,1,1,7],[87,19,1,1,7],[86,18,1,1,7],[85,18,1,1,7],[84,17,1,1,7],[84,18,1,1,7],[84,19,1,1,7],[83,17,1,1,7],[83,18,1,1,7],[83,19,1,1,7],[82,17,1,1,7],[82,18,1,1,7],[82,19,1,1,7],[81,17,1,1,7],[81,18,1,1,7],[80,17,1,1,7],[80,18,1,1,7],[79,17,1,1,7],[79,18,1,1,7],[79,19,1,1,7],[79,20,1,1,7],[79,21,1,1,7],[78,22,1,1,7],[79,22,1,1,7],[78,23,1,1,7],[79,23,1,1,7],[77,22,1,1,7],[77,23,1,1,7],[76,22,1,1,7],[76,23,1,1,7],[75,21,1,1,7],[75,22,1,1,7],[75,23,1,1,7],[74,21,1,1,7],[74,22,1,1,7],[74,23,1,1,7],[73,21,1,1,7],[73,22,1,1,7],[73,23,1,1,7],[72,21,1,1,7],[72,22,1,1,7],[72,23,1,1,7],[71,21,1,1,7],[71,22,1,1,7],[70,21,1,1,7],[70,22,1,1,7],[69,21,1,1,7],[69,22,1,1,7],[69,23,1,1,7],[68,21,1,1,7],[68,22,1,1,7],[68,23,1,1,7],[67,21,1,1,7],[67,22,1,1,7],[67,23,1,1,7],[66,21,1,1,7],[66,22,1,1,7],[66,23,1,1,7],[65,21,1,1,7],[65,22,1,1,7],[65,23,1,1,7],[64,21,1,1,7],[64,22,1,1,7],[64,23,1,1,7],[63,21,1,1,7],[63,22,1,1,7],[63,23,1,1,7],[62,21,1,1,7],[62,22,1,1,7],[62,23,1,1,7],[62,24,1,1,7],[63,24,1,1,7],[62,25,1,1,7],[63,25,1,1,7],[81,80,1,1,7],[82,80,1,1,7],[81,81,1,1,7],[82,81,1,1,7],[80,80,1,1,7],[80,81,1,1,7],[88,84,1,1,7],[88,85,1,1,7],[88,86,1,1,7],[87,84,1,1,7],[87,85,1,1,7],[87,86,1,1,7],[86,84,1,1,7],[86,85,1,1,7],[86,86,1,1,7],[85,84,1,1,7],[85,85,1,1,7],[85,86,1,1,7],[84,84,1,1,7],[84,85,1,1,7],[84,86,1,1,7],[83,84,1,1,7],[83,85,1,1,7],[83,86,1,1,7],[82,84,1,1,7],[82,85,1,1,7],[82,86,1,1,7],[81,84,1,1,7],[81,83,1,1,7],[82,83,1,1,7],[83,83,1,1,7],[80,83,1,1,7],[80,84,1,1,7],[86,74,1,1,7],[87,74,1,1,7],[86,75,1,1,7],[87,75,1,1,7],[86,76,1,1,7],[87,76,1,1,7],[85,74,1,1,7],[85,75,1,1,7],[85,76,1,1,7],[84,74,1,1,7],[84,75,1,1,7],[84,76,1,1,7],[83,74,1,1,7],[83,75,1,1,7],[83,76,1,1,7],[82,74,1,1,7],[82,75,1,1,7],[82,76,1,1,7],[81,74,1,1,7],[81,75,1,1,7],[81,76,1,1,7],[80,74,1,1,7],[80,75,1,1,7],[80,76,1,1,7],[105,68,1,1,7],[105,69,1,1,7],[104,68,1,1,7],[104,69,1,1,7],[103,68,1,1,7],[103,69,1,1,7],[96,68,1,1,7],[96,69,1,1,7],[95,68,1,1,7],[95,69,1,1,7],[94,68,1,1,7],[94,69,1,1,7],[93,68,1,1,7],[93,69,1,1,7],[103,77,1,1,7],[103,78,1,1,7],[103,79,1,1,7],[104,79,1,1,7]],
	"zones": [[0,0,170,47,"log_yard"],[15,12,140,35,"log_yard"],[29,76,48,18,"saw_hall"],[111,69,32,27,"machine_room"],[59,63,8,9,"drying"],[70,63,8,9,"drying"],[81,63,8,9,"drying"],[65,5,11,10,"log_yard"],[96,6,10,9,"log_yard"],[29,76,48,24,"saw_hall"],[0,0,170,4,"forest_edge"],[0,0,7,102,"forest_edge"],[163,0,7,102,"forest_edge"],[111,69,32,27,"machine_room"]],
	"buildings": [{"name":"제재동","rect":[29,76,48,24]},{"name":"기계실","rect":[111,69,32,27]},{"name":"건조장","rect":[59,63,8,9]},{"name":"건조장","rect":[70,63,8,9]},{"name":"건조장","rect":[81,63,8,9]},{"name":"야적 공구 작업장","rect":[65,5,11,10]},{"name":"야적 정비 작업장","rect":[96,6,10,9]}],
	"walls": [[50,19,2,8],[55,19,2,8],[60,19,2,8],[80,19,2,8],[85,19,2,8],[90,19,2,8],[110,19,2,8],[115,19,2,8],[50,31,2,8],[55,31,2,8],[60,31,2,8],[80,31,2,8],[85,31,2,8],[90,31,2,8],[110,31,2,8],[115,31,2,8],[119,75,15,1],[119,86,15,1],[119,75,1,12],[133,75,1,12],[113,88,12,1],[113,95,12,1],[113,88,1,8],[124,88,1,8],[128,88,13,1],[128,95,13,1],[128,88,1,8],[140,88,1,8],[50,4,2,8],[55,4,2,8],[60,4,2,8],[80,4,2,8],[85,4,2,8],[90,4,2,8],[110,4,2,8],[115,4,2,8],[66,10,9,1],[30,95,46,1],[44,77,1,19],[60,77,1,19],[70,23,2,2]],
	"lows": [[57,40,3,2],[88,38,2,3],[106,35,3,2],[71,31,3,1],[57,55,3,2],[88,56,2,3],[124,78,3,2],[100,63,5,1],[127,59,2,3],[76,16,3,6],[85,16,4,2],[94,17,5,3],[83,79,9,3],[90,84,6,2],[79,85,3,2],[88,74,8,3],[80,89,2,2],[145,73,4,2],[152,72,3,2],[144,77,1,1],[150,66,2,1],[37,80,4,2],[47,82,6,2],[33,86,3,2],[39,84,3,2],[26,90,2,1],[98,72,6,3],[98,76,3,2],[84,73,2,1],[96,23,3,2],[104,77,5,2],[108,72,2,1],[109,74,1,1],[105,74,3,1],[22,80,5,3],[37,72,8,1],[94,79,3,3],[78,14,5,1],[77,12,2,1],[67,8,2,1],[98,9,2,1],[63,80,4,2],[98,79,3,6]],
	"doors": [[119,80,1,"closed"],[133,81,1,"closed"],[118,88,1,"closed"],[134,88,1,"closed"],[127,69,1,"open"],[111,82,1,"open"],[63,63,2,"open"],[74,63,3,"open"],[85,63,4,"open"],[70,5,5,"open"],[70,10,5,"closed"],[101,6,6,"open"],[36,95,0,"open"],[52,95,0,"open"],[68,95,0,"open"],[41,76,0,"open"],[65,76,0,"open"],[53,99,0,"open"]],
	"windows": [[123,69,1],[142,78,1],[116,95,1],[136,95,1],[63,71,2],[74,71,3],[85,71,4],[70,14,5],[101,14,6],[32,76,0],[47,76,0],[63,76,0],[29,88,0],[76,88,0]],
	"trees": [[150,30],[149,70],[147,81],[153,88],[152,21],[146,6],[145,6],[144,6],[147,7],[146,7],[145,7],[144,7],[143,7],[148,8],[147,8],[146,8],[145,8],[144,8],[143,8],[142,8],[148,9],[147,9],[146,9],[145,9],[144,9],[143,9],[142,9],[147,10],[146,10],[145,10],[144,10],[143,10],[146,11],[145,11],[144,11],[30,11],[31,11],[32,11],[29,12],[30,12],[31,12],[32,12],[33,12],[28,13],[29,13],[30,13],[31,13],[32,13],[33,13],[34,13],[28,14],[29,14],[30,14],[31,14],[32,14],[33,14],[34,14],[29,15],[30,15],[31,15],[32,15],[33,15],[30,16],[31,16],[32,16],[161,70],[160,70],[159,70],[162,71],[161,71],[160,71],[159,71],[158,71],[163,72],[162,72],[161,72],[160,72],[159,72],[158,72],[157,72],[163,73],[162,73],[161,73],[160,73],[159,73],[158,73],[157,73],[162,74],[161,74],[160,74],[159,74],[158,74],[161,75],[160,75],[159,75],[114,14],[113,14],[115,15],[114,15],[113,15],[114,16],[154,3],[155,3],[156,3],[153,4],[154,4],[155,4],[156,4],[157,4],[152,5],[153,5],[154,5],[155,5],[156,5],[157,5],[158,5],[152,6],[153,6],[154,6],[155,6],[156,6],[157,6],[158,6],[153,7],[154,7],[155,7],[156,7],[157,7],[154,8],[155,8],[156,8],[160,26],[159,26],[158,26],[161,27],[160,27],[159,27],[158,27],[157,27],[162,28],[161,28],[160,28],[159,28],[158,28],[157,28],[156,28],[162,29],[161,29],[160,29],[159,29],[158,29],[157,29],[156,29],[161,30],[160,30],[159,30],[158,30],[157,30],[160,31],[159,31],[158,31],[22,3],[23,3],[24,3],[21,4],[22,4],[23,4],[24,4],[25,4],[20,5],[21,5],[22,5],[23,5],[24,5],[25,5],[26,5],[20,6],[21,6],[22,6],[23,6],[24,6],[25,6],[26,6],[21,7],[22,7],[23,7],[24,7],[25,7],[22,8],[23,8],[24,8]],
	"containers": [{"id":"machine_bench","name":"기계실 정비대","cell":[130,78],"building":1,"items":["scrap"]},{"id":"machine_parts","name":"안쪽 부품 창고","cell":[122,93],"building":1,"items":["scrap","scrap","scrap"]},{"id":"machine_fuel","name":"안쪽 연료 창고","cell":[138,93],"building":1,"items":["wood","wood","scrap"]},{"id":"machine_corridor","name":"기계실 공구함","cell":[115,74],"building":1,"items":["scrap"]},{"id":"drying_2","name":"건조 판재 상자","cell":[61,69],"building":2,"items":["plank","wood"]},{"id":"drying_3","name":"건조 판재 상자","cell":[72,69],"building":3,"items":["plank","wood"]},{"id":"drying_4","name":"건조 판재 상자","cell":[83,69],"building":4,"items":["plank","wood"]},{"id":"yard_timber","name":"원목 자재함","cell":[55,43],"building":-1,"items":["wood","plank"]},{"id":"yard_boards","name":"야적장 판재 상자","cell":[98,42],"building":-1,"items":["plank","wood"]},{"id":"room_5_b","name":"야적 공구 작업장 안쪽 상자","cell":[67,12],"building":5,"items":["wood","plank"],"level":0},{"id":"room_5_a","name":"야적 공구 작업장 작업 상자","cell":[67,7],"building":5,"items":["wood","plank"],"level":0},{"id":"room_6_a","name":"야적 정비 작업장 작업 상자","cell":[98,8],"building":6,"items":["wood","plank"],"level":0},{"id":"hall_0_0_replace","name":"원목 투입 칸 자재함","cell":[31,93],"building":0,"items":["wood","plank"],"level":0},{"id":"hall_0_1_replace","name":"톱 작업 칸 자재함","cell":[46,93],"building":0,"items":["wood","plank"],"level":0},{"id":"hall_0_2_replace","name":"대패 작업 칸 자재함","cell":[62,93],"building":0,"items":["wood","plank"],"level":0},{"id":"hall_0_corridor_replace","name":"제재동 운반 복도 자재함","cell":[31,97],"building":0,"items":["wood","plank"],"level":0}],
	"salvage": [{"id":"drying_offcuts_2","name":"건조장 자투리 목재","cell":[64,69],"material":"wood","amount":3},{"id":"drying_offcuts_3","name":"건조장 자투리 목재","cell":[75,69],"material":"wood","amount":3},{"id":"drying_offcuts_4","name":"건조장 자투리 목재","cell":[86,69],"material":"wood","amount":3},{"id":"yard_offcuts","name":"야적장 자투리 목재","cell":[79,42],"material":"wood","amount":3},{"id":"work_salvage_4","name":"야적장 자투리 목재","cell":[78,13],"material":"wood","amount":4},{"id":"work_salvage_5","name":"건조장 남은 판재","cell":[91,53],"material":"wood","amount":4},{"id":"work_salvage_6","name":"차량 곁 회수 부품","cell":[82,80],"material":"scrap","amount":2}],
	"entries": {"west_logging":[[0,20],[0,22]],"south_logging":[[89,101],[91,101]],"forest_edge":[[169,37],[169,57],[169,66]]},
	"entry_gap": {"west_logging":0.6,"south_logging":0.6,"forest_edge":0.6},
	"slots": [[52,34],[53,34],[54,34],[82,34],[83,34],[84,34],[67,66],[68,66],[69,66],[78,66],[79,66],[80,66]],
	"deep": [[127,69],[111,82]],
	"labels": [{"text":"원목 야적장","cell":[48,42]},{"text":"제재동","cell":[32,85]}],
	"props": [{"kind":"log_stack_high","rect":[50,4,2,8],"solid":"wall","facing":0,"note":"야적장 높은 원목 더미"},{"kind":"log_stack_high","rect":[55,4,2,8],"solid":"wall","facing":0,"note":"야적장 높은 원목 더미"},{"kind":"log_stack_high","rect":[60,4,2,8],"solid":"wall","facing":0,"note":"야적장 높은 원목 더미"},{"kind":"log_stack_high","rect":[80,4,2,8],"solid":"wall","facing":0,"note":"야적장 높은 원목 더미"},{"kind":"log_stack_high","rect":[85,4,2,8],"solid":"wall","facing":0,"note":"야적장 높은 원목 더미"},{"kind":"log_stack_high","rect":[90,4,2,8],"solid":"wall","facing":0,"note":"야적장 높은 원목 더미"},{"kind":"log_stack_high","rect":[110,4,2,8],"solid":"wall","facing":0,"note":"야적장 높은 원목 더미"},{"kind":"log_stack_high","rect":[115,4,2,8],"solid":"wall","facing":0,"note":"야적장 높은 원목 더미"},{"kind":"plank_stack","rect":[57,40,3,2],"solid":"low","facing":0,"note":"작업 구역의 짧은 판재 더미"},{"kind":"plank_stack","rect":[88,38,2,3],"solid":"low","facing":1,"note":"작업 구역의 짧은 판재 더미"},{"kind":"plank_stack","rect":[106,35,3,2],"solid":"low","facing":0,"note":"작업 구역의 짧은 판재 더미"},{"kind":"firewood_rick","rect":[71,31,3,1],"solid":"low","facing":0,"note":"작업 구역의 짧은 장작 단"},{"kind":"plank_stack","rect":[57,55,3,2],"solid":"low","facing":0,"note":"작업 구역의 짧은 판재 더미"},{"kind":"plank_stack","rect":[88,56,2,3],"solid":"low","facing":1,"note":"작업 구역의 짧은 판재 더미"},{"kind":"plank_stack","rect":[124,78,3,2],"solid":"low","facing":0,"note":"작업 구역의 짧은 판재 더미"},{"kind":"fallen_log","rect":[100,63,5,1],"solid":"low","facing":0,"note":"작업 구역의 짧은 쓰러진 통나무"},{"kind":"plank_stack","rect":[127,59,2,3],"solid":"low","facing":1,"note":"작업 구역의 짧은 판재 더미"},{"kind":"log_stack_low","rect":[76,16,3,6],"solid":"low","facing":0,"note":"원목 야적 작업 무리 · 낮은 원목 더미"},{"kind":"log_cart","rect":[85,16,4,2],"solid":"low","facing":0,"note":"원목 야적 작업 무리 · 원목 수레"},{"kind":"log_scatter","rect":[73,20,3,3],"solid":"none","facing":0,"note":"원목 야적 작업 무리 · 흩어진 통나무 토막"},{"kind":"skidder","rect":[94,17,5,3],"solid":"low","facing":0,"note":"원목 야적 작업 무리 · 집재 트랙터"},{"kind":"jib_crane","rect":[70,23,2,2],"solid":"wall","facing":0,"note":"원목 야적 작업 무리 · 야적 기중기"},{"kind":"log_truck","rect":[83,79,9,3],"solid":"low","facing":0,"note":"하역 마당 차량 무리 · 원목 트럭"},{"kind":"box_truck","rect":[90,84,6,2],"solid":"low","facing":0,"note":"하역 마당 차량 무리 · 상자 트럭"},{"kind":"forklift","rect":[79,85,3,2],"solid":"low","facing":0,"note":"하역 마당 차량 무리 · 지게차"},{"kind":"flat_trailer","rect":[88,74,8,3],"solid":"low","facing":0,"note":"하역 마당 차량 무리 · 평 트레일러"},{"kind":"pallet_stack","rect":[80,89,2,2],"solid":"low","facing":0,"note":"하역 마당 차량 무리 · 팔레트 더미"},{"kind":"farm_tractor","rect":[145,73,4,2],"solid":"low","facing":0,"note":"정비 작업 무리 · 트랙터"},{"kind":"fuel_tank","rect":[152,72,3,2],"solid":"low","facing":0,"note":"정비 작업 무리 · 연료 탱크"},{"kind":"oil_drum","rect":[144,77,1,1],"solid":"low","facing":0,"note":"정비 작업 무리 · 드럼통"},{"kind":"generator","rect":[150,66,2,1],"solid":"low","facing":0,"note":"정비 작업 무리 · 발전기"},{"kind":"scattered_tools","rect":[143,80,2,2],"solid":"none","facing":0,"note":"정비 작업 무리 · 흩어진 연장"},{"kind":"band_saw","rect":[37,80,4,2],"solid":"low","facing":0,"note":"제재 작업 무리 · 띠톱 기계"},{"kind":"log_carriage","rect":[47,82,6,2],"solid":"low","facing":0,"note":"제재 작업 무리 · 원목 대차"},{"kind":"circular_saw_bench","rect":[33,86,3,2],"solid":"low","facing":0,"note":"제재 작업 무리 · 원형톱대"},{"kind":"planer","rect":[39,84,3,2],"solid":"low","facing":0,"note":"제재 작업 무리 · 대패 기계"},{"kind":"tool_bench","rect":[26,90,2,1],"solid":"low","facing":0,"note":"제재 작업 무리 · 연장 작업대"},{"kind":"bark_heap","rect":[46,74,3,2],"solid":"none","facing":0,"note":"제재 작업 무리 · 껍질 더미"},{"kind":"drying_rack","rect":[98,72,6,3],"solid":"low","facing":0,"note":"건조장 운반 무리 · 판재 건조 선반"},{"kind":"plank_stack","rect":[98,76,3,2],"solid":"low","facing":0,"note":"건조장 운반 무리 · 판재 더미"},{"kind":"handcart","rect":[84,73,2,1],"solid":"low","facing":0,"note":"건조장 운반 무리 · 짐수레"},{"kind":"sawdust_bin","rect":[96,23,3,2],"solid":"low","facing":0,"note":"건조장 운반 무리 · 톱밥 통"},{"kind":"scattered_tools","rect":[89,63,2,2],"solid":"none","facing":0,"note":"건조장 운반 무리 · 흩어진 연장"},{"kind":"pickup_truck","rect":[104,77,5,2],"solid":"low","facing":0,"note":"사무동 곁 작업 무리 · 소형 화물차"},{"kind":"sawhorse","rect":[108,72,2,1],"solid":"low","facing":0,"note":"사무동 곁 작업 무리 · 톱질 받침틀"},{"kind":"chopping_block","rect":[109,74,1,1],"solid":"low","facing":0,"note":"사무동 곁 작업 무리 · 장작 토막받침"},{"kind":"firewood_rick","rect":[105,74,3,1],"solid":"low","facing":0,"note":"사무동 곁 작업 무리 · 장작 단"},{"kind":"scattered_tools","rect":[109,78,2,2],"solid":"none","facing":0,"note":"사무동 곁 작업 무리 · 흩어진 연장"},{"kind":"debarker","rect":[22,80,5,3],"solid":"low","facing":0,"note":"원목 들이는 작업장 곁 · 껍질 벗기는 기계"},{"kind":"log_conveyor","rect":[37,72,8,1],"solid":"low","facing":0,"note":"원목 들이는 작업장 곁 · 원목 롤러대"},{"kind":"sawdust_pile","rect":[94,79,3,3],"solid":"low","facing":0,"note":"판재 출구 곁 · 톱밥 더미"},{"kind":"fallen_log","rect":[78,14,5,1],"solid":"low","facing":0,"note":"숲 가장자리 · 쓰러진 통나무"},{"kind":"stump_cluster","rect":[79,15,4,4],"solid":"none","facing":0,"note":"벌목 빈터 · 그루터기 군"},{"kind":"sled_load","rect":[77,12,2,1],"solid":"low","facing":0,"note":"임도 어귀 · 짐 실은 썰매"},{"kind":"tool_bench","rect":[67,8,2,1],"solid":"low","facing":0,"note":"골목 끝 작은 작업장 · 연장 작업대"},{"kind":"scattered_tools","rect":[72,8,2,2],"solid":"none","facing":0,"note":"골목 끝 작은 작업장 · 흩어진 연장"},{"kind":"tool_bench","rect":[98,9,2,1],"solid":"low","facing":0,"note":"골목 끝 작은 작업장 · 연장 작업대"},{"kind":"scattered_tools","rect":[100,10,2,2],"solid":"none","facing":0,"note":"골목 끝 작은 작업장 · 흩어진 연장"},{"kind":"band_saw","rect":[63,80,4,2],"solid":"low","facing":0,"note":"제재동 작업 칸 · 띠톱 기계"},{"kind":"log_stack_low","rect":[98,79,3,6],"solid":"low","facing":0,"note":"차량 회수 작업 옆 원목 엄폐 · 낮은 원목 더미"}],
	"wagons": [],
	"openings": [],
	"stories": [{"level":1,"building":1,"rect":[111,69,32,27],"walls":[[127,70,1,25]],"doors":[[127,82,1,"closed"]],"windows":[[114,69,1],[139,69,1]],"containers":[{"id":"level_1_a","name":"사무실 자재함","cell":[113,93],"building":1,"items":["plank"],"level":1},{"id":"level_1_b","name":"도면실 공구함","cell":[140,93],"building":1,"items":["scrap"],"level":1}]},{"level":-1,"building":1,"rect":[111,69,32,27],"walls":[[127,70,1,25]],"doors":[[127,82,1,"closed"]],"windows":[],"containers":[{"id":"level_-1_a","name":"지하 연료 선반","cell":[113,93],"building":1,"items":["wood","scrap"],"level":-1},{"id":"level_-1_b","name":"지하 부품 선반","cell":[140,93],"building":1,"items":["scrap"],"level":-1}]}],
	"stairs": [{"cell":[113,71],"low":0,"high":1,"ladder":false},{"cell":[114,71],"low":-1,"high":0,"ladder":false}]
}


static func build() -> Dictionary:
	var g := FieldGrid.new(WIDTH, HEIGHT)
	var train := _rect(LAYOUT["train"])
	var platform := Rect2i(train.position.x, train.position.y - 3, 80, 3)
	var unload := Rect2i(train.position.x, train.end.y, 80, 3)
	var data := {
		"grid": g, "levels": {0: g}, "stairs": [], "props": [],
		"containers": {}, "spots": {}, "stoves": [], "entries": {},
		"buildings": [], "wagons": [], "train": train, "platform": platform,
		"spawns": {}, "labels": [], "trees": [], "low_blocks": [], "upper_rects": [],
		"train_cars": [], "lights": [], "manholes": {}, "manhole_levels": {}, "sewer_names": {},
		"entry_levels": {}, "entry_gap": LAYOUT["entry_gap"].duplicate(), "unload": unload,
		"entry_names": ENTRY_NAMES.duplicate(), "entry_weights": ENTRY_WEIGHTS.duplicate(), "first_entry": FIRST_ENTRY, "zone_names": ZONE_NAMES.duplicate(),
		"place_id": PLACE_ID, "place_kind": "sawmill", "bands": {},
		"train_doors": {"upper": [], "lower": []}, "crossings": [], "barricade_slots": [],
		"interior_kind_slots": [{"zone": "machine_room", "kinds": ["empty", "raiders", "nest", "beasts"]}],
	}
	g.zone.fill("drying")
	for row in LAYOUT["floors"]:
		var r := _rect(row)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				g.floor[g.index(Vector2i(x, y))] = int(row[4])
	for id in range(LAYOUT["buildings"].size()):
		var source: Dictionary = LAYOUT["buildings"][id]
		var r := _rect(source["rect"])
		data["buildings"].append({"id": id, "name": source["name"], "rect": r, "warm": false, "window_broken": false})
		for part in source.get("parts", [source["rect"]]):
			_shell(g, _rect(part), id)
	for row in LAYOUT["zones"]:
		var r := _rect(row)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				g.zone[g.index(Vector2i(x, y))] = row[4]
	for row in LAYOUT["walls"]:
		_solid(g, _rect(row), S.WALL)
	for row in LAYOUT["lows"]:
		var r := _rect(row)
		_solid(g, r, S.LOW)
		data["low_blocks"].append(r)
	for row in LAYOUT["doors"]:
		var c := _cell(row)
		g.set_solid(c, S.DOOR)
		g.doors[c] = {"state": row[3], "hp": 8, "building": int(row[2]), "cell": c}
	for row in LAYOUT["windows"]:
		var c := _cell(row)
		g.set_solid(c, S.WINDOW)
		g.windows[c] = {"broken": false, "glass": false, "building": int(row[2]), "cell": c}
	for row in LAYOUT["openings"]:
		g.set_solid(_cell(row), S.NONE)
	for row in LAYOUT["trees"]:
		var c := _cell(row)
		g.set_solid(c, S.BLOCK)
		data["trees"].append(c)
	for source in LAYOUT["props"]:
		data["props"].append({"kind": source["kind"], "rect": _rect(source["rect"]), "solid": source["solid"], "facing": int(source["facing"]), "note": source["note"]})
	for source in LAYOUT["wagons"]:
		var r := _rect(source["rect"])
		data["wagons"].append({"id": source["id"], "name": source["name"], "rect": r, "coal": float(source["coal"])})
		_solid(g, r, S.BLOCK)
	_solid(g, train, S.BLOCK)
	for side in ["upper", "lower"]:
		data["bands"][side] = _rect(LAYOUT["bands"][side])
		var y: int = train.position.y - 1 if side == "upper" else train.end.y
		for dx in [16, 40, 56]:
			data["train_doors"][side].append(Vector2i(train.position.x + dx, y))
	for xx in [train.position.x - 2, train.end.x + 1]:
		var cells: Array[Vector2i] = []
		for yy in range(train.position.y - 1, train.end.y + 1):
			cells.append(Vector2i(xx, yy))
		data["crossings"].append({"cells": cells, "who": {"person": true, "zombie": true, "carrying": true, "wounded": true, "sled": true}})
	for row in LAYOUT["slots"]:
		data["barricade_slots"].append(_cell(row))
	for key in LAYOUT["entries"]:
		data["entries"][key] = []
		for row in LAYOUT["entries"][key]:
			data["entries"][key].append(_cell(row))
	for source in LAYOUT["containers"]:
		var c := _cell(source["cell"])
		data["containers"][source["id"]] = {"id": source["id"], "name": source["name"], "cell": c, "level": 0, "building": int(source["building"]), "search": 4.0, "items": source["items"].duplicate(), "locked": false, "searched": false}
	for source in LAYOUT["salvage"]:
		data["spots"][source["id"]] = {"kind": "salvage", "name": source["name"], "cell": _cell(source["cell"]), "material": source["material"], "amount": int(source["amount"]), "state": "intact"}
	for side in ["upper", "lower"]:
		var r: Rect2i = platform if side == "upper" else unload
		data["spots"]["unload_" + side] = {"kind": "unload", "name": "위쪽 하역 자리" if side == "upper" else "아래쪽 하역 자리", "cell": Vector2i(r.position.x + 40, r.position.y + 1), "state": "open", "zone_rect": r}
	for source in LAYOUT["labels"]:
		data["labels"].append({"text": source["text"], "cell": _cell(source["cell"])})
	data["labels"].append({"text": "기계실", "cell": _cell(LAYOUT["deep"][0])})
	data["spawns"] = {"squad": [Vector2i(train.position.x + 28, train.end.y + 1), Vector2i(train.position.x + 30, train.end.y + 1), Vector2i(train.position.x + 32, train.end.y + 1)], "train_door": data["train_doors"]["lower"].duplicate(), "dead_levels": [], "dead_edges": []}
	for key in data["entries"]:
		data["spawns"]["dead_edges"].append(data["entries"][key][0])
	_lights(data)
	_build_levels(data)
	g.refresh_paths()
	return data


static func _rect(row: Array) -> Rect2i:
	return Rect2i(int(row[0]), int(row[1]), int(row[2]), int(row[3]))


static func _cell(row: Array) -> Vector2i:
	return Vector2i(int(row[0]), int(row[1]))


static func _solid(g: FieldGrid, r: Rect2i, kind: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			g.set_solid(Vector2i(x, y), kind)


static func _lights(data: Dictionary) -> void:
	var train: Rect2i = data["train"]
	for k in range(5):
		var r := Rect2i(train.position.x + k * 16, train.position.y, 16, 3)
		data["train_cars"].append({"rect": r, "kind": "car" if k < 4 else "engine"})
		if k == 4:
			data["lights"].append({"id": "firebox", "kind": "firebox", "cell": Vector2i(r.position.x + 2, r.end.y - 1), "side": Vector2i(0, 1), "strength": 0.8, "falls": 0.8, "reach": 4.0, "when": "always", "from_min": 0})
			continue
		for side in [-1, 1]:
			for n in range(2):
				var y: int = r.position.y if side < 0 else r.end.y - 1
				data["lights"].append({"id": "car_%d_%d_%d" % [k, side, n], "kind": "car_window", "cell": Vector2i(r.position.x + 4 + n * 6, y), "side": Vector2i(0, side), "strength": 1.0, "falls": 0.6, "reach": 3.0, "when": "dusk", "from_min": 890})


## Parts share one building id; only their own footprints receive floors.
static func _shell(g: FieldGrid, r: Rect2i, id: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			g.building[g.index(c)] = id
			g.floor[g.index(c)] = F.WOOD
			var edge: bool = x == r.position.x or y == r.position.y or x == r.end.x - 1 or y == r.end.y - 1
			g.set_solid(c, S.WALL if edge else S.NONE)


## The same cell joins levels, matching the base map's stairs contract.
static func _build_levels(data: Dictionary) -> void:
	for source in LAYOUT["stories"]:
		var level: int = int(source["level"])
		var id: int = int(source["building"])
		var lg := FieldGrid.new(WIDTH, HEIGHT)
		lg.solid.fill(S.AIR if level > 0 else S.BLOCK)
		var r := _rect(source["rect"])
		_shell(lg, r, id)
		if level > 0:
			data["upper_rects"].append({"building": id, "rect": r})
		else:
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					lg.floor[lg.index(Vector2i(x, y))] = F.GRAVEL
		for row in source["walls"]:
			_solid(lg, _rect(row), S.WALL)
		for row in source["doors"]:
			var c := _cell(row)
			lg.set_solid(c, S.DOOR)
			lg.doors[c] = {"state": row[3], "hp": 8, "building": id, "cell": c}
		for row in source["windows"]:
			var c := _cell(row)
			lg.set_solid(c, S.WINDOW)
			lg.windows[c] = {"broken": false, "glass": false, "building": id, "cell": c}
		for item in source["containers"]:
			data["containers"][item["id"]] = {"id": item["id"], "name": item["name"], "cell": _cell(item["cell"]), "level": level, "building": id, "search": 4.0, "items": item["items"].duplicate(), "locked": false, "searched": false}
		lg.refresh_paths()
		data["levels"][level] = lg
	for row in LAYOUT["stairs"]:
		data["stairs"].append({"cell": _cell(row["cell"]), "low": int(row["low"]), "high": int(row["high"]), "ladder": false})
