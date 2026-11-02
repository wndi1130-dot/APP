# 이 지도가 다른 판단을 만드는 것: 화차를 측선으로 미는 동안 구내를 뒤질수록 뒤의 무리가 가까워지고 다리 앞을 지킬 사람이 준다.
extends RefCounted

const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const PLACE_ID: String = "story_02"
const WIDTH: int = 185
const HEIGHT: int = 137
const TRAIN: Rect2i = Rect2i(20, 63, 80, 3)
const BANDS: Dictionary = {"upper": Rect2i(0, 41, 120, 22), "lower": Rect2i(0, 66, 120, 22)}
const ENTRY_NAMES: Dictionary = {"west_track": "서쪽 선로 끝", "yard_back": "창고 뒤 구내길", "siding_back": "측선 뒤 구내길"}
const ENTRY_WEIGHTS: Dictionary = {"west_track": 3.0, "yard_back": 1.0, "siding_back": 0.7}
const FIRST_ENTRY: String = "west_track"

# 한 칸은 1m. 운하의 유일한 횡단부는 철교이며 동쪽 끝 40칸은 기계실 외에 높은 것이 없는 들판이다.
const PLAN: Dictionary = {
	"zones": [["A", "다리 앞 선로", [0, 0, 185, 137]], ["B", "측선 작업 마당", [15, 88, 105, 49]], ["C", "운하와 들판", [122, 0, 63, 137]], ["D", "구내 창고", [56, 5, 44, 35]]],
	"labels": [["다리 앞 선로", [65, 50]], ["측선 작업 마당", [45, 104]], ["운하와 들판", [166, 82]], ["입고 작업실", [83, 29]], ["자재 창고", [85, 17]], ["기계 작업실", [151, 52]], ["들어 올리는 철교", [135, 61]], ["얼어붙은 바지선", [124, 100]]],
	"floors": [[12, 5, 8, 36, 1], [60, 34, 36, 6, 7], [15, 88, 105, 45, 7], [122, 0, 10, 137, 6], [140, 0, 5, 137, 6]],
	"siding": [[99, 65, 7, 3], [94, 68, 7, 3], [89, 71, 7, 3], [84, 74, 7, 3], [79, 77, 7, 3], [74, 80, 7, 3], [69, 83, 7, 3], [64, 86, 7, 3], [59, 89, 7, 3], [40, 92, 24, 3]],
	"bridge": [130, 60, 12, 9],
	"field": [145, 0, 40, 137],
	"loading_yard": [60, 34, 36, 6],
	"buildings": [
		{"id": 0, "name": "구내 창고", "rect": [60, 9, 36, 25], "warm": false, "window_broken": false},
		{"id": 1, "name": "기계실", "rect": [145, 47, 12, 10], "warm": false, "window_broken": false}
	],
	"walls": [[61, 21, 34, 1]],
	"doors": [[78, 33, 0], [78, 21, 0], [156, 52, 1]],
	"deep": {"rect": [61, 10, 34, 11], "door": [78, 21], "approach": [78, 27]},
	"props": [
		{"kind": "water", "rect": [132, 0, 8, 60], "solid": "low", "facing": 0, "note": "곧은 운하의 북쪽 물길", "level": 0},
		{"kind": "water", "rect": [132, 69, 8, 48], "solid": "low", "facing": 0, "note": "곧은 운하의 남쪽 물길", "level": 0},
		{"kind": "water", "rect": [126, 117, 17, 6], "solid": "low", "facing": 0, "note": "강과 만나는 첫째 만", "level": 0},
		{"kind": "water", "rect": [120, 123, 24, 7], "solid": "low", "facing": 0, "note": "서쪽으로 넓어진 강 어귀", "level": 0},
		{"kind": "water", "rect": [124, 130, 18, 4], "solid": "low", "facing": 0, "note": "곶 사이 좁아진 강 어귀", "level": 0},
		{"kind": "water", "rect": [119, 134, 24, 3], "solid": "low", "facing": 0, "note": "두 번째 만에서 이어지는 강", "level": 0},
		{"kind": "bridge_truss", "rect": [130, 60, 12, 1], "solid": "none", "facing": 0, "note": "들어 올리는 철교 가동부의 북쪽 트러스 자리", "level": 0},
		{"kind": "bridge_truss", "rect": [130, 68, 12, 1], "solid": "none", "facing": 0, "note": "들어 올리는 철교 가동부의 남쪽 트러스 자리", "level": 0},
		{"kind": "arcade_column", "rect": [128, 58, 2, 2], "solid": "wall", "facing": 0, "note": "철교 서쪽 틀의 북쪽 기둥", "level": 0},
		{"kind": "arcade_column", "rect": [128, 69, 2, 2], "solid": "wall", "facing": 0, "note": "철교 서쪽 틀의 남쪽 기둥", "level": 0},
		{"kind": "arcade_column", "rect": [142, 58, 2, 2], "solid": "wall", "facing": 0, "note": "철교 동쪽 틀의 북쪽 기둥", "level": 0},
		{"kind": "arcade_column", "rect": [142, 69, 2, 2], "solid": "wall", "facing": 0, "note": "철교 동쪽 틀의 남쪽 기둥", "level": 0},
		{"kind": "signal_bridge", "rect": [128, 60, 2, 9], "solid": "none", "facing": 1, "note": "철교 서쪽 위 가로대의 지상 투영 자리", "level": 0},
		{"kind": "signal_bridge", "rect": [142, 60, 2, 9], "solid": "none", "facing": 1, "note": "철교 동쪽 위 가로대의 지상 투영 자리", "level": 0},
		{"kind": "sleeper_pile", "rect": [34, 49, 4, 2], "solid": "low", "facing": 0, "note": "북쪽 띠의 침목 더미", "level": 0},
		{"kind": "crate_stack", "rect": [47, 53, 4, 2], "solid": "low", "facing": 0, "note": "북쪽 띠의 자재 상자", "level": 0},
		{"kind": "snow_drift", "rect": [86, 45, 4, 2], "solid": "low", "facing": 0, "note": "북쪽 띠의 눈 둔덕", "level": 0},
		{"kind": "sleeper_pile", "rect": [107, 55, 4, 2], "solid": "low", "facing": 0, "note": "다리 앞 침목 더미", "level": 0},
		{"kind": "crate_stack", "rect": [28, 75, 4, 2], "solid": "low", "facing": 0, "note": "남쪽 띠의 낮은 상자", "level": 0},
		{"kind": "sleeper_pile", "rect": [48, 77, 4, 2], "solid": "low", "facing": 0, "note": "측선 바깥 침목 더미", "level": 0},
		{"kind": "crate_stack", "rect": [93, 82, 4, 2], "solid": "low", "facing": 0, "note": "남쪽 띠의 동쪽 상자", "level": 0},
		{"kind": "snow_drift", "rect": [110, 85, 4, 2], "solid": "low", "facing": 0, "note": "남쪽 띠의 눈 둔덕", "level": 0},
		{"kind": "frozen_barge", "rect": [126, 95, 5, 10], "solid": "low", "facing": 1, "note": "서쪽 둑에 얼어붙은 바지선 자리", "level": 0},
		{"kind": "mooring_post", "rect": [124, 93, 1, 1], "solid": "low", "facing": 0, "note": "바지선 앞 계류 말뚝 자리", "level": 0},
		{"kind": "mooring_post", "rect": [124, 109, 1, 1], "solid": "low", "facing": 0, "note": "바지선 뒤 계류 말뚝 자리", "level": 0},
		{"kind": "arcade_column", "rect": [130, 90, 1, 3], "solid": "wall", "facing": 0, "note": "수문 틀의 서쪽 기둥", "level": 0},
		{"kind": "arcade_column", "rect": [140, 90, 1, 3], "solid": "wall", "facing": 0, "note": "수문 틀의 동쪽 기둥", "level": 0},
		{"kind": "sluice_frame", "rect": [130, 90, 11, 3], "solid": "none", "facing": 0, "note": "운하 위 수문 틀 자리", "level": 0},
		{"kind": "frozen_reeds", "rect": [122, 116, 3, 3], "solid": "none", "facing": 0, "note": "강 어귀 첫째 만의 갈대", "level": 0},
		{"kind": "frozen_reeds", "rect": [115, 127, 3, 3], "solid": "none", "facing": 0, "note": "강 어귀 둘째 만의 갈대", "level": 0},
		{"kind": "rock_outcrop", "rect": [119, 131, 3, 2], "solid": "low", "facing": 0, "note": "강 어귀 곶의 낮은 돌", "level": 0},
		{"kind": "tool_bench", "rect": [63, 26, 3, 1], "solid": "low", "facing": 0, "note": "입고 작업실의 공구 작업대", "level": 0},
		{"kind": "shelf", "rect": [62, 12, 3, 1], "solid": "low", "facing": 0, "note": "자재 창고의 부품 선반", "level": 0},
		{"kind": "tool_bench", "rect": [147, 49, 3, 1], "solid": "low", "facing": 0, "note": "기계 작업실의 조작 작업대", "level": 0},
		{"kind": "bare_tree", "rect": [7, 5, 1, 1], "solid": "tree", "facing": 0, "note": "서북쪽 숲 가장자리", "level": 0},
		{"kind": "bare_tree", "rect": [28, 9, 1, 1], "solid": "tree", "facing": 0, "note": "구내 뒤 마른 나무", "level": 0},
		{"kind": "bare_tree", "rect": [18, 120, 1, 1], "solid": "tree", "facing": 0, "note": "남쪽 숲 가장자리", "level": 0},
		{"kind": "bare_tree", "rect": [90, 132, 1, 1], "solid": "tree", "facing": 0, "note": "강 어귀 앞 마른 나무", "level": 0}
	],
	"wagons": [
		{"id": "blocked_wagon_01", "name": "문이 열린 앞 화차", "rect": [103, 63, 10, 3], "coal": 0, "work": [108, 62]},
		{"id": "blocked_wagon_02", "name": "문이 열린 뒤 화차", "rect": [116, 63, 10, 3], "coal": 0, "work": [121, 66]}
	],
	"boxes": [["tools_shallow", "입고 작업실 공구 상자", [68, 28], 0, ["scrap"]], ["tools_deep", "자재 창고 공구 상자", [68, 16], 0, ["scrap"]], ["yard_supplies", "하역 마당 자재 상자", [53, 35], -1, ["scrap"]]],
	"entries": [["west_track", [[0, 63], [0, 64], [0, 65]], 0.45], ["yard_back", [[16, 8], [18, 8]], 0.8], ["siding_back", [[108, 119], [111, 121]], 1.0]],
	"barricades": [[15, 42], [16, 42], [77, 40], [78, 40], [20, 88], [21, 88], [105, 88], [106, 88]],
	"work_site": {"cell": [54, 96], "rect": [37, 89, 30, 13]},
	"story_spots": [["story_bridge_front", "다리 앞 지키는 자리", [128, 62], [126, 60, 4, 9]], ["story_machine_room", "기계실 문 앞 들판", [159, 52], [157, 49, 5, 7]], ["story_rear_view", "뒤 창에서 다리가 보이는 들판", [173, 64], [169, 60, 8, 9]]],
	"dead": [[25, 19], [29, 22], [40, 16], [110, 112], [114, 116], [104, 122]]
}


