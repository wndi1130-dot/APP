extends GutTest
## One the AI walks turns into the way before it goes and backs off a crowd with
## its face to them, the walk drawn backwards (move_rules.gd; user field test
## 10-25: the companions "whip round and move like drones"). The player on a
## path goes as before.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const MoveRules = preload("res://game/sim/move_rules.gd")
const Person = preload("res://game/actors/person.gd")
const PersonVisual = preload("res://game/actors/person_visual.gd")
const Zombies = preload("res://game/actors/zombies.gd")
const Gait = preload("res://game/sim/gait.gd")

var game
var ally


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	game.player.position = game.lift(Vector2i(60, 7), 0)
	ally = null
	for q in game.squad:
		if q != game.player:
			q.position = game.lift(Vector2i(30, 7), 0)
			if ally == null:
				ally = q
	ally.position = game.lift(Vector2i(60, 12), 0)
	ally.turn_rate = deg_to_rad(400.0)
	ally.brain.erase("face_hold")


func _east(p) -> void:
	p.path = PackedVector3Array([p.position + Vector3(4, 0, 0)])


func _top(p) -> float:
	return p.speed(game.grid_at(p.position).floor_at(FieldGrid.cell_of(p.position)))


func test_the_share_of_pace_by_how_far_the_body_is_off_the_way() -> void:
	assert_eq(MoveRules.heading_share(0.0), 1.0)
	assert_eq(MoveRules.heading_share(deg_to_rad(MoveRules.FREE_DEG)), 1.0)
	assert_almost_eq(MoveRules.heading_share(deg_to_rad(60.0)), cos(deg_to_rad(60.0)) / cos(deg_to_rad(MoveRules.FREE_DEG)), 0.0001)
	assert_eq(MoveRules.heading_share(deg_to_rad(MoveRules.STILL_DEG)), 0.0)
	assert_eq(MoveRules.heading_share(PI), 0.0)


func test_a_body_still_turned_away_turns_on_the_spot_before_it_goes() -> void:
	_east(ally)
	ally.look = -PI * 0.5   # its drawn body faces west, the way is east
	var at: Vector3 = ally.position
	game._move_person(ally, 0.1)
	assert_eq(ally.position, at, "it does not glide off backwards")
	assert_false(ally.moving)
	assert_almost_eq(ally.facing, PI * 0.5, 0.0001, "it means to face the way")
	ally.look = PI * 0.5
	game._move_person(ally, 0.1)
	assert_gt(ally.position.x, at.x, "come round, it goes")


func test_a_walker_whose_way_turns_back_stops_and_turns_rather_than_glide_off() -> void:
	ally.look = PI * 0.5
	ally.path = PackedVector3Array([ally.position + Vector3(-4, 0, 0)])
	var at: Vector3 = ally.position
	game._move_person(ally, 0.1)
	assert_eq(ally.position, at, "no gliding off the other way while still turned from it: a half turn is made standing")
	assert_false(ally.moving)
	assert_almost_eq(ally.facing, -PI * 0.5, 0.0001)


# Facing the way it goes at its pace at once: an easing in at 0.2 s left the
# companions behind the chief and bitten more (40 runs 10-26, on the walk 5 → 13).
func test_facing_the_way_it_goes_at_its_pace_at_once() -> void:
	ally.look = PI * 0.5
	_east(ally)
	var top := _top(ally)
	var at: Vector3 = ally.position
	game._move_person(ally, 0.05)
	assert_almost_eq(ally.position.distance_to(at), top * 0.05, 0.001)


