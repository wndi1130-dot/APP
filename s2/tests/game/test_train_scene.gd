extends "res://addons/gut/test.gd"
## The train scene shows the rule values it is given: head counts, huddling and
## floor sleepers follow the numbers, and the walkers stay inside the car, the
## train and the one-at-a-time limit while a few take trips and come home.

const Scene = preload("res://game/train/train_scene.gd")
const Rules = preload("res://game/train/train_rules.gd")
const Look = preload("res://game/train/train_look.gd")
const Body = preload("res://game/train/train_body.gd")


func _scene(panel: bool = false) -> Node3D:
	var s := Scene.new()
	s.rules = Rules.load_default()
	s.opts = {"seed": 7, "panel": panel}
	add_child_autofree(s)
	return s


func _count(s, id: String) -> int:
	return (s.car(id)["bodies"] as Array).size()


func _huddled(s, id: String) -> int:
	var n := 0
	for b in s.car(id)["bodies"]:
		n += 1 if b.huddled else 0
	return n


func _on_floor(s, id: String) -> int:
	var n := 0
	for b in s.car(id)["bodies"]:
		n += 1 if b.pose == "floor" else 0
	return n


## One tick's worth of what must never be seen; empty when all is well.
func _stray(s, limit: int) -> Array:
	var bad: Array = []
	var half: float = Scene.CAR_WIDTH / 2.0
	var length: float = s.train_length()
	for c in s.cars:
		if int(c["out"]) > limit or int(c["out"]) < 0:
			bad.append("%s: %d out" % [c["id"], int(c["out"])])
		for b in c["bodies"]:
			var at: Vector3 = b.position
			if absf(at.z) > half:
				bad.append("%s: z %s" % [c["id"], at.z])
			if at.x < 0.0 or at.x > length:
				bad.append("%s: x %s" % [c["id"], at.x])
			if b.state == "seat" and not at.is_equal_approx(b.slot):
				bad.append("%s: a seated body left its place" % c["id"])
	return bad


func _tripping(s) -> bool:
	for c in s.cars:
		for b in c["bodies"]:
			if (b.state == "out" or b.state == "visit") and String(b.visit_car) != "":
				return true
	return false


# ---------------------------------------------------------------- head counts and postures

func test_every_car_holds_as_many_bodies_as_the_look_says() -> void:
	var s = _scene()
	assert_eq(s.cars.size(), 5)
	for c in s.cars:
		var comm: Dictionary = Rules.comm_of(s.rules, c["def"])
		assert_eq(_count(s, c["id"]), Look.figures(c["def"], comm, s.phase()), String(c["id"]))
	assert_eq(_count(s, "tail1"), 16)
	assert_eq(_count(s, "medtech"), 13)
	assert_eq(_count(s, "front"), 10)


func test_a_cold_tail_huddles_as_the_split_says_and_a_warm_one_does_not() -> void:
	var s = _scene()
	s.set_sit("tail", 0, 10.0)
	var expected: int = int(Look.split(_count(s, "tail1"), 10.0, 75.0)["huddled"])
	assert_eq(_huddled(s, "tail1"), expected)
	assert_gt(_huddled(s, "tail1"), 0)
	s.set_sit("tail", 0, 80.0)
	assert_eq(_huddled(s, "tail1"), 0)


func test_a_crowded_front_gains_bodies_and_floor_sleepers_and_loses_them_again() -> void:
	var s = _scene()
	var before := _count(s, "front")
	assert_eq(_on_floor(s, "front"), 0)
	s.set_sit("front", 2, 100.0)
	assert_gt(_count(s, "front"), before)
	assert_gt(_on_floor(s, "front"), 0)
	var crowded := _count(s, "front")
	s.set_sit("front", 2, 20.0)
	assert_lt(_count(s, "front"), crowded)
	assert_eq(_on_floor(s, "front"), 0)
	assert_gte(int(s.car("front")["out"]), 0)


func test_the_dining_car_holds_twelve_in_session_and_four_otherwise() -> void:
	var s = _scene()
	assert_eq(_count(s, "dining"), 4)
	s.set_train("phase", "council")
	assert_eq(_count(s, "dining"), 12)
	s.set_train("phase", "travel")
	assert_eq(_count(s, "dining"), 4)


