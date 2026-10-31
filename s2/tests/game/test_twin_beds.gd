extends "res://addons/gut/test.gd"
## 두 지도 전체 검사는 test_room_furnish의 기존 houses_01·houses_02 생성 결과를 함께 쓴다.
## 여기서는 작은 방으로 재시도·되돌림·가운데 막힘·선정 제외·예비 채우기를 검사한다.

const FieldGrid = preload("res://game/world/field_grid.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")
const S = FieldGrid.Solid


func _room(edge: int = 8) -> FieldGrid:
	var grid := FieldGrid.new(edge, edge)
	grid.building.fill(0)
	for y in range(edge):
		for x in range(edge):
			grid.set_solid(Vector2i(x, y), S.WALL if x == 0 or x == edge - 1 or y == 0 or y == edge - 1 else S.NONE)
	return grid


func _first_item() -> Dictionary:
	return {"kind": "bed", "size": Vector2i(2, 1), "need": true, "at": "head", "twin_room": true}


func _keys() -> Dictionary:
	var seeds: Array[Vector2i] = [Vector2i(6, 6)]
	return {"seeds": seeds, "boxes": []}


func test_second_bed_candidates_only_share_the_head_wall_at_two_cells() -> void:
	var grid := _room()
	var map := RoomFurnish.rooms_of(grid)
	var cells: Array[Vector2i] = map["rooms"][0]["cells"]
	var item := _first_item()
	item["near"] = "twin"
	item["near_cells"] = [Vector2i(1, 3)]
	item["near_dirs"] = [Vector2i.LEFT]
	var candidates := RoomFurnish._candidates(grid, map["of"], 0, cells, item, {}, {}, [], [], {}, RoomFurnish.HEAD_CANDIDATES)
	assert_eq(candidates.size(), 2, "같은 벽의 머리 두 칸 위·아래만 남긴다")
	for candidate: Dictionary in candidates:
		assert_eq(int(candidate["facing"]), 0, "첫 침대와 같은 방향")
		assert_true(RoomFurnish.bed_head(candidate["rect"], int(candidate["facing"])) in [Vector2i(1, 1), Vector2i(1, 5)], "가산점 밖의 떨어진 자리는 후보가 아니다")


func test_pair_retries_the_next_head_candidate_and_restores_failed_cells() -> void:
	var grid := _room()
	var map := RoomFurnish.rooms_of(grid)
	var item := _first_item()
	var forbid := {Vector2i(1, 3): "all"}
	var keys := _keys()
	var before := RoomFurnish._from_first(grid, map["of"], 0, keys)
	var candidates: Array = []
	for rect: Rect2i in [Rect2i(1, 1, 2, 1), Rect2i(1, 2, 2, 1)]:
		candidates.append(RoomFurnish._head_spot(grid, map["of"], 0, rect, item, forbid, {}, keys["seeds"], {}))
	var rects: Array = []
	var pair := RoomFurnish._twin_beds(grid, map["of"], 0, item, forbid, {}, {}, keys, before, [], rects, candidates, 0)
	assert_eq(pair.size(), 2, "첫 후보의 짝은 막혔지만 다음 후보는 둘 다 선다")
	if pair.size() != 2:
		return
	assert_eq(pair[0]["rect"], Rect2i(1, 2, 2, 1), "다음 머리-벽 후보로 옮겼다")
	assert_eq(pair[1]["rect"], Rect2i(1, 4, 2, 1), "같은 벽 한 칸 건너 둘째 침대")
	assert_eq(rects.size(), 2, "성공한 두 침대만 길 검사 목록에 남는다")
	assert_eq(grid.solid_at(Vector2i(1, 1)), S.NONE, "실패한 첫 후보 칸 복구")
	assert_eq(grid.solid_at(Vector2i(2, 1)), S.NONE, "실패한 첫 후보 발치 복구")
	assert_true(RoomFurnish._still_open(grid, map["of"], 0, keys, before, rects), "둘을 칠한 상태로 기존 길 검사 통과")


