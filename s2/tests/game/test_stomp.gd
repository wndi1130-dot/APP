extends "res://addons/gut/test.gd"
## One lying there and no melee weapon in the hand: the boot comes down (user
## 2026-10-11). It lands late and takes several, so a weapon stays worth carrying.

const FieldGame = preload("res://game/field_game.gd")
const W = preload("res://game/sim/weapons.gd")

var game
var p
var mult: float


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	p = game.player
	p.position = game.lift(Vector2i(60, 7), 0)
	mult = float(p.mults()["swing"])


func _fallen_at(dx: float) -> Dictionary:
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(dx, 0, 0))
	game.zombies.knock_down(z)
	z["t"] = 99.0
	return z


func _bare() -> void:
	p.hands = []
	p.set_weapon_slots(p.hands)
	assert_eq(p.weapon_id(), "")


func _gun() -> void:
	p.hands = [{"id": "pistol", "quality": "factory", "condition": 1.0, "loaded": 8}]
	p.set_weapon_slots(p.hands)


func test_it_is_slower_than_any_weapon() -> void:
	var c = game.combat
	for id in ["knife", "crowbar", "axe"]:
		assert_gt(c.STOMP_WINDUP, W.melee_windup(id), "lands later than " + id)
		assert_gt(c.STOMP_TIME * c.STOMPS_TO_END, float(W.get_data(id)["swing"]) * 2.0, "a weapon ends a fallen one in one blow")
	assert_gt(c.STOMPS_TO_END, 1, "several")


func test_bare_hands_stomp_a_fallen_one_late_and_three_times() -> void:
	_bare()
	var z := _fallen_at(0.7)
	var c = game.combat
	c.start_swing(p, z)
	assert_eq(p.strike_kind, "stomp")
	assert_almost_eq(p.strike_t, c.STOMP_WINDUP / mult, 0.001)
	assert_eq(int(z.get("stomped", 0)), 0, "nothing lands when it is called")
	c.update(c.STOMP_WINDUP / mult - 0.05)
	assert_eq(int(z.get("stomped", 0)), 0, "not yet")
	c.update(0.06)
	assert_eq(int(z["stomped"]), 1)
	assert_eq(z["state"], "downed", "one is not enough")
	# The lift was the front of the stomp's time, not extra.
	assert_almost_eq(p.swing_t + c.STOMP_WINDUP / mult, c.STOMP_TIME / mult, 0.01)
	for i in range(c.STOMPS_TO_END - 1):
		c.update(2.0)
		assert_eq(p.swing_t, 0.0)
		c.start_swing(p, z)
		c.update(c.STOMP_WINDUP / mult + 0.01)
	assert_eq(z["state"], "dead", "the third ends it")


func test_one_that_gets_up_under_the_boot_is_missed() -> void:
	_bare()
	var z := _fallen_at(0.7)
	game.combat.start_swing(p, z)
	z["state"] = "wander"
	game.combat.update(1.0)
	assert_eq(int(z.get("stomped", 0)), 0)
	assert_almost_eq(p.swing_t, game.combat.WHIFF_RECOVER, 0.001)


func test_with_a_weapon_it_is_the_one_blow_as_before() -> void:
	assert_eq(p.weapon_id(), "axe")
	var z := _fallen_at(0.9)
	game.combat.start_swing(p, z)
	assert_eq(p.strike_kind, "swing")
	game.combat.update(1.0)
	assert_eq(z["state"], "dead")
	assert_eq(int(z.get("stomped", 0)), 0)


func test_a_gun_in_the_hand_stomps_a_fallen_one_and_shoves_a_standing_one() -> void:
	_gun()
	var up: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.8, 0, 0))
	game.combat.start_swing(p, up)
	assert_eq(p.strike_t, 0.0, "a standing one is shoved at once")
	assert_eq(p.strike_kind, "swing")
	game.zombies.list.erase(up)
	game.combat.update(2.0)
	var z := _fallen_at(0.7)
	p.target_zombie = z
	p.hold_attack = true
	p.facing = PI / 2.0
	game.combat._pursue_zombie(p, 0.016)
	assert_eq(p.strike_kind, "stomp", "the attack order goes to the boot")
	assert_gt(p.strike_t, 0.0)
	assert_eq(int(p.weapon()["loaded"]), 8, "no shot is spent on it")
