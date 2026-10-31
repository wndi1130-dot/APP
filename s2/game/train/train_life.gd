extends RefCounted
## The visible lifecycle. Body.state remains locomotion; state here is the one
## event-selected purpose. Neither this nor its helpers writes simulation values.

const Catalog = preload("res://game/train/train_catalog.gd")
const Context = preload("res://game/train/train_context.gd")
const SeasonTable = preload("res://game/season_table.gd")
const LifeInput = preload("res://game/train/train_life_input.gd")
const Places = preload("res://game/train/train_places.gd")
const Schedule = preload("res://game/train/train_schedule.gd")
const Interaction = preload("res://game/train/train_interaction.gd")
const Motion = preload("res://game/train/train_motion_contract.gd")
const Interior = preload("res://game/train/train_interior.gd")
const TrainLight = preload("res://game/train/train_light.gd")

var host: Node3D
var places = Places.new()
var contexts: Dictionary = {}
var actors: Dictionary = {}
var rooms: Dictionary = {}
var interactions: Dictionary = {}  # car id -> one shared scene
var outside: Node3D
var event_count: int = 0
var last_event: String = ""
var last_failure: String = ""
var _tick: float = 0.0
var _serial: int = 0
var _cleanup: Dictionary = {}


func held(body: Node3D) -> bool:
	return String(actors.get(body.get_instance_id(), {}).get("interaction", "")) != ""


func greet(caller: Node3D, listener: Node3D) -> bool:
	var caller_id := caller.get_instance_id()
	if not places.bookings.has(caller_id):
		return true  # the legacy test/API may greet without a planned trip
	var id := listener.get_instance_id()
	if held(listener):
		return false
	if not places.transfer(id, places.bookings[caller_id]):
		return false
	actors[id]["activity"] = "chat"
	_route(listener, places.target(id))
	return true


func setup(scene: Node3D) -> void:
	host = scene


func before_refresh() -> void:
	# A new seating snapshot supersedes old place coordinates. Explicit scene
	# signals still use the timed exit; this resets a replaced snapshot safely.
	before_reseat(interactions.keys())


## 다시 앉는 칸에서 벌어지는 장면과, 그 칸 사람이 낀 다른 칸의 장면만 끝낸다.
## 나머지 장면(치우기 포함)은 이어 가서 제때 끝나야 뒷정리까지 된다.
func before_reseat(car_ids: Array) -> void:
	for car_id in interactions.keys():
		var scene = interactions[car_id]
		var touched: bool = car_ids.has(car_id)
		for m in scene.members:
			touched = touched or car_ids.has(actors.get(int(m["actor"]), {}).get("home", ""))
		if touched:
			scene.interrupt("rules")
			_finish(car_id, true)


func add_car(c: Dictionary) -> void:
	for id in places.bookings.keys():
		var spot: Dictionary = places.spots.get(places.bookings[id], {})
		if spot.get("car", "") == c["id"]:
			cancel(int(id), "closed")
	places.add_car(c["def"], float(c["x0"]))
	var room = Interior.new()
	var home_stage: int = clampi(int(c.get("home_stage", TrainLight.STAGE_DEFAULT)), 0, 3)
	room.build(c["node"], c["def"], func(at: Vector3, model: String = "") -> void: host._build_stove(c, at, model), home_stage)
	rooms[c["id"]] = room


func build_outside() -> void:
	outside = Node3D.new()
	outside.name = "OutsideLifeAnchors"
	host.add_child(outside)
	for id in ["chasing", "refugees", "passing"]:
		var anchor := Node3D.new()
		anchor.name = id
		outside.add_child(anchor)


