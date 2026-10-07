extends "res://addons/gut/test.gd"

const Body = preload("res://game/sim/body_state.gd")

const IDLE := {"running": false, "swinging": false, "carry_state": 0, "cold_level": 0, "indoor_rest": false}
const RUN := {"running": true, "swinging": false, "carry_state": 0, "cold_level": 0, "indoor_rest": false}


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _ticks(b: Body, seconds: float, ctx: Dictionary, step: float = 1.0) -> Array:
	var ev: Array = []
	var t := 0.0
	while t < seconds - 0.0001:
		ev.append_array(b.tick(step, ctx))
		t += step
	return ev


# --- wounds and infection ---

func test_bite_sets_window_and_certain_infection() -> void:
	var b := Body.new()
	b.apply_bite(_rng(1), "arm", 30.0)
	assert_eq(b.bleed, 1)
	assert_eq(b.infection, "bite")
	assert_true(b.infected)
	assert_eq(b.window_left, 480.0)
	assert_eq(b.bite_part, "arm")
	assert_eq(b.injured_at, 30.0)


func test_scratch_infects_about_ten_percent() -> void:
	var r := _rng(42)
	var infected := 0
	for _i in range(3000):
		var b := Body.new()
		b.apply_scratch(r, 0.0)
		assert_eq(b.infection, "scratch")
		assert_eq(b.window_left, 480.0)
		if b.infected:
			infected += 1
	assert_between(infected / 3000.0, 0.08, 0.12)


func test_second_scratch_keeps_shorter_window_and_bite_wins() -> void:
	var b := Body.new()
	b.apply_scratch(_rng(1), 0.0)
	_ticks(b, 100.0, IDLE)
	b.apply_scratch(_rng(2), 100.0)
	assert_almost_eq(b.window_left, 380.0, 0.0001)
	b.apply_bite(_rng(3), "leg", 120.0)
	assert_eq(b.infection, "bite")
	b.apply_scratch(_rng(4), 130.0)
	assert_eq(b.infection, "bite")
	assert_true(b.infected)


func test_bite_after_uninfected_scratch_gets_full_window() -> void:
	var b := Body.new()
	b.apply_scratch(_rng(1), 0.0)
	b.infected = false
	_ticks(b, 100.0, IDLE)
	b.apply_bite(_rng(2), "arm", 100.0)
	assert_eq(b.window_left, 480.0)
	var c := Body.new()
	c.apply_scratch(_rng(1), 0.0)
	c.infected = true
	_ticks(c, 100.0, IDLE)
	c.apply_bite(_rng(2), "arm", 100.0)
	assert_almost_eq(c.window_left, 380.0, 0.0001)


func test_window_closes_once_and_clean_scratch_clears() -> void:
	var b := Body.new()
	b.apply_scratch(_rng(1), 0.0)
	b.infected = false
	var ev := _ticks(b, 479.0, IDLE)
	assert_false(ev.has("window_closed"))
	ev = _ticks(b, 2.0, IDLE)
	assert_eq(ev.count("window_closed"), 1)
	assert_eq(b.infection, "")
	assert_eq(b.window_left, 0.0)
	var bit := Body.new()
	bit.apply_bite(_rng(1), "torso", 0.0)
	ev = _ticks(bit, 600.0, IDLE)
	assert_eq(ev.count("window_closed"), 1)
	assert_eq(bit.infection, "bite")


# --- bleeding ---

func test_light_bleed_stops_after_240_unless_running() -> void:
	var b := Body.new()
	b.apply_cut(false, 0.0)
	var ev := _ticks(b, 239.0, IDLE)
	assert_eq(b.bleed, 1)
	assert_false(ev.has("bleed_stopped"))
	ev = _ticks(b, 1.0, IDLE)
	assert_true(ev.has("bleed_stopped"))
	assert_eq(b.bleed, 0)
	var r := Body.new()
	r.apply_cut(false, 0.0)
	_ticks(r, 500.0, RUN)
	assert_eq(r.bleed, 1)


func test_new_light_wound_resets_light_timer() -> void:
	var b := Body.new()
	b.apply_cut(false, 0.0)
	_ticks(b, 200.0, IDLE)
	b.apply_cut(false, 200.0)
	_ticks(b, 200.0, IDLE)
	assert_eq(b.bleed, 1)


