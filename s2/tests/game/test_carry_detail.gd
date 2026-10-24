extends "res://addons/gut/test.gd"

const Carry = preload("res://game/sim/carry.gd")
const Heat = preload("res://game/sim/body_heat.gd")
const Person = preload("res://game/actors/person.gd")
const OUTSIDE := {"ambient_c": -14.0, "warmth": 0.6, "wind": 0.0}


func test_capacity_keeps_the_pack_units_and_strength_bonus() -> void:
	assert_eq(Carry.limit("pockets", 5), 3.0)
	assert_eq(Carry.limit("pack", 5), 8.0)
	assert_eq(Carry.limit("big_pack", 5), 12.0)
	assert_eq(Carry.limit("pack", 7), 10.0)
	assert_eq(Carry.limit("pack", 3), 6.0)


func test_half_full_full_and_double_boundaries() -> void:
	assert_eq(Carry.state(4.0, 8.0), 0)
	assert_eq(Carry.state(4.01, 8.0), 1)
	assert_eq(Carry.state(8.0, 8.0), 1)
	assert_eq(Carry.state(8.01, 8.0), 2)
	assert_eq(Carry.state(16.0, 8.0), 2)
	assert_eq(Carry.state(16.01, 8.0), 3)
	assert_eq(Carry.state(0.0, 0.0), 0)
	assert_eq(Carry.state(0.01, 0.0), 3)


func test_negative_item_counts_cannot_reduce_load() -> void:
	assert_eq(Carry.total_weight({"wood": 2, "food_pack": -100}), 2.0)
	assert_eq(Carry.state(-5.0, 8.0), 0)
	assert_almost_eq(Carry.item_weight("tourniquet"), Carry.item_weight("cloth") + Carry.item_weight("plank"), 0.00001)


func test_soaked_clothes_add_weight_but_do_not_lower_capacity() -> void:
	var p := Person.new()
	var limit: float = p.carry_limit()
	p.heat.soak(1.0)
	assert_almost_eq(p.weight(), 1.0, 0.00001)
	assert_eq(p.carry_limit(), limit)
	assert_eq(p.cold_level(), 1)
	p.heat.soak(-1.0)
	assert_eq(p.cold_level(), 0)
	p.free()


func test_immobile_load_cannot_start_a_climb() -> void:
	var p := Person.new()
	p.items = {"wood": 17}
	assert_eq(p.carry_state(), 3)
	p.start_action("climb", "넘기", 2.0, Callable())
	assert_eq(p.action, "")
	assert_eq(p.body.breath, 1.0)
	p.free()


func test_context_wetness_persists_and_dries_after_exposure() -> void:
	var h := Heat.new()
	var wet := OUTSIDE.duplicate()
	wet["wet"] = 1.0
	h.tick(10.0, wet)
	assert_almost_eq(h.wet, 0.99, 0.00001)
	h.tick(10.0, OUTSIDE)
	assert_almost_eq(h.wet, 0.98, 0.00001)
	h.tick(10.0, {"stove": true})
	assert_almost_eq(h.wet, 0.78, 0.00001)


func test_wet_loss_uses_a_clamped_ratio() -> void:
	var dry := Heat.loss_rate(OUTSIDE, 0.0)
	var wet := Heat.loss_rate(OUTSIDE, 1.0)
	# Soaked through cools twice as fast, the warmth not cut again (reverted
	# reference value: no decision or brief number, the existing rule first).
	assert_almost_eq(wet, dry * 2.0, 0.00001)
	assert_eq(Heat.loss_rate(OUTSIDE, 2.0), wet)
	assert_eq(Heat.loss_rate(OUTSIDE, -1.0), dry)


func test_windproof_movement_and_ambient_keep_their_original_effects() -> void:
	var windy := OUTSIDE.duplicate()
	windy["wind"] = 1.0
	var dry := Heat.loss_rate(OUTSIDE, 0.0)
	assert_almost_eq(Heat.loss_rate(windy, 0.0), dry * 2.0, 0.00001)
	windy["windproof"] = 1.0
	assert_almost_eq(Heat.loss_rate(windy, 0.0), dry, 0.00001)
	windy["moving"] = true
	assert_almost_eq(Heat.loss_rate(windy, 0.0), dry * 0.8, 0.00001)
	windy["ambient_c"] = 10.0
	assert_eq(Heat.loss_rate(windy, 0.0), 0.0)


func test_field_cold_stays_at_one_tier() -> void:
	var p := Person.new()
	p.heat.heat = 0.0
	assert_eq(p.cold_level(), 1)
	p.free()


func test_simple_splint_also_requires_cloth_and_consumes_it_at_completion() -> void:
	var p := Person.new()
	p.body.fracture(false)
	p.items = {"wood": 1}
	p.start_action("splint", "부목", 10.0, p.body.splint)
	assert_eq(p.action, "")
	p.items["cloth"] = 1
	p.start_action("splint", "부목", 10.0, p.body.splint)
	assert_eq(p.action, "splint")
	assert_eq(p.items["cloth"], 1)
	var done: Callable = p.action_done
	p.cancel_action()
	done.call()
	assert_false(p.items.has("cloth"))
	assert_true(p.body.splinted)
	p.free()


func test_crouched_search_and_treatment_are_allowed_but_walking_cancels() -> void:
	var p := Person.new()
	p.crouched = true
	for action in ["search", "treat"]:
		p.start_action(action, "손일", 4.0, Callable())
		assert_eq(p.action, action)
		assert_true(p.crouched)
		p.go_to(PackedVector3Array([Vector3(2.0, 0.0, 0.0)]))
		assert_eq(p.action, "")
	p.free()