func refresh(event: String = "rules") -> void:
	var car_ids: Array = host.cars.map(func(c): return c["id"])
	var bad := LifeInput.check(host.rules, car_ids)
	if not bad.is_empty():
		last_failure = "; ".join(bad)
		return
	# Prepare every car and person before changing the visible snapshot.
	var next_contexts: Dictionary = {}
	var next_people: Dictionary = {}
	for c in host.cars:
		if not rooms.has(c["id"]):
			last_failure = "room_missing: " + String(c["id"])
			return
		var context := Context.read(host.rules, c["def"]).duplicate(true)
		next_contexts[c["id"]] = context
		var supplied: Dictionary = host.rules.get("view", {}).get("actors", {}).get(c["id"], {})
		for i in c["bodies"].size():
			var body: Node3D = c["bodies"][i]
			if not is_instance_valid(body):
				last_failure = "body_missing: " + String(c["id"])
				return
			var id := body.get_instance_id()
			if next_people.has(id):
				last_failure = "body_in_multiple_cars"
				return
			var traits: Dictionary = (supplied.get(str(i), {}) as Dictionary).duplicate(true)
			if context["layout"] == "medical" and i < mini(int(context["patient_count"]), int(Catalog.tuning("medical_beds"))) and not supplied.has(str(i)):
				traits["injured"] = true
				traits["aggregate_patient"] = true
			if not traits.has("role"):
				# The workshop's people work at its bench, the engine crew shovel at the firebox end.
				if context["layout"] in ["technical", "engine_room"]:
					traits["role"] = "worker"
				elif context["layout"] == "medical" and not traits.get("injured", false) and not traits.get("sick", false):
					traits["role"] = "carer"
				elif context["layout"] == "dining" and not traits.get("child", false):
					traits["role"] = "cook"
			next_people[id] = {"body": body, "home": c["id"], "turn": i, "traits": traits,
				"preferred": Schedule.preferences(context, traits), "distractions": Schedule.distractions(context, traits),
				"state": Schedule.main_state(context, traits)}
	contexts = next_contexts
	event_count += 1
	last_event = event
	last_failure = ""
	for id in next_people:
		var row: Dictionary = next_people[id]
		var body: Node3D = row["body"]
		if not actors.has(id):
			actors[id] = {"body": body, "home": row["home"], "activity": "", "state": "idle", "waypoints": [],
				"turn": row["turn"], "interaction": "", "distraction": "", "distraction_left": 0.0,
				"distraction_due": float(Catalog.tuning("distraction_every")[0]) + int(row["turn"]),
				"requested": "", "traits": {}, "safe_arrival": false}
		var a: Dictionary = actors[id]
		if a["home"] != row["home"]:
			for c in host.cars:
				if c["id"] == a["home"] and body.state in ["out", "visit", "back"]:
					c["out"] = maxi(0, int(c["out"]) - 1)
			_leave_interaction(a, "rules")
			_end_evacuation(int(id), false)
			places.release(int(id))
			a["waypoints"] = []
			a["activity"] = ""
			a["requested"] = ""
			a["distraction"] = ""
			a.erase("restore")
			body.visit_car = ""
			body.errand = {}
			body.position = body.slot
			body.state = "seat"
			body.visible = true
		for key in ["home", "traits", "preferred", "distractions", "state"]:
			a[key] = row[key]
		a["event"] = event_count
		body.set_meta("life", a)
		var context: Dictionary = contexts[a["home"]]
		if not context["fire"]:
			_end_evacuation(int(id))
			body.visible = true
			a["safe_arrival"] = false
		if context["voting"]:
			a["distraction"] = ""
			Motion.Backend.show(body, "", 0.0)
	for c in host.cars:
		var context: Dictionary = contexts[c["id"]]
		rooms[c["id"]].apply(context)
		_apply_light(c, context)
		if context["voting"]:
			send_signal("vote", c["id"])
		elif context["accident"]:
			send_signal("accident", c["id"])
	for id in actors.keys():
		if not next_people.has(id):
			places.release(int(id))
			for scene in interactions.values():
				if scene.members.any(func(m): return int(m["actor"]) == int(id)):
					scene.interrupt("actor_removed")
			var body: Node3D = actors[id]["body"]
			if is_instance_valid(body):
				body.remove_meta("life")
			actors.erase(id)
	for car_id in interactions.keys():
		if not contexts.has(car_id):
			interactions[car_id].interrupt("actor_removed")
			_finish(car_id, true)
	for car_id in rooms.keys():
		if not contexts.has(car_id):
			rooms.erase(car_id)
	for id in places.refresh(contexts):
		cancel(int(id), "closed")
	if outside != null:
		var route := {
			"seg": host.rules.get("train", {}).get("seg", 1),
			"region": host.rules.get("view", {}).get("region", "region_01"),
			"country": host.rules.get("view", {}).get("country", "country_a"),
			"season": host.rules.get("view", {}).get("season", SeasonTable.season_of_seg(int(host.rules.get("train", {}).get("seg", 1)))),
			"weather": host.rules.get("stop", {}).get("weather", "overcast"),
			"layers": host.rules.get("view", {}).get("outside", {}).duplicate(true),
		}
		outside.set_meta("route", route)


