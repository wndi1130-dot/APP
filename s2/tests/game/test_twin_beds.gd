extends "res://addons/gut/test.gd"
## 두 지도 전체 검사는 test_room_furnish의 기존 houses_01·houses_02 생성 결과를 함께 쓴다.
## 여기서는 작은 방으로 재시도·되돌림·가운데 막힘·선정 제외만 검사한다.

const FieldGrid = preload("res://game/world/field_grid.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")
const S = FieldGrid.Solid


func _room() -> FieldGrid:
	var grid := FieldGrid.new(8, 8)
	grid.building.fill(0)
	for y in range(8):
		for x in range(8):
			grid.set_solid(Vector2i(x, y), S.WALL if x == 0 or x == 7 or y == 0 or y == 7 else S.NONE)
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


func _selected(data: Dictionary) -> Dictionary:
	return RoomFurnish._twin_rooms(data, RoomFurnish.density_plan(data), data["levels"], data["place_id"])


func test_bunk_coverage_skips_the_chosen_room_and_fills_its_quota() -> void:
	var data := _bedrooms()
	var first := _selected(data)
	assert_eq(first.size(), 1, "아홉 침실의 몫 하나")
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
	assert_eq(_selected(data), next, "같은 지도·씨앗의 선정은 동일")


func test_impossible_pair_falls_back_to_one_bed_and_counts_abandonment() -> void:
	var data := _bedrooms()
	var selected := _selected(data)
	assert_eq(selected.size(), 1)
	if selected.size() != 1:
		return
	var level := int(String(selected.keys()[0]).get_slice(":", 0))
	var grid: FieldGrid = data["levels"][level]
	# 한 침대와 그 양옆 협탁 자리는 남지만 같은 벽 두 칸 건너에는 침대가 설 수 없다.
	for y in range(1, 7):
		for x in range(1, 7):
			var cell := Vector2i(x, y)
			grid.set_solid(cell, S.NONE if cell in [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(1, 3)] else S.LOW)
	var stats := RoomFurnish.furnish_rooms(data)
	assert_eq(int(stats["twin_quota"]), 1)
	assert_eq(int(stats["twin_abandoned"]), 1, "짝 후보가 전부 없으면 방 하나 포기")
	assert_eq(int(stats.get("twins", 0)), 0)
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
	assert_eq(int(stats["twin_abandoned"]), 0)
	assert_eq(int(stats.get("twins", 0)), 1, "가운데가 막혀도 두 침대는 놓을 수 있다")
	var beds := 0
	for prop: Dictionary in data["props"]:
		if int(prop.get("level", 0)) != level:
			continue
		beds += int(prop["kind"] == "bed")
		assert_ne(prop["kind"], "nightstand", "막힌 가운데 대신 바깥 칸에 협탁을 놓지 않는다")
	assert_eq(beds, 2)
