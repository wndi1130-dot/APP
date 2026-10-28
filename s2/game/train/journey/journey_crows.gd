extends Node3D
## 「까마귀 떼가 한꺼번에 날아오름」 (결정 495 2절, 7b: crows may dress the travelling
## land; at a stop they are omens only, so the stop scene has none). A clump of crows
## sits on a field, along a tree line or on a fence as the land brings them on; as
## they come into sight of the train they all go up at once, wings beating one way,
## and make off away from the line; the place they sat is left bare (presentation_motion.md
## 「까마귀는 머릿수보다 덩어리」: clumps of three to five, sitting, gathering, rising).
## Small birds of a few dark faces in MultiMeshes: one for those sitting, two for the
## wing up and the wing down (a bird is drawn in the one its beat is at). In the land's frame.

const Kit = preload("res://game/train/journey/journey_kit.gd")

const COUNT: Dictionary = {"field_clump": Vector2i(9, 16), "tree_line": Vector2i(6, 11), "fence": Vector2i(5, 9)}
## They go up once they are this far ahead of the camera's middle, metres.
const RISE_AT := Vector2(6.0, 20.0)
## Away from the line and up, m/s; the beat, beats a second, slowing to a glide.
const FLY := Vector2(7.0, 10.5)
const CLIMB := Vector2(1.6, 3.2)
const BEAT := Vector2(4.5, 6.0)
const LIFE_S: float = 24.0
const BIRD := Color(0.06, 0.06, 0.07)

var journey: Node3D
var birds: Array = []
var age: float = 0.0
var risen: float = -1.0
var rise_at: float = 10.0
var side: float = -1.0
var rng := RandomNumberGenerator.new()
var _sit: MultiMesh
var _up: MultiMesh
var _down: MultiMesh
var _done: bool = false


func begin(j: Node3D, ev: Dictionary, seed_value: int) -> void:
	journey = j
	rng.seed = seed_value
	name = "Crows"
	var variant: String = String(ev.get("variant", "field_clump"))
	var span: Vector2i = COUNT.get(variant, Vector2i(6, 10))
	var n: int = rng.randi_range(span.x, span.y)
	side = -1.0 if rng.randf() < 0.65 else 1.0
	rise_at = rng.randf_range(RISE_AT.x, RISE_AT.y)
	var centre := Vector3(rng.randf_range(0.0, 20.0), 0.0, side * rng.randf_range(10.0, 24.0))
	var perch: float = Kit.FIELD_Y + 0.05
	if variant == "tree_line":
		centre.z = side * rng.randf_range(16.0, 30.0)
		perch = Kit.FIELD_Y + rng.randf_range(7.0, 10.0)
	elif variant == "fence":
		perch = Kit.FIELD_Y + 1.25
	# Clumps of three to five, a little apart.
	var clumps: int = maxi(1, int(ceil(n / 4.0)))
	for c in clumps:
		var at: Vector3 = centre + Vector3(rng.randf_range(-6.0, 6.0), 0.0, side * rng.randf_range(-3.0, 3.0))
		if variant == "fence":
			at = centre + Vector3(c * rng.randf_range(2.0, 3.5), 0.0, 0.0)
		for k in mini(rng.randi_range(3, 5), n - birds.size()):
			var spot: Vector3 = at + Vector3(rng.randf_range(-0.9, 0.9), 0.0, rng.randf_range(-0.6, 0.6))
			spot.y = perch + (rng.randf_range(-0.6, 0.6) if variant == "tree_line" else 0.0)
			birds.append({"pos": spot, "yaw": rng.randf() * TAU, "peck": rng.randf() * TAU,
				"delay": rng.randf_range(0.0, 0.35), "fly": rng.randf_range(FLY.x, FLY.y), "climb": rng.randf_range(CLIMB.x, CLIMB.y),
				"beat": rng.randf_range(BEAT.x, BEAT.y), "phase": rng.randf(), "drift": rng.randf_range(-0.35, 0.35), "up": false})
		if birds.size() >= n:
			break
	# The way they make off: away from the line, all one way, a little along it.
	var away := Vector3(rng.randf_range(-0.5, 0.6), 0.0, side).normalized()
	for b: Dictionary in birds:
		b["dir"] = away.rotated(Vector3.UP, float(b["drift"]) * 0.5)
	_build_draw()
	advance(0.0, 0.0)


