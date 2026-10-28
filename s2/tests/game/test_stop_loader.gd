extends "res://addons/gut/test.gd"
## Getting a stop's field ready under the stop scene (stop_loader.gd, 결정
## 421-3): the map built off the main thread and the field built over frames
## make the same stop as the field built at once (the same map, seed and
## order: nothing in the stop depends on how it was built), it stands still
## till it is shown, and one not wanted after all goes without trouble.

const StopLoader = preload("res://game/stop_loader.gd")
const FieldGame = preload("res://game/field_game.gd")

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
