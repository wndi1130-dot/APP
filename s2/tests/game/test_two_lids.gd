extends "res://addons/gut/test.gd"
## A map with more than one manhole (the town maps): each lid can be shut,
## a hole that is not a lid cannot.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const TwoLids = preload("res://tests/game/fixtures/two_lids_map.gd")
const MapView = preload("res://game/world/map_view.gd")

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


func test_the_dead_climb_out_of_a_hole_and_the_lid_lies_aside_meanwhile() -> void:
	var key := "manhole_02"
	var at: Vector3 = FieldGrid.center(game.data["manholes"][key])
	game.pending_spawn.append({"entry": key, "pos": at, "t": 0.0, "horde": 0, "target": at + Vector3(0, 0, -8)})
	game.clock.elapsed = 1.0
	game._update_spawns(0.1)
	assert_eq(game.zombies.list.size(), 1)
	var z: Dictionary = game.zombies.list[0]
	assert_eq(z["state"], "climb")
	assert_eq(z["climb_way"], "lid")
	assert_almost_eq(z["pos"].x, at.x, 0.001, "it comes up in the hole, not beside it")
	assert_almost_eq(absf(float(z["angle"])), PI, 0.001, "facing where the horde is going")
	assert_true(game.lid_open.has(key))
	game.zombies.update(1.0)
	game._update_hordes(1.0)
	assert_eq(z["state"], "climb", "still coming up")
	game.zombies.update(1.5)
	game._update_hordes(1.5)
	assert_eq(z["state"], "wander", "out, and on its way")
	assert_false(game.lid_open.has(key), "the lid is back")
	# A drain has no lid to push aside; a lid shut under a horde sends the rest elsewhere.
	game.pending_spawn.append({"entry": "drain", "pos": game.entry_pos("drain"), "t": 0.0, "horde": 0, "target": at})
	game._update_spawns(0.1)
	assert_eq(game.zombies.list[1]["state"], "climb")
	assert_false(game.lid_open.has("drain"))
	game.director.block(key)
	assert_eq(game._other_way(key), "manhole_01", "no culvert here: another open hole")


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


# Decision 422 M9: as a body starts up out of a lid, the lid is lifted from
# under, dragged aside and dropped over a moment, and the player hears iron
# (no rule hears it). A lid blocked under a horde only jolts and holds.
func test_a_lid_is_pushed_aside_as_the_body_comes_up_and_a_blocked_one_holds() -> void:
	var key := "manhole_02"
	var at: Vector3 = FieldGrid.center(game.data["manholes"][key])
	var view = game.view
	game.pending_spawn.append({"entry": key, "pos": at, "t": 0.0, "horde": 0, "target": at + Vector3(0, 0, -8)})
	game.clock.elapsed = 1.0
	game._update_spawns(0.1)
	assert_true(game.audio.played.has("lid_scrape"), "the lid is heard")
	var lid: Node3D = view.lid_nodes[key]
	assert_eq(lid.transform, Transform3D.IDENTITY, "it starts on the hole")
	view.advance_lids(MapView.LID_LIFT_END)
	assert_almost_eq(lid.position.y, MapView.LID_LIFT, 0.001, "lifted from under")
	view.advance_lids(MapView.LID_OPEN_TIME)
	assert_eq(lid.position, MapView.LID_ASIDE, "and lies aside where an open lid lay")
	assert_false(view.lid_anim.has(key))
	view.update_manhole(key, false)
	assert_eq(lid.transform, Transform3D.IDENTITY, "shut again at once, as before")
	game.director.block(key)
	view.update_manhole(key, true)
	game.pending_spawn.append({"entry": key, "pos": at, "t": 5.0, "horde": 1, "target": at})
	game._update_spawns(0.1)
	assert_ne(String(game.pending_spawn[-1]["entry"]), key, "the rest go another way, as before")
	assert_eq(view.lid_anim[key]["kind"], "jolt")
	view.advance_lids(MapView.LID_JOLT_TIME * 0.25)
	assert_gt(lid.position.y, 0.0, "it jolts under the planks")
	view.advance_lids(MapView.LID_JOLT_TIME)
	assert_eq(lid.transform, Transform3D.IDENTITY, "and holds")


func test_an_opening_lid_never_sinks_into_the_ground() -> void:
	var lowest := 1.0
	for i in range(41):
		var pose: Transform3D = MapView.lid_open_pose(MapView.LID_OPEN_TIME * float(i) / 40.0)
		for corner in [Vector3(0.55, 0, 0.55), Vector3(0.55, 0, -0.55), Vector3(-0.55, 0, 0.55), Vector3(-0.55, 0, -0.55)]:
			lowest = minf(lowest, (pose * corner).y)
	assert_gt(lowest, -0.01, "the bottom of the lid, metres")
