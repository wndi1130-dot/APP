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
	assert_eq(EdgeBand.BAND, 16.0)
	assert_eq(EdgeBand.INNER_ROW, 2.6)
	assert_eq(EdgeBand.INNER_SPACING, 2.0)
	assert_eq(EdgeBand.DEEP_SPACING, 3.4)
	assert_eq(EdgeBand.TRUNK_GAP, 0.3)
	assert_eq(EdgeBand.EDGE_WAVE, 1.2)
	assert_eq(EdgeBand.RAIL_CLEAR, 2.5)
	assert_eq(EdgeBand.ROAD_RUN, 5.0)
	assert_eq(EdgeBand.SHADE_DEPTH, 3.5)


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


func test_the_same_map_draws_the_same_woods() -> void:
	var a := EdgeBand.plan(_grid(), 11)
	var b := EdgeBand.plan(_grid(), 11)
	var c := EdgeBand.plan(_grid(), 12)
	assert_eq(a["trees"].size(), b["trees"].size())
	assert_eq(a["trees"][0]["at"], b["trees"][0]["at"])
	assert_ne(a["trees"][0]["at"], c["trees"][0]["at"], "another place, other woods")
	# 60 x 40 map: the ring is about (92 x 72 - 60 x 40) square metres.
	var n: int = a["trees"].size()
	assert_between(n, 200, 900)


func test_the_band_is_built_under_the_ground_level() -> void:
	var g := _grid()
	var root := Node3D.new()
	add_child_autofree(root)
	var counts := EdgeBand.build(root, g, {"place_id": "test"}, StandardMaterial3D.new(), [Color.WHITE, Color.GRAY, Color.GRAY, Color.GRAY, Color.DIM_GRAY, Color.WHITE, Color.WHITE, Color.GRAY])
	var band := root.get_node("EdgeBand")
	assert_not_null(band)
	assert_not_null(band.get_node("Ground"))
	assert_eq(int(counts["blocks"]), 1)
	assert_gt(int(counts["trees"]), 0)
	assert_gt(int(counts["chunks"]), 4, "the woods are cut in pieces so those off screen are not drawn")
