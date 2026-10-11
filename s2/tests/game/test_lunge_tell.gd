extends "res://addons/gut/test.gd"
## The tell of the dead that lunge, on the field's side: it is voiced when it
## begins, marked for as long as it lasts and only in sight, and it is not a
## sound of the stop (nothing is scored, no rule hears it).

const FieldGame = preload("res://game/field_game.gd")
const LungerRules = preload("res://game/sim/lunger_rules.gd")

const TICK: float = 1.0 / 60.0

var game


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false, LungerRules.OPTION: true}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	game.mask_on = false
	game.player.position = game.lift(Vector2i(60, 7), 0)
	for q in game.squad:
		if q != game.player:
			q.position = game.lift(Vector2i(30, 7), 0)


func _lunger(far: float) -> Dictionary:
	var z: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(far, 0, 0))
	z["lunger"] = true
	z["stander"] = true
	z["t"] = 99.0
	z["angle"] = atan2(game.player.position.x - z["pos"].x, game.player.position.z - z["pos"].z)
	return z


func _run(seconds: float) -> void:
	for n in int(round(seconds / TICK)):
		game.zombies.update(TICK)


func test_it_is_voiced_once_and_marked_while_it_stays_low() -> void:
	var z := _lunger(6.0)
	var noise: int = game.ledger.total
	var heard: int = game.sounds.size()
	_run(0.3)
	assert_eq(z["state"], "tell")
	assert_eq(game.audio.played.count(game.audio.TELL_GROUP), 1)
	assert_eq(game.hud.tells(), [z])
	assert_eq(game.ledger.total, noise, "it is not scored as a sound of the stop")
	assert_eq(game.sounds.size(), heard, "and no rule hears it")
	_run(LungerRules.TELL)
	assert_ne(z["state"], "tell")
	assert_eq(game.hud.tells(), [], "the mark goes when it runs")
	assert_eq(game.audio.played.count(game.audio.TELL_GROUP), 1)


func test_out_of_sight_it_is_not_marked() -> void:
	var z := _lunger(6.0)
	_run(0.3)
	assert_eq(z["state"], "tell")
	game.mask_on = true
	game.seen_now.clear()
	assert_eq(game.hud.tells(), [], "the dead behind the fog are not shown")
	game.seen_now[game.seen_key(z["pos"])] = true
	assert_eq(game.hud.tells(), [z])
