extends Node3D
## The inside of the train, seen from the side with the near wall off: boxes
## for cars, stand-in bodies that sit, huddle and walk the aisle, a few who
## walk to another car and back, and the council in the dining car while the
## session lasts. It only shows the rule values it is given
## (train_rules.gd) and changes none of them. Everything is built in code,
## like the field; the car bodies and the people's clips swap in later.

signal rules_applied

const Rules = preload("res://game/train/train_rules.gd")
const Look = preload("res://game/train/train_look.gd")
const Body = preload("res://game/train/train_body.gd")
const HandPanel = preload("res://game/train/train_panel.gd")
const Gesture = preload("res://game/train/train_gesture.gd")
const Life = preload("res://game/train/train_life.gd")
const Catalog = preload("res://game/train/train_catalog.gd")
const Smoke = preload("res://fx/smoke.gd")
const GlassShader = preload("res://fx/shaders/window_glass.gdshader")

const CAR_LENGTH: float = 16.0          # the field's car (16 x 2.8 x 3)
const CAR_WIDTH: float = 2.8
const CAR_HEIGHT: float = 3.0
const CAR_GAP: float = 1.0
const WALL: float = 0.1
## Across the car: the bench under the far wall, the floor in front of it, the
## aisle nearest the open side. The end doors stand open on the aisle.
const BENCH_Z: float = -0.85
const FLOOR_Z: float = -0.15
const AISLE_Z: float = 0.65
const DOOR_FROM: float = 0.2
const DOOR_TO: float = 1.1
const DOOR_HEIGHT: float = 2.0
const SLOT_FIRST: float = 1.2
const SLOT_STEP: float = 0.95
const BENCH_SLOTS: int = 15
const FLOOR_SHIFT: int = 2              # the floor fills between the bench's pairs
## People standing about gather in threes by the two doorways, beside the
## aisle: two along its edge and the third toward the bench, so the way stays open.
const KNOT_SIZE: int = 3
const KNOT_FROM: float = 1.6
const KNOT_STEP: float = 0.55
const KNOT_APART: float = 2.4
const KNOT_Z: float = 0.15
const KNOT_DEPTH: float = 0.45
const GESTURE_OFFSET: float = 1.3        # seconds between one car's gestures and the next car's
const PROP_META: String = "gesture_prop"
const BOWL_SIZE := Vector3(0.24, 0.08, 0.2)   # the empty bowl of a hungry car: small and pale, in the lap
const BOWL_COLOR := Color(0.8, 0.78, 0.7)
const RESENT_TURN: float = 0.6           # rad: those who resent stand half turned to the captain's car
## The stove stands in front of the bench, between two floor places; a car with
## a table has it by the end wall.
const TABLED: Array = ["dining", "captain"]   # the kinds of car with a table or a desk on the floor places
const STOVE_AT := Vector3(7.85, 0.0, -0.4)
const STOVE_AT_END := Vector3(0.45, 0.0, -0.9)
const STOVE_COLOR := Color(1.0, 0.55, 0.3)
const STOVE_ENERGY: float = 1.1
const LAMP_SWAY: float = 0.05           # metres, with the train's rocking
const LAMP_EASE: float = 1.5            # a mood comes on over a second or so
## The council sits on both sides of the dining table: the far side on the
## bench, the near side with their backs to the open side. The chair and the
## clerk stand by the table's head.
const TABLE_Z: float = 0.15
const TABLE_FIRST: float = 2.9
const TABLE_STEP: float = 0.92
const CHAIR_AT: Array = [Vector3(14.7, 0.0, -0.5), Vector3(15.2, 0.0, -0.05)]
const RISE_SWAY: float = 3.0            # rad a second: someone on their feet rocks from side to side
const RISE_REACH: float = 0.8
const AISLE_MARGIN: float = 1.0
const PACE_WAIT := Vector2(2.0, 6.0)    # a mover stands this long between walks
const VISIT_SPREAD: float = 3.0
## A caller stops just inside the other car's doorway, on the aisle, and one of
## that car's people on their feet comes over.
const CALL_INSIDE: float = 1.0
const CALL_APART: float = 0.7
const CALL_FIRST := Vector2(10.0, 30.0)
const OUT_AT_ONCE: int = 1              # of one car, on a trip or a call to another
const OUT_IN_SESSION: int = 2
const CAM_NEAR: float = 11.0            # metres of height on screen
const CAM_FAR: float = 24.0
const CAM_PITCH: float = -8.0
const CAM_BACK: float = 30.0
const CAM_LOOK_Y: float = -0.3          # below the floor: the panel covers the bottom

var rules: Dictionary = {}
var opts: Dictionary = {}               # seed: int, panel: bool
var problems := PackedStringArray()
var cars: Array = []                    # [{def, id, index, x0, node, bodies, out, errand_t, errand_i, call_t, call_i, mood, unrest, quiet, seats, values}]
var rng := RandomNumberGenerator.new()
var camera: Camera3D
var train: Node3D
var people: Node3D
var panel: CanvasLayer
var cam_x: float = CAR_LENGTH * 0.5
var zoomed_out: bool = false
var clock: float = 0.0
var _hold_from: float = 0.0             # the council room along the train while the vote is called
var _hold_to: float = 0.0
var _mats: Dictionary = {}
var _font: SystemFont
var life = Life.new()