func test_heavy_bleed_downs_at_120_and_kills_60_later() -> void:
	var b := Body.new()
	b.apply_cut(true, 0.0)
	var ev := _ticks(b, 119.0, IDLE)
	assert_false(b.downed)
	ev = _ticks(b, 1.0, IDLE)
	assert_true(ev.has("downed"))
	assert_true(b.downed)
	ev = _ticks(b, 59.0, IDLE)
	assert_false(b.dead)
	ev = _ticks(b, 1.0, IDLE)
	assert_true(ev.has("died"))
	assert_true(b.dead)
	assert_eq(b.tick(1.0, IDLE), [])


func test_two_bandages_save_a_downed_person() -> void:
	var b := Body.new()
	b.apply_cut(true, 0.0)
	_ticks(b, 150.0, IDLE)
	assert_true(b.downed)
	assert_false(b.bandage(1))
	assert_eq(b.bleed, 2)
	assert_true(b.bandage(2))
	assert_eq(b.bleed, 1)
	assert_false(b.downed)
	assert_eq(b.heavy_bleed_time, 0.0)
	assert_true(b.bandage())
	assert_eq(b.bleed, 0)
	assert_false(b.bandage())


func test_kit_stops_any_bleed() -> void:
	var b := Body.new()
	assert_false(b.use_kit())
	b.apply_cut(true, 0.0)
	assert_true(b.use_kit())
	assert_eq(b.bleed, 0)


func test_gunshot_heavy_leg_and_second_shot_downs() -> void:
	var r := _rng(8)
	var legs := 0
	for _i in range(2000):
		var b := Body.new()
		var part: String = b.apply_gunshot(r, 0.0)
		assert_eq(b.bleed, 2)
		assert_false(b.downed)
		if part == "leg":
			legs += 1
			assert_true(b.leg_fracture)
		else:
			assert_eq(part, "torso")
	assert_between(legs / 2000.0, 0.22, 0.28)
	var c := Body.new()
	c.apply_gunshot(r, 0.0)
	c.apply_gunshot(r, 5.0)
	assert_true(c.downed)
	var ev := _ticks(c, 60.0, IDLE)
	assert_true(ev.has("died"))


func test_cut_does_not_lower_bleed() -> void:
	var b := Body.new()
	b.apply_cut(true, 0.0)
	b.apply_cut(false, 1.0)
	assert_eq(b.bleed, 2)
	assert_eq(b.injured_at, 1.0)


func test_quick_treat_window() -> void:
	var b := Body.new()
	assert_false(b.quick_treat_ok(0.0))
	b.apply_cut(true, 100.0)
	assert_true(b.quick_treat_ok(220.0))
	assert_false(b.quick_treat_ok(220.1))


func test_splint() -> void:
	var b := Body.new()
	b.splint()
	assert_false(b.splinted)
	b.fracture(false)
	assert_true(b.leg_fracture)
	b.splint()
	assert_true(b.splinted)


# --- exhaustion and breath ---

func test_running_fatigue_and_multipliers() -> void:
	var b := Body.new()
	_ticks(b, 100.0, RUN)
	assert_almost_eq(b.exhaustion, 0.4, 0.0001)
	var c := Body.new()
	var heavy := RUN.duplicate()
	heavy["carry_state"] = 2
	heavy["cold_level"] = 1
	_ticks(c, 50.0, heavy)
	assert_almost_eq(c.exhaustion, 0.004 * 50.0 * 1.6 * 1.25, 0.0001)
	assert_almost_eq(Body.fatigue_mult({"carry_state": 1, "cold_level": 0}), 1.0, 0.0001)


func test_add_fatigue_and_levels() -> void:
	var b := Body.new()
	assert_eq(b.exhaustion_level(), 0)
	b.add_fatigue(0.49)
	assert_eq(b.exhaustion_level(), 0)
	b.add_fatigue(0.01)
	assert_eq(b.exhaustion_level(), 1)
	b.add_fatigue(0.3)
	assert_eq(b.exhaustion_level(), 2)
	b.add_fatigue(5.0)
	assert_eq(b.exhaustion, 1.0)
	b.add_fatigue(-5.0)
	assert_eq(b.exhaustion, 0.0)


func test_exhausted_heavy_event_once() -> void:
	var b := Body.new()
	b.add_fatigue(0.79)
	var ev := _ticks(b, 20.0, RUN)
	assert_eq(ev.count("exhausted_heavy"), 1)


