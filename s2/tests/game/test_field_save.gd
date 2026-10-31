extends "res://addons/gut/test.gd"
## The field's one save slot (S3 spec 4, user decision 296): what a stop came
## to goes to JSON and back whole, a broken slot falls back to the one before,
## and with the switch off the field writes nothing.

const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const LungerRules = preload("res://game/sim/lunger_rules.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")

const DIR := "user://test_field_save"
const AT := DIR + "/field_save.json"


func before_each() -> void:
	FieldSave._test_fail_step = ""
	DirAccess.make_dir_recursive_absolute(DIR)
	FieldSave.clear(AT)


func after_each() -> void:
	FieldSave._test_fail_step = ""
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


func test_fractional_or_non_numeric_versions_are_not_whole_saves() -> void:
	# to_json writes an integer envelope, so edit the JSON data without that coercion.
	var data: Dictionary = JSON.parse_string(FieldSave.to_json(_sample()))
	for version in [2.5, "2", true, null, [], {}]:
		data["version"] = version
		assert_eq(FieldSave.from_json(JSON.stringify(data)), {}, "invalid version: " + str(version))
	for version in [1.0, 2.0]:
		data["version"] = version
		assert_false(FieldSave.from_json(JSON.stringify(data)).is_empty(), "an integral JSON number is allowed")


func test_required_nested_fields_must_have_the_expected_types() -> void:
	var cases: Array = [
		[["clock"], []], [["clock", "elapsed"], "12.5"], [["clock", "speed"], null],
		[["coal"], []], [["coal", "delivered"], {}], [["coal", "spent"], "0"],
		[["people"], {}], [["people", 0], []], [["people", 0, "pid"], null],
		[["people", 0, "pos"], "here"], [["people", 0, "level"], "0"],
		[["people", 0, "items"], []], [["people", 0, "items", "food"], "2"],
		[["people", 0, "hands"], {}], [["people", 0, "hands"], [null]], [["people", 0, "body"], []],
		[["zombies"], {}], [["zombies", 0, "id"], "3"], [["zombies", 0, "horde"], []],
		[["containers", "c1"], []], [["containers", "c1", "items"], {}],
		[["ground_items", 0, "n"], "1"], [["ammo", "pistol"], "7"],
		[["start_opts"], []], [["departure"], []],
	]
	for version in [1, 2]:
		for trial in cases:
			var d := _sample()
			d["version"] = version
			var path: Array = trial[0]
			var parent: Variant = d
			for key in path.slice(0, path.size() - 1):
				parent = parent[key]
			parent[path.back()] = trial[1]
			assert_eq(FieldSave.from_json(FieldSave.to_json(d)), {}, "v%d %s" % [version, str(path)])


func test_optional_legacy_fields_and_body_defaults_can_be_absent() -> void:
	for version in [1, 2]:
		var d := _sample()
		d["version"] = version
		d["people"][0]["body"] = {}
		assert_eq(FieldSave.from_json(FieldSave.to_json(d)), d, "body readers supply their old defaults")
		for key in ["people", "zombies", "containers", "spots", "ammo", "unloaded", "ground_items", "decisions", "departure"]:
			d.erase(key)
		assert_eq(FieldSave.from_json(FieldSave.to_json(d)), d, "defaulted collections and runtime stay optional")


func test_exact_saves_require_their_directly_read_runtime_fields() -> void:
	var saved := FieldSave.capture(_game())
	assert_false(FieldSave.from_json(FieldSave.to_json(saved)).is_empty())
	for key in ["spots", "levels", "mission", "components", "holdout_doors", "game"]:
		var broken := saved.duplicate(true)
		broken["runtime"].erase(key)
		assert_eq(FieldSave.from_json(FieldSave.to_json(broken)), {}, "runtime." + key)
	# zombie_system is read with a fallback (_restore_zombie_system): optional, but typed when there.
	var without_system := saved.duplicate(true)
	without_system["runtime"].erase("zombie_system")
	assert_false(FieldSave.from_json(FieldSave.to_json(without_system)).is_empty(), "runtime.zombie_system optional")
	var odd_system := saved.duplicate(true)
	odd_system["runtime"]["zombie_system"] = []
	assert_eq(FieldSave.from_json(FieldSave.to_json(odd_system)), {}, "runtime.zombie_system typed")
	for key in ["containers", "people", "zombies"]:
		var broken := saved.duplicate(true)
		broken.erase(key)
		assert_eq(FieldSave.from_json(FieldSave.to_json(broken)), {}, "exact save: " + key)


