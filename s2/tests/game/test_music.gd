extends "res://addons/gut/test.gd"
## Background music (docs/design/briefs/bgm.md): what is picked, when it comes and goes, and that
## no file anywhere is silence. The pieces themselves are not in the repository (bgm.md 9.3); the
## director is run on lengths only.

const Rules = preload("res://game/audio/music_rules.gd")
const Director = preload("res://game/audio/music_director.gd")
const MusicPlayer = preload("res://game/audio/music_player.gd")
const MusicInput = preload("res://game/audio/music_input.gd")
const FieldGame = preload("res://game/field_game.gd")

const STEP: float = 0.25


## Every piece, 150 s long (the trial pieces run 1-3 min).
func _all(length: float = 150.0) -> Dictionary:
	var have := {}
	for song in Rules.SONGS:
		have[song["id"]] = length
	return have


func _director(scene: String, have: Dictionary) -> Director:
	var d := Director.new()
	d.start(scene, have, 7)
	return d


func _run(d: Director, seconds: float, s: Dictionary) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		d.tick(STEP, s)
		t += STEP


func _plays(d: Director) -> Array:
	return d.log.filter(func(c: Dictionary) -> bool: return c["do"] == "play")


func _day() -> Dictionary:
	return {"band": "day", "weathers": ["overcast"], "season": "late_autumn"}


## A warm, fed, quiet day on the train.
func _calm_train() -> Dictionary:
	return {"fear": 10, "tension": 20, "coal": 80, "food": 80, "hunger": 0, "stranded": false,
		"warmth": [72, 75, 70], "ration": [70, 70, 68], "night": false}


func _with(base: Dictionary, more: Dictionary) -> Dictionary:
	var out := base.duplicate()
	out.merge(more, true)
	return out


# --- threat --------------------------------------------------------------------------------

func test_what_comes_at_you_weighs_far_more_than_what_is_only_seen() -> void:
	assert_eq(Rules.threat_stage({"seen": 9}), 0, "nine standing in sight: no threat music")
	assert_eq(Rules.threat_stage({"seen": 30}), 1, "a crowd only seen tops out at stage 1")
	assert_eq(Rules.threat_stage({"coming_far": 1, "seen": 1}), 0)
	assert_eq(Rules.threat_stage({"coming_near": 1, "seen": 1}), 1, "one coming near")
	assert_eq(Rules.threat_stage({"coming_near": 2, "seen": 2}), 2, "two coming near: chased")
	assert_eq(Rules.threat_stage({"coming_near": 4, "seen": 4}), 3)
	assert_eq(Rules.threat_stage({"grabbed": true}), 3, "grabbed is stage 3 at once")
	assert_eq(Rules.threat_stage({"on_top": 1, "coming_near": 1, "seen": 1}), 3, "one within 3 m")
	assert_eq(Rules.threat_stage({"horde": true}), 4, "a horde arriving")
	assert_eq(Rules.threat_stage({"pressure": 1.0}), 1, "the horde rim alone, full: stage 1")


func test_threat_music_comes_at_once_and_goes_slowly() -> void:
	var d := _director("field", _all())
	_run(d, 1.0, _day())
	d.tick(STEP, _with(_day(), {"coming_near": 2, "seen": 2}))
	var plays := _plays(d)
	assert_eq(plays.size(), 1, "the chase piece starts the same tick")
	assert_eq(plays[0]["id"], "BGM14_THREAT_CHASE")
	assert_lte(float(plays[0]["fade"]), 1.0, "on the next beat, within a second")
	# It is over: nothing in sight. The music holds 20 s before stepping down.
	_run(d, 19.5, _day())
	assert_eq(d.stage, 2, "still held at 19.5 s")
	_run(d, 1.0, _day())
	assert_eq(d.stage, 1, "a stage down after the hold")
	assert_eq(_plays(d)[-1]["id"], "BGM13_THREAT_SEEN", "down to the seen piece")
	assert_gte(float(_plays(d)[-1]["fade"]), 8.0, "stepping down fades 8-12 s")
	_run(d, Director.STEP, _day())
	assert_eq(d.stage, 0, "and the next stage after one more step")
	assert_eq(d.playing, "", "the threat piece fades out")


