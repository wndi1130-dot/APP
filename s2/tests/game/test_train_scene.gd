extends "res://addons/gut/test.gd"
## The train scene shows the rule values it is given: head counts, huddling and
## floor sleepers follow the numbers, each car takes on the mood the look picks
## (who stands about, where they sit, the lamp, the stove, the frost), and the
## walkers stay inside the car, the train and the one-at-a-time limit while a
## few take trips and come home.

const Scene = preload("res://game/train/train_scene.gd")
const Rules = preload("res://game/train/train_rules.gd")
const Look = preload("res://game/train/train_look.gd")
const Body = preload("res://game/train/train_body.gd")
const HandPanel = preload("res://game/train/train_panel.gd")
const Boot = preload("res://game/boot.gd")


func _scene(panel: bool = false) -> Node3D:
	var s := Scene.new()
	s.rules = Rules.load_default()
	s.opts = {"seed": 7, "panel": panel}
	add_child_autofree(s)
	return s


## The scene in session, with no trips so only the council's own people are in the room.
func _council() -> Node3D:
	var s = _scene()
	s.rules["errands"] = []
	s.set_train("phase", "council")
	return s


## The seated of the council who are on their feet now.
func _up(s) -> int:
	var n := 0
	for b in s.car("dining")["bodies"]:
		n += 1 if int(b.seat) >= 0 and b.pose == "stand" else 0
	return n


func _leaning(s) -> int:
	var n := 0
	for b in s.car("dining")["bodies"]:
		n += 1 if float(b.side) != 0.0 else 0
	return n


## Where everyone of the council is and what they are doing, a row a person.
func _seats_of(s) -> Array:
	var rows: Array = []
	for b in s.car("dining")["bodies"]:
		rows.append([b.slot, b.state, b.pose, b.side, b.seat, b.act, b.bowed])
	return rows


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


## The bodies of a car that keep a place: seated, on the floor or standing about.
func _placed(s, id: String) -> Array:
	var rows: Array = []
	for b in s.car(id)["bodies"]:
		if b.state == "seat":
			rows.append(b)
	return rows


func _standing_about(s, id: String) -> int:
	var n := 0
	for b in _placed(s, id):
		n += 1 if b.pose == "stand" else 0
	return n


## How far along the car its seated people reach, first to last.
func _seated_span(s, id: String) -> float:
	var low: float = INF
	var high: float = -INF
	for b in _placed(s, id):
		low = minf(low, b.slot.x)
		high = maxf(high, b.slot.x)
	return high - low


## The closest two of a car's placed bodies stand this far apart.
func _closest(s, id: String) -> float:
	var rows := _placed(s, id)
	var best: float = INF
	for i in rows.size():
		for j in range(i + 1, rows.size()):
			best = minf(best, (rows[i].slot as Vector3).distance_to(rows[j].slot))
	return best


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


## The bodies of the whole train that are out on a call at a friendly car.
func _callers(s) -> Array:
	var rows: Array = []
	for c in s.cars:
		for b in c["bodies"]:
			if (b.state == "out" or b.state == "visit" or b.state == "back") and String(b.errand.get("id", "")) == "call":
				rows.append(b)
	return rows


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
	var expected: int = int(Look.split(_count(s, "tail1"), 10.0, 75.0, s.car("tail1")["mood"])["huddled"])
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


func test_the_dining_car_holds_the_council_in_session_and_four_otherwise() -> void:
	var s = _scene()
	assert_eq(_count(s, "dining"), 4)
	s.set_train("phase", "council")
	assert_eq(_count(s, "dining"), 32)
	s.set_train("phase", "travel")
	assert_eq(_count(s, "dining"), 4)


