extends "res://addons/gut/test.gd"
## 건물 키트 그리기(building_view.gd, 명세 건물 v1 3·4장): 지도 격자에서 조각을 놓는 규칙,
## 닫힘·열림·지하의 보이는 규칙, 지도 그리기(map_view)가 건물을 키트에 넘기고 설정을 끄면
## 회색 상자로 돌아가는 것을 본다.

const BuildingView = preload("res://game/world/building_view.gd")
const BuildingForms = preload("res://game/world/building_forms.gd")
const BuildingCensus = preload("res://tools/building_census.gd")
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


func _roofs_of(p: Dictionary, id: String, b: int = 0) -> Array:
	var out := []
	for row: Dictionary in p["roofs"]:
		if row["b"] == b and row["id"] == id:
			out.append(row["xf"])
	return out


func test_an_l_shaped_flat_roof_meets_itself_without_a_gap_or_inner_parapets() -> void:
	var p := BuildingView.plan(_l_block())
	var slabs := _roofs_of(p, "roof_flat")
	assert_eq(slabs.size(), 3, "긴 변이 반만 옆 조각에 닿는 곳에서 잘린 세 조각")
	# 조각끼리 맞닿은 변은 틈 없이 만난다(예전에는 바깥벽 안쪽으로 0.275씩 줄어 0.55 틈). ㄱ자 안쪽 모서리
	# (x 5·z 5)의 벽 바깥면 너머 네모는 어느 판도 덮지 않는다.
	var boxes := []
	var south_edges := []
	for xf: Transform3D in slabs:
		var half := xf.basis.get_scale() * 0.5
		boxes.append(Rect2(xf.origin.x - half.x, xf.origin.z - half.z, half.x * 2.0, half.z * 2.0))
		south_edges.append(snappedf(xf.origin.z + half.z, 0.001))
	assert_true(south_edges.has(5.0), "윗줄 서쪽 조각이 아랫줄 조각과 z 5에서 만난다 %s" % [south_edges])
	for at: Vector2 in [Vector2(4.6, 3.5), Vector2(4.9, 3.5), Vector2(3.5, 4.99), Vector2(3.5, 5.01), Vector2(4.6, 4.9)]:
		assert_true(boxes.any(func(box: Rect2) -> bool: return box.has_point(at)), "이음 자리를 판이 덮는다 %s %s" % [at, boxes])
	assert_false(boxes.any(func(box: Rect2) -> bool: return box.has_point(Vector2(4.86, 4.86))), "안쪽 모서리 바깥 네모는 비운다 %s" % [boxes])
	for i in range(boxes.size()):
		for j in range(i + 1, boxes.size()):
			assert_lt((boxes[i] as Rect2).intersection(boxes[j]).get_area(), 0.0001, "판끼리 겹치지 않는다")
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


func test_non_dictionary_building_rows_are_ignored() -> void:
	var data: Dictionary = _shed(true)
	data["rooms"] = []
	data["rooftops"] = []
	var clean: Dictionary = BuildingView.plan(data)
	for key: String in ["buildings", "upper_rects", "rooms", "rooftops"]:
		data[key].push_front(null)
		data[key].append("not a row")
		data[key].append(7)
	assert_eq(BuildingView.plan(data), clean, "입력 표의 사전 아닌 줄은 배치에 영향을 주지 않는다")


func test_town_paint_indices_follow_the_shared_palette() -> void:
	assert_eq(BuildingView.PAINTS, BuildingForms.TOWN_PAINTS)
	for b: int in range(32):
		var paint: Color = BuildingView.paint_for(b)
		var look: Dictionary = BuildingForms.pick({"id": b, "name": "살림집"}, "houses_01", paint)
		var expected: Color = BuildingView.PAINTS[int(look["paint_index"])]
		expected.a = paint.a
		assert_eq(paint, expected)


