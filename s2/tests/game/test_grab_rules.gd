extends "res://addons/gut/test.gd"

const G = preload("res://game/sim/grab_rules.gd")


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func test_window_front_back_and_two_grabbers() -> void:
	assert_almost_eq(G.window(true, 1, 0, 5), 1.5, 0.0001)
	assert_almost_eq(G.window(false, 1, 0, 5), 0.75, 0.0001)
	assert_eq(G.window(true, 2, 10, 10), 0.0)
	assert_eq(G.window(false, 3, 0, 5), 0.0)


func test_window_ability_and_mult() -> void:
	# 1 + 0.03*5 + 0.02*(7-5) = 1.19
	assert_almost_eq(G.window(true, 1, 5, 7), 1.5 * 1.19, 0.0001)
	assert_almost_eq(G.window(false, 1, 5, 7, 0.8), 0.75 * 1.19 * 0.8, 0.0001)
	# weak person: 1 + 0 + 0.02*(2-5) = 0.94
	assert_almost_eq(G.window(true, 1, 0, 2), 1.5 * 0.94, 0.0001)
	assert_eq(G.window(true, 1, 0, 5, 0.0), 0.0)


func test_bite_location_crawler_always_leg() -> void:
	var r := _rng(1)
	for _i in range(50):
		assert_eq(G.bite_location(r, true), "leg")


func test_bite_location_distribution() -> void:
	var r := _rng(7)
	var n := {"arm": 0, "torso": 0, "head_neck": 0, "leg": 0}  # the head and the neck too (결정 441 (5))
	for _i in range(4000):
		var k: String = G.bite_location(r, false)
		n[k] += 1
	assert_between(n["arm"] / 4000.0, 0.56, 0.64)
	assert_between(n["torso"] / 4000.0, 0.17, 0.23)  # 0.25 before the head and the neck took 0.05
	assert_between(n["head_neck"] / 4000.0, 0.03, 0.07)
	assert_between(n["leg"] / 4000.0, 0.12, 0.18)


## A hand seen coming (decision 474 J1): grab GRAB_SEEN, scratch SCRATCH_SEEN, the
## rest snaps at air; one unseen grabs GRAB_UNSEEN and otherwise scratches.
func test_attack_outcome_distribution_and_coat() -> void:
	var r := _rng(11)
	var n := {"grab": 0, "scratch": 0, "blocked": 0, "miss": 0}
	for _i in range(4000):
		n[G.attack_outcome(r, 0.0)] += 1
	assert_eq(n["blocked"], 0)
	assert_between(n["grab"] / 4000.0, G.GRAB_SEEN - 0.03, G.GRAB_SEEN + 0.03)
	assert_between(n["scratch"] / 4000.0, G.SCRATCH_SEEN - 0.03, G.SCRATCH_SEEN + 0.03)
	r = _rng(14)
	var u := {"grab": 0, "scratch": 0, "blocked": 0, "miss": 0}
	for _i in range(4000):
		u[G.attack_outcome(r, 0.0, false)] += 1
	assert_between(u["grab"] / 4000.0, G.GRAB_UNSEEN - 0.02, G.GRAB_UNSEEN + 0.02)
	assert_eq(u["miss"], 0, "an unseen hand never snaps at air")
	r = _rng(12)
	n = {"grab": 0, "scratch": 0, "blocked": 0, "miss": 0}
	for _i in range(4000):
		n[G.attack_outcome(r, 0.5)] += 1
	assert_between(n["grab"] / 4000.0, G.GRAB_SEEN - 0.03, G.GRAB_SEEN + 0.03)
	assert_between(float(n["blocked"]) / float(n["blocked"] + n["scratch"]), 0.45, 0.55)
	r = _rng(13)
	for _i in range(200):
		assert_ne(G.attack_outcome(r, 1.0), "scratch")