static func build() -> Dictionary:
	var g := FieldGrid.new(WIDTH, HEIGHT)
	var levels: Dictionary = {0: g}
	var data: Dictionary = {
		"grid": g, "levels": levels, "stairs": [], "containers": {}, "spots": {},
		"stoves": [], "entries": {}, "entry_gap": {}, "entry_levels": {},
		"buildings": [], "wagons": [], "train": TRAIN,
		"platform": Rect2i(20, 59, 80, 4), "unload": Rect2i(20, 66, 80, 3),
		"train_cars": [], "spawns": {}, "labels": [], "trees": [], "low_blocks": [],
		"upper_rects": [], "lights": [], "manholes": {}, "manhole_levels": {},
		"sewer_names": {}, "anchors": {}, "zone_names": {}, "place_id": PLACE_ID,
		"place_kind": "freight", "bands": BANDS.duplicate(true),
		"train_doors": {"upper": [], "lower": []}, "crossings": [], "barricade_slots": [],
		"interior_kind_slots": [{"zone": "D", "kinds": ["empty", "raiders", "nest", "beasts"]}],
		"props": [], "hole_faces": {}, "entry_names": ENTRY_NAMES.duplicate(true),
		"entry_weights": ENTRY_WEIGHTS.duplicate(true), "first_entry": FIRST_ENTRY
	}
	for row in PLAN["zones"]:
		data["zone_names"][row[0]] = row[1]
		var r := _rect(row[2])
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				g.zone[g.index(Vector2i(x, y))] = row[0]
	for row in PLAN["labels"]:
		data["labels"].append({"text": row[0], "cell": _cell(row[1])})
	for row in PLAN["floors"]:
		_fill_floor(g, Rect2i(row[0], row[1], row[2], row[3]), int(row[4]))
	_fill_floor(g, Rect2i(0, TRAIN.position.y, WIDTH, 3), F.RAIL)
	_fill_floor(g, _rect(PLAN["bridge"]), F.GRAVEL)
	_fill_floor(g, Rect2i(130, 63, 12, 3), F.RAIL)
	for row in PLAN["siding"]:
		_fill_floor(g, _rect(row), F.RAIL)
	_fill_floor(g, data["platform"], F.PLATFORM)
	_fill_floor(g, data["unload"], F.GRAVEL)
	_fill_solid(g, TRAIN, S.BLOCK)
	for row in PLAN["buildings"]:
		var b: Dictionary = row.duplicate(true)
		b["rect"] = _rect(row["rect"])
		data["buildings"].append(b)
		_shell(g, int(b["id"]), b["rect"])
	for row in PLAN["walls"]:
		_fill_solid(g, _rect(row), S.WALL)
	for row in PLAN["doors"]:
		var c := _cell(row)
		g.set_solid(c, S.DOOR)
		g.doors[c] = {"state": "open", "hp": 8, "building": int(row[2]), "cell": c}
	for row in PLAN["props"]:
		_prop(g, data, row)
	for row in PLAN["wagons"]:
		var wagon: Dictionary = row.duplicate(true)
		wagon["rect"] = _rect(row["rect"])
		wagon["work"] = _cell(row["work"])
		data["wagons"].append(wagon)
		_fill_solid(g, wagon["rect"], S.BLOCK)
	for row in PLAN["boxes"]:
		data["containers"][row[0]] = {"id": row[0], "name": row[1], "cell": _cell(row[2]), "building": int(row[3]), "search": 4.0, "items": row[4].duplicate(true), "locked": false, "level": 0, "searched": false}
	for row in PLAN["entries"]:
		var cells: Array[Vector2i] = []
		for c in row[1]:
			cells.append(_cell(c))
		data["entries"][row[0]] = cells
		data["entry_gap"][row[0]] = float(row[2])
		data["entry_levels"][row[0]] = 0
	for row in PLAN["barricades"]:
		data["barricade_slots"].append(_cell(row))
	_train(g, data)
	var work: Dictionary = PLAN["work_site"]
	data["spots"]["work_site"] = {"kind": "work_site", "cell": _cell(work["cell"]), "name": "측선 작업 구역", "state": "closed", "zone_rect": _rect(work["rect"])}
	for row in PLAN["story_spots"]:
		data["spots"][row[0]] = {"kind": "story", "cell": _cell(row[2]), "name": row[1], "zone_rect": _rect(row[3])}
	var dead: Array[Vector2i] = []
	for row in PLAN["dead"]:
		dead.append(_cell(row))
	data["spawns"] = {"squad": [Vector2i(54, 68), Vector2i(52, 69), Vector2i(56, 69)], "train_door": data["train_doors"]["upper"] + data["train_doors"]["lower"], "dead_yard": dead, "dead_levels": []}
	data["anchors"] = {"horde_home": Vector2i(54, 68), "whistle": Vector2i(98, 66), "flee_exit": Vector2i(0, 64), "engine": Vector2i(92, 64)}
	g.refresh_paths()
	return data


