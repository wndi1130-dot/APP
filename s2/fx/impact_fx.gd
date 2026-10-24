extends Node3D
## Cosmetic impact API. Simulation supplies confirmed contacts and glass hazards.
## Feedback is sampled by the caller; never changes Engine.time_scale.

const FxState = preload("res://fx/fx_state.gd")
const ParticlePool = preload("res://fx/particle_pool.gd")
const BURST_SHADER = preload("res://fx/shaders/blood_burst.gdshader")
const GLASS_SHADER = preload("res://fx/shaders/impact_residue.gdshader")
const MAX_GLASS := 32
const GLASS_SECONDS := 120.0
const MAX_HITSTOP := 0.045
const SHAKE_SECONDS := 0.14
const SHAKE_METRES := 0.025
const HURT_SECONDS := 0.65

var particles: Node3D
var glass_marks: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _serial := 0
var _stop_left := 0.0
var _shake_left := 0.0
var _hurt_left := 0.0
var _strength := 0.0
var _phase := 0.0
var _feedback_cooldown := 0.0


func _ready() -> void:
	_rng.seed = 1
	particles = ParticlePool.new()
	add_child(particles)
	particles.prepare(8, BURST_SHADER)
	var material := ShaderMaterial.new()
	material.shader = GLASS_SHADER
	var quad := QuadMesh.new()
	quad.material = material
	quad.size = Vector2.ONE
	for _i in range(MAX_GLASS):
		var mark := MeshInstance3D.new()
		mark.mesh = quad
		mark.visible = false
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mark)
		glass_marks.append({"node": mark, "id": -1, "left": 0.0})


func begin_stop(seed_value: int = 1) -> void:
	clear()
	_serial = 0
	_rng.seed = seed_value


func spark(pos: Vector3, normal: Vector3) -> int:
	return _burst(pos, normal, 8, {"style": 1, "life": 0.22, "speed": 3.2, "spread": 50.0, "size": 0.07, "color": Color(1.0, 0.63, 0.24)})


func wood(pos: Vector3, normal: Vector3, strength: float = 1.0) -> int:
	return _burst(pos, normal, clampi(roundi(10 * strength), 1, 12), {"style": 2, "life": 0.6, "speed": 2.0, "size": 0.13, "color": Color(0.36, 0.25, 0.15)})


## Pass a confirmed floor contact for settled shards. They do not create damage.
func glass(pos: Vector3, normal: Vector3, floor_pos: Vector3 = Vector3.INF) -> int:
	var count := _burst(pos, normal, 12, {"style": 3, "life": 0.65, "speed": 2.4, "size": 0.09, "color": Color(0.62, 0.71, 0.73, 0.8)})
	if floor_pos.is_finite():
		for _i in range(6):
			_settle_glass(floor_pos)
	return count


func muzzle(pos: Vector3, direction: Vector3, wind: Vector3 = Vector3.RIGHT) -> int:
	var count := _burst(pos, direction, 1, {"style": 4, "life": 0.055, "speed": 0.2, "size": 0.24, "gravity": Vector3.ZERO, "color": Color(1.0, 0.72, 0.32)})
	count += _burst(pos, _sideways(direction + wind * 0.4), 3, {"style": 6, "life": 0.4, "speed": 0.55, "size": 0.15, "gravity": Vector3.ZERO, "spread": 18.0, "color": Color(0.55, 0.55, 0.56, 0.2)})
	return count


func snow(pos: Vector3, direction: Vector3 = Vector3.RIGHT, falling: bool = false) -> int:
	return _burst(pos, _sideways(direction) + Vector3.UP * 0.3, 12 if falling else 6, {"style": 5, "life": 0.38, "speed": 1.0 if falling else 0.55, "size": 0.15, "gravity": Vector3(0, -1.5, 0), "spread": 45.0, "color": Color(0.70, 0.71, 0.73, 0.5)})


func breath(pos: Vector3, direction: Vector3, ambient_c: float = -10.0, wind: Vector3 = Vector3.ZERO) -> int:
	if ambient_c > 2.0:
		return 0
	return _burst(pos, _sideways(direction + wind * 0.35), 4, {"style": 6, "life": 0.75, "speed": 0.3, "size": 0.15, "gravity": Vector3(0, 0.03, 0), "spread": 12.0, "color": Color(0.68, 0.69, 0.70, 0.18)})


func _burst(pos: Vector3, direction: Vector3, count: int, spec: Dictionary) -> int:
	return particles.burst(pos, direction, count, _rng.randi(), spec)


static func _sideways(direction: Vector3) -> Vector3:
	var flat := Vector3(direction.x, 0.0, direction.z)
	return flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD


func _settle_glass(pos: Vector3) -> void:
	var slot: Dictionary = glass_marks[0]
	for candidate in glass_marks:
		if float(candidate["left"]) <= 0.0:
			slot = candidate
			break
		if int(candidate["id"]) < int(slot["id"]):
			slot = candidate
	_serial += 1
	var node: MeshInstance3D = slot["node"]
	var size := _rng.randf_range(0.04, 0.12)
	node.global_transform = Transform3D(Basis(Vector3.UP, _rng.randf_range(0, TAU)) * Basis(Vector3.RIGHT, -PI * 0.5), pos + Vector3(_rng.randf_range(-0.32, 0.32), 0.012, _rng.randf_range(-0.32, 0.32)))
	node.scale *= Vector3.ONE * size
	node.visible = true
	slot["left"] = GLASS_SECONDS
	slot["id"] = _serial


func hit_feedback(strength: float = 1.0) -> void:
	_strength = clampf(strength, 0.0, 1.0)
	if _feedback_cooldown <= 0.0:
		_stop_left = MAX_HITSTOP * _strength
		_feedback_cooldown = 0.12
	_shake_left = SHAKE_SECONDS
	_hurt_left = HURT_SECONDS * _strength


## Consume once per simulation frame, not once per actor. No pause of UI/audio.
func simulation_delta(delta: float) -> float:
	var dt := maxf(delta, 0.0)
	var used := minf(dt, _stop_left)
	_stop_left -= used
	return dt - used


## Add to the freshly calculated camera position each frame; never accumulate.
func camera_offset() -> Vector3:
	var size := SHAKE_METRES * _strength * clampf(_shake_left / SHAKE_SECONDS, 0.0, 1.0)
	return Vector3(sin(_phase * 113.0), sin(_phase * 157.0) * 0.45, 0.0) * size


func hurt_amount() -> float:
	return clampf(_hurt_left / HURT_SECONDS, 0.0, 1.0)


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	var dt := maxf(delta, 0.0)
	particles.advance(dt)
	_phase += dt
	_shake_left = maxf(0.0, _shake_left - dt)
	_hurt_left = maxf(0.0, _hurt_left - dt)
	_feedback_cooldown = maxf(0.0, _feedback_cooldown - dt)
	for slot in glass_marks:
		slot["left"] = maxf(0.0, float(slot["left"]) - dt)
		slot["node"].visible = float(slot["left"]) > 0.0


func clear() -> void:
	if is_instance_valid(particles):
		particles.clear()
	for slot in glass_marks:
		slot["left"] = 0.0
		slot["node"].visible = false
	_stop_left = 0.0
	_shake_left = 0.0
	_hurt_left = 0.0
	_strength = 0.0
	_phase = 0.0
	_feedback_cooldown = 0.0


func clear_glass(floor_pos: Vector3, radius: float = 0.8) -> void:
	for slot in glass_marks:
		if slot["node"].global_position.distance_to(floor_pos) <= maxf(radius, 0.0):
			slot["left"] = 0.0
			slot["node"].visible = false
