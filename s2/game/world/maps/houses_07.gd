# 이 지도가 다른 판단을 만드는 것: 열린 돌 아치 길목을 지킬지, 얼음 여울로 둘러 건너편 연립을 뒤질지, 막힌 트러스 다리의 화차 틈을 뚫을지 고른다.
extends RefCounted

const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 180
const HEIGHT: int = 116
const PLACE_ID: String = "houses_07"
const ZONE_NAMES: Dictionary = {"A": "북쪽 역 구내", "B": "강과 제방", "C": "강 건너 살림 마을", "D": "선창 창고 앞뜰"}
const ENTRY_NAMES: Dictionary = {"west_track": "서쪽 선로", "east_track": "동쪽 선로", "west_bank": "서쪽 제방 길", "east_bank": "동쪽 제방 길", "south_lane": "남쪽 마을 길"}
const ENTRY_WEIGHTS: Dictionary = {"west_track": 0.7, "east_track": 0.7, "west_bank": 1.0, "east_bank": 1.0, "south_lane": 0.6}
const FIRST_ENTRY: String = "west_bank"

# 모든 자리는 바깥 띠를 더하기 전 칸이다. 강은 바깥 띠(map_ring.gd edge_water)에서도 끝까지 이어진다.
# 한 칸 집은 방 하나짜리 5×5 집으로 잡았다. 길 길이는 같은 출발·도착 칸의 네 방향 이동 수다.
# 지도 상자는 houses_06의 연면적 9874칸·151개를 따라 연면적 4581칸에 70개, 동쪽 연립에 열을 더해 80개다.
# 묶음은 houses 01~06이 정차마다 주는 몫(169~270, 평균 216)에 맞춰 199다: 집·헛간 상자마다 둘(먹을 것·널빤지),
# 선창 창고 여덟(WAREHOUSE_BOX), 다리 끝 다섯, 동쪽 연립 스물(창고에서 덜어 온 몫, EAST_ROW_BOXES).
# 연립은 집집마다 방 이름표(_unit_hints)로 부엌·침실·욕실 가구를 받아 여닫는 자리가 서고, 동쪽 연립은 그 자리를 더해
# 상자 하나당 묶음을 houses 01~06의 범위(0.46~0.70)에 가깝게 맞춘다. 정차를 차릴 때 물건은 같은 건물 상자끼리만
# 옮겨 담기므로 연립마다 물건을 두어 통째로 빈 건물이 없게 한다.
## 선창 창고 상자 하나: 가장 값진 자리라 상자당 물건이 다음 건물의 두 배 넘는다. 처음 열둘에서 상자마다 먹을 것 둘·
## 고철 하나·널빤지 하나를 동쪽 연립으로 덜었다(코디 판단 442, 10-30: 지도 물건 합 그대로, 연립 넷 모두에 물건).
const WAREHOUSE_BOX: Array[String] = ["food_pack", "food_pack", "food_pack", "food_pack", "med_box", "med_box", "bandage", "scrap"]
## 동쪽 연립 지도 상자 열(층마다 4·3·3): 창고에서 덜어 온 먹을 것 열·고철 다섯·널빤지 다섯.
const EAST_ROW_BOXES: Array = [["food_pack", "scrap"], ["food_pack", "plank"], ["food_pack", "scrap"], ["food_pack", "plank"],
	["food_pack", "scrap"], ["food_pack", "plank"], ["food_pack", "scrap"], ["food_pack", "plank"], ["food_pack", "scrap"],
	["food_pack", "plank"]]
