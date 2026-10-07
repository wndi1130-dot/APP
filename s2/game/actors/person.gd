extends Node3D
## One person in the field: the chief, a companion, a crew member or a raider.
## Holds body, heat, bag and hands; moves along a path; runs one timed action.

const FieldGrid = preload("res://game/world/field_grid.gd")
const BodyState = preload("res://game/sim/body_state.gd")
const BodyHeat = preload("res://game/sim/body_heat.gd")
const AimModel = preload("res://game/sim/aim_model.gd")
const Carry = preload("res://game/sim/carry.gd")
const W = preload("res://game/sim/weapons.gd")

const WALK: float = 2.1
const RUN: float = 3.9
const CROUCH: float = 1.1
const ROLE_COLORS: Dictionary = {
	"chief": Color(0.92, 0.9, 0.84), "companion": Color(0.72, 0.62, 0.45), "worker": Color(0.55, 0.45, 0.35),
	"escort": Color(0.45, 0.5, 0.42), "raider": Color(0.7, 0.3, 0.26), "survivor": Color(0.6, 0.6, 0.7),
}

var pid: String = ""
var display_name: String = ""
var role: String = "companion"
var team: String = "squad"            # squad | crew | raider
var skills: Dictionary = {"strength": 5, "melee": 1, "shooting": 1, "stealth": 1, "search": 1}
var medical: String = "none"          # none | apprentice | skilled | master
var body := BodyState.new()
var heat := BodyHeat.new()
var aim := AimModel.new()
var hands: Array = []                  # [{id, quality, condition, loaded}], index 0 = in hand
var bag: String = "pack"
var items: Dictionary = {}             # item id -> count
var coat: Dictionary = {"name": "철도원 외투", "warmth": 0.7, "windproof": 0.5, "block": 0.25, "heavy": false, "wear": 0}
var gloves: bool = true
var smell: int = 0                     # 0 clean, 1 sweat, 2 stench
var traits: Array = []

var path := PackedVector3Array()
var running: bool = false
var crouched: bool = false
var facing: float = 0.0
var moving: bool = false
var command: String = "follow"         # companions: follow | wait | search | cover | retreat
var command_target := Vector3.ZERO
var action: String = ""                 # current timed action id
var action_label: String = ""
var action_t: float = 0.0
var action_total: float = 0.0
var action_done: Callable
var action_noise_t: float = 0.0
var swing_t: float = 0.0
var reload_t: float = 0.0
var jam_t: float = 0.0
var target_zombie: Dictionary = {}
var target_person = null
var hold_attack: bool = false
var grabbers: Array = []                # zombie dicts holding this person
var grab_left: float = 0.0
var grab_front: bool = true
var climbing: bool = false
## Above the ground floor (floors are stacked 3 m apart on position.y).
var upstairs: bool:
	get:
		return position.y > 1.5
var carrying_wounded = null
var downed_marked: bool = false
var dead_marked: bool = false
var brain: Dictionary = {}              # AI scratch space (raiders, companions, crew)
var panic: float = 0.0
var ice_t: float = 0.0
var fallen_t: float = 0.0
var last_hurt_by: String = ""
var blood_soaked: bool = false          # several close kills in a short time (body_injury 8.1)
var close_kills: Array = []             # field times of recent close kills

var body_mesh: MeshInstance3D
var head_mesh: MeshInstance3D
var weapon_mesh: MeshInstance3D
var ring: MeshInstance3D
var tag: Label3D


