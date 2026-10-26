extends "res://addons/gut/test.gd"

const EdgeBand = preload("res://game/world/edge_band.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const F = FieldGrid.Floor


## 60 x 40 snow; a rail line along row 20 out of both side edges, a road down
## column 30 out of the north edge.
func _grid() -> FieldGrid:
	var g := FieldGrid.new(60, 40)
	for x in g.width:
		g.floor[g.index(Vector2i(x, 20))] = F.RAIL
	for y in range(0, 20):
		g.floor[g.index(Vector2i(30, y))] = F.ROAD
		g.floor[g.index(Vector2i(31, y))] = F.ROAD
	return g


func test_values_are_fixed() -> void:
	assert_eq(EdgeBand.BAND, 12.0)
	assert_eq(EdgeBand.INNER_ROW, 2.6)
	assert_eq(EdgeBand.INNER_SPACING, 2.0)
	assert_eq(EdgeBand.DEEP_SPACING, 4.0)
	assert_eq(EdgeBand.TRUNK_GAP, 0.3)
	assert_eq(EdgeBand.EDGE_WAVE, 1.2)
	assert_eq(EdgeBand.RAIL_CLEAR, 2.5)
	assert_eq(EdgeBand.ROAD_RUN, 5.0)
	assert_eq(EdgeBand.ROAD_WIDEST, 8)
	assert_eq(EdgeBand.SHADE_DEPTH, 1.2)
	assert_eq(EdgeBand.GLADE_EVERY, 48.0)
	assert_eq(EdgeBand.GLADE_CHANCE, 0.5)
	assert_eq(EdgeBand.GLADE_SIZE, Vector2(4.0, 6.0))
	assert_eq(EdgeBand.GLADE_NEAR, 3.0)


func test_now_and_then_a_glade_with_a_trace_of_people_behind_the_first_rows() -> void:
	# A town-sized map: about a dozen chances round it.
	var g := FieldGrid.new(170, 120)
	for x in g.width:
		g.floor[g.index(Vector2i(x, 60))] = F.RAIL
	var total := 0
	for seed in range(1, 21):
		var plan := EdgeBand.plan(g, seed)
		total += plan["glades"].size()
		for gl: Dictionary in plan["glades"]:
			var r: Rect2 = gl["rect"]
			assert_between(r.size.x, EdgeBand.GLADE_SIZE.x, EdgeBand.GLADE_SIZE.y)
			assert_eq(r.size.x, r.size.y, "square")
			var near := minf(EdgeBand.outside(g, r.position.x, r.position.y), EdgeBand.outside(g, r.end.x, r.end.y))
			assert_almost_eq(near, EdgeBand.GLADE_NEAR, 0.001, "behind the first rows")
			assert_true(EdgeBand.outside(g, r.get_center().x, r.get_center().y) < EdgeBand.BAND - 2.0, "where the camera shows it")
			assert_true(absf(r.get_center().y - 60.5) > EdgeBand.RAIL_CLEAR + r.size.y * 0.5 or (r.position.x >= 0.0 and r.end.x <= g.width), "not on the rail line running out")
			assert_true(["felled", "rest"].has(gl["kind"]))
			for p: Dictionary in gl["props"]:
				var at: Vector3 = p["at"]
				assert_true(r.has_point(Vector2(at.x, at.z)), "the trace stands in its glade")
			for t: Dictionary in plan["trees"]:
				var at: Vector3 = t["at"]
				assert_false(r.has_point(Vector2(at.x, at.z)), "no tree in a glade")
	# 20 maps of about 12 chances at one in two: well over none, well under all.
	assert_between(total, 60, 180)


func test_the_camera_never_looks_past_the_band() -> void:
	var half := EdgeBand.view_half(24.0, 2.0, 52.0)
	assert_almost_eq(half.x, 24.0, 0.0001)
	assert_almost_eq(half.y, 12.0 / sin(deg_to_rad(52.0)), 0.0001)
	var mid := Vector3(80, 0, 60)
	assert_eq(EdgeBand.clamp_focus(mid, half, 170, 120), mid, "inside the map nothing moves")
	var west := EdgeBand.clamp_focus(Vector3(1, 0, 60), half, 170, 120)
	assert_almost_eq(west.x - half.x, -EdgeBand.BAND, 0.0001, "the left of the view stops at the band's far side")
	var far := EdgeBand.view_half(36.0, 2.0, 52.0)
	var south := EdgeBand.clamp_focus(Vector3(80, 0, 119), far, 170, 120)
	assert_almost_eq(south.z + far.y, 120.0 + EdgeBand.BAND, 0.0001, "zoomed out, the bottom of the view stops there too")
	var narrow := EdgeBand.clamp_focus(Vector3(3, 0, 3), Vector2(100, 100), 40, 30)
	assert_eq(narrow, Vector3(20, 0, 15), "a map smaller than the view is centred")


func test_rails_run_out_through_a_clear_corridor_and_roads_end_at_a_block() -> void:
	var g := _grid()
	var runs := EdgeBand.openings(g)
	var rails := runs.filter(func(r): return int(r["floor"]) == F.RAIL)
	var roads := runs.filter(func(r): return int(r["floor"]) == F.ROAD)
	assert_eq(rails.size(), 2, "west and east")
	assert_eq(roads.size(), 1, "north")
	assert_eq(int(roads[0]["side"]), 2)
	assert_eq([int(roads[0]["from"]), int(roads[0]["to"])], [30, 31])
	var plan := EdgeBand.plan(g, 7)
	for t: Dictionary in plan["trees"]:
		var at: Vector3 = t["at"]
		var out := EdgeBand.outside(g, at.x, at.z)
		assert_true(out >= EdgeBand.TRUNK_GAP and out < EdgeBand.BAND, "every tree stands in the band")
		if at.x < 0.0 or at.x > g.width:
			assert_true(absf(at.z - 20.5) > EdgeBand.RAIL_CLEAR, "no tree on the rail line running out")
		if at.z < 0.0 and at.x > 29.4 and at.x < 32.6:
			assert_true(at.z < -EdgeBand.ROAD_RUN - 1.0, "the road runs clear before the woods")
	assert_eq(plan["blocks"].size(), 1, "one block across the two-cell road")
	var block: Vector3 = plan["blocks"][0]["at"]
	assert_almost_eq(block.z, -EdgeBand.ROAD_RUN - 0.6, 0.0001)
	assert_true(block.x >= 30.0 and block.x <= 32.0)


func test_a_road_along_an_edge_is_not_walled_off() -> void:
	var g := _grid()
	for x in range(5, 55):
		g.floor[g.index(Vector2i(x, g.height - 1))] = F.ROAD
	var runs := EdgeBand.openings(g)
	assert_eq(runs.filter(func(r): return int(r["side"]) == 3).size(), 0, "a road beside the south edge leaves nothing open")
	var plan := EdgeBand.plan(g, 7)
	assert_eq(plan["blocks"].size(), 1, "only the road out of the north edge is blocked")
	var south := 0
	for t: Dictionary in plan["trees"]:
		var at: Vector3 = t["at"]
		if at.z > g.height and at.x > 6.0 and at.x < 54.0:
			south += 1
	assert_gt(south, 20, "woods stand past the road along the edge")


func test_the_same_map_draws_the_same_woods() -> void:
	var a := EdgeBand.plan(_grid(), 11)
	var b := EdgeBand.plan(_grid(), 11)
	var c := EdgeBand.plan(_grid(), 12)
	assert_eq(a["trees"].size(), b["trees"].size())
	assert_eq(a["trees"][0]["at"], b["trees"][0]["at"])
	assert_ne(a["trees"][0]["at"], c["trees"][0]["at"], "another place, other woods")
	# 60 x 40 map: the ring is about (84 x 64 - 60 x 40) square metres.
	var n: int = a["trees"].size()
	assert_between(n, 150, 700)


func test_the_band_is_built_under_the_ground_level() -> void:
	var g := _grid()
	var root := Node3D.new()
	add_child_autofree(root)
	var counts := EdgeBand.build(root, g, {"place_id": "test"}, StandardMaterial3D.new(), [Color.WHITE, Color.GRAY, Color.GRAY, Color.GRAY, Color.DIM_GRAY, Color.WHITE, Color.WHITE, Color.GRAY])
	var band := root.get_node("EdgeBand")
	assert_not_null(band)
	assert_not_null(band.get_node("Runs"), "the road and rail runs out of the map")
	assert_eq(int(counts["blocks"]), 1)
	var plan := EdgeBand.plan(g, EdgeBand.seed_of({"place_id": "test"}))
	assert_eq(int(counts["glades"]), plan["glades"].size())
	assert_eq(band.get_child_count(), 1 + int(counts["chunks"]) + 1 + int(counts["traces"]), "runs, tree pieces, the road's block and the glades' traces")
	assert_gt(int(counts["trees"]), 0)
	assert_gt(int(counts["chunks"]), 4, "the woods are cut in pieces so those off screen are not drawn")
