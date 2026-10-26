extends "res://addons/gut/test.gd"
## A restart must not buy time, reroll a fight, or forget a wave already coming.

const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")
const Mission = preload("res://game/sim/mission.gd")
const STEP: float = 0.1
const EPS: float = 0.000001
var fields: Array = []


func after_each() -> void:
	for game in fields:
		if is_instance_valid(game):
			game.free()
	fields.clear()
	await get_tree().process_frame


func _game(extra: Dictionary = {}):
	var game = FieldGame.new()
	game.opts = {"seed": 831, "raiders": false, "auto_pause": false, "arrive": false, "lungers": true, "receipt_id": "resume_exact"}
	game.opts.merge(extra, true)
	game.map_script = BareLine
	add_child(game)
	game.set_process(false)
	fields.append(game)
	return game


func _scenario(game, grabbed: bool) -> void:
	game.clock.elapsed = 41.3
	game.combat.wound_rng().randf()
	# The gear dice are seeded on first use (field_combat.gd gear_rng): drawn once, so both runs hold a seeded one.
	game.combat.gear_rng().randf()
	game.zombies.list.clear()
	game.director.next_arrival = 42.0
	game.director.budget_left = 21
	game.ammo["pistol"] = 3
	game.actions.coal_delivered = 2.4
	game.receipt.place_note("resume_check", true)
	var p = game.player
	p.body.apply_bite(game.rng, "arm_left", 40.0)
	p.body.window_left = 16.7
	p.body.light_bleed_time = 237.0
	p.body.exhaustion = 0.43
	p.body.breath = 0.38
	p.body.injured_at = -77.0
	p.body.wounds[0]["bandage_t"] = 3.2
	p.heat.heat = 34.8
	p.heat.wet = 0.62
	p.hunger_level = 2
	p.sore_level = 1
	p.smell = 2
	p.blood_soaked = true
	p.close_kills = [39.2, 40.1]
	for mate in game.squad:
		mate.command = "wait"
		mate.command_target = mate.position + Vector3(1.0, 0, 0)
	var hurt = game.squad[1]
	hurt.body.apply_cut(true, 40.0, "leg_left")
	hurt.body.heavy_bleed_time = 119.0
	hurt.body.downed = true
	hurt.body.down_time = 58.7
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.55 if grabbed else 8.0, 0, 0))
	z["state"] = "grab" if grabbed else "chase"
	z["victim"] = p
	z["target"] = p.position
	z["last_seen"] = p.position
	z["seen_t"] = 1.7
	z["windup"] = 0.35
	z["grab_t"] = 0.4
	if grabbed:
		p.grabbers = [z]
		p.grab_left = 0.7
		p.grab_front = false
	game.data["containers"]["resume_scrap"] = {
		"id": "resume_scrap", "name": "고철", "cell": Vector2i(24, 20), "level": 0,
		"building": -1, "search": 2, "items": ["scrap", "wood"], "locked": false, "searched": false,
	}
	game.view.add_container("resume_scrap")
	game.ground_items.append({"id": "ammo_craft", "n": 2, "pos": Vector3(24.25, 0, 19.75)})
	# Move every independent stream beyond its seed, including loot not yet rolled.
	for stream in [game.rng, game.eat_rng, game.zombies.loot_rng, game.zombies.lunge_rng, game.zombies.embed_rng, game.combat._pace_rng, game.lines._rng]:
		for i in 7:
			stream.randi()


func _saved(game) -> Dictionary:
	return FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))


func _snapshot(game) -> Dictionary:
	var state: Dictionary = _saved(game)
	# resume_opts makes implicit place/mission options explicit; those are not ticks.
	state.erase("start_opts")
	return state


func _resume(game):
	var saved: Dictionary = _saved(game)
	var before: Dictionary = saved.duplicate(true)
	before.erase("start_opts")
	var resumed = _game(FieldSave.resume_opts(saved))
	_same(_snapshot(resumed), before, "at restore")
	assert_true(resumed.paused)
	assert_true(resumed.resume_pending)
	# The real one-second gate is tested separately. Advance only its wall deadline,
	# never the field clock, so many restarts do not add simulation ticks to this test.
	resumed.resume_ready_at_ms = Time.get_ticks_msec()
	assert_true(resumed.continue_resume())
	game.free()
	return resumed


func _same(actual: Variant, expected: Variant, at: String) -> void:
	var differences: Array[String] = []
	_diff(actual, expected, at, differences)
	assert_eq(differences, [] as Array[String], at)


