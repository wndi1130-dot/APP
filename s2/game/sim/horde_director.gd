extends RefCounted
## Back-wave hordes for one stop (s2_station 2.3, field_unified 6, zombies.md '무리 운용').

const FieldClock = preload("res://game/sim/field_clock.gd")

const FIRST_INTERVAL := 270.0
const RATIO := 0.85
const PULL_PER_POINT := 5.0
const MIN_GAP := 60.0
const FIRST_SIZE := 6
const SIZE_STEP := 2
## Total hordes are endless (2026-10-07 review: 60 is a concurrent cap the
## field enforces, not a stop budget). budget_left stays for tests and debug.
const BUDGET := 1 << 30
const CONCURRENT_CAP := 60
const REST_BASE := 45.0
const REST_PER_SHOT := 5.0
const REST_MIN := 15.0
const CALL_RANGE_GROWTH := 0.6

## Rear hordes: the sewers are the endless source (user 2026-10-07: refugees
## fled underground and the infected came with them). A rural stop has a small
## sewer, so the train-following share on roads and the track end is large
## (places.md 5). Weights are the share of hordes per entry.
## The bigger Sulechów (user, build 20) adds the tenement cellar drain (a
## sewer mouth inside a building) and the south-east road.
const ENTRIES := ["culvert", "manhole", "east_track", "north_road", "south_road", "cellar", "east_road"]
const ENTRY_WEIGHTS := {"culvert": 0.25, "manhole": 0.15, "east_track": 0.2, "north_road": 0.1, "south_road": 0.075, "cellar": 0.15, "east_road": 0.075}
const SEWERS := ["culvert", "manhole", "cellar"]
const ENTRY_NAMES := {"culvert": "급수탑 밑 암거", "manhole": "거리 맨홀", "east_track": "동쪽 선로 끝", "north_road": "북쪽 길", "south_road": "남쪽 길", "cellar": "공동주택 지하실 배수구", "east_road": "남동쪽 길"}
const ENTRY_PHRASES := {"culvert": "급수탑 밑 암거에서 올라온다", "manhole": "거리 맨홀에서 올라온다", "east_track": "동쪽 선로 끝으로 온다", "north_road": "북쪽 길로 온다", "south_road": "남쪽 길로 온다", "cellar": "공동주택 지하실에서 올라온다", "east_road": "남동쪽 길로 온다"}
const FIRST_ENTRY := "east_track"

## Forecast bands, in game minutes left.
const HOUR_MIN := 50.0
const HALF_MIN := 25.0

var next_arrival: float = FIRST_INTERVAL
## Hordes arrived so far.
var index: int = 0
var last_arrival: float = -INF
var budget_left: int = BUDGET
var next_entry: String = FIRST_ENTRY
## Total seconds pulled forward by noise (for logs).
var pulled_seconds: float = 0.0
var rest_until: float = -INF
## Scheduled gap of the current wait; base for pressure().
var interval: float = FIRST_INTERVAL
var entry_history: Array[String] = []
## Sewer holes closed for this stop (a manhole with something heavy on it).
var blocked: Array[String] = []

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()


func is_exhausted() -> bool:
	return budget_left <= 0


## Size of the next horde (0 when the budget is gone).
func next_size() -> int:
	return mini(FIRST_SIZE + SIZE_STEP * index, budget_left)


## Noise pulls the next horde earlier, never below last_arrival + MIN_GAP or now. Halved during rest.
func add_noise(points: int, now: float) -> void:
	if points <= 0 or is_exhausted():
		return
	var pull: float = float(points) * PULL_PER_POINT
	if now < rest_until:
		pull *= 0.5
	var floor_t: float = maxf(last_arrival + MIN_GAP, now)
	var target: float = maxf(next_arrival - pull, floor_t)
	if target < next_arrival:
		pulled_seconds += next_arrival - target
		next_arrival = target


## Returns {"index", "size", "entry"} when a horde arrives now, else {}.
func update(now: float) -> Dictionary:
	if is_exhausted() or now < next_arrival:
		return {}
	var k: int = index
	var n: int = next_size()
	var e: String = next_entry
	budget_left -= n
	index += 1
	last_arrival = now
	entry_history.append(e)
	if is_exhausted():
		interval = 0.0
		next_arrival = INF
	else:
		var gap: float = maxf(FIRST_INTERVAL * pow(RATIO, k + 1), MIN_GAP)
		interval = gap
		next_arrival = now + gap
		next_entry = _pick_entry()
	return {"index": k, "size": n, "entry": e}


