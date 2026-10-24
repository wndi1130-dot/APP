extends GutTest

const DeadBody = preload("res://game/actors/dead_body.gd")
const BodyBake = preload("res://scripts/body_bake.gd")
const Motion = preload("res://game/sim/motion.gd")
const DeadPose = preload("res://game/actors/dead_pose.gd")
const LungerRules = preload("res://game/sim/lunger_rules.gd")


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


# Half of the dead go over the other way of each side (decision 412), the same
# body always the same way, and only when the folder in use has those motions.
func test_half_of_the_dead_go_over_the_other_way_when_the_folder_has_it() -> void:
	var names: Array = []
	for clip in BodyBake.CLIPS:
		names.append(clip[0])
	assert_eq(names[DeadBody.FALL_THROWN], "fall_thrown")
	assert_eq(names[DeadBody.FALL_SLUMP], "fall_slump")
	var z := _body("downed")
	z["fell_at"] = 9.9
	for n in DeadBody.FALL_SLUMP + 1:
		DeadBody.table.append([n * 32, 32, false])
	var other := 0
	for n in 40:
		z["phase"] = (float(n) + 0.5) / 40.0
		z["fell_fwd"] = true
		var front := int(DeadBody.picked(z, 0.4, 0.0, 1.0, true).g)
		assert_true(front == DeadBody.FALL_FRONT or front == DeadBody.FALL_SLUMP, "on its face")
		assert_eq(int(DeadBody.picked(z, 0.4, 0.0, 1.0, true).g), front, "the same body the same way")
		z["fell_fwd"] = false
		var back := int(DeadBody.picked(z, 0.4, 0.0, 1.0, true).g)
		assert_eq(back, DeadBody.FALL_THROWN if front == DeadBody.FALL_SLUMP else DeadBody.FALL, "on its back, the same half")
		if front == DeadBody.FALL_SLUMP:
			other += 1
	assert_between(other, 14, 26, "about half")
	# An older folder without them: the first ways only.
	DeadBody.table.resize(DeadBody.STAGGER + 1)
	for n in 40:
		z["phase"] = (float(n) + 0.5) / 40.0
		z["fell_fwd"] = n % 2 == 0
		assert_eq(int(DeadBody.picked(z, 0.4, 0.0, 1.0, true).g), DeadBody.FALL_FRONT if n % 2 == 0 else DeadBody.FALL)


# They lie at the end just as the first ways do, so getting up is the same.
func test_the_other_falls_end_lying_as_the_first_ones() -> void:
	var baked: Dictionary = BodyBake.load_baked(DeadBody.BUILT_IN)
	var clips: Array = baked["clips"]
	for pair in [[DeadBody.FALL, DeadBody.FALL_THROWN], [DeadBody.FALL_FRONT, DeadBody.FALL_SLUMP]]:
		var a := _last_frame(baked, clips[pair[0]])
		var b := _last_frame(baked, clips[pair[1]])
		var worst := 0.0
		for i in a.size():
			worst = maxf(worst, a[i].distance_to(b[i]))
		assert_lt(worst, 0.03, "%s lies as %s, metres" % [clips[pair[1]]["name"], clips[pair[0]]["name"]])


# The motions added for what the reference game's dead do (motion detail 2): in
# both bodies under the numbers named in dead_body.gd, the quick ones with every
# frame, the one-shots ending as they began, and only the two walks covering ground.
func test_the_added_motions_are_baked_under_their_numbers() -> void:
	var named := {DeadBody.THUMP: "thump", DeadBody.CLAW: "claw", DeadBody.HIT_LEFT: "hit_left",
		DeadBody.HIT_RIGHT: "hit_right", DeadBody.HIT_TOP: "hit_top", DeadBody.HIT_UPPER: "hit_upper",
		DeadBody.TURN_LEFT: "turn_left", DeadBody.TURN_RIGHT: "turn_right", DeadBody.WALK_D: "walk_d", DeadBody.WALK_E: "walk_e"}
	for n: int in named:
		assert_eq(BodyBake.OWN_CLIPS[n][0], named[n])
		assert_eq(BodyBake.CLIPS[n][0], named[n], "the same number either way")
	for folder in [DeadBody.BUILT_IN, "res://models/people/n5-crew_seamstress"]:
		var baked: Dictionary = BodyBake.load_baked(folder)
		var clips: Array = baked["clips"]
		assert_eq(clips.size(), BodyBake.OWN_CLIPS.size(), folder)
		for n: int in named:
			var clip: Dictionary = clips[n]
			assert_eq(str(clip["name"]), named[n], folder)
			if BodyBake.DEAD_KEEP.has(named[n]):
				assert_eq(int(clip["frames"]), int(BodyBake.OWN_CLIPS[n][2]), named[n] + " keeps every frame")
			assert_eq(float(clip["round"]) > 0.0, n == DeadBody.WALK_D or n == DeadBody.WALK_E, named[n] + " covers ground only if it walks")
			if not bool(clip["loop"]):
				var a := _frame(baked, clip, 0)
				var b := _last_frame(baked, clip)
				var worst := 0.0
				for i in a.size():
					worst = maxf(worst, a[i].distance_to(b[i]))
				assert_lt(worst, 0.02, "%s ends as it began, metres" % named[n])


