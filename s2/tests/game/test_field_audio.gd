extends "res://addons/gut/test.gd"
## Graybox sound (sound_music 12.1): silent with no files, and with files the
## nearest dead get the voices, the crowd raises the bed, actions make noise.

const FieldGame = preload("res://game/field_game.gd")

var game


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	game.player.position = game.lift(Vector2i(60, 7), 0)


func _tone() -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_8_BITS
	w.mix_rate = 8000
	w.data = PackedByteArray([0, 40, 80, 40, 0, 216, 176, 216])
	return w


## A spot on the ground where a w x h block of cells east and south of it
## has nothing that stops the eye, found on the map so a map change cannot
## put a wall in the way.
func _open_spot(w: int, h: int) -> Vector2i:
	var g = game.grid
	for y in range(4, g.height - h - 4):
		for x in range(4, g.width - w - 4):
			if not g.people_can_walk(Vector2i(x, y)):
				continue
			var clear := true
			for dy in range(h):
				for dx in range(-2, w):
					if g.opaque(Vector2i(x + dx, y + dy)):
						clear = false
						break
				if not clear:
					break
			if clear:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## A spot with open ground two cells east, then a wall one cell thick, then
## open ground the dead can stand on: the player here, the dead 4 m east.
func _wall_spot() -> Vector2i:
	var g = game.grid
	for y in range(4, g.height - 4):
		for x in range(4, g.width - 8):
			var c := Vector2i(x, y)
			if not g.people_can_walk(c) or g.opaque(c + Vector2i(1, 0)) or g.opaque(c + Vector2i(2, 0)):
				continue
			if g.solid_at(c + Vector2i(3, 0)) != g.Solid.WALL or g.opaque(c + Vector2i(4, 0)) or g.opaque(c + Vector2i(5, 0)):
				continue
			if g.dead_can_walk(c + Vector2i(4, 0)):
				return c
	return Vector2i(-1, -1)


## Stand at c looking east, the camera on you as on a phone, and look.
func _look_east_from(c: Vector2i) -> void:
	assert_ne(c, Vector2i(-1, -1), "the map has such a spot")
	var p = game.player
	p.position = game.lift(c, 0)
	p.facing = PI * 0.5
	game.cam_size = 36.0
	game.cam_focus = p.position
	game._update_camera(1.0)
	game._refresh_vision()


func _voiced() -> Array:
	var out: Array = []
	for s in game.audio.slots:
		if not s["z"].is_empty():
			out.append(s["z"])
	return out


func test_no_files_is_silence_not_a_crash() -> void:
	for g in game.audio.GROUPS:
		game.audio.lib[g] = []
	game.zombies.spawn("dead", game.player.position + Vector3(3, 0, 0))["state"] = "chase"
	game.audio.tick(0.5)
	game.make_sound(game.player.position, 2, "kick")
	game.audio.horde_started()
	assert_eq(game.audio.last_tag_group, "impact")
	assert_true(AudioServer.get_bus_index("SFX") >= 0, "SFX bus made")


func test_the_six_nearest_dead_in_sight_get_voices() -> void:
	# In the stop's fog and snow the eye reaches some 13 m: all eight within it.
	_look_east_from(_open_spot(14, 1))
	game.audio.lib["moan"] = [_tone()]
	var dead: Array = []
	for i in range(8):
		var z: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(2.0 + i * 1.4, 0, 0))
		z["state"] = "chase"
		dead.append(z)
	for z in dead:
		assert_true(game.audio.in_view(z["pos"]), "all eight are in sight")
	game.audio.pick_t = 0.0
	game.audio.tick(0.1)
	var voiced := _voiced()
	assert_eq(voiced.size(), 6)
	for i in range(6):
		assert_true(voiced.has(dead[i]), "nearest first")
	assert_false(voiced.has(dead[7]))


