extends "res://addons/gut/test.gd"
## The gestures of people inside the train are read off one clock and give
## where the trunk, the head and the arms sit. Nothing here moves anyone along
## the car or decides who does what.

const Gesture = preload("res://game/train/train_gesture.gd")
const MotionContract = preload("res://game/train/train_motion_contract.gd")
const TrainBody = preload("res://game/train/train_body.gd")

const FIRST_REST: Array = ["sit_bench", "sit_floor", "lie_bunk", "warm_hands_stand",
	"warm_hands_crouch", "sleep_lean_wall", "kneel"]
const FIRST_RIOT: Array = ["fist_raise", "shove_body", "bang_object", "spring_up", "stomp"]
const MORE_RIOT: Array = ["grab_collar", "punch_swing", "fall_down", "help_up", "throw_object",
	"back_away", "watch_flinch", "tip_crate", "torch_hold", "torch_carry", "light_cloth", "walk_out_smoke"]
const BONES: Array = ["hips", "spine", "chest", "neck", "head", "upper_arm.L",
	"upper_arm.R", "forearm.L", "forearm.R", "hand.L", "hand.R", "thigh.L", "thigh.R",
	"shin.L", "shin.R", "foot.L", "foot.R"]


func _steps(seconds: float, step: float = 0.05) -> Array:
	var out: Array = []
	var t := 0.0
	while t < seconds:
		out.append(t)
		t += step
	return out


func test_every_gesture_gives_the_same_parts_and_stays_within_a_body() -> void:
	for name in Gesture.NAMES:
		for role in 2:
			for t in _steps(14.0, 0.11):
				var d: Dictionary = Gesture.at(name, t, role)
				assert_eq(d["arms"].size(), 2, name)
				assert_between(float(d["lean"]), -0.15, 0.3, name + " lean")
				assert_between(float(d["sway"]), -0.2, 0.2, name + " sway")
				assert_between(float(d["lift"]), -0.02, 0.05, name + " lift")
				assert_lt((d["head"] as Vector3).length(), 0.15, name + " head")
				for arm in d["arms"]:
					assert_between(float(arm["pos"].y), 0.9, 1.5, name + " hand height")
	assert_eq(Gesture.at("no such thing", 1.0), Gesture._still(), "an unknown name stands still")


func test_in_an_argument_they_face_each_other_and_speak_in_turn() -> void:
	assert_almost_eq(float(Gesture.at(Gesture.ARGUE, 1.0, 0)["turn"]), PI * 0.5, 0.001)
	assert_almost_eq(float(Gesture.at(Gesture.ARGUE, 1.0, 1)["turn"]), -PI * 0.5, 0.001)
	var both := 0.0
	var first := 0.0
	var second := 0.0
	for t in _steps(Gesture.SAY * 4.0):
		var a: float = Gesture.speaking(t, 0)
		var b: float = Gesture.speaking(t, 1)
		both = maxf(both, minf(a, b))
		first = maxf(first, a)
		second = maxf(second, b)
	assert_lt(both, 0.05, "never both at once")
	assert_almost_eq(first, 1.0, 0.01)
	assert_almost_eq(second, 1.0, 0.01)
	# The one speaking comes forward with a hand out; the other goes back.
	var t_say := Gesture.SAY * 0.5
	var speaker: Dictionary = Gesture.at(Gesture.ARGUE, t_say, 0)
	var other: Dictionary = Gesture.at(Gesture.ARGUE, t_say, 1)
	assert_gt(float(speaker["lean"]), 0.15)
	assert_lt(float(other["lean"]), 0.0)
	assert_gt(float(speaker["arms"][1]["pos"].z), 0.35, "a hand out in front")


func test_whisperers_tip_toward_each_other_and_look_round_one_at_a_time() -> void:
	var t_calm := 0.0
	for t in _steps(Gesture.GLANCE_EVERY):
		if Gesture.glancing(t, 0) == 0.0 and Gesture.glancing(t, 1) == 0.0:
			t_calm = t
			break
	var left: Dictionary = Gesture.at(Gesture.WHISPER, t_calm, 0)
	var right: Dictionary = Gesture.at(Gesture.WHISPER, t_calm, 1)
	assert_gt(float(left["sway"]), 0.1, "the left one tips right")
	assert_lt(float(right["sway"]), -0.1, "the right one tips left")
	assert_gt(float(left["head"].x), 0.0)
	assert_lt(float(right["head"].x), 0.0)
	assert_gt(float(left["arms"][1]["pos"].y), 1.2, "a hand up by the mouth, on the inner side")
	assert_gt(float(right["arms"][0]["pos"].y), 1.2)
	var both := 0.0
	var turned := 0.0
	for t in _steps(Gesture.GLANCE_EVERY * 2.0):
		both = maxf(both, minf(Gesture.glancing(t, 0), Gesture.glancing(t, 1)))
		turned = minf(turned, float(Gesture.at(Gesture.WHISPER, t, 0)["turn"]))
	assert_eq(both, 0.0, "they do not look round together")
	assert_lt(turned, -0.8, "the left one looks round over its left shoulder, away from the other")


