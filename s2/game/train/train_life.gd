extends RefCounted
## The visible lifecycle. Body.state remains locomotion; state here is the one
## event-selected purpose. Neither this nor its helpers writes simulation values.

const Catalog = preload("res://game/train/train_catalog.gd")
const Context = preload("res://game/train/train_context.gd")
const Places = preload("res://game/train/train_places.gd")
const Schedule = preload("res://game/train/train_schedule.gd")
const Interaction = preload("res://game/train/train_interaction.gd")
const Motion = preload("res://game/train/train_motion_contract.gd")
const Interior = preload("res://game/train/train_interior.gd")

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
	for car_id in interactions.keys():
		interactions[car_id].interrupt("rules")
		_finish(car_id, true)


func add_car(c: Dictionary) -> void:
	places.add_car(c["def"], float(c["x0"]))
	var room = Interior.new()
	room.build(c["node"], c["def"], func(at: Vector3) -> void: host._build_stove(c, at))
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
	event_count += 1
	last_event = event
	contexts.clear()
	var alive: Dictionary = {}
	for c in host.cars:
		var context := Context.read(host.rules, c["def"])
		contexts[c["id"]] = context
		rooms[c["id"]].apply(context)
		_apply_light(c, context)
		var supplied: Dictionary = host.rules.get("view", {}).get("actors", {}).get(c["id"], {})
		for i in c["bodies"].size():
			var body: Node3D = c["bodies"][i]
			var id := body.get_instance_id()
			alive[id] = true
			if not actors.has(id):
				actors[id] = {"body": body, "home": c["id"], "activity": "", "state": "idle", "waypoints": [],
					"turn": i, "interaction": "", "distraction": "", "distraction_left": 0.0,
					"distraction_due": float(Catalog.tuning("distraction_every")[0]) + i,
					"requested": "", "traits": {}, "safe_arrival": false}
			var a: Dictionary = actors[id]
			a["traits"] = (supplied.get(str(i), {}) as Dictionary).duplicate(true)
			if context["layout"] == "medical" and i < mini(int(context["patient_count"]), int(Catalog.tuning("medical_beds"))) and not supplied.has(str(i)):
				a["traits"]["injured"] = true
				a["traits"]["aggregate_patient"] = true
			if not a["traits"].has("role"):
				if context["layout"] == "technical":
					a["traits"]["role"] = "worker"
				elif context["layout"] == "medical" and not a["traits"].get("injured", false) and not a["traits"].get("sick", false):
					a["traits"]["role"] = "carer"
				elif context["layout"] == "dining" and not a["traits"].get("child", false):
					a["traits"]["role"] = "cook"
			a["preferred"] = Schedule.preferences(context, a["traits"])
			a["distractions"] = Schedule.distractions(context, a["traits"])
			a["state"] = Schedule.main_state(context, a["traits"])
			a["event"] = event_count
			body.set_meta("life", a)
			if not context["fire"]:
				body.visible = true
				a["safe_arrival"] = false
			if context["voting"]:
				a["distraction"] = ""
				Motion.Backend.show(body, "", 0.0)
		if context["voting"]:
			send_signal("vote", c["id"])
		elif context["accident"]:
			send_signal("accident", c["id"])
	for id in actors.keys():
		if not alive.has(id):
			places.release(int(id))
			for scene in interactions.values():
				if scene.members.any(func(m): return int(m["actor"]) == int(id)):
					scene.interrupt("actor_removed")
			actors.erase(id)
	for id in places.refresh(contexts):
		cancel(int(id), "closed")
	if outside != null:
		var route := {
			"seg": host.rules.get("train", {}).get("seg", 1),
			"region": host.rules.get("view", {}).get("region", "region_01"),
			"country": host.rules.get("view", {}).get("country", "country_a"),
			"season": host.rules.get("view", {}).get("season", "deep_winter"),
			"weather": host.rules.get("stop", {}).get("weather", "overcast"),
			"layers": host.rules.get("view", {}).get("outside", {}),
		}
		outside.set_meta("route", route)


