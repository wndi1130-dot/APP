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
## five fixed seeds, never two units. Three checks cover different boundaries:
## - _assert_unchanged compares the input with its deep copy, including every float's bits. It catches
##   input mutation, but cannot catch a codec that changes only its newly returned output.
## - Codec-stage tests compare finite float bits in _encode and decode_checked (which calls _decode)
##   outputs before any JSON text step, including float64 neighbours of float32-exact values.
## - _assert_saved_equal allows FLOAT_ULP_SLACK units only across the engine's JSON text round trip.
##   That allowance alone cannot distinguish engine rounding from a one-unit codec regression.
## Ints, strings, types, key sets and sizes stay exact everywhere. Two units fail the round trip too.
const FLOAT_ULP_SLACK: int = 1
const FAR_ULPS: int = 9223372036854775807


## Units in the last place between two finite float64s with the same sign bit; FAR_ULPS for NaN, an
## infinity unequal to the other value, or opposite sign bits. Equal values (the same infinity, or +0.0
## and -0.0, which compare equal) are 0 apart.
static func _float_ulps(a: float, b: float) -> int:
	if a == b:
		return 0
	if is_nan(a) or is_nan(b) or is_inf(a) or is_inf(b):
		return FAR_ULPS
	var bytes := PackedByteArray()
	bytes.resize(16)
	bytes.encode_double(0, a)
	bytes.encode_double(8, b)
	var bits_a := bytes.decode_s64(0)
	var bits_b := bytes.decode_s64(8)
	# The sign bit, not signf(): 0.0 and the smallest subnormal share a sign bit one unit apart, while
	# signf(0.0) is 0. With one sign bit the raw patterns sit in one half of int64 and count up with
	# the magnitude, so their difference cannot overflow.
	if (bits_a < 0) != (bits_b < 0):
		return FAR_ULPS
	return absi(bits_a - bits_b)


static func _float_from_bits(hex_le: String) -> float:
	return hex_le.hex_decode().decode_double(0)


static func _float_bytes(value: float) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes


func _save_value(value: Variant) -> String:
	if value is float:
		var bytes := PackedByteArray()
		bytes.resize(8)
		bytes.encode_double(0, value)
		return "%s (float64 %s)" % [str(value), bytes.hex_encode()]
	return "%s (%s)" % [var_to_str(value), type_string(typeof(value))]


func _save_difference(actual: Variant, expected: Variant, at: String = "save", ulp_slack: int = FLOAT_ULP_SLACK) -> String:
	# Visit containers before comparing leaves: container == hides signed-zero changes.
	if actual is float and expected is float:
		if ulp_slack == 0:
			if _float_bytes(actual) == _float_bytes(expected):
				return ""
		elif _float_ulps(actual, expected) <= ulp_slack:
			return ""
	elif actual is Dictionary and expected is Dictionary:
		for key: Variant in expected:
			var path := "%s[%s]" % [at, str(key)]
			if not actual.has(key):
				return "%s: loaded=<missing>, saved=%s" % [path, _save_value(expected[key])]
			var difference := _save_difference(actual[key], expected[key], path, ulp_slack)
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
			var difference := _save_difference(actual[i], expected[i], "%s[%d]" % [at, i], ulp_slack)
			if difference != "":
				return difference
		return ""
	elif typeof(actual) == typeof(expected) and actual == expected:
		return ""  # non-float leaves retain exact type and value
	return "%s: loaded=%s, saved=%s" % [at, _save_value(actual), _save_value(expected)]


## Across the JSON file round trip: exact except a float may sit FLOAT_ULP_SLACK units off (see
## FLOAT_ULP_SLACK); the message names the first key that differs with both values' float64 bits.
func _assert_saved_equal(actual: Dictionary, expected: Dictionary, why: String) -> void:
	var difference := _save_difference(actual, expected)
	assert_true(difference.is_empty(), "%s\n%s" % [why, difference])


## An in-memory source against its own deep copy, no JSON in between: every float bit-exact.
func _assert_unchanged(actual: Dictionary, expected: Dictionary, why: String) -> void:
	var difference := _save_difference(actual, expected, "save", 0)
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
	_assert_unchanged(saved, original, "startup and immediate resave do not rewrite the input snapshot")


