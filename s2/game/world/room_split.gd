extends RefCounted
## 가구를 놓기 전, 살림집의 넓은 방에서 욕실과 작은 수납 칸을 떼어 내고(모서리에서 이어진 한 줄,
## 필요하면 ㄱ자), 그래도 큰 방은 곧은 칸막이 한 줄로 둘로 가른다(결정 469 F1). 문은 칸막이마다 하나다.
## 가게 위층의 살림집도 그 층부터 같은 규칙을 따른다.
const Grid = preload("res://game/world/field_grid.gd")
const Furnish = preload("res://game/world/room_furnish.gd")
const PropFit = preload("res://game/world/prop_fit.gd")
const S = Grid.Solid
const DIRS = Furnish.DIRS
const BED_LIMIT := 30
const KITCHEN_LIMIT := 36
const MIN_REMAINDER := 12
const DOOR_HP := 8
## 욕실 크기 차례(결정 469 F4): 문 앞 곧은 두 칸을 비우고도 변기·세면대·약장·휴지통 넷이 서도록 2×4·3×3을 먼저.
const BATH_SIZES := [Vector2i(2, 4), Vector2i(4, 2), Vector2i(3, 3), Vector2i(3, 4), Vector2i(4, 3), Vector2i(2, 3), Vector2i(3, 2)]
const STORE_SIZES := [Vector2i(1, 2), Vector2i(2, 1)]
const NON_HOME := ["가게", "매장", "상점", "매점", "빵집", "식료", "철물", "잡화", "사무", "관청", "공장", "공방", "병원", "진료", "교회", "성당", "창고", "헛간", "차고", "세탁", "우물집"]
## 위층에 살림집을 이고 있는 가게(이름 낱말 또는 지도 선언의 role).
const SHOP_WORDS := ["가게", "매장", "상점", "매점", "빵집", "식료", "철물", "잡화"]
const SHOP_ROLES := ["shop", "shopmain", "market"]
## 큰 방 가르기(결정 469 F1, 참고 실측 가운데값 침실 14~18·부엌 15·거실 25~30칸): 이 넓이를 넘는 방을
## 가르고, 가른 두 쪽은 아래 넓이에 가깝게. 두 쪽 모두 가구를 놓는 방 크기(MIN_REMAINDER칸, 짧은 변 3) 이상.
const SPLIT_OVER := {"bed": 24, "kitchen": 20, "living": 36}
const TARGET_AREA := {"bed": 16, "kitchen": 15, "living": 27}
const MIN_SIDE := 3
## 문이 원래 없는 쪽(새 칸막이 문으로만 드나드는 쪽)에는 더 안쪽 방이 온다: 침실을 지나 거실로 가지 않게.
const PRIVACY := {"bed": 3, "kitchen": 2, "living": 1}
## 집 한 채에서 가르는 횟수 상한: 이 수에 처음 큰 방 수를 더한다(연립 한 동에 큰 방이 여럿).
const MAX_CUTS := 8


static func is_home(building: Dictionary) -> bool:
	var role := String(building.get("role", ""))
	if not role.is_empty():
		return role == "home"
	var name := String(building.get("name", ""))
	for word: String in NON_HOME:
		if name.contains(word):
			return false
	return Furnish._home(name)


## 가게 건물: 땅층은 가게 그대로, 위층의 살림 칸만 집처럼 나눈다.
static func is_shop_house(building: Dictionary) -> bool:
	var role := String(building.get("role", ""))
	if not role.is_empty():
		return role in SHOP_ROLES
	var name := String(building.get("name", ""))
	for word: String in SHOP_WORDS:
		if name.contains(word):
			return true
	return false


