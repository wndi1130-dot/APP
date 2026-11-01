extends GutTest
## Decision 423 card 3 and 5, 422 M2/M11/M14: the walk and run by what is in
## the hand, a long weapon held low with a broken arm, and each person's own
## beat, stride and lean (gait.gd, person_visual.gd, field_game.gd steps_in).

const Gait = preload("res://game/sim/gait.gd")
const PersonVisual = preload("res://game/actors/person_visual.gd")
const Person = preload("res://game/actors/person.gd")
const FieldGame = preload("res://game/field_game.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const BodyBake = preload("res://scripts/body_bake.gd")


class StubCombat:
	extends RefCounted
	var near: bool = false

	func tap_assist_off(_p) -> bool:
		return near


class StubField:
	extends RefCounted
	var combat = StubCombat.new()


func _person(pid: String = "p_test", name_text: String = "시험") -> Node3D:
	var p := Person.new()
	add_child_autofree(p)
	p.setup(pid, name_text, "companion", Vector3.ZERO)
	return p


func _hold(p, wid: String) -> void:
	p.hands = [{"id": wid, "quality": "factory", "condition": 1.0, "loaded": 0}]


func _own() -> Array:
	return BodyBake.load_baked(PersonVisual.OWN_FOLDER).get("clips", [])


func _named(own: Array, c: Vector2) -> String:
	return String(own[int(c.y)].get("name", ""))


## Walked a step on (or stood still for a while) and drawn. Standing, the
## moments a hurt body shows how it is (mood_of) are let go by.
func _drawn(p, note: Dictionary, own: Array, move: bool) -> String:
	if move:
		p.moving = true
		p.position += Vector3(0.3, 0, 0)
		return _named(own, PersonVisual.motion_of(p, note, 0.1, [], own))
	p.moving = false
	PersonVisual.motion_of(p, note, 0.3, [], own)
	var got := _named(own, PersonVisual.motion_of(p, note, 0.1, [], own))
	var tries := 0
	while (got.begins_with("p_pain") or got == PersonVisual.OWN_SHIVER or got == PersonVisual.OWN_TIRED) and tries < 300:
		got = _named(own, PersonVisual.motion_of(p, note, 0.1, [], own))
		tries += 1
	return got


func test_each_kind_of_hand_has_its_walk_and_run() -> void:
	var kinds := {"knife": "", "crowbar": "axe", "axe": "axe", "pistol": "pistol", "shotgun": "long",
		"pipe_shotgun": "long", "bow": "", "frying_pan": "", "broken_bottle": "", "wood_stake": "", "": ""}
	for wid: String in kinds:
		assert_eq(Gait.kind_of(wid), String(kinds[wid]), wid)
	var p := _person()
	for row in [["pistol", "p_walk_pistol", "p_run_pistol"], ["shotgun", "p_walk_long", "p_run_long"],
			["bow", "", ""], ["axe", "p_walk_axe", ""], ["knife", "", ""]]:
		_hold(p, String(row[0]))
		assert_eq(Gait.gait_name(p, false), String(row[1]), String(row[0]) + " walks")
		assert_eq(Gait.gait_name(p, true), String(row[2]), String(row[0]) + " runs")


func test_the_drawn_walk_and_run_follow_the_hand() -> void:
	var own := _own()
	var p := _person()
	var note := {}
	PersonVisual.motion_of(p, note, 0.1, [], own)
	for row in [["pistol", "p_walk_pistol", "p_run_pistol"], ["shotgun", "p_walk_long", "p_run_long"],
			["axe", "p_walk_axe", "p_run"], ["knife", "p_walk", "p_run"], ["", "p_walk", "p_run"]]:
		_hold(p, String(row[0]))
		p.running = false
		assert_eq(_drawn(p, note, own, true), String(row[1]), "%s walking" % row[0])
		p.running = true
		assert_eq(_drawn(p, note, own, true), String(row[2]), "%s running" % row[0])
	# Crouched a gun is held low in both hands (test_crouched_by_what_is_held);
	# standing, one stand.
	p.running = false
	p.crouched = true
	_hold(p, "shotgun")
	assert_eq(_drawn(p, note, own, true), String(Gait.CROUCH_WALK["long"]))
	p.crouched = false
	assert_eq(_drawn(p, note, own, false), PersonVisual.OWN_STAND)
	# Turning on the spot it steps round in the walk of what it holds.
	p.rotation.y += 0.6
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.05, [], own)), "p_walk_long")


