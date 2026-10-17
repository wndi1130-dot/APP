extends "res://addons/gut/test.gd"

const V = preload("res://tests/politics/field_vectors.gd")
const SaveSlot = preload("res://game/politics/save_slot.gd")

const SAVE_PATH := "user://codex_field_port_save.json"
const BROKEN_PATH := "user://codex_field_port_broken.json"

var _tables: Dictionary


func before_all() -> void:
	_tables = V.tables()
	_cleanup()


func after_all() -> void:
	_cleanup()


func _cleanup() -> void:
	for path: String in [SAVE_PATH, BROKEN_PATH]:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute)


func _write_raw(text: String) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(text)
	file.close()


func test_fixture_states_round_trip_through_one_slot() -> void:
	var samples: Array = [V.cases()[0]["start"], V.cases()[4]["apply"]["after"], V.cases()[8]["arrival"]["state"]]
	for i: int in samples.size():
		assert_true(SaveSlot.save_slot(samples[i], SAVE_PATH), "save sample %d" % i)
		var loaded := SaveSlot.load_slot(_tables, SAVE_PATH, BROKEN_PATH)
		assert_null(loaded["why"], "load sample %d" % i)
		assert_eq(V.diff(samples[i], loaded["g"], "sample %d" % i), "")


func test_bad_saves_are_rejected_with_reason_and_preserved_beside_slot() -> void:
	var base: Dictionary = V.cases()[0]["start"]
	var no_version: Dictionary = base.duplicate(true)
	no_version.erase("version")
	var newer: Dictionary = base.duplicate(true)
	newer["version"] = SaveSlot.SAVE_VERSION + 1
	var bad_field: Dictionary = (V.cases()[0]["apply"]["after"] as Dictionary).duplicate(true)
	bad_field["fieldReturns"]["applied"] = []
	var cases := [
		{"raw": JSON.stringify(no_version), "why": "판 번호가 없다"},
		{"raw": JSON.stringify(newer), "why": "더 새 빌드에서 저장한 판이다"},
		{"raw": "{not json", "why": "저장 글이 깨졌다"},
		{"raw": JSON.stringify(bad_field), "why": "필드 귀환 기록이 이상하다"},
	]
	for row: Dictionary in cases:
		_cleanup()
		_write_raw(row["raw"])
		var loaded := SaveSlot.load_slot(_tables, SAVE_PATH, BROKEN_PATH)
		assert_null(loaded["g"], row["why"])
		assert_true(String(loaded["why"]).contains(row["why"]), String(loaded["why"]))
		assert_true(FileAccess.file_exists(BROKEN_PATH), row["why"] + " broken copy")
		assert_eq(FileAccess.get_file_as_string(BROKEN_PATH), row["raw"], row["why"] + " broken bytes")
		assert_true(FileAccess.file_exists(SAVE_PATH), row["why"] + " original retained")
		assert_eq(FileAccess.get_file_as_string(SAVE_PATH), row["raw"], row["why"] + " original bytes")
