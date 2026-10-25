extends "res://addons/gut/test.gd"
const Split = preload("res://game/world/room_split.gd")
const Furnish = preload("res://game/world/room_furnish.gd")
const Grid = preload("res://game/world/field_grid.gd")
const Maps = preload("res://game/world/field_maps.gd")
const View = preload("res://game/world/building_view.gd")
const S = Grid.Solid


func _house(w: int = 10, h: int = 8, title: String = "침실") -> Dictionary:
	var g := Grid.new(w + 4, h + 4)
	for y in range(1, h + 3):
		for x in range(1, w + 3):
			var c := Vector2i(x, y)
			g.building[g.index(c)] = 0
			g.floor[g.index(c)] = Grid.Floor.WOOD
			g.set_solid(c, S.WALL if x == 1 or y == 1 or x == w + 2 or y == h + 2 else S.NONE)
	var door := Vector2i(w / 2 + 2, h + 2)
	g.set_solid(door, S.DOOR)
	g.doors[door] = {"state": "closed", "hp": 8, "building": 0, "cell": door}
	g.refresh_paths()
	return {"grid": g, "levels": {0: g}, "place_id": "split_fixture", "buildings": [{"id": 0, "name": "주택", "rect": Rect2i(1, 1, w + 2, h + 2)}],
		"labels": [{"text": title, "cell": Vector2i(2, 2)}], "props": [], "containers": {}, "stairs": [], "low_blocks": [], "stoves": []}


func _contents(d: Dictionary) -> Dictionary:
	var out := {}
	for id: String in d["containers"]:
		out[id] = d["containers"][id]["items"].duplicate(true)
	return out


func _reachable(g: Grid, seed: Vector2i) -> Dictionary:
	var seen := {seed: true}
	var queue: Array = [seed]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for dir: Vector2i in Furnish.DIRS:
			var n := c + dir
			if not seen.has(n) and g.people_can_walk(n):
				seen[n] = true
				queue.append(n)
	return seen


func test_only_homes_and_not_handmade_first_stop() -> void:
	assert_false(Split.is_home({"name": "관리동", "role": "office"}))
	assert_true(Split.is_home({"name": "연립 가 동", "role": "home"}))
	for name: String in ["빵집", "가게", "사무실", "공장", "병원", "교회", "창고", "철물점", "우물집"]:
		var d := _house()
		d["buildings"][0]["name"] = name
		var solid: PackedByteArray = d["grid"].solid.duplicate()
		assert_eq(Split.apply(d)["rows"].size(), 0, name)
		assert_eq(d["grid"].solid, solid, name)
	var first := _house()
	first["place_id"] = Maps.DEFAULT_PLACE
	assert_eq(Split.apply(first)["rows"].size(), 0)
	var home := _house()
	assert_gt(Split.apply(home)["bath"], 0)


func test_bath_dimensions_one_door_faces_opacity_and_furnishing() -> void:
	var d := _house()
	var stats := Split.apply(d)
	assert_eq(stats["bath"], 1)
	var row: Dictionary = stats["rows"][0]
	var rect: Rect2i = row["rect"]
	assert_between(rect.get_area(), 6, 12)
	assert_between(mini(rect.size.x, rect.size.y), 2, 3)
	assert_between(maxi(rect.size.x, rect.size.y), 3, 4)
	var g: Grid = d["grid"]
	var map := Furnish.rooms_of(g)
	var ri := Furnish._at(g, map["of"], rect.position)
	assert_eq(map["rooms"][ri]["cells"].size(), rect.get_area())
	var doors := {}
	for c: Vector2i in map["rooms"][ri]["cells"]:
		for dir: Vector2i in Furnish.DIRS:
			if g.doors.has(c + dir):
				doors[c + dir] = true
	assert_eq(doors.size(), 1)
	var faces := g.faces(row["door"])
	assert_ne(rect.has_point(faces[0]), rect.has_point(faces[1]))
	assert_true(g.people_can_walk(faces[0]))
	assert_true(g.people_can_walk(faces[1]))
	assert_true(g.opaque(row["door"]))
	assert_eq(g.doors[row["door"]]["hp"], 8)
	for c: Vector2i in row["walls"]:
		assert_true(g.opaque(c))
	Furnish.furnish_rooms(d)
	assert_eq(d["density_classes"]["0:%d" % ri], "bath")
	var kinds := []
	for p: Dictionary in d["props"]:
		if p.get("rule") == "bath":
			kinds.append(p["kind"])
	assert_has(kinds, "toilet")
	assert_has(kinds, "washstand")


