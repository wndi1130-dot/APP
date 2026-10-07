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
	game.opts["inertia"] = "now"
	var p = game.player
	p.stick = Vector2(1, 0)
	_step(p, 0.06)
	assert_lt(p.drive_speed, Person.WALK * 0.6, "not at full walk at once")
	_step(p, 0.2)
	assert_almost_eq(p.drive_speed, p.speed(game.grid.floor_at(game.FieldGrid.cell_of(p.position))), 0.05)


func test_letting_go_stops_in_a_quarter_second_a_run_takes_longer() -> void:
	game.opts["inertia"] = "now"
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


func test_stick_rim_walks_unless_set_to_run() -> void:
	var hud = game.hud
	var p = game.player
	hud.stick_origin = Vector2(200, 400)
	hud.stick_at = Vector2(200 + hud.STICK_R, 400)
	hud._apply_stick()
	hud._update_rim(0.5)
	assert_false(p.running, "off by default (coordinator 18:10)")
	game.opts["stick_rim_run"] = true
	hud._apply_stick()
	assert_false(p.running, "a moment at the rim first")
	hud.stick_index = 0
	hud._update_rim(0.2)
	hud._apply_stick()
	assert_true(p.running)
	hud.stick_at = Vector2(200 + hud.STICK_R * 0.8, 400)
	hud._apply_stick()
	assert_true(p.running, "a shaking thumb between 75% and 90% keeps running")
	hud.stick_at = Vector2(200 + hud.STICK_R * 0.4, 400)
	hud._apply_stick()
	assert_false(p.running)
	assert_almost_eq(p.stick.x, 0.4, 0.02)


func test_setting_the_stick_down_by_the_toggles_starts_nothing() -> void:
	var hud = game.hud
	var r: Rect2 = hud.run_button.get_global_rect()
	var edge := Vector2(r.position.x - 20, r.get_center().y)
	assert_true(hud.finger_down(0, edge))
	assert_eq(hud.stick_index, -1, "no stick on the toggle's edge")
	assert_false(hud.run_button.button_pressed)
	hud.finger_up(0, edge)
	hud.finger_down(0, r.get_center())
	assert_true(hud.run_button.button_pressed, "the key itself still toggles")


func test_double_tap_run_only_when_set() -> void:
	var hud = game.hud
	var size: Vector2 = hud._view_size()
	var at := Vector2(size.x * 0.3, size.y - 100)
	hud.finger_down(0, at)
	hud.finger_up(0, at)
	hud.finger_down(0, at)
	hud.finger_move(0, at + Vector2(50, 0))
	assert_false(game.player.running, "off by default")
	hud.finger_up(0, at + Vector2(50, 0))
	game.opts["double_tap_run"] = true
	hud.finger_down(0, at)
	hud.finger_up(0, at)
	hud.finger_down(0, at)
	hud.finger_move(0, at + Vector2(50, 0))
	assert_true(game.player.running)
	hud.finger_up(0, at + Vector2(50, 0))
	assert_false(game.player.running, "the dash ends with the hold")


func test_run_crouch_and_pause_on_the_left_four_on_the_right() -> void:
	var hud = game.hud
	var half: float = hud._view_size().x * 0.5
	assert_lt(hud.run_button.get_global_rect().end.x, half)
	assert_lt(hud.crouch_button.get_global_rect().end.x, half)
	hud.context_button.visible = true
	var right: Array = []
	for b in hud.pads:
		if b.get_global_rect().position.x > half and b != hud.manual_button:
			right.append(b)
	assert_eq(right.size(), 4, "aim, attack, shove, situation")
	var top_left: Rect2 = hud.pause_button.get_global_rect()
	assert_lt(top_left.position.x, 40.0, "pause at the left end of the gauge row")
	assert_lt(top_left.position.y, 40.0)
	for i in range(hud.pads.size()):
		for j in range(i + 1, hud.pads.size()):
			assert_false(hud.pads[i].get_global_rect().intersects(hud.pads[j].get_global_rect()), "pads do not overlap")


func test_situation_pad_shows_only_with_something_to_do() -> void:
	var hud = game.hud
	var p = game.player
	p.position = game.lift(Vector2i(165, 95), 0)   # an empty snow corner
	hud._rebuild_context(p)
	assert_eq(hud.context_rows, [])
	assert_false(hud.context_button.visible)
	p.body.bleed = 1
	p.add_item("bandage", 1)
	hud._rebuild_context(p)
	assert_true(hud.context_button.visible)


func _run_then_stop_time(feel: String) -> float:
	var p = game.player
	game.opts["inertia"] = feel
	p.drive_speed = 0.0
	p.running = true
	p.stick = Vector2(1, 0)
	_step(p, 0.6)
	p.stick = Vector2.ZERO
	var t := 0.0
	while p.drive_speed > 0.0 and t < 2.0:
		_step(p, 0.02)
		t += 0.02
	return t


