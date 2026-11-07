extends "res://addons/gut/test.gd"
## Exercise apply() and real slot round trips, including startup through resume_opts().

const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const DeadCast = preload("res://game/actors/dead_cast.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")
var api: GDScript = DeadCast
var fields: Array = []
## A unique Korean/spaced folder: concurrent worktrees share user://.
static var DIR: String = "user://test_망자 차림_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
static var AT: String = DIR + "/현장 저장.json"


func before_each() -> void:
	assert_true(api.has_method("look_code_for"), "required DeadCast method")
	assert_eq(DirAccess.make_dir_recursive_absolute(DIR), OK)
	FieldSave.clear(AT)


func after_each() -> void:
	for game in fields:
		if is_instance_valid(game):
			game.free()
	fields.clear()
	FieldSave.clear(AT)
	await get_tree().process_frame


func after_all() -> void:
	assert_eq(DirAccess.remove_absolute(DIR), OK)


func _game(extra: Dictionary = {}, with_seed: bool = true):
	var game = FieldGame.new()
	var opts := {"raiders": false, "auto_pause": false, "arrive": false,
		"receipt_id": "dead_look_p0"}
	if with_seed:
		opts["seed"] = 831
	opts.merge(extra, true)
	game.opts = opts
	game.map_script = BareLine
	var resuming := opts.get("field_resume") is Dictionary
	add_child(game)
	game.set_process(false)
	assert_true(game.zombies.has_method("look_code_of"), "required draw/migration method")
	# _ready() applies field_resume itself; do not erase the result of that boot path.
	if not resuming:
		game.zombies.list.clear()
		game.pending_spawn.clear()
	fields.append(game)
	return game


func _saved(game) -> Dictionary:
	return FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))


## Godot's JSON text round trip can land one unit in the last place (ULP) off a float64 even though
## FieldSave writes with full precision: seen 11-07 on zombies[*].angle and zombies[*].phase, both
## directions (9c04804ea755f43f -> 9d04804ea755f43f, 000000e07b3ca13f -> ffffffdf7b3ca13f), on all
## five fixed seeds, never two units. FieldSave._encode passes finite floats through untouched, so the
## drift is the engine's decimal <-> double step, not this codec. A float counts as equal within
## FLOAT_ULP_SLACK units; ints, strings, types, key sets and sizes stay exact, and two units or more
## still fails, so a real codec change cannot hide behind this.
const FLOAT_ULP_SLACK: int = 1
const FAR_ULPS: int = 9223372036854775807


## Units in the last place between two float64s of the same sign; FAR_ULPS when they cannot be near
## (NaN, infinity, opposite signs).
static func _float_ulps(a: float, b: float) -> int:
	if a == b:
		return 0
	if is_nan(a) or is_nan(b) or is_inf(a) or is_inf(b) or signf(a) != signf(b):
		return FAR_ULPS
	var bytes := PackedByteArray()
	bytes.resize(16)
	bytes.encode_double(0, a)
	bytes.encode_double(8, b)
	# Same sign: the raw bit patterns sit in one half of int64 and count up with the magnitude.
	return absi(bytes.decode_s64(0) - bytes.decode_s64(8))


static func _float_from_bits(hex_le: String) -> float:
	return hex_le.hex_decode().decode_double(0)


func _save_value(value: Variant) -> String:
	if value is float:
		var bytes := PackedByteArray()
		bytes.resize(8)
		bytes.encode_double(0, value)
		return "%s (float64 %s)" % [str(value), bytes.hex_encode()]
	return "%s (%s)" % [var_to_str(value), type_string(typeof(value))]