# 다리 소품은 길게 늘어나지 않으므로 난간과 트러스를 나누어 이어 놓는다.
const PLAN: Dictionary = {
	"train": [42, 24, 80, 3],
	"platform": [42, 27, 80, 4],
	"river": [0, 44, 180, 18],
	"arch": [80, 42, 3, 22],
	"truss": [140, 42, 4, 22],
	"ford": [100, 44, 4, 18],
	"route_start": [82, 27],
	"route_goal": [82, 73],
	"grounds": [
		{"rect": [0, 21, 180, 3], "floor": F.GRAVEL},
		{"rect": [0, 27, 180, 4], "floor": F.GRAVEL},
		{"rect": [0, 40, 180, 4], "floor": F.GRAVEL},
		{"rect": [0, 62, 180, 4], "floor": F.GRAVEL},
		{"rect": [80, 31, 3, 13], "floor": F.ROAD},
		{"rect": [100, 31, 4, 13], "floor": F.GRAVEL},
		{"rect": [140, 31, 4, 13], "floor": F.GRAVEL},
		{"rect": [80, 64, 3, 10], "floor": F.ROAD},
		{"rect": [100, 62, 4, 13], "floor": F.GRAVEL},
		{"rect": [140, 64, 4, 30], "floor": F.ROAD},
		{"rect": [4, 90, 172, 4], "floor": F.ROAD},
		{"rect": [56, 66, 3, 50], "floor": F.ROAD},
		{"rect": [96, 66, 3, 46], "floor": F.GRAVEL}
	],
	"buildings": [
		{"name": "강변 연립", "rect": [26, 72, 24, 14], "top": 2, "basement": false, "role": "home", "id": 0, "row_group": "houses_07:연립", "door": [38, 72], "boxes_per_floor": 5},
		{"name": "안뜰 연립", "rect": [64, 74, 24, 15], "top": 3, "basement": false, "role": "home", "id": 1, "row_group": "houses_07:연립", "door": [76, 74], "boxes_per_floor": 5},
		{"name": "여울 연립", "rect": [111, 75, 24, 14], "top": 2, "basement": false, "role": "home", "id": 2, "row_group": "houses_07:연립", "door": [123, 75], "boxes_per_floor": 5},
		{"name": "돌담 집", "rect": [10, 94, 12, 10], "top": 1, "basement": true, "role": "home", "id": 3, "door": [16, 94], "boxes_per_floor": 2},
		{"name": "중정 살림집", "rect": [35, 96, 14, 10], "top": 2, "basement": false, "role": "home", "id": 4, "door": [42, 96], "boxes_per_floor": 2},
		{"name": "남쪽 집", "rect": [73, 99, 12, 10], "top": 1, "basement": true, "role": "home", "id": 5, "door": [79, 99], "boxes_per_floor": 2},
		{"name": "텃밭 살림집", "rect": [107, 96, 16, 12], "top": 2, "basement": false, "role": "home", "id": 6, "door": [115, 96], "boxes_per_floor": 3},
		{"name": "다리지기 집", "rect": [70, 65, 5, 5], "top": 1, "basement": false, "role": "home", "id": 7, "door": [74, 67], "boxes_per_floor": 1},
		{"name": "선창 창고", "rect": [145, 67, 24, 16], "top": 1, "basement": false, "role": "shed", "id": 8, "main": true, "stock": ["crate_stack", "sack_pile", "shelf"], "door": [157, 67], "boxes_per_floor": 5},
		{"name": "역사", "rect": [76, 7, 24, 12], "top": 1, "basement": false, "role": "office", "id": 9, "stock": ["desk", "file_cabinet", "shelf"], "door": [88, 18], "boxes_per_floor": 4},
		{"name": "장작 헛간", "rect": [13, 12, 14, 10], "top": 1, "basement": false, "role": "shed", "id": 10, "stock": ["sack_pile", "shelf"], "door": [20, 21], "boxes_per_floor": 2},
		{"name": "선로 헛간", "rect": [143, 20, 16, 11], "top": 1, "basement": false, "role": "shed", "id": 11, "stock": ["crate_stack", "shelf"], "door": [150, 30], "boxes_per_floor": 2},
		{"name": "동쪽 연립", "rect": [146, 95, 24, 15], "top": 3, "basement": false, "role": "home", "id": 12, "row_group": "houses_07:연립", "door": [158, 95], "boxes_per_floor": [4, 3, 3]}
	],
	"props": [
		{"kind": "water", "rect": [0, 46, 80, 14], "solid": "low", "facing": 0, "note": "서쪽 깊은 물", "level": 0},
		{"kind": "water", "rect": [83, 46, 17, 14], "solid": "low", "facing": 0, "note": "아치와 여울 사이 깊은 물", "level": 0},
		{"kind": "water", "rect": [104, 46, 36, 14], "solid": "low", "facing": 0, "note": "여울과 트러스 사이 깊은 물", "level": 0},
		{"kind": "water", "rect": [144, 46, 36, 14], "solid": "low", "facing": 0, "note": "동쪽 깊은 물", "level": 0},
		{"kind": "bridge_rail", "rect": [79, 42, 1, 6], "solid": "none", "facing": 1, "note": "돌 아치 서쪽 난간, 몸과 시야를 막지 않는다", "level": 0},
		{"kind": "bridge_rail", "rect": [79, 48, 1, 6], "solid": "none", "facing": 1, "note": "돌 아치 서쪽 난간, 몸과 시야를 막지 않는다", "level": 0},
		{"kind": "bridge_rail", "rect": [79, 54, 1, 6], "solid": "none", "facing": 1, "note": "돌 아치 서쪽 난간, 몸과 시야를 막지 않는다", "level": 0},
		{"kind": "bridge_rail", "rect": [79, 60, 1, 4], "solid": "none", "facing": 1, "note": "돌 아치 서쪽 난간, 몸과 시야를 막지 않는다", "level": 0},
		{"kind": "bridge_rail", "rect": [83, 42, 1, 6], "solid": "none", "facing": 1, "note": "돌 아치 동쪽 난간, 몸과 시야를 막지 않는다", "level": 0},
		{"kind": "bridge_rail", "rect": [83, 48, 1, 6], "solid": "none", "facing": 1, "note": "돌 아치 동쪽 난간, 몸과 시야를 막지 않는다", "level": 0},
		{"kind": "bridge_rail", "rect": [83, 54, 1, 6], "solid": "none", "facing": 1, "note": "돌 아치 동쪽 난간, 몸과 시야를 막지 않는다", "level": 0},
		{"kind": "bridge_rail", "rect": [83, 60, 1, 4], "solid": "none", "facing": 1, "note": "돌 아치 동쪽 난간, 몸과 시야를 막지 않는다", "level": 0},
		{"kind": "bridge_truss", "rect": [140, 42, 2, 8], "solid": "none", "facing": 1, "note": "쇠 다리 서쪽 트러스", "level": 0},
		{"kind": "bridge_truss", "rect": [140, 50, 2, 8], "solid": "none", "facing": 1, "note": "쇠 다리 서쪽 트러스", "level": 0},
		{"kind": "bridge_truss", "rect": [140, 58, 2, 6], "solid": "none", "facing": 1, "note": "쇠 다리 서쪽 트러스", "level": 0},
		{"kind": "bridge_truss", "rect": [142, 42, 2, 8], "solid": "none", "facing": 1, "note": "쇠 다리 동쪽 트러스", "level": 0},
		{"kind": "bridge_truss", "rect": [142, 50, 2, 8], "solid": "none", "facing": 1, "note": "쇠 다리 동쪽 트러스", "level": 0},
		{"kind": "bridge_truss", "rect": [142, 58, 2, 6], "solid": "none", "facing": 1, "note": "쇠 다리 동쪽 트러스", "level": 0},
		{"kind": "box_wagon", "rect": [140, 50, 3, 6], "solid": "low", "facing": 1, "fallen": true, "note": "옆으로 넘어진 화차, 동쪽 한 칸만 통한다", "level": 0},
		{"kind": "crate_stack", "rect": [140, 48, 3, 2], "solid": "low", "facing": 0, "note": "화차 앞에 쏟아진 상자 더미", "level": 0},
		{"kind": "crate_stack", "rect": [140, 56, 3, 2], "solid": "low", "facing": 0, "note": "화차 뒤에 쏟아진 상자 더미", "level": 0},
		{"kind": "sled_load", "rect": [141, 46, 2, 2], "solid": "low", "facing": 1, "note": "트러스 북쪽에 남은 짐 썰매", "level": 0},
		{"kind": "sleeper_stack", "rect": [140, 58, 2, 2], "solid": "low", "facing": 1, "note": "트러스 남쪽 침목 더미", "level": 0},
		{"kind": "crate_stack", "rect": [75, 40, 2, 2], "solid": "low", "facing": 0, "note": "아치 북쪽 끝 보급 상자 더미", "level": 0},
		{"kind": "crate_stack", "rect": [85, 64, 2, 2], "solid": "low", "facing": 0, "note": "아치 남쪽 끝 보급 상자 더미", "level": 0},
		{"kind": "crate_stack", "rect": [146, 63, 2, 2], "solid": "low", "facing": 0, "note": "트러스 끝 선창 보급 상자 더미", "level": 0},
		{"kind": "sled_load", "rect": [170, 68, 2, 3], "solid": "low", "facing": 1, "note": "선창 창고 곁 짐 썰매", "level": 0},
		{"kind": "sleeper_stack", "rect": [134, 67, 3, 2], "solid": "low", "facing": 0, "note": "선창으로 내릴 침목 더미", "level": 0}
	],
	"containers": [
		{"id": "arch_north", "name": "북쪽 다리 끝 창고 상자", "cell": [77, 41]},
		{"id": "arch_south", "name": "남쪽 다리 끝 창고 상자", "cell": [87, 64]},
		{"id": "truss_south", "name": "선창 다리 끝 창고 상자", "cell": [148, 64]}
	],
	"entries": [
		{"id": "west_track", "cells": [[0, 24], [0, 25], [0, 26]], "gap": 1.0},
		{"id": "east_track", "cells": [[179, 24], [179, 25], [179, 26]], "gap": 1.0},
		{"id": "west_bank", "cells": [[0, 62], [0, 63], [0, 64]], "gap": 0.6},
		{"id": "east_bank", "cells": [[179, 62], [179, 63], [179, 64]], "gap": 0.6},
		{"id": "south_lane", "cells": [[56, 115], [57, 115], [58, 115]], "gap": 2.0}
	],
	"dead_arch": [[77, 44], [86, 44], [78, 65], [86, 66]],
	"dead_truss": [[137, 44], [145, 61], [141, 66]],
	"dead_warehouse": [[151, 65], [159, 65], [171, 73], [155, 85], [143, 78]]
}