func test_shorter_inertia_stops_sooner() -> void:
	var now := _run_then_stop_time("now")
	var mid := _run_then_stop_time("mid")
	var short := _run_then_stop_time("short")
	assert_lt(mid, now)
	assert_lt(short, mid)
	assert_almost_eq(short / now, 0.5, 0.1, "0.20 against 0.4")


func test_left_thumb_on_stick_right_thumb_on_aim_pad() -> void:
	_gun()
	var hud = game.hud
	var size: Vector2 = hud._view_size()
	var at := Vector2(size.x * 0.3, size.y - 100)
	assert_true(hud.finger_down(0, at), "left half takes the stick")
	assert_eq(hud.stick_index, 0)
	hud.finger_move(0, at + Vector2(40, 0))
	assert_gt(game.player.stick.x, 0.0)
	var pad: Vector2 = hud.aim_button.get_global_rect().get_center()
	assert_true(hud.finger_down(1, pad), "second finger on the aim pad")
	assert_true(hud.auto_aim)
	assert_true(game.player.aim.active)
	hud.finger_up(1, pad)
	hud.finger_up(0, at + Vector2(40, 0))
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


func test_sharp_shooters_see_the_danger_marked_but_aim_stays_nearest() -> void:
	_gun()
	var p = game.player
	p.facing = PI * 0.5
	var near: Dictionary = game.zombies.spawn("dead", p.position + Vector3(4, 0, 0))
	var coming: Dictionary = game.zombies.spawn("dead", p.position + Vector3(7, 0, 0))
	coming["state"] = "chase"
	game._refresh_vision()
	p.skills["shooting"] = 8
	assert_eq(game.combat.aim_candidates(p)[0], near, "the game does not swap it for you")
	assert_true(game.combat.marks_danger(p, coming))
	assert_false(game.combat.marks_danger(p, near))
	p.skills["shooting"] = 6
	assert_false(game.combat.marks_danger(p, coming), "marks from 7 up")


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


func _axe_and_one_ahead() -> Dictionary:
	var p = game.player
	p.hands = [{"id": "axe", "quality": "factory", "condition": 0.9, "loaded": 0}]
	p.facing = PI * 0.5
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(1.0, 0, 0))
	game._refresh_vision()
	return z


func test_one_press_fights_on_and_a_second_press_stops() -> void:
	var p = game.player
	var z := _axe_and_one_ahead()
	var hud = game.hud
	hud._pad_down(hud.attack_button, Vector2.ZERO)
	hud._pad_up(hud.attack_button, Vector2.ZERO)
	assert_eq(p.target_zombie, z, "letting go of the pad does not stop it")
	assert_true(p.hold_attack)
	hud.tick(0.02)
	assert_true(hud.attack_button.button_pressed, "lit while the fight goes on")
	hud._pad_down(hud.attack_button, Vector2.ZERO)
	assert_true(p.target_zombie.is_empty())
	assert_false(p.hold_attack)


func test_a_resting_thumb_keeps_the_fight_a_push_away_stops_it() -> void:
	var p = game.player
	var z := _axe_and_one_ahead()
	var hud = game.hud
	hud._pad_down(hud.attack_button, Vector2.ZERO)
	hud.stick_origin = Vector2(200, 400)
	hud.stick_at = Vector2(200 + hud.STICK_R * 0.2, 400)
	hud._apply_stick()
	assert_eq(p.target_zombie, z, "a light touch")
	hud.stick_at = Vector2(200 + hud.STICK_R * 0.8, 400)
	hud._apply_stick()
	assert_eq(p.target_zombie, z, "pushing at it keeps hitting it")
	assert_eq(p.stick, Vector2.ZERO)
	hud.stick_at = Vector2(200 - hud.STICK_R * 0.8, 400)
	hud._apply_stick()
	assert_true(p.target_zombie.is_empty(), "pushing away calls it off")
	assert_false(p.hold_attack)
	assert_lt(p.stick.x, 0.0)


func test_one_target_only_when_chaining_is_off() -> void:
	var p = game.player
	var a := _axe_and_one_ahead()
	var b: Dictionary = game.zombies.spawn("dead", p.position + Vector3(-1.2, 0, 0))
	b["state"] = "chase"
	game._refresh_vision()
	game.opts["melee_chain"] = false
	game.hud._pad_down(game.hud.attack_button, Vector2.ZERO)
	a["state"] = "dead"
	game.combat._pursue_zombie(p, 0.1)
	assert_true(p.target_zombie.is_empty())
	assert_false(p.hold_attack)


