extends "res://addons/gut/test.gd"
## The save codec reads back only what its encoder writes (save owner, step 1): a typed int is
## the encoder's decimal text inside signed 64 bits, a typed float is "inf" or "-inf", a vector,
## colour, rect, map or packed run has its exact shape. Anything else marks the whole file
## broken, so a slot's .bak is read instead of a guessed value.
## test_fail_* fail on the codec before this change; test_keep_* hold before and after.

const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const SliceSave = preload("res://game/sim/slice_save.gd")
const TrainSave = preload("res://game/politics/save_slot.gd")
const TrainDom = preload("res://game/train/train_dom.gd")
const SliceFlow = preload("res://game/slice_flow.gd")

static var DIR: String = "user://test_save_codec_%d" % OS.get_process_id()
static var FIELD_AT: String = DIR + "/field_save.json"
static var SLICE_AT: String = DIR + "/slice.json"
static var TRAIN_AT: String = DIR + "/train.json"

## Not the encoder's int text: each must read as a broken file, never as a number.
const BAD_INT_TEXTS: Array[String] = [
	"", "x", "1.5", "1e3", "+7", "007", "00", "-0", "-007", "-", "+", "--1", "1-", " 7", "7 ", "12\n", "0x10", "１２",
	"9223372036854775808", "-9223372036854775809", "99999999999999999999",
]
## Not text (JSON gives every number as a float, and no format wrote a number in an int tag).
const BAD_INT_VALUES: Array = [7.0, 7, null, true, [], {}]


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_clear()


func after_each() -> void:
	_clear()


func after_all() -> void:
	DirAccess.remove_absolute(DIR)


func _clear() -> void:
	FieldSave.clear(FIELD_AT)
	SliceSave.clear(SLICE_AT)
	SliceSave.clear(TRAIN_AT)


static func _tag(type: String, value: Variant) -> Dictionary:
	return {"$type": type, "value": value}


static func _decoded(v: Variant) -> Variant:
	return FieldSave.decode_checked(v)


## The value through the encoder, JSON text and back, as a slot holds it. A file that does not
## read at all is told apart from one that reads a null.
func _round_trip(v: Variant) -> Variant:
	var text: String = JSON.stringify(FieldSave._encode({"v": v}), "", false, true)
	var back: Variant = FieldSave.decode_checked(JSON.parse_string(text))
	assert_true(back is Dictionary and (back as Dictionary).has("v"), "%s reads at all" % var_to_str(v))
	return back["v"] if back is Dictionary else "<not read>"


## A slot's JSON with one top key swapped: still good JSON, and a shape its reader accepts
## once the swapped value is forced to a number.
static func _with(text: String, key: String, value: Variant) -> String:
	var parsed: Dictionary = JSON.parse_string(text)
	parsed[key] = value
	return JSON.stringify(parsed, "", false, true)