func test_a_bigger_nearer_crowd_in_sight_is_a_louder_bed_and_one_behind_you_is_none() -> void:
	_look_east_from(_open_spot(7, 4))
	game.audio._assign_moans(game.player.position)
	var none: float = game.audio.crowd
	for i in range(10):
		game.zombies.spawn("dead", game.player.position + Vector3(5, 0, i * 0.3))["state"] = "horde"
	game.audio._assign_moans(game.player.position)
	assert_gt(game.audio.crowd, none + 5.0)
	# Turn round: the same crowd is now behind you, out of sight, and still.
	game.player.facing = -PI * 0.5
	game._refresh_vision()
	game.audio._assign_moans(game.player.position)
	assert_eq(game.audio.crowd, 0.0, "no bed for the dead you cannot see")


func test_noises_pick_their_sound() -> void:
	var a = game.audio
	a.on_sound(game.player.position, 3, "whistle")
	assert_eq(a.last_tag_group, "whistle")
	a.lib["gun"] = []
	a.on_sound(game.player.position, 2, "gun")
	assert_eq(a.last_tag_group, "impact", "shots fall back to an impact")
	a.on_sound(game.player.position, 1, "smoke")
	assert_eq(a.last_tag_group, "")


# Scene one: a horde sets off far away. It is out of sight, so no voice: a far
# thud (low, through the dullest bus) and birds tell it, the bed stays silent.
func test_a_far_horde_is_told_by_a_thud_and_birds_not_by_voices() -> void:
	var c := _open_spot(4, 1)
	_look_east_from(c)
	var a = game.audio
	a.lib["moan"] = [_tone()]
	# Thirty-odd metres off along the row, on the map, well past the sight radius.
	var step: int = 1 if c.x + 45 < game.grid.width else -1
	for i in range(12):
		var far: Vector3 = game.lift(Vector2i(c.x + step * (32 + i), c.y), 0)
		var z: Dictionary = game.zombies.spawn("dead", far, {"target": game.player.position})
		assert_false(a.in_view(z["pos"]))
	a.played.clear()
	a.horde_started()
	assert_eq(a.played, ["far_thud", "birds"])
	assert_eq(a.last_bus, "SFX", "the birds go through the plain bus")
	a.horde_started()
	assert_eq(a.played, ["far_thud", "birds", "far_thud"], "birds now and then, the thud each time")
	a.pick_t = 0.0
	for s in a.slots:
		s["wait"] = 0.0
	a.tick(0.1)
	assert_eq(_voiced().size(), 0, "no voice from a horde out of sight")
	assert_eq(a.crowd, 0.0, "and no bed")
	assert_false(a.GROUPS.has("gather"), "the far gathering moans are gone")
	assert_false(DirAccess.dir_exists_absolute("res://audio/gather"))


func test_the_far_thud_is_low_and_dull() -> void:
	var a = game.audio
	a.horde_started()
	var thud: AudioStreamPlayer3D = null
	for o in a.one_shots:
		if o.stream != null and o.stream.resource_path.get_file().begins_with(a.FAR_THUD[0]):
			thud = o
	assert_not_null(thud, "an impact file stands in for the thud")
	assert_eq(String(thud.bus), "SFX_FAR")
	assert_lte(thud.pitch_scale, float(a.FAR_THUD[3]))


# Scene two: one of the dead stands 4 m off behind a wall. It makes no voice,
# but its knock and its fall are heard, duller (through the wall).
func test_the_dead_behind_a_wall_knock_and_fall_duller_but_do_not_moan() -> void:
	var c := _wall_spot()
	_look_east_from(c)
	var a = game.audio
	a.lib["moan"] = [_tone()]
	var z: Dictionary = game.zombies.spawn("dead", game.lift(c + Vector2i(4, 0), 0))
	z["state"] = "chase"
	assert_false(a.in_view(z["pos"]), "the wall hides it")
	assert_true(a.through_wall(z["pos"]))
	a.pick_t = 0.0
	a.tick(0.1)
	assert_eq(_voiced().size(), 0, "no moan from behind the wall")
	game.make_sound(z["pos"], 2, "bang")
	assert_eq(a.last_tag_group, "impact", "the knock is heard")
	assert_eq(a.last_bus, "SFX_MID", "duller, through the wall")
	a._fall_beat(3, z["pos"], game.player.position, false, 1.0)
	assert_eq(a.last_bus, "SFX_MID", "its fall too")
	# The same knock with nothing between is plain.
	game.make_sound(game.lift(c + Vector2i(2, 0), 0), 2, "bang")
	assert_eq(a.last_bus, "SFX")


