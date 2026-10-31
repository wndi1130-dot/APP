extends "res://addons/gut/test.gd"
## The first stop's view ground, shared by loading, play and saved coordinates.

const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const StopGround = preload("res://game/world/stop_ground.gd")
const WorkSpots = preload("res://game/world/work_spots.gd")
const StopLoader = preload("res://game/stop_loader.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const FieldMission = preload("res://game/field_mission.gd")
const FieldWork = preload("res://game/field_work.gd")
const FirstStop = preload("res://game/world/sulehuf_map.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")
const MapView = preload("res://game/world/map_view.gd")
const OFFSET := Vector2i(21, 51)
const VIEW_KEYS := ["stop_view_rows", "stop_view_cols", "stop_view_rule"]
const GRID_ARRAYS := ["solid", "floor", "building", "zone", "opq", "walk_people", "walk_dead"]

static var _base_cache: Dictionary = {}
static var _wide_cache: Dictionary = {}
static var _loader_cache: Dictionary = {}


## Duplicate grids too: Dictionary.duplicate alone shares RefCounted grids.
static func _copy(data: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	var levels: Dictionary = {}
	for level in data["levels"]:
		var source: FieldGrid = data["levels"][level]
		var g := FieldGrid.new(source.width, source.height)
		for key: String in GRID_ARRAYS:
			g.set(key, source.get(key).duplicate())
		for key: String in ["doors", "windows", "floor_glass"]:
			g.set(key, source.get(key).duplicate(true))
		g.adopt_paths()
		g.revision = source.revision
		levels[level] = g
	out["levels"] = levels
	out["grid"] = levels[0]
	return out


static func _base() -> Dictionary:
	if _base_cache.is_empty():
		_base_cache = FieldMaps.build("first_leg_01_sulechow")
	return _copy(_base_cache)


static func _wide() -> Dictionary:
	if _wide_cache.is_empty():
		_wide_cache = StopGround.widen_view(_base())
	return _copy(_wide_cache)


static func _loader_map() -> Dictionary:
	if _loader_cache.is_empty():
		_loader_cache = StopLoader.make_ready(FirstStop, 7)
	return _copy(_loader_cache)


func _game(extra: Dictionary = {}):
	var game = FieldGame.new()
	var opts := {"seed": 7, "raiders": false, "auto_pause": false, "arrive": false,
		"arrival_horde": false, "map_data": _base()}
	opts.merge(extra, true)
	# As the game starts a stop (boot.gd, slice_flow.gd); a trial's own keys win.
	game.opts = StopGround.ask_view(opts)
	add_child_autofree(game)
	game.set_process(false)
	return game


func _assert_size(data: Dictionary, size: Vector2i) -> void:
	assert_eq((data["levels"] as Dictionary).size(), 4)
	for level in data["levels"]:
		var g: FieldGrid = data["levels"][level]
		assert_eq(Vector2i(g.width, g.height), size, "level %s" % level)


func _forest_has(data: Dictionary, cell: Vector2i) -> bool:
	for rect: Rect2i in data.get("deep_forest", []):
		if rect.has_point(cell):
			return true
	return false


func _has_label(data: Dictionary, text: String, cell: Vector2i) -> bool:
	for label: Dictionary in data["labels"]:
		if String(label["text"]) == text and label["cell"] == cell:
			return true
	return false


func _assert_mission_cell(game, original: Vector2i, level: int = 0) -> void:
	var offset := Vector2i(int(game.data["stop_view_cols"]), int(game.data["stop_view_rows"]))
	var g: FieldGrid = game.levels[level]
	var old: FieldGrid = _base_cache["levels"][level]
	var cell: Vector2i = original + offset
	assert_true(g.inside(cell))
	assert_eq(g.floor_at(cell), old.floor_at(original))
	assert_eq(g.solid_at(cell), old.solid_at(original))
	assert_eq(g.building_at(cell), old.building_at(original))
	assert_eq(g.people_can_walk(cell), old.people_can_walk(original))


## Only a start that asks gets the view ground; one without the keys keeps the map
## script's cells (the trials and tools that stand on them), and a loader's map keeps its own.
func test_a_field_widens_only_when_its_start_asks() -> void:
	var asked: FieldGame = _game()
	_assert_size(asked.data, Vector2i(191, 151))
	var plain: FieldGame = FieldGame.new()
	plain.opts = {"seed": 7, "raiders": false, "auto_pause": false, "arrive": false, "arrival_horde": false, "map_data": _base()}
	add_child_autofree(plain)
	plain.set_process(false)
	_assert_size(plain.data, Vector2i(170, 100))
	assert_eq(StopGround.view_offset(plain.data), Vector2i.ZERO)
	var handed: FieldGame = FieldGame.new()
	handed.opts = {"seed": 7, "raiders": false, "auto_pause": false, "arrive": false, "arrival_horde": false, "map_data": _loader_map()}
	add_child_autofree(handed)
	handed.set_process(false)
	_assert_size(handed.data, Vector2i(191, 151))
	var opts: Dictionary = StopGround.ask_view({"stop_view_rows": 0})
	assert_eq([opts["stop_view_rows"], opts["stop_view_cols"]], [0, StopGround.VIEW_ASK], "a key already there is kept")


func test_raw_size_and_need() -> void:
	var data: Dictionary = _base()
	_assert_size(data, Vector2i(170, 100))
	assert_eq(StopGround.view_need(data), OFFSET)
	assert_false(data.has("stop_view_rows"))


func test_shifted_arrival_cells() -> void:
	var data: Dictionary = _wide()
	_assert_size(data, Vector2i(191, 151))
	assert_eq(data["train"], Rect2i(37, 52, 80, 3))
	assert_eq(int(data["stop_view_rows"]), 51)
	assert_eq(int(data["stop_view_cols"]), 21)
	assert_eq(int(data["stop_view_rule"]), StopGround.VIEW_RULE)
	var cells: Array = []
	for doors: Array in data["train_doors"].values():
		cells.append_array(doors)
	cells.append_array(data["spawns"]["squad"])
	assert_eq(cells.size(), 7)
	for cell: Vector2i in cells:
		assert_gte(float(cell.x) + 0.5, StopGround.VIEW_REACH)
		assert_gte(float(cell.y) + 0.5, StopGround.VIEW_REACH)
	assert_eq(StopGround.view_need(data), Vector2i.ZERO)


func test_old_cells_unchanged() -> void:
	var original: Dictionary = _base()
	var data: Dictionary = _wide()
	for level in original["levels"]:
		var old: FieldGrid = original["levels"][level]
		var g: FieldGrid = data["levels"][level]
		for key: String in GRID_ARRAYS:
			var carried = old.get(key).slice(0, 0)
			for y: int in range(old.height):
				var begin: int = (y + OFFSET.y) * g.width + OFFSET.x
				carried.append_array(g.get(key).slice(begin, begin + old.width))
			assert_eq(carried, old.get(key), "level %s: %s" % [level, key])
	assert_eq(original["train"], Rect2i(16, 1, 80, 3))


func test_new_ground_partition() -> void:
	var data: Dictionary = _wide()
	var g: FieldGrid = data["grid"]
	var forest: Array = data["deep_forest"]
	assert_eq(forest, [Rect2i(0, 0, 191, 46), Rect2i(0, 61, 21, 90)])
	for i: int in range(forest.size()):
		for j: int in range(i + 1, forest.size()):
			assert_false((forest[i] as Rect2i).intersects(forest[j]))
	var bad_cover: int = 0
	var bad_forest: int = 0
	var bad_open: int = 0
	for y: int in range(g.height):
		for x: int in range(g.width):
			if x >= OFFSET.x and y >= OFFSET.y:
				continue
			var cell := Vector2i(x, y)
			var index: int = g.index(cell)
			var open: bool = y >= 46 and (y < 51 or (x < 21 and y < 61))
			var blocked: bool = _forest_has(data, cell)
			if blocked == open:
				bad_cover += 1
			if blocked and (g.solid_at(cell) != FieldGrid.Solid.BLOCK or g.floor_at(cell) != FieldGrid.Floor.SNOW
					or g.building_at(cell) != -1 or g.opq[index] != 1 or g.walk_people[index] != 0 or g.walk_dead[index] != 0
					or not g.people_path.is_point_solid(cell) or not g.dead_path.is_point_solid(cell)):
				bad_forest += 1
			if open and (g.walk_people[index] != int(g.people_can_walk(cell)) or g.walk_dead[index] != int(g.dead_can_walk(cell))
					or g.people_path.is_point_solid(cell) == g.people_can_walk(cell) or g.dead_path.is_point_solid(cell) == g.dead_can_walk(cell)):
				bad_open += 1
	assert_eq(bad_cover, 0, "only the new snow, main rail and road are outside forest")
	assert_eq(bad_forest, 0, "forest solids, opacity and both paths agree")
	assert_eq(bad_open, 0, "new trees and open cells have current paths")


func test_rail_and_road_connected() -> void:
	var data: Dictionary = _wide()
	var g: FieldGrid = data["grid"]
	for y: int in range(52, 55):
		for x: int in range(22):
			assert_eq(g.floor_at(Vector2i(x, y)), FieldGrid.Floor.RAIL)
			assert_true(g.people_can_walk(Vector2i(x, y)))
			assert_false(_forest_has(data, Vector2i(x, y)))
	for x: int in range(32, 36):
		for y: int in range(46, 52):
			assert_eq(g.floor_at(Vector2i(x, y)), FieldGrid.Floor.ROAD)
			assert_true(g.people_can_walk(Vector2i(x, y)))
			assert_false(_forest_has(data, Vector2i(x, y)))


func test_north_entry_reaches_doors() -> void:
	var data: Dictionary = _wide()
	var original: Dictionary = _base()
	var g: FieldGrid = data["grid"]
	var north: Array = data["entries"]["north_road"]
	assert_eq(north, [Vector2i(35, 46), Vector2i(34, 46), Vector2i(33, 46), Vector2i(32, 46)])
	var walk: PackedInt32Array = WorkSpots.walk_field(data)
	for cell: Vector2i in north:
		assert_true(g.people_can_walk(cell))
		assert_false(_forest_has(data, cell))
		assert_true(_forest_has(data, cell + Vector2i.UP), "forest immediately north")
		assert_gte(walk[g.index(cell)], 0, "the doors reach this entry")
	for id in original["entries"]:
		if id == "north_road":
			continue
		var expected: Array = []
		for cell: Vector2i in original["entries"][id]:
			expected.append(cell + OFFSET)
		assert_eq(data["entries"][id], expected, "only shifted: %s" % id)


func test_tree_edges_and_seed() -> void:
	var a: Dictionary = StopGround.widen_view(StopGround.apply(_base(), "city", 7))
	var b: Dictionary = StopGround.widen_view(StopGround.apply(_base(), "city", 90210))
	assert_eq(a["trees"], b["trees"], "independent of the run seed")
	assert_eq(a["props"], b["props"], "including facings")
	assert_eq(a["deep_forest"], b["deep_forest"])
	for level in a["levels"]:
		for key: String in GRID_ARRAYS:
			assert_eq(a["levels"][level].get(key), b["levels"][level].get(key), "level %s: %s" % [level, key])
	var seen: Dictionary = {}
	var top_edge: int = 0
	var left_edge: int = 0
	var g: FieldGrid = a["grid"]
	var tree_props: Dictionary = {}
	for prop: Dictionary in a["props"]:
		if String(prop["kind"]) not in ["spruce", "bare_tree"]:
			continue
		var cell: Vector2i = (prop["rect"] as Rect2i).position
		tree_props[cell] = prop
	for cell: Vector2i in a["trees"]:
		if cell.x >= 21 and cell.y >= 51:
			continue
		assert_false(seen.has(cell), "no double planting at forest corners")
		seen[cell] = true
		if _forest_has(a, cell):
			assert_false(tree_props.has(cell), "forest rows are always-visible tree cells, without props")
			assert_true((cell.y >= 40 and cell.y < 46) or (cell.x < 21 and cell.y >= 61 and (cell.x >= 15 or cell.y < 67)))
			top_edge += 1 if cell.y < 46 else 0
			left_edge += 1 if cell.y >= 61 and cell.x >= 15 else 0
		else:
			assert_true(tree_props.has(cell), "sparse snow trees retain their props")
			if tree_props.has(cell):
				assert_eq(tree_props[cell]["kind"], "bare_tree")
				assert_eq(int(tree_props[cell]["level"]), 0)
			assert_eq(g.floor_at(cell), FieldGrid.Floor.SNOW)
			assert_true(cell.y < 49 or cell.y > 57, "three clear cells beside the rail")
			for y: int in range(cell.y - 2, cell.y + 3):
				for x: int in range(cell.x - 2, cell.x + 3):
					assert_eq(g.floor_at(Vector2i(x, y)), FieldGrid.Floor.SNOW, "roads stay clear")
	assert_gt(top_edge, 0)
	assert_gt(left_edge, 0)
	assert_eq(seen.size(), (a["trees"] as Array).size() - (_base_cache["trees"] as Array).size())


func test_other_places_unchanged() -> void:
	var houses: Dictionary = FieldMaps.build("houses_01")
	assert_true(is_same(StopGround.widen_view(houses), houses))
	for key: String in VIEW_KEYS:
		assert_false(houses.has(key))
	var remote: Dictionary = StopGround.apply(FieldMaps.build_from(BareLine), "remote", 7, 600.0)
	var forest: Array = remote["deep_forest"].duplicate(true)
	var trees: Array = remote["trees"].duplicate(true)
	var props: Array = remote["props"].duplicate(true)
	assert_true(is_same(StopGround.widen_view(remote), remote))
	assert_eq(remote["deep_forest"], forest)
	assert_eq(remote["trees"], trees)
	assert_eq(remote["props"], props)
	for key: String in VIEW_KEYS:
		assert_false(remote.has(key))


func test_loader_matches_field() -> void:
	var loaded: Dictionary = _loader_map()
	var here: FieldGame = _game()
	var handed: FieldGame = _game({"map_data": _loader_map()})
	_assert_size(loaded, Vector2i(191, 151))
	for game: FieldGame in [here, handed]:
		_assert_size(game.data, Vector2i(191, 151))
		assert_eq(game.data["train"], loaded["train"])
		assert_eq(game.data["entries"], loaded["entries"])
		assert_eq(game.data["deep_forest"], loaded["deep_forest"])
		assert_eq(game.data["trees"], loaded["trees"])
		assert_eq(game.data["stop_view_rule"], loaded["stop_view_rule"])
	assert_true(loaded.has("_ground_key") and loaded.has("_building_plan"))


func test_zero_and_repeated_view() -> void:
	var raw: Dictionary = _base()
	raw["_ground_key"] = "kept"
	assert_true(is_same(StopGround.widen_view(raw, 0, 0), raw))
	_assert_size(raw, Vector2i(170, 100))
	assert_eq(raw["_ground_key"], "kept", "zero does not change the ground")
	assert_eq(raw["stop_view_rows"], 0)
	assert_eq(raw["stop_view_cols"], 0)
	assert_eq(raw["stop_view_rule"], StopGround.VIEW_RULE)
	var data: Dictionary = _wide()
	assert_true(is_same(StopGround.widen_view(data), data))
	assert_true(is_same(StopGround.widen_view(data, 51, 21), data))
	assert_true(is_same(StopGround.widen_view(data, 0, 0), data), "the caller rebuilds a different request")
	_assert_size(data, Vector2i(191, 151))
	assert_eq(data["stop_view_rows"], 51)
	assert_engine_error_count(0)


func test_view_reuse_and_rebuild() -> void:
	var data: Dictionary = StopGround.apply(_wide(), "city", 7)
	data["_ground_key"] = "kept"
	var calls: Array[int] = [0]
	var fresh: Callable = func() -> Dictionary:
		calls[0] += 1
		return _base()
	assert_true(is_same(FieldGame.shape_view(data, -1, -1, "city", 7, -1.0, fresh), data))
	assert_true(is_same(FieldGame.shape_view(data, 51, 21, "city", 7, -1.0, fresh), data))
	assert_eq(calls[0], 0)
	assert_eq(data["_ground_key"], "kept")
	var old: Dictionary = FieldGame.shape_view(data, 0, 0, "city", 7, -1.0, fresh)
	assert_eq(calls[0], 1)
	_assert_size(old, Vector2i(170, 100))
	assert_eq(old["stop_form"], "city", "the same form is reapplied after fresh")
	assert_eq(old["stop_view_rows"], 0)
	assert_eq(old["stop_view_cols"], 0)
	var shaped: Dictionary = FieldGame.shape_stop(data, "edge", 7, 180.0, fresh)
	assert_eq(calls[0], 2, "a new form starts before the handed view")
	assert_false(shaped.has("stop_view_rows"), "shape_stop's fresh branch has no view yet")
	var fitted: Dictionary = FieldGame.shape_view(shaped, -1, -1, "edge", 7, 180.0, fresh)
	assert_eq(calls[0], 2, "the already bare form does not need rebuilding")
	assert_eq(fitted["stop_view_rows"], 51)
	assert_eq(StopGround.view_need(fitted), Vector2i.ZERO)


func test_ahead_keys_invalidated() -> void:
	var expected: Array = FieldGame.AHEAD_KEYS.duplicate()
	expected.append("_edge_plan")
	expected.sort()
	var actual: Array = StopGround.VIEW_AHEAD_KEYS.duplicate()
	actual.sort()
	assert_eq(actual, expected)
	var raw: Dictionary = _base()
	for key: String in actual:
		raw[key] = Vector2i(170, 100)
	raw["spots"]["work_site"]["job"] = "fell"
	raw["spots"]["work_site"]["amount"] = 99
	var data: Dictionary = StopGround.widen_view(raw)
	for key: String in actual:
		assert_false(raw.has(key), "dropped before grow: %s" % key)
		assert_false(data.has(key), "not shifted: %s" % key)
	assert_false(data["spots"]["work_site"].has("job"))
	assert_false(data["spots"]["work_site"].has("amount"))


func test_wide_save_resumes_exactly() -> void:
	var first: FieldGame = _game({"stop_view_rows": 51, "stop_view_cols": 21, "stop_view_rule": StopGround.VIEW_RULE})
	first.clock.elapsed = 321.0
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(first)))
	assert_eq(saved["stop_view_rows"], 51)
	assert_eq(saved["stop_view_cols"], 21)
	assert_eq(saved["stop_view_rule"], StopGround.VIEW_RULE)
	for key: String in VIEW_KEYS:
		assert_false(saved["start_opts"].has(key))
	saved["runtime"]["game"]["glass_warned"] = true
	assert_true(FieldSave.exact(saved))
	var back: FieldGame = _game(FieldSave.resume_opts(saved))
	_assert_size(back.data, Vector2i(191, 151))
	assert_eq(back.clock.elapsed, 321.0)
	assert_true(back.glass_warned, "exact runtime restored")
	assert_eq(back.data["entries"], first.data["entries"])
	assert_engine_error_count(0)
	assert_push_warning_count(0)


