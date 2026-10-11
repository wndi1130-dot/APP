extends "res://addons/gut/test.gd"
## A stop on a map with only what a map must have: a train on open line, no
## platform, no building, nothing to search (user decision 101, the mine maps).
## The field starts, plays and ends on it.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")


func _game(extra: Dictionary = {}):
	var game = FieldGame.new()
	var opts := {"seed": 4, "auto_pause": false}
	opts.merge(extra, true)
	game.opts = opts
	game.map_script = BareLine
	add_child_autofree(game)
	game.set_process(false)
	return game


func test_the_field_starts_and_runs_on_it() -> void:
	var game = _game()
	assert_eq(game.data["place_id"], "mine_98")
	assert_eq(game.squad.size(), 4)
	var cars: Array = game.data["train_cars"]
	assert_eq(cars.size(), 2, "a train with no cars listed is still drawn: 32 cells, two cars")
	assert_eq(cars[1]["kind"], "engine")
	assert_eq(cars[0]["rect"], Rect2i(14, 14, 16, 3))
	assert_true(game.raiders.is_empty(), "no place for raiders, none come")
	for i in range(50):
		game._step(0.1)
	game._start_horde({"index": 0, "size": 4, "entry": "track_west"})
	for i in range(50):
		game._step(0.1)
	game.audio.tick(0.1)
	game.hud.tick(0.1)
	assert_gt(game.zombies.list.size(), 0, "the horde came in by the map's own way")
	assert_false(game.ended)


func test_people_board_from_either_side_of_the_train() -> void:
	var game = _game()
	var train: Rect2i = game.data["train"]
	game.squad[0].position = FieldGrid.center(Vector2i(30, train.position.y - 2))
	game.squad[1].position = FieldGrid.center(Vector2i(30, train.end.y + 1))
	game.squad[2].position = FieldGrid.center(Vector2i(2, 2))
	game.squad[3].position = FieldGrid.center(Vector2i(31, train.end.y + 1))
	assert_true(game.actions.on_platform(game.squad[0]), "the upper side")
	assert_true(game.actions.on_platform(game.squad[1]), "the lower side")
	assert_false(game.actions.on_platform(game.squad[2]))
	game.depart()
	assert_true(game.ended)
	var r: Dictionary = game.receipt.to_dict()
	assert_eq(r["people"]["leftBehind"], [game.squad[2].pid], "who was not by the train stays")
	assert_eq(r["placeState"]["looted"], 0.0, "nothing to search is nothing searched")
	assert_false(r["placeState"].has("waterTower"), "no tower here to speak of")
	assert_eq(r["place"]["type"], "freight", "the type the contract knows")
	assert_eq(r["placeState"]["placeKind"], "mine", "and beside it what the place really is")


func test_the_train_can_be_held_on_it() -> void:
	var game = _game({"holdout": "start", "holdout_time": 30.0})
	assert_eq(game.holdout.doors.size(), 2, "the lower side's doors")
	for i in range(320):
		if game.ended:
			break
		game._step(0.1)
	assert_true(game.ended, "ready, and gone")
	assert_true(game.receipt.to_dict()["placeState"]["holdout"]["ready"])
