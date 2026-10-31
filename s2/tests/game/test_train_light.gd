extends "res://addons/gut/test.gd"
## Decision 486: stage light, mood targets and day/night updates.

const Light = preload("res://game/train/train_light.gd")
const EPSILON: float = 0.0001
const CALM_LOOK: Dictionary = {"lamp": Color(1.0, 0.72, 0.42), "energy": 1.3, "sway": 1.0}
const FROZEN_LOOK: Dictionary = {"lamp": Color(0.72, 0.77, 0.88), "energy": 0.6, "sway": 0.5}


func _assert_color(actual: Color, expected: Color, context: String = "") -> void:
	assert_almost_eq(actual.r, expected.r, EPSILON, context + " red")
	assert_almost_eq(actual.g, expected.g, EPSILON, context + " green")
	assert_almost_eq(actual.b, expected.b, EPSILON, context + " blue")
	assert_almost_eq(actual.a, expected.a, EPSILON, context + " alpha")


func test_stage_defaults_converts_and_clamps() -> void:
	assert_eq(Light.stage_of({}), 1)
	assert_eq(Light.stage_of({"home_stage": -1}), 0)
	assert_eq(Light.stage_of({"home_stage": 9}), 3)
	assert_eq(Light.stage_of({"home_stage": 2}), 2)
	assert_eq(Light.stage_of({"home_stage": "2"}), 2)


func test_only_night_selects_the_night_plan() -> void:
	assert_eq(Light.daytime_of({"daytime": "night"}), "night")
	assert_eq(Light.daytime_of({}), "day")
	assert_eq(Light.daytime_of({"daytime": "day"}), "day")
	assert_eq(Light.daytime_of({"daytime": "dusk"}), "day")


func test_spec_clamps_stage_and_defaults_to_day() -> void:
	var low: Dictionary = Light.spec(-1, "night")
	var low_lamps: Array = low["lamps"]
	var low_first: Dictionary = low_lamps[0]
	assert_eq(low_lamps.size(), 2)
	assert_almost_eq(float(low_first["kelvin"]), 1850.0, EPSILON)
	assert_almost_eq(float(low["stove"]), 0.9, EPSILON)
	var high: Dictionary = Light.spec(9, "night")
	var high_lamps: Array = high["lamps"]
	var high_first: Dictionary = high_lamps[0]
	assert_eq(high_lamps.size(), 4)
	assert_almost_eq(float(high_first["kelvin"]), 2700.0, EPSILON)
	var fallback: Dictionary = Light.spec(1, "dusk")
	var fallback_lamps: Array = fallback["lamps"]
	var fallback_first: Dictionary = fallback_lamps[0]
	var fallback_window: Dictionary = fallback["window"]
	assert_almost_eq(float(fallback_first["energy"]), 0.2, EPSILON)
	assert_almost_eq(float(fallback_window["energy"]), 0.8, EPSILON)
	assert_almost_eq(float(fallback_window["kelvin"]), 7000.0, EPSILON)


func test_all_lamps_fit_the_car_and_start_at_its_midpoint() -> void:
	for stage: int in 4:
		for daytime: String in ["day", "night"]:
			var plan: Dictionary = Light.spec(stage, daytime)
			var lamps: Array = plan["lamps"]
			var first: Dictionary = lamps[0]
			var first_at: Vector3 = first["at"]
			var context: String = "%s %s" % [Light.STAGE_NAMES[stage], daytime]
			assert_almost_eq(first_at.x, 0.5, EPSILON, context)
			for lamp: Dictionary in lamps:
				var at: Vector3 = lamp["at"]
				assert_between(at.x, 0.0, 1.0, context)
				assert_lte(at.y, Light.LAMP_TOP, context)
				assert_lte(absf(at.z), 1.3, context)
				assert_gte(float(lamp["energy"]), 0.0, context)
				assert_gt(float(lamp["range"]), 0.0, context)


