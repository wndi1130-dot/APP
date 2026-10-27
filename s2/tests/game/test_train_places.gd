extends "res://addons/gut/test.gd"

const Catalog = preload("res://game/train/train_catalog.gd")
const Places = preload("res://game/train/train_places.gd")
const Context = preload("res://game/train/train_context.gd")
const Rules = preload("res://game/train/train_rules.gd")
const Schedule = preload("res://game/train/train_schedule.gd")
const LifeInput = preload("res://game/train/train_life_input.gd")


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


func test_registering_a_car_again_releases_only_its_old_bookings() -> void:
	var p = _pool()
	p.add_car({"id": "away", "kind": "comm", "comm": "tail"}, 32.0)
	p.refresh({"home": {"social": true}, "away": {"social": true}})
	assert_true(p.reserve(1, "home/door_tail"))
	assert_true(p.reserve(2, "home/door_tail"))
	assert_true(p.reserve(3, "away/door_tail"))
	p.arrive(1)
	p.arrive(3)
	var before: Vector3 = p.target(1)
	var other: Dictionary = p.spots["away/door_tail"]["members"].duplicate(true)
	p.add_car({"id": "home", "kind": "comm", "comm": "tail"}, 16.0)
	assert_eq(p.bookings, {3: "away/door_tail"})
	assert_eq(p.spots["away/door_tail"]["members"], other)
	for spot in p.spots.values():
		if spot["car"] == "home":
			assert_true(spot["members"].is_empty(), spot["id"])
	if p.bookings.has(1) or p.bookings.has(2):
		return
	assert_true(p.reserve(1, "home/door_tail"))
	assert_eq(p.target(1), before + Vector3(16, 0, 0))
	assert_true(p.arrive(1))
	assert_eq(p.present("home/door_tail"), 1)


func test_registering_another_layout_removes_old_spots_and_their_bookings() -> void:
	var p = _pool()
	p.add_car({"id": "away", "kind": "comm", "comm": "tail"}, 32.0)
	p.refresh({"home": {"social": true}, "away": {"social": true}})
	assert_true(p.reserve(1, "home/door_tail"))
	assert_true(p.reserve(3, "away/door_tail"))
	p.arrive(1)
	p.arrive(3)
	var old_spots: Array = p.spots.keys().filter(func(id): return p.spots[id]["car"] == "home")
	var other: Dictionary = p.spots["away/door_tail"]["members"].duplicate(true)
	p.add_car({"id": "home", "kind": "comm", "interior": "freight"}, 0.0)
	for id in old_spots:
		assert_false(p.spots.has(id), id)
	assert_eq(p.bookings, {3: "away/door_tail"})
	assert_eq(p.spots["away/door_tail"]["members"], other)
	assert_false(p.reserve(1, "home/door_tail"))


func test_refresh_releases_bookings_for_a_removed_car_even_when_always_open() -> void:
	var p = _pool()
	p.add_car({"id": "away", "kind": "comm", "comm": "tail"}, 32.0)
	p.spots["home/door_tail"]["when"] = "always"
	p.refresh({"home": {"social": true}, "away": {"social": true}})
	assert_true(p.reserve(1, "home/door_tail"))
	assert_true(p.reserve(2, "home/door_tail"))
	assert_true(p.reserve(3, "away/door_tail"))
	p.arrive(1)
	p.arrive(3)
	var other: Dictionary = p.spots["away/door_tail"]["members"].duplicate(true)
	var released: Array = p.refresh({"away": {"social": true}})
	released.sort()
	assert_eq(released, [1, 2])
	assert_eq(p.bookings, {3: "away/door_tail"})
	assert_eq(p.spots["away/door_tail"]["members"], other)
	for spot in p.spots.values():
		if spot["car"] == "home":
			assert_false(spot["enabled"], spot["id"])
			assert_false(spot["open"], spot["id"])
			assert_true(spot["members"].is_empty(), spot["id"])
	p.advance(float(p.spots["home/stove_side"]["cycle"][0]))
	assert_false(p.spots["home/door_tail"]["open"])
	assert_false(p.reserve(4, "home/door_tail"))


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


