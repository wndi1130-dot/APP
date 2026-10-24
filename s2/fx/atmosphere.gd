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
const DEFAULT_REGION := "K1"


## "K4", "k4" and the train's "region_04" all name K4. Unknown names are K1.
static func region_key(name: String) -> String:
	var n := name.strip_edges().to_upper()
	if n.begins_with("REGION_"):
		n = "K" + str(int(n.substr(7)))
	return n if REGIONS.has(n) else DEFAULT_REGION


static func region(name: String) -> Dictionary:
	return REGIONS[region_key(name)]


# ------------------------------------------------------------------ the light

## Each hour band under a clear sky at the coldest. zenith, horizon: the sky
## straight up and at the line. glow: round the sun. sun, ambient: light
## colour and energy. The day band keeps the user's low cold sun (10-17) and
## FxState's energy; dawn leans gold and pink, dusk orange and violet, night is
## moonlight. Saturation stays under BAND_SAT (no loud sky blue: blue is the
## support gauge's colour; red stays for discontent).
const BANDS: Dictionary = {
	"night": {"zenith": Color(0.035, 0.045, 0.075), "horizon": Color(0.075, 0.085, 0.115), "glow": Color(0.16, 0.18, 0.24),
		"sun": Color(0.58, 0.64, 0.78), "sun_energy": 0.06, "ambient": Color(0.26, 0.29, 0.38), "ambient_energy": 0.16},
	"dawn": {"zenith": Color(0.24, 0.27, 0.38), "horizon": Color(0.86, 0.62, 0.52), "glow": Color(1.0, 0.70, 0.46),
		"sun": Color(1.0, 0.76, 0.56), "sun_energy": 0.55, "ambient": Color(0.58, 0.52, 0.62), "ambient_energy": 0.40},
	"day": {"zenith": Color(0.47, 0.55, 0.66), "horizon": Color(0.76, 0.78, 0.80), "glow": Color(0.95, 0.94, 0.90),
		"sun": Color(0.80, 0.85, 0.92), "sun_energy": 0.70, "ambient": Color(0.56, 0.60, 0.67), "ambient_energy": 0.26},
	"dusk": {"zenith": Color(0.20, 0.18, 0.32), "horizon": Color(0.90, 0.52, 0.32), "glow": Color(1.0, 0.56, 0.30),
		"sun": Color(1.0, 0.64, 0.40), "sun_energy": 0.5, "ambient": Color(0.55, 0.45, 0.52), "ambient_energy": 0.38},
}
## The same bands at the warmest: softer, greener fill and a warmer day sun.
const WARM_BANDS: Dictionary = {
	"night": {"zenith": Color(0.04, 0.045, 0.06), "horizon": Color(0.08, 0.085, 0.095), "ambient": Color(0.25, 0.27, 0.30)},
	"dawn": {"zenith": Color(0.30, 0.31, 0.38), "horizon": Color(0.88, 0.66, 0.50), "ambient": Color(0.52, 0.50, 0.52)},
	"day": {"zenith": Color(0.50, 0.56, 0.62), "horizon": Color(0.78, 0.78, 0.74), "sun": Color(0.96, 0.92, 0.82), "ambient": Color(0.54, 0.57, 0.54)},
	"dusk": {"zenith": Color(0.26, 0.21, 0.30), "horizon": Color(0.90, 0.56, 0.34), "ambient": Color(0.48, 0.42, 0.44)},
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
	"rain": {"cloud": 0.96, "sun": 0.3, "fill": 1.1, "veil": 0.86, "veil_color": Color(0.40, 0.43, 0.46), "haze": 0.55, "fall": 0.7},
}

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


## The picture temperature: the cold's midday value, colder at night and dawn,
## colder still under a clear night sky.
static func temp_at(cold: float, w: Dictionary, kinds: Array, side := 0.0) -> float:
	var t := cold_key(cold, "temp", -1, side)
	var dark := float(w["night"]) + float(w["dawn"]) * 0.6 + float(w["dusk"]) * 0.3
	var clear := kinds.is_empty() or kinds.has("clear")
	return t - dark * (5.0 if clear else 2.5)


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