func _roof_case(shape: String, name: String = "살림집", size: Vector2i = Vector2i(14, 8), want_dormer: bool = false) -> Dictionary:
	var r: Rect2i = Rect2i(Vector2i(2, 2), size)
	var chosen: int = -1
	for b: int in range(512):
		var row: Dictionary = {"id": b, "name": name, "rect": r}
		var look: Dictionary = BuildingForms.pick(row, "houses_01", BuildingView.paint_for(b))
		if look["silhouette"] == shape and (not want_dormer or int(look["dormers"]) > 0):
			chosen = b
			break
	assert_gte(chosen, 0, "표의 후보에서 표본 번호를 찾는다")
	var grid: FieldGrid = FieldGrid.new(size.x + 5, size.y + 5)
	_walls(grid, r)
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			grid.building[grid.index(Vector2i(x, y))] = chosen
	var door: Vector2i = Vector2i(r.position.x + 2, r.end.y - 1)
	_door(grid, door)
	grid.doors[door]["building"] = chosen
	return {"grid": grid, "levels": {0: grid}, "place_id": "houses_01",
		"buildings": [{"id": chosen, "name": name, "rect": r}], "stoves": [], "stairs": []}


func test_hip_roof_uses_two_caps_and_shortens_the_gable_body() -> void:
	var data: Dictionary = _roof_case("hip")
	var b: int = int(data["buildings"][0]["id"])
	var p: Dictionary = BuildingView.plan(data)
	assert_eq(_roof_ids(p, b).count("roof_hip_end"), 2)
	assert_false(_roof_ids(p, b).has("roof_gable_end"))
	var bodies: Array = _roofs_of(p, "roof_gable", b)
	assert_eq(bodies.size(), 1)
	if bodies.size() != 1:
		return
	var body: Transform3D = bodies[0]
	assert_almost_eq(body.basis.get_scale().x, 14.0 - 8.0, 0.001, "몸통은 길이에서 경간을 뺀 만큼")
	var caps: Array = _roofs_of(p, "roof_hip_end", b)
	for cap: Transform3D in caps:
		assert_almost_eq(cap.basis.get_scale().y, body.basis.get_scale().y, 0.001)
		assert_almost_eq(cap.basis.get_scale().z, body.basis.get_scale().z, 0.001)
		assert_almost_eq(absf(cap.origin.x - body.origin.x), 3.0, 0.001, "용마루 끝끼리 맞닿는다")
	for size: Vector2i in [Vector2i(8, 8), Vector2i(8, 10)]:
		var square: Dictionary = _roof_case("hip", "살림집", size)
		var square_id: int = int(square["buildings"][0]["id"])
		var pyramid: Dictionary = BuildingView.plan(square)
		assert_eq(_roof_ids(pyramid, square_id).count("roof_hip_end"), 2)
		assert_false(_roof_ids(pyramid, square_id).has("roof_gable"), "길이 <= 경간이면 끝 둘만으로 피라미드")
	var rotated: Dictionary = _roof_case("hip", "살림집", Vector2i(8, 14))
	var rotated_id: int = int(rotated["buildings"][0]["id"])
	var turned: Dictionary = BuildingView.plan(rotated)
	var rotated_body: Transform3D = _roofs_of(turned, "roof_gable", rotated_id)[0]
	assert_almost_eq(rotated_body.basis.get_euler().y, PI * 0.5, 0.001)
	assert_almost_eq(rotated_body.basis.get_scale().x, 6.0, 0.001)


func test_shed_and_half_hip_have_only_their_own_end_walls() -> void:
	var data: Dictionary = _roof_case("shed", "차고", Vector2i(6, 5))
	var b: int = int(data["buildings"][0]["id"])
	var p: Dictionary = BuildingView.plan(data)
	assert_eq(_roof_ids(p, b).count("roof_shed"), 1)
	assert_eq(_roof_ids(p, b).count("roof_shed_wall"), 1)
	assert_eq(_roof_ids(p, b).count("roof_shed_side"), 2)
	assert_false(_roof_ids(p, b).has("roof_gable_end"))
	assert_false(_roof_ids(p, b).has("roof_gable"))
	var shed: Transform3D = _roofs_of(p, "roof_shed", b)[0]
	assert_almost_eq(shed.basis.get_euler().y, 0.0, 0.001, "독립 외쪽은 북쪽이 높다")
	data = _roof_case("half_hip")
	b = int(data["buildings"][0]["id"])
	p = BuildingView.plan(data)
	assert_eq(_roof_ids(p, b).count("roof_half_hip_end"), 2)
	assert_eq(_roof_ids(p, b).count("roof_half_hip_wall"), 2)
	assert_false(_roof_ids(p, b).has("roof_gable_end"), "위 1/3까지 올라간 박공 벽을 남기지 않는다")