static func build() -> Dictionary:
	var g := FieldGrid.new(WIDTH, HEIGHT)
	var upper := FieldGrid.new(WIDTH, HEIGHT)
	var top := FieldGrid.new(WIDTH, HEIGHT)
	var cellar := FieldGrid.new(WIDTH, HEIGHT)
	upper.solid.fill(S.AIR)
	top.solid.fill(S.AIR)
	cellar.solid.fill(S.BLOCK)
	cellar.opq.fill(1)
	var train := _rect(PLAN["train"])
	var platform := _rect(PLAN["platform"])
	var data: Dictionary = {
		"grid": g, "levels": {0: g, 1: upper, 2: top, -1: cellar}, "stairs": [],
		"containers": {}, "spots": {}, "stoves": [], "entries": {}, "entry_gap": {}, "entry_levels": {},
		"buildings": [], "wagons": [], "train": train, "platform": platform, "unload": platform,
		"train_cars": [], "spawns": {"squad": [], "train_door": [], "dead_street": [], "dead_levels": [], "raiders": []},
		"labels": [], "trees": [], "low_blocks": [], "upper_rects": [], "lights": [],
		"manholes": {}, "manhole_levels": {}, "sewer_names": {}, "hole_faces": {},
		"anchors": {}, "zone_names": ZONE_NAMES.duplicate(), "place_id": PLACE_ID, "place_kind": "houses",
		"bands": {"upper": Rect2i(22, 2, 120, 22), "lower": Rect2i(22, 27, 120, 17)},
		"train_doors": {"upper": [], "lower": []}, "crossings": [], "barricade_slots": [], "interior_kind_slots": [],
		"props": [], "slow_rects": [], "entry_names": ENTRY_NAMES.duplicate(),
		"entry_weights": ENTRY_WEIGHTS.duplicate(), "first_entry": FIRST_ENTRY
	}
	for y in range(HEIGHT):
		for x in range(WIDTH):
			g.zone[g.index(Vector2i(x, y))] = "A" if y < 40 else ("B" if y < 66 else ("D" if x >= 136 and y < 88 else "C"))
	for row: Dictionary in PLAN["grounds"]:
		_paint(g, _rect(row["rect"]), -1, int(row["floor"]))
	# 강은 얼음 바닥이다. 깊은 물은 다른 지도의 언 물처럼 낮은 막힘 물 소품(PLAN props)이 막고,
	# 물가 두 칸과 세 건넘목은 걷는다.
	_paint(g, _rect(PLAN["river"]), S.NONE, F.ICE)
	data["edge_water"] = [_rect(PLAN["river"])]
	_paint(g, _rect(PLAN["ford"]), S.NONE, F.ICE)
	_paint(g, _rect(PLAN["arch"]), S.NONE, F.ROAD)
	_paint(g, _rect(PLAN["truss"]), S.NONE, F.ROAD)
	_paint(g, Rect2i(0, train.position.y, WIDTH, train.size.y), -1, F.RAIL)
	_paint(g, train, S.BLOCK)
	_paint(g, platform, S.NONE, F.PLATFORM)
	for row: Dictionary in PLAN["buildings"]:
		_building(data, row)
	for row: Dictionary in PLAN["props"]:
		var prop: Dictionary = row.duplicate(true)
		var r := _rect(row["rect"])
		prop["rect"] = r
		data["props"].append(prop)
		if row["solid"] == "low":
			_paint(g, r, S.LOW)
			data["low_blocks"].append(r)
		elif row["solid"] == "wall":
			_paint(g, r, S.WALL)
	for row: Dictionary in PLAN["containers"]:
		_box(data, String(row["id"]), String(row["name"]), _cell(row["cell"]), -1, 0, ["food_pack", "food_pack", "bandage", "med_box", "scrap"])
	for row: Dictionary in PLAN["entries"]:
		var cells: Array[Vector2i] = []
		for a: Array in row["cells"]:
			cells.append(_cell(a))
		data["entries"][row["id"]] = cells
		data["entry_gap"][row["id"]] = float(row["gap"])
	for key: String in ["dead_arch", "dead_truss", "dead_warehouse"]:
		for a: Array in PLAN[key]:
			data["spawns"]["dead_street"].append(_cell(a))
	_train(data)
	data["anchors"] = {"horde_home": Vector2i(82, 29), "whistle": Vector2i(119, 27), "flee_exit": Vector2i(0, 63), "engine": Vector2i(118, 25)}
	for lv: int in data["levels"]:
		var lg: FieldGrid = data["levels"][lv]
		if lv != 0:
			lg.zone = g.zone.duplicate()
		lg.refresh_paths()
	return data


