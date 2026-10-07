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


func _raise() -> void:
	var hud = game.hud
	hud.pressing = true
	hud.aiming = true
	hud.aim_point = game.player.position + Vector3(8, 0, 0)
	assert_true(game.combat.start_aim(game.player))


func test_letting_go_on_yourself_lowers_the_gun() -> void:
	_raise()
	var me: Vector2 = game.hud._project(game.player.position + Vector3(0, 1.0, 0))
	game.hud._release(me)
	assert_false(game.player.aim.active)
	assert_eq(int(game.player.weapon()["loaded"]), 8, "no shot")


func test_letting_go_elsewhere_fires() -> void:
	_raise()
	var me: Vector2 = game.hud._project(game.player.position + Vector3(0, 1.0, 0))
	game.hud._release(me + Vector2(300, 0))
	assert_eq(int(game.player.weapon()["loaded"]), 7, "one round fired")


func test_losing_focus_pauses_and_drops_the_aim() -> void:
	_raise()
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(game.paused)
	assert_false(game.player.aim.active)
	assert_false(game.hud.aiming)
	game.hud._release(Vector2(10, 10))
	assert_eq(int(game.player.weapon()["loaded"]), 8, "the stale finger does not fire")
