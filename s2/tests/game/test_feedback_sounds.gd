extends "res://addons/gut/test.gd"
## Small sounds for the player's ear where the field already says no or hurts
## (field_audio door_turn by_key, shut_fast, feel_sound bite): a key's click
## and the door going quietly, softer than one opened by hand; a locked door's
## rattle; a boarded door's thud; a bite, and a duller one the coat took.
## Until their files are in, stand-ins. Nothing in the rules hears any of them.

const FieldGame = preload("res://game/field_game.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const BuildingRules = preload("res://game/sim/building_rules.gd")
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var game


func before_each() -> void:
	seed(20261030)
	game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()


## A building's door on the ground, no plank on it, with open ground beside
## it; locked now, the player at hand outside it, nothing in the hands.
func _at_locked_door() -> Vector2i:
	var g = game.grid
	for c: Vector2i in g.doors:
		var d: Dictionary = g.doors[c]
		if int(d.get("building", -1)) < 0 or BuildingRules.planks_total(d) > 0:
			continue
		for step: Vector2i in DIRS:
			if not g.indoor(c + step) and g.people_can_walk(c + step):
				g.set_door_state(c, "locked")
				var p = game.player
				p.position = FieldGrid.center(c) + (FieldGrid.center(c + step) - FieldGrid.center(c)) * 0.8
				p.stop()
				p.hands = []
				return c
	return Vector2i(-1, -1)


func _finish(p) -> void:
	p.action_t = 0.001
	game._update_person(p, 0.1)


func test_a_key_clicks_and_the_door_goes_softer_than_by_hand_and_the_dead_hear_nothing() -> void:
	var c := _at_locked_door()
	assert_ne(c, Vector2i(-1, -1), "the map has a building door")
	var a = game.audio
	var p = game.player
	a.door_turn(c, "open")
	var by_hand: float = a.last_shot.volume_db
	p.add_item(FieldItems.key_for(int(game.grid.doors[c]["building"])))
	a.played.clear()
	a.last_tag_group = "none"
	var heard: int = game.ledger.sound_events
	game.actions.door_default(p, c, "")
	_finish(p)
	assert_eq(String(game.grid.doors[c]["state"]), "open", "the key opened it")
	assert_true(a.played.has("door_unlock"), "the key's click")
	assert_true(a.last_shot.stream.resource_path.get_file().begins_with(String(a.DOOR_KEY[4])), "played: the impact set's iron stands in")
	assert_false(a.played.has("door_open"), "the door a moment after")
	await wait_seconds(a.DOOR_KEY_LAG + 0.15)
	assert_true(a.played.has("door_open"), "then the door")
	assert_lt(a.last_shot.volume_db, by_hand - 3.0, "softer than a door opened by hand")
	assert_eq(game.ledger.sound_events, heard, "no sound the dead hear (P12)")
	assert_eq(a.last_tag_group, "none")


func test_a_locked_door_rattles_and_a_boarded_one_thuds_at_the_players_hand() -> void:
	var c := _at_locked_door()
	assert_ne(c, Vector2i(-1, -1))
	var a = game.audio
	var p = game.player
	a.played.clear()
	a.last_tag_group = "none"
	var heard: int = game.ledger.sound_events
	game.actions.door_default(p, c, "")
	assert_true(a.played.has("door_locked"), "no key, no bar: it rattles")
	a.played.clear()
	game.actions.open_door_on_way(p, c)
	assert_false(a.played.has("door_locked"), "asked again at once: not again")
	a.shut_heard.clear()   # as though the gap had gone by
	game.actions.open_door_on_way(p, c)
	assert_true(a.played.has("door_locked"), "the way's own check rattles it too")
	BuildingRules.add_plank(game.grid.doors[c], 0)
	BuildingRules.add_plank(game.grid.doors[c], 1)
	a.played.clear()
	game.actions.door_default(p, c, "")
	assert_true(a.played.has("boarded"), "boarded: it thuds")
	assert_false(a.played.has("door_locked"))
	# A stick held against it asks every frame (field_game _drive): one thud.
	a.shut_heard.clear()
	a.played.clear()
	for i in range(10):
		game.actions.open_door_on_way(p, c)
	assert_eq(a.played.count("boarded"), 1, "held against it, it thuds once")
	assert_eq(game.ledger.sound_events, heard, "nothing the dead hear")
	assert_eq(a.last_tag_group, "none")
	# Until their files are in, the impact set's wood and slam stand in.
	for why: String in a.SHUT_FAST:
		a.shut_heard.clear()
		a.last_shot = null
		a.shut_fast(c, why)
		assert_not_null(a.last_shot, why + ": played")
		assert_true(a.last_shot.stream.resource_path.get_file().begins_with(String(a.SHUT_FAST[why][4])), why)


func test_a_bite_is_heard_and_one_the_coat_took_is_softer() -> void:
	var a = game.audio
	var p = game.player
	a.played.clear()
	game.feel.bitten(p, false)
	assert_true(a.played.has("bite"))
	assert_not_null(a.last_shot, "a stand-in until its files are in")
	assert_true(a.last_shot.stream in a.lib["blow_cut"], "a cut's layer stands in")
	var loud: float = a.last_shot.volume_db
	game.feel.bitten(p, true)
	assert_true(a.played.has("bite_blocked"))
	assert_true(a.last_shot.stream in a.lib["blow_thud"], "the coat's: a thud")
	assert_lt(a.last_shot.volume_db, loud, "and softer")
	# One of the squad bitten near is heard as well.
	var mate = game.squad[1]
	mate.position = p.position + Vector3(4, 0, 0)
	a.played.clear()
	game.feel.bitten(mate, false)
	assert_true(a.played.has("bite"), "a companion's bite is heard")
	assert_almost_eq(a.last_shot.position.distance_to(mate.position), 0.0, 0.001, "played where it is")
	assert_gt(a.last_shot.volume_db, -79.0)


func test_a_key_door_shut_again_or_a_stop_ended_meanwhile_makes_no_late_sound() -> void:
	var c := _at_locked_door()
	assert_ne(c, Vector2i(-1, -1))
	var a = game.audio
	var soft: Array = (a.DOOR_TURN["open"] as Array).duplicate()
	a.played.clear()
	game.grid.set_door_state(c, "closed")
	a._key_door_goes(c, soft, FieldGrid.center(c))
	assert_false(a.played.has("door_open"), "shut again: no late door")
	game.grid.set_door_state(c, "open")
	game.ended = true
	a._key_door_goes(c, soft, FieldGrid.center(c))
	assert_false(a.played.has("door_open"), "the stop over: none either")
	game.ended = false
	a._key_door_goes(c, soft, FieldGrid.center(c))
	assert_true(a.played.has("door_open"), "else it goes")
