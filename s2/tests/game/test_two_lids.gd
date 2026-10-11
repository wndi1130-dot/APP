extends "res://addons/gut/test.gd"
## A map with more than one manhole (the town maps): each lid can be shut,
## a hole that is not a lid cannot.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const TwoLids = preload("res://tests/game/fixtures/two_lids_map.gd")

var game


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 4, "auto_pause": false}
	game.map_script = TwoLids
	add_child_autofree(game)
	game.set_process(false)


func _labels() -> Array:
	return game.actions.context(game.player).map(func(row: Dictionary) -> String: return row["label"])


func test_each_lid_can_be_shut_and_a_drain_cannot() -> void:
	var p = game.player
	p.add_item("plank", 2)
	for key in ["manhole_01", "manhole_02"]:
		assert_true(game.director.sewer(key), key)
		p.position = FieldGrid.center(game.data["manholes"][key]) + Vector3(1, 0, 0)
		assert_true(_labels().has("맨홀 막기"), key)
		game.actions._lid_blocked(p, key, "plank")
		assert_false(game.director.is_open(key), key)
		assert_false(_labels().has("맨홀 막기"), "a shut lid is not offered again")
	assert_eq(int(p.items.get("plank", 0)), 0)
	p.add_item("plank", 1)
	p.position = FieldGrid.center(game.data["manholes"]["drain"]) + Vector3(1, 0, 0)
	assert_false(_labels().has("맨홀 막기"), "a drain has no lid")
	game.actions.block_lid(p, "drain")
	assert_true(game.director.is_open("drain"))


func test_the_driver_tells_of_any_lid_and_a_horde_comes_up_one() -> void:
	game.lid_tip_told = false
	game.director.next_entry = "drain"
	assert_eq(game.lid_tip(), "")
	game.director.next_entry = "manhole_02"
	assert_string_contains(game.lid_tip(), "판자나 고철")
	game._start_horde({"index": 0, "size": 3, "entry": "manhole_02"})
	for i in range(120):
		game._step(0.1)
	assert_gt(game.zombies.list.size(), 0, "they climb out of the second lid")
	assert_eq(game._free_sewer("manhole_01"), "manhole_02", "another open hole with nobody near")
