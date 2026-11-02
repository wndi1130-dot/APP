# 이 지도가 다른 판단을 만드는 것: 발전기 열에 몇 해 모인 무리가 언덕을 두르므로 오르는 길을 고르는 일이 곧 싸울 무리를 고르는 일이다.
extends RefCounted

const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const PLACE_ID: String = "story_03"
const WIDTH: int = 180
const HEIGHT: int = 180
const TRAIN: Rect2i = Rect2i(40, 151, 80, 3)
const BANDS: Dictionary = {"upper": Rect2i(20, 128, 120, 23), "lower": Rect2i(20, 154, 120, 22)}
const ENTRY_NAMES: Dictionary = {"forest_west": "언덕 서쪽 숲", "forest_north": "언덕 북쪽 숲", "forest_east": "언덕 동쪽 숲", "west_track": "아래쪽 선로 끝"}
const ENTRY_WEIGHTS: Dictionary = {"forest_west": 1.2, "forest_north": 0.8, "forest_east": 1.0, "west_track": 0.5}
const FIRST_ENTRY: String = "forest_west"

# 높이 격자를 복제하지 않는다. 깊은 눈과 바위 윤곽으로 비탈을 그리고 서로 떨어진 두 길을 낸다.
# 송신실·헛간과 철탑이 꼭대기의 세 시설이다. 철탑은 지붕이 생기지 않도록 건물로 등록하지 않는다.
const PLAN: Dictionary = {
	"zones": [["A", "언덕 아래 측선", [0, 0, 180, 180]], ["B", "굽은 오르막길", [10, 34, 80, 94]], ["C", "숲 사이 지름길", [90, 18, 80, 110]], ["D", "송신소 꼭대기 마당", [56, 34, 80, 42]]],
	"labels": [["언덕 아래 측선", [77, 141]], ["굽은 오르막길", [44, 99]], ["숲 사이 지름길", [125, 91]], ["송신소 꼭대기 마당", [100, 69]], ["통신 사무실", [84, 49]], ["송신 정비실", [85, 58]], ["발전기 헛간", [118, 54]], ["가는 격자 철탑", [100, 45]]],
	"forests": [[18, 35, 32, 91], [137, 26, 28, 100], [46, 15, 88, 19], [52, 108, 75, 18]],
	"yard": [56, 34, 80, 42],
	"winding": [[42, 113, 41, 5], [78, 113, 5, 15], [42, 86, 5, 32], [42, 86, 22, 5], [59, 68, 5, 23], [59, 68, 24, 5], [78, 62, 5, 11]],
	"shortcut": [[100, 98, 3, 30], [100, 98, 28, 3], [124, 73, 3, 28], [109, 73, 18, 3], [109, 63, 3, 13], [109, 63, 7, 3], [113, 59, 3, 7]],
	# 꼭대기 둘레의 바위 비탈: 남쪽 경계는 굽은 길(59..63)과 지름길(124..126)만 연다.
	"cliffs": [[52, 104, 40, 3], [70, 81, 34, 3], [82, 76, 26, 2],
		[55, 34, 82, 1], [55, 35, 1, 42], [136, 35, 1, 42],
		[56, 76, 3, 1], [64, 76, 60, 1], [127, 76, 9, 1]],
	"buildings": [
		{"id": 0, "name": "송신실", "role": "office", "rect": [68, 45, 24, 18], "warm": false, "window_broken": false},
		{"id": 1, "name": "발전기 헛간", "rect": [108, 47, 14, 13], "warm": false, "window_broken": false}
	],
	"walls": [[69, 54, 22, 1]],
	"doors": [[80, 62, 0], [80, 54, 0], [114, 59, 1]],
	"deep": {"rect": [69, 46, 22, 8], "door": [80, 54], "approach": [80, 58]},
	"tower": [97, 37, 7, 7],
	"props": [
		{"kind": "sleeper_pile", "rect": [31, 136, 4, 2], "solid": "low", "facing": 0, "note": "오르막 입구 서쪽 침목 더미", "level": 0},
		{"kind": "crate_stack", "rect": [63, 131, 4, 2], "solid": "low", "facing": 0, "note": "굽은 길 앞 자재 상자", "level": 0},
		{"kind": "snow_drift", "rect": [111, 137, 4, 2], "solid": "low", "facing": 0, "note": "지름길 앞 눈 둔덕", "level": 0},
		{"kind": "sleeper_pile", "rect": [131, 144, 4, 2], "solid": "low", "facing": 0, "note": "보일러 쪽 침목 더미", "level": 0},
		{"kind": "crate_stack", "rect": [29, 164, 3, 2], "solid": "low", "facing": 0, "note": "아래 들판의 자재 상자", "level": 0},
		{"kind": "snow_drift", "rect": [69, 169, 4, 2], "solid": "low", "facing": 0, "note": "아래 들판의 눈 둔덕", "level": 0},
		{"kind": "sleeper_pile", "rect": [122, 163, 4, 2], "solid": "low", "facing": 0, "note": "땅 끝의 침목 더미", "level": 0},
		{"kind": "arcade_column", "rect": [98, 38, 1, 1], "solid": "wall", "facing": 0, "note": "격자 철탑의 서북 기둥 자리", "level": 0},
		{"kind": "arcade_column", "rect": [102, 38, 1, 1], "solid": "wall", "facing": 0, "note": "격자 철탑의 동북 기둥 자리", "level": 0},
		{"kind": "arcade_column", "rect": [98, 42, 1, 1], "solid": "wall", "facing": 0, "note": "격자 철탑의 서남 기둥 자리", "level": 0},
		{"kind": "arcade_column", "rect": [102, 42, 1, 1], "solid": "wall", "facing": 0, "note": "격자 철탑의 동남 기둥 자리", "level": 0},
		{"kind": "radio_set", "rect": [74, 48, 2, 1], "solid": "low", "facing": 0, "note": "통신 사무실의 송신기와 녹음기 자리", "level": 0, "keep": true},
		{"kind": "cold_stove", "rect": [70, 48, 1, 1], "solid": "low", "facing": 0, "note": "통신 사무실의 식은 난로", "level": 0, "keep": true},
		{"kind": "desk", "rect": [86, 47, 2, 1], "solid": "low", "facing": 0, "note": "통신 사무실의 빈 통조림 자리", "level": 0, "keep": true},
		{"kind": "notice_board", "rect": [90, 49, 1, 2], "solid": "none", "facing": 1, "note": "통신 사무실의 벽 송신 일지 자리", "level": 0, "keep": true},
		{"kind": "tool_bench", "rect": [70, 57, 3, 1], "solid": "low", "facing": 0, "note": "송신 정비실의 공구 작업대", "level": 0},
		{"kind": "generator_unit", "rect": [111, 50, 3, 2], "solid": "low", "facing": 0, "note": "발전기 헛간의 돌아가는 발전기 자리", "level": 0},
		{"kind": "fuel_tank", "rect": [122, 49, 3, 4], "solid": "wall", "facing": 1, "note": "발전기 헛간에 붙은 연료 탱크", "level": 0}
	],
	"trees": [[20, 38], [26, 45], [38, 50], [22, 59], [39, 67], [25, 77], [37, 86], [20, 96], [38, 108], [24, 122], [48, 18], [56, 29], [65, 20], [78, 28], [86, 17], [98, 30], [112, 18], [129, 29], [141, 30], [158, 37], [143, 49], [160, 61], [139, 67], [157, 78], [142, 92], [160, 103], [148, 117], [139, 123], [56, 111], [62, 123], [77, 111], [88, 124], [106, 112], [117, 123], [165, 9], [8, 15], [13, 133], [164, 142]],
	"boxes": [["tools_shallow", "송신 정비실 공구 상자", [75, 59], 0, ["scrap"]], ["tools_deep", "통신 사무실 부품 상자", [83, 51], 0, ["scrap"]], ["generator_tools", "발전기 헛간 공구 상자", [118, 57], 1, ["scrap"]]],
	"entries": [["forest_west", [[34, 81], [35, 83]], 1.0], ["forest_north", [[73, 32], [74, 33]], 1.2], ["forest_east", [[145, 83], [147, 85]], 1.0], ["west_track", [[5, 151], [5, 152]], 1.5]],
	"barricades": [[79, 127], [80, 127], [100, 127], [101, 127], [31, 176], [32, 176], [122, 176], [123, 176]],
	"story_spots": [["story_transmitter", "송신실 송신기 앞", [77, 50], [73, 47, 7, 6]], ["story_log", "송신실 벽의 송신 일지", [89, 49], [88, 48, 3, 5]], ["story_generator", "발전기 헛간 조작 자리", [114, 54], [110, 50, 8, 7]], ["story_boiler_path", "보일러 쪽으로 내려가는 길의 시작", [111, 75], [109, 73, 8, 3]]],
	"dead_groups": {
		"dead_forest_north": [[51, 25], [59, 24], [74, 23], [90, 24], [105, 22], [121, 26]],
		"dead_forest_west": [[29, 48], [33, 58], [28, 74], [30, 91], [34, 106], [31, 118]],
		"dead_forest_east": [[147, 40], [153, 55], [145, 71], [150, 88], [145, 105], [138, 116]],
		"dead_forest_lower": [[65, 119], [70, 121], [83, 118], [94, 114], [110, 120], [121, 115]]
	}
}


