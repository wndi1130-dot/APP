extends "res://addons/gut/test.gd"
## Lanterns out and on (weather_fx 12.3 stage 2, user 2026-10-10): out, there is
## no light sound and the eye reaches less; everyone's go together.

const FieldGame = preload("res://game/field_game.gd")
const FieldClock = preload("res://game/sim/field_clock.gd")

var game


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()


func _night() -> void:
	game.clock.elapsed = (FieldClock.SUNSET_MIN - FieldClock.ARRIVE_MIN + 5) * 60.0 / FieldClock.GAME_PER_REAL
	assert_true(game.clock.is_dark())


func _light_sounds() -> int:
	return game.sounds.filter(func(s): return s["tag"] == "light").size()


func test_lanterns_out_make_no_light_sound() -> void:
	_night()
	game.light_t = 0.0
	game._update_night(0.1)
	assert_eq(_light_sounds(), game.squad.size(), "lit: each one is a sound a minute")
	game.sounds.clear()
	game.set_lamps(false)
	game.light_t = 0.0
	game._update_night(0.1)
	assert_eq(_light_sounds(), 0)
	game.set_lamps(true)
	game.light_t = 0.0
	game._update_night(0.1)
	assert_eq(_light_sounds(), game.squad.size())


func test_everyone_puts_theirs_out_together() -> void:
	_night()
	game.set_lamps(false)
	for p in game.squad + game.crew:
		assert_false(p.lamp_on)
		assert_false(p.lamp_lit(true, true), p.display_name)
	game.set_lamps(true)
	for p in game.squad + game.crew:
		assert_true(p.lamp_lit(true))


func test_out_at_night_the_eye_reaches_less_and_by_day_it_changes_nothing() -> void:
	var day: float = game.eye_mult()
	game.set_lamps(false)
	assert_almost_eq(game.eye_mult(), day, 0.0001, "by day a lantern does nothing")
	game.set_lamps(true)
	_night()
	var lit: float = game.eye_mult()
	assert_almost_eq(lit, minf(day, 0.55), 0.0001)
	game.set_lamps(false)
	assert_almost_eq(game.eye_mult(), minf(day, game.LAMP_OFF_SIGHT), 0.0001)
	assert_lt(game.eye_mult(), lit)
	game._refresh_vision()
	var dark_cells: int = game.seen_now.size()
	game.set_lamps(true)
	game._refresh_vision()
	assert_gt(game.seen_now.size(), dark_cells, "and the mask shows it")


func test_the_lantern_key_is_there_only_after_sunset_and_says_what_it_costs() -> void:
	var hud = game.hud
	hud.tick(0.02)
	assert_false(hud.lamp_button.visible, "by day there is no key")
	_night()
	hud.tick(0.02)
	hud.tick(0.02)
	assert_true(hud.lamp_button.visible)
	assert_true(hud.lamp_button.button_pressed, "lit to begin with")
	var texts: Array = hud.toasts.map(func(t): return String(t["l"].text))
	assert_eq(texts.filter(func(t): return t.contains("'등불'")).size(), 1, "one line, once")
	await wait_frames(2)
	var at: Vector2 = hud.lamp_button.get_global_rect().get_center()
	hud.finger_down(1, at)
	hud.finger_up(1, at)
	assert_false(game.lamps_on())
	assert_false(hud.lamp_button.button_pressed)
	assert_true(String(hud.toasts[-1]["l"].text).contains("껐다"))
	hud.finger_down(1, at)
	hud.finger_up(1, at)
	assert_true(game.lamps_on())


func test_the_lantern_key_is_clear_of_the_stick_and_its_neighbours() -> void:
	var hud = game.hud
	_night()
	hud.tick(0.02)
	await wait_frames(2)
	var rect: Rect2 = hud.lamp_button.get_global_rect()
	var home: Vector2 = hud.stick_home()
	var near := Vector2(clampf(home.x, rect.position.x, rect.end.x), clampf(home.y, rect.position.y, rect.end.y))
	assert_gt(near.distance_to(home), hud.STICK_R * hud.STICK_CATCH)
	assert_lt(rect.end.x, get_viewport().get_visible_rect().size.x * 0.5, "on the left half")
	for other in [hud.run_button, hud.crouch_button, hud.portrait, hud.blood_button, hud.pause_button, hud.allies_box, hud.context_button]:
		assert_false(rect.intersects(other.get_global_rect()), other.name)
