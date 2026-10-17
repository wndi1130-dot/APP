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
	assert_eq(int(PersonVisual.motion_of(p, note, 0.1, clips).y), DeadBody.RISE, "then it gets up")


func test_the_bodies_in_the_build_load_with_their_colour() -> void:
	for dir in [PersonVisual.FOLDER, DeadBody.BUILT_IN]:
		var got := DeadBody.with_albedo(BodyBake.load_baked(dir), dir)
		assert_false(got.is_empty(), dir)
		assert_true(got.get("albedo") is Texture2D, "%s has its colour picture" % dir)
