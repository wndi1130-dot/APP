extends "res://addons/gut/test.gd"
## Decision 486: moving slots, a steady pace, and a queue without moving bodies by hand.

const FieldGame = preload("res://game/field_game.gd")
const FieldAi = preload("res://game/field_ai.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")
const MoveRules = preload("res://game/sim/move_rules.gd")
const Person = preload("res://game/actors/person.gd")

class CountingAi:
	extends FieldAi
	var narrow_calls: int = 0
	var queue_calls: int = 0
	var axis_calls: int = 0
	var queue_path_calls: int = 0

	func _init(field_game) -> void:
		super(field_game)

	func _follow_narrow(fwd: Vector3) -> bool:
		narrow_calls += 1
		return super._follow_narrow(fwd)

	func _follow_queue_mates(eligible: Array) -> Array:
		queue_calls += 1
		return super._follow_queue_mates(eligible)

	func _refresh_follow_axis() -> void:
		axis_calls += 1
		super._refresh_follow_axis()

	func _follow_queue_path(p, gap: float, fwd: Vector3) -> PackedVector3Array:
		queue_path_calls += 1
		return super._follow_queue_path(p, gap, fwd)

## Decision 486: frozen 52c5501d walk body, independent of the R5 pace selector.
class R4WalkAi:
	extends FieldAi

	func _init(field_game) -> void:
		super(field_game)

	func _follow_walk(p, route: PackedVector3Array, leader = null, fwd: Vector3 = Vector3.ZERO, _run_gap: float = -1.0) -> void:
		while not route.is_empty() and p.position.distance_to(route[0]) < 0.12:
			route.remove_at(0)
		if route.is_empty():
			p.brain.erase("follow_walk_t")
			p.stop()
			return
		var goal: Vector3 = route[-1]
		var gap: float = p.position.distance_to(goal)
		var run: bool = p.brain.get("follow_running", false)
		if gap > FOLLOW_RUN_ON:
			run = true
		elif gap < FOLLOW_RUN_OFF:
			run = false
		p.running = game.player.running or run
		if leader != null and _follow_going(leader) and gap < FOLLOW_RUN_OFF:
			var leader_speed: float = leader.speed(game.grid_at(leader.position).floor_at(FieldGrid.cell_of(leader.position)))
			var was_running: bool = p.running
			p.running = false
			var own_speed: float = p.speed(game.grid_at(p.position).floor_at(FieldGrid.cell_of(p.position)))
			p.running = was_running
			if own_speed >= leader_speed - FOLLOW_EPS:
				p.running = false
				run = false
		p.brain["follow_running"] = run
		if leader == null and game.player.moving and fwd != Vector3.ZERO:
			route = _follow_buffer(p, route, fwd)
		p.brain["dest"] = route[-1]
		p.brain["follow_walk_t"] = game.clock.elapsed
		p.go_to(route, p.running)

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
	game.ai = CountingAi.new(game)
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
		q.brain["follow_t"] = game.clock.elapsed
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
		game.camera.look_at(p.global_position, Vector3.UP)
		for time in [0.0, 1.5, 3.0, 6.0, 12.0]:
			game.clock.elapsed = time
			for role in ["point", "side", "rear", "aside"]:
				var gaze: Vector3 = game.ai._look_out(p, role, Vector3.RIGHT, Vector3.FORWARD)
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
	game.ai._refresh_follow_queue()
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
	game.ai._refresh_follow_queue()
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
	game.ai._refresh_follow_queue()
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
	assert_lte(p.position.distance_to(slot), FieldAi.FOLLOW_PATH_NEAR)
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


## Decision 486: controlled movement uses real turns and paths, with staggered follow thinks.
func _follow_tick(delta: float) -> Dictionary:
	game.clock.elapsed += delta
	game._turn_people(delta)
	game._move_person(game.player, delta)
	var moved: Dictionary = {}
	for p in mates.values():
		game._move_person(p, delta)
		moved[p.pid] = {"moving": p.moving, "has_path": not p.path.is_empty()}
	game.ai._chief_still = 0.0 if game.player.moving else game.ai._chief_still + delta
	game.ai._record_follow()
	game.ai.think_t -= delta
	if game.ai.think_t <= 0.0:
		game.ai.think_t += FieldAi.THINK
		game.ai._refresh_follow_axis()
		game.ai._refresh_follow_queue()
	for p in mates.values():
		p.brain["think_t"] = float(p.brain.get("think_t", 0.0)) - delta
		if float(p.brain["think_t"]) <= 0.0:
			p.brain["think_t"] += FieldAi.THINK
			game.ai._keep_formation(p)
	return moved


func _queue_scene(run: bool = false) -> void:
	_start()
	for x in range(1, 39):
		game.grid.set_solid(Vector2i(x, 19), FieldGrid.Solid.WALL)
		game.grid.set_solid(Vector2i(x, 22), FieldGrid.Solid.WALL)
	game.grid.refresh_paths()
	for p in game.squad:
		p.body = Person.BodyState.new()
		p.items.clear()
		p.hands.clear()
		p.worn = Person.Wear.outfit(Person.Wear.DEFAULT)
		p.heat.heat = 100.0
		p.heat.wet = 0.0
		p.hunger_level = 0
		p.sore_level = 0
		p.panic = 0.0
		p.facing = PI * 0.5
		p.look = p.facing
		p.turn_rate = deg_to_rad(400.0)
		p.running = run
	for i in range(21):
		game.player.position = Vector3(2.5 + float(i) * 0.6, 0, 20.5)
		game.ai._record_follow()
	game.player.go_to(PackedVector3Array([Vector3(37.5, 0, 20.5)]), run)
	game.player.moving = true
	var speed: float = game.player.speed(game.grid.floor_at(FieldGrid.cell_of(game.player.position)))
	var gap: float = FieldAi.FOLLOW_QUEUE_GAP + speed * FieldAi.FOLLOW_QUEUE_GAP_S + 0.3
	for i in range(3):
		var p = mates[["point", "side", "rear"][i]]
		p.position = game.player.position - Vector3.RIGHT * gap * float(i + 1)
		p.brain["think_t"] = FieldAi.THINK * float(i) / 3.0
		assert_almost_eq(p.speed(game.grid.floor_at(FieldGrid.cell_of(p.position))), speed, 0.00001)
	game.ai._refresh_follow_queue()
	for p in mates.values():
		game.ai._keep_formation(p)


