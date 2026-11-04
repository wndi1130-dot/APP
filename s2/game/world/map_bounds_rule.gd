extends RefCounted
## 경계 난수는 판의 난수와 독립이다. 좌표는 고리와 정차 꼴이 끝난 격자 기준.
const FieldGrid = preload("res://game/world/field_grid.gd")
const ON := ["lake_01"]
const RULE: int = 1
const DEPTH: int = 16


static func enabled(place: String, rule: int = -1) -> bool:
	return place in ON and rule in [-1, RULE]


static func random_of(place: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(place + "|bounds|" + str(RULE))
	return rng


static func sides(data: Dictionary, width: int) -> Array[int]:
	var g: FieldGrid = data["grid"]
	var rng := random_of(String(data["place_id"]))
	var deep_x: int = rng.randi_range(0, 1) * 2
	var deep_y: int = rng.randi_range(0, 1) * 2 + 1
	var ratio: float = rng.randf_range(2.0, 3.0)
	var target: float = float((g.width + width * 2) * (g.height + width * 2)) * 1.55
	var best: Array[int] = [width, width, width, width]
	var error: float = INF
	for shallow: int in range(1, 80):
		var candidate: Array[int] = [width + shallow, width + shallow, width + shallow, width + shallow]
		candidate[deep_x] = width + roundi(float(shallow) * ratio)
		candidate[deep_y] = width + roundi(float(shallow) * ratio)
		var delta: float = absf(float((g.width + candidate[0] + candidate[2]) * (g.height + candidate[1] + candidate[3])) - target)
		if delta < error:
			best.assign(candidate)
			error = delta
	return best


## 북/동/남/서의 바깥 방향 깊이를 격자 좌표로 바꾼다.
static func point(g: FieldGrid, side: int, along: int, depth: int) -> Vector2i:
	match side:
		0: return Vector2i(along, depth)
		1: return Vector2i(g.width - depth, along)
		2: return Vector2i(g.width - along, g.height - depth)
	return Vector2i(depth, g.height - along)


static func strip(g: FieldGrid, side: int, start: int, finish: int, depth: int) -> Rect2i:
	var a: Vector2i = point(g, side, start, 0)
	var b: Vector2i = point(g, side, finish, depth)
	return Rect2i(Vector2i(mini(a.x, b.x), mini(a.y, b.y)), Vector2i(absi(a.x - b.x), absi(a.y - b.y)))


static func _limit(g: FieldGrid, mask: PackedByteArray, side: int, start: int, finish: int) -> int:
	var depth: int = DEPTH
	var area: Rect2i = strip(g, side, start, finish, DEPTH)
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			if mask[g.index(Vector2i(x, y))] == 0:
				continue
			var distance: int = [y, g.width - 1 - x, g.height - 1 - y, x][side]
			depth = mini(depth, distance)
	return depth


## 후보 사이에 보호가 같으면 한 번만 만든다. 한 변당 깊이 16칸만 읽는다.
static func limits(g: FieldGrid, mask: PackedByteArray) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	for side: int in 4:
		var length: int = g.width if side % 2 == 0 else g.height
		var profile := PackedInt32Array()
		profile.resize(length)
		for along: int in range(length):
			profile[along] = _limit(g, mask, side, along, along + 1)
		out.append(profile)
	return out


static func _cap(profile: PackedInt32Array, start: int, finish: int) -> int:
	var cap: int = DEPTH
	for along: int in range(start, finish):
		cap = mini(cap, profile[along])
	return cap


## 남는 길이까지 먼저 배분하므로 마지막에도 8m 미만 토막이 생기지 않는다.
static func lengths(total: int, rng: RandomNumberGenerator) -> Array[int]:
	var count: int = mini(floori(float(total) / 8.0), ceili(float(total) / 12.0))
	var out: Array[int] = []
	var remaining: int = total
	for i: int in range(count):
		var after: int = count - i - 1
		var size: int = rng.randi_range(maxi(8, remaining - after * 16), mini(16, remaining - after * 8))
		out.append(size)
		remaining -= size
	return out


## 17개 깊이 상태의 동적 계획. 보호 밖의 깊이 0과 작은 꺾임을 만들지 않는다.
static func depths(row: Array[Dictionary], rng: RandomNumberGenerator, first: int, last: int, economy: int = 0, failure: Dictionary = {}) -> Array[int]:
	var costs := PackedInt32Array()
	costs.resize(DEPTH + 1)
	costs.fill(100000000)
	costs[first] = 0
	var parents: Array[PackedInt32Array] = []
	for i: int in range(row.size()):
		var next := PackedInt32Array()
		next.resize(DEPTH + 1)
		next.fill(100000000)
		var parent := PackedInt32Array()
		parent.resize(DEPTH + 1)
		parent.fill(-1)
		var cap: int = int(row[i]["cap"])
		var wish: int = maxi(0, rng.randi_range(0, cap) - economy)
		for depth: int in range(0 if cap == 0 else 1, cap + 1):
			if (i == 0 and depth != first) or (i == row.size() - 1 and depth != last):
				continue
			for previous: int in range(maxi(0, depth - 6), mini(DEPTH, depth + 6) + 1):
				# 보호가 강제한 깊이 0끼리만 긴 틈을 이룬다. 그 밖은 2m 이상 꺾는다.
				if i > 0 and absi(previous - depth) < 2 and not (depth == 0 and previous == 0):
					continue
				var cost: int = costs[previous] + depth * int(row[i]["to"] - row[i]["from"]) * 32 + absi(depth - wish)
				if cost < next[depth]:
					next[depth] = cost
					parent[depth] = previous
		var best_next: int = 100000000
		for value: int in next:
			best_next = mini(best_next, value)
		if best_next >= 100000000 and failure.is_empty():
			var reachable: Array[int] = []
			for depth: int in range(costs.size()):
				if costs[depth] < 100000000: reachable.append(depth)
			failure.merge({"step_index": i, "step": row[i].duplicate(), "previous_depths": reachable,
				"first": first, "last": last, "min_bend": 2, "max_neighbour": 6})
		costs = next
		parents.append(parent)
	if costs[last] >= 100000000:
		return []
	var out: Array[int] = []
	out.resize(row.size())
	var at: int = last
	for i: int in range(row.size() - 1, -1, -1):
		out[i] = at
		at = parents[i][at]
	return out


## 정차 꼴 숲과 겹치거나 맞닿는 길이만 빼고 남는 구간을 돌려준다.
static func measured_segments(a: Vector2i, b: Vector2i, forest: Array) -> Array[Dictionary]:
	var horizontal: bool = a.y == b.y
	var low: int = mini(a.x, b.x) if horizontal else mini(a.y, b.y)
	var high: int = maxi(a.x, b.x) if horizontal else maxi(a.y, b.y)
	var intervals: Array[Vector2i] = []
	for rect: Rect2i in forest:
		var touches: bool = (a.y >= rect.position.y and a.y <= rect.end.y) if horizontal else (a.x >= rect.position.x and a.x <= rect.end.x)
		if touches:
			var lo: int = maxi(low, rect.position.x if horizontal else rect.position.y)
			var hi: int = mini(high, rect.end.x if horizontal else rect.end.y)
			if hi > lo:
				intervals.append(Vector2i(lo, hi))
	intervals.sort_custom(func(u: Vector2i, v: Vector2i) -> bool: return u.x < v.x)
	intervals.append(Vector2i(high, high))
	var out: Array[Dictionary] = []
	var cursor: int = low
	for interval: Vector2i in intervals:
		if interval.x > cursor:
			var start := Vector2i(cursor, a.y) if horizontal else Vector2i(a.x, cursor)
			var finish := Vector2i(interval.x, a.y) if horizontal else Vector2i(a.x, interval.x)
			out.append({"a": start, "b": finish, "length": interval.x - cursor})
		cursor = maxi(cursor, interval.y)
	return out


## 보호 틈의 시작/끝에서 먼저 나눈다. 임의 걸음 두 개가 틈을 과하게 넓히지 않게 한다.
static func _row(side: int, start: int, finish: int, rng: RandomNumberGenerator, profile: PackedInt32Array) -> Array[Dictionary]:
	if finish <= start: return []
	var cuts: Array[int] = [start]
	var previous_zero: bool = profile[start] == 0
	for along: int in range(start + 1, finish):
		var zero: bool = profile[along] == 0
		if zero != previous_zero and along - cuts[-1] >= 8 and finish - along >= 8:
			cuts.append(along)
		previous_zero = zero
	cuts.append(finish)
	var row: Array[Dictionary] = []
	for i: int in range(cuts.size() - 1):
		var along: int = cuts[i]
		for size: int in lengths(cuts[i + 1] - along, rng):
			row.append({"side": side, "from": along, "to": along + size,
				"cap": _cap(profile, along, along + size)})
			along += size
	return row


## 이름 있는 열린 자리는 8~16m 걸음에서 제외된다. 샛길 보호가 있는 판의
## 재시도에서는 그 정확한 끝에서 먼저 자르고 일반 구간만 기존 걸음으로 나눈다.
static func _opening_row(g: FieldGrid, side: int, start: int, finish: int, rng: RandomNumberGenerator, profile: PackedInt32Array, protection: Array[Dictionary]) -> Array[Dictionary]:
	var named := PackedByteArray()
	var guarded := PackedByteArray()
	named.resize(profile.size())
	guarded.resize(profile.size())
	var direction: Vector2i = point(g, side, 1, 0) - point(g, side, 0, 0)
	for item: Dictionary in protection:
		var rect: Rect2i = item["rect"]
		var name: String = String(item.get("open_name", item["kind"]))
		var is_named: bool = name.begins_with("entry/") or name == "road_rail" or name.begins_with("side_path/")
		var low: int = 0
		var high: int = 0
		match side:
			0:
				if rect.position.y != 0: continue
				low = rect.position.x
				high = rect.end.x
			1:
				if rect.end.x != g.width: continue
				low = rect.position.y
				high = rect.end.y
			2:
				if rect.end.y != g.height: continue
				low = g.width - rect.end.x
				high = g.width - rect.position.x
			3:
				if rect.position.x != 0: continue
				low = g.height - rect.end.y
				high = g.height - rect.position.y
		for along: int in range(maxi(start, low), mini(finish, high)):
			guarded[along] = 1
			if is_named: named[along] = 1
	var spans: Array[Vector2i] = []
	for along: int in range(start, finish):
		if named[along] == 0: continue
		var joined: bool = not spans.is_empty() and along - spans[-1].y < 8
		if joined:
			for gap: int in range(spans[-1].y, along):
				var cell: Vector2i = point(g, side, gap, 0)
				if direction.x < 0: cell.x -= 1
				if direction.y < 0: cell.y -= 1
				cell = cell.clamp(Vector2i.ZERO, Vector2i(g.width - 1, g.height - 1))
				if guarded[gap] != 0 or g.walk_people[g.index(cell)] != 1: joined = false
		if joined:
			spans[-1] = Vector2i(spans[-1].x, along + 1)
		else:
			spans.append(Vector2i(along, along + 1))
	var row: Array[Dictionary] = []
	var cursor: int = start
	for span: Vector2i in spans:
		if span.x > cursor and span.x - cursor < 8: return []
		row.append_array(_row(side, cursor, span.x, rng, profile))
		row.append({"side": side, "from": span.x, "to": span.y, "cap": 0})
		cursor = span.y
	if finish > cursor and finish - cursor < 8: return []
	row.append_array(_row(side, cursor, finish, rng, profile))
	return row


## 시계 방향 윤곽의 바깥쪽 방위. 예외는 맞닿은 변 전체의 길이를 기록한다.
static func remote_exceptions(points: Array[Vector2i], forest: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in range(points.size()):
		var a: Vector2i = points[i]
		var b: Vector2i = points[(i + 1) % points.size()]
		var touches: bool = false
		for rect: Rect2i in forest:
			touches = touches or (maxi(a.x, b.x) >= rect.position.x and mini(a.x, b.x) <= rect.end.x \
				and maxi(a.y, b.y) >= rect.position.y and mini(a.y, b.y) <= rect.end.y)
		if not touches:
			continue
		var direction: String = "north" if b.x > a.x else ("east" if b.y > a.y else ("south" if b.x < a.x else "west"))
		out.append({"edge": i, "direction": direction, "name": "edge %d %s" % [i, direction],
			"metres": absi(b.x - a.x) + absi(b.y - a.y), "a": a, "b": b})
	return out


static func outline(data: Dictionary, mask: PackedByteArray, protection: Array[Dictionary] = [], candidate: int = 0, profiles: Array[PackedInt32Array] = []) -> Dictionary:
	var g: FieldGrid = data["grid"]
	if profiles.is_empty(): profiles = limits(g, mask)
	var rng := random_of(String(data["place_id"]))
	if candidate > 0:
		rng.seed = hash(str(rng.seed) + ":candidate:" + str(candidate))
	var corners: Array[int] = [10, 10, 10, 10]
	var form_forest: Array = []
	if data.get("stop_form", "") == "remote" and data.get("stop_old_ground") is Rect2i:
		var old_ground: Rect2i = data["stop_old_ground"]
		for rect: Rect2i in data.get("deep_forest", []):
			if not old_ground.intersects(rect):
				form_forest.append(rect)
	for side: int in 4:
		var length: int = g.width if side % 2 == 0 else g.height
		corners[side] = mini(corners[side], _cap(profiles[side], 0, 26))
		corners[(side + 1) % 4] = mini(corners[(side + 1) % 4], _cap(profiles[side], length - 26, length))
	var rows: Array = []
	var has_side_opening: bool = false
	for item: Dictionary in protection:
		has_side_opening = has_side_opening or String(item.get("open_name", "")).begins_with("side_path/")
	var corner_hits: Array[Dictionary] = []
	for corner_index: int in 4:
		var corner_at := Vector2i(0 if corner_index in [0, 3] else g.width - 10, 0 if corner_index < 2 else g.height - 10)
		var required := Rect2i(corner_at, Vector2i(10, 10))
		for item: Dictionary in protection:
			var overlap: Rect2i = required.intersection(item["rect"])
			if overlap.has_area(): corner_hits.append({"corner": corner_index, "kind": item["kind"], "overlap": overlap})
	for side: int in 4:
		var length: int = g.width if side % 2 == 0 else g.height
		var ending: int = corners[(side + 1) % 4]
		var row: Array[Dictionary] = _row(side, corners[side], length - ending, rng, profiles[side])
		if candidate > 0 and has_side_opening:
			var named_row: Array[Dictionary] = _opening_row(g, side, corners[side], length - ending, rng, profiles[side], protection)
			if not named_row.is_empty(): row = named_row
		var failure: Dictionary = {}
		var picked: Array[int] = depths(row, rng, corners[side], ending, mini(candidate, DEPTH), failure)
		if picked.is_empty() and has_side_opening:
			var exact: Array[Dictionary] = _opening_row(g, side, corners[side], length - ending, rng, profiles[side], protection)
			if not exact.is_empty():
				row = exact
				failure.clear()
				picked = depths(row, rng, corners[side], ending, mini(candidate, DEPTH), failure)
		if picked.is_empty():
			# 모서리를 0으로 낮추어 다른 완료 문에서 탈락시키지 않는다.
			return {"solver_error": "깊이 전이 해 없음", "failed_side": side, "corners": corners, "steps": row,
				"corner10_hits": corner_hits, "depth_failure": failure, "boundary_protection": boundary_protection(g, protection),
				"forced_open_conflicts": forced_open_conflicts(g, protection)}
		for i: int in range(row.size()):
			row[i]["depth"] = picked[i]
		rows.append(row)
	var vertices: Array[Vector2i] = []
	var kinds: Array[String] = []
	var tiles: Array[Dictionary] = []
	var steps: Array[Dictionary] = []
	for side: int in 4:
		var length: int = g.width if side % 2 == 0 else g.height
		var previous: int = corners[side]
		var side_kind: String = "water" if side < 3 else "forest"
		for item: Dictionary in rows[side]:
			var depth: int = int(item["depth"])
			var start: int = int(item["from"])
			var finish: int = int(item["to"])
			if side == 2 and start >= length * 0.15 and depth != previous:
				side_kind = "forest"
			var kind: String = side_kind
			item["kind"] = kind
			steps.append(item)
			previous = depth
			_append(vertices, kinds, point(g, side, start, depth), kind)
			_append(vertices, kinds, point(g, side, finish, depth), kind)
			if depth > 0:
				var tile_start: int = 0 if side % 2 == 0 and start == corners[side] else start
				var tile_end: int = length if side % 2 == 0 and finish == length - corners[(side + 1) % 4] else finish
				tiles.append({"rect": strip(g, side, tile_start, tile_end, depth), "kind": kind})
	# 모서리는 위·아래 첫 걸음 네모에 포함한다. 봉인된 작은 네모는 만들지 않는다.
	if vertices.size() > 1 and vertices[-1] == vertices[0]:
		vertices.pop_back()
		kinds.pop_back()
	# 일직선 꼭짓점만 뺀다. 작은 꺾임의 합산은 직선 시험에서 따로 검사한다.
	var changed: bool = true
	while changed and vertices.size() > 4:
		changed = false
		for i: int in range(vertices.size()):
			var a: Vector2i = vertices[posmod(i - 1, vertices.size())]
			var b: Vector2i = vertices[i]
			var c: Vector2i = vertices[(i + 1) % vertices.size()]
			if (a.x == b.x and b.x == c.x) or (a.y == b.y and b.y == c.y):
				vertices.remove_at(i)
				kinds.remove_at(i)
				changed = true
				break
	var runs: Array[Dictionary] = []
	for i: int in range(vertices.size()):
		if runs.is_empty() or runs[-1]["kind"] != kinds[i]:
			runs.append({"from": i, "to": i + 1, "kind": kinds[i]})
		else:
			runs[-1]["to"] = i + 1
	var gaps: Array[String] = []
	for key: String in data.get("entries", {}):
		gaps.append(key)
	var excluded: int = 0
	var exceptions: Array[Dictionary] = remote_exceptions(vertices, form_forest)
	var openings: Array[Dictionary] = open_exceptions(g, vertices, protection)
	var oversized: Array[Dictionary] = []
	for opening: Dictionary in open_exceptions(g, vertices, protection, maxi(g.width, g.height)):
		if int(opening["metres"]) > 32: oversized.append(opening)
	var exempt_edges: Dictionary = {}
	for exception: Dictionary in exceptions:
		exempt_edges[exception["edge"]] = true
		excluded += int(exception["metres"])
	for opening: Dictionary in openings: exempt_edges[opening["edge"]] = true
	var violations: Array[Dictionary] = []
	for i: int in range(vertices.size()):
		var a: Vector2i = vertices[i]
		var b: Vector2i = vertices[(i + 1) % vertices.size()]
		var metres: int = absi(a.x - b.x) + absi(a.y - b.y)
		if exempt_edges.has(i) or metres <= 24:
			continue
		var kinds_blocking: Array[String] = []
		var area := Rect2i(a.min(b), (b - a).abs()).grow(DEPTH)
		for item: Dictionary in protection:
			if area.intersects(item["rect"]) and not kinds_blocking.has(item["kind"]):
				kinds_blocking.append(item["kind"])
		violations.append({"edge": i, "a": a, "b": b, "metres": metres, "protection": kinds_blocking})
	var result: Dictionary = {"rule": RULE, "made_by": "rule", "outline": vertices, "runs": runs,
		"sides": data.get("map_ring", {}).get("sides", []), "gaps": gaps, "tiles": tiles,
		"corner": corners.min(), "corners": corners, "steps": steps, "exceptions": exceptions, "violations": violations,
		"form_forest": form_forest, "form_forest_m": excluded}
	result["open_exceptions"] = openings
	result["oversized_openings"] = oversized
	result["corner10_hits"] = corner_hits
	return result


## 깊이 0 변에서 이름 있는 보호 사이의 보호 없는 틈만 8m 미만이면 합친다.
## 양 끝 빈칸과 이름 없는 보호는 합치지 않으며 전체 길이에 상한을 건다.
static func open_exceptions(g: FieldGrid, points: Array, protection: Array[Dictionary], maximum: int = 32) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for edge: int in range(points.size()):
		var a: Vector2i = points[edge]
		var b: Vector2i = points[(edge + 1) % points.size()]
		if not ((a.x == b.x and a.x in [0, g.width]) or (a.y == b.y and a.y in [0, g.height])):
			continue
		var metres: int = absi(b.x - a.x) + absi(b.y - a.y)
		if metres > maximum:
			continue
		var names: Array[String] = []
		var covered: bool = true
		var gap: int = 0
		var gap_cells: int = 0
		var direction: Vector2i = Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		for metre: int in range(metres):
			var cell: Vector2i = a + direction * metre
			if direction.x < 0: cell.x -= 1
			if direction.y < 0: cell.y -= 1
			cell = cell.clamp(Vector2i.ZERO, Vector2i(g.width - 1, g.height - 1))
			var hit: bool = false
			var protected_cell: bool = false
			for item: Dictionary in protection:
				if not (item["rect"] as Rect2i).has_point(cell): continue
				protected_cell = true
				var name: String = String(item.get("open_name", item["kind"]))
				if name.begins_with("entry/") or name == "road_rail" or name.begins_with("side_path/"):
					hit = true
					if not names.has(name): names.append(name)
			if hit:
				gap_cells += gap
				gap = 0
			else:
				gap += 1
				if names.is_empty() or protected_cell or gap >= 8 or g.walk_people[g.index(cell)] != 1:
					covered = false
					break
		# 마지막 빈칸은 뒤쪽 이름 있는 보호가 없으므로 내부 틈이 아니다.
		if covered and gap == 0 and metres > 0:
			names.sort()
			var facing: String = ("north" if a.x < b.x else "south") if a.y == b.y else ("east" if a.y < b.y else "west")
			out.append({"edge": edge, "direction": facing, "name": "+".join(names), "metres": metres,
				"a": a, "b": b, "gap_cells": gap_cells})
	return out


## 보호 때문에 깊이 0이어야 하지만 이름 있는 보호로 덮이지 않는 끝칸.
## 보호된 칸은 '보호 없는 걷는 틈'에도 해당하지 않는다. remote 숲 예외는 호출자가 따로 대조한다.
static func forced_open_conflicts(g: FieldGrid, protection: Array[Dictionary]) -> Array[Dictionary]:
	var cells: Dictionary = {}
	for item: Dictionary in boundary_protection(g, protection):
		var rect: Rect2i = item["rect"]
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				var cell: Vector2i = Vector2i(x, y)
				var row: Dictionary = cells.get_or_add(cell, {"cell": cell, "kinds": [], "named": false})
				row["named"] = bool(row["named"]) or bool(item["named"])
				if not row["kinds"].has(item["kind"]): row["kinds"].append(item["kind"])
	var out: Array[Dictionary] = []
	for row: Dictionary in cells.values():
		if not bool(row["named"]): out.append(row)
	return out


static func on_segment(p: Vector2i, a: Vector2i, b: Vector2i) -> bool:
	return (p.x - a.x) * (b.y - a.y) == (p.y - a.y) * (b.x - a.x) and p.x >= mini(a.x, b.x) and p.x <= maxi(a.x, b.x) and p.y >= mini(a.y, b.y) and p.y <= maxi(a.y, b.y)


## 실제 보호가 끝칸까지 닿은 자리. named=false이면 열린 자리 예외로 덮이는지 리드가 대조한다.
static func boundary_protection(g: FieldGrid, protection: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var borders: Array[Rect2i] = [Rect2i(0, 0, g.width, 1), Rect2i(g.width - 1, 0, 1, g.height),
		Rect2i(0, g.height - 1, g.width, 1), Rect2i(0, 0, 1, g.height)]
	for item: Dictionary in protection:
		for side: int in 4:
			var hit: Rect2i = (item["rect"] as Rect2i).intersection(borders[side])
			if hit.has_area(): out.append({"side": side, "kind": item["kind"], "rect": hit,
				"named": String(item["kind"]).begins_with("entry/") or item["kind"] == "road_rail" or String(item.get("open_name", "")).begins_with("side_path/")})
	return out


## 2m 미만 꺾임을 사이에 둔 같은 방향 구간 전체를 누적한다.
static func joined_straight(points: Array, omitted: Dictionary) -> int:
	var longest: int = 0
	for first: int in range(points.size()):
		if omitted.has(first): continue
		var delta: Vector2i = points[(first + 1) % points.size()] - points[first]
		var total: int = absi(delta.x) + absi(delta.y)
		var direction := Vector2i(signi(delta.x), signi(delta.y))
		for offset: int in range(2, points.size(), 2):
			var bend_index: int = (first + offset - 1) % points.size()
			var next_index: int = (first + offset) % points.size()
			var bend: Vector2i = points[next_index] - points[bend_index]
			var next: Vector2i = points[(next_index + 1) % points.size()] - points[next_index]
			if omitted.has(bend_index) or omitted.has(next_index) or absi(bend.x) + absi(bend.y) >= 2 or Vector2i(signi(next.x), signi(next.y)) != direction:
				break
			total += absi(next.x) + absi(next.y)
		longest = maxi(longest, total)
	return longest


## 모양 검사는 도장 이전의 필수 조건이다. 예외를 뺀 길이 >32m인 변만 깊이 변화 >=2.
static func shape_errors(g: FieldGrid, bounds: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	errors.assign(shape_report(g, bounds)["errors"])
	return errors


## 탈락 이유와 판정에 쓴 실제 수를 함께 보존한다.
static func shape_report(g: FieldGrid, bounds: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var report: Dictionary = {"errors": errors, "corners": bounds.get("corners", []), "sides": [], "corner10_hits": bounds.get("corner10_hits", [])}
	if bounds.has("solver_error") or bounds.get("outline", []).is_empty():
		errors.append(String(bounds.get("solver_error", "윤곽 없음")))
		report["failed_side"] = bounds.get("failed_side", -1)
		report["steps"] = bounds.get("steps", [])
		report["depth_failure"] = bounds.get("depth_failure", {})
		report["boundary_protection"] = bounds.get("boundary_protection", [])
		report["forced_open_conflicts"] = bounds.get("forced_open_conflicts", [])
		return report
	report["oversized_openings"] = bounds.get("oversized_openings", [])
	report["violations"] = bounds.get("violations", [])
	report["open_exceptions"] = bounds.get("open_exceptions", [])
	report["remote_exceptions"] = bounds.get("exceptions", [])
	if not report["oversized_openings"].is_empty(): errors.append("열린 자리 32m 초과")
	var points: Array = bounds["outline"]
	var exceptions: Array = bounds.get("exceptions", []) + bounds.get("open_exceptions", [])
	var omitted: Dictionary = {}
	for item: Dictionary in exceptions: omitted[item["edge"]] = true
	for edge: int in range(points.size()):
		var a: Vector2i = points[edge]
		var b: Vector2i = points[(edge + 1) % points.size()]
		if not omitted.has(edge) and ((a.x == b.x and a.x in [0, g.width]) or (a.y == b.y and a.y in [0, g.height])):
			errors.append("이름 없는 열린 자리: edge=%d a=%s b=%s length=%d" % [edge, str(a), str(b), absi(a.x - b.x) + absi(a.y - b.y)])
	var straight: int = joined_straight(points, omitted)
	report["straight_m"] = straight
	if straight > 24: errors.append("직선 24m 초과: %d" % straight)
	var corners: Array[Vector2i] = [Vector2i.ZERO, Vector2i(g.width, 0), Vector2i(g.width, g.height), Vector2i(0, g.height)]
	for side: int in 4:
		var exempt: bool = false
		for item: Dictionary in exceptions:
			exempt = exempt or on_segment(corners[side], item["a"], item["b"])
		var corner: int = bounds["corners"][side]
		if not exempt and (corner < 10 or corner > 25): errors.append("모서리 10~25m 위반: side=%d depth=%d" % [side, corner])
		var measured: int = 0
		var changes: int = 0
		var previous: int = -1
		var neighbour: int = 0
		for step: Dictionary in bounds["steps"]:
			if int(step["side"]) != side: continue
			var a: Vector2i = point(g, side, step["from"], step["depth"])
			var b: Vector2i = point(g, side, step["to"], step["depth"])
			var skip: bool = false
			for item: Dictionary in exceptions:
				skip = skip or (on_segment(a, item["a"], item["b"]) and on_segment(b, item["a"], item["b"]))
			if skip:
				previous = -1
				continue
			var length: int = int(step["to"]) - int(step["from"])
			measured += length
			if length < 8 or length > 16: errors.append("걸음 8~16m 위반: side=%d from=%d length=%d" % [side, step["from"], length])
			var depth: int = step["depth"]
			if previous >= 0:
				neighbour = maxi(neighbour, absi(depth - previous))
				changes += int(previous != depth)
			previous = depth
		if neighbour > 6: errors.append("이웃 차 6m 초과: side=%d delta=%d" % [side, neighbour])
		if measured > 32 and changes < 2: errors.append("변 깊이 변화 2회 미만: side=%d length=%d changes=%d" % [side, measured, changes])
		report["sides"].append({"side": side, "corner_m": corner, "corner_exempt": exempt, "measured_m": measured, "changes": changes, "neighbour_m": neighbour})
	return report


static func _append(vertices: Array[Vector2i], kinds: Array[String], at: Vector2i, kind: String) -> void:
	if vertices.is_empty() or vertices[-1] != at:
		vertices.append(at)
		kinds.append(kind)
	else:
		kinds[-1] = kind
