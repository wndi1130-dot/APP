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
