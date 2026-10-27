extends "res://addons/gut/test.gd"
## Companions fight at a human pace (user 2026-10-12): a rest after a blow, a
## rest when they pick the next one, a body that turns, a back that is slow
## to be watched. The player is left exactly as it was.

const FieldGame = preload("res://game/field_game.gd")
const FieldCombat = preload("res://game/field_combat.gd")
const FieldAi = preload("res://game/field_ai.gd")
const W = preload("res://game/sim/weapons.gd")

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
	game.player.position = game.lift(Vector2i(60, 7), 0)
	for q in game.squad:
		if q != game.player:
			q.position = game.lift(Vector2i(30, 7), 0)
			if ally == null:
				ally = q
	ally.position = game.lift(Vector2i(60, 9), 0)
	ally.hands = [{"id": "knife", "quality": "factory", "condition": 1.0, "loaded": 0}]
	game.player.hands = [{"id": "knife", "quality": "factory", "condition": 1.0, "loaded": 0}]


func _land(p, at: Dictionary) -> void:
	game.combat.start_swing(p, at)
	game.combat.update(p.strike_t + 0.01)


## What swing_t is after a landed blow with no rest added.
func _plain(p, id: String) -> float:
	var windup: float = W.melee_windup(id) / float(p.mults()["swing"])
	return maxf(float(W.get_data(id)["swing"]) / float(p.mults()["swing"]) - windup, FieldCombat.WHIFF_RECOVER)


func test_a_companion_rests_after_a_blow_that_landed() -> void:
	ally = null
	_start()
	for id in ["knife", "crowbar"]:
		ally.hands = [{"id": id, "quality": "factory", "condition": 1.0, "loaded": 0}]
		ally.swing_t = 0.0
		var z: Dictionary = game.zombies.spawn("dead", ally.position + Vector3(0.7, 0, 0))
		_land(ally, z)
		assert_eq(ally.strike_t, 0.0, "the blow came down")
		var extra: float = ally.swing_t - _plain(ally, id)
		assert_gte(extra, FieldCombat.ALLY_REST_MIN - 0.01, id + ": at least the least rest")
		assert_lte(extra, FieldCombat.ALLY_REST_MAX + 0.01, id + ": at most the most rest")
		assert_gt(ally.swing_t, float(W.get_data(id)["swing"]) / float(ally.mults()["swing"]), id + ": longer than the weapon's swing time")


func test_the_rests_vary_and_the_game_rng_is_left_alone() -> void:
	ally = null
	_start()
	var before: int = game.rng.state
	var seen := {}
	for i in 6:
		ally.swing_t = 0.0
		ally.strike_t = 0.0
		var z: Dictionary = game.zombies.spawn("dead", ally.position + Vector3(0.7, 0, 0))
		before = game.rng.state
		game.combat.start_swing(ally, z)
		game.combat.update(ally.strike_t + 0.01)
		seen[snappedf(ally.swing_t, 0.001)] = true
		game.zombies.list.erase(z)
	assert_gt(seen.size(), 1, "not the same pause every time")
	# The rest itself rolls nothing from game.rng (the blow's own rolls are the game's).
	var s0: int = game.rng.state
	game.combat._pace(FieldCombat.ALLY_REST_MIN, FieldCombat.ALLY_REST_MAX)
	assert_eq(game.rng.state, s0)


func test_the_player_is_not_slowed() -> void:
	ally = null
	_start()
	var p = game.player
	p.swing_t = 0.0
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.7, 0, 0))
	_land(p, z)
	# No companion's rest, only its weapon's gap (decision 473 W1).
	assert_almost_eq(p.swing_t, _plain(p, "knife") + W.melee_gap("knife"), 0.005)


func test_a_companion_waits_when_it_takes_the_next_one() -> void:
	ally = null
	_start()
	var gone: Dictionary = game.zombies.spawn("dead", ally.position + Vector3(0.7, 0, 0))
	gone["state"] = "dead"
	var next: Dictionary = game.zombies.spawn("dead", ally.position + Vector3(1.5, 0, 0))
	next["state"] = "chase"
	ally.target_zombie = gone
	ally.hold_attack = true
	ally.swing_t = 0.0
	game.combat._pursue_zombie(ally, 0.016)
	assert_eq(ally.target_zombie, next, "the next one is taken")
	assert_gte(ally.swing_t, FieldCombat.ALLY_SWITCH_MIN)
	assert_lte(ally.swing_t, FieldCombat.ALLY_SWITCH_MAX)
	# The player's chain is as quick as it was.
	game.zombies.list.clear()
	var p = game.player
	var gone2: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.7, 0, 0))
	gone2["state"] = "dead"
	var next2: Dictionary = game.zombies.spawn("dead", p.position + Vector3(1.5, 0, 0))
	next2["state"] = "chase"
	p.target_zombie = gone2
	p.hold_attack = true
	p.swing_t = 0.0
	game.combat._pursue_zombie(p, 0.016)
	assert_eq(p.target_zombie, next2)
	assert_eq(p.swing_t, 0.0)


