extends "res://addons/gut/test.gd"
## Decision 486: moving slots, a steady pace, and a queue without moving bodies by hand.

const FieldGame = preload("res://game/field_game.gd")
const FieldAi = preload("res://game/field_ai.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")

class CountingGame:
	extends FieldGame
	var path_calls: int = 0

	func find_path(from: Vector3, to: Vector3, for_dead: bool = false) -> PackedVector3Array:
		path_calls += 1
		return super.find_path(from, to, for_dead)


var game
var mates: Dictionary = {}


func _start() -> void:
	game = CountingGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	game.mask_on = false
	# Decision 486: a small empty floor keeps these geometry checks independent of map contents.
	game.grid = FieldGrid.new(40, 40)
	game.levels = {0: game.grid}
	game.grid.refresh_paths()
	game.player.position = Vector3(20.5, 0, 20.5)
	game.player.facing = PI * 0.5
	game.player.stop()
	game.player.running = false
	mates = {}
	for q in game.squad:
		if q == game.player:
			continue
		q.stop()
		q.brain.clear()
		q.command = "follow"
		q.running = false
		mates[game.ai._role(q)] = q
	for i in range(3):
		mates[["point", "side", "rear"][i]].position = Vector3(5.5, 0, 8.5 + i * 3.0)


func test_moving_point_has_a_separate_slot_and_keeps_a_path_ahead() -> void:
	_start()
	var p = mates["point"]
	var before_rng: int = game.rng.state
	for angle in [0.0, PI * 0.5, PI, -PI * 0.5]:
		game.player.facing = angle
		game.player.moving = true
		var fwd := Vector3(sin(angle), 0, cos(angle))
		var right := Vector3(fwd.z, 0, -fwd.x)
		game.ai._keep_formation(p)
		var slot: Vector3 = p.brain["follow_slot"]
		var offset: Vector3 = slot - game.player.position
		assert_gte(absf(offset.dot(right)), 1.5)
		assert_gt(offset.dot(fwd), 0.0, "the point still goes ahead (406)")
		assert_between(offset.length(), 2.0, 4.0)
		p.position = slot
		p.stop()
		var before: Vector3 = p.position
		game.ai._keep_formation(p)
		assert_false(p.path.is_empty(), "reaching the slot while the chief walks is not a stop")
		assert_gt((p.brain["dest"] - slot).dot(fwd), 0.0, "the steering goal leads the slot")
		assert_eq(p.position, before, "only the motion system moves a body")
	assert_eq(game.rng.state, before_rng)
	game.player.moving = false
	game.ai._keep_formation(p)
	p.position = p.brain["follow_slot"]
	game.ai._keep_formation(p)
	assert_true(p.path.is_empty(), "the chief stopped: settle at the idle slot")
	assert_between(p.position.distance_to(game.player.position), 1.5, 2.5)


func test_follow_running_keeps_its_state_between_three_and_four_metres() -> void:
	_start()
	var p = mates["point"]
	game.player.moving = true
	var goal: Vector3 = game.player.position + Vector3(5.0, 0, -2.0)
	# Decision 486: isolate the pace latch from a lead that changes with current speed.
	p.brain["follow_running"] = false
	for gap in [3.0, 4.0, 3.1, 3.9]:
		p.position = goal - Vector3.RIGHT * gap
		game.ai._follow_walk(p, PackedVector3Array([goal]))
		assert_false(p.running, "walking stays walking in the band")
	p.position = goal - Vector3.RIGHT * 4.6
	game.ai._follow_walk(p, PackedVector3Array([goal]))
	assert_true(p.running, "catch up beyond the outer threshold")
	for gap in [4.0, 3.0, 3.9, 3.1]:
		p.position = goal - Vector3.RIGHT * gap
		game.ai._follow_walk(p, PackedVector3Array([goal]))
		assert_true(p.running, "running stays running in the same band")
	p.position = goal - Vector3.RIGHT * 2.4
	game.ai._follow_walk(p, PackedVector3Array([goal]))
	assert_false(p.running, "walk again only inside the inner threshold")
	game.player.running = true
	game.ai._follow_walk(p, PackedVector3Array([goal]))
	assert_true(p.running, "the chief's run still wins")


