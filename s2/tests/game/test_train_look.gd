extends "res://addons/gut/test.gd"
## What a train car shows for its numbers: the head count (the web prototype's
## figures()), the warmth and crowding steps, the one mood a car is in, who
## walks, stands about, sits, hunches, and which trips a car may send.

const Look = preload("res://game/train/train_look.gd")
const Rules = preload("res://game/train/train_rules.gd")
const Gesture = preload("res://game/train/train_gesture.gd")

const WARMTHS: Array = [0.0, 29.9, 30.0, 44.9, 45.0, 60.0, 70.0, 70.1, 100.0]
const CROWDS: Array = [0.0, 45.0, 59.9, 60.0, 79.9, 80.0, 94.9, 95.0, 100.0]
const MOODS: Array = ["calm", "low", "stir", "frozen"]

var rules: Dictionary


func before_each() -> void:
	rules = Rules.load_default()


func _car(id: String) -> Dictionary:
	for c in rules["cars"]:
		if c["id"] == id:
			return c
	return {}


func _comm(id: String) -> Dictionary:
	return (rules["comms"] as Dictionary)[id].duplicate(true)


func _ids(rows: Array) -> Array:
	var ids: Array = []
	for e in rows:
		ids.append(e["id"])
	return ids


## A community with nothing wrong, then one number changed.
func _plain(key: String = "", value = null) -> Dictionary:
	var comm := {"rel": 0, "grudge": 0, "sit": [60.0, 60.0, 40.0, 30.0]}
	if key.begins_with("sit"):
		comm["sit"][int(key.substr(3))] = value
	elif key != "":
		comm[key] = value
	return comm


func _train(tension: float, fear: float) -> Dictionary:
	return {"phase": "travel", "tension": tension, "fear": fear}


# ---------------------------------------------------------------- head count

func test_figures_follow_the_web_prototype_formula() -> void:
	var tail := _car("tail1")
	assert_eq(Look.figures(tail, Rules.comm_of(rules, tail), "travel"), 16, "tail: 90 / 3 people, clamped")
	var medtech := _car("medtech")
	assert_eq(Look.figures(medtech, Rules.comm_of(rules, medtech), "travel"), 13)
	var front := _car("front")
	assert_eq(Look.figures(front, Rules.comm_of(rules, front), "travel"), 10)
	var guard := {"id": "guard", "kind": "comm", "comm": "guard"}
	assert_eq(Look.figures(guard, _comm("guard"), "travel"), 11)
	var engine := {"id": "engine", "kind": "engine", "comm": "engine"}
	assert_eq(Look.figures(engine, _comm("engine"), "travel"), 10)


func test_a_car_with_a_community_never_holds_fewer_than_two() -> void:
	var comm := _comm("medtech")
	comm["pop"] = 4
	comm["sit"] = [55, 50, 0, 25]
	assert_eq(Look.figures(_car("medtech"), comm, "travel"), 2)
	comm["pop"] = 0
	assert_eq(Look.figures(_car("medtech"), comm, "travel"), 2)


func test_people_away_leave_their_car_but_one_stays() -> void:
	var comm := _comm("medtech")
	comm["away"] = 3
	assert_eq(Look.figures(_car("medtech"), comm, "travel"), 10)
	comm["away"] = 99
	assert_eq(Look.figures(_car("medtech"), comm, "travel"), 1)


func test_the_tails_away_leave_from_its_first_car_only() -> void:
	var comm := _comm("tail")
	comm["away"] = 3
	var first := {"id": "tail1", "kind": "comm", "comm": "tail"}
	var second := {"id": "tail2", "kind": "comm", "comm": "tail"}
	assert_eq(Look.figures(first, comm, "travel"), 13)
	assert_eq(Look.figures(second, comm, "travel"), 16)


func test_the_dining_car_fills_for_the_session() -> void:
	var dining := _car("dining")
	assert_eq(Look.figures(dining, {}, "council"), 32, "the council: thirty to forty")
	for phase in ["prep", "travel", "stop", "settle", "end"]:
		assert_eq(Look.figures(dining, {}, phase), 4, phase)


