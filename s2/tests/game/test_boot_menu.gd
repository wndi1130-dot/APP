extends "res://addons/gut/test.gd"
## The start menu keeps one layer however many settings are picked.

const Boot = preload("res://game/boot.gd")
const FieldHoldout = preload("res://game/field_holdout.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")


# The menu runs at the field's cap, 60 unless picked; the pick holds on the menu and after a restart.
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

