extends "res://addons/gut/test.gd"
## Authored before the fix. Engine/GUT execution belongs to the caller.
## This file exercises the real field loop, work tickets, sounds and save codec.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const BuildingRules = preload("res://game/sim/building_rules.gd")
const DoorRules = preload("res://game/sim/door_rules.gd")
const PersonVisual = preload("res://game/actors/person_visual.gd")
const Wear = preload("res://game/sim/wear.gd")
const Gait = preload("res://game/sim/gait.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const DoorWalk = preload("res://game/sim/door_walk.gd")
const Corridor = preload("res://tests/game/fixtures/door_walk_map.gd")
const DOOR := Corridor.FIRST
const END := Vector3(34.5, 0.0, 8.5)

var game
var p


func _game():
	var field = FieldGame.new()
	field.opts = {"seed": 4, "raiders": false, "auto_pause": false, "weather": ["clear"], "arrive": false}
	field.map_script = Corridor
	add_child_autofree(field)
	field.set_process(false)
	field.zombies.list.clear()
	field.pending_spawn.clear()
	field.arrive_t = -1.0
	return field


func before_each() -> void:
	game = _game()
	p = game.player
	game.audio.played.clear()
	_place(p, 1.0)


func _place(person, distance: float, run: bool = false) -> void:
	person.cancel_action()
	person.position = Vector3(float(DOOR.x) - distance, 0.0, 8.5)
	person.stick = Vector2.ZERO
	person.drive_speed = 0.0
	person.turn_rate = 0.0
	# Dry, light clothing keeps this timing fixture independent of sweat/cold.
	person.worn = Wear.outfit({"shirt": "shirt_cotton", "trousers": "trousers_cotton", "shoes": "shoes_leather"})
	person.items.clear()
	person.heat.heat = 100.0
	person.heat.wet = 0.0
	person.go_to(PackedVector3Array([FieldGrid.center(DOOR),
		FieldGrid.center(Corridor.SECOND), END]), run)


func _begin() -> void:
	game.actions.open_door_on_way(p, DOOR)
	assert_ne(p.action, "", "the door work started")
	assert_almost_eq(float(p.mults()["hands"]), 1.0, 0.00001,
		"the exact half-second fixture has healthy, bare hands")


func _assert_outside_if_closed(person, cell: Vector2i = DOOR) -> void:
	if game.grid.doors[cell]["state"] == "closed":
		assert_lt(person.position.x, float(cell.x), "no tick enters the closed door cell")


func test_walk_advances_each_tick_of_the_half_second_without_losing_the_path() -> void:
	var path: PackedVector3Array = p.path.duplicate()
	_begin()
	assert_eq(p.path, path, "red before fix: start_action erased the route")
	for _tick: int in 4:
		var before: float = p.position.x
		game._update_person(p, 0.125)
		assert_gt(p.position.x, before, "red before fix: every work tick returned before movement")
		_assert_outside_if_closed(p)
	assert_eq(game.grid.doors[DOOR]["state"], "open")
	assert_false(p.path.is_empty())


func test_state_sound_and_work_ticket_change_only_at_exact_completion() -> void:
	_begin()
	var revision: int = game.grid.revision
	var sounds: int = game.audio.played.count("door_open")
	game._update_person(p, 0.25)
	game._update_person(p, 0.125)
	assert_eq(game.grid.doors[DOOR]["state"], "closed")
	assert_eq(game.grid.revision, revision)
	assert_eq(game.audio.played.count("door_open"), sounds)
	assert_true(game.actions.ongoing.has(p.get_instance_id()))
	game._update_person(p, 0.125)
	assert_eq(game.grid.doors[DOOR]["state"], "open")
	assert_eq(game.grid.revision, revision + 1)
	assert_eq(game.audio.played.count("door_open"), sounds + 1, "one door turn, at completion")
	assert_false(game.actions.ongoing.has(p.get_instance_id()))
	assert_false(bool(game.grid.doors[DOOR]["busy"]))
	game._update_person(p, 0.125)
	assert_eq(game.grid.revision, revision + 1, "no replay")


func test_late_start_waits_at_threshold_for_only_the_remaining_time() -> void:
	_place(p, 0.04)
	_begin()
	game._update_person(p, 0.125)
	_assert_outside_if_closed(p)
	assert_gt(p.position.x, 29.96, "approaches the threshold instead of stopping at work start")
	var threshold: Vector3 = p.position
	game._update_person(p, 0.125)
	assert_eq(p.position, threshold)
	assert_almost_eq(p.action_t, 0.25, 0.00001)
	game._update_person(p, 0.25)
	assert_eq(game.grid.doors[DOOR]["state"], "open")
	game._update_person(p, 0.125)
	assert_gt(p.position.x, 30.0, "no second half-second wait")


func test_completion_inside_a_long_tick_uses_the_remaining_movement_time() -> void:
	_place(p, 0.04)
	_begin()
	game._update_person(p, 0.75)
	assert_eq(game.grid.doors[DOOR]["state"], "open")
	assert_gt(p.position.x, 30.0, "the last quarter-second still moves")


func test_running_path_anticipates_the_door_and_keeps_running() -> void:
	_place(p, 4.0, true)
	var started := false
	var closed_crossings := 0
	for _tick: int in 40:
		game._update_person(p, 0.05)
		if p.action != "" and not started:
			started = true
			assert_lt(p.position.x, 29.0, "red before fix: start before reaching the doorway")
			assert_false(p.path.is_empty())
		if game.grid.doors[DOOR]["state"] == "closed" and p.position.x >= 30.0:
			closed_crossings += 1
		assert_true(p.running, "the run request survives door work")
	assert_true(started)
	assert_eq(closed_crossings, 0)
	assert_gt(p.position.x, 31.0)


func test_stick_walk_anticipates_without_losing_drive_or_showing_a_work_tag() -> void:
	_place(p, 3.0, true)
	p.stop()
	p.stick = Vector2.RIGHT
	var started := false
	for _tick: int in 35:
		game._update_person(p, 0.05)
		if p.action != "" and not started:
			started = true
			assert_lt(p.position.x, 29.0)
			assert_gt(p.drive_speed, 0.0)
			p.refresh_view(true)
			assert_eq(p.tag.text, "", "no standing-work countdown while walking")
			assert_false(PersonVisual.OWN_WORK.has(p.action), "no standing work clip")
		_assert_outside_if_closed(p)
	assert_true(started)
	assert_gt(p.position.x, 30.0)
	assert_true(p.running)


func test_companion_and_raider_use_the_same_moving_door_work() -> void:
	var mate = game.squad[1]
	for role: String in ["companion", "raider"]:
		game.grid.set_door_state(DOOR, "closed")
		mate.role = role
		mate.team = "raider" if role == "raider" else "squad"
		_place(mate, 1.0, true)
		game.actions.open_door_on_way(mate, DOOR)
		var before: float = mate.position.x
		game._update_person(mate, 0.125)
		assert_gt(mate.position.x, before, role)
		assert_false(mate.path.is_empty())
		assert_true(mate.running)
		game._update_person(mate, 0.375)
		assert_eq(game.grid.doors[DOOR]["state"], "open", role)


func test_locked_boarded_and_rejected_doors_keep_the_existing_rules() -> void:
	game.grid.set_door_state(DOOR, "locked")
	game.actions.open_door_on_way(p, DOOR)
	assert_eq(p.action, "")
	assert_true(p.path.is_empty())
	assert_eq(game.grid.doors[DOOR]["state"], "locked")
	game.grid.set_door_state(DOOR, "closed")
	BuildingRules.add_plank(game.grid.doors[DOOR], 0)
	_place(p, 1.0)
	game.actions.open_door_on_way(p, DOOR)
	assert_eq(p.action, "")
	assert_true(p.path.is_empty())
	game.grid.doors[DOOR]["planks"] = [0, 0]
	for state: String in ["open", "broken"]:
		game.grid.set_door_state(DOOR, state)
		_place(p, 1.0)
		game.actions.open_door_on_way(p, DOOR)
		assert_eq(p.action, "")
		assert_false(p.path.is_empty())
		assert_false(DoorRules.can_toggle(game.grid.doors[DOOR], "open"))


func test_occupants_still_allow_opening_and_prevent_closing() -> void:
	game.zombies.spawn("dead", FieldGrid.center(DOOR))
	_begin()
	game._update_person(p, 0.5)
	assert_eq(game.grid.doors[DOOR]["state"], "open", "opening had no occupant veto")
	p.position = Vector3(28.0, 0.0, 8.5)
	game.actions._set_door(DOOR, "closed")
	assert_eq(game.grid.doors[DOOR]["state"], "open", "a zombie in OCCUPANT_RADIUS blocks closing")
	game.zombies.list.clear()
	game.squad[1].position = FieldGrid.center(DOOR)
	game.actions._set_door(DOOR, "closed")
	assert_eq(game.grid.doors[DOOR]["state"], "open", "a living person also blocks closing")


func test_save_restore_keeps_remaining_time_route_run_and_reservation_identity() -> void:
	_place(p, 1.0, true)
	_begin()
	game._update_person(p, 0.125)
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))
	assert_false(saved.is_empty())
	assert_eq(int(saved["version"]), 3, "no format bump")
	var restored = _game()
	FieldSave.apply(restored, saved)
	var q = restored.player
	assert_eq(q.position, p.position)
	assert_eq(q.path, p.path)
	assert_false(q.path.is_empty(), "red before fix: the route lived only in a callback")
	assert_true(q.running)
	assert_almost_eq(q.action_t, 0.375, 0.00001)
	assert_true(is_same(q.action_busy, restored.grid.doors[DOOR]))
	assert_true(restored.actions.ongoing.has(q.get_instance_id()))
	var before: float = q.position.x
	restored._update_person(q, 0.125)
	assert_gt(q.position.x, before)
	assert_eq(restored.grid.doors[DOOR]["state"], "closed")
	restored._update_person(q, 0.25)
	assert_eq(restored.grid.doors[DOOR]["state"], "open")
	assert_false(bool(restored.grid.doors[DOOR]["busy"]))
	assert_false(restored.actions.ongoing.has(q.get_instance_id()))