## 순수 후보 선택. 격자·상자·이름표는 바꾸지 않는다. accept가 있으면 그것이 받는 후보만.
## soft: 지금은 다시 놓을 지도 가구가 서 있지만 나누면 치울 칸(빈 바닥으로 본다).
static func choose(g: Grid, cells: Array, sizes: Array, protected: Dictionary, accept: Callable = Callable(), soft: Dictionary = {}) -> Dictionary:
	if cells.is_empty():
		return {}
	var inside := {}
	var lo: Vector2i = cells[0]
	var hi := lo
	var entries: Array[Vector2i] = []
	for c: Vector2i in cells:
		if g.solid_at(c) != S.NONE and not soft.has(c):
			return {}
		inside[c] = true
		lo = lo.min(c)
		hi = hi.max(c)
		for d: Vector2i in DIRS:
			if g.doors.has(c + d):
				entries.append(c + d)
	if entries.is_empty():
		return {}
	var corners: Array = [lo, Vector2i(hi.x, lo.y), Vector2i(lo.x, hi.y), hi]
	corners.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := _distance(a, entries)
		var db := _distance(b, entries)
		return da > db if da != db else (a.y < b.y if a.y != b.y else a.x < b.x))
	for corner: Vector2i in corners:
		for size: Vector2i in sizes:
			var origin := Vector2i(corner.x if corner.x == lo.x else corner.x - size.x + 1,
				corner.y if corner.y == lo.y else corner.y - size.y + 1)
			var rect := Rect2i(origin, size)
			var inner := {}
			var wall := {}
			var valid := true
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					var c := Vector2i(x, y)
					# 창 앞 칸(「tall」)은 새 칸 안에 들어도 된다(창 난 욕실). 벽은 창에 닿지 않는다(아래).
					if not inside.has(c) or (g.solid_at(c) != S.NONE and not soft.has(c)) or (protected.has(c) and str(protected[c]) != "tall"):
						valid = false
					inner[c] = true
			if not valid:
				continue
			# 경계의 기존 벽은 쓰고, 방 쪽 경계와 ㄱ자 접점만 새로 칠한다.
			for y in range(rect.position.y - 1, rect.end.y + 1):
				for x in range(rect.position.x - 1, rect.end.x + 1):
					var c := Vector2i(x, y)
					if inner.has(c):
						continue
					if inside.has(c):
						if (g.solid_at(c) != S.NONE and not soft.has(c)) or protected.has(c):
							valid = false
						wall[c] = true
					elif g.solid_at(c) != S.WALL:
						valid = false
			if not valid or cells.size() - inner.size() - wall.size() < MIN_REMAINDER:
				continue
			var remaining := inside.duplicate()
			for c: Vector2i in inner:
				remaining.erase(c)
			for c: Vector2i in wall:
				remaining.erase(c)
			if not _connected(remaining):
				continue
			var doors: Array = wall.keys()
			# 벽장·찬방(두 칸)은 긴 변의 문을 먼저 본다: 안쪽 끝 칸에 선반을 두어도 문 안쪽 두 칸이 빈다.
			# 폭 두 칸 욕실은 짧은 끝의 문을 먼저 본다: 문 앞 두 칸 너머 안쪽 끝이 통째로 남는다.
			doors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				var la := _in_line(a, rect)
				var lb := _in_line(b, rect)
				if la != lb:
					return lb
				var ea := _narrow_end(a, rect)
				var eb := _narrow_end(b, rect)
				if ea != eb:
					return ea
				var da := _distance(a, entries)
				var db := _distance(b, entries)
				return da < db if da != db else (a.y < b.y if a.y != b.y else a.x < b.x))
			for door: Vector2i in doors:
				# faces()의 가로벽 우선 판정과 정확히 같은 축이어야 한다.
				var horizontal := _wall_at(g, wall, door + Vector2i.LEFT) or _wall_at(g, wall, door + Vector2i.RIGHT)
				var axis := Vector2i.DOWN if horizontal else Vector2i.RIGHT
				var a := door - axis
				var b := door + axis
				if not ((inner.has(a) and remaining.has(b)) or (inner.has(b) and remaining.has(a))):
					continue
				var side := Vector2i(axis.y, axis.x)
				if not _wall_at(g, wall, door - side) or not _wall_at(g, wall, door + side):
					continue
				var walls := wall.duplicate()
				walls.erase(door)
				var found := {"rect": rect, "inner": inner, "remaining": remaining, "walls": walls, "door": door}
				if accept.is_valid() and not accept.call(found):
					continue
				return found
	return {}


## 찬방을 떼고도 부엌에 조리대 한 줄이 설 곧은 벽(COUNTER_MIN칸)이 남는가. 칸막이를 잠깐 세워
## 보고 되돌린다(가구 코드의 _kitchen_run과 같은 칸: 비었고, 문 앞이 아니고, 벽에 붙음).
## side: 부엌으로 남을 쪽(found의 "keep"·"add", 없으면 "remaining"). soft는 choose와 같다.
## 그 쪽 칸만으로 방 번호를 매긴다(지도 전체를 다시 나누지 않는다). 칸은 처음 값으로 되돌린다.
static func _keeps_counter_run(data: Dictionary, g: Grid, lv: int, found: Dictionary, soft: Dictionary = {}, side: String = "remaining") -> bool:
	var door: Vector2i = found["door"]
	var was := {}
	for c: Vector2i in found["walls"]:
		was[c] = g.solid_at(c)
		g.set_solid(c, S.WALL)
	was[door] = g.solid_at(door)
	g.set_solid(door, S.DOOR)
	g.doors[door] = {"state": "closed", "hp": DOOR_HP, "cell": door}
	var cells: Array[Vector2i] = []
	cells.assign(found[side].keys())
	var of := PackedInt32Array()
	of.resize(g.width * g.height)
	of.fill(-1)
	for c in cells:
		of[g.index(c)] = 0
	var forbid := Furnish._forbidden(g, of, 0, cells, Furnish._stairs_by_level(data).get(lv, {}))
	var usable := {}
	for c: Vector2i in cells:
		if (g.solid_at(c) == S.NONE or soft.has(c)) and forbid.get(c, "") != "all" and Furnish._wall_sides(g, of, 0, Rect2i(c, Vector2i.ONE)) > 0:
			usable[c] = true
	var ok := false
	for c: Vector2i in usable:
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			if usable.has(c - d):
				continue
			var n := 1
			while usable.has(c + d * n):
				n += 1
			ok = ok or n >= Furnish.COUNTER_MIN
	for c: Vector2i in was:
		g.set_solid(c, was[c])
	g.doors.erase(door)
	return ok


## 폭 두 칸, 길이 넷 이상인 칸의 짧은 끝에 난 문.
static func _narrow_end(door: Vector2i, rect: Rect2i) -> bool:
	if mini(rect.size.x, rect.size.y) != 2 or maxi(rect.size.x, rect.size.y) < 4:
		return false
	if rect.size.x == 2:
		return door.y == rect.position.y - 1 or door.y == rect.end.y
	return door.x == rect.position.x - 1 or door.x == rect.end.x


## 두 칸짜리 방의 짧은 끝에 난 문(문과 두 칸이 한 줄).
static func _in_line(door: Vector2i, rect: Rect2i) -> bool:
	return rect.get_area() == 2 and (rect.size.x == 1 and door.x == rect.position.x or rect.size.y == 1 and door.y == rect.position.y)


static func _wall_at(g: Grid, walls: Dictionary, c: Vector2i) -> bool:
	return walls.has(c) or g.solid_at(c) == S.WALL


