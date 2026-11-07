extends "res://addons/gut/test.gd"
## 결정 578: 바닥 날씨의 값·전역 전달·셰이더 문장과 변조 거절.
## RenderingServer 전역 읽기는 편집기 전용: 정차 보관값과 실제 쓰기 경로를 함께 잠근다.

const FieldGame = preload("res://game/field_game.gd")
const FxState = preload("res://fx/fx_state.gd")
const MapView = preload("res://game/world/map_view.gd")
const SnowPattern = preload("res://tests/game/test_snow_pattern.gd")
const SHADER_PATH := "res://game/world/world_vis.gdshader"
const HOAR_START := "float hoar = smoothstep(0.0, 0.3, fx_frost) * (1.0 - smoothstep(0.5, 0.92, fx_cloud.x)) * (1.0 - smoothstep(0.0, 0.05, max(fx_fall.x, fx_fall.y)));"
const HOAR_WIND := "hoar *= 1.0 - smoothstep(0.5, 0.8, fx_wind.z);"
const HOAR_MASK := "hoar *= (is_ground ? 1.0 : 0.0) * smoothstep(0.6, 0.9, up) * sky * (1.0 - cover) * (1.0 - trodden) * (1.0 - smoothstep(0.08, 0.3, chroma)) * smoothstep(0.3, 0.7, 0.5 * grain.g + 0.5 * drift);"
const HOAR_PAINT := "base = mix(base, FX_RIME, 0.6 * hoar);"
const BLOW_START := "float blow = fresh * smoothstep(0.5, 0.9, fx_wind.z) * sky * (1.0 - smoothstep(0.08, 0.3, chroma));"
const BLOW_MASK := "blow *= (is_ground ? 1.0 : 0.0) * smoothstep(0.6, 0.9, up) * (1.0 - 0.6 * trodden);"
const BLOW_PAINT := "base = mix(base, FX_SNOW * 1.1, blow * lane * gust * 0.5);"
const SPLASH := "float splash_k = clamp(fx_fall.x, 0.0, 1.0) * wet * level_k * (1.0 - standing) * (1.0 - fx_cold.y);"
const RING_CENTER := "vec2 so = vec2(fx_hash(sc + slot * 0.37 + 3.1), fx_hash(sc + slot * 0.71 + 7.7)) * 0.26 + 0.37;"
const RING_EDGE := "float ring = (1.0 - smoothstep(0.0, 0.07, abs(length(fract(sp) - so) - st * 0.3))) * (1.0 - st);"
const WET_PAVING := "base *= 1.0 - (paved ? 0.26 : 0.17) * wet;"
const SKY_LIFT := "base = mix(base, max(base, fx_sky.rgb * 0.5), wet * level_k * (1.0 - standing) * (paved ? 0.32 : 0.1));"

var checker: Node


class ArrivalProbe extends FieldGame:
	var before_map: Dictionary = {}

	func _fx_params_now(hour: float, cover: float) -> Dictionary:
		var p := super._fx_params_now(hour, cover)
		if data.is_empty():
			before_map = p.duplicate()
		return p

func before_each() -> void:
	checker = SnowPattern.new()
	add_child_autofree(checker)


func _stop(storm := false, staged := false) -> Node:
	var game := ArrivalProbe.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "cold": 1.0, "weather": ["snow"]}
	game.opts["staged"] = staged
	if storm:
		game.opts["storm"] = "during"
	add_child_autofree(game)
	game.set_process(false)
	return game


func _assert_map_base(game: Node) -> void:
	var look := MapView.snow_look_for(game.data)
	var expected := MapView.map_snow_base(game.data, float(game.fx_params["fx_snow"]), look)
	assert_true(game.fx_params.has("fx_map_snow_base"))
	assert_almost_eq(float(game.fx_params.get("fx_map_snow_base", -1.0)), expected, 0.00001)
	# apply returns only keys it actually passes to global_shader_parameter_set.
	assert_eq(FxState.apply(game.fx_params), FxState.GLOBALS)