func test_queue_resume_never_walks_back() -> void:
	_queue_scene()
	var p = mates["point"]
	p.position = game.player.position - Vector3.RIGHT * 0.85
	p.stop()
	var start: Vector3 = p.position
	var rng_before: int = game.rng.state
	game.ai._keep_formation(p)
	assert_true(p.path.is_empty(), "wait for the moving gap instead of reversing")
	var turn_stops: int = 0
	var backsteps: float = 0.0
	for tick in range(30):
		# Decision 486: remove the chief's advance from back-distance before checking reversal.
		var progress: float = game.ai._follow_distance - float(game.ai._follow_projection(p.position)["back"])
		var moved: Dictionary = _follow_tick(1.0 / 30.0)
		var next_progress: float = game.ai._follow_distance - float(game.ai._follow_projection(p.position)["back"])
		backsteps += maxf(0.0, progress - next_progress)
		if bool(moved[p.pid]["has_path"]) and not bool(moved[p.pid]["moving"]):
			turn_stops += 1
		for target: Vector3 in p.path:
			assert_gte(target.x + 0.05, p.position.x, "all restart targets stay ahead")
	assert_lte(backsteps, 0.05)
	assert_gt(p.position.x, start.x, "the queue resumes within one second")
	assert_eq(turn_stops, 0)
	assert_eq(game.rng.state, rng_before)


func test_queue_route_keeps_slack_at_equal_speed() -> void:
	for run: bool in [false, true]:
		_queue_scene(run)
		var changes: Array[int] = [0, 0, 0]
		var empty_frames: Array[int] = [0, 0, 0]
		var previous: Array[bool] = [false, false, false]
		for tick in range(120):
			_follow_tick(1.0 / 30.0)
			for i in range(3):
				var p = mates[["point", "side", "rear"][i]]
				if tick >= 30:
					if p.moving != previous[i]:
						changes[i] += 1
					if p.path.is_empty():
						empty_frames[i] += 1
				previous[i] = p.moving
		assert_eq(changes, [0, 0, 0], "equal pace stays continuous after warmup")
		assert_eq(empty_frames, [0, 0, 0], "the line retains slack between staggered thinks")


func test_queue_gap_band_keeps_forward_walk_and_waits_across_thinks() -> void:
	_queue_scene(true)
	var leader = mates["point"]
	var p = mates["side"]
	p.position = leader.position - Vector3.RIGHT * 1.2
	p.brain["follow_running"] = true
	game.ai._keep_formation(p)
	assert_false(p.path.is_empty(), "a moving follower keeps walking inside the gap band")
	assert_false(p.running, "the band stays at a walk even when the chief runs")
	assert_false(bool(p.brain["follow_running"]))
	assert_false(p.brain.has("follow_gap_waiting"))
	for target: Vector3 in p.path:
		assert_gte(target.x, p.position.x, "band targets never go behind the body")
	assert_gte(p.path[-1].distance_to(leader.position), FieldAi.FOLLOW_QUEUE_WAIT - FieldAi.FOLLOW_EPS)
	p.position = leader.position - Vector3.RIGHT * 1.0
	game.ai._keep_formation(p)
	assert_true(p.path.is_empty())
	assert_true(bool(p.brain["follow_gap_waiting"]))
	game.clock.elapsed += FieldAi.THINK
	leader.brain["follow_t"] = game.clock.elapsed
	p.position = leader.position - Vector3.RIGHT * 1.2
	game.ai._keep_formation(p)
	assert_true(p.path.is_empty(), "a stopped follower does not restart inside the band")
	assert_true(bool(p.brain["follow_gap_waiting"]))
	game.clock.elapsed += FieldAi.THINK
	leader.brain["follow_t"] = game.clock.elapsed
	p.position = leader.position - Vector3.RIGHT * 2.1
	game.ai._keep_formation(p)
	assert_false(p.path.is_empty(), "the full running gap is open again")
	assert_false(p.brain.has("follow_gap_waiting"))
	for target: Vector3 in p.path:
		assert_gte(target.x, p.position.x)


func test_queue_gap_band_limits_changes_after_leader_turn() -> void:
	_queue_scene()
	for tick in range(30):
		_follow_tick(1.0 / 30.0)
	var leader = mates["point"]
	var p = mates["side"]
	assert_true(p.moving)
	# Decision 486: 180 degrees at 400 deg/s gives six still frames (0.2 s) before 90 degrees.
	leader.look = -PI * 0.5
	leader.facing = PI * 0.5
	var previous: bool = p.moving
	var changes: int = 0
	var turn_frames: int = 0
	var start: Vector3 = p.position
	for tick in range(120):
		var moved: Dictionary = _follow_tick(1.0 / 30.0)
		if bool(moved[leader.pid]["has_path"]) and not bool(moved[leader.pid]["moving"]):
			turn_frames += 1
		if p.moving != previous:
			changes += 1
		previous = p.moving
	assert_eq(turn_frames, 6, "the predecessor turns in place for 0.2 s with a live route")
	# Decision 486: allow one stop/restart pair for the turn, never repeated gap chatter in 4 s.
	assert_lte(changes, 2)
	assert_gt(p.position.x, start.x + 6.0, "holding forever cannot satisfy the change bound")


func test_queue_gap_band_limits_changes_with_slower_leader() -> void:
	_queue_scene()
	for tick in range(30):
		_follow_tick(1.0 / 30.0)
	var leader = mates["point"]
	var p = mates["side"]
	leader.heat.heat = 0.0
	assert_almost_eq(float(leader.mults()["move"]), 0.95, 0.00001)
	var floor_kind: int = game.grid.floor_at(FieldGrid.cell_of(p.position))
	assert_almost_eq(leader.speed(floor_kind), p.speed(floor_kind) * 0.95, 0.00001)
	assert_true(p.moving)
	var previous: bool = p.moving
	var changes: int = 0
	var start: Vector3 = p.position
	for tick in range(120):
		_follow_tick(1.0 / 30.0)
		if p.moving != previous:
			changes += 1
		previous = p.moving
	# Decision 486: 5% of 2.1 m/s closes 0.42 m in 4 s; allow at most one stop/restart pair.
	assert_lte(changes, 2)
	assert_gt(p.position.x, start.x + 6.0)


func test_queue_runs_to_catch_walking_leader_six_metres_ahead() -> void:
	_queue_scene()
	var p = mates["point"]
	p.position = game.player.position - Vector3.RIGHT * 6.0
	game.ai._keep_formation(p)
	assert_false(game.player.running)
	assert_false(p.path.is_empty())
	assert_gt(p.position.distance_to(p.path[-1]), FieldAi.FOLLOW_RUN_ON)
	assert_true(p.running, "walking pace must not veto a distant catch-up run")
	assert_true(bool(p.brain["follow_running"]))


