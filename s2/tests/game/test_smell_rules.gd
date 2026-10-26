extends "res://addons/gut/test.gd"
## Smell (body_injury 8.1): the body's smell on how far the dead notice it,
## one step further downwind, and the blood event's values in one place.

const FieldGame = preload("res://game/field_game.gd")
const SmellRules = preload("res://game/sim/smell_rules.gd")

var game


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()


func test_body_smell_steps_and_one_more_downwind() -> void:
	assert_eq([SmellRules.body_mult(0, false), SmellRules.body_mult(1, false), SmellRules.body_mult(2, false)], [1.0, 1.25, 1.5])
	assert_eq([SmellRules.body_mult(0, true), SmellRules.body_mult(1, true), SmellRules.body_mult(2, true)], [1.0, 1.5, 1.75], "a clean body has nothing for the wind to carry")


func test_downwind_is_the_blood_events_sixty_degrees() -> void:
	var at := Vector3(10, 0, 10)
	assert_true(SmellRules.downwind(0.4, Vector2(1, 0), at, at + Vector3(5, 0, 0)))
	assert_true(SmellRules.downwind(0.4, Vector2(1, 0), at, at + Vector3(5, 0, 4)), "39 degrees off")
	assert_false(SmellRules.downwind(0.4, Vector2(1, 0), at, at + Vector3(5, 0, 9)), "61 degrees off")
	assert_false(SmellRules.downwind(0.4, Vector2(1, 0), at, at + Vector3(-5, 0, 0)), "upwind")
	assert_false(SmellRules.downwind(0.0, Vector2(1, 0), at, at + Vector3(5, 0, 0)), "no wind")


func _trail_game(kinds: Array, air: float):
	var g = FieldGame.new()
	g.opts = {"seed": 11, "raiders": false, "auto_pause": false, "weather": kinds, "ambient_c": air}
	add_child_autofree(g)
	g.set_process(false)
	g.blood.clear()
	g.blood.append({"pos": Vector3(40.5, 0, 7.5), "t": g.clock.elapsed, "s": 2})
	return g


func test_rain_washes_the_trail_to_half_its_pull() -> void:
	# Sideways to the wind, above zero: 12 x 0.9 = 10.8 m dry, 5.4 m in the rain.
	var dry = _trail_game(["fog"], 4.0)
	var wet = _trail_game(["rain"], 4.0)
	assert_true(wet.weather.kinds.has("rain"))
	var at := Vector3(40.5, 0, 15.5)
	assert_false(dry.strongest_scent(at).is_empty(), "8 m off, dry: smelled")
	assert_true(wet.strongest_scent(at).is_empty(), "8 m off, rain: washed")
	assert_false(wet.strongest_scent(Vector3(40.5, 0, 12.5)).is_empty(), "5 m off, rain: still there")


func test_the_blood_event_values_are_the_fields() -> void:
	assert_eq(FieldGame.BLOOD_SCENT_R, SmellRules.EVENT_R)


## The dead facing +z; the body beside it, out of its cone, so only the feel at arm's reach can find it.
func _feels(body_offset: Vector3, smell: int) -> bool:
	var z: Dictionary = game.zombies.spawn("dead", Vector3(40.5, 0, 7.5))
	z["angle"] = 0.0
	z["sense_t"] = 0.0
	var p = game.player
	for q in game.squad:
		if q != p:
			q.position = game.lift(Vector2i(130, 7), 0)
	p.position = z["pos"] + body_offset
	p.smell = smell
	game.zombies._sense(z, [p], 0.1)
	var found: bool = z["state"] == "chase" and z["victim"] == p
	game.zombies.list.erase(z)
	return found


func test_a_strong_smell_is_felt_further_at_arms_reach() -> void:
	# The wind blows toward +x here: a body to the east is upwind of the dead.
	assert_gt(game.weather.wind_dir.x, 0.9)
	assert_gt(game.weather.wind, 0.0)
	assert_false(_feels(Vector3(2.4, 0, 0), 0), "clean: 1.8 m")
	assert_true(_feels(Vector3(2.4, 0, 0), 2), "stench: 2.7 m")
	assert_false(_feels(Vector3(2.4, 0, 0), 1), "sweat upwind: 2.25 m")
	assert_true(_feels(Vector3(-2.4, 0, 0), 1), "sweat downwind is one step on: 2.7 m")


func test_the_blood_event_is_marked_as_a_smell() -> void:
	var z: Dictionary = game.zombies.spawn("dead", Vector3(40.5, 0, 7.5))
	assert_eq(game.zombies.smell(Vector3(34.5, 0, 7.5), SmellRules.EVENT_R), 1)
	assert_eq(String(z["clue_kind"]), "scent")
	assert_eq(float(z["linger"]), SmellRules.LINGER)