func test_cars_without_a_community_have_fixed_counts() -> void:
	assert_eq(Look.figures(_car("captain"), {}, "travel"), 2)
	for kind in ["loco", "freight", "cold"]:
		assert_eq(Look.figures({"id": kind, "kind": kind}, {}, "travel"), 0, kind)
	assert_eq(Look.figures({"id": "x", "kind": "mystery"}, {}, "travel"), 3, "a kind nobody knows")


# ---------------------------------------------------------------- steps

func test_warmth_tone_steps_on_both_sides_of_each_edge() -> void:
	assert_eq(Look.warmth_tone(29.9), "freezing")
	assert_eq(Look.warmth_tone(30.0), "cold")
	assert_eq(Look.warmth_tone(44.9), "cold")
	assert_eq(Look.warmth_tone(45.0), "")
	assert_eq(Look.warmth_tone(70.0), "")
	assert_eq(Look.warmth_tone(70.1), "warm")


func test_crowd_level_steps_on_both_sides_of_each_edge() -> void:
	assert_eq(Look.crowd_level(59.9), 0)
	assert_eq(Look.crowd_level(60.0), 1)
	assert_eq(Look.crowd_level(79.9), 1)
	assert_eq(Look.crowd_level(80.0), 2)
	assert_eq(Look.crowd_level(94.9), 2)
	assert_eq(Look.crowd_level(95.0), 3)


func test_movers_are_a_few_of_the_car() -> void:
	assert_eq(Look.movers(0), 0)
	assert_eq(Look.movers(1), 1)
	assert_eq(Look.movers(8), 2)
	assert_eq(Look.movers(12), 3)
	assert_eq(Look.movers(16), 4)


# ---------------------------------------------------------------- the mood of a car

func test_a_car_with_nothing_wrong_is_calm() -> void:
	assert_eq(Look.mood(_plain(), _train(20.0, 0.0)), "calm")
	assert_eq(Look.mood(_plain(), {}), "calm", "a train without numbers")


func test_fear_freezes_every_car_from_sixty_and_before_anything_else() -> void:
	assert_eq(Look.mood(_plain(), _train(0.0, 59.9)), "calm")
	assert_eq(Look.mood(_plain(), _train(0.0, 60.0)), "frozen")
	assert_eq(Look.mood(_plain(), _train(100.0, 60.0)), "frozen", "fear quiets unrest")
	var angry := _plain("rel", -100)
	angry["sit"][0] = 0.0
	assert_eq(Look.mood(angry, _train(100.0, 60.0)), "frozen", "and anger, and cold")


func test_tension_stirs_every_car_from_sixty_and_before_cold_or_hunger() -> void:
	assert_eq(Look.mood(_plain(), _train(59.9, 0.0)), "calm")
	assert_eq(Look.mood(_plain(), _train(60.0, 0.0)), "stir")
	assert_eq(Look.mood(_plain("sit0", 10.0), _train(60.0, 0.0)), "stir", "unrest shows before cold")


func test_a_community_opposed_or_with_two_grudges_stirs_its_own_car() -> void:
	var train := _train(20.0, 0.0)
	assert_eq(Look.mood(_plain("rel", -39), train), "calm")
	assert_eq(Look.mood(_plain("rel", -40), train), "stir")
	assert_eq(Look.mood(_plain("grudge", 1), train), "calm")
	assert_eq(Look.mood(_plain("grudge", 2), train), "stir")
	var cold_and_angry := _plain("rel", -40)
	cold_and_angry["sit"][0] = 10.0
	assert_eq(Look.mood(cold_and_angry, train), "stir")


func test_cold_or_hunger_weighs_a_car_down_below_forty_five() -> void:
	var train := _train(20.0, 0.0)
	assert_eq(Look.mood(_plain("sit0", 45.0), train), "calm")
	assert_eq(Look.mood(_plain("sit0", 44.9), train), "low", "warmth")
	assert_eq(Look.mood(_plain("sit1", 45.0), train), "calm")
	assert_eq(Look.mood(_plain("sit1", 44.9), train), "low", "ration")
	assert_eq(Look.mood(_plain("sit2", 100.0), train), "calm", "crowding alone picks places, not the mood")