func _old_save() -> Dictionary:
	var first: FieldGame = _game({"stop_view_rows": 0, "stop_view_cols": 0, "stop_view_rule": 0})
	first.clock.elapsed = 222.0
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(first)))
	for key: String in VIEW_KEYS:
		saved.erase(key)
	saved["runtime"]["game"]["glass_warned"] = true
	return saved


func test_old_save_resumes_exactly() -> void:
	var saved: Dictionary = _old_save()
	var opts: Dictionary = FieldSave.resume_opts(saved)
	assert_eq(opts["stop_view_rows"], 0, "old saves explicitly keep the original ground")
	assert_eq(opts["stop_view_cols"], 0)
	assert_true(FieldSave.exact(saved))
	var back: FieldGame = _game(opts)
	_assert_size(back.data, Vector2i(170, 100))
	assert_eq(back.data["train"], Rect2i(16, 1, 80, 3))
	assert_eq(back.clock.elapsed, 222.0)
	assert_true(back.glass_warned, "exact runtime restored")
	assert_engine_error_count(0)
	assert_push_warning_count(0)


func test_loader_map_rebuilds_for_old_save() -> void:
	var opts: Dictionary = FieldSave.resume_opts(_old_save())
	opts["map_data"] = _loader_map()
	var back: FieldGame = _game(opts)
	_assert_size(back.data, Vector2i(170, 100))
	assert_eq(back.data["train"], Rect2i(16, 1, 80, 3))
	assert_eq(back.clock.elapsed, 222.0)
	assert_true(back.glass_warned, "the handed larger grids did not force legacy restore")
	assert_engine_error_count(0)
	assert_push_warning_count(0)


