extends "res://addons/gut/test.gd"
## The brakes are a sound the dead hear (decision 416, gap audit J04): those
## within its reach come to the train in the first minutes and the train
## holds them; it pulls no horde earlier, and skipping the scene of the train
## rolling in changes nothing.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const HordeDirector = preload("res://game/sim/horde_director.gd")
const ArrivalHorde = preload("res://game/sim/arrival_horde.gd")
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


func test_the_dead_within_its_reach_turn_for_the_train_and_the_rest_do_not() -> void:
	var game = _game()
	var g = game.train_guard
	assert_true(g.done)
	var reach: float = ArrivalHorde.reach(game.weather.sound_mult(false))
	assert_gt(g.heard, 0, "the first leg's yard has dead by its engine")
	for z in game.zombies.list:
		var d: float = (z["pos"] as Vector3).distance_to(g.spot)
		if z.get("arrival", false):
			assert_lte(d, reach + 0.01)
			assert_eq(z["state"], "investigate")
		elif z["state"] == "wander" and game.level_of(z["pos"]) == 0:
			assert_gt(d, reach, "one within reach on the ground that did not hear it")


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
