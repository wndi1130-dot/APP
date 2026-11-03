extends "res://addons/gut/test.gd"
## 같은 입력의 판 0/1을 공유하되 시험에서는 공유 자료를 수정하지 않는다.
const Grid = preload("res://game/world/field_grid.gd")
const Maps = preload("res://game/world/field_maps.gd")
const Bounds = preload("res://game/world/map_bounds.gd")
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


func before_all() -> void:
	for form: String in FORMS:
		var base: Dictionary = Loader.make_ready(Lake, 71, form, -1.0, "", 0)
		var active: Dictionary = Loader.make_ready(Lake, 71, form)
		var pre: Dictionary = _direct(form, 71, -1, false)
		var g: Grid = pre["grid"]
		cases[form] = {"base": base, "active": active, "before_solid": g.solid.duplicate(),
			"before_floor": g.floor.duplicate(), "before_anchors": pre["anchors"].duplicate(true),
			"before_middle": pre.get("village_middle"), "before_distance": pre.get("walk_to_village_m"),
			"protected": Bounds.protected_cells(pre), "people": _flood(active, "walk_people"),
			"base_people": _flood(base, "walk_people"), "dead": _flood(active, "walk_dead")}


func after_all() -> void:
	cases.clear()


func _direct(form: String, seed_value: int, rule: int = -1, stamp: bool = true) -> Dictionary:
	var data: Dictionary = Maps.build_from(Lake, "", rule)
	data = Ground.apply(data, form, seed_value)
	data = Ground.widen_view(data)
	data = Game.with_side_path(data, seed_value)
	return Bounds.apply(data, rule) if stamp else data


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
		var g: Grid = cases[form]["active"]["grid"]
		assert_eq(cases[form]["people"].count(1), g.walk_people.count(1), form + ": 지상 미도달 0")


func test_b_baseline_functions_and_counts_survive() -> void:
	for form: String in FORMS:
		var base: Dictionary = cases[form]["base"]
		var data: Dictionary = cases[form]["active"]
		var g: Grid = data["grid"]
		var lost: int = 0
		var old: Dictionary = _features(base)
		var now: Dictionary = _features(data)
		for key: String in old:
			if _reached(base["grid"], cases[form]["base_people"], old[key]):
				lost += int(not now.has(key) or not _reached(g, cases[form]["people"], now.get(key, [])))
		assert_eq(lost, 0, form + ": 판 0에서 닿던 기능 칸")
		for key: String in ["containers", "spots", "work_sites"]:
			assert_gte(data.get(key, {}).size(), base.get(key, {}).size(), form + ": " + key)


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
		for y: int in range(g.height):
			for x: int in range(g.width):
				var cell := Vector2i(x, y)
				var i: int = g.index(cell)
				var inside: bool = Geometry2D.is_point_in_polygon(Vector2(cell) + Vector2.ONE * 0.5, polygon)
				if inside:
					failures += int(g.solid[i] != row["before_solid"][i] or g.floor[i] != row["before_floor"][i])
				else:
					failures += int(g.walk_people[i] != 0 or g.walk_dead[i] != 0 or row["protected"][i] != 0)
				failures += int(g.people_path.is_point_solid(cell) != (g.walk_people[i] == 0))
				failures += int(g.dead_path.is_point_solid(cell) != (g.walk_dead[i] == 0))
		assert_eq(failures, 0, form + ": 안팎/보호/두 길찾기")


func test_f_steps_corners_and_straight_limit() -> void:
	for form: String in FORMS:
		var b: Dictionary = cases[form]["active"].get("bounds", {})
		var points: Array = b.get("outline", [])
		assert_gte(int(b.get("corner", 0)), 10, form + ": 네 모서리 깎음")
		assert_gt(points.size(), 8, form)
		for side: int in 4:
			var previous: int = -1
			var changes: int = 0
			for step: Dictionary in b.get("steps", []):
				if int(step["side"]) != side:
					continue
				assert_between(int(step["to"]) - int(step["from"]), 8, 16, form)
				if previous >= 0:
					assert_lte(absi(int(step["depth"]) - previous), 6, form + ": 이웃 깊이")
					changes += int(int(step["depth"]) != previous)
				previous = int(step["depth"])
			assert_gte(changes, 2, form + ": 변마다 깊이 변화")
		for i: int in range(points.size()):
			var delta: Vector2i = points[(i + 1) % points.size()] - points[i]
			var length: int = absi(delta.x) + absi(delta.y)
			var bend: Vector2i = points[(i + 2) % points.size()] - points[(i + 1) % points.size()]
			if absi(bend.x) + absi(bend.y) < 2:
				var following: Vector2i = points[(i + 3) % points.size()] - points[(i + 2) % points.size()]
				length += absi(following.x) + absi(following.y)
			assert_lte(length, 24, form + ": 윤곽 직선")


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
		assert_gte(float(g.walk_people.count(1)) / float(bg.walk_people.count(1)), 1.25, form)
		var sides: Array = d["map_ring"]["sides"]
		var area: int = (170 + sides[0] + sides[2]) * (106 + sides[1] + sides[3])
		assert_between(float(area) / (210.0 * 146.0), 1.5 * 0.97, 1.5 * 1.03, form)


