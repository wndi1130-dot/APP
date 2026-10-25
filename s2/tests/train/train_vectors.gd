extends "res://addons/gut/test.gd"
## Loads the train-vectors file (written by s1/tools/train_port_fixtures.ts from the S1 rules) and
## compares answers: whole numbers must be equal, other numbers within 1e-6, text and flags exact.
## Keys the S1 answer does not have are not compared.

const PATH := "res://tests/fixtures/train/train_vectors.json"
const FORMAT := "train-vectors-v2"
const EPS := 1e-6

static var _data: Dictionary = {}


## Also runnable in the requested GUT list; keep the static reader usable by
## every train test while checking the versioned fixture contract itself.
func test_fixture_contract() -> void:
	assert_eq(data().get("format"), FORMAT)
	assert_true(tables().has("HANDS"))
	assert_gt(points().size(), 0)
	var missing := 0
	for point: Dictionary in points():
		var state: Dictionary = point["state"]
		if not state.has("hands") or not state.has("injured"):
			missing += 1
	assert_eq(missing, 0, "v2 requires hands (nullable) and injured")


static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_data = parsed
	return _data


static func tables() -> Dictionary:
	return data().get("tables", {})


static func points() -> Array:
	return data().get("points", [])


static func _is_num(v: Variant) -> bool:
	return v is float or v is int


## "" when got matches want, else the first place they part.
static func diff(want: Variant, got: Variant, path: String = "") -> String:
	if _is_num(want):
		if not _is_num(got):
			return "%s: want %s, got %s" % [path, want, got]
		var w := float(want)
		var g := float(got)
		if w == floorf(w) and absf(w) < 1e15:
			return "" if g == w else "%s: want %s, got %s" % [path, w, g]
		return "" if absf(w - g) <= EPS else "%s: want %s, got %s" % [path, w, g]
	if want is Array:
		if not got is Array:
			return "%s: want an array, got %s" % [path, got]
		if (want as Array).size() != (got as Array).size():
			return "%s: want %d items, got %d (%s vs %s)" % [path, want.size(), got.size(), want, got]
		for i: int in (want as Array).size():
			var d := diff(want[i], got[i], "%s[%d]" % [path, i])
			if d != "":
				return d
		return ""
	if want is Dictionary:
		if not got is Dictionary:
			return "%s: want an object, got %s" % [path, got]
		for key: Variant in want:
			if not (got as Dictionary).has(key):
				return "%s.%s: missing" % [path, key]
			var d := diff(want[key], got[key], "%s.%s" % [path, key])
			if d != "":
				return d
		return ""
	if typeof(want) != typeof(got):
		return "%s: want %s (%s), got %s (%s)" % [path, want, type_string(typeof(want)), got, type_string(typeof(got))]
	return "" if want == got else "%s: want %s, got %s" % [path, want, got]


static func where(point: Dictionary) -> String:
	return "%s step %d%s" % [point["seed"], int(point["step"]), " (varied)" if bool(point["vary"]) else ""]


## Whole-state comparison for turn-vectors. Unlike diff(), extra keys are errors too.
## Keep the existing projection comparator unchanged for earlier train fixtures.
static func full_diffs(want: Variant, got: Variant, path: String = "", limit: int = 40) -> Array[String]:
	var out: Array[String] = []
	_collect(want, got, path, maxi(0, limit), out)
	return out


static func _collect(want: Variant, got: Variant, path: String, limit: int, out: Array[String]) -> void:
	if out.size() >= limit: return
	if want is Dictionary and got is Dictionary:
		for key: Variant in want:
			if out.size() >= limit: return
			if not got.has(key): out.append("%s.%s: missing" % [path, key])
			else: _collect(want[key], got[key], "%s.%s" % [path, key], limit, out)
		for key: Variant in got:
			if out.size() >= limit: return
			if not want.has(key): out.append("%s.%s: unexpected" % [path, key])
	elif want is Array and got is Array:
		if want.size() != got.size(): out.append("%s: want %d items, got %d" % [path, want.size(), got.size()])
		for i: int in mini(want.size(), got.size()):
			_collect(want[i], got[i], "%s[%d]" % [path, i], limit, out)
	else:
		var mismatch: String = diff(want, got, path)
		if mismatch != "": out.append(mismatch)