static func _distance(c: Vector2i, entries: Array) -> int:
	var best := 2147483647
	for e: Vector2i in entries:
		best = mini(best, absi(c.x - e.x) + absi(c.y - e.y))
	return best


static func _connected(cells: Dictionary) -> bool:
	if cells.is_empty():
		return false
	var queue: Array = [cells.keys()[0]]
	var seen := {queue[0]: true}
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d: Vector2i in DIRS:
			if cells.has(c + d) and not seen.has(c + d):
				seen[c + d] = true
				queue.append(c + d)
	return seen.size() == cells.size()


static func _protected(data: Dictionary, g: Grid, lv: int, map: Dictionary, ri: int, soft: Dictionary = {}) -> Dictionary:
	var stairs: Dictionary = Furnish._stairs_by_level(data).get(lv, {})
	var out: Dictionary = Furnish._forbidden(g, map["of"], ri, map["rooms"][ri]["cells"], stairs)
	# 지도 가구가 놓인 칸에는 칸막이도 새 칸도 두지 않는다: 가구가 벽 속에 묻히거나
	# 욕실 안에 침대가 남지 않게(가구 놓기는 칸막이 뒤에 돈다). 다시 놓을 가구(soft 칸)는
	# 나눌 때 치우므로 막지 않는다.
	for prop: Dictionary in _props(data):
		if int(prop.get("level", 0)) != lv or not prop.get("rect") is Rect2i or prop.get("_split_drop", false):
			continue
		if not soft.is_empty() and Furnish.REPLACED.has(String(prop.get("kind", ""))) and soft.has((prop["rect"] as Rect2i).position):
			continue
		var r: Rect2i = prop["rect"]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				out[Vector2i(x, y)] = true
	return out


## 상자가 놓일 칸을 먼저 예약한다. 하나라도 옮길 수 없으면 격자를 건드리지 않는다.
static func _box_moves(data: Dictionary, g: Grid, lv: int, candidate: Dictionary, soft: Dictionary = {}) -> Variant:
	var boxes: Dictionary = data.get("containers", {})
	var occupied := {}
	for box: Dictionary in boxes.values():
		if int(box.get("level", 0)) == lv:
			occupied[box["cell"]] = true
	var moves := {}
	var ids := boxes.keys()
	ids.sort()
	for id: String in ids:
		var box: Dictionary = boxes[id]
		var c: Vector2i = box["cell"]
		if int(box.get("level", 0)) != lv or not (candidate["walls"].has(c) or c == candidate["door"]):
			continue
		var spots: Array = candidate["remaining"].keys()
		spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var da := absi(a.x - c.x) + absi(a.y - c.y)
			var db := absi(b.x - c.x) + absi(b.y - c.y)
			return da < db if da != db else (a.y < b.y if a.y != b.y else a.x < b.x))
		var found := false
		for spot: Vector2i in spots:
			if not occupied.has(spot) and (g.solid_at(spot) == S.NONE or soft.has(spot)):
				moves[id] = spot
				occupied[spot] = true
				found = true
				break
		if not found:
			return null
	return moves


static func _apply(data: Dictionary, lv: int, room: Dictionary, cls: String, kind: String) -> Dictionary:
	var g: Grid = data.get("levels", {0: data["grid"]})[lv]
	var cells: Array[Vector2i] = []
	cells.assign(room["cells"])
	var of := PackedInt32Array()
	of.resize(g.width * g.height)
	of.fill(-1)
	for c in cells:
		of[g.index(c)] = 0
	var map := {"of": of, "rooms": [{"cells": cells}]}
	var replaced := _replaced_in(data, lv, cells)
	var soft: Dictionary = replaced["cells"]
	# 벽장·찬방은 문이 긴 변에 날 때만(선반 자리), 찬방은 부엌 조리대 벽도 남을 때만.
	var accept := Callable()
	if kind == "closet":
		accept = func(found: Dictionary) -> bool: return not _in_line(found["door"], found["rect"])
	elif kind == "pantry":
		accept = func(found: Dictionary) -> bool: return not _in_line(found["door"], found["rect"]) and _keeps_counter_run(data, g, lv, found, soft)
	var candidate := choose(g, cells, BATH_SIZES if kind == "bath" else STORE_SIZES, _protected(data, g, lv, map, 0, soft), accept, soft)
	if candidate.is_empty():
		return {}
	var moves: Variant = _box_moves(data, g, lv, candidate, soft)
	if moves == null:
		return {}
	_clear(data, g, lv, replaced)
	var b: int = room["building"]
	for c: Vector2i in candidate["walls"]:
		g.set_solid(c, S.WALL)
	var door: Vector2i = candidate["door"]
	g.set_solid(door, S.DOOR)
	g.doors[door] = {"state": "closed", "hp": DOOR_HP, "building": b, "cell": door}
	for id: String in moves:
		data["containers"][id]["cell"] = moves[id]
	# 기존 방 이름표가 새 벽·수납 칸에 걸리면 원래 방 쪽으로 옮긴다.
	var parent: Vector2i = candidate["remaining"].keys()[0]
	for label: Dictionary in data.get("labels", []):
		if int(label.get("level", 0)) == lv and (candidate["inner"].has(label.get("cell")) or candidate["walls"].has(label.get("cell")) or label.get("cell") == door):
			label["cell"] = parent
	var title := "욕실" if kind == "bath" else ("벽장 저장 칸" if cls == "bed" else "찬방 저장 칸")
	# 방 종류는 숨은 이름표로 적는다: 바닥 글씨(labels)는 늘리지 않고 가구 코드만 이름표처럼 읽는다.
	var hints: Array = data.get_or_add("_room_hints", [])
	hints.append({"text": title, "cell": candidate["rect"].position, "level": lv})
	hints.append({"text": Furnish.ROOM_LABEL[cls], "cell": parent, "level": lv})
	# 새 수납 칸에 남은 원래 가구의 용도 메모도 새 이름과 맞춘다.
	for prop: Dictionary in _props(data):
		if int(prop.get("level", 0)) == lv and candidate["inner"].has((prop["rect"] as Rect2i).get_center()):
			prop["note"] = title
	if kind != "bath":
		_shelf(data, g, lv, b, candidate, door, title)
	data.erase("_rooms")
	room["cells"] = candidate["remaining"].keys()
	return {"building": b, "level": lv, "kind": kind, "source_class": cls, "rect": candidate["rect"],
		"door": door, "walls": candidate["walls"].keys(), "parent": parent, "boxes_moved": moves.size()}


