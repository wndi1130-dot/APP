extends "res://addons/gut/test.gd"
## What a stop is for (content_variety_first_build 2부): the kind comes in by
## opts["mission"], and a stop with no kind writes what it always wrote.

const FieldGame = preload("res://game/field_game.gd")
const Mission = preload("res://game/sim/mission.gd")
const SulehufMap = preload("res://game/world/sulehuf_map.gd")


func _game(extra: Dictionary):
	var game = FieldGame.new()
	var opts := {"seed": 5, "raiders": false, "auto_pause": false}
	opts.merge(extra)
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	return game


func _run(extra: Dictionary) -> Dictionary:
	var game = FieldGame.new()
	var opts := {"seed": 5, "raiders": false, "auto_pause": false}
	opts.merge(extra)
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	var out := {"mission": game.mission}
	game.finish("departed")
	out["receipt"] = game.receipt.to_dict()
	out["telemetry"] = game.telemetry.to_dict()
	return out


func test_a_stop_with_no_kind_writes_what_it_always_wrote() -> void:
	var plain := _run({})
	var empty := _run({"mission": ""})
	assert_eq(plain["mission"], "")
	assert_eq(JSON.stringify(empty["receipt"]), JSON.stringify(plain["receipt"]))
	assert_eq(JSON.stringify(empty["telemetry"]), JSON.stringify(plain["telemetry"]))
	assert_false((plain["receipt"]["placeState"] as Dictionary).has("mission"))
	assert_false((plain["telemetry"] as Dictionary).has("mission"))


func test_the_kind_goes_on_the_receipt_and_the_run_log() -> void:
	for kind in ["survey", "depot"]:
		var run := _run({"mission": kind})
		assert_eq(run["mission"], kind)
		assert_eq(run["receipt"]["placeState"]["mission"], kind)
		assert_eq(run["telemetry"]["mission"], kind)


func test_a_kind_nobody_knows_is_the_plain_stop() -> void:
	var run := _run({"mission": "picnic"})
	assert_eq(run["mission"], "")
	assert_false((run["telemetry"] as Dictionary).has("mission"))


# ---------------------------------------------------------------- goals (sim)

func test_goals_are_counted_each_on_its_own() -> void:
	var m := Mission.new("survey")
	assert_false(m.all_done())
	assert_true(m.mark("outside", "switch", 40.0))
	assert_false(m.mark("outside", "switch", 41.0), "a part counts once")
	assert_false(m.mark("outside", "roof", 41.0), "not a part of it")
	assert_eq(m.state("outside", "departed"), Mission.PART)
	assert_eq(m.state("records", "departed"), Mission.RETREAT, "left untouched by choice")
	assert_eq(m.state("records", "wiped"), Mission.FAILED, "lost before it was touched")
	assert_eq(m.state("deep", "departed"), Mission.NONE, "an extra left alone is not part done")
	m.mark("outside", "signal", 90.0)
	assert_eq(m.state("outside", "departed"), Mission.DONE)
	assert_almost_eq(float(m.goal("outside")["t"]), 90.0, 0.001)
	assert_false(m.all_done())
	m.mark("records", "log", 150.0)
	assert_true(m.all_done(), "the extra is not needed")
	assert_eq(m.states("departed"), {"outside": "done", "records": "done", "deep": "none"})
	assert_true(m.learn("switch_east_frozen"))
	assert_false(m.learn("switch_east_frozen"), "the same fact from a second place is one fact")


func test_a_plain_stop_has_no_goals() -> void:
	var m := Mission.new("")
	assert_eq(m.goals.size(), 0)
	assert_false(m.all_done())
	assert_eq(m.states("departed"), {})


# ---------------------------------------------------------------- the survey in the field

