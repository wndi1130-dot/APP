extends "res://addons/gut/test.gd"

const TurntableView = preload("res://game/world/turntable_view.gd")
const StoryLook = preload("res://game/world/story_look.gd")
const Story01 = preload("res://game/world/maps/story_01.gd")
const MapView = preload("res://game/world/map_view.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")

var story_grid: FieldGrid


func before_all() -> void:
	story_grid = Story01.build()["grid"]


func _arrays() -> Array:
	return TurntableView.arrays(_spec(), story_grid, MapView.ground_bank_row)


func _spec() -> Dictionary:
	return StoryLook.for_place("story_01")["turntable"]


func test_one_surface_shared_material_level_parent_no_collision() -> void:
	var parent: Node3D = autofree(Node3D.new())
	var material := ShaderMaterial.new()
	material.shader = preload("res://game/world/world_vis.gdshader")
	var node := TurntableView.build(parent, material, _spec(), story_grid, MapView.ground_bank_row)
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
	var mesh_arrays := _arrays()
	var vertices: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = mesh_arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = mesh_arrays[Mesh.ARRAY_COLOR]
	var uv: PackedVector2Array = mesh_arrays[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = mesh_arrays[Mesh.ARRAY_TEX_UV2]
	assert_gt(vertices.size(), 0)
	# 정점 연산을 별도로 재현한 985개에 약 10% 여유. 엔진 실측은 문지기에서 확인한다.
	assert_lte(vertices.size(), 1084 * 3)
	assert_eq(vertices.size() % 3, 0)
	for i in vertices.size():
		assert_between(uv[i].x, -1.0, 1.0)
		assert_between(uv[i].y, -1.0, 1.0)
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
	var mesh_arrays := _arrays()
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
			assert_almost_eq(end.y - absf(direction.x) * TurntableView.BED_WIDTH * 0.5, 71.0, 0.00001)
			assert_between(float(fan["length"]), 1.9, 2.1)
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


func _weights(point: Vector2, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var origin := Vector2(a.x, a.z)
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ac := Vector2(c.x - a.x, c.z - a.z)
	var offset := point - origin
	var area := ab.cross(ac)
	var wb := offset.cross(ac) / area
	var wc := ab.cross(offset) / area
	return Vector3(1.0 - wb - wc, wb, wc)


## 실제 땅 배열에서 해당 칸의 삼각형을 고른다. 전차대의 보간 도우미는 부르지 않는다.
## grid를 주지 않으면 story_01 지도. pick을 주면 그 점으로 삼각형을 고르고 point의 무게를 잰다 — 칸 경계 위
## 정점은 칸마다 다른 값(하늘 알파)을 가진 두 삼각형에 걸치므로, 그 정점이 든 전차대 조각의 가운데로 고른다.
func _ground_sample(point: Vector2, ground: Dictionary, grid: FieldGrid = null, pick: Vector2 = Vector2.INF) -> Array:
	if grid == null:
		grid = story_grid
	if not pick.is_finite():
		pick = point
	var x := clampi(floori(pick.x), 0, grid.width - 1)
	var z := clampi(floori(pick.y), 0, grid.height - 1)
	var tile := Vector2i(floori(float(x) / MapView.TILE), floori(float(z) / MapView.TILE))
	var arrays: Array = ground[tile]
	var width := mini(MapView.TILE, grid.width - tile.x * MapView.TILE)
	var first := ((z - tile.y * MapView.TILE) * width + x - tile.x * MapView.TILE) * 6
	if pick.x - x < pick.y - z:
		first += 3
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var weights := _weights(point, vertices[first], vertices[first + 1], vertices[first + 2])
	return [weights, [uv[first], uv[first + 1], uv[first + 2]], colors[first].a]


## world_vis.vertex의 식. UV 보간 뒤 변형하지 않고 각 정점을 변형한 뒤 높이를 보간한다.
func _snow_height(uv: Vector2, alpha: float, snow: float, wind: Vector3) -> float:
	var bank := (maxf(0.0, uv.x * wind.x) + maxf(0.0, uv.y * wind.y)) * alpha
	return 0.35 * bank * smoothstep(0.2, 0.9, snow) * (0.4 + 0.6 * wind.z)


func test_snow_uv_and_dense_surface_clearance_match_ground_triangles() -> void:
	var arrays := _arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var ground := MapView.ground_arrays(story_grid, MapView.ground_details(story_grid))
	var banked_vertices: int = 0
	for i in vertices.size():
		var sample := _ground_sample(Vector2(vertices[i].x, vertices[i].z), ground)
		var weights: Vector3 = sample[0]
		var corner_uv: Array = sample[1]
		var expected: Vector2 = corner_uv[0] * weights.x + corner_uv[1] * weights.y + corner_uv[2] * weights.z
		assert_lt(uv[i].distance_to(expected), 0.00001, "땅 삼각형의 UV와 같다")
		if uv[i].length_squared() > 0.00001:
			banked_vertices += 1
	assert_gt(banked_vertices, 0, "실제 눈둑 정점이 있어야 한다")
	var counts: Dictionary = {}
	var clearance: Dictionary = {}
	for i in range(0, vertices.size(), 3):
		if normals[i].y < 0.99:
			continue
		var a := vertices[i]
		var b := vertices[i + 1]
		var c := vertices[i + 2]
		var points: Array[Vector2] = [Vector2((a.x + b.x + c.x) / 3.0, (a.z + b.z + c.z) / 3.0)]
		for zi in range(ceili(minf(a.z, minf(b.z, c.z)) * 10.0), floori(maxf(a.z, maxf(b.z, c.z)) * 10.0) + 1):
			for xi in range(ceili(minf(a.x, minf(b.x, c.x)) * 10.0), floori(maxf(a.x, maxf(b.x, c.x)) * 10.0) + 1):
				var point := Vector2(xi, zi) * 0.1
				var weights := _weights(point, a, b, c)
				if minf(weights.x, minf(weights.y, weights.z)) >= -0.000001:
					points.append(point)
		for point: Vector2 in points:
			var weights := _weights(point, a, b, c)
			var sample := _ground_sample(point, ground)
			var ground_weights: Vector3 = sample[0]
			var corner_uv: Array = sample[1]
			for snow: float in [0.0, 0.5, 1.0]:
				for wind: Vector3 in [Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 0.5), Vector3.ZERO]:
					var ground_y: float = 0.0
					var surface_y: float = 0.0
					for corner in 3:
						ground_y += ground_weights[corner] * _snow_height(corner_uv[corner], float(sample[2]), snow, wind)
						surface_y += weights[corner] * (vertices[i + corner].y + _snow_height(uv[i + corner], colors[i + corner].a, snow, wind))
					clearance[colors[i]] = minf(float(clearance.get(colors[i], INF)), surface_y - ground_y)
			counts[colors[i]] = int(counts.get(colors[i], 0)) + 1
	for color: Color in [TurntableView.FLOOR, TurntableView.RIM, TurntableView.BRIDGE, TurntableView.BED, TurntableView.STEEL]:
		assert_gt(int(counts.get(color, 0)), 0, "모든 종류의 윗면을 표본으로 검사한다")
		assert_gte(float(clearance.get(color, -INF)), 0.02 - 0.00001, "땅 위 2 cm 간격: %s" % color)


## world_vis.vertex의 벽 발치 눈 값(foot): 정점마다 max(|UV.x|, |UV.y|) × COLOR.a를 잡아 면 안에서 보간한다.
static func _foot(uv: Vector2, sky: float) -> float:
	return maxf(absf(uv.x), absf(uv.y)) * sky


## 벽 발치 눈(땅·눈 루프 PR2b, weather_fx 17장)이 전차대 윗면에서도 땅과 같은 자리에 같은 굵기로 쌓인다.
## 땅 정점은 칸 모서리라 모서리마다 잡은 foot을 땅 삼각형 안에서 보간하지만, 전차대 정점은 땅 삼각형 안쪽에
## 있어 부호 있는 UV를 먼저 보간한 뒤 잡는다. 한 땅 삼각형의 모서리 부호가 축마다 엇갈리거나(맞선 벽) ㄱ자면
## 둘이 달라져, 전차대 위에서만 발치 눈 띠가 끊기거나 번진다(점검 M2). 전차대 조각은 땅 칸과 대각선으로 잘려
## 한 땅 삼각형 안에 있으므로 정점에서 같으면 면 안에서도 같다(둘 다 그 삼각형 위 일차식).
## 전차대가 있는 모든 곳을 본다 — 11-06 story_01 하나, 윗면 정점 1,407개 중 발치 값이 있는 것 332개, 어긋남 0.
## 어긋나는 지도가 생기면 전차대가 모서리별 foot을 따로 넘기는 길로 고친다(땅·눈 설계 「점검 반영」 칸).
func test_foot_snow_on_turntable_tops_matches_ground_triangles() -> void:
	var places: int = 0
	for place_id: String in StoryLook.LOOKS:
		var spec: Dictionary = StoryLook.for_place(place_id).get("turntable", {})
		if spec.is_empty():
			continue
		places += 1
		var data := FieldMaps.build(place_id)
		# 모르는 곳이면 build가 기본 지도를 주므로, 전차대를 엉뚱한 땅 위에 재지 않게 곳부터 맞춘다.
		assert_eq(String(data.get("place_id", "")), place_id, "전차대 곳의 지도를 지었다")
		var grid: FieldGrid = data["grid"]
		var arrays := TurntableView.arrays(spec, grid, MapView.ground_bank_row)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var ground := MapView.ground_arrays(grid, MapView.ground_details(grid))
		var tops: int = 0
		var footed: int = 0
		var worst: float = 0.0
		var worst_at := Vector3.ZERO
		for i in range(0, vertices.size(), 3):
			if normals[i].y < 0.6:
				continue
			var centre := Vector2(vertices[i].x + vertices[i + 1].x + vertices[i + 2].x, vertices[i].z + vertices[i + 1].z + vertices[i + 2].z) / 3.0
			for j in range(i, i + 3):
				tops += 1
				var sample := _ground_sample(Vector2(vertices[j].x, vertices[j].z), ground, grid, centre)
				var weights: Vector3 = sample[0]
				var corner_uv: Array = sample[1]
				var ground_foot: float = 0.0
				for corner in 3:
					ground_foot += weights[corner] * _foot(corner_uv[corner], float(sample[2]))
				var top_foot := _foot(uv[j], colors[j].a)
				if ground_foot > 0.001 or top_foot > 0.001:
					footed += 1
				if absf(top_foot - ground_foot) > worst:
					worst = absf(top_foot - ground_foot)
					worst_at = vertices[j]
		gut.p("%s: 윗면 정점 %d, 발치 값 있는 것 %d, 가장 큰 차이 %.4f" % [place_id, tops, footed, worst])
		assert_gt(footed, 0, "%s: 발치 값이 있는 윗면 정점이 있어야 이 검사가 뜻을 가진다" % place_id)
		assert_lte(worst, 0.05, "%s: 전차대 윗면 발치 눈 = 땅(가장 큰 차이 %.3f, 자리 %s)" % [place_id, worst, worst_at])
	assert_gt(places, 0, "전차대가 있는 곳이 하나는 있다")


func test_door_fan_rails_and_both_bed_edges_reach_wall() -> void:
	var arrays := _arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for fan: Dictionary in TurntableView.fans(_spec()):
		if fan["stop"]:
			continue
		var start: Vector2 = fan["start"]
		var direction: Vector2 = fan["direction"]
		var across := Vector2(direction.y, -direction.x)
		for side: float in [-1.0, 1.0]:
			var rail_z: float = -INF
			var bed_z: float = -INF
			for i in vertices.size():
				if normals[i].y < 0.99:
					continue
				var offset := Vector2(vertices[i].x, vertices[i].z) - start
				if offset.dot(direction) < -TurntableView.fan_overlap(_spec()) - 0.0001:
					continue
				var lateral := offset.dot(across)
				if colors[i] == TurntableView.STEEL and absf(lateral - side * TurntableView.GAUGE_HALF) <= TurntableView.RAIL_WIDTH * 0.5 + 0.0001:
					rail_z = maxf(rail_z, vertices[i].z)
				if colors[i] == TurntableView.BED and absf(lateral - side * TurntableView.BED_WIDTH * 0.5) < 0.0001:
					bed_z = maxf(bed_z, vertices[i].z)
			assert_almost_eq(rail_z, 71.0, 0.0001)
			assert_almost_eq(bed_z, 71.0, 0.0001)


func _disc_polygon() -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var center: Vector2 = _spec()["center"]
	for i in TurntableView.SEGMENTS:
		var angle := TAU * (i + 0.5) / TurntableView.SEGMENTS
		polygon.append(center + Vector2(sin(angle), cos(angle)) * float(_spec()["outer_radius"]))
	return polygon


func test_fan_inner_edges_overlap_polygon_and_sleepers_do_not_overlap_rim() -> void:
	var arrays := _arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var disc := _disc_polygon()
	for fan: Dictionary in TurntableView.fans(_spec()):
		var start: Vector2 = fan["start"]
		var direction: Vector2 = fan["direction"]
		var found: Dictionary = {}
		for i in vertices.size():
			if normals[i].y < 0.99 or (colors[i] != TurntableView.BED and colors[i] != TurntableView.STEEL):
				continue
			var point := Vector2(vertices[i].x, vertices[i].z)
			var offset := point - start
			if absf(offset.dot(direction) + TurntableView.fan_overlap(_spec())) > 0.0001:
				continue
			if absf(offset.dot(Vector2(direction.y, -direction.x))) > TurntableView.BED_WIDTH * 0.5 + 0.0001:
				continue
			assert_true(Geometry2D.is_point_in_polygon(point, disc), "안쪽 끝은 실제 32각형 안에 있다")
			found[point.snapped(Vector2(0.0001, 0.0001))] = true
		assert_gte(found.size(), 6, "노반 두 모서리와 두 레일의 네 모서리")
	var rims: Array[PackedVector2Array] = []
	var sleepers: Array[PackedVector2Array] = []
	for i in range(0, vertices.size(), 3):
		if normals[i].y < 0.99 or not is_equal_approx(vertices[i].y, 0.10):
			continue
		var triangle := PackedVector2Array([Vector2(vertices[i].x, vertices[i].z), Vector2(vertices[i + 1].x, vertices[i + 1].z), Vector2(vertices[i + 2].x, vertices[i + 2].z)])
		if colors[i] == TurntableView.RIM:
			rims.append(triangle)
		elif colors[i] == TurntableView.SLEEPER:
			sleepers.append(triangle)
	assert_gt(rims.size(), 0)
	assert_gt(sleepers.size(), 0)
	var overlap_area: float = 0.0
	for rim: PackedVector2Array in rims:
		for sleeper: PackedVector2Array in sleepers:
			for polygon: PackedVector2Array in Geometry2D.intersect_polygons(rim, sleeper):
				var twice_area: float = 0.0
				for i in polygon.size():
					twice_area += polygon[i].cross(polygon[(i + 1) % polygon.size()])
				overlap_area += absf(twice_area) * 0.5
	assert_almost_eq(overlap_area, 0.0, 0.000001, "같은 높이의 침목·테두리 겹침 넓이")
