extends "res://addons/gut/test.gd"
## The brakes are a sound the dead hear (decision 494): those
## within its reach come to the train in the first minutes and the train
## holds them; it pulls no horde earlier, and skipping the scene of the train
## rolling in changes nothing.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const HordeDirector = preload("res://game/sim/horde_director.gd")
const ArrivalHorde = preload("res://game/sim/arrival_horde.gd")
const SeasonTable = preload("res://game/season_table.gd")
const TrainGuard = preload("res://game/sim/train_guard.gd")


func _game(extra: Dictionary = {}):
	var game = FieldGame.new()
	var opts := {"seed": 7, "raiders": false, "auto_pause": false}
	opts.merge(extra, true)
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	return game


func _run(game, seconds: float, step: float = 0.1) -> void:
	var t := 0.0
	while t < seconds and not game.ended:
		game._step(step)
		t += step


func test_nearby_dead_come_and_all_arrivals_are_inside_far_reach() -> void:
	var game = _game()
	var g = game.train_guard
	assert_true(g.done)
	var reach: float = ArrivalHorde.reach(game.weather.sound_mult(false))
	var far: float = ArrivalHorde.far_reach(game.weather.sound_mult(false))
	assert_gt(g.heard, 0, "the first leg's yard has dead by its engine")
	for z in game.zombies.list:
		var d: float = (z["pos"] as Vector3).distance_to(g.spot)
		if z.get("arrival", false):
			assert_lt(d, far)
			assert_eq(z["state"], "investigate")
		elif z["state"] == "wander" and game.level_of(z["pos"]) == 0:
			assert_gt(d, reach, "one within reach on the ground that did not hear it")


func _brake_game(form: String = "remote"):
	var game = _game({"place": "bare_line_01", "arrival_horde": false, "arrive": false, "weather": ["clear"], "stop_form": form})
	game.zombies.list.clear()
	game.zombies.next_id = 1
	game.pending_spawn.clear()
	game.weather.wind = 0.0
	return game


func _dead_at(game, d: float, state: String = "wander", level: int = 0) -> Dictionary:
	var spot := FieldGrid.center(game.data["anchors"]["whistle"])
	var z: Dictionary = game.zombies.spawn("frozen" if state == "frozen" else "dead", spot + Vector3(d, game.level_y(level), 0.0))
	z["state"] = state
	return z


func test_chance_fades_linearly_and_weather_scales_both_ends() -> void:
	assert_eq(ArrivalHorde.reach(), 35.0)
	assert_eq(ArrivalHorde.far_reach(), 250.0)
	for mult in [0.5, 1.0, 1.5]:
		assert_eq(ArrivalHorde.chance(35.0 * mult, mult), 1.0)
		assert_almost_eq(ArrivalHorde.chance(142.5 * mult, mult), 0.5, 0.0001)
		assert_eq(ArrivalHorde.chance(250.0 * mult, mult), 0.0)
		assert_eq(ArrivalHorde.chance(251.0 * mult, mult), 0.0)
	for id in range(1, 101):
		assert_true(ArrivalHorde.attracted(35.0, 7, id))
		assert_false(ArrivalHorde.attracted(250.0, 7, id))


func test_nearby_dead_ignore_the_cap_and_the_far_boundary_calls_none() -> void:
	var game = _brake_game()
	var most := ArrivalHorde.cap(game.journey_progress)
	var nearby: Array = []
	for i in range(most + 2):
		nearby.append(_dead_at(game, 10.0 + i))
	var blocked := _dead_at(game, 50.0)
	var edge := _dead_at(game, ArrivalHorde.FAR_M)
	# Past the far reach and walking to another sound: not the brakes' to bring.
	var outside := _dead_at(game, ArrivalHorde.FAR_M + 1.0, "investigate")
	outside["target"] = outside["pos"] + Vector3(10.0, 0.0, 0.0)
	var before := [blocked.duplicate(true), edge.duplicate(true), outside.duplicate(true)]
	var frozen := _dead_at(game, 10.0, "frozen")
	game.train_guard.brake()
	for z: Dictionary in nearby:
		assert_true(z.get("arrival", false))
		assert_eq(z["state"], "investigate")
	assert_eq(game.train_guard.heard, most + 2)
	assert_eq([blocked, edge, outside], before)
	assert_eq(frozen["state"], "waking", "nearby frozen dead still wake")
	assert_eq(game.train_guard.filled, 0)
	assert_eq(game.train_guard.fill_due.size(), 0)


