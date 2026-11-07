extends "res://addons/gut/test.gd"
## The ground shots tool's pure parts (tools/ground_shots.gd): what is measured
## for each thing on the ground and what is left out, without a window. The
## captures themselves run only in a rendering window (godot_gate, by hand).

const Shots = preload("res://tools/ground_shots.gd")


func test_a_hull_keeps_the_outer_points_in_turn() -> void:
	var points: Array[Vector2] = [Vector2(0, 0), Vector2(4, 0), Vector2(4, 4), Vector2(0, 4), Vector2(2, 2), Vector2(4, 0)]
	var hull: PackedVector2Array = Shots.convex_hull(points)
	assert_eq(hull.size(), 4, "the inner point and the repeated corner go")
	assert_almost_eq(Shots.polygon_area(hull), 16.0, 0.0001)
	var line: Array[Vector2] = [Vector2(0, 0), Vector2(1, 1), Vector2(2, 2)]
	assert_true(Shots.convex_hull(line).is_empty(), "points on one line make no area")
	var bad: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(NAN, 1)]
	assert_true(Shots.convex_hull(bad).is_empty(), "a broken point makes no hull")


func test_a_widened_hull_grows_by_the_padding_on_every_side() -> void:
	var square := PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4, 4), Vector2(0, 4)])
	var grown: PackedVector2Array = Shots.expand_hull(square, 1.0)
	assert_almost_eq(Shots.polygon_area(grown), 36.0, 0.0001, "4 + 1 + 1 each way")
	assert_true(Shots.expand_hull(PackedVector2Array([Vector2.ZERO, Vector2.ONE]), 1.0).is_empty())
	assert_true(Shots.expand_hull(square, -1.0).is_empty(), "no shrinking")


func test_pixels_two_things_share_are_counted_for_neither() -> void:
	var left := PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4, 4), Vector2(0, 4)])
	var right := PackedVector2Array([Vector2(2, 0), Vector2(6, 0), Vector2(6, 4), Vector2(2, 4)])
	var masks: Array[Dictionary] = Shots.exclusive_pixels([left, right], Vector2i(10, 10))
	assert_eq(masks[0]["polygon_pixels"], 16)
	assert_eq(masks[0]["shared_pixels"], 8, "the two middle columns are both's")
	assert_eq((masks[0]["pixels"] as Array).size(), 8)
	assert_eq((masks[1]["pixels"] as Array).size(), 8)
	var empty: Array[Dictionary] = Shots.exclusive_pixels([PackedVector2Array()], Vector2i(10, 10))
	assert_eq(empty[0]["polygon_pixels"], 0, "an undrawn row has no pixels")


func test_a_cell_is_used_only_when_its_plate_is_seen_whole_enough() -> void:
	assert_true(Shots.probe_visibility(96, 100)["visible"])
	assert_false(Shots.probe_visibility(94, 100)["visible"], "under PROBE_VISIBLE")
	assert_false(Shots.probe_visibility(0, 0)["visible"], "no reference pixels")
	assert_eq(Shots.probe_visibility(0, 0)["reason"], "no_reference_pixels")
	assert_false(Shots.probe_visibility(-1, 100)["visible"])


func test_low_visibility_is_marked_not_left_out() -> void:
	var low: Dictionary = Shots.visibility(Shots.MIN_VISIBLE_PIXELS - 1, 120.0, 3)
	assert_true(low["low_visibility"])
	assert_eq(low["low_visibility_reason"]["shared_pixels"], 3)
	assert_false(Shots.visibility(Shots.MIN_VISIBLE_PIXELS, 120.0, 0)["low_visibility"])
	assert_false(Shots.visibility(0, 0.0, 0, false)["low_visibility"], "an undrawn row is not a low one")
	var rows: Array = [
		{"id": "knife", "mean_abs_luma": 0.0, "object_luma": 0.2, "changed_pixels": 0, "drawn": true, "low_visibility": true},
		{"id": "coat_long", "mean_abs_luma": 0.2, "object_luma": 0.3, "changed_pixels": 400, "drawn": true, "low_visibility": false},
		{"id": "oats", "mean_abs_luma": 0.0, "object_luma": 0.0, "changed_pixels": 0, "drawn": false},
	]
	var summary: Dictionary = Shots.summarize(rows)
	assert_eq(summary["weakest"]["id"], "knife", "a thing hardly seen stays the weakest, not dropped")
	assert_eq(summary["low_visibility_count"], 1)
	assert_eq(summary["drawn_count"], 2)
	assert_eq((summary["not_drawn"] as Array).size(), 1)


## Each row must add exactly what it draws alone; a row that pushes another off
## (or is itself left undrawn) stops the measuring instead of mixing two things.
func test_rows_must_add_what_they_draw_alone() -> void:
	var alone: Array = [{0: Vector2i(36, 6)}, {0: Vector2i(48, 6)}]
	assert_true(Shots.row_counts_consistent(alone, [{0: Vector2i(36, 6)}, {0: Vector2i(48, 6)}])["ok"])
	var displaced: Dictionary = Shots.row_counts_consistent(alone, [{0: Vector2i(36, 6)}, {0: Vector2i(12, 0)}])
	assert_false(displaced["ok"])
	assert_eq(displaced["row"], 1)
	assert_eq(displaced["alone"], Vector2i(48, 6))
	var same_size: Array = [{0: Vector2i(36, 6)}, {0: Vector2i(36, 6)}]
	var pushed_off: Dictionary = Shots.row_counts_consistent(same_size, [{0: Vector2i(36, 6)}, {0: Vector2i.ZERO}])
	assert_false(pushed_off["ok"], "the second drawn in place of the first: same total, still caught")
	assert_true(Shots.row_counts_consistent([{}], [{0: Vector2i.ZERO}])["ok"], "an absent level counts as zero")
	assert_false(Shots.row_counts_consistent(alone, [{0: Vector2i(36, 6)}])["ok"], "a missing row")
