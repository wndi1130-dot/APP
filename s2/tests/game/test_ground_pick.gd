extends "res://addons/gut/test.gd"
## A press on a ground model takes that thing (field_hud.gd _pick_item with
## map_view.drawn_ground): three dropped at one spot are drawn apart, so the one
## pressed is the one picked, not the list's first at that spot (코디 11-07 10:3x ①).

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const GroundLook = preload("res://game/world/ground_look.gd")

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
	assert_eq(game.view._drawn_ground_sig, game.view._ground_signature(game.ground_items, game.view.level_roots), "picking refreshes before any table read")
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


func _visible_root(lv: int) -> Node3D:
	if not game.view.level_roots.has(lv):
		var created := Node3D.new()
		game.view.add_child(created)
		game.view.level_roots[lv] = created
	var root: Node3D = game.view.level_roots[lv]
	root.visible = true
	return root


func test_hidden_floor_models_and_glints_do_not_outrank_visible_things() -> void:
	_visible_root(0)
	var upper := _visible_root(1)
	upper.visible = false
	game.ground_items.assign([
		{"pos": item_at + Vector3(0.3, 0, 0), "id": "no_art_550"},
		{"pos": game.shift_to_height(item_at, 3.0), "id": "no_art_550"},
	])
	assert_eq(game.view.drawn_ground(game.ground_items).size(), 2)
	assert_eq(game.hud._pick_item(item_at), 0, "the hidden model is closer but not visible")
	upper.visible = true
	assert_eq(game.hud._pick_item(item_at), 1, "visibility is read without a list change")
	game.ground_items[1]["glint"] = true
	upper.visible = false
	assert_eq(game.hud._pick_item(item_at), 0, "a hidden light has no visible priority")
	upper.visible = true
	assert_eq(game.hud._pick_item(item_at), 1)


func test_visible_glint_wins_with_empty_drawn_table_only_when_view_ready() -> void:
	var root := _visible_root(0)
	game.view.level_roots.erase(2)
	game.ground_items.assign([
		{"pos": game.shift_to_height(item_at, 6.0), "id": "no_art_550"},
		{"pos": item_at + Vector3(0.2, 0, 0), "id": "no_art_550", "glint": true},
	])
	assert_true(game.view.drawn_ground(game.ground_items).is_empty())
	assert_eq(game.hud._pick_item(item_at), 1, "a visible light beats the closer missing-floor row")
	root.visible = false
	assert_eq(game.hud._pick_item(item_at), 0)
	root.visible = true
	var view = game.view
	game.view = null
	assert_eq(game.hud._pick_item(item_at), 0, "no view keeps nearest-centre picking")
	game.view = view
	var roots: Dictionary = view.level_roots.duplicate()
	view.level_roots.clear()
	assert_eq(game.hud._pick_item(item_at), 0, "no roots keeps nearest-centre picking")
	view.level_roots.merge(roots)


func test_tap_drawn_position_keeps_item_number_and_row_identity() -> void:
	_visible_root(0)
	game.grid = game.view.grid
	game.levels = game.view.levels
	game.grid.refresh_paths()
	var p = game.player
	p.position = item_at - Vector3(3, 0, 0)
	game.hud.ally_buttons.clear()
	var drawn: Dictionary = game.view.drawn_ground(game.ground_items)
	var row: Dictionary = game.ground_items[2]
	assert_true(game.hud._tap_thing(p, drawn[2]["at"]))
	var goal: Dictionary = p.brain.get("goal", {})
	assert_eq(goal.get("key", -1), 2)
	assert_true(is_same(goal.get("ground_item"), row), "the goal keeps the original row")