func choose_local(c: Dictionary, body: Node3D) -> bool:
	var id := body.get_instance_id()
	if not actors.has(id):
		return false
	var a: Dictionary = actors[id]
	if String(a["interaction"]) != "" or contexts[c["id"]]["voting"]:
		return true
	if moving_count(c["id"]) >= int(Catalog.tuning("max_movers")):
		body.timer = float(Catalog.tuning("tick"))
		return true
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
	_route(body, places.target(id))
	body.state = "pace"
	return true


func reserve_trip(body: Node3D, to: Dictionary, row: Dictionary, goal_x: float) -> bool:
	var id := body.get_instance_id()
	if not actors.has(id) or String(actors[id]["interaction"]) != "":
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
		return body.walk(delta)
	while not a["waypoints"].is_empty() and body.position.is_equal_approx(a["waypoints"][0]):
		a["waypoints"].pop_front()
	if a["waypoints"].is_empty():
		body.set_pose("sit" if body.position.y > 0.0 else "stand", false)
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
			body.rotation.y = 0.0
			return true
	return false


func arrived(body: Node3D) -> void:
	var id := body.get_instance_id()
	if not actors.has(id):
		return
	var a: Dictionary = actors[id]
	if a.has("restore"):
		var previous: Dictionary = a["restore"]
		body.state = "seat"
		body.position = previous["position"]
		body.slot = previous["slot"]
		body.set_pose(previous["pose"], body.huddled, body.bowed)
		a.erase("restore")
		return
	if places.arrive(id):
		var s: Dictionary = places.spots[places.bookings[id]]
		body.timer = host.rng.randf_range(float(s["hold"][0]), float(s["hold"][1]))
		var context: Dictionary = contexts[s["car"]]
		a["requested"] = Schedule.gesture(a["activity"], context, a["traits"], int(a["turn"]))
		if a["activity"] in ["sleep", "heal", "mourn"]:
			body.idle_gesture = ""
			Motion.Backend.show(body, "", 0.0)
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
	places.release(id)
	if actors.has(id):
		var a: Dictionary = actors[id]
		a["waypoints"] = []
		a["requested"] = ""
		a["activity"] = ""
		a.erase("restore")
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
		if a["activity"] not in ["sleep", "heal", "mourn"] and not a["distractions"].is_empty() and not contexts[a["home"]]["voting"]:
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
		if contexts[c["id"]]["fire"]:
			_evacuate(c)


func show_body(c: Dictionary, body: Node3D) -> void:
	var id := body.get_instance_id()
	if not actors.has(id) or not body.visible:
		return
	var a: Dictionary = actors[id]
	if contexts[c["id"]]["voting"] or (host._hold_to > host._hold_from and body.position.x >= host._hold_from and body.position.x <= host._hold_to):
		return
	var room: String = a["interaction"]
	if room != "" and interactions.has(room):
		var scene = interactions[room]
		var requested: String = scene.gesture(id)
		if requested != "" and body.state not in ["pace", "out", "back"]:
			Motion.show(body, requested, scene.elapsed, scene.role(id), scene.phase)
		return
	# Existing cold/hunger/fear/resentment gestures retain their precedence.
	if body.gesture != "" or body.state not in ["wait", "visit"]:
		return
	var requested: String = a["distraction"] if a["distraction"] != "" else a["requested"]
	if requested != "":
		Motion.show(body, requested, host.clock, int(a["turn"]) % 2)


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
		a["before_interaction"] = {"state": b.state, "slot": b.slot, "pose": b.pose, "position": b.position}
		scene.invite(id, i)
		if not fixed:
			_route(b, places.target(id))
			b.state = "pace"
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
	var scene = interactions[car_id]
	for m in scene.members:
		var id: int = m["actor"]
		places.release(id)
		if not actors.has(id):
			continue
		var a: Dictionary = actors[id]
		var b: Node3D = a["body"]
		a["interaction"] = ""
		a["state"] = Schedule.main_state(contexts[a["home"]], a["traits"])
		a["event"] = "scene_finished"
		a["requested"] = ""
		a["waypoints"] = []
		Motion.Backend.show(b, "", 0.0, 0, b.rotation.y)
		var previous: Dictionary = a.get("before_interaction", {})
		if previous.get("state", "wait") == "seat":
			if instant or b.position.is_equal_approx(previous["position"]):
				b.state = "seat"
				b.position = previous["position"]
				b.slot = previous["slot"]
				b.set_pose(previous["pose"], b.huddled, b.bowed)
			else:
				a["restore"] = previous
				_route(b, previous["position"])
				b.state = "pace"
		else:
			b.state = "visit" if previous.get("state") == "visit" else "wait"
			b.timer = float(Catalog.tuning("slot_return_delay"))
	if _cleanup.has(car_id):
		if scene.reason == "":
			rooms[car_id].cleanup()
		_cleanup.erase(car_id)
	interactions.erase(car_id)