func test_a_folder_without_them_walks_and_runs_the_plain_way() -> void:
	var clips := [{"name": "p_walk", "round": 1.64}, {"name": "p_run", "round": 2.27}, {"name": "p_crouch_walk", "round": 1.19}]
	var p := _person()
	_hold(p, "pistol")
	assert_eq(PersonVisual.gait_of(p, clips, false), 0)
	assert_eq(PersonVisual.gait_of(p, clips, true), 1)
	p.crouched = true
	assert_eq(PersonVisual.gait_of(p, clips, false), 2)


# The weapon walks and runs are the plain ones' legs: they go round with the
# footsteps as the plain ones do, and their rounds are the rules' own.
func test_the_weapon_gaits_go_round_with_the_footsteps() -> void:
	var own := _own()
	for gait in [["walk", Gait.WALK.values()], ["run", Gait.RUN.values()]]:
		for clip_name: String in gait[1]:
			var n := PersonVisual.clip_named(own, clip_name, -1)
			assert_gt(n, -1, clip_name + " is in the build")
			assert_almost_eq(float(own[n]["round"]), float(SimNoise.STEP_ROUND[gait[0]]), 0.01 * float(own[n]["round"]), clip_name + ": the round is the rules' own")
			assert_true(PersonVisual.is_stepped(clip_name), clip_name)
	for clip_name in ["p_walk", "p_run", "p_crouch_walk"]:
		assert_true(PersonVisual.is_stepped(clip_name), clip_name)
	for clip_name in ["p_limp_heavy", "p_spent", "p_hold_weak", ""]:
		assert_false(PersonVisual.is_stepped(clip_name), clip_name)
	var p := _person()
	_hold(p, "shotgun")
	var note := {}
	PersonVisual.motion_of(p, note, 0.1, [], own)
	p.moving = true
	p.position += Vector3(0.1, 0, 0)
	p.brain["step_r"] = 0.37
	var c := PersonVisual.motion_of(p, note, 0.05, [], own)
	assert_eq(_named(own, c), "p_walk_long")
	assert_almost_eq(c.x, 0.37, 0.001, "the long walk is where the footsteps are")


# Card 5 and M2: a long weapon with an arm broken (one or both) is held low in
# one hand standing and carried in one hand on the move; the numbers are as
# they were. A handgun is held as before.
func test_a_broken_arm_holds_a_long_weapon_low() -> void:
	var own := _own()
	var p := _person()
	var note := {}
	_hold(p, "shotgun")
	assert_false(Gait.weak_hold(p))
	p.body.fracture(true, "arm_left")
	assert_true(Gait.weak_hold(p))
	assert_true(bool(p.mults()["one_hand"]), "the same state the rules will not let it aim in")
	assert_eq(_drawn(p, note, own, false), Gait.HOLD_WEAK, "standing: low in one hand")
	assert_eq(_drawn(p, note, own, true), "p_walk", "walking: carried in one hand")
	p.running = true
	assert_eq(_drawn(p, note, own, true), "p_run")
	p.running = false
	p.body.fracture(true, "arm_right")
	for i in 10:
		PersonVisual.motion_of(p, note, 0.1, [], own)   # the flinch at the new break plays out
	assert_eq(_drawn(p, note, own, false), Gait.HOLD_WEAK, "both arms broken: the same picture")
	p.crouched = true
	assert_eq(_drawn(p, note, own, false), PersonVisual.OWN_CROUCH_STAND, "crouched it keeps low")
	p.crouched = false
	_hold(p, "pistol")
	assert_false(Gait.weak_hold(p))
	assert_eq(_drawn(p, note, own, false), PersonVisual.OWN_STAND)
	assert_eq(_drawn(p, note, own, true), "p_walk_pistol")


