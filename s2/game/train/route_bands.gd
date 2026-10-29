extends RefCounted
## Bands from decision 494: band values only; place names stay out of the repository.
## A stop's number is S1's segment: segment n is the act's n-th stop. A stop's own
## map shows its own stop's band on whatever stretch it is played (the slice plays
## the first stop's map on stretch 2). A running train's window shows the band of
## the stop ahead (slice_flow.gd _show_train).

const Atmosphere = preload("res://fx/atmosphere.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")

const BANDS: Dictionary = {
	"prologue": ["K1", "K3", "K4", "K4", "K6"],
	"act1": ["K7", "K8", "K8", "K8", "K8", "K8", "K9", "K9", "K10", "K10", "K10", "K10"],
	"act2": ["K10", "K10", "K10", "K10", "K10", "K11", "K11", "K11", "K11", "K11", "K11", "K11"],
	"act3": ["K12", "K12", "K12", "K12", "K12", "K12"],
}


static func stop_band(act: String, stop: int, act_progress: float = 0.0) -> String:
	if not BANDS.has(act):
		return Atmosphere.DEFAULT_REGION
	var bands: Array = BANDS[act]
	var slot := stop
	if act == "prologue":
		slot = clampi(stop, 1, bands.size())
	elif stop < 1 or stop > bands.size():
		slot = clampi(floori(act_progress * bands.size()) + 1, 1, bands.size())
	return String(bands[slot - 1])


## The stop a map is the own map of, [act, stop]; empty for a map any stop may use.
## The first leg's first stop is the hand-made default map (field_maps.gd).
static func place_stop(place_id: String) -> Array:
	if place_id == FieldMaps.DEFAULT_PLACE:
		return ["prologue", 1]
	return []


## A stop's own map shows its stop's band; any other map the band of the stop it is played at.
static func band_of(place_id: String, act: String, stop: int, act_progress: float = 0.0) -> String:
	var own := place_stop(place_id)
	if not own.is_empty():
		return stop_band(String(own[0]), int(own[1]))
	return stop_band(act, stop, act_progress)
