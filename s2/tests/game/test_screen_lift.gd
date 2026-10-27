extends "res://addons/gut/test.gd"
## 설정의 밝기 한 칸(결정 471 B5): −20~+20 %, 5 % 걸음, 기본 0 = 지금 화면. 옮기면 바로 화면에
## 얹히고(field_game.set_screen_lift, 곡선은 mood) 판 사이에 남는다(user://screen.cfg, −0.2~0.2).
## 남긴 값은 플레이 흐름만 얹는다 — 도구처럼 만든 필드는 저장값과 상관없이 0이다.

const ScreenLift = preload("res://game/ui/screen_lift.gd")
const FieldGame = preload("res://game/field_game.gd")

const TEST_FILE: String = "user://screen_test.cfg"


## set_screen_lift와 screen_lift만 가진 가짜 판.
class LiftCatcher:
	extends RefCounted
	var screen_lift := 0.0
	var lifts: Array[float] = []

	func set_screen_lift(g: float) -> void:
		screen_lift = g
		lifts.append(g)


func before_each() -> void:
	DirAccess.remove_absolute(TEST_FILE)
	ScreenLift.where = TEST_FILE


func after_each() -> void:
	DirAccess.remove_absolute(TEST_FILE)
	ScreenLift.where = ScreenLift.FILE


func test_nothing_saved_is_the_screen_as_it_is_and_a_value_is_kept_in_steps() -> void:
	assert_eq(ScreenLift.load_lift(), 0)
	assert_eq(ScreenLift.save_lift(15), 15)
	assert_eq(ScreenLift.load_lift(), 15, "the next run comes back to it")
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(TEST_FILE), OK)
	assert_almost_eq(float(cfg.get_value("screen", "lift")), 0.15, 0.0001, "kept as the lift itself, -0.2..0.2")
	assert_eq(ScreenLift.save_lift(23), 20, "steps of 5, no more than +20")
	assert_eq(ScreenLift.save_lift(-7), -5)
	assert_eq(ScreenLift.save_lift(-40), -20, "no less than -20")
	assert_eq(ScreenLift.load_lift(), -20)


func test_the_row_lifts_the_screen_at_once_and_keeps_it() -> void:
	var game := LiftCatcher.new()
	var row := ScreenLift.make(game)
	add_child_autofree(row)
	var bar := row.get_node("Bar") as HSlider
	var value := row.get_node("Value") as Label
	assert_eq([bar.min_value, bar.max_value, bar.step], [-20.0, 20.0, 5.0])
	assert_eq(bar.value, 0.0)
	assert_eq(value.text, "기본")
	assert_gte(bar.custom_minimum_size.y, 44.0, "a finger's height")
	bar.value = 15
	assert_almost_eq(game.screen_lift, 0.15, 0.0001)
	assert_eq(value.text, "+15%")
	assert_eq(ScreenLift.load_lift(), 15, "kept")
	bar.value = -10
	assert_eq(value.text, "-10%")
	assert_almost_eq(game.screen_lift, -0.1, 0.0001)
	# The bar starts where the run's screen is, not where the file says.
	ScreenLift.save_lift(20)
	var again := ScreenLift.make(game)
	add_child_autofree(again)
	assert_eq((again.get_node("Bar") as HSlider).value, -10.0)


func test_a_run_without_the_curve_keeps_the_value_and_breaks_nothing() -> void:
	ScreenLift.apply(RefCounted.new(), 10)
	ScreenLift.apply(null, 10)
	ScreenLift.apply_saved(RefCounted.new())
	var row := ScreenLift.make(RefCounted.new())
	add_child_autofree(row)
	(row.get_node("Bar") as HSlider).value = 10
	assert_eq(ScreenLift.load_lift(), 10)


func test_a_field_made_like_a_tool_stays_at_zero_and_the_flow_lifts_it() -> void:
	ScreenLift.save_lift(20)
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	var curve: bool = game.has_method("set_screen_lift")
	if curve:
		assert_eq(float(game.get("screen_lift")), 0.0, "shots, brightness counts and bots see the screen as it is")
	game.hud.settings_panel()
	var row: Node = game.hud.find_child("ScreenLift", true, false)
	assert_not_null(row, "the pause screen's settings show the brightness row")
	ScreenLift.apply_saved(game)
	if curve:
		assert_almost_eq(float(game.get("screen_lift")), 0.2, 0.0001, "the play flow puts the saved brightness on")