func test_swarmed_it_steps_back_with_its_face_to_them_and_the_walk_runs_back() -> void:
	var them: Vector3 = ally.position + Vector3(-1.0, 0, 0)
	ally.brain["face_hold"] = them
	ally.brain["face_hold_t"] = game.clock.elapsed
	ally.look = -PI * 0.5
	ally.refresh_view(false)   # The shared phase reads the body actually drawn.
	ally.running = true
	ally.brain["step_r"] = 0.5
	var note: Dictionary = {}
	var own: Array = [{"name": "p_walk", "round": 1.64}]
	PersonVisual.motion_of(ally, note, 0.0, [], own)
	_east(ally)
	var at: Vector3 = ally.position
	game._move_person(ally, 0.1)
	assert_almost_eq(ally.facing, -PI * 0.5, 0.0001, "its face stays to them")
	assert_gt(ally.position.x, at.x, "it goes back, away from them")
	assert_lte(ally.position.distance_to(at), MoveRules.BACKPEDAL * 0.1 + 0.0001, "a walk at most, never a run")
	assert_lte(MoveRules.BACKPEDAL, Person.WALK)
	assert_gt(MoveRules.BACKPEDAL, Zombies.SPEED_HURRY, "it gains on the hurrying dead as it backs off")
	assert_lt(float(ally.brain["step_r"]), 0.5, "the walk's round runs back: it is drawn stepping backwards")
	var motion: Vector2 = PersonVisual.motion_of(ally, note, 0.1, [], own)
	assert_eq(int(motion.y), 0, "the backward walk is drawn")
	assert_almost_eq(motion.x, float(ally.brain["step_r"]), 0.0001, "the drawing uses the same backward round")
	ally.brain["face_hold_t"] = game.clock.elapsed - MoveRules.FACE_HOLD - 0.1
	game._move_person(ally, 0.1)
	assert_almost_eq(ally.facing, PI * 0.5, 0.0001, "the hold over, it turns to the way")


func test_swarmed_the_companion_asks_to_keep_its_face_to_them() -> void:
	var z: Dictionary = game.zombies.spawn("dead", ally.position + Vector3(1.6, 0, 0))
	game.zombies.spawn("dead", ally.position + Vector3(1.8, 0, 0.6))
	game.zombies.spawn("dead", ally.position + Vector3(1.7, 0, -0.6))
	assert_gte(game.ai._crowd(ally), game.ai.CROWD_N)
	ally.running = true
	game.ai._engage(ally, z)
	assert_eq(ally.brain.get("face_hold"), z["pos"])
	assert_almost_eq(float(ally.brain["face_hold_t"]), game.clock.elapsed, 0.0001)
	assert_false(ally.running, "it steps back at a walk, not a run")


# Backing off toward the chief it does not back into the chief's body (check
# shots 10-26: the two bodies stood as one): with the chief in the way back, it
# ends at the chief's side, CHIEF_ROOM off; with the chief out of the way, as before.
func test_swarmed_it_backs_off_beside_the_chief_not_through_it() -> void:
	game.player.position = ally.position + Vector3(-1.5, 0, 0)
	var z: Dictionary = game.zombies.spawn("dead", ally.position + Vector3(1.6, 0, 0))
	game.zombies.spawn("dead", ally.position + Vector3(1.8, 0, 0.6))
	game.zombies.spawn("dead", ally.position + Vector3(1.7, 0, -0.6))
	game.ai._engage(ally, z)
	var dest: Vector3 = ally.brain["dest"]
	var chief: Vector3 = game.player.position
	assert_almost_eq(Vector2(dest.x - chief.x, dest.z - chief.z).length(), game.ai.CHIEF_ROOM, 0.01, "at the chief's side")
	var way := Vector2(dest.x - ally.position.x, dest.z - ally.position.z)
	var rel := Vector2(chief.x - ally.position.x, chief.z - ally.position.z)
	var near := way * clampf(rel.dot(way) / way.length_squared(), 0.0, 1.0)
	assert_gt(near.distance_to(rel), 0.5, "the way there goes by the chief, not through")
	game.player.position = ally.position + Vector3(0, 0, 4.0)
	var open: Vector3 = game.ai._beside_chief(ally.position, ally.position + Vector3(-2.5, 0, 0), Vector3(-1, 0, 0))
	assert_eq(open, ally.position + Vector3(-2.5, 0, 0), "the chief out of the way: as before")


func test_a_step_back_sounds_as_a_step() -> void:
	ally.brain["step_r"] = 0.6
	assert_gt(FieldGame.steps_in(ally, -3.0), 0)


