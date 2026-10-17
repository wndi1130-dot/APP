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
	for dir in [PersonVisual.FOLDER, DeadBody.BUILT_IN]:
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
# the bent shuffle; the folder's own living motions win once it has them.
func test_crouched_it_is_low_and_the_living_motions_are_used_when_there() -> void:
	var p := _person()
	var note := {}
	p.crouched = true
	PersonVisual.motion_of(p, note, 0.1, [])
	var low := PersonVisual.motion_of(p, note, 0.3, [])
	assert_eq(int(low.y), DeadBody.TELL, "stands low")
	assert_between(low.x, PersonVisual.CROUCH_LOW.x, PersonVisual.CROUCH_LOW.y)
	p.position += Vector3(0.3, 0, 0)
	assert_eq(int(PersonVisual.motion_of(p, note, 0.1, []).y), PersonVisual.CROUCH_WALK, "the bent shuffle")
	var clips: Array = []
	for n in 15:
		clips.append({"name": "x%d" % n, "length": 1.0})
	for own in [PersonVisual.OWN_WALK, PersonVisual.OWN_RUN, PersonVisual.OWN_STAND, PersonVisual.OWN_CROUCH_WALK, PersonVisual.OWN_CROUCH_STAND]:
		clips.append({"name": own, "length": 1.0, "round": 2.0})
	p.position += Vector3(0.3, 0, 0)
	assert_eq(int(PersonVisual.motion_of(p, note, 0.1, clips).y), 18, "its own crouched walk")
	p.crouched = false
	p.position += Vector3(0.3, 0, 0)
	assert_eq(int(PersonVisual.motion_of(p, note, 0.1, clips).y), 15, "its own walk")
	p.running = true
	p.position += Vector3(0.3, 0, 0)
	assert_eq(int(PersonVisual.motion_of(p, note, 0.1, clips).y), 16, "its own run")
	p.running = false
	PersonVisual.motion_of(p, note, 0.3, clips)
	assert_eq(int(PersonVisual.motion_of(p, note, 0.1, clips).y), 17, "its own stand")


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
