extends "res://addons/gut/test.gd"
## 집 안 가구는 몸을 막는다(docs/design/briefs/house_layout.md 1장). 위층·지하도
## 땅 층처럼 막고, 길을 끊는 가구와 안 보이는 가구는 막지 않는다.

const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")
const S = FieldGrid.Solid
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func _model(kind: String) -> String:
	return "" if kind == "unmodelled_box" else "res://test/" + kind + ".glb"


## 집 한 채(9×7 칸): 바깥벽, 땅 층 남쪽 문 하나, 방 안은 x 2~6 · y 2~4.
## 계단은 (6, 2)에서 땅 층과 2층을 잇는다.
func _house() -> Dictionary:
	var levels: Dictionary = {}
	for lv in [0, 1]:
		var g := FieldGrid.new(9, 7)
		for y in range(7):
			for x in range(9):
				var c := Vector2i(x, y)
				if x >= 1 and x <= 7 and y >= 1 and y <= 5:
					g.building[g.index(c)] = 0
					var wall: bool = x == 1 or x == 7 or y == 1 or y == 5
					g.set_solid(c, S.WALL if wall else S.NONE)
		levels[lv] = g
	var door := Vector2i(4, 5)
	levels[0].set_solid(door, S.DOOR)
	levels[0].doors[door] = {"state": "closed", "hp": 8, "building": 0, "cell": door}
	for g: FieldGrid in levels.values():
		g.refresh_paths()
	return {"grid": levels[0], "levels": levels, "props": [], "containers": {}, "low_blocks": [],
		"stairs": [{"cell": Vector2i(6, 2), "low": 0, "high": 1, "ladder": false}]}


func _prop(kind: String, rect: Rect2i, lv: int) -> Dictionary:
	return {"kind": kind, "rect": rect, "solid": "none", "facing": 0, "level": lv}


func test_upper_floor_furniture_with_a_model_blocks() -> void:
	var d := _house()
	d["props"].append(_prop("bed", Rect2i(2, 3, 2, 1), 1))
	var stats := RoomFurnish.block_furniture_with(d, _model)
	assert_eq(stats["painted"], 1)
	assert_eq(d["levels"][1].solid_at(Vector2i(2, 3)), S.LOW)
	assert_eq(d["levels"][1].solid_at(Vector2i(3, 3)), S.LOW)
	assert_false(d["levels"][1].people_can_walk(Vector2i(3, 3)), "길 찾기도 새 값")
	assert_true(d["low_blocks"].is_empty(), "위층은 땅 층 엄폐 목록에 안 들어감")


func test_upper_floor_furniture_without_a_model_is_not_an_unseen_wall() -> void:
	var d := _house()
	d["props"].append(_prop("unmodelled_box", Rect2i(2, 3, 1, 1), 1))
	d["props"].append(_prop("unmodelled_box", Rect2i(2, 3, 1, 1), 0))
	var stats := RoomFurnish.block_furniture_with(d, _model)
	assert_eq(stats["no_model"], 1)
	assert_eq(d["levels"][1].solid_at(Vector2i(2, 3)), S.NONE, "안 보이면 안 막는다")
	assert_eq(d["levels"][0].solid_at(Vector2i(2, 3)), S.LOW, "땅 층은 회색 덩이로 보이니 막는다")
	assert_eq(d["low_blocks"], [Rect2i(2, 3, 1, 1)])


func test_flat_and_wall_things_never_block() -> void:
	var d := _house()
	d["props"].append(_prop("blanket_curtain", Rect2i(2, 3, 2, 1), 1))
	d["props"].append(_prop("notice_board", Rect2i(5, 3, 1, 1), 0))
	var stats := RoomFurnish.block_furniture_with(d, _model)
	assert_eq(stats["painted"], 0)
	assert_eq(d["levels"][1].solid_at(Vector2i(2, 3)), S.NONE)
	assert_eq(d["levels"][0].solid_at(Vector2i(5, 3)), S.NONE)


func test_furniture_that_would_cut_the_way_in_is_left_walkable() -> void:
	var d := _house()
	# 침대는 칠해도 되고, 방을 가로지르는 선반은 문(4, 5)과 계단(6, 2)을 갈라놓는다.
	d["props"].append(_prop("bed", Rect2i(2, 2, 2, 1), 0))
	d["props"].append(_prop("shelf", Rect2i(2, 3, 5, 1), 0))
	var stats := RoomFurnish.block_furniture_with(d, _model)
	assert_eq(stats["painted"], 1)
	assert_eq(stats["kept_path"], 1)
	assert_eq(d["levels"][0].solid_at(Vector2i(2, 2)), S.LOW)
	assert_eq(d["levels"][0].solid_at(Vector2i(4, 3)), S.NONE)