func _pair_ready(spot_id: String) -> void:
	var spot: Dictionary = places.spots[spot_id]
	var car_id: String = spot["car"]
	if interactions.has(car_id):
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
		a["before_interaction"] = {"state": b.state, "slot": b.slot, "pose": b.pose, "position": b.position}
		scene.invite(id, i)
	for id in members.slice(0, spec["roles"].size()):
		scene.arrive(id)


func _route(body: Node3D, target: Vector3) -> void:
	var a: Dictionary = actors[body.get_instance_id()]
	a["waypoints"] = [Vector3(body.position.x, 0, host.AISLE_Z), Vector3(target.x, 0, host.AISLE_Z), target]
	body.goal_x = target.x
	Motion.Backend.show(body, "", 0.0, 0, body.rotation.y)


func _interaction_state(kind: String) -> String:
	match kind:
		"care", "help": return "heal"
		"council": return "session"
		"push", "strike": return "gather"
		"chat", "tap": return "idle"
	return "work"


func moving_count(car_id: String) -> int:
	var c: Dictionary = host.car(car_id)
	return c["bodies"].filter(func(b): return b.visible and b.state in ["pace", "out", "back"]).size()


func _blocked(c: Dictionary, except: Array) -> Array:
	var positions: Array = []
	for b in c["bodies"]:
		if b.visible and not except.has(b.get_instance_id()) and b.state == "seat":
			positions.append(b.position)
	return positions


func _apply_light(c: Dictionary, context: Dictionary) -> void:
	if context["night"]:
		c["lamp_energy"] = float(c["lamp_energy"]) * float(Catalog.tuning("night_lamp"))
	if context["motion"] == "stopped":
		c["lamp_sway"] = float(Catalog.tuning("stopped_sway"))
	elif context["motion"] == "departing":
		c["lamp_sway"] = float(c["lamp_sway"]) * float(Catalog.tuning("departing_sway"))
	if c.has("stove_light") and not context["coal"]:
		c["stove_light"].light_energy = 0.0
		c["steam"].emitting = false


func _evacuate(c: Dictionary) -> void:
	var moving: int = 0
	for b in c["bodies"]:
		if actors[b.get_instance_id()].get("evacuating", false):
			moving += 1
	for b in c["bodies"]:
		if moving >= int(Catalog.tuning("max_movers")):
			return
		var a: Dictionary = actors[b.get_instance_id()]
		if a["safe_arrival"] or a.get("evacuating", false):
			continue
		for direction in [-1, 1]:
			var n: int = int(c["index"]) + direction
			if n < 0 or n >= host.cars.size():
				continue
			var target_car: Dictionary = host.cars[n]
			if not contexts[target_car["id"]]["safe"]:
				continue
			var choices := places.candidates(target_car["id"], ["refuge"])
			if choices.is_empty():
				continue
			places.release(b.get_instance_id())
			if places.reserve(b.get_instance_id(), choices[0]):
				# A fire interrupts a trip without leaving its old departure counter.
				if b.state in ["out", "visit", "back"]:
					c["out"] = maxi(0, int(c["out"]) - 1)
					b.visit_car = ""
				a["evacuating"] = true
				a["activity"] = "refuge"
				_route(b, places.target(b.get_instance_id()))
				b.state = "pace"
				moving += 1
				break
