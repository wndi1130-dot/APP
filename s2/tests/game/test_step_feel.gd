extends "res://addons/gut/test.gd"
## No two steps alike, and a step by how the player moves (field_audio
## STEP_GAIN_DB, STEP_PITCH, STEP_CROUCH, STEP_LOAD): each step a little louder
## or softer and higher or lower; crouched, softer; under a load, louder and lower.

const FieldGame = preload("res://game/field_game.gd")
const FieldAudio = preload("res://game/audio/field_audio.gd")

var game


func before_each() -> void:
	seed(20261102)
	game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()


func _tone() -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_8_BITS
	w.mix_rate = 8000
	w.data = PackedByteArray([0, 40, 80, 40, 0, 216, 176, 216])
	return w


func test_no_two_steps_are_alike() -> void:
	seed(7)   # again after the field is set up: its setting up draws numbers too
	assert_eq(FieldAudio.STEP_GAIN_DB, 2.0, "two dB either way")
	assert_eq(FieldAudio.STEP_PITCH, [0.95, 1.05], "five per cent either way")
	var gains: Dictionary = {}
	var pitches: Dictionary = {}
	for k in range(200):
		var w: Array = FieldAudio.step_wobble()
		assert_between(float(w[0]), db_to_linear(-FieldAudio.STEP_GAIN_DB) - 0.0001, db_to_linear(FieldAudio.STEP_GAIN_DB) + 0.0001, "within the loudness wobble")
		assert_between(float(w[1]), float(FieldAudio.STEP_PITCH[0]), float(FieldAudio.STEP_PITCH[1]), "within the pitch wobble")
		gains[snappedf(float(w[0]), 0.01)] = true
		pitches[snappedf(float(w[1]), 0.005)] = true
	assert_gt(gains.size(), 20, "the loudness wanders")
	assert_gt(pitches.size(), 10, "and the pitch")


func test_a_step_by_how_one_moves() -> void:
	var plain: Array = FieldAudio.feel_of(false, 0)
	assert_eq(plain, [1.0, 1.0], "walking light, as the floor has it")
	var crouched: Array = FieldAudio.feel_of(true, 0)
	assert_lt(float(crouched[0]), 0.7, "crouched, a good deal softer")
	var heavy: Array = FieldAudio.feel_of(false, 1)
	var over: Array = FieldAudio.feel_of(false, 2)
	assert_gt(float(heavy[0]), 1.0, "a load is heard")
	assert_gt(float(over[0]), float(heavy[0]), "more of it, more")
	assert_lt(float(heavy[1]), 1.0, "and lower")
	assert_lt(float(over[1]), float(heavy[1]))
	assert_eq(FieldAudio.feel_of(false, 9), FieldAudio.feel_of(false, 3), "past the last state, the last")
	assert_eq(FieldAudio.feel_of(false, -1), plain, "below the first, the first")
	# The values themselves (first values).
	assert_almost_eq(float(crouched[0]), 0.55, 0.0001)
	assert_almost_eq(float(heavy[0]), 1.12, 0.0001)
	assert_almost_eq(float(heavy[1]), 0.97, 0.0001)
	assert_almost_eq(float(over[0]), 1.25, 0.0001)
	assert_almost_eq(float(over[1]), 0.94, 0.0001)
	var both: Array = FieldAudio.feel_of(true, 2)
	assert_almost_eq(float(both[0]), 0.55 * 1.25, 0.0001, "crouched under a load: both")
	assert_almost_eq(float(both[1]), 0.94, 0.0001)


## The player's own feel is its crouch and its real load (Person.carry_state).
func test_the_players_feel_is_its_own() -> void:
	var a = game.audio
	var p = game.player
	p.crouched = false
	assert_eq(a.step_feel(), FieldAudio.feel_of(false, int(p.carry_state())))
	p.crouched = true
	assert_eq(a.step_feel(), FieldAudio.feel_of(true, int(p.carry_state())))
	p.crouched = false


## Crouched, every step is softer than any step standing (the wobble is
## smaller than the crouch), on the same floor.
func test_crouched_steps_are_always_softer() -> void:
	var a = game.audio
	var p = game.player
	var at: Vector3 = p.position
	assert_false(game.grid.floor_glass.has(game.FieldGrid.cell_of(at)), "no glass underfoot (its crunch would be the last heard)")
	var g = a._step_group(at)[0]
	a.lib[g] = [_tone(), _tone(), _tone()]
	var standing: Array = []
	var low: Array = []
	p.crouched = false
	for k in range(40):
		a.footstep(at, false)
		standing.append(float(a.last_shot.volume_db))
	p.crouched = true
	for k in range(40):
		a.footstep(at, false)
		low.append(float(a.last_shot.volume_db))
	p.crouched = false
	assert_lt(low.max(), standing.min(), "crouched is always softer")
	assert_gt(standing.max() - standing.min(), 1.0, "and standing steps are not all one loudness")
