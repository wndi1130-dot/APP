extends "res://addons/gut/test.gd"

const HordeDirector = preload("res://game/sim/horde_director.gd")
const FieldClock = preload("res://game/sim/field_clock.gd")


func _make(seed_value: int = 1):
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return HordeDirector.new(rng)


## Runs update at each arrival time exactly; returns arrival times.
func _arrivals(h, count: int) -> Array:
	var out: Array = []
	for i in count:
		var t: float = h.next_arrival
		var r: Dictionary = h.update(t)
		if r.is_empty():
			break
		out.append(t)
	return out


func test_initial_state() -> void:
	var h = _make()
	assert_eq(h.next_arrival, 270.0)
	assert_eq(h.index, 0)
	assert_eq(h.last_arrival, -INF)
	assert_false(h.is_exhausted(), "rear hordes are endless by default")
	assert_eq(h.next_entry, "east_track")
	assert_eq(h.pulled_seconds, 0.0)
	assert_eq(h.next_size(), 6)


func test_no_arrival_before_time() -> void:
	var h = _make()
	assert_eq(h.update(0.0), {})
	assert_eq(h.update(269.99), {})
	assert_eq(h.index, 0)


func test_first_arrival_east_size_six() -> void:
	var h = _make()
	h.budget_left = 60
	var r: Dictionary = h.update(270.0)
	assert_eq(r, {"index": 0, "size": 6, "entry": "east_track"})
	assert_eq(h.index, 1)
	assert_eq(h.last_arrival, 270.0)
	assert_eq(h.budget_left, 54)
	assert_eq(h.update(270.0), {}, "only one horde per arrival")


func test_interval_sequence_without_noise() -> void:
	var h = _make()
	var times: Array = _arrivals(h, 4)
	assert_eq(times.size(), 4)
	assert_almost_eq(times[0], 270.0, 0.001)
	assert_almost_eq(times[1], 499.5, 0.001)
	assert_almost_eq(times[2], 694.575, 0.001)
	assert_almost_eq(times[3], 860.38875, 0.001)
	# Each gap is 0.85x the previous.
	assert_almost_eq((times[2] - times[1]) / (times[1] - times[0]), 0.85, 0.0001)
	assert_almost_eq((times[3] - times[2]) / (times[2] - times[1]), 0.85, 0.0001)


func test_sizes_and_budget_exhaustion() -> void:
	var h = _make()
	h.budget_left = 60  # debug option only; the default is endless
	var sizes: Array = []
	var t: float = 0.0
	for i in 20:
		t = maxf(t, h.next_arrival)
		if is_inf(t):
			break
		var r: Dictionary = h.update(t)
		if r.is_empty():
			break
		sizes.append(r["size"])
	assert_eq(sizes, [6, 8, 10, 12, 14, 10], "last horde gets what is left of 60")
	assert_eq(h.budget_left, 0)
	assert_true(h.is_exhausted())
	assert_eq(h.update(99999.0), {}, "no more hordes after the budget is gone")
	assert_eq(h.seconds_to_next(2000.0), INF)
	assert_eq(h.pressure(2000.0), 0.0)
	assert_eq(h.next_size(), 0)


func test_min_gap_floor_on_schedule() -> void:
	var h = _make()
	# Force many arrivals; the computed gap would eventually fall below 60 s.
	h.budget_left = 100000
	var times: Array = _arrivals(h, 30)
	for i in range(1, times.size()):
		assert_gte(times[i] - times[i - 1], 60.0 - 0.0001)
	assert_almost_eq(times[times.size() - 1] - times[times.size() - 2], 60.0, 0.0001)


func test_noise_pulls_five_seconds_per_point() -> void:
	var h = _make()
	h.add_noise(10, 0.0)
	assert_almost_eq(h.next_arrival, 220.0, 0.0001)
	assert_almost_eq(h.pulled_seconds, 50.0, 0.0001)
	h.add_noise(0, 0.0)
	h.add_noise(-5, 0.0)
	assert_almost_eq(h.next_arrival, 220.0, 0.0001)


func test_noise_never_pulls_below_now() -> void:
	var h = _make()
	h.add_noise(1000, 100.0)
	assert_almost_eq(h.next_arrival, 100.0, 0.0001)
	assert_almost_eq(h.pulled_seconds, 170.0, 0.0001)
	assert_eq(h.update(100.0)["index"], 0)


func test_noise_never_pulls_below_min_gap() -> void:
	var h = _make()
	h.update(270.0)
	h.add_noise(1000, 280.0)
	assert_almost_eq(h.next_arrival, 330.0, 0.0001)
	assert_eq(h.update(329.0), {})
	assert_eq(h.update(330.0)["index"], 1)


func test_noise_does_not_push_back_an_overdue_horde() -> void:
	var h = _make()
	# 300 > next_arrival(270): horde overdue, arrives on next update.
	h.add_noise(5, 300.0)
	assert_almost_eq(h.next_arrival, 270.0, 0.0001)
	assert_eq(h.pulled_seconds, 0.0)
	assert_false(h.update(300.0).is_empty())


