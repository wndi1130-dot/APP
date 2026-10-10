extends "res://addons/gut/test.gd"

const FieldGrid = preload("res://game/world/field_grid.gd")
const SulehufMap = preload("res://game/world/sulehuf_map.gd")
const S = FieldGrid.Solid


func _open(w: int = 40, h: int = 40) -> FieldGrid:
	var g := FieldGrid.new(w, h)
	g.refresh_paths()
	return g


func test_open_field_sight_has_no_holes() -> void:
	var g := _open()
	var o := Vector2i(20, 20)
	var seen := g.visible_cells(o, 10, Vector2.ZERO, 0.0, 0.0)
	var missing := 0
	for y in range(10, 31):
		for x in range(10, 31):
			if (Vector2i(x, y) - o).length_squared() <= 100 and not seen.has(g.index(Vector2i(x, y))):
				missing += 1
	assert_eq(missing, 0, "every cell inside the radius is seen in the open")


func test_wall_hides_cells_behind_but_wall_itself_is_seen() -> void:
	var g := FieldGrid.new(40, 40)
	for y in range(10, 31):
		g.set_solid(Vector2i(24, y), S.WALL)
	g.refresh_paths()
	var seen := g.visible_cells(Vector2i(20, 20), 12, Vector2.ZERO, 0.0, 0.0)
	assert_true(seen.has(g.index(Vector2i(24, 20))), "the wall face is visible")
	assert_false(seen.has(g.index(Vector2i(26, 20))), "behind the wall is hidden")
	assert_false(seen.has(g.index(Vector2i(30, 22))))


func test_cone_limits_far_sight_behind() -> void:
	var g := _open()
	var o := Vector2i(20, 20)
	var seen := g.visible_cells(o, 12, Vector2(1, 0), 0.17, 2.6)
	assert_true(seen.has(g.index(Vector2i(30, 20))), "ahead, far")
	assert_false(seen.has(g.index(Vector2i(10, 20))), "behind, far")
	assert_true(seen.has(g.index(Vector2i(18, 20))), "behind, within the near circle")


func test_closed_door_blocks_sight_open_door_does_not() -> void:
	var g := FieldGrid.new(30, 30)
	for y in range(5, 25):
		g.set_solid(Vector2i(15, y), S.WALL)
	var door := Vector2i(15, 15)
	g.set_solid(door, S.DOOR)
	g.doors[door] = {"state": "closed", "hp": 8, "building": 0}
	g.refresh_paths()
	assert_false(g.line_clear(Vector2i(10, 15), Vector2i(20, 15)))
	g.set_door_state(door, "open")
	assert_true(g.line_clear(Vector2i(10, 15), Vector2i(20, 15)))
	assert_true(g.visible_cells(Vector2i(10, 15), 12, Vector2.ZERO, 0.0, 0.0).has(g.index(Vector2i(20, 15))))


func test_diagonal_gap_between_two_corners_blocks_sight() -> void:
	var g := FieldGrid.new(10, 10)
	g.set_solid(Vector2i(5, 4), S.WALL)
	g.set_solid(Vector2i(4, 5), S.WALL)
	g.refresh_paths()
	assert_false(g.line_clear(Vector2i(4, 4), Vector2i(5, 5)))


func test_walk_cache_matches_live_rules_on_sulechow() -> void:
	var data: Dictionary = SulehufMap.build()
	var g: FieldGrid = data["grid"]
	var bad := 0
	for y in range(g.height):
		for x in range(g.width):
			var c := Vector2i(x, y)
			var i := g.index(c)
			if (g.walk_people[i] == 1) != g.people_can_walk(c) or (g.walk_dead[i] == 1) != g.dead_can_walk(c):
				bad += 1
			if (g.opq[i] == 1) != g._opaque_now(c):
				bad += 1
	assert_eq(bad, 0)
	# After a door opens the caches follow.
	var door: Vector2i = g.doors.keys()[0]
	g.set_door_state(door, "open")
	assert_true(g.dead_can_walk(door))
	assert_eq(g.walk_dead[g.index(door)], 1)
	assert_eq(g.opq[g.index(door)], 0)


