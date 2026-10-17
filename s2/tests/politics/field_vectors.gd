extends RefCounted
## Reader and deep comparator for field-vectors-v1. JSON object key order is ignored; numeric types
## are interchangeable, with non-integral values compared to 1e-6.

const PATH := "res://tests/game/fixtures/field_port/field_vectors.json"
const FORMAT := "field-vectors-v1"
const EPS := 1e-6

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary and parsed.get("format") == FORMAT:
			_data = parsed
	return _data


static func tables() -> Dictionary:
	return data().get("tables", {})


static func cases() -> Array:
	return data().get("cases", [])


static func departure(name: String) -> Dictionary:
	return data().get("departures", {}).get(name, {})


static func receipt(name: String) -> Dictionary:
	return data().get("receipts", {}).get(name, {})


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func diff(want: Variant, got: Variant, path: String = "") -> String:
	if _is_number(want):
		if not _is_number(got):
			return "%s: want %s, got %s" % [path, want, got]
		var expected := float(want)
		var actual := float(got)
		var integral := expected == floorf(expected) and actual == floorf(actual)
		if integral:
			return "" if expected == actual else "%s: want %s, got %s" % [path, expected, actual]
		return "" if absf(expected - actual) <= EPS else "%s: want %s, got %s" % [path, expected, actual]
	if want is Array:
		if not got is Array:
			return "%s: want an array, got %s" % [path, got]
		if (want as Array).size() != (got as Array).size():
			return "%s: want %d items, got %d" % [path, want.size(), got.size()]
		for i: int in (want as Array).size():
			var problem := diff(want[i], got[i], "%s[%d]" % [path, i])
			if problem != "":
				return problem
		return ""
	if want is Dictionary:
		if not got is Dictionary:
			return "%s: want an object, got %s" % [path, got]
		if (want as Dictionary).size() != (got as Dictionary).size():
			return "%s: want keys %s, got keys %s" % [path, want.keys(), got.keys()]
		for key: Variant in want:
			if not (got as Dictionary).has(key):
				return "%s.%s: missing" % [path, key]
			var problem := diff(want[key], got[key], "%s.%s" % [path, key])
			if problem != "":
				return problem
		return ""
	if typeof(want) != typeof(got):
		return "%s: want %s (%s), got %s (%s)" % [path, want, type_string(typeof(want)), got, type_string(typeof(got))]
	return "" if want == got else "%s: want %s, got %s" % [path, want, got]


static func where(case: Dictionary) -> String:
	return "%s/%s/%s/hang=%s" % [case["seed"], case["receipt"], case["departure"], case["hang"]]
