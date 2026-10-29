extends "res://addons/gut/test.gd"
## Decision 444 (전투 손맛 C): a blow is felt. The field holds a moment as the
## player's own blow lands, the camera kicks the way it went and settles, the
## phone buzzes, and the blow sounds by the weapon; a miss is the swing and a short breath
## of air (blow_miss), no hit_*.
## None of it is read back by the rules (hit_feel.gd).

const FieldGame = preload("res://game/field_game.gd")
const HitFeel = preload("res://game/hit_feel.gd")
const PersonVisual = preload("res://game/actors/person_visual.gd")
const W = preload("res://game/sim/weapons.gd")
const FxState = preload("res://fx/fx_state.gd")
const BodyState = preload("res://game/sim/body_state.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const DeadPose = preload("res://game/actors/dead_pose.gd")
const FieldAudio = preload("res://game/audio/field_audio.gd")
const FieldSave = preload("res://game/sim/field_save.gd")

var game
var p


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 17, "raiders": false, "auto_pause": false, "hit_power": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	p = game.player
	p.position = game.lift(Vector2i(60, 7), 0)
	p.facing = PI * 0.5   # east
	_hand(p, "crowbar")
	game.audio.played.clear()


func _hand(who, id: String) -> void:
	who.hands = [] if id == "" else [{"id": id, "quality": "factory", "condition": 1.0, "loaded": 0}]
	who.set_weapon_slots(who.hands)


## The fight clock runs past the draw-back and the way back (zombies stand still).
func _land() -> void:
	for i in 40:
		game.combat.update(0.05)


func _hold_for(weapon: String) -> float:
	return HitFeel.STOP_BASE + HitFeel.STOP_PER_KG * float(W.get_data(weapon)["weight"])


func test_the_players_blow_holds_the_field_kicks_the_camera_and_buzzes() -> void:
	game.zombies.spawn("dead", p.position + Vector3(0.9, 0, 0))
	game.combat.swing_air(p)
	assert_true(game.audio.played.has("swing_heavy"), "a crowbar comes round with the heavy whoosh")
	_land()
	var f = game.feel
	assert_true(f.holding(), "the field holds")
	assert_between(f.hold_t, _hold_for("crowbar"), _hold_for("crowbar") + HitFeel.STOP_FELLED + 0.0001)
	assert_true(game.audio.played.has("hit_blunt"), "a crowbar lands blunt")
	var kick: Vector3 = f.camera_offset()
	assert_gt(kick.length(), 0.0, "the camera kicks")
	assert_gt(kick.x, 0.0, "the way the blow went (east)")
	assert_false(f.last_buzz.is_empty(), "the phone buzzes")


func test_the_blow_sounds_ship() -> void:
	var a = game.audio
	var counts := {"swing_light": 3, "swing_heavy": 3, "hit_blunt": 3, "hit_blade": 3, "hit_stomp": 2}
	for g: String in counts:
		assert_true(a.GROUPS.has(g), g)
		var list: Array = a._load_group(g)
		assert_eq(list.size(), int(counts[g]), g)
		for s in list:
			assert_gt(s.get_length(), 0.1, g)


func test_a_heavier_weapon_holds_longer() -> void:
	assert_lt(_hold_for("knife"), _hold_for("crowbar"))
	assert_lt(_hold_for("crowbar"), _hold_for("axe"))
	assert_almost_eq(_hold_for("axe"), 0.075, 0.0001)
	assert_lt(_hold_for("axe") + HitFeel.STOP_FELLED, HitFeel.STOP_MAX + 0.0001, "the longest hold is under the cap")


func test_an_edge_lands_with_its_own_sound() -> void:
	_hand(p, "knife")
	game.zombies.spawn("dead", p.position + Vector3(0.8, 0, 0))
	game.combat.swing_air(p)
	assert_true(game.audio.played.has("swing_light"), "a knife whooshes light")
	_land()
	assert_true(game.audio.played.has("hit_blade"))
	assert_false(game.audio.played.has("hit_blunt"))


func test_a_miss_is_the_swing_alone_not_a_crash_of_glass() -> void:
	game.combat.swing_air(p)
	_land()
	assert_true(game.audio.played.has("swing_heavy"))
	for g in ["hit_blunt", "hit_blade", "hit_stomp"]:
		assert_false(game.audio.played.has(g), "no blow lands on air")
	assert_ne(game.audio.last_tag_group, "impact", "the swish is not a random crash any more")
	assert_false(game.feel.holding(), "nothing to hold for")


func test_a_companions_blow_is_heard_but_neither_holds_nor_shakes() -> void:
	var ally = null
	for o in game.allies_alive():
		if o != p:
			ally = o
			break
	assert_not_null(ally, "the stop has a companion")
	ally.position = p.position + Vector3(0, 0, 3)
	ally.facing = PI * 0.5
	_hand(ally, "axe")
	game.zombies.spawn("dead", ally.position + Vector3(0.9, 0, 0))
	game.combat.swing_air(ally)
	_land()
	assert_true(game.audio.played.has("hit_blade"), "a hatchet is an edge")
	assert_false(game.feel.holding())
	assert_eq(game.feel.camera_offset(), Vector3.ZERO)
	assert_true(game.feel.last_buzz.is_empty())


func test_the_hold_stands_the_rules_and_the_people_and_then_lets_go() -> void:
	game.feel.hold_t = 0.05
	var t0: float = game.clock.elapsed
	game._process(0.02)
	assert_true(game.hitstop)
	assert_eq(game.clock.elapsed, t0, "the rules do not step through a hold")
	assert_eq(PersonVisual.frame_delta(game, 0.02), 0.0, "the people stand with it")
	for i in 4:
		game._process(0.02)
	assert_false(game.hitstop)
	assert_gt(game.clock.elapsed, t0, "after it the field goes on")


func test_no_second_hold_straight_after_one() -> void:
	var f = game.feel
	f._hold(0.05)
	f.tick(0.06, true)
	assert_false(f.holding())
	f._hold(0.05)
	assert_false(f.holding(), "within the rest after a hold, none")
	f.tick(HitFeel.STOP_REST, true)
	f._hold(0.05)
	assert_true(f.holding())


func test_the_kick_settles() -> void:
	var f = game.feel
	f._kick(Vector3(1, 0, 0), 0.01)
	assert_gt(f.camera_offset().length(), 0.005)
	for i in 30:
		f.tick(0.02, true)
	assert_eq(f.camera_offset(), Vector3.ZERO, "gone within half a second")


func test_paused_the_hold_waits() -> void:
	var f = game.feel
	f.hold_t = 0.05
	f.tick(0.5, false)
	assert_almost_eq(f.hold_t, 0.05, 0.0001, "a pause does not eat the hold")


func test_a_bite_on_the_player_holds_and_shakes_hardest() -> void:
	game.feel.bitten(p, false)
	assert_almost_eq(game.feel.hold_t, HitFeel.STOP_BITTEN, 0.0001)
	assert_almost_eq(game.feel.camera_offset().length(), HitFeel.SHAKE_BITTEN, 0.0001)
	assert_eq(int(game.feel.last_buzz[0]), int(HitFeel.BUZZ_BITTEN[0]))


func test_the_players_shot_kicks_back_from_where_it_went() -> void:
	game.feel.shot(p, "shotgun", p.position + Vector3(5, 0, 0))
	var kick: Vector3 = game.feel.camera_offset()
	assert_lt(kick.x, 0.0, "back, away from the shot")
	assert_false(game.feel.holding(), "a shot does not hold the field")


# At 30 frames a second a frame is longer than the lightest holds: the hold is
# read as the frame starts, so even those stand one whole frame.
func test_a_hold_shorter_than_a_frame_still_stands_one_frame() -> void:
	game.feel.hold_t = 0.03
	var t0: float = game.clock.elapsed
	game._process(1.0 / 30.0)
	assert_true(game.hitstop)
	assert_eq(game.clock.elapsed, t0)
	game._process(1.0 / 30.0)
	assert_false(game.hitstop)
	assert_gt(game.clock.elapsed, t0)


func test_a_real_blow_on_the_frames_holds_the_rules() -> void:
	game.zombies.spawn("dead", p.position + Vector3(0.9, 0, 0))
	game.combat.swing_air(p)
	var frames := 0
	while not game.feel.holding() and frames < 60:
		game._process(1.0 / 30.0)
		frames += 1
	assert_true(game.feel.holding(), "the blow lands within two seconds of frames")
	var t0: float = game.clock.elapsed
	game._process(1.0 / 30.0)
	assert_true(game.hitstop)
	assert_eq(game.clock.elapsed, t0, "the frame after the blow, the rules stand")


func test_a_weapon_that_breaks_on_the_blow_still_sounds_it() -> void:
	p.hands = [{"id": "broken_bottle", "quality": "factory", "condition": 0.01, "loaded": 0}]
	p.set_weapon_slots(p.hands)
	game.zombies.spawn("dead", p.position + Vector3(0.7, 0, 0))
	game.combat.swing_air(p)
	_land()
	assert_eq(p.weapon_id(), "", "the bottle went to pieces")
	assert_true(game.audio.played.has("hit_blade"), "the blow that broke it is heard")


func test_a_field_with_no_frames_keeps_only_a_few_kicks() -> void:
	for i in 40:
		game.feel.shot(p, "pistol", p.position + Vector3(5, 0, 0))
	assert_eq(game.feel.kicks.size(), HitFeel.KICKS_MAX)


func test_a_blow_throws_blood_the_way_it_went() -> void:
	# Decision 444 D: drops off the body, flying on from the blow (east here).
	FxState.blood_level = FxState.BloodLevel.NORMAL
	var fx = game.blood_fx
	fx.clear()
	game.zombies.spawn("dead", p.position + Vector3(0.9, 0, 0))
	game.combat.swing_air(p)
	_land()
	assert_gt(fx.drop_count(), 0, "the blow throws drops")
	var east := 0.0
	for d in fx.drops:
		east += float(d["vel"].x)
	assert_gt(east, 0.0, "they fly on the way the blow went")


func test_the_blood_has_its_own_dice() -> void:
	FxState.blood_level = FxState.BloodLevel.NORMAL
	var state: int = game.rng.state
	game.feel.landed(p, p.position + Vector3(0.9, 0, 0), "knife", true)
	assert_eq(game.rng.state, state, "the rules' dice are not touched")
	assert_gt(game.blood_fx.records.size(), 0, "one that goes down leaves a pool under it")


func test_a_round_a_vest_held_does_not_bleed() -> void:
	FxState.blood_level = FxState.BloodLevel.NORMAL
	var fx = game.blood_fx
	fx.clear()
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(3.0, 0, 0))
	z["round_held"] = true
	game.combat._shot_bleeds(p, z, "chase")
	assert_eq(fx.drop_count(), 0)
	assert_false(z.has("round_held"), "the mark is spent")
	game.combat._shot_bleeds(p, z, "chase")
	assert_gt(fx.drop_count(), 0, "a round that went in bleeds")