func test_shed_high_wall_stops_at_wall_length_in_both_orientations() -> void:
	for size: Vector2i in [Vector2i(6, 5), Vector2i(5, 6)]:
		for center: Vector2 in [Vector2(INF, INF), Vector2(100.0, 100.0)]:
			var p: Dictionary = {"roofs": []}
			var g: Dictionary = BuildingView._plan_gable(p, Rect2i(Vector2i(2, 2), size), 3.0, 0, 1.0, "shed", center)
			var wall: Transform3D = _roofs_of(p, "roof_shed_wall", 0)[0]
			var roof: Transform3D = _roofs_of(p, "roof_shed", 0)[0]
			var wall_length: float = float(maxi(size.x, size.y)) - 2.0 * BuildingView.FACE_IN
			assert_almost_eq(wall.basis.get_scale().x, wall_length, 0.001)
			assert_almost_eq(roof.basis.get_scale().x - wall.basis.get_scale().x, 2.0 * BuildingView.OVERHANG, 0.001)
			for end: float in [-0.5, 0.5]:
				var at: Vector3 = wall * Vector3(end, 0.0, -5.0)
				var local: Vector2 = BuildingView._roof_local(g, Vector2(at.x, at.z))
				assert_lte(absf(local.x), wall_length * 0.5 + 0.001, "높은 벽은 처마 끝까지 늘어나지 않는다")


func test_hip_and_mansard_chimney_bases_follow_the_actual_roof_plane() -> void:
	for shape: String in ["hip", "mansard"]:
		var data: Dictionary = _roof_case(shape, "헛간" if shape == "mansard" else "살림집")
		var b: int = int(data["buildings"][0]["id"])
		var r: Rect2i = data["buildings"][0]["rect"]
		# 모임의 끝 경사가 옆 경사보다 낮은 곳: 예전 박공 식이면 공중에 뜨는 표본.
		data["stoves"] = [{"building": b, "cell": Vector2i(r.end.x - 2, r.position.y + 2)}]
		var p: Dictionary = BuildingView.plan(data)
		var chimneys: Array = _roofs_of(p, "chimney", b)
		assert_eq(chimneys.size(), 1)
		if chimneys.size() != 1:
			continue
		var chimney: Transform3D = chimneys[0]
		var k: float = (float(r.size.y) - 2.0 * BuildingView.FACE_IN) / BuildingView.ROOF_SPAN
		var pitch: float = float(p["looks"][b]["pitch"])
		var center: Vector2 = Vector2(r.position) + Vector2(r.size) * 0.5
		var cross: float = absf(chimney.origin.z - center.y)
		var rise: float = k * BuildingView.ROOF_RISE
		var height: float = rise - cross * tan(deg_to_rad(20.0))
		if shape == "hip":
			var body: float = float(r.size.x - r.size.y)
			var run: float = (float(r.size.y) - 2.0 * BuildingView.FACE_IN + 2.0 * BuildingView.OVERHANG) * 0.5
			var from_tip: float = maxf(0.0, absf(chimney.origin.x - center.x) - body * 0.5)
			var end_height: float = rise - from_tip / run * k * (BuildingView.ROOF_RISE + BuildingView.ROOF_EAVE * BuildingView.ROOF_TAN)
			height = minf(rise - cross * BuildingView.ROOF_TAN, end_height)
		var surface: float = BuildingView.LEVEL_H + pitch * height
		assert_almost_eq(chimney.origin.y, surface, 0.2, "%s 굴뚝 밑은 지붕 면에 묻힌다" % shape)


func _matching_home_ids() -> Array[int]:
	var buckets: Dictionary = {}
	for b: int in range(4096):
		var row: Dictionary = {"id": b, "name": "살림집", "rect": Rect2i(2, 2, 8, 6)}
		var signature: String = BuildingForms.signature(BuildingForms.pick(row, "houses_01", BuildingView.paint_for(b)))
		if not buckets.has(signature):
			buckets[signature] = []
		buckets[signature].append(b)
		if (buckets[signature] as Array).size() == 5:
			var result: Array[int] = []
			result.assign(buckets[signature])
			return result
	assert_true(false, "같은 초기 꼴 다섯 채의 번호를 찾는다")
	return []


