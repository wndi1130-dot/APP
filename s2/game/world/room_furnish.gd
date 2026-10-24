extends RefCounted
## 방 안 가구 규칙(docs/design/briefs/house_layout.md 1·3장). 둘이다.
## furnish_rooms: 살림방·부엌·거실·매장·창고·지하 저장 칸을 묶음 규칙대로 다시 놓고
## 상자를 용기 가구 칸으로 옮긴다(아래 「방 종류별 가구」).
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
## at: "wall"(긴 변을 벽에) / "mid"(벽에서 떨어져도 됨). tall: 창 앞에 못 둠.
## near: "far_door"(문에서 멀리) / "door"(문 가까이) / "stove"(난로 가까이).
const PALETTE: Dictionary = {
	"bed": [
		{"kind": "bed", "size": Vector2i(2, 1), "need": true, "at": "wall", "near": "far_door"},
		{"kind": "wardrobe", "size": Vector2i(2, 1), "need": true, "holds": true, "at": "wall", "tall": true},
		{"kind": "blanket_chest", "size": Vector2i(2, 1), "holds": true, "at": "wall"},
		{"kind": "bookcase", "size": Vector2i(2, 1), "holds": true, "at": "wall", "tall": true},
		{"kind": "bench", "size": Vector2i(3, 1), "at": "wall"},
	],
	"kitchen": [
		{"kind": "cold_stove", "size": Vector2i(1, 1), "need": true, "at": "wall"},
		{"kind": "jar_shelf", "size": Vector2i(3, 1), "need": true, "holds": true, "at": "wall", "tall": true},
		{"kind": "dining_set", "size": Vector2i(2, 2), "at": "mid"},
		{"kind": "fridge_open", "size": Vector2i(1, 1), "holds": true, "at": "wall", "tall": true},
		{"kind": "barrel", "size": Vector2i(1, 1), "at": "wall"},
	],
	"living": [
		{"kind": "cold_stove", "size": Vector2i(1, 1), "need": true, "at": "wall"},
		{"kind": "bench", "size": Vector2i(3, 1), "need": true, "at": "wall", "near": "stove"},
		{"kind": "bookcase", "size": Vector2i(2, 1), "holds": true, "at": "wall", "tall": true},
		{"kind": "dining_set", "size": Vector2i(2, 2), "at": "mid"},
		{"kind": "radio_set", "size": Vector2i(2, 1), "at": "wall"},
	],
	"shop": [
		{"kind": "shop_counter", "size": Vector2i(3, 1), "need": true, "holds": true, "at": "wall", "near": "door"},
		{"kind": "display_shelf", "size": Vector2i(4, 1), "need": true, "holds": true, "at": "wall", "tall": true},
		{"kind": "display_shelf", "size": Vector2i(4, 1), "holds": true, "at": "wall", "tall": true},
		{"kind": "crate_stack", "size": Vector2i(2, 2), "holds": true, "at": "wall"},
		{"kind": "barrel", "size": Vector2i(1, 1), "at": "wall"},
	],
	"storage": [
		{"kind": "shelf", "size": Vector2i(3, 1), "need": true, "holds": true, "at": "wall", "tall": true},
		{"kind": "shelf", "size": Vector2i(3, 1), "holds": true, "at": "wall", "tall": true},
		{"kind": "crate_stack", "size": Vector2i(2, 2), "holds": true, "at": "wall"},
		{"kind": "barrel", "size": Vector2i(1, 1), "at": "wall"},
		{"kind": "sack_pile", "size": Vector2i(2, 2), "at": "wall"},
	],
	"store": [
		{"kind": "jar_shelf", "size": Vector2i(3, 1), "need": true, "holds": true, "at": "wall", "tall": true},
		{"kind": "shelf", "size": Vector2i(3, 1), "holds": true, "at": "wall", "tall": true},
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
## 지우지 않고 남겨도 덮는 비율에는 센다.
const COVER_MAX: float = 0.45
const FLOOR_MIN: float = 0.5
const FLOOR_MIN_SMALL: float = 0.4
## 가구 하나마다 해 보는 자리 수(점수 위에서부터).
const TOP_CANDIDATES: int = 6


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
	# 지하의 침실·부엌은 사용자 답(지하실 카드)을 기다린다. 지도 가구 그대로.
	if lv < 0 and (cls == "bed" or cls == "kitchen" or cls == "living"):
		return ""
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
		forbid: Dictionary, taken: Dictionary, doors_in: Array, stove_cells: Array, box_at: Dictionary) -> Array:
	var size: Vector2i = item["size"]
	var tall: bool = item.get("tall", false)
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
				_keep_top(out, {"rect": r, "facing": facing, "score": score}, TOP_CANDIDATES)
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


## 방 안 가구를 묶음 규칙대로 다시 놓고, 상자를 그 방 용기 가구 칸으로 옮긴다.
## 돌려주는 값: {"rooms", "placed", "need_missing", "boxes_in", "boxes_near"}.
static func furnish_rooms(data: Dictionary) -> Dictionary:
	var stats := {"rooms": 0, "placed": 0, "need_missing": 0, "boxes_in": 0, "boxes_near": 0}
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
			for i: int in idxs:
				if drop.has(i):
					continue
				var rect: Rect2i = _rect(props[i].get("rect"))
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
			for item: Dictionary in PALETTE[cls]:
				var size: Vector2i = item["size"]
				var a := size.x * size.y
				if used + a > cap or float(area - used - a) < area * floor_min:
					if item.get("need", false):
						stats["need_missing"] += 1
					continue
				var cands := _candidates(g, of, ri, cells, item, forbid, taken, keys["seeds"], stove_cells, box_at)
				var tries: Array = []
				if not cands.is_empty():
					var top := mini(3, cands.size())
					var pick := rng.randi_range(0, top - 1)
					tries.append(cands[pick])
					for k in range(mini(6, cands.size())):
						if k != pick:
							tries.append(cands[k])
				var ok := false
				for cand: Dictionary in tries:
					var r: Rect2i = cand["rect"]
					for y in range(r.position.y, r.end.y):
						for x in range(r.position.x, r.end.x):
							g.set_solid(Vector2i(x, y), S.LOW)
					rects.append(r)
					if _still_open(g, of, ri, keys, before, rects):
						ok = true
						placed.append({"item": item, "rect": r, "facing": cand["facing"]})
						for y in range(r.position.y, r.end.y):
							for x in range(r.position.x, r.end.x):
								taken[Vector2i(x, y)] = true
						used += a
						if item["kind"] == "cold_stove":
							stove_cells.append(r.position)
						break
					rects.pop_back()
					for y in range(r.position.y, r.end.y):
						for x in range(r.position.x, r.end.x):
							g.set_solid(Vector2i(x, y), S.NONE)
				if not ok and item.get("need", false):
					stats["need_missing"] += 1
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


const ROOM_LABEL: Dictionary = {"bed": "살림방", "kitchen": "부엌", "living": "거실", "shop": "매장", "storage": "창고", "store": "저장 칸"}
const KIND_LABEL: Dictionary = {
	"bed": "침대", "wardrobe": "장롱", "blanket_chest": "담요 궤", "bookcase": "책장", "bench": "긴 의자",
	"cold_stove": "꺼진 난로", "jar_shelf": "항아리 선반", "dining_set": "식탁과 의자", "fridge_open": "문 열린 냉장고",
	"barrel": "통", "radio_set": "라디오", "shop_counter": "계산대", "display_shelf": "진열 선반",
	"crate_stack": "상자 더미", "shelf": "선반", "sack_pile": "자루 더미", "tin_crate": "나무 궤",
}
