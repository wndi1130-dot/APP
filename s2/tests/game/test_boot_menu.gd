extends "res://addons/gut/test.gd"
## The start menu keeps one layer however many settings are picked.

const Boot = preload("res://game/boot.gd")


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