func setup(id: String, name_text: String, p_role: String, at: Vector3) -> void:
	pid = id
	display_name = name_text
	role = p_role
	team = "raider" if role == "raider" else ("crew" if role == "worker" or role == "escort" else "squad")
	position = at
	var color: Color = ROLE_COLORS.get(role, Color(0.7, 0.7, 0.7))
	body_mesh = _part(CapsuleMesh.new(), color)
	(body_mesh.mesh as CapsuleMesh).radius = 0.27
	(body_mesh.mesh as CapsuleMesh).height = 1.45
	body_mesh.position = Vector3(0, 0.75, 0)
	head_mesh = _part(SphereMesh.new(), color.lightened(0.15))
	(head_mesh.mesh as SphereMesh).radius = 0.17
	(head_mesh.mesh as SphereMesh).height = 0.34
	head_mesh.position = Vector3(0, 1.6, 0.04)
	weapon_mesh = _part(BoxMesh.new(), Color(0.2, 0.2, 0.2))
	weapon_mesh.position = Vector3(0.3, 1.0, 0.35)
	ring = _part(TorusMesh.new(), Color(0.95, 0.85, 0.4) if role == "chief" else color.darkened(0.2))
	(ring.mesh as TorusMesh).inner_radius = 0.36
	(ring.mesh as TorusMesh).outer_radius = 0.44
	ring.position = Vector3(0, 0.03, 0)
	ring.visible = role == "chief" or team == "squad"
	tag = Label3D.new()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 36
	tag.pixel_size = 0.01
	tag.outline_size = 8
	tag.position = Vector3(0, 2.25, 0)
	tag.no_depth_test = true
	add_child(tag)
	_refresh_weapon_mesh()


