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


func test_no_rain_below_zero() -> void:
	var cold = Weather.new(["sleet"], -14.0)
	assert_eq(cold.kinds.size(), 0, "sleet is dropped at -14 C")
	assert_false(cold.wets_clothes())
	var thaw = Weather.new(["sleet"], -1.0)
	assert_true(thaw.wets_clothes())
	assert_true(thaw.ice_everywhere())


func test_unknown_kind_ignored_and_clear_label() -> void:
	var w = Weather.new(["rain", "monsoon"])
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
