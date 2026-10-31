extends "res://addons/gut/test.gd"
## The atmosphere frame (fx/atmosphere.gd, 사용자 2026-10-24 분위기 변주): one cold
## value with the act table and its test switch, the hour bands from the season
## brief, what falls by temperature (no rain below zero), the colour rules, the
## look getting colder, and that the field, the train and the rules keep apart.

const Atmosphere = preload("res://fx/atmosphere.gd")
const FxState = preload("res://fx/fx_state.gd")
const FieldGame = preload("res://game/field_game.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const BuildingView = preload("res://game/world/building_view.gd")
const SeasonTable = preload("res://game/season_table.gd")
const MapEdge = preload("res://fx/map_edge.gd")


func before_each() -> void:
	Atmosphere.scheme = Atmosphere.DEFAULT_SCHEME


func after_each() -> void:
	Atmosphere.scheme = Atmosphere.DEFAULT_SCHEME


# ---------------------------------------------------------------- the cold

func test_the_default_flow_is_the_one_season_table() -> void:
	# The user's season answer of 10-24 with the prologue (나), as S1 and the
	# train read it: an early cold snap at the start, late autumn rain, first
	# frosts and snow by the end of the first leg, deep winter by the end of act
	# 1, the coldest in act 2, the thaw only in act 3.
	assert_eq(Atmosphere.scheme, "autumn_to_thaw")
	var start := Atmosphere.cold_for("prologue")
	assert_almost_eq(start, Atmosphere.cold_from_temp(float(SeasonTable.row(1)["temp"])), 0.0001, "the first stretch's temperature")
	var autumn := Atmosphere.cold_for("prologue", SeasonTable.seg_progress(5))
	assert_lt(autumn, start, "late autumn is milder than the cold snap the leg sets out in")
	assert_lt(Atmosphere.look(12.0, ["clear"], "K1", autumn)["temp_c"], 7.0)
	assert_eq(Atmosphere.season_at("prologue"), "late_autumn")
	assert_eq(Atmosphere.season_at("prologue", 1.0), "late_autumn", "the prologue's one state (늦가을 → 이른 첫 추위)")
	assert_eq(Atmosphere.season_at("act1", 0.0), "early_winter")
	assert_eq(Atmosphere.season_at("act1", 1.0), "deep_winter", "deep winter by the end of act 1")
	assert_eq(Atmosphere.season_at("act2", 0.5), "deep_winter")
	assert_eq(Atmosphere.season_at("act3", 0.5), "early_thaw")
	# Colder at every step from late autumn to the end of act 2, then the thaw.
	var last := -1.0
	for row in [["prologue", SeasonTable.seg_progress(5)], ["prologue", 0.5], ["prologue", 1.0], ["act1", 0.0], ["act1", 0.5], ["act1", 1.0], ["act2", 0.0], ["act2", 1.0]]:
		var c := Atmosphere.cold_for(String(row[0]), float(row[1]))
		assert_gte(c, last, "%s %.2f never warmer than before" % row)
		last = c
	assert_eq(last, 1.0, "the coldest is in act 2")
	assert_lt(Atmosphere.cold_for("act3", 1.0), Atmosphere.cold_for("act3", 0.0), "it thaws as act 3 goes")
	assert_eq(Atmosphere.side_for("prologue"), 0.0)
	assert_eq(Atmosphere.side_for("act3"), 1.0)
	# Unknown acts read as the prologue; progress is clamped.
	assert_eq(Atmosphere.cold_for("epilogue"), Atmosphere.cold_for("prologue"))
	assert_eq(Atmosphere.cold_for("act3", 5.0), Atmosphere.cold_for("act3", 1.0))


func test_cold_reads_the_temperature_backwards() -> void:
	for t in [7.0, 4.0, 0.0, -0.5, -3.0, -7.0, -10.0, -14.0]:
		for side in [0.0, 1.0]:
			var c := Atmosphere.cold_from_temp(t, side)
			assert_almost_eq(Atmosphere.cold_key(c, "temp", -1, side), t, 0.01, "%s side %s" % [t, side])
	assert_eq(Atmosphere.cold_from_temp(12.0), 0.0)
	assert_eq(Atmosphere.cold_from_temp(-42.0), 1.0, "S1's hardest cold is the deepest winter picture")


func test_the_prologue_rains_then_freezes() -> void:
	# Above zero in late autumn: what the rules call snow falls as rain.
	var first := Atmosphere.look(12.0, ["snow"], "K1", Atmosphere.cold_for("prologue", SeasonTable.seg_progress(4)))
	assert_gt(float(first["temp_c"]), 1.5)
	assert_eq(String(first["falls"]), "rain")
	assert_eq(int(first["snow_level"]), 0)
	# By the end of the prologue the nights freeze: still water is ice by night.
	var last_c := Atmosphere.cold_for("prologue", 1.0)
	var night := Atmosphere.look(22.0, ["clear"], "K1", last_c)
	assert_lt(float(night["temp_c"]), -3.0)
	assert_gt(float(night["ice"]), 0.9)
	assert_ne(String(Atmosphere.look(22.0, ["snow"], "K1", last_c)["falls"]), "rain")


func test_the_old_table_stays_as_a_test_switch() -> void:
	assert_eq(Atmosphere.cold_for("prologue", 0.0, "winter_to_thaw"), 1.0, "10-09: deep winter at the start")
	assert_eq(Atmosphere.season_for(Atmosphere.cold_for("act3", 0.5, "winter_to_thaw"), Atmosphere.side_for("act3", "winter_to_thaw")), "early_thaw")
	Atmosphere.scheme = "winter_to_thaw"
	assert_eq(Atmosphere.cold_for("prologue"), 1.0, "the switch is what cold_for reads")


func test_the_same_cold_reads_differently_either_side_of_midwinter() -> void:
	var autumn := Atmosphere.look(12.0, ["clear"], "K1", 0.35, {"side": 0.0})
	var spring := Atmosphere.look(12.0, ["clear"], "K1", 0.35, {"side": 1.0})
	assert_gt(float(autumn["leaves"]), 0.3, "leaf still on the birches in autumn")
	assert_eq(float(spring["leaves"]), 0.0, "none in the thaw")
	assert_gt(float(spring["snow_cm"]), float(autumn["snow_cm"]), "old snow lies in the thaw")
	assert_gt(float(spring["sunset"]) - float(spring["sunrise"]), float(autumn["sunset"]) - float(autumn["sunrise"]), "days lengthen toward spring")
	assert_eq(String(autumn["season"]), "late_autumn")
	assert_eq(String(spring["season"]), "early_thaw")


func test_the_anchors_keep_the_season_briefs_hours() -> void:
	# seasons_regions.md 2.2 and 7장 (the spring side): the same band starts
	# FxState already has.
	var anchors := {1.0: "deep_winter", 0.7: "late_winter", 0.35: "early_thaw"}
	for c in anchors:
		var mine := Atmosphere.band_starts(c, 1.0)
		var theirs: Dictionary = FxState.SEASON_BANDS[anchors[c]]
		for band in ["dawn", "day", "dusk", "night"]:
			assert_almost_eq(float(mine[band]), float(theirs[band]), 0.01, "%s %s" % [anchors[c], band])
	var deep := Atmosphere.sun_times(1.0)
	assert_almost_eq(deep.x, 8.0, 0.001)
	assert_almost_eq(deep.y, 15.0 + 50.0 / 60.0, 0.001)


func test_bands_add_up_and_agree_with_fx_state_in_deep_winter() -> void:
	for h in range(0, 96):
		var hour := h * 0.25
		var w := Atmosphere.band_weights(hour, 1.0)
		var total := 0.0
		for k in w:
			assert_true(float(w[k]) >= 0.0)
			total += float(w[k])
		assert_almost_eq(total, 1.0, 0.0001, "%.2f" % hour)
	for hour in [3.0, 7.6, 12.0, 15.5, 17.2, 23.0]:
		assert_eq(Atmosphere.band_of(hour, 1.0), String(FxState.hour_band(hour)["name"]), "%.1f" % hour)


func test_midday_in_deep_winter_keeps_the_users_low_cold_sun() -> void:
	# User 2026-10-17: a low cold sun (0.80, 0.85, 0.92) at 35 degrees.
	var t := Atmosphere.sun_times(1.0)
	var noon := (t.x + t.y) * 0.5
	var l := Atmosphere.look(noon, ["clear"], "K1", 1.0)
	assert_eq(String(l["band"]), "day")
	var sun: Color = l["sun_color"]
	var want: Color = FxState.BAND_LOOK["day"]["sun"]
	assert_almost_eq(sun.r, want.r, 0.001)
	assert_almost_eq(sun.g, want.g, 0.001)
	assert_almost_eq(sun.b, want.b, 0.001)
	assert_almost_eq(float(l["sun_pitch"]), FxState.SUN_PITCH, 0.05)
	# Away from midday the sun is lower (longer shadows), never flatter than the floor.
	var morning := Atmosphere.look(t.x + 0.3, ["clear"], "K1", 1.0)
	assert_gt(float(morning["sun_pitch"]), float(l["sun_pitch"]))
	assert_lte(float(morning["sun_pitch"]), -16.0)
	assert_gt(float(morning["sun_yaw"]), 0.0, "the morning sun stands east of south")


# ---------------------------------------------------------------- what falls

func test_no_rain_below_zero() -> void:
	for temp in [-20.0, -8.0, -3.0, -2.5, -1.0, 0.0, 0.5, 1.0]:
		for kinds in [["snow"], ["sleet"], ["blizzard"], ["fog", "snow"], ["rain"]]:
			var drawn := Atmosphere.drawn_kinds(kinds, temp)
			if kinds == ["rain"]:
				continue
			assert_false(drawn.has("rain"), "%s at %.1f" % [kinds, temp])
	assert_eq(Atmosphere.drawn_kinds(["snow"], 4.0), ["rain"], "warm: snow falls as rain")
	assert_eq(Atmosphere.drawn_kinds(["snow"], -1.0), ["sleet"], "around zero: sleet")
	assert_eq(Atmosphere.drawn_kinds(["sleet"], -14.0), ["snow"], "hard cold: no sleet")
	assert_eq(Atmosphere.drawn_kinds(["blizzard"], -14.0), ["blizzard"])
	assert_eq(Atmosphere.drawn_kinds(["clear", "fog", "overcast"], 6.0), ["clear", "fog", "overcast"])
	assert_eq(Atmosphere.drawn_kinds(["acid"], -5.0), [], "unknown kinds go, as weather.gd does")


# ---------------------------------------------------------------- colour rules

func _alarm_red(c: Color) -> bool:
	# Red is for discontent and shortage: no strong colour of red's own hue.
	return c.s > 0.5 and (c.h < 12.0 / 360.0 or c.h > 348.0 / 360.0)


func test_band_colours_stay_inside_the_colour_rules() -> void:
	for band in Atmosphere.BANDS:
		for key in ["zenith", "horizon", "glow", "sun", "ambient"]:
			for table in [Atmosphere.BANDS, Atmosphere.WARM_BANDS]:
				if not table[band].has(key):
					continue
				var c: Color = table[band][key]
				assert_lte(c.s, Atmosphere.BAND_SAT, "%s %s" % [band, key])
				# No loud sky blue: blue is the support gauge's. Dark night blues
				# carry little colour however their saturation reads.
				if c.b > c.r:
					assert_lte(maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b)), Atmosphere.SKY_BLUE_CHROMA, "%s %s bluish" % [band, key])
				assert_false(_alarm_red(c), "%s %s" % [band, key])


