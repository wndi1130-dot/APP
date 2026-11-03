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
	var target: float = float((g.width + width * 2) * (g.height + width * 2)) * 1.5
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


## 17개 깊이 상태의 동적 계획. 6m 차이는 강제하고 2m 미만 꺾임은 가능한 한 피한다.
static func depths(row: Array[Dictionary], rng: RandomNumberGenerator, first: int, last: int) -> Array[int]:
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
		var wish: int = rng.randi_range(0, cap)
		for depth: int in range(cap + 1):
			if (i == 0 and depth != first) or (i == row.size() - 1 and depth != last):
				continue
			for previous: int in range(maxi(0, depth - 6), mini(DEPTH, depth + 6) + 1):
				var penalty: int = 1000 if i > 0 and absi(previous - depth) < 2 else 0
				var cost: int = costs[previous] + penalty + absi(depth - wish)
				if cost < next[depth]:
					next[depth] = cost
					parent[depth] = previous
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
static func _row(g: FieldGrid, mask: PackedByteArray, side: int, start: int, finish: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var cuts: Array[int] = [start]
	var previous_zero: bool = _limit(g, mask, side, start, start + 1) == 0
	for along: int in range(start + 1, finish):
		var zero: bool = _limit(g, mask, side, along, along + 1) == 0
		if zero != previous_zero and along - cuts[-1] >= 8 and finish - along >= 8:
			cuts.append(along)
		previous_zero = zero
	cuts.append(finish)
	var row: Array[Dictionary] = []
	for i: int in range(cuts.size() - 1):
		var along: int = cuts[i]
		for size: int in lengths(cuts[i + 1] - along, rng):
			row.append({"side": side, "from": along, "to": along + size,
				"cap": _limit(g, mask, side, along, along + size)})
			along += size
	return row


static func outline(data: Dictionary, mask: PackedByteArray, protection: Array[Dictionary] = []) -> Dictionary:
	var g: FieldGrid = data["grid"]
	var rng := random_of(String(data["place_id"]))
	var corners: Array[int] = [10, 10, 10, 10]
	var form_forest: Array = data.get("deep_forest", []).duplicate()
	for side: int in 4:
		var length: int = g.width if side % 2 == 0 else g.height
		corners[side] = mini(corners[side], _limit(g, mask, side, 0, 26))
		corners[(side + 1) % 4] = mini(corners[(side + 1) % 4], _limit(g, mask, side, length - 26, length))
	var rows: Array = []
	for _attempt: int in range(5):
		rows.clear()
		var retry: bool = false
		for side: int in 4:
			var length: int = g.width if side % 2 == 0 else g.height
			var ending: int = corners[(side + 1) % 4]
			var row: Array[Dictionary] = _row(g, mask, side, corners[side], length - ending, rng)
			var picked: Array[int] = depths(row, rng, corners[side], ending)
			if picked.is_empty():
				corners[side] = 0
				corners[(side + 1) % 4] = 0
				retry = true
				break
			for i: int in range(row.size()):
				row[i]["depth"] = picked[i]
			rows.append(row)
		if not retry:
			break
	if rows.size() != 4:
		push_error("보호 칸과 경계 깊이의 해를 찾지 못했습니다")
		return {}
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
	var exceptions: Array[Dictionary] = []
	for i: int in range(vertices.size()):
		var a: Vector2i = vertices[i]
		var b: Vector2i = vertices[(i + 1) % vertices.size()]
		excluded += absi(a.x - b.x) + absi(a.y - b.y)
		for segment: Dictionary in measured_segments(a, b, form_forest):
			excluded -= int(segment["length"])
			if int(segment["length"]) <= 24:
				continue
			var kinds_blocking: Array[String] = []
			var area := Rect2i(segment["a"], segment["b"] - segment["a"]).grow(DEPTH)
			for item: Dictionary in protection:
				if area.intersects(item["rect"]) and not kinds_blocking.has(item["kind"]):
					kinds_blocking.append(item["kind"])
			exceptions.append({"a": segment["a"], "b": segment["b"], "metres": segment["length"],
				"protection": kinds_blocking})
	return {"rule": RULE, "made_by": "rule", "outline": vertices, "runs": runs,
		"sides": data.get("map_ring", {}).get("sides", []), "gaps": gaps, "tiles": tiles,
		"corner": corners.min(), "corners": corners, "steps": steps, "exceptions": exceptions,
		"form_forest": form_forest, "form_forest_m": excluded}


static func _append(vertices: Array[Vector2i], kinds: Array[String], at: Vector2i, kind: String) -> void:
	if vertices.is_empty() or vertices[-1] != at:
		vertices.append(at)
		kinds.append(kind)
	else:
		kinds[-1] = kind
