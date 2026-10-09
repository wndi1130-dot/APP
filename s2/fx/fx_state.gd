extends RefCounted
## The one writer of the fx_* shader globals (project.godot [shader_globals]).
## Game code says what the stop is like (weather kinds, temperature, wind,
## hour, lying snow) and this turns it into shader values and light colours.
## Rules: docs/design/briefs/shaders.md. Weather kinds follow
## game/sim/weather.gd; "rain" and "overcast" are accepted for the thaw and
## other seasons and unknown kinds are ignored, like weather.gd does.
## Numbers here are proposals (shaders.md 4장) until a play check fixes them.

const GLOBALS: Array[String] = ["fx_wet", "fx_snow", "fx_frost", "fx_wind", "fx_tint", "fx_flash", "fx_fade"]

## How wet each kind leaves surfaces (0..1). Fog only dampens.
const WET: Dictionary = {"rain": 1.0, "sleet": 0.75, "fog": 0.25, "overcast": 0.1}
## Colour washed over sky, haze and particles. Grey and grey-blue only:
## sky blue is kept for support (decisions.md 날씨와 빛).
const KIND_TINT: Dictionary = {
	"clear": Color(0.78, 0.79, 0.80),
	"overcast": Color(0.66, 0.67, 0.68),
	"fog": Color(0.70, 0.71, 0.72),
	"snow": Color(0.72, 0.73, 0.75),
	"blizzard": Color(0.62, 0.64, 0.67),
	"sleet": Color(0.60, 0.62, 0.63),
	"rain": Color(0.56, 0.58, 0.59),
}

## Hour bands (presentation_motion.md 정차 변주 축 가: dawn grey-blue, day
## lead-grey, dusk amber windows, night lamps and torches only).
## sun: directional light colour and energy, ambient: fill colour and energy.
const BAND_LOOK: Dictionary = {
	"night": {"name": "night", "sun": Color(0.58, 0.6, 0.64), "sun_energy": 0.05, "ambient": Color(0.31, 0.32, 0.345), "ambient_energy": 0.16, "tint": Color(0.33, 0.34, 0.36)},
	"dawn": {"name": "dawn", "sun": Color(0.76, 0.77, 0.79), "sun_energy": 0.32, "ambient": Color(0.53, 0.55, 0.58), "ambient_energy": 0.36, "tint": Color(0.62, 0.64, 0.67)},
	"day": {"name": "day", "sun": Color(0.84, 0.84, 0.85), "sun_energy": 0.55, "ambient": Color(0.60, 0.61, 0.63), "ambient_energy": 0.45, "tint": Color(0.76, 0.76, 0.77)},
	"dusk": {"name": "dusk", "sun": Color(0.80, 0.70, 0.58), "sun_energy": 0.32, "ambient": Color(0.46, 0.46, 0.48), "ambient_energy": 0.32, "tint": Color(0.60, 0.58, 0.56)},
}

## Where each band starts (hours) per season state, from sunrise and sunset
## (seasons_regions.md 7장): dawn 1 h before sunrise, day 30 min after it,
## dusk 1 h before sunset, night 40 min after it.
const SEASON_BANDS: Dictionary = {
	"deep_winter": {"dawn": 7.0, "day": 8.5, "dusk": 14.0 + 50.0 / 60.0, "night": 16.5},
	"late_winter": {"dawn": 6.5, "day": 8.0, "dusk": 15.5, "night": 17.0 + 10.0 / 60.0},
	"early_thaw": {"dawn": 5.75, "day": 7.25, "dusk": 16.25, "night": 17.0 + 55.0 / 60.0},
}
const DEFAULT_SEASON := "deep_winter"

## Snow thickness level by season state (seasons_regions.md 7장). open_ground:
## wind-scoured plain (late winter) or sunny, slushy ground (early thaw).
const SEASON_SNOW: Dictionary = {
	"deep_winter": [2, 2],
	"late_winter": [2, 1],
	"early_thaw": [1, 0],
}

## Lying snow by the season design's three thicknesses (seasons_regions.md
## 7장: 0 none, 1 a crust on flat tops, 2 deep snow that also takes slopes).
const SNOW_LEVELS: Array[float] = [0.0, 0.38, 0.9]

## Lamp light inside cars and houses: amber, the one warm colour outside.
const LAMP := Color(1.0, 0.64, 0.30)


static func snow_for_level(level: int) -> float:
	return SNOW_LEVELS[clampi(level, 0, SNOW_LEVELS.size() - 1)]