func test_looks_stay_in_range_and_inside_the_rules() -> void:
	for cold in [0.0, 0.35, 0.7, 1.0]:
		for hour in [0.0, 6.0, 7.8, 9.0, 12.0, 15.0, 16.2, 18.0, 22.0]:
			for kinds in [["clear"], ["overcast"], ["fog", "snow"], ["blizzard"], ["sleet"], []]:
				var l := Atmosphere.look(hour, kinds, "K4", cold)
				for key in ["cloud", "haze", "veil", "ice", "icicles", "breath", "window_frost", "leaves", "sun_visible", "lum", "wind"]:
					var v := float(l[key])
					assert_true(v >= 0.0 and v <= 1.0, "%s %s %s %s = %f" % [cold, hour, kinds, key, v])
				for key in ["sky_top", "sky_low", "sun_glow", "sun_color", "ambient_color"]:
					assert_false(_alarm_red(l[key]), "%s %s %s %s" % [cold, hour, kinds, key])
				assert_true(String(l["falls"]) in ["none", "snow", "sleet", "rain"])
				if float(l["temp_c"]) <= 0.0:
					assert_ne(String(l["falls"]), "rain", "no rain below zero")


func test_the_hours_have_their_own_colour() -> void:
	var t := Atmosphere.sun_times(1.0)
	var dawn := Atmosphere.look(t.x + 0.2, ["clear"], "K1", 1.0)
	var day := Atmosphere.look(12.0, ["clear"], "K1", 1.0)
	var dusk := Atmosphere.look(t.y - 0.4, ["clear"], "K1", 1.0)
	var night := Atmosphere.look(t.y + 2.0, ["clear"], "K1", 1.0)
	# Dawn and dusk lean warm low down, day stays grey-white, night is dark.
	assert_gt(Color(dawn["sky_low"]).r - Color(dawn["sky_low"]).b, 0.2, "dawn gold and pink")
	assert_gt(Color(dusk["sky_low"]).r - Color(dusk["sky_low"]).b, 0.25, "dusk orange")
	assert_lt(absf(Color(day["sky_low"]).r - Color(day["sky_low"]).b), 0.08)
	assert_gt(Color(dusk["sky_top"]).b, Color(dusk["sky_top"]).g, "violet overhead at dusk")
	assert_lt(Color(night["sky_top"]).v, 0.12)
	assert_lt(float(night["sun_energy"]), float(dawn["sun_energy"]))
	# Weather closes the colour down: an overcast dawn is greyer than a clear one.
	var grey_dawn := Atmosphere.look(t.x + 0.2, ["overcast"], "K1", 1.0)
	assert_lt(Color(grey_dawn["sky_low"]).s, Color(dawn["sky_low"]).s)
	assert_lt(float(Atmosphere.look(12.0, ["blizzard"], "K1", 1.0)["sun_energy"]), float(day["sun_energy"]))


