# 이 지도가 다른 판단을 만드는 것: 지연물이 없는 북서쪽을 지키면 북동쪽 숲이 비므로 방벽에 맡길 곳을 정한다.
extends RefCounted
## 북동쪽 반만 숲이고 북서쪽은 도랑 없이 열려 있다. 좌표는 이 파일 안에서 조립한다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 138
const HEIGHT: int = 82
const PLACE_ID: String = "bare_line_03"
const ZONE_NAMES: Dictionary = {"track_bank": "선로 둑", "forest_side": "숲 가장자리", "open_side": "트인 눈밭"}
const ENTRY_NAMES: Dictionary = {"track_west_upper":"서쪽 선로, 위 눈밭 쪽","track_east_upper":"동쪽 선로, 숲 쪽","track_west_lower":"서쪽 선로, 아래 눈밭 쪽","track_east_lower":"동쪽 선로, 눈밭 쪽","forest_edge":"숲 가장자리","forest_gap":"숲이 끊긴 자리","open_field":"트인 눈밭"}
const ENTRY_WEIGHTS: Dictionary = {"track_west_upper":1.5,"track_east_upper":1.5,"track_west_lower":1.5,"track_east_lower":1.5,"forest_edge":1,"forest_gap":1,"open_field":1}
const FIRST_ENTRY: String = "track_east_upper"
const PLAN: Dictionary = {
	"train": [29,40,80,3],
	"forest": "east",
	"house": [18,72,8,6],
	"house_door": [22,72],
	"windows": [
		[18,74]
	],
	"floors": [
		{"rect":[0,10,11,3],"kind":5},
		{"rect":[18,8,11,3],"kind":5},
		{"rect":[36,6,11,3],"kind":5},
		{"rect":[54,5,11,3],"kind":5},
		{"rect":[72,6,11,3],"kind":5},
		{"rect":[90,8,11,3],"kind":5},
		{"rect":[108,10,11,3],"kind":5},
		{"rect":[126,11,11,3],"kind":5},
		{"rect":[0,24,13,3],"kind":5},
		{"rect":[18,21,13,3],"kind":5},
		{"rect":[36,19,13,3],"kind":5},
		{"rect":[54,19,13,3],"kind":5},
		{"rect":[72,20,13,3],"kind":5},
		{"rect":[90,23,13,3],"kind":5},
		{"rect":[108,25,13,3],"kind":5},
		{"rect":[126,25,12,3],"kind":5},
		{"rect":[0,57,11,3],"kind":5},
		{"rect":[18,55,11,3],"kind":5},
		{"rect":[36,54,11,3],"kind":5},
		{"rect":[54,55,11,3],"kind":5},
		{"rect":[72,57,11,3],"kind":5},
		{"rect":[90,59,11,3],"kind":5},
		{"rect":[108,60,11,3],"kind":5},
		{"rect":[126,59,11,3],"kind":5},
		{"rect":[0,73,13,3],"kind":5},
		{"rect":[18,71,13,3],"kind":5},
		{"rect":[36,71,13,3],"kind":5},
		{"rect":[54,72,13,3],"kind":5},
		{"rect":[72,75,13,3],"kind":5},
		{"rect":[90,77,13,3],"kind":5},
		{"rect":[108,77,13,3],"kind":5},
		{"rect":[126,76,12,3],"kind":5},
		{"rect":[21,71,20,1],"kind":5},
		{"rect":[38,57,3,15],"kind":5},
		{"rect":[38,57,7,1],"kind":5},
		{"rect":[42,43,3,15],"kind":5},
		{"rect":[21,71,51,1],"kind":5},
		{"rect":[69,59,3,13],"kind":5},
		{"rect":[69,59,12,1],"kind":5},
		{"rect":[78,43,3,17],"kind":5},
		{"rect":[117,0,3,23],"kind":5},
		{"rect":[101,22,19,1],"kind":5},
		{"rect":[101,22,3,17],"kind":5},
		{"rect":[70,0,3,22],"kind":5},
		{"rect":[70,21,17,1],"kind":5},
		{"rect":[84,21,3,18],"kind":5},
		{"rect":[112,70,3,12],"kind":5},
		{"rect":[112,75,3,2],"kind":0},
		{"rect":[93,70,22,1],"kind":5},
		{"rect":[93,59,3,12],"kind":5},
		{"rect":[93,64,3,2],"kind":0},
		{"rect":[78,59,18,1],"kind":5},
		{"rect":[78,43,3,17],"kind":5},
		{"rect":[86,33,6,3],"kind":7},
		{"rect":[103,33,5,4],"kind":7},
		{"rect":[80,46,5,4],"kind":7}
	],
	"props": [
		{"kind":"sleeper_stack","rect":[83,34,1,3],"solid":"low","facing":1,"note":"둑의 침목 더미"},
		{"kind":"rail_stack","rect":[87,34,4,1],"solid":"low","facing":0,"note":"둑의 레일 토막 더미"},
		{"kind":"crate_stack","rect":[99,34,2,2],"solid":"low","facing":0,"note":"둑의 자재 상자 더미"},
		{"kind":"ballast_pile","rect":[104,34,3,2],"solid":"low","facing":0,"note":"둑의 자갈 더미"},
		{"kind":"sleeper_stack","rect":[41,46,1,3],"solid":"low","facing":1,"note":"둑의 침목 더미"},
		{"kind":"crate_stack","rect":[45,47,2,2],"solid":"low","facing":0,"note":"둑의 자재 상자 더미"},
		{"kind":"fallen_signal","rect":[73,48,5,1],"solid":"low","facing":0,"note":"둑의 쓰러진 신호기"},
		{"kind":"rail_handcar","rect":[81,47,3,2],"solid":"low","facing":0,"note":"둑의 수동차"},
		{"kind":"plank_bridge","rect":[84,31,2,3],"solid":"none","facing":0,"note":"도랑을 건너는 널다리"},
		{"kind":"plank_bridge","rect":[101,31,2,3],"solid":"none","facing":0,"note":"도랑을 건너는 널다리"},
		{"kind":"plank_bridge","rect":[42,49,2,3],"solid":"none","facing":0,"note":"도랑을 건너는 널다리"},
		{"kind":"plank_bridge","rect":[78,49,2,3],"solid":"none","facing":0,"note":"도랑을 건너는 널다리"},
		{"kind":"snow_fence","rect":[15,65,5,1],"solid":"low","facing":0,"note":"트인 눈밭의 짧은 눈막이"},
		{"kind":"snow_drift","rect":[16,67,4,2],"solid":"none","facing":0,"note":"울타리 뒤에 쌓인 눈"},
		{"kind":"snow_fence","rect":[47,65,5,1],"solid":"low","facing":0,"note":"트인 눈밭의 짧은 눈막이"},
		{"kind":"snow_drift","rect":[48,67,4,2],"solid":"none","facing":0,"note":"울타리 뒤에 쌓인 눈"},
		{"kind":"snow_fence","rect":[79,65,5,1],"solid":"low","facing":0,"note":"트인 눈밭의 짧은 눈막이"},
		{"kind":"snow_drift","rect":[80,67,4,2],"solid":"none","facing":0,"note":"울타리 뒤에 쌓인 눈"},
		{"kind":"snow_fence","rect":[32,66,5,1],"solid":"low","facing":0,"note":"트인 눈밭의 짧은 눈막이"},
		{"kind":"snow_drift","rect":[33,68,4,2],"solid":"none","facing":0,"note":"울타리 뒤에 쌓인 눈"},
		{"kind":"snow_fence","rect":[63,66,5,1],"solid":"low","facing":0,"note":"트인 눈밭의 짧은 눈막이"},
		{"kind":"snow_drift","rect":[64,68,4,2],"solid":"none","facing":0,"note":"울타리 뒤에 쌓인 눈"},
		{"kind":"shelf","rect":[19,73,3,1],"solid":"low","facing":0,"note":"창고 안 선반"},
		{"kind":"tool_bench","rect":[23,73,2,1],"solid":"low","facing":0,"note":"창고 안 연장 작업대"},
		{"kind":"tool_rack","rect":[27,74,2,1],"solid":"low","facing":0,"note":"연장 걸이"},
		{"kind":"crate_stack","rect":[29,75,2,2],"solid":"low","facing":0,"note":"자재 상자 더미"},
		{"kind":"fuel_drum","rect":[28,78,1,1],"solid":"low","facing":0,"note":"연료 드럼"},
		{"kind":"fuel_drum","rect":[30,79,1,1],"solid":"low","facing":0,"note":"연료 드럼"},
		{"kind":"firewood_pile","rect":[20,79,2,1],"solid":"low","facing":0,"note":"장작 더미"},
		{"kind":"sleeper_stack","rect":[14,78,3,1],"solid":"low","facing":0,"note":"침목 더미"},
		{"kind":"power_pole","rect":[15,16,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"power_pole","rect":[29,16,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"power_pole","rect":[43,16,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"power_pole","rect":[57,16,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"fallen_pole","rect":[71,16,5,1],"solid":"low","facing":0,"note":"끊긴 전신주 줄의 쓰러진 기둥"},
		{"kind":"power_pole","rect":[85,16,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"power_pole","rect":[99,16,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"power_pole","rect":[113,16,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"power_pole","rect":[127,16,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"wire_coil","rect":[31,14,1,1],"solid":"low","facing":0,"note":"전신주 밑의 전선 타래"},
		{"kind":"rail_marker","rect":[27,36,1,1],"solid":"none","facing":0,"note":"자갈 둑의 거리 말뚝"},
		{"kind":"wire_coil","rect":[101,14,1,1],"solid":"low","facing":0,"note":"전신주 밑의 전선 타래"},
		{"kind":"rail_marker","rect":[99,36,1,1],"solid":"none","facing":0,"note":"자갈 둑의 거리 말뚝"},
		{"kind":"fallen_log","rect":[110,7,5,1],"solid":"low","facing":0,"note":"숲 가장자리의 쓰러진 통나무"},
		{"kind":"firewood_pile","rect":[117,9,2,1],"solid":"low","facing":0,"note":"통나무 곁의 장작"},
		{"kind":"snow_drift","rect":[110,10,4,2],"solid":"none","facing":0,"note":"숲 그늘에 쌓인 눈"},
		{"kind":"signal_post","rect":[5,36,1,1],"solid":"wall","facing":0,"note":"서쪽 선로 곁 기둥 신호등"},
		{"kind":"rail_marker","rect":[7,38,1,1],"solid":"none","facing":0,"note":"선로 점검 길 거리 말뚝"},
		{"kind":"sled_load","rect":[3,39,2,1],"solid":"low","facing":0,"note":"선로 점검을 마친 썰매"},
		{"kind":"snow_bank","rect":[114,35,6,1],"solid":"low","facing":0,"note":"도랑과 둑 사이에 밀어 둔 눈"}
	],
	"trees": [
		[79,3],
		[81,4],
		[77,2],
		[77,7],
		[77,6],
		[74,4],
		[76,3],
		[75,4],
		[79,4],
		[79,5],
		[74,5],
		[96,5],
		[96,1],
		[91,7],
		[92,7],
		[97,2],
		[97,3],
		[90,5],
		[93,6],
		[97,4],
		[93,7],
		[89,3],
		[113,4],
		[109,6],
		[109,9],
		[105,6],
		[113,9],
		[113,8],
		[106,7],
		[108,8],
		[106,5],
		[111,9],
		[107,4],
		[128,7],
		[130,1],
		[129,1],
		[127,3],
		[131,4],
		[129,6],
		[124,5],
		[126,5],
		[127,6],
		[129,2],
		[133,3],
		[130,10],
		[136,10],
		[130,15],
		[135,16],
		[132,10],
		[131,15],
		[136,11],
		[129,12],
		[136,15],
		[135,10],
		[133,11],
		[116,18],
		[115,17],
		[123,16],
		[116,19],
		[116,15],
		[120,16],
		[123,18],
		[121,18],
		[120,17],
		[115,19],
		[122,18],
		[104,19],
		[106,24],
		[100,23],
		[104,24],
		[102,21],
		[108,23],
		[105,26],
		[104,20],
		[102,20],
		[106,21],
		[109,24],
		[90,22],
		[86,19],
		[83,22],
		[92,24],
		[89,20],
		[88,24],
		[84,20],
		[89,24],
		[91,24],
		[88,20],
		[88,25],
		[74,22],
		[76,19],
		[78,20],
		[74,20],
		[75,19],
		[75,18],
		[73,17],
		[80,18],
		[73,15],
		[76,16],
		[76,20],
		[120,25],
		[119,25],
		[125,23],
		[123,27],
		[123,25],
		[127,24],
		[124,27],
		[120,23],
		[128,23],
		[126,23],
		[126,26],
		[99,11],
		[97,12],
		[99,9],
		[95,12],
		[100,12],
		[105,12],
		[96,12],
		[103,10],
		[101,10],
		[100,10],
		[99,10],
		[81,15],
		[83,15],
		[84,16],
		[85,11],
		[83,16],
		[87,16],
		[81,12],
		[84,10],
		[86,15],
		[86,14],
		[87,13]
	],
	"slow_rects": [
		[70,31,14,3],
		[87,31,14,3],
		[104,31,22,3],
		[14,49,27,3],
		[45,49,31,3],
		[82,49,38,3]
	],
	"gates": [
		[84,34,3,1],
		[101,34,3,1],
		[42,48,3,1],
		[78,48,3,1]
	],
	"entries": {"track_west_upper":[[0,37],[0,38],[0,39]],"track_east_upper":[[137,37],[137,38],[137,39]],"track_west_lower":[[0,43],[0,44],[0,45]],"track_east_lower":[[137,43],[137,44],[137,45]],"forest_edge":[[117,0],[118,0],[119,0]],"forest_gap":[[70,0],[71,0]],"open_field":[[112,81],[113,81],[114,81],[115,81]]},
	"dead_forest": [
		[128,16],
		[96,14],
		[71,14],
		[118,15]
	],
	"dead_field": [
		[11,74],
		[86,76],
		[131,72]
	],
	"stores": [
		{"id":"tools","name":"연장 궤","cell":[20,75],"items":["scrap","scrap","plank","plank","bandage"]},
		{"id":"track_supplies","name":"보선 자재 상자","cell":[24,75],"items":["wood","wood","flare","cloth","food_pack"]}
	],
	"salvage": [
		{"id":"recover_sleeper_stack","name":"침목 뜯는 자리","cell":[82,34],"material":"wood","amount":3},
		{"id":"recover_rail_stack","name":"레일 토막 회수 자리","cell":[87,33],"material":"scrap","amount":2},
		{"id":"recover_fallen_signal","name":"신호기 회수 자리","cell":[73,47],"material":"scrap","amount":1},
		{"id":"recover_fallen_pole","name":"쓰러진 기둥 뜯는 자리","cell":[71,15],"material":"wood","amount":2},
		{"id":"recover_fallen_log","name":"통나무 뜯는 자리","cell":[110,6],"material":"wood","amount":2}
	]
}


static func _r(a: Array) -> Rect2i:
	return Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))


static func _c(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


static func _paint(g: FieldGrid, r: Rect2i, solid: int = -1, floor_kind: int = -1, building: int = -2) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			if solid >= 0:
				g.set_solid(c, solid)
			if floor_kind >= 0:
				g.floor[g.index(c)] = floor_kind
			if building >= -1:
				g.building[g.index(c)] = building


static func build() -> Dictionary:
	var g := FieldGrid.new(WIDTH, HEIGHT)
	var train := _r(PLAN["train"])
	var data: Dictionary = {
		"grid": g, "levels": {0: g}, "stairs": [],
		"containers": {}, "spots": {}, "stoves": [], "entries": {},
		"buildings": [], "wagons": [], "train": train,
		"platform": Rect2i(train.position.x, train.end.y, 80, 3),
		"spawns": {}, "labels": [], "trees": [], "low_blocks": [], "upper_rects": [],
		"train_cars": [], "lights": [], "manholes": {}, "manhole_levels": {}, "sewer_names": {},
		"entry_levels": {}, "entry_gap": {},
		"entry_names": ENTRY_NAMES.duplicate(), "entry_weights": ENTRY_WEIGHTS.duplicate(),
		"first_entry": FIRST_ENTRY, "zone_names": ZONE_NAMES.duplicate(),
		"unload": Rect2i(train.position.x, train.position.y - 3, 80, 9),
		"place_id": PLACE_ID, "place_kind": "bare_line",
		"bands": {
			"upper": Rect2i(train.position.x - 20, train.position.y - 22, 120, 22),
			"lower": Rect2i(train.position.x - 20, train.end.y, 120, 22),
		},
		"train_doors": {"upper": [], "lower": []}, "crossings": [], "barricade_slots": [],
		"interior_kind_slots": [], "props": [], "slow_rects": [],
	}
	# 바람에 쌓인 눈과 발자국 길을 먼저 칠하고, 도랑과 본선은 뒤에서 보존한다.
	for row: Dictionary in PLAN["floors"]:
		_paint(g, _r(row["rect"]), -1, int(row["kind"]))
	var house := _r(PLAN["house"])
	_paint(g, house, S.WALL, F.WOOD, 0)
	_paint(g, house.grow(-1), S.NONE)
	var door := _c(PLAN["house_door"])
	g.set_solid(door, S.DOOR)
	g.doors[door] = {"state": "closed", "hp": 8, "building": 0, "cell": door}
	for a: Array in PLAN["windows"]:
		var c := _c(a)
		g.set_solid(c, S.WINDOW)
		g.windows[c] = {"broken": false, "glass": false, "building": 0, "cell": c}
	data["buildings"].append({
		"id": 0, "name": "선로 창고", "rect": house, "warm": false, "window_broken": false,
		"rooms": [{"name": "연장 칸", "rect": house.grow(-1)}],
	})
	data["labels"].append({"text": "선로 창고", "cell": house.position, "level": 0})
	data["labels"].append({"text": "연장 칸", "cell": house.position + Vector2i(4, 2), "level": 0})
	for row: Dictionary in PLAN["props"]:
		var prop: Dictionary = row.duplicate(true)
		var r := _r(row["rect"])
		prop["rect"] = r
		data["props"].append(prop)
		match String(row["solid"]):
			"low":
				_paint(g, r, S.LOW)
				data["low_blocks"].append(r)
			"wall":
				_paint(g, r, S.WALL)
		if row["kind"] == "snow_drift":
			_paint(g, r, -1, F.DEEP_SNOW)
		elif row["kind"] == "plank_bridge":
			_paint(g, r, -1, F.GRAVEL)
	for a: Array in PLAN["trees"]:
		var c := _c(a)
		g.set_solid(c, S.BLOCK)
		data["trees"].append(c)
	var stove := house.position + Vector2i(1, 4)
	g.set_solid(stove, S.LOW)
	data["stoves"].append({"cell": stove, "building": 0, "level": 0, "lit": false, "upstairs": false})
	for a: Array in PLAN["slow_rects"]:
		var r := _r(a)
		_paint(g, r, -1, F.SNOW)
		data["slow_rects"].append(r)
	# 석 줄 본선과 양옆 석 줄은 지도 가장자리까지 이어진다.
	_paint(g, Rect2i(0, train.position.y, WIDTH, 3), -1, F.RAIL)
	_paint(g, Rect2i(0, train.position.y - 3, WIDTH, 3), -1, F.GRAVEL)
	_paint(g, Rect2i(0, train.end.y, WIDTH, 3), -1, F.GRAVEL)
	_paint(g, train, S.BLOCK)
	for offset: int in [8, 40, 56]:
		var x: int = train.position.x + offset
		data["train_doors"]["upper"].append(Vector2i(x, train.position.y - 1))
		data["train_doors"]["lower"].append(Vector2i(x, train.end.y))
	for offset: int in [16, 32, 48]:
		var x: int = train.position.x + offset
		data["crossings"].append({
			"cells": [Vector2i(x, train.position.y), Vector2i(x, train.position.y + 1), Vector2i(x, train.position.y + 2)],
			"who": {"person": true, "zombie": false, "carrying": true, "wounded": false, "sled": false},
		})
	for a: Array in PLAN["gates"]:
		var r := _r(a)
		for x in range(r.position.x, r.end.x):
			data["barricade_slots"].append(Vector2i(x, r.position.y))
	for name: String in PLAN["entries"]:
		var cells: Array[Vector2i] = []
		for a: Array in PLAN["entries"][name]:
			cells.append(_c(a))
		data["entries"][name] = cells
		data["entry_levels"][name] = 0
		data["entry_gap"][name] = 2.0 if name.begins_with("forest_") else 0.6
	var forest_dead: Array[Vector2i] = []
	var field_dead: Array[Vector2i] = []
	for a: Array in PLAN["dead_forest"]:
		forest_dead.append(_c(a))
	for a: Array in PLAN["dead_field"]:
		field_dead.append(_c(a))
	data["spawns"] = {
		"squad": [Vector2i(train.position.x + 39, train.end.y + 1), Vector2i(train.position.x + 40, train.end.y + 1), Vector2i(train.position.x + 41, train.end.y + 1), Vector2i(train.position.x + 42, train.end.y + 1)],
		"train_door": data["train_doors"]["lower"] + data["train_doors"]["upper"],
		"dead_forest": forest_dead, "dead_field": field_dead, "dead_levels": [],
	}
	for row: Dictionary in PLAN["stores"]:
		var c := _c(row["cell"])
		data["containers"][row["id"]] = {"id": row["id"], "name": row["name"], "cell": c, "level": 0, "building": g.building_at(c), "search": 5, "items": row["items"].duplicate(), "locked": false, "searched": false}
	for row: Dictionary in PLAN["salvage"]:
		data["spots"][row["id"]] = {"kind": "salvage", "name": row["name"], "cell": _c(row["cell"]), "material": row["material"], "amount": row["amount"], "state": "intact"}
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var zone: String = "open_side"
			var forest: bool = (y < train.position.y + 1) if PLAN["forest"] != "lower" else (y > train.position.y + 1)
			if PLAN["forest"] == "east":
				forest = forest and x * 2 >= WIDTH
			if forest:
				zone = "forest_side"
			if y >= train.position.y - 10 and y < train.end.y + 10:
				zone = "track_bank"
			g.zone[g.index(Vector2i(x, y))] = zone
	_train_lights(data)
	g.refresh_paths()
	return data


static func _train_lights(data: Dictionary) -> void:
	var train: Rect2i = data["train"]
	for k in range(5):
		var r := Rect2i(train.position.x + k * 16, train.position.y, 16, 3)
		data["train_cars"].append({"rect": r, "kind": "car" if k < 4 else "engine"})
		if k == 4:
			data["lights"].append({"id": "firebox", "kind": "firebox", "cell": Vector2i(r.position.x + 2, r.end.y - 1), "side": Vector2i(0, 1), "strength": 0.8, "falls": 0.8, "reach": 4.0, "when": "always", "from_min": 0})
			continue
		for side: int in [-1, 1]:
			var y := r.position.y if side < 0 else r.end.y - 1
			for w in range(4):
				data["lights"].append({"id": "car%d_%d_window%d" % [k + 1, side, w + 1], "kind": "car_window", "cell": Vector2i(r.position.x + 3 + w * 3, y), "side": Vector2i(0, side), "strength": 1.0, "falls": 0.6, "reach": 3.0, "when": "dusk", "from_min": 890})
