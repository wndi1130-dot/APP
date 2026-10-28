extends "res://addons/gut/test.gd"
## Lying snow rules (weather_fx.md 4장): it deepens while it snows, a thaw and
## rain eat it, and the field hands the result to the fx shader globals.

const SnowCover = preload("res://game/sim/snow_cover.gd")
const FxState = preload("res://fx/fx_state.gd")
const FieldGame = preload("res://game/field_game.gd")
const Atmosphere = preload("res://fx/atmosphere.gd")
const SeasonTable = preload("res://game/season_table.gd")


func _stop(weather: Array) -> Node:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "cold": 1.0, "weather": weather}
	add_child_autofree(game)
	game.set_process(false)
	return game


func test_start_depth_follows_the_season() -> void:
	assert_eq(SnowCover.new("deep_winter").depth_cm, 25.0)
	assert_eq(SnowCover.new("late_winter", true).depth_cm, 7.0)
	assert_eq(SnowCover.new("early_thaw", true).depth_cm, 0.0)
	assert_eq(SnowCover.new("summer").depth_cm, SnowCover.new().depth_cm, "unknown season is deep winter")


func test_a_storm_before_arrival_lies_on_top_as_fresh_snow() -> void:
	# weather_fx 14장, the stop after the storm: season depth + 25 cm.
	var after := SnowCover.new("deep_winter", false, 25.0)
	assert_eq(after.depth_cm, 50.0)
	assert_eq(after.fresh_cm, 25.0)
	assert_gt(after.cover(), SnowCover.new("deep_winter").cover())
	assert_almost_eq(after.fresh_cover(), SnowCover.cover_for(25.0), 0.0001)
	# Clear and cold afterwards: nothing more falls.
	assert_eq(after.advance(60.0, ["clear"], -25.0), 0.0)
	assert_eq(after.fresh_cm, 25.0)
	assert_eq(SnowCover.new("deep_winter", false, -5.0).depth_cm, 25.0, "no negative storm")
	assert_eq(SnowCover.new("deep_winter", false, 500.0).depth_cm, SnowCover.MAX_CM)


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


func test_field_takes_the_storm_pictures_without_changing_rules() -> void:
	# weather_fx 14장: the look and the storm snow are picture inputs only.
	var plain = _stop(["clear"])
	var before = FieldGame.new()
	before.opts = {"seed": 5, "raiders": false, "auto_pause": false, "cold": 1.0, "weather": ["clear"], "look": ["overcast"]}
	add_child_autofree(before)
	before.set_process(false)
	assert_eq(before.weather.kinds, plain.weather.kinds, "rules play as clear")
	assert_lt(float(before.fx_light["sun_energy"]), float(plain.fx_light["sun_energy"]), "the sky is darker")
	var after = FieldGame.new()
	after.opts = {"seed": 5, "raiders": false, "auto_pause": false, "cold": 1.0, "weather": ["clear"], "storm_cm": 25.0}
	add_child_autofree(after)
	after.set_process(false)
	assert_eq(after.snow_cover.depth_cm, 50.0)
	assert_gt(float(after.fx_params["fx_snow"]), float(plain.fx_params["fx_snow"]))
	assert_eq(after.look_kinds, after.weather.kinds, "no look given: drawn as it plays")


## Decision 474 N2: the stretches before the stop lay or eat the old snow.
func test_past_stretches_lay_snow_and_the_older_ones_count_less() -> void:
	assert_almost_eq(SnowCover.after_past(5.0, []), 5.0, 0.001, "no past: the climate's depth")
	assert_almost_eq(SnowCover.after_past(5.0, [{"weather": "snow", "temp": -3.0}]), 5.0 + SnowCover.PAST_HOURS, 0.001)
	var older := SnowCover.after_past(5.0, [{"weather": "snow", "temp": -3.0}, {"weather": "overcast", "temp": -3.0}])
	assert_almost_eq(older, 5.0 + SnowCover.PAST_HOURS * SnowCover.PAST_KEEP, 0.001, "one stretch back counts less")
	assert_eq(SnowCover.after_past(20.0, [{"weather": "rain", "temp": 3.0}]), 0.0, "rain eats it, never below zero")
	assert_lt(SnowCover.after_past(10.0, [{"weather": "fog", "temp": 2.0}]), 10.0, "a mild stretch thaws it")
	assert_almost_eq(SnowCover.after_past(10.0, [{"weather": "clear", "temp": -4.0}]), 10.0, 0.001, "a clear cold snap keeps it")
	assert_eq(SnowCover.after_past(70.0, [{"weather": "blizzard", "temp": -10.0}]), SnowCover.MAX_CM)


func test_winter_stops_on_the_route_samples_lie_over_7cm_four_to_eight_in_ten() -> void:
	# The departure's pastWeather on the S1 route samples (N2 fixture), stops whose
	# nights freeze; the climate alone gave every run the same 4 of 10.
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/train/route_weather.json"))
	var rows: Array = f["tables"]["SEASON_ROWS"]
	var side := Atmosphere.side_for("prologue")
	var total := 0
	var over := 0
	var shares := {}
	for c: Dictionary in f["contracts"]:
		if not bool(c.get("climate", false)) or c.has("disaster") or not (c["expected"] as Dictionary).has("pastWeather"):
			continue
		var seg := int(c["seg"])
		if not bool(rows[seg - 1]["night_freeze"]):
			continue
		var cold := Atmosphere.cold_for("prologue", SeasonTable.seg_progress(seg))
		var past: Array = []
		for p: Dictionary in c["expected"]["pastWeather"]:
			past.append({"weather": String(p["weather"]), "temp": float(rows[int(p["seg"]) - 1]["temp"])})
		var cm := SnowCover.after_past(Atmosphere.cold_key(cold, "snow_cm", 0, side), past)
		total += 1
		var run := String(c["seed"])
		shares[run] = (shares.get(run, 0) as int) + (1 if cm > 7.0 else 0)
		if cm > 7.0:
			over += 1
	assert_gt(total, 30)
	var share := float(over) / float(total)
	assert_between(share, 0.4, 0.8, "winter stops over 7 cm: %.2f" % share)
	assert_gt((shares.values() as Array).max() - (shares.values() as Array).min(), 0, "the weather before makes runs differ")


func test_field_lays_the_past_stretches_on_its_old_snow() -> void:
	var plain = FieldGame.new()
	plain.opts = {"seed": 5, "raiders": false, "auto_pause": false, "cold": 0.55, "weather": ["clear"]}
	add_child_autofree(plain)
	plain.set_process(false)
	var after = FieldGame.new()
	after.opts = {"seed": 5, "raiders": false, "auto_pause": false, "cold": 0.55, "weather": ["clear"],
		"departure": {"pastWeather": [{"seg": 21, "weather": "snow"}, {"seg": 22, "weather": "snow"}, {"seg": 23, "weather": "snow"}]}}
	add_child_autofree(after)
	after.set_process(false)
	var want := SnowCover.after_past(plain.snow_cover.depth_cm, [{"weather": "snow", "temp": -2.0}, {"weather": "snow", "temp": -3.0}, {"weather": "snow", "temp": -3.0}])
	assert_almost_eq(after.snow_cover.depth_cm, want, 0.01)
	assert_gt(after.snow_cover.depth_cm, plain.snow_cover.depth_cm)
	assert_eq(after.snow_cover.fresh_cm, 0.0, "old snow, not fresh")
