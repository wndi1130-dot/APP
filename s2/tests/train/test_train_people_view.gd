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
	var s := {"layout": "coach", "warmth": 60.0, "cold": false, "freezing": false, "exposure": 0.0, "night": false, "stove_x": 7.85, "ration": 70.0, "crowding": 40.0, "tension": 0.0, "fear": 0.0, "resent": false}
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


func test_what_the_scene_and_the_life_plan_decide_comes_first() -> void:
	assert_eq(View.want_for(_body("walk"), _state(), "", 1), "t_walk")
	assert_eq(View.want_for(_body("sit", Gesture.BOWL_SIT), _state(), "", 1), "t_eat", "hunger holds a bowl")
	assert_eq(View.want_for(_body("stand", Gesture.ARMS_CROSSED), _state(), "", 1), "t_fold")
	assert_eq(View.want_for(_body("stand", Gesture.RUB_STAMP), _state(), "", 1), "t_shiver")
	assert_has(["t_talk", "t_no"], View.want_for(_body("stand", Gesture.ARGUE), _state(), "", 1), "tension argues")
	assert_eq(View.want_for(_body("stand"), _state({"layout": "guard"}), "watch", 1), "t_lantern", "the guard keeps watch")
	assert_eq(View.want_for(_body("floor"), _state(), "warm", 1), "t_warm_hands", "hands out to the stove")
	assert_eq(View.want_for(_body("sit"), _state(), "heal", 1), "t_lie")
	assert_eq(View.want_for(_body("stand"), _state(), "cook", 1), "t_stir")
	assert_eq(View.want_for(_body("stand"), _state({"layout": "technical"}), "work", 1), "t_shovel", "coal is shovelled")
	assert_eq(View.want_for(_body("floor"), _state(), "care", 1), "t_kneel_work")
	var huddled := _body("sit")
	huddled.huddled = true
	assert_eq(View.want_for(huddled, _state({"cold": true}), "", 1), "t_sit_huddle")
	for clip in ["t_walk", "t_shiver", "t_cough", "t_eat", "t_fold", "t_lantern", "t_warm_hands", "t_lie", "t_stir", "t_kneel_work", "t_sit_huddle", "t_shovel"]:
		assert_has(TrainClips.names(), clip)


## Every clip the picks can give is a baked one.
func test_every_pick_is_a_baked_motion() -> void:
	var names := TrainClips.names()
	for pose in ["sit", "floor", "stand"]:
		var body: Node3D = add_child_autofree(Body.new())
		body.pose = pose
		var w: Dictionary = View.weights_for(pose, body, _state({"warmth": 20.0, "exposure": 90.0, "night": true, "layout": "guard"}), View.traits_of(5))
		for clip in w:
			assert_has(names, clip, pose)
	for clip in View.POSTURE:
		assert_has(names, clip)
	for k in View.BRIDGES:
		assert_has(names, String(View.BRIDGES[k][0]), k)


## One bench is not one motion: people differ, and the car's state moves the odds.
func test_people_differ_and_the_cold_moves_the_odds() -> void:
	var warm := {}
	var cold := {}
	var traits := {}
	for key in range(100, 160):
		var w := View.want_for(_body("sit"), _state(), "", key, 3.0)
		var c := View.want_for(_body("sit"), _state({"warmth": 20.0, "cold": true, "freezing": true}), "", key, 3.0)
		warm[w] = int(warm.get(w, 0)) + 1
		cold[c] = int(cold.get(c, 0)) + 1
		traits[str(View.traits_of(key))] = true
	assert_gte(warm.size(), 2, "a warm bench is not all one motion: %s" % [warm])
	assert_gte(cold.size(), 3, "a cold bench is not all one motion: %s" % [cold])
	assert_gt(int(cold.get("t_sit_huddle", 0)), int(warm.get("t_sit_huddle", 0)), "the cold huddles more")
	assert_eq(traits.size(), 60, "no two people share their traits")
	var coughs_warm := 0
	var coughs_out := 0
	for key in range(200, 260):
		coughs_warm += int(View.want_for(_body("stand"), _state(), "", key, 1.0) == "t_cough")
		coughs_out += int(View.want_for(_body("stand"), _state({"warmth": 25.0, "exposure": 90.0}), "", key, 1.0) == "t_cough")
	assert_eq(coughs_warm, 0, "nobody coughs in a warm sheltered car")
	assert_between(coughs_out, 3, 50, "exposure in the cold makes some cough, not all")


## One person keeps at a thing for a while, then their own timetable moves them on.
func test_a_persons_timetable_holds_then_changes() -> void:
	var b := _body("sit")
	var s := _state({"night": true})
	assert_eq(View.want_for(b, s, "", 77, 10.0), View.want_for(b, s, "", 77, 10.0), "the same moment, the same pick")
	var seen := {}
	var changes := 0
	var last := ""
	for i in 240:
		var c := View.want_for(b, s, "", 77, float(i) * 0.5)
		seen[c] = true
		if last != "" and c != last:
			changes += 1
		last = c
	assert_gte(seen.size(), 2, "over two minutes one person does more than one thing")
	assert_lte(float(changes), 120.0 / View.HOLD_FROM + 1.0, "but not every moment")


## The transition layer: a change of the car's state is taken by a few first and
## the rest after, each at their own delay; a scene move is taken at once.
func test_a_change_reaches_people_one_after_another() -> void:
	var view: Node3D = autofree(View.new())
	var bodies: Array = []
	for i in 40:
		bodies.append(_body("sit"))
	for b in bodies:
		view.shown_for(b, "t_sit", 0.0)
	var at := func(t: float) -> int:
		var n := 0
		for b in bodies:
			n += int(view.shown_for(b, "t_sit_huddle", t) == "t_sit_huddle")
		return n
	assert_eq(at.call(0.1), 0, "nobody at once")
	var first: int = at.call(1.2)
	assert_between(first, 1, 30, "a few react first")
	assert_eq(at.call(View.REACT_TO + 0.5), bodies.size(), "and the rest follow")
	# The scene stands one up: that is taken at once.
	var b: Node3D = bodies[0]
	b.pose = "stand"
	assert_eq(view.shown_for(b, "t_stand", View.REACT_TO + 0.6), "t_stand")
	b.gesture = Gesture.ARGUE
	assert_eq(view.shown_for(b, "t_no", View.REACT_TO + 0.7), "t_no", "a gesture keeps its own beat")


func test_a_joining_motion_goes_between_two() -> void:
	var view: Node3D = autofree(View.new())
	var b := _body("floor")
	view.shown_for(b, "t_floor_sit", 0.0)
	view.shown_for(b, "t_warm_hands", 1.0)
	var t := 1.0 + View.REACT_TO + 0.1
	var bridge: Array = View.BRIDGES["*>t_warm_hands"]
	assert_eq(view.shown_for(b, "t_warm_hands", t), String(bridge[0]), "first the joining motion")
	assert_eq(view.shown_for(b, "t_warm_hands", t + float(bridge[1]) * 0.5), String(bridge[0]))
	assert_eq(view.shown_for(b, "t_warm_hands", t + float(bridge[1]) + 0.05), "t_warm_hands", "then the motion")


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
