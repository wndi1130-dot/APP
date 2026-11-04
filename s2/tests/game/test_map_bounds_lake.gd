extends "res://addons/gut/test.gd"
## 같은 입력의 판 0/1을 공유하되 시험에서는 공유 자료를 수정하지 않는다.
const Grid = preload("res://game/world/field_grid.gd")
const Maps = preload("res://game/world/field_maps.gd")
const Bounds = preload("res://game/world/map_bounds.gd")
const Rule = preload("res://game/world/map_bounds_rule.gd")
const Shift = preload("res://game/world/map_shift.gd")
const Ground = preload("res://game/world/stop_ground.gd")
const Side = preload("res://game/world/side_path.gd")
const Edge = preload("res://game/world/edge_band.gd")
const Loader = preload("res://game/stop_loader.gd")
const Game = preload("res://game/field_game.gd")
const Save = preload("res://game/sim/field_save.gd")
const Digest = preload("res://tests/game/bounds_digest.gd")
const Work = preload("res://game/world/work_spots.gd")
const Lake = preload("res://game/world/maps/lake_01.gd")
const FORMS: Array[String] = ["", "edge", "remote"]
const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var cases: Dictionary = {}
var cores: Dictionary = {}


func before_all() -> void:
	cores[0] = Maps.build_from(Lake, "", 0)
	cores[1] = Maps.build_from(Lake)
	for form: String in FORMS:
		var base: Dictionary = _direct(form, 71, 0, false)
		_finish(base)
		var active: Dictionary = Loader.make_ready(Lake, 71, form)
		if not active.has("bounds_stamp"):
			print("bounds/attempts form=%s failure=%s\n%s" % [form, active.get("bounds_failure", "도장 없음"), JSON.stringify(active.get("bounds_attempts", []), "\t")])
		var pre: Dictionary = _direct(form, 71, -1, false)
		var g: Grid = pre["grid"]
		cases[form] = {"base": base, "active": active, "pre": pre, "before_solid": g.solid,
			"before_floor": g.floor, "before_anchors": pre["anchors"].duplicate(true),
			"before_middle": pre.get("village_middle"), "before_distance": pre.get("walk_to_village_m"),
			"protected": Bounds.protected_cells(pre), "people": _flood(active, "walk_people"),
			"pre_people": _flood(pre, "walk_people"), "base_people": _flood(base, "walk_people"),
			"dead": _flood(active, "walk_dead"), "digest": Digest.digest(active)}


## 도장이 없는 판 0에 판 1 좌표를 대입하지 않는다. 명시적인 실패와 탈락 요약을 남긴다.
func _require_stamp(data: Dictionary, context: String) -> bool:
	var present: bool = int(data.get("bounds_stamp", 0)) == Rule.RULE
	var reasons: Dictionary = {}
	for attempt: Dictionary in data.get("bounds_attempts", []):
		for reason: String in attempt.get("rejected", []):
			reasons[reason] = int(reasons.get(reason, 0)) + 1
	assert_true(present, "%s: bounds_stamp=%s failure=%s bounds_attempts=%s" % [context,
		str(data.get("bounds_stamp", "없음")), data.get("bounds_failure", ""), str(reasons)])
	return present


func after_all() -> void:
	cases.clear()
	cores.clear()


func _direct(form: String, seed_value: int, rule: int = -1, stamp: bool = true) -> Dictionary:
	var data: Dictionary = _copy_map(cores[0 if rule == 0 else 1])
	data = Ground.apply(data, form, seed_value)
	data = Ground.widen_view(data)
	data = Game.with_side_path(data, seed_value)
	if not stamp: return data
	var base_factory: Callable = func() -> Dictionary: return _direct(form, seed_value, 0, false)
	return Bounds.finish(data, base_factory, rule)


func _copy_map(source: Dictionary) -> Dictionary:
	var copy: Dictionary = source.duplicate(true)
	var levels: Dictionary = {}
	for level: int in source["levels"]:
		var old: Grid = source["levels"][level]
		var grid := Grid.new(old.width, old.height)
		for key: String in Digest.GRID_ARRAYS:
			grid.set(key, old.get(key).duplicate())
		grid.doors = old.doors.duplicate(true)
		grid.windows = old.windows.duplicate(true)
		grid.floor_glass = old.floor_glass.duplicate(true)
		grid.revision = old.revision
		grid.adopt_paths()
		levels[level] = grid
	copy["levels"] = levels
	copy["grid"] = levels[0]
	copy.erase("_walk_key")
	copy.erase("_walk_field")
	return copy


func _finish(data: Dictionary) -> void:
	data["_edge_plan"] = Edge.plan_ahead(data)
	Work.dress(data, -1, 71)
	if data.has("bounds_stamp"): Edge.prepare_bounds_groves(data)


func _changed_items(a: Dictionary, b: Dictionary) -> Array[String]:
	var keys: Dictionary = a.duplicate()
	keys.merge(b)
	var changed: Array[String] = []
	for key: String in keys:
		if not a.has(key) or not b.has(key) or a[key] != b[key]:
			changed.append(key)
	changed.sort()
	return changed


func _flood(data: Dictionary, cache: String) -> PackedByteArray:
	var g: Grid = data["grid"]
	var walk: PackedByteArray = g.get(cache)
	var seen := PackedByteArray()
	seen.resize(walk.size())
	var queue: Array[Vector2i] = []
	for row: Array in data.get("train_doors", {}).values():
		for door: Vector2i in row:
			if queue.is_empty() and g.inside(door) and walk[g.index(door)] == 1:
				queue.append(door)
				seen[g.index(door)] = 1
	var cursor: int = 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		for direction: Vector2i in DIRS:
			var next: Vector2i = cell + direction
			if g.inside(next) and walk[g.index(next)] == 1 and seen[g.index(next)] == 0:
				seen[g.index(next)] = 1
				queue.append(next)
	return seen


func test_a_all_walkable_ground_is_reached() -> void:
	for form: String in FORMS:
		if not _require_stamp(cases[form]["active"], form): continue
		var data: Dictionary = cases[form]["active"]
		var g: Grid = data["grid"]
		var missing: Array[Dictionary] = []
		var old_isolated: Array[Dictionary] = []
		for y: int in range(g.height):
			for x: int in range(g.width):
				var cell := Vector2i(x, y)
				if g.walk_people[g.index(cell)] == 1 and cases[form]["people"][g.index(cell)] == 0:
					if cases[form]["pre_people"][g.index(cell)] != 0:
						missing.append(_cell_info(form, cell))
					else:
						old_isolated.append(_cell_info(form, cell))
		print("bounds/a 경계 전부터 미도달=" + str(old_isolated))
		assert_true(missing.is_empty(), "%s: 미도달=%s 경계 전=%s 보존 통로=%s" % [form, str(missing),
			str(data.get("bounds", {}).get("unreachable_before", [])), str(data.get("bounds", {}).get("protected_routes", []))])


