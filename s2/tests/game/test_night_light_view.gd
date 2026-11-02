extends "res://addons/gut/test.gd"
## GPU readback is unnecessary: inspect built nodes and resources.
const View = preload("res://game/world/night_light_view.gd")
const LampLight = preload("res://game/sim/lamp_light.gd")
const Switch = preload("res://game/perf_switch.gd")


func _view(parent: Node = null) -> View:
	var view := View.new()
	view.name = "NightLights"
	if parent == null:
		add_child_autofree(view)
	else:
		parent.add_child(view)
	view.build({"lights": [
		{"id": "camp", "kind": "campfire", "cell": Vector2i(2, 2)},
		{"id": "drum", "kind": "barrel_fire", "cell": Vector2i(5, 2)},
		{"id": "candle", "kind": "candle", "cell": Vector2i(8, 2), "side": Vector2i(1, 0)},
		{"id": "car", "kind": "headlights", "cell": Vector2i(11, 2), "side": Vector2i(1, 0)},
	]})
	return view


func test_actual_parts_roles_layers_and_beds_for_every_kind() -> void:
	var view := _view()
	var expected := {"camp": [3, 1, 1, 0], "drum": [2, 1, 1, 0], "candle": [0, 0, 0, 1], "car": [0, 0, 0, 2]}
	var actual_glows := 0
	for id: String in expected:
		var counts := [0, 0, 0, 0]
		var flames: Array[MeshInstance3D] = []
		var phases: Array = []
		var seeds: Array = []
		var sizes: Array = []
		for node: MeshInstance3D in view.parts[id]["glow"]:
			assert_eq(node.get_parent(), view)
			assert_true(node.mesh is QuadMesh)
			var mat := node.material_override as ShaderMaterial
			assert_eq(mat.shader.resource_path, "res://game/world/night_flame.gdshader")
			var role := String(node.get_meta("fire_role", ""))
			assert_true(role in ["flame", "bed", "glow"])
			if role == "bed":
				counts[1] += 1
				assert_eq(mat.get_shader_parameter("bed"), true)
				assert_almost_eq(node.basis.z.dot(Vector3.UP), 1.0, 0.00001)
				assert_eq((node.mesh as QuadMesh).size, Vector2.ONE * (0.9 if id == "camp" else 0.55))
				assert_almost_eq(node.position.y, View.CAMP_BED_Y if id == "camp" else View.BARREL_BED_Y, 0.00001)
			elif role == "flame":
				counts[0] += 1
				flames.append(node)
				assert_eq(mat.get_shader_parameter("round_glow"), 0.0)
				var phase: float = mat.get_shader_parameter("phase")
				var seed: float = mat.get_shader_parameter("seed")
				var size: Vector2 = (node.mesh as QuadMesh).size
				assert_false(phases.has(phase))
				assert_false(seeds.has(seed))
				assert_false(sizes.has(size))
				phases.append(phase)
				seeds.append(seed)
				sizes.append(size)
			else:
				counts[3] += 1
				assert_eq(mat.get_shader_parameter("round_glow"), 1.0)
			actual_glows += 1
		for i in range(1, flames.size()):
			var offset := flames[i].position - flames[0].position
			assert_almost_eq(Vector2(offset.x, offset.z).length(), 0.25, 0.001)
			assert_lt((flames[i].mesh as QuadMesh).size.y, (flames[0].mesh as QuadMesh).size.y)
		var sparks: GPUParticles3D = view.parts[id]["sparks"]
		if sparks != null:
			counts[2] += 1
			assert_eq(sparks.get_parent(), view)
			assert_eq(sparks.get_meta("fire_role"), "sparks")
			assert_gte(sparks.amount, 8)
			assert_lte(sparks.amount, 12)
		assert_eq(counts, expected[id], id + ": each role must exist")
	var tagged_glows := 0
	for node: Node in view.get_children():
		if node is MeshInstance3D and node.has_meta("fire_role"):
			tagged_glows += 1
	assert_eq(tagged_glows, actual_glows, "no orphaned glowing parts")
	assert_eq(actual_glows, 10)


func test_off_on_off_updates_every_part_and_keeps_stones_visible() -> void:
	var view := _view()
	var stones := view.get_node_or_null("Stones_camp") as Node3D
	assert_not_null(stones, "actual model stays outside the light group")
	for on: bool in [false, true, false]:
		for id: String in view.parts:
			view.set_on(id, on)
			assert_eq(view.is_on(id), on)
			for node: MeshInstance3D in view.parts[id]["glow"]:
				assert_eq(node.visible, on)
			var sparks: GPUParticles3D = view.parts[id]["sparks"]
			if sparks != null:
				assert_eq(sparks.visible, on)
				assert_eq(sparks.emitting, on)
		if stones != null:
			assert_true(stones.visible)
			assert_true(stones.is_visible_in_tree())