func test_real_file_round_trip_without_seed_option_preserves_mixed_legacy_looks() -> void:
	var fixture := _file_fixture()
	var saved: Dictionary = fixture["save"]
	var untouched: Dictionary = saved.duplicate(true)
	assert_false((saved["start_opts"] as Dictionary).has("seed"))
	assert_true(FieldSave.write(saved, AT))
	_assert_unchanged(saved, untouched, "write must not mutate its source snapshot")
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


func test_ulp_count_reads_the_sign_bit_and_source_checks_allow_no_slack() -> void:
	var tiny := _float_from_bits("0100000000000000")        # smallest positive subnormal
	var minus_tiny := _float_from_bits("0100000000000080")  # smallest negative subnormal
	var minus_zero := _float_from_bits("0000000000000080")
	assert_eq(_float_ulps(0.0, tiny), 1, "0.0 and the smallest subnormal share a sign bit, one unit apart")
	assert_eq(_float_ulps(minus_zero, minus_tiny), 1, "-0.0 and the smallest negative subnormal, one unit")
	assert_eq(_float_ulps(0.0, minus_tiny), FAR_ULPS, "opposite sign bits never count as near")
	var x := _float_from_bits("000000e07b3ca13f")
	var one_down := _float_from_bits("ffffffdf7b3ca13f")
	assert_eq(_float_ulps(-x, -one_down), 1, "negative neighbours count the same way")
	assert_eq(_float_ulps(INF, INF), 0, "the same infinity is an equal value, not a near one")
	assert_eq(_float_ulps(INF, -INF), FAR_ULPS)
	# A float32 cut of an ordinary value lands far outside the round-trip slack.
	var cut: float = PackedFloat32Array([0.1])[0]
	assert_true(_float_ulps(cut, 0.1) > 1000000, "float32 0.1 is %d units from float64 0.1" % _float_ulps(cut, 0.1))
	# The in-memory source checks (_assert_unchanged) pass slack 0: one unit before JSON still fails.
	assert_eq(_save_difference({"p": one_down}, {"p": x}), "", "round-trip comparison keeps one unit")
	var exact := _save_difference({"z": [{"p": one_down}]}, {"z": [{"p": x}]}, "save", 0)
	assert_true(exact.contains("save[z][0][p]") and exact.contains("float64"), "slack 0 names the key and bits: %s" % exact)


func test_exact_save_difference_rejects_nested_signed_zero_swaps() -> void:
	for zero_bits: String in ["0000000000000000", "0000000000000080"]:
		var other_bits := "0000000000000080" if zero_bits == "0000000000000000" else "0000000000000000"
		var expected_zero := _float_from_bits(zero_bits)
		var actual_zero := _float_from_bits(other_bits)
		var saved := {"outer": [{"value": expected_zero}]}
		var changed := {"outer": [{"value": actual_zero}]}
		assert_ne(_save_difference(actual_zero, expected_zero, "save", 0), "", "scalar zero sign is exact")
		var difference := _save_difference(changed, saved, "save", 0)
		assert_true(difference.contains("save[outer][0][value]"), "nested zero swap names its path")
		assert_true(difference.contains(zero_bits) and difference.contains(other_bits), "both zero patterns are reported")
		assert_ne(_save_difference([changed], [saved], "save", 0), "", "array-root comparison also visits leaves")


func test_exact_save_difference_accepts_identical_nan_bits() -> void:
	var first_nan := _float_from_bits("010000000000f87f")
	var same_nan := _float_from_bits("010000000000f87f")
	var other_nan := _float_from_bits("020000000000f87f")
	assert_true(is_nan(first_nan) and is_nan(same_nan) and is_nan(other_nan), "quiet NaN fixtures")
	assert_eq(_save_difference(first_nan, same_nan, "save", 0), "", "identical NaN bits are unchanged")
	assert_eq(_save_difference({"outer": [first_nan]}, {"outer": [same_nan]}, "save", 0), "",
		"nested identical NaN bits are unchanged")
	assert_ne(_save_difference({"outer": [first_nan]}, {"outer": [other_nan]}, "save", 0), "",
		"a different NaN payload is a bit change")


func test_json_save_difference_keeps_signed_zeros_equal() -> void:
	var positive_zero := _float_from_bits("0000000000000000")
	var negative_zero := _float_from_bits("0000000000000080")
	assert_eq(_save_difference({"outer": [positive_zero]}, {"outer": [negative_zero]}, "save", 1), "")
	assert_eq(_save_difference({"outer": [negative_zero]}, {"outer": [positive_zero]}, "save", 1), "")
	assert_eq(_float_ulps(positive_zero, negative_zero), 0, "JSON comparison keeps the two-zero policy")


