extends Node3D

const Graybox = preload("res://scripts/graybox.gd")
const Visibility = preload("res://scripts/grid_visibility.gd")
const NoiseRadius = preload("res://scripts/noise_radius.gd")
const WIDTH: int = 48
const HEIGHT: int = 32
const MAX_ZOMBIES: int = 150
const SIGHT_RADIUS: int = 16
const NOISE_RADIUS: float = 12.0

var settings: Dictionary = {}
var vat_assets: Dictionary = {}
var camera: Camera3D
var environment: Environment
var player: Node3D
var destination := Vector3(-6, 0, 5)
var blockers: Dictionary = {}
var visible_cells: Dictionary = {}
var zombies: Array[Dictionary] = []
var crowd: MultiMeshInstance3D
var darkness: MultiMeshInstance3D
var rain: GPUParticles3D
var rng := RandomNumberGenerator.new()
var noise_target := Vector3.ZERO
var noise_time: float = 0.0
var drawn_count: int = 0
var mask_accumulator: float = 0.0
var field_started_ms: int = 0
var noise_hits: int = 0

func _ready() -> void:
	rng.seed = 20261007
	field_started_ms = Time.get_ticks_msec()
	environment = Graybox.environment_for(self, bool(settings.get("fog", true)))
	Graybox.box(self, Vector3(WIDTH, 0.2, HEIGHT), Vector3(0, -0.2, 0), 0.42)
	_build_station()
	player = Node3D.new()
	add_child(player)
	player.position = destination
	Graybox.box(player, Vector3(0.6, 1.7, 0.5), Vector3(0, 0.85, 0), 0.85)
	camera = Graybox.camera_for(self, Vector3(12, 9, 18), Vector3(0, 1, 1), 16)
	var start := camera.transform
	camera.position = Vector3(22, 32, 26)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	var finish := camera.transform
	camera.transform = start
	var tween := create_tween()
	tween.tween_method(func(weight: float) -> void: camera.transform = start.interpolate_with(finish, weight), 0.0, 1.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(camera, "size", 38.0, 1.8)
	_build_zombies()
	_build_darkness()
	_build_rain()
	_refresh_visibility()
	_render_crowd()

func _build_station() -> void:
	# Station rectangle; south-wall doorway remains open at x=-1,0,1.
	for x in range(-5, 6):
		_wall(Vector2i(x + WIDTH / 2, -5 + HEIGHT / 2))
		if absi(x) > 1:
			_wall(Vector2i(x + WIDTH / 2, 1 + HEIGHT / 2))
	for z in range(-4, 1):
		_wall(Vector2i(-5 + WIDTH / 2, z + HEIGHT / 2))
		_wall(Vector2i(5 + WIDTH / 2, z + HEIGHT / 2))
	Graybox.box(self, Vector3(11, 0.15, 7), Vector3(0, 0.05, -2), 0.3)
	# Door marker, no blocker/collision in the opening.
	Graybox.box(self, Vector3(2.8, 0.06, 0.8), Vector3(0, 0.18, 1), 0.7)
	for index in range(3):
		var cell := Vector2i(34 + index, 21)
		_wall(cell)

func _wall(cell: Vector2i) -> void:
	blockers[cell] = true
	Graybox.box(self, Vector3(1, 2.4, 1), _world(cell) + Vector3(0, 1.2, 0), 0.35)

func _build_zombies() -> void:
	crowd = MultiMeshInstance3D.new()
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = vat_assets["mesh"]
	instances.instance_count = MAX_ZOMBIES
	instances.visible_instance_count = 0
	instances.custom_aabb = AABB(Vector3(-25, -1, -17), Vector3(50, 5, 34))
	crowd.multimesh = instances
	add_child(crowd)
	for index in range(MAX_ZOMBIES):
		var at := _random_free_position()
		zombies.append({"position": at, "target": _random_free_position(), "phase": rng.randf(), "chase": 0.0, "angle": 0.0})

func _random_free_position() -> Vector3:
	for attempt in range(100):
		var cell := Vector2i(rng.randi_range(1, WIDTH - 2), rng.randi_range(1, HEIGHT - 2))
		if not blockers.has(cell):
			return _world(cell)
	return Vector3(-10, 0, 8)

func _build_darkness() -> void:
	darkness = MultiMeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.02, 1.02)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.055, 0.055, 0.055)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	plane.material = material
	var mask := MultiMesh.new()
	mask.transform_format = MultiMesh.TRANSFORM_3D
	mask.mesh = plane
	mask.instance_count = WIDTH * HEIGHT
	mask.visible_instance_count = 0
	mask.custom_aabb = AABB(Vector3(-25, 2, -17), Vector3(50, 1, 34))
	darkness.multimesh = mask
	add_child(darkness)