func _ready() -> void:
	rng.seed = int(opts.get("seed", 1))
	life.setup(self)
	if rules.is_empty():
		rules = Rules.load_default()
	problems = Rules.check(rules)
	_build_world()
	if problems.is_empty():
		_build_train()
		life.build_outside()
		apply_rules()
	else:
		push_warning("train rules: %s" % ", ".join(problems))
	if bool(opts.get("panel", true)):
		panel = HandPanel.new()
		panel.scene = self
		add_child(panel)


func _process(delta: float) -> void:
	step(delta)


func phase() -> String:
	return String((rules.get("train", {}) as Dictionary).get("phase", "travel"))


func car(id: String) -> Dictionary:
	for c in cars:
		if c["id"] == id:
			return c
	return {}


## Seat every car again from the rules as they are now.
func apply_rules(event: String = "rules") -> void:
	life.before_refresh()
	var definitions: Array = Rules.display_cars(rules)
	var rebuild: bool = definitions.size() != cars.size()
	if not rebuild:
		for i in definitions.size():
			if definitions[i]["id"] != cars[i]["id"] or Catalog.layout_id(definitions[i]) != Catalog.layout_id(cars[i]["def"]):
				rebuild = true
				break
	if rebuild:
		_rebuild_layout()
	for i in cars.size():
		cars[i]["def"] = definitions[i]
	_hold_from = 0.0
	_hold_to = 0.0
	for c in cars:
		_seat_car(c)
		if _in_session(c) and String(c["quiet"]) == "vote":
			_hold_from = float(c["x0"])
			_hold_to = _hold_from + CAR_LENGTH
	life.refresh(event)
	rules_applied.emit()


func _rebuild_layout() -> void:
	var traces: Dictionary = {}
	for id in life.rooms:
		traces[id] = life.rooms[id].traces.duplicate(true)
	if is_instance_valid(life.outside):
		life.outside.free()
	if is_instance_valid(train):
		train.free()
	cars.clear()
	life = Life.new()
	life.setup(self)
	_build_train()
	life.build_outside()
	for id in life.rooms:
		for prop in life.rooms[id].traces:
			if traces.get(id, {}).has(prop):
				life.rooms[id].traces[prop] = traces[id][prop]
	_place_camera()


## 아래 세 손잡이도 set_value와 같은 길을 쓴다. 사본에 값을 넣어 전체를 검사하고,
## 통과한 사본만 장면에 올린다. 틀린 값은 아무것도 바꾸지 않고 false를 돌려준다.
func set_sit(comm_id: String, i: int, value: float) -> bool:
	var proposed: Dictionary = rules.duplicate(true)
	var sit = _comm_in(proposed, comm_id).get("sit")
	if not (sit is Array) or i < 0 or i >= sit.size():
		return false
	sit[i] = clampf(value, 0.0, 100.0)
	return _accept(proposed, "rules")


func set_comm(comm_id: String, key: String, value) -> bool:
	var proposed: Dictionary = rules.duplicate(true)
	var comm := _comm_in(proposed, comm_id)
	if comm.is_empty():
		return false
	comm[key] = value
	return _accept(proposed, "rules")


func set_train(key: String, value) -> bool:
	var proposed: Dictionary = rules.duplicate(true)
	if not (proposed.get("train") is Dictionary):
		return false
	proposed["train"][key] = value
	return _accept(proposed, key)


## The test panel and a future port submit the same snapshot fields.
func set_value(path: String, value) -> bool:
	var proposed: Dictionary = rules.duplicate(true)
	Catalog.assign_value(proposed, path, value)
	return _accept(proposed, path)


## 검사를 통과한 사본만 규칙 값이 되어 장면에 놓인다.
func _accept(proposed: Dictionary, event: String) -> bool:
	if not Rules.check(proposed).is_empty():
		return false
	rules = proposed
	apply_rules(event)
	return true


func _comm_in(source: Dictionary, comm_id: String) -> Dictionary:
	var comms = source.get("comms")
	if not (comms is Dictionary) or not (comms.get(comm_id) is Dictionary):
		return {}
	return comms[comm_id]


func life_signal(cue: String, car_id: String = "") -> void:
	life.send_signal(cue, car_id)


## One tick of the people: movers pace their own aisle, and now and then one
## takes a trip with a use to another car or calls at a friendly one, stays
## and comes back.
func step(delta: float) -> void:
	clock += delta
	life.advance(delta)
	for c in cars:
		_step_lamp(c, delta)
		_step_errand(c, delta)
		_step_call(c, delta)
		if _in_session(c):
			_step_council(c, delta)
		for b in c["bodies"]:
			_step_body(c, b, delta)
			_idle(c, b)
			if b.gesture != "":
				_show_gesture(c, b)
			life.show_body(c, b)


func scroll(metres: float) -> void:
	cam_x = clampf(cam_x + metres, 0.0, maxf(train_length(), 0.0))
	_place_camera()