func test_the_player_on_a_path_still_goes_at_once() -> void:
	var p = game.player
	p.look = -PI * 0.5
	_east(p)
	var top := _top(p)
	var at: Vector3 = p.position
	game._move_person(p, 0.05)
	assert_almost_eq(p.position.distance_to(at), top * 0.05, 0.001)
	assert_almost_eq(p.facing, PI * 0.5, 0.0001)


func _open_fps_lane() -> Vector3:
	for x: int in range(60, 70):
		for z: int in range(7, 10):
			var cell := Vector2i(x, z)
			game.grid.set_solid(cell, FieldGrid.Solid.NONE)
			game.grid.floor[game.grid.index(cell)] = FieldGrid.Floor.SNOW
			game.grid.doors.erase(cell)
			game.grid.windows.erase(cell)
	return Vector3(60.5, 0.0, 7.5)


func _fps_route(start: Vector3, spacing: float) -> PackedVector3Array:
	var route := PackedVector3Array()
	for i: int in range(1, int(8.0 / spacing) + 1):
		route.append(start + Vector3.RIGHT * spacing * float(i))
	return route


func test_person_waypoints_keep_pace_at_thirty_and_sixty_hz() -> void:
	var start: Vector3 = _open_fps_lane()
	var p = game.player
	for spacing: float in [1.0, 0.5]:
		for fps: int in [30, 60]:
			p.stop()
			p.position = start
			p.running = false
			p.path = _fps_route(start, spacing)
			var speed: float = _top(p)
			var dt: float = 1.0 / float(fps)
			var frames: int = 0
			while not p.path.is_empty() and frames < fps * 15:
				var before: Vector3 = p.position
				game._move_person(p, dt)
				assert_gt(p.position.distance_to(before), 0.000001)
				frames += 1
			assert_true(p.path.is_empty())
			assert_almost_eq(p.position.x, start.x + 8.0, 0.0001)
			assert_almost_eq(float(frames) * dt, 8.0 / speed, dt + 0.0001)


func test_dead_waypoints_keep_pace_without_reversal_at_thirty_and_sixty_hz() -> void:
	var start: Vector3 = _open_fps_lane()
	var z: Dictionary = game.zombies.spawn("dead", start)
	game.zombies._people.clear()
	for spacing: float in [1.0, 0.5]:
		for fps: int in [30, 60]:
			z["pos"] = start
			z["state"] = "chase"
			z["target"] = start + Vector3.RIGHT * 8.0
			z["path"] = _fps_route(start, spacing)
			z["path_t"] = 100.0
			var dt: float = 1.0 / float(fps)
			var speed: float = game.zombies._speed(z)
			var frames: int = 0
			while not (z["path"] as PackedVector3Array).is_empty() and frames < fps * 30:
				var before: Vector3 = z["pos"]
				game.zombies._move(z, dt)
				var after: Vector3 = z["pos"]
				assert_gt(after.x - before.x, 0.000001)
				frames += 1
			assert_true((z["path"] as PackedVector3Array).is_empty())
			var end: Vector3 = z["pos"]
			assert_almost_eq(end.x, start.x + 8.0, 0.0001)
			assert_almost_eq(float(frames) * dt, 8.0 / speed, dt + 0.0001)


func test_a_stair_waypoint_still_changes_only_height_for_both() -> void:
	var start: Vector3 = _open_fps_lane()
	var upper: Vector3 = start + Vector3.UP * game.level_y(1)
	game.player.position = start
	game.player.path = PackedVector3Array([upper, upper + Vector3.RIGHT])
	game._move_person(game.player, 0.1)
	assert_eq(game.player.position, upper)
	assert_eq(game.player.path.size(), 1)
	var z: Dictionary = game.zombies.spawn("dead", start)
	z["state"] = "chase"
	z["target"] = upper + Vector3.RIGHT * 8.0
	z["path"] = PackedVector3Array([upper, upper + Vector3.RIGHT])
	z["path_t"] = 100.0
	game.zombies._move(z, 0.1)
	assert_eq(z["pos"], upper)
	assert_eq((z["path"] as PackedVector3Array).size(), 1)


