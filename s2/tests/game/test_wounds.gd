extends "res://addons/gut/test.gd"
## Per-part wounds (body_injury 4.6, stage 1): the list is the source, old fields read from it.

const Body = preload("res://game/sim/body_state.gd")
const Receipt = preload("res://game/sim/receipt.gd")
const FieldGame = preload("res://game/field_game.gd")

const IDLE := {"running": false, "swinging": false, "carry_state": 0, "cold_level": 0, "indoor_rest": false}

var game


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _field() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()


# --- the list ---

func test_names_match_the_receipt_schema() -> void:
	assert_eq(Body.PARTS, Receipt.WOUND_PARTS)
	assert_eq(Body.KINDS, Receipt.WOUND_KINDS)


func test_add_wound_stores_the_fields_and_refuses_unknown_names() -> void:
	var b := Body.new()
	assert_eq(b.add_wound("arm_left", "scratch", 12.0), 0)
	assert_eq(b.wounds.size(), 1)
	var w: Dictionary = b.wounds[0]
	assert_eq(w["part"], "arm_left")
	assert_eq(w["kind"], "scratch")
	assert_almost_eq(float(w["blood"]), 0.15, 0.0001)
	assert_false(w["disinfected"])
	assert_false(w["bandaged"])
	assert_false(w["splinted"])
	assert_false(w["festering"])
	assert_eq(w["at"], 12.0)
	assert_eq(b.add_wound("hand_left", "scratch", 0.0), -1)
	assert_eq(b.add_wound("torso", "burn", 0.0), -1)
	assert_eq(b.wounds.size(), 1)


func test_each_kind_has_a_start_blood() -> void:
	var b := Body.new()
	for kind: String in Body.KINDS:
		b.add_wound("torso", kind, 0.0)
	var blood := {}
	for w: Dictionary in b.wounds:
		blood[w["kind"]] = w["blood"]
	assert_eq(blood["fracture"], 0.0)
	assert_gt(blood["scratch"], 0.0)
	assert_gt(blood["laceration"], blood["scratch"])
	assert_gte(blood["deep"], Body.HEAVY_BLOOD)


# --- computed bleed ---

func test_bleed_is_the_total_of_all_wounds() -> void:
	var b := Body.new()
	assert_eq(b.bleed, 0)
	b.add_wound("arm_left", "scratch", 0.0)
	assert_eq(b.bleed, 1)
	b.add_wound("leg_left", "laceration", 0.0)
	b.add_wound("torso", "laceration", 0.0)
	assert_eq(b.bleed, 1, "0.15 + 0.4 + 0.4 stays light")
	b.add_wound("head_neck", "laceration", 0.0)
	assert_eq(b.bleed, 2, "the total passes 1.0")
	var c := Body.new()
	c.add_wound("leg_right", "deep", 0.0)
	assert_eq(c.bleed, 2)
	var d := Body.new()
	d.add_wound("torso", "fracture", 0.0)
	assert_eq(d.bleed, 0, "a fracture does not bleed")


func test_light_bleed_stop_closes_the_blood_but_keeps_the_wounds() -> void:
	var b := Body.new()
	b.add_wound("arm_right", "laceration", 0.0)
	b.add_wound("torso", "scratch", 0.0)
	var ev: Array = []
	for _i in range(240):
		ev.append_array(b.tick(1.0, IDLE))
	assert_true(ev.has("bleed_stopped"))
	assert_eq(b.bleed, 0)
	assert_eq(b.wounds.size(), 2)


func test_bleed_drop_below_heavy_resets_the_heavy_timers() -> void:
	var b := Body.new()
	b.add_wound("torso", "deep", 0.0)
	for _i in range(130):
		b.tick(1.0, IDLE)
	assert_true(b.downed)
	assert_true(b.bandage(2))
	assert_false(b.downed)
	assert_eq(b.heavy_bleed_time, 0.0)
	assert_eq(b.down_time, 0.0)


# --- computed fractures and splints ---

func test_fracture_reads_from_the_part() -> void:
	var b := Body.new()
	assert_false(b.arm_fracture)
	assert_false(b.leg_fracture)
	b.add_wound("arm_left", "fracture", 0.0)
	assert_true(b.arm_fracture)
	assert_false(b.leg_fracture)
	b.add_wound("leg_right", "fracture", 0.0)
	assert_true(b.leg_fracture)
	assert_eq(b.bleed, 0)
	var m: Dictionary = b.multipliers({})
	assert_true(m["one_hand"])
	assert_almost_eq(float(m["move"]), 0.25, 0.0001, "unsplinted leg crawls")


