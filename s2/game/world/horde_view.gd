class_name HordeView
extends Node3D
## 경계 밖 그림 무리. 게임 판정과 combat 자원은 바꾸지 않는다.

const BuildPace = preload("res://game/world/build_pace.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const BODIES: Array[String] = ["n3-body_tracksuit", "n10-body_denim-m", "n10-body_poncho-f"]
const MOTIONS: Array[String] = ["walk_a", "stagger", "thump", "claw"]
const CELL := Vector2i(42, 80)
const ATLAS_SIZE := Vector2i(2048, 1024)
const COLUMNS: int = 48
const DIRECTIONS: int = 8
const FRAMES: int = 6
const CELL_COUNT: int = 576
const FOOT := Vector2(21.0, 64.0) # x는 기본값 — 실제 발 x는 (방향, 동작)마다 칸 표 foot_px_x.
## 회색 기준 칸: 48열 x 42 px = 2016 뒤 오른쪽 띠.
const GRAY_RECT := Rect2i(2016, 0, 32, 80)
const PX_PER_M: float = 30.0
const CAM_SIZE: float = 24.0
const REFERENCE_HEIGHT: int = 720
const THETA_ZERO: float = 0.0
const CAM_PITCH: float = 35.0
const CAM_YAW: float = 45.0
const CHUNK_M: float = 24.0
const CHUNK_CAP: int = 216 # 여섯 덩어리 = 1296, 화면 상한 1300 이내.
const MAP_CAP: int = 3000
const VISIBLE_CAP: int = 6
const PIECE_CAP: int = 256
const WORK_USEC: int = 6000
const HEAD_MAX_M: float = 1.95
const MAX_SCALE: float = 1.08
const ORBIT_M: float = 0.3
const MIN_GAP: float = 0.65
const MAX_TRIES: int = 12
const HISTORY_SIZE: int = 32
const HISTORY_STEP: float = 1.0 / 30.0
const ATLAS_PATH: String = "res://models/horde/horde_atlas.png"
const TABLE_PATH: String = "res://models/horde/horde_atlas.json"
const KINDS: Array[String] = ["wall_sheet", "wall_sound", "wall_plank", "wall_stack", "overpass"]

var stats: Dictionary = {}
var chunks: Array[Dictionary] = []
var _sight: Dictionary = {}
var _materials: Array[ShaderMaterial] = []
var _draws: Array[MultiMeshInstance3D] = []
var _focus := Vector4.ZERO
var _history := PackedVector4Array()
var _focus_clock: float = 0.0
var _history_tick: int = -1
var _work_start: int = 0
var _continuous_usec: int = 0
var _pieces: int = 0
var _piece_pace: BuildPace


static func camera_back() -> Vector3:
	var pitch: float = deg_to_rad(CAM_PITCH)
	var yaw: float = deg_to_rad(CAM_YAW)
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))


static func camera_theta() -> float:
	var back: Vector3 = camera_back()
	return atan2(back.x, back.z) # 몸의 앞은 +Z, 각도는 +Y 회전.


static func direction_cell(theta: float) -> int:
	return posmod(int(floor((theta - camera_theta() - THETA_ZERO + PI / 8.0) / (PI / 4.0))), DIRECTIONS)


static func atlas_index(body: int, direction: int, motion: int, frame: int) -> int:
	return (((body * DIRECTIONS + direction) * MOTIONS.size() + motion) * FRAMES + frame)


static func clip_indices(clips: Array) -> Array[int]:
	var found: Array[int] = []
	for wanted: String in MOTIONS:
		var match_index: int = -1
		for index: int in range(clips.size()):
			var clip: Dictionary = clips[index]
			if String(clip.get("name", "")) == wanted:
				if match_index >= 0 or not is_finite(float(clip.get("length", 0.0))) or float(clip.get("length", 0.0)) <= 0.0:
					return []
				match_index = index
		if match_index < 0:
			return []
		found.append(match_index)
	return found


