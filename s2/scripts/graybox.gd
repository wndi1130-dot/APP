extends RefCounted

static func box(parent: Node3D, size: Vector3, at: Vector3, shade: float = 0.5) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(shade, shade, shade)
	material.roughness = 1.0
	mesh.material = material
	node.mesh = mesh
	node.position = at
	parent.add_child(node)
	return node

static func environment_for(parent: Node3D, fog: bool, shadows: bool = false) -> Environment:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.16, 0.16, 0.16)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.65, 0.65, 0.65)
	environment.ambient_light_energy = 0.7
	# Depth fog works on Mobile; volumetric fog requires Forward+.
	environment.fog_enabled = fog
	environment.fog_density = 0.025
	environment.fog_light_color = Color(0.45, 0.45, 0.45)
	world.environment = environment
	parent.add_child(world)
	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 0.8
	# One sun shadow; the distance covers the oblique top-view field.
	light.shadow_enabled = shadows
	light.directional_shadow_max_distance = 65.0
	parent.add_child(light)
	return environment

static func camera_for(parent: Node3D, at: Vector3, target: Vector3, size: float) -> Camera3D:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size
	camera.near = 0.1
	camera.far = 150.0
	parent.add_child(camera)
	camera.position = at
	camera.look_at(target, Vector3.UP)
	camera.current = true
	return camera

static func train(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	for index in range(6):
		var x := (float(index) - 2.5) * 4.0
		# Open side: floor, rear panel, roof, end walls; exactly six cars.
		box(root, Vector3(3.7, 0.25, 2.2), Vector3(x, 0.3, 0), 0.5)
		box(root, Vector3(3.7, 2.1, 0.15), Vector3(x, 1.5, -1.0), 0.4)
		box(root, Vector3(3.7, 0.15, 2.2), Vector3(x, 2.6, 0), 0.55)
		box(root, Vector3(0.12, 2.1, 2.2), Vector3(x - 1.8, 1.5, 0), 0.35)
		box(root, Vector3(0.55, 0.4, 0.9), Vector3(x, 0.65, -0.5), 0.6)
	return root
