extends RefCounted
## 보호 칸을 보존하며 지상 경계를 한 번만 찍는다.

const FieldGrid = preload("res://game/world/field_grid.gd")
const Rule = preload("res://game/world/map_bounds_rule.gd")
const StopGround = preload("res://game/world/stop_ground.gd")
const EdgeBand = preload("res://game/world/edge_band.gd")
## 경계 보호에 넣는 샛길 몫. 띠(`belt`)·성긴 숲(`woods`)은 나무라 넣지 않는다.
const SIDE_PATH_WALK: Array[String] = ["gap", "entrance", "store", "door"]


static func check(bounds: Dictionary, grid: FieldGrid) -> Array[String]:
	var errors: Array[String] = []
	if bounds.is_empty():
		return errors
	if not bounds.get("rule", 0) is int or int(bounds.get("rule", 0)) < 0:
		errors.append("rule: 0 이상의 정수가 필요합니다")
		return errors
	if int(bounds.get("rule", 0)) == 0:
		return errors
	if bounds.get("made_by", "") not in ["rule", "hand"]:
		errors.append("made_by: rule 또는 hand가 필요합니다")
	var sides: Variant = bounds.get("sides")
	if not sides is Array or sides.size() != 4:
		errors.append("sides: 왼쪽, 위, 오른쪽, 아래의 네 폭이 필요합니다")
	else:
		for width: Variant in sides:
			if not width is int or width < 0:
				errors.append("sides: 폭은 0 이상의 정수여야 합니다")
	var gaps: Variant = bounds.get("gaps")
	if not gaps is Array:
		errors.append("gaps: 진입로 이름 배열이 필요합니다")
	else:
		for gap: Variant in gaps:
			if not gap is String:
				errors.append("gaps: 진입로 이름은 문자열이어야 합니다")
	var outline: Variant = bounds.get("outline")
	if not outline is Array or outline.size() < 4:
		errors.append("outline: 닫는 변을 포함한 꼭짓점 네 개 이상이 필요합니다")
		return errors
	for point: Variant in outline:
		if not point is Vector2i:
			errors.append("outline: 꼭짓점은 Vector2i여야 합니다")
			return errors
		if point.x < 0 or point.y < 0 or point.x > grid.width or point.y > grid.height:
			errors.append("outline: 격자 밖 꼭짓점입니다")
	var count: int = outline.size()
	var area: int = 0
	for i in range(count):
		var a: Vector2i = outline[i]
		var b: Vector2i = outline[(i + 1) % count]
		var c: Vector2i = outline[(i + 2) % count]
		if a == b or (a.x != b.x and a.y != b.y):
			errors.append("outline/%d: 길이가 있는 가로 또는 세로 변이어야 합니다" % i)
		if (a.x == b.x) == (b.x == c.x):
			errors.append("outline/%d: 이웃 변의 방향이 같거나 겹칩니다" % i)
		area += a.x * b.y - b.x * a.y
		for j in range(i + 2, count):
			if i == 0 and j == count - 1:
				continue
			var u: Vector2i = outline[j]
			var v: Vector2i = outline[(j + 1) % count]
			if maxi(mini(a.x, b.x), mini(u.x, v.x)) <= mini(maxi(a.x, b.x), maxi(u.x, v.x)) \
					and maxi(mini(a.y, b.y), mini(u.y, v.y)) <= mini(maxi(a.y, b.y), maxi(u.y, v.y)):
				errors.append("outline/%d/%d: 자기 교차 또는 겹침입니다" % [i, j])
	if area <= 0:
		errors.append("outline: 시계 방향이어야 합니다")
	var runs: Variant = bounds.get("runs")
	if not runs is Array:
		errors.append("runs: 구간 배열이 필요합니다")
		return errors
	var next_edge: int = 0
	for run: Variant in runs:
		if not run is Dictionary or not run.get("from") is int or not run.get("to") is int:
			errors.append("runs: from/to 정수가 필요합니다")
			return errors
		if run["from"] != next_edge or run["to"] <= run["from"] or run["to"] > count:
			errors.append("runs: 변 번호가 빠지거나 겹칩니다")
		if run.get("kind", "") not in ["wall", "cliff", "rock", "mine", "forest", "water", "quarry"]:
			errors.append("runs: 알 수 없는 갈래입니다")
		next_edge = run["to"]
	if next_edge != count:
		errors.append("runs: 마지막 변까지 덮어야 합니다")
	return errors