func test_nothing_in_reach_is_said_not_swung_at() -> void:
	var p = game.player
	p.hands = [{"id": "axe", "quality": "factory", "condition": 0.9, "loaded": 0}]
	game.hud._pad_down(game.hud.attack_button, Vector2.ZERO)
	assert_false(p.hold_attack)
	assert_false(game.hud.attack_button.button_pressed)


func test_situation_pad_does_the_nearest_thing_and_a_hold_lists_the_rest() -> void:
	var hud = game.hud
	var p = game.player
	p.body.bleed = 1
	p.add_item("bandage", 1)
	p.add_item("cloth", 1)
	hud._rebuild_context(p)
	assert_gt(hud.context_rows.size(), 1)
	assert_true(hud.context_button.text.begins_with(String(hud.context_rows[0]["label"])))
	var at: Vector2 = hud.context_button.get_global_rect().get_center()
	hud.finger_down(1, at)
	hud.fingers[1]["ms"] = Time.get_ticks_msec() - 1000
	hud.tick(0.02)
	assert_eq(hud.offer_box.get_child_count(), hud.context_rows.size() + 1, "each choice and 'stop'")
	hud.finger_up(1, at)
	assert_eq(p.action, "", "a hold that opened the list does nothing else")
	hud.finger_down(1, at)
	hud.finger_up(1, at)
	assert_ne(p.action, "", "a tap does the first one")


func test_pause_pad_pauses() -> void:
	var hud = game.hud
	var was: bool = game.paused
	var at: Vector2 = hud.pause_button.get_global_rect().get_center()
	hud.finger_down(1, at)
	hud.finger_up(1, at)
	assert_ne(game.paused, was)


func test_departure_logs_the_dead_on_the_track() -> void:
	game.zombies.spawn("dead", game.lift(Vector2i(5, 2), 0))
	game.zombies.spawn("dead", game.lift(Vector2i(120, 1), 0))
	game.zombies.spawn("dead", game.lift(Vector2i(130, 3), 0))
	game.zombies.spawn("dead", game.lift(Vector2i(50, 6), 0))   # on the platform, not the track
	var gone: Dictionary = game.zombies.spawn("dead", game.lift(Vector2i(140, 2), 0))
	gone["state"] = "dead"
	assert_eq(game.track_dead(), {"west": 1, "east": 2})
	var got: Array = []
	game.finished.connect(func(r): got.append(r))
	game.finish("departed")
	assert_eq(JSON.parse_string(got[0]["telemetry"])["trackDead"], {"west": 1.0, "east": 2.0})


func test_one_main_action_trial_turns_aim_into_attack_with_an_axe() -> void:
	var p = game.player
	var z := _axe_and_one_ahead()
	var hud = game.hud
	game.opts["primary_one"] = true
	hud.tick(0.02)
	assert_false(hud.attack_button.visible)
	assert_false(hud.manual_button.visible, "manual only with a gun")
	assert_eq(hud.aim_button.text, "공격")
	hud._pad_down(hud.aim_button, Vector2.ZERO)
	hud._pad_up(hud.aim_button, Vector2.ZERO)
	assert_eq(p.target_zombie, z)
	assert_true(p.hold_attack)
	_gun()
	hud.tick(0.02)
	assert_eq(hud.aim_button.text, "조준")
	assert_true(hud.manual_button.visible)


func test_blood_drop_binds_the_worst_bleed() -> void:
	var p = game.player
	var hud = game.hud
	hud.tick(0.02)
	assert_false(hud.blood_button.visible)
	p.body.bleed = 2
	p.add_item("bandage", 1)
	hud.tick(0.02)
	assert_true(hud.blood_button.visible)
	var at: Vector2 = hud.blood_button.get_global_rect().get_center()
	hud.finger_down(1, at)
	hud.finger_up(1, at)
	assert_ne(p.action, "", "binding starts")


func test_pistol_rounds_go_through_a_thick_coat() -> void:
	_gun()
	var p = game.player
	var d: Dictionary = game.combat.W.get_data("pistol")
	var stopped := 0
	var landed := 0
	for i in range(200):
		var z: Dictionary = game.zombies.spawn("clothed", p.position + Vector3(5, 0, 0))
		if game.combat._shoot_zombie(p, z, d, 0.6, 5.0):
			landed += 1
			if z["state"] != "downed" and z["state"] != "dead" and absf(float(z.get("stun", 0.0)) - 0.3) < 0.001:
				stopped += 1
	assert_gt(landed, 0)
	assert_eq(stopped, 0, "coats stop blades and bites only (user 17:34)")


func test_depart_note_says_the_horde_is_close_and_holds_time() -> void:
	var hud = game.hud
	hud.depart_card()
	assert_true(game.paused, "the note stops field time")
	assert_false(game.ended, "no whistle before '출발한다'")
	hud._close_modal()
	assert_false(hud.horde_close())
	var z: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(25, 0, 0))
	z["horde"] = 0
	assert_true(hud.horde_close())
