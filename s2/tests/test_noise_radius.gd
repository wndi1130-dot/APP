extends "res://addons/gut/test.gd"

const NoiseRadius = preload("res://scripts/noise_radius.gd")

func test_radius_includes_boundary_and_excludes_outside() -> void:
	assert_true(NoiseRadius.contains(Vector2(3, 4), Vector2.ZERO, 5.0))
	assert_false(NoiseRadius.contains(Vector2(3.01, 4), Vector2.ZERO, 5.0))
	assert_true(NoiseRadius.contains(Vector2.ZERO, Vector2.ZERO, 0.0))
	assert_false(NoiseRadius.contains(Vector2.ZERO, Vector2.ZERO, -1.0))

func test_offset_origin_and_affected_indices() -> void:
	var points := PackedVector2Array([Vector2(10, 10), Vector2(13, 14), Vector2(20, 20)])
	assert_eq(NoiseRadius.affected(points, Vector2(10, 10), 5.0), PackedInt32Array([0, 1]))