func _save_difference(actual: Variant, expected: Variant, at: String = "save") -> String:
	if typeof(actual) == typeof(expected) and actual == expected:
		return ""
	if actual is float and expected is float:
		if _float_ulps(actual, expected) <= FLOAT_ULP_SLACK:
			return ""
	elif actual is Dictionary and expected is Dictionary:
		for key: Variant in expected:
			var path := "%s[%s]" % [at, str(key)]
			if not actual.has(key):
				return "%s: loaded=<missing>, saved=%s" % [path, _save_value(expected[key])]
			var difference := _save_difference(actual[key], expected[key], path)
			if difference != "":
				return difference
		for key: Variant in actual:
			if not expected.has(key):
				return "%s[%s]: loaded=%s, saved=<missing>" % [at, str(key), _save_value(actual[key])]
		return ""  # every key matched under the float rule above
	elif actual is Array and expected is Array:
		if actual.size() != expected.size():
			return "%s.size: loaded=%d, saved=%d" % [at, actual.size(), expected.size()]
		for i: int in expected.size():
			var difference := _save_difference(actual[i], expected[i], "%s[%d]" % [at, i])
			if difference != "":
				return difference
		return ""
	return "%s: loaded=%s, saved=%s" % [at, _save_value(actual), _save_value(expected)]


func _assert_saved_equal(actual: Dictionary, expected: Dictionary, why: String) -> void:
	# Exact except a float may sit FLOAT_ULP_SLACK units off (see FLOAT_ULP_SLACK); the message
	# names the first key that differs with both values' float64 bits.
	var difference := _save_difference(actual, expected)
	assert_true(difference.is_empty(), "%s\n%s" % [why, difference])


func _fixture() -> Dictionary:
	var game = _game()
	for id: int in [7, 17, 23, 31, 37, 41, 43]:
		var z: Dictionary = game.zombies.spawn("fresh" if id in [41, 43] else "dead", game.player.position + Vector3(4, 0, 0))
		z["id"] = id
		z["name"] = "일어난 사람" if id in [17, 31] else ""
		z["worn"] = {}
		z["state"] = "rising" if id == 43 else "wander"
		if id == 7:
			z["look_code"] = 95
		elif id == 17:
			z["look_code"] = 0
		elif id == 37:
			z["look_code"] = 511   # valid transport, an unassigned outfit
		else:
			z.erase("look_code")
	# The person link, not the already-finished rising state, identifies row 41.
	game.people[-1].display_name = ""
	game.people[-1].brain["rising_id"] = 41
	game.zombies.next_id = 44
	for _i: int in 7:
		game.rng.randi()
	return _saved(game)


func _assert_restored(game) -> void:
	assert_eq(game.zombies.list.size(), 7)
	assert_eq(int(game.people[-1].brain.get("rising_id", -1)), 41, "restored person retains the zombie link")
	for id: int in [7, 17, 23, 31, 37, 41, 43]:
		var z: Dictionary = game.zombies.find(id)
		assert_false(z.is_empty(), "saved identity %d survives temporary next_id" % id)
		assert_true(z.has("look_code"), "look is persistent before any later render/save")
		if not z.has("look_code"):
			continue
		var expected: int = 95 if id == 7 else (511 if id == 37 else 0)
		if id in [23, 43]:
			expected = int(api.call("look_code_for", 831, id))
			assert_gt(expected, 7, "unlinked unnamed rows get a common outfit even in rising state")
		assert_eq(int(z["look_code"]), expected, "saved/migrated code for %d" % id)
	var again := _saved(game)
	assert_false(again.is_empty())
	for row: Dictionary in again.get("zombies", []):
		assert_true(row.has("look_code"), "immediate re-save includes migrated code")
		assert_eq(row.get("look_code", -1), game.zombies.find(int(row["id"])).get("look_code", -2))


func test_t6_exact_restore_migrates_old_rows_once_before_immediate_resave() -> void:
	var saved := _fixture()
	assert_true(FieldSave.exact(saved))
	var original: Dictionary = saved.duplicate(true)
	var game = _game()
	game.zombies.next_id = 900
	game.people[0].brain["rising_id"] = 23  # stale local state must not classify an ordinary saved row
	assert_true(FieldSave._grid_sizes_match(game, saved))
	FieldSave.apply(game, saved)
	_assert_restored(game)
	assert_eq(saved, original, "migration must not rewrite the save input")
	var first := _saved(game)
	FieldSave.apply(game, first)
	_assert_restored(game)
	assert_eq(_saved(game)["zombies"], first["zombies"], "migration is idempotent")


