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

static var resource_reads: int = 0 # 캐시 적중도 포함한 읽기 시도. 꺼짐 경로의 무읽기 계약 관측.
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
var _staged: bool = false
var _build_cancelled: bool = false
var _sight_cache: Dictionary = {}
var frame_material_writes: int = 0
var frame_sight_reads: int = 0
var visible_chunks: Array[int] = []


func _init() -> void:
	# _process can tick while a staged build is still resting, before setup() runs.
	_history.resize(HISTORY_SIZE)
	_history.fill(Vector4.ZERO)


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


static func card_mesh() -> ArrayMesh:
	# UV v=64/80 줄을 공유하는 위/아래 두 면. 발 원점이 실제 모서리 위에 있다.
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.5, 0.5, 0), Vector3(0.5, 0.5, 0),
		Vector3(-0.5, -0.3, 0), Vector3(0.5, -0.3, 0),
		Vector3(-0.5, -0.5, 0), Vector3(0.5, -0.5, 0)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(0, 0.8),
		Vector2(1, 0.8), Vector2(0, 1), Vector2(1, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 1, 3, 2, 2, 3, 4, 3, 5, 4])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func card_pixel(uv: Vector2, rect: Rect2) -> Vector2:
	# horde_far.vertex와 같은 계약. 발이 테두리 밖이면 해당 면만 퇴화한다.
	var split: float = clampf(FOOT.y, rect.position.y, rect.end.y)
	var py: float = lerpf(rect.position.y, split, uv.y / 0.8) if uv.y <= 0.8 else lerpf(split, rect.end.y, (uv.y - 0.8) / 0.2)
	return Vector2(lerpf(rect.position.x, rect.end.x, uv.x), py)


static func configure_card(mat: ShaderMaterial, table: Dictionary) -> void:
	var rects := PackedVector4Array()
	for rect: Array in table["bounds_px"]:
		rects.append(Vector4(rect[0], rect[1], rect[2], rect[3]))
	mat.set_shader_parameter("bounds_px", rects)
	mat.set_shader_parameter("foot_px_x", PackedFloat32Array(table["foot_px_x"]))
	mat.set_shader_parameter("clip_lengths", PackedFloat32Array(table["clip_lengths"]))
	mat.set_shader_parameter("camera_pitch", deg_to_rad(CAM_PITCH))


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
		box = _expand_card(box, foot)
	# 고리 반지름 0.3 + 벽 쪽 쏠림 0.3. 수직 여유도 보수적으로 둔다.
	return box.grow(0.6)


static func _expand_card(box: AABB, foot: Vector3) -> AABB:
	for dx: float in [-float(CELL.x), float(CELL.x)]:
		for py: float in [0.0, FOOT.y, float(CELL.y)]:
			box = box.expand(upright_corner(foot, Vector2(dx, FOOT.y - py) * (MAX_SCALE / PX_PER_M)))
	return box


func _card_aabb(people: Array[Dictionary]) -> AABB:
	var box := AABB(people[0]["position"], Vector3.ZERO)
	for person: Dictionary in people:
		if not await _checkpoint():
			return AABB()
		box = _expand_card(box, person["position"])
	return box.grow(0.6)


func _begin_stats(pace: BuildPace) -> void:
	stats = {"instances": 0, "chunks": 0, "invalid_walls": 0, "attempts": 0,
		"cpu_ms": 0.0, "max_continuous_ms": 0.0, "resource_ms": 0.0, "pieces": 0, "ready": false,
		"cancelled": false, "resource_loads": 0, "table_error": "", "table_warning": "", "uploaded_instances": 0,
		"stage": "layout", "wait_stages": {}, "resource_max_ms": 0.0}
	_work_start = Time.get_ticks_usec()
	_continuous_usec = 0
	_pieces = 0
	_piece_pace = pace if pace != null else BuildPace.new()
	_staged = _piece_pace.on
	_build_cancelled = false


func _cancelled() -> bool:
	if _staged and not _piece_pace.on and not _build_cancelled:
		_build_cancelled = true
		stats["cancelled"] = true
		stats["ready"] = false
		_account()
		set_process(false)
	return _build_cancelled


func _checkpoint(force: bool = false) -> bool:
	if _cancelled():
		return false
	_pieces += 1
	if force or _rest_due():
		await _rest()
	return not _cancelled()


