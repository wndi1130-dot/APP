extends "res://addons/gut/test.gd"

const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const StopGround = preload("res://game/world/stop_ground.gd")
const SidePath = preload("res://game/world/side_path.gd")
const FieldGame = preload("res://game/field_game.gd")
const WorkSpots = preload("res://game/world/work_spots.gd")
const PLACES: Array[String] = ["houses_01", "freight_01"]
static var _built: Dictionary = {}


func after_all() -> void:
	_built.clear()


## Finished maps are shared read-only; tests that dress one make a fresh edge.
func _map(place: String) -> Dictionary:
	if not _built.has(place):
		_built[place] = FieldMaps.build(place)
	return _built[place]


func _edge(place: String) -> Dictionary:
	var key: String = "edge:" + place
	if not _built.has(key):
		_built[key] = StopGround.apply(_map(place), "edge", 71, 200.0)
	return _built[key]


func _center(rect: Rect2i) -> Vector2:
	return Vector2(rect.position) + Vector2(rect.size) * 0.5


func _shift(was: Dictionary, now: Dictionary) -> Vector2i:
	var old: Rect2i = was["buildings"][0]["rect"]
	var moved: Rect2i = now["buildings"][0]["rect"]
	return moved.position - old.position


func test_empty_form_keeps_the_same_dictionary_without_keys() -> void:
	for place: String in PLACES:
		var data: Dictionary = _map(place)
		var keys: Array = data.keys()
		assert_true(is_same(StopGround.apply(data, "", 71), data), place)
		assert_eq(data.keys(), keys)
		assert_false(data.has("stop_form"))


func test_edge_distance_and_walk_to_village() -> void:
	for place: String in PLACES:
		var was: Dictionary = _map(place)
		var now: Dictionary = _edge(place)
		var old: FieldGrid = was["grid"]
		var g: FieldGrid = now["grid"]
		assert_false(is_same(was, now))
		assert_between(_center(now["train"]).distance_to(StopGround.village_middle(now)), 199.0, 201.0, place)
		assert_gt(g.width, old.width)
		assert_eq(g.height, old.height)
		assert_gte(float(now["walk_to_village_m"]), 150.0, place)
		assert_eq(now["stop_form"], "edge")
		_check_village_cell(now, place)


## The village's cell is the outdoor one nearest the middle that the doors reach on foot.
func _check_village_cell(now: Dictionary, label: String) -> void:
	var g: FieldGrid = now["grid"]
	var middle: Vector2 = StopGround.village_middle(now)
	var cell: Vector2i = now["village_middle"]
	var field: PackedInt32Array = WorkSpots.walk_field(now, 600.0)
	assert_lt(g.building_at(cell), 0, label + ": outdoors")
	assert_gte(field[g.index(cell)], 0, label + ": reached from the doors")
	assert_eq(float(now["walk_to_village_m"]), float(field[g.index(cell)]) / float(WorkSpots.STEP))
	var own: float = (Vector2(cell) + Vector2.ONE * 0.5).distance_squared_to(middle)
	var nearer: int = 0
	for y: int in range(g.height):
		for x: int in range(g.width):
			var i: int = g.index(Vector2i(x, y))
			if field[i] >= 0 and g.building[i] < 0 and Vector2(float(x) + 0.5, float(y) + 0.5).distance_squared_to(middle) < own:
				nearer += 1
	assert_eq(nearer, 0, label + ": no nearer outdoor cell the doors reach")


func test_city_village_cell_is_outdoors_and_reached_on_every_kind_of_town() -> void:
	# A church or a works hall often sits on the buildings' middle.
	for place: String in PLACES + ["church_01", "factory_01"]:
		var now: Dictionary = StopGround.apply(_map(place).duplicate(), "city", 71)
		_check_village_cell(now, place)
		assert_gte(float(now["walk_to_village_m"]), 0.0, place)


