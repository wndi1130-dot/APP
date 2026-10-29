extends "res://addons/gut/test.gd"

const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const StopForm = preload("res://game/world/stop_form.gd")
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
		_built[key] = StopForm.apply(_map(place), "edge", 71, 200.0)
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
		assert_true(is_same(StopForm.apply(data, "", 71), data), place)
		assert_eq(data.keys(), keys)
		assert_false(data.has("stop_form"))


func test_edge_distance_and_walk_to_village() -> void:
	for place: String in PLACES:
		var was: Dictionary = _map(place)
		var now: Dictionary = _edge(place)
		var old: FieldGrid = was["grid"]
		var g: FieldGrid = now["grid"]
		assert_false(is_same(was, now))
		assert_between(_center(now["train"]).distance_to(StopForm.village_middle(now)), 199.0, 201.0, place)
		assert_gt(g.width, old.width)
		assert_eq(g.height, old.height)
		assert_gte(float(now["walk_to_village_m"]), 150.0, place)
		assert_eq(now["stop_form"], "edge")
		var middle: Vector2 = StopForm.village_middle(now)
		var cell: Vector2i = g.nearest_walkable(Vector2i(floori(middle.x), floori(middle.y)), false, 12)
		assert_eq(now["village_middle"], cell)
		assert_true(g.people_can_walk(cell))
		var field: PackedInt32Array = WorkSpots.walk_field(now, 600.0)
		assert_eq(float(now["walk_to_village_m"]), float(field[g.index(cell)]) / float(WorkSpots.STEP))


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


func test_train_anchors_and_boarding_are_rebuilt() -> void:
	for place: String in PLACES:
		var now: Dictionary = _edge(place)
		var train: Rect2i = now["train"]
		var worked: Dictionary = FieldMaps.anchors(now)
		for key: String in ["whistle", "engine"]:
			assert_true(train.grow(2).has_point(now["anchors"][key]), place)
		for key: String in worked:
			assert_eq(now["anchors"][key], worked[key])
		assert_eq(now["boarding"], [now["platform"]] + FieldMaps.side_strips(now, now["platform"]))
		assert_eq(now["unloading"], [now["unload"]] + FieldMaps.side_strips(now, now["unload"]))


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
					if old.solid_at(c) != g.solid_at(c + offset) or old.floor_at(c) != g.floor_at(c + offset):
						unchanged = false
			assert_true(unchanged, "%s level %d: old cells keep solid and floor" % [place, lv])
		assert_false(was.has("stop_form"), "the input is still an undressed map")


func test_seed_repeats_and_default_distances_stay_in_range() -> void:
	for place: String in PLACES:
		var was: Dictionary = _map(place)
		var first: Dictionary = StopForm.apply(was, "edge", 71)
		var again: Dictionary = StopForm.apply(was, "edge", 71)
		assert_eq(first["train"], again["train"])
		assert_eq(first["grid"].width, again["grid"].width)
		assert_eq(first["grid"].height, again["grid"].height)
		assert_eq(first["trees"], again["trees"])
		for seed_value: int in [1, 8, 73, 1009]:
			var now: Dictionary = StopForm.apply(was, "edge", seed_value)
			var distance: float = _center(now["train"]).distance_to(StopForm.village_middle(now))
			assert_between(distance, 150.0, 300.0, "%s seed %d" % [place, seed_value])


func test_city_only_adds_the_three_handoff_keys() -> void:
	for place: String in PLACES:
		var was: Dictionary = _map(place)
		var data: Dictionary = was.duplicate(true)
		var now: Dictionary = StopForm.apply(data, "city", 71)
		assert_true(is_same(data, now))
		assert_eq(now.size(), was.size() + 3)
		for key: String in was:
			assert_eq(now[key], was[key], place + ": " + key)
		assert_eq(now["stop_form"], "city")
		assert_true(now["village_middle"] is Vector2i)
		assert_true(now["walk_to_village_m"] is float)


func test_work_spots_can_dress_an_edge() -> void:
	for place: String in PLACES:
		var data: Dictionary = StopForm.apply(_map(place), "edge", 71, 200.0)
		var train: Rect2i = data["train"]
		WorkSpots.dress(data, -1, 1)
		assert_true(data.has("fell_groves"), place)
		assert_eq(data["train"], train)
		var field: PackedInt32Array = data["_walk_field"]
		var g: FieldGrid = data["grid"]
		assert_eq(field.size(), g.width * g.height)