func test_no_two_placed_bodies_share_a_place_in_any_mood() -> void:
	var s = _scene()
	s.set_sit("tail", 2, 100.0)
	# [tension, fear, the tail's warmth]: low and gathered, calm and spread, stirred with knots, frozen.
	for row in [[20.0, 0.0, 35.0], [20.0, 0.0, 60.0], [70.0, 0.0, 60.0], [20.0, 70.0, 60.0]]:
		s.rules["comms"]["tail"]["sit"][1] = 60.0 if float(row[2]) >= 45.0 else 40.0
		s.rules["train"]["tension"] = row[0]
		s.rules["train"]["fear"] = row[1]
		s.set_sit("tail", 0, row[2])
		var mood: String = s.car("tail1")["mood"]
		var split: Dictionary = Look.split(16, float(row[2]), 100.0, mood)
		assert_eq(_placed(s, "tail1").size(), 16 - int(split["walk"]), mood)
		assert_gt(_closest(s, "tail1"), Body.RADIUS * 1.5, "%s: nobody sits or stands inside another" % mood)


func test_the_line_over_a_car_reads_its_numbers_heads_and_mood() -> void:
	var s = _scene()
	s.set_sit("tail", 0, 10.0)
	var line: String = s.car("tail1")["values"].text
	assert_string_contains(line, "온기 10")
	assert_string_contains(line, "16명")
	assert_string_contains(line, "가라앉음")
	assert_eq(String(s.car("dining")["values"].text), "4명 · 평온")


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


# ---------------------------------------------------------------- the mood of a car

func test_each_car_takes_the_mood_the_look_picks_and_names_it() -> void:
	var s = _scene()
	assert_eq(s.car("tail1")["mood"], "low")
	assert_eq(s.car("medtech")["mood"], "calm")
	s.set_train("tension", 70.0)
	for c in s.cars:
		assert_eq(c["mood"], "stir", String(c["id"]))
		assert_string_contains(String(c["values"].text), "술렁임")
	s.set_train("fear", 70.0)
	for c in s.cars:
		assert_eq(c["mood"], "frozen", String(c["id"]))
		assert_string_contains(String(c["values"].text), "얼어붙음")
	s.set_train("fear", 0.0)
	s.set_train("tension", 20.0)
	assert_eq(s.car("tail1")["mood"], "low")
	assert_eq(s.car("front")["mood"], "calm")
	s.set_comm("front", "rel", -40)
	assert_eq(s.car("front")["mood"], "stir", "its own car only")
	assert_eq(s.car("medtech")["mood"], "calm")


func test_a_stirred_car_stands_about_in_knots_and_walks_faster() -> void:
	var s = _scene()
	assert_eq(_standing_about(s, "medtech"), 0)
	s.set_train("tension", 70.0)
	var split: Dictionary = Look.split(_count(s, "medtech"), 55.0, 45.0, "stir")
	assert_eq(_standing_about(s, "medtech"), int(split["stand"]))
	assert_gt(_standing_about(s, "medtech"), 0)
	var walkers := 0
	for b in s.car("medtech")["bodies"]:
		assert_almost_eq(float(b.speed), Body.WALK_SPEED * 1.4, 0.001)
		walkers += 1 if b.state != "seat" else 0
	assert_eq(walkers, int(split["walk"]))
	s.set_train("tension", 20.0)
	assert_eq(_standing_about(s, "medtech"), 0, "calm again: everyone who stood about sits")
	for b in s.car("medtech")["bodies"]:
		assert_almost_eq(float(b.speed), Body.WALK_SPEED, 0.001)


func test_a_frightened_car_bows_its_seated_heads_and_a_calm_one_does_not() -> void:
	var s = _scene()
	s.set_train("fear", 70.0)
	for b in s.car("medtech")["bodies"]:
		assert_eq(bool(b.bowed), b.state == "seat", "the seated bow, the one who walks does not")
	assert_eq(_placed(s, "medtech").size(), _count(s, "medtech") - Look.movers(_count(s, "medtech"), "frozen"))
	s.set_train("fear", 0.0)
	for b in s.car("medtech")["bodies"]:
		assert_false(bool(b.bowed))


