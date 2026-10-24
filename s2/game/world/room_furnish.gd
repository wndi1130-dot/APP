extends RefCounted
## 방 안 가구 규칙(docs/design/briefs/house_layout.md 1·3장). 지금 넣은 것은
## 「가구는 몸을 막는다」다: 건물 안 가구를 모든 층에서 낮은 막힘(LOW)으로 칠한다.
## 땅 층은 모델이 없어도 회색 덩이로 그려지니 막고, 위층·지하는 모델로 그려지는
## 것만 막는다(보이면 막고, 안 보이면 막지 않는다). 칠하면 그 방의 문·계단·상자·
## 다른 가구 앞으로 가는 길이 끊기는 가구는 칠하지 않고 셈에 남긴다.
## 지도 파일과 지도의 소품 줄은 고치지 않는다. 같은 지도는 늘 같은 결과다.

const FieldGrid = preload("res://game/world/field_grid.gd")
const PropKinds = preload("res://game/world/prop_kinds.gd")
const S = FieldGrid.Solid
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## 바닥에 깔리거나, 벽에 걸리거나, 사람이 지나가는 것. 막지 않는다.
const PASS_KINDS: Dictionary = {
	"blanket_curtain": true, "oil_lamp_out": true, "lamp_post": true, "quilted_vest": true,
	"notice_board": true, "hand_bell": true, "stair_stub": true, "mine_portal": true,
	"support_frame": true, "community_banner": true, "wet_blanket": true, "inspection_pit": true,
	"dock_door": true, "blank_sign": true, "eye_chart_frame": true, "bell_rope": true,
	"skybridge_rail": true, "lift_shaft": true, "plank_patch": true, "snow_drift": true,
	"scattered_tools": true, "rope_coil": true, "plate_stack": true, "candle_stand": true,
	"weigh_platform": true, "transfer_table": true, "seedling_tray": true, "floor_shell": true,
	"water": true,
}


## 막을 가구인가. 땅 층은 모델이 없어도 회색 덩이로 보인다.
static func blocks(kind: String, lv: int) -> bool:
	if kind.is_empty() or PASS_KINDS.has(kind):
		return false
	return lv == 0 or not PropKinds.model_path(kind).is_empty()


## 건물 안 칸 덩어리: 같은 건물·같은 층에서 벽·문·창으로 나뉜다(4이웃).
## {"of": 칸 -> 방 번호, "rooms": [{"cells": [칸], "building": 번호}]}
static func rooms_of(g: FieldGrid) -> Dictionary:
	var of: Dictionary = {}
	var rooms: Array = []
	for y in range(g.height):
		for x in range(g.width):
			var c := Vector2i(x, y)
			if of.has(c) or not _interior(g, c):
				continue
			var b := g.building_at(c)
			var idx := rooms.size()
			var cells: Array[Vector2i] = []
			var stack: Array[Vector2i] = [c]
			of[c] = idx
			while not stack.is_empty():
				var cur: Vector2i = stack.pop_back()
				cells.append(cur)
				for d in DIRS:
					var n := cur + d
					if not of.has(n) and _interior(g, n) and g.building_at(n) == b:
						of[n] = idx
						stack.append(n)
			rooms.append({"cells": cells, "building": b})
	return {"of": of, "rooms": rooms}


static func _interior(g: FieldGrid, c: Vector2i) -> bool:
	if not g.inside(c) or g.building_at(c) < 0:
		return false
	var s := g.solid_at(c)
	return s == S.NONE or s == S.LOW or s == S.BLOCK


static func _rect(v: Variant) -> Variant:
	if v is Rect2i:
		return v
	if v is Array and v.size() >= 4:
		return Rect2i(int(v[0]), int(v[1]), int(v[2]), int(v[3]))
	return null


static func _cell(v: Variant) -> Variant:
	if v is Vector2i:
		return v
	if v is Array and v.size() >= 2:
		return Vector2i(int(v[0]), int(v[1]))
	return null


