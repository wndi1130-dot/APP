extends Node3D
## One person in the field: the chief, a companion, a crew member or a raider.
## Holds body, heat, bag and hands; moves along a path; runs one timed action.

const FieldGrid = preload("res://game/world/field_grid.gd")
const BodyState = preload("res://game/sim/body_state.gd")
const BodyHeat = preload("res://game/sim/body_heat.gd")
const AimModel = preload("res://game/sim/aim_model.gd")
const Carry = preload("res://game/sim/carry.gd")
const Wear = preload("res://game/sim/wear.gd")
const W = preload("res://game/sim/weapons.gd")
const Pose = preload("res://game/actors/person_pose.gd")

const WALK: float = 2.1
const RUN: float = 3.9
const MOVE_MIN: float = 0.25 # Decision 442: no slow input glide; decision 425 stays unchanged.
const CROUCH: float = 1.1
const CROUCH_NOISE_MULT: float = 0.5 # contract with the sound rules; no extra sound event
const ROLE_COLORS: Dictionary = {
	"chief": Color(0.92, 0.9, 0.84), "companion": Color(0.72, 0.62, 0.45), "worker": Color(0.55, 0.45, 0.35),
	"escort": Color(0.45, 0.5, 0.42), "raider": Color(0.7, 0.3, 0.26), "survivor": Color(0.6, 0.6, 0.7),
}

## Lanterns (weather_fx 12.1): the chief's lights their own ring, a mate's says where they are.
# The weapon in the hand as a model where one is in the build: the grip at the
# origin, the blade or muzzle along +Z, Y up. Without one the box stands in.
const WEAPON_MODEL: String = "res://models/weapons/%s.glb"
# The hatchet comes with its edge lying sideways (+X); turned so it faces down.
const WEAPON_TURN: Dictionary = {"axe": Vector3(0, 0, -PI * 0.5)}
const LAMP_CHIEF: Dictionary = {"strength": 1.0, "reach": 7.0}
const LAMP_MATE: Dictionary = {"strength": 0.6, "reach": 4.0}

var pid: String = ""
var display_name: String = ""
var role: String = "companion"
var team: String = "squad"            # squad | crew | raider
var skills: Dictionary = {"strength": 5, "melee": 1, "shooting": 1, "stealth": 1, "search": 1}
var medical: String = "none"          # none | apprentice | skilled | master
## What the train sends them out with (the departure contract, s3 contract 2; card B): 0 none,
## 1 some, 2 bad. Both take from how well a blow lands (body_injury 4.2).
var hunger_level: int = 0
var sore_level: int = 0
var body := BodyState.new()
var heat := BodyHeat.new()
var aim := AimModel.new()
var hands: Array = []                  # [{id, quality, condition, loaded}], index 0 = in hand
var bag: String = "pack"
var items: Dictionary = {}             # item id -> count
## What is worn, place by place (wear.gd, decision 434): {slot: garment state}.
## coat, hat and gloves are the old three places seen through it: the coat
## over the body (the coat over the jacket, else the jacket), what is on the
## head ({} for none), whether the hands are gloved.
var worn: Dictionary = Wear.outfit(Wear.DEFAULT)
var coat: Dictionary:
	get:
		return Wear.torso_outer(self)
	set(value):
		Wear.set_torso_outer(self, value)
var hat: Dictionary:
	get:
		return worn.get("head", {})
	set(value):
		if value.is_empty():
			worn.erase("head")
		else:
			worn["head"] = value
var gloves: bool:
	get:
		return worn.has("hands")
	set(value):
		if value and not worn.has("hands"):
			worn["hands"] = Wear.make("gloves")
		elif not value:
			worn.erase("hands")
var smell: int = 0                     # 0 clean, 1 sweat, 2 stench
var traits: Array = []
var lamp: Dictionary = {}              # {strength, reach} of the lantern carried; empty = none
var lamp_on: bool = true               # put out by hand (weather_fx 12.3 stage 2)