## 지금 나누는 건물 둘레의 지도 가구(apply가 건물마다 한 번 골라 둔다). 없으면 지도 가구 전부.
static func _props(data: Dictionary) -> Array:
	return data.get("_split_props", data.get("props", []))


## 방 안의 다시 놓을 지도 가구(room_furnish REPLACED)와 그 칸. 나눈 방은 가구 놓기가 어차피
## 다시 놓는다. 남겨 두면 칸막이 자리를 막고, 메모 「안방의 침대」가 새로 뗀 방을 침실로 읽힌다.
static func _replaced_in(data: Dictionary, lv: int, cells: Array) -> Dictionary:
	var inside := {}
	for c: Vector2i in cells:
		inside[c] = true
	var found: Array = []
	var soft := {}
	for p: Dictionary in _props(data):
		if int(p.get("level", 0)) != lv or not p.get("rect") is Rect2i or p.get("_split_drop", false) or not Furnish.REPLACED.has(String(p.get("kind", ""))):
			continue
		var r: Rect2i = p["rect"]
		if not inside.has(r.position) and not inside.has(r.get_center()):
			continue
		found.append(p)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				soft[Vector2i(x, y)] = true
	return {"props": found, "cells": soft, "inside": inside}


## _replaced_in이 찾은 가구를 치운다: 그 칸의 낮은 막힘을 풀고 치울 표시를 한다. 소품 줄과
## 땅층 낮은 덩이 목록에서는 apply 끝에 한 번에 뺀다(_drop_cleared).
static func _clear(data: Dictionary, g: Grid, lv: int, replaced: Dictionary) -> void:
	for p: Dictionary in replaced["props"]:
		p["_split_drop"] = true
		var r: Rect2i = p["rect"]
		if lv == 0:
			data.get_or_add("_split_dropped", {})[r] = true
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if replaced["inside"].has(c) and g.solid_at(c) == S.LOW:
					g.set_solid(c, S.NONE)


static func _drop_cleared(data: Dictionary) -> void:
	data.erase("_split_props")
	var rects: Dictionary = data.get("_split_dropped", {})
	data.erase("_split_dropped")
	if not data.has("props"):
		return
	data["props"] = data["props"].filter(func(p: Dictionary) -> bool: return not p.get("_split_drop", false))
	if not rects.is_empty() and data.has("low_blocks"):
		data["low_blocks"] = data["low_blocks"].filter(func(r: Rect2i) -> bool: return not rects.has(r))


## ---------------------------------------------------------------- 큰 방 가르기 (결정 469 F1)

## 가를 자리: 방을 가로(또는 세로)로 끝까지 가르는 곧은 한 줄. 줄 양끝 바로 밖은 벽(창·문 아님), 줄 칸은
## 비었고(soft는 빈 것으로) 지킬 칸이 아니며, 두 쪽은 각각 이어지고 MIN_REMAINDER칸·짧은 변 MIN_SIDE 이상.
## 원래 문이 없는 쪽에는 더 안쪽 방(PRIVACY). 두 쪽이 TARGET_AREA에 가장 가까운 줄과 쪽 나눔을 고른다.
## 돌려주는 값: {"walls", "door", "keep", "add", "remaining"} — keep 쪽이 원래 묶음, add 쪽이 새 묶음.
## stairs: 이 층의 계단 칸(위층 방은 계단으로 들어온다).
static func _cut(g: Grid, cells: Array, protected: Dictionary, soft: Dictionary, keep: String, add: String, accept: Callable = Callable(), stairs: Dictionary = {}) -> Dictionary:
	var lo: Vector2i = cells[0]
	var hi := lo
	var entries: Array[Vector2i] = []
	for c: Vector2i in cells:
		lo = lo.min(c)
		hi = hi.max(c)
		if stairs.has(c):
			entries.append(c)
		for d: Vector2i in DIRS:
			if g.doors.has(c + d) or (g.people_can_walk(c + d) and g.building_at(c + d) != g.building_at(c)):
				entries.append(c + d)
	if entries.is_empty():
		return {}
	var lines: Array = []
	for axis in [0, 1]:
		var along := Vector2i.RIGHT if axis == 0 else Vector2i.DOWN
		for k in range((lo.y if axis == 0 else lo.x) + 1, hi.y if axis == 0 else hi.x):
			var line: Array[Vector2i] = []
			var a := {}
			var b := {}
			for c: Vector2i in cells:
				var at := c.y if axis == 0 else c.x
				if at == k:
					line.append(c)
				elif at < k:
					a[c] = true
				else:
					b[c] = true
			if line.size() < 2 or a.size() < MIN_REMAINDER or b.size() < MIN_REMAINDER:
				continue
			line.sort()
			var valid := line[line.size() - 1] - line[0] == along * (line.size() - 1)
			for c: Vector2i in line:
				valid = valid and (g.solid_at(c) == S.NONE or soft.has(c)) and not protected.has(c)
			valid = valid and g.solid_at(line[0] - along) == S.WALL and g.solid_at(line[line.size() - 1] + along) == S.WALL
			if valid and _short_side(a) >= MIN_SIDE and _short_side(b) >= MIN_SIDE and _connected(a) and _connected(b):
				lines.append({"line": line, "a": a, "b": b, "axis": axis})
	var best := {}
	var best_score := 2147483647
	for row: Dictionary in lines:
		var touch_a := _touches(row["a"], entries)
		var touch_b := _touches(row["b"], entries)
		for keep_a: bool in [true, false]:
			var keep_cells: Dictionary = row["a"] if keep_a else row["b"]
			var add_cells: Dictionary = row["b"] if keep_a else row["a"]
			if not (touch_a if keep_a else touch_b) and PRIVACY[keep] < PRIVACY[add]:
				continue
			if not (touch_b if keep_a else touch_a) and PRIVACY[add] < PRIVACY[keep]:
				continue
			var score := absi(keep_cells.size() - int(TARGET_AREA[keep])) + absi(add_cells.size() - int(TARGET_AREA[add]))
			if score >= best_score:
				continue
			var door := _cut_door(row["line"], row["axis"], keep_cells, add_cells, protected, entries)
			if door.x < 0:
				continue
			var walls := {}
			for c: Vector2i in row["line"]:
				if c != door:
					walls[c] = true
			var remaining := keep_cells.duplicate()
			remaining.merge(add_cells)
			var found := {"walls": walls, "door": door, "keep": keep_cells, "add": add_cells, "remaining": remaining}
			if accept.is_valid() and not accept.call(found):
				continue
			best = found
			best_score = score
	return best


