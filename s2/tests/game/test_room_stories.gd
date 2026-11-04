extends "res://addons/gut/test.gd"
## 방 이야기(docs/design/briefs/house_layout.md 4장, 결정 423). 같은 씨앗이면 같은 이야기, 물건
## 양은 그대로, 금지선(잠긴 방 안의 망자, 밖에서 잠근 문, 다 막은 창)을 넘지 않고, 모든 상자에
## 여전히 걸어서 닿는다.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")
const RoomStories = preload("res://game/world/room_stories.gd")
const BuildingRules = preload("res://game/sim/building_rules.gd")
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const MAPS: Array[String] = ["houses_01", "houses_02", "lodge_01"]
const SEEDS: Array[int] = [1, 2]


func _dice(d: Dictionary, s: int) -> int:
	return ("%d:stories:%s" % [s, d["place_id"]]).hash()


func _items(d: Dictionary) -> Array:
	var out: Array = []
	for id: String in d["containers"]:
		for it in d["containers"][id].get("items", []):
			out.append(String(it))
	out.sort()
	return out


## 문·창·상자·소품·칸: 이야기가 바꾸는 것 전부.
func _state(d: Dictionary) -> Array:
	var g0: FieldGrid = d["levels"][0]
	var doors: Array = []
	for c: Vector2i in g0.doors:
		doors.append([c, g0.doors[c]["state"], g0.doors[c].get("barred", "")])
	doors.sort()
	var windows: Array = []
	for c: Vector2i in g0.windows:
		windows.append([c, g0.windows[c]["broken"], BuildingRules.planks_total(g0.windows[c])])
	windows.sort()
	var boxes: Array = []
	for id: String in d["containers"]:
		boxes.append([id, d["containers"][id].get("items", []), d["containers"][id].get("searched", false)])
	boxes.sort()
	var solids: Array = []
	for lv: int in d["levels"]:
		solids.append(d["levels"][lv].solid)
	return [doors, windows, boxes, d["props"].size(), solids]


## 열차 문에서 걸어서(층 사이는 계단) 닿는 상자 id.
func _box_reach(d: Dictionary) -> Dictionary:
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
	var out: Dictionary = {}
	for id: String in d["containers"]:
		var box: Dictionary = d["containers"][id]
		var c: Vector2i = box["cell"]
		var lv := int(box.get("level", 0))
		for n: Vector2i in [c, c + DIRS[0], c + DIRS[1], c + DIRS[2], c + DIRS[3]]:
			if seen.has(Vector3i(n.x, n.y, lv)):
				out[id] = true
	return out


func _lost(before: Dictionary, after: Dictionary) -> Array:
	var out: Array = []
	for id: String in before:
		if not after.has(id):
			out.append(id)
	return out


## 그 이야기가 붙는 첫 건물(번호 차례)에 직접 건다. 붙은 건물 번호, 없으면 -1.
func _first_fit(d: Dictionary, story: String) -> int:
	var city := RoomStories._city(d)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var ids: Array = city["homes"].keys()
	ids.sort()
	for b: int in ids:
		var ok := false
		match story:
			"barricaded":
				ok = RoomStories._barricaded(d, city, b, rng)
			"looted":
				ok = RoomStories._looted(d, city, b, rng)
			"rushed":
				ok = RoomStories._rushed(d, city, b, rng)
		if ok:
			for lv: int in city["changed"]:
				d["levels"][lv].refresh_paths()
			return b
	return -1


func test_same_seed_same_stories() -> void:
	var a := FieldMaps.build("houses_01")
	var b := FieldMaps.build("houses_01")
	assert_eq(RoomStories.apply(a, _dice(a, 7)), RoomStories.apply(b, _dice(b, 7)))
	assert_eq(_state(a), _state(b))


func test_other_runs_other_stories() -> void:
	var seen: Dictionary = {}
	for s in [1, 2, 3]:
		var d := FieldMaps.build("houses_01")
		seen[str(RoomStories.apply(d, _dice(d, s)))] = true
	assert_gt(seen.size(), 1, "판마다 다른 이야기")


## 필드를 띄우면 이야기가 판 씨앗과 장소로 정해져 영수증 장소 상태에 남는다.
func test_a_field_keeps_its_stories_in_the_place_state() -> void:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "place": "houses_01"}
	add_child_autofree(game)
	game.set_process(false)
	var kept: Array = game.receipt.to_dict()["placeState"].get("roomStories", [])
	# The field builds its map in its stop's band (the outer village takes the region's look).
	var d := FieldMaps.build("houses_01", FieldGame.region_for(game.opts))
	assert_eq(kept, RoomStories.apply(d, _dice(d, 5)))
	assert_gt(kept.size(), 0)


