extends GutTest

const PersonVisual = preload("res://game/actors/person_visual.gd")
const Person = preload("res://game/actors/person.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const BodyBake = preload("res://scripts/body_bake.gd")


func _person() -> Node3D:
	var p := Person.new()
	add_child_autofree(p)
	p.setup("p_test", "시험", "companion", Vector3.ZERO)
	return p


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
	assert_eq(int(PersonVisual.motion_of(p, note, 0.1, [], own).y), DeadBody.STAGGER, "spent, it reels as the dead do")
	assert_false(PersonVisual.is_own(note))
	PersonVisual.motion_of(p, note, 0.3, [], own)
	assert_eq(int(PersonVisual.motion_of(p, note, 0.1, [], own).y), DeadBody.STAGGER, "and stopping for breath it does not stand up straight")
	p.fallen_t = 1.0
	assert_eq(int(PersonVisual.motion_of(p, note, 0.1, [], own).y), DeadBody.FALL_FRONT, "and falls as they do")
	assert_false(PersonVisual.is_own(note))


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
	assert_eq(_named(own, bite), PersonVisual.OWN_BITTEN, "the flinch, even held")
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
	assert_eq(String(own[int(PersonVisual.blow_of(p, own).y)]["name"]), "p_swing_axe", "down at a body on the ground")
	p.strike_kind = "stomp"
	p.strike_t = 0.4
	assert_eq(PersonVisual.blow_of(p, own).y, -1.0, "no stomp of its own yet")
	p.strike_kind = "swing"
	p.strike_at = {}
	var note := {}
	assert_eq(_named(own, PersonVisual.motion_of(p, note, 0.1, [], own)), "p_swing_one", "a swing at the air too")
	assert_true(PersonVisual.is_own(note))


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
	assert_gt(at[0].x, 0.2, "on the right")
	assert_between(at[0].y, 0.5, 1.0, "at the hip")
	assert_lt(at[0].y, at[1].y, "hanging below the elbow")
	assert_gt(PersonVisual.grip_of(at[0], at[1], Basis()).z.z, 0.8, "hanging, the head forward")
	var out := PersonVisual.arm_at(table, frames, Color(0.4, PersonVisual.clip_named(clips, PersonVisual.OWN_SHOVE, -1), 1.0, 1.0))
	assert_gt(out[0].z, 0.5, "thrust out")
	assert_gt(PersonVisual.grip_of(out[0], out[1], Basis()).z.y, 0.8, "the head up")
	var turned := PersonVisual.grip_of(out[0], out[1], PersonVisual.grip_of(at[0], at[1], Basis()))
	assert_between(turned.z.y, 0.1, 0.95, "it turns part way in one frame, not all at once")