func choose_local(c: Dictionary, body: Node3D) -> bool:
	var id := body.get_instance_id()
	if not actors.has(id) or not contexts.has(c["id"]):
		return false
	var a: Dictionary = actors[id]
	if String(a["interaction"]) != "" or contexts[c["id"]]["voting"]:
		return true
	if moving_count(c["id"]) >= int(Catalog.tuning("max_movers")):
		body.timer = float(Catalog.tuning("tick"))
		return true
	var previous: String = String(places.bookings.get(id, ""))
	var previous_requested: String = a["requested"]
	places.release(id)
	a["requested"] = ""
	var preferred: Array = Schedule.ranked(a["preferred"], a["state"], contexts[c["id"]])
	var choices := places.candidates(c["id"], preferred)
	# Equal-priority idle places take turns; needs and shared events keep priority.
	if choices.is_empty():
		return false
	var offset: int = 0
	if a["state"] == "idle" and int(contexts[c["id"]]["stage"]) == 0:
		offset = posmod(int(a["turn"]), choices.size())
	var choice: String = ""
	for i in choices.size():
		var candidate: String = choices[(i + offset) % choices.size()]
		if places.reserve(id, candidate, _blocked(c, [id])):
			choice = candidate
			break
	if choice == "":
		return false
	a["turn"] = int(a["turn"]) + 1
	a["activity"] = places.spots[choice]["activity"]
	if choice == previous and body.position.is_equal_approx(places.target(id)):
		places.arrive(id)
		a["requested"] = previous_requested
		body.timer = _hold_time(places.spots[choice], String(a["activity"]))
		return true
	_route(body, places.target(id))
	body.state = "pace"
	return true


func reserve_trip(body: Node3D, to: Dictionary, row: Dictionary, goal_x: float) -> bool:
	var id := body.get_instance_id()
	if not actors.has(id) or String(actors[id]["interaction"]) != "":
		return false
	if not contexts.has(actors[id]["home"]) or not contexts.has(to.get("id", "")):
		return false
	var kind := String(row.get("id", ""))
	var purpose: String = actors[id]["state"]
	if purpose in ["sleep", "heal", "gather", "work"] and not ((purpose == "heal" and kind == "sick") or (purpose == "work" and kind == "work")):
		return false
	if moving_count(String(actors[id]["home"])) >= int(Catalog.tuning("max_movers")):
		return false
	var activities: Array = []
	match kind:
		"call": activities = ["chat"]
		"meal": activities = ["eat"]
		"sick": activities = ["heal"]
		"council": activities = ["session"]
		"work": activities = ["work", "carry"]
		_: return false
	var choices := places.candidates(to["id"], activities)
	if kind == "call":
		var door: String = "/door_tail" if goal_x < float(to["x0"]) + host.CAR_LENGTH * 0.5 else "/door_front"
		choices = choices.filter(func(s): return String(s).ends_with(door))
	if choices.is_empty() or not places.transfer(id, choices[0]):
		return false
	var a: Dictionary = actors[id]
	a["activity"] = places.spots[choices[0]]["activity"]
	a["state"] = {"call": "call", "meal": "eat", "sick": "heal", "council": "session", "work": "work"}[kind]
	a["event"] = "trip_started"
	a["requested"] = ""
	_route(body, places.target(id))
	return true


func walk(body: Node3D, delta: float) -> bool:
	var a: Dictionary = actors.get(body.get_instance_id(), {})
	if a.is_empty() or (a["waypoints"] as Array).is_empty():
		var done: bool = body.walk(delta)
		if done:
			_face_spot(body)
		return done
	while not a["waypoints"].is_empty() and body.position.is_equal_approx(a["waypoints"][0]):
		a["waypoints"].pop_front()
	if a["waypoints"].is_empty():
		body.set_pose("sit" if body.position.y > 0.0 else "stand", false)
		_face_spot(body)
		return true
	var target: Vector3 = a["waypoints"][0]
	var toward: Vector3 = target - body.position
	body.position = body.position.move_toward(target, body.speed * delta)
	body.clock += delta
	body.rotation.y = atan2(toward.x, toward.z)
	# The existing walk clip is for the longitudinal aisle; entering a place is
	# a short standing transition until a sidestep/entry clip is available.
	body.set_pose("sit" if target.y > 0.0 or body.position.y > 0.0 else ("walk" if absf(toward.x) > 0.001 else "stand"), false)
	if body.position.is_equal_approx(target):
		a["waypoints"].pop_front()
		if a["waypoints"].is_empty():
			body.set_pose("sit" if body.position.y > 0.0 else "stand", false)
			_face_spot(body)
			return true
	return false


func _face_spot(body: Node3D) -> void:
	var id: int = body.get_instance_id()
	var spot: Dictionary = places.spots.get(places.bookings.get(id, ""), {})
	var member: Dictionary = spot.get("members", {}).get(id, {})
	body.rotation.y = _spot_facing(spot, int(member.get("anchor", 0)), body.position)
	# A new arrival also resets a repeated motion's stored base facing.
	body.set_meta("life_facing", body.rotation.y)