func test_old_fracture_call_takes_the_free_side() -> void:
	var b := Body.new()
	b.fracture(true)
	b.fracture(true)
	var parts: Array = []
	for w: Dictionary in b.wounds:
		parts.append(w["part"])
	parts.sort()
	assert_eq(parts, ["arm_left", "arm_right"])
	b.fracture(false, "leg_right")
	assert_eq(b.wounds[2]["part"], "leg_right")


func test_splint_goes_to_one_broken_limb_legs_first() -> void:
	var b := Body.new()
	b.add_wound("arm_left", "fracture", 0.0)
	b.add_wound("leg_left", "fracture", 0.0)
	b.splint()
	assert_true(b.wounds[1]["splinted"], "the leg first")
	assert_false(b.wounds[0]["splinted"])
	assert_false(b.splinted, "the arm still has no splint")
	assert_true(b.fractures_splinted("leg"))
	assert_almost_eq(float(b.multipliers({})["move"]), 0.6, 0.0001, "a splinted leg limps")
	b.splint()
	assert_true(b.splinted)
	b.splint()
	assert_true(b.splinted, "nothing left to splint changes nothing")


func test_a_new_fracture_does_not_undo_another_splint() -> void:
	var b := Body.new()
	b.add_wound("leg_left", "fracture", 0.0)
	b.splint()
	b.add_wound("arm_right", "fracture", 0.0)
	assert_true(b.fractures_splinted("leg"))
	assert_false(b.splinted)


# --- treatment lands on the most urgent wound ---

func test_most_urgent_is_blood_then_festering_then_fracture() -> void:
	var b := Body.new()
	assert_eq(b.most_urgent(), -1)
	b.add_wound("arm_left", "fracture", 0.0)
	assert_eq(b.most_urgent(), 0)
	b.add_wound("torso", "scratch", 0.0)
	b.wounds[1]["blood"] = 0.0
	b.set_festering(1, true)
	assert_eq(b.most_urgent(), 1, "festering before a fracture")
	b.add_wound("leg_left", "laceration", 0.0)
	assert_eq(b.most_urgent(), 2, "blood before festering")
	b.add_wound("leg_right", "deep", 0.0)
	assert_eq(b.most_urgent(), 3, "the most blood first")


func test_bandage_dresses_the_wound_that_bleeds_most() -> void:
	var b := Body.new()
	b.add_wound("arm_right", "scratch", 0.0)
	b.add_wound("leg_left", "deep", 0.0)
	assert_false(b.bandage(1), "a deep wound needs two bandages")
	assert_eq(b.bleed, 2)
	assert_true(b.bandage(2))
	assert_true(b.wounds[1]["bandaged"])
	assert_true(b.wounds[1]["blood"] > 0.0, "a plain bandage seeps on")
	assert_false(b.wounds[0]["bandaged"], "the scratch was not the urgent one")
	assert_eq(b.bleed, 1)


func test_one_bandage_stops_one_light_wound() -> void:
	var b := Body.new()
	b.add_wound("arm_left", "laceration", 0.0)
	b.add_wound("leg_left", "laceration", 0.0)
	assert_true(b.bandage(1))
	var dressed := 0
	for w: Dictionary in b.wounds:
		if w["bandaged"]:
			dressed += 1
	assert_eq(dressed, 1)
	assert_eq(b.bleed, 1)
	assert_true(b.bandage(1))
	assert_eq(b.bleed, 0)
	assert_false(b.bandage(1))


func test_a_bandage_with_a_spare_goes_on_to_the_next_light_wound() -> void:
	var b := Body.new()
	b.add_wound("arm_left", "laceration", 0.0)
	b.add_wound("leg_left", "scratch", 0.0)
	assert_true(b.bandage(2))
	assert_eq(b.bleed, 0)


func test_three_cuts_heavy_bandage_steps_down_one_level() -> void:
	var b := Body.new()
	for part: String in ["arm_left", "arm_right", "torso"]:
		b.add_wound(part, "laceration", 0.0)
	assert_eq(b.bleed, 2)
	assert_true(b.bandage(1))
	assert_eq(b.bleed, 1)