func test_mission_cells_follow_view() -> void:
	for offset: Vector2i in [OFFSET, Vector2i.ZERO]:
		var view := {"stop_view_rows": offset.y, "stop_view_cols": offset.x}
		var depot_opts: Dictionary = view.duplicate()
		depot_opts["mission"] = "depot"
		var depot: FieldGame = _game(depot_opts)
		assert_eq(depot.data["spots"]["dp_conveyor"]["cell"], FieldMission.CONVEYOR_CELL + offset)
		assert_true(_has_label(depot.data, "적재 컨베이어", FieldMission.CONVEYOR_CELL + offset + Vector2i.DOWN))
		_assert_mission_cell(depot, FieldMission.CONVEYOR_CELL)
		var repair_at: Vector3 = FieldGrid.center(FieldMission.CONVEYOR_CELL + offset) + Vector3(0.9, 0, 0)
		depot.player.brain["side"] = 0
		assert_eq(depot.mission_play.repair_step(depot.player), repair_at)
		depot.mission_play.conveyor()["state"] = "running"
		assert_true(depot.mission_play.belt_noise(0.0))
		assert_eq(depot.sounds.back()["pos"], FieldGrid.center(FieldMission.CONVEYOR_CELL + offset))
		var survey_opts: Dictionary = view.duplicate()
		survey_opts["mission"] = "survey"
		var survey: FieldGame = _game(survey_opts)
		for row: Array in FieldMission.SURVEY_SPOTS:
			assert_eq(survey.data["spots"][row[0]]["cell"], row[2] + offset)
			assert_true(_has_label(survey.data, row[1], row[2] + offset + Vector2i.DOWN))
			_assert_mission_cell(survey, row[2])
		for row: Array in FieldMission.SURVEY_LOGS:
			assert_eq(survey.data["containers"][row[0]]["cell"], row[2] + offset)
			assert_eq(survey.data["containers"][row[0]]["building"], row[3])
			_assert_mission_cell(survey, row[2], int(row[4]))


