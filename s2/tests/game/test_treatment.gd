extends "res://addons/gut/test.gd"
## The order of care for one wound (body_injury 4.6): first aid stops the blood,
## full care runs every step the tools allow and stops at a missing tool.

const Body = preload("res://game/sim/body_state.gd")
const Treatment = preload("res://game/sim/treatment.gd")


func _ids(steps: Array) -> Array:
	return steps.map(func(s): return s["id"])


func _states(steps: Array) -> Array:
	return steps.map(func(s): return s["state"])


func test_a_laceration_is_cleaned_then_bound() -> void:
	var b := Body.new()
	var i: int = b.add_wound("arm_left", "laceration", 0.0)
	var steps: Array = Treatment.plan(b.wounds[i], {"bottle_spirit": 1, "bandage": 1})
	assert_eq(_ids(steps), ["disinfect", "bandage"])
	assert_eq(_states(steps), [Treatment.DO, Treatment.DO])
	assert_eq(steps[0]["tool"], "bottle_spirit")
	assert_eq(steps[1]["count"], 1)
	assert_eq(Treatment.runnable(steps).size(), 2)


func test_a_missing_tool_stops_the_run_and_is_named() -> void:
	var b := Body.new()
	var i: int = b.add_wound("arm_left", "laceration", 0.0)
	var steps: Array = Treatment.plan(b.wounds[i], {"bandage": 3})
	assert_eq(_states(steps), [Treatment.MISSING, Treatment.BLOCKED], "no spirit: nothing behind it is done either")
	assert_eq(steps[0]["need"], "소독할 술 없음")
	assert_true(Treatment.runnable(steps).is_empty())
	assert_true(Treatment.steps_text(steps).contains("소독할 술 없음"))


func test_first_aid_is_the_bandage_only() -> void:
	var b := Body.new()
	var i: int = b.add_wound("arm_left", "laceration", 0.0)
	var steps: Array = Treatment.plan(b.wounds[i], {"bandage": 1}, Treatment.FIRST_AID)
	assert_eq(_ids(steps), ["bandage"], "no cleaning in first aid")
	assert_eq(_states(steps), [Treatment.DO])
	# Nothing bleeding: nothing for first aid to do.
	b.bandage_wound(i)
	assert_eq(Treatment.plan(b.wounds[i], {"bandage": 1}, Treatment.FIRST_AID).size(), 0)
	var f: int = b.add_wound("leg_left", "fracture", 0.0)
	assert_eq(Treatment.plan(b.wounds[f], {"plank": 1}, Treatment.FIRST_AID).size(), 0, "a fracture does not bleed")


func test_a_heavy_wound_takes_two_bandages() -> void:
	var b := Body.new()
	var i: int = b.add_wound("torso", "deep", 0.0)
	var one: Array = Treatment.plan(b.wounds[i], {"bandage": 1}, Treatment.FIRST_AID)
	assert_eq(_states(one), [Treatment.MISSING])
	assert_eq(one[0]["need"], "붕대 2개 필요")
	var two: Array = Treatment.plan(b.wounds[i], {"bandage": 2}, Treatment.FIRST_AID)
	assert_eq(_states(two), [Treatment.DO])
	assert_eq(two[0]["count"], 2)
	assert_eq(Treatment.apply(b, i, "bandage"), 2)
	assert_almost_eq(float(b.wounds[i]["blood"]), Body.SEEP_BLOOD, 0.001, "it seeps on as a light one")
	assert_true(b.wounds[i]["bandaged"])


func test_stage_two_steps_read_as_missing_tools() -> void:
	var b := Body.new()
	var deep: int = b.add_wound("leg_right", "deep", 0.0)
	var steps: Array = Treatment.plan(b.wounds[deep], {"bandage": 5, "bottle_spirit": 2, "plank": 2})
	assert_eq(_ids(steps), ["tourniquet", "suture", "bandage"], "a limb: the tourniquet comes first")
	assert_eq(_states(steps), [Treatment.MISSING, Treatment.BLOCKED, Treatment.BLOCKED])
	assert_eq(steps[0]["need"], "지혈대 없음")
	var torso: int = b.add_wound("torso", "deep", 0.0)
	assert_eq(_ids(Treatment.plan(b.wounds[torso], {})), ["suture", "bandage"], "no tourniquet on the torso")
	var shot: int = b.add_wound("torso", "embedded", 0.0)
	var pull: Array = Treatment.plan(b.wounds[shot], {"bandage": 5, "bottle_spirit": 2})
	assert_eq(_ids(pull), ["pull", "disinfect", "bandage"])
	assert_eq(pull[0]["need"], "핀셋 없음")
	# First aid still stops the blood of both.
	assert_eq(_states(Treatment.plan(b.wounds[deep], {"bandage": 2}, Treatment.FIRST_AID)), [Treatment.DO])
	assert_eq(_states(Treatment.plan(b.wounds[shot], {"bandage": 2}, Treatment.FIRST_AID)), [Treatment.DO])


