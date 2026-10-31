extends GutTest
## Decisions 486 and 425; user motion feedback 2026-11-01.

const Person = preload("res://game/actors/person.gd")
const PersonVisual = preload("res://game/actors/person_visual.gd")
const FieldAi = preload("res://game/field_ai.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const Gait = preload("res://game/sim/gait.gd")
const MoveRules = preload("res://game/sim/move_rules.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")


class WatchClock:
	extends RefCounted
	var elapsed: float = 0.0


class PacePerson:
	extends Person
	var pace: float = 0.1

	func speed(_floor_kind: int) -> float:
		return pace


class WatchField:
	extends RefCounted
	var clock: WatchClock = WatchClock.new()
	var camera: Node3D
	var squad: Array = []
	var crew: Array = []
	var screen: Vector3 = Vector3.FORWARD
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()

	func cam_back() -> Vector3:
		return screen


var field: WatchField
var ai: FieldAi
var watcher: Person


func before_each() -> void:
	field = WatchField.new()
	watcher = _person()
	field.squad = [watcher]
	field.crew = [watcher]
	ai = FieldAi.new(field)


func _person() -> Person:
	var p: Person = Person.new()
	add_child_autofree(p)
	p.setup("motion_test", "Motion", "companion", Vector3.ZERO)
	return p


func _own() -> Array:
	return [{"name": "p_stand", "length": 2.0},
		{"name": "p_walk", "round": 1.64}, {"name": "p_run", "round": 2.27},
		{"name": "p_crouch_idle", "length": 2.0}, {"name": "p_crouch_walk", "round": 1.19}]


func _named(c: Vector2) -> String:
	var own: Array = _own()
	return String(own[int(c.y)]["name"])


func _draw(p: Person, note: Dictionary, delta: float) -> Vector2:
	return PersonVisual.motion_of(p, note, delta, [], _own())


func _walk_for(p: Person, note: Dictionary, speed: float, seconds: float, fps: int) -> Vector2:
	var delta: float = 1.0 / float(fps)
	var motion: Vector2 = Vector2.ZERO
	for _tick: int in range(int(roundf(seconds * float(fps)))):
		p.position += Vector3.BACK * speed * delta
		motion = _draw(p, note, delta)
	return motion


func _watch() -> Vector3:
	return ai._look_out(watcher, "point", Vector3.BACK, Vector3.RIGHT)


func test_follow_and_escort_hold_a_watch_for_at_least_one_and_a_half_seconds() -> void:
	var rng_before: int = field.rng.state
	var first: Vector3 = _watch()
	var site: Vector3 = watcher.position - Vector3.BACK * 5.0
	ai._escort_watch(watcher, site)
	var escort_first: float = watcher.facing
	for tick: int in range(1, 7):
		field.clock.elapsed = float(tick) * 0.249
		assert_almost_eq(first.angle_to(_watch()), 0.0, 0.0001)
		ai._escort_watch(watcher, site)
		assert_almost_eq(angle_difference(escort_first, watcher.facing), 0.0, 0.0001)
	assert_eq(field.rng.state, rng_before, "watching does not draw random numbers")


func test_a_watch_change_under_ten_degrees_is_ignored_after_the_hold() -> void:
	var first: Vector3 = _watch()
	field.clock.elapsed = 2.0
	var sweep: float = sin(field.clock.elapsed * 0.5) * deg_to_rad(FieldAi.LOOK_SWEEP_DEG)
	var base: Vector3 = Vector3.BACK.rotated(Vector3.UP, deg_to_rad(5.0) - sweep)
	var kept: Vector3 = ai._look_out(watcher, "point", base, Vector3.RIGHT)
	assert_almost_eq(first.angle_to(kept), 0.0, 0.0001)
	base = Vector3.BACK.rotated(Vector3.UP, deg_to_rad(12.0) - sweep)
	var changed: Vector3 = ai._look_out(watcher, "point", base, Vector3.RIGHT)
	assert_almost_eq(first.angle_to(changed), deg_to_rad(12.0), 0.0001)


func test_a_watch_keeps_the_camera_edge_when_the_sweep_crosses_the_camera() -> void:
	field.camera = Node3D.new()
	add_child_autofree(field.camera)
	field.camera.position = watcher.position + Vector3.BACK * 20.0
	field.screen = Vector3.BACK
	var base: Vector3 = Vector3.BACK.rotated(Vector3.UP, deg_to_rad(3.0))
	var site: Vector3 = watcher.position - base * 5.0
	for tick: int in range(105):
		field.clock.elapsed = float(tick) * 0.25
		var look: Vector3 = ai._look_out(watcher, "point", base, Vector3.RIGHT)
		assert_gt(look.x, 0.0, "the outward centre chooses the positive edge")
		assert_lte(look.dot(Vector3.BACK), 0.50001)
		ai._escort_watch(watcher, site)
		assert_gt(sin(watcher.facing), 0.0, "the escort uses the same edge latch")


func test_camera_edge_changes_only_beyond_fifteen_degrees_past_the_centre() -> void:
	field.camera = Node3D.new()
	add_child_autofree(field.camera)
	field.camera.position = watcher.position + Vector3.BACK * 20.0
	var base: Vector3 = Vector3.BACK.rotated(Vector3.UP, deg_to_rad(3.0))
	ai._look_out(watcher, "point", base, Vector3.RIGHT)
	field.clock.elapsed = 2.0
	base = Vector3.BACK.rotated(Vector3.UP, deg_to_rad(-10.0))
	assert_gt(ai._look_out(watcher, "point", base, Vector3.RIGHT).x, 0.0)
	field.clock.elapsed = 4.0
	base = Vector3.BACK.rotated(Vector3.UP, deg_to_rad(-20.0))
	assert_lt(ai._look_out(watcher, "point", base, Vector3.RIGHT).x, 0.0)


func test_the_held_watch_still_sweeps_close_to_forty_degrees_each_way() -> void:
	var least: float = 0.0
	var most: float = 0.0
	for tick: int in range(241):
		field.clock.elapsed = float(tick) * 0.25
		var look: Vector3 = _watch()
		var angle: float = atan2(look.x, look.z)
		least = minf(least, angle)
		most = maxf(most, angle)
	assert_lt(least, deg_to_rad(-35.0))
	assert_gt(most, deg_to_rad(35.0))
	assert_gte(least, deg_to_rad(-40.01))
	assert_lte(most, deg_to_rad(40.01))


func _field(extra: Dictionary = {}) -> FieldGame:
	var game: FieldGame = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false, "arrive": false}
	game.opts.merge(extra, true)
	game.map_script = BareLine
	add_child_autofree(game)
	game.set_process(false)
	return game


