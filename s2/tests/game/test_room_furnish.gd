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