func test_queue_near_follower_runs_with_slow_running_chief() -> void:
	_queue_scene(true)
	game.player.bag = "pack"
	game.player.skills["strength"] = 5
	game.player.items["food_pack"] = 5
	assert_eq(game.player.carry_state(), 1)
	assert_almost_eq(float(game.player.mults()["move"]), 0.9, 0.00001)
	var p = mates["point"]
	p.position = game.player.position - Vector3.RIGHT * 2.2
	game.ai._keep_formation(p)
	assert_false(p.path.is_empty())
	assert_lt(p.position.distance_to(p.path[-1]), FieldAi.FOLLOW_RUN_OFF)
	assert_true(p.running, "walking cannot match the chief's 0.9-speed run")
	assert_true(game.player.running)


func test_queue_vetoes_running_only_near_a_walkable_pace() -> void:
	_queue_scene()
	var leader = mates["point"]
	var p = mates["side"]
	game.player.running = true
	game.ai._follow_walk(p, PackedVector3Array([p.position + Vector3.RIGHT * (FieldAi.FOLLOW_RUN_OFF - 0.1)]), leader)
	assert_false(p.running, "walking already matches a nearby walking predecessor")
	game.ai._follow_walk(p, PackedVector3Array([p.position + Vector3.RIGHT * FieldAi.FOLLOW_RUN_OFF]), leader)
	assert_true(p.running, "the near-speed veto is strictly below RUN_OFF")


func test_leader_turn_is_not_a_stop() -> void:
	_queue_scene()
	var leader = mates["point"]
	var p = mates["side"]
	p.position = leader.position - Vector3.RIGHT * 0.85
	leader.path = PackedVector3Array([leader.position + Vector3.RIGHT * 2.0])
	leader.moving = false
	assert_false(game.ai._follow_wait(p, leader), "a turning predecessor still has a live path")
	assert_eq(float(p.brain["follow_lead_still"]), 0.0)
	leader.stop()
	assert_false(game.ai._follow_wait(p, leader), "one think is shorter than the still delay")
	assert_true(game.ai._follow_wait(p, leader), "a real stop enters the existing 0.9 m wait")
	p.position = leader.position - Vector3.RIGHT * 1.2
	assert_true(game.ai._follow_wait(p, leader))
	p.position = leader.position - Vector3.RIGHT * 1.5
	assert_false(game.ai._follow_wait(p, leader))
	game.player.stop()
	game.player.drive_speed = 1.0
	assert_true(game.ai._follow_going(game.player), "stick motion is also going")


func test_queue_holds_through_corner() -> void:
	_queue_scene()
	for x in range(40):
		for z in range(40):
			var open: bool = (x >= 1 and x <= 23 and z in [20, 21]) or (x in [22, 23] and z >= 20 and z <= 35)
			game.grid.set_solid(Vector2i(x, z), FieldGrid.Solid.NONE if open else FieldGrid.Solid.WALL)
	game.grid.refresh_paths()
	game.player.go_to(PackedVector3Array([Vector3(22.5, 0, 20.5), Vector3(22.5, 0, 34.5)]))
	var order: Array = game.ai._follow_order.duplicate()
	var max_away: float = 0.0
	for tick in range(240):
		_follow_tick(1.0 / 30.0)
		assert_true(game.ai._follow_queue_on)
		assert_eq(game.ai._follow_order, order)
		for p in mates.values():
			max_away = maxf(max_away, float(game.ai._follow_projection(p.position)["away"]))
	assert_gt(game.player.position.z, 22.5, "the chief has turned the corner")
	assert_lte(max_away, 0.8, "the line stays near the trail around the bend")
	# Decision 486: test the exact release distance on open ground after the narrow sample.
	game.grid = FieldGrid.new(40, 40)
	game.levels = {0: game.grid}
	game.grid.refresh_paths()
	game.ai._follow_distance = game.ai._follow_narrow_at + 3.99
	game.ai._refresh_follow_queue()
	assert_true(game.ai._follow_queue_on)
	assert_eq(game.ai._follow_order, order)
	game.ai._follow_distance = game.ai._follow_narrow_at + 4.0
	for p in mates.values():
		p.brain["follow_lead_still"] = 0.5
		p.brain["follow_gap_waiting"] = true
	game.ai._refresh_follow_queue()
	assert_false(game.ai._follow_queue_on)
	assert_true(game.ai._follow_order.is_empty())
	for p in mates.values():
		assert_false(p.brain.has("follow_waiting"))
		assert_false(p.brain.has("follow_lead_still"))
		assert_false(p.brain.has("follow_gap_waiting"))


func test_queue_mode_same_for_all_mates() -> void:
	_queue_scene()
	var ai = game.ai as CountingAi
	var narrow_before: int = ai.narrow_calls
	var order_before: int = ai.queue_calls
	var order: Array = ai._follow_order.duplicate()
	game.player.facing = 0.0
	for role in ["rear", "point", "side"]:
		game.clock.elapsed += 0.05
		ai._keep_formation(mates[role])
		assert_true(mates[role].brain["follow_queue"])
	assert_eq(ai.narrow_calls, narrow_before, "individual thinks never inspect the narrow cell")
	assert_eq(ai.queue_calls, order_before, "individual thinks never reorder the line")
	assert_eq(ai._follow_order, order)
	ai.think_t = 0.0
	ai.update(0.01)
	assert_eq(ai.narrow_calls, narrow_before + 1, "one common think performs one inspection")
	assert_eq(ai.queue_calls, order_before + 1, "one common think updates order once")
	ai.update(0.01)
	assert_eq(ai.narrow_calls, narrow_before + 1)
	assert_eq(ai.queue_calls, order_before + 1)


func test_queue_skips_busy_mate() -> void:
	_queue_scene()
	var busy = mates["point"]
	var p = mates["side"]
	busy.stop()
	busy.action = "search"
	assert_eq(game.ai._follow_leader(p), game.player, "skip work even before the common refresh")
	game.ai._refresh_follow_queue()
	assert_false(game.ai._follow_order.has(busy))
	assert_false(game.ai._follow_mates().has(busy))
	game.ai._keep_formation(p)
	assert_false(p.path.is_empty())
	assert_false(bool(p.brain.get("follow_waiting", false)))
	assert_gt(p.path[-1].x, busy.position.x)
	busy.cancel_action()
	busy.brain["follow_t"] = game.clock.elapsed - FieldAi.THINK * 2.0
	assert_false(game.ai._follow_mates().has(busy), "a stale combat or work path is not a follow candidate")