func test_a_threat_longer_than_its_piece_plays_it_again_at_once() -> void:
	var d := _director("field", _all(115.0))
	_run(d, 116.0 + STEP, _with(_day(), {"coming_near": 2, "seen": 2}))
	var chase := _plays(d).filter(func(c: Dictionary) -> bool: return c["id"] == "BGM14_THREAT_CHASE")
	assert_eq(chase.size(), 2, "the chase piece again when it runs out")
	assert_lte(float(chase[1]["fade"]), 1.0, "no 10 s dip in the middle of a chase")
	assert_lt(float(chase[1]["t"]) - 115.0, 0.5, "with no gap")


func test_a_stage_is_kept_at_least_eight_seconds() -> void:
	var d := _director("field", _all())
	d.tick(STEP, _with(_day(), {"coming_near": 2, "seen": 2}))
	var since := d.now
	# Flickering at the edge: the stage does not drop before its minimum, even past the hold.
	for i in range(200):
		d.tick(STEP, _day() if i % 2 == 0 else _with(_day(), {"coming_near": 2, "seen": 2}))
	assert_eq(d.stage, 2, "an on-off threat keeps the stage")
	_run(d, Director.HOLD + 0.5, _day())
	assert_eq(d.stage, 1)
	assert_gte(d.stage_since - since, Director.MIN_STAGE)


func test_released_from_a_grab_goes_straight_back_to_the_chase() -> void:
	var d := _director("field", _all())
	d.tick(STEP, _with(_day(), {"grabbed": true, "coming_near": 1, "seen": 1}))
	assert_eq(d.stage, 3)
	assert_almost_eq(d.db, Director.GAIN["threat_chase"] + Director.ON_TOP_DB, 0.01, "on you: only the pulse, lower")
	_run(d, Director.MIN_STAGE, _with(_day(), {"grabbed": true, "coming_near": 1, "seen": 1}))
	_run(d, 0.5, _with(_day(), {"coming_near": 2, "seen": 2}))
	assert_eq(d.stage, 2, "no 20 s hold after a grab")
	assert_almost_eq(d.db, Director.GAIN["threat_chase"], 0.01, "the chase comes back up")


func test_after_a_horde_no_explore_piece_for_ninety_seconds() -> void:
	var d := _director("field", _all())
	_run(d, 60.0, _day())
	d.tick(STEP, _with(_day(), {"horde": true}))
	assert_eq(_plays(d)[-1]["id"], "BGM15_THREAT_HORDE")
	_run(d, 30.0, _with(_day(), {"horde": true}))
	_run(d, Director.HOLD + 1.0, _day())
	assert_eq(d.stage, 0, "the horde is gone after its hold")
	var gone := d.now
	_run(d, Director.HORDE_REST - 1.0, _day())
	assert_eq(d.playing, "", "quiet for 90 s")
	assert_true(_plays(d).filter(func(c: Dictionary) -> bool: return c["t"] > gone).is_empty())


# --- the quiet between pieces --------------------------------------------------------------

func test_the_stop_opens_without_music_and_pieces_have_quiet_between() -> void:
	var d := _director("field", _all())
	_run(d, Director.READ_BEAT - 0.5, _day())
	assert_eq(_plays(d).size(), 0, "the reading beat has no music")
	_run(d, 1.0, _day())
	assert_eq(_plays(d).size(), 1, "then a piece")
	assert_eq(_plays(d)[0]["id"], "BGM08_FIELD_DAY_A", "the late-autumn grey day piece fits best")
	assert_almost_eq(float(_plays(d)[0]["db"]), Director.GAIN["explore"], 0.01, "under the effects bed")
	_run(d, 150.0 + float(Director.GAP[0]) - 1.0, _day())
	assert_eq(_plays(d).size(), 1, "at least 60 s of quiet after a piece")