func test_turning_about_goes_round_holds_and_comes_back() -> void:
	assert_almost_eq(Gesture.about(0.0), 0.0, 0.001)
	assert_almost_eq(Gesture.about(Gesture.ABOUT_TURN + Gesture.ABOUT_HOLD * 0.5), 1.0, 0.001, "looking the other way")
	assert_almost_eq(Gesture.about(Gesture.ABOUT_ROUND - 0.1), 0.0, 0.001, "and back as it stood")
	var there: Dictionary = Gesture.at(Gesture.TURN_ABOUT, Gesture.ABOUT_TURN + 0.5, 0)
	assert_almost_eq(float(there["turn"]), PI * 0.5, 0.001)
	assert_almost_eq(float(Gesture.at(Gesture.TURN_ABOUT, Gesture.ABOUT_TURN + 0.5 - 1.7, 1)["turn"]), -PI * 0.5, 0.001, "the next one turns the other way, and not in step")
	# Part way round the head is ahead of the body.
	assert_gt(float(Gesture.at(Gesture.TURN_ABOUT, Gesture.ABOUT_TURN * 0.5, 0)["head"].x), 0.05)


func test_arms_crossed_and_a_back_turned() -> void:
	var crossed: Dictionary = Gesture.at(Gesture.ARMS_CROSSED, 3.0)
	for arm in crossed["arms"]:
		assert_gt(float(arm["pos"].z), 0.2, "on the chest")
		assert_almost_eq(absf(float(arm["rot"].y)), PI * 0.5, 0.2, "lying across it")
	assert_almost_eq(float(crossed["turn"]), 0.0, 0.001)
	var most := 0.0
	var least := 9.0
	for t in _steps(Gesture.GLANCE_EVERY * 2.0):
		var turn: float = Gesture.at(Gesture.BACK_TURNED, t)["turn"]
		most = maxf(most, turn)
		least = minf(least, turn)
	assert_almost_eq(most, PI, 0.001, "its back to the car")
	assert_almost_eq(least, PI - 0.7, 0.01, "and now and then a look over the shoulder")


func test_the_next_five_say_what_they_sit_on_and_keep_the_hands_where_that_puts_them() -> void:
	assert_eq(Gesture.base_of(Gesture.HUG_KNEES), {"base": "floor", "huddled": true})
	assert_eq(Gesture.base_of(Gesture.SLUMP), {"base": "floor", "huddled": false})
	assert_eq(Gesture.base_of(Gesture.DRAG_WALK)["base"], "walk")
	assert_eq(Gesture.base_of(Gesture.BOWL_SIT)["base"], "sit")
	assert_eq(Gesture.base_of(Gesture.RUB_STAMP)["base"], "stand")
	assert_eq(Gesture.base_of(Gesture.ARGUE)["base"], "stand", "the first five stand")
	for t in _steps(12.0, 0.13):
		for role in 2:
			for arm in Gesture.at(Gesture.HUG_KNEES, t, role)["arms"]:
				assert_between(float(arm["pos"].y), 0.3, 0.55, "round the knees, low")
			for arm in Gesture.at(Gesture.SLUMP, t, role)["arms"]:
				assert_lt(float(arm["pos"].y), 0.2, "hands on the floor")
			assert_lt(float(Gesture.at(Gesture.SLUMP, t, role)["lean"]), -0.25, "fallen back")
			var bowl: Dictionary = Gesture.at(Gesture.BOWL_SIT, t, role)
			assert_eq(bowl["prop"]["name"], "bowl")
			for arm in bowl["arms"]:
				assert_lt(absf(float(arm["pos"].y) - float(bowl["prop"]["pos"].y)), 0.15, "the hands are at the bowl")
			var drag: Dictionary = Gesture.at(Gesture.DRAG_WALK, t, role)
			assert_eq(drag["pace"], Gesture.DRAG_PACE)
			assert_lte(float(drag["lift"]), 0.0, "it never comes up off its feet")
	assert_false(Gesture.at(Gesture.ARMS_CROSSED, 1.0).has("prop"))


func test_cold_hands_are_rubbed_then_blown_into_and_the_feet_stamp() -> void:
	var high := 0.0
	var low := 9.0
	var up := 0.0
	for t in _steps(Gesture.BLOW_EVERY * 2.0, 0.02):
		var d: Dictionary = Gesture.at(Gesture.RUB_STAMP, t)
		high = maxf(high, float(d["arms"][0]["pos"].y))
		low = minf(low, float(d["arms"][0]["pos"].y))
		up = maxf(up, float(d["lift"]))
		assert_lt(absf(float(d["arms"][0]["pos"].x) - float(d["arms"][1]["pos"].x)), 0.25, "the hands stay together")
	assert_gt(high, 1.38, "up at the mouth")
	assert_lt(low, 1.16, "and down in front of the chest")
	assert_almost_eq(up, 0.03, 0.002, "a foot comes up")


