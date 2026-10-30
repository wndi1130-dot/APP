extends RefCounted
## The atmosphere frame (사용자 2026-10-24: 회색 한 벌 대신 색과 변주, 점점 추워짐).
## One place says how the outside looks, from four inputs: the hour, the weather
## the rules picked, the region band (K1~K12) and one cold value (cold: 0 the
## warmest the campaign gets, 1 the coldest). look() returns sky, sun, clouds,
## haze, what falls, lying snow, water and ice, breath, frost and the colour
## grade; params() turns that into the fx_* shader globals (FxState writes them).
## Picture only: rules (sight, sound and body multipliers, weather odds, the
## field clock, the rules temperature) never read anything here. Brief:
## docs/design/briefs/atmosphere.md. Numbers are proposals until a play check.

const FxState = preload("res://fx/fx_state.gd")
const SeasonTable = preload("res://game/season_table.gd")

# ------------------------------------------------------------------ the cold

## cold: 0 the warmest the campaign gets, 1 the coldest. side: 0 the autumn side
## (days still shortening, leaf on the trees, first frosts), 1 the spring side
## (days lengthening, old snow going grey). The default, "autumn_to_thaw", is
## the one season table S1 and the train read too (game/season_table.gd, the
## user's season answer of 2026-10-24 with the prologue (나)): an early cold
## snap at the start, late autumn rain, first night frosts and snow by the end
## of the first leg, early winter to deep winter through act 1, the coldest with
## blizzards in act 2, the early thaw in act 3. Its cold comes from the table's
## midday temperature (cold_from_temp), so the two never disagree.
## "winter_to_thaw" is the old 10-09 flow, kept to compare:
## act -> [cold at its first stop, cold at its last, side].
const SCHEMES: Dictionary = {
	"winter_to_thaw": {"prologue": [1.0, 1.0, 0.5], "act1": [1.0, 0.9, 1.0], "act2": [0.82, 0.6, 1.0], "act3": [0.42, 0.3, 1.0]},
}
const DEFAULT_SCHEME := "autumn_to_thaw"
const ACTS: Array[String] = ["prologue", "act1", "act2", "act3"]
## The test switch (boot menu, opts "cold_scheme"): which table cold_for reads.
static var scheme: String = DEFAULT_SCHEME

## What a cold value means, on either side of midwinter; linear between the
## anchors, and between the two sides by `side`. temp: picture temperature at
## midday in C, for what falls and what freezes (not the rules temperature).
## rise, set: sunrise and sunset (seasons_regions.md 2.2 on the spring side; the
## autumn side is late October to December at 52~54 N). noon: sun height at
## midday in degrees (35 at the coldest is the user's low cold sun of 10-17).
## snow_cm: [ordinary, open ground] lying on arrival. leaves: leaf left on birch
## and beech (autumn colour; none in spring).
const AUTUMN_KEYS: Array = [
	{"cold": 0.0, "temp": 7.0, "rise": 7.0, "set": 16.6, "noon": 40.0, "snow_cm": [0.0, 0.0], "leaves": 1.0},
	{"cold": 0.45, "temp": -0.5, "rise": 7.6, "set": 16.05, "noon": 37.0, "snow_cm": [3.0, 0.0], "leaves": 0.35},
	{"cold": 0.75, "temp": -7.0, "rise": 7.9, "set": 15.9, "noon": 35.5, "snow_cm": [18.0, 8.0], "leaves": 0.0},
	{"cold": 1.0, "temp": -14.0, "rise": 8.0, "set": 15.0 + 50.0 / 60.0, "noon": 35.0, "snow_cm": [25.0, 25.0], "leaves": 0.0},
]
const SPRING_KEYS: Array = [
	{"cold": 0.0, "temp": 7.0, "rise": 6.3, "set": 17.7, "noon": 44.0, "snow_cm": [0.0, 0.0], "leaves": 0.0},
	{"cold": 0.35, "temp": 1.0, "rise": 6.75, "set": 17.25, "noon": 42.0, "snow_cm": [7.0, 0.0], "leaves": 0.0},
	{"cold": 0.7, "temp": -6.0, "rise": 7.5, "set": 16.5, "noon": 38.0, "snow_cm": [25.0, 7.0], "leaves": 0.0},
	{"cold": 1.0, "temp": -14.0, "rise": 8.0, "set": 15.0 + 50.0 / 60.0, "noon": 35.0, "snow_cm": [25.0, 25.0], "leaves": 0.0},
]
## Season states by the lowest cold that still counts as them, on each side.
const AUTUMN_SEASONS: Array = [[0.85, "deep_winter"], [0.4, "early_winter"], [0.0, "late_autumn"]]
const SPRING_SEASONS: Array = [[0.85, "deep_winter"], [0.55, "late_winter"], [0.0, "early_thaw"]]

## What falls, by picture temperature: rain only above this (no rain below
## zero, body_injury 8.3), snow below the other, sleet between.
const RAIN_ABOVE := 1.5
const SNOW_BELOW := -2.0


static func _from_table(which: String) -> bool:
	return not SCHEMES.has(which if which != "" else scheme)


static func _scheme_row(act: String, which: String) -> Array:
	var s: Dictionary = SCHEMES[which if which != "" else scheme]
	return s.get(act, s["prologue"])


static func cold_for(act: String, progress := 0.0, which := "") -> float:
	if _from_table(which):
		return cold_from_temp(SeasonTable.temp_at(act, progress), SeasonTable.side_at(act))
	var row := _scheme_row(act, which)
	return clampf(lerpf(float(row[0]), float(row[1]), clampf(progress, 0.0, 1.0)), 0.0, 1.0)


## Which side of midwinter the act stands on (0 autumn, 1 spring).
static func side_for(act: String, which := "") -> float:
	if _from_table(which):
		return SeasonTable.side_at(act)
	return clampf(float(_scheme_row(act, which)[2]), 0.0, 1.0)


## The season state's name at this point of the campaign: the table's (the
## same name S1 and the train read), else from the old flow's cold.
static func season_at(act: String, progress := 0.0, which := "") -> String:
	if _from_table(which):
		return SeasonTable.season_at(act, progress)
	return season_for(cold_for(act, progress, which), side_for(act, which))


## The cold whose midday picture temperature is this (the keys' temp read
## backwards, straight between them): +7 C and warmer is 0, -14 C and colder 1.
static func cold_from_temp(temp: float, side := 0.0) -> float:
	var k := clampf(side, 0.0, 1.0)
	return lerpf(_cold_on(AUTUMN_KEYS, temp), _cold_on(SPRING_KEYS, temp), k)


