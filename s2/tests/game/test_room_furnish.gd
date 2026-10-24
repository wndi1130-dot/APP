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


## 80장: 열차 문에서 걸어서(층 사이는 계단) 모든 상자에 닿는다. 몸을 막는 가구는 벽 속에
## 없고, 문 안쪽 두 칸은 걸어서 지나간다.
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
		assert_eq(_faults(d), [], id + ": 벽 속 가구, 막힌 문 앞")


## 집 가구(다시 놓는 종류, 담는 가구, 큰 가구)가 벽·문·창 칸에 걸친 곳과, 문 안쪽 두
## 칸(같은 방)이 막힌 문. 벽선에 걸쳐 세운 기계·탈것·기둥·문짝은 지도 그대로라 안 본다.
func _faults(d: Dictionary) -> Array:
	var out: Array = []
	for p: Dictionary in d["props"]:
		var lv := int(p.get("level", 0))
		var kind := String(p.get("kind", ""))
		var r: Variant = RoomFurnish._rect(p.get("rect"))
		if r == null or not d["levels"].has(lv) or not RoomFurnish.blocks(kind, lv):
			continue
		if not (RoomFurnish.REPLACED.has(kind) or RoomFurnish.HOLDER_KINDS.has(kind) or RoomFurnish.TALL_KINDS.has(kind)):
			continue
		var g: FieldGrid = d["levels"][lv]
		var rect: Rect2i = r
		if g.building_at(rect.position + rect.size / 2) < 0:
			continue
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var s := g.solid_at(Vector2i(x, y))
				if s == S.WALL or s == S.DOOR or s == S.WINDOW:
					out.append("%s %d %s 벽 속" % [p["kind"], lv, Vector2i(x, y)])
	for lv: int in d["levels"]:
		var g: FieldGrid = d["levels"][lv]
		var map := RoomFurnish.rooms_of(g)
		var of: PackedInt32Array = map["of"]
		for dc: Vector2i in g.doors:
			for dd in DIRS:
				var n := dc + dd
				var ri := RoomFurnish._at(g, of, n)
				if ri < 0:
					continue
				for fc: Vector2i in [n, n + dd]:
					if RoomFurnish._at(g, of, fc) == ri and not g.people_can_walk(fc):
						out.append("문 %d %s 앞 %s" % [lv, dc, fc])
	return out


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


func test_a_box_in_a_room_left_as_it_is_goes_into_its_cabinet() -> void:
	var d := _house()
	# 다시 놓지 않는 방(이름 없는 서류 방): 서류장 (2, 2)~(3, 2), 상자는 바닥 (5, 3).
	d["props"].append({"kind": "file_cabinet", "rect": Rect2i(2, 2, 2, 1), "solid": "none", "facing": 0, "level": 0})
	d["containers"]["c"] = {"id": "c", "cell": Vector2i(5, 3), "level": 0, "items": ["paper"]}
	RoomFurnish.block_furniture_with(d, _model)
	assert_eq(RoomFurnish.boxes_into_furniture(d), 1)
	var box: Dictionary = d["containers"]["c"]
	assert_eq(box["furniture"], "file_cabinet")
	assert_true(Rect2i(2, 2, 2, 1).has_point(box["cell"]))
	assert_eq(box["items"], ["paper"])


## 문 앞 비움(3장): 문 안쪽 2칸 × 3칸, 계단과 그 둘레. 창 앞은 큰 가구만.
func _front_clear(g: FieldGrid) -> bool:
	for c: Vector2i in [Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3)]:
		if g.solid_at(c) != S.NONE:
			return false
	return true


func test_a_shelf_in_the_doorway_is_moved_aside_with_its_box() -> void:
	var d := _house()
	# 문 (4, 5) 안쪽 둘째 줄에 선 선반, 그 안에 상자.
	d["props"].append(_prop("shelf", Rect2i(3, 3, 3, 1), 0))
	d["containers"]["c"] = {"id": "c", "cell": Vector2i(4, 3), "level": 0}
	var stats := RoomFurnish.clear_fronts(d)
	assert_eq(stats["moved"], 1)
	var r: Rect2i = d["props"][0]["rect"]
	assert_eq(r, Rect2i(2, 2, 3, 1), "가까운 빈 자리, 계단 둘레(5, 2)는 피함")
	assert_eq(d["containers"]["c"]["cell"], Vector2i(3, 2), "상자도 같이")
	RoomFurnish.block_furniture_with(d, _model)
	assert_true(_front_clear(d["levels"][0]), "문 앞 2×3이 빔")
	assert_eq(d["levels"][0].solid_at(Vector2i(2, 2)), S.LOW, "옮긴 자리에서 몸을 막음")


func _with_window(d: Dictionary) -> Dictionary:
	var g: FieldGrid = d["levels"][0]
	var w := Vector2i(1, 3)
	g.set_solid(w, S.WINDOW)
	g.windows[w] = {"broken": false, "glass": false, "building": 0, "cell": w}
	g.refresh_paths()
	return d


func test_a_tall_piece_leaves_the_window_and_a_low_one_stays() -> void:
	var d := _with_window(_house())
	d["props"].append(_prop("wardrobe", Rect2i(2, 3, 1, 1), 0))
	assert_eq(RoomFurnish.clear_fronts(d)["moved"], 1)
	assert_eq(d["props"][0]["rect"], Rect2i(2, 2, 1, 1), "창 앞을 비우고 귀퉁이 벽으로")
	var e := _with_window(_house())
	e["props"].append(_prop("bed", Rect2i(2, 3, 1, 1), 0))
	var stats := RoomFurnish.clear_fronts(e)
	assert_eq(stats["moved"] + stats["removed"] + stats["left"], 0, "낮은 가구는 창 앞에 있어도 된다")
	assert_eq(e["props"][0]["rect"], Rect2i(2, 3, 1, 1))