func _part(mesh: Mesh, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mesh.material = mat
	node.mesh = mesh
	add_child(node)
	return node


func is_alive() -> bool:
	return not body.dead


func can_act() -> bool:
	return not body.dead and not body.downed and grabbers.is_empty() and fallen_t <= 0.0


func weapon() -> Dictionary:
	return hands[0] if hands.size() > 0 else {"id": "", "quality": "factory", "condition": 1.0, "loaded": 0}


func weapon_id() -> String:
	return String(weapon().get("id", ""))


func weight() -> float:
	var w := Carry.total_weight(items)
	for i in range(1, hands.size()):
		w += Carry.item_weight(hands[i]["id"]) * 0.5
	w += 1.0 if heat.wet > 0.5 else 0.0
	return w


func carry_limit() -> float:
	return Carry.limit(bag, int(skills["strength"]))


func carry_state() -> int:
	return Carry.state(weight(), carry_limit())


## S2 keeps only the '추움' tier (on/off, s2_station 2.4 after the 2026-10-07
## review). Hypothermia tiers wait for S3.
func cold_level() -> int:
	return mini(heat.level(), 1)


## A close kill splashes the coat; three within a minute soak it: the body
## smells one step worse and the blood starts calling (body_injury 8.1).
func note_close_kill(now: float) -> bool:
	close_kills.append(now)
	while not close_kills.is_empty() and now - float(close_kills[0]) > 60.0:
		close_kills.pop_front()
	if close_kills.size() >= 3 and not blood_soaked:
		blood_soaked = true
		smell = mini(smell + 1, 2)
		return true
	return false


## Rubbing snow on the coat clears the soaking (one smell step) and chills.
func rub_snow() -> void:
	if blood_soaked:
		blood_soaked = false
		smell = maxi(smell - 1, 0)
	close_kills.clear()
	heat.heat = maxf(0.0, heat.heat - 12.0)


func smell_mult() -> float:
	return [1.0, 1.25, 1.5][clampi(smell, 0, 2)]


func mult_ctx() -> Dictionary:
	return {"carry_state": carry_state(), "cold_level": cold_level(), "gloves": gloves, "heavy_coat": bool(coat.get("heavy", false)), "panic": panic > 0.6, "strength": int(skills["strength"])}


func mults() -> Dictionary:
	return body.multipliers(mult_ctx())


func speed(floor_kind: int) -> float:
	var base := WALK
	if running and body.can_run() and carry_state() <= 2:
		base = RUN
	elif crouched:
		base = CROUCH
	if carry_state() >= 3:
		return 0.0
	var m: Dictionary = mults()
	return base * float(m["move"]) * FieldGrid.FLOOR_SPEED[floor_kind]


func is_running_now() -> bool:
	return running and moving and body.can_run()


func add_item(id: String, n: int = 1) -> void:
	items[id] = int(items.get(id, 0)) + n


func take_item(id: String, n: int = 1) -> bool:
	if int(items.get(id, 0)) < n:
		return false
	items[id] = int(items[id]) - n
	if items[id] <= 0:
		items.erase(id)
	return true


func start_action(id: String, label: String, seconds: float, done: Callable) -> void:
	action = id
	action_label = label
	action_t = seconds
	action_total = seconds
	action_done = done
	path = PackedVector3Array()
	moving = false


func cancel_action() -> void:
	action = ""
	action_label = ""
	action_t = 0.0


func go_to(p: PackedVector3Array, run: bool = false) -> void:
	path = p
	running = run
	if action != "" and action != "aim":
		cancel_action()


func stop() -> void:
	path = PackedVector3Array()
	moving = false


func face_point(p: Vector3) -> void:
	var d := p - position
	if d.length() > 0.01:
		facing = atan2(d.x, d.z)


func release_grab(z: Dictionary) -> void:
	grabbers.erase(z)
	if grabbers.is_empty():
		grab_left = 0.0


func set_weapon_slots(list: Array) -> void:
	hands = list
	_refresh_weapon_mesh()


func swap_weapons() -> void:
	if hands.size() < 2:
		return
	var first = hands.pop_front()
	hands.append(first)
	aim.stop()
	_refresh_weapon_mesh()


func _refresh_weapon_mesh() -> void:
	if weapon_mesh == null:
		return
	var id := weapon_id()
	var size := Vector3(0.06, 0.06, 0.3)
	match id:
		"axe":
			size = Vector3(0.08, 0.08, 0.75)
		"crowbar":
			size = Vector3(0.05, 0.05, 0.6)
		"knife":
			size = Vector3(0.04, 0.04, 0.28)
		"pistol":
			size = Vector3(0.06, 0.12, 0.25)
		"shotgun", "pipe_shotgun":
			size = Vector3(0.07, 0.07, 0.95)
		"bow":
			size = Vector3(0.05, 0.9, 0.05)
	(weapon_mesh.mesh as BoxMesh).size = size
	weapon_mesh.visible = id != ""


## Per-frame visuals: facing, posture, tag text.
func refresh_view(show_tag: bool) -> void:
	rotation.y = facing
	var lying := body.downed or body.dead or fallen_t > 0.0
	if lying:
		body_mesh.rotation = Vector3(PI * 0.5, 0, 0)
		body_mesh.position = Vector3(0, 0.25, 0.3)
		head_mesh.position = Vector3(0, 0.22, 1.05)
	else:
		var bend := 0.45 if crouched else (0.2 if body.exhaustion_level() >= 1 else 0.0)
		body_mesh.rotation = Vector3(bend, 0, 0)
		body_mesh.position = Vector3(0, 0.75 - bend * 0.25, 0)
		head_mesh.position = Vector3(0, 1.6 - bend * 0.5, 0.04 + bend * 0.4)
	weapon_mesh.visible = not lying and weapon_id() != ""
	if body.dead:
		(body_mesh.mesh.material as StandardMaterial3D).albedo_color = Color(0.3, 0.28, 0.27)
	var text := ""
	if show_tag:
		if body.dead:
			text = display_name
		elif not grabbers.is_empty():
			text = "잡힘!"
		elif body.downed:
			text = "%s · 쓰러짐" % display_name
		elif action != "" and action != "aim":
			text = "%s %d초" % [action_label, ceili(action_t)]
		elif jam_t > 0.0:
			text = "걸림 %d초" % ceili(jam_t)
		elif reload_t > 0.0:
			text = "장전"
	tag.text = text
	tag.modulate = Color(1, 0.55, 0.45) if not grabbers.is_empty() else Color(0.95, 0.93, 0.88)