func test_train_is_inside_with_twelve_cells_past_its_end() -> void:
	for place: String in PLACES:
		var now: Dictionary = _edge(place)
		var g: FieldGrid = now["grid"]
		var train: Rect2i = now["train"]
		assert_true(Rect2i(0, 0, g.width, g.height).encloses(train), place)
		assert_gte(train.position.x, 12)
		assert_gte(g.width - train.end.x, 12)


func test_added_columns_continue_every_train_rail_row() -> void:
	for place: String in PLACES:
		var was: Dictionary = _map(place)
		var now: Dictionary = _edge(place)
		var old: FieldGrid = was["grid"]
		var g: FieldGrid = now["grid"]
		var offset: Vector2i = _shift(was, now)
		var start: int = 0 if offset.x > 0 else old.width
		var end: int = offset.x if offset.x > 0 else g.width
		var train: Rect2i = now["train"]
		var joined: bool = true
		for y: int in range(train.position.y, train.end.y):
			for x: int in range(start, end):
				joined = joined and g.floor_at(Vector2i(x, y)) == FieldGrid.Floor.RAIL
		assert_true(joined, place + ": rail reaches across every added column")


func test_old_train_footprint_is_walkable_and_new_one_keeps_its_mask() -> void:
	for place: String in PLACES:
		var was: Dictionary = _map(place)
		var now: Dictionary = _edge(place)
		var old: FieldGrid = was["grid"]
		var g: FieldGrid = now["grid"]
		var train: Rect2i = was["train"]
		var moved: Rect2i = now["train"]
		var offset: Vector2i = _shift(was, now)
		var cleared: bool = true
		var copied: bool = true
		for y: int in range(train.size.y):
			for x: int in range(train.size.x):
				var local: Vector2i = Vector2i(x, y)
				var source: Vector2i = train.position + local
				var target: Vector2i = moved.position + local
				cleared = cleared and g.people_can_walk(source + offset)
				copied = copied and old.solid_at(source) == g.solid_at(target) and old.floor_at(source) == g.floor_at(target)
		assert_true(cleared, place + ": the abandoned track is walkable")
		assert_true(copied, place + ": train solid and floor masks match")


func test_all_doors_and_cars_follow_the_train() -> void:
	for place: String in PLACES:
		var now: Dictionary = _edge(place)
		var g: FieldGrid = now["grid"]
		var train: Rect2i = now["train"]
		for cells: Array in now["train_doors"].values():
			for cell: Vector2i in cells:
				assert_true(train.grow(2).has_point(cell), place)
				assert_true(g.people_can_walk(cell))
		for cell: Vector2i in now["spawns"]["train_door"]:
			assert_true(train.grow(2).has_point(cell))
			assert_true(g.people_can_walk(cell))
		for car: Dictionary in now["train_cars"]:
			assert_true(train.encloses(car["rect"]))
		for cell: Vector2i in now["spawns"]["squad"]:
			assert_true(FieldMaps.by_train(now, cell))
			assert_true(g.people_can_walk(cell))


func test_train_anchors_follow_the_train_and_boarding_is_rebuilt() -> void:
	for place: String in PLACES:
		var was: Dictionary = _map(place)
		var now: Dictionary = _edge(place)
		var offset: Vector2i = _shift(was, now)
		var travel: Vector2i = now["train"].position - was["train"].position - offset
		var train: Rect2i = now["train"]
		var was_worked: Dictionary = FieldMaps.anchors(was)
		var worked: Dictionary = FieldMaps.anchors(now)
		var own: int = 0
		for key: String in ["whistle", "engine"]:
			assert_true(train.grow(2).has_point(now["anchors"][key]), place)
		for key: String in StopGround.TRAIN_ANCHORS:
			if not was["anchors"].has(key):
				continue
			if was["anchors"][key] != was_worked[key]:
				own += 1
				assert_eq(now["anchors"][key], was["anchors"][key] + offset + travel, "%s: the map's %s rides with the train" % [place, key])
			else:
				assert_eq(now["anchors"][key], worked[key], "%s: %s worked out again" % [place, key])
		assert_gt(own, 0, place + ": the map sets one of its train anchors itself")
		assert_eq(now["boarding"], [now["platform"]] + FieldMaps.side_strips(now, now["platform"]))
		assert_eq(now["unloading"], [now["unload"]] + FieldMaps.side_strips(now, now["unload"]))


