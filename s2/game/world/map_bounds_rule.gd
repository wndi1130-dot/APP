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


static func outline(data: Dictionary, mask: PackedByteArray) -> Dictionary:
	var g: FieldGrid = data["grid"]
	var rng := random_of(String(data["place_id"]))
	var corner: int = 10
	# 보호 대상이 모서리까지 오는 지도는 깎기 조건을 시험에서 드러낸다.
	for side: int in 4:
		var length: int = g.width if side % 2 == 0 else g.height
		corner = mini(corner, mini(_limit(g, mask, side, 0, 26), _limit(g, mask, side, length - 26, length)))
	var vertices: Array[Vector2i] = []
	var kinds: Array[String] = []
	var tiles: Array[Dictionary] = []
	var steps: Array[Dictionary] = []
	for side: int in 4:
		var length: int = g.width if side % 2 == 0 else g.height
		var along: int = corner
		var previous: int = corner
		var side_kind: String = "water" if side < 3 else "forest"
		var row: Array[Dictionary] = []
		while along < length - corner:
			var remaining: int = length - corner - along
			var step: int = mini(16 if along == corner else rng.randi_range(8, 16), remaining)
			if remaining > step and remaining - step < 8:
				step = remaining - 8
			var depth: int = clampi(previous + (rng.randi_range(2, 6) if rng.randi_range(0, 1) == 0 else -rng.randi_range(2, 6)), 0, DEPTH)
			if along == corner or step == remaining:
				depth = corner
			depth = mini(depth, _limit(g, mask, side, along, along + step))
			if side == 2 and along >= length * 0.15 and depth != previous:
				side_kind = "forest"
			var kind: String = side_kind
			row.append({"side": side, "from": along, "to": along + step, "depth": depth, "kind": kind})
			along += step
			previous = depth
		# 보호 칸 때문에 얕아진 걸음의 앞뒤도 낮춘다. 모서리는 고정하여 연결을 보존한다.
		for _pass_index: int in range(3):
			for i: int in range(1, row.size() - 1):
				row[i]["depth"] = mini(int(row[i]["depth"]), int(row[i - 1]["depth"]) + 6)
			for i: int in range(row.size() - 2, 0, -1):
				row[i]["depth"] = mini(int(row[i]["depth"]), int(row[i + 1]["depth"]) + 6)
		steps.append_array(row)
		for item: Dictionary in row:
			var depth: int = int(item["depth"])
			var start: int = int(item["from"])
			var finish: int = int(item["to"])
			var kind: String = item["kind"]
			_append(vertices, kinds, point(g, side, start, depth), kind)
			_append(vertices, kinds, point(g, side, finish, depth), kind)
			if depth > 0:
				var tile_start: int = 0 if side % 2 == 0 and start == corner else start
				var tile_end: int = length if side % 2 == 0 and finish == length - corner else finish
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
	return {"rule": RULE, "made_by": "rule", "outline": vertices, "runs": runs,
		"sides": data.get("map_ring", {}).get("sides", []), "gaps": gaps, "tiles": tiles, "corner": corner, "steps": steps}


static func _append(vertices: Array[Vector2i], kinds: Array[String], at: Vector2i, kind: String) -> void:
	if vertices.is_empty() or vertices[-1] != at:
		vertices.append(at)
		kinds.append(kind)
	else:
		kinds[-1] = kind
