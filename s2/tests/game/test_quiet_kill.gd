extends "res://addons/gut/test.gd"
## A crouched knife from behind ends a body that has not noticed anyone, from
## whichever side it is come at (weapons.md 날붙이, zombies.md 뒤에서 조용히).

const FieldGame = preload("res://game/field_game.gd")

var game
var p


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 17, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	p = game.player
	p.position = game.lift(Vector2i(60, 7), 0)
	p.hands = [{"id": "knife", "quality": "factory", "condition": 1.0, "loaded": 0}]
	p.set_weapon_slots(p.hands)
	p.aim.stop()
	p.crouched = true


## A wandering body at `way` from the player, its back to the player.
func _back_turned(way: Vector3, state: String = "wander") -> Dictionary:
	var z: Dictionary = game.zombies.spawn("dead", p.position + way * 0.9)
	z["state"] = state
	z["angle"] = atan2(way.x, way.z)
	return z


func test_the_quiet_blow_ends_it_from_every_side() -> void:
	for way in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var z := _back_turned(way)
		assert_true(game.combat.behind(z, p.position), "the player is at its back (%s)" % way)
		game.combat.swing(p, z)
		assert_eq(z["state"], "dead", "a quiet knife from behind is one blow (%s)" % way)