func test_furniture_in_front_of_the_door_or_on_the_stairs_is_left() -> void:
	var d := _house()
	d["props"].append(_prop("wardrobe", Rect2i(4, 4, 1, 1), 0))
	d["props"].append(_prop("desk", Rect2i(6, 2, 1, 1), 1))
	var stats := RoomFurnish.block_furniture_with(d, _model)
	assert_eq(stats["kept_path"], 2)
	assert_eq(d["levels"][0].solid_at(Vector2i(4, 4)), S.NONE, "문 안쪽 칸")
	assert_eq(d["levels"][1].solid_at(Vector2i(6, 2)), S.NONE, "계단 칸")


func test_a_box_stays_reachable() -> void:
	var d := _house()
	# 상자는 (2, 2) 구석. 그 둘레를 다 막는 두 가구 가운데 둘째는 남는다.
	d["containers"]["c"] = {"cell": Vector2i(2, 2), "level": 0}
	d["props"].append(_prop("barrel", Rect2i(3, 2, 1, 1), 0))
	d["props"].append(_prop("barrel", Rect2i(2, 3, 1, 1), 0))
	var stats := RoomFurnish.block_furniture_with(d, _model)
	assert_eq(stats["painted"], 1)
	assert_eq(stats["kept_path"], 1)


func test_same_map_gives_the_same_cells() -> void:
	var a := FieldMaps.build("houses_01")
	var b := FieldMaps.build("houses_01")
	for lv: int in a["levels"]:
		assert_eq(a["levels"][lv].solid, b["levels"][lv].solid, "층 %d" % lv)
	assert_eq(a["furniture_stats"], b["furniture_stats"])


func test_the_first_stop_keeps_its_own_cells() -> void:
	var d := FieldMaps.build(FieldMaps.DEFAULT_PLACE)
	assert_false(d.has("furniture_stats"))


## 80장: 열차 문에서 걸어서(층 사이는 계단) 모든 상자에 닿는다.
func test_every_map_keeps_every_box_reachable_from_the_train() -> void:
	for id in FieldMaps.ids():
		if id == FieldMaps.DEFAULT_PLACE:
			continue
		var d := FieldMaps.build(id)
		assert_true(d.has("furniture_stats"), id)
		var seen := _reach_all(d)
		var missed: Array = []
		for box: Dictionary in d["containers"].values():
			var c: Vector2i = box["cell"]
			var lv := int(box.get("level", 0))
			var hit := false
			for n: Vector2i in [c, c + DIRS[0], c + DIRS[1], c + DIRS[2], c + DIRS[3]]:
				hit = hit or seen.has(Vector3i(n.x, n.y, lv))
			if not hit:
				missed.append(c)
		assert_eq(missed, [], id + ": 닿지 않는 상자")


func _reach_all(d: Dictionary) -> Dictionary:
	var levels: Dictionary = d["levels"]
	var links: Dictionary = {}
	for st: Dictionary in d["stairs"]:
		var c: Vector2i = st["cell"]
		var a := Vector3i(c.x, c.y, int(st["low"]))
		var b := Vector3i(c.x, c.y, int(st["high"]))
		links[a] = links.get(a, []) + [b]
		links[b] = links.get(b, []) + [a]
	var g0: FieldGrid = levels[0]
	var seeds: Array = []
	for side in d["train_doors"]:
		seeds.append_array(d["train_doors"][side])
	seeds.append_array(d["spawns"].get("squad", []))
	var seen: Dictionary = {}
	var queue: Array[Vector3i] = []
	for s: Vector2i in seeds:
		var c := g0.nearest_walkable(s, false, 3)
		var k := Vector3i(c.x, c.y, 0)
		if g0.people_can_walk(c) and not seen.has(k):
			seen[k] = true
			queue.append(k)
	var head := 0
	while head < queue.size():
		var cur: Vector3i = queue[head]
		head += 1
		var nexts: Array = links.get(cur, []).duplicate()
		for dd in DIRS:
			nexts.append(Vector3i(cur.x + dd.x, cur.y + dd.y, cur.z))
		for n: Vector3i in nexts:
			if not seen.has(n) and levels.has(n.z) and levels[n.z].people_can_walk(Vector2i(n.x, n.y)):
				seen[n] = true
				queue.append(n)
	return seen


