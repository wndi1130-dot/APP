extends "res://addons/gut/test.gd"
## The gestures of people inside the train are read off one clock and give
## where the trunk, the head and the arms sit. Nothing here moves anyone along
## the car or decides who does what.

const Gesture = preload("res://game/train/train_gesture.gd")


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