func test_fall_values_by_kind() -> void:
	var cases := {"clear": Vector2.ZERO, "overcast": Vector2.ZERO, "fog": Vector2.ZERO,
		"rain": Vector2(1.0, 0.0), "snow": Vector2(0.0, 0.55), "blizzard": Vector2(0.0, 1.0), "sleet": Vector2(0.6, 0.3), "unknown": Vector2.ZERO}
	for kind: String in cases:
		assert_eq(FxState.params_for([kind], -10.0)["fx_fall"], cases[kind], kind)
	assert_eq(FxState.params_for([], -10.0)["fx_fall"], Vector2.ZERO)


func test_fall_uses_component_maxima_independent_of_order_and_depth() -> void:
	var cases := [[["rain", "snow"], Vector2(1.0, 0.55)], [["sleet", "snow"], Vector2(0.6, 0.55)],
		[["sleet", "rain", "blizzard", "unknown", "rain"], Vector2(1.0, 1.0)]]
	for row: Array in cases:
		var kinds: Array = row[0].duplicate()
		for depth: float in [0.0, 1.0]:
			assert_eq(FxState.params_for(kinds, -10.0, Vector2.RIGHT, 0.4, 12.0, depth)["fx_fall"], row[1])
			kinds.reverse()
			assert_eq(FxState.params_for(kinds, -10.0, Vector2.RIGHT, 0.4, 12.0, depth)["fx_fall"], row[1])


func test_plain_and_storm_arrivals_write_fall_and_map_base() -> void:
	for storm: bool in [false, true]:
		var game := _stop(storm)
		assert_eq(game.fx_params["fx_fall"], Vector2(0.0, 1.0 if storm else 0.55))
		_assert_map_base(game)


func test_missing_map_is_zero_then_built_fills_it_once() -> void:
	for storm: bool in [false, true]:
		var game := _stop(storm)
		assert_false(game.before_map.is_empty(), "arrival really precedes map construction")
		assert_eq(float(game.before_map.get("fx_map_snow_base", -1.0)), 0.0)
		assert_true(game.is_built)
		assert_false(game.built.is_connected(Callable(game, "_apply_map_snow_base")), "one-shot consumed")
		_assert_map_base(game)
		assert_gt(float(game.fx_params.get("fx_map_snow_base", -1.0)), 0.0)
	assert_eq(float(FxState.params_for(["snow"], -10.0).get("fx_map_snow_base", -1.0)), 0.0)


func test_staged_stop_fills_map_base_after_build_without_a_clock_tick() -> void:
	var game := _stop(false, true)
	if not game.is_built:
		await wait_for_signal(game.built, 60)
	assert_true(game.is_built)
	if not game.is_built:
		return
	assert_gt(game.pace.waits, 0)
	assert_true(game.standing_by)
	assert_eq(game.clock.elapsed, 0.0)
	_assert_map_base(game)
	assert_false(game.built.is_connected(Callable(game, "_apply_map_snow_base")))


func test_map_base_applies_the_resolved_shift_once_and_clamps() -> void:
	var game := _stop()
	# The live material is the resolved look; a second shift would differ at 0.4.
	for shift: float in [-0.3, 0.3]:
		game.view.material.set_shader_parameter("snow_shift", shift)
		for snow: float in [0.0, 0.01, 0.0101, 0.4, 1.0]:
			assert_almost_eq(game._map_snow_base(snow), MapView.map_snow_base(game.data, snow, {"shift": shift}), 0.00001)
	assert_almost_eq(game._map_snow_base(0.4), 0.52, 0.00001)


func test_snow_update_writes_both_snow_values_and_preserves_fall() -> void:
	for storm: bool in [false, true]:
		var game := _stop(storm)
		game.snow_cover.depth_cm = 0.0
		game._apply_fx()
		var before: float = game.fx_params["fx_snow"]
		var fall: Vector2 = game.fx_params["fx_fall"]
		game.snow_cover.depth_cm = game.snow_cover.MAX_CM
		game.clock.elapsed = 4.0 # one game minute, the existing snow update interval
		game._update_snow()
		assert_gt(absf(float(game.fx_params["fx_snow"]) - before), 0.002)
		assert_eq(game.fx_params["fx_fall"], fall)
		_assert_map_base(game)


