extends "res://addons/gut/test.gd"
## A shove that knocks one of the dead over (decision 412): half go down at
## once, half reel back on their feet first and go down after, lying as long.

const FieldGame = preload("res://game/field_game.gd")
const Zombies = preload("res://game/actors/zombies.gd")

var game
var p


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 31, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	p = game.player
	p.position = game.lift(Vector2i(60, 7), 0)


## A body whose own number makes it reel first (or not).
func _body(reels: bool) -> Dictionary:
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.8, 0, 0))
	for i in range(100):
		z["phase"] = (i + 0.5) / 100.0
		if Zombies.reels_first(z) == reels:
			return z
	return z


func _run(seconds: float) -> void:
	for i in range(roundi(seconds * 30.0)):
		game.zombies.update(1.0 / 30.0)


func test_half_reel_first_apart_from_how_they_fall() -> void:
	# DeadBody.fall_motion picks the way down by phase * 5.17; the two choices cross.
	var seen := {}
	var reel := 0
	for i in range(200):
		var z := {"phase": (i + 0.5) / 200.0}
		var first := Zombies.reels_first(z)
		reel += 1 if first else 0
		seen[[first, fposmod(float(z["phase"]) * 5.17, 1.0) < 0.5]] = true
	assert_eq(seen.size(), 4, "every pairing of when and how it falls")
	assert_between(reel, 80, 120, "about half reel first")


func test_one_goes_down_at_once() -> void:
	var z := _body(false)
	game.zombies.release(z, p.position, true)
	assert_eq(z["state"], "downed")
	assert_false(z.has("fall_in"))


func test_the_other_reels_on_its_feet_then_goes_down_lying_as_long() -> void:
	var z := _body(true)
	game.zombies.release(z, p.position, true)
	assert_eq(z["state"], "chase", "on its feet while it reels")
	assert_gt(float(z["stun"]), 0.0, "stunned: it cannot bite or grab")
	assert_almost_eq(float(z["fall_in"]), Zombies.SHOVED_TIME, 0.001)
	_run(Zombies.SHOVED_TIME - 0.1)
	assert_eq(z["state"], "chase", "still reeling")
	_run(0.15)
	assert_eq(z["state"], "downed", "then it goes over")
	assert_between(float(z["t"]), Zombies.GET_UP.x - 0.1, Zombies.GET_UP.y, "and lies as long as one gone down at once")


func test_killed_while_it_reels_it_does_not_go_down_again() -> void:
	var z := _body(true)
	game.zombies.release(z, p.position, true)
	game.zombies.kill(z)
	_run(0.4)
	assert_eq(z["state"], "dead")
	assert_false(z.has("fall_in"))


func test_a_shove_that_does_not_knock_it_over_is_as_before() -> void:
	var z := _body(true)
	game.zombies.release(z, p.position, false)
	assert_eq(z["state"], "chase")
	assert_false(z.has("fall_in"))
	_run(0.4)
	assert_ne(z["state"], "downed")