func focus_car(id: String) -> void:
	var c := car(id)
	if c.is_empty():
		return
	cam_x = float(c["x0"]) + CAR_LENGTH * 0.5
	_place_camera()


func toggle_zoom() -> void:
	zoomed_out = not zoomed_out
	_place_camera()


func train_length() -> float:
	return cars.size() * (CAR_LENGTH + CAR_GAP) - CAR_GAP


## The line under a car's name: its numbers, its head count and its mood, or
## for the council its step of unrest.
func values_text(c: Dictionary) -> String:
	var comm := Rules.comm_of(rules, c["def"])
	var state: String = Look.MOOD_NAMES[c["mood"]]
	if _in_session(c):
		var level: int = c["unrest"]
		state = Look.QUIET_NAMES.get(c["quiet"], "소란 %d %s" % [level, Look.UNREST_NAMES[level]])
	var heads := "%d명 · %s" % [(c["bodies"] as Array).size(), state]
	if comm.is_empty():
		return heads
	var sit: Array = comm["sit"]
	var parts: Array = []
	for i in 4:
		parts.append("%s %d" % [Rules.SIT_NAMES[i], roundi(float(sit[i]))])
	parts.append("관계 %d" % roundi(float(comm.get("rel", 0))))
	parts.append(heads)
	return " · ".join(parts)


func _unhandled_input(event: InputEvent) -> void:
	if camera == null:
		return
	var dx: float = 0.0
	if event is InputEventScreenDrag:
		dx = event.relative.x
	elif event is InputEventMouseMotion and not DisplayServer.is_touchscreen_available() \
			and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		dx = event.relative.x
	if dx != 0.0:
		scroll(-dx * camera.size / maxf(get_viewport().get_visible_rect().size.y, 1.0))


func _seat_car(c: Dictionary) -> void:
	var comm := Rules.comm_of(rules, c["def"])
	var n := Look.figures(c["def"], comm, phase())
	if bool(Catalog.layout(c["def"]).get("storage_only", false)):
		n = 0
	var w := Look.warmth(comm)
	var m := Look.mood(comm, rules.get("train", {}))
	var look := Look.mood_look(m)
	c["mood"] = m
	var bodies: Array = c["bodies"]
	while bodies.size() > n:
		var gone: Node3D = bodies.pop_back()
		_end_trip(c, gone)
		people.remove_child(gone)
		gone.queue_free()
	while bodies.size() < n:
		var b := Body.new()
		people.add_child(b)
		b.setup(c["id"], bodies.size() + int(c["index"]) * 5)
		bodies.append(b)
	for b in bodies:
		b.speed = Body.WALK_SPEED * float(look["speed"])
	if _in_session(c):
		_seat_council(c)
	else:
		c["unrest"] = -1
		c["quiet"] = ""
		# The dining table and the captain's desk stand where the floor places are.
		var open_floor: bool = not TABLED.has(String((c["def"] as Dictionary).get("kind", "")))
		_seat_rows(c, Look.seating(n, w, Look.crowding(comm), m, open_floor), bool(look["gather"]))
	_dress_car(c, w, look)
	(c["values"] as Label3D).text = values_text(c)


## The dining car while the council sits.
func _in_session(c: Dictionary) -> bool:
	return String((c["def"] as Dictionary).get("kind", "")) == "dining" and phase() == "council"


