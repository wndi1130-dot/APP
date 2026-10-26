extends "res://addons/gut/test.gd"

const Scene = preload("res://game/train/train_scene.gd")
const Rules = preload("res://game/train/train_rules.gd")
const Catalog = preload("res://game/train/train_catalog.gd")
const Context = preload("res://game/train/train_context.gd")
const Body = preload("res://game/train/train_body.gd")
const SeasonTable = preload("res://game/season_table.gd")


func _scene(panel: bool = false):
	var s = Scene.new()
	s.rules = Rules.load_default()
	s.opts = {"seed": 7, "panel": panel}
	add_child_autofree(s)
	return s


func _advance(s, seconds: float) -> void:
	for i in int(seconds * 10):
		s.step(.1)


func _start_fire(s, car_id: String = "tail1") -> Array:
	s.rules["view"]["fire_cars"] = [car_id]
	s.life.refresh("fire")
	s.life._evacuate(s.car(car_id))
	return s.life.actors.values().filter(func(a): return a["home"] == car_id and a.get("evacuating", false))


func test_time_does_not_poll_big_states_or_mutate_input_values() -> void:
	var s = _scene()
	var events: int = s.life.event_count
	var before: Dictionary = s.rules.duplicate(true)
	_advance(s, 40)
	assert_eq(s.life.event_count, events, "no whole-state decision in a frame tick")
	assert_eq(s.rules, before, "display does not spend food, heal or change politics")
	assert_true(s.set_value("view.daytime", "night"))
	assert_gt(s.life.event_count, events)
	for a in s.life.actors.values():
		assert_eq(a["state"], "sleep")


func test_a_walker_reserves_a_named_activity_instead_of_only_random_pacing() -> void:
	var s = _scene()
	s.rules["errands"] = []
	s.rules.erase("calls")
	var saw_arrival := false
	var saw_reservation := false
	for i in 700:
		s.step(.1)
		saw_reservation = saw_reservation or not s.life.places.bookings.is_empty()
		for spot in s.life.places.spots.values():
			saw_arrival = saw_arrival or spot["members"].values().any(func(m): return m["phase"] == "present")
		for c in s.cars:
			assert_lte(s.life.moving_count(c["id"]), 4)
	assert_true(saw_reservation)
	assert_true(saw_arrival)


func test_coal_food_medicine_and_insulation_change_only_their_display() -> void:
	var s = _scene()
	assert_true(s.set_value("train.coal", 0))
	assert_eq(float(s.car("front")["stove_light"].light_energy), 0.0)
	assert_false(s.life.places.spots["front/stove_side"]["open"])
	assert_true(s.set_value("train.food", 0))
	assert_false(s.life.places.spots["dining/meal"]["open"])
	assert_false(s.life.rooms["dining"].props["bowls"].visible)
	assert_true(s.set_value("train.med", 0))
	assert_false(s.life.rooms["medtech"].props["medicine"].visible)
	assert_true(s.life.rooms["front"].props["goods"].visible)
	s.set_value("train.lux", 0)
	assert_false(s.life.rooms["front"].props["goods"].visible)
	s.set_value("train.injured", 2)
	assert_true(s.life.places.spots["medtech/care"]["open"])
	var patients: int = s.life.actors.values().filter(func(a): return a["traits"].get("aggregate_patient", false)).size()
	assert_eq(patients, 2)
	s.set_value("dom.insulated", ["tail1"])
	assert_true(s.life.rooms["tail1"].props["insulation"].visible)
	assert_eq(s.rules["comms"]["tail"]["sit"][0], 35.0, "insulation here does not compute warmth")


func test_the_season_comes_from_the_season_table_unless_set() -> void:
	var s = _scene()
	s.set_value("train.seg", 1)
	var route: Dictionary = s.life.outside.get_meta("route")
	assert_eq(String(route["season"]), SeasonTable.season_of_seg(1))
	assert_eq(String(route["season"]), "late_autumn", "the first leg is the prologue's late autumn")


func test_night_and_stop_change_lamps_and_route_metadata_stays_outside_politics() -> void:
	var s = _scene()
	var lamp: float = s.car("front")["lamp_energy"]
	s.set_value("view.daytime", "night")
	assert_lt(float(s.car("front")["lamp_energy"]), lamp)
	s.set_value("view.motion", "stopped")
	assert_eq(float(s.car("front")["lamp_sway"]), 0.0)
	s.set_value("train.seg", 9)
	s.set_value("view.region", "region_04")
	s.set_value("view.season", "early_thaw")
	s.set_value("stop.weather", "snow")
	var route: Dictionary = s.life.outside.get_meta("route").duplicate(true)
	s.set_comm("tail", "rel", -90)
	assert_eq(s.life.outside.get_meta("route"), route, "politics must not invent outside scenes")
	assert_eq(int(route["seg"]), 9)
	assert_eq(s.life.outside.get_child_count(), 3, "only the requested outside attachment points")