func test_a_blow_on_one_shoved_back_bleeds_where_it_is_seen() -> void:
	# A blow is judged where the body is drawn (decision 474 J2); what it throws
	# comes off there too, not off the rules' spot already 1.3 m on (review M1).
	FxState.blood_level = FxState.BloodLevel.NORMAL
	var fx = game.blood_fx
	fx.clear()
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.9, 0, 0))
	game.zombies.release(z, p.position, false)
	assert_gt(z["pos"].x - p.position.x, 2.0, "the rules have it on already")
	game.combat._strike(p, z)
	assert_gt(fx.drops.size(), 0)
	var x := 0.0
	for d in fx.drops:
		x += float(d["pos"].x) - p.position.x
	x /= float(fx.drops.size())
	assert_lt(x, 1.4, "the drops come off the drawn body, not the rules' spot")


# Decision 501: keep the old tests above on the unscaled path.
func test_power_table_uses_actual_body_penalties_and_leaves_inputs_untouched() -> void:
	var rows: Array = [
		["crowbar", 5, 0.0, 0, 1.0, 1.0, 0.85, 1],
		["crowbar", 5, 0.6, 0, 0.7, 0.775, 0.65875, 1],
		["crowbar", 5, 0.9, 0, 0.4, 0.55, 0.4675, 0],
		["crowbar", 5, 0.0, 2, 0.6, 0.7, 0.595, 1],
		["crowbar", 5, 0.9, 2, 0.24, 0.43, 0.3655, 0],
		["axe", 5, 0.0, 0, 1.0, 0.76, 0.836, 1],
		["axe", 4, 0.0, 0, 1.0, 0.6016, 0.66176, 1],
		["axe", 7, 0.0, 0, 1.0, 1.12, 1.232, 2],
		["axe", 7, 0.9, 0, 0.7, 0.868, 0.9548, 2],
		["knife", 4, 0.0, 0, 1.0, 0.94, 0.564, 1],
		["knife", 7, 0.0, 0, 1.0, 1.12, 0.672, 1],
		["broken_bottle", 5, 0.0, 0, 1.0, 1.0, 0.475, 0],
	]
	var rng_before: int = game.rng.state
	for row: Array in rows:
		var body: BodyState = BodyState.new()
		body.exhaustion = float(row[2])
		body.bleed = int(row[3])
		var ctx: Dictionary = {"strength": int(row[1]), "heavy_coat": true, "cold_level": 3}
		var before: Dictionary = body.save_of().duplicate(true)
		var ctx_before: Dictionary = ctx.duplicate(true)
		var melee: float = HitFeel.body_melee(body, ctx)
		var power: Dictionary = HitFeel.blow_power(float(W.get_data(String(row[0]))["weight"]), int(row[1]), melee)
		assert_almost_eq(melee, float(row[4]), 0.00001, str(row))
		assert_almost_eq(float(power["q"]), float(row[5]), 0.00001, str(row))
		assert_almost_eq(float(power["power"]), float(row[6]), 0.00001, str(row))
		assert_eq(int(power["tier"]), int(row[7]), str(row))
		assert_eq(body.save_of(), before, "the extra body read is pure")
		assert_eq(ctx, ctx_before, "the caller's coat and cold stay set")
	assert_eq(game.rng.state, rng_before)


