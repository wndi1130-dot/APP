extends RefCounted
## How the dead smell the living (body_injury 8.1, the user's 'light' smell of
## 2026-10-07). Two things only: excessive blood calls them (a 12 m event each
## minute and a dark trail), and a body's own smell stretches how far they
## notice that body. The reference game has no smell at all; this is ours.

## The blood event and its trail. field_game.gd lays the trail and pulses the
## event with these same values (tests hold them equal).
const EVENT_R: float = 12.0
const EVENT_EVERY: float = 60.0
const TRAIL_EVERY: float = 1.5
const TRAIL_LIFE: float = 120.0
const TRAIL_MAX: int = 200
## Falling snow weakens drops older than this to that share of their reach.
const SNOW_FADE_AFTER: float = 30.0
const SNOW_FADE: float = 0.7
## A smelled spot holds the dead there this long; a trail it follows is not
## given up for another for this long (the sense ticks at ~6 Hz).
const LINGER: float = 8.0
const TRAIL_LOCK: float = 3.0
const TRAIL_LOCK_TICK: float = 0.17

## Body smell 0 clean, 1 sweat, 2 stench: x1, x1.25, x1.5 on how far the dead
## notice that body, the end of sight and the feel at arm's reach alike.
## Downwind it goes one step further (x1.5 sweat, x1.75 stench); a clean body
## has nothing for the wind to carry.
const BODY_STEP: float = 0.25
const BODY_MAX: int = 2
## Downwind as the blood event reads it (weather.scent_mult): within 60 degrees.
const DOWNWIND_COS: float = 0.5


static func body_mult(smell: int, downwind: bool) -> float:
	var level: int = clampi(smell, 0, BODY_MAX)
	if downwind and level > 0:
		level += 1
	return 1.0 + BODY_STEP * float(level)


## True when the wind carries from `from` (the body) toward `to` (the dead).
static func downwind(wind: float, wind_dir: Vector2, from: Vector3, to: Vector3) -> bool:
	var d := Vector2(to.x - from.x, to.z - from.z)
	if wind <= 0.0 or d.length() < 0.001:
		return false
	return wind_dir.dot(d.normalized()) >= DOWNWIND_COS