func test_edge_is_idempotent_and_unknown_form_only_warns() -> void:
	for place: String in PLACES:
		var now: Dictionary = _edge(place)
		var train: Rect2i = now["train"]
		assert_true(is_same(StopForm.apply(now, "edge", 999, 275.0), now))
		assert_eq(now["train"], train)
		var was: Dictionary = _map(place)
		var keys: Array = was.keys()
		assert_true(is_same(StopForm.apply(was, "unknown", 71), was))
		assert_eq(was.keys(), keys)
	# One warning a map: the count runs over the whole test.
	assert_push_warning_count(PLACES.size())


func test_edge_nearer_than_the_village_row_warns_and_keeps_the_map() -> void:
	var was: Dictionary = _small_map(true)
	var train: Rect2i = was["train"]
	var gap: float = absf(_center(train).y - StopForm.village_middle(was).y)
	assert_gt(gap, 1.0, "the village sits off the train's row")
	var keys: Array = was.keys()
	assert_true(is_same(StopForm.apply(was, "edge", 71, gap - 1.0), was))
	assert_eq(was.keys(), keys)
	assert_eq(was["train"], train)
	assert_push_warning_count(1)


func test_middle_is_area_weighted_or_the_grid_middle() -> void:
	var g: FieldGrid = FieldGrid.new(80, 40)
	assert_eq(StopForm.village_middle({"grid": g, "buildings": []}), Vector2(40, 20))
	var data: Dictionary = {"grid": g, "buildings": [
		{"rect": Rect2i(0, 0, 2, 2)}, {"rect": Rect2i(10, 10, 4, 4)}]}
	assert_eq(StopForm.village_middle(data), Vector2(9.8, 9.8))


func test_edge_without_buildings_uses_the_grown_grid_middle() -> void:
	var data: Dictionary = _small_map(true)
	data["buildings"].clear()
	var now: Dictionary = StopForm.apply(data, "edge", 71, 200.0)
	var g: FieldGrid = now["grid"]
	var train: Rect2i = now["train"]
	assert_eq(StopForm.village_middle(now), Vector2(g.width, g.height) * 0.5)
	assert_between(_center(train).distance_to(StopForm.village_middle(now)), 199.0, 201.0)
	assert_gte(train.position.x, 12)
	assert_gte(g.width - train.end.x, 12)


func _small_map(to_right: bool) -> Dictionary:
	var g: FieldGrid = FieldGrid.new(80, 40)
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
	g.refresh_paths()
	return {"grid": g, "levels": {0: g}, "place_id": "stop_form_fixture",
		"train": train, "train_cars": FieldMaps.cars_of(train),
		"train_doors": {"upper": [Vector2i(39, 19)], "lower": [Vector2i(39, 23)]},
		"spawns": {"train_door": [Vector2i(39, 23)], "squad": [Vector2i(39, 25)], "dead_street": [Vector2i(10, 5)]},
		"buildings": [{"id": 0, "rect": Rect2i(10 if to_right else 66, 10, 4, 4)}],
		"platform": Rect2i(36, 23, 8, 4), "unload": Rect2i(36, 23, 8, 2),
		"lights": [{"cell": Vector2i(42, 22), "side": Vector2i.DOWN}, {"cell": Vector2i(10, 10), "side": Vector2i.LEFT}],
		"barricade_slots": [Vector2i(39, 18), Vector2i(10, 12)],
		"crossings": [{"cells": [Vector2i(40, 20), Vector2i(40, 21), Vector2i(40, 22)], "who": {"person": true}}],
		"bands": {"upper": Rect2i(0, 8, 80, 12)}, "rail_crossings": [Rect2i(10, 20, 2, 3)],
		"anchors": {"village_gate": Vector2i(10, 12)}, "trees": [], "props": []}


func test_both_directions_move_only_train_attachments_and_extend_open_rows() -> void:
	for to_right: bool in [false, true]:
		var was: Dictionary = _small_map(to_right)
		was["_edge_plan"] = {"key": {"size": Vector2i(80, 40)}, "plan": {}}
		var old_solid: PackedByteArray = was["grid"].solid.duplicate()
		var old_floor: PackedByteArray = was["grid"].floor.duplicate()
		var now: Dictionary = StopForm.apply(was, "edge", 71, 200.0)
		var offset: Vector2i = _shift(was, now)
		var train: Rect2i = was["train"]
		var moved: Rect2i = now["train"]
		var travel: Vector2i = moved.position - train.position
		var g: FieldGrid = now["grid"]
		assert_eq(offset.x == 0, to_right)
		assert_false(now.has("_edge_plan"), "the old outer-band plan cannot follow a resized map")
		assert_between(_center(moved).distance_to(StopForm.village_middle(now)), 199.0, 201.0)
		assert_eq(now["lights"][0]["cell"], was["lights"][0]["cell"] + travel)
		assert_eq(now["lights"][1]["cell"], was["lights"][1]["cell"] + offset)
		assert_eq(now["lights"][0]["side"], Vector2i.DOWN)
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