func test_kit_stops_every_bleeding_wound_and_leaves_fractures() -> void:
	var b := Body.new()
	assert_false(b.use_kit())
	b.add_wound("torso", "deep", 0.0)
	b.add_wound("arm_left", "laceration", 0.0)
	b.add_wound("leg_left", "fracture", 0.0)
	assert_true(b.use_kit())
	assert_eq(b.bleed, 0)
	assert_true(b.leg_fracture)
	assert_false(b.splinted)


func test_disinfect_marks_the_most_urgent_open_wound() -> void:
	var b := Body.new()
	assert_false(b.disinfect())
	b.add_wound("arm_left", "scratch", 0.0)
	b.add_wound("leg_left", "laceration", 0.0)
	b.add_wound("torso", "fracture", 0.0)
	assert_true(b.disinfect())
	assert_true(b.wounds[1]["disinfected"], "the bigger flow first")
	assert_true(b.disinfect())
	assert_true(b.wounds[0]["disinfected"])
	assert_false(b.disinfect(), "a fracture is not cleaned")
	assert_false(b.disinfect(2))


# --- old callers ---

func test_old_apply_calls_add_wounds() -> void:
	var b := Body.new()
	b.apply_bite(_rng(1), "arm", 5.0)
	assert_eq(b.wounds[0]["kind"], "bite")
	assert_eq(b.wounds[0]["part"], "arm_left", "a coarse arm becomes the lighter side")
	assert_eq(b.bite_part, "arm")
	b.apply_bite(_rng(1), "leg_right", 6.0)
	assert_eq(b.wounds[1]["part"], "leg_right")
	assert_eq(b.bite_part, "leg", "the latest bite")
	b.apply_scratch(_rng(2), 7.0, "arm_right")
	assert_eq(b.wounds[2]["kind"], "scratch")
	assert_eq(b.wounds[2]["part"], "arm_right")
	b.apply_cut(false, 8.0, "head_neck")
	assert_eq(b.wounds[3]["kind"], "laceration")
	b.apply_cut(true, 9.0)
	assert_eq(b.wounds[4]["kind"], "deep")
	assert_eq(b.wounds[4]["part"], "torso", "no part given: torso")
	assert_eq(b.injured_at, 9.0)


func test_gunshot_leaves_a_bullet_and_a_leg_shot_breaks_that_leg() -> void:
	var r := _rng(8)
	var legs := 0
	for _i in range(400):
		var b := Body.new()
		var part: String = b.apply_gunshot(r, 0.0)
		assert_eq(b.wounds[0]["kind"], "embedded")
		assert_eq(b.bleed, 2)
		if part == "leg":
			legs += 1
			assert_eq(b.wounds.size(), 2)
			assert_eq(b.wounds[1]["kind"], "fracture")
			assert_eq(b.wounds[1]["part"], b.wounds[0]["part"])
			assert_true(String(b.wounds[0]["part"]).begins_with("leg_"))
			assert_true(b.leg_fracture)
		else:
			assert_eq(b.wounds.size(), 1)
			assert_eq(b.wounds[0]["part"], "torso")
	assert_gt(legs, 60)
	assert_lt(legs, 140)


func test_part_pickers_stay_on_their_parts() -> void:
	var r := _rng(3)
	var seen := {}
	for _i in range(300):
		var part: String = Body.pick_part(r)
		assert_true(Body.PARTS.has(part))
		seen[part] = true
		assert_has(["torso", "arm_left", "arm_right"], Body.pick_scratch_part(r))
		assert_has(["arm_left", "arm_right"], Body.pick_side(r, "arm"))
		assert_has(["leg_left", "leg_right"], Body.pick_side(r, "leg"))
	assert_eq(seen.size(), 6)
	assert_eq(Body.pick_side(r, "torso"), "torso")
	assert_eq(Body.coarse("arm_left"), "arm")
	assert_eq(Body.coarse("head_neck"), "head_neck")


# --- writing the old fields still works ---

func test_old_field_writes_keep_the_list_in_step() -> void:
	var b := Body.new()
	b.bleed = 2
	assert_eq(b.bleed, 2)
	assert_eq(b.wounds.size(), 1)
	b.bleed = 1
	assert_eq(b.bleed, 1)
	b.bleed = 0
	assert_eq(b.bleed, 0)
	b.arm_fracture = true
	assert_true(b.arm_fracture)
	b.arm_fracture = true
	assert_eq(b.wounds.size(), 2, "one more only for the fracture")
	b.leg_fracture = true
	b.splinted = true
	assert_true(b.splinted)
	b.splinted = false
	assert_false(b.splinted)
	b.arm_fracture = false
	assert_false(b.arm_fracture)
	assert_true(b.leg_fracture)


