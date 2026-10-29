extends "res://addons/gut/test.gd"
## A building's window opened or shut, or its curtain drawn, by a hand is heard
## (field_audio window_turn, from field_actions _set_window_open and
## _curtain_set): the player's ear only, as a door turned, no sound the dead
## hear. Until their files are in: the impact set's wood, and for a curtain a
## light swing pitched low. The stop laying out its windows makes none.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")

var game


func before_each() -> void:
	seed(20261030)
	game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()


## A whole window of a home on the ground whose two faces can be stood on, the
## player at its inner face (where its latch is just lifted).
func _at_window() -> Vector2i:
	var keys: Array = game.grid.windows.keys()
	keys.sort()
	for c: Vector2i in keys:
		var w: Dictionary = game.grid.windows[c]
		if w["broken"] or game.grid.outer_face(c) < 0:
			continue
		var f: Array[Vector2i] = game.grid.faces(c)
		if game.grid.people_can_walk(f[0]) and game.grid.people_can_walk(f[1]):
			game.player.position = FieldGrid.center(f[1 - game.grid.outer_face(c)])
			game.player.stop()
			return c
	return Vector2i(-1, -1)


func _finish(p) -> void:
	p.action_t = 0.001
	game._update_person(p, 0.1)


func test_the_stop_laying_out_its_windows_and_curtains_is_no_sound() -> void:
	var a = game.audio
	for g: String in ["window_open", "window_close", "curtain"]:
		assert_false(a.played.has(g), g + ": not as the stop is laid out")


func test_a_window_opened_and_shut_is_heard_and_the_dead_hear_nothing() -> void:
	var c := _at_window()
	assert_ne(c, Vector2i(-1, -1), "the map has a whole window")
	var a = game.audio
	var p = game.player
	var w: Dictionary = game.grid.windows[c]
	w["open"] = false
	w["latched"] = false
	game.grid.refresh_cell(c)
	a.played.clear()
	a.last_tag_group = "none"
	var heard: int = game.ledger.sound_events
	game.actions.open_window(p, c)
	assert_false(a.played.has("window_open"), "not while the hand is at it")
	_finish(p)
	assert_true(bool(w["open"]))
	assert_true(a.played.has("window_open"), "opened: heard")
	assert_not_null(a.last_shot)
	assert_true(a.last_shot.stream.resource_path.get_file().begins_with(String(a.WINDOW_TURN["open"][4])), "the impact set's wood stands in")
	game.actions.close_window(p, c)
	_finish(p)
	assert_false(bool(w["open"]))
	assert_true(a.played.has("window_close"), "shut: heard")
	assert_eq(game.ledger.sound_events, heard, "no sound the dead hear")
	assert_eq(a.last_tag_group, "none")


func test_a_curtain_drawn_is_heard_as_cloth_and_the_dead_hear_nothing() -> void:
	var c := _at_window()
	assert_ne(c, Vector2i(-1, -1))
	var a = game.audio
	var p = game.player
	var w: Dictionary = game.grid.windows[c]
	w["curtain"] = "open"
	game.grid.refresh_cell(c)
	a.played.clear()
	a.last_tag_group = "none"
	var heard: int = game.ledger.sound_events
	game.actions.toggle_curtain(p, c)
	_finish(p)
	assert_eq(String(w["curtain"]), "closed")
	assert_true(a.played.has("curtain"), "drawn: heard")
	assert_not_null(a.last_shot)
	assert_true(a.last_shot.stream in a.lib["swing_light"], "a light swing stands in")
	assert_eq(game.ledger.sound_events, heard, "no sound the dead hear")
	assert_eq(a.last_tag_group, "none")
