extends RefCounted
## The rule values the train interior reads, as one Dictionary in S1's names
## (train_rules.json). Until the politics port feeds it, the JSON file stands
## in; this only loads and checks the shape and decides nothing.

const BodyState = preload("res://game/sim/body_state.gd")
const W = preload("res://game/sim/weapons.gd")
const Carry = preload("res://game/sim/carry.gd")
const LifeInput = preload("res://game/train/train_life_input.gd")

const PATH := "res://game/train/train_rules.json"
const KINDS: Array = ["comm", "dining", "captain", "engine", "loco", "freight", "cold", "technical", "tender"]
const PHASES: Array = ["prep", "travel", "stop", "council", "settle", "end"]
const SIT_NAMES: Array = ["온기", "배급", "과밀", "노출"]
const CAPTAIN_OUT := "out"
const CAPTAIN_DOINGS: Array = ["", "rest", "bed"]


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
		if not (train.get("voting", false) is bool):
			bad.append("train.voting: %s" % str(train.get("voting")))
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
	else:
		cars = display_cars(d)
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
	# Optional too: without a captain the board shows a sound one, nowhere.
	if d.has("captain"):
		bad.append_array(_check_captain(d["captain"], ids))
	bad.append_array(LifeInput.check(d, ids))
	return bad


## The captain: on a car that exists or out, doing a thing the board knows,
## holding things the field can name, with wounds the field body can carry.
static func _check_captain(captain, car_ids: Array) -> PackedStringArray:
	var bad := PackedStringArray()
	if not (captain is Dictionary):
		bad.append("captain: not an object")
		return bad
	var at = captain.get("at")
	if not (at is String) or (at != CAPTAIN_OUT and not car_ids.has(at)):
		bad.append("captain.at: %s" % str(at))
	if not CAPTAIN_DOINGS.has(captain.get("doing", "")):
		bad.append("captain.doing: %s" % str(captain.get("doing")))
	if not _in_range(captain.get("left", 0), 0.0, 1000.0):
		bad.append("captain.left: %s" % str(captain.get("left")))
	var hands = captain.get("hands", {})
	if not (hands is Dictionary):
		bad.append("captain.hands: not an object")
		hands = {}
	var weapon = hands.get("weapon", "")
	if not (weapon is String) or (weapon != "" and not W.DATA.has(weapon)):
		bad.append("captain.hands.weapon: %s" % str(weapon))
	var held_tool = hands.get("tool", "")
	if not (held_tool is String) or (held_tool != "" and not Carry.ITEM_NAMES.has(held_tool) and not W.DATA.has(held_tool)):
		bad.append("captain.hands.tool: %s" % str(held_tool))
	var wounds = captain.get("wounds", [])
	if not (wounds is Array):
		bad.append("captain.wounds: not a list")
		wounds = []
	for w in wounds:
		if not (w is Dictionary) or not BodyState.PARTS.has(w.get("part")) or not BodyState.KINDS.has(w.get("kind")):
			bad.append("captain.wounds: no such part or kind (%s)" % str(w))
		elif w.has("blood") and not _in_range(w["blood"], 0.0, 100.0):
			bad.append("captain.wounds: blood %s" % str(w["blood"]))
	return bad


static func comm_of(d: Dictionary, car: Dictionary) -> Dictionary:
	var comms: Dictionary = d.get("comms", {})
	return comms.get(car.get("comm", ""), {})


## S1 domestic extraDefs names added cars by kind and insertion number.
## This projects an existing expansion; it never attaches or buys a rule car.
static func display_cars(d: Dictionary) -> Array:
	var rows: Array = d.get("cars", []).duplicate(true)
	var dom = d.get("dom", {})
	if not dom is Dictionary or not dom.get("extraCars", []) is Array:
		return rows
	var extra: Array = dom.get("extraCars", [])
	for i in extra.size():
		if not extra[i] in ["coach", "store"]:
			continue
		var id := "%s%d" % [extra[i], i + 1]
		if rows.any(func(car): return car is Dictionary and car.get("id", "") == id):
			continue
		if extra[i] == "coach":
			rows.append({"id": id, "kind": "comm", "comm": "tail", "name": "덧붙인 객차", "plate": "객차", "expanded": true})
		else:
			rows.append({"id": id, "kind": "freight", "name": "덧붙인 창고칸", "plate": "창고"})
	# If a port supplies the existing order, keep it. Unlisted display cars stay
	# in their prior order rather than guessing a new formation.
	if dom.get("cars") is Array:
		var ordered: Array = []
		for id in dom["cars"]:
			for car in rows:
				if car is Dictionary and car.get("id", "") == id and not ordered.has(car):
					ordered.append(car)
		for car in rows:
			if not ordered.has(car):
				ordered.append(car)
		return ordered
	return rows


static func _in_range(v, lo: float, hi: float) -> bool:
	return (v is float or v is int) and float(v) >= lo and float(v) <= hi