func test_j_forest_union_front_and_plan_key() -> void:
	for form: String in FORMS:
		var d: Dictionary = cases[form]["active"]
		var g: Grid = d["grid"]
		var forest: Array = []
		var covered: Dictionary = {}
		for tile: Dictionary in d.get("bounds", {}).get("tiles", []):
			if tile["kind"] != "forest":
				continue
			var rect: Rect2i = tile["rect"]
			forest.append(rect)
			assert_true(rect in d["deep_forest"], form)
			for y: int in range(rect.position.y, rect.end.y):
				for x: int in range(rect.position.x, rect.end.x):
					var cell := Vector2i(x, y)
					assert_false(covered.has(cell), form + ": 숲 중복 없음")
					covered[cell] = true
					assert_eq(g.solid[g.index(cell)], Grid.Solid.BLOCK)
		assert_lte(forest.size(), 48, form)
		for border: Dictionary in Edge._forest_borders(g, forest):
			assert_false(border["edges"].is_empty(), form + ": 봉인 네모 없음")
		for cell: Vector2i in covered:
			var front: bool = false
			for direction: Vector2i in DIRS:
				front = front or g.people_can_walk(cell + direction)
			if not front:
				continue
			var nearest: float = INF
			for tree: Vector2i in d.get("trees", []):
				nearest = minf(nearest, Vector2(cell).distance_to(Vector2(tree)))
			assert_lte(nearest, 1.5, form + ": 앞줄 빈틈")
		assert_eq(d["_edge_plan"]["key"], Edge.plan_key(g, Edge.seed_of(d), Edge.look_of(d), d.get("deep_forest", []), d.get("bounds", {})), form)


func test_k1_k2_repeat_and_direct_path_match() -> void:
	for form: String in FORMS:
		var first: Dictionary = cases[form]["active"]
		var repeated: Dictionary = Loader.make_ready(Lake, 71, form)
		assert_eq(Digest.digest(first), Digest.digest(repeated), form + ": 같은 입력 두 번")
		var direct: Dictionary = _direct(form, 71)
		direct["_edge_plan"] = Edge.plan_ahead(direct)
		Work.dress(direct, -1, 71)
		assert_eq(Digest.digest(direct), Digest.digest(first), form + ": 직접 시작 지문")
		var dg: Grid = direct["grid"]
		var fg: Grid = first["grid"]
		for key: String in Digest.GRID_ARRAYS:
			assert_eq(dg.get(key), fg.get(key), form + ": 직접 시작 " + key)
		assert_eq(direct["bounds"], first["bounds"], form)
		assert_eq(Edge.plan_ahead(direct)["key"], first["_edge_plan"]["key"], form)


func test_k3_save_resume_preserves_grid_outline_and_stamp() -> void:
	var game = Game.new()
	game.opts = {"seed": 71, "place": "lake_01", "auto_pause": false, "bounds_rule": 1}
	game.map_script = Lake
	add_child_autofree(game)
	game.set_process(false)
	var saved: Dictionary = Save.from_json(Save.to_json(Save.capture(game)))
	assert_false(saved.is_empty())
	var resumed = Game.new()
	resumed.opts = Save.resume_opts(saved)
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
	var rebuilt: Dictionary = Loader.make_ready(Lake, 71, "", -1.0, "", int(opts["bounds_rule"]))
	assert_eq(Digest.digest(rebuilt), Digest.digest(cases[""]["base"]))
	assert_false(rebuilt.has("bounds_stamp"))
	assert_eq(rebuilt["map_ring"]["sides"], [20, 20, 20, 20])


func test_k5_side_path_absent_present_and_north_west_shift() -> void:
	var absent_seed: int = 1
	while Side.rolls("lake_01", absent_seed):
		absent_seed += 1
	var without: Dictionary = _direct("", absent_seed)
	assert_false(without.has("side_path"))
	var found: Dictionary = {}
	for form: String in FORMS:
		var plain: Dictionary = Maps.build_from(Lake)
		plain = Ground.apply(plain, form, 71)
		for seed_value: int in range(1, 65):
			var rng := Side._rng("lake_01", seed_value)
			if rng.randf() >= Side.CHANCE:
				continue
			var spot: Dictionary = Side.pick(plain, rng)
			if spot.is_empty() or found.has(spot["side"]):
				continue
			var side: int = int(spot["side"])
			var with_path: Dictionary = Maps.build_from(Lake)
			with_path = Ground.apply(with_path, form, 71)
			var old_train: Rect2i = with_path["train"]
			with_path = Side.add(with_path, seed_value)
			Bounds.apply(with_path)
			assert_true(with_path.has("side_path"))
			assert_eq(with_path.get("bounds_stamp", 0), 1)
			if side in [0, 3]:
				var shift: Vector2i = Vector2i(Side.STRIP, 0) if side == 3 else Vector2i(0, Side.STRIP)
				assert_eq(with_path["train"].position, old_train.position + shift)
			found[side] = seed_value
			if found.has(0) and found.has(3):
				break
		if found.has(0) and found.has(3):
			break
	assert_false(found.is_empty(), "샛길 있는 씨앗")
	assert_true(found.has(0), "북쪽으로 키우는 실제 씨앗: 못 찾으면 미확인으로 남긴다")
	assert_true(found.has(3), "서쪽으로 키우는 실제 씨앗: 못 찾으면 미확인으로 남긴다")


func test_l_grove_count_and_reachable_stands() -> void:
	for form: String in FORMS:
		var data: Dictionary = cases[form]["active"].duplicate(true)
		var base: Dictionary = cases[form]["base"].duplicate(true)
		var groves: Array = Edge.fell_groves(data["grid"], data["_edge_plan"]["plan"], data)
		var old: Array = Edge.fell_groves(base["grid"], base["_edge_plan"]["plan"], base)
		assert_gte(groves.size(), old.size(), form)
		for grove: Dictionary in groves:
			assert_false(grove["stand"].is_empty())
			for at: Vector2i in grove["stand"]:
				assert_eq(cases[form]["people"][data["grid"].index(at)], 1, form)


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
