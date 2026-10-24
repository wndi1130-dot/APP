extends RefCounted
## 방 안 가구 규칙(docs/design/briefs/house_layout.md 1·3장). 이 차례로 돈다.
## furnish_rooms: 살림방·부엌·거실·매장·창고·지하 저장 칸·보일러실을 묶음 규칙대로 다시 놓고
## 상자를 용기 가구 칸으로 옮긴다(아래 「방 종류별 가구」).
## clear_fronts: 문·계단 앞과 창 앞(큰 가구)에 서거나 벽에 박힌 지도 가구를 가까운 빈 자리로 옮긴다.
## block_furniture: 「가구는 몸을 막는다」. 건물 안 가구를 모든 층에서 낮은 막힘(LOW)으로 칠한다.
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
## {"of": 칸마다 방 번호(PackedInt32Array, y*너비+x, 없으면 -1), "rooms": [{"cells": [칸], "building": 번호}]}
static func rooms_of(g: FieldGrid) -> Dictionary:
	var of := PackedInt32Array()
	of.resize(g.width * g.height)
	of.fill(-1)
	var rooms: Array = []
	for y in range(g.height):
		for x in range(g.width):
			var c := Vector2i(x, y)
			if of[y * g.width + x] >= 0 or not _interior(g, c):
				continue
			var b := g.building_at(c)
			var idx := rooms.size()
			var cells: Array[Vector2i] = []
			var stack: Array[Vector2i] = [c]
			of[y * g.width + x] = idx
			while not stack.is_empty():
				var cur: Vector2i = stack.pop_back()
				cells.append(cur)
				for d in DIRS:
					var n := cur + d
					if g.inside(n) and of[n.y * g.width + n.x] < 0 and _interior(g, n) and g.building_at(n) == b:
						of[n.y * g.width + n.x] = idx
						stack.append(n)
			rooms.append({"cells": cells, "building": b})
	return {"of": of, "rooms": rooms}


