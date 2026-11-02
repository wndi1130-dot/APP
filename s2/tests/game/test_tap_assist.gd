extends "res://addons/gut/test.gd"
## User decision 330: a tap on a thing walks over and does it, but not while
## one of the dead is near; then only the stick and the pads.

const FieldGame = preload("res://game/field_game.gd")
const FieldCombat = preload("res://game/field_combat.gd")

var game
var p
var item_at: Vector3


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 17, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	p = game.player
	p.position = game.lift(Vector2i(60, 7), 0)
	item_at = p.position + Vector3(2, 0, 0)
	game.ground_items.append({"pos": item_at, "id": "cloth", "n": 1})


func _dead(dist: float, state: String = "") -> Dictionary:
	# Ahead, where the player sees it: one unseen behind does not give itself away.
	p.facing = 0.0
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0, 0, dist))
	if state != "":
		z["state"] = state
	game._refresh_vision()
	return z


func _tap_item() -> bool:
	p.brain.erase("goal")
	return game.hud._tap_thing(p, item_at)


func test_a_tap_on_a_thing_walks_over_with_none_of_the_dead_near() -> void:
	assert_true(_tap_item())
	assert_true(p.brain.has("goal"))


func test_one_of_the_dead_near_turns_the_tap_off() -> void:
	_dead(FieldCombat.TAP_ASSIST_OFF_R - 1.0)
	assert_true(game.combat.tap_assist_off(p))
	assert_true(_tap_item(), "the tap is taken (it does not call a fight off)")
	assert_false(p.brain.has("goal"), "nobody walks over")


func test_the_dead_further_off_leave_it_on() -> void:
	_dead(FieldCombat.TAP_ASSIST_OFF_R + 1.0)
	assert_false(game.combat.tap_assist_off(p))
	assert_true(_tap_item())
	assert_true(p.brain.has("goal"))


func test_a_story_marker_is_not_walked_to_but_a_working_spot_is() -> void:
	# Story maps mark their scene places as spots of kind "story": nothing is drawn or done there yet.
	game.ground_items.clear()
	var cell := Vector2i(62, 7)
	for kind: String in ["story", "inspect"]:
		game.data["spots"]["tap_" + kind] = {"kind": kind, "cell": cell, "name": "자리", "zone_rect": Rect2i(cell, Vector2i.ONE)}
		p.brain.erase("goal")
		game.hud._tap_thing(p, game.lift(cell, 0))
		assert_eq(p.brain.has("goal"), kind != "story", kind)
		game.data["spots"].erase("tap_" + kind)


func test_frozen_or_downed_dead_do_not_turn_it_off() -> void:
	_dead(1.5, "downed")
	assert_false(game.combat.tap_assist_off(p))
	var z: Dictionary = game.zombies.spawn("frozen", p.position + Vector3(0.6, 0, 1.5))
	assert_eq(String(z["state"]), "frozen")
	game._refresh_vision()
	assert_false(game.combat.tap_assist_off(p))
	assert_true(_tap_item())
	assert_true(p.brain.has("goal"))
