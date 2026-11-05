extends "res://addons/gut/test.gd"
## 결정 562: 지도 촬영 자리를 자료와 규칙으로 고르고 소품을 세는 동작을 지킨다.
## 작은 격자로 경계, 빠진 자료, 순서와 동률을 확인한다. 정면 자리는 게임처럼 카메라 초점과 1층
## 바닥(footprint)으로 지붕 걷힘을 재고, 인자·그림·잣대 파일의 실패는 오류로 돌아오는지 본다.

const MapShots = preload("res://tools/map_shots.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const BuildingView = preload("res://game/world/building_view.gd")


func _building(g: FieldGrid, r: Rect2i, id: int) -> void:
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			var c: Vector2i = Vector2i(x, y)
			g.building[g.index(c)] = id
			if x == r.position.x or x == r.end.x - 1 or y == r.position.y or y == r.end.y - 1:
				g.set_solid(c, FieldGrid.Solid.WALL)


func _door(g: FieldGrid, c: Vector2i, id: int) -> void:
	g.set_solid(c, FieldGrid.Solid.DOOR)
	g.doors[c] = {"state": "closed", "building": id, "hp": 3, "key": ""}


func _prop(c: Vector2i, kind: String) -> Dictionary:
	return {"rect": Rect2i(c, Vector2i.ONE), "kind": kind}


## Footprints as building_view.gd keeps them (building -> Rect2i), here each row's rect.
func _prints(rows: Array) -> Dictionary:
	var out: Dictionary = {}
	for row: Dictionary in rows:
		out[int(row["id"])] = row["rect"]
	return out


## The camera's focus where the leader stands (no map edge to pull it in).
func _same(c: Vector2i) -> Vector2i:
	return c


func _fronts(rows: Array, g: FieldGrid) -> Dictionary:
	return MapShots.front_spots({"buildings": rows}, g, _prints(rows), _same)


func test_camera_sees_south_and_east_walls() -> void:
	assert_true(MapShots.faces_camera(Vector2i.DOWN), "남쪽 벽")
	assert_true(MapShots.faces_camera(Vector2i.RIGHT), "동쪽 벽")
	assert_false(MapShots.faces_camera(Vector2i.UP), "북쪽 벽")
	assert_false(MapShots.faces_camera(Vector2i.LEFT), "서쪽 벽")


func test_roof_distance_includes_boundary_and_excludes_self() -> void:
	var radius: int = int(BuildingView.NEAR_R)
	assert_eq(float(radius), BuildingView.NEAR_R, "반경이 정수인 시험 자료")
	var c: Vector2i = Vector2i(20, 20)
	var prints: Dictionary = {
		0: Rect2i(c, Vector2i.ONE),
		1: Rect2i(c + Vector2i(radius, 0), Vector2i(3, 2)),
		2: Rect2i(c + Vector2i(radius + 1, 0), Vector2i.ONE),
	}
	assert_eq(MapShots.near_roofs(prints, c, 0), 1, "경계 포함, 자신과 바깥 제외")
	assert_true(MapShots.roof_lifted(prints[0], c), "자기 칸 위 초점은 지붕을 걷음")
	assert_eq(BuildingView.NEAR_R, 10.0, "대각 시험 자료의 반경")
	var diagonal: Dictionary = {
		1: Rect2i(c + Vector2i(6, 8), Vector2i.ONE),
		2: Rect2i(c + Vector2i(7, 8), Vector2i.ONE),
	}
	assert_eq(MapShots.near_roofs(diagonal, c, -1), 1, "대각선은 직선 거리")


func test_outer_doors_use_first_walkable_outside_and_keep_order() -> void:
	var g: FieldGrid = FieldGrid.new(40, 40)
	var a: Vector2i = Vector2i(10, 10)
	var b: Vector2i = Vector2i(20, 20)
	var other: Vector2i = Vector2i(30, 30)
	_door(g, a, 4)
	_door(g, b, 4)
	_door(g, other, 5)
	g.building[g.index(a)] = 9
	g.set_solid(a + Vector2i.DOWN, FieldGrid.Solid.WALL)
	g.building[g.index(a + Vector2i.RIGHT)] = 9
	g.set_solid(b + Vector2i.DOWN, FieldGrid.Solid.WALL)
	g.set_solid(b + Vector2i.RIGHT, FieldGrid.Solid.WALL)
	g.set_solid(b + Vector2i.UP, FieldGrid.Solid.WALL)
	assert_eq(MapShots.outer_doors(g, 4, [b, other, a]), [[b, Vector2i.LEFT], [a, Vector2i.UP]], "문 소유권과 방향 순서")
	g.set_solid(a + Vector2i.DOWN, FieldGrid.Solid.NONE)
	assert_eq(MapShots.outer_doors(g, 4, [a]), [[a, Vector2i.DOWN]], "남쪽이 먼저")
	g.set_solid(a + Vector2i.DOWN, FieldGrid.Solid.WALL)
	g.building[g.index(a + Vector2i.RIGHT)] = -1
	assert_eq(MapShots.outer_doors(g, 4, [a]), [[a, Vector2i.RIGHT]], "동쪽이 다음")


func test_door_faces_counts_buildings_once_and_ignores_doorless() -> void:
	var g: FieldGrid = FieldGrid.new(40, 40)
	var rows: Array = []
	for id: int in range(3):
		var r: Rect2i = Rect2i(3 + id * 11, 5, 5, 5)
		_building(g, r, id)
		rows.append({"id": id, "rect": r})
	_door(g, Vector2i(5, 5), 0)
	_door(g, Vector2i(16, 9), 1)
	_door(g, Vector2i(18, 7), 1)
	assert_eq(MapShots.door_faces({"buildings": rows}, g), {"buildings_with_door": 2, "with_door_on_seen_wall": 1}, "건물마다 한 번")


func test_front_spots_skip_unseen_and_sort_by_id() -> void:
	var g: FieldGrid = FieldGrid.new(40, 40)
	# 북쪽 문 가게도 12칸 밖이 지도 안·빈 땅이라, 벽 방향 거르기만이 그 가게를 뺀다.
	var north: Rect2i = Rect2i(3, 20, 5, 5)
	var south: Rect2i = Rect2i(20, 3, 5, 5)
	_building(g, north, 1)
	_building(g, south, 2)
	_door(g, Vector2i(5, 20), 1)
	_door(g, Vector2i(22, 7), 2)
	assert_true(g.people_can_walk(Vector2i(5, 8)) and g.building_at(Vector2i(5, 8)) < 0, "북쪽 문 12칸 밖은 빈 땅")
	var rows: Array = [{"id": 2, "rect": south, "role": "shop"}, {"id": 1, "rect": north, "role": "shop"}]
	var expected: Dictionary = {"cell": Vector2i(22, 19), "look": Vector2i(22, 7), "building": 2, "doors": 1, "doors_seen": 1, "near_roofs": 0}
	var first: Dictionary = _fronts(rows, g)
	assert_eq(first.get("front_shop"), expected, "보이는 다음 가게")
	assert_eq(_fronts(rows, g), first, "반복 결과")
	rows.reverse()
	assert_eq(_fronts(rows, g), first, "건물 행 순서 무관")


func test_front_spots_skip_large_building_and_unseen_home() -> void:
	var g: FieldGrid = FieldGrid.new(50, 50)
	var large: Rect2i = Rect2i(0, 0, 31, 30)
	var home: Rect2i = Rect2i(40, 35, 5, 5)
	_building(g, large, 1)
	_building(g, home, 2)
	_door(g, Vector2i(15, 29), 1)
	_door(g, Vector2i(40, 37), 2)
	# 두 문 모두 12칸 밖이 빈 땅이라, 넓이 거르기와 벽 방향 거르기만이 둘을 뺀다.
	for c: Vector2i in [Vector2i(15, 41), Vector2i(28, 37)]:
		assert_true(g.people_can_walk(c) and g.building_at(c) < 0, "12칸 밖은 빈 땅")
	var rows: Array = [{"id": 1, "rect": large, "role": "shop"}, {"id": 2, "rect": home, "role": "home"}]
	var result: Dictionary = _fronts(rows, g)
	assert_false(result.has("front_shop"), "900칸 초과 제외")
	assert_false(result.has("front_home"), "서쪽 문만 있으면 제외")


func test_front_spots_select_smallest_id_among_visible_shops() -> void:
	var g: FieldGrid = FieldGrid.new(40, 40)
	var a: Rect2i = Rect2i(2, 2, 5, 5)
	var b: Rect2i = Rect2i(28, 2, 5, 5)
	_building(g, a, 3)
	_building(g, b, 8)
	_door(g, Vector2i(4, 6), 3)
	_door(g, Vector2i(30, 6), 8)
	var rows: Array = [{"id": 8, "rect": b, "role": "shop"}, {"id": 3, "rect": a, "role": "shop"}]
	var result: Dictionary = _fronts(rows, g)
	assert_eq(result["front_shop"]["building"], 3, "작은 건물 번호 먼저")


func test_front_spots_use_next_walkable_cell_and_fewest_roofs() -> void:
	var g: FieldGrid = FieldGrid.new(40, 45)
	var r: Rect2i = Rect2i(10, 3, 5, 5)
	_building(g, r, 1)
	var door: Vector2i = Vector2i(12, 7)
	_door(g, door, 1)
	var rows: Array = [{"id": 1, "rect": r, "role": "shop"}]
	g.set_solid(door + Vector2i.DOWN * 12, FieldGrid.Solid.WALL)
	var blocked: Dictionary = _fronts(rows, g)
	assert_eq(blocked["front_shop"]["cell"], door + Vector2i.DOWN * 13, "막힌 12칸 다음")
	g.set_solid(door + Vector2i.DOWN * 12, FieldGrid.Solid.NONE)
	# A neighbour's footprint 10 cells from the 12th cell: its roof would lift there, not from the 13th.
	var with_neighbour: Dictionary = {1: r, 2: Rect2i(12, 9, 1, 1)}
	var fewer: Dictionary = MapShots.front_spots({"buildings": rows}, g, with_neighbour, _same)
	assert_eq(fewer["front_shop"]["cell"], door + Vector2i.DOWN * 13, "지붕이 적은 칸")
	assert_eq(fewer["front_shop"]["near_roofs"], 0, "지붕 수")
	# A building row with no footprint (nothing inside, never drawn open) lifts no roof: the 12th again.
	rows.append({"id": 2, "rect": Rect2i(12, 9, 1, 1), "role": "home"})
	var no_print: Dictionary = MapShots.front_spots({"buildings": rows}, g, {1: r}, _same)
	assert_eq(no_print["front_shop"]["cell"], door + Vector2i.DOWN * 12, "바닥 없는 건물은 안 셈")


func test_front_spots_judge_the_own_roof_from_the_camera_focus() -> void:
	var g: FieldGrid = FieldGrid.new(40, 45)
	var r: Rect2i = Rect2i(10, 3, 5, 5)
	_building(g, r, 1)
	var door: Vector2i = Vector2i(12, 7)
	_door(g, door, 1)
	var rows: Array = [{"id": 1, "rect": r, "role": "shop"}]
	# The field pulls the focus two cells back toward the shop (as at a map edge): from the 12th cell it
	# would sit 10 cells off the shop and lift its own roof, so the 13th is taken.
	var pulled: Callable = func(c: Vector2i) -> Vector2i: return c + Vector2i.UP * 2
	var result: Dictionary = MapShots.front_spots({"buildings": rows}, g, _prints(rows), pulled)
	assert_eq(result["front_shop"]["cell"], door + Vector2i.DOWN * 13, "자기 지붕이 걷히는 칸은 뺌")
	var on_door: Callable = func(_c: Vector2i) -> Vector2i: return door
	assert_false(MapShots.front_spots({"buildings": rows}, g, _prints(rows), on_door).has("front_shop"), "모든 칸에서 걷히면 없음")


func test_inside_cell_keeps_a_walkable_middle_and_moves_off_walls_and_out_of_an_l() -> void:
	var g: FieldGrid = FieldGrid.new(30, 30)
	var r: Rect2i = Rect2i(2, 2, 7, 7)
	_building(g, r, 1)
	assert_eq(MapShots.inside_cell(g, 1, r), Vector2i(5, 5), "걸을 수 있는 가운데는 그대로")
	g.set_solid(Vector2i(5, 5), FieldGrid.Solid.WALL)
	assert_eq(MapShots.inside_cell(g, 1, r), Vector2i(5, 4), "안벽 위 가운데는 가장 가까운 칸(줄 순서 첫째)")
	# An L: building 2 only along the top and the left of its rect, so the rect's middle (14, 14) is outside it.
	var l: Rect2i = Rect2i(10, 10, 8, 8)
	for y: int in range(l.position.y, l.end.y):
		for x: int in range(l.position.x, l.end.x):
			if x < 13 or y < 13:
				g.building[g.index(Vector2i(x, y))] = 2
	assert_eq(MapShots.inside_cell(g, 2, l), Vector2i(14, 12), "ㄴ자 건물은 건물 안 칸")


func test_parse_args_reads_the_options_and_refuses_bad_ones() -> void:
	var ok: Dictionary = MapShots.parse_args(PackedStringArray(["--out=D:/x", "--zoom=20", "--seed=7", "--mask", "--front", "houses_01"]))
	assert_false(ok.has("error"), "바른 인자")
	assert_eq([ok["out"], ok["zoom"], ok["front_zoom"], ok["seed"], ok["place"], ok["mask"], ok["dead"], ok["front"]],
		["D:/x", 20.0, 20.0, 7, "houses_01", true, false, true], "값")
	var bad_lines: Array = [["--out=D:/x"], ["houses_01"], ["--out=", "houses_01"], ["--out=D:/x", "--zoom=0", "houses_01"],
		["--out=D:/x", "--zoom=-3", "houses_01"], ["--out=D:/x", "--zoom=abc", "houses_01"], ["--out=D:/x", "--zoom=inf", "houses_01"],
		["--out=D:/x", "--front-zoom=0", "houses_01"], ["--out=D:/x", "--seed=1.5", "houses_01"], ["--out=D:/x", "--mask=1", "houses_01"],
		["--out=D:/x", "--bogus", "houses_01"], ["--out=D:/x", "houses_01", "lake_01"], ["--out=D:/x", "--mask", "--mask", "houses_01"]]
	for bad: Array in bad_lines:
		assert_true(MapShots.parse_args(PackedStringArray(bad)).has("error"), "거부: %s" % [bad])


func test_write_json_and_save_shot_report_what_was_not_written() -> void:
	var tag: String = "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var good: String = "user://map_shots_test_%s.json" % tag
	assert_eq(MapShots.write_json(good, {"a": 1}), OK, "쓰기")
	assert_eq(JSON.parse_string(FileAccess.get_file_as_string(good)), {"a": 1.0}, "다시 읽기")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(good))
	assert_ne(MapShots.write_json("user://map_shots_no_dir_%s/m.json" % tag, {}), OK, "없는 폴더")
	assert_eq(MapShots.save_shot(Image.new(), "user://map_shots_%s.jpg" % tag), ERR_INVALID_DATA, "빈 그림")
	var img: Image = Image.create_empty(4, 4, false, Image.FORMAT_RGB8)
	assert_ne(MapShots.save_shot(img, "user://map_shots_no_dir_%s/s.jpg" % tag), OK, "없는 폴더에 그림")
	# The engine reports the failed jpg write itself (Image.save_jpg); the tool turns it into MAP_SHOTS_FAIL.
	assert_engine_error_count(1, "없는 폴더에 그림을 쓰면 엔진 오류 하나")


