extends GutTest

const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const Ring = preload("res://game/world/map_ring.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const StopGround = preload("res://game/world/stop_ground.gd")
const SidePath = preload("res://game/world/side_path.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")
const S = FieldGrid.Solid
# 실제 지도는 세 종류만 짓고 읽기 전용으로 공유한다. 나머지는 작은 손 지도다.
static var _built: Dictionary = {}


func after_all() -> void:
	_built.clear()


func _map(place: String) -> Dictionary:
	if not _built.has(place):
		_built[place] = FieldMaps.build(place)
	return _built[place]


func _small(width: int = 5, height: int = 5) -> Dictionary:
	var g := FieldGrid.new(width, height)
	g.refresh_paths()
	return {"grid": g, "levels": {0: g}, "place_id": "flee_fixture"}


func _label(data: Dictionary) -> String:
	var g: FieldGrid = data["grid"]
	return "%s flee_exit=%s size=%dx%d" % [data.get("place_id", "fixture"),
		data.get("anchors", {}).get("flee_exit"), g.width, g.height]


func _assert_edge(data: Dictionary) -> void:
	var g: FieldGrid = data["grid"]
	var cell: Variant = data.get("anchors", {}).get("flee_exit")
	assert_true(cell is Vector2i, _label(data) + ": 출구 존재")
	if not cell is Vector2i:
		return
	assert_true(g.inside(cell) and (cell.x == 0 or cell.x == g.width - 1
		or cell.y == 0 or cell.y == g.height - 1), _label(data) + ": 최종 경계")
	assert_true(g.people_can_walk(cell), _label(data) + ": 보행 가능")


func test_source_flag_is_recorded_before_anchor_merge() -> void:
	assert_eq(_map("lodge_01").get("flee_exit_set"), false, "lodge_01: 원본에 출구 없음")
	for place: String in ["church_01", "houses_01"]:
		assert_eq(_map(place).get("flee_exit_set"), true, place + ": 원본이 출구 지정")


func test_ring_only_translates_the_other_named_anchors() -> void:
	var script: Script = load(FieldMaps.path_of("church_01"))
	var raw: Dictionary = script.build()
	var data: Dictionary = _map("church_01")
	var inner: Rect2i = data["map_ring"]["inner"]
	for key: String in ["whistle", "engine", "horde_home"]:
		assert_eq(data["anchors"][key], raw["anchors"][key] + inner.position, key + ": 기존 평행이동")
	_assert_edge(data)


func test_own_corners_follow_the_same_side_priority_as_entries() -> void:
	var inner := Rect2i(2, 2, 5, 4)
	for pair: Array in [[Vector2i(2, 2), Vector2i(0, 2)], [Vector2i(6, 2), Vector2i(8, 2)],
		[Vector2i(2, 5), Vector2i(0, 5)], [Vector2i(6, 5), Vector2i(8, 5)],
		[Vector2i(4, 2), Vector2i(4, 0)], [Vector2i(4, 5), Vector2i(4, 7)]]:
		var data: Dictionary = _small(9, 8)
		data["anchors"] = {"flee_exit": pair[0], "whistle": Vector2i(4, 4)}
		data["flee_exit_set"] = true
		Ring.finish_flee_exit(data, inner)
		assert_eq(data["anchors"]["flee_exit"], pair[1], _label(data))
		assert_eq(data["anchors"]["whistle"], Vector2i(4, 4))
		_assert_edge(data)


func test_calculated_and_unmarked_exits_are_recomputed_on_the_final_grid() -> void:
	for marked: bool in [false, true]:
		var data: Dictionary = _small()
		data["anchors"] = {"flee_exit": Vector2i(0, 2)}
		if marked:
			data["flee_exit_set"] = false
		var expected: Vector2i = FieldMaps.anchors(data)["flee_exit"]
		assert_ne(expected, data["anchors"]["flee_exit"], "입력은 재계산과 다른 경계 칸")
		Ring.finish_flee_exit(data)
		assert_eq(data["anchors"]["flee_exit"], expected, _label(data))
		_assert_edge(data)


func test_own_walkable_exit_is_kept_even_when_not_the_farthest() -> void:
	var data: Dictionary = _small()
	data["anchors"] = {"flee_exit": Vector2i(0, 2)}
	data["flee_exit_set"] = true
	Ring.finish_flee_exit(data)
	assert_eq(data["anchors"]["flee_exit"], Vector2i(0, 2), _label(data))
	_assert_edge(data)


func test_blocked_projection_falls_back_to_an_open_final_edge() -> void:
	var data: Dictionary = _small(9, 8)
	var g: FieldGrid = data["grid"]
	data["anchors"] = {"flee_exit": Vector2i(2, 3)}
	data["flee_exit_set"] = true
	g.set_solid(Vector2i(0, 3), S.BLOCK)
	# 2차 규칙: 원래 칸도 막혔을 때에만 새 경계에서 다시 고른다.
	g.set_solid(Vector2i(2, 3), S.BLOCK)
	g.refresh_paths()
	Ring.finish_flee_exit(data, Rect2i(2, 2, 5, 4))
	assert_ne(data["anchors"]["flee_exit"], Vector2i(0, 3))
	_assert_edge(data)


func _block_edge(data: Dictionary) -> void:
	var g: FieldGrid = data["grid"]
	for y in range(g.height):
		for x in range(g.width):
			if x == 0 or x == g.width - 1 or y == 0 or y == g.height - 1:
				g.set_solid(Vector2i(x, y), S.BLOCK)
	g.refresh_paths()


func test_no_walkable_border_warns_and_preserves_the_existing_value() -> void:
	var data: Dictionary = _small()
	data["anchors"] = {"flee_exit": Vector2i(2, 2), "engine": Vector2i(1, 1)}
	data["flee_exit_set"] = true
	_block_edge(data)
	var before: Dictionary = data["anchors"].duplicate()
	Ring.finish_flee_exit(data, Rect2i(2, 2, 1, 1))
	assert_eq(data["anchors"], before, _label(data) + ": 실패 때 옛 출구 보존")
	assert_push_warning_count(1)


func test_missing_exit_is_created_only_if_a_walkable_edge_exists() -> void:
	var data: Dictionary = _small()
	Ring.finish_flee_exit(data)
	_assert_edge(data)
	var blocked: Dictionary = _small()
	_block_edge(blocked)
	Ring.finish_flee_exit(blocked)
	assert_false(blocked.has("anchors"), "막힌 지도에 집결지를 출구로 만들어 넣지 않음")
	assert_push_warning_count(1)


func test_edge_scan_keeps_row_order_ties_and_handles_single_cell_grids() -> void:
	var data: Dictionary = _small(3, 3)
	Ring.finish_flee_exit(data)
	assert_eq(data["anchors"]["flee_exit"], Vector2i.ZERO, "같은 거리면 위에서 아래, 왼쪽에서 오른쪽")
	var first: Vector2i = data["anchors"]["flee_exit"]
	Ring.finish_flee_exit(data)
	assert_eq(data["anchors"]["flee_exit"], first, "다시 확정해도 같음")
	for size: Vector2i in [Vector2i.ONE, Vector2i(1, 4), Vector2i(4, 1)]:
		var narrow: Dictionary = _small(size.x, size.y)
		Ring.finish_flee_exit(narrow)
		_assert_edge(narrow)


func test_edge_choice_uses_door_precedence_and_the_farthest_open_noncorner() -> void:
	var data: Dictionary = _small(7, 5)
	var g: FieldGrid = data["grid"]
	g.set_solid(Vector2i.ZERO, S.BLOCK)
	g.refresh_paths()
	data["anchors"] = {"horde_home": Vector2i.ZERO}
	data["train_doors"] = {"lower": [Vector2i(5, 3)], "upper": [Vector2i(1, 1)]}
	data["spawns"] = {"train_door": [Vector2i(6, 1)], "squad": [Vector2i(0, 4)]}
	# (5,3)에서 가장 먼 (0,0)은 막혔다. 남은 최댓값은 (0,1)의 거리 제곱 29.
	Ring.finish_flee_exit(data)
	assert_eq(data["anchors"]["flee_exit"], Vector2i(0, 1), _label(data))
	assert_eq(data["anchors"]["horde_home"], Vector2i.ZERO, "지도 고유 집결지를 바꾸지 않음")
	data["train_doors"]["lower"].clear()
	Ring.finish_flee_exit(data)
	assert_eq(data["anchors"]["flee_exit"], Vector2i(6, 4), "다음 우선순위는 위쪽 문")
	data["train_doors"]["upper"].clear()
	Ring.finish_flee_exit(data)
	assert_eq(data["anchors"]["flee_exit"], Vector2i(0, 4), "그다음은 spawns.train_door")
	data["spawns"]["train_door"].clear()
	Ring.finish_flee_exit(data)
	assert_eq(data["anchors"]["flee_exit"], Vector2i(6, 0), "마지막은 spawns.squad")
	_assert_edge(data)


# test_stop_ground.gd의 _small_map과 같은 열차/문/승강장 규약.
func _stop(to_right: bool) -> Dictionary:
	var data: Dictionary = _small(80, 40)
	var g: FieldGrid = data["grid"]
	var train := Rect2i(36, 20, 8, 3)
	for y in range(train.position.y, train.end.y):
		for x in range(g.width):
			g.floor[g.index(Vector2i(x, y))] = FieldGrid.Floor.RAIL
			if train.has_point(Vector2i(x, y)):
				g.set_solid(Vector2i(x, y), S.BLOCK)
	data.merge({"train": train, "train_cars": FieldMaps.cars_of(train),
		"train_doors": {"upper": [Vector2i(39, 19)], "lower": [Vector2i(39, 23)]},
		"spawns": {"train_door": [Vector2i(39, 23)], "squad": [Vector2i(39, 25)]},
		"buildings": [{"id": 0, "rect": Rect2i(10 if to_right else 66, 10, 4, 4)}],
		"platform": Rect2i(36, 23, 8, 4), "unload": Rect2i(36, 23, 8, 2),
		"entries": {"west": [Vector2i(0, 5)], "east": [Vector2i(79, 5)]},
		"anchors": {"flee_exit": Vector2i(79 if to_right else 0, 5),
			"whistle": Vector2i(42, 22), "engine": Vector2i(41, 21), "horde_home": Vector2i(39, 27)},
		"trees": [], "props": [], "lights": []})
	g.refresh_paths()
	return data


func test_stop_uses_false_source_flag_even_when_old_value_looks_owned() -> void:
	for to_right: bool in [false, true]:
		var was: Dictionary = _stop(to_right)
		was["flee_exit_set"] = false
		var now: Dictionary = StopGround.apply(was, "edge", 71, 200.0)
		assert_eq(now.get("stop_form"), "edge")
		assert_eq(now["anchors"]["flee_exit"], FieldMaps.anchors(now)["flee_exit"], _label(now))
		_assert_edge(now)


func test_stop_uses_true_flag_even_when_old_exit_equals_calculated_value() -> void:
	var was: Dictionary = _stop(true)
	was["anchors"]["flee_exit"] = FieldMaps.anchors(was)["flee_exit"]
	was["flee_exit_set"] = true
	var old_exit: Vector2i = was["anchors"]["flee_exit"]
	var now: Dictionary = StopGround.apply(was, "edge", 71, 200.0)
	var g: FieldGrid = now["grid"]
	assert_eq(now["anchors"]["flee_exit"], Vector2i(g.width - 1, old_exit.y), _label(now))
	assert_ne(now["anchors"]["flee_exit"], FieldMaps.anchors(now)["flee_exit"], "같은 옛 값이어도 출처로 구별")
	_assert_edge(now)


func test_legacy_stop_uses_value_fallback_without_changing_other_anchor_rules() -> void:
	for to_right: bool in [false, true]:
		var was: Dictionary = _stop(to_right)
		var now: Dictionary = StopGround.apply(was, "edge", 71, 200.0)
		var g: FieldGrid = now["grid"]
		assert_eq(now["anchors"]["flee_exit"], Vector2i(g.width - 1 if to_right else 0, 5), _label(now))
		var travel: Vector2i = now["train"].position - was["train"].position
		for key: String in ["whistle", "engine", "horde_home"]:
			assert_eq(now["anchors"][key], was["anchors"][key] + travel, key + ": 기존 열차 이동")
		_assert_edge(now)
		# 정차 흐름의 최종 확정에서는 출처 없는 넘겨받은 자료를 재계산한다.
		Ring.finish_flee_exit(now)
		assert_eq(now["anchors"]["flee_exit"], FieldMaps.anchors(now)["flee_exit"])


func test_missing_legacy_stop_exit_is_computed() -> void:
	var was: Dictionary = _stop(true)
	was["anchors"].erase("flee_exit")
	var now: Dictionary = StopGround.apply(was, "edge", 71, 200.0)
	assert_eq(now["anchors"]["flee_exit"], FieldMaps.anchors(now)["flee_exit"])
	_assert_edge(now)


func test_side_path_on_a_ringed_map_finishes_exit_and_only_shifts_other_anchors() -> void:
	var base: Dictionary = _map("houses_01")
	var result: Dictionary = {}
	for run_seed in range(1, 200):
		if not SidePath.rolls("houses_01", run_seed):
			continue
		# _grow는 levels 사전을 바꾸므로 사전/배열은 깊게 복사한다.
		var candidate: Dictionary = SidePath.add(base.duplicate(true), run_seed)
		if candidate.has("side_path"):
			result = candidate
			break
	assert_false(result.is_empty(), "houses_01: 유한한 씨앗 범위에서 실제 샛길이 있어야 함")
	if result.is_empty():
		return
	var side: int = result["side_path"]["side"]
	var offset: Vector2i = Vector2i(SidePath.STRIP, 0) if side == 3 else (Vector2i(0, SidePath.STRIP) if side == 0 else Vector2i.ZERO)
	for key: String in ["whistle", "engine", "horde_home"]:
		assert_eq(result["anchors"][key], base["anchors"][key] + offset, key + ": 샛길 평행이동")
	assert_eq(result.get("flee_exit_set"), true)
	_assert_edge(result)


func test_side_strip_all_four_directions_recompute_after_building_walk_data() -> void:
	for side in range(4):
		var data: Dictionary = _small(100, 100)
		data.merge({"train": Rect2i(46, 48, 8, 3), "buildings": [], "entries": {},
			"props": [], "containers": {}, "spawns": {"train_door": [Vector2i(50, 51)]},
			"anchors": {"flee_exit": SidePath._at(data["grid"], side, 50, 0)}, "flee_exit_set": false})
		if side == 0 or side == 3:
			data = MapShift.grow(data, SidePath.STRIP if side == 3 else 0,
				SidePath.STRIP if side == 0 else 0, 0, 0, false)
		else:
			data = SidePath._grow(data, side)
		var rng := RandomNumberGenerator.new()
		rng.seed = 71
		SidePath._build(data, {"side": side, "along": 40}, rng, 71)
		assert_eq(data["anchors"]["flee_exit"], FieldMaps.anchors(data)["flee_exit"], "샛길 방향 %d" % side)
		_assert_edge(data)


# 저장 시험은 test_field_save.gd와 같은 작은 fixture를 쓰며 파일 I/O를 하지 않는다.
func _game(extra: Dictionary = {}):
	var game = FieldGame.new()
	game.map_script = BareLine
	game.opts = {"seed": 4, "auto_pause": false, "raiders": false, "arrival_horde": false}
	game.opts.merge(extra, true)
	add_child_autofree(game)
	game.set_process(false)
	return game


func test_handed_map_without_source_flag_is_finalized_by_field_start() -> void:
	var handed: Dictionary = FieldMaps.build_from(BareLine)
	handed.erase("flee_exit_set")
	var g: FieldGrid = handed["grid"]
	handed["anchors"]["flee_exit"] = Vector2i(g.width / 2, g.height / 2)
	var game = _game({"map_data": handed})
	assert_eq(game.data["anchors"]["flee_exit"], FieldMaps.anchors(game.data)["flee_exit"])
	_assert_edge(game.data)


func test_exact_save_rechecks_exit_after_restoring_grid_obstacles() -> void:
	var original = _game()
	var blocked: Vector2i = original.data["anchors"]["flee_exit"]
	original.data["grid"].set_solid(blocked, S.BLOCK)
	original.data["grid"].refresh_paths()
	var saved: Dictionary = FieldSave.capture(original)
	assert_true(FieldSave.exact(saved), "격자를 복원하는 저장 경로")
	var restored = _game()
	FieldSave.apply(restored, saved)
	assert_false(restored.data["grid"].people_can_walk(blocked), "저장된 장애물이 실제 복원됨")
	assert_ne(restored.data["anchors"]["flee_exit"], blocked, "막힌 옛 출구를 다시 고름")
	_assert_edge(restored.data)


func test_legacy_save_keeps_version_and_recomputes_unmarked_exit() -> void:
	var game = _game()
	var saved: Dictionary = FieldSave.capture(game)
	saved["version"] = 1
	saved.erase("runtime")
	game.data.erase("flee_exit_set")
	var g: FieldGrid = game.data["grid"]
	game.data["anchors"]["flee_exit"] = Vector2i(g.width / 2, g.height / 2)
	FieldSave.apply(game, saved)
	assert_eq(saved["version"], 1, "옛 저장 판을 올리지 않음")
	assert_eq(game.data["anchors"]["flee_exit"], FieldMaps.anchors(game.data)["flee_exit"])
	_assert_edge(game.data)


func test_owned_blocked_projection_keeps_walkable_original() -> void:
	for marked: bool in [false, true]:
		var data: Dictionary = _small(9, 8)
		var g: FieldGrid = data["grid"]
		var original := Vector2i(2, 3)
		data["anchors"] = {"flee_exit": original, "whistle": Vector2i(4, 4)}
		if marked:
			data["flee_exit_set"] = true
		g.set_solid(Vector2i(0, 3), S.BLOCK)
		g.refresh_paths()
		Ring.finish_flee_exit(data, Rect2i(2, 2, 5, 4), not marked)
		assert_eq(data["anchors"]["flee_exit"], original, _label(data) + ": 숲 앞의 걸을 수 있는 칸 보존")
		assert_true(g.people_can_walk(original))
		assert_eq(data["anchors"]["whistle"], Vector2i(4, 4))
		if marked:
			# 최종 지도 인수에서 같은 확정 함수를 다시 불러도 예외를 잃지 않는다.
			Ring.finish_flee_exit(data)
			assert_eq(data["anchors"]["flee_exit"], original, "출처가 남은 출구는 재확정에도 보존")


func test_owned_blocked_projection_and_original_recompute() -> void:
	var data: Dictionary = _small(9, 8)
	var g: FieldGrid = data["grid"]
	data["anchors"] = {"flee_exit": Vector2i(2, 3)}
	data["flee_exit_set"] = true
	for cell: Vector2i in [Vector2i(0, 3), Vector2i(2, 3)]:
		g.set_solid(cell, S.BLOCK)
	g.refresh_paths()
	Ring.finish_flee_exit(data, Rect2i(2, 2, 5, 4))
	assert_eq(data["anchors"]["flee_exit"], FieldMaps.anchors(data)["flee_exit"], _label(data))
	_assert_edge(data)


# 지도 스크립트를 짓지 않고 작은 손 격자에 띠 변환만 적용한다.
func _legacy_ring_fixture() -> Dictionary:
	var data: Dictionary = _small(7, 6)
	data.merge({"place_kind": "lodge", "buildings": [], "containers": {}, "props": [],
		"trees": [], "low_blocks": [], "stairs": [],
		"entries": {"west": [Vector2i(0, 2)]},
		"anchors": {"flee_exit": Vector2i(0, 2), "whistle": Vector2i(3, 3)}})
	return data


func test_unmarked_exit_shared_with_ground_entry_follows_entry() -> void:
	var raw: Dictionary = _legacy_ring_fixture()
	var data: Dictionary = Ring.add(raw)
	var inner: Rect2i = data["map_ring"]["inner"]
	assert_eq(data["anchors"]["flee_exit"], data["entries"]["west"][0], _label(data))
	assert_eq(data["anchors"]["flee_exit"], Vector2i(0, inner.position.y + 2))
	assert_eq(data["anchors"]["whistle"], raw["anchors"]["whistle"] + inner.position)
	assert_false(data.has("flee_exit_set"), "호환 판정을 원본 출처 표시로 꾸미지 않음")
	assert_eq(raw["anchors"]["flee_exit"], Vector2i(0, 2), "원본 보존")
	_assert_edge(data)


func test_unmarked_exit_without_ground_entry_overlap_recomputes() -> void:
	# 맨홀·다른 층 입구는 이동 대상이 아니며, 명시적 false는 겹침보다 우선한다.
	for mode: String in ["different_cell", "manhole", "upper_level", "marked_false"]:
		var raw: Dictionary = _legacy_ring_fixture()
		match mode:
			"different_cell":
				raw["entries"]["west"] = [Vector2i(0, 1)]
			"manhole":
				raw["manholes"] = {"west": true}
			"upper_level":
				raw["entry_levels"] = {"west": 1}
			"marked_false":
				raw["flee_exit_set"] = false
		var data: Dictionary = Ring.add(raw)
		assert_eq(data["anchors"]["flee_exit"], FieldMaps.anchors(data)["flee_exit"], mode + ": 재계산")
		var inner: Rect2i = data["map_ring"]["inner"]
		assert_ne(data["anchors"]["flee_exit"], Vector2i(0, inner.position.y + 2), mode + ": 입구 겹침 예외 아님")
		_assert_edge(data)