func _sort_rows(rows: Array[Dictionary], by_wall: bool) -> Array[Dictionary]:
	# 합병 한 항목마다 쉼/취소 확인. 전체 벽 수와 무관하게 한 조각을 제한한다.
	var source: Array[Dictionary] = rows
	var width: int = 1
	var forward: Vector3 = -camera_back()
	while width < source.size():
		var merged: Array[Dictionary] = []
		for start: int in range(0, source.size(), width * 2):
			var middle: int = mini(start + width, source.size())
			var end: int = mini(start + width * 2, source.size())
			var left: int = start
			var right: int = middle
			while left < middle or right < end:
				if not await _checkpoint():
					return []
				var take_left: bool = right >= end
				if left < middle and right < end:
					take_left = String(source[left]["id"]) <= String(source[right]["id"]) if by_wall else (source[left]["position"] as Vector3).dot(forward) <= (source[right]["position"] as Vector3).dot(forward)
				if left < middle and take_left:
					merged.append(source[left])
					left += 1
				else:
					merged.append(source[right])
					right += 1
		source = merged
		width *= 2
	return source


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
		var waits: Dictionary = stats["wait_stages"]
		var stage: String = stats["stage"]
		waits[stage] = int(waits.get(stage, 0)) + 1
	_work_start = Time.get_ticks_usec()
	_pieces = 0
	stats["pieces"] = int(stats["pieces"]) + 1


func _rest_due() -> bool:
	var accounted: int = _continuous_usec if _staged else 0
	return _pieces >= PIECE_CAP or accounted + Time.get_ticks_usec() - _work_start >= WORK_USEC


func build_layout(walls: Array, vis: Dictionary, pace: BuildPace = null, table: Dictionary = {}) -> Array[Dictionary]:
	_begin_stats(pace)
	_staged = _staged or bool(vis.get("staged", false))
	return await _build_layout(walls, vis, table)


