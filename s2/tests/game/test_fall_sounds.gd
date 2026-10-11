extends "res://addons/gut/test.gd"
## One of the dead going down is heard in four beats, in step with how it is
## drawn. Only the player hears it: the dead hear nothing of it.

const FieldGame = preload("res://game/field_game.gd")
const FieldAudio = preload("res://game/audio/field_audio.gd")
const DeadPose = preload("res://game/actors/dead_pose.gd")
const Motion = preload("res://game/sim/motion.gd")

var game
var a


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	game.player.position = game.lift(Vector2i(60, 7), 0)
	a = game.audio
	a.played.clear()


func _falls(cell: Vector2i) -> Dictionary:
	var z: Dictionary = game.zombies.spawn("dead", game.lift(cell, 0))
	z["age"] = 10.0
	DeadPose.mark_fall(z)
	return z


func _at(z: Dictionary, since: float) -> void:
	z["age"] = float(z["fell_at"]) + since
	a._tick_falls(game.player.position)


func test_the_beats_come_when_the_body_does_what_they_are() -> void:
	var length: float = float(Motion.row("dead_fall")["len"])
	var t: Array = FieldAudio.fall_times(false)
	assert_eq(t.size(), FieldAudio.FALL_BEATS.size())
	assert_almost_eq(float(t[2]), DeadPose.BUCKLE * length, 0.001, "the knees")
	assert_almost_eq(float(t[3]), DeadPose.LAND * length, 0.001, "the ground")
	assert_almost_eq(float(t[3]), float(Motion.row("dead_fall")["sound"]), 0.011, "where the motion table says its sound is")
	assert_lt(float(t[1]), DeadPose.REEL * length, "while it still reels")
	assert_eq(float(FieldAudio.fall_times(true)[0]), 0.0, "shot down: at once")
	for beat in FieldAudio.FALL_BEATS:
		assert_has(FieldAudio.GROUPS, beat[0])


func test_a_fall_nearby_plays_all_four_in_order_and_once() -> void:
	var z := _falls(Vector2i(64, 7))
	_at(z, 0.0)
	assert_eq(a.played, [], "a hand weapon's own sound comes first")
	_at(z, 0.04)
	assert_eq(a.played, ["fall_hit"])
	_at(z, 0.2)
	assert_eq(a.played, ["fall_hit", "fall_reel"])
	_at(z, 0.5)
	_at(z, 0.7)
	_at(z, 0.75)
	assert_eq(a.played, ["fall_hit", "fall_reel", "fall_knee", "fall_land"])
	assert_true(a.falls.is_empty(), "done with it")
	_at(z, 3.0)
	assert_eq(a.played.size(), 4, "lying there it is not heard again")


func test_far_off_only_the_ground_is_heard_and_farther_nothing() -> void:
	var z := _falls(Vector2i(60 + 30, 7))
	_at(z, 1.0)
	assert_eq(a.played, ["fall_land"])
	a.played.clear()
	var far := _falls(Vector2i(60 + 50, 7))
	_at(far, 1.0)
	assert_eq(a.played, [])


func test_of_many_falling_together_the_nearest_few_are_heard_each_beat_once() -> void:
	var all: Array = []
	for i in range(6):
		all.append(_falls(Vector2i(62 + i * 2, 7)))
	a._tick_falls(game.player.position)
	assert_eq(a.falls.size(), FieldAudio.FALL_AT_ONCE)
	var nearest: Array = []
	for f in a.falls:
		nearest.append(f["z"]["id"])
	nearest.sort()
	assert_eq(nearest, [all[0]["id"], all[1]["id"], all[2]["id"]])
	for z in all:
		z["age"] = float(z["fell_at"]) + 0.04
	a._tick_falls(game.player.position)
	assert_eq(a.played, ["fall_hit"], "one blow heard, not three in the same instant")


func test_the_dead_hear_nothing_of_it() -> void:
	var noise: int = game.ledger.total
	var heard: int = game.sounds.size()
	var z := _falls(Vector2i(64, 7))
	_at(z, 1.0)
	assert_eq(game.ledger.total, noise)
	assert_eq(game.sounds.size(), heard)