## 찍힌 자료의 판이 다르면 호출자가 원본부터 다시 준비해야 한다.
static func can_reuse(data: Dictionary, bounds_rule: int = -1) -> bool:
	var requested: int = Rule.RULE if Rule.enabled(String(data.get("place_id", "")), bounds_rule) else maxi(bounds_rule, 0)
	if data.has("bounds_failure") and int(data.get("bounds_ring_rule", 0)) == 0:
		return requested in [0, Rule.RULE]
	if not data.has("bounds_stamp"):
		return int(data.get("bounds_ring_rule", 0)) == requested or not data.has("map_ring")
	return int(data["bounds_stamp"]) == requested


## 실패 자료를 반환하지 않고 같은 입력의 원본 판 0 전체를 돌려준다.
static func finish(data: Dictionary, base_factory: Callable, bounds_rule: int = -1, solver: Callable = Callable()) -> Dictionary:
	if data.has("bounds_failure") and int(data.get("bounds_ring_rule", 0)) == 0:
		return data
	if data.has("bounds_stamp") or not Rule.enabled(String(data.get("place_id", "")), bounds_rule):
		return apply(data, bounds_rule)
	data.get_or_add("_ms", {})["bounds_baseline"] = 0.0
	var result: Dictionary = apply(data, bounds_rule, -1, solver)
	if result.has("bounds_failure"):
		var mark: int = Time.get_ticks_usec()
		var base: Dictionary = base_factory.call()
		result.get_or_add("_ms", {})["bounds_fallback"] = float(Time.get_ticks_usec() - mark) / 1000.0
		base["bounds_failure"] = result["bounds_failure"]
		base["bounds_attempts"] = result.get("bounds_attempts", [])
		base["_ms"] = result.get("_ms", {})
		return base
	return result


## 원래 지도+고리. 정차 꼴이 붙인 통로 띠는 분자와 분모 양쪽에서 제외한다.
static func playable_rect(data: Dictionary) -> Rect2i:
	var g: FieldGrid = data["grid"]
	# map_shift가 inner도 옮긴다. 샛길/정차 통로가 붙기 전 고리의 범위를 복원한다.
	var ring: Dictionary = data.get("map_ring", {})
	if ring.has("inner") and ring.has("sides"):
		var inner: Rect2i = ring["inner"]
		var widths: Array = ring["sides"]
		return Rect2i(inner.position - Vector2i(widths[0], widths[1]),
			inner.size + Vector2i(widths[0] + widths[2], widths[1] + widths[3]))
	return data.get("stop_old_ground", Rect2i(0, 0, g.width, g.height))


static func count_playable(data: Dictionary, blocked: PackedByteArray = PackedByteArray()) -> int:
	var g: FieldGrid = data["grid"]
	var area: Rect2i = playable_rect(data)
	var count: int = 0
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var i: int = g.index(Vector2i(x, y))
			count += int(g.walk_people[i] == 1 and (blocked.is_empty() or blocked[i] == 0))
	return count