## 칸막이 문: 앞뒤 칸이 두 쪽 바닥이고 지킬 칸이 아닌 줄 칸 가운데 원래 들어오는 곳에 가장 가까운 것.
static func _cut_door(line: Array, axis: int, keep: Dictionary, add: Dictionary, protected: Dictionary, entries: Array) -> Vector2i:
	var across := Vector2i.DOWN if axis == 0 else Vector2i.RIGHT
	var best := Vector2i(-1, -1)
	var best_d := 2147483647
	for c: Vector2i in line:
		var p := c - across
		var q := c + across
		if not ((keep.has(p) and add.has(q)) or (keep.has(q) and add.has(p))) or protected.has(p) or protected.has(q):
			continue
		var d := _distance(c, entries)
		if d < best_d:
			best_d = d
			best = c
	return best


static func _touches(cells: Dictionary, entries: Array) -> bool:
	for e: Vector2i in entries:
		if cells.has(e):
			return true
		for d: Vector2i in DIRS:
			if cells.has(e + d):
				return true
	return false


static func _short_side(cells: Dictionary) -> int:
	var lo: Vector2i = cells.keys()[0]
	var hi := lo
	for c: Vector2i in cells:
		lo = lo.min(c)
		hi = hi.max(c)
	return mini(hi.x - lo.x + 1, hi.y - lo.y + 1)


