# 이 지도가 다른 판단을 만드는 것: 운반조 다섯을 모두 부르려면 얼음 쪽 끝까지 가야 하고, 그 사이 첫 무리가 얼음을 건너온다.
extends RefCounted

const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const PLACE_ID: String = "story_01"
const WIDTH: int = 140
const HEIGHT: int = 100
const TRAIN: Rect2i = Rect2i(30, 38, 80, 3)
const BANDS: Dictionary = {"upper": Rect2i(10, 16, 120, 22), "lower": Rect2i(10, 41, 120, 22)}
const ENTRY_NAMES: Dictionary = {"ice_west": "서쪽 얼음길", "ice_east": "동쪽 얼음길", "village_road": "마을 쪽 길"}
const ENTRY_WEIGHTS: Dictionary = {"ice_west": 1.0, "ice_east": 1.0, "village_road": 0.5}
const FIRST_ENTRY: String = "ice_west"

# 한 칸은 1m다. 둘레까지 포함한 최종 좌표이며 확장이나 층 복제는 하지 않는다.
# 같은 구역 글자 C의 두 사각형은 두 호수 가장자리다. 구역 이름은 모두 네 개다.
const PLAN: Dictionary = {
	"zones": [
		["A", "승강장과 급수탑", [0, 0, 140, 100]],
		["B", "저탄장", [55, 63, 65, 37]],
		["C", "호수 얼음길", [0, 0, 15, 100]],
		["C", "호수 얼음길", [126, 0, 14, 100]],
		["D", "원형 기관고", [25, 71, 30, 24]]
	],
	"labels": [["승강장과 급수탑", [73, 26]], ["저탄장", [70, 66]], ["호수 얼음길", [12, 84]], ["원형 기관고", [40, 76]]],
	"floors": [
		[0, 0, 15, 100, 6], [126, 0, 14, 100, 6],
		[70, 0, 10, 16, 1], [15, 76, 40, 10, 7], [55, 63, 65, 33, 7],
		[25, 63, 30, 8, 7], [103, 3, 8, 10, 6], [105, 92, 20, 1, 4]
	],
	"buildings": [{"id": 0, "name": "원형 기관고", "rect": [25, 71, 30, 24], "warm": false, "window_broken": false}],
	"roundhouse_rows": [[71, 78, 25, 55], [78, 84, 27, 53], [84, 89, 31, 49], [89, 94, 35, 45], [94, 95, 38, 42]],
	"walls": [[27, 83, 26, 1]],
	"doors": [[35, 71], [45, 71], [40, 83]],
	"deep": {"rect": [31, 84, 18, 11], "door": [40, 83], "approach": [40, 79]},
	"props": [
		{"kind": "water", "rect": [5, 0, 5, 76], "solid": "low", "facing": 0, "note": "서쪽 호수의 열린 물", "level": 0},
		{"kind": "water", "rect": [134, 0, 6, 88], "solid": "low", "facing": 0, "note": "동쪽 호수의 열린 물", "level": 0},
		{"kind": "sleeper_pile", "rect": [33, 29, 4, 2], "solid": "low", "facing": 0, "note": "승강장 서쪽 침목 더미", "level": 0},
		{"kind": "crate_stack", "rect": [40, 29, 4, 2], "solid": "low", "facing": 0, "note": "승강장 자재 상자", "level": 0},
		{"kind": "snow_drift", "rect": [87, 23, 4, 2], "solid": "low", "facing": 0, "note": "급수탑 앞 눈 둔덕", "level": 0},
		{"kind": "sleeper_pile", "rect": [94, 23, 4, 2], "solid": "low", "facing": 0, "note": "승강장 동쪽 침목 더미", "level": 0},
		{"kind": "sleeper_pile", "rect": [21, 55, 5, 2], "solid": "low", "facing": 0, "note": "저탄장 서쪽 침목 더미", "level": 0},
		{"kind": "crate_stack", "rect": [29, 55, 4, 2], "solid": "low", "facing": 0, "note": "기관고 앞 자재 상자", "level": 0},
		{"kind": "crate_stack", "rect": [112, 53, 4, 2], "solid": "low", "facing": 0, "note": "저탄장 동쪽 자재 상자", "level": 0},
		{"kind": "snow_drift", "rect": [119, 53, 5, 2], "solid": "low", "facing": 0, "note": "동쪽 얼음길 앞 눈 둔덕", "level": 0},
		{"kind": "water_tower", "rect": [103, 5, 5, 5], "solid": "wall", "facing": 0, "note": "얼어붙은 급수탑", "level": 0},
		{"kind": "water_crane", "rect": [88, 11, 2, 2], "solid": "low", "facing": 0, "note": "얼어붙은 급수관", "level": 0},
		{"kind": "turntable_deck", "rect": [34, 64, 12, 5], "solid": "none", "facing": 0, "note": "땅과 높이가 같은 전차대", "level": 0},
		{"kind": "turntable_rim", "rect": [32, 65, 2, 4], "solid": "low", "facing": 0, "note": "전차대 서쪽 테두리", "level": 0},
		{"kind": "turntable_rim", "rect": [46, 65, 2, 4], "solid": "low", "facing": 0, "note": "전차대 동쪽 테두리", "level": 0},
		{"kind": "turntable_rim", "rect": [36, 63, 6, 1], "solid": "low", "facing": 0, "note": "전차대 앞 테두리", "level": 0},
		{"kind": "turntable_rim", "rect": [36, 69, 6, 1], "solid": "low", "facing": 0, "note": "전차대 뒤 테두리", "level": 0},
		{"kind": "coal_heap", "rect": [60, 79, 5, 3], "solid": "low", "facing": 0, "note": "저탄장 서쪽 석탄 더미", "level": 0},
		{"kind": "coal_heap", "rect": [75, 88, 5, 4], "solid": "low", "facing": 0, "note": "저탄장 안쪽 석탄 더미", "level": 0},
		{"kind": "coal_heap", "rect": [96, 68, 5, 3], "solid": "low", "facing": 0, "note": "저탄장 앞 석탄 더미", "level": 0},
		{"kind": "crate_stack", "rect": [70, 76, 3, 2], "solid": "low", "facing": 0, "note": "낮은 석탄 통", "level": 0},
		{"kind": "crate_stack", "rect": [98, 84, 3, 2], "solid": "low", "facing": 0, "note": "안쪽 낮은 석탄 통", "level": 0},
		{"kind": "bare_tree", "rect": [18, 3, 1, 1], "solid": "tree", "facing": 0, "note": "북쪽 숲 가장자리", "level": 0},
		{"kind": "bare_tree", "rect": [29, 7, 1, 1], "solid": "tree", "facing": 0, "note": "북쪽 마른 나무", "level": 0},
		{"kind": "bare_tree", "rect": [91, 4, 1, 1], "solid": "tree", "facing": 0, "note": "급수탑 뒤 마른 나무", "level": 0},
		{"kind": "bare_tree", "rect": [119, 8, 1, 1], "solid": "tree", "facing": 0, "note": "북동쪽 숲 가장자리", "level": 0},
		{"kind": "bare_tree", "rect": [57, 98, 1, 1], "solid": "tree", "facing": 0, "note": "남쪽 숲 가장자리", "level": 0},
		{"kind": "bare_tree", "rect": [100, 97, 1, 1], "solid": "tree", "facing": 0, "note": "측선 뒤 마른 나무", "level": 0},
		{"kind": "bare_tree", "rect": [122, 96, 1, 1], "solid": "tree", "facing": 0, "note": "남동쪽 숲 가장자리", "level": 0}
	],
	"coal_boxes": [
		["coal_front_01", [63, 72]], ["coal_front_02", [74, 68]], ["coal_front_03", [89, 69]], ["coal_front_04", [102, 74]],
		["coal_ice_01", [12, 81]], ["coal_ice_02", [15, 86]], ["coal_ice_03", [128, 79]], ["coal_ice_04", [131, 86]]
	],
	"tool_boxes": [["tools_shallow", "기관고 앞방 공구 상자", [35, 78]], ["tools_deep", "기관고 안쪽 공구 상자", [40, 90]]],
	"wagons": [{"id": "coal_siding", "name": "열린 석탄 화차", "rect": [108, 91, 12, 3], "coal": 0, "work": [112, 90]}],
	"entries": [["ice_west", [[1, 18], [1, 19], [1, 20]], 1.4], ["ice_east", [[137, 95], [137, 96], [137, 97]], 1.4], ["village_road", [[74, 0], [75, 0], [76, 0]], 2.0]],
	"barricades": [[37, 30], [38, 30], [39, 30], [91, 24], [92, 24], [93, 24], [26, 56], [27, 56], [28, 56], [116, 54], [117, 54], [118, 54]],
	"work_site": {"cell": [69, 68], "rect": [58, 64, 50, 31]},
	"story_spots": [
		["story_porter_01", "저탄장 앞쪽 운반조", [65, 72], [64, 71, 3, 3]],
		["story_porter_02", "저탄장 안쪽 운반조", [81, 82], [80, 81, 3, 3]],
		["story_porter_03", "저탄장 동쪽 운반조", [102, 88], [101, 87, 3, 3]],
		["story_porter_04", "서쪽 얼음 끝 운반조", [12, 82], [10, 80, 5, 5]],
		["story_porter_05", "동쪽 얼음 끝 운반조", [131, 83], [128, 81, 5, 5]],
		["story_platform_end", "승강장 끝의 빈 터", [90, 35], [82, 31, 15, 7]]
	]
}


