extends "res://addons/gut/test.gd"

const Body = preload("res://game/sim/body_state.gd")
const Treatment = preload("res://game/sim/treatment.gd")
const Rules = preload("res://game/sim/injury_rules.gd")


func test_deep_dressing_turns_dirty_at_three_minutes() -> void:
	var b := Body.new()
	b.add_wound("leg_left", "deep", 0.0)
	b.disinfect(0)
	assert_eq(b.bandage_wound(0), 2)
	b.tick(179.0, {})
	assert_false(Rules.dirty(b.wounds[0]))
	assert_true(b.tick(1.0, {}).has("bandage_dirty"))
	assert_true(Rules.dirty(b.wounds[0]))
	assert_false(b.wounds[0]["festering"])


func test_laceration_dressing_turns_dirty_at_six_minutes() -> void:
	var b := Body.new()
	b.add_wound("arm_left", "laceration", 0.0)
	b.disinfect(0)
	b.bandage_wound(0)
	b.tick(359.0, {})
	assert_false(Rules.dirty(b.wounds[0]))
	b.tick(1.0, {})
	assert_true(Rules.dirty(b.wounds[0]))


func test_replacing_a_dry_bleed_dirty_bandage_costs_one_and_three_seconds() -> void:
	var b := Body.new()
	b.add_wound("arm_left", "laceration", 0.0)
	b.disinfect(0)
	b.bandage_wound(0)
	b.tick(360.0, {})
	var steps := Treatment.runnable(Treatment.plan(b.wounds[0], {"bandage": 1}, Treatment.FIRST_AID))
	assert_eq(steps.size(), 1)
	assert_eq(steps[0]["seconds"], 3.0)
	assert_eq(steps[0]["uses"], {"bandage": 1})
	assert_eq(Treatment.apply(b, 0, "bandage"), 1)
	assert_false(Rules.dirty(b.wounds[0]))
	assert_eq(b.wounds[0]["bandage_t"], 0.0)
	assert_eq(b.bandage_wound(0), 0)


func test_a_clean_dressing_cannot_be_stacked_to_seal_a_deep_wound() -> void:
	var b := Body.new()
	b.add_wound("torso", "deep", 0.0)
	b.bandage_wound(0)
	assert_eq(b.bandage_wound(0), 0)
	b.tick(300.0, {})
	assert_almost_eq(b.wounds[0]["blood"], Body.SEEP_BLOOD, 0.00001)
	assert_eq(b.bandage_wound(0), 1)
	assert_almost_eq(b.wounds[0]["blood"], Body.SEEP_BLOOD, 0.00001)
	b.suture_wound(0)
	assert_eq(b.bleed, 0)


func test_dirty_exposure_is_independent_of_tick_size() -> void:
	var large := Body.new()
	var small := Body.new()
	for b in [large, small]:
		b.add_wound("arm_left", "deep", 0.0)
		b.disinfect(0)
		b.bandage_wound(0)
	large.tick(539.0, {})
	for _i in 539:
		small.tick(1.0, {})
	assert_false(large.has_festering())
	assert_false(small.has_festering())
	assert_almost_eq(large.wounds[0]["open_t"], small.wounds[0]["open_t"], 0.00001)
	large.tick(1.0, {})
	small.tick(1.0, {})
	assert_true(large.has_festering())
	assert_true(small.has_festering())


func test_early_replacement_and_disinfection_prevent_festering() -> void:
	var b := Body.new()
	b.add_wound("arm_left", "laceration", 0.0)
	b.disinfect(0)
	b.bandage_wound(0)
	for _i in 4:
		b.tick(360.0, {})
		b.bandage_wound(0)
	assert_false(b.has_festering())


func test_an_embedded_object_must_be_removed_before_disinfection() -> void:
	var b := Body.new()
	b.add_wound("leg_left", "embedded", 0.0)
	assert_false(b.disinfect(0))
	assert_true(b.pull_wound(0))
	assert_true(b.disinfect(0))
	assert_false(b.disinfect(0))


func test_splint_plan_needs_both_wood_and_cloth() -> void:
	var b := Body.new()
	b.fracture(false)
	var missing := Treatment.plan(b.wounds[0], {"wood": 1})
	assert_eq(missing[0]["state"], Treatment.MISSING)
	var ready := Treatment.plan(b.wounds[0], {"wood": 1, "cloth": 1})
	assert_eq(ready[0]["state"], Treatment.DO)
	assert_eq(ready[0]["uses"], {"wood": 1, "cloth": 1})
	assert_eq(ready[0]["seconds"], 10.0)


func test_missing_needle_blocks_later_steps_and_tweezers_are_kept() -> void:
	var b := Body.new()
	b.add_wound("torso", "embedded", 0.0)
	b.wounds[0]["what"] = "bullet"
	var steps := Treatment.plan(b.wounds[0], {"tweezers": 1, "bottle_spirit": 1, "bandage": 2})
	assert_eq(steps[0]["uses"], {})
	assert_eq(steps[2]["state"], Treatment.MISSING)
	assert_eq(steps[3]["state"], Treatment.BLOCKED)


func test_old_saved_wounds_without_dressing_fields_still_work() -> void:
	var b := Body.new()
	b.add_wound("torso", "scratch", 0.0)
	b.bandage_wound(0)
	b.wounds[0].erase("bandage_t")
	b.wounds[0].erase("bandage_dirty")
	b.tick(360.0, {})
	assert_true(Rules.dirty(b.wounds[0]))
	assert_eq(b.bandage_wound(0), 1)