func test_the_dusk_shade_is_the_open_sky_s_cool_light() -> void:
	# A warm low sun and a shade lit by the sky's blue, as in the sunset sky
	# photo: the ground does not go one orange-brown at dusk.
	for cold in [0.0, 1.0]:
		var t := Atmosphere.sun_times(cold)
		var dusk := Atmosphere.look(t.y - 0.4, ["clear"], "K1", cold)
		var sun: Color = dusk["sun_color"]
		var shade: Color = dusk["ambient_color"]
		assert_gt(sun.r - sun.b, 0.2, "a warm low sun (cold %s)" % cold)
		assert_lt(sun.s, 0.6 if cold < 0.5 else 0.5, "no deep orange sun (cold %s)" % cold)
		assert_gte(shade.b, shade.r, "a cool shade (cold %s)" % cold)
	# Late autumn's dusk sun is warmer than deep winter's (the season shows in it).
	var autumn: Color = Atmosphere.look(Atmosphere.sun_times(0.0).y - 0.4, ["clear"], "K1", 0.0)["sun_color"]
	var winter: Color = Atmosphere.look(Atmosphere.sun_times(1.0).y - 0.4, ["clear"], "K1", 1.0)["sun_color"]
	assert_gt(autumn.r - autumn.b, winter.r - winter.b, "a warmer sun in late autumn")


func test_the_night_light_is_a_neutral_grey() -> void:
	# After dark the only colour is the lamps' orange: the moon and the fill are
	# a faintly warm grey, under a clear sky or cloud (no blue screen).
	for cold in [0.0, 1.0]:
		var t := Atmosphere.sun_times(cold)
		for kinds in [["clear"], ["overcast"], ["rain"]]:
			var night := Atmosphere.look(t.y + 3.0, kinds, "K1", cold)
			for key in ["ambient_color", "sun_color"]:
				var c: Color = night[key]
				assert_lte(c.b, c.r, "%s %s (cold %s) not blue" % [key, kinds, cold])
				assert_lt(c.s, 0.08, "%s %s (cold %s) grey" % [key, kinds, cold])


func test_the_tone_holds_in_every_weather_and_only_colour_goes() -> void:
	# Contrast 1.2 about the hour's grey under a clear sky; an overcast, a fog or
	# a sleet spreads the tones further, never less, and takes colour out (the
	# grey day used to go flat).
	var clear := Atmosphere.grade(Atmosphere.look(12.0, ["clear"], "K1", 0.0))
	assert_almost_eq(float(clear["spread"]), Atmosphere.TONE_CONTRAST, 0.0001)
	for kinds in [["overcast"], ["fog"], ["sleet"], ["blizzard"]]:
		var g := Atmosphere.grade(Atmosphere.look(12.0, kinds, "K1", 0.0))
		assert_gt(float(g["spread"]), float(clear["spread"]), "%s spreads the tones more" % [kinds])
		assert_lte(float(g["spread"]), Atmosphere.TONE_CONTRAST_DIM + 0.0001)
		for c: float in [0.1, 0.4, 0.8]:
			var out: float = 0.5 + float(g["contrast"]) * (float(g["brightness"]) * c - 0.5)
			assert_almost_eq(out, float(g["spread"]) * (c - 0.4) + 0.4, 0.0001, "%s turns about the day's grey" % [kinds])
		assert_lt(float(g["saturation"]), float(clear["saturation"]), "%s takes colour out" % [kinds])
	# Godot: 0.5 + k(b·c − 0.5). By day that is 1.2(c − 0.4) + 0.4.
	for c: float in [0.1, 0.4, 0.8]:
		var out: float = 0.5 + float(clear["contrast"]) * (float(clear["brightness"]) * c - 0.5)
		assert_almost_eq(out, 1.2 * (c - 0.4) + 0.4, 0.0001)
	assert_almost_eq(float(clear["pivot"]), Atmosphere.TONE_PIVOT_DAY, 0.0001)
	assert_lte(float(clear["saturation"]), 1.0, "the grade never adds colour by day")
	# At night the grey sinks with the light, so the spread keeps the night's level.
	var t := Atmosphere.sun_times(0.0)
	var night := Atmosphere.grade(Atmosphere.look(t.y + 3.0, ["clear"], "K1", 0.0))
	var p := float(night["pivot"])
	assert_lt(p, 0.15)
	assert_gt(float(night["spread"]), Atmosphere.TONE_CONTRAST, "the night spreads the lamps from the dark")
	assert_almost_eq(0.5 + float(night["contrast"]) * (float(night["brightness"]) * p - 0.5), p, 0.0001)


func test_rain_by_day_eases_the_spread_and_keeps_the_grey() -> void:
	# The fall dims a rain noon evenly; the spread eases so the darks stay over
	# the dark line (decision 470), still above a clear day's, about the same grey.
	var l := Atmosphere.look(12.0, ["rain"], "K1", 0.0)
	assert_eq(String(l["falls"]), "rain")
	var rain := Atmosphere.grade(l)
	var overcast := Atmosphere.grade(Atmosphere.look(12.0, ["overcast"], "K1", 0.0))
	var veiled: float = lerpf(Atmosphere.TONE_CONTRAST, Atmosphere.TONE_CONTRAST_DIM, float(l["veil"]))
	var w: Dictionary = l["weights"]
	assert_almost_eq(float(rain["spread"]), veiled * (1.0 + Atmosphere.TONE_CONTRAST_DUSK * float(w["dusk"])) * (1.0 - Atmosphere.TONE_RAIN_EASE * float(l["fall"]) * float(w["day"])), 0.0001)
	assert_gt(float(w["day"]), 0.9, "noon is the day")
	assert_lt(float(rain["spread"]), float(overcast["spread"]), "rain eases the spread")
	assert_gt(float(rain["spread"]), Atmosphere.TONE_CONTRAST, "never flatter than a clear day")
	assert_almost_eq(float(rain["pivot"]), float(overcast["pivot"]), 0.0001, "about the same grey")
	# Godot parts the channels by the spread times the saturation: the ease keeps the colour.
	var sat_plain: float = lerpf(1.0, 0.9, float(l["veil"])) * (1.0 + 0.1 * (float(w["dawn"]) + float(w["dusk"])) * (1.0 - float(l["veil"]))) * float(l.get("region_sat", 1.0))
	assert_almost_eq(float(rain["saturation"]) * float(rain["spread"]), sat_plain * veiled * (1.0 + Atmosphere.TONE_CONTRAST_DUSK * float(w["dusk"])), 0.0001, "the ease keeps the colour")
	assert_lt(float(rain["saturation"]), 1.0, "and adds none")
	for c: float in [0.1, 0.4, 0.8]:
		var out: float = 0.5 + float(rain["contrast"]) * (float(rain["brightness"]) * c - 0.5)
		assert_almost_eq(out, float(rain["spread"]) * (c - float(rain["pivot"])) + float(rain["pivot"]), 0.0001)
	# The night's rain and the snow keep their spread.
	var t := Atmosphere.sun_times(0.0)
	var night_l := Atmosphere.look(t.y + 3.0, ["rain"], "K1", 0.0)
	var night_veiled: float = lerpf(Atmosphere.TONE_CONTRAST, Atmosphere.TONE_CONTRAST_DIM, maxf(float(night_l["veil"]), float(night_l["weights"]["night"])))
	assert_almost_eq(float(Atmosphere.grade(night_l)["spread"]), night_veiled * (1.0 + Atmosphere.TONE_CONTRAST_DUSK * float(night_l["weights"]["dusk"])), 0.0001)
	var snow_l := Atmosphere.look(12.0, ["snow"], "K1", 0.9)
	assert_ne(String(snow_l["falls"]), "rain")
	var snow_veiled: float = lerpf(Atmosphere.TONE_CONTRAST, Atmosphere.TONE_CONTRAST_DIM, float(snow_l["veil"]))
	assert_almost_eq(float(Atmosphere.grade(snow_l)["spread"]), snow_veiled * (1.0 + Atmosphere.TONE_CONTRAST_DUSK * float(snow_l["weights"]["dusk"])), 0.0001)