func test_closet_and_pantry_strict_area_thresholds() -> void:
	for spec: Array in [[6, 5, "침실", "closet", 0], [8, 4, "침실", "closet", 1], [6, 6, "부엌", "pantry", 0], [8, 5, "부엌", "pantry", 1]]:
		var d := _house(spec[0], spec[1], spec[2])
		# 기존 욕실 후보가 있는 것으로 고정해 수납의 경계값만 격리한다.
		d["_split_baths"] = {0: {"key": "other", "level": 1, "room": 0, "area": 6, "short": 2, "doors": 1, "class": "bath"}}
		var stats := Split.apply(d)
		assert_eq(stats[spec[3]], spec[4], str(spec))
		for row: Dictionary in stats["rows"]:
			assert_between(row["rect"].get_area(), 2, 6)


func test_door_stair_window_fronts_and_every_floor_cell_remain_reachable() -> void:
	var d := _house(14, 12)
	var g: Grid = d["grid"]
	var window := Vector2i(4, 1)
	g.set_solid(window, S.WINDOW)
	g.windows[window] = {"broken": false, "glass": true, "building": 0}
	d["stairs"] = [{"cell": Vector2i(3, 3), "low": 0, "high": 1}]
	var map := Furnish.rooms_of(g)
	var protected := Split._protected(d, g, 0, map, 0)
	var stats := Split.apply(d)
	assert_gt(stats["rows"].size(), 0)
	for c: Vector2i in protected:
		if g.inside(c) and map["of"][g.index(c)] == 0:
			assert_eq(g.solid_at(c), S.NONE, str(c))
	var seen := _reachable(g, Vector2i(0, 0))
	for y in range(g.height):
		for x in range(g.width):
			var c := Vector2i(x, y)
			if g.people_can_walk(c):
				assert_has(seen, c)


func test_rejects_blocked_corners_without_mutation() -> void:
	var d := _house(6, 5)
	var g: Grid = d["grid"]
	var map := Furnish.rooms_of(g)
	var all := {}
	for c: Vector2i in map["rooms"][0]["cells"]:
		all[c] = true
	var solid := g.solid.duplicate()
	assert_true(Split.choose(g, map["rooms"][0]["cells"], Split.BATH_SIZES, all).is_empty())
	assert_eq(g.solid, solid)


func test_boxes_on_wall_move_with_ids_items_and_floors_unchanged() -> void:
	var d := _house()
	var g: Grid = d["grid"]
	var map := Furnish.rooms_of(g)
	var candidate := Split.choose(g, map["rooms"][0]["cells"], Split.BATH_SIZES, Split._protected(d, g, 0, map, 0))
	assert_false(candidate.is_empty())
	for c: Vector2i in candidate["walls"]:
		d["containers"]["box_%d_%d" % [c.x, c.y]] = {"cell": c, "level": 0, "items": [{"kind": "wood", "n": 3}], "searched": false}
	var contents := _contents(d)
	var floor_before := g.floor.duplicate()
	var stats := Split.apply(d)
	assert_gt(stats["boxes_moved"], 0)
	assert_eq(_contents(d), contents)
	assert_eq(g.floor, floor_before)
	var seen := _reachable(g, Vector2i(0, 0))
	for box: Dictionary in d["containers"].values():
		assert_has(seen, box["cell"])
		assert_has(map["rooms"][0]["cells"], box["cell"])


func test_same_map_seed_is_deterministic_and_apply_is_idempotent() -> void:
	seed(11)
	var a := _house()
	Split.apply(a)
	seed(11)
	var b := _house()
	Split.apply(b)
	assert_eq(a["grid"].solid, b["grid"].solid)
	assert_eq(a["grid"].doors, b["grid"].doors)
	assert_eq(a["labels"], b["labels"])
	var rows: Array = a["room_splits"]["rows"].duplicate(true)
	Split.apply(a)
	assert_eq(a["room_splits"]["rows"], rows)


func test_actual_houses_cache_rebuilt_and_building_view_sees_partition() -> void:
	var d := Maps.build("houses_01")
	assert_gt(d["room_splits"]["bath"], 0)
	assert_false(d.has("_rooms"))
	var visual := View.plan(d)
	for row: Dictionary in d["room_splits"]["rows"]:
		var found := false
		for door: Dictionary in visual["doors"]:
			if door["lv"] == row["level"] and door["cell"] == row["door"]:
				found = true
		assert_true(found, "partition door in drawing plan")
		for c: Vector2i in row["walls"]:
			assert_eq(d["levels"][row["level"]].solid_at(c), S.WALL)
			var drawn := false
			for piece: Dictionary in visual["pieces"]:
				if piece["lv"] != row["level"] or piece["b"] != row["building"] or piece.get("id", "") not in ["int_wall", "int_wall_cut"]:
					continue
				var xf: Transform3D = piece["xf"]
				var local := xf.affine_inverse() * Vector3(c.x + 0.5, 0, c.y + 0.5)
				if absf(local.x) <= 0.501 and absf(local.z) < 0.01:
					drawn = true
			assert_true(drawn, "partition wall in drawing plan")


