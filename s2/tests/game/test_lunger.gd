extends "res://addons/gut/test.gd"
## The dead that lunge (user 2026-10-12): one in ten of those that stand, and
## one in ten of whoever died at this stop. Seeing a person within 8 m it drops low for 1.2 s,
## runs straight for 3 s and is spent for 6 s. Once. Two at a time. Off unless
## the field is started with opts["lungers"].

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const Zombies = preload("res://game/actors/zombies.gd")
const LungerRules = preload("res://game/sim/lunger_rules.gd")

const TICK: float = 1.0 / 60.0

var game


func _start(lungers) -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	if lungers != null:
		game.opts[LungerRules.OPTION] = lungers
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	game.mask_on = false
	game.player.position = game.lift(Vector2i(60, 7), 0)
	for q in game.squad:
		if q != game.player:
			q.position = game.lift(Vector2i(30, 7), 0)


## One of the dead that lunges, standing that far from the player and facing them.
func _lunger(far: float, side: float = 0.0) -> Dictionary:
	var z: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(far, 0, side))
	z["lunger"] = true
	z["stander"] = true
	z["t"] = 99.0
	z["angle"] = atan2(game.player.position.x - z["pos"].x, game.player.position.z - z["pos"].z)
	return z


func _run(seconds: float) -> void:
	for n in int(round(seconds / TICK)):
		game.zombies.update(TICK)


func _floor(z: Dictionary) -> float:
	return float(FieldGrid.FLOOR_SPEED[game.grid_at(z["pos"]).floor_at(FieldGrid.cell_of(z["pos"]))])


func test_left_off_nobody_lunges_and_the_fights_dice_are_not_touched() -> void:
	_start(null)
	assert_false(game.zombies.lungers_on)
	var before: int = game.rng.state
	for n in 40:
		game.zombies.spawn("dead", game.player.position + Vector3(20, 0, 0))
	var off_state: int = game.rng.state
	for z in game.zombies.list:
		assert_false(z.has("lunger"), "nothing is noted on the body")
	var risen: Dictionary = game.zombies.add_rising(game.player.position + Vector3(20, 0, 0), "")
	assert_false(risen["lunger"])
	assert_ne(before, off_state)
	_start(true)
	for n in 40:
		game.zombies.spawn("dead", game.player.position + Vector3(20, 0, 0))
	assert_eq(game.rng.state, off_state, "picking who lunges takes nothing from the game's dice")


func test_one_in_ten_of_those_that_stand_and_one_in_ten_of_whoever_died_here() -> void:
	_start(true)
	var lungers := 0
	var standers := 0
	for n in 2000:
		var z: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(20, 0, 0))
		standers += 1 if z["stander"] else 0
		if z["lunger"]:
			lungers += 1
			assert_true(z["stander"], "only one that stands")
	assert_between(float(lungers) / float(standers), 0.06, 0.14)
	assert_false(game.zombies.spawn("frozen", game.player.position + Vector3(20, 0, 0)).has("lunger"), "not the frozen")
	for n in 60:
		assert_false(game.zombies.spawn("dead", game.player.position + Vector3(20, 0, 0), {"target": game.player.position}).has("lunger"), "nor one sent in with a horde")
	var risen := 0
	for n in 2000:
		if game.zombies.add_rising(game.player.position + Vector3(20, 0, 0), "")["lunger"]:
			risen += 1
	assert_between(float(risen) / 2000.0, 0.06, 0.14, "one in ten of those that died here and got up, not all of them")


func test_it_drops_low_runs_straight_and_is_spent_once() -> void:
	_start(true)
	var z := _lunger(5.0)
	var stood: Vector3 = z["pos"]
	_run(0.3)
	assert_eq(z["state"], "tell", "seen within reach: the tell")
	assert_true(z["lunged"])
	_run(LungerRules.TELL - 0.4)
	assert_eq(z["state"], "tell")
	assert_eq(z["pos"], stood, "it does not move in the tell")
	# The person steps well aside as it goes: it runs at where they stood.
	_run(0.2)
	assert_eq(z["state"], "chase")
	assert_gt(float(z["dash_t"]), 0.0)
	var dir: Vector3 = z["dash_dir"]
	assert_almost_eq(dir.x, -1.0, 0.01)
	game.player.position = game.player.position + Vector3(0, 0, 40)
	var from: Vector3 = z["pos"]
	var floor_k := _floor(z)
	_run(1.0)
	var gone: Vector3 = z["pos"] - from
	assert_almost_eq(gone.length(), LungerRules.DASH_SPEED * floor_k, 0.4, "at the run's speed")
	assert_almost_eq(gone.z, 0.0, 0.05, "and in a straight line, not after the person")
	_run(LungerRules.DASH)
	assert_eq(float(z["dash_t"]), 0.0)
	assert_gt(float(z["spent_t"]), 0.0)
	z["state"] = "chase"
	assert_almost_eq(game.zombies._speed(z), LungerRules.SPENT_SPEED * _floor(z), 0.001)
	_run(LungerRules.SPENT + 0.1)
	assert_eq(float(z["spent_t"]), 0.0)
	z["state"] = "chase"
	assert_almost_eq(game.zombies._speed(z), Zombies.SPEED_HURRY * _floor(z), 0.001, "then as it was")
	# Seeing them again, it does not do it a second time.
	z["state"] = "wander"
	z["pos"] = game.player.position + Vector3(5, 0, 0)
	z["angle"] = -PI / 2.0
	_run(0.5)
	assert_ne(z["state"], "tell")
	assert_eq(float(z["dash_t"]), 0.0)


func test_no_more_than_two_at_a_time_and_the_field_is_told() -> void:
	_start(true)
	var four: Array = []
	for n in 4:
		four.append(_lunger(6.0, float(n) - 1.5))
	_run(0.3)
	var telling := 0
	for z in four:
		telling += 1 if z["state"] == "tell" else 0
	assert_eq(telling, LungerRules.AT_ONCE)
	for z in four:
		if z["state"] != "tell":
			assert_false(z.get("lunged", false), "the others keep theirs for later")
			assert_eq(z["state"], "chase", "and come on as the dead do")


func test_struck_in_the_tell_it_does_not_run() -> void:
	_start(true)
	var z := _lunger(5.0)
	_run(0.3)
	assert_eq(z["state"], "tell")
	z["stun"] = 0.5
	_run(0.1)
	assert_eq(z["state"], "chase")
	assert_eq(float(z["dash_t"]), 0.0)
	assert_gt(float(z["spent_t"]), 0.0)
	# Shoved out of it, the same.
	var other := _lunger(5.0, 2.0)
	_run(0.3)
	assert_eq(other["state"], "tell")
	game.zombies.release(other, game.player.position, false)
	_run(2.0)
	assert_eq(float(other["dash_t"]), 0.0)
	assert_gt(float(other["spent_t"]), 0.0)


func test_too_far_off_it_comes_on_as_the_dead_do() -> void:
	_start(true)
	var z := _lunger(LungerRules.SEES + 0.6)
	_run(0.3)
	if z["state"] == "chase":
		assert_false(z.get("lunged", false))
	else:
		assert_ne(z["state"], "tell")
