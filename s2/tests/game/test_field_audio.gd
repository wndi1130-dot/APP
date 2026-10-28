extends "res://addons/gut/test.gd"
## Graybox sound (sound_music 12.1): silent with no files, and with files the
## nearest dead get the voices, the crowd raises the bed, actions make noise.

const FieldGame = preload("res://game/field_game.gd")

var game


func before_each() -> void:
	seed(20261024)   # the ear's dice: the same every run, so a check never rides on luck
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


# Past the map's edge the danger is heard: a far bed, louder toward the nearest
# place out there, none beyond EDGE_RANGE.
func test_the_danger_past_the_edge_is_heard_louder_nearer() -> void:
	var a = game.audio
	a._tick_edge(game.player.position, 10.0)
	assert_false(a.edge_spots.is_empty(), "the map's drawing hands the places over")
	a.edge_spots = [Vector3(-30, 0, 60)]
	a._tick_edge(Vector3(2, 0, 60), 10.0)
	var far_db: float = a.edge_bed.volume_db
	a._tick_edge(Vector3(-10, 0, 60), 10.0)
	var near_db: float = a.edge_bed.volume_db
	assert_gt(far_db, -80.0, "32 m from a place past the edge it is heard")
	assert_gt(near_db, far_db, "and louder walking toward it")
	a._tick_edge(Vector3(100, 0, 60), 10.0)
	assert_eq(a.edge_bed.volume_db, -80.0, "past EDGE_RANGE it is gone")


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



# The wind never comes round the same way (user 2026-10-24: 「지금
# 규칙적이니까 귀가피곤함」): the bed wanders, gusts come at uneven gaps, and
# no gust has the shape of the one before.
func test_the_wind_wanders_and_its_gusts_never_come_round_the_same_way() -> void:
	var a = game.audio
	assert_true(a.has("wind"), "the shipped wind file")
	var at: Vector3 = game.player.position
	var levels: Array = []
	var starts: Array = []
	var n0: int = a.gust_log.size()
	for k in range(480):
		a._tick_wind(at, 0.25)
		if k * 0.25 > float(a.WIND_IN[1]):
			levels.append(a.bed_db())   # once it has come in: the wandering, not the coming up
		if a.gust_log.size() > n0 + starts.size():
			starts.append(k * 0.25)
	assert_gt(levels.max() - levels.min(), 2.0, "the bed rises and falls")
	assert_gte(starts.size(), 6, "gusts in two minutes")
	var gaps: Array = []
	for k in range(1, starts.size()):
		gaps.append(snappedf(starts[k] - starts[k - 1], 0.25))
	var distinct: Dictionary = {}
	for g in gaps:
		distinct[g] = true
	assert_gt(distinct.size(), gaps.size() / 2, "the gaps are uneven, no beat")
	for k in range(n0 + 1, a.gust_log.size()):
		var g: Array = a.gust_log[k]
		var before: Array = a.gust_log[k - 1]
		assert_between(float(g[1]), float(a.GUST_LEN[0]), float(a.GUST_LEN[1]))
		assert_ne(String(g[6]), String(before[6]), "not the file just heard")
		assert_gt(absf(float(g[3]) - float(before[3])), a.GUST_PITCH_APART, "nor the pitch")


