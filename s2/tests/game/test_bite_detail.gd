extends "res://addons/gut/test.gd"

const Rules = preload("res://game/sim/grab_rules.gd")
const FieldGame = preload("res://game/field_game.gd")


func _coat(heavy: bool = true) -> Dictionary:
	return {"heavy": heavy, "block": 0.5 if heavy else 0.25, "wear": 0.0}


func _game():
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	game.player.position = game.lift(Vector2i(60, 7), 0)
	game.player.coat.merge(_coat(), true)
	return game


func _held(game, crawler: bool = false) -> Dictionary:
	var p = game.player
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0, 0, 0.5))
	z["state"] = "grab"
	z["victim"] = p
	z["crawl"] = crawler
	p.grabbers.append(z)
	p.grab_left = 0.0
	return z


func _blocked_arm_seed() -> int:
	var rng := RandomNumberGenerator.new()
	for value in range(1, 1000):
		rng.seed = value
		var part_roll := rng.randf()
		var block_roll := rng.randf()
		if part_roll < Rules.BITE_ARM and block_roll < Rules.HEAVY_COAT_BLOCK:
			return value
	return -1


func _bites(game) -> int:
	var count := 0
	for injury in game.telemetry.injuries:
		if injury["kind"] == "bite": count += 1
	return count


func test_coat_defence_covers_only_arms_and_torso_and_teeth_need_a_heavy_coat() -> void:
	for site in ["arm_left", "arm_right", "torso"]:
		assert_eq(Rules.clothing_block(_coat(), site), 0.5)
		assert_eq(Rules.clothing_block(_coat(), site, true), 0.5)
		assert_eq(Rules.clothing_block(_coat(false), site), 0.25)
		assert_eq(Rules.clothing_block(_coat(false), site, true), 0.0)
	for site in ["head", "leg_left", "leg_right"]:
		assert_eq(Rules.clothing_block(_coat(), site, true), 0.0)
		assert_eq(Rules.clothing_block(_coat(), site), 0.0)


func test_a_hole_disables_only_its_part_and_existing_wear_still_counts() -> void:
	var coat := _coat()
	Rules.damage_clothing(coat, "arm_left", true)
	assert_eq(Rules.clothing_block(coat, "arm_left", true), 0.0)
	assert_almost_eq(Rules.clothing_block(coat, "arm_right", true), 0.475, 0.000001)
	assert_true(coat["holes"].has("arm_left"))
	assert_false(coat["holes"].has("arm_right"))
	var before: Dictionary = coat.duplicate(true)
	Rules.damage_clothing(coat, "leg_left", false)
	assert_eq(coat, before, "an uncovered leg does not damage the coat")
	coat["wear"] = 1.0
	assert_eq(Rules.clothing_block(coat, "torso", true), 0.0)


func test_blocked_bite_leaves_a_hole_and_releases_but_the_next_same_part_bite_lands() -> void:
	var game = _game()
	var value := _blocked_arm_seed()
	assert_gt(value, 0)
	_held(game)
	game.rng.seed = value
	game.combat.wound_rng().seed = 77
	game.combat.bite(game.player)
	assert_eq(_bites(game), 0)
	assert_false(game.player.body.has_bite_wound())
	assert_true(game.player.grabbers.is_empty())
	assert_eq(game.player.coat["holes"].size(), 1)
	assert_false(Rules.can_regrab(game.player, game.clock.elapsed))
	# Arrange a second contact directly to isolate clothing from acquisition.
	_held(game)
	game.rng.seed = value
	game.combat.wound_rng().seed = 77
	game.combat.bite(game.player)
	assert_eq(_bites(game), 1)
	assert_true(game.player.body.has_bite_wound())
	assert_true(game.player.grabbers.is_empty())


## The one at the front that bit is noted for its drawing (DeadBody.bite_after_k):
## it tears away through the rest of the bite. One behind it is not.
func test_the_front_one_that_bit_is_noted_for_its_tear_away() -> void:
	var game = _game()
	var front := _held(game)
	var behind := _held(game)
	front["age"] = 12.5
	game.combat.bite(game.player)
	assert_eq(float(front.get("bit_at", -1.0)), 12.5)
	assert_false(behind.has("bit_at"))


func test_crawler_bite_reaches_a_leg_the_coat_does_not_cover() -> void:
	var game = _game()
	_held(game, true)
	game.combat.bite(game.player)
	assert_eq(_bites(game), 1)
	assert_eq(game.player.coat["wear"], 0.0)
	assert_false(game.player.coat.has("holes"))
	var found := false
	for wound in game.player.body.wounds:
		if wound["kind"] == "bite":
			found = String(wound["part"]).begins_with("leg_")
	assert_true(found)


func test_a_door_breach_uses_scratch_defence_without_a_grab_roll() -> void:
	var game = _game()
	var rng := RandomNumberGenerator.new()
	for value in range(1, 100):
		rng.seed = value
		if rng.randf() < 0.5:
			game.rng.seed = value
			break
	assert_eq(game.combat.breach_reaches(game.player), "blocked")
	assert_true(game.player.grabbers.is_empty())
	assert_true(game.telemetry.injuries.is_empty())
	assert_eq(game.player.coat["holes"].size(), 1)


func test_empty_and_dead_contacts_cannot_create_a_bite() -> void:
	var game = _game()
	game.combat.bite(game.player)
	assert_eq(_bites(game), 0)
	assert_true(Rules.can_regrab(game.player, game.clock.elapsed))
	var z := _held(game)
	z["state"] = "dead"
	game.combat.bite(game.player)
	assert_eq(_bites(game), 0)
	assert_true(game.player.grabbers.is_empty())
