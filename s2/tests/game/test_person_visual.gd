extends GutTest

const PersonVisual = preload("res://game/actors/person_visual.gd")
const Person = preload("res://game/actors/person.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const BodyBake = preload("res://scripts/body_bake.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")


func _person() -> Node3D:
	var p := Person.new()
	add_child_autofree(p)
	p.setup("p_test", "시험", "companion", Vector3.ZERO)
	return p


class _Field:
	var paused := false
	var ended := false


# Paused (the player's pause or the app away), the people stand still as the dead
# and the train do (user field test 10-25: they walked and breathed on through a
# pause); at the end, the train leaving, they go on.
func test_the_people_stand_still_while_the_field_is_paused() -> void:
	var field := _Field.new()
	assert_eq(PersonVisual.frame_delta(field, 0.1), 0.1)
	field.paused = true
	assert_eq(PersonVisual.frame_delta(field, 0.1), 0.0)
	var p := _person()
	var note := {}
	PersonVisual.motion_of(p, note, 0.1, [])
	var t: float = float(note["t"])
	PersonVisual.motion_of(p, note, PersonVisual.frame_delta(field, 0.5), [])
	assert_eq(float(note["t"]), t, "the clock of its motion stands")
	field.ended = true
	assert_eq(PersonVisual.frame_delta(field, 0.1), 0.1, "at the end it goes on")


func test_the_motion_follows_what_the_person_is_doing() -> void:
	var p := _person()
	var note := {}
	# Kept still: it stands.
	PersonVisual.motion_of(p, note, 0.1, [])
	assert_eq(int(PersonVisual.motion_of(p, note, 0.3, []).y), DeadBody.STAND)
	# Moving: walks; running: runs; spent: reels.
	p.position += Vector3(0.3, 0, 0)
	assert_eq(int(PersonVisual.motion_of(p, note, 0.1, []).y), 0)
	p.running = true
	p.position += Vector3(0.3, 0, 0)
	assert_eq(int(PersonVisual.motion_of(p, note, 0.1, []).y), DeadBody.RUN)
	# Knocked down it lies on its face; dead, on its back.
	p.body.downed = true
	assert_eq(int(PersonVisual.motion_of(p, note, 0.1, []).y), DeadBody.FALL_FRONT)
	p.body.dead = true
	assert_eq(int(PersonVisual.motion_of(p, note, 0.1, []).y), DeadBody.FALL)


func test_a_fall_plays_once_then_it_gets_up() -> void:
	var p := _person()
	var note := {}
	var clips := [{}, {}, {}, {}, {}, {}, {"length": 1.0}, {}, {}, {"length": 1.0}, {}, {"length": 1.0}]
	p.fallen_t = 1.0
	var start := PersonVisual.motion_of(p, note, 0.0, clips)
	var later := PersonVisual.motion_of(p, note, 0.5, clips)
	assert_eq(int(later.y), DeadBody.FALL_FRONT)
	assert_gt(later.x, start.x, "the fall goes on")
	assert_eq(PersonVisual.motion_of(p, note, 2.0, clips).x, 1.0, "and stays down at its end")
	p.fallen_t = 0.0
	assert_eq(int(PersonVisual.motion_of(p, note, 0.1, clips).y), DeadBody.RISE_FRONT, "then it gets up off its face")


func test_the_bodies_in_the_build_load_with_their_colour() -> void:
	for dir in [PersonVisual.FOLDER, PersonVisual.OWN_FOLDER, DeadBody.BUILT_IN]:
		var got := DeadBody.with_albedo(BodyBake.load_baked(dir), dir)
		assert_false(got.is_empty(), dir)
		assert_true(got.get("albedo") is Texture2D, "%s has its colour picture" % dir)


# Held by the dead the arms go out against them and the body leans back from
# one in front (bent under one behind) and twists; it does not walk on the spot.
func test_held_by_the_dead_it_pushes_back_and_twists() -> void:
	var p := _person()
	var note := {}
	PersonVisual.motion_of(p, note, 0.1, [])
	p.grabbers.append({"state": "grab"})
	p.grab_front = true
	var held := PersonVisual.motion_of(p, note, 0.1, [])
	assert_eq(int(held.y), DeadBody.LUNGE, "the arms out")
	assert_almost_eq(fposmod(held.x - DeadBody.REACH_AT + 0.5, 1.0) - 0.5, 0.0, DeadBody.REACH_SHIFT + 0.001, "held at the reach, not walking")
	var lean := PersonVisual.lean_of(p, note)
	assert_lt(lean.y.z, 0.0, "leaning back from the one in front")
	p.grab_front = false
	assert_gt(PersonVisual.lean_of(p, note).y.z, 0.0, "bent under one behind")
	p.grabbers.clear()
	assert_eq(PersonVisual.lean_of(p, note), Basis(), "let go, upright")


# A new wound throws the body back in the struck pose for a moment; a bite
# furthest. Then it is as it was.
func test_a_bite_throws_the_body_back_for_a_moment() -> void:
	var p := _person()
	var note := {}
	PersonVisual.motion_of(p, note, 0.1, [])
	p.body.apply_bite(RandomNumberGenerator.new(), "arm_right", 0.0)
	assert_eq(int(PersonVisual.motion_of(p, note, 0.0, []).y), DeadBody.HIT, "struck")
	var bitten: float = PersonVisual.lean_of(p, note).y.z
	assert_lt(bitten, 0.0, "thrown back")
	p.body.apply_scratch(RandomNumberGenerator.new(), 0.0, "torso")
	PersonVisual.motion_of(p, note, 0.0, [])
	assert_gt(PersonVisual.lean_of(p, note).y.z, bitten, "a scratch throws it less")
	PersonVisual.motion_of(p, note, PersonVisual.HURT_TIME + 0.1, [])
	assert_ne(int(PersonVisual.motion_of(p, note, 0.1, []).y), DeadBody.HIT, "and then it stands again")
	assert_eq(PersonVisual.lean_of(p, note), Basis())


# Crouched it stands low (held in the drop before a run, breathing) and walks
# the bent shuffle, where the build has no living motions of its own.
func test_crouched_it_is_low_without_the_living_motions() -> void:
	var p := _person()
	var note := {}
	p.crouched = true
	PersonVisual.motion_of(p, note, 0.1, [])
	var low := PersonVisual.motion_of(p, note, 0.3, [])
	assert_eq(int(low.y), DeadBody.TELL, "stands low")
	assert_between(low.x, PersonVisual.CROUCH_LOW.x, PersonVisual.CROUCH_LOW.y)
	p.position += Vector3(0.3, 0, 0)
	assert_eq(int(PersonVisual.motion_of(p, note, 0.1, []).y), PersonVisual.CROUCH_WALK, "the bent shuffle")


func _own() -> Array:
	return BodyBake.load_baked(PersonVisual.OWN_FOLDER).get("clips", [])


func _named(own: Array, c: Vector2) -> String:
	return String(own[int(c.y)].get("name", ""))


# With the living's own folder they walk, run, stand and crouch in their own
# motions; what they have none of yet (reeling spent, the falls) is the dead's.
func test_the_living_walk_run_stand_and_crouch_in_their_own_motions() -> void:
	var own := _own()
	assert_gt(own.size(), 10, "the living's folder is in the build")
	var p := _person()
	var note := {}
	PersonVisual.motion_of(p, note, 0.1, [], own)
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.3, [], own)), PersonVisual.OWN_STAND)
	assert_true(PersonVisual.is_own(note))
	p.position += Vector3(0.3, 0, 0)
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), PersonVisual.OWN_WALK)
	p.running = true
	p.position += Vector3(0.3, 0, 0)
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), PersonVisual.OWN_RUN)
	p.running = false
	p.crouched = true
	p.position += Vector3(0.3, 0, 0)
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), PersonVisual.OWN_CROUCH_WALK)
	PersonVisual.motion_of(p, note, 0.3, [], own)
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), PersonVisual.OWN_CROUCH_STAND)
	p.crouched = false
	p.body.exhaustion = 0.9
	p.position += Vector3(0.3, 0, 0)
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), PersonVisual.OWN_SPENT, "spent, it reels")
	assert_true(PersonVisual.is_own(note))
	PersonVisual.motion_of(p, note, 0.3, [], own)
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), PersonVisual.OWN_SPENT, "and stopping for breath it does not stand up straight")
	p.fallen_t = 1.0
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), PersonVisual.OWN_FALL_FRONT, "and falls on its face")
	assert_true(PersonVisual.is_own(note))


