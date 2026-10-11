extends Node3D
## One stand-in person inside the train: a capsule and a head the size of the
## field person (actors/person.gd), without its rules. It holds a pose and
## walks a line along the aisle. When the hand-made clips come, pose_at() is
## the one place they replace. Forward is +z, toward the open side of the car.

const RADIUS: float = 0.27
const HEIGHT: float = 1.45
const HEAD_RADIUS: float = 0.17
const WALK_SPEED: float = 1.0           # a narrow aisle: slower than the field's 2.1
const SEAT_HEIGHT: float = 0.45
const SEATED_SCALE: float = 0.5         # the trunk alone: the legs fold away, and someone who gets up shows
const HUDDLE_SCALE: float = 0.78
const HUDDLE_LEAN: float = 0.45         # rad, forward over the knees
const BOW_DROP: float = 0.13            # a bowed head, the trunk upright
const SIDE_LEAN: float = 0.2            # rad, over to a neighbour
const SIDE_HEAD: float = 0.12
const BOB: float = 0.03
const BOB_RATE: float = 9.0
## Worn winter coats, no two cars alike and none a uniform.
const COATS: Array = [
	Color(0.46, 0.4, 0.33), Color(0.36, 0.38, 0.4), Color(0.5, 0.45, 0.4),
	Color(0.33, 0.33, 0.3), Color(0.42, 0.36, 0.36), Color(0.4, 0.42, 0.36),
]

static var _capsule: CapsuleMesh
static var _sphere: SphereMesh
static var _coats: Array = []

var home_car: String = ""
var pose: String = "sit"                 # walk | stand | sit | floor
var huddled: bool = false
var bowed: bool = false
var side: float = 0.0                    # leans to its own right (1) or left (-1), 0 upright
var seat: int = -1                       # its seat number in the council, -1 outside it
var act: String = ""                     # the council gesture it is in: "" | lean | rise
var act_t: float = 0.0
var gesture: String = ""                 # the gesture of train_gesture.gd it is in, "" for none
var gesture_role: int = 0                # which of a pair it is
var gesture_facing: float = 0.0          # where it faces before the gesture turns it
var idle_gesture: String = ""            # the gesture it falls into while it stands between walks, "" for none
var speed: float = WALK_SPEED
var state: String = "seat"               # seat | wait | pace | out | visit | back
var timer: float = 0.0
var goal_x: float = 0.0
var visit_car: String = ""
var errand: Dictionary = {}
var slot := Vector3.ZERO
var clock: float = 0.0
var body_mesh: MeshInstance3D
var head_mesh: MeshInstance3D


func setup(car_id: String, coat: int) -> void:
	home_car = car_id
	_share_meshes()
	body_mesh = MeshInstance3D.new()
	body_mesh.mesh = _capsule
	body_mesh.material_override = _coats[posmod(coat, _coats.size())]
	add_child(body_mesh)
	head_mesh = MeshInstance3D.new()
	head_mesh.mesh = _sphere
	head_mesh.material_override = _coats[posmod(coat + 3, _coats.size())]
	add_child(head_mesh)
	show_pose()


## Where the trunk and the head sit for a pose: {"body_pos", "body_scale",
## "body_lean", "body_roll", "head_pos"}. `t` only bobs a walk. A bowed head is
## the quiet of a frightened car, a huddle is the cold, and `p_side` leans a
## person who is not walking over to one side.
static func pose_at(p_pose: String, p_huddled: bool, t: float = 0.0, p_bowed: bool = false, p_side: float = 0.0) -> Dictionary:
	var base: float = 0.0
	var scale: float = 1.0
	match p_pose:
		"sit":
			base = SEAT_HEIGHT
			scale = SEATED_SCALE
		"floor":
			scale = SEATED_SCALE
	var lean: float = 0.0
	var head_drop: float = 0.0
	var head_out: float = 0.04
	if p_huddled and p_pose != "walk":
		scale *= HUDDLE_SCALE
		lean = HUDDLE_LEAN
		head_drop = 0.22
		head_out = 0.22
	elif p_bowed and p_pose != "walk":
		head_drop = BOW_DROP
		head_out = 0.14
	var bob: float = absf(sin(t * BOB_RATE)) * BOB if p_pose == "walk" else 0.0
	var half: float = HEIGHT * scale * 0.5
	var over: float = p_side if p_pose != "walk" else 0.0
	return {
		"body_pos": Vector3(0, base + half + bob, 0),
		"body_scale": Vector3(1, scale, 1),
		"body_lean": lean,
		"body_roll": -over * SIDE_LEAN,
		"head_pos": Vector3(over * SIDE_HEAD, base + HEIGHT * scale + HEAD_RADIUS - 0.02 - head_drop + bob, head_out),
	}


func set_pose(p_pose: String, p_huddled: bool, p_bowed: bool = false) -> void:
	pose = p_pose
	huddled = p_huddled
	bowed = p_bowed
	show_pose()


func show_pose() -> void:
	if body_mesh == null:
		return
	var at := pose_at(pose, huddled, clock, bowed, side)
	body_mesh.position = at["body_pos"]
	body_mesh.scale = at["body_scale"]
	body_mesh.rotation.x = float(at["body_lean"])
	body_mesh.rotation.z = float(at["body_roll"])
	head_mesh.position = at["head_pos"]


## Walk toward goal_x along the aisle; true once there.
func walk(delta: float) -> bool:
	clock += delta
	var left: float = goal_x - position.x
	var stride: float = speed * delta
	if absf(left) <= stride:
		position.x = goal_x
		rotation.y = 0.0
		set_pose("stand", false)
		return true
	position.x += signf(left) * stride
	rotation.y = PI * 0.5 * signf(left)
	set_pose("walk", false)
	return false


static func _share_meshes() -> void:
	if _capsule != null:
		return
	_capsule = CapsuleMesh.new()
	_capsule.radius = RADIUS
	_capsule.height = HEIGHT
	_capsule.radial_segments = 12
	_capsule.rings = 4
	_sphere = SphereMesh.new()
	_sphere.radius = HEAD_RADIUS
	_sphere.height = HEAD_RADIUS * 2.0
	_sphere.radial_segments = 12
	_sphere.rings = 6
	for c in COATS:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.roughness = 1.0
		_coats.append(mat)