func test_an_overcast_lights_from_above_and_keeps_the_ground() -> void:
	# A closed sky by day: part of the fill becomes a high light with a soft
	# shadow, so walls fall darker while the ground keeps its light; a
	# clear sky and the night are as the look has them.
	var l := Atmosphere.look(12.0, ["overcast"], "K1", 0.0)
	var lt := Atmosphere.light(l)
	assert_lt(float(lt["ambient_energy"]), float(l["ambient_energy"]), "less flat fill")
	assert_lt(float(lt["sun_pitch"]), float(l["sun_pitch"]), "the light stands higher")
	assert_lt(float(lt["shadow"]), 0.6, "a soft shadow under cloud")
	var ground_before := float(l["sun_energy"]) * sin(deg_to_rad(-float(l["sun_pitch"]))) + float(l["ambient_energy"])
	var ground_after := float(lt["sun_energy"]) * sin(deg_to_rad(-float(lt["sun_pitch"]))) + float(lt["ambient_energy"])
	assert_almost_eq(ground_after, ground_before, ground_before * 0.02, "the ground keeps its light")
	# A wall facing away from the light gets only the fill: darker than before.
	assert_lt(float(lt["ambient_energy"]), float(l["ambient_energy"]) * 0.8)
	# The low dusk sun behind cloud keeps its colour share by strength, not more.
	var t := Atmosphere.sun_times(0.0)
	var dusk := Atmosphere.look(t.y - 0.4, ["overcast"], "K1", 0.0)
	var dusk_lt := Atmosphere.light(dusk)
	var dusk_before := float(dusk["sun_energy"]) * sin(deg_to_rad(clampf(-float(dusk["sun_pitch"]), 5.0, 90.0))) + float(dusk["ambient_energy"])
	var dusk_after := float(dusk_lt["sun_energy"]) * sin(deg_to_rad(-float(dusk_lt["sun_pitch"]))) + float(dusk_lt["ambient_energy"])
	assert_almost_eq(dusk_after, dusk_before, dusk_before * 0.02, "no flood of dusk light from overhead")
	for k in [[12.0, ["clear"]], [t.y + 3.0, ["overcast"]]]:
		var same := Atmosphere.look(float(k[0]), k[1], "K1", 0.0)
		var same_lt := Atmosphere.light(same)
		assert_almost_eq(float(same_lt["sun_energy"]), float(same["sun_energy"]), 0.0001, "%s" % [k])
		assert_almost_eq(float(same_lt["sun_pitch"]), float(same["sun_pitch"]), 0.0001)
		assert_almost_eq(float(same_lt["shadow"]), 1.0, 0.0001)


func test_a_closed_sky_greys_the_day_and_what_falls_dims_it() -> void:
	# Cloud greys the day and gives back as fill what it takes of the sun; what
	# falls and the wind dim it (1 − 0.15·fall − 0.2·wind), after our own
	# CLOUD_KEEP. K1's wind is 0.5.
	var clear := _face(Atmosphere.look(12.0, ["clear"], "K1", 1.0))
	var grey := _face(Atmosphere.look(12.0, ["overcast"], "K1", 1.0))
	var snow := _face(Atmosphere.look(12.0, ["snow"], "K1", 1.0))
	var storm := _face(Atmosphere.look(12.0, ["blizzard"], "K1", 1.0))
	assert_almost_eq(grey / clear, Atmosphere.CLOUD_KEEP * (1.0 - 0.2 * 0.5), 0.03, "an overcast keeps most of the day")
	assert_lt(snow, grey, "falling snow dims it")
	assert_lt(storm, snow, "a blizzard's wind more")
	# The veil greys the light without darkening it: never less than the band's.
	var l := Atmosphere.look(12.0, ["overcast"], "K1", 1.0)
	var band := Atmosphere.look(12.0, ["clear"], "K1", 1.0)
	assert_gte(Color(l["ambient_color"]).srgb_to_linear().get_luminance(), Color(band["ambient_color"]).srgb_to_linear().get_luminance() - 0.001)
	assert_lt(Color(l["ambient_color"]).s, Color(band["ambient_color"]).s, "grey, not tinted")


func test_the_view_fill_lights_the_walls_by_day_and_not_at_night() -> void:
	# Decision 476: the diagonal view shows the walls turned from the sun.
	for kinds in [["clear"], ["overcast"]]:
		var t := Atmosphere.sun_times(0.5)
		var day := Atmosphere.light(Atmosphere.look(12.0, kinds, "K1", 0.5))
		var dusk := Atmosphere.light(Atmosphere.look(t.y - 0.4, kinds, "K1", 0.5))
		var night := Atmosphere.light(Atmosphere.look(t.y + 2.0, kinds, "K1", 0.5))
		assert_almost_eq(float(day["fill_energy"]), Atmosphere.VIEW_FILL, 0.01, "%s by day" % [kinds])
		assert_between(float(dusk["fill_energy"]), 0.0, Atmosphere.VIEW_FILL * 0.75, "%s less at dusk" % [kinds])
		assert_almost_eq(float(night["fill_energy"]), 0.0, 0.001, "%s none at night" % [kinds])


func test_a_low_day_sun_lights_the_ground_as_noon_does() -> void:
	# Decision 471 B0: two stops in five come in the morning. Through the day
	# band the ground keeps the noon light; the sun still stands low (long
	# shadows), and dawn and dusk still dim.
	for c in [0.0, 0.5, 1.0]:
		var t := Atmosphere.sun_times(c)
		var noon := (t.x + t.y) * 0.5
		var morning := t.x + 1.0
		for kinds in [["clear"], ["overcast"]]:
			var at_noon := _face(Atmosphere.look(noon, kinds, "K1", c))
			var early := Atmosphere.look(morning, kinds, "K1", c)
			assert_almost_eq(_face(early) / at_noon, 1.0, 0.03, "%s %s morning" % [c, kinds])
			assert_gt(float(early["sun_pitch"]), float(Atmosphere.look(noon, kinds, "K1", c)["sun_pitch"]), "the sun still low")
			assert_lt(_face(Atmosphere.look(t.x - 0.3, kinds, "K1", c)), at_noon * 0.8, "%s %s dawn still dim" % [c, kinds])


