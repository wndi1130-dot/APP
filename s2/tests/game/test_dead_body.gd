extends GutTest

const DeadBody = preload("res://game/actors/dead_body.gd")
const BodyBake = preload("res://scripts/body_bake.gd")
const Motion = preload("res://game/sim/motion.gd")
const DeadPose = preload("res://game/actors/dead_pose.gd")


func before_each() -> void:
	DeadBody.rounds = {}
	DeadBody.table = []


func _body(state: String = "wander") -> Dictionary:
	return {"state": state, "phase": 0.37, "crawl": false, "age": 10.0, "pos": Vector3(3, 0, 4), "t": 0.0}


func test_with_no_baked_folder_there_is_no_body_and_the_boxes_are_told_what_they_were() -> void:
	OS.set_environment(DeadBody.FOLDER_ENV, "user://no_such_dead_body")
	assert_true(DeadBody.assets().is_empty())
	OS.set_environment(DeadBody.FOLDER_ENV, "")
	for state in ["wander", "investigate", "chase", "attack", "grab", "downed", "rising", "dead", "frozen", "waking", "climb"]:
		var z := _body(state)
		var clip := 1.0 if state in ["chase", "attack", "grab"] else 0.0
		assert_eq(DeadBody.custom(z, 0.6, 1.0, 0.8, false), Color(0.37, clip, 1.0, 0.8), state)
		assert_false(DeadBody.falls_by_motion(z, false), "the boxes are laid down whole")
		assert_false(z.has("body_at"), "and nothing is noted on the body")
	# A box changing what it does is told nothing more, even with a baked table about.
	DeadBody.table = [[0, 32, true], [32, 32, true]]
	var box := _body("wander")
	DeadBody.custom(box, 0.0, 0.0, 0.8, false)
	box["state"] = "chase"
	assert_eq(DeadBody.custom(box, 0.0, 0.0, 0.8, false), Color(0.37, 1.0, 0.0, 0.8))
	assert_false(box.has("body_motion"), "and nothing is noted on it either")


func test_the_motion_numbers_are_the_ones_the_bake_writes() -> void:
	var names: Array = []
	for clip in BodyBake.CLIPS:
		names.append(clip[0])
	assert_eq(names.slice(0, DeadBody.WALKS), ["walk_a", "walk_b", "walk_c"])
	assert_eq(names[DeadBody.STAND], "stand")
	assert_eq(names[DeadBody.LUNGE], "lunge")
	assert_eq(names[DeadBody.FALL], "fall")
	assert_eq(names[DeadBody.FALL_FRONT], "fall_front")
	assert_eq(names[DeadBody.CRAWL], "crawl")
	assert_eq(names[DeadBody.RISE], "rise")
	assert_eq(names[DeadBody.CLIMB], "climb")
	assert_eq(names[DeadBody.RISE_FRONT], "rise_front")


func test_a_baked_body_walks_its_own_walk_and_stands_once_it_keeps_its_place() -> void:
	var seen := {}
	for n in 40:
		seen[DeadBody.walk_of(float(n) / 40.0)] = true
	assert_eq(seen.size(), DeadBody.WALKS, "all three walks are handed out")
	var z := _body()
	assert_eq(DeadBody.custom(z, 0.0, 0.0, 1.0, true).g, float(DeadBody.walk_of(0.37)), "first seen, it walks")
	z["age"] = 10.0 + DeadBody.STILL_AFTER
	assert_eq(DeadBody.custom(z, 0.0, 0.0, 1.0, true).g, float(DeadBody.STAND), "in the same place this long, it stands")
	z["pos"] = Vector3(3.2, 0, 4)
	assert_eq(DeadBody.custom(z, 0.0, 0.0, 1.0, true).g, float(DeadBody.walk_of(0.37)), "and walks again when it moves")
	assert_eq(DeadBody.custom(_body("grab"), 0.0, 0.0, 1.0, true).g, float(DeadBody.LUNGE))
	assert_eq(DeadBody.custom(_body("frozen"), 0.0, 1.0, 1.0, true).g, float(DeadBody.STAND))


func test_a_baked_body_goes_over_by_the_fall_and_comes_up_through_it_backwards() -> void:
	var length := float(Motion.row("dead_fall")["len"])
	var z := _body("downed")
	z["fell_at"] = 10.0 - length * 0.5
	assert_true(DeadBody.falls_by_motion(z, true))
	var mid := DeadBody.custom(z, 0.4, 0.0, 1.0, true)
	assert_eq(mid.g, float(DeadBody.FALL))
	assert_almost_eq(mid.r, 0.5, 0.001, "half the fall's time, half the motion (not how far over the boxes would be)")
	z["fell_at"] = 10.0 - length * 3.0
	assert_almost_eq(DeadBody.custom(z, 1.0, 1.0, 1.0, true).r, 1.0, 0.001, "it lies at the motion's end")
	var up := DeadBody.custom(z, 0.3, 0.0, 1.0, true)
	assert_eq(up.g, float(DeadBody.RISE), "off its back it gets up by its own motion")
	assert_almost_eq(up.r, 0.7, 0.001, "as far through it as it has come up")
	z["fell_fwd"] = true
	var up_front := DeadBody.custom(z, 0.3, 0.0, 1.0, true)
	assert_eq(up_front.g, float(DeadBody.RISE_FRONT), "off its face it has another")
	assert_almost_eq(up_front.r, 0.7, 0.001)
	var corpse := _body("dead")
	assert_almost_eq(DeadBody.custom(corpse, 1.0, 1.0, 1.0, true).r, 1.0, 0.001, "a body that was never seen to fall lies")