func test_indoor_rest_recovers() -> void:
	var b := Body.new()
	b.add_fatigue(0.9)
	var rest := IDLE.duplicate()
	rest["indoor_rest"] = true
	_ticks(b, 60.0, rest)
	assert_almost_eq(b.exhaustion, 0.4, 0.0001)
	_ticks(b, 60.0, IDLE)
	assert_almost_eq(b.exhaustion, 0.4, 0.0001)
	_ticks(b, 120.0, rest)
	assert_eq(b.exhaustion, 0.0)


func test_breath_runs_out_and_recovers() -> void:
	var b := Body.new()
	_ticks(b, 5.0, RUN)
	assert_almost_eq(b.breath, 0.4, 0.0001)
	assert_true(b.can_run())
	_ticks(b, 3.0, RUN)
	assert_false(b.can_run())
	_ticks(b, 2.0, IDLE)
	assert_almost_eq(b.breath, 0.54, 0.0001)
	var swing := IDLE.duplicate()
	swing["swinging"] = true
	_ticks(b, 2.0, swing)
	assert_almost_eq(b.breath, 0.54, 0.0001)
	_ticks(b, 10.0, IDLE)
	assert_eq(b.breath, 1.0)


func test_can_run_blockers() -> void:
	var b := Body.new()
	assert_true(b.can_run())
	b.leg_fracture = true
	assert_false(b.can_run())
	b.leg_fracture = false
	b.exhaustion = 0.8
	assert_false(b.can_run())
	b.exhaustion = 0.0
	b.breath = 0.15
	assert_false(b.can_run())
	b.breath = 1.0
	b.downed = true
	assert_false(b.can_run())


# --- 4.2 multipliers ---

func test_multipliers_neutral() -> void:
	var m: Dictionary = Body.new().multipliers({})
	for k: String in ["move", "swing", "aim_min", "reload", "swap", "hands", "shove_window"]:
		assert_eq(m[k], 1.0, k)
	assert_false(m["one_hand"])


func test_multipliers_carry_and_strength() -> void:
	var b := Body.new()
	assert_almost_eq(b.multipliers({"carry_state": 1})["move"], 0.9, 0.0001)
	var m2: Dictionary = b.multipliers({"carry_state": 2})
	assert_almost_eq(m2["move"], 0.7, 0.0001)
	assert_almost_eq(m2["swing"], 0.85, 0.0001)
	assert_almost_eq(m2["shove_window"], 0.8, 0.0001)
	var strong: Dictionary = b.multipliers({"carry_state": 2, "strength": 7})
	assert_almost_eq(strong["move"], 0.85, 0.0001)
	assert_almost_eq(strong["swing"], 0.925, 0.0001)
	assert_eq(b.multipliers({"carry_state": 3})["move"], 0.0)


func test_multipliers_exhaustion() -> void:
	var b := Body.new()
	b.exhaustion = 0.6
	var m1: Dictionary = b.multipliers({})
	assert_almost_eq(m1["swing"], 0.9, 0.0001)
	assert_almost_eq(m1["hands"], 0.9, 0.0001)
	assert_lt(m1["aim_shrink"], 1.0)
	assert_eq(m1["aim_min"], 1.0)
	b.exhaustion = 0.9
	var m2: Dictionary = b.multipliers({})
	assert_almost_eq(m2["swing"], 0.75, 0.0001)
	assert_almost_eq(m2["shove_window"], 0.8, 0.0001)
	assert_almost_eq(m2["aim_min"], 1.4, 0.0001)
	var s2: Dictionary = b.multipliers({"strength": 8})
	assert_almost_eq(s2["swing"], 0.875, 0.0001)
	assert_almost_eq(s2["aim_min"], 1.2, 0.0001)


func test_multipliers_injuries() -> void:
	var b := Body.new()
	b.bleed = 2
	var m: Dictionary = b.multipliers({})
	assert_almost_eq(m["move"], 0.8, 0.0001)
	assert_almost_eq(m["aim_min"], 1.4, 0.0001)
	b.bleed = 0
	b.arm_fracture = true
	m = b.multipliers({})
	assert_almost_eq(m["reload"], 0.6, 0.0001)
	assert_almost_eq(m["swap"], 0.7, 0.0001)
	assert_almost_eq(m["hands"], 0.5, 0.0001)
	assert_almost_eq(m["shove_window"], 0.7, 0.0001)
	assert_true(m["one_hand"])
	b.arm_fracture = false
	b.leg_fracture = true
	b.splinted = true
	m = b.multipliers({})
	assert_almost_eq(m["move"], 0.6, 0.0001)
	b.splinted = false
	assert_almost_eq(b.multipliers({})["move"], 0.25, 0.0001)