## The light an up-facing face gets (linear).
func _face(l: Dictionary) -> float:
	var s := sin(deg_to_rad(clampf(-float(l["sun_pitch"]), 5.0, 90.0)))
	return float(l["sun_energy"]) * s * Color(l["sun_color"]).srgb_to_linear().get_luminance() + float(l["ambient_energy"]) * Color(l["ambient_color"]).srgb_to_linear().get_luminance()


func test_it_looks_colder_as_the_cold_rises() -> void:
	var warm := Atmosphere.look(9.0, ["clear"], "K1", 0.0)
	var mid := Atmosphere.look(9.0, ["clear"], "K1", 0.5)
	var hard := Atmosphere.look(9.0, ["clear"], "K1", 1.0)
	for key in ["breath", "icicles", "window_frost", "ice"]:
		assert_lte(float(warm[key]), float(mid[key]), key)
		assert_lte(float(mid[key]), float(hard[key]), key)
	assert_gt(float(hard["breath"]), float(warm["breath"]))
	assert_gt(float(hard["icicles"]), 0.5)
	assert_eq(float(warm["icicles"]), 0.0)
	assert_lt(float(hard["temp_c"]), float(mid["temp_c"]))
	assert_lt(int(warm["snow_level"]), int(hard["snow_level"]))
	assert_eq(int(hard["snow_level"]), 2)
	assert_eq(int(warm["snow_level"]), 0)
	assert_gt(float(warm["leaves"]), 0.5, "autumn leaf in the warm stage")
	# Shorter days in the cold.
	var day_warm := Atmosphere.sun_times(0.0)
	var day_hard := Atmosphere.sun_times(1.0)
	assert_gt(day_warm.y - day_warm.x, day_hard.y - day_hard.x)
	# Breath is thicker at night.
	var night := Atmosphere.look(22.0, ["clear"], "K1", 0.5)
	assert_gt(float(night["breath"]), float(mid["breath"]))


func test_params_are_every_global_and_keep_the_haze_grey() -> void:
	var l := Atmosphere.look(8.3, ["clear"], "K1", 1.0)
	var p := Atmosphere.params(l, Vector2(1, 0.2))
	for key in FxState.GLOBALS:
		assert_true(p.has(key), key)
	assert_eq(p.size(), FxState.GLOBALS.size())
	var cold: Vector4 = p["fx_cold"]
	assert_eq(cold.x, 1.0)
	assert_gt(cold.y, 0.9, "water is ice at -14")
	# The hour's colour reaches haze and flakes at a quarter: they stay near grey.
	var tint: Color = p["fx_tint"]
	assert_lt(tint.s, 0.15)
	# A closed sky throws no cloud shadows; a clear one does.
	var cloud: Vector4 = p["fx_cloud"]
	assert_gt(cloud.w, 0.0)
	var shut: Vector4 = Atmosphere.params(Atmosphere.look(12.0, ["overcast"], "K1", 1.0))["fx_cloud"]
	assert_almost_eq(shut.w, 0.0, 0.001)
	assert_eq(FxState.apply(p).size(), FxState.GLOBALS.size())


func test_the_sight_mask_leaves_the_day_readable() -> void:
	# Ground out of sight stays readable by day and sinks after dark (469 D3):
	# never seen 0.70 and seen before 0.85 at noon; dimmed less at night (0.80,
	# 0.90), where the dark is the night's own.
	var t := Atmosphere.sun_times(0.0)
	var day: Vector2 = Atmosphere.params(Atmosphere.look(12.0, ["overcast"], "K1", 0.0))["fx_sight"]
	var dusk: Vector2 = Atmosphere.params(Atmosphere.look(t.y - 0.4, ["clear"], "K1", 0.0))["fx_sight"]
	var night: Vector2 = Atmosphere.params(Atmosphere.look(t.y + 3.0, ["clear"], "K1", 0.0))["fx_sight"]
	assert_almost_eq(day.x, FxState.SIGHT_DAY.x, 0.001)
	assert_almost_eq(day.y, FxState.SIGHT_DAY.y, 0.001)
	assert_almost_eq(night.x, FxState.SIGHT_NIGHT.x, 0.01)
	assert_almost_eq(night.y, FxState.SIGHT_NIGHT.y, 0.01)
	assert_between(dusk.x, minf(night.x, day.x), maxf(night.x, day.x), "dusk between night and day")
	assert_lt(night.x, night.y, "at night too, ground seen before stays lighter")
	assert_lt(day.x, day.y, "ground seen before stays lighter than ground never seen")
	# A stop drawn without the frame (a storm stage, the gallery) goes by its hour band.
	assert_eq(FxState.params_for(["clear"], 0.0, Vector2(1, 0), 0.4, 12.0)["fx_sight"], FxState.SIGHT_DAY)
	assert_eq(FxState.params_for(["clear"], 0.0, Vector2(1, 0), 0.4, 23.0)["fx_sight"], FxState.SIGHT_NIGHT)


func test_regions_name_the_twelve_bands() -> void:
	assert_eq(Atmosphere.REGIONS.size(), 12)
	assert_eq(Atmosphere.region_key("region_04"), "K4")
	assert_eq(Atmosphere.region_key("k10"), "K10")
	assert_eq(Atmosphere.region_key("nowhere"), Atmosphere.DEFAULT_REGION)
	for k in Atmosphere.REGIONS:
		var r: Dictionary = Atmosphere.REGIONS[k]
		for key in ["forest", "conifer", "birch", "water", "town", "hills", "spire", "silo", "wind", "mist"]:
			assert_true(float(r[key]) >= 0.0 and float(r[key]) <= 1.0, "%s %s" % [k, key])
		assert_true(String(r["poles"]) in ["telegraph", "catenary"])
	# Poles before the border, catenary masts after it (presentation_motion 7b).
	assert_eq(String(Atmosphere.REGIONS["K1"]["poles"]), "telegraph")
	assert_eq(String(Atmosphere.REGIONS["K3"]["poles"]), "catenary")


# ---------------------------------------------------------------- the field

func _stop_with(o: Dictionary) -> Node:
	var game = FieldGame.new()
	game.opts = o
	add_child_autofree(game)
	game.set_process(false)
	return game


## A stop in the hardest cold unless more says otherwise.
func _stop(more := {}) -> Node:
	var o := {"seed": 5, "raiders": false, "auto_pause": false, "weather": ["fog", "snow"], "cold": 1.0}
	o.merge(more, true)
	return _stop_with(o)