func test_no_two_seated_bodies_share_a_place() -> void:
	var s = _scene()
	s.set_sit("tail", 2, 100.0)
	var places: Dictionary = {}
	for b in s.car("tail1")["bodies"]:
		if b.state == "seat":
			places[b.slot] = true
	assert_eq(places.size(), 12, "sixteen people: four walk, twelve sit apart")


func test_the_line_over_a_car_reads_its_numbers_and_heads() -> void:
	var s = _scene()
	s.set_sit("tail", 0, 10.0)
	var line: String = s.car("tail1")["values"].text
	assert_string_contains(line, "온기 10")
	assert_string_contains(line, "16명")
	assert_eq(String(s.car("dining")["values"].text), "4명")


func test_a_seated_body_is_lower_than_a_standing_one_and_a_huddled_one_lower_still() -> void:
	var stand: Dictionary = Body.pose_at("stand", false)
	var sit: Dictionary = Body.pose_at("sit", false)
	var hunched: Dictionary = Body.pose_at("sit", true)
	assert_lt(float(sit["head_pos"].y), float(stand["head_pos"].y))
	assert_lt(float(hunched["head_pos"].y), float(sit["head_pos"].y))
	assert_gt(float(hunched["body_lean"]), 0.0)
	assert_eq(float(Body.pose_at("walk", true)["body_lean"]), 0.0, "nobody walks hunched")


func test_the_doorway_between_cars_is_on_the_aisle_and_taller_than_a_person() -> void:
	assert_between(Scene.AISLE_Z, Scene.DOOR_FROM + Body.RADIUS, Scene.DOOR_TO - Body.RADIUS)
	assert_gt(Scene.DOOR_HEIGHT, Body.HEIGHT + Body.HEAD_RADIUS * 2.0)


# ---------------------------------------------------------------- time passing

func test_while_time_passes_bodies_stay_in_the_car_and_the_train() -> void:
	var s = _scene()
	var bad: Array = []
	var tripped := false
	for i in 600:
		s.step(0.1)
		bad.append_array(_stray(s, Scene.OUT_AT_ONCE))
		tripped = tripped or _tripping(s)
	assert_eq(bad.slice(0, 3), [], "z within the car, x within the train, seated stay seated, one out at a time")
	assert_true(tripped, "someone walks to another car in a minute")


func test_when_no_new_trips_start_everyone_comes_home() -> void:
	var s = _scene()
	for i in 600:
		s.step(0.1)
	s.rules["errands"] = []
	for i in 1500:
		s.step(0.1)
	var strays: Array = []
	for c in s.cars:
		assert_eq(int(c["out"]), 0, String(c["id"]))
		var x0: float = c["x0"]
		for b in c["bodies"]:
			var x: float = b.position.x
			if b.state != "seat" and (x < x0 or x > x0 + Scene.CAR_LENGTH):
				strays.append("%s: x %s" % [c["id"], x])
	assert_eq(strays.slice(0, 3), [], "walkers are back in their own car")


# ---------------------------------------------------------------- bad rules

func test_broken_rules_show_problems_and_no_cars_and_do_not_stop_the_scene() -> void:
	var s = Scene.new()
	s.rules = {"train": {}}
	s.opts = {"seed": 7, "panel": false}
	add_child_autofree(s)
	assert_false(s.problems.is_empty())
	assert_true(s.cars.is_empty())
	s.step(0.1)
	assert_true(s.cars.is_empty())
	assert_true(s.is_inside_tree())


# ---------------------------------------------------------------- the hand panel

func test_the_panel_picks_a_car_and_its_slider_sets_that_communitys_warmth() -> void:
	var s = _scene(true)
	assert_not_null(s.panel)
	s.panel.pick(1)
	assert_eq(s.panel.title.text, String(s.rules["cars"][1]["name"]))
	s.panel.sliders["sit0"].value = 10
	assert_almost_eq(float(s.rules["comms"]["medtech"]["sit"][0]), 10.0, 0.001)


func test_the_dining_car_has_no_warmth_to_set() -> void:
	var s = _scene(true)
	s.panel.pick(2)
	assert_eq(s.panel.comm_id(), "")
	assert_false(s.panel.sliders["sit0"].editable)