func test_the_survey_puts_its_places_on_the_map_and_a_plain_stop_does_not() -> void:
	var plain = _game({})
	var base: Dictionary = SulehufMap.build()
	assert_eq(plain.data["spots"].keys(), base["spots"].keys())
	assert_eq(plain.data["containers"].keys(), base["containers"].keys())
	assert_false(plain.mission_play.active())
	var game = _game({"mission": "survey"})
	for row in game.mission_play.SURVEY_SPOTS:
		assert_true(game.data["spots"].has(row[0]), row[0])
		assert_true(game.grid.people_can_walk(row[2]), "%s can be walked up to" % row[1])
		assert_false(base["spots"].values().any(func(sp): return sp["cell"] == row[2]), "its own cell")
	for row in game.mission_play.SURVEY_LOGS:
		var c: Dictionary = game.data["containers"][row[0]]
		assert_true(c["locked"])
		assert_true(game.levels[int(row[4])].people_can_walk(row[2]) or game.levels[int(row[4])].inside(row[2]))
		assert_false(base["containers"].values().any(func(o): return o["cell"] == row[2] and o["level"] == row[4]), "its own cell")
	assert_eq(game.grid.building_at(game.mission_play.SURVEY_LOGS[0][2]), 0, "in the station")
	assert_eq(game.grid.building_at(game.mission_play.SURVEY_LOGS[1][2]), 1, "in the signal box")


func test_looking_at_the_outside_things_is_silent_and_counts() -> void:
	var game = _game({"mission": "survey"})
	var p = game.player
	var noise: int = game.ledger.total
	game.actions.spot_default(p, "sv_switch", "")
	assert_eq(p.action, "inspect")
	assert_almost_eq(p.action_total, game.mission_play.INSPECT_TIME, 0.001)
	p.action_done.call()
	assert_eq(game.data["spots"]["sv_switch"]["state"], "seen")
	assert_eq(game.mission_play.mission.state("outside", "departed"), Mission.PART)
	game.mission_play._seen(p, "sv_signal")
	assert_true(game.mission_play.mission.is_done("outside"))
	assert_eq(game.ledger.total, noise, "no sound was made")
	assert_true(game.mission_play.mission.facts.has("switch_east_frozen"))


func test_the_record_box_opens_quietly_and_slowly_or_fast_and_loud() -> void:
	var game = _game({"mission": "survey"})
	var p = game.player
	var play = game.mission_play
	var noise: int = game.ledger.total
	game.actions.search(p, "sv_log_office")
	assert_ne(p.action, "search", "it is locked: a card asks how")
	play._lock_choice("quiet", p, "sv_log_office")
	assert_eq(p.action, "pick")
	assert_almost_eq(p.action_total, play.PICK_TIME, 0.001)
	p.action_done.call()
	assert_false(game.data["containers"]["sv_log_office"]["locked"])
	assert_eq(game.ledger.total, noise, "picked without a sound")
	play._lock_choice("break", p, "sv_log_signal")
	assert_lt(p.action_total, play.PICK_TIME / 5.0)
	p.action_done.call()
	assert_false(game.data["containers"]["sv_log_signal"]["locked"])
	assert_gt(game.ledger.total, noise, "broken with a loud sound")
	assert_eq(play.opened, ["sv_log_office", "sv_log_signal"] as Array[String])
	assert_eq(game.decisions.size(), 2)
	# Reading it is what counts, and the second box adds nothing new.
	game.actions._searched(p, "sv_log_office")
	assert_true(play.mission.is_done("records"))
	var facts: int = play.mission.facts.size()
	game.actions._searched(p, "sv_log_signal")
	assert_eq(play.mission.facts.size(), facts)


func test_a_fact_can_be_had_in_two_places() -> void:
	var by_eye = _game({"mission": "survey"})
	by_eye.mission_play._seen(by_eye.player, "sv_switch")
	assert_true(by_eye.mission_play.mission.facts.has("switch_east_frozen"))
	var by_log = _game({"mission": "survey"})
	by_log.actions._searched(by_log.squad[1], "sv_log_signal")
	assert_true(by_log.mission_play.mission.facts.has("switch_east_frozen"))
	assert_true(by_log.mission_play.mission.is_done("records"), "a companion's find counts")


func test_no_work_crew_on_a_survey() -> void:
	var game = _game({"mission": "survey"})
	game.zombies.list.clear()
	game.actions.start_work(game.player)
	assert_false(game.actions.work_started)
	assert_eq(game.crew.size(), 0)
	var plain = _game({})
	plain.zombies.list.clear()
	plain.actions.start_work(plain.player)
	assert_true(plain.actions.work_started, "the plain stop calls them as before")


