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


## The flags of stretch `seg`'s stop (empty: none).
static func flags(seg: int) -> Dictionary:
	return (FLAGS.get(seg, {}) as Dictionary).duplicate()


## Put stretch `seg`'s flags on a stop's map data, as soon as the map is built.
static func dress(data: Dictionary, seg: int) -> void:
	data["no_fire"] = bool(flags(seg).get("no_fire", false))