## Seat a car as its mood, its warmth and its crowding have it.
func _seat_rows(c: Dictionary, rows: Array, gather: bool) -> void:
	var bodies: Array = c["bodies"]
	var walkers: int = 0
	for row in rows:
		walkers += 1 if row["pose"] == "walk" else 0
	var standing: int = 0
	var bench: int = 0
	var on_floor: int = 0
	var x0: float = c["x0"]
	var standers: int = 0
	var bench_rows: int = 0
	var floor_rows: int = 0
	for row in rows:
		standers += 1 if row["pose"] == "stand" else 0
		bench_rows += 1 if row["pose"] == "sit" else 0
		floor_rows += 1 if row["pose"] == "floor" else 0
	var comm := Rules.comm_of(rules, c["def"])
	var value := Look.gesture_for(c["mood"], rules.get("train", {}), comm)
	var also := Look.gesture_also(value, comm)
	var gestures := Look.knot_gestures(value, standers, int(c["index"]), also)
	# Resentment has somewhere to look: up or down the train, at the captain's car.
	var toward_captain: float = _captain_side(c) * RESENT_TURN
	var idle := Look.idle_gestures(value, walkers)
	var walked: int = 0
	var sat := Look.bench_gestures(value, bench_rows)
	var low := Look.floor_gestures(value, floor_rows)
	for i in bodies.size():
		var b: Node3D = bodies[i]
		var row: Dictionary = rows[i]
		match String(row["pose"]):
			"walk":
				_walk_from(c, b, _aisle_place(x0, i, walkers))
				# In a cold car one who walks rubs its hands while it stands between walks.
				b.idle_gesture = idle[walked]["name"]
				b.gesture_role = int(idle[walked]["role"])
				_idle(c, b)
				walked += 1
			"stand":
				# A pair in a gesture stands as far apart as the gesture has them.
				var g: Dictionary = gestures[standing]
				var pair_of: String = String(gestures[0]["name"])
				var wide: float = float(Gesture.PAIR_GAP.get(pair_of, KNOT_STEP)) - KNOT_STEP if standing < KNOT_SIZE else 0.0
				# One who shows a second value comes out from behind the pair and stands beside it.
				var whose: String = String(g["of"])
				var aside: bool = whose != "" and whose != value
				_sit_down(c, b, x0, _knot_place(standing, wide, aside), "stand", false, false)
				b.rotation.y = _knot_facing(standing)
				b.gesture = g["name"]
				b.gesture_role = int(g["role"])
				b.gesture_facing = toward_captain if whose == "resent" else 0.0
				if b.gesture != "":
					_show_gesture(c, b)
				standing += 1
			"sit":
				var seat := Vector3(SLOT_FIRST + Look.seat_slot(bench, BENCH_SLOTS, gather) * SLOT_STEP, 0, BENCH_Z)
				_sit_down(c, b, x0, seat, "sit", bool(row["huddled"]), bool(row["bowed"]))
				# In a hungry car the first two on the bench hold an empty bowl.
				_seat_gesture(c, b, sat[bench], bool(row["huddled"]))
				bench += 1
			_:
				# The stove stands between two floor places: gathered, the floor fills on both sides of it.
				var slot: int = (on_floor * Look.SLOT_STRIDE + FLOOR_SHIFT) % BENCH_SLOTS
				if gather:
					slot = maxi(Look.seat_slot(on_floor, BENCH_SLOTS, true) - 1, 0)
				var place := Vector3(SLOT_FIRST + SLOT_STEP * 0.5 + slot * SLOT_STEP, 0, FLOOR_Z)
				_sit_down(c, b, x0, place, "floor", bool(row["huddled"]), bool(row["bowed"]))
				# In a frightened car the first few on the floor hug their knees; in a hungry one two lie back.
				_seat_gesture(c, b, low[on_floor], bool(row["huddled"]))
				on_floor += 1


## Seat the dining car as the council: everyone keeps the same place whatever
## the unrest, and only the step, the hush of fear and the called vote change
## what the room does. No community's own numbers reach a seat.
func _seat_council(c: Dictionary) -> void:
	var train: Dictionary = rules.get("train", {})
	var level := Look.unrest_level(Look.unrest_score(train, rules.get("comms", {})), int(c["unrest"]))
	var quiet := Look.council_quiet(train)
	var hushed: bool = quiet == "hush"
	c["unrest"] = level
	c["quiet"] = quiet
	var bodies: Array = c["bodies"]
	var places := Look.council_places(bodies.size())
	var walkers: int = places.count("walk")
	var hold: Array = Look.UNREST_LOOK[level]["hold"]
	var x0: float = c["x0"]
	var taken: Dictionary = {}
	var seat: int = 0
	for i in bodies.size():
		var b: Node3D = bodies[i]
		var place: String = places[i]
		var k: int = int(taken.get(place, 0))
		taken[place] = k + 1
		match place:
			"walk":
				# In a frightened room those who walked stand where they were.
				if hushed:
					_sit_down(c, b, 0.0, _aisle_place(x0, k, walkers), "stand", false, true)
				else:
					_walk_from(c, b, _aisle_place(x0, k, walkers))
			"chair":
				_sit_down(c, b, x0, CHAIR_AT[k % CHAIR_AT.size()], "stand", false, hushed)
				b.rotation.y = -PI * 0.5
			"door":
				_sit_down(c, b, x0, _knot_place(k), "stand", false, hushed)
				b.rotation.y = _knot_facing(k)
			_:
				var at := Vector3(SLOT_FIRST + k * SLOT_STEP, 0, BENCH_Z)
				if place == "table":
					at = Vector3(TABLE_FIRST + k * TABLE_STEP, 0, TABLE_Z)
				# A gesture under way carries on when a number changes; a quiet room drops it at once.
				var same: bool = b.seat == seat
				var act: String = b.act if same and quiet == "" else ""
				_sit_down(c, b, x0, at, "sit", false, hushed)
				b.rotation.y = PI if place == "table" else 0.0
				b.seat = seat
				b.act = act
				if not same:
					b.act_t = rng.randf_range(float(hold[0]), float(hold[1]))
				_show_act(b)
				seat += 1
	c["seats"] = seat


## Where along the aisle the k-th of a car's walkers belongs.
func _aisle_place(x0: float, k: int, walkers: int) -> Vector3:
	return Vector3(x0 + AISLE_MARGIN + (CAR_LENGTH - 2.0 * AISLE_MARGIN) * (k + 0.5) / maxi(walkers, 1), 0, AISLE_Z)


## A body that walks: it keeps on with what it was doing, or gets up if it sat.
func _walk_from(c: Dictionary, b: Node3D, at: Vector3) -> void:
	b.slot = at
	_plain(b)
	if b.state == "seat":
		b.position = b.slot
		b.rotation.y = 0.0
		b.set_pose("stand", false)
		_wait(c, b)