func test_a_stop_takes_its_cold_from_the_act() -> void:
	var first = _stop_with({"seed": 5, "raiders": false, "auto_pause": false, "weather": ["fog", "snow"]})
	assert_eq(first.cold, Atmosphere.cold_for("prologue"), "the first stop of the prologue by default")
	assert_eq(first.side, 0.0)
	assert_eq(String(first.atmo["season"]), "late_autumn", "the season table's name")
	var thaw = _stop_with({"seed": 5, "raiders": false, "auto_pause": false, "weather": ["fog", "snow"], "act": "act3", "act_progress": 0.5})
	assert_eq(thaw.cold, Atmosphere.cold_for("act3", 0.5))
	assert_eq(thaw.side, 1.0)
	assert_eq(String(thaw.atmo["season"]), "early_thaw")
	# The old snow deepens with the cold through act 1, not in one season step.
	var early = _stop_with({"seed": 5, "raiders": false, "auto_pause": false, "weather": ["clear"], "act": "act1", "act_progress": 0.3})
	var later = _stop_with({"seed": 5, "raiders": false, "auto_pause": false, "weather": ["clear"], "act": "act1", "act_progress": 0.7})
	assert_eq(String(early.atmo["season"]), String(later.atmo["season"]))
	assert_gt(later.snow_cover.depth_cm, early.snow_cover.depth_cm + 3.0)


## 코디네이터 10-25 (the field's air follows the season table; it was -14 C for
## every stop): the cold moves the rules' air too, and what falls with it, so a
## rainy picture is a rainy stop. The field clock stays the rules' own.
func test_the_cold_changes_the_picture_and_the_air_with_it() -> void:
	var hard = _stop()
	var warm = _stop({"cold": 0.0})
	assert_eq(hard.cold, 1.0)
	assert_almost_eq(hard.weather.ambient_c, -14.0, 0.001, "the hardest cold is the old fixed air")
	assert_almost_eq(warm.weather.ambient_c, 7.0, 0.001, "the warmest picture's midday")
	assert_eq(hard.weather.kinds, ["fog", "snow"] as Array[String])
	assert_eq(warm.weather.kinds, ["fog", "rain"] as Array[String], "what falls is the air's, in the rules as in the picture")
	assert_eq(warm.clock.SUNSET_MIN, hard.clock.SUNSET_MIN)
	# The picture: the warm stage's snow falls as rain on bare, wet ground.
	assert_eq(String(warm.atmo["falls"]), "rain")
	assert_eq(int((warm.snow.draw_pass_1 as QuadMesh).material.get_shader_parameter("shape")), 0, "rain streaks")
	assert_eq(int((hard.snow.draw_pass_1 as QuadMesh).material.get_shader_parameter("shape")), 1, "round flakes")
	assert_eq(warm.snow_cover.depth_cm, 0.0)
	assert_gt(hard.snow_cover.depth_cm, 20.0)
	assert_gt(float(warm.fx_params["fx_wet"]), float(hard.fx_params["fx_wet"]))
	assert_lt(float((warm.fx_params["fx_cold"] as Vector4).y), 0.1, "standing water is open")


func test_the_light_follows_the_hour_through_the_stop() -> void:
	var game = _stop({"weather": ["clear"]})
	var arrival: Color = game.sun.light_color
	var day_energy: float = game.sun.light_energy
	# 15:30, low sun at dusk: warmer and weaker, the shadows longer.
	game.clock.elapsed = (15.5 * 60.0 - 630.0) * 60.0 / 15.0
	game._update_light()
	assert_eq(String(game.atmo["band"]), "dusk")
	assert_gt(game.sun.light_color.r - game.sun.light_color.b, arrival.r - arrival.b)
	assert_lt(game.sun.light_energy, day_energy)
	assert_gt(game.sun.rotation_degrees.x, -30.0)
	assert_true(game.environment.adjustment_enabled)


func test_past_the_map_edge_the_ground_goes_on_under_fog() -> void:
	# 결정 448 17 (「맵끝이 대놓고 랜더링 되있음」): no flat slab past the map. The
	# ground goes on in the edge's colours under the map's own material, and fog
	# in the hour's colour lies over it.
	var game = _stop({"weather": ["clear"], "cold": 0.0})
	assert_not_null(game.map_edge)
	var box: AABB = game.map_edge.ground.get_aabb()
	var w := float(game.view.grid.width)
	var h := float(game.view.grid.height)
	assert_lt(box.position.x, -30.0)
	assert_gt(box.end.x, w + 30.0)
	assert_lt(box.position.z, -30.0)
	assert_gt(box.end.z, h + 30.0)
	assert_eq(game.map_edge.ground.material_override, game.view.material, "the map's own ground material")
	assert_eq(game.map_edge.sheets.size(), 3)
	assert_eq(Color(game.map_edge.fog_mats[0].get_shader_parameter("fog_color")), Color(game.fx_light["fog_color"]))
	assert_eq(game.map_edge.fog_mats[0].get_shader_parameter("vis"), game.view.vis_texture, "the fog reads the map's sight mask")
	# The ground past the edge settles to the edge's mean colour, not a grey slab.
	var mean: Color = MapEdge.mean_edge_color(game.view.grid)
	assert_almost_eq(mean.a, 1.0, 0.0001)
	# The fog frame starts inside the edge and leaves the middle of the map open.
	var fog_box: AABB = game.map_edge.sheets[0].get_aabb()
	assert_lt(fog_box.position.x, -30.0)
	var frame: ArrayMesh = game.map_edge.sheets[0].mesh
	var verts: PackedVector3Array = frame.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for v in verts:
		var inside := v.x > MapEdge.FOG_INSET + 0.01 and v.x < w - MapEdge.FOG_INSET - 0.01 and v.z > MapEdge.FOG_INSET + 0.01 and v.z < h - MapEdge.FOG_INSET - 0.01
		assert_false(inside, "no fog corner in the map's middle: %s" % v)


func test_a_foggy_day_lays_fog_over_the_field() -> void:
	# 색감 루프 C5: fog in the look lays a layer over the whole field, thin round
	# the eye and closing from where sight ends; other weathers keep it clear.
	assert_gt(Atmosphere.field_fog(Atmosphere.look(12.0, ["fog"], "K1", 0.0)), 0.9)
	for kinds in [["overcast"], ["rain"], ["clear"], ["snow"]]:
		assert_eq(Atmosphere.field_fog(Atmosphere.look(12.0, kinds, "K1", 0.0)), 0.0, "%s" % [kinds])
	var game = _stop({"weather": ["fog"], "cold": 0.0})
	assert_true(game.map_edge.field.visible)
	assert_almost_eq(float(game.map_edge.field_mat.get_shader_parameter("clear_r")), FieldGame.SIGHT_RADIUS * game.eye_mult(), 0.01, "fog closes in where sight ends")
	var clear = _stop({"weather": ["clear"], "cold": 0.0})
	assert_false(clear.map_edge.field.visible, "nothing drawn over the field on other days")
	# Lit by the hour: the night's fog is far darker than the day's (no glow).
	var day_light: Vector3 = MapEdge.fog_light(Atmosphere.light(Atmosphere.look(12.0, ["fog"], "K1", 0.0)))
	var t := Atmosphere.sun_times(0.0)
	var night_light: Vector3 = MapEdge.fog_light(Atmosphere.light(Atmosphere.look(t.y + 2.0, ["fog"], "K1", 0.0)))
	assert_lt(night_light.length(), day_light.length() * 0.3)


