extends "res://addons/gut/test.gd"
## The player's brightness (decision 471 B5): a gamma on the dark end of the
## grade, 0 by default, and never picked up by a field the tools make.

const FieldGame = preload("res://game/field_game.gd")

## Where the settings row keeps it (train-3d, like sound.cfg).
const SCREEN_FILE := "user://screen.cfg"


func _stop() -> Node:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "weather": ["clear"]}
	add_child_autofree(game)
	game.set_process(false)
	return game


func _offsets(game) -> PackedFloat32Array:
	return (game.environment.adjustment_color_correction as GradientTexture1D).gradient.offsets


func test_by_default_the_picture_is_as_made() -> void:
	var game = _stop()
	game._update_atmosphere()
	assert_eq(game.screen_lift, 0.0)
	var o := _offsets(game)
	assert_almost_eq(o[1], 0.3, 0.0001)
	assert_almost_eq(o[2], 0.85, 0.0001)


func test_the_brightness_bends_the_dark_end_within_twenty_percent() -> void:
	var game = _stop()
	game._update_atmosphere()
	game.set_screen_lift(0.5)
	assert_eq(game.screen_lift, FieldGame.SCREEN_LIFT_MAX, "held to +20 %")
	var up := _offsets(game)
	assert_lt(up[1], 0.3, "the shadows' stop comes from a darker input: darks lift")
	assert_almost_eq(up[0], 0.0, 0.0001)
	assert_almost_eq(up[3], 1.0, 0.0001)
	game.set_screen_lift(-0.2)
	assert_gt(_offsets(game)[1], 0.3, "and sink the other way")
	game.set_screen_lift(0.0)
	assert_almost_eq(_offsets(game)[1], 0.3, 0.0001)


func test_a_field_the_tools_make_ignores_a_saved_brightness() -> void:
	# A player who saved +20 % must not shift the shots, measures and bots:
	# only the play flow hands the saved value to the field.
	var had := FileAccess.file_exists(SCREEN_FILE)
	var keep := FileAccess.get_file_as_string(SCREEN_FILE) if had else ""
	var cfg := ConfigFile.new()
	cfg.set_value("screen", "lift", 0.2)
	cfg.save(SCREEN_FILE)
	var game = _stop()
	game._update_atmosphere()
	assert_eq(game.screen_lift, 0.0)
	assert_almost_eq(_offsets(game)[1], 0.3, 0.0001)
	if had:
		var f := FileAccess.open(SCREEN_FILE, FileAccess.WRITE)
		f.store_string(keep)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCREEN_FILE))
	for path in ["res://tools/atmosphere_shots.gd", "res://tools/stop_measure.gd", "res://tools/one_motion_runs.gd", "res://game/field_game.gd"]:
		var code := FileAccess.get_file_as_string(path)
		assert_false(code.contains("screen.cfg"), "%s does not read the saved brightness" % path)
	assert_false(FileAccess.get_file_as_string("res://tools/atmosphere_shots.gd").contains("set_screen_lift"))
