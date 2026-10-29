extends "res://addons/gut/test.gd"
## What the dead hear, the player hears too (field_audio on_sound, TAG_VOICES):
## nails hammered in, a latch worked at, a can bashed open, a lure coming down,
## a clock in a pack, a bow loosed — each a stand-in until its files are in,
## the hammer for as long as the boarding lasts. What is no sound (smoke, a
## lamp's light) stays silent.

const FieldGame = preload("res://game/field_game.gd")
const SimNoise = preload("res://game/sim/noise.gd")

var game


func before_each() -> void:
	seed(20261030)
	game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()


func test_each_sound_the_dead_hear_is_heard_by_its_stand_in() -> void:
	var a = game.audio
	var at: Vector3 = game.player.position + Vector3(3, 0, 0)
	for tag: String in a.TAG_VOICES:
		if tag == "hammer":
			continue
		var v: Array = a.TAG_VOICES[tag]
		a.last_shot = null
		a.on_sound(at, SimNoise.Level.NORMAL, tag)
		assert_eq(a.last_tag_group, String(v[0]), tag + ": its own group's name")
		assert_not_null(a.last_shot, tag + ": played")
		var stand: String = v[1]
		if stand.begins_with("@"):
			assert_true(a.last_shot.stream in a.lib[stand.substr(1)], tag + ": its stand-in group")
		else:
			assert_true(a.last_shot.stream.resource_path.get_file().begins_with(stand), tag + ": the impact set's " + stand)
	for tag: String in ["smoke", "light"]:
		a.last_tag_group = "x"
		a.on_sound(at, SimNoise.Level.NORMAL, tag)
		assert_eq(a.last_tag_group, "", tag + " is no sound")


func test_a_can_bashed_open_is_two_knocks() -> void:
	var a = game.audio
	var n: int = a.tag_knocks
	a.on_sound(game.player.position, SimNoise.Level.NORMAL, "can_bash")
	assert_eq(a.tag_knocks - n, 1, "the first at once")
	await wait_seconds(float(a.TAG_VOICES["can_bash"][5]) + 0.15)
	assert_eq(a.tag_knocks - n, 2, "the second a moment after")


func test_the_hammer_knocks_while_the_boarding_lasts_then_stops() -> void:
	var a = game.audio
	var p = game.player
	var at: Vector3 = p.position + Vector3(0.8, 0, 0)
	p.action = "craft"
	var n: int = a.tag_knocks
	a.on_sound(at, SimNoise.Level.NORMAL, "hammer")
	assert_eq(a.tag_knocks - n, 1, "a knock at once")
	await wait_seconds(2.0)
	var during: int = a.tag_knocks - n
	assert_gt(during, 2, "knock after knock")
	assert_lt(during, 7, "not a drum roll")
	p.action = ""
	await wait_seconds(1.0)
	assert_eq(a.tag_knocks - n, during, "the boarding over, no more")
	# Nobody at a work there: not a knock.
	a.on_sound(at, SimNoise.Level.NORMAL, "hammer")
	assert_eq(a.tag_knocks - n, during)
