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
	var s := {"layout": "coach", "warmth": 60.0, "cold": false, "freezing": false, "exposure": 0.0, "night": false, "stove_x": 7.85, "ration": 70.0, "crowding": 40.0, "tension": 0.0, "fear": 0.0, "resent": false, "meal": false}
	s.merge(over, true)
	return s


func _body_in_tree(pose: String) -> Node3D:
	var b: Node3D = add_child_autofree(Body.new())
	b.pose = pose
	return b


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
	assert_lte(names.size(), 128, "the shader's clip tables have a hundred and twenty-eight places")
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
			bodies += int(s.people_view.on_screen(c))
			assert_false(b.body_mesh.visible, "the capsule is hidden")
			assert_true(s.people_view.drawn.has(b))
	var shown := 0
	for d in s.people_view.draws:
		shown += (d as MultiMeshInstance3D).multimesh.visible_instance_count
	assert_eq(shown, bodies, "everyone in the cars on the screen")
	assert_eq(s.people_view.draws.size(), s.people_view.bodies.size(), "one draw a body for the whole train")
	var wearing := {}
	for b in s.people_view.worn:
		wearing[s.people_view.worn[b]] = true
	assert_gte(wearing.size(), 3, "the train is not one body: %s" % [wearing.keys()])


## Every body the train can pick was baked with the same train motions, picture and all.
func test_every_train_body_is_baked_with_the_train_motions() -> void:
	var folders: Array = View.GENERAL_BODIES.duplicate()
	for role in View.ROLE_BODIES:
		folders.append_array(View.ROLE_BODIES[role])
	for folder in folders:
		var dir: String = View.PEOPLE_DIR + String(folder)
		var baked: Dictionary = BodyBake.load_baked(dir)
		assert_false(baked.is_empty(), folder)
		if baked.is_empty():
			continue
		var names: Array = (baked["clips"] as Array).map(func(c): return String(c["name"]))
		assert_eq(names, TrainClips.names(), folder)
		assert_true(ResourceLoader.exists(dir.path_join("albedo.png")), folder + " has its own picture")


## The car and the person's work pick the body; the rest wear ordinary clothes,
## and neighbours differ.
func test_the_car_and_the_work_pick_the_body() -> void:
	assert_has(View.ROLE_BODIES["cook"], View.body_for("dining", "cook", 0, 5, ""))
	assert_has(View.ROLE_BODIES["carer"], View.body_for("medical", "carer", 0, 5, ""))
	assert_has(View.ROLE_BODIES["stoker"], View.body_for("technical", "worker", 0, 5, ""))
	assert_has(View.ROLE_BODIES["stoker"], View.body_for("loco", "", 0, 5, ""))
	assert_eq(View.body_for("guard", "", 0, 5, ""), View.ROLE_BODIES["guard"][0], "the guard car's first guard")
	assert_has(View.ROLE_BODIES["guard"], View.body_for("guard", "", 1, 5, ""), "and its second")
	assert_has(View.GENERAL_BODIES, View.body_for("guard", "", View.ROLE_A_CAR, 5, ""), "the rest of the guard car is plain")
	assert_has(View.GENERAL_BODIES, View.body_for("medical", "carer", View.ROLE_A_CAR, 5, ""), "two carers a car, not a car of them")
	assert_has(View.GENERAL_BODIES, View.body_for("dining", "cook", View.ROLE_A_CAR, 5, ""), "two cooks a car")
	assert_has(View.GENERAL_BODIES, View.body_for("coach", "", 0, 5, ""))
	assert_has(View.GENERAL_BODIES, View.body_for("medical", "", 0, 5, ""), "a patient wears their own clothes")
	for key in range(0, 40):
		var first := View.body_for("coach", "", 0, key, "")
		assert_ne(View.body_for("coach", "", 0, key, first), first, "no two neighbours in one body")


