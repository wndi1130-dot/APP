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


func test_a_stop_rolls_its_arrival_mostly_by_day() -> void:
	# Decision 471 B0: 40% morning, 35% midday, 20% late afternoon, 5% dusk.
	var bands := [0, 0, 0, 0]
	for s in range(1, 401):
		var a := FieldClock.arrival_for(s)
		assert_eq(a % 10, 0, "on the ten minutes")
		assert_eq(a, FieldClock.arrival_for(s), "the same seed, the same arrival")
		for k in FieldClock.ARRIVALS.size():
			var b: Array = FieldClock.ARRIVALS[k]
			if a >= int(b[1]) and a <= int(b[2]):
				bands[k] += 1
	assert_eq(int(bands[0]) + int(bands[1]) + int(bands[2]) + int(bands[3]), 400, "every arrival inside a band")
	assert_between(float(bands[0]) / 400.0, 0.32, 0.48, "morning")
	assert_between(float(bands[1]) / 400.0, 0.27, 0.43, "midday")
	assert_between(float(bands[2]) / 400.0, 0.13, 0.27, "late afternoon")
	assert_lte(float(bands[3]) / 400.0, 0.10, "a dusk arrival is rare")


func test_the_clock_runs_from_the_stop_s_arrival() -> void:
	var c = FieldClock.new()
	c.arrive_min = 480.0
	assert_eq(c.label(), "D1 08:00")
	c.elapsed = 60.0  # 15 game minutes
	assert_almost_eq(c.game_minutes(), 495.0, 0.0001)
	assert_almost_eq(c.sun_fraction(), 15.0 / (945.0 - 480.0), 0.0001)
	c.arrive_min = 900.0
	c.elapsed = 240.0  # an hour later: 16:00, dark
	assert_true(c.is_dark())
	assert_almost_eq(c.dusk_share(), 1.0, 0.0001)


func test_format_minutes() -> void:
	assert_eq(FieldClock.format_minutes(0.0), "D1 00:00")
	assert_eq(FieldClock.format_minutes(1439.9), "D1 23:59")
	assert_eq(FieldClock.format_minutes(1500.0), "D2 01:00")