func test_interaction_runs_and_interrupt_releases_every_reserved_role() -> void:
	var s = _scene()
	assert_true(s.life.start_interaction("chat", "medtech"), s.life.last_failure)
	var pair = s.life.interactions["medtech"]
	var ids: Array = pair.members.map(func(m): return m["actor"])
	assert_eq(ids.size(), 2)
	assert_ne(s.life.places.target(ids[0]), s.life.places.target(ids[1]))
	_advance(s, 3)
	s.life_signal("interrupt", "medtech")
	_advance(s, 2)
	assert_false(s.life.interactions.has("medtech"))
	for id in ids:
		assert_false(s.life.places.bookings.has(id))
		assert_eq(s.life.actors[id]["interaction"], "")


func test_council_roles_are_seat_based_and_vote_holds_the_whole_room() -> void:
	var s = _scene()
	s.rules["errands"] = []
	s.set_train("phase", "council")
	assert_true(s.life.start_interaction("council", "dining"))
	var roles: Array = s.life.interactions["dining"].members.map(func(m): return [m["actor"], m["role"]])
	s.set_comm("tail", "grudge", 5)
	assert_true(s.life.start_interaction("council", "dining"))
	assert_eq(s.life.interactions["dining"].members.map(func(m): return [m["actor"], m["role"]]), roles)
	s.life_signal("bell", "dining")
	s.set_train("voting", true)
	var before: Array = s.car("dining")["bodies"].map(func(b): return [b.position, b.pose, b.rotation])
	_advance(s, 2)
	assert_eq(s.car("dining")["bodies"].map(func(b): return [b.position, b.pose, b.rotation]), before)


func test_classroom_roles_filter_children_out_of_fights() -> void:
	var s = _scene()
	s.set_value("train.passed", {"edu_letters": 1})
	s.set_value("view.actors", {"dining": {"1": {"child": true}, "2": {"child": true}, "3": {"child": true}}})
	assert_false(s.life.start_interaction("classroom", "dining"), "a cook cannot silently become the teacher")
	s.set_value("view.actors", {"dining": {"0": {"role": "teacher"}, "1": {"child": true}, "2": {"child": true}, "3": {"child": true}}})
	s.set_value("train.passed", {"edu_letters": 1})
	assert_true(s.life.start_interaction("classroom", "dining"), s.life.last_failure)
	assert_eq(s.life.interactions["dining"].members.filter(func(m): return m["role"] == "child").size(), 3)
	var lesson = s.life.interactions["dining"]
	for member in lesson.members:
		lesson.arrive(member["actor"])
	var clapping: Array = lesson.members.filter(func(m): return lesson.gesture(m["actor"]) == "child_clap_pair")
	assert_eq(clapping.size(), 2, "paired clapping always has two children")
	assert_eq(clapping.map(func(m): return lesson.role(m["actor"])), [0, 1])
	s.set_value("view.collapse_by_car", {"dining": 4})
	assert_false(s.life.start_interaction("push", "dining"))
	for a in s.life.actors.values():
		if a["traits"].get("child", false):
			assert_false(a["preferred"].has("gather"))


func test_care_assigns_a_healthy_carer_and_an_unwell_patient() -> void:
	var s = _scene()
	s.set_value("train.injured", 2)
	var started: bool = s.life.start_interaction("care", "medtech")
	assert_true(started, s.life.last_failure)
	if not s.life.interactions.has("medtech"):
		return
	for member in s.life.interactions["medtech"].members:
		var traits: Dictionary = s.life.actors[member["actor"]]["traits"]
		if member["role"] == "patient":
			assert_true(traits.get("injured", false) or traits.get("sick", false))
		else:
			assert_eq(traits.get("role", ""), "carer")
			assert_false(traits.get("injured", false) or traits.get("sick", false))


func test_memorial_event_selects_a_shared_activity_before_sleep() -> void:
	var s = _scene()
	s.set_value("view.daytime", "night")
	s.set_value("view.memorial", true)
	var c: Dictionary = s.car("dining")
	var b: Node3D = c["bodies"][0]
	for other in c["bodies"]:
		other.state = "seat"
	assert_eq(s.life.actors[b.get_instance_id()]["state"], "gather")
	assert_true(s.life.choose_local(c, b))
	assert_eq(s.life.actors[b.get_instance_id()]["activity"], "mourn")
	assert_eq(s.life.places.bookings[b.get_instance_id()], "dining/memorial")


func test_upper_bunk_has_a_real_reservation_and_a_bounded_sleep_fallback() -> void:
	var s = _scene()
	s.set_value("view.daytime", "night")
	var c: Dictionary = s.car("tail1")
	var b: Node3D = c["bodies"][0]
	var id: int = b.get_instance_id()
	assert_true(s.life.places.reserve(1, "tail1/bunk"))
	assert_true(s.life.places.reserve(2, "tail1/bunk"))
	assert_true(s.life.places.reserve(id, "tail1/bunk"))
	var target: Vector3 = s.life.places.target(id)
	assert_gt(target.y, 1.0)
	s.life.actors[id]["activity"] = "sleep"
	s.life._route(b, target)
	for i in 400:
		if s.life.walk(b, .1):
			break
	assert_eq(b.position, target)
	s.life.arrived(b)
	b.state = "wait"
	s.life.show_body(c, b)
	assert_eq(s.life.actors[id]["requested"], "lie_bunk")
	assert_eq(b.pose, "sit")
	assert_eq(b.idle_gesture, "")
	assert_lte(b.position.y + b.head_mesh.position.y + Body.HEAD_RADIUS, Scene.CAR_HEIGHT)


