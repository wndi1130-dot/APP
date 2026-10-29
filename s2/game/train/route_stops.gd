extends RefCounted
## Flags that ride a stop's place on the route, not its map: whichever map comes to
## that place, the flag goes with it. A stretch's number is S1's (the stop of stretch n
## is the first leg's n-th stop: death.ts STRANGER_SEG 2 is Guben).
##
## no_fire: fire is kept out of the stop altogether. The first leg's fifth stop, the
## freight yard by the Mulde bridge at Eilenburg (first_leg_story.md 7.4: no fire
## catching there, places §6 「포대 연기와 문틀」 not used either). The stop's map data
## carries it as data["no_fire"]; night_lights.gd leaves the campfires and drum fires out.

const FLAGS: Dictionary = {5: {"no_fire": true}}

const JourneyRoute = preload("res://game/train/journey/journey_route.gd")
const SeasonTable = preload("res://game/season_table.gd")

## How far along the first leg each of its stops stands (km from the start).
const KM: Dictionary = {1: 54.0, 2: 125.0, 3: 142.0, 4: 163.0, 5: 287.0}


## The season table's stretch a first-leg stop stands on (decision 494): the table keeps
## S1a's stretches of 13 km, so a stop reads the one it is in, counted up as the journey
## map counts them (journey_route.gd). A stop past the five reads the fifth's.
static func season_seg(stop: int) -> int:
	var km: float = float(KM[clampi(stop, 1, KM.size())])
	return clampi(ceili(km / JourneyRoute.STRETCH_KM), 1, SeasonTable.segments())


## The flags of stretch `seg`'s stop (empty: none).
static func flags(seg: int) -> Dictionary:
	return (FLAGS.get(seg, {}) as Dictionary).duplicate()


## Put stretch `seg`'s flags on a stop's map data, as soon as the map is built.
static func dress(data: Dictionary, seg: int) -> void:
	data["no_fire"] = bool(flags(seg).get("no_fire", false))
