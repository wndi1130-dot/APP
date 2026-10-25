extends "res://addons/gut/test.gd"

const Weather = preload("res://game/sim/weather.gd")


func test_sulechow_default_fog_and_snow() -> void:
	var w = Weather.new()
	assert_eq(w.kinds, ["fog", "snow"] as Array[String])
	assert_almost_eq(w.sight_mult(), 0.72, 0.0001, "light fog with fine snow has its own value (about 13 m)")
	assert_almost_eq(w.sight_mult(true), 0.55, 0.0001, "a foggy night is the night value")
	var heavy = Weather.new(["fog"])
	assert_almost_eq(heavy.sight_mult(), 0.6, 0.0001, "heavy fog alone is shorter than the default")
	var stack = Weather.new(["fog", "sleet"], 0.0)
	assert_almost_eq(stack.sight_mult(), 0.6, 0.0001, "unnamed pairs take the shorter")
	assert_almost_eq(w.sound_mult(), 1.0, 0.0001, "fog and snow leave gunshots alone")
	assert_almost_eq(w.sound_mult(true), 0.75, 0.0001, "snow muffles footsteps")
	assert_false(w.always_cold())
	assert_eq(w.label(), "안개 · 눈 내림")


func test_blizzard_matches_gunshot_value() -> void:
	var w = Weather.new(["blizzard"])
	assert_almost_eq(w.sound_mult(), 0.75, 0.0001)
	assert_true(w.always_cold())
	assert_lt(w.sight_mult(), 0.5)


## What falls is the air's (결정 423; the season table's falls, 코디네이터 10-25):
## sleet given at -14 C falls as snow (it used to be dropped), no rain below
## rain_above, no sleet at or below snow_below.
func test_no_rain_below_zero() -> void:
	var cold = Weather.new(["sleet"], -14.0)
	assert_eq(cold.kinds, ["snow"] as Array[String], "sleet falls as snow at -14 C")
	assert_false(cold.wets_clothes())
	var thaw = Weather.new(["sleet"], -1.0)
	assert_true(thaw.wets_clothes())
	assert_true(thaw.ice_everywhere())
	assert_eq(Weather.new(["rain"], -1.0).kinds, ["sleet"] as Array[String], "no rain at -1 C")
	assert_eq(Weather.new(["snow"], 4.0).kinds, ["rain"] as Array[String], "snow falls as rain at +4 C")
	assert_eq(Weather.new(["fog", "snow"], -3.0).kinds, ["fog", "snow"] as Array[String], "the first stretch's -3 C keeps the snow")
	assert_eq(Weather.new(["snow", "sleet"], 6.0).kinds, ["rain"] as Array[String], "two falling kinds are one")


func test_rain_hides_and_covers_a_little_and_wets_without_ice() -> void:
	var w = Weather.new(["rain"], 5.0)
	assert_eq(w.kinds, ["rain"] as Array[String])
	assert_almost_eq(w.sight_mult(), 0.85, 0.0001)
	assert_almost_eq(w.sound_mult(), 0.9, 0.0001, "the rain's noise covers sounds a little")
	assert_almost_eq(w.sound_mult(true), 0.9, 0.0001, "footsteps are not muffled")
	assert_true(w.wets_clothes())
	assert_false(w.ice_everywhere(), "wet, not icy underfoot")
	assert_false(w.always_cold())
	assert_gt(w.particles(), 0, "the field draws what falls by this count")
	assert_eq(w.label(), "비")


func test_unknown_kind_ignored_and_clear_label() -> void:
	var w = Weather.new(["monsoon"])
	assert_eq(w.kinds.size(), 0)
	assert_eq(w.label(), "맑음")
	assert_almost_eq(w.sight_mult(), 1.0, 0.0001)
	var c = Weather.new(["clear"])
	assert_gt(c.sight_mult(), 1.0, "clear days are seen from far")