func test_the_first_stop_is_left_as_it_is() -> void:
	# field_game은 규칙으로 지은 지도(room_stats가 있는 것)에만 이야기를 얹는다.
	assert_false(FieldMaps.build(FieldMaps.DEFAULT_PLACE).has("room_stats"))


## 안에서 막은 방: 문은 안에서 막혀 잠겼고(바깥 빗장 없음), 나간 창 하나는 깨져 열려 있고,
## 판자는 창 일부만, 다른 상자 몫이 이 방에 모였지만 양은 그대로, 안에 망자 없음.
func test_a_room_shut_from_inside_has_its_way_out_and_nobody_in_it() -> void:
	var d := FieldMaps.build("houses_01")
	var items := _items(d)
	var dead: Array = (d["spawns"].get("dead_levels", []) as Array).duplicate(true)
	var reach := _box_reach(d)
	var b := _first_fit(d, "barricaded")
	assert_gt(b, -1, "막을 방이 있는 집")
	var g0: FieldGrid = d["levels"][0]
	var shut := 0
	for c: Vector2i in g0.doors:
		if String(g0.doors[c].get("barred", "")) == "inside":
			shut += 1
			assert_eq(g0.doors[c]["state"], "locked")
	assert_gt(shut, 0, "안에서 막은 문")
	var boarded := 0
	var broken := 0
	for c: Vector2i in g0.windows:
		var w: Dictionary = g0.windows[c]
		if BuildingRules.planks_total(w) > 0:
			boarded += 1
			assert_lt(BuildingRules.most_on_a_face(w), BuildingRules.SIGHT_PLANKS, "창을 다 막지 않는다")
			assert_eq(BuildingRules.planks(w, g0.outer_face(c)), 0, "판자는 안쪽 면에")
			assert_eq(int(w.get("building", g0.building_at(c))), b)
		if w["broken"] and int(w.get("building", -1)) == b:
			broken += 1
	# 판자 친 창은 창이 둘 넘는 방에만 있다(나간 창은 비움): 있으면 안쪽 면에, 셋째 장 밑.
	assert_gt(broken, 0, "막은 사람이 나간 창")
	assert_eq(_items(d), items, "물건 양은 그대로")
	assert_eq(d["spawns"].get("dead_levels", []), dead, "망자를 더하지 않는다")
	assert_eq(_lost(reach, _box_reach(d)), [], "막은 방 상자도 창으로 닿는다")


## 털린 집: 그 건물 상자는 하나만 남고 다 비어 뒤진 채, 바깥문 하나가 부서졌다. 양은 그대로.
func test_a_looted_house_keeps_its_share_in_one_hidden_place() -> void:
	var d := FieldMaps.build("houses_01")
	var items := _items(d)
	var reach := _box_reach(d)
	var b := _first_fit(d, "looted")
	assert_gt(b, -1, "털린 집이 될 집")
	var g0: FieldGrid = d["levels"][0]
	var full := 0
	var emptied := 0
	for id: String in d["containers"]:
		var box: Dictionary = d["containers"][id]
		var lv := int(box.get("level", 0))
		if (d["levels"][lv] as FieldGrid).building_at(box["cell"]) != b or box.has("pick") or box.get("locked", false):
			continue
		if (box.get("items", []) as Array).is_empty():
			emptied += 1
			assert_true(box.get("searched", false), id + " 빈 상자는 뒤진 채")
		else:
			full += 1
	assert_eq(full, 1, "숨긴 자리 하나")
	assert_gt(emptied, 0)
	var broken := 0
	for c: Vector2i in RoomStories.outer_doors(g0, b):
		if g0.doors[c]["state"] == "broken":
			broken += 1
	assert_eq(broken, 1, "부서진 바깥문 하나")
	assert_eq(_items(d), items, "물건 양은 그대로")
	assert_eq(_lost(reach, _box_reach(d)), [])