# Scene three: one of the dead in plain sight moans. Gone out of sight it keeps
# its voice a moment (no cut at the edge of the cone), then falls silent.
func test_the_dead_in_sight_moan_and_fall_silent_a_moment_after_going_out_of_sight() -> void:
	_look_east_from(_open_spot(6, 1))
	var a = game.audio
	a.lib["moan"] = [_tone()]
	var z: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(5, 0, 0))
	z["state"] = "wander"
	a.pick_t = 0.0
	for s in a.slots:
		s["wait"] = 0.0
	a.tick(0.1)
	assert_eq(_voiced(), [z], "seen, it has a voice")
	# Turn away: it is out of sight now.
	game.player.facing = -PI * 0.5
	game._refresh_vision()
	assert_false(a.in_view(z["pos"]))
	a.pick_t = 0.0
	a.tick(a.VOICE_KEEP * 0.5)
	assert_eq(_voiced(), [z], "kept a moment")
	a.pick_t = 0.0
	a.tick(a.VOICE_KEEP)
	assert_eq(_voiced().size(), 0, "then silent")
	# One that was never seen is never given a voice, however near.
	var unseen: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(3, 0, 0))
	unseen["state"] = "chase"
	a.pick_t = 0.0
	a.tick(0.1)
	assert_eq(_voiced().size(), 0)


func test_depart_note_holds_the_mix_and_leave_plays_its_beats_in_order() -> void:
	var a = game.audio
	game.hud.depart_card()
	assert_true(a.held)
	var bed: float = a.bed.volume_db
	a.tick(0.5)
	assert_eq(a.bed.volume_db, bed, "the bed stays put while the note is up")
	game.hud._card_pick(game.hud._depart_pick, "go")
	assert_false(a.held)
	assert_true(game.ended)
	assert_eq(a.played, ["impact"], "impact at once, the rest follow")
	await wait_seconds(1.0)
	assert_eq(a.played, ["impact", "pen", "whistle"])


func test_the_shipped_files_load() -> void:
	var a = game.audio
	for g in ["moan", "horde_bed", "birds", "impact", "gun", "step_snow", "wind", "train_idle", "whistle", "pen"]:
		var list: Array = a._load_group(g)
		assert_gt(list.size(), 0, g)
		for s in list:
			assert_gt(s.get_length(), 0.1, g)
	assert_eq(a._load_group("moan").size(), 8)
	assert_eq(a._load_group("birds").size(), 1)
	assert_eq(a._load_group("pen").size(), 3)
	for g in ["door_bang", "door_wall", "door_break"]:
		assert_eq(a._load_group(g).size(), 2, g)
		for s in a._load_group(g):
			assert_gt(s.get_length(), 0.1, g)


func test_the_radio_hisses_then_calls_and_an_urgent_call_is_the_loudest() -> void:
	var a = game.audio
	for g in ["radio_hiss", "radio"]:
		assert_eq(a._load_group(g).size(), 1, g)
		assert_gt(a._load_group(g)[0].get_length(), 0.5, g)
	a.played.clear()
	game.radio_last = -INF
	game.set_radio("들어온다", "urgent")
	assert_eq(a.played, ["radio_hiss"], "the hiss first")
	game._tick_radio(game.RADIO_HISS + 0.01)
	assert_eq(a.played, ["radio_hiss", "radio"], "then the call")
	assert_gt(float(a.RADIO_LOUD["urgent"]), float(a.RADIO_LOUD["call"]))
	assert_gt(float(a.RADIO_LOUD["call"]), float(a.RADIO_LOUD["hiss"]))
	a.played.clear()
	game.set_radio("신호소 위: 동쪽", "say")
	assert_eq(a.played, [], "what is said to your face makes no radio sound")