func test_two_adjacent_doors_never_skip_a_closed_cell_or_restart_a_timer() -> void:
	game.grid.set_door_state(Corridor.SECOND, "closed")
	_place(p, 4.0, true)
	var starts: Dictionary = {DOOR: 0, Corridor.SECOND: 0}
	var was_busy: Dictionary = {DOOR: false, Corridor.SECOND: false}
	for _tick: int in 64:
		game._update_person(p, 0.05)
		for cell: Vector2i in [DOOR, Corridor.SECOND]:
			var busy: bool = bool(game.grid.doors[cell].get("busy", false))
			if busy and not bool(was_busy[cell]):
				starts[cell] += 1
			was_busy[cell] = busy
			_assert_outside_if_closed(p, cell)
	assert_eq(starts[DOOR], 1)
	assert_eq(starts[Corridor.SECOND], 1)
	assert_gt(p.position.x, 32.0)
	assert_true(p.running)


func test_zero_delta_render_and_pause_do_not_advance_the_door_or_route() -> void:
	_begin()
	var position: Vector3 = p.position
	var path: PackedVector3Array = p.path.duplicate()
	var left: float = p.action_t
	game._update_person(p, 0.0)
	p.refresh_view(true)
	game._process(0.0)
	game.paused = true
	game._process(0.125)
	assert_eq(p.position, position)
	assert_eq(p.path, path)
	assert_eq(p.action_t, left)
	assert_eq(game.grid.doors[DOOR]["state"], "closed")


