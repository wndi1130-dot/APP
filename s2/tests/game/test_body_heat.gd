extends "res://addons/gut/test.gd"

const Heat = preload("res://game/sim/body_heat.gd")

const OUTSIDE := {"ambient_c": -14.0, "indoor": false, "stove": false, "warmth": 0.6, "windproof": 0.0, "moving": false, "wind": 0.0}


func _time_to_level(h: Heat, target: int, ctx: Dictionary) -> float:
	var t := 0.0
	while h.level() < target and t < 7200.0:
		h.tick(1.0, ctx)
		t += 1.0
	return t


func test_level_boundaries() -> void:
	assert_eq(Heat.level_of(100.0), 0)
	assert_eq(Heat.level_of(65.0), 0)
	assert_eq(Heat.level_of(64.9), 1)
	assert_eq(Heat.level_of(35.0), 1)
	assert_eq(Heat.level_of(34.9), 2)
	assert_eq(Heat.level_of(12.0), 2)
	assert_eq(Heat.level_of(11.9), 3)
	assert_eq(Heat.level_of(0.0), 3)
	var h := Heat.new()
	assert_eq(h.level(), 0)


func test_calibration_standing_outside_normal_clothes() -> void:
	# Target: cold ~5 min, light hypothermia ~13 min, each within +-25%.
	var h := Heat.new()
	var t_cold := _time_to_level(h, 1, OUTSIDE)
	assert_between(t_cold, 300.0 * 0.75, 300.0 * 1.25)
	var t_hypo := t_cold + _time_to_level(h, 2, OUTSIDE)
	assert_between(t_hypo, 780.0 * 0.75, 780.0 * 1.25)


func test_moving_wind_wet_change_speed() -> void:
	var base := Heat.loss_rate(OUTSIDE, 0.0)
	var mv := OUTSIDE.duplicate()
	mv["moving"] = true
	assert_almost_eq(Heat.loss_rate(mv, 0.0), base * 0.8, 0.00001)
	var windy := OUTSIDE.duplicate()
	windy["wind"] = 1.0
	assert_almost_eq(Heat.loss_rate(windy, 0.0), base * 2.0, 0.00001)
	windy["windproof"] = 1.0
	assert_almost_eq(Heat.loss_rate(windy, 0.0), base, 0.00001)
	assert_almost_eq(Heat.loss_rate(OUTSIDE, 1.0), base * 2.0, 0.00001)
	var warm := OUTSIDE.duplicate()
	warm["warmth"] = 1.2
	assert_lt(Heat.loss_rate(warm, 0.0), base)


func test_ambient_scales_loss() -> void:
	var mild := OUTSIDE.duplicate()
	mild["ambient_c"] = 10.0
	assert_eq(Heat.loss_rate(mild, 0.0), 0.0)
	mild["ambient_c"] = -2.0
	assert_almost_eq(Heat.loss_rate(mild, 0.0), Heat.loss_rate(OUTSIDE, 0.0) * 0.5, 0.00001)


func test_indoor_quarter_and_stove_recovers() -> void:
	var a := Heat.new()
	var b := Heat.new()
	var inside := OUTSIDE.duplicate()
	inside["indoor"] = true
	a.tick(100.0, OUTSIDE)
	b.tick(100.0, inside)
	assert_almost_eq(100.0 - b.heat, (100.0 - a.heat) * 0.25, 0.0001)
	var stove := inside.duplicate()
	stove["stove"] = true
	a.heat = 40.0
	a.tick(10.0, stove)
	assert_almost_eq(a.heat, 52.0, 0.0001)
	a.tick(100.0, stove)
	assert_eq(a.heat, 100.0)


func test_heat_never_below_zero() -> void:
	var h := Heat.new()
	h.tick(100000.0, OUTSIDE)
	assert_eq(h.heat, 0.0)
	assert_eq(h.level(), 3)


func test_soak_and_drying() -> void:
	var h := Heat.new()
	h.soak(0.7)
	h.soak(0.7)
	assert_eq(h.wet, 1.0)
	h.soak(-2.0)
	assert_eq(h.wet, 0.0)
	h.soak(1.0)
	var stove := OUTSIDE.duplicate()
	stove["stove"] = true
	h.tick(10.0, stove)
	assert_almost_eq(h.wet, 0.8, 0.0001)
	h.tick(10.0, OUTSIDE)
	assert_almost_eq(h.wet, 0.79, 0.0001)
	h.tick(1000.0, stove)
	assert_eq(h.wet, 0.0)


func test_wet_cools_twice_as_fast() -> void:
	var dry := Heat.new()
	var soaked := Heat.new()
	soaked.soak(1.0)
	var t_dry := _time_to_level(dry, 1, OUTSIDE)
	var t_wet := _time_to_level(soaked, 1, OUTSIDE)
	assert_between(t_wet / t_dry, 0.48, 0.56)


func test_ctx_wet_applies_without_soaking() -> void:
	var a := Heat.new()
	var b := Heat.new()
	var sleet := OUTSIDE.duplicate()
	sleet["wet"] = 1.0
	a.tick(10.0, OUTSIDE)
	b.tick(10.0, sleet)
	assert_almost_eq(100.0 - b.heat, (100.0 - a.heat) * 2.0, 0.0001)
	assert_eq(b.wet, 0.0)
