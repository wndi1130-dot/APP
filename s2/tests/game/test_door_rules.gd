extends "res://addons/gut/test.gd"

const R = preload("res://game/sim/door_rules.gd")


func test_lock_needs_forcing_and_a_broken_door_never_reappears() -> void:
	assert_false(R.can_toggle({"state": "locked"}, "open"))
	assert_true(R.can_toggle({"state": "locked"}, "open", true))
	for target in ["open", "closed"]:
		assert_false(R.can_toggle({"state": "broken"}, target, true))
	assert_false(R.can_force({"state": "broken"}))


func test_toggle_requires_an_actual_change_and_kicking_an_open_door_is_rejected() -> void:
	assert_true(R.can_toggle({"state": "closed"}, "open"))
	assert_true(R.can_toggle({"state": "open"}, "closed"))
	assert_false(R.can_toggle({"state": "open"}, "open"))
	assert_false(R.can_toggle({"state": "closed"}, "closed"))
	assert_false(R.can_force({"state": "open"}))
	assert_false(R.can_force({}))
