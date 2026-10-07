extends "res://addons/gut/test.gd"

const Visibility = preload("res://scripts/grid_visibility.gd")

func test_open_grid_and_radius_boundary() -> void:
	var visible := Visibility.compute(9, 9, Vector2i(4, 4), 2, {})
	assert_true(visible.has(Vector2i(4, 4)))
	assert_true(visible.has(Vector2i(6, 4)))
	assert_false(visible.has(Vector2i(6, 6)))
	assert_eq(visible.size(), 13)

func test_wall_visible_but_cell_behind_hidden() -> void:
	var visible := Visibility.compute(8, 5, Vector2i(1, 2), 7, {Vector2i(3, 2): true})
	assert_true(visible.has(Vector2i(3, 2)))
	assert_false(visible.has(Vector2i(4, 2)))
	assert_true(visible.has(Vector2i(2, 3)))

func test_door_opens_line_of_sight() -> void:
	var walls: Dictionary = {}
	for y in range(5):
		walls[Vector2i(3, y)] = true
	assert_false(Visibility.compute(8, 5, Vector2i(1, 2), 7, walls).has(Vector2i(5, 2)))
	walls.erase(Vector2i(3, 2))
	assert_true(Visibility.compute(8, 5, Vector2i(1, 2), 7, walls).has(Vector2i(5, 2)))

func test_bounds_and_invalid_origin() -> void:
	var visible := Visibility.compute(3, 3, Vector2i.ZERO, 8, {})
	assert_eq(visible.size(), 9)
	assert_false(visible.has(Vector2i(-1, 0)))
	assert_eq(Visibility.compute(3, 3, Vector2i(-1, 0), 8, {}).size(), 0)

func test_closed_diagonal_corner_does_not_leak() -> void:
	var walls := {Vector2i(2, 1): true, Vector2i(1, 2): true}
	var visible := Visibility.compute(5, 5, Vector2i(1, 1), 4, walls)
	assert_false(visible.has(Vector2i(2, 2)))
	assert_true(visible.has(Vector2i(2, 1)))