func test_power_context_edges_outcomes_and_thresholds() -> void:
	var base: Dictionary = HitFeel.blow_power(2.0, 5, 1.0)
	var breath: Dictionary = HitFeel.blow_power(2.0, 5, 1.0, true)
	var back: Dictionary = HitFeel.blow_power(2.0, 5, 1.0, false, true)
	var counter: Dictionary = HitFeel.blow_power(2.0, 5, 1.0, false, false, true)
	assert_almost_eq(float(breath["q"]), 0.8, 0.00001)
	assert_almost_eq(float(back["power"]), 0.935, 0.00001)
	assert_almost_eq(float(counter["power"]), 1.02, 0.00001)
	assert_eq(int(counter["tier"]), 2)
	for edge: int in [-1, 0, 1, 2]:
		var edged: Dictionary = HitFeel.blow_power(2.0, 5, 1.0, false, false, false, edge)
		assert_almost_eq(float(edged["q"]), 0.9 if edge == 1 else (0.8 if edge == 2 else 1.0), 0.00001)
	var weak: Dictionary = HitFeel.blow_power(2.0, 5, 0.4)
	for outcome: String in ["finish", "shatter"]:
		var ended: Dictionary = HitFeel.resolved_power(weak, outcome)
		assert_eq(float(ended["power"]), 0.95)
		assert_eq(int(ended["tier"]), 2)
		assert_eq(ended["q"], weak["q"], "outcomes do not multiply Q")
	var blocked: Dictionary = HitFeel.resolved_power(counter, "blocked")
	assert_eq(float(blocked["power"]), 0.5)
	assert_eq(int(blocked["tier"]), 0)
	assert_eq(blocked["q"], counter["q"])
	assert_false(weak.has("result"), "outcome binding does not write its input")
	assert_eq(HitFeel.resolved_power(base, "body")["power"], base["power"])
	assert_eq(HitFeel.resolved_power({}, "finish").get("power", -1.0), -1.0)
	for way: String in ["stomp", "shove"]:
		var boot: Dictionary = HitFeel.blow_power(20.0, 5, 1.0, false, false, false, 2, way)
		assert_eq(float(boot["q"]), 1.0, "no weapon need or edge on a boot or shove")
		assert_eq(float(boot["power"]), 0.75 if way == "stomp" else 0.6)
		assert_gt(absf(float(boot["power"]) - 0.55), 0.02)
	assert_gt(absf(float(HitFeel.blow_power(0.5, 5, 1.0)["power"]) - 0.55), 0.02)
	assert_eq(float(HitFeel.blow_power(10.0, 100, 1.0, false, true, true)["power"]), 1.5)
	assert_eq(float(HitFeel.blow_power(3.0, 0, 0.0, true, false, false, 2)["power"]), 0.2)
	assert_eq(HitFeel.power_tier(0.54999), 0)
	assert_eq(HitFeel.power_tier(0.55), 1)
	assert_eq(HitFeel.power_tier(0.95), 2)