func _spot_facing(spot: Dictionary, anchor: int, at: Vector3) -> float:
	var focus: Variant = spot.get("look_at", 0)
	var target: Vector2
	if focus is Array:
		var point: Array = focus
		# Windows at different anchors each look straight through their pane.
		if not point.is_empty() and point[0] is Array:
			if anchor < 0 or anchor >= point.size():
				return 0.0
			point = point[anchor]
		if point.size() != 2:
			return 0.0
		target = Vector2(float(point[0]), float(point[1]))
	elif focus is String and focus == "partner":
		var anchors: Array = spot.get("anchors", [])
		if anchors.size() < 2:
			return 0.0
		var other: Array = anchors[(anchor + 1) % anchors.size()]
		target = Vector2(float(other[0]), float(other[2]))
	else:
		return 0.0
	var local := Vector2(at.x - float(spot.get("x0", 0.0)), at.z)
	var toward: Vector2 = target - local
	return 0.0 if toward.is_zero_approx() else atan2(toward.x, toward.y)


func _hold_time(spot: Dictionary, activity: String) -> float:
	var seconds: float = host.rng.randf_range(float(spot["hold"][0]), float(spot["hold"][1]))
	if activity in ["rest", "watch", "warm", "chat", "read", "mend", "sleep"]:
		seconds = maxf(seconds, float(Catalog.tuning("min_hold")))
	return seconds


func arrived(body: Node3D) -> void:
	var id := body.get_instance_id()
	if not actors.has(id):
		return
	var a: Dictionary = actors[id]
	if a.get("evacuating", false) and not contexts.get(a["home"], {}).get("fire", false):
		_end_evacuation(id, contexts.has(a["home"]))
		return
	if a.has("restore"):
		var previous: Dictionary = a["restore"]
		body.state = "seat"
		body.position = previous["position"]
		body.slot = previous["slot"]
		body.set_pose(previous["pose"], body.huddled, body.bowed)
		a["waypoints"] = []
		a.erase("restore")
		if previous.has("facing"):
			_face_saved(body, previous)
		else:
			_face_spot(body)
		return
	if places.bookings.has(id):
		var spot: Dictionary = places.spots.get(places.bookings[id], {})
		if not contexts.has(spot.get("car", "")):
			cancel(id, "closed")
			return
	if places.arrive(id):
		var s: Dictionary = places.spots[places.bookings[id]]
		body.timer = _hold_time(s, String(a["activity"]))
		_face_spot(body)
		var context: Dictionary = contexts[s["car"]]
		a["requested"] = Schedule.gesture(a["activity"], context, a["traits"], int(a["turn"]))
		if a["activity"] in ["sleep", "heal", "mourn"]:
			body.idle_gesture = ""
			Motion.Backend.show(body, "", 0.0, 0, body.rotation.y)
			a["distraction"] = ""
		if a.get("evacuating", false):
			# The destination represents the safe crowd; do not stack every proxy there.
			a["safe_arrival"] = true
			a["evacuating"] = false
			body.visible = false
			body.state = "seat"
			body.slot = body.position
			places.release(id)
	if String(a["interaction"]) != "" and interactions.has(a["interaction"]):
		interactions[a["interaction"]].arrive(id)
	elif places.bookings.has(id):
		_pair_ready(String(places.bookings[id]))


func end_trip(body: Node3D) -> void:
	var id := body.get_instance_id()
	var returning := _end_evacuation(id)
	places.release(id)
	if actors.has(id):
		var a: Dictionary = actors[id]
		if not returning:
			a["waypoints"] = []
			a.erase("restore")
		a["requested"] = ""
		a["activity"] = ""
		a["state"] = Schedule.main_state(contexts.get(a["home"], {}), a["traits"]) if contexts.has(a["home"]) else "idle"
		a["event"] = "returned"


func return_route(body: Node3D) -> void:
	places.release(body.get_instance_id())
	if actors.has(body.get_instance_id()):
		actors[body.get_instance_id()]["requested"] = ""
		_route(body, Vector3(body.slot.x, 0, host.AISLE_Z))


func cancel(id: int, why: String) -> void:
	if not actors.has(id):
		return
	if _end_evacuation(id):
		return
	var a: Dictionary = actors[id]
	var b: Node3D = a["body"]
	places.release(id)
	a["requested"] = ""
	if String(a["interaction"]) != "" and interactions.has(a["interaction"]):
		interactions[a["interaction"]].interrupt(why)
	if b.state in ["out", "visit"]:
		b.state = "back"
		b.goal_x = b.slot.x
		return_route(b)
	elif b.state == "pace":
		a["waypoints"] = []
		b.state = "wait"
		b.timer = float(Catalog.tuning("slot_return_delay"))