func test_idle_watch_stays_outside_the_camera_cone_after_the_sweep() -> void:
	_start()
	var p = mates["rear"]
	var before_rng: int = game.rng.state
	for camera_way in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		game.camera.global_position = p.global_position + camera_way * 20.0 + Vector3.UP * 50.0
		for time in [0.0, 1.5, 3.0, 6.0, 12.0]:
			game.clock.elapsed = time
			for role in ["point", "side", "rear", "aside"]:
				game.ai._look_out(p, role, Vector3.RIGHT, Vector3.FORWARD)
				var target: float = float(p.brain["watch_" + role]["target"])
				var gaze := Vector3(sin(target), 0.0, cos(target))
				assert_lte(gaze.normalized().dot(camera_way), 0.50001, "at least 60 degrees from the camera")
	game.camera.global_position = p.global_position + Vector3.UP * 50.0
	assert_true(game.ai._look_out(p, "rear", Vector3.RIGHT, Vector3.FORWARD).is_finite())
	assert_eq(game.rng.state, before_rng)


func test_door_trail_uses_arc_gap_wait_hysteresis_and_five_metres_to_release() -> void:
	_start()
	var p = mates["point"]
	var door := Vector2i(19, 20)
	game.grid.set_solid(door, FieldGrid.Solid.DOOR)
	game.grid.doors[door] = {"state": "open", "planks": [0, 0]}
	game.grid.refresh_paths()
	var before_rng: int = game.rng.state
	game.player.moving = true
	for i in range(8):
		game.player.position = Vector3(8.5 + i * 0.1, 0, 20.5)
		game.ai._record_follow()
	assert_gte(game.ai._follow_count, 2, "sub-step distances accumulate across updates")
	assert_almost_eq(game.ai._follow_trail[0].distance_to(game.ai._follow_trail[1]), 0.6, 0.0001)
	for i in range(FieldAi.FOLLOW_TRAIL_CAP + 5):
		var along := 20 - absi(20 - i % 40)
		game.player.position = Vector3(8.5 + float(along) * 0.6, 0, 20.5)
		game.ai._record_follow()
	# Decision 486: finish with a real short crossing after exercising the ring's bound.
	for i in range(21):
		game.player.position = Vector3(8.5 + i * 0.6, 0, 20.5)
		game.ai._record_follow()
	p.position = game.player.position - Vector3.RIGHT * 2.5
	game.ai._keep_formation(p)
	assert_true(p.brain["follow_queue"])
	assert_lt((p.brain["dest"] - game.player.position).x, 0.0, "the point joins behind the chief")
	assert_false(p.path.is_empty())
	assert_eq(game.ai._follow_trail.size(), FieldAi.FOLLOW_TRAIL_CAP)
	assert_lte(game.ai._follow_count, FieldAi.FOLLOW_TRAIL_CAP)
	p.position = game.player.position - Vector3.RIGHT * 0.8
	game.player.moving = false
	game.ai._keep_formation(p)
	assert_true(p.path.is_empty(), "a stopped predecessor within 0.9 m: wait")
	p.position = game.player.position - Vector3.RIGHT * 1.2
	game.ai._keep_formation(p)
	assert_true(p.path.is_empty(), "stay waiting in the hysteresis band")
	p.position = game.player.position - Vector3.RIGHT * 1.5
	game.ai._keep_formation(p)
	assert_false(p.path.is_empty(), "resume only beyond 1.45 m")
	p.position = game.player.position - Vector3.RIGHT * 2.5
	for i in range(6):
		game.ai._keep_formation(p)
	assert_true(p.brain["follow_queue"], "standing near a recent door does not age it out")
	game.player.position += Vector3.RIGHT * 5.1
	game.ai._record_follow()
	game.ai._keep_formation(p)
	assert_false(p.brain["follow_queue"], "five metres of travel releases an open exit")
	# Decision 486: a hairpin's chord is short, but its trail still leaves room to walk.
	game.ai = FieldAi.new(game)
	for at in [Vector3(18.5, 0, 20.5), Vector3(20.5, 0, 20.5), Vector3(20.5, 0, 21.3), Vector3(18.5, 0, 21.3)]:
		game.player.position = at
		game.ai._record_follow()
	p.position = Vector3(18.5, 0, 20.5)
	assert_lt(p.position.distance_to(game.player.position), FieldAi.FOLLOW_QUEUE_WAIT)
	assert_false(game.ai._follow_wait(p, game.player), "do not stop across a bend's short chord")
	assert_eq(game.rng.state, before_rng)