## 큰 방 하나를 가른다. 그 방의 다시 놓을 지도 가구는 먼저 치우고, 남는 지도 가구의 메모는 그 쪽 이름으로.
## 두 쪽 묶음은 숨은 이름표로 적는다. room은 원래 쪽으로 줄고, 돌려주는 값의 cells가 새 쪽이다.
static func _bisect(data: Dictionary, lv: int, room: Dictionary, add: String) -> Dictionary:
	var g: Grid = data.get("levels", {0: data["grid"]})[lv]
	var keep: String = room["class"]
	var cells: Array[Vector2i] = []
	cells.assign(room["cells"])
	var of := PackedInt32Array()
	of.resize(g.width * g.height)
	of.fill(-1)
	for c in cells:
		of[g.index(c)] = 0
	var replaced := _replaced_in(data, lv, cells)
	var soft: Dictionary = replaced["cells"]
	var protected := _protected(data, g, lv, {"of": of, "rooms": [{"cells": cells}]}, 0, soft)
	# 칸막이 줄은 문 앞 곧은 두 칸만 비우면 문 곁 칸(문 앞 피할 자리의 양옆)은 지나도 된다: 문이 새 방의
	# 모서리 곁으로 열린다. 계단 둘레·남는 지도 가구 칸은 그대로 지킨다.
	var stairs: Dictionary = Furnish._stairs_by_level(data).get(lv, {})
	var inside := {}
	for c in cells:
		inside[c] = true
	var hard := {}
	var sides := {}
	for c in cells:
		if stairs.has(c):
			hard[c] = true
			for d: Vector2i in DIRS:
				hard[c + d] = true
		for d: Vector2i in DIRS:
			if inside.has(c + d) or not (g.doors.has(c + d) or g.people_can_walk(c + d)):
				continue
			var flank := Vector2i(d.y, d.x)
			for k in [0, 1]:
				hard[c - d * k] = true
				sides[c - d * k + flank] = true
				sides[c - d * k - flank] = true
	for prop: Dictionary in _props(data):
		if int(prop.get("level", 0)) == lv and prop.get("rect") is Rect2i and not prop.get("_split_drop", false) and not soft.has((prop["rect"] as Rect2i).position):
			var r: Rect2i = prop["rect"]
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					hard[Vector2i(x, y)] = true
	var line_protected := protected.duplicate()
	for c: Vector2i in sides:
		if not hard.has(c) and str(protected.get(c, "")) == "all":
			line_protected.erase(c)
	# 부엌으로 남거나 새로 서는 쪽에는 조리대 한 줄이 설 곧은 벽이 있어야 한다.
	var accept := Callable()
	if keep == "kitchen" or add == "kitchen":
		var side := "keep" if keep == "kitchen" else "add"
		accept = func(found: Dictionary) -> bool: return _keeps_counter_run(data, g, lv, found, soft, side)
	var candidate := _cut(g, cells, line_protected, soft, keep, add, accept, stairs)
	if candidate.is_empty():
		return {}
	var moves: Variant = _box_moves(data, g, lv, candidate, soft)
	if moves == null:
		return {}
	_clear(data, g, lv, replaced)
	var b: int = room["building"]
	for c: Vector2i in candidate["walls"]:
		g.set_solid(c, S.WALL)
	var door: Vector2i = candidate["door"]
	g.set_solid(door, S.DOOR)
	g.doors[door] = {"state": "closed", "hp": DOOR_HP, "building": b, "cell": door}
	for id: String in moves:
		data["containers"][id]["cell"] = moves[id]
	var keep_cells: Dictionary = candidate["keep"]
	var add_cells: Dictionary = candidate["add"]
	var keep_at := _first(keep_cells)
	# 칸막이에 걸린 이름표, 새 쪽에 남은 방 이름 글씨는 원래 쪽으로(새 쪽이 원래 묶음으로 읽히지 않게).
	for label: Dictionary in data.get("labels", []):
		if int(label.get("level", 0)) != lv:
			continue
		var at: Variant = label.get("cell")
		if candidate["walls"].has(at) or at == door or (add_cells.has(at) and Furnish._name_class(String(label.get("text", "")))[1]):
			label["cell"] = keep_at
	var hints: Array = data.get_or_add("_room_hints", [])
	# 앞서 이 방에 단 숨은 이름표(욕실·벽장을 뗄 때 원래 방 쪽에 단 것)도 원래 쪽으로.
	for hint: Dictionary in hints:
		if int(hint.get("level", 0)) == lv and add_cells.has(hint.get("cell")):
			hint["cell"] = keep_at
	hints.append({"text": Furnish.ROOM_LABEL[keep], "cell": keep_at, "level": lv})
	hints.append({"text": Furnish.ROOM_LABEL[add], "cell": _first(add_cells), "level": lv})
	for prop: Dictionary in _props(data):
		if int(prop.get("level", 0)) != lv or not prop.get("rect") is Rect2i:
			continue
		var note := String(prop.get("note", ""))
		var cut := note.find("의 ")
		if cut > 0 and add_cells.has((prop["rect"] as Rect2i).get_center()):
			prop["note"] = Furnish.ROOM_LABEL[add] + note.substr(cut)
	data.erase("_rooms")
	room["cells"] = keep_cells.keys()
	room["area"] = keep_cells.size()
	return {"building": b, "level": lv, "kind": "cut", "source_class": keep, "class": add, "door": door,
		"walls": candidate["walls"].keys(), "cells": add_cells.keys(), "boxes_moved": moves.size()}


static func _first(cells: Dictionary) -> Vector2i:
	var keys: Array = cells.keys()
	keys.sort()
	return keys[0]


## 벽장·찬방 안쪽 끝 칸에 작은 선반 하나(참고 실측: 벽장 가운데값 2칸·가구 1점, 선반 89.5%).
## 문이 짧은 끝에 났으면 두지 않는다(문 안쪽 두 칸은 늘 비어 있어야 한다). 꾸밈 가구라 상자 수는 그대로다.
static func _shelf(data: Dictionary, g: Grid, lv: int, b: int, candidate: Dictionary, door: Vector2i, title: String) -> void:
	var cells: Array = candidate["inner"].keys()
	if cells.size() != 2 or _in_line(door, candidate["rect"]):
		return
	cells.sort_custom(func(a: Vector2i, c: Vector2i) -> bool:
		var da := absi(a.x - door.x) + absi(a.y - door.y)
		var dc := absi(c.x - door.x) + absi(c.y - door.y)
		return da > dc if da != dc else (a.y < c.y if a.y != c.y else a.x < c.x))
	var at: Vector2i = cells[0]
	var toward: Vector2i = (cells[cells.size() - 1] as Vector2i) - at
	var facing := 0
	for f in range(4):
		if PropFit.front(f) == toward.sign():
			facing = f
	if Furnish.blocks("small_shelf", lv):
		g.set_solid(at, S.LOW)
		if lv == 0:
			data.get_or_add("low_blocks", []).append(Rect2i(at, Vector2i.ONE))
	var shelf := {"kind": "small_shelf", "rect": Rect2i(at, Vector2i.ONE), "solid": "low", "facing": facing,
		"note": "%s의 %s" % [title, Furnish.KIND_LABEL["small_shelf"]], "level": lv, "building": b, "rule": "store"}
	data.get_or_add("props", []).append(shelf)
	if data.has("_split_props"):
		data["_split_props"].append(shelf)


## 이름 없는 살림집은 방 크기 차례로 종류를 물려받는다(room_furnish HOME_ORDER). 칸막이가 생기면
## 그 건물은 이름 있는 건물로 읽혀 차례가 끊기므로, 나누기 전에 정한 종류를 숨은 이름표로 묶어 둔다.
static func _pin_classes(data: Dictionary, rooms: Array) -> void:
	var hints: Array = data.get_or_add("_room_hints", [])
	for room: Dictionary in rooms:
		var cls: String = room["class"]
		if not Furnish.ROOM_LABEL.has(cls) or room["cells"].is_empty():
			continue
		var cells: Array = room["cells"].duplicate()
		cells.sort()
		hints.append({"text": Furnish.ROOM_LABEL[cls], "cell": cells[0], "level": room["level"]})