## 방에서 꼭 닿아야 하는 곳: 드나드는 칸(문 곁, 문 없이 뚫린 곳, 벽 없는 변),
## 계단 칸, 상자(칸이나 이웃). 칠하기 전에 걸어서 닿던 것만 센다(원래 있던
## 문제로 칠하기를 막지 않게).
static func _keys(g: FieldGrid, of: Dictionary, ri: int, cells: Array[Vector2i], stairs: Dictionary, boxes: Array) -> Dictionary:
	var seeds: Array[Vector2i] = []
	for c in cells:
		if g.solid_at(c) != S.NONE:
			continue
		if stairs.has(c):
			seeds.append(c)
			continue
		for d in DIRS:
			var n := c + d
			if of.get(n, -1) != ri and (g.doors.has(n) or g.people_can_walk(n)):
				seeds.append(c)
				break
	var box_sets: Array = []
	for c: Vector2i in boxes:
		var near: Array[Vector2i] = []
		for n: Vector2i in [c, c + DIRS[0], c + DIRS[1], c + DIRS[2], c + DIRS[3]]:
			if of.get(n, -1) == ri:
				near.append(n)
		if not near.is_empty():
			box_sets.append(near)
	return {"seeds": seeds, "boxes": box_sets}


static func _reach(g: FieldGrid, of: Dictionary, ri: int, seeds: Array[Vector2i]) -> Dictionary:
	var seen: Dictionary = {}
	var queue: Array[Vector2i] = []
	for s in seeds:
		if not seen.has(s) and g.solid_at(s) == S.NONE:
			seen[s] = true
			queue.append(s)
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for d in DIRS:
			var n := cur + d
			if not seen.has(n) and of.get(n, -1) == ri and g.solid_at(n) == S.NONE:
				seen[n] = true
				queue.append(n)
	return seen


static func _touches(rect: Rect2i, seen: Dictionary) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			if seen.has(c):
				return true
			for d in DIRS:
				if seen.has(c + d):
					return true
	return false


## 첫 드나드는 칸 하나에서 걸어서 닿는 칸. 방이 둘로 갈리면 다른 출입구에 못 닿는다.
static func _from_first(g: FieldGrid, of: Dictionary, ri: int, keys: Dictionary) -> Dictionary:
	var seeds: Array[Vector2i] = keys["seeds"]
	if seeds.is_empty():
		return {}
	var one: Array[Vector2i] = [seeds[0]]
	return _reach(g, of, ri, one)


## 칠한 뒤에도 원래 닿던 출입구·계단·상자에 다 닿고, 칠한 가구마다 앞에 설 칸이 있나.
static func _still_open(g: FieldGrid, of: Dictionary, ri: int, keys: Dictionary, before: Dictionary, painted: Array) -> bool:
	var seeds: Array[Vector2i] = keys["seeds"]
	if seeds.is_empty():
		return true
	var seen := _from_first(g, of, ri, keys)
	for s in seeds:
		if before.has(s) and not seen.has(s):
			return false
	for near: Array in keys["boxes"]:
		var was := false
		var now := false
		for n: Vector2i in near:
			was = was or before.has(n)
			now = now or seen.has(n)
		if was and not now:
			return false
	for rect: Rect2i in painted:
		if not _touches(rect, seen):
			return false
	return true


## 건물 안 가구를 LOW로 칠한다. 돌려주는 값: {"painted", "kept_path", "no_model"}.
static func block_furniture(data: Dictionary) -> Dictionary:
	return block_furniture_with(data, Callable(PropKinds, "model_path"))


