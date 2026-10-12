# 이 지도가 다른 판단을 만드는 것: 숲 속 창고에 보낼 사람과 트인 눈밭을 지킬 사람을 나눈다.
extends RefCounted
## 얕은 도랑과 작은 보선 창고가 있는 땅 위 지도. 좌표는 이 파일 안에서 조립한다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 140
const HEIGHT: int = 80
const PLACE_ID: String = "bare_line_01"
const ZONE_NAMES: Dictionary = {"track_bank": "선로 둑", "forest_side": "숲 가장자리", "open_side": "트인 눈밭"}
const ENTRY_NAMES: Dictionary = {"track_west_upper":"서쪽 선로, 숲 쪽","track_east_upper":"동쪽 선로, 숲 쪽","track_west_lower":"서쪽 선로, 눈밭 쪽","track_east_lower":"동쪽 선로, 눈밭 쪽","forest_edge":"숲 가장자리","open_field":"트인 눈밭"}
const ENTRY_WEIGHTS: Dictionary = {"track_west_upper":1.5,"track_east_upper":1.5,"track_west_lower":1.5,"track_east_lower":1.5,"forest_edge":1,"open_field":1}
const FIRST_ENTRY: String = "track_west_upper"
const PLAN: Dictionary = {
	"train": [30,38,80,3],
	"forest": "upper",
	"house": [20,5,8,6],
	"house_door": [24,10],
	"windows": [
		[20,7]
	],
	"floors": [
		{"rect":[0,10,11,3],"kind":5},
		{"rect":[18,11,11,3],"kind":5},
		{"rect":[36,10,11,3],"kind":5},
		{"rect":[54,8,11,3],"kind":5},
		{"rect":[72,6,11,3],"kind":5},
		{"rect":[90,5,11,3],"kind":5},
		{"rect":[108,6,11,3],"kind":5},
		{"rect":[126,8,11,3],"kind":5},
		{"rect":[0,25,13,3],"kind":5},
		{"rect":[18,25,13,3],"kind":5},
		{"rect":[36,23,13,3],"kind":5},
		{"rect":[54,21,13,3],"kind":5},
		{"rect":[72,19,13,3],"kind":5},
		{"rect":[90,19,13,3],"kind":5},
		{"rect":[108,21,13,3],"kind":5},
		{"rect":[126,23,13,3],"kind":5},
		{"rect":[0,58,11,3],"kind":5},
		{"rect":[18,57,11,3],"kind":5},
		{"rect":[36,55,11,3],"kind":5},
		{"rect":[54,53,11,3],"kind":5},
		{"rect":[72,52,11,3],"kind":5},
		{"rect":[90,53,11,3],"kind":5},
		{"rect":[108,55,11,3],"kind":5},
		{"rect":[126,57,11,3],"kind":5},
		{"rect":[0,75,13,3],"kind":5},
		{"rect":[18,73,13,3],"kind":5},
		{"rect":[36,71,13,3],"kind":5},
		{"rect":[54,69,13,3],"kind":5},
		{"rect":[72,69,13,3],"kind":5},
		{"rect":[90,71,13,3],"kind":5},
		{"rect":[108,73,13,3],"kind":5},
		{"rect":[126,75,13,3],"kind":5},
		{"rect":[23,11,3,9],"kind":5},
		{"rect":[23,19,23,1],"kind":5},
		{"rect":[43,19,3,18],"kind":5},
		{"rect":[23,19,38,1],"kind":5},
		{"rect":[58,11,3,13],"kind":5},
		{"rect":[58,23,21,1],"kind":5},
		{"rect":[76,23,3,14],"kind":5},
		{"rect":[91,0,3,21],"kind":5},
		{"rect":[76,20,18,1],"kind":5},
		{"rect":[76,20,3,17],"kind":5},
		{"rect":[108,70,3,10],"kind":5},
		{"rect":[108,75,3,2],"kind":0},
		{"rect":[95,70,16,1],"kind":5},
		{"rect":[95,57,3,14],"kind":5},
		{"rect":[95,62,3,2],"kind":0},
		{"rect":[75,57,23,1],"kind":5},
		{"rect":[75,41,3,17],"kind":5},
		{"rect":[75,46,3,2],"kind":0},
		{"rect":[75,55,3,2],"kind":0},
		{"rect":[72,31,5,4],"kind":7},
		{"rect":[77,44,5,4],"kind":7},
		{"rect":[13,33,6,3],"kind":7}
	],
	"props": [
		{"kind":"sleeper_stack","rect":[42,32,1,3],"solid":"low","facing":1,"note":"둑의 침목 더미"},
		{"kind":"fallen_signal","rect":[46,32,5,1],"solid":"low","facing":0,"note":"둑의 쓰러진 신호기"},
		{"kind":"rail_handcar","rect":[73,32,3,2],"solid":"low","facing":0,"note":"둑의 수동차"},
		{"kind":"crate_stack","rect":[79,32,2,2],"solid":"low","facing":0,"note":"둑의 자재 상자 더미"},
		{"kind":"sleeper_stack","rect":[36,44,1,3],"solid":"low","facing":1,"note":"둑의 침목 더미"},
		{"kind":"crate_stack","rect":[40,45,2,2],"solid":"low","facing":0,"note":"둑의 자재 상자 더미"},
		{"kind":"snow_bank","rect":[69,46,6,1],"solid":"low","facing":0,"note":"둑의 눈 둑"},
		{"kind":"ballast_pile","rect":[78,45,3,2],"solid":"low","facing":0,"note":"둑의 자갈 더미"},
		{"kind":"plank_bridge","rect":[43,29,2,3],"solid":"none","facing":0,"note":"도랑을 건너는 널다리"},
		{"kind":"plank_bridge","rect":[76,29,2,3],"solid":"none","facing":0,"note":"도랑을 건너는 널다리"},
		{"kind":"plank_bridge","rect":[37,47,2,3],"solid":"none","facing":0,"note":"도랑을 건너는 널다리"},
		{"kind":"plank_bridge","rect":[75,47,2,3],"solid":"none","facing":0,"note":"도랑을 건너는 널다리"},
		{"kind":"snow_fence","rect":[24,60,5,1],"solid":"low","facing":0,"note":"트인 눈밭의 짧은 눈막이"},
		{"kind":"snow_drift","rect":[25,62,4,2],"solid":"none","facing":0,"note":"울타리 뒤에 쌓인 눈"},
		{"kind":"snow_fence","rect":[55,64,5,1],"solid":"low","facing":0,"note":"트인 눈밭의 짧은 눈막이"},
		{"kind":"snow_drift","rect":[56,66,4,2],"solid":"none","facing":0,"note":"울타리 뒤에 쌓인 눈"},
		{"kind":"snow_fence","rect":[99,63,5,1],"solid":"low","facing":0,"note":"트인 눈밭의 짧은 눈막이"},
		{"kind":"snow_drift","rect":[100,65,4,2],"solid":"none","facing":0,"note":"울타리 뒤에 쌓인 눈"},
		{"kind":"shelf","rect":[21,6,3,1],"solid":"low","facing":0,"note":"창고 안 선반"},
		{"kind":"tool_bench","rect":[25,6,2,1],"solid":"low","facing":0,"note":"창고 안 연장 작업대"},
		{"kind":"tool_rack","rect":[28,8,2,1],"solid":"low","facing":0,"note":"연장 걸이"},
		{"kind":"crate_stack","rect":[30,11,2,2],"solid":"low","facing":0,"note":"자재 상자 더미"},
		{"kind":"fuel_drum","rect":[28,13,1,1],"solid":"low","facing":0,"note":"연료 드럼"},
		{"kind":"fuel_drum","rect":[30,14,1,1],"solid":"low","facing":0,"note":"연료 드럼"},
		{"kind":"firewood_pile","rect":[22,12,2,1],"solid":"low","facing":0,"note":"장작 더미"},
		{"kind":"sleeper_stack","rect":[16,12,3,1],"solid":"low","facing":0,"note":"침목 더미"},
		{"kind":"power_pole","rect":[15,65,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"power_pole","rect":[29,65,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"power_pole","rect":[43,65,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"power_pole","rect":[57,65,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"fallen_pole","rect":[71,65,5,1],"solid":"low","facing":0,"note":"끊긴 전신주 줄의 쓰러진 기둥"},
		{"kind":"power_pole","rect":[85,65,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"power_pole","rect":[99,65,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"power_pole","rect":[113,65,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"power_pole","rect":[127,65,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"wire_coil","rect":[31,67,1,1],"solid":"low","facing":0,"note":"전신주 밑의 전선 타래"},
		{"kind":"rail_marker","rect":[27,44,1,1],"solid":"none","facing":0,"note":"자갈 둑의 거리 말뚝"},
		{"kind":"wire_coil","rect":[101,67,1,1],"solid":"low","facing":0,"note":"전신주 밑의 전선 타래"},
		{"kind":"rail_marker","rect":[99,44,1,1],"solid":"none","facing":0,"note":"자갈 둑의 거리 말뚝"},
		{"kind":"fallen_log","rect":[98,5,5,1],"solid":"low","facing":0,"note":"숲 가장자리의 쓰러진 통나무"},
		{"kind":"firewood_pile","rect":[105,7,2,1],"solid":"low","facing":0,"note":"통나무 곁의 장작"},
		{"kind":"snow_drift","rect":[98,8,4,2],"solid":"none","facing":0,"note":"숲 그늘에 쌓인 눈"},
		{"kind":"signal_post","rect":[5,34,1,1],"solid":"wall","facing":0,"note":"서쪽 선로 곁 기둥 신호등"},
		{"kind":"rail_marker","rect":[7,36,1,1],"solid":"none","facing":0,"note":"선로 점검 길 거리 말뚝"},
		{"kind":"sled_load","rect":[3,37,2,1],"solid":"low","facing":0,"note":"선로 점검을 마친 썰매"},
		{"kind":"rail_stack","rect":[14,34,4,1],"solid":"low","facing":0,"note":"서쪽 선로 곁 자재"}
	],
	"trees": [
		[15,6],
		[18,10],
		[16,7],
		[18,8],
		[14,4],
		[15,5],
		[16,3],
		[19,9],
		[16,8],
		[17,3],
		[17,5],
		[39,5],
		[33,6],
		[36,6],
		[39,4],
		[31,3],
		[32,6],
		[37,6],
		[32,4],
		[35,1],
		[35,6],
		[37,1],
		[47,5],
		[48,3],
		[50,8],
		[54,6],
		[53,7],
		[50,7],
		[52,4],
		[48,9],
		[50,6],
		[45,4],
		[45,8],
		[72,5],
		[66,3],
		[64,4],
		[65,5],
		[68,5],
		[68,3],
		[71,3],
		[68,7],
		[66,6],
		[71,1],
		[69,6],
		[89,6],
		[84,4],
		[85,11],
		[87,11],
		[88,7],
		[88,6],
		[88,11],
		[84,12],
		[85,8],
		[83,10],
		[82,7],
		[107,5],
		[103,6],
		[107,1],
		[103,1],
		[104,2],
		[102,2],
		[105,5],
		[109,4],
		[105,3],
		[102,7],
		[106,6],
		[119,7],
		[127,6],
		[120,9],
		[124,8],
		[123,3],
		[120,5],
		[121,8],
		[125,4],
		[121,7],
		[123,8],
		[127,9],
		[134,17],
		[131,14],
		[128,15],
		[133,18],
		[135,13],
		[132,15],
		[132,17],
		[133,14],
		[128,14],
		[130,14],
		[135,16],
		[112,16],
		[109,18],
		[111,16],
		[108,19],
		[114,21],
		[111,23],
		[107,22],
		[112,17],
		[107,18],
		[113,20],
		[109,16],
		[96,25],
		[95,24],
		[92,22],
		[88,23],
		[92,23],
		[90,22],
		[93,22],
		[88,21],
		[91,22],
		[90,23],
		[88,24],
		[63,17],
		[67,16],
		[62,14],
		[68,17],
		[62,17],
		[64,14],
		[64,16],
		[65,20],
		[66,14],
		[65,18],
		[65,21],
		[34,22],
		[34,24],
		[38,21],
		[35,21],
		[40,26],
		[39,24],
		[37,22],
		[37,27],
		[35,27],
		[32,25],
		[34,26],
		[20,22],
		[24,22],
		[22,18],
		[20,18],
		[23,21],
		[22,22],
		[23,20],
		[24,24],
		[21,18],
		[18,24],
		[22,20],
		[121,23],
		[116,25],
		[119,25],
		[120,28],
		[117,25],
		[120,22],
		[118,25],
		[120,23],
		[119,23],
		[118,22],
		[116,28]
	],
	"slow_rects": [
		[16,29,27,3],
		[46,29,30,3],
		[80,29,40,3],
		[12,47,24,3],
		[40,47,34,3],
		[79,47,40,3]
	],
	"gates": [
		[43,32,3,1],
		[76,32,3,1],
		[37,46,3,1],
		[75,46,3,1]
	],
	"entries": {"track_west_upper":[[0,35],[0,36],[0,37]],"track_east_upper":[[139,35],[139,36],[139,37]],"track_west_lower":[[0,41],[0,42],[0,43]],"track_east_lower":[[139,41],[139,42],[139,43]],"forest_edge":[[91,0],[92,0],[93,0]],"open_field":[[108,79],[109,79],[110,79],[111,79]]},
	"dead_forest": [
		[92,14],
		[105,14],
		[122,13],
		[50,13]
	],
	"dead_field": [
		[107,73],
		[58,75],
		[14,70]
	],
	"stores": [
		{"id":"tools","name":"연장 궤","cell":[22,8],"items":["scrap","scrap","plank","plank","bandage"]},
		{"id":"track_supplies","name":"보선 자재 상자","cell":[26,8],"items":["wood","wood","flare","cloth","food_pack"]}
	],
	"salvage": [
		{"id":"recover_sleeper_stack","name":"침목 뜯는 자리","cell":[41,32],"material":"wood","amount":3},
		{"id":"recover_rail_stack","name":"레일 토막 회수 자리","cell":[13,34],"material":"scrap","amount":2},
		{"id":"recover_fallen_signal","name":"신호기 회수 자리","cell":[46,31],"material":"scrap","amount":1},
		{"id":"recover_fallen_pole","name":"쓰러진 기둥 뜯는 자리","cell":[71,64],"material":"wood","amount":2},
		{"id":"recover_fallen_log","name":"통나무 뜯는 자리","cell":[98,4],"material":"wood","amount":2}
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