func test_the_fog_lifts_in_the_room_the_eye_is_in() -> void:
	# The reference game lays no fog sheet in a room: in the building the player
	# is in, its walls cut away, the fog over the field lifts off its footprint.
	var game = _stop({"weather": ["fog"], "cold": 0.0})
	var edge = game.map_edge
	edge.set_room(Rect2i(4, 5, 6, 3))
	assert_eq(edge.field_mat.get_shader_parameter("room"), Vector4(4, 5, 10, 8))
	edge.set_room(Rect2i(0, 0, -1, -1))
	assert_eq(edge.field_mat.get_shader_parameter("room"), Vector4(0, 0, -1, -1), "outside: no room")
	assert_false(game._open_room().has_area(), "the player starts outside")
	assert_true(FileAccess.get_file_as_string("res://fx/shaders/field_fog.gdshader").contains("ROOM_KEEP"))


func test_breath_shows_in_the_cold_and_frost_comes_at_night() -> void:
	var game = _stop()
	assert_not_null(game.breath)
	for p in game.people:
		p.visible = true
	game.breath.tick(0.016, game)
	assert_gt(game.breath.shown, 0, "everyone breathes out in the cold")
	assert_lte(game.breath.shown, game.breath.MAX_PUFFS)
	assert_false(game.cold_frost.visible, "no frost on the edges by day")
	var night = _stop({"look_hour": 20.0})
	assert_true(night.cold_frost.visible, "frost creeps in on a cold night")
	var warm = _stop({"cold": 0.0, "look_hour": 20.0})
	assert_false(warm.cold_frost.visible, "not in the warm stage")


func test_a_storm_stop_keeps_its_own_light() -> void:
	var game = _stop({"storm": "during"})
	assert_almost_eq(game.sun.rotation_degrees.x, FxState.SUN_PITCH, 0.001)
	assert_null(game.cold_frost, "the storm has its own frost")


# ---------------------------------------------------------------- the train and the houses

func test_the_slice_hangs_the_outside_behind_the_running_train() -> void:
	var f = SliceFlow.new()
	# The train's own screen at the stop: without the stop scene (with it, the
	# stop pick is the scene from the roof, test_stop_cinema.gd).
	# Seed 2 draws snow on stretch 1 and sleet on stretch 4 from the season table.
	f.opts = {"skip_field": true, "seed": 2, "cinema": false}
	add_child_autofree(f)
	assert_not_null(f.outside)
	assert_eq(f.outside.get_parent(), f.train.camera, "the camera carries it")
	assert_true(f.outside.moving, "running on the first stretch")
	# The first stretch sets out in the early cold snap; late autumn rain comes after.
	assert_ne(String(f.weather.falls), "rain", "the first stretch, the cold snap")
	assert_eq(String(f.outside_look({}, 4)["falls"]), "rain", "the fourth stretch, late autumn: its sleet falls as rain")
	assert_eq(String(f.outside_look({}, 4)["season"]), "late_autumn")
	f.next()
	assert_false(f.outside.moving, "standing at the stop")
	var deep = SliceFlow.new()
	deep.opts = {"skip_field": true, "seed": 3, "look": {"cold": 1.0}}
	add_child_autofree(deep)
	assert_eq(String(deep.weather.falls), "snow", "deep winter: snow")
	assert_eq(deep.frost.modulate.a, 1.0, "the corners frost over in the hardest cold")
	var warm = SliceFlow.new()
	warm.opts = {"skip_field": true, "seed": 3, "look": {"cold": 0.0, "kinds": ["snow"], "hour": 12.0}}
	add_child_autofree(warm)
	assert_eq(String(warm.weather.falls), "rain")
	assert_eq(warm.frost.modulate.a, 0.0, "no frost in the warm rain")
	assert_false(warm.weather.drift.visible, "no lying snow to blow")
	var clear = SliceFlow.new()
	clear.opts = {"skip_field": true, "seed": 3, "look": {"kinds": ["clear"]}}
	add_child_autofree(clear)
	assert_false(clear.weather.far.visible, "nothing falls from a clear sky")


func test_the_outside_card_is_painted_without_smoke_or_screen_reads() -> void:
	var code := FileAccess.get_file_as_string("res://fx/shaders/outside_view.gdshader")
	assert_false(code.contains("hint_screen_texture"))
	assert_false(code.contains("hint_depth_texture"))
	var s: Shader = load("res://fx/shaders/outside_view.gdshader")
	assert_gt(s.get_shader_uniform_list().size(), 10)


func test_houses_keep_a_little_paint() -> void:
	var painted := 0
	for b in range(16):
		var c: Color = BuildingView.accent_for(b)
		assert_true(c.a >= 0.0 and c.a <= 1.0)
		assert_false(_alarm_red(c), str(b))
		if c.a > 0.0:
			painted += 1
	assert_gt(painted, 10, "most houses kept some paint on their doors")
	assert_lt(painted, 16, "some never had any")


# ---------------------------------------------------------------- CC0 photos (사용자 10-25, 공개 자산 먼저)

func test_the_photo_skies_and_the_ground_grain_are_in_the_build() -> void:
	for key in Atmosphere.SKY_PHOTOS:
		var tex := Atmosphere.sky_texture(key)
		assert_not_null(tex, key)
		if tex != null:
			# Phone budget (사용자 10-25, 공개 자산 먼저): 1024 wide at most.
			assert_eq(tex.get_size(), Vector2(1024, 256), key)
	var ground: Texture2D = load(Atmosphere.GROUND_DETAIL)
	assert_not_null(ground)
	assert_eq(ground.get_size(), Vector2(512, 512))
	for name in FxState.TEXTURE_GLOBALS:
		assert_true(ProjectSettings.has_setting("shader_globals/" + name), name)
		assert_eq(String(ProjectSettings.get_setting("shader_globals/" + name)["type"]), "sampler2D", name)


func test_each_hour_and_weather_takes_its_photo_sky() -> void:
	var t := Atmosphere.sun_times(1.0)
	var cases := [
		[t.x + 0.2, ["clear"], "dawn"], [12.0, ["clear"], "day"], [t.y - 0.4, ["clear"], "dusk"], [t.y + 2.0, ["clear"], "night"],
		[12.0, ["overcast"], "overcast"], [12.0, ["fog"], "mist"], [12.0, ["snow"], "snow"], [12.0, ["blizzard"], "snow"],
	]
	for c in cases:
		var l := Atmosphere.look(float(c[0]), c[1], "K1", 1.0)
		assert_eq(Atmosphere.sky_main(l), String(c[2]), "%s %s" % [c[0], c[1]])
		var total := 0.0
		for row in l["skies"]:
			assert_true(Atmosphere.SKY_PHOTOS.has(String(row[0])), String(row[0]))
			total += float(row[1])
		assert_almost_eq(total, 1.0, 0.0001)
	# Warm rain is a grey sky too.
	assert_eq(Atmosphere.sky_main(Atmosphere.look(12.0, ["snow"], "K1", 0.0)), "overcast")


