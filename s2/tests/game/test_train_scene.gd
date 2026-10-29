extends "res://addons/gut/test.gd"
## The train scene shows the rule values it is given: head counts, huddling and
## floor sleepers follow the numbers, each car takes on the mood the look picks
## (who stands about, where they sit, the lamp, the stove, the frost), and the
## walkers stay inside the car, the train and the one-at-a-time limit while a
## few take trips and come home.

const Scene = preload("res://game/train/train_scene.gd")
const Rules = preload("res://game/train/train_rules.gd")
const Gesture = preload("res://game/train/train_gesture.gd")
const Look = preload("res://game/train/train_look.gd")
const TrainLight = preload("res://game/train/train_light.gd")
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
	assert_eq(s.cars.size(), 13, "S1's formation (결정 카드 Q2 나): three tail cars to the engine and its locomotive")
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
	# The mood's light over the car's light board (train_light.gd target): its stage and hour.
	var stage: int = TrainLight.stage_of(c)
	var daytime: String = TrainLight.daytime_of(s.rules.get("view", {}))
	var calm: Dictionary = TrainLight.target(stage, daytime, Look.mood_look("calm"))
	var frozen: Dictionary = TrainLight.target(stage, daytime, Look.mood_look("frozen"))
	s.set_train("fear", 70.0)
	assert_almost_eq(lamp.light_energy, float(calm["lamp_energy"]), 0.001, "not at once")
	for i in 100:
		s.step(0.1)
		assert_lte(absf(lamp.position.x - Scene.CAR_LENGTH * 0.5), Scene.LAMP_SWAY * float(frozen["lamp_sway"]) + 0.001)
	assert_almost_eq(lamp.light_energy, float(frozen["lamp_energy"]), 0.01)
	assert_almost_eq(lamp.light_color.b, (frozen["lamp_color"] as Color).b, 0.01, "a colder light")
	assert_lt(lamp.light_color.r, (calm["lamp_color"] as Color).r)


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
	# The cold car is kept cold on purpose: its glass frosts whatever warmth the rules give it.
	assert_almost_eq(float(s.car("cold")["glass"].get_shader_parameter("cold_car")), 1.0, 0.001)


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
	# A low car walks at 0.6: two cars there and back with a stay is two and a half
	# minutes; from the last tail car to the dining car and back is the longest walk.
	for i in 9000:
		s.step(0.1)
		if i >= 2500 and i % 100 == 0 and s.cars.all(func(c): return int(c["out"]) == 0):
			break
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
			# Its own place at the door, or the second of the door's pair when one of the
			# car already waits there for someone to talk to.
			var off: float = minf(absf(from_door - Scene.CALL_INSIDE), absf(from_door - Scene.CALL_INSIDE - Scene.CALL_APART))
			if off > 0.05 or not is_equal_approx(b.position.z, Scene.AISLE_Z):
				bad.append("a caller stands at %s" % b.position)
		for tail in ["tail1", "tail2", "tail3"]:
			if int(s.car(tail)["out"]) != 0:
				bad.append("the tail sent someone")
	assert_true(called.has("front") or called.has("medtech"), "the infirmary and the front car are on calling terms")
	# S1's formation has the guard's and the engine's cars too, and their ideas are close.
	var friends: Array = ["front", "medtech", "guard", "engine"]
	assert_eq(called.keys().filter(func(id) -> bool: return not friends.has(id)), [], "nobody calls anywhere else")
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
	for i in 600:
		s.step(0.1)
		if i >= 200 and _leaning(s) > 0:
			break
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
	var medtech: int = (s.rules["cars"] as Array).map(func(c): return String(c["id"])).find("medtech")
	s.panel.pick(medtech)
	assert_eq(s.panel.title.text, String(s.rules["cars"][medtech]["name"]))
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
	s.panel.pick((s.rules["cars"] as Array).map(func(c): return String(c["id"])).find("dining"))
	assert_eq(s.panel.comm_id(), "")
	assert_false(s.panel.sliders["sit0"].editable)


# ---------------------------------------------------------------- the captain's board

## Turn the board's views until the one at `at` shows (CAPTAIN_SHOWS, in turn).
func _show_captain_at(s, at: String) -> void:
	for i in HandPanel.CAPTAIN_SHOWS.size():
		if HandPanel.CAPTAIN_SHOWS[i]["at"] == at:
			while s.panel.captain_i != i + 1:
				s.panel.next_captain()
			return


func test_the_panel_has_a_captain_board_that_starts_hidden_and_flips() -> void:
	var s = _scene(true)
	assert_not_null(s.panel.captain_board)
	assert_false(s.panel.captain_board.visible)
	s.panel._flip_captain()
	assert_true(s.panel.captain_board.visible)
	s.panel._flip_captain()
	assert_false(s.panel.captain_board.visible)


func test_the_board_first_shows_the_rules_captain() -> void:
	var s = _scene(true)
	assert_eq(s.panel.captain_board.line_label.text, "열차장실 · 멀쩡함")


func test_every_captain_to_look_at_passes_the_rules_check() -> void:
	for show in HandPanel.CAPTAIN_SHOWS:
		var d := Rules.load_default()
		d["captain"] = (show as Dictionary).duplicate(true)
		assert_eq(Rules.check(d), PackedStringArray(), str(show["at"]))


func test_the_next_captain_goes_into_the_rules_and_the_line_changes() -> void:
	var s = _scene(true)
	var before: String = s.panel.captain_board.line_label.text
	s.panel.next_captain()
	assert_eq(s.rules["captain"], HandPanel.CAPTAIN_SHOWS[0])
	assert_ne(s.panel.captain_board.line_label.text, before)


func test_after_a_round_the_rules_own_captain_is_back() -> void:
	var s = _scene(true)
	var own = s.rules["captain"]
	for i in HandPanel.CAPTAIN_SHOWS.size() + 1:
		s.panel.next_captain()
	assert_eq(s.rules["captain"], own)
	assert_eq(s.panel.captain_i, 0)


func test_a_captain_who_is_out_reads_so_on_the_line() -> void:
	var s = _scene(true)
	_show_captain_at(s, "out")
	assert_eq(s.panel.captain_board.line_label.text, "밖에 나감 · 멀쩡함")