# Held, bitten and shoving are the living's own too: the held motion twists by
# itself (only the lean is added), the bite plays once, the shove in its time.
func test_held_bitten_and_the_shove_in_their_own_motions() -> void:
	var own := _own()
	var p := _person()
	var note := {}
	PersonVisual.motion_of(p, note, 0.1, [], own)
	p.grabbers.append({"state": "grab"})
	p.grab_front = true
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), PersonVisual.OWN_HELD)
	var lean := PersonVisual.lean_of(p, note)
	assert_lt(lean.y.z, 0.0, "leaning back from the one in front")
	assert_almost_eq(lean.x.y, 0.0, 0.0001, "no twist added on top")
	p.body.apply_bite(RandomNumberGenerator.new(), "arm_right", 0.0)
	var bite := PersonVisual.motion_of(p, note, 0.0, [], own)
	# The one holding it has no place here: from in front (decision 422: its own flinch).
	assert_eq(_named(own, bite), PersonVisual.OWN_BITTEN_FRONT, "the flinch, even held")
	assert_almost_eq(bite.x, 0.0, 0.001, "from its start")
	assert_gt(PersonVisual.motion_of(p, note, 0.3, [], own).x, 0.4)
	PersonVisual.motion_of(p, note, 0.4, [], own)
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), PersonVisual.OWN_HELD, "then held again")
	p.grabbers.clear()
	var wind: float = PersonVisual.Pose.SHOVE_WINDUP / float(p.mults()["swing"])
	p.shove_t = wind
	var shove := PersonVisual.motion_of(p, note, 0.1, [], own)
	assert_eq(_named(own, shove), PersonVisual.OWN_SHOVE)
	assert_almost_eq(shove.x, 0.0, 0.001, "drawn back from the start of the wind-up")
	p.shove_t = wind * 0.5
	assert_almost_eq(PersonVisual.motion_of(p, note, 0.1, [], own).x, PersonVisual.SHOVE_OUT.x * 0.5, 0.001)
	p.shove_t = 0.0
	p.lunge_t = PersonVisual.Pose.LUNGE
	assert_almost_eq(PersonVisual.motion_of(p, note, 0.1, [], own).x, PersonVisual.SHOVE_OUT.x, 0.001, "out as it lands")
	p.lunge_t = PersonVisual.Pose.LUNGE * 0.5
	assert_almost_eq(PersonVisual.motion_of(p, note, 0.1, [], own).x, lerpf(PersonVisual.SHOVE_OUT.x, PersonVisual.SHOVE_OUT.y, 0.5), 0.001, "coming back")
	assert_eq(PersonVisual.SHOVE_OUT.y, 1.0, "the whole shove is seen, back to where it started")


