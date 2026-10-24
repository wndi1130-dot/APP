extends "res://addons/gut/test.gd"

const N = preload("res://game/sim/noise.gd")
const Ledger = preload("res://game/sim/noise_ledger.gd")


func test_indoor_footsteps_keep_floor_crouch_and_skill_factors() -> void:
	assert_almost_eq(N.footstep_radius(false, 1.0, 1.0, false, 0, false, true), 1.5, 0.0001)
	assert_almost_eq(N.footstep_radius(true, 1.0, 1.0, false, 0, false, true), 6.0, 0.0001)
	assert_almost_eq(N.footstep_radius(false, 1.0, 1.0, true, 10, false, true), 0.45, 0.0001)
	assert_almost_eq(N.footstep_radius(false, 1.0, 1.0, false, 0, true, true), 6.0, 0.0001)


func test_observation_does_not_double_count_pressure_or_keep_an_unbounded_step_history() -> void:
	var ledger = Ledger.new()
	ledger.add(N.Level.NORMAL, 1.0, "run")
	for i in range(100):
		ledger.observe(N.Level.NORMAL, "run", 12.0, 2)
	assert_eq(ledger.total, 1)
	assert_eq(ledger.history.size(), 1)
	assert_eq(ledger.sound_events, 100)
	assert_eq(ledger.sound_reactions, 200)
	assert_eq(ledger.by_action.size(), 1)
	assert_eq(ledger.by_action["run"]["linger"], 30.0)
