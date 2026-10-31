extends "res://addons/gut/test.gd"
const Grid = preload("res://game/world/field_grid.gd")
const Maps = preload("res://game/world/field_maps.gd")
const Yard = preload("res://game/world/yard_dress.gd")
const Furnish = preload("res://game/world/room_furnish.gd")
const RoomDecor = preload("res://game/world/room_decor.gd")
const MapRing = preload("res://game/world/map_ring.gd")
const Kinds = preload("res://game/world/prop_kinds.gd")
const Cellar = preload("res://game/world/cellar_rules.gd")
const Roof = preload("res://game/world/roof_rules.gd")
const Split = preload("res://game/world/room_split.gd")
const S = Grid.Solid
const F = Grid.Floor
const MAP_IDS: Array[String] = ["houses_01", "houses_07"]
const ALL_MAP_IDS: Array[String] = ["houses_01", "houses_02", "houses_03", "houses_04",
	"houses_05", "houses_06", "houses_07"]
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
	var hatches: int = Cellar.hatches(data)
	Roof.plan(data)
	Split.apply(data, script)
	data["room_stats"] = Furnish.furnish_rooms(data)
	data["room_stats"]["hatches"] = hatches
	data["room_stats"]["fronts"] = Furnish.clear_fronts(data)
	data["furniture_stats"] = Furnish.block_furniture(data)
	data["room_stats"]["boxes_moved"] = Furnish.boxes_into_furniture(data)
	data["room_stats"]["boxes_renamed"] = Furnish.name_boxes_by_furniture(data)
	data["room_stats"]["decor"] = RoomDecor.dress(data)
	return data


## 배치기와 별도인 시험용 4이웃 넓이 우선 걷기.
func _walk(grid: Grid, start: Vector2i, blocked: Dictionary = {}) -> Dictionary:
	var seen: Dictionary = {}
	if not grid.inside(start) or blocked.has(start) or grid.solid_at(start) not in [S.NONE, S.DOOR]:
		return seen
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for direction: Vector2i in STEPS:
			var neighbor: Vector2i = cell + direction
			if grid.inside(neighbor) and not blocked.has(neighbor) \
					and not seen.has(neighbor) and grid.solid_at(neighbor) in [S.NONE, S.DOOR]:
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


func _assert_home_caps(place_id: String, surveyed: Dictionary, before: Dictionary,
		measured: Dictionary, stats: Dictionary) -> void:
	var over_cap_homes: int = 0
	for home: Dictionary in surveyed["homes"]:
		var building_id: int = home["building"]
		var cap: int = floori(float(home["cells"].size()) * 6.5 / 100.0)
		var old_count: int = before["per_home"][building_id]["old"]
		var new_count: int = measured["per_home"][building_id]["new"]
		var label: String = "%s 집 %d (원래 빈 칸 %d, 상한 %d)" % [place_id, building_id, home["cells"].size(), cap]
		assert_eq(measured["per_home"][building_id]["old"], old_count, label + " 기존 줄 수 보존")
		if old_count > cap:
			over_cap_homes += 1
			assert_eq(new_count, 0, label + " 이미 넘은 집에는 추가하지 않음")
		else:
			assert_lte(old_count + new_count, cap, label + " 집마다 상한")
	assert_eq(stats["over_cap_homes"], over_cap_homes, place_id + " 기존 상한 초과 집 수")


func _check_map(place_id: String) -> void:
	var data: Dictionary = _prepare(place_id)
	var grid: Grid = data["grid"]
	var before_props: Array = data["props"].duplicate(true)
	var before_decor: Array[Dictionary] = []
	for original_prop: Dictionary in before_props:
		if original_prop.get("decor", false):
			before_decor.append(original_prop)
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
	var before_census: Dictionary = Yard.census(data, surveyed)
	var routes: Array[Dictionary] = _routes_before(grid)
	var stats: Dictionary = Yard.dress(data)
	assert_gt(int(stats["homes"]), 0, place_id + " 살림집 검출")
	assert_gt(int(stats["rows"]), 0, place_id + " 새 소품")
	assert_eq(data["props"].slice(0, before_props.size()), before_props, place_id + " 기존 줄 순서·값 보존")
	var after_decor: Array[Dictionary] = []
	for retained_prop: Dictionary in data["props"]:
		if retained_prop.get("decor", false):
			after_decor.append(retained_prop)
	assert_eq(after_decor, before_decor, place_id + " 실내 장식 줄 순서·모든 값 보존")
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
		assert_false(String(row["kind"]) in ["garden_bed", "herb_bed", "laundry_line"], "꺼 둔 갈래(텃밭·빨랫줄)는 새 줄 없음")
		assert_eq(bool(row.get("shade", true)), not Yard.NO_SHADE_KINDS.has(String(row["kind"])),
			String(row["kind"]) + " 발이 모형 전체인 갈래만 접지 그늘 끔")
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
	_assert_home_caps(place_id, surveyed, before_census, measured, stats)
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


func test_two_house_maps_preserve_rules_routes_and_meet_yard_targets() -> void:
	for place_id: String in MAP_IDS:
		_check_map(place_id)