# Two people standing do not breathe together.
func test_people_stand_each_at_their_own_place_and_pace() -> void:
	var a := _person()
	var b := Person.new()
	add_child_autofree(b)
	b.setup("p_other", "다른이", "companion", Vector3(3, 0, 0))
	var na := {}
	var nb := {}
	for i in 3:
		PersonVisual.motion_of(a, na, 0.2, [])
		PersonVisual.motion_of(b, nb, 0.2, [])
	assert_ne(PersonVisual.motion_of(a, na, 0.1, []).x, PersonVisual.motion_of(b, nb, 0.1, []).x)


# A melee blow is the living's own: a knife stabs, an axe (and any blow at a
# body on the ground) comes down, the rest swing across; drawn back to where
# the blow lands over the wind-up, the rest on the way back. A stomp has none.
func test_a_blow_is_the_living_own_swing() -> void:
	var own := _own()
	var p := _person()
	for want in [["knife", "p_stab", 0.35], ["axe", "p_swing_axe", 0.45], ["crowbar", "p_swing_one", 0.45]]:
		p.hands = [{"id": want[0], "quality": "factory", "condition": 1.0, "loaded": 0}]
		p.strike_kind = "swing"
		p.strike_at = {"state": "chase"}
		p.strike_total = 0.4
		p.strike_t = 0.4
		var start := PersonVisual.blow_of(p, own)
		assert_eq(String(own[int(start.y)]["name"]), want[1], want[0])
		assert_almost_eq(start.x, 0.0, 0.001, "drawn back from the start")
		p.strike_t = 0.1
		assert_almost_eq(PersonVisual.blow_of(p, own).x, float(want[2]) * 0.75, 0.001)
		p.strike_t = 0.0
		p.swing_t = 0.3
		assert_almost_eq(PersonVisual.blow_of(p, own).x, float(want[2]), 0.001, "the blow lands")
		p.swing_t = 0.15
		assert_almost_eq(PersonVisual.blow_of(p, own).x, float(want[2]) + (1.0 - float(want[2])) * 0.5, 0.001, "half way back")
		p.swing_t = 0.0
		PersonVisual.blow_of(p, own)
	p.strike_at = {"state": "downed"}
	p.strike_t = 0.4
	assert_eq(String(own[int(PersonVisual.blow_of(p, own).y)]["name"]), "p_floor_strike", "down at a body on the ground")
	p.strike_t = 0.0
	p.swing_t = 0.3
	assert_almost_eq(PersonVisual.blow_of(p, own).x, 0.5, 0.001, "it lands in front of the feet")
	p.swing_t = 0.0
	PersonVisual.blow_of(p, own)
	p.strike_kind = "stomp"
	p.strike_t = 0.4
	assert_eq(String(own[int(PersonVisual.blow_of(p, own).y)]["name"]), "p_stomp", "a stomp of its own")
	p.strike_kind = "swing"
	p.strike_at = {}
	var note := {}
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), "p_swing_one", "a swing at the air too")
	assert_true(PersonVisual.is_own(note))