func _build_layout(walls: Array, vis: Dictionary, table: Dictionary) -> Array[Dictionary]:
	stats["stage"] = "validate"
	var head_max: float = head_height(table)
	var map_size: Vector2 = vis.get("map_size", Vector2.ZERO)
	var valid: Array[Dictionary] = []
	var ids: Dictionary = {}
	for entry: Variant in walls:
		if not await _checkpoint():
			return []
		if entry is Dictionary:
			var id: String = String(entry.get("id", ""))
			ids[id] = int(ids.get(id, 0)) + 1
	for entry: Variant in walls:
		if not await _checkpoint():
			return []
		var wall: Dictionary = entry if entry is Dictionary else {}
		var why: String = wall_error(wall, map_size, vis.get("grid"))
		if why.is_empty() and int(ids.get(String(wall["id"]), 0)) != 1:
			why = "중복 id"
		if not why.is_empty():
			stats["invalid_walls"] = int(stats["invalid_walls"]) + 1
			push_warning("HordeView 벽 무시: %s (%s)" % [String(wall.get("id", "?")).replace("\n", " ").replace("\r", " "), why])
		else:
			valid.append(wall)
	stats["stage"] = "wall_sort"
	valid = await _sort_rows(valid, true)
	if _cancelled():
		return []
	var endpoints: Dictionary = {}
	stats["stage"] = "endpoints"
	for wall: Dictionary in valid:
		if not await _checkpoint():
			return []
		for key: String in ["a", "b"]:
			var endpoint := Vector2i(wall[key])
			endpoints[endpoint] = int(endpoints.get(endpoint, 0)) + 1
	# 모든 유효 벽의 후보를 먼저 센다. 같은 배율과 내림으로 지도 상한을 지킨다.
	var plans: Array[Dictionary] = []
	var candidate_sum: float = 0.0
	stats["stage"] = "plans"
	for wall: Dictionary in valid:
		if not await _checkpoint():
			return []
		var a: Vector2 = wall["a"]
		var b: Vector2 = wall["b"]
		var length_m: float = a.distance_to(b)
		var depth_m: float = minf(40.0, float(wall.get("depth", 40.0)))
		if depth_m <= 0.4:
			continue
		var start_gap: float = 2.0 if int(endpoints[Vector2i(a)]) == 1 else 0.0
		var end_gap: float = 2.0 if int(endpoints[Vector2i(b)]) == 1 else 0.0
		for chunk_i: int in range(int(ceil(length_m / CHUNK_M))):
			if not await _checkpoint():
				return []
			var lo: float = maxf(start_gap, float(chunk_i) * CHUNK_M)
			var hi: float = minf(length_m - end_gap, float(chunk_i + 1) * CHUNK_M)
			if hi > lo:
				var candidates: float = (hi - lo) * density_area(depth_m)
				plans.append({"wall": wall, "chunk_i": chunk_i, "lo": lo, "hi": hi, "depth": depth_m, "candidates": candidates})
				candidate_sum += candidates
	var density_scale: float = minf(1.0, float(MAP_CAP) / maxf(candidate_sum, 1.0))
	stats["density_scale"] = density_scale
	stats["candidate_sum"] = candidate_sum
	var result: Array[Dictionary] = []
	var bins: Dictionary = {}
	for plan: Dictionary in plans:
		stats["stage"] = "candidates"
		if not await _checkpoint():
			return []
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
			if not await _checkpoint():
				return []
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
		stats["stage"] = "people_sort"
		people = await _sort_rows(people, false)
		if _cancelled():
			return []
		if not people.is_empty():
			stats["stage"] = "aabb"
			var box: AABB = await _card_aabb(people)
			if _cancelled():
				return []
			result.append({"id": "%s:%d" % [wall_id, chunk_i], "wall": wall, "people": people, "aabb": box})
			stats["instances"] = int(stats["instances"]) + people.size()
		if not await _checkpoint(true):
			return []
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
	set_process(false)
	_begin_stats(pace)
	_staged = _staged or bool(vis.get("staged", false))
	_sight = vis
	_history.resize(HISTORY_SIZE)
	_history.fill(Vector4.ZERO)
	visibility_changed.connect(_visibility_reset)
	stats["stage"] = "table"
	# 표/아틀라스/셰이더는 각각 독립된 준비 조각. 동기 load 자체의 시간도 계측한다.
	if not await _checkpoint(true):
		return
	var table_start: int = Time.get_ticks_usec()
	var table_result: Dictionary = _read_table_result()
	var table: Dictionary = table_result["table"]
	stats["table_error"] = table_result["error"]
	_resource_account(table_start)
	if not await _checkpoint(true):
		return
	# 깊이 0은 정상 무배치. 실제 배치를 요청한 벽의 표 오류는 가림 제거 전에 알린다.
	for entry: Variant in walls:
		if not await _checkpoint():
			return
		if entry is Dictionary and wall_error(entry, vis.get("map_size", Vector2.ZERO), vis.get("grid")).is_empty() and float(entry.get("depth", 40.0)) > 0.0 and not String(table_result["error"]).is_empty():
			stats["table_warning"] = table_result["error"]
			push_warning("HordeView 칸 표: " + String(table_result["error"]))
			_account()
			return
	chunks = await _build_layout(walls, vis, table)
	if _cancelled():
		return
	if chunks.is_empty():
		return
	stats["stage"] = "atlas"
	if not await _checkpoint(true):
		return
	var resource_start: int = Time.get_ticks_usec()
	stats["resource_loads"] = int(stats["resource_loads"]) + 1
	var atlas: Texture2D = _load_atlas()
	_resource_account(resource_start)
	if not await _checkpoint(true):
		return
	stats["stage"] = "shader"
	resource_start = Time.get_ticks_usec()
	stats["resource_loads"] = int(stats["resource_loads"]) + 1
	var shader: Shader = _load_shader()
	_resource_account(resource_start)
	if not await _checkpoint(true):
		return
	if atlas == null or shader == null or atlas.get_size() != Vector2(ATLAS_SIZE):
		push_warning("HordeView: 아틀라스 크기 또는 셰이더 자원 오류")
		return
	var mesh: ArrayMesh = card_mesh()
	stats["stage"] = "upload"
	for chunk: Dictionary in chunks:
		if not await _checkpoint():
			return
		var wall: Dictionary = chunk["wall"]
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("atlas", atlas)
		configure_card(mat, table)
		mat.set_shader_parameter("wall_a", wall["a"])
		mat.set_shader_parameter("wall_b", wall["b"])
		mat.set_shader_parameter("wall_out", wall["out"])
		mat.set_shader_parameter("focus_history", _history)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		var people: Array[Dictionary] = chunk["people"]
		mm.instance_count = people.size()
		mm.custom_aabb = chunk["aabb"]
		for index: int in range(people.size()):
			if not await _checkpoint():
				return
			mm.set_instance_transform(index, Transform3D(Basis.IDENTITY, people[index]["position"]))
			mm.set_instance_custom_data(index, people[index]["custom"])
			stats["uploaded_instances"] = int(stats["uploaded_instances"]) + 1
		var draw := MultiMeshInstance3D.new()
		draw.name = "HordeChunk_%d" % _draws.size()
		draw.multimesh = mm
		draw.material_override = mat
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.visible = false
		add_child(draw)
		_draws.append(draw)
		_materials.append(mat)
		if not await _checkpoint(true):
			return
	_sync_sight()
	stats["ready"] = true
	set_process(true)
	_account()
	print("HORDE_BUILD ", stats)


