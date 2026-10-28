extends "res://addons/gut/test.gd"
## 건물 키트 그리기(building_view.gd, 명세 건물 v1 3·4장): 지도 격자에서 조각을 놓는 규칙,
## 닫힘·열림·지하의 보이는 규칙, 지도 그리기(map_view)가 건물을 키트에 넘기고 설정을 끄면
## 회색 상자로 돌아가는 것을 본다.

const BuildingView = preload("res://game/world/building_view.gd")
const MapView = preload("res://game/world/map_view.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const SulehufMap = preload("res://game/world/sulehuf_map.gd")
const S = FieldGrid.Solid
## 화면 한 장 예산(명세 4.6, 가안): 술레후프 전 건물이 이 안이어야 한다.
const TRIANGLE_BUDGET := 15000
const CUT_SLOTS := ["cut_full", "cut_low"]
const OUTER_LINE := ["ext_wall", "ext_wall_cut", "ext_window", "ext_window_cut", "ext_door", "door_frame_cut"]
var _was_on: Variant


func before_each() -> void:
	_was_on = ProjectSettings.get_setting(BuildingView.MODE_SETTING) if ProjectSettings.has_setting(BuildingView.MODE_SETTING) else null


func after_each() -> void:
	ProjectSettings.set_setting(BuildingView.MODE_SETTING, _was_on)


## 8 × 6 칸 단층 창고 하나: 남쪽 가운데 문, 북쪽과 동쪽에 창, 서쪽 벽에 붙은 가로 안벽,
## 북쪽 벽에 붙은 세로 안벽.
func _shed(two_storey: bool = false) -> Dictionary:
	var g := FieldGrid.new(14, 12)
	var levels := {0: g}
	_walls(g, Rect2i(2, 2, 8, 6))
	_door(g, Vector2i(5, 7))
	_window(g, Vector2i(4, 2))
	_window(g, Vector2i(9, 4))
	for x in range(3, 6):
		g.set_solid(Vector2i(x, 5), S.WALL)
	for y in range(3, 5):
		g.set_solid(Vector2i(7, y), S.WALL)
	var rows := [{"id": 0, "name": "창고", "rect": Rect2i(2, 2, 8, 6)}]
	var uppers := []
	if two_storey:
		var up := FieldGrid.new(14, 12)
		_walls(up, Rect2i(2, 2, 4, 6))
		levels[1] = up
		uppers.append({"building": 0, "rect": Rect2i(2, 2, 4, 6)})
	return {"grid": g, "levels": levels, "buildings": rows, "upper_rects": uppers, "stoves": [], "stairs": []}


func _walls(g: FieldGrid, r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			g.building[g.index(c)] = 0
			if x == r.position.x or y == r.position.y or x == r.end.x - 1 or y == r.end.y - 1:
				g.set_solid(c, S.WALL)


func _door(g: FieldGrid, c: Vector2i) -> void:
	g.set_solid(c, S.DOOR)
	g.doors[c] = {"state": "closed", "hp": 3, "building": 0, "key": ""}


func _window(g: FieldGrid, c: Vector2i) -> void:
	g.set_solid(c, S.WINDOW)
	g.windows[c] = {"broken": false, "glass": false, "building": 0}


func _pieces(p: Dictionary, id: String, slot: String = "") -> Array:
	return p["pieces"].filter(func(row: Dictionary) -> bool: return row.get("id") == id and (slot == "" or row["slot"] == slot))


func _roof_ids(p: Dictionary, b: int) -> Array:
	var ids := []
	for row: Dictionary in p["roofs"]:
		if row["b"] == b:
			ids.append(row["id"])
	return ids


## 조각의 바깥(+Z)이 세계에서 보는 쪽
static func _outward(xf: Transform3D) -> Vector3:
	return (xf.basis * Vector3.BACK).normalized()


## 지도 그리기 없이 키트만 세운다(시야 그림 같은 값은 빈 재질에서 받는다).
func _kit(data: Dictionary) -> Node3D:
	assert_true(BuildingView.can_draw(), "대응표와 조각을 읽는다")
	var kit := BuildingView.new()
	add_child_autofree(kit)
	kit.setup(data, ShaderMaterial.new())
	return kit


## 들고 남 점박이를 다 지나게
func _settle(buildings: Node3D) -> void:
	buildings._process(1.0)


func _triangles(node: Node) -> int:
	var n := 0
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh != null:
			for s in range(child.mesh.get_surface_count()):
				var idx: PackedInt32Array = child.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
				n += idx.size() / 3
	return n


# ---------------------------------------------------------------- 놓는 규칙

func test_cells_split_into_straight_outer_corner_and_inner_walls() -> void:
	var g: FieldGrid = _shed()["grid"]
	assert_eq(BuildingView.cell_kind(g, Vector2i(2, 2), 0), {"kind": "corner", "d": Vector2i(-1, -1)})
	assert_eq(BuildingView.cell_kind(g, Vector2i(9, 7), 0), {"kind": "corner", "d": Vector2i(1, 1)})
	assert_eq(BuildingView.cell_kind(g, Vector2i(6, 7), 0), {"kind": "ext", "n": Vector2i(0, 1)})
	assert_eq(BuildingView.cell_kind(g, Vector2i(6, 2), 0), {"kind": "ext", "n": Vector2i(0, -1)})
	assert_eq(BuildingView.cell_kind(g, Vector2i(9, 3), 0), {"kind": "ext", "n": Vector2i(1, 0)})
	assert_eq(BuildingView.cell_kind(g, Vector2i(4, 5), 0), {"kind": "int"})


func test_l_shaped_building_gets_an_inner_corner() -> void:
	var g := FieldGrid.new(12, 12)
	# ㄱ자: 6 × 6에서 북동쪽 3 × 3을 비운다.
	for y in range(2, 8):
		for x in range(2, 8):
			if x >= 5 and y <= 4:
				continue
			g.building[g.index(Vector2i(x, y))] = 0
	# 빈 자리를 두르는 벽: 서쪽 줄 x = 4(y 2–4), 남쪽 줄 y = 5(x 5–7), 그 사이 꺾인 칸 (4, 5).
	for c: Vector2i in [Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)]:
		g.set_solid(c, S.WALL)
	assert_eq(BuildingView.cell_kind(g, Vector2i(4, 4), 0), {"kind": "ext", "n": Vector2i(1, 0)})
	assert_eq(BuildingView.cell_kind(g, Vector2i(6, 5), 0), {"kind": "ext", "n": Vector2i(0, -1)})
	var kind := BuildingView.cell_kind(g, Vector2i(4, 5), 0)
	assert_eq(kind, {"kind": "inner", "d": Vector2i(1, -1)}, "북동쪽 바깥을 보는 꺾인 모서리")
	assert_true(BuildingView.cut_line(kind), "동쪽으로도 꺾여 카메라 쪽이라 턱 줄")
	assert_eq(BuildingView.cell_kind(g, Vector2i(3, 5), 0), {"kind": "int"}, "꺾인 칸 옆 안쪽 칸")


## 대각뷰(결정 476): 카메라가 남동에서 북서를 본다. 남·동을 보는 줄이 턱 줄.
func test_lines_facing_the_camera_are_cut_lines() -> void:
	assert_true(BuildingView.cut_line({"kind": "ext", "n": Vector2i(0, 1)}))
	assert_true(BuildingView.cut_line({"kind": "ext", "n": Vector2i(1, 0)}))
	assert_false(BuildingView.cut_line({"kind": "ext", "n": Vector2i(0, -1)}))
	assert_false(BuildingView.cut_line({"kind": "ext", "n": Vector2i(-1, 0)}))
	assert_true(BuildingView.cut_line({"kind": "corner", "d": Vector2i(-1, 1)}))
	assert_true(BuildingView.cut_line({"kind": "corner", "d": Vector2i(1, -1)}))
	assert_true(BuildingView.cut_line({"kind": "corner", "d": Vector2i(1, 1)}))
	assert_false(BuildingView.cut_line({"kind": "corner", "d": Vector2i(-1, -1)}), "북서 모서리만 선다")
	assert_false(BuildingView.cut_line({"kind": "int"}))


func test_south_and_east_walls_have_tall_and_low_runs_north_wall_only_stands() -> void:
	var p := BuildingView.plan(_shed())
	# 남쪽 줄: 문(5)을 빼고 3–4, 6–8 두 토막. 동쪽 줄: 창(4)을 빼고 3, 5–6 두 토막.
	# 3 m 와 턱이 짝으로.
	var tall := _pieces(p, "ext_wall", "cut_full")
	var low := _pieces(p, "ext_wall_cut", "cut_low")
	assert_eq(tall.size(), 4)
	assert_eq(low.size(), 4)
	var south := []
	var east := []
	for row: Dictionary in tall:
		var length := snappedf(row["xf"].basis.get_scale().x, 0.01)
		if is_equal_approx(row["xf"].origin.z, 7.5):
			south.append(length)
		else:
			assert_almost_eq(row["xf"].origin.x, 9.5, 0.001, "동쪽 줄 칸 가운데")
			assert_gt(_outward(row["xf"]).x, 0.9, "동쪽을 본다")
			east.append(length)
	south.sort()
	east.sort()
	assert_eq(south, [2.0, 3.0])
	assert_eq(east, [1.0, 2.0])
	# 북쪽 줄: 창(4)을 빼고 3, 5–8. 서는 줄에만 있다.
	var north := _pieces(p, "ext_wall", "stand").filter(func(row: Dictionary) -> bool: return is_equal_approx(row["xf"].origin.z, 2.5))
	assert_eq(north.size(), 2)
	for row: Dictionary in north:
		assert_lt(_outward(row["xf"]).z, -0.9, "북쪽을 본다")


func test_doors_and_windows_take_their_line() -> void:
	var p := BuildingView.plan(_shed())
	assert_eq(p["doors"].size(), 1)
	var door: Dictionary = p["doors"][0]
	assert_eq(door["cell"], Vector2i(5, 7))
	assert_eq(door["line"], "cut", "남쪽 문은 턱 줄")
	assert_true(door["outer"])
	assert_eq(p["outer_doors"][0], [Vector2i(5, 7)])
	assert_eq(_pieces(p, "ext_door", "cut_full").size(), 1)
	assert_eq(_pieces(p, "door_frame_cut", "cut_low").size(), 1)
	var lines := {}
	for row: Dictionary in p["windows"]:
		lines[row["cell"]] = row["line"]
	assert_eq(lines, {Vector2i(4, 2): "stand", Vector2i(9, 4): "cut"}, "동쪽 창은 턱 줄")
	assert_eq(_pieces(p, "ext_window", "stand").size(), 1)
	assert_eq(_pieces(p, "ext_window", "cut_full").size(), 1)
	assert_eq(_pieces(p, "ext_window_cut", "cut_low").size(), 1)


func test_corners_and_plinth_follow_the_outline() -> void:
	var p := BuildingView.plan(_shed())
	assert_eq(_pieces(p, "ext_corner", "stand").size(), 1, "북서 모서리만 선다")
	assert_eq(_pieces(p, "ext_corner", "cut_full").size(), 3, "나머지 셋은 턱 줄")
	assert_eq(_pieces(p, "ext_corner_cut", "cut_low").size(), 3)
	assert_eq(_pieces(p, "ext_plinth_corner").size(), 4)
	# 기단은 문을 비우고 창 밑으로는 지난다: 남쪽 2토막, 북쪽 1, 동쪽 1, 서쪽 1.
	assert_eq(_pieces(p, "ext_plinth").size(), 5)
	# 선 줄이 턱 모서리와 만나는 두 끝(서쪽 줄의 남쪽 끝, 북쪽 줄의 동쪽 끝)은 열렸을 때
	# 마구리로 막는다. 턱 줄끼리 만나는 끝은 막지 않는다.
	var caps := _pieces(p, "wall_end_cap", "int_cut")
	assert_eq(caps.size(), 2)
	var at := []
	for row: Dictionary in caps:
		at.append(Vector2(snappedf(row["xf"].origin.x, 0.01), snappedf(row["xf"].origin.z, 0.01)))
	at.sort()
	assert_eq(at, [Vector2(2.5, 7.0), Vector2(9.0, 2.5)])


func test_inner_walls_run_to_the_outer_wall_middle() -> void:
	var p := BuildingView.plan(_shed())
	var low := _pieces(p, "int_wall_cut", "int_cut")
	assert_eq(low.size(), 2, "대각뷰에서는 가로·세로 안벽 다 턱")
	assert_true(_pieces(p, "int_wall").is_empty())
	var across := low.filter(func(row: Dictionary) -> bool: return is_equal_approx(row["xf"].origin.z, 5.5))
	assert_eq(across.size(), 1)
	var xf: Transform3D = across[0]["xf"]
	# 서쪽 벽 칸(2) 가운데 2.5에서 홀로 끝난 칸(5) 끝 6.0까지.
	assert_almost_eq(xf.basis.get_scale().x, 3.5, 0.001)
	assert_almost_eq(xf.origin.x, 4.25, 0.001)
	assert_almost_eq(xf.origin.z, 5.5, 0.001)
	var down := low.filter(func(row: Dictionary) -> bool: return is_equal_approx(row["xf"].origin.x, 7.5))
	assert_eq(down.size(), 1)
	assert_almost_eq(down[0]["xf"].basis.get_scale().x, 2.5, 0.001, "북쪽 벽 칸 가운데 2.5에서 5.0까지")
	assert_almost_eq(down[0]["xf"].origin.z, 3.75, 0.001)


func test_lone_storey_gets_a_gable_roof_along_its_long_side() -> void:
	var p := BuildingView.plan(_shed())
	assert_eq(_roof_ids(p, 0), ["roof_gable", "roof_gable_end", "roof_gable_end"], "창고에는 굴뚝이 없다")
	var gable: Dictionary = p["roofs"][0]
	assert_almost_eq(gable["xf"].origin.y, BuildingView.LEVEL_H, 0.001, "벽 꼭대기")
	assert_almost_eq(gable["xf"].basis.get_euler().y, 0.0, 0.001, "용마루가 긴 쪽(X)")
	assert_eq(p["footprints"][0], Rect2i(2, 2, 8, 6))


func test_lower_side_of_a_taller_building_gets_a_flat_roof() -> void:
	var p := BuildingView.plan(_shed(true))
	var ids := _roof_ids(p, 0)
	assert_eq(ids.count("roof_flat"), 1)
	assert_eq(ids.count("roof_parapet"), 3, "높은 쪽에 붙은 서쪽 변에는 낮은 벽이 없다")
	assert_eq(ids.count("roof_gable"), 1)
	for row: Dictionary in p["roofs"]:
		if row["id"] == "roof_flat":
			var xf: Transform3D = row["xf"]
			var west := xf.origin.x - xf.basis.get_scale().x * 0.5
			# 높은 쪽 동쪽 벽(칸 5) 바깥면까지 들어간다.
			assert_almost_eq(west, 6.0 - BuildingView.FACE_IN, 0.001)
			assert_almost_eq(xf.origin.y, BuildingView.LEVEL_H, 0.1)
		elif row["id"] == "roof_gable":
			assert_almost_eq(row["xf"].origin.y, 2.0 * BuildingView.LEVEL_H, 0.001, "위층 꼭대기")


func test_sulehuf_doors_windows_and_roofs_are_all_placed_once() -> void:
	var data: Dictionary = SulehufMap.build()
	var p := BuildingView.plan(data)
	var want_doors := {}
	var want_windows := {}
	for lv: int in data["levels"]:
		var lg: FieldGrid = data["levels"][lv]
		for c: Vector2i in lg.doors:
			if lg.building_at(c) >= 0:
				want_doors[Vector3i(c.x, c.y, lv)] = true
		for c: Vector2i in lg.windows:
			if lg.building_at(c) >= 0:
				want_windows[Vector3i(c.x, c.y, lv)] = true
	var got_doors := {}
	for row: Dictionary in p["doors"]:
		var key := Vector3i(row["cell"].x, row["cell"].y, row["lv"])
		assert_false(got_doors.has(key), "문 %s 한 번" % key)
		got_doors[key] = true
	var got_windows := {}
	for row: Dictionary in p["windows"]:
		var key := Vector3i(row["cell"].x, row["cell"].y, row["lv"])
		assert_false(got_windows.has(key), "창 %s 한 번" % key)
		got_windows[key] = true
	assert_eq(got_doors.keys().size(), want_doors.size())
	assert_eq(got_windows.keys().size(), want_windows.size())
	for key in want_doors:
		assert_true(got_doors.has(key), "문 %s" % key)
	for key in want_windows:
		assert_true(got_windows.has(key), "창 %s" % key)
	for row: Dictionary in data["buildings"]:
		var ids := _roof_ids(p, int(row["id"]))
		assert_true(ids.has("roof_gable"), "%s 박공지붕" % row["name"])
	# 역사와 화물 창고는 위층이 1층보다 좁아 낮은 쪽이 평지붕.
	assert_true(_roof_ids(p, 0).has("roof_flat"))
	assert_true(_roof_ids(p, 7).has("roof_flat"))


func test_sulehuf_cut_lines_face_the_camera_and_standing_lines_do_not() -> void:
	var p := BuildingView.plan(SulehufMap.build())
	var cut := 0
	var stand := 0
	for row: Dictionary in p["pieces"]:
		# 안문 틀도 턱 줄에서는 door_frame_cut이라 안 줄(int_)은 뺀다.
		if not row.has("id") or not OUTER_LINE.has(row["id"]) or String(row["slot"]).begins_with("int"):
			continue
		var out := _outward(row["xf"])
		if CUT_SLOTS.has(row["slot"]):
			cut += 1
			assert_true(out.z > 0.9 or out.x > 0.9, "%s %s 턱 줄은 남·동을 본다" % [row["id"], row["xf"].origin])
		else:
			stand += 1
			assert_true(out.z < 0.9 and out.x < 0.9, "%s %s 서는 줄은 북·서를 본다" % [row["id"], row["xf"].origin])
	assert_gt(cut, 0)
	assert_gt(stand, 0)


# ---------------------------------------------------------------- 그리기와 보이는 규칙

func test_sulehuf_draws_with_the_kit_inside_the_triangle_budget() -> void:
	var tris := _triangles(_kit(SulehufMap.build()))
	assert_gt(tris, 1000)
	assert_lt(tris, TRIANGLE_BUDGET)


## map_view가 회색 상자 wall_nodes 자리에 키트의 바깥 턱 줄 노드를 그대로 넣을 수 있게.
func test_cut_nodes_match_the_grey_box_wall_keys() -> void:
	var kit := _kit(SulehufMap.build())
	ProjectSettings.set_setting(BuildingView.MODE_SETTING, false)
	var grey := MapView.new()
	add_child_autofree(grey)
	grey.setup(SulehufMap.build())
	var a: Array = []
	for key: Vector2i in kit.shells:
		if kit.cut_node(key.x, key.y) != null:
			a.append(key)
	var b: Array = grey.wall_nodes.keys().filter(func(k: Vector2i) -> bool: return k.x >= 0)
	a.sort()
	b.sort()
	assert_eq(a, b)


## 건물 한 층의 껍데기(바깥 줄)와 안(안 줄) 노드
static func _nodes(kit: Node3D, b: int, lv: int, slots: Array) -> Array:
	var out := []
	var shell: Dictionary = kit.shells.get(Vector2i(b, lv), {})
	for slot in slots:
		if shell.has(slot):
			out.append(shell[slot])
	return out


func _assert_shown(nodes: Array, on: bool, why: String) -> void:
	assert_false(nodes.is_empty(), why + ": 노드 없음")
	for node: MeshInstance3D in nodes:
		assert_eq(node.visible, on, why)


func test_entering_a_house_opens_it_and_leaving_closes_it() -> void:
	var kit := _kit(SulehufMap.build())
	kit.show_levels(0)
	kit.cut_away(-1, 0)
	_settle(kit)
	var cut: MeshInstance3D = kit.cut_node(4, 0)
	var tall: Mesh = kit.cut_meshes[Vector2i(4, 0)][0]
	var low: Mesh = kit.cut_meshes[Vector2i(4, 0)][1]
	var inside := _nodes(kit, 4, 0, ["int_cut", "int_stand"])
	assert_true(kit.roofs[4].visible, "밖에서는 지붕")
	_assert_shown(inside, false, "밖에서는 안벽을 안 그린다")
	assert_eq(cut.mesh, tall)
	kit.cut_away(4, 0)
	_settle(kit)
	assert_false(kit.roofs[4].visible, "들어가면 지붕을 걷는다")
	assert_true(kit.roofs[5].visible, "이웃 지붕은 그대로")
	_assert_shown(inside, true, "들어가면 안벽")
	assert_eq(cut.mesh, low, "남쪽 줄은 턱만")
	assert_eq(cut.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	kit.cut_away(-1, 0)
	_settle(kit)
	assert_true(kit.roofs[4].visible)
	_assert_shown(inside, false, "나오면 다시 닫힘")
	assert_eq(cut.mesh, tall)


func test_upstairs_hides_the_floor_above_and_the_cellar_hides_the_ground() -> void:
	var kit := _kit(SulehufMap.build())
	var outer := ["cut", "stand"]
	var inner := ["int_cut", "int_stand"]
	kit.show_levels(1)
	kit.cut_away(6, 1)
	_settle(kit)
	_assert_shown(_nodes(kit, 6, 2, outer), false, "위층은 숨긴다")
	_assert_shown(_nodes(kit, 6, 1, inner), true, "든 층은 열림")
	_assert_shown(_nodes(kit, 6, 0, outer), true, "아래층은 닫힌 껍데기")
	_assert_shown(_nodes(kit, 6, 0, inner), false, "아래층 안은 안 그린다")
	assert_false(kit.roofs[6].visible)
	assert_true(kit.roofs[4].visible)
	kit.show_levels(-1)
	kit.cut_away(6, -1)
	_settle(kit)
	_assert_shown(_nodes(kit, 6, -1, inner), true, "지하는 열림")
	_assert_shown(_nodes(kit, 6, 0, outer), false, "지하에서는 땅 위를 숨긴다")
	assert_false(kit.roofs[4].visible)


## 발밑 칸을 c로 두고 둘레 건물을 다시 고른다(시험에는 카메라가 없다).
func _stand_at(kit: Node3D, c: Vector2i) -> void:
	kit._focus_cell = c
	if kit._update_near(c):
		kit._apply()
	_settle(kit)


func test_buildings_near_the_player_open_at_the_players_floor() -> void:
	var kit := _kit(_shed(true))
	kit.show_levels(0)
	kit.cut_away(-1, 0)
	_stand_at(kit, Vector2i(5, 10))
	assert_true(kit.near.has(0), "남쪽 문 앞 2칸")
	var roof: MeshInstance3D = kit.roofs[0]
	assert_false(roof.visible, "둘레 건물은 지붕을 걷는다(그림자도: 남기면 안이 검게 덮인다)")
	_assert_shown(_nodes(kit, 0, 1, ["cut", "stand"]), false, "위층도 걷는다")
	assert_eq(kit.cut_node(0, 0).mesh, kit.cut_meshes[Vector2i(0, 0)][1], "1층 앞벽은 턱")
	_assert_shown(_nodes(kit, 0, 0, ["int_cut"]), true, "1층 안벽")
	assert_true(kit.interior_visible(0, 0), "소품은 시야 가림이 본 칸에만")
	# 멀어지면 다시 닫힌 집.
	_stand_at(kit, Vector2i(13, 11) + Vector2i(12, 12))
	assert_false(kit.near.has(0))
	assert_true(roof.visible)
	assert_eq(kit.cut_node(0, 0).mesh, kit.cut_meshes[Vector2i(0, 0)][0])
	_assert_shown(_nodes(kit, 0, 1, ["cut", "stand"]), true, "위층 다시")
	_assert_shown(_nodes(kit, 0, 0, ["int_cut"]), false, "안벽 다시 숨김")


func test_a_near_building_opens_at_the_players_floor_when_upstairs() -> void:
	var kit := _kit(_shed(true))
	kit.show_levels(1)
	kit.cut_away(-1, 1)
	_stand_at(kit, Vector2i(5, 10))
	assert_eq(kit.cut_node(0, 1).mesh, kit.cut_meshes[Vector2i(0, 1)][1], "플레이어 층이 열린다")
	assert_eq(kit.cut_node(0, 0).mesh, kit.cut_meshes[Vector2i(0, 0)][0], "아래층은 닫힌 껍데기")
	_assert_shown(_nodes(kit, 0, 0, ["cut", "stand"]), true, "아래층 껍데기")
	# 든 건물은 둘레에서 빠지고 든 층 규칙을 따른다.
	kit.cut_away(0, 1)
	_settle(kit)
	assert_false(kit.near.has(0))
	assert_false(kit.roofs[0].visible)


func test_a_door_redraws_when_it_opens_and_breaks() -> void:
	var data: Dictionary = SulehufMap.build()
	var kit := _kit(data)
	var g: FieldGrid = data["grid"]
	var c: Vector2i = kit.outer_doors[4][0]
	var key: Vector3i = Vector3i(c.x, c.y, 0)
	var closed: AABB = kit.door_mesh(key).get_aabb()
	g.set_door_state(c, "open")
	kit.update_door(c)
	assert_false(kit.door_mesh(key).get_aabb().is_equal_approx(closed), "열린 문짝은 돌아간다")
	g.set_door_state(c, "broken")
	kit.update_door(c)
	assert_lt(kit.door_mesh(key).get_aabb().size.y, closed.size.y, "부서진 문짝은 낮다")


# ---------------------------------------------------------------- 지도 그리기에 붙이기

func test_map_view_hands_building_walls_doors_and_windows_to_the_kit() -> void:
	var view := MapView.new()
	add_child_autofree(view)
	view.setup(SulehufMap.build())
	assert_not_null(view.buildings, "설정이 켜져 있으면 키트")
	for key: Vector2i in view.wall_nodes:
		if key.x >= 0:
			assert_eq(view.wall_nodes[key], view.buildings.cut_node(key.x, key.y), "%s 회색 상자 대신 키트 노드" % key)
	assert_true(view.door_nodes.is_empty(), "문은 키트가 그린다")
	assert_true(view.window_nodes.is_empty(), "창도 키트가 그린다")
	view.show_levels(1)
	view.cut_away(6, 1)
	assert_eq(view.buildings.player_lv, 1, "층을 넘긴다")
	assert_eq([view.buildings.open_b, view.buildings.open_lv], [6, 1], "든 건물을 넘긴다")


func test_turning_the_setting_off_draws_grey_boxes() -> void:
	ProjectSettings.set_setting(BuildingView.MODE_SETTING, false)
	var view := MapView.new()
	add_child_autofree(view)
	view.setup(SulehufMap.build())
	assert_null(view.buildings)
	assert_false(view.door_nodes.is_empty(), "회색 상자가 문을 그린다")
	assert_false(view.wall_nodes.is_empty())


## ㄱ자 단층 건물(8×3 위 칸 + 3×5 아래 칸), 오르는 옥상이라 맨 위가 평지붕.
func _l_block(stove: bool = false) -> Dictionary:
	var g := FieldGrid.new(14, 14)
	var a := Rect2i(2, 2, 8, 3)
	var b := Rect2i(2, 5, 3, 5)
	var cells := {}
	for r: Rect2i in [a, b]:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				cells[Vector2i(x, y)] = true
	for c: Vector2i in cells:
		g.building[g.index(c)] = 0
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not cells.has(c + d):
				g.set_solid(c, S.WALL)
	_door(g, Vector2i(6, 4))
	var stoves := [{"building": 0, "cell": Vector2i(3, 7)}] if stove else []
	return {"grid": g, "levels": {0: g}, "buildings": [{"id": 0, "name": "창고", "rect": a}, {"id": 0, "name": "창고", "rect": b}],
		"upper_rects": [], "stoves": stoves, "stairs": [], "rooftops": [{"building": 0}]}


func _roofs_of(p: Dictionary, id: String) -> Array:
	var out := []
	for row: Dictionary in p["roofs"]:
		if row["b"] == 0 and row["id"] == id:
			out.append(row["xf"])
	return out


func test_an_l_shaped_flat_roof_meets_itself_without_a_gap_or_inner_parapets() -> void:
	var p := BuildingView.plan(_l_block())
	var slabs := _roofs_of(p, "roof_flat")
	assert_eq(slabs.size(), 3, "긴 변이 반만 옆 조각에 닿는 곳에서 잘린 세 조각")
	# 조각끼리 맞닿은 변은 칸 경계(x 5, z 5)에서 만난다(예전에는 바깥벽 안쪽으로 0.275씩 줄어 0.55 틈).
	var east_edges := []
	var south_edges := []
	for xf: Transform3D in slabs:
		east_edges.append(snappedf(xf.origin.x + xf.basis.get_scale().x * 0.5, 0.001))
		south_edges.append(snappedf(xf.origin.z + xf.basis.get_scale().z * 0.5, 0.001))
	assert_true(east_edges.has(5.0), "윗줄 서쪽 조각이 동쪽 조각과 x 5에서 만난다 %s" % [east_edges])
	assert_true(south_edges.has(5.0), "윗줄 서쪽 조각이 아랫줄 조각과 z 5에서 만난다 %s" % [south_edges])
	var parapets := _roofs_of(p, "roof_parapet")
	assert_eq(parapets.size(), 8, "바깥 변에만 낮은 벽(안쪽 이음에는 없음)")
	for xf: Transform3D in parapets:
		assert_gt(xf.basis.get_scale().x, 0.0, "낮은 벽 길이가 0 밑으로 뒤집히지 않는다")
		var o := xf.origin
		assert_false(o.x < 5.0 and absf(o.z - 5.0) < 0.6, "윗줄과 아랫줄 사이 안쪽 이음에 낮은 벽 없음 %s" % o)
		assert_false(absf(o.x - 5.0) < 0.6 and o.z > 2.6 and o.z < 4.9, "윗줄 두 조각 사이 이음에 낮은 벽 없음 %s" % o)


func test_a_one_cell_deep_flat_piece_keeps_its_parapets_the_right_way_round() -> void:
	var g := FieldGrid.new(14, 8)
	_walls(g, Rect2i(2, 2, 8, 1))
	_door(g, Vector2i(5, 2))
	var p := BuildingView.plan({"grid": g, "levels": {0: g}, "buildings": [{"id": 0, "name": "창고", "rect": Rect2i(2, 2, 8, 1)}],
		"upper_rects": [], "stoves": [], "stairs": [], "rooftops": [{"building": 0}]})
	for xf: Transform3D in _roofs_of(p, "roof_parapet"):
		assert_gt(xf.basis.get_scale().x, 0.0)
	assert_eq(_roofs_of(p, "roof_parapet").size(), 2, "깊이 한 칸이면 가로 벽 둘이 끝까지 덮는다")


func test_a_flat_only_building_with_a_stove_gets_its_chimney() -> void:
	assert_eq(_roofs_of(BuildingView.plan(_l_block(true)), "chimney").size(), 1, "난로가 있으면 꼴과 상관없이 굴뚝")
	var chimney: Transform3D = _roofs_of(BuildingView.plan(_l_block(true)), "chimney")[0]
	assert_almost_eq(chimney.origin.x, 3.5, 0.001, "난로 칸 위")
	assert_almost_eq(chimney.origin.z, 7.5, 0.001)
	assert_almost_eq(chimney.origin.y, BuildingView.LEVEL_H, 0.1, "평지붕 위")
	assert_eq(_roofs_of(BuildingView.plan(_l_block()), "chimney").size(), 0, "난로 없는 창고는 굴뚝 없음")


func test_rows_of_one_building_give_one_form_in_any_order() -> void:
	var looks := []
	for order: Array in [[0, 1], [1, 0]]:
		var g := FieldGrid.new(40, 16)
		_walls(g, Rect2i(2, 2, 8, 6))
		_door(g, Vector2i(5, 7))
		var rows := [{"id": 0, "name": "조립 공장", "rect": Rect2i(2, 2, 8, 6)}, {"id": 0, "name": "조립 공장", "rect": Rect2i(12, 2, 16, 10)}]
		var data := {"grid": g, "levels": {0: g}, "buildings": [rows[order[0]], rows[order[1]]], "upper_rects": [],
			"stoves": [], "stairs": [], "place_id": "factory_02"}
		looks.append(BuildingView.plan(data)["looks"][0]["roof"])
	assert_eq(looks[0], looks[1], "줄 순서가 꼴을 바꾸지 않는다")
	assert_eq(looks[0], "flat", "두 줄의 넓이 합(208칸)으로 큰 공장")