func test_a_car_without_a_community_follows_the_train_only() -> void:
	assert_eq(Look.mood({}, _train(20.0, 0.0)), "calm")
	assert_eq(Look.mood({}, _train(60.0, 0.0)), "stir")
	assert_eq(Look.mood({}, _train(60.0, 60.0)), "frozen")


func test_the_default_rules_start_with_a_low_tail_and_calm_cars_ahead() -> void:
	var train: Dictionary = rules["train"]
	assert_eq(Look.mood(_comm("tail"), train), "low")
	for id in ["medtech", "guard", "front", "engine"]:
		assert_eq(Look.mood(_comm(id), train), "calm", id)


func test_every_mood_has_a_name_and_a_whole_look() -> void:
	var keys: Array = (Look.MOOD_LOOK["calm"] as Dictionary).keys()
	for m in MOODS:
		assert_true(Look.MOOD_NAMES.has(m), m)
		var look: Dictionary = Look.mood_look(m)
		assert_eq(look.keys(), keys, m)
		assert_lte(int(look["movers"][0]), int(look["movers"][1]), m)
		assert_gt(float(look["speed"]), 0.0, m)
		assert_between(float(look["stand"]), 0.0, 1.0, m)
	assert_eq(Look.mood_look("nonsense"), Look.mood_look("calm"), "a mood nobody knows looks calm")


func test_the_mood_sets_how_many_walk() -> void:
	assert_eq(Look.movers(16, "calm"), 4)
	assert_eq(Look.movers(16, "low"), 2)
	assert_eq(Look.movers(4, "low"), 1)
	assert_eq(Look.movers(16, "stir"), 4)
	assert_eq(Look.movers(8, "stir"), 3, "more than a calm car of eight")
	assert_eq(Look.movers(2, "stir"), 2, "never more than the car holds")
	assert_eq(Look.movers(16, "frozen"), 1)
	assert_eq(Look.movers(1, "frozen"), 0)
	for m in MOODS:
		assert_eq(Look.movers(0, m), 0, m)


# ---------------------------------------------------------------- places and postures

func test_split_adds_up_and_hunches_only_the_seated() -> void:
	for m in MOODS:
		for count in range(17):
			for w in WARMTHS:
				for crowd in CROWDS:
					var s: Dictionary = Look.split(count, float(w), float(crowd), m)
					var label := "%s, %d people, warmth %s, crowding %s" % [m, count, w, crowd]
					assert_eq(int(s["walk"]) + int(s["stand"]) + int(s["bench"]) + int(s["floor"]), count, label)
					assert_lte(int(s["huddled"]), int(s["bench"]) + int(s["floor"]), label)
					assert_gte(int(s["bench"]), 0, label)


func test_only_a_stirred_car_stands_about() -> void:
	for count in range(17):
		for m in ["calm", "low", "frozen"]:
			assert_eq(Look.split(count, 50.0, 50.0, m)["stand"], 0, "%s, %d people" % [m, count])
	assert_eq(Look.split(16, 50.0, 50.0, "stir")["stand"], 4, "sixteen: four walk, four of the twelve stand")
	assert_eq(Look.split(13, 50.0, 50.0, "stir")["stand"], 3)


func test_cold_huddles_the_seated_and_warmth_does_not() -> void:
	for count in range(17):
		assert_eq(Look.split(count, 80.0, 50.0)["huddled"], 0, "warm, %d people" % count)
	assert_gt(int(Look.split(12, 10.0, 50.0)["huddled"]), 0, "freezing")
	assert_gt(int(Look.split(12, 40.0, 50.0)["huddled"]), 0, "cold")


func test_nobody_sits_on_the_floor_below_sixty_crowding() -> void:
	for count in range(17):
		for crowd in [0.0, 30.0, 59.9]:
			assert_eq(Look.split(count, 50.0, crowd)["floor"], 0, "%d people, crowding %s" % [count, crowd])
	assert_gt(int(Look.split(16, 50.0, 100.0)["floor"]), 0, "a full car sleeps in layers")