## A car at ease rests, talks and eats as a car of its kind does (user
## 2026-10-25: a peaceful train shown at random), and the work in it shows.
func test_a_calm_car_does_what_its_kind_does() -> void:
	var calm := {"warmth": 72.0, "ration": 85.0}
	var eat := {"dining": 0, "coach": 0}
	var doze := {"guard": 0, "coach": 0}
	var kneel := {"carer": 0, "none": 0}
	var stir := 0
	for key in range(300, 380):
		for layout in ["dining", "coach"]:
			var st := _state(calm.merged({"layout": layout, "meal": true}))
			eat[layout] += int(View.want_for(_body("sit"), st, "", key, 2.0) == "t_eat")
		for layout in ["guard", "coach"]:
			var st := _state(calm.merged({"layout": layout, "night": true}))
			doze[layout] += int(View.want_for(_body("sit"), st, "", key, 2.0) == "t_sit_doze")
		kneel["carer"] += int(View.want_for(_body_in_tree("floor"), _state(calm.merged({"layout": "medical"})), "", key, 2.0, {"role": "carer"}) == "t_kneel_work")
		kneel["none"] += int(View.want_for(_body_in_tree("floor"), _state(calm.merged({"layout": "coach"})), "", key, 2.0) == "t_kneel_work")
		stir += int(View.want_for(_body("stand"), _state(calm.merged({"layout": "dining"})), "", key, 2.0, {"role": "cook"}) == "t_stir")
	assert_gt(eat["dining"], eat["coach"] + 5, "the dining car eats at the table: %s" % [eat])
	assert_lt(doze["guard"], doze["coach"], "the guards keep awake: %s" % [doze])
	assert_gt(kneel["carer"], 5, "the carers tend")
	assert_eq(kneel["none"], 0, "nobody kneels to work for nothing")
	assert_gt(stir, 5, "the cook stirs the pot")


## Two side by side do not do the same thing at the same moment, unless talking together.
func test_the_one_beside_is_not_copied() -> void:
	var st := _state({"warmth": 72.0, "ration": 85.0, "night": true})
	var same := 0
	for key in range(500, 600):
		var first := View.want_for(_body("sit"), st, "", key, 3.0)
		var next := View.want_for(_body("sit"), st, "", key, 3.0, {}, first)
		if next == first and not View.TOGETHER.has(first):
			same += 1
	assert_lte(same, 2, "the one beside is not a copy")


func test_people_are_taken_in_seat_order() -> void:
	var list: Array = []
	for x in [5.0, 1.0, 3.0]:
		var b: Node3D = add_child_autofree(Body.new())
		b.position = Vector3(x, 0, 0)
		list.append(b)
	var ordered: Array = View.in_seat_order(list)
	assert_eq(ordered.map(func(b): return b.position.x), [1.0, 3.0, 5.0])


## A guard car: at most LAP_GUNS guns lie across knees, one draw for all.
func test_guards_have_at_most_two_guns_on_their_knees() -> void:
	var s := Scene.new()
	s.rules = Rules.load_default()
	s.rules["cars"].append({"id": "guard1", "kind": "comm", "comm": "front", "interior": "guard", "name": "경비"})
	s.opts = {"seed": 7, "panel": false}
	add_child_autofree(s)
	if s.people_view == null or s.people_view.guns == null:
		pass_test("no baked people or no gun here")
		return
	for i in 30:
		s.people_view._process(0.1)
		s.clock += 1.0
		assert_lte(s.people_view.guns.multimesh.visible_instance_count, View.LAP_GUNS)