func test_snow_gate_keeps_both_globals_below_threshold() -> void:
	for storm: bool in [false, true]:
		var game := _stop(storm)
		var before: Dictionary = game.fx_params.duplicate()
		game._update_snow() # less than a minute must not write either value
		assert_eq(game.fx_params, before)
		# Saturation makes a minute of snowfall smaller than the shader's 0.002 gate.
		game.snow_cover.depth_cm = game.snow_cover.MAX_CM
		game._apply_fx()
		before = game.fx_params.duplicate()
		game.clock.elapsed = 4.0
		game._update_snow()
		assert_almost_eq(game.snow_at_min, game.clock.game_minutes(), 0.00001)
		assert_eq(game.fx_params, before)


func test_globals_are_declared_registered_and_wired_to_the_writer() -> void:
	for name: String in ["fx_fall", "fx_map_snow_base"]:
		assert_true(FxState.GLOBALS.has(name))
		assert_true(ProjectSettings.has_setting("shader_globals/" + name))
	var setting: Dictionary = ProjectSettings.get_setting("shader_globals/fx_map_snow_base", {})
	assert_eq(setting.get("type"), "float")
	assert_eq(setting.get("value"), 0.0)
	var common := FileAccess.get_file_as_string("res://fx/shaders/fx_common.gdshaderinc")
	assert_true(checker._strip_comments(common).contains("global uniform float fx_map_snow_base;"))
	var field := FileAccess.get_file_as_string("res://game/field_game.gd")
	var arrival: String = field.get_slice("func _apply_fx()", 1).get_slice("\nfunc ", 0)
	assert_eq(arrival.count("FxState.apply(fx_params)"), 2, "plain and storm paths write the complete values")
	assert_true(arrival.contains("built.connect(_apply_map_snow_base, CONNECT_ONE_SHOT)"))
	var update: String = field.get_slice("func _update_snow()", 1).get_slice("\nfunc ", 0)
	assert_true(update.contains('FxState.apply({"fx_snow": p["fx_snow"], "fx_map_snow_base": p["fx_map_snow_base"]})'))
	var ready_write: String = field.get_slice("func _apply_map_snow_base()", 1).get_slice("\nfunc ", 0)
	assert_true(ready_write.contains('FxState.apply({"fx_map_snow_base": fx_params["fx_map_snow_base"]})'))


func _contract_rows(contract: String) -> Array[Array]:
	match contract:
		"hoar":
			return [["hoar", HOAR_START, []], ["hoar", HOAR_WIND, []], ["hoar", HOAR_MASK, []], ["", HOAR_PAINT, []]]
		"blow":
			return [["blow", BLOW_START, []], ["blow", BLOW_MASK, []], ["", BLOW_PAINT, ["if(blow>0.01)"]]]
		"ring":
			var guard := ["if(splash_k>0.01)"]
			return [["splash_k", SPLASH, []], ["sp", "vec2 sp = world_pos.xz * 2.0;", guard],
				["sc", "vec2 sc = floor(sp);", guard], ["ph", "float ph = TIME * 1.3 + fx_hash(sc) * 7.0;", guard],
				["slot", "float slot = floor(ph);", guard], ["st", "float st = ph - slot;", guard],
				["so", RING_CENTER, guard], ["ring", RING_EDGE, guard],
				["ring", "ring *= step(fx_hash(sc + slot * 1.3), 0.4 * fx_fall.x);", guard],
				["", "base += vec3(ring * splash_k * 0.16);", guard]]
		"wet":
			return [["", WET_PAVING, []]]
		"sky":
			return [["", SKY_LIFT, []]]
	return []


func _weather_errors(source: String, contract: String) -> PackedStringArray:
	# Reuse the snow checker's tokens, exact statement order and brace paths.
	# The named writes must also match exactly, so a later overwrite is not an escape.
	var tokens: Array[String] = checker._tokens(checker._strip_comments(source))
	var paired: Dictionary = checker._paired_tokens(tokens)
	if paired.has("error"):
		return PackedStringArray([String(paired["error"])])
	var pairs: Dictionary = paired["pairs"]
	var steps := _contract_rows(contract)
	if steps.is_empty():
		return PackedStringArray(["unknown contract"])
	var expected := {}
	for step: Array in steps:
		step[1] = checker._compact(step[1])
		if step[0] != "":
			if not expected.has(step[0]):
				expected[step[0]] = []
			expected[step[0]].append(step[1])
	for info: Dictionary in checker._function_headers(tokens, pairs):
		if info["name"] != "fragment":
			continue
		var opening: int = info["start"]
		var closing: int = int(info["end"]) - 1
		var errors: PackedStringArray = checker._snow_flow_errors(tokens, pairs, opening, closing, steps)
		for name: String in expected:
			if checker._write_statements(tokens, pairs, opening + 1, closing, name) != expected[name]:
				errors.append("쓰기 목록·순서 오류: " + name)
		return errors
	return PackedStringArray(["fragment missing"])


