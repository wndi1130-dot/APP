extends Node3D
## The inside of the train, seen from the side with the near wall off: boxes
## for cars, stand-in bodies that sit, huddle and walk the aisle, and a few who
## walk to another car and back. It only shows the rule values it is given
## (train_rules.gd) and changes none of them. Everything is built in code,
## like the field; the car bodies and the people's clips swap in later.

signal rules_applied

const Rules = preload("res://game/train/train_rules.gd")
const Look = preload("res://game/train/train_look.gd")
const Body = preload("res://game/train/train_body.gd")
const HandPanel = preload("res://game/train/train_panel.gd")
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
## The stove stands in front of the bench, between two floor places; a car with
## a table has it by the end wall.
const STOVE_AT := Vector3(7.85, 0.0, -0.4)
const STOVE_AT_END := Vector3(0.45, 0.0, -0.9)
const STOVE_COLOR := Color(1.0, 0.55, 0.3)
const STOVE_ENERGY: float = 1.1
const LAMP_SWAY: float = 0.05           # metres, with the train's rocking
const LAMP_EASE: float = 1.5            # a mood comes on over a second or so
const AISLE_MARGIN: float = 1.0
const PACE_WAIT := Vector2(2.0, 6.0)    # a mover stands this long between walks
const VISIT_SPREAD: float = 3.0
const OUT_AT_ONCE: int = 1              # of one car, on a trip to another
const OUT_IN_SESSION: int = 2
const CAM_NEAR: float = 11.0            # metres of height on screen
const CAM_FAR: float = 24.0
const CAM_PITCH: float = -8.0
const CAM_BACK: float = 30.0
const CAM_LOOK_Y: float = -0.3          # below the floor: the panel covers the bottom

var rules: Dictionary = {}
var opts: Dictionary = {}               # seed: int, panel: bool
var problems := PackedStringArray()
var cars: Array = []                    # [{def, id, index, x0, node, bodies, out, errand_t, errand_i, values}]
var rng := RandomNumberGenerator.new()
var camera: Camera3D
var train: Node3D
var people: Node3D
var panel: CanvasLayer
var cam_x: float = CAR_LENGTH * 0.5
var zoomed_out: bool = false
var clock: float = 0.0
var _mats: Dictionary = {}
var _font: SystemFont


func _ready() -> void:
	rng.seed = int(opts.get("seed", 1))
	if rules.is_empty():
		rules = Rules.load_default()
	problems = Rules.check(rules)
	_build_world()
	if problems.is_empty():
		_build_train()
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
func apply_rules() -> void:
	for c in cars:
		_seat_car(c)
	rules_applied.emit()


func set_sit(comm_id: String, i: int, value: float) -> void:
	rules["comms"][comm_id]["sit"][i] = clampf(value, 0.0, 100.0)
	apply_rules()


func set_comm(comm_id: String, key: String, value) -> void:
	rules["comms"][comm_id][key] = value
	apply_rules()


func set_train(key: String, value) -> void:
	rules["train"][key] = value
	apply_rules()


## One tick of the people: movers pace their own aisle, and now and then one
## takes a trip with a use to another car, stays and comes back.
func step(delta: float) -> void:
	clock += delta
	for c in cars:
		_step_lamp(c, delta)
		_step_errand(c, delta)
		for b in c["bodies"]:
			_step_body(c, b, delta)


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


## The line under a car's name: its numbers and its head count.
func values_text(c: Dictionary) -> String:
	var comm := Rules.comm_of(rules, c["def"])
	var heads := "%d명 · %s" % [(c["bodies"] as Array).size(), Look.MOOD_NAMES[c["mood"]]]
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
	var w := Look.warmth(comm)
	var m := Look.mood(comm, rules.get("train", {}))
	var look := Look.mood_look(m)
	c["mood"] = m
	var rows := Look.seating(n, w, Look.crowding(comm), m)
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
	var walkers: int = 0
	for row in rows:
		walkers += 1 if row["pose"] == "walk" else 0
	var gather: bool = look["gather"]
	var standing: int = 0
	var bench: int = 0
	var on_floor: int = 0
	var x0: float = c["x0"]
	for i in n:
		var b: Node3D = bodies[i]
		var row: Dictionary = rows[i]
		b.speed = Body.WALK_SPEED * float(look["speed"])
		match String(row["pose"]):
			"walk":
				b.slot = Vector3(x0 + AISLE_MARGIN + (CAR_LENGTH - 2.0 * AISLE_MARGIN) * (i + 0.5) / maxi(walkers, 1), 0, AISLE_Z)
				if b.state == "seat":
					b.position = b.slot
					b.rotation.y = 0.0
					b.set_pose("stand", false)
					_wait(c, b)
			"stand":
				_sit_down(c, b, x0, _knot_place(standing), "stand", false, false)
				b.rotation.y = _knot_facing(standing)
				standing += 1
			"sit":
				var seat := Vector3(SLOT_FIRST + Look.seat_slot(bench, BENCH_SLOTS, gather) * SLOT_STEP, 0, BENCH_Z)
				_sit_down(c, b, x0, seat, "sit", bool(row["huddled"]), bool(row["bowed"]))
				bench += 1
			_:
				# The stove stands between two floor places: gathered, the floor fills on both sides of it.
				var slot: int = (on_floor * Look.SLOT_STRIDE + FLOOR_SHIFT) % BENCH_SLOTS
				if gather:
					slot = maxi(Look.seat_slot(on_floor, BENCH_SLOTS, true) - 1, 0)
				var place := Vector3(SLOT_FIRST + SLOT_STEP * 0.5 + slot * SLOT_STEP, 0, FLOOR_Z)
				_sit_down(c, b, x0, place, "floor", bool(row["huddled"]), bool(row["bowed"]))
				on_floor += 1
	_dress_car(c, w, look)
	(c["values"] as Label3D).text = values_text(c)