static func apply(data: Dictionary, bounds_rule: int = -1, _base_walk: int = -1, solver: Callable = Callable()) -> Dictionary:
	if not can_reuse(data, bounds_rule):
		push_error("다른 판의 경계는 원본부터 다시 준비해야 합니다")
		data["bounds_failure"] = "판 불일치"
		return data
	var bounds: Dictionary = data.get("bounds", {})
	var mask := PackedByteArray()
	if bounds.is_empty() and Rule.enabled(String(data.get("place_id", "")), bounds_rule):
		var mark: int = Time.get_ticks_usec()
		var protection: Array[Dictionary] = []
		mask = protected_cells(data, protection)
		data.get_or_add("_ms", {})["bounds_protect"] = float(Time.get_ticks_usec() - mark) / 1000.0
		bounds = solver.call(data, mask, protection) if solver.is_valid() else _connected_outline(data, mask, protection)
		if bounds.is_empty():
			data["bounds_failure"] = "해 없음: 모양/보호/연결 또는 17회 한도"
			return data
	if bounds.is_empty() or bounds_rule == 0 or bounds.get("rule", 0) == 0:
		return data
	var errors: Array[String] = check(bounds, data["grid"])
	if bounds.get("made_by") == "rule":
		errors.append_array(Rule.shape_errors(data["grid"], bounds))
	if not errors.is_empty():
		data["bounds_failure"] = "; ".join(errors)
		push_error("경계 검사 실패: " + "; ".join(errors))
		return data
	# 요청한 저장 판의 자료가 없으면 다른 판으로 표시하지 않는다(설계 7a).
	var rule: int = int(bounds["rule"])
	if bounds_rule > 0 and bounds_rule != rule:
		return data
	if data.has("bounds_stamp"):
		return data
	var tiles: Array = bounds.get("tiles", [])
	var g: FieldGrid = data["grid"]
	for tile: Dictionary in tiles:
		var rect: Rect2i = tile["rect"]
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				if not mask.is_empty() and mask[g.index(Vector2i(x, y))] != 0:
					data["bounds_failure"] = "보호 칸 침범"
					push_error("경계가 보호 칸에 닿았습니다")
					return data
	var forest: Array[Rect2i] = []
	var stamp_started: int = Time.get_ticks_usec()
	var blocked: int = 0
	for tile: Dictionary in tiles:
		var rect: Rect2i = tile["rect"]
		var water: bool = tile["kind"] == "water"
		if water:
			blocked += _water(data, rect)
		else:
			blocked += _paint(g, rect, false)
			forest.append(rect)
	data["bounds"] = bounds
	data["bounds_blocked"] = blocked
	if not tiles.is_empty():
		g.revision += 1
		data.get_or_add("deep_forest", []).append_array(forest)
		StopGround.view_forest_trees(data, forest, Rule.random_of(String(data["place_id"])), 1)
		_remove_trees(data)
	data["bounds_stamp"] = rule
	_water_regions(data)
	if Rule.enabled(String(data.get("place_id", "")), bounds_rule):
		data.get_or_add("_ms", {})["bounds_stamp_ms"] = float(Time.get_ticks_usec() - stamp_started) / 1000.0
	return data


## 물 enum이 없어 ICE를 유지하되 1=윤곽 쪽 한 칸 물가, 2=물 바닥으로 구별한다.
static func _water_regions(data: Dictionary) -> void:
	var g: FieldGrid = data["grid"]
	var regions := PackedByteArray()
	regions.resize(g.width * g.height)
	var outside := PackedByteArray()
	outside.resize(regions.size())
	# 손으로 만든 계약 자료(PR1a 시험)엔 tiles가 없다 — 물 칸도 없다.
	for tile: Dictionary in data["bounds"].get("tiles", []):
		var rect: Rect2i = tile["rect"]
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				var i: int = g.index(Vector2i(x, y))
				outside[i] = 1
				if tile["kind"] == "water": regions[i] = 2
	for i: int in range(regions.size()):
		if regions[i] != 2: continue
		var cell := Vector2i(i % g.width, floori(float(i) / g.width))
		for delta: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + delta
			if g.inside(next) and outside[g.index(next)] == 0:
				regions[i] = 1
	data["bounds_water_regions"] = regions


