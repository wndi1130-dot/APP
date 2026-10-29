extends "res://addons/gut/test.gd"
## The room's sound (field_audio _tick_room, ROOM bus): inside, a sound made in
## the player's own room gets a reverb sized by the room's floor; outdoors and
## from behind a wall it gets none.

const FieldGame = preload("res://game/field_game.gd")
const FieldAudio = preload("res://game/audio/field_audio.gd")
const Grid = preload("res://game/world/field_grid.gd")

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var game


func before_each() -> void:
	seed(20261029)
	game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()


## A 5 x 5 room in a ring of wall on a 9 x 9 grid, building 0 inside and on its
## walls, a shut door in the west wall at (1, 4); open ground all round.
func _room() -> Grid:
	var g := Grid.new(9, 9)
	for y in range(1, 8):
		for x in range(1, 8):
			var c := Vector2i(x, y)
			g.building[g.index(c)] = 0
			if x == 1 or y == 1 or x == 7 or y == 7:
				g.solid[g.index(c)] = Grid.Solid.WALL
	var door := Vector2i(1, 4)
	g.solid[g.index(door)] = Grid.Solid.DOOR
	g.doors[door] = {"state": "closed", "hp": 3, "building": 0}
	return g


## One of the stop map's building doors on the ground with open ground outside it
## and two cells of floor in from it: [door, outside, one in, two in].
func _door_way() -> Array:
	var g = game.grid
	for c: Vector2i in g.doors:
		if int(g.doors[c].get("building", -1)) < 0:
			continue
		for d: Vector2i in DIRS:
			var out_c: Vector2i = c - d
			var in1: Vector2i = c + d
			var in2: Vector2i = c + d * 2
			if g.indoor(out_c) or not g.people_can_walk(out_c):
				continue
			if g.indoor(in1) and g.indoor(in2) and g.solid_at(in1) == Grid.Solid.NONE and g.solid_at(in2) == Grid.Solid.NONE:
				return [c, out_c, in1, in2]
	return []


func test_a_room_is_its_floor_within_its_walls_and_open_doors() -> void:
	var g := _room()
	assert_eq(FieldAudio.room_of(g, Vector2i(4, 4)).size(), 25, "five by five, the shut door not in it")
	g.doors[Vector2i(1, 4)]["state"] = "open"
	var open: Dictionary = FieldAudio.room_of(g, Vector2i(4, 4))
	assert_eq(open.size(), 26, "the open doorway is part of the room, the ground outside is not")
	assert_false(open.has(Vector2i(0, 4)))
	assert_true(FieldAudio.room_of(g, Vector2i(0, 0)).is_empty(), "outdoors there is no room")


func test_a_room_hears_its_furniture_and_shut_door_but_not_the_ground_outside() -> void:
	var g := _room()
	var chest := Vector2i(3, 3)
	g.solid[g.index(chest)] = Grid.Solid.BLOCK   # a piece of furniture
	var a = game.audio
	a.room_cells = FieldAudio.room_of(g, Vector2i(4, 4))
	a.room_key = [0, Vector2i(4, 4), g.revision]
	assert_false(a.room_cells.has(chest), "the air does not pass the furniture")
	assert_true(a.in_room(Grid.center(chest)), "but a lid opened on it is the room's sound")
	assert_true(a.in_room(Grid.center(Vector2i(1, 4))), "and so is the shut door's")
	assert_false(a.in_room(Grid.center(Vector2i(0, 4))), "the ground outside the shut door is not")
	assert_false(a.in_room(game.lift(chest, 1)), "nor the floor above")


func test_a_bigger_room_has_a_bigger_longer_reverb() -> void:
	var closet: Dictionary = FieldAudio.room_reverb(9.0)
	var kitchen: Dictionary = FieldAudio.room_reverb(25.0)
	var hall: Dictionary = FieldAudio.room_reverb(300.0)
	assert_almost_eq(float(closet["size"]), 0.2, 0.001)
	assert_almost_eq(float(hall["size"]), 0.7, 0.001)
	assert_lt(float(closet["size"]), float(kitchen["size"]))
	assert_lt(float(kitchen["size"]), float(hall["size"]))
	assert_lt(float(closet["wet"]), float(hall["wet"]), "a hall answers back more")
	assert_gt(float(closet["damp"]), float(hall["damp"]), "a small furnished room swallows more")
	assert_almost_eq(float(FieldAudio.room_reverb(2.0)["size"]), 0.2, 0.001, "smaller than a closet is a closet")
	assert_almost_eq(float(FieldAudio.room_reverb(5000.0)["size"]), 0.7, 0.001)


func test_inside_a_house_its_sounds_go_through_the_room_and_outside_they_do_not() -> void:
	var way: Array = _door_way()
	assert_false(way.is_empty(), "the map has a door into a building with floor behind it")
	if way.is_empty():
		return
	var a = game.audio
	var i: int = AudioServer.get_bus_index(FieldAudio.ROOM_BUS)
	assert_true(i >= 0, "the room has a bus of its own")
	assert_eq(AudioServer.get_bus_send(i), &"SFX", "sent to SFX: it ducks with the rest")
	assert_true(AudioServer.get_bus_effect(i, 0) is AudioEffectReverb)
	var inside: Vector3 = game.lift(way[3], 0)
	game.player.position = inside
	a._tick_room(inside)
	assert_gt(a.room_area, 0.0, "the player stands in a room")
	assert_true(a.in_room(inside))
	assert_eq(a._bus_at(inside), FieldAudio.ROOM_BUS)
	var verb := AudioServer.get_bus_effect(i, 0) as AudioEffectReverb
	assert_almost_eq(verb.room_size, float(FieldAudio.room_reverb(a.room_area)["size"]), 0.0001, "the reverb is the room's size")
	a.footstep(inside, false)
	assert_eq(a.last_bus, FieldAudio.ROOM_BUS, "a step indoors is heard in the room")
	var outside: Vector3 = game.lift(way[1], 0)
	game.player.position = outside
	a._tick_room(outside)
	assert_true(a.room_cells.is_empty(), "outdoors, no room")
	a.footstep(outside, false)
	assert_eq(a.last_bus, "SFX", "a step outdoors is dry")
