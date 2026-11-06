extends "res://addons/gut/test.gd"
## A format 2 byte run (a list of typed ints, test_field_save_b64.gd _old_encode) is read through
## the encoder's 256 byte texts (field_save.gd BYTE_TEXTS) instead of the general int text check:
## the same bytes come back,
## the same texts and shapes break the file, and the run's elements no longer go through
## _int_of_text one by one (on the phone, SM-S906N 11-07, that check made one 6.6 MB format 2
## save 0.14 s slower to read; 230 728 of its 231 736 int tags sat in five byte runs).
## test_fail_* fail on the codec before this change (main with only the _test_int_texts count
## added); test_keep_* hold before and after.

const FieldSave = preload("res://game/sim/field_save.gd")

## Not the encoder's text for a byte: each must break the file, as _int_of_text with the 0..255
## check did. Every text test_save_codec.gd refuses for an int, and the byte edges.
const BAD_BYTE_TEXTS: Array[String] = [
	"", "x", "1.5", "1e3", "+7", "007", "00", "-0", "-007", "-", "+", "--1", "1-", " 7", "7 ", "12\n", "0x10", "１２",
	"256", "-1", "1000", "0255", "+0", "-255", "2550", "25 5", "9223372036854775807", "9223372036854775808",
]
## Not text: JSON gives every number as a float, and no format wrote a number in an int tag.
## A StringName is not text either: _int_of_text refused it, and it must not find the key "7".
const BAD_BYTE_VALUES: Array = [7.0, 7, 0.0, null, true, [], {}, &"7", &"255"]


static func _run(values: Array) -> Dictionary:
	return {"$type": "PackedByteArray", "value": values}


static func _byte(text: Variant) -> Dictionary:
	return {"$type": "int", "value": text}


## Every byte, as format 2 wrote it, through JSON text and back.
static func _all_bytes_text() -> String:
	var values: Array = []
	for b: int in 256:
		values.append(_byte(str(b)))
	return JSON.stringify({"solid": _run(values)}, "", false, true)


# ---------------------------------------------------------------- fail before this change

func test_fail_a_byte_run_does_not_read_its_elements_through_the_int_text_check() -> void:
	var parsed: Variant = JSON.parse_string(_all_bytes_text())
	FieldSave._test_int_texts = 0
	var back: Variant = FieldSave.decode_checked(parsed)
	assert_true(back is Dictionary, "the run reads")
	assert_eq(FieldSave._test_int_texts, 0, "none of the 256 elements went through _int_of_text")


# ---------------------------------------------------------------- held before and after

func test_keep_every_byte_text_reads_back_as_its_byte() -> void:
	var back: Variant = FieldSave.decode_checked(JSON.parse_string(_all_bytes_text()))
	var want := PackedByteArray()
	for b: int in 256:
		want.append(b)
	assert_eq(typeof(back["solid"]), TYPE_PACKED_BYTE_ARRAY)
	assert_eq(back["solid"], want)


func test_keep_a_text_that_is_not_a_byte_breaks_the_file() -> void:
	for text: String in BAD_BYTE_TEXTS:
		assert_null(FieldSave.decode_checked({"solid": _run([_byte("1"), _byte(text)])}), "byte text %s" % JSON.stringify(text))
	for value: Variant in BAD_BYTE_VALUES:
		assert_null(FieldSave.decode_checked({"solid": _run([_byte("1"), _byte(value)])}), "byte value %s" % JSON.stringify(value))


func test_keep_an_element_that_is_not_a_typed_int_breaks_the_file() -> void:
	var elements: Array = [
		7.0, "7", null, [], {"value": "7"}, {"$type": "float", "value": "7"}, {"$type": "int"},
		{"$type": "int", "value": "7", "x": 1.0}, {"$type": "int", "base64": "Bw=="}, {"$type": "Int", "value": "7"},
	]
	for element: Variant in elements:
		assert_null(FieldSave.decode_checked({"solid": _run([_byte("0"), element])}), "element %s" % JSON.stringify(element))


func test_keep_one_bad_byte_at_the_end_of_a_long_run_breaks_it_and_the_next_read_is_clean() -> void:
	var values: Array = []
	for i: int in 5000:
		values.append(_byte(str(i % 256)))
	values.append(_byte("256"))
	assert_null(FieldSave.decode_checked({"solid": _run(values)}), "the last element breaks the whole file")
	values.pop_back()
	var back: Variant = FieldSave.decode_checked({"solid": _run(values)})
	assert_true(back is Dictionary, "the same run without it reads")
	assert_eq((back["solid"] as PackedByteArray).size(), 5000)
	assert_eq(int(back["solid"][4999]), 4999 % 256)


func test_keep_misses_change_nothing_that_reads_or_misses() -> void:
	for text: String in BAD_BYTE_TEXTS:
		FieldSave.decode_checked({"solid": _run([_byte(text)])})
	FieldSave.decode_checked(JSON.parse_string(_all_bytes_text()))
	var known: int = 0
	for b: int in 256:
		if FieldSave.decode_checked({"solid": _run([_byte(str(b))])}) is Dictionary:
			known += 1
	assert_eq(known, 256, "each byte text still reads after the misses")
	for text: String in BAD_BYTE_TEXTS:
		assert_null(FieldSave.decode_checked({"solid": _run([_byte(text)])}), "and each miss still misses: %s" % JSON.stringify(text))


func test_keep_an_int32_run_and_a_lone_int_still_go_through_the_int_text_check() -> void:
	FieldSave._test_int_texts = 0
	# Byte-sized values too: only a byte run may skip the int text check.
	var back: Variant = FieldSave.decode_checked({
		"ints": {"$type": "PackedInt32Array", "value": [_byte("-2147483648"), _byte("0"), _byte("7"), _byte("255"), _byte("2147483647")]},
		"n": _byte("300"), "small": _byte("255"), "zero": _byte("0"),
	})
	assert_eq(back, {"ints": PackedInt32Array([-2147483648, 0, 7, 255, 2147483647]), "n": 300, "small": 255, "zero": 0})
	assert_eq(FieldSave._test_int_texts, 8, "five run elements and three lone ints")
	assert_null(FieldSave.decode_checked({"ints": {"$type": "PackedInt32Array", "value": [_byte("007")]}}))


func test_keep_an_empty_byte_run_reads_as_an_empty_run() -> void:
	var back: Variant = FieldSave.decode_checked({"solid": _run([])})
	assert_eq(typeof(back["solid"]), TYPE_PACKED_BYTE_ARRAY)
	assert_eq((back["solid"] as PackedByteArray).size(), 0)


func test_keep_an_element_with_its_keys_the_other_way_round_reads() -> void:
	var back: Variant = FieldSave.decode_checked({"solid": _run([{"value": "9", "$type": "int"}, _byte("200")])})
	assert_eq(back["solid"], PackedByteArray([9, 200]))


func test_keep_one_bad_byte_in_the_middle_of_a_long_run_breaks_it() -> void:
	for bad: Variant in ["256", "07", 7.0, &"7"]:
		var values: Array = []
		for i: int in 3000:
			values.append(_byte(str(i % 256)))
		values[1500] = _byte(bad)
		assert_null(FieldSave.decode_checked({"solid": _run(values)}), "element 1500 = %s" % var_to_str(bad))