func test_night_and_a_clear_day_leave_longer_quiet() -> void:
	var day := _director("field", {})
	var night := _director("field", {})
	var clear := _director("field", {})
	for i in range(200):
		var g := day.gap(_day())
		assert_between(g, 60.0, 180.0)
		assert_between(night.gap(_with(_day(), {"band": "night"})), 90.0, 270.0)
		assert_between(clear.gap(_with(_day(), {"weathers": ["clear"]})), 120.0, 360.0)


func test_music_is_on_for_at_most_half_a_long_stop() -> void:
	for length in [60.0, 150.0, 180.0]:
		var d := _director("field", _all(length))
		_run(d, 20.0 * 60.0, _day())
		assert_gt(d.music_t, 0.0, "some music in 20 min")
		assert_lte(d.music_t / d.scene_t, Director.MAX_SHARE + 0.01, "music %d s pieces: at most half" % int(length))


func test_the_chase_crosses_the_explore_piece_out() -> void:
	var d := _director("field", _all())
	_run(d, Director.READ_BEAT + 1.0, _day())
	var explore := d.playing
	assert_ne(explore, "")
	d.tick(STEP, _with(_day(), {"coming_near": 2, "seen": 2}))
	var fades: Array = d.log.filter(func(c: Dictionary) -> bool: return c["do"] == "fade" and c["id"] == explore)
	assert_eq(fades.size(), 1, "the explore piece goes as the chase comes")
	assert_lte(float(fades[0]["fade"]), 1.0)
	assert_eq(d.playing, "BGM14_THREAT_CHASE")


func test_a_blizzard_has_no_explore_piece_but_threat_music_still_comes() -> void:
	var d := _director("field", _all())
	var storm := _with(_day(), {"weathers": ["blizzard"]})
	_run(d, 300.0, storm)
	assert_eq(_plays(d).size(), 0, "the wind is the music")
	d.tick(STEP, _with(storm, {"coming_near": 2, "seen": 2}))
	assert_eq(_plays(d)[-1]["id"], "BGM14_THREAT_CHASE")


func test_indoors_the_piece_goes_down_three_db() -> void:
	var d := _director("field", _all())
	_run(d, Director.READ_BEAT + 1.0, _day())
	assert_almost_eq(d.db, Director.GAIN["explore"], 0.01)
	d.tick(STEP, _with(_day(), {"indoor": true}))
	assert_almost_eq(d.db, Director.GAIN["explore"] + Director.INDOOR_DB, 0.01)
	d.tick(STEP, _day())
	assert_almost_eq(d.db, Director.GAIN["explore"], 0.01, "back out, back up")


func test_cellar_and_night_pick_their_own_pieces() -> void:
	var rng := RandomNumberGenerator.new()
	var have := _all()
	assert_eq(Rules.pick("explore", have, _with(_day(), {"under": true}), "", rng), "BGM12_FIELD_NIGHT_B")
	assert_eq(Rules.pick("explore", have, {"band": "night", "weathers": ["fog"], "season": "early_winter"}, "", rng), "BGM11_FIELD_NIGHT_A")
	assert_eq(Rules.pick("explore", have, {"band": "day", "weathers": ["snow"], "season": "deep_winter"}, "", rng), "BGM10_FIELD_DAY_C")
	assert_ne(Rules.pick("explore", have, _day(), "", rng), "BGM12_FIELD_NIGHT_B", "no cellar piece above ground")


func test_the_piece_just_heard_is_not_picked_again() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var have := _all()
	var last := ""
	for i in range(60):
		var id := Rules.pick("title", have, {}, last, rng)
		assert_ne(id, last)
		last = id
	assert_eq(Rules.pick("title", {"BGM02_TITLE_B": 180.0}, {}, "BGM02_TITLE_B", rng), "BGM02_TITLE_B", "unless it is the only one")


# --- the train -----------------------------------------------------------------------------