func test_seating_has_a_row_a_person_in_the_split_postures() -> void:
	for m in MOODS:
		for count in range(17):
			for w in WARMTHS:
				for crowd in CROWDS:
					var rows: Array = Look.seating(count, float(w), float(crowd), m)
					var s: Dictionary = Look.split(count, float(w), float(crowd), m)
					var seen := {"walk": 0, "stand": 0, "sit": 0, "floor": 0}
					var huddled := 0
					for r in rows:
						seen[String(r["pose"])] += 1
						huddled += 1 if bool(r["huddled"]) else 0
					var label := "%s, %d people, warmth %s, crowding %s" % [m, count, w, crowd]
					assert_eq(rows.size(), count, label)
					assert_eq(seen, {"walk": s["walk"], "stand": s["stand"], "sit": s["bench"], "floor": s["floor"]}, label)
					assert_eq(huddled, int(s["huddled"]), label)


func test_those_who_walk_or_stand_about_do_not_huddle() -> void:
	for m in MOODS:
		for count in range(17):
			for r in Look.seating(count, 5.0, 100.0, m):
				if r["pose"] == "walk" or r["pose"] == "stand":
					assert_false(bool(r["huddled"]), "%s, %d people" % [m, count])


func test_only_a_frightened_car_bows_its_head_and_only_the_seated() -> void:
	for m in MOODS:
		for r in Look.seating(16, 50.0, 100.0, m):
			var seated: bool = r["pose"] == "sit" or r["pose"] == "floor"
			assert_eq(bool(r["bowed"]), m == "frozen" and seated, "%s, %s" % [m, r["pose"]])


func test_seat_places_do_not_repeat_spread_or_gathered() -> void:
	for gather in [false, true]:
		var seen: Dictionary = {}
		for k in 15:
			var slot: int = Look.seat_slot(k, 15, gather)
			assert_between(slot, 0, 14, "place %d" % k)
			seen[slot] = true
		assert_eq(seen.size(), 15, "gathered" if gather else "spread")


func test_the_spread_sit_apart_and_the_gathered_fill_from_the_middle() -> void:
	var spread: Array = []
	var gathered: Array = []
	for k in 5:
		spread.append(Look.seat_slot(k, 15, false))
		gathered.append(Look.seat_slot(k, 15, true))
	assert_eq(spread, [0, 4, 8, 12, 1])
	assert_eq(gathered, [7, 8, 6, 9, 5])


func test_frost_grows_as_the_car_cools_and_the_stove_dies() -> void:
	assert_eq(Look.frost(100.0), 0.0)
	assert_eq(Look.frost(45.0), 0.0, "no frost from the cold step up")
	assert_almost_eq(Look.frost(30.0), 0.5, 0.001)
	assert_eq(Look.frost(15.0), 1.0)
	assert_eq(Look.frost(0.0), 1.0)
	assert_eq(Look.stove(0.0), 0.0)
	assert_eq(Look.stove(30.0), 0.0, "out in a freezing car")
	assert_almost_eq(Look.stove(50.0), 0.5, 0.001)
	assert_eq(Look.stove(70.0), 1.0)
	assert_eq(Look.stove(100.0), 1.0)
	for i in range(1, WARMTHS.size()):
		var colder: float = WARMTHS[i - 1]
		var warmer: float = WARMTHS[i]
		assert_gte(Look.frost(colder), Look.frost(warmer), "frost at %s and %s" % [colder, warmer])
		assert_lte(Look.stove(colder), Look.stove(warmer), "stove at %s and %s" % [colder, warmer])


# ---------------------------------------------------------------- calls between friendly cars

func test_the_gap_between_two_communities_sums_the_three_axes() -> void:
	assert_eq(Look.ideo_gap([1, -1, -1], [1, -1, -1]), 0.0)
	assert_eq(Look.ideo_gap([1, -1, -1], [-1, 1, 1]), 6.0)
	assert_eq(Look.ideo_gap([0, -1, 1], [-1, -1, 1]), 1.0)


