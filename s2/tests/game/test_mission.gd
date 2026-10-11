extends "res://addons/gut/test.gd"
## What a stop is for (content_variety_first_build 2부): the kind comes in by
## opts["mission"], and a stop with no kind writes what it always wrote.

const FieldGame = preload("res://game/field_game.gd")


func _run(extra: Dictionary) -> Dictionary:
	var game = FieldGame.new()
	var opts := {"seed": 5, "raiders": false, "auto_pause": false}
	opts.merge(extra)
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	var out := {"mission": game.mission}
	game.finish("departed")
	out["receipt"] = game.receipt.to_dict()
	out["telemetry"] = game.telemetry.to_dict()
	return out


func test_a_stop_with_no_kind_writes_what_it_always_wrote() -> void:
	var plain := _run({})
	var empty := _run({"mission": ""})
	assert_eq(plain["mission"], "")
	assert_eq(JSON.stringify(empty["receipt"]), JSON.stringify(plain["receipt"]))
	assert_eq(JSON.stringify(empty["telemetry"]), JSON.stringify(plain["telemetry"]))
	assert_false((plain["receipt"]["placeState"] as Dictionary).has("mission"))
	assert_false((plain["telemetry"] as Dictionary).has("mission"))


func test_the_kind_goes_on_the_receipt_and_the_run_log() -> void:
	for kind in ["survey", "depot"]:
		var run := _run({"mission": kind})
		assert_eq(run["mission"], kind)
		assert_eq(run["receipt"]["placeState"]["mission"], kind)
		assert_eq(run["telemetry"]["mission"], kind)


func test_a_kind_nobody_knows_is_the_plain_stop() -> void:
	var run := _run({"mission": "picnic"})
	assert_eq(run["mission"], "")
	assert_false((run["telemetry"] as Dictionary).has("mission"))
