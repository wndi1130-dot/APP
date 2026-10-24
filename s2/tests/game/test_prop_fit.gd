extends "res://addons/gut/test.gd"

const PropFit = preload("res://game/world/prop_fit.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const MapView = preload("res://game/world/map_view.gd")
const PropModels = preload("res://game/world/prop_models.gd")
const HousesMap = preload("res://game/world/maps/houses_04.gd")

## 3 m 선반 꼴(가로 3, 깊이 1)과 깊이가 1.52 m인 옷장 꼴.
const SHELF_LO := Vector3(-1.5, 0, -0.5)
const SHELF_HI := Vector3(1.5, 1.8, 0.5)
const DEEP_LO := Vector3(-0.647, 0, -0.76)
const DEEP_HI := Vector3(0.647, 2.0, 0.76)


func test_map_facing_stays_when_the_model_fits() -> void:
	var fit := PropFit.fit(SHELF_LO, SHELF_HI, Rect2i(0, 0, 3, 1), 2)
	assert_eq(fit["facing"], 2)
	assert_eq(fit["scale"], Vector3.ONE)
	assert_false(fit["turned"])
	assert_false(fit["shrunk"])


func test_long_model_turns_to_the_rect_long_axis_without_shrinking() -> void:
	for facing in [1, 3]:
		var fit := PropFit.fit(SHELF_LO, SHELF_HI, Rect2i(0, 0, 3, 1), facing)
		assert_true(fit["turned"])
		assert_true(int(fit["facing"]) % 2 == 0, "along x")
		assert_eq(fit["scale"], Vector3.ONE, "turning is enough, no 1 m stub")
	var upright := PropFit.fit(SHELF_LO, SHELF_HI, Rect2i(0, 0, 1, 3), 0)
	assert_true(int(upright["facing"]) % 2 == 1, "a tall rect turns the shelf along z")
	assert_eq(upright["scale"], Vector3.ONE)


func test_a_turned_model_puts_its_back_to_the_wall() -> void:
	var g := FieldGrid.new(10, 10)
	for x in range(2, 5):
		g.set_solid(Vector2i(x, 2), FieldGrid.Solid.WALL)
	var north_wall := PropFit.fit(SHELF_LO, SHELF_HI, Rect2i(2, 3, 3, 1), 1, g)
	assert_eq(north_wall["facing"], 0, "wall to the north: front looks south (+z)")
	var h := FieldGrid.new(10, 10)
	for x in range(2, 5):
		h.set_solid(Vector2i(x, 4), FieldGrid.Solid.WALL)
	var south_wall := PropFit.fit(SHELF_LO, SHELF_HI, Rect2i(2, 3, 3, 1), 3, h)
	assert_eq(south_wall["facing"], 2, "wall to the south: front looks north (-z)")


func test_small_overflow_shrinks_only_that_axis_and_keeps_height() -> void:
	var fit := PropFit.fit(DEEP_LO, DEEP_HI, Rect2i(0, 0, 2, 1), 0)
	assert_false(fit["turned"])
	assert_true(fit["shrunk"])
	var s: Vector3 = fit["scale"]
	assert_eq(s.x, 1.0)
	assert_eq(s.y, 1.0, "height stays")
	assert_almost_eq(s.z, 0.5 / 0.76, 0.001)
	var fp := PropFit.footprint(DEEP_LO * s, DEEP_HI * s, 0)
	assert_lte(fp[1].y, 0.5 + 0.001)


func test_shrinking_stops_at_a_third() -> void:
	var fit := PropFit.fit(SHELF_LO, SHELF_HI, Rect2i(0, 0, 1, 1), 0)
	assert_almost_eq(fit["scale"].x, PropFit.MIN_SCALE, 0.0001)
	assert_eq(fit["scale"].z, 1.0)


func test_a_square_rect_keeps_the_map_facing() -> void:
	var fit := PropFit.fit(Vector3(-1, 0, -0.5), Vector3(1, 1, 0.5), Rect2i(0, 0, 2, 2), 1)
	assert_eq(fit["facing"], 1)
	assert_false(fit["turned"])
	assert_eq(fit["scale"], Vector3.ONE)


func test_the_field_draws_every_model_inside_its_rect() -> void:
	var data: Dictionary = HousesMap.build()
	var view := MapView.new()
	add_child_autofree(view)
	view.setup(data)
	assert_gt(int(view.prop_fit_counts["turned"]), 0, "this map had shelves turned across their rects")
	var checked := 0
	for path: String in view.prop_batches:
		var box: AABB = PropModels.batch_meshes(path)[0].get_aabb()
		for item: Dictionary in view.prop_batches[path]["items"]:
			var xf: Transform3D = item["xf"]
			var r: Rect2i = item["rect"]
			var mn := Vector2(INF, INF)
			var mx := Vector2(-INF, -INF)
			for x in [box.position.x, box.end.x]:
				for z in [box.position.z, box.end.z]:
					var v := xf.basis * Vector3(x, 0, z)
					mn = Vector2(minf(mn.x, v.x), minf(mn.y, v.z))
					mx = Vector2(maxf(mx.x, v.x), maxf(mx.y, v.z))
			var sx := xf.basis.x.length()
			var sz := xf.basis.z.length()
			var room_x := r.size.x * 0.5 + maxf(PropFit.TOL_MIN, r.size.x * PropFit.TOL_RATIO) + 0.001
			var room_z := r.size.y * 0.5 + maxf(PropFit.TOL_MIN, r.size.y * PropFit.TOL_RATIO) + 0.001
			var at_min := minf(sx, sz) <= PropFit.MIN_SCALE + 0.001
			if not at_min:
				assert_lte(maxf(-mn.x, mx.x), room_x, "%s x" % path.get_file())
				assert_lte(maxf(-mn.y, mx.y), room_z, "%s z" % path.get_file())
			assert_almost_eq(xf.basis.y.length(), 1.0, 0.001, "height stays")
			checked += 1
	assert_gt(checked, 100)
