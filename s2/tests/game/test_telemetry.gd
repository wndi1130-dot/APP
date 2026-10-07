extends "res://addons/gut/test.gd"

const Telemetry = preload("res://game/sim/telemetry.gd")


func test_empty_log_is_one_valid_line() -> void:
	var tm := Telemetry.new("run_0")
	var line := tm.to_json_line()
	assert_false(line.contains("\n"))
	var parsed: Variant = JSON.parse_string(line)
	assert_true(parsed is Dictionary)
	assert_eq((parsed as Dictionary).keys(), ["v", "run", "end", "staySec", "carrySec", "zones", "noise", "hordes", "injuries", "ammo"])
	assert_eq(parsed["run"], "run_0")
	assert_eq(parsed["end"], "")
	assert_eq(parsed["staySec"], -1.0)
	assert_eq(parsed["carrySec"], 0.0)


func test_zones_record_entries_and_time_in_first_entered_order() -> void:
	var tm := Telemetry.new()
	tm.zone_enter("platform", 0.0)
	tm.zone_tick("platform", 12.5)
	tm.zone_enter("street", 12.5)
	tm.zone_tick("street", 30.0)
	tm.zone_enter("platform", 42.5)
	tm.zone_tick("platform", 5.0)
	tm.zone_tick("platform", 0.0)
	tm.zone_tick("platform", -3.0)
	assert_eq(tm.current_zone, "platform")
	var zones: Dictionary = tm.to_dict()["zones"]
	assert_eq(zones.keys(), ["platform", "street"])
	assert_eq(zones["platform"]["enter"], [0.0, 42.5])
	assert_almost_eq(float(zones["platform"]["seconds"]), 17.5, 0.001)
	assert_almost_eq(float(zones["street"]["seconds"]), 30.0, 0.001)


func test_zone_tick_without_enter_still_counts() -> void:
	var tm := Telemetry.new()
	tm.zone_tick("signal_box", 4.0)
	assert_eq(tm.to_dict()["zones"]["signal_box"]["enter"], [])
	assert_almost_eq(float(tm.to_dict()["zones"]["signal_box"]["seconds"]), 4.0, 0.001)


func test_noise_curve_keeps_only_changes() -> void:
	var tm := Telemetry.new()
	tm.noise(1.0, 0)
	tm.noise(2.0, 0)
	tm.noise(3.0, 3)
	tm.noise(4.0, 3)
	tm.noise(5.0, 9)
	assert_eq(tm.to_dict()["noise"], [[1.0, 0], [3.0, 3], [5.0, 9]])


func test_hordes_and_injuries_in_order() -> void:
	var tm := Telemetry.new()
	tm.horde(270.0, 0, 6, "east")
	tm.horde(499.5, 1, 8, "north")
	tm.injury(310.25, "s2_scout", "scratch")
	var d := tm.to_dict()
	assert_eq(d["hordes"], [
		{"t": 270.0, "index": 0, "size": 6, "entry": "east"},
		{"t": 499.5, "index": 1, "size": 8, "entry": "north"},
	])
	assert_eq(d["injuries"].size(), 1)
	assert_eq(d["injuries"][0]["who"], "s2_scout")
	assert_eq(d["injuries"][0]["kind"], "scratch")
	assert_almost_eq(float(d["injuries"][0]["t"]), 310.3, 0.001)


func test_ammo_sums_and_ignores_non_positive() -> void:
	var tm := Telemetry.new()
	tm.ammo("pistol", 2)
	tm.ammo("pistol", 1)
	tm.ammo("shell", 0)
	tm.ammo("craft", -1)
	tm.ammo("shell", 1)
	assert_eq(tm.to_dict()["ammo"], {"pistol": 3, "shell": 1})


func test_carry_time_ignores_non_positive() -> void:
	var tm := Telemetry.new()
	tm.carry_time(1.5)
	tm.carry_time(0.0)
	tm.carry_time(-2.0)
	tm.carry_time(2.0)
	assert_almost_eq(float(tm.to_dict()["carrySec"]), 3.5, 0.001)


func test_end_accepts_only_receipt_reasons() -> void:
	var tm := Telemetry.new()
	assert_false(tm.end("fled", 100.0))
	assert_eq(tm.to_dict()["end"], "")
	for reason: String in ["departed", "limit", "wiped"]:
		assert_true(tm.end(reason, 1234.56), reason)
		assert_eq(tm.to_dict()["end"], reason)
	assert_almost_eq(float(tm.to_dict()["staySec"]), 1234.6, 0.001)
	assert_true(tm.end("departed", 0.0))
	assert_eq(tm.to_dict()["staySec"], 0.0)


func test_full_run_line_round_trips() -> void:
	var tm := Telemetry.new("seed_42")
	tm.zone_enter("platform", 0.0)
	tm.zone_tick("platform", 60.0)
	tm.noise(61.0, 1)
	tm.horde(270.0, 0, 6, "east")
	tm.injury(300.0, "s2_lead", "bite")
	tm.ammo("pistol", 4)
	tm.carry_time(45.0)
	tm.end("departed", 1500.0)
	var line := tm.to_json_line()
	assert_false(line.contains("\n"))
	assert_false(line.contains("  "))
	var parsed: Variant = JSON.parse_string(line)
	assert_true(parsed is Dictionary)
	assert_eq(JSON.stringify(parsed, "", true), JSON.stringify(JSON.parse_string(JSON.stringify(tm.to_dict())), "", true))
	assert_eq(parsed["end"], "departed")
	assert_eq(parsed["staySec"], 1500.0)
	assert_eq(parsed["hordes"][0]["entry"], "east")
	assert_eq(parsed["ammo"]["pistol"], 4.0)
	assert_eq(tm.to_json_line(), line)