func _codec_float_patterns() -> Array[String]:
	return [
		# Float64 immediately below, at and above the float32-exact anchors 1.0 and 0.5.
		"ffffffffffffef3f", "000000000000f03f", "010000000000f03f",
		"ffffffffffffdf3f", "000000000000e03f", "010000000000e03f",
		# The same neighbours around float32-exact 0.033664580434560776.
		"ffffffdf7b3ca13f", "000000e07b3ca13f", "010000e07b3ca13f",
		# Negative anchors and their two neighbours (in increasing magnitude order).
		"ffffffffffffefbf", "000000000000f0bf", "010000000000f0bf",
		"ffffffffffffdfbf", "000000000000e0bf", "010000000000e0bf",
		"ffffffdf7b3ca1bf", "000000e07b3ca1bf", "010000e07b3ca1bf",
		# Signed zeros, smallest subnormals and the positive normal/subnormal boundary.
		"0000000000000000", "0000000000000080", "0100000000000000", "0100000000000080",
		"ffffffffffff0f00", "0000000000001000", "0100000000001000",
		# The other four 11-07 samples; 000000e07b3ca13f is already included above.
		"9c04804ea755f43f", "000000607836ed3f", "00000020cd4d933f", "000000c091ffed3f",
	]


func _assert_float_pattern(actual: Variant, expected_bits: String, why: String) -> void:
	assert_true(actual is float, "%s: output remains a float" % why)
	if not actual is float:
		return
	assert_eq(_float_bytes(float(actual)).hex_encode(), expected_bits, why)


func test_encode_preserves_finite_float_bits_before_json() -> void:
	for sample_bits: String in _codec_float_patterns():
		var sample_value := _float_from_bits(sample_bits)
		assert_true(is_finite(sample_value), "finite codec fixture %s" % sample_bits)
		var encoded: Variant = FieldSave._encode(sample_value)
		_assert_float_pattern(encoded, sample_bits, "_encode output %s" % sample_bits)


func test_decode_preserves_finite_float_bits_before_json() -> void:
	for sample_bits: String in _codec_float_patterns():
		# Independent input: a compensating encode/decode pair cannot hide either stage's change.
		var sample_value := _float_from_bits(sample_bits)
		assert_true(is_finite(sample_value), "finite codec fixture %s" % sample_bits)
		var decoded: Variant = FieldSave.decode_checked(sample_value)
		_assert_float_pattern(decoded, sample_bits, "_decode output through decode_checked %s" % sample_bits)


func test_codec_nested_outputs_preserve_finite_float_bits() -> void:
	var samples: Array = []
	for sample_bits: String in _codec_float_patterns():
		samples.append(_float_from_bits(sample_bits))
	var source_payload := {"outer": [{"values": samples}]}
	var untouched: Dictionary = source_payload.duplicate(true)
	var encoded: Variant = FieldSave._encode(source_payload)
	assert_eq(_save_difference(encoded, untouched, "encoded", 0), "", "nested encode output keeps every bit")
	_assert_unchanged(source_payload, untouched, "nested encode input is unchanged")
	# Decode a fresh, unencoded fixture so output regressions cannot cancel each other.
	var decode_input: Dictionary = untouched.duplicate(true)
	var decoded: Variant = FieldSave.decode_checked(decode_input)
	assert_eq(_save_difference(decoded, untouched, "decoded", 0), "", "nested decode output keeps every bit")
	_assert_unchanged(decode_input, untouched, "nested decode input is unchanged")


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
		_assert_unchanged(saved, untouched, "source unchanged for seed %d" % seed_value)
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
		_assert_unchanged(saved, untouched, "full capture input unchanged, seed %d" % seed_value)
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


func _saved_person_row(saved: Dictionary, person_pid: String) -> Dictionary:
	for row: Dictionary in saved.get("people", []):
		if String(row.get("pid", "")) == person_pid:
			return row
	return {}


func _release_person_probe_games() -> void:
	# Each parameter case releases its own scenes before constructing the next one.
	while not fields.is_empty():
		var game = fields.pop_back()
		if is_instance_valid(game):
			game.free()