static func _building(data: Dictionary, row: Dictionary) -> void:
	var r := _rect(row["rect"])
	var id: int = row["id"]
	var info: Dictionary = row.duplicate(true)
	info["rect"] = r
	info["door"] = _cell(row["door"])
	info["warm"] = false
	info["window_broken"] = false
	data["buildings"].append(info)
	var bottom: int = -1 if row["basement"] else 0
	for lv in range(bottom, int(row["top"])):
		var g: FieldGrid = data["levels"][lv]
		_shell(g, r, id, lv)
		if lv > 0:
			data["upper_rects"].append({"building": id, "rect": r})
		var cuts: Array[Vector2i] = []
		if lv >= 0 and row.has("row_group"):
			cuts = _row_units(g, r, id)
			_unit_hints(data, r, lv)
		if lv >= 0:
			_windows(g, r, id, _cell(row["door"]), cuts, 3 if row["role"] in ["home", "office"] else 6)
		_building_boxes(data, row, lv)
	var ground: FieldGrid = data["grid"]
	var door := _cell(row["door"])
	ground.set_solid(door, S.DOOR)
	ground.doors[door] = {"state": "closed", "hp": 8, "building": id, "cell": door}
	for lv in range(int(row["top"]) - 1):
		var stair_x: int = r.position.x + 2 if lv == 0 else r.end.x - 3
		data["stairs"].append({"cell": Vector2i(stair_x, r.position.y + 2), "low": lv, "high": lv + 1, "ladder": false})
	if row["basement"]:
		data["stairs"].append({"cell": Vector2i(r.end.x - 3, r.position.y + 2), "low": -1, "high": 0, "ladder": false})


