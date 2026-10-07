extends "res://addons/gut/test.gd"

const FieldClock = preload("res://game/sim/field_clock.gd")


func test_starts_at_arrival() -> void:
	var c = FieldClock.new()
	assert_eq(c.elapsed, 0.0)
	assert_almost_eq(c.game_minutes(), 630.0, 0.0001)
	assert_eq(c.label(), "D1 10:30")
	assert_false(c.is_dark())
	assert_eq(c.sun_fraction(), 0.0)
	assert_false(c.past_safe())
	assert_false(c.past_limit())
	assert_eq(c.stay_game_minutes(), 0)


func test_one_real_minute_is_fifteen_game_minutes() -> void:
	var c = FieldClock.new()
	c.advance(60.0)
	assert_almost_eq(c.elapsed, 60.0, 0.0001)
	assert_almost_eq(c.game_minutes(), 645.0, 0.0001)
	assert_eq(c.label(), "D1 10:45")
	assert_eq(c.stay_game_minutes(), 15)


func test_speed_doubles_field_time() -> void:
	var c = FieldClock.new()
	c.speed = 2.0
	c.advance(30.0)
	assert_almost_eq(c.elapsed, 60.0, 0.0001)
	assert_eq(c.label(), "D1 10:45")


func test_negative_or_zero_delta_ignored() -> void:
	var c = FieldClock.new()
	c.advance(-5.0)
	c.advance(0.0)
	assert_eq(c.elapsed, 0.0)


func test_label_floors_minutes() -> void:
	var c = FieldClock.new()
	c.advance(3.9)  # 58.5 game seconds -> still 10:30
	assert_eq(c.label(), "D1 10:30")
	c.advance(0.1)  # exactly one game minute
	assert_eq(c.label(), "D1 10:31")


func test_sunset_boundary() -> void:
	var c = FieldClock.new()
	c.elapsed = 1259.9
	assert_false(c.is_dark())
	assert_lt(c.sun_fraction(), 1.0)
	c.elapsed = 1260.0  # (945 - 630) * 4
	assert_true(c.is_dark())
	assert_eq(c.sun_fraction(), 1.0)
	assert_eq(c.label(), "D1 15:45")
	c.elapsed = 1800.0
	assert_eq(c.sun_fraction(), 1.0, "clamped after sunset")


func test_sun_fraction_midway() -> void:
	var c = FieldClock.new()
	c.elapsed = 630.0
	assert_almost_eq(c.sun_fraction(), 0.5, 0.0001)


func test_safe_and_limit_boundaries() -> void:
	var c = FieldClock.new()
	c.elapsed = 1199.99
	assert_false(c.past_safe())
	c.elapsed = 1200.0
	assert_true(c.past_safe())
	assert_false(c.past_limit())
	c.elapsed = 1799.99
	assert_false(c.past_limit())
	c.elapsed = 1800.0
	assert_true(c.past_limit())
	assert_eq(c.stay_game_minutes(), 450)
	assert_eq(c.label(), "D1 18:00")


func test_minutes_label_of_other_times() -> void:
	var c = FieldClock.new()
	assert_eq(c.minutes_label(0.0), "D1 10:30")
	assert_eq(c.minutes_label(270.0), "D1 11:37")  # 67.5 game min, floored
	assert_eq(c.minutes_label(-10.0), "D1 10:30")
	assert_eq(c.minutes_label(3240.0), "D2 00:00")  # 630 + 810 = 1440


func test_format_minutes() -> void:
	assert_eq(FieldClock.format_minutes(0.0), "D1 00:00")
	assert_eq(FieldClock.format_minutes(1439.9), "D1 23:59")
	assert_eq(FieldClock.format_minutes(1500.0), "D2 01:00")