## The ground entries on the grown side's old border stand on the new border; the rest
## only shift with the map. A flee exit the map set on one goes with it.
func test_entries_on_the_grown_side_move_out_to_the_new_border() -> void:
	for place: String in PLACES:
		var was: Dictionary = _map(place)
		var now: Dictionary = _edge(place)
		var g: FieldGrid = now["grid"]
		var offset: Vector2i = _shift(was, now)
		var old_border: int = offset.x if offset.x > 0 else was["grid"].width - 1
		var new_border: int = 0 if offset.x > 0 else g.width - 1
		var moved: int = 0
		for id in was["entries"]:
			for i: int in range(was["entries"][id].size()):
				var c: Vector2i = was["entries"][id][i] + offset
				var ground: bool = not was.get("manholes", {}).has(id) and int(was.get("entry_levels", {}).get(id, 0)) == 0
				if ground and c.x == old_border:
					moved += 1
					assert_eq(now["entries"][id][i], Vector2i(new_border, c.y), "%s %s" % [place, id])
				else:
					assert_eq(now["entries"][id][i], c, "%s %s" % [place, id])
		if place == "houses_01":
			assert_gt(moved, 0, place + ": its ways in stand on both sides")
		var flee: Vector2i = was["anchors"]["flee_exit"] + offset
		if was["anchors"]["flee_exit"] != FieldMaps.anchors(was)["flee_exit"]:
			assert_eq(now["anchors"]["flee_exit"], Vector2i(new_border, flee.y) if flee.x == old_border else flee, place)


func test_old_cells_on_every_level_stay_intact_away_from_the_train() -> void:
	for place: String in PLACES:
		var was: Dictionary = _map(place)
		var now: Dictionary = _edge(place)
		var offset: Vector2i = _shift(was, now)
		var train: Rect2i = was["train"]
		var moved: Rect2i = now["train"]
		for lv: int in was["levels"]:
			var old: FieldGrid = was["levels"][lv]
			var g: FieldGrid = now["levels"][lv]
			var unchanged: bool = true
			for y: int in range(old.height):
				for x: int in range(old.width):
					var c: Vector2i = Vector2i(x, y)
					if lv == 0 and (train.has_point(c) or moved.has_point(c + offset)):
						continue
					# The platform's floor goes with the train.
					if lv == 0 and (was["platform"].has_point(c) or was["unload"].has_point(c) \
							or now["platform"].has_point(c + offset) or now["unload"].has_point(c + offset)):
						continue
					if old.solid_at(c) != g.solid_at(c + offset) or old.floor_at(c) != g.floor_at(c + offset):
						unchanged = false
			assert_true(unchanged, "%s level %d: old cells keep solid and floor" % [place, lv])
		assert_false(was.has("stop_form"), "the input is still an undressed map")


func test_seed_repeats_and_default_distances_stay_in_range() -> void:
	for place: String in PLACES:
		var was: Dictionary = _map(place)
		var first: Dictionary = StopGround.apply(was, "edge", 71)
		var again: Dictionary = StopGround.apply(was, "edge", 71)
		assert_eq(first["train"], again["train"])
		assert_eq(first["grid"].width, again["grid"].width)
		assert_eq(first["grid"].height, again["grid"].height)
		assert_eq(first["trees"], again["trees"])
		for seed_value: int in [1, 8, 73, 1009]:
			var now: Dictionary = StopGround.apply(was, "edge", seed_value)
			var distance: float = _center(now["train"]).distance_to(StopGround.village_middle(now))
			assert_between(distance, 150.0, 300.0, "%s seed %d" % [place, seed_value])