func test_entries_and_sewers_are_on_the_map_and_reachable() -> void:
	var data: Dictionary = SulehufMap.build()
	var g: FieldGrid = data["grid"]
	var platform := Vector2i(50, 6)
	for key in data["entries"]:
		if int(data["entry_levels"].get(key, 0)) != 0:
			continue   # the cellar drain: checked across floors in test_field_levels
		for c in data["entries"][key]:
			assert_true(g.inside(c), "%s entry %s inside" % [key, c])
			var start: Vector2i = g.nearest_walkable(c, true, 3)
			assert_true(g.dead_can_walk(start), "%s entry has a walkable cell" % key)
			var path := g.find_path(FieldGrid.center(start), FieldGrid.center(platform), false)
			assert_gt(path.size(), 0, "%s entry reaches the platform" % key)
	for key in data["manholes"]:
		assert_true(data["entries"].has(key), "every sewer mouth is also an entry")


func test_sewer_mouths_are_away_from_the_train() -> void:
	var data: Dictionary = SulehufMap.build()
	var train: Rect2i = data["train"]
	var mid := Vector2(train.get_center())
	for key in data["manholes"]:
		var c: Vector2i = data["manholes"][key]
		assert_gt(Vector2(c).distance_to(mid), 25.0, "%s is not right next to the train" % key)


func test_find_path_goes_around_a_wall() -> void:
	var g := FieldGrid.new(30, 30)
	for y in range(0, 25):
		g.set_solid(Vector2i(15, y), S.WALL)
	g.refresh_paths()
	var path := g.find_path(Vector3(10.5, 0, 5.5), Vector3(20.5, 0, 5.5))
	assert_gt(path.size(), 1, "needs a bend")
	for p in path:
		assert_true(g.people_can_walk(FieldGrid.cell_of(p)))
	assert_true(g.clear_walk(Vector2i(10, 26), Vector2i(20, 26), false))
	assert_false(g.clear_walk(Vector2i(10, 5), Vector2i(20, 5), false))


func test_a_whole_window_or_shut_door_stops_a_blow_but_not_the_eye() -> void:
	var g := FieldGrid.new(30, 30)
	for y in range(5, 25):
		g.set_solid(Vector2i(15, y), S.WALL)
	var win := Vector2i(15, 15)
	g.set_solid(win, S.WINDOW)
	g.windows[win] = {"broken": false, "glass": false, "building": 0, "cell": win}
	var door := Vector2i(15, 18)
	g.set_solid(door, S.DOOR)
	g.doors[door] = {"state": "closed", "hp": 8, "building": 0}
	g.set_solid(Vector2i(10, 12), S.LOW)
	g.refresh_paths()
	assert_true(g.line_clear(Vector2i(14, 15), Vector2i(16, 15)), "glass is clear to the eye")
	assert_false(g.body_line_clear(Vector2i(14, 15), Vector2i(16, 15)), "but whole glass stops an axe")
	assert_false(g.body_line_clear(Vector2i(14, 18), Vector2i(16, 18)), "so does a shut door")
	assert_false(g.body_line_clear(Vector2i(14, 12), Vector2i(16, 12)), "and a wall")
	assert_true(g.body_line_clear(Vector2i(9, 12), Vector2i(11, 12)), "low cover can be reached over")
	g.break_window(win)
	g.set_door_state(door, "open")
	assert_true(g.body_line_clear(Vector2i(14, 15), Vector2i(16, 15)))
	assert_true(g.body_line_clear(Vector2i(14, 18), Vector2i(16, 18)))



# ---------------------------------------------------------------- lights

func _lights_of(data: Dictionary, kind: String) -> Array:
	return data["lights"].filter(func(l): return l["kind"] == kind)


