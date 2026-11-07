extends "res://addons/gut/test.gd"
## A press on a ground model takes that thing (field_hud.gd _pick_item with
## map_view.drawn_ground): three dropped at one spot are drawn apart, so the one
## pressed is the one picked, not the list's first at that spot (코디 11-07 10:3x ①).

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")

var game
var item_at: Vector3


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 17, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	game.ground_items.clear()
	# Keep placement independent of this stop's generated furniture.
	game.view.grid = FieldGrid.new(64, 16)
	game.view.levels = {0: game.view.grid}
	item_at = game.lift(Vector2i(60, 7), 0)
	for i: int in 3:
		game.ground_items.append({"pos": item_at, "id": "no_art_550", "n": 1})
	game.view.update_ground(game.ground_items)


func test_pick_each_drawn_position_and_empty_space() -> void:
	var drawn: Dictionary = game.view.drawn_ground(game.ground_items)
	assert_eq(drawn.size(), 3)
	for item: int in drawn:
		assert_eq(game.hud._pick_item(drawn[item]["at"]), item)
	assert_eq(game.hud._pick_item(item_at + Vector3(20, 0, 20)), -1)


## What is seen wins: a shining one (a light, no model) pressed on beats a model
## further off, and a fourth on a cell (not drawn) never beats the model drawn
## where the finger is.
func test_pick_seen_things_shining_first_then_undrawn_last() -> void:
	game.ground_items.clear()
	game.ground_items.append({"pos": item_at, "id": "no_art_550", "n": 1})
	game.ground_items.append({"pos": item_at + Vector3(0.5, 0, 0), "id": "no_art_550", "n": 1, "glint": true})
	game.view.update_ground(game.ground_items)
	assert_eq(game.hud._pick_item(item_at + Vector3(0.5, 0, 0)), 1, "the shining one under the finger")
	assert_eq(game.hud._pick_item(item_at), 0, "the model under the finger")
	game.ground_items.clear()
	for i: int in 4:
		game.ground_items.append({"pos": item_at, "id": "no_art_550", "n": 1})
	var drawn: Dictionary = game.view.drawn_ground(game.ground_items)
	assert_eq(drawn.size(), 3, "three drawn on the cell")
	assert_false(drawn.has(3), "the fourth is on the list only")
	assert_eq(game.hud._pick_item(item_at), 0, "the model at the spot, not the undrawn fourth")


func test_pick_refreshes_removed_item_and_empty_list() -> void:
	game.ground_items.remove_at(0)
	assert_eq(game.hud._pick_item(item_at), 0)
	assert_eq(game.view._drawn_ground_sig, game.ground_items.hash(), "picking refreshes before any table read")
	var drawn: Dictionary = game.view.drawn_ground(game.ground_items)
	assert_eq(drawn.size(), 2)
	for item: int in drawn:
		assert_lt(item, game.ground_items.size())
		assert_eq(game.hud._pick_item(drawn[item]["at"]), item)
	game.ground_items.clear()
	assert_eq(game.hud._pick_item(item_at), -1)
	assert_true(game.view.drawn_ground(game.ground_items).is_empty())


func test_pick_without_view_or_roots_and_glints_only() -> void:
	var view = game.view
	game.view = null
	assert_eq(game.hud._pick_item(item_at), 0)
	game.view = view
	var roots: Dictionary = view.level_roots.duplicate()
	view.level_roots.clear()
	view.update_ground(game.ground_items)
	assert_true(view.drawn_ground(game.ground_items).is_empty(), "no stale table without roots")
	assert_eq(game.hud._pick_item(item_at), 0)
	view.level_roots.merge(roots)
	assert_eq(view.drawn_ground(game.ground_items).size(), 3, "same list draws after roots return")
	game.ground_items.assign([{"pos": item_at, "id": "no_art_550", "glint": true}])
	assert_eq(game.hud._pick_item(item_at), 0)
	assert_true(view.drawn_ground(game.ground_items).is_empty())


func test_drawn_table_skips_missing_floor_and_grid_falls_back() -> void:
	game.ground_items.append({"pos": item_at + Vector3(0, 6, 0), "id": "no_art_550"})
	var roots: Dictionary = game.view.level_roots.duplicate()
	game.view.level_roots.erase(2)
	assert_false(game.view.drawn_ground(game.ground_items).has(3))
	game.view.level_roots.merge(roots)
	var levels: Dictionary = game.view.levels.duplicate()
	game.view.levels.clear()
	var c := FieldGrid.cell_of(item_at)
	assert_eq(game.view._ground_blocked(c, 0), game.view.grid.solid_at(c) != FieldGrid.Solid.NONE)
	assert_false(game.view._ground_blocked(c, 2), "missing upper grid is not blocked")
	var upper := FieldGrid.new(64, 16)
	upper.solid[upper.index(c)] = FieldGrid.Solid.BLOCK
	game.view.levels[2] = upper
	assert_true(game.view._ground_blocked(c, 2), "read the requested floor's furniture")
	assert_false(game.view._ground_blocked(c, 0), "ground floor still falls back to grid")
	game.view.levels = levels