func test_all_house_maps_obey_each_home_cap() -> void:
	for place_id: String in ALL_MAP_IDS:
		var data: Dictionary = _prepare(place_id)
		var surveyed: Dictionary = Yard.survey(data)
		var before: Dictionary = Yard.census(data, surveyed)
		var stats: Dictionary = Yard.dress(data)
		_assert_home_caps(place_id, surveyed, before, Yard.census(data, surveyed), stats)


func test_existing_rows_over_home_cap_add_nothing() -> void:
	var grid: Grid = Grid.new(14, 14)
	var house: Rect2i = Rect2i(5, 5, 3, 3)
	for cell: Vector2i in Yard._rect_cells(house):
		grid.building[grid.index(cell)] = 0
	var data: Dictionary = {"grid": grid, "levels": {0: grid}, "place_id": "yard_over_cap",
		"buildings": [{"id": 0, "rect": house, "name": "상한 시험 집"}],
		"density_classes": {"0:0": "bed"}, "props": [], "low_blocks": [],
		"containers": {}, "trees": [], "_defer_paths": true}
	for old_index in range(20):
		data["props"].append({"kind": "bush_juniper", "rect": Rect2i(4, 5, 1, 1),
			"solid": "none", "level": 0, "note": "기존 줄 %d" % old_index})
	var surveyed: Dictionary = Yard.survey(data)
	var before: Dictionary = Yard.census(data, surveyed)
	var before_props: Array = data["props"].duplicate(true)
	var stats: Dictionary = Yard.dress(data)
	_assert_home_caps("상한 시험", surveyed, before, Yard.census(data, surveyed), stats)
	assert_eq(stats["homes"], 1)
	assert_eq(stats["over_cap_homes"], 1, "기존 소품만으로 상한을 넘은 집도 셈함")
	assert_eq(stats["rows"], 0)
	assert_eq(stats["full_checks"], 0)
	assert_eq(data["props"], before_props, "기존 줄을 고치거나 새 줄을 붙이지 않음")


func test_real_build_updates_both_walk_caches_and_path_grids() -> void:
	for place_id: String in MAP_IDS:
		var data: Dictionary = MapRing.plain_build(load(Maps.path_of(place_id)), Maps.build_from)
		var grid: Grid = data["grid"]
		assert_true(grid.paths_ready(), place_id + " 실제 짓기의 길 캐시 완료")
		var checked: int = 0
		for prop: Dictionary in data["props"]:
			if not prop.get("yard", false):
				continue
			for cell: Vector2i in Yard.blocking_cells(prop):
				var cell_index: int = grid.index(cell)
				assert_eq(grid.solid_at(cell), S.LOW)
				assert_eq(int(grid.walk_people[cell_index]), 0, place_id + " 사람 걷기 배열")
				assert_eq(int(grid.walk_dead[cell_index]), 0, place_id + " 망자 걷기 배열")
				assert_true(grid.people_path.is_point_solid(cell), place_id + " 사람 AStar 막힘")
				assert_true(grid.dead_path.is_point_solid(cell), place_id + " 망자 AStar 막힘")
				checked += 1
		assert_gt(checked, 0, place_id + " 새 LOW 칸을 실제로 검사함")


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


func _two_cell_gap_grid() -> Grid:
	var grid: Grid = Grid.new(9, 9)
	for wall_y in range(grid.height):
		grid.set_solid(Vector2i(4, wall_y), S.WALL)
	grid.set_solid(Vector2i(4, 3), S.NONE)
	grid.set_solid(Vector2i(4, 4), S.NONE)
	var door: Vector2i = Vector2i(1, 4)
	grid.set_solid(door, S.DOOR)
	grid.building[grid.index(door)] = 0
	grid.doors[door] = {"building": 0, "state": "open"}
	grid.floor[grid.index(Vector2i(7, 4))] = F.ROAD
	return grid


func _paths_by_walk(grid: Grid, guard: Dictionary, blocked: Dictionary) -> bool:
	for group: Dictionary in guard.values():
		if group["targets"].is_empty():
			continue
		var reached: Dictionary = _walk(grid, group["sources"][0], blocked)
		for required: Vector2i in group["sources"] + group["targets"]:
			if not reached.has(required):
				return false
	return true


func test_ring_checks_each_block_after_the_previous_one() -> void:
	var grid: Grid = _two_cell_gap_grid()
	var first: Array[Vector2i] = [Vector2i(4, 3)]
	var second: Array[Vector2i] = [Vector2i(4, 4)]
	var both: Array[Vector2i] = [first[0], second[0]]
	var blocked: Dictionary = {first[0]: true, second[0]: true}
	var guard: Dictionary = Yard.path_guard(grid)
	assert_false(guard.is_empty(), "문에서 반대편 길까지의 보존 기준 있음")
	assert_true(Yard.ring_keeps_paths(grid, first))
	assert_true(Yard.ring_keeps_paths(grid, second))
	assert_false(Yard.ring_keeps_paths(grid, both), "앞 칸을 막은 뒤 다음 고리를 검사")
	assert_true(Yard.paths_preserved(grid, guard, {first[0]: true}))
	assert_true(Yard.paths_preserved(grid, guard, {second[0]: true}))
	var walk: PackedByteArray = Yard._walk_mask(grid)
	var before_walk: PackedByteArray = walk.duplicate()
	assert_false(Yard.paths_preserved(grid, guard, blocked, walk), "두 칸을 모두 막으면 길이 끊김")
	assert_eq(walk, before_walk, "거절된 후보의 임시 막힘은 표에서 복원")
	assert_true(Yard.paths_preserved(grid, guard, {}, walk), "복원된 표로 다음 검사 가능")