func test_new_queue_follower_uses_nearest_active_body_ahead() -> void:
	_queue_scene()
	var p = mates["rear"]
	game.ai._follow_order.erase(p)
	p.brain.erase("follow_t")
	assert_eq(game.ai._follow_leader(p), mates["side"], "the missing order entry still has a body ahead")
	mates["side"].action = "search"
	assert_eq(game.ai._follow_leader(p), mates["point"], "busy bodies cannot lead the new follower")
	mates["point"].brain["follow_t"] = game.clock.elapsed - FieldAi.THINK * 2.0
	assert_eq(game.ai._follow_leader(p), game.player, "no active body ahead means the chief")
	mates["side"].action = ""
	mates["point"].brain["follow_t"] = game.clock.elapsed
	p.position = game.player.position - Vector3.RIGHT * 0.5
	assert_eq(game.ai._follow_leader(p), game.player, "active bodies behind are not predecessors")


func test_narrow_queue_survives_two_seconds_of_chief_stillness() -> void:
	_queue_scene()
	game.player.stop()
	for tick in range(60):
		_follow_tick(1.0 / 30.0)
		assert_true(game.ai._follow_queue_on, "standing inside the corridor must keep the line")
	assert_gte(game.ai._chief_still, 2.0 - FieldAi.FOLLOW_EPS)
	assert_true(game.ai._follow_narrow(Vector3.RIGHT))


func test_door_queue_releases_when_chief_still() -> void:
	_start()
	game.ai._follow_door_id = 1
	game.ai._follow_door_at = 0.0
	game.ai._follow_distance = 2.0
	game.player.moving = true
	game.ai._refresh_follow_queue()
	assert_true(game.ai._follow_queue_on)
	game.player.stop()
	game.ai._chief_still = FieldAi.LOOK_STILL_S - 0.01
	game.ai._refresh_follow_queue()
	assert_true(game.ai._follow_queue_on)
	game.ai._chief_still = FieldAi.LOOK_STILL_S
	game.ai._refresh_follow_queue()
	assert_false(game.ai._follow_queue_on)
	game.ai._keep_formation(mates["point"])
	assert_false(mates["point"].brain["follow_queue"])
	assert_between(mates["point"].brain["follow_slot"].distance_to(game.player.position), 1.5, 2.5)


func test_follow_keys_reset_on_return() -> void:
	_start()
	var p = mates["side"]
	p.brain.merge({"follow_running": true, "follow_waiting": true, "follow_queue": true,
		"follow_lead_still": 2.0, "follow_settled": true, "follow_walk_t": 0.0, "follow_gap_waiting": true}, true)
	game.clock.elapsed = 2.0
	p.position = game.player.position + Vector3(0.5, 0, -2.0)
	game.ai._keep_formation(p)
	assert_false(p.running)
	assert_false(bool(p.brain.get("follow_running", false)))
	assert_false(p.brain.has("follow_waiting"))
	assert_false(p.brain.has("follow_lead_still"))
	assert_false(p.brain.has("follow_settled"))
	assert_false(p.brain.has("follow_gap_waiting"))
	# Decision 486: leaving follow clears the marker in the same AI turn.
	p.command = "wait"
	p.brain["think_t"] = 0.0
	game.clock.elapsed += 0.1
	game.ai.update(0.01)
	for key: String in ["follow_t", "follow_walk_t", "follow_running", "follow_waiting", "follow_queue", "follow_lead_still", "follow_gap_waiting"]:
		assert_false(p.brain.has(key))
	p.command = "follow"
	game.ai._keep_formation(p)
	assert_false(p.running)


func _turn_trace(p, enabled: bool, marked: bool, off: float = 120.0) -> Array[Vector3]:
	var origin: Vector3 = Vector3(20.5, 0, 20.5)
	p.position = origin
	p.look = PI * 0.5 - deg_to_rad(off)
	p.facing = p.look
	p.turn_rate = deg_to_rad(400.0)
	p.running = false
	p.brain.erase("face_hold")
	p.brain.erase("face_hold_t")
	p.brain.erase("follow_walk_t")
	if marked:
		p.brain["follow_walk_t"] = game.clock.elapsed
	p.go_to(PackedVector3Array([origin + Vector3.RIGHT * 5.0]))
	game.opts["follow_walk_turn"] = enabled
	var trace: Array[Vector3] = []
	for tick in range(12):
		game._move_person(p, 1.0 / 30.0)
		trace.append(p.position)
		p.turn_tick(1.0 / 30.0)
	return trace


func test_follow_turn_floor_only_followers() -> void:
	_start()
	var p = mates["side"]
	assert_false(bool(game.opts.get("follow_walk_turn", false)))
	var old_trace: Array[Vector3] = _turn_trace(p, false, false)
	assert_eq(_turn_trace(p, false, true), old_trace, "the disabled option preserves the complete old position trace")
	assert_eq(_turn_trace(p, true, false), old_trace, "an unmarked companion keeps the old turn")
	var walking: Array[Vector3] = _turn_trace(p, true, true)
	var speed: float = p.speed(game.grid.floor_at(Vector2i(20, 20)))
	assert_almost_eq(walking[0].x - 20.5, speed * MoveRules.FOLLOW_TURN_FLOOR / 30.0, 0.00001)
	assert_eq(walking[0].z, 20.5, "movement still follows the path, not the shown heading")
	# Decision 486: the floor also covers the positive heading share near 80 degrees.
	var valley_old: Array[Vector3] = _turn_trace(p, false, false, 80.0)
	assert_eq(_turn_trace(p, false, true, 80.0), valley_old, "disabled followers retain the 80-degree trace")
	assert_eq(_turn_trace(p, true, false, 80.0), valley_old, "unmarked followers retain the 80-degree trace")
	var valley_walk: Array[Vector3] = _turn_trace(p, true, true, 80.0)
	var valley_share: float = (valley_walk[0].x - 20.5) * 30.0 / speed
	assert_gte(valley_share, MoveRules.FOLLOW_TURN_FLOOR - 0.0001)
	assert_almost_eq(valley_walk[0].x - 20.5, speed * MoveRules.FOLLOW_TURN_FLOOR / 30.0, 0.00001)
	assert_gt(valley_walk[0].x, valley_old[0].x)
	for team: String in ["crew", "raider"]:
		p.team = team
		assert_eq(_turn_trace(p, true, true), old_trace, "other people ignore even a stale copied marker")
		assert_eq(_turn_trace(p, true, true, 80.0), valley_old, "other people retain the 80-degree trace")
	p.team = "squad"
	assert_eq(_turn_trace(game.player, true, true), _turn_trace(game.player, false, true))
	assert_eq(_turn_trace(game.player, true, true, 80.0), _turn_trace(game.player, false, true, 80.0))
	# Decision 486: keep a full degree of margin from the strict 135-degree boundary.
	assert_eq(_turn_trace(p, true, true, 136.0)[0], Vector3(20.5, 0, 20.5))
	assert_eq(_turn_trace(p, true, true, 180.0)[0], Vector3(20.5, 0, 20.5))
	p.brain["follow_walk_t"] = game.clock.elapsed - 0.5
	assert_false(game._follows(p), "the marker expires at two thinks")
	p.look = -PI * 0.5
	var at: Vector3 = p.position
	game._move_person(p, 0.1)
	assert_eq(p.position, at)
	p.brain["follow_walk_t"] = game.clock.elapsed
	p.action = "search"
	assert_false(game._follows(p))
	p.action = ""
	p.command = "wait"
	assert_false(game._follows(p))