func test_heading_share_is_recomputed_after_a_waypoint() -> void:
	var start: Vector3 = _open_fps_lane()
	ally.position = start
	ally.command = "wait"
	ally.look = PI * 0.5
	ally.turn_rate = 1.0
	var corner: Vector3 = start + Vector3.RIGHT * 0.05
	var diagonal: Vector3 = Vector3.RIGHT.rotated(Vector3.UP, -PI / 3.0)
	ally.path = PackedVector3Array([corner, corner + diagonal * 2.0])
	var speed: float = _top(ally)
	var dt: float = 0.1
	game._move_person(ally, dt)
	var share: float = MoveRules.heading_share(PI / 3.0)
	assert_almost_eq(ally.position.distance_to(corner), (dt - 0.05 / speed) * speed * share, 0.0001)
	assert_almost_eq(ally.facing, atan2(diagonal.x, diagonal.z), 0.0001)


func test_door_after_waypoint_starts_opening() -> void:
	var start: Vector3 = _open_fps_lane()
	var door := Vector2i(61, 7)
	game.grid.set_solid(door, FieldGrid.Solid.DOOR)
	game.grid.doors[door] = {"state": "closed", "planks": [0, 0]}
	game.player.position = start + Vector3.RIGHT * 0.35
	game.player.path = PackedVector3Array([start + Vector3.RIGHT * 0.4, start + Vector3.RIGHT])
	game._move_person(game.player, 0.2)
	assert_eq(game.player.action, "door")


func test_camera_interpolation_matches_sixty_hz_and_time_partitions() -> void:
	var start_focus: Vector3 = game.player.position + Vector3.RIGHT * 2.0
	var start_size: float = game.cam_size + 3.0
	var positions: Array[Vector3] = []
	var sizes: Array[float] = []
	game.cam_focus = start_focus
	game.camera.size = start_size
	game._update_camera(1.0 / 60.0)
	assert_almost_eq(game.camera.size, lerpf(start_size, game.cam_size, 6.0 / 60.0), 0.00001)
	var one: Vector3 = game.cam_focus
	game.cam_focus = start_focus
	game._update_camera(2.0 / 60.0)
	var two: Vector3 = game.cam_focus
	assert_almost_eq(two.distance_to(start_focus) / one.distance_to(start_focus), 2.0 - 4.0 / 60.0, 0.0001)
	for pieces: int in [1, 3, 6]:
		game.cam_focus = start_focus
		game.camera.size = start_size
		for _frame: int in range(pieces):
			game._update_camera(0.1 / float(pieces))
		positions.append(game.cam_focus)
		sizes.append(game.camera.size)
	for index: int in range(1, positions.size()):
		assert_almost_eq(positions[index].distance_to(positions[0]), 0.0, 0.00001)
		assert_almost_eq(sizes[index], sizes[0], 0.00001)


func test_backpedal_then_sideways_keeps_distance_and_contacts_across_frames() -> void:
	var start: Vector3 = _open_fps_lane()
	var corner: Vector3 = start + Vector3.RIGHT * 0.105
	var finish: Vector3 = corner + Vector3.FORWARD * 0.105
	var counts: Array[int] = []
	var phases: Array[float] = []
	for pieces: int in [1, 2]:
		ally.stop()
		ally.position = start
		ally.command = "wait"
		ally.running = false
		ally.crouched = false
		ally.look = -PI * 0.5
		ally.refresh_view(false)
		ally.brain["face_hold"] = start + Vector3.LEFT
		ally.brain["face_hold_t"] = game.clock.elapsed
		ally.brain["step_r"] = 0.23
		ally.brain.erase(Gait.GROUND_RUN)
		ally.ground_sample.clear()
		ally.path = PackedVector3Array([corner, finish])
		var backward_dt: float = 0.105 / minf(_top(ally), MoveRules.BACKPEDAL)
		var sideways_dt: float = 0.105 / _top(ally)
		var total_dt: float = backward_dt + sideways_dt
		var durations: PackedFloat64Array = PackedFloat64Array([total_dt]) if pieces == 1 else PackedFloat64Array([backward_dt, sideways_dt])
		var before: int = game.ledger.sound_events
		for dt: float in durations:
			game._begin_motion_tick()
			game._move_person(ally, dt)
		assert_almost_eq(ally.position.distance_to(finish), 0.0, 0.00001)
		counts.append(int(game.ledger.sound_events) - before)
		phases.append(float(ally.brain["step_r"]))
		if pieces == 1:
			var ground: Dictionary = ally.brain[Gait.GROUND_RUN]
			var expected: float = (0.21 / total_dt) * (1.0 - exp(-total_dt / Gait.RUN_TAU))
			assert_almost_eq(float(ground["speed"]), expected, 0.0001, "one speed sample includes both distances")
	assert_eq(counts[0], 2, "both crossings of the same contact survive the reversal")
	assert_eq(counts[0], counts[1])
	assert_almost_eq(phases[0], phases[1], 0.00001)
	assert_almost_eq(phases[0], 0.23, 0.00001)


