extends "res://addons/gut/test.gd"
## The dead in sight call out by what happens to them (SAY_GROUPS): noticing
## you, taking a blow and going down each have files of their own once they
## are in, said in the body's own voice; until then a moan stands in, pitched
## as SAYS has it. Idle, chasing and biting stay with the moans.

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


func _tone(n: int) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_8_BITS
	w.mix_rate = 8000
	var data := PackedByteArray()
	for i in range(64 + n):
		data.append((i * (7 + n)) % 256)
	w.data = data
	return w


## The player on a spot with eight cells of open ground east of it, looking
## east (as test_field_audio's _open_spot and _look_east_from).
func _face_east() -> Vector3:
	var g = game.grid
	var c := Vector2i(-1, -1)
	for y in range(4, g.height - 5):
		for x in range(6, g.width - 12):
			var clear := true
			for dx in range(-2, 8):
				if g.opaque(Vector2i(x + dx, y)) or not g.people_can_walk(Vector2i(x + dx, y)):
					clear = false
					break
			if clear:
				c = Vector2i(x, y)
				break
		if c.x >= 0:
			break
	assert_ne(c, Vector2i(-1, -1), "the map has such a spot")
	var p = game.player
	p.position = game.lift(c, 0)
	p.facing = PI * 0.5
	game.cam_size = 36.0
	game.cam_focus = p.position
	game._update_camera(1.0)
	game._refresh_vision()
	return p.position


func _slot_of(z: Dictionary) -> Dictionary:
	for s in game.audio.slots:
		if s["z"] == z:
			return s
	return {}


func test_a_call_of_its_own_once_the_files_are_in() -> void:
	var at := _face_east()
	var a = game.audio
	a.lib["dead_notice"] = [_tone(1), _tone(2), _tone(3)]
	a.lib["dead_hit"] = [_tone(4), _tone(5)]
	var z: Dictionary = game.zombies.spawn("dead", at + Vector3(4, 0, 0))
	z["state"] = "wander"
	a.pick_t = 0.0
	for s in a.slots:
		s["wait"] = 0.0
	a.tick(0.1)
	var slot := _slot_of(z)
	assert_false(slot.is_empty(), "it has a voice")
	assert_eq(a.said.back()[1], "idle")
	assert_eq(a.said.back()[3], "moan", "wandering is a moan")
	# It starts after you: its own call, in its own voice, not a moan pitched up.
	z["state"] = "chase"
	a.tick(0.05)
	assert_eq(a.said.back().slice(0, 2), [z["id"], "notice"])
	assert_eq(a.said.back()[3], "dead_notice")
	assert_true((a.lib["dead_notice"] as Array).has(slot["player"].stream), "one of the notice files")
	var voice: float = float(a.voice_of(z)["pitch"])
	var band: float = float(a.moan_band(at.distance_to(z["pos"]))[1])
	assert_almost_eq(float(slot["player"].pitch_scale), voice * band, voice * band * 0.031, "its voice, no more")
	assert_gt(float(slot["cut"]), 0.0, "still a short call")
	# A blow lands: its own grunt.
	z["stun"] = 0.6
	a.tick(0.05)
	assert_eq(a.said.back()[1], "hit")
	assert_eq(a.said.back()[3], "dead_hit")
	assert_true((a.lib["dead_hit"] as Array).has(slot["player"].stream))
	# Chasing on: back to the moans.
	slot["wait"] = 0.0
	a.tick(0.05)
	assert_eq(a.said.back()[1], "chase")
	assert_eq(a.said.back()[3], "moan")


func test_without_its_files_a_moan_stands_in_as_before() -> void:
	var at := _face_east()
	var a = game.audio
	a.lib["dead_notice"] = []
	var z: Dictionary = game.zombies.spawn("dead", at + Vector3(4, 0, 0))
	z["state"] = "wander"
	a.pick_t = 0.0
	for s in a.slots:
		s["wait"] = 0.0
	a.tick(0.1)
	z["state"] = "chase"
	a.tick(0.05)
	var slot := _slot_of(z)
	assert_eq(a.said.back()[1], "notice")
	assert_eq(a.said.back()[3], "moan")
	assert_true((a.lib["moan"] as Array).has(slot["player"].stream))
	var voice: float = float(a.voice_of(z)["pitch"])
	var band: float = float(a.moan_band(at.distance_to(z["pos"]))[1])
	var want: float = voice * float(a.SAYS["notice"]["pitch"]) * band
	assert_almost_eq(float(slot["player"].pitch_scale), want, want * 0.031, "a moan pitched as a call")


func test_its_own_calls_never_come_twice_running() -> void:
	var at := _face_east()
	var a = game.audio
	a.lib["dead_hit"] = [_tone(1), _tone(2), _tone(3)]
	var z: Dictionary = game.zombies.spawn("dead", at + Vector3(4, 0, 0))
	z["state"] = "chase"
	a.pick_t = 0.0
	a.tick(0.1)
	var last := -1
	for k in range(20):
		z["stun"] = 0.0
		a.tick(0.05)
		z["stun"] = 0.6
		a.tick(0.05)
		var e: Array = a.said.back()
		assert_eq(e[3], "dead_hit")
		assert_ne(e[2], last, "not the grunt just heard")
		last = e[2]