func test_a_low_car_draws_in_round_the_stove_and_fewer_walk() -> void:
	var s = _scene()
	var calm_span := _seated_span(s, "front")
	var calm_walkers: int = _count(s, "front") - _placed(s, "front").size()
	s.set_sit("front", 1, 40.0)
	assert_eq(s.car("front")["mood"], "low")
	assert_lt(_seated_span(s, "front"), calm_span, "the seated sit closer together")
	assert_lt(_count(s, "front") - _placed(s, "front").size(), calm_walkers)
	var stove_x: float = float(s.car("front")["x0"]) + Scene.STOVE_AT.x
	var nearest: float = INF
	for b in _placed(s, "front"):
		nearest = minf(nearest, absf(b.slot.x - stove_x))
	assert_lt(nearest, Scene.SLOT_STEP, "someone sits by the stove")


func test_the_lamp_eases_to_the_moods_light_and_sways_within_its_reach() -> void:
	var s = _scene()
	var c: Dictionary = s.car("medtech")
	var lamp: OmniLight3D = c["lamp"]
	var calm: Dictionary = Look.mood_look("calm")
	var frozen: Dictionary = Look.mood_look("frozen")
	s.set_train("fear", 70.0)
	assert_almost_eq(lamp.light_energy, float(calm["energy"]), 0.001, "not at once")
	for i in 100:
		s.step(0.1)
		assert_lte(absf(lamp.position.x - Scene.CAR_LENGTH * 0.5), Scene.LAMP_SWAY * float(frozen["sway"]) + 0.001)
	assert_almost_eq(lamp.light_energy, float(frozen["energy"]), 0.01)
	assert_almost_eq(lamp.light_color.b, (frozen["lamp"] as Color).b, 0.01, "a colder light")
	assert_lt(lamp.light_color.r, (calm["lamp"] as Color).r)


func test_the_stove_burns_with_the_cars_warmth_and_frost_takes_the_glass() -> void:
	var s = _scene()
	var c: Dictionary = s.car("front")
	s.set_sit("front", 0, 90.0)
	assert_almost_eq(float(c["stove_light"].light_energy), Scene.STOVE_ENERGY, 0.001)
	assert_true(bool(c["steam"].emitting), "a warm stove steams faintly")
	assert_almost_eq(float(c["glass"].get_shader_parameter("cold_car")), 0.0, 0.001)
	s.set_sit("front", 0, 10.0)
	assert_almost_eq(float(c["stove_light"].light_energy), 0.0, 0.001)
	assert_false(bool(c["steam"].emitting), "a dead stove does not")
	assert_almost_eq(float(c["glass"].get_shader_parameter("cold_car")), 1.0, 0.001)
	assert_true(s.car("dining").has("stove_light"), "the dining car has a stove of its own")
	assert_almost_eq(float(s.car("tail1")["glass"].get_shader_parameter("cold_car")), Look.frost(35.0), 0.001)


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
	s.rules.erase("calls")
	# A low car walks at 0.6: two cars there and back with a stay is two and a half minutes.
	for i in 2500:
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


# ---------------------------------------------------------------- calls between friendly cars

func test_friendly_cars_call_on_each_other_and_the_tail_calls_on_nobody() -> void:
	var s = _scene()
	s.rules["errands"] = []
	var called: Dictionary = {}
	var bad: Array = []
	for i in 1500:
		s.step(0.1)
		for b in _callers(s):
			called[String(b.visit_car)] = true
			if b.state != "visit":
				continue
			var x0: float = s.car(String(b.visit_car))["x0"]
			var from_door: float = minf(absf(b.position.x - x0), absf(b.position.x - x0 - Scene.CAR_LENGTH))
			if absf(from_door - Scene.CALL_INSIDE) > 0.05 or not is_equal_approx(b.position.z, Scene.AISLE_Z):
				bad.append("a caller stands at %s" % b.position)
		if int(s.car("tail1")["out"]) != 0:
			bad.append("the tail sent someone")
	assert_true(called.has("front") or called.has("medtech"), "the infirmary and the front car are on calling terms")
	assert_eq(called.keys().filter(func(id) -> bool: return id != "front" and id != "medtech"), [], "nobody calls anywhere else")
	assert_eq(bad.slice(0, 3), [], "a caller stops just inside the doorway, on the aisle")