## Decision 498 (코디 10-29): the line's zero is the first stop's own place along the
## journey (its season stretch), not the journey's start.
func test_the_cap_grows_along_the_journey_from_eight_to_thirty() -> void:
	assert_almost_eq(ArrivalHorde.first_progress(), 1.0 / 23.0, 0.000001, "the fifth of 24 stretches, in the first of four acts")
	assert_eq(ArrivalHorde.cap(ArrivalHorde.first_progress()), 8, "the first stop: as many as before")
	assert_eq(ArrivalHorde.cap(0.0), 8, "before it no fewer")
	# The first leg's stops stand on the table's stretches 5, 10, 11, 13 and 23 (54-287 km).
	var caps: Array = []
	for row: int in [5, 10, 11, 13, 23]:
		caps.append(ArrivalHorde.cap(SeasonTable.seg_progress(row) / 4.0))
	assert_eq(caps, [8, 9, 10, 10, 13])
	assert_eq(ArrivalHorde.cap(0.5), 19, "the second act sets out")
	assert_eq(ArrivalHorde.cap(1.0), 30, "the journey's end")
	assert_eq(ArrivalHorde.cap(2.0), 30, "never over thirty")
	var game = _game({"place": "bare_line_01", "arrival_horde": false, "arrive": false, "act": "act2", "act_progress": 0.5})
	assert_almost_eq(game.journey_progress, 0.625, 0.0001, "two acts done and half the third of four")
	assert_eq(ArrivalHorde.cap(game.journey_progress), 21)


func test_far_boundary_is_silent_with_room_under_the_cap() -> void:
	var game = _brake_game()
	_dead_at(game, ArrivalHorde.FAR_M)
	_dead_at(game, ArrivalHorde.FAR_M + 1.0)
	var before: Array = game.zombies.list.duplicate(true)
	game.train_guard.brake()
	assert_eq(game.train_guard.heard, 0)
	assert_eq(game.zombies.list, before)


func test_far_calls_repeat_by_seed_and_id_and_leave_misses_unchanged() -> void:
	var a = _brake_game()
	var b = _brake_game()
	for i in range(80):
		_dead_at(a, 142.5)
		_dead_at(b, 142.5)
	var before: Array = a.zombies.list.duplicate(true)
	b.zombies.list.reverse()
	for i in range(17):
		b.rng.randf()
	a.train_guard.brake()
	b.train_guard.brake()
	assert_gt(a.train_guard.heard, 0)
	assert_lte(a.train_guard.heard, ArrivalHorde.cap(a.journey_progress))
	assert_eq(a.train_guard.heard, b.train_guard.heard)
	assert_eq(a.ledger.history.size(), 1)
	assert_eq(a.ledger.by_action["train_brake"]["reactions"], 0, "far calls stay out of the sound ledger")
	assert_eq(a.ledger.by_action["train_brake"]["max_radius"], ArrivalHorde.reach())
	for i in range(a.zombies.list.size()):
		var z: Dictionary = a.zombies.list[i]
		var other: Dictionary = b.zombies.find(int(z["id"]))
		assert_eq(z.get("arrival", false), other.get("arrival", false))
		assert_eq(z["target"], other["target"])
		if not z.get("arrival", false):
			assert_eq(z, before[i], "a missed roll or a full cap changes nothing")


## Choose successful rolls so this test isolates distance and id ordering.
func _willing(game, d: float, first_id: int) -> Dictionary:
	var z := _dead_at(game, d)
	var id := first_id
	while not ArrivalHorde.attracted(d, game.rng.seed, id):
		id += 1
	z["id"] = id
	return z