static func _paint(g: FieldGrid, rect: Rect2i, water: bool) -> int:
	var blocked: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var i: int = g.index(Vector2i(x, y))
			blocked += int(g.solid[i] == FieldGrid.Solid.NONE)
			g.solid[i] = FieldGrid.Solid.LOW if water else FieldGrid.Solid.BLOCK
			g.floor[i] = FieldGrid.Floor.ICE if water else FieldGrid.Floor.SNOW
			g.building[i] = -1
			g.opq[i] = 0 if water else 1
			g.walk_people[i] = 0
			g.walk_dead[i] = 0
	g.people_path.fill_solid_region(rect, true)
	g.dead_path.fill_solid_region(rect, true)
	return blocked


static func _water(data: Dictionary, rect: Rect2i) -> int:
	# 기존 바닥에는 별도 물 enum이 없다. ICE와 LOW를 함께 쓰고 회색 낮은 상자는 만들지 않는다.
	data.get_or_add("props", []).append({"kind": "water", "rect": rect, "solid": "low", "level": 0})
	return _paint(data["grid"], rect, true)


static func _protect(mask: PackedByteArray, g: FieldGrid, value: Variant, pad: int = 2, details: Array[Dictionary] = [], kind: String = "") -> void:
	if value is Vector3:
		_protect(mask, g, FieldGrid.cell_of(value), pad, details, kind)
	elif value is Vector2i or value is Vector2:
		_protect(mask, g, Rect2i(Vector2i(value), Vector2i.ONE), pad, details, kind)
	elif value is Rect2i:
		var rect: Rect2i = value.grow(pad).intersection(Rect2i(0, 0, g.width, g.height))
		if not kind.is_empty() and rect.has_area():
			details.append({"kind": kind, "rect": rect})
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				mask[g.index(Vector2i(x, y))] = 1
	elif value is Array:
		for item: Variant in value:
			_protect(mask, g, item, pad, details, kind)
	elif value is Dictionary:
		for item: Variant in value.values():
			_protect(mask, g, item, pad, details, kind)


static func protected_cells(data: Dictionary, details: Array[Dictionary] = []) -> PackedByteArray:
	var g: FieldGrid = data["grid"]
	var mask := PackedByteArray()
	mask.resize(g.width * g.height)
	for key: String in ["train", "platform", "boarding", "unloading", "train_doors", "bands", "side_path", "spots", "stairs", "anchors", "village_middle", "deep_forest"]:
		var value: Variant = data.get(key)
		if key == "side_path" and value is Dictionary:
			# 샛길은 지나가는 몫(틈·입구·창고·문)만 지킨다. 띠·성긴 숲 나무까지 지키면 띠 줄 전체와
			# 모서리가 깊이 0으로 묶여 깊이 풀이가 해 없음이 된다(북·서 샛길).
			var spot: Dictionary = value
			var walk: Dictionary = {}
			for part: String in SIDE_PATH_WALK:
				if spot.has(part): walk[part] = spot[part]
			value = walk
		_protect(mask, g, value, 2, details, key)
	for building: Dictionary in data.get("buildings", []):
		_protect(mask, g, building["rect"], 3, details, "building")
	for grid: FieldGrid in data.get("levels", {0: g}).values():
		_protect(mask, g, grid.doors.keys(), 5, details, "door")
		_protect(mask, g, grid.windows.keys(), 5, details, "window")
	for box: Dictionary in data.get("containers", {}).values():
		_protect(mask, g, box.get("cell"), 3, details, "container")
	for key: String in data.get("entries", {}):
		if int(data.get("entry_levels", {}).get(key, 0)) != 0 or key in data.get("manholes", {}):
			continue
		for cell: Vector2i in data["entries"][key]:
			var reach: Vector2i = Vector2i(8, 4) if cell.x in [0, g.width - 1] else Vector2i(4, 8)
			_protect(mask, g, Rect2i(cell - reach, reach * 2 + Vector2i.ONE), 2, details, "entry/" + key)
	for opening: Dictionary in EdgeBand.openings(g):
		var side: int = int(opening["side"])
		var inward: Vector2i = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP][side]
		var first: Vector2i = EdgeBand._edge_cell(g, side, int(opening["from"]))
		var last: Vector2i = EdgeBand._edge_cell(g, side, int(opening["to"])) + inward * 8
		var area := Rect2i(first.min(last), (last - first).abs() + Vector2i.ONE)
		# ±3은 길을 가로지르는 방향에만 적용한다. grow(8)은 틈을 16m 더 넓혔다.
		if side < 2:
			area.position.y -= 3
			area.size.y += 6
		else:
			area.position.x -= 3
			area.size.x += 6
		_protect(mask, g, area, 2, details, "road_rail")
	_name_side_path(data, details)
	return mask


