extends "res://addons/gut/test.gd"

const Zombies = preload("res://game/actors/zombies.gd")
const Separation = preload("res://game/sim/dead_separation.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const DT := 1.0 / 30.0
const EPS := 0.000002

class World extends RefCounted:
	var grid = FieldGrid.new(32, 32)
	var stairs: Array = []
	var rng := RandomNumberGenerator.new()
	var opts := {"seed": 413}
	func level_of(at: Vector3) -> int:
		return roundi(at.y / 3.0)
	func level_y(lv: int) -> float:
		return lv * 3.0
	func grid_at(_at: Vector3):
		return grid

var zombies
var world


func before_each() -> void:
	world = World.new()
	world.rng.seed = 413
	zombies = Zombies.new()
	zombies.game = world
	add_child_autofree(zombies)


func _dead(at: Vector3 = Vector3(10.5, 0, 10.5)) -> Dictionary:
	return zombies.spawn("dead", at)


func test_coincident_pair_reaches_body_width() -> void:
	var a := _dead()
	var b := _dead()
	for tick in range(90):
		zombies._separate(DT)
	assert_gte(a["pos"].distance_to(b["pos"]), Separation.SEPARATION_R - EPS)


func test_wall_rejects_the_whole_push() -> void:
	world.grid.set_solid(Vector2i(9, 10), FieldGrid.Solid.WALL)
	var a := _dead(Vector3(10.001, 0, 10.5))
	_dead(Vector3(10.2, 0, 10.5))
	zombies._separate(DT)
	assert_eq(a["pos"], Vector3(10.001, 0, 10.5))


func test_downed_neither_pushes_nor_is_pushed() -> void:
	var a := _dead()
	var b := _dead()
	a["state"] = "downed"
	zombies._separate(DT)
	assert_eq(a["pos"], Vector3(10.5, 0, 10.5))
	assert_eq(b["pos"], a["pos"])


func test_distant_pair_does_not_move() -> void:
	var a := _dead()
	var at := Vector3(11.1, 0, 10.5)
	var b := _dead(at)
	zombies._separate(DT)
	assert_eq(a["pos"], Vector3(10.5, 0, 10.5))
	assert_eq(b["pos"], at)


func test_three_coincident_bodies_limit_the_summed_vector() -> void:
	for i in range(3):
		_dead()
	var start := Vector3(10.5, 0, 10.5)
	var cap: float = zombies._speed(zombies.list[0]) * DT * Separation.MAX_STEP_SHARE
	zombies._separate(DT)
	for z in zombies.list:
		assert_lte(z["pos"].distance_to(start), cap + EPS)
		assert_gt(z["pos"].distance_to(start), 0.0)


func test_all_excluded_states_and_timers_are_inert() -> void:
	for state in ["downed", "rising", "waking", "frozen", "climb", "grab", "dead", "corpse", "dash"]:
		zombies.list.clear()
		var a := _dead()
		var b := _dead()
		a["state"] = state
		zombies._separate(DT)
		assert_eq(a["pos"], b["pos"], state)
		assert_eq(a["pos"], Vector3(10.5, 0, 10.5), state)
	for timer in ["dash_t", "shoved_t"]:
		zombies.list.clear()
		var a := _dead()
		var b := _dead()
		a[timer] = 0.01
		zombies._separate(DT)
		assert_eq(a["pos"], b["pos"], timer)
		assert_eq(a["pos"], Vector3(10.5, 0, 10.5), timer)


func test_different_floors_do_not_interact() -> void:
	var a := _dead()
	var b := _dead(Vector3(10.5, 3, 10.5))
	zombies._separate(DT)
	assert_eq(a["pos"], Vector3(10.5, 0, 10.5))
	assert_eq(b["pos"], Vector3(10.5, 3, 10.5))


func test_closed_door_and_stair_or_ladder_destinations_are_rejected() -> void:
	for obstacle in ["door", "stairs", "ladder"]:
		zombies.list.clear()
		world.grid = FieldGrid.new(32, 32)
		world.stairs.clear()
		if obstacle == "door":
			world.grid.doors[Vector2i(9, 10)] = {"state": "closed"}
			world.grid.set_solid(Vector2i(9, 10), FieldGrid.Solid.DOOR)
		else:
			world.stairs.append({"cell": Vector2i(9, 10), "low": 0, "high": 1, "ladder": obstacle == "ladder"})
		var a := _dead(Vector3(10.001, 0, 10.5))
		_dead(Vector3(10.2, 0, 10.5))
		zombies._separate(DT)
		assert_eq(a["pos"], Vector3(10.001, 0, 10.5), obstacle)


func test_correction_changes_only_position_and_not_random_state() -> void:
	var a := _dead()
	_dead()
	var saved: Dictionary = a.duplicate(true)
	var random_state: int = world.rng.state
	zombies._separate(DT)
	assert_ne(a["pos"], saved["pos"])
	for key in saved:
		if key != "pos":
			assert_eq(a[key], saved[key], key)
	assert_eq(world.rng.state, random_state)


func test_crawl_and_slow_floor_use_current_speed() -> void:
	world.grid.floor[world.grid.index(Vector2i(10, 10))] = FieldGrid.Floor.DEEP_SNOW
	var a := _dead()
	_dead()
	a["crawl"] = true
	var cap: float = zombies._speed(a) * DT * Separation.MAX_STEP_SHARE
	zombies._separate(DT)
	assert_almost_eq(a["pos"].distance_to(Vector3(10.5, 0, 10.5)), cap, EPS)


func test_exact_pair_resolves_identically_when_list_order_changes() -> void:
	var a := _dead()
	var b := _dead()
	zombies._separate(DT)
	var first_a: Vector3 = a["pos"]
	var first_b: Vector3 = b["pos"]
	a["pos"] = Vector3(10.5, 0, 10.5)
	b["pos"] = a["pos"]
	zombies.list.reverse()
	zombies._separate(DT)
	assert_eq(a["pos"], first_a)
	assert_eq(b["pos"], first_b)


func test_tick_entry_exclusion_survives_a_state_transition() -> void:
	var a := _dead()
	var b := _dead()
	# update remembers excluded IDs before timers expire/state transitions run.
	zombies._separate(DT, {a["id"]: true})
	assert_eq(a["pos"], Vector3(10.5, 0, 10.5))
	assert_eq(b["pos"], a["pos"])
