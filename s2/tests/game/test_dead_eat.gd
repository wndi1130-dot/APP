extends "res://addons/gut/test.gd"
## Decision 423, card 4: the dead eat the bodies of the living. The wandering
## dead near a body come to it and kneel to eat; eating they see half as far
## and hear as ever; a body still gets up as before, and then they stop.

const FieldGame = preload("res://game/field_game.gd")
const EatRules = preload("res://game/sim/eat_rules.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const SimNoise = preload("res://game/sim/noise.gd")

var game
var body                     # the one of the living who died


func before_each() -> void:
	DeadBody.table = []
	DeadBody.named = {}
	game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	for q in game.squad:
		if q != game.player:
			body = q
			break
	body.position = game.player.position + Vector3(0, 0, -20)
	game.on_person_died(body)


func after_all() -> void:
	DeadBody.table = []
	DeadBody.named = {}


func _dead_at(at: Vector3, state: String = "wander") -> Dictionary:
	var z: Dictionary = game.zombies.spawn("dead", at)
	z["state"] = state
	z["home"] = at
	z["target"] = at
	z["sense_t"] = 0.0
	return z


func _look(z: Dictionary) -> void:
	game.zombies._food = game.zombies._edible_bodies()
	z["sense_t"] = 0.0
	game.zombies._sense(z, game.people_alive(), 0.1)


func _rising() -> Dictionary:
	return game.zombies.find(int(body.brain["rising_id"]))


func test_a_body_lying_there_can_be_eaten_until_it_gets_up() -> void:
	assert_true(body.body.dead)
	assert_eq(String(_rising()["state"]), "rising")
	assert_has(game.zombies._edible_bodies(), body, "dead and not up yet")
	_rising()["state"] = "wander"
	assert_false(game.zombies._edible_bodies().has(body), "up again: gone")
	assert_true(EatRules.edible(body, {"state": "dead"}), "put down for good, it lies there")
	assert_false(EatRules.edible(game.player, {}), "one of the living alive is not eaten")


func test_the_wandering_dead_near_a_body_come_to_it_and_kneel_to_eat() -> void:
	var near := _dead_at(body.position + Vector3(6, 0, 0))
	var far := _dead_at(body.position + Vector3(EatRules.GATHER_R + 2.0, 0, 0))
	_look(near)
	_look(far)
	assert_eq(String(near["state"]), "investigate", "within reach of it, it comes")
	assert_eq(String(near.get("clue_kind", "")), "food")
	assert_eq(String(far["state"]), "wander", "further off it does not")
	# At the body it kneels to eat, facing it.
	near["pos"] = body.position + Vector3(1.0, 0, 0)
	game.zombies._move(near, 0.1)
	assert_eq(String(near["state"]), "eat")
	assert_almost_eq(float(near["angle"]), atan2(-1.0, 0.0), 0.01)
	# Eating, it stays where it is.
	var at: Vector3 = near["pos"]
	game.zombies._move(near, 0.5)
	assert_eq(near["pos"], at)
	assert_true("eat" in game.zombies.SEPARATION_EXCLUDED, "and is not pushed off it by the others")


func test_so_many_eat_at_one_body_and_the_rest_stand_round_it() -> void:
	var eaters: Array = []
	for i in EatRules.AT_MOST + 1:
		var z := _dead_at(body.position + Vector3(0.8, 0, 0.2 * i), "investigate")
		z["clue_kind"] = "food"
		z["target"] = body.position
		z["linger"] = 3.0
		z["eat_of"] = body.get_instance_id()
		eaters.append(z)
	game.zombies._food = game.zombies._edible_bodies()
	for z in eaters:
		game.zombies._move(z, 0.1)
	var eating := eaters.filter(func(z): return z["state"] == "eat")
	assert_eq(eating.size(), EatRules.AT_MOST)
	assert_eq(String(eaters[-1]["state"]), "investigate", "the last stands by")


func test_eating_it_sees_half_as_far_and_hears_as_ever() -> void:
	var p = game.player
	# How far one wandering sees the player standing in front of it, the most
	# open of four ways round the player.
	var seen := 0.0
	var way := Vector3.ZERO
	for dir in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var d := 2.0
		while d < 14.0:
			var w := _dead_at(p.position + dir * d)
			w["angle"] = atan2(-dir.x, -dir.z)   # facing the player
			_look(w)
			if w["state"] == "chase" and d > seen:
				seen = d
				way = dir
			game.zombies.list.erase(w)
			d += 0.25
	assert_gt(seen, 2.0, "it sees the player some way off")
	var eater := _dead_at(p.position + way * seen * 0.75, "eat")
	eater["angle"] = atan2(-way.x, -way.z)
	eater["eat_of"] = body.get_instance_id()
	_look(eater)
	assert_eq(String(eater["state"]), "eat", "three quarters of the way: eating, it does not see")
	var close := _dead_at(p.position + way * maxf(seen * 0.4, 0.5), "eat")
	close["angle"] = atan2(-way.x, -way.z)
	close["eat_of"] = body.get_instance_id()
	_look(close)
	assert_eq(String(close["state"]), "chase", "close enough it does")
	# A sound pulls it off as it does the others.
	game.zombies.hear(eater["pos"] + Vector3(3, 0, 0), SimNoise.Level.LOUD, 20.0)
	assert_eq(String(eater["state"]), "investigate")
	assert_eq(String(eater.get("clue_kind", "")), "sound")


func test_it_stops_when_the_body_gets_up_and_goes_back_when_pushed_off() -> void:
	var z := _dead_at(body.position + Vector3(1.0, 0, 0), "eat")
	z["eat_of"] = body.get_instance_id()
	game.zombies._food = game.zombies._edible_bodies()
	z["pos"] = body.position + Vector3(EatRules.LEAVE_R + 0.5, 0, 0)
	game.zombies._keep_eating(z)
	assert_eq(String(z["state"]), "investigate", "pushed off it, it goes back")
	assert_eq(String(z["clue_kind"]), "food")
	z["state"] = "eat"
	z["pos"] = body.position + Vector3(1.0, 0, 0)
	_rising()["rise_t"] = 0.01
	game.zombies.update(0.05)
	assert_eq(String(_rising()["state"]), "wander", "the body is up")
	game.zombies.update(0.05)
	assert_eq(String(z["state"]), "wander", "and it stops eating")
	assert_true(z.has("ate_until"))
	# Decision 429: it gets up from the body before it does anything else.
	assert_eq(String(z["state"]), "wander")
	assert_almost_eq(Vector3(z["pos"]).distance_to(z["target"]), 0.0, 0.01, "it stands where it ate a while (wander keeps it there)")
	DeadBody.table = []
	for i in 30:
		DeadBody.table.append([i * 32, 32, true, 1.0])
	DeadBody.named = {"eat_start": 27, "eat": 28, "eat_rise": 29}
	z["body_at"] = z["pos"]
	assert_eq(DeadBody.motion_in(DeadBody.custom(z, 0.0, 0.0, 1.0, true).g), 29, "and is drawn getting up from it")


func test_an_eater_can_be_struck_down_as_any() -> void:
	var z := _dead_at(body.position + Vector3(1.0, 0, 0), "eat")
	z["eat_of"] = body.get_instance_id()
	game.zombies.knock_down(z)
	assert_eq(String(z["state"]), "downed")
	var y := _dead_at(body.position + Vector3(-1.0, 0, 0), "eat")
	y["eat_of"] = body.get_instance_id()
	assert_true(game.zombies.active(y), "it is one of the dead like any other")
	assert_true(game.zombies.threat(y))


func test_eating_is_drawn_going_down_on_and_on_and_getting_up() -> void:
	DeadBody.table = []
	for i in 30:
		DeadBody.table.append([i * 32, 32, true, 1.0])
	DeadBody.named = {"eat_start": 27, "eat": 28, "eat_rise": 29}
	var z := {"state": "eat", "phase": 0.2, "crawl": false, "age": 10.0, "pos": Vector3.ZERO, "angle": 0.0, "t": 0.0, "eat_at": 9.5}
	var c := DeadBody.custom(z, 0.0, 0.0, 1.0, true)
	assert_eq(DeadBody.motion_in(c.g), 27, "going down to it")
	assert_almost_eq(c.r, 0.5, 0.001)
	z["age"] = 11.0
	assert_eq(DeadBody.motion_in(DeadBody.custom(z, 0.0, 0.0, 1.0, true).g), 28, "then eating")
	z["state"] = "wander"
	z["ate_until"] = 11.0
	z["age"] = 11.25
	var up := DeadBody.custom(z, 0.0, 0.0, 1.0, true)
	assert_eq(DeadBody.motion_in(up.g), 29, "getting up from it")
	assert_almost_eq(up.r, 0.25, 0.001)
	DeadBody.named = {}
	var old := {"state": "eat", "phase": 0.2, "crawl": false, "age": 10.0, "pos": Vector3.ZERO, "angle": 0.0, "t": 0.0, "eat_at": 9.5}
	assert_eq(DeadBody.motion_in(DeadBody.custom(old, 0.0, 0.0, 1.0, true).g), DeadBody.STAND, "a folder without them: it stands as it did")