func test_someone_of_the_car_comes_over_to_a_caller() -> void:
	var s = _scene()
	var caller = s.car("medtech")["bodies"][0]
	var host: Dictionary = s.car("front")
	caller.visit_car = "front"
	caller.position.x = float(host["x0"]) + Scene.CALL_INSIDE
	assert_true(s._greet(caller))
	var came := 0
	for h in host["bodies"]:
		if h.state == "pace":
			came += 1
			assert_almost_eq(float(h.goal_x), caller.position.x + Scene.CALL_APART, 0.001, "beside the caller, further in")
	assert_eq(came, 1, "one comes over, the others stay as they were")
	for h in host["bodies"]:
		if h.state == "wait":
			h.state = "pace"
	assert_false(s._greet(caller), "with everyone walking the caller waits for the first who is free")


func test_nobody_calls_in_a_frightened_train_during_the_session_or_without_the_rule() -> void:
	for setting in [["fear", 70.0], ["phase", "council"], ["", null]]:
		var s = _scene()
		s.rules["errands"] = []
		if String(setting[0]) == "":
			s.rules.erase("calls")
		else:
			s.set_train(setting[0], setting[1])
		var out := 0
		for i in 1200:
			s.step(0.1)
			for c in s.cars:
				out += int(c["out"])
		assert_eq(out, 0, "nobody left a car: %s" % str(setting[0]))


# ---------------------------------------------------------------- the council

func test_the_council_seats_both_sides_of_the_table_and_nobody_inside_another() -> void:
	var s = _council()
	var seated := 0
	var standing := 0
	for b in _placed(s, "dining"):
		seated += 1 if b.pose == "sit" else 0
		standing += 1 if b.pose == "stand" else 0
	assert_eq(seated, Look.COUNCIL_BENCH + Look.COUNCIL_TABLE)
	assert_eq(standing, 4, "the chair, the clerk and two by the door")
	assert_eq(_count(s, "dining") - _placed(s, "dining").size(), 2, "two walk the aisle")
	assert_gt(_closest(s, "dining"), Body.RADIUS * 1.5)
	assert_eq(_up(s), 0, "at first everyone seated sits")


func test_the_line_over_the_council_names_its_step_of_unrest() -> void:
	var s = _council()
	assert_eq(String(s.car("dining")["values"].text), "32명 · 소란 1 웅성")
	s.set_train("tension", 85.0)
	assert_string_contains(String(s.car("dining")["values"].text), "소란 4 개판")
	s.set_train("tension", 76.0)
	assert_string_contains(String(s.car("dining")["values"].text), "소란 4 개판", "five under the threshold holds")
	s.set_train("tension", 74.0)
	assert_string_contains(String(s.car("dining")["values"].text), "소란 3 고함·야유")
	s.set_train("phase", "travel")
	assert_string_contains(String(s.car("dining")["values"].text), "4명")
	s.set_train("tension", 76.0)
	s.set_train("phase", "council")
	assert_string_contains(String(s.car("dining")["values"].text), "소란 3", "a new session starts from the score, with nothing to hold")


func test_a_communitys_own_numbers_move_no_seat_in_the_council() -> void:
	var s = _council()
	for i in 200:
		s.step(0.1)
	assert_gt(_leaning(s), 0, "the room is in the middle of its gestures")
	var before: Array = _seats_of(s)
	s.set_comm("tail", "rel", -80)
	s.set_comm("tail", "grudge", 2)
	s.set_sit("front", 0, 5.0)
	assert_string_contains(String(s.car("dining")["values"].text), "소란 2 언쟁", "only the step changes: 20 + 10 + 15")
	assert_eq(_seats_of(s), before, "nobody moved, rose or leaned because of one community")