static func _train(g: FieldGrid, data: Dictionary) -> void:
	for side in ["upper", "lower"]:
		var y: int = TRAIN.position.y - 1 if side == "upper" else TRAIN.end.y
		for x in [38, 54, 70]:
			data["train_doors"][side].append(Vector2i(x, y))
		var apron := Rect2i(20, 59 if side == "upper" else 66, 80, 3)
		data["spots"]["unload_" + side] = {"kind": "unload", "name": "북쪽 선로 하역 자리" if side == "upper" else "측선 쪽 하역 자리", "cell": Vector2i(54, 61 if side == "upper" else 67), "state": "open", "zone_rect": apron}
	for x in [TRAIN.position.x - 1, TRAIN.end.x]:
		var cells: Array[Vector2i] = []
		for y in range(TRAIN.position.y - 1, TRAIN.end.y + 1):
			var c := Vector2i(x, y)
			cells.append(c)
			g.floor[g.index(c)] = F.GRAVEL
		data["crossings"].append({"cells": cells, "who": {"person": true, "zombie": true, "carrying": true, "wounded": true, "sled": true}})
	for k in range(5):
		data["train_cars"].append({"rect": Rect2i(TRAIN.position.x + 16 * k, TRAIN.position.y, 16, 3), "kind": "engine" if k == 4 else "car"})


