extends RefCounted
## Decision 486: four home stages, each with day and night light.
## Lamp0 stays at the car's midpoint for train_scene's sway.

const STAGE_NAMES: Array[String] = ["rag", "mended", "furnished", "nordic"]
const STAGE_DEFAULT: int = 1
const LAMP_TOP: float = 2.1        # The diagonal view lifts the roof at 2.2 m.
const CALM_ENERGY: float = 1.3     # train_look.gd MOOD_LOOK calm energy.
const LOOK_TINT: float = 0.35
const WINDOW_SHARES: Array[float] = [0.3, 0.7]
const WINDOW_AT := Vector2(1.1, -1.0) # y, z: snow light comes up from below.

const STAGES: Array[Dictionary] = [
	{
		"stove": 0.7,
		"night": {
			"lamps": [
				{"at": Vector3(0.5, 0.95, -0.6), "kind": "candle", "kelvin": 1850.0,
					"energy": 0.75, "range": 5.5, "shadow": true, "sway": 0.3},
				{"at": Vector3(0.22, 0.8, -0.7), "kind": "candle", "kelvin": 1850.0,
					"energy": 0.25, "range": 3.0, "shadow": false, "sway": 0.3},
			],
			"window": {"kelvin": 9000.0, "energy": 0.08, "range": 4.0},
		},
		"day": {
			"lamps": [
				{"at": Vector3(0.5, 0.95, -0.6), "kind": "candle", "kelvin": 1850.0,
					"energy": 0.0, "range": 3.5, "shadow": true, "sway": 0.3},
				{"at": Vector3(0.22, 0.8, -0.7), "kind": "candle", "kelvin": 1850.0,
					"energy": 0.0, "range": 3.0, "shadow": false, "sway": 0.3},
			],
			"window": {"kelvin": 7000.0, "energy": 0.5, "range": 4.0},
		},
	},
	{
		"stove": 1.0,
		"night": {
			"lamps": [
				{"at": Vector3(0.5, 2.0, 0.0), "kind": "kerosene", "kelvin": 2000.0,
					"energy": 1.2, "range": 7.0, "shadow": true, "sway": 1.0},
				{"at": Vector3(0.15, 0.85, -0.7), "kind": "candle", "kelvin": 1850.0,
					"energy": 0.3, "range": 3.0, "shadow": false, "sway": 0.3},
			],
			"window": {"kelvin": 9000.0, "energy": 0.1, "range": 4.5},
		},
		"day": {
			"lamps": [
				{"at": Vector3(0.5, 2.0, 0.0), "kind": "kerosene", "kelvin": 2000.0,
					"energy": 0.2, "range": 7.0, "shadow": true, "sway": 1.0},
				{"at": Vector3(0.15, 0.85, -0.7), "kind": "candle", "kelvin": 1850.0,
					"energy": 0.0, "range": 3.0, "shadow": false, "sway": 0.3},
			],
			"window": {"kelvin": 7000.0, "energy": 0.8, "range": 4.5},
		},
	},
	{
		"stove": 1.15,
		"night": {
			"lamps": [
				{"at": Vector3(0.5, 2.0, 0.0), "kind": "kerosene", "kelvin": 2200.0,
					"energy": 1.15, "range": 7.0, "shadow": true, "sway": 0.6},
				{"at": Vector3(0.18, 1.9, -0.3), "kind": "kerosene", "kelvin": 2200.0,
					"energy": 0.9, "range": 6.0, "shadow": false, "sway": 0.4},
				{"at": Vector3(0.82, 1.2, -0.9), "kind": "kerosene", "kelvin": 2100.0,
					"energy": 0.6, "range": 4.0, "shadow": false, "sway": 0.0},
			],
			"window": {"kelvin": 6000.0, "energy": 0.12, "range": 4.5},
		},
		"day": {
			"lamps": [
				{"at": Vector3(0.5, 2.0, 0.0), "kind": "kerosene", "kelvin": 2200.0,
					"energy": 0.3, "range": 7.0, "shadow": true, "sway": 0.6},
				{"at": Vector3(0.18, 1.9, -0.3), "kind": "kerosene", "kelvin": 2200.0,
					"energy": 0.0, "range": 6.0, "shadow": false, "sway": 0.4},
				{"at": Vector3(0.82, 1.2, -0.9), "kind": "kerosene", "kelvin": 2100.0,
					"energy": 0.0, "range": 4.0, "shadow": false, "sway": 0.0},
			],
			"window": {"kelvin": 6000.0, "energy": 0.9, "range": 4.5},
		},
	},
	{
		"stove": 1.0,
		"night": {
			"lamps": [
				{"at": Vector3(0.5, 2.05, 0.0), "kind": "electric", "kelvin": 2700.0,
					"energy": 1.45, "range": 8.0, "shadow": true, "sway": 0.0},
				{"at": Vector3(0.2, 1.7, -1.1), "kind": "electric", "kelvin": 2700.0,
					"energy": 0.8, "range": 5.0, "shadow": false, "sway": 0.0},
				{"at": Vector3(0.8, 1.7, -1.1), "kind": "electric", "kelvin": 2700.0,
					"energy": 0.8, "range": 5.0, "shadow": false, "sway": 0.0},
				{"at": Vector3(0.35, 1.0, -0.6), "kind": "electric", "kelvin": 2500.0,
					"energy": 0.6, "range": 3.5, "shadow": false, "sway": 0.0},
			],
			"window": {"kelvin": 9000.0, "energy": 0.15, "range": 5.0},
		},
		"day": {
			"lamps": [
				{"at": Vector3(0.5, 2.05, 0.0), "kind": "electric", "kelvin": 2700.0,
					"energy": 0.5, "range": 8.0, "shadow": true, "sway": 0.0},
				{"at": Vector3(0.2, 1.7, -1.1), "kind": "electric", "kelvin": 2700.0,
					"energy": 0.0, "range": 5.0, "shadow": false, "sway": 0.0},
				{"at": Vector3(0.8, 1.7, -1.1), "kind": "electric", "kelvin": 2700.0,
					"energy": 0.0, "range": 5.0, "shadow": false, "sway": 0.0},
				{"at": Vector3(0.35, 1.0, -0.6), "kind": "electric", "kelvin": 2500.0,
					"energy": 0.3, "range": 3.5, "shadow": false, "sway": 0.0},
			],
			"window": {"kelvin": 6500.0, "energy": 1.1, "range": 5.0},
		},
	},
]