func test_a_v2_departure_requires_the_fields_used_to_build_the_stop() -> void:
	var d := _sample()
	d["departure"] = {
		"version": 2, "placeId": "bare", "departureId": "dep_1", "stopId": "stop-1",
		"roster": [{"id": "p1", "name": "Chief", "role": "chief", "comm": "guard", "rel": 0.0,
			"body": {}, "gear": {"hands": [], "items": {}, "bag": "pack", "wear": {}}, "hunger": 0, "sore": 0, "rest": 0}],
	}
	assert_false(FieldSave.from_json(FieldSave.to_json(d)).is_empty())
	for key in ["placeId", "departureId", "stopId", "roster"]:
		var broken := d.duplicate(true)
		broken["departure"].erase(key)
		assert_eq(FieldSave.from_json(FieldSave.to_json(broken)), {}, "departure." + key)
	var broken_gear := d.duplicate(true)
	broken_gear["departure"]["roster"][0]["gear"]["hands"] = {}
	assert_eq(FieldSave.from_json(FieldSave.to_json(broken_gear)), {}, "nested contract gear")


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
	FieldSave._test_fail_step = "short"
	assert_false(FieldSave.write(next, AT), "a cut-off temporary file is not a save")
	assert_eq(FieldSave._test_fail_step, "", "the failure switches itself off")
	assert_eq(FileAccess.get_file_as_string(AT), slot_text, "the slot is untouched")
	assert_eq(FileAccess.get_file_as_string(AT + ".bak"), backup_text, "the backup is untouched")
	assert_false(FileAccess.file_exists(AT + ".tmp"))
	assert_eq(FieldSave.read(AT), previous, "the last whole save is still read")
	assert_true(FieldSave.write(next, AT), "the next write is whole without resetting the failure")
	assert_eq(FieldSave.read(AT), next)


func _assert_write_failure_preserves_slot(step: String) -> void:
	assert_true(FieldSave.write(_sample(), AT))
	var previous := _sample()
	previous["clock"]["elapsed"] = 99.0
	assert_true(FieldSave.write(previous, AT))
	var slot_bytes := FileAccess.get_file_as_bytes(AT)
	var backup_bytes := FileAccess.get_file_as_bytes(AT + ".bak")
	var next := _sample()
	next["clock"]["elapsed"] = 150.0
	FieldSave._test_fail_step = step
	assert_false(FieldSave.write(next, AT), step)
	assert_eq(FieldSave._test_fail_step, "", "one write only")
	assert_eq(FileAccess.get_file_as_bytes(AT), slot_bytes, "the latest slot stays in place")
	assert_eq(FileAccess.get_file_as_bytes(AT + ".bak"), backup_bytes, "the older backup is untouched")
	assert_false(FileAccess.file_exists(AT + ".broken"), "a read error does not quarantine a whole save")
	assert_false(FileAccess.file_exists(AT + ".tmp"))
	assert_eq(FieldSave.read(AT), previous, "read still picks the latest whole save after " + step)
	assert_true(FieldSave.write(next, AT), "the next write has no injected failure")
	assert_eq(FieldSave.read(AT), next)


func test_a_write_error_keeps_the_slot_and_its_backup_whole() -> void:
	_assert_write_failure_preserves_slot("write_error")


func test_same_length_tampering_keeps_the_previous_save() -> void:
	var changed := FieldSave.to_json(_sample()).to_utf8_buffer()
	var at := changed.find(46)
	assert_gte(at, 0, "the sample has a decimal point")
	changed[at] = 48
	assert_eq(changed.size(), FieldSave.to_json(_sample()).to_utf8_buffer().size())
	assert_false(FieldSave.from_json(changed.get_string_from_utf8()).is_empty(), "tampering remains parseable and structurally whole")
	_assert_write_failure_preserves_slot("tamper")


func test_a_previous_read_error_keeps_the_latest_slot_in_place() -> void:
	_assert_write_failure_preserves_slot("read_previous")


func test_a_temporary_rename_failure_still_reads_the_previous_save() -> void:
	assert_true(FieldSave.write(_sample(), AT))
	var previous := _sample()
	previous["clock"]["elapsed"] = 99.0
	assert_true(FieldSave.write(previous, AT))
	var next := _sample()
	next["clock"]["elapsed"] = 150.0
	FieldSave._test_fail_step = "rename_tmp"
	assert_false(FieldSave.write(next, AT))
	assert_eq(FieldSave._test_fail_step, "")
	assert_eq(FileAccess.get_file_as_string(AT), FieldSave.to_json(previous))
	assert_false(FileAccess.file_exists(AT + ".tmp"))
	assert_eq(FieldSave.read(AT), previous, "the whole slot moved to backup is restored/readable")
	assert_true(FieldSave.write(next, AT))
	assert_eq(FieldSave.read(AT), next)


