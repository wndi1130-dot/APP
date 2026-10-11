extends "res://addons/gut/test.gd"
## Holding the train while it gets ready to leave (user decisions 056, 074,
## 075): the first shape, on the stop there is. A plain stop knows nothing of it.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldHoldout = preload("res://game/field_holdout.gd")
const HordeDirector = preload("res://game/sim/horde_director.gd")


func _game(extra: Dictionary = {}):
	var game = FieldGame.new()
	var opts := {"seed": 5, "raiders": false, "auto_pause": false}
	opts.merge(extra, true)
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	return game


func _dead_at(game, door: Dictionary) -> Dictionary:
	return game.zombies.spawn("dead", FieldGrid.center(door["cell"]))


func test_a_plain_stop_is_as_it_was() -> void:
	var game = _game()
	assert_false(game.holdout.enabled())
	assert_false(game.holdout.on)
	assert_eq(game.goal_text(), "")
	assert_eq(game.horde_target(), FieldGrid.center(game.horde_home()))
	assert_eq(game.director.first_interval, HordeDirector.FIRST_INTERVAL)
	assert_eq(game.director.next_arrival, HordeDirector.FIRST_INTERVAL)
	assert_true(game.holdout.wall_row(game.player).is_empty())
	game.holdout.tick(1.0)
	game.depart()
	assert_true(game.ended, "leaving leaves")
	assert_false(game.receipt.to_dict()["placeState"].has("holdout"))
	assert_false(game.telemetry.to_dict().has("holdout"))


func test_it_opens_with_a_clock_three_doors_and_its_own_pace() -> void:
	var game = _game({"holdout": "start"})
	var h = game.holdout
	assert_true(h.on)
	assert_eq(h.left, FieldHoldout.READY_TIME)
	assert_eq(h.doors.size(), 3, "the platform side's doors")
	assert_eq(h.count("whole"), 3)
	assert_eq(game.director.next_arrival, FieldHoldout.FIRST_GAP, "the first horde comes at the stage's pace")
	assert_string_contains(game.goal_text(), "채비 5:00")
	# Five minutes of the stage's pace, with nothing pulling them in: more than the stop's one.
	var n := 0
	var t := 0.0
	while t < FieldHoldout.READY_TIME:
		t += 1.0
		if not game.director.update(t).is_empty():
			n += 1
	assert_between(n, 5, 8, "waves in five quiet minutes")


func test_a_horde_walks_to_the_doors_each_body_to_one() -> void:
	var game = _game({"holdout": "start"})
	game._start_horde({"index": 0, "size": 6, "entry": "south_road"})
	var seen: Dictionary = {}
	for row in game.pending_spawn:
		seen[row["target"]] = true
	assert_eq(seen.size(), 3)
	for door in game.holdout.doors:
		assert_true(seen.has(FieldGrid.center(door["cell"])))


func test_the_dead_at_a_door_wear_it_down_and_a_wall_takes_it_first() -> void:
	var game = _game({"holdout": "start"})
	var h = game.holdout
	var door: Dictionary = h.doors[0]
	h.tick(5.0)
	assert_eq(int(door["hp"]), FieldHoldout.DOOR_HP, "nobody at it")
	_dead_at(game, door)
	h.tick(FieldHoldout.BANG_EVERY)
	assert_eq(int(door["hp"]), FieldHoldout.DOOR_HP - 1)
	_dead_at(game, door)
	_dead_at(game, door)
	h.tick(FieldHoldout.BANG_EVERY)
	assert_eq(int(door["hp"]), FieldHoldout.DOOR_HP - 4, "three of them, three blows")
	game.player.add_item("plank", 1)
	game.player.position = FieldGrid.center(door["cell"])
	assert_eq(h.wall_row(game.player)["label"], "방벽 세우기")
	h._built(game.player, 0, "plank")
	assert_eq(int(door["wall"]), FieldHoldout.WALL_HP)
	assert_eq(int(game.player.items.get("plank", 0)), 0, "it costs the one thing")
	assert_true(h.wall_row(game.player).is_empty(), "one wall a door")
	h.tick(FieldHoldout.BANG_EVERY)
	assert_eq(int(door["hp"]), FieldHoldout.DOOR_HP - 4, "the wall is hit, not the door")
	assert_eq(int(door["wall"]), FieldHoldout.WALL_HP - 3)
	assert_eq(int(h.doors[1]["hp"]), FieldHoldout.DOOR_HP, "the other doors are not this one")