# Far moans are lower and duller than near ones (user 2026-10-11).
func test_a_far_moan_is_lower_and_duller_than_a_near_one() -> void:
	var a = game.audio
	a.lib["moan"] = [_tone()]
	for dull in a.DULL_BUSES:
		var bus := AudioServer.get_bus_index(dull)
		assert_true(bus >= 0, dull + " bus made")
		assert_eq(AudioServer.get_bus_send(bus), &"SFX", "ducked with the rest")
		var low: AudioEffectLowPassFilter = AudioServer.get_bus_effect(bus, 0)
		assert_eq(low.cutoff_hz, float(a.DULL_BUSES[dull]))
	assert_lt(float(a.DULL_BUSES["SFX_FAR"]), float(a.DULL_BUSES["SFX_MID"]), "the farthest is the dullest")
	# The bands, not the sight: the mask is off so the far one is seen too
	# (in fog the eye stops short of the far band).
	_look_east_from(_open_spot(18, 1))
	game.mask_on = false
	var heard: Dictionary = {}
	for d in [3.0, 12.0, 17.0]:
		var z: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(d, 0, 0))
		z["state"] = "chase"
		heard[d] = z
	a.pick_t = 0.0
	for s in a.slots:
		s["wait"] = 0.0
	a.tick(0.1)
	var by: Dictionary = {}
	for s in a.slots:
		for d in heard:
			if s["z"] == heard[d]:
				by[d] = s["player"]
	assert_eq(by.size(), 3)
	assert_eq(String(by[3.0].bus), "SFX")
	assert_eq(String(by[12.0].bus), "SFX_MID")
	assert_eq(String(by[17.0].bus), "SFX_FAR")
	# The bands do not overlap: for one voice the lowest near moan is above the
	# highest far one (each moan is its voice's pitch, times its band, give or
	# take 3%).
	assert_gt(0.97 * float(a.moan_band(3.0)[1]), 1.03 * float(a.moan_band(12.0)[1]))
	assert_gt(0.97 * float(a.moan_band(12.0)[1]), 1.03 * float(a.moan_band(17.0)[1]))
	for d in heard:
		var own: float = float(a.voice_of(heard[d])["pitch"]) * float(a.SAYS["chase"]["pitch"])
		var k: float = by[d].pitch_scale / own
		assert_between(k, 0.97 * float(a.moan_band(d)[1]) - 0.001, 1.03 * float(a.moan_band(d)[1]) + 0.001, str(d))
	assert_lt(by[17.0].volume_db, by[3.0].volume_db, "and quieter, as before")


# Each of the dead has a voice of its own (decided by the seed), says what it
# is doing, and no file comes twice in a row (user 2026-10-24: 「다양하게」).
func test_each_dead_keeps_its_own_voice_from_the_seed() -> void:
	var a = game.audio
	var kinds: Dictionary = {}
	for i in range(24):
		var z: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(i, 0, 0))
		var v: Dictionary = a.voice_of(z)
		kinds[v["kind"]] = true
		assert_eq(a.voice_of(z), v, "the same each time it is heard")
		# Only the spawn's seeded phase and the kind decide it: another body
		# with the same phase sounds the same.
		var twin := z.duplicate()
		twin["id"] = 9000 + i
		assert_eq(a.voice_of(twin), v)
		assert_between(float(v["pitch"]) / float(a.VOICES[v["kind"]]["pitch"]), 1.0 - a.VOICE_SPREAD - 0.001, 1.0 + a.VOICE_SPREAD + 0.001)
	assert_eq(kinds.keys().size(), 3, "low, middle and high all turn up")
	var fresh: Dictionary = game.zombies.spawn("fresh", game.player.position + Vector3(1, 0, 1))
	assert_eq(a.voice_of(fresh)["kind"], "rough", "the fresh ones are rough")
	# Each voice has its own files out of the eight, and they differ.
	var sets: Array = []
	for k in a.VOICES:
		var own: Array = a.files_of(k)
		assert_between(own.size(), 3, 4, k)
		assert_false(sets.has(own), k + " is not another's set")
		sets.append(own)