func test_changing_the_captain_leaves_the_people_of_the_cars_as_they_are() -> void:
	var s = _scene(true)
	var in_captain: int = s.car("captain")["bodies"].size()
	var in_medtech: int = s.car("medtech")["bodies"].size()
	s.panel.next_captain()
	assert_eq(s.car("captain")["bodies"].size(), in_captain)
	assert_eq(s.car("medtech")["bodies"].size(), in_medtech)


func test_rules_without_a_captain_have_none_again_after_a_round() -> void:
	var s := Scene.new()
	s.rules = Rules.load_default()
	s.rules.erase("captain")
	s.opts = {"seed": 7, "panel": true}
	add_child_autofree(s)
	for i in HandPanel.CAPTAIN_SHOWS.size() + 1:
		s.panel.next_captain()
	assert_false(s.rules.has("captain"))


# ---------------------------------------------------------------- the gestures of a tense train

## The people of a car who are in a gesture.
func _gesturing(s, car_id: String) -> Array:
	var rows: Array = []
	for b in s.car(car_id)["bodies"]:
		if b.gesture != "":
			rows.append(b)
	return rows


func _gesturing_anywhere(s) -> int:
	var n := 0
	for c in s.cars:
		n += _gesturing(s, String(c["id"])).size()
	return n


## Those in a gesture other than the cold's: in a cold car (the tail, as the
## rules come) those who walk rub their hands between walks whatever else goes on.
func _gesturing_but_cold(s, car_id: String) -> Array:
	return _gesturing(s, car_id).filter(func(b) -> bool: return b.gesture != Gesture.RUB_STAMP)


func _gesturing_anywhere_but_cold(s) -> int:
	var n := 0
	for c in s.cars:
		n += _gesturing_but_cold(s, String(c["id"])).size()
	return n


func test_a_tense_tails_first_knot_gestures_and_only_those_standing_still() -> void:
	var s = _scene()
	assert_eq(_gesturing_but_cold(s, "tail1").size(), 0)
	s.set_train("tension", 70.0)
	var rows := _gesturing(s, "tail1")
	assert_eq(rows.size(), 3)
	for b in rows:
		assert_eq(b.pose, "stand")
		assert_eq(b.state, "seat")
	for b in s.car("tail1")["bodies"]:
		if b.state != "seat":
			assert_eq(b.gesture, "", "a walker does not gesture")


func test_two_quarrel_a_quarrel_apart_and_the_third_looks_about() -> void:
	var s = _scene()
	s.set_train("tension", 70.0)
	var rows := _gesturing(s, "tail1")
	var pair := rows.filter(func(b) -> bool: return b.gesture == Gesture.ARGUE)
	var about := rows.filter(func(b) -> bool: return b.gesture == Gesture.TURN_ABOUT)
	assert_eq(pair.size(), 2)
	assert_eq(about.size(), 1)
	assert_eq(pair[0].gesture_role, 0)
	assert_eq(pair[1].gesture_role, 1)
	assert_lt(pair[0].position.x, pair[1].position.x)
	assert_almost_eq(pair[1].position.x - pair[0].position.x, float(Gesture.PAIR_GAP[Gesture.ARGUE]), 0.01)


func test_those_who_quarrel_face_each_other() -> void:
	var s = _scene()
	s.set_train("tension", 70.0)
	s.step(0.1)
	var pair := _gesturing(s, "tail1").filter(func(b) -> bool: return b.gesture == Gesture.ARGUE)
	assert_eq(pair.size(), 2)
	assert_eq(pair[0].gesture_role, 0)
	assert_almost_eq(float(pair[0].rotation.y), PI * 0.5, 0.01)
	assert_almost_eq(float(pair[1].rotation.y), -PI * 0.5, 0.01)


func test_the_infirmary_whispers_with_its_heads_closer() -> void:
	var s = _scene()
	s.set_train("tension", 70.0)
	var pair := _gesturing(s, "medtech").filter(func(b) -> bool: return b.gesture == Gesture.WHISPER)
	assert_eq(pair.size(), 2)
	assert_eq(pair[0].gesture_role, 0)
	assert_eq(pair[1].gesture_role, 1)
	assert_almost_eq(pair[1].position.x - pair[0].position.x, float(Gesture.PAIR_GAP[Gesture.WHISPER]), 0.01)
	assert_almost_eq(float(pair[0].gesture_facing), PI * 0.5, 0.001)
	assert_almost_eq(float(pair[1].gesture_facing), -PI * 0.5, 0.001)


func test_only_argue_supplies_the_knot_pairs_base_turn() -> void:
	var s = _scene()
	for member in 2:
		assert_eq(s._knot_gesture_facing(Gesture.ARGUE, member), 0.0)
		var expected: float = PI * 0.5 if member == 0 else -PI * 0.5
		for gesture_name in ["", Gesture.WHISPER, Gesture.ARMS_CROSSED, "warm_hands_stand", "shove_body", "grab_collar", "help_up"]:
			assert_almost_eq(s._knot_gesture_facing(gesture_name, member), expected, 0.001, gesture_name)


func test_aside_thirds_keep_depth_and_face_the_pair_at_both_doors() -> void:
	var s = _scene()
	for member in [2, 5]:
		for wide in [0.0, 0.4]:
			var first: Vector3 = s._knot_place(member - 2, wide)
			var second: Vector3 = s._knot_place(member - 1, wide)
			var third: Vector3 = s._knot_place(member, wide, true)
			assert_almost_eq(first.z - third.z, float(s.KNOT_DEPTH), 0.001)
			assert_gt(first.z - third.z, 0.2)
			var toward: Vector3 = ((first + second) * 0.5 - third).normalized()
			var yaw: float = s._knot_facing(member, wide, true)
			assert_true(Vector3(sin(yaw), 0, cos(yaw)).is_equal_approx(toward))
			assert_almost_eq(s._knot_gesture_facing(Gesture.WHISPER, member, wide, true), yaw, 0.001)