func test_rerouting_cancels_without_replaying_the_previous_path() -> void:
	_begin()
	game._update_person(p, 0.125)
	var replacement := PackedVector3Array([Vector3(25.0, 0.0, 8.5)])
	p.go_to(replacement, false)
	game._update_person(p, 0.5)
	assert_eq(game.grid.doors[DOOR]["state"], "closed")
	assert_eq(p.path, replacement)
	assert_false(bool(game.grid.doors[DOOR]["busy"]))
	assert_false(game.actions.ongoing.has(p.get_instance_id()))


func test_a_second_person_waits_for_the_same_reservation_without_clearing_the_route() -> void:
	_begin()
	var mate = game.squad[1]
	_place(mate, 0.04)
	game._update_person(mate, 0.125)
	assert_eq(mate.action, "", "the existing owner keeps the work ticket")
	assert_false(mate.path.is_empty())
	_assert_outside_if_closed(mate)
	game._update_person(p, 0.5)
	game._update_person(mate, 0.125)
	assert_gt(mate.position.x, 30.0)


func test_reboarding_or_breaking_the_door_mid_work_cannot_commit_an_open() -> void:
	_begin()
	game._update_person(p, 0.125)
	BuildingRules.add_plank(game.grid.doors[DOOR], 1)
	game._update_person(p, 0.375)
	assert_eq(game.grid.doors[DOOR]["state"], "closed")
	assert_false(bool(game.grid.doors[DOOR]["busy"]))
	game.grid.doors[DOOR]["planks"] = [0, 0]
	_place(p, 1.0)
	_begin()
	game.grid.set_door_state(DOOR, "broken")
	game._update_person(p, 0.5)
	assert_eq(game.grid.doors[DOOR]["state"], "broken")
	assert_false(bool(game.grid.doors[DOOR]["busy"]))