func test_the_dead_say_what_they_do() -> void:
	_look_east_from(_open_spot(6, 1))
	var a = game.audio
	var z: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(4, 0, 0))
	z["state"] = "wander"
	a.pick_t = 0.0
	for s in a.slots:
		s["wait"] = 0.0
	a.tick(0.1)
	assert_eq(a.said.back().slice(0, 2), [z["id"], "idle"])
	var slot: Dictionary = {}
	for s in a.slots:
		if s["z"] == z:
			slot = s
	assert_lte(float(slot["wait"]), 8.0, "the next comes in a few seconds")
	# It starts after you: a call at once, whatever it was waiting for.
	z["state"] = "chase"
	a.tick(0.05)
	assert_eq(a.said.back().slice(0, 2), [z["id"], "notice"])
	assert_gt(float(slot["cut"]), 0.0, "a short call")
	# Then it goes on chasing; at you it bites, short and sharp.
	slot["wait"] = 0.0
	a.tick(0.05)
	assert_eq(a.said.back()[1], "chase")
	z["state"] = "attack"
	slot["wait"] = 0.0
	a.tick(0.05)
	assert_eq(a.said.back()[1], "bite")
	var bite_pitch: float = slot["player"].pitch_scale
	assert_gt(bite_pitch, float(a.voice_of(z)["pitch"]) * 1.05, "a bite is higher than its voice")
	# A blow lands: a grunt at once.
	z["stun"] = 0.6
	a.tick(0.05)
	assert_eq(a.said.back()[1], "hit")
	# The short ones end after their length.
	a.tick(float(a.SAYS["hit"]["cut"]) + 0.01)
	assert_true(bool(slot["fading"]) or not slot["player"].playing)
	# About to run it is silent: its own rasp is heard instead.
	z["state"] = "tell"
	z["stun"] = 0.0
	slot["wait"] = 0.0
	var n: int = a.said.size()
	a.tick(0.05)
	assert_eq(a.said.size(), n)


func test_no_moan_file_comes_twice_in_a_row() -> void:
	_look_east_from(_open_spot(6, 3))
	var a = game.audio
	assert_eq(a.lib["moan"].size(), 8, "the eight shipped moans")
	var one: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(3, 0, 0))
	var two: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(3, 0, 1))
	one["state"] = "chase"
	two["state"] = "chase"
	a.pick_t = 0.0
	for k in range(30):
		for s in a.slots:
			s["wait"] = 0.0
		a.tick(0.05)
	assert_gt(a.said.size(), 30)
	var last: Dictionary = {}
	for k in range(1, a.said.size()):
		var e: Array = a.said[k]
		assert_ne(e[2], a.said[k - 1][2], "not the file just heard")
		if last.has(e[0]):
			assert_ne(e[2], last[e[0]], "nor its own last one")
		last[e[0]] = e[2]


func test_one_in_sight_going_down_breathes_out_and_one_out_of_sight_does_not() -> void:
	var c := _wall_spot()
	_look_east_from(c)
	var a = game.audio
	var seen: Dictionary = game.zombies.spawn("dead", game.lift(c + Vector2i(2, 0), 0))
	var hidden: Dictionary = game.zombies.spawn("dead", game.lift(c + Vector2i(4, 0), 0))
	assert_true(a.in_view(seen["pos"]))
	assert_false(a.in_view(hidden["pos"]))
	for z in [seen, hidden]:
		z["fell_at"] = 0.0
		z["age"] = 1.0   # a second into the fall: every beat is due
	a._tick_falls(game.player.position)
	var fell: Array = []
	for e in a.said:
		if e[1] == "fall":
			fell.append(e[0])
	assert_eq(fell, [seen["id"]], "a breath out only from the one in sight")
	assert_true(a.played.has("fall_hit"), "the fall itself is heard from both")