func test_idle_gesture_keeps_the_arrival_facing() -> void:
	var s = _scene()
	var c: Dictionary = s.car("guard")
	var b: Node3D = c["bodies"][0]
	b.state = "wait"
	b.gesture = ""
	b.idle_gesture = Gesture.RUB_STAMP
	b.rotation.y = 1.2
	s._idle(c, b)
	assert_almost_eq(float(b.gesture_facing), 1.2, 0.001)
	for now in [0.0, 0.5, 1.0, 2.0]:
		s.clock = now
		s._show_gesture(c, b)
		assert_almost_eq(float(b.rotation.y), 1.2, 0.001)


func test_a_gesturing_body_shows_both_its_arm_boxes() -> void:
	var s = _scene()
	s.set_train("tension", 70.0)
	for b in _gesturing(s, "tail1"):
		assert_true(b.has_meta(Gesture.ARMS_META))
		var arms: Array = b.get_meta(Gesture.ARMS_META)
		assert_eq(arms.size(), 2)
		for arm in arms:
			assert_true(arm.visible)


func test_calm_again_nobody_gestures_and_every_arm_is_hidden() -> void:
	var s = _scene()
	s.set_train("tension", 70.0)
	assert_gt(_gesturing_anywhere(s), 0)
	s.set_train("tension", 20.0)
	assert_eq(_gesturing_anywhere_but_cold(s), 0)
	var seen := 0
	for c in s.cars:
		for b in c["bodies"]:
			if b.has_meta(Gesture.ARMS_META) and b.gesture != Gesture.RUB_STAMP:
				seen += 1
				for arm in b.get_meta(Gesture.ARMS_META):
					assert_false(arm.visible, String(c["id"]))
	assert_gt(seen, 0, "the arms were made when the gestures began")


func test_a_frightened_train_does_not_quarrel() -> void:
	var s = _scene()
	s.set_train("tension", 70.0)
	s.set_train("fear", 60.0)
	for c in s.cars:
		for b in _gesturing(s, String(c["id"])):
			assert_eq(b.gesture, Gesture.HUG_KNEES, String(c["id"]))


func test_the_gestures_begin_at_sixty_tension() -> void:
	var s = _scene()
	s.set_train("tension", 59.0)
	assert_eq(_gesturing_but_cold(s, "tail1").size(), 0)
	s.set_train("tension", 60.0)
	assert_eq(_gesturing(s, "tail1").size(), 3)


func test_a_car_stirred_only_by_its_own_grudge_does_not_quarrel() -> void:
	var s = _scene()
	s.set_train("tension", 20.0)
	s.set_comm("tail", "rel", -50)
	assert_eq(s.car("tail1")["mood"], "stir")
	assert_gt(_standing_about(s, "tail1"), 0)
	var rows := _gesturing(s, "tail1")
	assert_gt(rows.size(), 0)
	for b in rows:
		assert_false([Gesture.ARGUE, Gesture.WHISPER, Gesture.TURN_ABOUT].has(b.gesture), b.gesture)


func test_the_dining_car_in_session_does_not_gesture() -> void:
	var s = _council()
	s.set_train("tension", 70.0)
	assert_eq(_gesturing(s, "dining").size(), 0)


func test_gestures_move_nobody_along_the_car() -> void:
	var s = _scene()
	s.set_train("tension", 70.0)
	var before: Dictionary = {}
	for b in _gesturing(s, "tail1"):
		before[b] = b.position.x
	assert_eq(before.size(), 3)
	for i in 60:
		s.step(0.1)
	assert_eq(_gesturing(s, "tail1").size(), 3)
	for b in before:
		assert_eq(b.position.x, before[b], "it stays where it stood")


func test_gestures_make_and_remove_nobody() -> void:
	var s = _scene()
	s.set_train("tension", 20.0)
	var calm := 0
	for c in s.cars:
		calm += _count(s, String(c["id"]))
	s.set_train("tension", 70.0)
	var tense := 0
	for c in s.cars:
		tense += _count(s, String(c["id"]))
	assert_eq(tense, calm)


# ---------------------------------------------------------------- the gestures of a resentful car

## A scene whose tail resents the captain on a train that is not tense.
func _resentful() -> Node3D:
	var s = _scene()
	s.set_train("tension", 20.0)
	s.set_comm("tail", "rel", -50)
	return s


## The folded arms of a car, in knot order.
func _folded(s, car_id: String) -> Array:
	return _gesturing(s, car_id).filter(func(b) -> bool: return b.gesture == Gesture.ARMS_CROSSED)


## Which way along the train the captain's car lies from a car: 1 ahead, -1 behind.
func _toward_captain(s, car_id: String) -> float:
	return signf(float(s.car("captain")["x0"]) - float(s.car(car_id)["x0"]))


func test_a_resentful_tail_folds_two_pairs_of_arms_and_turns_one_back() -> void:
	var s = _resentful()
	var rows := _gesturing(s, "tail1")
	assert_eq(rows.size(), 3)
	assert_eq(_folded(s, "tail1").size(), 2)
	assert_eq(rows.filter(func(b) -> bool: return b.gesture == Gesture.BACK_TURNED).size(), 1)
	for b in rows:
		assert_eq(b.pose, "stand")
		assert_eq(b.state, "seat")
	for b in s.car("tail1")["bodies"]:
		if b.state != "seat":
			assert_eq(b.gesture, "", "a walker does not gesture")


func test_cars_with_a_good_standing_do_not_resent() -> void:
	var s = _resentful()
	assert_eq(_gesturing(s, "medtech").size(), 0)
	assert_eq(_gesturing(s, "front").size(), 0)


func test_those_with_folded_arms_half_turn_to_the_captains_car() -> void:
	var s = _resentful()
	var side := _toward_captain(s, "tail1")
	assert_ne(side, 0.0)
	s.step(0.1)
	var folded := _folded(s, "tail1")
	assert_eq(folded.size(), 2)
	for b in folded:
		assert_almost_eq(float(b.rotation.y), side * s.RESENT_TURN, 0.01)


func test_a_car_ahead_of_the_captain_turns_the_other_way() -> void:
	var s = _resentful()
	s.set_comm("front", "rel", -50)
	s.step(0.1)
	var tail_side := _toward_captain(s, "tail1")
	var front_side := _toward_captain(s, "front")
	assert_ne(front_side, 0.0)
	assert_eq(front_side, -tail_side)
	var folded := _folded(s, "front")
	assert_gt(folded.size(), 0)
	for b in folded:
		assert_eq(signf(float(b.rotation.y)), front_side)


