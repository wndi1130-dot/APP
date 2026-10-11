extends "res://addons/gut/test.gd"
## What a train car shows for its numbers: the head count (the web prototype's
## figures()), the warmth and crowding steps, the one mood a car is in, who
## walks, stands about, sits, hunches, and which trips a car may send.

const Look = preload("res://game/train/train_look.gd")
const Rules = preload("res://game/train/train_rules.gd")

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
	assert_eq(Look.figures(dining, {}, "council"), 12)
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