static func table_contract() -> Dictionary:
	return {"version": 1, "bodies": BODIES, "motions": MOTIONS, "directions": DIRECTIONS,
		"frames": FRAMES, "cell_count": CELL_COUNT, "columns": COLUMNS, "rows": 12,
		"cell_px": [CELL.x, CELL.y], "atlas_px": [ATLAS_SIZE.x, ATLAS_SIZE.y],
		"foot_px": [FOOT.x, FOOT.y], "px_per_m": PX_PER_M, "theta_zero": THETA_ZERO,
		"camera_pitch": CAM_PITCH, "camera_yaw": CAM_YAW, "camera_size": CAM_SIZE,
		"reference_height": REFERENCE_HEIGHT, "padding_px": 2,
		"gray_rect": [GRAY_RECT.position.x, GRAY_RECT.position.y, GRAY_RECT.size.x, GRAY_RECT.size.y],
		"foot_px_x_order": "direction * 4 + motion",
		"index_formula": "(((body * 8 + direction) * 4 + motion) * 6 + frame)",
		"direction_formula": "posmod(floor((theta - theta_cam - theta_zero + PI/8)/(PI/4)), 8)"}


static func wall_error(wall: Dictionary, map_size: Vector2, grid: FieldGrid = null) -> String:
	if not wall.get("id") is String or String(wall["id"]).is_empty():
		return "id 누락"
	for key: String in ["a", "b", "out"]:
		if not wall.get(key) is Vector2 or not (wall[key] as Vector2).is_finite():
			return key + " 좌표 오류"
	for key: String in ["height", "floor_y", "depth"]:
		var value: Variant = wall.get(key, 40.0 if key == "depth" else 0.0)
		if not (value is float or value is int) or not is_finite(float(value)):
			return key + " 유한 수 아님"
	# depth 0 is the map's "no horde behind this piece" (a recess and the like): a valid wall, no one placed.
	if float(wall.get("height", 0.0)) <= 0.0 or float(wall.get("depth", 40.0)) < 0.0:
		return "높이 또는 깊이 오류"
	if not KINDS.has(String(wall.get("kind", ""))):
		return "벽 종류 오류"
	var a: Vector2 = wall["a"]
	var b: Vector2 = wall["b"]
	var outward: Vector2 = wall["out"]
	if a.distance_to(b) <= 0.001:
		return "길이 0"
	if not a.is_equal_approx(a.round()) or not b.is_equal_approx(b.round()):
		return "격자 모서리 아님"
	if absf(outward.length() - 1.0) > 0.001 or absf(outward.dot((b - a).normalized())) > 0.001:
		return "바깥 법선은 단위이며 수직이어야 함"
	if map_size.x <= 0.0 or map_size.y <= 0.0:
		return "지도 크기 누락"
	var bounds := Rect2(Vector2.ZERO, map_size)
	# 격자 가장자리, 또는 안쪽으로 들인 경계의 통행 가능/불가 양쪽을 검사한다.
	var tangent: Vector2 = (b - a).normalized()
	for point: Vector2 in [a + tangent * 0.25, (a + b) * 0.5, b - tangent * 0.25]:
		var outer: Vector2 = point + outward
		var inner: Vector2 = point - outward
		if not bounds.has_point(outer) and bounds.has_point(inner):
			continue
		if grid != null:
			var outside_cell := Vector2i(floori(outer.x), floori(outer.y))
			var inside_cell := Vector2i(floori(inner.x), floori(inner.y))
			if not grid.people_can_walk(outside_cell) and grid.people_can_walk(inside_cell):
				continue
		return "바깥 방향 아님 또는 안팎을 확인할 격자 없음"
	return ""


static func head_height(table: Dictionary) -> float:
	var highest: float = 0.0
	for rect: Array in table.get("bounds_px", []):
		highest = maxf(highest, (FOOT.y - float(rect[1])) / PX_PER_M / cos(deg_to_rad(CAM_PITCH)))
	return highest if highest > 0.0 else HEAD_MAX_M


static func full_depth(wall: Dictionary, head_max: float = HEAD_MAX_M) -> float:
	if wall.get("kind") == "overpass":
		return 0.0 # 틈은 실제 깊이 검사에 맡긴다.
	var back: Vector3 = camera_back()
	var away := -Vector2(back.x, back.z).normalized()
	return maxf(0.0, (float(wall["height"]) - head_max * MAX_SCALE) / tan(deg_to_rad(CAM_PITCH)) * maxf(0.0, (wall["out"] as Vector2).dot(away)) - ORBIT_M)


