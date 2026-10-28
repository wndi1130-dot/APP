extends "res://addons/gut/test.gd"
## 필드 선로의 침목과 레일(track_view.gd, 결정 476 대각뷰 점검 7): 선로 칸에서 줄기를 읽고,
## 조각을 온 세상 같은 간격으로 깔아 지도 끝 안팎이 이어지며, 열차와 화차는 레일 윗면에 선다.

const TrackView = preload("res://game/world/track_view.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const Kit = preload("res://game/world/train_model_kit.gd")
const FieldGame = preload("res://game/field_game.gd")
const MapView = preload("res://game/world/map_view.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const F = FieldGrid.Floor


## 본선(1~3줄, 3칸 폭) 끝까지, 나란히 붙은 두 줄(6~11줄, 6칸 폭) x 4~9, 1칸 곁선(14줄) x 12~14.
func _grid() -> FieldGrid:
	var g := FieldGrid.new(20, 16)
	for x in 20:
		for y in [1, 2, 3]:
			g.floor[g.index(Vector2i(x, y))] = F.RAIL
	for x in range(4, 10):
		for y in range(6, 12):
			g.floor[g.index(Vector2i(x, y))] = F.RAIL
	for x in range(12, 15):
		g.floor[g.index(Vector2i(x, 14))] = F.RAIL
	return g


## 가운데 줄 z인 줄기의 [x0, x1], 없으면 빈 배열.
func _span(list: Array, z: float) -> Array:
	for run: Dictionary in list:
		if is_equal_approx(float(run["z"]), z):
			return [float(run["x0"]), float(run["x1"])]
	return []


func test_rail_cells_read_as_lines_three_cells_a_set() -> void:
	var found := TrackView.runs(_grid())
	assert_eq(found.size(), 4, "the main line, two side by side, one siding")
	assert_eq(_span(found, 2.5), [0.0, 20.0])
	assert_eq(_span(found, 7.5), [4.0, 10.0])
	assert_eq(_span(found, 10.5), [4.0, 10.0])
	assert_eq(_span(found, 14.5), [12.0, 15.0])


func test_pieces_keep_one_spacing_so_runs_that_meet_join() -> void:
	var whole := TrackView.spots([{"x0": 0.0, "x1": 20.0, "z": 2.5}])
	assert_eq(whole.size(), 29)
	assert_almost_eq(whole[0].x, TrackView.STEP * 0.5, 0.0001)
	# The map's own run and the one past its edge give the same pieces, none twice.
	var halves := TrackView.spots([{"x0": 0.0, "x1": 10.0, "z": 2.5}, {"x0": 10.0, "x1": 20.0, "z": 2.5}])
	assert_eq(halves.size(), whole.size())
	for i in whole.size():
		assert_true(halves.has(whole[i]))
	var west := TrackView.spots(TrackView.outside_runs([Rect2(-60, 1, 60, 3)], 20.0))
	assert_almost_eq(whole[0].x - west[west.size() - 1].x, TrackView.STEP, 0.0001, "no gap or overlap at the edge")


func test_outside_runs_follow_the_map_rule_and_skip_lines_along_z() -> void:
	var out := TrackView.outside_runs([Rect2(20, 6, 60, 6), Rect2(5, -60, 3, 60)], 20.0)
	assert_eq(out.size(), 2, "two lines past the east edge, none for a north run")
	assert_almost_eq(float(out[0]["z"]), 7.5, 0.0001)
	assert_almost_eq(float(out[1]["z"]), 10.5, 0.0001)


func test_one_piece_mesh_inside_and_outside_with_the_map_material() -> void:
	var parent: Node3D = autofree(Node3D.new())
	var material := StandardMaterial3D.new()
	var root := TrackView.build(parent, _grid(), material, [Rect2(-60, 1, 60, 3)])
	assert_eq(root.get_child_count(), 2)
	var inside: MultiMeshInstance3D = root.get_node("TrackMap")
	var outside: MultiMeshInstance3D = root.get_node("TrackOutside")
	assert_eq(inside.material_override, material, "seen, remembered and snowed on like the ground")
	assert_eq(inside.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "too low to show a shadow worth its passes")
	assert_eq(outside.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_eq(TrackView.piece().get_faces().size() / 3, 22, "a sleeper box and two rails open at their joined ends")
	assert_eq(inside.multimesh.instance_count, TrackView.spots(TrackView.runs(_grid())).size())
	assert_eq(outside.multimesh.instance_count, TrackView.spots(TrackView.outside_runs([Rect2(-60, 1, 60, 3)], 20.0)).size())
	var box: AABB = TrackView.piece().get_aabb()
	assert_almost_eq(box.end.y, TrackView.RAIL_TOP, 0.0001)
	assert_almost_eq(box.size.z, TrackView.SLEEPER.z, 0.0001)
	assert_almost_eq(box.size.x, TrackView.STEP, 0.0001, "rail ends meet the next piece's")
	assert_eq(TrackView.build(autofree(Node3D.new()), FieldGrid.new(8, 8), material).get_child_count(), 0, "no rails, nothing drawn")


func test_a_crossing_boards_only_the_lines_its_road_crosses() -> void:
	var found := TrackView.runs(_grid())
	# A road over the main line, one over both side-by-side lines running past their east end, one over bare ground.
	var on := TrackView.crossing_runs(found, [Rect2i(5, 0, 3, 5), Rect2i(8, 6, 4, 6), Rect2i(16, 5, 2, 3)])
	assert_eq(on.size(), 3)
	assert_eq(_span(on, 2.5), [5.0, 8.0])
	assert_eq(_span(on, 7.5), [8.0, 10.0], "cut where the rails end")
	assert_eq(_span(on, 10.5), [8.0, 10.0])
	assert_eq(TrackView.crossing_runs(found, []), [], "no crossing in the map, no boards")


func test_boards_lie_between_and_beside_the_rails_just_under_their_tops() -> void:
	var rail_in := TrackView.GAUGE_HALF - TrackView.RAIL.z * 0.5
	var rail_out := TrackView.GAUGE_HALF + TrackView.RAIL.z * 0.5
	for span: Array in TrackView.board_spans():
		var a := absf(float(span[0]))
		var b := absf(float(span[1]))
		var lo := minf(a, b) if signf(float(span[0])) == signf(float(span[1])) else 0.0
		var hi := maxf(a, b)
		assert_true(hi <= rail_in - 0.05 or lo >= rail_out, "no board over a rail or its flangeway: %s" % [span])
	var m := TrackView.crossing_mesh([{"x0": 5.0, "x1": 8.0, "z": 2.5}])
	var box := m.get_aabb()
	assert_almost_eq(box.end.y, TrackView.RAIL_TOP - 0.01, 0.0001, "the rails stand proud of the boards")
	assert_almost_eq(box.position.y, TrackView.SLEEPER_Y + TrackView.SLEEPER.y * 0.5, 0.0001, "laid on the sleepers")
	assert_almost_eq(box.position.x, 5.0, 0.0001)
	assert_almost_eq(box.end.x, 8.0, 0.0001)
	assert_almost_eq(box.get_center().z, 2.5, 0.0001)
	assert_lte(box.size.z, TrackView.SLEEPER.z + 0.2)
	assert_eq(m.get_faces().size() / 3, 9 * 10, "nine boards, a box each without a bottom")
	assert_null(TrackView.crossing_mesh([]))


func test_the_boards_are_one_more_shadowless_mesh_only_where_a_road_crosses() -> void:
	var material := StandardMaterial3D.new()
	var root := TrackView.build(autofree(Node3D.new()), _grid(), material, [], [Rect2i(5, 0, 3, 5)])
	assert_eq(root.get_child_count(), 2)
	var boards: MeshInstance3D = root.get_node("TrackCrossings")
	assert_eq(boards.material_override, material, "seen, remembered and snowed on like the ground")
	assert_eq(boards.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_false(TrackView.build(autofree(Node3D.new()), _grid(), material).has_node("TrackCrossings"), "no crossing, no draw call")
	assert_false(TrackView.build(autofree(Node3D.new()), _grid(), material, [], [Rect2i(16, 5, 2, 3)]).has_node("TrackCrossings"), "a road over bare ground lays nothing")


func test_trains_and_wagons_stand_on_the_rail_tops() -> void:
	var g := _grid()
	assert_almost_eq(TrackView.height_under(g, Rect2i(0, 1, 16, 3)), TrackView.RAIL_TOP, 0.0001)
	assert_eq(TrackView.height_under(g, Rect2i(0, 4, 4, 2)), 0.0, "off the rails stays on the ground")
	assert_eq(TrackView.height_under(g, Rect2i(40, 40, 4, 2)), 0.0)
	var wagons := [{"rect": Rect2i(4, 6, 6, 3), "name": "석탄 화차", "coal": 1.0}, {"rect": Rect2i(14, 4, 6, 2), "name": "빈 화차"}]
	var heights := TrackView.wagon_heights(g, wagons)
	assert_almost_eq(float(heights[0]), TrackView.RAIL_TOP, 0.0001)
	assert_eq(float(heights[1]), 0.0)
	var root := Kit.attach_wagons(autofree(Node3D.new()), wagons, heights)
	for key: String in root._batches:
		var placed: Transform3D = root._batches[key]["transforms"][0]
		var lifted := placed.origin.x < 12.0
		assert_almost_eq(placed.origin.y, TrackView.RAIL_TOP if lifted else 0.0, 0.0001, key)


func test_the_field_lays_its_line_and_stands_the_train_on_it() -> void:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "weather": ["clear"]}
	add_child_autofree(game)
	game.set_process(false)
	var track: Node3D = game.view.level_roots[0].get_node("Track")
	var inside: MultiMeshInstance3D = track.get_node("TrackMap")
	assert_gt(inside.multimesh.instance_count, 100, "the main line through the place")
	assert_true(track.has_node("TrackOutside"), "and on out past the edge")
	assert_almost_eq(game.view.train_node.position.y, TrackView.RAIL_TOP, 0.0001)
	for kind: String in ["car_window", "firebox"]:
		if game.view.light_nodes.has(kind):
			assert_almost_eq(game.view.light_nodes[kind].position.y, TrackView.RAIL_TOP, 0.0001, kind + " stands with the train")
	game.view.slide_train(12.0)
	assert_almost_eq(game.view.train_node.position.y, TrackView.RAIL_TOP, 0.0001, "it rolls along the rails")

func test_outside_runs_take_the_side_not_the_shape() -> void:
	# A band wider than its length still runs east-west past the west or east edge; a north or south band
	# wider than it is deep is still no east-west line (edge_band.gd hands over rectangles without their side).
	var out := TrackView.outside_runs([Rect2(-60, 0, 60, 61), Rect2(100, 5, 60, 61), Rect2(10, -60, 70, 60), Rect2(10, 40, 70, 60)], 100.0)
	assert_eq(out.size(), TrackView.lines(0.0, 61.0).size() * 2, "the west and east bands only")
	for run: Dictionary in out:
		assert_true(float(run["x1"]) <= 0.0 or float(run["x0"]) >= 100.0, "every line lies past the west or east edge")


func test_overlapping_crossings_board_a_line_once() -> void:
	var found := TrackView.runs(_grid())
	var on := TrackView.crossing_runs(found, [Rect2i(5, 0, 3, 5), Rect2i(6, 0, 4, 5), Rect2i(5, 0, 3, 5), Rect2i(12, 0, 2, 5)])
	assert_eq(on.size(), 2, "the three over 5..10 make one stretch, the one at 12 its own")
	assert_eq(_span(on, 2.5), [5.0, 10.0])
	var meeting := TrackView.crossing_runs(found, [Rect2i(5, 0, 3, 5), Rect2i(8, 0, 2, 5)])
	assert_eq(meeting.size(), 1, "crossings that meet end to end are one stretch of boards")


func test_the_map_hands_its_crossings_to_the_track() -> void:
	var data: Dictionary = FieldMaps.build_from(load(FieldMaps.path_of("bare_line_01")))
	var g: FieldGrid = data["grid"]
	var at := Vector2i(-1, -1)
	for y in g.height:
		for x in g.width:
			if at.x < 0 and g.floor_at(Vector2i(x, y)) == F.RAIL:
				at = Vector2i(x, y)
	assert_true(at.x >= 0, "the line map has rails")
	data["rail_crossings"] = [Rect2i(at.x, 0, 2, g.height)]
	var view: Node3D = autofree(MapView.new())
	view.setup(data)
	var track: Node3D = view.level_roots[0].get_node("Track")
	assert_true(track.has_node("TrackCrossings"), "MapView.setup hands data[rail_crossings] on to the boards")