func test_spot_counts_split_indoor_trees_and_made_and_clip_box() -> void:
	var g: FieldGrid = FieldGrid.new(40, 40)
	g.building[g.index(Vector2i(20, 20))] = 1
	var props: Array = [_prop(Vector2i(20, 20), "pine"), _prop(Vector2i(3, 3), "pine"),
		_prop(Vector2i(4, 4), "boulder"), _prop(Vector2i(5, 5), "chair"),
		_prop(Vector2i(38, 20), "chair"), {"kind": "chair"},
		{"rect": Rect2i(6, 6, 1, 1), "kind": "chair", "level": 1}]
	var counts: Dictionary = MapShots.spot_counts({"props": props}, g, Vector2i(20, 20))
	assert_eq(counts["outdoor_m2"], 1295, "건물 칸 제외")
	assert_eq(counts["indoor"], 1, "실내가 먼저")
	assert_eq(counts["trees"], 1, "나무")
	assert_eq(counts["things"], 2, "바깥 소품")
	assert_eq(counts["made"], 1, "자연물 제외")
	assert_eq(counts["things_per100"], 0.15, "100칸당 소품")
	assert_eq(counts["made_per100"], 0.08, "100칸당 인공물")
	assert_eq(counts["kind_list"], {"boulder": 1, "chair": 1}, "종류")


