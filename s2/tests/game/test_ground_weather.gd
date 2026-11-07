extends "res://addons/gut/test.gd"
## 결정 578: 바닥 날씨의 값·전역 전달·셰이더 문장과 변조 거절.
## RenderingServer 전역 읽기는 편집기 전용: 정차가 쓰기 통로에 보낸 값을 기록한다.

const FieldGame = preload("res://game/field_game.gd")
const FxState = preload("res://fx/fx_state.gd")
const MapView = preload("res://game/world/map_view.gd")
const SnowTracks = preload("res://game/sim/snow_tracks.gd")
const Atmosphere = preload("res://fx/atmosphere.gd")
const SnowPattern = preload("res://tests/game/test_snow_pattern.gd")
const SHADER_PATH := "res://game/world/world_vis.gdshader"
const HOAR_START := "float hoar = smoothstep(0.0, 0.3, fx_frost) * (1.0 - smoothstep(0.5, 0.92, fx_cloud.x)) * (1.0 - smoothstep(0.0, 0.05, max(fx_fall.x, fx_fall.y)));"
const HOAR_WIND := "hoar *= 1.0 - smoothstep(0.5, 0.8, fx_wind.z);"
const HOAR_MASK := "hoar *= (is_ground ? 1.0 : 0.0) * smoothstep(0.6, 0.9, up) * sky * (1.0 - cover) * (1.0 - smoothstep(0.05, 0.3, trodden)) * (1.0 - smoothstep(0.08, 0.3, chroma)) * smoothstep(0.3, 0.7, 0.5 * grain.g + 0.5 * drift);"
const HOAR_PAINT := "base = mix(base, FX_RIME, 0.6 * hoar);"
const BLOW_START := "float blow = fresh * smoothstep(0.5, 0.9, fx_wind.z) * sky * (1.0 - smoothstep(0.08, 0.3, chroma));"
const BLOW_MASK := "blow *= (is_ground ? 1.0 : 0.0) * smoothstep(0.6, 0.9, up) * (1.0 - 0.6 * trodden);"
const BLOW_PAINT := "base = mix(base, FX_SNOW * 1.1, blow * lane * gust * 0.5);"
const SPLASH := "float splash_k = clamp(fx_fall.x, 0.0, 1.0) * wet * level_k * (1.0 - standing) * (1.0 - fx_cold.y);"
const RING_CENTER := "vec2 so = vec2(fx_hash(sc + slot * 0.37 + 3.1), fx_hash(sc + slot * 0.71 + 7.7)) * 0.26 + 0.37;"
const RING_EDGE := "float ring = (1.0 - smoothstep(0.0, 0.07, abs(length(fract(sp) - so) - st * 0.3))) * (1.0 - st);"
const RING_SELECT := "float splash_cell = step(fx_hash(sc + slot * 1.3), 0.4 * fx_fall.x);"
const WET_PAVING := "base *= 1.0 - (paved ? 0.26 : 0.17) * wet;"
const SKY_LIFT := "base = mix(base, max(base, fx_sky.rgb * 0.5), wet * level_k * (1.0 - standing) * (paved ? 0.32 : 0.1));"

var checker: Node


class ArrivalProbe extends FieldGame:
	var writes: Array[Dictionary] = []

	func _push_fx(values: Dictionary) -> void:
		# Copy at the call: later changes to fx_params must not rewrite the evidence.
		writes.append({"values": values.duplicate(true), "built": is_built})
		super._push_fx(values)


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
	assert_false(game.writes.is_empty(), "the field must call its writer")
	if game.writes.is_empty():
		return
	var sent: Dictionary = game.writes.back()["values"]
	assert_almost_eq(float(sent.get("fx_map_snow_base", -1.0)), expected, 0.00001, "actually sent")