func test_friends_are_the_communities_close_on_the_axes_and_both_ways() -> void:
	var ideo: Dictionary = rules["ideo"]
	assert_eq(Look.friends("medtech", ideo, 1.0), ["front"])
	assert_eq(Look.friends("front", ideo, 1.0), ["medtech"])
	assert_eq(Look.friends("engine", ideo, 1.0), ["guard"])
	assert_eq(Look.friends("guard", ideo, 1.0), ["engine"])
	assert_eq(Look.friends("tail", ideo, 1.0), [], "the tail stands far from everyone")
	for a in ideo:
		for b in Look.friends(String(a), ideo, 2.0):
			assert_true(Look.friends(b, ideo, 2.0).has(String(a)), "%s and %s" % [a, b])
		assert_false(Look.friends(String(a), ideo, 6.0).has(String(a)), "nobody calls on themselves")


func test_without_axes_nobody_is_a_friend() -> void:
	assert_eq(Look.friends("medtech", {}, 1.0), [])
	assert_eq(Look.friends("strangers", rules["ideo"], 6.0), [])


func test_a_car_calls_at_the_cars_of_its_friends_only() -> void:
	var cars: Array = rules["cars"]
	var ideo: Dictionary = rules["ideo"]
	assert_eq(Look.calls_for(_car("medtech"), cars, ideo, 1.0), ["front"])
	assert_eq(Look.calls_for(_car("front"), cars, ideo, 1.0), ["medtech"])
	assert_eq(Look.calls_for(_car("tail1"), cars, ideo, 1.0), [])
	assert_eq(Look.calls_for(_car("dining"), cars, ideo, 6.0), [], "no community, no calls")
	var two_tails: Array = cars.duplicate(true)
	two_tails.append({"id": "tail2", "kind": "comm", "comm": "tail"})
	assert_false(Look.calls_for(_car("tail1"), two_tails, ideo, 6.0).has("tail2"), "its own people's other car is not a call")
	assert_false(Look.calls_for(_car("tail1"), two_tails, ideo, 6.0).has("dining"))


func test_nobody_calls_in_a_frightened_car_or_during_the_session() -> void:
	for m in MOODS:
		assert_eq(Look.calls_open(m, "travel"), m != "frozen", m)
		assert_false(Look.calls_open(m, "council"), m)


# ---------------------------------------------------------------- the council

func test_the_unrest_score_adds_tension_the_opposed_and_those_set_against_the_captain() -> void:
	assert_eq(Look.unrest_score(rules["train"], rules["comms"]), 20.0, "the start: tension alone")
	var comms: Dictionary = rules["comms"].duplicate(true)
	comms["tail"]["rel"] = -40
	comms["guard"]["rel"] = -39
	assert_eq(Look.unrest_score(_train(20.0, 0.0), comms), 30.0, "one community opposed")
	comms["front"]["grudge"] = 2
	comms["engine"]["grudge"] = 1
	assert_eq(Look.unrest_score(_train(20.0, 0.0), comms), 45.0, "and one with two grudges")
	comms["tail"]["grudge"] = 3
	assert_eq(Look.unrest_score(_train(20.0, 0.0), comms), 60.0, "opposed and set against: both count")
	assert_eq(Look.unrest_score(_train(20.0, 90.0), comms), 60.0, "fear is not in the score")
	assert_eq(Look.unrest_score({}, {}), 0.0)


func test_unrest_climbs_a_step_at_each_threshold() -> void:
	var edges: Array = [[0.0, 0], [19.9, 0], [20.0, 1], [39.9, 1], [40.0, 2], [59.9, 2], [60.0, 3], [79.9, 3], [80.0, 4], [250.0, 4]]
	for edge in edges:
		assert_eq(Look.unrest_level(float(edge[0])), int(edge[1]), "score %s" % edge[0])
		assert_eq(Look.unrest_level(float(edge[0]), 0), int(edge[1]), "from the lowest step, score %s" % edge[0])
	assert_eq(Look.UNREST_NAMES.size(), 5)
	assert_eq(Look.UNREST_LOOK.size(), 5)


func test_unrest_settles_only_five_under_a_threshold() -> void:
	assert_eq(Look.unrest_level(15.0, 1), 1, "15 holds the second step")
	assert_eq(Look.unrest_level(14.9, 1), 0)
	assert_eq(Look.unrest_level(75.0, 4), 4)
	assert_eq(Look.unrest_level(74.9, 4), 3)
	assert_eq(Look.unrest_level(36.0, 3), 2, "falls past a step it is well under and holds the next")
	assert_eq(Look.unrest_level(10.0, 4), 0)
	assert_eq(Look.unrest_level(17.0, 0), 0, "holding is for the way down only")
	assert_eq(Look.unrest_level(90.0, 9), 4, "a step nobody knows")