func _five_homes(joined: bool = false) -> Dictionary:
	var ids: Array[int] = _matching_home_ids()
	var grid: FieldGrid = FieldGrid.new(60, 12)
	var rows: Array = []
	for i: int in range(ids.size()):
		var r: Rect2i = Rect2i(2 + i * 10, 2, 8, 6)
		_walls(grid, r)
		for y: int in range(r.position.y, r.end.y):
			for x: int in range(r.position.x, r.end.x):
				grid.building[grid.index(Vector2i(x, y))] = ids[i]
		var door: Vector2i = Vector2i(r.position.x + 2, r.end.y - 1)
		_door(grid, door)
		grid.doors[door]["building"] = ids[i]
		var row: Dictionary = {"id": ids[i], "name": "살림집", "rect": r}
		if joined:
			row["row_group"] = "terrace-a"
		rows.append(row)
	return {"grid": grid, "levels": {0: grid}, "buildings": rows, "place_id": "houses_01", "stoves": [], "stairs": []}


func _same_neighbours(p: Dictionary, b: int) -> int:
	var r: Rect2i = p["footprints"][b]
	var center: Vector2 = Vector2(r.position) + Vector2(r.size) * 0.5
	var signature: String = BuildingForms.signature(p["looks"][b])
	var count: int = 0
	for other: int in p["looks"]:
		if other == b or BuildingForms.signature(p["looks"][other]) != signature:
			continue
		var q: Rect2i = p["footprints"][other]
		if center.distance_to(Vector2(q.position) + Vector2(q.size) * 0.5) <= 24.0:
			count += 1
	return count


func test_five_matching_homes_avoid_near_repeats_deterministically() -> void:
	var data: Dictionary = _five_homes()
	var p: Dictionary = BuildingView.plan(data)
	assert_eq(p["looks"].size(), 5)
	var changed: int = 0
	for row: Dictionary in data["buildings"]:
		var b: int = int(row["id"])
		var initial: Dictionary = BuildingForms.pick(row, "houses_01", BuildingView.paint_for(b))
		changed += 1 if BuildingForms.signature(initial) != BuildingForms.signature(p["looks"][b]) else 0
		assert_lte(_same_neighbours(p, b), 2, "24 m 안 같은 서명 이웃은 둘 이하")
		assert_eq(p["looks"][b]["paint_index"], initial["paint_index"], "이 표본은 실루엣만 돌려 풀린다")
	assert_gt(changed, 0, "원래부터 다른 꼴인 표본으로 통과시키지 않는다")
	data["buildings"].reverse()
	var reversed: Dictionary = BuildingView.plan(data)
	assert_eq(p["looks"], reversed["looks"])
	assert_eq(p["roofs"], reversed["roofs"])


func _look_neighbourhood(template: Dictionary, centres: Array[Vector2i]) -> Dictionary:
	var p: Dictionary = {"looks": {}, "footprints": {}, "row_groups": {}}
	for b: int in range(centres.size()):
		p["looks"][b] = template.duplicate(true)
		p["footprints"][b] = Rect2i(centres[b] - Vector2i.ONE, Vector2i(2, 2))
		p["row_groups"][b] = null
	return p


func test_star_neighbours_rotate_a_shape_because_of_the_centres_overflow() -> void:
	var original: Dictionary = BuildingForms.pick({"id": 0, "name": "살림집", "rect": Rect2i(0, 0, 8, 6)},
		"houses_01", BuildingView.paint_for(0))
	var centres: Array[Vector2i] = [Vector2i.ZERO, Vector2i(-20, 0), Vector2i(20, 0), Vector2i(0, -20), Vector2i(0, 20)]
	var p: Dictionary = _look_neighbourhood(original, centres)
	var neighbours: Dictionary = {0: [1, 2, 3, 4], 1: [0], 2: [0], 3: [0], 4: [0]}
	for a: int in range(1, centres.size()):
		assert_lte(Vector2(centres[a]).length(), BuildingView.LOOK_RADIUS)
		for b: int in range(a + 1, centres.size()):
			assert_gt(Vector2(centres[a]).distance_to(Vector2(centres[b])), BuildingView.LOOK_RADIUS)
	assert_eq(BuildingView._look_conflicts(p["looks"], neighbours, {0: true, 1: true, 2: true}, 3, original), 1,
		"자기 이웃은 하나뿐: 가운데 창에 네 번째를 더하는 overflow만 벌점")
	var ids: Array[int] = [0, 1, 2, 3, 4]
	BuildingView._avoid_near_looks(p, ids)
	assert_ne(p["looks"][3]["silhouette"], original["silhouette"], "overflow가 실제 꼴을 돌린다")
	for b: int in ids:
		assert_eq(p["looks"][b]["paint_index"], original["paint_index"])
		assert_eq(p["looks"][b]["neighbor_conflicts"], 0)
		assert_lte(_same_neighbours(p, b), 2)