func test_a_quiet_survey_done_is_told_and_nothing_is_added() -> void:
	var game = _game({"mission": "survey"})
	var p = game.player
	var budget: int = game.director.budget_left
	var dead: int = game.zombies.list.size()
	var waiting: int = game.pending_spawn.size()
	game.mission_play._seen(p, "sv_switch")
	game.mission_play._seen(p, "sv_signal")
	assert_false(game.mission_play.mission.all_done())
	game.actions._searched(p, "sv_log_office")
	assert_true(game.mission_play.mission.all_done())
	assert_false(game.ended, "being done does not end the stop")
	assert_true(String(game.radio_wait.get("text", "")).contains("떠날 때"), "the driver says so")
	assert_eq(game.director.budget_left, budget, "no horde is put on top")
	assert_eq(game.zombies.list.size(), dead)
	assert_eq(game.pending_spawn.size(), waiting)
	assert_eq(game.hordes.size(), 0)


func test_how_the_goals_stood_goes_on_the_receipt_and_the_run_log() -> void:
	var game = _game({"mission": "survey"})
	game.mission_play._seen(game.player, "sv_switch")
	game.mission_play._unlocked("sv_log_signal")
	game.finish("departed")
	var ps: Dictionary = game.receipt.to_dict()["placeState"]
	assert_eq(ps["goals"], {"outside": "part", "records": "retreat", "deep": "none"})
	assert_eq(ps["facts"], ["switch_east_frozen"])
	assert_eq(ps["opened"], ["sv_log_signal"])
	assert_eq(game.receipt.check(game.receipt.to_dict()).size(), 0, "still a receipt")
	var rows: Array = game.telemetry.to_dict()["goals"]
	assert_eq(rows.size(), 3)
	assert_eq(rows[0]["id"], "outside")
	assert_eq(rows[0]["state"], "part")


# ---------------------------------------------------------------- the run log in the field

func test_a_cleared_horde_logs_its_breather_and_a_shaken_off_chase_its_time() -> void:
	var game = _game({})
	game.zombies.list.clear()
	game.pending_spawn.clear()
	game.hordes[1] = {"t": 0.0, "ids": [], "cleared": false, "entry": "east_track"}
	game._update_hordes(0.1)
	var rests: Array = game.telemetry.rests
	assert_eq(rests.size(), 1)
	assert_almost_eq(float(rests[0][1]) - float(rests[0][0]), game.director.REST_BASE, 0.001)
	assert_almost_eq(float(rests[0][1]), game.director.rest_until, 0.001, "read from the director, not worked out again")
	game.director.noticed(game.clock.elapsed - game.director.LOST_QUIET - 1.0)
	game._update_hordes(0.1)
	assert_eq(game.telemetry.lost.size(), 1)
	game._update_hordes(0.1)
	assert_eq(game.telemetry.lost.size(), 1, "once for one escape")


func test_loads_put_down_at_the_train_are_counted() -> void:
	var game = _game({})
	var p = game.player
	p.add_item("scrap", 2)
	var rect: Rect2i = game.data["unload"]
	p.position = game.lift(rect.position + Vector2i(3, 1), 0)
	game.actions._auto_unload()
	assert_eq(game.telemetry.trips, 1)
	game.actions._auto_unload()
	assert_eq(game.telemetry.trips, 1, "empty hands are not a load")


# ---------------------------------------------------------------- the loading yard

func test_an_amount_goal_fills_and_the_repair_is_its_own_goal() -> void:
	var m := Mission.new("depot")
	assert_false(m.fill("load", 5.0, 100.0))
	assert_eq(m.state("load", "departed"), Mission.PART)
	assert_eq(m.state("repair", "departed"), Mission.NONE, "loading straight away is not a part-done repair")
	m.mark("repair", "begun", 120.0)
	assert_eq(m.state("repair", "departed"), Mission.PART)
	assert_true(m.fill("load", 12.0, 500.0), "the moment it is full")
	assert_false(m.fill("load", 13.0, 510.0), "told once")
	assert_true(m.all_done(), "the load is the stop; the repair is a choice")
	assert_eq(m.states("departed"), {"load": "done", "repair": "part"})
	assert_almost_eq(float(m.goal("load")["t"]), 500.0, 0.001)


func _depot():
	var game = _game({"mission": "depot"})
	game.zombies.list.clear()
	game.pending_spawn.clear()
	return game


