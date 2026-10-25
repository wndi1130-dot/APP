extends RefCounted
## 가구를 놓기 전, 살림집의 넓은 방에서 욕실과 작은 수납 칸을 떼어 낸다.
## 칸막이는 모서리에서 이어진 한 줄(필요하면 ㄱ자)이며 문은 하나다.
const Grid = preload("res://game/world/field_grid.gd")
const Furnish = preload("res://game/world/room_furnish.gd")
const PropFit = preload("res://game/world/prop_fit.gd")
const S = Grid.Solid
const DIRS = Furnish.DIRS
const BED_LIMIT := 30
const KITCHEN_LIMIT := 36
const MIN_REMAINDER := 12
const DOOR_HP := 8
const BATH_SIZES := [Vector2i(2, 3), Vector2i(3, 2), Vector2i(2, 4), Vector2i(4, 2), Vector2i(3, 3), Vector2i(3, 4), Vector2i(4, 3)]
const STORE_SIZES := [Vector2i(1, 2), Vector2i(2, 1)]
const NON_HOME := ["가게", "매장", "상점", "매점", "빵집", "식료", "철물", "잡화", "사무", "관청", "공장", "공방", "병원", "진료", "교회", "성당", "창고", "헛간", "차고", "세탁", "우물집"]


static func is_home(building: Dictionary) -> bool:
	var role := String(building.get("role", ""))
	if not role.is_empty():
		return role == "home"
	var name := String(building.get("name", ""))
	for word: String in NON_HOME:
		if name.contains(word):
			return false
	return Furnish._home(name)


## 순수 후보 선택. 격자·상자·이름표는 바꾸지 않는다. accept가 있으면 그것이 받는 후보만.
static func choose(g: Grid, cells: Array, sizes: Array, protected: Dictionary, accept: Callable = Callable()) -> Dictionary:
	if cells.is_empty():
		return {}
	var inside := {}
	var lo: Vector2i = cells[0]
	var hi := lo
	var entries: Array[Vector2i] = []
	for c: Vector2i in cells:
		if g.solid_at(c) != S.NONE:
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
					if not inside.has(c) or g.solid_at(c) != S.NONE or protected.has(c):
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
						if g.solid_at(c) != S.NONE or protected.has(c):
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
			doors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				var la := _in_line(a, rect)
				var lb := _in_line(b, rect)
				if la != lb:
					return lb
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
static func _keeps_counter_run(data: Dictionary, g: Grid, lv: int, found: Dictionary) -> bool:
	var door: Vector2i = found["door"]
	for c: Vector2i in found["walls"]:
		g.set_solid(c, S.WALL)
	g.set_solid(door, S.DOOR)
	g.doors[door] = {"state": "closed", "hp": DOOR_HP, "cell": door}
	var map := Furnish.rooms_of(g)
	var of: PackedInt32Array = map["of"]
	var ri := Furnish._at(g, of, found["remaining"].keys()[0])
	var ok := false
	if ri >= 0:
		var cells: Array[Vector2i] = map["rooms"][ri]["cells"]
		var forbid := Furnish._forbidden(g, of, ri, cells, Furnish._stairs_by_level(data).get(lv, {}))
		var usable := {}
		for c: Vector2i in cells:
			if g.solid_at(c) == S.NONE and forbid.get(c, "") != "all" and Furnish._wall_sides(g, of, ri, Rect2i(c, Vector2i.ONE)) > 0:
				usable[c] = true
		for c: Vector2i in usable:
			for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				if usable.has(c - d):
					continue
				var n := 1
				while usable.has(c + d * n):
					n += 1
				ok = ok or n >= Furnish.COUNTER_MIN
	for c: Vector2i in found["walls"]:
		g.set_solid(c, S.NONE)
	g.set_solid(door, S.NONE)
	g.doors.erase(door)
	return ok


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