func test_t5_exact_restore_keeps_saved_rng_state_and_next_draw() -> void:
	var saved := _fixture()
	var source = fields[0]
	var expected := RandomNumberGenerator.new()
	expected.seed = source.rng.seed
	expected.state = source.rng.state
	var state: int = expected.state
	var game = _game()
	game.rng.randi()
	FieldSave.apply(game, saved)
	assert_eq(game.rng.state, state, "restore/migration/view use no simulation dice")
	assert_eq(game.rng.randi(), expected.randi())
	_assert_restored(game)


func test_saved_zero_inactive_and_place_only_codes_survive_draw_and_resave() -> void:
	var source = _game()
	var codes: Array[int] = [0, 88, 511]
	for outfit: int in [24, 27]:
		for variant: int in 8:
			codes.append(outfit * 8 + variant)
	var expected_by_id := {}
	for code: int in codes:
		var z: Dictionary = source.zombies.spawn("dead", source.player.position + Vector3(4, 0, 0))
		z["name"] = ""
		z["look_code"] = code
		expected_by_id[int(z["id"])] = code
	var saved := _saved(source)
	assert_eq(int(saved["version"]), 3)
	var original: Dictionary = saved.duplicate(true)
	var game = _game()
	FieldSave.apply(game, saved)
	var state: int = game.rng.state
	assert_eq(state, source.rng.state, "restoring explicit codes keeps saved simulation state")
	assert_eq(game.zombies.list.size(), codes.size())
	for id: int in expected_by_id:
		var z: Dictionary = game.zombies.find(id)
		var code := int(expected_by_id[id])
		assert_eq(int(z.get("look_code", -1)), code)
		var active := code if (code >> 3) in [24, 27] else 0
		assert_eq(int(game.zombies.call("look_code_of", z)), active)
		var record: Dictionary = game.zombies._sight_draw(z, 0, "dead", {}, null, {})
		var custom: Color = record["custom"]
		assert_eq(int(floorf(custom.b * 0.5 + 0.25)), active if DeadBody.can_mix() else 0)
		assert_eq(int(z["look_code"]), code, "drawing only filters inactive codes")
	var again := _saved(game)
	var rows: Array = again["zombies"]
	assert_eq(rows.size(), codes.size())
	for row: Dictionary in rows:
		assert_eq(int(row.get("look_code", -1)), int(expected_by_id[int(row["id"])]))
	assert_eq(game.rng.state, state, "drawing and resaving consume no simulation dice")
	assert_eq(saved, original, "read/draw/resave leaves the input snapshot untouched")


func _fallback(reason: String) -> void:
	var saved := _fixture()
	match reason:
		"v1":
			saved["version"] = 1
		"v2_no_runtime", "v3_no_runtime":
			saved["version"] = 2 if reason == "v2_no_runtime" else 3
			saved.erase("runtime")
		"grid":
			var levels: Dictionary = saved["runtime"]["levels"]
			levels[levels.keys()[0]]["solid"] = PackedByteArray()
		"view_rule":
			saved["stop_view_rows"] = 1
			saved["stop_view_rule"] = -1
	var original: Dictionary = saved.duplicate(true)
	var game = _game()
	game.zombies.next_id = 900
	game.people[0].brain["rising_id"] = 23
	if reason == "grid":
		assert_true(FieldSave.exact(saved))
		assert_false(FieldSave._grid_sizes_match(game, saved))
	else:
		assert_false(FieldSave.exact(saved), "the selected condition really enters fallback")
	var expected := RandomNumberGenerator.new()
	expected.seed = game.rng.seed
	expected.state = game.rng.state
	# The pre-P0 spawn consumes angle, phase and stander only: three draws per row.
	for _i: int in (saved["zombies"] as Array).size() * 3:
		expected.randf()
	FieldSave.apply(game, saved)
	if reason == "grid":
		assert_push_warning("field save grid size changed; restoring legacy state")
	assert_eq(game.rng.state, expected.state, "fallback still consumes exactly three draws per row")
	assert_eq(game.rng.randi(), expected.randi())
	assert_eq(game.zombies.next_id, 44)
	_assert_restored(game)
	assert_eq(saved, original, "fallback leaves input untouched")


func test_t6_fallback_v1_preserves_and_migrates_with_unchanged_rng_cost() -> void:
	_fallback("v1")


func test_t6_fallback_v2_without_runtime_preserves_and_migrates() -> void:
	_fallback("v2_no_runtime")