func test_collapse_is_display_only_and_never_infers_fire_from_tension() -> void:
	var r := Rules.load_default()
	var car: Dictionary = r["cars"][0]
	r["train"]["tension"] = 100
	var c := Context.read(r, car)
	assert_eq(int(c["stage"]), 3, "no invented riot or fire gameplay")
	assert_false(c["fire"])
	r["view"]["riot_stage"] = "riot"
	assert_eq(int(Context.read(r, car)["stage"]), 4)
	r["view"]["fire_cars"] = [car["id"]]
	assert_eq(int(Context.read(r, car)["stage"]), 5)
	for step in 7:
		r["view"]["collapse_by_car"] = {car["id"]: step}
		assert_eq(int(Context.read(r, car)["stage"]), step)


func test_fire_moves_bounded_groups_to_a_safe_adjacent_car_without_new_people() -> void:
	var s = _scene()
	var count_before: int = s.people.get_child_count()
	s.set_value("view.fire_cars", ["tail1"])
	var original: Dictionary = s.rules.duplicate(true)
	for i in 2600:
		s.step(.1)
		assert_lte(s.life.moving_count("tail1"), 4)
	assert_eq(s.people.get_child_count(), count_before)
	assert_eq(s.rules, original, "no fire spreading, damage, spending or death calculation")
	var evacuated: Array = s.life.actors.values().filter(func(a): return a["home"] == "tail1" and a["safe_arrival"])
	assert_eq(evacuated.size(), s.car("tail1")["bodies"].size())
	assert_true(s.life.rooms["tail1"].fire_mark.visible)
	assert_eq(int(s.car("tail1")["out"]), 0)


func test_overturned_props_stay_until_a_completed_cleanup_and_scorch_remains() -> void:
	var s = _scene()
	s.set_value("view.collapse_by_car", {"tail1": 5})
	var room = s.life.rooms["tail1"]
	assert_true(room.traces["sacks"]["overturned"])
	s.set_value("view.collapse_by_car", {"tail1": 6})
	assert_true(room.traces["sacks"]["overturned"])
	s.life_signal("cleanup", "tail1")
	assert_true(s.life.interactions.has("tail1"), s.life.last_failure)
	assert_true(room.traces["sacks"]["overturned"], "pressing the button alone does not clean")
	_advance(s, 50)
	assert_false(room.traces["sacks"]["overturned"])
	assert_true(room.traces["sacks"]["scorched"])


func test_all_car_types_can_be_built_without_putting_passengers_in_storage() -> void:
	var s = Scene.new()
	s.rules = Rules.load_default()
	s.rules["cars"] = []
	s.rules["errands"] = []
	s.rules.erase("calls")
	s.rules.erase("captain")
	for id in Catalog.data()["layouts"]:
		s.rules["cars"].append({"id": id, "kind": "comm", "interior": id, "name": id, "plate": id})
	s.opts = {"panel": false}
	add_child_autofree(s)
	assert_eq(s.problems.size(), 0)
	for c in s.cars:
		assert_true(s.life.rooms.has(c["id"]))
		if Catalog.data()["layouts"][c["id"]].get("storage_only", false):
			assert_eq(c["bodies"].size(), 0)


func test_expansion_uses_s1_car_ids_and_keeps_car_bound_traces() -> void:
	var s = _scene()
	s.set_value("view.collapse_by_car", {"tail1": 4})
	assert_true(s.life.rooms["tail1"].traces["sacks"]["overturned"])
	s.set_value("view.collapse_by_car", {"tail1": 0})
	assert_true(s.set_value("dom.extraCars", ["coach", "store"]))
	assert_eq(s.cars.size(), 8)
	assert_eq(Catalog.layout_id(s.car("coach1")["def"]), "coach")
	assert_eq(s.car("store2")["bodies"].size(), 0)
	assert_true(s.life.rooms["tail1"].traces["sacks"]["overturned"])
	assert_eq(s.rules["dom"]["extraCars"], ["coach", "store"])
	assert_true(s.set_value("dom.extraCars", []))
	assert_eq(s.cars.size(), 6)


func test_new_panel_controls_use_the_same_snapshot_and_can_be_folded() -> void:
	var s = _scene(true)
	var panel = s.panel.life_panel
	assert_false(panel.visible)
	s.panel._flip_life()
	assert_true(panel.visible)
	panel.controls["train.coal"].value = 0
	assert_eq(float(s.rules["train"]["coal"]), 0.0)
	panel.controls["view.work_time"].button_pressed = true
	assert_true(s.rules["view"]["work_time"])
	assert_true(s.set_value("train.passed", {"common_kitchen": 1, "contribution_ration": 1}))
	assert_true(s.life.rooms["dining"].props["ladle"].visible)
	assert_true(s.life.rooms["dining"].props["ration_note"].visible)
	assert_false(s.set_value("train.food", -1))