func advance(delta: float) -> void:
	_tick += maxf(delta, 0.0)
	if _tick < float(Catalog.tuning("tick")):
		return
	var dt := _tick
	_tick = 0.0
	for id in places.advance(dt):
		cancel(int(id), "closed")
	for car_id in interactions.keys():
		var scene = interactions[car_id]
		if contexts.get(car_id, {}).get("voting", false):
			continue
		scene.advance(dt)
		if scene.ended:
			_finish(car_id)
	for a in actors.values():
		var b: Node3D = a["body"]
		if not is_instance_valid(b) or b.state not in ["wait", "visit"] or String(a["interaction"]) != "":
			continue
		var context: Dictionary = contexts.get(a["home"], {})
		if context.is_empty():
			continue
		if a["activity"] not in ["sleep", "heal", "mourn"] and not a["distractions"].is_empty() and not context["voting"]:
			a["distraction_due"] = float(a["distraction_due"]) - dt
			a["distraction_left"] = maxf(0, float(a["distraction_left"]) - dt)
			if float(a["distraction_left"]) <= 0:
				a["distraction"] = ""
			if float(a["distraction_due"]) <= 0:
				a["distraction"] = a["distractions"][posmod(int(a["turn"]), a["distractions"].size())]
				a["distraction_left"] = float(Catalog.tuning("distraction_hold"))
				var range_s: Array = Catalog.tuning("distraction_every")
				a["distraction_due"] = host.rng.randf_range(float(range_s[0]), float(range_s[1]))
	for c in host.cars:
		if contexts.get(c["id"], {}).get("fire", false):
			_evacuate(c)


func show_body(c: Dictionary, body: Node3D) -> void:
	var id := body.get_instance_id()
	if not actors.has(id) or not body.visible or not contexts.has(c["id"]):
		return
	var a: Dictionary = actors[id]
	if contexts[c["id"]]["voting"] or (host._hold_to > host._hold_from and body.position.x >= host._hold_from and body.position.x <= host._hold_to):
		return
	# Existing cold/hunger/fear/resentment gestures retain their precedence: a body
	# the scene draws one on is not drawn here too, not even by a shared scene.
	if body.gesture != "":
		return
	var room: String = a["interaction"]
	if room != "" and interactions.has(room):
		var scene = interactions[room]
		if body.state not in ["pace", "out", "back"]:
			_show_motion(body, String(scene.gesture(id)), scene.elapsed, scene.role(id), scene.phase)
		return
	if body.state not in ["wait", "visit"]:
		return
	var requested: String = a["requested"]
	# A distraction is short and never moves the body: none on a seat or the floor, and
	# none that would sit it down or drop it (catch_breath borrows a slump to the floor:
	# on one standing it dropped them, and the next frame the request stood them up).
	if a["distraction"] != "" and body.pose not in ["sit", "floor"] and Motion.keeps_pose(String(a["distraction"]), String(body.pose)):
		requested = a["distraction"]
	# Each one's motion runs from when that one started it, not from the shared
	# clock: a look round starts facing ahead and a one-off at its first frame.
	if requested != String(a.get("motion", "")):
		a["motion"] = requested
		a["motion_since"] = host.clock
	_show_motion(body, requested, host.clock - float(a.get("motion_since", host.clock)), 0)


## Draws a life motion. Once the request has gone empty, a motion still shown is
## taken off once: arms hidden, back to the facing it turned from, the pose kept.
func _show_motion(body: Node3D, requested: String, time: float, role: int, phase: String = "loop") -> void:
	if requested != "":
		Motion.show(body, requested, time, role, phase)
	elif body.has_meta("life_motion") and String(body.get_meta("life_motion")["requested"]) != "":
		Motion.show(body, "", 0.0)


