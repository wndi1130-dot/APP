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
