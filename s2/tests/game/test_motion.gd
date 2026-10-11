extends "res://addons/gut/test.gd"

const Motion = preload("res://game/sim/motion.gd")
const Combat = preload("res://game/field_combat.gd")
const W = preload("res://game/sim/weapons.gd")


func test_shove_row_is_todays_shove_rule() -> void:
	var row: Dictionary = Motion.row("shove")
	assert_almost_eq(float(row["hit"]), Combat.SHOVE_WINDUP, 0.0001)
	assert_almost_eq(float(row["len"]), Combat.SHOVE_WINDUP + Combat.SHOVE_TIME, 0.0001)
	assert_almost_eq(float(Motion.row("fall")["len"]), Combat.FALL_TIME, 0.0001)


func test_swing_row_follows_the_weapon_table() -> void:
	for wid in ["knife", "crowbar", "axe"]:
		var row: Dictionary = Motion.swing_row(wid)
		assert_almost_eq(float(row["len"]), float(W.get_data(wid)["swing"]), 0.0001, wid)
		assert_almost_eq(float(row["hit"]), float(W.get_data(wid)["windup"]), 0.0001, wid)
		assert_lt(float(row["hit"]), float(row["len"]) * 0.5, "%s: the way back is the longer half" % wid)
	assert_lt(float(Motion.swing_row("knife")["hit"]), float(Motion.swing_row("crowbar")["hit"]), "a heavier weapon winds up longer")
	assert_lt(float(Motion.swing_row("crowbar")["hit"]), float(Motion.swing_row("axe")["hit"]))
	assert_true(Motion.swing_row("pistol").is_empty())
	assert_true(Motion.swing_row("").is_empty())


func test_marks_fire_once_and_in_time_order() -> void:
	var m := Motion.new()
	assert_true(m.start_known("shove"))
	assert_eq(m.phase(), "windup")
	assert_eq(m.tick(0.0), ["feet_held"] as Array[String])
	assert_true(m.feet_held())
	assert_eq(m.tick(0.1), [] as Array[String])
	assert_false(m.can_cut())
	assert_eq(m.tick(0.06), ["sound", "hit", "feet_free"] as Array[String])
	assert_eq(m.phase(), "recover")
	assert_false(m.feet_held())
	assert_eq(m.tick(0.2), ["open"] as Array[String])
	assert_true(m.can_cut())
	assert_eq(m.tick(0.2), ["end"] as Array[String])
	assert_false(m.active())
	assert_eq(m.tick(0.2), [] as Array[String])


func test_one_long_step_returns_every_mark() -> void:
	var m := Motion.new()
	m.start_known("shove")
	assert_eq(m.tick(5.0), ["feet_held", "sound", "hit", "feet_free", "open", "end"] as Array[String])
	assert_false(m.active())


func test_speed_stretches_every_time() -> void:
	var m := Motion.new()
	m.start_known("shove", 0.5)
	assert_almost_eq(m.time_left(), 1.0, 0.0001)
	assert_false(m.tick(0.2).has("hit"))
	assert_true(m.tick(0.11).has("hit"))
	assert_almost_eq(m.k(), 0.31, 0.0001)


func test_cut_only_where_the_row_opens() -> void:
	var m := Motion.new()
	m.start_known("shove")
	m.tick(0.2)
	assert_false(m.cut())
	assert_true(m.active())
	m.tick(0.15)
	assert_true(m.cut())
	assert_false(m.active())
	m.start_known("fall")
	m.tick(1.4)
	assert_false(m.cut())
	m.stop()
	assert_false(m.active())


func test_loop_starts_over_and_fires_again() -> void:
	var m := Motion.new()
	m.start("search", {"len": 1.0, "hit": -1.0, "feet": Vector2(0.0, 1.0), "open": 0.0, "sound": 0.5, "upper": false, "loop": true})
	assert_eq(m.tick(0.6), ["feet_held", "open", "sound"] as Array[String])
	assert_eq(m.tick(0.5), ["feet_free", "end"] as Array[String])
	assert_true(m.active())
	assert_almost_eq(m.k(), 0.1, 0.0001)
	assert_true(m.tick(0.5).has("sound"))


func test_windup_and_way_back_run_zero_to_one() -> void:
	var m := Motion.new()
	m.start("swing", Motion.swing_row("axe"))
	assert_eq(m.windup_k(), 0.0)
	m.tick(0.15)
	assert_almost_eq(m.windup_k(), 0.5, 0.0001)
	assert_eq(m.recover_k(), 0.0)
	assert_true(m.tick(0.15).has("hit"))
	assert_eq(m.windup_k(), 1.0)
	m.tick(0.3)
	assert_almost_eq(m.recover_k(), 0.5, 0.0001)


func test_unknown_motion_does_not_start() -> void:
	var m := Motion.new()
	assert_false(m.start_known("no_such_motion"))
	assert_false(m.active())
	assert_eq(m.k(), 0.0)
	assert_true(m.can_cut())
