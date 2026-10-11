extends GutTest

const DeadBody = preload("res://game/actors/dead_body.gd")
const BodyBake = preload("res://scripts/body_bake.gd")
const Motion = preload("res://game/sim/motion.gd")


func _body(state: String = "wander") -> Dictionary:
	return {"state": state, "phase": 0.37, "crawl": false, "age": 10.0, "pos": Vector3(3, 0, 4), "t": 0.0}


func test_with_no_baked_folder_there_is_no_body_and_the_boxes_are_told_what_they_were() -> void:
	OS.set_environment(DeadBody.FOLDER_ENV, "user://no_such_dead_body")
	assert_true(DeadBody.assets().is_empty())
	OS.set_environment(DeadBody.FOLDER_ENV, "")
	for state in ["wander", "investigate", "chase", "attack", "grab", "downed", "rising", "dead", "frozen", "waking"]:
		var z := _body(state)
		var clip := 1.0 if state in ["chase", "attack", "grab"] else 0.0
		assert_eq(DeadBody.custom(z, 0.6, 1.0, 0.8, false), Color(0.37, clip, 1.0, 0.8), state)
		assert_false(DeadBody.falls_by_motion(z, false), "the boxes are laid down whole")
		assert_false(z.has("body_at"), "and nothing is noted on the body")


func test_the_motion_numbers_are_the_ones_the_bake_writes() -> void:
	var names: Array = []
	for clip in BodyBake.CLIPS:
		names.append(clip[0])
	assert_eq(names.slice(0, DeadBody.WALKS), ["walk_a", "walk_b", "walk_c"])
	assert_eq(names[DeadBody.STAND], "stand")
	assert_eq(names[DeadBody.LUNGE], "lunge")
	assert_eq(names[DeadBody.FALL], "fall")


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
	assert_almost_eq(DeadBody.custom(z, 0.3, 0.0, 1.0, true).r, 0.3, 0.001, "coming up, as far back as it has come up")
	var corpse := _body("dead")
	assert_almost_eq(DeadBody.custom(corpse, 1.0, 1.0, 1.0, true).r, 1.0, 0.001, "a body that was never seen to fall lies")


func test_a_crawler_is_still_laid_down_whole() -> void:
	var z := _body("downed")
	z["crawl"] = true
	assert_false(DeadBody.falls_by_motion(z, true))
	assert_ne(DeadBody.custom(z, 1.0, 0.0, 1.0, true).g, float(DeadBody.FALL))