func test_later_stages_have_at_least_as_many_night_lamps_and_higher_kelvin() -> void:
	var expected_counts: Array[int] = [2, 2, 3, 4]
	var expected_kelvin: Array[float] = [1850.0, 2000.0, 2200.0, 2700.0]
	var previous_count: int = 0
	var previous_kelvin: float = 0.0
	for stage: int in 4:
		var plan: Dictionary = Light.spec(stage, "night")
		var lamps: Array = plan["lamps"]
		var first: Dictionary = lamps[0]
		var temperature: float = float(first["kelvin"])
		assert_eq(lamps.size(), expected_counts[stage])
		assert_gte(lamps.size(), previous_count)
		assert_almost_eq(temperature, expected_kelvin[stage], EPSILON)
		assert_gt(temperature, previous_kelvin)
		previous_count = lamps.size()
		previous_kelvin = temperature
	var rag: Dictionary = Light.spec(0, "night")
	var nordic: Dictionary = Light.spec(3, "night")
	var rag_lamps: Array = rag["lamps"]
	var nordic_lamps: Array = nordic["lamps"]
	assert_gt(nordic_lamps.size(), rag_lamps.size())


func test_day_windows_are_brighter_and_do_not_dim_with_stage() -> void:
	var previous_energy: float = 0.0
	for stage: int in 4:
		var day: Dictionary = Light.spec(stage, "day")
		var night: Dictionary = Light.spec(stage, "night")
		var day_window: Dictionary = day["window"]
		var night_window: Dictionary = night["window"]
		var energy: float = float(day_window["energy"])
		assert_gt(energy, float(night_window["energy"]))
		assert_gte(energy, previous_energy)
		previous_energy = energy


func test_stove_multipliers_are_the_same_by_day_and_night() -> void:
	var expected: Array[float] = [0.9, 1.0, 1.15, 1.0]
	for stage: int in 4:
		for daytime: String in ["day", "night"]:
			var plan: Dictionary = Light.spec(stage, daytime)
			assert_almost_eq(float(plan["stove"]), expected[stage], EPSILON)


func test_nordic_lamps_stay_still_while_early_stages_sway() -> void:
	for daytime: String in ["day", "night"]:
		var nordic: Dictionary = Light.spec(3, daytime)
		var nordic_lamps: Array = nordic["lamps"]
		for lamp: Dictionary in nordic_lamps:
			assert_almost_eq(float(lamp["sway"]), 0.0, EPSILON)
		for stage: int in [0, 1]:
			var plan: Dictionary = Light.spec(stage, daytime)
			var lamps: Array = plan["lamps"]
			var first: Dictionary = lamps[0]
			assert_gt(float(first["sway"]), 0.0)


func test_kelvin_orders_warm_colors_and_keeps_daylight_near_white() -> void:
	var candle: Color = Light.kelvin(1850.0)
	var electric: Color = Light.kelvin(2700.0)
	# At 1850 K blue is zero; cross products compare r/b without division by zero.
	assert_gt(candle.r * electric.b, electric.r * candle.b)
	var daylight: Color = Light.kelvin(6500.0)
	var brightest: float = maxf(daylight.r, maxf(daylight.g, daylight.b))
	var dimmest: float = minf(daylight.r, minf(daylight.g, daylight.b))
	assert_lte(brightest - dimmest, 0.15)


func test_kelvin_clamps_and_normalizes_every_channel() -> void:
	for temperature: float in [-5000.0, 0.0, 999.0, 1000.0, 1850.0, 1900.0, 2000.0,
			2200.0, 2700.0, 6500.0, 6600.0, 6700.0, 9000.0, 12000.0, 50000.0]:
		var color: Color = Light.kelvin(temperature)
		assert_between(color.r, 0.0, 1.0)
		assert_between(color.g, 0.0, 1.0)
		assert_between(color.b, 0.0, 1.0)
		assert_almost_eq(maxf(color.r, maxf(color.g, color.b)), 1.0, EPSILON)
		assert_almost_eq(color.a, 1.0, EPSILON)
	_assert_color(Light.kelvin(-5000.0), Light.kelvin(1000.0), "lower clamp")
	_assert_color(Light.kelvin(50000.0), Light.kelvin(12000.0), "upper clamp")


func test_spec_returns_independent_nested_lamps_and_window() -> void:
	var changed: Dictionary = Light.spec(2, "night")
	var changed_lamps: Array = changed["lamps"]
	var changed_first: Dictionary = changed_lamps[0]
	var changed_window: Dictionary = changed["window"]
	changed_first["energy"] = 99.0
	changed_window["energy"] = 99.0
	changed_lamps.clear()
	var fresh: Dictionary = Light.spec(2, "night")
	var fresh_lamps: Array = fresh["lamps"]
	assert_eq(fresh_lamps.size(), 3)
	if not fresh_lamps.is_empty():
		var fresh_first: Dictionary = fresh_lamps[0]
		assert_almost_eq(float(fresh_first["energy"]), 1.15, EPSILON)
	var fresh_window: Dictionary = fresh["window"]
	assert_almost_eq(float(fresh_window["energy"]), 0.12, EPSILON)