static func _cold_on(table: Array, temp: float) -> float:
	if temp >= float(table[0]["temp"]):
		return 0.0
	for i in range(table.size() - 1):
		var a: Dictionary = table[i]
		var b: Dictionary = table[i + 1]
		if temp >= float(b["temp"]):
			return lerpf(float(a["cold"]), float(b["cold"]), inverse_lerp(float(a["temp"]), float(b["temp"]), temp))
	return 1.0


static func _key_on(table: Array, c: float, key: String, index: int) -> float:
	for i in range(table.size() - 1):
		var a: Dictionary = table[i]
		var b: Dictionary = table[i + 1]
		if c <= float(b["cold"]) + 0.00001:
			var t := inverse_lerp(float(a["cold"]), float(b["cold"]), c)
			var va = a[key] if index < 0 else a[key][index]
			var vb = b[key] if index < 0 else b[key][index]
			return lerpf(float(va), float(vb), t)
	var last: Dictionary = table[table.size() - 1]
	return float(last[key] if index < 0 else last[key][index])


## A number from the anchors at this cold and side, straight between them.
static func cold_key(cold: float, key: String, index := -1, side := 0.0) -> float:
	var c := clampf(cold, 0.0, 1.0)
	var k := clampf(side, 0.0, 1.0)
	return lerpf(_key_on(AUTUMN_KEYS, c, key, index), _key_on(SPRING_KEYS, c, key, index), k)


static func season_for(cold: float, side := 0.0) -> String:
	for row in (SPRING_SEASONS if side >= 0.5 else AUTUMN_SEASONS):
		if cold >= float(row[0]) - 0.00001:
			return String(row[1])
	return "late_autumn"


## Sunrise and sunset at this cold and side.
static func sun_times(cold: float, side := 0.0) -> Vector2:
	return Vector2(cold_key(cold, "rise", -1, side), cold_key(cold, "set", -1, side))


## Where the four hour bands start (seasons_regions 7장 rule: dawn 1 h before
## sunrise, day 30 min after it, dusk 1 h before sunset, night 40 min after).
static func band_starts(cold: float, side := 0.0) -> Dictionary:
	var t := sun_times(cold, side)
	return {"dawn": t.x - 1.0, "day": t.x + 0.5, "dusk": t.y - 1.0, "night": t.y + 40.0 / 60.0}


## How much of each band the hour is in (they add up to 1). Bands meet over
## about 40 minutes so the light never jumps.
static func band_weights(hour: float, cold: float, side := 0.0) -> Dictionary:
	var b := band_starts(cold, side)
	var h := fposmod(hour, 24.0)
	var ease := 0.34
	var dawn_in := smoothstep(b["dawn"] - ease, b["dawn"] + ease, h)
	var day_in := smoothstep(b["day"] - ease, b["day"] + ease, h)
	var dusk_in := smoothstep(b["dusk"] - ease, b["dusk"] + ease, h)
	var night_in := smoothstep(b["night"] - ease, b["night"] + ease, h)
	var w := {
		"dawn": dawn_in * (1.0 - day_in),
		"day": day_in * (1.0 - dusk_in),
		"dusk": dusk_in * (1.0 - night_in),
		"night": (1.0 - dawn_in) + night_in,
	}
	var total := 0.0
	for k in w:
		total += float(w[k])
	for k in w:
		w[k] = float(w[k]) / total
	return w


static func band_of(hour: float, cold: float, side := 0.0) -> String:
	var w := band_weights(hour, cold, side)
	var best := "night"
	for k in ["dawn", "day", "dusk", "night"]:
		if float(w[k]) > float(w[best]) + 0.0001:
			best = k
	return best


## Sun height in degrees (below zero under the horizon) and how far round from
## south it stands (+ east in the morning, - west in the afternoon).
static func sun_angles(hour: float, cold: float, side := 0.0) -> Vector2:
	var t := sun_times(cold, side)
	var f := (fposmod(hour, 24.0) - t.x) / maxf(t.y - t.x, 0.1)
	var elev := cold_key(cold, "noon", -1, side) * sin(PI * clampf(f, 0.0, 1.0))
	if f < 0.0:
		elev = -6.0 * clampf(-f * 6.0, 0.0, 1.0)
	elif f > 1.0:
		elev = -6.0 * clampf((f - 1.0) * 6.0, 0.0, 1.0)
	return Vector2(elev, lerpf(55.0, -55.0, clampf(f, 0.0, 1.0)))


# ------------------------------------------------------------------ the regions

