extends "res://addons/gut/test.gd"
## fx library (docs/design/briefs/shaders.md): every shader parses, the
## weather-to-shader table keeps the colour rules, and smoke keeps the ban lines.

const FxState = preload("res://fx/fx_state.gd")
const Smoke = preload("res://fx/smoke.gd")
const DIR := "res://fx/shaders/"


func _shader_files() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".gdshader"):
			out.append(DIR + f)
	return out


func test_every_fx_shader_parses() -> void:
	var files := _shader_files()
	assert_gt(files.size(), 10, "shader count %d" % files.size())
	for path in files:
		var s: Shader = load(path)
		assert_not_null(s, path)
		# A shader that fails to parse reports no uniforms at all.
		assert_gt(s.get_shader_uniform_list().size(), 0, path)


func test_no_screen_or_depth_reads() -> void:
	# Mobile budget (shaders.md 5장): nothing reads the screen or depth buffer.
	for path in _shader_files() + [DIR + "fx_common.gdshaderinc"]:
		var code := FileAccess.get_file_as_string(path)
		assert_false(code.contains("hint_screen_texture"), path)
		assert_false(code.contains("hint_depth_texture"), path)


func test_shader_globals_are_registered() -> void:
	for name in FxState.GLOBALS:
		assert_true(ProjectSettings.has_setting("shader_globals/" + name), name)
	var code := FileAccess.get_file_as_string(DIR + "fx_common.gdshaderinc")
	for name in FxState.GLOBALS:
		assert_true(code.contains("global uniform") and code.contains(name), name)


func test_params_stay_in_range() -> void:
	for kinds in [["clear"], ["fog", "snow"], ["blizzard"], ["sleet"], ["rain"], ["overcast"], [], ["unknown"]]:
		for c in [-25.0, -8.0, -1.0, 4.0]:
			for hour in [0.0, 7.0, 12.0, 16.0, 21.0]:
				var p := FxState.params_for(kinds, c, Vector2(0.3, 1.0), 0.7, hour)
				for key in ["fx_wet", "fx_snow", "fx_frost", "fx_fade", "fx_flash"]:
					var v: float = p[key]
					assert_true(v >= 0.0 and v <= 1.0, "%s %s %s" % [kinds, c, key])
				var wind: Vector3 = p["fx_wind"]
				assert_almost_eq(Vector2(wind.x, wind.y).length(), 1.0, 0.001)


func test_weather_cases() -> void:
	var sulechow := FxState.params_for(["fog", "snow"], -14.0)
	assert_lt(float(sulechow["fx_wet"]), 0.3, "nothing is wet at -14")
	assert_gt(float(sulechow["fx_snow"]), 0.5)
	assert_gt(float(sulechow["fx_frost"]), 0.5)
	var thaw := FxState.params_for(["rain"], 4.0, Vector2(1, 0), 0.4, 12.0, 0.0)
	assert_eq(float(thaw["fx_wet"]), 1.0)
	assert_eq(float(thaw["fx_snow"]), 0.0)
	assert_eq(float(thaw["fx_frost"]), 0.0)
	var sleet := FxState.params_for(["sleet"], -1.0)
	assert_gt(float(sleet["fx_wet"]), 0.5)
	# Unknown kinds are ignored like weather.gd does.
	assert_eq(FxState.params_for(["acid"], -5.0), FxState.params_for([], -5.0))


func _sky_blue(c: Color) -> bool:
	# Sky blue is reserved for support (decisions.md 날씨와 빛): no bluish
	# weather or hour colour may carry real saturation.
	return c.b > c.r and c.s > 0.15


func test_no_sky_blue_or_red_in_weather_colours() -> void:
	for kind in FxState.KIND_TINT:
		assert_false(_sky_blue(FxState.KIND_TINT[kind]), kind)
	for band in FxState.BAND_LOOK.values():
		for key in ["sun", "ambient", "tint"]:
			var c: Color = band[key]
			assert_false(_sky_blue(c), "%s %s" % [band["name"], key])
			# Red is for discontent and shortage only: dusk stays amber-grey.
			assert_lt(c.r - c.g, 0.15, "%s %s" % [band["name"], key])


func test_hour_bands() -> void:
	assert_eq(String(FxState.hour_band(3.0)["name"]), "night")
	assert_eq(String(FxState.hour_band(7.0)["name"]), "dawn")
	assert_eq(String(FxState.hour_band(12.0)["name"]), "day")
	assert_eq(String(FxState.hour_band(16.0)["name"]), "dusk")
	assert_eq(String(FxState.hour_band(23.5)["name"]), "night")
	assert_eq(String(FxState.hour_band(-1.0)["name"]), "night")
	# Deep winter is the default (seasons_regions.md 7장: 07:00 / 08:30 / 14:50 / 16:30).
	assert_eq(String(FxState.hour_band(14.9)["name"]), "dusk")
	assert_eq(String(FxState.hour_band(16.6)["name"]), "night")


func test_hour_bands_follow_the_season() -> void:
	assert_eq(String(FxState.hour_band(6.0, "deep_winter")["name"]), "night")
	assert_eq(String(FxState.hour_band(6.0, "early_thaw")["name"]), "dawn")
	assert_eq(String(FxState.hour_band(17.0, "deep_winter")["name"]), "night")
	assert_eq(String(FxState.hour_band(17.0, "late_winter")["name"]), "dusk")
	assert_eq(String(FxState.hour_band(16.0, "early_thaw")["name"]), "day")
	# Unknown season falls back to deep winter.
	assert_eq(FxState.hour_band(16.0, "summer"), FxState.hour_band(16.0))
	for season in FxState.SEASON_BANDS:
		var b: Dictionary = FxState.SEASON_BANDS[season]
		assert_true(b["dawn"] < b["day"] and b["day"] < b["dusk"] and b["dusk"] < b["night"], season)