## The car's air by day and by night (train_scene _build_world's ambient and its
## cold fill from the open side): snow light by day, moon on snow by night.
const WORLD: Dictionary = {
	"day": {"ambient_color": Color(0.62, 0.66, 0.74), "ambient_energy": 0.45,
		"fill_color": Color(0.70, 0.76, 0.88), "fill_energy": 0.45},
	"night": {"ambient_color": Color(0.32, 0.36, 0.48), "ambient_energy": 0.2,
		"fill_color": Color(0.45, 0.52, 0.70), "fill_energy": 0.12},
}


static func stage_of(c: Dictionary) -> int:
	return clampi(int(c.get("home_stage", STAGE_DEFAULT)), 0, STAGE_NAMES.size() - 1)


static func daytime_of(view: Dictionary) -> String:
	return "night" if view.get("daytime", "day") == "night" else "day"


static func spec(stage: int, daytime: String) -> Dictionary:
	var home: Dictionary = STAGES[clampi(stage, 0, STAGE_NAMES.size() - 1)]
	var period: Dictionary = home["night" if daytime == "night" else "day"]
	return {"lamps": period["lamps"], "window": period["window"], "stove": float(home["stove"])}.duplicate(true)


## The ambient and fill for "day" or "night" (anything but "night" is day).
static func world(daytime: String) -> Dictionary:
	var air: Dictionary = WORLD["night" if daytime == "night" else "day"]
	return air.duplicate(true)