func test_city_only_adds_the_three_handoff_keys() -> void:
	for place: String in PLACES:
		var was: Dictionary = _map(place)
		var data: Dictionary = was.duplicate(true)
		var now: Dictionary = StopGround.apply(data, "city", 71)
		assert_true(is_same(data, now))
		assert_eq(now.size(), was.size() + 3)
		for key: String in was:
			assert_eq(now[key], was[key], place + ": " + key)
		assert_eq(now["stop_form"], "city")
		assert_true(now["village_middle"] is Vector2i)
		assert_true(now["walk_to_village_m"] is float)


func test_work_spots_can_dress_an_edge() -> void:
	for place: String in PLACES:
		var data: Dictionary = StopGround.apply(_map(place), "edge", 71, 200.0)
		var train: Rect2i = data["train"]
		WorkSpots.dress(data, -1, 1)
		assert_true(data.has("fell_groves"), place)
		assert_eq(data["train"], train)
		var field: PackedInt32Array = data["_walk_field"]
		var g: FieldGrid = data["grid"]
		assert_eq(field.size(), g.width * g.height)


func test_edge_is_idempotent_and_unknown_or_unbuilt_forms_only_warn() -> void:
	for place: String in PLACES:
		var now: Dictionary = _edge(place)
		var train: Rect2i = now["train"]
		assert_true(is_same(StopGround.apply(now, "edge", 999, 275.0), now))
		assert_eq(now["train"], train)
		# An edge stop cannot be made a city one again.
		assert_true(is_same(StopGround.apply(now, "city", 71), now))
		assert_eq(now["stop_form"], "edge")
		var was: Dictionary = _map(place)
		var keys: Array = was.keys()
		assert_true(is_same(StopGround.apply(was, "unknown", 71), was))
		assert_true(is_same(StopGround.apply(was, "remote", 71), was))
		assert_eq(was.keys(), keys)
	# Three warnings a map: the count runs over the whole test.
	assert_push_warning_count(3 * PLACES.size())


func test_siding_keeps_its_yard_and_only_adds_the_keys() -> void:
	var was: Dictionary = _map("freight_01")
	var now: Dictionary = StopGround.apply(was.duplicate(), "siding", 71)
	assert_eq(now.size(), was.size() + 3)
	assert_eq(now["stop_form"], "siding")
	assert_true(is_same(now["grid"], was["grid"]))


func test_edge_nearer_than_the_village_row_warns_and_stays_a_city_stop() -> void:
	var was: Dictionary = _small_map(true)
	var train: Rect2i = was["train"]
	var grid: FieldGrid = was["grid"]
	var gap: float = absf(_center(train).y - StopGround.village_middle(was).y)
	assert_gt(gap, 1.0, "the village sits off the train's row")
	assert_true(is_same(StopGround.apply(was, "edge", 71, gap - 1.0), was))
	assert_eq(was["stop_form"], "city")
	assert_eq(was["stop_form_asked"], "edge", "what was asked stays, so it is not put on again")
	assert_true(is_same(FieldGame.shape_stop(was, "edge", 71, gap - 1.0, func() -> Dictionary: return {}), was))
	assert_true(is_same(was["grid"], grid))
	assert_eq(was["train"], train)
	assert_push_warning_count(1)


func test_seeded_walk_off_is_never_nearer_than_the_village_row() -> void:
	# The village 180 m down from the train's row: a seed may not ask for 150 m.
	for seed_value: int in [1, 8, 73, 1009]:
		var was: Dictionary = _small_map(true, 220, 200)
		var gap: float = absf(_center(was["train"]).y - StopGround.village_middle(was).y)
		assert_gt(gap, 150.0)
		var now: Dictionary = StopGround.apply(was, "edge", seed_value)
		var distance: float = _center(now["train"]).distance_to(StopGround.village_middle(now))
		assert_between(distance, gap, 300.0, "seed %d" % seed_value)