# Blow after blow goes through each weapon's ways, so the same one is not seen
# twice running; after a rest the next starts again from the first.
func test_blow_after_blow_goes_through_the_ways() -> void:
	var own := _own()
	var p := _person()
	p.strike_kind = "swing"
	p.strike_at = {"state": "chase"}
	for want in [["crowbar", ["p_swing_one", "p_swing_back", "p_swing_axe", "p_swing_one"]],
			["knife", ["p_stab", "p_swing_one", "p_stab", "p_swing_one"]],
			["axe", ["p_swing_axe", "p_chop_side", "p_swing_axe", "p_chop_side"]]]:
		p.hands = [{"id": want[0], "quality": "factory", "condition": 1.0, "loaded": 0}]
		var note := {}
		var seen: Array = []
		var t := 0.0
		for i in 4:
			p.strike_total = 0.2
			p.strike_t = 0.2
			seen.append(_named(own, PersonVisual.blow_of(p, own, note, t)))
			p.strike_t = 0.0
			p.swing_t = 0.3
			assert_eq(_named(own, PersonVisual.blow_of(p, own, note, t + 0.2)), seen[-1], "the same way back as it went")
			p.swing_t = 0.0
			PersonVisual.blow_of(p, own, note, t + 0.5)
			t += 0.6
		assert_eq(seen, want[1], want[0])
		p.strike_t = 0.2
		assert_eq(_named(own, PersonVisual.blow_of(p, own, note, t - 0.1 + PersonVisual.CHAIN_GAP + 0.5)), want[1][0], "after a rest, the first again")
		p.strike_t = 0.0
		p.swing_t = 0.0
		PersonVisual.blow_of(p, own, note, t + 5.0)
	# A body baked before the second way was added swings its first again.
	var older: Array = own.filter(func(c): return String(c.get("name", "")) != "p_swing_back")
	p.hands = [{"id": "crowbar", "quality": "factory", "condition": 1.0, "loaded": 0}]
	var gone := {"blow_n": 0, "blow_end": 0.0}
	p.strike_t = 0.2
	assert_eq(_named(older, PersonVisual.blow_of(p, older, gone, 0.5)), "p_swing_one", "no p_swing_back: the first way")
	# The axe's chop from the side stops its way back with the axe low, before the loop lifts it again.
	p.strike_t = 0.0
	p.swing_t = 0.0
	PersonVisual.blow_of(p, own, gone, 1.0)
	p.hands = [{"id": "axe", "quality": "factory", "condition": 1.0, "loaded": 0}]
	gone = {"blow_n": 0, "blow_end": 1.0}
	p.strike_t = 0.2
	assert_eq(_named(own, PersonVisual.blow_of(p, own, gone, 1.5)), "p_chop_side")
	p.strike_t = 0.0
	p.swing_t = 0.3
	assert_almost_eq(PersonVisual.blow_of(p, own, gone, 1.6).x, 0.16, 0.001, "where it lands")
	p.swing_t = 0.003
	assert_almost_eq(PersonVisual.blow_of(p, own, gone, 1.9).x, 0.45, 0.01, "the axe low, not lifted again")