func _assert_arrival_writes(game: Node) -> void:
	assert_eq(game.writes.size(), 2, "arrival then the one-shot built write")
	if game.writes.size() != 2:
		return
	var arrival: Dictionary = game.writes[0]["values"]
	assert_false(game.writes[0]["built"])
	assert_eq(arrival.size(), FxState.GLOBALS.size())
	for key: String in FxState.GLOBALS:
		assert_true(arrival.has(key), key)
	assert_eq(float(arrival.get("fx_map_snow_base", -1.0)), 0.0)
	assert_eq(arrival.get("fx_fall"), game.fx_params["fx_fall"])
	assert_true(game.writes[1]["built"])
	assert_eq(game.writes[1]["values"].keys(), ["fx_map_snow_base"])
	_assert_map_base(game)


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


func test_blizzard_picture_wind_floor_preserves_other_kinds_and_plain_frame() -> void:
	# 849dd942 keeps 0.4 in the raw blizzard path; the atmosphere already floors it.
	for wind: float in [-0.2, 0.0, 0.4, 0.9, 1.0, 1.2]:
		var p := FxState.params_for(["blizzard"], -10.0, Vector2.RIGHT, wind)
		assert_almost_eq(Vector3(p["fx_wind"]).z, clampf(maxf(wind, 0.9), 0.0, 1.0), 0.00001)
		for kinds: Array in [[], ["unknown"], ["clear"], ["overcast"], ["fog"], ["rain"], ["snow"], ["sleet"], ["snow", "rain"]]:
			p = FxState.params_for(kinds, -10.0, Vector2.RIGHT, wind)
			assert_almost_eq(Vector3(p["fx_wind"]).z, clampf(wind, 0.0, 1.0), 0.00001)
	var frame := Atmosphere.look(12.0, ["blizzard"], "K1", 1.0, {"wind": 0.4})
	assert_true(frame["kinds"].has("blizzard"))
	assert_almost_eq(Vector3(Atmosphere.params(frame)["fx_wind"]).z, float(frame["wind"]), 0.00001, "plain frame unchanged")


func test_storm_picture_wind_crosses_dust_gate_without_changing_rule_wind() -> void:
	var game := _stop(true)
	assert_almost_eq(game.weather.wind, 0.4, 0.00001, "body weather stays put")
	assert_gte(Vector3(game.fx_params["fx_wind"]).z, 0.9)
	assert_gt(Vector3(game.fx_params["fx_wind"]).z, 0.5, "dust's lower wind threshold")


func test_gallery_blizzard_wind_uses_the_picture_floor() -> void:
	# 4_blizzard_night supplies the gallery default 0.6; 12_storm_during is already 0.9.
	var gallery = load("res://fx/gallery.gd")
	for preset: Dictionary in gallery.PRESETS:
		var wind := float(preset.get("wind", 0.6))
		var p := FxState.params_for(preset["kinds"], preset["c"], Vector2(1, 0.3), wind, preset["hour"], preset["snow"])
		var expected := maxf(wind, 0.9) if preset["kinds"].has("blizzard") else wind
		assert_almost_eq(Vector3(p["fx_wind"]).z, expected, 0.00001, preset["name"])


func test_plain_and_storm_arrivals_write_fall_and_map_base() -> void:
	for storm: bool in [false, true]:
		var game := _stop(storm)
		assert_eq(game.fx_params["fx_fall"], Vector2(0.0, 1.0 if storm else 0.55))
		_assert_arrival_writes(game)


func test_missing_map_is_zero_then_built_fills_it_once() -> void:
	for storm: bool in [false, true]:
		var game := _stop(storm)
		_assert_arrival_writes(game)
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
	_assert_arrival_writes(game)
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
		game.writes.clear()
		game.snow_cover.depth_cm = game.snow_cover.MAX_CM
		game.clock.elapsed = 4.0 # one game minute, the existing snow update interval
		game._update_snow()
		assert_gt(absf(float(game.fx_params["fx_snow"]) - before), 0.002)
		assert_eq(game.fx_params["fx_fall"], fall)
		assert_eq(game.writes.size(), 1)
		if game.writes.size() == 1:
			var sent: Dictionary = game.writes[0]["values"]
			assert_eq(sent.size(), 2, "both snow values in one call")
			assert_eq(sent.get("fx_snow"), game.fx_params["fx_snow"])
			assert_eq(sent.get("fx_map_snow_base"), game.fx_params["fx_map_snow_base"])
		_assert_map_base(game)


