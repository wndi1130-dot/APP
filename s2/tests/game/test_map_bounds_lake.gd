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
		var pre: Dictionary = _direct(form, 71, -1, false)
		var g: Grid = pre["grid"]
		cases[form] = {"base": base, "active": active, "pre": pre, "before_solid": g.solid,
			"before_floor": g.floor, "before_anchors": pre["anchors"].duplicate(true),
			"before_middle": pre.get("village_middle"), "before_distance": pre.get("walk_to_village_m"),
			"protected": Bounds.protected_cells(pre), "people": _flood(active, "walk_people"),
			"pre_people": _flood(pre, "walk_people"), "base_people": _flood(base, "walk_people"),
			"dead": _flood(active, "walk_dead"), "digest": Digest.digest(active)}


func after_all() -> void:
	cases.clear()
	cores.clear()


func _direct(form: String, seed_value: int, rule: int = -1, stamp: bool = true) -> Dictionary:
	var data: Dictionary = _copy_map(cores[0 if rule == 0 else 1])
	data = Ground.apply(data, form, seed_value)
	data = Ground.widen_view(data)
	data = Game.with_side_path(data, seed_value)
	return Bounds.apply(data, rule) if stamp else data


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
		var data: Dictionary = cases[form]["active"]
		var g: Grid = data["grid"]
		var missing: Array[Dictionary] = []
		for y: int in range(g.height):
			for x: int in range(g.width):
				var cell := Vector2i(x, y)
				if g.walk_people[g.index(cell)] == 1 and cases[form]["people"][g.index(cell)] == 0:
					missing.append(_cell_info(form, cell))
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
	return {"cell": cell, "core_cell": cell - data["map_ring"]["inner"].position,
		"before_reached": cases[form]["pre_people"][g.index(cell)], "neighbors": neighbors}


func test_b_baseline_functions_and_counts_survive() -> void:
	for form: String in FORMS:
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
		var row: Dictionary = cases[form]
		var data: Dictionary = row["active"]
		assert_eq(data["anchors"], row["before_anchors"], form)
		assert_eq(data.get("village_middle"), row["before_middle"], form)
		assert_eq(data.get("walk_to_village_m"), row["before_distance"], form)


func test_e_outside_blocked_inside_and_protection_unchanged() -> void:
	for form: String in FORMS:
		var row: Dictionary = cases[form]
		var data: Dictionary = row["active"]
		var g: Grid = data["grid"]
		assert_eq(data.get("bounds_stamp", 0), 1, form)
		assert_true(Bounds.check(data.get("bounds", {}), g).is_empty(), form)
		var polygon := PackedVector2Array()
		for point: Vector2i in data.get("bounds", {}).get("outline", []):
			polygon.append(Vector2(point))
		var failures: int = 0
		var details: Array[Dictionary] = []
		for y: int in range(g.height):
			for x: int in range(g.width):
				var cell := Vector2i(x, y)
				var i: int = g.index(cell)
				var was: int = failures
				var inside: bool = Geometry2D.is_point_in_polygon(Vector2(cell) + Vector2.ONE * 0.5, polygon)
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


func test_f_steps_corners_and_straight_limit() -> void:
	for form: String in FORMS:
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
		var verified: bool = actual == expected and b.get("form_forest", []) == form_forest
		assert_true(verified, "%s: 예외 명단 expected=%s actual=%s" % [form, str(expected), str(actual)])
		var checked: Array[Dictionary] = []
		if verified:
			checked.assign(actual)
		var omitted_edges: Dictionary = {}
		var excluded: int = 0
		for exception: Dictionary in checked:
			omitted_edges[exception["edge"]] = true
			excluded += int(exception["metres"])
		print("예외: %s 통로 숲 변 %d개, 길이 %dm — %s" % [form, checked.size(), excluded, str(checked)])
		print("bounds/f violations=" + str(b.get("violations", [])))
		var corner_points: Array[Vector2i] = [Vector2i.ZERO, Vector2i(g.width, 0), Vector2i(g.width, g.height), Vector2i(0, g.height)]
		for i: int in 4:
			var omitted: bool = false
			var at: Vector2i = corner_points[i]
			for exception: Dictionary in checked:
				omitted = omitted or _on_segment(at, exception["a"], exception["b"])
			if not omitted:
				assert_gte(int(b.get("corners", [0, 0, 0, 0])[i]), 10, form + ": 모서리 " + str(at))
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
				measured += 1
				assert_between(int(step["to"]) - int(step["from"]), 8, 16, form)
				if previous >= 0:
					assert_lte(absi(int(step["depth"]) - previous), 6, form + ": 이웃 깊이")
					changes += int(int(step["depth"]) != previous)
				previous = int(step["depth"])
			if measured > 0:
				assert_gte(changes, 2, form + ": 변마다 깊이 변화 side=" + str(side))
		for i: int in range(points.size()):
			if omitted_edges.has(i):
				continue
			var delta: Vector2i = points[(i + 1) % points.size()] - points[i]
			var length: int = absi(delta.x) + absi(delta.y)
			assert_lte(length, 24, "%s: 윤곽 변 %d %s→%s violations=%s" % [form, i, str(points[i]),
				str(points[(i + 1) % points.size()]), str(b.get("violations", []))])
			var bend: Vector2i = points[(i + 2) % points.size()] - points[(i + 1) % points.size()]
			if absi(bend.x) + absi(bend.y) < 2 and not omitted_edges.has((i + 1) % points.size()) and not omitted_edges.has((i + 2) % points.size()):
				var following: Vector2i = points[(i + 3) % points.size()] - points[(i + 2) % points.size()]
				assert_lte(length + absi(following.x) + absi(following.y), 24, form + ": 2m 미만 꺾임 합산")
		assert_eq(excluded, int(b.get("form_forest_m", 0)), form + ": 기존 숲 제외 길이")


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
		assert_gte(float(numerator) / float(denominator), 1.25, metrics)
		var sides: Array = d["map_ring"]["sides"]
		var area: int = (170 + sides[0] + sides[2]) * (106 + sides[1] + sides[3])
		print("bounds/ring form=%s sides=%s cells=%d" % [form, str(sides), area])
		assert_between(float(area) / (210.0 * 146.0), 1.55 * 0.97, 1.55 * 1.03, form)