# The weapon goes in the worn body's right hand: hanging at the side the head
# points forward; with the arms thrust out (the shove) the head points up.
func test_the_weapon_sits_in_the_baked_right_hand() -> void:
	var baked := BodyBake.load_baked(PersonVisual.OWN_FOLDER)
	var arm := PersonVisual.hand_of(baked)
	assert_gt((arm["hand"] as PackedInt32Array).size(), 5, "the hand")
	assert_gt((arm["elbow"] as PackedInt32Array).size(), 3, "the elbow")
	var table := PersonVisual.arm_table(baked, arm["hand"], arm["elbow"])
	var frames := DeadBody.table_of(baked)
	var clips: Array = baked["clips"]
	var stand := Color(0.0, PersonVisual.clip_named(clips, PersonVisual.OWN_STAND, -1), 1.0, 1.0)
	var at := PersonVisual.arm_at(table, frames, stand)
	assert_lt(at[0].x, -0.2, "on the right (-x, the body facing +z)")
	assert_between(at[0].y, 0.5, 1.0, "at the hip")
	assert_lt(at[0].y, at[1].y, "hanging below the elbow")
	assert_gt(PersonVisual.grip_of(at[0], at[1], Basis()).z.z, 0.8, "hanging, the head forward")
	var out := PersonVisual.arm_at(table, frames, Color(0.4, PersonVisual.clip_named(clips, PersonVisual.OWN_SHOVE, -1), 1.0, 1.0))
	assert_gt(out[0].z, 0.5, "thrust out")
	assert_gt(PersonVisual.grip_of(out[0], out[1], Basis()).z.y, 0.8, "the head up")
	var turned := PersonVisual.grip_of(out[0], out[1], PersonVisual.grip_of(at[0], at[1], Basis()))
	assert_between(turned.z.y, 0.1, 0.95, "it turns part way in one frame, not all at once")


# A job of the hands plays the living's own: rummaging at the height of the
# work, kneeling for work on the ground, a bandage, a bar worked at, the pickaxe
# coming down in front of the feet over and over, a window broken with one blow
# over the try, a door kicked with the foot landing as the try ends. Climbing
# has none of its own.
func test_a_job_of_the_hands_is_the_living_own() -> void:
	var own := _own()
	var p := _person()
	# A splint takes a stick and a cloth and a break to set (body_injury 4.6 도구:
	# 부목(막대 + 천)); without them it does not start.
	p.items = {"plank": 1, "cloth": 1}
	p.body.fracture(false)
	# Treating itself, at its worst wound: the broken leg (decision 422).
	for want in [["search", "p_search_mid"], ["door", "p_search_mid"], ["pry", "p_pry"], ["swap", "p_search_mid"],
			["loot", "p_kneel_work"], ["fire", "p_kneel_work"], ["snow", "p_search_low"], ["treat", "p_treat_leg"],
			["splint", "p_kneel_work"], ["lid", "p_kneel_work"], ["dig", "p_floor_strike"], ["window", "p_swing_one"],
			["kick", "p_kick"]]:
		p.start_action(want[0], "시험", 2.0, func() -> void: pass)
		var note := {}
		var c := PersonVisual.motion_of(p, note, 0.1, [], own)
		assert_eq(_named(own, c), want[1], want[0])
		assert_true(PersonVisual.is_own(note), want[0])
	p.start_action("window", "창 깨기", 1.0, func() -> void: pass)
	p.action_t = 0.25
	assert_almost_eq(PersonVisual.work_of(p, {}, 0.0, own).x, 0.75, 0.001, "one blow over the try")
	p.start_action("kick", "문 차기", 1.0, func() -> void: pass)
	assert_almost_eq(PersonVisual.work_of(p, {}, 0.0, own).x, 0.0, 0.001, "standing ready")
	p.action_t = PersonVisual.KICK_WIND * 0.5
	assert_almost_eq(PersonVisual.work_of(p, {}, 0.0, own).x, 0.2, 0.001, "the leg coming up")
	p.action_t = 0.001
	assert_almost_eq(PersonVisual.work_of(p, {}, 0.0, own).x, 0.4, 0.01, "the foot lands as the try ends")
	p.start_action("climb", "시험", 2.0, func() -> void: pass)
	assert_eq(PersonVisual.work_of(p, {}, 0.0, own).y, -1.0, "climb")
	p.cancel_action()
	assert_eq(PersonVisual.work_of(p, {}, 0.0, own).y, -1.0, "the job is over")