func is_done() -> bool:
	return _done


func advance(delta: float, _travelled: float) -> void:
	age += delta
	if risen < 0.0 and journey != null and _ahead_of_camera() < rise_at:
		risen = age
		journey.emit_signal("journey_event", "crows_rise", global_position, "rise")
	var n_sit: int = 0
	var n_up: int = 0
	var n_down: int = 0
	for b: Dictionary in birds:
		var pos: Vector3 = b["pos"]
		var flying: bool = risen >= 0.0 and age - risen >= float(b["delay"])
		if not flying:
			# Sitting: a hop or a peck now and then.
			b["peck"] = float(b["peck"]) + delta * rng.randf_range(0.5, 2.5)
			var bob: float = maxf(0.0, sin(float(b["peck"]) * 3.0)) * 0.04
			_sit.set_instance_transform(n_sit, Transform3D(Basis(Vector3.UP, float(b["yaw"])), pos + Vector3(0, bob, 0)))
			n_sit += 1
			continue
		var t: float = age - risen - float(b["delay"])
		var dir: Vector3 = b["dir"]
		var climb: float = float(b["climb"]) * clampf(1.4 - t * 0.12, 0.3, 1.4)
		b["pos"] = pos + dir * float(b["fly"]) * minf(1.0, 0.35 + t) * delta + Vector3(0, climb * delta, 0)
		var face := Basis(Vector3.UP, atan2(dir.x, dir.z))
		# Beating hard as they lift, then gliding between beats.
		var hz: float = float(b["beat"]) * (1.0 if t < 2.0 else 0.55)
		var down: bool = fposmod(float(b["phase"]) + t * hz, 1.0) < 0.5
		var xf := Transform3D(face, b["pos"] as Vector3)
		if down:
			_down.set_instance_transform(n_down, xf)
			n_down += 1
		else:
			_up.set_instance_transform(n_up, xf)
			n_up += 1
	_sit.visible_instance_count = n_sit
	_up.visible_instance_count = n_up
	_down.visible_instance_count = n_down
	if age >= LIFE_S or (risen >= 0.0 and age - risen > 9.0):
		_done = true


## How far ahead of the middle of the camera's view the clump is, metres.
func _ahead_of_camera() -> float:
	var land: Node3D = journey.get("land")
	var x: float = land.position.x + position.x
	return x - float(journey.call("_cam_x"))


func _build_draw() -> void:
	_sit = _multi("Sitting", _bird_mesh(0))
	_up = _multi("WingsUp", _bird_mesh(1))
	_down = _multi("WingsDown", _bird_mesh(-1))


func _multi(label: String, mesh: Mesh) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = maxi(birds.size(), 1)
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-60, -4, -60), Vector3(160, 50, 120))
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return mm


## A crow, front along +z: a body and, flying, two wings up (1) or down (-1); 0 sitting.
static func _bird_mesh(wings: int) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body: float = 0.42 if wings != 0 else 0.34
	_face(st, Vector3(0, 0.1, body * 0.55), Vector3(0.07, 0.08, 0), Vector3(-0.07, 0.08, 0))
	_face(st, Vector3(0.07, 0.08, 0), Vector3(0, 0.07, -body * 0.45), Vector3(-0.07, 0.08, 0))
	_face(st, Vector3(0, 0.15, 0.05), Vector3(0.07, 0.08, 0), Vector3(-0.07, 0.08, 0))
	if wings == 0:
		_face(st, Vector3(0, 0.0, 0.12), Vector3(0.09, 0.08, -0.05), Vector3(-0.09, 0.08, -0.05))
	else:
		var tip: float = 0.26 * float(wings)
		for s: float in [-1.0, 1.0]:
			_face(st, Vector3(0.04 * s, 0.09, 0.08), Vector3(0.46 * s, 0.09 + tip, -0.02), Vector3(0.04 * s, 0.09, -0.1))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BIRD
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	return st.commit()


static func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n: Vector3 = (c - a).cross(b - a).normalized()
	for v in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(v)