func _cell_info(form: String, cell: Vector2i) -> Dictionary:
	var data: Dictionary = cases[form]["active"]
	var g: Grid = data["grid"]
	var neighbors: Array[Dictionary] = []
	for delta: Vector2i in DIRS:
		var at: Vector2i = cell + delta
		if not g.inside(at):
			continue
		var kind: String = "기존"
		for tile: Dictionary in data.get("bounds", {}).get("tiles", []):
			if (tile["rect"] as Rect2i).has_point(at):
				kind = tile["kind"]
				break
		neighbors.append({"cell": at, "solid": g.solid_at(at), "kind": kind, "building": g.building_at(at)})
	var core_cell: Vector2i = cell - data["map_ring"]["inner"].position
	var base: Dictionary = cases[form]["base"]
	var bg: Grid = base["grid"]
	var base_cell: Vector2i = core_cell + base["map_ring"]["inner"].position
	var boxes: Array[String] = []
	for key: String in data.get("containers", {}):
		var box: Dictionary = data["containers"][key]
		if int(box.get("level", 0)) == 0 and box.get("cell") == cell: boxes.append(key)
	var furniture: Array[String] = []
	for prop: Dictionary in data.get("props", []):
		if int(prop.get("level", 0)) == 0 and prop.get("rect") is Rect2i and (prop["rect"] as Rect2i).has_point(cell):
			furniture.append(String(prop.get("kind", "")))
	return {"cell": cell, "core_cell": core_cell, "building": g.building_at(cell), "boxes": boxes, "furniture_props": furniture,
		"in_original_map": (data["map_ring"]["inner"] as Rect2i).has_point(cell), "base_cell": base_cell,
		"base_walkable": bg.inside(base_cell) and bg.people_can_walk(base_cell),
		"base_reached": int(cases[form]["base_people"][bg.index(base_cell)]) if bg.inside(base_cell) else -1,
		"before_reached": cases[form]["pre_people"][g.index(cell)], "neighbors": neighbors}


func test_b_baseline_functions_and_counts_survive() -> void:
	for form: String in FORMS:
		if not _require_stamp(cases[form]["active"], form): continue
		var base: Dictionary = cases[form]["base"]
		var data: Dictionary = cases[form]["active"]
		var g: Grid = data["grid"]
		var lost: int = 0
		var old: Dictionary = _core_features(base)
		var now: Dictionary = _core_features(data)
		var lost_keys: Array[String] = []
		for key: String in old:
			if _reached(base["grid"], cases[form]["base_people"], old[key]):
				if not now.has(key) or not _reached(g, cases[form]["people"], now.get(key, [])):
					lost += 1
					lost_keys.append(key)
		assert_eq(lost, 0, form + ": 원래 지도 기능 칸 " + str(lost_keys))
		var inner: Rect2i = data["map_ring"]["inner"]
		var old_inner: Rect2i = base["map_ring"]["inner"]
		for key: String in base["containers"]:
			var box: Dictionary = base["containers"][key]
			if not old_inner.has_point(box["cell"]):
				continue
			assert_true(data["containers"].has(key), form + ": 원래 상자 " + key)
			if data["containers"].has(key):
				assert_eq(data["containers"][key]["cell"] - inner.position, box["cell"] - old_inner.position, key)
		for key: String in data["containers"]:
			var box: Dictionary = data["containers"][key]
			if not inner.has_point(box["cell"]) and int(box.get("level", 0)) == 0:
				var points: Dictionary = {}
				_feature(points, key, box["cell"])
				assert_true(_reached(g, cases[form]["people"], points[key]), form + ": 고리 상자 " + key + " " + str(_cell_info(form, box["cell"])))


func _core_features(data: Dictionary) -> Dictionary:
	var all_features: Dictionary = _features(data)
	var out: Dictionary = {}
	var inner: Rect2i = data["map_ring"]["inner"]
	for key: String in all_features:
		var cells: Array[Vector2i] = []
		for cell: Vector2i in all_features[key]:
			if inner.has_point(cell):
				cells.append(cell)
		if not cells.is_empty():
			out[key] = cells
	return out


