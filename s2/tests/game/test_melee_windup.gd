extends "res://addons/gut/test.gd"
## A melee blow lands after the weapon is drawn back, by its weight
## (user 2026-10-11): not the moment the attack is called.

const FieldGame = preload("res://game/field_game.gd")
const W = preload("res://game/sim/weapons.gd")

var game
var p


func _start(extra: Dictionary = {}) -> void:
	game = FieldGame.new()
	var opts := {"seed": 5, "raiders": false, "auto_pause": false}
	opts.merge(extra)
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	p = game.player
	p.position = game.lift(Vector2i(60, 7), 0)


func _dead_at(dx: float) -> Dictionary:
	return game.zombies.spawn("dead", p.position + Vector3(dx, 0, 0))


func _touched(z: Dictionary) -> bool:
	return not game.zombies.list.has(z) or String(z["state"]) in ["dead", "downed"] or float(z.get("stun", 0.0)) > 0.0


func test_heavier_weapons_are_drawn_back_longer() -> void:
	assert_almost_eq(W.melee_windup("knife"), 0.10, 0.001)
	assert_almost_eq(W.melee_windup("crowbar"), 0.18, 0.001)
	assert_almost_eq(W.melee_windup("axe"), 0.30, 0.001)
	assert_eq(W.melee_windup("pistol"), 0.0, "a gun is not swung")
	for id in ["knife", "crowbar", "axe"]:
		assert_lte(W.melee_windup(id), float(W.get_data(id)["swing"]) * 0.5, "the front part of the swing")


func test_the_blow_lands_after_the_draw_back_and_the_swing_is_no_longer() -> void:
	_start()
	assert_eq(p.weapon_id(), "axe")
	var z := _dead_at(1.0)
	var before: String = z["state"]
	var mult: float = float(p.mults()["swing"])
	game.combat.start_swing(p, z)
	assert_almost_eq(p.strike_t, 0.30 / mult, 0.001)
	assert_almost_eq(p.strike_total, p.strike_t, 0.001)
	assert_eq(z["state"], before, "nothing lands when it is called")
	assert_false(_touched(z))
	game.combat.update(0.30 / mult - 0.05)
	assert_false(_touched(z), "not yet")
	game.combat.update(0.06)
	assert_true(_touched(z), "now it lands")
	assert_eq(p.strike_t, 0.0)
	# 0.30 drawn back + what is left = the axe's swing time: the draw-back is not extra.
	# The player's gap after the blow is (decision 473 W1).
	assert_almost_eq(p.swing_t + 0.30 / mult, float(W.get_data("axe")["swing"]) / mult + W.melee_gap("axe"), 0.005)


func test_a_second_call_while_drawn_back_does_nothing() -> void:
	_start()
	var z := _dead_at(1.0)
	game.combat.start_swing(p, z)
	var t: float = p.strike_t
	game.combat.start_swing(p, z)
	assert_almost_eq(p.strike_t, t, 0.001)


func test_one_that_steps_out_of_reach_is_missed() -> void:
	_start()
	var z := _dead_at(1.0)
	game.combat.start_swing(p, z)
	z["pos"] = p.position + Vector3(4.0, 0, 0)
	game.combat.update(1.0)
	assert_false(_touched(z))
	assert_almost_eq(p.swing_t, game.combat.WHIFF_RECOVER, 0.001, "a miss still costs a moment")


func test_a_grab_stops_the_blow_unless_the_setting_says_nothing_does() -> void:
	_start()
	var z := _dead_at(1.0)
	game.combat.start_swing(p, z)
	p.grabbers.append(_dead_at(-0.6))
	game.combat.update(1.0)
	assert_false(_touched(z), "grabbed: the blow does not land")
	_start({"melee_break": "none"})
	var z2 := _dead_at(1.0)
	game.combat.start_swing(p, z2)
	p.grabbers.append(_dead_at(-0.6))
	game.combat.update(1.0)
	assert_true(_touched(z2), "set to 'none': it lands all the same")


func test_one_knocked_down_while_drawing_back_does_not_strike() -> void:
	_start({"melee_break": "none"})
	var z := _dead_at(1.0)
	game.combat.start_swing(p, z)
	p.fallen_t = 1.0
	game.combat.update(0.5)
	assert_false(_touched(z))


func test_with_no_melee_weapon_it_is_the_old_shove_at_once() -> void:
	_start()
	p.hands = [{"id": "pistol", "quality": "factory", "loaded": 0}]
	p.set_weapon_slots(p.hands)
	assert_eq(p.weapon_id(), "pistol")
	var z := _dead_at(0.8)
	game.combat.start_swing(p, z)
	assert_eq(p.strike_t, 0.0)
	assert_gt(p.swing_t, 0.0, "shoved")


func test_the_attack_order_goes_through_the_draw_back() -> void:
	_start()
	var z := _dead_at(1.0)
	p.target_zombie = z
	p.facing = PI / 2.0
	game.combat._pursue_zombie(p, 0.016)
	assert_gt(p.strike_t, 0.0, "the order starts the draw-back")
	assert_false(_touched(z))