func test_sixteen_car_windows_face_the_platform_clear_of_the_doors() -> void:
	var data := SulehufMap.build()
	var train: Rect2i = data["train"]
	var cars: Array = data["train_cars"].filter(func(c): return c["kind"] == "car")
	assert_eq(cars.size(), 4)
	assert_eq(data["train_cars"].size(), 5, "four cars and the engine")
	assert_eq(data["train_cars"][4]["rect"].end.x, train.end.x, "the pieces fill the train")
	var windows: Array = _lights_of(data, "car_window")
	assert_eq(windows.size(), 16)
	var doors: Array = data["spawns"]["train_door"].map(func(c): return c.x)
	var seen: Dictionary = {}
	for l: Dictionary in windows:
		var c: Vector2i = l["cell"]
		seen[c] = true
		assert_eq(c.y, train.end.y - 1, "the platform side")
		assert_false(doors.has(c.x), "not where a door is")
		assert_eq(cars.filter(func(car): return car["rect"].has_point(c)).size(), 1, "in a car, not the engine")
		assert_true(data["platform"].has_point(c + l["side"]), "it falls on the platform")
		assert_eq([l["strength"], l["falls"], l["reach"], l["when"], l["from_min"]], [1.0, 0.6, 3.0, "dusk", 890])
	assert_eq(seen.size(), 16, "no two in one place")
	for car: Dictionary in cars:
		assert_eq(windows.filter(func(l): return car["rect"].has_point(l["cell"])).size(), 4)


func test_the_firebox_the_tower_fire_and_the_hideout_are_one_each() -> void:
	var data := SulehufMap.build()
	var g: FieldGrid = data["grid"]
	assert_eq(data["lights"].size(), 19)
	var fire: Dictionary = _lights_of(data, "firebox")[0]
	assert_true(data["train_cars"][4]["rect"].has_point(fire["cell"]), "in the engine")
	assert_eq([fire["strength"], fire["reach"], fire["when"]], [0.8, 4.0, "always"])
	var tower: Dictionary = _lights_of(data, "tower_fire")[0]
	assert_eq(tower["cell"], data["spots"]["water_tower"]["cell"], "where the fire is lit")
	assert_eq([tower["strength"], tower["reach"], tower["when"]], [0.7, 5.0, "tower_fire"])
	var hide: Dictionary = _lights_of(data, "hideout")[0]
	assert_true(g.windows.has(hide["cell"]), "a window")
	assert_eq(int(g.windows[hide["cell"]]["building"]), int(hide["building"]))
	assert_eq(data["buildings"][hide["building"]]["name"], "약국")
	assert_false(data["buildings"][hide["building"]]["rect"].has_point(hide["cell"] + hide["side"]), "it shows outward")
	assert_eq([hide["strength"], hide["reach"], hide["when"], hide["from_min"]], [0.35, 1.5, "raiders_dusk", 890])
	var ids: Dictionary = {}
	for l: Dictionary in data["lights"]:
		ids[l["id"]] = true
	assert_eq(ids.size(), 19, "every light has its own id")


func test_who_carries_a_lantern_and_when_it_is_lit() -> void:
	var Person = preload("res://game/actors/person.gd")
	var made: Dictionary = {}
	for role: String in ["chief", "companion", "worker", "escort", "raider"]:
		var p = Person.new()
		add_child_autofree(p)
		p.setup(role, role, role, Vector3.ZERO)
		made[role] = p
	assert_eq(made["chief"].lamp, {"strength": 1.0, "reach": 7.0})
	for role: String in ["companion", "worker", "escort"]:
		assert_eq(made[role].lamp, {"strength": 0.6, "reach": 4.0}, role)
		assert_true(made[role].lamp_lit(true))
		assert_false(made[role].lamp_lit(false, true), "only the chief's is lit in a cellar by day")
	assert_true(made["raider"].lamp.is_empty())
	assert_false(made["raider"].lamp_lit(true))
	assert_false(made["chief"].lamp_lit(false))
	assert_true(made["chief"].lamp_lit(true))
	assert_true(made["chief"].lamp_lit(false, true))