# Not one wind (결정 434 1절: 「패턴 여러게 + 오프닝 달라지게」): beds of
# their own grain and gusts of their own, a stop never taking the bed the one
# before had, a blizzard its own kind, a howl's layers each from its own file.
func test_the_wind_is_many_and_no_two_stops_running_share_a_bed() -> void:
	var a = game.audio
	assert_gte(a.beds.size(), 6, "five beds of their own and the plain one")
	for name in ["breeze", "gusty", "low", "whistle", "forest", "blizzard"]:
		assert_true(a.beds.has(name), name)
	assert_gte(a.gust_files.size(), 3, "gusts of their own")
	assert_true(a.beds.has(a.bed_name))
	var names: Array = a.beds.keys()
	var last := ""
	var seen: Dictionary = {}
	for i in range(60):
		var b: String = a.pick_bed(names, ["fog", "snow"], 0.4, false, last, randf())
		assert_ne(b, last, "never the bed the stop before had")
		assert_ne(b, "blizzard", "no blizzard's roar on a fog stop")
		assert_ne(b, "plain", "nor the old short loop")
		seen[b] = true
		last = b
	assert_gte(seen.size(), 5, "the stops go round many beds")
	var storm: Dictionary = {}
	for i in range(60):
		storm[a.pick_bed(names, ["blizzard"], 0.9, true, "", randf())] = true
	assert_true(storm.has("blizzard"))
	assert_false(storm.has("breeze"), "no soft breeze in a blizzard")
	assert_false(storm.has("plain"), "nor the old short loop in a blizzard")
	# A new stop takes another bed than this one.
	var was: String = a.bed_name
	var b2 = a.get_script().new()
	game.add_child(b2)
	b2.setup(game)
	assert_ne(b2.bed_name, was, "the next stop opens on another bed")
	b2.queue_free()
	# A howl's layers come from files of their own.
	for g in a.gusts:
		g["len"] = 0.0
	var n: int = a.gust_log.size()
	a.howl()
	var files: Dictionary = {}
	for g in a.gust_log.slice(n):
		files[g[6]] = true
	assert_eq(files.size(), a.gust_log.size() - n, "each layer its own file")


# Nor is the bed a loop (user 2026-10-28: 「지금 루프 형태라싸구려겜같음」): over
# ten minutes its pieces never follow each other the way two like them already
# did, are of uneven length, never go back over the stretch just heard and come
# from more than one file; the gusts come at gaps that scatter, no two running
# alike, at strengths no two running alike, each told to whoever follows them.
func test_ten_minutes_of_wind_never_go_round_in_the_same_order() -> void:
	var a = game.audio
	var at: Vector3 = game.player.position
	var heard: Array = []
	a.gust_started.connect(func(peak: float, length: float, howl: bool) -> void: heard.append([peak, length, howl]))
	var n0: int = a.gust_log.size()
	var log0: int = a.bed_log.size()
	var top := 0.0
	for k in range(6000):
		a._tick_wind(at, 0.1)
		top = maxf(top, a.wind_now())
	var heard_pieces: Array = a.bed_log.slice(log0)
	assert_gt(heard_pieces.size(), 60, "ten minutes is many pieces")
	assert_eq(a.repeats_in(a.bed_log), 0, "no two pieces follow each other as two like them did")
	var files: Dictionary = {}
	var len_sum := 0.0
	var len_sq := 0.0
	var back := 0
	for i in range(heard_pieces.size()):
		var p: Array = heard_pieces[i]
		files[p[0]] = true
		len_sum += float(p[2])
		len_sq += float(p[2]) * float(p[2])
		for j in range(maxi(0, i - 2), i):
			if p[0] == heard_pieces[j][0]:
				var s0: Vector2 = a.piece_span(heard_pieces[j])
				var s1: Vector2 = a.piece_span(p)
				if s1.x < s0.y and s0.x < s1.y:
					back += 1
	assert_eq(back, 0, "no piece goes back over the stretch of the two before it")
	assert_gte(files.size(), 2, "pieces from kin beds too")
	assert_false(files.has("plain"), "never a piece of the old short loop")
	var len_mean: float = len_sum / heard_pieces.size()
	var len_sd: float = sqrt(maxf(0.0, len_sq / heard_pieces.size() - len_mean * len_mean))
	assert_gt(len_sd, 1.0, "pieces of uneven length")
	# The gusts: when, how hard, and told.
	var times: Array = []
	var peaks: Array = []
	for g in a.gust_log.slice(n0):
		if not g[5]:
			times.append(float(g[7]))
			peaks.append(float(g[2]))
	assert_gt(times.size(), 40, "gusts all through")
	assert_eq(heard.size(), a.gust_log.size() - n0, "every gust told")
	assert_gt(top, 0.0, "how hard it blows, for the snow and the trees")
	var gaps: Array = []
	for k in range(1, times.size()):
		gaps.append(times[k] - times[k - 1])
	var mean := 0.0
	for g in gaps:
		mean += g
	mean /= gaps.size()
	var sd := 0.0
	for g in gaps:
		sd += (g - mean) * (g - mean)
	sd = sqrt(sd / gaps.size())
	assert_gt(sd / mean, 0.2, "the gaps scatter: no beat")
	var alike_gaps := 0
	var alike_peaks := 0
	for k in range(1, gaps.size()):
		if absf(gaps[k] - gaps[k - 1]) < 0.3:
			alike_gaps += 1
	for k in range(1, peaks.size()):
		if absf(peaks[k] - peaks[k - 1]) < a.GUST_LOUD_APART - 0.001:
			alike_peaks += 1
	assert_eq(alike_gaps, 0, "no two gaps running alike")
	assert_eq(alike_peaks, 0, "no two gusts running alike in strength")
	gut.p("10 min: %d pieces from %d files, length sd %.2f s, %d repeats; %d gusts, gap CV %.2f, %d gaps and %d strengths alike running" % [heard_pieces.size(), files.size(), len_sd, a.repeats_in(a.bed_log), times.size(), sd / mean, alike_gaps, alike_peaks])