func test_dead_passes_a_waypoint_beside_a_person_at_thirty_and_sixty_hz() -> void:
	var waypoint: Vector3 = _open_fps_lane() + Vector3.RIGHT
	game.player.position = waypoint + Vector3.RIGHT * 0.45
	game.zombies._people = game.people
	assert_true(game.zombies._people.has(game.player))
	var z: Dictionary = game.zombies.spawn("dead", waypoint)
	var positions: Array[Vector3] = []
	var speed: float = 0.0
	for fps: int in [30, 60]:
		z["pos"] = waypoint + Vector3.LEFT * 0.12
		z["state"] = "chase"
		z["target"] = waypoint + Vector3.BACK * 2.0
		z["path"] = PackedVector3Array([waypoint, z["target"]])
		z["path_t"] = 100.0
		speed = game.zombies._speed(z)
		for frame: int in range(fps):
			game.zombies._move(z, 1.0 / float(fps))
			if frame == 2:
				assert_eq((z["path"] as PackedVector3Array).size(), 1, "the nearby person does not pin the waypoint")
		var after: Vector3 = z["pos"]
		assert_gt(after.z, waypoint.z + 0.5, "the next leg makes progress with the person still present")
		positions.append(after)
	assert_lte(positions[0].distance_to(positions[1]), speed / 30.0 + 0.00001)


func test_dead_waypoint_remainder_and_avoidance_respect_walls_and_doors() -> void:
	var start: Vector3 = _open_fps_lane()
	game.zombies._people = game.people
	var blocked: Vector2i = Vector2i(60, 8)
	for solid: int in [FieldGrid.Solid.WALL, FieldGrid.Solid.DOOR]:
		game.grid.set_solid(blocked, solid)
		if solid == FieldGrid.Solid.DOOR:
			game.grid.doors[blocked] = {"state": "closed", "planks": [0, 0]}
		var waypoint: Vector3 = start + Vector3(0.0, 0.0, 0.48)
		game.player.position = waypoint + Vector3.RIGHT * 0.45
		var z: Dictionary = game.zombies.spawn("dead", waypoint + Vector3.LEFT * 0.02)
		z["state"] = "chase"
		z["target"] = waypoint + Vector3.BACK * 2.0
		z["path"] = PackedVector3Array([waypoint, z["target"]])
		z["path_t"] = 100.0
		game.zombies._move(z, 0.1)
		var after: Vector3 = z["pos"]
		assert_eq((z["path"] as PackedVector3Array).size(), 1)
		assert_lt(after.z, 8.0, "the remaining time cannot cross the blocker")
		assert_false(game.grid.blocks_body(FieldGrid.cell_of(after)))
		if solid == FieldGrid.Solid.DOOR:
			assert_true(z.has("bang_seen"), "the next leg still checks the closed door")
		# A person pushing directly into the blocker cannot displace the body through it.
		z["pos"] = waypoint
		z["path"] = PackedVector3Array([waypoint + Vector3.LEFT * 2.0])
		game.player.position = waypoint + Vector3.FORWARD * 0.45
		game.zombies._move(z, 0.01)
		after = z["pos"]
		assert_lt(after.z, 8.0)
		assert_false(game.grid.blocks_body(FieldGrid.cell_of(after)))
		game.grid.doors.erase(blocked)
		game.grid.set_solid(blocked, FieldGrid.Solid.NONE)
