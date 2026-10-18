extends "res://addons/gut/test.gd"
## A building door takes the same rule as the train's (user's morning answer to
## the house doors, decision 314): one of the dead alone only knocks on it; with
## another within 1.5 m of the one striking, the blows wear it down.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")

var game
var door_c := Vector2i(-1, -1)
var stand := Vector3.ZERO


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 17, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	door_c = Vector2i(-1, -1)
	for c in game.grid.doors:
		if String(game.grid.doors[c]["state"]) != "closed":
			continue
		for n in [c + Vector2i(1, 0), c + Vector2i(-1, 0), c + Vector2i(0, 1), c + Vector2i(0, -1)]:
			if not game.grid.blocks_body(n) and not game.grid.doors.has(n) and not game.grid.windows.has(n):
				door_c = c
				stand = FieldGrid.center(n)
				break
		if door_c.x >= 0:
			break


## The dead at the door bang on it for this long (the walk calls _bang each step).
func _bang_for(seconds: float, at_door: Array) -> void:
	var t := 0.0
	while t < seconds:
		for z in at_door:
			game.zombies._bang(z, door_c, 0.1)
		t += 0.1


func _hp() -> int:
	return int(game.grid.doors[door_c]["hp"])


func test_one_alone_knocks_a_minute_and_the_door_holds() -> void:
	assert_true(door_c.x >= 0, "the map has a shut door to stand at")
	var before := _hp()
	var z: Dictionary = game.zombies.spawn("dead", stand)
	game.sounds.clear()
	_bang_for(60.0, [z])
	assert_eq(_hp(), before, "alone a minute: hp %d, then %d" % [before, _hp()])
	assert_eq(String(game.grid.doors[door_c]["state"]), "closed")
	var bangs: int = game.sounds.filter(func(s: Dictionary) -> bool: return s["tag"] == "bang").size()
	# A blow every 1.3 s, taken in 0.1 s steps: about 43 to 46 in the minute.
	assert_between(bangs, 42, 47, "the knocking is still made: %d" % bangs)


func test_two_together_wear_it_down() -> void:
	assert_true(door_c.x >= 0)
	var before := _hp()
	var a: Dictionary = game.zombies.spawn("dead", stand)
	var b: Dictionary = game.zombies.spawn("dead", stand + Vector3(0.3, 0, 0.3))
	_bang_for(13.0, [a, b])
	assert_eq(before - _hp(), mini(20, before), "two for 13 s: hp %d, then %d" % [before, _hp()])


func test_one_more_too_far_off_or_down_does_not_count() -> void:
	assert_true(door_c.x >= 0)
	var before := _hp()
	var a: Dictionary = game.zombies.spawn("dead", stand)
	game.zombies.spawn("dead", stand + Vector3(2.0, 0, 0))
	var down: Dictionary = game.zombies.spawn("dead", stand + Vector3(0.4, 0, 0))
	down["state"] = "downed"
	_bang_for(13.0, [a])
	assert_eq(_hp(), before, "one 2 m off and one lying down: hp %d, then %d" % [before, _hp()])