func test_the_called_vote_and_fear_quiet_the_council() -> void:
	assert_eq(Look.council_quiet(_train(90.0, 0.0)), "")
	assert_eq(Look.council_quiet(_train(90.0, 59.9)), "")
	assert_eq(Look.council_quiet(_train(90.0, 60.0)), "hush")
	var voting := _train(90.0, 0.0)
	voting["voting"] = true
	assert_eq(Look.council_quiet(voting), "vote")
	voting["fear"] = 80.0
	assert_eq(Look.council_quiet(voting), "vote")
	for quiet in ["vote", "hush"]:
		assert_true(Look.QUIET_NAMES.has(quiet), quiet)


func test_the_council_room_has_a_place_for_everyone() -> void:
	var places: Array = Look.council_places(Look.DINING_SESSION)
	assert_eq(places.size(), 32)
	assert_eq(places.count("chair"), 2)
	assert_eq(places.count("walk"), 2)
	assert_eq(places.count("door"), 2)
	assert_eq(places.count("bench"), Look.COUNCIL_BENCH)
	assert_eq(places.count("table"), Look.COUNCIL_TABLE)
	for count in range(45):
		var rows: Array = Look.council_places(count)
		assert_eq(rows.size(), count)
		assert_lte(rows.count("bench"), Look.COUNCIL_BENCH, "%d people" % count)
		assert_lte(rows.count("table"), Look.COUNCIL_TABLE, "%d people" % count)
		if count > 0 and count <= 32:
			assert_eq(Look.council_places(count - 1), rows.slice(0, count - 1), "one more person moves nobody")


func test_more_of_the_seated_act_and_rise_as_unrest_climbs() -> void:
	var seats: int = Look.COUNCIL_BENCH + Look.COUNCIL_TABLE
	var before := {"lean": 0, "rise": 0}
	for level in 5:
		var now := {"": 0, "lean": 0, "rise": 0}
		for seat in seats:
			var role: String = Look.council_role(seat, seats, level)
			now[role] += 1
			if level > 0 and Look.council_role(seat, seats, level - 1) != "":
				assert_ne(role, "", "seat %d keeps acting at step %d" % [seat, level])
		var look: Dictionary = Look.UNREST_LOOK[level]
		assert_eq(now["rise"], int(look["rise"]), "step %d" % level)
		assert_eq(now["lean"] + now["rise"], int(look["act"]), "step %d" % level)
		assert_gte(int(now["rise"]), int(before["rise"]))
		assert_gt(now["lean"] + now["rise"], before["lean"] + before["rise"])
		# With the two who walk and the two by the door: the brief's eight to twelve.
		assert_between(now["lean"] + now["rise"] + 4, 8, 12, "step %d" % level)
		before = now
	assert_eq(Look.council_role(0, seats, 0), "lean")
	assert_eq(Look.council_role(-1, seats, 4), "", "not a seat")


func test_every_seat_has_its_own_rank_whatever_the_number_of_seats() -> void:
	for seats in range(1, 41):
		var acting := 0
		for seat in seats:
			acting += 1 if Look.council_role(seat, seats, 4) != "" else 0
		assert_eq(acting, mini(seats, int(Look.UNREST_LOOK[4]["act"])), "%d seats" % seats)


func test_nobody_rises_in_the_two_quiet_steps() -> void:
	var seats: int = Look.COUNCIL_BENCH + Look.COUNCIL_TABLE
	for level in [0, 1]:
		for seat in seats:
			assert_ne(Look.council_role(seat, seats, level), "rise", "step %d, seat %d" % [level, seat])


# ---------------------------------------------------------------- trips

func test_a_car_without_a_community_sends_nobody() -> void:
	var errands: Array = rules["errands"]
	assert_eq(Look.errands_for(_car("dining"), "council", errands), [])
	assert_eq(Look.errands_for(_car("captain"), "travel", errands), [])