func test_j_forest_union_front_and_plan_key() -> void:
	for form: String in FORMS:
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
		var first: Dictionary = cases[form]["active"]
		# cores와 make_ready는 각각 독립해서 지었다. 준비된 직접 경로의 사본만 찍는다.
		var direct: Dictionary = Bounds.apply(_copy_map(cases[form]["pre"]))
		_finish(direct)
		var changed: Array[String] = _changed_items(Digest.digest(direct), cases[form]["digest"])
		assert_true(changed.is_empty(), form + ": 반복/직접 시작 changed=" + str(changed))
		var dg: Grid = direct["grid"]
		var fg: Grid = first["grid"]
		for key: String in Digest.GRID_ARRAYS:
			assert_eq(dg.get(key), fg.get(key), form + ": 직접 시작 " + key)
		assert_eq(direct["bounds"], first["bounds"], form)
		assert_eq(direct["_edge_plan"]["key"], first["_edge_plan"]["key"], form)


func test_k3_save_resume_preserves_grid_outline_and_stamp() -> void:
	var game = Game.new()
	game.opts = {"seed": 71, "place": "lake_01", "auto_pause": false, "bounds_rule": 1}
	game.opts["map_data"] = _copy_map(cases[""]["active"])
	game.map_script = Lake
	add_child_autofree(game)
	game.set_process(false)
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
	assert_eq(resumed.data["bounds"], game.data["bounds"])
	assert_eq(resumed.data["bounds_stamp"], game.data["bounds_stamp"])


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
	# pick은 첫 유효 방향에서만 난수를 쓴다. 북/서는 실제 띠를 직접 붙여 좌표 계약을 검사한다.
	for side: int in [0, 3]:
		var probe: Dictionary = _copy_map(cores[1])
		var old: Dictionary = probe["containers"].duplicate(true)
		var train: Rect2i = probe["train"]
		var shift: Vector2i = Vector2i(Side.STRIP, 0) if side == 3 else Vector2i(0, Side.STRIP)
		probe = Shift.grow(probe, shift.x, shift.y, 0, 0, false)
		var spot: Dictionary = {"side": side, "along": 40, "seconds": 0.0}
		Side._build(probe, spot, Side._rng("lake_01", present_seed), present_seed)
		probe["side_path"] = spot
		Bounds.apply(probe)
		assert_eq(probe.get("bounds_stamp", 0), 1)
		assert_eq(probe["train"].position, train.position + shift)
		for key: String in old:
			assert_eq(probe["containers"][key]["cell"], old[key]["cell"] + shift, key)
		assert_true(Bounds.check(probe.get("bounds", {}), probe["grid"]).is_empty())


func test_l_grove_count_and_reachable_stands() -> void:
	for form: String in FORMS:
		var data: Dictionary = cases[form]["active"].duplicate(true)
		var base: Dictionary = cases[form]["base"].duplicate(true)
		var groves: Array = Edge.fell_groves(data["grid"], data["_edge_plan"]["plan"], data)
		var old: Array = Edge.fell_groves(base["grid"], base["_edge_plan"]["plan"], base)
		assert_gte(groves.size(), old.size(), "%s: 이전=%s 이후=%s" % [form, str(old), str(groves)])
		for grove: Dictionary in groves:
			assert_false(grove["stand"].is_empty())
			for at: Vector2i in grove["stand"]:
				assert_eq(cases[form]["people"][data["grid"].index(at)], 1, form + ": 벌목지=" + str(grove) + " stand=" + str(at))


func test_m_water_masks_and_upper_floor_outside() -> void:
	for form: String in FORMS:
		var data: Dictionary = cases[form]["active"]
		var g: Grid = data["grid"]
		var bounds: Dictionary = data.get("bounds", {})
		var bad: int = 0
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
						var index: int = g.index(Vector2i(x, y))
						bad += int(g.solid[index] != Grid.Solid.LOW or g.opq[index] != 0 or g.floor[index] != Grid.Floor.ICE)
					for level: int in data["levels"]:
						if level > 0:
							var upper: Grid = data["levels"][level]
							bad += int(upper.walk_people[upper.index(Vector2i(x, y))] != 0)
		assert_eq(bad, 0, form)