func _diff(actual: Variant, expected: Variant, at: String, differences: Array[String]) -> void:
	if differences.size() >= 12:
		return
	if (actual is float or actual is int) and (expected is float or expected is int):
		var equal: bool = actual == expected if actual is int and expected is int else (absf(float(actual) - float(expected)) <= EPS if is_finite(float(expected)) else actual == expected)
		if not equal:
			differences.append("%s: %s != %s" % [at, actual, expected])
	elif actual is Vector3 and expected is Vector3:
		_diff(actual.x, expected.x, at + ".x", differences)
		_diff(actual.y, expected.y, at + ".y", differences)
		_diff(actual.z, expected.z, at + ".z", differences)
	elif actual is Dictionary and expected is Dictionary:
		if actual.size() != expected.size():
			differences.append(at + ": different keys")
		for key in expected:
			if actual.has(key):
				_diff(actual[key], expected[key], at + "." + str(key), differences)
			else:
				differences.append(at + ": missing " + str(key))
	elif (actual is Array and expected is Array) or (actual is PackedVector3Array and expected is PackedVector3Array):
		if actual.size() != expected.size():
			differences.append(at + ": different lengths")
		for i in mini(actual.size(), expected.size()):
			_diff(actual[i], expected[i], at + "[%d]" % i, differences)
	elif actual != expected:
		differences.append(at + ": different values")


func _run_pair(grabbed: bool) -> void:
	var uninterrupted = _game()
	var restarted = _game()
	_scenario(uninterrupted, grabbed)
	_scenario(restarted, grabbed)
	# Include a cut at the exact grabbed instant, before the bite window ticks.
	restarted = _resume(restarted)
	for i in 60:
		uninterrupted._process(STEP)
		restarted._process(STEP)
		if (i + 1) % 13 == 0:
			restarted = _resume(restarted)
	_same(_snapshot(restarted), _snapshot(uninterrupted), "after six seconds")
	assert_false(uninterrupted.hordes.is_empty(), "a wave really arrived")
	assert_true(uninterrupted.squad[1].body.dead, "the downed body's clock really expired")
	assert_gt(uninterrupted.zombies.list.size(), 1, "new bodies really entered")


func test_repeated_json_restarts_match_uninterrupted_ticks() -> void:
	_run_pair(false)


func test_restarting_while_grabbed_keeps_the_same_bite_and_wave() -> void:
	_run_pair(true)


func test_cut_while_a_wave_is_still_entering() -> void:
	var game = _game()
	_scenario(game, false)
	for i in 13:
		game._process(STEP)
	assert_false(game.pending_spawn.is_empty())
	var before: Dictionary = _snapshot(game)
	var resumed = _resume(game)
	_same(_snapshot(resumed), before, "incoming wave")
	assert_true(resumed.hordes.keys()[0] is int, "wave ids stay integer dictionary keys")


func test_all_rng_steps_and_large_seed_survive_json() -> void:
	var game = _game({"seed": 9223372036854775123})
	_scenario(game, false)
	var resumed = _game(FieldSave.resume_opts(_saved(game)))
	var originals: Array = [game.rng, game.eat_rng, game.zombies.loot_rng, game.zombies.lunge_rng, game.zombies.embed_rng, game.combat._wound_rng, game.combat._gear_rng, game.combat._pace_rng, game.lines._rng]
	var copies: Array = [resumed.rng, resumed.eat_rng, resumed.zombies.loot_rng, resumed.zombies.lunge_rng, resumed.zombies.embed_rng, resumed.combat._wound_rng, resumed.combat._gear_rng, resumed.combat._pace_rng, resumed.lines._rng]
	for i in originals.size():
		assert_eq(copies[i].seed, originals[i].seed, "seed %d" % i)
		assert_eq(copies[i].state, originals[i].state, "state %d" % i)
		for j in 8:
			assert_eq(copies[i].randi(), originals[i].randi(), "next draw %d/%d" % [i, j])


func test_mission_holdout_grid_and_work_reservations_survive() -> void:
	var game = _game({"holdout": "start"})
	_scenario(game, false)
	game.mission_play.mission = Mission.new("depot")
	game.mission_play.mission.fill("load", 4.5, game.clock.elapsed)
	game.mission_play.mission.mark("repair", "begun", game.clock.elapsed)
	game.mission_play.mission.learn("resume_fact")
	game.mission_play.opened.append("resume_scrap")
	game.mission_play.repair_done = 12.3
	game.mission_play.belt_noise_t = 1.8
	game.holdout.left = 67.8
	game.holdout.doors[0]["hp"] = 34
	game.holdout.doors[0]["wall"] = 12
	game.holdout.doors[0]["bang_t"] = 0.43
	game.holdout.doors[0]["entered"] = {9: true}
	game.holdout.walls_built = 1
	var door_cell := Vector2i(27, 20)
	game.grid.solid[game.grid.index(door_cell)] = FieldGrid.Solid.DOOR
	game.grid.doors[door_cell] = {"state": "locked", "hp": 17, "building": -1, "key": "test", "boards": 2}
	var window_cell := Vector2i(28, 20)
	game.grid.solid[game.grid.index(window_cell)] = FieldGrid.Solid.WINDOW
	game.grid.windows[window_cell] = {"broken": true, "glass": false, "building": -1, "boards": 1}
	game.grid.refresh_paths()
	var p = game.player
	p.position = Vector3(24.5, 0, 20.5)
	game.actions.search(p, "resume_scrap")
	assert_eq(p.action, "search")
	p.action_t = 0.15
	var resumed = _game(FieldSave.resume_opts(_saved(game)))
	assert_true(is_same(resumed.player.action_busy, resumed.data["containers"]["resume_scrap"]))
	assert_true(resumed.actions.ongoing.has(resumed.player.get_instance_id()))
	_same(_snapshot(resumed), _snapshot(game), "mission and work")
	resumed.resume_ready_at_ms = Time.get_ticks_msec()
	assert_true(resumed.continue_resume())
	for i in 4:
		game._process(STEP)
		resumed._process(STEP)
	_same(_snapshot(resumed), _snapshot(game), "work completed once")
	assert_true(resumed.data["containers"]["resume_scrap"]["searched"])
	assert_true(resumed.view.has_container("resume_scrap"), "the new heap is also drawn")
	assert_true(is_instance_valid(resumed.holdout.doors[0]["node"]))