func test_a_saved_watch_picks_the_same_next_target_and_leaves_pushes_unsaved() -> void:
	var first: FieldGame = _field()
	var p: Person = first.squad[1]
	first.camera.position = p.position + Vector3.FORWARD * 20.0
	first.clock.elapsed = 2.0
	first.ai._look_out(p, "point", Vector3.BACK, Vector3.RIGHT)
	first.ai._escort_watch(p, p.position - Vector3.BACK * 5.0)
	p.visual_push = Vector3(0.3, 0.0, 0.0)
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(first)))
	assert_false(saved.is_empty())
	var resumed: FieldGame = _field(FieldSave.resume_opts(saved))
	var q: Person = resumed.squad[1]
	assert_eq(String(q.pid), String(p.pid))
	assert_eq(q.visual_push, Vector3.ZERO, "push history belongs only to the drawing")
	resumed.camera.position = first.camera.position
	for key: String in ["watch_point", "watch_escort"]:
		var state: Dictionary = p.brain[key]
		var restored: Dictionary = q.brain[key]
		assert_eq(restored.size(), state.size())
		for field_name: String in state:
			assert_true(restored.has(field_name))
			var value: float = float(state[field_name])
			assert_true(is_finite(value), "watch state contains only finite numbers")
			assert_almost_eq(float(restored[field_name]), value, 0.0000001)
	var rng_before: int = first.rng.state
	for elapsed: float in [2.5, 4.0, 6.0, 8.0]:
		first.clock.elapsed = elapsed
		resumed.clock.elapsed = elapsed
		var a: Vector3 = first.ai._look_out(p, "point", Vector3.BACK, Vector3.RIGHT)
		var b: Vector3 = resumed.ai._look_out(q, "point", Vector3.BACK, Vector3.RIGHT)
		assert_almost_eq(a.angle_to(b), 0.0, 0.0001)
		first.ai._escort_watch(p, p.position - Vector3.BACK * 5.0)
		resumed.ai._escort_watch(q, q.position - Vector3.BACK * 5.0)
		assert_almost_eq(angle_difference(p.facing, q.facing), 0.0, 0.0001)
	assert_eq(first.rng.state, rng_before)
	assert_eq(resumed.rng.state, rng_before)


func test_five_degrees_at_point_three_radians_per_second_do_not_step() -> void:
	for fps: int in [30, 60]:
		var p: Person = _person()
		var note: Dictionary = {}
		_draw(p, note, 0.0)
		var delta: float = 1.0 / float(fps)
		var left: float = deg_to_rad(5.0)
		while left > 0.00001:
			var turn: float = minf(left, 0.3 * delta)
			p.rotation.y += turn
			left -= turn
			assert_eq(_named(_draw(p, note, delta)), "p_stand")


func test_a_ninety_degree_turn_steps_and_a_recent_twenty_degree_turn_accumulates() -> void:
	var p: Person = _person()
	var note: Dictionary = {}
	_draw(p, note, 0.0)
	p.rotation.y += PI * 0.5
	var turned: Vector2 = _draw(p, note, 0.1)
	assert_eq(_named(turned), "p_walk")
	assert_gt(turned.x, 0.0, "a large turn advances the feet too")
	_draw(p, note, 0.3)
	p.rotation.y += 0.01
	assert_eq(_named(_draw(p, note, 0.1)), "p_stand", "a completed turn is not counted twice")
	p = _person()
	note = {}
	_draw(p, note, 0.0)
	p.rotation.y += deg_to_rad(5.0)
	assert_eq(_named(_draw(p, note, 0.1)), "p_walk", "angular speed alone can start a step")
	p = _person()
	note = {}
	_draw(p, note, 0.0)
	for _tick: int in range(9):
		p.rotation.y += 0.04
		_draw(p, note, 0.1)
	assert_eq(_named(_draw(p, note, 0.01)), "p_walk", "0.36 radians in the recent window")


func test_low_speed_jitter_stands_and_the_middle_band_keeps_either_state() -> void:
	for fps: int in [30, 60]:
		var p: Person = _person()
		var note: Dictionary = {}
		_draw(p, note, 0.0)
		assert_eq(_named(_walk_for(p, note, 0.1, 2.0, fps)), "p_stand")
		assert_eq(_named(_walk_for(p, note, 0.2, 2.0, fps)), "p_stand")
		assert_eq(_named(_walk_for(p, note, 1.0, 1.0, fps)), "p_walk")
		assert_eq(_named(_walk_for(p, note, 0.2, 2.0, fps)), "p_walk")
		assert_eq(_named(_walk_for(p, note, 0.1, 2.0, fps)), "p_stand")


func test_a_complete_stop_releases_the_walk_after_the_existing_grace() -> void:
	var p: Person = _person()
	var note: Dictionary = {}
	_draw(p, note, 0.0)
	assert_eq(_named(_walk_for(p, note, 3.0, 1.0, 60)), "p_walk")
	_draw(p, note, 0.3)
	assert_eq(_named(_draw(p, note, 0.1)), "p_stand")


func test_a_person_moved_only_by_separation_stands() -> void:
	var p: Person = _person()
	var note: Dictionary = {}
	p.brain["step_r"] = 0.42
	_draw(p, note, 0.0)
	p.position += Vector3.RIGHT * 0.3
	p.visual_push += Vector3.RIGHT * 0.3
	assert_eq(_named(_draw(p, note, 0.1)), "p_stand")
	assert_almost_eq(float(p.brain["step_r"]), 0.42, 0.0001)