func test_storage_has_no_living_places_and_the_cold_car_keeps_no_food() -> void:
	for id in ["freight", "tender", "cold", "loco"]:
		assert_true(Catalog.data()["layouts"][id]["storage_only"])
		assert_eq(Catalog.data()["layouts"][id]["spots"], [])
	var props: Array = Catalog.data()["layouts"]["cold"]["props"]
	var rear: Dictionary = props.filter(func(p): return p["id"] == "rear_platform")[0]
	assert_gt(float(rear["at"][0]) - float(rear["size"][0]) * .5, 8.0)
	# No food where the dead are laid (user 2026-10-25): the food is in the store car.
	assert_eq(props.filter(func(p): return String(p.get("when", "")) == "food" or String(p["model"]) == "food_crates").size(), 0)
	# Nothing there reads as a laid-out body: no blanket spread flat, only folded ones stacked.
	assert_eq(props.filter(func(p): return String(p["model"]) == "blanket").size(), 0)
	assert_gt(props.filter(func(p): return String(p["model"]) == "blanket_stack").size(), 0)
	# Until the dead are kept there it is only a cold store: the memorial shows with them.
	for memorial in props.filter(func(p): return String(p["model"]) == "memorial_board"):
		assert_eq(String(memorial.get("when", "")), "stored")
	var store: Array = Catalog.data()["layouts"]["freight"]["props"]
	assert_eq(store.filter(func(p): return String(p["model"]) == "food_crates").size(), 1)
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
	var c := Context.read(r, _car(r, "medtech"))
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


## The default formation's car `id` (S1's order, so not by its place in the list).
func _car(r: Dictionary, id: String) -> Dictionary:
	for c: Dictionary in r["cars"]:
		if String(c["id"]) == id:
			return c
	return {}


func test_laws_close_dining_for_session_and_reopen_education_afterwards() -> void:
	var r := Rules.load_default()
	r["train"]["passed"] = {"edu_letters": 1, "child_pack": 2}
	var c := Context.read(r, _car(r, "dining"))
	assert_true(c["classroom"])
	assert_true(c["half_class"])
	r["train"]["phase"] = "council"
	c = Context.read(r, _car(r, "dining"))
	assert_false(c["classroom"])
	assert_false(c["meal"])
	assert_eq(Schedule.main_state(c, {}), "session")


func test_invalid_optional_input_is_rejected_before_it_reaches_a_scene() -> void:
	for path_value in [["train.food", -1], ["view.daytime", "unknown"], ["view.fire_cars", ["missing"]],
		["view.collapse_override", 2.5], ["view.collapse_by_car", {"tail1": 9}], ["dom.parts", "many"], ["view.actors", []]]:
		var r := Rules.load_default()
		Catalog.assign_value(r, path_value[0], path_value[1])
		assert_false(Rules.check(r).is_empty(), path_value[0])


func test_life_input_checks_context_objects_without_requiring_optional_fields() -> void:
	assert_true(LifeInput.check({}, []).is_empty())
	assert_true(LifeInput.check({"train": {}, "comms": {"tail": {}}, "view": {}, "dom": {}, "stop": {}}, []).is_empty())
	var defaults := Rules.load_default()
	var car_ids: Array = defaults["cars"].map(func(car): return car["id"])
	assert_true(LifeInput.check(defaults, car_ids).is_empty())
	for value in [null, false, 1, "invalid", []]:
		for path in ["train", "comms", "view", "dom", "stop"]:
			var r: Dictionary = {}
			r[path] = value
			assert_false(LifeInput.check(r, []).is_empty(), path)
		assert_false(LifeInput.check({"comms": {"tail": value}}, []).is_empty(), "comms.tail")


func test_life_input_rejects_nonfinite_and_wrongly_typed_context_numbers() -> void:
	for value in [null, false, true, "1", [], {}, INF, -INF, NAN]:
		for key in ["coal", "food", "med", "lux", "hunger", "injured", "sickCount", "stored", "decreeLeft", "seg", "fear", "tension", "trust"]:
			var train: Dictionary = {}
			train[key] = value
			assert_false(LifeInput.check({"train": train}, []).is_empty(), "train." + key)
		for key in ["rel", "grudge"]:
			var comm: Dictionary = {}
			comm[key] = value
			assert_false(LifeInput.check({"comms": {"tail": comm}}, []).is_empty(), "comms.tail." + key)
	assert_true(LifeInput.check({"train": {"fear": -1.0, "tension": 1000001.0, "trust": 0.5},
		"comms": {"tail": {"rel": -90.0, "grudge": 0.5}}}, []).is_empty(), "finite values add no new display bands")