# --- receipt rows ---

func test_receipt_wounds_lists_part_kind_and_festering_only_when_set() -> void:
	var b := Body.new()
	b.add_wound("arm_left", "scratch", 0.0)
	b.add_wound("torso", "bite", 0.0)
	b.set_festering(1, true)
	assert_eq(b.receipt_wounds(), [{"part": "arm_left", "kind": "scratch"}, {"part": "torso", "kind": "bite", "festering": true}])
	assert_true(b.has_bite_wound())
	assert_false(b.has_serious_wound())
	b.add_wound("leg_left", "fracture", 0.0)
	assert_true(b.has_serious_wound())


# --- in the field ---

func test_a_fall_that_breaks_a_leg_adds_a_leg_fracture_wound() -> void:
	_field()
	var p = game.squad[1]
	game.combat.fall(p, "미끄러져", 1.0, true)
	assert_eq(p.body.wounds.size(), 1)
	assert_eq(p.body.wounds[0]["kind"], "fracture")
	assert_has(["leg_left", "leg_right"], p.body.wounds[0]["part"])
	assert_true(p.body.leg_fracture)
	var q = game.squad[2]
	game.combat.fall(q, "미끄러져", 1.0, false)
	assert_has(["arm_left", "arm_right"], q.body.wounds[0]["part"])


func test_a_bite_lands_on_a_part_and_keeps_the_coarse_place() -> void:
	_field()
	var p = game.squad[1]
	game.combat.bite(p)
	assert_eq(p.body.wounds.size(), 1)
	assert_eq(p.body.wounds[0]["kind"], "bite")
	assert_true(Body.PARTS.has(p.body.wounds[0]["part"]))
	assert_has(["arm", "torso", "leg"], p.body.bite_part)
	assert_eq(p.body.infection, "bite")


func test_wound_picking_does_not_touch_the_fight_rolls() -> void:
	_field()
	var before: int = game.rng.randi()
	var other := FieldGame.new()
	other.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(other)
	other.set_process(false)
	for _i in range(20):
		other.combat.wound_side("arm")
	assert_eq(other.rng.randi(), before, "same seed, same next roll")


func test_the_receipt_gets_the_wounds_of_each_person() -> void:
	_field()
	var a = game.squad[1]
	var c = game.squad[2]
	a.body.add_wound("arm_left", "bite", 0.0)
	a.body.add_wound("leg_right", "fracture", 0.0)
	c.body.add_wound("torso", "scratch", 0.0)
	var got: Array = []
	game.finished.connect(func(r): got.append(r))
	game.finish("departed")
	var d: Dictionary = got[0]["receipt"]
	assert_eq(d["version"], 2)
	var rows: Array = d["people"]["wounds"]
	assert_eq(rows.size(), 3)
	assert_has(rows, {"person": a.pid, "part": "arm_left", "kind": "bite"})
	assert_has(rows, {"person": a.pid, "part": "leg_right", "kind": "fracture"})
	assert_has(rows, {"person": c.pid, "part": "torso", "kind": "scratch"})
	assert_has(d["people"]["bitten"], a.pid)
	assert_has(d["people"]["injured"], a.pid)
	assert_false(d["people"]["injured"].has(c.pid))
	assert_eq(Receipt.check(d), [] as Array[String])
	assert_eq(Receipt.fold_gaps(d), [] as Array[String])
	var parsed: Variant = JSON.parse_string(got[0]["receipt_json"])
	assert_eq(Receipt.check(parsed), [] as Array[String])


func test_no_wounds_keeps_the_receipt_at_version_one() -> void:
	_field()
	var got: Array = []
	game.finished.connect(func(r): got.append(r))
	game.finish("departed")
	var d: Dictionary = got[0]["receipt"]
	assert_false(d.has("version"))
	assert_false(d["people"].has("wounds"))
	assert_eq(Receipt.check(d), [] as Array[String])


# --- PR 69 review (PC, 2026-10-10) ---

func test_a_deep_leg_wound_stops_running_without_a_fracture() -> void:
	var b := Body.new()
	assert_true(b.can_run())
	b.apply_cut(true, 0.0, "leg_left")
	assert_false(b.leg_fracture)
	assert_false(b.can_run(), "deep leg wound: no running")