func test_follow_turn_option_preserves_zombie_movement() -> void:
	_start()
	var z: Dictionary = game.zombies.spawn("dead", Vector3(10.5, 0, 10.5))
	z["state"] = "investigate"
	z["target"] = Vector3(18.5, 0, 10.5)
	z["path"] = PackedVector3Array([Vector3(18.5, 0, 10.5)])
	z["turn_t"] = 0.0
	for tick in range(30):
		var before: Dictionary = z.duplicate(true)
		var rng_before: int = game.rng.state
		game.opts["follow_walk_turn"] = false
		game.zombies._move(z, 1.0 / 30.0)
		var expected: Dictionary = z.duplicate(true)
		var expected_rng: int = game.rng.state
		z.clear()
		z.merge(before, true)
		game.rng.state = rng_before
		game.opts["follow_walk_turn"] = true
		game.zombies._move(z, 1.0 / 30.0)
		assert_eq(z, expected, "the zombie mover is independent of this option")
		assert_eq(game.rng.state, expected_rng)


func test_follow_decisions_never_move_bodies_or_draw_game_rng() -> void:
	_queue_scene()
	var before_rng: int = game.rng.state
	var positions: Array[Vector3] = []
	for p in game.squad:
		positions.append(p.position)
	for attempt in range(4):
		game.ai._refresh_follow_queue()
		for p in mates.values():
			game.ai._keep_formation(p)
	for i in range(game.squad.size()):
		assert_eq(game.squad[i].position, positions[i])
	assert_eq(game.rng.state, before_rng)
	var p = mates["point"]
	p.go_to(PackedVector3Array([p.position + Vector3.RIGHT]))
	game.ai._follow_walk(p, PackedVector3Array())
	assert_true(p.path.is_empty(), "a failed search never keeps a stale route")
	assert_false(p.brain.has("follow_walk_t"))


func test_follow_slot_reuse_and_camera_zoom_are_stable() -> void:
	_start()
	var p = mates["side"]
	game.ai._keep_formation(p)
	var slot: Vector3 = p.brain["follow_slot"]
	game.player.position += Vector3.RIGHT * 0.1
	game.ai._keep_formation(p)
	assert_eq(p.brain["follow_slot"], slot + Vector3.RIGHT * 0.1, "a free base slot takes priority over the saved idle slot")
	var gaze: Vector3 = game.ai._look_out(p, "side", Vector3.RIGHT, Vector3.FORWARD)
	game.camera.position += Vector3(100, 30, -70)
	game.camera.size *= 2.0
	assert_eq(game.ai._look_out(p, "side", Vector3.RIGHT, Vector3.FORWARD), gaze, "translation and zoom cannot change a watch")


func test_follow_base_slot_precedes_saved_shift() -> void:
	_start()
	game.player.moving = true
	var p = mates["side"]
	var base: Vector3 = game.ai._follow_spot(p, [p], Vector3.RIGHT, Vector3.FORWARD)
	var blocker = mates["point"]
	var before: Vector3 = blocker.position
	blocker.position = base
	var shifted: Vector3 = game.ai._follow_spot(p, [p], Vector3.RIGHT, Vector3.FORWARD)
	assert_ne(shifted, base)
	assert_eq(game.ai._follow_spot(p, [p], Vector3.RIGHT, Vector3.FORWARD), shifted, "the valid saved shift remains the first alternative")
	blocker.position = before
	assert_eq(game.ai._follow_spot(p, [p], Vector3.RIGHT, Vector3.FORWARD), base, "a free base slot replaces the saved shift")


func test_follow_fallback_returns_to_base_slot_next_think() -> void:
	_start()
	game.player.moving = true
	var p = mates["side"]
	var base: Vector3 = game.ai._follow_spot(p, [p], Vector3.RIGHT, Vector3.FORWARD)
	var fallback: Vector3 = game.player.position - Vector3.RIGHT * FieldAi.FOLLOW_WALK_MIN
	# Decision 486: walls leave only the occupied fallback and the chief's own cell open.
	for x in range(16, 25):
		for z in range(16, 25):
			game.grid.set_solid(Vector2i(x, z), FieldGrid.Solid.WALL)
	game.grid.set_solid(FieldGrid.cell_of(game.player.position), FieldGrid.Solid.NONE)
	game.grid.set_solid(FieldGrid.cell_of(fallback), FieldGrid.Solid.NONE)
	mates["point"].position = fallback
	game.grid.refresh_paths()
	assert_eq(game.ai._follow_spot(p, [p], Vector3.RIGHT, Vector3.FORWARD), fallback)
	assert_eq(p.brain["follow_slot"], fallback, "the finite fallback remains available for this think")
	assert_false(p.brain.has("follow_slot_role"))
	assert_false(p.brain.has("follow_offset"))
	for x in range(16, 25):
		for z in range(16, 25):
			game.grid.set_solid(Vector2i(x, z), FieldGrid.Solid.NONE)
	game.grid.refresh_paths()
	game.clock.elapsed += FieldAi.THINK
	assert_eq(game.ai._follow_spot(p, [p], Vector3.RIGHT, Vector3.FORWARD), base)
	assert_eq(p.brain["follow_slot_role"], "side")
	assert_true(p.brain.has("follow_offset"))


