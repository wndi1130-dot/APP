extends "res://addons/gut/test.gd"

const Body = preload("res://game/sim/body_state.gd")
const Rules = preload("res://game/sim/injury_rules.gd")


func test_pain_is_bounded_and_splint_eases_a_fracture() -> void:
	var b := Body.new()
	var i := b.add_wound("leg_left", "fracture", 0.0)
	assert_almost_eq(b.pain(), 1.0, 0.00001)
	b.splint_wound(i)
	assert_almost_eq(b.pain(), 0.5, 0.00001)
	b.add_wound("torso", "embedded", 0.0)
	assert_almost_eq(b.pain(), 1.0, 0.00001)


func test_clean_bandage_eases_pain_without_curing_a_bite() -> void:
	var b := Body.new()
	b.apply_bite(RandomNumberGenerator.new(), "arm", 0.0)
	b.bandage_wound(0)
	assert_almost_eq(b.pain(), 0.2, 0.00001)
	assert_true(b.infected)
	assert_eq(b.window_left, 480.0)


func test_head_blood_aim_penalty_ends_when_covered() -> void:
	var b := Body.new()
	b.add_wound("head_neck", "scratch", 0.0)
	assert_almost_eq(b.multipliers({})["aim_min"], 1.4, 0.00001)
	b.bandage_wound(0)
	assert_almost_eq(b.multipliers({})["aim_min"], 1.0, 0.00001)


func test_light_and_deep_arm_injuries_use_the_body_table() -> void:
	var b := Body.new()
	b.add_wound("arm_left", "scratch", 0.0)
	assert_almost_eq(b.multipliers({})["reload"], 0.8, 0.00001)
	assert_false(b.multipliers({})["one_hand"])
	b.add_wound("arm_right", "deep", 0.0)
	assert_almost_eq(b.multipliers({})["reload"], 0.6, 0.00001)
	assert_true(b.multipliers({})["one_hand"])


func test_leg_wound_slows_walking_and_deep_wound_blocks_running() -> void:
	var b := Body.new()
	b.add_wound("leg_left", "scratch", 0.0)
	assert_almost_eq(b.multipliers({})["move"], 0.8, 0.00001)
	b.add_wound("leg_right", "deep", 0.0, 0.0)
	assert_false(b.can_run())
	assert_almost_eq(b.multipliers({})["move"], 0.6, 0.00001)


func test_torso_injury_spends_more_breath() -> void:
	var healthy := Body.new()
	var hurt := Body.new()
	hurt.add_wound("torso", "scratch", 0.0)
	healthy.tick(1.0, {"running": true})
	hurt.tick(1.0, {"running": true})
	assert_lt(hurt.breath, healthy.breath)
	assert_gt(hurt.exhaustion, healthy.exhaustion)


func test_torso_festering_matches_the_exact_region() -> void:
	var b := Body.new()
	var i := b.add_wound("torso", "scratch", 0.0)
	b.set_festering(i, true)
	assert_true(b.festering_on("torso"))
	assert_false(b.festering_on("arm"))
	assert_almost_eq(b.multipliers({})["swing"], Body.FESTER_MULT, 0.00001)


func test_repeated_wounds_have_a_fixed_budget_without_losing_hits() -> void:
	var b := Body.new()
	for i in 1000:
		b.add_wound("arm_left", "scratch", float(i))
	assert_eq(b.wounds.size(), Rules.MAX_SAME_WOUNDS)
	var hits := 0
	for w in b.wounds:
		hits += int(w["hits"])
	assert_eq(hits, 1000)
	assert_almost_eq(b.blood_total(), 150.0, 0.0001)
	assert_almost_eq(b.pain(), 1.0, 0.00001)


func test_heavy_bleed_keeps_the_original_death_clock() -> void:
	var b := Body.new()
	b.add_wound("torso", "deep", 0.0)
	b.tick(120.0, {})
	assert_true(b.downed)
	assert_false(b.dead)
	b.tick(59.0, {})
	assert_false(b.dead)
	assert_true(b.tick(1.0, {}).has("died"))
	assert_true(b.dead)


func test_merged_wounds_preserve_left_right_hit_distribution() -> void:
	var b := Body.new()
	for i in 100:
		b.apply_cut(false, float(i), "arm")
	var left := 0
	var right := 0
	for w in b.wounds:
		if w["part"] == "arm_left":
			left += int(w["hits"])
		else:
			right += int(w["hits"])
	assert_eq(left, 50)
	assert_eq(right, 50)
	assert_eq(b.wounds.size(), Rules.MAX_SAME_WOUNDS * 2)


func test_infection_window_is_not_a_field_death_timer() -> void:
	var b := Body.new()
	b.apply_bite(RandomNumberGenerator.new(), "arm", 0.0)
	b.bandage_wound(0)
	b.tick(480.0, {})
	assert_eq(b.window_left, 0.0)
	assert_true(b.infected)
	assert_false(b.dead)