# Aimed standing still, a handgun is held out in one hand and a long gun up at
# the shoulder, the gun in the hand; on the move, or with a bow, the gun is held
# as before.
func test_a_gun_is_aimed_in_the_living_own() -> void:
	var own := _own()
	var p := _person()
	var note := {}
	for want in [["pistol", "p_aim_one"], ["shotgun", "p_aim_two"]]:
		p.hands = [{"id": want[0], "quality": "factory", "condition": 1.0, "loaded": 1}]
		p.aim.active = true
		PersonVisual.motion_of(p, note, 0.3, [], own)
		assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), want[1], want[0])
		assert_true(PersonVisual.aiming(note, own), want[0])
	p.position += Vector3(0.3, 0, 0)
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), "p_walk_long", "on the move: the long gun's own walk (gait.gd)")
	assert_false(PersonVisual.aiming(note, own))
	p.hands = [{"id": "bow", "quality": "factory", "condition": 1.0, "loaded": 1}]
	assert_eq(PersonVisual.aim_of(p, own), -1, "no aim of its own with a bow")
	p.aim.active = false
	p.hands = [{"id": "pistol", "quality": "factory", "condition": 1.0, "loaded": 1}]
	assert_eq(PersonVisual.aim_of(p, own), -1, "not aimed")


# Loading or clearing a handgun standing still is the living's own: a load once
# over the gun's loading time, the gun in the hand; crouched, a long gun or a bow
# is held as before.
func test_a_gun_is_loaded_in_the_living_own() -> void:
	var own := _own()
	var p := _person()
	p.hands = [{"id": "pistol", "quality": "factory", "condition": 1.0, "loaded": 0}]
	var total := float(PersonVisual.Pose.W.get_data("pistol").get("reload", 1.0))
	p.reload_t = total * 0.5
	var note := {}
	PersonVisual.motion_of(p, note, 0.3, [], own)
	var c := PersonVisual.motion_of(p, note, 0.1, [], own)
	assert_eq(_named(own, c), PersonVisual.OWN_RELOAD)
	assert_almost_eq(c.x, 0.5, 0.001, "half way through the load")
	assert_true(PersonVisual.loading(note, own))
	p.reload_t = 0.0
	p.jam_t = 1.0
	assert_eq(_named(own, PersonVisual.reload_of(p, {}, 0.5, own)), PersonVisual.OWN_RELOAD, "a jam cleared")
	p.jam_t = 0.0
	p.hands = [{"id": "shotgun", "quality": "factory", "condition": 1.0, "loaded": 0}]
	p.reload_t = 0.35
	assert_eq(PersonVisual.reload_of(p, {}, 0.5, own).y, -1.0, "a long gun as before")
	p.hands = [{"id": "pistol", "quality": "factory", "condition": 1.0, "loaded": 0}]
	p.crouched = true
	assert_eq(PersonVisual.reload_of(p, {}, 0.5, own).y, -1.0, "crouched it stays low")
	p.crouched = false
	p.hands = [{"id": "bow", "quality": "factory", "condition": 1.0, "loaded": 0}]
	assert_eq(PersonVisual.reload_of(p, {}, 0.5, own).y, -1.0, "a bow nocks as before")


# Crouched it keeps low: chest-high work is done low, and a gun is aimed
# without standing up.
func test_crouched_it_works_and_aims_low() -> void:
	var own := _own()
	var p := _person()
	p.crouched = true
	for job in ["search", "pry"]:
		p.start_action(job, "시험", 2.0, func() -> void: pass)
		assert_eq(_named(own, PersonVisual.motion_of(p, {}, 0.1, [], own)), "p_search_low", job)
	p.cancel_action()
	p.hands = [{"id": "pistol", "quality": "factory", "condition": 1.0, "loaded": 1}]
	p.aim.active = true
	assert_eq(PersonVisual.aim_of(p, own), -1)
	var note := {}
	PersonVisual.motion_of(p, note, 0.3, [], own)
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), PersonVisual.OWN_CROUCH_STAND)


# Down, dragging itself, getting up and dying in the living's own (people folder
# 16 on): it lies on its face, crawls, stays down where it stops (it does not
# fall again), gets up off its face; dead it goes over on its back.
func test_down_crawling_and_up_again_in_the_living_own() -> void:
	var own := _own()
	var p := _person()
	var note := {}
	PersonVisual.motion_of(p, note, 0.3, [], own)
	p.body.downed = true
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), PersonVisual.OWN_FALL_FRONT)
	PersonVisual.motion_of(p, note, 2.0, [], own)
	p.position += Vector3(0.2, 0, 0)
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), PersonVisual.OWN_CRAWL, "drags itself")
	var still := PersonVisual.motion_of(p, note, 0.1, [], own)
	assert_eq(_named(own, still), PersonVisual.OWN_FALL_FRONT)
	assert_almost_eq(still.x, 1.0, 0.001, "down already, not falling again")
	p.body.downed = false
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), PersonVisual.OWN_RISE_FRONT, "up off its face")
	assert_true(PersonVisual.is_own(note))
	PersonVisual.motion_of(p, note, 2.0, [], own)
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), PersonVisual.OWN_STAND)
	p.body.dead = true
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), PersonVisual.OWN_FALL, "dead, on its back")


