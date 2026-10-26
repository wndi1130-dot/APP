extends RefCounted
## The one writer of the fx_* shader globals (project.godot [shader_globals]).
## Game code says what the stop is like (weather kinds, temperature, wind,
## hour, lying snow) and this turns it into shader values and light colours.
## Rules: docs/design/briefs/shaders.md. Weather kinds follow
## game/sim/weather.gd; "rain" and "overcast" are accepted for the thaw and
## other seasons and unknown kinds are ignored, like weather.gd does.
## Numbers here are proposals (shaders.md 4장) until a play check fixes them.

## fx_cold, fx_sky, fx_cloud and fx_sight belong to the atmosphere frame (fx/atmosphere.gd):
## params_for gives plain values from the temperature and hour, Atmosphere.params the real ones.
const GLOBALS: Array[String] = ["fx_wet", "fx_snow", "fx_frost", "fx_wind", "fx_tint", "fx_flash", "fx_fade", "fx_cold", "fx_sky", "fx_cloud", "fx_sight"]
## Texture globals (CC0 photos, 사용자 10-25 공개 자산 먼저): the ground's grain stays as
## project.godot sets it; the photo sky follows the look (set_sky).
const TEXTURE_GLOBALS: Array[String] = ["fx_ground", "fx_sky_tex"]

enum BloodLevel { OFF, LOW, NORMAL, HIGH }
const BLOOD_LABELS: Array[String] = ["끔", "적게", "보통", "많이"]
## 피·타격 효과(짧게 튀는 CPU 입자)가 한꺼번에 쓸 수 있는 입자 수. 날씨 입자는
## 폰에서 이미 잰 값이라 여기서 줄이지 않는다.
const TRANSIENT_PARTICLES := 120
static var blood_level: int = BloodLevel.NORMAL
static var _particle_leases: Dictionary = {}
static var _blood_clients: Array[WeakRef] = []


static func set_blood_level(level: int) -> void:
	blood_level = clampi(level, BloodLevel.OFF, BloodLevel.HIGH)
	for i in range(_blood_clients.size() - 1, -1, -1):
		var client = _blood_clients[i].get_ref()
		if client == null:
			_blood_clients.remove_at(i)
		elif blood_level == BloodLevel.OFF:
			client.clear()


static func register_blood_client(client: Node) -> void:
	_blood_clients.append(weakref(client))


static func blood_scale() -> float:
	return [0.0, 0.4, 1.0, 1.5][clampi(blood_level, 0, 3)]


static func leased_particles() -> int:
	var total := 0
	for key in _particle_leases.keys():
		if _particle_leases[key]["owner"].get_ref() == null:
			_particle_leases.erase(key)
		else:
			total += int(_particle_leases[key]["count"])
	return total


static func lease_particles(owner: Node, requested: int) -> int:
	release_particles(owner)
	var count := clampi(requested, 0, maxi(0, TRANSIENT_PARTICLES - leased_particles()))
	if count > 0:
		_particle_leases[owner.get_instance_id()] = {"owner": weakref(owner), "count": count}
	return count


static func release_particles(owner: Node) -> void:
	_particle_leases.erase(owner.get_instance_id())

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

## How bright the sight mask leaves ground the eye does not reach now (fx_sight:
## x never seen, y seen before; seen now is full). By day the ground out of sight
## stays readable, its shapes and paths still there to choose a way by. After
## dark it is dimmed less, not more: the night is dark already, and pressing it
## a second time left a black screen round the lamp (play screen at night 87%
## dark cells at 0.24, against the reference's 67%; decision 469 D3).
const SIGHT_DAY := Vector2(0.55, 0.75)
const SIGHT_NIGHT := Vector2(0.60, 0.78)


## The sight mask's floors at this much daylight (0 night .. 1 full day).
static func sight_floor(daylight: float) -> Vector2:
	return SIGHT_NIGHT.lerp(SIGHT_DAY, clampf(daylight, 0.0, 1.0))


