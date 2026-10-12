extends "res://addons/gut/test.gd"
## A train that stopped on open line is seen coming to its stand (user
## decisions 200, 204): it rolls in slowing, the brakes cry, and a touch
## brings it straight to where it stands. Stops at a place open as they did.

const FieldGame = preload("res://game/field_game.gd")
const TinyMap = preload("res://tests/game/fixtures/tiny_map.gd")


func _game(extra: Dictionary = {}):
	var game = FieldGame.new()
	var opts := {"seed": 5, "raiders": false, "auto_pause": false, "place": "bare_line_01"}
	opts.merge(extra, true)
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	return game


func test_the_train_rolls_in_and_the_brakes_cry_before_it_stands() -> void:
	var game = _game()
	assert_eq(game.arrive_t, 0.0)
	assert_gt(game.arrive_far(), 30.0, "from off the screen")
	assert_almost_eq(absf(game.view.train_node.position.x), game.arrive_far(), 0.001)
	assert_eq(game.view.light_nodes["car_window"].position.x, game.view.train_node.position.x, "its windows with it")
	assert_false(game.hud.visible)
	var clock: float = game.clock.elapsed
	var last: float = game.arrive_far()
	var t := 0.0
	while t < FieldGame.ARRIVE_ROLL_S - FieldGame.ARRIVE_BRAKE_S - 0.2:
		game._process(0.1)
		t += 0.1
		var at: float = absf(game.view.train_node.position.x)
		assert_lt(at, last, "nearer every moment")
		last = at
	assert_false(game.audio.played.has("train_brake"), "not yet")
	for p in game.people:
		assert_false(p.visible, "nobody stands where the train is not")
	while t < FieldGame.ARRIVE_ROLL_S + 0.05:
		game._process(0.1)
		t += 0.1
	assert_eq(game.audio.played.count("train_brake"), 1, "once")
	assert_true(game.audio.has("train_brake"), "the file is in")
	assert_almost_eq(game.view.train_node.position.x, 0.0, 0.001)
	assert_eq(game.clock.elapsed, clock, "the clock waits for it")
	assert_gte(game.arrive_t, 0.0, "a quiet moment yet")
	while t < FieldGame.ARRIVE_ROLL_S + FieldGame.ARRIVE_HUSH_S + 0.15:
		game._process(0.1)
		t += 0.1
	assert_eq(game.arrive_t, -1.0)
	assert_true(game.hud.visible)
	assert_gt(game.clock.elapsed, clock, "and the stop runs")


func test_a_touch_brings_it_straight_to_its_stand() -> void:
	var game = _game()
	game._process(0.1)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	game.hud._input(touch)
	assert_eq(game.arrive_t, -1.0)
	assert_eq(game.view.train_node.position.x, 0.0)
	assert_true(game.hud.visible)
	assert_false(game.audio.played.has("train_brake"), "skipped: no cry after it stands")
	game._process(0.1)
	assert_true(game.player.visible)


func test_a_stop_at_a_place_opens_as_it_did() -> void:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	game.map_script = TinyMap
	add_child_autofree(game)
	game.set_process(false)
	assert_eq(game.arrive_t, -1.0)
	assert_true(game.hud.visible)
	assert_eq(game.view.train_node.position.x, 0.0)
	assert_eq(_game({"place": "summit_01"}).arrive_t, -1.0, "a pass is a place")