func test_life_input_requires_at_least_four_finite_situation_values() -> void:
	for value in [null, false, 1, "cold", {}, [], [70], [70, 70], [70, 70, 0]]:
		assert_false(LifeInput.check({"comms": {"tail": {"sit": value}}}, []).is_empty(), "comms.tail.sit")
	for i in 4:
		for value in [null, false, "70", [], {}, INF, -INF, NAN]:
			var sit: Array = [70, 70, 0, 0]
			sit[i] = value
			assert_false(LifeInput.check({"comms": {"tail": {"sit": sit}}}, []).is_empty(), "sit[%d]" % i)
	for sit in [[70, 70, 0, 0], [-1.0, 1000001.0, 0.5, -0.5, 7]]:
		assert_true(LifeInput.check({"comms": {"tail": {"sit": sit}}}, []).is_empty(), "no new range or exact length")


func test_life_input_checks_context_flags_and_labels() -> void:
	var source := {"train": {"phase": "", "voting": false, "council": {"martial": false}, "edu": {"side": ""}},
		"view": {"region": "", "country": ""}, "dom": {"insulated": []}, "stop": {"weather": ""}}
	assert_true(LifeInput.check(source, ["home"]).is_empty())
	for path_value in [["train.phase", 1], ["train.voting", "false"], ["train.council.martial", 0],
		["train.edu.side", []], ["view.region", {}], ["view.country", null],
		["dom.insulated", [false]], ["stop.weather", 0]]:
		var r: Dictionary = source.duplicate(true)
		Catalog.assign_value(r, path_value[0], path_value[1])
		assert_false(LifeInput.check(r, ["home"]).is_empty(), path_value[0])


func test_life_input_checks_actor_trait_types_and_string_indices() -> void:
	assert_true(LifeInput.check({"view": {"actors": {"home": {"0": {}}}}}, ["home"]).is_empty())
	for key in ["child", "injured", "sick", "mourning"]:
		for value in [null, 0, "false", [], {}]:
			var traits: Dictionary = {}
			traits[key] = value
			assert_false(LifeInput.check({"view": {"actors": {"home": {"0": traits}}}}, ["home"]).is_empty(), key)
	for value in [null, false, 1, [], {}]:
		assert_false(LifeInput.check({"view": {"actors": {"home": {"0": {"role": value}}}}}, ["home"]).is_empty(), "role")
	assert_false(LifeInput.check({"view": {"actors": {"home": {0: {}}}}}, ["home"]).is_empty(), "Life reads str(i) keys")
	assert_true(LifeInput.check({"view": {"actors": {"home": {"0": {"child": false, "injured": true,
		"sick": false, "mourning": true, "role": "teacher"}}}}}, ["home"]).is_empty())


func test_life_input_checks_car_context_field_types() -> void:
	assert_true(LifeInput.check({"cars": [{"id": "home"}]}, ["home"]).is_empty())
	for value in [null, false, 1, "car", {}]:
		assert_false(LifeInput.check({"cars": value}, ["home"]).is_empty(), "cars")
	for value in [null, false, 1, "car", []]:
		assert_false(LifeInput.check({"cars": [value]}, ["home"]).is_empty(), "car object")
	for key_value in [["id", 1], ["kind", false], ["comm", []], ["expanded", "false"], ["interior", {}]]:
		var car: Dictionary = {"id": "home", "kind": "comm", "comm": "tail"}
		car[key_value[0]] = key_value[1]
		assert_false(LifeInput.check({"cars": [car]}, ["home"]).is_empty(), key_value[0])


## The engine car's people live in their own car by the engine (S1 편성, 결정카드 domestic Q2):
## a living layout with bunks and a place to shovel at the front end, not the coal-only tender.
func test_the_engine_room_is_lived_in() -> void:
	var row: Dictionary = Catalog.data()["layouts"]["engine_room"]
	assert_false(bool(row.get("storage_only", false)))
	var acts: Array = (row["spots"] as Array).map(func(s): return String(s["activity"]))
	for a in ["rest", "sleep", "warm", "work"]:
		assert_has(acts, a)
	assert_eq(Catalog.layout_id({"id": "engine", "kind": "comm", "comm": "engine", "interior": "engine_room"}), "engine_room")