func test_a_fracture_takes_a_plank_or_wood() -> void:
	var b := Body.new()
	var i: int = b.add_wound("leg_left", "fracture", 0.0)
	assert_eq(_states(Treatment.plan(b.wounds[i], {})), [Treatment.MISSING])
	var steps: Array = Treatment.plan(b.wounds[i], {"wood": 1})
	assert_eq(steps[0]["tool"], "wood")
	assert_eq(Treatment.apply(b, i, "splint"), 1)
	assert_true(b.wounds[i]["splinted"])
	assert_eq(_states(Treatment.plan(b.wounds[i], {"wood": 1})), [Treatment.DONE])
	assert_eq(Treatment.apply(b, i, "splint"), 0, "not twice")


func test_done_steps_are_marked_and_skipped() -> void:
	var b := Body.new()
	var i: int = b.add_wound("arm_right", "scratch", 0.0)
	assert_eq(Treatment.apply(b, i, "disinfect"), 1)
	var steps: Array = Treatment.plan(b.wounds[i], {"bandage": 1})
	assert_eq(_states(steps), [Treatment.DONE, Treatment.DO], "cleaned already: only the bandage is left, and no spirit is needed")
	assert_eq(Treatment.apply(b, i, "bandage"), 1)
	assert_eq(_states(Treatment.plan(b.wounds[i], {})), [Treatment.DONE, Treatment.DONE])
	assert_eq(b.bleed_level(), 0)


func test_bandage_wound_dresses_the_one_chosen_not_the_worst() -> void:
	var b := Body.new()
	var worst: int = b.add_wound("torso", "laceration", 0.0)
	var small: int = b.add_wound("arm_left", "scratch", 0.0)
	assert_eq(b.bandage_wound(small), 1)
	assert_eq(float(b.wounds[small]["blood"]), 0.0)
	assert_gt(float(b.wounds[worst]["blood"]), 0.0, "the other one is left as it was")
	assert_eq(b.bandage_wound(small), 0, "nothing more to dress there")
	assert_eq(b.bandage_wound(99), 0)


func test_index_of_is_by_identity() -> void:
	var b := Body.new()
	b.add_wound("arm_left", "scratch", 0.0)
	b.add_wound("arm_left", "scratch", 0.0)
	assert_eq(b.index_of(b.wounds[1]), 1, "two wounds that read the same are still two")
	assert_eq(b.index_of(b.wounds[1].duplicate()), -1)


func test_the_wound_line_reads_part_kind_and_blood() -> void:
	var b := Body.new()
	var i: int = b.add_wound("leg_left", "laceration", 0.0)
	assert_eq(Treatment.wound_text(b.wounds[i]), "왼다리 찢김 · 피 보통")
	b.bandage_wound(i)
	assert_eq(Treatment.wound_text(b.wounds[i]), "왼다리 찢김 · 피 멎음 · 붕대 감음")
	var f: int = b.add_wound("arm_right", "fracture", 0.0)
	assert_eq(Treatment.wound_text(b.wounds[f]), "오른팔 골절 · 부목 없음")
	for part: String in Body.PARTS:
		assert_true(Treatment.PART_NAMES.has(part), part)
	for kind: String in Body.KINDS:
		assert_true(Treatment.KIND_NAMES.has(kind), kind)
		assert_true(Treatment.ORDER.has(kind), kind)


func test_a_medic_is_quicker() -> void:
	var step: Dictionary = Treatment.plan({"part": "torso", "kind": "bite", "blood": 0.4, "disinfected": false, "bandaged": false, "splinted": false, "festering": false}, {"bandage": 1})[0]
	assert_almost_eq(Treatment.seconds(step, "none"), 4.0, 0.001)
	assert_lt(Treatment.seconds(step, "skilled"), 4.0)