static func build() -> Dictionary:
	var g := FieldGrid.new(WIDTH, HEIGHT)
	var levels: Dictionary = {0: g}
	var data: Dictionary = {
		"grid": g, "levels": levels, "stairs": [], "containers": {}, "spots": {},
		"stoves": [], "entries": {}, "entry_gap": {}, "entry_levels": {},
		"buildings": [], "wagons": [], "train": TRAIN,
		"platform": Rect2i(46, 34, 47, 4), "unload": Rect2i(30, 41, 80, 3),
		"train_cars": [], "spawns": {}, "labels": [], "trees": [], "low_blocks": [],
		"upper_rects": [], "lights": [], "manholes": {}, "manhole_levels": {},
		"sewer_names": {}, "anchors": {}, "zone_names": {}, "place_id": PLACE_ID,
		"place_kind": "freight", "bands": BANDS.duplicate(true),
		"train_doors": {"upper": [], "lower": []}, "crossings": [], "barricade_slots": [],
		"interior_kind_slots": [{"zone": "D", "kinds": ["empty", "raiders", "nest", "beasts"]}],
		"props": [], "hole_faces": {}, "entry_names": ENTRY_NAMES.duplicate(),
		"entry_weights": ENTRY_WEIGHTS.duplicate(), "first_entry": FIRST_ENTRY
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
	_fill_floor(g, data["platform"], F.PLATFORM)
	_fill_floor(g, data["unload"], F.GRAVEL)
	_fill_solid(g, TRAIN, S.BLOCK)
	for row in PLAN["buildings"]:
		var b: Dictionary = row.duplicate(true)
		b["rect"] = _rect(row["rect"])
		data["buildings"].append(b)
	_roundhouse(g)
	for row in PLAN["walls"]:
		_fill_solid(g, _rect(row), S.WALL)
	for row in PLAN["doors"]:
		var c := _cell(row)
		g.set_solid(c, S.DOOR)
		g.doors[c] = {"state": "open", "hp": 8, "building": 0, "cell": c}
	for row in PLAN["props"]:
		var pr: Dictionary = row.duplicate(true)
		var r := _rect(row["rect"])
		pr["rect"] = r
		data["props"].append(pr)
		match String(pr["solid"]):
			"low":
				_fill_solid(g, r, S.LOW)
				if pr["kind"] == "water":
					_fill_floor(g, r, F.ICE)
				else:
					data["low_blocks"].append(r)
			"wall":
				_fill_solid(g, r, S.WALL)
			"tree":
				_fill_solid(g, r, S.BLOCK)
				data["trees"].append(r.position)
	for row in PLAN["wagons"]:
		var wagon: Dictionary = row.duplicate(true)
		wagon["rect"] = _rect(row["rect"])
		wagon["work"] = _cell(row["work"])
		data["wagons"].append(wagon)
		_fill_solid(g, wagon["rect"], S.BLOCK)
	# 석탄은 사건 쪽에서 채운다. 여기서는 상자 자리만 두고 수량을 정하지 않는다.
	for row in PLAN["coal_boxes"]:
		data["containers"][row[0]] = {"id": row[0], "name": "석탄 자루 상자", "cell": _cell(row[1]), "building": -1, "search": 4.0, "items": [], "locked": false, "level": 0, "searched": false}
	for row in PLAN["tool_boxes"]:
		data["containers"][row[0]] = {"id": row[0], "name": row[1], "cell": _cell(row[2]), "building": 0, "search": 4.0, "items": ["scrap"], "locked": false, "level": 0, "searched": false}
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
	data["spots"]["work_site"] = {"kind": "work_site", "cell": _cell(work["cell"]), "name": "저탄장 작업 구역", "state": "closed", "zone_rect": _rect(work["rect"])}
	for row in PLAN["story_spots"]:
		data["spots"][row[0]] = {"kind": "story", "cell": _cell(row[2]), "name": row[1], "zone_rect": _rect(row[3])}
	# 초기 망자와 누운 몸은 없다. 첫 얼음 물결의 시계와 운반조는 사건 쪽 소유다.
	data["spawns"] = {"squad": [Vector2i(64, 44), Vector2i(62, 45), Vector2i(66, 45)], "train_door": data["train_doors"]["upper"] + data["train_doors"]["lower"], "dead_ice": [], "dead_levels": []}
	data["anchors"] = {"horde_home": Vector2i(64, 44), "whistle": Vector2i(108, 41), "flee_exit": Vector2i(75, 0), "engine": Vector2i(102, 39)}
	g.refresh_paths()
	return data


static func _train(g: FieldGrid, data: Dictionary) -> void:
	for side in ["upper", "lower"]:
		var y: int = TRAIN.position.y - 1 if side == "upper" else TRAIN.end.y
		for x in [48, 64, 80]:
			data["train_doors"][side].append(Vector2i(x, y))
		var apron: Rect2i = Rect2i(46, 34, 47, 3) if side == "upper" else Rect2i(30, 41, 80, 3)
		data["spots"]["unload_" + side] = {"kind": "unload", "name": "승강장 하역 자리" if side == "upper" else "저탄장 하역 자리", "cell": Vector2i(64, 36 if side == "upper" else 42), "state": "open", "zone_rect": apron}
	# 열차 밑을 뚫지 않는다. 양 끝으로 사람과 무리가 돌아간다.
	for x in [TRAIN.position.x - 1, TRAIN.end.x]:
		var cells: Array[Vector2i] = []
		for y in range(TRAIN.position.y - 1, TRAIN.end.y + 1):
			var c := Vector2i(x, y)
			cells.append(c)
			g.floor[g.index(c)] = F.GRAVEL
		data["crossings"].append({"cells": cells, "who": {"person": true, "zombie": true, "carrying": true, "wounded": true, "sled": true}})
	for k in range(5):
		data["train_cars"].append({"rect": Rect2i(TRAIN.position.x + 16 * k, TRAIN.position.y, 16, 3), "kind": "engine" if k == 4 else "car"})


static func _roundhouse(g: FieldGrid) -> void:
	# 북쪽의 넓은 정비문에서 남쪽으로 좁아지는 반원 윤곽. 전용 지붕은 만들지 않는다.
	for row in PLAN["roundhouse_rows"]:
		for y in range(int(row[0]), int(row[1])):
			for x in range(int(row[2]), int(row[3])):
				var c := Vector2i(x, y)
				g.building[g.index(c)] = 0
				g.floor[g.index(c)] = F.WOOD
	for row in PLAN["roundhouse_rows"]:
		for y in range(int(row[0]), int(row[1])):
			for x in range(int(row[2]), int(row[3])):
				var c := Vector2i(x, y)
				for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if g.building_at(c + step) != 0:
						g.set_solid(c, S.WALL)
						break


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