## The loader puts the side path on first (stop_loader.gd make_ready); the edge goes on a
## bare map and the side path after it, as on a map built in the field, and what the
## loader made ahead from the old map is dropped. A city stop keeps all of it.
func test_shape_stop_puts_the_edge_on_a_bare_map_before_the_side_path() -> void:
	var place: String = "houses_01"
	var found: Array = [-1, {}]
	for s: int in range(1, 200):
		if not SidePath.rolls(place, s):
			continue
		var d: Dictionary = SidePath.add(FieldMaps.build(place), s)
		if d.has("side_path"):
			found = [s, d]
			break
	var run_seed: int = found[0]
	assert_gt(run_seed, 0)
	var handed: Dictionary = found[1]
	handed["_ground_key"] = "made ahead"
	var shaped: Dictionary = FieldGame.shape_stop(handed, "edge", run_seed, 200.0, func() -> Dictionary: return FieldMaps.build(place))
	assert_false(shaped.has("side_path"), "built again bare")
	for key: String in FieldGame.AHEAD_KEYS:
		assert_false(shaped.has(key), key)
	var now: Dictionary = FieldGame.with_side_path(shaped, run_seed)
	assert_true(now.has("side_path"))
	assert_eq(now["stop_form"], "edge")
	var g: FieldGrid = now["grid"]
	var train: Rect2i = now["train"]
	for y: int in range(train.position.y, train.end.y):
		var rail: int = 0
		for x: int in range(train.end.x, train.end.x + StopGround.END_GAP):
			if g.floor_at(Vector2i(x, y)) == FieldGrid.Floor.RAIL:
				rail += 1
		for x: int in range(train.position.x - StopGround.END_GAP, train.position.x):
			if g.floor_at(Vector2i(x, y)) == FieldGrid.Floor.RAIL:
				rail += 1
		assert_eq(rail, 2 * StopGround.END_GAP, "row %d: track on both ends of the train" % y)
	var near: Rect2i = Rect2i(train.position.x - StopGround.END_GAP, train.position.y - 3, train.size.x + 2 * StopGround.END_GAP, train.size.y + 6)
	for tree: Vector2i in now["trees"]:
		assert_false(near.has_point(tree), "no tree on or by the track round the train")
	var kept: Dictionary = _map(place).duplicate()
	kept["_ground_key"] = "made ahead"
	assert_eq(FieldGame.shape_stop(kept, "city", 71, -1.0, func() -> Dictionary: return {})["_ground_key"], "made ahead")
	assert_true(FieldGame.shape_stop(kept, "", 71, -1.0, func() -> Dictionary: return {}).has("_ground_key"))


func test_middle_is_area_weighted_or_the_grid_middle() -> void:
	var g: FieldGrid = FieldGrid.new(80, 40)
	assert_eq(StopGround.village_middle({"grid": g, "buildings": []}), Vector2(40, 20))
	var data: Dictionary = {"grid": g, "buildings": [
		{"rect": Rect2i(0, 0, 2, 2)}, {"rect": Rect2i(10, 10, 4, 4)}]}
	assert_eq(StopGround.village_middle(data), Vector2(9.8, 9.8))


func test_edge_without_buildings_uses_the_grown_grid_middle() -> void:
	var data: Dictionary = _small_map(true)
	data["buildings"].clear()
	var now: Dictionary = StopGround.apply(data, "edge", 71, 200.0)
	var g: FieldGrid = now["grid"]
	var train: Rect2i = now["train"]
	assert_eq(StopGround.village_middle(now), Vector2(g.width, g.height) * 0.5)
	assert_between(_center(train).distance_to(StopGround.village_middle(now)), 199.0, 201.0)
	assert_gte(train.position.x, 12)
	assert_gte(g.width - train.end.x, 12)