func test_counter_requires_a_close_pre_hit_attack_tell_grab_or_live_dash() -> void:
	for state: String in ["attack", "tell", "grab"]:
		assert_true(HitFeel.countering(state, 0.0, 1.2), state)
		assert_false(HitFeel.countering(state, 0.0, 1.2001), state)
	assert_false(HitFeel.countering("chase", 0.0, 0.5))
	assert_true(HitFeel.countering("chase", 0.1, 0.5))
	assert_false(HitFeel.countering("downed", 0.1, 0.5))


# Decision 501: choose branch dice locally, without consuming the field's dice.
func _roll_seed(first_low: float, first_high: float, second_low: float = 0.0, second_high: float = 1.0) -> int:
	var dice: RandomNumberGenerator = RandomNumberGenerator.new()
	for value: int in range(4096):
		dice.seed = value
		var first: float = dice.randf()
		var second: float = dice.randf()
		if first >= first_low and first < first_high and second >= second_low and second < second_high:
			return value
	assert_true(false, "a seed for the requested branch exists")
	return 0


func test_strike_captures_counter_before_knockdown_and_clears_its_call_state() -> void:
	game.opts["hit_power"] = true
	var heard: Array = []
	game.combat.struck.connect(func(info: Dictionary) -> void: heard.append(info.duplicate(true)))
	for state: String in ["attack", "tell", "chase", "dash"]:
		var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.8, 0, 0))
		z["angle"] = -PI * 0.5
		z["state"] = "chase" if state == "dash" else state
		z["dash_t"] = 0.1 if state == "dash" else 0.0
		z["lunger"] = state == "dash" or state == "tell"
		game.rng.seed = _roll_seed(0.98, 1.0, 0.0, 0.1)
		game.combat._strike(p, z)
		assert_eq(z["state"], "downed", "a body knockdown was reached")
		assert_eq(bool(heard.back()["counter"]), state != "chase", state)
		assert_true(game.combat._blow_now.is_empty(), "cleared before the next frame")
		assert_eq(float(z.get("hit_power", -1.0)), float(heard.back()["power"]))
		game.zombies.list.erase(z)
	var saved: Dictionary = FieldSave._script_state(game, game.combat)
	assert_true((saved.get("_blow_now", {}) as Dictionary).is_empty(), "no pending power in a save")