func test_short_shuffle_watch_has_no_expiry_gap_and_preserves_combat_hold() -> void:
	_start()
	var p = mates["side"]
	p.path = PackedVector3Array([p.position + Vector3.RIGHT * 0.8])
	for tick in range(4):
		game.clock.elapsed += FieldAi.THINK
		game.ai._follow_release_watch(p)
		game.ai._follow_watch(p, Vector3.LEFT)
		var watch: Vector3 = p.brain["follow_watch"]
		assert_almost_eq(p.position.distance_to(watch), 20.0, 0.00001)
		assert_eq(float(p.brain["face_hold_t"]), game.clock.elapsed)
		assert_lt(FieldAi.THINK + 1.0 / 30.0, MoveRules.FACE_HOLD)
	var combat_hold: Vector3 = p.position + Vector3.BACK * 3.0
	p.brain["face_hold"] = combat_hold
	p.brain["face_hold_t"] = game.clock.elapsed
	game.ai._follow_release_watch(p)
	assert_eq(p.brain["face_hold"], combat_hold)
	game.ai._follow_watch(p, Vector3.LEFT)
	assert_eq(p.brain["face_hold"], combat_hold)
	p.brain.erase("face_hold")
	p.brain.erase("face_hold_t")
	p.path = PackedVector3Array([p.position + Vector3.RIGHT * (FieldAi.FOLLOW_SHUFFLE + 0.1)])
	game.ai._follow_watch(p, Vector3.LEFT)
	assert_false(p.brain.has("face_hold"))


func test_stand_no_jitter_after_walk() -> void:
	_start()
	game.player.position = Vector3(8.5, 0, 20.5)
	# Decision 486: start settled, take a short walk, then exercise the idle shuffle for six seconds.
	for i in range(3):
		var p = mates[["point", "side", "rear"][i]]
		p.position = game.ai._follow_spot(p, game.ai._follow_mates(), Vector3.RIGHT, Vector3.FORWARD)
		p.look = PI * 0.5
		p.facing = p.look
		p.brain["think_t"] = FieldAi.THINK * float(i) / 3.0
	game.player.go_to(PackedVector3Array([Vector3(30.5, 0, 20.5)]))
	game.player.moving = true
	for p in mates.values():
		game.ai._keep_formation(p)
	for tick in range(30):
		_follow_tick(1.0 / 30.0)
	game.player.stop()
	var changes: Array[int] = [0, 0, 0]
	var previous: Array[bool] = [true, true, true]
	var camera_frames: int = 0
	for tick in range(180):
		_follow_tick(1.0 / 30.0)
		for i in range(3):
			var p = mates[["point", "side", "rear"][i]]
			if p.moving != previous[i]:
				changes[i] += 1
			previous[i] = p.moving
			if tick > 90 and p.path.is_empty():
				var camera_way: Vector3 = game.camera.global_transform.basis.z
				camera_way.y = 0.0
				if Vector3(sin(p.look), 0, cos(p.look)).dot(camera_way.normalized()) > 0.5:
					camera_frames += 1
	for count: int in changes:
		assert_lte(count, 2)
	assert_eq(camera_frames, 0)
	for p in mates.values():
		assert_true(p.path.is_empty())


func _assert_follow_value(value: Variant) -> void:
	assert_false(value is Vector3i)
	if value is Vector3 or value is Vector2:
		assert_true(value.is_finite())
	elif value is float:
		assert_true(is_finite(value))
	elif value is Dictionary:
		for child: Variant in value.values():
			_assert_follow_value(child)
	elif value is Array:
		for child: Variant in value:
			_assert_follow_value(child)


func test_follow_state_saves_finite() -> void:
	var first = _field({"follow_walk_turn": true, "follow_ablate": ["1a", "3"]})
	first.player.moving = true
	first.ai._record_follow()
	first.ai._refresh_follow_axis()
	assert_true(first.ai._follow_fwd is Vector3 and first.ai._follow_fwd.is_finite())
	assert_ne(first.ai._follow_fwd, Vector3.ZERO)
	assert_false(first.ai._r5("1a"))
	assert_false(first.ai._r5("3"))
	for p in first.squad:
		if p != first.player:
			p.command = "follow"
			first.ai._keep_formation(p)
			first.ai._follow_wait(p, first.player)
	first.player.stop()
	for p in first.squad:
		if p != first.player:
			first.ai._follow_walk(p, PackedVector3Array([p.position + Vector3.RIGHT * 0.5]))
			first.ai._follow_watch(p, Vector3.LEFT)
			p.brain["follow_gap_waiting"] = false
	first.ai._follow_queue_on = true
	first.ai._follow_narrow_at = 2.0
	first.ai._follow_queue_mates(first.ai._follow_mates())
	var before: Dictionary = FieldSave.capture(first)
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(before))
	assert_false(saved.is_empty(), "all follow fields survive the real field-save codec")
	var resumed = _field(FieldSave.resume_opts(saved))
	assert_true(bool(resumed.opts.get("follow_walk_turn", false)))
	assert_false(saved["start_opts"].has("follow_ablate"), "the measurement switch is not a start option in a save")
	assert_false(resumed.opts.has("follow_ablate"))
	assert_true(resumed.ai._r5("1a"))
	assert_true(resumed.ai._r5("3"))
	assert_eq(resumed.ai._follow_fwd, first.ai._follow_fwd)
	assert_true(resumed.ai._follow_fwd is Vector3 and resumed.ai._follow_fwd.is_finite())
	assert_eq(resumed.ai._follow_queue_on, first.ai._follow_queue_on)
	assert_eq(resumed.ai._follow_narrow_at, first.ai._follow_narrow_at)
	for i in range(first.ai._follow_order.size()):
		assert_eq(resumed.ai._follow_order[i].pid, first.ai._follow_order[i].pid)
	for i in range(first.squad.size()):
		var p = first.squad[i]
		for key: String in p.brain:
			if key.begins_with("follow_"):
				_assert_follow_value(p.brain[key])
				assert_eq(resumed.squad[i].brain.get(key), p.brain[key], "round-trip " + key)
	var ai_state: Dictionary = saved["runtime"]["components"]["ai"]
	assert_false(ai_state.has("follow_ablate"), "transient metadata is not script state")
	_assert_follow_value(ai_state["_follow_fwd"])
	_assert_follow_value(ai_state["_follow_queue_on"])
	_assert_follow_value(ai_state["_follow_narrow_at"])


func test_narrow_hold_releases_when_chief_stands() -> void:
	for ablated: bool in [false, true]:
		_start()
		game.opts["follow_ablate"] = ["1a"] if ablated else []
		game.ai._follow_narrow_at = 0.0
		game.ai._follow_distance = 1.0
		game.ai._chief_still = FieldAi.LOOK_STILL_S - 0.01
		game.ai._refresh_follow_queue()
		assert_true(game.ai._follow_queue_on, "the exit hold lasts until the chief has stood for 1.5 seconds")
		game.ai._chief_still = FieldAi.LOOK_STILL_S
		game.ai._refresh_follow_queue()
		assert_eq(game.ai._follow_queue_on, ablated, "1a alone releases the exit hold")
	_queue_scene()
	game.player.stop()
	game.ai._chief_still = FieldAi.LOOK_STILL_S + 0.5
	game.ai._refresh_follow_queue()
	assert_true(game.ai._follow_queue_on, "the corridor itself still needs a queue")