func test_the_one_with_its_back_turned_has_its_back_to_the_captains_car() -> void:
	var s = _resentful()
	var side := _toward_captain(s, "tail1")
	s.step(0.1)
	var backs := _gesturing(s, "tail1").filter(func(b) -> bool: return b.gesture == Gesture.BACK_TURNED)
	assert_eq(backs.size(), 1)
	for b in backs:
		# It looks over its shoulder now and then, so the angle is not compared exactly.
		assert_lt(cos(float(b.rotation.y) - side * s.RESENT_TURN), 0.0)


func test_each_gesturing_body_keeps_where_it_was_told_to_face() -> void:
	var s = _resentful()
	var side := _toward_captain(s, "tail1")
	var rows := _gesturing(s, "tail1")
	assert_eq(rows.size(), 3)
	for b in rows:
		assert_almost_eq(float(b.gesture_facing), side * s.RESENT_TURN, 0.0001)


func test_a_resentful_body_shows_both_its_arm_boxes() -> void:
	var s = _resentful()
	var rows := _gesturing(s, "tail1")
	assert_eq(rows.size(), 3)
	for b in rows:
		assert_true(b.has_meta(Gesture.ARMS_META))
		var arms: Array = b.get_meta(Gesture.ARMS_META)
		assert_eq(arms.size(), 2)
		for arm in arms:
			assert_true(arm.visible)


func test_the_resentful_do_not_stand_wider_apart() -> void:
	var s = _resentful()
	var rows := _gesturing(s, "tail1")
	var first = rows.filter(func(b) -> bool: return b.gesture_role == 0)[0]
	var second = rows.filter(func(b) -> bool: return b.gesture_role == 1)[0]
	assert_almost_eq(absf(float(second.position.x) - float(first.position.x)), float(s.KNOT_STEP), 0.01)


func test_rising_tension_leaves_one_of_a_resentful_car_with_folded_arms() -> void:
	var s = _resentful()
	s.set_train("tension", 70.0)
	var rows := _gesturing(s, "tail1")
	assert_eq(rows.size(), 3)
	assert_eq(rows.filter(func(b) -> bool: return b.gesture == Gesture.ARGUE).size(), 2)
	assert_eq(rows.filter(func(b) -> bool: return b.gesture == Gesture.ARMS_CROSSED).size(), 1)
	for b in rows:
		assert_false([Gesture.BACK_TURNED, Gesture.TURN_ABOUT].has(b.gesture), b.gesture)


func test_a_mended_standing_ends_the_resentment() -> void:
	var s = _resentful()
	assert_gt(_gesturing_anywhere(s), 0)
	s.set_comm("tail", "rel", 0)
	assert_eq(_gesturing_anywhere_but_cold(s), 0)
	for b in s.car("tail1")["bodies"]:
		assert_eq(b.gesture_facing, 0.0)
	var seen := 0
	for c in s.cars:
		for b in c["bodies"]:
			if b.has_meta(Gesture.ARMS_META) and b.gesture != Gesture.RUB_STAMP:
				seen += 1
				for arm in b.get_meta(Gesture.ARMS_META):
					assert_false(arm.visible, String(c["id"]))
	assert_gt(seen, 0, "the arms were made when the gestures began")


func test_a_grudge_alone_folds_arms() -> void:
	var s = _scene()
	s.set_train("tension", 20.0)
	s.set_comm("tail", "grudge", 2)
	assert_eq(s.car("tail1")["mood"], "stir")
	assert_gt(_folded(s, "tail1").size(), 0)


func test_a_frightened_train_does_not_resent() -> void:
	var s = _resentful()
	s.set_train("fear", 60.0)
	for c in s.cars:
		for b in _gesturing(s, String(c["id"])):
			assert_eq(b.gesture, Gesture.HUG_KNEES, String(c["id"]))


func test_resentment_moves_nobody_along_the_car() -> void:
	var s = _resentful()
	var before: Dictionary = {}
	for b in _gesturing(s, "tail1"):
		before[b] = b.position.x
	assert_eq(before.size(), 3)
	for i in 60:
		s.step(0.1)
	assert_eq(_gesturing(s, "tail1").size(), 3)
	for b in before:
		assert_eq(b.position.x, before[b], "it stays where it stood")


func test_resentment_makes_and_removes_nobody() -> void:
	var s = _scene()
	s.set_train("tension", 20.0)
	var before := 0
	for c in s.cars:
		before += _count(s, String(c["id"]))
	s.set_comm("tail", "rel", -50)
	var after := 0
	for c in s.cars:
		after += _count(s, String(c["id"]))
	assert_eq(after, before)


# ---------------------------------------------------------------- the gestures of a frightened train

## A scene whose train is frightened, with the tail crowded onto the floor.
func _frightened() -> Node3D:
	var s = _scene()
	s.set_train("fear", 70.0)
	return s


## Those of a car who sit on the floor.
func _floor_seated(s, car_id: String) -> int:
	var n := 0
	for b in s.car(car_id)["bodies"]:
		n += 1 if b.state == "seat" and b.pose == "floor" else 0
	return n


func test_a_frightened_tails_first_three_on_the_floor_hug_their_knees() -> void:
	var s = _frightened()
	var low := _floor_seated(s, "tail1")
	assert_gt(low, 0)
	var rows := _gesturing(s, "tail1")
	assert_eq(rows.size(), mini(3, low))
	for b in rows:
		assert_eq(b.gesture, Gesture.HUG_KNEES)
		assert_eq(b.pose, "floor")
		assert_eq(b.state, "seat")
		assert_true(b.huddled)


func test_a_crowd_on_the_floor_stops_at_three_hugging() -> void:
	var s = _frightened()
	s.set_sit("tail", 2, 100.0)
	assert_gt(_floor_seated(s, "tail1"), 3)
	assert_eq(_gesturing(s, "tail1").size(), 3)


