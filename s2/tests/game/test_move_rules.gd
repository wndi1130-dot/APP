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