## Rest window after a horde is cleared. Recent gunshots shorten it.
func horde_cleared(now: float, gunshots_recent: int) -> void:
	var rest: float = maxf(REST_BASE - REST_PER_SHOT * float(maxi(gunshots_recent, 0)), REST_MIN)
	rest_until = now + rest
	if next_arrival < rest_until:
		next_arrival = rest_until


func seconds_to_next(now: float) -> float:
	if is_exhausted():
		return INF
	return next_arrival - now


## 0..1: how much of the current gap has been used up (1 = imminent).
func pressure(now: float) -> float:
	if is_exhausted() or interval <= 0.0:
		return 0.0
	return clampf(1.0 - seconds_to_next(now) / interval, 0.0, 1.0)


## Calling range grows with time on the field: 1.0 -> 1.6 at 1800 s.
func call_range_mult(now: float) -> float:
	return 1.0 + CALL_RANGE_GROWTH * clampf(now / FieldClock.LIMIT_SEC, 0.0, 1.0)


## Radio forecast. precision 0: direction + rough time. 1 (signal box): direction, time to 15 min, size.
func forecast(now: float, precision: int, clock) -> String:
	if is_exhausted():
		return "더 오는 기척은 없다."
	var where: String = ENTRY_NAMES.get(next_entry, next_entry)
	if precision <= 0:
		var left_min: float = maxf(seconds_to_next(now), 0.0) * FieldClock.GAME_PER_REAL / 60.0
		var when: String = "곧"
		if left_min >= HOUR_MIN:
			when = "한 시간쯤"
		elif left_min >= HALF_MIN:
			when = "반 시간쯤"
		return "%s, %s." % [ENTRY_PHRASES.get(next_entry, where), when]
	var at_min: float = _arrival_minutes(maxf(next_arrival, now), clock)
	var rounded: int = roundi(at_min / 15.0) * 15
	var hh: int = floori(rounded / 60.0) % 24
	var mm: int = rounded % 60
	return "%s, %02d:%02d쯤, %s." % [where, hh, mm, size_word(next_size())]


## Rough Korean size words: "몇", "여섯 남짓", "열 남짓", "스물 남짓"...
func size_word(n: int) -> String:
	if n <= 0:
		return "없음"
	if n <= 3:
		return "몇"
	var anchors: Array = [[50, "쉰"], [40, "마흔"], [30, "서른"], [20, "스물"], [15, "열다섯"], [10, "열"], [8, "여덟"], [6, "여섯"], [5, "다섯"], [4, "넷"]]
	for a: Array in anchors:
		if n >= int(a[0]):
			return "%s 남짓" % a[1]
	return "몇"


func _arrival_minutes(field_t: float, clock) -> float:
	if clock != null and clock.has_method("minutes_at"):
		return float(clock.minutes_at(field_t))
	return FieldClock.minutes_at(field_t)


## Close a sewer hole for this stop. Its share comes out of the other holes.
func block(entry: String) -> void:
	if not blocked.has(entry):
		blocked.append(entry)
	if next_entry == entry:
		next_entry = _pick_entry()


func is_open(entry: String) -> bool:
	return ENTRIES.has(entry) and not blocked.has(entry)


## A loud sound next to a sewer hole wakes that hole: the next horde climbs out there.
func call_from(entry: String) -> bool:
	if not SEWERS.has(entry) or not is_open(entry) or is_exhausted():
		return false
	next_entry = entry
	return true


static func is_sewer(entry: String) -> bool:
	return SEWERS.has(entry)


## Weighted random entry among open ones, never the same three times in a row.
func _pick_entry() -> String:
	var n: int = entry_history.size()
	var banned: String = ""
	if n >= 2 and entry_history[n - 1] == entry_history[n - 2]:
		banned = entry_history[n - 1]
	var total: float = 0.0
	var choices: Array[String] = []
	for e: String in ENTRIES:
		if e != banned and not blocked.has(e):
			choices.append(e)
			total += float(ENTRY_WEIGHTS[e])
	if choices.is_empty():
		return FIRST_ENTRY
	var r: float = _rng.randf() * total
	for e: String in choices:
		r -= float(ENTRY_WEIGHTS[e])
		if r <= 0.0:
			return e
	return choices[choices.size() - 1]