var path := PackedVector3Array()
var running: bool = false
var crouched: bool = false
var facing: float = 0.0
## Body turn: turn_rate in rad/s (0 = the view follows facing at once), look is the angle shown.
var turn_rate: float = 0.0
var look: float = 0.0
var moving: bool = false
var visual_push: Vector3 = Vector3.ZERO # Cumulative world-space separation; drawing only, not saved.
var ground_sample: Dictionary = {}     # Runtime tick identity; never restored from a saved clock.
var motion_epoch: int = 0              # A rewind starts the drawing's samples again too.
var stick := Vector2.ZERO               # player's left thumb: world x/z direction, length 0..1
var drive_speed: float = 0.0            # body speed under the stick (eases in and out)
var drive_dir := Vector3.ZERO
var command: String = "follow"         # companions: follow | wait | search | cover | retreat
var command_target := Vector3.ZERO
var action: String = ""                 # current timed action id
var action_label: String = ""
var action_t: float = 0.0
var action_total: float = 0.0
var action_done: Callable
var action_busy: Dictionary = {}        # container reserved by a search; freed when the action ends or is cut short
var action_noise_t: float = 0.0
var swing_t: float = 0.0
var shove_t: float = 0.0                # the shove is winding up (field_combat.start_shove)
var lunge_t: float = 0.0                # the shove just landed: arms out
var strike_t: float = 0.0               # a melee blow is drawn back (field_combat.start_swing)
var strike_total: float = 0.0           # how long this draw-back is in all (for the motion)
var strike_at = null                    # what it will land on: a zombie's Dictionary or a person
var strike_kind: String = "swing"       # "swing" a weapon comes round | "stomp" the boot comes down (kept after it lands, for the motion)
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
var weapon_box: BoxMesh                 # what weapon_mesh shows when there is no model
var weapon_model: Node3D = null         # under weapon_mesh, so the poses move it too
var weapon_model_id: String = ""
var ring: MeshInstance3D
var tag: Label3D


## Is the lantern lit (weather_fx 12.1): everyone's after sunset, the chief's
## always down in a cellar. The picture only; the night sound rule is the game's.
func lamp_lit(dark: bool, cellar: bool = false) -> bool:
	if lamp.is_empty() or not lamp_on or not is_alive():
		return false
	return dark or (cellar and role == "chief")


func setup(id: String, name_text: String, p_role: String, at: Vector3) -> void:
	pid = id
	display_name = name_text
	role = p_role
	team = "raider" if role == "raider" else ("crew" if role == "worker" or role == "escort" else "squad")
	lamp = {} if team == "raider" else (LAMP_CHIEF.duplicate() if role == "chief" else LAMP_MATE.duplicate())
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
	weapon_box = weapon_mesh.mesh
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
		w += Carry.item_weight(hands[i]["id"]) * Carry.RESERVE_WEAPON_WEIGHT
	w += Carry.SOAKED_WEIGHT if heat.wet > Carry.SOAKED_THRESHOLD else 0.0
	# Clothes worn past what everyone goes out in (wear.gd 5장).
	w += Wear.extra_weight(self)
	return w


func carry_limit() -> float:
	return Carry.limit(bag, int(skills["strength"]))


func carry_state() -> int:
	return Carry.state(weight(), carry_limit())


## The load lets one run: not over the limit and nothing held in both arms
## (card G 가, decision 448-19: one walks with it).
func load_lets_run() -> bool:
	return carry_state() < 2 and not Carry.has_big(items)


## S2 keeps only the '추움' tier (on/off, s2_station 2.4 after the 2026-10-07
## review). Hypothermia tiers wait for S3.
func cold_level() -> int:
	return 1 if heat.wet > BodyHeat.WET_COLD_THRESHOLD else mini(heat.level(), 1)


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
	return {"carry_state": carry_state(), "cold_level": cold_level(), "gloves": gloves, "heavy_coat": Wear.heavy(self), "barefoot": Wear.barefoot(self), "panic": panic > 0.6, "strength": int(skills["strength"]),
			"hunger_level": hunger_level, "sore_level": sore_level}


func mults() -> Dictionary:
	return body.multipliers(mult_ctx())


## The field loop can pass this complete movement/work context to the body.
func body_context(indoor: bool = false) -> Dictionary:
	return {"running": is_running_now(), "moving": moving, "swinging": swing_t > 0.0,
		"working": action != "" or climbing, "crouched": crouched,
		"carry_state": carry_state(), "cold_level": cold_level(),
		"indoor_rest": indoor and not moving and action == "" and grabbers.is_empty() and fallen_t <= 0.0}


func speed(floor_kind: int) -> float:
	var base := WALK
	if crouched:
		base = CROUCH
	elif running and body.can_run() and load_lets_run():
		base = RUN
	if carry_state() >= 3:
		return 0.0
	var m: Dictionary = mults()
	return base * float(m["move"]) * FieldGrid.FLOOR_SPEED[floor_kind]


## The same speed with only the run switched off.
func walk_speed(floor_kind: int) -> float:
	if carry_state() >= 3:
		return 0.0
	var base: float = CROUCH if crouched else WALK
	var m: Dictionary = mults()
	return base * float(m["move"]) * FieldGrid.FLOOR_SPEED[floor_kind]


func is_running_now() -> bool:
	return running and moving and not crouched and load_lets_run() and body.can_run()


func add_item(id: String, n: int = 1) -> void:
	# A found pack bigger than the one on the back is worn at once (P20); the
	# old one is left. One no bigger goes in the pack like any thing.
	var worn: String = Carry.FieldItems.bag_of(id)
	if n > 0 and worn != "" and int(Carry.BAGS[worn]["limit"]) > int(Carry.BAGS.get(bag, Carry.BAGS["pockets"])["limit"]):
		bag = worn
		n -= 1
		if n <= 0:
			return
	items[id] = int(items.get(id, 0)) + n