func test_a_gesture_is_put_on_a_stand_in_body_and_taken_off_again() -> void:
	var Body: GDScript = load("res://game/train/train_body.gd")
	var b: Node3D = Body.new()
	add_child_autofree(b)
	b.setup("c1", 2)
	b.set_pose("stand", false)
	var stood: Vector3 = b.body_mesh.position
	var head: Vector3 = b.head_mesh.position
	Gesture.show(b, Gesture.ARMS_CROSSED, 2.0, 0, 0.3)
	var arms: Array = b.get_meta(Gesture.ARMS_META)
	assert_eq(arms.size(), 2)
	assert_true(arms[0].visible)
	assert_almost_eq(arms[0].position.z, 0.27, 0.001)
	assert_almost_eq(b.rotation.y, 0.3, 0.001)
	assert_almost_eq(b.body_mesh.rotation.x, -0.07, 0.001)
	Gesture.show(b, Gesture.BACK_TURNED, 0.2, 0, 0.3)
	assert_almost_eq(b.rotation.y, 0.3 + PI, 0.01)
	assert_eq(b.get_meta(Gesture.ARMS_META), arms, "the same two boxes")
	assert_eq(b.get_child_count(), 4)
	# One that sits: the body is put in the pose the gesture sits on.
	Gesture.show(b, Gesture.HUG_KNEES, 1.0)
	assert_eq(b.pose, "floor")
	assert_true(b.huddled)
	assert_lt(b.body_mesh.position.y, stood.y)
	# Taken off, the arms are gone and the pose is whatever the scene sets next.
	Gesture.show(b, Gesture.WHISPER, 0.0)
	assert_ne(b.body_mesh.rotation.z, 0.0)
	Gesture.show(b, "", 0.0, 0, 0.0)
	assert_false(arms[0].visible)
	b.set_pose("stand", false)
	assert_eq(b.body_mesh.position, stood)
	assert_eq(b.head_mesh.position, head)
	assert_almost_eq(b.body_mesh.rotation.x, 0.0, 0.001)
	assert_eq(b.body_mesh.rotation.z, 0.0)


# ---------------------------------------------------------------- the first twelve stand-in gestures

func test_knows_only_the_original_ten_and_the_first_twelve() -> void:
	var names: Array = []
	names.append_array(Gesture.NAMES)
	names.append_array(Gesture.MORE)
	names.append_array(FIRST_REST)
	names.append_array(FIRST_RIOT)
	names.append_array(MORE_RIOT)
	assert_eq(names.size(), 34)
	for name in names:
		assert_true(Gesture.knows(name), name)
		assert_true(bool(MotionContract.resolve(name)["native"]), name)
	for name in ["", "chat_talk", "chat_listen", "give_item", "push_pair", "strike_pair",
		"set_fire", "collapse_fall", "drag_feet", "mourn_kneel", "light_luggage", "nonsense"]:
		assert_false(Gesture.knows(name), name)
		assert_false(bool(MotionContract.resolve(name)["native"]), name)


func test_three_part_lengths_and_bone_keys_follow_the_first_values() -> void:
	# [enter, loop, exit, enter keys, loop keys, exit keys]; all first values (가안).
	var expected: Dictionary = {
		"sit_bench": [1.1, 4.2, 1.3, 4, 3, 4],
		"sit_floor": [1.5, 4.8, 1.7, 5, 3, 5],
		"lie_bunk": [2.4, 5.6, 2.6, 5, 3, 5],
		"warm_hands_stand": [0.7, 3.2, 0.7, 3, 4, 3],
		"warm_hands_crouch": [1.3, 3.4, 1.5, 4, 4, 4],
		"sleep_lean_wall": [1.6, 5.1, 1.8, 4, 3, 4],
		"kneel": [1.2, 4.0, 1.4, 4, 3, 4],
		"fist_raise": [0.55, 1.7, 0.65, 3, 4, 3],
		"bang_object": [0.6, 1.6, 0.7, 3, 4, 3],
	}
	for name in expected:
		var row: Dictionary = Gesture.spec(name)
		assert_eq(row["kind"], "three", name)
		var first: Array = expected[name]
		for i in 3:
			var part: String = ["enter", "loop", "exit"][i]
			var frames: Array = Gesture.keyframes(name, part)
			assert_eq(frames.size(), int(first[i + 3]), "%s %s keys" % [name, part])
			assert_almost_eq(float(row["length"][part]), float(first[i]), 0.001, "%s %s seconds" % [name, part])
			assert_almost_eq(float(frames.front()["time"]), 0.0, 0.001)
			assert_almost_eq(float(frames.back()["time"]), float(first[i]), 0.001)
			for k in frames.size():
				if k > 0:
					assert_gt(float(frames[k]["time"]), float(frames[k - 1]["time"]), "%s %s key %d" % [name, part, k])
				for bone in frames[k]["bones"]:
					assert_true(BONES.has(String(bone)), "%s %s: real bone %s" % [name, part, bone])
					if bool(row["upper"]):
						assert_false(bone in ["hips", "thigh.L", "thigh.R", "shin.L", "shin.R", "foot.L", "foot.R"],
							"%s upper motion keeps leg %s" % [name, bone])


