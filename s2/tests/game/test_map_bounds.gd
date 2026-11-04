extends "res://addons/gut/test.gd"
## PR1a 계약. 전체 504건 비교는 리드가 같은 뽑기 도구(tools/bounds_baseline_dump.gd)로 별도 수행한다.

const BoundsDigest = preload("res://tests/game/bounds_digest.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const MapBounds = preload("res://game/world/map_bounds.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const MapRing = preload("res://game/world/map_ring.gd")
const StopLoader = preload("res://game/stop_loader.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")
const SidePath = preload("res://game/world/side_path.gd")
## 경계를 켜지 않은 지도 20장면의 지문. 표본에 든 지도를 일부러 바꾼 PR은 다시 뽑아 같이 커밋한다(REDUMP).
const BASELINE: String = "res://tests/fixtures/bounds_baseline_sample.json"
const REDUMP: String = "godot --headless --path s2 -s res://tools/bounds_baseline_dump.gd -- --sample"
const WIDTHS: Array[int] = [30, 36, 42, 48]
const SHIFT: Vector2i = Vector2i(30, 36)


class BoundedLine extends RefCounted:
	static func build() -> Dictionary:
		var data: Dictionary = preload("res://tests/game/fixtures/bare_line_map.gd").build()
		data["bounds"] = {"rule": 1, "made_by": "hand", "outline": [Vector2i(0, 0), Vector2i(12, 0),
			Vector2i(12, 12), Vector2i(0, 12)], "runs": [{"from": 0, "to": 4, "kind": "forest"}],
			"gaps": [], "sides": [0, 0, 0, 0]}
		return data


class BoundedSideLine extends RefCounted:
	static func build() -> Dictionary:
		var data: Dictionary = BoundedLine.build()
		data = MapShift.grow(data, 0, 0, 80, 100)
		data["place_id"] = "bounds_probe"
		return data


func _sample() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	assert_true(parsed is Dictionary, "표본 JSON을 읽을 수 있어야 합니다")
	if not parsed is Dictionary:
		return {}
	assert_eq(int(parsed.get("digest_version", -1)), BoundsDigest.VERSION, "지문 판이 바뀌었으면 표본을 다시 뽑는다: " + REDUMP)
	assert_true(bool(parsed.get("sample", false)), "표본 모드로 뽑은 파일")
	return parsed.get("cases", {})


func _built_case(key: String) -> Dictionary:
	var parts: PackedStringArray = key.split("|", true)
	assert_eq(parts.size(), 4, key)
	assert_eq(parts[2], "71", key)
	return StopLoader.make_ready(load(FieldMaps.path_of(parts[0])), 71, parts[1], -1.0, parts[3])


static func _changed_items(first: Dictionary, second: Dictionary) -> Array[String]:
	var keys: Dictionary = first.duplicate()
	keys.merge(second)
	var changed: Array[String] = []
	for key: String in keys:
		if not first.has(key) or not second.has(key) or first[key] != second[key]:
			changed.append(key)
	changed.sort()
	return changed


func test_sample_20_matches_baseline() -> void:
	var cases: Dictionary = _sample()
	assert_eq(cases.size(), 20)
	for key: String in cases:
		var data: Dictionary = _built_case(key)
		var changed: Array[String] = _changed_items(cases[key], BoundsDigest.digest(data))
		assert_true(changed.is_empty(), ("%s changed=%s — 이 PR이 그 지도를 일부러 바꿨으면 표본을 다시 뽑아 같이 커밋: %s"
			+ " / 지도를 안 건드렸는데 달라졌으면 경계·로더·고리 회귀다.") % [key, str(changed), REDUMP])
		assert_false(data.has("bounds_stamp"), key + ": 꺼진 지도에는 찍기 표시가 없습니다")
		var ring: Dictionary = data.get("map_ring", {})
		if not ring.is_empty():
			assert_true(ring.has("sides"), key + ": 네 폭 기록")
			var width: int = int(ring["width"])
			assert_eq(ring.get("sides"), [width, width, width, width], key + ": 균일한 네 폭")
		data.clear()


func test_same_sample_input_twice_has_same_digest() -> void:
	var cases: Dictionary = _sample()
	if cases.is_empty():
		fail_test("표본이 없습니다")
		return
	var key: String = cases.keys()[0]
	var first: Dictionary = _built_case(key)
	var fingerprint: Dictionary = BoundsDigest.digest(first)
	first.clear()
	var second: Dictionary = _built_case(key)
	var changed: Array[String] = _changed_items(fingerprint, BoundsDigest.digest(second))
	assert_true(changed.is_empty(), "%s changed=%s" % [key, str(changed)])


func test_digest_detects_cell_entry_and_planned_tree_changes() -> void:
	var cases: Dictionary = _sample()
	if cases.is_empty():
		fail_test("표본이 없습니다")
		return
	var data: Dictionary = _built_case(cases.keys()[0])
	var before: Dictionary = BoundsDigest.digest(data)
	var grid: FieldGrid = data["grid"]
	var old_floor: int = grid.floor[0]
	grid.floor[0] = (old_floor + 1) % FieldGrid.Floor.size()
	assert_true(_changed_items(before, BoundsDigest.digest(data)).has("grid/floor"), "칸 하나")
	grid.floor[0] = old_floor
	var entries: Dictionary = data["entries"]
	assert_false(entries.is_empty())
	if entries.is_empty():
		return
	var cells: Array = entries[entries.keys()[0]]
	assert_false(cells.is_empty())
	if cells.is_empty():
		return
	var entry: Vector2i = cells[0]
	cells[0] = entry + Vector2i.ONE
	assert_true(_changed_items(before, BoundsDigest.digest(data)).has("map/entries"), "진입로 하나")
	cells[0] = entry
	var trees: Array = data["_edge_plan"]["plan"]["trees"]
	assert_false(trees.is_empty())
	if trees.is_empty():
		return
	var tree: Dictionary = trees[0]
	var tree_at: Vector3 = tree["at"]
	tree["at"] = tree_at + Vector3(0.25, 0, 0)
	assert_true(_changed_items(before, BoundsDigest.digest(data)).has("edge/plan/trees"), "계획 나무 하나")
	tree["at"] = tree_at
	assert_eq(BoundsDigest.digest(data), before, "변조를 되돌리면 원 지문입니다")


func _map() -> Dictionary:
	var levels: Dictionary = {}
	for level in [-1, 0, 1, 2]:
		var grid := FieldGrid.new(24, 18)
		for i in range(grid.width * grid.height):
			grid.solid[i] = FieldGrid.Solid.LOW if i % 11 == 0 else FieldGrid.Solid.NONE
			grid.floor[i] = i % FieldGrid.Floor.size()
			grid.building[i] = 7 if i % 5 == 0 else -1
			grid.zone[i] = "층%d/%d" % [level, i % 3]
		grid.solid[grid.index(Vector2i(3, 4))] = FieldGrid.Solid.DOOR
		grid.doors[Vector2i(3, 4)] = {"state": "closed", "hp": 20, "building": 7, "key": ""}
		grid.solid[grid.index(Vector2i(5, 6))] = FieldGrid.Solid.WINDOW
		grid.windows[Vector2i(5, 6)] = {"broken": false, "glass": true, "building": 7, "open": false,
			"latched": false, "stuck": false, "curtain": ""}
		grid.floor_glass[Vector2i(7, 8)] = Vector2i(5, 6)
		grid.refresh_paths()
		levels[level] = grid
	return {"grid": levels[0], "levels": levels, "place_id": "bounds_probe", "place_kind": "houses",
		"buildings": [], "containers": {}, "props": [], "trees": [], "low_blocks": [], "stairs": [],
		"entries": {"west": [Vector2i(0, 8)], "east": [Vector2i(23, 8)],
			"north": [Vector2i(10, 0)], "south": [Vector2i(10, 17)]},
		"anchors": {"flee_exit": Vector2i(0, 8)}, "hole_faces": {"way": Vector2i.UP},
		"geometry": {Vector2i(1, 2): Vector2i(3, 4), Rect2i(2, 3, 4, 5): Rect2i(6, 7, 8, 9),
			Vector3(1.5, 2.0, 3.5): Vector3(4.5, 6.0, 7.5)},
		"nested": [{"cell": Vector2i(1, 2), "rect": Rect2i(2, 3, 4, 5), "pos": Vector3(1, 2, 3), "side": Vector2i.LEFT}]}


func _assert_shifted(was: Dictionary, now: Dictionary) -> void:
	for level: int in was["levels"]:
		var old: FieldGrid = was["levels"][level]
		var grown: FieldGrid = now["levels"][level]
		assert_eq(Vector2i(grown.width, grown.height), Vector2i(old.width + 72, old.height + 84))
		for key: String in BoundsDigest.GRID_ARRAYS:
			var same: bool = true
			for y in range(old.height):
				for x in range(old.width):
					var at := Vector2i(x, y)
					if old.get(key)[old.index(at)] != grown.get(key)[grown.index(at + SHIFT)]:
						same = false
			assert_true(same, "층 %d %s: 옛 칸 전체 보존" % [level, key])
		for cell: Vector2i in old.doors:
			assert_eq(grown.doors.get(cell + SHIFT), old.doors[cell], "문")
		for cell: Vector2i in old.windows:
			assert_eq(grown.windows.get(cell + SHIFT), old.windows[cell], "창")
		for cell: Vector2i in old.floor_glass:
			assert_eq(grown.floor_glass.get(cell + SHIFT), old.floor_glass[cell] + SHIFT, "유리의 키와 값")
		var paths_same: bool = true
		for y in range(old.height):
			for x in range(old.width):
				var at := Vector2i(x, y)
				if old.people_path.is_point_solid(at) != grown.people_path.is_point_solid(at + SHIFT) \
						or old.dead_path.is_point_solid(at) != grown.dead_path.is_point_solid(at + SHIFT):
					paths_same = false
		assert_true(paths_same, "층 %d: 두 길찾기 보존" % level)
	assert_eq(now["geometry"], {Vector2i(31, 38): Vector2i(33, 40),
		Rect2i(32, 39, 4, 5): Rect2i(36, 43, 8, 9), Vector3(31.5, 2.0, 39.5): Vector3(34.5, 6.0, 43.5)})
	assert_eq(now["nested"], [{"cell": Vector2i(31, 38), "rect": Rect2i(32, 39, 4, 5),
		"pos": Vector3(31, 2, 39), "side": Vector2i.LEFT}])
	assert_eq(now["hole_faces"], was["hole_faces"], "방향은 그대로")


func test_grow_four_different_widths_preserves_every_level_and_position() -> void:
	var was: Dictionary = _map()
	var now: Dictionary = MapShift.grow(was, WIDTHS[0], WIDTHS[1], WIDTHS[2], WIDTHS[3])
	_assert_shifted(was, now)
	for key: String in was["entries"]:
		assert_eq(now["entries"][key][0], was["entries"][key][0] + SHIFT)


func test_ring_four_different_widths_keeps_inner_and_moves_entries_to_edge() -> void:
	var was: Dictionary = _map()
	var now: Dictionary = MapRing.add(was, WIDTHS)
	_assert_shifted(was, now)
	assert_eq(now["map_ring"]["inner"], Rect2i(30, 36, 24, 18))
	assert_true(now["map_ring"].has("sides"))
	assert_eq(now["map_ring"].get("sides"), WIDTHS)
	assert_eq(now["map_ring"]["roads"].slice(0, 4), [Rect2i(15, 18, 60, 2),
		Rect2i(15, 76, 60, 2), Rect2i(15, 18, 2, 60), Rect2i(73, 18, 2, 60)], "네 폭 각각의 둘레 길")
	assert_eq(now["entries"], {"west": [Vector2i(0, 44)], "east": [Vector2i(95, 44)],
		"north": [Vector2i(40, 0)], "south": [Vector2i(40, 101)]})
	assert_eq(now["anchors"]["flee_exit"], Vector2i(0, 44))
	assert_eq(was["entries"]["west"][0], Vector2i(0, 8), "원본 보존")


func test_regional_lots_keep_the_inset_on_all_four_sides() -> void:
	var grid := FieldGrid.new(100, 100)
	var anchor := Rect2i(30, 30, 12, 7)
	var expected: Array[Rect2i] = [Rect2i(30, 12, 12, 7), Rect2i(81, 30, 7, 12),
		Rect2i(30, 81, 12, 7), Rect2i(12, 30, 7, 12)]
	for side in range(4):
		assert_eq(MapRing._regional_rect(grid, anchor, side, 12, 7, 10), expected[side])


func _bounds() -> Dictionary:
	return {"rule": 1, "made_by": "hand", "outline": [Vector2i(0, 0), Vector2i(12, 0),
		Vector2i(12, 12), Vector2i(0, 12)], "runs": [{"from": 0, "to": 4, "kind": "forest"}],
		"gaps": [], "sides": [0, 0, 0, 0]}


func test_check_accepts_clockwise_implicit_closure() -> void:
	assert_true(MapBounds.check(_bounds(), FieldGrid.new(12, 12)).is_empty())
	var concave: Dictionary = _bounds()
	concave["outline"] = [Vector2i(0, 0), Vector2i(12, 0), Vector2i(12, 6),
		Vector2i(6, 6), Vector2i(6, 12), Vector2i(0, 12)]
	concave["runs"] = [{"from": 0, "to": 2, "kind": "water"}, {"from": 2, "to": 6, "kind": "forest"}]
	assert_true(MapBounds.check(concave, FieldGrid.new(12, 12)).is_empty(), "오목한 윤곽과 나뉜 구간")


func test_check_rejects_wrong_types_and_outside_vertices() -> void:
	for pair: Array in [["rule", "1"], ["rule", -1], ["outline", {}], ["runs", {}],
		["made_by", "unknown"], ["sides", [0, 0, 0]], ["sides", [0, 0, -1, 0]], ["gaps", [3]]]:
		var bounds: Dictionary = _bounds()
		bounds[pair[0]] = pair[1]
		assert_false(MapBounds.check(bounds, FieldGrid.new(12, 12)).is_empty(), str(pair))
	for point: Variant in [Vector2(0, 0), Vector2i(-1, 0), Vector2i(13, 0)]:
		var bounds: Dictionary = _bounds()
		bounds["outline"][0] = point
		assert_false(MapBounds.check(bounds, FieldGrid.new(12, 12)).is_empty(), str(point))


func test_check_rejects_open_closing_edge_diagonal_overlap_and_counterclockwise() -> void:
	var cases: Dictionary = {
		"닫는 변이 대각선": [Vector2i(0, 0), Vector2i(10, 0), Vector2i(10, 10), Vector2i(4, 10)],
		"중간 대각 변": [Vector2i(0, 0), Vector2i(10, 2), Vector2i(10, 10), Vector2i(0, 10)],
		"자기 교차": [Vector2i(1, 1), Vector2i(9, 1), Vector2i(9, 9), Vector2i(5, 9),
			Vector2i(5, 0), Vector2i(3, 0), Vector2i(3, 7), Vector2i(1, 7)],
		"겹친 변": [Vector2i(0, 0), Vector2i(10, 0), Vector2i(4, 0), Vector2i(4, 8), Vector2i(0, 8)],
		"반시계": [Vector2i(0, 0), Vector2i(0, 10), Vector2i(10, 10), Vector2i(10, 0)],
		"첫 점 반복": [Vector2i(0, 0), Vector2i(10, 0), Vector2i(10, 10), Vector2i(0, 10), Vector2i(0, 0)],
	}
	for label: String in cases:
		var bounds: Dictionary = _bounds()
		bounds["outline"] = cases[label]
		bounds["runs"][0]["to"] = cases[label].size()
		assert_false(MapBounds.check(bounds, FieldGrid.new(12, 12)).is_empty(), label)


func test_check_rejects_missing_overlapping_and_unordered_runs() -> void:
	for spans: Array in [[[0, 3]], [[0, 2], [3, 4]], [[0, 3], [2, 4]], [[2, 4], [0, 2]], [[0, 0], [0, 4]]]:
		var bounds: Dictionary = _bounds()
		bounds["runs"] = []
		for span: Array in spans:
			bounds["runs"].append({"from": span[0], "to": span[1], "kind": "water"})
		assert_false(MapBounds.check(bounds, FieldGrid.new(12, 12)).is_empty(), str(spans))


func test_empty_and_rule_zero_are_off_and_stamp_blocks_grow() -> void:
	var grid := FieldGrid.new(12, 12)
	for bounds: Dictionary in [{}, {"rule": 0, "outline": "꺼지면 검사하지 않음"}]:
		var data: Dictionary = {"grid": grid, "bounds": bounds}
		assert_true(MapBounds.check(bounds, grid).is_empty())
		assert_true(is_same(MapBounds.apply(data), data))
		assert_false(data.has("bounds_stamp"))
		assert_true(MapShift.can_grow(data))
	var active: Dictionary = {"grid": grid, "bounds": _bounds()}
	assert_true(is_same(MapBounds.apply(active, 0), active), "저장 판 0은 켜진 자료도 끕니다")
	assert_false(active.has("bounds_stamp"))
	MapBounds.apply(active, 99)
	assert_false(active.has("bounds_stamp"), "알 수 없는 저장 판을 다른 판으로 찍지 않습니다")
	MapBounds.apply(active)
	assert_eq(active["bounds_stamp"], 1)
	assert_false(MapShift.can_grow(active), "찍힌 뒤 확대 금지")
	assert_true(is_same(MapBounds.apply(active, 1), active), "같은 판은 한 번만 찍습니다")
	assert_eq(grid.solid.count(FieldGrid.Solid.NONE), 144, "계약만으로 지형을 바꾸지 않습니다")


func _assert_bounds_unchanged(data: Dictionary, snapshot: Dictionary, fingerprint: Dictionary) -> void:
	# 자료와 경계 기록 보존(이 GUT의 assert_eq_deep은 메시지 인자를 받지 않는다).
	assert_eq_deep(data, snapshot)
	assert_eq(BoundsDigest.digest(data), fingerprint, "격자와 경로 및 계획 지문 보존")
	for level: Variant in snapshot["levels"]:
		assert_true(is_same(data["levels"][level], snapshot["levels"][level]), "격자 객체 보존")


func test_stamped_grow_and_side_path_growth_are_rejected_without_mutation() -> void:
	var data: Dictionary = StopLoader.make_ready(BoundedLine, 71)
	data["place_id"] = "bounds_probe"
	var snapshot: Dictionary = data.duplicate(true)
	var fingerprint: Dictionary = BoundsDigest.digest(data)
	assert_true(is_same(MapShift.grow(data, 1, 2, 3, 4), data))
	assert_push_error("찍힌 경계 뒤에는 지도를 키울 수 없습니다")
	_assert_bounds_unchanged(data, snapshot, fingerprint)
	for side: int in [1, 2]:
		assert_true(is_same(SidePath._grow(data, side), data))
		assert_push_error("찍힌 경계 뒤에는 샛길을 넓힐 수 없습니다")
		_assert_bounds_unchanged(data, snapshot, fingerprint)
	assert_true(is_same(SidePath.add(data, 71), data))
	assert_push_error("찍힌 경계 뒤에는 샛길을 더할 수 없습니다")
	_assert_bounds_unchanged(data, snapshot, fingerprint)


func test_same_rule_apply_twice_preserves_data_and_digest() -> void:
	var data: Dictionary = StopLoader.make_ready(BoundedLine, 71, "", -1.0, "", 0)
	MapBounds.apply(data, 1)
	assert_eq(data.get("bounds_stamp"), 1)
	var snapshot: Dictionary = data.duplicate(true)
	var fingerprint: Dictionary = BoundsDigest.digest(data)
	assert_true(is_same(MapBounds.apply(data, 1), data))
	_assert_bounds_unchanged(data, snapshot, fingerprint)
	assert_push_error_count(0)


func test_unknown_seed_defers_bounds_until_side_path() -> void:
	var data: Dictionary = StopLoader.make_ready(BoundedSideLine, -1)
	assert_false(data.has("bounds_stamp"), "씨앗을 모르면 경계를 찍지 않음")
	assert_false(data.has("_side_seed"))
	# 미리 짓기는 꺼진 지도와 같이 그대로 한다. 샛길이 붙으면 필드가 버리고 다시 짓는다.
	assert_true(data.has("_edge_plan"))
	assert_true(data.has("_building_plan"))
	var run_seed: int = -1
	for candidate: int in range(1, 200):
		if SidePath.rolls("bounds_probe", candidate):
			run_seed = candidate
			break
	assert_gt(run_seed, 0)
	var before: Vector2i = Vector2i(data["grid"].width, data["grid"].height)
	data = FieldGame.with_side_path(data, run_seed)
	assert_true(data.has("side_path"), "경계를 찍기 전에 실제 샛길 확대")
	assert_ne(Vector2i(data["grid"].width, data["grid"].height), before)
	for key: String in FieldGame.AHEAD_KEYS:
		assert_false(data.has(key), "샛길이 붙으면 옛 미리 짓기는 버림: " + key)
	MapBounds.apply(data)
	assert_eq(data.get("bounds_stamp"), 1, "씨앗 확정과 샛길 뒤 찍기")
	var ready: Dictionary = StopLoader.make_ready(BoundedSideLine, run_seed)
	assert_eq(ready.get("_side_seed"), run_seed)
	assert_eq(ready.get("bounds_stamp"), 1)
	assert_true(ready.has("_edge_plan"))
	assert_eq(ready["grid"].solid, data["grid"].solid)
	assert_eq(ready["grid"].floor, data["grid"].floor)
	assert_eq_deep(ready["side_path"], data["side_path"])
	assert_eq_deep(ready["bounds"], data["bounds"])
	assert_true(is_same(FieldGame.with_side_path(ready, run_seed), ready))
	assert_push_error_count(0)


func test_worker_receives_requested_rule() -> void:
	for rule: int in [0, 1, 99]:
		var box: Dictionary = {}
		StopLoader._build_off_thread(box, BoundedLine, 71, "", -1.0, "", 0, rule)
		var data: Dictionary = box["data"]
		assert_eq(int(data.get("bounds_stamp", 0)), 1 if rule == 1 else 0)


func test_thread_binding_passes_the_requested_rule() -> void:
	for rule: int in [0, 1, 99]:
		var loader = StopLoader.new()
		add_child_autofree(loader)
		loader.seed_for = 71
		loader.bounds_rule_for = rule
		loader.vat = {"skip_baking": true}
		loader._start_task(BoundedLine)
		if not loader.has_data():
			await wait_for_signal(loader.data_ready, 30)
		assert_true(loader.has_data())
		assert_eq(int(loader.data.get("bounds_stamp", 0)), 1 if rule == 1 else 0)


func test_direct_field_rebuilds_a_different_stamped_rule() -> void:
	var prepared: Dictionary = StopLoader.make_ready(BoundedLine, 71)
	var game = FieldGame.new()
	game.opts = {"seed": 71, "auto_pause": false, "bounds_rule": 0, "map_data": prepared}
	game.map_script = BoundedLine
	add_child_autofree(game)
	game.set_process(false)
	assert_false(is_same(game.data["grid"], prepared["grid"]))
	assert_false(game.data.has("bounds_stamp"))
	assert_eq(prepared.get("bounds_stamp"), 1)


func test_bounds_rule_capture_json_resume_and_legacy_zero() -> void:
	var game = FieldGame.new()
	game.opts = {"seed": 4, "auto_pause": false, "bounds_rule": 0}
	game.map_script = BareLine
	add_child_autofree(game)
	game.set_process(false)
	for rule in [0, 1]:
		game.data.erase("bounds_stamp")
		if rule > 0:
			game.data["bounds_stamp"] = rule
		var saved: Dictionary = FieldSave.capture(game)
		assert_eq(saved["bounds_rule"], rule)
		assert_eq(saved["version"], 2, "저장 판 번호를 올리지 않습니다")
		assert_false(saved["start_opts"].has("bounds_rule"))
		var back: Dictionary = FieldSave.from_json(FieldSave.to_json(saved))
		assert_false(back.is_empty())
		assert_eq(FieldSave.resume_opts(back)["bounds_rule"], rule)
		back.erase("bounds_rule")
		back["start_opts"]["bounds_rule"] = 99
		assert_eq(FieldSave.resume_opts(back)["bounds_rule"], 0, "키 없는 옛 저장은 판 0이 이깁니다")