func test_no_wall_without_something_to_build_it_of() -> void:
	var game = _game({"holdout": "start"})
	for m in FieldHoldout.MATERIALS:
		game.player.items.erase(m)
	game.holdout.build(game.player, 0)
	assert_ne(game.player.action, "wall")
	game.player.add_item("scrap", 1)
	game.holdout.build(game.player, 0)
	assert_eq(game.player.action, "wall")
	assert_eq(game.player.action_t, FieldHoldout.BUILD_TIME)


func test_a_door_is_whole_then_damaged_then_breached() -> void:
	var game = _game({"holdout": "start", "holdout_door_hp": 6})
	var h = game.holdout
	var door: Dictionary = h.doors[1]
	_dead_at(game, door)
	assert_eq(h.state_of(door), "whole")
	h.tick(FieldHoldout.BANG_EVERY * 4)
	assert_eq(h.state_of(door), "damaged", "under half")
	h.tick(FieldHoldout.BANG_EVERY * 2)
	assert_eq(h.state_of(door), "breached")
	assert_false(game.ended, "a breached door is not the end of it")
	h.tick(FieldHoldout.BANG_EVERY * 3)
	var r: Dictionary = h.result()
	assert_eq(r["doors"], ["whole", "breached", "whole"])
	assert_eq(int(r["breached"]), 1)
	assert_eq(int(r["entered"]), 1, "each of the dead that goes in by a breached door is counted once")


func test_the_train_leaves_when_it_is_ready_and_says_what_it_cost() -> void:
	var game = _game({"holdout": "start", "holdout_time": 20.0})
	var h = game.holdout
	h.tick(19.0)
	assert_false(game.ended)
	h.tick(1.5)
	assert_true(game.ended)
	var note: Dictionary = game.receipt.to_dict()["placeState"]["holdout"]
	assert_true(note["ready"])
	assert_false(note["early"])
	assert_eq(game.receipt.to_dict()["endReason"], "departed", "the receipt's reasons are the contract's")
	assert_true(game.telemetry.to_dict()["holdout"]["ready"])


func test_called_on_leaving_it_opens_first_and_leaving_again_goes_early() -> void:
	var game = _game({"holdout": "depart"})
	var h = game.holdout
	assert_false(h.on, "a stop like any other until leaving is called")
	assert_eq(game.director.first_interval, HordeDirector.FIRST_INTERVAL)
	game.depart()
	assert_false(game.ended, "the train is not ready")
	assert_true(h.on)
	h.tick(30.0)
	game.depart()
	assert_true(game.ended)
	var note: Dictionary = game.receipt.to_dict()["placeState"]["holdout"]
	assert_false(note["ready"])
	assert_true(note["early"])
	assert_eq(int(note["leftSec"]), 270)


func test_a_map_with_doors_on_the_upper_side_only_or_none_still_holds() -> void:
	var game = _game({"holdout": "depart"})
	game.data["train_doors"] = {"upper": [Vector2i(40, 0), Vector2i(60, 0)]}
	game.depart()
	assert_eq(game.holdout.doors.size(), 2, "the upper side's")
	assert_eq(game.holdout.target(3), FieldGrid.center(Vector2i(60, 0)))
	var bare = _game({"holdout": "depart"})
	bare.data["train_doors"] = {}
	bare.depart()
	assert_true(bare.holdout.on, "the clock still runs")
	assert_eq(bare.holdout.target(0), FieldGrid.center(bare.horde_home()), "no door to walk to: where a horde always went")
	bare.holdout.tick(1.0)
	assert_string_contains(bare.goal_text(), "문 멀쩡 0")


func test_the_stops_time_limit_waits_for_a_held_train() -> void:
	var game = _game({"holdout": "start"})
	game.clock.elapsed = game.clock.LIMIT_SEC + 1.0
	game._check_end()
	assert_false(game.ended, "the train's own clock is the limit now")
