extends RefCounted
## Shared, read-only first values for the visible life of the train.

const PATH := "res://game/train/train_life.json"
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_data = parsed
	return _data


static func tuning(key: String):
	return data()["tuning"][key]


static func layout_id(car: Dictionary) -> String:
	var explicit := String(car.get("interior", ""))
	if data()["layouts"].has(explicit):
		return explicit
	match String(car.get("kind", "")):
		"dining", "captain", "freight", "cold", "loco":
			return String(car["kind"])
		"engine", "tender":
			return "tender"
		"technical":
			return "technical"
	match String(car.get("id", "")):
		"workshop", "work":
			return "technical"
	match String(car.get("comm", "")):
		"medtech":
			return "medical"
		"guard":
			return "guard"
		"front":
			return "front"
	return "coach"


static func layout(car: Dictionary) -> Dictionary:
	return data()["layouts"][layout_id(car)]


static func vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


static func field_value(source: Dictionary, path: String, fallback = null):
	var value = source
	for part in path.split("."):
		if not (value is Dictionary) or not value.has(part):
			return fallback
		value = value[part]
	return value


static func assign_value(source: Dictionary, path: String, value) -> void:
	var parts := path.split(".")
	var at: Dictionary = source
	for i in parts.size() - 1:
		if not at.get(parts[i]) is Dictionary:
			at[parts[i]] = {}
		at = at[parts[i]]
	at[parts[-1]] = value