func test_downwind_stretch() -> void:
	var w = Weather.new(["snow"], -14.0, Vector2(1, 0), 1.0)
	var at := Vector3(10, 0, 10)
	assert_almost_eq(w.downwind(at, at + Vector3(5, 0, 0)), 2.0, 0.0001, "straight downwind doubles")
	assert_almost_eq(w.downwind(at, at + Vector3(-5, 0, 0)), 1.0, 0.0001, "upwind is unchanged")
	assert_almost_eq(w.downwind(at, at + Vector3(0, 0, 5)), 1.0, 0.0001, "sideways is unchanged")
	assert_almost_eq(w.downwind(at, at), 1.0, 0.0001)
	var calm = Weather.new(["snow"], -14.0, Vector2(0, 0), 0.0)
	assert_almost_eq(calm.downwind(at, at + Vector3(5, 0, 0)), 1.0, 0.0001)


func test_particles() -> void:
	assert_eq(Weather.new(["fog"]).particles(), 0)
	assert_eq(Weather.new(["fog", "snow"]).particles(), 300)
	assert_eq(Weather.new(["blizzard", "snow"]).particles(), 900)


func test_scent_wind_and_cold() -> void:
	var w = Weather.new(["snow"], -14.0, Vector2(1, 0), 0.4)
	var at := Vector3(10, 0, 10)
	assert_almost_eq(w.scent_mult(at, at + Vector3(5, 0, 0)), 0.6 * 1.5, 0.0001, "downwind")
	assert_almost_eq(w.scent_mult(at, at + Vector3(-5, 0, 0)), 0.6 * 0.6, 0.0001, "upwind")
	assert_almost_eq(w.scent_mult(at, at + Vector3(0, 0, 5)), 0.6 * 0.9, 0.0001, "sideways")
	var thaw = Weather.new(["sleet"], 1.0, Vector2(1, 0), 0.0)
	assert_almost_eq(thaw.scent_mult(at, at + Vector3(5, 0, 0)), 1.0, 0.0001, "no wind, above zero")


func test_sight_falls_evenly_from_1450_to_sunset() -> void:
	var FieldClock = load("res://game/sim/field_clock.gd")
	var clock = FieldClock.new()
	var plain = Weather.new(["sleet"], 0.0)
	plain.kinds = [] as Array[String]
	var foggy = Weather.new()
	var clear = Weather.new(["clear"])
	# Game minute -> the share of a plain day's sight that is left.
	var rows := {880: 1.0, 890: 1.0, 901: 0.91, 912: 0.82, 923: 0.73, 934: 0.64, 945: 0.55}
	for minute: int in rows:
		clock.elapsed = (minute - FieldClock.ARRIVE_MIN) * 60.0 / FieldClock.GAME_PER_REAL
		for w in [plain, foggy, clear]:
			w.dusk = clock.dusk_share()
		assert_almost_eq(plain.sight_mult(clock.is_dark()), float(rows[minute]), 0.0001, str(minute))
		var gone: float = clampf((minute - 890) / 55.0, 0.0, 1.0)
		assert_almost_eq(foggy.sight_mult(clock.is_dark()), 0.72 - 0.17 * gone, 0.0001, "from the weather's own, evenly")
	clock.elapsed = (917.5 - FieldClock.ARRIVE_MIN) * 60.0 / FieldClock.GAME_PER_REAL
	clear.dusk = clock.dusk_share()
	assert_almost_eq(clear.sight_mult(), 0.9, 0.0001, "a clear day falls from its own 1.25, with no step at 14:50")
	var storm = Weather.new(["blizzard"])
	storm.dusk = 0.5
	assert_almost_eq(storm.sight_mult(), 0.4, 0.0001, "what sees no farther than the night is left as it is")
	assert_almost_eq(storm.sight_mult(true), 0.4, 0.0001)
	plain.dusk = 0.3
	assert_almost_eq(plain.sight_mult(true), 0.55, 0.0001, "after sunset it is the night value")