func test_pair_failure_restores_both_beds_when_the_path_is_cut() -> void:
	var grid := _room()
	var map := RoomFurnish.rooms_of(grid)
	var item := _first_item()
	var seeds: Array[Vector2i] = [Vector2i(6, 6), Vector2i(1, 3)]
	var keys := {"seeds": seeds, "boxes": []}
	var before := RoomFurnish._from_first(grid, map["of"], 0, keys)
	var original := grid.solid.duplicate()
	var first := RoomFurnish._head_spot(grid, map["of"], 0, Rect2i(1, 1, 2, 1), item, {}, {}, seeds, {})
	var rects: Array = []
	var pair := RoomFurnish._twin_beds(grid, map["of"], 0, item, {}, {}, {}, keys, before, [], rects, [first], 0)
	assert_true(pair.is_empty(), "둘째 침대가 원래 닿던 필수 칸을 덮으면 둘 다 포기")
	assert_eq(grid.solid, original, "실패한 두 침대의 임시 칠을 전부 복구")
	assert_true(rects.is_empty(), "실패한 두 침대를 길 검사 목록에도 남기지 않는다")


## 침실 아홉 개면 기존 12% 반올림 몫이 하나다. 각 층은 서로 다른 집이라 욕실 전환 후보가 없다.
func _bedrooms() -> Dictionary:
	var levels: Dictionary = {}
	var labels: Array = []
	for level in range(9):
		var grid := _room()
		grid.building.fill(level)
		levels[level] = grid
		labels.append({"cell": Vector2i(3, 3), "level": level, "text": "침실"})
	return {"grid": levels[0], "levels": levels, "labels": labels, "place_id": "twin_fixture",
		"props": [], "containers": {}, "low_blocks": [], "stairs": [], "_defer_paths": true}


func _selection(data: Dictionary) -> Dictionary:
	return RoomFurnish._twin_rooms(data, RoomFurnish.density_plan(data), data["levels"], data["place_id"])


func _selected(data: Dictionary) -> Dictionary:
	return _selection(data)["selected"]


## 짧은 변이 하나 더 긴 방을 지정해 첫 뽑기의 순서를 굴림값과 무관하게 고정한다.
func _fill_bedrooms(first_level: int = 0) -> Dictionary:
	var data := _bedrooms()
	var first_grid := _room(9)
	first_grid.building.fill(first_level)
	data["levels"][first_level] = first_grid
	data["grid"] = data["levels"][0]
	return data


func _same_floor_bedrooms() -> Dictionary:
	var grid := FieldGrid.new(81, 9)
	grid.building.fill(0)
	grid.solid.fill(S.WALL)
	var labels: Array = []
	for room_id in range(9):
		var offset := Vector2i(room_id * 9, 0)
		var edge := 8 if room_id == 0 else 7
		for y in range(1, edge):
			for x in range(1, edge):
				grid.set_solid(offset + Vector2i(x, y), S.NONE)
		labels.append({"cell": offset + Vector2i(3, 3), "level": 0, "text": "침실"})
	return {"grid": grid, "levels": {0: grid}, "labels": labels, "place_id": "twin_fixture",
		"props": [], "containers": {}, "low_blocks": [], "stairs": [], "_defer_paths": true}


func _block_pair(grid: FieldGrid) -> void:
	var map := RoomFurnish.rooms_of(grid)
	# 한 침대와 그 양옆 협탁 자리는 남지만 같은 벽 두 칸 건너에는 침대가 설 수 없다.
	for cell: Vector2i in map["rooms"][0]["cells"]:
		grid.set_solid(cell, S.NONE if cell in [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(1, 3)] else S.LOW)


func test_bunk_coverage_skips_the_chosen_room_and_fills_its_quota() -> void:
	var data := _bedrooms()
	var first := _selected(data)
	assert_eq(first.size(), 1, "아홉 침실의 몫 하나")
	assert_eq((_selection(data)["reserve"] as Dictionary).size(), 8, "나머지 넓은 침실은 예비")
	if first.size() != 1:
		return
	var key := String(first.keys()[0])
	var level := int(key.get_slice(":", 0))
	data["props"].append({"kind": "bed", "rect": Rect2i(1, 1, 2, 1), "level": level})
	assert_true(_selected(data).has(key), "다시 놓을 bed는 선정에서 제외하지 않는다")
	data["props"].append({"kind": "bunk_bed", "rect": [1, 3, 2, 1], "level": level})
	var next := _selected(data)
	assert_eq(next.size(), first.size(), "남는 넓은 방으로 같은 몫을 채운다")
	assert_false(next.has(key), "STANDS_FOR로 bed를 대신하는 방은 뺀다")
	assert_false((_selection(data)["reserve"] as Dictionary).has(key), "침대를 대신하는 방은 예비에서도 뺀다")
	assert_eq(_selected(data), next, "같은 지도·씨앗의 선정은 동일")