static func fully_hidden(wall: Dictionary, point: Vector2, head_max: float = HEAD_MAX_M) -> bool:
	var a: Vector2 = wall["a"]
	var b: Vector2 = wall["b"]
	var outward: Vector2 = wall["out"]
	var depth: float = (point - a).dot(outward)
	if depth < 0.0 or depth >= full_depth(wall, head_max):
		return false
	var back: Vector3 = camera_back()
	var toward := Vector2(back.x, back.z).normalized()
	var denom: float = toward.dot(outward)
	if denom >= -0.0001:
		return false
	var hit: Vector2 = point + toward * (-depth / denom)
	var along: float = (hit - a).dot((b - a).normalized())
	return along >= 0.0 and along <= a.distance_to(b)


static func stream(id: String, cell: Vector2i, lane: int) -> float:
	# 정수 31비트 안에서 계산. 배열 순서나 전역 RNG 상태를 읽지 않는다.
	var value: int = int(id.hash()) & 0x7fffffff
	for part: int in [cell.x, cell.y, lane]:
		value = ((value ^ (part & 0x7fffffff)) * 1103515245 + 12345) & 0x7fffffff
		value = value ^ (value >> 13)
	return float(value & 0x00ffffff) / 16777216.0


static func _clearance(point: Vector2, bins: Dictionary) -> bool:
	var cell := Vector2i(floori(point.x / MIN_GAP), floori(point.y / MIN_GAP))
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			for other: Vector2 in bins.get(cell + Vector2i(dx, dy), []):
				if point.distance_squared_to(other) < MIN_GAP * MIN_GAP:
					return false
	return true


static func upright_corner(foot: Vector3, corner: Vector2) -> Vector3:
	var right_h: Vector3 = Vector3.UP.cross(camera_back()).normalized()
	if corner.y < 0.0:
		# 발 아래로 내려간 그림(카메라 쪽으로 딛는 발)은 땅 밑이 아니라 땅 위 카메라 쪽으로: 화면 자리는 같다.
		var back_h := Vector3(camera_back().x, 0.0, camera_back().z).normalized()
		return foot + right_h * corner.x + back_h * (-corner.y) / sin(deg_to_rad(CAM_PITCH))
	return foot + right_h * corner.x + Vector3.UP * corner.y / cos(deg_to_rad(CAM_PITCH))


static func density(depth: float) -> float:
	return lerpf(0.5, 0.12, smoothstep(18.0, 26.0, depth))


static func density_area(depth: float) -> float:
	# density의 적분. 후보 수와 역누적분포 표본이 같은 함수를 쓴다.
	var d: float = clampf(depth, 0.4, 40.0)
	var t: float = clampf((d - 18.0) / 8.0, 0.0, 1.0)
	return 0.5 * (d - 0.4) - 0.38 * (8.0 * (t * t * t - 0.5 * t * t * t * t) + maxf(0.0, d - 26.0))


static func sample_depth(unit: float, depth_m: float) -> float:
	var lo: float = 0.4
	var hi: float = depth_m
	var target: float = unit * density_area(depth_m)
	for _step: int in range(16):
		var mid: float = (lo + hi) * 0.5
		if density_area(mid) < target:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


static func density_wave(point: Vector2) -> float:
	return 0.65 + 0.35 * sin(point.x * 0.17 + point.y * 0.11)


static func card_aabb(people: Array[Dictionary]) -> AABB:
	if people.is_empty():
		return AABB()
	var first: Vector3 = people[0]["position"]
	var box := AABB(first, Vector3.ZERO)
	# 전체 칸으로 보수적으로 감싼다. 실제 카드는 합 테두리만 쓴다.
	for person: Dictionary in people:
		var foot: Vector3 = person["position"]
		# 발 x는 (방향, 동작)마다 2..CELL.x-2 안이라 칸 가로 전체를 양쪽으로 감싼다.
		for dx: float in [-float(CELL.x), float(CELL.x)]:
			for py: float in [0.0, float(CELL.y)]:
				var corner: Vector3 = upright_corner(foot, Vector2(dx, FOOT.y - py) * (MAX_SCALE / PX_PER_M))
				box = box.expand(corner)
	# 고리 반지름 0.3 + 벽 쪽 쏠림 0.3. 수직 여유도 보수적으로 둔다.
	return box.grow(0.6)