func test_manual_toggle_keeps_its_stationary_work_and_half_second() -> void:
	game.actions.door_default(p, DOOR, "open")
	assert_eq(p.action, "door")
	assert_true(p.path.is_empty())
	var before: Vector3 = p.position
	game._update_person(p, 0.25)
	assert_eq(p.position, before)
	assert_eq(game.grid.doors[DOOR]["state"], "closed")
	game._update_person(p, 0.25)
	assert_eq(p.position, before)
	assert_eq(game.grid.doors[DOOR]["state"], "open")


func test_legacy_saved_door_callback_with_four_bound_arguments_still_resumes() -> void:
	var route: PackedVector3Array = p.path.duplicate()
	game.actions._begin_work(p, "door", "문", 0.5,
		game.actions._door_on_way_done.bind(p, DOOR, route, true), "door", DOOR, FieldGrid.center(DOOR))
	game._update_person(p, 0.125)
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))
	var restored = _game()
	FieldSave.apply(restored, saved)
	var q = restored.player
	assert_true(q.path.is_empty(), "the legacy stopped action resumes as saved")
	restored._update_person(q, 0.375)
	assert_eq(restored.grid.doors[DOOR]["state"], "open")
	assert_eq(q.path, route)
	assert_true(q.running)


func test_the_existing_hand_multiplier_is_applied_once_without_changing_rule_time() -> void:
	p.gloves = true
	game.actions.open_door_on_way(p, DOOR)
	assert_eq(p.action_total, DoorRules.TOGGLE_SECONDS)
	assert_almost_eq(float(p.mults()["hands"]), 0.9, 0.00001)
	game._update_person(p, 0.5)
	assert_eq(game.grid.doors[DOOR]["state"], "closed")
	assert_almost_eq(p.action_t, 0.05, 0.00001)
	game._update_person(p, 0.0625)
	assert_eq(game.grid.doors[DOOR]["state"], "open")


func test_an_injury_cancels_the_ticket_and_releases_the_door_before_completion() -> void:
	_begin()
	game._update_person(p, 0.125)
	p.body.apply_cut(true, 0.0, "arm_left")
	game.actions.validate_work(p)
	assert_eq(p.action, "")
	assert_false(game.actions.ongoing.has(p.get_instance_id()))
	assert_false(bool(game.grid.doors[DOOR]["busy"]))
	assert_eq(game.grid.doors[DOOR]["state"], "closed")


