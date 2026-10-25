extends "res://addons/gut/test.gd"
## 열차 사람이 사건을 받아들이는 모습(train_people_view.gd, 사용자 2026-10-25: 유저 결정마다
## 그 칸 누군가가 반응하고 며칠 그 기색이 남는다). 사건 꼴은 {kind, car, comm, sign, size, day}.
## 규칙 값은 읽기만 한다.

const Scene = preload("res://game/train/train_scene.gd")
const Rules = preload("res://game/train/train_rules.gd")
const View = preload("res://game/train/train_people_view.gd")
const Body = preload("res://game/train/train_body.gd")
const Gesture = preload("res://game/train/train_gesture.gd")


func _rules() -> Dictionary:
	return Rules.load_default()


func _kinds(evs: Array) -> Array:
	return evs.map(func(e): return String(e["kind"]))


func _scene(extra_cars: Array = []) -> Node3D:
	var s := Scene.new()
	s.rules = Rules.load_default()
	for c in extra_cars:
		s.rules["cars"].append(c)
	s.opts = {"seed": 7, "panel": false}
	add_child_autofree(s)
	return s


func test_the_rule_values_tell_what_happened() -> void:
	var a := _rules()
	assert_eq(View.events_between(a, a.duplicate(true), 3), [], "nothing changed, nothing happened")
	var b := a.duplicate(true)
	b["train"]["passed"] = {"evening_pot": true}
	var evs := View.events_between(a, b, 3)
	assert_eq(_kinds(evs), ["law_passed"])
	assert_eq(evs[0]["law"], "evening_pot")
	assert_eq(int(evs[0]["day"]), 3)
	assert_eq(_kinds(View.events_between(b, a, 3)), ["law_repealed"])
	var cut := a.duplicate(true)
	cut["comms"]["tail"]["sit"][1] = float(a["comms"]["tail"]["sit"][1]) - 15.0
	evs = View.events_between(a, cut, 3)
	assert_eq(_kinds(evs), ["ration"])
	assert_eq(evs[0]["comm"], "tail")
	assert_eq(int(evs[0]["sign"]), -1, "rations cut")
	var nudge := a.duplicate(true)
	nudge["comms"]["tail"]["sit"][1] = float(a["comms"]["tail"]["sit"][1]) + 3.0
	assert_eq(View.events_between(a, nudge, 3), [], "a small move is not an event")
	var out := a.duplicate(true)
	out["comms"]["tail"]["away"] = 6
	assert_eq(_kinds(View.events_between(a, out, 3)), ["party_out"])
	assert_eq(_kinds(View.events_between(out, a, 3)), ["party_back"])
	var more := a.duplicate(true)
	more["comms"]["tail"]["pop"] = int(a["comms"]["tail"]["pop"]) + 8
	assert_eq(_kinds(View.events_between(a, more, 3)), ["taken_in"])
	assert_eq(_kinds(View.events_between(more, a, 3)), ["let_go"])
	var dead := a.duplicate(true)
	dead["train"]["stored"] = 2
	dead["comms"]["tail"]["pop"] = int(a["comms"]["tail"]["pop"]) - 2
	assert_eq(_kinds(View.events_between(a, dead, 3)), ["dead_stored"], "the dead are not counted as let go")
	var mourn := a.duplicate(true)
	mourn["view"]["memorial"] = true
	assert_eq(_kinds(View.events_between(a, mourn, 3)), ["memorial"])
	var decree := a.duplicate(true)
	decree["train"]["decreeLeft"] = 2
	assert_eq(_kinds(View.events_between(a, decree, 3)), ["decree"])
	var vote := a.duplicate(true)
	vote["train"]["voting"] = true
	assert_eq(_kinds(View.events_between(a, vote, 3)), ["vote_called"])
	assert_eq(_kinds(View.events_between(vote, a, 3)), ["vote_done"])