# With the run on but no breath left (or spent) the feet walk, as the rules
# move them: the picture walks too.
func test_out_of_breath_with_the_run_on_it_walks() -> void:
	var own := _own()
	var p := _person()
	var note := {}
	PersonVisual.motion_of(p, note, 0.1, [], own)
	p.running = true
	assert_eq(_drawn(p, note, own, true), PersonVisual.OWN_RUN)
	p.body.breath = 0.0
	assert_false(p.body.can_run())
	assert_eq(_drawn(p, note, own, true), PersonVisual.OWN_WALK, "no breath: it walks")
	p.body.breath = 1.0
	p.body.exhaustion = 0.9
	assert_eq(_drawn(p, note, own, true), PersonVisual.OWN_SPENT, "spent with the run on: it reels")


# Over the load, or with something big in both arms, the rules walk it with the
# run on (person.gd load_lets_run, decision 448-19): the picture walks too, not a
# run at a walking pace.
func test_over_the_load_or_with_a_big_thing_the_run_on_walks() -> void:
	var own := _own()
	var p := _person()
	var note := {}
	PersonVisual.motion_of(p, note, 0.1, [], own)
	p.running = true
	p.items.clear()
	assert_eq(_drawn(p, note, own, true), PersonVisual.OWN_RUN)
	p.add_item("symbol_bell", 1)
	assert_false(p.load_lets_run())
	assert_false(Gait.runs(p))
	assert_eq(_drawn(p, note, own, true), Gait.CARRY_BIG, "the bell in the arms: it walks, carrying it")
	p.items.clear()
	p.add_item("scrap", int(ceil(p.carry_limit() * 1.5)))
	assert_eq(p.carry_state(), 2)
	assert_eq(_drawn(p, note, own, true), PersonVisual.OWN_WALK, "over the load: it walks")
	p.items.clear()
	assert_eq(_drawn(p, note, own, true), PersonVisual.OWN_RUN, "put down, it runs again")


# Bleeding hard (the rules walk it slower and it goes down in two minutes) it
# reels as one spent does, walking and standing (decision 448: how one moves
# shows the wounds); a leg that limps shows the limp first, walking. A light
# bleed walks as before. Bleeding does not stop the run, so running it runs.
func test_bleeding_hard_it_reels_and_a_limp_comes_first() -> void:
	var own := _own()
	var p := _person()
	var note := {}
	PersonVisual.motion_of(p, note, 0.1, [], own)
	p.body.add_wound("arm_left", "laceration", 1.0)
	assert_eq(p.body.bleed_level(), 1)
	assert_false(Gait.reels(p))
	for i in 10:
		PersonVisual.motion_of(p, note, 0.1, [], own)   # the flinch at the new wound plays out
	assert_eq(_drawn(p, note, own, true), PersonVisual.OWN_WALK, "a light bleed: it walks")
	p.body.add_wound("torso", "deep", 1.0)
	assert_eq(p.body.bleed_level(), 2)
	assert_lt(float(p.mults()["move"]), 1.0, "the rules walk it slower")
	assert_true(Gait.reels(p))
	for i in 10:
		PersonVisual.motion_of(p, note, 0.1, [], own)   # the flinch at the new wound plays out
	assert_eq(_drawn(p, note, own, true), PersonVisual.OWN_SPENT, "bleeding hard: it reels")
	assert_eq(_drawn(p, note, own, false), PersonVisual.OWN_SPENT, "and stopping it does not stand up straight")
	p.running = true
	assert_true(p.body.can_run())
	assert_eq(_drawn(p, note, own, true), PersonVisual.OWN_RUN, "the run on: it runs")
	p.running = false
	p.crouched = true
	assert_eq(_drawn(p, note, own, true), PersonVisual.OWN_CROUCH_WALK, "crouched: the crouched walk")
	p.crouched = false
	p.body.add_wound("leg_left", "laceration", 1.0)
	for i in 10:
		PersonVisual.motion_of(p, note, 0.1, [], own)
	assert_true(_drawn(p, note, own, true).begins_with("p_limp_light"), "a leg that limps: the limp first")
	assert_eq(_drawn(p, note, own, false), PersonVisual.OWN_SPENT, "standing still it reels")
	# Spent with a limp, the same: the limp walking, the reel standing.
	var q := _person("p_q", "지친")
	var q_note := {}
	PersonVisual.motion_of(q, q_note, 0.1, [], own)
	q.body.exhaustion = 0.9
	q.body.add_wound("leg_right", "laceration", 1.0)
	for i in 10:
		PersonVisual.motion_of(q, q_note, 0.1, [], own)
	assert_true(_drawn(q, q_note, own, true).begins_with("p_limp_light"), "spent and limping: the limp walking")
	assert_eq(_drawn(q, q_note, own, false), PersonVisual.OWN_SPENT, "and the reel standing")