func test_a_write_with_only_a_whole_backup_preserves_that_backup() -> void:
	var first := _sample()
	assert_true(FieldSave.write(first, AT))
	assert_eq(DirAccess.rename_absolute(AT, AT + ".bak"), OK)
	var backup_bytes := FileAccess.get_file_as_bytes(AT + ".bak")
	assert_eq(FieldSave.read(AT), first)
	var next := _sample()
	next["clock"]["elapsed"] = 150.0
	assert_true(FieldSave.write(next, AT))
	assert_eq(FileAccess.get_file_as_string(AT), FieldSave.to_json(next))
	assert_eq(FileAccess.get_file_as_bytes(AT + ".bak"), backup_bytes)
	assert_false(FileAccess.file_exists(AT + ".tmp"))
	assert_eq(FieldSave.read(AT), next)


func test_a_structurally_broken_slot_falls_back_and_preserves_the_backup_on_write() -> void:
	var first := _sample()
	assert_true(FieldSave.write(first, AT))
	var previous := _sample()
	previous["clock"]["elapsed"] = 99.0
	assert_true(FieldSave.write(previous, AT))
	var backup_bytes := FileAccess.get_file_as_bytes(AT + ".bak")
	var broken := _sample()
	broken.erase("clock")
	var broken_text := FieldSave.to_json(broken)
	var file := FileAccess.open(AT, FileAccess.WRITE)
	file.store_string(broken_text)
	file.close()
	assert_eq(FieldSave.from_json(broken_text), {})
	assert_eq(FieldSave.read(AT), first, "valid JSON with a missing clock must not hide the backup")
	var next := _sample()
	next["clock"]["elapsed"] = 150.0
	assert_true(FieldSave.write(next, AT))
	assert_eq(FileAccess.get_file_as_string(AT + ".broken"), broken_text)
	assert_eq(FileAccess.get_file_as_bytes(AT + ".bak"), backup_bytes)
	assert_false(FileAccess.file_exists(AT + ".tmp"))
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


func test_new_lunger_share_round_trips_with_assignments_clocks_and_dice() -> void:
	var a = _game({"act": "act1", "act_progress": 9.0 / 12.0})
	var z: Dictionary = a.zombies.spawn("dead", a.player.position + Vector3(3, 0, 0))
	z["lunger"] = true
	z["lunged"] = true
	z["state"] = "chase"
	z["dash_t"] = 0.7
	z["dash_dir"] = Vector3.RIGHT
	z["spent_t"] = 0.25
	var risen: Dictionary = a.zombies.add_rising(a.player.position + Vector3(4, 0, 0), "")
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(a)))
	var system: Dictionary = saved["runtime"]["zombie_system"]
	assert_almost_eq(float(system["lunger_share"]), 0.05, 0.000000001)
	assert_false(system.has("lungers_on"), "new saves store only the share")
	var opts: Dictionary = FieldSave.resume_opts(saved)
	opts[LungerRules.OPTION] = true  # Saved share wins over the rebuilt field (383, 387, 134).
	var b = _game(opts)
	assert_eq(b.zombies.lunger_share, a.zombies.lunger_share)
	assert_eq(b.zombies.lunge_rng.state, a.zombies.lunge_rng.state)
	assert_eq(b.rng.state, a.rng.state)
	var back: Dictionary = b.zombies.find(int(z["id"]))
	assert_true(back["lunger"])
	assert_true(back["lunged"])
	assert_eq(back["dash_t"], z["dash_t"])
	assert_eq(back["dash_dir"], z["dash_dir"])
	assert_eq(back["spent_t"], z["spent_t"])
	var risen_back: Dictionary = b.zombies.find(int(risen["id"]))
	assert_eq(risen_back["lunger"], risen["lunger"])
	assert_eq(risen_back["rise_t"], risen["rise_t"])
	var next_a: Dictionary = a.zombies.spawn("dead", a.player.position)
	var next_b: Dictionary = b.zombies.spawn("dead", b.player.position)
	assert_eq(next_b["id"], next_a["id"])
	assert_eq(next_b["lunger"], next_a["lunger"])
	var rising_a: Dictionary = a.zombies.add_rising(a.player.position, "")
	var rising_b: Dictionary = b.zombies.add_rising(b.player.position, "")
	assert_eq(rising_b["lunger"], rising_a["lunger"])
	assert_eq(b.zombies.lunge_rng.state, a.zombies.lunge_rng.state)
	assert_eq(b.rng.state, a.rng.state)