## Where in the car the k-th of those standing about stands: knots of three,
## by the tail-end doorway and the front-end one in turn.
func _knot_place(k: int) -> Vector3:
	var knot: int = k / KNOT_SIZE
	var member: int = k % KNOT_SIZE
	var along: float = KNOT_FROM + (knot / 2) * KNOT_APART
	if member == 1:
		along += KNOT_STEP
	elif member == 2:
		along += KNOT_STEP * 0.5
	var x: float = along if knot % 2 == 0 else CAR_LENGTH - along
	return Vector3(x, 0, KNOT_Z - (KNOT_DEPTH if member == 2 else 0.0))


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
	b.set_pose(pose, huddled, bowed)


func _end_trip(c: Dictionary, b: Node3D) -> void:
	if b.state == "out" or b.state == "visit" or b.state == "back":
		c["out"] = int(c["out"]) - 1
	b.visit_car = ""


func _step_body(c: Dictionary, b: Node3D, delta: float) -> void:
	match b.state:
		"wait":
			b.timer -= delta
			if b.timer <= 0.0:
				b.goal_x = rng.randf_range(float(c["x0"]) + AISLE_MARGIN, float(c["x0"]) + CAR_LENGTH - AISLE_MARGIN)
				b.state = "pace"
		"pace":
			if b.walk(delta):
				_wait(c, b)
		"out":
			if b.walk(delta):
				b.state = "visit"
				b.timer = float(b.errand.get("stay", 5.0))
		"visit":
			b.timer -= delta
			if b.timer <= 0.0:
				b.goal_x = b.slot.x
				b.state = "back"
		"back":
			if b.walk(delta):
				_end_trip(c, b)
				_wait(c, b)


## A calm mover stands a few seconds between walks; a stirred one hardly stops.
func _wait(c: Dictionary, b: Node3D) -> void:
	b.state = "wait"
	b.timer = rng.randf_range(PACE_WAIT.x, PACE_WAIT.y) * float(Look.mood_look(c["mood"])["wait"])


func _step_errand(c: Dictionary, delta: float) -> void:
	var rows := Look.errands_for(c["def"], phase(), rules.get("errands", []))
	if rows.is_empty():
		return
	c["errand_t"] = float(c["errand_t"]) - delta
	if float(c["errand_t"]) > 0.0:
		return
	var row: Dictionary = rows[int(c["errand_i"]) % rows.size()]
	c["errand_i"] = int(c["errand_i"]) + 1
	c["errand_t"] = float(row["every"]) * rng.randf_range(0.8, 1.2) * float(Look.mood_look(c["mood"])["wait"])
	if int(c["out"]) >= (OUT_IN_SESSION if phase() == "council" else OUT_AT_ONCE):
		return
	var to := car(String(row["to"]))
	if to.is_empty():
		return
	for b in c["bodies"]:
		if b.state == "wait":
			b.errand = row
			b.visit_car = to["id"]
			b.goal_x = float(to["x0"]) + CAR_LENGTH * 0.5 + rng.randf_range(-VISIT_SPREAD, VISIT_SPREAD)
			b.state = "out"
			c["out"] = int(c["out"]) + 1
			return


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
	var defs: Array = rules["cars"]
	for i in defs.size():
		var def: Dictionary = defs[i]
		var node := Node3D.new()
		node.name = "Car_%s" % def["id"]
		node.position.x = i * (CAR_LENGTH + CAR_GAP)
		train.add_child(node)
		var c := {
			"def": def, "id": String(def["id"]), "index": i, "x0": node.position.x, "node": node,
			"bodies": [], "out": 0, "errand_t": rng.randf_range(2.0, 8.0), "errand_i": 0, "mood": "calm",
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
	if kind == "comm" or kind == "engine" or kind == "dining" or kind == "captain":
		_box(node, Vector3(l - 1.6, Body.SEAT_HEIGHT, 0.5), Vector3(l * 0.5, Body.SEAT_HEIGHT * 0.5, -1.0), wood.lightened(0.08))
	if kind == "dining":
		_box(node, Vector3(l - 4.0, 0.75, 0.6), Vector3(l * 0.5, 0.375, -0.2), wood.lightened(0.15))
	elif kind == "captain":
		_box(node, Vector3(1.6, 0.75, 0.7), Vector3(l * 0.5, 0.375, -0.2), wood.lightened(0.15))
	if kind == "comm" or kind == "engine":
		_build_stove(c, STOVE_AT)
	elif kind == "dining" or kind == "captain":
		_build_stove(c, STOVE_AT_END)
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