func test_t6_fallback_v3_without_runtime_preserves_and_migrates() -> void:
	_fallback("v3_no_runtime")


func test_t6_fallback_grid_mismatch_preserves_and_migrates() -> void:
	_fallback("grid")


func test_t6_fallback_view_rule_mismatch_preserves_and_migrates() -> void:
	_fallback("view_rule")


func _file_fixture(seed_value: int = 831) -> Dictionary:
	# Fix construction too, then remove the option before spawning/capturing the old run.
	var source = _game({"seed": seed_value})
	source.opts.erase("seed")
	assert_false(source.opts.has("seed"), "the original run has no seed option")
	var expected := {17: 0, 23: 88, 31: 511, 37: 24 * 8 + 3, 41: 27 * 8 + 7, 43: 13, 47: 0, 53: 0}
	for id: int in [7, 17, 23, 31, 37, 41, 43, 47, 53]:
		var z: Dictionary = source.zombies.spawn("fresh" if id == 53 else "dead", source.player.position + Vector3(4, 0, 0))
		z["id"] = id
		z["name"] = "이름 있는 망자" if id in [41, 47] else ""
		z["state"] = "wander"
		z["worn"] = {}
		if id in [7, 47, 53]:
			z.erase("look_code")
		else:
			z["look_code"] = int(expected[id])
	source.people[-1].display_name = ""
	source.people[-1].brain["rising_id"] = 53
	source.zombies.next_id = 54
	for _i: int in 7:
		source.rng.randi()
	expected[7] = int(api.call("look_code_for", int(source.rng.seed), 7))
	return {"save": FieldSave.capture(source), "expected": expected,
		"seed": int(source.rng.seed), "rng_state": int(source.rng.state)}


func _assert_file_resume_and_immediate_resave(saved: Dictionary, fixture: Dictionary) -> void:
	assert_false(saved.is_empty(), "the real slot must return a complete save before booting")
	if saved.is_empty():
		return
	var original: Dictionary = saved.duplicate(true)
	var opts := FieldSave.resume_opts(saved)
	assert_eq(int(opts.get("seed", 0)), int(fixture["seed"]))
	assert_true(opts.has("field_resume"))
	# FieldGame._ready invokes FieldSave.apply with these actual disk-read options.
	var game = _game(opts, false)
	assert_eq(game.rng.seed, int(fixture["seed"]))
	assert_eq(game.rng.state, int(fixture["rng_state"]))
	assert_eq(int(game.people[-1].brain.get("rising_id", -1)), 53)
	var expected: Dictionary = fixture["expected"]
	assert_eq(game.zombies.list.size(), expected.size())
	for id: int in expected:
		var z: Dictionary = game.zombies.find(id)
		assert_eq(int(z.get("look_code", -1)), int(expected[id]), "disk restore code for %d" % id)
	# No extra render or simulation step between apply and the next actual write.
	assert_true(FieldSave.write(FieldSave.capture(game), AT))
	var again := FieldSave.read(AT)
	assert_false(again.is_empty())
	assert_eq((again.get("zombies", []) as Array).size(), expected.size())
	for row: Dictionary in again.get("zombies", []):
		assert_true(row.has("look_code"), "immediate disk resave persists every migrated code")
		assert_eq(int(row.get("look_code", -1)), int(expected[int(row["id"])]))
	assert_eq(game.rng.state, int(fixture["rng_state"]), "disk resave consumes no simulation dice")
	_assert_saved_equal(saved, original, "startup and immediate resave do not rewrite the input snapshot")


func test_real_file_round_trip_without_seed_option_preserves_mixed_legacy_looks() -> void:
	var fixture := _file_fixture()
	var saved: Dictionary = fixture["save"]
	var untouched: Dictionary = saved.duplicate(true)
	assert_false((saved["start_opts"] as Dictionary).has("seed"))
	assert_true(FieldSave.write(saved, AT))
	_assert_saved_equal(saved, untouched, "write must not mutate its source snapshot")
	assert_true(FileAccess.file_exists(AT))
	var loaded := FieldSave.read(AT)
	_assert_saved_equal(loaded, saved, "seed %d: write/read retains all missing and explicit codes before migration" % int(fixture["seed"]))
	assert_true(FieldSave.exact(loaded))
	_assert_file_resume_and_immediate_resave(loaded, fixture)