func test_impossible_pair_falls_back_to_one_bed_and_counts_abandonment() -> void:
	# 첫 뽑기가 마지막에 오므로 포기 뒤에 만날 예비 방이 없다. 앞선 방은 다시 차리지 않는다.
	var data := _fill_bedrooms(8)
	var selected := _selected(data)
	assert_eq(selected.size(), 1)
	if selected.size() != 1:
		return
	var level := int(String(selected.keys()[0]).get_slice(":", 0))
	var grid: FieldGrid = data["levels"][level]
	_block_pair(grid)
	var stats := RoomFurnish.furnish_rooms(data)
	assert_eq(int(stats["twin_quota"]), 1)
	assert_eq(int(stats["twin_tried"]), 1)
	assert_eq(int(stats["twin_abandoned"]), 1, "짝 후보가 전부 없으면 방 하나 포기")
	assert_eq(int(stats["twin_filled"]), 0)
	assert_eq(int(stats.get("twins", 0)), 0)
	_assert_twins(data, stats)
	var beds := 0
	for prop: Dictionary in data["props"]:
		if int(prop.get("level", 0)) == level and prop["kind"] == "bed":
			beds += 1
			assert_false(prop.get("twin", false), "보통 넓은 침실의 침대로 되돌림")
	assert_eq(beds, 1, "짝 실패 뒤에도 보통 침대 하나는 놓는다")


func test_blocked_middle_omits_the_stand_without_moving_it_outside() -> void:
	var data := _bedrooms()
	var selected := _selected(data)
	assert_eq(selected.size(), 1)
	if selected.size() != 1:
		return
	var level := int(String(selected.keys()[0]).get_slice(":", 0))
	var grid: FieldGrid = data["levels"][level]
	for y in range(1, 7):
		for x in range(1, 7):
			var cell := Vector2i(x, y)
			# 가운데 (1, 3)은 막고 바깥 협탁 자리 (1, 1)·(1, 5)는 비워 둔다.
			var open := cell in [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(1, 4), Vector2i(2, 4), Vector2i(1, 5)]
			grid.set_solid(cell, S.NONE if open else S.LOW)
	var stats := RoomFurnish.furnish_rooms(data)
	assert_eq(int(stats["twin_quota"]), 1)
	assert_eq(int(stats["twin_tried"]), 1)
	assert_eq(int(stats["twin_abandoned"]), 0)
	assert_eq(int(stats["twin_filled"]), 0)
	assert_eq(int(stats.get("twins", 0)), 1, "가운데가 막혀도 두 침대는 놓을 수 있다")
	_assert_twins(data, stats)
	var beds := 0
	for prop: Dictionary in data["props"]:
		if int(prop.get("level", 0)) != level:
			continue
		beds += int(prop["kind"] == "bed")
		assert_ne(prop["kind"], "nightstand", "막힌 가운데 대신 바깥 칸에 협탁을 놓지 않는다")
	assert_eq(beds, 2)


func test_abandoned_first_pick_is_filled_by_the_next_reserve() -> void:
	var data := _fill_bedrooms()
	var selection := _selection(data)
	assert_true(selection["selected"].has("0:0"), "가장 먼저 차리는 넓은 방이 첫 뽑기")
	assert_eq(String(selection["reserve"].get("1:0", "")), "1:1", "다음 집의 방은 예비")
	_block_pair(data["levels"][0])
	var stats := RoomFurnish.furnish_rooms(data)
	assert_eq(int(stats["twin_quota"]), 1)
	assert_eq(int(stats["twin_tried"]), 2, "첫 뽑기와 뒤의 예비를 한 번씩 시도")
	assert_eq(int(stats["twin_abandoned"]), 1)
	assert_eq(int(stats["twin_filled"]), 1)
	assert_eq(int(stats.get("twins", 0)), 1)
	for prop: Dictionary in data["props"]:
		if prop.get("twin", false):
			assert_eq(int(prop["level"]), 1, "기존 순회에서 만난 첫 예비가 채운다")
	_assert_twins(data, stats)