func test_dense_single_shape_barns_cycle_paint_and_report_exhausted_candidates() -> void:
	var original: Dictionary = BuildingForms.pick({"id": 0, "name": "헛간", "rect": Rect2i(0, 0, 8, 6)},
		"houses_01", BuildingView.paint_for(0))
	assert_eq(original["candidates"], ["mansard"])
	assert_eq((BuildingForms.PALETTES[original["palette"]] as Array).size(), 2)
	var centres: Array[Vector2i] = [Vector2i(0, 0), Vector2i(3, 0), Vector2i(6, 0), Vector2i(9, 0), Vector2i(12, 0), Vector2i(15, 0)]
	var p: Dictionary = _look_neighbourhood(original, centres)
	var ids: Array[int] = [0, 1, 2, 3, 4, 5]
	BuildingView._avoid_near_looks(p, ids)
	var paints: Dictionary = {}
	var unresolved: int = 0
	for b: int in ids:
		var look: Dictionary = p["looks"][b]
		assert_eq(look["silhouette"], "mansard", "후보 소진에도 용도 밖 꼴은 넣지 않는다")
		paints[look["paint_index"]] = true
		var expected: Color = (BuildingForms.PALETTES[look["palette"]][int(look["paint_index"])] as Color).srgb_to_linear()
		expected.a = (original["paint"] as Color).a
		assert_eq(look["paint"], expected)
		unresolved += 1 if int(look["neighbor_conflicts"]) > 0 else 0
	assert_eq(paints.size(), 2, "실루엣 하나를 다 쓰면 칠을 돌린다")
	assert_gt(unresolved, 0, "모든 후보 소진을 neighbor_conflicts에 남긴다")


func test_row_group_exempts_matching_homes_without_exempting_missing_groups() -> void:
	var data: Dictionary = _five_homes(true)
	var p: Dictionary = BuildingView.plan(data)
	var most: int = 0
	for row: Dictionary in data["buildings"]:
		var b: int = int(row["id"])
		var initial: Dictionary = BuildingForms.pick(row, "houses_01", BuildingView.paint_for(b))
		assert_eq(BuildingForms.signature(p["looks"][b]), BuildingForms.signature(initial))
		most = maxi(most, _same_neighbours(p, b))
	assert_gt(most, 2, "연립 예외가 실제로 같은 꼴을 보존한다")
	assert_false(BuildingForms.same_row_group(null, null))
	assert_false(BuildingForms.same_row_group("", ""))
	assert_false(BuildingForms.same_row_group("terrace-a", "terrace-b"))
	assert_true(BuildingForms.same_row_group(0, 0), "숫자 row_group 0도 명시된 무리")
	assert_false(BuildingForms.same_row_group(0, "0"), "서로 다른 자료형을 합치지 않는다")


func test_census_reads_actual_dormers_and_row_group_exemption() -> void:
	for joined: bool in [false, true]:
		var data: Dictionary = _five_homes(joined)
		var p: Dictionary = BuildingView.plan(data)
		var rows: Array = BuildingCensus.rows_of("houses_01", data, p)
		var metrics: Dictionary = BuildingCensus.roof_metrics(rows)
		assert_eq(rows.size(), 5)
		assert_eq(metrics["status"], "collected")
		assert_lte(int(metrics["near_same_max"]), 0 if joined else 2)
		assert_eq(metrics["near_same_ge3_buildings"], 0)
		assert_gte(float(metrics["map_form_median"]), 1.0)
		for row: Dictionary in rows:
			assert_eq(int(row["dormers"]), _roofs_of(p, "roof_dormer", int(row["b"])).size())
	assert_eq(BuildingCensus.roof_metrics([{"map": "old", "b": 0}])["status"], "not_collected")