## The water tower is drawn where its cells went (map_view.gd, stop_cinema.gd), not in the
## forest that now fills the map's old north-west corner.
func test_water_tower_follows_view() -> void:
	var base := _base()
	var wide := _wide()
	var before: Array[Vector2i] = MapView.water_tower_cells(base["grid"], base)
	var after: Array[Vector2i] = MapView.water_tower_cells(wide["grid"], wide)
	assert_gt(before.size(), 0)
	var moved: Array[Vector2i] = []
	for c: Vector2i in before:
		moved.append(c + OFFSET)
	assert_eq(after, moved)
	for c: Vector2i in after:
		assert_false(_forest_has(wide, c), "tower cell %s in the forest" % c)


## Coal goes down on the moved platform row, not in the forest over the old one (field_work.gd).
func test_coal_drop_follows_view() -> void:
	for offset: Vector2i in [OFFSET, Vector2i.ZERO]:
		var game: FieldGame = _game({"stop_view_rows": offset.y, "stop_view_cols": offset.x})
		var original := Vector2i(39, FieldWork.COAL_DROP_ROW)
		assert_eq(game.work.coal_drop(float(original.x + offset.x) + 0.5), FieldGrid.center(original + offset))
		_assert_mission_cell(game, original)
		assert_true((game.levels[0] as FieldGrid).people_can_walk(original + offset))
		assert_eq(game.work.coal_drop(-50.0), FieldGrid.center(Vector2i(FieldWork.COAL_DROP_MIN_X, FieldWork.COAL_DROP_ROW) + offset))
