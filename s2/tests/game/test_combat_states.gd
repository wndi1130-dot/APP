extends "res://addons/gut/test.gd"
## One melee blow ends differently by the state of the dead it lands on
## (zombies.md 갓 일어난 자·얼어붙은 자·껴입은 자, weapons.md S2 rows).
## The odds carry a die roll, so every chance here is run many times.

const FieldGame = preload("res://game/field_game.gd")
const W = preload("res://game/sim/weapons.gd")

const SWINGS: int = 200

var game
var p


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 17, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	p = game.player
	p.position = game.lift(Vector2i(60, 7), 0)


## A body in the named state, right in front of the player, quiet and still.
func _body_at(state: String, dx: float = 0.9, kind: String = "dead") -> Dictionary:
	var z: Dictionary = game.zombies.spawn(kind, p.position + Vector3(dx, 0, 0))
	if kind != "frozen":
		z["state"] = state
	# Each blow's odds are counted, not the weapon worn through (it breaks at nothing).
	if not p.hands.is_empty():
		p.hands[0]["condition"] = 1.0
	return z


func _hand(id: String, quality: String = "factory") -> void:
	p.hands = [{"id": id, "quality": quality, "condition": 1.0, "loaded": 0}]
	p.set_weapon_slots(p.hands)
	p.aim.stop()


func test_a_rising_body_goes_down_to_any_blow() -> void:
	for id in ["knife", "crowbar", "axe"]:
		_hand(id)
		var z := _body_at("rising")
		assert_eq(p.weapon_id(), id)
		game.combat.swing(p, z)
		assert_eq(z["state"], "dead", "%s ends one that is standing up" % id)


func test_a_frozen_body_shatters_to_blunt_and_wakes_to_a_knife() -> void:
	_hand("knife")
	var z := _body_at("dead", 0.9, "frozen")
	assert_eq(z["state"], "frozen")
	game.combat.swing(p, z)
	assert_ne(z["state"], "dead", "a knife does not shatter it")
	assert_eq(z["state"], "waking", "the blade only wakes it")
	for id in ["crowbar", "axe"]:
		_hand(id)
		var z2 := _body_at("dead", 0.9, "frozen")
		game.combat.swing(p, z2)
		assert_eq(z2["state"], "dead", "%s shatters the frozen body" % id)


func test_a_chasing_body_is_not_taken_by_the_quiet_blow() -> void:
	_hand("knife")
	p.crouched = true
	var ended := 0
	for i in range(SWINGS):
		var z := _body_at("chase", -0.9)
		z["angle"] = -PI / 2.0
		assert_true(game.combat.behind(z, p.position))
		game.combat.swing(p, z)
		if z["state"] == "dead":
			ended += 1
	assert_lt(ended, SWINGS, "a chase is never a sure one-blow kill")
	assert_lt(float(ended) / float(SWINGS), 0.95, "and it is usually not one at all")


func test_a_coated_body_turns_a_blade_on_the_torso_without_going_down() -> void:
	_hand("knife")
	# Only the body-hit branch is counted: a head hit may still knock the
	# coated body down, which is not the branch under test here.
	var stuns: Array = []
	for i in range(SWINGS):
		var z := _body_at("wander", 0.9, "clothed")
		game.combat.swing(p, z)
		if z["state"] == "wander":
			stuns.append(float(z["stun"]))
	assert_gt(stuns.size(), 0, "a body hit happens now and then")
	for s in stuns:
		assert_almost_eq(s, 0.3, 0.0001, "a blade on the coat only stuns it a little")
		assert_ne(s, 0.6, "never the whole-body stun")


func test_a_coated_body_goes_down_to_a_blunt_blow() -> void:
	_hand("crowbar")
	var stun_06 := 0
	var knocked := 0
	for i in range(SWINGS):
		var z := _body_at("wander", 0.9, "clothed")
		game.combat.swing(p, z)
		if z["state"] == "downed":
			knocked += 1
		elif float(z["stun"]) == 0.6:
			stun_06 += 1
	assert_gt(knocked, 0, "a blunt blow knocks the coated body down")
	assert_gt(stun_06, 0, "and now and then leaves it up with the full stun")