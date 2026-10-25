extends "res://addons/gut/test.gd"

const R = preload("res://game/sim/window_rules.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")


func test_break_clear_and_cross_are_distinct_states() -> void:
	var whole := {"broken": false, "glass": true}
	var sharp := {"broken": true, "glass": true}
	var clean := {"broken": true, "glass": false}
	assert_true(R.can_break(whole))
	assert_false(R.can_clear(whole))
	assert_false(R.can_cross(whole, 0))
	assert_false(R.can_break(sharp))
	assert_true(R.can_clear(sharp))
	assert_true(R.can_cross(sharp, 0))
	assert_false(R.can_clear(clean))
	assert_true(R.can_cross(clean, 2))


func test_missing_windows_and_immobile_loads_cannot_be_crossed() -> void:
	assert_false(R.can_break({}))
	assert_false(R.can_clear({}))
	assert_false(R.can_cross({}, 0))
	assert_false(R.can_cross({"broken": true, "glass": false}, 3))


func test_combat_can_break_a_window_without_a_timed_interaction() -> void:
	var game = FieldGame.new()
	game.opts = {"seed": 1, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	var cell: Vector2i = game.grid.windows.keys()[0]
	var window: Dictionary = game.grid.windows[cell]
	window["broken"] = false
	var p = game.player
	p.position = FieldGrid.center(cell) - Vector3(1.0, 0, 0)
	p.facing = PI / 2.0
	p.hands = [{"id": "crowbar", "quality": "factory", "condition": 1.0, "loaded": 0}]
	game.combat._swing_empty(p)
	assert_true(window["broken"], "the existing impact callback has no work ticket")


func test_glass_odds_and_the_one_stop_before_climbing_in() -> void:
	var sharp := {"broken": true, "glass": true}
	var clean := {"broken": true, "glass": false}
	assert_eq(R.cross_cut_chance(sharp, false), 0.5)
	assert_eq(R.cross_cut_chance(sharp, true), 0.2)
	assert_eq(R.cross_cut_chance(clean, false), 0.0)
	assert_eq(R.clear_cut_chance(false, false), 0.1)
	assert_eq(R.clear_cut_chance(true, false), 0.0, "gloves")
	assert_eq(R.clear_cut_chance(false, true), 0.0, "something in the hand knocks the shards out")
	assert_true(R.holds_for_choice(sharp, false, false, 0.0, 10.0), "first walk-in is held")
	assert_true(R.holds_for_choice(sharp, false, true, 9.0, 10.0), "the choice is still up")
	assert_false(R.holds_for_choice(sharp, false, true, 5.0, 10.0), "after the hold it lets through")
	assert_false(R.holds_for_choice(sharp, false, true, -INF, 10.0), "chose to go straight through")
	assert_false(R.holds_for_choice(sharp, true, false, 0.0, 10.0), "running goes straight in")
	assert_false(R.holds_for_choice(clean, false, false, 0.0, 10.0))


func test_a_broken_frame_offers_its_glass_and_stops_the_walking_player_once() -> void:
	var game = FieldGame.new()
	game.opts = {"seed": 1, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.data["containers"] = {}
	game.ground_items.clear()
	var c := Vector2i(-1, -1)
	for key: Vector2i in game.grid.windows:
		var sides: Array[Vector2i] = game.grid.faces(key)
		if sides.size() == 2 and game.grid.people_can_walk(sides[0]) and game.grid.people_can_walk(sides[1]):
			c = key
			break
	assert_ne(c, Vector2i(-1, -1), "a window with floor on both sides")
	game.grid.break_window(c)
	var p = game.player
	p.position = FieldGrid.center(game.grid.faces(c)[0])
	p.running = false
	var labels: Array = game.actions.window_choices(p, c).map(func(r) -> String: return r["label"])
	assert_has(labels, "유리 치우기")
	assert_has(labels, "그냥 넘기")
	var near: Array = game.actions._near_things(p).map(func(r) -> String: return r["label"])
	assert_has(near, "유리 치우기", "the button by the window says what it does")
	assert_false(game.actions.can_vault_window(p, c), "walking into the glass: stopped and asked")
	assert_true(game.actions.glass_asked.has(c))
	assert_false(game.actions.can_vault_window(p, c), "held while the choice is up")
	p.running = true
	assert_true(game.actions.can_vault_window(p, c), "running goes straight in")
	p.running = false
	for q in game.squad:
		if q != p:
			q.position = p.position
			assert_true(game.actions.can_vault_window(q, c), "a companion is not stopped")
			break
	game.actions._clear_glass(c)
	assert_false(game.grid.windows[c]["glass"])
	game.actions.glass_asked.clear()
	assert_true(game.actions.can_vault_window(p, c), "a clean frame lets the player through")
	near = game.actions._near_things(p).map(func(r) -> String: return r["label"])
	assert_has(near, "넘어가기")