func test_placeholder_node_budget_adds_no_new_lights() -> void:
	var s = _scene()
	var nodes: Array = [s]
	var count := 0
	var lights := 0
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		count += 1
		lights += 1 if node is Light3D else 0
		nodes.append_array(node.get_children())
	assert_eq(lights, 1 + 2 * s.cars.size(), "sun plus each car's own lamp and stove (six cars with the workshop: 13)")
	print("TRAIN_NODE_BUDGET=" + JSON.stringify({"nodes": count, "lights": lights, "people": s.people.get_child_count(), "furniture_roots": s.life.rooms.size(), "outside_nodes": 4}))


func test_refresh_rejects_a_late_bad_sit_without_changing_the_snapshot() -> void:
	var s = _scene()
	s.rules["view"]["outside"] = {"passing": false}
	s.life.refresh("baseline")
	assert_true(s.life.start_interaction("chat", "medtech"), s.life.last_failure)
	var contexts: Dictionary = s.life.contexts.duplicate(true)
	var actors: Dictionary = s.life.actors.duplicate(true)
	var bookings: Dictionary = s.life.places.bookings.duplicate(true)
	var pair = s.life.interactions["medtech"]
	var lamp: float = s.car("front")["lamp_energy"]
	var goods: bool = s.life.rooms["front"].props["goods"].visible
	var events: int = s.life.event_count
	var event: String = s.life.last_event
	var route: Dictionary = s.life.outside.get_meta("route").duplicate(true)
	var sit: Array = s.rules["comms"]["tail"]["sit"].duplicate()
	s.rules["view"]["daytime"] = "night"
	s.rules["view"]["outside"]["passing"] = true
	s.rules["train"]["lux"] = 0
	s.rules["comms"]["tail"]["sit"] = [70]
	s.life.refresh("bad_snapshot")
	assert_eq(s.life.contexts, contexts)
	assert_eq(s.life.actors, actors)
	assert_eq(s.life.places.bookings, bookings)
	assert_eq(s.life.interactions["medtech"], pair)
	assert_eq(float(s.car("front")["lamp_energy"]), lamp)
	assert_eq(s.life.rooms["front"].props["goods"].visible, goods)
	assert_eq(s.life.event_count, events)
	assert_eq(s.life.last_event, event)
	assert_eq(s.life.outside.get_meta("route"), route)
	assert_ne(s.life.last_failure, "")
	s.rules["comms"]["tail"]["sit"] = sit
	s.life.refresh("valid_snapshot")
	assert_eq(s.life.event_count, events + 1)
	assert_eq(s.life.last_event, "valid_snapshot")
	for context in s.life.contexts.values():
		assert_true(context["night"])
	assert_false(s.life.rooms["front"].props["goods"].visible)


func test_refresh_prepares_every_body_before_applying_the_first_car() -> void:
	var s = _scene()
	var contexts: Dictionary = s.life.contexts.duplicate(true)
	var actors: Dictionary = s.life.actors.duplicate(true)
	var lamp: float = s.car("front")["lamp_energy"]
	var events: int = s.life.event_count
	var last: Dictionary = s.cars.back()
	last["bodies"].append(s.car("front")["bodies"][0])
	s.rules["view"]["daytime"] = "night"
	s.life.refresh("duplicate_body")
	last["bodies"].pop_back()
	assert_eq(s.life.contexts, contexts)
	assert_eq(s.life.actors, actors)
	assert_eq(float(s.car("front")["lamp_energy"]), lamp)
	assert_eq(s.life.event_count, events)
	assert_ne(s.life.last_failure, "")


func test_cancelled_evacuees_release_their_count_and_can_leave_again() -> void:
	var s = _scene()
	var movers := _start_fire(s)
	assert_gt(movers.size(), 0)
	for a in movers:
		var b: Node3D = a["body"]
		var id: int = b.get_instance_id()
		var at: Vector3 = b.position.lerp(s.life.places.target(id), .5)
		b.position = at
		s.life.cancel(id, "closed")
		assert_false(a.get("evacuating", false))
		assert_false(a["safe_arrival"])
		assert_false(s.life.places.bookings.has(id))
		assert_eq(b.position, at)
		assert_eq(b.state, "wait")
		assert_eq(a["waypoints"], [])
	s.life._evacuate(s.car("tail1"))
	for a in movers:
		assert_true(a.get("evacuating", false))
		assert_true(s.life.places.bookings.has(a["body"].get_instance_id()))
		assert_false(a.has("restore"))


func test_ending_an_evacuation_trip_allows_a_new_reservation() -> void:
	var s = _scene()
	var movers := _start_fire(s)
	assert_gt(movers.size(), 0)
	for a in movers:
		s.life.end_trip(a["body"])
		assert_false(a.get("evacuating", false))
		assert_false(a["safe_arrival"])
		assert_false(s.life.places.bookings.has(a["body"].get_instance_id()))
	s.life._evacuate(s.car("tail1"))
	for a in movers:
		assert_true(a.get("evacuating", false))
		assert_true(s.life.places.bookings.has(a["body"].get_instance_id()))