func test_nobody_rises_while_the_council_whispers_and_some_do_when_it_shouts() -> void:
	var s = _council()
	s.set_train("tension", 0.0)
	var up := 0
	var leaning := 0
	for i in 400:
		s.step(0.1)
		up = maxi(up, _up(s))
		leaning = maxi(leaning, _leaning(s))
	assert_eq(up, 0, "step 0: seated, heads together")
	assert_between(leaning, 1, int(Look.UNREST_LOOK[0]["act"]))
	s.set_train("tension", 90.0)
	var strays: Array = []
	for i in 400:
		s.step(0.1)
		up = maxi(up, _up(s))
		strays.append_array(_stray(s, Scene.OUT_IN_SESSION))
	assert_between(up, 1, int(Look.UNREST_LOOK[4]["rise"]), "step 4: several on their feet, never more than the look allows")
	assert_eq(strays.slice(0, 3), [], "those who rise stay at their seats")


func test_when_the_vote_is_called_everyone_sits_still_and_nobody_moves() -> void:
	var s = _council()
	s.set_train("tension", 90.0)
	for i in 300:
		s.step(0.1)
	s.set_train("voting", true)
	assert_string_contains(String(s.car("dining")["values"].text), "표결")
	assert_eq(_up(s), 0, "at once")
	assert_eq(_leaning(s), 0)
	var x0: float = s.car("dining")["x0"]
	var before: Dictionary = {}
	for c in s.cars:
		for b in c["bodies"]:
			if b.position.x >= x0 and b.position.x <= x0 + Scene.CAR_LENGTH:
				before[b] = b.position
	assert_gte(before.size(), 32)
	for i in 200:
		s.step(0.1)
	for b in before:
		assert_eq(b.position, before[b], "nobody in the room moves")
	assert_eq(_up(s), 0)
	s.set_train("voting", false)
	var up := 0
	for i in 200:
		s.step(0.1)
		up = maxi(up, _up(s))
	assert_gt(up, 0, "the room takes up again when the vote is done")


func test_a_frightened_council_bows_its_heads_whatever_the_unrest() -> void:
	var s = _council()
	s.set_train("tension", 90.0)
	s.set_train("fear", 70.0)
	assert_string_contains(String(s.car("dining")["values"].text), "무서운 조용함")
	assert_eq(_placed(s, "dining").size(), 32, "those who walked stand still")
	var up := 0
	for i in 300:
		s.step(0.1)
		up = maxi(up, _up(s))
	assert_eq(up, 0)
	for b in s.car("dining")["bodies"]:
		assert_true(bool(b.bowed))
	s.set_train("fear", 0.0)
	for b in s.car("dining")["bodies"]:
		assert_false(bool(b.bowed))
	assert_eq(_count(s, "dining") - _placed(s, "dining").size(), 2, "and two walk again")


func test_after_the_session_nobody_in_the_dining_car_keeps_a_council_gesture() -> void:
	var s = _council()
	s.set_train("tension", 90.0)
	for i in 300:
		s.step(0.1)
	s.set_train("phase", "travel")
	for b in s.car("dining")["bodies"]:
		assert_eq(int(b.seat), -1)
		assert_eq(String(b.act), "")
		assert_eq(float(b.side), 0.0)


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


func test_the_start_menu_has_a_way_into_the_train_and_the_panel_a_way_back() -> void:
	var boot = Boot.new()
	add_child_autofree(boot)
	assert_not_null(boot.find_child("TrainButton", true, false))
	assert_true(ResourceLoader.exists(Boot.TRAIN_SCENE), Boot.TRAIN_SCENE)
	assert_true(ResourceLoader.exists(HandPanel.BOOT_SCENE), HandPanel.BOOT_SCENE)


func test_the_dining_car_has_no_warmth_to_set() -> void:
	var s = _scene(true)
	s.panel.pick(2)
	assert_eq(s.panel.comm_id(), "")
	assert_false(s.panel.sliders["sit0"].editable)
