extends "res://addons/gut/test.gd"

const WorkSpots = preload("res://game/world/work_spots.gd")
const EdgeBand = preload("res://game/world/edge_band.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const BuildingUses = preload("res://game/world/building_uses.gd")
const RUN_SEED: int = 731


func _map(place_id: String) -> Dictionary:
	return FieldMaps.build_from(load(FieldMaps.path_of(place_id)) as Script)


func _food(data: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in data.get("work_sites", []) as Array:
		if String(row.get("kind", "")) == "food":
			out.append(row)
	return out


func _dress_unchanged(data: Dictionary, seg: int, run_seed: int = RUN_SEED) -> void:
	var g: FieldGrid = data["grid"] as FieldGrid
	var solids: PackedByteArray = g.solid.duplicate()
	var floors: PackedByteArray = g.floor.duplicate()
	WorkSpots.dress(data, seg, run_seed)
	assert_eq(g.solid, solids, "dress keeps every solid")
	assert_eq(g.floor, floors, "dress keeps every floor")


func _check_food(data: Dictionary, allowed: Array[String]) -> void:
	var food: Array[Dictionary] = _food(data)
	assert_eq(food.size(), 1, "one depot on this candidate stop")
	if food.size() != 1:
		return
	var g: FieldGrid = data["grid"] as FieldGrid
	var site: Dictionary = food[0]
	assert_true(allowed.has(String(site["food"])), "food fits the map group")
	assert_eq(int(site["level"]), 0)
	assert_eq(float(site["cap_segments"]), 1.5)
	assert_between(float(site["path_m"]), 0.0, WorkSpots.MAX_PATH_M)
	var stand: Array = site["stand"] as Array
	assert_false(stand.is_empty())
	var nearest: float = INF
	for cell: Vector2i in stand:
		assert_true(g.people_can_walk(cell), "stand is walkable")
		var distance: float = WorkSpots.reach(data, cell)
		assert_between(distance, 0.0, WorkSpots.MAX_PATH_M, "stand has a complete short path")
		nearest = minf(nearest, distance)
	assert_almost_eq(float(site["path_m"]), nearest, 0.001)
	if String(site["food"]) == "reefer":
		assert_eq(int(site["building"]), -1)
	if String(site["food"]) == "military":
		var uses_store: bool = false
		for row: Dictionary in data.get("buildings", []) as Array:
			if int(row["id"]) == int(site["building"]):
				uses_store = BuildingUses.use_of(row) == "store"
		assert_true(uses_store, "military only changes a store's kind")


func _small_data() -> Dictionary:
	var g: FieldGrid = FieldGrid.new(60, 40)
	for x: int in range(g.width):
		g.floor[g.index(Vector2i(x, 20))] = FieldGrid.Floor.RAIL
	g.refresh_paths()
	return {"grid": g, "place_id": "sawmill_01", "trees": [],
		"train_doors": {"lower": [Vector2i(30, 21)]}}


func test_depot_segments_are_sparse_repeatable_pairs() -> void:
	var within_total: float = 0.0
	var within_count: int = 0
	var all_total: float = 0.0
	var all_count: int = 0
	for run_seed: int in range(1, 51):
		var previous: int = -1
		for block: int in range(4):
			var pair: Array[int] = WorkSpots.depot_segments(run_seed, block)
			assert_eq(pair.size(), 2)
			assert_eq(pair, WorkSpots.depot_segments(run_seed, block), "same seed, same pair")
			if pair.size() != 2:
				continue
			for seg: int in pair:
				assert_between(seg - block * 9, 1, 7)
				if previous >= 0:
					assert_gte(seg - previous, 3, "three or more apart across blocks too")
					all_total += float(seg - previous)
					all_count += 1
				previous = seg
			assert_between(pair[1] - pair[0], 3, 6)
			within_total += float(pair[1] - pair[0])
			within_count += 1
	assert_between(within_total / float(maxi(1, within_count)), 3.5, 4.5)
	assert_between(all_total / float(maxi(1, all_count)), 4.0, 5.0)


func test_factory_candidate_has_food_once() -> void:
	var data: Dictionary = _map("factory_01")
	var pair: Array[int] = WorkSpots.depot_segments(RUN_SEED, 0)
	_dress_unchanged(data, pair[0])
	_check_food(data, ["canned", "grain", "military"])
	var sites: Array = (data.get("work_sites", []) as Array).duplicate(true)
	_dress_unchanged(data, pair[0])
	assert_eq(data.get("work_sites", []) as Array, sites, "a second dress adds no depot")


func test_factory_non_candidate_and_negative_segment_have_no_food() -> void:
	var data: Dictionary = _map("factory_01")
	var pair: Array[int] = WorkSpots.depot_segments(RUN_SEED, 0)
	var ordinary: int = 0
	while pair.has(ordinary):
		ordinary += 1
	_dress_unchanged(data, ordinary)
	assert_true(_food(data).is_empty(), "not moved to another stop")
	_dress_unchanged(data, -1)
	assert_true(_food(data).is_empty(), "no departure means no depot")


func test_houses_candidate_has_a_wholesale_depot() -> void:
	var data: Dictionary = _map("houses_01")
	_dress_unchanged(data, WorkSpots.depot_segments(RUN_SEED, 0)[0])
	_check_food(data, ["wholesale", "military"])


func test_freight_candidate_uses_a_siding_wagon() -> void:
	var data: Dictionary = _map("freight_01")
	assert_false((data.get("wagons", []) as Array).is_empty(), "siding stock is in wagons")
	_dress_unchanged(data, WorkSpots.depot_segments(RUN_SEED, 0)[0])
	_check_food(data, ["reefer"])


func test_bare_line_groves_are_disjoint_and_not_added_twice() -> void:
	var data: Dictionary = _map("bare_line_01")
	var g: FieldGrid = data["grid"] as FieldGrid
	_dress_unchanged(data, -1)
	var groves: Array = data.get("fell_groves", []) as Array
	assert_between(groves.size(), 1, 3)
	var seen: Dictionary = {}
	for grove: Dictionary in groves:
		assert_eq(String(grove["kind"]), "fell")
		assert_false(bool(grove["edge"]))
		assert_gte(int(grove["trees"]), 4)
		assert_eq(int(grove["trees"]), (grove["cells"] as Array).size())
		assert_false((grove["stand"] as Array).is_empty())
		for cell: Vector2i in grove["cells"] as Array:
			assert_false(seen.has(cell), "no tree belongs to two groves")
			seen[cell] = true
			assert_eq(g.solid_at(cell), FieldGrid.Solid.BLOCK)
		for cell: Vector2i in grove["stand"] as Array:
			assert_true(g.people_can_walk(cell))
			assert_false((data["trees"] as Array).has(cell))
	var before: Array = groves.duplicate(true)
	_dress_unchanged(data, -1)
	assert_eq(data["fell_groves"] as Array, before)


func test_tree_components_are_transitive_and_preserve_existing_metadata() -> void:
	var data: Dictionary = _small_data()
	var g: FieldGrid = data["grid"] as FieldGrid
	var trees: Array[Vector2i] = [Vector2i(10, 10), Vector2i(12, 12), Vector2i(14, 14), Vector2i(16, 16)]
	data["trees"] = trees
	for cell: Vector2i in trees:
		g.set_solid(cell, FieldGrid.Solid.BLOCK)
	g.refresh_paths()
	var edge: Dictionary = {"kind": "fell", "edge": true, "trees": 6}
	var stock: Dictionary = {"kind": "wood", "rect": Rect2i(1, 1, 2, 2),
		"stand": [Vector2i(3, 1)], "level": 0, "building": -1}
	data["fell_groves"] = [edge]
	data["work_sites"] = [stock]
	_dress_unchanged(data, -1)
	var groves: Array = data["fell_groves"] as Array
	assert_eq(groves.size(), 2, "one transitive component plus the original edge row")
	assert_eq(groves[0] as Dictionary, edge)
	assert_eq((data["work_sites"] as Array)[0] as Dictionary, stock)
	if groves.size() == 2:
		assert_eq(int((groves[1] as Dictionary)["trees"]), 4)


func test_missing_doors_add_nothing_and_spawn_doors_are_the_fallback() -> void:
	var data: Dictionary = _small_data()
	var g: FieldGrid = data["grid"] as FieldGrid
	data["train_doors"] = {"lower": [], "upper": []}
	data["buildings"] = [{"id": 1, "name": "곡물 곳간", "rect": Rect2i(10, 10, 4, 4)}]
	_dress_unchanged(data, WorkSpots.depot_segments(RUN_SEED, 0)[0])
	assert_false(data.has("fell_groves"))
	assert_false(data.has("work_sites"))
	assert_eq(WorkSpots.reach(data, Vector2i(30, 21)), -1.0)
	var p: Dictionary = EdgeBand.plan(g, 77, EdgeBand.look_of(data))
	assert_true(EdgeBand.fell_groves(g, p, data).is_empty())
	data["spawns"] = {"train_door": [Vector2i(30, 21)]}
	assert_eq(WorkSpots.reach(data, Vector2i(30, 21)), 0.0)
	assert_almost_eq(WorkSpots.reach(data, Vector2i(30, 24)), 3.0, 0.001)
	_dress_unchanged(data, WorkSpots.depot_segments(RUN_SEED, 0)[0])
	_check_food(data, ["grain"])


func test_reach_counts_the_start_uses_all_doors_and_rejects_partial_paths() -> void:
	var data: Dictionary = _small_data()
	var g: FieldGrid = data["grid"] as FieldGrid
	data["train_doors"] = {"lower": [Vector2i(2, 10)], "upper": [Vector2i(8, 10)]}
	assert_almost_eq(WorkSpots.reach(data, Vector2i(10, 10)), 2.0, 0.001)
	for y: int in range(g.height):
		g.set_solid(Vector2i(20, y), FieldGrid.Solid.WALL)
	g.refresh_paths()
	assert_eq(WorkSpots.reach(data, Vector2i(25, 10)), -1.0, "partial path is not arrival")
	assert_eq(WorkSpots.reach(data, Vector2i(20, 10)), -1.0, "a wall is not a stand")


func test_food_path_limit_is_walked_distance_not_just_straight_distance() -> void:
	var g: FieldGrid = FieldGrid.new(100, 100)
	for y: int in range(80):
		g.set_solid(Vector2i(20, y), FieldGrid.Solid.WALL)
	g.refresh_paths()
	var data: Dictionary = {"grid": g, "place_id": "factory_99",
		"train_doors": {"lower": [Vector2i(10, 10)]},
		"buildings": [{"id": 1, "name": "통조림 창고", "rect": Rect2i(30, 10, 4, 4)}]}
	var detour: float = WorkSpots.reach(data, Vector2i(29, 10))
	assert_true(detour < 0.0 or detour > WorkSpots.MAX_PATH_M, "19 m away in a line, much more on foot")
	_dress_unchanged(data, WorkSpots.depot_segments(RUN_SEED, 0)[0])
	assert_true(_food(data).is_empty(), "a long detour rejects a nearby depot")
	assert_eq(WorkSpots.reach(data, Vector2i(99, 99)), -1.0, "straight distance exceeds 90 m")


func test_depot_uses_door_fronts_and_does_not_replace_blocked_fronts() -> void:
	var data: Dictionary = _small_data()
	var g: FieldGrid = data["grid"] as FieldGrid
	data["place_id"] = "factory_99"
	data["buildings"] = [{"id": 1, "name": "통조림 창고", "rect": Rect2i(10, 10, 4, 4)}]
	for y: int in range(10, 14):
		for x: int in range(10, 14):
			g.set_solid(Vector2i(x, y), FieldGrid.Solid.WALL)
	var door: Vector2i = Vector2i(10, 11)
	g.doors[door] = {"state": "open", "planks": [0, 0]}
	g.set_solid(door, FieldGrid.Solid.DOOR)
	g.refresh_paths()
	var seg: int = WorkSpots.depot_segments(RUN_SEED, 0)[0]
	_dress_unchanged(data, seg)
	_check_food(data, ["canned", "military"])
	var food: Array[Dictionary] = _food(data)
	if food.size() == 1:
		assert_eq(food[0]["stand"] as Array, [Vector2i(9, 11)], "only the door's outside face")
	data.erase("work_sites")
	g.set_solid(Vector2i(9, 11), FieldGrid.Solid.BLOCK)
	g.refresh_paths()
	_dress_unchanged(data, seg)
	assert_true(_food(data).is_empty(), "a blocked front does not turn into a doorless perimeter")


func test_freight_without_wagons_falls_back_to_a_store_or_nothing() -> void:
	var data: Dictionary = _small_data()
	data["place_id"] = "freight_99"
	data["buildings"] = [{"id": 1, "name": "식료 창고", "rect": Rect2i(10, 10, 4, 4)}]
	var seg: int = WorkSpots.depot_segments(RUN_SEED, 0)[0]
	_dress_unchanged(data, seg)
	_check_food(data, ["wholesale", "military"])
	data.erase("work_sites")
	data["buildings"] = []
	_dress_unchanged(data, seg)
	assert_true(_food(data).is_empty(), "no matching site means no depot")


func test_edge_groves_accept_any_tall_model_and_skip_low_or_deep_plants() -> void:
	var data: Dictionary = _small_data()
	var g: FieldGrid = data["grid"] as FieldGrid
	var trees: Array[Dictionary] = []
	for i: int in range(6):
		trees.append({"at": Vector3(-1.0, 0.0, 8.5 + float(i)), "yaw": 0.0,
			"model": "any_tree", "height": 2.0, "spread": 1.0})
	trees.append({"at": Vector3(-1.0, 0.0, 14.5), "yaw": 0.0, "model": "low", "scale": 1.0})
	trees.append({"at": Vector3(-2.7, 0.0, 15.5), "yaw": 0.0, "model": "deep", "height": 2.0})
	var groves: Array = EdgeBand.fell_groves(g, {"trees": trees}, data)
	assert_eq(groves.size(), 1)
	if groves.size() != 1:
		return
	var grove: Dictionary = groves[0] as Dictionary
	assert_eq(int(grove["trees"]), 6)
	assert_eq(grove["plan_idx"] as Array, [0, 1, 2, 3, 4, 5])
	for cell: Vector2i in grove["stand"] as Array:
		assert_eq(cell.x, 0)
		assert_between(cell.y, 8, 15, "one eight-metre span")


func test_edge_groves_keep_the_inner_trees_and_their_plan_indices() -> void:
	var data: Dictionary = _small_data()
	var g: FieldGrid = data["grid"] as FieldGrid
	var solids: PackedByteArray = g.solid.duplicate()
	var floors: PackedByteArray = g.floor.duplicate()
	var p: Dictionary = EdgeBand.plan(g, 77, EdgeBand.look_of({"place_id": "sawmill_01"}))
	var plan_before: Dictionary = p.duplicate(true)
	var groves: Array = EdgeBand.fell_groves(g, p, data)
	assert_between(groves.size(), 1, 2, "the dense inner rows offer work")
	var used: Dictionary = {}
	var previous_distance: float = -1.0
	for grove: Dictionary in groves:
		assert_eq(String(grove["kind"]), "fell")
		assert_true(bool(grove["edge"]))
		assert_gte(int(grove["trees"]), 6)
		assert_eq(int(grove["level"]), 0)
		var indices: Array = grove["plan_idx"] as Array
		var cells: Array = grove["cells"] as Array
		var trees: Array = p["trees"] as Array
		assert_eq(indices.size(), int(grove["trees"]))
		assert_eq(cells.size(), indices.size())
		for i: int in range(indices.size()):
			var plan_idx: int = int(indices[i])
			assert_between(plan_idx, 0, trees.size() - 1)
			if plan_idx < 0 or plan_idx >= trees.size():
				continue
			assert_false(used.has(plan_idx), "one plan tree belongs to one grove")
			used[plan_idx] = true
			var tree: Dictionary = trees[plan_idx] as Dictionary
			assert_true(tree.has("height"), "low scale-only plants are not trees")
			var at: Vector3 = tree["at"] as Vector3
			assert_gt(EdgeBand.outside(g, at.x, at.z), 0.0)
			assert_lte(EdgeBand.outside(g, at.x, at.z), 2.6)
			assert_eq(cells[i] as Vector2i, FieldGrid.cell_of(at))
		var stand: Array = grove["stand"] as Array
		assert_false(stand.is_empty())
		assert_lte(stand.size(), 8)
		var nearest: float = INF
		for cell: Vector2i in stand:
			assert_true(g.people_can_walk(cell))
			assert_true(cell.x == 0 or cell.x == g.width - 1 or cell.y == 0 or cell.y == g.height - 1)
			var distance: float = WorkSpots.reach(data, cell)
			assert_gte(distance, 0.0)
			nearest = minf(nearest, distance)
		assert_gte(nearest, previous_distance, "nearest groves come first")
		previous_distance = nearest
	assert_eq(g.solid, solids)
	assert_eq(g.floor, floors)
	assert_eq(p, plan_before, "the rendered plan is untouched")