func test_snow_level_by_season() -> void:
	assert_eq(FxState.snow_level_for("deep_winter"), 2)
	assert_eq(FxState.snow_level_for("late_winter", true), 1)
	assert_eq(FxState.snow_level_for("early_thaw"), 1)
	assert_eq(FxState.snow_level_for("early_thaw", true), 0)
	assert_eq(FxState.snow_for_level(FxState.snow_level_for("early_thaw", true)), 0.0)


func test_smoke_has_no_chimney_or_column_kinds() -> void:
	# Ban line: buildings, factory chimneys and cooling towers never smoke, and a
	# stopped train never sends a column up. Only these four kinds exist.
	assert_eq(Smoke.KINDS.keys().size(), 4)
	for kind in ["chimney", "column", "factory", "cooling_tower", "wagon_flue", "pyre"]:
		assert_null(Smoke.build(kind), kind)


func test_smoke_heights_follow_the_ban_lines() -> void:
	for kind in Smoke.KINDS:
		assert_true(Smoke.max_rise(kind) <= float(Smoke.KINDS[kind]["max_rise"]) + 0.001, "%s rises %.2f" % [kind, Smoke.max_rise(kind)])
	# Standing engine: steam by the wheels stays below a metre.
	assert_lt(Smoke.max_rise("loco_idle"), 1.0)
	# Omen and field smoke hugs the ground.
	assert_lt(Smoke.max_rise("low_drift"), 1.5)
	# Stove steam is faint.
	assert_true(float(Smoke.KINDS["stove"]["max_alpha"]) <= 0.25)
	# Running smoke flows back more than it rises: never a straight column.
	var d: Vector3 = Vector3(Smoke.KINDS["loco_run"]["dir"]).normalized()
	assert_gt(absf(d.x), 2.0 * d.y)


func test_locomotive_switches_by_speed() -> void:
	assert_eq(Smoke.kind_for_locomotive(0.0), "loco_idle")
	assert_eq(Smoke.kind_for_locomotive(0.5), "loco_idle")
	assert_eq(Smoke.kind_for_locomotive(12.0), "loco_run")
	var run := Smoke.build("loco_run")
	var idle := Smoke.build("loco_idle")
	Smoke.update_locomotive(run, idle, 0.0)
	assert_false(run.emitting)
	assert_true(idle.emitting)
	Smoke.update_locomotive(run, idle, 15.0)
	assert_true(run.emitting)
	assert_false(idle.emitting)
	run.free()
	idle.free()


func test_apply_writes_every_global_and_nothing_else() -> void:
	var p := FxState.params_for(["sleet"], -1.0)
	p["not_a_global"] = 1.0
	var written := FxState.apply(p)
	assert_eq(written.size(), FxState.GLOBALS.size())
	assert_false(written.has("not_a_global"))
	FxState.apply(FxState.params_for([], -5.0))


func test_gallery_has_touch_controls_and_a_way_back() -> void:
	# On the phone there are no number keys and no other way out (S2 PR 88 menu).
	var gallery = load("res://fx/gallery.tscn").instantiate()
	add_child_autofree(gallery)
	for name in ["BackButton", "PrevButton", "NextButton"]:
		assert_not_null(gallery.find_child(name, true, false), name)
	assert_true(ResourceLoader.exists(gallery.menu_scene()), gallery.menu_scene())
	assert_false(get_tree().is_quit_on_go_back(), "back gesture goes to the menu")
	gallery.step(-1)
	assert_eq(gallery.current, gallery.PRESETS.size() - 1, "previous wraps to the last preset")
	gallery.step(1)
	assert_eq(gallery.current, 0, "next wraps to the first preset")


func test_gallery_shows_the_three_storm_stops() -> void:
	# weather_fx 14장: before (still, overcast), during (blizzard, no shadows),
	# after (clear, coldest, deepest snow).
	var gallery = load("res://fx/gallery.tscn").instantiate()
	add_child_autofree(gallery)
	var at: Dictionary = {}
	for i in range(gallery.PRESETS.size()):
		at[String(gallery.PRESETS[i]["name"])] = i
	for name in ["11_storm_before", "12_storm_during", "13_storm_after"]:
		assert_true(at.has(name), name)
	gallery.apply_preset(at["11_storm_before"])
	assert_true(gallery.sun.shadow_enabled)
	assert_false(gallery.snow_fx.emitting, "nothing falls before the storm")
	var before: float = gallery.sun.light_energy
	gallery.apply_preset(at["12_storm_during"])
	assert_false(gallery.sun.shadow_enabled, "no shadows inside the storm")
	assert_true(gallery.snow_fx.emitting)
	assert_lt(gallery.sun.light_energy, before)
	gallery.apply_preset(at["13_storm_after"])
	assert_true(gallery.sun.shadow_enabled)
	assert_false(gallery.snow_fx.emitting)
	assert_gt(gallery.sun.light_energy, before, "brightest after the storm")
	var p: Dictionary = gallery.PRESETS[at["13_storm_after"]]
	assert_gt(float(p["snow"]), float(gallery.PRESETS[at["11_storm_before"]]["snow"]))
	assert_lt(float(p["wind"]), float(gallery.PRESETS[at["12_storm_during"]]["wind"]))
	gallery.apply_preset(0)
	assert_true(gallery.sun.shadow_enabled, "other presets keep shadows")