func _resource_account(start: int) -> void:
	var elapsed_ms: float = float(Time.get_ticks_usec() - start) / 1000.0
	stats["resource_ms"] = float(stats["resource_ms"]) + elapsed_ms
	stats["resource_max_ms"] = maxf(float(stats["resource_max_ms"]), elapsed_ms)
	_account()


func _read_table_result() -> Dictionary:
	return read_table_result()


func _load_atlas() -> Texture2D:
	resource_reads += 1
	return load(ATLAS_PATH) if ResourceLoader.exists(ATLAS_PATH) else null


func _load_shader() -> Shader:
	resource_reads += 1
	return load("res://fx/shaders/horde_far.gdshader")


static func read_table() -> Dictionary:
	return read_table_result()["table"]


static func read_table_result(path: String = TABLE_PATH) -> Dictionary:
	resource_reads += 1
	if not FileAccess.file_exists(path):
		return {"table": {}, "error": "없음: " + path}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"table": {}, "error": "읽기 실패: %s (%d)" % [path, FileAccess.get_open_error()]}
	return parse_table_result(file.get_as_text())


static func parse_table_result(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"table": {}, "error": "파싱: %s (%d줄)" % [json.get_error_message(), json.get_error_line()]}
	var table: Dictionary = _validated_table(json.data)
	return {"table": table, "error": "계약 다름" if table.is_empty() else ""}


## The baked table's text -> the table, or {} when it does not match this code.
static func parse_table(text: String) -> Dictionary:
	return parse_table_result(text)["table"]


static func _validated_table(parsed: Variant) -> Dictionary:
	if not parsed is Dictionary:
		return {}
	var table: Dictionary = parsed
	# JSON gives every number back as a float, and Array == is strict about int
	# against float, so compare with the contract after the same round trip.
	var contract: Dictionary = JSON.parse_string(JSON.stringify(table_contract()))
	for key: String in contract:
		if table.get(key) != contract[key]:
			return {}
	if not table.get("bounds_px") is Array or (table["bounds_px"] as Array).size() != 32:
		return {}
	if not table.get("foot_px_x") is Array or (table["foot_px_x"] as Array).size() != 32:
		return {}
	for foot_x: Variant in table["foot_px_x"]:
		if not (foot_x is float or foot_x is int) or not is_finite(float(foot_x)) or float(foot_x) < 2.0 or float(foot_x) > float(CELL.x - 2):
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
	var values: Dictionary = {"vis_texture": _sight.get("vis_texture"), "map_size": _sight.get("map_size", Vector2.ONE)}
	if source != null:
		for key: String in ["mask_on", "eye_xz", "eye_r", "round_day", "round_floor"]:
			var value: Variant = source.get_shader_parameter(key)
			frame_sight_reads += 1
			if value != null:
				values[key] = value
	for key: String in values:
		var value: Variant = values[key]
		if _sight_cache.has(key) and _sight_cache[key] == value:
			continue
		_sight_cache[key] = value
		for mat: ShaderMaterial in _materials:
			_write_frame_parameter(mat, key, value)


func _write_frame_parameter(mat: ShaderMaterial, key: String, value: Variant) -> void:
	mat.set_shader_parameter(key, value)
	frame_material_writes += 1


func _process(delta: float) -> void:
	frame_material_writes = 0
	frame_sight_reads = 0
	if not is_visible_in_tree():
		return
	var field: Node = _sight.get("field")
	var player: Node3D = field.get("player") if is_instance_valid(field) else _sight.get("player")
	var held: bool = is_instance_valid(field) and bool(field.get("paused")) and not bool(field.get("ended"))
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
	_sync_sight()
	# 개체가 아닌 소수 덩어리만 추려 여섯 개 상한을 지킨다.
	var camera: Camera3D = get_viewport().get_camera_3d()
	visible_chunks = _select_visible(camera)
	for index: int in range(_draws.size()):
		_draws[index].visible = visible_chunks.has(index)
	for index: int in visible_chunks:
		var mat: ShaderMaterial = _materials[index]
		_write_frame_parameter(mat, "focus", _focus)
		_write_frame_parameter(mat, "focus_clock", _focus_clock)
		_write_frame_parameter(mat, "focus_history", _history)


func _select_visible(camera: Camera3D) -> Array[int]:
	var candidates: Array[int] = []
	if camera == null:
		return candidates
	var planes: Array[Plane] = camera.get_frustum()
	for index: int in range(chunks.size()):
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
	if candidates.size() > VISIBLE_CAP:
		candidates.resize(VISIBLE_CAP)
	return candidates


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
