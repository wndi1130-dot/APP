extends "res://addons/gut/hook_script.gd"

const OUTPUT_PATH := "res://build/gut-outside-errors.json"


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


func run() -> int:
	var found := outside(gut.error_tracker.errors.items)
	print("GUT outside-test errors: %d" % found.size())
	for error: Dictionary in found:
		print("  %s %s (%s:%s %s)" % [error["type"], error["code"],
			error["file"], error["line"], error["function"]])

	var directory_error := DirAccess.make_dir_recursive_absolute(OUTPUT_PATH.get_base_dir())
	if directory_error != OK:
		printerr("GUT outside-test report: cannot create build directory: %s" % error_string(directory_error))
		return 1
	var output := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if output == null:
		printerr("GUT outside-test report: cannot open %s: %s" % [OUTPUT_PATH,
			error_string(FileAccess.get_open_error())])
		return 1
	output.store_string(JSON.stringify({"count": found.size(), "errors": found}))
	output.flush()
	var write_error := output.get_error()
	output.close()
	if write_error != OK:
		printerr("GUT outside-test report: cannot write %s: %s" % [OUTPUT_PATH, error_string(write_error)])
		return 1
	# GUT ignores this return value; CI checks the report. Keep the runner's exit code unchanged.
	return 0