func _small_map(to_right: bool, height: int = 40, building_y: int = 10) -> Dictionary:
	var g: FieldGrid = FieldGrid.new(80, height)
	var train: Rect2i = Rect2i(36, 20, 8, 3)
	for y: int in range(train.position.y, train.end.y):
		for x: int in range(g.width):
			g.floor[g.index(Vector2i(x, y))] = FieldGrid.Floor.RAIL
	for y: int in range(train.position.y, train.end.y):
		for x: int in range(train.position.x, train.end.x):
			g.set_solid(Vector2i(x, y), FieldGrid.Solid.BLOCK)
	for x: int in range(g.width):
		g.floor[g.index(Vector2i(x, 5))] = FieldGrid.Floor.ROAD
		g.floor[g.index(Vector2i(x, 6))] = FieldGrid.Floor.ROAD
	g.set_solid(Vector2i(0 if not to_right else g.width - 1, 6), FieldGrid.Solid.WALL)
	# The platform's painted floor.
	for y: int in range(23, 27):
		for x: int in range(36, 44):
			g.floor[g.index(Vector2i(x, y))] = FieldGrid.Floor.PLATFORM
	g.refresh_paths()
	return {"grid": g, "levels": {0: g}, "place_id": "stop_form_fixture",
		"train": train, "train_cars": FieldMaps.cars_of(train),
		"train_doors": {"upper": [Vector2i(39, 19)], "lower": [Vector2i(39, 23)]},
		"spawns": {"train_door": [Vector2i(39, 23)], "squad": [Vector2i(39, 25)], "dead_street": [Vector2i(10, 5)]},
		"buildings": [{"id": 0, "rect": Rect2i(10 if to_right else 66, building_y, 4, 4)}],
		"platform": Rect2i(36, 23, 8, 4), "unload": Rect2i(36, 23, 8, 2),
		"lights": [{"cell": Vector2i(42, 22), "side": Vector2i.DOWN}, {"cell": Vector2i(10, 10), "side": Vector2i.LEFT},
			{"cell": Vector2i(38, 25), "kind": "car_window", "side": Vector2i.DOWN}, {"cell": Vector2i(35, 21), "kind": "lamp", "side": Vector2i.LEFT}],
		"barricade_slots": [Vector2i(39, 18), Vector2i(10, 12)],
		"crossings": [{"cells": [Vector2i(40, 20), Vector2i(40, 21), Vector2i(40, 22)], "who": {"person": true}}],
		"bands": {"upper": Rect2i(0, 8, 80, 12)}, "rail_crossings": [Rect2i(10, 20, 2, 3)],
		"entries": {"west": [Vector2i(0, 5)], "east": [Vector2i(79, 5)], "drain": [Vector2i(79, 30)]},
		"manholes": {"drain": true},
		"anchors": {"village_gate": Vector2i(10, 12), "horde_home": Vector2i(39, 27), "flee_exit": Vector2i(79, 5)},
		"trees": [], "props": []}