func test_snow_gate_keeps_both_globals_below_threshold() -> void:
	for storm: bool in [false, true]:
		var game := _stop(storm)
		var before: Dictionary = game.fx_params.duplicate()
		game.writes.clear()
		game._update_snow() # less than a minute must not write either value
		assert_eq(game.fx_params, before)
		assert_true(game.writes.is_empty())
		# Saturation makes a minute of snowfall smaller than the shader's 0.002 gate.
		game.snow_cover.depth_cm = game.snow_cover.MAX_CM
		game._apply_fx()
		before = game.fx_params.duplicate()
		game.writes.clear()
		game.clock.elapsed = 4.0
		game._update_snow()
		assert_almost_eq(game.snow_at_min, game.clock.game_minutes(), 0.00001)
		assert_eq(game.fx_params, before)
		assert_true(game.writes.is_empty(), "below the 0.002 gate sends nothing")


func test_globals_are_declared_and_registered() -> void:
	for name: String in ["fx_fall", "fx_map_snow_base"]:
		assert_true(FxState.GLOBALS.has(name))
		assert_true(ProjectSettings.has_setting("shader_globals/" + name))
	var setting: Dictionary = ProjectSettings.get_setting("shader_globals/fx_map_snow_base", {})
	assert_eq(setting.get("type"), "float")
	assert_eq(setting.get("value"), 0.0)
	var common := FileAccess.get_file_as_string("res://fx/shaders/fx_common.gdshaderinc")
	assert_true(checker._strip_comments(common).contains("global uniform float fx_map_snow_base;"))


func _contract_rows(contract: String) -> Array[Array]:
	match contract:
		"hoar":
			return [["hoar", HOAR_START, []], ["hoar", HOAR_WIND, []], ["hoar", HOAR_MASK, []], ["", HOAR_PAINT, []]]
		"blow":
			return [["blow", BLOW_START, []], ["blow", BLOW_MASK, []], ["", BLOW_PAINT, ["if(blow>0.01)"]]]
		"ring":
			var guard := ["if(splash_k>0.01)"]
			var selected := ["if(splash_k>0.01)", "if(splash_cell>0.5)"]
			return [["splash_k", SPLASH, []], ["sp", "vec2 sp = world_pos.xz * 2.0;", guard],
				["sc", "vec2 sc = floor(sp);", guard], ["ph", "float ph = TIME * 1.3 + fx_hash(sc) * 7.0;", guard],
				["slot", "float slot = floor(ph);", guard], ["st", "float st = ph - slot;", guard],
				["splash_cell", RING_SELECT, guard], ["so", RING_CENTER, selected], ["ring", RING_EDGE, selected],
				["", "base += vec3(ring * splash_k * 0.16);", selected]]
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
		# Extend the existing snow guard with this contract's own write roots.
		var protected_names: Array = checker.SNOW_FLOW_VALUES.duplicate()
		for name: String in expected:
			if not protected_names.has(name):
				protected_names.append(name)
		var errors: PackedStringArray = checker._snow_flow_errors(tokens, pairs, opening, closing, steps, protected_names)
		var write_errors: Array[String] = []
		for name: String in expected:
			if checker._write_statements(tokens, pairs, opening + 1, closing, name, write_errors) != expected[name]:
				errors.append("쓰기 목록·순서 오류: " + name)
		errors.append_array(PackedStringArray(write_errors))
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
	for mask: String in ["1.0", "(1.0 - trodden)"]:
		_reject("hoar", HOAR_MASK, HOAR_MASK.replace("(1.0 - smoothstep(0.05, 0.3, trodden))", mask))


