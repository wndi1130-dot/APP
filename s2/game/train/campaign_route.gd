extends RefCounted
## The two direct stops used by the campaign trial (442).

const FieldMaps = preload("res://game/world/field_maps.gd")
const RouteStops = preload("res://game/train/route_stops.gd")
const StopForm = preload("res://game/sim/stop_form.gd")
const CATALOG: String = "first_leg_main_v1"
const STOPS: Array = [
	{"id": "sulechow", "number": 1, "name": "술레후프", "kind": "freight", "mode": "direct", "map": "first_leg_01_sulechow", "placeholder": false, "band": "K1", "km": 54.0, "form": "city"},
	{"id": "guben", "number": 2, "name": "구벤", "kind": "houses", "mode": "direct", "map": "houses_01", "placeholder": true, "band": "K3", "km": 125.0, "form": "edge"},
]


## The cursor is zero based; the stop's number belongs to the story.
static func stop_at(i: int) -> Dictionary:
	return (STOPS[i] as Dictionary).duplicate(true) if i >= 0 and i < STOPS.size() else {}


static func size() -> int:
	return STOPS.size()


static func map_problem(stop: Dictionary, data: Dictionary = {}) -> String:
	var map_id: String = String(stop.get("map", ""))
	if map_id.is_empty() or not FieldMaps.has(map_id):
		return "F-CAMPAIGN-MAP: unregistered map " + map_id
	if FieldMaps.resolve(map_id) != map_id:
		return "F-CAMPAIGN-MAP: map resolved elsewhere"
	var script: Script = load(FieldMaps.path_of(map_id))
	if script == null or script.get_script_constant_map().get("PLACE_ID") != map_id:
		return "F-CAMPAIGN-MAP: script id differs"
	if not data.is_empty() and (data.get("place_id") != map_id or data.get("place_kind") != stop.get("kind")):
		return "F-CAMPAIGN-MAP: map data differs"
	return ""


static func validate() -> String:
	var seen: Dictionary = {}
	for i: int in STOPS.size():
		var stop: Dictionary = stop_at(i)
		if seen.has(stop["id"]) or stop["number"] != i + 1 or stop["mode"] != "direct":
			return "F-CAMPAIGN-CATALOG: stop identity"
		seen[stop["id"]] = true
		if stop["km"] != RouteStops.KM[i + 1] or stop["form"] != StopForm.on_route("prologue", i + 1):
			return "F-CAMPAIGN-CATALOG: stop context"
		var issue: String = map_problem(stop)
		if issue != "":
			return issue
	return ""