func test_queue_gap_wait_faces_lookout() -> void:
	for ablated: bool in [false, true]:
		_queue_scene()
		game.opts["follow_ablate"] = ["1b"] if ablated else []
		var leader = mates["point"]
		var p = mates["side"]
		game.player.stop()
		leader.stop()
		p.position = leader.position - Vector3.RIGHT * 1.1
		p.brain.erase("follow_gap_waiting")
		p.brain["follow_lead_still"] = 0.0
		p.facing = PI * 0.5
		game.camera.global_position = p.global_position + Vector3.BACK * 20.0 + Vector3.UP * 50.0
		game.camera.look_at(p.global_position, Vector3.UP)
		var expected: Vector3 = game.ai._look_out(p, "side", Vector3.RIGHT, Vector3.FORWARD)
		game.ai._keep_formation(p)
		assert_true(p.path.is_empty())
		assert_true(bool(p.brain.get("follow_gap_waiting", false)))
		assert_false(bool(p.brain.get("follow_waiting", false)), "this is the gap stop, not the predecessor wait")
		if ablated:
			assert_almost_eq(p.facing, PI * 0.5, 0.00001, "the R4 gap stop keeps its old facing")
		else:
			assert_almost_eq(p.facing, atan2(expected.x, expected.z), 0.00001)
			var gaze: Vector3 = Vector3(sin(p.facing), 0, cos(p.facing))
			assert_lt(gaze.dot(Vector3.BACK), cos(deg_to_rad(65.0)))


## Decision 486: equal healthy bodies on open ground, with the real mover and staggered thinks.
func _formation_scene() -> void:
	_start()
	for p in game.squad:
		p.body = Person.BodyState.new()
		p.items.clear()
		p.hands.clear()
		p.worn = Person.Wear.outfit(Person.Wear.DEFAULT)
		p.heat.heat = 100.0
		p.heat.wet = 0.0
		p.hunger_level = 0
		p.sore_level = 0
		p.panic = 0.0
		p.facing = PI * 0.5
		p.look = p.facing
		p.turn_rate = deg_to_rad(400.0)
		p.running = false
	game.player.go_to(PackedVector3Array([Vector3(37.5, 0, 20.5)]))
	game.player.moving = true
	game.ai._record_follow()
	game.ai._refresh_follow_axis()
	game.ai.think_t = FieldAi.THINK
	for i in range(3):
		var p = mates[["point", "side", "rear"][i]]
		p.position = game.ai._follow_spot(p, game.ai._follow_mates(), Vector3.RIGHT, Vector3.FORWARD)
		p.brain["think_t"] = FieldAi.THINK * float(i) / 3.0
		game.ai._keep_formation(p)


func _formation_turn_observation() -> Dictionary:
	_formation_scene()
	for tick in range(30):
		_follow_tick(1.0 / 30.0)
	game.player.go_to(PackedVector3Array([game.player.position + Vector3.FORWARD * 12.0]))
	var result: Dictionary = {"axis_max_degrees": 0.0, "mates": {}}
	for role: String in ["point", "side", "rear"]:
		var p = mates[role]
		result["mates"][role] = {"moving": p.moving, "running": p.running, "moving_changes": 0, "running_changes": 0, "turn_stops": 0}
	for tick in range(90):
		var before_axis: Vector3 = game.ai._follow_fwd
		var before_calls: int = game.ai.axis_calls
		var moved: Dictionary = _follow_tick(1.0 / 30.0)
		assert_lte(game.ai.axis_calls - before_calls, 1, "only the shared think turns the axis")
		var turn: float = rad_to_deg(before_axis.angle_to(game.ai._follow_fwd))
		result["axis_max_degrees"] = maxf(float(result["axis_max_degrees"]), turn)
		for role: String in ["point", "side", "rear"]:
			var p = mates[role]
			var stats: Dictionary = result["mates"][role]
			if bool(moved[p.pid]["has_path"]) and not bool(moved[p.pid]["moving"]):
				stats["turn_stops"] += 1
			if bool(stats["moving"]) != p.moving:
				stats["moving_changes"] += 1
			if bool(stats["running"]) != p.running:
				stats["running_changes"] += 1
			stats["moving"] = p.moving
			stats["running"] = p.running
	return result


func test_formation_axis_turns_limited_per_think() -> void:
	var result: Dictionary = _formation_turn_observation()
	assert_gt(float(result["axis_max_degrees"]), 0.0, "the fixture really turns")
	assert_lte(float(result["axis_max_degrees"]), 67.5 + 0.001)
	for role: String in ["point", "side"]:
		assert_lte(int(result["mates"][role]["moving_changes"]), 2, role)
		assert_eq(int(result["mates"][role]["turn_stops"]), 0, role)
	var calls: int = game.ai.axis_calls
	var axis: Vector3 = game.ai._follow_fwd
	for p in mates.values():
		game.ai._keep_formation(p)
	assert_eq(game.ai.axis_calls, calls)
	assert_eq(game.ai._follow_fwd, axis)
	game.player.stop()
	game.player.facing = 0.0
	game.ai._refresh_follow_axis()
	assert_eq(game.ai._follow_fwd, Vector3.BACK, "a standing chief uses the raw facing")
	game.opts["follow_ablate"] = ["2a"]
	game.player.facing = PI * 0.5
	assert_eq(game.ai._follow_axis(), game.ai._follow_forward(), "2a off restores the raw axis")


func test_formation_zigzag_no_turn_stop() -> void:
	_formation_scene()
	for tick in range(30):
		_follow_tick(1.0 / 30.0)
	var route: PackedVector3Array = PackedVector3Array()
	var at: Vector3 = game.player.position
	for i in range(16):
		var angle: float = deg_to_rad(22.5 if i % 2 == 0 else -22.5)
		at += Vector3(cos(angle), 0, sin(angle))
		route.append(at)
	game.player.go_to(route)
	var stops: Dictionary = {"point": 0, "side": 0, "rear": 0}
	for tick in range(180):
		var moved: Dictionary = _follow_tick(1.0 / 30.0)
		for role: String in stops:
			var p = mates[role]
			if bool(moved[p.pid]["has_path"]) and not bool(moved[p.pid]["moving"]):
				stops[role] += 1
	for role: String in stops:
		assert_eq(int(stops[role]), 0, role + " never turns in place on the one-metre zigzag")