func test_hoar_tracks_mask_clears_every_press() -> void:
	# Read the actual shader thresholds, not a second hard-coded copy of its formula.
	var regex := RegEx.new()
	assert_eq(regex.compile("hoar\\s*\\*=[^;]*\\(1\\.0\\s*-\\s*smoothstep\\(\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*,\\s*trodden\\s*\\)\\)"), OK)
	var found := regex.search(checker._strip_comments(FileAccess.get_file_as_string(SHADER_PATH)))
	assert_not_null(found, "849dd942's linear remainder leaves frost on every footprint")
	if found == null:
		return
	var low := float(found.get_string(1))
	var high := float(found.get_string(2))
	assert_lt(low, high)
	if low >= high:
		return
	assert_almost_eq(1.0 - smoothstep(low, high, 0.0), 1.0, 0.000001, "fresh cell")
	for kind: String in SnowTracks.PRESS:
		assert_almost_eq(1.0 - smoothstep(low, high, float(SnowTracks.PRESS[kind])), 0.0, 0.000001, kind)
		var tracks := SnowTracks.new(1)
		tracks.press(0, kind)
		assert_almost_eq(1.0 - smoothstep(low, high, 1.0 - tracks.value(0)), 0.0, 0.000001, kind + " stored byte")


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


func test_ring_selection_precedes_geometry_and_rejects_eager_work() -> void:
	# 849dd942 computes both rows before selection; exact nested paths must reject that.
	_assert_contract("ring")
	_reject("ring", RING_SELECT, RING_SELECT.replace("0.4 * fx_fall.x", "1.0"))
	_reject("ring", "if (splash_cell > 0.5)", "if (true)")
	var source := FileAccess.get_file_as_string(SHADER_PATH)
	var changed := source.replace(RING_CENTER, "").replace("if (splash_cell > 0.5) {", RING_CENTER + "\nif (splash_cell > 0.5) {")
	assert_ne(changed, source)
	assert_true(_weather_errors(changed, "ring").has(checker.UNSUPPORTED_PREFIX + "눈 계약 실행 위치·순서: " + checker._compact(RING_CENTER)))


func test_weather_writes_reject_components_subscripts_and_all_operators() -> void:
	var source := FileAccess.get_file_as_string(SHADER_PATH)
	assert_eq(_weather_errors(source, "ring").size(), 0)
	for target: String in ["so.x", "so.xy", "sp[0]"]:
		var name := "sp" if target.begins_with("sp") else "so"
		for op: String in checker.WRITE_OPERATORS:
			var write := target + op + (";" if op in ["++", "--"] else "0.0;")
			var changed := source.replace(RING_CENTER, RING_CENTER + "\n" + write)
			assert_ne(changed, source)
			assert_true(_weather_errors(changed, "ring").has("보호 값 성분·첨자 쓰기: " + name), write)
	for write: String in ["++so.x;", "--sp[0];"]:
		var name := "sp" if write.contains("sp") else "so"
		var changed := source.replace(RING_CENTER, RING_CENTER + "\n" + write)
		assert_true(_weather_errors(changed, "ring").has("보호 값 성분·첨자 쓰기: " + name), write)


func test_weather_writes_reject_builtin_out_and_user_out_inout() -> void:
	var source := FileAccess.get_file_as_string(SHADER_PATH)
	assert_eq(_weather_errors(source, "hoar").size(), 0)
	var changed := source.replace(HOAR_MASK, HOAR_MASK + "\nfloat ignored_part = modf(1.0, hoar);")
	assert_ne(changed, source)
	assert_true(_weather_errors(changed, "hoar").has(checker.UNSUPPORTED_PREFIX + "보호 값 out 내장 함수 전달: hoar (modf)"))
	for target: String in ["so.x", "sp[0]"]:
		var name := "so" if target.begins_with("so") else "sp"
		changed = source.replace(RING_CENTER, RING_CENTER + "\nfloat ignored_part = modf(1.0, " + target + ");")
		assert_ne(changed, source)
		assert_true(_weather_errors(changed, "ring").has(checker.UNSUPPORTED_PREFIX + "보호 값 out 내장 함수 전달: " + name + " (modf)"))
	for qualifier: String in ["out", "inout"]:
		var helper := "void reset_weather(" + qualifier + " vec2 value) { value = vec2(0.0); }\n"
		changed = source.replace("void fragment() {", helper + "void fragment() {")
		changed = changed.replace(RING_CENTER, RING_CENTER + "\nreset_weather(so);")
		assert_ne(changed, source)
		assert_true(_weather_errors(changed, "ring").has(checker.UNSUPPORTED_PREFIX + "보호 값 사용자 함수 전달: so (reset_weather)"), qualifier)


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