## Out of the council's gestures and of any gesture of a bad value.
func _plain(b: Node3D) -> void:
	b.side = 0.0
	b.seat = -1
	b.act = ""
	b.idle_gesture = ""
	if b.gesture != "":
		Gesture.show(b, "", 0.0)
		_show_prop(b, {})
		b.gesture = ""
		b.gesture_facing = 0.0


## Draw the gesture a body is in, at the car's own beat. The gesture turns
## the body itself, from where it was set to face.
func _show_gesture(c: Dictionary, b: Node3D) -> void:
	var t: float = clock + float(c["index"]) * GESTURE_OFFSET
	Gesture.show(b, b.gesture, t, b.gesture_role, b.gesture_facing)
	_show_prop(b, Gesture.at(b.gesture, t, b.gesture_role).get("prop", {}))


## One who walks falls into its idle gesture while it stands between walks
## (in a cold car: hands rubbed, feet stamped) and drops it to walk on.
func _idle(c: Dictionary, b: Node3D) -> void:
	if b.idle_gesture == "":
		return
	if b.state == "wait" and b.gesture == "":
		b.gesture = b.idle_gesture
		b.gesture_facing = 0.0
		_show_gesture(c, b)
	elif b.state != "wait" and b.gesture == b.idle_gesture:
		# One sent off on a trip has already turned to walk this step: it keeps that facing.
		Gesture.show(b, "", 0.0, 0, b.rotation.y)
		_show_prop(b, {})
		b.gesture = ""


## Put one who sits in its gesture, unless the cold has hunched it up first.
func _seat_gesture(c: Dictionary, b: Node3D, g: Dictionary, huddled: bool) -> void:
	b.gesture = String(g["name"]) if Look.takes(String(g["name"]), huddled) else ""
	b.gesture_role = int(g["role"])
	b.gesture_facing = 0.0
	if b.gesture != "":
		_show_gesture(c, b)


## What a gesture has in its hands (the empty bowl of the hungry). The
## gesture says only where it is held: the small box is made here the first
## time and kept. {} puts it away.
func _show_prop(b: Node3D, prop: Dictionary) -> void:
	if not b.has_meta(PROP_META):
		if prop.is_empty():
			return
		b.set_meta(PROP_META, _box(b, BOWL_SIZE, Vector3.ZERO, BOWL_COLOR))
	var held: MeshInstance3D = b.get_meta(PROP_META)
	held.visible = not prop.is_empty()
	if held.visible:
		held.position = prop["pos"]


## Which way along the train the captain's car lies from this one: 1 ahead,
## -1 behind, 0 when this is it or there is none.
func _captain_side(c: Dictionary) -> float:
	for other in cars:
		if String((other["def"] as Dictionary).get("kind", "")) == "captain":
			return signf(float(other["x0"]) - float(c["x0"]))
	return 0.0


## The gesture a seated member of the council is in: up on their feet, leaning
## over to a neighbour, or sitting still.
func _show_act(b: Node3D) -> void:
	b.side = 0.0
	match String(b.act):
		"rise":
			b.set_pose("stand", false, b.bowed)
		"lean":
			b.side = 1.0 if b.seat % 2 == 0 else -1.0
			b.set_pose("sit", false, b.bowed)
		_:
			b.set_pose("sit", false, b.bowed)


## The seated who act take turns: a gesture, a rest, a gesture. A higher step
## brings more of them in as their rests run out, and they finish what they
## were doing when the room cools.
func _step_council(c: Dictionary, delta: float) -> void:
	if String(c["quiet"]) != "":
		return
	var level: int = c["unrest"]
	var hold: Array = Look.UNREST_LOOK[level]["hold"]
	for b in c["bodies"]:
		if b.seat < 0:
			continue
		var role := Look.council_role(b.seat, int(c["seats"]), level)
		if role == "" and String(b.act) == "":
			continue
		if String(b.act) == "rise":
			# Whoever is on their feet does not stand still.
			b.side = sin(clock * RISE_SWAY + float(b.seat)) * RISE_REACH
			b.show_pose()
		b.act_t -= delta
		if b.act_t <= 0.0:
			b.act = role if String(b.act) == "" else ""
			b.act_t = rng.randf_range(float(hold[0]), float(hold[1]))
			_show_act(b)



## Where in the car the k-th of those standing about stands: knots of three,
## by the tail-end doorway and the front-end one in turn. `wide` sets the
## first two of a knot that much further apart. `aside` brings the third out
## from behind them: a step beyond the second, on the same line.
func _knot_place(k: int, wide: float = 0.0, aside: bool = false) -> Vector3:
	var knot: int = k / KNOT_SIZE
	var member: int = k % KNOT_SIZE
	var along: float = KNOT_FROM + (knot / 2) * KNOT_APART
	var behind: bool = member == 2 and not aside
	if member == 1:
		along += KNOT_STEP + wide
	elif behind:
		along += (KNOT_STEP + wide) * 0.5
	elif member == 2:
		along += KNOT_STEP + wide + KNOT_STEP
	var x: float = along if knot % 2 == 0 else CAR_LENGTH - along
	return Vector3(x, 0, KNOT_Z - (KNOT_DEPTH if behind else 0.0))


