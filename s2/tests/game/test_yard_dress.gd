extends "res://addons/gut/test.gd"
const Grid = preload("res://game/world/field_grid.gd")
const Maps = preload("res://game/world/field_maps.gd")
const Yard = preload("res://game/world/yard_dress.gd")
const Furnish = preload("res://game/world/room_furnish.gd")
const Kinds = preload("res://game/world/prop_kinds.gd")
const Cellar = preload("res://game/world/cellar_rules.gd")
const Roof = preload("res://game/world/roof_rules.gd")
const Split = preload("res://game/world/room_split.gd")
const S = Grid.Solid
const F = Grid.Floor
const MAP_IDS: Array[String] = ["houses_01", "houses_07"]
const STEPS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]


## FieldMaps의 마당 호출 바로 전. 지도는 두 종류만, 결정성 비교를 위해 각각 두 벌 준비.
func _prepare(place_id: String) -> Dictionary:
	var script: Script = load(Maps.path_of(place_id))
	var data: Dictionary = script.build()
	data["place_id"] = place_id
	for key: String in Maps.OPTIONAL:
		if not data.has(key):
			data[key] = Maps.OPTIONAL[key].duplicate(true)
	var ground: Grid = data["grid"]
	for slow: Rect2i in data["slow_rects"]:
		for slow_cell: Vector2i in Yard._rect_cells(slow):
			ground.floor[ground.index(slow_cell)] = F.DEEP_SNOW
	data["_defer_paths"] = true
	Cellar.hatches(data)
	Roof.plan(data)
	Split.apply(data, script)
	Furnish.furnish_rooms(data)
	Furnish.clear_fronts(data)
	Furnish.block_furniture(data)
	Furnish.boxes_into_furniture(data)
	Furnish.name_boxes_by_furniture(data)
	return data


## 배치기와 별도인 시험용 4이웃 넓이 우선 걷기.
func _walk(grid: Grid, start: Vector2i) -> Dictionary:
	var seen: Dictionary = {}
	if not grid.inside(start) or grid.solid_at(start) not in [S.NONE, S.DOOR]:
		return seen
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for direction: Vector2i in STEPS:
			var neighbor: Vector2i = cell + direction
			if grid.inside(neighbor) and not seen.has(neighbor) and grid.solid_at(neighbor) in [S.NONE, S.DOOR]:
				seen[neighbor] = true
				queue.append(neighbor)
	return seen


func _routes_before(grid: Grid) -> Array[Dictionary]:
	var pending: Dictionary = {}
	for door: Vector2i in grid.doors:
		for direction: Vector2i in STEPS:
			var outside: Vector2i = door + direction
			if grid.inside(outside) and grid.building_at(outside) < 0 and grid.solid_at(outside) in [S.NONE, S.DOOR]:
				pending[outside] = true
	var groups: Array[Dictionary] = []
	while not pending.is_empty():
		var start: Vector2i = pending.keys()[0]
		var seen: Dictionary = _walk(grid, start)
		var sources: Array[Vector2i] = []
		var targets: Array[Vector2i] = []
		for source: Vector2i in pending.keys():
			if seen.has(source):
				sources.append(source)
				pending.erase(source)
		for cell: Vector2i in seen:
			if grid.floor_at(cell) == F.ROAD or cell.x == 0 or cell.y == 0 or cell.x == grid.width - 1 or cell.y == grid.height - 1:
				targets.append(cell)
		groups.append({"sources": sources, "targets": targets})
	return groups