func test_a_deep_arm_wound_still_lets_you_run() -> void:
	var b := Body.new()
	b.apply_cut(true, 0.0, "arm_left")
	assert_true(b.can_run())


func test_a_head_hit_puts_the_round_in_the_head() -> void:
	for s in range(1, 30):
		var b := Body.new()
		var part: String = b.apply_gunshot(_rng(s), 0.0, "head")
		assert_eq(part, "head")
		assert_eq(b.wounds[0]["part"], "head_neck", "seed %d" % s)
		assert_eq(b.wounds.size(), 1, "no leg fracture from a head hit")


func test_a_body_hit_still_rolls_torso_or_leg() -> void:
	var legs := 0
	for s in range(1, 200):
		var b := Body.new()
		var part: String = b.apply_gunshot(_rng(s), 0.0, "body")
		assert_true(part in ["torso", "leg"])
		legs += 1 if part == "leg" else 0
	assert_gt(legs, 0)


func test_an_infected_scratch_goes_back_as_bitten() -> void:
	_field()
	var c = game.squad[2]
	c.body.add_wound("torso", "scratch", 0.0)
	c.body.infection = "scratch"
	c.body.infected = true
	c.body.window_left = 380.0
	var got: Array = []
	game.finished.connect(func(r): got.append(r))
	game.finish("departed")
	assert_has(got[0]["receipt"]["people"]["bitten"], c.pid)


func test_a_clean_scratch_does_not_go_back_as_bitten() -> void:
	_field()
	var c = game.squad[2]
	c.body.add_wound("torso", "scratch", 0.0)
	c.body.infection = "scratch"
	c.body.infected = false
	var got: Array = []
	game.finished.connect(func(r): got.append(r))
	game.finish("departed")
	assert_false(got[0]["receipt"]["people"]["bitten"].has(c.pid))


func test_bandage_reports_what_it_really_used() -> void:
	var b := Body.new()
	for i in range(3):
		b.add_wound("arm_left", "laceration", 0.0)
	b.bandage(2)
	assert_eq(b.last_bandages_used, 1, "a heavy total stops after one light wound drops it below heavy")
	var c := Body.new()
	c.add_wound("torso", "deep", 0.0)
	c.bandage(2)
	assert_eq(c.last_bandages_used, 2)


func test_treating_takes_only_the_bandages_wound_on() -> void:
	_field()
	var medic = game.squad[1]
	var o = game.squad[2]
	for i in range(3):
		o.body.add_wound("arm_left", "laceration", 0.0)
	medic.items["bandage"] = 3
	medic.medical = "none"
	game.actions._treated(medic, o, medic, true)
	assert_eq(int(medic.items.get("bandage", 0)), 3 - o.body.last_bandages_used)
	assert_eq(int(medic.items.get("bandage", 0)), 2, "one used, two kept")


func test_ai_bandaging_takes_only_what_was_used() -> void:
	_field()
	var giver = game.squad[1]
	var who = game.squad[2]
	for i in range(3):
		who.body.add_wound("arm_left", "laceration", 0.0)
	giver.items["bandage"] = 2
	game.ai._use_bandage(giver, who, 2)
	assert_eq(int(giver.items.get("bandage", 0)), 1)


func test_a_dressed_heavy_wound_seeps_on_for_the_full_time() -> void:
	var b := Body.new()
	b.add_wound("arm_left", "laceration", 0.0)
	b.tick(Body.LIGHT_BLEED_STOP - 1.0, IDLE)
	b.add_wound("leg_left", "deep", 0.0)
	assert_eq(b.bleed_level(), 2)
	b.bandage(2)
	assert_eq(b.bleed_level(), 1, "the deep one seeps")
	b.tick(1.5, IDLE)
	assert_eq(b.bleed_level(), 1, "the old light-bleed clock did not stop it at once")


func test_a_closed_window_is_not_reopened_by_a_new_bite() -> void:
	var b := Body.new()
	b.apply_bite(_rng(1), "arm", 0.0)
	b.window_left = 0.0
	b.apply_bite(_rng(2), "leg", 10.0)
	assert_eq(b.window_left, 0.0)
	b.apply_scratch(_rng(3), 20.0)
	assert_eq(b.window_left, 0.0, "nor by a scratch")


func test_a_first_bite_still_opens_the_window() -> void:
	var b := Body.new()
	b.apply_bite(_rng(1), "arm", 0.0)
	assert_eq(b.window_left, Body.WINDOW)