## The three of a knot face one another.
func _knot_facing(k: int) -> float:
	var knot: int = k / KNOT_SIZE
	var member: int = k % KNOT_SIZE
	if member == 2:
		return 0.0
	var toward_front: bool = (member == 0) == (knot % 2 == 0)
	return PI * 0.5 if toward_front else -PI * 0.5


## The lamp, the stove and the window frost follow the car's mood and warmth.
func _dress_car(c: Dictionary, w: float, look: Dictionary) -> void:
	c["lamp_color"] = look["lamp"]
	c["lamp_energy"] = float(look["energy"])
	c["lamp_sway"] = float(look["sway"])
	(c["glass"] as ShaderMaterial).set_shader_parameter("cold_car", Look.frost(w))
	if c.has("stove_light"):
		var burn := Look.stove(w)
		(c["stove_light"] as OmniLight3D).light_energy = STOVE_ENERGY * burn
		(c["steam"] as GPUParticles3D).emitting = burn >= Look.STOVE_STEAM_FROM


func _step_lamp(c: Dictionary, delta: float) -> void:
	var lamp: OmniLight3D = c["lamp"]
	var ease_by := minf(1.0, delta * LAMP_EASE)
	lamp.light_color = lamp.light_color.lerp(c["lamp_color"], ease_by)
	lamp.light_energy = lerpf(lamp.light_energy, float(c["lamp_energy"]), ease_by)
	lamp.position.x = CAR_LENGTH * 0.5 + sin(clock * 1.3 + float(c["index"])) * LAMP_SWAY * float(c["lamp_sway"])


func _sit_down(c: Dictionary, b: Node3D, x0: float, at: Vector3, pose: String, huddled: bool, bowed: bool) -> void:
	_end_trip(c, b)
	b.state = "seat"
	b.slot = at + Vector3(x0, 0, 0)
	b.position = b.slot
	b.rotation.y = 0.0
	_plain(b)
	b.set_pose(pose, huddled, bowed)


func _end_trip(c: Dictionary, b: Node3D) -> void:
	if b.state == "out" or b.state == "visit" or b.state == "back":
		c["out"] = int(c["out"]) - 1
	b.visit_car = ""
	life.end_trip(b)


func _step_body(c: Dictionary, b: Node3D, delta: float) -> void:
	if life.contexts.get(c["id"], {}).get("fire", false) and not life.actors.get(b.get_instance_id(), {}).get("evacuating", false):
		return
	# While the vote is called nobody on their feet in the council room moves.
	if _hold_to > _hold_from and b.state != "seat" and b.position.x >= _hold_from and b.position.x <= _hold_to:
		if b.pose == "walk":
			b.set_pose("stand", false)
		return
	match b.state:
		"wait":
			if life.held(b):
				return
			b.timer -= delta
			if b.timer <= 0.0:
				if not life.choose_local(c, b):
					b.goal_x = rng.randf_range(float(c["x0"]) + AISLE_MARGIN, float(c["x0"]) + CAR_LENGTH - AISLE_MARGIN)
					b.state = "pace"
		"pace":
			if life.walk(b, delta):
				_wait(c, b)
				life.arrived(b)
		"out":
			if life.walk(b, delta):
				b.state = "visit"
				b.timer = float(b.errand.get("stay", 5.0))
				life.arrived(b)
		"visit":
			# A caller waits for the first of the car who is free to come over.
			if String(b.errand.get("id", "")) == "call" and not bool(b.errand.get("met", false)):
				b.errand["met"] = _greet(b)
			if life.held(b):
				return
			b.timer -= delta
			if b.timer <= 0.0:
				b.goal_x = b.slot.x
				b.state = "back"
				life.return_route(b)
		"back":
			if life.walk(b, delta):
				_end_trip(c, b)
				_wait(c, b)


## A calm mover stands a few seconds between walks; a stirred one hardly stops.
func _wait(c: Dictionary, b: Node3D) -> void:
	b.state = "wait"
	b.timer = rng.randf_range(PACE_WAIT.x, PACE_WAIT.y) * float(Look.mood_look(c["mood"])["wait"])


func _step_errand(c: Dictionary, delta: float) -> void:
	if _hold_to > _hold_from or life.contexts.get(c["id"], {}).get("fire", false):
		return                      # nobody sets out while the vote is called
	c["errand_t"] = float(c["errand_t"]) - delta
	if float(c["errand_t"]) > 0.0:
		return
	var rows := Look.errands_for(c["def"], phase(), rules.get("errands", []))
	if rows.is_empty():
		c["errand_t"] = PACE_WAIT.y
		return
	var row: Dictionary = rows[int(c["errand_i"]) % rows.size()]
	c["errand_i"] = int(c["errand_i"]) + 1
	c["errand_t"] = float(row["every"]) * rng.randf_range(0.8, 1.2) * float(Look.mood_look(c["mood"])["wait"])
	if int(c["out"]) >= (OUT_IN_SESSION if phase() == "council" else OUT_AT_ONCE):
		return
	var to := car(String(row["to"]))
	if to.is_empty():
		return
	_send(c, to, row, float(to["x0"]) + CAR_LENGTH * 0.5 + rng.randf_range(-VISIT_SPREAD, VISIT_SPREAD))