static func _write_text(at: String, text: String) -> void:
	var file := FileAccess.open(at, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## The field slot as the default stop captures it (test_field_save_b64.gd's way).
func _field_save() -> Dictionary:
	var game = FieldGame.new()
	game.opts = {"seed": 1, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.set_physics_process(false)
	return FieldSave.capture(game)


static func _slice_save(note: String) -> Dictionary:
	return {
		"version": SliceSave.VERSION, "kind": SliceSave.KIND, "step": "train", "run": "r", "train_sha": "",
		"seg": 0, "applied": [], "contract": {"note": note}, "receipt": {}, "passed": false, "result_reason": "",
	}


## [the S1 board a new run starts on, its table], as test_field_save_b64.gd builds it.
static func _train_board() -> Array:
	var board: Array = SliceFlow.start_board()
	var g: Dictionary = (board[0] as Dictionary).duplicate(true)
	if g.get("dom") == null:
		g["dom"] = TrainDom.start()
	TrainDom.ensure(g)
	TrainSave.fill_defaults(g)
	return [g, board[1]]


## The encoder writes an infinite vector component as 1e99999, and Godot reads that back as inf
## with a warning (built_in_strtod "Exponent too high") that GUT counts as an engine error:
## expected here, one for each infinite component read, and no other.
func _expect_inf_warnings(count: int) -> void:
	var seen: int = 0
	for tracked: Variant in get_errors():
		if tracked.is_engine_error() and tracked.contains_text("Exponent too high"):
			tracked.handled = true
			seen += 1
	assert_eq(seen, count, "one Exponent too high warning for each infinite component read")


## Format 2's packed run: a list of typed ints (test_field_save_b64.gd _old_encode).
static func _old_run(v: Variant) -> Dictionary:
	var values: Array = []
	for n: int in v:
		values.append({"$type": "int", "value": str(n)})
	return {"$type": type_string(typeof(v)), "value": values}


# ---------------------------------------------------------------- the codec (fail before)

func test_fail_an_int_tag_that_is_not_the_encoders_text_breaks_the_file() -> void:
	for text: String in BAD_INT_TEXTS:
		assert_null(_decoded({"n": _tag("int", text)}), "int text %s" % JSON.stringify(text))
	for value: Variant in BAD_INT_VALUES:
		assert_null(_decoded({"n": _tag("int", value)}), "int value %s" % JSON.stringify(value))


func test_fail_a_float_tag_is_inf_or_minus_inf_only() -> void:
	for value: Variant in ["nan", "INF", "Infinity", "", "1.5", 1.0, null]:
		assert_null(_decoded({"f": _tag("float", value)}), "float value %s" % JSON.stringify(value))


func test_fail_a_vector_colour_or_rect_of_the_wrong_shape_breaks_the_file() -> void:
	var cases: Array = [
		_tag("Vector3", [1.0, 2.0]), _tag("Vector3", [1.0, 2.0, 3.0, 4.0]), _tag("Vector3", [1.0, "x", 3.0]),
		_tag("Vector3", "abc"), _tag("Vector3", null), _tag("Vector3", [1.0, 2.0, _tag("int", "3")]),
		_tag("Vector2", [1.0]), _tag("Color", [1.0, 1.0, 1.0]), _tag("Color", [1.0, 1.0, 1.0, true]),
		_tag("Vector2i", [1.5, 0.0]), _tag("Vector2i", [2147483648.0, 0.0]), _tag("Vector2i", ["1", 0.0]),
		_tag("Vector2i", [INF, 0.0]), _tag("Rect2i", [0.0, 0.0, 1.0]), _tag("Rect2i", [0.0, 0.0, 1.0, -2147483649.0]),
	]
	for tag: Dictionary in cases:
		assert_null(_decoded({"at": tag}), JSON.stringify(tag))


func test_fail_a_typed_map_or_run_of_the_wrong_shape_breaks_the_file() -> void:
	var cases: Array = [
		_tag("Dictionary", "x"), _tag("Dictionary", [1.0]), _tag("Dictionary", [[_tag("int", "1")]]),
		_tag("Dictionary", [[_tag("int", "1"), "a", "b"]]), _tag("Dictionary", [[_tag("int", "x"), "a"]]),
		_tag("PackedStringArray", [1.0]), _tag("PackedStringArray", "ab"),
		_tag("PackedVector3Array", [[1.0, 2.0, 3.0]]), _tag("PackedVector3Array", "x"),
		_tag("PackedByteArray", [_tag("int", "256")]), _tag("PackedByteArray", [_tag("int", "-1")]),
		_tag("PackedByteArray", [7.0]), _tag("PackedInt32Array", [_tag("int", "2147483648")]),
		_tag("PackedInt32Array", [_tag("int", "-2147483649")]), _tag("PackedInt32Array", "x"),
	]
	for tag: Dictionary in cases:
		assert_null(_decoded({"run": tag}), JSON.stringify(tag))


## The encoder walks a map's keys once: a key twice would drop the value before it.
func test_fail_a_typed_map_with_a_repeated_key_breaks_the_file() -> void:
	var one: Dictionary = _tag("int", "1")
	assert_null(_decoded({"m": _tag("Dictionary", [[one, "A"], [one, "B"]])}), "the second 1 would drop A")


## No game state has a "$type" key (saves of format 1 to 3 and the game's data), so every such
## map in a slot is a tag, and one that is not whole is a broken file.
func test_fail_an_unknown_or_unfinished_tag_breaks_the_file() -> void:
	assert_null(_decoded({"x": _tag("Transform3D", [1.0])}), "a type the encoder never writes")
	assert_null(_decoded({"x": {"$type": "int", "value": "5", "more": 1.0}}), "a tag with another key")
	assert_null(_decoded({"x": {"$type": "int"}}), "a tag with no value")
	assert_null(_decoded({"x": {"$type": "PackedByteArray"}}), "a packed tag with no run")
	assert_null(_decoded({"x": {"$type": 5.0, "value": "1"}}), "a type that is not text")


## A child that does not read stops its parent before the parent builds anything from it (a
## packed run, a map, a list, the dig parts' clean-up). No engine error on the way: GUT fails a
## test on one by default (failure_error_types).
func test_fail_a_broken_child_stops_every_kind_of_parent() -> void:
	var bad_int: Dictionary = _tag("int", "x")
	var short: Dictionary = _tag("Vector3", [1.0, 2.0])
	var cases: Array = [
		_tag("PackedByteArray", [bad_int]), _tag("PackedInt32Array", [bad_int]),
		_tag("PackedVector3Array", [short]), _tag("PackedStringArray", [bad_int]),
		_tag("Dictionary", [[bad_int, "a"]]), _tag("Dictionary", [[_tag("int", "1"), bad_int]]),
		_tag("Dictionary", [[_tag("int", "1"), short]]),
		[1.0, bad_int, 3.0], {"a": {"b": short}}, {"dig_parts": [bad_int], "dig_wagon": 0.0},
	]
	for v: Variant in cases:
		assert_null(_decoded({"x": v}), JSON.stringify(v))


## Proposal E: format 1 wrote a place as a bare [x, y, z] (field_save.gd VEC_KEYS).
func test_fail_a_format_one_place_that_is_not_three_numbers_breaks_the_file() -> void:
	assert_null(_decoded({"pos": [1.0, "x", 3.0]}))
	assert_null(_decoded({"home": [_tag("int", "1"), 2.0, 3.0]}))


# ---------------------------------------------------------------- the three entrances (fail before)

func test_fail_each_decode_entrance_refuses_a_bad_int_tag() -> void:
	var field_text: String = FieldSave.to_json(_field_save())
	assert_false(FieldSave.from_json(field_text).is_empty(), "the field slot as written reads")
	assert_true(FieldSave.from_json(_with(field_text, "seed", _tag("int", "x"))).is_empty(), "field: seed as x")
	var slice_text: String = SliceSave._text(_slice_save("main"))
	_write_text(SLICE_AT, slice_text)
	assert_false(SliceSave._parse(SLICE_AT).is_empty(), "the slice slot as written reads")
	_write_text(SLICE_AT, _with(slice_text, "seg", _tag("int", "x")))
	assert_eq(SliceSave._parse(SLICE_AT), {}, "slice: seg as x")
	var board: Array = _train_board()
	assert_true(SliceSave.write_train(board[0], TRAIN_AT))
	assert_not_null(TrainSave.load_slot(board[1], TRAIN_AT, TRAIN_AT + ".broken")["g"], "the train slot as written loads")
	_write_text(TRAIN_AT, _with(FileAccess.get_file_as_string(TRAIN_AT), "seg", _tag("int", "x")))
	assert_null(TrainSave.load_slot(board[1], TRAIN_AT, TRAIN_AT + ".broken")["g"], "train: seg as x")


# ---------------------------------------------------------------- the game's reads (fail before)

func test_fail_the_field_slot_reads_its_backup_over_a_bad_int_tag() -> void:
	var save: Dictionary = _field_save()
	var good: Dictionary = save.duplicate(true)
	good["seed"] = 2
	_write_text(FIELD_AT + ".bak", FieldSave.to_json(good))
	_write_text(FIELD_AT, _with(FieldSave.to_json(save), "seed", _tag("int", "x")))
	assert_eq(int(FieldSave.read(FIELD_AT).get("seed", -1)), 2, "the backup, not seed 0 forced from x")


## Before: an index past the end inside _decode (an engine error, which fails a GUT test).
func test_fail_the_field_slot_reads_its_backup_over_a_short_vector() -> void:
	var save: Dictionary = _field_save()
	assert_false((save.get("people", []) as Array).is_empty(), "the default stop has someone to place")
	var good: Dictionary = save.duplicate(true)
	good["seed"] = 2
	_write_text(FIELD_AT + ".bak", FieldSave.to_json(good))
	var parsed: Dictionary = JSON.parse_string(FieldSave.to_json(save))
	parsed["people"][0]["pos"] = _tag("Vector3", [1.0, 2.0])
	_write_text(FIELD_AT, JSON.stringify(parsed, "", false, true))
	assert_eq(int(FieldSave.read(FIELD_AT).get("seed", -1)), 2, "the backup")


func test_fail_the_slice_slot_reads_its_backup_over_a_bad_int_tag() -> void:
	_write_text(SLICE_AT + ".bak", SliceSave._text(_slice_save("backup")))
	_write_text(SLICE_AT, _with(SliceSave._text(_slice_save("main")), "seg", _tag("int", "x")))
	assert_eq(SliceSave.read(SLICE_AT).get("contract"), {"note": "backup"})


func test_fail_the_train_slot_reads_its_backup_over_a_bad_int_tag() -> void:
	var board: Array = _train_board()
	assert_true(SliceSave.write_train(board[0], TRAIN_AT))
	var good_text: String = FileAccess.get_file_as_string(TRAIN_AT)
	_write_text(TRAIN_AT + ".bak", good_text)
	_write_text(TRAIN_AT, _with(good_text, "seg", _tag("int", "x")))
	var source: Dictionary = {}
	assert_false(SliceSave._train(TRAIN_AT, board[1], source).is_empty())
	assert_eq(source.get("train_sha"), good_text.sha256_text(), "the backup's text is the one read")


# ---------------------------------------------------------------- proposal: the writers' previous slot (fail before)

func test_fail_a_field_write_keeps_a_good_backup_over_a_previous_slot_with_a_bad_int_tag() -> void:
	var save: Dictionary = _field_save()
	var backup_text: String = FieldSave.to_json(save)
	_write_text(FIELD_AT + ".bak", backup_text)
	_write_text(FIELD_AT, _with(backup_text, "seed", _tag("int", "x")))
	assert_true(FieldSave.write(save, FIELD_AT))
	assert_eq(FileAccess.get_file_as_string(FIELD_AT + ".bak"), backup_text, "the good backup is kept")
	assert_true(FileAccess.file_exists(FIELD_AT + ".broken"), "the bad slot is set aside")


func test_fail_a_slice_write_keeps_a_good_backup_over_a_previous_slot_with_a_bad_int_tag() -> void:
	var backup_text: String = SliceSave._text(_slice_save("backup"))
	_write_text(SLICE_AT + ".bak", backup_text)
	_write_text(SLICE_AT, _with(SliceSave._text(_slice_save("main")), "seg", _tag("int", "x")))
	assert_true(SliceSave.write(_slice_save("new"), SLICE_AT))
	assert_eq(FileAccess.get_file_as_string(SLICE_AT + ".bak"), backup_text, "the good backup is kept")
	assert_true(FileAccess.file_exists(SLICE_AT + ".broken"), "the bad slot is set aside")


func test_fail_a_train_write_keeps_a_good_backup_over_a_previous_slot_with_a_bad_int_tag() -> void:
	var board: Array = _train_board()
	assert_true(SliceSave.write_train(board[0], TRAIN_AT))
	var backup_text: String = FileAccess.get_file_as_string(TRAIN_AT)
	_write_text(TRAIN_AT + ".bak", backup_text)
	_write_text(TRAIN_AT, _with(backup_text, "seg", _tag("int", "x")))
	assert_true(SliceSave.write_train(board[0], TRAIN_AT))
	assert_eq(FileAccess.get_file_as_string(TRAIN_AT + ".bak"), backup_text, "the good backup is kept")
	assert_true(FileAccess.file_exists(TRAIN_AT + ".broken"), "the bad slot is set aside")


# ---------------------------------------------------------------- kept (pass before and after)

func test_keep_every_value_the_encoder_writes_comes_back_the_same_and_typed() -> void:
	var cases: Array = [
		0, -1, 7, 9223372036854775807, -9223372036854775807 - 1, 9007199254740993,
		1.5, -0.25, 0.1, INF, -INF,
		Vector3(1.5, -2.0, 3.0), Vector3.INF, Vector2(0.5, -1.0), Vector2i(-2147483648, 2147483647),
		Rect2i(-1, 2, 30, 40), Color(0.1, 0.2, 0.3, 0.4),
		PackedByteArray([0, 255]), PackedInt32Array([-2147483648, 2147483647]),
		PackedVector3Array([Vector3(1, 2, 3), Vector3.INF]), PackedStringArray(["", "눈", "a"]),
		{0: "a", -1: [1, 2.5], "k": {"n": 3}}, [1, [2, [3]]], "", "글", true, false, null,
		[null, 1], {"a": null}, {null: 1, 2: null},
	]
	for v: Variant in cases:
		var back: Variant = _round_trip(v)
		assert_eq(typeof(back), typeof(v), "%s keeps its type" % var_to_str(v))
		# var_to_str tells 1 from 1.0 at every depth, where == does not.
		assert_eq(var_to_str(back), var_to_str(v), "%s comes back the same" % var_to_str(v))
	assert_eq(_round_trip(NAN), -INF, "NaN is written as -inf (the encoder's way, kept)")
	_expect_inf_warnings(6)  # Vector3.INF and the one in the PackedVector3Array


## A stop with no train door keeps Vector3.INF as the door to climb in by (field_ai.gd _board_door).
func test_keep_a_saved_person_with_no_door_to_board_by() -> void:
	var save: Dictionary = _field_save()
	save["people"][0]["state"] = {"brain": {"board_door": Vector3.INF}}
	var back: Variant = _decoded(JSON.parse_string(FieldSave.to_json(save)))
	assert_eq(back["people"][0]["state"]["brain"]["board_door"], Vector3.INF)
	_expect_inf_warnings(3)


## Every bare number list takes an infinite component, as Vector3 does: Vector2, Color and
## format 1's places.
func test_keep_infinite_components_in_every_number_list() -> void:
	for v: Variant in [Vector2(INF, -INF), Color(INF, 0.0, -INF, 1.0)]:
		assert_eq(var_to_str(_round_trip(v)), var_to_str(v))
	var back: Variant = _decoded(JSON.parse_string("{\"pos\": [1e99999, 0, -1e99999], \"home\": [0, 1e99999, 0]}"))
	assert_eq(back["pos"], Vector3(INF, 0, -INF))
	assert_eq(back["home"], Vector3(0, INF, 0))
	_expect_inf_warnings(7)


## What already read as broken still does, with no engine error, and the next read starts clean.
func test_keep_a_broken_run_still_breaks_the_file_and_the_next_read_is_clean() -> void:
	var cut: Dictionary = {"$type": "PackedInt32Array", "base64": "AQID"}
	var cases: Array = [
		cut, [1.0, cut], {"a": {"b": cut}}, _tag("Dictionary", [[_tag("int", "1"), cut]]),
		{"$type": "Vector3", "base64": "AAAA"}, {"$type": "PackedByteArray", "value": [], "base64": ""},
	]
	for v: Variant in cases:
		assert_null(_decoded({"x": v}), JSON.stringify(v))
		assert_eq(_decoded({"x": _tag("int", "7")}), {"x": 7}, "a good save read right after")


func test_keep_the_int64_edges_and_past_two_to_the_53rd_read_exactly() -> void:
	assert_eq(_decoded(_tag("int", "9223372036854775807")), 9223372036854775807)
	assert_eq(_decoded(_tag("int", "-9223372036854775808")), -9223372036854775807 - 1)
	assert_eq(_decoded(_tag("int", "9007199254740993")), 9007199254740993)
	assert_eq(_decoded(_tag("int", "0")), 0)
	assert_eq(_decoded(_tag("int", "-1")), -1)


func test_keep_format_two_packed_runs_still_read() -> void:
	var bytes := PackedByteArray([0, 1, 255])
	var ints := PackedInt32Array([-2147483648, 0, 2147483647])
	var text: String = JSON.stringify({"b": _old_run(bytes), "i": _old_run(ints)}, "", false, true)
	var back: Variant = _decoded(JSON.parse_string(text))
	assert_eq(typeof(back["b"]), TYPE_PACKED_BYTE_ARRAY)
	assert_eq(typeof(back["i"]), TYPE_PACKED_INT32_ARRAY)
	assert_eq(back, {"b": bytes, "i": ints})


func test_keep_format_one_places_still_read() -> void:
	var back: Variant = _decoded(JSON.parse_string("{\"pos\": [1.5, 2, -3], \"home\": [0, 0, 0], \"path\": [1, 2, 3]}"))
	assert_eq(back["pos"], Vector3(1.5, 2, -3))
	assert_eq(back["home"], Vector3.ZERO)
	assert_eq(back["path"], [1.0, 2.0, 3.0], "another key keeps its list of three")


func test_keep_the_three_slots_as_written_still_read() -> void:
	var save: Dictionary = _field_save()
	assert_true(FieldSave.write(save, FIELD_AT))
	assert_eq(int(FieldSave.read(FIELD_AT).get("seed", -1)), 1)
	assert_true(SliceSave.write(_slice_save("main"), SLICE_AT))
	assert_eq(SliceSave.read(SLICE_AT).get("contract"), {"note": "main"})
	var board: Array = _train_board()
	var written: Dictionary = {}
	assert_true(SliceSave.write_train(board[0], TRAIN_AT, written))
	var source: Dictionary = {}
	assert_false(SliceSave._train(TRAIN_AT, board[1], source).is_empty())
	assert_eq(source.get("train_sha"), written.get("train_sha"))