func test_the_yard_has_a_conveyor_and_one_card_once_the_crew_is_down() -> void:
	var game = _depot()
	var play = game.mission_play
	assert_true(game.grid.people_can_walk(play.CONVEYOR_CELL))
	assert_eq(play.conveyor()["state"], "stopped")
	play.conveyor_card(game.player)
	assert_eq(game.decisions.size(), 0, "nothing to decide before the crew is down")
	game.actions.start_work(game.player)
	assert_true(game.actions.work_started)
	assert_eq(game.crew.size(), 6)
	play._conveyor_choice("load", game.player)
	assert_eq(game.decisions, [{"id": "depot_conveyor", "choice": "load"}])
	assert_eq(play.conveyor()["state"], "stopped")
	assert_almost_eq(play.load_mult(), 1.0, 0.001)


func test_mending_takes_scrap_and_two_pairs_of_hands_once() -> void:
	var game = _depot()
	var play = game.mission_play
	game.actions.start_work(game.player)
	play._conveyor_choice("repair", game.player)
	assert_eq(play.conveyor()["state"], "stopped", "no scrap, no repair")
	assert_eq(game.decisions.size(), 0)
	game.player.add_item("scrap", 1)
	game.squad[1].add_item("scrap", 2)
	play._conveyor_choice("repair", game.player)
	assert_eq(play.conveyor()["state"], "part")
	assert_eq(play.scrap_at_hand(), 1, "two were used")
	var menders: Array = game.crew.filter(func(q): return q.brain.get("job", "") == "repair")
	assert_eq(menders.size(), play.REPAIR_HANDS)
	for q in menders:
		assert_eq(q.role, "worker", "escorts keep guarding")
	assert_eq(play.mission.state("repair", "departed"), Mission.PART)
	# A mender walks to the belt, then works in steps; nobody presses anything.
	var q = menders[0]
	q.position = game.lift(play.CONVEYOR_CELL + Vector2i(8, 0), 0)
	assert_not_null(play.repair_step(q), "too far: go there")
	q.position = game.lift(play.CONVEYOR_CELL, 0)
	assert_null(play.repair_step(q))
	assert_eq(q.action, "repair")
	var steps := int(play.REPAIR_WORK / play.REPAIR_STEP)
	for i in range(steps - 1):
		play._repaired(q)
	assert_eq(play.conveyor()["state"], "part")
	play._repaired(q)
	assert_eq(play.conveyor()["state"], "running")
	assert_true(play.mission.is_done("repair"))
	assert_eq(game.crew.filter(func(c): return c.brain.get("job", "") == "repair").size(), 0, "back to the coal")
	assert_almost_eq(play.load_mult(), play.BELT_MULT, 0.001)


func test_a_running_belt_loads_twice_as_much_and_is_heard_instead_of_the_picks() -> void:
	var plain = _game({})
	var carrier = plain.squad[1]
	plain.ai._dug(carrier)
	var one: float = float(carrier.brain["load"])
	var game = _depot()
	game.mission_play.conveyor()["state"] = "running"
	var c2 = game.squad[1]
	game.ai._dug(c2)
	assert_almost_eq(float(c2.brain["load"]), one * game.mission_play.BELT_MULT, 0.001)
	game.actions.work_started = true
	var noise: int = game.ledger.total
	var pick_t: float = game.actions.dig_noise_t
	game.actions._dig_noise(1.0)
	assert_gt(game.ledger.total, noise, "the belt is heard")
	assert_almost_eq(game.actions.dig_noise_t, pick_t, 0.001, "the pickaxes are not")


func test_leaving_mid_repair_keeps_the_coal_and_the_half_mended_belt() -> void:
	var game = _depot()
	var play = game.mission_play
	game.actions.start_work(game.player)
	game.player.add_item("scrap", 2)
	play._conveyor_choice("repair", game.player)
	play._repaired(game.crew[0])
	game.actions.coal_delivered = float(play.mission.goal("load")["amount"])
	play.loaded()
	assert_true(String(game.radio_wait.get("text", "")).contains("떠날 때"))
	assert_false(game.ended, "a full load does not end the stop")
	game.finish("departed")
	var d: Dictionary = game.receipt.to_dict()
	assert_eq(d["placeState"]["goals"], {"load": "done", "repair": "part"})
	assert_eq(d["placeState"]["conveyor"], "part")
	assert_eq(int(d["stock"]["coal"]), 12)
	assert_false((d["stock"] as Dictionary).has("scrap"), "the scrap used does not come back")
	assert_eq(game.receipt.check(d).size(), 0)