## How bright the band is, for veils and haze (night dark, day full).
static func _band_lum(w: Dictionary) -> float:
	return float(w["night"]) * 0.09 + float(w["dawn"]) * 0.6 + float(w["day"]) * 1.0 + float(w["dusk"]) * 0.55


# ------------------------------------------------------------------ look

## Everything the pictures read. hour: 0..24. kinds: the rules' weather (or a
## storm stage's look). region: "K1".."K12" or the train's "region_NN". cold:
## 0..1. more: "side" 0 autumn .. 1 spring (side_for), "wind" 0..1 (else the
## region's), "temp_c" (picture temperature given outright, else from cold and hour),
## "season" (the season table's name for this point, else from the cold).
static func look(hour: float, kinds: Array, region_name := DEFAULT_REGION, cold := 1.0, more := {}) -> Dictionary:
	var c := clampf(cold, 0.0, 1.0)
	var side := clampf(float(more.get("side", 0.0)), 0.0, 1.0)
	var w := band_weights(hour, c, side)
	var reg := region(region_name)
	var temp := float(more.get("temp_c", temp_at(c, w, kinds, side)))
	var drawn := drawn_kinds(kinds, temp)
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
	# Under a closed sky the fill is the sky's grey, not the band's tint.
	ambient = ambient.lerp(veil_color * 0.9, veil * 0.6)
	sun = sun.lerp(veil_color.lerp(sun, 0.5), veil * 0.5)
	# Never flatter than 16 degrees: the oblique field must still read its ground.
	var light_pitch := -clampf(angles.x, 16.0, 60.0)
	var light_yaw := angles.y
	if float(w["night"]) > 0.5:
		light_pitch = -40.0
		light_yaw = -20.0
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
	var falls := "none"
	for k in ["blizzard", "snow", "sleet", "rain"]:
		if drawn.has(k):
			falls = "snow" if k == "blizzard" else k
			break
	var ice := 1.0 - smoothstep(-3.0, 1.0, temp)
	var out := {
		"hour": fposmod(hour, 24.0), "band": band_of(hour, c, side), "weights": w,
		"cold": c, "side": side, "season": String(more.get("season", season_for(c, side))), "temp_c": temp, "region": region_key(region_name),
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
	out["fog_color"] = horizon.lerp(veil_color * lum, 0.5)
	# Past the map's edge: more snowy land in the same light, darker (not a void).
	var land := Color(ambient) * float(ambient_energy) * 1.7 + Color(sun) * float(sun_energy) * 0.45
	out["background"] = Color(clampf(land.r, 0.0, 1.0), clampf(land.g, 0.0, 1.0), clampf(land.b, 0.0, 1.0)) * 0.55
	return out


## The colour grade (WorldEnvironment adjustments): weather and hour change
## saturation and contrast; shadows lean to the fill's hue, lights to the sun's.
static func grade(l: Dictionary) -> Dictionary:
	var w: Dictionary = l["weights"]
	var veil := float(l["veil"])
	var sat := lerpf(1.08, 0.8, veil) * lerpf(1.0, 0.72, float(w["night"]))
	sat *= 1.0 + 0.1 * (float(w["dawn"]) + float(w["dusk"])) * (1.0 - veil)
	var contrast := lerpf(1.08, 0.94, maxf(veil, float(l["haze"]) * 0.8))
	return {
		"saturation": sat,
		"contrast": contrast,
		"brightness": 1.0,
		"shadow": Color(l["ambient_color"]),
		"light": Color(l["sun_color"]),
		"strength": lerpf(0.5, 0.2, veil),
	}


## Light for a WorldEnvironment and sun, the same keys as FxState.lighting_for
## plus where the sun stands.
static func light(l: Dictionary) -> Dictionary:
	return {
		"band": l["band"],
		"sun_color": l["sun_color"],
		"sun_energy": l["sun_energy"],
		"sun_pitch": l["sun_pitch"],
		"sun_yaw": l["sun_yaw"],
		"ambient_color": l["ambient_color"],
		"ambient_energy": l["ambient_energy"],
		"fog_color": l["fog_color"],
		"fog_density": 0.012 + 0.03 * float(l["haze"]),
		"background": l["background"],
		"lamp": l["lamp"],
	}


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
	return p
