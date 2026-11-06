extends "res://addons/gut/test.gd"
## Exercise apply(), not just the migration helper. No save files are written.

const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const DeadCast = preload("res://game/actors/dead_cast.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")
var api: GDScript = DeadCast
var fields: Array = []


func before_each() -> void:
	assert_true(api.has_method("look_code_for"), "required DeadCast method")


func after_each() -> void:
	for game in fields:
		if is_instance_valid(game):
			game.free()
	fields.clear()
	await get_tree().process_frame


func _game():
	var game = FieldGame.new()
	game.opts = {"seed": 831, "raiders": false, "auto_pause": false, "arrive": false,
		"receipt_id": "dead_look_p0"}
	game.map_script = BareLine
	add_child(game)
	game.set_process(false)
	assert_true(game.zombies.has_method("look_code_of"), "required draw/migration method")
	game.zombies.list.clear()
	game.pending_spawn.clear()
	fields.append(game)
	return game


func _saved(game) -> Dictionary:
	return FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))


func _fixture() -> Dictionary:
	var game = _game()
	for id: int in [7, 17, 23, 31, 37]:
		var z: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(4, 0, 0))
		z["id"] = id
		z["name"] = "일어난 사람" if id in [17, 31] else ""
		z["worn"] = {}
		if id == 7:
			z["look_code"] = 95
		elif id == 17:
			z["look_code"] = 0
		elif id == 37:
			z["look_code"] = 511   # valid transport, an unassigned outfit
		else:
			z.erase("look_code")
	game.zombies.next_id = 38
	for _i: int in 7:
		game.rng.randi()
	return _saved(game)


func _assert_restored(game) -> void:
	assert_eq(game.zombies.list.size(), 5)
	for id: int in [7, 17, 23, 31, 37]:
		var z: Dictionary = game.zombies.find(id)
		assert_false(z.is_empty(), "saved identity %d survives temporary next_id" % id)
		assert_true(z.has("look_code"), "look is persistent before any later render/save")
		if not z.has("look_code"):
			continue
		var expected: int = 95 if id == 7 else (511 if id == 37 else 0)
		if id == 23:
			expected = int(api.call("look_code_for", 831, id))
			assert_gt(expected, 7, "only the missing unnamed row receives a common outfit")
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
	assert_eq(game.zombies.next_id, 38)
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