## 칸의 방 번호(-1이면 방 밖).
static func _at(g: FieldGrid, of: PackedInt32Array, c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= g.width or c.y >= g.height:
		return -1
	return of[c.y * g.width + c.x]


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
static func _keys(g: FieldGrid, of: PackedInt32Array, ri: int, cells: Array[Vector2i], stairs: Dictionary, boxes: Array) -> Dictionary:
	var seeds: Array[Vector2i] = []
	for c in cells:
		if g.solid_at(c) != S.NONE:
			continue
		if stairs.has(c):
			seeds.append(c)
			continue
		for d in DIRS:
			var n := c + d
			if _at(g, of, n) != ri and (g.doors.has(n) or g.people_can_walk(n)):
				seeds.append(c)
				break
	var box_sets: Array = []
	for c: Vector2i in boxes:
		var near: Array[Vector2i] = []
		for n: Vector2i in [c, c + DIRS[0], c + DIRS[1], c + DIRS[2], c + DIRS[3]]:
			if _at(g, of, n) == ri:
				near.append(n)
		if not near.is_empty():
			box_sets.append(near)
	return {"seeds": seeds, "boxes": box_sets}


static func _reach(g: FieldGrid, of: PackedInt32Array, ri: int, seeds: Array[Vector2i]) -> Dictionary:
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
			if not seen.has(n) and _at(g, of, n) == ri and g.solid_at(n) == S.NONE:
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
static func _from_first(g: FieldGrid, of: PackedInt32Array, ri: int, keys: Dictionary) -> Dictionary:
	var seeds: Array[Vector2i] = keys["seeds"]
	if seeds.is_empty():
		return {}
	var one: Array[Vector2i] = [seeds[0]]
	return _reach(g, of, ri, one)


## 칠한 뒤에도 원래 닿던 출입구·계단·상자에 다 닿고, 칠한 가구마다 앞에 설 칸이 있나.
static func _still_open(g: FieldGrid, of: PackedInt32Array, ri: int, keys: Dictionary, before: Dictionary, painted: Array) -> bool:
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


## 이미 몸을 막는 가구(rect) 가운데 칠하기 전에 앞에 닿던 것. 새로 칠한 뒤에도 앞에
## 닿아야 한다(나중 가구가 먼저 선 가구 앞을 막지 않게).
static func _standing(g: FieldGrid, of: PackedInt32Array, ri: int, rects: Array, before: Dictionary) -> Array:
	var out: Array = []
	for r: Rect2i in rects:
		var low := false
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				low = low or (_at(g, of, c) == ri and g.solid_at(c) == S.LOW)
		if low and _touches(r, before):
			out.append(r)
	return out


## 층 -> {계단 칸: true}.
static func _stairs_by_level(data: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for st: Dictionary in data.get("stairs", []):
		var c: Variant = _cell(st.get("cell"))
		if c == null:
			continue
		for lv: int in [int(st.get("low", 0)), int(st.get("high", 1))]:
			if not out.has(lv):
				out[lv] = {}
			out[lv][c] = true
	return out


## 건물 안 가구를 LOW로 칠한다. 돌려주는 값: {"painted", "kept_path", "no_model"}.
static func block_furniture(data: Dictionary) -> Dictionary:
	return block_furniture_with(data, Callable(PropKinds, "model_path"))


## 시험은 모델이 있는지를 따로 줄 수 있다(kind -> 경로, 없으면 "").
static func block_furniture_with(data: Dictionary, has_model: Callable) -> Dictionary:
	var stats := {"painted": 0, "kept_path": 0, "no_model": 0}
	if not data.has("low_blocks"):
		data["low_blocks"] = []
	var levels: Dictionary = data.get("levels", {0: data["grid"]})
	var stairs_by := _stairs_by_level(data)
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
		var of: PackedInt32Array = map["of"]
		var wanted: Dictionary = {}  # 방 번호 -> [{"rect", "cells"}]
		var room_rects: Dictionary = {}  # 방 번호 -> [막는 가구 rect]
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
			var ri: int = _at(g, of, rect.position + rect.size / 2)
			if ri < 0:
				continue
			if not room_rects.has(ri):
				room_rects[ri] = []
			room_rects[ri].append(rect)
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
					if _at(g, of, c) == ri and g.solid_at(c) == S.NONE:
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
		var boxes_of: Dictionary = {}  # 방 번호 -> [상자 칸]
		for c: Vector2i in boxes_by.get(lv, []):
			for n: Vector2i in [c, c + DIRS[0], c + DIRS[1], c + DIRS[2], c + DIRS[3]]:
				var bi := _at(g, of, n)
				if bi >= 0:
					if not boxes_of.has(bi):
						boxes_of[bi] = []
					boxes_of[bi].append(c)
					break
		for ri: int in wanted:
			var room: Dictionary = map["rooms"][ri]
			var room_boxes: Array = boxes_of.get(ri, [])
			var keys := _keys(g, of, ri, room["cells"], stairs, room_boxes)
			var before := _from_first(g, of, ri, keys)
			var guard := _standing(g, of, ri, room_rects.get(ri, []), before)
			var items: Array = wanted[ri]
			# 거의 모든 방은 한 번에 다 칠해도 열려 있다. 아니면 하나씩.
			var rects: Array = []
			for it: Dictionary in items:
				for c: Vector2i in it["cells"]:
					g.set_solid(c, S.LOW)
				rects.append(it["rect"])
			if _still_open(g, of, ri, keys, before, rects + guard):
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
				if _still_open(g, of, ri, keys, before, kept + guard):
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


## ---------------------------------------------------------------- 문·창 앞 비움(3장 「비울 칸」)

## 창 바로 안쪽에 못 서는 큰 가구(장, 선반, 찬장, 냉장고, 책장, 진열대).
const TALL_KINDS: Dictionary = {
	"wardrobe": true, "shelf": true, "bookcase": true, "display_shelf": true, "jar_shelf": true,
	"file_cabinet": true, "fridge_open": true, "record_shelf_row": true, "map_cabinet": true,
	"hardware_rack": true, "bread_rack": true, "parts_rack": true, "cellar_shelf": true,
	"shop_shelf": true, "tool_rack": true, "medicine_cabinet": true,
}
## 옮겨 볼 거리(칸, 맨해튼). 가까운 것부터.
const NUDGE_MAX: int = 3


## 비울 칸에 걸친 가구인가: 문·계단 앞("all")은 다, 창 앞("tall")은 큰 가구만.
static func _in_front(r: Rect2i, kind: String, forbid: Dictionary) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var f: String = forbid.get(Vector2i(x, y), "")
			if f == "all" or (f == "tall" and TALL_KINDS.has(kind)):
				return true
	return false


## 가구 칸 가운데 그 방 밖(벽·문·창·옆방)에 걸친 것이 있나.
static func _sticks_out(g: FieldGrid, of: PackedInt32Array, ri: int, r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if _at(g, of, Vector2i(x, y)) != ri:
				return true
	return false


## 가구 rect가 벽에 붙은 변 수.
static func _wall_sides(g: FieldGrid, of: PackedInt32Array, ri: int, r: Rect2i) -> int:
	var n := 0
	for d in DIRS:
		if _wall_side(g, of, ri, r, d):
			n += 1
	return n


## 옮길 자리 차례: 거리 1..NUDGE_MAX, 같은 거리면 위·왼쪽부터(늘 같은 차례).
static func _nudges() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dist in range(1, NUDGE_MAX + 1):
		for dy in range(-dist, dist + 1):
			var rest := dist - absi(dy)
			for dx: int in ([-rest, rest] if rest != 0 else [0]):
				out.append(Vector2i(dx, dy))
	return out


## 문·계단 앞, 창 앞(큰 가구)에 서거나 벽에 박힌 가구를 옮긴다. 막는 가구(blocks)만 본다: 바닥에
## 깔리거나 벽에 걸리거나 안 보이는 것은 문 앞에 있어도 걸리지 않는다. 새 자리는 같은
## 방, 빈 칸(또는 제 옛 칸), 다른 가구·바닥 상자·비울 칸이 아니고, 막아도 방의
## 출입구·계단·상자로 가는 길이 남는 곳이다. 벽에 붙은 변이 줄지 않는 자리를 먼저 본다.
## 옛 칸에 든 상자는 같이 옮긴다. 자리가 없으면 다시 놓는 종류(REPLACED)는 지우고,
## 기계·이야기 소품은 둔다. 돌려주는 값: {"moved", "removed", "left"}.
static func clear_fronts(data: Dictionary) -> Dictionary:
	var stats := {"moved": 0, "removed": 0, "left": 0}
	var levels: Dictionary = data.get("levels", {0: data["grid"]})
	var stairs_by := _stairs_by_level(data)
	var containers: Dictionary = data.get("containers", {}) if data.get("containers", {}) is Dictionary else {}
	var box_ids: Array = containers.keys()
	box_ids.sort()
	var props: Array = data.get("props", [])
	var drop: Dictionary = {}
	var gone_ground: Array = []
	var nudges := _nudges()
	var lvs: Array = levels.keys()
	lvs.sort()
	for lv: int in lvs:
		var g: FieldGrid = levels[lv]
		var stairs: Dictionary = stairs_by.get(lv, {})
		var map := rooms_of(g)
		var of: PackedInt32Array = map["of"]
		var in_room: Dictionary = {}  # 방 -> [가구 번호]
		for i in range(props.size()):
			var p: Dictionary = props[i]
			if int(p.get("level", 0)) != lv:
				continue
			var r: Variant = _rect(p.get("rect"))
			if r == null:
				continue
			var ri := _at(g, of, (r as Rect2i).position + (r as Rect2i).size / 2)
			if ri >= 0:
				if not in_room.has(ri):
					in_room[ri] = []
				in_room[ri].append(i)
		var boxes_in: Dictionary = {}  # 방 -> [상자 id]
		for id: String in box_ids:
			var box: Dictionary = containers[id]
			var bc: Variant = _cell(box.get("cell"))
			if int(box.get("level", 0)) != lv or bc == null:
				continue
			var bi := _at(g, of, bc)
			if bi >= 0:
				if not boxes_in.has(bi):
					boxes_in[bi] = []
				boxes_in[bi].append(id)
		var changed := false
		var room_ids: Array = in_room.keys()
		room_ids.sort()
		for ri: int in room_ids:
			var cells: Array[Vector2i] = map["rooms"][ri]["cells"]
			var forbid := _forbidden(g, of, ri, cells, stairs)
			var idxs: Array = in_room[ri]
			var todo: Array = []
			for i: int in idxs:
				var kind := String(props[i].get("kind", ""))
				var r: Rect2i = _rect(props[i]["rect"])
				if blocks(kind, lv) and (_in_front(r, kind, forbid) or _sticks_out(g, of, ri, r)):
					todo.append(i)
			if todo.is_empty():
				continue
			changed = true
			var room_boxes: Array = boxes_in.get(ri, [])
			for i: int in todo:
				var p: Dictionary = props[i]
				var kind := String(p.get("kind", ""))
				var old: Rect2i = _rect(p["rect"])
				# 다른 소품(바닥에 깔린 것까지)과 바닥 상자가 선 칸. 막는 가구는 앞도 지킨다.
				var taken: Dictionary = {}
				var held: Dictionary = {}  # 다른 막는 가구의 칸
				var others: Array = []
				for j: int in idxs:
					if j == i or drop.has(j):
						continue
					var rj: Rect2i = _rect(props[j]["rect"])
					var stops := blocks(String(props[j].get("kind", "")), lv)
					if stops:
						others.append(rj)
					for y in range(rj.position.y, rj.end.y):
						for x in range(rj.position.x, rj.end.x):
							taken[Vector2i(x, y)] = true
							if stops:
								held[Vector2i(x, y)] = true
				var riding: Array = []  # 옛 칸에 든 상자
				var floor_box: Dictionary = {}  # 바닥 상자 칸 -> id
				for id: String in room_boxes:
					var bc: Vector2i = _cell(containers[id]["cell"])
					if old.has_point(bc):
						riding.append(id)
					else:
						floor_box[bc] = id
				# 담는 가구는 든 상자가 없으면 바닥 상자 하나를 품고 설 수 있다(가구 하나에 상자 하나).
				var can_hold: bool = HOLDER_KINDS.has(kind) and riding.is_empty()
				var box_cells: Array = []
				for id: String in room_boxes:
					if not riding.has(id):
						box_cells.append(_cell(containers[id]["cell"]))
				# 옛 칸을 비우고 본다(지도가 찍어 둔 막힘이면).
				var was_low: Array[Vector2i] = []
				for y in range(old.position.y, old.end.y):
					for x in range(old.position.x, old.end.x):
						var c := Vector2i(x, y)
						if _at(g, of, c) == ri and g.solid_at(c) == S.LOW and not held.has(c):
							was_low.append(c)
							g.set_solid(c, S.NONE)
				var keys := _keys(g, of, ri, cells, stairs, box_cells)
				var before := _from_first(g, of, ri, keys)
				var guard := _standing(g, of, ri, others, before)
				var walls := _wall_sides(g, of, ri, old)
				var best := Rect2i()
				var found := false
				var held_box: Array = []
				# 두 번 돈다: 먼저 벽에 붙은 변이 줄지 않는 자리, 다음엔 아무 자리. 길쭉한 가구는
				# 같은 방향 다음에 90도 돌린 꼴(제자리부터)도 본다.
				var shapes: Array[Vector2i] = [old.size]
				if old.size.x != old.size.y:
					shapes.append(Vector2i(old.size.y, old.size.x))
				var tries: Array = []
				for keep_wall in [true, false]:
					for shape in shapes:
						if shape != old.size:
							tries.append([keep_wall, Rect2i(old.position, shape)])
						for off: Vector2i in nudges:
							tries.append([keep_wall, Rect2i(old.position + off, shape)])
				# 그래도 없으면 방 안 모든 자리를 가까운 차례로(좁은 방의 긴 가구).
				var far: Array = []
				var lo := cells[0]
				var hi := cells[0]
				for c in cells:
					lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
					hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
				for shape in shapes:
					for y in range(lo.y, hi.y - shape.y + 2):
						for x in range(lo.x, hi.x - shape.x + 2):
							var dist := absi(x - old.position.x) + absi(y - old.position.y)
							if dist > NUDGE_MAX:
								far.append([dist, Rect2i(x, y, shape.x, shape.y)])
				far.sort_custom(func(a: Array, b: Array) -> bool:
					if a[0] != b[0]:
						return a[0] < b[0]
					var ra: Rect2i = a[1]
					var rb: Rect2i = b[1]
					if ra.position.y != rb.position.y:
						return ra.position.y < rb.position.y
					if ra.position.x != rb.position.x:
						return ra.position.x < rb.position.x
					return ra.size.x > rb.size.x)
				for f: Array in far:
					tries.append([false, f[1]])
				for t: Array in tries:
					var keep_wall: bool = t[0]
					var r: Rect2i = t[1]
					var fits := true
					var under: Array = []
					for y in range(r.position.y, r.end.y):
						for x in range(r.position.x, r.end.x):
							var c := Vector2i(x, y)
							if _at(g, of, c) != ri or g.solid_at(c) != S.NONE or taken.has(c) or stairs.has(c):
								fits = false
							elif floor_box.has(c):
								under.append(floor_box[c])
					if under.size() > (1 if can_hold else 0):
						fits = false
					if not fits or _in_front(r, kind, forbid):
						continue
					if keep_wall and _wall_sides(g, of, ri, r) < walls:
						continue
					for y in range(r.position.y, r.end.y):
						for x in range(r.position.x, r.end.x):
							g.set_solid(Vector2i(x, y), S.LOW)
					var open := _still_open(g, of, ri, keys, before, [r] + guard)
					for y in range(r.position.y, r.end.y):
						for x in range(r.position.x, r.end.x):
							g.set_solid(Vector2i(x, y), S.NONE)
					if open:
						best = r
						found = true
						held_box = under
						break
				if found:
					var turned := best.size != old.size
					p["rect"] = best
					if turned:
						# 돌린 가구는 긴 변을 댄 벽 쪽으로 등을 둔다.
						for d in DIRS:
							if (d.y != 0) == (best.size.x >= best.size.y) and _wall_side(g, of, ri, best, d):
								p["facing"] = _facing_from_back(d)
								break
					for id: String in riding:
						var nb: Dictionary = containers[id].duplicate(true)
						var rel: Vector2i = _cell(nb["cell"]) - old.position
						if turned:
							rel = Vector2i(rel.y, rel.x)
						nb["cell"] = best.position + Vector2i(clampi(rel.x, 0, best.size.x - 1), clampi(rel.y, 0, best.size.y - 1))
						containers[id] = nb
					for id: String in held_box:
						var hb: Dictionary = containers[id].duplicate(true)
						hb["furniture"] = kind
						containers[id] = hb
					if lv == 0 and not was_low.is_empty():
						gone_ground.append(old)
					stats["moved"] += 1
				elif REPLACED.has(kind) and riding.is_empty():
					drop[i] = true
					if lv == 0 and not was_low.is_empty():
						gone_ground.append(old)
					stats["removed"] += 1
				else:
					for c in was_low:
						g.set_solid(c, S.LOW)
					stats["left"] += 1
		if changed:
			g.refresh_paths()
	if not drop.is_empty():
		var out: Array = []
		for i in range(props.size()):
			if not drop.has(i):
				out.append(props[i])
		data["props"] = out
	if not gone_ground.is_empty() and data.has("low_blocks"):
		var kept: Array = []
		for r: Rect2i in data["low_blocks"]:
			if not gone_ground.has(r):
				kept.append(r)
		data["low_blocks"] = kept
	return stats


## ---------------------------------------------------------------- 방 종류별 가구(3장)

## 방 이름(가구 메모 「X의 Y」의 X)의 낱말 → 다시 놓는 묶음. 앞에서부터 본다.
const NAME_CLASS: Array = [
	["기록", ""], ["병", ""], ["약", ""], ["진료", ""], ["제의", ""],
	["부엌", "kitchen"], ["거실", "living"], ["저장", "store"],
	["창고", "storage"], ["보관", "storage"], ["비축", "storage"], ["입고", "storage"], ["광", "storage"],
	["매장", "shop"], ["가게", "shop"],
	["안방", "bed"], ["침실", "bed"], ["살림", "bed"], ["숙직", "bed"],
	["작업", "work"], ["공구", "work"], ["공방", "work"],
]

## 묶음마다 놓는 가구. size는 (긴 변, 짧은 변). need: 꼭 있을 것. holds: 상자가 드는 용기.
## at: "wall"(긴 변을 벽에) / "mid"(벽에서 떨어져도 됨). 큰 가구(TALL_KINDS)는 창 앞에 못 둔다.
## near: "far_door"(문에서 멀리) / "door"(문 가까이) / "stove"(난로 가까이).
const PALETTE: Dictionary = {
	"bed": [
		{"kind": "bed", "size": Vector2i(2, 1), "need": true, "at": "wall", "near": "far_door"},
		{"kind": "wardrobe", "size": Vector2i(2, 1), "need": true, "holds": true, "at": "wall"},
		{"kind": "blanket_chest", "size": Vector2i(2, 1), "holds": true, "at": "wall"},
		{"kind": "bookcase", "size": Vector2i(2, 1), "holds": true, "at": "wall"},
		{"kind": "bench", "size": Vector2i(3, 1), "at": "wall"},
	],
	"kitchen": [
		{"kind": "cold_stove", "size": Vector2i(1, 1), "need": true, "at": "wall"},
		{"kind": "jar_shelf", "size": Vector2i(3, 1), "need": true, "holds": true, "at": "wall"},
		{"kind": "dining_set", "size": Vector2i(2, 2), "at": "mid"},
		{"kind": "fridge_open", "size": Vector2i(1, 1), "holds": true, "at": "wall"},
		{"kind": "barrel", "size": Vector2i(1, 1), "at": "wall"},
	],
	"living": [
		{"kind": "cold_stove", "size": Vector2i(1, 1), "need": true, "at": "wall"},
		{"kind": "bench", "size": Vector2i(3, 1), "need": true, "at": "wall", "near": "stove"},
		{"kind": "bookcase", "size": Vector2i(2, 1), "holds": true, "at": "wall"},
		{"kind": "dining_set", "size": Vector2i(2, 2), "at": "mid"},
		{"kind": "radio_set", "size": Vector2i(2, 1), "at": "wall"},
	],
	"shop": [
		{"kind": "shop_counter", "size": Vector2i(3, 1), "need": true, "holds": true, "at": "wall", "near": "door"},
		{"kind": "display_shelf", "size": Vector2i(4, 1), "need": true, "holds": true, "at": "wall"},
		{"kind": "display_shelf", "size": Vector2i(4, 1), "holds": true, "at": "wall"},
		{"kind": "crate_stack", "size": Vector2i(2, 2), "holds": true, "at": "wall"},
		{"kind": "barrel", "size": Vector2i(1, 1), "at": "wall"},
	],
	"storage": [
		{"kind": "shelf", "size": Vector2i(3, 1), "need": true, "holds": true, "at": "wall"},
		{"kind": "shelf", "size": Vector2i(3, 1), "holds": true, "at": "wall"},
		{"kind": "crate_stack", "size": Vector2i(2, 2), "holds": true, "at": "wall"},
		{"kind": "barrel", "size": Vector2i(1, 1), "at": "wall"},
		{"kind": "sack_pile", "size": Vector2i(2, 2), "at": "wall"},
	],
	# 보일러실(지하): 화실과 석탄함이 꼭 있고, 연료통·공구함·선반은 덤.
	"boiler": [
		{"kind": "firebox", "size": Vector2i(1, 1), "need": true, "at": "wall"},
		{"kind": "coal_bin", "size": Vector2i(3, 2), "need": true, "at": "wall"},
		{"kind": "fuel_drum", "size": Vector2i(1, 1), "at": "wall"},
		{"kind": "toolbox", "size": Vector2i(1, 1), "holds": true, "at": "wall"},
		{"kind": "shelf", "size": Vector2i(3, 1), "holds": true, "at": "wall"},
	],
	"store": [
		{"kind": "jar_shelf", "size": Vector2i(3, 1), "need": true, "holds": true, "at": "wall"},
		{"kind": "shelf", "size": Vector2i(3, 1), "holds": true, "at": "wall"},
		{"kind": "tin_crate", "size": Vector2i(2, 1), "holds": true, "at": "wall"},
		{"kind": "barrel", "size": Vector2i(1, 1), "at": "wall"},
		{"kind": "barrel", "size": Vector2i(1, 1), "at": "wall"},
	],
}

## 다시 놓는 묶음에서 지우는 지도 가구(그 밖의 종류는 남는다: 기계, 이야기 소품).
const REPLACED: Dictionary = {
	"bed": true, "wardrobe": true, "cold_stove": true, "fridge_open": true, "dining_set": true,
	"desk": true, "shelf": true, "jar_shelf": true, "barrel": true, "tin_crate": true,
	"blanket_chest": true, "crate_stack": true, "sack_pile": true, "bookcase": true, "bench": true,
	"radio_set": true, "shop_counter": true, "display_shelf": true,
}
## 꼭 있을 것이 아닌 가구가 놓일 확률(방마다 씨앗으로 굴린다). 같은 지도의 같은 쓰임
## 방이 다 같은 가구 묶음이 되지 않게. 상자가 남은 방의 용기 가구는 굴리지 않고 놓는다.
const OPTIONAL_CHANCE: float = 0.6
## 지우지 않고 남겨도 덮는 비율에는 센다.
const COVER_MAX: float = 0.45
const FLOOR_MIN: float = 0.5
const FLOOR_MIN_SMALL: float = 0.4
## 가구 하나마다 해 보는 자리 수(점수 위에서부터). 꼭 있을 것은 더 많이.
const TOP_CANDIDATES: int = 6
const TOP_CANDIDATES_NEED: int = 24


## 방 이름 → 묶음. 이름이 없으면 가구 묶음으로 가른다.
## 방 이름만으로 고른 묶음과, 이름에서 찾았는지.
static func _name_class(name: String) -> Array:
	for row: Array in NAME_CLASS:
		if _named(name, row[0]):
			return [row[1], true]
	return ["", false]


static func room_class(name: String, kinds: Dictionary, lv: int) -> String:
	var found := _name_class(name)
	var cls: String = found[0]
	var named: bool = found[1]
	if not named:
		if kinds.has("iv_stand") or kinds.has("record_shelf_row") or kinds.has("loom"):
			return ""
		if kinds.has("bed"):
			cls = "bed"
		elif kinds.has("dining_set") or kinds.has("fridge_open"):
			cls = "kitchen"
		elif kinds.has("jar_shelf") and lv < 0:
			cls = "store"
	# 가게 위층은 살림집이다(가게 이름을 물려받은 위층 방에 침대가 있다).
	if lv >= 1 and (cls == "shop" or cls == "storage" or cls == "work") and kinds.has("bed"):
		return "bed"
	if cls == "work":
		return ""
	# 지하의 부엌은 보일러실, 침실·거실은 저장 칸으로(결정 423, 지하실 카드 「가」. 방 수는 그대로).
	if lv < 0 and cls == "kitchen":
		return "boiler"
	if lv < 0 and (cls == "bed" or cls == "living"):
		return "store"
	# 지하의 매장은 저장 칸으로, 땅 위 저장 칸은 창고로.
	if lv < 0 and (cls == "shop" or cls == "storage"):
		return "store"
	if lv >= 0 and cls == "store":
		return "storage"
	return cls


## 낱말이 방 이름에 있나. 「광」은 따로 선 낱말일 때만(광산·광장 아님).
static func _named(name: String, word: String) -> bool:
	if word == "광":
		return Array(name.split(" ")).has("광")
	return name.find(word) >= 0


## 비울 칸: "all"은 아무것도, "tall"은 큰 가구만 못 놓는다.
static func _forbidden(g: FieldGrid, of: PackedInt32Array, ri: int, cells: Array[Vector2i], stairs: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for c in cells:
		if stairs.has(c):
			out[c] = "all"
			for d in DIRS:
				out[c + d] = "all"
			continue
		for d in DIRS:
			var n := c + d
			if _at(g, of, n) == ri:
				continue
			if g.doors.has(n) or g.people_can_walk(n):
				# 문(뚫린 곳) 안쪽 2칸 x 문과 양옆 1칸.
				var inward := -d
				var side := Vector2i(inward.y, inward.x)
				for k in [0, 1]:
					for s in [-1, 0, 1]:
						out[c + inward * k + side * s] = "all"
			elif g.windows.has(n) and not out.has(c):
				out[c] = "tall"
	return out


## 그 변 바로 밖이 벽(또는 건물 밖 막힘)인가. 문·뚫린 곳·창이면 아니다.
static func _wall_side(g: FieldGrid, of: PackedInt32Array, ri: int, r: Rect2i, d: Vector2i) -> bool:
	var n := r.size.y if d.x != 0 else r.size.x
	for i in range(n):
		var c: Vector2i
		if d.x != 0:
			c = Vector2i(r.end.x if d.x > 0 else r.position.x - 1, r.position.y + i)
		else:
			c = Vector2i(r.position.x + i, r.end.y if d.y > 0 else r.position.y - 1)
		if _at(g, of, c) == ri or g.doors.has(c) or g.windows.has(c) or g.people_can_walk(c):
			return false
	return true


## 등을 댄 벽 → 앞이 방을 보는 facing(prop_fit.front: 0 +Z, 1 -X, 2 -Z, 3 +X).
static func _facing_from_back(back: Vector2i) -> int:
	if back == Vector2i(0, -1):
		return 0
	if back == Vector2i(0, 1):
		return 2
	if back == Vector2i(-1, 0):
		return 3
	return 1


## 가구 칸 가운데 4이웃이 걸어서 닿는 칸(seen)인 것, 옛 칸에 가까운 것. 없으면 (-1, -1).
static func _front_cell(r: Rect2i, seen: Dictionary, old: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			var open := false
			for d in DIRS:
				open = open or seen.has(c + d)
			var dd := absi(c.x - old.x) + absi(c.y - old.y)
			if open and dd < best_d:
				best_d = dd
				best = c
	return best


static func _nearest_seen(seen: Dictionary, old: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for c: Vector2i in seen:
		var dd := absi(c.x - old.x) + absi(c.y - old.y)
		if dd < best_d or (dd == best_d and (c.y < best.y or (c.y == best.y and c.x < best.x))):
			best_d = dd
			best = c
	return best


static func _dist_to(r: Rect2i, cells: Array) -> int:
	var best := 999
	for c: Vector2i in cells:
		var dx := maxi(0, maxi(r.position.x - c.x, c.x - (r.end.x - 1)))
		var dy := maxi(0, maxi(r.position.y - c.y, c.y - (r.end.y - 1)))
		best = mini(best, dx + dy)
	return best


## 한 가구의 놓을 자리 후보. [{"rect", "facing", "score"}], 점수 높은 것부터.
static func _candidates(g: FieldGrid, of: PackedInt32Array, ri: int, cells: Array[Vector2i], item: Dictionary,
		forbid: Dictionary, taken: Dictionary, doors_in: Array, stove_cells: Array, box_at: Dictionary, k: int = TOP_CANDIDATES) -> Array:
	var size: Vector2i = item["size"]
	var tall: bool = TALL_KINDS.has(String(item["kind"]))
	var holds: bool = item.get("holds", false)
	var shapes: Array[Vector2i] = [size]
	if size.x != size.y:
		shapes.append(Vector2i(size.y, size.x))
	var lo := cells[0]
	var hi := cells[0]
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var out: Array = []
	for shape in shapes:
		for y in range(lo.y, hi.y - shape.y + 2):
			for x in range(lo.x, hi.x - shape.x + 2):
				var r := Rect2i(x, y, shape.x, shape.y)
				var fits := true
				for yy in range(r.position.y, r.end.y):
					for xx in range(r.position.x, r.end.x):
						var c := Vector2i(xx, yy)
						var f: String = forbid.get(c, "")
						if _at(g, of, c) != ri or g.solid_at(c) != S.NONE or taken.has(c) or f == "all" or (tall and f == "tall"):
							fits = false
						elif box_at.has(c) and not holds:
							fits = false
				if not fits:
					continue
				# 네 변이 벽인지 한 번씩. 긴 변(정사각이면 아무 변)이 벽이면 등을 댈 수 있다.
				var backs: Array[Vector2i] = []
				var walls := 0
				for d in DIRS:
					if not _wall_side(g, of, ri, r, d):
						continue
					walls += 1
					var long_side := (d.y != 0) == (r.size.x >= r.size.y)
					if long_side or r.size.x == r.size.y:
						backs.append(d)
				if item.get("at", "wall") == "wall" and backs.is_empty():
					continue
				var score := 0.0
				var facing := 0
				if not backs.is_empty():
					score += 3.0
					facing = _facing_from_back(backs[0])
				if walls >= 2:
					score += 1.0
				if item.get("at", "wall") == "mid" and walls == 0:
					score += 2.0
				match item.get("near", ""):
					"far_door":
						score += 0.3 * _dist_to(r, doors_in)
					"door":
						score -= 0.5 * _dist_to(r, doors_in)
					"stove":
						if not stove_cells.is_empty():
							score -= 0.5 * _dist_to(r, stove_cells)
				_keep_top(out, {"rect": r, "facing": facing, "score": score}, k)
	return out


## 점수 높은 것, 같으면 위·왼쪽·넓은 것이 앞. 위 몇 개만 남긴다.
static func _ahead(a: Dictionary, b: Dictionary) -> bool:
	if a["score"] != b["score"]:
		return a["score"] > b["score"]
	var ra: Rect2i = a["rect"]
	var rb: Rect2i = b["rect"]
	if ra.position.y != rb.position.y:
		return ra.position.y < rb.position.y
	if ra.position.x != rb.position.x:
		return ra.position.x < rb.position.x
	return ra.size.x > rb.size.x


static func _keep_top(top: Array, cand: Dictionary, k: int) -> void:
	var at := top.size()
	while at > 0 and _ahead(cand, top[at - 1]):
		at -= 1
	if at >= k:
		return
	top.insert(at, cand)
	if top.size() > k:
		top.pop_back()


## 꼭 있을 가구가 빠진 방을 까닭별로 센다: space(덮는 몫·바닥 몫), spot(놓을 자리 없음), path(길이 끊김).
static func _missing(stats: Dictionary, cls: String, item: Dictionary, why: String) -> void:
	stats["need_missing"] += 1
	var key := "%s/%s/%s" % [cls, item["kind"], why]
	stats["missing"][key] = int(stats["missing"].get(key, 0)) + 1


## 방 안 가구를 묶음 규칙대로 다시 놓고, 상자를 그 방 용기 가구 칸으로 옮긴다.
## 돌려주는 값: {"rooms", "placed", "need_missing", "boxes_in", "boxes_near"}.
static func furnish_rooms(data: Dictionary) -> Dictionary:
	var stats := {"rooms": 0, "placed": 0, "need_missing": 0, "boxes_in": 0, "boxes_near": 0, "missing": {}}
	if not data.has("low_blocks"):
		data["low_blocks"] = []
	var place := String(data.get("place_id", ""))
	var levels: Dictionary = data.get("levels", {0: data["grid"]})
	var stairs_by := _stairs_by_level(data)
	var containers: Dictionary = data.get("containers", {}) if data.get("containers", {}) is Dictionary else {}
	var box_ids: Array = containers.keys()
	box_ids.sort()
	var props: Array = data.get("props", [])
	var drop: Dictionary = {}
	var dropped_ground: Array = []
	var new_ground: Array = []
	var added: Array = []
	var lvs: Array = levels.keys()
	lvs.sort()
	for lv: int in lvs:
		var g: FieldGrid = levels[lv]
		var stairs: Dictionary = stairs_by.get(lv, {})
		var map := rooms_of(g)
		var of: PackedInt32Array = map["of"]
		var in_room: Dictionary = {}
		for i in range(props.size()):
			var p: Dictionary = props[i]
			if int(p.get("level", 0)) != lv:
				continue
			var r: Variant = _rect(p.get("rect"))
			if r == null:
				continue
			var rect: Rect2i = r
			var ri: int = _at(g, of, rect.position + rect.size / 2)
			if ri >= 0:
				if not in_room.has(ri):
					in_room[ri] = []
				in_room[ri].append(i)
		var box_room: Dictionary = {}  # 방 번호 -> [상자 id]
		for id: String in box_ids:
			var box: Dictionary = containers[id]
			if int(box.get("level", 0)) != lv:
				continue
			var bc: Variant = _cell(box.get("cell"))
			if bc != null:
				var bi := _at(g, of, bc)
				if bi >= 0:
					if not box_room.has(bi):
						box_room[bi] = []
					box_room[bi].append(id)
		var changed := false
		for ri in range(map["rooms"].size()):
			if not in_room.has(ri):
				continue
			var room: Dictionary = map["rooms"][ri]
			var cells: Array[Vector2i] = room["cells"]
			var idxs: Array = in_room[ri]
			var kinds: Dictionary = {}
			var names: Dictionary = {}
			for i: int in idxs:
				var p: Dictionary = props[i]
				kinds[String(p.get("kind", ""))] = true
				var note := String(p.get("note", ""))
				var cut := note.find("의 ")
				if cut > 0:
					var who := note.substr(0, cut)
					names[who] = int(names.get(who, 0)) + 1
			var name := ""
			var best := 0
			var name_keys: Array = names.keys()
			name_keys.sort()
			for k: String in name_keys:
				if names[k] > best:
					best = names[k]
					name = k
			var cls := room_class(name, kinds, lv)
			if cls.is_empty():
				continue
			changed = true
			# 지우기: 다시 놓을 종류만. 남는 것(기계 등)은 칸을 차지한 채 둔다.
			var taken: Dictionary = {}
			for i: int in idxs:
				var p: Dictionary = props[i]
				var rect: Rect2i = _rect(p.get("rect"))
				if REPLACED.has(String(p.get("kind", ""))):
					drop[i] = true
					if lv == 0:
						dropped_ground.append(rect)
					for y in range(rect.position.y, rect.end.y):
						for x in range(rect.position.x, rect.end.x):
							var c := Vector2i(x, y)
							if _at(g, of, c) == ri and g.solid_at(c) == S.LOW:
								g.set_solid(c, S.NONE)
			var kept_rects: Array = []
			for i: int in idxs:
				if drop.has(i):
					continue
				var rect: Rect2i = _rect(props[i].get("rect"))
				kept_rects.append(rect)
				for y in range(rect.position.y, rect.end.y):
					for x in range(rect.position.x, rect.end.x):
						taken[Vector2i(x, y)] = true
			var room_boxes: Array = box_room.get(ri, [])
			var box_cells: Array = []
			var box_at: Dictionary = {}
			for id: String in room_boxes:
				var bc: Vector2i = _cell(containers[id]["cell"])
				box_cells.append(bc)
				box_at[bc] = true
			var keys := _keys(g, of, ri, cells, stairs, box_cells)
			var before := _from_first(g, of, ri, keys)
			var guard := _standing(g, of, ri, kept_rects, before)
			var forbid := _forbidden(g, of, ri, cells, stairs)
			var rng := RandomNumberGenerator.new()
			rng.seed = ("%s|%d|%d|%d" % [place, int(room["building"]), lv, ri]).hash()
			var area := cells.size()
			var used := 0
			for c: Vector2i in taken:
				if _at(g, of, c) == ri:
					used += 1
			var cap := int(floor(area * COVER_MAX))
			var floor_min: float = FLOOR_MIN_SMALL if area <= 9 else FLOOR_MIN
			var placed: Array = []
			var rects: Array = []
			var stove_cells: Array = []
			var holders := 0
			# 지도의 담는 가구(궤, 약품 상자 등)가 남은 방은 담는 가구를 이미 가졌다. 창고·저장 칸은
			# 쌓아 둔 짐(석탄 더미, 연료통, 자루)이 곧 담는 것이다.
			var kept_holder := false
			var piles: bool = cls == "storage" or cls == "store"
			for i: int in idxs:
				var kk := String(props[i].get("kind", ""))
				if not drop.has(i) and (HOLDER_KINDS.has(kk) or (piles and not PASS_KINDS.has(kk))):
					kept_holder = true
			for item: Dictionary in PALETTE[cls]:
				var need: bool = item.get("need", false)
				if need and item.get("holds", false) and kept_holder:
					need = false
				elif not need:
					var for_box: bool = item.get("holds", false) and holders < room_boxes.size()
					if not for_box and rng.randf() >= OPTIONAL_CHANCE:
						continue
				# 꼭 있을 것은 자리가 없으면 한 칸씩 짧은 꼴로, 그래도 없으면 벽에서 떨어져서 찾는다.
				var variants: Array = [item]
				if need:
					var size0: Vector2i = item["size"]
					var shortest := 2 if item["kind"] == "bed" else 1
					for n in range(maxi(size0.x, size0.y) - 1, shortest - 1, -1):
						var v: Dictionary = item.duplicate()
						v["size"] = Vector2i(n, mini(size0.x, size0.y))
						variants.append(v)
					if item.get("at", "wall") == "wall":
						var m: Dictionary = item.duplicate()
						m["at"] = "mid"
						variants.append(m)
				var ok := false
				var why := ""
				for v: Dictionary in variants:
					var size: Vector2i = v["size"]
					var a := size.x * size.y
					if (not need and used + a > cap) or float(area - used - a) < area * floor_min:
						why = "space"
						continue
					var cands := _candidates(g, of, ri, cells, v, forbid, taken, keys["seeds"], stove_cells, box_at,
						TOP_CANDIDATES_NEED if need else TOP_CANDIDATES)
					if cands.is_empty():
						why = "spot"
						continue
					var tries: Array = []
					var top := mini(3, cands.size())
					var pick := rng.randi_range(0, top - 1)
					tries.append(cands[pick])
					for k in range(cands.size()):
						if k != pick:
							tries.append(cands[k])
					for cand: Dictionary in tries:
						var r: Rect2i = cand["rect"]
						for y in range(r.position.y, r.end.y):
							for x in range(r.position.x, r.end.x):
								g.set_solid(Vector2i(x, y), S.LOW)
						rects.append(r)
						if _still_open(g, of, ri, keys, before, rects + guard):
							ok = true
							placed.append({"item": v, "rect": r, "facing": cand["facing"]})
							for y in range(r.position.y, r.end.y):
								for x in range(r.position.x, r.end.x):
									taken[Vector2i(x, y)] = true
							used += a
							if v.get("holds", false):
								holders += 1
							if v["kind"] == "cold_stove":
								stove_cells.append(r.position)
							break
						rects.pop_back()
						for y in range(r.position.y, r.end.y):
							for x in range(r.position.x, r.end.x):
								g.set_solid(Vector2i(x, y), S.NONE)
					if ok:
						break
					why = "path"
				if not ok and need:
					_missing(stats, cls, item, why)
			# 상자: 가까운 용기 가구로, 가구 하나에 하나. 그 가구 칸 가운데 바로 앞이
			# 걸어서 닿는 칸에 둔다. 들 가구가 없고 원래 칸이 가구에 덮였으면 닿는 바닥으로.
			var seen := _from_first(g, of, ri, keys)
			var free_holders: Array = []
			for pl: Dictionary in placed:
				if pl["item"].get("holds", false):
					free_holders.append(pl)
			for id: String in room_boxes:
				var box: Dictionary = containers[id].duplicate(true)
				var bc: Vector2i = _cell(box["cell"])
				var order: Array = range(free_holders.size())
				order.sort_custom(func(a: int, b: int) -> bool:
					return _dist_to(free_holders[a]["rect"], [bc]) < _dist_to(free_holders[b]["rect"], [bc]))
				var done := false
				for k: int in order:
					var spot := _front_cell(free_holders[k]["rect"], seen, bc)
					if spot.x < 0:
						continue
					box["cell"] = spot
					box["furniture"] = free_holders[k]["item"]["kind"]
					free_holders.remove_at(k)
					stats["boxes_in"] += 1
					done = true
					break
				if not done and g.solid_at(bc) != S.NONE:
					var near := _nearest_seen(seen, bc)
					if near.x >= 0:
						box["cell"] = near
					stats["boxes_near"] += 1
				containers[id] = box
			var label: String = name if not name.is_empty() and _name_class(name)[0] == cls else ROOM_LABEL[cls]
			for pl: Dictionary in placed:
				var r: Rect2i = pl["rect"]
				var kind: String = pl["item"]["kind"]
				added.append({"kind": kind, "rect": r, "solid": "low", "facing": pl["facing"],
					"note": "%s의 %s" % [label, KIND_LABEL.get(kind, kind)], "level": lv,
					"building": int(room["building"]), "rule": cls})
				if lv == 0:
					new_ground.append(r)
			stats["rooms"] += 1
			stats["placed"] += placed.size()
		if changed:
			g.refresh_paths()
	var out: Array = []
	for i in range(props.size()):
		if not drop.has(i):
			out.append(props[i])
	out.append_array(added)
	data["props"] = out
	if not dropped_ground.is_empty():
		var kept_blocks: Array = []
		for r: Rect2i in data["low_blocks"]:
			if not dropped_ground.has(r):
				kept_blocks.append(r)
		data["low_blocks"] = kept_blocks
	data["low_blocks"].append_array(new_ground)
	return stats


const ROOM_LABEL: Dictionary = {"bed": "살림방", "kitchen": "부엌", "living": "거실", "shop": "매장", "storage": "창고", "store": "저장 칸", "boiler": "보일러실"}
const KIND_LABEL: Dictionary = {
	"bed": "침대", "wardrobe": "장롱", "blanket_chest": "담요 궤", "bookcase": "책장", "bench": "긴 의자",
	"cold_stove": "꺼진 난로", "jar_shelf": "항아리 선반", "dining_set": "식탁과 의자", "fridge_open": "문 열린 냉장고",
	"barrel": "통", "radio_set": "라디오", "shop_counter": "계산대", "display_shelf": "진열 선반",
	"crate_stack": "상자 더미", "shelf": "선반", "sack_pile": "자루 더미", "tin_crate": "나무 궤",
	"firebox": "보일러 화실", "coal_bin": "석탄함", "fuel_drum": "연료통", "toolbox": "공구함",
}


## ---------------------------------------------------------------- 가구 속 상자(1장 「가구가 곧 용기」)

## 상자가 들어갈 수 있는 가구(장, 선반, 궤, 책상, 계산대, 상자 더미 등).
const HOLDER_KINDS: Dictionary = {
	"wardrobe": true, "blanket_chest": true, "bookcase": true, "shelf": true, "jar_shelf": true,
	"display_shelf": true, "shop_counter": true, "crate_stack": true, "tin_crate": true, "fridge_open": true,
	"desk": true, "typewriter_desk": true, "office_desk": true, "file_cabinet": true, "map_cabinet": true,
	"record_shelf_row": true, "tool_chest": true, "toolbox": true, "workbench": true, "tool_bench": true,
	"medicine_crate": true, "glass_cabinet": true, "vestry_chest": true, "parish_chest": true,
	"hymn_shelf": true, "conductor_log_chest": true, "ration_ledger_chest": true, "freezer_chest": true,
	"part_crate": true, "ammo_crate": true, "relief_crate": true, "blanket_crate": true, "lamp_shelf": true,
	"hardware_rack": true, "parts_rack": true, "bread_rack": true, "cloth_bolt_rack": true,
	"evidence_shelf": true, "strongbox": true, "office_cabinet": true, "service_counter": true,
	"checkout": true, "mail_sorting_rack": true, "cask_stack": true, "drawer_chest_spilled": true,
}


## 다시 놓지 않은 방의 상자도 그 방 용기 가구 칸으로 옮긴다(가구 하나에 하나, 바로 앞이
## 걸어서 닿는 칸). 들 가구가 없으면 그대로. 돌려주는 값: 옮긴 상자 수.
static func boxes_into_furniture(data: Dictionary) -> int:
	var moved := 0
	var containers: Variant = data.get("containers", {})
	if not containers is Dictionary or containers.is_empty():
		return 0
	var levels: Dictionary = data.get("levels", {0: data["grid"]})
	var stairs_by := _stairs_by_level(data)
	var ids: Array = containers.keys()
	ids.sort()
	var lvs: Array = levels.keys()
	lvs.sort()
	for lv: int in lvs:
		var g: FieldGrid = levels[lv]
		var map := rooms_of(g)
		var of: PackedInt32Array = map["of"]
		var holders_of: Dictionary = {}  # 방 -> [rect, kind]
		var used: Dictionary = {}
		for p: Dictionary in data.get("props", []):
			if int(p.get("level", 0)) != lv or not HOLDER_KINDS.has(String(p.get("kind", ""))):
				continue
			var r: Variant = _rect(p.get("rect"))
			if r == null:
				continue
			var ri := _at(g, of, (r as Rect2i).position + (r as Rect2i).size / 2)
			if ri < 0:
				continue
			if not holders_of.has(ri):
				holders_of[ri] = []
			holders_of[ri].append([r, String(p["kind"])])
		# 이미 상자를 품은 가구(furnish_rooms가 넣은 것)는 건너뛴다.
		for id: String in ids:
			var box: Dictionary = containers[id]
			var hc: Variant = _cell(box.get("cell"))
			if int(box.get("level", 0)) != lv or not box.has("furniture") or hc == null:
				continue
			var hi := _at(g, of, hc)
			for k in range(holders_of.get(hi, []).size()):
				if (holders_of[hi][k][0] as Rect2i).has_point(hc):
					used[Vector3i(lv, hi, k)] = true
		for id: String in ids:
			var box: Dictionary = containers[id]
			if int(box.get("level", 0)) != lv or box.has("furniture"):
				continue
			var bc: Variant = _cell(box.get("cell"))
			if bc == null:
				continue
			var ri := _at(g, of, bc)
			if ri < 0 or not holders_of.has(ri):
				continue
			var room: Dictionary = map["rooms"][ri]
			var keys := _keys(g, of, ri, room["cells"], stairs_by.get(lv, {}), [])
			var seen := _from_first(g, of, ri, keys)
			var list: Array = holders_of[ri]
			var order: Array = range(list.size())
			order.sort_custom(func(a: int, b: int) -> bool:
				var da := _dist_to(list[a][0], [bc])
				var db := _dist_to(list[b][0], [bc])
				return da < db if da != db else a < b)
			for k: int in order:
				var key := Vector3i(lv, ri, k)
				if used.has(key):
					continue
				var spot := _front_cell(list[k][0], seen, bc)
				if spot.x < 0:
					continue
				var nb: Dictionary = box.duplicate(true)
				nb["cell"] = spot
				nb["furniture"] = list[k][1]
				containers[id] = nb
				used[key] = true
				moved += 1
				break
	return moved