func test_an_event_reaches_its_cars() -> void:
	var s := _scene([{"id": "workshop", "kind": "technical", "name": "공방"}])
	var ids := func(evs: Array) -> Array: return evs.map(func(c): return String(c["id"]))
	assert_eq(ids.call(View.cars_for({"kind": "ration", "comm": "tail"}, s.cars)), ["tail1"])
	assert_eq(ids.call(View.cars_for({"kind": "mod_done", "car": "medtech"}, s.cars)), ["medtech"])
	assert_eq(ids.call(View.cars_for({"kind": "made", "car": "", "comm": ""}, s.cars)), ["workshop"], "what was made is seen in the workshop")
	var wide: Array = ids.call(View.cars_for({"kind": "law_passed"}, s.cars))
	assert_eq(wide[0], "dining", "a law is seen first where the council sits")
	assert_gt(wide.size(), 2)
	for c in s.cars:
		if String((c["def"] as Dictionary).get("kind", "")) in ["loco", "engine", "tender", "freight"]:
			assert_does_not_have(wide, String(c["id"]), "not in the engine")


## A few react, more for a bigger event, each in their own way; another day, another few.
func test_people_take_it_each_in_their_own_way() -> void:
	var rows: Array = []
	for k in 16:
		rows.append({"key": 1000 + k * 37, "pose": "sit" if k % 3 else "stand"})
	var small := View.reaction_picks("ration", -1, 0.0, rows, 3)
	var big := View.reaction_picks("ration", -1, 1.0, rows, 3)
	assert_eq(small.size(), View.REACT_FEW)
	assert_eq(big.size(), View.REACT_MANY)
	var ways := {}
	for k in range(0, 400):
		ways[View.role_for("ration", -1, View.traits_of(k))] = true
	assert_gte(ways.size(), 3, "bad news is taken more than one way: %s" % [ways.keys()])
	assert_eq(View.role_for("memorial", 1, View.traits_of(5)), "grief", "a loss is taken quietly")
	assert_ne(View.reaction_picks("ration", -1, 0.5, rows, 3).keys(), View.reaction_picks("ration", -1, 0.5, rows, 4).keys(), "not the same few every day")
	for way in View.REACTIONS:
		for pose in View.REACTIONS[way]:
			var clip: String = View.REACTIONS[way][pose]
			assert_eq(String(View.POSTURE.get(clip, "stand")), pose, "%s %s" % [way, pose])


## One picked to react shows it over the everyday gestures (the cold hunch, a
## bowl, a chat), but not asleep or at a job.
func test_a_reaction_comes_before_the_everyday_gestures() -> void:
	var s := {"layout": "coach", "warmth": 60.0, "cold": false, "freezing": false, "exposure": 0.0, "night": false, "stove_x": 7.85, "ration": 70.0, "crowding": 40.0, "tension": 0.0, "fear": 0.0, "resent": false, "meal": false}
	var react := {"react": "t_sit_no"}
	for g in [Gesture.BOWL_SIT, Gesture.HUG_KNEES, ""]:
		var b: Node3D = add_child_autofree(Body.new())
		b.pose = "sit"
		b.gesture = g
		b.huddled = g == ""
		assert_eq(View.want_for(b, s, "", 3, 0.0, react), "t_sit_no", "over 「%s」" % g)
		assert_eq(View.want_for(b, s, "chat", 3, 0.0, react), "t_sit_no", "over a chat")
		assert_eq(View.want_for(b, s, "sleep", 3, 0.0, react), "t_lie", "not asleep")
		assert_eq(View.want_for(b, s, "work", 3, 0.0, react), "t_kneel_work", "not at a job")