func test_multipliers_cold_stacks_and_gear() -> void:
	var b := Body.new()
	var c1: Dictionary = b.multipliers({"cold_level": 1})
	assert_almost_eq(c1["move"], 0.95, 0.0001)
	assert_almost_eq(c1["reload"], 0.9, 0.0001)
	assert_eq(c1["aim_min"], 1.0)
	var c2: Dictionary = b.multipliers({"cold_level": 2})
	assert_almost_eq(c2["aim_min"], 1.4, 0.0001)
	assert_almost_eq(c2["reload"], 0.72, 0.0001)
	var c3: Dictionary = b.multipliers({"cold_level": 3})
	assert_almost_eq(c3["move"], 0.95 * 0.85, 0.0001)
	assert_almost_eq(c3["reload"], 0.54, 0.0001)
	assert_true(c3["hands"] <= c2["hands"])
	var g: Dictionary = b.multipliers({"gloves": true, "heavy_coat": true})
	assert_almost_eq(g["reload"], 0.9, 0.0001)
	assert_almost_eq(g["move"], 0.85, 0.0001)
	assert_almost_eq(g["swing"], 0.9, 0.0001)
	var p: Dictionary = b.multipliers({"panic": true})
	assert_almost_eq(p["aim_min"], 1.4, 0.0001)
	assert_almost_eq(p["hands"], 0.6, 0.0001)


func test_multipliers_floor_and_cap() -> void:
	var b := Body.new()
	b.arm_fracture = true
	b.bleed = 2
	b.exhaustion = 0.9
	b.leg_fracture = true
	var m: Dictionary = b.multipliers({"cold_level": 3, "gloves": true, "panic": true, "heavy_coat": true, "carry_state": 2})
	for k: String in ["swing", "reload", "swap", "hands", "shove_window"]:
		assert_eq(m[k], 0.5, k)
	assert_eq(m["move"], 0.25)
	assert_eq(m["aim_min"], 3.0)


# --- icons and words ---

func test_icons_order_and_severity() -> void:
	var b := Body.new()
	assert_eq(b.icons(), [])
	b.exhaustion = 0.6
	b.bleed = 1
	b.arm_fracture = true
	b.cold_level = 3
	b.infection = "scratch"
	var ic: Array = b.icons()
	assert_eq(ic.size(), 5)
	assert_eq(ic[0]["id"], "infection")
	assert_false(ic[0]["severe"])
	assert_eq(ic[1]["id"], "cold")
	assert_true(ic[1]["severe"])
	assert_eq(ic[2]["id"], "bleed")
	assert_eq(ic[3]["id"], "fracture")
	assert_eq(ic[4]["id"], "exhaustion")
	b.bleed = 2
	b.infection = "bite"
	ic = b.icons()
	assert_true(ic[0]["severe"])
	assert_eq(ic[1]["id"], "bleed")
	assert_eq(ic[2]["id"], "cold")


func test_icons_cold_faint_from_tick() -> void:
	var b := Body.new()
	var ctx := IDLE.duplicate()
	ctx["cold_level"] = 1
	b.tick(1.0, ctx)
	var ic: Array = b.icons()
	assert_eq(ic.size(), 1)
	assert_eq(ic[0]["id"], "cold")
	assert_true(ic[0]["faint"])


func test_status_words() -> void:
	var b := Body.new()
	assert_eq(b.status_words(), "멀쩡함")
	b.exhaustion = 0.6
	assert_eq(b.status_words(), "피곤함")
	b.cold_level = 2
	assert_eq(b.status_words(), "손이 떨림")
	b.leg_fracture = true
	b.splinted = true
	assert_eq(b.status_words(), "느림")
	b.bleed = 2
	assert_eq(b.status_words(), "피를 흘림")
	b.infection = "bite"
	assert_eq(b.status_words(), "물림")
	b.downed = true
	assert_eq(b.status_words(), "쓰러짐")
	b.dead = true
	assert_eq(b.status_words(), "죽음")