func _assert_bad_person_primary_uses_backup(bad_brain: Variant, why: String) -> void:
	var fixture := _file_fixture()
	var saved: Dictionary = fixture["save"]
	var source = fields.back()
	var person_pid := String(source.people[-1].pid)
	var primary: Dictionary = saved.duplicate(true)
	var person_row := _saved_person_row(primary, person_pid)
	assert_false(person_row.is_empty(), "%s: corrupt a real restored person's row" % why)
	if person_row.is_empty():
		return
	var wrote_backup := FieldSave.write(saved, AT)
	assert_true(wrote_backup, "%s: first valid save" % why)
	if not wrote_backup:
		return
	primary["clock"]["elapsed"] = float(primary["clock"]["elapsed"]) + 1.0
	var wrote_primary := FieldSave.write(primary, AT)
	assert_true(wrote_primary, "%s: rotate the valid backup" % why)
	if not wrote_primary:
		return
	var backup_bytes := FileAccess.get_file_as_bytes(AT + ".bak")
	var backup := FieldSave.from_json(backup_bytes.get_string_from_utf8())
	assert_false(backup.is_empty(), "%s: backup is valid before corruption" % why)
	if backup.is_empty():
		return
	_assert_saved_equal(backup, saved, "%s: backup holds the original save" % why)
	# The valid primary changes in only this restored person's brain.
	person_row["state"]["brain"] = bad_brain
	var broken_text := FieldSave.to_json(primary)
	var file := FileAccess.open(AT, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string(broken_text)
	file.close()
	var rejected := FieldSave.from_json(FileAccess.get_file_as_string(AT)).is_empty()
	assert_true(rejected, "%s: reject the primary before apply can change game state" % why)
	var reads_before: int = FieldSave._test_reads
	var loaded := FieldSave.read(AT)
	assert_eq(FieldSave._test_reads - reads_before, 2, "%s: read tries primary then backup" % why)
	var difference := _save_difference(loaded, backup)
	assert_true(difference.is_empty(), "%s: read selects backup\n%s" % [why, difference])
	assert_eq(FileAccess.get_file_as_bytes(AT + ".bak"), backup_bytes)
	# On the old product these assertions fail; never feed its malformed result to apply().
	if not rejected or not difference.is_empty():
		return
	_assert_file_resume_and_immediate_resave(loaded, fixture)
	var restored_person = FieldSave._person_with_id(fields.back(), person_pid)
	assert_not_null(restored_person, "%s: the selected person really restores" % why)
	if restored_person != null:
		assert_eq(int(restored_person.brain.get("rising_id", -1)), 53)
	assert_eq(FileAccess.get_file_as_bytes(AT + ".bak"), backup_bytes)
	assert_eq(FileAccess.get_file_as_string(AT + ".broken"), broken_text)


func test_bad_person_brain_primary_selects_backup_and_resumes() -> void:
	_assert_bad_person_primary_uses_backup(1, "brain is an integer")


func test_bad_rising_id_primary_selects_backup_and_resumes() -> void:
	for bad_id: Variant in [{}, "7", 7.5, 9007199254740994.0, -9007199254740994.0]:
		_assert_bad_person_primary_uses_backup({"rising_id": bad_id}, "invalid rising_id %s" % var_to_str(bad_id))
		_release_person_probe_games()
		await get_tree().process_frame


func _assert_person_link_acceptance(mode: String, exact_restore: bool) -> void:
	var fixture := _file_fixture()
	var saved: Dictionary = fixture["save"]
	var source = fields.back()
	var person_pid := String(source.people[-1].pid)
	var person_row := _saved_person_row(saved, person_pid)
	assert_false(person_row.is_empty(), "probe uses an actual captured person")
	if person_row.is_empty():
		return
	match mode:
		"integral_float":
			person_row["state"]["brain"]["rising_id"] = 7.0
		"missing_brain":
			person_row["state"].erase("brain")
		"missing_rising_id":
			person_row["state"]["brain"].erase("rising_id")
	if not exact_restore:
		saved["version"] = 1
		saved.erase("runtime")
	var untouched: Dictionary = saved.duplicate(true)
	var wrote := FieldSave.write(saved, AT)
	assert_true(wrote, "%s: accepted for exact=%s" % [mode, str(exact_restore)])
	if not wrote:
		return
	var loaded := FieldSave.read(AT)
	assert_false(loaded.is_empty(), "%s: accepted after the real JSON file" % mode)
	if loaded.is_empty():
		return
	assert_eq(FieldSave.exact(loaded), exact_restore)
	var loaded_person := _saved_person_row(loaded, person_pid)
	assert_false(loaded_person.is_empty())
	if loaded_person.is_empty():
		return
	if mode == "integral_float":
		var json_id: Variant = loaded_person["state"]["brain"]["rising_id"]
		assert_true(json_id is float, "the transport really delivers a JSON float")
		assert_eq(json_id, 7.0)
	elif mode == "missing_brain":
		assert_false(loaded_person["state"].has("brain"), "legacy missing brain remains absent")
	else:
		assert_false(loaded_person["state"]["brain"].has("rising_id"), "legacy missing link remains absent")
	var game = _game(FieldSave.resume_opts(loaded), false)
	var restored_person = FieldSave._person_with_id(game, person_pid)
	assert_not_null(restored_person, "the accepted row is restored by pid")
	if restored_person == null:
		return
	if mode == "integral_float":
		assert_eq(int(restored_person.brain.get("rising_id", -1)), 7)
	else:
		assert_false(restored_person.brain.has("rising_id"))
	var expected_seven: int = 0 if mode == "integral_float" else int(api.call("look_code_for", int(fixture["seed"]), 7))
	assert_eq(int(game.zombies.find(7).get("look_code", -1)), expected_seven,
		"migration maps JSON 7.0 to integer zombie id 7 only when the link exists")
	assert_eq(int(game.zombies.find(53).get("look_code", -1)), int(api.call("look_code_for", int(fixture["seed"]), 53)),
		"the old 53 link is absent, so its unnamed row gets an ordinary look")
	_assert_unchanged(saved, untouched, "acceptance and restoration leave the source unchanged")


func test_integral_json_rising_id_is_accepted_and_migrates() -> void:
	for exact_restore: bool in [true, false]:
		_assert_person_link_acceptance("integral_float", exact_restore)
		_release_person_probe_games()
		await get_tree().process_frame


func test_legacy_person_without_brain_is_accepted() -> void:
	for exact_restore: bool in [true, false]:
		_assert_person_link_acceptance("missing_brain", exact_restore)
		_release_person_probe_games()
		await get_tree().process_frame


func test_legacy_person_without_rising_id_is_accepted() -> void:
	for exact_restore: bool in [true, false]:
		_assert_person_link_acceptance("missing_rising_id", exact_restore)
		_release_person_probe_games()
		await get_tree().process_frame


func test_person_brain_guard_checks_types_and_integer_boundaries() -> void:
	var save_api: GDScript = FieldSave
	var has_guard := save_api.has_method("_person_brain_ok")
	assert_true(has_guard, "person brain acceptance has a pure guard")
	if not has_guard:
		return  # Old product fails the assertion without calling a missing method.
	for legacy_row: Dictionary in [{}, {"state": {}}, {"state": {"brain": {}}}]:
		assert_true(save_api.call("_person_brain_ok", legacy_row), "absent legacy keys are allowed")
	# Typed int64 values do not go through JSON's untyped float range restriction.
	for good_id: Variant in [0, -7, 9007199254740993, -9007199254740993,
			9223372036854775807, -9223372036854775807 - 1,
			0.0, -0.0, 7.0, -7.0, 9007199254740991.0, -9007199254740991.0,
			9007199254740992.0, -9007199254740992.0]:
		assert_true(save_api.call("_person_brain_ok", {"state": {"brain": {"rising_id": good_id}}}),
			"whole safe JSON float or typed integer %s" % var_to_str(good_id))
	for bad_brain: Variant in [1, 1.0, "brain", [], null, true]:
		assert_false(save_api.call("_person_brain_ok", {"state": {"brain": bad_brain}}),
			"a present brain must be a dictionary")
	for bad_id: Variant in [{}, [], "7", 7.5, -7.5, true, false, null, NAN, INF, -INF,
			9007199254740994.0, -9007199254740994.0, 1.0e308]:
		assert_false(save_api.call("_person_brain_ok", {"state": {"brain": {"rising_id": bad_id}}}),
			"invalid rising_id %s" % var_to_str(bad_id))
	assert_false(save_api.call("_person_brain_ok", {"state": 1}), "invalid state cannot reach brain")
	var row := {"state": {"brain": {"rising_id": 7.0, "unrelated": {"keep": [1, null]}}}}
	var untouched: Dictionary = row.duplicate(true)
	assert_true(save_api.call("_person_brain_ok", row), "other brain fields are outside this guard")
	_assert_unchanged(row, untouched, "pure acceptance does not rewrite its input")

