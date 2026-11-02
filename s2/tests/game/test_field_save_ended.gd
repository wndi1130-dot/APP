extends GutTest
## Ended saves keep the receipt and ownership without walking the field.

const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const SliceSave = preload("res://game/sim/slice_save.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")
const KEYS := ["version", "kind", "phase", "receipt_id", "receipt_state", "place",
	"departure", "seed", "stop_id", "start_opts", "clock", "coal"]

static var DIR: String = "user://test_field_save_ended_%d" % OS.get_process_id()
static var AT: String = DIR + "/field_save.json"


func before_each() -> void:
	FieldSave._test_fail_step = ""
	DirAccess.make_dir_recursive_absolute(DIR)
	FieldSave.clear(AT)


func after_each() -> void:
	FieldSave._test_fail_step = ""
	FieldSave.clear(AT)


func after_all() -> void:
	DirAccess.remove_absolute(DIR)


func _game(extra: Dictionary = {}):
	var game = FieldGame.new()
	var opts := {"seed": 4, "auto_pause": false}
	opts.merge(extra, true)
	game.opts = opts
	game.map_script = BareLine
	add_child_autofree(game)
	game.set_process(false)
	return game


func _assert_small(saved: Dictionary) -> void:
	var expected: Array = KEYS.duplicate()
	var actual: Array = saved.keys()
	expected.sort()
	actual.sort()
	assert_eq(actual, expected, "only the ended envelope, receipt and ownership remain")
	assert_eq(saved.get("phase"), "ended")
	assert_false(saved.has("runtime"))
	assert_false(saved.has("people"))


func test_ended_capture_keeps_exactly_the_small_fields() -> void:
	var game = _game({"slice": true, "slice_run": "run_ended", "visit_id": "visit_ended",
		"receipt_id": "ret_ended", "stop_id": "stop_ended"})
	game.clock.elapsed = 42.5
	game.clock.speed = 2.0
	game.actions.coal_delivered = 3.5
	game.actions.coal_spent = 1.25
	var running: Dictionary = FieldSave.capture(game)
	game.ended = true
	var saved: Dictionary = FieldSave.capture(game)
	_assert_small(saved)
	for key in KEYS:
		if key not in ["phase", "start_opts"]:
			assert_eq(saved.get(key), running[key], "unchanged value: " + key)
	assert_eq(saved.get("start_opts"), {"slice": true, "slice_run": "run_ended", "visit_id": "visit_ended"})


func test_ended_capture_never_reads_field_collections_or_runtime() -> void:
	# No people, zombies, containers, levels, byte arrays or runtime components exist here.
	var game := {"ended": true, "receipt": null, "place": "bare",
		"opts": {"receipt_id": "ret_minimal", "stop_id": "stop_minimal"},
		"rng": {"seed": 4}, "clock": {"elapsed": 12.5, "speed": 1.0}, "actions": null}
	var saved: Dictionary = FieldSave.capture(game)
	_assert_small(saved)
	assert_eq(saved.get("receipt_id"), "ret_minimal")
	assert_eq(saved.get("stop_id"), "stop_minimal")
	assert_eq(saved.get("start_opts"), {}, "absent ownership options are not invented")
	assert_eq(saved.get("receipt_state"), {})
	assert_eq(saved.get("departure"), {})
	assert_eq(saved.get("coal"), {"delivered": 0, "spent": 0})


func test_ended_save_carries_the_field_save_version_not_the_train_save_version() -> void:
	# field_save.gd VERSION numbers this field save only; politics/save_slot.gd SAVE_VERSION is the train's.
	var game := {"ended": true, "receipt": null, "place": "bare", "opts": {},
		"rng": {"seed": 4}, "clock": {"elapsed": 0.0, "speed": 1.0}, "actions": null}
	var saved: Dictionary = FieldSave.capture(game)
	assert_eq(saved.get("version"), FieldSave.VERSION, "the field save's own format number")
	assert_eq(saved.get("kind"), FieldSave.KIND)


func test_ended_save_passes_whole_and_write_read_round_trip() -> void:
	var order: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/game/fixtures/field_v4/departure_skip_kept.json"))
	var game = _game({"departure": order, "receipt_id": "ret_ended"})
	game.receipt.set_end("departed")
	game.ended = true
	var saved: Dictionary = FieldSave.capture(game)
	assert_true(FieldSave._whole(saved))
	assert_false(FieldSave.exact(saved), "an ended save has no runtime to restore")
	assert_true(FieldSave.write(saved, AT))
	var back: Dictionary = FieldSave.read(AT)
	_assert_small(back)
	assert_eq(back, saved)
	assert_eq(SliceSave.receipt_of_field(back), game.receipt.to_dict(), "the whole receipt is recoverable")


func test_ended_capture_deep_copies_departure_and_receipt_state() -> void:
	var game = _game()
	game.opts["departure"] = {"stopId": "stop_copy", "nested": {"rows": [{"n": 2}]}}
	game.receipt._place_extra["ended_probe"] = {"rows": [{"n": 3}]}
	game.ended = true
	var departure: Dictionary = game.opts["departure"].duplicate(true)
	var receipt: Dictionary = FieldSave._receipt_state(game.receipt)
	var saved: Dictionary = FieldSave.capture(game)
	game.opts["departure"]["nested"]["rows"][0]["n"] = 20
	game.receipt._place_extra["ended_probe"]["rows"][0]["n"] = 30
	assert_eq(saved["departure"], departure)
	assert_eq(saved["receipt_state"], receipt)


func test_ended_interrupt_writes_the_same_small_save() -> void:
	var game = _game({"field_save": true, "field_save_path": AT,
		"slice": true, "slice_run": "run_interrupt", "visit_id": "visit_interrupt"})
	game.receipt.set_end("departed")
	game.ended = true
	var expected: Dictionary = FieldSave.capture(game)
	game.interrupt()
	var saved: Dictionary = FieldSave.read(AT)
	_assert_small(saved)
	assert_eq(saved, expected)


func test_apply_and_resume_opts_reject_small_and_full_ended_saves() -> void:
	var game = _game()
	var full: Dictionary = FieldSave.capture(game)
	full["phase"] = "ended"
	full["clock"]["elapsed"] = 999.0
	game.ended = true
	var small: Dictionary = FieldSave.capture(game)
	small["clock"]["elapsed"] = 999.0
	game.ended = false
	var before: Dictionary = FieldSave.capture(game)
	for saved in [small, full]:
		assert_eq(FieldSave.resume_opts(saved), {}, "an ended save cannot start a field")
		FieldSave.apply(game, saved)
		assert_eq(FieldSave.capture(game), before, "reject before changing any simulation state")


func test_running_capture_keeps_people_and_runtime() -> void:
	var game = _game()
	var saved: Dictionary = FieldSave.capture(game)
	assert_eq(saved["phase"], "field")
	assert_true(saved.has("runtime"))
	assert_true(saved.has("people"))
	assert_eq(saved["people"].size(), game.people.size())
	assert_eq(saved["people"][0]["pos"], game.people[0].position)
	assert_true(FieldSave.exact(saved))
	assert_true(FieldSave._whole(saved))
