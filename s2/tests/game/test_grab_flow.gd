extends "res://addons/gut/test.gd"
## Being reached, held and bitten by the dead on the field, and a crowbar on a
## locked door (zombies.md 잡기, weapons.md 짧은 둔기 문 따기).

const FieldGame = preload("res://game/field_game.gd")

const TRIES: int = 200

var game
var p


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 31, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	p = game.player
	p.position = game.lift(Vector2i(60, 7), 0)


func _body_at(dx: float) -> Dictionary:
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(dx, 0, 0))
	z["state"] = "attack"
	return z


func _let_go() -> void:
	for z in p.grabbers.duplicate():
		game.zombies.release(z, p.position, false)
	p.grabbers.clear()
	p.grab_left = 0.0


func test_a_whole_coat_never_lets_a_scratch_through() -> void:
	p.coat["block"] = 1.0
	p.coat["wear"] = 0.0
	var z := _body_at(0.8)
	var seen := {}
	for i in range(TRIES):
		# Each blocked reach wears the coat; put it back so the block stays whole.
		p.coat["wear"] = 0.0
		var outcome: String = game.combat.zombie_reaches(z, p)
		seen[outcome] = true
		if outcome == "blocked":
			assert_almost_eq(float(p.coat["wear"]), 0.05, 0.0001, "a blocked reach wears the coat")
		_let_go()
	assert_false(seen.has("scratch"), "no scratch gets through a whole coat")
	assert_true(seen.has("grab"), "it still takes hold now and then")
	assert_true(seen.has("blocked"), "and the coat stops the rest")


func test_a_hold_is_broken_while_the_window_lasts() -> void:
	var z := _body_at(0.8)
	p.grabbers.append(z)
	p.grab_left = 0.5
	assert_true(game.combat.break_grab(p), "a hold with time left can be broken")
	assert_true(p.grabbers.is_empty(), "nothing holds the person after")
	assert_eq(p.grab_left, 0.0)


func test_a_hold_with_no_window_left_cannot_be_broken() -> void:
	var z := _body_at(0.8)
	p.grabbers.append(z)
	p.grab_left = 0.0
	assert_false(game.combat.break_grab(p), "the window is gone")
	assert_eq(p.grabbers.size(), 1, "and it still holds")


func test_a_bite_lets_go_panics_and_goes_on_the_receipt() -> void:
	var z := _body_at(0.8)
	p.grabbers.append(z)
	p.grab_left = 0.0
	game.combat.bite(p)
	assert_true(p.grabbers.is_empty(), "the dead let go once they have bitten")
	assert_eq(p.grab_left, 0.0)
	assert_eq(p.panic, 1.0, "a bite is full panic")
	var people: Dictionary = game.receipt.to_dict()["people"]
	assert_true((people["bitten"] as Array).has(p.pid), "the bitten one is on the receipt")


func _a_locked_door() -> Vector2i:
	for c in game.grid.doors:
		if String(game.grid.doors[c]["state"]) == "locked":
			return c
	return game.grid.doors.keys()[0]


func test_a_crowbar_starts_prying_a_door() -> void:
	assert_false(game.grid.doors.is_empty(), "the field has doors")
	p.hands = [{"id": "crowbar", "quality": "factory", "condition": 1.0, "loaded": 0}]
	p.set_weapon_slots(p.hands)
	game.actions.pry_door(p, _a_locked_door())
	assert_eq(p.action, "pry", "the crowbar goes into the door")
	assert_almost_eq(p.action_t, game.actions.PRY_TIME, 0.0001)


func test_no_crowbar_no_prying() -> void:
	p.hands = [{"id": "knife", "quality": "factory", "condition": 1.0, "loaded": 0}]
	p.set_weapon_slots(p.hands)
	p.cancel_action()
	game.actions.pry_door(p, _a_locked_door())
	assert_eq(p.action, "", "a knife does not pry a door")