func test_the_hearth_piece_only_when_warm_and_fed() -> void:
	var calm := _calm_train()
	assert_eq(Rules.train_row(calm), "hearth")
	assert_eq(Rules.train_row(_with(calm, {"coal": 15})), "cold", "the coal is gone: not the hearth")
	assert_eq(Rules.train_row(_with(calm, {"stranded": true})), "cold", "a train stood for want of coal")
	assert_eq(Rules.train_row(_with(calm, {"warmth": [20, 25, 70]})), "cold", "most cars freezing")
	assert_eq(Rules.train_row(_with(calm, {"coal": 45})), "none", "coal not rich: plain cars, no hearth")
	assert_eq(Rules.train_row(_with(calm, {"warmth": [72, 40, 70]})), "none", "one cold car: no hearth")
	assert_eq(Rules.train_row(_with(calm, {"hunger": 1})), "hunger")
	assert_eq(Rules.train_row(_with(calm, {"ration": [30, 40, 35]})), "hunger", "rations under the low line")
	assert_eq(Rules.train_row(_with(calm, {"tension": 45})), "none", "restless: no hearth")
	assert_eq(Rules.train_row(_with(calm, {"tension": 60})), "tension")
	assert_eq(Rules.train_row(_with(calm, {"riot": "protest"})), "tension")
	assert_eq(Rules.train_row(_with(calm, {"night": true})), "night")


func test_the_train_rows_go_in_their_order() -> void:
	var calm := _calm_train()
	var all_bad := _with(calm, {"fear": 85, "crisis": true, "coal": 10, "hunger": 2, "tension": 80, "night": true})
	assert_eq(Rules.train_row(all_bad), "fear", "the fearful hush beats everything")
	assert_eq(Rules.train_row(_with(all_bad, {"fear": 79})), "crisis")
	assert_eq(Rules.train_row(_with(all_bad, {"fear": 79, "crisis": false})), "cold", "cold before hunger")
	assert_eq(Rules.train_row(_with(all_bad, {"fear": 79, "crisis": false, "coal": 60})), "hunger")
	assert_eq(Rules.train_row(_with(all_bad, {"fear": 79, "crisis": false, "coal": 60, "hunger": 0})), "tension")
	assert_eq(Rules.row_kind("fear"), "", "no music under the fearful hush")
	assert_eq(Rules.row_kind("none"), "")


func test_going_worse_fades_the_piece_in_three_seconds_and_better_lets_it_play_out() -> void:
	var d := _director("train", _all())
	d.tick(STEP, _calm_train())
	assert_eq(d.playing, "BGM04_TRAIN_A", "a calm warm day: the hearth piece")
	_run(d, 30.0, _calm_train())
	d.tick(STEP, _with(_calm_train(), {"coal": 10}))
	var fade: Dictionary = d.log.filter(func(c: Dictionary) -> bool: return c["do"] == "fade")[-1]
	assert_eq(fade["id"], "BGM04_TRAIN_A")
	assert_almost_eq(float(fade["fade"]), Director.WORSE_FADE, 0.01, "out in 3 s")
	assert_eq(d.playing, "BGM20_TRAIN_COLD", "the cold piece at once")
	# The coal comes back: the cold piece plays to its end, then quiet, then the hearth.
	var started := d.now
	_run(d, 60.0, _calm_train())
	assert_eq(d.playing, "BGM20_TRAIN_COLD", "better: played out, not cut")
	_run(d, 150.0 - 60.0, _calm_train())
	assert_eq(d.playing, "", "then the quiet")
	_run(d, Director.GAP[1], _calm_train())
	assert_eq(_plays(d)[-1]["id"], "BGM04_TRAIN_A")
	assert_gte(float(_plays(d)[-1]["t"]) - started, 150.0 + float(Director.GAP[0]))


func test_fear_takes_the_music_away() -> void:
	var d := _director("train", _all())
	d.tick(STEP, _with(_calm_train(), {"night": true}))
	assert_eq(d.playing, "BGM05_TRAIN_B")
	d.tick(STEP, _with(_calm_train(), {"night": true, "fear": 85}))
	assert_eq(d.playing, "", "the fearful hush")
	_run(d, 600.0, _with(_calm_train(), {"night": true, "fear": 85}))
	assert_eq(d.playing, "", "and nothing comes while it lasts")