func test_far_cap_takes_nearer_dead_then_lower_ids() -> void:
	var game = _brake_game()
	var most := ArrivalHorde.cap(game.journey_progress)
	for i in range(most - 2):
		_dead_at(game, 10.0)
	var farther := _willing(game, 90.0, 100)
	var first := _willing(game, 50.0, int(farther["id"]) + 1)
	var second := _willing(game, 50.0, int(first["id"]) + 1)
	var third := _willing(game, 50.0, int(second["id"]) + 1)
	game.zombies.list.reverse()
	game.train_guard.brake()
	assert_eq(game.train_guard.heard, most)
	assert_true(first.get("arrival", false))
	assert_true(second.get("arrival", false))
	assert_false(third.get("arrival", false))
	assert_false(farther.get("arrival", false))


func test_far_hearing_keeps_ignored_states_frozen_bodies_and_other_floors() -> void:
	var game = _brake_game()
	for state in ["dead", "rising", "downed", "grab", "attack", "climb", "tell", "waking", "chase", "frozen"]:
		_dead_at(game, 50.0, state)
	_dead_at(game, 100.0, "wander", 2)
	var loud := _dead_at(game, 50.0, "investigate")
	loud["clue"] = SimNoise.Level.VERY_LOUD
	loud["target"] = loud["pos"] + Vector3(10.0, 0.0, 0.0)
	var missed := _dead_at(game, 142.5)
	while ArrivalHorde.attracted(142.5, game.rng.seed, int(missed["id"])):
		missed["id"] += 1
	var before: Array = game.zombies.list.duplicate(true)
	game.train_guard.brake()
	assert_eq(game.zombies.list, before)
	assert_eq(game.train_guard.heard, 0)


func test_far_hearing_uses_the_floor_gate_of_hear_and_no_wind_as_the_near_brake() -> void:
	var game = _brake_game()
	var spot := FieldGrid.center(game.data["anchors"]["whistle"])
	var z := _dead_at(game, 180.0, "wander", 1)
	var d: float = spot.distance_to(z["pos"])
	while not ArrivalHorde.attracted(d, game.rng.seed, int(z["id"])):
		z["id"] += 1
	assert_false(game.zombies.can_hear(z, spot, ArrivalHorde.FAR_M), "a floor between halves the far reach")
	game.weather.wind = 1.0
	game.weather.wind_dir = Vector2(1.0, 0.0)
	var before := z.duplicate(true)
	game.train_guard.brake()
	assert_false(z.get("arrival", false), "the wind carries the brakes no farther, as for the near ones")
	assert_eq(z, before)


func test_everyone_the_brakes_called_comes_however_far() -> void:
	var game = _brake_game()
	var spot := FieldGrid.center(game.data["anchors"]["whistle"])
	# As if a sewer by the engine had rung the brakes through the map: called at 120 m.
	var z := _dead_at(game, 120.0, "investigate")
	z["target"] = spot
	z["clue"] = SimNoise.Level.VERY_LOUD
	game.train_guard.brake()
	assert_true(z.get("arrival", false), "called by the brakes: the guards' to put down")


func test_upstairs_the_pull_fades_by_the_same_rule_from_half_the_reach() -> void:
	var game = _brake_game()
	var z := _dead_at(game, 20.0, "wander", 1)
	var d: float = FieldGrid.center(game.data["anchors"]["whistle"]).distance_to(z["pos"])
	while not ArrivalHorde.attracted(d, game.rng.seed, int(z["id"]), 0.5):
		z["id"] += 1
	game.train_guard.brake()
	assert_true(z.get("arrival", false), "a floor up, 20 m off: past the halved near reach, still pulled")
	assert_almost_eq(ArrivalHorde.chance(20.0, 0.5), (125.0 - 20.0) / (125.0 - 17.5), 0.0001)
	assert_gt(ArrivalHorde.chance(20.0, 0.5), ArrivalHorde.chance(36.0, 0.5), "nearer upstairs is likelier, never the other way")