func test_noise_after_budget_ignored() -> void:
	var h = _make()
	h.budget_left = 6
	h.update(270.0)
	h.add_noise(10, 280.0)
	assert_eq(h.next_arrival, INF)
	assert_eq(h.pulled_seconds, 0.0)


func test_rest_window() -> void:
	var h = _make()
	h.update(270.0)  # next at 499.5
	h.horde_cleared(300.0, 0)
	assert_almost_eq(h.rest_until, 345.0, 0.0001)
	assert_almost_eq(h.next_arrival, 499.5, 0.0001, "rest does not delay a later horde")
	h.horde_cleared(480.0, 0)
	assert_almost_eq(h.next_arrival, 525.0, 0.0001, "rest pushes an earlier horde back")


func test_rest_shortened_by_gunshots_with_floor() -> void:
	var h = _make()
	h.horde_cleared(0.0, 2)
	assert_almost_eq(h.rest_until, 35.0, 0.0001)
	h.horde_cleared(0.0, 6)
	assert_almost_eq(h.rest_until, 15.0, 0.0001)
	h.horde_cleared(0.0, 100)
	assert_almost_eq(h.rest_until, 15.0, 0.0001)
	h.horde_cleared(0.0, -3)
	assert_almost_eq(h.rest_until, 45.0, 0.0001)


func test_noise_halved_inside_rest_window() -> void:
	var h = _make()
	h.horde_cleared(0.0, 0)  # rest until 45
	h.add_noise(10, 10.0)
	assert_almost_eq(h.next_arrival, 245.0, 0.0001)
	h.add_noise(10, 45.0)  # window over
	assert_almost_eq(h.next_arrival, 195.0, 0.0001)
	assert_almost_eq(h.pulled_seconds, 75.0, 0.0001)


func test_entry_never_three_in_a_row() -> void:
	for s in 40:
		var h = _make(s)
		h.budget_left = 100000
		var entries: Array = []
		var t: float = 0.0
		for i in 60:
			t = h.next_arrival
			var r: Dictionary = h.update(t)
			entries.append(r["entry"])
		assert_eq(entries[0], "east_track")
		var ok := true
		for i in range(2, entries.size()):
			if entries[i] == entries[i - 1] and entries[i] == entries[i - 2]:
				ok = false
		assert_true(ok, "seed %d: %s" % [s, str(entries)])
		for e in entries:
			assert_has(HordeDirector.ENTRY_NAMES, e)


func test_entries_vary_and_deterministic() -> void:
	var a = _make(7)
	var b = _make(7)
	a.budget_left = 1000
	b.budget_left = 1000
	var ea: Array = []
	var eb: Array = []
	for i in 12:
		ea.append(a.update(a.next_arrival)["entry"])
		eb.append(b.update(b.next_arrival)["entry"])
	assert_eq(ea, eb)
	assert_gt(ea.count("culvert") + ea.count("manhole"), 0, "sewers show up")


func test_seconds_to_next_and_pressure() -> void:
	var h = _make()
	assert_almost_eq(h.seconds_to_next(0.0), 270.0, 0.0001)
	assert_almost_eq(h.pressure(0.0), 0.0, 0.0001)
	assert_almost_eq(h.pressure(135.0), 0.5, 0.0001)
	assert_almost_eq(h.pressure(270.0), 1.0, 0.0001)
	assert_almost_eq(h.pressure(400.0), 1.0, 0.0001, "clamped")
	h.add_noise(27, 0.0)  # pull 135 s
	assert_almost_eq(h.pressure(0.0), 0.5, 0.0001, "noise raises pressure")
	var g = _make()
	g.update(270.0)
	assert_almost_eq(g.pressure(270.0), 0.0, 0.0001)
	g.horde_cleared(490.0, 0)  # next pushed to 535; gap stays 229.5
	assert_almost_eq(g.pressure(490.0), 1.0 - 45.0 / 229.5, 0.0001, "rest pushes pressure back down")


func test_call_range_mult() -> void:
	var h = _make()
	assert_almost_eq(h.call_range_mult(0.0), 1.0, 0.0001)
	assert_almost_eq(h.call_range_mult(-10.0), 1.0, 0.0001)
	assert_almost_eq(h.call_range_mult(900.0), 1.3, 0.0001)
	assert_almost_eq(h.call_range_mult(1800.0), 1.6, 0.0001)
	assert_almost_eq(h.call_range_mult(5000.0), 1.6, 0.0001)