func _assert_feedback(feel, seconds: float, shake: float, ms: int, strength: float) -> void:
	assert_almost_eq(feel.hold_t, seconds, 0.000001)
	assert_almost_eq(float(feel.kicks.back()["amp"]), shake, 0.000001)
	assert_eq(int(feel.last_buzz[0]), ms)
	assert_almost_eq(float(feel.last_buzz[1]), strength, 0.000001)


func test_unscaled_landed_stomped_and_door_keep_exact_legacy_feedback() -> void:
	var at: Vector3 = p.position + Vector3(0.8, 0, 0)
	for weapon: String in ["knife", "crowbar", "axe"]:
		var kg: float = float(W.get_data(weapon)["weight"])
		for ended: bool in [false, true]:
			var more: float = 1.0 if ended else 0.0
			var feel: HitFeel = HitFeel.new(game)
			feel.landed(p, at, weapon, ended)
			_assert_feedback(feel, _hold_for(weapon) + HitFeel.STOP_FELLED * more, HitFeel.SHAKE_BASE + HitFeel.SHAKE_PER_KG * kg + HitFeel.SHAKE_FELLED * more, int(roundf(HitFeel.BUZZ_BASE_MS + HitFeel.BUZZ_PER_KG_MS * kg + HitFeel.BUZZ_FELLED_MS * more)), 0.35 + 0.15 * kg)
		var door: HitFeel = HitFeel.new(game)
		door.struck_door(p, at, weapon)
		_assert_feedback(door, HitFeel.STOP_DOOR, HitFeel.SHAKE_DOOR, int(roundf(HitFeel.BUZZ_BASE_MS + HitFeel.BUZZ_PER_KG_MS * kg)), 0.4)
	for ended: bool in [false, true]:
		var more: float = 1.0 if ended else 0.0
		var feel: HitFeel = HitFeel.new(game)
		feel.stomped(p, at, ended)
		_assert_feedback(feel, HitFeel.STOP_STOMP + HitFeel.STOP_FELLED * more, HitFeel.SHAKE_BASE + HitFeel.SHAKE_FELLED * more, int(roundf(HitFeel.BUZZ_BASE_MS + HitFeel.BUZZ_FELLED_MS * more)), 0.5)


func test_power_scales_q_feedback_rounds_frames_and_keeps_caps_and_rest() -> void:
	var at: Vector3 = p.position + Vector3(0.8, 0, 0)
	var feel: HitFeel = HitFeel.new(game)
	feel.landed(p, at, "crowbar", false, false, 0.55, 0)
	_assert_feedback(feel, 2.0 / 60.0, 0.0059 * 0.55, 19, 0.65 * 0.55)
	feel.tick(1.0, true)
	feel.landed(p, at, "axe", true, false, 2.0, 2)
	_assert_feedback(feel, HitFeel.STOP_MAX, 0.0091 * 1.4, 80, 1.0)
	feel.tick(HitFeel.STOP_MAX, true)
	feel.landed(p, at, "axe", true, false, 2.0, 2)
	assert_eq(feel.hold_t, 0.0, "STOP_REST still stops another hold")
	var boot: HitFeel = HitFeel.new(game)
	boot.stomped(p, at, false, 0.55, 0)
	_assert_feedback(boot, 2.0 / 60.0, HitFeel.SHAKE_BASE * 0.55, 10, 0.275)
	assert_eq(HitFeel.stop_seconds(0.001, 0.5, 0), 2.0 / 60.0)


func test_swing_person_stays_unscaled_with_power_enabled() -> void:
	game.opts["hit_power"] = true
	var other = game.allies_alive().filter(func(who) -> bool: return who != p)[0]
	game.rng.seed = _roll_seed(0.0, 0.1)
	game.combat.swing_person(p, other)
	_assert_feedback(game.feel, 0.06, 0.0059, 34, 0.65)
	assert_true(game.combat._blow_now.is_empty())


func test_audio_power_changes_only_first_layer_and_keeps_legacy_tiers() -> void:
	for weapon: String in ["knife", "crowbar", "axe", "broken_bottle", "boot", ""]:
		for target: String in ["standing", "downed", "frozen"]:
			for result: String in ["body", "finish", "shatter", "blocked", "miss"]:
				var info: Dictionary = {"weapon": weapon, "target": target, "result": result, "edge": 2}
				var old: Array = FieldAudio.blow_layers(info)
				for tier: int in [-1, 0, 1, 2]:
					info["tier"] = tier
					var got: Array = FieldAudio.blow_layers(info)
					assert_eq(got.size(), old.size(), "no new layer")
					if tier == -1 or tier == 1 or result == "miss":
						assert_eq(got, old)
					else:
						assert_eq(got[0][0], old[0][0])
						assert_almost_eq(float(got[0][1]), float(old[0][1]) * (0.6 if tier == 0 else 1.12), 0.00001)
						assert_almost_eq(float(got[0][2]), float(old[0][2]) * (1.1 if tier == 0 else 0.95), 0.00001)
						assert_eq(got.slice(1), old.slice(1))


