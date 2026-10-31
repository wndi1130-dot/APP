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
		"ground_items": [{"pos": Vector3(3, 0, 4), "id": "ammo_craft", "n": 1}], "unloaded": {"food": 3},
		"coal": {"delivered": 0.0, "spent": 0.0},
		"zombies": [{"id": 3, "kind": "walker", "pos": Vector3(5, 0, 6), "state": "wander", "loot": [], "searched": false, "horde": -1, "name": ""}],
		"decisions": [{"id": "d1", "choice": "a"}], "receipt_id": "ret_1", "departure": {"version": 1.0, "departureId": "dep_1", "stopId": "stop-1", "roster": [{"id": "p1", "comm": "guard"}], "promises": []},
	}


func test_a_save_goes_to_json_and_back_whole() -> void:
	var d := _sample()
	var back := FieldSave.from_json(FieldSave.to_json(d))
	assert_eq(back, d, "the same save, places as places and counts as whole numbers")
	assert_true(back["people"][0]["pos"] is Vector3)
	assert_eq(typeof(back["zombies"][0]["id"]), TYPE_INT)
	assert_eq(back["departure"], d["departure"], "the departure order passes through untouched")


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
	second["stop_id"] = "정차-2"
	assert_true(FieldSave.write(second, AT))
	assert_eq(FileAccess.get_file_as_string(AT), FieldSave.to_json(second))
	assert_eq(FieldSave.from_json(FileAccess.get_file_as_string(AT + ".bak")), first)
	assert_eq(FieldSave.read(AT)["clock"]["elapsed"], 99.0, "the last save is the one read")
	assert_false(FileAccess.file_exists(AT + ".tmp"))
	var f := FileAccess.open(AT, FileAccess.WRITE)
	f.store_string("{\"version\": 1, \"kind\": \"s2_fi")
	f.close()
	assert_eq(FieldSave.read(AT)["clock"]["elapsed"], 12.5, "a broken slot: the last whole one")
	FieldSave.clear(AT)
	assert_eq(FieldSave.read(AT), {}, "no save at all")


func test_a_cut_off_write_keeps_the_slot_and_its_backup_whole() -> void:
	assert_true(FieldSave.write(_sample(), AT))
	var previous := _sample()
	previous["clock"]["elapsed"] = 99.0
	assert_true(FieldSave.write(previous, AT))
	var slot_text := FileAccess.get_file_as_string(AT)
	var backup_text := FileAccess.get_file_as_string(AT + ".bak")
	var next := _sample()
	next["clock"]["elapsed"] = 150.0
	FieldSave._test_write_limit_bytes = 16
	assert_false(FieldSave.write(next, AT), "a cut-off temporary file is not a save")
	assert_eq(FieldSave._test_write_limit_bytes, -1, "the write limit switches itself off")
	assert_eq(FileAccess.get_file_as_string(AT), slot_text, "the slot is untouched")
	assert_eq(FileAccess.get_file_as_string(AT + ".bak"), backup_text, "the backup is untouched")
	assert_false(FileAccess.file_exists(AT + ".tmp"))
	assert_eq(FieldSave.read(AT), previous, "the last whole save is still read")
	assert_true(FieldSave.write(next, AT), "the next write is whole without resetting the limit")
	assert_eq(FieldSave.read(AT), next)


func test_writing_over_a_broken_slot_keeps_the_whole_backup() -> void:
	var first := _sample()
	assert_true(FieldSave.write(first, AT))
	var second := _sample()
	second["clock"]["elapsed"] = 99.0
	assert_true(FieldSave.write(second, AT))
	var backup_text := FileAccess.get_file_as_string(AT + ".bak")
	var f := FileAccess.open(AT + ".broken", FileAccess.WRITE)
	f.store_string("an older broken slot")
	f.close()
	var broken_text := "{\"version\": 1, \"kind\": \"s2_fi"
	f = FileAccess.open(AT, FileAccess.WRITE)
	f.store_string(broken_text)
	f.close()
	var next := _sample()
	next["clock"]["elapsed"] = 150.0
	assert_true(FieldSave.write(next, AT))
	assert_eq(FileAccess.get_file_as_string(AT + ".bak"), backup_text, "the whole backup is kept")
	assert_eq(FieldSave.from_json(backup_text), first)
	assert_eq(FileAccess.get_file_as_string(AT + ".broken"), broken_text, "the broken slot replaces the older one")
	assert_eq(FileAccess.get_file_as_string(AT), FieldSave.to_json(next))
	assert_eq(FieldSave.read(AT), next)
	assert_false(FileAccess.file_exists(AT + ".tmp"))