## 잠긴 문을 통과시키지 않는다. 샛길 통행 칸에서 문 바로 앞 바깥 칸까지 걷는다.
## 이름은 보호 정보에만 붙이며 보호 마스크와 배치는 그대로 둔다.
static func _name_side_path(data: Dictionary, details: Array[Dictionary]) -> void:
	if details.is_empty(): return
	var spot: Dictionary = data.get("side_path", {})
	var g: FieldGrid = data["grid"]
	if not spot.get("store") is Rect2i or not spot.get("door") is Vector2i: return
	var side: int = int(spot.get("side", -1))
	if side < 0 or side > 3: return
	var store_rect: Rect2i = spot["store"]
	var door: Vector2i = spot["door"]
	var building_id: int = int(spot.get("building", -1))
	if building_id < 0 or not g.doors.has(door) or int(g.doors[door].get("building", -2)) != building_id: return
	var owned: Array[Rect2i] = []
	owned.append(store_rect.grow(3).intersection(Rect2i(0, 0, g.width, g.height)))
	for cell: Vector2i in g.doors:
		if int(g.doors[cell].get("building", -2)) == building_id:
			owned.append(Rect2i(cell, Vector2i.ONE).grow(5).intersection(Rect2i(0, 0, g.width, g.height)))
	for cell: Vector2i in g.windows:
		if int(g.windows[cell].get("building", -2)) == building_id:
			owned.append(Rect2i(cell, Vector2i.ONE).grow(5).intersection(Rect2i(0, 0, g.width, g.height)))
	var candidates: Array[int] = []
	var domain := PackedByteArray()
	domain.resize(g.width * g.height)
	for i: int in range(details.size()):
		var item: Dictionary = details[i]
		var rect: Rect2i = item["rect"]
		if item["kind"] != "side_path" and not (item["kind"] in ["building", "door", "window"] and owned.has(rect)): continue
		candidates.append(i)
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x): domain[g.index(Vector2i(x, y))] = 1
	var seen := PackedByteArray()
	seen.resize(domain.size())
	var connected := PackedByteArray()
	connected.resize(domain.size())
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	# entrance는 숲 띠 바로 안쪽의 실제 입구다. gap만 고립되어도 허용하지 않는다.
	for root: Vector2i in spot.get("entrance", []):
		if not g.inside(root): continue
		var root_index: int = g.index(root)
		if domain[root_index] == 0 or g.walk_people[root_index] != 1 or seen[root_index] != 0: continue
		var queue: Array[Vector2i] = [root]
		seen[root_index] = 1
		var cursor: int = 0
		var reached_door: bool = false
		var reached_gap: bool = false
		while cursor < queue.size():
			var cell: Vector2i = queue[cursor]
			cursor += 1
			reached_gap = reached_gap or spot.get("gap", []).has(cell)
			if not store_rect.has_point(cell) and absi(cell.x - door.x) + absi(cell.y - door.y) == 1:
				reached_door = true
			for direction: Vector2i in directions:
				var next: Vector2i = cell + direction
				if not g.inside(next): continue
				var index: int = g.index(next)
				if domain[index] == 1 and seen[index] == 0 and g.walk_people[index] == 1:
					seen[index] = 1
					queue.append(next)
		if reached_door and reached_gap:
			for cell: Vector2i in queue: connected[g.index(cell)] = 1
	var name: String = "side_path/" + String(["north", "east", "south", "west"][side])
	# 같은 side_path 사전의 멀리 떨어진 woods까지 이름을 퍼뜨리지 않는다.
	for i: int in candidates:
		var rect: Rect2i = details[i]["rect"]
		var touches: bool = false
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				if connected[g.index(Vector2i(x, y))] == 1:
					touches = true
					break
			if touches: break
		if touches: details[i]["open_name"] = name


