extends "res://addons/gut/test.gd"

const Scene = preload("res://game/train/train_scene.gd")
const Rules = preload("res://game/train/train_rules.gd")
const Catalog = preload("res://game/train/train_catalog.gd")
const Context = preload("res://game/train/train_context.gd")
const Body = preload("res://game/train/train_body.gd")


func _scene(panel: bool = false):
	var s = Scene.new()
	s.rules = Rules.load_default()
	s.opts = {"seed": 7, "panel": panel}
	add_child_autofree(s)
	return s


func _advance(s, seconds: float) -> void:
	for i in int(seconds * 10):
		s.step(.1)


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


func test_night_and_stop_change_lamps_and_route_metadata_stays_outside_politics() -> void:
	var s = _scene()
	var lamp: float = s.car("front")["lamp_energy"]
	s.set_value("view.daytime", "night")
	assert_lt(float(s.car("front")["lamp_energy"]), lamp)
	s.set_value("view.motion", "stopped")
	assert_eq(float(s.car("front")["lamp_sway"]), 0.0)
	s.set_value("train.seg", 9)
	s.set_value("view.region", "region_04")
	s.set_value("view.season", "thaw")
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
	assert_eq(s.cars.size(), 7)
	assert_eq(Catalog.layout_id(s.car("coach1")["def"]), "coach")
	assert_eq(s.car("store2")["bodies"].size(), 0)
	assert_true(s.life.rooms["tail1"].traces["sacks"]["overturned"])
	assert_eq(s.rules["dom"]["extraCars"], ["coach", "store"])
	assert_true(s.set_value("dom.extraCars", []))
	assert_eq(s.cars.size(), 5)


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
	assert_eq(lights, 11, "sun plus the existing five lamps and five stoves")
	print("TRAIN_NODE_BUDGET=" + JSON.stringify({"nodes": count, "lights": lights, "people": s.people.get_child_count(), "furniture_roots": s.life.rooms.size(), "outside_nodes": 4}))
