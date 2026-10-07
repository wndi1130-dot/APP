extends "res://addons/gut/test.gd"

const Flow = preload("res://scripts/scene_flow.gd")

func test_full_order_and_duplicate_rejection() -> void:
	var flow := Flow.new()
	assert_eq(flow.stage, Flow.Stage.HOME)
	assert_false(flow.advance(Flow.Stage.STATION))
	assert_true(flow.advance(Flow.Stage.BRAKING))
	assert_false(flow.advance(Flow.Stage.BRAKING))
	assert_true(flow.advance(Flow.Stage.LOADING))
	assert_true(flow.advance(Flow.Stage.STATION))
	assert_true(flow.advance(Flow.Stage.FIELD))
	assert_false(flow.advance(Flow.Stage.HOME))
	assert_false(flow.advance(Flow.Stage.FIELD + 1))

func test_reset_starts_a_new_measurement_flow() -> void:
	var flow := Flow.new()
	assert_true(flow.advance(Flow.Stage.BRAKING))
	flow.reset()
	assert_eq(flow.stage, Flow.Stage.HOME)
	assert_true(flow.advance(Flow.Stage.BRAKING))