func test_separation_records_the_displacements_it_really_applies() -> void:
	var game: FieldGame = _field()
	game.grid = FieldGrid.new(12, 12)
	game.levels = {0: game.grid}
	game.grid.refresh_paths()
	game.stairs.clear()
	var a: Person = game.squad[1]
	var b: Person = game.squad[2]
	game.people = [a, b]
	a.stop()
	b.stop()
	a.position = Vector3(5.5, 0.0, 5.5)
	b.position = a.position + Vector3.RIGHT * 0.2
	var at_a: Vector3 = a.global_position
	var at_b: Vector3 = b.global_position
	var pushed_a: Vector3 = a.visual_push
	var pushed_b: Vector3 = b.visual_push
	var note_a: Dictionary = {}
	var note_b: Dictionary = {}
	_draw(a, note_a, 0.0)
	_draw(b, note_b, 0.0)
	game._separate_people(0.1)
	assert_gt(a.global_position.distance_to(at_a) + b.global_position.distance_to(at_b), 0.0)
	assert_almost_eq((a.visual_push - pushed_a).distance_to(a.global_position - at_a), 0.0, 0.0001)
	assert_almost_eq((b.visual_push - pushed_b).distance_to(b.global_position - at_b), 0.0, 0.0001)
	assert_eq(_named(_draw(a, note_a, 0.1)), "p_stand")
	assert_eq(_named(_draw(b, note_b, 0.1)), "p_stand")


func test_push_history_covers_skipped_draws_and_preserves_real_movement() -> void:
	var p: Person = _person()
	var note: Dictionary = {}
	_draw(p, note, 0.0)
	p.visual_push += Vector3.RIGHT * 0.1
	p.visual_push += Vector3.FORWARD * 0.2
	p.position += p.visual_push
	assert_eq(_named(_draw(p, note, 0.1)), "p_stand")
	p.position += Vector3.BACK * 0.1 + Vector3.RIGHT * 0.3
	p.visual_push += Vector3.RIGHT * 0.3
	var motion: Vector2 = _draw(p, note, 0.1)
	assert_eq(_named(motion), "p_walk")
	assert_almost_eq(motion.x, 0.1 / 1.64, 0.0001, "only real ground movement advances the feet")


func test_backward_ground_movement_reverses_the_phase_and_forward_movement_advances_it() -> void:
	var p: Person = _person()
	var note: Dictionary = {"step": 0.8}
	_draw(p, note, 0.0)
	var back: Vector2 = _walk_for(p, note, -1.0, 1.0, 30)
	assert_eq(_named(back), "p_walk")
	assert_lt(back.x, 0.8)
	p = _person()
	note = {}
	_draw(p, note, 0.0)
	p.facing = PI
	var front: Vector2 = _walk_for(p, note, 1.0, 1.0, 30)
	assert_eq(_named(front), "p_walk")
	assert_gt(front.x, 0.0, "the drawn yaw, rather than the intended facing, is used")


func test_sideways_movement_keeps_forward_phase_until_one_hundred_degrees() -> void:
	for angle: float in [90.0, 99.0, 101.0]:
		var p: Person = _person()
		var note: Dictionary = {"step": 0.5}
		_draw(p, note, 0.0)
		p.position += Vector3.BACK.rotated(Vector3.UP, deg_to_rad(angle)) * 0.1
		var motion: Vector2 = _draw(p, note, 0.1)
		if angle > 100.0:
			assert_lt(motion.x, 0.5)
		else:
			assert_gt(motion.x, 0.5)


func test_backward_rule_phase_reflects_between_the_same_two_foot_contacts() -> void:
	var p: Person = _person()
	var note: Dictionary = {}
	_draw(p, note, 0.0)
	for contact: float in SimNoise.STEP_AT:
		p.position += Vector3.FORWARD * 0.1
		p.brain["step_r"] = contact
		var motion: Vector2 = _draw(p, note, 0.1)
		assert_almost_eq(motion.x, 0.85 - contact, 0.0001)
		assert_almost_eq(float(p.brain["step_r"]), contact, 0.0001, "drawing does not change the rules")


func test_light_input_keeps_rule_footsteps_without_standing_glide() -> void:
	var game: FieldGame = _motion_field()
	var p: Person = game.player
	var counter: Person = _person()
	counter.display_name = p.display_name
	p.brain["step_r"] = 0.0
	counter.brain["step_r"] = 0.0
	p.stick = Vector2(0.0, 0.051)
	var note: Dictionary = {}
	_draw(p, note, 0.0)
	var count: int = 0
	var glides: int = 0
	var delta: float = 1.0 / 60.0
	for _tick: int in range(300):
		var before: Vector3 = p.global_position
		var pushed: Vector3 = p.visual_push
		game.clock.advance(delta)
		game._drive(p, delta)
		var gone: float = p.global_position.distance_to(before)
		assert_gte(gone / delta, Person.MOVE_MIN - 0.0001)
		count += FieldGame.steps_in(counter, gone)
		assert_almost_eq(float(p.brain["step_r"]), float(counter.brain["step_r"]), 0.000001)
		glides += _standing_glide(p, note, delta, before, pushed)
	assert_gt(count, 0, "decision 425 still advances footsteps by distance")
	assert_eq(glides, 0, "decision 442 removes the input that left the picture standing")


func _ground_tick(p: Person, note: Dictionary, speed: float, delta: float, floor_kind: int = FieldGrid.Floor.SNOW) -> Vector2:
	var gone: float = speed * delta
	p.position += Vector3.BACK * gone
	p.moving = absf(speed) > 0.0
	Gait.update_ground_run(p, gone, delta, floor_kind)
	FieldGame.steps_in(p, gone)
	return _draw(p, note, delta)


func _ground_for(p: Person, note: Dictionary, speed: float, seconds: float, fps: int) -> Vector2:
	var delta: float = 1.0 / float(fps)
	var motion: Vector2 = Vector2.ZERO
	for _tick: int in range(int(roundf(seconds * float(fps)))):
		motion = _ground_tick(p, note, speed, delta)
	return motion