## The region bands (seasons_regions.md 5장, presentation_motion.md 7b): only
## what the pictures read. horizon: the far line. forest: how much of the far
## line is wood; conifer and birch: what the wood is. water: lakes and rivers
## near the line. town: roofs and blocks. hills: how much the line rolls.
## spire, silo: church towers and grain towers now and then. wind: how hard it
## blows (plain and coast strong, wood and valley weak). mist: river and marsh
## fog. open: wind-scoured ground (thin snow in late winter, SnowCover).
## poles: telegraph poles (Polish side) or the catenary masts (German side).
const REGIONS: Dictionary = {
	"K1": {"name": "대폴란드 호수 평야", "forest": 0.45, "conifer": 0.55, "birch": 0.45, "water": 0.7, "town": 0.3, "hills": 0.1, "spire": 0.5, "silo": 0.0, "wind": 0.5, "mist": 0.35, "open": false, "poles": "telegraph"},
	"K2": {"name": "오데르·보브르 골짜기", "forest": 0.6, "conifer": 0.35, "birch": 0.35, "water": 0.6, "town": 0.2, "hills": 0.35, "spire": 0.3, "silo": 0.0, "wind": 0.3, "mist": 0.85, "open": false, "poles": "telegraph"},
	"K3": {"name": "국경 강변 소도시", "forest": 0.2, "conifer": 0.4, "birch": 0.35, "water": 0.45, "town": 0.9, "hills": 0.1, "spire": 0.6, "silo": 0.0, "wind": 0.5, "mist": 0.45, "open": false, "poles": "catenary"},
	"K4": {"name": "라우지츠 소나무 모래 평원", "forest": 0.85, "conifer": 0.95, "birch": 0.12, "water": 0.3, "town": 0.15, "hills": 0.05, "spire": 0.1, "silo": 0.0, "wind": 0.8, "mist": 0.2, "open": true, "poles": "catenary"},
	"K5": {"name": "니더라우지츠 등성이", "forest": 0.75, "conifer": 0.7, "birch": 0.2, "water": 0.1, "town": 0.15, "hills": 0.75, "spire": 0.2, "silo": 0.0, "wind": 0.5, "mist": 0.4, "open": false, "poles": "catenary"},
	"K6": {"name": "엘베·물데 범람원과 교외", "forest": 0.3, "conifer": 0.3, "birch": 0.4, "water": 0.55, "town": 0.6, "hills": 0.05, "spire": 0.2, "silo": 0.1, "wind": 0.5, "mist": 0.65, "open": false, "poles": "catenary"},
	"K7": {"name": "북쪽 평야 제분소·곡물 창고", "forest": 0.15, "conifer": 0.4, "birch": 0.3, "water": 0.1, "town": 0.35, "hills": 0.0, "spire": 0.15, "silo": 0.8, "wind": 0.85, "mist": 0.3, "open": true, "poles": "catenary"},
	"K8": {"name": "엘베 범람원과 플레밍", "forest": 0.6, "conifer": 0.85, "birch": 0.3, "water": 0.65, "town": 0.2, "hills": 0.3, "spire": 0.45, "silo": 0.0, "wind": 0.5, "mist": 0.6, "open": false, "poles": "catenary"},
	"K9": {"name": "큰 도시 외곽과 운하", "forest": 0.15, "conifer": 0.3, "birch": 0.4, "water": 0.45, "town": 0.95, "hills": 0.0, "spire": 0.25, "silo": 0.1, "wind": 0.5, "mist": 0.5, "open": false, "poles": "catenary"},
	"K10": {"name": "브란덴부르크 북동부 호수와 숲", "forest": 0.85, "conifer": 0.45, "birch": 0.3, "water": 0.75, "town": 0.15, "hills": 0.45, "spire": 0.35, "silo": 0.0, "wind": 0.5, "mist": 0.5, "open": false, "poles": "catenary"},
	"K11": {"name": "포어포메른 늪과 보덴 해안", "forest": 0.15, "conifer": 0.5, "birch": 0.4, "water": 0.85, "town": 0.25, "hills": 0.0, "spire": 0.55, "silo": 0.1, "wind": 0.9, "mist": 0.65, "open": true, "poles": "catenary"},
	"K12": {"name": "뤼겐", "forest": 0.35, "conifer": 0.85, "birch": 0.2, "water": 0.9, "town": 0.2, "hills": 0.2, "spire": 0.3, "silo": 0.0, "wind": 0.9, "mist": 0.5, "open": true, "poles": "catenary"},
}

# Region-band hue, saturation and haze (decision 494); keep the light's luminance.
# K1 is the reference: the user's low cold sun (2026-10-17) stays as it is there.
const REGION_LOOK: Dictionary = {
	"K1": {"light": Color(1.0, 1.0, 1.0), "shade": Color(1.0, 1.0, 1.0), "sat": 1.0, "haze": 0.0},
	"K2": {"light": Color(1.02, 1.04, 0.92), "shade": Color(0.95, 1.04, 0.97), "sat": 0.88, "haze": 0.08},
	"K3": {"light": Color(0.97, 1.0, 1.05), "shade": Color(0.92, 0.98, 1.08), "sat": 1.03, "haze": -0.03},
	"K4": {"light": Color(1.06, 1.03, 0.9), "shade": Color(0.97, 1.03, 0.97), "sat": 1.02, "haze": -0.04},
	"K5": {"light": Color(1.02, 1.0, 0.97), "shade": Color(1.01, 0.98, 0.99), "sat": 0.9, "haze": 0.02},
	"K6": {"light": Color(0.99, 1.0, 1.02), "shade": Color(0.95, 1.0, 1.05), "sat": 0.86, "haze": 0.06},
	"K7": {"light": Color(1.06, 1.02, 0.9), "shade": Color(1.0, 0.99, 0.96), "sat": 0.95, "haze": -0.02},
	"K8": {"light": Color(1.03, 0.99, 0.96), "shade": Color(1.02, 0.96, 1.04), "sat": 0.96, "haze": 0.02},
	"K9": {"light": Color(0.98, 1.0, 1.03), "shade": Color(0.94, 0.98, 1.06), "sat": 0.85, "haze": 0.02},
	"K10": {"light": Color(1.01, 1.02, 0.97), "shade": Color(0.95, 1.03, 1.0), "sat": 0.96, "haze": 0.02},
	"K11": {"light": Color(1.07, 1.02, 0.88), "shade": Color(0.9, 0.98, 1.1), "sat": 1.0, "haze": 0.03},
	"K12": {"light": Color(0.99, 1.01, 1.05), "shade": Color(1.03, 0.99, 0.97), "sat": 0.92, "haze": 0.04},
}
const DEFAULT_REGION := "K1"


## "K4", "k4" and the train's "region_04" all name K4. Unknown names are K1.
static func region_key(name: String) -> String:
	var n := name.strip_edges().to_upper()
	if n.begins_with("REGION_"):
		n = "K" + str(int(n.substr(7)))
	return n if REGIONS.has(n) else DEFAULT_REGION


static func region(name: String) -> Dictionary:
	return REGIONS[region_key(name)]


static func region_look(name: String) -> Dictionary:
	var row: Dictionary = REGION_LOOK[region_key(name)]
	return row.duplicate(true)


# ------------------------------------------------------------------ the light