## Now and then one mover calls at a car its own is on good terms with: stops
## in the doorway, has a word with whoever is about and walks home (2026-10-12:
## calls between friendly cars, on top of the trips with a use). For show only.
func _step_call(c: Dictionary, delta: float) -> void:
	var calls: Dictionary = rules.get("calls", {})
	if calls.is_empty() or not Look.calls_open(c["mood"], phase()) or life.contexts.get(c["id"], {}).get("fire", false):
		return
	c["call_t"] = float(c["call_t"]) - delta
	if float(c["call_t"]) > 0.0:
		return
	c["call_t"] = float(calls["every"]) * rng.randf_range(0.8, 1.2) * float(Look.mood_look(c["mood"])["wait"])
	var doors := Look.calls_for(c["def"], rules["cars"], rules.get("ideo", {}), float(calls.get("within", 0.0)))
	if doors.is_empty() or int(c["out"]) >= OUT_AT_ONCE:
		return
	var to := car(String(doors[int(c["call_i"]) % doors.size()]))
	c["call_i"] = int(c["call_i"]) + 1
	if to.is_empty() or not Look.calls_open(to["mood"], phase()):
		return
	var ahead: bool = float(to["x0"]) > float(c["x0"])
	var door: float = float(to["x0"]) + (CALL_INSIDE if ahead else CAR_LENGTH - CALL_INSIDE)
	_send(c, to, {"id": "call", "to": to["id"], "stay": float(calls["stay"])}, door)


## Send one of the car's movers who stands waiting to `to`; nobody goes when
## all of them are walking.
func _send(c: Dictionary, to: Dictionary, row: Dictionary, goal_x: float) -> void:
	for b in c["bodies"]:
		if b.state == "wait":
			if not life.reserve_trip(b, to, row, goal_x):
				continue
			b.errand = row
			b.visit_car = to["id"]
			b.goal_x = goal_x
			b.state = "out"
			c["out"] = int(c["out"]) + 1
			return


## One of the car's people who stands waiting comes over to the caller; false
## while all of them are walking.
func _greet(caller: Node3D) -> bool:
	var host := car(String(caller.visit_car))
	if host.is_empty():
		return true
	var inward: float = 1.0 if caller.position.x < float(host["x0"]) + CAR_LENGTH * 0.5 else -1.0
	for h in host["bodies"]:
		if h.state == "wait":
			if not life.greet(caller, h):
				continue
			h.goal_x = caller.position.x + inward * CALL_APART
			h.state = "pace"
			return true
	return false


func _build_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.045, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.72)
	env.ambient_light_energy = 0.35
	world.environment = env
	add_child(world)
	# A faint cold fill from the open side, so a body in the aisle is not a black shape.
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.62, 0.7, 0.86)
	fill.light_energy = 0.3
	fill.rotation_degrees = Vector3(-25, 0, 0)
	add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.1
	camera.far = 120.0
	add_child(camera)
	camera.current = true
	_place_camera()
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Pretendard", "Noto Sans CJK KR", "Noto Sans KR", "Droid Sans Fallback", "sans-serif"])


func _place_camera() -> void:
	if camera == null:
		return
	var pitch := deg_to_rad(CAM_PITCH)
	camera.size = CAM_FAR if zoomed_out else CAM_NEAR
	camera.rotation = Vector3(pitch, 0, 0)
	camera.position = Vector3(cam_x, CAM_LOOK_Y, 0) + Vector3(0, -sin(pitch), cos(pitch)) * CAM_BACK


func _build_train() -> void:
	train = Node3D.new()
	train.name = "Train"
	add_child(train)
	people = Node3D.new()
	people.name = "People"
	train.add_child(people)
	var defs: Array = Rules.display_cars(rules)
	for i in defs.size():
		var def: Dictionary = defs[i]
		var node := Node3D.new()
		node.name = "Car_%s" % def["id"]
		node.position.x = i * (CAR_LENGTH + CAR_GAP)
		train.add_child(node)
		var c := {
			"def": def, "id": String(def["id"]), "index": i, "x0": node.position.x, "node": node,
			"bodies": [], "out": 0, "errand_t": rng.randf_range(2.0, 8.0), "errand_i": 0, "mood": "calm",
			"call_t": rng.randf_range(CALL_FIRST.x, CALL_FIRST.y), "call_i": 0,
			"unrest": -1, "quiet": "", "seats": 0,
		}
		_build_car(c, i < defs.size() - 1)
		cars.append(c)
	_box(train, Vector3(train_length() + 6.0, 0.12, 0.1), Vector3(train_length() * 0.5, -1.5, CAR_WIDTH * 0.5 - 0.3), Color(0.3, 0.3, 0.32))