## 급히 떠난 부엌: 식탁 곁에 넘어진 탁자, 길은 남는다.
func test_a_kitchen_left_in_a_hurry_has_a_fallen_table_by_the_dining_set() -> void:
	var d := FieldMaps.build("houses_01")
	var reach := _box_reach(d)
	var b := _first_fit(d, "rushed")
	assert_gt(b, -1, "식탁 있는 부엌")
	var fallen: Array = []
	var tables: Array = []
	for p: Dictionary in d["props"]:
		if p.get("story", false) and p["kind"] == "table_overturned":
			fallen.append(p["rect"])
		elif p["kind"] == "dining_set" and int(p.get("building", -1)) == b:
			tables.append(p["rect"])
	assert_eq(fallen.size(), 1)
	var by := false
	for t: Rect2i in tables:
		by = by or (fallen[0] as Rect2i).grow(1).intersects(t)
	assert_true(by, "식탁 곁")
	assert_eq(_lost(reach, _box_reach(d)), [])


## 계단이 문 칸에서 오르는 공장 건물: 그 문을 막으면 위층 상자가 끊긴다. 막지 않는다.
func test_a_door_the_stairs_start_from_is_never_shut() -> void:
	var d := FieldMaps.build("factory_02")
	var reach := _box_reach(d)
	RoomStories.apply(d, _dice(d, 1))
	assert_eq(_lost(reach, _box_reach(d)), [])
	var stairs: Dictionary = RoomFurnish._stairs_by_level(d).get(0, {})
	for c: Vector2i in d["levels"][0].doors:
		if stairs.has(c):
			assert_ne(d["levels"][0].doors[c].get("barred", ""), "inside", "계단 문 %s" % c)


## 지도 몇 장 x 판 몇: 건물 이야기 4채·작은 이야기 6자리 이하, 건물마다 하나, 양 그대로, 망자
## 그대로, 다 막은 창 없음, 새로 잠근 문은 모두 안에서 막은 문, 이야기 소품은 비울 칸 밖, 상자에
## 다 닿는다.
func test_stories_keep_the_amount_the_ban_lines_and_the_way_to_every_box() -> void:
	for id: String in MAPS:
		for s: int in SEEDS:
			var d := FieldMaps.build(id)
			var tag := "%s 판 %d" % [id, s]
			var items := _items(d)
			var dead: Array = (d["spawns"].get("dead_levels", []) as Array).duplicate(true)
			var reach := _box_reach(d)
			var g0: FieldGrid = d["levels"][0]
			var locked_before: Dictionary = {}
			for c: Vector2i in g0.doors:
				if g0.doors[c]["state"] == "locked":
					locked_before[c] = true
			var out := RoomStories.apply(d, _dice(d, s))
			var big := 0
			var small := 0
			var stash := 0
			var seen: Dictionary = {}
			for row: Dictionary in out:
				assert_false(seen.has(row["building"]), tag + ": 건물마다 이야기 하나")
				seen[row["building"]] = true
				if row["story"] == "small":
					small += 1
				elif row["story"] == "floor_stash":
					stash += 1
				else:
					big += 1
			assert_lte(big, RoomStories.BUILDINGS_MAX, tag)
			assert_lte(small, RoomStories.SMALL_MAX, tag)
			assert_lte(stash, 1, tag + ": 마루 밑 숨긴 칸은 많아야 한 곳")
			assert_eq(_items(d), items, tag + ": 양 그대로")
			assert_eq(d["spawns"].get("dead_levels", []), dead, tag + ": 망자 그대로")
			assert_eq(_lost(reach, _box_reach(d)), [], tag + ": 닿지 않게 된 상자")
			for c: Vector2i in g0.windows:
				assert_lt(BuildingRules.most_on_a_face(g0.windows[c]), BuildingRules.SIGHT_PLANKS, tag + ": 다 막은 창")
			for c: Vector2i in g0.doors:
				if g0.doors[c]["state"] == "locked" and not locked_before.has(c):
					assert_eq(g0.doors[c].get("barred", ""), "inside", tag + ": 밖에서 잠근 문")
			var stairs := RoomFurnish._stairs_by_level(d)
			for p: Dictionary in d["props"]:
				if not p.get("story", false):
					continue
				var lv := int(p["level"])
				var g: FieldGrid = d["levels"][lv]
				var map := RoomFurnish.rooms_of(g)
				var r: Rect2i = p["rect"]
				var ri := RoomFurnish._at(g, map["of"], r.position)
				var forbid := RoomFurnish._forbidden(g, map["of"], ri, map["rooms"][ri]["cells"], stairs.get(lv, {}))
				for y in range(r.position.y, r.end.y):
					for x in range(r.position.x, r.end.x):
						assert_false(forbid.has(Vector2i(x, y)), "%s: %s가 비울 칸에" % [tag, p["kind"]])