func test_blocked_blades_throw_no_blood_with_power_on_or_off() -> void:
	FxState.blood_level = FxState.BloodLevel.NORMAL
	_hand(p, "knife")
	var heard: Array = []
	game.combat.struck.connect(func(info: Dictionary) -> void: heard.append(info.duplicate(true)))
	for enabled: bool in [false, true]:
		game.opts["hit_power"] = enabled
		game.blood_fx.clear()
		game.feel = HitFeel.new(game)
		var z: Dictionary = game.zombies.spawn("clothed", p.position + Vector3(0.8, 0, 0))
		z["angle"] = -PI * 0.5
		z["state"] = "chase"
		game.rng.seed = _roll_seed(0.98, 1.0)
		game.combat._strike(p, z)
		assert_eq(heard.back()["result"], "blocked", "the cloth branch was reached")
		assert_eq(game.blood_fx.drop_count(), 0, "M1: the cloth took the blade")
		assert_eq(game.blood_fx.records.size(), 0)
		assert_almost_eq(game.feel.hold_t, 2.0 / 60.0, 0.000001)
		assert_almost_eq(float(game.feel.kicks.back()["amp"]), 0.0047 * 0.5, 0.000001)
		assert_true(game.feel.last_buzz.is_empty(), "a block only holds and kicks")
		assert_eq(int(heard.back()["tier"]), 0 if enabled else -1)
		game.zombies.list.erase(z)


func test_power_is_default_on_but_off_and_misses_emit_absent_fields() -> void:
	game.opts.erase("hit_power")
	var heard: Array = []
	game.combat.struck.connect(func(info: Dictionary) -> void: heard.append(info.duplicate(true)))
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.8, 0, 0))
	z["angle"] = -PI * 0.5
	z["state"] = "chase"
	assert_gt(float(game.combat._power_before(p, z, "swing")["power"]), 0.0)
	game.opts["hit_power"] = false
	game.combat._strike(p, z)
	assert_false(z.has("hit_power"))
	game.combat._struck(p, p.position, "swing", "crowbar", "", "miss", 0)
	game.combat._struck(p, p.position, "shove", "", "", "miss", -1)
	for info: Dictionary in heard:
		assert_eq(float(info["power"]), -1.0)
		assert_eq(int(info["tier"]), -1)
		assert_false(bool(info["counter"]))
	assert_true(game.combat._blow_now.is_empty())


func test_power_reads_fatigue_and_edge_before_the_blow_spends_them() -> void:
	game.opts["hit_power"] = true
	_hand(p, "broken_bottle")
	p.hands[0]["condition"] = 0.01
	p.body.exhaustion = 0.7999
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.8, 0, 0))
	z["angle"] = -PI * 0.5
	z["state"] = "chase"
	var before: Dictionary = game.combat._power_before(p, z, "swing")
	var heard: Array = []
	game.combat.struck.connect(func(info: Dictionary) -> void: heard.append(info.duplicate(true)))
	game.rng.seed = _roll_seed(0.98, 1.0, 0.98, 1.0)
	game.combat._strike(p, z)
	assert_eq(p.weapon_id(), "", "the bottle broke on this blow")
	assert_eq(p.body.exhaustion_level(), 2, "the blow crossed a fatigue threshold")
	assert_eq(int(heard.back()["edge"]), 2)
	assert_eq(heard.back()["result"], "body")
	assert_almost_eq(float(heard.back()["power"]), float(before["power"]), 0.000001)


func test_power_companion_keeps_sound_and_blood_without_player_feedback() -> void:
	game.opts["hit_power"] = true
	FxState.blood_level = FxState.BloodLevel.NORMAL
	game.blood_fx.clear()
	var ally = game.allies_alive().filter(func(who) -> bool: return who != p)[0]
	ally.position = p.position + Vector3(0, 0, 3)
	_hand(ally, "axe")
	var z: Dictionary = game.zombies.spawn("dead", ally.position + Vector3(0.8, 0, 0))
	z["state"] = "attack"
	game.combat._strike(ally, z)
	assert_true(game.audio.played.has("hit_blade"))
	assert_gt(game.blood_fx.drop_count(), 0)
	assert_false(game.feel.holding())
	assert_true(game.feel.kicks.is_empty())
	assert_true(game.feel.last_buzz.is_empty())
	assert_gt(float(z.get("hit_power", -1.0)), 0.0)


