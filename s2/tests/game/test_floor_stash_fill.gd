extends "res://addons/gut/test.gd"
## What is under a loose board (floor_stash.gd, card K): small things someone hid,
## one always and a second now and then, on dice of its own.

const FloorStash = preload("res://game/sim/floor_stash.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const Carry = preload("res://game/sim/carry.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const RoomStories = preload("res://game/world/room_stories.gd")
const FieldGame = preload("res://game/field_game.gd")


func test_the_table_is_small_things_and_the_values_in_the_pr() -> void:
	assert_eq(FloorStash.TABLE, [[3, "pocket_watch", 1], [3, "wrist_watch", 1], [2, "cigarettes", 1], [2, "ammo_pistol", 2], [1, "junk_smokes", 1]])
	assert_eq(FloorStash.SECOND_CHANCE, 0.5)
	for row: Array in FloorStash.TABLE:
		var id := String(row[1])
		assert_gt(Carry.item_weight(id), 0.0, "a thing the field knows: " + id)
		assert_lte(Carry.item_weight(id) * int(row[2]), 0.5, "small: " + id)
		assert_ne(FieldItems.group(id), "rare", "apart from the named finds: " + id)


## houses_01 with its floor stash laid (the first story seed that gives one).
func _stash_map() -> Dictionary:
	for s in range(1, 60):
		var data := FieldMaps.build("houses_01")
		RoomStories.apply(data, s)
		if not data.get("floor_stashes", []).is_empty():
			return data
	return {}


func test_the_box_under_the_board_gets_one_or_two_small_finds() -> void:
	var data := _stash_map()
	assert_false(data.is_empty(), "a map with a loose board")
	var id := String(data["floor_stashes"][0]["id"])
	var ids := {}
	for row: Array in FloorStash.TABLE:
		ids[String(row[1])] = true
	var counts := {}
	for seed in range(1, 201):
		data["containers"][id]["items"] = []
		var out := FloorStash.fill(data, seed)
		var items: Array = data["containers"][id]["items"]
		assert_between(out.size(), 1, 2, "one find, a second now and then")
		assert_between(items.size(), 1, 4)
		for item in items:
			assert_true(ids.has(String(item)), String(item))
		counts[out.size()] = int(counts.get(out.size(), 0)) + 1
	assert_between(int(counts.get(2, 0)), 70, 130, "about half have a second (200 runs)")


func test_the_same_run_hides_the_same_and_a_filled_box_is_left_as_it_is() -> void:
	var data := _stash_map()
	var id := String(data["floor_stashes"][0]["id"])
	FloorStash.fill(data, 9)
	var once: Array = (data["containers"][id]["items"] as Array).duplicate()
	data["containers"][id]["items"] = []
	FloorStash.fill(data, 9)
	assert_eq(data["containers"][id]["items"], once)
	# A resumed stop: what its save says stays.
	data["containers"][id]["items"] = ["junk_paper"]
	assert_eq(FloorStash.fill(data, 9), [])
	assert_eq(data["containers"][id]["items"], ["junk_paper"])


func test_a_stop_with_no_loose_board_is_left_as_it_is() -> void:
	var data := FieldMaps.build("houses_01")
	var before := str(data["containers"])
	assert_eq(FloorStash.fill(data, 3), [])
	assert_eq(str(data["containers"]), before)


func test_a_field_fills_its_loose_board_as_it_opens() -> void:
	var filled := false
	for seed in range(1, 16):
		var game = FieldGame.new()
		game.opts = {"seed": seed, "auto_pause": false, "raiders": false, "place": "houses_01"}
		add_child(game)
		game.set_process(false)
		for s: Dictionary in game.data.get("floor_stashes", []):
			assert_false((game.data["containers"][s["id"]]["items"] as Array).is_empty(), "seed %d: filled" % seed)
			filled = true
		remove_child(game)
		game.free()
		if filled:
			break
	assert_true(filled, "a run of houses_01 with a loose board")
