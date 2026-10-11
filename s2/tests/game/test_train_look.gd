extends "res://addons/gut/test.gd"
## What a train car shows for its numbers: the head count (the web prototype's
## figures()), the warmth and crowding steps, who walks, sits, hunches, and which
## trips a car may send.

const Look = preload("res://game/train/train_look.gd")
const Rules = preload("res://game/train/train_rules.gd")

const WARMTHS: Array = [0.0, 29.9, 30.0, 44.9, 45.0, 60.0, 70.0, 70.1, 100.0]
const CROWDS: Array = [0.0, 45.0, 59.9, 60.0, 79.9, 80.0, 94.9, 95.0, 100.0]

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


# ---------------------------------------------------------------- places and postures

func test_split_adds_up_and_hunches_only_the_seated() -> void:
	for count in range(17):
		for w in WARMTHS:
			for crowd in CROWDS:
				var s: Dictionary = Look.split(count, float(w), float(crowd))
				var label := "%d people, warmth %s, crowding %s" % [count, w, crowd]
				assert_eq(int(s["walk"]) + int(s["bench"]) + int(s["floor"]), count, label)
				assert_lte(int(s["huddled"]), int(s["bench"]) + int(s["floor"]), label)


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
	for count in range(17):
		for w in WARMTHS:
			for crowd in CROWDS:
				var rows: Array = Look.seating(count, float(w), float(crowd))
				var s: Dictionary = Look.split(count, float(w), float(crowd))
				var walk := 0
				var bench := 0
				var on_floor := 0
				var huddled := 0
				for r in rows:
					match String(r["pose"]):
						"walk":
							walk += 1
						"sit":
							bench += 1
						"floor":
							on_floor += 1
					huddled += 1 if bool(r["huddled"]) else 0
				var label := "%d people, warmth %s, crowding %s" % [count, w, crowd]
				assert_eq(rows.size(), count, label)
				assert_eq(walk, int(s["walk"]), label)
				assert_eq(bench, int(s["bench"]), label)
				assert_eq(on_floor, int(s["floor"]), label)
				assert_eq(huddled, int(s["huddled"]), label)


func test_those_who_walk_do_not_huddle() -> void:
	for count in range(17):
		for r in Look.seating(count, 5.0, 100.0):
			if r["pose"] == "walk":
				assert_false(bool(r["huddled"]), "%d people" % count)


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