func _assert_round(p: Person, gone: float, gait: String) -> void:
	var before: float = float(p.brain.get("step_r", Gait.first_step(p)))
	var size: float = float(SimNoise.STEP_ROUND[gait]) * Gait.stride(p)
	FieldGame.steps_in(p, gone)
	assert_almost_eq(float(p.brain["step_r"]), fposmod(before + gone / size, 1.0), 0.000001, gait + " round")


func test_run_on_at_nine_tenths_of_walk_uses_the_walk_picture_and_round() -> void:
	var p: Person = _person()
	p.running = true
	var note: Dictionary = {}
	_draw(p, note, 0.0)
	var walking_speed: float = p.walk_speed(FieldGrid.Floor.SNOW)
	var motion: Vector2 = _ground_for(p, note, walking_speed * 0.9, 1.0, 60)
	assert_true(Gait.runs(p), "the run remains allowed")
	assert_false(Gait.ground_runs(p))
	assert_eq(_named(motion), "p_walk")
	_assert_round(p, 0.1, "walk")


func test_run_speed_uses_the_run_picture_and_round() -> void:
	var p: Person = _person()
	p.running = true
	var note: Dictionary = {}
	_draw(p, note, 0.0)
	var motion: Vector2 = _ground_for(p, note, p.speed(FieldGrid.Floor.SNOW), 1.0, 60)
	assert_true(Gait.ground_runs(p))
	assert_eq(_named(motion), "p_run")
	_assert_round(p, 0.1, "run")


func test_one_point_ten_of_walk_keeps_either_previous_gait() -> void:
	for was_running: bool in [false, true]:
		var p: Person = _person()
		p.running = true
		var speed: float = p.walk_speed(FieldGrid.Floor.SNOW) * 1.10
		p.brain[Gait.GROUND_RUN] = {"speed": speed, "running": was_running}
		var note: Dictionary = {}
		_draw(p, note, 0.0)
		var motion: Vector2 = _ground_for(p, note, speed, 1.0, 60)
		assert_eq(Gait.ground_runs(p), was_running)
		assert_eq(_named(motion), "p_run" if was_running else "p_walk")
		_assert_round(p, 0.1, "run" if was_running else "walk")


func test_run_limits_are_inclusive_and_a_switch_keeps_the_foot_phase() -> void:
	for was_running: bool in [false, true]:
		var p: Person = _person()
		p.running = true
		var ratio: float = 1.05 if was_running else 1.15
		var speed: float = p.walk_speed(FieldGrid.Floor.SNOW) * ratio
		p.brain[Gait.GROUND_RUN] = {"speed": speed, "running": was_running}
		p.brain["step_r"] = 0.97
		var note: Dictionary = {}
		_draw(p, note, 0.0)
		var delta: float = 0.125
		Gait.update_ground_run(p, speed * delta, delta, FieldGrid.Floor.SNOW)
		assert_eq(Gait.ground_runs(p), not was_running)
		assert_almost_eq(float(p.brain["step_r"]), 0.97, 0.000001, "switching does not reset the round")
		_assert_round(p, speed * delta, "walk" if was_running else "run")
		p.position += Vector3.BACK * speed * delta
		var motion: Vector2 = _draw(p, note, delta)
		assert_eq(_named(motion), "p_walk" if was_running else "p_run")
		assert_almost_eq(motion.x, float(p.brain["step_r"]), 0.000001, "the new clip keeps the same round position")


func test_crouch_load_breath_and_a_hurt_leg_override_a_fast_ground_sample() -> void:
	for block: String in ["crouch", "load", "breath", "leg"]:
		var p: Person = _person()
		p.running = true
		p.brain[Gait.GROUND_RUN] = {"speed": 20.0, "running": true}
		match block:
			"crouch":
				p.crouched = true
			"load":
				p.items.clear()
				p.add_item("scrap", int(ceil(p.carry_limit() * 1.25)))
				assert_eq(p.carry_state(), 2)
			"breath":
				p.body.breath = 0.0
			"leg":
				p.body.fracture(true, "leg_left")
		assert_false(Gait.runs(p), block)
		Gait.update_ground_run(p, 2.0, 0.1, FieldGrid.Floor.SNOW)
		assert_false(Gait.ground_runs(p), block)
		_assert_round(p, 0.1, "crouch" if p.crouched else "walk")
		var note: Dictionary = {}
		_draw(p, note, 0.0)
		p.position += Vector3.BACK * 0.3
		assert_eq(_named(_draw(p, note, 0.1)), "p_crouch_walk" if p.crouched else "p_walk")


func test_walk_speed_matches_only_switching_run_off_with_the_same_floor_body_and_load() -> void:
	var p: Person = _person()
	p.hunger_level = 1
	p.sore_level = 1
	for load_share: float in [0.0, 0.8, 1.25, 2.0]:
		p.items.clear()
		p.add_item("scrap", int(ceil(p.carry_limit() * load_share)))
		for floor_kind: int in [FieldGrid.Floor.SNOW, FieldGrid.Floor.DEEP_SNOW]:
			p.running = false
			var expected: float = p.speed(floor_kind)
			p.running = true
			assert_almost_eq(p.walk_speed(floor_kind), expected, 0.000001)
			assert_true(p.running, "reading the walking speed preserves the run request")


func test_the_real_stick_walks_when_pushed_lightly_and_runs_when_pushed_fully() -> void:
	var game: FieldGame = _field()
	var p: Person = game.player
	p.position = game.lift(Vector2i(5, 5), 0)
	p.running = true
	var floor_kind: int = game.grid.floor_at(FieldGrid.cell_of(p.position))
	var walking_speed: float = p.walk_speed(floor_kind)
	p.stick = Vector2(0.0, walking_speed * 0.9 / (p.speed(floor_kind) * 1.6))
	var note: Dictionary = {}
	_draw(p, note, 0.0)
	var motion: Vector2 = Vector2.ZERO
	var delta: float = 1.0 / 60.0
	for _tick: int in range(120):
		game.clock.advance(delta)
		game._drive(p, delta)
		motion = _draw(p, note, delta)
	assert_almost_eq(float(p.brain[Gait.GROUND_RUN]["speed"]), walking_speed * 0.9, 0.05)
	assert_false(Gait.ground_runs(p))
	assert_eq(_named(motion), "p_walk")
	p.stick = Vector2(0.0, 1.0)
	for _tick: int in range(120):
		game.clock.advance(delta)
		game._drive(p, delta)
		motion = _draw(p, note, delta)
	assert_true(Gait.ground_runs(p))
	assert_eq(_named(motion), "p_run")
	_assert_round(p, 0.1, "run")