## Hour bands (presentation_motion.md 정차 변주 축 가: dawn grey-blue, day
## lead-grey, dusk amber windows, night lamps and torches only).
## sun: directional light colour and energy, ambient: fill colour and energy.
const BAND_LOOK: Dictionary = {
	"night": {"name": "night", "sun": Color(0.58, 0.6, 0.64), "sun_energy": 0.05, "ambient": Color(0.31, 0.32, 0.345), "ambient_energy": 0.16, "tint": Color(0.33, 0.34, 0.36)},
	"dawn": {"name": "dawn", "sun": Color(0.76, 0.77, 0.79), "sun_energy": 0.32, "ambient": Color(0.53, 0.55, 0.58), "ambient_energy": 0.36, "tint": Color(0.62, 0.64, 0.67)},
	# Day: more sun, less fill so the low sun's shadows read on the snow (decisions 323, 337).
	"day": {"name": "day", "sun": Color(0.80, 0.85, 0.92), "sun_energy": 0.70, "ambient": Color(0.60, 0.61, 0.63), "ambient_energy": 0.25, "tint": Color(0.76, 0.76, 0.77)},
	"dusk": {"name": "dusk", "sun": Color(0.80, 0.70, 0.58), "sun_energy": 0.32, "ambient": Color(0.46, 0.46, 0.48), "ambient_energy": 0.32, "tint": Color(0.60, 0.58, 0.56)},
}

## Low cold winter sun (user, 2026-10-17): degrees below level for the sun
## in every scene (field, stop, home, gallery). Storm stages set their own.
## The day sun colour above is the cold one of the same decision.
const SUN_PITCH := -35.0

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

## Model colour grade, the defaults of weathered.gdshader (user, 2026-10-17):
## models are pressed darker and colder so they do not stand out on white snow,
## and are not repainted. Roughness 0.9 is weathered's roughness_base default.
const MODEL_GRADE: Dictionary = {
	"grade_saturation": 0.45,
	"grade_value": 0.82,
	"grade_cool": Color(0.78, 0.85, 0.95),
	"grade_cool_mix": 0.35,
}
const MODEL_ROUGHNESS := 0.9


## The same sum as fx_model_grade in fx_common.gdshaderinc, for tests and tools.
static func grade_color(c: Color, g: Dictionary = MODEL_GRADE) -> Color:
	var v := maxf(c.r, maxf(c.g, c.b))
	var sat := float(g["grade_saturation"])
	var val := float(g["grade_value"])
	var cool: Color = g["grade_cool"]
	var k := float(g["grade_cool_mix"])
	var out := Color(lerpf(v, c.r, sat), lerpf(v, c.g, sat), lerpf(v, c.b, sat)) * val
	out = Color(lerpf(out.r, out.r * cool.r, k), lerpf(out.g, out.g * cool.g, k), lerpf(out.b, out.b * cool.b, k))
	return Color(out.r, out.g, out.b, c.a)


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
	# Nothing stays wet below -3 C: water is ice (weather.gd falls by the air).
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
	# Plain atmosphere values from the temperature alone: cold +6 C .. -14 C,
	# standing water frozen below about -1 C, no cloud shadows.
	var cold := clampf((6.0 - ambient_c) / 20.0, 0.0, 1.0)
	var ice := 1.0 - smoothstep(-3.0, 1.0, ambient_c)
	return {
		"fx_wet": clampf(wet, 0.0, 1.0),
		"fx_snow": clampf(snow, 0.0, 1.0),
		"fx_frost": frost,
		"fx_wind": Vector3(dir.x, dir.y, clampf(wind, 0.0, 1.0)),
		"fx_tint": Color(tint.r, tint.g, tint.b, 1.0),
		"fx_flash": 0.0,
		"fx_fade": 0.0,
		"fx_cold": Vector4(cold, ice, 0.0, 0.0),
		"fx_sky": Color(tint.r, tint.g, tint.b, 1.0),
		"fx_cloud": Vector4(0.0, dir.x, dir.y, 0.0),
		"fx_sight": sight_floor(float({"day": 1.0, "dawn": 0.5, "dusk": 0.5}.get(band["name"], 0.0))),
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
## The photo sky the field's water gives back; nothing happens without one.
static func set_sky(tex: Texture2D) -> bool:
	if tex == null:
		return false
	RenderingServer.global_shader_parameter_set("fx_sky_tex", tex)
	return true


## The seconds the field has stood paused (pause_veil.gd); not a weather value,
## so it is not in GLOBALS and a stop's params leave it alone.
static func set_still(seconds: float) -> void:
	RenderingServer.global_shader_parameter_set("fx_still", seconds)


static func apply(params: Dictionary) -> Array[String]:
	var written: Array[String] = []
	for key in GLOBALS:
		if params.has(key):
			RenderingServer.global_shader_parameter_set(key, params[key])
			written.append(key)
	return written
