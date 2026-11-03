extends "res://addons/gut/test.gd"
## A door, a key, a window, a curtain, a climb through a frame, a locked or
## boarded door and a loose board each have files of their own (field_audio
## OWN_VOICE): heard at their own pitch, as loud as the stand-in was (the row's
## loudness, set by the stand-in, times OWN_VOICE's dB), never the same file
## twice running; with no files, the stand-in as before.

const FieldGame = preload("res://game/field_game.gd")

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


## Every row of the player's-ear sounds with an own file: [row, stand-in].
func _rows() -> Array:
	var a = game.audio
	var out: Array = []
	for row: Array in a.DOOR_TURN.values() + [a.DOOR_KEY] + a.WINDOW_TURN.values() + [a.VAULT_VOICE] + a.SHUT_FAST.values():
		out.append([row, String(row[4])])
	out.append([a.CREAK_VOICE, a.CREAK_STANDIN])
	return out


## The files shipped in each group (rights_ledger), so a lost one is caught.
const SHIPPED: Dictionary = {
	"floor_creak": 11, "door_open": 8, "door_close": 6, "door_unlock": 7, "door_locked": 5,
	"boarded": 8, "window_open": 4, "window_close": 4, "curtain": 2, "window_vault": 6,
}


func test_every_turned_thing_ships_files_of_its_own() -> void:
	var a = game.audio
	assert_eq(SHIPPED.size(), a.OWN_VOICE.size(), "every own group counted here")
	for group: String in SHIPPED:
		assert_eq(a._load_group(group).size(), int(SHIPPED[group]), group + ": as many files as shipped")
	var named: Array = []
	for pair: Array in _rows():
		named.append(String(pair[0][0]))
	for group: String in a.OWN_VOICE:
		assert_true(named.has(group), group + " is a row's group")
		var list: Array = a._load_group(group)
		assert_gte(list.size(), 1, group)
		for s in list:
			assert_between(s.get_length(), 0.1, 1.6, group)
		var own: Array = a.OWN_VOICE[group]
		assert_lt(float(own[0]), 1.0, group + ": its own pitch is about its own")
		assert_gt(float(own[1]), 1.0, group)
		assert_lte(float(own[2]), 6.0, group + ": at most +6 dB on the stand-in's loudness")
	for pair: Array in _rows():
		var g: String = pair[0][0]
		assert_true(a.OWN_VOICE.has(g), g + " has an own row")
		if a.OWN_VOICE.has(g):
			assert_lte(float(pair[0][1]) * db_to_linear(float(a.OWN_VOICE[g][2])), 1.0, g + ": not past full")


func test_an_own_file_at_its_own_pitch_and_loudness_never_twice_running() -> void:
	var a = game.audio
	var at: Vector3 = game.player.position
	for pair: Array in _rows():
		var row: Array = pair[0]
		var g: String = row[0]
		if not a.OWN_VOICE.has(g):
			continue
		var own: Array = a.OWN_VOICE[g]
		a.lib[g] = [_tone(), _tone(), _tone()]
		var last: AudioStream = null
		for k in range(12):
			a._voice_or_standin(row, String(pair[1]), at)
			assert_not_null(a.last_shot, g)
			if a.last_shot == null:
				break
			assert_true(a.last_shot.stream in a.lib[g], g + ": its own file")
			assert_between(float(a.last_shot.pitch_scale), float(own[0]), float(own[1]), g + ": its own pitch")
			assert_almost_eq(float(a.last_shot.volume_db), a._db(float(row[1])) + float(own[2]), 0.01, g + ": as loud as the stand-in")
			assert_ne(a.last_shot.stream, last, g + ": not the same file twice running")
			last = a.last_shot.stream


## Too far to hear (past 60 m), nothing is picked: the file heard last stays
## the one not to play again, so near, far, near never repeats what was heard.
func test_one_too_far_to_hear_does_not_count_as_heard() -> void:
	var a = game.audio
	var near: Vector3 = game.player.position
	var far: Vector3 = near + Vector3(70, 0, 0)
	for pair: Array in _rows():
		var row: Array = pair[0]
		var g: String = row[0]
		if not a.OWN_VOICE.has(g):
			continue
		a.lib[g] = [_tone(), _tone()]
		a._voice_or_standin(row, String(pair[1]), near)
		var first: AudioStream = a.last_shot.stream
		a._voice_or_standin(row, String(pair[1]), far)
		assert_null(a.last_shot, g + ": too far, nothing played")
		a._voice_or_standin(row, String(pair[1]), near)
		assert_ne(a.last_shot.stream, first, g + ": not the one heard last")


## Other rows that go through the same way (the glass in a frame, a manhole
## lid, glass underfoot, a box): when files come into one of them, it needs its
## own pitch and loudness too (OWN_VOICE), or its row's stand-in bending is
## put on its own recording.
func test_any_other_row_with_files_has_its_own_voice() -> void:
	var a = game.audio
	var rows: Array = [a.VAULT_GLASS, a.LID_VOICE, a.STEP_GLASS, a.CREAK_VOICE]
	for kind: String in a.BOX_VOICES:
		rows += (a.BOX_VOICES[kind] as Dictionary).values()
	rows += a.BOX_RUSTLE.values()
	for row: Array in rows:
		var g: String = row[0]
		if not a._load_group(g).is_empty():
			assert_true(a.OWN_VOICE.has(g), g + " ships files: give it a row in OWN_VOICE")
		else:
			assert_false(a.OWN_VOICE.has(g), g + ": no files, no own row")


func test_with_no_files_the_stand_in_as_before() -> void:
	var a = game.audio
	var at: Vector3 = game.player.position
	for pair: Array in _rows():
		var row: Array = pair[0]
		var g: String = row[0]
		var stand: String = pair[1]
		a.lib[g] = []
		a.last_shot = null
		a._voice_or_standin(row, stand, at)
		assert_not_null(a.last_shot, g + ": the stand-in is heard")
		if a.last_shot == null:
			continue
		assert_between(float(a.last_shot.pitch_scale), float(row[2]), float(row[3]), g + ": at the row's pitch")
		assert_almost_eq(float(a.last_shot.volume_db), a._db(float(row[1])), 0.01, g + ": at the row's loudness")
		if stand.begins_with("@"):
			assert_true(a.last_shot.stream in a.lib[stand.substr(1)], g + ": " + stand)
		else:
			assert_true(a.last_shot.stream.resource_path.get_file().begins_with(stand), g + ": " + stand)