## 연립 한 층을 두 집으로: 가운데 벽(문 하나로 이웃집과 이음), 집마다 앞쪽 큰 방(부엌·거실)과 뒤쪽 방 둘.
## 벽은 상자 칸(_building_boxes)과 계단 칸을 비켜 선다. 바깥벽과 만나는 칸(창을 두지 않을 자리)을 돌려준다.
static func _row_units(g: FieldGrid, r: Rect2i, id: int) -> Array[Vector2i]:
	var x0 := r.position.x
	var y0 := r.position.y
	var mid := x0 + int(r.size.x / 2) - 1
	var back := y0 + 8
	var walls: Array[Rect2i] = [Rect2i(mid, y0 + 1, 1, r.size.y - 2), Rect2i(x0 + 1, back, r.size.x - 2, 1),
		Rect2i(x0 + 6, back, 1, r.end.y - 1 - back), Rect2i(x0 + 17, back, 1, r.end.y - 1 - back)]
	for w: Rect2i in walls:
		_paint(g, w, S.WALL)
	for c: Vector2i in [Vector2i(mid, y0 + 3), Vector2i(x0 + 3, back), Vector2i(x0 + 8, back), Vector2i(x0 + 14, back), Vector2i(x0 + 20, back)]:
		g.set_solid(c, S.DOOR)
		g.doors[c] = {"state": "closed", "hp": 8, "building": id, "cell": c}
	var cuts: Array[Vector2i] = [Vector2i(mid, y0), Vector2i(mid, r.end.y - 1), Vector2i(x0, back), Vector2i(r.end.x - 1, back),
		Vector2i(x0 + 6, r.end.y - 1), Vector2i(x0 + 17, r.end.y - 1)]
	return cuts


