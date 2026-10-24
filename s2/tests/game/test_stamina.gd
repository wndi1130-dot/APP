extends "res://addons/gut/test.gd"

const Body = preload("res://game/sim/body_state.gd")
const Stamina = preload("res://game/sim/stamina.gd")
const Person = preload("res://game/actors/person.gd")


func test_running_preserves_base_rates() -> void:
	var b := Body.new()
	b.tick(1.0, {"running": true})
	assert_almost_eq(b.exhaustion, 0.004, 0.00001)
	assert_almost_eq(b.breath, 0.88, 0.00001)


func test_load_and_cold_raise_cost_without_double_counting_fatigue() -> void:
	var b := Body.new()
	b.tick(1.0, {"running": true, "carry_state": 2, "cold_level": 1})
	assert_almost_eq(b.exhaustion, 0.004 * 1.6 * 1.25, 0.00001)
	assert_almost_eq(b.breath, 1.0 - 0.12 * 1.5 * 1.25, 0.00001)


func test_walking_recovers_a_quarter_and_rest_recovers_in_full() -> void:
	var walk := Stamina.advance(0.0, 0.2, 1.0, {"moving": true})
	var rest := Stamina.advance(0.0, 0.2, 1.0, {})
	var tired := Stamina.advance(0.5, 0.2, 1.0, {})
	assert_almost_eq(walk.y - 0.2, (rest.y - 0.2) * 0.25, 0.00001)
	assert_almost_eq(tired.y, rest.y, 0.00001, "the stop's fatigue does not slow the rest (reverted reference value)")


func test_loaded_walk_cannot_recharge_but_stationary_rest_can() -> void:
	var walk := Stamina.advance(0.0, 0.2, 1.0, {"moving": true, "carry_state": 2})
	var rest := Stamina.advance(0.0, 0.2, 1.0, {"carry_state": 2})
	assert_almost_eq(walk.y, 0.2, 0.00001)
	assert_gt(rest.y, walk.y)


func test_working_is_not_indoor_rest() -> void:
	var b := Body.new()
	b.exhaustion = 0.6
	b.breath = 0.5
	b.tick(10.0, {"working": true, "indoor_rest": true})
	assert_almost_eq(b.exhaustion, 0.6, 0.00001)
	assert_almost_eq(b.breath, 0.5, 0.00001)


func test_running_waits_for_a_separate_resume_threshold() -> void:
	var b := Body.new()
	b.breath = 0.14
	b.tick(0.01, {})
	assert_false(b.can_run())
	b.tick(0.1, {})
	assert_gt(b.breath, Body.RUN_BREATH_MIN)
	assert_false(b.can_run())
	b.tick(0.4, {})
	assert_true(b.can_run())


func test_crouch_wins_over_a_stale_run_toggle() -> void:
	var p := Person.new()
	p.running = true
	p.crouched = true
	p.moving = true
	assert_almost_eq(p.speed(0), Person.CROUCH, 0.00001)
	assert_false(p.is_running_now())
	p.free()


func test_climbing_pays_once_on_entry_and_cancellation_does_not_refund() -> void:
	var p := Person.new()
	p.start_action("climb", "넘기", 2.0, Callable())
	var spent: float = p.body.breath
	assert_lt(spent, 1.0)
	p.cancel_action()
	assert_eq(p.body.breath, spent)
	assert_almost_eq(p.body.exhaustion, 2.0 * Body.RUN_FATIGUE, 0.00001)
	p.free()


func test_existing_attack_fatigue_is_not_charged_again() -> void:
	var b := Body.new()
	b.add_fatigue(0.05)
	b.tick(1.0, {"swinging": true})
	assert_almost_eq(b.exhaustion, 0.05, 0.00001)
	assert_eq(b.breath, 1.0)


func test_negative_time_and_large_time_stay_in_range() -> void:
	var b := Body.new()
	b.tick(-1.0, {"running": true})
	assert_eq(b.exhaustion, 0.0)
	assert_eq(b.breath, 1.0)
	b.tick(10000.0, {"running": true})
	assert_eq(b.exhaustion, 1.0)
	assert_eq(b.breath, 0.0)
	assert_false(b.can_run())
