extends GutTest
## Only bytes validated in this process may bypass the previous-slot parser.

const FieldSave = preload("res://game/sim/field_save.gd")
static var DIR: String = "user://test_field_save_hash_%d" % OS.get_process_id()
static var AT: String = DIR + "/field_save.json"
static var OTHER: String = DIR + "/other.json"


func before_each() -> void:
	FieldSave._test_fail_step = ""
	DirAccess.make_dir_recursive_absolute(DIR)
	FieldSave.clear(AT)
	FieldSave.clear(OTHER)
	FieldSave._known_good.clear()
	FieldSave._test_previous_parses = 0


func after_each() -> void:
	FieldSave._test_fail_step = ""
	FieldSave.clear(AT)
	FieldSave.clear(OTHER)
	FieldSave._known_good.clear()
	FieldSave._test_previous_parses = 0


func after_all() -> void:
	DirAccess.remove_absolute(DIR)


func _sample(elapsed: float = 12.5) -> Dictionary:
	return {
		"version": FieldSave.VERSION, "kind": FieldSave.KIND, "phase": "field",
		"seed": 4, "receipt_id": "눈길",
		"clock": {"elapsed": elapsed, "speed": 1.0},
		"coal": {"delivered": 0.0, "spent": 0.0},
	}


func _put(path: String, bytes: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_buffer(bytes)
	file.close()


func _digest(bytes: PackedByteArray) -> PackedByteArray:
	var context: HashingContext = HashingContext.new()
	assert_eq(context.start(HashingContext.HASH_SHA256), OK)
	assert_eq(context.update(bytes), OK)
	return context.finish()


func _assert_record_matches(path: String) -> void:
	assert_true(FieldSave._known_good.has(path))
	assert_eq(FieldSave._known_good.get(path), _digest(FileAccess.get_file_as_bytes(path)))


func _snapshot(path: String) -> Dictionary:
	var result: Dictionary = {}
	for suffix: String in ["", ".bak", ".broken", ".tmp"]:
		var at: String = path + suffix
		# Keep absence distinct from an empty file.
		result[suffix] = FileAccess.get_file_as_bytes(at) if FileAccess.file_exists(at) else null
	return result


func test_large_then_small_skips_previous_parse() -> void:
	var large: Dictionary = _sample()
	large["note"] = "x".repeat(65536)
	var small: Dictionary = _sample(99.0)
	small["phase"] = "ended"
	var large_bytes: PackedByteArray = FieldSave.to_json(large).to_utf8_buffer()
	assert_false(FieldSave.from_json(large_bytes.get_string_from_utf8()).is_empty())
	assert_true(FieldSave.write(large, AT))
	_assert_record_matches(AT)
	assert_true(FieldSave.write(small, AT))
	assert_eq(FieldSave._test_previous_parses, 0)
	assert_eq(FileAccess.get_file_as_bytes(AT + ".bak"), large_bytes)
	assert_eq(FileAccess.get_file_as_bytes(AT), FieldSave.to_json(small).to_utf8_buffer())
	assert_false(FileAccess.file_exists(AT + ".broken"))
	_assert_record_matches(AT)
	assert_true(FieldSave.write(_sample(150.0), AT))
	assert_eq(FieldSave._test_previous_parses, 0, "the new bytes replaced the old hash")


func test_read_primary_remembers_exact_disk_bytes() -> void:
	var sample: Dictionary = _sample()
	# Whitespace and UTF-8 must be hashed from disk, not by serializing the decoded save.
	var bytes: PackedByteArray = (" \n" + FieldSave.to_json(sample) + "\n\t").to_utf8_buffer()
	_put(AT, bytes)
	assert_eq(FieldSave.read(AT), sample)
	_assert_record_matches(AT)
	assert_true(FieldSave.write(_sample(99.0), AT))
	assert_eq(FieldSave._test_previous_parses, 0)
	assert_eq(FileAccess.get_file_as_bytes(AT + ".bak"), bytes)


func test_read_backup_does_not_remember_primary() -> void:
	var sample: Dictionary = _sample()
	var backup_bytes: PackedByteArray = FieldSave.to_json(sample).to_utf8_buffer()
	var broken: Dictionary = _sample()
	broken.erase("clock")
	var broken_bytes: PackedByteArray = FieldSave.to_json(broken).to_utf8_buffer()
	_put(AT + ".bak", backup_bytes)
	_put(AT, broken_bytes)
	assert_eq(FieldSave.read(AT), sample)
	assert_false(FieldSave._known_good.has(AT))
	assert_true(FieldSave.write(_sample(99.0), AT))
	assert_eq(FieldSave._test_previous_parses, 1)
	assert_eq(FileAccess.get_file_as_bytes(AT + ".broken"), broken_bytes)
	assert_eq(FileAccess.get_file_as_bytes(AT + ".bak"), backup_bytes)
	_assert_record_matches(AT)


func test_same_length_valid_change_is_parsed() -> void:
	assert_true(FieldSave.write(_sample(), AT))
	var original: PackedByteArray = FileAccess.get_file_as_bytes(AT)
	var changed: PackedByteArray = original.get_string_from_utf8().replace("12.5", "13.5").to_utf8_buffer()
	assert_ne(changed, original)
	assert_eq(changed.size(), original.size())
	assert_false(FieldSave.from_json(changed.get_string_from_utf8()).is_empty())
	_put(AT, changed)
	assert_true(FieldSave.write(_sample(99.0), AT))
	assert_eq(FieldSave._test_previous_parses, 1)
	assert_eq(FileAccess.get_file_as_bytes(AT + ".bak"), changed)
	assert_false(FileAccess.file_exists(AT + ".broken"))
	_assert_record_matches(AT)


func test_same_length_broken_change_is_quarantined() -> void:
	assert_true(FieldSave.write(_sample(), AT))
	var original: PackedByteArray = FileAccess.get_file_as_bytes(AT)
	var changed: PackedByteArray = original.duplicate()
	changed[0] = 33
	assert_eq(changed.size(), original.size())
	assert_true(FieldSave.from_json(changed.get_string_from_utf8()).is_empty())
	_put(AT, changed)
	assert_true(FieldSave.write(_sample(99.0), AT))
	assert_eq(FieldSave._test_previous_parses, 1)
	assert_eq(FileAccess.get_file_as_bytes(AT + ".broken"), changed)
	assert_false(FileAccess.file_exists(AT + ".bak"))
	_assert_record_matches(AT)


func test_truncated_change_is_quarantined() -> void:
	assert_true(FieldSave.write(_sample(), AT))
	var original: PackedByteArray = FileAccess.get_file_as_bytes(AT)
	var changed: PackedByteArray = original.slice(0, original.size() - 1)
	_put(AT, changed)
	assert_true(FieldSave.write(_sample(99.0), AT))
	assert_eq(FieldSave._test_previous_parses, 1)
	assert_eq(FileAccess.get_file_as_bytes(AT + ".broken"), changed)
	assert_false(FileAccess.file_exists(AT + ".bak"))


func test_clear_forgets_only_its_path() -> void:
	var sample: Dictionary = _sample()
	assert_true(FieldSave.write(sample, AT))
	assert_true(FieldSave.write(sample, OTHER))
	FieldSave.clear(AT)
	assert_false(FieldSave._known_good.has(AT))
	_assert_record_matches(OTHER)
	_put(AT, FieldSave.to_json(sample).to_utf8_buffer())
	assert_true(FieldSave.write(_sample(99.0), AT))
	assert_eq(FieldSave._test_previous_parses, 1)
	assert_true(FieldSave.write(_sample(99.0), OTHER))
	assert_eq(FieldSave._test_previous_parses, 1, "the other path still has its record")


func test_identical_bytes_at_another_path_are_not_known() -> void:
	var sample: Dictionary = _sample()
	assert_true(FieldSave.write(sample, AT))
	_put(OTHER, FileAccess.get_file_as_bytes(AT))
	assert_false(FieldSave._known_good.has(OTHER))
	assert_true(FieldSave.write(_sample(99.0), OTHER))
	assert_eq(FieldSave._test_previous_parses, 1)


func _assert_failed_write_keeps_record(step: String) -> void:
	var sample: Dictionary = _sample()
	assert_true(FieldSave.write(sample, AT))
	var before: Dictionary = FieldSave._known_good.duplicate(true)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(AT)
	FieldSave._test_previous_parses = 0
	FieldSave._test_fail_step = step
	assert_false(FieldSave.write(_sample(99.0), AT), step)
	assert_eq(FieldSave._test_fail_step, "")
	assert_eq(FieldSave._known_good, before, "failed writes cannot replace a record")
	assert_eq(FileAccess.get_file_as_bytes(AT), bytes)
	assert_false(FileAccess.file_exists(AT + ".tmp"))
	assert_eq(FieldSave._test_previous_parses, 0)
	assert_true(FieldSave.write(_sample(150.0), AT))
	assert_eq(FieldSave._test_previous_parses, 0, "the old record remains usable")
	_assert_record_matches(AT)


func test_short_failure_keeps_record() -> void:
	_assert_failed_write_keeps_record("short")


func test_write_error_keeps_record() -> void:
	_assert_failed_write_keeps_record("write_error")


func test_rename_tmp_failure_keeps_record() -> void:
	_assert_failed_write_keeps_record("rename_tmp")


func test_tamper_failure_keeps_record() -> void:
	_assert_failed_write_keeps_record("tamper")


func test_read_previous_failure_keeps_record() -> void:
	_assert_failed_write_keeps_record("read_previous")


func test_failed_writes_do_not_create_records() -> void:
	for step: String in ["short", "tamper", "write_error", "read_previous", "rename_tmp"]:
		FieldSave.clear(AT)
		var bytes: PackedByteArray = FieldSave.to_json(_sample()).to_utf8_buffer()
		_put(AT, bytes)
		FieldSave._test_fail_step = step
		assert_false(FieldSave.write(_sample(99.0), AT), step)
		assert_false(FieldSave._known_good.has(AT), step)
		assert_eq(FileAccess.get_file_as_bytes(AT), bytes)
		assert_false(FileAccess.file_exists(AT + ".tmp"))


func test_cached_and_uncached_disk_bytes_match() -> void:
	var first: Dictionary = _sample()
	var second: Dictionary = _sample(99.0)
	assert_true(FieldSave.write(first, AT))
	assert_true(FieldSave.write(first, OTHER))
	_put(AT + ".bak", "old backup".to_utf8_buffer())
	_put(OTHER + ".bak", "old backup".to_utf8_buffer())
	_put(AT + ".broken", "old broken".to_utf8_buffer())
	_put(OTHER + ".broken", "old broken".to_utf8_buffer())
	FieldSave._known_good.erase(OTHER)
	FieldSave._test_previous_parses = 0
	assert_true(FieldSave.write(second, AT))
	assert_eq(FieldSave._test_previous_parses, 0)
	assert_true(FieldSave.write(second, OTHER))
	assert_eq(FieldSave._test_previous_parses, 1)
	assert_eq(_snapshot(AT), _snapshot(OTHER))
	# A stale record and no record must also quarantine the same broken bytes.
	var broken: PackedByteArray = "{broken".to_utf8_buffer()
	_put(AT, broken)
	_put(OTHER, broken)
	FieldSave._known_good.erase(OTHER)
	FieldSave._test_previous_parses = 0
	assert_true(FieldSave.write(_sample(150.0), AT))
	assert_true(FieldSave.write(_sample(150.0), OTHER))
	assert_eq(FieldSave._test_previous_parses, 2)
	assert_eq(_snapshot(AT), _snapshot(OTHER))
	assert_eq(FileAccess.get_file_as_bytes(AT + ".broken"), broken)
	assert_eq(FileAccess.get_file_as_bytes(AT + ".bak"), FieldSave.to_json(first).to_utf8_buffer())