func test_a_car_song_keeps_the_train_piece_back() -> void:
	var d := _director("train", _all())
	d.tick(STEP, _calm_train())
	d.tick(STEP, _with(_calm_train(), {"car_song": true}))
	assert_almost_eq(d.db, Director.CAR_SONG_DB, 0.01, "12 dB under a car's own song")
	var quiet := _director("train", _all())
	_run(quiet, 300.0, _with(_calm_train(), {"car_song": true}))
	assert_eq(_plays(quiet).size(), 0, "no new piece starts over a song")


# --- no files ------------------------------------------------------------------------------

func test_no_file_anywhere_is_silence() -> void:
	var d := _director("field", {})
	_run(d, 600.0, _with(_day(), {"coming_near": 3, "seen": 3}))
	d.cue("loss")
	_run(d, 10.0, _with(_day(), {"horde": true}))
	assert_eq(d.log.size(), 0, "nothing to play: nothing said")
	var t := _director("train", {})
	_run(t, 300.0, _calm_train())
	assert_eq(t.log.size(), 0)


func test_the_repository_holds_no_piece_and_the_player_runs_silent() -> void:
	assert_true(MusicPlayer.find_files(["res://audio/music"]).is_empty(), "no piece in the repository until the user picks (bgm.md 9.3)")
	var p := MusicPlayer.new()
	add_child_autofree(p)
	p.setup("field", null, ["res://audio/music_none"])
	assert_true(p.director.have.is_empty())
	for i in range(10):
		p.tick(1.0)
	assert_true(AudioServer.get_bus_index(MusicPlayer.BUS) >= 0, "the Music bus is made")
	assert_false(p.players[0].playing)


func test_a_warning_ducks_harder_than_the_radio() -> void:
	assert_eq(MusicPlayer.duck_target({}), 0.0)
	assert_eq(MusicPlayer.duck_target({"radio": 0.3}), -8.0)
	assert_eq(MusicPlayer.duck_target({"radio": 0.3, "warning": 1.0}), -12.0)
	var p := MusicPlayer.new()
	add_child_autofree(p)
	p.setup("field", null, ["res://audio/music_none"])
	p.duck("warning")
	p.tick(0.2)
	assert_almost_eq(p.duck_db, -12.0, 0.01, "down within 0.1 s")
	for i in range(10):
		p.tick(0.2)
	assert_almost_eq(p.duck_db, 0.0, 0.01, "back after its hold")


# --- the field input -----------------------------------------------------------------------

func test_the_field_reads_only_the_dead_in_sight() -> void:
	seed(20261025)
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	assert_not_null(game.music, "the field has its music")
	var p = game.player
	p.position = game.lift(_open_east(game), 0)
	p.facing = PI * 0.5   # east
	game.cam_size = 36.0
	game.cam_focus = p.position
	game._update_camera(1.0)
	game._refresh_vision()
	var near: Dictionary = game.zombies.spawn("dead", p.position + Vector3(2.0, 0, 0))
	near["state"] = "chase"
	var behind: Dictionary = game.zombies.spawn("dead", p.position + Vector3(-6.0, 0, 0))
	behind["state"] = "chase"
	assert_true(MusicInput.shown(game, near["pos"]), "the one 2 m ahead is in sight")
	assert_false(MusicInput.shown(game, behind["pos"]), "the one behind you is out of sight")
	var s := MusicInput.field(game)
	assert_eq(int(s["seen"]), 1, "the unseen one is not counted")
	assert_eq(int(s["coming_near"]), 1)
	assert_eq(int(s["on_top"]), 1, "2 m is within 3 m")
	assert_false(bool(s["horde"]))
	assert_eq(Rules.threat_stage(s), 3)
	game.music.tick(0.5)


## A ground cell with five open cells east of it, so a map change cannot put a wall in the way.
func _open_east(game) -> Vector2i:
	var g = game.grid
	for y in range(4, g.height - 4):
		for x in range(8, g.width - 8):
			var c := Vector2i(x, y)
			var open := true
			for dx in range(-7, 6):
				if not g.people_can_walk(c + Vector2i(dx, 0)) or g.opaque(c + Vector2i(dx, 0)) or g.indoor(c + Vector2i(dx, 0)):
					open = false
					break
			if open:
				return c
	return Vector2i(60, 7)