func test_a_closed_refuge_clears_evacuation_before_it_reopens() -> void:
	var s = _scene()
	var movers := _start_fire(s)
	assert_gt(movers.size(), 0)
	var fires: Array = ["tail1"]
	for a in movers:
		var spot: String = s.life.places.bookings[a["body"].get_instance_id()]
		var car_id: String = s.life.places.spots[spot]["car"]
		if not fires.has(car_id):
			fires.append(car_id)
	s.rules["view"]["fire_cars"] = fires
	s.life.refresh("refuge_closed")
	for a in movers:
		assert_false(a.get("evacuating", false))
		assert_false(s.life.places.bookings.has(a["body"].get_instance_id()))
	s.rules["view"]["fire_cars"] = ["tail1"]
	s.life.refresh("refuge_opened")
	s.life._evacuate(s.car("tail1"))
	for a in movers:
		assert_true(a.get("evacuating", false))
		assert_true(s.life.places.bookings.has(a["body"].get_instance_id()))


func test_late_interaction_exit_does_not_release_evacuation_bookings() -> void:
	var s = _scene()
	assert_true(s.life.start_interaction("chat", "medtech"), s.life.last_failure)
	if not s.life.interactions.has("medtech"):
		return
	var pair = s.life.interactions["medtech"]
	var ids: Array = pair.members.map(func(m): return m["actor"])
	_start_fire(s, "medtech")
	var bookings: Dictionary = s.life.places.bookings.duplicate(true)
	var routes: Dictionary = {}
	for id in ids:
		assert_true(s.life.actors[id].get("evacuating", false))
		assert_true(bookings.has(id))
		routes[id] = s.life.actors[id]["waypoints"].duplicate()
	pair.interrupt("accident")
	pair.advance(float(pair.spec["exit"]))
	s.life._finish("medtech")
	assert_false(s.life.interactions.has("medtech"))
	for id in ids:
		assert_eq(s.life.places.bookings.get(id, ""), bookings.get(id, ""))
		assert_eq(s.life.actors[id]["waypoints"], routes[id])
		assert_true(s.life.actors[id].get("evacuating", false))
		assert_eq(s.life.actors[id]["interaction"], "")


func test_evacuation_discards_an_interaction_return_before_arrival() -> void:
	var s = _scene()
	assert_true(s.life.start_interaction("chat", "medtech"), s.life.last_failure)
	if not s.life.interactions.has("medtech"):
		return
	var pair = s.life.interactions["medtech"]
	var id: int = pair.members[0]["actor"]
	var a: Dictionary = s.life.actors[id]
	var b: Node3D = a["body"]
	a["before_interaction"]["state"] = "seat"  # only a seated member walks back with a restore
	b.position = a["before_interaction"]["position"] + Vector3.RIGHT
	pair.interrupt("interrupt")
	s.life._finish("medtech")
	assert_true(a.has("restore"))
	_start_fire(s, "medtech")
	assert_true(a.get("evacuating", false))
	assert_false(a.has("restore"))
	assert_true(s.life.places.bookings.has(id))
	if not s.life.places.bookings.has(id):
		return
	var target: Vector3 = s.life.places.target(id)
	b.position = target
	s.life.arrived(b)
	assert_eq(b.position, target)
	assert_true(a["safe_arrival"])
	assert_false(a.get("evacuating", false))
	assert_false(b.visible)
	assert_false(s.life.places.bookings.has(id))


func test_late_scene_finish_preserves_a_new_route_to_the_same_spot() -> void:
	var s = _scene()
	assert_true(s.life.start_interaction("chat", "medtech"), s.life.last_failure)
	if not s.life.interactions.has("medtech"):
		return
	var id: int = s.life.interactions["medtech"].members[0]["actor"]
	var a: Dictionary = s.life.actors[id]
	var spot: String = s.life.places.bookings[id]
	assert_true(s.life.places.transfer(id, spot))
	s.life._route(a["body"], s.life.places.target(id))
	var route: Array = a["waypoints"].duplicate()
	s.life._finish("medtech")
	assert_eq(s.life.places.bookings.get(id, ""), spot)
	assert_eq(a["waypoints"], route)
	assert_eq(a["interaction"], "")


func test_stage_recovery_returns_an_incoming_evacuee_without_hiding() -> void:
	for stage in [0, 6]:
		var s = _scene()
		var movers := _start_fire(s)
		assert_gt(movers.size(), 0)
		if movers.is_empty():
			return
		var a: Dictionary = movers[0]
		var b: Node3D = a["body"]
		var id: int = b.get_instance_id()
		var slot: Vector3 = b.slot
		b.position = b.position.lerp(s.life.places.target(id), .5)
		s.rules["view"]["fire_cars"] = []
		s.rules["view"]["collapse_by_car"] = {"tail1": stage}
		s.life.refresh("recovery")
		assert_false(a.get("evacuating", false))
		assert_false(s.life.places.bookings.has(id))
		assert_true(b.visible)
		assert_true(a.has("restore"))
		if not a.has("restore"):
			return
		assert_eq(a["waypoints"].back(), slot)
		for i in 400:
			if s.life.walk(b, .1):
				break
		assert_eq(b.position, slot)
		assert_eq(a["waypoints"], [])
		s.life.arrived(b)
		assert_true(b.visible)
		assert_eq(b.position, slot)
		assert_eq(b.slot, slot)
		assert_eq(b.state, "seat")
		assert_false(a["safe_arrival"])
		assert_false(a.has("restore"))