func test_narrow_homes_drop_their_requested_dormers() -> void:
	for short_side: int in [5, 6, 7]:
		for shape: String in ["gable", "hip"]:
			var data: Dictionary = _roof_case(shape, "살림집", Vector2i(8, short_side), true)
			var row: Dictionary = data["buildings"][0]
			var b: int = int(row["id"])
			assert_gt(int(BuildingForms.pick(row, "houses_01", BuildingView.paint_for(b))["dormers"]), 0)
			var p: Dictionary = BuildingView.plan(data)
			assert_eq(_roofs_of(p, "roof_dormer", b).size(), 0, "짧은 변 5~7칸 집의 돌출 지붕창을 막는다")
			assert_eq(p["looks"][b]["dormers"], 0, "현황 셈에도 실제 배치 수 0")


func test_dormer_peaks_and_backs_fit_narrow_and_wide_homes() -> void:
	var peak: float = 1.0 + 0.65 * tan(deg_to_rad(35.0)) + 0.06
	var back: float = peak / tan(deg_to_rad(35.0)) + 0.1
	for size: Vector2i in [Vector2i(8, 6), Vector2i(14, 8), Vector2i(6, 8), Vector2i(8, 14)]:
		for shape: String in ["gable", "hip", "mansard"]:
			for pitch: float in [0.85, 1.0, 1.3, 1.7]:
				var p: Dictionary = {"roofs": []}
				var g: Dictionary = BuildingView._plan_gable(p, Rect2i(Vector2i(2, 2), size), 3.0, 0, pitch, shape)
				var count: int = BuildingView._plan_dormers(p, g, 0, 3, Vector2(INF, INF))
				# 용마루 방향 규칙(가로가 세로의 0.75배 이상이면 가로)에 따라 6×8은 경간이 8칸 쪽이다.
				if float(g["span"]) * 0.32 < BuildingView.DORMER_REAR:
					assert_eq(count, 0, "경간이 좁은 8×6 집에는 지붕창을 놓지 않는다")
				elif mini(size.x, size.y) == 8:
					assert_gt(count, 0, "14×8에서는 꼭대기 검사 표본을 실제로 만든다")
				for dormer: Transform3D in _roofs_of(p, "roof_dormer", 0):
					var local: Vector2 = BuildingView._roof_local(g, Vector2(dormer.origin.x, dormer.origin.z))
					var ridge: Vector2 = BuildingView._roof_world(g, Vector2(local.x, 0.0))
					var tip: Vector3 = dormer * Vector3(0.0, peak, 0.0)
					assert_lte(tip.y, BuildingView._roof_height(g, ridge) + 0.001, "덮개 꼭대기까지 용마루 아래")
					var rear: Vector3 = dormer * Vector3(0.0, peak, -back)
					assert_lte(rear.y, BuildingView._roof_height(g, Vector2(rear.x, rear.z)) + 0.001, "뒤 박공과 덮개가 본 지붕에 묻힌다")


func test_dormers_reject_the_roof_just_below_the_full_rear_depth() -> void:
	var minimum: float = (1.0 + 0.65 * tan(deg_to_rad(35.0)) + 0.06) / tan(deg_to_rad(35.0)) + 0.2
	for shape: String in ["gable", "hip", "mansard"]:
		for delta: float in [-0.001, 0.001]:
			var p: Dictionary = {"roofs": []}
			var g: Dictionary = BuildingView._plan_gable(p, Rect2i(2, 2, 14, 8), 3.0, 0, 1.0, shape)
			g["span"] = (minimum + delta) / 0.32
			g["k"] = float(g["span"]) / BuildingView.ROOF_SPAN
			var count: int = BuildingView._plan_dormers(p, g, 0, 1, Vector2(INF, INF))
			assert_eq(count, 0 if delta < 0.0 else 1, "뒤 처마 끝 깊이 문턱: %s" % shape)