# Decision 501: a short scripted fight, then equal rule steps (not wall time).
func _power_fight(enabled: bool, seed_value: int) -> Dictionary:
	var field: FieldGame = FieldGame.new()
	field.opts = {"seed": seed_value, "raiders": false, "auto_pause": false, "lungers": true, "hit_power": enabled}
	add_child(field)
	field.set_process(false)
	field.zombies.list.clear()
	field.pending_spawn.clear()
	var who = field.player
	who.position = field.lift(Vector2i(60, 7), 0)
	who.facing = PI * 0.5
	_hand(who, "crowbar")
	var trace: Array = []
	field.combat.struck.connect(func(info: Dictionary) -> void:
		var old: Dictionary = info.duplicate(true)
		for key: String in ["power", "tier", "counter"]:
			old.erase(key)
		trace.append(old))
	var rushing: Dictionary = field.zombies.spawn("dead", who.position + Vector3(0.8, 0, 0))
	rushing["state"] = "chase"
	rushing["lunger"] = true
	rushing["dash_t"] = 0.15
	rushing["dash_dir"] = Vector3(-1, 0, 0)
	rushing["angle"] = -PI * 0.5
	field.combat._strike(who, rushing)
	var frozen: Dictionary = field.zombies.spawn("frozen", who.position + Vector3(0.8, 0, 0))
	field.combat._strike(who, frozen)
	assert_eq(frozen["state"], "dead", "frozen shatter is covered")
	_hand(who, "")
	var fallen: Dictionary = field.zombies.spawn("dead", who.position + Vector3(0.8, 0, 0))
	field.zombies.knock_down(fallen)
	for i: int in range(field.combat.STOMPS_TO_END):
		field.combat.stomp(who, fallen)
	assert_eq(fallen["state"], "dead", "stomp finish is covered")
	var shoved: Dictionary = field.zombies.spawn("dead", who.position + Vector3(0.7, 0, 0))
	shoved["state"] = "tell"
	shoved["lunger"] = true
	who.swing_t = 0.0
	field.combat.shove(who)
	assert_gt(float(shoved.get("shoved_t", 0.0)), 0.0, "shove body contact is covered")
	var ally = field.allies_alive().filter(func(person) -> bool: return person != who)[0]
	ally.position = who.position + Vector3(0, 0, 3)
	_hand(ally, "axe")
	var target: Dictionary = field.zombies.spawn("dead", ally.position + Vector3(0.8, 0, 0))
	target["state"] = "attack"
	field.combat._strike(ally, target)
	for i: int in range(12):
		field._step(1.0 / 60.0)
		assert_true(field.combat._blow_now.is_empty(), "empty at every rule boundary")
	var dead: Array = []
	for z: Dictionary in field.zombies.list:
		dead.append([z["id"], z["state"], z["pos"], field.zombies.seen_pos(z)])
	var people: Array = []
	for person in field.people:
		people.append([person.pid, person.body.dead, person.body.downed, person.position])
	var result: Dictionary = {"melee_tally": field.combat.melee_tally.duplicate(true), "contacts": field.combat.contacts.duplicate(true), "kills": field.combat.kills, "crowd_falls": field.combat.crowd_falls, "dead": dead, "people": people, "rng": field.rng.state, "trace": trace}
	field.free()
	return result


func test_power_on_off_same_seed_preserves_rules_in_a_mixed_fight() -> void:
	for seed_value: int in [17, 51]:
		var off: Dictionary = _power_fight(false, seed_value)
		var on: Dictionary = _power_fight(true, seed_value)
		for key: String in off:
			assert_eq(on[key], off[key], "%s, seed %d" % [key, seed_value])


func test_hit_power_mixes_recoil_without_changing_its_duration() -> void:
	var prior: Array = DeadBody.table
	DeadBody.table = []
	for clip: int in range(DeadBody.HIT_UPPER + 1):
		DeadBody.table.append([clip * 12, 12, false, 0.4])
	var plain: Color = Color(0.5, float(DeadBody.HIT_LEFT), 1.0, 1.0)
	var old: Color = DeadBody.mixed({"age": 1.0}, plain)
	assert_eq(DeadBody.mixed({"age": 1.0, "hit_power": -1.0}, plain), old)
	assert_eq(DeadBody.mixed({"age": 1.0, "hit_power": 0.85}, plain), old)
	assert_eq(DeadBody.struck_scale(0.4), 0.6)
	assert_eq(DeadBody.struck_scale(0.85), 1.0)
	assert_eq(DeadBody.struck_scale(1.2), 1.2)
	for power: float in [0.4, 1.2]:
		var z: Dictionary = {"state": "chase", "age": 1.2, "hit_at": 1.0, "hit_hold": 0.0, "hit_power": power, "hit_way": "p_stab"}
		var mixed: Color = DeadBody.mixed(z, plain)
		assert_ne(mixed.g, old.g, "the recoil blend changes")
		assert_eq(mixed.r, old.r, "the motion clock does not change")
		assert_eq(DeadBody.motion_in(mixed.g), DeadBody.HIT_LEFT)
		assert_almost_eq(DeadBody.struck_k(z), 0.5, 0.00001)
		z["age"] = 1.401
		assert_eq(DeadBody.struck_motion(z), -1, "ends at the old duration")
	DeadBody.table = prior


