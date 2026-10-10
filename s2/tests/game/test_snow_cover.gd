extends "res://addons/gut/test.gd"
## Lying snow rules (weather_fx.md 4장): it deepens while it snows, a thaw and
## rain eat it, and the field hands the result to the fx shader globals.

const SnowCover = preload("res://game/sim/snow_cover.gd")
const FxState = preload("res://fx/fx_state.gd")
const FieldGame = preload("res://game/field_game.gd")


func _stop(weather: Array) -> Node:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "weather": weather}
	add_child_autofree(game)
	game.set_process(false)
	return game


func test_start_depth_follows_the_season() -> void:
	assert_eq(SnowCover.new("deep_winter").depth_cm, 25.0)
	assert_eq(SnowCover.new("late_winter", true).depth_cm, 7.0)
	assert_eq(SnowCover.new("early_thaw", true).depth_cm, 0.0)
	assert_eq(SnowCover.new("summer").depth_cm, SnowCover.new().depth_cm, "unknown season is deep winter")


func test_cover_curve_matches_the_three_thicknesses() -> void:
	assert_eq(SnowCover.cover_for(0.0), 0.0)
	assert_almost_eq(SnowCover.cover_for(7.0), FxState.snow_for_level(1), 0.03)
	assert_almost_eq(SnowCover.cover_for(40.0), FxState.snow_for_level(2), 0.03)
	var last := -1.0
	for cm in [0.0, 2.0, 7.0, 15.0, 25.0, 40.0, 80.0]:
		var c := SnowCover.cover_for(cm)
		assert_gt(c, last, "deeper snow covers more")
		assert_true(c >= 0.0 and c <= 1.0)
		last = c


func test_snowfall_deepens_and_a_blizzard_is_faster() -> void:
	var calm := SnowCover.new()
	var storm := SnowCover.new()
	calm.advance(120.0, ["fog", "snow"], -14.0)
	storm.advance(120.0, ["blizzard"], -14.0)
	assert_almost_eq(calm.depth_cm, 27.0, 0.001)
	assert_almost_eq(calm.fresh_cm, 2.0, 0.001)
	assert_gt(storm.depth_cm, calm.depth_cm)
	assert_gt(storm.fresh_cover(), calm.fresh_cover())


func test_clear_cold_weather_changes_nothing() -> void:
	var s := SnowCover.new()
	assert_eq(s.advance(600.0, ["clear"], -14.0), 0.0)
	assert_eq(s.advance(600.0, ["fog"], -3.0), 0.0)
	assert_eq(s.fresh_cm, 0.0)
	assert_eq(s.advance(0.0, ["blizzard"], -14.0), 0.0)
	assert_eq(s.advance(-5.0, ["blizzard"], -14.0), 0.0)


func test_thaw_and_rain_eat_snow_and_never_go_below_zero() -> void:
	var s := SnowCover.new("early_thaw")
	s.advance(60.0, ["snow"], -2.0)
	assert_almost_eq(s.fresh_cm, 1.0, 0.001)
	assert_lt(s.advance(60.0, ["overcast"], 4.0), 0.0, "four degrees melts")
	assert_eq(s.fresh_cm, 0.0, "fresh snow goes first")
	# Snow kinds lay nothing above freezing.
	assert_lt(SnowCover.rate_cm_h(["snow"], 3.0), 0.0)
	assert_lt(SnowCover.rate_cm_h(["rain"], 4.0), SnowCover.rate_cm_h(["overcast"], 4.0))
	s.advance(6000.0, ["rain"], 6.0)
	assert_eq(s.depth_cm, 0.0)
	assert_eq(s.cover(), 0.0)
	var deep := SnowCover.new()
	deep.advance(60000.0, ["blizzard"], -20.0)
	assert_eq(deep.depth_cm, SnowCover.MAX_CM)


func test_field_snow_deepens_through_the_stop() -> void:
	var game = _stop(["fog", "snow"])
	var at_arrival: float = game.fx_params["fx_snow"]
	assert_almost_eq(at_arrival, game.snow_cover.cover(), 0.0001, "the field feeds its lying snow")
	# Three game hours of fine snow.
	game.clock.elapsed = 180.0 * 60.0 / 15.0
	game._update_snow()
	assert_almost_eq(game.snow_cover.fresh_cm, 3.0, 0.01)
	assert_gt(float(game.fx_params["fx_snow"]), at_arrival)


func test_field_snow_stays_put_on_a_clear_day() -> void:
	var game = _stop(["clear"])
	var at_arrival: float = game.fx_params["fx_snow"]
	game.clock.elapsed = 1800.0
	game._update_snow()
	assert_eq(float(game.fx_params["fx_snow"]), at_arrival)
