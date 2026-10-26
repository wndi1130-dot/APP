extends GutTest
## Decision 469 D3 나: the room the eye stands in is drawn as seen whichever way
## the eye faces, its walls too; the rules' sight (who and what is seen) stays
## the cone's, by day and after dark.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldClock = preload("res://game/sim/field_clock.gd")

const NIGHT: float = (FieldClock.SUNSET_MIN - FieldClock.ARRIVE_MIN) * 60.0 / FieldClock.GAME_PER_REAL + 40.0


func _game() -> Node:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	return game


## The southmost floor cell of the first room with at least 20 floor cells,
## so a cone facing south leaves most of the room behind the eye.
func _room_corner(game) -> Vector2i:
	var g: FieldGrid = game.grid
	for y in g.height:
		for x in g.width:
			var c := Vector2i(x, y)
			if not g.indoor(c) or g.solid_at(c) != FieldGrid.Solid.NONE:
				continue
			var cells: Array[int] = game._room_cells(g, 0, c)
			var floor_n := 0
			var south := c
			for i in cells:
				var d := Vector2i(i % g.width, i / g.width)
				if g.solid_at(d) == FieldGrid.Solid.NONE:
					floor_n += 1
					if d.y > south.y:
						south = d
			if floor_n >= 20:
				return south
	return Vector2i(-1, -1)


func _shown(game) -> Dictionary:
	return game.view._prop_seen_now


func test_the_room_is_drawn_whole_and_the_rules_keep_the_cone() -> void:
	var game = _game()
	var g: FieldGrid = game.grid
	var at := _room_corner(game)
	assert_ne(at, Vector2i(-1, -1), "a room of 20 floor cells")
	game.player.position = FieldGrid.center(at)
	game.player.facing = 0.0  # looking south, out of the room's far end
	game._refresh_vision()
	var n: int = g.width * g.height
	var room: Array[int] = game._room_cells(g, 0, at)
	var behind := 0
	for i in room:
		assert_true(_shown(game).has(n + i), "drawn as seen")
		assert_eq(g.building_at(Vector2i(i % g.width, i / g.width)), g.building_at(at), "one building")
		if not game.seen_now.has(n + i):
			behind += 1
	assert_gt(behind, 0, "the cone does not see all the room: only the picture shows it")
	for key: int in game.seen_now:
		assert_true(_shown(game).has(key), "the cone's cells are drawn too")


func test_walls_close_the_room() -> void:
	var game = _game()
	var g: FieldGrid = game.grid
	var at := _room_corner(game)
	var room: Array[int] = game._room_cells(g, 0, at)
	var walls := 0
	for i in room:
		var c := Vector2i(i % g.width, i / g.width)
		var s := g.solid_at(c)
		if s == FieldGrid.Solid.WALL or s == FieldGrid.Solid.DOOR or s == FieldGrid.Solid.WINDOW:
			walls += 1
			continue
		# Every floor cell's sides are room cells or the room's own walls.
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			assert_true(room.has(g.index(c + d)), "floor %s goes no further than its walls" % [c])
	assert_gt(walls, 0, "the walls round it are drawn as well")


func test_after_dark_the_room_keeps_its_outline_but_not_its_dead() -> void:
	var game = _game()
	var g: FieldGrid = game.grid
	var at := _room_corner(game)
	game.player.position = FieldGrid.center(at)
	game.player.facing = 0.0
	game.clock.elapsed = NIGHT
	game.lit_now = {}
	game._refresh_vision()
	var n: int = g.width * g.height
	for i in game._room_cells(g, 0, at):
		assert_true(_shown(game).has(n + i), "the outline is drawn after dark")
	for key: int in game.seen_now:
		var c := Vector2i((key % n) % g.width, (key % n) / g.width)
		assert_false(Vector2(c - at).length() > 7.5 and game._dark_cell(g, 0, c), "the rules' dark rooms stay dark")


func test_no_room_outdoors_or_in_the_cellar() -> void:
	var game = _game()
	var g: FieldGrid = game.grid
	var out := Vector2i(-1, -1)
	for y in g.height:
		for x in g.width:
			if out.x < 0 and not g.indoor(Vector2i(x, y)) and g.people_can_walk(Vector2i(x, y)):
				out = Vector2i(x, y)
	assert_true(game._room_cells(g, 0, out).is_empty(), "outdoors")
	assert_true(game._room_cells(g, -1, _room_corner(game)).is_empty(), "the cellar keeps its own dark")
