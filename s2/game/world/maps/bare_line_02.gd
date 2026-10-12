# 이 지도가 다른 판단을 만드는 것: 눈밭의 먼 창고로 건너갈 동안 아래 숲 쪽 문을 방벽에 맡길지 고른다.
extends RefCounted
## 창고가 눈밭 쪽에 있고 숲은 아래쪽에 있다. 좌표는 이 파일 안에서 조립한다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 142
const HEIGHT: int = 78
const PLACE_ID: String = "bare_line_02"
const ZONE_NAMES: Dictionary = {"track_bank": "선로 둑", "forest_side": "숲 가장자리", "open_side": "트인 눈밭"}
const ENTRY_NAMES: Dictionary = {"track_west_upper":"서쪽 선로, 눈밭 쪽","track_east_upper":"동쪽 선로, 눈밭 쪽","track_west_lower":"서쪽 선로, 숲 쪽","track_east_lower":"동쪽 선로, 숲 쪽","forest_edge":"숲 가장자리","open_field":"트인 눈밭"}
const ENTRY_WEIGHTS: Dictionary = {"track_west_upper":1.5,"track_east_upper":1.5,"track_west_lower":1.5,"track_east_lower":1.5,"forest_edge":1,"open_field":1}
const FIRST_ENTRY: String = "track_east_lower"
const PLAN: Dictionary = {
	"train": [31,36,80,3],
	"forest": "lower",
	"house": [117,4,8,6],
	"house_door": [121,9],
	"windows": [
		[117,6]
	],
	"floors": [
		{"rect":[0,11,11,3],"kind":5},
		{"rect":[18,10,11,3],"kind":5},
		{"rect":[36,8,11,3],"kind":5},
		{"rect":[54,6,11,3],"kind":5},
		{"rect":[72,5,11,3],"kind":5},
		{"rect":[90,6,11,3],"kind":5},
		{"rect":[108,8,11,3],"kind":5},
		{"rect":[126,10,11,3],"kind":5},
		{"rect":[0,25,13,3],"kind":5},
		{"rect":[18,23,13,3],"kind":5},
		{"rect":[36,21,13,3],"kind":5},
		{"rect":[54,19,13,3],"kind":5},
		{"rect":[72,19,13,3],"kind":5},
		{"rect":[90,21,13,3],"kind":5},
		{"rect":[108,23,13,3],"kind":5},
		{"rect":[126,25,13,3],"kind":5},
		{"rect":[0,55,11,3],"kind":5},
		{"rect":[18,53,11,3],"kind":5},
		{"rect":[36,51,11,3],"kind":5},
		{"rect":[54,50,11,3],"kind":5},
		{"rect":[72,51,11,3],"kind":5},
		{"rect":[90,53,11,3],"kind":5},
		{"rect":[108,55,11,3],"kind":5},
		{"rect":[126,56,11,3],"kind":5},
		{"rect":[0,71,13,3],"kind":5},
		{"rect":[18,69,13,3],"kind":5},
		{"rect":[36,67,13,3],"kind":5},
		{"rect":[54,67,13,3],"kind":5},
		{"rect":[72,69,13,3],"kind":5},
		{"rect":[90,71,13,3],"kind":5},
		{"rect":[108,73,13,3],"kind":5},
		{"rect":[126,73,13,3],"kind":5},
		{"rect":[120,10,3,9],"kind":5},
		{"rect":[93,18,30,1],"kind":5},
		{"rect":[93,18,3,17],"kind":5},
		{"rect":[102,10,21,1],"kind":5},
		{"rect":[102,10,3,13],"kind":5},
		{"rect":[62,22,43,1],"kind":5},
		{"rect":[62,22,3,13],"kind":5},
		{"rect":[44,0,3,22],"kind":5},
		{"rect":[39,21,8,1],"kind":5},
		{"rect":[39,21,3,14],"kind":5},
		{"rect":[55,62,3,16],"kind":5},
		{"rect":[55,67,3,2],"kind":0},
		{"rect":[49,62,9,1],"kind":5},
		{"rect":[49,39,3,24],"kind":5},
		{"rect":[49,44,3,2],"kind":0},
		{"rect":[49,53,3,2],"kind":0},
		{"rect":[41,29,6,3],"kind":7},
		{"rect":[87,29,6,3],"kind":7},
		{"rect":[94,29,5,4],"kind":7},
		{"rect":[16,30,5,4],"kind":7},
		{"rect":[45,42,5,4],"kind":7},
		{"rect":[51,43,6,3],"kind":7}
	],
	"props": [
		{"kind":"sleeper_stack","rect":[38,30,1,3],"solid":"low","facing":1,"note":"둑의 침목 더미"},
		{"kind":"rail_stack","rect":[42,30,4,1],"solid":"low","facing":0,"note":"둑의 레일 토막 더미"},
		{"kind":"rail_stack","rect":[88,30,4,1],"solid":"low","facing":0,"note":"둑의 레일 토막 더미"},
		{"kind":"ballast_pile","rect":[95,30,3,2],"solid":"low","facing":0,"note":"둑의 자갈 더미"},
		{"kind":"rail_handcar","rect":[17,31,3,2],"solid":"low","facing":0,"note":"둑의 수동차"},
		{"kind":"ballast_pile","rect":[47,42,2,3],"solid":"low","facing":1,"note":"둑의 자갈 더미"},
		{"kind":"rail_stack","rect":[52,44,4,1],"solid":"low","facing":0,"note":"둑의 레일 토막 더미"},
		{"kind":"sleeper_stack","rect":[80,44,3,1],"solid":"low","facing":0,"note":"둑의 침목 더미"},
		{"kind":"crate_stack","rect":[86,43,2,2],"solid":"low","facing":0,"note":"둑의 자재 상자 더미"},
		{"kind":"fallen_signal","rect":[16,42,5,1],"solid":"low","facing":0,"note":"둑의 쓰러진 신호기"},
		{"kind":"plank_bridge","rect":[39,27,2,3],"solid":"none","facing":0,"note":"도랑을 건너는 널다리"},
		{"kind":"plank_bridge","rect":[62,27,2,3],"solid":"none","facing":0,"note":"도랑을 건너는 널다리"},
		{"kind":"plank_bridge","rect":[92,27,2,3],"solid":"none","facing":0,"note":"도랑을 건너는 널다리"},
		{"kind":"plank_bridge","rect":[49,45,2,3],"solid":"none","facing":0,"note":"도랑을 건너는 널다리"},
		{"kind":"plank_bridge","rect":[83,45,2,3],"solid":"none","facing":0,"note":"도랑을 건너는 널다리"},
		{"kind":"snow_fence","rect":[20,12,5,1],"solid":"low","facing":0,"note":"트인 눈밭의 짧은 눈막이"},
		{"kind":"snow_drift","rect":[21,9,4,2],"solid":"none","facing":0,"note":"울타리 뒤에 쌓인 눈"},
		{"kind":"snow_fence","rect":[51,13,5,1],"solid":"low","facing":0,"note":"트인 눈밭의 짧은 눈막이"},
		{"kind":"snow_drift","rect":[52,10,4,2],"solid":"none","facing":0,"note":"울타리 뒤에 쌓인 눈"},
		{"kind":"snow_fence","rect":[94,13,5,1],"solid":"low","facing":0,"note":"트인 눈밭의 짧은 눈막이"},
		{"kind":"snow_drift","rect":[95,10,4,2],"solid":"none","facing":0,"note":"울타리 뒤에 쌓인 눈"},
		{"kind":"shelf","rect":[118,5,3,1],"solid":"low","facing":0,"note":"창고 안 선반"},
		{"kind":"tool_bench","rect":[122,5,2,1],"solid":"low","facing":0,"note":"창고 안 연장 작업대"},
		{"kind":"tool_rack","rect":[125,7,2,1],"solid":"low","facing":0,"note":"연장 걸이"},
		{"kind":"crate_stack","rect":[127,10,2,2],"solid":"low","facing":0,"note":"자재 상자 더미"},
		{"kind":"fuel_drum","rect":[125,12,1,1],"solid":"low","facing":0,"note":"연료 드럼"},
		{"kind":"fuel_drum","rect":[127,13,1,1],"solid":"low","facing":0,"note":"연료 드럼"},
		{"kind":"firewood_pile","rect":[119,11,2,1],"solid":"low","facing":0,"note":"장작 더미"},
		{"kind":"sleeper_stack","rect":[113,11,3,1],"solid":"low","facing":0,"note":"침목 더미"},
		{"kind":"power_pole","rect":[15,12,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"power_pole","rect":[29,12,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"power_pole","rect":[43,12,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"power_pole","rect":[57,12,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"fallen_pole","rect":[71,12,5,1],"solid":"low","facing":0,"note":"끊긴 전신주 줄의 쓰러진 기둥"},
		{"kind":"power_pole","rect":[85,12,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"power_pole","rect":[99,12,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"power_pole","rect":[113,12,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"power_pole","rect":[127,12,1,1],"solid":"wall","facing":0,"note":"열네 칸 간격의 전신주"},
		{"kind":"wire_coil","rect":[31,10,1,1],"solid":"low","facing":0,"note":"전신주 밑의 전선 타래"},
		{"kind":"rail_marker","rect":[27,32,1,1],"solid":"none","facing":0,"note":"자갈 둑의 거리 말뚝"},
		{"kind":"wire_coil","rect":[101,10,1,1],"solid":"low","facing":0,"note":"전신주 밑의 전선 타래"},
		{"kind":"rail_marker","rect":[99,32,1,1],"solid":"none","facing":0,"note":"자갈 둑의 거리 말뚝"},
		{"kind":"fallen_log","rect":[90,67,5,1],"solid":"low","facing":0,"note":"숲 가장자리의 쓰러진 통나무"},
		{"kind":"firewood_pile","rect":[97,69,2,1],"solid":"low","facing":0,"note":"통나무 곁의 장작"},
		{"kind":"snow_drift","rect":[90,70,4,2],"solid":"none","facing":0,"note":"숲 그늘에 쌓인 눈"},
		{"kind":"signal_post","rect":[5,32,1,1],"solid":"wall","facing":0,"note":"서쪽 선로 곁 기둥 신호등"},
		{"kind":"rail_marker","rect":[7,34,1,1],"solid":"none","facing":0,"note":"선로 점검 길 거리 말뚝"},
		{"kind":"sled_load","rect":[3,35,2,1],"solid":"low","facing":0,"note":"선로 점검을 마친 썰매"},
		{"kind":"snow_bank","rect":[100,69,6,1],"solid":"low","facing":0,"note":"숲 앞에 밀어 둔 눈"}
	],
	"trees": [
		[11,66],
		[12,69],
		[12,67],
		[12,65],
		[8,69],
		[10,63],
		[6,65],
		[12,68],
		[10,66],
		[11,68],
		[10,64],
		[23,72],
		[24,74],
		[23,69],
		[24,72],
		[25,71],
		[28,70],
		[19,71],
		[25,69],
		[28,72],
		[24,71],
		[20,73],
		[35,67],
		[36,67],
		[41,65],
		[35,65],
		[38,66],
		[36,64],
		[41,67],
		[37,62],
		[39,62],
		[37,68],
		[39,61],
		[53,74],
		[54,72],
		[54,69],
		[58,72],
		[59,74],
		[52,72],
		[54,74],
		[54,75],
		[52,71],
		[60,73],
		[52,70],
		[72,68],
		[75,68],
		[71,61],
		[73,66],
		[69,63],
		[71,64],
		[72,66],
		[72,64],
		[75,66],
		[77,65],
		[76,64],
		[90,75],
		[85,70],
		[90,74],
		[89,70],
		[85,73],
		[87,69],
		[87,71],
		[88,74],
		[88,72],
		[88,73],
		[86,71],
		[105,67],
		[103,68],
		[104,66],
		[108,66],
		[102,68],
		[109,66],
		[108,64],
		[105,68],
		[107,69],
		[100,68],
		[102,65],
		[126,73],
		[124,72],
		[120,70],
		[121,72],
		[121,69],
		[120,73],
		[124,75],
		[122,71],
		[121,71],
		[123,71],
		[127,72],
		[137,63],
		[131,64],
		[134,65],
		[132,61],
		[131,67],
		[135,63],
		[130,64],
		[129,62],
		[132,62],
		[132,66],
		[133,60],
		[113,56],
		[115,58],
		[112,53],
		[113,54],
		[114,59],
		[111,54],
		[110,59],
		[109,56],
		[109,59],
		[107,57],
		[112,57],
		[75,58],
		[72,54],
		[76,56],
		[71,57],
		[71,59],
		[76,55],
		[75,55],
		[70,57],
		[75,60],
		[73,59],
		[77,58],
		[31,55],
		[32,57],
		[33,59],
		[29,57],
		[37,55],
		[29,55],
		[34,57],
		[29,56],
		[32,54],
		[29,59],
		[28,56]
	],
	"slow_rects": [
		[12,27,26,3],
		[42,27,20,3],
		[65,27,26,3],
		[96,27,32,3],
		[18,45,30,3],
		[53,45,30,3],
		[86,45,36,3]
	],
	"gates": [
		[39,30,3,1],
		[92,30,3,1],
		[49,44,3,1],
		[83,44,3,1]
	],
	"entries": {"track_west_upper":[[0,33],[0,34],[0,35]],"track_east_upper":[[141,33],[141,34],[141,35]],"track_west_lower":[[0,39],[0,40],[0,41]],"track_east_lower":[[141,39],[141,40],[141,41]],"forest_edge":[[55,77],[56,77],[57,77]],"open_field":[[44,0],[45,0],[46,0],[47,0]]},
	"dead_forest": [
		[20,63],
		[61,67],
		[110,63],
		[128,69]
	],
	"dead_field": [
		[31,5],
		[76,4],
		[133,10]
	],
	"stores": [
		{"id":"tools","name":"연장 궤","cell":[119,7],"items":["scrap","scrap","plank","plank","bandage"]},
		{"id":"track_supplies","name":"보선 자재 상자","cell":[123,7],"items":["wood","wood","flare","cloth","food_pack"]}
	],
	"salvage": [
		{"id":"recover_sleeper_stack","name":"침목 뜯는 자리","cell":[37,30],"material":"wood","amount":3},
		{"id":"recover_rail_stack","name":"레일 토막 회수 자리","cell":[42,29],"material":"scrap","amount":2},
		{"id":"recover_fallen_signal","name":"신호기 회수 자리","cell":[16,41],"material":"scrap","amount":1},
		{"id":"recover_fallen_pole","name":"쓰러진 기둥 뜯는 자리","cell":[71,11],"material":"wood","amount":2},
		{"id":"recover_fallen_log","name":"통나무 뜯는 자리","cell":[90,66],"material":"wood","amount":2}
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
