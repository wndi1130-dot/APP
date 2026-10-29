extends "res://addons/gut/test.gd"
## 집 안 가구는 몸을 막는다(docs/design/briefs/house_layout.md 1장). 위층·지하도
## 땅 층처럼 막고, 길을 끊는 가구와 안 보이는 가구는 막지 않는다.

const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")
const FurnitureTints = preload("res://game/world/furniture_tints.gd")
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


## 80장: 열차 문에서 걸어서(층 사이는 계단, 덧문 포함) 모든 상자에 닿는다. 몸을 막는 가구는
## 벽 속에 없고, 문 안쪽 두 칸은 걸어서 지나간다. 지하에는 살림방·부엌·거실 묶음이 없다.
func test_every_map_keeps_every_box_reachable_from_the_train() -> void:
	var hatches := 0
	for id in FieldMaps.ids():
		if id == FieldMaps.DEFAULT_PLACE:
			continue
		var d := FieldMaps.build(id)
		hatches += int(d["room_stats"].get("hatches", 0))
		var cellar_homes: Array = []
		for p: Dictionary in d["props"]:
			if int(p.get("level", 0)) < 0 and ["bed", "kitchen", "living"].has(String(p.get("rule", ""))):
				cellar_homes.append(p["kind"])
		assert_eq(cellar_homes, [], id + ": 지하에 살림방·부엌·거실 묶음")
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
	assert_gt(hatches, 0, "큰 지하에 마당 쪽 덧문")


## 집 가구(다시 놓는 종류, 담는 가구, 큰 가구)가 벽·문·창 칸에 걸친 곳과, 문 안쪽 두
## 칸(같은 방, 9칸 이하·폭 두 칸 방은 한 칸)이 막힌 문. 벽선에 걸쳐 세운 기계·탈것·기둥·문짝은
## 지도 그대로라 안 본다.
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
				var cells: Array[Vector2i] = []
				cells.assign(map["rooms"][ri]["cells"])
				var small := cells.size() <= RoomFurnish.SMALL_ROOM_CELLS or RoomFurnish._narrow(cells)
				for fc: Vector2i in ([n] if small else [n, n + dd]):
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
	assert_true(kinds.has("wardrobe") or kinds.has("dresser"), "침실 필수 수납: 장롱 또는 서랍장")
	assert_false(kinds.has("cold_stove"), "침실 묶음에 난로는 없다")


func test_the_box_goes_into_a_holding_piece() -> void:
	var d := _bedroom()
	RoomFurnish.furnish_rooms(d)
	var box: Dictionary = d["containers"]["cache_0"]
	assert_has(["wardrobe", "dresser", "nightstand"], box.get("furniture", ""))
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
	assert_eq(RoomFurnish.room_class("부엌", {"dining_set": true}, -1), "boiler", "지하 부엌은 보일러실")
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
		assert_true(kinds.has("wardrobe") or kinds.has("dresser"), "침실 필수 수납")
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


## ---------------------------------------------------------------- 이름표·건물 이름으로 읽는 방

## 방 rule 묶음별 방 수(그 지도 그 건물 이름).
func _rule_rooms(d: Dictionary, building_name: String) -> Dictionary:
	var ids: Dictionary = {}
	for row: Dictionary in d.get("buildings", []):
		if String(row.get("name", "")) == building_name:
			ids[int(row["id"])] = true
	var maps: Dictionary = {}
	var seen: Dictionary = {}
	for p: Dictionary in d["props"]:
		if not p.has("rule") or not ids.has(int(p.get("building", -1))):
			continue
		var lv := int(p.get("level", 0))
		if not maps.has(lv):
			maps[lv] = RoomFurnish.rooms_of(d["levels"][lv])
		var r: Rect2i = RoomFurnish._rect(p["rect"])
		var ri := RoomFurnish._at(d["levels"][lv], maps[lv]["of"], r.position + r.size / 2)
		seen["%d|%d" % [lv, ri]] = p["rule"]
	var out: Dictionary = {}
	for k: String in seen:
		out[seen[k]] = int(out.get(seen[k], 0)) + 1
	return out


