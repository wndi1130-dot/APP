extends "res://addons/gut/test.gd"
## Pure geometry/decision boundaries. Missing DoorWalk is an expected pre-fix failure.

const DoorWalk = preload("res://game/sim/door_walk.gd")


func test_start_distance_includes_the_exact_boundary_but_not_the_next_point() -> void:
	assert_true(DoorWalk.should_start(1.05, 2.1, 0.5))
	assert_false(DoorWalk.should_start(1.0501, 2.1, 0.5))
	assert_true(DoorWalk.should_start(1.95, 3.9, 0.5))
	assert_false(DoorWalk.should_start(1.9501, 3.9, 0.5))
	assert_true(DoorWalk.should_start(0.0, 2.1, 0.5))
	assert_false(DoorWalk.should_start(0.0, 0.0, 0.5))
	assert_false(DoorWalk.should_start(1.0, -1.0, 0.5))
	assert_false(DoorWalk.should_start(NAN, 2.1, 0.5))
	assert_false(DoorWalk.should_start(1.0, INF, 0.5))
	assert_false(DoorWalk.should_start(1.0, 2.1, -0.5))


func test_distance_follows_the_bend_and_never_uses_the_straight_line_shortcut() -> void:
	var doors := {Vector2i(2, 2): {"state": "closed"}}
	var path := PackedVector3Array([Vector3(0.5, 0, 2.5), Vector3(2.5, 0, 2.5)])
	var hit: Dictionary = DoorWalk.first_door(Vector3(0.5, 0, 0.5), path, doors, 10.0)
	assert_almost_eq(float(hit["distance"]), 3.5, 0.00001)
	assert_false(DoorWalk.should_start(float(hit["distance"]), 3.9, 0.5))
	assert_true(DoorWalk.first_door(Vector3(0.5, 0, 0.5), path, doors, 3.49).is_empty())


func test_a_turn_away_or_a_door_on_another_floor_is_not_a_candidate() -> void:
	var doors := {Vector2i(2, 0): {"state": "closed"}}
	var turned := PackedVector3Array([Vector3(1.5, 0, 2.5)])
	assert_true(DoorWalk.first_door(Vector3(1.5, 0, 0.5), turned, doors, 4.0).is_empty())
	var stairs := PackedVector3Array([Vector3(1.5, 3, 0.5), Vector3(2.5, 3, 0.5)])
	assert_true(DoorWalk.first_door(Vector3(1.5, 0, 0.5), stairs, doors, 4.0).is_empty())


func test_adjacent_doors_are_found_in_path_order_even_in_reverse_dictionary_order() -> void:
	var near := Vector2i(2, 0)
	var far := Vector2i(3, 0)
	var doors := {far: {"state": "closed"}, near: {"state": "closed"}}
	var path := PackedVector3Array([Vector3(6.5, 0, 0.5)])
	var hit: Dictionary = DoorWalk.first_door(Vector3(0.5, 0, 0.5), path, doors, 8.0)
	assert_eq(hit["cell"], near)
	assert_almost_eq(float(hit["distance"]), 1.5, 0.00001)
	doors[near]["state"] = "open"
	hit = DoorWalk.first_door(Vector3(0.5, 0, 0.5), path, doors, 8.0)
	assert_eq(hit["cell"], far)
	assert_almost_eq(float(hit["distance"]), 2.5, 0.00001)


func test_swept_segment_finds_a_closed_cell_even_when_the_endpoint_is_beyond_it() -> void:
	var doors := {Vector2i(2, 0): {"state": "closed"}}
	var hit: Dictionary = DoorWalk.first_door(Vector3(0.5, 0, 0.5),
		PackedVector3Array([Vector3(6.5, 0, 0.5)]), doors, 6.0)
	assert_almost_eq(float(hit["distance"]), 1.5, 0.00001)
	assert_lt(DoorWalk.before_threshold(6.0, float(hit["distance"])), 1.5)
	assert_eq(DoorWalk.before_threshold(0.2, 1.5), 0.2)
	assert_eq(DoorWalk.before_threshold(1.0, 0.0), 0.0)


func test_reverse_and_diagonal_approaches_stop_outside_the_cell() -> void:
	var doors := {Vector2i(2, 2): {"state": "closed"}}
	var west: Dictionary = DoorWalk.first_door(Vector3(4.5, 0, 2.5),
		PackedVector3Array([Vector3(1.5, 0, 2.5)]), doors, 4.0)
	assert_almost_eq(float(west["distance"]), 1.5, 0.00001)
	var exact_west: Dictionary = DoorWalk.first_door(Vector3(4.5, 0, 2.5),
		PackedVector3Array([Vector3(3.0, 0, 2.5)]), doors, 1.5)
	assert_almost_eq(float(exact_west["distance"]), 1.5, 0.00001,
		"the far cell edge is included even when the step ends exactly there")
	var diagonal: Dictionary = DoorWalk.first_door(Vector3(0.5, 0, 0.5),
		PackedVector3Array([Vector3(3.5, 0, 3.5)]), doors, 5.0)
	assert_almost_eq(float(diagonal["distance"]), sqrt(4.5), 0.00001)


func test_empty_stationary_and_invalid_paths_have_no_candidate() -> void:
	var at := Vector3(0.5, 0, 0.5)
	var doors := {Vector2i(2, 0): {"state": "closed"}}
	assert_true(DoorWalk.first_door(at, PackedVector3Array(), doors, 4.0).is_empty())
	assert_true(DoorWalk.first_door(at, PackedVector3Array([at]), doors, 4.0).is_empty())
	assert_true(DoorWalk.first_door(at, PackedVector3Array([Vector3(5, 0, 0.5)]), doors, 0.0).is_empty())
	assert_true(DoorWalk.first_door(at, PackedVector3Array([Vector3(NAN, 0, 0.5)]), doors, 4.0).is_empty())


func test_clock_roundoff_cannot_add_a_frame_at_thirty_or_sixty_hz() -> void:
	for hz: int in [30, 60]:
		var left := 0.5
		var delta: float = 1.0 / float(hz)
		var frames: int = int(float(hz) * 0.5)
		for tick: int in frames:
			var done: bool = DoorWalk.finishes(left, delta, 1.0)
			assert_eq(done, tick == frames - 1)
			left = 0.0 if done else left - delta
		assert_eq(left, 0.0)
	assert_false(DoorWalk.finishes(0.5, 0.5 - 0.00000001, 1.0))
	assert_true(DoorWalk.finishes(0.5, 0.5, 1.0))
	assert_false(DoorWalk.finishes(0.5, 0.0, 1.0))
	assert_false(DoorWalk.finishes(0.5, 1.0, 0.0))