func test_build_adds_three_lamps_and_two_windows_under_the_car() -> void:
	var car: Node3D = Node3D.new()
	var length: float = 12.0
	var lamps: Array[OmniLight3D] = Light.build(car, length, 2, "night")
	assert_eq(car.get_child_count(), 5)
	assert_eq(lamps.size(), 3)
	var light_count: int = 0
	var shadow_count: int = 0
	for child: Node in car.get_children():
		if child is OmniLight3D:
			var light: OmniLight3D = child as OmniLight3D
			light_count += 1
			if light.shadow_enabled:
				shadow_count += 1
	assert_eq(light_count, 5)
	assert_eq(shadow_count, 1)
	if not lamps.is_empty():
		assert_eq(String(lamps[0].name), "Lamp0")
		assert_almost_eq(lamps[0].position.x, 0.5 * length, EPSILON)
	var plan: Dictionary = Light.spec(2, "night")
	var lamp_specs: Array = plan["lamps"]
	for i: int in mini(lamps.size(), lamp_specs.size()):
		var lamp: OmniLight3D = lamps[i]
		var lamp_spec: Dictionary = lamp_specs[i]
		var at: Vector3 = lamp_spec["at"]
		assert_eq(lamp.get_parent(), car)
		assert_eq(String(lamp.name), "Lamp%d" % i)
		assert_eq(lamp.position, Vector3(at.x * length, at.y, at.z))
		assert_eq(lamp.shadow_enabled, i == 0)
		_assert_color(lamp.light_color, Light.kelvin(float(lamp_spec["kelvin"])))
		assert_almost_eq(lamp.light_energy, float(lamp_spec["energy"]), EPSILON)
		assert_almost_eq(lamp.omni_range, float(lamp_spec["range"]), EPSILON)
		assert_almost_eq(float(lamp.get_meta("sway", -1.0)), float(lamp_spec["sway"]), EPSILON)
		assert_eq(String(lamp.get_meta("kind", "")), "kerosene")
	var window_spec: Dictionary = plan["window"]
	for i: int in 2:
		var window_light: OmniLight3D = car.get_node_or_null("Window%d" % i) as OmniLight3D
		assert_not_null(window_light, "Window%d" % i)
		if window_light != null:
			assert_eq(String(window_light.name), "Window%d" % i)
			assert_eq(window_light.position, Vector3(Light.WINDOW_SHARES[i] * length, 1.1, -1.0))
			assert_false(window_light.shadow_enabled)
			assert_false(lamps.has(window_light))
			_assert_color(window_light.light_color, Light.kelvin(float(window_spec["kelvin"])))
			assert_almost_eq(window_light.light_energy, float(window_spec["energy"]), EPSILON)
			assert_almost_eq(window_light.omni_range, float(window_spec["range"]), EPSILON)
	car.free()
	assert_false(is_instance_valid(car))


func test_calm_and_empty_looks_keep_stage_energy_and_apply_the_tint() -> void:
	for stage: int in 4:
		for daytime: String in ["day", "night"]:
			var plan: Dictionary = Light.spec(stage, daytime)
			var lamps: Array = plan["lamps"]
			var first: Dictionary = lamps[0]
			var calm: Dictionary = Light.target(stage, daytime, CALM_LOOK)
			var fallback: Dictionary = Light.target(stage, daytime, {})
			var calm_color: Color = calm["lamp_color"]
			var fallback_color: Color = fallback["lamp_color"]
			var expected_color: Color = Light.kelvin(float(first["kelvin"])).lerp(Color(1.0, 0.72, 0.42), 0.35)
			assert_almost_eq(float(calm["lamp_energy"]), float(first["energy"]), EPSILON)
			assert_almost_eq(float(calm["lamp_sway"]), float(first["sway"]), EPSILON)
			_assert_color(calm_color, expected_color)
			assert_almost_eq(float(fallback["lamp_energy"]), float(calm["lamp_energy"]), EPSILON)
			assert_almost_eq(float(fallback["lamp_sway"]), float(calm["lamp_sway"]), EPSILON)
			_assert_color(fallback_color, calm_color)


