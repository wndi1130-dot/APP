extends "res://addons/gut/test.gd"
## The sound levels in the settings (결정 448): 전체·음악·효과·목소리, a bus each, heard at once and
## kept between runs; the music's ducking never moves the player's music level.

const SoundLevels = preload("res://game/audio/sound_levels.gd")
const SoundRows = preload("res://game/ui/sound_rows.gd")
const MusicPlayer = preload("res://game/audio/music_player.gd")
const FieldGame = preload("res://game/field_game.gd")

const TEST_FILE: String = "user://sound_test.cfg"


func before_each() -> void:
	DirAccess.remove_absolute(TEST_FILE)
	SoundLevels.where = TEST_FILE


func after_each() -> void:
	SoundLevels.apply({})
	DirAccess.remove_absolute(TEST_FILE)
	SoundLevels.where = SoundLevels.FILE


func _db(bus: String) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))


func test_every_bus_is_there_with_its_send() -> void:
	SoundLevels.ensure_buses()
	for bus in ["Music", "SFX", "Voice"]:
		var i := AudioServer.get_bus_index(bus)
		assert_true(i >= 0, bus)
		assert_eq(String(AudioServer.get_bus_send(i)), "Master", bus + " goes to Master")
	for dull in ["SFX_MID", "SFX_FAR"]:
		assert_eq(String(AudioServer.get_bus_send(AudioServer.get_bus_index(dull))), "SFX", dull + " is under 효과")


func test_nothing_saved_is_full_and_a_move_is_heard_and_kept() -> void:
	for bus in SoundLevels.BUSES:
		assert_eq(int(SoundLevels.load_levels()[bus]), 100)
	SoundLevels.set_level("Music", 50)
	assert_almost_eq(_db("Music"), linear_to_db(0.5), 0.01, "half is heard at once")
	assert_eq(int(SoundLevels.load_levels()["Music"]), 50, "and kept")
	assert_eq(int(SoundLevels.load_levels()["SFX"]), 100, "the others as they were")
	SoundLevels.set_level("Voice", 0)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Voice")), "0 is off")
	SoundLevels.set_level("Master", 47)
	assert_eq(int(SoundLevels.load_levels()["Master"]), 50, "steps of 10")
	SoundLevels.apply({})
	SoundLevels.apply_saved()
	assert_almost_eq(_db("Music"), linear_to_db(0.5), 0.01, "the next run comes back to it")


func test_the_music_ducks_its_players_not_the_players_music_level() -> void:
	SoundLevels.set_level("Music", 60)
	var p := MusicPlayer.new()
	add_child_autofree(p)
	p.setup("field", null, ["res://audio/music_none"])
	assert_almost_eq(_db("Music"), linear_to_db(0.6), 0.01, "the setup keeps the saved level")
	p.duck("warning")
	for i in range(3):
		p.tick(0.2)
	assert_almost_eq(p.duck_db, -12.0, 0.01)
	assert_almost_eq(_db("Music"), linear_to_db(0.6), 0.01, "the bus stays where the player put it")


func test_the_rows_show_the_levels_and_a_bar_moves_its_bus() -> void:
	SoundLevels.set_level("SFX", 70)
	var rows := SoundRows.make()
	add_child_autofree(rows)
	assert_eq(rows.get_child_count(), 4, "전체, 음악, 효과, 목소리")
	var sfx := rows.get_node("SFX")
	assert_eq((sfx.get_node("Bar") as HSlider).value, 70.0)
	assert_eq((sfx.get_node("Value") as Label).text, "70%")
	var music := rows.get_node("Music")
	(music.get_node("Bar") as HSlider).value = 0
	assert_eq((music.get_node("Value") as Label).text, "끔")
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
	assert_eq(int(SoundLevels.load_levels()["Music"]), 0, "kept")
	for bus in SoundLevels.BUSES:
		var bar := rows.get_node(bus).get_node("Bar") as HSlider
		assert_gte(bar.custom_minimum_size.y, 44.0, "a finger's height")


func test_the_settings_pane_has_the_sound_rows() -> void:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.hud.settings_panel()
	var rows: Node = game.hud.find_child("SoundRows", true, false)
	assert_not_null(rows, "the pause screen's settings show the sound rows")
	if rows != null:
		assert_eq(rows.get_child_count(), 4)
