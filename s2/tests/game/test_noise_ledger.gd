extends "res://addons/gut/test.gd"

const SimNoise = preload("res://game/sim/noise.gd")
const NoiseLedger = preload("res://game/sim/noise_ledger.gd")


func test_empty() -> void:
	var l = NoiseLedger.new()
	assert_eq(l.total, 0)
	assert_eq(l.history.size(), 0)
	assert_eq(l.score_since(0.0), 0)


func test_add_returns_points_and_accumulates() -> void:
	var l = NoiseLedger.new()
	assert_eq(l.add(SimNoise.Level.QUIET, 1.0, "walk"), 0)
	assert_eq(l.add(SimNoise.Level.NORMAL, 2.0, "pry"), 1)
	assert_eq(l.add(SimNoise.Level.LOUD, 3.0, "pistol"), 3)
	assert_eq(l.add(SimNoise.Level.VERY_LOUD, 4.0, "shotgun"), 6)
	assert_eq(l.total, 10)
	assert_eq(l.history.size(), 4)


func test_history_entries() -> void:
	var l = NoiseLedger.new()
	l.add(SimNoise.Level.LOUD, 12.5, "pistol")
	l.add(SimNoise.Level.NORMAL, 20.0, "door")
	assert_eq(l.history[0], {"t": 12.5, "level": SimNoise.Level.LOUD, "tag": "pistol", "total": 3})
	assert_eq(l.history[1], {"t": 20.0, "level": SimNoise.Level.NORMAL, "tag": "door", "total": 4})


func test_score_since_is_inclusive() -> void:
	var l = NoiseLedger.new()
	l.add(SimNoise.Level.LOUD, 10.0, "a")
	l.add(SimNoise.Level.VERY_LOUD, 20.0, "b")
	l.add(SimNoise.Level.NORMAL, 30.0, "c")
	assert_eq(l.score_since(0.0), 10)
	assert_eq(l.score_since(10.0), 10)
	assert_eq(l.score_since(10.01), 7)
	assert_eq(l.score_since(20.0), 7)
	assert_eq(l.score_since(30.0), 1)
	assert_eq(l.score_since(30.01), 0)


func test_bad_level_clamped() -> void:
	var l = NoiseLedger.new()
	assert_eq(l.add(7, 0.0, "x"), 6)
	assert_eq(l.add(-2, 0.0, "y"), 0)
	assert_eq(l.history[0]["level"], SimNoise.Level.VERY_LOUD)
	assert_eq(l.total, 6)