## 찍기 전에 연결성을 검사한다. 끊길 통로는 원래 걷기 경로를 보호하고 윤곽을 다시 푼다.
static func _connected_outline(data: Dictionary, mask: PackedByteArray, protection: Array[Dictionary]) -> Dictionary:
	var times: Dictionary = data.get_or_add("_ms", {})
	for key: String in ["bounds_outline", "bounds_connect", "bounds_loss", "bounds_shape", "bounds_prepare"]:
		times[key] = 0.0
	var mark: int = Time.get_ticks_usec()
	var g: FieldGrid = data["grid"]
	var area: Rect2i = playable_rect(data)
	var playable_before: int = count_playable(data)
	var profiles: Array[PackedInt32Array] = Rule.limits(g, mask)
	var component_roots: Array[int] = []
	var before := PackedInt32Array()
	var dead_before: Dictionary = {}
	var preexisting: Array[Vector2i] = []
	var routes: Array[Vector2i] = []
	var route_cells: Dictionary = {}
	var blocked := PackedByteArray()
	blocked.resize(g.width * g.height)
	var touched: Array[int] = []
	var attempts: Array[Dictionary] = []
	# ON 지도의 생성 분기에서만 호출한다.
	data["bounds_attempts"] = attempts
	times["bounds_prepare"] = float(Time.get_ticks_usec() - mark) / 1000.0
	for attempt: int in range(Rule.DEPTH + 1):
		mark = Time.get_ticks_usec()
		var bounds: Dictionary = Rule.outline(data, mask, protection, attempt, profiles)
		times["bounds_outline"] += float(Time.get_ticks_usec() - mark) / 1000.0
		mark = Time.get_ticks_usec()
		var shape: Dictionary = Rule.shape_report(g, bounds)
		var record: Dictionary = {"attempt": attempt + 1, "candidate": attempt, "shape": shape,
			"grid_size": Vector2i(g.width, g.height), "playable_rect": area,
			"rejected": [], "detached_people": -1, "detached_dead_pairs": -1, "connect_checked": false,
			# routes는 공유 배열이다. 다음 시도의 from(마지막은 최종 길이)까지가 이번에 더한 칸이다.
			"connect_routes": {"from": routes.size(), "cells": routes}}
		attempts.append(record)
		record["rejected"].append_array(shape["errors"])
		times["bounds_shape"] += float(Time.get_ticks_usec() - mark) / 1000.0
		if not bounds.has("outline"):
			record["area_checked"] = false
			continue
		mark = Time.get_ticks_usec()
		# 전체 재집계 대신 이전 후보의 표시만 지우고 이번 네모만 센다.
		for index: int in touched: blocked[index] = 0
		touched.clear()
		var walk_loss: int = 0
		var newly_blocked: int = 0
		var protected_hits: int = 0
		for tile: Dictionary in bounds["tiles"]:
			var rect: Rect2i = tile["rect"]
			for y: int in range(rect.position.y, rect.end.y):
				var row_index: int = y * g.width
				for x: int in range(rect.position.x, rect.end.x):
					var index: int = row_index + x
					if blocked[index] != 0: continue
					blocked[index] = 1
					touched.append(index)
					newly_blocked += int(g.solid[index] == FieldGrid.Solid.NONE)
					protected_hits += int(mask[index] != 0)
					if x >= area.position.x and x < area.end.x and y >= area.position.y and y < area.end.y:
						walk_loss += int(g.walk_people[index] == 1)
		var new_walk: int = playable_before - walk_loss
		record.merge({"area_checked": true, "playable_before": playable_before, "walk_loss": walk_loss,
			"playable_walk": new_walk, "ratio_checked": false,
			"newly_blocked": newly_blocked, "blocked_share": float(newly_blocked) / blocked.size(),
			"protected_hits": protected_hits})
		if protected_hits > 0: record["rejected"].append("보호 칸 침범")
		times["bounds_loss"] += float(Time.get_ticks_usec() - mark) / 1000.0
		if not record["rejected"].is_empty(): continue
		# 모든 변과 면적을 고른 뒤에만 한 번 확인한다. 실패한 통로를 보호한 경우에만 다시 한다.
		mark = Time.get_ticks_usec()
		if before.is_empty():
			before = walk_parents(data)
			dead_before = _scan_walk(g, g.walk_dead, PackedByteArray(), component_roots, true)
			for index: int in range(before.size()):
				if g.walk_people[index] == 1 and before[index] < 0:
					preexisting.append(Vector2i(index % g.width, floori(float(index) / g.width)))
		var after: PackedInt32Array = walk_parents(data, blocked)
		var dead_after: Dictionary = _scan_walk(g, g.walk_dead, blocked, component_roots, true)
		var detached: Array[int] = []
		for index: int in range(before.size()):
			if before[index] >= 0 and blocked[index] == 0 and after[index] < 0: detached.append(index)
		var dead_lost: Array[Dictionary] = _dead_lost(data, dead_before, dead_after)
		record["connect_checked"] = true
		record["detached_people"] = detached.size()
		record["detached_dead_pairs"] = dead_lost.size()
		record["dead_lost"] = dead_lost
		if not detached.is_empty(): record["rejected"].append("새 사람 미도달 칸")
		if not dead_lost.is_empty(): record["rejected"].append("망자 진입로 연결 단절")
		if record["rejected"].is_empty():
			bounds["playable_walk"] = new_walk
			bounds["unreachable_before"] = preexisting
			bounds["protected_routes"] = routes
			times["bounds_connect"] += float(Time.get_ticks_usec() - mark) / 1000.0
			return bounds
		_add_routes(g, before, detached, blocked, mask, protection, routes, route_cells)
		var dead_detached: Array[int] = []
		for pair: Dictionary in dead_lost:
			dead_detached.append(pair["home_index"])
			dead_detached.append_array(pair["entry_indices"])
		_add_routes(g, dead_before["parents"], dead_detached, blocked, mask, protection, routes, route_cells)
		times["bounds_connect"] += float(Time.get_ticks_usec() - mark) / 1000.0
		mark = Time.get_ticks_usec()
		profiles = Rule.limits(g, mask)
		times["bounds_prepare"] += float(Time.get_ticks_usec() - mark) / 1000.0
	return {}