func start_interaction(kind: String, car_id: String) -> bool:
	last_failure = ""
	if interactions.has(car_id) or not Catalog.data()["interactions"].has(kind) or not contexts.has(car_id):
		last_failure = "busy_or_unknown"
		return false
	var spec: Dictionary = Catalog.data()["interactions"][kind].duplicate(true)
	var context: Dictionary = contexts[car_id]
	if context["voting"] or context["fire"] or (kind == "classroom" and not context["classroom"]):
		last_failure = "closed"
		return false
	var c: Dictionary = host.car(car_id)
	var fixed: bool = bool(spec.get("council", false)) and context["council"] and context["layout"] == "dining"
	if kind == "classroom" and context["half_class"]:
		spec["roles"] = spec["roles"].slice(0, int(Catalog.tuning("half_class_capacity")))
		spec["gestures"] = spec["gestures"].slice(0, int(Catalog.tuning("half_class_capacity")))
	if spec.get("council", false) and not fixed:
		return false
	var picked: Array = []
	var council_places: Array = host.Look.council_places(c["bodies"].size()) if fixed else []
	for role_index in spec["roles"].size():
		var role: String = spec["roles"][role_index]
		var candidates: Array = c["bodies"].duplicate()
		if kind in ["care", "help"] and role in ["carer", "helper"]:
			# Invite the eligible neighbour at the bedside first, vacating that
			# seat for the patient instead of inviting somebody across the room.
			var bedside: Dictionary = places.spots.get(car_id + "/" + String(spec["spot"]), {})
			if not bedside.is_empty():
				var at := Catalog.vector(bedside["anchors"][role_index]) + Vector3(float(c["x0"]), 0, 0)
				candidates.sort_custom(func(a, b): return a.position.distance_squared_to(at) < b.position.distance_squared_to(at))
		for b in candidates:
			var id: int = b.get_instance_id()
			var a: Dictionary = actors[id]
			if picked.has(id) or b.state not in ["seat", "wait"] or a["interaction"] != "":
				continue
			if fixed:
				var index: int = c["bodies"].find(b)
				if role == "chair" and index != council_places.find("chair"):
					continue
				if role == "clerk" and index != council_places.find("chair") + 1:
					continue
				if role == "representative" and b.seat != 0:
					continue
				if role == "background" and b.seat != 1:
					continue
			var child: bool = bool(a["traits"].get("child", false))
			var unwell: bool = bool(a["traits"].get("injured", false)) or bool(a["traits"].get("sick", false))
			if not fixed and ((bool(spec.get("adults_only", false)) and (child or unwell)) or (role == "child" and not child) or (role != "child" and child and role not in ["learner", "receiver", "patient"])):
				continue
			if not fixed and ((role == "patient" and not unwell) or (role in ["carer", "helper"] and unwell)):
				continue
			if not fixed and ((role == "carer" and a["traits"].get("role", "") != "carer") or (kind == "classroom" and role == "teacher" and a["traits"].get("role", "") != "teacher")):
				continue
			picked.append(id)
			break
	if picked.size() != spec["roles"].size():
		last_failure = "roles_missing"
		return false
	var spot_id := car_id + "/" + String(spec["spot"])
	if not fixed:
		if not places.spots.has(spot_id) or not places.spots[spot_id]["open"]:
			last_failure = "spot_closed"
			return false
		var moving: int = c["bodies"].filter(func(b): return b.state in ["pace", "out", "back"]).size()
		if moving + picked.size() > int(Catalog.tuning("max_movers")):
			last_failure = "movement_budget"
			return false
		if not places.reserve_group(picked, spot_id, _blocked(c, picked)):
			last_failure = "capacity"
			return false
	var scene = Interaction.new()
	scene.setup(kind, spec)
	interactions[car_id] = scene
	if kind == "cleanup":
		_cleanup[car_id] = true
	for i in picked.size():
		var id: int = picked[i]
		var a: Dictionary = actors[id]
		var b: Node3D = a["body"]
		a["interaction"] = car_id
		a["state"] = _interaction_state(kind)
		a["event"] = "invited"
		a["before_interaction"] = _snapshot(b)
		if not fixed:
			_route(b, places.target(id))
			b.state = "pace"
		else:
			_serial += 1
			a["movement"] = _serial
		scene.invite(id, i)
		scene.members[i]["movement"] = a["movement"]
	for id in picked:
		if fixed:
			scene.arrive(id)
	return true


func send_signal(cue: String, car_id: String = "") -> void:
	var ids: Array = [car_id] if car_id != "" else contexts.keys()
	for id in ids:
		if cue == "cleanup":
			start_interaction("cleanup", id)
			continue
		if cue in ["bell", "wrench"] and not interactions.has(id):
			start_interaction("council", id)
		if interactions.has(id):
			interactions[id].receive(cue)