func test_invalid_look_in_primary_file_selects_valid_backup_and_resumes_it() -> void:
	var fixture := _file_fixture()
	var saved: Dictionary = fixture["save"]
	assert_true(FieldSave.write(saved, AT))
	var next: Dictionary = saved.duplicate(true)
	next["clock"]["elapsed"] = float(next["clock"]["elapsed"]) + 1.0
	assert_true(FieldSave.write(next, AT))
	var backup_bytes := FileAccess.get_file_as_bytes(AT + ".bak")
	_assert_saved_equal(FieldSave.from_json(backup_bytes.get_string_from_utf8()), saved, "backup contains the original snapshot")
	next["zombies"][0]["look_code"] = 512
	var broken_text := FieldSave.to_json(next)
	var file := FileAccess.open(AT, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string(broken_text)
	file.close()
	assert_eq(FieldSave.from_json(FileAccess.get_file_as_string(AT)), {}, "invalid primary look code is rejected")
	var loaded := FieldSave.read(AT)
	_assert_saved_equal(loaded, saved, "the valid backup wins over the invalid primary look code")
	assert_eq(FileAccess.get_file_as_bytes(AT + ".bak"), backup_bytes)
	_assert_file_resume_and_immediate_resave(loaded, fixture)
	assert_eq(FileAccess.get_file_as_bytes(AT + ".bak"), backup_bytes, "resave preserves the valid backup")
	assert_eq(FileAccess.get_file_as_string(AT + ".broken"), broken_text)


func test_save_difference_reports_the_nested_key_and_both_exact_values() -> void:
	var saved := {"zombies": [{"id": 7, "probe": 9007199254740993}]}
	var loaded := {"zombies": [{"id": 7, "probe": 9007199254740992}]}
	var difference := _save_difference(loaded, saved)
	assert_true(difference.contains("save[zombies][0][probe]"))
	assert_true(difference.contains("loaded=9007199254740992"))
	assert_true(difference.contains("saved=9007199254740993"))
	assert_true(_save_difference({"x": 0.25}, {"x": 0.5}).contains("float64"))
	assert_true(_save_difference({}, {"x": 1}).contains("loaded=<missing>"))
	assert_true(_save_difference({"x": 1}, {}).contains("saved=<missing>"))
	assert_eq(_save_difference(saved, saved.duplicate(true)), "")


func test_save_difference_allows_one_float_ulp_and_nothing_else() -> void:
	var x := _float_from_bits("000000e07b3ca13f")
	var one_down := _float_from_bits("ffffffdf7b3ca13f")   # the 11-07 phase pair, one unit apart
	var bits := PackedByteArray()
	bits.resize(8)
	bits.encode_double(0, x)
	bits.encode_s64(0, bits.decode_s64(0) + 2)
	var two_up: float = bits.decode_double(0)
	assert_eq(_float_ulps(x, one_down), 1)
	assert_eq(_float_ulps(one_down, x), 1)
	assert_eq(_float_ulps(x, two_up), 2)
	assert_eq(_save_difference({"z": [{"phase": one_down}]}, {"z": [{"phase": x}]}), "",
		"one unit in the last place, nested in a dictionary and an array, counts as equal")
	var two := _save_difference({"z": [{"phase": two_up}]}, {"z": [{"phase": x}]})
	assert_true(two.contains("save[z][0][phase]"), "two units still fail and name the key: %s" % two)
	assert_true(two.contains("float64"), "two units still show both values' bits: %s" % two)
	# The slack is for floats only: a type change, a sign flip, NaN and infinity stay differences.
	assert_ne(_save_difference({"n": 8.0}, {"n": 8}), "", "float in place of int")
	assert_ne(_save_difference({"n": 8}, {"n": 8.0}), "", "int in place of float")
	assert_ne(_save_difference({"f": -x}, {"f": x}), "", "opposite sign")
	assert_eq(_float_ulps(NAN, NAN), FAR_ULPS)
	assert_eq(_float_ulps(INF, 1.0e308), FAR_ULPS)
	assert_eq(_float_ulps(0.0, -0.0), 0, "the two zeros compare equal")
	assert_eq(_save_difference({"a": [1, 2]}, {"a": [1, 2, 3]}), "save[a].size: loaded=2, saved=3")


func test_engine_json_float_round_trip_stays_within_one_ulp() -> void:
	# The saved bits from the five 11-07 failures; the log line says what the engine does today.
	for hex: String in ["9c04804ea755f43f", "000000e07b3ca13f", "000000607836ed3f",
			"00000020cd4d933f", "000000c091ffed3f"]:
		var x := _float_from_bits(hex)
		var text := JSON.stringify({"v": x}, "", false, true)
		var back: Variant = JSON.parse_string(text)["v"]
		assert_true(back is float, "%s reads back as a float" % hex)
		var ulps := _float_ulps(float(back), x)
		gut.p("engine JSON float round trip %s via %s -> %d ulp" % [hex, text, ulps])
		assert_true(ulps <= FLOAT_ULP_SLACK, "%s: %d units off after the engine's JSON text" % [hex, ulps])


func test_int64_seed_and_rng_payload_round_trip_preserves_values_and_input() -> void:
	for seed_value: int in [0, 9007199254740991, 9007199254740993, -19, 9223372036854775807]:
		var saved := _minimal()
		saved["kind"] = FieldSave.KIND
		saved["seed"] = seed_value
		saved["start_opts"] = {}
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		rng.state = seed_value
		saved["rng_probe"] = FieldSave._freeze(null, rng)
		var untouched: Dictionary = saved.duplicate(true)
		assert_true(FieldSave.write(saved, AT), "write seed %d" % seed_value)
		_assert_saved_equal(saved, untouched, "source unchanged for seed %d" % seed_value)
		var loaded := FieldSave.read(AT)
		_assert_saved_equal(loaded, saved, "exact int64 file round trip for seed %d" % seed_value)
		assert_eq(loaded.get("seed"), seed_value)
		assert_eq(loaded.get("rng_probe"), {"$rng": [str(seed_value), str(seed_value)]})
		assert_false((loaded.get("start_opts", {}) as Dictionary).has("seed"))


func test_fixed_int64_seeds_preserve_full_capture_through_real_files() -> void:
	# Isolate the intermittent dictionary difference from resume/scene reconstruction.
	for seed_value: int in [0, 9007199254740991, 9007199254740993, -19, 9223372036854775807]:
		var fixture := _file_fixture(seed_value)
		var saved: Dictionary = fixture["save"]
		var untouched: Dictionary = saved.duplicate(true)
		assert_eq(saved["seed"], seed_value)
		assert_false((saved["start_opts"] as Dictionary).has("seed"))
		assert_true(FieldSave.write(saved, AT), "full capture seed %d" % seed_value)
		_assert_saved_equal(saved, untouched, "full capture input unchanged, seed %d" % seed_value)
		_assert_saved_equal(FieldSave.read(AT), saved, "full capture exact round trip, seed %d" % seed_value)
		# Bound scene lifetime: only this iteration's source exists during the next build.
		var source = fields.pop_back()
		source.free()
		await get_tree().process_frame


func _minimal() -> Dictionary:
	return {"version": 1, "clock": {"elapsed": 0.0, "speed": 1.0},
		"coal": {"delivered": 0.0, "spent": 0.0},
		"zombies": [{"id": 7, "horde": -1, "kind": "dead", "pos": Vector3.ZERO, "state": "wander"}]}


func test_whole_rejects_noninteger_nonfinite_and_out_of_range_look_codes() -> void:
	for value: Variant in [-1, 512, 1.5, "8", {}, [], null, NAN, INF, -INF, true]:
		var saved := _minimal()
		saved["zombies"][0]["look_code"] = value
		assert_false(FieldSave._whole(saved), "reject look_code %s (type %d)" % [str(value), typeof(value)])


func test_whole_accepts_missing_zero_max_and_integral_json_numbers() -> void:
	assert_true(FieldSave._whole(_minimal()), "legacy row remains readable")
	for value: Variant in [0, 511, 0.0, 511.0, 8, 8.0]:
		var saved := _minimal()
		saved["zombies"][0]["look_code"] = value
		assert_true(FieldSave._whole(saved), "valid transport even if the outfit is reserved")
