extends GutTest
## Decision 439 card 1: indoors after dark a room is dark away from the light of
## its windows and of any lamp; into the dark the eye reaches as far as in a
## cellar, the dead's as well as the living's.

const BuildingRules = preload("res://game/sim/building_rules.gd")
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


## An indoor ground cell farther than the window light from every window, and
## one right inside a window that lets the light in.
func _cells(game) -> Array:
	var g = game.grid
	var lit := BuildingRules.window_lit_cells(g)
	var far := Vector2i(-1, -1)
	var near := Vector2i(-1, -1)
	for y in g.height:
		for x in g.width:
			var c := Vector2i(x, y)
			if not g.indoor(c) or not g.people_can_walk(c):
				continue
			if far.x < 0 and not lit.has(g.index(c)):
				far = c
			if near.x < 0 and lit.has(g.index(c)):
				near = c
	return [far, near]


func test_the_new_values_are_the_listed_ones() -> void:
	assert_eq([BuildingRules.WINDOW_LIGHT_CELLS, BuildingRules.DARK_SIGHT, BuildingRules.LIT_MIN], [2, 7.0, 40])
	assert_eq(BuildingRules.DARK_SIGHT, float(FieldGame.SIGHT_CELLAR), "as far as in a cellar")
	assert_eq(BuildingRules.dark_reach(20.0, true), 7.0)
	assert_eq(BuildingRules.dark_reach(20.0, false), 20.0)
	assert_eq(BuildingRules.dark_reach(5.0, true), 5.0, "never farther than it was")


func test_by_day_nothing_is_dark_and_by_night_only_the_unlit_rooms() -> void:
	var game = _game()
	var cells := _cells(game)
	var far: Vector2i = cells[0]
	var near: Vector2i = cells[1]
	assert_ne(far, Vector2i(-1, -1), "an unlit room")
	assert_ne(near, Vector2i(-1, -1), "a room by a window")
	assert_false(game.dark_at(FieldGrid.center(far)), "by day")
	game.clock.elapsed = NIGHT
	assert_true(game.clock.is_dark())
	game.lit_now = {}
	assert_true(game.dark_at(FieldGrid.center(far)))
	assert_false(game.dark_at(FieldGrid.center(near)), "a window's light")
	assert_false(game.dark_at(FieldGrid.center(game.data["spawns"]["squad"][0])), "outdoors is the night's, not a room's")
	# A lamp lights it.
	game.lit_now = {game.grid.index(far): 200}
	assert_false(game.dark_at(FieldGrid.center(far)), "a lamp's light")


func test_a_drawn_curtain_or_three_planks_put_the_window_out() -> void:
	var game = _game()
	game.clock.elapsed = NIGHT
	game.lit_now = {}
	var g = game.grid
	var w_cell := Vector2i(-1, -1)
	var inside := Vector2i(-1, -1)
	var keys: Array = g.windows.keys()
	keys.sort()
	for c: Vector2i in keys:
		var o: int = g.outer_face(c)
		if o < 0 or BuildingRules.window_opaque(g.windows[c]):
			continue
		var f: Vector2i = g.faces(c)[1 - o]
		if g.people_can_walk(f):
			w_cell = c
			inside = f
			break
	assert_ne(w_cell, Vector2i(-1, -1))
	# The light of other windows may still reach it: only this window's own share is checked.
	var others := 0
	for c: Vector2i in g.windows:
		if c != w_cell and not BuildingRules.window_opaque(g.windows[c]) and maxi(absi(c.x - inside.x), absi(c.y - inside.y)) <= BuildingRules.WINDOW_LIGHT_CELLS:
			others += 1
	assert_false(game.dark_at(FieldGrid.center(inside)))
	g.windows[w_cell]["curtain"] = "closed"
	g.refresh_cell(w_cell)
	assert_eq(game.dark_at(FieldGrid.center(inside)), others == 0, "drawn: dark unless another window lights it")
	g.windows[w_cell]["curtain"] = ""
	for i in BuildingRules.SIGHT_PLANKS:
		BuildingRules.add_plank(g.windows[w_cell], 1)
	g.refresh_cell(w_cell)
	assert_eq(game.dark_at(FieldGrid.center(inside)), others == 0, "boarded up: the same")


func test_the_chief_sees_no_farther_than_a_cellar_into_an_unlit_room_at_night() -> void:
	var game = _game()
	game.mask_on = true
	var g = game.grid
	var far: Vector2i = _cells(game)[0]
	game.player.position = FieldGrid.center(far)
	game.player.lamp_on = false
	var n: int = g.width * g.height
	game._refresh_vision()
	var day_far := _far_dark_seen(game, far, n)
	game.clock.elapsed = NIGHT
	game._refresh_vision()
	assert_eq(_far_dark_seen(game, far, n), 0, "nothing unlit beyond the cellar's reach")
	assert_gte(day_far, 0)


## Indoor cells seen beyond DARK_SIGHT that would be dark now.
func _far_dark_seen(game, origin: Vector2i, n: int) -> int:
	var g = game.grid
	var count := 0
	for key: int in game.seen_now:
		if key < n or key >= 2 * n:
			continue
		var i: int = key - n
		var c := Vector2i(i % g.width, i / g.width)
		if Vector2(c - origin).length() > BuildingRules.DARK_SIGHT and game._dark_cell(g, 0, c) and game.clock.is_dark():
			count += 1
	return count
