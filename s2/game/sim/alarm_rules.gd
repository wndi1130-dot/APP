extends RefCounted
## A building's alarm (gap audit J17): breaking in may set it off. A door
## kicked through or pried open, or a window broken, rolls once for the
## building; one opened with its key never does. Once it rings it is loud and
## carries far, over and over, for a good while: the dead come from all round
## and, when it stops, stand about there as a crowd of their own. Set off from
## far on purpose (a window broken by a shot or a throw), it is bait.
##
## Pure: what a building's role gives, when it rings, decided by the stop's
## seed and the building alone (no dice of the game's are drawn).

const SimNoise = preload("res://game/sim/noise.gd")
const LootRules = preload("res://game/sim/loot_rules.gd")
const LootTables = preload("res://game/sim/loot_tables.gd")

## The chance a building's alarm goes off when it is first broken into, by
## its kind (kind_of): shops, chemists and the station had them, workshops
## often, homes now and then, sheds and barns never.
const CHANCE := {"shop": 0.4, "hospital": 0.5, "station": 0.4, "workshop": 0.3, "house": 0.1, "farm": 0.0, "shed": 0.0}
const OTHER_CHANCE := 0.1
## How long it rings, and one ring this often (each a loud sound).
const RING_S := 120.0
const RING_EVERY_S := 4.0
## Every ring reaches this many times a loud sound's radius (noise.gd SOURCES
## "reach"): seventy metres out of doors.
const REACH := 2.0
const LEVEL := SimNoise.Level.LOUD


static func chance(kind: String) -> float:
	return float(CHANCE.get(kind, OTHER_CHANCE))


## A building's kind, as the loot reads it: its own name first (the station,
## the freight shed), then the words of its name (shop, chemist, workshop …).
static func kind_of(building: Dictionary) -> String:
	var name := String(building.get("name", ""))
	if LootTables.PLACE_OF_BUILDING.has(name):
		return String(LootTables.PLACE_OF_BUILDING[name])
	return LootRules.place_of_name(name)


## Does this building's alarm go off, the first time it is broken into?
static func goes_off(seed: int, building: int, kind: String) -> bool:
	var h: int = ("%d:%d:building_alarm" % [seed, building]).hash()
	return float(h & 0xFFFFFF) / float(0x1000000) < chance(kind)


## The rings of an alarm set off at `start`: their times, the first one first.
static func rings(start: float) -> Array[float]:
	var out: Array[float] = []
	var t := 0.0
	while t < RING_S:
		out.append(start + t)
		t += RING_EVERY_S
	return out