func _check_map(place_id: String) -> void:
	var data: Dictionary = _prepare(place_id)
	var grid: Grid = data["grid"]
	var before_props: Array = data["props"].duplicate(true)
	var before_low: Array = data["low_blocks"].duplicate(true)
	var before_metadata: Dictionary = data.duplicate(true)
	for excluded: String in ["grid", "levels", "props", "low_blocks", "_rooms"]:
		before_metadata.erase(excluded)
	var solids: Dictionary = {}
	var floors: Dictionary = {}
	var buildings: Dictionary = {}
	for level: int in data["levels"]:
		var level_grid: Grid = data["levels"][level]
		solids[level] = level_grid.solid.duplicate()
		floors[level] = level_grid.floor.duplicate()
		buildings[level] = level_grid.building.duplicate()
	var surveyed: Dictionary = Yard.survey(data)
	var routes: Array[Dictionary] = _routes_before(grid)
	var stats: Dictionary = Yard.dress(data)
	assert_gt(int(stats["homes"]), 0, place_id + " 살림집 검출")
	assert_gt(int(stats["rows"]), 0, place_id + " 새 소품")
	assert_eq(data["props"].slice(0, before_props.size()), before_props, place_id + " 기존 줄 순서·값 보존")
	assert_eq(data["low_blocks"].slice(0, before_low.size()), before_low, place_id + " 기존 낮은 막힘 보존")
	for metadata_key: String in before_metadata:
		assert_eq(data[metadata_key], before_metadata[metadata_key], place_id + " 보존: " + metadata_key)
	var expected_blocked: Dictionary = {}
	var used: Dictionary = {}
	var new_rows: Array = data["props"].slice(before_props.size())
	var new_kind_counts: Dictionary = {}
	var blocking_rows: int = 0
	for row: Dictionary in new_rows:
		assert_true(bool(row.get("yard", false)), place_id + " 마당 표지")
		assert_eq(int(row.get("level", -1)), 0)
		assert_false(Kinds.model_path(String(row["kind"])).is_empty(), String(row["kind"]) + " 실제 모형 경로")
		assert_true(row["solid"] in ["none", "low"])
		assert_true(int(row["facing"]) >= 0 and int(row["facing"]) <= 3)
		assert_true(String(row["note"]).contains(" 마당의 "))
		assert_false(row.has("search"), "뒤지는 소품을 만들지 않음")
		var rect: Rect2i = row["rect"]
		var expected_size: Vector2i = Yard.SIZES[row["kind"]]
		if int(row["facing"]) % 2 == 1:
			expected_size = Vector2i(expected_size.y, expected_size.x)
		assert_eq(rect.size, expected_size, String(row["kind"]) + " 회전한 모형 크기")
		for cell: Vector2i in Yard._rect_cells(rect):
			assert_eq(surveyed["owners"].get(cell, -1), row["building"], place_id + " 원래 빈 마당")
			assert_false(surveyed["forbidden"].has(cell), place_id + " 문·철길·승강장·건널목 금지 칸")
			assert_false(used.has(cell), "새 줄끼리 겹치지 않음")
			assert_eq(int(solids[0][grid.index(cell)]), S.NONE)
			assert_lt(grid.building_at(cell), 0)
			assert_false(grid.floor_at(cell) in [F.ROAD, F.RAIL, F.PLATFORM, F.ICE, F.DEEP_SNOW])
			used[cell] = true
		for blocked: Vector2i in Yard.blocking_cells(row):
			expected_blocked[blocked] = true
			var registered: bool = false
			for low_rect: Rect2i in data["low_blocks"].slice(before_low.size()):
				registered = registered or low_rect.has_point(blocked)
			assert_true(registered, "LOW 칸을 low_blocks에도 등록")
		new_kind_counts[row["kind"]] = int(new_kind_counts.get(row["kind"], 0)) + 1
		blocking_rows += int(row["solid"] == "low")
	assert_eq(stats["rows"], new_rows.size())
	assert_eq(stats["kinds"], new_kind_counts)
	assert_eq(stats["blocking"], blocking_rows)
	assert_eq(stats["yard_cells"], surveyed["owners"].size())
	for checked_level: int in data["levels"]:
		var checked_grid: Grid = data["levels"][checked_level]
		assert_eq(checked_grid.floor, floors[checked_level], "바닥 불변")
		assert_eq(checked_grid.building, buildings[checked_level], "건물 번호 불변")
		var expected_solids: PackedByteArray = solids[checked_level].duplicate()
		if checked_level == 0:
			for changed_cell: Vector2i in expected_blocked:
				expected_solids[checked_grid.index(changed_cell)] = S.LOW
		assert_eq(checked_grid.solid, expected_solids, place_id + " 실내·기존 고체·none 소품 통과 칸 보존")
	for route: Dictionary in routes:
		if route["targets"].is_empty():
			continue
		var after_walk: Dictionary = _walk(grid, route["sources"][0])
		var missing: int = 0
		for required: Vector2i in route["sources"] + route["targets"]:
			missing += int(not after_walk.has(required))
		assert_eq(missing, 0, place_id + " 모든 문에서 원래 닿던 길·지도 끝 전체 보존")
	var measured: Dictionary = Yard.census(data)
	assert_eq(measured["yard_cells"], stats["yard_cells"], "차린 뒤에도 분모 고정")
	assert_true(float(measured["per_100"]) >= 5.0, "%s 100m²당 5 이상: %.3f" % [place_id, measured["per_100"]])
	assert_true(float(measured["per_100"]) <= 8.0, "%s 100m²당 8 이하: %.3f" % [place_id, measured["per_100"]])
	assert_true(float(measured["median_kinds"]) >= 4.0, place_id + " 집 갈래 수 가운데값 4 이상")
	assert_true(int(measured["map_kinds"]) >= 8, place_id + " 지도 갈래 수 8 이상")
	var replay: Dictionary = _prepare(place_id)
	var replay_start: int = replay["props"].size()
	var replay_stats: Dictionary = Yard.dress(replay)
	assert_eq(replay["props"].slice(replay_start), new_rows, place_id + " 같은 준비 두 번 → 같은 줄·순서")
	assert_eq(replay_stats, stats, place_id + " 결정적인 집계")
	data.erase("_defer_paths")
	grid.refresh_paths()
	for cached_cell: Vector2i in expected_blocked:
		assert_false(grid.people_can_walk(cached_cell), "마지막 refresh_paths 뒤 막힘 반영")


