extends "res://addons/gut/test.gd"

const Interaction = preload("res://game/train/train_interaction.gd")
const Catalog = preload("res://game/train/train_catalog.gd")
const Motion = preload("res://game/train/train_motion_contract.gd")

class WithoutKnows:
	extends RefCounted
	static func marker() -> bool: return true

class Declines:
	extends RefCounted
	static func knows(_name: String) -> bool: return false

class Accepts:
	extends RefCounted
	static func knows(name: String) -> bool: return name == "teach_point"


func _pair():
	var scene = Interaction.new()
	scene.setup("chat", Catalog.data()["interactions"]["chat"])
	return scene


func test_pair_waits_for_both_actors_then_enters_loops_and_exits() -> void:
	var s = _pair()
	assert_true(s.invite(10, 0))
	assert_false(s.invite(10, 1))
	assert_false(s.invite(11, 0))
	assert_true(s.invite(11, 1))
	s.arrive(10)
	assert_eq(s.phase, "invite")
	s.arrive(11)
	assert_eq(s.phase, "enter")
	assert_eq(s.gesture(10), "chat_talk")
	assert_eq(s.gesture(11), "chat_listen")
	s.advance(float(s.spec["enter"]))
	assert_eq(s.phase, "loop")
	s.advance(float(s.spec["loop"]))
	assert_eq(s.phase, "exit")
	s.advance(float(s.spec["exit"]))
	assert_true(s.ended)


func test_interrupt_while_waiting_or_looping_reaches_exit_and_releases() -> void:
	for when in ["invite", "loop"]:
		var s = _pair()
		s.invite(1, 0)
		s.invite(2, 1)
		if when == "loop":
			s.arrive(1)
			s.arrive(2)
			s.advance(float(s.spec["enter"]))
		s.receive("accident")
		assert_eq(s.phase, "exit")
		s.advance(float(s.spec["exit"]))
		assert_true(s.ended)
		assert_eq(s.reason, "accident")


func test_missing_partner_times_out_instead_of_holding_a_place_forever() -> void:
	var s = _pair()
	s.invite(1, 0)
	s.advance(float(s.spec["invite_timeout"]))
	assert_eq(s.phase, "exit")
	assert_eq(s.reason, "invite_timeout")


func test_bell_and_wrench_have_one_chair_and_a_shared_response() -> void:
	for cue in ["bell", "wrench"]:
		var s = Interaction.new()
		s.setup("council", Catalog.data()["interactions"]["council"])
		for i in 4:
			s.invite(i, i)
		for i in 4:
			s.arrive(i)
		s.receive(cue)
		assert_eq(s.gesture(0), "ring_bell" if cue == "bell" else "bang_flue_wrench")
		for i in range(1, 4):
			assert_eq(s.gesture(i), "freeze_look")


func test_no_knows_and_false_knows_use_existing_gesture_or_safe_pose() -> void:
	for script in [WithoutKnows, Declines]:
		var chat := Motion.resolve("chat_talk", script)
		assert_true(chat["fallback"])
		assert_eq(chat["gesture"], "whisper")
		var sleep := Motion.resolve("lie_bunk", script)
		assert_eq(sleep["gesture"], "")
		assert_eq(sleep["pose"], "sit")
		var missing := Motion.resolve("unknown_clip", script)
		assert_eq(missing["gesture"], "")
		assert_eq(missing["pose"], "stand")
	assert_eq(Motion.resolve("teach_point", Accepts)["gesture"], "teach_point")
	assert_false(Motion.resolve("teach_point", Accepts)["fallback"])


func test_all_stage_names_stay_inside_the_shared_contract() -> void:
	var names := ["chat_talk", "window_watch", "warm_hands_stand", "catch_breath", "chat_listen", "look_around", "fist_raise", "stand_point", "bang_object", "stomp", "spring_up", "shove_body", "throw_object", "push_pair", "strike_pair", "set_fire", "freeze_look", "help_walk_pair", "head_down", "tend_sick"]
	for stage in Catalog.data()["collapse"]:
		assert_lte(int(stage["moving"]), 4)
		for name in stage["gestures"]:
			assert_true(names.has(name))
			assert_false(String(name).begins_with("collapse_"))
