extends "res://addons/gut/test.gd"
## field_save.gd BYTE_TEXTS, the table a format 2 byte run is read through: exactly the encoder's
## 256 texts "0" to "255", each to its int byte, and read-only (a const), so no lookup, test or
## other code can add, drop or change a key. Kept apart from test_save_codec_bytes.gd, which also
## runs on the codec before the table (main with only the _test_int_texts count added).

const FieldSave = preload("res://game/sim/field_save.gd")


func test_the_table_is_the_encoders_text_for_each_byte_and_nothing_else() -> void:
	var table: Dictionary = FieldSave.BYTE_TEXTS
	assert_eq(table.size(), 256)
	for b: int in 256:
		assert_true(table.has(str(b)), "has %d" % b)
		assert_eq(typeof(table.get(str(b))), TYPE_INT, "%d is an int" % b)
		assert_eq(table.get(str(b)), b)
	for key: Variant in table:
		assert_eq(typeof(key), TYPE_STRING, "key %s is text" % var_to_str(key))


func test_the_table_is_read_only() -> void:
	assert_true(FieldSave.BYTE_TEXTS.is_read_only())