## 욕실을 침실(없으면 거실) 구석에서 뗀다. 큰 방부터 하나씩 보아 처음 되는 곳에. 뗐으면 true.
static func _carve_bath(data: Dictionary, rooms: Array, stats: Dictionary) -> bool:
	for cls: String in ["bed", "living"]:
		var tried := false
		for room: Dictionary in rooms:
			if room["class"] != cls:
				continue
			tried = true
			var row := _apply(data, room["level"], room, cls, "bath")
			if not row.is_empty():
				_record(stats, row, "bath")
				return true
		if tried:
			stats["skipped"] += 1
	return false


## 집 한 채의 큰 방을 차례로 가른다(가장 큰 방부터, SPLIT_OVER를 넘는 동안). 새 쪽 묶음은 그 집에 없는
## 것부터: 거실, 부엌, 그다음 침실(아이 방). 거실·부엌으로 못 가르면 침실로 한 번 더 본다.
static func _cut_rooms(data: Dictionary, b: int, rooms: Array, stats: Dictionary) -> void:
	var failed := {}
	var over := 0
	for r: Dictionary in rooms:
		over += int(SPLIT_OVER.has(r["class"]) and r["cells"].size() > int(SPLIT_OVER[r["class"]]))
	for _n in range(MAX_CUTS + over):
		var pick := -1
		for i in range(rooms.size()):
			var r: Dictionary = rooms[i]
			var cls: String = r["class"]
			if SPLIT_OVER.has(cls) and r["cells"].size() > int(SPLIT_OVER[cls]) and not failed.has(i) and (pick < 0 or r["cells"].size() > rooms[pick]["cells"].size()):
				pick = i
		if pick < 0:
			return
		var room: Dictionary = rooms[pick]
		var has := {}
		for r: Dictionary in rooms:
			has[r["class"]] = true
		var wants: Array[String] = []
		for cls: String in ["living", "kitchen"]:
			if not has.has(cls):
				wants.append(cls)
		wants.append("bed")
		var row := {}
		for add: String in wants:
			row = _bisect(data, room["level"], room, add)
			if not row.is_empty():
				break
		if row.is_empty():
			failed[pick] = true
			stats["skipped"] += 1
			continue
		stats["cut"] += 1
		stats["boxes_moved"] += row["boxes_moved"]
		stats["cuts"].append(row)
		rooms.append({"level": row["level"], "building": b, "cells": row["cells"], "area": row["cells"].size(), "class": row["class"]})
	_living_from_a_bedroom(data, rooms, stats)


## 방에 제 문이 있나: 문(또는 뚫린 곳) 너머가 건물 밖·복도·계단 칸이고 다른 침실·부엌·욕실이 아니다.
static func _own_way_in(data: Dictionary, lv: int, inside: Dictionary, rooms: Array) -> bool:
	var g: Grid = data.get("levels", {0: data["grid"]})[lv]
	var private := {}
	for r: Dictionary in rooms:
		if r["level"] == lv and r["class"] in ["bed", "kitchen", "bath"]:
			for c: Vector2i in r["cells"]:
				if not inside.has(c):
					private[c] = true
	for c: Vector2i in Furnish._stairs_by_level(data).get(lv, {}):
		if inside.has(c):
			return true
	for c: Vector2i in inside:
		for d: Vector2i in DIRS:
			var n: Vector2i = c + d
			if inside.has(n) or not (g.doors.has(n) or g.people_can_walk(n)):
				continue
			var beyond: Vector2i = n + d if g.doors.has(n) else n
			if not private.has(beyond):
				return true
	return false


## 가르고도 거실이 없는 집에 침실이 둘 이상이면, 가장 낮은 층의 가장 큰 침실을 거실로 쓴다(벽은 그대로).
## 바닥 글씨로 방 이름이 적힌 방은 글씨와 어긋나지 않게 두지 않는다.
static func _living_from_a_bedroom(data: Dictionary, rooms: Array, stats: Dictionary) -> void:
	var beds: Array = []
	for r: Dictionary in rooms:
		if r["class"] == "living":
			return
		if r["class"] == "bed" and r["cells"].size() >= MIN_REMAINDER:
			beds.append(r)
	if beds.size() < 2:
		return
	beds.sort_custom(func(a: Dictionary, c: Dictionary) -> bool:
		if a["level"] != c["level"]:
			return a["level"] < c["level"]
		return a["cells"].size() > c["cells"].size())
	for room: Dictionary in beds:
		var lv: int = room["level"]
		var inside := {}
		for c: Vector2i in room["cells"]:
			inside[c] = true
		# 다른 방을 지나야 들어오는 안쪽 침실은 거실로 쓰지 않는다(PRIVACY와 같은 뜻).
		if not _own_way_in(data, lv, inside, rooms):
			continue
		var written := false
		for label: Dictionary in data.get("labels", []):
			written = written or (int(label.get("level", 0)) == lv and inside.has(label.get("cell")) and Furnish._name_class(String(label.get("text", "")))[1])
		if written:
			continue
		var title: String = Furnish.ROOM_LABEL["living"]
		for hint: Dictionary in data.get("_room_hints", []):
			if int(hint.get("level", 0)) == lv and inside.has(hint.get("cell")):
				hint["text"] = title
		for prop: Dictionary in _props(data):
			if int(prop.get("level", 0)) != lv or not prop.get("rect") is Rect2i:
				continue
			var note := String(prop.get("note", ""))
			var cut := note.find("의 ")
			if cut > 0 and inside.has((prop["rect"] as Rect2i).get_center()):
				prop["note"] = title + note.substr(cut)
		room["class"] = "living"
		stats["relabelled"] = int(stats.get("relabelled", 0)) + 1
		return