# Half of the people (by name, decision 412) slump on their face instead, knocked
# down or dead, and get up off their face; the other half fall as before.
func test_half_of_the_people_slump_on_their_face_instead() -> void:
	var own := _own()
	var p := _person()
	var slumps := 0
	for n in 40:
		p.pid = "p_%d" % n
		if PersonVisual.fall_name(p, own) == PersonVisual.OWN_FALL_SLUMP:
			slumps += 1
	assert_between(slumps, 12, 28, "about half")
	var n := 0
	p.pid = "p_0"
	while PersonVisual.fall_name(p, own) != PersonVisual.OWN_FALL_SLUMP:
		n += 1
		p.pid = "p_%d" % n
	var note := {}
	PersonVisual.motion_of(p, note, 0.3, [], own)
	p.body.downed = true
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), PersonVisual.OWN_FALL_SLUMP)
	PersonVisual.motion_of(p, note, 2.0, [], own)
	p.position += Vector3(0.2, 0, 0)
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), PersonVisual.OWN_CRAWL, "drags itself")
	var still := PersonVisual.motion_of(p, note, 0.1, [], own)
	assert_eq(_named(own, still), PersonVisual.OWN_FALL_SLUMP)
	assert_almost_eq(still.x, 1.0, 0.001, "down already, not falling again")
	p.body.downed = false
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), PersonVisual.OWN_RISE_FRONT, "up off its face")
	PersonVisual.motion_of(p, note, 2.0, [], own)
	p.body.dead = true
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), PersonVisual.OWN_FALL_SLUMP, "dead, on its face")
	# A folder without it: as before.
	var older: Array = own.filter(func(c): return String(c.get("name", "")) != PersonVisual.OWN_FALL_SLUMP)
	assert_eq(PersonVisual.fall_name(p, older), PersonVisual.OWN_FALL)


# From motion 16 on the colour carries the shader's upper half; the easing and
# the hand read it back as the same motion.
func test_motions_from_sixteen_on_are_packed_for_the_shader() -> void:
	var c := DeadBody.packed(Color(0.5, 17.0, 1.0, 1.0), 17, 300, 20.0)
	assert_eq(c.g, VatBaker.pack_motion(17, 300, 20))
	assert_eq(DeadBody.motion_in(c.g), 17)
	assert_eq(DeadBody.motion_in(DeadBody.packed(Color(0, 5, 1, 1), 5, 40, 3.0).g), 5, "below sixteen as before")
	assert_eq(DeadBody.packed(Color(0, 5, 1, 1), 5, 40, 3.0).g, 5.0 + 16.0 * 40.0 + 65536.0 * 3.0)
	var baked := BodyBake.load_baked(PersonVisual.OWN_FOLDER)
	var arm := PersonVisual.hand_of(baked)
	var table := PersonVisual.arm_table(baked, arm["hand"], arm["elbow"])
	var frames := DeadBody.table_of(baked)
	var front := PersonVisual.clip_named(baked["clips"], PersonVisual.OWN_FALL_FRONT, -1)
	var down := PersonVisual.arm_at(table, frames, DeadBody.packed(Color(1.0, front, 1.0, 1.0), front, 0, 0.0))
	assert_lt(down[0].y, 0.5, "the hand of a body lying on its face is near the ground")