func test_successful_first_pick_never_tries_a_reserve() -> void:
	# 첫 뽑기 앞과 뒤에 예비를 두어 아직 차리지 않은 첫 뽑기와 이미 선 방을 모두 센다.
	var data := _fill_bedrooms(4)
	assert_true(_selected(data).has("4:0"))
	var stats := RoomFurnish.furnish_rooms(data)
	assert_eq(int(stats["twin_quota"]), 1)
	assert_eq(int(stats["twin_tried"]), int(stats["twin_quota"]))
	assert_eq(int(stats["twin_abandoned"]), 0)
	assert_eq(int(stats["twin_filled"]), 0)
	assert_eq(int(stats.get("twins", 0)), 1)
	_assert_twins(data, stats)


func test_reserves_on_the_first_picks_building_floor_are_skipped() -> void:
	var data := _same_floor_bedrooms()
	var selection := _selection(data)
	assert_true(selection["selected"].has("0:0"))
	assert_eq((selection["reserve"] as Dictionary).size(), 8, "같은 층의 넓은 방도 예비 목록에는 남긴다")
	assert_eq(String(selection["reserve"].get("0:1", "")), "0:0")
	_block_pair(data["grid"])
	var stats := RoomFurnish.furnish_rooms(data)
	assert_eq(int(stats["twin_quota"]), 1)
	assert_eq(int(stats["twin_tried"]), 2, "첫 뽑기가 포기한 건물·층은 예비에 열린다")
	assert_eq(int(stats["twin_abandoned"]), 1)
	assert_eq(int(stats["twin_filled"]), 1)
	assert_eq(int(stats.get("twins", 0)), 1)
	for prop: Dictionary in data["props"]:
		if prop.get("twin", false):
			var x: int = (prop["rect"] as Rect2i).position.x
			assert_true(x >= 9 and x < 18, "포기한 방 다음에 차리는 같은 층 방이 채운다")
	_assert_twins(data, stats)


## 침실 열셋(몫 둘): 1층 B(짧은 변 7)와 2층 A(짧은 변 7)가 첫 뽑기, 2층 A2(같은 집·층, 짧은 변 6)는 예비.
func _two_on_a_floor() -> Dictionary:
	var data := _bedrooms()
	for level in range(9, 12):
		var extra := _room()
		extra.building.fill(level)
		data["levels"][level] = extra
		data["labels"].append({"cell": Vector2i(3, 3), "level": level, "text": "침실"})
	var b_grid := _room(9)
	b_grid.building.fill(1)
	data["levels"][1] = b_grid
	var pair := FieldGrid.new(17, 9)
	pair.building.fill(2)
	pair.solid.fill(S.WALL)
	for y in range(1, 8):
		for x in range(1, 8):
			pair.set_solid(Vector2i(x, y), S.NONE)
		for x in range(9, 15):
			pair.set_solid(Vector2i(x, y), S.NONE)
	data["levels"][2] = pair
	data["labels"].append({"cell": Vector2i(11, 3), "level": 2, "text": "침실"})
	data["grid"] = data["levels"][0]
	return data


func test_a_reserve_on_a_floor_with_a_standing_twin_is_skipped() -> void:
	var data := _two_on_a_floor()
	var selection := _selection(data)
	assert_eq((selection["selected"] as Dictionary).size(), 2, "침실 열셋이면 몫 둘")
	assert_true(selection["selected"].has("1:0") and selection["selected"].has("2:0"))
	assert_eq(String(selection["reserve"].get("2:1", "")), "2:2", "같은 집·층의 둘째 방은 예비")
	_block_pair(data["levels"][1])
	var stats := RoomFurnish.furnish_rooms(data)
	assert_eq(int(stats["twin_quota"]), 2)
	assert_eq(int(stats["twin_tried"]), 3, "B 포기, A 섬, A2는 A가 선 층이라 건너뛰고 3층 예비가 채움")
	assert_eq(int(stats["twin_abandoned"]), 1)
	assert_eq(int(stats["twin_filled"]), 1)
	assert_eq(int(stats.get("twins", 0)), 2)
	for prop: Dictionary in data["props"]:
		if prop.get("twin", false):
			assert_true(int(prop["level"]) in [2, 3], "A와 3층 예비만")
			if int(prop["level"]) == 2:
				assert_lt((prop["rect"] as Rect2i).position.x, 8, "A2에는 두 침대가 없다")
	_assert_twins(data, stats)


