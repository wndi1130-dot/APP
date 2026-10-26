extends "res://addons/gut/test.gd"
## PR 5 (decision 426; s3 contract 2): the departure kit comes out of the train's armory and the
## rounds out of its three stocks. The start armory is the field's first squad's kits, so the
## first departure goes out exactly as before; a short armory leaves a hand empty; a train that
## keeps no armory (S1's states) sends the kits as they were. In the field the guns are loaded
## first from the train's rounds and the rest is the pool.

const FieldGame = preload("res://game/field_game.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")
const FieldDeparture = preload("res://game/politics/field_departure.gd")
const KitPick = preload("res://game/politics/kit_pick.gd")
const TrainDom = preload("res://game/train/train_dom.gd")
const V = preload("res://tests/politics/field_vectors.gd")


func _state(with_stores: bool) -> Dictionary:
	var g: Dictionary = (V.data()["contracts"][0]["state"] as Dictionary).duplicate(true)
	if with_stores:
		g["dom"] = TrainDom.start()
	return g


func _hands(departure: Dictionary) -> Array:
	var out: Array = []
	for row: Dictionary in FieldDeparture.people_of(departure):
		out.append([String(row["role"]), row["gear"]["hands"]])
	return out


func test_the_start_stores_are_the_first_kits_and_their_rounds() -> void:
	var d: Dictionary = TrainDom.start()
	assert_true(TrainDom.is_store(d), "still the stores the train rules know")
	assert_eq(int(d["ammo_pistol"]), 16)
	assert_eq(int(d["ammo_shell"]), 5)
	assert_eq(int(d["ammo_craft"]), 9)
	assert_eq((d["armory"] as Array).size(), 11, "eleven weapons")
	# The kits of the field's first squad, one weapon each.
	var kits: Array = []
	for gear: Dictionary in [FieldDeparture.CHIEF_GEAR, FieldDeparture.COMPANION_GEAR["guard"], FieldDeparture.COMPANION_GEAR["medtech"], FieldDeparture.COMPANION_GEAR["tail"]] + FieldDeparture.ESCORT_GEAR:
		for h: Array in gear["hands"]:
			kits.append({"id": h[0], "quality": h[1], "condition": h[2]})
	assert_eq(str(d["armory"]), str(kits))
	TrainDom.start()["armory"].clear()
	assert_eq((TrainDom.start()["armory"] as Array).size(), 11, "a fresh copy each run")


func test_the_first_departure_goes_out_as_before() -> void:
	var before := FieldDeparture.build(_state(false), V.tables(), {"placeId": "sulechow_station"})
	var after := FieldDeparture.build(_state(true), V.tables(), {"placeId": "sulechow_station"})
	assert_eq(str(_hands(after)), str(_hands(before)), "the same hands, out of the armory")
	assert_false((before["train"] as Dictionary).has("ammo"), "no stores, no rounds handed over")
	assert_eq(after["train"]["ammo"], {"pistol": 16, "shell": 5, "craft": 9})
	assert_false((after["train"] as Dictionary).has("lures"), "no lures kept yet")


func test_a_short_armory_leaves_a_hand_empty_and_takes_the_best_left() -> void:
	var g := _state(true)
	var armory: Array = g["dom"]["armory"]
	# The pistol gone and one crowbar lost; the rest as they were.
	for i in range(armory.size() - 1, -1, -1):
		if armory[i]["id"] == "pistol":
			armory.remove_at(i)
	for i in armory.size():
		if armory[i]["id"] == "crowbar" and is_equal_approx(float(armory[i]["condition"]), 0.8):
			armory.remove_at(i)
			break
	var d := FieldDeparture.build(g, V.tables(), {"placeId": "sulechow_station"})
	var chief: Array = d["roster"][0]["gear"]["hands"]
	assert_eq(chief.size(), 1, "the chief goes out with the axe alone")
	assert_eq(String(chief[0][0]), "axe")
	var crowbars := 0
	for row: Dictionary in FieldDeparture.people_of(d):
		for h: Array in row["gear"]["hands"]:
			if h[0] == "crowbar":
				crowbars += 1
	assert_eq(crowbars, 2, "two crowbars left, two hands get one")
	assert_eq((g["dom"]["armory"] as Array).size(), 9, "building the sheet takes nothing out of the stores")


func test_the_train_hands_over_its_lures_when_it_keeps_them() -> void:
	assert_eq(KitPick.train_kit({}), {})
	assert_eq(KitPick.train_kit({"dom": {"wood": 1}}), {}, "S1's stores keep no rounds")
	var g := {"dom": TrainDom.start()}
	g["dom"]["lures"] = 2
	assert_eq(KitPick.train_kit(g), {"ammo": {"pistol": 16, "shell": 5, "craft": 9}, "lures": 2})


func _game(departure: Dictionary):
	var game = FieldGame.new()
	game.opts = {"seed": 4, "auto_pause": false, "raiders": false, "departure": departure}
	game.map_script = BareLine
	add_child_autofree(game)
	game.set_process(false)
	return game


func test_in_the_field_the_guns_are_loaded_first_and_the_rest_is_the_pool() -> void:
	var g := _state(true)
	g["dom"]["ammo_pistol"] = 10
	g["dom"]["ammo_shell"] = 0
	g["dom"]["ammo_craft"] = 3
	var game = _game(FieldDeparture.build(g, V.tables(), {"placeId": "sulechow_station"}))
	var loaded: Dictionary = game.loaded_totals()
	assert_eq(int(loaded["pistol"]) + int(game.ammo["pistol"]), 10, "every round the train gave, no more")
	assert_eq(int(game.ammo["shell"]), 0)
	assert_eq(int(loaded["shell"]), 0, "no shells: the shotgun goes out empty")
	assert_eq(int(loaded["craft"]) + int(game.ammo["craft"]), 3)
	for p in game.squad:
		for h in p.hands:
			if String(h["id"]) == "pistol":
				assert_eq(int(h["loaded"]), 8, "the gun is filled before the pool")


func test_the_first_departure_has_the_rounds_it_had() -> void:
	var game = _game(FieldDeparture.build(_state(true), V.tables(), {"placeId": "sulechow_station"}))
	var plain = _game(FieldDeparture.build(_state(false), V.tables(), {"placeId": "sulechow_station"}))
	for k: String in ["pistol", "shell", "craft"]:
		assert_eq(int(game.ammo[k]) + int(game.loaded_totals()[k]), int(plain.ammo[k]) + int(plain.loaded_totals()[k]), "the same rounds out: " + k)