func test_one_off_key_counts_and_contact_times_are_not_game_hits() -> void:
	for name in ["shove_body", "spring_up", "stomp"]:
		var row: Dictionary = Gesture.spec(name)
		assert_eq(row["kind"], "once", name)
		var frames: Array = Gesture.keyframes(name, "once")
		assert_eq(frames.size(), 4 if name == "stomp" else 5, name)
		var duration: float = 1.4 if name == "shove_body" else (1.1 if name == "spring_up" else 1.0)
		assert_almost_eq(float(frames.back()["time"]), duration, 0.001, name)
		for frame in frames:
			for bone in frame["bones"]:
				assert_true(BONES.has(String(bone)), "%s real bone %s" % [name, bone])
	assert_almost_eq(float(Gesture.keyframes("shove_body", "once")[2]["time"]), 0.58, 0.001)
	assert_eq(Gesture.keyframes("shove_body", "once", 0)[2]["bones"]["chest"], "forward")
	assert_eq(Gesture.keyframes("shove_body", "once", 1)[2]["bones"]["chest"], "react_if_confirmed")
	assert_almost_eq(float(Gesture.keyframes("bang_object", "loop")[2]["time"]), 0.85, 0.001)
	assert_almost_eq(float(Gesture.keyframes("stomp", "once")[2]["time"]), 0.55, 0.001)
	assert_eq(Gesture.keyframes("nonsense", "enter"), [])


func test_all_twelve_record_people_props_hands_weapon_and_mask() -> void:
	for name in FIRST_REST + FIRST_RIOT:
		var row: Dictionary = Gesture.spec(name)
		assert_eq(int(row["people"]), 2 if name == "shove_body" else 1, name)
		assert_false(bool(row["two_hand_weapon"]), name)
		assert_true(row.has("upper"), name)
		assert_true(row.has("pair"), name)
		assert_true(row["prop"].has("left"), name)
		assert_true(row["prop"].has("right"), name)
		assert_true(row.has("base"), name)
	assert_true(bool(Gesture.spec("warm_hands_stand")["upper"]))
	assert_true(bool(Gesture.spec("fist_raise")["upper"]))
	assert_true(bool(Gesture.spec("bang_object")["upper"]))
	assert_false(bool(Gesture.spec("shove_body")["upper"]))
	assert_eq(Gesture.spec("bang_object")["prop"]["right"], "grip")
	assert_eq(Gesture.spec("bang_object")["prop"]["name"], "bowl_or_small_lid")
	assert_eq(Gesture.spec("shove_body")["pair"]["clock"], "shared")


func test_enter_ends_in_the_first_loop_pose_without_a_teleport() -> void:
	for name in FIRST_REST + ["fist_raise", "bang_object"]:
		var row: Dictionary = Gesture.spec(name)
		var enter: float = row["length"]["enter"]
		var after: Dictionary = Gesture.phase_at(name, "enter", enter)
		var repeat: Dictionary = Gesture.phase_at(name, "loop", 0.0)
		assert_eq(after["body_pos"], repeat["body_pos"], name)
		assert_eq(after["body_scale"], repeat["body_scale"], name)
		assert_eq(after["head_pos"], repeat["head_pos"], name)
		for i in 2:
			assert_eq(after["arms"][i]["pos"], repeat["arms"][i]["pos"], name)
		assert_eq(Gesture.at(name, enter)["pose"], repeat["pose"], name)
		assert_eq(Gesture.at(name, 0.0)["pose"], "stand", "%s enters from standing" % name)
	assert_eq(Gesture.phase_at("spring_up", "once", 1.1)["pose"], "stand")
	assert_eq(Gesture.phase_at("stomp", "once", 1.0)["pose"], "stand")


func test_a_stand_in_reads_new_height_facing_and_two_arm_boxes() -> void:
	var b = TrainBody.new()
	add_child_autofree(b)
	b.setup("c1", 2)
	b.set_pose("stand", false)
	Gesture.show(b, "sit_bench", 1.1, 0, 0.3)
	assert_eq(b.pose, "sit")
	# A seated trunk is raised by the seat, so its centre is not below a standing one.
	assert_almost_eq(float(b.body_mesh.position.y), float(TrainBody.pose_at("sit", false)["body_pos"].y), 0.05)
	assert_ne(float(b.body_mesh.position.y), float(TrainBody.pose_at("stand", false)["body_pos"].y))
	var arms: Array = b.get_meta(Gesture.ARMS_META)
	assert_eq(arms.size(), 2)
	assert_true(arms[0].visible)
	assert_true(arms[1].visible)
	Gesture.show_phase(b, "lie_bunk", "loop", 0.0, 0, 0.3)
	assert_eq(b.pose, "sit")
	assert_almost_eq(float(b.rotation.y), 0.3 + PI * 0.5, 0.001)
	assert_eq(b.get_meta(Gesture.ARMS_META), arms)
	Gesture.show(b, "", 0.0, 0, 0.3)
	assert_false(arms[0].visible)
	assert_false(arms[1].visible)


func test_an_upper_clip_leaves_a_walking_body_and_its_scale_alone() -> void:
	for name in ["warm_hands_stand", "fist_raise", "bang_object"]:
		var b = TrainBody.new()
		add_child_autofree(b)
		b.setup("c1", 2)
		b.set_pose("walk", false)
		var scale: Vector3 = b.body_mesh.scale
		Gesture.show_phase(b, name, "loop", 0.2, 0)
		assert_eq(b.pose, "walk", name)
		assert_eq(b.body_mesh.scale, scale, name)
		assert_eq(b.get_meta(Gesture.ARMS_META).size(), 2, name)