func test_a_remote_halt_with_none_heard_fills_none() -> void:
	var game = _brake_game("remote")
	game.train_guard.brake()
	assert_eq(game.train_guard.heard, 0)
	assert_eq(game.train_guard.filled, 0)
	assert_eq(TrainGuard.auto("houses", 2, 7, "remote")["killed"], 0, "nobody out at a remote halt: no bodies at the train")


func test_remote_fills_none_and_edge_fills_half_rounded_down() -> void:
	for kind in ["houses", "mine", "unknown"]:
		var least := int(ArrivalHorde.band(kind)[0])
		var half := floori(float(least) * 0.5)
		assert_eq(ArrivalHorde.fill(0, kind, "remote"), 0)
		assert_eq(ArrivalHorde.auto_bodies(kind, "remote").size(), 0)
		assert_eq(ArrivalHorde.fill(0, kind, "edge"), half)
		assert_eq(ArrivalHorde.fill(1, kind, "edge"), maxi(half - 1, 0))
		assert_eq(ArrivalHorde.auto_bodies(kind, "edge").size(), half)
		assert_eq(ArrivalHorde.fill(0, kind), least)
	var edge = _brake_game("edge")
	edge.train_guard.brake()
	assert_eq(edge.train_guard.filled, floori(float(ArrivalHorde.band(String(edge.data["place_kind"]))[0]) * 0.5))


## Decision 416 (코디 10-29): what the brakes bring is fought in the stand's first minutes,
## and that noise brings the first horde no sooner than the window's end.
func test_noise_in_the_arrival_window_brings_no_horde_before_it_ends() -> void:
	var game = _game()
	assert_almost_eq(game.director.quiet_until, ArrivalHorde.WINDOW_S, 0.001)
	game.director.add_noise(1000, 10.0)
	assert_almost_eq(game.director.next_arrival, ArrivalHorde.WINDOW_S, 0.001, "pulled no further than the window's end")
	var late = _game()
	late.director.add_noise(1000, ArrivalHorde.WINDOW_S + 10.0)
	assert_almost_eq(late.director.next_arrival, ArrivalHorde.WINDOW_S + 10.0, 0.001, "after it: down to now, as before")
	var off = _game({"arrival_horde": false})
	off.director.add_noise(1000, 10.0)
	assert_almost_eq(off.director.next_arrival, 10.0, 0.001, "no brakes heard: as before")


func test_it_pulls_no_horde_earlier_and_tells_nobody_where_the_squad_is() -> void:
	var game = _game()
	assert_eq(game.director.next_arrival, HordeDirector.FIRST_INTERVAL)
	assert_eq(game.director.pulled_seconds, 0.0)
	assert_eq(game.director.noticed_t, -INF)
	assert_null(game.last_loud)
	assert_eq(game.ledger.total, 0)
	var row: Dictionary = game.ledger.history[0]
	assert_eq(row["tag"], "train_brake")
	assert_eq(row["level"], SimNoise.Level.LOUD)
	assert_true(game.ledger.by_action.has("train_brake"), "heard, and kept on the stop's record")
	var shown := false
	for s: Dictionary in game.sounds:
		shown = shown or (s["tag"] == "train_brake" and s["level"] == SimNoise.Level.LOUD)
	assert_true(shown, "and the HUD shows it as any sound")


func test_skipping_the_scene_changes_nothing() -> void:
	var seen = _game({"place": "bare_line_01"})
	var skipped = _game({"place": "bare_line_01", "arrive": false})
	assert_gte(seen.arrive_t, 0.0, "one rolls in")
	assert_eq(skipped.arrive_t, -1.0, "the other stands already")
	assert_eq(seen.train_guard.heard, skipped.train_guard.heard)
	assert_eq(seen.train_guard.filled, skipped.train_guard.filled)
	assert_eq(seen.zombies.list.size(), skipped.zombies.list.size())
	for i in range(seen.zombies.list.size()):
		assert_eq(seen.zombies.list[i]["state"], skipped.zombies.list[i]["state"])
		assert_eq(seen.zombies.list[i].get("arrival", false), skipped.zombies.list[i].get("arrival", false))