func test_dormers_sit_on_the_slope_and_keep_clear_of_the_chimney() -> void:
	for shape: String in ["gable", "hip", "mansard"]:
		var data: Dictionary = _roof_case(shape, "시청 본관" if shape == "mansard" else "살림집", Vector2i(14, 8), true)
		var b: int = int(data["buildings"][0]["id"])
		data["stoves"] = [{"building": b, "cell": Vector2i(10, 5)}]
		var p: Dictionary = BuildingView.plan(data)
		var dormers: Array = _roofs_of(p, "roof_dormer", b)
		assert_gt(dormers.size(), 0)
		assert_lte(dormers.size(), 3)
		assert_eq(dormers.size(), int(p["looks"][b]["dormers"]))
		var chimney: Transform3D = _roofs_of(p, "chimney", b)[0]
		var pitch: float = float(p["looks"][b]["pitch"])
		var k: float = (8.0 - 2.0 * BuildingView.FACE_IN) / BuildingView.ROOF_SPAN
		var slope: float = tan(deg_to_rad(20.0 if shape == "mansard" else 35.0))
		for dormer: Transform3D in dormers:
			var surface: float = BuildingView.LEVEL_H + pitch * (k * BuildingView.ROOF_RISE - absf(dormer.origin.z - 6.0) * slope)
			assert_almost_eq(dormer.origin.y, surface, 0.002)
			assert_gt(Vector2(dormer.origin.x, dormer.origin.z).distance_to(Vector2(chimney.origin.x, chimney.origin.z)), 1.2)
		assert_eq(_pieces(p, "roof_dormer").size(), 0, "지붕창도 roofs 한 경로로 굽는다")


func test_new_roofs_bake_to_one_node_and_follow_cut_away_and_near() -> void:
	# 새 GLB 굽기·가져오기 뒤 실행한다. 시야 구멍은 같은 건물 셰이더를 사용한다.
	for shape: String in ["hip", "half_hip", "mansard", "shed"]:
		var data: Dictionary = _roof_case(shape, "차고" if shape == "shed" else ("헛간" if shape == "mansard" else "살림집"),
			Vector2i(6, 5) if shape == "shed" else Vector2i(14, 8))
		var b: int = int(data["buildings"][0]["id"])
		var kit: Node3D = _kit(data)
		assert_eq(kit.roofs.size(), 1)
		var roof: MeshInstance3D = kit.roofs[b]
		assert_eq(roof.mesh.get_surface_count(), 1, "한 지붕 메시·재질")
		assert_eq(roof.material_override, kit.material, "시야 가림 구멍을 쓰는 공용 셰이더")
		kit.show_levels(0)
		_stand_at(kit, Vector2i(100, 100))
		kit.cut_away(b, 0)
		_settle(kit)
		assert_false(roof.visible)
		kit.cut_away(-1, 0)
		_stand_at(kit, Vector2i(100, 100))
		assert_true(roof.visible)
		var r: Rect2i = data["buildings"][0]["rect"]
		_stand_at(kit, Vector2i(r.position.x + 2, r.end.y + 1))
		assert_false(roof.visible, "가까이 가면 새 지붕과 끝 벽도 함께 걷는다")
		assert_eq(roof.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "새 지붕도 박공처럼 그림자를 드리운다")


func test_census_measures_map_median_and_crowded_windows() -> void:
	var rows: Array = []
	for b: int in range(4):
		rows.append({"map": "a", "b": b, "center": [float(b * 10), 0.0], "silhouette": "gable",
			"signature": "same", "form_combo": "gable|normal|render|0"})
	rows.append({"map": "b", "b": 0, "center": [0.0, 0.0], "silhouette": "gable", "signature": "first", "form_combo": "gable|normal|render|0"})
	rows.append({"map": "b", "b": 1, "center": [10.0, 0.0], "silhouette": "hip", "signature": "second", "form_combo": "hip|normal|render|1"})
	var metrics: Dictionary = BuildingCensus.roof_metrics(rows)
	assert_eq(metrics["silhouette_count"], 2)
	assert_almost_eq(float(metrics["dominant_silhouette_share"]), 5.0 / 6.0, 0.001)
	assert_eq(metrics["map_form_median"], 1.5)
	assert_eq(metrics["map_form_min"], 1)
	assert_eq(metrics["near_same_max"], 3)
	assert_eq(metrics["near_same_ge3_buildings"], 2)
	# 한 용도의 줄만 모아도 다른 용도의 이웃을 잃지 않는다.
	assert_eq(BuildingCensus.roof_metrics([rows[1]], rows)["near_same_max"], 3)