func test_interrupting_an_enter_blends_from_the_visible_pose_into_exit() -> void:
	var player = Gesture.new()
	var prepared := {"hands_ready": true, "support": Vector3.ZERO}
	assert_true(player.begin("sit_bench", 0, 81, "stand", prepared))
	assert_eq(player.segment, "enter")
	player.advance(0.55)
	var before: Dictionary = player.frame()
	assert_true(player.cancel(81))
	assert_eq(player.segment, "exit")
	assert_eq(player.frame()["body_pos"], before["body_pos"], "no jump to a finished sitting pose")
	assert_eq(player.frame()["head_pos"], before["head_pos"])
	assert_false(player.cancel(81), "one exit per run")
	player.advance(1.3)
	assert_eq(player.segment, "done")
	assert_false(player.active())
	assert_eq(player.frame()["pose"], "stand")


func test_cancel_in_loop_does_not_finish_a_spare_loop_and_old_runs_cannot_cut_new_runs() -> void:
	var player = Gesture.new()
	var prepared := {"hands_ready": true, "support": Vector3.ZERO}
	assert_true(player.begin("lie_bunk", 0, 82, "stand", prepared))
	player.advance(2.4)
	assert_eq(player.segment, "loop")
	player.advance(1.2)
	var before: Dictionary = player.frame()
	assert_true(player.cancel(82))
	assert_eq(player.frame()["arms"][0]["pos"], before["arms"][0]["pos"])
	assert_eq(player.segment, "exit")
	player.advance(2.6)
	assert_false(player.active())
	assert_true(player.begin("lie_bunk", 0, 83, "stand", prepared))
	assert_false(player.cancel(82), "the older run must not end the new one")
	assert_true(player.active())


func test_one_off_interruption_recovers_without_replaying_its_contact() -> void:
	var player = Gesture.new()
	assert_true(player.begin("stomp", 0, 84, "stand", {"hands_ready": true, "floor_clear": true}))
	player.advance(0.2)
	var held: Dictionary = player.frame()
	assert_true(player.cancel(84))
	assert_almost_eq(player.duration(), 0.7, 0.001, "full-body recovery first value (가안)")
	assert_eq(player.frame()["body_pos"], held["body_pos"])
	player.advance(0.7)
	assert_eq(player.segment, "done")
	assert_false(player.cancel(84))
	assert_false(player.finish_offscreen(84), "cleanup happens once")


func test_shove_pair_needs_real_positions_and_shares_a_contact_frame() -> void:
	var a := Vector3(1.0, 0.0, 0.0)
	var b := Vector3(3.0, 0.0, 0.0)
	assert_eq(Gesture.shove_pair(a, a, 0.58), {}, "a missing second place fails")
	var joined: Dictionary = Gesture.shove_pair(a, b, 0.58, true, 91)
	assert_eq(joined["run_id"], 91)
	assert_eq(joined["time"], 0.58)
	assert_eq(joined["anchors"], [a, b], "caller-owned places, no invented PAIR_GAP")
	assert_almost_eq(float(joined["contact"]), 0.58, 0.001)
	assert_almost_eq(float(joined["facings"][0]), PI * 0.5, 0.001)
	assert_almost_eq(float(joined["facings"][1]), -PI * 0.5, 0.001)
	assert_gt(float(joined["roles"][0]["lean"]), 0.0, "A leans into the contact")
	assert_lt(float(joined["roles"][1]["lean"]), 0.0, "B reacts only when confirmed")
	var missed: Dictionary = Gesture.shove_pair(a, b, 0.58, false, 91)
	assert_gt(float(missed["roles"][1]["lean"]), 0.0, "the visual alone cannot declare a hit")


func test_shove_cancellation_releases_both_even_if_one_was_removed() -> void:
	var a = Gesture.new()
	var b = Gesture.new()
	var context := {"hands_ready": true, "adult": true, "anchors": [Vector3.ZERO, Vector3.RIGHT]}
	assert_false(a.begin("shove_body", 0, 92, "stand", {"hands_ready": true}), "a pair cannot begin alone")
	assert_true(a.begin("shove_body", 0, 92, "stand", context))
	assert_true(b.begin("shove_body", 1, 92, "stand", context))
	assert_true(Gesture.cancel_pair(a, b, 92))
	assert_eq(a.segment, "exit")
	assert_eq(b.segment, "exit")
	assert_false(Gesture.cancel_pair(a, b, 92))
	a.advance(0.7)
	b.advance(0.7)
	assert_false(a.active())
	assert_false(b.active())
	assert_true(a.begin("shove_body", 0, 93, "stand", context))
	assert_true(a.finish_offscreen(93))
	assert_false(a.finish_offscreen(93))
	assert_true(b.begin("shove_body", 1, 93, "stand", context))
	assert_true(Gesture.cancel_pair(null, b, 93), "the surviving body does not keep holding a missing one")
	assert_eq(b.segment, "exit")


func test_unprepared_support_hands_prop_and_floor_fail_at_start() -> void:
	var player = Gesture.new()
	assert_false(player.begin("sit_bench", 0, 1, "stand"))
	assert_false(player.begin("lie_bunk", 0, 1, "stand", {"hands_ready": true}))
	assert_false(player.begin("stomp", 0, 1, "stand", {"hands_ready": true}))
	assert_false(player.begin("bang_object", 0, 1, "stand", {"hands_ready": true}))
	assert_false(player.begin("spring_up", 0, 1, "stand", {"hands_ready": true}))
	assert_false(player.begin("shove_body", 0, 1, "sit", {"hands_ready": true, "adult": true,
		"anchors": [Vector3.ZERO, Vector3.RIGHT]}))
	var prop := Node3D.new()
	add_child_autofree(prop)
	assert_true(player.begin("bang_object", 0, 2, "stand",
		{"hands_ready": true, "prop": prop, "target": Vector3.ZERO}))