## The cold's tremble (user 2026-10-25): nobody in a warm car, in a freezing one
## those the cold gets to, each as much as it gets to them, never past SHIVER_MAX.
func test_the_cold_trembles_some_and_not_the_warm() -> void:
	var warm := 0
	var cool := 0
	var amounts := {}
	for key in range(100, 160):
		warm += int(View.shiver_for(_state(), View.traits_of(key)) > 0.0)
		cool += int(View.shiver_for(_state({"warmth": 40.0, "cold": true}), View.traits_of(key)) > 0.0)
		var s := View.shiver_for(_state({"warmth": 15.0, "cold": true, "freezing": true}), View.traits_of(key))
		assert_between(s, 0.0, View.SHIVER_MAX)
		amounts[snappedf(s, 0.01)] = true
	assert_eq(warm, 0, "nobody trembles in a warm car")
	assert_between(cool, 10, 50, "in a cold car some do, not every one")
	assert_gte(amounts.size(), 10, "each as much as the cold gets to them")


## Neighbours on a cold bench share one blanket, two or three under it.
func test_neighbours_on_a_cold_bench_share_a_blanket() -> void:
	var cold := _state({"warmth": 20.0, "cold": true, "freezing": true})
	var rows: Array = []
	for i in 5:
		rows.append({"x": 1.2 + 0.95 * i, "free": true, "cold": 0.1})
	assert_eq(View.blanket_groups(rows, _state()), [], "not in a warm car")
	assert_eq(View.blanket_groups(rows, cold), [[0, 1, 2], [3, 4]], "five side by side: three and two")
	rows[2]["free"] = false
	assert_eq(View.blanket_groups(rows, cold), [[0, 1], [3, 4]], "one at something else breaks the bench")
	rows[2]["free"] = true
	rows[3]["x"] = 1.2 + 0.95 * 4
	rows[4]["x"] = 1.2 + 0.95 * 5
	assert_eq(View.blanket_groups(rows, cold), [[0, 1, 2], [3, 4]], "a gap starts another")
	for r in rows:
		r["cold"] = 0.7
	assert_eq(View.blanket_groups(rows, _state({"warmth": 40.0, "cold": true})), [], "nor for those the cold has not got to")
	var many: Array = []
	for i in 12:
		many.append({"x": 0.95 * i, "free": true, "cold": 0.1})
	assert_eq(View.blanket_groups(many, cold).size(), View.BLANKETS_A_CAR)
	var under := _body("sit")
	assert_eq(View.want_for(under, _state(), "", 5, 1.0, {"blanket": true}), "t_sit_huddle", "hunched up under it")


## The cloth lies over the shoulders, not over the heads, and faces outward.
func test_the_blanket_lies_on_the_shoulders() -> void:
	for n in [2, 3]:
		var mesh := View.blanket_mesh(n)
		var box := mesh.get_aabb()
		assert_almost_eq(box.size.x, View.BLANKET_STEP * (n - 1) + 2.0 * View.BLANKET_EDGE, 0.01)
		assert_lt(box.end.y, 1.06, "below the hunched heads' tops")
		assert_gt(box.end.y, 0.95, "over the shoulders")
		var arrays := mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var up := 0
		var tops := 0
		for i in verts.size():
			if verts[i].y > 0.98:
				tops += 1
				up += int(normals[i].y > 0.3)
		assert_gt(tops, 0)
		assert_eq(up, tops, "the top of the cloth faces up")
		assert_lt(mesh.get_faces().size() / 3, 2600, "a blanket stays light")