func test_no_trip_goes_to_the_car_it_leaves() -> void:
	var errands: Array = rules["errands"]
	var rows: Array = Look.errands_for(_car("medtech"), "council", errands)
	assert_false(_ids(rows).has("sick"), "the infirmary is its own car")
	assert_true(_ids(Look.errands_for(_car("front"), "travel", errands)).has("sick"))


func test_only_trips_of_the_phase_remain() -> void:
	var errands: Array = rules["errands"]
	var travel: Array = _ids(Look.errands_for(_car("front"), "travel", errands))
	var council: Array = _ids(Look.errands_for(_car("front"), "council", errands))
	assert_false(travel.has("council"), "no session while travelling")
	assert_true(travel.has("meal"))
	assert_true(council.has("council"), "the session calls people")
	assert_true(council.has("meal"))


# ---------------------------------------------------------------- the gestures of a bad value

func test_a_stirred_car_gestures_for_tension_from_sixty() -> void:
	assert_eq(Look.gesture_for("stir", {"tension": 60.0}), "tension")
	assert_eq(Look.gesture_for("stir", {"tension": 59.0}), "resent")


func test_a_car_that_is_not_stirred_has_no_gesture_even_at_ninety() -> void:
	for m in ["calm", "low", "frozen"]:
		assert_eq(Look.gesture_for(m, {"tension": 90.0}), "", m)


func test_a_stirred_car_on_a_train_without_tension_resents() -> void:
	assert_eq(Look.gesture_for("stir", {}), "resent")


func test_fear_comes_before_the_gestures() -> void:
	var train := {"tension": 90.0, "fear": 60.0}
	var m := Look.mood({}, train)
	assert_eq(m, "frozen")
	assert_eq(Look.gesture_for(m, train), "")


func test_a_car_stirred_only_by_its_own_grudge_resents() -> void:
	var train := {"tension": 20.0, "fear": 0.0}
	var m := Look.mood({"rel": -50, "sit": [60, 60, 40, 40]}, train)
	assert_eq(m, "stir")
	assert_eq(Look.gesture_for(m, train), "resent")


func test_the_first_knot_quarrels_two_and_the_third_looks_about() -> void:
	var rows := Look.knot_gestures("tension", 3, 0)
	assert_eq(rows.size(), 3)
	assert_eq(rows[0]["name"], Gesture.ARGUE)
	assert_eq(rows[1]["name"], Gesture.ARGUE)
	assert_eq(rows[0]["role"], 0)
	assert_eq(rows[1]["role"], 1)
	assert_eq(rows[2]["name"], Gesture.TURN_ABOUT)


func test_an_odd_car_whispers_where_an_even_one_quarrels() -> void:
	var odd := Look.knot_gestures("tension", 3, 1)
	assert_eq(odd[0]["name"], Gesture.WHISPER)
	assert_eq(odd[1]["name"], Gesture.WHISPER)
	assert_eq(Look.knot_gestures("tension", 3, 2)[0]["name"], Gesture.ARGUE)


func test_two_standers_are_a_pair_and_one_alone_keeps_still() -> void:
	var two := Look.knot_gestures("tension", 2, 0)
	assert_eq(two.size(), 2)
	assert_eq(two[0]["name"], Gesture.ARGUE)
	assert_eq(two[1]["name"], Gesture.ARGUE)
	var one := Look.knot_gestures("tension", 1, 0)
	assert_eq(one.size(), 1)
	assert_eq(one[0]["name"], "", "nobody quarrels alone")
	assert_eq(Look.knot_gestures("tension", 0, 0), [])


func test_only_the_first_knot_acts() -> void:
	var rows := Look.knot_gestures("tension", 5, 0)
	assert_eq(rows[3]["name"], "")
	assert_eq(rows[4]["name"], "")


func test_there_is_a_row_a_stander() -> void:
	for standing in range(8):
		assert_eq(Look.knot_gestures("tension", standing, 0).size(), standing, "%d standing" % standing)


func test_no_value_or_an_unknown_one_gives_no_gesture() -> void:
	for value in ["", "nonsense"]:
		for row in Look.knot_gestures(value, 5, 0):
			assert_eq(row["name"], "", "value '%s'" % value)