func test_pick_spots_choose_start_inside_edge_and_road() -> void:
	var g: FieldGrid = FieldGrid.new(40, 40)
	var a: Rect2i = Rect2i(4, 4, 4, 4)
	var b: Rect2i = Rect2i(24, 4, 4, 4)
	_building(g, a, 1)
	_building(g, b, 2)
	for c: Vector2i in [Vector2i(6, 26), Vector2i(7, 26), Vector2i(8, 26), Vector2i(28, 28)]:
		g.floor[g.index(c)] = FieldGrid.Floor.ROAD
	var data: Dictionary = {"spawns": {"squad": [Vector2i(3, 3), Vector2i(4, 3)]},
		"train": Rect2i(1, 1, 2, 2), "map_ring": {"inner": Rect2i(0, 0, 40, 40)},
		"buildings": [{"id": 1, "rect": a}, {"id": 2, "rect": b}, {"id": 3, "rect": Rect2i(0, 0, 31, 30)}],
		"containers": {"a": {"cell": Vector2i(5, 5)}, "b": {"cell": Vector2i(25, 5)},
			"c": {"cell": Vector2i(26, 5)}, "upper": {"cell": Vector2i(5, 5), "level": 1}}}
	var result: Dictionary = MapShots.pick_spots(data, g)
	assert_eq(result["start"], Vector2i(3, 3), "첫 분대원")
	assert_eq(result["inside"], b.get_center(), "상자가 많은 건물")
	assert_eq(result["edge"], Vector2i(35, 20), "기차에서 먼 고리")
	assert_eq(result["road"], Vector2i(6, 26), "길 밀도와 동률 순서")


