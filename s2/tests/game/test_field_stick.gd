extends "res://addons/gut/test.gd"
## Phone controls (user 17:15 and 17:32, field_unified 10): left-thumb stick
## with a little body weight, aim pad with auto aim, small manual switch,
## attack pad, and two fingers at once.

const FieldGame = preload("res://game/field_game.gd")
const Person = preload("res://game/actors/person.gd")

var game


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	# Open platform, nobody in the way.
	game.player.position = game.lift(Vector2i(60, 7), 0)
	for q in game.squad:
		if q != game.player:
			q.position = game.lift(Vector2i(30, 7), 0)


func _step(p, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		game._update_person(p, 0.02)
		t += 0.02


func _gun() -> void:
	game.player.hands = [{"id": "pistol", "quality": "factory", "condition": 1.0, "loaded": 8}]


func _tried() -> bool:
	return int(game.player.weapon()["loaded"]) < 8 or game.player.jam_t > 0.0


func test_stick_gets_going_over_a_fifth_of_a_second() -> void:
	var p = game.player
	p.stick = Vector2(1, 0)
	_step(p, 0.06)
	assert_lt(p.drive_speed, Person.WALK * 0.6, "not at full walk at once")
	_step(p, 0.2)
	assert_almost_eq(p.drive_speed, p.speed(game.grid.floor_at(game.FieldGrid.cell_of(p.position))), 0.05)


func test_letting_go_stops_in_a_quarter_second_a_run_takes_longer() -> void:
	var p = game.player
	p.stick = Vector2(1, 0)
	_step(p, 0.5)
	p.stick = Vector2.ZERO
	_step(p, 0.3)
	assert_eq(p.drive_speed, 0.0, "a walk stops within 0.3 s")
	p.running = true
	p.stick = Vector2(1, 0)
	_step(p, 0.5)
	p.stick = Vector2.ZERO
	_step(p, 0.3)
	assert_gt(p.drive_speed, 0.0, "a run is still sliding at 0.3 s")
	_step(p, 0.2)
	assert_eq(p.drive_speed, 0.0)


func test_direction_follows_the_thumb_at_once() -> void:
	var p = game.player
	p.stick = Vector2(1, 0)
	_step(p, 0.4)
	p.stick = Vector2(0, 1)
	_step(p, 0.02)
	assert_almost_eq(p.drive_dir.z, 1.0, 0.01)


func test_a_heavy_bag_gets_going_slower() -> void:
	var p = game.player
	p.stick = Vector2(1, 0)
	_step(p, 0.1)
	var light: float = p.drive_speed / maxf(p.speed(0), 0.01)
	p.stick = Vector2.ZERO
	_step(p, 1.0)
	p.add_item("food_pack", 30)
	if p.speed(0) <= 0.0:
		p.items["food_pack"] = 10
	p.stick = Vector2(1, 0)
	_step(p, 0.1)
	var heavy: float = p.drive_speed / maxf(p.speed(0), 0.01)
	assert_lt(heavy, light)


func test_pushing_the_stick_walks_away_from_a_search() -> void:
	var p = game.player
	p.start_action("search", "뒤지기", 5.0, func() -> void: pass)
	p.stick = Vector2(1, 0)
	_step(p, 0.1)
	assert_eq(p.action, "")
	assert_gt(p.drive_speed, 0.0)


func test_stick_rim_runs() -> void:
	var hud = game.hud
	var p = game.player
	hud.stick_origin = Vector2(200, 400)
	hud.stick_at = Vector2(200 + hud.STICK_R, 400)
	hud._apply_stick()
	assert_true(p.running)
	hud.stick_at = Vector2(200 + hud.STICK_R * 0.4, 400)
	hud._apply_stick()
	assert_false(p.running)
	assert_almost_eq(p.stick.x, 0.4, 0.02)


func test_left_thumb_on_stick_right_thumb_on_aim_pad() -> void:
	_gun()
	var hud = game.hud
	var size: Vector2 = hud._view_size()
	assert_true(hud.finger_down(0, Vector2(size.x * 0.2, size.y * 0.6)), "left half takes the stick")
	hud.finger_move(0, Vector2(size.x * 0.2 + 40, size.y * 0.6))
	assert_gt(game.player.stick.x, 0.0)
	var pad: Vector2 = hud.aim_button.get_global_rect().get_center()
	assert_true(hud.finger_down(1, pad), "second finger on the aim pad")
	assert_true(hud.auto_aim)
	assert_true(game.player.aim.active)
	hud.finger_up(1, pad)
	hud.finger_up(0, Vector2(size.x * 0.2 + 40, size.y * 0.6))
	assert_eq(game.player.stick, Vector2.ZERO)


func test_auto_aim_settles_on_the_one_ahead_and_fires_on_release() -> void:
	_gun()
	var p = game.player
	p.facing = PI * 0.5   # east
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(7, 0, 0))
	game.zombies.spawn("dead", p.position + Vector3(-5, 0, 0))   # nearer, but behind
	game._refresh_vision()
	var hud = game.hud
	hud._auto_aim_start()
	hud._tick_auto_aim(0.05)
	assert_null(hud.aim_target, "not at once")
	hud._tick_auto_aim(1.0)
	assert_eq(hud.aim_target, z)
	hud._auto_aim_end(hud._project(p.position + Vector3(0, 1, 0)) + Vector2(300, 0))
	assert_true(_tried())