func test_thirty_and_sixty_hz_open_on_the_half_second_tick_without_an_extra_frame() -> void:
	for hz: int in [30, 60]:
		game.grid.set_door_state(DOOR, "closed")
		_place(p, 0.04)
		_begin()
		var frames: int = int(float(hz) * 0.5)
		for tick: int in frames:
			game._update_person(p, 1.0 / float(hz))
			assert_eq(game.grid.doors[DOOR]["state"], "open" if tick == frames - 1 else "closed")
			_assert_outside_if_closed(p)


## Review regressions, authored against a7f6e255 before changing production code.
## Advance the same motion identity and idle-gait tail as the real field loop.
func _tick_person(person, delta: float) -> void:
	game._begin_motion_tick()
	game.clock.advance(delta)
	game._motion_clock = game.clock.elapsed
	game._update_person(person, delta)
	game._update_ground_gait(person, delta)


func test_wall_slide_sweeps_the_actual_x_segment_for_stick_and_path() -> void:
	game.grid.set_solid(Vector2i(31, 10), FieldGrid.Solid.WALL)
	for stick_input: bool in [false, true]:
		_place(p, 0.2, true)
		p.position.z = 8.9
		p.go_to(PackedVector3Array([p.position + Vector3(5, 0, 5)]), true)
		if stick_input:
			p.stick = Vector2.ONE.normalized()
			p.drive_dir = Vector3(1, 0, 1).normalized()
			p.drive_speed = 3.9
		assert_almost_eq(p.speed(FieldGrid.Floor.SNOW), 3.9, 0.00001)
		_tick_person(p, 0.5)
		assert_lt(p.position.x, 30.0, "a7f6e255: the x slide tunnels to x=31.179")
		assert_eq(game.grid.doors[DOOR]["state"], "closed")


func test_wall_slide_also_sweeps_the_second_axis() -> void:
	var cell := Vector2i(28, 10)
	game.grid.doors[cell] = game.grid.doors[DOOR].duplicate(true)
	game.grid.set_solid(cell, FieldGrid.Solid.DOOR)
	game.grid.set_solid(Vector2i(30, 11), FieldGrid.Solid.WALL)
	game.grid.set_solid(Vector2i(30, 9), FieldGrid.Solid.WALL)
	_place(p, 1.1, true)
	p.position = Vector3(28.9, 0, 9.8)
	p.go_to(PackedVector3Array([p.position + Vector3(5, 0, 5)]), true)
	_tick_person(p, 0.5)
	assert_lt(p.position.z, 10.0, "a7f6e255: the z slide skips the closed cell")
	assert_eq(game.grid.doors[cell]["state"], "closed")


func test_reversing_the_real_stick_path_cancels_work_and_reservation() -> void:
	_place(p, 0.04)
	p.stick = Vector2.RIGHT
	_tick_person(p, 0.125)
	assert_eq(p.action, "door_walk")
	var before: Vector3 = p.position
	p.stick = Vector2.LEFT
	_tick_person(p, 0.125)
	assert_lt(p.position.x, before.x)
	assert_eq(p.action, "", "a7f6e255: the abandoned door keeps opening")
	assert_false(game.actions.ongoing.has(p.get_instance_id()))
	assert_false(bool(game.grid.doors[DOOR]["busy"]))
	_tick_person(p, 0.5)
	assert_eq(game.grid.doors[DOOR]["state"], "closed")
	assert_eq(game.audio.played.count("door_open"), 0)


func test_sideways_stick_removes_the_old_path_door_even_with_forward_inertia() -> void:
	_place(p, 0.04)
	_begin()
	p.drive_dir = Vector3.RIGHT
	p.drive_speed = 2.1
	p.stick = Vector2.DOWN
	_tick_person(p, 0.05)
	assert_true(p.path.is_empty(), "the actual stick branch discarded the old route")
	assert_eq(p.action, "", "a7f6e255: reach alone accepts a door off the new direction")
	assert_false(game.actions.ongoing.has(p.get_instance_id()))
	assert_false(bool(game.grid.doors[DOOR]["busy"]))