# Decision 448: crouched, a gun is held low in both hands (a long gun and a
# handgun each its own way); anything else crouches the plain way, and so does a
# long weapon held in one hand (a hurt arm). The crouched walks go round with the
# footsteps at the crouch's round.
func test_crouched_by_what_is_held() -> void:
	var own := _own()
	for clip_name: String in Gait.CROUCH_WALK.values():
		var n := PersonVisual.clip_named(own, clip_name, -1)
		assert_gt(n, -1, clip_name + " is in the build")
		assert_almost_eq(float(own[n]["round"]), float(SimNoise.STEP_ROUND["crouch"]), 0.01 * float(own[n]["round"]), clip_name + ": the crouch's round")
		assert_true(PersonVisual.is_stepped(clip_name), clip_name)
	var p := _person()
	var note := {}
	PersonVisual.motion_of(p, note, 0.1, [], own)
	p.crouched = true
	for row in [["shotgun", "long"], ["pistol", "pistol"]]:
		_hold(p, String(row[0]))
		assert_eq(_drawn(p, note, own, true), String(Gait.CROUCH_WALK[row[1]]), "%s crouched, walking" % row[0])
		assert_eq(_drawn(p, note, own, false), String(Gait.CROUCH_STAND[row[1]]), "%s crouched, still" % row[0])
	for wid in ["knife", "axe", "bow", ""]:
		_hold(p, wid)
		if wid == "":
			p.hands = []
		assert_eq(_drawn(p, note, own, true), PersonVisual.OWN_CROUCH_WALK, "%s crouched, walking" % wid)
		assert_eq(_drawn(p, note, own, false), PersonVisual.OWN_CROUCH_STAND, "%s crouched, still" % wid)
	_hold(p, "shotgun")
	p.body.fracture(true, "arm_left")
	for i in 10:
		PersonVisual.motion_of(p, note, 0.1, [], own)   # the flinch at the new break plays out
	assert_eq(_drawn(p, note, own, true), PersonVisual.OWN_CROUCH_WALK, "a long gun in one hand: the plain crouch")


# Decision 448: something big held in both arms is carried so, walking (it cannot
# be run); a body wound as sore as it shows standing goes bent with a hand to its
# side; an arm that hurts walks as before. A leg's limp comes first, then the reel
# (spent or bleeding hard), then full arms, then the hurt. Both go round with the
# footsteps at the walk's round.
func test_carried_and_hurt_walks() -> void:
	var own := _own()
	for clip_name in [Gait.CARRY_BIG, Gait.WALK_HURT]:
		var n := PersonVisual.clip_named(own, clip_name, -1)
		assert_gt(n, -1, clip_name + " is in the build")
		assert_almost_eq(float(own[n]["round"]), float(SimNoise.STEP_ROUND["walk"]), 0.01 * float(own[n]["round"]), clip_name + ": the walk's round")
		assert_true(PersonVisual.is_stepped(clip_name), clip_name)
	var p := _person()
	var note := {}
	PersonVisual.motion_of(p, note, 0.1, [], own)
	p.add_item("symbol_bell", 1)
	assert_eq(_drawn(p, note, own, true), Gait.CARRY_BIG, "the bell in both arms")
	p.running = true
	assert_eq(_drawn(p, note, own, true), Gait.CARRY_BIG, "the run on: it walks carrying")
	p.running = false
	p.items.clear()
	assert_eq(_drawn(p, note, own, true), PersonVisual.OWN_WALK, "put down: the plain walk")
	p.body.add_wound("arm_right", "laceration", 1.0)
	for i in 10:
		PersonVisual.motion_of(p, note, 0.1, [], own)
	assert_eq(_drawn(p, note, own, true), PersonVisual.OWN_WALK, "an arm that hurts: as before")
	p.body.add_wound("torso", "laceration", 1.0)
	for i in 10:
		PersonVisual.motion_of(p, note, 0.1, [], own)
	assert_lt(p.body.bleed_level(), 2)
	assert_eq(_drawn(p, note, own, true), Gait.WALK_HURT, "the body hurting: bent, a hand to its side")
	p.add_item("symbol_bell", 1)
	assert_eq(_drawn(p, note, own, true), Gait.CARRY_BIG, "full arms before the hurt")
	p.body.exhaustion = 0.9
	assert_eq(_drawn(p, note, own, true), PersonVisual.OWN_SPENT, "spent: the reel before full arms")
	p.body.exhaustion = 0.0
	p.body.add_wound("arm_left", "deep", 1.0)
	for i in 10:
		PersonVisual.motion_of(p, note, 0.1, [], own)
	assert_eq(p.body.bleed_level(), 2)
	assert_eq(_drawn(p, note, own, true), PersonVisual.OWN_SPENT, "bleeding hard: the reel before full arms")
	p.items.clear()
	p.body.add_wound("leg_left", "laceration", 1.0)
	for i in 10:
		PersonVisual.motion_of(p, note, 0.1, [], own)
	assert_true(_drawn(p, note, own, true).begins_with("p_limp_light"), "a leg that limps comes first")


