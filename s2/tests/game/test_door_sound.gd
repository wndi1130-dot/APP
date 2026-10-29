extends "res://addons/gut/test.gd"
## A building's door turned by a hand is heard (field_audio door_turn): opening
## and shutting each their own sound, the impact set's wood until their files
## are in. Only the player's ear: nothing in the rules hears it.

const FieldGame = preload("res://game/field_game.gd")
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


## A shut (not locked, not boarded) building door on the ground and the open
## ground just outside it: [door, outside].
func _shut_door() -> Array:
	var g = game.grid
	for c: Vector2i in g.doors:
		var d: Dictionary = g.doors[c]
		if int(d.get("building", -1)) < 0 or String(d.get("state", "")) != "closed":
			continue
		var planks: Variant = d.get("planks")
		if planks is Array and int(planks[0]) + int(planks[1]) > 0:
			continue
		for step: Vector2i in DIRS:
			if not g.indoor(c + step) and g.people_can_walk(c + step):
				return [c, c + step]
	return []


func test_opening_and_shutting_a_door_is_heard() -> void:
	var way: Array = _shut_door()
	assert_false(way.is_empty(), "the map has a shut building door")
	if way.is_empty():
		return
	var c: Vector2i = way[0]
	game.player.position = game.lift(way[1], 0)
	var a = game.audio
	a.played.clear()
	a.last_tag_group = "none"
	game.actions._set_door(c, "open")
	assert_eq(String(game.grid.doors[c]["state"]), "open")
	assert_true(a.played.has("door_open"), "the door opening is heard")
	assert_false(a.played.has("door_close"))
	game.actions._set_door(c, "closed")
	assert_eq(String(game.grid.doors[c]["state"]), "closed")
	assert_true(a.played.has("door_close"), "and its shutting")
	assert_eq(a.last_tag_group, "none", "no sound of the world: the dead hear no door turned")


func test_until_its_files_are_in_a_door_is_the_wood_pitched_down() -> void:
	var way: Array = _shut_door()
	if way.is_empty():
		fail_test("the map has a shut building door")
		return
	var a = game.audio
	if a.has("door_open"):
		pass_test("the door has files of its own")
		return
	game.player.position = game.lift(way[1], 0)
	a.door_turn(way[0], "open")
	var o: AudioStreamPlayer3D = a.last_shot
	assert_not_null(o, "heard from beside the door")
	if o == null:
		return
	assert_true(o.stream.resource_path.get_file().begins_with("wooden"), "the impact set's wood stands in")
	assert_lt(o.pitch_scale, 0.9, "pitched down")
	a.door_turn(way[0], "sideways")
	assert_false(a.played.has("sideways"), "a state that is no turn makes no sound")