func test_pick_spots_accept_empty_data() -> void:
	var g: FieldGrid = FieldGrid.new(40, 40)
	var result: Dictionary = MapShots.pick_spots({}, g)
	assert_false(result.has("start"), "분대 없음")
	assert_false(result.has("inside"), "건물 없음")
	assert_false(result.has("road"), "길 없음")
	assert_eq(result["edge"], Vector2i(20, 4), "기차 없을 때 첫 고리")


func test_pick_spots_ignore_near_train_roads_and_oversized_building() -> void:
	var g: FieldGrid = FieldGrid.new(50, 50)
	var big: Rect2i = Rect2i(0, 0, 31, 30)
	var small: Rect2i = Rect2i(35, 2, 4, 4)
	_building(g, big, 1)
	_building(g, small, 2)
	for c: Vector2i in [Vector2i(4, 34), Vector2i(6, 34), Vector2i(40, 40)]:
		g.floor[g.index(c)] = FieldGrid.Floor.ROAD
	var data: Dictionary = {"train": Rect2i(2, 32, 2, 2),
		"buildings": [{"id": 1, "rect": big}, {"id": 2, "rect": small}],
		"containers": {"a": {"cell": Vector2i(2, 2)}, "b": {"cell": Vector2i(3, 3)},
			"c": {"cell": Vector2i(36, 3)}}}
	var result: Dictionary = MapShots.pick_spots(data, g)
	assert_eq(result["road"], Vector2i(40, 40), "기차 근처의 밀집 도로 제외")
	assert_eq(result["inside"], small.get_center(), "큰 건물의 상자가 더 많아도 제외")


