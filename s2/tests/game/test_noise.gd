extends "res://addons/gut/test.gd"

const SimNoise = preload("res://game/sim/noise.gd")


func test_tables_match_docs() -> void:
	assert_eq(SimNoise.SCORE, [0, 1, 3, 6])
	assert_eq(SimNoise.RADIUS, [3.0, 12.0, 35.0, 1000.0])
	assert_eq(SimNoise.LINGER, [0.0, 30.0, 60.0, 90.0])
	assert_eq(SimNoise.NAMES.size(), 4)
	assert_eq(SimNoise.Level.QUIET, 0)
	assert_eq(SimNoise.Level.VERY_LOUD, 3)


func test_radius_outdoor_indoor() -> void:
	assert_eq(SimNoise.radius(SimNoise.Level.QUIET, false), 3.0)
	assert_eq(SimNoise.radius(SimNoise.Level.NORMAL, false), 12.0)
	assert_eq(SimNoise.radius(SimNoise.Level.LOUD, false), 35.0)
	assert_eq(SimNoise.radius(SimNoise.Level.QUIET, true), 1.5)
	assert_eq(SimNoise.radius(SimNoise.Level.NORMAL, true), 6.0)
	assert_eq(SimNoise.radius(SimNoise.Level.LOUD, true), 17.5)


func test_radius_range_mult_after_indoor() -> void:
	assert_almost_eq(SimNoise.radius(SimNoise.Level.LOUD, true, 1.6), 28.0, 0.0001)
	assert_almost_eq(SimNoise.radius(SimNoise.Level.NORMAL, false, 1.5), 18.0, 0.0001)
	assert_eq(SimNoise.radius(SimNoise.Level.NORMAL, false, 0.0), 0.0)
	assert_eq(SimNoise.radius(SimNoise.Level.NORMAL, false, -1.0), 0.0, "negative mult clamps to 0")


func test_very_loud_is_whole_map_even_indoors() -> void:
	assert_gte(SimNoise.radius(SimNoise.Level.VERY_LOUD, false), 500.0)
	assert_gte(SimNoise.radius(SimNoise.Level.VERY_LOUD, true), 500.0)
	assert_gte(SimNoise.radius(SimNoise.Level.VERY_LOUD, true, 0.1), 500.0)


func test_radius_clamps_bad_level() -> void:
	assert_eq(SimNoise.radius(-1, false), 3.0)
	assert_gte(SimNoise.radius(9, false), 500.0)


func test_footstep_base() -> void:
	assert_eq(SimNoise.footstep_radius(false, 1.0, 1.0, false, 0), 3.0)
	assert_eq(SimNoise.footstep_radius(true, 1.0, 1.0, false, 0), 12.0)


func test_footstep_crouch_and_stealth() -> void:
	assert_almost_eq(SimNoise.footstep_radius(false, 1.0, 1.0, true, 0), 1.5, 0.0001)
	assert_almost_eq(SimNoise.footstep_radius(false, 1.0, 1.0, true, 5), 1.5 * 0.8, 0.0001)
	assert_almost_eq(SimNoise.footstep_radius(false, 1.0, 1.0, true, 10), 1.5 * 0.6, 0.0001)
	assert_almost_eq(SimNoise.footstep_radius(false, 1.0, 1.0, true, 30), 1.5 * 0.6, 0.0001, "stealth cut caps at 40%")
	assert_almost_eq(SimNoise.footstep_radius(false, 1.0, 1.0, true, -3), 1.5, 0.0001)


func test_stealth_only_when_crouched_and_crouch_only_walking() -> void:
	assert_eq(SimNoise.footstep_radius(false, 1.0, 1.0, false, 10), 3.0)
	assert_eq(SimNoise.footstep_radius(true, 1.0, 1.0, true, 10), 12.0)


func test_footstep_floor_and_trait_mults() -> void:
	assert_almost_eq(SimNoise.footstep_radius(false, 1.5, 1.0, false, 0), 4.5, 0.0001)  # metal
	assert_almost_eq(SimNoise.footstep_radius(true, 0.5, 1.0, false, 0), 6.0, 0.0001)  # deep snow
	assert_almost_eq(SimNoise.footstep_radius(false, 1.0, 0.5, true, 10), 1.5 * 0.6 * 0.5, 0.0001)
	assert_almost_eq(SimNoise.footstep_radius(true, 1.5, 1.5, false, 0), 27.0, 0.0001)


func test_footstep_on_glass() -> void:
	assert_eq(SimNoise.footstep_radius(false, 1.0, 1.0, false, 0, true), 12.0)


func test_footstep_level() -> void:
	assert_eq(SimNoise.footstep_level(false, false), SimNoise.Level.QUIET)
	assert_eq(SimNoise.footstep_level(true, false), SimNoise.Level.NORMAL)
	assert_eq(SimNoise.footstep_level(false, true), SimNoise.Level.NORMAL)
	assert_eq(SimNoise.footstep_level(true, true), SimNoise.Level.NORMAL)