func test_the_train_and_the_field_show_the_photo_sky() -> void:
	var f = SliceFlow.new()
	f.opts = {"skip_field": true, "seed": 3, "look": {"hour": 12.0, "kinds": ["overcast"]}}
	add_child_autofree(f)
	var m: ShaderMaterial = f.outside.material
	assert_eq(float(m.get_shader_parameter("photo_on")), 1.0)
	var w: Vector3 = m.get_shader_parameter("sky_w")
	assert_almost_eq(w.x + w.y + w.z, 1.0, 0.0001)
	var game = _stop({"weather": ["fog"]})
	assert_eq(game.sky_photo, "mist", "the puddles give back the foggy sky")


func test_the_ground_reads_its_photo_grain_once() -> void:
	# Phone budget: one fetch for all four grains, on top of the sight mask.
	var code := FileAccess.get_file_as_string("res://game/world/world_vis.gdshader")
	assert_eq(code.count("texture(fx_ground"), 1)
	assert_false(code.contains("hint_screen_texture"))


# -------------------------------------------------------- region-band looks

func test_region_looks_match_the_twelve_bands_and_stay_in_range() -> void:
	assert_eq(Atmosphere.REGION_LOOK.size(), 12)
	var look_keys: Array = Atmosphere.REGION_LOOK.keys()
	var region_keys: Array = Atmosphere.REGIONS.keys()
	look_keys.sort()
	region_keys.sort()
	assert_eq_deep(look_keys, region_keys)
	for key: String in Atmosphere.REGION_LOOK:
		var rl: Dictionary = Atmosphere.REGION_LOOK[key]
		var saturation: float = float(rl["sat"])
		var haze: float = float(rl["haze"])
		assert_true(saturation >= 0.8 and saturation <= 1.1, "%s saturation" % key)
		assert_true(haze >= -0.06 and haze <= 0.1, "%s haze" % key)
		for tint_key: String in ["light", "shade"]:
			var tint: Color = rl[tint_key]
			for channel: float in [tint.r, tint.g, tint.b]:
				assert_true(channel >= 0.85 and channel <= 1.15, "%s %s channels" % [key, tint_key])


func test_region_looks_keep_linear_luminance_and_light_energy() -> void:
	for pair: Array in [["K1", "K11"], ["K3", "K9"]]:
		var a: Dictionary = Atmosphere.look(12.0, ["clear"], String(pair[0]), 1.0)
		var b: Dictionary = Atmosphere.look(12.0, ["clear"], String(pair[1]), 1.0)
		for key: String in ["sun_color", "ambient_color"]:
			var a_color: Color = a[key]
			var b_color: Color = b[key]
			assert_almost_eq(a_color.srgb_to_linear().get_luminance(), b_color.srgb_to_linear().get_luminance(), 0.005, "%s %s luminance" % [pair, key])
		for key: String in ["sun_energy", "ambient_energy"]:
			assert_almost_eq(float(a[key]), float(b[key]), 0.0001, "%s %s energy" % [pair, key])


func test_region_looks_keep_the_light_of_a_sun_at_full_red() -> void:
	# The dawn sun is already at full red, so a warm band's tint cannot keep its
	# luminance in the colour alone (K11 lost 3.5 %): what the gamut takes comes
	# back as energy, and every band lights the ground as K1 does (colour x energy).
	for cold: float in [0.0, 1.0]:
		for hour: float in [Atmosphere.sun_times(cold).x, 12.0]:
			var plain: Dictionary = Atmosphere.look(hour, ["clear"], "K1", cold)
			for i: int in range(2, 13):
				var band: Dictionary = Atmosphere.look(hour, ["clear"], "K%d" % i, cold)
				for pair: Array in [["sun_color", "sun_energy"], ["ambient_color", "ambient_energy"]]:
					var want: float = Color(plain[pair[0]]).srgb_to_linear().get_luminance() * float(plain[pair[1]])
					var got: float = Color(band[pair[0]]).srgb_to_linear().get_luminance() * float(band[pair[1]])
					assert_almost_eq(got / maxf(want, 0.0001), 1.0, 0.002, "K%d %s at %.2f h, cold %s" % [i, pair[0], hour, cold])


func _region_rgb_distance(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


func test_neighbouring_region_looks_have_distinct_light_colours() -> void:
	for i: int in range(1, 12):
		var a_key: String = "K%d" % i
		var b_key: String = "K%d" % (i + 1)
		var a: Dictionary = Atmosphere.look(12.0, ["clear"], a_key, 1.0)
		var b: Dictionary = Atmosphere.look(12.0, ["clear"], b_key, 1.0)
		var a_sun: Color = a["sun_color"]
		var b_sun: Color = b["sun_color"]
		var a_ambient: Color = a["ambient_color"]
		var b_ambient: Color = b["ambient_color"]
		var distance: float = maxf(_region_rgb_distance(a_sun, b_sun), _region_rgb_distance(a_ambient, b_ambient))
		assert_gt(distance, 0.004, "%s and %s differ" % [a_key, b_key])


func test_region_looks_have_the_requested_warm_cool_and_saturation_order() -> void:
	var coast: Dictionary = Atmosphere.look(12.0, ["clear"], "K11", 1.0)
	var city: Dictionary = Atmosphere.look(12.0, ["clear"], "K9", 1.0)
	var plain: Dictionary = Atmosphere.look(12.0, ["clear"], "K1", 1.0)
	var pines: Dictionary = Atmosphere.look(12.0, ["clear"], "K4", 1.0)
	var coast_sun: Color = coast["sun_color"]
	var city_sun: Color = city["sun_color"]
	var city_ambient: Color = city["ambient_color"]
	var plain_ambient: Color = plain["ambient_color"]
	assert_gt(coast_sun.r / coast_sun.b, city_sun.r / city_sun.b, "K11 sunlight is warmer than K9")
	assert_gt(city_ambient.b / city_ambient.r, plain_ambient.b / plain_ambient.r, "K9 shade is cooler than K1")
	var city_grade: Dictionary = city["grade"]
	var pines_grade: Dictionary = pines["grade"]
	assert_lt(float(city_grade["saturation"]), float(pines_grade["saturation"]), "K9 is less saturated than K4")


func test_region_sunlight_differs_less_at_night_than_at_noon() -> void:
	var day_coast: Color = Atmosphere.look(12.0, ["clear"], "K11", 1.0)["sun_color"]
	var day_city: Color = Atmosphere.look(12.0, ["clear"], "K9", 1.0)["sun_color"]
	var night_coast: Color = Atmosphere.look(23.0, ["clear"], "K11", 1.0)["sun_color"]
	var night_city: Color = Atmosphere.look(23.0, ["clear"], "K9", 1.0)["sun_color"]
	assert_lt(_region_rgb_distance(night_coast, night_city), _region_rgb_distance(day_coast, day_city), "night keeps only 30 percent of the regional tint")


func test_region_look_normalises_names_and_returns_an_independent_copy() -> void:
	var expected: Dictionary = Atmosphere.region_look("K11")
	var alias: Dictionary = Atmosphere.region_look("region_11")
	assert_eq_deep(alias, expected)
	alias["light"] = Color(0.0, 0.0, 0.0)
	alias["shade"] = Color(0.0, 0.0, 0.0)
	alias["sat"] = 0.0
	alias["haze"] = 1.0
	assert_eq_deep(Atmosphere.region_look("K11"), expected)
	assert_eq_deep(Atmosphere.region_look("region_11"), expected)
