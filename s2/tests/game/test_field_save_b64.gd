extends "res://addons/gut/test.gd"
## Field save format 3: byte and int32 runs as one base64 line each (the grids' cells and the
## sight memory were a typed object a number), the old forms still read, and one home press
## (focus-out, then pause) writes the slot once.

const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const SliceSave = preload("res://game/sim/slice_save.gd")

static var DIR: String = "user://test_field_save_b64_%d" % OS.get_process_id()
static var AT: String = DIR + "/field_save.json"
static var SLICE_AT: String = DIR + "/slice.json"


func before_each() -> void:
	FieldSave._test_fail_step = ""
	DirAccess.make_dir_recursive_absolute(DIR)
	FieldSave.clear(AT)


func after_each() -> void:
	FieldSave.clear(AT)
	SliceSave.clear(SLICE_AT)


func after_all() -> void:
	DirAccess.remove_absolute(DIR)


## The default stop as a plain start makes it, with the slot on.
func _game(extra: Dictionary = {}):
	var game = FieldGame.new()
	var opts := {"seed": 1, "auto_pause": false, "field_save": true, "field_save_path": AT}
	opts.merge(extra, true)
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	game.set_physics_process(false)
	return game


## Format 2's way with a packed run: the run as a list, each number a typed int.
static func _old_encode(v: Variant) -> Variant:
	if v is PackedByteArray or v is PackedInt32Array:
		var values: Array = []
		for n: int in v:
			values.append({"$type": "int", "value": str(n)})
		return {"$type": type_string(typeof(v)), "value": values}
	if v is Dictionary:
		var out: Dictionary = {}
		for key: Variant in v:
			out[key] = _old_encode(v[key])
		return out
	if v is Array:
		var out: Array = []
		for e: Variant in v:
			out.append(_old_encode(e))
		return out
	return v


## A whole save as format 2 wrote it.
static func _old_text(save: Dictionary) -> String:
	var old: Dictionary = save.duplicate(true)
	old["version"] = 2
	var encoded: Dictionary = FieldSave._encode(_old_encode(old))
	encoded["version"] = 2
	return JSON.stringify(encoded, "", false, true)


func _round_trip(v: Variant) -> Variant:
	var text: String = JSON.stringify(FieldSave._encode(v), "", false, true)
	return FieldSave._decode(JSON.parse_string(text))


func test_every_packed_run_comes_back_the_same_and_typed() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var bytes := PackedByteArray()
	for i: int in 4099:
		bytes.append(rng.randi_range(0, 255))
	var ints := PackedInt32Array([0, 1, -1, 2147483647, -2147483648, 65536])
	for i: int in 1001:
		ints.append(rng.randi_range(-2147483648, 2147483647))
	var cases: Array = [
		PackedByteArray(), PackedByteArray([0]), PackedByteArray([255, 1]), PackedByteArray([7, 8, 9]), bytes,
		PackedInt32Array(), PackedInt32Array([-5]), ints,
		PackedVector3Array([Vector3(1.5, -2, 3)]), PackedStringArray(["", "눈", "a"]),
	]
	for v: Variant in cases:
		var back: Variant = _round_trip(v)
		assert_eq(typeof(back), typeof(v), "%s keeps its type" % type_string(typeof(v)))
		assert_eq(back, v, "%s of %d comes back the same" % [type_string(typeof(v)), v.size()])
	var nested: Dictionary = {"levels": {0: {"solid": bytes}, -1: {"solid": PackedByteArray([3])}}, "runs": [ints, bytes]}
	assert_eq(_round_trip(nested), nested, "inside maps and lists too")


func test_a_byte_run_is_one_base64_line() -> void:
	var run := PackedByteArray()
	run.resize(24650)
	run.fill(1)
	var encoded: Dictionary = FieldSave._encode(run)
	assert_eq(encoded.keys(), ["$type", "base64"])
	assert_eq(encoded["base64"], Marshalls.raw_to_base64(run))
	var text: String = JSON.stringify(encoded)
	assert_lt(text.length(), 33000, "about 4/3 of a byte a cell, not an object a cell")
	assert_eq(text.find("\"int\""), -1)


func test_format_two_saves_still_read() -> void:
	var game = _game()
	var save: Dictionary = FieldSave.capture(game)
	assert_eq(int(save["version"]), 3)
	var old_text: String = _old_text(save)
	assert_gt(old_text.find("\"PackedByteArray\",\"value\""), -1, "the old form is what it was")
	var back: Dictionary = FieldSave.from_json(old_text)
	assert_false(back.is_empty(), "a format 2 save is still a whole save")
	assert_eq(int(back.get("version", 0)), 2)
	back["version"] = 3
	assert_eq(back, FieldSave.from_json(FieldSave.to_json(save)), "and reads as the same field")
	var levels: Dictionary = back["runtime"]["levels"]
	for key: Variant in levels:
		assert_true(levels[key]["solid"] is PackedByteArray)
	assert_true(back["runtime"]["game"]["seen_memory"] is PackedByteArray)


