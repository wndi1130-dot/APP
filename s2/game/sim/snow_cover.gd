extends RefCounted
## Lying snow at one stop: how deep it is and how much fell since arrival.
## Pure rules, no scene (weather_fx.md 4장). Game code advances it with the
## field clock and hands cover() to FxState.params_for as ground_snow; the
## shaders are not touched. Every number is a proposal until a play check.

## Depth on arrival by season state (seasons_regions.md 7장 thickness 0, 1, 2
## read as centimetres): [normal ground, open ground].
const SEASON_START_CM: Dictionary = {
	"deep_winter": [25.0, 25.0],
	"late_winter": [25.0, 7.0],
	"early_thaw": [7.0, 0.0],
}
const DEFAULT_SEASON := "deep_winter"
## Centimetres an hour each weather kind lays down (negative: eats snow).
const FALL_CM_H: Dictionary = {"snow": 1.0, "blizzard": 3.0, "sleet": 0.3, "rain": -2.0}
## Melt per hour for each degree above freezing.
const MELT_CM_H_PER_C: float = 0.4
const MAX_CM: float = 80.0
## cover() curve: 7 cm is about thickness 1 (0.38), 25 cm about 0.8, 40 cm 0.9.
const COVER_MAX: float = 0.95
const COVER_SCALE_CM: float = 13.5

## Total depth on undisturbed ground.
var depth_cm: float = 0.0
## What fell since arrival: this is what settles on things that came in bare
## (the train, cleared paths, footprints) and on what people disturb.
var fresh_cm: float = 0.0


func _init(season := DEFAULT_SEASON, open_ground := false) -> void:
	var row: Array = SEASON_START_CM.get(season, SEASON_START_CM[DEFAULT_SEASON])
	depth_cm = float(row[1 if open_ground else 0])


## Net change in cm per hour for this weather. Snow kinds only lay snow at or
## below freezing; above it they fall as water and the thaw runs.
static func rate_cm_h(kinds: Array, ambient_c: float) -> float:
	var rate := 0.0
	for k in kinds:
		var r := float(FALL_CM_H.get(String(k), 0.0))
		if r > 0.0 and ambient_c > 0.0:
			continue
		rate += r
	if ambient_c > 0.0:
		rate -= MELT_CM_H_PER_C * ambient_c
	return rate


## Advance by game minutes. Returns the change in depth (cm).
func advance(game_minutes: float, kinds: Array, ambient_c: float) -> float:
	if game_minutes <= 0.0:
		return 0.0
	var before := depth_cm
	var step := rate_cm_h(kinds, ambient_c) * game_minutes / 60.0
	depth_cm = clampf(depth_cm + step, 0.0, MAX_CM)
	# Fresh snow grows with snowfall and is the first to go in a thaw.
	fresh_cm = clampf(fresh_cm + step, 0.0, depth_cm)
	return depth_cm - before


static func cover_for(cm: float) -> float:
	return COVER_MAX * (1.0 - exp(-maxf(cm, 0.0) / COVER_SCALE_CM))


## 0..1 for the fx_snow shader global (FxState.params_for ground_snow).
func cover() -> float:
	return cover_for(depth_cm)


## 0..1 cover of what fell since arrival, for surfaces that started bare.
func fresh_cover() -> float:
	return cover_for(fresh_cm)
