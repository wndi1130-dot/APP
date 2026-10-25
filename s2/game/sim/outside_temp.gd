extends RefCounted
## A stop's outside air for the rules (body heat, the cold in a fight, smell,
## what falls). 코디네이터 10-25: the field's air follows the season table too,
## the same stretch temperature S1, the train, the stop scene and the pictures
## read, so a rainy stop is not frozen like -14 C. The field and the stop scene
## (stop_cinema.gd) both take it from here.

const Atmosphere = preload("res://fx/atmosphere.gd")
const SeasonTable = preload("res://game/season_table.gd")


## opts "ambient_c" gives it outright. A cold given outright (check shots,
## tests) or the old 10-09 flow gives that cold's midday picture temperature
## (cold 1 is -14 C, the old fixed air). Else the season table's midday
## temperature of the act at its progress.
static func of(opts: Dictionary, cold: float, side: float) -> float:
	if opts.has("ambient_c"):
		return float(opts["ambient_c"])
	var scheme := String(opts.get("cold_scheme", ""))
	if scheme == "":
		scheme = Atmosphere.scheme
	if opts.has("cold") or Atmosphere.SCHEMES.has(scheme):
		return Atmosphere.cold_key(cold, "temp", -1, side)
	return SeasonTable.temp_at(String(opts.get("act", "prologue")), float(opts.get("act_progress", 0.0)))