## 연립 한 층 두 집의 방 이름(숨은 이름표, room_furnish가 읽는다): 앞 큰 방은 부엌(방 나누기가 거실·방을
## 떼어 낸다), 뒤 방은 바깥쪽이 침실, 가운데 벽 쪽이 욕실. 이름에 「집」이 없는 연립은 이름표가 없으면
## 방 갈래를 물려받지 못해 가구도 여닫는 자리도 없이 남는다.
static func _unit_hints(data: Dictionary, r: Rect2i, lv: int) -> void:
	var x0 := r.position.x
	var y0 := r.position.y
	var mid := x0 + int(r.size.x / 2) - 1
	var hints: Array = data.get_or_add("_room_hints", [])
	for spot: Array in [[Vector2i(x0 + 5, y0 + 5), "부엌"], [Vector2i(mid + 5, y0 + 5), "부엌"],
			[Vector2i(x0 + 3, y0 + 10), "침실"], [Vector2i(x0 + 8, y0 + 10), "욕실"],
			[Vector2i(mid + 3, y0 + 10), "욕실"], [Vector2i(x0 + 20, y0 + 10), "침실"]]:
		hints.append({"text": spot[1], "cell": spot[0], "level": lv})


## 바깥벽 창: 네 벽에 `step`칸마다, 모서리·문·안벽이 만나는 칸과 그 곁은 비운다.
static func _windows(g: FieldGrid, r: Rect2i, id: int, door: Vector2i, cuts: Array[Vector2i], step: int) -> void:
	var spots: Array[Vector2i] = []
	for x in range(r.position.x + 2, r.end.x - 2, step):
		spots.append(Vector2i(x, r.position.y))
		spots.append(Vector2i(x, r.end.y - 1))
	for y in range(r.position.y + 2, r.end.y - 2, step):
		spots.append(Vector2i(r.position.x, y))
		spots.append(Vector2i(r.end.x - 1, y))
	for c: Vector2i in spots:
		var near := (c - door).abs()
		if near.x + near.y <= 1:
			continue
		var by_cut := false
		for k: Vector2i in cuts:
			by_cut = by_cut or absi(k.x - c.x) + absi(k.y - c.y) <= 1
		if by_cut or g.solid_at(c) != S.WALL:
			continue
		g.set_solid(c, S.WINDOW)
		g.windows[c] = {"broken": false, "glass": false, "building": id, "cell": c}