func test_frozen_look_is_dimmer_bluer_and_sways_less() -> void:
	for stage: int in 4:
		var calm: Dictionary = Light.target(stage, "night", CALM_LOOK)
		var frozen: Dictionary = Light.target(stage, "night", FROZEN_LOOK)
		var calm_color: Color = calm["lamp_color"]
		var frozen_color: Color = frozen["lamp_color"]
		assert_lt(float(frozen["lamp_energy"]), float(calm["lamp_energy"]))
		assert_almost_eq(float(frozen["lamp_energy"]), float(calm["lamp_energy"]) * 0.6 / 1.3, EPSILON)
		assert_gt(frozen_color.b / frozen_color.r, calm_color.b / calm_color.r)
		assert_almost_eq(float(frozen["lamp_sway"]), float(calm["lamp_sway"]) * 0.5, EPSILON)


func test_apply_daytime_updates_colors_and_secondary_energy_only() -> void:
	var car: Node3D = Node3D.new()
	var lamps: Array[OmniLight3D] = Light.build(car, 16.0, 3, "night")
	var windows: Array[OmniLight3D] = []
	for i: int in 2:
		var window_light: OmniLight3D = car.get_node_or_null("Window%d" % i) as OmniLight3D
		assert_not_null(window_light, "Window%d" % i)
		if window_light != null:
			windows.append(window_light)
	assert_eq(lamps.size(), 4)
	if lamps.size() != 4:
		car.free()
		return
	lamps[0].light_energy = 0.73 # Preserve a value partway through train_scene's easing.
	var first_energy: float = lamps[0].light_energy
	var positions: Array[Vector3] = []
	var ranges: Array[float] = []
	var shadows: Array[bool] = []
	for lamp: OmniLight3D in lamps:
		lamp.light_color = Color(0.1, 0.2, 0.3)
		positions.append(lamp.position)
		ranges.append(lamp.omni_range)
		shadows.append(lamp.shadow_enabled)
	Light.apply_daytime(lamps, windows, 3, "day")
	var day: Dictionary = Light.spec(3, "day")
	var day_lamps: Array = day["lamps"]
	assert_almost_eq(lamps[0].light_energy, first_energy, EPSILON)
	for i: int in lamps.size():
		var lamp: OmniLight3D = lamps[i]
		var lamp_spec: Dictionary = day_lamps[i]
		_assert_color(lamp.light_color, Light.kelvin(float(lamp_spec["kelvin"])))
		if i > 0:
			assert_almost_eq(lamp.light_energy, float(lamp_spec["energy"]), EPSILON)
		assert_eq(lamp.position, positions[i])
		assert_almost_eq(lamp.omni_range, ranges[i], EPSILON)
		assert_eq(lamp.shadow_enabled, shadows[i])
	var day_window: Dictionary = day["window"]
	for i: int in windows.size():
		var window_light: OmniLight3D = windows[i]
		assert_almost_eq(window_light.light_energy, float(day_window["energy"]), EPSILON)
		_assert_color(window_light.light_color, Light.kelvin(float(day_window["kelvin"])))
		assert_eq(window_light.position, Vector3(Light.WINDOW_SHARES[i] * 16.0, 1.1, -1.0))
		assert_almost_eq(window_light.omni_range, 5.0, EPSILON)
		assert_false(window_light.shadow_enabled)
	assert_eq(car.get_child_count(), 6)
	car.free()
	assert_false(is_instance_valid(car))


func test_the_air_is_darker_and_colder_by_night() -> void:
	var day: Dictionary = Light.world("day")
	var night: Dictionary = Light.world("night")
	assert_lt(float(night["ambient_energy"]), float(day["ambient_energy"]))
	assert_lt(float(night["fill_energy"]), float(day["fill_energy"]))
	for air: Dictionary in [day, night]:
		var amb: Color = air["ambient_color"]
		var fill: Color = air["fill_color"]
		assert_gt(amb.b, amb.r, "ambient leans cold")
		assert_gt(fill.b, fill.r, "fill leans cold")
	assert_eq(float(Light.world("dusk")["fill_energy"]), float(day["fill_energy"]), "only night is night")
	day["fill_energy"] = 9.0
	assert_ne(float(Light.world("day")["fill_energy"]), 9.0, "a copy")