func test_a_pair_is_never_made_by_halves() -> void:
	for standing in range(8):
		for car_index in range(4):
			var roles: Array = []
			for row in Look.knot_gestures("tension", standing, car_index):
				if row["name"] == Gesture.ARGUE or row["name"] == Gesture.WHISPER:
					roles.append(row["role"])
			var label := "%d standing, car %d" % [standing, car_index]
			if not roles.is_empty():
				assert_eq(roles, [0, 1], label)


# ---------------------------------------------------------------- the gestures of resentment

func _resent_names(standing: int, car_index: int = 0) -> Array:
	var names: Array = []
	for row in Look.knot_gestures("resent", standing, car_index):
		names.append(row["name"])
	return names


func test_tension_comes_before_resentment_in_a_car_stirred_by_both() -> void:
	var train := {"tension": 70.0, "fear": 0.0}
	var m := Look.mood({"rel": -50, "sit": [60, 60, 40, 40]}, train)
	assert_eq(m, "stir")
	assert_eq(Look.gesture_for(m, train), "tension")


func test_a_grudge_alone_is_resentment() -> void:
	var train := {"tension": 20.0, "fear": 0.0}
	var m := Look.mood({"rel": 0, "grudge": 2, "sit": [60, 60, 40, 40]}, train)
	assert_eq(m, "stir")
	assert_eq(Look.gesture_for(m, train), "resent")


func test_fear_comes_before_resentment() -> void:
	var train := {"tension": 20.0, "fear": 60.0}
	var m := Look.mood({"rel": -50, "sit": [60, 60, 40, 40]}, train)
	assert_eq(m, "frozen")
	assert_eq(Look.gesture_for(m, train), "")


func test_three_resentful_standers_fold_their_arms_but_the_second_turns_its_back() -> void:
	var rows := Look.knot_gestures("resent", 3, 0)
	assert_eq(rows.size(), 3)
	assert_eq(rows[0]["name"], Gesture.ARMS_CROSSED)
	assert_eq(rows[1]["name"], Gesture.BACK_TURNED)
	assert_eq(rows[2]["name"], Gesture.ARMS_CROSSED)
	assert_eq(rows[0]["role"], 0)
	assert_eq(rows[1]["role"], 1)
	assert_eq(rows[2]["role"], 2)


func test_one_resentful_stander_alone_still_folds_its_arms() -> void:
	var one := Look.knot_gestures("resent", 1, 0)
	assert_eq(one.size(), 1)
	assert_eq(one[0]["name"], Gesture.ARMS_CROSSED)
	assert_eq(one[0]["role"], 0)
	assert_eq(_resent_names(2), [Gesture.ARMS_CROSSED, Gesture.BACK_TURNED])
	assert_eq(Look.knot_gestures("resent", 0, 0), [])


func test_only_the_first_knot_resents() -> void:
	var rows := Look.knot_gestures("resent", 5, 0)
	for k in [3, 4]:
		assert_eq(rows[k]["name"], "", "stander %d" % k)
		assert_eq(rows[k]["role"], 0, "stander %d" % k)


func test_there_is_a_row_a_stander_in_resentment_too() -> void:
	for standing in range(8):
		assert_eq(Look.knot_gestures("resent", standing, 0).size(), standing, "%d standing" % standing)


func test_resentment_does_not_depend_on_the_car() -> void:
	var first := _resent_names(3, 0)
	for car_index in range(4):
		assert_eq(_resent_names(3, car_index), first, "car %d" % car_index)


func test_resentment_gives_none_of_the_gestures_of_tension() -> void:
	for standing in range(8):
		for name in _resent_names(standing):
			assert_false([Gesture.ARGUE, Gesture.WHISPER, Gesture.TURN_ABOUT].has(name), "%d standing: %s" % [standing, name])


func test_at_most_one_turns_its_back() -> void:
	for standing in range(8):
		var backs := _resent_names(standing).filter(func(n) -> bool: return n == Gesture.BACK_TURNED)
		assert_lte(backs.size(), 1, "%d standing" % standing)