func test_one_second_continue_gate_for_both_grabbed_and_free_people() -> void:
	for grabbed: bool in [false, true]:
		var game = _game()
		_scenario(game, grabbed)
		var resumed = _game(FieldSave.resume_opts(_saved(game)))
		var before: Dictionary = _snapshot(resumed)
		assert_eq(resumed.hud.resume_button.text, "이어서")
		assert_true(resumed.hud.resume_button.disabled)
		resumed.hud._continue_resume()
		resumed.hud._toggle_pause()
		resumed.hud._close_modal()
		var first_frame: int = Time.get_ticks_msec()
		resumed._process(30.0)
		assert_false(resumed.continue_resume())
		assert_true(resumed.resume_pending, "a long frame is not one second on screen")
		assert_gte(resumed.resume_ready_at_ms, first_frame + 1000)
		var minutes: int = int(floor(resumed.clock.game_minutes())) % 1440
		assert_eq(resumed.hud.clock_label.text, "%02d:%02d" % [minutes / 60, minutes % 60])
		assert_eq(resumed.hud.grab_bar.visible, grabbed)
		assert_eq(resumed.hud.status_rows, resumed.player.body.status_notes())
		# A physics timer can overshoot on a busy test host. Wait for the actual
		# foreground deadline without accidentally pressing the button after it.
		while Time.get_ticks_msec() < resumed.resume_ready_at_ms:
			await get_tree().process_frame
		resumed._process(STEP)
		assert_true(resumed.paused, "the deadline alone never resumes play")
		assert_false(resumed.hud.resume_button.disabled)
		_same(_snapshot(resumed), before, "still waiting for the press")
		resumed.hud.resume_button.pressed.emit()
		assert_false(resumed.paused)
		assert_false(resumed.resume_pending)
		resumed._process(STEP)
		assert_almost_eq(resumed.clock.elapsed, game.clock.elapsed + STEP, EPS)


func test_version_one_keeps_old_fallbacks_and_missing_body_defaults() -> void:
	var game = _game()
	_scenario(game, true)
	var legacy: Dictionary = FieldSave.capture(game)
	legacy["version"] = 1
	legacy.erase("runtime")
	var old_zombies: Array = []
	for zombie: Dictionary in game.zombies.list:
		old_zombies.append({"id": zombie["id"], "kind": zombie["kind"], "pos": zombie["pos"], "state": zombie["state"], "horde": zombie["horde"], "name": zombie["name"], "loot": zombie.get("loot", []), "searched": zombie.get("searched", false)})
	legacy["zombies"] = old_zombies
	for row: Dictionary in legacy["people"]:
		row.erase("state")
		row.erase("aim")
		row.erase("heat")
		row.erase("meta")
		var body: Dictionary = row["body"]
		for key in body.keys():
			if key not in ["wounds", "infection", "infected", "exhaustion", "downed", "dead"]:
				body.erase(key)
	var decoded: Dictionary = FieldSave.from_json(JSON.stringify(_old_json_data(legacy)))
	assert_eq(decoded["version"], 1)
	var resumed = _game(FieldSave.resume_opts(decoded))
	assert_eq(resumed.player.body.window_left, 0.0)
	assert_eq(resumed.player.body.breath, 1.0)
	assert_eq(resumed.player.heat.heat, 100.0)
	assert_eq(resumed.zombies.list[0]["state"], "wander")
	assert_true(resumed.hordes.is_empty())
	assert_false(resumed.data["containers"].has("resume_scrap"))
	assert_true(resumed.resume_pending)


func _old_json_data(value: Variant) -> Variant:
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Vector2i:
		return [value.x, value.y]
	if value is Dictionary:
		var out: Dictionary = {}
		for key in value:
			out[String(key)] = _old_json_data(value[key])
		return out
	if value is Array:
		var out: Array = []
		for item in value:
			out.append(_old_json_data(item))
		return out
	return value
