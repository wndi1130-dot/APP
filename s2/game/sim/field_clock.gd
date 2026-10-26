extends RefCounted
## Field clock: real seconds -> field seconds (x speed) -> game time of day.

const GAME_PER_REAL := 15.0
const ARRIVE_MIN := 630
const SUNSET_MIN := 945
## The light starts to go at 14:50 (user decision 210).
const DUSK_MIN := 890
const SAFE_SEC := 1200.0
const LIMIT_SEC := 1800.0
## When the train comes in, rolled stop by stop (decision 471 B0): mostly by day,
## now and then late, so the stops do not all end the same way. [share, from,
## to] in game minutes: morning 07:30-09:30, midday 10:00-12:30, late afternoon
## 13:00-14:20, dusk 14:50-15:30. The light still goes at 14:50 (decision 210).
const ARRIVALS: Array = [[0.40, 450, 570], [0.35, 600, 750], [0.20, 780, 860], [0.05, 890, 930]]

## Debug speed. 2.0 makes every field clock run twice as fast.
var speed: float = 1.0
## Field seconds since arrival (speed already applied).
var elapsed: float = 0.0
## This stop's arrival in game minutes (a stop's opts "arrive_min"; else 10:30).
var arrive_min: float = float(ARRIVE_MIN)


func advance(real_delta: float) -> void:
	if real_delta <= 0.0:
		return
	elapsed += real_delta * speed


## Game minutes from midnight of day 1 at a given field time.
static func minutes_at(field_seconds: float, arrive := float(ARRIVE_MIN)) -> float:
	return arrive + maxf(field_seconds, 0.0) * GAME_PER_REAL / 60.0


## The arrival a stop's seed rolls (ARRIVALS), on the ten minutes.
static func arrival_for(stop_seed: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([stop_seed, "arrive"])
	var r := rng.randf()
	for band: Array in ARRIVALS:
		if r < float(band[0]):
			return int(snappedi(rng.randi_range(int(band[1]), int(band[2])), 10))
		r -= float(band[0])
	return ARRIVE_MIN


## Minutes of the day from the arrival (10:30 unless the stop says). Not wrapped; the field never reaches midnight.
func game_minutes() -> float:
	return minutes_at(elapsed, arrive_min)


func label() -> String:
	return minutes_label(elapsed)


func is_dark() -> bool:
	return game_minutes() >= float(SUNSET_MIN)


## How far the light has gone: 0 until 14:50, evenly up to 1 at sunset.
func dusk_share() -> float:
	return clampf((game_minutes() - float(DUSK_MIN)) / float(SUNSET_MIN - DUSK_MIN), 0.0, 1.0)


func sun_fraction() -> float:
	var span := maxf(float(SUNSET_MIN) - arrive_min, 1.0)
	return clampf((game_minutes() - arrive_min) / span, 0.0, 1.0)


func past_safe() -> bool:
	return elapsed >= SAFE_SEC


func past_limit() -> bool:
	return elapsed >= LIMIT_SEC


func stay_game_minutes() -> int:
	return int(floor(maxf(elapsed, 0.0) * GAME_PER_REAL / 60.0))


## "D1 HH:MM" of a field time (minutes floored).
func minutes_label(field_seconds: float) -> String:
	return format_minutes(minutes_at(field_seconds, arrive_min))


## "D<day> HH:MM" from absolute game minutes since day-1 midnight (floored).
static func format_minutes(total_minutes: float) -> String:
	var m: int = maxi(int(floor(total_minutes)), 0)
	var day: int = 1 + floori(m / 1440.0)
	var in_day: int = m % 1440
	return "D%d %02d:%02d" % [day, floori(in_day / 60.0), in_day % 60]
