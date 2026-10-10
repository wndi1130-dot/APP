extends "res://addons/gut/test.gd"
## The field feeds the fx shader globals from its weather at stop start, and
## the start menu opens the shader gallery. RenderingServer cannot read a
## global back at runtime (editor-only), so the stop keeps what it wrote.

const FieldGame = preload("res://game/field_game.gd")
const FxState = preload("res://fx/fx_state.gd")
const Boot = preload("res://game/boot.gd")
const MapView = preload("res://game/world/map_view.gd")


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


func test_floors_under_a_roof_are_kept_from_snow_and_wet() -> void:
	var game = _stop(["snow"])
	var g = game.grid
	var indoor := Vector2i(-1, -1)
	var outdoor := Vector2i(-1, -1)
	for y in range(g.height):
		for x in range(g.width):
			var c := Vector2i(x, y)
			if indoor.x < 0 and g.indoor(c):
				indoor = c
			elif outdoor.x < 0 and not g.indoor(c):
				outdoor = c
	assert_true(indoor.x >= 0 and outdoor.x >= 0, "the map has both")
	assert_eq(MapView.sky_alpha(g, indoor), 0.0)
	assert_eq(MapView.sky_alpha(g, outdoor), 1.0)


func test_light_and_backdrop_come_from_fx_state() -> void:
	var game = _stop(["fog", "snow"])
	var light: Dictionary = FxState.lighting_for(["fog", "snow"], 10.5)
	assert_eq(String(light["band"]), "day", "10:30 arrival")
	assert_eq(game.sun.light_color, light["sun_color"])
	assert_almost_eq(game.sun.light_energy, float(light["sun_energy"]), 0.0001)
	assert_eq(game.environment.ambient_light_color, light["ambient_color"])
	assert_almost_eq(game.environment.ambient_light_energy, float(light["ambient_energy"]), 0.0001)
	# The void around the map is the weather tint, darkened: grey, never sky blue.
	var back: Color = game.environment.background_color
	assert_lt(back.v, Color(game.fx_params["fx_tint"]).v)
	assert_false(back.b > back.r and back.s > 0.15, "no sky blue")


func test_a_blizzard_is_dimmer_than_a_clear_day() -> void:
	var clear = _stop(["clear"])
	var storm = _stop(["blizzard"])
	assert_lt(storm.sun.light_energy, clear.sun.light_energy)
	assert_lt(storm.environment.ambient_light_energy, clear.environment.ambient_light_energy)


func test_dusk_dims_the_arrival_light_down_to_the_night_band() -> void:
	var game = _stop(["clear"])
	var day: float = game.sun.light_energy
	var night: Dictionary = FxState.lighting_for(["clear"], 0.0)
	# 15:45 is halfway between 15:00 and 16:30.
	game.clock.elapsed = (945.0 - 630.0) * 60.0 / 15.0
	game._update_light()
	assert_lt(game.sun.light_energy, day)
	assert_gt(game.sun.light_energy, game.NIGHT_SUN_MIN)
	game.clock.elapsed = 1800.0
	game._update_light()
	# No lamps in the gray box yet: night never goes under the field's floors.
	assert_almost_eq(game.sun.light_energy, maxf(float(night["sun_energy"]), game.NIGHT_SUN_MIN), 0.0001)
	assert_almost_eq(game.environment.ambient_light_energy, maxf(float(night["ambient_energy"]), game.NIGHT_AMBIENT_MIN), 0.0001)
	assert_gte(game.environment.ambient_light_energy, 0.2, "night stays readable")


func test_pause_fades_the_world_and_resume_brings_it_back() -> void:
	var game = _stop(["fog", "snow"])
	assert_eq(float(game.fx_params["fx_fade"]), 0.0)
	game.paused = true
	game._update_fade(game.FADE_TIME * 0.5)
	assert_almost_eq(float(game.fx_params["fx_fade"]), 0.5, 0.0001, "the fade eases in")
	game._update_fade(1.0)
	assert_eq(float(game.fx_params["fx_fade"]), 1.0)
	game.paused = false
	game._update_fade(1.0)
	assert_eq(float(game.fx_params["fx_fade"]), 0.0)
	# The end screen is not a pause.
	game.paused = true
	game.ended = true
	game._update_fade(1.0)
	assert_eq(float(game.fx_params["fx_fade"]), 0.0)


func test_snowfall_is_drawn_by_the_fx_precip_shader() -> void:
	var game = _stop(["fog", "snow"])
	assert_true(game.snow.emitting)
	var flake: Mesh = game.snow.draw_pass_1
	assert_true(flake is QuadMesh)
	var mat: ShaderMaterial = flake.material
	assert_eq(mat.shader.resource_path, "res://fx/shaders/precip.gdshader")
	assert_eq(int(mat.get_shader_parameter("shape")), 1, "round flakes, not rain streaks")
	assert_false(_stop(["clear"]).snow.emitting)


func test_world_shader_reads_frost_and_fade_and_no_screen() -> void:
	var path := "res://game/world/world_vis.gdshader"
	var s: Shader = load(path)
	assert_gt(s.get_shader_uniform_list().size(), 0, "parses")
	var code := FileAccess.get_file_as_string(path)
	for word in ["fx_wet", "fx_snow", "fx_frost", "fx_fade", "COLOR.a"]:
		assert_true(code.contains(word), word)
	assert_false(code.contains("hint_screen_texture"))
	assert_false(code.contains("hint_depth_texture"))