static func snow_level_for(season: String, open_ground := false) -> int:
	var row: Array = SEASON_SNOW.get(season, SEASON_SNOW[DEFAULT_SEASON])
	return int(row[1 if open_ground else 0])


static func hour_band(hour: float, season := DEFAULT_SEASON) -> Dictionary:
	var starts: Dictionary = SEASON_BANDS.get(season, SEASON_BANDS[DEFAULT_SEASON])
	var h := fposmod(hour, 24.0)
	if h >= float(starts["night"]) or h < float(starts["dawn"]):
		return BAND_LOOK["night"]
	if h >= float(starts["dusk"]):
		return BAND_LOOK["dusk"]
	if h >= float(starts["day"]):
		return BAND_LOOK["day"]
	return BAND_LOOK["dawn"]


## Shader globals for a stop. ground_snow < 0 means "guess from temperature";
## pass snow_for_level(snow_level_for(season, open_ground)) from the season state.
static func params_for(kinds: Array, ambient_c: float, wind_dir := Vector2(1, 0), wind := 0.4, hour := 12.0, ground_snow := -1.0, season := DEFAULT_SEASON) -> Dictionary:
	var known: Array[String] = []
	for k in kinds:
		var key := String(k)
		if KIND_TINT.has(key):
			known.append(key)
	var wet := 0.0
	for k in known:
		wet = maxf(wet, float(WET.get(k, 0.0)))
	# Nothing stays wet below -3 C: water is ice (weather.gd SLEET_MIN_C).
	if ambient_c < -3.0:
		wet = minf(wet, 0.25)
	var snow := ground_snow
	if snow < 0.0:
		snow = clampf((1.0 - ambient_c) / 6.0, 0.0, 0.8) if ambient_c < 1.0 else 0.0
	if known.has("blizzard"):
		snow = maxf(snow, 0.9)
	elif known.has("snow"):
		snow = maxf(snow, 0.6)
	if known.has("rain"):
		snow *= 0.5 # rain eats lying snow into slush
	var frost := clampf((-ambient_c - 2.0) / 16.0, 0.0, 1.0)
	var tint := Color(0.72, 0.73, 0.75)
	if not known.is_empty():
		tint = KIND_TINT[known[0]]
		for k in known:
			# Darkest weather wins the wash.
			if KIND_TINT[k].v < tint.v:
				tint = KIND_TINT[k]
	var band := hour_band(hour, season)
	tint = tint * Color(band["tint"])
	var dir := wind_dir.normalized() if wind_dir.length() > 0.001 else Vector2(1, 0)
	return {
		"fx_wet": clampf(wet, 0.0, 1.0),
		"fx_snow": clampf(snow, 0.0, 1.0),
		"fx_frost": frost,
		"fx_wind": Vector3(dir.x, dir.y, clampf(wind, 0.0, 1.0)),
		"fx_tint": Color(tint.r, tint.g, tint.b, 1.0),
		"fx_flash": 0.0,
		"fx_fade": 0.0,
	}


## Light and fog for the WorldEnvironment and sun of a stop at this hour.
static func lighting_for(kinds: Array, hour := 12.0, season := DEFAULT_SEASON) -> Dictionary:
	var band := hour_band(hour, season)
	var dim := 1.0
	for k in kinds:
		match String(k):
			"fog", "overcast":
				dim = minf(dim, 0.8)
			"snow", "sleet", "rain":
				dim = minf(dim, 0.75)
			"blizzard":
				dim = minf(dim, 0.6)
	var foggy := kinds.has("fog") or kinds.has("blizzard")
	return {
		"band": band["name"],
		"sun_color": band["sun"],
		"sun_energy": float(band["sun_energy"]) * dim,
		"ambient_color": band["ambient"],
		"ambient_energy": float(band["ambient_energy"]) * lerpf(1.0, dim, 0.5),
		"fog_color": Color(band["tint"]).darkened(0.1),
		# Depth fog is off on the oblique field camera (field_game.gd); scenes
		# with a horizon (stop arrival, running train) use this density.
		"fog_density": 0.03 if foggy else 0.012,
		"lamp": LAMP,
	}


## Write params into the shader globals. Unknown keys are ignored.
## Returns the keys written.
static func apply(params: Dictionary) -> Array[String]:
	var written: Array[String] = []
	for key in GLOBALS:
		if params.has(key):
			RenderingServer.global_shader_parameter_set(key, params[key])
			written.append(key)
	return written
