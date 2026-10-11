extends RefCounted
## The rule values the train interior reads, as one Dictionary in S1's names
## (train_rules.json). Until the politics port feeds it, the JSON file stands
## in; this only loads and checks the shape and decides nothing.

const PATH := "res://game/train/train_rules.json"
const KINDS: Array = ["comm", "dining", "captain", "engine", "loco", "freight", "cold"]
const PHASES: Array = ["prep", "travel", "stop", "council", "settle", "end"]
const SIT_NAMES: Array = ["온기", "배급", "과밀", "노출"]


static func load_default() -> Dictionary:
	return load_file(PATH)


## {} when the file is missing or is not a JSON object.
static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## What is wrong with the shape, one line each; empty when it can be shown.
static func check(d: Dictionary) -> PackedStringArray:
	var bad := PackedStringArray()
	var train = d.get("train")
	if not (train is Dictionary):
		bad.append("train: missing")
	else:
		if not PHASES.has(train.get("phase")):
			bad.append("train.phase: %s" % str(train.get("phase")))
		for key in ["tension", "fear"]:
			if not _in_range(train.get(key), 0.0, 100.0):
				bad.append("train.%s: %s" % [key, str(train.get(key))])
	var comms = d.get("comms")
	if not (comms is Dictionary):
		bad.append("comms: missing")
		comms = {}
	for id in comms:
		var c = comms[id]
		if not (c is Dictionary):
			bad.append("comms.%s: not an object" % id)
			continue
		var sit = c.get("sit")
		if not (sit is Array) or sit.size() != 4:
			bad.append("comms.%s.sit: four numbers" % id)
		else:
			for i in 4:
				if not _in_range(sit[i], 0.0, 100.0):
					bad.append("comms.%s.sit[%d]: %s" % [id, i, str(sit[i])])
		if not _in_range(c.get("pop"), 0.0, 100000.0):
			bad.append("comms.%s.pop: %s" % [id, str(c.get("pop"))])
		if not _in_range(c.get("rel"), -100.0, 100.0):
			bad.append("comms.%s.rel: %s" % [id, str(c.get("rel"))])
	var cars = d.get("cars")
	var ids: Array = []
	if not (cars is Array) or cars.is_empty():
		bad.append("cars: missing")
		cars = []
	for car in cars:
		if not (car is Dictionary) or String(car.get("id", "")) == "":
			bad.append("cars: a car without an id")
			continue
		var id := String(car["id"])
		if ids.has(id):
			bad.append("cars.%s: twice" % id)
		ids.append(id)
		if not KINDS.has(car.get("kind")):
			bad.append("cars.%s.kind: %s" % [id, str(car.get("kind"))])
		if car.has("comm") and not comms.has(car["comm"]):
			bad.append("cars.%s.comm: %s" % [id, str(car["comm"])])
	var errands = d.get("errands", [])
	if not (errands is Array):
		bad.append("errands: not a list")
		errands = []
	for e in errands:
		if not (e is Dictionary) or not ids.has(e.get("to")):
			bad.append("errands: goes to no car (%s)" % str(e.get("to") if e is Dictionary else e))
		elif float(e.get("every", 0.0)) <= 0.0 or float(e.get("stay", 0.0)) <= 0.0:
			bad.append("errands.%s: every and stay above 0" % str(e.get("id")))
	# Both are optional: without them nobody calls at another car.
	var ideo = d.get("ideo", {})
	if not (ideo is Dictionary):
		bad.append("ideo: not an object")
		ideo = {}
	for id in ideo:
		var axes = ideo[id]
		if not comms.has(id):
			bad.append("ideo.%s: no such community" % id)
		elif not (axes is Array) or axes.size() != 3 or axes.any(func(v) -> bool: return not _in_range(v, -1.0, 1.0)):
			bad.append("ideo.%s: three numbers from -1 to 1" % id)
	var calls = d.get("calls", {})
	if not (calls is Dictionary):
		bad.append("calls: not an object")
	elif not calls.is_empty():
		if not _in_range(calls.get("within"), 0.0, 6.0):
			bad.append("calls.within: %s" % str(calls.get("within")))
		if not _in_range(calls.get("every"), 0.001, 100000.0) or not _in_range(calls.get("stay"), 0.001, 100000.0):
			bad.append("calls: every and stay above 0")
	return bad


static func comm_of(d: Dictionary, car: Dictionary) -> Dictionary:
	var comms: Dictionary = d.get("comms", {})
	return comms.get(car.get("comm", ""), {})


static func _in_range(v, lo: float, hi: float) -> bool:
	return (v is float or v is int) and float(v) >= lo and float(v) <= hi