func _finish(car_id: String, instant: bool = false) -> void:
	if not interactions.has(car_id):
		return
	var scene = interactions[car_id]
	for m in scene.members:
		var id: int = m["actor"]
		if not actors.has(id):
			places.release(id)
			continue
		var a: Dictionary = actors[id]
		if a["interaction"] != car_id:
			continue
		if int(a.get("movement", 0)) != int(m.get("movement", -1)):
			a["interaction"] = ""
			a.erase("before_interaction")
			continue
		places.release(id)
		var b: Node3D = a["body"]
		a["interaction"] = ""
		a["state"] = Schedule.main_state(contexts[a["home"]], a["traits"]) if contexts.has(a["home"]) else "idle"
		a["event"] = "scene_finished"
		a["requested"] = ""
		a["waypoints"] = []
		Motion.show(b, "", 0.0)
		var previous: Dictionary = a.get("before_interaction", {})
		a.erase("before_interaction")
		if previous.get("state", "wait") == "seat":
			if instant or b.position.is_equal_approx(previous["position"]):
				b.state = "seat"
				b.position = previous["position"]
				b.slot = previous["slot"]
				b.set_pose(previous["pose"], b.huddled, b.bowed)
				_face_saved(b, previous)
			else:
				a["restore"] = previous
				_route(b, previous["position"])
				b.state = "pace"
		else:
			b.state = "visit" if previous.get("state") == "visit" else "wait"
			b.timer = float(Catalog.tuning("slot_return_delay"))
	if _cleanup.has(car_id):
		if scene.reason == "" and rooms.has(car_id):
			rooms[car_id].cleanup()
		_cleanup.erase(car_id)
	interactions.erase(car_id)


## Where a body is before a scene or a fire moves it, and the way it faces
## before any gesture turns it, so a return can face it that way again.
func _snapshot(b: Node3D) -> Dictionary:
	return {"state": b.state, "slot": b.slot, "pose": b.pose, "position": b.position, "facing": _facing_of(b)}


func _facing_of(b: Node3D) -> float:
	return float(b.gesture_facing) if b.gesture != "" else Motion._base_facing(b)


## Faces a body the way its snapshot saw it; its next gesture turns from there.
func _face_saved(body: Node3D, previous: Dictionary) -> void:
	if previous.has("facing"):
		body.rotation.y = float(previous["facing"])
		body.set_meta("life_facing", body.rotation.y)


func _pair_ready(spot_id: String) -> void:
	var spot: Dictionary = places.spots[spot_id]
	var car_id: String = spot["car"]
	if interactions.has(car_id) or not contexts.has(car_id):
		return
	var kind: String = {"chat": "chat", "care": "care", "carry": "handoff", "work": "teach", "gather": "push"}.get(spot["activity"], "")
	if kind == "" or (kind == "push" and int(contexts[car_id]["stage"]) != 4):
		return
	var members: Array = []
	for id in spot["members"]:
		if spot["members"][id]["phase"] == "present" and actors.has(id) and not held(actors[id]["body"]):
			if kind == "push" and (actors[id]["traits"].get("child", false) or actors[id]["traits"].get("injured", false)):
				continue
			members.append(id)
	var spec: Dictionary = Catalog.data()["interactions"][kind]
	if members.size() < spec["roles"].size():
		return
	var scene = Interaction.new()
	scene.setup(kind, spec)
	interactions[car_id] = scene
	for i in spec["roles"].size():
		var id: int = members[i]
		var a: Dictionary = actors[id]
		var b: Node3D = a["body"]
		a["interaction"] = car_id
		a["state"] = "call" if b.state == "visit" and b.errand.get("id", "") == "call" else _interaction_state(kind)
		a["event"] = "partners_arrived"
		a["before_interaction"] = _snapshot(b)
		_serial += 1
		a["movement"] = _serial
		scene.invite(id, i)
		scene.members[i]["movement"] = a["movement"]
	for id in members.slice(0, spec["roles"].size()):
		scene.arrive(id)


func _route(body: Node3D, target: Vector3) -> void:
	var a: Dictionary = actors[body.get_instance_id()]
	_serial += 1
	a["movement"] = _serial
	a["waypoints"] = [Vector3(body.position.x, 0, host.AISLE_Z), Vector3(target.x, 0, host.AISLE_Z), target]
	body.goal_x = target.x
	# It sets off from the facing a gesture turned from; the next motion starts afresh.
	Motion.show(body, "", 0.0)
	a["motion"] = ""


func _interaction_state(kind: String) -> String:
	match kind:
		"care", "help": return "heal"
		"council": return "session"
		"push", "strike": return "gather"
		"chat", "tap": return "idle"
	return "work"


func moving_count(car_id: String) -> int:
	var c: Dictionary = host.car(car_id)
	var bodies: Array = c.get("bodies", [])
	return bodies.filter(func(b): return b.visible and b.state in ["pace", "out", "back"]).size()


func _blocked(c: Dictionary, except: Array) -> Array:
	var positions: Array = []
	for b in c["bodies"]:
		if b.visible and not except.has(b.get_instance_id()) and b.state == "seat":
			positions.append(b.position)
	return positions