func test_dead_spot_uses_nearest_outdoor_ground_floor_dead() -> void:
	var g: FieldGrid = FieldGrid.new(40, 40)
	g.building[g.index(Vector2i(11, 10))] = 1
	var dead: Array = [{"pos": FieldGrid.center(Vector2i(11, 10))},
		{"pos": FieldGrid.center(Vector2i(12, 10)), "level": 1},
		{"pos": FieldGrid.center(Vector2i(20, 10))}, {"pos": FieldGrid.center(Vector2i(16, 10))}]
	var data: Dictionary = {"spawns": {"squad": [Vector2i(10, 10)]}}
	assert_eq(MapShots.dead_spot(dead, data, g), {"cell": Vector2i(12, 10), "look": Vector2i(16, 10)}, "가까운 실외 망자")
	assert_eq(MapShots.dead_spot(dead.slice(0, 2), data, g), {}, "적합한 망자 없음")


func test_room_classes_vote_and_break_ties_by_name() -> void:
	var g: FieldGrid = FieldGrid.new(12, 12)
	_building(g, Rect2i(2, 2, 5, 5), 0)
	var props: Array = [{"rect": Rect2i(3, 3, 1, 1), "rule": "kitchen"},
		{"rect": Rect2i(4, 3, 1, 1), "rule": "bed"}]
	var data: Dictionary = {"props": props}
	assert_eq(MapShots.room_classes(data, g), {"0:0": "bed"}, "동률은 이름순")
	props.append({"rect": Rect2i(5, 3, 1, 1), "rule": "kitchen"})
	assert_eq(MapShots.room_classes(data, g), {"0:0": "kitchen"}, "다수결")