func _kinds_in(d: Dictionary, building_name: String, rule: String) -> Dictionary:
	var ids: Dictionary = {}
	for row: Dictionary in d.get("buildings", []):
		if String(row.get("name", "")) == building_name:
			ids[int(row["id"])] = true
	var out: Dictionary = {}
	for p: Dictionary in d["props"]:
		if p.get("rule", "") == rule and ids.has(int(p.get("building", -1))):
			out[p["kind"]] = true
	return out


func test_an_empty_house_on_a_label_map_gets_a_kitchen_and_a_bedroom() -> void:
	# 호수 지도의 어장 주택: 가구도 이름표도 없는 두 방. 큰 방이 부엌, 작은 방이 침실.
	var d := FieldMaps.build("lake_01")
	var rooms := _rule_rooms(d, "어장 주택")
	assert_eq(rooms.get("kitchen", 0), 5, "다섯 채의 부엌")
	assert_eq(rooms.get("bed", 0), 5, "다섯 채의 침실")
	var bed := _kinds_in(d, "어장 주택", "bed")
	assert_true(bed.has("bed") and (bed.has("wardrobe") or bed.has("dresser")), "침실에 침대와 수납장")
	var kitchen := _kinds_in(d, "어장 주택", "kitchen")
	assert_true(kitchen.has("cold_stove") and kitchen.has("counter") and kitchen.has("sink"), "부엌에 난로·싱크를 포함한 조리대 줄")


func test_a_one_room_hut_is_a_living_room() -> void:
	var d := FieldMaps.build("lake_01")
	var kinds := _kinds_in(d, "얼음 낚시 움막", "living")
	assert_true(kinds.has("cold_stove") and kinds.has("armchair"), "난로와 안락의자")


func test_a_labelled_bedroom_with_bunks_gets_no_second_bed() -> void:
	# 산장 위층 침실 이름표, 지도의 이층 침대가 침대를 대신한다. 아래층 빈 침실은 침대를 받는다.
	var d := FieldMaps.build("lodge_01")
	var g1: FieldGrid = d["levels"][1]
	var map := RoomFurnish.rooms_of(g1)
	var beds: Dictionary = {}
	var bunks: Dictionary = {}
	for p: Dictionary in d["props"]:
		if int(p.get("level", 0)) != 1:
			continue
		var r: Rect2i = RoomFurnish._rect(p["rect"])
		var ri := RoomFurnish._at(g1, map["of"], r.position + r.size / 2)
		if p["kind"] == "bed":
			beds[ri] = true
		elif p["kind"] == "bunk_bed":
			bunks[ri] = true
	assert_gt(bunks.size(), 0)
	for ri: int in bunks:
		assert_false(beds.has(ri), "이층 침대 방에 침대를 더하지 않는다")
	assert_gt(_rule_rooms(d, "본채").get("bed", 0), 3, "본채 침실 이름표가 읽힌다")


func test_the_empty_rooms_of_a_store_building_are_stores() -> void:
	var d := FieldMaps.build("lake_01")
	assert_gt(_rule_rooms(d, "얼음 창고").get("storage", 0), 1, "얼음 창고의 빈 방")


func test_workshops_garages_barns_and_woodsheds_have_their_own_sets() -> void:
	# ref-ops 대조 7: 바깥 건물은 공구·재료 몫. 일터·농가 낱말은 살림·창고 낱말보다 먼저 읽는다.
	assert_eq(RoomFurnish.room_class("작업실", {}, 0), "work")
	assert_eq(RoomFurnish.room_class("정비실", {}, 0), "work")
	assert_eq(RoomFurnish.room_class("차고", {}, 0), "garage")
	assert_eq(RoomFurnish.room_class("외양간 앞방", {}, 0), "barn")
	assert_eq(RoomFurnish.room_class("건초 헛간 뒷방", {}, 0), "barn")
	assert_eq(RoomFurnish.room_class("장작 창고", {}, 0), "woodshed")
	assert_eq(RoomFurnish.room_class("장작 헛간 안방", {}, 0), "woodshed", "헛간의 안쪽 방은 침실이 아니다")
	assert_eq(RoomFurnish.room_class("작업실", {"bed": true}, 1), "bed", "위층 일터에 침대가 있으면 살림방")
	var d := FieldMaps.build("houses_01")
	assert_true(_kinds_in(d, "차고", "work").has("workbench"), "차고의 작업실에 작업대")
	var lodge := FieldMaps.build("lodge_02")
	assert_true(_kinds_in(lodge, "장작 창고", "woodshed").has("firewood_stack"), "장작 창고에 장작 더미")