func test_stage_recovery_restores_separate_seats_before_showing_safe_arrivals() -> void:
	for stage in [0, 6]:
		var s = _scene()
		var movers := _start_fire(s)
		assert_gte(movers.size(), 2)
		if movers.size() < 2:
			return
		var first: Node3D = movers[0]["body"]
		var second: Node3D = movers[1]["body"]
		var first_id: int = first.get_instance_id()
		var second_id: int = second.get_instance_id()
		var first_slot: Vector3 = first.slot
		var second_slot: Vector3 = second.slot
		assert_ne(first_slot, second_slot)
		var spot: String = s.life.places.bookings[first_id]
		var target: Vector3 = s.life.places.target(first_id)
		first.position = target
		s.life.arrived(first)
		assert_true(s.life.places.transfer(second_id, spot))
		s.life._route(second, s.life.places.target(second_id))
		second.position = s.life.places.target(second_id)
		s.life.arrived(second)
		assert_false(first.visible)
		assert_false(second.visible)
		assert_eq(first.position, second.position, "hidden proxies can reuse a refuge anchor")
		s.rules["view"]["fire_cars"] = []
		s.rules["view"]["collapse_by_car"] = {"tail1": stage}
		s.life.refresh("recovery")
		assert_true(first.visible)
		assert_true(second.visible)
		assert_eq(first.position, first_slot)
		assert_eq(second.position, second_slot)
		assert_eq(first.slot, first_slot)
		assert_eq(second.slot, second_slot)
		assert_ne(first.position, second.position)
		assert_false(movers[0]["safe_arrival"])
		assert_false(movers[1]["safe_arrival"])
		assert_false(s.life.places.bookings.has(first_id))
		assert_false(s.life.places.bookings.has(second_id))


func test_refresh_rebinds_a_reused_body_with_or_without_its_old_car() -> void:
	for remove_old in [false, true]:
		var s = _scene()
		assert_true(s.life.start_interaction("chat", "medtech"), s.life.last_failure)
		if not s.life.interactions.has("medtech"):
			return
		var id: int = s.life.interactions["medtech"].members[0]["actor"]
		var a: Dictionary = s.life.actors[id]
		var b: Node3D = a["body"]
		var source: Dictionary = s.car("medtech")
		var destination: Dictionary = s.car("dining")
		var replaced: Node3D = destination["bodies"][0]
		var slot: Vector3 = replaced.slot
		source["bodies"].erase(b)
		destination["bodies"][0] = b
		b.slot = slot
		b.position = replaced.position
		b.set_pose(replaced.pose, replaced.huddled, replaced.bowed)
		if remove_old:
			s.cars.erase(source)
		s.rules["view"]["collapse_override"] = 0
		s.rules["train"]["phase"] = "council"
		s.rules["train"]["voting"] = false
		s.life.refresh("formation")
		assert_eq(a["home"], "dining")
		assert_eq(a["state"], "session")
		assert_eq(a["interaction"], "")
		assert_eq(a["waypoints"], [])
		assert_false(a.has("restore"))
		assert_false(a.has("before_interaction"))
		assert_false(s.life.places.bookings.has(id))
		assert_eq(b.slot, slot)
		assert_eq(b.position, slot)
		assert_eq(b.get_meta("life")["home"], "dining")
		if s.life.interactions.has("medtech"):
			s.life._finish("medtech")
		assert_eq(a["state"], "session", "the old room cannot overwrite the new purpose")
		b.state = "wait"
		a["distraction_due"] = 0.0
		s.life.advance(float(Catalog.tuning("tick")))
		assert_ne(a["distraction"], "")
		assert_eq(a["home"], "dining")
		if remove_old:
			assert_false(s.life.contexts.has("medtech"))
			assert_false(s.life.rooms.has("medtech"))
			assert_false(s.life.interactions.has("medtech"))