func test_a_companion_closing_short_gaps_walks_and_an_open_path_runs() -> void:
	var game: FieldGame = _field()
	var p: Person = game.squad[1]
	p.position = game.lift(Vector2i(5, 5), 0)
	p.running = true
	p.turn_rate = 0.0
	p.rotation.y = 0.0
	var note: Dictionary = {}
	_draw(p, note, 0.0)
	var motion: Vector2 = Vector2.ZERO
	var delta: float = 0.1
	var slow_step: float = p.walk_speed(FieldGrid.Floor.SNOW) * 0.9 * delta
	for _tick: int in range(20):
		p.path = PackedVector3Array([p.position + Vector3.BACK * slow_step])
		game.clock.advance(delta)
		game._move_person(p, delta)
		motion = _draw(p, note, delta)
	assert_true(Gait.runs(p))
	assert_false(Gait.ground_runs(p))
	assert_eq(_named(motion), "p_walk")
	_assert_round(p, 0.1, "walk")
	for _tick: int in range(10):
		p.path = PackedVector3Array([p.position + Vector3.BACK])
		game.clock.advance(delta)
		game._move_person(p, delta)
		motion = _draw(p, note, delta)
	assert_true(Gait.ground_runs(p))
	assert_eq(_named(motion), "p_run")
	_assert_round(p, 0.1, "run")


func test_a_tick_samples_once_and_idle_ticks_decay_the_run_filter() -> void:
	var game: FieldGame = _field()
	var p: Person = game.player
	p.running = true
	var floor_kind: int = game.grid.floor_at(FieldGrid.cell_of(p.position))
	var speed: float = p.speed(floor_kind)
	p.brain[Gait.GROUND_RUN] = {"speed": speed, "running": true}
	game.clock.advance(0.1)
	game._update_ground_gait(p, 0.1, speed * 0.1)
	var sampled: float = float(p.brain[Gait.GROUND_RUN]["speed"])
	game._update_ground_gait(p, 0.1)
	assert_almost_eq(float(p.brain[Gait.GROUND_RUN]["speed"]), sampled, 0.000001)
	game.clock.advance(0.1)
	game._update_ground_gait(p, 0.1)
	assert_almost_eq(float(p.brain[Gait.GROUND_RUN]["speed"]), sampled * exp(-0.1 / Gait.RUN_TAU), 0.000001)
	assert_false(Gait.ground_runs(p), "a tick with no travel can release the run")


func test_ground_run_survives_field_save_and_keeps_the_same_later_decisions() -> void:
	var first: FieldGame = _field()
	var p: Person = first.squad[1]
	p.running = true
	var note: Dictionary = {}
	_draw(p, note, 0.0)
	var walking_speed: float = p.walk_speed(FieldGrid.Floor.SNOW)
	_ground_for(p, note, walking_speed * 1.4, 1.0, 60)
	_ground_for(p, note, walking_speed * 1.10, 1.0, 60)
	assert_true(Gait.ground_runs(p), "save the running side of the middle band")
	first.clock.elapsed = 2.0
	first._update_ground_gait(p, 0.0)
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(first)))
	assert_false(saved.is_empty())
	var resumed: FieldGame = _field(FieldSave.resume_opts(saved))
	var q: Person = resumed.squad[1]
	var restored_note: Dictionary = {}
	_draw(q, restored_note, 0.0)
	assert_eq(Gait.ground_runs(q), Gait.ground_runs(p))
	for value_key: String in ["speed", "tick"]:
		assert_true(is_finite(float(q.brain[Gait.GROUND_RUN][value_key])))
		assert_almost_eq(float(q.brain[Gait.GROUND_RUN][value_key]), float(p.brain[Gait.GROUND_RUN][value_key]), 0.0000001)
	for ratio: float in [1.10, 0.9, 1.4]:
		for _tick: int in range(60):
			var a: Vector2 = _ground_tick(p, note, walking_speed * ratio, 1.0 / 60.0)
			var b: Vector2 = _ground_tick(q, restored_note, walking_speed * ratio, 1.0 / 60.0)
			assert_eq(Gait.ground_runs(q), Gait.ground_runs(p))
			assert_eq(_named(b), _named(a))
			assert_almost_eq(float(q.brain["step_r"]), float(p.brain["step_r"]), 0.0000001)


func _ground_path(fps: int) -> Dictionary:
	var p: Person = _person()
	p.running = true
	var note: Dictionary = {}
	_draw(p, note, 0.0)
	var order: Array[bool] = [false]
	var times: Array[float] = []
	var speeds: Array[float] = []
	var elapsed: float = 0.0
	var previous: bool = false
	var delta: float = 1.0 / float(fps)
	var walking_speed: float = p.walk_speed(FieldGrid.Floor.SNOW)
	for ratio: float in [0.9, 1.10, 1.4, 1.10, 0.9, 0.0, 1.4, 1.10, 0.9]:
		for _tick: int in range(fps):
			_ground_tick(p, note, walking_speed * ratio, delta)
			elapsed += delta
			var running: bool = Gait.ground_runs(p)
			if running != previous:
				order.append(running)
				times.append(elapsed)
				previous = running
		speeds.append(float(p.brain[Gait.GROUND_RUN]["speed"]))
	return {"order": order, "times": times, "speeds": speeds}