func test_legacy_array_building_declarations_keep_the_name_fallback() -> void:
	var script: Script = load("res://game/world/maps/lodge_01.gd")
	var d: Dictionary = script.build()
	d["place_id"] = "lodge_01"
	var stats := Split.apply(d, script)
	assert_has(stats, "rows")
	assert_has(d, "room_splits")


## 이름표 없는 농가: 위 12x3, 가운데 12x2, 아래 12x3. 나누기 전 차례는 부엌·살림방·거실.
func _farmhouse() -> Dictionary:
	var g := Grid.new(16, 14)
	for y in range(1, 13):
		for x in range(1, 15):
			var c := Vector2i(x, y)
			g.building[g.index(c)] = 0
			g.floor[g.index(c)] = Grid.Floor.WOOD
			g.set_solid(c, S.WALL if x == 1 or x == 14 or y in [1, 5, 8, 12] else S.NONE)
	for door: Vector2i in [Vector2i(1, 6), Vector2i(8, 5), Vector2i(8, 8)]:
		g.set_solid(door, S.DOOR)
		g.doors[door] = {"state": "closed", "hp": 8, "building": 0, "cell": door}
	g.refresh_paths()
	return {"grid": g, "levels": {0: g}, "place_id": "split_fixture", "buildings": [{"id": 0, "name": "농가", "rect": Rect2i(1, 1, 14, 12)}],
		"labels": [], "props": [], "containers": {}, "stairs": [], "low_blocks": [], "stoves": []}


func test_an_unnamed_home_keeps_its_room_kinds_after_a_split() -> void:
	var d := _farmhouse()
	var g: Grid = d["grid"]
	var plan := Furnish.density_plan(d)
	var map := Furnish.rooms_of(g)
	var was := {}
	for c: Vector2i in [Vector2i(3, 3), Vector2i(3, 6)]:
		was[c] = plan["classes"]["0:%d" % Furnish._at(g, map["of"], c)]
	assert_eq(was[Vector2i(3, 3)], "kitchen")
	var stats := Split.apply(d)
	assert_eq(stats["bath"], 1)
	assert_eq(stats["closet"], 1)
	assert_eq(d["labels"], [], "the split writes no floor text")
	Furnish.furnish_rooms(d)
	map = Furnish.rooms_of(g)
	for c: Vector2i in was:
		assert_eq(d["density_classes"]["0:%d" % Furnish._at(g, map["of"], c)], was[c], str(c))
	var kitchen := 0
	for p: Dictionary in d["props"]:
		if p.get("rule") == "kitchen":
			kitchen += 1
	assert_gt(kitchen, 0, "the kitchen is furnished")


func test_a_closet_door_is_on_its_long_side_and_one_shelf_stands_at_the_far_end() -> void:
	var d := _farmhouse()
	var stats := Split.apply(d)
	var closets: Array = stats["rows"].filter(func(r: Dictionary) -> bool: return r["kind"] == "closet")
	assert_eq(closets.size(), 1)
	var row: Dictionary = closets[0]
	var rect: Rect2i = row["rect"]
	var shelves: Array = d["props"].filter(func(p: Dictionary) -> bool: return rect.has_point((p["rect"] as Rect2i).position))
	assert_eq(shelves.size(), 1)
	var shelf: Dictionary = shelves[0]
	assert_eq(shelf["kind"], "small_shelf")
	assert_false(Split._in_line(row["door"], rect), "door on the long side")
	var at: Vector2i = (shelf["rect"] as Rect2i).position
	var door: Vector2i = row["door"]
	for c: Vector2i in [rect.position, rect.end - Vector2i.ONE]:
		assert_true(absi(at.x - door.x) + absi(at.y - door.y) >= absi(c.x - door.x) + absi(c.y - door.y))
	var open: Vector2i = rect.position if at != rect.position else rect.end - Vector2i.ONE
	assert_true(d["grid"].people_can_walk(open), "the cell inside the door stays free")
	assert_eq(d["containers"].size(), 0)
