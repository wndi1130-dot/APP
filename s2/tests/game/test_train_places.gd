extends "res://addons/gut/test.gd"

const Catalog = preload("res://game/train/train_catalog.gd")
const Places = preload("res://game/train/train_places.gd")
const Context = preload("res://game/train/train_context.gd")
const Rules = preload("res://game/train/train_rules.gd")
const Schedule = preload("res://game/train/train_schedule.gd")


func _pool():
	var p = Places.new()
	p.add_car({"id": "home", "kind": "comm", "comm": "tail"}, 0)
	p.refresh({"home": {"social": true, "stove": true, "safe": true}})
	return p


func test_arriving_people_take_capacity_before_they_get_there() -> void:
	var p = _pool()
	assert_true(p.reserve(1, "home/door_tail"))
	assert_true(p.reserve(2, "home/door_tail"))
	assert_false(p.reserve(3, "home/door_tail"))
	assert_eq(p.approaching("home/door_tail"), 2)
	assert_true(p.reserve(1, "home/door_tail"))
	assert_eq(p.approaching("home/door_tail"), 2, "repeated request has one booking")
	var first: Vector3 = p.target(1)
	assert_ne(first, p.target(2))
	p.arrive(1)
	assert_eq(p.present("home/door_tail"), 1)
	assert_eq(p.approaching("home/door_tail"), 1)
	p.release(1)
	assert_true(p.reserve(3, "home/door_tail"))
	assert_eq(first, p.target(3))


func test_closing_a_place_releases_present_and_incoming_people() -> void:
	var p = _pool()
	p.reserve(1, "home/door_tail")
	p.reserve(2, "home/door_tail")
	p.arrive(1)
	assert_eq(p.refresh({"home": {"social": false}}).size(), 2)
	assert_eq(p.bookings.size(), 0)
	assert_false(p.reserve(3, "home/door_tail"))
	p.refresh({"home": {"social": true}})
	assert_true(p.reserve(3, "home/door_tail"))


func test_place_timer_closes_and_reopens_without_a_rule_change() -> void:
	var p = _pool()
	var cycle: Array = p.spots["home/stove_side"]["cycle"]
	p.reserve(1, "home/stove_side")
	assert_eq(p.advance(float(cycle[0])), [1])
	assert_false(p.spots["home/stove_side"]["open"])
	p.advance(float(cycle[1]))
	assert_true(p.spots["home/stove_side"]["open"])


func test_a_failed_group_invitation_preserves_old_bookings() -> void:
	var p = _pool()
	p.reserve(1, "home/stove_side")
	p.arrive(1)
	var before: Dictionary = p.bookings.duplicate(true)
	assert_false(p.reserve_group([1, 2, 3], "home/door_tail"))
	assert_eq(p.bookings, before)
	assert_eq(p.present("home/stove_side"), 1)
	assert_eq(p.approaching("home/door_tail"), 0)


func test_two_different_activities_cannot_reserve_the_same_physical_anchor() -> void:
	var p = _pool()
	p.spots["home/door_front"]["anchors"][0] = p.spots["home/door_tail"]["anchors"][0]
	p.spots["home/door_front"]["capacity"] = 1
	assert_true(p.reserve(1, "home/door_tail"))
	assert_false(p.reserve(2, "home/door_front"))


func test_all_layouts_have_unique_names_bounded_props_and_valid_activities() -> void:
	var data: Dictionary = Catalog.data()
	for id in data["layouts"]:
		var row: Dictionary = data["layouts"][id]
		var names: Array = []
		for prop in row["props"]:
			assert_false(names.has(prop["id"]), id)
			names.append(prop["id"])
			assert_true(String(prop["model"]).is_valid_identifier())
			var at: Vector3 = Catalog.vector(prop["at"])
			var size: Vector3 = Catalog.vector(prop["size"])
			assert_gte(at.x - size.x * 0.5, 0.0, id)
			assert_lte(at.x + size.x * 0.5, 16.0, id)
			assert_lte(absf(at.z) + size.z * 0.5, 1.4, id)
		for spot in row["spots"]:
			assert_eq(int(spot["capacity"]), spot["anchors"].size(), id)
			assert_true(data["activities"].has(spot["activity"]))
			for anchor in spot["anchors"]:
				assert_between(float(anchor[0]), 0.3, 15.7)
				assert_between(float(anchor[2]), -1.1, 1.1)