## 연결 영역 번호로 각 진입로와 각 둥지의 원래 연결을 함께 대조한다.
static func _dead_lost(data: Dictionary, before: Dictionary, after: Dictionary) -> Array[Dictionary]:
	var g: FieldGrid = data["grid"]
	var old_labels: PackedInt32Array = before["labels"]
	var new_labels: PackedInt32Array = after["labels"]
	var lost: Array[Dictionary] = []
	for key: String in data.get("entries", {}):
		if int(data.get("entry_levels", {}).get(key, 0)) != 0 or data.get("manholes", {}).has(key): continue
		var old_starts: Dictionary = {}
		var new_starts: Dictionary = {}
		for cell: Vector2i in data["entries"][key]:
			if not g.inside(cell): continue
			var index: int = g.index(cell)
			if old_labels[index] >= 0: old_starts.get_or_add(old_labels[index], []).append(index)
			if new_labels[index] >= 0: new_starts[new_labels[index]] = true
		for name: String in data.get("anchors", {}):
			if not name.begins_with("horde_home") or not data["anchors"][name] is Vector2i: continue
			var home: Vector2i = data["anchors"][name]
			if not g.inside(home): continue
			var index: int = g.index(home)
			if old_starts.has(old_labels[index]) and not new_starts.has(new_labels[index]):
				lost.append({"entry": key, "home": name, "home_index": index, "home_cell": home,
					"entry_indices": old_starts[old_labels[index]]})
	return lost