func test_two_house_maps_preserve_rules_routes_and_meet_yard_targets() -> void:
	for place_id: String in MAP_IDS:
		_check_map(place_id)


func test_every_selected_kind_has_a_real_model_before_dressing() -> void:
	for kind: String in Yard.SIZES:
		assert_false(Kinds.model_path(kind).is_empty(), kind + " 모형 누락")


func test_single_corridor_cut_is_rejected_and_laundry_blocks_only_posts() -> void:
	var grid: Grid = Grid.new(9, 3)
	grid.solid.fill(S.BLOCK)
	for open_x in range(9):
		grid.set_solid(Vector2i(open_x, 1), S.NONE)
		grid.floor[grid.index(Vector2i(open_x, 1))] = F.ROAD
	var door: Vector2i = Vector2i(1, 1)
	grid.set_solid(door, S.DOOR)
	grid.building[grid.index(door)] = 0
	grid.doors[door] = {"building": 0, "state": "open"}
	var guard: Dictionary = Yard.path_guard(grid)
	assert_true(Yard.paths_preserved(grid, guard))
	assert_false(Yard.paths_preserved(grid, guard, {Vector2i(5, 1): true}), "한쪽 길이 남아도 다른 지도 끝을 끊으면 거절")
	var line: Dictionary = {"kind": "laundry_line", "solid": "low", "rect": Rect2i(2, 1, 6, 1)}
	var posts: Array[Vector2i] = Yard.blocking_cells(line)
	assert_eq(posts, [Vector2i(2, 1), Vector2i(7, 1)])
	line["rect"] = Rect2i(2, 1, 1, 6)
	assert_eq(Yard.blocking_cells(line), [Vector2i(2, 1), Vector2i(2, 6)])
	line["solid"] = "none"
	assert_true(Yard.blocking_cells(line).is_empty())


func test_upper_bedrooms_select_homes_and_equal_distance_uses_smaller_id() -> void:
	var ground: Grid = Grid.new(22, 14)
	var upper: Grid = Grid.new(22, 14)
	upper.solid.fill(S.AIR)
	var houses: Array = [{"id": 2, "name": "서쪽 집", "rect": Rect2i(4, 5, 3, 3)},
		{"id": 7, "name": "동쪽 집", "rect": Rect2i(12, 5, 3, 3)}]
	for house: Dictionary in houses:
		for cell: Vector2i in Yard._rect_cells(house["rect"]):
			ground.building[ground.index(cell)] = house["id"]
			ground.set_solid(cell, S.WALL)
			upper.building[upper.index(cell)] = house["id"]
			upper.set_solid(cell, S.NONE)
	var data: Dictionary = {"grid": ground, "levels": {0: ground, 1: upper}, "buildings": houses,
		"density_classes": {"1:0": "bed", "1:1": "bed"}, "props": [], "containers": {}, "trees": []}
	var surveyed: Dictionary = Yard.survey(data)
	assert_eq(surveyed["homes"].size(), 2, "윗층 침실도 살림집")
	assert_eq(surveyed["owners"].get(Vector2i(9, 6), -1), 2, "동거리 작은 건물 번호")
	assert_eq(surveyed["owners"].get(Vector2i(10, 6), -1), 7, "가까운 건물")


func test_the_ring_check_lets_open_ground_skip_the_whole_map_search() -> void:
	# 열린 땅 한가운데는 막아도 둘레로 돌아가고(참), 좁은 길목(양옆 벽)이나 지도 끝은 전체 검사로 넘긴다(거짓).
	var g := Grid.new(7, 7)
	var open: Array[Vector2i] = [Vector2i(3, 3)]
	assert_true(Yard.ring_keeps_paths(g, open), "열린 땅")
	var pair: Array[Vector2i] = [Vector2i(3, 3), Vector2i(4, 3)]
	assert_true(Yard.ring_keeps_paths(g, pair), "열린 땅 두 칸")
	g.set_solid(Vector2i(3, 2), Grid.Solid.WALL)
	g.set_solid(Vector2i(3, 4), Grid.Solid.WALL)
	assert_false(Yard.ring_keeps_paths(g, open), "위아래가 벽인 길목은 좌우가 갈림")
	var edge: Array[Vector2i] = [Vector2i(0, 3)]
	assert_false(Yard.ring_keeps_paths(g, edge), "지도 끝 칸")
