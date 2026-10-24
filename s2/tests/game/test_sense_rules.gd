extends "res://addons/gut/test.gd"

const Rules = preload("res://game/sim/sense_rules.gd")
const Zombies = preload("res://game/actors/zombies.gd")
const Weather = preload("res://game/sim/weather.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")

class SightGrid extends RefCounted:
	var sight_clear := true
	var body_clear := true
	func line_clear(_a, _b) -> bool: return sight_clear
	func body_line_clear(_a, _b) -> bool: return body_clear

class SightClock extends RefCounted:
	var elapsed := 0.0
	var dark := false
	func is_dark() -> bool: return dark

class Subject extends RefCounted:
	var position := Vector3(5.5, 0, 10.5)
	var moving := false
	var running := false
	var crouched := false
	var smell := 0
	func smell_mult() -> float: return 1.0
	func is_running_now() -> bool: return moving and running
	func is_alive() -> bool: return true

class SightWorld extends RefCounted:
	var rng := RandomNumberGenerator.new()
	var opts := {"seed": 1}
	var weather = Weather.new([])
	var clock := SightClock.new()
	var grid := SightGrid.new()
	func level_of(at: Vector3) -> int: return roundi(at.y / 3.0)
	func level_y(level_id: int) -> float: return level_id * 3.0
	func grid_at(_at: Vector3): return grid
	func strongest_scent(_at: Vector3) -> Dictionary: return {}

class DoorWorld extends RefCounted:
	var rng := RandomNumberGenerator.new()
	var grid = FieldGrid.new(32, 32)
	var player := Subject.new()
	var bangs := 0
	func level_of(at: Vector3) -> int: return roundi(at.y / 3.0)
	func level_y(level_id: int) -> float: return level_id * 3.0
	func grid_at(_at: Vector3): return grid
	func on_door_banged(_cell, _by) -> void: bangs += 1
	func find_path(_from: Vector3, to: Vector3, _dead: bool = false) -> PackedVector3Array:
		return PackedVector3Array([to])


func _dead():
	var dead = Zombies.new()
	dead.game = SightWorld.new()
	dead.game.rng.seed = 3
	add_child_autofree(dead)
	return dead


func _one(dead) -> Dictionary:
	var z: Dictionary = dead.spawn("dead", Vector3(5.5, 0, 5.5))
	z["angle"] = 0.0
	return z


func test_posture_uses_real_motion_and_preserves_crouch() -> void:
	assert_eq(Rules.posture_mult(false, false, true), 0.8, "a run toggle while stopped is still stopped")
	assert_eq(Rules.posture_mult(false, true, false), 1.0)
	assert_eq(Rules.posture_mult(false, true, true), 1.5)
	assert_eq(Rules.posture_mult(true, false, false), 0.55)
	assert_eq(Rules.posture_mult(true, true, false), 0.55)


func test_weather_and_posture_change_actual_discovery_range() -> void:
	var dead = _dead()
	var z := _one(dead)
	var p := Subject.new()
	p.position = z["pos"] + Vector3(0, 0, 8.0)
	dead._sense(z, [p], 0.2)
	assert_eq(z["state"], "wander", "standing 8m away exceeds 9 * .8")
	p.moving = true
	dead._sense(z, [p], 0.2)
	assert_eq(z["state"], "chase", "walking can be seen at 8m")
	z["state"] = "wander"
	z["victim"] = null
	dead.game.weather = Weather.new(["fog"])
	dead._sense(z, [p], 0.2)
	assert_eq(z["state"], "wander", "fog cuts walking range to 5.4m")
	p.running = true
	dead._sense(z, [p], 0.2)
	assert_eq(z["state"], "chase", "running in fog reaches 8.1m")
	assert_almost_eq(Weather.new(["fog", "snow"]).sight_mult(), 0.72, 0.000001)
	assert_almost_eq(Weather.new(["clear"]).sight_mult(true), 0.55, 0.000001)
	assert_almost_eq(Weather.new(["blizzard"]).sight_mult(true), 0.4, 0.000001)


func test_close_sense_cannot_see_through_a_wall_or_touch_through_glass() -> void:
	var dead = _dead()
	var z := _one(dead)
	var p := Subject.new()
	p.position = z["pos"] + Vector3(0, 0, -0.7)
	dead.game.grid.sight_clear = false
	dead.game.grid.body_clear = false
	dead._sense(z, [p], 0.2)
	assert_eq(z["state"], "wander", "nearby does not reveal somebody behind a wall")
	dead.game.grid.sight_clear = true
	dead._sense(z, [p], 0.2)
	assert_eq(z["state"], "wander", "glass blocks all-round touch behind the body")
	p.position = z["pos"] + Vector3(0, 0, 0.7)
	dead._sense(z, [p], 0.2)
	assert_eq(z["state"], "chase", "front glass permits sight, but not attack")