## Each hour band under a clear sky at the coldest. zenith, horizon: the sky
## straight up and at the line. glow: round the sun. sun, ambient: light
## colour and energy. The day band keeps the user's low cold sun (10-17) and
## FxState's energy; dawn leans gold and pink, dusk orange and violet, night is
## dark. Saturation stays under BAND_SAT (no loud sky blue: blue is the
## support gauge's colour; red stays for discontent).
## Night light (sun, ambient): a neutral, faintly warm grey at the old blue's
## brightness, so the only colour after dark is the lamps' and the lit windows'
## orange (the reference's night: darkness and warm lights, not a blue screen).
const BANDS: Dictionary = {
	"night": {"zenith": Color(0.035, 0.045, 0.075), "horizon": Color(0.075, 0.085, 0.115), "glow": Color(0.16, 0.18, 0.24),
		"sun": Color(0.642, 0.639, 0.633), "sun_energy": 0.06, "ambient": Color(0.296, 0.291, 0.285), "ambient_energy": 0.16},
	"dawn": {"zenith": Color(0.24, 0.27, 0.38), "horizon": Color(0.86, 0.62, 0.52), "glow": Color(1.0, 0.70, 0.46),
		"sun": Color(1.0, 0.76, 0.56), "sun_energy": 0.55, "ambient": Color(0.58, 0.52, 0.62), "ambient_energy": 0.40},
	"day": {"zenith": Color(0.47, 0.55, 0.66), "horizon": Color(0.76, 0.78, 0.80), "glow": Color(0.95, 0.94, 0.90),
		"sun": Color(0.80, 0.85, 0.92), "sun_energy": 0.70, "ambient": Color(0.56, 0.60, 0.67), "ambient_energy": 0.26},
	# Dusk light (sun, ambient): the clear sunset sky photo's own light at our
	# brightness: a softened orange sun, the shade lit by the open sky's cool blue
	# (the old orange sun and warm shade made the whole ground one brown).
	# Energy: the reference keeps 0.8 of the day's light at dusk; ours kept under
	# half, and an overcast dusk read as night (V 0.23 against its 0.26).
	"dusk": {"zenith": Color(0.20, 0.18, 0.32), "horizon": Color(0.90, 0.52, 0.32), "glow": Color(1.0, 0.56, 0.30),
		"sun": Color(0.86, 0.70, 0.47), "sun_energy": 0.55, "ambient": Color(0.48, 0.47, 0.55), "ambient_energy": 0.46},
}
## The same bands at the warmest: softer, greener fill and a warmer day sun.
const WARM_BANDS: Dictionary = {
	# Late autumn's night fill a shade over the winter's (the same neutral grey): with no
	# snow to give the moon back, the bare ground under a clear sky kept three quarters of
	# the first stop under V 0.15 (decision 470 night line: 0.70 at most; reference 0.67).
	# Raised again after the ground layers (decision 496) darkened the bare ground: 0.312 → 0.345.
	"night": {"zenith": Color(0.04, 0.045, 0.06), "horizon": Color(0.08, 0.085, 0.095), "ambient": Color(0.345, 0.340, 0.333)},
	"dawn": {"zenith": Color(0.30, 0.31, 0.38), "horizon": Color(0.88, 0.66, 0.50), "ambient": Color(0.52, 0.50, 0.52)},
	# Late autumn's day sun a neutral, faintly green white (decision 499): the old warm
	# (0.96, 0.92, 0.82) turned the faded grass yellow under a clear sky (a green share of
	# 0.04 at the first stop against 0.15~0.25); the warmth stays at dawn and dusk.
	"day": {"zenith": Color(0.50, 0.56, 0.62), "horizon": Color(0.78, 0.78, 0.74), "sun": Color(0.88, 0.90, 0.88), "ambient": Color(0.54, 0.57, 0.54)},
	# Late autumn's low sun is warmer than winter's, as the reference's season
	# palette has it (fall dusk far more orange than winter dusk): more colour
	# (saturation 0.55 against 0.45) at the same brightness, but kept amber (hue
	# 30 degrees): a redder sun turned the lit ground pink. The shade stays the
	# sky's cool blue, so the ground does not go one brown.
	"dusk": {"zenith": Color(0.26, 0.21, 0.30), "horizon": Color(0.90, 0.56, 0.34), "sun": Color(0.93, 0.67, 0.42), "ambient": Color(0.43, 0.43, 0.50)},
}
## Most saturation a band colour may carry, and how much colour (chroma, max
## minus min) a bluish one may: sky blue is the support gauge's (tests keep both).
const BAND_SAT := 0.72
const SKY_BLUE_CHROMA := 0.22

## What each weather drawn does to the sky and light. cloud: cover 0..1 (clear
## keeps broken cloud, so shadows cross the ground). sun: what is left of the
## direct sun. fill: the flat light grey skies give back. veil: how far the sky
## goes to veil_color. haze: how much distance fades. fall: how hard it falls.
const WEATHER: Dictionary = {
	"clear": {"cloud": 0.28, "sun": 1.35, "fill": 1.0, "veil": 0.0, "veil_color": Color(0.7, 0.72, 0.75), "haze": 0.18, "fall": 0.0},
	"overcast": {"cloud": 0.95, "sun": 0.38, "fill": 1.25, "veil": 0.78, "veil_color": Color(0.50, 0.52, 0.55), "haze": 0.45, "fall": 0.0},
	"fog": {"cloud": 0.85, "sun": 0.45, "fill": 1.2, "veil": 0.85, "veil_color": Color(0.64, 0.65, 0.66), "haze": 0.9, "fall": 0.0},
	"snow": {"cloud": 0.92, "sun": 0.42, "fill": 1.2, "veil": 0.82, "veil_color": Color(0.58, 0.61, 0.66), "haze": 0.6, "fall": 0.55},
	"blizzard": {"cloud": 1.0, "sun": 0.16, "fill": 0.95, "veil": 0.93, "veil_color": Color(0.70, 0.73, 0.77), "haze": 0.95, "fall": 1.0},
	"sleet": {"cloud": 0.96, "sun": 0.32, "fill": 1.15, "veil": 0.86, "veil_color": Color(0.44, 0.46, 0.48), "haze": 0.55, "fall": 0.6},
	# Rain is the first stop's weather (late autumn +6 C): the fill makes up at dusk
	# and night what the wet ground and models take (by day the closed sky's give-back
	# sets the light), and the veil a grey near the overcast's (decision 470: dusk V
	# 0.211 and night dark share 0.76 missed the lines 0.25 and 0.70).
	"rain": {"cloud": 0.96, "sun": 0.3, "fill": 1.45, "veil": 0.86, "veil_color": Color(0.48, 0.51, 0.54), "haze": 0.55, "fall": 0.7},
}

## Photo skies (CC0, Poly Haven, 사용자 10-25 공개 자산 먼저; made by tools/atmo_textures.gd from
## originals outside the repository): the cloud shapes behind the train and in
## the field's puddles. The hour's colour still comes from BANDS: a photo only
## lends its clouds, and a little of its own colour (hue). source: the Poly
## Haven name. Kloppenheim is a village near Frankfurt, the right latitude.
const SKY_PHOTOS: Dictionary = {
	"dawn": {"source": "kloppenheim_06_puresky", "hue": 0.45},
	"day": {"source": "kloppenheim_05_puresky", "hue": 0.25},
	"dusk": {"source": "belfast_sunset_puresky", "hue": 0.45},
	"night": {"source": "kloppenheim_02_puresky", "hue": 0.2},
	"overcast": {"source": "overcast_soil_puresky", "hue": 0.2},
	"snow": {"source": "snow_field_2_puresky", "hue": 0.2},
	"mist": {"source": "kloofendal_misty_morning_puresky", "hue": 0.2},
}
## Which photo a closed sky takes, by what is drawn (the heaviest first).
const WEATHER_SKY: Array = [["fog", "mist"], ["blizzard", "snow"], ["snow", "snow"], ["sleet", "overcast"], ["rain", "overcast"], ["overcast", "overcast"]]
## The field's ground detail (R snow, G autumn leaf, B wet soil, A grit).
const GROUND_DETAIL := "res://fx/textures/ground_detail.png"
static var _sky_cache: Dictionary = {}


