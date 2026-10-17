extends "res://addons/gut/test.gd"
## The weather and the film over the slice's train (world_weather.gd,
## world_film.gd): the mockup's layers in its order with its tiles, speeds and
## opacities (k3_views.js world, mockup px × K), the snow on a slant while the
## train runs and falling straight at a stop, the dark edges as the mockup's
## radial gradient, and the slice turning them with its steps.

const WorldWeather = preload("res://game/ui/world_weather.gd")
const WorldFilm = preload("res://game/ui/world_film.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")


func _param(c: CanvasItem, p: String) -> Variant:
	return (c.material as ShaderMaterial).get_shader_parameter(p)


func _weather(still: bool = false):
	var w = WorldWeather.new()
	w.still = still
	add_child_autofree(w)
	return w


func test_the_weather_lays_the_mockups_layers_in_its_order() -> void:
	var w = _weather()
	var names: Array = []
	for c in w.get_children():
		names.append(String(c.name))
	assert_eq(names, ["Drift", "Fog", "SnowFar", "SnowNear"], "drift, fog, snow 2, snow 3: back to front")
	var k: float = UiFonts.K
	assert_almost_eq(w.drift.offset_top, 238.0 * k, 0.01, ".w-drift top 238")
	assert_almost_eq(w.drift.offset_bottom, 328.0 * k, 0.01, "90 high")
	assert_eq(_param(w.drift, "tile_px"), Vector2(844, 90) * k)
	assert_almost_eq(w.fog.offset_top, 214.0 * k, 0.01, ".w-fogB top 214")
	assert_eq(_param(w.fog, "tile_px"), Vector2(1266, 150) * k)
	assert_eq(_param(w.fog, "start_px"), Vector2(-300, 0) * k, "background-position −300px 0")
	assert_almost_eq(float(_param(w.fog, "opacity")), 0.42, 0.001)
	assert_eq(_param(w.far, "tile_px"), Vector2(400, 400) * k)
	assert_almost_eq(float(_param(w.far, "opacity")), 0.8, 0.001)
	assert_almost_eq(float(_param(w.near, "opacity")), 0.6, 0.001)


func test_running_the_snow_streaks_on_a_slant_and_at_a_stop_it_falls() -> void:
	var w = _weather()
	var k: float = UiFonts.K
	assert_true(w.moving, "running unless told")
	assert_true(w.drift.visible)
	assert_eq(_param(w.far, "tex"), WorldWeather.SNOW_RUN_FAR)
	assert_eq(_param(w.near, "tex"), WorldWeather.SNOW_RUN_NEAR)
	var near: Vector2 = _param(w.near, "speed_px")
	assert_almost_eq(near.x, -800.0 / 2.4 * k, 0.01, "snowB: 800 px back in 2.4 s")
	assert_almost_eq(near.y, 400.0 / 2.4 * k, 0.01, "and 400 down")
	assert_almost_eq((_param(w.drift, "speed_px") as Vector2).x, -844.0 / 3.0 * k, 0.01, "the drift blows by in 3 s")
	w.moving = false
	assert_false(w.drift.visible, "at a stop the drift lies under the station")
	assert_eq(_param(w.far, "tex"), WorldWeather.SNOW_STOP_FAR)
	assert_eq(_param(w.near, "tex"), WorldWeather.SNOW_STOP_NEAR)
	var far: Vector2 = _param(w.far, "speed_px")
	assert_almost_eq(far.y, 1600.0 / 27.0 * k, 0.01, "fallA: 1600 px down in 27 s")
	assert_gt(far.y, absf(far.x) * 3.0, "nearly straight down")
	w.moving = true
	assert_eq(_param(w.far, "tex"), WorldWeather.SNOW_RUN_FAR, "and back on the slant when it runs again")
	assert_true(w.drift.visible)


func test_still_holds_every_layer_at_its_start() -> void:
	var w = _weather(true)
	var layers: Array = [w.drift, w.fog, w.far, w.near]
	for c in layers:
		assert_eq(float(_param(c, "still")), 1.0, String(c.name) + " held")
	w.still = false
	for c in layers:
		assert_eq(float(_param(c, "still")), 0.0, String(c.name) + " moving")


