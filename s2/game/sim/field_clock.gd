extends RefCounted
## Field clock: real seconds -> field seconds (x speed) -> game time of day.

const GAME_PER_REAL := 15.0
const ARRIVE_MIN := 630
const SUNSET_MIN := 945
const SAFE_SEC := 1200.0
const LIMIT_SEC := 1800.0

## Debug speed. 2.0 makes every field clock run twice as fast.
var speed: float = 1.0
## Field seconds since arrival (speed already applied).
var elapsed: float = 0.0


func advance(real_delta: float) -> void:
	if real_delta <= 0.0:
		return
	elapsed += real_delta * speed


## Game minutes from midnight of day 1 at a given field time.
static func minutes_at(field_seconds: float) -> float:
	return float(ARRIVE_MIN) + maxf(field_seconds, 0.0) * GAME_PER_REAL / 60.0


## Minutes of the day, starting at 630 (10:30). Not wrapped; the field never reaches midnight.
func game_minutes() -> float:
	return minutes_at(elapsed)


func label() -> String:
	return minutes_label(elapsed)


func is_dark() -> bool:
	return game_minutes() >= float(SUNSET_MIN)


func sun_fraction() -> float:
	var span := float(SUNSET_MIN - ARRIVE_MIN)
	return clampf((game_minutes() - float(ARRIVE_MIN)) / span, 0.0, 1.0)


func past_safe() -> bool:
	return elapsed >= SAFE_SEC


func past_limit() -> bool:
	return elapsed >= LIMIT_SEC


func stay_game_minutes() -> int:
	return int(floor(maxf(elapsed, 0.0) * GAME_PER_REAL / 60.0))


## "D1 HH:MM" of a field time (minutes floored).
func minutes_label(field_seconds: float) -> String:
	return format_minutes(minutes_at(field_seconds))


## "D<day> HH:MM" from absolute game minutes since day-1 midnight (floored).
static func format_minutes(total_minutes: float) -> String:
	var m: int = maxi(int(floor(total_minutes)), 0)
	var day: int = 1 + floori(m / 1440.0)
	var in_day: int = m % 1440
	return "D%d %02d:%02d" % [day, floori(in_day / 60.0), in_day % 60]