func test_same_door_stick_and_release_inertia_keep_the_original_timer() -> void:
	_place(p, 0.04)
	_begin()
	p.stick = Vector2.RIGHT
	_tick_person(p, 0.125)
	var work: Dictionary = game.actions.ongoing[p.get_instance_id()]
	p.stick = Vector2.ZERO
	_tick_person(p, 0.01)
	assert_gt(p.drive_speed, 0.0, "release still has forward inertia")
	assert_eq(p.action, "door_walk")
	assert_true(is_same(game.actions.ongoing[p.get_instance_id()], work))
	assert_almost_eq(p.action_t, 0.365, 0.00001)
	p.stick = Vector2.RIGHT
	_tick_person(p, 0.365)
	assert_eq(game.grid.doors[DOOR]["state"], "open")
	assert_eq(game.audio.played.count("door_open"), 1)


func test_long_tick_approaches_locked_and_boarded_doors_before_refusing() -> void:
	for boarded: bool in [false, true]:
		game.grid.doors[DOOR]["planks"] = [0, 0]
		game.grid.set_door_state(DOOR, "closed" if boarded else "locked")
		if boarded:
			BuildingRules.add_plank(game.grid.doors[DOOR], 0)
		_place(p, 1.8, true)
		var before: Vector3 = p.position
		assert_gt(before.distance_to(FieldGrid.center(DOOR)), game.actions.INTERACT_REACH)
		_tick_person(p, 0.5)
		assert_gt(p.position.x, before.x, "a7f6e255: a failed out-of-reach action freezes approach")
		assert_lt(p.position.x, 30.0)
		assert_true(p.path.size() > 0, "rejection has not happened before reaching the door")
		assert_false(bool(game.grid.doors[DOOR]["busy"]))
		game.ledger.by_action.clear()
		game.audio.played.clear()
		_tick_person(p, 0.05)
		assert_true(p.path.is_empty(), "in reach, use the existing refusal")
		assert_eq(game.audio.played.count("boarded" if boarded else "door_locked"), 1)
		assert_true(game.ledger.by_action.is_empty(), "rattle/thud never enters zombie hearing")


func test_long_tick_approaches_a_locked_door_then_uses_its_key() -> void:
	game.grid.set_door_state(DOOR, "locked")
	_place(p, 1.8, true)
	p.add_item(FieldItems.key_for(int(game.grid.doors[DOOR]["building"])))
	_tick_person(p, 0.5)
	assert_gt(p.position.x, 28.2, "a7f6e255: never reaches the key interaction")
	_tick_person(p, 0.05)
	assert_eq(p.action, "door")
	assert_eq(game.grid.doors[DOOR]["state"], "locked")
	_tick_person(p, p.action_t)
	assert_eq(game.grid.doors[DOOR]["state"], "open")
	assert_eq(game.audio.played.count("door_unlock"), 1)


func test_completion_split_accumulates_gait_and_the_later_run_footstep() -> void:
	_place(p, DoorWalk.CLEARANCE, true)
	_begin()
	p.action_t = 0.01
	p.rotation.y = PI * 0.5
	p.brain[Gait.GROUND_RUN] = {"speed": 2.5, "running": false}
	p.brain["step_r"] = 0.19
	game.ledger.by_action.clear()
	var before: Vector3 = p.position
	var delta: float = 1.0 / 30.0
	_tick_person(p, delta)
	var gone: float = before.distance_to(p.position)
	var expected: float = lerpf(2.5, gone / delta, 1.0 - exp(-delta / Gait.RUN_TAU))
	assert_almost_eq(float(p.brain[Gait.GROUND_RUN]["speed"]), expected, 0.0001,
		"a7f6e255: only the first 0.01 s wait reaches the gait filter")
	assert_true(Gait.ground_runs(p))
	assert_true(game.ledger.by_action.has("run"), "the second span puts down a running foot")
	assert_false(game.ledger.by_action.has("walk"))
	if game.ledger.by_action.has("run"):
		var row: Dictionary = game.ledger.by_action["run"]
		var radius: float = SimNoise.footstep_radius(true, 1.0, 1.0, false,
			int(p.skills["stealth"])) * game.weather.sound_mult(true)
		assert_almost_eq(float(row["max_radius"]), radius, 0.00001)
		assert_almost_eq(float(row["linger"]), SimNoise.LINGER[SimNoise.Level.NORMAL], 0.00001)
	game._update_ground_gait(p, delta)
	assert_almost_eq(float(p.brain[Gait.GROUND_RUN]["speed"]), expected, 0.0001,
		"the final idle-gait call cannot apply the same delta twice")