static func _protected(data: Dictionary, g: Grid, lv: int, map: Dictionary, ri: int) -> Dictionary:
	var stairs: Dictionary = Furnish._stairs_by_level(data).get(lv, {})
	var out: Dictionary = Furnish._forbidden(g, map["of"], ri, map["rooms"][ri]["cells"], stairs)
	# 지도 가구가 놓인 칸에는 칸막이도 새 칸도 두지 않는다: 가구가 벽 속에 묻히거나
	# 욕실 안에 침대가 남지 않게(가구 놓기는 칸막이 뒤에 돈다).
	for prop: Dictionary in data.get("props", []):
		if int(prop.get("level", 0)) != lv or not prop.get("rect") is Rect2i:
			continue
		var r: Rect2i = prop["rect"]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				out[Vector2i(x, y)] = true
	return out


## 상자가 놓일 칸을 먼저 예약한다. 하나라도 옮길 수 없으면 격자를 건드리지 않는다.
static func _box_moves(data: Dictionary, g: Grid, lv: int, candidate: Dictionary) -> Variant:
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
			if not occupied.has(spot) and g.solid_at(spot) == S.NONE:
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
	# 벽장·찬방은 문이 긴 변에 날 때만(선반 자리), 찬방은 부엌 조리대 벽도 남을 때만.
	var accept := Callable()
	if kind == "closet":
		accept = func(found: Dictionary) -> bool: return not _in_line(found["door"], found["rect"])
	elif kind == "pantry":
		accept = func(found: Dictionary) -> bool: return not _in_line(found["door"], found["rect"]) and _keeps_counter_run(data, g, lv, found)
	var candidate := choose(g, cells, BATH_SIZES if kind == "bath" else STORE_SIZES, _protected(data, g, lv, map, 0), accept)
	if candidate.is_empty():
		return {}
	var moves: Variant = _box_moves(data, g, lv, candidate)
	if moves == null:
		return {}
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
	for prop: Dictionary in data.get("props", []):
		if int(prop.get("level", 0)) == lv and candidate["inner"].has((prop["rect"] as Rect2i).get_center()):
			prop["note"] = title
	if kind != "bath":
		_shelf(data, g, lv, b, candidate, door, title)
	data.erase("_rooms")
	room["cells"] = candidate["remaining"].keys()
	return {"building": b, "level": lv, "kind": kind, "source_class": cls, "rect": candidate["rect"],
		"door": door, "walls": candidate["walls"].keys(), "parent": parent, "boxes_moved": moves.size()}


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
	data.get_or_add("props", []).append({"kind": "small_shelf", "rect": Rect2i(at, Vector2i.ONE), "solid": "low", "facing": facing,
		"note": "%s의 %s" % [title, Furnish.KIND_LABEL["small_shelf"]], "level": lv, "building": b, "rule": "store"})


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


static func apply(data: Dictionary, map_script: Script = null) -> Dictionary:
	if data.has("room_splits"):
		return data["room_splits"]
	var stats := {"bath": 0, "closet": 0, "pantry": 0, "skipped": 0, "boxes_moved": 0, "rows": []}
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
		if not is_home(identity):
			continue
		var b: int = building["id"]
		var made: int = stats["rows"].size()
		var rooms: Array = []
		for lv: int in lvs:
			if lv < 0:
				continue
			var map: Dictionary = original_rooms[lv]
			for ri in range(map["rooms"].size()):
				var room: Dictionary = map["rooms"][ri]
				if room["building"] == b:
					rooms.append({"level": lv, "building": b, "cells": room["cells"], "area": room["cells"].size(), "class": plan["classes"].get("%d:%d" % [lv, ri], "")})
		rooms.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return a["area"] > c["area"])
		if not plan["baths"].get(str(b), {}).get("selected", false):
			var source := {}
			for cls: String in ["bed", "living"]:
				for room: Dictionary in rooms:
					if room["class"] == cls:
						source = room
						break
				if not source.is_empty():
					break
			if not source.is_empty():
				var row := _apply(data, source["level"], source, source["class"], "bath")
				_record(stats, row, "bath")
		for room: Dictionary in rooms:
			var cls: String = room["class"]
			if not (cls == "bed" and room["area"] > BED_LIMIT or cls == "kitchen" and room["area"] > KITCHEN_LIMIT):
				continue
			var kind := "closet" if cls == "bed" else "pantry"
			_record(stats, _apply(data, room["level"], room, cls, kind), kind)
		if stats["rows"].size() > made:
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