## 깔개(사용자 10-28): 침대는 양옆으로 한 칸씩 넓게 그 밑에, 방 칸을 벗어난 줄은 깎는다. 계단은 덮지 않는다.
func test_a_rug_lies_under_the_bed_inside_the_room() -> void:
	var cells: Array[Vector2i] = []
	for y in range(4):
		for x in range(5):
			cells.append(Vector2i(x, y))
	var placed := [{"item": {"kind": "bed"}, "rect": Rect2i(1, 1, 2, 1), "facing": 0}]
	var lies := _rug_salt("bed", true)
	var rug := RoomFurnish._lay_rug("bed", cells, placed, {}, lies)
	assert_eq(rug.get("rect"), Rect2i(1, 0, 2, 3), "the bed's width, a cell more on either long side")
	assert_between(int(rug.get("look", 0)), 1, 224)
	var by_wall := [{"item": {"kind": "bed"}, "rect": Rect2i(1, 0, 2, 1), "facing": 0}]
	assert_eq(RoomFurnish._lay_rug("bed", cells, by_wall, {}, lies).get("rect"), Rect2i(1, 0, 2, 2), "trimmed at the wall")
	assert_true(RoomFurnish._lay_rug("bed", cells, by_wall, {Vector2i(2, 1): true}, lies).is_empty(), "never over the stairs")
	assert_true(RoomFurnish._lay_rug("bed", cells, placed, {}, _rug_salt("bed", false)).is_empty(), "not every bedroom has one")
	assert_true(RoomFurnish._lay_rug("kitchen", cells, placed, {}, lies).is_empty(), "no rug in a kitchen")


## 깔개 굴림이 want(깔림·안 깔림)로 나오는 첫 씨앗.
func _rug_salt(cls: String, want: bool) -> int:
	for s in range(1000):
		if (float(RoomFurnish._roll(s, RoomFurnish.ROLL_RUG) % 1000) / 1000.0 < float(RoomFurnish.RUG_CHANCE[cls])) == want:
			return s
	return -1


## 점검 L3: 기댈 벽·깔개는 방 번호를 따라 차례로 돌지 않는다(씨앗 비트를 잘라 쓰지 않고 섞어 고른다).
func test_lean_walls_and_rugs_do_not_step_with_the_room_number() -> void:
	var steps := 0
	var backs: Dictionary = {}
	var rugs := 0
	var prev := -1
	for ri in range(40):
		var s := RoomFurnish.look_seed_of("houses_01", 3, 0, ri)
		var back := RoomFurnish._roll(s, RoomFurnish.ROLL_BACK) % 4
		backs[back] = int(backs.get(back, 0)) + 1
		if prev >= 0 and back == (prev + 1) % 4:
			steps += 1
		prev = back
		rugs += int(RoomFurnish._roll(s, RoomFurnish.ROLL_RUG) % 1000 < 550)
	assert_eq(backs.size(), 4, "all four walls lean: %s" % str(backs))
	assert_lt(steps, 20, "the lean wall does not step round the room once per room number: %d of 39" % steps)
	assert_between(rugs, 12, 32, "about half the bedrooms have a rug")


## 배치 틀(사용자 10-28 「가구배치가 단조로우면 안돼」): 한 동네의 침실들에서 침대가 한 구석으로 몰리지 않는다.
func test_beds_do_not_all_take_the_same_corner() -> void:
	var d := FieldMaps.build("houses_01")
	var corners: Dictionary = {}
	var beds := 0
	var maps: Dictionary = {}
	for p: Dictionary in d["props"]:
		if p.get("kind", "") != "bed" or p.get("rule", "") != "bed":
			continue
		var lv := int(p.get("level", 0))
		if not maps.has(lv):
			maps[lv] = RoomFurnish.rooms_of(d["levels"][lv])
		var r: Rect2i = p["rect"]
		var ri := RoomFurnish._at(d["levels"][lv], maps[lv]["of"], r.position)
		if ri < 0:
			continue
		var cells: Array = maps[lv]["rooms"][ri]["cells"]
		var lo: Vector2i = cells[0]
		var hi: Vector2i = cells[0]
		for c: Vector2i in cells:
			lo = lo.min(c)
			hi = hi.max(c)
		var mid := Vector2(lo + hi) / 2.0
		var at := Vector2(r.position) + Vector2(r.size - Vector2i.ONE) / 2.0
		corners["%d%d" % [int(at.x > mid.x), int(at.y > mid.y)]] = int(corners.get("%d%d" % [int(at.x > mid.x), int(at.y > mid.y)], 0)) + 1
		beds += 1
	assert_gt(beds, 8, "houses_01 has its bedrooms")
	var most := 0
	for k: String in corners:
		most = maxi(most, int(corners[k]))
	assert_eq(corners.size(), 4, "beds stand in all four quarters of their rooms: %s" % str(corners))
	assert_lt(float(most) / beds, 0.5, "no quarter takes half the beds: %s" % str(corners))