func test_same_list_rebuilds_after_furniture_blocks_a_watched_cell() -> void:
	game.ground_items.assign([{"pos": item_at + Vector3(0.4, 0, 0), "id": "no_art_550"}])
	game.view.update_ground(game.ground_items)
	var old_mesh: Mesh = game.view.ground_nodes[0].mesh
	var sig: int = game.ground_items.hash()
	var c := FieldGrid.cell_of(game.ground_items[0]["pos"])
	game.view.grid.set_solid(c, FieldGrid.Solid.LOW)
	game.view.grid.refresh_cell(c)
	var drawn: Dictionary = game.view.drawn_ground(game.ground_items)
	assert_eq(game.ground_items.hash(), sig)
	assert_false(is_same(old_mesh, game.view.ground_nodes[0].mesh))
	assert_eq(drawn.size(), 1)
	var piece: Dictionary = drawn[0]
	assert_gte(GroundLook.footprint_gap(Vector2(piece["at"].x, piece["at"].z), Vector2(piece["size"].x, piece["size"].z), piece["yaw"], Vector2(c.x + 0.5, c.y + 0.5), Vector2.ONE, 0.0), -0.000001)
	game.view.grid.set_solid(c, FieldGrid.Solid.NONE)
	game.view.grid.refresh_cell(c)
	drawn = game.view.drawn_ground(game.ground_items)
	assert_eq(drawn[0]["at"], game.ground_items[0]["pos"], "removing the furniture restores the home spot")


func test_unrelated_revision_reuses_mesh_and_list_change_still_rebuilds() -> void:
	var mesh: Mesh = game.view.ground_nodes[0].mesh
	game.view.update_ground(game.ground_items)
	assert_true(is_same(mesh, game.view.ground_nodes[0].mesh))
	game.view.grid.set_solid(Vector2i(1, 1), FieldGrid.Solid.LOW)
	game.view.grid.refresh_cell(Vector2i(1, 1))
	game.view.update_ground(game.ground_items)
	assert_true(is_same(mesh, game.view.ground_nodes[0].mesh), "unwatched changes do not rebuild")
	var c := FieldGrid.cell_of(item_at)
	game.view.grid.refresh_cell(c)
	game.view.update_ground(game.ground_items)
	assert_true(is_same(mesh, game.view.ground_nodes[0].mesh), "unchanged blocking does not rebuild")
	assert_eq(game.view._ground_revisions[0], game.view.grid.revision)
	var revision: int = game.view.grid.revision
	game.ground_items.remove_at(2)
	assert_eq(game.view.drawn_ground(game.ground_items).size(), 2)
	assert_false(is_same(mesh, game.view.ground_nodes[0].mesh))
	assert_eq(game.view.grid.revision, revision)


func test_partial_root_removal_and_return_refresh_the_same_list() -> void:
	var upper := _visible_root(2)
	game.ground_items.append({"pos": item_at + Vector3(0, 6, 0), "id": "no_art_550"})
	assert_true(game.view.drawn_ground(game.ground_items).has(3))
	game.view.level_roots.erase(2)
	assert_false(game.view.drawn_ground(game.ground_items).has(3))
	assert_null(game.view.ground_nodes[2].mesh)
	game.view.level_roots[2] = upper
	assert_true(game.view.drawn_ground(game.ground_items).has(3))
	assert_not_null(game.view.ground_nodes[2].mesh)


func test_missing_grid_and_replacement_at_the_same_revision() -> void:
	game.view.levels.clear()
	game.view.grid = null
	game.ground_items.assign([{"pos": item_at + Vector3(0.4, 0, 0), "id": "no_art_550"}])
	assert_eq(game.view.drawn_ground(game.ground_items).size(), 1, "no grid can still draw")
	var empty := FieldGrid.new(64, 16)
	game.view.grid = empty
	game.view.update_ground(game.ground_items)
	var mesh: Mesh = game.view.ground_nodes[0].mesh
	var replacement := FieldGrid.new(64, 16)
	var c := FieldGrid.cell_of(game.ground_items[0]["pos"])
	replacement.set_solid(c, FieldGrid.Solid.LOW)
	assert_eq(empty.revision, replacement.revision)
	game.view.grid = replacement
	var drawn: Dictionary = game.view.drawn_ground(game.ground_items)
	assert_false(is_same(mesh, game.view.ground_nodes[0].mesh), "grid identity also invalidates watched cells")
	assert_ne(drawn[0]["at"], game.ground_items[0]["pos"])