func test_old_v2_lungers_on_true_and_false_restore_without_the_removed_property() -> void:
	var a = _game()
	for was_on: bool in [true, false]:
		var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(a)))
		var system: Dictionary = saved["runtime"]["zombie_system"]
		system.erase("lunger_share")
		system["lungers_on"] = was_on
		var opts: Dictionary = FieldSave.resume_opts(saved)
		opts["act"] = "act3"
		var b = _game(opts)
		assert_eq(float(b.zombies.lunger_share), LungerRules.SHARE if was_on else 0.0)
		assert_eq(b.zombies.lunge_rng.state, a.zombies.lunge_rng.state)
		assert_true(system.has("lungers_on"), "migration leaves the input untouched")


func test_new_share_wins_over_an_old_switch_even_when_zero() -> void:
	var a = _game()
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(a)))
	saved["runtime"]["zombie_system"]["lunger_share"] = 0.0
	saved["runtime"]["zombie_system"]["lungers_on"] = true
	var b = _game(FieldSave.resume_opts(saved))
	assert_eq(float(b.zombies.lunger_share), 0.0, "presence, not truthiness, chooses the new field")


func test_missing_v2_switch_or_system_keeps_the_start_share() -> void:
	var a = _game()
	for missing_system: bool in [false, true]:
		var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(a)))
		if missing_system:
			saved["runtime"].erase("zombie_system")
		else:
			saved["runtime"]["zombie_system"].erase("lunger_share")
		var opts: Dictionary = FieldSave.resume_opts(saved)
		opts[LungerRules.OPTION] = true
		var b = _game(opts)
		assert_eq(float(b.zombies.lunger_share), LungerRules.SHARE, "the start's forced share stays, as the old switch did")


func test_v1_and_grid_fallback_keep_the_start_share() -> void:
	var a = _game()
	for legacy: bool in [true, false]:
		var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(a)))
		if legacy:
			saved["version"] = 1
			saved.erase("runtime")
		else:
			saved["runtime"]["levels"][0]["width"] += 1
		var opts: Dictionary = FieldSave.resume_opts(saved)
		opts[LungerRules.OPTION] = true
		var b = _game(opts)
		assert_eq(float(b.zombies.lunger_share), LungerRules.SHARE, "the start's forced share stays, as the old switch did")


## The start's own share: the prologue's 0, act 1 slot 10's 0.05, or the forced 0.1 (383, 387, 134).
func _resume_with_start(saved: Dictionary, start: Dictionary):
	var opts: Dictionary = FieldSave.resume_opts(saved)
	opts.merge(start, true)
	return _game(opts)


const STARTS: Array = [
	[{"act": "prologue", "act_progress": 0.5, "lungers": false}, 0.0],
	[{"act": "act1", "act_progress": 0.75, "lungers": false}, 0.05],
	[{"act": "act1", "act_progress": 0.75, "lungers": true}, 0.1],
]


func test_a_saved_share_that_is_not_a_share_keeps_the_start_share() -> void:
	for bad: float in [NAN, INF, -INF, -0.1, 1.5]:
		var a = _game()
		a.zombies.lunger_share = bad
		var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(a)))
		for start: Array in STARTS:
			var b = _resume_with_start(saved, start[0])
			assert_almost_eq(float(b.zombies.lunger_share), float(start[1]), 0.000000001, "%s falls back to the start's own share" % bad)


func test_missing_share_v1_and_grid_fallback_keep_each_start_share() -> void:
	var a = _game()
	for way: String in ["missing", "v1", "grid"]:
		var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(a)))
		if way == "missing":
			saved["runtime"]["zombie_system"].erase("lunger_share")
		elif way == "v1":
			saved["version"] = 1
			saved.erase("runtime")
		else:
			saved["runtime"]["levels"][0]["width"] += 1
		for start: Array in STARTS:
			var b = _resume_with_start(saved, start[0])
			assert_almost_eq(float(b.zombies.lunger_share), float(start[1]), 0.000000001, "%s keeps the start's own share" % way)


func test_the_slice_marker_survives_capture_and_resume_options() -> void:
	var game = _game({"slice": true, "field_save": true, "field_save_path": AT})
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))
	assert_true(bool(saved["start_opts"]["slice"]))
	var resumed: Dictionary = FieldSave.resume_opts(saved)
	assert_true(bool(resumed["slice"]))
	assert_false(saved["start_opts"].has("field_save_path"))
