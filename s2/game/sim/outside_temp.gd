extends RefCounted
## A stop's outside air for the rules (body heat, the cold in a fight, smell,
## what falls). 코디네이터 10-25: the field's air follows the season table too,
## the same stretch temperature S1, the train, the stop scene and the pictures
## read, so a rainy stop is not frozen like -14 C. The field and the stop scene
## (stop_cinema.gd) both take it from here. of() is the midday air; the field
## moves its air with the hour by at_hour() (dusk and night colder).

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


## Whether this stop's night freezes by the season table: 1 yes, 0 no, -1 not
## known (an air or a cold given outright, the old flow): the night air then
## has no bounds at zero.
static func frost_of(opts: Dictionary) -> int:
	var scheme := String(opts.get("cold_scheme", ""))
	if scheme == "":
		scheme = Atmosphere.scheme
	if opts.has("ambient_c") or opts.has("cold") or Atmosphere.SCHEMES.has(scheme):
		return -1
	return 1 if SeasonTable.night_freeze_at(String(opts.get("act", "prologue")), float(opts.get("act_progress", 0.0))) else 0


## The air at an hour of the stop (2026-10-25 user answer: the rules' air goes
## down at dusk and night on the pictures' curve, held to the table's night
## frost at zero; fx/atmosphere.gd draws the same). midday: this stop's
## midday air (of). kinds: what the sky shows (clear or nothing: the clear
## night's bigger drop). Storm stops keep their midday air.
static func at_hour(midday: float, hour: float, cold: float, side: float, kinds: Array, frost: int) -> float:
	var clear := kinds.is_empty() or kinds.has("clear")
	return SeasonTable.night_air(midday, Atmosphere.dark_share(Atmosphere.band_weights(hour, cold, side)), clear, frost)