func test_a_roomy_car_brings_two_down_off_the_bench_to_hug() -> void:
	assert_eq(_floor_seated(_scene(), "front"), 0, "calm: nobody sits on the floor of a roomy car")
	var s = _frightened()
	assert_eq(_floor_seated(s, "front"), 2)
	assert_eq(_gesturing(s, "front").size(), 2)


func test_only_those_on_the_floor_hug_in_a_frightened_train() -> void:
	var s = _frightened()
	assert_gt(_gesturing_anywhere(s), 0)
	for c in s.cars:
		for b in _gesturing(s, String(c["id"])):
			assert_eq(b.pose, "floor", String(c["id"]))


func test_the_three_who_hug_each_have_a_beat_of_their_own() -> void:
	var s = _frightened()
	s.set_sit("tail", 2, 100.0)
	var roles: Array = []
	for b in _gesturing(s, "tail1"):
		roles.append(int(b.gesture_role))
	roles.sort()
	assert_eq(roles, [0, 1, 2])


func test_a_hugging_body_shows_both_its_arm_boxes() -> void:
	var s = _frightened()
	var rows := _gesturing(s, "tail1")
	assert_gt(rows.size(), 0)
	for b in rows:
		assert_true(b.has_meta(Gesture.ARMS_META))
		var arms: Array = b.get_meta(Gesture.ARMS_META)
		assert_eq(arms.size(), 2)
		for arm in arms:
			assert_true(arm.visible)


func test_those_who_hug_their_knees_are_not_turned() -> void:
	var s = _frightened()
	s.step(0.1)
	var rows := _gesturing(s, "tail1")
	assert_gt(rows.size(), 0)
	for b in rows:
		assert_eq(b.gesture_facing, 0.0)
		assert_almost_eq(float(b.rotation.y), 0.0, 0.01)


func test_a_fear_that_lifts_ends_the_hugging() -> void:
	var s = _frightened()
	assert_gt(_gesturing_anywhere(s), 0)
	s.set_train("fear", 0.0)
	assert_eq(_gesturing_anywhere_but_cold(s), 0)
	var seen := 0
	for c in s.cars:
		for b in c["bodies"]:
			if b.has_meta(Gesture.ARMS_META) and b.gesture != Gesture.RUB_STAMP:
				seen += 1
				for arm in b.get_meta(Gesture.ARMS_META):
					assert_false(arm.visible, String(c["id"]))
	assert_gt(seen, 0, "the arms were made when the hugging began")


func test_a_fear_that_lifts_leaves_a_tense_train_quarrelling() -> void:
	var s = _scene()
	s.set_train("tension", 70.0)
	s.set_train("fear", 70.0)
	s.set_train("fear", 0.0)
	var rows := _gesturing(s, "tail1")
	assert_eq(rows.filter(func(b) -> bool: return b.gesture == Gesture.ARGUE).size(), 2)
	assert_eq(rows.filter(func(b) -> bool: return b.gesture == Gesture.HUG_KNEES).size(), 0)


func test_the_council_room_does_not_hug_in_fear() -> void:
	var s = _council()
	s.set_train("fear", 70.0)
	assert_eq(_gesturing(s, "dining").size(), 0)


func test_hugging_moves_nobody_along_the_car() -> void:
	var s = _frightened()
	var before: Dictionary = {}
	for b in _gesturing(s, "tail1"):
		before[b] = Vector2(b.position.x, b.position.z)
	assert_gt(before.size(), 0)
	for i in 60:
		s.step(0.1)
	assert_eq(_gesturing(s, "tail1").size(), before.size())
	for b in before:
		assert_eq(b.position.x, before[b].x, "it stays where it sat")
		assert_eq(b.position.z, before[b].y, "it stays where it sat")


func test_fear_makes_and_removes_nobody_by_hugging() -> void:
	var s = _scene()
	var before := 0
	for c in s.cars:
		before += _count(s, String(c["id"]))
	s.set_train("fear", 70.0)
	var after := 0
	for c in s.cars:
		after += _count(s, String(c["id"]))
	assert_eq(after, before)


# ---------------------------------------------------------------- two values in one car

## A scene whose tail is tense and resents the captain too.
func _tense_and_resentful() -> Node3D:
	var s = _resentful()
	s.set_train("tension", 70.0)
	return s


## Those of a car in a gesture of a given name.
func _doing(s, car_id: String, gesture_name: String) -> Array:
	return _gesturing(s, car_id).filter(func(b) -> bool: return b.gesture == gesture_name)


func test_the_one_with_folded_arms_half_turns_to_the_captains_car_and_the_pair_does_not() -> void:
	var s = _tense_and_resentful()
	var side := _toward_captain(s, "tail1")
	assert_ne(side, 0.0)
	var folded := _doing(s, "tail1", Gesture.ARMS_CROSSED)
	assert_eq(folded.size(), 1)
	assert_almost_eq(float(folded[0].gesture_facing), side * s.RESENT_TURN, 0.0001)
	var pair := _doing(s, "tail1", Gesture.ARGUE)
	assert_eq(pair.size(), 2)
	for b in pair:
		assert_eq(b.gesture_facing, 0.0)
	s.step(0.1)
	assert_almost_eq(float(folded[0].rotation.y), side * s.RESENT_TURN, 0.01)


func test_the_one_with_folded_arms_stands_beside_the_pair_with_depth() -> void:
	var s = _tense_and_resentful()
	var folded := _doing(s, "tail1", Gesture.ARMS_CROSSED)
	var pair := _doing(s, "tail1", Gesture.ARGUE)
	assert_eq(folded.size(), 1)
	assert_eq(pair.size(), 2)
	var second = pair.filter(func(b) -> bool: return b.gesture_role == 1)[0]
	for b in pair:
		assert_almost_eq(float(folded[0].position.z), float(b.position.z) - float(s.KNOT_DEPTH), 0.001)
	assert_almost_eq(float(folded[0].position.x) - float(second.position.x), float(s.KNOT_STEP), 0.01)