func test_both_directions_move_only_train_attachments_and_extend_open_rows() -> void:
	for to_right: bool in [false, true]:
		var was: Dictionary = _small_map(to_right)
		was["_edge_plan"] = {"key": {"size": Vector2i(80, 40)}, "plan": {}}
		var old_solid: PackedByteArray = was["grid"].solid.duplicate()
		var old_floor: PackedByteArray = was["grid"].floor.duplicate()
		var now: Dictionary = StopGround.apply(was, "edge", 71, 200.0)
		var offset: Vector2i = _shift(was, now)
		var train: Rect2i = was["train"]
		var moved: Rect2i = now["train"]
		var travel: Vector2i = moved.position - train.position
		var g: FieldGrid = now["grid"]
		assert_eq(offset.x == 0, to_right)
		assert_false(now.has("_edge_plan"), "the old outer-band plan cannot follow a resized map")
		assert_between(_center(moved).distance_to(StopGround.village_middle(now)), 199.0, 201.0)
		assert_eq(now["lights"][0]["cell"], was["lights"][0]["cell"] + travel)
		assert_eq(now["lights"][1]["cell"], was["lights"][1]["cell"] + offset)
		assert_eq(now["lights"][0]["side"], Vector2i.DOWN)
		assert_eq(now["lights"][2]["cell"], was["lights"][2]["cell"] + travel, "a car window goes with its car")
		assert_eq(now["lights"][3]["cell"], was["lights"][3]["cell"] + offset, "a lamp by the track stays in town")
		var new_border: int = g.width - 1 if to_right else 0
		assert_eq(now["entries"]["east"][0], Vector2i(new_border, 5) if to_right else Vector2i(79, 5) + offset)
		assert_eq(now["entries"]["west"][0], Vector2i(0, 5) if to_right else Vector2i(new_border, 5))
		assert_eq(now["entries"]["drain"][0], Vector2i(79, 30) + offset, "a manhole stays where it is")
		assert_eq(now["anchors"]["flee_exit"], now["entries"]["east"][0], "the map's way out goes with its entry")
		assert_eq(now["anchors"]["horde_home"], Vector2i(39, 27) + travel, "the map's own anchor rides with the train")
		var platform_moved: bool = true
		for y: int in range(23, 27):
			for x: int in range(36, 44):
				var c: Vector2i = Vector2i(x, y)
				platform_moved = platform_moved and g.floor_at(c + offset) == FieldGrid.Floor.SNOW \
					and g.floor_at(c + travel) == FieldGrid.Floor.PLATFORM
		assert_true(platform_moved, "the platform's floor is painted by the new train, not the old track")
		assert_eq(now["barricade_slots"][0], was["barricade_slots"][0] + travel)
		assert_eq(now["barricade_slots"][1], was["barricade_slots"][1] + offset)
		assert_eq(now["bands"]["upper"], Rect2i(offset + Vector2i(0, 8), Vector2i(80, 12)))
		assert_eq(now["rail_crossings"][0], Rect2i(offset + Vector2i(10, 20), Vector2i(2, 3)))
		assert_eq(now["anchors"]["village_gate"], Vector2i(10, 12) + offset)
		assert_eq(now["spawns"]["squad"][0], was["spawns"]["squad"][0] + travel)
		assert_eq(now["spawns"]["dead_street"][0], was["spawns"]["dead_street"][0] + offset)
		for i: int in range(was["crossings"][0]["cells"].size()):
			assert_eq(now["crossings"][0]["cells"][i], was["crossings"][0]["cells"][i] + travel)
		var start: int = 80 if to_right else 0
		var end: int = g.width if to_right else offset.x
		var roads: bool = true
		var blocked: bool = true
		for x: int in range(start, end):
			roads = roads and g.floor_at(Vector2i(x, 5)) == FieldGrid.Floor.ROAD
			blocked = blocked and g.floor_at(Vector2i(x, 6)) == FieldGrid.Floor.SNOW
		assert_true(roads, "open boundary roads continue")
		assert_true(blocked, "a walled boundary row stays snow")
		for tree: Vector2i in now["trees"]:
			assert_true(tree.x >= start and tree.x < end)
			assert_true(tree.y < moved.position.y - 3 or tree.y > moved.end.y + 2)
			assert_eq(g.solid_at(tree), FieldGrid.Solid.BLOCK)
		assert_eq(now["trees"].size(), now["props"].size())
		for prop: Dictionary in now["props"]:
			assert_eq(prop["kind"], "bare_tree")
		assert_eq(was["train"], train)
		assert_eq(was["grid"].solid, old_solid)
		assert_eq(was["grid"].floor, old_floor)
