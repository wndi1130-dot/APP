extends "res://addons/gut/test.gd"

const G = preload("res://game/sim/grab_rules.gd")


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func test_window_front_back_and_two_grabbers() -> void:
	assert_almost_eq(G.window(true, 1, 0, 5), 1.0, 0.0001)
	assert_almost_eq(G.window(false, 1, 0, 5), 0.5, 0.0001)
	assert_eq(G.window(true, 2, 10, 10), 0.0)
	assert_eq(G.window(false, 3, 0, 5), 0.0)


func test_window_ability_and_mult() -> void:
	# 1 + 0.03*5 + 0.02*(7-5) = 1.19
	assert_almost_eq(G.window(true, 1, 5, 7), 1.19, 0.0001)
	assert_almost_eq(G.window(false, 1, 5, 7, 0.8), 0.5 * 1.19 * 0.8, 0.0001)
	# weak person: 1 + 0 + 0.02*(2-5) = 0.94
	assert_almost_eq(G.window(true, 1, 0, 2), 0.94, 0.0001)
	assert_eq(G.window(true, 1, 0, 5, 0.0), 0.0)


func test_bite_location_crawler_always_leg() -> void:
	var r := _rng(1)
	for _i in range(50):
		assert_eq(G.bite_location(r, true), "leg")


func test_bite_location_distribution() -> void:
	var r := _rng(7)
	var n := {"arm": 0, "torso": 0, "leg": 0}
	for _i in range(4000):
		var k: String = G.bite_location(r, false)
		n[k] += 1
	assert_between(n["arm"] / 4000.0, 0.56, 0.64)
	assert_between(n["torso"] / 4000.0, 0.22, 0.28)
	assert_between(n["leg"] / 4000.0, 0.12, 0.18)


func test_attack_outcome_distribution_and_coat() -> void:
	var r := _rng(11)
	var n := {"grab": 0, "scratch": 0, "blocked": 0}
	for _i in range(4000):
		n[G.attack_outcome(r, 0.0)] += 1
	assert_eq(n["blocked"], 0)
	assert_between(n["grab"] / 4000.0, 0.62, 0.68)
	r = _rng(12)
	n = {"grab": 0, "scratch": 0, "blocked": 0}
	for _i in range(4000):
		n[G.attack_outcome(r, 0.5)] += 1
	assert_between(n["grab"] / 4000.0, 0.62, 0.68)
	assert_between(float(n["blocked"]) / float(n["blocked"] + n["scratch"]), 0.45, 0.55)
	r = _rng(13)
	for _i in range(200):
		assert_ne(G.attack_outcome(r, 1.0), "scratch")