func test_skill_settles_the_aim_sooner() -> void:
	var p = game.player
	p.skills["shooting"] = 1
	var slow: float = game.combat.acquire_time(p)
	p.skills["shooting"] = 9
	assert_lt(game.combat.acquire_time(p), slow)


func test_sharp_shooters_take_the_one_coming_first() -> void:
	_gun()
	var p = game.player
	p.facing = PI * 0.5
	var near: Dictionary = game.zombies.spawn("dead", p.position + Vector3(4, 0, 0))
	var coming: Dictionary = game.zombies.spawn("dead", p.position + Vector3(7, 0, 0))
	coming["state"] = "chase"
	game._refresh_vision()
	p.skills["shooting"] = 2
	assert_eq(game.combat.aim_candidates(p)[0], near)
	p.skills["shooting"] = 8
	assert_eq(game.combat.aim_candidates(p)[0], coming)


func test_auto_aim_let_go_on_yourself_lowers_the_gun() -> void:
	_gun()
	var p = game.player
	p.facing = PI * 0.5
	game.zombies.spawn("dead", p.position + Vector3(7, 0, 0))
	game._refresh_vision()
	var hud = game.hud
	hud._auto_aim_start()
	hud._tick_auto_aim(1.0)
	var me: Vector2 = hud._project(p.position + Vector3(0, 1, 0))
	hud._pad_move(hud.aim_button, me, {"start": me + Vector2(0, 200)})
	hud._auto_aim_end(me)
	assert_false(_tried())
	assert_false(p.aim.active)


func test_manual_mode_aims_anywhere_with_the_right_thumb() -> void:
	_gun()
	var hud = game.hud
	hud.manual_button.button_pressed = true
	var me: Vector2 = hud._project(game.player.position + Vector3(0, 1, 0))
	hud._press(me + Vector2(250, -80))
	assert_true(hud.aiming, "no enemy needed under the thumb")
	hud._release(me + Vector2(250, -80))
	assert_true(_tried())


func test_attack_pad_swings_at_what_is_in_reach() -> void:
	var p = game.player
	p.hands = [{"id": "axe", "quality": "factory", "condition": 0.9, "loaded": 0}]
	p.facing = PI * 0.5
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(1.0, 0, 0))
	game._refresh_vision()
	assert_eq(game.combat.melee_pick(p), z)
	game.hud._pad_down(game.hud.attack_button, Vector2.ZERO)
	assert_eq(p.target_zombie, z)
