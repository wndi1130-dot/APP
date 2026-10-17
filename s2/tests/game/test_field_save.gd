extends "res://addons/gut/test.gd"
## The field's one save slot (S3 spec 4, user decision 296): what a stop came
## to goes to JSON and back whole, a broken slot falls back to the one before,
## and with the switch off the field writes nothing.

const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")

const DIR := "user://test_field_save"
const AT := DIR + "/field_save.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	FieldSave.clear(AT)


func after_each() -> void:
	FieldSave.clear(AT)


func _game(extra: Dictionary = {}):
	var game = FieldGame.new()
	var opts := {"seed": 4, "auto_pause": false}
	opts.merge(extra, true)
	game.opts = opts
	game.map_script = BareLine
	add_child_autofree(game)
	game.set_process(false)
	return game


func _sample() -> Dictionary:
	return {
		"version": FieldSave.VERSION, "kind": FieldSave.KIND, "stop_id": "stop-1", "place": "bare", "mission": "", "seed": 4,
		"phase": "field", "end_reason": "", "saved_at": "D1 10:30", "clock": {"elapsed": 12.5, "speed": 1.0}, "player_pid": "p1",
		"people": [{"pid": "p1", "team": "squad", "pos": Vector3(1.5, 0, -2.25), "level": 0, "alive": true, "bag": "pack", "items": {"food": 2}, "hands": [], "body": {"wounds": [], "infection": "", "infected": false, "exhaustion": 0.1, "downed": false, "dead": false}}],
		"ammo": {"pistol": 7, "shell": 4, "craft": 8}, "containers": {"c1": {"searched": true, "locked": false, "items": []}}, "spots": {},
		"ground_items": [{"pos": Vector3(3, 0, 4), "id": "arrow", "n": 1}], "unloaded": {"food": 3},
		"coal": {"delivered": 0.0, "spent": 0.0},
		"zombies": [{"id": 3, "kind": "walker", "pos": Vector3(5, 0, 6), "state": "wander", "loot": [], "searched": false, "horde": -1, "name": ""}],
		"decisions": [{"id": "d1", "choice": "a"}], "return_id": "", "promises": [{"id": "skip_dispatch", "by": "p2"}],
	}


func test_a_save_goes_to_json_and_back_whole() -> void:
	var d := _sample()
	var back := FieldSave.from_json(FieldSave.to_json(d))
	assert_eq(back, d, "the same save, places as places and counts as whole numbers")
	assert_true(back["people"][0]["pos"] is Vector3)
	assert_eq(typeof(back["zombies"][0]["id"]), TYPE_INT)
	assert_eq(back["promises"], d["promises"], "the train side's promises pass through untouched")


func test_what_is_not_a_whole_save_of_this_kind_reads_as_none() -> void:
	assert_eq(FieldSave.from_json("{not json"), {})
	var other := _sample()
	other["kind"] = "s1_train"
	assert_eq(FieldSave.from_json(FieldSave.to_json(other)), {}, "another kind")
	var old := _sample()
	old["version"] = FieldSave.VERSION + 1
	assert_eq(FieldSave.from_json(FieldSave.to_json(old)), {}, "another version")


func test_the_slot_is_written_over_and_a_broken_one_falls_back() -> void:
	var first := _sample()
	assert_true(FieldSave.write(first, AT))
	var second := _sample()
	second["clock"]["elapsed"] = 99.0
	assert_true(FieldSave.write(second, AT))
	assert_eq(FieldSave.read(AT)["clock"]["elapsed"], 99.0, "the last save is the one read")
	assert_false(FileAccess.file_exists(AT + ".tmp"))
	var f := FileAccess.open(AT, FileAccess.WRITE)
	f.store_string("{\"version\": 1, \"kind\": \"s2_fi")
	f.close()
	assert_eq(FieldSave.read(AT)["clock"]["elapsed"], 12.5, "a broken slot: the last whole one")
	FieldSave.clear(AT)
	assert_eq(FieldSave.read(AT), {}, "no save at all")


func test_a_field_is_captured_and_comes_back_the_same() -> void:
	var game = _game()
	var d := FieldSave.capture(game)
	assert_eq(d["kind"], FieldSave.KIND)
	assert_eq(d["seed"], 4)
	assert_eq(d["people"].size(), game.people.size())
	assert_eq(d["player_pid"], game.player.pid)
	assert_eq(d["people"][0]["pos"], game.people[0].position)
	assert_eq(FieldSave.from_json(FieldSave.to_json(d)), FieldSave.from_json(FieldSave.to_json(FieldSave.from_json(FieldSave.to_json(d)))), "a second trip changes nothing")


func test_with_the_switch_off_an_interrupt_writes_nothing() -> void:
	var game = _game({"field_save_path": AT})
	game.interrupt()
	assert_true(game.paused, "the field still stops")
	assert_false(FileAccess.file_exists(AT), "and nothing is saved")


func test_with_the_switch_on_an_interrupt_saves_the_field() -> void:
	var game = _game({"field_save": true, "field_save_path": AT})
	game.paused = true  # a pause the player chose: the app going away still saves
	game.interrupt()
	var d := FieldSave.read(AT)
	assert_eq(d["seed"], 4)
	assert_eq(d["people"].size(), game.people.size())