func test_clearing_the_slot_removes_its_broken_file_too() -> void:
	assert_true(FieldSave.write(_sample(), AT))
	assert_true(FieldSave.write(_sample(), AT))
	for suffix in [".tmp", ".broken"]:
		var f := FileAccess.open(AT + suffix, FileAccess.WRITE)
		f.store_string("left over")
		f.close()
		assert_true(FileAccess.file_exists(AT + suffix))
	FieldSave.clear(AT)
	for at in [AT, AT + ".tmp", AT + ".bak", AT + ".broken"]:
		assert_false(FileAccess.file_exists(at), "every file belonging to the slot is cleared")
	assert_eq(FieldSave.read(AT), {})


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


func test_the_departure_order_is_kept_whole_and_names_the_stop() -> void:
	var order = JSON.parse_string(FileAccess.get_file_as_string("res://tests/game/fixtures/field_v4/departure_skip_kept.json"))
	var game = _game({"departure": order, "receipt_id": "ret_test"})
	var d := FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))
	assert_eq(d["departure"], order, "camelCase inside, nothing renamed or dropped")
	assert_eq(d["stop_id"], String(order["stopId"]))
	assert_eq(d["receipt_id"], "ret_test")
	assert_false(d.has("promises"), "promises live inside the departure order")


func test_the_field_is_resumed_only_while_its_return_is_not_taken_in() -> void:
	var d := _sample()
	assert_true(FieldSave.should_resume(d, {}), "a stop still being played")
	assert_false(FieldSave.should_resume({}, {}), "no save")
	assert_false(FieldSave.should_resume(d, {"ret_1": true}), "the train already took this return in")
	assert_false(FieldSave.should_resume(d, ["ret_1"]), "a list of ids reads the same")
	var ended := _sample()
	ended["phase"] = "ended"
	assert_false(FieldSave.should_resume(ended, {}), "a stop that ended goes back to the train")


func _full_game(extra: Dictionary = {}):
	var game = FieldGame.new()
	var opts := {"seed": 5, "raiders": false, "auto_pause": false}
	opts.merge(extra, true)
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	return game


func test_a_stop_left_mid_play_comes_back_as_it_was() -> void:
	var a = _full_game({"receipt_id": "ret_a"})
	var p = a.player
	p.position += Vector3(2.0, 0, 1.0)
	p.add_item("bandage", 3)
	var box_id := ""
	for key in a.data["containers"]:
		if not a.data["containers"][key]["locked"]:
			box_id = key
			break
	assert_ne(box_id, "")
	a.data["containers"][box_id]["searched"] = true
	a.data["containers"][box_id]["items"] = []
	var z: Dictionary = a.zombies.spawn("dead", p.position + Vector3(3.0, 0, 0))
	a.zombies.kill(z)
	a.clock.elapsed = 123.0
	a.ammo["pistol"] = 2
	a.receipt.place_note("manholeBlocked", true)
	a.receipt.person("bitten", p.pid)
	var d := FieldSave.from_json(FieldSave.to_json(FieldSave.capture(a)))
	assert_true(FieldSave.should_resume(d, {}))
	var b = _full_game(FieldSave.resume_opts(d))
	assert_eq(b.rng.seed, a.rng.seed)
	assert_almost_eq(b.clock.elapsed, 123.0, 0.001)
	assert_true(b.player.position.is_equal_approx(p.position), "where the player stood")
	assert_eq(int(b.player.items.get("bandage", 0)), int(p.items.get("bandage", 0)))
	assert_true(b.data["containers"][box_id]["searched"], "a searched box stays searched")
	assert_eq(int(b.ammo["pistol"]), 2)
	var back: Dictionary = b.zombies.find(int(z["id"]))
	assert_false(back.is_empty(), "the same body, the same id")
	assert_eq(back["state"], "dead")
	assert_gt(b.zombies.next_id, int(z["id"]), "new bodies get new ids")
	var said: Dictionary = b.receipt.to_dict()
	assert_true(bool(said["placeState"].get("manholeBlocked", false)), "what the receipt gathered comes back")
	assert_true((said["people"]["bitten"] as Array).has(p.pid))
	assert_eq(b.arrive_t, -1.0, "the train is already in")
	assert_eq(String(b.opts.get("receipt_id", "")), "ret_a")


func test_without_a_save_handed_over_the_field_starts_fresh() -> void:
	var a = _game()
	a.clock.elapsed = 50.0
	assert_true(FieldSave.write(FieldSave.capture(a), AT))
	var b = _game({"field_save_path": AT})
	assert_almost_eq(b.clock.elapsed, 0.0, 0.001, "a file on disk alone changes nothing")


func test_the_slice_marker_survives_capture_and_resume_options() -> void:
	var game = _game({"slice": true, "field_save": true, "field_save_path": AT})
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))
	assert_true(bool(saved["start_opts"]["slice"]))
	var resumed: Dictionary = FieldSave.resume_opts(saved)
	assert_true(bool(resumed["slice"]))
	assert_false(saved["start_opts"].has("field_save_path"))