static func apply(data: Dictionary, map_script: Script = null) -> Dictionary:
	if data.has("room_splits"):
		return data["room_splits"]
	var stats := {"bath": 0, "closet": 0, "pantry": 0, "cut": 0, "skipped": 0, "boxes_moved": 0, "rows": [], "cuts": []}
	if String(data.get("place_id", "")) in ["", "first_leg_01_sulechow"]:
		return stats
	var plan := Furnish.density_plan(data)
	# 지도 반환 자료는 role을 생략한다. 원래 선언의 home을 읽되 지도는 고치지 않는다.
	var roles := {}
	if map_script != null:
		var constants := map_script.get_script_constant_map()
		for section: String in ["PLAN", "NORTH"]:
			for row: Variant in constants.get(section, {}).get("buildings", []):
				if row is Dictionary and row.has("role"):
					roles[int(row["id"])] = row["role"]
	var levels: Dictionary = data.get("levels", {0: data["grid"]})
	var lvs := levels.keys()
	lvs.sort()
	var original_rooms := {}
	for lv: int in lvs:
		original_rooms[lv] = Furnish.rooms_of(levels[lv])
	for building: Dictionary in data.get("buildings", []):
		var identity := building.duplicate()
		if roles.has(int(building["id"])):
			identity["role"] = roles[int(building["id"])]
		var home := is_home(identity)
		if not home and not is_shop_house(identity):
			continue
		var b: int = building["id"]
		var made: int = stats["rows"].size() + stats["cuts"].size()
		# 이 건물에 닿는 지도 가구만 한 번 골라 둔다(나누는 동안 가구 줄을 몇 번이고 훑지 않게).
		if building.get("rect") is Rect2i:
			var reach: Rect2i = (building["rect"] as Rect2i).grow(1)
			data["_split_props"] = data.get("props", []).filter(func(p: Dictionary) -> bool: return p.get("rect") is Rect2i and (p["rect"] as Rect2i).intersects(reach))
		else:
			data.erase("_split_props")
		var rooms: Array = []
		for lv: int in lvs:
			if lv < (0 if home else 1):
				continue
			var map: Dictionary = original_rooms[lv]
			for ri in range(map["rooms"].size()):
				var room: Dictionary = map["rooms"][ri]
				if room["building"] == b:
					rooms.append({"level": lv, "building": b, "cells": room["cells"], "area": room["cells"].size(), "class": plan["classes"].get("%d:%d" % [lv, ri], "")})
		rooms.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return a["area"] > c["area"])
		# 가게는 위층에 침실이 있을 때만 살림집이다.
		if not home and not rooms.any(func(r: Dictionary) -> bool: return r["class"] == "bed"):
			continue
		# 욕실: 문 하나짜리 작은 방이 욕실 후보가 아니면(없거나 큰 방을 대신 쓰면) 침실·거실 구석을 뗀다.
		var bath: Dictionary = plan["baths"].get(str(b), {})
		var needs_bath: bool = not bath.get("selected", false) or bath.get("reason", "") != "small_one_door"
		if needs_bath:
			needs_bath = not _carve_bath(data, rooms, stats)
		for room: Dictionary in rooms:
			var cls: String = room["class"]
			if not (cls == "bed" and room["area"] > BED_LIMIT or cls == "kitchen" and room["area"] > KITCHEN_LIMIT):
				continue
			var kind := "closet" if cls == "bed" else "pantry"
			_record(stats, _apply(data, room["level"], room, cls, kind), kind)
		_cut_rooms(data, b, rooms, stats)
		# 큰 방에서 못 뗀 욕실은 가른 뒤의 방에서 한 번 더 본다.
		if needs_bath:
			_carve_bath(data, rooms, stats)
		if stats["rows"].size() + stats["cuts"].size() > made:
			_pin_classes(data, rooms)
	# 방 번호는 마지막 칸막이 뒤에 다시 구한다. 가구 코드는 이 욕실만 우선 읽는다.
	var baths := {}
	var final_maps := {}
	for row: Dictionary in stats["rows"]:
		if row["kind"] != "bath":
			continue
		var g: Grid = levels[row["level"]]
		if not final_maps.has(row["level"]):
			final_maps[row["level"]] = Furnish.rooms_of(g)
		var map: Dictionary = final_maps[row["level"]]
		var ri := Furnish._at(g, map["of"], row["rect"].position)
		baths[row["building"]] = {"key": "%d:%d" % [row["level"], ri], "level": row["level"], "room": ri,
			"area": row["rect"].get_area(), "short": mini(row["rect"].size.x, row["rect"].size.y), "doors": 1, "class": "bath"}
	data["_split_baths"] = baths
	_drop_cleared(data)
	data["room_splits"] = stats
	data.erase("_rooms")
	if not data.get("_defer_paths", false):
		for g: Grid in levels.values():
			g.refresh_paths()
	return stats


static func _record(stats: Dictionary, row: Dictionary, kind: String) -> void:
	if row.is_empty():
		stats["skipped"] += 1
		return
	stats[kind] += 1
	stats["boxes_moved"] += row["boxes_moved"]
	stats["rows"].append(row)