# Near a building's corner the wind is heard from it too, louder as it blows
# harder; on a still day it keeps still.
func test_the_wind_is_heard_from_a_corner_near_by() -> void:
	var a = game.audio
	var places: Dictionary = a.spot_places()
	assert_false(places["corner"].is_empty(), "the map's buildings have corners")
	var stand := Vector3.INF
	for c: Vector3 in places["corner"]:
		for off in [Vector2i(-2, -2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(2, 2)]:
			var cell := Vector2i(int(c.x) + off.x, int(c.z) + off.y)
			if game.grid.people_can_walk(cell) and not game.grid.indoor(cell):
				stand = game.lift(cell, 0)
				break
		if stand != Vector3.INF:
			break
	assert_ne(stand, Vector3.INF, "a corner one can stand by outside")
	game.player.position = stand
	game.weather.wind = 0.9
	for k in range(40):
		a._tick_wind(stand, 0.1)
	var s: AudioStreamPlayer3D = a.spot_players["corner"]
	assert_lte(Vector2(s.position.x - stand.x, s.position.z - stand.z).length(), a.SPOT_RANGE, "heard from a corner near by")
	assert_gt(s.volume_db, -40.0, "whistling in a hard wind")
	game.weather.wind = 0.1
	for k in range(40):
		a._tick_wind(stand, 0.1)
	assert_lte(s.volume_db, -79.0, "still on a still day")


# The field standing still (the resume screen does not tick the ear) while the
# players go on: the next piece comes as the field goes on, not seconds of
# silence after a file ran out under it. A gust never starts so late in its
# file that the file runs out before the gust has died away.
func test_the_wind_goes_on_after_the_field_stood_still_and_no_gust_runs_out() -> void:
	var a = game.audio
	var at: Vector3 = game.player.position
	for k in range(40):
		a._tick_wind(at, 0.1)
	var n: int = a.bed_log.size()
	a.wind_clock_ms = Time.get_ticks_msec() - 8000   # eight seconds with no tick
	a._tick_wind(at, 0.1)
	assert_eq(a.bed_log.size(), n + 1, "the next piece at once")
	a._tick_wind(at, 0.1)
	assert_eq(a.bed_log.size(), n + 1, "and only the one")
	var over := 0
	for k in range(200):
		for g in a.gusts:
			g["len"] = 0.0
		if k % 2 == 0:
			a._gust(randf_range(float(a.GUST_LEN[0]), float(a.GUST_LEN[1])), 0.6, false)
		else:
			a.howl()
	for g in a.gust_log:
		var full: float = a.gust_stream(String(g[6])).get_length()
		if float(g[0]) + float(g[1]) * maxf(float(g[3]), float(g[4])) > full + 0.001:
			over += 1
	assert_eq(over, 0, "no gust runs out of its file")


# Nor does a stop open the same way (user 2026-10-25: 「처음내릴떄 휘오오옹
# 하는거 스타트가 매번똑같은니까」): the bed comes up from nothing over its own
# length, its first loudness and pitch are new, the first gust waits its own time.
func test_getting_down_the_wind_comes_up_its_own_way_each_stop() -> void:
	var at: Vector3 = game.player.position
	var opens: Array = []
	var stop_beds: Array = [game.audio.bed_name]
	for i in range(5):
		var b = game.audio.get_script().new()
		game.add_child(b)
		b.setup(game)
		assert_ne(b.bed_name, stop_beds.back(), "each stop on another bed than the one before")
		stop_beds.append(b.bed_name)
		assert_between(b.wind_in, float(b.WIND_IN[0]), float(b.WIND_IN[1]))
		assert_between(b.gust_t, float(b.FIRST_AFTER[0]), float(b.FIRST_AFTER[1]))
		assert_between(b.howl_wait, float(b.FIRST_AFTER[0]), float(b.FIRST_AFTER[1]))
		var first_gust: float = b.gust_t
		b._tick_wind(at, 1.0 / 60.0)
		assert_lt(b.bed_db(), -30.0, "near silence the moment one gets down")
		var first_pitch: float = b.wind.pitch_scale
		while b.wind_up < b.wind_in:
			b._tick_wind(at, 0.1)
		assert_gt(b.bed_db(), -25.0, "up to its level once it has come in")
		opens.append([snappedf(b.wind_in, 0.01), snappedf(first_gust, 0.01), snappedf(first_pitch, 0.001)])
		b.queue_free()
	var distinct: Dictionary = {}
	for o in opens:
		distinct[str(o)] = true
	assert_eq(distinct.size(), opens.size(), "no two stops open alike")
	var pitches: Dictionary = {}
	for o in opens:
		pitches[o[2]] = true
	assert_gt(pitches.size(), 1, "the first pitch is not the same each stop")


func test_a_stronger_wind_gusts_more_often() -> void:
	var a = game.audio
	var calm: Vector2 = a.gust_gap(0.2)
	var storm: Vector2 = a.gust_gap(1.0)
	assert_lt(storm.y, calm.y)
	assert_lt(storm.x, calm.x)
	game.weather.kinds.append("blizzard")
	assert_gte(a.wind_strength(), 0.9, "a blizzard blows hard whatever the number")


# A blizzard stop comes in with a howl: one to three gusts laid together, a
# new shape each time it is heard, its own few seconds after getting down
# (user 2026-10-25), never the moment one does.
func test_a_blizzard_comes_in_with_a_howl_of_a_new_shape_each_time() -> void:
	var a = game.audio
	game.weather.kinds.append("blizzard")
	var t := 0.0
	while not a.howled and t < float(a.FIRST_AFTER[1]) + 0.5:
		a._tick_wind(game.player.position, 0.1)
		t += 0.1
	assert_true(a.howled)
	assert_between(t, float(a.FIRST_AFTER[0]) - 0.001, float(a.FIRST_AFTER[1]) + 0.2, "a few seconds after getting down")
	var shapes: Array = []
	var first: Array = []
	for g in a.gust_log:
		if g[5]:
			first.append(g)
	assert_between(first.size(), 1, 3, "one to three layers")
	for g in first:
		assert_between(float(g[1]), float(a.HOWL_LEN[0]), float(a.HOWL_LEN[1]))
	shapes.append(first)
	for k in range(4):
		var n: int = a.gust_log.size()
		for g in a.gusts:
			g["len"] = 0.0
		a.howl()
		shapes.append(a.gust_log.slice(n))
	var distinct: Dictionary = {}
	for s in shapes:
		distinct[str(s)] = true
	assert_eq(distinct.size(), shapes.size(), "no two howls alike")
	var howls: int = a.gust_log.filter(func(g): return g[5]).size()
	a._tick_wind(game.player.position, 0.1)
	assert_eq(a.gust_log.filter(func(g): return g[5]).size(), howls, "it howls once as the stop comes in, not over and over")