## 시험은 모델이 있는지를 따로 줄 수 있다(kind -> 경로, 없으면 "").
static func block_furniture_with(data: Dictionary, has_model: Callable) -> Dictionary:
	var stats := {"painted": 0, "kept_path": 0, "no_model": 0}
	if not data.has("low_blocks"):
		data["low_blocks"] = []
	var levels: Dictionary = data.get("levels", {0: data["grid"]})
	var stairs_by: Dictionary = {}
	for st: Dictionary in data.get("stairs", []):
		var c: Variant = _cell(st.get("cell"))
		if c == null:
			continue
		for lv: int in [int(st.get("low", 0)), int(st.get("high", 1))]:
			if not stairs_by.has(lv):
				stairs_by[lv] = {}
			stairs_by[lv][c] = true
	var boxes_by: Dictionary = {}
	var containers: Variant = data.get("containers", {})
	for box: Dictionary in (containers.values() if containers is Dictionary else containers):
		var c: Variant = _cell(box.get("cell"))
		if c == null:
			continue
		var lv := int(box.get("level", 0))
		if not boxes_by.has(lv):
			boxes_by[lv] = []
		boxes_by[lv].append(c)
	var model_known: Dictionary = {}
	for lv: int in levels:
		var g: FieldGrid = levels[lv]
		var stairs: Dictionary = stairs_by.get(lv, {})
		var map := rooms_of(g)
		var of: Dictionary = map["of"]
		var wanted: Dictionary = {}  # 방 번호 -> [{"rect", "cells"}]
		for p: Dictionary in data.get("props", []):
			if int(p.get("level", 0)) != lv:
				continue
			var r: Variant = _rect(p.get("rect"))
			if r == null:
				continue
			var rect: Rect2i = r
			var kind := String(p.get("kind", ""))
			if not model_known.has(kind):
				model_known[kind] = not String(has_model.call(kind)).is_empty()
			if kind.is_empty() or PASS_KINDS.has(kind):
				continue
			var ri: int = of.get(rect.position + rect.size / 2, -1)
			if ri < 0:
				continue
			if lv != 0 and not model_known[kind]:
				stats["no_model"] += 1
				continue
			var cells: Array[Vector2i] = []
			var on_stairs := false
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					var c := Vector2i(x, y)
					if stairs.has(c):
						on_stairs = true
					if of.get(c, -1) == ri and g.solid_at(c) == S.NONE:
						cells.append(c)
			if on_stairs:
				stats["kept_path"] += 1
				continue
			if cells.is_empty():
				continue
			if not wanted.has(ri):
				wanted[ri] = []
			wanted[ri].append({"rect": rect, "cells": cells})
		if wanted.is_empty():
			continue
		var boxes: Array = boxes_by.get(lv, [])
		for ri: int in wanted:
			var room: Dictionary = map["rooms"][ri]
			var room_boxes: Array = []
			for c: Vector2i in boxes:
				for n: Vector2i in [c, c + DIRS[0], c + DIRS[1], c + DIRS[2], c + DIRS[3]]:
					if of.get(n, -1) == ri:
						room_boxes.append(c)
						break
			var keys := _keys(g, of, ri, room["cells"], stairs, room_boxes)
			var before := _from_first(g, of, ri, keys)
			var items: Array = wanted[ri]
			# 거의 모든 방은 한 번에 다 칠해도 열려 있다. 아니면 하나씩.
			var rects: Array = []
			for it: Dictionary in items:
				for c: Vector2i in it["cells"]:
					g.set_solid(c, S.LOW)
				rects.append(it["rect"])
			if _still_open(g, of, ri, keys, before, rects):
				stats["painted"] += items.size()
				if lv == 0:
					data["low_blocks"].append_array(rects)
				continue
			for it: Dictionary in items:
				for c: Vector2i in it["cells"]:
					g.set_solid(c, S.NONE)
			var kept: Array = []
			for it: Dictionary in items:
				for c: Vector2i in it["cells"]:
					g.set_solid(c, S.LOW)
				kept.append(it["rect"])
				if _still_open(g, of, ri, keys, before, kept):
					stats["painted"] += 1
					if lv == 0:
						data["low_blocks"].append(it["rect"])
				else:
					kept.pop_back()
					for c: Vector2i in it["cells"]:
						g.set_solid(c, S.NONE)
					stats["kept_path"] += 1
		g.refresh_paths()
	return stats
