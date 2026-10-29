extends RefCounted
## Where on the line the land going by the train comes from (presentation_motion.md
## 7b, seasons_regions.md 5장, 결정 495): a stretch's region band, cut into windows
## at the band boundaries and around the places the line passes without showing.
## The windows are taken in order, one more each time a decision card closes
## (7b 「키트가 바뀌는 때」), never by the clock: on the train's screen the distance
## run and the time on screen are not one to one. Reads the season table; sets nothing.

const SeasonTable = preload("res://game/season_table.gd")

## The first leg's 312 km over its 24 stretches, evenly (season_table.json region note).
const STRETCH_KM: float = 13.0
## Where each band of the first leg begins (7b 「지역 키트 여섯」, km).
const BAND_KM: Array = [["K1", 0.0], ["K2", 54.0], ["K3", 118.0], ["K4", 130.0], ["K5", 186.0], ["K6", 236.0]]
const LEG_KM: float = 312.0
## Passed by without showing (7b 「지나가되 보여 주지 않는 곳」): the border fields
## wear the K1 plate with fields, woods and snow only — no buildings, signs, dead,
## outside events or wagons on the next line.
const NEUTRAL_KM: Array = [[18.0, 32.0]]
const DEFAULT_BAND := "K1"
## The kinds of land a band's window lays, how often each comes (weight) and for how
## long (seconds of running, 7b: the land goes by slower than it would): the band's
## kit (설계 3장). Four kinds keep a run of three from coming again inside ten
## minutes; a neutral window keeps to woods, the lake shore and fields, longer each,
## and the kit dresses them bare (no village, boat, landing stage or sign). Bands
## with no kit yet lay none: the stop scene keeps its own corridor there.
const KINDS: Dictionary = {
	"K1": [
		{"kind": "wood", "weight": 0.28, "len_s": Vector2(40.0, 90.0)},
		{"kind": "lake", "weight": 0.24, "len_s": Vector2(40.0, 90.0)},
		{"kind": "field", "weight": 0.3, "len_s": Vector2(40.0, 90.0)},
		{"kind": "village", "weight": 0.18, "len_s": Vector2(35.0, 70.0)},
	],
}
const NEUTRAL_KINDS: Array = [
	{"kind": "wood", "weight": 0.35, "len_s": Vector2(90.0, 150.0)},
	{"kind": "lake", "weight": 0.25, "len_s": Vector2(90.0, 150.0)},
	{"kind": "field", "weight": 0.4, "len_s": Vector2(90.0, 150.0)},
]


static func has_kit(band: String) -> bool:
	return KINDS.has(band)


## The kinds a window lays ([] where its band has no kit yet).
static func kinds(window: Dictionary) -> Array:
	var band: String = String(window.get("band", DEFAULT_BAND))
	if not has_kit(band):
		return []
	return (NEUTRAL_KINDS if bool(window.get("neutral", false)) else KINDS[band]).duplicate(true)


## A stretch's windows in order, each {band, from_km, to_km, neutral}. Past the first
## leg (the acts) there is one window, of `band` (the train's view) or K1's next.
static func windows(seg: int, band: String = "") -> Array:
	var out: Array = []
	if seg < 1 or seg > SeasonTable.segments():
		out.append({"band": band if band != "" else DEFAULT_BAND, "from_km": -1.0, "to_km": -1.0, "neutral": false})
		return out
	var a: float = STRETCH_KM * float(seg - 1)
	var b: float = minf(STRETCH_KM * float(seg), LEG_KM)
	var cuts: Array = [a, b]
	for row: Array in BAND_KM:
		var at: float = float(row[1])
		if at > a and at < b:
			cuts.append(at)
	for q: Array in NEUTRAL_KM:
		for at: float in q:
			if at > a and at < b:
				cuts.append(at)
	cuts.sort()
	for i in range(cuts.size() - 1):
		var x0: float = cuts[i]
		var x1: float = cuts[i + 1]
		if x1 - x0 < 0.01:
			continue
		var mid: float = (x0 + x1) * 0.5
		out.append({"band": band_at(mid), "from_km": x0, "to_km": x1, "neutral": neutral_at(mid)})
	return out


## The band at km `km` of the first leg.
static func band_at(km: float) -> String:
	var found: String = DEFAULT_BAND
	for row: Array in BAND_KM:
		if km >= float(row[1]):
			found = String(row[0])
	return found


static func neutral_at(km: float) -> bool:
	for q: Array in NEUTRAL_KM:
		if km >= float(q[0]) and km < float(q[1]):
			return true
	return false


## The stretch's band as the season table has it (its region), else K1.
static func band_of_seg(seg: int) -> String:
	return String(SeasonTable.row(seg).get("region", DEFAULT_BAND))