func test_a_failed_reserve_leaves_the_gap_for_the_following_room() -> void:
	var data := _fill_bedrooms()
	_block_pair(data["levels"][0])
	_block_pair(data["levels"][1])
	var stats := RoomFurnish.furnish_rooms(data)
	assert_eq(int(stats["twin_quota"]), 1)
	assert_eq(int(stats["twin_tried"]), 3)
	assert_eq(int(stats["twin_abandoned"]), 2)
	assert_eq(int(stats["twin_filled"]), 1)
	assert_eq(int(stats.get("twins", 0)), 1)
	for prop: Dictionary in data["props"]:
		if prop.get("twin", false):
			assert_eq(int(prop["level"]), 2)
	_assert_twins(data, stats)


func test_filling_the_same_input_twice_gives_the_same_result() -> void:
	var first := _fill_bedrooms()
	var second := _fill_bedrooms()
	_block_pair(first["levels"][0])
	_block_pair(second["levels"][0])
	var first_stats := RoomFurnish.furnish_rooms(first)
	var second_stats := RoomFurnish.furnish_rooms(second)
	assert_eq(int(first_stats["twin_filled"]), 1, "채우기를 실제로 거치는 입력")
	assert_eq(first_stats, second_stats)
	assert_eq(first["props"], second["props"], "가구와 순서가 같다")
	assert_eq(first["low_blocks"], second["low_blocks"])
	assert_eq(first.get("rugs", []), second.get("rugs", []))
	for level: int in first["levels"]:
		var first_grid: FieldGrid = first["levels"][level]
		var second_grid: FieldGrid = second["levels"][level]
		assert_eq(first_grid.solid, second_grid.solid)
	_assert_twins(first, first_stats)
	_assert_twins(second, second_stats)


func _assert_twins(data: Dictionary, stats: Dictionary) -> void:
	var maps: Dictionary = {}
	for level: int in data["levels"]:
		maps[level] = RoomFurnish.rooms_of(data["levels"][level])
	var beds: Dictionary = {}
	var stands: Dictionary = {}
	var actual: Dictionary = {}
	for prop: Dictionary in data["props"]:
		var prop_level := int(prop.get("level", 0))
		var rect: Rect2i = prop["rect"]
		var room_id := RoomFurnish._at(data["levels"][prop_level], maps[prop_level]["of"], rect.position)
		var key := "%d:%d" % [prop_level, room_id]
		if prop["kind"] == "bed":
			beds.get_or_add(key, []).append(prop)
			if prop.get("twin", false):
				assert_false(actual.has(key), "한 방의 둘째 침대 표시는 하나")
				actual[key] = true
		elif prop["kind"] == "nightstand":
			stands.get_or_add(key, []).append(rect.position)
	assert_eq(actual.size(), int(stats["twin_tried"]) - int(stats["twin_abandoned"]), "성공 = 시도 - 포기")
	assert_eq(actual.size(), int(stats.get("twins", 0)), "기존 둘째 침대 통계")
	assert_lte(actual.size(), int(stats["twin_quota"]), "몫을 넘지 않는다")
	assert_lte(int(stats["twin_filled"]), int(stats["twin_abandoned"]), "포기한 만큼만 채운다")
	for twin_key: String in actual:
		var pair: Array = beds[twin_key]
		assert_eq(pair.size(), 2)
		if pair.size() != 2:
			continue
		var first_rect: Rect2i = pair[0]["rect"]
		var first_facing := int(pair[0]["facing"])
		assert_eq(int(pair[1]["facing"]), first_facing, "같은 머리 방향")
		var first_head := RoomFurnish.bed_head(first_rect, first_facing)
		var second_head := RoomFurnish.bed_head(pair[1]["rect"], int(pair[1]["facing"]))
		var across := Vector2i(0, 1) if first_rect.size.x > first_rect.size.y else Vector2i(1, 0)
		assert_true((second_head - first_head) in [across * 2, across * -2], "벽을 따라 머리 사이 두 칸")
		var head_dir: Vector2i = [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN][posmod(first_facing, 4)]
		var twin_level := int(twin_key.get_slice(":", 0))
		var twin_room := int(twin_key.get_slice(":", 1))
		for bed: Dictionary in pair:
			assert_true(RoomFurnish._wall_side(data["levels"][twin_level], maps[twin_level]["of"], twin_room, bed["rect"], head_dir), "두 머리는 같은 벽에")
		var middle: Vector2i = (first_head + second_head) / 2
		assert_lte(stands.get(twin_key, []).size(), 1)
		for stand_cell: Vector2i in stands.get(twin_key, []):
			assert_eq(stand_cell, middle, "협탁은 두 머리 사이 칸에만")