func test_ring_with_existing_low_and_walls_matches_independent_bfs() -> void:
	var grid: Grid = _two_cell_gap_grid()
	grid.set_solid(Vector2i(4, 2), S.LOW)
	var guard: Dictionary = Yard.path_guard(grid)
	var single: Array[Vector2i] = [Vector2i(4, 3)]
	var pair: Array[Vector2i] = [Vector2i(4, 3), Vector2i(4, 4)]
	var single_blocked: Dictionary = {single[0]: true}
	var pair_blocked: Dictionary = {pair[0]: true, pair[1]: true}
	var single_preserved: bool = _paths_by_walk(grid, guard, single_blocked)
	var pair_preserved: bool = _paths_by_walk(grid, guard, pair_blocked)
	assert_true(single_preserved, "독립 4이웃 BFS: 한 칸은 우회 가능")
	assert_false(pair_preserved, "독립 4이웃 BFS: 두 칸은 통로를 끊음")
	assert_eq(Yard.ring_keeps_paths(grid, single), single_preserved, "LOW·벽이 섞인 고리의 한 칸")
	assert_eq(Yard.ring_keeps_paths(grid, pair), pair_preserved, "LOW·벽이 섞인 고리의 두 칸")
	assert_eq(Yard.paths_preserved(grid, guard, pair_blocked), pair_preserved)


func test_placed_laundry_in_both_orientations_registers_only_its_posts() -> void:
	for orientation in range(2):
		var grid: Grid = Grid.new(24, 24)
		grid.set_solid(Vector2i.ZERO, S.LOW)
		var size: Vector2i = Vector2i(6, 1) if orientation == 0 else Vector2i(1, 6)
		var footprint: Rect2i = Rect2i(Vector2i(3, 3), size)
		var cells: Array[Vector2i] = Yard._rect_cells(footprint)
		var owners: Dictionary = {}
		for owned: Vector2i in cells:
			owners[owned] = 0
		# 한 줄짜리 소유 영역에서 첫 앵커만 맞는다. 실제 굴림으로 해당 방향의 씨앗을 고른다.
		var seed_value: int = -1
		for tried_seed in range(256):
			if Yard._roll(tried_seed, 401, grid.index(footprint.position)) % 2 == orientation:
				seed_value = tried_seed
				break
		assert_gte(seed_value, 0, "실제 facing 굴림에서 시험 방향을 확보")
		if seed_value < 0:
			continue
		var home: Dictionary = {"building": 0, "name": "빨랫줄 시험 집", "rect": Rect2i(8, 12, 3, 3),
			"front": Vector2i.DOWN, "cells": cells, "seed": seed_value}
		var data: Dictionary = {"grid": grid, "props": [], "low_blocks": [Rect2i(0, 0, 1, 1)]}
		var before_low: int = data["low_blocks"].size()
		var state: Dictionary = {"owners": owners, "forbidden": {}, "used": {}, "fronts": [],
			"fences": {}, "models": {"laundry_line": true}, "remaining": 1,
			"guard": Yard.path_guard(grid), "walk": Yard._walk_mask(grid), "full_checks": 0}
		Yard._cache_home(home, state)
		var placed: bool = Yard._place(data, home, state, "laundry_line", "laundry", 400)
		assert_true(placed, "가로·세로 빨랫줄의 실제 후보 검사·배치")
		if not placed:
			continue
		assert_eq(data["props"].size(), 1)
		assert_eq(data["props"][0]["rect"], footprint)
		assert_eq(int(data["props"][0]["facing"]) % 2, orientation)
		var expected_posts: Dictionary = {footprint.position: true, footprint.end - Vector2i.ONE: true}
		var registered: Dictionary = {}
		for low_rect: Rect2i in data["low_blocks"].slice(before_low):
			for registered_cell: Vector2i in Yard._rect_cells(low_rect):
				registered[registered_cell] = true
		assert_eq(registered, expected_posts, "새 low_blocks의 칸 집합은 두 기둥과 정확히 같음")
		assert_eq(data["low_blocks"].size() - before_low, 2)
		for checked_cell: Vector2i in cells:
			if expected_posts.has(checked_cell):
				assert_eq(grid.solid_at(checked_cell), S.LOW)
			else:
				assert_eq(grid.solid_at(checked_cell), S.NONE, "가운데 네 칸은 LOW가 아님")
