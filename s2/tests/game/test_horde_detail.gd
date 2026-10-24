extends "res://addons/gut/test.gd"

const Zombies = preload("res://game/actors/zombies.gd")
const Sense = preload("res://game/sim/sense_rules.gd")
const Director = preload("res://game/sim/horde_director.gd")

class HerdGrid extends RefCounted:
	var visible := true
	func line_clear(_a, _b) -> bool: return visible

class HerdWorld extends RefCounted:
	var rng := RandomNumberGenerator.new()
	var grid := HerdGrid.new()
	func level_of(at: Vector3) -> int: return roundi(at.y / 3.0)
	func level_y(level_id: int) -> float: return level_id * 3.0
	func grid_at(_at: Vector3): return grid


func _dead():
	var dead = Zombies.new()
	dead.game = HerdWorld.new()
	dead.game.rng.seed = 9
	add_child_autofree(dead)
	return dead


func test_herd_call_reaches_only_visible_neighbours_on_its_floor() -> void:
	var dead = _dead()
	var source: Dictionary = dead.spawn("dead", Vector3(5, 0, 5))
	source["state"] = "chase"
	var near: Dictionary = dead.spawn("dead", Vector3(12.9, 0, 5))
	var far: Dictionary = dead.spawn("dead", Vector3(13.1, 0, 5))
	var upstairs: Dictionary = dead.spawn("dead", Vector3(5, 3, 5))
	dead._call_neighbours(source, Vector3(20, 0, 5))
	assert_eq(near["state"], "investigate")
	assert_eq(near["clue_kind"], "herd")
	assert_eq(far["state"], "wander")
	assert_eq(upstairs["state"], "wander")
	assert_eq(source["state"], "chase")


func test_a_wall_blocks_a_neighbours_visual_call() -> void:
	var dead = _dead()
	var source: Dictionary = dead.spawn("dead", Vector3(5, 0, 5))
	source["state"] = "chase"
	var neighbour: Dictionary = dead.spawn("dead", Vector3(6, 0, 5))
	dead.game.grid.visible = false
	dead._call_neighbours(source, Vector3(20, 0, 5))
	assert_eq(neighbour["state"], "wander")
	assert_eq(neighbour["target"], neighbour["home"])


func test_herd_does_not_replace_an_existing_grab_or_chase() -> void:
	var dead = _dead()
	var source: Dictionary = dead.spawn("dead", Vector3(5, 0, 5))
	source["state"] = "chase"
	var holders: Array = []
	for state in ["grab", "chase", "downed", "frozen", "climb", "tell"]:
		var z: Dictionary = dead.spawn("dead", Vector3(6, 0, 5))
		z["state"] = state
		holders.append(z.duplicate(true))
	dead._call_neighbours(source, Vector3(20, 0, 5))
	for i in range(holders.size()):
		assert_eq(dead.list[i + 1], holders[i])


func test_hash_queries_handle_negative_cells_and_do_not_return_the_whole_field() -> void:
	var bodies: Array = []
	for x in range(-15, 15):
		for z in range(-15, 15):
			bodies.append({"state": "wander", "pos": Vector3(x * 20.0 - 0.1, 0, z * 20.0 - 0.1)})
	var floor_of := func(at: Vector3) -> int: return roundi(at.y / 3.0)
	var cells := Sense.index(bodies, floor_of, Zombies.HERD)
	var near := Sense.neighbours(cells, Vector3.ZERO, 0, Zombies.HERD, Zombies.HERD)
	assert_gte(near.size(), 1)
	assert_lte(near.size(), 9)
	assert_eq(Sense.cell(Vector3(-0.1, 0, -0.1), 0, 8.0), Vector3i(-1, 0, -1))
	assert_true(Sense.neighbours(cells, Vector3.ZERO, 1, 8.0, 8.0).is_empty())


func test_movement_padding_keeps_a_body_crossing_a_hash_boundary_in_candidates() -> void:
	var z := {"state": "wander", "pos": Vector3(16.01, 0, 0)}
	var cells := Sense.index([z], func(_at: Vector3) -> int: return 0, 8.0)
	z["pos"] = Vector3(15.99, 0, 0)
	var near := Sense.neighbours(cells, Vector3(7.99, 0, 0), 0, 8.0, 8.1)
	assert_true(near.has(z))


func test_noise_pressure_preserves_a_guaranteed_quiet_interval() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var director = Director.new(rng)
	director.quiet_until = 100.0
	director.last_arrival = 0.0
	director.add_noise(1000, 10.0)
	assert_eq(director.next_arrival, 100.0)
	assert_true(director.update(99.0).is_empty())
	assert_false(director.update(100.0).is_empty())