## A trace stays: after a ration cut the car eats and murmurs more; after a memorial it is quiet.
func test_a_car_keeps_a_trace_for_days() -> void:
	var b: Node3D = add_child_autofree(Body.new())
	b.pose = "sit"
	var s := {"layout": "coach", "warmth": 60.0, "cold": false, "freezing": false, "exposure": 0.0, "night": false, "stove_x": 7.85, "ration": 70.0, "crowding": 40.0, "tension": 0.0, "fear": 0.0, "resent": false, "meal": false}
	var me := View.traits_of(9)
	var plain := View.weights_for("sit", b, s, me)
	var cut := View.weights_for("sit", b, s.merged({"marks": [{"kind": "ration", "sign": -1, "size": 0.5}]}), me)
	assert_gt(float(cut["t_eat"]), float(plain["t_eat"]))
	var quiet := View.weights_for("sit", b, s.merged({"marks": [{"kind": "memorial", "sign": -1, "size": 0.8}]}), me)
	assert_lt(float(quiet["t_sit_talk"]), float(plain["t_sit_talk"]))
	assert_gt(float(quiet["t_sit_huddle"]), float(plain["t_sit_huddle"]))
	for k in quiet:
		assert_gte(float(quiet[k]), 0.0)


## The whole way: a ration cut in the tail is found from the values, a few
## there react for a while and go back, and the car keeps its trace till the days are out.
func test_a_ration_cut_shows_in_the_tail() -> void:
	var s := _scene()
	var view = s.people_view
	if view == null:
		pass_test("no baked people here")
		return
	var before: float = float(s.rules["comms"]["tail"]["sit"][1])
	assert_true(s.set_sit("tail", 1, before - 20.0))
	assert_eq(_kinds(view.heard), ["ration"])
	assert_true(view.scenes.has("tail1"), "the tail reacts")
	var scene_rec: Dictionary = view.scenes["tail1"]
	assert_between((scene_rec["picks"] as Dictionary).size(), View.REACT_FEW, View.REACT_MANY)
	var picks: Dictionary = scene_rec["picks"]
	for i in 20:
		s.step(0.5)
		view._process(0.5)
	var showing := 0
	for b in picks:
		showing += int(String(view.drawn.get(b, "")) == String(picks[b]))
	assert_gt(showing, 0, "those who react are seen doing it")
	assert_eq(view._marks_of("tail1").size(), 1, "the car keeps the trace")
	s.clock = float(scene_rec["until"]) + 0.1
	view._process(0.1)
	assert_false(view.scenes.has("tail1"), "and the moment passes")
	s.rules["train"]["seg"] = int(s.rules["train"]["seg"]) + View.LINGER_DAYS
	assert_eq(view._marks_of("tail1").size(), 0, "the trace is gone after its days")


## The domestic rules' own events come in through the scene, the same way.
func test_posted_events_are_taken_in_the_same_way() -> void:
	var s := _scene([{"id": "workshop", "kind": "technical", "name": "공방"}])
	var view = s.people_view
	if view == null:
		pass_test("no baked people here")
		return
	s.post_event({"kind": "made", "car": "", "comm": "", "sign": 1, "size": 0.4, "day": 2})
	assert_eq(_kinds(view.heard), ["made"])
	assert_true(view.marks.has("workshop"))
	var bare := _scene()
	bare.post_event({"kind": "made", "car": "", "comm": "", "sign": 1, "size": 0.4, "day": 2})
	if bare.people_view != null:
		assert_eq(bare.people_view.scenes, {}, "no workshop car, no one to see it")
	s.post_event({"kind": "mod_done", "car": "tail1", "comm": "", "sign": 1, "size": 0.6, "day": 2})
	assert_true(view.scenes.has("tail1"))


## A screen built afresh shows no change of its own; given the values it last
## showed, it takes in what changed in between (the slice's next stop).
func test_a_new_screen_takes_in_what_changed_since_the_last() -> void:
	var fresh := _scene()
	if fresh.people_view == null:
		pass_test("no baked people here")
		return
	assert_eq(fresh.people_view.heard, [], "a new screen is not an event")
	var before := Rules.load_default()
	var s := Scene.new()
	s.rules = Rules.load_default()
	s.rules["comms"]["tail"]["sit"][1] = float(before["comms"]["tail"]["sit"][1]) - 20.0
	s.opts = {"seed": 7, "panel": false, "rules_before": before}
	add_child_autofree(s)
	assert_eq(_kinds(s.people_view.heard), ["ration"], "the cut since the last stop is seen")
	assert_true(s.people_view.scenes.has("tail1"))