static func sky_path(key: String) -> String:
	return "res://fx/textures/sky/sky_%s.jpg" % key


## The photo skies a look mixes, as [[key, weight], ...] adding up to 1: the
## two strongest hour bands, and the closed sky's photo as far as it is veiled.
static func sky_photos(w: Dictionary, drawn: Array, veil: float) -> Array:
	var bands: Array = ["dawn", "day", "dusk", "night"]
	bands.sort_custom(func(a, b): return float(w[a]) > float(w[b]))
	var a := float(w[bands[0]])
	var b := float(w[bands[1]])
	var open := 1.0 - clampf(veil, 0.0, 1.0)
	var out: Array = [[bands[0], open * a / maxf(a + b, 0.0001)], [bands[1], open * b / maxf(a + b, 0.0001)]]
	var closed := "overcast"
	for row in WEATHER_SKY:
		if drawn.has(row[0]):
			closed = row[1]
			break
	out.append([closed, 1.0 - open])
	return out


## The photo with the most weight (what the field's puddles give back).
static func sky_main(l: Dictionary) -> String:
	var best: Array = ["day", -1.0]
	for row in l.get("skies", []):
		if float(row[1]) > float(best[1]):
			best = row
	return String(best[0])


## A photo sky as a texture, loaded once (null if it is not in this build).
static func sky_texture(key: String) -> Texture2D:
	if not _sky_cache.has(key):
		var path := sky_path(key)
		_sky_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _sky_cache[key]

## What the rules' weather falls as at this picture temperature (the user's
## 10-24 answer: what falls goes by the temperature): snow, sleet and rain are
## rain when it is warm, sleet around zero, snow in hard cold; a blizzard is
## rain or sleet when it is warm. Clear, overcast and fog stay. Unknown kinds
## go, as in weather.gd.
static func drawn_kinds(kinds: Array, temp_c: float) -> Array:
	var out: Array = []
	for k in kinds:
		var key := String(k)
		var d := key
		match key:
			"snow", "sleet", "rain":
				d = "rain" if temp_c > RAIN_ABOVE else ("sleet" if temp_c > SNOW_BELOW else "snow")
			"blizzard":
				d = "rain" if temp_c > RAIN_ABOVE else ("sleet" if temp_c > SNOW_BELOW else "blizzard")
		if WEATHER.has(d) and not out.has(d):
			out.append(d)
	return out


## How dark the hour is for the air: full night 1, dawn 0.6, dusk 0.3 of the
## band weights (the night is coldest, the dawn still cold, the dusk cooling).
static func dark_share(w: Dictionary) -> float:
	return float(w["night"]) + float(w["dawn"]) * 0.6 + float(w["dusk"]) * 0.3


## The picture temperature: the midday value (the rules' midday given as
## midday_c, else the cold's), colder at night and dawn, colder still under a
## clear night sky, held to the season table's night frost (SeasonTable.night_air,
## the same curve the field rules' air takes: 2026-10-25 user answer).
static func temp_at(cold: float, w: Dictionary, kinds: Array, side := 0.0, midday := NAN, frost := -1) -> float:
	var t := cold_key(cold, "temp", -1, side) if is_nan(midday) else midday
	var clear := kinds.is_empty() or kinds.has("clear")
	return SeasonTable.night_air(t, dark_share(w), clear, frost)


static func _mix_bands(w: Dictionary, cold: float, key: String) -> Color:
	var out := Color(0, 0, 0)
	var warm := 1.0 - clampf(cold, 0.0, 1.0)
	for k in w:
		var c: Color = BANDS[k][key]
		var wrow: Dictionary = WARM_BANDS[k]
		if wrow.has(key):
			c = c.lerp(wrow[key], warm)
		out += c * float(w[k])
	return Color(out.r, out.g, out.b, 1.0)


static func _mix_num(w: Dictionary, key: String) -> float:
	var v := 0.0
	for k in w:
		v += float(BANDS[k][key]) * float(w[k])
	return v


## How much of the clear hour's light a closed sky keeps by day before what
## falls and the wind take theirs: a little gloom of our own (the reference
## keeps it all).
const CLOUD_KEEP := 0.7


static func _lin_lum(c: Color) -> float:
	return c.srgb_to_linear().get_luminance()


## A neutral grey as bright as c (linear luminance).
static func _grey_like(c: Color) -> Color:
	var y := _lin_lum(c)
	var g := Color(y, y, y).linear_to_srgb()
	return Color(g.r, g.g, g.b, c.a)


## Colour c brought up to the brightness of `like` (linear luminance) when it
## fell below it, as far as it stays in range; never darkened.
static func _keep_lum(c: Color, like: Color) -> Color:
	var lc := c.srgb_to_linear()
	var y := lc.get_luminance()
	var want := _lin_lum(like)
	if y <= 0.0001 or y >= want:
		return c
	var k := want / y
	k = minf(k, 1.0 / maxf(lc.r, maxf(lc.g, maxf(lc.b, 0.0001))))
	var out := Color(lc.r * k, lc.g * k, lc.b * k, c.a).linear_to_srgb()
	return Color(out.r, out.g, out.b, c.a)


## Tint in linear space, restore luminance in either direction, then fit the gamut
## (look() gives back as energy what the fit takes from a sun already at full red).
static func _tint_keep(c: Color, t: Color, k: float) -> Color:
	var linear: Color = c.srgb_to_linear()
	var luminance: float = linear.get_luminance()
	if luminance <= 0.0001:
		return c
	linear = Color(
		linear.r * lerpf(1.0, t.r, k),
		linear.g * lerpf(1.0, t.g, k),
		linear.b * lerpf(1.0, t.b, k),
		c.a
	)
	var scale: float = luminance / linear.get_luminance()
	scale = minf(scale, 1.0 / maxf(linear.r, maxf(linear.g, linear.b)))
	var out: Color = Color(linear.r * scale, linear.g * scale, linear.b * scale, c.a).linear_to_srgb()
	return Color(out.r, out.g, out.b, c.a)


## How bright the band is, for veils and haze (night dark, day full).
static func _band_lum(w: Dictionary) -> float:
	return float(w["night"]) * 0.09 + float(w["dawn"]) * 0.6 + float(w["day"]) * 1.0 + float(w["dusk"]) * 0.55


# ------------------------------------------------------------------ look

