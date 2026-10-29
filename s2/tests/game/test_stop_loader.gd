extends "res://addons/gut/test.gd"
## Getting a stop's field ready under the stop scene (stop_loader.gd, 결정
## 421-3): the map built off the main thread and the field built over frames
## make the same stop as the field built at once (the same map, seed and
## order: nothing in the stop depends on how it was built), it stands still
## till it is shown, and one not wanted after all goes without trouble.

const StopLoader = preload("res://game/stop_loader.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const MapView = preload("res://game/world/map_view.gd")
const EdgeBand = preload("res://game/world/edge_band.gd")
const StopGround = preload("res://game/world/stop_ground.gd")
const SidePath = preload("res://game/world/side_path.gd")

const OPTS := {"seed": 7, "arrive": false}


func _snapshot(f) -> Dictionary:
	var dead: Array = []
	for z: Dictionary in f.zombies.list:
		dead.append([String(z["kind"]), z["pos"]])
	var crew: Array = []
	for p in f.people:
		crew.append([String(p.pid), p.position])
	return {
		"place": f.data["place_id"], "size": Vector2i(f.grid.width, f.grid.height), "rng": f.rng.state,
		"dead": dead, "crew": crew, "containers": (f.data["containers"] as Dictionary).keys(),
		"spots": (f.data["spots"] as Dictionary).keys(), "radio": f.radio, "view": f.view.get_child_count(),
		"buildings": f.view.buildings.get_child_count() if f.view.buildings else -1,
		"budget": f.director.budget_left, "player": f.player.position,
	}


func _loader() -> Node:
	var loader = StopLoader.new()
	add_child_autofree(loader)
	loader.prepare("")
	if not loader.has_data():
		await wait_for_signal(loader.data_ready, 30)
	return loader


func test_a_stop_built_over_frames_is_the_stop_built_at_once_and_stands_till_shown() -> void:
	var whole = FieldGame.new()
	whole.opts = OPTS.duplicate()
	add_child_autofree(whole)
	assert_true(whole.is_built, "built in the one call, as before")
	assert_eq(whole.pace.waits, 0)
	# As it stands when built: it is live and would play on while the other is built.
	var at_once: Dictionary = _snapshot(whole)
	whole.process_mode = Node.PROCESS_MODE_DISABLED
	var loader = await _loader()
	assert_true(loader.has_data(), "the map came back from the worker")
	assert_true(loader.data.has("_building_plan"), "its buildings planned off the main thread too")
	assert_true(loader.data.has("_edge_plan"), "and the woods round it")
	loader.resting = true
	var holder := Node3D.new()
	add_child_autofree(holder)
	loader.build_field(holder, OPTS.duplicate())
	var staged = loader.field
	assert_not_null(staged)
	assert_false(staged.is_built, "still being built after its first frame's share")
	assert_false(staged.visible, "out of sight while it is built")
	await wait_for_signal(loader.field_built, 60)
	assert_true(staged.is_built)
	assert_gt(staged.pace.waits, 0, "spread over frames")
	assert_eq_deep(_snapshot(staged), at_once)
	# Built, it stands still till the slice shows it.
	assert_true(staged.standing_by)
	var t0: float = staged.clock.elapsed
	await wait_process_frames(6)
	assert_eq(staged.clock.elapsed, t0, "no field time passes before it is shown")
	staged.go_live()
	await wait_process_frames(6)
	assert_gt(staged.clock.elapsed, t0, "shown, its clock runs")
	# Shown from under the stop scene: as bright as its last look, the sight
	# mask coming in over MASK_IN_S, not a dark cut. What is in sight is the same.
	assert_lt(float(staged.view.material.get_shader_parameter("mask_on")), 0.5, "the mask not in yet")
	assert_true(staged.mask_on, "the sight rules as ever")
	await wait_seconds(FieldGame.MASK_IN_S + 0.3)
	assert_eq(staged.mask_in, 1.0)
	assert_almost_eq(float(staged.view.material.get_shader_parameter("mask_on")), 1.0, 0.001, "the mask in full")
	assert_almost_eq(float(whole.view.material.get_shader_parameter("mask_on")), 1.0, 0.001, "a field built at once has it from the start")


func test_a_field_not_wanted_after_all_finishes_quietly_and_goes() -> void:
	var loader = await _loader()
	var holder := Node3D.new()
	add_child_autofree(holder)
	loader.build_field(holder, OPTS.duplicate())
	var f = loader.field
	assert_false(f.is_built)
	loader.abandon()
	assert_null(loader.field)
	await wait_process_frames(4)
	assert_false(is_instance_valid(f), "gone once its build ran out")


func test_without_a_thread_the_map_is_there_at_once() -> void:
	var loader = StopLoader.new()
	loader.threaded = false
	add_child_autofree(loader)
	loader.prepare("")
	assert_true(loader.has_data())
	assert_eq(loader.place, "first_leg_01_sulechow", "the default stop")
	assert_false(loader.data.has("_building_plan"), "planned on the main thread with the field, as before")


## A stop's form known ahead goes on the bare map on the worker, before the side path
## (as FieldGame.shape_stop puts it on in the field): what is made ahead is made from the
## edge's map, and the field keeps that map as it is, with nothing done on the main thread.
func test_an_edge_stop_is_made_on_the_worker_before_the_side_path() -> void:
	var script: Script = load(FieldMaps.path_of("houses_01"))
	var bare: Dictionary = FieldMaps.build_from(script)
	# A seed whose side path goes on, so the order is seen: the edge first, the side path after.
	var run_seed: int = -1
	var d: Dictionary = {}
	for s: int in range(1, 200):
		if not SidePath.rolls("houses_01", s):
			continue
		d = StopLoader.make_ready(script, s, "edge")
		if d.has("side_path"):
			run_seed = s
			break
	assert_gt(run_seed, 0, "a seed with a side path")
	assert_true(d.has("side_path"))
	var g: FieldGrid = d["grid"]
	assert_eq(d["stop_form"], "edge")
	assert_gt(g.width, (bare["grid"] as FieldGrid).width, "the ground grew out along the track")
	assert_eq(d["_ground_key"], MapView.ground_key(g), "the ground's arrays fit the edge's map")
	assert_eq(d["_edge_plan"]["key"], EdgeBand.plan_key(g, EdgeBand.seed_of(d), EdgeBand.look_of(d)), "so does the woods' plan")
	assert_gt(float(d["walk_to_village_m"]), 0.0, "the village is reached on foot")
	var train: Rect2i = d["train"]
	for y: int in range(train.position.y, train.end.y):
		var rail: int = 0
		for x: int in range(train.end.x, train.end.x + StopGround.END_GAP):
			rail += 1 if g.floor_at(Vector2i(x, y)) == FieldGrid.Floor.RAIL else 0
		for x: int in range(train.position.x - StopGround.END_GAP, train.position.x):
			rail += 1 if g.floor_at(Vector2i(x, y)) == FieldGrid.Floor.RAIL else 0
		assert_eq(rail, 2 * StopGround.END_GAP, "row %d: track on both ends of the train" % y)
	# The field keeps it: no form put on again, nothing made ahead dropped, no side path again.
	var kept: Dictionary = FieldGame.with_side_path(FieldGame.shape_stop(d, "edge", run_seed, -1.0, func() -> Dictionary: return {}), run_seed)
	assert_true(is_same(kept, d), "the field keeps the loader's map")
	assert_true(kept.has("_ground_key") and kept.has("_building_plan"), "and what was made ahead from it")
	# The same stop put together in the field, edge then side path, is the same ground.
	var here: Dictionary = FieldGame.with_side_path(FieldGame.shape_stop(FieldMaps.build_from(script), "edge", run_seed, -1.0, func() -> Dictionary: return {}), run_seed)
	assert_eq((here["grid"] as FieldGrid).width, g.width)
	assert_eq((here["grid"] as FieldGrid).height, g.height)
	assert_eq(here["train"], d["train"])
	assert_eq(here["side_path"]["side"], d["side_path"]["side"])
	# Without a form it is the map as it was made before.
	var city: Dictionary = StopLoader.make_ready(script, run_seed)
	assert_false(city.has("stop_form"))
	assert_lt((city["grid"] as FieldGrid).width, g.width)