func test_parent_and_view_visibility_restore_emission_without_restart() -> void:
	var parent := Node3D.new()
	parent.visible = false
	parent.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(parent)
	var view := _view(parent)
	view.set_on("camp", true)
	var sparks: GPUParticles3D = view.parts["camp"]["sparks"]
	assert_true(view.is_on("camp"))
	assert_false(sparks.emitting)
	parent.show()
	assert_true(sparks.emitting)
	for surface: Node3D in [parent, view]:
		surface.hide()
		assert_true(view.is_on("camp"))
		assert_false(sparks.emitting)
		surface.show()
		assert_true(sparks.emitting)
	var material := sparks.process_material
	for i in 3:
		view.set_on("camp", true)
		assert_eq(view.parts["camp"]["sparks"], sparks)
		assert_eq(sparks.process_material, material)
		assert_true(sparks.emitting)
	# Count call sites instead of trusting a counter that nobody increments.
	var source := FileAccess.get_file_as_string("res://game/world/night_light_view.gd")
	var calls := RegEx.new()
	calls.compile("\\brestart\\s*\\(")
	assert_eq(calls.search_all(source).size(), 0, "zero restart calls")
	assert_true(source.contains("if sparks.emitting != emitting:"))


func test_no_smoke_or_extra_lights_and_correct_spark_shader() -> void:
	var view := _view()
	var smoke_count := 0
	var spark_count := 0
	for node: Node in view.find_children("*", "GPUParticles3D", true, false):
		var sparks := node as GPUParticles3D
		if sparks.has_meta("fx_kind"):
			smoke_count += 1
		assert_eq(sparks.draw_passes, 1)
		for pass_index in sparks.draw_passes:
			var mesh := sparks.get_draw_pass_mesh(pass_index)
			assert_not_null(mesh)
			if mesh == null:
				continue
			for surface in mesh.get_surface_count():
				var mat := sparks.material_override as ShaderMaterial
				if mat == null:
					mat = mesh.surface_get_material(surface) as ShaderMaterial
				assert_not_null(mat)
				if mat == null:
					continue
				if mat.shader.resource_path.ends_with("smoke_soft.gdshader"):
					smoke_count += 1
				assert_eq(mat.shader.resource_path, "res://game/world/night_spark.gdshader")
		spark_count += 1
	assert_eq(smoke_count, 0)
	assert_eq(spark_count, 2)
	assert_eq(view.find_children("*", "Light3D", true, false).size(), 0)
	assert_true(View.FLAME.code.contains("if (!bed)"))
	for shader: Shader in [View.FLAME, View.SPARK]:
		assert_true(shader.code.contains("depth_draw_never"))
		assert_false(shader.code.contains("depth_test_disabled"))
		assert_true(shader.code.contains("fx_common.gdshaderinc"))
		assert_true(shader.code.contains("fx_photo("))
	assert_true(View.SPARK.code.contains("INSTANCE_CUSTOM.y"))
	assert_true(View.SPARK.code.contains("COLOR.a"))
	assert_true(View.SPARK.code.contains("length(MODEL_MATRIX[0].xyz)"))


func _rise_bound(sparks: GPUParticles3D) -> float:
	var motion := sparks.process_material as ParticleProcessMaterial
	var v := motion.initial_velocity_max  # every launch assumed straight up
	var g := motion.gravity.y
	var t := sparks.lifetime
	if g < 0.0:
		t = minf(t, maxf(0.0, -v / g))  # include an apex before death
	# Nonnegative drag cannot increase ascent. Ignoring it is conservative.
	var rise := maxf(0.0, v * t + 0.5 * g * t * t)
	var quad := sparks.draw_pass_1 as QuadMesh
	var sway: float = (quad.material as ShaderMaterial).get_shader_parameter("sway")
	return motion.emission_box_extents.y + rise + sway + quad.size.length() * motion.scale_max * 0.5


func test_built_particle_settings_bound_height_and_respond_to_weather() -> void:
	var view := _view()
	for kinds: Array in [[], ["rain"], ["blizzard"], ["sleet"], []]:
		view.set_weather({"fx_wind": Vector3(1, 0, 0.8)}, kinds)
		for id: String in ["camp", "drum"]:
			var sparks: GPUParticles3D = view.parts[id]["sparks"]
			var motion := sparks.process_material as ParticleProcessMaterial
			assert_eq(motion.emission_shape, ParticleProcessMaterial.EMISSION_SHAPE_BOX)
			assert_eq(motion.direction, Vector3.UP)
			assert_gte(motion.damping_min, 0.0)
			assert_gte(motion.damping_max, motion.damping_min)
			assert_false(motion.turbulence_enabled)
			assert_eq(motion.linear_accel_min, 0.0)
			assert_eq(motion.linear_accel_max, 0.0)
			assert_eq(motion.radial_accel_min, 0.0)
			assert_eq(motion.radial_accel_max, 0.0)
			assert_eq(motion.tangential_accel_min, 0.0)
			assert_eq(motion.tangential_accel_max, 0.0)
			assert_lte(motion.gravity.y, 0.0)
			assert_almost_eq(motion.gravity.x, 0.2, 0.00001)
			assert_almost_eq(sparks.amount_ratio, 1.0 if kinds.is_empty() else 0.6, 0.00001)
			assert_almost_eq(sparks.lifetime, 1.1 if kinds.is_empty() else 0.8, 0.00001)
			assert_lte(_rise_bound(sparks), 1.5, id + str(kinds))
			# Even omitting gravity and drag stays safe with discrete GPU time steps.
			var quad := sparks.draw_pass_1 as QuadMesh
			var pad := motion.emission_box_extents.y + float((quad.material as ShaderMaterial).get_shader_parameter("sway"))
			pad += quad.size.length() * motion.scale_max * 0.5
			assert_lte(pad + motion.initial_velocity_max * sparks.lifetime, 1.5)
			motion.gravity.y = -6.0
			assert_almost_eq(_rise_bound(sparks) - pad, motion.initial_velocity_max * motion.initial_velocity_max / 12.0, 0.00001, "apex before death")
		view.set_weather({"fx_wind": Vector3.ZERO}, [])
	view.set_weather({"fx_wind": Vector3(0, -1, 0.4)}, [])
	var sparks: GPUParticles3D = view.parts["camp"]["sparks"]
	assert_almost_eq((sparks.process_material as ParticleProcessMaterial).gravity.z, -0.1, 0.00001)
	view.set_weather({"fx_wind": Vector3(1, 1, 0)}, [])
	assert_eq((sparks.process_material as ParticleProcessMaterial).gravity, Vector3(0, -View.SPARK_FALL, 0))


