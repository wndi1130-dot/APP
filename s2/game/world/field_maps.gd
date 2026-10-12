extends RefCounted
## Which map a stop is played on (user 2026-10-11: up to nine maps a kind).
## A map is one script with `static func build() -> Dictionary` and a
## `PLACE_ID`; this is the one place that knows where they live. The game asks
## for a place id and gets the map's data, with the keys newer maps add (bands
## beside the track, train doors on both sides, crossings, barricade slots,
## what the deep part holds) filled in empty where a map does not give them.
##
## A stop may later be several maps joined by a way in (user 2026-10-11: a
## mine goes on underground): `build` can be called again in the same stop,
## and nothing here keeps state.

## Floors are stacked this far apart on every map (map_view draws by it too).
const LEVEL_H: float = 3.0
const DEFAULT_PLACE: String = "first_leg_01_sulechow"
## Maps that keep their own file name.
const BUILT_IN: Dictionary = {"first_leg_01_sulechow": "res://game/world/sulehuf_map.gd"}
## Maps named <kind>_<two digits> live here.
const MAP_DIR: String = "res://game/world/maps/"
const KINDS: Array[String] = ["mine", "lodge", "sawmill", "lake", "freight", "houses", "hospital", "factory", "church", "office", "summit"]
const MOST_PER_KIND: int = 9
## Keys a map may leave out, and what they read as then.
const OPTIONAL: Dictionary = {
	"entry_levels": {}, "manholes": {}, "manhole_levels": {}, "sewer_names": {},
	"bands": {}, "train_doors": {}, "crossings": [], "barricade_slots": [], "interior_kind_slots": [],
	"zone_names": {},
	# Which way a hole that is not straight down opens (key -> Vector2i): the
	# dead come out of a culvert that way. Left out: toward where they are going.
	"hole_faces": {},
	# What a stop on open line has none of.
	"labels": [], "lights": [], "wagons": [], "stoves": [], "low_blocks": [], "trees": [],
	"train_cars": [], "buildings": [], "upper_rects": [], "containers": {}, "spots": {},
}
## How far from the train's side counts as by it, where there is no platform.
const BY_TRAIN: int = 3
## A train whose map does not list its cars is drawn in cars this long, the
## engine last (the east end, where the whistle is).
const CAR_LEN: int = 16


## A sewer hole with a lid can be shut; the others (a culvert, a drain) cannot.
## A map names its lids "manhole", "manhole_01", ...
static func lid(hole: String) -> bool:
	return hole.begins_with("manhole")


static func path_of(place_id: String) -> String:
	if BUILT_IN.has(place_id):
		return BUILT_IN[place_id]
	return MAP_DIR + place_id + ".gd"


static func has(place_id: String) -> bool:
	if BUILT_IN.has(place_id):
		return true
	# Only <kind>_<NN>: a place id never walks out of the maps folder.
	var parts: PackedStringArray = place_id.rsplit("_", true, 1)
	if parts.size() != 2 or not KINDS.has(parts[0]) or parts[1].length() != 2 or not parts[1].is_valid_int():
		return false
	return ResourceLoader.exists(path_of(place_id))


## The place asked for, or the default when there is no such map.
static func resolve(place_id: String) -> String:
	return place_id if has(place_id) else DEFAULT_PLACE


## Every map there is: the built-in ones, then each kind's by number.
static func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in BUILT_IN:
		out.append(id)
	for kind in KINDS:
		for n in range(1, MOST_PER_KIND + 1):
			var id := "%s_%02d" % [kind, n]
			if has(id):
				out.append(id)
	return out


## The map's data, ready for the field. An unknown place gives the default map.
static func build(place_id: String) -> Dictionary:
	return build_from(load(path_of(resolve(place_id))))