func test_a_piece_half_in_the_wall_comes_into_the_room() -> void:
	var d := _house()
	# 작업대 (1, 3)~(2, 3): 서쪽 벽 칸에 반이 박혔다.
	d["props"].append(_prop("workbench", Rect2i(1, 3, 2, 1), 0))
	assert_eq(RoomFurnish.clear_fronts(d)["moved"], 1)
	assert_eq(d["props"][0]["rect"], Rect2i(2, 2, 2, 1), "벽에서 나와 북쪽 벽에 붙음")
	assert_eq(d["levels"][0].solid_at(Vector2i(1, 3)), S.WALL, "벽은 그대로")


func test_a_later_piece_does_not_close_the_front_of_one_already_standing() -> void:
	var d := _house()
	# 귀퉁이 (2, 2)에 이미 몸을 막는 장롱. 그 앞 두 칸을 다 막는 통 둘 가운데 둘째는 남는다.
	d["props"].append(_prop("wardrobe", Rect2i(2, 2, 1, 1), 0))
	d["levels"][0].set_solid(Vector2i(2, 2), S.LOW)
	d["props"].append(_prop("barrel", Rect2i(3, 2, 1, 1), 0))
	d["props"].append(_prop("barrel", Rect2i(2, 3, 1, 1), 0))
	var stats := RoomFurnish.block_furniture_with(d, _model)
	assert_eq(stats["painted"], 1)
	assert_eq(stats["kept_path"], 1)


func test_rooms_of_one_use_get_different_sets_by_seed() -> void:
	var sets: Dictionary = {}
	for n in range(12):
		var d := _bedroom()
		d["place_id"] = "houses_%02d" % n
		d["containers"] = {}
		RoomFurnish.furnish_rooms(d)
		var kinds: Array = []
		for p: Dictionary in d["props"]:
			kinds.append(p["kind"])
		kinds.sort()
		assert_has(kinds, "bed")
		assert_has(kinds, "wardrobe")
		sets[str(kinds)] = true
	assert_gt(sets.size(), 2, "덤 가구는 방마다 굴린다")


func test_a_needed_piece_takes_a_shorter_shape_on_a_short_wall() -> void:
	# 3×4 매장(x 2~4, y 2~5), 문은 남쪽 (3, 6). 문 앞 두 줄을 비우면 계산대가 북쪽 벽을
	# 다 쓰고, 4칸짜리 진열 선반은 어느 벽에도 안 들어간다.
	var g := FieldGrid.new(7, 8)
	for y in range(8):
		for x in range(7):
			var c := Vector2i(x, y)
			if x >= 1 and x <= 5 and y >= 1 and y <= 6:
				g.building[g.index(c)] = 0
				var wall: bool = x == 1 or x == 5 or y == 1 or y == 6
				g.set_solid(c, S.WALL if wall else S.NONE)
	var door := Vector2i(3, 6)
	g.set_solid(door, S.DOOR)
	g.doors[door] = {"state": "closed", "hp": 8, "building": 0, "cell": door}
	g.refresh_paths()
	var d := {"grid": g, "levels": {0: g}, "stairs": [], "low_blocks": [], "place_id": "houses_99", "containers": {},
		"props": [{"kind": "shop_counter", "rect": Rect2i(2, 2, 1, 1), "solid": "none", "facing": 0, "note": "매장의 계산대", "level": 0}]}
	var stats := RoomFurnish.furnish_rooms(d)
	assert_eq(stats["need_missing"], 0, str(stats["missing"]))
	var shelf: Variant = null
	for p: Dictionary in d["props"]:
		if p["kind"] == "display_shelf":
			shelf = p
	assert_not_null(shelf, "진열 선반이 있다")
	if shelf != null:
		var r: Rect2i = shelf["rect"]
		assert_lt(maxi(r.size.x, r.size.y), 4, "짧은 꼴")


func test_a_long_rack_in_the_doorway_turns_to_stand_by_the_side_wall() -> void:
	# 5×4 방(x 2~6, y 2~5), 문 (4, 6). 북쪽 두 줄은 작업대가 차지했다.
	var g := FieldGrid.new(9, 8)
	for y in range(8):
		for x in range(9):
			var c := Vector2i(x, y)
			if x >= 1 and x <= 7 and y >= 1 and y <= 6:
				g.building[g.index(c)] = 0
				var wall: bool = x == 1 or x == 7 or y == 1 or y == 6
				g.set_solid(c, S.WALL if wall else S.NONE)
	var door := Vector2i(4, 6)
	g.set_solid(door, S.DOOR)
	g.doors[door] = {"state": "closed", "hp": 8, "building": 0, "cell": door}
	g.refresh_paths()
	var d := {"grid": g, "levels": {0: g}, "stairs": [], "low_blocks": [], "containers": {},
		"props": [_prop("workbench", Rect2i(2, 2, 5, 1), 0), _prop("workbench", Rect2i(4, 3, 3, 1), 0),
			_prop("cloth_bolt_rack", Rect2i(2, 4, 3, 1), 0)]}
	d["containers"]["c"] = {"id": "c", "cell": Vector2i(4, 4), "level": 0}
	assert_eq(RoomFurnish.clear_fronts(d)["moved"], 1)
	var rack: Dictionary = d["props"][2]
	assert_eq(rack["rect"], Rect2i(2, 3, 1, 3), "옆벽에 세로로")
	assert_eq(rack["facing"], 3, "등은 서쪽 벽")
	assert_true((rack["rect"] as Rect2i).has_point(d["containers"]["c"]["cell"]), "든 상자도 가구 안")
