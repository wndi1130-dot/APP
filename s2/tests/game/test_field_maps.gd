extends "res://addons/gut/test.gd"
## The field asks for a place and gets its map (user 2026-10-11: several maps
## a kind). With nothing asked it is the stop it always was.

const FieldGame = preload("res://game/field_game.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const SulehufMap = preload("res://game/world/sulehuf_map.gd")
const MapView = preload("res://game/world/map_view.gd")
const TinyMap = preload("res://tests/game/fixtures/tiny_map.gd")


func _game(opts: Dictionary):
	var game = FieldGame.new()
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	return game


func test_the_default_place_is_the_old_stop_with_every_key_it_had() -> void:
	var old: Dictionary = SulehufMap.build()
	var now: Dictionary = FieldMaps.build(FieldMaps.DEFAULT_PLACE)
	for key in old:
		assert_true(now.has(key), "still there: " + key)
	assert_eq(now["grid"].width, old["grid"].width)
	assert_eq(now["grid"].height, old["grid"].height)
	assert_eq(now["train"], old["train"])
	assert_eq(now["entries"], old["entries"])
	assert_eq(now["place_id"], SulehufMap.PLACE_ID)
	assert_eq(now["place_kind"], "freight")


func test_keys_a_map_leaves_out_read_as_empty() -> void:
	var now: Dictionary = FieldMaps.build(FieldMaps.DEFAULT_PLACE)
	for key in ["bands", "crossings", "barricade_slots", "interior_kind_slots"]:
		assert_true(now[key].is_empty(), key)
	# The old stop has doors on the platform side only.
	assert_eq(now["train_doors"], {"lower": SulehufMap.build()["spawns"]["train_door"]})
	var tiny: Dictionary = FieldMaps.build_from(TinyMap)
	assert_eq(tiny["place_id"], "mine_99", "read from the map's PLACE_ID")
	assert_eq(tiny["place_kind"], "mine", "what the map says is kept")
	assert_eq(tiny["bands"], {"upper": Rect2i(0, 0, 8, 1)})
	assert_eq(tiny["manholes"], {}, "no sewer on this one")
	assert_eq(tiny["entry_levels"], {})
	assert_eq(tiny["train_doors"], {"lower": [Vector2i(4, 2)]})


func test_an_unknown_place_is_the_default_and_never_a_path() -> void:
	assert_eq(FieldMaps.resolve(""), FieldMaps.DEFAULT_PLACE)
	assert_eq(FieldMaps.resolve("mine_01x"), FieldMaps.DEFAULT_PLACE)
	assert_eq(FieldMaps.resolve("../sim/receipt"), FieldMaps.DEFAULT_PLACE)
	assert_eq(FieldMaps.resolve("sulehuf_map"), FieldMaps.DEFAULT_PLACE)
	assert_false(FieldMaps.has("castle_01"), "not a kind")
	assert_eq(FieldMaps.path_of("mine_03"), "res://game/world/maps/mine_03.gd")
	assert_has(FieldMaps.ids(), FieldMaps.DEFAULT_PLACE)
	for id in FieldMaps.ids():
		assert_true(FieldMaps.has(id))


func test_floors_are_one_height_everywhere() -> void:
	assert_eq(FieldMaps.LEVEL_H, SulehufMap.LEVEL_H)
	assert_eq(FieldMaps.LEVEL_H, MapView.LEVEL_H)


func test_the_field_plays_the_place_asked_for_and_writes_it_down() -> void:
	var game = _game({"seed": 3, "raiders": false, "auto_pause": false})
	assert_eq(game.place, FieldMaps.DEFAULT_PLACE)
	assert_eq(game.data["place_id"], SulehufMap.PLACE_ID)
	assert_eq(game.receipt.to_dict()["place"]["id"], SulehufMap.PLACE_ID)
	assert_eq(game.receipt.to_dict()["place"]["type"], "freight")
	assert_almost_eq(game.lift(Vector2i(5, 5), 1).y, FieldMaps.LEVEL_H, 0.001)
	var other = _game({"seed": 3, "raiders": false, "auto_pause": false, "place": "no_such_place"})
	assert_eq(other.place, FieldMaps.DEFAULT_PLACE, "falls back, the stop still starts")


func test_a_new_map_can_be_handed_over_in_the_same_stop() -> void:
	var game = _game({"seed": 3, "raiders": false, "auto_pause": false})
	var first: Dictionary = game.data
	var t: float = game.clock.elapsed
	game._take_map(FieldMaps.build_from(TinyMap))
	assert_eq(game.grid.width, 8)
	assert_eq(game.levels.size(), 1)
	assert_eq(game.seen_memory.size(), 8 * 6 * 4)
	assert_eq(game.clock.elapsed, t, "the clock is the stop's, not the map's")
	game._take_map(first)
	assert_eq(game.grid.width, SulehufMap.WIDTH, "and back: the first map is as it was left")