func test_a_place_short_of_its_kind_gets_the_rest_out_of_sight() -> void:
	var game = _game({"place": "houses_01"})
	var g = game.train_guard
	var least: int = int(ArrivalHorde.band("houses")[0])
	assert_eq(g.heard + g.filled, maxi(least, g.heard))
	var before: int = game.zombies.list.size()
	_run(game, ArrivalHorde.FILL_GAP_S * float(g.filled) + 0.5)
	var came := 0
	for z in game.zombies.list.slice(before):
		if z.get("arrival", false):
			came += 1
			assert_false(game.camera.is_position_in_frustum(z["pos"]), "never on screen")
	assert_eq(came, g.filled)


func test_the_guards_put_them_down_at_the_train_and_it_goes_on_the_receipt() -> void:
	var game = _game({"place": "houses_01"})
	_run(game, ArrivalHorde.WINDOW_S)
	var g = game.train_guard
	assert_gt(g.bodies.size(), 0, "some got to the train")
	assert_gt(g.put_down.size(), 0, "and the guards put them down")
	for id: int in g.put_down:
		var z: Dictionary = game.zombies.find(id)
		assert_eq(z["state"], "dead")
	# The field's run is the same function an unplayed stop uses.
	assert_eq(TrainGuard.resolve(g.bodies, g.hands, game.rng.seed), g.result)
	game.finish("departed")
	var d: Dictionary = game.receipt.to_dict()
	var note: Dictionary = d["placeState"]["trainGuard"]
	assert_eq(note["came"], g.bodies.size())
	assert_eq(note["heard"], g.heard)
	assert_eq((d["people"]["dead"] as Array).size(), 0, "nobody of the squad died at the train")
	assert_eq(game.receipt.problems().size(), 0, str(game.receipt.problems()))


func test_the_radio_says_it_once_and_not_when_it_is_off() -> void:
	var game = _game({"place": "houses_01"})
	var said := 0
	var t := 0.0
	while t < ArrivalHorde.RADIO_AT_S + 3.0:
		game._step(0.1)
		t += 0.1
		if game.radio == ArrivalHorde.RADIO_LINE and game.radio_t > 7.95:
			said += 1
	assert_eq(said, 1)
	var quiet = _game({"place": "houses_01", "radio": "off"})
	t = 0.0
	while t < ArrivalHorde.RADIO_AT_S + 3.0:
		quiet._step(0.1)
		t += 0.1
		assert_ne(quiet.radio, ArrivalHorde.RADIO_LINE)


func test_no_arrival_horde_when_switched_off() -> void:
	var game = _game({"arrival_horde": false})
	assert_false(game.train_guard.done)
	assert_eq(game.ledger.history.size(), 0)


func test_the_whistle_is_as_it_was() -> void:
	assert_eq(SimNoise.SOURCES["whistle"]["levels"], [SimNoise.Level.VERY_LOUD])
	assert_true(SimNoise.pulls("whistle"))
	assert_eq(SimNoise.tag_score(SimNoise.Level.VERY_LOUD, "whistle"), 6)
	assert_eq(SimNoise.tag_score(SimNoise.Level.LOUD, "train_brake"), 0)


## Every sound the field makes is in the one table, at a level it allows
## (gap audit J04: where it comes from, who hears it, what it pulls).
func test_every_sound_the_code_makes_is_in_the_table() -> void:
	var re := RegEx.create_from_string("make_sound\\((.*)")
	var level_re := RegEx.create_from_string("Level\\.([A-Z_]+)")
	var tag_re := RegEx.create_from_string("\"([a-z_]+)\"")
	var seen: Dictionary = {}
	for path in _scripts("res://game"):
		var text := FileAccess.get_file_as_string(path)
		for line in text.split("\n"):
			if line.contains("func make_sound"):
				continue
			var m := re.search(line)
			if m == null:
				continue
			var tags := tag_re.search_all(m.get_string(1))
			if tags.is_empty():
				continue
			var tag: String = tags[tags.size() - 1].get_string(1)
			seen[tag] = true
			assert_true(SimNoise.SOURCES.has(tag), "%s: %s — a new sound: add its row to noise.gd SOURCES (levels, at, pull)" % [path, tag])
			var lv := level_re.search(m.get_string(1))
			if lv != null and SimNoise.SOURCES.has(tag):
				assert_true((SimNoise.SOURCES[tag]["levels"] as Array).has(SimNoise.Level.get(lv.get_string(1))), "%s: %s at %s" % [path, tag, lv.get_string(1)])
	assert_true(seen.has("train_brake") and seen.has("train_guard") and seen.has("whistle"))


