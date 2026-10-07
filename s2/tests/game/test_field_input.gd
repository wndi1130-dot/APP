extends "res://addons/gut/test.gd"
## Touch rules on the field HUD (headless).

const FieldGame = preload("res://game/field_game.gd")

var game


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	game.player.hands = [{"id": "pistol", "quality": "factory", "condition": 1.0, "loaded": 8}]


## A pulled trigger spends a round, or jams (the cold makes that a dice roll).
func _tried() -> bool:
	return int(game.player.weapon()["loaded"]) < 8 or game.player.jam_t > 0.0


func _raise() -> void:
	var hud = game.hud
	hud.pressing = true
	hud.aiming = true
	hud.aim_armed = true
	hud.aim_point = game.player.position + Vector3(8, 0, 0)
	assert_true(game.combat.start_aim(game.player))


func test_letting_go_on_yourself_lowers_the_gun() -> void:
	_raise()
	var me: Vector2 = game.hud._project(game.player.position + Vector3(0, 1.0, 0))
	game.hud._release(me)
	assert_false(game.player.aim.active)
	assert_false(_tried(), "no shot")


func test_letting_go_elsewhere_fires() -> void:
	_raise()
	var me: Vector2 = game.hud._project(game.player.position + Vector3(0, 1.0, 0))
	game.hud._release(me + Vector2(300, 0))
	assert_true(_tried(), "the trigger was pulled")


func test_losing_focus_pauses_and_drops_the_aim() -> void:
	_raise()
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(game.paused)
	assert_false(game.player.aim.active)
	assert_false(game.hud.aiming)
	game.hud._release(Vector2(10, 10))
	assert_false(_tried(), "the stale finger does not fire")


func test_enemy_at_your_feet_still_gets_shot() -> void:
	var p = game.player
	# Zoomed all the way out, as on a phone.
	game.cam_size = 36.0
	game.cam_focus = p.position
	game._update_camera(1.0)
	# Past the pistol's shove distance (1.2 m), but foreshortened onto the shooter on screen.
	var spot := Vector3.INF
	for off in [Vector3(0, 0, 1.4), Vector3(0, 0, -1.4), Vector3(1.3, 0, 0), Vector3(-1.3, 0, 0)]:
		if game.hud._over_player(game.hud._project(p.position + off + Vector3(0, 1.0, 0))):
			spot = p.position + off
			break
	assert_ne(spot, Vector3.INF, "some enemy past shove range still sits inside the ring")
	var z: Dictionary = game.zombies.spawn("dead", spot)
	game._refresh_vision()
	var at: Vector2 = game.hud._project(z["pos"] + Vector3(0, 1.0, 0))
	game.hud._press(at)
	assert_true(game.hud.aiming)
	game.hud._release(at)
	assert_true(_tried(), "it fires: the finger never left the shooter")


func test_run_toggle_stands_you_up() -> void:
	var hud = game.hud
	hud.crouch_button.button_pressed = true
	hud._toggle_crouch()
	assert_true(game.player.crouched)
	hud.run_button.button_pressed = true
	hud._toggle_run()
	assert_false(game.player.crouched)
	assert_false(hud.crouch_button.button_pressed)


func test_one_tap_fights_on_to_the_next_close_enemy() -> void:
	var p = game.player
	p.hands = [{"id": "axe", "quality": "factory", "condition": 0.9, "loaded": 0}]
	var a: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.8, 0, 0))
	var b: Dictionary = game.zombies.spawn("dead", p.position + Vector3(-1.2, 0, 0))
	b["state"] = "chase"
	game._refresh_vision()
	game.combat.melee_target(p, a, true)
	a["state"] = "dead"
	game.combat._pursue_zombie(p, 0.1)
	assert_eq(p.target_zombie, b, "the next one at you")
	assert_true(p.hold_attack)


func test_tapping_away_stops_the_fight() -> void:
	var p = game.player
	var b: Dictionary = game.zombies.spawn("dead", p.position + Vector3(-1.2, 0, 0))
	b["state"] = "chase"
	game._refresh_vision()
	p.hold_attack = true
	p.target_zombie = {}
	game.combat._pursue_zombie(p, 0.1)
	assert_true(p.target_zombie.is_empty(), "no new target after an order to stop")
	assert_false(p.hold_attack)
