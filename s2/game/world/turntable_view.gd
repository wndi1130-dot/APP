extends RefCounted
## 보행 판정 없이 그리는 얕은 작업 바닥. 재질과 시야는 지도와 공유한다.

const SEGMENTS: int = 32
const RAIL_WIDTH: float = 0.20
const GAUGE_HALF: float = 0.72
const BED_WIDTH: float = 2.5
const STOP_LENGTH: float = 0.4
const RIM := Color(0.76, 0.75, 0.72)
const FLOOR := Color(0.36, 0.36, 0.36)
const BRIDGE := Color(0.80, 0.78, 0.72)
const BED := Color(0.28, 0.26, 0.24)
const SLEEPER := Color(0.24, 0.21, 0.19)
const STEEL := Color(0.66, 0.66, 0.66)


static func build(parent: Node3D, material: Material, spec: Dictionary) -> MeshInstance3D:
	if spec.is_empty():
		return null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays(spec))
	var node := MeshInstance3D.new()
	node.name = "Turntable"
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


static func arrays(spec: Dictionary) -> Array:
	if spec.is_empty():
		return []
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center: Vector2 = spec["center"]
	var inner: float = spec["inner_radius"]
	var outer: float = spec["outer_radius"]
	var wall: float = spec["wall_z"]
	var cuts: Array[Vector2] = []
	for i in SEGMENTS:
		# 반 분할 돌려야 (±5.5, ±6.5)의 옛 칠 모서리도 32각형 안에 든다.
		var a := Vector2(sin(TAU * (i + 0.5) / SEGMENTS), cos(TAU * (i + 0.5) / SEGMENTS))
		var b := Vector2(sin(TAU * (i + 1.5) / SEGMENTS), cos(TAU * (i + 1.5) / SEGMENTS))
		var ia := center + a * inner
		var ib := center + b * inner
		var oa := center + a * outer
		var ob := center + b * outer
		if (oa.y <= wall) != (ob.y <= wall):
			cuts.append(oa.lerp(ob, (wall - oa.y) / (ob.y - oa.y)))
		_face(st, [_at(center, 0.03), _at(ib, 0.03), _at(ia, 0.03)], FLOOR, 8.0, wall)
		_face(st, [_at(ia, 0.10), _at(ib, 0.10), _at(ob, 0.10), _at(oa, 0.10)], RIM, 3.0, wall)
		_face(st, [_at(oa, 0.0), _at(oa, 0.10), _at(ob, 0.10), _at(ob, 0.0)], RIM, 3.0, wall)
		_face(st, [_at(ib, 0.03), _at(ib, 0.10), _at(ia, 0.10), _at(ia, 0.03)], RIM, 3.0, wall)
	if cuts.size() == 2:
		cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		_face(st, [_at(cuts[0], 0.0), _at(cuts[0], 0.10), _at(cuts[1], 0.10), _at(cuts[1], 0.0)], RIM, 3.0, wall)
	var axis: Vector2 = spec["bridge_axis"]
	_strip(st, center - axis * inner, axis, inner * 2.0, float(spec["bridge_width"]), 0.03, 0.16, BRIDGE, wall)
	_rails(st, center - axis * inner, axis, inner * 2.0, 0.16, 0.20, wall)
	for fan: Dictionary in fans(spec):
		var start: Vector2 = fan["start"]
		var direction: Vector2 = fan["direction"]
		var length: float = fan["length"]
		_strip(st, start, direction, length, BED_WIDTH, 0.0, 0.05, BED, wall)
		for i in 4:
			var sleeper_start := start + direction * (length * (float(i) + 0.5) / 4.0 - 0.12)
			_strip(st, sleeper_start, direction, 0.24, BED_WIDTH, 0.05, 0.10, SLEEPER, wall, false)
		_rails(st, start, direction, length, 0.10, 0.18, wall)
		if fan["stop"]:
			_strip(st, start + direction * (length - STOP_LENGTH), direction, STOP_LENGTH, BED_WIDTH, 0.05, 0.20, BRIDGE, wall)
	return st.commit_to_arrays()


## 두 문 방향은 벽 앞까지, 나머지는 3 m에서 끝난다. 폭의 벽 넘침도 _face에서 자른다.
static func fans(spec: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var center: Vector2 = spec["center"]
	for angle: float in spec["fan_angles"]:
		var direction := Vector2(sin(deg_to_rad(angle)), cos(deg_to_rad(angle)))
		var start := center + direction * float(spec["outer_radius"])
		var stop := absf(angle) > 30.0
		var length := 3.0 if stop else (float(spec["wall_z"]) - start.y) / direction.y
		out.append({"start": start, "direction": direction, "length": length, "stop": stop})
	return out


static func _at(point: Vector2, height: float) -> Vector3:
	return Vector3(point.x, height, point.y)


static func _rails(st: SurfaceTool, start: Vector2, direction: Vector2, length: float, bottom: float, top: float, wall: float) -> void:
	var across := Vector2(direction.y, -direction.x)
	for side: float in [-1.0, 1.0]:
		_strip(st, start + across * side * GAUGE_HALF, direction, length, RAIL_WIDTH, bottom, top, STEEL, wall)


## 바닥 없는 상자. 침목은 윗면만 그려 전체 삼각형 수를 600 이하로 유지한다.
static func _strip(st: SurfaceTool, start: Vector2, direction: Vector2, length: float, width: float, bottom: float, top: float, color: Color, wall: float, sides: bool = true) -> void:
	var across := Vector2(direction.y, -direction.x) * width * 0.5
	var corners: Array[Vector2] = [start - across, start + across, start + direction * length + across, start + direction * length - across]
	_face(st, [_at(corners[0], top), _at(corners[1], top), _at(corners[2], top), _at(corners[3], top)], color, 0.0, wall)
	if sides:
		for i in 4:
			var a := corners[i]
			var b := corners[(i + 1) % 4]
			_face(st, [_at(a, bottom), _at(a, top), _at(b, top), _at(b, bottom)], color, 0.0, wall)


## z=벽 선에서 다각형을 잘라 낸다. 꼭짓점만 눌러 놓으면 옛 칠의 모서리가 드러난다.
static func _face(st: SurfaceTool, points: Array, color: Color, kind: float, wall: float) -> void:
	var clipped: Array[Vector3] = []
	var previous: Vector3 = points.back()
	for current: Vector3 in points:
		if (previous.z <= wall) != (current.z <= wall):
			clipped.append(previous.lerp(current, (wall - previous.z) / (current.z - previous.z)))
		if current.z <= wall:
			clipped.append(current)
		previous = current
	for i in range(1, clipped.size() - 1):
		var normal := (clipped[i + 1] - clipped[0]).cross(clipped[i] - clipped[0]).normalized()
		if normal.length_squared() < 0.5:
			continue
		for vertex: Vector3 in [clipped[0], clipped[i], clipped[i + 1]]:
			st.set_normal(normal)
			st.set_color(color)
			st.set_uv(Vector2.ZERO)
			st.set_uv2(Vector2(kind, 0))
			st.add_vertex(vertex)