func test_a_field_save_is_whole_and_small() -> void:
	var game = _game()
	var save: Dictionary = FieldSave.capture(game)
	var text: String = FieldSave.to_json(save)
	var old_text: String = _old_text(save)
	var back: Dictionary = FieldSave.from_json(text)
	assert_eq(back, FieldSave.from_json(old_text).merged({"version": 3}, true), "the same save either way")
	gut.p("default stop save: %d B as format 3, %d B the old way" % [text.to_utf8_buffer().size(), old_text.to_utf8_buffer().size()])
	assert_lt(text.to_utf8_buffer().size(), 500000, "the default stop's save stays under 500 KB")
	assert_lt(text.to_utf8_buffer().size() * 8, old_text.to_utf8_buffer().size(), "an eighth of the old form or less")
	assert_true(FieldSave.write(save, AT))
	assert_eq(FieldSave.read(AT), back)


func test_a_broken_base64_run_is_not_a_whole_save() -> void:
	var game = _game()
	var text: String = FieldSave.to_json(FieldSave.capture(game))
	var parsed: Dictionary = JSON.parse_string(text)
	var memory: Dictionary = parsed["runtime"]["game"]["seen_memory"]
	assert_true(memory.has("base64"))
	var good: String = memory["base64"]
	assert_gt(good.length(), 8, "the field has seen something")
	for bad: Variant in ["@@@@", good.substr(1), good + "=", 12, good.substr(0, good.length() - 4) + "AAA\n", "AA=A"]:
		memory["base64"] = bad
		assert_eq(FieldSave.from_json(JSON.stringify(parsed, "", false, true)), {}, "%s is not a save" % str(bad).right(8).c_escape())
	memory["base64"] = good
	for extra: Array in [["extra", 0], ["value", []]]:
		memory[extra[0]] = extra[1]
		assert_eq(FieldSave.from_json(JSON.stringify(parsed, "", false, true)), {}, "a packed tag with %s beside it is not a save" % extra[0])
		memory.erase(extra[0])
	assert_false(FieldSave.from_json(JSON.stringify(parsed, "", false, true)).is_empty(), "the good line still is")
	var ints: Dictionary = FieldSave._encode(PackedInt32Array([1, 2]))
	ints["base64"] = Marshalls.raw_to_base64(PackedByteArray([1, 2, 3]))
	FieldSave._decode_bad = false
	assert_null(FieldSave._decode(ints), "an int32 run cut between numbers")
	assert_true(FieldSave._decode_bad)
	FieldSave._decode_bad = false


func test_one_home_press_writes_the_slot_once() -> void:
	var game = _game()
	game.interrupt()
	assert_true(FileAccess.file_exists(AT), "the first notice writes the slot")
	FieldSave.clear(AT)
	game.interrupt()
	assert_false(FileAccess.file_exists(AT), "the second notice of the same press writes nothing")
	game.welcome_back()
	game.interrupt()
	assert_true(FileAccess.file_exists(AT), "back and away again writes again")


func test_a_failed_write_while_away_is_tried_again() -> void:
	var game = _game()
	FieldSave._test_fail_step = "write_error"
	game.interrupt()
	assert_false(FileAccess.file_exists(AT))
	assert_true(game.away)
	game.interrupt()
	assert_true(FileAccess.file_exists(AT), "the second notice writes what the first could not")


func test_a_slice_slot_with_a_broken_packed_run_reads_the_one_before() -> void:
	var good: Dictionary = {"version": SliceSave.VERSION, "kind": SliceSave.KIND, "step": "train", "run": "run_b64",
		"train_sha": "sha", "seg": 1, "applied": [], "contract": {"note": "a"}, "receipt": {}, "passed": false, "result_reason": ""}
	assert_true(SliceSave.write(good, SLICE_AT))
	assert_true(DirAccess.copy_absolute(SLICE_AT, SLICE_AT + ".bak") == OK)
	var text: String = FileAccess.get_file_as_string(SLICE_AT)
	assert_gt(text.find("\"note\":\"a\""), -1)
	var file: FileAccess = FileAccess.open(SLICE_AT, FileAccess.WRITE)
	file.store_string(text.replace("\"note\":\"a\"", "\"note\":{\"$type\":\"PackedInt32Array\",\"base64\":\"AQID\"}"))
	file.close()
	assert_eq(SliceSave._parse(SLICE_AT), {}, "a slot with an int32 run cut between numbers is a broken file")
	assert_eq(SliceSave.read(SLICE_AT)["contract"], {"note": "a"}, "and the one before it is read")


func test_an_ended_stop_also_writes_once_a_press() -> void:
	var game = _game()
	game.receipt.set_end("departed")
	game.ended = true
	game.interrupt()
	assert_true(FileAccess.file_exists(AT))
	FieldSave.clear(AT)
	game.interrupt()
	assert_false(FileAccess.file_exists(AT), "the second notice writes nothing")
	game.welcome_back()
	game.interrupt()
	assert_true(FileAccess.file_exists(AT), "back and away again writes again")


func test_away_again_after_play_writes_what_came_since() -> void:
	var game = _game()
	game.interrupt()
	var first: Dictionary = FieldSave.read(AT)
	game.welcome_back()
	for i: int in 10:
		game._step(0.1)
	game.interrupt()
	var second: Dictionary = FieldSave.read(AT)
	assert_gt(float(second["clock"]["elapsed"]), float(first["clock"]["elapsed"]), "the second save is the stop as it is now")