func _begin_stats(pace: BuildPace) -> void:
	stats = {"instances": 0, "chunks": 0, "invalid_walls": 0, "attempts": 0,
		"cpu_ms": 0.0, "max_continuous_ms": 0.0, "resource_ms": 0.0, "pieces": 0, "ready": false}
	_work_start = Time.get_ticks_usec()
	_continuous_usec = 0
	_pieces = 0
	_piece_pace = pace if pace != null else BuildPace.new()


func _account() -> void:
	var used: int = Time.get_ticks_usec() - _work_start
	stats["cpu_ms"] = float(stats["cpu_ms"]) + float(used) / 1000.0
	_continuous_usec += used
	stats["max_continuous_ms"] = maxf(float(stats["max_continuous_ms"]), float(_continuous_usec) / 1000.0)
	_work_start = Time.get_ticks_usec()


func _rest() -> void:
	_account()
	var before: int = Engine.get_process_frames()
	# 부모가 이 setup을 await하는 동안만 조각마다 쉰다. 같은 pace 시계를 갱신해야
	# 부모의 longest_usec에 이 프레임 대기 시간이 CPU 작업처럼 더해지지 않는다.
	var budget_before: int = _piece_pace.budget_usec
	_piece_pace.budget_usec = 0
	await BuildPace.rest(_piece_pace)
	_piece_pace.budget_usec = budget_before
	if Engine.get_process_frames() != before:
		_continuous_usec = 0
	_work_start = Time.get_ticks_usec()
	_pieces = 0
	stats["pieces"] = int(stats["pieces"]) + 1


func _rest_due() -> bool:
	return _pieces >= PIECE_CAP or Time.get_ticks_usec() - _work_start >= WORK_USEC