func test_corner_tangent_does_not_open_or_refuse_an_unentered_door() -> void:
	for state: String in ["closed", "locked"]:
		game.grid.set_door_state(DOOR, state)
		_place(p, 1.0)
		p.position = Vector3(30.5, 0, 9.5)
		p.go_to(PackedVector3Array([Vector3(31.5, 0, 8.5)]))
		game.audio.played.clear()
		_tick_person(p, 0.5)
		assert_gt(p.position.x, 31.0, "a7f6e255: a corner touch opens/refuses the wrong door")
		assert_eq(game.grid.doors[DOOR]["state"], state)
		assert_eq(p.action, "")
		assert_false(bool(game.grid.doors[DOOR]["busy"]))
		assert_false(game.audio.played.has("door_open"))
		assert_false(game.audio.played.has("door_locked"))


func test_window_is_crossed_before_predicting_the_door_behind_it() -> void:
	Corridor.add_window(game.grid)
	_place(p, 1.05)
	assert_true(game.actions.can_vault_window(p, Corridor.WINDOW))
	_tick_person(p, 0.05)
	assert_gt(p.position.x, 29.0, "a7f6e255: door work prevents entering the earlier frame")
	assert_eq(p.action, "")
	assert_false(bool(game.grid.doors[DOOR]["busy"]))
	assert_eq(game.grid.doors[DOOR]["state"], "closed")
	assert_eq(game.audio.played.count("window_vault"), 1)
	_tick_person(p, 0.05)
	assert_eq(p.action, "door_walk", "after the frame, the usual prediction resumes")
	assert_eq(game.audio.played.count("window_vault"), 1, "no replay inside the frame")
	assert_false(game.actions.glass_asked.has(Corridor.WINDOW))
	assert_true(p.body.wounds.is_empty())


func test_glass_window_keeps_its_choice_before_any_door_reservation() -> void:
	Corridor.add_window(game.grid, true)
	_place(p, 1.05)
	_tick_person(p, 0.05)
	assert_true(game.actions.glass_asked.has(Corridor.WINDOW),
		"a7f6e255: premature door work hides the existing glass choice")
	assert_eq(p.action, "")
	assert_false(bool(game.grid.doors[DOOR]["busy"]))
	assert_lt(p.position.x, 29.0)
	assert_true(p.body.wounds.is_empty())


func test_save_outside_two_metres_preserves_reach_and_live_door_identity() -> void:
	_place(p, 1.8, true)
	game.actions.open_door_on_way(p, DOOR, 1.8, 3.9)
	assert_eq(p.action, "door_walk")
	var work: Dictionary = game.actions.ongoing[p.get_instance_id()]
	assert_gt(p.position.distance_to(FieldGrid.center(DOOR)), 2.0)
	assert_gt(float(work["reach"]), 2.0)
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))
	assert_eq(int(saved["version"]), 3)
	var restored = _game()
	FieldSave.apply(restored, saved)
	var q = restored.player
	var resumed: Dictionary = restored.actions.ongoing[q.get_instance_id()]
	assert_eq(float(resumed["reach"]), float(work["reach"]))
	assert_true(is_same(resumed["object"], restored.grid.doors[DOOR]))
	assert_true(is_same(q.action_busy, resumed["object"]))
	restored.actions.validate_work(q)
	assert_eq(q.action, "door_walk")
	restored._update_person(q, 0.5)
	assert_eq(restored.grid.doors[DOOR]["state"], "open")
	assert_false(restored.actions.ongoing.has(q.get_instance_id()))