# Decision 422 M3: with danger near (the dead the tap helper stops for, or a fight
# with someone living) a hand weapon comes up on guard standing, and stays up a
# while after; a knife low with its point out, anything else (the bare fists too)
# up by the shoulder. Walking it walks; a gun or a bow, a hurt arm, full arms or
# crouching are as before.
func test_danger_near_a_hand_weapon_comes_up_on_guard() -> void:
	var own := _own()
	for clip_name in [Gait.READY_ONE, Gait.READY_STAB]:
		assert_gt(PersonVisual.clip_named(own, clip_name, -1), -1, clip_name + " is in the build")
	var field := StubField.new()
	var p := _person()
	var note := {}
	_hold(p, "crowbar")
	PersonVisual.motion_of(p, note, 0.1, [], own)
	PersonVisual.guard_note(field, p, note, 0.3)
	assert_eq(_drawn(p, note, own, false), PersonVisual.OWN_STAND, "nothing near: it stands")
	field.combat.near = true
	PersonVisual.guard_note(field, p, note, 0.3)
	assert_eq(_drawn(p, note, own, false), Gait.READY_ONE, "the dead near: on guard")
	_hold(p, "knife")
	assert_eq(_drawn(p, note, own, false), Gait.READY_STAB, "a knife: low, its point out")
	p.hands = []
	assert_eq(_drawn(p, note, own, false), Gait.READY_ONE, "bare fists: up")
	_hold(p, "crowbar")
	assert_eq(_drawn(p, note, own, true), "p_walk_axe", "walking it walks")
	for wid in ["shotgun", "pistol", "bow"]:
		_hold(p, wid)
		assert_eq(Gait.ready_name(p), "", wid + ": aimed its own way")
	_hold(p, "shotgun")
	PersonVisual.guard_note(field, p, note, 0.3)
	assert_eq(_drawn(p, note, own, false), PersonVisual.OWN_STAND, "a gun: it stands")
	# The danger gone, the guard stays up GUARD_HOLD and then comes down.
	_hold(p, "crowbar")
	PersonVisual.guard_note(field, p, note, 0.3)
	field.combat.near = false
	PersonVisual.guard_note(field, p, note, 0.3)
	assert_eq(_drawn(p, note, own, false), Gait.READY_ONE, "just gone: still on guard")
	for i in int(ceil(Gait.GUARD_HOLD / 0.1)):
		PersonVisual.motion_of(p, note, 0.1, [], own)
	assert_eq(_drawn(p, note, own, false), PersonVisual.OWN_STAND, "gone a while: it stands down")
	# A living foe is danger too, the dead or not.
	assert_false(Gait.threatened(field, p))
	p.target_person = _person("p_foe", "약탈자")
	assert_true(Gait.threatened(field, p))
	p.target_person = null
	# Crouched it keeps low; a hurt arm or full arms hold nothing up.
	field.combat.near = true
	PersonVisual.guard_note(field, p, note, 0.3)
	p.crouched = true
	assert_eq(_drawn(p, note, own, false), PersonVisual.OWN_CROUCH_STAND, "crouched it keeps low")
	p.crouched = false
	p.add_item("symbol_bell", 1)
	assert_eq(Gait.ready_name(p), "", "something big in the arms")
	p.items.clear()
	p.body.fracture(true, "arm_left")
	assert_eq(Gait.ready_name(p), "", "an arm too hurt to hold it up")