func test_sparks_leave_inside_the_flame_and_clear_its_tip() -> void:
	# Launched from the embers they died inside the main flame quad and never showed.
	var view := _view()
	for id: String in ["camp", "drum"]:
		var sparks: GPUParticles3D = view.parts[id]["sparks"]
		var main: MeshInstance3D = view.parts[id]["glow"][0]
		assert_eq(String(main.get_meta("fire_role")), "flame")
		var top: float = main.position.y + (main.mesh as QuadMesh).size.y * 0.5
		assert_lt(sparks.position.y, top, id)
		assert_gt(sparks.position.y, main.position.y - (main.mesh as QuadMesh).size.y * 0.5, id)
		# The slowest spark, without drag, by the time it starts to fade.
		var motion := sparks.process_material as ParticleProcessMaterial
		var t := sparks.lifetime * 0.8
		var climb := motion.initial_velocity_min * t + 0.5 * motion.gravity.y * t * t
		assert_gt(sparks.position.y + climb, top, id)


func _alarm_red(c: Color) -> bool:
	return c.s > 0.5 and (c.h < 12.0 / 360.0 or c.h > 348.0 / 360.0)


func _assert_fire_palette(c: Color) -> void:
	assert_false(_alarm_red(c))
	assert_gte(c.h * 360.0, 20.0)
	assert_lte(c.h * 360.0, 45.0)


func test_fire_constants_and_built_materials_stay_in_orange_palette() -> void:
	for c: Color in [View.FLAME_TINT, View.CORE_TINT, View.BED_TINT, View.SPARK_TINT]:
		_assert_fire_palette(c)
	assert_true(_alarm_red(Color.from_hsv(350.0 / 360.0, 0.9, 1.0)))
	assert_true(_alarm_red(Color.from_hsv(5.0 / 360.0, 0.9, 1.0)))
	assert_false(_alarm_red(Color.WHITE))
	var view := _view()
	for id: String in ["camp", "drum"]:
		for node: MeshInstance3D in view.parts[id]["glow"]:
			var mat := node.material_override as ShaderMaterial
			_assert_fire_palette(mat.get_shader_parameter("tint"))
			_assert_fire_palette(mat.get_shader_parameter("core_tint"))
		var sparks: GPUParticles3D = view.parts[id]["sparks"]
		var motion := sparks.process_material as ParticleProcessMaterial
		_assert_fire_palette(motion.color)
		for c: Color in (motion.color_ramp as GradientTexture1D).gradient.colors:
			assert_false(_alarm_red(c))


func test_sparks_switch_only_changes_sparks_and_defaults_on() -> void:
	var view := _view()
	for id: String in view.parts:
		view.set_on(id, true)
	assert_true(view.sparks_enabled)
	for settings: Dictionary in [{"night_sparks": false}, {"night_sparks": true}, {"night_sparks": false}, {}]:
		Switch.apply_night_sparks(view, settings)
		var enabled: bool = settings.get("night_sparks", true)
		for id: String in view.parts:
			assert_true(view.is_on(id))
			for node: MeshInstance3D in view.parts[id]["glow"]:
				assert_true(node.visible)
			var sparks: GPUParticles3D = view.parts[id]["sparks"]
			if sparks != null:
				assert_eq(sparks.emitting, enabled)
				assert_eq(sparks.visible, enabled)


func test_lamp_result_can_light_a_fire_at_storm_noon() -> void:
	var view := _view()
	var row := {"when": "dusk", "from_min": 900}
	view.set_on("camp", LampLight.is_on(row, 720.0, false, false))
	assert_false(view.is_on("camp"))
	# field_game._light_minutes supplies 1440 when storm.windows_lit is set.
	view.set_on("camp", LampLight.is_on(row, 1440.0, false, false))
	assert_true(view.is_on("camp"))
	assert_true((view.parts["camp"]["sparks"] as GPUParticles3D).emitting)