## Everything the pictures read. hour: 0..24. kinds: the rules' weather (or a
## storm stage's look). region: "K1".."K12" or the train's "region_NN". cold:
## 0..1. more: "side" 0 autumn .. 1 spring (side_for), "wind" 0..1 (else the
## region's), "temp_c" (picture temperature given outright, else from cold and hour),
## "midday_c" (the rules' midday air, else the cold's), "night_frost" (1 or 0:
## the season table's night frost for this point, -1 or none: no bounds),
## "season" (the season table's name for this point, else from the cold).
static func look(hour: float, kinds: Array, region_name := DEFAULT_REGION, cold := 1.0, more := {}) -> Dictionary:
	var c := clampf(cold, 0.0, 1.0)
	var side := clampf(float(more.get("side", 0.0)), 0.0, 1.0)
	var w := band_weights(hour, c, side)
	var reg := region(region_name)
	var midday := float(more.get("midday_c", NAN))
	var temp := float(more.get("temp_c", temp_at(c, w, kinds, side, midday, int(more.get("night_frost", -1)))))
	# What falls is the midday air's for the whole stop, as in the rules (a
	# night's sleet turning to snow would take the ice underfoot away). A
	# temperature given outright decides it.
	var falls_c := temp if more.has("temp_c") else (cold_key(c, "temp", -1, side) if is_nan(midday) else midday)
	var drawn := drawn_kinds(kinds, falls_c)
	# Weather: most cloud, least sun, the heaviest veil and haze win.
	var cloud := 0.0
	var sun_k := 10.0
	var fill := 0.0
	var veil := 0.0
	var veil_color := Color(0.7, 0.72, 0.75)
	var haze := 0.12
	var fall := 0.0
	for k in drawn:
		var row: Dictionary = WEATHER[k]
		cloud = maxf(cloud, float(row["cloud"]))
		sun_k = minf(sun_k, float(row["sun"]))
		fill = maxf(fill, float(row["fill"]))
		if float(row["veil"]) > veil:
			veil = float(row["veil"])
			veil_color = row["veil_color"]
		haze = maxf(haze, float(row["haze"]))
		fall = maxf(fall, float(row["fall"]))
	if drawn.is_empty():
		cloud = float(WEATHER["clear"]["cloud"])
		fill = 1.0
		sun_k = 1.0
	haze = clampf(haze + float(reg["mist"]) * 0.15 * (1.0 - float(w["day"]) * 0.5), 0.0, 1.0)
	haze = clampf(haze + float(region_look(region_name)["haze"]), 0.0, 1.0)
	var lum := _band_lum(w)
	var zenith := _mix_bands(w, c, "zenith")
	var horizon := _mix_bands(w, c, "horizon")
	var glow := _mix_bands(w, c, "glow")
	# A grey sky keeps a little of the hour's colour low down (a warm seam at
	# dawn under the overcast), but goes the veil's grey as the sky closes.
	var veiled := veil_color * lum
	var seam := horizon.lerp(veiled, 0.55)
	zenith = zenith.lerp(veiled * 0.86, veil)
	horizon = horizon.lerp(seam, veil)
	glow = glow.lerp(seam, veil)
	var sun := _mix_bands(w, c, "sun")
	var ambient := _mix_bands(w, c, "ambient")
	var angles := sun_angles(hour, c, side)
	# The direct sun goes as the sun sinks to the line and as cloud closes.
	var up := smoothstep(-2.0, 6.0, angles.x)
	var night_part := float(w["night"])
	# The clear sky's extra sun is the day's; moonlight is there under a clear sky only.
	var sun_energy := _mix_num(w, "sun_energy") * lerpf(sun_k, minf(sun_k, 1.0), night_part) * lerpf(lerpf(0.35, 1.0, up), 1.0, night_part)
	sun_energy *= lerpf(1.0, lerpf(1.0, 0.35, cloud), night_part)
	var ambient_energy := _mix_num(w, "ambient_energy") * fill
	# Under a closed sky the fill is the sky's grey, not the band's tint. The
	# veil takes the colour, not the light: cloud greys the day as the
	# reference's cloudy palette does (CLOUD_KEEP below sets how much it dims).
	# After dark the cloud keeps the light it gives back but lends no colour:
	# the night's grey stays neutral.
	var veil_tint := veil_color.lerp(_grey_like(veil_color), night_part)
	ambient = _keep_lum(ambient.lerp(veil_tint * 0.9, veil * 0.6), ambient)
	sun = _keep_lum(sun.lerp(veil_tint.lerp(sun, 0.5), veil * 0.5), sun)
	# The region band's light (decision 494): hue and saturation, never the brightness;
	# the night keeps a third of it (its grey stays near neutral).
	var rl: Dictionary = region_look(region_name)
	var region_k: float = 1.0 - 0.7 * night_part
	var sun_lum := _lin_lum(sun)
	var ambient_lum := _lin_lum(ambient)
	sun = _tint_keep(sun, rl["light"], region_k)
	ambient = _tint_keep(ambient, rl["shade"], region_k)
	sun_energy *= sun_lum / maxf(_lin_lum(sun), 0.0001)
	ambient_energy *= ambient_lum / maxf(_lin_lum(ambient), 0.0001)
	# Never flatter than 16 degrees: the oblique field must still read its ground.
	var light_pitch := -clampf(angles.x, 16.0, 60.0)
	var light_yaw := angles.y
	if float(w["night"]) > 0.5:
		light_pitch = -40.0
		light_yaw = -20.0
	# The day is flat from the day band to the dusk band, as in the reference: a
	# low morning or afternoon sun lights the ground as this stop's noon sun would.
	# The fill makes up what the low angle takes; the long shadows stay, and dawn
	# and dusk still dim (decision 471 B0: two stops in five now come in the morning).
	var face_sin := sin(deg_to_rad(-light_pitch))
	var flat_sin := lerpf(face_sin, maxf(face_sin, sin(deg_to_rad(clampf(cold_key(c, "noon", -1, side), 16.0, 60.0)))), float(w["day"]))
	if flat_sin > face_sin:
		ambient_energy += sun_energy * (flat_sin - face_sin) * _lin_lum(sun) / maxf(_lin_lum(ambient), 0.01)
	var snow_level := 0
	var cm: float = cold_key(c, "snow_cm", 1 if bool(reg["open"]) else 0, side)
	if cm >= 15.0:
		snow_level = 2
	elif cm >= 3.0:
		snow_level = 1
	var night_w := float(w["night"]) + float(w["dawn"]) * 0.4
	var wind := float(more.get("wind", reg["wind"]))
	if drawn.has("blizzard"):
		wind = maxf(wind, 0.9)
	# By day a closed sky gives back as fill what it takes of the sun: an
	# up-facing face keeps the clear hour's light, short of what falls and the
	# wind (the reference's day light 1 − 0.15·fall − 0.2·wind) and our own gloom.
	var closed := clampf(veil / 0.75, 0.0, 1.0) * (1.0 - night_part)
	if closed > 0.0:
		var clear_sun := _mix_num(w, "sun_energy") * float(WEATHER["clear"]["sun"]) * lerpf(0.35, 1.0, up)
		var clear_face := clear_sun * flat_sin * _lin_lum(_mix_bands(w, c, "sun")) + _mix_num(w, "ambient_energy") * _lin_lum(_mix_bands(w, c, "ambient"))
		var face := sun_energy * face_sin * _lin_lum(sun) + ambient_energy * _lin_lum(ambient)
		var keep := CLOUD_KEEP * (1.0 - 0.15 * fall - 0.2 * wind)
		var short := (clear_face * keep - face) * closed
		if short > 0.0:
			ambient_energy += short / maxf(_lin_lum(ambient), 0.01)
	var falls := "none"
	for k in ["blizzard", "snow", "sleet", "rain"]:
		if drawn.has(k):
			falls = "snow" if k == "blizzard" else k
			break
	var ice := 1.0 - smoothstep(-3.0, 1.0, temp)
	var out := {
		"hour": fposmod(hour, 24.0), "band": band_of(hour, c, side), "weights": w,
		"cold": c, "side": side, "season": String(more.get("season", season_for(c, side))), "temp_c": temp, "region": region_key(region_name),
		"region_sat": float(rl["sat"]),
		"sunrise": sun_times(c, side).x, "sunset": sun_times(c, side).y,
		"sun_height": angles.x, "sun_azimuth": angles.y,
		"sun_pitch": light_pitch, "sun_yaw": light_yaw,
		"sun_color": sun, "sun_energy": sun_energy,
		"ambient_color": ambient, "ambient_energy": ambient_energy,
		"sky_top": zenith, "sky_low": horizon, "sun_glow": glow,
		"sun_visible": up * (1.0 - smoothstep(0.55, 0.95, cloud)) * (1.0 - float(w["night"])),
		"cloud": cloud, "haze": haze, "veil": veil, "lum": lum,
		"kinds": drawn, "falls": falls, "fall": fall, "storm": drawn.has("blizzard"), "wind": clampf(wind, 0.0, 1.0),
		"snow_cm": cm, "snow_level": snow_level,
		"ice": ice, "wet_ground": 1.0 - ice,
		"icicles": smoothstep(0.3, 0.9, c) * (0.4 + 0.6 * ice),
		"drip": smoothstep(-1.5, 1.0, temp) * smoothstep(0.2, 0.5, c),
		"leaves": cold_key(c, "leaves", -1, side),
		"breath": clampf(inverse_lerp(8.0, -8.0, temp), 0.0, 1.0) * (0.7 + 0.3 * night_w),
		"edge_frost": smoothstep(0.6, 1.0, c) * 0.22 * night_w + (0.08 if drawn.has("blizzard") else 0.0),
		"window_frost": smoothstep(0.3, 1.0, c),
		"lamp": FxState.LAMP,
	}
	out["grade"] = grade(out)
	out["skies"] = sky_photos(w, drawn, veil)
	out["fog_color"] = horizon.lerp(veil_color * lum, 0.5)
	# Past the map's edge: more snowy land in the same light, darker (not a void).
	var land := Color(ambient) * float(ambient_energy) * 1.7 + Color(sun) * float(sun_energy) * 0.45
	out["background"] = Color(clampf(land.r, 0.0, 1.0), clampf(land.g, 0.0, 1.0), clampf(land.b, 0.0, 1.0)) * 0.55
	return out