func test_thirty_and_sixty_hz_take_the_same_ground_gait_path() -> void:
	var slow: Dictionary = _ground_path(30)
	var fast: Dictionary = _ground_path(60)
	var expected: Array[bool] = [false, true, false, true, false]
	var slow_order: Array[bool] = slow["order"]
	var fast_order: Array[bool] = fast["order"]
	assert_eq(slow_order, expected)
	assert_eq(fast_order, expected)
	var slow_times: Array[float] = slow["times"]
	var fast_times: Array[float] = fast["times"]
	assert_eq(slow_times.size(), fast_times.size())
	for index: int in range(mini(slow_times.size(), fast_times.size())):
		assert_almost_eq(slow_times[index], fast_times[index], 1.0 / 30.0 + 0.000001)
	var slow_speeds: Array[float] = slow["speeds"]
	var fast_speeds: Array[float] = fast["speeds"]
	for index: int in range(slow_speeds.size()):
		assert_almost_eq(slow_speeds[index], fast_speeds[index], 0.0000001)


func test_missing_or_nonfinite_ground_samples_leave_only_a_finite_saved_state() -> void:
	var p: Person = _person()
	p.running = true
	assert_false(Gait.ground_runs(p), "old saves start walking until sampled")
	for bad_delta: float in [0.0, -1.0, 0.1, NAN, INF]:
		p.brain[Gait.GROUND_RUN] = {"speed": NAN, "running": true, "tick": INF}
		Gait.update_ground_run(p, INF, bad_delta, FieldGrid.Floor.SNOW)
		var state: Dictionary = p.brain[Gait.GROUND_RUN]
		assert_true(is_finite(float(state["speed"])))
		assert_false(Gait.ground_runs(p))
		assert_false(state.has("tick"), "the field supplies a fresh finite tick")


func _motion_field(floor_kind: int = FieldGrid.Floor.SNOW) -> FieldGame:
	var game: FieldGame = _field()
	game.grid = FieldGrid.new(40, 40)
	game.grid.floor.fill(floor_kind)
	game.grid.refresh_paths()
	game.levels = {0: game.grid}
	game.stairs.clear()
	game.zombies.list.clear()
	game.pending_spawn.clear()
	for index: int in range(game.squad.size()):
		var p: Person = game.squad[index]
		p.stop()
		p.brain.clear()
		p.running = false
		p.stick = Vector2.ZERO
		p.drive_speed = 0.0
		p.position = Vector3(2.5 + float(index) * 2.0, 0.0, 2.5)
	game.player.position = Vector3(10.5, 0.0, 10.5)
	return game


func _standing_glide(p: Person, note: Dictionary, delta: float, before: Vector3, pushed: Vector3) -> int:
	var ground: Vector3 = p.global_position - before - (p.visual_push - pushed)
	ground.y = 0.0
	var clip: String = _named(_draw(p, note, delta))
	if clip == "p_stand" or (clip == "p_walk" and not bool(note.get("ground_walk", false))):
		return int(ground.length() > PersonVisual.GROUND_MIN)
	return 0


func test_stick_deadzone_and_first_tick_skip_the_standing_speed_band_at_both_rates() -> void:
	for fps: int in [30, 60]:
		var game: FieldGame = _motion_field()
		var p: Person = game.player
		var delta: float = 1.0 / float(fps)
		for push: float in [0.0, 0.01, 0.049]:
			p.stick = Vector2(0.0, push)
			var rest_at: Vector3 = p.position
			game._drive(p, delta)
			assert_almost_eq(p.drive_speed, 0.0, 0.000001)
			assert_eq(p.position, rest_at)
			assert_false(p.moving)
		p.stick = Vector2(0.0, 0.051)
		var before: Vector3 = p.position
		game._drive(p, delta)
		assert_gte(p.drive_speed, Person.MOVE_MIN)
		assert_gte(p.position.distance_to(before) / delta, Person.MOVE_MIN - 0.0001)
		assert_true(p.moving)
		assert_lt(p.drive_speed, p.speed(FieldGrid.Floor.SNOW) * 0.35, "inertia still builds beyond the first tick")


func test_stick_release_never_crosses_the_slow_band_on_snow_or_loaded_ice() -> void:
	for fps: int in [30, 60]:
		for floor_kind: int in [FieldGrid.Floor.SNOW, FieldGrid.Floor.ICE]:
			var game: FieldGame = _motion_field(floor_kind)
			var p: Person = game.player
			if floor_kind == FieldGrid.Floor.ICE:
				p.add_item("scrap", int(ceil(p.carry_limit() * 0.8)))
				assert_gt(p.carry_state(), 0)
			assert_gt(p.speed(floor_kind), 0.0)
			var delta: float = 1.0 / float(fps)
			p.stick = Vector2(0.0, 0.2)
			for _tick: int in range(fps * 2):
				game.clock.advance(delta)
				game._drive(p, delta)
			p.stick = Vector2.ZERO
			var coast_ticks: int = 0
			for _tick: int in range(fps * 3):
				var before: Vector3 = p.position
				game.clock.advance(delta)
				game._drive(p, delta)
				var speed: float = p.position.distance_to(before) / delta
				assert_true(is_zero_approx(p.drive_speed) or p.drive_speed >= Person.MOVE_MIN)
				assert_true(is_zero_approx(speed) or speed >= Person.MOVE_MIN - 0.0001)
				coast_ticks += int(p.moving)
			assert_gt(coast_ticks, 0, "letting go retains the existing coast")
			assert_almost_eq(p.drive_speed, 0.0, 0.000001)
			assert_false(p.moving)


func test_a_positive_subminimum_pace_starts_at_the_floor_but_zero_still_cannot_move() -> void:
	for fps: int in [30, 60]:
		var game: FieldGame = _motion_field()
		var p: PacePerson = PacePerson.new()
		add_child_autofree(p)
		p.setup("motion_slow", "Slow", "chief", Vector3(10.5, 0.0, 10.5))
		p.stick = Vector2(0.0, 0.051)
		var delta: float = 1.0 / float(fps)
		var note: Dictionary = {}
		_draw(p, note, 0.0)
		game._drive(p, delta)
		assert_almost_eq(p.drive_speed, Person.MOVE_MIN, 0.000001)
		assert_eq(_named(_draw(p, note, delta)), "p_walk")
		var before: Vector3 = p.position
		p.pace = 0.0
		for stick: Vector2 in [Vector2.ZERO, Vector2(0.0, 0.051)]:
			p.stick = stick
			p.drive_speed = Person.MOVE_MIN
			game._drive(p, delta)
			assert_almost_eq(p.drive_speed, 0.0, 0.000001)
			assert_eq(p.position, before)
			assert_false(p.moving)