# Eating a body (decision 423), in both bodies: down, the loop and up again run
# into each other with no jump, none covers ground, and the head is lowest (the
# teeth meet) at the middle of the loop.
func test_eating_a_body_goes_down_eats_and_gets_up_with_no_jump() -> void:
	# Picked by name (dead_body.gd EAT_START, EAT, EAT_RISE); their numbers in the bake.
	var number := {}
	for i in BodyBake.CLIPS.size():
		number[BodyBake.CLIPS[i][0]] = i
	var start: int = number[DeadBody.EAT_START]
	var loop: int = number[DeadBody.EAT]
	var rise: int = number[DeadBody.EAT_RISE]
	var named := {start: DeadBody.EAT_START, loop: DeadBody.EAT, rise: DeadBody.EAT_RISE}
	for n: int in named:
		assert_eq(BodyBake.OWN_CLIPS[n][0], named[n])
		assert_eq(BodyBake.CLIPS[n][0], named[n], "the same number either way")
	for folder in [DeadBody.BUILT_IN, "res://models/people/n5-crew_seamstress"]:
		var baked: Dictionary = BodyBake.load_baked(folder)
		var clips: Array = baked["clips"]
		for n: int in named:
			assert_eq(str(clips[n]["name"]), named[n], folder)
			assert_eq(bool(clips[n]["loop"]), n == loop, named[n] + " loops only if it is the eating")
			assert_eq(float(clips[n]["round"]), 0.0, named[n] + " covers no ground")
		var down: Dictionary = clips[start]
		var eat: Dictionary = clips[loop]
		var up: Dictionary = clips[rise]
		var joins := [[_last_frame(baked, down), _frame(baked, eat, 0), "down into the eating"],
			[_frame(baked, eat, 0), _frame(baked, up, 0), "the eating into getting up"],
			[_last_frame(baked, up), _frame(baked, down, 0), "up to where it went down from"]]
		for join: Array in joins:
			var worst := 0.0
			for i in join[0].size():
				worst = maxf(worst, join[0][i].distance_to(join[1][i]))
			assert_lt(worst, 0.02, "%s, metres (%s)" % [join[2], folder])
		var standing := _frame(baked, clips[DeadBody.STAND], 0)
		var head := 0
		for i in standing.size():
			if standing[i].y > standing[head].y:
				head = i
		var lowest := 0
		var low := INF
		for k in int(eat["frames"]):
			var y: float = _frame(baked, eat, k)[head].y
			if y < low:
				low = y
				lowest = k
		assert_almost_eq(float(lowest) / float(eat["frames"]), 0.5, 1.0 / float(eat["frames"]), "the teeth meet at the middle (%s)" % folder)
		assert_lt(low, _frame(baked, down, 0)[head].y - 0.3, "down at the body, not standing over it")


func _last_frame(baked: Dictionary, clip: Dictionary) -> Array:
	return _frame(baked, clip, int(clip["frames"]) - 1)


func _frame(baked: Dictionary, clip: Dictionary, k: int) -> Array:
	var img: Image = baked["image"]
	var rows := int(baked["rows_per_frame"])
	var first := (int(clip["start"]) + k) * rows
	var lo := Vector3(clip["lo"][0], clip["lo"][1], clip["lo"][2])
	var hi := Vector3(clip["hi"][0], clip["hi"][1], clip["hi"][2])
	var out: Array = []
	for y in range(first, first + rows):
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			out.append(lo + Vector3(c.r, c.g, c.b) * (hi - lo))
	return out


