extends "res://addons/gut/test.gd"
## Decision 491 4: every blow at the dead is told once, as it lands or goes
## through air (field_combat.gd struck), with the weapon, the state of the one
## struck, how it came out and the weapon's edge. The sound line plays by it.

const FieldGame = preload("res://game/field_game.gd")

var game
var p
var heard: Array = []


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	p = game.player
	p.position = game.lift(Vector2i(60, 7), 0)
	p.facing = PI * 0.5   # east
	heard.clear()
	game.combat.struck.connect(func(info: Dictionary) -> void: heard.append(info))


func _hand(id: String, condition: float = 1.0) -> void:
	p.hands = [] if id == "" else [{"id": id, "quality": "factory", "condition": condition, "loaded": 0}]
	p.set_weapon_slots(p.hands)
	p.swing_t = 0.0


func _body(state: String, kind: String = "dead") -> Dictionary:
	var z: Dictionary = game.zombies.spawn(kind, p.position + Vector3(0.9, 0, 0))
	if kind != "frozen":
		z["state"] = state
	return z


func test_a_blow_on_one_standing_is_told_once_with_its_outcome() -> void:
	_hand("crowbar")
	game.combat.swing(p, _body("chase"))
	assert_eq(heard.size(), 1)
	var info: Dictionary = heard[0]
	assert_eq(info["way"], "swing")
	assert_eq(info["weapon"], "crowbar")
	assert_eq(info["target"], "standing")
	assert_has(["body", "head", "finish"], info["result"])
	assert_eq(info["edge"], 0, "sharp")
	assert_true(info["by_player"])


func test_the_edge_is_the_weapons_before_the_blow() -> void:
	_hand("crowbar", 0.5)
	game.combat.swing(p, _body("chase"))
	assert_eq(heard[-1]["edge"], 1, "dull")
	_hand("crowbar", 0.2)
	game.combat.swing(p, _body("chase"))
	assert_eq(heard[-1]["edge"], 2, "about to break")


func test_many_blows_each_told_once_as_body_head_or_finish() -> void:
	_hand("crowbar")
	var seen := {}
	for i in 120:
		p.hands[0]["condition"] = 1.0
		game.combat.swing(p, _body("chase"))
		seen[heard[-1]["result"]] = true
	assert_eq(heard.size(), 120, "one each")
	for r in seen:
		assert_has(["body", "head", "finish"], r)
	assert_true(seen.has("body") and seen.has("finish"))


func test_one_on_the_ground_rising_and_frozen() -> void:
	_hand("crowbar")
	game.combat.swing(p, _body("downed"))
	assert_eq(heard[-1]["target"], "downed")
	game.combat.swing(p, _body("rising"))
	assert_eq(heard[-1]["target"], "rising")
	assert_eq(heard[-1]["result"], "finish", "its head is crushed as it gets up")
	game.combat.swing(p, _body("", "frozen"))
	assert_eq(heard[-1]["target"], "frozen")
	assert_eq(heard[-1]["result"], "shatter", "a crowbar breaks it")
	_hand("knife")
	game.combat.swing(p, _body("", "frozen"))
	assert_eq(heard[-1]["result"], "stuck", "a knife only sticks in it")


func test_a_blade_on_a_thick_coat_is_blocked() -> void:
	_hand("knife")
	var told := {}
	for i in 60:
		p.hands[0]["condition"] = 1.0
		game.combat.swing(p, _body("chase", "clothed"))
		told[heard[-1]["result"]] = true
	assert_true(told.has("blocked"))


func test_a_swing_at_air_is_a_miss() -> void:
	_hand("knife")
	game.combat._swing_empty(p)
	assert_eq(heard.size(), 1)
	assert_eq(heard[0]["result"], "miss")
	assert_eq(heard[0]["target"], "")
	assert_eq(heard[0]["weapon"], "knife")


func test_a_stomp_is_the_boots_and_the_last_one_finishes() -> void:
	_hand("")
	var lying := _body("downed")
	lying["t"] = 99.0
	for i in game.combat.STOMPS_TO_END:
		game.combat.stomp(p, lying)
	assert_eq(heard.size(), game.combat.STOMPS_TO_END)
	assert_eq(heard[0]["way"], "stomp")
	assert_eq(heard[0]["weapon"], "boot")
	assert_eq(heard[0]["target"], "downed")
	assert_eq(heard[0]["result"], "body")
	assert_eq(heard[0]["edge"], -1)
	assert_eq(heard[-1]["result"], "finish")


func test_a_shove_is_told_for_each_it_pushes_and_as_a_miss_for_none() -> void:
	_hand("")
	game.combat.shove(p)
	assert_eq(heard.size(), 1)
	assert_eq(heard[0]["result"], "miss")
	heard.clear()
	p.swing_t = 0.0
	_body("chase")
	game.combat.shove(p)
	assert_eq(heard.size(), 1)
	assert_eq(heard[0]["way"], "shove")
	assert_eq(heard[0]["weapon"], "", "bare hands")
	assert_eq(heard[0]["result"], "body")