func test_without_resentment_the_third_still_stands_behind_the_pair() -> void:
	var s = _scene()
	s.set_train("tension", 70.0)
	var about := _doing(s, "tail1", Gesture.TURN_ABOUT)
	var pair := _doing(s, "tail1", Gesture.ARGUE)
	assert_eq(about.size(), 1)
	assert_eq(pair.size(), 2)
	for b in pair:
		assert_almost_eq(float(about[0].position.z), float(b.position.z) - float(s.KNOT_DEPTH), 0.001)
	var low := minf(float(pair[0].position.x), float(pair[1].position.x))
	var high := maxf(float(pair[0].position.x), float(pair[1].position.x))
	assert_gt(float(about[0].position.x), low)
	assert_lt(float(about[0].position.x), high)


func test_a_car_in_good_standing_does_not_fold_its_arms_on_a_tense_train() -> void:
	var s = _tense_and_resentful()
	assert_eq(_doing(s, "medtech", Gesture.ARMS_CROSSED).size(), 0)
	assert_eq(_doing(s, "medtech", Gesture.TURN_ABOUT).size(), 1)


func test_a_mended_standing_sends_the_third_back_to_look_about() -> void:
	var s = _tense_and_resentful()
	s.set_comm("tail", "rel", 0)
	assert_eq(_doing(s, "tail1", Gesture.ARMS_CROSSED).size(), 0)
	var about := _doing(s, "tail1", Gesture.TURN_ABOUT)
	assert_eq(about.size(), 1)
	assert_eq(about[0].gesture_facing, 0.0)
	for b in _doing(s, "tail1", Gesture.ARGUE):
		assert_almost_eq(float(about[0].position.z), float(b.position.z) - float(s.KNOT_DEPTH), 0.001)


func test_a_tension_that_subsides_leaves_only_the_gestures_of_resentment() -> void:
	var s = _tense_and_resentful()
	s.set_train("tension", 20.0)
	assert_eq(_doing(s, "tail1", Gesture.ARGUE).size(), 0)
	assert_eq(_doing(s, "tail1", Gesture.ARMS_CROSSED).size(), 2)
	assert_eq(_doing(s, "tail1", Gesture.BACK_TURNED).size(), 1)


func test_a_grudge_alone_is_enough_to_fold_a_thirds_arms_on_a_tense_train() -> void:
	var s = _scene()
	s.set_comm("tail", "grudge", 2)
	s.set_train("tension", 70.0)
	assert_eq(_doing(s, "tail1", Gesture.ARGUE).size(), 2)
	assert_eq(_doing(s, "tail1", Gesture.ARMS_CROSSED).size(), 1)


func test_fear_covers_both_tension_and_resentment() -> void:
	var s = _tense_and_resentful()
	s.set_train("fear", 60.0)
	assert_gt(_gesturing_anywhere(s), 0)
	for c in s.cars:
		for b in _gesturing(s, String(c["id"])):
			assert_eq(b.gesture, Gesture.HUG_KNEES, String(c["id"]))


func test_two_values_move_nobody_along_the_car() -> void:
	var s = _tense_and_resentful()
	var before: Dictionary = {}
	for b in _gesturing(s, "tail1"):
		before[b] = Vector2(b.position.x, b.position.z)
	assert_eq(before.size(), 3)
	for i in 60:
		s.step(0.1)
	assert_eq(_gesturing(s, "tail1").size(), 3)
	for b in before:
		assert_eq(b.position.x, before[b].x, "it stays where it stood")
		assert_eq(b.position.z, before[b].y, "it stays where it stood")

# ---------------------------------------------------------------- fright brings a couple down to the floor

func test_the_medical_car_also_brings_two_down_to_hug() -> void:
	assert_eq(_floor_seated(_scene(), "medtech"), 0)
	var s = _frightened()
	assert_eq(_floor_seated(s, "medtech"), 2)
	assert_eq(_doing(s, "medtech", Gesture.HUG_KNEES).size(), 2)


func test_the_cars_with_a_table_or_a_desk_keep_everyone_off_the_floor() -> void:
	var s = _frightened()
	for id in ["dining", "captain"]:
		assert_eq(_floor_seated(s, id), 0, id)
		assert_eq(_gesturing(s, id).size(), 0, id)


func test_those_who_come_down_sit_in_the_floor_row_and_huddle() -> void:
	var s = _frightened()
	var rows := _gesturing(s, "front")
	assert_eq(rows.size(), 2)
	for b in rows:
		assert_almost_eq(float(b.position.z), float(s.FLOOR_Z), 0.001)
		assert_eq(b.pose, "floor")
		assert_eq(b.state, "seat")
		assert_true(b.huddled)


func test_coming_down_off_the_bench_adds_and_removes_nobody() -> void:
	var s = _scene()
	var front := _count(s, "front")
	var medtech := _count(s, "medtech")
	s.set_train("fear", 70.0)
	assert_eq(_count(s, "front"), front)
	assert_eq(_count(s, "medtech"), medtech)


func test_a_fear_that_lifts_puts_the_two_back_on_the_bench() -> void:
	var s = _frightened()
	s.set_train("fear", 0.0)
	for id in ["front", "medtech"]:
		assert_eq(_floor_seated(s, id), 0, id)
		assert_eq(_gesturing(s, id).size(), 0, id)


func test_a_crowded_tail_sits_on_the_floor_as_it_did_before() -> void:
	assert_eq(_floor_seated(_frightened(), "tail1"), _floor_seated(_scene(), "tail1"))


func test_a_roomy_car_that_fills_up_follows_its_crowding() -> void:
	var s = _frightened()
	s.set_sit("front", 2, 100.0)
	assert_gt(_floor_seated(s, "front"), 3)
	assert_eq(_gesturing(s, "front").size(), 3)


func test_the_two_who_came_down_stay_where_they_sat() -> void:
	var s = _frightened()
	var before: Dictionary = {}
	for b in _gesturing(s, "front"):
		before[b] = Vector2(b.position.x, b.position.z)
	assert_eq(before.size(), 2)
	for i in 60:
		s.step(0.1)
	assert_eq(_gesturing(s, "front").size(), 2)
	for b in before:
		assert_eq(b.position.x, before[b].x, "it stays where it sat")
		assert_eq(b.position.z, before[b].y, "it stays where it sat")

# ---------------------------------------------------------------- the gestures of a hungry car

