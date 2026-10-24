extends "res://addons/gut/test.gd"
## 열차 사람 몸(train_people_view.gd): 구운 폴더의 동작 이름, 칸 상태에 따른 동작 고르기,
## 캡슐을 숨기고 그린 몸 수. 값은 읽기만 한다.

const Scene = preload("res://game/train/train_scene.gd")
const Rules = preload("res://game/train/train_rules.gd")
const View = preload("res://game/train/train_people_view.gd")
const TrainClips = preload("res://game/train/train_clips.gd")
const Body = preload("res://game/train/train_body.gd")
const Gesture = preload("res://game/train/train_gesture.gd")
const BodyBake = preload("res://scripts/body_bake.gd")


func _state(over: Dictionary = {}) -> Dictionary:
	var s := {"layout": "coach", "warmth": 60.0, "cold": false, "freezing": false, "exposure": 0.0, "night": false, "stove_x": 7.85}
	s.merge(over, true)
	return s


func _body(pose: String, gesture: String = "") -> Node3D:
	var b: Node3D = autofree(Body.new())
	b.pose = pose
	b.gesture = gesture
	return b


func test_the_baked_folder_has_every_train_motion_by_name() -> void:
	var baked: Dictionary = BodyBake.load_baked(TrainClips.FOLDER)
	assert_false(baked.is_empty())
	var names: Array = (baked["clips"] as Array).map(func(c): return String(c["name"]))
	assert_eq(names, TrainClips.names())
	assert_lte(names.size(), 32, "the shader's clip tables have thirty-two places")
	for n in names:
		assert_true(String(n).begins_with("t_"), n)


func test_the_cars_state_picks_the_motion() -> void:
	assert_eq(View.clip_for(_body("walk"), _state(), "", 1), "t_walk")
	assert_eq(View.clip_for(_body("stand"), _state({"cold": true, "freezing": true}), "", 1), "t_shiver", "a freezing car shivers")
	assert_eq(View.clip_for(_body("stand"), _state({"cold": true, "exposure": 80.0}), "", 3), "t_cough", "exposure in the cold coughs")
	assert_eq(View.clip_for(_body("sit", Gesture.BOWL_SIT), _state(), "", 1), "t_eat", "hunger holds a bowl")
	assert_eq(View.clip_for(_body("stand", Gesture.ARMS_CROSSED), _state(), "", 1), "t_fold")
	assert_has(["t_talk", "t_no"], View.clip_for(_body("stand", Gesture.ARGUE), _state(), "", 1), "tension argues")
	assert_eq(View.clip_for(_body("stand"), _state({"layout": "guard", "night": true}), "", 1), "t_lantern", "the guard keeps watch")
	assert_eq(View.clip_for(_body("floor"), _state(), "warm", 1), "t_warm_hands", "hands out to the stove")
	assert_eq(View.clip_for(_body("sit"), _state(), "heal", 1), "t_lie")
	assert_eq(View.clip_for(_body("stand"), _state(), "cook", 1), "t_stir")
	assert_eq(View.clip_for(_body("floor"), _state(), "care", 1), "t_kneel_work")
	var huddled := _body("sit")
	huddled.huddled = true
	assert_eq(View.clip_for(huddled, _state({"cold": true}), "", 1), "t_sit_huddle")
	for clip in ["t_walk", "t_shiver", "t_cough", "t_eat", "t_fold", "t_lantern", "t_warm_hands", "t_lie", "t_stir", "t_kneel_work", "t_sit_huddle"]:
		assert_has(TrainClips.names(), clip)


func test_the_view_draws_every_body_and_hides_the_capsules() -> void:
	var s := Scene.new()
	s.rules = Rules.load_default()
	s.opts = {"seed": 7, "panel": false}
	add_child_autofree(s)
	assert_not_null(s.people_view)
	if s.people_view == null:
		return
	assert_true(s.people_view.is_worn())
	s.people_view._process(0.016)
	var bodies := 0
	for c in s.cars:
		for b in c["bodies"]:
			bodies += 1
			assert_false(b.body_mesh.visible, "the capsule is hidden")
			assert_true(s.people_view.drawn.has(b))
	var shown := 0
	for d in s.people_view.draws:
		shown += (d as MultiMeshInstance3D).multimesh.visible_instance_count
	assert_eq(shown, bodies)
	assert_eq(s.people_view.draws.size(), View.COATS.size(), "one draw a coat for the whole train")