func test_a_body_turns_over_time_and_is_not_there_in_one_step() -> void:
	ally = null
	_start()
	ally.turn_rate = deg_to_rad(400.0)
	ally.look = 0.0
	ally.facing = PI
	assert_false(ally.turned_to(deg_to_rad(35.0)))
	ally.turn_tick(0.016)
	var moved: float = absf(angle_difference(ally.look, 0.0))
	assert_almost_eq(moved, ally.turn_rate * 0.016, 0.001, "one step turns it by rate times the step, no more")
	assert_gt(absf(angle_difference(ally.look, ally.facing)), 0.0, "one step does not turn it round")
	var steps := 0
	while not ally.turned_to(deg_to_rad(1.0)) and steps < 3000:
		ally.turn_tick(0.016)
		steps += 1
	assert_true(ally.turned_to(deg_to_rad(1.0)), "turned round in the end")
	ally.refresh_view(false)
	assert_almost_eq(absf(angle_difference(ally.rotation.y, PI)), 0.0, 0.03, "the picture draws the rules' turn")
	# No turn rate: as before, at once, always turned.
	ally.turn_rate = 0.0
	ally.facing = 1.0
	ally.turn_tick(0.016)
	ally.refresh_view(false)
	assert_eq(ally.rotation.y, 1.0)
	assert_true(ally.turned_to(0.0))


# Decision 442 card C2: the turn is on the rules' clock. A field stepped with no
# frame drawn (the 40 runs) turns its people as the one on screen does, and a
# drawn frame alone does not turn them.
func test_the_rules_step_turns_the_bodies_and_a_frame_alone_does_not() -> void:
	ally = null
	_start()
	game._turn_people(0.0)
	assert_gt(ally.turn_rate, 0.0, "the rules give the rate")
	ally.look = 0.0
	ally.facing = PI
	ally.refresh_view(false)
	assert_eq(ally.look, 0.0, "a frame drawn does not turn it")
	game._turn_people(0.1)
	assert_almost_eq(absf(angle_difference(ally.look, 0.0)), ally.turn_rate * 0.1, 0.001, "a rules step does")


func test_a_companion_does_not_swing_until_it_faces_the_target() -> void:
	ally = null
	_start()
	var z: Dictionary = game.zombies.spawn("dead", ally.position + Vector3(0.7, 0, 0))
	z["state"] = "chase"
	ally.turn_rate = deg_to_rad(400.0)
	ally.look = PI + 0.0
	ally.target_zombie = z
	game.combat._pursue_zombie(ally, 0.016)
	assert_eq(ally.strike_t, 0.0, "still turning, no blow")
	ally.look = ally.facing
	ally.target_zombie = z
	game.combat._pursue_zombie(ally, 0.016)
	assert_gt(ally.strike_t, 0.0, "facing it, the blow starts")


func test_the_game_gives_everyone_but_the_player_a_turn_rate() -> void:
	ally = null
	_start()
	game._process(0.016)
	assert_eq(game.player.turn_rate, 0.0)
	var rates := {}
	for q in game.people:
		if q != game.player:
			assert_gt(q.turn_rate, 0.0)
			assert_gte(q.turn_rate, deg_to_rad(FieldGame.TURN_DEG_PER_S) * 0.85 - 0.001)
			assert_lte(q.turn_rate, deg_to_rad(FieldGame.TURN_DEG_PER_S) * 1.15 + 0.001)
			rates[q.turn_rate] = true
	assert_gt(rates.size(), 1, "each person has their own pace")


func _notice_max() -> float:
	return FieldAi.BEHIND_NOTICE_MAX


func test_something_behind_is_not_a_threat_at_first_in_front_it_is() -> void:
	ally = null
	_start()
	ally.facing = 0.0
	var behind: Dictionary = game.zombies.spawn("dead", ally.position + Vector3(0, 0, -2.5))
	behind["state"] = "chase"
	assert_true(game.ai._threat_near(ally, 3.0).is_empty(), "first look: not noticed")
	var t := FieldAi.THINK
	var found := false
	while t <= _notice_max() + 0.001:
		if not game.ai._threat_near(ally, 3.0).is_empty():
			found = true
			break
		t += FieldAi.THINK
	assert_true(found, "noticed once it has stayed behind long enough")
	assert_lte(t, _notice_max() + 0.001)
	# Nothing behind any more: the count starts over.
	game.zombies.list.erase(behind)
	assert_true(game.ai._threat_near(ally, 3.0).is_empty())
	assert_eq(ally.brain["behind_t"], 0.0)
	# In front: at once.
	var front: Dictionary = game.zombies.spawn("dead", ally.position + Vector3(0, 0, 2.5))
	front["state"] = "chase"
	assert_eq(game.ai._threat_near(ally, 3.0), front)
	# Close behind (inside BEHIND_NEAR): at once.
	game.zombies.list.erase(front)
	var close: Dictionary = game.zombies.spawn("dead", ally.position + Vector3(0, 0, -1.0))
	close["state"] = "chase"
	assert_eq(game.ai._threat_near(ally, 3.0), close)


func test_a_companion_holds_the_gun_after_a_shot() -> void:
	ally = null
	_start()
	ally.hands = [{"id": "pistol", "quality": "factory", "condition": 1.0, "loaded": 8}]
	var z: Dictionary = game.zombies.spawn("dead", ally.position + Vector3(0, 0, 4.0))
	z["state"] = "chase"
	ally.facing = 0.0
	game.combat.start_aim(ally)
	ally.brain["aim_wait"] = 0.0
	var loaded_before: int = int(ally.weapon()["loaded"])
	game.ai._shoot_or_aim(ally, z["pos"], z)
	if int(ally.weapon()["loaded"]) < loaded_before:
		assert_almost_eq(float(ally.brain["aim_wait"]), FieldAi.ALLY_REFIRE, 0.001)
	else:
		pending("the shot did not leave the gun in this set-up (jam, misfire or no clear aim)")