func _assert_contract(contract: String) -> void:
	var errors := _weather_errors(FileAccess.get_file_as_string(SHADER_PATH), contract)
	assert_eq(errors.size(), 0, "\n".join(errors))


func _reject(contract: String, old: String, replacement: String) -> void:
	var source := FileAccess.get_file_as_string(SHADER_PATH)
	assert_eq(_weather_errors(source, contract).size(), 0, "정상 원문 먼저")
	var changed := source.replace(old, replacement)
	assert_ne(changed, source, "실제로 바뀐 변조")
	assert_gt(_weather_errors(changed, contract).size(), 0, contract)


func test_hoar_fall_contract() -> void:
	_assert_contract("hoar")


func test_hoar_fall_contract_rejects_mutation() -> void:
	_reject("hoar", HOAR_START, HOAR_START.replace("0.05, max(fx_fall.x, fx_fall.y)", "0.5, fx_fall.x"))


func test_hoar_wind_contract() -> void:
	_assert_contract("hoar")


func test_hoar_wind_contract_rejects_mutation() -> void:
	_reject("hoar", HOAR_WIND, HOAR_WIND.replace("0.5, 0.8", "0.8, 1.0"))


func test_hoar_ground_contract() -> void:
	_assert_contract("hoar")


func test_hoar_ground_contract_rejects_mutation() -> void:
	_reject("hoar", HOAR_MASK, HOAR_MASK.replace("(is_ground ? 1.0 : 0.0)", "1.0"))


func test_hoar_tracks_contract() -> void:
	_assert_contract("hoar")


func test_hoar_tracks_contract_rejects_mutation() -> void:
	_reject("hoar", HOAR_MASK, HOAR_MASK.replace("(1.0 - trodden)", "1.0"))


func test_blow_ground_top_contract() -> void:
	_assert_contract("blow")


func test_blow_ground_top_contract_rejects_mutation() -> void:
	for mask: String in ["(is_ground ? 1.0 : 0.0)", "smoothstep(0.6, 0.9, up)"]:
		_reject("blow", BLOW_MASK, BLOW_MASK.replace(mask, "1.0"))


func test_ring_cell_bounds_contract() -> void:
	_assert_contract("ring") # centre 0.37..0.63, radius 0.3 plus edge 0.07


func test_ring_cell_bounds_contract_rejects_mutation() -> void:
	_reject("ring", RING_CENTER, RING_CENTER.replace("* 0.26 + 0.37", "* 0.3 + 0.35"))
	_reject("ring", RING_EDGE, RING_EDGE.replace("st * 0.3", "st * 0.4"))
	_reject("ring", RING_EDGE, RING_EDGE.replace("0.07", "0.08"))


func test_wet_paving_contract() -> void:
	_assert_contract("wet")


func test_wet_paving_contract_rejects_mutation() -> void:
	_reject("wet", WET_PAVING, WET_PAVING.replace("0.26", "0.3"))


func test_sky_only_lifts_contract() -> void:
	_assert_contract("sky")


func test_sky_only_lifts_contract_rejects_mutation() -> void:
	_reject("sky", SKY_LIFT, SKY_LIFT.replace("max(base, fx_sky.rgb * 0.5)", "fx_sky.rgb * 0.5"))


func test_weather_contracts_reject_comments_duplicates_and_wrong_paths() -> void:
	for row: Array in [["hoar", HOAR_WIND], ["blow", BLOW_MASK], ["ring", RING_CENTER], ["wet", WET_PAVING], ["sky", SKY_LIFT]]:
		var line: String = row[1]
		for changed: String in ["/* " + line + " */", line + "\n" + line, "if (false) { " + line + " }"]:
			_reject(row[0], line, changed)