func test_a_crawler_drags_itself_lies_still_when_knocked_down_and_dies_on_its_face() -> void:
	var z := _body("chase")
	z["crawl"] = true
	assert_true(DeadBody.falls_by_motion(z, true), "the crawl is on the ground already")
	var moving := DeadBody.custom(z, 1.0, 1.0, 1.0, true)
	assert_eq(moving.g, float(DeadBody.CRAWL))
	assert_eq(moving.b, 1.0, "the clock does not move it")
	z["pos"] += Vector3(0, 0, 0.09)
	var pulled := DeadBody.custom(z, 1.0, 1.0, 1.0, true)
	assert_almost_eq(fposmod(pulled.r - moving.r, 1.0), 0.09 / (float(DeadBody.STRIDE[DeadBody.CRAWL]) * _stride(z)), 0.001, "the ground it covers does")
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
	assert_almost_eq(fposmod(second.r - first.r, 1.0), 0.11 / (float(DeadBody.STRIDE[walk]) * _stride(z)), 0.001)
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
	assert_almost_eq(fposmod(DeadBody.custom(z, 0.0, 0.0, 1.0, true).r - first.r, 1.0), 0.2 / (2.0 * _stride(z)), 0.001)
	var crawler := _body("chase")
	crawler["crawl"] = true
	var before := DeadBody.custom(crawler, 0.0, 0.0, 1.0, true)
	crawler["pos"] += Vector3(0.1, 0, 0)
	assert_almost_eq(fposmod(DeadBody.custom(crawler, 0.0, 0.0, 1.0, true).r - before.r, 1.0), 0.1 / (float(DeadBody.STRIDE[DeadBody.CRAWL]) * _stride(crawler)), 0.001, "the others fall back on the written ones")
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


func test_a_standing_baked_body_sways_by_a_clock_the_drawing_side_keeps() -> void:
	var z := _body("frozen")
	var first := DeadBody.custom(z, 0.0, 0.0, 1.0, true)
	assert_eq(first.g, float(DeadBody.STAND))
	assert_eq(first.b, 1.0, "the shader's clock is not used")
	assert_almost_eq(first.r, 0.37, 0.001, "from the body's own number")
	z["age"] += 0.05
	var pace := lerpf(DeadBody.STAND_PACE.x, DeadBody.STAND_PACE.y, fposmod(0.37 * 7.31, 1.0))
	var second := DeadBody.custom(z, 0.0, 0.0, 1.0, true)
	assert_almost_eq(second.r - first.r, 0.05 * pace / float(DeadBody.SECONDS[DeadBody.STAND]), 0.0001, "at its own pace")
	z["age"] += 0.05
	assert_almost_eq(DeadBody.custom(z, 0.0, 1.0, 1.0, true).r, second.r, 0.0001, "held still it stays in its frame")
	z["age"] += 30.0
	assert_almost_eq(DeadBody.custom(z, 0.0, 0.0, 1.0, true).r - second.r, DeadBody.SWAY_CAP * pace / float(DeadBody.SECONDS[DeadBody.STAND]), 0.0001, "a long gap is not played through")
	# A folder's own length is used where it gives one.
	for n in 5:
		DeadBody.table.append([n * 32, 32, true, 1.5])
	var other := _body("frozen")
	var a := DeadBody.custom(other, 0.0, 0.0, 1.0, true)
	other["age"] += 0.03
	assert_almost_eq(DeadBody.custom(other, 0.0, 0.0, 1.0, true).r - a.r, 0.03 * pace / 1.5, 0.0001)



