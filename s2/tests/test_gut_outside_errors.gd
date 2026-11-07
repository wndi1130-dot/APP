extends "res://addons/gut/test.gd"

const OutsideErrors = preload("res://tests/hooks/outside_errors.gd")


func _add_error(tracker: GutErrorTracker, error_type: int = Logger.ERROR_TYPE_ERROR,
		function_name: String = "before_all") -> GutTrackedError:
	return tracker.add_error(function_name, "res://tests/한글 파일.gd", 12,
		"엔진 오류", "오류 설명", false, error_type, [])


func test_unhandled_engine_errors_are_counted() -> void:
	for error_type in [Logger.ERROR_TYPE_ERROR, Logger.ERROR_TYPE_SCRIPT, Logger.ERROR_TYPE_SHADER]:
		var tracker := GutErrorTracker.new()
		tracker.start_test("test_body")
		tracker.end_test()
		var error := _add_error(tracker, error_type)
		var found := OutsideErrors.outside(tracker.errors.items)
		assert_eq(found.size(), 1)
		if found.size() == 1:
			assert_eq(found[0], {
				"type": str(error.get_error_type_name()),
				"code": "엔진 오류",
				"rationale": "오류 설명",
				"file": "res://tests/한글 파일.gd",
				"function": "before_all",
				"line": 12,
			})
		assert_false(error.handled)
		assert_eq(tracker.get_current_test_errors().size(), 1)


func test_handled_errors_are_excluded() -> void:
	var tracker := GutErrorTracker.new()
	var engine_error := _add_error(tracker)
	var gut_error := tracker.add_gut_error("다룬 GUT 오류")
	var push_error_entry := _add_error(tracker, Logger.ERROR_TYPE_ERROR, "push_error")
	for error in [engine_error, gut_error, push_error_entry]:
		error.handled = true
	assert_eq(OutsideErrors.outside(tracker.errors.items), [])


func test_test_body_errors_are_excluded() -> void:
	var tracker := GutErrorTracker.new()
	tracker.start_test("test_body")
	_add_error(tracker)
	tracker.add_gut_error("시험 안 GUT 오류")
	_add_error(tracker, Logger.ERROR_TYPE_ERROR, "push_error")
	tracker.end_test()
	assert_eq(OutsideErrors.outside(tracker.errors.items), [])


func test_push_warnings_are_excluded() -> void:
	var tracker := GutErrorTracker.new()
	_add_error(tracker, Logger.ERROR_TYPE_WARNING, "push_warning")
	assert_eq(OutsideErrors.outside(tracker.errors.items), [])


func test_engine_warnings_are_excluded() -> void:
	var tracker := GutErrorTracker.new()
	var warning := _add_error(tracker, Logger.ERROR_TYPE_WARNING)
	assert_true(warning.is_engine_error())
	assert_eq(OutsideErrors.outside(tracker.errors.items), [])


func test_gut_errors_are_counted() -> void:
	var tracker := GutErrorTracker.new()
	var error := tracker.add_gut_error("GUT 오류")
	var found := OutsideErrors.outside(tracker.errors.items)
	assert_eq(found.size(), 1)
	if found.size() == 1:
		assert_eq(found[0]["type"], str(error.get_error_type_name()))
		assert_eq(found[0]["code"], "GUT 오류")


func test_push_errors_are_counted() -> void:
	var tracker := GutErrorTracker.new()
	var error := _add_error(tracker, Logger.ERROR_TYPE_ERROR, "push_error")
	var found := OutsideErrors.outside(tracker.errors.items)
	assert_eq(found.size(), 1)
	if found.size() == 1:
		assert_eq(found[0]["type"], str(error.get_error_type_name()))
		assert_eq(found[0]["function"], "push_error")


func test_empty_dictionary_has_no_errors() -> void:
	assert_eq(OutsideErrors.outside({}), [])