static func build() -> Dictionary:
	var g := FieldGrid.new(WIDTH, HEIGHT)
	var levels: Dictionary = {0: g}
	var data: Dictionary = {
		"grid": g, "levels": levels, "stairs": [], "containers": {}, "spots": {},
		"stoves": [], "entries": {}, "entry_gap": {}, "entry_levels": {},
		"buildings": [], "wagons": [], "train": TRAIN,
		"platform": Rect2i(40, 147, 80, 4), "unload": Rect2i(40, 154, 80, 3),
		"train_cars": [], "spawns": {}, "labels": [], "trees": [], "low_blocks": [],
		"upper_rects": [], "lights": [], "manholes": {}, "manhole_levels": {},
		"sewer_names": {}, "anchors": {}, "zone_names": {}, "place_id": PLACE_ID,
		"place_kind": "office", "bands": BANDS.duplicate(true),
		"train_doors": {"upper": [], "lower": []}, "crossings": [], "barricade_slots": [],
		"interior_kind_slots": [{"zone": "D", "kinds": ["empty"]}],
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
	for row in PLAN["forests"]:
		_fill_floor(g, _rect(row), F.DEEP_SNOW)
	_fill_floor(g, _rect(PLAN["yard"]), F.GRAVEL)
	for row in PLAN["winding"]:
		_fill_floor(g, _rect(row), F.ROAD)
	for row in PLAN["shortcut"]:
		_fill_floor(g, _rect(row), F.GRAVEL)
	_fill_floor(g, Rect2i(0, TRAIN.position.y, WIDTH, 3), F.RAIL)
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
	for row in PLAN["cliffs"]:
		_prop(g, data, {"kind": "rock_outcrop", "rect": row, "solid": "wall", "facing": 0, "note": "오르막 사이 바위 비탈", "level": 0})
	for row in PLAN["props"]:
		_prop(g, data, row)
	for row in PLAN["trees"]:
		_prop(g, data, {"kind": "bare_tree", "rect": [row[0], row[1], 1, 1], "solid": "tree", "facing": 0, "note": "언덕 둘레의 마른 나무", "level": 0})
	# 대각선 철골의 윤곽만 바닥에 그린다. 서 있을 판·지붕·추가 층은 없다.
	for i in range(5):
		_fill_floor(g, Rect2i(98 + i, 38 + i, 1, 1), F.RAIL)
		_fill_floor(g, Rect2i(102 - i, 38 + i, 1, 1), F.RAIL)
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
	for row in PLAN["story_spots"]:
		data["spots"][row[0]] = {"kind": "story", "cell": _cell(row[2]), "name": row[1], "zone_rect": _rect(row[3])}
	data["spawns"] = {"squad": [Vector2i(74, 148), Vector2i(72, 147), Vector2i(76, 147)], "train_door": data["train_doors"]["upper"] + data["train_doors"]["lower"], "dead_levels": []}
	for key in PLAN["dead_groups"]:
		var cells: Array[Vector2i] = []
		for row in PLAN["dead_groups"][key]:
			cells.append(_cell(row))
			_prop(g, data, {"kind": "dry_bush", "rect": [row[0], row[1], 1, 1], "solid": "none", "facing": 0, "note": "언덕 둘레 망자가 머무는 덤불", "level": 0})
		data["spawns"][key] = cells
	data["anchors"] = {"horde_home": Vector2i(74, 148), "whistle": Vector2i(118, 150), "flee_exit": Vector2i(5, 152), "engine": Vector2i(112, 152)}
	g.refresh_paths()
	return data


static func _train(g: FieldGrid, data: Dictionary) -> void:
	for side in ["upper", "lower"]:
		var y: int = TRAIN.position.y - 1 if side == "upper" else TRAIN.end.y
		for x in [58, 74, 90]:
			data["train_doors"][side].append(Vector2i(x, y))
		var apron := Rect2i(40, 147 if side == "upper" else 154, 80, 3)
		data["spots"]["unload_" + side] = {"kind": "unload", "name": "언덕 쪽 하역 자리" if side == "upper" else "아래 들판 하역 자리", "cell": Vector2i(74, 149 if side == "upper" else 155), "state": "open", "zone_rect": apron}
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