## 가구 색 판(art3d furniture_tints): 한 집의 새 가구는 한 판, 집마다 판을 굴린다.
func test_one_house_one_tint_and_houses_differ() -> void:
	var d := FieldMaps.build("houses_01")
	var by_house: Dictionary = {}
	for p: Dictionary in d["props"]:
		# room_furnish가 놓은 줄(조리대 줄 표시가 있는 줄)만: 벽장 선반 같은 room_split 줄은 따로다.
		if not p.has("counter_run"):
			continue
		assert_true(p.has("tint"), "%s has a tint" % p.get("kind", ""))
		var t := int(p.get("tint", -1))
		assert_between(t, 0, RoomFurnish.TINT_SETS - 1)
		var b := int(p.get("building", -1))
		if by_house.has(b):
			assert_eq(t, by_house[b], "one set to a house")
		by_house[b] = t
	var sets: Dictionary = {}
	for b: int in by_house:
		sets[by_house[b]] = true
	assert_gt(sets.size(), 1, "houses roll their own sets: %s" % str(by_house))


## 지도가 둔 가구도 그 집의 새 가구와 같은 판으로 그린다(map_view는 FurnitureTints.pick으로 고른다).
func test_kept_furniture_takes_its_houses_tint() -> void:
	var d := FieldMaps.build("houses_01")
	var levels: Dictionary = d.get("levels", {0: d["grid"]})
	var set_of: Dictionary = {}
	for p: Dictionary in d["props"]:
		if p.has("counter_run"):
			set_of[int(p["building"])] = int(p["tint"])
	var kept := 0
	for p: Dictionary in d["props"]:
		if p.has("counter_run") or not p.get("rect") is Rect2i:
			continue
		var r: Rect2i = p["rect"]
		var g: FieldGrid = levels.get(int(p.get("level", 0)), d["grid"])
		var b := g.building_at(r.position + r.size / 2)
		if set_of.has(b):
			assert_eq(FurnitureTints.pick(p, r.position, b), set_of[b], "%s in house %d" % [p.get("kind", ""), b])
			kept += 1
	assert_gt(kept, 0, "houses_01 keeps some of its map's furniture in furnished houses")


## 새 협탁은 그 집 침대의 베개 쪽 끝 곁에만 선다(발치나 침대 앞 가운데가 아니다).
func test_nightstands_stand_by_the_pillow() -> void:
	var stands := 0
	for map_name: String in ["houses_01", "houses_02"]:
		var d := FieldMaps.build(map_name)
		var heads: Dictionary = {}  # "층:건물" -> [베개 칸]
		for p: Dictionary in d["props"]:
			if p.get("kind", "") == "bed" and p.has("counter_run"):
				var key := "%d:%d" % [int(p.get("level", 0)), int(p["building"])]
				heads.get_or_add(key, []).append(RoomFurnish.bed_head(p["rect"], int(p["facing"])))
		for p: Dictionary in d["props"]:
			if p.get("kind", "") != "nightstand" or not p.has("counter_run"):
				continue
			var at: Vector2i = (p["rect"] as Rect2i).position
			var by_pillow := false
			for h: Vector2i in heads.get("%d:%d" % [int(p.get("level", 0)), int(p["building"])], []):
				by_pillow = by_pillow or absi(at.x - h.x) + absi(at.y - h.y) == 1
			assert_true(by_pillow, "%s: the nightstand at %s stands by a pillow" % [map_name, str(at)])
			stands += 1
	assert_gt(stands, 2, "nightstands still stand")