func test_formation_run_uses_slot_distance() -> void:
	_start()
	var p = mates["side"]
	game.player.moving = true
	var far_goal: Vector3 = p.position + Vector3.RIGHT * 8.0
	for sample: Array in [[3.0, false], [3.01, true], [1.0, true], [0.99, false]]:
		game.ai._follow_walk(p, PackedVector3Array([far_goal]), null, Vector3.RIGHT, float(sample[0]))
		assert_eq(p.running, bool(sample[1]), "the lead cannot change the slot hysteresis")
	for sample: Array in [[4.6, true], [3.0, true], [2.4, false]]:
		game.ai._follow_walk(p, PackedVector3Array([p.position + Vector3.RIGHT * float(sample[0])]), game.player, Vector3.ZERO, 0.1)
		assert_eq(p.running, bool(sample[1]), "a queue keeps the 4.5/2.5 thresholds")
	game.player.running = true
	game.ai._follow_walk(p, PackedVector3Array([far_goal]), null, Vector3.RIGHT, 0.1)
	assert_true(p.running, "the chief's run still wins over a near slot")
	var result: Dictionary = _formation_turn_observation()
	for role: String in ["point", "side"]:
		assert_lte(int(result["mates"][role]["running_changes"]), 2, role + " changes run at most twice after a right-angle turn")


func test_formation_shifted_slot_not_saved() -> void:
	for ablated: bool in [false, true]:
		_start()
		game.opts["follow_ablate"] = ["4a"] if ablated else []
		game.player.moving = true
		var p = mates["side"]
		var base: Vector3 = game.ai._follow_spot(p, [p], Vector3.RIGHT, Vector3.FORWARD)
		var blocker = mates["point"]
		var old: Vector3 = blocker.position
		blocker.position = base
		var shifted: Vector3 = game.ai._follow_spot(p, [p], Vector3.RIGHT, Vector3.FORWARD)
		assert_ne(shifted, base)
		assert_true(shifted.is_finite())
		assert_eq(p.brain["follow_slot"], shifted, "the current goal remains observable")
		for key: String in ["follow_offset", "follow_slot_role", "follow_slot_walking"]:
			assert_eq(p.brain.has(key), ablated, "only R4 saves a shifted slot: " + key)
		blocker.position = old
		game.clock.elapsed += FieldAi.THINK
		assert_eq(game.ai._follow_spot(p, [p], Vector3.RIGHT, Vector3.FORWARD), base)
		assert_true(p.brain.has("follow_offset"), "base slots still keep their relative offset")


func test_queue_band_keeps_sufficient_route_and_refreshes_short_route() -> void:
	for ablated: bool in [false, true]:
		_queue_scene()
		game.opts["follow_ablate"] = ["6"] if ablated else []
		var leader = mates["point"]
		var p = mates["side"]
		p.position = leader.position - Vector3.RIGHT * 1.4
		p.brain.erase("follow_gap_waiting")
		var leader_back: float = float(game.ai._follow_projection(leader.position)["back"])
		var short_route: PackedVector3Array = game.ai._follow_queue_path(p, leader_back + FieldAi.FOLLOW_QUEUE_WAIT, Vector3.RIGHT)
		short_route = game.ai._follow_leave_room(p, short_route, leader)
		var speed: float = p.speed(game.grid.floor_at(FieldGrid.cell_of(p.position)))
		assert_gt(game.ai._follow_remaining(p.position, short_route), 0.0)
		assert_lt(game.ai._follow_remaining(p.position, short_route), speed * FieldAi.THINK, "the R4 band route ends within one think")
		var kept: PackedVector3Array = PackedVector3Array([p.position + Vector3.BACK * 0.4, p.position + Vector3.BACK * 0.4 + Vector3.RIGHT * 0.3])
		p.go_to(kept.duplicate())
		game.ai.queue_path_calls = 0
		game.ai._keep_formation(p)
		assert_eq(game.ai.queue_path_calls, 1 if ablated else 0)
		if not ablated:
			assert_eq(p.path, kept, "a long, clear route survives the band think")
		assert_false(p.running)
		p.go_to(PackedVector3Array([p.position + Vector3.RIGHT * 0.2]))
		game.ai.queue_path_calls = 0
		game.ai._keep_formation(p)
		assert_eq(game.ai.queue_path_calls, 1, "a short route is still refreshed")


func _r4_pace_trace(reference: bool, ablated: bool) -> Array[Vector3]:
	_formation_scene()
	if reference:
		game.ai = R4WalkAi.new(game)
	else:
		game.opts["follow_ablate"] = ["3"] if ablated else []
	var p = mates["side"]
	p.position = Vector3(8.5, 0, 18.5)
	p.stop()
	var trace: Array[Vector3] = []
	var gaps: Array[float] = [4.6, 3.1, 2.4, 4.0, 4.7, 2.3]
	for tick in range(180):
		game.clock.step(1.0 / 30.0)
		if tick % 15 == 0:
			var gap: float = gaps[floori(float(tick) / 15.0) % gaps.size()]
			game.ai._follow_walk(p, PackedVector3Array([p.position + Vector3.RIGHT * gap]), null, Vector3.RIGHT, 0.8)
		game._turn_people(1.0 / 30.0)
		game._move_person(p, 1.0 / 30.0)
		trace.append(p.position)
	return trace


func test_ablate_3_matches_r4_position_trace() -> void:
	var reference: Array[Vector3] = _r4_pace_trace(true, false)
	assert_eq(_r4_pace_trace(false, true), reference, "3 off follows the frozen 52c5501d walker for every tick")
	assert_ne(_r4_pace_trace(false, false), reference, "the fixture also detects enabled slot pacing")


func test_follow_ablation_steps_are_independent() -> void:
	_start()
	var steps: Array[String] = ["1a", "1b", "2a", "3", "4a", "6"]
	for selected: String in steps:
		game.opts["follow_ablate"] = [selected]
		for step: String in steps:
			assert_eq(game.ai._r5(step), step != selected)
	game.opts["follow_ablate"] = []
	for step: String in steps:
		assert_true(game.ai._r5(step))


func _field(extra: Dictionary = {}):
	var g = FieldGame.new()
	g.opts = {"seed": 11, "raiders": false, "auto_pause": false, "arrive": false}
	g.opts.merge(extra, true)
	g.map_script = BareLine
	add_child_autofree(g)
	g.set_process(false)
	return g