func test_struck_from_behind_it_goes_over_on_its_face() -> void:
	var z := _body("downed")
	z["fell_at"] = 9.9
	z["fell_fwd"] = true
	assert_eq(DeadBody.custom(z, 0.4, 0.0, 1.0, true).g, float(DeadBody.FALL_FRONT))
	z["fell_fwd"] = false
	assert_eq(DeadBody.custom(z, 0.4, 0.0, 1.0, true).g, float(DeadBody.FALL))


func test_a_crawler_drags_itself_lies_still_when_knocked_down_and_dies_on_its_face() -> void:
	var z := _body("chase")
	z["crawl"] = true
	assert_true(DeadBody.falls_by_motion(z, true), "the crawl is on the ground already")
	var moving := DeadBody.custom(z, 1.0, 1.0, 1.0, true)
	assert_eq(moving.g, float(DeadBody.CRAWL))
	assert_eq(moving.b, 1.0, "the clock does not move it")
	z["pos"] += Vector3(0, 0, 0.09)
	var pulled := DeadBody.custom(z, 1.0, 1.0, 1.0, true)
	assert_almost_eq(fposmod(pulled.r - moving.r, 1.0), 0.09 / float(DeadBody.STRIDE[DeadBody.CRAWL]), 0.001, "the ground it covers does")
	z["state"] = "downed"
	assert_eq(DeadBody.custom(z, 1.0, 0.0, 1.0, true).b, 1.0, "held still")
	z["state"] = "dead"
	var dead := DeadBody.custom(z, 1.0, 1.0, 1.0, true)
	assert_eq(dead.g, float(DeadBody.FALL_FRONT))
	assert_eq(dead.r, 1.0)
	assert_eq(DeadBody.ground_turn(z, 1.0), 0.0, "a crawler keeps to its line")


func test_baked_bodies_do_not_all_lie_along_the_same_line() -> void:
	var a := _body("dead")
	var b := _body("dead")
	b["phase"] = 0.81
	assert_ne(DeadBody.ground_turn(a, 1.0), DeadBody.ground_turn(b, 1.0))
	assert_eq(DeadBody.ground_turn(a, 0.0), 0.0, "upright it is not turned")


func test_out_of_a_manhole_a_baked_body_hauls_itself_up_by_the_rules_clock() -> void:
	var z := _body("climb")
	z["climb_at"] = 10.0 - float(Motion.row("dead_climb_lid")["len"]) * 0.25
	var c := DeadBody.custom(z, 0.0, 0.0, 1.0, true)
	assert_eq(c.g, float(DeadBody.CLIMB))
	assert_almost_eq(c.r, 0.25, 0.001)
	assert_eq(DeadBody.climbing(z, true), DeadPose.climbing(z), "lifted out of the ground as the boxes are")
	assert_eq(DeadBody.climbing(z, false), DeadPose.climbing(z))


func test_out_of_a_culvert_a_baked_body_crawls_then_gets_up_and_is_not_turned_over_twice() -> void:
	var z := _body("climb")
	z["climb_way"] = "culvert"
	var row: Dictionary = Motion.row("dead_climb_culvert")
	z["climb_at"] = 10.0 - float(row["open"]) * 0.5
	var crawl := DeadBody.custom(z, 0.0, 0.0, 1.0, true)
	assert_eq(crawl.g, float(DeadBody.CRAWL))
	assert_almost_eq(crawl.r, float(row["open"]) * 0.5 / DeadBody.CRAWL_LEN, 0.001, "its arms keep pulling: the crawl runs on the rules clock")
	assert_eq(crawl.b, 0.0, "not held still")
	var slid := DeadBody.climbing(z, true)
	assert_eq(slid.basis, Basis(), "the crawl lies flat by itself")
	assert_lt(slid.origin.z, 0.0, "still partly back in the mouth")
	z["climb_at"] = 10.0 - float(row["len"]) * 0.99
	var up := DeadBody.custom(z, 0.0, 0.0, 1.0, true)
	assert_eq(up.g, float(DeadBody.RISE_FRONT))
	assert_gt(up.r, 0.95, "nearly on its feet")