static func build_from(script: Script) -> Dictionary:
	var data: Dictionary = script.build()
	var consts: Dictionary = script.get_script_constant_map()
	if not data.has("place_id"):
		data["place_id"] = String(consts.get("PLACE_ID", DEFAULT_PLACE))
	if not data.has("place_kind"):
		data["place_kind"] = "freight"
	for key: String in OPTIONAL:
		if not data.has(key):
			data[key] = OPTIONAL[key].duplicate(true)
	# The old map has doors on one side only: they are the lower side's.
	if data["train_doors"].is_empty() and data.get("spawns", {}).has("train_door"):
		data["train_doors"] = {"lower": data["spawns"]["train_door"].duplicate()}
	# No platform: people board, and loads are put down, by the train on
	# either side of it.
	if data.has("train"):
		if not data.has("platform"):
			data["platform"] = data["train"].grow(BY_TRAIN)
		if not data.has("unload"):
			data["unload"] = data["platform"]
		if data["train_cars"].is_empty():
			data["train_cars"] = cars_of(data["train"])
		# A train with doors on a side the platform does not reach is boarded,
		# and loaded, from the ground by it on that side as well.
		data["boarding"] = [data["platform"]] + side_strips(data, data["platform"])
		data["unloading"] = [data["unload"]] + side_strips(data, data["unload"])
	# Cells the field steers by. What the map names is kept; the rest is worked
	# out from its train and its edges.
	var worked: Dictionary = anchors(data)
	worked.merge(data.get("anchors", {}), true)
	data["anchors"] = worked
	return data


## The ground by the train on each side that has doors, where `covered` does
## not already lie.
static func side_strips(d: Dictionary, covered: Rect2i) -> Array:
	var train: Rect2i = d["train"]
	var out: Array = []
	for side: String in ["upper", "lower"]:
		if d["train_doors"].get(side, []).is_empty():
			continue
		var y: int = train.position.y - BY_TRAIN if side == "upper" else train.end.y
		var strip := Rect2i(train.position.x, y, train.size.x, BY_TRAIN)
		if not strip.intersects(covered):
			out.append(strip)
	return out


## Is this cell where people board (or, with "unloading", put loads down)?
static func by_train(d: Dictionary, c: Vector2i, what: String = "boarding") -> bool:
	for rect: Rect2i in d[what]:
		if rect.grow(1).has_point(c):
			return true
	return false


static func cars_of(train: Rect2i) -> Array:
	var out: Array = []
	var x: int = train.position.x
	while x < train.end.x:
		var length: int = mini(CAR_LEN, train.end.x - x)
		out.append({"rect": Rect2i(x, train.position.y, length, train.size.y), "kind": "car"})
		x += length
	if not out.is_empty():
		out[out.size() - 1]["kind"] = "engine"
	return out


## Where things head when a map does not say: "horde_home" (a horde with no
## sound to follow: the middle door of the train's lower side, or the upper
## side's), "whistle" (the engine end of the train) and "flee_exit" (the cell
## on the map's edge farthest from the train that people can walk); "engine"
## is where the idling engine is heard from. A train with doors on both sides
## has "horde_home_upper" too: what comes from above the train heads there.
static func anchors(d: Dictionary) -> Dictionary:
	var g = d["grid"]
	var doors: Array = d.get("train_doors", {}).get("lower", [])
	if doors.is_empty():
		doors = d.get("train_doors", {}).get("upper", [])
	if doors.is_empty():
		doors = d.get("spawns", {}).get("train_door", [])
	if doors.is_empty():
		doors = d.get("spawns", {}).get("squad", [])
	var home := Vector2i(g.width / 2, g.height / 2)
	if not doors.is_empty():
		home = doors[doors.size() / 2]
	var whistle: Vector2i = home
	if d.has("train"):
		var train: Rect2i = d["train"]
		whistle = Vector2i(clampi(train.end.x - 6, 0, g.width - 1), clampi(train.end.y, 0, g.height - 1))
	var exit: Vector2i = home
	var far := -1
	for y in range(g.height):
		for x in range(g.width):
			if x > 0 and x < g.width - 1 and y > 0 and y < g.height - 1:
				continue
			var c := Vector2i(x, y)
			var dist: int = (c - home).length_squared()
			if dist > far and g.people_can_walk(c):
				far = dist
				exit = c
	# The engine is heard from the cab, a little in from the whistle's end.
	var engine: Vector2i = whistle
	if d.has("train"):
		engine = Vector2i(clampi(d["train"].end.x - 4, 0, g.width - 1), clampi(d["train"].position.y + 1, 0, g.height - 1))
	var out := {"horde_home": home, "whistle": whistle, "flee_exit": exit, "engine": engine}
	var both: Dictionary = d.get("train_doors", {})
	if not both.get("lower", []).is_empty() and not both.get("upper", []).is_empty():
		out["horde_home_upper"] = both["upper"][both["upper"].size() / 2]
	return out