## The hour's lamps are the light board's (train_light.gd: lit at night, low by day);
## here only the train's motion sways them and the coal keeps the stove.
func _apply_light(c: Dictionary, context: Dictionary) -> void:
	if context["motion"] == "stopped":
		c["lamp_sway"] = float(Catalog.tuning("stopped_sway"))
	elif context["motion"] == "departing":
		c["lamp_sway"] = float(c["lamp_sway"]) * float(Catalog.tuning("departing_sway"))
	if c.has("stove_light") and not context["coal"]:
		c["stove_light"].light_energy = 0.0
		c["steam"].emitting = false


func _leave_interaction(a: Dictionary, why: String) -> void:
	var car_id: String = a["interaction"]
	if interactions.has(car_id):
		interactions[car_id].interrupt(why)
	a["interaction"] = ""
	a.erase("before_interaction")


func _end_evacuation(id: int, restore_home: bool = true) -> bool:
	if not actors.has(id):
		return false
	var a: Dictionary = actors[id]
	if not a.get("evacuating", false) and not a["safe_arrival"] and not a.has("before_evacuation"):
		return false
	var b: Node3D = a["body"]
	var previous: Dictionary = a.get("before_evacuation", {})
	var hidden: bool = not b.visible
	places.release(id)
	a["evacuating"] = false
	a["safe_arrival"] = false
	a["waypoints"] = []
	a["requested"] = ""
	a["activity"] = ""
	a["distraction"] = ""
	a.erase("restore")
	a.erase("before_evacuation")
	var recover: bool = restore_home and not previous.is_empty() and contexts.has(a["home"])
	if recover:
		b.slot = previous["slot"]
	if recover and (hidden or not contexts[a["home"]]["fire"]):
		if hidden or b.position.is_equal_approx(previous["position"]):
			b.position = previous["position"]
			b.state = "seat"
			b.set_pose(previous["pose"], b.huddled, b.bowed)
			_face_saved(b, previous)
		else:
			a["restore"] = previous
			_route(b, previous["position"])
			b.state = "pace"
	else:
		b.state = "wait"
		b.timer = float(Catalog.tuning("slot_return_delay"))
	b.visible = true
	a["state"] = Schedule.main_state(contexts[a["home"]], a["traits"]) if contexts.has(a["home"]) else "idle"
	return true


func _evacuate(c: Dictionary) -> void:
	var moving: int = 0
	for b in c["bodies"]:
		if actors.get(b.get_instance_id(), {}).get("evacuating", false):
			moving += 1
	for b in c["bodies"]:
		if moving >= int(Catalog.tuning("max_movers")):
			return
		if not actors.has(b.get_instance_id()):
			continue
		var a: Dictionary = actors[b.get_instance_id()]
		if a["safe_arrival"] or a.get("evacuating", false):
			continue
		var id: int = b.get_instance_id()
		var previous: Dictionary = a.get("restore", a.get("before_interaction", {}))
		var home: Dictionary = {"state": "seat", "position": b.slot, "slot": b.slot, "pose": b.pose}
		if b.state == "seat":
			home["facing"] = _facing_of(b)
		if previous.get("state", "") == "seat":
			home = previous.duplicate(true)
		# 피난처를 먼저 잡는다. 어느 곳도 못 잡으면 하던 일과 예약을 그대로 두고 다음 틱에 다시 본다.
		if not _secure_refuge(c, id):
			continue
		_leave_interaction(a, "accident")
		a.erase("restore")
		a["waypoints"] = []
		a["requested"] = ""
		a["distraction"] = ""
		# A fire interrupts a trip without leaving its old departure counter.
		if b.state in ["out", "visit", "back"]:
			c["out"] = maxi(0, int(c["out"]) - 1)
			b.visit_car = ""
			b.errand = {}
		b.timer = float(Catalog.tuning("slot_return_delay"))
		a["before_evacuation"] = home
		a["evacuating"] = true
		a["activity"] = "refuge"
		_route(b, places.target(id))
		b.state = "pace"
		moving += 1


## 가까운 칸부터 피난처 후보를 하나씩 잡아 본다. transfer()는 실패하면 옛 예약을 그대로 되돌린다.
func _secure_refuge(c: Dictionary, id: int) -> bool:
	for direction in [-1, 1]:
		var n: int = int(c["index"]) + direction
		if n < 0 or n >= host.cars.size():
			continue
		var target_car: Dictionary = host.cars[n]
		if not contexts.get(target_car["id"], {}).get("safe", false):
			continue
		for spot in places.candidates(target_car["id"], ["refuge"]):
			if places.transfer(id, spot):
				return true
	return false
