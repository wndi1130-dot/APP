extends "res://addons/gut/test.gd"

const TurntableView = preload("res://game/world/turntable_view.gd")
const StoryLook = preload("res://game/world/story_look.gd")
const Story01 = preload("res://game/world/maps/story_01.gd")
const MapView = preload("res://game/world/map_view.gd")


func _spec() -> Dictionary:
	return StoryLook.for_place("story_01")["turntable"]


func test_one_surface_shared_material_level_parent_no_collision() -> void:
	var parent: Node3D = autofree(Node3D.new())
	var material := ShaderMaterial.new()
	material.shader = preload("res://game/world/world_vis.gdshader")
	var node := TurntableView.build(parent, material, _spec())
	assert_eq(parent.get_child_count(), 1)
	assert_eq(node.get_parent(), parent)
	assert_eq(node.mesh.get_surface_count(), 1)
	assert_eq(node.material_override, material)
	var shared: ShaderMaterial = node.material_override
	assert_eq(node.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_eq(node.get_child_count(), 0, "충돌체를 포함해 자식이 없다")
	var view: MapView = autofree(MapView.new())
	view.material = material
	view.set_mask_enabled(false)
	assert_eq(shared.get_shader_parameter("mask_on"), 0.0)
	view.set_mask_enabled(true)
	assert_eq(shared.get_shader_parameter("mask_on"), view.mask_shade)
	view.set_sight_round(Vector2(40.5, 62.5), 12.0, 0.5, 0.0)
	assert_eq(shared.get_shader_parameter("eye_xz"), Vector2(40.5, 62.5))
	assert_eq(shared.get_shader_parameter("eye_r"), 12.0)
	assert_eq(shared.get_shader_parameter("round_day"), 0.5)
	assert_eq(shared.get_shader_parameter("round_floor"), 0.0)
	view.set_lamp_gain(0.7)
	assert_almost_eq(float(shared.get_shader_parameter("lamp_gain")), 0.7, 0.0001)


func test_arrays_keep_ground_channels_bounds_and_triangle_budget() -> void:
	var spec := _spec()
	var mesh_arrays := TurntableView.arrays(spec)
	var vertices: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = mesh_arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = mesh_arrays[Mesh.ARRAY_COLOR]
	var uv: PackedVector2Array = mesh_arrays[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = mesh_arrays[Mesh.ARRAY_TEX_UV2]
	assert_gt(vertices.size(), 0)
	assert_lte(vertices.size(), 600 * 3)
	assert_eq(vertices.size() % 3, 0)
	for i in vertices.size():
		assert_eq(uv[i], Vector2.ZERO)
		assert_eq(uv2[i].y, 0.0)
		assert_true([0.0, 3.0, 8.0].has(uv2[i].x))
		assert_eq(colors[i].a, 1.0)
		assert_between(vertices[i].y, 0.0, 0.20001)
		assert_lte(vertices[i].z, 71.00001)
		if uv2[i].x != 0.0:
			assert_lte(Vector2(vertices[i].x, vertices[i].z).distance_to(spec["center"]), 8.55001)
	for i in range(0, vertices.size(), 3):
		var normal := (vertices[i + 2] - vertices[i]).cross(vertices[i + 1] - vertices[i]).normalized()
		assert_gt(normal.dot(normals[i]), 0.999, "면 방향과 명시한 법선이 같다")


func test_disc_covers_every_old_painted_cell_corner() -> void:
	var mesh_arrays := TurntableView.arrays(_spec())
	var vertices: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX]
	var uv2: PackedVector2Array = mesh_arrays[Mesh.ARRAY_TEX_UV2]
	var farthest: float = 0.0
	for y in range(-8, 9):
		for x in range(-8, 9):
			if x * x + y * y > 64:
				continue
			for offset: Vector2 in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
				var local := Vector2(x, y) + offset
				farthest = maxf(farthest, local.length())
				var point := Vector2(Story01.TURNTABLE_CENTER) + Vector2(0.5, 0.5) + local
				var covered := false
				for i in range(0, vertices.size(), 3):
					if uv2[i].x == 0.0 or not is_equal_approx(vertices[i].y, vertices[i + 1].y) or not is_equal_approx(vertices[i].y, vertices[i + 2].y):
						continue
					if _in_triangle(point, vertices[i], vertices[i + 1], vertices[i + 2]):
						covered = true
						break
				assert_true(covered, "옛 칠 모서리 %s" % point)
	assert_almost_eq(farthest, sqrt(72.5), 0.00001)
	assert_gt(float(_spec()["outer_radius"]), farthest)


func _in_triangle(point: Vector2, a3: Vector3, b3: Vector3, c3: Vector3) -> bool:
	var a := Vector2(a3.x, a3.z)
	var b := Vector2(b3.x, b3.z)
	var c := Vector2(c3.x, c3.z)
	var ab := (b - a).cross(point - a)
	var bc := (c - b).cross(point - b)
	var ca := (a - c).cross(point - c)
	return (ab >= -0.00001 and bc >= -0.00001 and ca >= -0.00001) or (ab <= 0.00001 and bc <= 0.00001 and ca <= 0.00001)


func test_fan_lengths_spacing_bridge_axis_and_rail_vertex_contract() -> void:
	var spec := _spec()
	assert_eq(spec["bridge_axis"], Vector2(0, 1))
	assert_eq(spec["bridge_width"], 2.4)
	assert_eq(spec["fan_angles"], [-55.0, -30.0, 30.0, 55.0])
	assert_eq(TurntableView.RAIL_WIDTH, 0.20)
	assert_eq(TurntableView.BED_WIDTH, 2.5)
	assert_eq(TurntableView.STOP_LENGTH, 0.4)
	var fans := TurntableView.fans(spec)
	assert_eq(fans.size(), 4)
	for i in fans.size():
		var fan: Dictionary = fans[i]
		var start: Vector2 = fan["start"]
		var direction: Vector2 = fan["direction"]
		var end := start + direction * float(fan["length"])
		if fan["stop"]:
			assert_eq(fan["length"], 3.0)
		else:
			assert_almost_eq(end.y, 71.0, 0.00001)
			assert_between(float(fan["length"]), 1.2, 1.4)
		if i > 0:
			var previous: Vector2 = fans[i - 1]["start"]
			assert_gte(start.distance_to(previous) - TurntableView.BED_WIDTH, 1.0)
	var mesh_arrays := TurntableView.arrays(spec)
	var vertices: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = mesh_arrays[Mesh.ARRAY_COLOR]
	var rail_tops: int = 0
	for i in range(0, vertices.size(), 3):
		if colors[i] != TurntableView.STEEL or not is_equal_approx(vertices[i].y, vertices[i + 1].y) or not is_equal_approx(vertices[i].y, vertices[i + 2].y):
			continue
		rail_tops += 1
		assert_gte(colors[i].v, 0.60)
		assert_gte(colors[i].v - TurntableView.BED.v, 0.30)
		assert_gte(colors[i].v - TurntableView.SLEEPER.v, 0.30)
		# 벽에서 잘린 레일도 시작 쪽 폭 0.20 m를 첫 삼각형의 한 변으로 가진다.
		if rail_tops % 2 == 1:
			var shortest := minf(vertices[i].distance_to(vertices[i + 1]), minf(vertices[i + 1].distance_to(vertices[i + 2]), vertices[i + 2].distance_to(vertices[i])))
			assert_almost_eq(shortest, 0.20, 0.0001)
	assert_eq(rail_tops, 20, "가운데 두 줄과 부채꼴 여덟 줄")
	assert_lte(TurntableView.BED.v, 0.30)
	assert_lte(TurntableView.SLEEPER.v, 0.30)
	assert_gte(MapView.FLOOR_COLORS[0].v - TurntableView.BED.v, 0.20)
	assert_true(colors.has(TurntableView.BED))
	assert_true(colors.has(TurntableView.SLEEPER))


func test_empty_spec_draws_nothing() -> void:
	var parent: Node3D = autofree(Node3D.new())
	assert_null(TurntableView.build(parent, StandardMaterial3D.new(), {}))
	assert_eq(parent.get_child_count(), 0)
	assert_eq(TurntableView.arrays({}), [])