func test_forecast_basic_bands() -> void:
	var h = _make()
	var c = FieldClock.new()
	assert_eq(h.forecast(0.0, 0, c), "동쪽 선로 끝으로 온다, 한 시간쯤.")
	# 50 game min = 200 s before arrival.
	assert_eq(h.forecast(70.0, 0, c), "동쪽 선로 끝으로 온다, 한 시간쯤.")
	assert_eq(h.forecast(70.1, 0, c), "동쪽 선로 끝으로 온다, 반 시간쯤.")
	# 25 game min = 100 s before arrival.
	assert_eq(h.forecast(170.0, 0, c), "동쪽 선로 끝으로 온다, 반 시간쯤.")
	assert_eq(h.forecast(170.1, 0, c), "동쪽 선로 끝으로 온다, 곧.")
	assert_eq(h.forecast(300.0, 0, c), "동쪽 선로 끝으로 온다, 곧.", "overdue")


func test_forecast_precise() -> void:
	var h = _make()
	var c = FieldClock.new()
	# Arrival at 270 s = 697.5 game min -> rounds to 11:45.
	assert_eq(h.forecast(0.0, 1, c), "동쪽 선로 끝, 11:45쯤, 여섯 남짓.")
	h.add_noise(9, 0.0)  # 225 s -> 686.25 min -> 11:30
	assert_eq(h.forecast(0.0, 1, c), "동쪽 선로 끝, 11:30쯤, 여섯 남짓.")
	h.update(h.next_arrival)
	var road: String = HordeDirector.ENTRY_NAMES[h.next_entry]
	assert_string_contains(h.forecast(230.0, 1, c), road + ", ")
	assert_string_contains(h.forecast(230.0, 1, c), "여덟 남짓.")


func test_forecast_without_clock_uses_default() -> void:
	var h = _make()
	assert_eq(h.forecast(0.0, 1, null), "동쪽 선로 끝, 11:45쯤, 여섯 남짓.")


func test_forecast_after_budget() -> void:
	var h = _make()
	h.budget_left = 6
	h.update(270.0)
	var c = FieldClock.new()
	assert_eq(h.forecast(300.0, 0, c), "더 오는 기척은 없다.")
	assert_eq(h.forecast(300.0, 1, c), "더 오는 기척은 없다.")


func test_size_word() -> void:
	var h = _make()
	assert_eq(h.size_word(0), "없음")
	assert_eq(h.size_word(-1), "없음")
	assert_eq(h.size_word(1), "몇")
	assert_eq(h.size_word(3), "몇")
	assert_eq(h.size_word(4), "넷 남짓")
	assert_eq(h.size_word(6), "여섯 남짓")
	assert_eq(h.size_word(7), "여섯 남짓")
	assert_eq(h.size_word(8), "여덟 남짓")
	assert_eq(h.size_word(10), "열 남짓")
	assert_eq(h.size_word(14), "열 남짓")
	assert_eq(h.size_word(16), "열다섯 남짓")
	assert_eq(h.size_word(20), "스물 남짓")
	assert_eq(h.size_word(60), "쉰 남짓")


func test_default_is_endless_with_growing_sizes() -> void:
	var h = _make()
	var sizes: Array = []
	for i in 12:
		sizes.append(h.update(h.next_arrival)["size"])
	assert_eq(sizes.slice(0, 4), [6, 8, 10, 12])
	assert_eq(sizes[11], 28)
	assert_false(h.is_exhausted())
	assert_eq(HordeDirector.CONCURRENT_CAP, 60)


func test_block_moves_share_to_other_holes() -> void:
	var h = _make(3)
	h.block("manhole")
	assert_false(h.is_open("manhole"))
	assert_true(h.is_open("culvert"))
	for i in 80:
		var r: Dictionary = h.update(h.next_arrival)
		assert_ne(r["entry"], "manhole")
	assert_false(h.call_from("manhole"), "a blocked hole cannot be called")


func test_block_repicks_when_next_is_blocked() -> void:
	var h = _make()
	assert_true(h.call_from("culvert"))
	assert_eq(h.next_entry, "culvert")
	h.block("culvert")
	assert_ne(h.next_entry, "culvert")


func test_call_from_sewer_only() -> void:
	var h = _make()
	assert_false(h.call_from("north_road"), "roads are not woken by sound")
	assert_eq(h.next_entry, "east_track")
	assert_true(h.call_from("manhole"))
	assert_eq(h.update(270.0)["entry"], "manhole")
	assert_true(HordeDirector.is_sewer("culvert"))
	assert_false(HordeDirector.is_sewer("east_track"))


func test_sewer_forecast_phrase() -> void:
	var h = _make()
	h.call_from("culvert")
	assert_eq(h.forecast(0.0, 0, FieldClock.new()), "급수탑 밑 암거에서 올라온다, 한 시간쯤.")
	assert_eq(h.forecast(0.0, 1, FieldClock.new()), "급수탑 밑 암거, 11:45쯤, 여섯 남짓.")


func test_weights_cover_entries() -> void:
	var total := 0.0
	for e in HordeDirector.ENTRIES:
		assert_has(HordeDirector.ENTRY_WEIGHTS, e)
		assert_has(HordeDirector.ENTRY_NAMES, e)
		assert_has(HordeDirector.ENTRY_PHRASES, e)
		total += HordeDirector.ENTRY_WEIGHTS[e]
	assert_almost_eq(total, 1.0, 0.0001)