func _features(data: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in ["buildings", "containers", "stairs", "train", "platform", "boarding", "unloading",
			"train_doors", "bands", "entries", "side_path", "spots", "anchors", "village_middle"]:
		_feature(out, key, data.get(key))
	return out


func _feature(out: Dictionary, key: String, value: Variant) -> void:
	if value is Vector2i or value is Vector2:
		var cell := Vector2i(value)
		out[key] = [cell, cell + Vector2i.LEFT, cell + Vector2i.RIGHT, cell + Vector2i.UP, cell + Vector2i.DOWN]
	elif value is Vector3:
		_feature(out, key, Grid.cell_of(value))
	elif value is Rect2i:
		var cells: Array[Vector2i] = []
		for y: int in range(value.position.y - 1, value.end.y + 1):
			for x: int in range(value.position.x - 1, value.end.x + 1):
				cells.append(Vector2i(x, y))
		out[key] = cells
	elif value is Array:
		for i: int in range(value.size()):
			_feature(out, key + "/" + str(i), value[i])
	elif value is Dictionary:
		for child: Variant in value:
			_feature(out, key + "/" + str(child), value[child])


func _reached(g: Grid, seen: PackedByteArray, cells: Array) -> bool:
	for cell: Vector2i in cells:
		if g.inside(cell) and seen[g.index(cell)] == 1:
			return true
	return false


func test_c_entries_reach_horde_home_on_dead_cache() -> void:
	for form: String in FORMS:
		if not _require_stamp(cases[form]["active"], form): continue
		var d: Dictionary = cases[form]["active"]
		var g: Grid = d["grid"]
		var seen: PackedByteArray = cases[form]["dead"]
		for key: String in d["entries"]:
			if int(d.get("entry_levels", {}).get(key, 0)) != 0 or key in d.get("manholes", {}):
				continue
			for cell: Vector2i in d["entries"][key]:
				assert_eq(g.walk_dead[g.index(cell)], 1, form + ": 진입로 자체")
				assert_eq(seen[g.index(cell)], 1, form + ": 진입로 연결")
		for key: String in ["horde_home", "horde_home_upper"]:
			if d["anchors"].get(key) is Vector2i:
				assert_eq(seen[g.index(d["anchors"][key])], 1, form + ": " + key)


func test_d_derived_positions_are_not_reselected() -> void:
	for form: String in FORMS:
		if not _require_stamp(cases[form]["active"], form): continue
		var row: Dictionary = cases[form]
		var data: Dictionary = row["active"]
		assert_eq(data["anchors"], row["before_anchors"], form)
		assert_eq(data.get("village_middle"), row["before_middle"], form)
		assert_eq(data.get("walk_to_village_m"), row["before_distance"], form)


func test_e_outside_blocked_inside_and_protection_unchanged() -> void:
	for form: String in FORMS:
		if not _require_stamp(cases[form]["active"], form): continue
		var row: Dictionary = cases[form]
		var data: Dictionary = row["active"]
		var g: Grid = data["grid"]
		assert_eq(data.get("bounds_stamp", 0), 1, form)
		assert_true(Bounds.check(data.get("bounds", {}), g).is_empty(), form)
		var polygon: Array = data.get("bounds", {}).get("outline", [])
		var painted: Dictionary = {}
		for tile: Dictionary in data.get("bounds", {}).get("tiles", []):
			var rect: Rect2i = tile["rect"]
			for y: int in range(rect.position.y, rect.end.y):
				for x: int in range(rect.position.x, rect.end.x): painted[Vector2i(x, y)] = true
		var regressions: Array[Vector2i] = []
		regressions.assign([Vector2i(137, 104)] if form == "edge" else [Vector2i(114, 43), Vector2i(350, 161)])
		if form != "":
			for cell: Vector2i in regressions: assert_true(_inside_cell(cell, polygon), form + ": 내부 회귀 " + str(cell))
		var failures: int = 0
		var details: Array[Dictionary] = []
		for y: int in range(g.height):
			for x: int in range(g.width):
				var cell := Vector2i(x, y)
				var i: int = g.index(cell)
				var was: int = failures
				var inside: bool = _inside_cell(cell, polygon)
				failures += int(inside == painted.has(cell))
				if inside:
					failures += int(g.solid[i] != row["before_solid"][i] or g.floor[i] != row["before_floor"][i])
				else:
					failures += int(g.walk_people[i] != 0 or g.walk_dead[i] != 0 or row["protected"][i] != 0)
				failures += int(g.people_path.is_point_solid(cell) != (g.walk_people[i] == 0))
				failures += int(g.dead_path.is_point_solid(cell) != (g.walk_dead[i] == 0))
				if failures != was and details.size() < 24:
					var info: Dictionary = _cell_info(form, cell)
					info.merge({"inside": inside, "solid_before": row["before_solid"][i], "solid_after": g.solid[i],
						"floor_before": row["before_floor"][i], "floor_after": g.floor[i], "protected": row["protected"][i],
						"people_cache": g.walk_people[i], "people_solid": g.people_path.is_point_solid(cell),
						"dead_cache": g.walk_dead[i], "dead_solid": g.dead_path.is_point_solid(cell)})
					details.append(info)
		assert_eq(failures, 0, form + ": 안팎/보호/두 길찾기 " + str(details))


## 직각 윤곽의 세로 변만 센다. 중심은 홀수, 꼭짓점은 짝수여서 경계 동률이 없다.
func _inside_cell(cell: Vector2i, points: Array) -> bool:
	var center: Vector2i = cell * 2 + Vector2i.ONE
	var crossings: int = 0
	for edge: int in range(points.size()):
		var a: Vector2i = points[edge] * 2
		var b: Vector2i = points[(edge + 1) % points.size()] * 2
		if a.x == b.x and a.x > center.x and center.y > mini(a.y, b.y) and center.y < maxi(a.y, b.y):
			crossings += 1
	return crossings % 2 == 1


func test_f_steps_corners_and_straight_limit() -> void:
	for form: String in FORMS:
		if not _require_stamp(cases[form]["active"], form): continue
		var data: Dictionary = cases[form]["active"]
		var g: Grid = data["grid"]
		var b: Dictionary = data.get("bounds", {})
		var points: Array = b.get("outline", [])
		var form_forest: Array = []
		var pre: Dictionary = cases[form]["pre"]
		if form == "remote" and pre.get("stop_form", "") == "remote" and pre.get("stop_old_ground") is Rect2i:
			var old_ground: Rect2i = pre["stop_old_ground"]
			for rect: Rect2i in pre.get("deep_forest", []):
				if not old_ground.intersects(rect):
					form_forest.append(rect)
		# 생성기의 예외 함수나 bounds.form_forest를 기준으로 삼지 않고 찍기 전 자료에서 다시 센다.
		var expected: Array[Dictionary] = _expected_remote_edges(points, form_forest)
		var actual: Array = b.get("exceptions", [])
		var protection: Array[Dictionary] = []
		Bounds.protected_cells(pre, protection)
		var expected_open: Array[Dictionary] = _expected_open_edges(g, points, protection)
		for opening: Dictionary in _expected_open_edges(g, points, protection, maxi(g.width, g.height)):
			assert_lte(int(opening["metres"]), 32, form + ": 너무 긴 보호 틈은 예외 불가 " + str(opening))
		var actual_open: Array = b.get("open_exceptions", [])
		var verified: bool = actual == expected and b.get("form_forest", []) == form_forest
		verified = verified and expected_open == actual_open
		assert_eq(actual_open, expected_open, form + ": 열린 자리 보호 자료 대조")
		assert_true(verified, "%s: 예외 명단 expected=%s actual=%s" % [form, str(expected), str(actual)])
		var checked: Array[Dictionary] = []
		if verified:
			checked.assign(actual)
			checked.append_array(actual_open)
		var omitted_edges: Dictionary = {}
		var excluded: int = 0
		for exception: Dictionary in checked:
			omitted_edges[exception["edge"]] = true
			excluded += int(exception["metres"])
		print("예외: %s remote 통로 숲=%s / 열린 자리=%s / 합계 %dm" % [form, str(actual), str(actual_open), excluded])
		print("bounds/f violations=" + str(b.get("violations", [])))
		var corner_points: Array[Vector2i] = [Vector2i.ZERO, Vector2i(g.width, 0), Vector2i(g.width, g.height), Vector2i(0, g.height)]
		for i: int in 4:
			var omitted: bool = false
			var at: Vector2i = corner_points[i]
			for exception: Dictionary in checked:
				omitted = omitted or _on_segment(at, exception["a"], exception["b"])
			if not omitted:
				assert_between(int(b.get("corners", [0, 0, 0, 0])[i]), 10, 25, form + ": 모서리 " + str(at))
		assert_gt(points.size(), 8, form)
		for side: int in 4:
			var previous: int = -1
			var changes: int = 0
			var measured: int = 0
			for step: Dictionary in b.get("steps", []):
				if int(step["side"]) != side:
					continue
				var a: Vector2i = Rule.point(g, side, step["from"], step["depth"])
				var z: Vector2i = Rule.point(g, side, step["to"], step["depth"])
				var omitted: bool = false
				for exception: Dictionary in checked:
					omitted = omitted or (_on_segment(a, exception["a"], exception["b"]) and _on_segment(z, exception["a"], exception["b"]))
				if omitted:
					previous = -1
					continue
				measured += int(step["to"]) - int(step["from"])
				assert_between(int(step["to"]) - int(step["from"]), 8, 16, form)
				if previous >= 0:
					assert_lte(absi(int(step["depth"]) - previous), 6, form + ": 이웃 깊이")
					changes += int(int(step["depth"]) != previous)
				previous = int(step["depth"])
			# 코디 판정 ④: 예외를 뺀 길이가 32m 넘는 변에만 깊이 변화 >=2.
			if measured > 32:
				assert_gte(changes, 2, form + ": 변마다 깊이 변화 side=" + str(side))
		for i: int in range(points.size()):
			if omitted_edges.has(i):
				continue
			var delta: Vector2i = points[(i + 1) % points.size()] - points[i]
			var length: int = absi(delta.x) + absi(delta.y)
			assert_lte(length, 24, "%s: 윤곽 변 %d %s→%s violations=%s" % [form, i, str(points[i]),
				str(points[(i + 1) % points.size()]), str(b.get("violations", []))])
		assert_lte(_max_joined(points, omitted_edges), 24, form + ": 같은 방향 전체 누적")
		var forest_m: int = 0
		for item: Dictionary in expected: forest_m += int(item["metres"])
		assert_eq(forest_m, int(b.get("form_forest_m", 0)), form + ": 기존 숲 제외 길이")
	var stair: Array[Vector2i] = [Vector2i(0, 0), Vector2i(12, 0), Vector2i(12, 1), Vector2i(24, 1), Vector2i(24, 2), Vector2i(36, 2), Vector2i(36, 20), Vector2i(0, 20)]
	assert_eq(_max_joined(stair, {6: true}), 36, "12+12+12m 전체 누적")
	assert_eq(_max_joined(stair, {3: true, 6: true}), 24, "검증된 예외에서 끊음")


func _max_joined(points: Array, omitted: Dictionary) -> int:
	var maximum: int = 0
	for start: int in range(points.size()):
		var axis: Vector2i = points[(start + 1) % points.size()] - points[start]
		var sum: int = 0
		for offset: int in range(points.size()):
			var edge: int = (start + offset) % points.size()
			if omitted.has(edge): break
			var delta: Vector2i = points[(edge + 1) % points.size()] - points[edge]
			var length: int = absi(delta.x) + absi(delta.y)
			if offset % 2 == 1:
				if length >= 2: break
			elif delta.x * axis.x + delta.y * axis.y > 0:
				sum += length
			else:
				break
		maximum = maxi(maximum, sum)
	return maximum


## 보호 네모를 경계 칸 표로 펼쳐 생성기의 구간 계산과 독립 대조한다.
func _expected_open_edges(g: Grid, points: Array, protection: Array[Dictionary], maximum: int = 32) -> Array[Dictionary]:
	var names_by_cell: Dictionary = {}
	for item: Dictionary in protection:
		var name: String = item["kind"]
		if not (name.begins_with("entry/") or name == "road_rail"): continue
		var rect: Rect2i = item["rect"]
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				if x in [0, g.width - 1] or y in [0, g.height - 1]:
					names_by_cell.get_or_add(Vector2i(x, y), {})[name] = true
	var expected: Array[Dictionary] = []
	for edge: int in range(points.size()):
		var a: Vector2i = points[edge]
		var b: Vector2i = points[(edge + 1) % points.size()]
		var horizontal: bool = a.y == b.y
		if not ((horizontal and a.y in [0, g.height]) or (not horizontal and a.x in [0, g.width])): continue
		var length: int = absi(b.x - a.x) + absi(b.y - a.y)
		if length > maximum: continue
		var names: Dictionary = {}
		var covered: int = 0
		for along: int in range(mini(a.x, b.x) if horizontal else mini(a.y, b.y), maxi(a.x, b.x) if horizontal else maxi(a.y, b.y)):
			var cell := Vector2i(along, mini(a.y, g.height - 1)) if horizontal else Vector2i(mini(a.x, g.width - 1), along)
			if names_by_cell.has(cell):
				covered += 1
				names.merge(names_by_cell[cell])
		if covered == length and length > 0:
			var sorted_names: Array = names.keys()
			sorted_names.sort()
			var direction: String = ("north" if a.x < b.x else "south") if horizontal else ("east" if a.y < b.y else "west")
			expected.append({"edge": edge, "direction": direction, "name": "+".join(sorted_names), "metres": length, "a": a, "b": b})
	return expected


func _expected_remote_edges(points: Array, forest: Array) -> Array[Dictionary]:
	var expected: Array[Dictionary] = []
	for i: int in range(points.size()):
		var a: Vector2i = points[i]
		var b: Vector2i = points[(i + 1) % points.size()]
		var hit: bool = false
		for rect: Rect2i in forest:
			if a.y == b.y:
				hit = hit or (a.y >= rect.position.y and a.y <= rect.end.y \
					and maxi(mini(a.x, b.x), rect.position.x) <= mini(maxi(a.x, b.x), rect.end.x))
			else:
				hit = hit or (a.x >= rect.position.x and a.x <= rect.end.x \
					and maxi(mini(a.y, b.y), rect.position.y) <= mini(maxi(a.y, b.y), rect.end.y))
		if hit:
			var direction: String = ("north" if a.x < b.x else "south") if a.y == b.y else ("east" if a.y < b.y else "west")
			expected.append({"edge": i, "direction": direction, "name": "edge %d %s" % [i, direction],
				"metres": absi(a.x - b.x) + absi(a.y - b.y), "a": a, "b": b})
	return expected


func _on_segment(point: Vector2i, a: Vector2i, b: Vector2i) -> bool:
	return (point.x - a.x) * (b.y - a.y) == (point.y - a.y) * (b.x - a.x) \
		and point.x >= mini(a.x, b.x) and point.x <= maxi(a.x, b.x) \
		and point.y >= mini(a.y, b.y) and point.y <= maxi(a.y, b.y)


func test_g_water_terrain_mix() -> void:
	for form: String in FORMS:
		if not _require_stamp(cases[form]["active"], form): continue
		var data: Dictionary = cases[form]["active"]
		var g: Grid = data["grid"]
		var b: Dictionary = data.get("bounds", {})
		var points: Array = b.get("outline", [])
		var lengths: Dictionary = {"water": 0.0, "forest": 0.0}
		var gaps: Dictionary = {}
		for opening: Dictionary in Edge.openings(g):
			for along: int in range(int(opening["from"]), int(opening["to"]) + 1):
				gaps[Edge._edge_cell(g, int(opening["side"]), along)] = true
		for key: String in b.get("gaps", []):
			for cell: Vector2i in data.get("entries", {}).get(key, []):
				gaps[cell] = true
		for run: Dictionary in b.get("runs", []):
			for i: int in range(run["from"], run["to"]):
				var a := Vector2(points[i])
				var delta: Vector2 = Vector2(points[(i + 1) % points.size()]) - a
				var direction: Vector2 = delta.normalized()
				for metre: int in range(roundi(delta.length())):
					var at: Vector2 = a + direction * (float(metre) + 0.5) + Vector2(-direction.y, direction.x) * 0.5
					if not gaps.has(Vector2i(floori(at.x), floori(at.y))):
						lengths[run["kind"]] = float(lengths.get(run["kind"], 0.0)) + 1.0
		var total: float = float(lengths["water"]) + float(lengths["forest"])
		assert_gt(total, 0.0, form)
		assert_gte(float(lengths["water"]) / maxf(total, 1.0), 0.5, form + ": 물 30% 및 지형 50%")
		assert_eq(lengths.size(), 2, form + ": 벽 없음")


func test_h_newly_blocked_share() -> void:
	for form: String in FORMS:
		if not _require_stamp(cases[form]["active"], form): continue
		var row: Dictionary = cases[form]
		var d: Dictionary = row["active"]
		var g: Grid = d["grid"]
		var count: int = 0
		for i: int in range(g.solid.size()):
			count += int(row["before_solid"][i] == Grid.Solid.NONE and g.solid[i] != Grid.Solid.NONE)
		assert_eq(count, int(d.get("bounds_blocked", -1)), form)
		assert_lte(float(count) / float(g.width * g.height), 0.18, form)


func test_i_walkable_area_and_ring_area() -> void:
	for form: String in FORMS:
		if not _require_stamp(cases[form]["active"], form): continue
		var d: Dictionary = cases[form]["active"]
		var g: Grid = d["grid"]
		var bg: Grid = cases[form]["base"]["grid"]
		var numerator: int = g.walk_people.count(1)
		var denominator: int = bg.walk_people.count(1)
		var blocked: int = int(d.get("bounds_blocked", 0))
		var cells: int = g.width * g.height
		var metrics: String = "%s walk=%d/%d ratio=%.9f blocked=%d/%d share=%.9f" % [form,
			numerator, denominator, float(numerator) / denominator, blocked, cells, float(blocked) / cells]
		print("bounds/i " + metrics)
		var new_numerator: int = _playable_walk(d)
		var new_denominator: int = _playable_walk(cases[form]["base"])
		print("잣대 바꿈 — 코디 판정 ② 11-04, 통로 띠 칸 뺌, 옛 셈 %.9f (%d/%d) / 새 셈 %.9f (%d/%d) form=%s" % [float(numerator) / denominator, numerator, denominator, float(new_numerator) / new_denominator, new_numerator, new_denominator, form])
		assert_gte(float(new_numerator) / new_denominator, 1.25, metrics)
		var sides: Array = d["map_ring"]["sides"]
		var area: int = (170 + sides[0] + sides[2]) * (106 + sides[1] + sides[3])
		print("bounds/ring form=%s sides=%s cells=%d" % [form, str(sides), area])
		assert_between(float(area) / (210.0 * 146.0), 1.55 * 0.97, 1.55 * 1.03, form)


func _playable_walk(data: Dictionary) -> int:
	var g: Grid = data["grid"]
	var total: int = 0
	var area: Rect2i = data.get("stop_old_ground", Rect2i(0, 0, g.width, g.height))
	for index: int in range(g.walk_people.size()):
		var cell := Vector2i(index % g.width, floori(float(index) / g.width))
		if area.has_point(cell): total += int(g.walk_people[index] == 1)
	return total


func test_j_forest_union_front_and_plan_key() -> void:
	for form: String in FORMS:
		if not _require_stamp(cases[form]["active"], form): continue
		var d: Dictionary = cases[form]["active"]
		var g: Grid = d["grid"]
		var forest: Array = []
		var covered: Dictionary = {}
		var union_errors: Array[Vector2i] = []
		var tree_cells: Dictionary = {}
		for tree: Vector2i in d.get("trees", []):
			tree_cells[tree] = true
		for tile: Dictionary in d.get("bounds", {}).get("tiles", []):
			if tile["kind"] != "forest":
				continue
			var rect: Rect2i = tile["rect"]
			forest.append(rect)
			assert_true(rect in d["deep_forest"], form)
			for y: int in range(rect.position.y, rect.end.y):
				for x: int in range(rect.position.x, rect.end.x):
					var cell := Vector2i(x, y)
					if covered.has(cell) or g.solid[g.index(cell)] != Grid.Solid.BLOCK:
						union_errors.append(cell)
					covered[cell] = true
		assert_true(union_errors.is_empty(), form + ": 숲 합집합 " + str(union_errors))
		assert_lte(forest.size(), 48, form)
		for border: Dictionary in Edge._forest_borders(g, forest):
			assert_false(border["edges"].is_empty(), form + ": 봉인 네모 없음")
		for cell: Vector2i in covered:
			var front: bool = false
			for direction: Vector2i in DIRS:
				front = front or g.people_can_walk(cell + direction)
			if not front:
				continue
			var close: bool = false
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					close = close or tree_cells.has(cell + Vector2i(dx, dy))
			if not close:
				var nearest: float = INF
				for tree: Vector2i in tree_cells:
					nearest = minf(nearest, Vector2(cell).distance_to(Vector2(tree)))
				assert_lte(nearest, 1.5, form + ": 앞줄 빈틈 cell=" + str(cell))
		assert_eq(d["_edge_plan"]["key"], Edge.plan_key(g, Edge.seed_of(d), Edge.look_of(d), d.get("deep_forest", []), d.get("bounds", {})), form)


func test_k1_k2_repeat_and_direct_path_match() -> void:
	for form: String in FORMS:
		if not _require_stamp(cases[form]["active"], form): continue
		var first: Dictionary = cases[form]["active"]
		# cores와 make_ready는 각각 독립해서 지었다. 준비된 직접 경로의 사본만 찍는다.
		var direct: Dictionary = Bounds.apply(_copy_map(cases[form]["pre"]), -1, _playable_walk(cases[form]["base"]))
		_finish(direct)
		var changed: Array[String] = _changed_items(Digest.digest(direct), cases[form]["digest"])
		assert_true(changed.is_empty(), form + ": 반복/직접 시작 changed=" + str(changed))
		var dg: Grid = direct["grid"]
		var fg: Grid = first["grid"]
		for key: String in Digest.GRID_ARRAYS:
			assert_eq(dg.get(key), fg.get(key), form + ": 직접 시작 " + key)
		if not _require_stamp(direct, form + ": 직접"): continue
		assert_eq(direct.get("bounds", {}), first.get("bounds", {}), form)
		assert_eq(direct["_edge_plan"]["key"], first["_edge_plan"]["key"], form)


func test_k3_save_resume_preserves_grid_outline_and_stamp() -> void:
	if not _require_stamp(cases[""]["active"], "저장 전"): return
	var game = Game.new()
	game.opts = {"seed": 71, "place": "lake_01", "auto_pause": false, "bounds_rule": 1}
	game.opts["map_data"] = _copy_map(cases[""]["active"])
	game.map_script = Lake
	add_child_autofree(game)
	game.set_process(false)
	if not _require_stamp(game.data, "저장 직전 게임"): return
	var saved: Dictionary = Save.from_json(Save.to_json(Save.capture(game)))
	assert_false(saved.is_empty())
	var resumed = Game.new()
	resumed.opts = Save.resume_opts(saved)
	resumed.opts["map_data"] = _copy_map(cases[""]["active"])
	resumed.map_script = Lake
	add_child_autofree(resumed)
	resumed.set_process(false)
	Save.apply(resumed, saved)
	assert_eq(resumed.grid.solid, game.grid.solid)
	assert_eq(resumed.data.get("bounds", {}), game.data.get("bounds", {}))
	_require_stamp(resumed.data, "재개")
	assert_eq(resumed.data.get("bounds_stamp", -1), game.data.get("bounds_stamp", -2))


func test_k4_missing_save_rule_rebuilds_zero() -> void:
	var opts: Dictionary = Save.resume_opts({"phase": "field", "place": "lake_01", "seed": 71})
	assert_eq(opts["bounds_rule"], 0)
	var rebuilt: Dictionary = _direct("", 71, int(opts["bounds_rule"]))
	_finish(rebuilt)
	assert_eq(Digest.digest(rebuilt), Digest.digest(cases[""]["base"]))
	assert_false(rebuilt.has("bounds_stamp"))
	assert_eq(rebuilt["map_ring"]["sides"], [20, 20, 20, 20])


func test_k5_side_path_absent_present_and_north_west_shift() -> void:
	var absent_seed: int = 1
	for candidate: int in range(1, 65):
		if not Side.rolls("lake_01", candidate):
			absent_seed = candidate
			break
	var without: Dictionary = Game.with_side_path(_copy_map(cores[1]), absent_seed)
	assert_false(without.has("side_path"))
	var present_seed: int = -1
	for candidate: int in range(1, 65):
		if Side.rolls("lake_01", candidate):
			present_seed = candidate
			break
	assert_gt(present_seed, 0)
	var natural: Dictionary = Game.with_side_path(_copy_map(cores[1]), present_seed)
	assert_true(natural.has("side_path"), "자연 선택 방향=" + str(natural.get("side_path", {})))
	# 북/서만 실제 후보가 되도록 사본을 구성하고 add의 확률·자리·건물 난수를 모두 지난다.
	for side: int in [0, 3]:
		var probe: Dictionary = _copy_map(cores[1])
		var pg: Grid = probe["grid"]
		for other: int in 4:
			if other == side: continue
			var length: int = pg.height if other % 2 == 1 else pg.width
			for along: int in range(length): pg.set_solid(Side._at(pg, other, along, 0), Grid.Solid.BLOCK)
		# 열린 통로 100m는 40~60초의 실제 선택 범위 안이다.
		for along: int in range(34, 54):
			for depth: int in range(101):
				var cell: Vector2i = Side._at(pg, side, along, depth)
				pg.set_solid(cell, Grid.Solid.NONE)
				pg.floor[pg.index(cell)] = Grid.Floor.SNOW
				pg.building[pg.index(cell)] = -1
		var start: Vector2i = Side._at(pg, side, 44, 100)
		probe["train_doors"] = {"fixture": [start]}
		probe["spawns"]["train_door"] = [start]
		probe["edge_water"] = []
		pg.refresh_paths()
		var old: Dictionary = probe["containers"].duplicate(true)
		var train: Rect2i = probe["train"]
		var shift: Vector2i = Vector2i(Side.STRIP, 0) if side == 3 else Vector2i(0, Side.STRIP)
		probe = Side.add(probe, present_seed)
		assert_eq(int(probe.get("side_path", {}).get("side", -1)), side, "실제 Side.add 방향")
		var before: Dictionary = _copy_map(probe)
		var before_reached: PackedByteArray = _flood(before, "walk_people")
		var protection: PackedByteArray = Bounds.protected_cells(before)
		Bounds.apply(probe)
		if not _require_stamp(probe, "북/서 샛길"): continue
		assert_eq(probe["train"].position, train.position + shift)
		for key: String in old:
			assert_eq(probe["containers"][key]["cell"], old[key]["cell"] + shift, key)
		assert_true(Bounds.check(probe.get("bounds", {}), probe["grid"]).is_empty())
		var final_grid: Grid = probe["grid"]
		var after_reached: PackedByteArray = _flood(probe, "walk_people")
		var bad: int = 0
		for i: int in range(final_grid.walk_people.size()):
			var cell := Vector2i(i % final_grid.width, floori(float(i) / final_grid.width))
			var inside: bool = _inside_cell(cell, probe.get("bounds", {}).get("outline", []))
			if protection[i] != 0: bad += int(not inside or final_grid.solid[i] != before["grid"].solid[i])
			if not inside: bad += int(final_grid.walk_people[i] != 0 or final_grid.walk_dead[i] != 0)
			if before_reached[i] == 1 and final_grid.walk_people[i] == 1: bad += int(after_reached[i] != 1)
		assert_eq(bad, 0, "북/서 실제 추가의 보호·도달·안팎")


func test_k6_failed_solver_rebuilds_original_zero() -> void:
	var fail: Callable = func(_data: Dictionary, _mask: PackedByteArray, _protection: Array[Dictionary]) -> Dictionary: return {}
	for form: String in FORMS:
		var loaded: Dictionary = Loader.make_ready(Lake, 71, form, -1.0, "", -1, fail)
		assert_true(loaded.has("bounds_failure"), form + ": 실패 명시")
		assert_false(loaded.has("bounds_stamp"), form)
		assert_eq(Digest.digest(loaded), Digest.digest(cases[form]["base"]), form + ": 원본 판 0 재생성 지문")
		assert_false(Bounds.can_reuse(cases[form]["pre"], 0), "큰 고리를 판 0으로 재사용 금지")
		var factory: Callable = func() -> Dictionary: return _direct(form, 71, 0, false)
		var direct: Dictionary = Bounds.finish(_copy_map(cases[form]["pre"]), factory, -1, fail)
		_finish(direct)
		assert_eq(Digest.digest(direct), Digest.digest(cases[form]["base"]), form + ": 직접 경로 실패 지문")


func test_l_grove_count_and_reachable_stands() -> void:
	for form: String in FORMS:
		if not _require_stamp(cases[form]["active"], form): continue
		var data: Dictionary = cases[form]["active"].duplicate(true)
		var base: Dictionary = cases[form]["base"].duplicate(true)
		var groves: Array = Edge.fell_groves(data["grid"], data["_edge_plan"]["plan"], data)
		var old: Array = Edge.fell_groves(base["grid"], base["_edge_plan"]["plan"], base)
		assert_gte(groves.size(), old.size(), "%s: 이전=%s 이후=%s" % [form, str(old), str(groves)])
		var owners: Dictionary = {}
		var duplicate_cells: Array[Vector2i] = []
		var all_groves: Array = data.get("fell_groves", []) + groves
		for grove: Dictionary in all_groves:
			var own: Dictionary = {}
			for cell: Vector2i in grove.get("cells", []):
				if owners.has(cell) and not own.has(cell): duplicate_cells.append(cell)
				own[cell] = true
				owners[cell] = true
		assert_true(duplicate_cells.is_empty(), form + ": 전체 벌목지 나무 중복=" + str(duplicate_cells))
		assert_eq(data.get("_bounds_groves", []), Edge._bounds_groves(data["grid"], data), form + ": 일꾼 준비 결과")
		for grove: Dictionary in groves:
			assert_false(grove["stand"].is_empty())
			for at: Vector2i in grove["stand"]:
				assert_eq(cases[form]["people"][data["grid"].index(at)], 1, form + ": 벌목지=" + str(grove) + " stand=" + str(at))


func test_m_water_masks_and_upper_floor_outside() -> void:
	for form: String in FORMS:
		if not _require_stamp(cases[form]["active"], form): continue
		var data: Dictionary = cases[form]["active"]
		var g: Grid = data["grid"]
		var bounds: Dictionary = data.get("bounds", {})
		var bad: int = 0
		var regions: PackedByteArray = data.get("bounds_water_regions", PackedByteArray())
		assert_eq(regions.size(), g.width * g.height, form + ": 물 영역 마스크")
		if regions.size() != g.width * g.height: return
		var shore: int = 0
		var bottom: int = 0
		var water_cells: Dictionary = {}
		for cell: Vector2i in data.get("trees", []):
			bad += int(Edge.bounds_skip(g, bounds, Vector2(cell) + Vector2.ONE * 0.5))
		for tree: Dictionary in data["_edge_plan"]["plan"]["trees"]:
			if not tree.get("skip", false):
				bad += int(Edge.bounds_skip(g, bounds, Vector2(tree["at"].x, tree["at"].z)))
		for tile: Dictionary in bounds.get("tiles", []):
			var rect: Rect2i = tile["rect"]
			if tile["kind"] == "water":
				var found_prop: bool = false
				for prop: Dictionary in data.get("props", []):
					found_prop = found_prop or (prop.get("kind") == "water" and prop.get("rect") == rect)
				assert_true(found_prop, form + ": 물 네모 소품")
				assert_false(rect in data.get("low_blocks", []), form + ": 회색 낮은 상자 제외")
			for y: int in range(rect.position.y, rect.end.y):
				for x: int in range(rect.position.x, rect.end.x):
					if tile["kind"] == "water":
						var cell := Vector2i(x, y)
						water_cells[cell] = true
						var index: int = g.index(cell)
						bad += int(g.solid[index] != Grid.Solid.LOW or g.opq[index] != 0 or g.floor[index] != Grid.Floor.ICE)
						var near_outline: bool = false
						for delta: Vector2i in DIRS:
							near_outline = near_outline or (g.inside(cell + delta) and _inside_cell(cell + delta, bounds["outline"]))
						bad += int(regions[index] != (1 if near_outline else 2))
						bad += int(g.walk_people[index] != 0 or g.walk_dead[index] != 0 or not g.people_path.is_point_solid(cell) or not g.dead_path.is_point_solid(cell))
						shore += int(near_outline)
						bottom += int(not near_outline)
					for level: int in data["levels"]:
						if level > 0:
							var upper: Grid = data["levels"][level]
							bad += int(upper.walk_people[upper.index(Vector2i(x, y))] != 0)
		for i: int in range(regions.size()):
			var cell := Vector2i(i % g.width, floori(float(i) / g.width))
			bad += int((regions[i] != 0) != water_cells.has(cell))
		assert_gt(shore, 0, form + ": 윤곽 쪽 한 칸 얼음 물가")
		assert_gt(bottom, 0, form + ": 물 바닥")
		print("bounds/m form=%s shore=%d bottom=%d" % [form, shore, bottom])
		assert_eq(bad, 0, form)


func test_n_opening_cap_and_shape_gate() -> void:
	var g := Grid.new(80, 80)
	for length: int in [24, 32, 33]:
		var points: Array[Vector2i] = [Vector2i(0, 0), Vector2i(length, 0), Vector2i(length, 20), Vector2i(0, 20)]
		var named: Array[Dictionary] = [{"kind": "entry/test", "rect": Rect2i(0, 0, length, 2)}]
		var expected: Array[Dictionary] = _expected_open_edges(g, points, named)
		assert_eq(Rule.open_exceptions(g, points, named), expected, "보호 원본 독립 계산")
		assert_eq(expected.size(), 1 if length <= 32 else 0, "열린 자리 32m 상한")
		var unnamed: Array[Dictionary] = [{"kind": "walk_route", "rect": Rect2i(0, 0, length, 2)}]
		assert_true(Rule.open_exceptions(g, points, unnamed).is_empty(), "이름 없는 보호는 열린 자리 아님")
	var square: Array[Vector2i] = [Vector2i.ZERO, Vector2i(80, 0), Vector2i(80, 80), Vector2i(0, 80)]
	var invalid: Dictionary = {"outline": square, "steps": [], "corners": [0, 0, 0, 0]}
	assert_false(Rule.shape_errors(g, invalid).is_empty(), "긴 직선과 낮은 모서리는 도장 전에 거부")


func test_o_dead_detour_and_route_deduplication() -> void:
	var g := Grid.new(7, 5)
	g.solid.fill(Grid.Solid.BLOCK)
	for y: int in range(1, 4):
		for x: int in range(1, 6): g.solid[g.index(Vector2i(x, y))] = Grid.Solid.NONE
	for y: int in range(1, 4): g.solid[g.index(Vector2i(3, y))] = Grid.Solid.BLOCK
	var door := Vector2i(3, 2)
	g.doors[door] = {"state": "closed", "planks": [0, 0]}
	g.solid[g.index(door)] = Grid.Solid.DOOR
	g.solid[g.index(Vector2i(3, 1))] = Grid.Solid.NONE
	g.refresh_paths()
	var start := Vector2i(1, 2)
	var home := Vector2i(5, 2)
	var d: Dictionary = {"grid": g, "train_doors": {"test": [start]}, "entries": {"test": [start]}, "anchors": {"horde_home": home}}
	var blocked := PackedByteArray()
	blocked.resize(35)
	blocked[g.index(Vector2i(3, 1))] = 1
	var people: PackedInt32Array = Bounds.walk_parents(d, blocked)
	var before: PackedInt32Array = Bounds.walk_parents(d, PackedByteArray(), true)
	var after: PackedInt32Array = Bounds.walk_parents(d, blocked, true)
	assert_gte(people[g.index(home)], 0, "사람은 닫힌 문 통과")
	assert_gte(before[g.index(home)], 0, "경계 전 망자 우회")
	assert_eq(after[g.index(home)], -1, "경계 뒤 망자 우회 단절")
	var mask := PackedByteArray()
	mask.resize(35)
	var details: Array[Dictionary] = []
	var routes: Array[Vector2i] = []
	var cells: Dictionary = {}
	var detached: Array[int] = [g.index(home), g.index(home)]
	Bounds._add_routes(g, before, detached, blocked, mask, details, routes, cells)
	assert_eq(routes, [Vector2i(3, 1)], "같은 조상 경로를 한 번만 보호")
	assert_eq(details.size(), 1)


func test_p_depth_solver_keeps_named_gap_exact_and_limits_straights() -> void:
	var free_row: Array[Dictionary] = []
	for i: int in range(7): free_row.append({"from": i * 12, "to": (i + 1) * 12, "cap": 16})
	var free_depths: Array[int] = Rule.depths(free_row, Rule.random_of("lake_01"), 10, 10, 16)
	assert_eq(free_depths.size(), 7)
	assert_false(free_depths.has(0), "보호가 없는 변에 이름 없는 열린 자리를 만들지 않음")
	var row: Array[Dictionary] = [
		{"from": 0, "to": 12, "cap": 16}, {"from": 12, "to": 24, "cap": 16},
		{"from": 24, "to": 36, "cap": 0}, {"from": 36, "to": 49, "cap": 0},
		{"from": 49, "to": 61, "cap": 16}, {"from": 61, "to": 73, "cap": 16},
		{"from": 73, "to": 85, "cap": 16}]
	for candidate: int in range(17):
		var picked: Array[int] = Rule.depths(row, Rule.random_of("lake_01"), 10, 10, candidate)
		assert_eq(picked.size(), row.size(), "모서리와 25m 보호 틈을 함께 만족")
		if picked.size() != row.size(): continue
		assert_eq(picked[0], 10)
		assert_eq(picked[-1], 10)
		for i: int in range(picked.size()):
			assert_eq(picked[i] == 0, row[i]["cap"] == 0, "이름 있는 틈 밖으로 깊이 0 확장 금지")
			if i > 0:
				assert_lte(absi(picked[i] - picked[i - 1]), 6)
				if picked[i] != 0 or picked[i - 1] != 0:
					assert_gte(absi(picked[i] - picked[i - 1]), 2)


func test_q_dead_components_preserve_each_entry_not_just_the_union() -> void:
	var g := Grid.new(7, 3)
	g.walk_dead.fill(0)
	for x: int in range(7): g.walk_dead[7 + x] = 1
	var d: Dictionary = {"grid": g, "entries": {"left": [Vector2i(0, 1)], "right": [Vector2i(6, 1)]},
		"anchors": {"horde_home": Vector2i(1, 1)}}
	var blocked := PackedByteArray()
	blocked.resize(21)
	blocked[10] = 1
	var roots: Array[int] = []
	var before: Dictionary = Bounds._scan_walk(g, g.walk_dead, PackedByteArray(), roots, true)
	var after: Dictionary = Bounds._scan_walk(g, g.walk_dead, blocked, roots, true)
	var lost: Array[Dictionary] = Bounds._dead_lost(d, before, after)
	assert_eq(lost.size(), 1, "한 진입로가 살아 있어도 다른 진입로의 단절을 잡음")
	if lost.size() == 1: assert_eq(lost[0]["entry"], "right")