func test_one_that_lunges_drops_low_runs_and_then_reels() -> void:
	var names: Array = []
	for clip: Array in BodyBake.OWN_CLIPS:
		names.append(clip[0])
	assert_eq(names[DeadBody.TELL], "tell")
	assert_eq(names[DeadBody.STAGGER], "stagger")
	# The tell is read off the rules' clock: 0 as it starts, 1 as it runs.
	var low := _body("tell")
	low["t"] = LungerRules.TELL * 0.25
	var told := DeadBody.custom(low, 0.0, 0.0, 1.0, true)
	assert_eq(told.g, float(DeadBody.TELL))
	assert_almost_eq(told.r, 0.75, 0.001)
	assert_eq(DeadBody.custom(_body("tell"), 0.0, 0.0, 0.8, false), Color(0.37, 0.0, 0.0, 0.8), "a box is told nothing new")
	# One of the old dead runs while its run lasts, and reels after it.
	var runner := _body("chase")
	runner["kind"] = "dead"
	runner["dash_t"] = 1.0
	runner["spent_t"] = 0.0
	assert_eq(DeadBody.custom(runner, 0.0, 0.0, 1.0, true).g, float(DeadBody.RUN))
	var spent := _body("chase")
	spent["kind"] = "fresh"
	spent["dash_t"] = 0.0
	spent["spent_t"] = 2.0
	assert_eq(DeadBody.custom(spent, 0.0, 0.0, 1.0, true).g, float(DeadBody.STAGGER), "even one that would run")
	assert_true(DeadBody.STRIDE.has(DeadBody.STAGGER))


# Holding on to someone (or about to bite), a baked body keeps its arms out at
# them and only shifts its legs: it is held at their side, so a walk would slide.
func test_a_baked_body_holding_on_keeps_its_reach_and_does_not_walk() -> void:
	for state in ["grab", "attack"]:
		var z := _body(state)
		for i in 20:
			z["age"] += 0.05
			var c := DeadBody.custom(z, 0.0, 0.0, 1.0, true)
			assert_eq(int(c.g), DeadBody.LUNGE, state)
			assert_almost_eq(fposmod(c.r - DeadBody.REACH_AT + 0.5, 1.0) - 0.5, 0.0, DeadBody.REACH_SHIFT + 0.001, state)


# Thrown off someone it reels back with its feet going back over the ground
# it is seen to cover, then reels on the spot while stunned, then walks on.
func test_a_body_thrown_off_reels_back_then_on_the_spot() -> void:
	var z := _body("chase")
	z["stun"] = 1.0
	z["shoved_t"] = 0.2
	var first := DeadBody.custom(z, 0.0, 0.0, 1.0, true)
	assert_eq(int(first.g), DeadBody.STAGGER)
	z["pos"] += Vector3(0.1, 0, 0)
	var back := DeadBody.custom(z, 0.0, 0.0, 1.0, true)
	assert_almost_eq(fposmod(first.r - back.r, 1.0), 0.1 / float(DeadBody.STRIDE[DeadBody.STAGGER]), 0.001, "the feet go back")
	z["shoved_t"] = 0.0
	z["age"] += 0.05
	var spot := DeadBody.custom(z, 0.0, 0.0, 1.0, true)
	assert_eq(int(spot.g), DeadBody.STAGGER, "stunned, it reels on")
	z["age"] += 0.05
	var on := DeadBody.custom(z, 0.0, 0.0, 1.0, true)
	assert_almost_eq(fposmod(on.r - spot.r, 1.0), 0.05 * DeadBody.REEL_PACE / 1.3, 0.001, "by its own clock")
	z["stun"] = 0.0
	assert_ne(int(DeadBody.custom(z, 0.0, 0.0, 1.0, true).g), DeadBody.STAGGER, "then it comes on")
	# Stunned by a blow, not thrown off: no reel.
	var struck := _body("chase")
	struck["stun"] = 0.6
	assert_ne(int(DeadBody.custom(struck, 0.0, 0.0, 1.0, true).g), DeadBody.STAGGER)


func test_struck_is_eased_into_fast_and_a_reel_slowly() -> void:
	assert_eq(DeadBody.mix_time(DeadBody.HIT), 0.1)
	assert_eq(DeadBody.mix_time(DeadBody.STAGGER), 0.4)
	assert_eq(DeadBody.mix_time(DeadBody.FALL), DeadBody.MIX_TIME, "the rest as they were")


# Each body's own stride, a tenth either way of the written one.
func _stride(z: Dictionary) -> float:
	return lerpf(1.0 - DeadBody.STRIDE_SPREAD, 1.0 + DeadBody.STRIDE_SPREAD, fposmod(float(z["phase"]) * 3.17, 1.0))
