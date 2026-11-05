extends "res://addons/gut/test.gd"
## The start menu keeps one layer however many settings are picked.

const Boot = preload("res://game/boot.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldHoldout = preload("res://game/field_holdout.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")


# A phone starts at 30, anything else at 60; the field on a phone keeps the menu's cap, off it the
# field's options as before.
func test_a_phone_starts_capped_at_30_and_its_stops_keep_the_menu_cap() -> void:
	assert_eq(Boot.default_fps_cap(true), 30, "a phone")
	assert_eq(Boot.default_fps_cap(false), 60, "the PC and the tests")
	assert_eq(FieldGame.fps_cap_for(30, {}, true), 30, "a phone stop keeps the menu's 30")
	assert_eq(FieldGame.fps_cap_for(30, {"fps_cap": 60}, true), 30, "an old save's 60 does not lift it")
	assert_eq(FieldGame.fps_cap_for(60, {}, true), 60, "60 picked in the menu holds")
	assert_eq(FieldGame.fps_cap_for(0, {}, true), 60, "a field with no cap set yet")
	assert_eq(FieldGame.fps_cap_for(30, {}, false), 60, "off the phone the field's own 60, as before")
	assert_eq(FieldGame.fps_cap_for(60, {"fps_cap": 0}, false), 0, "and its options' cap, as before")


# The menu runs at the field's cap, 60 on the PC unless picked; the pick holds on the menu and after a restart.
func test_the_fps_cap_picked_holds_over_the_default() -> void:
	var was: int = Engine.max_fps
	var boot = Boot.new()
	add_child_autofree(boot)
	assert_eq(Engine.max_fps, 60, "the menu runs capped")
	boot._pick("fps_cap", 30)
	assert_eq(Engine.max_fps, 30, "the pick wins")
	boot._on_restart()
	assert_eq(Engine.max_fps, 30, "a restart keeps the pick")
	Engine.max_fps = was


func test_picking_settings_does_not_pile_up_menu_layers() -> void:
	var boot = Boot.new()
	add_child_autofree(boot)
	for i in range(5):
		boot._pick("raiders", i % 2 == 0)
	var layers := 0
	for c in boot.get_children():
		if c is CanvasLayer and not c.is_queued_for_deletion():
			layers += 1
	assert_eq(layers, 1)


# The kind of stop is picked last in the list, so the rows above keep their place.
func test_the_kind_of_stop_is_the_last_setting_and_starts_plain() -> void:
	var boot = Boot.new()
	add_child_autofree(boot)
	assert_eq(boot.CHOICES[boot.CHOICES.size() - 1][0], "mission")
	assert_eq(boot.settings["mission"], "")
	assert_eq(boot.settings["lungers"], false, "the lungers are off until picked")
	# The switches for looking at a rare thing start at what the game has.
	assert_eq(boot.settings["holdout_chance"], -1)
	assert_eq(boot.settings["holdout_forecast_heard"], FieldHoldout.FORECAST_HEARD)
	assert_eq(boot.settings["lungers_many"], false)
	assert_eq(boot.settings["place_kind"], "", "and the map is the one it always was")
	assert_eq(boot.place_picked(), "")


# A switch for looking at a map on the phone: a kind and its number.
func test_a_map_can_be_picked_by_kind_and_number() -> void:
	var boot = Boot.new()
	add_child_autofree(boot)
	var kinds: Array = []
	for opt in boot.CHOICES.filter(func(row): return row[0] == "place_kind")[0][2]:
		if opt[0] != "":
			kinds.append(opt[0])
	assert_eq(kinds, Array(FieldMaps.KINDS), "every kind there is")
	boot._pick("place_kind", "summit")
	boot._pick("place_no", 3)
	assert_eq(boot.place_picked(), "summit_03")
	assert_true(FieldMaps.has(boot.place_picked()))
	boot._pick("place_no", 9)
	assert_eq(FieldMaps.resolve(boot.place_picked()), FieldMaps.DEFAULT_PLACE, "no such map: the usual stop")