func test_a_wall_slide_below_the_minimum_holds_but_a_faster_slide_still_moves() -> void:
	for fps: int in [30, 60]:
		var game: FieldGame = _motion_field()
		var p: Person = game.player
		game.grid.set_solid(Vector2i(11, 10), FieldGrid.Solid.WALL)
		game.grid.refresh_paths()
		p.position = Vector3(10.9995, 0.0, 10.5)
		p.stick = Vector2(1.0, 0.2).normalized()
		var before: Vector3 = p.position
		var delta: float = 1.0 / float(fps)
		game._drive(p, delta)
		assert_eq(p.position, before)
		assert_almost_eq(p.drive_speed, 0.0, 0.000001)
		assert_false(p.moving)
		p.drive_speed = Person.WALK
		game._drive(p, delta)
		assert_true(p.moving)
		assert_gte(p.position.distance_to(before) / delta, Person.MOVE_MIN)


func test_fast_reversal_keeps_its_walk_drop_above_the_minimum() -> void:
	for fps: int in [30, 60]:
		var game: FieldGame = _motion_field()
		var p: Person = game.player
		var delta: float = 1.0 / float(fps)
		p.running = true
		p.stick = Vector2.RIGHT
		for _tick: int in range(fps):
			game.clock.advance(delta)
			game._drive(p, delta)
		assert_gt(p.drive_speed, Person.WALK * 1.1)
		p.stick = Vector2.LEFT
		game._drive(p, delta)
		assert_eq(p.drive_dir, Vector3.LEFT)
		assert_gte(p.drive_speed, Person.MOVE_MIN)
		assert_lt(p.drive_speed, Person.WALK, "the fast reversal still drops to a walk")


func test_planted_feet_still_hold_the_stick_and_the_path() -> void:
	var game: FieldGame = _motion_field()
	for p: Person in [game.player, game.squad[1]]:
		p.shove_t = 0.1
		p.stick = Vector2.RIGHT
		p.drive_speed = 1.0
		p.path = PackedVector3Array([p.position + Vector3.RIGHT])
		var before: Vector3 = p.position
		assert_true(game.combat.feet_held(p))
		game._drive(p, 1.0 / 60.0)
		assert_almost_eq(p.drive_speed, 0.0, 0.000001)
		assert_false(p.moving)
		game._move_person(p, 1.0 / 60.0)
		assert_eq(p.position, before)
		assert_false(p.moving)


func test_a_heading_share_of_point_one_metres_per_second_turns_without_translation() -> void:
	for fps: int in [30, 60]:
		var game: FieldGame = _motion_field()
		var p: Person = game.squad[1]
		var delta: float = 1.0 / float(fps)
		var off: float = acos(0.1 * cos(deg_to_rad(MoveRules.FREE_DEG)) / p.speed(FieldGrid.Floor.SNOW))
		p.turn_rate = 1.0
		p.look = -off
		p.rotation.y = p.look
		p.path = PackedVector3Array([p.position + Vector3.BACK * 5.0])
		assert_almost_eq(p.speed(FieldGrid.Floor.SNOW) * MoveRules.heading_share(off), 0.1, 0.000001)
		var before: Vector3 = p.position
		var look: float = p.look
		game._move_person(p, delta)
		assert_eq(p.position, before)
		assert_false(p.moving)
		assert_false(p.path.is_empty(), "the turn keeps its destination")
		p.turn_tick(delta)
		assert_almost_eq(absf(angle_difference(look, p.look)), p.turn_rate * delta, 0.000001)
		assert_lt(absf(angle_difference(p.look, p.facing)), off)


func test_a_short_last_path_step_is_clipped_by_distance_and_still_allowed() -> void:
	var game: FieldGame = _motion_field()
	var p: Person = game.squad[1]
	p.command = "wait"
	p.turn_rate = 0.0
	var before: Vector3 = p.position
	var goal: Vector3 = before + Vector3.BACK * 0.2
	p.path = PackedVector3Array([goal])
	assert_gt(p.speed(FieldGrid.Floor.SNOW), Person.MOVE_MIN)
	game._move_person(p, 1.0)
	assert_eq(p.position, goal)
	assert_true(p.moving)
	assert_almost_eq(p.position.distance_to(before), 0.2, 0.000001)
	assert_lt(p.position.distance_to(before), Person.MOVE_MIN, "distance clipping is not a slow speed request")


func test_backpedalling_still_caps_the_speed_and_keeps_the_held_face() -> void:
	var game: FieldGame = _motion_field()
	var p: Person = game.squad[1]
	p.running = true
	p.turn_rate = 1.0
	p.brain["face_hold"] = p.position + Vector3.FORWARD * 5.0
	p.brain["face_hold_t"] = game.clock.elapsed
	p.path = PackedVector3Array([p.position + Vector3.BACK * 5.0])
	var before: Vector3 = p.position
	var delta: float = 1.0 / 60.0
	game._move_person(p, delta)
	assert_true(p.moving)
	assert_almost_eq(p.position.distance_to(before) / delta, MoveRules.BACKPEDAL, 0.0001)
	assert_almost_eq(absf(angle_difference(p.facing, PI)), 0.0, 0.000001)


func test_reissued_short_follow_paths_settle_with_the_existing_allowance() -> void:
	for fps: int in [30, 60]:
		var game: FieldGame = _motion_field()
		var p: Person = game.squad[1]
		var before: Vector3 = p.position
		var goal: Vector3 = before + Vector3.BACK * (FieldAi.FOLLOW_SETTLE - 0.01)
		p.brain["follow_slot"] = goal
		p.command = "follow"
		p.turn_rate = 0.0
		for _tick: int in range(fps * 3):
			game.ai._follow_walk(p, PackedVector3Array([goal]))
			game._move_person(p, 1.0 / float(fps))
			assert_eq(p.position, before)
			assert_true(p.path.is_empty())
			assert_false(p.moving)


