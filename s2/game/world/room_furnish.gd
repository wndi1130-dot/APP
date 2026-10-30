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
const BuildingRules = preload("res://game/sim/building_rules.gd")
const CoreScenes = preload("res://game/world/core_scenes.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
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
## 칸 배열을 바로 읽는다(지도 하나에 층마다 수만 칸). 칸 차례는 깊이 우선, 이웃은 DIRS 차례.
static func rooms_of(g: FieldGrid) -> Dictionary:
	var w := g.width
	var n := w * g.height
	var of := PackedInt32Array()
	of.resize(n)
	of.fill(-1)
	var solid := g.solid
	var bld := g.building
	var rooms: Array = []
	var stack := PackedInt32Array()
	for i in range(n):
		if of[i] >= 0:
			continue
		var b := bld[i]
		var s0 := solid[i]
		if b < 0 or not (s0 == S.NONE or s0 == S.LOW or s0 == S.BLOCK):
			continue
		var idx := rooms.size()
		var cells: Array[Vector2i] = []
		of[i] = idx
		stack.resize(0)
		stack.append(i)
		while not stack.is_empty():
			var cur := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			var x := cur % w
			cells.append(Vector2i(x, cur / w))
			# DIRS 차례: +x, -x, +y, -y.
			for k in range(4):
				var nb := -1
				if k == 0:
					nb = cur + 1 if x + 1 < w else -1
				elif k == 1:
					nb = cur - 1 if x > 0 else -1
				elif k == 2:
					nb = cur + w if cur + w < n else -1
				else:
					nb = cur - w if cur >= w else -1
				if nb < 0 or of[nb] >= 0 or bld[nb] != b:
					continue
				var s := solid[nb]
				if s == S.NONE or s == S.LOW or s == S.BLOCK:
					of[nb] = idx
					stack.append(nb)
		rooms.append({"cells": cells, "building": b})
	return {"of": of, "rooms": rooms}


## 지도를 짓는 동안 길 찾기 자료(refresh_paths)는 맨 끝에 한 번: field_maps가 "_defer_paths"를
## 켜고 다 지은 뒤 층마다 다시 만든다. 따로 부르면(시험) 단계마다 다시 만든다.
## 지도를 짓는 동안 층마다 한 번만 나눈다(가구 칠하기·옮기기는 방을 나누지 않는다).
## 칸을 바꾸는 단계(덧문)는 이것보다 먼저 돈다. field_maps가 다 지은 뒤 지운다.
static func _rooms(data: Dictionary, lv: int, g: FieldGrid) -> Dictionary:
	var cache: Dictionary = data.get("_rooms", {})
	if cache.has(lv) and cache[lv]["grid"] == g:
		return cache[lv]["map"]
	var map := rooms_of(g)
	cache[lv] = {"grid": g, "map": map}
	data["_rooms"] = cache
	return map


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


## 길 찾기 표시(칸마다 한 바이트). 다 찾으면 쓴 칸만 되돌린다.
static var _mark := PackedByteArray()


## 방 ri 안에서 seeds부터 걸어서 닿는 빈칸. 칸 배열을 바로 읽는다(지도 짓기에 수만 번 돈다).
## 넓이 우선, 이웃은 DIRS 차례.
static func _reach(g: FieldGrid, of: PackedInt32Array, ri: int, seeds: Array[Vector2i]) -> Dictionary:
	var w := g.width
	var h := g.height
	var n := w * h
	if _mark.size() != n:
		_mark.resize(n)
		_mark.fill(0)
	var solid := g.solid
	var queue := PackedInt32Array()
	for s in seeds:
		if s.x < 0 or s.y < 0 or s.x >= w or s.y >= h:
			continue
		var i := s.y * w + s.x
		if _mark[i] == 0 and solid[i] == S.NONE:
			_mark[i] = 1
			queue.append(i)
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		var x := cur % w
		for k in range(4):
			var nb := -1
			if k == 0:
				nb = cur + 1 if x + 1 < w else -1
			elif k == 1:
				nb = cur - 1 if x > 0 else -1
			elif k == 2:
				nb = cur + w if cur + w < n else -1
			else:
				nb = cur - w if cur >= w else -1
			if nb >= 0 and _mark[nb] == 0 and of[nb] == ri and solid[nb] == S.NONE:
				_mark[nb] = 1
				queue.append(nb)
	var seen: Dictionary = {}
	for i in queue:
		seen[Vector2i(i % w, i / w)] = true
		_mark[i] = 0
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
		var map := _rooms(data, lv, g)
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
		if not data.get("_defer_paths", false):
			g.refresh_paths()
	return stats


## ---------------------------------------------------------------- 문·창 앞 비움(3장 「비울 칸」)

## 창 바로 안쪽에 못 서는 큰 가구(장, 선반, 찬장, 냉장고, 책장, 진열대).
const TALL_KINDS: Dictionary = {
	"wardrobe": true, "shelf": true, "bookcase": true, "display_shelf": true, "jar_shelf": true,
	"file_cabinet": true, "fridge_open": true, "record_shelf_row": true, "map_cabinet": true,
	"hardware_rack": true, "bread_rack": true, "parts_rack": true, "cellar_shelf": true,
	"shop_shelf": true, "tool_rack": true, "medicine_cabinet": true, "cupboard": true, "towel_shelf": true,
}
## 옮겨 볼 거리(칸, 맨해튼). 가까운 것부터.
const NUDGE_MAX: int = 3


## 비울 칸에 걸친 가구인가: 문·계단 앞("all")은 다, 창 앞("tall")은 큰 가구만.
static func _in_front(r: Rect2i, kind: String, forbid: Dictionary) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var f: String = forbid.get(Vector2i(x, y), "")
			if f == "all" or (f == "tall" and (r.get_area() >= 2 or TALL_KINDS.has(kind))):
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


## 방 안 모든 자리(옛 자리에서 NUDGE_MAX보다 먼 것)를 가까운 차례로: 거리, 위, 왼쪽, 넓은 꼴.
## 숫자 열쇠로 엔진 안에서 정렬한다. [[false, Rect2i], ...]
static func _far_spots(cells: Array[Vector2i], shapes: Array[Vector2i], old: Rect2i) -> Array:
	var lo := cells[0]
	var hi := cells[0]
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var widest := 0
	for shape in shapes:
		widest = maxi(widest, shape.x)
	var keys := PackedInt64Array()
	for si in range(shapes.size()):
		var shape: Vector2i = shapes[si]
		var rank := 0 if shape.x == widest else 1
		for y in range(lo.y, hi.y - shape.y + 2):
			for x in range(lo.x, hi.x - shape.x + 2):
				var dist := absi(x - old.position.x) + absi(y - old.position.y)
				if dist > NUDGE_MAX:
					keys.append((((dist * 4096 + y) * 4096 + x) * 2 + rank) * 2 + si)
	keys.sort()
	var out: Array = []
	for key in keys:
		var si := key % 2
		var rest := key / 4
		var x := rest % 4096
		var y := (rest / 4096) % 4096
		out.append([false, Rect2i(x, y, shapes[si].x, shapes[si].y)])
	return out


## 문·계단 앞, 창 앞(큰 가구)에 서거나 벽에 박힌 가구를 옮긴다. 막는 가구(blocks)만 본다: 바닥에
## 깔리거나 벽에 걸리거나 안 보이는 것은 문 앞에 있어도 걸리지 않는다. 새 자리는 같은
## 방, 빈 칸(또는 제 옛 칸), 다른 가구·바닥 상자·비울 칸이 아니고, 막아도 방의
## 출입구·계단·상자로 가는 길이 남는 곳이다. 벽에 붙은 변이 줄지 않는 자리를 먼저 본다.
## 옛 칸에 든 상자는 같이 옮긴다. 자리가 없으면 다시 놓는 종류(REPLACED)는 지우고,
## 기계·이야기 소품은 둔다. 돌려주는 값: {"moved", "removed", "left"}.
static func clear_fronts(data: Dictionary) -> Dictionary:
	var stats := {"moved": 0, "removed": 0, "left": 0, "shortened": 0}
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
		var map := _rooms(data, lv, g)
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
				# 가까운 자리에 없으면 방 안 모든 자리를 가까운 차례로(좁은 방의 긴 가구). 그때만 만든다.
				for phase in range(3):
					if found:
						break
					if phase == 1:
						tries = _far_spots(cells, shapes, old)
					if phase == 2:
						# 큰 수납 가구가 어느 방향으로도 안 들어가면 필수 가구와 같은
						# 짧은 꼴을 시험한다. 기계·이야기 소품의 크기는 바꾸지 않는다.
						tries = []
						if HOLDER_KINDS.has(kind) or REPLACED.has(kind):
							var shortest := 2 if kind == "bed" else 1
							for n in range(maxi(old.size.x, old.size.y) - 1, shortest - 1, -1):
								var slim := Vector2i(n, mini(old.size.x, old.size.y))
								for c in cells:
									tries.append([false, Rect2i(c, slim)])
									if slim.x != slim.y:
										tries.append([false, Rect2i(c, Vector2i(slim.y, slim.x))])
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
					var turned := old.size.x != old.size.y and best.size == Vector2i(old.size.y, old.size.x)
					if best.get_area() < old.get_area():
						stats["shortened"] += 1
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
		if changed and not data.get("_defer_paths", false):
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
	["차고", "garage"], ["장작", "woodshed"], ["외양간", "barn"], ["마구간", "barn"], ["건초", "barn"], ["헛간", "barn"],
	["부엌", "kitchen"], ["거실", "living"], ["저장", "store"],
	["욕실", "bath"], ["세면실", "bath"],
	["안방", "bed"], ["침실", "bed"], ["살림", "bed"], ["숙직", "bed"],
	["사무", "office"], ["관리실", "office"], ["관리방", "office"], ["역무", "office"],
	["서무", "office"], ["사령", "office"], ["접수", "office"], ["계량", "office"],
	["창고", "storage"], ["보관", "storage"], ["비축", "storage"], ["입고", "storage"], ["광", "storage"],
	["매장", "shop"], ["가게", "shop"],
	["작업", "work"], ["공구", "work"], ["공방", "work"], ["정비", "work"],
]

