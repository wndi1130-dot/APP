extends "res://addons/gut/test.gd"

const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const StopGround = preload("res://game/world/stop_ground.gd")
const SidePath = preload("res://game/world/side_path.gd")
const FieldGame = preload("res://game/field_game.gd")
const WorkSpots = preload("res://game/world/work_spots.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const MapView = preload("res://game/world/map_view.gd")
const EdgeBand = preload("res://game/world/edge_band.gd")
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


func test_edge_is_idempotent_and_unknown_or_changed_forms_only_warn() -> void:
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
		assert_true(is_same(StopGround.apply(now, "remote", 71), now))
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


## Every cell's walk caches and both path grids' points (solid, weight), to compare.
static func _paths_of(g: FieldGrid) -> Array:
	var points := PackedFloat32Array()
	for y in range(g.height):
		for x in range(g.width):
			var c := Vector2i(x, y)
			points.append(1.0 if g.people_path.is_point_solid(c) else 0.0)
			points.append(1.0 if g.dead_path.is_point_solid(c) else 0.0)
			points.append(g.people_path.get_point_weight_scale(c))
	return [g.opq.duplicate(), g.walk_people.duplicate(), g.walk_dead.duplicate(), points]


## An edge stop refreshes only the cells it changed (the footprints and the trees) on paths
## carried over from the town: every floor ends as a full refresh would leave it.
func test_edge_paths_are_a_full_refresh_on_every_floor() -> void:
	for place: String in PLACES + ["first_leg_01_sulechow"]:
		var now: Dictionary = StopGround.apply(_map(place), "edge", 71, 200.0)
		assert_eq(now["stop_form"], "edge", place + ": the ground did grow")
		for lv in now["levels"]:
			var g: FieldGrid = now["levels"][lv]
			var kept := _paths_of(g)
			g.refresh_paths()
			assert_eq(kept, _paths_of(g), "%s level %d" % [place, lv])



## The existing hand map, moved down so both sides of the strip have deep forest.
## Its continued road is row 45, its train rows 60..62; row 46 is walled at the edge.
func _remote_fixture(to_right: bool) -> Dictionary:
	var key: String = "remote_fixture:%s" % to_right
	if not _built.has(key):
		var was: Dictionary = MapShift.shift_rows(_small_map(to_right, 80), 40)
		var g: FieldGrid = was["grid"]
		# Rails 57..67 touch the train; rail 10 and road 110 are detached.
		for y: int in [10, 57, 58, 59, 63, 64, 65, 66, 67, 110]:
			for x: int in range(g.width):
				var c: Vector2i = Vector2i(x, y)
				if g.floor_at(c) != FieldGrid.Floor.PLATFORM:
					g.floor[g.index(c)] = FieldGrid.Floor.ROAD if y == 110 else FieldGrid.Floor.RAIL
		was["entries"]["west"].append(Vector2i(0, 110))
		was["entries"]["east"].append(Vector2i(g.width - 1, 110))
		var edge_x: int = g.width - 1 if to_right else 0
		was["entries"]["rail_end"] = [Vector2i(edge_x, 60)]
		was["anchors"]["flee_exit"] = Vector2i(edge_x, 110)
		for lv: int in [-1, 1]:
			var other: FieldGrid = FieldGrid.new(g.width, g.height)
			other.solid.fill(FieldGrid.Solid.AIR if lv > 0 else FieldGrid.Solid.BLOCK)
			other.refresh_paths()
			was["levels"][lv] = other
		_built[key] = {"was": was, "now": StopGround.apply(was, "remote", 71, 600.0)}
	return _built[key]


func _added_ground(was: Dictionary, now: Dictionary) -> Rect2i:
	var old: FieldGrid = was["grid"]
	var g: FieldGrid = now["grid"]
	var offset: Vector2i = _shift(was, now)
	return Rect2i(0 if offset.x > 0 else old.width, 0, g.width - old.width, g.height)


func _in_forest(data: Dictionary, cell: Vector2i) -> bool:
	for rect: Rect2i in data.get("deep_forest", []):
		if rect.has_point(cell):
			return true
	return false


func _check_remote_village(now: Dictionary, label: String) -> void:
	var g: FieldGrid = now["grid"]
	var cell: Vector2i = now["village_middle"]
	var field: PackedInt32Array = WorkSpots.walk_field(now, 1000.0)
	assert_between(float(now["walk_to_village_m"]), 0.0, 1000.0, label)
	assert_lt(g.building_at(cell), 0, label + ": outdoors")
	assert_gte(field[g.index(cell)], 0, label + ": reached from the doors")
	assert_eq(float(now["walk_to_village_m"]), float(field[g.index(cell)]) / float(WorkSpots.STEP), label)
	var reached: bool = false
	for doors: Array in now["train_doors"].values():
		for door: Vector2i in doors:
			if g.people_can_walk(door) and not g.people_path.get_id_path(door, cell).is_empty():
				reached = true
	assert_true(reached, label + ": the people's path also reaches the village")


func test_remote_seeded_distances_and_walks_stay_in_range() -> void:
	for place: String in PLACES:
		for seed_value: int in [1, 8, 73, 1009]:
			var now: Dictionary = StopGround.apply(_map(place), "remote", seed_value)
			var label: String = "%s seed %d" % [place, seed_value]
			var distance: float = _center(now["train"]).distance_to(StopGround.village_middle(now))
			assert_between(distance, 400.0, 800.0, label)
			assert_between(float(now["walk_to_village_m"]), 0.0, 1000.0, label)
			assert_eq(now["stop_form"], "remote", label)


func test_remote_target_distance_and_seed_repeat() -> void:
	var was: Dictionary = _map("houses_01")
	var first: Dictionary = StopGround.apply(was, "remote", 71, 600.0)
	var again: Dictionary = StopGround.apply(was, "remote", 71, 600.0)
	assert_between(_center(first["train"]).distance_to(StopGround.village_middle(first)), 599.0, 601.0)
	assert_eq(first["train"], again["train"])
	assert_eq(first["trees"], again["trees"])
	assert_eq(first["props"], again["props"])
	assert_eq(first["deep_forest"], again["deep_forest"])
	assert_eq(first["grid"].solid, again["grid"].solid)
	assert_eq(first["grid"].floor, again["grid"].floor)
	_check_remote_village(first, "600 m")


func test_remote_forest_blocks_both_walkers_and_preserves_other_floors() -> void:
	for to_right: bool in [false, true]:
		var fixture: Dictionary = _remote_fixture(to_right)
		var was: Dictionary = fixture["was"]
		var now: Dictionary = fixture["now"]
		var g: FieldGrid = now["grid"]
		var upper: FieldGrid = now["levels"][1]
		var lower: FieldGrid = now["levels"][-1]
		var added: Rect2i = _added_ground(was, now)
		# Touching rails 57..67, padded by 24: rows 33..91, 59 of 120 rows.
		var strip: Rect2i = Rect2i(added.position.x, 33, added.size.x, 59)
		var expected: Array[Rect2i] = [
			Rect2i(added.position.x, 0, added.size.x, 33),
			Rect2i(added.position.x, 92, added.size.x, g.height - 92)]
		assert_eq(now["deep_forest"], expected)
		var closed: bool = true
		var cached: bool = true
		var covered: bool = true
		var other_floors: bool = true
		var forest_cells: int = 0
		for y: int in range(added.position.y, added.end.y):
			for x: int in range(added.position.x, added.end.x):
				var c: Vector2i = Vector2i(x, y)
				covered = covered and _in_forest(now, c) == (not strip.has_point(c))
				other_floors = other_floors and upper.solid_at(c) == FieldGrid.Solid.AIR and lower.solid_at(c) == FieldGrid.Solid.BLOCK
				if strip.has_point(c):
					continue
				forest_cells += 1
				var i: int = g.index(c)
				closed = closed and g.solid_at(c) == FieldGrid.Solid.BLOCK and g.floor_at(c) == FieldGrid.Floor.SNOW and g.building_at(c) == -1
				closed = closed and not g.people_can_walk(c) and not g.dead_can_walk(c)
				cached = cached and g.walk_people[i] == 0 and g.walk_dead[i] == 0 and g.opq[i] == 1
				cached = cached and g.people_path.is_point_solid(c) and g.dead_path.is_point_solid(c)
		assert_gt(forest_cells, 0)
		assert_true(closed, "every cell outside the strip blocks both walkers")
		assert_true(cached, "both walk caches, both paths and sight agree with the forest")
		assert_true(covered, "forest rectangles cover exactly the added ground outside the strip")
		assert_true(other_floors, "grow's air above and rock below stay intact")


func test_remote_open_rows_join_the_old_map_and_doors_reach_village() -> void:
	for to_right: bool in [false, true]:
		var fixture: Dictionary = _remote_fixture(to_right)
		var was: Dictionary = fixture["was"]
		var now: Dictionary = fixture["now"]
		var old: FieldGrid = was["grid"]
		var g: FieldGrid = now["grid"]
		var added: Rect2i = _added_ground(was, now)
		var train: Rect2i = now["train"]
		var edge_x: int = old.width - 1 if to_right else 0
		var offset: Vector2i = _shift(was, now)
		var joined: bool = true
		for y: int in [45, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67]:
			var floor_kind: int = old.floor_at(Vector2i(edge_x, y))
			var join: Vector2i = Vector2i(edge_x, y) + offset
			joined = joined and g.floor_at(join) == floor_kind and g.people_can_walk(join)
			for x: int in range(added.position.x, added.end.x):
				var c: Vector2i = Vector2i(x, y)
				joined = joined and g.floor_at(c) == floor_kind
				if not train.has_point(c):
					joined = joined and g.people_can_walk(c) and g.dead_can_walk(c)
		assert_true(joined, "open rail and road rows inside the strip join the old map")
		var ended: bool = true
		for y: int in [10, 110]:
			var join: Vector2i = Vector2i(edge_x, y) + offset
			ended = ended and g.people_can_walk(join) and g.dead_can_walk(join)
			for x: int in range(added.position.x, added.end.x):
				var c: Vector2i = Vector2i(x, y)
				ended = ended and _in_forest(now, c) and g.floor_at(c) == FieldGrid.Floor.SNOW \
					and g.solid_at(c) == FieldGrid.Solid.BLOCK and not g.people_can_walk(c) and not g.dead_can_walk(c)
		assert_true(ended, "detached rail and road rows end in snow-covered forest at the old border")
		assert_eq(g.floor_at(Vector2i(added.position.x, 46)), FieldGrid.Floor.SNOW, "a walled road row is not continued")
		_check_remote_village(now, "right" if to_right else "left")
		var cell_center: Vector2 = Vector2(now["village_middle"]) + Vector2.ONE * 0.5
		assert_lte(cell_center.distance_to(StopGround.village_middle(now)), 1.0, "the doors reach the village itself")


func test_remote_trees_are_sparse_inside_and_dense_only_at_forest_edge() -> void:
	for to_right: bool in [false, true]:
		var fixture: Dictionary = _remote_fixture(to_right)
		var now: Dictionary = fixture["now"]
		var added: Rect2i = _added_ground(fixture["was"], now)
		var strip: Rect2i = Rect2i(added.position.x, 33, added.size.x, 59)
		var tree_props: Dictionary = {}
		var dense_rows: Dictionary = {}
		for prop: Dictionary in now["props"]:
			var rect: Rect2i = prop["rect"]
			if added.has_point(rect.position):
				tree_props[rect.position] = prop
		var sparse: int = 0
		var dense: int = 0
		var placed: bool = true
		var shallow: bool = true
		for c: Vector2i in now["trees"]:
			placed = placed and added.has_point(c) and tree_props.has(c)
			if not tree_props.has(c):
				continue
			var prop: Dictionary = tree_props[c]
			placed = placed and prop["rect"] == Rect2i(c, Vector2i.ONE) and int(prop["level"]) == 0
			if strip.has_point(c):
				sparse += 1
				placed = placed and prop["kind"] == "bare_tree"
			else:
				dense += 1
				var depth: int = strip.position.y - c.y if c.y < strip.position.y else c.y - strip.end.y + 1
				shallow = shallow and _in_forest(now, c) and depth >= 1 and depth <= 6
				placed = placed and prop["kind"] == "spruce"
				if not dense_rows.has(c.y):
					dense_rows[c.y] = []
				(dense_rows[c.y] as Array).append(c.x)
		assert_gt(sparse, 0, "the open strip keeps sparse trees")
		assert_gt(dense, 0, "the forest edge has dense spruce")
		assert_true(placed, "every new tree has a one-cell ground prop of the existing tree kind")
		assert_true(shallow, "no tree is drawn beyond the first six metres of deep forest")
		for rect: Rect2i in now["deep_forest"]:
			var rows: Array[int] = []
			for y: int in dense_rows:
				if y >= rect.position.y and y < rect.end.y:
					rows.append(y)
			rows.sort()
			assert_gte(rows.size(), 2, "each forest edge has at least two dense rows")
			for i: int in range(1, rows.size()):
				assert_between(rows[i] - rows[i - 1], 2, 3, "dense row spacing")
		for row: Array in dense_rows.values():
			row.sort()
			assert_between(int(row[0]) - added.position.x, 0, 2, "seeded row start")
			assert_between(added.end.x - 1 - int(row[-1]), 0, 2, "trees reach the far end")
			for i: int in range(1, row.size()):
				assert_between(int(row[i]) - int(row[i - 1]), 2, 3, "dense tree spacing")


func test_remote_added_walkable_share_follows_the_strip_on_tall_maps() -> void:
	# These finished maps have 205, 195, 200 and 100 rows. A strip around 50..60 m
	# must stay below 60%; train solids and sparse trees take at most another 5%.
	for place: String in ["houses_01", "church_01", "freight_01", FieldMaps.DEFAULT_PLACE]:
		var was: Dictionary = _map(place)
		var now: Dictionary = StopGround.apply(was, "remote", 71, 600.0)
		var g: FieldGrid = now["grid"]
		var added: Rect2i = _added_ground(was, now)
		var forest_rows: int = 0
		for rect: Rect2i in now["deep_forest"]:
			forest_rows += rect.size.y
		var strip_height: int = added.size.y - forest_rows
		var walkable: int = 0
		for y: int in range(added.position.y, added.end.y):
			for x: int in range(added.position.x, added.end.x):
				if g.people_can_walk(Vector2i(x, y)):
					walkable += 1
		var share: float = float(walkable) / float(added.size.x * added.size.y)
		var strip_share: float = float(strip_height) / float(g.height)
		assert_gt(forest_rows, 0, place + ": a taller map keeps nonempty forest")
		assert_lt(strip_height, g.height, place)
		assert_lt(strip_share, 0.60, place + ": detached rows do not widen the strip")
		assert_lt(share, 0.60, place + ": added ground stays mostly forest")
		assert_lte(share, strip_share, place + ": no walking outside the strip")
		assert_gte(share, strip_share - 0.05, place + ": only train solids and sparse trees reduce walking")
		var calculated: Vector2i = FieldMaps.anchors(now)["flee_exit"]
		assert_true(g.people_can_walk(calculated), place + ": the calculated exit is walkable")
		assert_false(_in_forest(now, calculated), place + ": the calculated exit avoids forest")


func test_remote_entries_and_map_exit_outside_the_strip_stay_at_the_old_border() -> void:
	for to_right: bool in [false, true]:
		var fixture: Dictionary = _remote_fixture(to_right)
		var was: Dictionary = fixture["was"]
		var now: Dictionary = fixture["now"]
		var g: FieldGrid = now["grid"]
		var offset: Vector2i = _shift(was, now)
		var id: String = "east" if to_right else "west"
		var old_entry: Vector2i = was["entries"][id][1] + offset
		var kept: Vector2i = now["entries"][id][1]
		assert_eq(kept, old_entry, "the detached road entry stays in the old map")
		assert_true(g.people_can_walk(kept) and g.dead_can_walk(kept))
		assert_false(_in_forest(now, kept))
		var next: Vector2i = kept + Vector2i.RIGHT * (1 if to_right else -1)
		assert_true(_in_forest(now, next), "the next cell is already deep forest")
		assert_eq(g.solid_at(next), FieldGrid.Solid.BLOCK)
		assert_eq(g.floor_at(next), FieldGrid.Floor.SNOW)
		assert_eq(now["anchors"]["flee_exit"], kept, "the map's own exit stays before the forest too")
		var new_border: int = g.width - 1 if to_right else 0
		for cell: Vector2i in [now["entries"][id][0], now["entries"]["rail_end"][0]]:
			assert_eq(cell.x, new_border, "entries inside the strip still move out")
			assert_true(g.people_can_walk(cell) and g.dead_can_walk(cell))
			assert_false(_in_forest(now, cell))
		assert_eq(now["entries"]["drain"][0], was["entries"]["drain"][0] + offset, "a manhole stays put")


func test_remote_calculated_exit_is_rebuilt_on_a_walkable_border_cell() -> void:
	for to_right: bool in [false, true]:
		var was: Dictionary = _remote_fixture(to_right)["was"].duplicate(true)
		was["anchors"].erase("flee_exit")
		var now: Dictionary = StopGround.apply(was, "remote", 71, 600.0)
		var g: FieldGrid = now["grid"]
		var exit: Vector2i = now["anchors"]["flee_exit"]
		assert_eq(exit, FieldMaps.anchors(now)["flee_exit"])
		assert_true(g.people_can_walk(exit) and g.dead_can_walk(exit))
		assert_false(_in_forest(now, exit))
		assert_true(exit.x == 0 or exit.x == g.width - 1 or exit.y == 0 or exit.y == g.height - 1)


func test_remote_core_stops_at_a_road_or_blocked_rail_above_touching_rails() -> void:
	for solid: int in [FieldGrid.Solid.NONE, FieldGrid.Solid.WALL]:
		var was: Dictionary = MapShift.shift_rows(_small_map(true, 80), 40)
		var old: FieldGrid = was["grid"]
		for y: int in range(20, 60):
			old.floor[old.index(Vector2i(old.width - 1, y))] = FieldGrid.Floor.RAIL
		var break_cell: Vector2i = Vector2i(old.width - 1, 56)
		old.floor[old.index(break_cell)] = FieldGrid.Floor.ROAD if solid == FieldGrid.Solid.NONE else FieldGrid.Floor.RAIL
		old.set_solid(break_cell, solid)
		old.refresh_paths()
		var now: Dictionary = StopGround.apply(was, "remote", 71, 600.0)
		var added: Rect2i = _added_ground(was, now)
		assert_eq(now["deep_forest"][0], Rect2i(added.position.x, 0, added.size.x, 33),
			"the core stops at row 57, then gets 24 rows of padding")
		assert_true(_in_forest(now, Vector2i(added.position.x, 20)), "rail beyond the break is detached")


func test_remote_strip_covers_carried_attachments_before_adding_its_margin() -> void:
	var was: Dictionary = MapShift.shift_rows(_small_map(true, 200), 40)
	was["platform"] = Rect2i(36, 62, 8, 45)
	was["unload"] = Rect2i(36, 40, 8, 22)
	was["train_doors"]["upper"] = [Vector2i(39, 30)]
	was["spawns"]["squad"] = [Vector2i(39, 110)]
	was["spawns"]["train_door"] = [Vector2i(39, 115)]
	was["spawns"]["dead_street"] = [Vector2i(10, 210)]
	was["lights"].append({"kind": "car_window", "cell": Vector2i(38, 29), "level": 0})
	was["lights"].append({"kind": "lamp", "cell": Vector2i(10, 200), "level": 0})
	was["crossings"][0]["cells"].append(Vector2i(40, 125))
	var now: Dictionary = StopGround.apply(was, "remote", 71, 600.0)
	var added: Rect2i = _added_ground(was, now)
	var train: Rect2i = now["train"]
	var carried: Array = [now["barricade_slots"][0], now["lights"][-2]["cell"]]
	for doors: Array in now["train_doors"].values():
		carried.append_array(doors)
	for key: String in ["train_door", "squad"]:
		carried.append_array(now["spawns"][key])
	for crossing: Dictionary in now["crossings"]:
		carried.append_array(crossing["cells"])
	for cell: Vector2i in carried:
		assert_false(_in_forest(now, cell), "every carried cell stays inside the strip")
	for rect: Rect2i in [now["platform"], now["unload"], train]:
		assert_false(_in_forest(now, rect.position))
		assert_false(_in_forest(now, rect.end - Vector2i.ONE))
	# Car window row 29 and crossing row 125 set the core, not the town lamp or dead.
	assert_true(_in_forest(now, Vector2i(added.position.x, 4)))
	assert_false(_in_forest(now, Vector2i(added.position.x, 5)), "24 cells above the carried light")
	assert_false(_in_forest(now, Vector2i(added.position.x, 149)), "24 cells below the carried crossing")
	assert_true(_in_forest(now, Vector2i(added.position.x, 150)))


func test_remote_is_idempotent() -> void:
	for to_right: bool in [false, true]:
		var now: Dictionary = _remote_fixture(to_right)["now"]
		var g: FieldGrid = now["grid"]
		var train: Rect2i = now["train"]
		var keys: Array = now.keys()
		var trees: Array = now["trees"].duplicate()
		var forest: Array = now["deep_forest"].duplicate()
		var walk: float = float(now["walk_to_village_m"])
		assert_eq(now["stop_form"], "remote")
		assert_true(is_same(StopGround.apply(now, "remote", 999, 450.0), now))
		assert_true(is_same(now["grid"], g))
		assert_eq(now["train"], train)
		assert_eq(now.keys(), keys)
		assert_eq(now["trees"], trees)
		assert_eq(now["deep_forest"], forest)
		assert_eq(float(now["walk_to_village_m"]), walk)


func test_remote_nearer_than_the_village_row_warns_and_stays_city() -> void:
	var was: Dictionary = _small_map(true, 500, 450)
	var g: FieldGrid = was["grid"]
	var train: Rect2i = was["train"]
	var gap: float = absf(_center(train).y - StopGround.village_middle(was).y)
	assert_gt(gap, 400.0)
	assert_true(is_same(StopGround.apply(was, "remote", 71, gap - 1.0), was))
	assert_true(is_same(was["grid"], g))
	assert_eq(was["train"], train)
	assert_eq(was["stop_form"], "city")
	assert_eq(was["stop_form_asked"], "remote")
	assert_push_warning_count(1)


func test_remote_walk_limit_reaches_village_at_eight_hundred_meters() -> void:
	var now: Dictionary = StopGround.apply(_small_map(true), "remote", 71, 800.0)
	_check_remote_village(now, "800 m")
	assert_gt(float(now["walk_to_village_m"]), 600.0)
	var cell_center: Vector2 = Vector2(now["village_middle"]) + Vector2.ONE * 0.5
	assert_lte(cell_center.distance_to(StopGround.village_middle(now)), 1.0)


func test_deep_forest_rectangles_are_skipped_by_outdoor_block_runs() -> void:
	var data: Dictionary = _small_map(true, 80)
	var g: FieldGrid = data["grid"]
	var forest: Rect2i = Rect2i(2, 40, 5, 4)
	var ordinary: Vector2i = Vector2i(10, 40)
	for y: int in range(forest.position.y, forest.end.y):
		for x: int in range(forest.position.x, forest.end.x):
			g.set_solid(Vector2i(x, y), FieldGrid.Solid.BLOCK)
	g.set_solid(ordinary, FieldGrid.Solid.BLOCK)
	data["deep_forest"] = [forest]
	var skipped: bool = true
	var kept: bool = false
	for run: Rect2i in MapView.outdoor_block_runs(g, data):
		skipped = skipped and not run.intersects(forest)
		kept = kept or run.has_point(ordinary)
	assert_true(skipped, "deep forest does not become outdoor block boxes")
	assert_true(kept, "ordinary outdoor blocks still draw")
	data.erase("deep_forest")
	var visible: bool = false
	for run: Rect2i in MapView.outdoor_block_runs(g, data):
		visible = visible or run.intersects(forest)
	assert_true(visible, "maps without deep forest keep their block boxes")


func test_city_edge_and_siding_do_not_gain_deep_forest() -> void:
	for form: String in ["city", "edge", "siding"]:
		var was: Dictionary = _small_map(true)
		var g: FieldGrid = was["grid"]
		var train: Rect2i = was["train"]
		var solid: PackedByteArray = g.solid.duplicate()
		var floor: PackedByteArray = g.floor.duplicate()
		var now: Dictionary = StopGround.apply(was, form, 71, 200.0)
		assert_false(now.has("deep_forest"), form)
		assert_eq(now["stop_form"], form)
		if form != "edge":
			assert_true(is_same(now, was), form)
			assert_true(is_same(now["grid"], g), form)
			assert_eq(now["train"], train, form)
			assert_eq(g.solid, solid, form)
			assert_eq(g.floor, floor, form)


func test_remote_own_anchor_off_the_strip_is_worked_out_again() -> void:
	var was: Dictionary = MapShift.shift_rows(_small_map(true, 80), 40)
	# Far below the train's rows (60..62): the map set it, so it moves with the train.
	was["anchors"]["horde_home"] = Vector2i(39, 110)
	var now: Dictionary = StopGround.apply(was, "remote", 71, 600.0)
	assert_true(now.has("deep_forest"))
	var home: Vector2i = now["anchors"].get("horde_home", Vector2i(-1, -1))
	assert_true(now["anchors"].has("horde_home"), "worked out from the moved train")
	assert_false(_in_forest(now, home), "not in the deep forest")
	assert_eq(now["grid"].solid_at(home), FieldGrid.Solid.NONE)


func test_remote_strip_cut_off_from_the_village_warns_and_stays_city() -> void:
	var was: Dictionary = MapShift.shift_rows(_small_map(true, 80), 40)
	var g: FieldGrid = was["grid"]
	# A wall all down the old border: the strip would meet the old map nowhere.
	for y: int in range(g.height):
		g.solid[g.index(Vector2i(g.width - 1, y))] = FieldGrid.Solid.WALL
	g.refresh_paths()
	var now: Dictionary = StopGround.apply(was, "remote", 71, 600.0)
	assert_true(is_same(now, was), "the map as it was")
	assert_eq(now["stop_form"], "city")
	assert_eq(now["stop_form_asked"], "remote")
	assert_eq(now["grid"].width, 80, "not grown")
	assert_false(now.has("deep_forest"))


## Each door and squad spot's metres to the map's nearer side end (x), from its cell's middle.
func _end_reach(now: Dictionary) -> float:
	var g: FieldGrid = now["grid"]
	var cells: Array = []
	for doors: Array in now.get("train_doors", {}).values():
		cells.append_array(doors)
	cells.append_array(now.get("spawns", {}).get("squad", []))
	var reach: float = INF
	for c: Vector2i in cells:
		reach = minf(reach, minf(float(c.x) + 0.5, float(g.width) - float(c.x) - 0.5))
	return reach


func test_view_reach_covers_the_furthest_view_on_a_wide_screen() -> void:
	assert_gte(StopGround.MAX_ASPECT, 22.0 / 9.0, "wider than the 21:9 phones")
	for aspect: float in [16.0 / 9.0, 21.0 / 9.0, StopGround.MAX_ASPECT]:
		var half: Vector2 = EdgeBand.view_half(36.0, aspect, FieldGame.CAM_PITCH, FieldGame.CAM_YAW)
		assert_gte(StopGround.VIEW_REACH, maxf(half.x, half.y), "aspect %.3f" % aspect)


func test_outlying_doors_stand_a_full_view_from_the_map_end() -> void:
	var places: Array[String] = PLACES.duplicate()
	places.append("church_01")
	for place: String in places:
		assert_gte(_end_reach(_edge(place)), StopGround.VIEW_REACH, place + " edge")
	for to_right: bool in [true, false]:
		var now: Dictionary = _remote_fixture(to_right)["now"]
		assert_gte(_end_reach(now), StopGround.VIEW_REACH, "remote fixture %s" % to_right)


## A door one cell past the train's end on the grown side stands nearer the map's end
## than the train's end does: its offset counts negative, not as the end cell.
func test_a_spot_past_the_trains_end_still_stands_a_full_view_from_the_map_end() -> void:
	for to_right: bool in [true, false]:
		var was: Dictionary = _small_map(to_right)
		var train: Rect2i = was["train"]
		was["train_doors"]["lower"].append(Vector2i(train.end.x if to_right else train.position.x - 1, train.end.y))
		var now: Dictionary = StopGround.apply(was, "edge", 71, 200.0)
		assert_gte(_end_reach(now), StopGround.VIEW_REACH, "to_right %s" % to_right)
