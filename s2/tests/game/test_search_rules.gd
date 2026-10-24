extends "res://addons/gut/test.gd"

const R = preload("res://game/sim/search_rules.gd")
const FieldGame = preload("res://game/field_game.gd")


func test_search_skill_changes_container_time_without_a_second_hand_multiplier() -> void:
	assert_almost_eq(R.seconds(7.0, 0), 7.0, 0.0001)
	assert_almost_eq(R.seconds(7.0, 3), 7.0 / 1.45, 0.0001)
	assert_almost_eq(R.seconds(2.0, -1), 2.0, 0.0001)


func test_reserved_locked_and_finished_containers_cannot_start_again() -> void:
	assert_false(R.can_search({}))
	assert_true(R.can_search({"locked": false, "searched": false}))
	for key in ["busy", "locked", "searched"]:
		var container := {"locked": false, "searched": false}
		container[key] = true
		assert_false(R.can_search(container), key)


func test_only_unlocked_completed_contents_can_be_taken() -> void:
	assert_false(R.can_take({"searched": false}))
	assert_false(R.can_take({"searched": true, "locked": true}))
	assert_false(R.can_take({"searched": true, "busy": true}))
	assert_true(R.can_take({"searched": true, "items": ["cloth"]}))


func test_cancelled_timed_callback_and_existing_completion_notification_stay_distinct() -> void:
	var game = FieldGame.new()
	game.opts = {"seed": 1, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	var id: String = game.data["containers"].keys()[0]
	var container: Dictionary = game.data["containers"][id]
	container["locked"] = false
	container["searched"] = false
	var p = game.player
	p.position = game.lift(container["cell"], int(container.get("level", 0)))
	game.actions.search(p, id)
	var callback: Callable = p.action_done
	p.cancel_action()
	callback.call()
	assert_false(container["searched"], "an abandoned timed operation does not grant contents")
	game.actions._searched(p, id)
	assert_true(container["searched"], "existing completion notifications still work")