## Tanner Helland's approximation, normalized to keep energy separate.
static func kelvin(k: float) -> Color:
	var temperature: float = clampf(k, 1000.0, 12000.0) / 100.0
	var red: float = 255.0
	var green: float = 0.0
	var blue: float = 0.0
	if temperature <= 66.0:
		green = 99.4708025861 * log(temperature) - 161.1195681661
	else:
		red = 329.698727446 * pow(temperature - 60.0, -0.1332047592)
		green = 288.1221695283 * pow(temperature - 60.0, -0.0755148492)
	if temperature >= 66.0:
		blue = 255.0
	elif temperature > 19.0:
		blue = 138.5177312231 * log(temperature - 10.0) - 305.0447927307
	red = clampf(red, 0.0, 255.0) / 255.0
	green = clampf(green, 0.0, 255.0) / 255.0
	blue = clampf(blue, 0.0, 255.0) / 255.0
	var peak: float = maxf(red, maxf(green, blue))
	return Color(red / peak, green / peak, blue / peak, 1.0)


static func build(car: Node3D, length: float, stage: int, daytime: String) -> Array[OmniLight3D]:
	var plan: Dictionary = spec(stage, daytime)
	var lamp_specs: Array = plan["lamps"]
	var lamps: Array[OmniLight3D] = []
	for i: int in lamp_specs.size():
		var lamp_spec: Dictionary = lamp_specs[i]
		var at: Vector3 = lamp_spec["at"]
		var lamp: OmniLight3D = OmniLight3D.new()
		lamp.name = "Lamp%d" % i
		lamp.position = Vector3(at.x * length, at.y, at.z)
		lamp.light_color = kelvin(float(lamp_spec["kelvin"]))
		lamp.light_energy = float(lamp_spec["energy"])
		lamp.omni_range = float(lamp_spec["range"])
		lamp.shadow_enabled = bool(lamp_spec["shadow"])
		lamp.set_meta("sway", float(lamp_spec["sway"]))
		lamp.set_meta("kind", String(lamp_spec["kind"]))
		car.add_child(lamp)
		lamps.append(lamp)
	var window_spec: Dictionary = plan["window"]
	for i: int in WINDOW_SHARES.size():
		var window_light: OmniLight3D = OmniLight3D.new()
		window_light.name = "Window%d" % i
		window_light.position = Vector3(WINDOW_SHARES[i] * length, WINDOW_AT.x, WINDOW_AT.y)
		window_light.light_color = kelvin(float(window_spec["kelvin"]))
		window_light.light_energy = float(window_spec["energy"])
		window_light.omni_range = float(window_spec["range"])
		window_light.shadow_enabled = false
		car.add_child(window_light)
	return lamps


static func target(stage: int, daytime: String, look: Dictionary) -> Dictionary:
	var plan: Dictionary = spec(stage, daytime)
	var lamp_specs: Array = plan["lamps"]
	var first: Dictionary = lamp_specs[0]
	var mood_color: Color = look.get("lamp", Color(1.0, 0.72, 0.42))
	var mood_energy: float = float(look.get("energy", CALM_ENERGY))
	var mood_sway: float = float(look.get("sway", 1.0))
	return {
		"lamp_color": kelvin(float(first["kelvin"])).lerp(mood_color, LOOK_TINT),
		"lamp_energy": float(first["energy"]) * mood_energy / CALM_ENERGY,
		"lamp_sway": float(first["sway"]) * mood_sway,
	}


## Pass the full build() result in order, including Lamp0.
## train_scene eases Lamp0's energy toward target(); only its color changes here.
static func apply_daytime(lamps: Array, windows: Array, stage: int, daytime: String) -> void:
	var plan: Dictionary = spec(stage, daytime)
	var lamp_specs: Array = plan["lamps"]
	for i: int in mini(lamps.size(), lamp_specs.size()):
		var lamp: OmniLight3D = lamps[i]
		var lamp_spec: Dictionary = lamp_specs[i]
		lamp.light_color = kelvin(float(lamp_spec["kelvin"]))
		if i > 0:
			lamp.light_energy = float(lamp_spec["energy"])
	var window_spec: Dictionary = plan["window"]
	for window_light: OmniLight3D in windows:
		window_light.light_color = kelvin(float(window_spec["kelvin"]))
		window_light.light_energy = float(window_spec["energy"])