func test_refresh_rehomes_a_hidden_evacuee_without_restoring_the_old_seat() -> void:
	var s = _scene()
	var movers := _start_fire(s)
	assert_gt(movers.size(), 0)
	if movers.is_empty():
		return
	var a: Dictionary = movers[0]
	var b: Node3D = a["body"]
	var id: int = b.get_instance_id()
	b.position = s.life.places.target(id)
	s.life.arrived(b)
	assert_false(b.visible)
	var destination: Dictionary = s.car("medtech")
	var replaced: Node3D = destination["bodies"][0]
	var slot: Vector3 = replaced.slot
	s.car("tail1")["bodies"].erase(b)
	destination["bodies"][0] = b
	b.slot = slot
	b.position = replaced.position
	b.set_pose(replaced.pose, replaced.huddled, replaced.bowed)
	s.rules["view"]["fire_cars"] = []
	s.life.refresh("formation")
	assert_eq(a["home"], "medtech")
	assert_eq(b.position, slot)
	assert_eq(b.slot, slot)
	assert_true(b.visible)
	assert_false(a.get("evacuating", false))
	assert_false(a["safe_arrival"])
	assert_false(a.has("before_evacuation"))
	assert_false(a.has("restore"))
	assert_false(s.life.places.bookings.has(id))


func test_finishing_a_scene_tolerates_a_missing_home_context() -> void:
	var s = _scene()
	assert_true(s.life.start_interaction("chat", "medtech"), s.life.last_failure)
	if not s.life.interactions.has("medtech"):
		return
	var ids: Array = s.life.interactions["medtech"].members.map(func(m): return m["actor"])
	s.life.contexts.erase("medtech")
	s.life._finish("medtech", true)
	assert_false(s.life.interactions.has("medtech"))
	for id in ids:
		assert_eq(s.life.actors[id]["state"], "idle")
		assert_eq(s.life.actors[id]["interaction"], "")
		assert_false(s.life.places.bookings.has(id))


func test_reregistering_a_refuge_cancels_its_incoming_evacuation() -> void:
	var s = _scene()
	var movers := _start_fire(s)
	assert_gt(movers.size(), 0)
	var destinations: Array = []
	for a in movers:
		var spot: String = s.life.places.bookings[a["body"].get_instance_id()]
		var car_id: String = s.life.places.spots[spot]["car"]
		if not destinations.has(car_id):
			destinations.append(car_id)
	for car_id in destinations:
		s.life.add_car(s.car(car_id))
	for a in movers:
		assert_false(a.get("evacuating", false))
		assert_false(s.life.places.bookings.has(a["body"].get_instance_id()))
	s.life.refresh("reregistered")
	s.life._evacuate(s.car("tail1"))
	for a in movers:
		assert_true(a.get("evacuating", false))
		assert_true(s.life.places.bookings.has(a["body"].get_instance_id()))


func test_a_burning_car_opens_no_everyday_place_whatever_its_screen_stage() -> void:
	var s = _scene()
	assert_true(s.set_value("view.work_time", true))
	assert_true(s.set_value("view.fire_cars", ["tail1"]))
	assert_true(s.set_value("view.collapse_by_car", {"tail1": 0}))
	var c: Dictionary = s.life.contexts["tail1"]
	assert_eq(int(c["stage"]), 0)
	assert_true(c["fire"])
	assert_false(c["safe"])
	for key in ["meal", "work", "social", "gather", "memorial", "classroom", "stove"]:
		assert_false(c[key], "불난 칸에서 열린 조건: " + String(key))
	var checked: int = 0
	for spot in s.life.places.spots.values():
		if spot["car"] == "tail1" and String(spot["when"]) in ["meal", "work", "social", "stove", "gather"]:
			assert_false(spot["open"], "불난 칸의 자리: " + String(spot["id"]))
			checked += 1
	assert_gt(checked, 0)
	assert_true(s.set_value("view.collapse_by_car", {"tail1": 6}))
	assert_true(s.life.contexts["tail1"]["fire"])
	assert_false(s.life.contexts["tail1"]["recovery"], "불이 난 채로 회복 표시를 켜지 않는다")
	assert_false(s.life.contexts["tail1"]["social"])


func test_evacuation_secures_a_refuge_first_and_falls_back_to_the_next_one() -> void:
	var s = _scene()
	s.rules["view"]["fire_cars"] = ["medtech"]
	s.life.refresh("fire")
	var places = s.life.places
	# 꼬리 칸 한 사람이 선 자리에 두 피난처의 앵커를 모두 겹쳐 둔다. 정원으로는 빈자리가 남는다.
	var blocker: int = s.car("tail1")["bodies"][0].get_instance_id()
	places.release(blocker)
	var rest: Array = places.candidates("tail1", ["rest", "watch"])
	assert_false(rest.is_empty())
	assert_true(places.reserve(blocker, rest[0]))
	var at: Vector3 = places.target(blocker)
	var first: Dictionary = places.spots["tail1/refuge"]
	var second: Dictionary = places.spots["dining/refuge"]
	var second_anchors: Array = second["anchors"].duplicate(true)
	for spot in [first, second]:
		var x0: float = float(spot["x0"])
		spot["anchors"] = spot["anchors"].map(func(_v): return [at.x - x0, at.y, at.z])
	assert_true(places.candidates("tail1", ["refuge"]).has("tail1/refuge"), "정원으로는 아직 빈자리가 있다")
	var before: Dictionary = {}
	for b in s.car("medtech")["bodies"]:
		var id: int = b.get_instance_id()
		before[id] = [b.state, b.position, places.bookings.get(id, ""), s.life.actors[id]["activity"]]
	assert_false(before.is_empty())
	s.life._evacuate(s.car("medtech"))
	for b in s.car("medtech")["bodies"]:
		var id: int = b.get_instance_id()
		assert_false(s.life.actors[id].get("evacuating", false))
		assert_eq([b.state, b.position, places.bookings.get(id, ""), s.life.actors[id]["activity"]], before[id], "피난처를 못 잡으면 하던 일을 그대로 둔다")
	second["anchors"] = second_anchors
	s.life._evacuate(s.car("medtech"))
	var moved: int = 0
	for b in s.car("medtech")["bodies"]:
		var id: int = b.get_instance_id()
		if s.life.actors[id].get("evacuating", false):
			moved += 1
			assert_eq(places.bookings.get(id, ""), "dining/refuge", "첫 피난처가 막히면 다음 피난처로 간다")
	assert_gt(moved, 0)