func _build_rain() -> void:
	rain = GPUParticles3D.new()
	rain.amount = 256
	rain.lifetime = 1.3
	rain.visibility_aabb = AABB(Vector3(-26, -2, -18), Vector3(52, 12, 36))
	rain.position.y = 7.0
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(24, 0.5, 16)
	process.direction = Vector3(0.08, -1, 0)
	process.spread = 4.0
	process.initial_velocity_min = 6.0
	process.initial_velocity_max = 7.0
	process.gravity = Vector3(0, -2, 0)
	rain.process_material = process
	var drop := BoxMesh.new()
	drop.size = Vector3(0.025, 0.25, 0.025)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.65, 0.65, 0.65)
	drop.material = material
	rain.draw_pass_1 = drop
	add_child(rain)
	rain.emitting = bool(settings.get("rain", true))

func apply_settings(new_settings: Dictionary) -> void:
	settings = new_settings.duplicate()
	environment.fog_enabled = bool(settings["fog"])
	rain.emitting = bool(settings["rain"])
	_refresh_visibility()
	_render_crowd()

func emit_noise() -> void:
	noise_target = player.position
	noise_time = 6.0
	noise_hits = 0
	for index in range(int(settings["zombies"])):
		var at: Vector3 = zombies[index]["position"]
		if NoiseRadius.contains(Vector2(at.x, at.z), Vector2(noise_target.x, noise_target.z), NOISE_RADIUS):
			zombies[index]["target"] = noise_target
			zombies[index]["chase"] = 6.0
			noise_hits += 1

func _physics_process(delta: float) -> void:
	var direction := destination - player.position
	if direction.length() > 0.12:
		_move_actor(player, direction.normalized() * minf(4.0 * delta, direction.length()))
	noise_time = maxf(0, noise_time - delta)
	for index in range(int(settings["zombies"])):
		var zombie: Dictionary = zombies[index]
		var at: Vector3 = zombie["position"]
		var chasing := maxf(0, float(zombie["chase"]) - delta)
		var target: Vector3 = zombie["target"]
		if chasing <= 0.0 and at.distance_to(target) < 0.4:
			target = _random_free_position()
		var difference := target - at
		if difference.length() > 0.1:
			var step := difference.normalized() * minf((1.8 if chasing > 0 else 0.65) * delta, difference.length())
			at = _slide(at, step)
			zombie["angle"] = atan2(difference.x, difference.z)
		zombie["position"] = at
		zombie["target"] = target
		zombie["chase"] = chasing
	mask_accumulator += delta
	if mask_accumulator >= 0.1:
		mask_accumulator = 0.0
		_refresh_visibility()

func _process(_delta: float) -> void:
	_render_crowd()

func _move_actor(actor: Node3D, step: Vector3) -> void:
	actor.position = _slide(actor.position, step)

func _slide(at: Vector3, step: Vector3) -> Vector3:
	var result := at
	var candidate := result + Vector3(step.x, 0, 0)
	if _can_walk(candidate):
		result.x = candidate.x
	candidate = result + Vector3(0, 0, step.z)
	if _can_walk(candidate):
		result.z = candidate.z
	return result

func _can_walk(at: Vector3) -> bool:
	var cell := _cell(at)
	return cell.x >= 0 and cell.y >= 0 and cell.x < WIDTH and cell.y < HEIGHT and not blockers.has(cell)

func _refresh_visibility() -> void:
	var enabled := bool(settings.get("visibility", true))
	darkness.visible = enabled
	if not enabled:
		visible_cells.clear()
		return
	visible_cells = Visibility.compute(WIDTH, HEIGHT, _cell(player.position), SIGHT_RADIUS, blockers)
	var hidden: int = 0
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var cell := Vector2i(x, y)
			if not visible_cells.has(cell):
				darkness.multimesh.set_instance_transform(hidden, Transform3D(Basis.IDENTITY, _world(cell) + Vector3(0, 2.55, 0)))
				hidden += 1
	darkness.multimesh.visible_instance_count = hidden

func _render_crowd() -> void:
	var count: int = 0
	for index in range(int(settings["zombies"])):
		var zombie: Dictionary = zombies[index]
		var at: Vector3 = zombie["position"]
		if bool(settings["visibility"]) and not visible_cells.has(_cell(at)):
			continue
		# CPU frustum selection: the displayed count is submitted VAT instances.
		if not camera.is_position_in_frustum(at + Vector3(0, 0.9, 0)):
			continue
		crowd.multimesh.set_instance_transform(count, Transform3D(Basis(Vector3.UP, float(zombie["angle"])), at))
		crowd.multimesh.set_instance_custom_data(count, Color(float(zombie["phase"]), 1.0 if float(zombie["chase"]) > 0 else 0.0, 0, 1))
		count += 1
	drawn_count = count
	crowd.multimesh.visible_instance_count = count

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_tap_move(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_tap_move(event.position)

func _tap_move(screen_position: Vector2) -> void:
	var ray_origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.0001:
		return
	var distance := -ray_origin.y / direction.y
	if distance < 0:
		return
	var target := ray_origin + direction * distance
	if _can_walk(target):
		destination = target

func _cell(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x + WIDTH * 0.5), floori(at.z + HEIGHT * 0.5))

func _world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x - WIDTH * 0.5 + 0.5, 0, cell.y - HEIGHT * 0.5 + 0.5)