## ---------------------------------------------------------------- 방 종류별 가구

## 침실 하나(바깥벽, 남쪽 문, 방 안 x 2~7 · y 2~5 = 6×4), 상자 하나.
func _bedroom() -> Dictionary:
	var g := FieldGrid.new(10, 8)
	for y in range(8):
		for x in range(10):
			var c := Vector2i(x, y)
			if x >= 1 and x <= 8 and y >= 1 and y <= 6:
				g.building[g.index(c)] = 0
				var wall: bool = x == 1 or x == 8 or y == 1 or y == 6
				g.set_solid(c, S.WALL if wall else S.NONE)
	var door := Vector2i(4, 6)
	g.set_solid(door, S.DOOR)
	g.doors[door] = {"state": "closed", "hp": 8, "building": 0, "cell": door}
	var win := Vector2i(8, 3)
	g.set_solid(win, S.WINDOW)
	g.windows[win] = {"broken": false, "glass": false, "building": 0, "cell": win}
	g.refresh_paths()
	return {"grid": g, "levels": {0: g}, "stairs": [], "low_blocks": [], "place_id": "houses_99",
		"containers": {"cache_0": {"id": "cache_0", "cell": Vector2i(6, 4), "level": 0, "items": ["plank"]}},
		"props": [
			{"kind": "bed", "rect": Rect2i(2, 2, 2, 1), "solid": "none", "facing": 0, "note": "안방의 침대", "level": 0},
			{"kind": "cold_stove", "rect": Rect2i(7, 5, 1, 1), "solid": "none", "facing": 0, "note": "안방의 꺼진 난로", "level": 0},
			{"kind": "wardrobe", "rect": Rect2i(2, 5, 2, 1), "solid": "none", "facing": 0, "note": "안방의 장롱", "level": 0},
		]}


func test_a_bedroom_gets_a_bed_and_a_wardrobe_by_the_rules() -> void:
	var d := _bedroom()
	var stats := RoomFurnish.furnish_rooms(d)
	assert_eq(stats["rooms"], 1)
	assert_eq(stats["need_missing"], 0)
	var kinds: Array = []
	for p: Dictionary in d["props"]:
		kinds.append(p["kind"])
		var r: Rect2i = p["rect"]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				assert_false(c == Vector2i(4, 5) or c == Vector2i(4, 4), "문 안쪽 2칸: %s %s" % [p["kind"], c])
				if p["kind"] == "wardrobe" or p["kind"] == "bookcase":
					assert_ne(c, Vector2i(7, 3), "창 앞 큰 가구")
	assert_has(kinds, "bed")
	assert_has(kinds, "wardrobe")
	assert_false(kinds.has("cold_stove"), "침실 묶음에 난로는 없다")


func test_the_box_goes_into_a_holding_piece() -> void:
	var d := _bedroom()
	RoomFurnish.furnish_rooms(d)
	var box: Dictionary = d["containers"]["cache_0"]
	assert_has(["wardrobe", "blanket_chest", "bookcase"], box.get("furniture", ""))
	var inside := false
	for p: Dictionary in d["props"]:
		if p["kind"] == box["furniture"] and (p["rect"] as Rect2i).has_point(box["cell"]):
			inside = true
	assert_true(inside, "상자 칸이 그 가구 칸 안")
	assert_eq(box["items"], ["plank"], "내용물 그대로")


func test_same_seed_same_room_other_map_other_room() -> void:
	var a := _bedroom()
	var b := _bedroom()
	var c := _bedroom()
	c["place_id"] = "houses_98"
	RoomFurnish.furnish_rooms(a)
	RoomFurnish.furnish_rooms(b)
	RoomFurnish.furnish_rooms(c)
	assert_eq(str(a["props"]), str(b["props"]))
	assert_eq(a["grid"].solid, b["grid"].solid)


func test_shop_upstairs_with_a_bed_is_a_home() -> void:
	assert_eq(RoomFurnish.room_class("매장", {"bed": true, "wardrobe": true}, 1), "bed")
	assert_eq(RoomFurnish.room_class("매장", {"shop_counter": true}, 0), "shop")
	assert_eq(RoomFurnish.room_class("부엌", {"dining_set": true}, -1), "", "지하 부엌은 카드 답 기다림")
	assert_eq(RoomFurnish.room_class("광부 숙소", {"bed": true}, 0), "bed", "광은 따로 선 낱말일 때만")
	assert_eq(RoomFurnish.room_class("", {"bed": true, "iv_stand": true}, 1), "", "병실은 그대로")