func build_layout(walls: Array, vis: Dictionary, pace: BuildPace = null, table: Dictionary = {}) -> Array[Dictionary]:
	_begin_stats(pace)
	var head_max: float = head_height(table)
	var map_size: Vector2 = vis.get("map_size", Vector2.ZERO)
	var valid: Array[Dictionary] = []
	var ids: Dictionary = {}
	for entry: Variant in walls:
		_pieces += 1
		if _rest_due():
			await _rest()
		if entry is Dictionary:
			var id: String = String(entry.get("id", ""))
			ids[id] = int(ids.get(id, 0)) + 1
	for entry: Variant in walls:
		_pieces += 1
		if _rest_due():
			await _rest()
		var wall: Dictionary = entry if entry is Dictionary else {}
		var why: String = wall_error(wall, map_size, vis.get("grid"))
		if why.is_empty() and int(ids.get(String(wall["id"]), 0)) != 1:
			why = "중복 id"
		if not why.is_empty():
			stats["invalid_walls"] = int(stats["invalid_walls"]) + 1
			push_warning("HordeView 벽 무시: %s (%s)" % [String(wall.get("id", "?")).replace("\n", " ").replace("\r", " "), why])
		else:
			valid.append(wall)
	valid.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["id"]) < String(right["id"]))
	var endpoints: Dictionary = {}
	for wall: Dictionary in valid:
		for key: String in ["a", "b"]:
			var endpoint := Vector2i(wall[key])
			endpoints[endpoint] = int(endpoints.get(endpoint, 0)) + 1
		_pieces += 1
		if _rest_due():
			await _rest()
	# 모든 유효 벽의 후보를 먼저 센다. 같은 배율과 내림으로 지도 상한을 지킨다.
	var plans: Array[Dictionary] = []
	var candidate_sum: float = 0.0
	for wall: Dictionary in valid:
		var a: Vector2 = wall["a"]
		var b: Vector2 = wall["b"]
		var length_m: float = a.distance_to(b)
		var depth_m: float = minf(40.0, float(wall.get("depth", 40.0)))
		if depth_m <= 0.4:
			continue
		var start_gap: float = 2.0 if int(endpoints[Vector2i(a)]) == 1 else 0.0
		var end_gap: float = 2.0 if int(endpoints[Vector2i(b)]) == 1 else 0.0
		for chunk_i: int in range(int(ceil(length_m / CHUNK_M))):
			var lo: float = maxf(start_gap, float(chunk_i) * CHUNK_M)
			var hi: float = minf(length_m - end_gap, float(chunk_i + 1) * CHUNK_M)
			if hi > lo:
				var candidates: float = (hi - lo) * density_area(depth_m)
				plans.append({"wall": wall, "chunk_i": chunk_i, "lo": lo, "hi": hi, "depth": depth_m, "candidates": candidates})
				candidate_sum += candidates
			_pieces += 1
			if _rest_due():
				await _rest()
	var density_scale: float = minf(1.0, float(MAP_CAP) / maxf(candidate_sum, 1.0))
	stats["density_scale"] = density_scale
	stats["candidate_sum"] = candidate_sum
	var result: Array[Dictionary] = []
	var bins: Dictionary = {}
	for plan: Dictionary in plans:
		var wall: Dictionary = plan["wall"]
		var a: Vector2 = wall["a"]
		var b: Vector2 = wall["b"]
		var tangent: Vector2 = (b - a).normalized()
		var outward: Vector2 = wall["out"]
		var depth_m: float = plan["depth"]
		var wall_id: String = wall["id"]
		var contact_start: float = maxf(0.4, full_depth(wall, head_max))
		var chunk_i: int = plan["chunk_i"]
		var lo: float = plan["lo"]
		var hi: float = plan["hi"]
		var target: int = mini(CHUNK_CAP, int(floor(float(plan["candidates"]) * density_scale)))
		var people: Array[Dictionary] = []
		var group_size: int = 0
		var group_attempts: int = 0
		var group_at := Vector2.ZERO
		var group_key := Vector2i.ZERO
		for attempt: int in range(target * MAX_TRIES):
			if people.size() >= target:
				break
			if group_size <= 0 or group_attempts >= 8 * MAX_TRIES:
				group_key = Vector2i(int(round(a.x + tangent.x * lo)), int(round(a.y + tangent.y * lo))) + Vector2i(attempt, chunk_i)
				group_size = 3 + int(stream(wall_id, group_key, 11) * 6.0)
				group_attempts = 0
				group_at = Vector2(lerpf(lo, hi, stream(wall_id, group_key, 13)), sample_depth(stream(wall_id, group_key, 14), depth_m))
			group_attempts += 1
			var lane: int = 100 + attempt * 7
			var ring: float = TAU * stream(wall_id, group_key, lane)
			var radius: float = 1.8 * sqrt(stream(wall_id, group_key, lane + 1))
			var along: float = group_at.x + cos(ring) * radius
			var depth: float = group_at.y + sin(ring) * radius
			var point: Vector2 = a + tangent * along + outward * depth
			var wave: float = density_wave(point)
			stats["attempts"] = int(stats["attempts"]) + 1
			_pieces += 1
			if _rest_due():
				await _rest()
			if along < lo or along > hi or depth < 0.4 or depth > depth_m:
				continue
			if stream(wall_id, group_key, lane + 2) > wave or fully_hidden(wall, point, head_max) or not _clearance(point, bins):
				continue
			var cell := Vector2i(floori(point.x * 4.0), floori(point.y * 4.0))
			var motion: int = 1
			if depth >= contact_start and depth <= contact_start + 0.8:
				motion = 2 + int(stream(wall_id, cell, 21) * 2.0)
			elif depth > contact_start + 1.1 and along > lo + 0.3 and along < hi - 0.3 and not fully_hidden(wall, point - outward * 0.3, head_max):
				motion = 0 if stream(wall_id, cell, 22) < 0.3 else 1
			var theta: float = atan2(-outward.x, -outward.y)
			if stream(wall_id, cell, 23) < 0.1:
				theta = TAU * stream(wall_id, cell, 24)
			else:
				theta += deg_to_rad(80.0) * (stream(wall_id, cell, 24) - 0.5)
			var position3 := Vector3(point.x, float(wall.get("floor_y", 0.0)), point.y)
			people.append({"position": position3, "depth": depth, "motion": motion,
				"custom": Color(stream(wall_id, cell, 25), float(motion), fposmod(theta, TAU) / TAU, stream(wall_id, cell, 26)), "cell": cell})
			group_size -= 1
			var bin := Vector2i(floori(point.x / MIN_GAP), floori(point.y / MIN_GAP))
			if not bins.has(bin):
				bins[bin] = []
			(bins[bin] as Array).append(point)
		# 정렬 한 번은 최대 216개. 카메라 전방 투영 깊이가 작은 순서.
		var forward: Vector3 = -camera_back()
		people.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return (left["position"] as Vector3).dot(forward) < (right["position"] as Vector3).dot(forward))
		if not people.is_empty():
			result.append({"id": "%s:%d" % [wall_id, chunk_i], "wall": wall, "people": people, "aabb": card_aabb(people)})
			stats["instances"] = int(stats["instances"]) + people.size()
		await _rest()
	stats["chunks"] = result.size()
	_account()
	return result