static func _add_routes(g: FieldGrid, parents: PackedInt32Array, detached: Array[int], blocked: PackedByteArray, mask: PackedByteArray, protection: Array[Dictionary], routes: Array[Vector2i], route_cells: Dictionary) -> void:
	var processed: Dictionary = {}
	for first: int in detached:
		var at: int = first
		while at >= 0 and parents[at] != at and not processed.has(at):
			processed[at] = true
			if blocked[at] != 0 and not route_cells.has(at):
				route_cells[at] = true
				var cell := Vector2i(at % g.width, floori(float(at) / g.width))
				routes.append(cell)
				_protect(mask, g, cell, 2, protection, "walk_route")
			at = parents[at]


static func walk_parents(data: Dictionary, blocked: PackedByteArray = PackedByteArray(), dead: bool = false, roots: Array = []) -> PackedInt32Array:
	var g: FieldGrid = data["grid"]
	var walk: PackedByteArray = g.walk_dead if dead else g.walk_people
	var starts: Array = data.get("train_doors", {}).values()
	if dead:
		starts = []
		for key: String in data.get("entries", {}):
			if int(data.get("entry_levels", {}).get(key, 0)) == 0 and not data.get("manholes", {}).has(key):
				starts.append(data["entries"][key])
	if not roots.is_empty(): starts = [roots]
	var seeds: Array[int] = []
	for cells: Array in starts:
		for cell: Vector2i in cells:
			if (dead or seeds.is_empty()) and g.inside(cell):
				var index: int = g.index(cell)
				if walk[index] == 1 and (blocked.is_empty() or blocked[index] == 0): seeds.append(index)
	return _scan_walk(g, walk, blocked, seeds)["parents"]


## 정수 큐와 걷기 캐시를 재사용한다. 망자는 전체 연결 영역을 한 번만 돈다.
static func _scan_walk(g: FieldGrid, walk: PackedByteArray, blocked: PackedByteArray, seeds: Array[int], components: bool = false) -> Dictionary:
	var parent := PackedInt32Array()
	parent.resize(walk.size())
	parent.fill(-1)
	var labels: PackedInt32Array = parent.duplicate()
	var queue := PackedInt32Array()
	queue.resize(walk.size())
	var read: int = 0
	var write: int = 0
	var directions: Array[int] = [-1, 1, -g.width, g.width]
	for seed_offset: int in range(walk.size() if components else seeds.size()):
		var root: int = seed_offset if components else seeds[seed_offset]
		if walk[root] == 0 or parent[root] >= 0 or (not blocked.is_empty() and blocked[root] != 0): continue
		parent[root] = root
		labels[root] = root
		queue[write] = root
		write += 1
		while read < write:
			var at: int = queue[read]
			read += 1
			var x: int = at % g.width
			for direction: int in directions:
				if (direction == -1 and x == 0) or (direction == 1 and x == g.width - 1): continue
				var next: int = at + direction
				if next < 0 or next >= walk.size() or parent[next] >= 0 or walk[next] == 0: continue
				if not blocked.is_empty() and blocked[next] != 0: continue
				parent[next] = at
				labels[next] = root
				queue[write] = next
				write += 1
	return {"parents": parent, "labels": labels}


static func _remove_trees(data: Dictionary) -> void:
	var g: FieldGrid = data["grid"]
	var kept: Array = []
	for cell: Vector2i in data.get("trees", []):
		if not EdgeBand.bounds_skip(g, data["bounds"], Vector2(cell) + Vector2.ONE * 0.5):
			kept.append(cell)
	data["trees"] = kept
	var props: Array = []
	for prop: Dictionary in data.get("props", []):
		if prop.get("kind") == "bare_tree" and EdgeBand.bounds_skip(g, data["bounds"], Vector2((prop["rect"] as Rect2i).get_center())):
			continue
		props.append(prop)
	data["props"] = props