static func _prop(g: FieldGrid, data: Dictionary, row: Dictionary) -> void:
	var prop: Dictionary = row.duplicate(true)
	var r := _rect(row["rect"])
	prop["rect"] = r
	data["props"].append(prop)
	match String(prop["solid"]):
		"low":
			_fill_solid(g, r, S.LOW)
			if prop["kind"] == "water":
				_fill_floor(g, r, F.ICE)
			else:
				data["low_blocks"].append(r)
		"wall":
			_fill_solid(g, r, S.WALL)
		"tree":
			_fill_solid(g, r, S.BLOCK)
			data["trees"].append(r.position)


static func _shell(g: FieldGrid, id: int, r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			g.building[g.index(c)] = id
			g.floor[g.index(c)] = F.WOOD
			var edge: bool = x == r.position.x or y == r.position.y or x == r.end.x - 1 or y == r.end.y - 1
			g.set_solid(c, S.WALL if edge else S.NONE)


static func _cell(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


static func _rect(a: Array) -> Rect2i:
	return Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))


static func _fill_floor(g: FieldGrid, r: Rect2i, kind: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			g.floor[g.index(Vector2i(x, y))] = kind


static func _fill_solid(g: FieldGrid, r: Rect2i, kind: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			g.set_solid(Vector2i(x, y), kind)