## How far the grade spreads the tones about its grey: 1.2 under a clear sky by
## day. A grey sky and the night spread them further, to TONE_CONTRAST_DIM: the
## light there casts little shadow of its own to tell form by, and the screen
## measured half the reference's spread (p95−p5 0.23 against 0.50 at an
## overcast noon, 0.14 against 0.38 at night). Never flatter than a clear day.
const TONE_CONTRAST := 1.2
const TONE_CONTRAST_DIM := 1.38
## Dusk spreads them further again (decision 471 B1): the low sun lights the
## pale faces and leaves the rest in shade, and the screen measured a flat middle
## (p5 0.13, p95 0.44 at an overcast dusk against the reference's 0.03 and 0.52).
## It turns about the hour's grey, which at dusk sits at the picture's mean.
const TONE_CONTRAST_DUSK := 0.35
## Under a grey dusk sky the picture the player sees (the sight mask on) sits
## under the hour's grey, so the spread would sink it: the grey drops this much
## there, and the play view keeps its mean (decision 470: not darker).
const TONE_PIVOT_DUSK_GREY := 0.04
## The view fill: in the diagonal view (decision 476) the walls turned from the
## sun fill much of the screen, and lit by the fill alone they fell under the
## grade to black (V 0.01; the reference reads both wall faces at 0.45~0.6;
## easing a grey day's spread to 1.32 lifted them too but cost the spread). A
## light from the camera's side (south-east), near level and without shadow:
## the south and east faces the camera sees take it, the ground and its shadows
## barely (sin VIEW_FILL_TILT), so the spread stays. This much by day, half at
## dawn and dusk, none at night (the night is the lamps', decision 471 B3·B4).
const VIEW_FILL := 2.0
const VIEW_FILL_TILT := 5.0
## The grey the tone turns about: 0.4 by day, lower as the hour's light goes,
## so the spread does not darken a dim picture (night stays where it was).
const TONE_PIVOT_DAY := 0.4
const TONE_PIVOT_NIGHT := 0.1
## The field's exposure (WorldEnvironment tonemap): every colour, the floors
## too (world_vis), is read as sRGB, and the hour's light alone left a mid grey
## at 0.19 and white at 0.4 on an overcast noon. 1.8 brings them near the
## reference's picture; the ground stays about where it was.
const EXPOSURE := 1.8