func test_motion_contract_runs_entry_exit_and_one_cleanup() -> void:
	var b = TrainBody.new()
	add_child_autofree(b)
	b.setup("c1", 2)
	b.set_pose("stand", false)
	assert_true(MotionContract.start(b, "sit_bench", 101, 0,
		{"hands_ready": true, "support": Vector3.ZERO}))
	assert_eq(MotionContract.step(b, 0.5)["phase"], "enter")
	assert_false(MotionContract.cancel(b, 100))
	assert_true(MotionContract.cancel(b, 101))
	assert_eq(MotionContract.step(b, 1.3)["phase"], "done")
	assert_false(b.has_meta("life_player"))
	assert_false(MotionContract.cancel(b, 101), "it does not replay an older exit")
	for arm in b.get_meta(Gesture.ARMS_META):
		assert_false(arm.visible)


func test_motion_contract_pair_draws_two_positions_on_one_clock() -> void:
	var a = TrainBody.new()
	var b = TrainBody.new()
	add_child_autofree(a)
	add_child_autofree(b)
	a.setup("c1", 2)
	b.setup("c1", 3)
	a.set_pose("stand", false)
	b.set_pose("stand", false)
	a.position = Vector3.ZERO
	b.position = Vector3.RIGHT
	assert_false(MotionContract.show_shove_pair(a, b, 0.58, true, 102), "both runs must be ready")
	var ready := {"hands_ready": true, "adult": true}
	assert_false(MotionContract.start(a, "shove_body", 102, 0, ready), "pair entry is atomic")
	assert_false(MotionContract.start_shove_pair(a, b, 102, ready, {"hands_ready": true}),
		"an unready B must leave no running A")
	assert_false(a.has_meta("life_player"))
	assert_false(b.has_meta("life_player"))
	assert_true(MotionContract.start_shove_pair(a, b, 102, ready, ready))
	assert_true(MotionContract.show_shove_pair(a, b, 0.58, true, 102))
	assert_almost_eq(float(a.rotation.y), PI * 0.5, 0.001)
	assert_almost_eq(float(b.rotation.y), -PI * 0.5, 0.001)
	assert_eq(a.position, Vector3.ZERO)
	assert_eq(b.position, Vector3.RIGHT)
	assert_false(MotionContract.show_shove_pair(a, b, 0.58, true, 101), "a stale run")
	var hit_reaction: float = b.body_mesh.rotation.x
	assert_lt(hit_reaction, 0.0)
	b.position = Vector3.ZERO
	assert_false(MotionContract.show_shove_pair(a, b, 0.58, true, 102), "the pair lost its anchored place")
	b.position = Vector3.RIGHT
	assert_true(MotionContract.cancel_shove_pair(a, b, 102))
	assert_false(MotionContract.show_shove_pair(a, b, 0.58, true, 102), "cancelled pair starts no more contact")
	assert_eq(MotionContract.step(b, 0.0)["phase"], "exit")
	assert_almost_eq(b.body_mesh.rotation.x, hit_reaction, 0.001, "exit begins at the confirmed visible reaction")
	assert_almost_eq(float(b.rotation.y), -PI * 0.5, 0.001, "the paired facing stays through the first exit frame")
	assert_eq(MotionContract.step(a, 0.7)["phase"], "done")
	assert_eq(MotionContract.step(b, 0.7)["phase"], "done")


func test_legacy_ten_keep_the_same_names_pair_gap_base_and_prop() -> void:
	assert_true(Gesture.knows(Gesture.ARGUE), "legacy names now have an explicit availability check")
	assert_eq(Gesture.NAMES.size(), 5)
	assert_eq(Gesture.MORE.size(), 5)
	assert_almost_eq(float(Gesture.PAIR_GAP[Gesture.ARGUE]), 0.95, 0.001)
	assert_almost_eq(float(Gesture.PAIR_GAP[Gesture.WHISPER]), 0.78, 0.001)
	assert_eq(Gesture.base_of(Gesture.HUG_KNEES), {"base": "floor", "huddled": true})
	assert_eq(Gesture.base_of(Gesture.BOWL_SIT), {"base": "sit", "huddled": false})
	assert_eq(Gesture.at(Gesture.BOWL_SIT, 1.0)["prop"]["name"], "bowl")
	assert_eq(Gesture.at(Gesture.ARGUE, 0.0, 0)["turn"], PI * 0.5)
	assert_eq(Gesture.at(Gesture.ARGUE, 0.0, 1)["turn"], -PI * 0.5)


# ---------------------------------------------------------------- the twelve later unrest gestures