## A freezing car: some tremble, neighbours pull a blanket up, a few breathe
## out; warm again, the blankets go down and the breath stops.
func test_a_freezing_car_trembles_shares_blankets_and_breathes() -> void:
	var s := Scene.new()
	s.rules = Rules.load_default()
	s.opts = {"seed": 7, "panel": false}
	add_child_autofree(s)
	if s.people_view == null:
		pass_test("no baked people here")
		return
	var view = s.people_view
	# The thirteen-car train starts the camera away from tail1; only cars on
	# the screen breathe.
	s.focus_car("tail1")
	assert_true(s.set_sit("tail", 0, 15.0), "a freezing tail")
	for i in 40:
		s.step(0.5)
		view._process(0.5)
	var c: Dictionary = s.car("tail1")
	var trembling := 0
	for b in c["bodies"]:
		trembling += int(float(view.shivers.get(b, 0.0)) > 0.05)
	assert_gt(trembling, 0, "some tremble in the cold")
	var under := 0
	for d in view.blankets:
		under += (d as MultiMeshInstance3D).multimesh.visible_instance_count
	assert_gt(under, 0, "neighbours share a blanket")
	assert_true(view.breath.has("tail1"), "breath shows in the freezing car")
	if view.breath.has("tail1"):
		assert_true((view.breath["tail1"]["p"] as GPUParticles3D).emitting)
	assert_true(s.set_sit("tail", 0, 75.0), "warm again")
	for i in 40:
		s.step(0.5)
		view._process(0.5)
	under = 0
	for d in view.blankets:
		under += (d as MultiMeshInstance3D).multimesh.visible_instance_count
	assert_eq(under, 0, "the blankets are put away")
	for b in c["bodies"]:
		assert_lt(float(view.shivers.get(b, 0.0)), View.BREATH_FROM, "the trembling has died down")
	if view.breath.has("tail1"):
		assert_false((view.breath["tail1"]["p"] as GPUParticles3D).emitting, "no breath")


## One under a blanket taken off the car (a reseat takes the body out of the
## tree before it is freed): the blanket goes with them, and the body out of
## the tree is not asked where it is (an engine error, which fails the test).
func test_a_blanket_goes_with_one_taken_off_the_car() -> void:
	var s := Scene.new()
	s.rules = Rules.load_default()
	s.opts = {"seed": 7, "panel": false}
	add_child_autofree(s)
	if s.people_view == null:
		pass_test("no baked people here")
		return
	var view = s.people_view
	assert_true(s.set_sit("tail", 0, 15.0), "a freezing tail")
	for i in 40:
		s.step(0.5)
		view._process(0.5)
	var c: Dictionary = s.car("tail1")
	var gone: Node3D = null
	var key := -1
	for k in view.covers:
		var under: Array = view.covers[k]["under"]
		if (c["bodies"] as Array).has(under[0]):
			gone = under[0]
			key = k
			break
	assert_not_null(gone, "a blanket is up in the freezing tail")
	if gone == null:
		return
	(c["bodies"] as Array).erase(gone)
	s.people.remove_child(gone)
	gone.queue_free()
	view._process(0.5)
	assert_false(view.covers.has(key), "the blanket goes with them")


## A long train draws only the cars on the screen (one draw a body would
## otherwise put every car's people in every frame); the rest go on living.
func test_only_the_cars_on_the_screen_are_drawn() -> void:
	var s := Scene.new()
	s.rules = Rules.load_default()
	for i in 6:
		s.rules["cars"].append({"id": "tail_x%d" % i, "kind": "comm", "comm": "tail", "name": "꼬리칸"})
	s.opts = {"seed": 7, "panel": false}
	add_child_autofree(s)
	var view = s.people_view
	if view == null:
		pass_test("no baked people here")
		return
	s.focus_car("tail1")
	view._process(0.016)
	var far: Dictionary = s.cars[s.cars.size() - 1]
	assert_false(view.on_screen(far), "the far end is off the screen")
	assert_true(view.on_screen(s.car("tail1")))
	var drawn_now := 0
	for d in view.draws:
		drawn_now += (d as MultiMeshInstance3D).multimesh.visible_instance_count
	var everyone := 0
	for c in s.cars:
		everyone += (c["bodies"] as Array).size()
	assert_lt(drawn_now, everyone, "not the whole train")
	for b in far["bodies"]:
		assert_true(view.drawn.has(b), "they still live their lives")
	s.focus_car(String(far["id"]))
	view._process(0.016)
	assert_true(view.on_screen(far), "scrolled to")
	assert_false(view.on_screen(s.car("tail1")))