func test_two_cell_corridor_is_narrow_but_three_cells_are_not() -> void:
	_start()
	game.player.position = Vector3(20.5, 0, 20.5)
	for x in range(12, 29):
		game.grid.set_solid(Vector2i(x, 19), FieldGrid.Solid.WALL)
		game.grid.set_solid(Vector2i(x, 22), FieldGrid.Solid.WALL)
	game.grid.refresh_paths()
	assert_true(game.ai._follow_narrow(Vector3.RIGHT))
	mates["point"].position = Vector3(18.5, 0, 20.5)
	mates["side"].position = Vector3(16.5, 0, 20.5)
	mates["rear"].position = Vector3(14.5, 0, 20.5)
	game.player.moving = true
	game.ai._keep_formation(mates["side"])
	assert_true(mates["side"].brain["follow_queue"])
	assert_false(mates["side"].path.is_empty())
	for x in range(12, 29):
		game.grid.set_solid(Vector2i(x, 22), FieldGrid.Solid.NONE)
		game.grid.set_solid(Vector2i(x, 23), FieldGrid.Solid.WALL)
	game.grid.refresh_paths()
	assert_false(game.ai._follow_narrow(Vector3.RIGHT))


func test_slots_avoid_current_bodies_and_prior_role_slots_in_any_think_order() -> void:
	_start()
	var point = mates["point"]
	var side = mates["side"]
	side.position = game.player.position + Vector3(1.6, 0, -1.2)
	var slots: Array[Vector3] = []
	for role in ["rear", "side", "point"]:
		var p = mates[role]
		var before: Vector3 = p.position
		game.ai._keep_formation(p)
		var slot: Vector3 = p.brain["follow_slot"]
		assert_true(slot.is_finite())
		assert_between(slot.distance_to(game.player.position), 1.5, 2.5)
		for q in mates.values():
			if q != p:
				assert_gt(slot.distance_to(q.position), 0.9)
		for prior in slots:
			assert_gt(slot.distance_to(prior), 0.9)
		slots.append(slot)
		assert_eq(p.position, before)
	assert_gt(point.brain["follow_slot"].distance_to(side.position), 0.9)
	# Decision 486: returning from door duty must not cross another body to recover role order.
	var rear = mates["rear"]
	point.position = game.player.position - Vector3.RIGHT * 2.0
	rear.position = game.player.position - Vector3.RIGHT * 3.5
	side.position = game.player.position - Vector3.RIGHT * 5.0
	var positions := [point.position, rear.position, side.position]
	game.ai.held_door = {"cell": FieldGrid.cell_of(game.player.position), "out": Vector3.LEFT, "building": 0}
	assert_eq(game.ai._follow_queue_mates(game.ai._follow_mates()), [point, side])
	game.ai.held_door = {}
	assert_eq(game.ai._follow_queue_mates(game.ai._follow_mates()), [point, rear, side])
	assert_eq([point.position, rear.position, side.position], positions)


func test_one_wall_on_the_way_to_a_slot_uses_one_path_search_without_queueing() -> void:
	_start()
	var p = mates["side"]
	var fwd := Vector3.RIGHT
	var right := Vector3.FORWARD
	var slot: Vector3 = game.ai._follow_spot(p, game.ai._follow_mates(), fwd, right)
	p.position = slot - fwd * 4.0
	game.grid.set_solid(FieldGrid.cell_of(slot - fwd * 2.0), FieldGrid.Solid.WALL)
	game.grid.refresh_paths()
	game.path_calls = 0
	var before_rng: int = game.rng.state
	assert_false(game.ai._follow_clear(p.position, slot))
	assert_false(game.ai._follow_narrow(fwd))
	game.ai._keep_formation(p)
	assert_false(p.brain["follow_queue"], "one blocked sight line is not a narrow lane")
	assert_eq(game.path_calls, 1, "only one detour search in this think")
	assert_gt(p.path.size(), 1)
	assert_eq(p.path[-1], slot)
	assert_eq(game.rng.state, before_rng)
	for tick in range(180):
		game._turn_people(1.0 / 30.0)
		game._move_person(p, 1.0 / 30.0)
	assert_lte(p.position.distance_to(slot), FieldAi.FOLLOW_SETTLE, "decision 442 settles within the existing arrival allowance")
	assert_false(p.moving, "the chief is still: the detour finishes at the slot")