## The colour grade (WorldEnvironment adjustments): a tone turned about the
## hour's grey (contrast 1.2, more under a grey sky, at dusk and at night); weather and
## hour change the saturation; shadows lean to the fill's hue, lights to the sun's.
static func grade(l: Dictionary) -> Dictionary:
	var w: Dictionary = l["weights"]
	var veil := float(l["veil"])
	var spread := lerpf(TONE_CONTRAST, TONE_CONTRAST_DIM, maxf(veil, float(w["night"]))) * (1.0 + TONE_CONTRAST_DUSK * float(w["dusk"]))
	# A grey sky takes a tenth of the colour, no more: the grey is in the
	# materials already, and 0.8 left an overcast day near colourless.
	var sat := lerpf(1.0, 0.9, veil) * lerpf(1.0, 0.72, float(w["night"]))
	sat *= 1.0 + 0.1 * (float(w["dawn"]) + float(w["dusk"])) * (1.0 - veil)
	sat *= float(l.get("region_sat", 1.0))
	# Godot multiplies the brightness, then turns the contrast about 0.5 (sRGB):
	# 0.5 + k(b·c − 0.5) is the line spread·(c − pivot) + pivot when these hold.
	var pivot := lerpf(TONE_PIVOT_NIGHT, TONE_PIVOT_DAY, float(l["lum"])) - TONE_PIVOT_DUSK_GREY * float(w["dusk"]) * veil
	var k := 1.0 + 2.0 * pivot * (spread - 1.0)
	return {
		"saturation": sat,
		"contrast": k,
		"brightness": spread / k,
		"spread": spread,
		"pivot": pivot,
		"shadow": Color(l["ambient_color"]),
		"light": Color(l["sun_color"]),
		"strength": lerpf(0.5, 0.2, veil),
	}


## Light for a WorldEnvironment and sun, the same keys as FxState.lighting_for
## plus where the sun stands.
## Under a closing sky by day the light comes from the whole bright dome above:
## this much of the fill turns into the sun light, brought up high with a soft
## shadow. Ground and roofs stay as bright; walls and the sides of things fall
## darker, so an overcast has form instead of one flat grey. Fill to light about
## 35:65 and not quite overhead (-62 degrees): a light from straight above cast
## no shadow worth reading, and the overcast screen kept half the reference's spread.
const SKY_DOME_SHARE := 0.65
const SKY_DOME_PITCH := -62.0
const SKY_DOME_SHADOW := 0.5


static func light(l: Dictionary) -> Dictionary:
	var dome := smoothstep(0.45, 0.9, float(l["veil"])) * (1.0 - float(l["weights"]["night"]))
	var fill := float(l["ambient_energy"])
	var moved := fill * SKY_DOME_SHARE * dome
	var pitch := lerpf(float(l["sun_pitch"]), SKY_DOME_PITCH, dome)
	# Raised overhead, the sun keeps what it gave the ground from where it stood
	# (a low dusk sun behind cloud does not flood the yard), and the light's
	# colour is the two parts by their strength.
	var high := sin(deg_to_rad(clampf(-pitch, 5.0, 90.0)))
	var sun_part := float(l["sun_energy"]) * sin(deg_to_rad(clampf(-float(l["sun_pitch"]), 5.0, 90.0))) / high
	var dome_part := moved / high
	var color := Color(l["sun_color"])
	if sun_part + dome_part > 0.001:
		color = Color(l["sun_color"]).lerp(Color(l["ambient_color"]), dome_part / (sun_part + dome_part))
	return {
		"band": l["band"],
		"sun_color": color,
		"sun_energy": sun_part + dome_part,
		"sun_pitch": pitch,
		"sun_yaw": l["sun_yaw"],
		"shadow": lerpf(1.0, SKY_DOME_SHADOW, dome),
		"ambient_color": l["ambient_color"],
		"ambient_energy": fill - moved,
		"fill_energy": VIEW_FILL * (float(l["weights"]["day"]) + 0.5 * (float(l["weights"]["dawn"]) + float(l["weights"]["dusk"]))),
		"fill_color": color.lerp(Color(l["ambient_color"]), 0.5),
		"fog_color": l["fog_color"],
		"fog_density": 0.012 + 0.03 * float(l["haze"]),
		"background": l["background"],
		"lamp": l["lamp"],
	}


## How thick a foggy day's fog lies over the whole field (fx/map_edge.gd): 0
## without fog in the look, 1 in a thick one (the reference game's fog days
## go white; overcast and rain keep the field clear).
static func field_fog(l: Dictionary) -> float:
	if not Array(l["kinds"]).has("fog"):
		return 0.0
	return smoothstep(0.55, 0.9, float(l["haze"]))


## The fx_* shader globals for this look. FxState still makes wet, snow, frost
## and wind from what is drawn and the picture temperature; this adds the cold
## (fx_cold: cold, ice, icicles, leaves), the sky's light (fx_sky) and the
## cloud shadows (fx_cloud: cover, drift x, drift z, how much is sun).
## ground_snow < 0: from the season's lying snow.
static func params(l: Dictionary, wind_dir := Vector2(1, 0), ground_snow := -1.0) -> Dictionary:
	var season := String(l["season"])
	var snow := ground_snow
	if snow < 0.0:
		snow = FxState.snow_for_level(int(l["snow_level"]))
	var fx_season := season if FxState.SEASON_BANDS.has(season) else "deep_winter"
	var p := FxState.params_for(l["kinds"], float(l["temp_c"]), wind_dir, float(l["wind"]), float(l["hour"]), snow, fx_season)
	var lum := float(l["lum"])
	# Haze and flakes stay grey: the hour's colour comes in at a quarter.
	var grey := Color(l["sky_low"]).v
	var tint := Color(grey, grey, grey).lerp(Color(l["sky_low"]), 0.25) * lerpf(0.4, 1.0, lum)
	p["fx_tint"] = Color(tint.r, tint.g, tint.b, 1.0)
	p["fx_cold"] = Vector4(float(l["cold"]), float(l["ice"]), float(l["icicles"]), float(l["leaves"]))
	var sky: Color = Color(l["sky_low"]).lerp(Color(l["sky_top"]), 0.4)
	p["fx_sky"] = Color(sky.r, sky.g, sky.b, 1.0)
	var dir := wind_dir.normalized() if wind_dir.length() > 0.001 else Vector2(1, 0)
	var sun_share := float(l["sun_energy"]) / maxf(float(l["sun_energy"]) + float(l["ambient_energy"]), 0.01)
	var cover := float(l["cloud"])
	# Shadows cross the ground only where there are gaps to cross between.
	var shade := sun_share * (1.0 - smoothstep(0.78, 0.94, cover))
	p["fx_cloud"] = Vector4(cover, dir.x * (1.5 + 3.0 * float(l["wind"])), dir.y * (1.5 + 3.0 * float(l["wind"])), shade)
	# The sight mask by the hour's light: night (lum 0.09) as dark as before, full day lightest.
	p["fx_sight"] = FxState.sight_floor(inverse_lerp(0.09, 1.0, float(l["lum"])))
	return p