static func attach(parent: Node3D, walls: Array, vis: Dictionary, pace: BuildPace, settings: Dictionary) -> Node3D:
	if settings.get("horde", true) == false:
		print("PERF_SWITCH ", {"horde": false})
		return null
	if walls.is_empty():
		return null
	var node: HordeView = HordeView.new()
	node.name = "HordeView"
	parent.add_child(node)
	await node.setup(walls, vis, pace)
	return node


func setup(walls: Array, vis: Dictionary, pace: BuildPace) -> void:
	_sight = vis
	_history.resize(HISTORY_SIZE)
	_history.fill(Vector4.ZERO)
	var table_start: int = Time.get_ticks_usec()
	var table: Dictionary = read_table()
	var table_ms: float = float(Time.get_ticks_usec() - table_start) / 1000.0
	chunks = await build_layout(walls, vis, pace, table)
	stats["resource_ms"] = table_ms
	visibility_changed.connect(_visibility_reset)
	if chunks.is_empty():
		set_process(false)
		return
	var resource_start: int = Time.get_ticks_usec()
	if table.is_empty() or not ResourceLoader.exists(ATLAS_PATH):
		stats["resource_ms"] = table_ms + float(Time.get_ticks_usec() - resource_start) / 1000.0
		_account()
		push_warning("HordeView: 아틀라스 또는 칸 표 없음/불일치. horde_bake를 먼저 실행해야 합니다.")
		set_process(false)
		return
	var atlas: Texture2D = load(ATLAS_PATH)
	var shader: Shader = load("res://fx/shaders/horde_far.gdshader")
	stats["resource_ms"] = table_ms + float(Time.get_ticks_usec() - resource_start) / 1000.0
	if atlas == null or shader == null or atlas.get_size() != Vector2(ATLAS_SIZE):
		_account()
		push_warning("HordeView: 아틀라스 크기 또는 셰이더 자원 오류")
		set_process(false)
		return
	_account()
	await _rest()
	var rects := PackedVector4Array()
	for rect: Array in table["bounds_px"]:
		rects.append(Vector4(rect[0], rect[1], rect[2], rect[3]))
	var lengths := PackedFloat32Array(table["clip_lengths"])
	for chunk: Dictionary in chunks:
		var wall: Dictionary = chunk["wall"]
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("atlas", atlas)
		mat.set_shader_parameter("bounds_px", rects)
		mat.set_shader_parameter("foot_px_x", PackedFloat32Array(table["foot_px_x"]))
		mat.set_shader_parameter("clip_lengths", lengths)
		mat.set_shader_parameter("camera_pitch", deg_to_rad(CAM_PITCH))
		mat.set_shader_parameter("wall_a", wall["a"])
		mat.set_shader_parameter("wall_b", wall["b"])
		mat.set_shader_parameter("wall_out", wall["out"])
		mat.set_shader_parameter("focus_history", _history)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		mm.mesh = quad
		var people: Array[Dictionary] = chunk["people"]
		mm.instance_count = people.size()
		mm.custom_aabb = chunk["aabb"]
		for index: int in range(people.size()):
			_pieces += 1
			if _rest_due():
				await _rest()
			mm.set_instance_transform(index, Transform3D(Basis.IDENTITY, people[index]["position"]))
			mm.set_instance_custom_data(index, people[index]["custom"])
		var draw := MultiMeshInstance3D.new()
		draw.name = "HordeChunk_%d" % _draws.size()
		draw.multimesh = mm
		draw.material_override = mat
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.visible = false
		add_child(draw)
		_draws.append(draw)
		_materials.append(mat)
		await _rest()
	_sync_sight()
	stats["ready"] = true
	_account()
	print("HORDE_BUILD ", stats)