func _build_car(c: Dictionary, gangway: bool) -> void:
	var node: Node3D = c["node"]
	var def: Dictionary = c["def"]
	var kind := String(def.get("kind", ""))
	var steel := Color(0.2, 0.2, 0.21)
	var wood := Color(0.3, 0.25, 0.2)
	var l := CAR_LENGTH
	var w := CAR_WIDTH
	var h := CAR_HEIGHT
	_box(node, Vector3(l, 0.15, w), Vector3(l * 0.5, -0.075, 0), wood)
	_box(node, Vector3(l, h, WALL), Vector3(l * 0.5, h * 0.5, -w * 0.5), wood.darkened(0.2))
	_box(node, Vector3(l + 0.2, 0.15, w + 0.2), Vector3(l * 0.5, h + 0.075, 0), steel)
	# End walls with an open doorway on the aisle.
	for x in [0.0, l]:
		_box(node, Vector3(WALL, h, DOOR_FROM + w * 0.5), Vector3(x, h * 0.5, (DOOR_FROM - w * 0.5) * 0.5), wood.darkened(0.3))
		_box(node, Vector3(WALL, h, w * 0.5 - DOOR_TO), Vector3(x, h * 0.5, (DOOR_TO + w * 0.5) * 0.5), wood.darkened(0.3))
		_box(node, Vector3(WALL, h - DOOR_HEIGHT, DOOR_TO - DOOR_FROM), Vector3(x, DOOR_HEIGHT + (h - DOOR_HEIGHT) * 0.5, (DOOR_FROM + DOOR_TO) * 0.5), wood.darkened(0.3))
	# Windows: the field's glass, so frost grows in from the frame as the car cools.
	var glass := ShaderMaterial.new()
	glass.shader = GlassShader
	c["glass"] = glass
	for k in 4:
		var at := Vector3(l * (k + 0.5) / 4.0, 1.75, -w * 0.5 + WALL)
		_box(node, Vector3(1.6, 0.9, 0.02), at, Color(0.07, 0.09, 0.13))
		var pane := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(1.6, 0.9)
		pane.mesh = quad
		pane.material_override = glass
		pane.position = at + Vector3(0, 0, 0.02)
		node.add_child(pane)
	_box(node, Vector3(l, 0.45, w - 0.4), Vector3(l * 0.5, -0.45, 0), steel.darkened(0.2))
	for x in [2.2, 3.6, l - 3.6, l - 2.2]:
		_box(node, Vector3(0.9, 0.9, 0.15), Vector3(x, -1.0, w * 0.5 - 0.3), steel.darkened(0.4))
	if gangway:
		_box(node, Vector3(CAR_GAP, 0.1, DOOR_TO - DOOR_FROM + 0.2), Vector3(l + CAR_GAP * 0.5, -0.05, (DOOR_FROM + DOOR_TO) * 0.5), steel)
	life.add_car(c)
	var calm := Look.mood_look("calm")
	var lamp := OmniLight3D.new()
	lamp.light_color = calm["lamp"]
	lamp.light_energy = float(calm["energy"])
	lamp.omni_range = 9.0
	lamp.position = Vector3(l * 0.5, h - 0.5, 0.3)
	node.add_child(lamp)
	c["lamp"] = lamp
	c["lamp_color"] = lamp.light_color
	c["lamp_energy"] = lamp.light_energy
	c["lamp_sway"] = 1.0
	c["name"] = _label(node, String(def.get("name", def["id"])), Vector3(l * 0.5, h + 1.2, 0), 72, Color(0.93, 0.91, 0.86))
	c["values"] = _label(node, "", Vector3(l * 0.5, h + 0.55, 0), 44, Color(0.7, 0.7, 0.68))


## An iron stove with its pipe, an ember glow and the faint steam a car stove
## may make (fx/smoke.gd "stove").
func _build_stove(c: Dictionary, at: Vector3) -> void:
	var node: Node3D = c["node"]
	var iron := Color(0.12, 0.12, 0.13)
	_box(node, Vector3(0.4, 0.7, 0.4), at + Vector3(0, 0.35, 0), iron)
	_box(node, Vector3(0.1, CAR_HEIGHT - 0.7, 0.1), at + Vector3(0, 0.7 + (CAR_HEIGHT - 0.7) * 0.5, -0.1), iron)
	var glow := OmniLight3D.new()
	glow.light_color = STOVE_COLOR
	glow.light_energy = 0.0
	glow.omni_range = 3.0
	glow.position = at + Vector3(0, 0.5, 0.35)
	node.add_child(glow)
	c["stove_light"] = glow
	var steam: GPUParticles3D = Smoke.build("stove")
	steam.position = at + Vector3(0, 0.75, 0)
	steam.emitting = false
	node.add_child(steam)
	c["steam"] = steam


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _mat(color)
	node.position = at
	parent.add_child(node)
	return node


func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mats.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 1.0
		_mats[key] = mat
	return _mats[key]


func _label(parent: Node3D, text: String, at: Vector3, size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = _font
	label.font_size = size
	label.pixel_size = 0.01
	label.outline_size = 8
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = at
	parent.add_child(label)
	return label