func test_going_down_in_sight_breathes_out_its_own_fall() -> void:
	var at := _face_east()
	var a = game.audio
	a.lib["dead_fall"] = [_tone(1), _tone(2)]
	var z: Dictionary = game.zombies.spawn("dead", at + Vector3(3, 0, 0))
	assert_true(a.in_view(z["pos"]))
	z["fell_at"] = 0.0
	z["age"] = 1.0
	a._tick_falls(game.player.position)
	var fell: Array = []
	for e in a.said:
		if e[1] == "fall":
			fell.append(e)
	assert_eq(fell.size(), 1)
	assert_eq(fell[0][3], "dead_fall")


## Its own call does not wait on the moans: with no moan at all, a fall still
## breathes out its own file; with neither, nothing is said.
func test_its_own_call_needs_no_moan() -> void:
	var at := _face_east()
	var a = game.audio
	a.lib["moan"] = []
	a.lib["dead_fall"] = [_tone(1)]
	var z: Dictionary = game.zombies.spawn("dead", at + Vector3(3, 0, 0))
	assert_true(a.in_view(z["pos"]))
	a._fall_voice(z, game.player.position)
	assert_eq(a.said.size(), 1, "heard without a moan")
	assert_eq(a.said.back()[3], "dead_fall")
	a.lib["dead_fall"] = []
	assert_eq(a._call_for("fall", a.voice_of(z), -1), [], "neither: nothing to say with")
	a._fall_voice(z, game.player.position)
	assert_eq(a.said.size(), 1, "and nothing said")


## Gone out of sight, one of the dead says nothing new, struck or not, while
## its slot keeps what it was saying a moment (VOICE_KEEP).
func test_out_of_sight_it_starts_no_new_call() -> void:
	var at := _face_east()
	var a = game.audio
	a.lib["dead_hit"] = [_tone(1), _tone(2)]
	var z: Dictionary = game.zombies.spawn("dead", at + Vector3(3, 0, 0))
	z["state"] = "chase"
	a.pick_t = 0.0
	for s in a.slots:
		s["wait"] = 0.0
	a.tick(0.05)
	var heard: int = a.said.size()
	assert_gt(heard, 0, "in sight, it calls")
	game.player.facing = -PI * 0.5
	game._refresh_vision()
	assert_false(a.in_view(z["pos"]))
	z["stun"] = 0.6
	for s in a.slots:
		s["wait"] = 0.0
	a.pick_t = 1.0
	a.tick(0.05)
	assert_eq(a.said.size(), heard, "out of sight: no new call, not even a blow's")


## About to run: its own rasp once the files are in, read the first time it is
## heard, never the one just heard, a little higher or lower each time.
func test_the_rasp_before_a_run_is_its_own_once_in() -> void:
	var at := _face_east()
	var a = game.audio
	a.lib.erase(a.TELL_GROUP)
	a.lunge_tell(at + Vector3(3, 0, 0))
	assert_true(a.lib.has(a.TELL_GROUP), "read on first use")
	assert_gte((a.lib[a.TELL_GROUP] as Array).size(), 3, "the shipped files, read")
	assert_not_null(a.last_shot)
	assert_true(a.last_shot.stream in a.lib[a.TELL_GROUP], "and heard the first time")
	# One file only: heard each time, never stuck on avoiding it.
	var one: Array = [_tone(4)]
	a.lib[a.TELL_GROUP] = one
	for k in range(3):
		a.lunge_tell(at + Vector3(3, 0, 0))
		assert_eq(a.last_shot.stream, one[0], "the one file")
	var files: Array = [_tone(1), _tone(2), _tone(3)]
	a.lib[a.TELL_GROUP] = files
	var last: AudioStream = null
	for k in range(12):
		a.lunge_tell(at + Vector3(3, 0, 0))
		assert_not_null(a.last_shot)
		assert_true(files.has(a.last_shot.stream), "one of its own")
		assert_ne(a.last_shot.stream, last, "not the one just heard")
		assert_between(float(a.last_shot.pitch_scale), 0.94, 1.06)
		last = a.last_shot.stream
	a.lib[a.TELL_GROUP] = []
	a.lunge_tell(at + Vector3(3, 0, 0))
	assert_almost_eq(float(a.last_shot.pitch_scale), float(a.TELL_STANDIN_PITCH), 0.001, "a moan pitched up stands in")


## The rasp before a run is a rule's warning, heard even from one of the dead
## out of sight (decision 509's own exception): behind the player it still rasps.
func test_the_rasp_before_a_run_is_heard_out_of_sight_too() -> void:
	var at := _face_east()
	var a = game.audio
	a.lib[a.TELL_GROUP] = [_tone(1), _tone(2)]
	var behind: Vector3 = at + Vector3(-3, 0, 0)
	assert_false(a.in_view(behind), "behind the player: out of sight")
	a.played.clear()
	a.last_shot = null
	a.lunge_tell(behind)
	assert_eq(a.played.count(a.TELL_GROUP), 1, "the warning is given")
	assert_not_null(a.last_shot, "and heard")
	if a.last_shot != null:
		assert_true(a.last_shot.stream in a.lib[a.TELL_GROUP], "its own rasp")
		assert_gt(float(a.last_shot.volume_db), -40.0, "not muted for being unseen")


func test_the_shipped_calls_are_short() -> void:
	var a = game.audio
	for g in ["dead_notice", "dead_hit", "dead_fall", "lunge_tell"]:
		var list: Array = a._load_group(g)
		assert_gte(list.size(), 3, g)
		for s in list:
			assert_between(s.get_length(), 0.1, 1.6, g)
