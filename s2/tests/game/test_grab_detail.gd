extends "res://addons/gut/test.gd"

const FieldGame = preload("res://game/field_game.gd")
const Rules = preload("res://game/sim/grab_rules.gd")

var game


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	game.player.position = game.lift(Vector2i(60, 7), 0)
	game.player.facing = 0.0


func _hand() -> Dictionary:
	return game.zombies.spawn("dead", game.player.position + Vector3(0, 0, 0.6))


func _roll_grab(z: Dictionary) -> String:
	var rng := RandomNumberGenerator.new()
	for value in range(1, 100):
		rng.seed = value
		if rng.randf() < Rules.GRAB_SHARE:
			game.rng.seed = value
			break
	return game.combat.zombie_reaches(z, game.player)


func test_front_back_side_and_prone_keep_the_planned_windows() -> void:
	assert_true(Rules.front_contact(0.0, Vector3(0, 0, 1)))
	assert_false(Rules.front_contact(0.0, Vector3(0, 0, -1)))
	assert_false(Rules.front_contact(0.0, Vector3(1, 0, 0)))
	assert_false(Rules.front_contact(0.0, Vector3(0, 0, 1), true))
	assert_eq(Rules.window(true, 1, 0, 5), 1.5)
	assert_eq(Rules.window(false, 1, 0, 5), 0.75)
	assert_eq(Rules.window(true, 2, 10, 10), 0.0)
	game.player.fallen_t = 1.0
	assert_eq(_roll_grab(_hand()), "grab")
	assert_false(game.player.grab_front)
	var p = game.player
	assert_almost_eq(p.grab_left, Rules.window(false, 1, p.skills["melee"], p.skills["strength"], p.mults()["shove_window"]), 0.00001)


func test_last_release_protects_the_person_from_every_grabber_until_deadline() -> void:
	var z := _hand()
	assert_eq(_roll_grab(z), "grab")
	game.zombies.release(z, game.player.position, false)
	assert_true(game.player.grabbers.is_empty())
	game.clock.elapsed = Rules.REGRAB_GRACE - 0.01
	assert_eq(_roll_grab(_hand()), "miss", "another dead hand must also wait")
	game.clock.elapsed = Rules.REGRAB_GRACE
	assert_eq(_roll_grab(_hand()), "grab")


func test_grace_does_not_prevent_a_scratch() -> void:
	var z := _hand()
	assert_eq(_roll_grab(z), "grab")
	game.zombies.release(z, game.player.position, false)
	game.player.coat["heavy"] = false
	game.player.coat["block"] = 0.0
	var rng := RandomNumberGenerator.new()
	for value in range(1, 100):
		rng.seed = value
		if rng.randf() >= Rules.GRAB_SHARE:
			game.rng.seed = value
			break
	assert_eq(game.combat.zombie_reaches(_hand(), game.player), "scratch")
	assert_true(game.player.grabbers.is_empty())


func test_two_hands_remove_the_window_and_one_release_does_not_grant_grace() -> void:
	var first := _hand()
	var second := _hand()
	assert_eq(_roll_grab(first), "grab")
	assert_eq(_roll_grab(second), "grab")
	assert_eq(game.player.grab_left, 0.0)
	game.zombies.release(first, game.player.position, false)
	assert_eq(game.player.grabbers.size(), 1)
	assert_true(Rules.can_regrab(game.player, game.clock.elapsed), "still held, not released yet")
	game.zombies.release(second, game.player.position, false)
	assert_false(Rules.can_regrab(game.player, game.clock.elapsed))


func test_knocking_down_or_killing_a_grabber_releases_and_starts_grace() -> void:
	var z := _hand()
	assert_eq(_roll_grab(z), "grab")
	game.zombies.knock_down(z)
	assert_true(game.player.grabbers.is_empty())
	assert_false(Rules.can_regrab(game.player, game.clock.elapsed))
	game.clock.elapsed += Rules.REGRAB_GRACE
	z = _hand()
	assert_eq(_roll_grab(z), "grab")
	game.zombies.kill(z)
	assert_true(game.player.grabbers.is_empty())
	assert_false(Rules.can_regrab(game.player, game.clock.elapsed))


func test_contact_cannot_reach_a_distant_or_different_floor_target() -> void:
	var z := _hand()
	z["pos"] = game.player.position + Vector3(0, 0, 2.0)
	assert_eq(_roll_grab(z), "miss")
	z["pos"] = game.player.position + Vector3(0, 3, 0)
	assert_eq(_roll_grab(z), "miss")
	z["pos"] = game.player.position
	z["state"] = "downed"
	assert_eq(_roll_grab(z), "miss")
	assert_true(game.telemetry.injuries.is_empty())


func test_a_stale_grab_does_not_bite_or_follow_across_floors() -> void:
	var z := _hand()
	assert_eq(_roll_grab(z), "grab")
	game.player.position.y += 3.0
	game.combat.bite(game.player)
	assert_true(game.player.grabbers.is_empty())
	assert_false(game.player.body.has_bite_wound())
	assert_eq(game.level_of(z["pos"]), 0)


func test_repeating_the_same_contact_does_not_duplicate_a_grab_or_reset_its_window() -> void:
	var z := _hand()
	assert_eq(_roll_grab(z), "grab")
	game.player.grab_left = 0.25
	var count: int = game.telemetry.injuries.size()
	assert_eq(_roll_grab(z), "grab")
	assert_eq(game.player.grab_left, 0.25)
	assert_eq(game.telemetry.injuries.size(), count)