func test_hit_power_waits_for_the_blend_into_the_blow() -> void:
	var prior: Array = DeadBody.table
	DeadBody.table = []
	for clip: int in range(DeadBody.HIT_UPPER + 1):
		DeadBody.table.append([clip * 12, 12, false, 0.4])
	var plain: Color = Color(0.5, float(DeadBody.HIT_LEFT), 1.0, 1.0)
	# The body was in another motion: the first frames blend into the blow as before, no pop.
	var weak: Dictionary = {"age": 1.0, "body_motion": 0, "body_r": 0.3, "hit_power": 0.4}
	var plain_body: Dictionary = {"age": 1.0, "body_motion": 0, "body_r": 0.3}
	assert_eq(DeadBody.mixed(weak, plain), DeadBody.mixed(plain_body, plain), "the blend in is left alone")
	var blend: float = float(weak["body_mix"])
	weak["age"] = 1.0 + blend * 0.5
	plain_body["age"] = weak["age"]
	assert_eq(DeadBody.mixed(weak, plain), DeadBody.mixed(plain_body, plain), "still blending in")
	weak["age"] = 1.0 + blend * 3.0
	plain_body["age"] = weak["age"]
	assert_ne(DeadBody.mixed(weak, plain), DeadBody.mixed(plain_body, plain), "then the weak recoil eases in")
	DeadBody.table = prior


func test_stomp_and_shove_read_body_before_their_fatigue() -> void:
	game.opts["hit_power"] = true
	_hand(p, "")
	var heard: Array = []
	game.combat.struck.connect(func(info: Dictionary) -> void: heard.append(info.duplicate(true)))
	for way: String in ["stomp", "shove"]:
		p.body.exhaustion = 0.7999
		p.swing_t = 0.0
		var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.7, 0, 0))
		z["angle"] = -PI * 0.5
		z["state"] = "chase"
		if way == "stomp":
			game.zombies.knock_down(z)
		var before: Dictionary = game.combat._power_before(p, z, way)
		if way == "stomp":
			game.combat.stomp(p, z)
		else:
			game.combat.shove(p)
		assert_eq(heard.back()["way"], way)
		assert_eq(heard.back()["result"], "body")
		assert_eq(p.body.exhaustion_level(), 2)
		assert_almost_eq(float(heard.back()["power"]), float(before["power"]), 0.000001)
		assert_true(game.combat._blow_now.is_empty())
		game.zombies.list.erase(z)


func test_q_scales_blood_spray_including_felled_bodies_without_rules_dice() -> void:
	FxState.blood_level = FxState.BloodLevel.NORMAL
	var before: int = game.rng.state
	var at: Vector3 = p.position + Vector3(0.8, 0, 0)
	for ended: bool in [false, true]:
		var counts: Array = []
		for q: float in [0.5, 1.4]:
			game.blood_fx.clear()
			game.blood_fx._rng.seed = 501
			game.feel.landed(p, at, "crowbar", ended, false, q, 1)
			counts.append(game.blood_fx.drop_count())
			if ended:
				assert_gt(game.blood_fx.records.size(), 0, "the death pool stays")
		assert_gt(int(counts[1]), int(counts[0]))
	assert_eq(game.rng.state, before)


func test_hit_power_never_changes_seen_pos_including_fallen_and_shoved_bodies() -> void:
	var prior: Array = DeadBody.table
	DeadBody.table = []
	for clip: int in range(DeadBody.HIT_UPPER + 1):
		DeadBody.table.append([clip * 12, 12, false, 0.4])
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.8, 0, 0))
	game.zombies.knock_down(z)
	z["hit_at"] = float(z["age"]) - 0.2
	z["hit_way"] = "p_stab"
	z["hit_hold"] = 0.9
	for state: String in ["chase", "downed", "rising", "dead"]:
		for elapsed: float in [0.0, 0.15, 0.4, 0.8]:
			var off: Dictionary = z.duplicate(true)
			off["state"] = state
			off["age"] = float(z["age"]) + elapsed
			off["shoved_from"] = off["pos"] - Vector3(0.5, 0, 0)
			off["shoved_t"] = maxf(0.0, 0.35 - elapsed)
			var down: float = DeadPose.down_k(off)
			var seen: Vector3 = game.zombies.seen_pos(off)
			var old: Color = DeadBody.custom(off, down, 1.0, 1.0, true)
			for power: float in [0.4, 1.2]:
				var on: Dictionary = off.duplicate(true)
				on["hit_power"] = power
				var drawn: Color = DeadBody.custom(on, down, 1.0, 1.0, true)
				assert_eq(game.zombies.seen_pos(on), seen, "%s at %s" % [state, elapsed])
				assert_eq(DeadPose.down_k(on), down)
				if down > 0.0:
					assert_eq(drawn, old, "the whole ground pose is unchanged")
	DeadBody.table = prior
