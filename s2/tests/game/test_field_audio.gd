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


func test_no_files_is_silence_not_a_crash() -> void:
	for g in game.audio.GROUPS:
		game.audio.lib[g] = []
	game.zombies.spawn("dead", game.player.position + Vector3(3, 0, 0))["state"] = "chase"
	game.audio.tick(0.5)
	game.make_sound(game.player.position, 2, "kick")
	game.audio.horde_started()
	assert_eq(game.audio.last_tag_group, "impact")
	assert_true(AudioServer.get_bus_index("SFX") >= 0, "SFX bus made")


func test_the_six_nearest_dead_get_voices() -> void:
	game.audio.lib["moan"] = [_tone()]
	var dead: Array = []
	for i in range(9):
		var z: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(2.0 + i * 2.0, 0, 0))
		z["state"] = "chase"
		dead.append(z)
	game.audio.pick_t = 0.0
	game.audio.tick(0.1)
	var voiced: Array = []
	for s in game.audio.slots:
		if not s["z"].is_empty():
			voiced.append(s["z"])
	assert_eq(voiced.size(), 6)
	for i in range(6):
		assert_true(voiced.has(dead[i]), "nearest first")
	assert_false(voiced.has(dead[8]))


func test_a_bigger_nearer_crowd_is_a_louder_bed() -> void:
	game.audio._assign_moans(game.player.position)
	var none: float = game.audio.crowd
	for i in range(10):
		game.zombies.spawn("dead", game.player.position + Vector3(5, 0, i * 0.5))["state"] = "horde"
	game.audio._assign_moans(game.player.position)
	assert_gt(game.audio.crowd, none + 5.0)


func test_noises_pick_their_sound() -> void:
	var a = game.audio
	a.on_sound(game.player.position, 3, "whistle")
	assert_eq(a.last_tag_group, "whistle")
	a.lib["gun"] = []
	a.on_sound(game.player.position, 2, "gun")
	assert_eq(a.last_tag_group, "impact", "shots fall back to an impact")
	a.on_sound(game.player.position, 1, "smoke")
	assert_eq(a.last_tag_group, "")


func test_a_horde_setting_off_gathers_far_moans() -> void:
	game.audio.horde_started()
	assert_gt(game.audio.gather_t, 0.0)


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
	for g in ["moan", "horde_bed", "gather", "birds", "impact", "gun", "step_snow", "wind", "train_idle", "whistle", "pen"]:
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
	var heard: Dictionary = {}
	for d in [3.0, 12.0, 22.0]:
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
	assert_eq(String(by[22.0].bus), "SFX_FAR")
	# The bands do not overlap: the lowest near moan is above the highest far one.
	assert_gt(0.85 * float(a.moan_band(3.0)[1]), 1.1 * float(a.moan_band(22.0)[1]))
	assert_gte(by[3.0].pitch_scale, 0.85)
	assert_lte(by[22.0].pitch_scale, 1.1 * 0.75 + 0.001)
	assert_lt(by[22.0].volume_db, by[3.0].volume_db, "and quieter, as before")