func take_item(id: String, n: int = 1) -> bool:
	if int(items.get(id, 0)) < n:
		return false
	items[id] = int(items[id]) - n
	if items[id] <= 0:
		items.erase(id)
	return true


func start_action(id: String, label: String, seconds: float, done: Callable) -> void:
	# One body does one thing at a time (decision 420): no work of the hands
	# starts while a blow or a shove is on, whoever asks for it.
	if swing_t > 0.0 or strike_t > 0.0 or shove_t > 0.0:
		return
	if id == "climb" and carry_state() >= 3:
		return
	if id == "splint" and not _can_simple_splint():
		return
	_free_busy()
	action = id
	action_label = label
	action_t = seconds
	action_total = seconds
	action_done = _complete_simple_splint.bind(done) if id == "splint" else done
	path = PackedVector3Array()
	moving = false
	if id == "climb":
		body.exert_climb(seconds, body_context())


func _can_simple_splint() -> bool:
	return int(items.get("cloth", 0)) > 0 and (int(items.get("plank", 0)) > 0 or int(items.get("wood", 0)) > 0) and (body.arm_fracture or body.leg_fracture) and not body.splinted


func _complete_simple_splint(done: Callable) -> void:
	if not _can_simple_splint() or not done.is_valid():
		return
	# The existing completion takes the plank. Consume cloth at completion too.
	take_item("cloth")
	done.call()


func cancel_action() -> void:
	_free_busy()
	action = ""
	action_label = ""
	action_t = 0.0


func _free_busy() -> void:
	if not action_busy.is_empty():
		action_busy["busy"] = false
		action_busy = {}


func go_to(p: PackedVector3Array, run: bool = false) -> void:
	path = p
	running = run
	if action != "" and action != "aim":
		cancel_action()


func stop() -> void:
	path = PackedVector3Array()
	moving = false


## A stable 0..1 value from the name, so each person keeps their own pace.
func name_unit(salt: String = "") -> float:
	return float((salt + display_name).hash() % 1000) / 1000.0


## The shown body is within `limit` radians of where it is meant to face.
func turned_to(limit: float) -> bool:
	if turn_rate <= 0.0:
		return true
	return absf(angle_difference(look, facing)) <= limit


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
	weapon_box.size = size
	_fit_weapon_model(id)
	weapon_mesh.mesh = weapon_box if weapon_model == null else null
	weapon_mesh.visible = id != ""


## Puts the hand's weapon model under weapon_mesh (or takes it away) when the
## weapon in the hand changes.
func _fit_weapon_model(id: String) -> void:
	if id == weapon_model_id:
		return
	weapon_model_id = id
	if weapon_model != null:
		weapon_model.queue_free()
		weapon_model = null
	var path := WEAPON_MODEL % id
	if id == "" or not ResourceLoader.exists(path):
		return
	var scene := load(path) as PackedScene
	if scene == null:
		return
	weapon_model = scene.instantiate() as Node3D
	if weapon_model == null:
		return
	weapon_model.rotation = WEAPON_TURN.get(id, Vector3.ZERO)
	weapon_mesh.add_child(weapon_model)


## The drawn body comes round toward facing at turn_rate, on the rules' clock
## (field_game _step; decision 442 card C2): what waits on the turn (turned_to,
## the walk's heading_share) and the picture read the same angle, and a field
## stepped without frames (the 40 runs) turns the same as one on screen.
func turn_tick(delta: float) -> void:
	if turn_rate <= 0.0:
		look = facing
		return
	look = wrapf(rotate_toward(look, look + angle_difference(look, facing), turn_rate * delta), -PI, PI)


## Per-frame visuals: facing, posture, tag text.
func refresh_view(show_tag: bool) -> void:
	rotation.y = facing if turn_rate <= 0.0 else look
	var lying := body.downed or body.dead or fallen_t > 0.0
	if lying:
		body_mesh.rotation = Vector3(PI * 0.5, 0, 0)
		body_mesh.position = Vector3(0, 0.25, 0.3)
		head_mesh.position = Vector3(0, 0.22, 1.05)
	else:
		var bend := 0.45 if crouched else (0.2 if body.exhaustion_level() >= 1 else 0.0)
		# A shove: back on the heels, then thrown forward.
		if shove_t > 0.0:
			bend -= 0.3
		elif lunge_t > 0.0:
			bend += 0.55
		body_mesh.rotation = Vector3(bend, 0, 0)
		body_mesh.position = Vector3(0, 0.75 - bend * 0.25, 0)
		head_mesh.position = Vector3(0, 1.6 - bend * 0.5, 0.04 + bend * 0.4)
	weapon_mesh.visible = not lying and weapon_id() != ""
	Pose.apply(self, lying)
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