func test_follow_arrival_uses_the_remaining_route_and_keeps_other_short_paths() -> void:
	var game: FieldGame = _motion_field()
	var p: Person = game.squad[1]
	p.turn_rate = 0.0
	var before: Vector3 = p.position
	var goal: Vector3 = before + Vector3.BACK * 0.2
	p.brain["follow_slot"] = goal
	p.path = PackedVector3Array([before + Vector3.RIGHT * 0.2,
		goal + Vector3.RIGHT * 0.2, goal])
	game._move_person(p, 0.02)
	assert_true(p.moving, "a nearby slot beyond a detour is not an arrival")
	assert_gt(p.position.distance_to(before), 0.0)
	assert_false(p.path.is_empty())
	p.position = before
	p.path = PackedVector3Array([goal])
	p.command = "wait"
	game._move_person(p, 0.02)
	assert_true(p.moving, "another order does not inherit a stale follow slot")
	assert_gt(p.position.distance_to(before), 0.0)
	p.position = before
	p.command = "follow"
	p.path = PackedVector3Array([before + Vector3.RIGHT * 0.2])
	game._move_person(p, 0.02)
	assert_true(p.moving, "a combat or work destination is not the follow slot")


func test_minimum_ground_speed_walks_on_its_first_tick_and_every_frame_for_three_seconds() -> void:
	for fps: int in [30, 60]:
		for start: float in [0.0, 39.5]:
			var p: Person = _person()
			p.position.z = start
			var note: Dictionary = {}
			_draw(p, note, 0.0)
			var delta: float = 1.0 / float(fps)
			var standing_frames: int = 0
			for tick: int in range(fps * 3):
				p.position += Vector3.BACK * Person.MOVE_MIN * delta
				var clip: String = _named(_draw(p, note, delta))
				standing_frames += int(clip == "p_stand")
				assert_eq(clip, "p_walk")
				if tick == 0:
					assert_true(bool(note["ground_walk"]))
					assert_lt(float(note["ground_speed"]), PersonVisual.WALK_ON, "entry does not wait for the filter")
			assert_eq(standing_frames, 0)
			assert_eq(_named(_draw(p, note, PersonVisual.STILL_AFTER)), "p_stand")


func test_subtraction_noise_and_separation_cannot_start_a_walk() -> void:
	for delta: float in [0.0000001, 1.0 / 30.0, 1.0 / 60.0]:
		var sample_note: Dictionary = {}
		assert_false(PersonVisual._ground_walk(sample_note, PersonVisual.GROUND_MIN * 0.5, delta, delta))
		assert_false(PersonVisual._ground_walk(sample_note, PersonVisual.GROUND_MIN, delta, delta * 2.0))
	var p: Person = _person()
	var note: Dictionary = {}
	_draw(p, note, 0.0)
	for _tick: int in range(120):
		var push: Vector3 = Vector3.RIGHT * 0.03
		p.position += push
		p.visual_push += push
		assert_eq(_named(_draw(p, note, 1.0 / 60.0)), "p_stand")


func test_stick_start_stop_and_reversal_have_zero_standing_translation_ticks() -> void:
	for fps: int in [30, 60]:
		var game: FieldGame = _motion_field()
		var p: Person = game.player
		var note: Dictionary = {}
		_draw(p, note, 0.0)
		var delta: float = 1.0 / float(fps)
		var glides: int = 0
		var moving_ticks: int = 0
		var still_ticks: int = 0
		for tick: int in range(fps * 8):
			var t: float = float(tick) * delta
			p.running = t >= 1.5 and t < 4.0
			if t < 0.25 or (t >= 4.0 and t < 5.0) or t >= 6.5:
				p.stick = Vector2.ZERO
			elif t < 1.5:
				p.stick = Vector2(0.0, 0.051)
			elif t < 3.0:
				p.stick = Vector2.DOWN
			elif t < 4.0:
				p.stick = Vector2.UP
			else:
				p.stick = Vector2(0.051, 0.0)
			var before: Vector3 = p.global_position
			var pushed: Vector3 = p.visual_push
			game.clock.advance(delta)
			game._drive(p, delta)
			game._update_ground_gait(p, delta)
			p.refresh_view(false)
			glides += _standing_glide(p, note, delta, before, pushed)
			moving_ticks += int(p.moving)
			still_ticks += int(not p.moving)
		assert_gt(moving_ticks, fps)
		assert_gt(still_ticks, fps)
		assert_eq(glides, 0)


func test_follow_start_arrival_and_turn_have_zero_standing_translation_ticks() -> void:
	for fps: int in [30, 60]:
		var game: FieldGame = _motion_field()
		game.player.position = Vector3(20.5, 0.0, 20.5)
		game.player.facing = 0.0
		var p: Person = game.squad[1]
		p.position = Vector3(20.5, 0.0, 14.5)
		p.turn_rate = deg_to_rad(120.0)
		p.look = PI
		p.rotation.y = p.look
		var note: Dictionary = {}
		_draw(p, note, 0.0)
		var delta: float = 1.0 / float(fps)
		var think_left: float = 0.0
		var glides: int = 0
		var moving_ticks: int = 0
		var turning_ticks: int = 0
		var rng_before: int = game.rng.state
		for _tick: int in range(fps * 10):
			var before: Vector3 = p.global_position
			var pushed: Vector3 = p.visual_push
			var look: float = p.look
			game.clock.advance(delta)
			think_left -= delta
			if think_left <= 0.0:
				think_left += FieldAi.THINK
				game.ai._keep_formation(p)
			game._turn_people(delta)
			game._move_person(p, delta)
			game._update_ground_gait(p, delta)
			p.refresh_view(false)
			glides += _standing_glide(p, note, delta, before, pushed)
			moving_ticks += int(p.moving)
			if not p.moving and absf(angle_difference(look, p.look)) > 0.000001:
				turning_ticks += 1
		assert_gt(moving_ticks, fps)
		assert_gt(turning_ticks, 0)
		assert_eq(glides, 0)
		assert_false(p.moving)
		assert_true(p.path.is_empty())
		var slot: Vector3 = p.brain["follow_slot"]
		assert_lte(p.position.distance_to(slot), FieldAi.FOLLOW_SETTLE + 0.00001)
		assert_eq(game.rng.state, rng_before)