func test_storage_has_no_living_places_and_cold_car_keeps_front_and_rear_apart() -> void:
	for id in ["freight", "tender", "cold", "loco"]:
		assert_true(Catalog.data()["layouts"][id]["storage_only"])
		assert_eq(Catalog.data()["layouts"][id]["spots"], [])
	var props: Array = Catalog.data()["layouts"]["cold"]["props"]
	var food: Dictionary = props.filter(func(p): return p["id"] == "food_front")[0]
	var rear: Dictionary = props.filter(func(p): return p["id"] == "rear_platform")[0]
	assert_lt(float(food["at"][0]) + float(food["size"][0]) * .5, 8.0)
	assert_gt(float(rear["at"][0]) - float(rear["size"][0]) * .5, 8.0)
	assert_false(Catalog.data()["layouts"].has("classroom"), "classroom is part of dining")


func test_medical_beds_and_half_open_curtain_are_furniture_not_locked_rooms() -> void:
	var props: Array = Catalog.data()["layouts"]["medical"]["props"]
	assert_eq(props.filter(func(p): return String(p["id"]).begins_with("bed_")).size(), 6)
	var curtain: Dictionary = props.filter(func(p): return p["id"] == "care_curtain")[0]
	assert_lt(float(curtain["size"][0]), 1.0)
	assert_lt(float(curtain["at"][2]) + float(curtain["size"][2]), .2, "curtain leaves the aisle open")


func test_context_is_a_snapshot_and_resource_gates_do_not_spend_anything() -> void:
	var r := Rules.load_default()
	r["train"]["coal"] = 0
	r["train"]["food"] = 0
	r["train"]["med"] = 0
	r["train"]["injured"] = 2
	var before := r.duplicate(true)
	var c := Context.read(r, r["cars"][1])
	assert_false(c["stove"])
	assert_false(c["meal"])
	assert_false(c["medicine"])
	assert_true(c["patients"], "care is still allowed without medicine")
	assert_eq(r, before)


func test_preferences_keep_layers_and_filter_children_and_injured_people() -> void:
	var r := Rules.load_default()
	r["view"]["work_time"] = true
	r["view"]["collapse_override"] = 4
	var c := Context.read(r, r["cars"][0])
	assert_false(Schedule.preferences(c, {"child": true}).has("gather"))
	assert_false(Schedule.preferences(c, {"injured": true}).has("gather"))
	assert_true(Schedule.preferences(c, {}).has("gather"))
	assert_eq(Catalog.data()["preferences"].map(func(p): return p["layer"]), ["shared", "work", "idle", "needs", "sleep"])
	r["view"]["collapse_override"] = -1
	r["view"]["daytime"] = "night"
	c = Context.read(r, r["cars"][0])
	assert_eq(Schedule.main_state(c, {}), "sleep")
	assert_eq(Schedule.main_state(c, {"injured": true}), "heal")


func test_laws_close_dining_for_session_and_reopen_education_afterwards() -> void:
	var r := Rules.load_default()
	r["train"]["passed"] = {"edu_letters": 1, "child_pack": 2}
	var c := Context.read(r, r["cars"][2])
	assert_true(c["classroom"])
	assert_true(c["half_class"])
	r["train"]["phase"] = "council"
	c = Context.read(r, r["cars"][2])
	assert_false(c["classroom"])
	assert_false(c["meal"])
	assert_eq(Schedule.main_state(c, {}), "session")


func test_invalid_optional_input_is_rejected_before_it_reaches_a_scene() -> void:
	for path_value in [["train.food", -1], ["view.daytime", "unknown"], ["view.fire_cars", ["missing"]],
		["view.collapse_override", 2.5], ["view.collapse_by_car", {"tail1": 9}], ["dom.parts", "many"], ["view.actors", []]]:
		var r := Rules.load_default()
		Catalog.assign_value(r, path_value[0], path_value[1])
		assert_false(Rules.check(r).is_empty(), path_value[0])