static func read_table() -> Dictionary:
	if not FileAccess.file_exists(TABLE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
	if not parsed is Dictionary:
		return {}
	var table: Dictionary = parsed
	var contract: Dictionary = table_contract()
	for key: String in contract:
		if table.get(key) != contract[key]:
			return {}
	if not table.get("bounds_px") is Array or (table["bounds_px"] as Array).size() != 32:
		return {}
	if not table.get("foot_px_x") is Array or (table["foot_px_x"] as Array).size() != 32:
		return {}
	for foot_x: Variant in table["foot_px_x"]:
		if not (foot_x is float or foot_x is int) or float(foot_x) < 2.0 or float(foot_x) > float(CELL.x - 2):
			return {}
	if not table.get("clip_lengths") is Array or (table["clip_lengths"] as Array).size() != 12:
		return {}
	for duration: Variant in table["clip_lengths"]:
		if not (duration is float or duration is int) or not is_finite(float(duration)) or float(duration) <= 0.0:
			return {}
	for entry: Variant in table["bounds_px"]:
		if not entry is Array or (entry as Array).size() != 4:
			return {}
		for value: Variant in entry:
			if not (value is float or value is int) or not is_finite(float(value)):
				return {}
		var rect := Rect2(float(entry[0]), float(entry[1]), float(entry[2]), float(entry[3]))
		if not rect.has_area() or not Rect2(2, 2, CELL.x - 4, CELL.y - 4).encloses(rect):
			return {}
	return table


func _sync_sight() -> void:
	var source: ShaderMaterial = _sight.get("material")
	for mat: ShaderMaterial in _materials:
		mat.set_shader_parameter("vis_texture", _sight.get("vis_texture"))
		mat.set_shader_parameter("map_size", _sight.get("map_size", Vector2.ONE))
		for key: String in ["mask_on", "eye_xz", "eye_r", "round_day", "round_floor"]:
			if source != null:
				var value: Variant = source.get_shader_parameter(key)
				if value != null:
					mat.set_shader_parameter(key, value)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var player: Node3D = _sight.get("player")
	var field: Node = _sight.get("field")
	var held: bool = field != null and bool(field.get("paused")) and not bool(field.get("ended"))
	if not held:
		_focus_clock += delta
		var target := Vector4.ZERO
		if is_instance_valid(player):
			target = Vector4(player.global_position.x, player.global_position.z, 1.0, 0.0)
			if _focus.z == 0.0:
				_focus = Vector4(target.x, target.y, 0.0, 0.0)
		_focus = _focus.lerp(target, 1.0 - exp(-delta / 0.5))
		var tick: int = int(floor(_focus_clock / HISTORY_STEP))
		for step: int in range(maxi(_history_tick + 1, tick - HISTORY_SIZE + 1), tick + 1):
			_history[posmod(step, HISTORY_SIZE)] = _focus
		_history_tick = tick
	for mat: ShaderMaterial in _materials:
		mat.set_shader_parameter("focus", _focus)
		mat.set_shader_parameter("focus_clock", _focus_clock)
		mat.set_shader_parameter("focus_history", _history)
	_sync_sight()
	# 개체가 아닌 소수 덩어리만 추려 여섯 개 상한을 지킨다.
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var candidates: Array[int] = []
	var planes: Array[Plane] = camera.get_frustum()
	for index: int in range(_draws.size()):
		_draws[index].visible = false
		var box: AABB = chunks[index]["aabb"]
		var outside: bool = false
		for plane: Plane in planes:
			var all_out: bool = true
			for corner: int in range(8):
				if not plane.is_point_over(box.get_endpoint(corner)):
					all_out = false
					break
			if all_out:
				outside = true
				break
		if not outside:
			candidates.append(index)
	candidates.sort_custom(func(left: int, right: int) -> bool: return camera.global_position.distance_squared_to((chunks[left]["aabb"] as AABB).get_center()) < camera.global_position.distance_squared_to((chunks[right]["aabb"] as AABB).get_center()))
	for slot: int in range(mini(VISIBLE_CAP, candidates.size())):
		_draws[candidates[slot]].visible = true


func _visibility_reset() -> void:
	if not is_visible_in_tree():
		_clear_focus()


func _clear_focus() -> void:
	_focus = Vector4.ZERO
	_history.fill(Vector4.ZERO)
	for mat: ShaderMaterial in _materials:
		mat.set_shader_parameter("focus", Vector4.ZERO)
		mat.set_shader_parameter("focus_history", _history)


func _exit_tree() -> void:
	_clear_focus()