# Decision 422, first set, in the living's own folder (the shader has sixty-four
# places now): every one there by name, the quick ones with every frame, the
# limps covering ground and nothing else, a hand to where it hurts ending as it
# began; and the hand of one past thirty-two read back through the packing.
func test_the_first_set_of_decision_422_is_in_the_living_own() -> void:
	var names := ["p_search_high", "p_limp_light_l", "p_limp_light_r", "p_limp_heavy_l", "p_limp_heavy_r",
		"p_treat_arm", "p_treat_leg", "p_treat_head", "p_bitten_front", "p_bitten_back", "p_shiver",
		"p_pain_head", "p_pain_torso", "p_pain_arm", "p_pain_leg", "p_tired_stretch"]
	var baked := BodyBake.load_baked(PersonVisual.OWN_FOLDER)
	var clips: Array = baked["clips"]
	assert_eq(clips.size(), BodyBake.PERSON_CLIPS.size())
	for name: String in names:
		var n := PersonVisual.clip_named(clips, name, -1)
		assert_gt(n, -1, name)
		var clip: Dictionary = clips[n]
		if BodyBake.PERSON_KEEP.has(name):
			assert_eq(int(clip["frames"]), 24, name + " keeps every frame")
		assert_eq(float(clip["round"]) > 0.0, name.begins_with("p_limp"), name + " covers ground only if it limps")
	for name in ["p_pain_head", "p_pain_torso", "p_pain_arm", "p_pain_leg", "p_tired_stretch"]:
		var clip: Dictionary = clips[PersonVisual.clip_named(clips, name, -1)]
		var img: Image = baked["image"]
		var worst := 0
		for x in img.get_width():
			var a := img.get_pixel(x, int(clip["start"]))
			var b := img.get_pixel(x, int(clip["start"]) + int(clip["frames"]) - 1)
			worst = maxi(worst, roundi(maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) * 255.0))
		assert_lte(worst, 1, name + " ends as it began")
	var arm := PersonVisual.hand_of(baked)
	var table := PersonVisual.arm_table(baked, arm["hand"], arm["elbow"])
	var frames := DeadBody.table_of(baked)
	var treat := PersonVisual.clip_named(clips, "p_treat_leg", -1)
	assert_gt(treat, 32, "past thirty-two")
	var low := PersonVisual.arm_at(table, frames, DeadBody.packed(Color(0.0, treat, 1.0, 1.0), treat, 5, 10.0))
	var plain := PersonVisual.arm_at(table, frames, DeadBody.packed(Color(0.0, treat, 1.0, 1.0), treat, 0, 0.0))
	assert_lt(plain[0].y, 0.7, "the hands are down at the shin")
	assert_true(low[0].is_finite(), "a frame and share on top read back")


# Decision 422, second set: carrying each kind of weapon keeps the legs of the
# plain walk and run (the same ground a round, so the move pace picks them with
# no slide), and the three guards and the weak-hand hold stay on the spot.
func test_the_second_set_of_decision_422_is_in_the_living_own() -> void:
	var baked := BodyBake.load_baked(PersonVisual.OWN_FOLDER)
	var clips: Array = baked["clips"]
	var round_of := func(name: String) -> float:
		var n := PersonVisual.clip_named(clips, name, -1)
		assert_gt(n, -1, name)
		if n < 0:
			return -1.0
		assert_true(bool(clips[n]["loop"]), name + " loops")
		return float(clips[n]["round"])
	var walk: float = round_of.call("p_walk")
	var run: float = round_of.call("p_run")
	for name in ["p_walk_long", "p_walk_axe", "p_walk_pistol"]:
		assert_almost_eq(round_of.call(name), walk, walk * 0.05, name + " covers what the walk does")
	for name in ["p_run_long", "p_run_pistol"]:
		assert_almost_eq(round_of.call(name), run, run * 0.05, name + " covers what the run does")
	for name in ["p_ready_one", "p_ready_two", "p_ready_stab", "p_hold_weak"]:
		assert_eq(round_of.call(name), 0.0, name + " stays on the spot")


func test_the_putting_on_motions_and_the_garments_over_the_living_own() -> void:
	var baked := BodyBake.load_baked(PersonVisual.OWN_FOLDER)
	var clips: Array = baked["clips"]
	for name in ["p_wear_outer", "p_wear_head", "p_wear_hands"]:
		var n := PersonVisual.clip_named(clips, name, -1)
		assert_gt(n, -1, name)
		if n > -1:
			assert_false(bool(clips[n]["loop"]), name + " is played once")
	# Each garment is baked with the same motions, so it is drawn with the body's motion and frame.
	var line_up := func(list: Array) -> Array:
		var out := []
		for clip: Dictionary in list:
			out.append([clip["name"], clip["start"], clip["frames"], clip["loop"], clip["length"]])
		return out
	for kind: String in BodyBake.SHELLS:
		var worn := BodyBake.load_baked(PersonVisual.OWN_FOLDER.path_join("wear").path_join(kind))
		assert_false(worn.is_empty(), kind)
		if worn.is_empty():
			continue
		assert_eq(int(worn["height"]), int(baked["height"]), kind)
		assert_lt(int(worn["vertices"]), int(baked["vertices"]), kind + " covers a part of the body")
		assert_eq(line_up.call(worn["clips"]), line_up.call(clips), kind + " lines up with the body")
	assert_true(PersonVisual.hands_marked(baked["mesh"]), "the hands marked for the shader's gloves")
