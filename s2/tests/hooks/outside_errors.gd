extends "res://addons/gut/hook_script.gd"

const OUTPUT_PATH := "res://build/gut-outside-errors.json"
const TEMP_PATH := OUTPUT_PATH + ".tmp"


static func outside(items: Dictionary) -> Array:
	var found: Array = []
	for error: GutTrackedError in items.get(GutUtils.NO_TEST, []):
		if error.handled or error.is_push_warning():
			continue
		if not error.is_gut_error() and not error.is_push_error():
			if not error.is_engine_error() or error.error_type == Logger.ERROR_TYPE_WARNING:
				continue
		found.append({
			"type": str(error.get_error_type_name()),
			"code": error.code,
			"rationale": error.rationale,
			"file": error.file,
			"function": error.function,
			"line": error.line,
		})
	return found


func _fail(message: String) -> int:
	printerr(message)
	if FileAccess.file_exists(TEMP_PATH):
		var remove_error := DirAccess.remove_absolute(TEMP_PATH)
		if remove_error != OK:
			printerr("GUT outside-test report: cannot remove %s: %s" % [TEMP_PATH, error_string(remove_error)])
	return 1


func run():
	# GUT ignores the return value; failure is signalled only by the missing final report.
	var found := outside(gut.error_tracker.errors.items)
	print("GUT outside-test errors: %d" % found.size())
	for error: Dictionary in found:
		var line := "  %s %s (%s:%s %s)" % [error["type"], error["code"],
			error["file"], error["line"], error["function"]]
		var rationale: String = error["rationale"]
		if not rationale.is_empty():
			line += " — " + rationale.left(200)
		print(line)

	# Drop stale success before any write can fail, even when CI has not removed it.
	if FileAccess.file_exists(OUTPUT_PATH):
		var remove_error := DirAccess.remove_absolute(OUTPUT_PATH)
		if remove_error != OK:
			return _fail("GUT outside-test report: cannot remove %s: %s" % [OUTPUT_PATH, error_string(remove_error)])
	var directory_error := DirAccess.make_dir_recursive_absolute(OUTPUT_PATH.get_base_dir())
	if directory_error != OK:
		return _fail("GUT outside-test report: cannot create build directory: %s" % error_string(directory_error))
	var output := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if output == null:
		return _fail("GUT outside-test report: cannot open %s: %s" % [TEMP_PATH,
			error_string(FileAccess.get_open_error())])
	output.store_string(JSON.stringify({"count": found.size(), "errors": found}))
	output.flush()
	var write_error := output.get_error()
	output.close()
	if write_error != OK:
		return _fail("GUT outside-test report: cannot write %s: %s" % [TEMP_PATH, error_string(write_error)])
	if output.is_open():
		return _fail("GUT outside-test report: cannot close %s" % TEMP_PATH)
	var rename_error := DirAccess.rename_absolute(TEMP_PATH, OUTPUT_PATH)
	if rename_error != OK:
		return _fail("GUT outside-test report: cannot rename %s: %s" % [TEMP_PATH, error_string(rename_error)])
	return 0
