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
		if rng.randf() < Rules.grab_share(true):
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
	var hand := _hand()   # spawning rolls the game's dice: before they are set
	var rng := RandomNumberGenerator.new()
	for value in range(1, 100):
		rng.seed = value
		var r: float = rng.randf()
		if r >= Rules.grab_share(true) and r < Rules.grab_share(true) + Rules.SCRATCH_SEEN:
			game.rng.seed = value
			break
	assert_eq(game.combat.zombie_reaches(hand, game.player), "scratch")
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


## Decision 474 J1, counted only: a hand from inside the view cone (about
## 160 degrees ahead) is seen, one from beside or behind is not; lying, none is.
func test_a_hand_is_seen_inside_the_view_cone_only() -> void:
	assert_true(Rules.in_sight(0.0, Vector3(0, 0, 1)))
	assert_true(Rules.in_sight(0.0, Vector3(0.9, 0, 0.3)), "well to one side, still in the cone")
	assert_false(Rules.in_sight(0.0, Vector3(1, 0, 0)), "beside")
	assert_false(Rules.in_sight(0.0, Vector3(0, 0, -1)), "behind")
	assert_false(Rules.in_sight(0.0, Vector3(0, 0, 1), true), "lying")


## A grab from the front and its bite are counted as seen; one from behind as unseen.
func test_contacts_and_bites_are_counted_on_the_side_they_came_from() -> void:
	var c: Dictionary = game.combat.contacts
	game.player.coat["heavy"] = false
	game.player.coat["block"] = 0.0
	assert_eq(_roll_grab(_hand()), "grab")
	assert_eq(int(c["seen"]["reach"]), 1)
	assert_eq(int(c["seen"]["grab"]), 1)
	assert_eq(int(c["unseen"]["reach"]), 0)
	game.combat.bite(game.player)
	var bitten: bool = game.telemetry.injuries.any(func(i): return i["kind"] == "bite")
	assert_eq(int(c["seen"]["bite"]), 1 if bitten else 0, "the held hand was seen")
	assert_eq(int(c["unseen"]["bite"]), 0)
	game.clock.elapsed = Rules.REGRAB_GRACE + 1.0
	var back: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(0, 0, -0.6))
	assert_eq(_roll_grab(back), "grab")
	assert_eq(int(c["unseen"]["reach"]), 1)
	assert_eq(int(c["unseen"]["grab"]), 1)


## "붙은 수" (decision 474 J1): the dead attacking or holding that one person, in reach.
func test_the_crowd_on_someone_counts_only_the_dead_reaching_for_them() -> void:
	var p = game.player
	for x in [-0.5, 0.0, 0.5]:
		var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(x, 0, 0.6))
		z["state"] = "attack"
		z["victim"] = p
	var idle: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0, 0, -0.6))
	idle["state"] = "wander"
	var far: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0, 0, 4.0))
	far["state"] = "attack"
	far["victim"] = p
	assert_eq(game.combat.crowd_at(p), 3)


## Decision 474 J1: a hand from beside or behind takes hold far more often than
## one seen coming, each more of the dead on the person adds, never past the most.
func test_a_hand_unseen_or_in_a_crowd_takes_hold_more_often() -> void:
	assert_almost_eq(Rules.grab_share(true), Rules.GRAB_SEEN, 0.0001)
	assert_almost_eq(Rules.grab_share(false), Rules.GRAB_UNSEEN, 0.0001)
	assert_gte(Rules.grab_share(false), 2.0 * Rules.grab_share(true), "behind, twice the seen one")
	assert_almost_eq(Rules.grab_share(true, 3), Rules.GRAB_SEEN + 2.0 * Rules.CROWD_STEP, 0.0001)
	assert_almost_eq(Rules.grab_share(false, 6), Rules.GRAB_MOST, 0.0001)


## A seen hand that does not take hold scratches only so often; the rest snap at air.
func test_a_seen_hand_past_the_scratch_band_snaps_at_air() -> void:
	var hand := _hand()
	var rng := RandomNumberGenerator.new()
	for value in range(1, 200):
		rng.seed = value
		if rng.randf() >= Rules.grab_share(true) + Rules.SCRATCH_SEEN:
			game.rng.seed = value
			break
	assert_eq(game.combat.zombie_reaches(hand, game.player), "miss")
	assert_eq(int(game.combat.contacts["seen"]["miss"]), 1)
	assert_true(game.player.grabbers.is_empty())
	var back: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(0, 0, -0.6))
	game.rng.seed = 1
	assert_ne(game.combat.zombie_reaches(back, game.player), "miss", "from behind none snaps at air")


## Three of the dead on someone put them down once (decision 474 J1): the hands that
## held drop off where they are, no grace keeps the rest off, and not again until clear.
func test_three_on_someone_put_them_down_once() -> void:
	var p = game.player
	var on: Array = [_hand()]
	assert_eq(_roll_grab(on[0]), "grab", "one alone takes hold first")
	var held_at: Vector3 = on[0]["pos"]
	for x in [-0.5, 0.5]:
		var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(x, 0, 0.6))
		z["state"] = "attack"
		z["victim"] = p
		on.append(z)
	assert_eq(game.combat.crowd_at(p), 3)
	assert_eq(game.combat.zombie_reaches(on[1], p), "fall")
	assert_almost_eq(p.fallen_t, game.combat.FALL_TIME, 0.0001)
	assert_true(p.grabbers.is_empty(), "the hands let go")
	assert_eq(on[0]["pos"], held_at, "not pushed off: the fall gives no room")
	assert_true(Rules.can_regrab(p, game.clock.elapsed), "on the ground no grace keeps the rest off")
	assert_gt(float(on[0]["cooldown"]), 0.0, "the one that held gets its breath back")
	assert_eq(int(game.combat.crowd_falls), 1)
	p.fallen_t = 0.0
	on[0]["state"] = "attack"
	assert_eq(game.combat.crowd_at(p), 3, "still three on them")
	assert_ne(game.combat.zombie_reaches(on[2], p), "fall", "not again until up and clear")
	assert_eq(int(game.combat.crowd_falls), 1)