## 묶음마다 놓는 가구. size는 (긴 변, 짧은 변). need: 꼭 있을 것. holds: 상자가 드는 용기.
## at: "wall"(긴 변을 벽에) / "mid"(벽에서 떨어져도 됨). 큰 가구(TALL_KINDS)는 창 앞에 못 둔다.
## near: "far_door"(문에서 멀리) / "door"(문 가까이) / "stove"(난로 가까이).
const PALETTE: Dictionary = {
	"bed": [
		{"kind": "bed", "size": Vector2i(2, 1), "need": true, "at": "wall", "corner": true, "near": "far_door"},
		{"kind": "dresser", "size": Vector2i(2, 1), "chance": 0.8, "holds": true, "at": "wall"},
		{"kind": "wardrobe", "size": Vector2i(2, 1), "chance": 0.6, "holds": true, "at": "wall"},
		{"kind": "chair", "size": Vector2i(1, 1), "chance": 0.5, "at": "wall"},
		# 침대 머리(베개 쪽) 곁 협탁(_bedsides). 긴 변을 벽에 댄 침대는 베개 한쪽만 트여 하나, 넓은 침실에서
		# 머리를 벽에 댄 침대는 베개 양옆에 짝(사용자 10-28 「짝 가구」)이 선다(_wide_bed_items).
		{"kind": "nightstand", "size": Vector2i(1, 1), "chance": 0.5, "holds": true, "at": "wall", "near": "bed_head"},
	],
	"kitchen": [
		# 난로·싱크·조리대는 _kitchen_run에서 한 줄로 먼저 놓는다.
		{"kind": "dining_set", "size": Vector2i(2, 2), "chance": 0.25, "at": "mid"},
		{"kind": "fridge_open", "size": Vector2i(1, 1), "chance": 0.96, "holds": true, "at": "wall"},
		{"kind": "cupboard", "size": Vector2i(1, 1), "chance": 0.5, "holds": true, "at": "wall"},
	],
	"living": [
		{"kind": "cold_stove", "size": Vector2i(1, 1), "need": true, "at": "wall"},
		{"kind": "armchair", "size": Vector2i(1, 1), "need": true, "at": "wall", "near": "stove", "copies": 2},
		{"kind": "settee", "size": Vector2i(2, 1), "chance": 0.8, "at": "mid", "near": "stove"},
		{"kind": "bookcase", "size": Vector2i(2, 1), "chance": 0.7, "holds": true, "at": "wall"},
		{"kind": "radio_set", "size": Vector2i(2, 1), "chance": 0.6, "at": "wall"},
		{"kind": "low_table", "size": Vector2i(1, 1), "chance": 0.75, "at": "mid", "near": "stove"},
		{"kind": "side_table", "size": Vector2i(1, 1), "chance": 0.55, "holds": true, "at": "wall"},
	],
	# 욕실 표준 묶음(결정 469 F4): 변기·세면대·약장이 꼭, 휴지통은 거의 늘, 넓으면 욕조·수건 선반.
	"bath": [
		{"kind": "toilet", "size": Vector2i(1, 1), "need": true, "at": "wall", "corner": true},
		{"kind": "washstand", "size": Vector2i(1, 1), "need": true, "at": "wall", "holds": true},
		{"kind": "medicine_cabinet", "size": Vector2i(1, 1), "need": true, "at": "wall", "holds": true},
		{"kind": "waste_bin", "size": Vector2i(1, 1), "chance": 0.9, "at": "wall", "holds": true},
		{"kind": "bathtub", "size": Vector2i(2, 1), "chance": 0.5, "at": "wall", "corner": true},
		{"kind": "towel_shelf", "size": Vector2i(1, 1), "chance": 0.4, "holds": true, "at": "wall"},
	],
	"office": [
		{"kind": "desk", "size": Vector2i(2, 1), "need": true, "holds": true, "at": "wall"},
		{"kind": "chair", "size": Vector2i(1, 1), "need": true, "copies": 2, "at": "mid", "near": "desk"},
		{"kind": "file_cabinet", "size": Vector2i(1, 1), "chance": 0.65, "holds": true, "at": "wall"},
		{"kind": "shelf", "size": Vector2i(3, 1), "chance": 0.4, "holds": true, "at": "wall"},
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
	# 작업실·공구실·정비실(ref-ops 대조 7: 바깥 건물은 공구·재료 몫): 작업대가 꼭 있고 연장·부품.
	"work": [
		{"kind": "workbench", "size": Vector2i(3, 1), "need": true, "holds": true, "at": "wall"},
		{"kind": "tool_rack", "size": Vector2i(2, 1), "chance": 0.75, "at": "wall"},
		{"kind": "tool_chest", "size": Vector2i(2, 1), "chance": 0.6, "holds": true, "at": "wall"},
		{"kind": "parts_rack", "size": Vector2i(3, 1), "chance": 0.5, "holds": true, "at": "wall"},
		{"kind": "part_crate", "size": Vector2i(1, 1), "chance": 0.5, "holds": true, "at": "wall"},
		{"kind": "sawhorse", "size": Vector2i(2, 1), "chance": 0.35, "at": "mid"},
		{"kind": "fuel_drum", "size": Vector2i(1, 1), "chance": 0.3, "at": "wall"},
	],
	# 차고: 작업대, 반쯤은 서 있는 차, 타이어·기름통·연장.
	"garage": [
		{"kind": "workbench", "size": Vector2i(3, 1), "need": true, "holds": true, "at": "wall"},
		{"kind": "car", "size": Vector2i(4, 2), "chance": 0.45, "at": "mid"},
		{"kind": "tire_stack", "size": Vector2i(2, 2), "chance": 0.6, "at": "wall", "corner": true},
		{"kind": "tool_rack", "size": Vector2i(2, 1), "chance": 0.7, "at": "wall"},
		{"kind": "fuel_can_group", "size": Vector2i(2, 1), "chance": 0.55, "at": "wall"},
		{"kind": "tool_chest", "size": Vector2i(2, 1), "chance": 0.5, "holds": true, "at": "wall"},
		{"kind": "hardware_rack", "size": Vector2i(3, 1), "chance": 0.4, "holds": true, "at": "wall"},
	],
	# 헛간·외양간·마구간·건초 헛간: 사료 자루와 상자, 건초 수레·짐수레, 연장.
	"barn": [
		{"kind": "sack_pile", "size": Vector2i(2, 2), "need": true, "at": "wall"},
		{"kind": "crate_stack", "size": Vector2i(2, 2), "need": true, "holds": true, "at": "wall"},
		{"kind": "hay_cart", "size": Vector2i(3, 2), "chance": 0.45, "at": "mid"},
		{"kind": "tool_rack", "size": Vector2i(2, 1), "chance": 0.6, "at": "wall"},
		{"kind": "farm_cart", "size": Vector2i(4, 2), "chance": 0.25, "at": "mid"},
		{"kind": "barrel", "size": Vector2i(1, 1), "chance": 0.5, "at": "wall"},
		{"kind": "sawhorse", "size": Vector2i(2, 1), "chance": 0.3, "at": "mid"},
	],
	# 장작 헛간·장작 창고: 장작 더미가 꼭 있고 장작 단·모탕·선반.
	"woodshed": [
		{"kind": "firewood_stack", "size": Vector2i(3, 2), "need": true, "at": "wall"},
		{"kind": "firewood_rick", "size": Vector2i(3, 1), "chance": 0.7, "at": "wall"},
		{"kind": "sawhorse", "size": Vector2i(2, 1), "chance": 0.6, "at": "mid"},
		{"kind": "shelf", "size": Vector2i(3, 1), "chance": 0.5, "holds": true, "at": "wall"},
		{"kind": "tool_rack", "size": Vector2i(2, 1), "chance": 0.45, "at": "wall"},
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
	"dresser": true, "chair": true, "nightstand": true, "counter": true, "sink": true, "cupboard": true,
	"settee": true, "armchair": true, "low_table": true, "side_table": true,
	"toilet": true, "washstand": true, "bathtub": true, "towel_shelf": true,
	"waste_bin": true,
}
## 목표 하한·상한, 절대 상한, 빈 바닥 하한. 길·문·계단 검사는 항상 우선한다.
## 사무실·창고·가게는 사분위가 없어 중앙값 주위의 작업 범위를 둔다.
const DENSITY: Dictionary = {
	"bed": [0.458, 0.583, 0.67, 0.33], "kitchen": [0.417, 0.556, 0.64, 0.36],
	"living": [0.300, 0.419, 0.50, 0.50], "bath": [0.444, 0.667, 0.67, 0.33],
	"office": [0.38, 0.52, 0.67, 0.33], "shop": [0.30, 0.42, 0.61, 0.39],
	"storage": [0.25, 0.40, 0.67, 0.33], "store": [0.25, 0.40, 0.67, 0.33],
	"boiler": [0.25, 0.40, 0.67, 0.33],
	"work": [0.25, 0.40, 0.67, 0.33], "garage": [0.25, 0.40, 0.67, 0.33],
	"barn": [0.25, 0.40, 0.67, 0.33], "woodshed": [0.25, 0.40, 0.67, 0.33],
}
## Rooms that, short of their share, take the pieces the dice left out (_palette_for).
const FILL_UNROLLED: Dictionary = {"work": true, "garage": true, "barn": true, "woodshed": true}
## 목표 몫 채우기(결정 469 F2): 묶음을 다 굴리고도 목표 몫(DENSITY 하한~상한에서 굴린 값)보다 빈 방은
## 이 차례로 더 놓는다. 벽 가구가 먼저, 모형이 있는 것(위층에서도 몸을 막음)이 먼저. 담는 가구는
## 묶음에서 놓이는 방 갈래에만 둔다(loot_dress.gd FURNITURE_ROOM이 가구로 방을 읽는다).
const FILL: Dictionary = {
	"bed": [
		{"kind": "wardrobe", "size": Vector2i(2, 1), "holds": true, "at": "wall"},
		{"kind": "blanket_chest", "size": Vector2i(2, 1), "holds": true, "at": "wall"},
		{"kind": "dresser", "size": Vector2i(2, 1), "holds": true, "at": "wall"},
		{"kind": "chair", "size": Vector2i(1, 1), "at": "wall"},
	],
	"kitchen": [
		{"kind": "fridge_open", "size": Vector2i(1, 1), "holds": true, "at": "wall"},
		{"kind": "shelf", "size": Vector2i(3, 1), "holds": true, "at": "wall"},
		{"kind": "cupboard", "size": Vector2i(1, 1), "holds": true, "at": "wall"},
		{"kind": "barrel", "size": Vector2i(1, 1), "at": "wall"},
		{"kind": "dining_set", "size": Vector2i(2, 2), "at": "mid"},
		{"kind": "chair", "size": Vector2i(1, 1), "at": "wall"},
	],
	"living": [
		{"kind": "bookcase", "size": Vector2i(2, 1), "holds": true, "at": "wall"},
		{"kind": "blanket_chest", "size": Vector2i(2, 1), "holds": true, "at": "wall"},
		{"kind": "side_table", "size": Vector2i(1, 1), "holds": true, "at": "wall"},
		{"kind": "armchair", "size": Vector2i(1, 1), "at": "wall"},
		{"kind": "settee", "size": Vector2i(2, 1), "at": "wall"},
	],
	"bath": [
		{"kind": "towel_shelf", "size": Vector2i(1, 1), "holds": true, "at": "wall"},
		{"kind": "waste_bin", "size": Vector2i(1, 1), "holds": true, "at": "wall"},
	],
	"office": [
		{"kind": "file_cabinet", "size": Vector2i(1, 1), "holds": true, "at": "wall"},
		{"kind": "shelf", "size": Vector2i(3, 1), "holds": true, "at": "wall"},
		{"kind": "chair", "size": Vector2i(1, 1), "at": "wall"},
	],
}
## 배치 틀(사용자 10-28 「가구배치가 단조로우면 안돼」): 살림방은 방마다 기댈 벽 하나와 자리 고르는 결을
## 굴린다. 큰 가구는 그 벽을 먼저 보고, 같은 점수의 자리는 결이 가른다(늘 위·왼쪽 구석으로 몰리지 않게).
const LAYOUT_CLASSES: Dictionary = {"bed": true, "living": true, "kitchen": true, "bath": true}
const ANCHOR_KINDS: Dictionary = {"bed": true, "settee": true, "wardrobe": true, "dresser": true, "bookcase": true, "bathtub": true}
const LEAN_BONUS := 1.5
const GRAIN := 0.6
## _roll 쓰임 번호(점검 L3): 배치 틀의 기댈 벽, 부엌 줄의 난로 끝, 깔개의 깔림·무늬·결, 홑침대 둘.
const ROLL_BACK := 1
const ROLL_RUN_END := 2
const ROLL_RUG := 3
const ROLL_WEAVE := 4
const ROLL_RUG_LOOK := 5
const ROLL_TWIN := 6
## 넓은 침실(짧은 변 WIDE_BED_SIDE칸 이상): 침대는 머리를 벽에 대는 자리부터 HEAD_CANDIDATES개까지 본다.
## 베개 양옆이 트여 협탁이 짝으로 서고, 길 검사로 다 막히면 지금처럼 긴 변을 벽에 댄다.
## 홑침대 둘(아이 방·손님 방)은 지도 침실 전체의 TWIN_SHARE를 짧은 변이 넓은 방부터 고른다(_twin_rooms, 코디
## 10-30 07:1x). 참고 사본 방 꾸밈 표(loot-feel 10-30): 잘 자리 둘 이상인 방은 넓이로는 늘지 않고 짧은 변이
## 4칸(하나인 방 3칸)이며, 아이 방 갈래가 없을 때 침실의 12%가 참고와 맞는다.
const WIDE_BED_SIDE := 4
const HEAD_CANDIDATES := 12
const TWIN_SHARE := 0.12
## 깔개(room_finish 깔개 칸): 방 갈래마다 깔릴 몫과 고르는 무늬(셰이더 room_rug_finish의 0~6).
const RUG_CHANCE: Dictionary = {"bed": 0.55, "living": 0.8, "dining": 0.9}
const RUG_WEAVES: Dictionary = {"bed": [0, 2, 3, 6], "living": [1, 3, 4, 5, 0], "dining": [1, 5, 0]}
## 가구 색 판(art3d `furniture_tints.gd` TINTS, 종류마다 넷): 한 집의 가구는 한 판으로 맞춘다. 표에 없는
## 종류나 판 번호가 없는 줄은 모형 제 색.
const TINT_SETS := 4
## 방마다 하나만 서는 가구(채우기가 둘째를 놓지 않는다).
const ONE_PER_ROOM: Dictionary = {"fridge_open": true, "dining_set": true, "settee": true, "bathtub": true,
	"waste_bin": true, "bed": true, "cold_stove": true, "desk": true, "radio_set": true}
const OPTIONAL_BY_KIND: Dictionary = {"display_shelf": 0.6, "crate_stack": 0.6, "barrel": 0.6,
	"shelf": 0.6, "sack_pile": 0.6, "fuel_drum": 0.6, "toolbox": 0.6, "tin_crate": 0.6}
const COUNTER_MIN: int = 4
const COUNTER_MAX: int = 8
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
	if lv >= 1 and cls in ["shop", "storage", "work", "garage", "barn", "woodshed"] and kinds.has("bed"):
		return "bed"
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


## ---------------------------------------------------------------- 이름표와 건물 이름으로 읽는 방

## 살림집 건물 이름의 낱말(「… 집」으로 끝나는 이름도). 이름표도 가구도 없는 빈 집의 방을
## 땅 층 큰 방부터 이 차례로, 나머지와 위층은 침실로 읽는다.
const HOME_WORDS: Array[String] = ["주택", "사택", "관사", "농가", "오두막", "움막", "살림"]
const HOME_ORDER: Array[String] = ["kitchen", "bed", "living"]
## 한 방뿐인 살림 움막은 거실(난로와 긴 의자).
const ONE_ROOM_HOME: String = "living"
## 방으로 칠 크기: 복도·벽장은 뺀다.
const ROOM_MIN_CELLS: int = 12
const ROOM_MIN_SIDE: int = 3
## 이만큼 이하인 방(과 폭 두 칸 방)은 문 앞을 1칸만 비운다(_forbidden).
const SMALL_ROOM_CELLS: int = 9
## 남긴 지도 가구가 대신하는 꼭 있을 가구.
const STANDS_FOR: Dictionary = {"bunk_bed": "bed", "office_desk": "desk", "typewriter_desk": "desk"}


## 가구 메모 「X의 Y」에서 가장 많은 X(같으면 가나다 앞).
static func _note_name(props: Array, idxs: Array) -> String:
	var names: Dictionary = {}
	for i: int in idxs:
		var note := String(props[i].get("note", ""))
		var cut := note.find("의 ")
		if cut > 0:
			var who := note.substr(0, cut)
			names[who] = int(names.get(who, 0)) + 1
	var name := ""
	var best := 0
	var keys: Array = names.keys()
	keys.sort()
	for k: String in keys:
		if names[k] > best:
			best = names[k]
			name = k
	return name


## 방 안 이름표 가운데 방 이름 낱말이 든 첫 것. 방 번호 -> 글.
static func _room_labels(data: Dictionary, lv: int, g: FieldGrid, of: PackedInt32Array) -> Dictionary:
	var out: Dictionary = {}
	# 바닥 이름표가 먼저, 그다음 방 나누기(room_split)의 숨은 이름표.
	for lab: Variant in data.get("labels", []) + data.get("_room_hints", []):
		if not lab is Dictionary or int(lab.get("level", 0)) != lv:
			continue
		var c: Variant = _cell(lab.get("cell"))
		if c == null:
			continue
		var ri := _at(g, of, c)
		var text := String(lab.get("text", ""))
		if ri >= 0 and not out.has(ri) and _name_class(text)[1]:
			out[ri] = text
	return out


## 어느 층이든 가구 메모·이름표·가구로 묶음이 정해진 방이 있는 건물.
static func _classified_buildings(data: Dictionary, levels: Dictionary, props: Array) -> Dictionary:
	var out: Dictionary = {}
	for lv: int in levels:
		var g: FieldGrid = levels[lv]
		var map := _rooms(data, lv, g)
		var of: PackedInt32Array = map["of"]
		var labels := _room_labels(data, lv, g, of)
		var in_room := _props_by_room(g, of, props, lv)
		for ri in range(map["rooms"].size()):
			var idxs: Array = in_room.get(ri, [])
			if idxs.is_empty() and not labels.has(ri):
				continue
			var kinds: Dictionary = {}
			for i: int in idxs:
				kinds[String(props[i].get("kind", ""))] = true
			var name := _note_name(props, idxs)
			if name.is_empty():
				name = labels.get(ri, "")
			if not room_class(name, kinds, lv).is_empty():
				out[int(map["rooms"][ri]["building"])] = true
	return out


static func _props_by_room(g: FieldGrid, of: PackedInt32Array, props: Array, lv: int) -> Dictionary:
	var out: Dictionary = {}
	for i in range(props.size()):
		if int(props[i].get("level", 0)) != lv:
			continue
		var r: Variant = _rect(props[i].get("rect"))
		if r == null:
			continue
		var ri := _at(g, of, r.position + r.size / 2)
		if ri >= 0:
			if not out.has(ri):
				out[ri] = []
			out[ri].append(i)
	return out


## 가구도 이름도 없는 빈 방을 건물 이름으로 읽는다(이름표만 둔 지도, house_layout.md 3장).
## 창고·가게처럼 이름에 방 낱말이 든 건물은 그 묶음. 살림집은 그 건물에 묶음이 정해진 방이
## 하나도 없을 때만: 땅 층 큰 방부터 부엌·침실·거실, 나머지와 위층은 침실, 한 방뿐이면 거실.
## 방 번호 -> 묶음.
static func _building_classes(data: Dictionary, lv: int, map: Dictionary, in_room: Dictionary, props: Array,
		labels: Dictionary, classified: Dictionary) -> Dictionary:
	var names: Dictionary = {}
	for row: Variant in data.get("buildings", []):
		if row is Dictionary:
			names[int(row.get("id", -1))] = String(row.get("name", ""))
	var empty: Dictionary = {}  # 건물 -> [방 번호]
	for ri in range(map["rooms"].size()):
		if in_room.has(ri) or labels.has(ri):
			continue
		var room: Dictionary = map["rooms"][ri]
		if not _roomy(room["cells"]):
			continue
		var b: int = room["building"]
		if not empty.has(b):
			empty[b] = []
		empty[b].append(ri)
	var out: Dictionary = {}
	var ids: Array = empty.keys()
	ids.sort()
	for b: int in ids:
		var bname: String = names.get(b, "")
		var rooms: Array = empty[b]
		var found := _name_class(bname)
		if found[1]:
			var cls := room_class(bname, {}, lv)
			# 가게 위층의 빈 방은 살림방이다(가게 이름을 물려받은 위층, room_class의 주석과 같은 뜻).
			if lv >= 1 and cls == "shop":
				cls = "bed"
			if not cls.is_empty():
				for ri: int in rooms:
					out[ri] = cls
			continue
		if lv < 0 or classified.has(b) or not _home(bname):
			continue
		rooms.sort_custom(func(a: int, c: int) -> bool:
			var na: int = map["rooms"][a]["cells"].size()
			var nc: int = map["rooms"][c]["cells"].size()
			return na > nc or (na == nc and a < c))
		for k in range(rooms.size()):
			var cls := "bed"
			if lv == 0 and rooms.size() == 1:
				cls = ONE_ROOM_HOME
			elif lv == 0 and k < HOME_ORDER.size():
				cls = HOME_ORDER[k]
			out[rooms[k]] = cls
	return out


static func _home(name: String) -> bool:
	if name.ends_with("집"):
		return true
	for w: String in HOME_WORDS:
		if name.find(w) >= 0:
			return true
	return false


## 이 장소 종류에서 멈춘 기계(core_scenes.gd SCENES 낱말)가 설 수 있는 건물 id.
static func _machine_buildings(data: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var rows: Array = CoreScenes.SCENES.get(String(data.get("place_kind", "")), [])
	for b: Dictionary in data.get("buildings", []):
		for row: Array in rows:
			if String(b.get("name", "")).contains(String(row[0])):
				out[int(b["id"])] = true
	return out


## 모든 층을 먼저 읽고 건물당 욕실 하나를 고른다. 작은 방은 이 선택에만 쓴다.
## 원래 부엌·유일한 침실은 어느 후보 단계에서도 바꾸지 않는다.
static func density_plan(data: Dictionary) -> Dictionary:
	var levels: Dictionary = data.get("levels", {0: data["grid"]})
	var props: Array = data.get("props", [])
	var classified := _classified_buildings(data, levels, props)
	var classes: Dictionary = {}
	var buildings: Dictionary = {}
	var homes: Dictionary = {}
	var machine := _machine_buildings(data)
	for b: Dictionary in data.get("buildings", []):
		if _home(String(b.get("name", ""))):
			homes[int(b["id"])] = true
	var lvs: Array = levels.keys()
	lvs.sort()
	for lv: int in lvs:
		var g: FieldGrid = levels[lv]
		var map := _rooms(data, lv, g)
		var of: PackedInt32Array = map["of"]
		var in_room := _props_by_room(g, of, props, lv)
		var labels := _room_labels(data, lv, g, of)
		var inherited := _building_classes(data, lv, map, in_room, props, labels, classified)
		for ri in range(map["rooms"].size()):
			var idxs: Array = in_room.get(ri, [])
			var kinds: Dictionary = {}
			for i: int in idxs:
				var kind := String(props[i].get("kind", ""))
				kinds[kind] = true
				if STANDS_FOR.has(kind):
					kinds[STANDS_FOR[kind]] = true
			var name := _note_name(props, idxs)
			var cls := room_class(labels.get(ri, "") if name.is_empty() else name, kinds, lv)
			if cls.is_empty():
				cls = inherited.get(ri, "")
			# 멈춘 기계가 서는 건물의 일터 방은 지도가 둔 그대로다 — 새 가구가 기계 자리를 먹지 않게.
			if FILL_UNROLLED.has(cls) and machine.has(int(map["rooms"][ri]["building"])):
				cls = ""
			var key := "%d:%d" % [lv, ri]
			classes[key] = cls
			if lv < 0:
				continue
			var room: Dictionary = map["rooms"][ri]
			var b: int = room["building"]
			if cls == "bed":
				homes[b] = true
			if not buildings.has(b):
				buildings[b] = []
			var cells: Array[Vector2i] = room["cells"]
			var lo := cells[0]
			var hi := cells[0]
			var doors: Dictionary = {}
			for c in cells:
				lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
				hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
				for d in DIRS:
					if g.doors.has(c + d):
						doors[c + d] = true
			buildings[b].append({"key": key, "level": lv, "room": ri, "area": cells.size(),
				"short": mini(hi.x - lo.x + 1, hi.y - lo.y + 1), "doors": doors.size(), "class": cls})
	var baths: Dictionary = {}
	for b: int in homes:
		var rooms: Array = buildings.get(b, [])
		var bedrooms := 0
		for room: Dictionary in rooms:
			bedrooms += int(room["class"] == "bed")
		var candidates: Array = []
		for room: Dictionary in rooms:
			if room["class"] == "kitchen" or (room["class"] == "bed" and bedrooms == 1):
				continue
			if room["area"] >= 4 and room["area"] <= 11 and room["short"] >= 2 and room["doors"] == 1:
				candidates.append(room)
		var reason := "small_one_door"
		if candidates.is_empty() and rooms.size() >= 3:
			reason = "smallest_fallback"
			for room: Dictionary in rooms:
				if room["area"] >= 4 and room["area"] <= 16 and room["short"] >= 2 and room["class"] != "kitchen" and not (room["class"] == "bed" and bedrooms == 1):
					candidates.append(room)
		candidates = [data["_split_baths"][b]] if data.get("_split_baths", {}).has(b) else candidates
		candidates.sort_custom(func(a: Dictionary, c: Dictionary) -> bool:
			if reason == "small_one_door" and a["level"] != c["level"]:
				return a["level"] < c["level"]
			if a["area"] != c["area"]:
				return a["area"] < c["area"]
			return a["level"] < c["level"] if a["level"] != c["level"] else a["room"] < c["room"])
		if candidates.is_empty():
			baths[str(b)] = {"selected": false, "reason": "no_eligible_room", "rooms": rooms.size(), "bedrooms": bedrooms}
		else:
			var selected: Dictionary = candidates[0]
			classes[selected["key"]] = "bath"
			baths[str(b)] = selected.duplicate()
			baths[str(b)]["selected"] = true
			baths[str(b)]["reason"] = reason
	return {"classes": classes, "baths": baths}


## 확률은 가구 종류마다 한 번. 넓은 방의 추가 가구는 뽑힌 종류 안에서만 고른다.
static func _palette_for(cls: String, area: int, rng: RandomNumberGenerator) -> Array:
	var selected: Array = []
	var storage := false
	for source: Dictionary in PALETTE[cls]:
		var item := source.duplicate()
		if not item.get("need", false) and rng.randf() >= float(item.get("chance", OPTIONAL_BY_KIND.get(item["kind"], 0.0))):
			continue
		storage = storage or item["kind"] in ["dresser", "wardrobe"]
		selected.append(item)
		if int(item.get("copies", 1)) > 1 and rng.randf() < 0.5:
			var extra := item.duplicate()
			extra["need"] = false
			selected.append(extra)
	# 침실의 장롱 또는 서랍장은 집 배치 브리프의 필수 수납이다.
	if cls == "bed" and not storage:
		selected.append(PALETTE["bed"][1].duplicate())
	if cls == "bed":
		for item: Dictionary in selected:
			if item["kind"] in ["dresser", "wardrobe"]:
				item["need"] = true
				break
	selected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.get("need", false)) != bool(b.get("need", false)):
			return bool(a.get("need", false))
		var sa: Vector2i = a["size"]
		var sb: Vector2i = b["size"]
		return sa.x * sa.y > sb.x * sb.y)
	var out := selected.duplicate(true)
	var typical: int = {"bed": 15, "living": 28, "office": 16, "shop": 28, "storage": 9, "store": 9, "boiler": 18,
		"work": 30, "garage": 40, "barn": 30, "woodshed": 20}.get(cls, 100000)
	var repeats := clampi(int(ceil(float(area) / typical)) - 1, 0, 5)
	for cycle in range(repeats):
		for original: Dictionary in selected:
			# One of these to a room: a second stove, workbench, car or bed is not more of the room.
			if original["kind"] in ["cold_stove", "radio_set", "nightstand", "side_table", "workbench", "car", "hay_cart", "farm_cart", "bed"]:
				continue
			var item := original.duplicate()
			item["need"] = false
			item["fill"] = true
			out.append(item)
	# A workplace or farm room short of its share after the dice takes the pieces it did not
	# roll, while it is under the share, so a small workshop is never barer than the map left it.
	if FILL_UNROLLED.has(cls):
		var rolled: Dictionary = {}
		for item: Dictionary in selected:
			rolled[item["kind"]] = true
		for source: Dictionary in PALETTE[cls]:
			if not rolled.has(source["kind"]):
				var item := source.duplicate()
				item["need"] = false
				item["fill"] = true
				out.append(item)
	return out


## 방으로 칠 만한가: 칸 수와 짧은 변.
static func _roomy(cells: Array[Vector2i]) -> bool:
	if cells.size() < ROOM_MIN_CELLS:
		return false
	var lo := cells[0]
	var hi := cells[0]
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return mini(hi.x - lo.x + 1, hi.y - lo.y + 1) >= ROOM_MIN_SIDE


## 폭이 두 칸 이하인 방.
static func _narrow(cells: Array[Vector2i]) -> bool:
	if cells.is_empty():
		return false
	var lo := cells[0]
	var hi := cells[0]
	for c in cells:
		lo = lo.min(c)
		hi = hi.max(c)
	return mini(hi.x - lo.x + 1, hi.y - lo.y + 1) <= 2


## 비울 칸: "all"은 아무것도, "tall"은 큰 가구만 못 놓는다. 머리를 벽에 댄 침대가 서면 furnish_rooms가 베개
## 양옆에 "stand"(협탁만)를 더한다.
static func _forbidden(g: FieldGrid, of: PackedInt32Array, ri: int, cells: Array[Vector2i], stairs: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	# 9칸 이하 방(욕실·벽장·찬방)과 폭 두 칸 방(좁은 부엌)은 문 안쪽 1칸만: 2칸이면 욕실에
	# 변기·세면대밖에, 좁은 부엌에 조리대 한 줄도 못 선다(결정 442 「작은 욕실 문 앞 비움」 가).
	# 문 바로 앞 칸은 어느 방이든 늘 빈다.
	var deep: Array = [0] if cells.size() <= SMALL_ROOM_CELLS or _narrow(cells) else [0, 1]
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
				# 문(뚫린 곳) 안쪽 2칸(작은 방은 1칸) x 문과 양옆 1칸.
				var inward := -d
				var side := Vector2i(inward.y, inward.x)
				for k in deep:
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


## 침대 모형의 베개 쪽 끝 칸. 침대 모형은 머리가 -X이고 facing만큼 돈다(prop_fit.footprint):
## 0은 왼쪽 끝, 1은 위 끝, 2는 오른쪽 끝, 3은 아래 끝.
static func bed_head(r: Rect2i, facing: int) -> Vector2i:
	match posmod(facing, 4):
		2:
			return Vector2i(r.end.x - 1, r.position.y)
		3:
			return Vector2i(r.position.x, r.end.y - 1)
	return r.position


## 협탁 자리: 베개 쪽 끝 너머 벽을 따라 한 칸. 그 끝이 벽에 닿았으면(구석 침대) 그 벽에 붙여
## 베개 옆 한 칸. 발치나 침대 앞 가운데에는 서지 않는다.
static func _bedside(g: FieldGrid, of: PackedInt32Array, ri: int, r: Rect2i, facing: int) -> Vector2i:
	var head := bed_head(r, facing)
	var foot := r.end - Vector2i.ONE if head == r.position else r.position
	var beyond := head + (head - foot).sign()
	if _at(g, of, beyond) == ri:
		return beyond
	return head + [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0)][posmod(facing, 4)]


## 협탁 자리들. 머리를 벽에 댄 침대(head_wall)는 베개 칸 양옆(머리 벽을 따라) 가운데 방 안 칸, 아니면 _bedside 하나.
static func _bedsides(g: FieldGrid, of: PackedInt32Array, ri: int, r: Rect2i, facing: int, head_wall: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not head_wall:
		out.append(_bedside(g, of, ri, r, facing))
		return out
	var head := bed_head(r, facing)
	var across := Vector2i(0, 1) if r.size.x > r.size.y else Vector2i(1, 0)
	for c: Vector2i in [head - across, head + across]:
		if _at(g, of, c) == ri:
			out.append(c)
	return out


## 베개를 댄 벽 쪽 → 침대 facing(bed_head가 그 벽 앞 끝이 되게): 서 0, 북 1, 동 2, 남 3.
static func _facing_from_head(d: Vector2i) -> int:
	if d == Vector2i(-1, 0):
		return 0
	if d == Vector2i(0, -1):
		return 1
	if d == Vector2i(1, 0):
		return 2
	return 3


## 칸들을 두른 네모의 짧은 변.
static func _short_side(cells: Array[Vector2i]) -> int:
	if cells.is_empty():
		return 0
	var lo := cells[0]
	var hi := cells[0]
	for c in cells:
		lo = lo.min(c)
		hi = hi.max(c)
	return mini(hi.x - lo.x + 1, hi.y - lo.y + 1)


## 침대 머리를 벽에 대고도 둘레가 남는 침실.
static func _wide_bedroom(cells: Array[Vector2i]) -> bool:
	return _short_side(cells) >= WIDE_BED_SIDE


## 홑침대 둘을 둘 침실("층:방" -> true): 이 지도에서 가구를 놓는 침실 수의 TWIN_SHARE(반올림)만큼, 짧은 변이
## 넓은 방부터, 같으면 씨앗을 섞은 굴림 차례로. 짧은 변이 WIDE_BED_SIDE보다 좁은 방은 머리-벽 침대 둘이 서지
## 않아 고르지 않는다. 첫 바퀴는 한 건물 한 층에 하나씩(같은 꼴 방이 줄지은 연립·위층 숙소에 몰리지 않게),
## 모자라면 둘째 바퀴에서 채운다.
static func _twin_rooms(data: Dictionary, plan: Dictionary, levels: Dictionary, place: String) -> Dictionary:
	var count := 0
	var wide: Array = []  # [짧은 변, 굴림, "층:방", "건물:층"]
	for lv: int in levels:
		var g: FieldGrid = levels[lv]
		var map := _rooms(data, lv, g)
		for ri in range(map["rooms"].size()):
			var key := "%d:%d" % [lv, ri]
			var cells: Array[Vector2i] = map["rooms"][ri]["cells"]
			if plan["classes"].get(key, "") != "bed" or cells.size() < ROOM_MIN_CELLS:
				continue
			count += 1
			var side := _short_side(cells)
			if side >= WIDE_BED_SIDE:
				var bid := int(map["rooms"][ri]["building"])
				wide.append([side, _roll(look_seed_of(place, bid, lv, ri), ROLL_TWIN), key, "%d:%d" % [bid, lv]])
	wide.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var quota := mini(roundi(count * TWIN_SHARE), wide.size())
	var out: Dictionary = {}
	var floors: Dictionary = {}
	for spread: bool in [true, false]:
		for row: Array in wide:
			if out.size() >= quota:
				return out
			if out.has(row[2]) or (spread and floors.has(row[3])):
				continue
			out[row[2]] = true
			floors[row[3]] = true
	return out


## 넓은 침실의 묶음: 침대는 머리-벽 자리부터(head_first), 협탁 뒤에 짝 하나(pair, 꼭 있을 것 아님).
## twin이면(홑침대 둘) 첫 침대 바로 뒤에 둘째 침대(머리-벽 자리만)를 끼우고, 짝 대신 두 침대 사이에 협탁 하나
## (굴림에 없었으면 더함, 코디 10-30 11:2x 「두 침대 방의 흔한 꼴」). 채우기(FILL)는 침대를 더하지 않아(ONE_PER_ROOM)
## 여기서 끼운다.
static func _wide_bed_items(items: Array, twin: bool) -> Array:
	var out: Array = []
	var stand := false
	for item: Dictionary in items:
		out.append(item)
		if item["kind"] == "bed" and item.get("need", false):
			item["head_first"] = true
			if twin:
				item["twin_room"] = true
				out.append({"kind": "bed", "size": Vector2i(2, 1), "at": "head", "near": "twin", "twin": true, "twin_room": true})
		elif item["kind"] == "nightstand" and not item.get("fill", false):
			stand = true
			if not twin:
				var pair: Dictionary = item.duplicate()
				pair["need"] = false
				pair["pair"] = true
				out.append(pair)
	if twin and not stand:
		out.append({"kind": "nightstand", "size": Vector2i(1, 1), "holds": true, "at": "wall", "near": "bed_head"})
	return out


## 그 칸에 가구가 설 수 있나(방 안, 빈칸, 안 쓴 칸, 비울 칸 아님; tall이면 창 앞도 아님).
static func _free_cell(g: FieldGrid, of: PackedInt32Array, ri: int, c: Vector2i, taken: Dictionary, forbid: Dictionary,
		tall: bool = false) -> bool:
	var f: String = forbid.get(c, "")
	return _at(g, of, c) == ri and g.solid_at(c) == S.NONE and not taken.has(c) and f != "all" and not (tall and f == "tall")


## 머리-벽 자리 하나(r은 1×2·2×1 침대 꼴): 짧은 변 한쪽(베개 끝)이 벽이고 긴 두 변은 방으로 트인 꼴.
## 베개 양옆이 비면(짝 협탁 자리) 점수를 더 준다. 홑침대 둘 방(twin_room)은 긴 변 한쪽이 옆벽에 닿아도 되고
## (침대·협탁·침대 세 칸이 폭 4칸 방에 서게), 첫 침대는 같은 벽 한 칸 건너 둘째가 설 자리가 있는 곳이, 둘째는
## 그 자리가 먼저. 그런 끝이 없으면 {}.
static func _head_spot(g: FieldGrid, of: PackedInt32Array, ri: int, r: Rect2i, item: Dictionary, forbid: Dictionary,
		taken: Dictionary, doors_in: Array, taste: Dictionary) -> Dictionary:
	if r.size.x == r.size.y:
		return {}
	var along := Vector2i(1, 0) if r.size.x > r.size.y else Vector2i(0, 1)
	var across := Vector2i(along.y, along.x)
	var twin_room: bool = item.get("twin_room", false)
	if int(_wall_side(g, of, ri, r, across)) + int(_wall_side(g, of, ri, r, -across)) > (1 if twin_room else 0):
		return {}
	var best: Dictionary = {}
	for d: Vector2i in [-along, along]:
		if not _wall_side(g, of, ri, r, d):
			continue
		var facing := _facing_from_head(d)
		var head := bed_head(r, facing)
		# 베개 양옆이 방 바닥이어야 한다(창이 난 벽은 _wall_side로는 벽이 아니라서 따로 본다).
		var sides := int(_at(g, of, head - across) == ri) + int(_at(g, of, head + across) == ri)
		if sides < (1 if twin_room else 2):
			continue
		var score := 3.0
		for c: Vector2i in [head - across, head + across]:
			if _free_cell(g, of, ri, c, taken, forbid):
				score += 1.0
		if twin_room and item.get("near", "") != "twin":
			for s: int in [-1, 1]:
				var h2 := head + across * (2 * s)
				if _free_cell(g, of, ri, head + across * s, taken, forbid) and _free_cell(g, of, ri, h2, taken, forbid, true) \
						and _free_cell(g, of, ri, h2 - d, taken, forbid, true):
					score += 2.0
					break
		if not taste.is_empty():
			if taste["back"] == d:
				score += LEAN_BONUS
			score += GRAIN * _grain(r, int(taste["salt"]))
		match item.get("near", ""):
			"far_door":
				score += 0.3 * _dist_to(r, doors_in)
			"twin":
				var heads: Array = item.get("near_cells", [])
				var dirs: Array = item.get("near_dirs", [])
				for i in range(heads.size()):
					if dirs[i] == d:
						var gap: Vector2i = heads[i] - head
						score += 3.0 if gap == across * 2 or gap == across * -2 else 1.0
		if best.is_empty() or score > float(best["score"]):
			best = {"rect": r, "facing": facing, "score": score, "head": d}
	return best


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
		forbid: Dictionary, taken: Dictionary, doors_in: Array, stove_cells: Array, box_at: Dictionary, k: int = TOP_CANDIDATES,
		taste: Dictionary = {}) -> Array:
	var size: Vector2i = item["size"]
	var tall: bool = size.x * size.y >= 2 or TALL_KINDS.has(String(item["kind"]))
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
						if _at(g, of, c) != ri or g.solid_at(c) != S.NONE or taken.has(c) or f == "all" or (tall and f == "tall") \
								or (f == "stand" and item.get("near", "") != "bed_head"):
							fits = false
						elif box_at.has(c) and not holds:
							fits = false
				if not fits:
					continue
				if item.get("near", "") == "bed_head" and not item.get("near_cells", []).has(r.position):
					continue
				if item.get("at", "wall") == "head":
					var spot := _head_spot(g, of, ri, r, item, forbid, taken, doors_in, taste)
					if not spot.is_empty():
						_keep_top(out, spot, k)
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
					score += 5.0 if item.get("corner", false) else 1.0
				if item.get("at", "wall") == "mid" and walls == 0:
					score += 2.0
				if not taste.is_empty():
					if ANCHOR_KINDS.has(String(item["kind"])) and backs.has(taste["back"]):
						score += LEAN_BONUS
					score += GRAIN * _grain(r, int(taste["salt"]))
				match item.get("near", ""):
					"far_door":
						score += 0.3 * _dist_to(r, doors_in)
					"door":
						score -= 0.5 * _dist_to(r, doors_in)
					"stove":
						if not stove_cells.is_empty():
							score -= 0.5 * _dist_to(r, stove_cells)
					"desk":
						if not item.get("near_cells", []).is_empty():
							score -= 2.0 * _dist_to(r, item["near_cells"])
					"bed_head":
						# 두 베개 곁인 칸(홑침대 둘 사이)이 먼저.
						score += 2.0 * (item.get("near_cells", []).count(r.position) - 1)
				_keep_top(out, {"rect": r, "facing": facing, "score": score}, k)
	return out


## 그 집 가구의 색 판 번호(0~TINT_SETS-1). 지도와 건물로 정해져 판마다 같다.
## String.hash()(djb2)는 번호가 1 바뀌면 값이 고정 간격만 바뀌어 판이 차례로 돌거나 몰리므로,
## PCG로 섞은 뒤 고른다(furniture_tints.roll과 같이).
static func tint_for(place: String, building: int) -> int:
	return int(rand_from_seed(("%s|%d|tint" % [place, building]).hash())[0]) % TINT_SETS


## 방의 결: 자리(꼴과 칸)마다 0~1의 정해진 값. 같은 방은 늘 같다.
static func _grain(r: Rect2i, salt: int) -> float:
	return float(hash([r.position.x, r.position.y, r.size.x, r.size.y, salt]) % 1000) / 1000.0


## 방의 배치 틀 씨앗. rng와 따로라 묶음 고르기·목표 몫은 바꾸지 않는다.
static func look_seed_of(place: String, building: int, lv: int, ri: int) -> int:
	return ("%s|%d|%d|%d|look" % [place, building, lv, ri]).hash() & 0x7fffffff


## 배치 틀·깔개의 굴림 하나(0 이상): 씨앗과 쓰임 번호(ROLL_*)를 PCG로 섞는다. String.hash()(djb2)의
## 비트를 잘라 쓰면 방 번호가 1 늘 때 낮은 비트도 1씩 늘어 이웃 방이 기댈 벽을 차례로 돌고, 쓰임끼리
## 같은 비트를 나눠 써서 서로 따라간다.
static func _roll(base: int, purpose: int) -> int:
	return int(rand_from_seed(hash([base, purpose]))[0])


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
static func _hang_curtains(g: FieldGrid, cells: Array[Vector2i]) -> void:
	for c in cells:
		for d in DIRS:
			var n: Vector2i = c + d
			if g.windows.has(n) and not g.windows[n].has("curtain"):
				g.windows[n]["curtain"] = "open"


## 이어진 벽 줄 전체를 먼저 시험한다. ㄱ자도 후보지만 모서리 가구 앞에 설 수
## 없으면 기존 길 검사에서 거절한다. 그때는 일자나 더 짧은 줄을 고른다.
static func _kitchen_run(g: FieldGrid, of: PackedInt32Array, ri: int, cells: Array[Vector2i],
		forbid: Dictionary, taken: Dictionary, box_at: Dictionary, keys: Dictionary, before: Dictionary,
		guard: Array, available: int, salt: int = -1) -> Array:
	var usable: Dictionary = {}
	for c in cells:
		if g.solid_at(c) == S.NONE and not taken.has(c) and forbid.get(c, "") != "all" and _wall_sides(g, of, ri, Rect2i(c, Vector2i.ONE)) > 0:
			usable[c] = true
	var target := mini(available, clampi(roundi(cells.size() / 3.0), COUNTER_MIN, COUNTER_MAX))
	for length in range(target, COUNTER_MIN - 1, -1):
		var candidates: Array = []
		for start: Vector2i in usable:
			for direction in DIRS:
				for turn_at in range(1, length):
					for turn in [-1, 0, 1]:
						if turn == 0 and turn_at != 1:
							continue
						var line: Array[Vector2i] = [start]
						var d := direction
						for i in range(1, length):
							if i == turn_at and turn != 0:
								d = Vector2i(-direction.y, direction.x) * turn
							var c: Vector2i = line.back() + d
							if not usable.has(c) or line.has(c):
								break
							line.append(c)
						if line.size() != length or box_at.has(line[0]) or box_at.has(line[-1]):
							continue
						var score := _wall_sides(g, of, ri, Rect2i(start, Vector2i.ONE)) * 4.0 + float(turn != 0)
						if salt >= 0:
							score += 2.0 * GRAIN * _grain(Rect2i(start, line[-1] - start), salt)
						candidates.append({"line": line, "score": score})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
		for candidate: Dictionary in candidates:
			var line: Array[Vector2i] = candidate["line"]
			var rects: Array = []
			for c in line:
				g.set_solid(c, S.LOW)
				rects.append(Rect2i(c, Vector2i.ONE))
			if _still_open(g, of, ri, keys, before, rects + guard):
				var out: Array = []
				# 난로와 개수대는 방마다 어느 끝에 설지 굴린다.
				var flip := salt >= 0 and _roll(salt, ROLL_RUN_END) & 1 == 1
				for i in range(line.size()):
					var at := line.size() - 1 - i if flip else i
					var kind: String = "cold_stove" if at == 0 else ("sink" if at == line.size() - 1 else "counter")
					var r: Rect2i = rects[i]
					var facing := 0
					for d in DIRS:
						if _wall_side(g, of, ri, r, d):
							facing = _facing_from_back(d)
							break
					out.append({"item": {"kind": kind, "size": Vector2i.ONE, "holds": kind == "counter", "need": true, "run": true}, "rect": r, "facing": facing})
				return out
			for c in line:
				g.set_solid(c, S.NONE)
	return []


static func furnish_rooms(data: Dictionary) -> Dictionary:
	var stats := {"rooms": 0, "placed": 0, "need_missing": 0, "boxes_in": 0, "boxes_near": 0, "missing": {}}
	if not data.has("low_blocks"):
		data["low_blocks"] = []
	var plan := density_plan(data)
	# 남길 지도 가구의 문 앞 잘못된 자리를 먼저 고친다. 새 가구가 그 가구의
	# 피할 자리를 먼저 차지해서 문 앞에 남겨 두는 일이 없도록 한다.
	stats["pre_fronts"] = clear_fronts(data)
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
	var tint_of: Dictionary = {}  # 방 안 지도 가구 줄 번호 -> 그 집 칠 판
	var lvs: Array = levels.keys()
	lvs.sort()
	data["density_classes"] = plan["classes"]
	data["density_baths"] = plan["baths"]
	var twins := _twin_rooms(data, plan, levels, place)
	for lv: int in lvs:
		var g: FieldGrid = levels[lv]
		var stairs: Dictionary = stairs_by.get(lv, {})
		var map := _rooms(data, lv, g)
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
				tint_of[i] = tint_for(place, int(map["rooms"][ri]["building"]))
			elif g.building_at(rect.position + rect.size / 2) >= 0:
				tint_of[i] = tint_for(place, g.building_at(rect.position + rect.size / 2))
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
		# 방 이름은 가구 메모에서, 없으면 방 안 이름표에서 읽는다. 둘 다 없는 빈 방은 건물 이름으로.
		var labels := _room_labels(data, lv, g, of)
		for ri in range(map["rooms"].size()):
			var idxs: Array = in_room.get(ri, [])
			var room: Dictionary = map["rooms"][ri]
			var cells: Array[Vector2i] = room["cells"]
			var kinds: Dictionary = {}
			for i: int in idxs:
				kinds[String(props[i].get("kind", ""))] = true
			var name := _note_name(props, idxs)
			if name.is_empty():
				name = labels.get(ri, "")
			var cls: String = plan["classes"].get("%d:%d" % [lv, ri], "")
			if cls.is_empty() or (cls != "bath" and cells.size() < ROOM_MIN_CELLS):
				continue
			changed = true
			# A home room's windows have curtains (J08; building_rules draws some).
			if BuildingRules.CURTAIN_CLASSES.has(cls):
				_hang_curtains(g, cells)
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
			# 남긴 지도 가구 가운데 몸을 막을 것(뒤에 block_furniture가 칠한다)을 이 방을 채우는
			# 동안만 막는 칸으로 칠해 둔다. 새 가구가 그 앞을 막지 않게 지킨다(_standing).
			var held: Array[Vector2i] = []
			for i: int in idxs:
				var hk := String(props[i].get("kind", ""))
				if drop.has(i) or REPLACED.has(hk) or not blocks(hk, lv):
					continue
				var hr: Rect2i = _rect(props[i].get("rect"))
				for y in range(hr.position.y, hr.end.y):
					for x in range(hr.position.x, hr.end.x):
						var hc := Vector2i(x, y)
						if _at(g, of, hc) == ri and g.solid_at(hc) == S.NONE:
							g.set_solid(hc, S.LOW)
							held.append(hc)
			var keys := _keys(g, of, ri, cells, stairs, box_cells)
			var before := _from_first(g, of, ri, keys)
			var guard := _standing(g, of, ri, kept_rects, before)
			var forbid := _forbidden(g, of, ri, cells, stairs)
			var rng := RandomNumberGenerator.new()
			rng.seed = ("%s|%d|%d|%d" % [place, int(room["building"]), lv, ri]).hash()
			# 배치 틀: rng를 쓰지 않아 묶음 고르기·목표 몫은 그대로다.
			var look_seed := look_seed_of(place, int(room["building"]), lv, ri)
			var taste: Dictionary = {"back": DIRS[_roll(look_seed, ROLL_BACK) % DIRS.size()], "salt": look_seed} if LAYOUT_CLASSES.has(cls) else {}
			var area := cells.size()
			var used := 0
			for c: Vector2i in taken:
				if _at(g, of, c) == ri:
					used += 1
			var density: Array = DENSITY[cls]
			var cap := int(floor(area * float(density[2])))
			var floor_min: float = density[3]
			var target := int(ceil(area * rng.randf_range(density[0], density[1])))
			var placed: Array = []
			var rects: Array = []
			var stove_cells: Array = []
			var holders := 0
			if cls == "kitchen":
				placed = _kitchen_run(g, of, ri, cells, forbid, taken, box_at, keys, before, guard, cap - used, look_seed)
				if placed.is_empty():
					_missing(stats, cls, {"kind": "counter_run"}, "spot_or_path")
				for pl: Dictionary in placed:
					var r: Rect2i = pl["rect"]
					rects.append(r)
					taken[r.position] = true
					used += 1
					holders += int(pl["item"].get("holds", false))
					if pl["item"]["kind"] == "cold_stove":
						stove_cells.append(r.position)
			# 지도의 담는 가구(궤, 약품 상자 등)가 남은 방은 담는 가구를 이미 가졌다. 창고·저장 칸은
			# 쌓아 둔 짐(석탄 더미, 연료통, 자루)이 곧 담는 것이다.
			var kept_holder := false
			var piles: bool = cls in ["storage", "store", "barn", "woodshed"]
			for i: int in idxs:
				var kk := String(props[i].get("kind", ""))
				if not drop.has(i) and (HOLDER_KINDS.has(kk) or (piles and not PASS_KINDS.has(kk))):
					kept_holder = true
			# 남긴 가구가 대신하는 꼭 있을 가구(이층 침대는 침대).
			var covered: Dictionary = {}
			for i: int in idxs:
				var kk := String(props[i].get("kind", ""))
				if not drop.has(i):
					covered[STANDS_FOR.get(kk, kk)] = true
			var items := _palette_for(cls, area, rng)
			# 넓은 침실: 침대는 머리-벽 자리부터, 협탁은 짝으로도, 굴림이 맞으면 홑침대 둘.
			var wide: bool = cls == "bed" and _wide_bedroom(cells)
			if wide:
				items = _wide_bed_items(items, twins.has("%d:%d" % [lv, ri]))
			# 부엌을 갈라 뗀 식당(room_split DINING)은 거실 묶음의 꼭 있을 가구 다음에 식탁을 꼭 둔다.
			var dining: bool = cls == "living" and _named(String(labels.get(ri, "")), "식당")
			if dining:
				var at := 0
				while at < items.size() and bool((items[at] as Dictionary).get("need", false)):
					at += 1
				items.insert(at, {"kind": "dining_set", "size": Vector2i(2, 2), "need": true, "at": "mid"})
			for item: Dictionary in items:
				if covered.has(item["kind"]) or (item.get("fill", false) and used >= target):
					continue
				if item.get("near", "") == "desk":
					item["near_cells"] = []
					for pl: Dictionary in placed:
						if pl["item"]["kind"] == "desk":
							item["near_cells"].append((pl["rect"] as Rect2i).position)
				elif item.get("near", "") == "bed_head":
					item["near_cells"] = []
					for pl: Dictionary in placed:
						if pl["item"]["kind"] == "bed":
							item["near_cells"].append_array(_bedsides(g, of, ri, pl["rect"], int(pl["facing"]), pl.has("head")))
				elif item.get("near", "") == "twin":
					item["near_cells"] = []
					item["near_dirs"] = []
					for pl: Dictionary in placed:
						if pl["item"]["kind"] == "bed":
							item["near_cells"].append(bed_head(pl["rect"], int(pl["facing"])))
							item["near_dirs"].append(pl.get("head", Vector2i.ZERO))
				var need: bool = item.get("need", false)
				if need and item.get("holds", false) and kept_holder and cls in ["storage", "store", "shop", "work", "garage", "barn"]:
					need = false
				# 꼭 있을 것은 자리가 없으면 한 칸씩 짧은 꼴로, 그래도 없으면 벽에서 떨어져서 찾는다.
				var variants: Array = [item]
				# 넓은 침실의 침대는 머리-벽 자리를 먼저 보고, 없으면 긴 변을 벽에.
				if item.get("head_first", false):
					var hv: Dictionary = item.duplicate()
					hv["at"] = "head"
					hv.erase("corner")
					variants.push_front(hv)
				if need:
					var size0: Vector2i = item["size"]
					var shortest := 2 if item["kind"] == "bed" else 1
					for n in range(maxi(size0.x, size0.y) - 1, shortest - 1, -1):
						var v: Dictionary = item.duplicate()
						v["size"] = Vector2i(n, mini(size0.x, size0.y))
						variants.append(v)
					if item.get("at", "wall") == "wall" and cls not in ["bed", "bath"]:
						var m: Dictionary = item.duplicate()
						m["at"] = "mid"
						variants.append(m)
				var ok := false
				var why := ""
				for v: Dictionary in variants:
					var size: Vector2i = v["size"]
					var a := size.x * size.y
					if used + a > cap or float(area - used - a) < area * floor_min:
						why = "space"
						continue
					var cands := _candidates(g, of, ri, cells, v, forbid, taken, keys["seeds"], stove_cells, box_at,
						HEAD_CANDIDATES if v.get("at", "") == "head" else (TOP_CANDIDATES_NEED if need else TOP_CANDIDATES), taste)
					if cands.is_empty():
						why = "spot"
						continue
					var tries: Array = []
					var top := 1 if v.get("corner", false) else mini(3, cands.size())
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
							if cand.has("head"):
								placed[-1]["head"] = cand["head"]
								# 베개 양옆 두 칸은 협탁 자리로 남긴다(다른 가구·채우기가 먼저 차지하지 않게). 홑침대 둘 방은
								# 둘째 침대가 선 뒤 두 베개 사이 한 칸만.
								var keep: Array[Vector2i] = []
								if not v.get("twin_room", false):
									keep = _bedsides(g, of, ri, r, int(cand["facing"]), true)
								elif v.get("twin", false):
									var h2 := bed_head(r, int(cand["facing"]))
									for pl0: Dictionary in placed.slice(0, placed.size() - 1):
										if pl0["item"]["kind"] == "bed" and pl0.has("head"):
											var h1 := bed_head(pl0["rect"], int(pl0["facing"]))
											if (h2 - h1).length_squared() == 4 and (h1.x == h2.x or h1.y == h2.y):
												keep.append((h1 + h2) / 2)
								for side_c: Vector2i in keep:
									if forbid.get(side_c, "") != "all":
										forbid[side_c] = "stand"
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
			# 목표 몫 채우기(결정 469 F2): 묶음만으로 목표 몫에 못 미치면 FILL 차례로 더 놓는다. 길·문·계단
			# 검사로 깎인 자리는 다른 벽에서 찾는다. 상한·빈 바닥 하한은 그대로, 한 번 못 선 종류는 다시 보지 않는다.
			var stuck: Dictionary = {}
			var adding := true
			while used < target and adding:
				adding = false
				for source: Dictionary in FILL.get(cls, []):
					var kind: String = source["kind"]
					if used >= target or stuck.has(kind):
						continue
					if ONE_PER_ROOM.has(kind) and (covered.has(kind) or placed.any(func(pl: Dictionary) -> bool: return pl["item"]["kind"] == kind)):
						continue
					var size: Vector2i = source["size"]
					var a := size.x * size.y
					if used + a > cap or float(area - used - a) < area * floor_min:
						stuck[kind] = true
						continue
					var v: Dictionary = source.duplicate()
					v["fill"] = true
					var cands := _candidates(g, of, ri, cells, v, forbid, taken, keys["seeds"], stove_cells, box_at, TOP_CANDIDATES, taste)
					var cand := {} if cands.is_empty() else _first_open(g, of, ri, keys, before, guard, rects, cands, rng.randi_range(0, mini(3, cands.size()) - 1))
					if cand.is_empty():
						stuck[kind] = true
						continue
					var r: Rect2i = cand["rect"]
					placed.append({"item": v, "rect": r, "facing": cand["facing"]})
					for y in range(r.position.y, r.end.y):
						for x in range(r.position.x, r.end.x):
							taken[Vector2i(x, y)] = true
					used += a
					holders += int(v.get("holds", false))
					adding = true
			var rug := _lay_rug("dining" if dining else cls, cells, placed, stairs, look_seed)
			if not rug.is_empty():
				rug["level"] = lv
				rug["building"] = int(room["building"])
				data.get_or_add("rugs", []).append(rug)
			# 상자: 가까운 용기 가구로, 가구 하나에 하나. 그 가구 칸 가운데 바로 앞이
			# 걸어서 닿는 칸에 둔다. 들 가구가 없고 원래 칸이 가구에 덮였으면 닿는 바닥으로.
			# 상자 자리는 예전처럼 남긴 가구를 칠하기 전 칸으로 본다.
			for hc in held:
				g.set_solid(hc, S.NONE)
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
				# 위층의 모델 없는 새 가구는 계획 중에만 막는다. 보이지 않는 벽을 남기지 않는다.
				if not blocks(kind, lv):
					for y in range(r.position.y, r.end.y):
						for x in range(r.position.x, r.end.x):
							g.set_solid(Vector2i(x, y), S.NONE)
				added.append({"kind": kind, "rect": r, "solid": "low", "facing": pl["facing"],
					"note": "%s의 %s" % [label, KIND_LABEL.get(kind, kind)], "level": lv,
					"building": int(room["building"]), "rule": cls, "counter_run": pl["item"].get("run", false),
					"tint": tint_for(place, int(room["building"]))})
				# 식당 마감(room_finish DINING): 거실 묶음이라 rule만으로는 그냥 거실과 갈리지 않는다.
				if dining:
					added[-1]["dining"] = true
				# 홑침대 둘의 둘째 침대(침실의 침대 수를 셀 때 가른다).
				if pl["item"].get("twin", false):
					added[-1]["twin"] = true
				if lv == 0:
					new_ground.append(r)
			stats["rooms"] += 1
			stats["placed"] += placed.size()
			if cls == "bed":
				stats["bedrooms"] = int(stats.get("bedrooms", 0)) + 1
				stats["wide_bedrooms"] = int(stats.get("wide_bedrooms", 0)) + int(wide)
				for pl: Dictionary in placed:
					stats["head_beds"] = int(stats.get("head_beds", 0)) + int(pl["item"]["kind"] == "bed" and pl.has("head"))
					stats["twins"] = int(stats.get("twins", 0)) + int(pl["item"].get("twin", false))
					stats["stand_pairs"] = int(stats.get("stand_pairs", 0)) + int(pl["item"].get("pair", false))
		if changed and not data.get("_defer_paths", false):
			g.refresh_paths()
	var out: Array = []
	for i in range(props.size()):
		if not drop.has(i):
			# 지도가 둔 가구도 그 집의 새 가구와 한 칠 판(map_view의 FurnitureTints.pick은 tint를 먼저 읽는다).
			var row: Dictionary = props[i]
			if tint_of.has(i) and not row.has("tint"):
				row = row.duplicate()
				row["tint"] = tint_of[i]
			out.append(row)
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


## 깔개 하나(room_finish 깔개 칸): 침대는 양옆으로 한 칸씩 넓게 그 밑에, 식탁은 둘레 한 칸 넓게,
## 거실은 낮은 탁자 둘레, 없으면 방 가운데. 방 칸을 벗어나는 줄은 깎고, 2×2보다 작으면 깔지 않는다.
## 납작해서 길·문 앞을 막지 않는다(걷는 길 검사 밖). 계단 칸은 덮지 않는다. {} 이면 없음.
static func _lay_rug(cls: String, cells: Array[Vector2i], placed: Array, stairs: Dictionary, salt: int) -> Dictionary:
	if float(_roll(salt, ROLL_RUG) % 1000) / 1000.0 >= float(RUG_CHANCE.get(cls, 0.0)):
		return {}
	var inside: Dictionary = {}
	var lo := cells[0]
	var hi := cells[0]
	for c in cells:
		if not stairs.has(c):
			inside[c] = true
		lo = lo.min(c)
		hi = hi.max(c)
	var core := Rect2i()
	for want: String in (["dining_set"] if cls == "dining" else (["bed"] if cls == "bed" else ["low_table", "dining_set", "settee"])):
		for pl: Dictionary in placed:
			if core.size == Vector2i.ZERO and String(pl["item"]["kind"]) == want:
				core = pl["rect"]
	var rug: Rect2i
	if core.size == Vector2i.ZERO:
		var mid := (lo + hi) / 2
		rug = Rect2i(mid - Vector2i.ONE, Vector2i(3, 2) if hi.x - lo.x >= hi.y - lo.y else Vector2i(2, 3))
	elif cls == "bed":
		rug = core.grow_individual(0, 1, 0, 1) if core.size.x >= core.size.y else core.grow_individual(1, 0, 1, 0)
	else:
		rug = core.grow(1)
	# 방 밖으로 나간 변을 깎는다: 바깥 칸이 가장 많은 변부터.
	for _i in range(8):
		var out := [0, 0, 0, 0]  # 왼·오른·위·아래 변의 바깥 칸
		for y in range(rug.position.y, rug.end.y):
			for x in range(rug.position.x, rug.end.x):
				if not inside.has(Vector2i(x, y)):
					out[0] += int(x == rug.position.x)
					out[1] += int(x == rug.end.x - 1)
					out[2] += int(y == rug.position.y)
					out[3] += int(y == rug.end.y - 1)
		var worst := 0
		for side in range(4):
			if out[side] > out[worst]:
				worst = side
		if out[worst] == 0:
			break
		rug = rug.grow_individual(-int(worst == 0), -int(worst == 2), -int(worst == 1), -int(worst == 3))
		if rug.size.x < 2 or rug.size.y < 2:
			return {}
	if rug.size.x < 2 or rug.size.y < 2:
		return {}
	for y in range(rug.position.y, rug.end.y):
		for x in range(rug.position.x, rug.end.x):
			if not inside.has(Vector2i(x, y)):
				return {}
	var weaves: Array = RUG_WEAVES[cls]
	return {"rect": rug, "look": 1 + int(weaves[_roll(salt, ROLL_WEAVE) % weaves.size()]) * 32 + _roll(salt, ROLL_RUG_LOOK) % 32}


## 후보 가운데 pick 번째를 먼저, 나머지는 차례로 세워 보고 길이 남는 첫 자리. 그 자리는 칸을 막고
## rects에 든 채로 돌려준다. 없으면 빈 사전(칸과 rects는 처음 그대로).
static func _first_open(g: FieldGrid, of: PackedInt32Array, ri: int, keys: Dictionary, before: Dictionary, guard: Array,
		rects: Array, cands: Array, pick: int) -> Dictionary:
	var tries: Array = [cands[pick]]
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
			return cand
		rects.pop_back()
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				g.set_solid(Vector2i(x, y), S.NONE)
	return {}


const ROOM_LABEL: Dictionary = {"bed": "살림방", "kitchen": "부엌", "living": "거실", "bath": "욕실", "office": "사무실", "shop": "매장", "storage": "창고", "store": "저장 칸", "boiler": "보일러실",
	"work": "작업실", "garage": "차고", "barn": "헛간", "woodshed": "장작 헛간"}
const KIND_LABEL: Dictionary = {
	"bed": "침대", "wardrobe": "장롱", "blanket_chest": "담요 궤", "bookcase": "책장", "bench": "긴 의자",
	"cold_stove": "꺼진 난로", "jar_shelf": "항아리 선반", "dining_set": "식탁과 의자", "fridge_open": "문 열린 냉장고",
	"barrel": "통", "radio_set": "라디오", "shop_counter": "계산대", "display_shelf": "진열 선반",
	"crate_stack": "상자 더미", "shelf": "선반", "sack_pile": "자루 더미", "tin_crate": "나무 궤",
	"firebox": "보일러 화실", "coal_bin": "석탄함", "fuel_drum": "연료통", "toolbox": "공구함",
	"dresser": "서랍장", "chair": "의자", "nightstand": "침대 곁 협탁", "counter": "조리대", "sink": "개수대",
	"cupboard": "찬장", "settee": "긴 소파", "armchair": "안락의자", "low_table": "낮은 탁자", "side_table": "곁탁자",
	"toilet": "변기", "washstand": "세면대", "bathtub": "욕조", "towel_shelf": "수건 선반", "medicine_cabinet": "약장", "waste_bin": "휴지통", "small_shelf": "작은 선반", "file_cabinet": "서류장", "desk": "책상",
	"workbench": "작업대", "tool_rack": "연장 걸이", "tool_chest": "공구 궤", "parts_rack": "부품 선반", "part_crate": "부품 상자",
	"sawhorse": "모탕", "car": "자동차", "tire_stack": "타이어 더미", "fuel_can_group": "기름통", "hardware_rack": "철물 선반",
	"hay_cart": "건초 수레", "farm_cart": "짐수레", "firewood_stack": "장작 더미", "firewood_rick": "장작 단",
}


## ---------------------------------------------------------------- 가구 속 상자(1장 「가구가 곧 용기」)

## 상자가 들어갈 수 있는 가구(장, 선반, 궤, 책상, 계산대, 상자 더미 등).
const HOLDER_KINDS: Dictionary = {
	"dresser": true, "nightstand": true, "counter": true, "cupboard": true, "side_table": true, "washstand": true, "towel_shelf": true, "small_shelf": true, "medicine_cabinet": true, "waste_bin": true,
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
	var stats := {"keyed": 0, "kitchen_added": 0, "spare_added": 0}
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
		var map := _rooms(data, lv, g)
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
		var seen_of: Dictionary = {}  # 방 -> 걸어서 닿는 칸(상자는 칸을 막지 않으니 방마다 한 번)
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
			if not seen_of.has(ri):
				var room: Dictionary = map["rooms"][ri]
				seen_of[ri] = _from_first(g, of, ri, _keys(g, of, ri, room["cells"], stairs_by.get(lv, {}), []))
			var seen: Dictionary = seen_of[ri]
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
		# The room each box stands in, as a key loot_dress.gd room_of reads before the box's name.
		# A key the map gave is kept; a room of no known kind gets none; a box whose name says its
		# room in loot_dress.gd's words (부엌 찬장, 매장 상자, 작업실 상자) keeps that, so what it
		# holds never belies its name. 「창고」 is no such word there: a 창고 상자 takes the key.
		var keys := _room_keys(data, lv, g, map, of)
		var in_room: Dictionary = {}  # room -> boxes in it
		for id: String in ids:
			var box: Dictionary = containers[id]
			var bc: Variant = _cell(box.get("cell"))
			if int(box.get("level", 0)) != lv or bc == null:
				continue
			var ri := _at(g, of, bc)
			in_room[ri] = int(in_room.get(ri, 0)) + 1
			var key: String = keys.get(ri, "")
			if not key.is_empty() and not box.has("room") and not _name_places(String(box.get("name", ""))):
				box["room"] = key
				stats["keyed"] += 1
		# A home room's spare furniture that opens gets an empty box each: the kitchen's counters,
		# cupboards and fridge, and (card R2) the bathroom's cabinet and washstand, the bedroom's
		# nightstand, dresser and wardrobe, the living room's bookcase and side table. The place's
		# bundles are dealt over the boxes by room when the stop opens (loot_dress.gd, the odds and
		# ends by room share in loot_junk.gd), so more places to open, the same things in all. One
		# box to a cell, so no two boxes share the spot a finger presses.
		var spots: Dictionary = {}
		for id: String in ids:
			var box: Dictionary = containers[id]
			if int(box.get("level", 0)) == lv and _cell(box.get("cell")) != null:
				spots[_cell(box.get("cell"))] = true
		for ri: int in holders_of:
			var key: String = keys.get(ri, "")
			if not SPARE.has(key):
				continue
			var list: Array = holders_of[ri]
			for k in range(list.size()):
				var kind: String = list[k][1]
				if int(in_room.get(ri, 0)) >= int(SPARE_MOST[key]):
					break
				if used.has(Vector3i(lv, ri, k)) or not SPARE[key].has(kind):
					continue
				if not seen_of.has(ri):
					var room: Dictionary = map["rooms"][ri]
					seen_of[ri] = _from_first(g, of, ri, _keys(g, of, ri, room["cells"], stairs_by.get(lv, {}), []))
				var r: Rect2i = list[k][0]
				var spot := _front_cell(r, seen_of[ri], r.position)
				var id := "%s_%d_%d_%d" % ["kitchen" if key == "kitchen" else "spare", lv, ri, k]
				if spot.x < 0 or spots.has(spot) or containers.has(id):
					continue
				containers[id] = {"id": id, "name": KIND_LABEL.get(kind, kind), "cell": spot, "level": lv,
					"building": int(map["rooms"][ri]["building"]), "search": KITCHEN_SEARCH, "items": [], "locked": false,
					"searched": false, "furniture": kind, "room": key}
				used[Vector3i(lv, ri, k)] = true
				spots[spot] = true
				in_room[ri] = int(in_room.get(ri, 0)) + 1
				stats["kitchen_added" if key == "kitchen" else "spare_added"] += 1
	data["box_rooms"] = stats
	return moved


static func _name_places(name: String) -> bool:
	return LootDress.room_of({"name": name}) != "storage"


## A box in a piece of furniture whose name says another room (a map's 「부엌 상자」 moved into
## the wardrobe of a room laid out again, a 「매장 상자」 in an upstairs dresser) takes the
## piece's name, so the bag's tab says what was opened. Its key becomes the piece's room, the
## room loot_dress.gd reads a box in a piece by anyway (room_of_box), so what it holds is the
## same. The ring's boxes are filled by their names (loot_rules.gd fill), so the ring calls
## this after its fill (map_ring.gd). Returns how many were renamed.
static func name_boxes_by_furniture(data: Dictionary) -> int:
	var renamed := 0
	var containers: Variant = data.get("containers", {})
	if not containers is Dictionary:
		return 0
	for id: String in containers:
		var box: Dictionary = containers[id]
		var kind := String(box.get("furniture", ""))
		var room := String(LootDress.FURNITURE_ROOM.get(kind, ""))
		var says := LootDress.room_of_name(String(box.get("name", "")))
		if room.is_empty() or not KIND_LABEL.has(kind) or says == "storage" or says == room or box.get("name") == KIND_LABEL[kind]:
			continue
		if not box.has("room"):
			box["room"] = room
		box["name"] = KIND_LABEL[kind]
		renamed += 1
	return renamed


## Kitchen furniture that opens: an empty box goes in each one no box is in yet, until the
## kitchen has KITCHEN_MOST places to open (the reference kitchen has some 8 to 12).
const KITCHEN_SPARE: Dictionary = {"counter": true, "cupboard": true, "fridge_open": true}
const KITCHEN_MOST: int = 10
## The same for a home's other rooms (card R2, decision 469: some 12 to 20 places to open a home),
## by room key (ROOM_KEYS: a living room deals as a bedroom, a dining room as the kitchen it was
## cut from, so its living-room pieces open too). The most a room gets is what one taps apart.
const SPARE: Dictionary = {
	"kitchen": {"counter": true, "cupboard": true, "fridge_open": true, "side_table": true, "bookcase": true},
	"bathroom": {"medicine_cabinet": true, "washstand": true, "towel_shelf": true, "waste_bin": true},
	"bedroom": {"nightstand": true, "dresser": true, "wardrobe": true, "blanket_chest": true, "bookcase": true, "side_table": true},
}
const SPARE_MOST: Dictionary = {"kitchen": KITCHEN_MOST, "bathroom": 3, "bedroom": 1}
## Seconds to search one of those (card L, decision 442): half a map box's 4, so opening all
## of a stop's adds some 36 s, not 73 (after the box-size factor: cupboard 1.5 s, counter 2 s).
const KITCHEN_SEARCH: float = 2.0
## Room kind (room_class) -> the room key loot_dress.gd deals by. A living room deals as a
## bedroom (loot-feel: its hall is a chapel's, nearly every pull 0.3), the store a pantry.
const ROOM_KEYS: Dictionary = {"kitchen": "kitchen", "bed": "bedroom", "living": "bedroom", "bath": "bathroom",
	"store": "pantry", "storage": "storage", "shop": "shop", "office": "office", "boiler": "toolbox",
	"work": "toolbox", "garage": "toolbox", "barn": "storage", "woodshed": "storage"}


## The room key of a room: a closet, pantry or dining room split off (room_split.gd) by its
## hidden name, then its kind, then words in its name, then its building's role. A dining room
## deals as the kitchen it was cut from (loot-feel: one kitchen share for the home).
static func room_key(cls: String, words: String, role: String) -> String:
	if _named(words, "벽장"):
		return "bedroom"
	if _named(words, "찬방"):
		return "pantry"
	if _named(words, "식당"):
		return "kitchen"
	if ROOM_KEYS.has(cls):
		return ROOM_KEYS[cls]
	for word: String in ["진료", "병실", "약"]:
		if _named(words, word):
			return "clinic"
	for word: String in ["작업", "공구", "공방"]:
		if _named(words, word):
			return "toolbox"
	if role in ["shop", "shopmain", "market"]:
		return "shop"
	if role == "office":
		return "office"
	return ""


## Room number -> room key on one level.
static func _room_keys(data: Dictionary, lv: int, g: FieldGrid, map: Dictionary, of: PackedInt32Array) -> Dictionary:
	var classes: Dictionary = data.get("density_classes", {})
	var props: Array = data.get("props", [])
	var labels := _room_labels(data, lv, g, of)
	var in_room := _props_by_room(g, of, props, lv)
	var roles: Dictionary = {}
	for b: Variant in data.get("buildings", []):
		if b is Dictionary:
			roles[int(b.get("id", -1))] = String(b.get("role", ""))
	var out: Dictionary = {}
	for ri in range(map["rooms"].size()):
		var words := "%s %s" % [labels.get(ri, ""), _note_name(props, in_room.get(ri, []))]
		var key := room_key(String(classes.get("%d:%d" % [lv, ri], "")), words, String(roles.get(int(map["rooms"][ri]["building"]), "")))
		if not key.is_empty():
			out[ri] = key
	return out