func test_each_layer_tiles_by_its_own_size() -> void:
	var w = _weather()
	await wait_frames(1)
	for c in [w.drift, w.fog, w.far, w.near]:
		assert_eq(_param(c, "rect_px"), (c as Control).size, String(c.name))
	assert_almost_eq(w.drift.size.y, 90.0 * UiFonts.K, 0.01)
	assert_eq(w.far.size, w.size, "the snow over all of it")


func test_the_dark_edges_are_the_mockups_radial_gradient() -> void:
	var f = WorldFilm.new()
	add_child_autofree(f)
	var tex := f.vignette.texture as GradientTexture2D
	assert_eq(tex.fill, GradientTexture2D.FILL_RADIAL)
	# Where a screen corner lands on the gradient: the texture's circle reaches
	# its last stop .74 of the rect out, and the rect is drawn over the screen's
	# full width and taller than it, about 45 % down.
	var reach: float = tex.fill_to.x - tex.fill_from.x
	var top: float = f.vignette.anchor_top
	var bottom: float = f.vignette.anchor_bottom
	var v: float = (0.0 - top) / (bottom - top)
	var at: float = Vector2(0.5, 0.5 - v).length() / reach
	# The mockup's radial-gradient(74% 86% at 50% 45%) at its corner (0, 0).
	var css: float = Vector2(0.5 / 0.74, 0.45 / 0.86).length()
	assert_almost_eq(at, css, 0.001, "the corner sits as far out as the mockup's")
	var g: Gradient = tex.gradient
	assert_almost_eq(g.sample(0.3).a, 0.0, 0.001, "clear to 46 %")
	assert_almost_eq(g.sample(0.78).a, 0.34, 0.001)
	assert_almost_eq(g.sample(1.0).a, 0.66, 0.001)
	assert_almost_eq(g.sample(at).a, 0.34 + (css - 0.78) / 0.22 * 0.32, 0.002, "the corner .45 dark")


func test_the_grain_is_the_mockups_tile_at_its_opacity() -> void:
	var f = WorldFilm.new()
	add_child_autofree(f)
	assert_eq(_param(f.grain, "grain"), WorldFilm.GRAIN)
	assert_almost_eq(float(_param(f.grain, "tile_px")), 160.0 * UiFonts.K, 0.01)
	assert_almost_eq(float(_param(f.grain, "opacity")), 0.55, 0.001)
	assert_eq(f.get_child(0), f.vignette, "the grain over the dark edges")
	assert_eq(f.get_child(1), f.grain)


func test_the_slice_runs_the_weather_between_the_stops() -> void:
	var f = SliceFlow.new()
	f.opts = {"skip_field": true, "seed": 3}
	add_child_autofree(f)
	var layer: CanvasLayer = f.layer
	assert_lt(f.weather.get_index(), f.frost.get_index(), "the weather under the frost")
	assert_lt(f.frost.get_index(), f.film.get_index(), "the film over it")
	assert_lt(f.film.get_index(), f.gauges.get_index(), "and the gauges over the film")
	assert_eq(f.weather.get_parent(), layer)
	var seen := {}
	while true:
		seen[f.current()] = [f.weather.visible, f.weather.moving, f.film.visible]
		if f.current() == "end":
			break
		f.next()
	assert_eq(seen["train"], [true, true, true], "running on the first stretch")
	assert_eq(seen["stop_pick"], [true, false, true], "at the stop")
	assert_eq(seen["receipt"], [true, false, true], "still at the stop")
	assert_eq(seen["council"], [true, false, true], "the session before it leaves")
	assert_eq(seen["travel"], [true, true, true], "running again")
	assert_eq(seen["arrive"], [true, false, true])
	assert_eq(seen["end"], [true, false, true])


func test_the_slice_holds_the_weather_when_asked() -> void:
	var f = SliceFlow.new()
	f.opts = {"skip_field": true, "seed": 3, "still": true}
	add_child_autofree(f)
	assert_true(f.weather.still)
	assert_eq(float(_param(f.weather.far, "still")), 1.0)
