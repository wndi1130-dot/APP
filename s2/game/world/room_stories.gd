extends RefCounted
## 방 이야기(docs/design/briefs/house_layout.md 4장, 결정 423 (9)). 살림집·가게 같은 작은 건물에
## 지도마다 건물 이야기 2~4채와 작은 이야기 3~6자리를 판마다 굴려 얹는다. 씨앗은 판 씨앗과
## 장소 id라 같은 판에서 같은 장소는 늘 같은 이야기다(이어 하기도 같다). 고른 것은 장소 상태에
## 남긴다(field_game이 영수증에 적는다). 글 없이 문·창·가구·상자로 읽힌다(결정 417).
## 물건 양은 그대로다. 이야기는 물건이 놓인 자리, 겉모습, 길, 소리만 바꾼다.
##
## 금지선(4.3): 잠긴 방 안의 망자나 시신, 밖에서 잠근 문, 다 막은 창은 넣지 않는다. 그래서
## 「안에서 막은 방」은 안에 아무도 없고(막은 사람은 창으로 나갔다), 문은 안에서 막혀 바깥
## 빗장 없이 그리며(쇠지렛대로 따거나 차서 부순다), 창 판자는 세 자리 가운데 두 장이다.

const FieldGrid = preload("res://game/world/field_grid.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")
const BuildingRules = preload("res://game/sim/building_rules.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const S = FieldGrid.Solid
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## 건물 이야기와 무게(4.2에서 지금 그릴 수 있는 셋).
const BUILDING_STORIES: Array = [["barricaded", 3], ["looted", 4], ["rushed", 3]]
const BUILDINGS_MIN: int = 2
const BUILDINGS_MAX: int = 4
const SMALL_MIN: int = 3
const SMALL_MAX: int = 6
## 이야기를 얹을 만큼 작은 건물(땅 층 방 칸 합).
const SMALL_BUILDING_CELLS: int = 600
## 이야기가 붙는 방 묶음(room_furnish 규칙 방).
const HOME_CLASSES: Dictionary = {"bed": true, "kitchen": true, "living": true, "shop": true, "storage": true}
## 안에서 막은 방이 되는 방(4.2: 침실, 창고).
const BARRICADE_CLASSES: Dictionary = {"bed": true, "storage": true}
## 창 하나 안쪽 면에 댄 판자(building_rules 한 면 넷까지). 셋째부터 시야를 막으니 둘만: 창 일부만 가린다.
const BOARDS_PER_WINDOW: int = 2
## 작은 이야기 소품. 모두 바닥에 놓여 몸을 막지 않는다. [종류, 곁에 둘 가구들]
const SMALL_PIECES: Array = [
	["hand_basket", ["bench", "bed", "wardrobe"]],
	["candle_stand", ["bed", "dining_set", "bench"]],
]
const KIND_NOTE: Dictionary = {
	"drawer_chest_spilled": "다 열린 서랍장", "table_overturned": "넘어진 탁자",
	"candle_stand": "촛대", "hand_basket": "수선 바구니", "loose_board": "들뜬 마루",
}
## 마루 밑 숨긴 칸(카드 K 가): 정차에 이 몫으로 한 곳, 사는 집 침실·거실 마루 한 칸(문·계단·창
## 앞과 가구·상자 곁 칸은 빼고). 빈 숨은 상자 하나와 들뜬 마루 소품. 속은 loot_dress가 채운다.
## 밟거나 곁을 지나면 작게 삐걱(field_game `_floor_creak`), 뒤지기는 짧다.
const STASH_CHANCE: float = 0.3
const STASH_CLASSES: Dictionary = {"bed": true, "living": true}
const STASH_SEARCH: float = 2.0
const STASH_NAME: String = "들뜬 마루 밑"


## 판 씨앗·장소로 이야기를 고르고 지도 자료에 얹는다. 돌려주는 값: 장소 상태에 남길
## [{"story": "barricaded"|"looted"|"rushed"|"small", "building": 번호}].
static func apply(data: Dictionary, dice_seed: int) -> Array:
	var levels: Dictionary = data.get("levels", {})
	if not levels.has(0):
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = dice_seed
	var city := _city(data)
	var eligible: Array = []
	var ids: Array = city["homes"].keys()
	ids.sort()
	for b: int in ids:
		if int(city["ground"].get(b, 0)) <= SMALL_BUILDING_CELLS:
			eligible.append(b)
	_shuffle(eligible, rng)
	var out: Array = []
	var want := rng.randi_range(BUILDINGS_MIN, BUILDINGS_MAX)
	var storied: Dictionary = {}
	# 건물마다 한 번 굴린다. 고른 이야기가 그 건물에 맞지 않으면 다시 뽑지 않고 빈 집으로
	# 두고(4.1) 다음 건물로 간다. 정한 수가 차거나 건물이 다하면 그친다.
	for b: int in eligible:
		if out.size() >= want:
			break
		var story := _pick(rng)
		var ok := false
		match story:
			"barricaded":
				ok = _barricaded(data, city, b, rng)
			"looted":
				ok = _looted(data, city, b, rng)
			"rushed":
				ok = _rushed(data, city, b, rng)
		if ok:
			out.append({"story": story, "building": b})
			storied[b] = true
	var small_want := rng.randi_range(SMALL_MIN, SMALL_MAX)
	var small := 0
	for b: int in eligible:
		if small >= small_want:
			break
		if not storied.has(b) and _small(data, city, b, rng):
			out.append({"story": "small", "building": b})
			small += 1
	# Last, so the stories above are the same with or without it; in a home with no story yet.
	if rng.randf() < STASH_CHANCE:
		var free: Array = []
		for b: int in eligible:
			if not out.any(func(row: Dictionary) -> bool: return row["building"] == b):
				free.append(b)
		var at := _floor_stash(data, city, free, rng)
		if at >= 0:
			out.append({"story": "floor_stash", "building": at})
	for lv: int in city["changed"]:
		(levels[lv] as FieldGrid).refresh_paths()
	return out


## 층마다 방, 건물마다 땅 층 칸 수와 살림 방([{"lv", "ri", "cls"}]).
static func _city(data: Dictionary) -> Dictionary:
	var levels: Dictionary = data["levels"]
	var maps: Dictionary = {}
	var ground: Dictionary = {}
	for lv: int in levels:
		maps[lv] = RoomFurnish.rooms_of(levels[lv])
	for room: Dictionary in maps[0]["rooms"]:
		ground[room["building"]] = int(ground.get(room["building"], 0)) + room["cells"].size()
	var cls_of: Dictionary = {}  # Vector2i(lv, ri) -> 묶음
	for p: Dictionary in data.get("props", []):
		var cls := String(p.get("rule", ""))
		var lv := int(p.get("level", 0))
		if not HOME_CLASSES.has(cls) or lv < 0 or not maps.has(lv):
			continue
		var r: Variant = RoomFurnish._rect(p.get("rect"))
		if r == null:
			continue
		var ri := RoomFurnish._at(levels[lv], maps[lv]["of"], r.position + r.size / 2)
		if ri >= 0:
			cls_of[Vector2i(lv, ri)] = cls
	var keys: Array = cls_of.keys()
	keys.sort()
	var homes: Dictionary = {}
	for key: Vector2i in keys:
		var b: int = maps[key.x]["rooms"][key.y]["building"]
		if not homes.has(b):
			homes[b] = []
		homes[b].append({"lv": key.x, "ri": key.y, "cls": cls_of[key]})
	return {"maps": maps, "ground": ground, "homes": homes, "changed": {},
		"stairs": RoomFurnish._stairs_by_level(data), "outside": _from_train(data)}


## 땅 층에서 열차 문(과 일행이 서는 자리)부터 걸어서 닿는 건물 밖 칸.
static func _from_train(data: Dictionary) -> Dictionary:
	var g: FieldGrid = data["levels"][0]
	var seeds: Array = []
	for side in data.get("train_doors", {}):
		seeds.append_array(data["train_doors"][side])
	seeds.append_array(data.get("spawns", {}).get("squad", []))
	var seen: Dictionary = {}
	var queue: Array[Vector2i] = []
	for s: Vector2i in seeds:
		var c := g.nearest_walkable(s, false, 3)
		if g.people_can_walk(c) and g.building_at(c) < 0 and not seen.has(c):
			seen[c] = true
			queue.append(c)
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		for d in DIRS:
			var n := cur + d
			if g.inside(n) and not seen.has(n) and g.building_at(n) < 0 and g.people_can_walk(n):
				seen[n] = true
				queue.append(n)
	return seen


static func _pick(rng: RandomNumberGenerator) -> String:
	var total := 0
	for row: Array in BUILDING_STORIES:
		total += int(row[1])
	var at := rng.randi_range(0, total - 1)
	for row: Array in BUILDING_STORIES:
		at -= int(row[1])
		if at < 0:
			return row[0]
	return BUILDING_STORIES[0][0]


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t


## 건물 b의 땅 층 바깥문: 바로 밖이 건물 밖 걸을 수 있는 칸인 문. 칸 차례.
## 막은 사람이 안에서 댄 판자: 창의 안쪽 면에 BOARDS_PER_WINDOW장.
static func _board_inside(g: FieldGrid, c: Vector2i) -> void:
	var outer := g.outer_face(c)
	var inner := 1 - outer if outer >= 0 else 0
	for i in range(BOARDS_PER_WINDOW):
		BuildingRules.add_plank(g.windows[c], inner)
	g.refresh_cell(c)


static func outer_doors(g: FieldGrid, b: int) -> Array:
	var out: Array = []
	for c: Vector2i in g.doors:
		if g.building_at(c) != b and int(g.doors[c].get("building", -1)) != b:
			continue
		if _opens_out(g, c):
			out.append(c)
	out.sort()
	return out


## 문·창 칸 c의 한쪽이 건물 밖 걸을 수 있는 칸인가.
static func _opens_out(g: FieldGrid, c: Vector2i) -> bool:
	for d in DIRS:
		if g.inside(c + d) and g.building_at(c + d) < 0 and g.people_can_walk(c + d):
			return true
	return false


## 문·창 칸 c의 한쪽이 열차에서 걸어서 닿는 바깥 칸인가.
static func _opens_to(c: Vector2i, outside: Dictionary) -> bool:
	for d in DIRS:
		if outside.has(c + d):
			return true
	return false


## 건물 b 안의 상자 id(잠기지 않고, 아직 안 뒤졌고, 고른 꾸러미가 아닌 것). id 차례.
static func _boxes(data: Dictionary, b: int) -> Array:
	var levels: Dictionary = data["levels"]
	var out: Array = []
	var containers: Dictionary = data.get("containers", {})
	for id: String in containers:
		var box: Dictionary = containers[id]
		var lv := int(box.get("level", 0))
		var c: Variant = RoomFurnish._cell(box.get("cell"))
		if c == null or not levels.has(lv) or box.has("pick") or bool(box.get("searched", false)) or bool(box.get("locked", false)):
			continue
		if (levels[lv] as FieldGrid).building_at(c) == b:
			out.append(id)
	out.sort()
	return out


## 상자가 든 방(층, 방 번호). 방 밖이면 방 번호 -1.
static func _room_of_box(data: Dictionary, city: Dictionary, id: String) -> Vector2i:
	var box: Dictionary = data["containers"][id]
	var lv := int(box.get("level", 0))
	if not city["maps"].has(lv):
		return Vector2i(lv, -1)
	return Vector2i(lv, RoomFurnish._at(data["levels"][lv], city["maps"][lv]["of"], RoomFurnish._cell(box["cell"])))


## ---------------------------------------------------------------- 안에서 막은 방

## 안에서 막은 방(4.2): 땅 층 침실이나 창고 하나. 문은 안에서 막혀 안 열리고(따거나 차서
## 부순다), 막은 사람이 나간 창 하나는 깨져 열려 있고, 바깥 창 절반에 판자(창 하나뿐이면 그
## 창에). 그 건물 다른 상자 몫의 절반이 이 방 상자로 모인다. 안에 사람·시신·망자는 없다.
static func _barricaded(data: Dictionary, city: Dictionary, b: int, rng: RandomNumberGenerator) -> bool:
	var rooms: Array = []
	for room: Dictionary in city["homes"][b]:
		if room["lv"] == 0 and BARRICADE_CLASSES.has(room["cls"]):
			rooms.append(room)
	_shuffle(rooms, rng)
	for room: Dictionary in rooms:
		if _barricade_room(data, city, b, room):
			return true
	return false


static func _barricade_room(data: Dictionary, city: Dictionary, b: int, room: Dictionary) -> bool:
	var g: FieldGrid = data["levels"][0]
	var map: Dictionary = city["maps"][0]
	var of: PackedInt32Array = map["of"]
	var ri: int = room["ri"]
	var cells: Array[Vector2i] = map["rooms"][ri]["cells"]
	var stairs: Dictionary = city["stairs"].get(0, {})
	var doors: Dictionary = {}
	var windows: Dictionary = {}
	for c in cells:
		if stairs.has(c):
			return false
		for d in DIRS:
			var n := c + d
			if RoomFurnish._at(g, of, n) == ri:
				continue
			if g.doors.has(n):
				if stairs.has(n):
					return false  # 계단이 문 칸에서 오른다: 막으면 위층이 끊긴다
				doors[n] = true
			elif g.windows.has(n):
				if _opens_to(n, city["outside"]):
					windows[n] = true
			elif g.people_can_walk(n):
				return false  # 문 없이 뚫린 곳: 막을 수 없는 방
	var box_ids: Array = []
	for id: String in _boxes(data, b):
		if _room_of_box(data, city, id) == Vector2i(0, ri):
			box_ids.append(id)
	if doors.is_empty() or windows.is_empty() or box_ids.is_empty():
		return false
	# 지도가 이 방에 둔 망자가 있으면 막지 않는다(금지선: 잠긴 방 안의 망자).
	var room_cells: Dictionary = {}
	for c in cells:
		room_cells[c] = true
	for row: Variant in data.get("spawns", {}).get("dead_levels", []):
		if int(row[1]) == 0 and room_cells.has(row[0]):
			return false
	var wins: Array = windows.keys()
	wins.sort()
	var exit: Vector2i = wins[0]
	# 막고 나서도 건물의 다른 칸은 다 걸어서 닿고, 이 방은 나간 창으로 닿아야 한다.
	var before := _reach(g, b, {}, city["outside"])
	var shut: Dictionary = {exit: true}
	for c: Vector2i in doors:
		shut[c] = false
	var after := _reach(g, b, shut, city["outside"])
	var room_in := false
	for c in cells:
		room_in = room_in or after.has(c)
	if not room_in:
		return false
	for c: Vector2i in before:
		if RoomFurnish._at(g, of, c) != ri and not doors.has(c) and not after.has(c):
			return false
	for c: Vector2i in doors:
		g.doors[c]["barred"] = "inside"
		g.set_door_state(c, "locked")
	# 나간 창은 비워 둔다(판자가 한 장이라도 있으면 못 지난다). 다른 창은 하나 걸러 판자.
	# 창이 하나뿐인 방은 판자 친 창 없이 나간 창(창틀의 밧줄)만 바깥 흔적이 된다.
	g.break_window(exit)
	for k in range(1, wins.size(), 2):
		_board_inside(g, wins[k])
	g.revision += 1
	# 다른 상자마다 절반(내림)을 이 방 첫 상자로.
	var into: String = box_ids[0]
	var gathered: Array = (data["containers"][into].get("items", []) as Array).duplicate()
	for id: String in _boxes(data, b):
		if box_ids.has(id):
			continue
		var box: Dictionary = data["containers"][id].duplicate(true)
		# 생필품(결정 490, 차림 맨 끝에 붙음)은 세지도 옮기지도 않는다 — 다른 물건이 생필품을 켜든 끄든 같은 자리로 간다.
		var items: Array = []
		var supplies: Array = []
		for item: Variant in box.get("items", []):
			(supplies if FieldItems.group(String(item)) == "supplies" else items).append(item)
		var move := int(items.size() / 2.0)
		gathered.append_array(items.slice(items.size() - move))
		box["items"] = items.slice(0, items.size() - move) + supplies
		data["containers"][id] = box
	var target: Dictionary = data["containers"][into].duplicate(true)
	target["items"] = gathered
	data["containers"][into] = target
	return true


## 건물 b 땅 층에서 열차 쪽 바깥(outside)으로 난 문·창으로 걸어 들어가 닿는 칸.
## over: 칸 -> 걸을 수 있나(덮어쓰기).
static func _reach(g: FieldGrid, b: int, over: Dictionary, outside: Dictionary) -> Dictionary:
	var seen: Dictionary = {}
	var queue: Array[Vector2i] = []
	var mine := func(c: Vector2i) -> bool:
		if g.building_at(c) == b:
			return true
		if g.doors.has(c):
			return int(g.doors[c].get("building", -1)) == b
		if g.windows.has(c):
			return int(g.windows[c].get("building", -1)) == b
		return false
	var walk := func(c: Vector2i) -> bool:
		return bool(over[c]) if over.has(c) else g.people_can_walk(c)
	for c: Vector2i in g.doors.keys() + g.windows.keys():
		if mine.call(c) and _opens_to(c, outside) and walk.call(c) and not seen.has(c):
			seen[c] = true
			queue.append(c)
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		for d in DIRS:
			var n := cur + d
			if g.inside(n) and not seen.has(n) and mine.call(n) and walk.call(n):
				seen[n] = true
				queue.append(n)
	return seen


## ---------------------------------------------------------------- 털린 집

## 털린 집(4.2): 상자는 다 비어 뒤진 채고, 그 몫이 숨긴 자리 하나(가장 높은 층, 같으면
## 살림방의 상자)에 모인다. 바깥문 하나가 부서졌고, 다 열린 서랍장과 넘어진 탁자.
static func _looted(data: Dictionary, city: Dictionary, b: int, rng: RandomNumberGenerator) -> bool:
	var boxes := _boxes(data, b)
	var doors := outer_doors(data["levels"][0], b)
	if boxes.size() < 2 or doors.is_empty():
		return false
	var hidden: String = boxes[0]
	var best: int = -1000000
	for id: String in boxes:
		var at := _room_of_box(data, city, id)
		var score: int = at.x * 10 + (1 if _class_at(city, b, at) == "bed" else 0)
		if score > best:
			best = score
			hidden = id
	var gathered: Array = []
	for id: String in boxes:
		var box: Dictionary = data["containers"][id].duplicate(true)
		gathered.append_array(box.get("items", []))
		if id != hidden:
			box["items"] = []
			box["searched"] = true
		data["containers"][id] = box
	data["containers"][hidden]["items"] = gathered
	(data["levels"][0] as FieldGrid).set_door_state(doors[0], "broken")
	for room: Dictionary in city["homes"][b]:
		if room["cls"] in ["bed", "living"]:
			if _place(data, city, room, "drawer_chest_spilled", [Vector2i.ONE], true, rng) != null:
				break
	for room: Dictionary in city["homes"][b]:
		if room["cls"] in ["living", "kitchen"]:
			if _place(data, city, room, "table_overturned", [Vector2i(2, 1), Vector2i(1, 2)], true, rng) != null:
				break
	return true


static func _class_at(city: Dictionary, b: int, at: Vector2i) -> String:
	for room: Dictionary in city["homes"].get(b, []):
		if room["lv"] == at.x and room["ri"] == at.y:
			return room["cls"]
	return ""


## ---------------------------------------------------------------- 급히 떠난 부엌, 작은 이야기

## 급히 떠난 부엌(4.2): 식탁 곁에 넘어진 탁자가 길을 꺾는다. 식탁은 덤 가구라 부엌이나
## 거실(식탁 방)에 있는 것을 쓴다. 양 그대로, 바깥 흔적 없음.
static func _rushed(data: Dictionary, city: Dictionary, b: int, rng: RandomNumberGenerator) -> bool:
	for room: Dictionary in city["homes"][b]:
		if room["cls"] != "kitchen" and room["cls"] != "living":
			continue
		var near := _pieces_in(data, city, room, ["dining_set"])
		if not near.is_empty() and _place(data, city, room, "table_overturned", [Vector2i(2, 1), Vector2i(1, 2)], true, rng, near) != null:
			return true
	return false


## 작은 이야기(4.1): 살림 방 하나, 가구 곁 한 자리에 바닥 소품 하나. 양 그대로.
static func _small(data: Dictionary, city: Dictionary, b: int, rng: RandomNumberGenerator) -> bool:
	var rooms: Array = (city["homes"][b] as Array).duplicate()
	_shuffle(rooms, rng)
	var row: Array = SMALL_PIECES[rng.randi_range(0, SMALL_PIECES.size() - 1)]
	for room: Dictionary in rooms:
		var near := _pieces_in(data, city, room, row[1])
		if not near.is_empty() and _place(data, city, room, row[0], [Vector2i.ONE], false, rng, near) != null:
			return true
	return false


## 마루 밑 숨긴 칸 하나(카드 K): 건물 차례대로, 침실·거실을 섞어 처음 맞는 마루 칸. 건물 번호, 없으면 -1.
static func _floor_stash(data: Dictionary, city: Dictionary, eligible: Array, rng: RandomNumberGenerator) -> int:
	for b: int in eligible:
		var rooms: Array = []
		for room: Dictionary in city["homes"][b]:
			if STASH_CLASSES.has(room["cls"]):
				rooms.append(room)
		_shuffle(rooms, rng)
		for room: Dictionary in rooms:
			var free := _open_floor(data, city, room)
			if free.is_empty():
				continue
			var c: Vector2i = free[rng.randi_range(0, free.size() - 1)]
			var lv: int = room["lv"]
			var id := "floor_stash_%d" % b
			data["containers"][id] = {"id": id, "name": STASH_NAME, "cell": c, "level": lv, "building": b,
				"search": STASH_SEARCH, "items": [], "locked": false, "searched": false, "furniture": "loose_board", "stash": "floor"}
			data["props"].append({"kind": "loose_board", "rect": Rect2i(c, Vector2i.ONE), "solid": "none",
				"facing": rng.randi_range(0, 3), "level": lv, "building": b, "note": KIND_NOTE["loose_board"], "story": true})
			data.get_or_add("floor_stashes", []).append({"id": id, "cell": c, "level": lv})
			return b
	return -1


## 방의 빈 마루 칸 가운데 비울 칸(문·계단·창 앞)도, 가구·상자 칸과 그 곁도 아닌 칸.
static func _open_floor(data: Dictionary, city: Dictionary, room: Dictionary) -> Array[Vector2i]:
	var lv: int = room["lv"]
	var ri: int = room["ri"]
	var g: FieldGrid = data["levels"][lv]
	var map: Dictionary = city["maps"][lv]
	var of: PackedInt32Array = map["of"]
	var cells: Array[Vector2i] = map["rooms"][ri]["cells"]
	var forbid := RoomFurnish._forbidden(g, of, ri, cells, city["stairs"].get(lv, {}))
	var near: Dictionary = {}
	for p: Dictionary in data["props"]:
		var pr: Variant = RoomFurnish._rect(p.get("rect"))
		if int(p.get("level", 0)) != lv or pr == null:
			continue
		var grown: Rect2i = (pr as Rect2i).grow(1)
		for y in range(grown.position.y, grown.end.y):
			for x in range(grown.position.x, grown.end.x):
				near[Vector2i(x, y)] = true
	for id: String in data.get("containers", {}):
		var box: Dictionary = data["containers"][id]
		var bc: Variant = RoomFurnish._cell(box.get("cell"))
		if int(box.get("level", 0)) == lv and bc != null:
			for y in range(-1, 2):
				for x in range(-1, 2):
					near[(bc as Vector2i) + Vector2i(x, y)] = true
	var out: Array[Vector2i] = []
	for c in cells:
		if g.solid_at(c) == S.NONE and not forbid.has(c) and not near.has(c):
			out.append(c)
	return out


## 방 안의 그 종류 가구 rect들.
static func _pieces_in(data: Dictionary, city: Dictionary, room: Dictionary, kinds: Array) -> Array:
	var lv: int = room["lv"]
	var g: FieldGrid = data["levels"][lv]
	var of: PackedInt32Array = city["maps"][lv]["of"]
	var out: Array = []
	for p: Dictionary in data["props"]:
		if int(p.get("level", 0)) != lv or not kinds.has(String(p.get("kind", ""))):
			continue
		var r: Variant = RoomFurnish._rect(p.get("rect"))
		if r != null and RoomFurnish._at(g, of, r.position + r.size / 2) == room["ri"]:
			out.append(r)
	return out


## 이야기 소품 하나를 방에 놓는다. near가 있으면 그 가구에 맞닿은 자리만. 비울 칸(문·계단·창
## 앞), 다른 소품·가구·상자 칸은 피하고, 몸을 막는 것은 막아도 방의 출입구·계단·상자·먼저 선
## 가구로 가는 길이 남는 자리만. 놓은 rect 또는 null.
static func _place(data: Dictionary, city: Dictionary, room: Dictionary, kind: String, sizes: Array,
		stops: bool, rng: RandomNumberGenerator, near: Array = []) -> Variant:
	var lv: int = room["lv"]
	var ri: int = room["ri"]
	var g: FieldGrid = data["levels"][lv]
	var map: Dictionary = city["maps"][lv]
	var of: PackedInt32Array = map["of"]
	var cells: Array[Vector2i] = map["rooms"][ri]["cells"]
	var stairs: Dictionary = city["stairs"].get(lv, {})
	var forbid := RoomFurnish._forbidden(g, of, ri, cells, stairs)
	var taken: Dictionary = {}
	var rects: Array = []
	for p: Dictionary in data["props"]:
		if int(p.get("level", 0)) != lv:
			continue
		var pr: Variant = RoomFurnish._rect(p.get("rect"))
		if pr == null or RoomFurnish._at(g, of, pr.position + pr.size / 2) != ri:
			continue
		rects.append(pr)
		for y in range(pr.position.y, pr.end.y):
			for x in range(pr.position.x, pr.end.x):
				taken[Vector2i(x, y)] = true
	var box_cells: Array = []
	for id: String in data.get("containers", {}):
		var box: Dictionary = data["containers"][id]
		var bc: Variant = RoomFurnish._cell(box.get("cell"))
		if int(box.get("level", 0)) == lv and bc != null and RoomFurnish._at(g, of, bc) == ri:
			box_cells.append(bc)
			taken[bc] = true
	var spots: Array = []
	for c in cells:
		for size: Vector2i in sizes:
			var r := Rect2i(c, size)
			if _free(g, of, ri, r, taken, forbid) and (near.is_empty() or _beside(r, near)):
				spots.append(r)
	if spots.is_empty():
		return null
	_shuffle(spots, rng)
	var keys := RoomFurnish._keys(g, of, ri, cells, stairs, box_cells)
	var before := RoomFurnish._from_first(g, of, ri, keys)
	var guard := RoomFurnish._standing(g, of, ri, rects, before)
	for r: Rect2i in spots.slice(0, 12):
		if stops:
			_paint(g, r, S.LOW)
			if not RoomFurnish._still_open(g, of, ri, keys, before, [r] + guard):
				_paint(g, r, S.NONE)
				continue
			city["changed"][lv] = true
			if lv == 0 and data.has("low_blocks"):
				data["low_blocks"].append(r)
		data["props"].append({"kind": kind, "rect": r, "solid": "low" if stops else "none",
			"facing": rng.randi_range(0, 3), "level": lv, "building": int(map["rooms"][ri]["building"]),
			"note": KIND_NOTE.get(kind, kind), "story": true})
		return r
	return null


static func _free(g: FieldGrid, of: PackedInt32Array, ri: int, r: Rect2i, taken: Dictionary, forbid: Dictionary) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			if RoomFurnish._at(g, of, c) != ri or g.solid_at(c) != S.NONE or taken.has(c) or forbid.has(c):
				return false
	return true


static func _beside(r: Rect2i, near: Array) -> bool:
	var grown := r.grow(1)
	for n: Rect2i in near:
		if grown.intersects(n):
			return true
	return false


static func _paint(g: FieldGrid, r: Rect2i, kind: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			g.set_solid(Vector2i(x, y), kind)