static func _building_boxes(data: Dictionary, row: Dictionary, lv: int) -> void:
	var r := _rect(row["rect"])
	var cells: Array[Vector2i] = [
		Vector2i(r.position.x + 2, r.end.y - 3),
		Vector2i(r.end.x - 3, r.end.y - 3),
		Vector2i(r.position.x + int(r.size.x / 2), r.end.y - 3),
		Vector2i(r.position.x + 2, r.position.y + int(r.size.y / 2)),
		Vector2i(r.end.x - 3, r.position.y + int(r.size.y / 2))
	]
	# 층마다 수가 다르면(동쪽 연립) 줄로 적는다. first는 그 건물에서 이 층 앞까지 놓은 상자 수.
	var counts: Variant = row["boxes_per_floor"]
	var first := 0
	if counts is Array:
		for k in range(lv):
			first += int(counts[k])
	for n in range(int(counts[lv]) if counts is Array else int(counts)):
		var suffix: String = "창고 상자"
		if row["role"] == "home" and lv >= 0:
			suffix = "살림방 상자" if n % 2 == 0 else "부엌 상자"
		var items: Array = ["food_pack", "plank"]
		if int(row["id"]) == 8:
			items = WAREHOUSE_BOX
		elif int(row["id"]) == 12:
			items = EAST_ROW_BOXES[first + n]
		var id: String = "cache_%d_%d_%d" % [row["id"], lv, n]
		_box(data, id, String(row["name"]) + " " + suffix, cells[n], int(row["id"]), lv, items)


static func _box(data: Dictionary, id: String, title: String, cell: Vector2i, building: int, level: int, items: Array) -> void:
	data["containers"][id] = {"id": id, "name": title, "cell": cell, "level": level, "building": building,
		"search": 4.0 if level == 0 else 6.0, "items": items.duplicate(), "locked": false, "searched": false}


static func _train(data: Dictionary) -> void:
	var g: FieldGrid = data["grid"]
	var train: Rect2i = data["train"]
	for side: String in ["upper", "lower"]:
		var y: int = train.position.y - 1 if side == "upper" else train.end.y
		for offset: int in [8, 24, 40, 56]:
			data["train_doors"][side].append(Vector2i(train.position.x + offset, y))
	data["spawns"]["train_door"] = data["train_doors"]["upper"] + data["train_doors"]["lower"]
	data["spawns"]["squad"] = [Vector2i(80, 29), Vector2i(81, 29), Vector2i(82, 29), Vector2i(83, 29)]
	for x: int in [train.position.x - 1, train.end.x]:
		var cells: Array[Vector2i] = []
		for y in range(train.position.y - 1, train.end.y + 1):
			var c := Vector2i(x, y)
			cells.append(c)
			g.floor[g.index(c)] = F.GRAVEL
		data["crossings"].append({"cells": cells, "who": {"person": true, "zombie": true, "carrying": true, "wounded": true, "sled": true}})
	for n in range(5):
		data["train_cars"].append({"rect": Rect2i(train.position.x + n * 16, train.position.y, 16, 3), "kind": "engine" if n == 4 else "car"})
	data["spots"]["unload_lower"] = {"kind": "unload", "name": "승강장 하역 자리", "cell": Vector2i(82, 29), "state": "open", "zone_rect": data["unload"]}


static func _shell(g: FieldGrid, r: Rect2i, id: int, level: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			g.building[g.index(c)] = id
			g.floor[g.index(c)] = F.GRAVEL if level < 0 else F.WOOD
			var wall: bool = x == r.position.x or x == r.end.x - 1 or y == r.position.y or y == r.end.y - 1
			g.set_solid(c, S.WALL if wall else S.NONE)


static func _paint(g: FieldGrid, r: Rect2i, solid: int = -1, floor_kind: int = -1) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			if solid >= 0:
				g.set_solid(c, solid)
			if floor_kind >= 0:
				g.floor[g.index(c)] = floor_kind


static func _rect(a: Array) -> Rect2i:
	return Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))


static func _cell(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))