func test_each_person_has_their_own_beat_stride_and_lean() -> void:
	var a := _person("p_a", "가나")
	var b := _person("p_b", "다라마")
	assert_ne(Gait.first_step(a), Gait.first_step(b), "two people start the round at their own place")
	assert_ne(Gait.stride(a), Gait.stride(b))
	for p in [a, b]:
		assert_between(Gait.stride(p), Gait.STRIDE.x, Gait.STRIDE.y)
		assert_between(Gait.first_step(p), 0.0, 1.0)
		assert_between(Gait.posture(p, false), Gait.POSTURE.x, Gait.POSTURE.y)
		assert_almost_eq(Gait.posture(p, true), Gait.posture(p, false) * Gait.RUN_POSTURE, 0.0001, "running leans further")
	var again := _person("p_c", "가나")
	assert_eq(Gait.stride(again), Gait.stride(a), "the same person always has the same")
	assert_eq(Gait.first_step(again), Gait.first_step(a))


# The footsteps go by each one's own round: two to it, at its own stride, and
# from its own place before the first step (field_game.gd steps_in).
func test_the_footsteps_go_by_each_ones_own_round() -> void:
	var a := _person("p_a", "가나")
	var b := _person("p_b", "다라마")
	FieldGame.steps_in(a, 0.0)
	FieldGame.steps_in(b, 0.0)
	assert_almost_eq(float(a.brain["step_r"]), Gait.first_step(a), 0.0001, "a first step from its own place")
	assert_ne(float(a.brain["step_r"]), float(b.brain["step_r"]), "so two who set off together are not in step")
	var round_a: float = float(SimNoise.STEP_ROUND["walk"]) * Gait.stride(a)
	a.brain["step_r"] = 0.0
	assert_eq(FieldGame.steps_in(a, round_a * 0.1), 0)
	assert_eq(FieldGame.steps_in(a, round_a * 0.15), 1, "at 0.2 of its own round")
	assert_eq(FieldGame.steps_in(a, round_a * 0.75), 1, "the other at 0.65, the round done")
	assert_almost_eq(fposmod(float(a.brain["step_r"]) + 0.5, 1.0), 0.5, 0.0001, "back where it began")


# The lean comes on as it goes and goes as it stops, never at once.
func test_the_lean_comes_on_the_move_and_goes_standing() -> void:
	var p := _person("p_a", "가나")
	var note := {}
	PersonVisual.motion_of(p, note, 0.1, [])
	assert_eq(PersonVisual.lean_of(p, note), Basis(), "standing upright")
	p.moving = true
	p.position += Vector3(0.1, 0, 0)
	PersonVisual.motion_of(p, note, 0.05, [])
	var first := float(note["posture"])
	assert_between(first, 0.0, Gait.posture(p, false) * 0.5, "it starts to lean, not all at once")
	for i in 20:
		p.position += Vector3(0.1, 0, 0)
		PersonVisual.motion_of(p, note, 0.1, [])
	assert_almost_eq(float(note["posture"]), Gait.posture(p, false), 0.002)
	var lean := PersonVisual.lean_of(p, note)
	assert_almost_eq(lean.y.z, sin(Gait.posture(p, false)), 0.0001, "forward, by its own lean")
	p.moving = false
	for i in 20:
		PersonVisual.motion_of(p, note, 0.1, [])
	assert_almost_eq(float(note["posture"]), 0.0, 0.002, "upright again once it stops")
	p.fallen_t = 1.0
	assert_eq(PersonVisual.lean_of(p, note), Basis(), "none on the ground")
