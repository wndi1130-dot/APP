extends "res://addons/gut/test.gd"
## 2a: the stop loader's worker makes the ground's and the floors' arrays ahead (and the
## side path first, with the field's seed); the field lays them as they are, or works
## them out again here when the map changed since.

const Maps = preload("res://game/world/field_maps.gd")
const MapView = preload("res://game/world/map_view.gd")
const StopLoader = preload("res://game/stop_loader.gd")
const SidePath = preload("res://game/world/side_path.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const PLACE := "mine_01"


func _ready_map(run_seed: int) -> Dictionary:
	return StopLoader.make_ready(load(Maps.path_of(PLACE)), run_seed)


func test_the_workers_ground_arrays_are_the_ones_laid_row_by_row() -> void:
	var g: FieldGrid = Maps.build(PLACE)["grid"]
	var details := MapView.ground_details(g)
	var ahead := MapView.ground_arrays(g, details)
	# The main thread's way (_build_ground on a map without them): banks, then rows.
	var banks := PackedVector2Array()
	for y in range(g.height + 1):
		MapView.ground_bank_row(g, y, banks)
	var tools := {}
	for y in range(g.height):
		MapView.ground_row(g, details, banks, y, tools)
	assert_eq(ahead.keys(), tools.keys(), "the same tiles in the same order")
	assert_eq(ahead.size(), ceili(g.width / float(MapView.TILE)) * ceili(g.height / float(MapView.TILE)))
	var corners := 0
	for tile in ahead:
		assert_eq(ahead[tile], (tools[tile] as SurfaceTool).commit_to_arrays())
		corners += (ahead[tile][Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	assert_eq(corners, g.width * g.height * 6, "six corners a cell, none left out")
	assert_eq(ahead[Vector2i.ZERO][Mesh.ARRAY_TEX_UV2].size(), ahead[Vector2i.ZERO][Mesh.ARRAY_VERTEX].size(), "the floor kind rides in UV2")


func test_a_view_lays_the_loaders_arrays_and_works_out_a_changed_map_again() -> void:
	var d := _ready_map(-1)
	var floors: Array = (d["_floor_arrays"] as Dictionary).keys()
	var v = MapView.new()
	add_child_autofree(v)
	await v.setup(d)
	assert_true(v.ground_from_loader)
	for lv in floors:
		assert_true(bool(v.floor_from_loader.get(lv, false)), "level %d's floors" % lv)
	for key: String in ["_ground_arrays", "_ground_key", "_floor_arrays", "_floor_keys"]:
		assert_false(d.has(key), "%s is read once, not kept with the map" % key)
	var laid: int = v.level_roots[0].get_child_count()
	# One cell changed after the arrays were made: the ground is worked out again here.
	var changed := _ready_map(-1)
	var g: FieldGrid = changed["grid"]
	var c := Vector2i(2, 2)
	g.floor[g.index(c)] = FieldGrid.Floor.GRAVEL if g.floor_at(c) != FieldGrid.Floor.GRAVEL else FieldGrid.Floor.SNOW
	var again = MapView.new()
	add_child_autofree(again)
	await again.setup(changed)
	assert_false(again.ground_from_loader)
	assert_eq(again.level_roots[0].get_child_count(), laid, "the same pieces either way")


func test_the_loader_puts_the_side_path_on_first_and_the_field_keeps_its_arrays() -> void:
	var s := -1
	var d := {}
	for k in range(1, 200):
		if not SidePath.rolls(PLACE, k):
			continue
		d = _ready_map(k)
		if d.has("side_path"):
			s = k
			break
	assert_gt(s, 0)
	assert_eq(int(d["_side_seed"]), s)
	assert_eq(d["_ground_key"], MapView.ground_key(d["grid"]), "the arrays fit the map the side path grew")
	var kept := FieldGame.with_side_path(d, s)
	assert_true(kept.has("_ground_arrays"), "the field neither puts it on again nor drops the arrays")
	var own := FieldGame.with_side_path(Maps.build(PLACE), s)
	assert_eq(kept["side_path"], own["side_path"], "the same way as the field would put on")
	assert_eq(kept["grid"].width, own["grid"].width)


func test_a_map_made_for_another_seed_is_made_again() -> void:
	var loader = StopLoader.new()
	loader.threaded = false
	add_child_autofree(loader)
	loader.prepare(PLACE, 3)
	assert_true(loader.has_data())
	assert_eq(int(loader.data["_side_seed"]), 3)
	loader.prepare(PLACE, 3)
	assert_eq(int(loader.data["_side_seed"]), 3, "the same place and seed keeps what is under way")
	loader.prepare(PLACE, 4)
	assert_eq(loader.seed_for, 4)
	assert_eq(int(loader.data["_side_seed"]), 4)