## A scene whose infirmary is short of food: warm enough, and no one on the floor.
func _hungry() -> Node3D:
	var s = _scene()
	s.set_sit("medtech", 1, 30.0)
	return s


## Those of a car who hold an empty bowl that can be seen.
func _bowls(s, car_id: String) -> int:
	var n := 0
	for b in s.car(car_id)["bodies"]:
		if b.has_meta(s.PROP_META) and (b.get_meta(s.PROP_META) as Node3D).visible:
			n += 1
	return n


func test_a_hungry_infirmary_has_two_on_the_bench_looking_into_a_bowl() -> void:
	var s = _hungry()
	var rows := _doing(s, "medtech", Gesture.BOWL_SIT)
	assert_eq(rows.size(), 2)
	var roles: Array = []
	for b in rows:
		assert_eq(b.pose, "sit")
		assert_eq(b.state, "seat")
		assert_false(b.huddled)
		assert_eq(b.gesture_facing, 0.0)
		roles.append(int(b.gesture_role))
	roles.sort()
	assert_eq(roles, [0, 1])
	assert_eq(_gesturing(s, "medtech").size(), 2, "nobody else gestures")


func test_both_hold_their_bowl_where_the_gesture_says() -> void:
	var s = _hungry()
	assert_eq(_bowls(s, "medtech"), 2)
	var want: Vector3 = Gesture.at(Gesture.BOWL_SIT, 0.0, 0)["prop"]["pos"]
	for b in _doing(s, "medtech", Gesture.BOWL_SIT):
		var held: Node3D = b.get_meta(s.PROP_META)
		assert_true(held.visible)
		assert_almost_eq(float(held.position.x), want.x, 0.001)
		assert_almost_eq(float(held.position.y), want.y, 0.001)
		assert_almost_eq(float(held.position.z), want.z, 0.001)


func test_the_default_scene_holds_no_bowl_and_no_gesture_but_the_colds() -> void:
	var s = _scene()
	for c in s.cars:
		assert_eq(_bowls(s, String(c["id"])), 0, String(c["id"]))
	assert_eq(_gesturing_anywhere_but_cold(s), 0)


func test_a_car_that_is_not_hungry_holds_no_bowl() -> void:
	var s = _hungry()
	for id in ["tail1", "dining", "captain", "front"]:
		assert_eq(_bowls(s, id), 0, id)
		assert_eq(_doing(s, id, Gesture.BOWL_SIT).size(), 0, id)


func test_a_tail_hungrier_than_cold_holds_bowls_and_the_huddled_floor_keeps_to_the_cold() -> void:
	var s = _scene()
	s.set_sit("tail", 1, 20.0)
	assert_eq(_doing(s, "tail1", Gesture.BOWL_SIT).size(), 2)
	assert_eq(_doing(s, "tail1", Gesture.SLUMP).size(), 0)
	assert_gt(_floor_seated(s, "tail1"), 0)


func test_a_warm_crowded_hungry_front_has_two_with_bowls_and_two_lying_back() -> void:
	var s = _scene()
	s.set_sit("front", 1, 30.0)
	s.set_sit("front", 2, 100.0)
	assert_eq(_doing(s, "front", Gesture.BOWL_SIT).size(), 2)
	var lying := _doing(s, "front", Gesture.SLUMP)
	assert_eq(lying.size(), 2)
	for b in lying:
		assert_eq(b.pose, "floor")
		assert_eq(b.state, "seat")
		assert_false(b.huddled)


func test_a_ration_that_rises_puts_the_bowls_down() -> void:
	var s = _hungry()
	s.set_sit("medtech", 1, 60.0)
	assert_eq(_gesturing(s, "medtech").size(), 0)
	assert_eq(_bowls(s, "medtech"), 0)


func test_a_colder_car_does_not_hold_bowls() -> void:
	var s = _hungry()
	s.set_sit("medtech", 0, 20.0)
	assert_eq(_doing(s, "medtech", Gesture.BOWL_SIT).size(), 0)
	assert_eq(_bowls(s, "medtech"), 0)


func test_tension_fear_or_resentment_covers_the_hunger() -> void:
	var tense = _hungry()
	tense.set_train("tension", 70.0)
	assert_eq(_doing(tense, "medtech", Gesture.BOWL_SIT).size(), 0, "tension")
	assert_eq(_bowls(tense, "medtech"), 0, "tension")
	var afraid = _hungry()
	afraid.set_train("fear", 70.0)
	assert_eq(_doing(afraid, "medtech", Gesture.BOWL_SIT).size(), 0, "fear")
	assert_eq(_bowls(afraid, "medtech"), 0, "fear")
	var resentful = _hungry()
	resentful.set_comm("medtech", "rel", -50)
	assert_eq(_doing(resentful, "medtech", Gesture.BOWL_SIT).size(), 0, "resentment")
	assert_eq(_bowls(resentful, "medtech"), 0, "resentment")


func test_those_with_bowls_stay_where_they_sat() -> void:
	var s = _hungry()
	var before: Dictionary = {}
	for b in _doing(s, "medtech", Gesture.BOWL_SIT):
		before[b] = Vector2(b.position.x, b.position.z)
	assert_eq(before.size(), 2)
	for i in 60:
		s.step(0.1)
	assert_eq(_doing(s, "medtech", Gesture.BOWL_SIT).size(), 2)
	assert_eq(_bowls(s, "medtech"), 2)
	for b in before:
		assert_eq(b.position.x, before[b].x, "it stays where it sat")
		assert_eq(b.position.z, before[b].y, "it stays where it sat")


func test_hunger_adds_and_removes_nobody() -> void:
	var s = _scene()
	var before := _count(s, "medtech")
	s.set_sit("medtech", 1, 30.0)
	assert_eq(_count(s, "medtech"), before)


func test_a_body_with_a_bowl_shows_both_its_arm_boxes() -> void:
	var s = _hungry()
	var rows := _doing(s, "medtech", Gesture.BOWL_SIT)
	assert_gt(rows.size(), 0)
	for b in rows:
		assert_true(b.has_meta(Gesture.ARMS_META))
		var arms: Array = b.get_meta(Gesture.ARMS_META)
		assert_eq(arms.size(), 2)
		for arm in arms:
			assert_true(arm.visible)