func test_straight_walk_keeps_moving_between_thinks_and_settles_when_the_chief_stops() -> void:
	_start()
	game.player.position = Vector3(8.5, 0, 20.5)
	game.player.go_to(PackedVector3Array([Vector3(30.5, 0, 20.5)]))
	game.player.moving = true
	for role in ["point", "side", "rear"]:
		var p = mates[role]
		p.position = game.ai._follow_spot(p, game.ai._follow_mates(), Vector3.RIGHT, Vector3.FORWARD)
		p.facing = PI * 0.5
		game.ai._keep_formation(p)
	var think_left := FieldAi.THINK
	for tick in range(120):
		game._turn_people(1.0 / 30.0)
		game._move_person(game.player, 1.0 / 30.0)
		for p in mates.values():
			game._move_person(p, 1.0 / 30.0)
			assert_true(p.moving, "the real movement loop must not exhaust a walking path")
		game.ai._record_follow()
		think_left -= 1.0 / 30.0
		if think_left <= 0.0:
			think_left += FieldAi.THINK
			for p in mates.values():
				game.path_calls = 0
				game.ai._keep_formation(p)
				assert_lte(game.path_calls, 1)
	game.player.stop()
	for p in mates.values():
		game.ai._keep_formation(p)
	for tick in range(180):
		game._turn_people(1.0 / 30.0)
		for p in mates.values():
			game._move_person(p, 1.0 / 30.0)
	for p in mates.values():
		assert_false(p.moving)
		assert_true(p.path.is_empty())
		assert_lte(p.position.distance_to(p.brain["follow_slot"]), FieldAi.FOLLOW_SETTLE)


## Decision 486: a save written before these fields (no `_follow_*` on the AI, no `follow_*` in a
## brain) resumes without errors, the trail starts afresh, and the point picks a slot again.
func test_a_save_without_the_follow_fields_resumes_and_follows_again() -> void:
	# A whole map both times (the small floor of _start does not round-trip through a save).
	var first = _field()
	first.player.moving = true
	for q in first.squad:
		if q != first.player:
			q.command = "follow"
			first.ai._keep_formation(q)
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(first)))
	var ai: Dictionary = saved["runtime"]["components"]["ai"]
	for key in ai.keys():
		if String(key).begins_with("_follow"):
			ai.erase(key)
	for row: Dictionary in saved["people"]:
		var state: Dictionary = row.get("state", {})
		var brain: Dictionary = state.get("brain", {})
		for key in brain.keys():
			if String(key).begins_with("follow_"):
				brain.erase(key)
	var resumed = _field(FieldSave.resume_opts(saved))
	assert_eq(resumed.ai._follow_count, 0, "an old save starts the trail afresh")
	resumed.player.moving = true
	var picked: int = 0
	for q in resumed.squad:
		if q == resumed.player or q.command != "follow" or resumed.ai._role(q) != "point":
			continue
		resumed.ai._keep_formation(q)
		var slot: Variant = q.brain.get("follow_slot")
		assert_true(slot is Vector3 and (slot as Vector3).is_finite(), "the point picks a slot again")
		picked += 1
	assert_eq(picked, 1)


func _field(extra: Dictionary = {}):
	var g = FieldGame.new()
	g.opts = {"seed": 11, "raiders": false, "auto_pause": false, "arrive": false}
	g.opts.merge(extra, true)
	g.map_script = BareLine
	add_child_autofree(g)
	g.set_process(false)
	return g