func test_a_baked_bodys_feet_go_by_the_ground_it_covers() -> void:
	var z := _body("wander")
	var walk := DeadBody.walk_of(z["phase"])
	var first := DeadBody.custom(z, 0.0, 0.0, 1.0, true)
	assert_eq(first.g, float(walk))
	assert_eq(first.b, 1.0, "the clock does not step it")
	assert_almost_eq(first.r, 0.37, 0.001, "it starts from the body's own number")
	z["age"] += 0.05
	z["pos"] += Vector3(0.11, 0, 0)
	var second := DeadBody.custom(z, 0.0, 0.0, 1.0, true)
	assert_almost_eq(fposmod(second.r - first.r, 1.0), 0.11 / float(DeadBody.STRIDE[walk]), 0.001)
	z["age"] += 0.05
	z["pos"] += Vector3(6, 0, 0)
	var put := DeadBody.custom(z, 0.0, 0.0, 1.0, true)
	assert_almost_eq(put.r, second.r, 0.001, "put somewhere else, it has not walked there")
	z["age"] += DeadBody.STILL_AFTER + 0.1
	assert_eq(DeadBody.custom(z, 0.0, 0.0, 1.0, true).g, float(DeadBody.STAND), "and where it stops it stands")


func test_the_fresh_dead_run_after_someone_and_the_others_do_not() -> void:
	var fresh := _body("chase")
	fresh["kind"] = "fresh"
	assert_eq(DeadBody.custom(fresh, 0.0, 0.0, 1.0, true).g, float(DeadBody.RUN))
	fresh["state"] = "wander"
	assert_lt(DeadBody.custom(fresh, 0.0, 0.0, 1.0, true).g, float(DeadBody.WALKS), "not after anyone, it walks")
	var old := _body("chase")
	old["kind"] = "dead"
	assert_lt(DeadBody.custom(old, 0.0, 0.0, 1.0, true).g, float(DeadBody.WALKS))
	var names: Array = []
	for clip: Array in BodyBake.OWN_CLIPS:
		names.append(clip[0])
	assert_eq(names[DeadBody.RUN], "run")


func test_the_baked_folders_own_rounds_are_used_where_it_gives_them() -> void:
	var walk := DeadBody.walk_of(0.37)
	var clips: Array = []
	for n in 12:
		clips.append({"name": "m%d" % n, "round": 2.0 if n == walk else 0.0})
	DeadBody.rounds = DeadBody.rounds_of({"clips": clips})
	assert_eq(DeadBody.rounds, {walk: 2.0}, "only the motions that cover ground")
	var z := _body("wander")
	var first := DeadBody.custom(z, 0.0, 0.0, 1.0, true)
	z["pos"] += Vector3(0.2, 0, 0)
	assert_almost_eq(fposmod(DeadBody.custom(z, 0.0, 0.0, 1.0, true).r - first.r, 1.0), 0.1, 0.001)
	var crawler := _body("chase")
	crawler["crawl"] = true
	var before := DeadBody.custom(crawler, 0.0, 0.0, 1.0, true)
	crawler["pos"] += Vector3(0.1, 0, 0)
	assert_almost_eq(fposmod(DeadBody.custom(crawler, 0.0, 0.0, 1.0, true).r - before.r, 1.0), 0.1 / float(DeadBody.STRIDE[DeadBody.CRAWL]), 0.001, "the others fall back on the written ones")
	DeadBody.rounds = {}
	assert_eq(DeadBody.rounds_of({}), {})


func test_a_baked_body_changing_motion_keeps_the_frame_it_was_in_for_a_moment() -> void:
	# Twelve motions of 32 frames each, all looping but the fall (6).
	for n in 12:
		DeadBody.table.append([n * 32, 32, n != DeadBody.FALL])
	var z := _body("wander")
	var walk := DeadBody.walk_of(z["phase"])
	var walking := DeadBody.custom(z, 0.0, 0.0, 1.0, true)
	assert_eq(walking.g, float(walk), "nothing to ease from at first")
	var was := DeadBody.frame_of(walk, walking.r)
	assert_eq(was, walk * 32 + int(0.37 * 32.0))
	# Struck down: the fall starts from the walk frame it was in, and lets go of it.
	z["state"] = "downed"
	z["fell_at"] = z["age"]
	var struck := DeadBody.custom(z, 0.01, 0.0, 1.0, true)
	var share := floorf(struck.g / 65536.0)
	var frame := floorf((struck.g - share * 65536.0) / 16.0)
	assert_eq(share, DeadBody.MIX_STEPS, "all of the old frame at the change")
	assert_eq(frame, float(was))
	assert_eq(struck.g - share * 65536.0 - frame * 16.0, float(DeadBody.FALL), "under it, the motion it is in now")
	z["age"] += DeadBody.MIX_TIME * 0.5
	var half := floorf(DeadBody.custom(z, 0.3, 0.0, 1.0, true).g / 65536.0)
	assert_almost_eq(half, DeadBody.MIX_STEPS * 0.5, 1.0, "half of it half way")
	z["age"] += DeadBody.MIX_TIME
	assert_eq(DeadBody.custom(z, 0.9, 0.0, 1.0, true).g, float(DeadBody.FALL), "then the motion alone")
	assert_eq(DeadBody.frame_of(DeadBody.FALL, 1.0), DeadBody.FALL * 32 + 31, "a motion played once ends on its last frame")
	assert_eq(DeadBody.frame_of(99, 0.5), 0, "an unknown motion has none")