func test_saved_work_without_reach_uses_the_existing_default_radius() -> void:
	_begin()
	game.actions.ongoing[p.get_instance_id()].erase("reach")
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))
	var restored = _game()
	FieldSave.apply(restored, saved)
	var q = restored.player
	restored.actions.validate_work(q)
	assert_eq(q.action, "door_walk")
	restored._update_person(q, 0.5)
	assert_eq(restored.grid.doors[DOOR]["state"], "open")


func test_real_ai_updates_do_not_restart_a_companion_door_timer() -> void:
	var mate = game.squad[1]
	_place(mate, 0.8, true)
	mate.command = "follow"
	p.position = END
	p.moving = true
	p.facing = PI * 0.5
	game.actions.open_door_on_way(mate, DOOR)
	var ticket: Dictionary = game.actions.ongoing[mate.get_instance_id()]
	for tick: int in 3:
		_tick_person(mate, 0.125)
		mate.brain["think_t"] = 0.0
		game.ai.update(0.125)
		assert_eq(mate.action, "door_walk")
		assert_true(is_same(game.actions.ongoing.get(mate.get_instance_id(), {}), ticket))
		assert_almost_eq(mate.action_t, 0.5 - float(tick + 1) * 0.125, 0.00001)
	_tick_person(mate, 0.125)
	assert_eq(game.grid.doors[DOOR]["state"], "open")
	assert_eq(game.audio.played.count("door_open"), 1)


func test_stop_cancels_door_work_and_releases_its_reservation() -> void:
	_begin()
	p.stop()
	assert_eq(p.action, "", "a7f6e255: stop leaves a live door action")
	assert_false(bool(game.grid.doors[DOOR]["busy"]))
	game.actions.validate_work(p)
	assert_false(game.actions.ongoing.has(p.get_instance_id()))
	_tick_person(p, 0.75)
	assert_eq(game.grid.doors[DOOR]["state"], "closed")


func test_ice_fall_in_first_span_prevents_the_remaining_stick_movement() -> void:
	_place(p, 0.4, true)
	_begin()
	p.action_t = 0.01
	p.stick = Vector2.RIGHT
	p.drive_dir = Vector3.RIGHT
	p.drive_speed = 3.9
	p.brain[Gait.GROUND_RUN] = {"speed": 3.9, "running": true}
	p.rotation.y = PI * 0.5
	p.brain["step_r"] = 0.3 # No contact in the first slice: the next RNG draw is the ice check.
	p.ice_t = 3.0
	game.grid.floor.fill(FieldGrid.Floor.ICE)
	var chosen_seed: int = -1
	for candidate: int in 1000:
		game.rng.seed = candidate
		if game.rng.randf() < 0.1:
			chosen_seed = candidate
			break
	assert_gte(chosen_seed, 0, "bounded selection of a real ice-fall random draw")
	if chosen_seed < 0:
		return
	game.rng.seed = chosen_seed
	var before: Vector3 = p.position
	_tick_person(p, 0.1)
	assert_gt(p.fallen_t, 0.0, "the real footstep ice branch called combat.fall")
	assert_lte(p.position.x - before.x, 3.9 * 0.01 + 0.00001,
		"a7f6e255: live stick input moves the fallen body in the remaining 0.09 s")
	assert_eq(game.grid.doors[DOOR]["state"], "closed")
	assert_false(bool(game.grid.doors[DOOR]["busy"]))
	assert_false(game.actions.ongoing.has(p.get_instance_id()))


func test_released_stick_cancels_when_forward_inertia_has_stopped() -> void:
	_place(p, 0.04)
	p.stick = Vector2.RIGHT
	_tick_person(p, 0.05)
	assert_eq(p.action, "door_walk")
	p.stick = Vector2.ZERO
	_tick_person(p, 0.25)
	assert_eq(p.drive_speed, 0.0)
	assert_eq(p.action, "", "a7f6e255: an idle body finishes its abandoned door work")
	assert_false(game.actions.ongoing.has(p.get_instance_id()))
	assert_false(bool(game.grid.doors[DOOR]["busy"]))
	_tick_person(p, 0.5)
	assert_eq(game.grid.doors[DOOR]["state"], "closed")
