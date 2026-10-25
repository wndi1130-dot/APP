extends "res://addons/gut/test.gd"
## A companion sent to the train climbs in (the user's field test 2026-10-25, 14): to the door the
## dead crowd least, a moment to climb up, then inside and out of their reach;
## one at arm's length is shoved off first, and an order to do something else
## brings it out again at that door.

const FieldGame = preload("res://game/field_game.gd")
const FieldAi = preload("res://game/field_ai.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")

var game
var ally


func _start() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	game.mask_on = false
	game.player.position = game.lift(Vector2i(60, 9), 0)
	ally = null
	for q in game.squad:
		if q != game.player:
			q.position = game.lift(Vector2i(30, 9), 0)
			if ally == null:
				ally = q
	ally.command = "retreat"


func _door(i: int) -> Vector3:
	return FieldGrid.center(game.data["spawns"]["train_door"][i])


func _climb(cap: float = 10.0) -> float:
	var t := 0.0
	while ally.action == "board" and t < cap:
		game._update_person(ally, 0.05)
		t += 0.05
	return t


func test_at_the_door_it_climbs_in_and_is_out_of_reach() -> void:
	_start()
	var door := _door(0)
	ally.position = door + Vector3(0, 0, 1.0)
	game.ai._companion(ally)
	assert_eq(ally.action, "board", "it climbs")
	assert_true(bool(ally.brain.get("boarding", false)), "the door guard can see it is climbing")
	assert_false(bool(ally.brain.get("boarded", false)))
	_climb()
	assert_eq(ally.action, "")
	assert_true(bool(ally.brain.get("boarded", false)))
	assert_false(ally.brain.has("boarding"))
	assert_true(game.aboard(ally))
	assert_lt(ally.position.y, -40.0, "inside, where the dead do not reach (as the work crew)")
	assert_ne(game.level_of(ally.position), game.level_of(door))
	game.ai._companion(ally)
	assert_lt(ally.position.y, -40.0, "it stays in while the order stands")


func test_far_off_it_walks_to_the_door_first() -> void:
	_start()
	ally.position = _door(0) + Vector3(0, 0, 6.0)
	game.ai._companion(ally)
	assert_ne(ally.action, "board")
	assert_false(ally.path.is_empty(), "on its way")


func test_a_crowded_door_sends_it_to_another() -> void:
	_start()
	var near := _door(0)
	ally.position = near + Vector3(0, 0, 2.0)
	assert_true(game.ai._board_door(ally).is_equal_approx(near), "the nearest when none are by it")
	ally.brain.erase("board_door")
	for k in 3:
		game.zombies.spawn("dead", near + Vector3(0.6 * k - 0.6, 0, -0.8))
	assert_false(game.ai._board_door(ally).is_equal_approx(near), "three of the dead by it: another door")


func test_one_at_arms_length_is_shoved_off_before_it_climbs() -> void:
	_start()
	var door := _door(0)
	ally.position = door + Vector3(0, 0, 1.0)
	var z: Dictionary = game.zombies.spawn("dead", ally.position + Vector3(1.0, 0, 0))
	z["state"] = "chase"
	z["victim"] = ally
	game.ai._companion(ally)
	assert_ne(ally.action, "board", "no turning its back on it")
	assert_gt(ally.swing_t, 0.0, "shoved")


func test_another_order_brings_it_out_at_its_door() -> void:
	_start()
	var door := _door(0)
	ally.position = door + Vector3(0, 0, 1.0)
	game.ai._companion(ally)
	_climb()
	assert_true(bool(ally.brain.get("boarded", false)))
	game.hud._command(ally, "follow")
	game.ai._companion(ally)
	assert_almost_eq(ally.position.distance_to(door), 0.0, 0.01, "out at the door it went in by")
	assert_false(ally.brain.has("board_at"))


func test_an_order_given_mid_climb_leaves_it_outside() -> void:
	_start()
	var door := _door(0)
	ally.position = door + Vector3(0, 0, 1.0)
	game.ai._companion(ally)
	assert_eq(ally.action, "board")
	game.hud._command(ally, "follow")
	_climb()
	assert_false(bool(ally.brain.get("boarded", false)), "it was called back before it was in")
	assert_gt(ally.position.y, -1.0)