func test_later_unrest_three_part_lengths_and_keys() -> void:
	# [enter, loop, exit, enter keys, loop keys, exit keys]; first values (가안).
	var expected: Dictionary = {
		"back_away": [0.4, 0.9, 0.5, 3, 4, 3],
		"watch_flinch": [0.5, 3.0, 0.5, 3, 4, 3],
		"torch_hold": [0.6, 2.4, 0.6, 3, 3, 3],
		"torch_carry": [0.5, 1.0, 0.5, 3, 3, 3],
		"walk_out_smoke": [0.5, 1.1, 0.6, 3, 3, 3],
	}
	for name in expected:
		var row: Dictionary = Gesture.spec(name)
		assert_eq(row["kind"], "three", name)
		assert_true(bool(row["upper"]), "%s keeps the caller's legs" % name)
		var first: Array = expected[name]
		for i in 3:
			var part: String = ["enter", "loop", "exit"][i]
			var frames: Array = Gesture.keyframes(name, part)
			assert_eq(frames.size(), int(first[i + 3]), "%s %s keys" % [name, part])
			assert_almost_eq(float(row["length"][part]), float(first[i]), 0.001, "%s %s seconds" % [name, part])
			assert_almost_eq(float(frames.back()["time"]), float(first[i]), 0.001)
			for k in frames.size():
				if k > 0:
					assert_gt(float(frames[k]["time"]), float(frames[k - 1]["time"]), "%s %s key %d" % [name, part, k])
				for bone in frames[k]["bones"]:
					assert_true(BONES.has(String(bone)), "%s %s: real bone %s" % [name, part, bone])
					assert_false(bone in ["hips", "thigh.L", "thigh.R", "shin.L", "shin.R", "foot.L", "foot.R"],
						"%s upper motion keeps leg %s" % [name, bone])
		var after: Dictionary = Gesture.phase_at(name, "enter", float(row["length"]["enter"]))
		var repeat: Dictionary = Gesture.phase_at(name, "loop", 0.0)
		for i in 2:
			assert_eq(after["arms"][i]["pos"], repeat["arms"][i]["pos"], "%s enters its loop without a jump" % name)


func test_later_unrest_one_off_lengths_keys_and_contacts() -> void:
	# [seconds, keys, {key: contact seconds}]; the contacts are display marks, not hits.
	var expected: Dictionary = {
		"grab_collar": [1.6, 6, {2: 0.5, 3: 0.9}],
		"punch_swing": [1.2, 5, {2: 0.46}],
		"fall_down": [1.3, 5, {3: 0.78}],
		"help_up": [2.0, 5, {2: 0.7}],
		"throw_object": [1.0, 5, {2: 0.48}],
		"tip_crate": [1.5, 5, {3: 1.05}],
		"light_cloth": [1.8, 5, {2: 0.9}],
	}
	for name in expected:
		var row: Dictionary = Gesture.spec(name)
		assert_eq(row["kind"], "once", name)
		assert_false(bool(row["two_hand_weapon"]), name)
		var frames: Array = Gesture.keyframes(name, "once")
		assert_eq(frames.size(), int(expected[name][1]), name)
		assert_almost_eq(float(frames.back()["time"]), float(expected[name][0]), 0.001, name)
		for k in expected[name][2]:
			assert_almost_eq(float(frames[k]["time"]), float(expected[name][2][k]), 0.001, "%s key %d" % [name, k])
		for k in range(1, frames.size()):
			assert_gt(float(frames[k]["time"]), float(frames[k - 1]["time"]), "%s key %d" % [name, k])
		for role in int(row["people"]):
			for frame in Gesture.keyframes(name, "once", role):
				for bone in frame["bones"]:
					assert_true(BONES.has(String(bone)), "%s real bone %s" % [name, bone])
	for name in ["grab_collar", "punch_swing", "help_up"]:
		assert_eq(int(Gesture.spec(name)["people"]), 2, name)
		assert_eq(Gesture.spec(name)["pair"]["clock"], "shared", name)


func test_later_unrest_is_for_adults_except_walking_out_of_smoke() -> void:
	var prop := Node3D.new()
	add_child_autofree(prop)
	var pair: Array = [Vector3.ZERO, Vector3.RIGHT]
	var facts: Dictionary = {"hands_ready": true, "prop": prop, "target": Vector3.FORWARD,
		"floor_clear": true, "anchors": pair}
	var start: Dictionary = {"torch_carry": "walk"}
	for name in MORE_RIOT:
		var from: String = start.get(name, "stand")
		var child = Gesture.new()
		assert_eq(child.begin(name, 0, 1, from, facts), name == "walk_out_smoke", "%s without an adult" % name)
		var grown: Dictionary = facts.duplicate()
		grown["adult"] = true
		var adult = Gesture.new()
		assert_true(adult.begin(name, 0, 2, from, grown), "%s with an adult" % name)


func test_help_up_b_starts_on_the_floor_and_a_fall_ends_there() -> void:
	var facts: Dictionary = {"hands_ready": true, "adult": true, "anchors": [Vector3.ZERO, Vector3.RIGHT]}
	assert_false(Gesture.new().begin("help_up", 1, 1, "stand", facts))
	assert_true(Gesture.new().begin("help_up", 1, 1, "floor", facts))
	assert_false(Gesture.new().begin("help_up", 0, 1, "floor", facts))
	assert_true(Gesture.new().begin("help_up", 0, 1, "stand", facts))
	var fall = Gesture.new()
	assert_false(fall.begin("fall_down", 0, 3, "stand", {"hands_ready": true, "adult": true}), "the floor must be clear")
	assert_true(fall.begin("fall_down", 0, 3, "stand", {"hands_ready": true, "adult": true, "floor_clear": true}))
	assert_eq(Gesture.keyframes("fall_down", "once").back()["visual"], "floor_prop")
	assert_eq(Gesture.phase_at("fall_down", "once", 1.3)["pose"], "floor")
	fall.advance(2.0)
	assert_false(fall.active())
	assert_eq(fall._exit_base, "floor", "a fallen body stays down until it gets up")
	for name in MORE_RIOT:
		for frame in Gesture.keyframes(name, "once" if Gesture.spec(name)["kind"] == "once" else "loop"):
			assert_false(String(frame["visual"]) in ["bunk", "bunk_turn", "bunk_breathe"], "%s never lies flat" % name)


