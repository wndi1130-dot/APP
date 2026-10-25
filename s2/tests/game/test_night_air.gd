extends GutTest
## The field's air at dusk and night (2026-10-25 user answer): the rules' air
## follows the pictures' curve (a clear night 5 C under midday, otherwise 2.5 C),
## held to the season table's night frost at zero (no frost: +0.5 C or above,
## frost: -1 C or below). What falls stays the midday air's.

const SeasonTable = preload("res://game/season_table.gd")
const OutsideTemp = preload("res://game/sim/outside_temp.gd")
const BodyHeat = preload("res://game/sim/body_heat.gd")
const FieldGame = preload("res://game/field_game.gd")


func test_the_night_air_curve_and_its_bounds() -> void:
	assert_almost_eq(SeasonTable.night_air(5.0, 0.0, true, 0), 5.0, 0.000001, "by day the air is midday's")
	assert_almost_eq(SeasonTable.night_air(5.0, 1.0, false, 0), 2.5, 0.000001, "a cloudy night is 2.5 C colder")
	assert_almost_eq(SeasonTable.night_air(4.0, 0.5, true, -1), 1.5, 0.000001, "half dark, half the drop")
	assert_almost_eq(SeasonTable.night_air(2.0, 1.0, true, 0), 0.5, 0.000001, "no night frost: held at +0.5 C")
	assert_almost_eq(SeasonTable.night_air(2.0, 1.0, false, 1), -1.0, 0.000001, "night frost: -1 C or below")
	assert_almost_eq(SeasonTable.night_air(0.0, 1.0, true, 1), -5.0, 0.000001, "frost already under: the curve")
	assert_almost_eq(SeasonTable.night_air(2.0, 1.0, true, -1), -3.0, 0.000001, "not known: the plain curve")


func test_every_first_leg_night_keeps_to_its_night_frost() -> void:
	for seg in range(1, SeasonTable.segments() + 1):
		var r: Dictionary = SeasonTable.row(seg)
		var frost := 1 if bool(r["night_freeze"]) else 0
		for clear in [true, false]:
			var night := SeasonTable.night_air(float(r["temp"]), 1.0, clear, frost)
			if frost == 1:
				assert_lte(night, -1.0, "stretch %d freezes at night" % seg)
			else:
				assert_gte(night, minf(float(r["temp"]), 0.5), "stretch %d stays above zero" % seg)


func _field(seg: int, kinds: Array) -> Node:
	var field = FieldGame.new()
	field.opts = {"seed": 3, "raiders": false, "auto_pause": false, "act": "prologue", "act_progress": SeasonTable.seg_progress(seg), "weather": kinds, "look": kinds}
	add_child_autofree(field)
	field.set_process(false)
	return field


func test_the_field_air_goes_down_after_dark_and_what_falls_stays() -> void:
	# Stretch 17: 0 C at midday, the first night frosts; sleet falls.
	var field = _field(17, ["sleet"])
	assert_eq(OutsideTemp.frost_of(field.opts), 1)
	assert_almost_eq(field.weather.ambient_c, 0.0, 0.001, "on arrival (10:30) the air is midday's")
	var kinds: Array = field.weather.kinds.duplicate()
	var falls := String(field.atmo["falls"])
	field.clock.elapsed = 1800.0
	field._update_atmosphere()
	assert_almost_eq(field.weather.ambient_c, -2.5, 0.001, "18:00, full night under cloud")
	assert_almost_eq(field.weather.ambient_c, float(field.atmo["temp_c"]), 0.001, "the picture's air is the rules' air")
	assert_almost_eq(field.weather.midday_c, 0.0, 0.001)
	assert_eq(field.weather.kinds, kinds, "what falls stays the midday air's")
	assert_eq(String(field.atmo["falls"]), falls, "and the picture's too")
	assert_almost_eq(field.weather.scent_mult(Vector3.ZERO, Vector3(5, 0, 0)), 0.6 * 1.5, 0.001, "below zero the blood smell is cut")


func test_a_late_autumn_night_stays_above_zero() -> void:
	# Stretch 13: +2 C at midday, no night frost; a clear night would be -3 C.
	var field = _field(13, ["clear"])
	assert_eq(OutsideTemp.frost_of(field.opts), 0)
	field.clock.elapsed = 1800.0
	field._update_atmosphere()
	assert_almost_eq(field.weather.ambient_c, 0.5, 0.001)


func test_the_body_cools_faster_at_night() -> void:
	var day := BodyHeat.loss_rate({"ambient_c": 0.0}, 0.0)
	var night := BodyHeat.loss_rate({"ambient_c": -2.5}, 0.0)
	assert_gt(night, day)
	assert_almost_eq(night / day, 12.5 / 10.0, 0.0001, "the loss goes by 10 C minus the air")


func test_an_air_given_outright_has_no_bounds() -> void:
	assert_eq(OutsideTemp.frost_of({"ambient_c": 3.0}), -1)
	assert_eq(OutsideTemp.frost_of({"cold": 0.5}), -1)
	assert_eq(OutsideTemp.frost_of({"act": "act2", "act_progress": 0.5}), 1)
