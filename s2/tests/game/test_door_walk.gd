extends "res://addons/gut/test.gd"
## Walking into a locked door is as a tap on it (field_game _meets_door,
## field_actions open_door_on_way; the coordinator's call of 2026-10-30): with
## its key the walk opens it, with no sound the dead hear (P12); without,
## 「잠김」 and the ear's rattle — once in SHUT_TELL_S of the field's clock,
## not once a frame the stick is held against it, as for a boarded one. A
## companion's way goes round as before.

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


## A building's door on the ground, no plank on it, locked now, with open
## ground outside: the player stands there just short of it, the stick held
## at it.
func _against_locked_door() -> Vector2i:
	var g = game.grid
	for c: Vector2i in g.doors:
		var d: Dictionary = g.doors[c]
		if int(d.get("building", -1)) < 0 or BuildingRules.planks_total(d) > 0:
			continue
		for step: Vector2i in DIRS:
			if not g.indoor(c + step) and g.people_can_walk(c + step):
				g.set_door_state(c, "locked")
				var toward: Vector3 = FieldGrid.center(c) - FieldGrid.center(c + step)
				var p = game.player
				p.position = game.lift(c + step, 0) + toward * 0.35
				p.stop()
				p.stick = Vector2(toward.x, toward.z).normalized()
				return c
	return Vector2i(-1, -1)


## How many of the notes up now say `text`.
func _notes(text: String) -> int:
	var n := 0
	for t: Dictionary in game.hud.toasts:
		if String((t["l"] as Label).text).replace(String.chr(0x2060), "") == text:
			n += 1
	return n


func _walk(frames: int) -> void:
	for i in range(frames):
		game._update_person(game.player, 0.05)


func test_walking_into_a_locked_door_without_its_key_says_so_once_and_rattles_once() -> void:
	var c := _against_locked_door()
	assert_ne(c, Vector2i(-1, -1), "the map has a building door")
	var a = game.audio
	a.played.clear()
	_walk(40)
	assert_eq(String(game.grid.doors[c]["state"]), "locked", "it stays locked")
	assert_eq(_notes("잠김"), 1, "「잠김」 once, the stick held against it two seconds")
	assert_eq(a.played.count("door_locked"), 1, "and one rattle")


func test_walking_into_a_locked_door_with_its_key_opens_it_quietly() -> void:
	var c := _against_locked_door()
	assert_ne(c, Vector2i(-1, -1))
	var p = game.player
	p.add_item(FieldItems.key_for(int(game.grid.doors[c]["building"])))
	var a = game.audio
	a.played.clear()
	# Three seconds of the stick held at it: up to it, the key's turn, and on.
	var turns := 0
	var was := ""
	for i in range(60):
		game._update_person(p, 0.05)
		if String(p.action) == "door" and was != "door":
			turns += 1
		was = String(p.action)
	assert_eq(turns, 1, "the key's turn begins once, not over again while the stick is held")
	assert_eq(String(game.grid.doors[c]["state"]), "open", "the walk opened it with its key")
	assert_eq(_notes("잠김"), 0, "nothing to say")
	assert_false(a.played.has("door_locked"))
	assert_true(a.played.has("door_unlock"), "the key's small click")


func test_a_boarded_door_held_against_says_so_once() -> void:
	var c := _against_locked_door()
	assert_ne(c, Vector2i(-1, -1))
	game.grid.set_door_state(c, "closed")
	BuildingRules.add_plank(game.grid.doors[c], 0)
	BuildingRules.add_plank(game.grid.doors[c], 1)
	var a = game.audio
	a.played.clear()
	_walk(40)
	assert_eq(_notes("판자로 막혀 있다"), 1, "once, not a note a frame")
	assert_eq(a.played.count("boarded"), 1)


func test_a_companions_way_goes_round_a_locked_door_as_before() -> void:
	var mate = game.squad[1]
	assert_true(game._meets_door(game.player, {"state": "locked"}), "the player's walk stops to deal with it")
	assert_false(game._meets_door(mate, {"state": "locked"}), "a companion's way does not")
	assert_true(game._meets_door(mate, {"state": "closed"}), "a shut one, as ever, for all")
	assert_false(game._meets_door(game.player, {"state": "open"}))
	assert_false(game._meets_door(game.player, {"state": "broken"}))