func test_later_pairs_share_one_clock_and_cannot_start_one_sided() -> void:
	var a = TrainBody.new()
	var b = TrainBody.new()
	add_child_autofree(a)
	add_child_autofree(b)
	a.setup("c1", 2)
	b.setup("c1", 3)
	a.set_pose("stand", false)
	b.set_pose("stand", false)
	a.position = Vector3.ZERO
	b.position = Vector3.RIGHT
	var ready := {"hands_ready": true, "adult": true}
	for name in ["grab_collar", "punch_swing", "help_up"]:
		assert_false(MotionContract.start(a, name, 201, 0, ready), "%s goes through the pair entry" % name)
		var joined: Dictionary = Gesture.pair_at(name, Vector3.ZERO, Vector3.RIGHT, 0.5, true, 201)
		assert_eq(joined["roles"].size(), 2, name)
		assert_almost_eq(float(joined["contact"]), float(Gesture.spec(name)["pair"]["contact"]), 0.001, name)
		assert_eq(Gesture.pair_at(name, Vector3.ZERO, Vector3.ZERO, 0.5), {}, name)
	assert_eq(Gesture.pair_at("throw_object", Vector3.ZERO, Vector3.RIGHT, 0.5), {}, "a one-person row has no pair")
	assert_true(MotionContract.start_shove_pair(a, b, 202, ready, ready, "punch_swing"))
	assert_true(MotionContract.show_shove_pair(a, b, 0.46, true, 202, "punch_swing"))
	assert_false(MotionContract.show_shove_pair(a, b, 0.46, true, 202), "the run is a punch, not a shove")
	assert_true(MotionContract.cancel_shove_pair(a, b, 202))
	assert_false(MotionContract.start_shove_pair(a, b, 203, ready, ready, "throw_object"))


func test_old_names_are_offered_only_while_the_backend_draws_them() -> void:
	for name in MotionContract.LEGACY:
		assert_true(Gesture.knows(name), "legacy %s is still drawn" % name)
	for name in MotionContract.FALLBACK:
		assert_true(Gesture.knows(String(MotionContract.FALLBACK[name])), "fallback for %s is drawn" % name)
	var feet: Dictionary = MotionContract.resolve("drag_feet")
	assert_false(feet["native"])
	assert_true(feet["fallback"])
	assert_eq(feet["gesture"], "drag_walk")
	var walk: Dictionary = MotionContract.resolve("drag_walk")
	assert_true(walk["native"])
	assert_eq(walk["gesture"], "drag_walk")


func test_a_borrowed_gesture_turns_from_the_seat_every_frame_and_does_not_wind_up() -> void:
	# look_around has no clip of its own and borrows turn_about, a quarter round
	# and back. Drawn every frame, it turns from the facing the body had before it,
	# not from where the last frame left it: added up frame on frame, a body
	# waiting on its bench spun round and sat down again facing anywhere.
	var b = TrainBody.new()
	add_child_autofree(b)
	b.setup("c1", 2)
	b.rotation.y = 0.3
	assert_eq(MotionContract.resolve("look_around")["gesture"], Gesture.TURN_ABOUT)
	var worst: float = 0.0
	var widest: float = 0.0
	var widest_t: float = 0.0
	var t: float = 0.0
	while t < Gesture.ABOUT_ROUND * 2.0:
		MotionContract.show(b, "look_around", t, 0)
		var own: float = float(Gesture.at(Gesture.TURN_ABOUT, t, 0)["turn"])
		worst = maxf(worst, absf(angle_difference(0.3 + own, b.rotation.y)))
		if absf(own) > widest:
			widest = absf(own)
			widest_t = t
		t += 1.0 / 30.0
	assert_lt(worst, 0.001, "each frame is the seat's facing plus that frame's own turn")
	assert_gt(widest, 1.0, "it still turns to look")
	# Stopped while turned furthest, and even passed straight to another borrowed
	# gesture, it is back where it sat once nothing is drawn.
	MotionContract.show(b, "look_around", widest_t, 0)
	MotionContract.show(b, "chat_talk", widest_t, 0)
	MotionContract.show(b, "", 0.0)
	assert_almost_eq(angle_difference(0.3, b.rotation.y), 0.0, 0.001)
	# Something else that turns the body (a walk, a seat) is where the next one turns from.
	b.rotation.y = 1.2
	MotionContract.show(b, "look_around", widest_t, 0)
	assert_almost_eq(angle_difference(1.2 + float(Gesture.at(Gesture.TURN_ABOUT, widest_t, 0)["turn"]), b.rotation.y), 0.0, 0.001)
	MotionContract.show(b, "", 0.0)
	assert_almost_eq(angle_difference(1.2, b.rotation.y), 0.0, 0.001)