## The maps: none puts more of the dead by its engine than its kind's most.
## Building all eighty takes minutes, so these are the ones with the most by
## their engines of each kind (counted over every map, 2026-10-25: the rest
## have 0 to 3); a map made later is counted by tools/arrival_runs.gd.
const MOST_BY_ENGINE := ["first_leg_01_sulechow", "summit_05", "office_02", "mine_02", "bare_line_01", "lodge_02"]


func test_no_map_has_more_by_its_engine_than_its_kind_allows() -> void:
	const FieldMaps = preload("res://game/world/field_maps.gd")
	for id in MOST_BY_ENGINE:
		var d: Dictionary = FieldMaps.build(id)
		if not d["anchors"].has("whistle"):
			continue
		var spot: Vector3 = FieldGrid.center(d["anchors"]["whistle"])
		var n := 0
		for key: String in d["spawns"]:
			if (key.begins_with("dead_") and key != "dead_levels") or key in ["clothed_station", "clothed_shed"]:
				for c in d["spawns"][key]:
					if FieldGrid.center(c).distance_to(spot) <= ArrivalHorde.reach():
						n += 1
		assert_lte(n, int(ArrivalHorde.band(String(d["place_kind"]))[1]), id)


func _scripts(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir + "/" + sub))
	return out


## The music steps aside for the brakes and a call on the radio (its own
## frame connects to this); the hiss alone does not.
func test_the_brakes_and_the_radio_hush_the_music() -> void:
	var game = _game({"place": "houses_01"})
	var heard: Array = []
	game.audio.hush.connect(func(kind: String, s: float) -> void: heard.append([kind, s]))
	game.audio.train_brake()
	game.audio.radio("hiss")
	game.audio.radio("urgent")
	assert_eq(heard, [["brake", game.audio.HUSH_BRAKE_S], ["radio", game.audio.HUSH_RADIO_S]])


## The guards cover the doors all through the stop (the user's field test,
## 14): one of the dead that comes at someone getting on is theirs too.
func test_the_guards_cover_someone_getting_on() -> void:
	var game = _game({"place": "houses_01", "arrival_horde": false})
	game.zombies.list.clear()
	game.pending_spawn.clear()
	var p = game.squad[1]
	var door: Vector3 = FieldGrid.center(game.data["spawns"]["train_door"][0])
	p.position = door
	p.command = "retreat"
	var z: Dictionary = game.zombies.spawn("dead", door + Vector3(1.6, 0, 0))
	z["state"] = "chase"
	z["victim"] = p
	var t := 0.0
	while t < TrainGuard.KILL_S + 1.5:
		game._step(0.1)
		t += 0.1
	var g = game.train_guard
	assert_eq(g.at_doors, 1, "taken at the door")
	assert_eq(z["state"], "dead", "and put down by the guards")
	assert_true(g.put_down.has(int(z["id"])))
	game.finish("departed")
	assert_eq(game.receipt.to_dict()["placeState"]["trainGuard"]["atDoors"], 1)
	assert_eq(game.receipt.problems().size(), 0, str(game.receipt.problems()))


func test_nobody_getting_on_nobody_covered() -> void:
	var game = _game({"place": "houses_01", "arrival_horde": false})
	game.zombies.list.clear()
	game.pending_spawn.clear()
	var door: Vector3 = FieldGrid.center(game.data["spawns"]["train_door"][0])
	var z: Dictionary = game.zombies.spawn("dead", door + Vector3(1.6, 0, 0))
	for i in range(20):
		game._step(0.1)
	assert_false(z.get("at_door", false))
	assert_eq(game.train_guard.at_doors, 0)