func test_lost_memory_counts_seconds_at_both_tick_rates() -> void:
	for hz in [30, 60]:
		var dead = _dead()
		var z := _one(dead)
		z["state"] = "chase"
		z["last_seen"] = z["pos"] + Vector3(0, 0, 20)
		for i in range(roundi(7.5 * hz)):
			dead._sense(z, [], 1.0 / hz)
		assert_eq(z["state"], "chase", "7.5 real seconds, not per-frame increments")
		assert_almost_eq(float(z["seen_t"]), 7.5, 0.00001)
		for i in range(hz):
			dead._sense(z, [], 1.0 / hz)
		assert_eq(z["state"], "wander", "8 seconds plus at most one sensing interval")
		assert_eq(z["target"], z["pos"], "expired memory does not leave a pursuit path")
		assert_true(z["path"].is_empty())


func test_chase_sampling_does_not_roll_the_random_stream_every_frame() -> void:
	var dead = _dead()
	var z := _one(dead)
	z["state"] = "chase"
	z["last_seen"] = z["pos"] + Vector3(0, 0, 20)
	z["sense_t"] = 0.15
	var saved: int = dead.game.rng.state
	dead._sense(z, [], 1.0 / 60.0)
	assert_eq(dead.game.rng.state, saved)
	assert_almost_eq(float(z["seen_t"]), 1.0 / 60.0, 0.00001)


func test_unseen_stairs_do_not_reveal_a_person_on_another_floor() -> void:
	var dead = _dead()
	var z := _one(dead)
	var p := Subject.new()
	z["state"] = "chase"
	z["victim"] = p
	z["last_seen"] = z["pos"] + Vector3(0, 0, 3)
	p.position = z["last_seen"] + Vector3(0, 3, 0)
	var last: Vector3 = z["last_seen"]
	dead._sense(z, [p], 0.2)
	assert_eq(z["last_seen"], last)
	assert_eq(z["target"], last)


func test_sound_travel_expires_but_arrival_keeps_the_original_linger() -> void:
	var dead = _dead()
	var z := _one(dead)
	var target: Vector3 = z["pos"] + Vector3(0, 0, 20)
	dead.hear(target, SimNoise.Level.NORMAL, 30.0)
	assert_eq(z["clue_left"], 30.0)
	z["turn_t"] = 100.0
	dead._move(z, 29.0)
	assert_eq(z["state"], "investigate")
	dead._move(z, 1.01)
	assert_eq(z["state"], "search", "an unreachable sound is not followed forever")
	dead.hear(z["pos"], SimNoise.Level.NORMAL, 3.0)
	dead._move(z, 1.0)
	assert_eq(z["linger"], 29.0, "arrival still gets the planned 30-second linger")
	assert_eq(z["clue_left"], 30.0)


func test_weaker_sound_does_not_refresh_or_replace_a_stronger_trip() -> void:
	var dead = _dead()
	var z := _one(dead)
	var loud: Vector3 = z["pos"] + Vector3(0, 0, 20)
	dead.hear(loud, SimNoise.Level.LOUD, 30.0)
	z["clue_left"] = 2.0
	dead.hear(z["pos"] + Vector3(5, 0, 0), SimNoise.Level.NORMAL, 30.0)
	assert_eq(z["target"], loud)
	assert_eq(z["clue_left"], 2.0)


func test_closed_door_holds_a_body_while_the_original_bang_timer_runs() -> void:
	var dead = Zombies.new()
	dead.game = DoorWorld.new()
	add_child_autofree(dead)
	var c := Vector2i(10, 5)
	dead.game.grid.doors[c] = {"state": "closed", "hp": 3, "building": -1, "key": ""}
	dead.game.grid.set_solid(c, FieldGrid.Solid.DOOR)
	var z: Dictionary = dead.spawn("dead", Vector3(9.98, 0, 5.5))
	z["state"] = "chase"
	z["target"] = Vector3(11.5, 0, 5.5)
	z["path"] = PackedVector3Array([z["target"]])
	z["path_t"] = 100.0
	dead._move(z, 0.1)
	assert_eq(dead.game.bangs, 1)
	assert_true(z["pos"].x < 10.0, "thumping is not permission to enter a closed door")
	for i in range(12): dead._move(z, 0.1)
	assert_eq(dead.game.bangs, 1)
	dead._move(z, 0.11)
	assert_eq(dead.game.bangs, 2, "the existing 1.3-second interval is unchanged")
	assert_eq(dead.game.grid.doors[c]["hp"], 3, "movement itself does not damage the door")
	dead.game.grid.set_door_state(c, "broken")
	dead._move(z, 0.1)
	assert_true(z["pos"].x > 10.0, "a broken doorway can be entered")
