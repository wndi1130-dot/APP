extends RefCounted
## Which map a stop is played on (user 2026-10-11: five to seven maps a kind).
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
const KINDS: Array[String] = ["mine", "lodge", "sawmill", "lake", "freight", "houses", "hospital", "factory", "church", "office"]
const MOST_PER_KIND: int = 7
## Keys a map may leave out, and what they read as then.
const OPTIONAL: Dictionary = {
	"entry_levels": {}, "manholes": {}, "manhole_levels": {}, "sewer_names": {},
	"bands": {}, "train_doors": {}, "crossings": [], "barricade_slots": [], "interior_kind_slots": [],
}


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
	return data
