extends "res://addons/gut/test.gd"
## The field asks for a place and gets its map (user 2026-10-11: several maps
## a kind). With nothing asked it is the stop it always was.

const FieldGame = preload("res://game/field_game.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const SulehufMap = preload("res://game/world/sulehuf_map.gd")
const MapView = preload("res://game/world/map_view.gd")
const TinyMap = preload("res://tests/game/fixtures/tiny_map.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")


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


func test_a_place_the_receipt_does_not_know_is_written_beside_its_type() -> void:
	var game = _game({"seed": 3, "raiders": false, "auto_pause": false})
	assert_false(game.receipt.to_dict()["place"].has("placeKind"), "the old stop's receipt is as it was")
	var Receipt = preload("res://game/sim/receipt.gd")
	assert_false(Receipt.PLACE_TYPES.has("mine"), "when the contract learns it, this note goes")


func test_the_train_has_doors_drawn_on_each_side_the_map_gives() -> void:
	var old: Dictionary = SulehufMap.build()
	var faces: Array = MapView.door_faces(old)
	assert_eq(faces.size(), old["spawns"]["train_door"].size())
	var train: Rect2i = old["train"]
	for face in faces:
		assert_almost_eq(float(face["z"]), train.position.y + train.size.y - 0.05, 0.001, "the platform side")
	var both := {"train": Rect2i(10, 20, 80, 3), "train_doors": {"upper": [Vector2i(30, 19), Vector2i(60, 19)], "lower": [Vector2i(40, 23)]}}
	faces = MapView.door_faces(both)
	assert_eq(faces.size(), 3)
	assert_almost_eq(float(faces[0]["z"]), 20.05, 0.001, "the upper side is the train's north face")
	assert_almost_eq(float(faces[2]["z"]), 22.95, 0.001)


func test_the_first_stop_steers_by_the_cells_it_always_did() -> void:
	var game = _game({"seed": 3, "raiders": false, "auto_pause": false})
	assert_eq(game.horde_home(), Vector2i(50, 10), "the platform by the train")
	assert_eq(game.data["anchors"]["whistle"], Vector2i(90, 4))
	assert_eq(game.data["anchors"]["flee_exit"], Vector2i(60, 99))
	assert_eq(game.data["anchors"]["engine"], Vector2i(92, 2), "where the engine idles")
	assert_eq(game.data["platform"], Rect2i(16, 4, 82, 6), "its own platform, not one worked out")
	assert_eq(game.road_entries(), ["east_track", "north_road", "south_road", "east_road"], "the fair spawn tries them in this order")
	assert_eq(game.combat._where(FieldGrid.center(Vector2i(50, 8))), "platform")
	assert_eq(game.data["zone_names"][""], "sulechow", "anywhere unnamed")
	assert_ne(FieldMaps.anchors(game.data)["horde_home"], Vector2i(50, 10), "the map's own cell is kept over the worked-out one")


func test_a_map_that_names_no_cells_has_them_worked_out() -> void:
	var tiny: Dictionary = FieldMaps.build_from(TinyMap)
	var a: Dictionary = tiny["anchors"]
	assert_eq(a["horde_home"], Vector2i(4, 2), "the train's door")
	assert_eq(a["whistle"], Vector2i(1, 2), "the engine end, kept on the map")
	assert_eq(a["flee_exit"], Vector2i(0, 5), "the far edge from the train")
	assert_eq(tiny["zone_names"], {})


func test_every_group_of_the_dead_a_map_lists_is_put_out() -> void:
	var game = _game({"seed": 3, "raiders": false, "auto_pause": false})
	game._take_map(FieldMaps.build_from(TinyMap))
	game.zombies.list.clear()
	game._spawn_dead()
	assert_eq(game.zombies.list.size(), 2, "dead_yard's two, and no list this map leaves out is asked for")
	assert_eq(game.combat._where(FieldGrid.center(Vector2i(2, 2))), "mine_99", "no zone names: the place itself")


func test_blocked_ground_out_of_doors_is_drawn_as_runs() -> void:
	var g = FieldGrid.new(12, 6)
	for x in range(2, 7):
		g.set_solid(Vector2i(x, 1), FieldGrid.Solid.BLOCK)
	g.set_solid(Vector2i(9, 1), FieldGrid.Solid.BLOCK)
	for x in range(0, 12):
		g.set_solid(Vector2i(x, 3), FieldGrid.Solid.BLOCK)   # the train
	g.set_solid(Vector2i(4, 5), FieldGrid.Solid.BLOCK)        # a tree
	g.set_solid(Vector2i(8, 5), FieldGrid.Solid.LOW)          # water: floor only
	var d := {"train": Rect2i(0, 3, 12, 1), "wagons": [], "trees": [Vector2i(4, 5)]}
	assert_eq(MapView.outdoor_block_runs(g, d), [Rect2i(2, 1, 5, 1), Rect2i(9, 1, 1, 1)] as Array[Rect2i])
	# The first stop draws its own (the water tower): nothing of it changes.
	assert_true(SulehufMap.build()["spots"].has("water_tower"))
