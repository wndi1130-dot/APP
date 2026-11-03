extends RefCounted
## 보호 칸을 보존하며 지상 경계를 한 번만 찍는다.

const FieldGrid = preload("res://game/world/field_grid.gd")
const Rule = preload("res://game/world/map_bounds_rule.gd")
const StopGround = preload("res://game/world/stop_ground.gd")
const EdgeBand = preload("res://game/world/edge_band.gd")


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
	if not data.has("bounds_stamp"):
		return true
	var requested: int = bounds_rule if bounds_rule >= 0 else int(data.get("bounds", {}).get("rule", 0))
	return int(data["bounds_stamp"]) == requested


static func apply(data: Dictionary, bounds_rule: int = -1) -> Dictionary:
	if not can_reuse(data, bounds_rule):
		push_error("다른 판의 경계는 원본부터 다시 준비해야 합니다")
		return data
	var bounds: Dictionary = data.get("bounds", {})
	var mask := PackedByteArray()
	if bounds.is_empty() and Rule.enabled(String(data.get("place_id", "")), bounds_rule):
		mask = protected_cells(data)
		bounds = Rule.outline(data, mask)
	if bounds.is_empty() or bounds_rule == 0 or bounds.get("rule", 0) == 0:
		return data
	var errors: Array[String] = check(bounds, data["grid"])
	if not errors.is_empty():
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
					push_error("경계가 보호 칸에 닿았습니다")
					return data
	var forest: Array[Rect2i] = []
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
		StopGround.view_forest_trees(data, forest, Rule.random_of(String(data["place_id"])))
		_forest_front(data, forest)
		_remove_trees(data)
	data["bounds_stamp"] = rule
	return data


static func _forest_front(data: Dictionary, forest: Array[Rect2i]) -> void:
	var g: FieldGrid = data["grid"]
	var planted: Dictionary = {}
	for tree: Vector2i in data.get("trees", []):
		planted[tree] = true
	for rect: Rect2i in forest:
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				if planted.has(cell) or posmod(x + y, 2) != 0:
					continue
				for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if g.people_can_walk(cell + direction):
						data["trees"].append(cell)
						planted[cell] = true
						break


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


static func _protect(mask: PackedByteArray, g: FieldGrid, value: Variant, pad: int = 2) -> void:
	if value is Vector3:
		_protect(mask, g, FieldGrid.cell_of(value), pad)
	elif value is Vector2i or value is Vector2:
		_protect(mask, g, Rect2i(Vector2i(value), Vector2i.ONE), pad)
	elif value is Rect2i:
		var rect: Rect2i = value.grow(pad).intersection(Rect2i(0, 0, g.width, g.height))
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				mask[g.index(Vector2i(x, y))] = 1
	elif value is Array:
		for item: Variant in value:
			_protect(mask, g, item, pad)
	elif value is Dictionary:
		for item: Variant in value.values():
			_protect(mask, g, item, pad)


static func protected_cells(data: Dictionary) -> PackedByteArray:
	var g: FieldGrid = data["grid"]
	var mask := PackedByteArray()
	mask.resize(g.width * g.height)
	for key: String in ["train", "platform", "boarding", "unloading", "train_doors", "bands", "side_path", "spots", "stairs", "anchors", "village_middle", "deep_forest"]:
		_protect(mask, g, data.get(key), 2)
	for building: Dictionary in data.get("buildings", []):
		_protect(mask, g, building["rect"], 3)
	for grid: FieldGrid in data.get("levels", {0: g}).values():
		_protect(mask, g, grid.doors.keys(), 5)
		_protect(mask, g, grid.windows.keys(), 5)
	for box: Dictionary in data.get("containers", {}).values():
		_protect(mask, g, box.get("cell"), 3)
	for key: String in data.get("entries", {}):
		if int(data.get("entry_levels", {}).get(key, 0)) != 0 or key in data.get("manholes", {}):
			continue
		for cell: Vector2i in data["entries"][key]:
			var reach: Vector2i = Vector2i(8, 4) if cell.x in [0, g.width - 1] else Vector2i(4, 8)
			_protect(mask, g, Rect2i(cell - reach, reach * 2 + Vector2i.ONE))
	for opening: Dictionary in EdgeBand.openings(g):
		var area: Rect2 = EdgeBand.run_rect(g, opening, 8.0, 3.0)
		_protect(mask, g, Rect2i(area).grow(8), 2)
	return mask


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
