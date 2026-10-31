extends "res://addons/gut/test.gd"
## The field's one save slot (S3 spec 4, user decision 296): what a stop came
## to goes to JSON and back whole, a broken slot falls back to the one before,
## and with the switch off the field writes nothing.

const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const FieldWork = preload("res://game/field_work.gd")
const LungerRules = preload("res://game/sim/lunger_rules.gd")
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


func _dig_save(parts: Array, wagon_index: int = -1) -> Dictionary:
	var saved: Dictionary = _sample()
	var site: Dictionary = {"dig_parts": parts}
	if wagon_index >= 0:
		site["dig_wagon"] = wagon_index
	saved["runtime"] = {"components": {"work": {"sites": {"work_site": site}}}}
	return saved


func test_wagon_indices_and_pick_seconds_survive_json() -> void:
	var parts: Array = [{"wagon": 0, "seconds": 60.0}, {"wagon": 1, "seconds": 30.0}]
	var saved: Dictionary = _dig_save(parts, 1)
	var back: Dictionary = FieldSave.from_json(FieldSave.to_json(saved))
	var site: Dictionary = back["runtime"]["components"]["work"]["sites"]["work_site"]
	assert_eq(site["dig_parts"], parts)
	assert_eq(int(site["dig_wagon"]), 1)
	assert_eq(typeof(site["dig_parts"][0]["wagon"]), TYPE_INT)
	assert_eq(FieldSave.from_json(FieldSave.to_json(back)), back)


func test_writing_dig_parts_clamps_finite_seconds_and_discards_nonfinite_seconds() -> void:
	var saved: Dictionary = _dig_save([135.0, -15.0, NAN, INF, -INF,
		{"wagon": 1, "seconds": INF}, {"wagon": 1, "seconds": 45.0}], 0)
	var back: Dictionary = FieldSave.from_json(FieldSave.to_json(saved))
	var parts: Array = back["runtime"]["components"]["work"]["sites"]["work_site"]["dig_parts"]
	assert_eq(parts, [{"wagon": 0, "seconds": 90.0}, {"wagon": 0, "seconds": 0.0},
		{"wagon": 1, "seconds": 45.0}])


func test_reading_dig_parts_clamps_seconds_before_they_can_be_resumed() -> void:
	var encoded: Dictionary = JSON.parse_string(FieldSave.to_json(_dig_save([], 0)))
	encoded["runtime"]["components"]["work"]["sites"]["work_site"]["dig_parts"] = [135.0, -15.0,
		{"wagon": 1, "seconds": {"$type": "float", "value": "inf"}},
		{"wagon": 1, "seconds": {"$type": "float", "value": "-inf"}}]
	var back: Dictionary = FieldSave.from_json(JSON.stringify(encoded))
	assert_eq(back["runtime"]["components"]["work"]["sites"]["work_site"]["dig_parts"],
		[{"wagon": 0, "seconds": 90.0}, {"wagon": 0, "seconds": 0.0}])


func test_legacy_numeric_dig_parts_wait_for_the_current_map_wagon() -> void:
	var saved: Dictionary = _dig_save([60.0, 135.0, -15.0, NAN, INF])
	var back: Dictionary = FieldSave.from_json(FieldSave.to_json(saved))
	var site: Dictionary = back["runtime"]["components"]["work"]["sites"]["work_site"]
	assert_eq(site["dig_parts"], [60.0, 90.0, 0.0], "no map index invented by JSON conversion")
	assert_eq(FieldWork.clean_dig_parts(site["dig_parts"], 1),
		[{"wagon": 1, "seconds": 60.0}, {"wagon": 1, "seconds": 90.0}, {"wagon": 1, "seconds": 0.0}])


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