# ---------------------------------------------------------------- the gestures of a cold car

## Those of a car who stand between two walks.
func _waiting(s, car_id: String) -> Array:
	return (s.car(car_id)["bodies"] as Array).filter(func(b) -> bool: return b.state == "wait")


## How many of a body's two arm boxes can be seen.
func _arms_shown(b) -> int:
	var n := 0
	if b.has_meta(Gesture.ARMS_META):
		for arm in b.get_meta(Gesture.ARMS_META):
			n += 1 if arm.visible else 0
	return n


func test_the_two_who_walk_in_a_cold_tail_rub_their_hands_while_they_stand() -> void:
	var s = _scene()
	var rows := _doing(s, "tail1", Gesture.RUB_STAMP)
	assert_eq(rows.size(), 2)
	var roles: Array = []
	for b in rows:
		assert_eq(b.state, "wait")
		assert_eq(b.pose, "stand")
		assert_false(b.huddled)
		assert_eq(b.gesture_facing, 0.0)
		assert_eq(b.idle_gesture, Gesture.RUB_STAMP)
		roles.append(int(b.gesture_role))
	roles.sort()
	assert_eq(roles, [0, 1])
	assert_eq(_gesturing_but_cold(s, "tail1").size(), 0, "nobody else gestures")


func test_a_body_that_rubs_its_hands_shows_both_its_arm_boxes() -> void:
	var s = _scene()
	var rows := _doing(s, "tail1", Gesture.RUB_STAMP)
	assert_gt(rows.size(), 0)
	for b in rows:
		assert_true(b.has_meta(Gesture.ARMS_META))
		var arms: Array = b.get_meta(Gesture.ARMS_META)
		assert_eq(arms.size(), 2)
		for arm in arms:
			assert_true(arm.visible)


func test_no_other_car_rubs_its_hands_at_the_start() -> void:
	var s = _scene()
	for id in ["medtech", "dining", "captain", "front"]:
		assert_eq(_doing(s, id, Gesture.RUB_STAMP).size(), 0, id)


func test_hands_are_rubbed_only_while_standing_between_walks() -> void:
	var s = _scene()
	var wrong := 0
	var walking := 0
	for i in 300:
		s.step(0.1)
		for b in s.car("tail1")["bodies"]:
			var should: bool = b.idle_gesture == Gesture.RUB_STAMP and b.state == "wait"
			wrong += 0 if (b.gesture == Gesture.RUB_STAMP) == should else 1
			walking += 1 if b.idle_gesture == Gesture.RUB_STAMP and b.state != "wait" else 0
	assert_eq(wrong, 0)
	assert_gt(walking, 0, "it did let go to walk")


func test_one_who_sets_off_puts_its_arms_down() -> void:
	var s = _scene()
	var seen := 0
	for i in 300:
		s.step(0.1)
		for b in s.car("tail1")["bodies"]:
			if b.idle_gesture == Gesture.RUB_STAMP and b.state != "wait":
				seen += 1
				assert_eq(b.gesture, "")
				assert_eq(_arms_shown(b), 0)
	assert_gt(seen, 0, "someone set off")


func test_one_who_walks_in_a_cold_tail_still_turns_the_way_it_goes() -> void:
	var s = _scene()
	var seen := 0
	for i in 300:
		s.step(0.1)
		for b in s.car("tail1")["bodies"]:
			if b.pose == "walk":
				seen += 1
				assert_almost_eq(absf(float(b.rotation.y)), PI * 0.5, 0.01)
	assert_gt(seen, 0, "someone walked")


func test_a_warmth_that_rises_ends_the_rubbing() -> void:
	var s = _scene()
	s.set_sit("tail", 0, 60.0)
	assert_eq(_doing(s, "tail1", Gesture.RUB_STAMP).size(), 0)
	for b in s.car("tail1")["bodies"]:
		assert_ne(b.idle_gesture, Gesture.RUB_STAMP)
	assert_eq(_doing(s, "tail1", Gesture.BOWL_SIT).size(), 2, "the hunger shows instead")


func test_a_tail_hungrier_than_cold_does_not_rub_its_hands() -> void:
	var s = _scene()
	s.set_sit("tail", 1, 20.0)
	assert_eq(_doing(s, "tail1", Gesture.RUB_STAMP).size(), 0)
	assert_eq(_doing(s, "tail1", Gesture.BOWL_SIT).size(), 2)


func test_tension_fear_or_resentment_covers_the_cold() -> void:
	var tense = _scene()
	tense.set_train("tension", 70.0)
	var afraid = _scene()
	afraid.set_train("fear", 70.0)
	var resentful = _scene()
	resentful.set_comm("tail", "rel", -50)
	var scenes := {"tension": tense, "fear": afraid, "resentment": resentful}
	for name in scenes:
		assert_eq(_doing(scenes[name], "tail1", Gesture.RUB_STAMP).size(), 0, name)
		for i in 100:
			scenes[name].step(0.1)
		assert_eq(_doing(scenes[name], "tail1", Gesture.RUB_STAMP).size(), 0, "%s, later" % name)


func test_a_cooled_infirmary_rubs_its_hands_too() -> void:
	var s = _scene()
	s.set_sit("medtech", 0, 30.0)
	var waiting := _waiting(s, "medtech").size()
	assert_gt(waiting, 0)
	assert_eq(_doing(s, "medtech", Gesture.RUB_STAMP).size(), waiting)


func test_cold_adds_and_removes_nobody() -> void:
	var s = _scene()
	var before := _count(s, "tail1")
	s.set_sit("tail", 0, 60.0)
	assert_eq(_count(s, "tail1"), before)


func test_those_who_rub_their_hands_keep_their_place() -> void:
	var s = _scene()
	var before: Dictionary = {}
	for b in _doing(s, "tail1", Gesture.RUB_STAMP):
		before[b] = b.position.x
	assert_eq(before.size(), 2)
	for i in 5:
		s.step(0.1)
	assert_eq(_doing(s, "tail1", Gesture.RUB_STAMP).size(), 2)
	for b in before:
		assert_eq(b.gesture, Gesture.RUB_STAMP)
		assert_eq(b.position.x, before[b], "it stays where it stood")
