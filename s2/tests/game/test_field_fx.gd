extends "res://addons/gut/test.gd"
## The field feeds the fx shader globals from its weather at stop start, and
## the start menu opens the shader gallery. RenderingServer cannot read a
## global back at runtime (editor-only), so the stop keeps what it wrote.

const FieldGame = preload("res://game/field_game.gd")
const FxState = preload("res://fx/fx_state.gd")
const Boot = preload("res://game/boot.gd")


func _stop(weather: Array) -> Node:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "weather": weather}
	add_child_autofree(game)
	game.set_process(false)
	return game


func test_menu_has_a_gallery_button_and_the_scene_exists() -> void:
	var boot = Boot.new()
	add_child_autofree(boot)
	var button = boot.menu.find_child("GalleryButton", true, false)
	assert_not_null(button, "gallery button")
	assert_eq(button.text, "셰이더 보기")
	assert_true(ResourceLoader.exists(Boot.GALLERY_SCENE), Boot.GALLERY_SCENE)


func test_gallery_button_survives_menu_rebuilds() -> void:
	var boot = Boot.new()
	add_child_autofree(boot)
	boot._pick("weather", ["clear"])
	assert_not_null(boot.menu.find_child("GalleryButton", true, false))


func test_snow_stop_writes_snow_and_cold_frost() -> void:
	var game = _stop(["fog", "snow"])
	var p: Dictionary = game.fx_params
	assert_eq(p.size(), FxState.GLOBALS.size())
	assert_gt(float(p["fx_snow"]), 0.5, "snow lies at -14 C")
	assert_almost_eq(float(p["fx_wet"]), 0.25, 0.0001, "fog only dampens")
	assert_gt(float(p["fx_frost"]), 0.5)
	assert_eq(p["fx_wind"], Vector3(game.weather.wind_dir.normalized().x, game.weather.wind_dir.normalized().y, game.weather.wind))


func test_clear_stop_is_dry_with_less_snow_than_a_blizzard() -> void:
	var clear: Dictionary = _stop(["clear"]).fx_params
	var storm: Dictionary = _stop(["blizzard"]).fx_params
	assert_almost_eq(float(clear["fx_wet"]), 0.0, 0.0001)
	assert_lt(float(clear["fx_snow"]), float(storm["fx_snow"]))
	assert_gte(float(storm["fx_snow"]), 0.9)


func test_hour_is_the_arrival_hour() -> void:
	# 10:30 arrival is the day band, brighter than the night wash.
	var game = _stop(["clear"])
	var night: Dictionary = FxState.params_for(["clear"], game.weather.ambient_c, game.weather.wind_dir, game.weather.wind, 23.0)
	assert_gt(Color(game.fx_params["fx_tint"]).v, Color(night["fx_tint"]).v)