func test_the_life_panel_follows_a_shortened_train_without_reading_past_its_end() -> void:
	var s = _scene(true)
	assert_true(s.set_value("dom.extraCars", ["coach", "store"]))
	assert_eq(s.cars.size(), 8)
	s.panel._flip_life()
	s.panel.pick(7)
	var panel = s.panel.life_panel
	assert_eq(panel._car_id(), String(s.cars[7]["id"]))
	assert_true(s.set_value("dom.extraCars", []))
	assert_eq(s.cars.size(), 6)
	assert_eq(s.panel.car_i, 5, "칸이 줄면 고른 칸 번호부터 고친다")
	assert_eq(panel._car_id(), String(s.cars[5]["id"]))
	assert_true(panel.status.text.begins_with(String(s.cars[5]["def"]["name"])), "생활 판이 새 편성의 칸으로 다시 그려졌다")


func test_old_setters_check_the_whole_snapshot_before_touching_the_cars() -> void:
	var s = _scene()
	var rules: Dictionary = s.rules.duplicate(true)
	var slots: Array = s.car("tail1")["bodies"].map(func(b): return b.slot)
	var text: String = s.car("tail1")["values"].text
	var events: int = s.life.event_count
	var contexts: Dictionary = s.life.contexts.duplicate(true)
	assert_false(s.set_comm("tail", "sit", [70]), "넷이 아닌 sit 배열은 받지 않는다")
	assert_false(s.set_comm("tail", "rel", "low"))
	assert_false(s.set_comm("nobody", "rel", 0))
	assert_false(s.set_train("tension", 150.0))
	assert_false(s.set_sit("tail", 9, 50.0))
	assert_eq(s.rules, rules)
	assert_eq(s.car("tail1")["bodies"].map(func(b): return b.slot), slots)
	assert_eq(s.car("tail1")["values"].text, text)
	assert_eq(s.life.event_count, events)
	assert_eq(s.life.contexts, contexts)
	assert_true(s.set_comm("tail", "rel", -10))
	assert_eq(s.life.event_count, events + 1)


func test_a_display_only_change_keeps_a_running_chat() -> void:
	var s = _scene()
	assert_true(s.life.start_interaction("chat", "medtech"), s.life.last_failure)
	var pair = s.life.interactions["medtech"]
	var ids: Array = pair.members.map(func(m): return m["actor"])
	_advance(s, 1)
	assert_eq(s.life.interactions.get("medtech"), pair)
	var bookings: Dictionary = {}
	for id in ids:
		bookings[id] = s.life.places.bookings.get(id, "")
	assert_true(s.set_value("train.lux", float(s.rules["train"].get("lux", 0)) + 5.0))
	assert_eq(s.life.interactions.get("medtech"), pair, "물품 값만 바뀌면 대화가 이어진다")
	assert_eq(pair.reason, "")
	for id in ids:
		assert_eq(s.life.actors[id]["interaction"], "medtech")
		assert_eq(s.life.places.bookings.get(id, ""), bookings[id])
	# 앉는 모양이 바뀌는 칸이면 그 칸의 장면은 여전히 끝난다.
	var sit: Array = s.rules["comms"]["medtech"]["sit"]
	assert_true(s.set_sit("medtech", 2, 0.0 if float(sit[2]) >= 50.0 else 100.0))
	assert_false(s.life.interactions.has("medtech"))


func test_a_display_only_change_lets_a_cleanup_finish_and_clear_the_props() -> void:
	var s = _scene()
	s.set_value("view.collapse_by_car", {"tail1": 5})
	s.set_value("view.collapse_by_car", {"tail1": 6})
	var room = s.life.rooms["tail1"]
	assert_true(room.traces["sacks"]["overturned"])
	s.life_signal("cleanup", "tail1")
	var job = s.life.interactions.get("tail1")
	assert_not_null(job, s.life.last_failure)
	_advance(s, 2)
	assert_true(s.set_value("train.lux", float(s.rules["train"].get("lux", 0)) + 5.0))
	assert_eq(s.life.interactions.get("tail1"), job, "물품 값만 바뀌면 치우기가 이어진다")
	_advance(s, 50)
	assert_false(room.traces["sacks"]["overturned"], "끝까지 치우면 넘어진 짐이 정리된다")
