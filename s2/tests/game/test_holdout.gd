extends "res://addons/gut/test.gd"
## Holding the train while it gets ready to leave (user decisions 056, 074,
## 075): the first shape, on the stop there is. A plain stop knows nothing of it.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const FieldHoldout = preload("res://game/field_holdout.gd")
const FieldHud = preload("res://game/ui/field_hud.gd")
const HordeDirector = preload("res://game/sim/horde_director.gd")


func _game(extra: Dictionary = {}):
	var game = FieldGame.new()
	var opts := {"seed": 5, "raiders": false, "auto_pause": false}
	opts.merge(extra, true)
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	return game


## What the doors were heard to do (the radio speaks of them too).
func _door_sounds(game) -> Array:
	return game.audio.played.filter(func(g: String) -> bool: return g.begins_with("door_"))


func _dead_at(game, door: Dictionary) -> Dictionary:
	return game.zombies.spawn("dead", FieldGrid.center(door["cell"]))


func test_a_plain_stop_is_as_it_was() -> void:
	var game = _game()
	assert_false(game.holdout.enabled())
	assert_false(game.holdout.on)
	assert_eq(game.goal_text(), "")
	assert_eq(game.horde_target(), FieldGrid.center(game.horde_home()))
	assert_eq(game.director.first_interval, HordeDirector.FIRST_INTERVAL)
	assert_eq(game.director.next_arrival, HordeDirector.FIRST_INTERVAL)
	assert_true(game.holdout.wall_row(game.player).is_empty())
	game.holdout.tick(1.0)
	game.depart()
	assert_true(game.ended, "leaving leaves")
	assert_true(game.hud.leaving.is_empty(), "no beat on a plain stop")
	assert_true(game.hud.modal_open, "the end card at once")
	assert_false(game.receipt.to_dict()["placeState"].has("holdout"))
	assert_false(game.telemetry.to_dict().has("holdout"))


# User decision 142: no wave is the last one, so leaving is the full stop.
func test_a_held_train_leaving_gets_a_beat_before_the_end_card() -> void:
	var game = _game({"holdout": "start"})
	var hud = game.hud
	assert_eq(game.holdout.leave_lines()[0], "물결이 닿기 전에 떠났다")
	game.holdout.first_wave = game.director.index - 3
	assert_eq(game.holdout.leave_lines()[0], "셋째 물결에서 떠났다")
	game.holdout.first_wave = game.director.index - 12
	assert_eq(game.holdout.leave_lines()[0], "12번째 물결에서 떠났다")
	assert_true(String(game.holdout.leave_lines()[1]).begins_with("채비 %d초를 남겼다" % int(ceil(game.holdout.left))))
	game.depart()
	game.holdout.tick(FieldHoldout.LAST_CALL_S + 0.1)
	assert_true(game.ended)
	assert_false(hud.leaving.is_empty(), "the beat is on")
	assert_false(hud.modal_open, "the end card waits")
	hud.tick(FieldHud.LEAVE_DARK_S)
	assert_almost_eq(hud.leaving["veil"].color.a, FieldHud.LEAVE_DARK, 0.01, "dark by now")
	assert_almost_eq(hud.leaving["words"].modulate.a, 1.0, 0.01, "and the lines are up")
	hud.tick(FieldHud.LEAVE_BEAT_S)
	assert_true(hud.leaving.is_empty())
	assert_true(hud.modal_open, "then the end card")


func test_it_opens_with_a_clock_three_doors_and_its_own_pace() -> void:
	var game = _game({"holdout": "start"})
	var h = game.holdout
	assert_true(h.on)
	assert_eq(h.left, FieldHoldout.READY_TIME)
	assert_eq(h.doors.size(), 3, "the platform side's doors")
	assert_eq(h.count("whole"), 3)
	assert_eq(game.director.next_arrival, FieldHoldout.FIRST_GAP, "the first horde comes at the stage's pace")
	assert_string_contains(game.goal_text(), "채비 5:00")
	# Five minutes of the stage's pace, with nothing pulling them in: more than the stop's one.
	var n := 0
	var t := 0.0
	while t < FieldHoldout.READY_TIME:
		t += 1.0
		if not game.director.update(t).is_empty():
			n += 1
	assert_between(n, 5, 8, "waves in five quiet minutes")


func test_a_horde_walks_to_the_doors_each_body_to_one() -> void:
	var game = _game({"holdout": "start"})
	game._start_horde({"index": 0, "size": 6, "entry": "south_road"})
	var seen: Dictionary = {}
	for row in game.pending_spawn:
		seen[row["target"]] = true
	assert_eq(seen.size(), 3)
	for door in game.holdout.doors:
		assert_true(seen.has(FieldGrid.center(door["cell"])))


func test_the_dead_at_a_door_wear_it_down_and_a_wall_takes_it_first() -> void:
	var game = _game({"holdout": "start"})
	var h = game.holdout
	var door: Dictionary = h.doors[0]
	h.tick(5.0)
	assert_eq(int(door["hp"]), FieldHoldout.DOOR_HP, "nobody at it")
	_dead_at(game, door)
	h.tick(FieldHoldout.BANG_EVERY)
	assert_eq(int(door["hp"]), FieldHoldout.DOOR_HP - 1)
	_dead_at(game, door)
	_dead_at(game, door)
	h.tick(FieldHoldout.BANG_EVERY)
	assert_eq(int(door["hp"]), FieldHoldout.DOOR_HP - 4, "three of them, three blows")
	game.player.add_item("plank", 1)
	game.player.position = FieldGrid.center(door["cell"])
	assert_eq(h.wall_row(game.player)["label"], "방벽 세우기")
	h._built(game.player, 0, "plank")
	assert_eq(int(door["wall"]), FieldHoldout.WALL_HP)
	assert_eq(int(game.player.items.get("plank", 0)), 0, "it costs the one thing")
	assert_true(h.wall_row(game.player).is_empty(), "one wall a door")
	h.tick(FieldHoldout.BANG_EVERY)
	assert_eq(int(door["hp"]), FieldHoldout.DOOR_HP - 4, "the wall is hit, not the door")
	assert_eq(int(door["wall"]), FieldHoldout.WALL_HP - 3)
	assert_eq(int(h.doors[1]["hp"]), FieldHoldout.DOOR_HP, "the other doors are not this one")


func test_no_wall_without_something_to_build_it_of() -> void:
	var game = _game({"holdout": "start"})
	for m in FieldHoldout.MATERIALS:
		game.player.items.erase(m)
	game.holdout.build(game.player, 0)
	assert_ne(game.player.action, "wall")
	game.player.add_item("scrap", 1)
	game.holdout.build(game.player, 0)
	assert_eq(game.player.action, "wall")
	assert_eq(game.player.action_t, FieldHoldout.BUILD_TIME)


func test_a_door_is_whole_then_damaged_then_breached() -> void:
	var game = _game({"holdout": "start", "holdout_door_hp": 6})
	var h = game.holdout
	var door: Dictionary = h.doors[1]
	_dead_at(game, door)
	assert_eq(h.state_of(door), "whole")
	h.tick(FieldHoldout.BANG_EVERY * 4)
	assert_eq(h.state_of(door), "damaged", "under half")
	h.tick(FieldHoldout.BANG_EVERY * 2)
	assert_eq(h.state_of(door), "breached")
	assert_false(game.ended, "a breached door is not the end of it")
	h.tick(FieldHoldout.BANG_EVERY * 3)
	var r: Dictionary = h.result()
	assert_eq(r["doors"], ["whole", "breached", "whole"])
	assert_eq(int(r["breached"]), 1)
	assert_eq(int(r["entered"]), 1, "each of the dead that goes in by a breached door is counted once")


func test_a_door_that_gives_way_reaches_whoever_stands_in_front_of_it_once() -> void:
	var scratched := 0
	for seed in range(1, 9):
		var game = _game({"holdout": "start", "holdout_door_hp": 2, "seed": seed})
		var h = game.holdout
		var door: Dictionary = h.doors[0]
		for p in game.squad:
			p.position = FieldGrid.center(door["cell"] + Vector2i(40, 3))
		game.player.position = FieldGrid.center(door["cell"] + Vector2i(1, 1))
		var wounds: int = game.player.body.wounds.size()
		_dead_at(game, door)
		h.tick(FieldHoldout.BANG_EVERY * 2)
		assert_eq(h.state_of(door), "breached")
		assert_eq(h.reached, 1, "the one in front of it, not those along the platform")
		assert_eq(game.player.body.wounds.size() - wounds, h.hurt, "a scratch or the coat, nothing else")
		assert_true(game.player.grabbers.is_empty(), "nothing has hold of them")
		h.tick(FieldHoldout.BANG_EVERY * 4)
		assert_eq(h.reached, 1, "once, as it gives way")
		assert_eq(int(h.result()["hurt"]), h.hurt)
		scratched += h.hurt
	assert_between(scratched, 1, 8, "over eight stops the coat does not stop every hand")


func test_a_door_has_its_own_sounds_and_only_the_near_doors_are_heard_knocking() -> void:
	var game = _game({"holdout": "start", "holdout_door_hp": 4})
	var h = game.holdout
	var a = game.audio
	var door: Dictionary = h.doors[0]
	game.player.position = FieldGrid.center(door["cell"]) + Vector3(0.5, 0, 2)
	_dead_at(game, door)
	a.played.clear()
	a.last_tag_group = ""
	h.tick(FieldHoldout.BANG_EVERY)
	assert_eq(_door_sounds(game), ["door_bang"])
	assert_eq(a.last_tag_group, "", "the knock is not also played as any impact")
	assert_eq(game.sounds[-1]["tag"], "bang", "the dead hear what they heard")
	h.tick(FieldHoldout.BANG_EVERY * 3)
	assert_eq(_door_sounds(game), ["door_bang", "door_bang", "door_bang", "door_break"], "the blow that breaks it is the break alone")
	h.tick(FieldHoldout.BANG_EVERY * 3)
	assert_eq(_door_sounds(game).size(), 4, "a breached door is not heard knocking")
	a.played.clear()
	h.doors[0]["hp"] = 4
	h.doors[0]["wall"] = 2
	h.tick(FieldHoldout.BANG_EVERY * 2)
	assert_eq(_door_sounds(game), ["door_bang", "door_wall"], "a wall is knocked on, then goes down")
	var far: Dictionary = h.doors[0]
	for other: Dictionary in h.doors:
		if FieldGrid.center(other["cell"]).distance_to(game.player.position) > FieldGrid.center(far["cell"]).distance_to(game.player.position):
			far = other
	for z in game.zombies.list:
		z["state"] = "downed"
	_dead_at(game, far)
	a.played.clear()
	h.tick(FieldHoldout.BANG_EVERY)
	assert_eq(int(far["hp"]), 3)
	assert_eq(_door_sounds(game), [], "the third door away is not heard knocking")
	h.tick(FieldHoldout.BANG_EVERY * 3)
	assert_eq(_door_sounds(game), ["door_break"], "but it is heard giving way")


# User decision 149: ready, the train waits for the word; going costs nothing
# for being unready then, and the same count of three is gone through.
func test_a_ready_train_waits_for_the_word_and_says_what_it_cost() -> void:
	var game = _game({"holdout": "start", "holdout_time": 20.0})
	var h = game.holdout
	h.tick(19.0)
	assert_false(h.ready)
	h.tick(1.5)
	assert_true(h.ready)
	assert_false(game.ended, "it does not go by itself")
	assert_true(h.on, "the doors are still to be held")
	assert_string_contains(String(game.radio_wait["text"]), "채비 끝났다", "the driver says so")
	assert_gt(h.ready_shown, 0.0, "and it stands on the screen")
	assert_string_contains(game.goal_text(), "채비 끝")
	assert_eq(int(h.early_cost()["coal"]), 0)
	h.tick(10.0)
	assert_false(game.ended, "however long")
	game.depart()
	assert_true(h.calling, "the same count")
	h.tick(FieldHoldout.LAST_CALL_S + 0.1)
	assert_true(game.ended)
	var note: Dictionary = game.receipt.to_dict()["placeState"]["holdout"]
	assert_true(note["ready"])
	assert_false(note["early"])
	assert_eq(int(note["overSec"]), 10, "how long it stayed on is kept")
	assert_eq(int(note["earlyCost"]["coal"]), 0)
	assert_eq(game.receipt.to_dict()["endReason"], "departed", "the receipt's reasons are the contract's")
	assert_true(game.telemetry.to_dict()["holdout"]["ready"])


func test_called_on_leaving_it_opens_first_and_leaving_again_goes_early() -> void:
	var game = _game({"holdout": "depart"})
	var h = game.holdout
	assert_false(h.on, "a stop like any other until leaving is called")
	assert_eq(game.director.first_interval, HordeDirector.FIRST_INTERVAL)
	game.depart()
	assert_false(game.ended, "the train is not ready")
	assert_true(h.on)
	h.tick(30.0)
	game.depart()
	assert_false(game.ended, "a last call first")
	h.tick(FieldHoldout.LAST_CALL_S)
	assert_true(game.ended)
	var note: Dictionary = game.receipt.to_dict()["placeState"]["holdout"]
	assert_false(note["ready"])
	assert_true(note["early"])
	assert_eq(int(note["leftSec"]), 270)


# User decision 143: leaving can be called at any time; a count of three, and
# whoever is not at the train when it ends stays on the platform, shouting.
func test_the_last_call_counts_three_and_leaves_behind_whoever_missed_it() -> void:
	var game = _game({"holdout": "start"})
	var h = game.holdout
	var mates: Array = game.squad.filter(func(p): return p != game.player)
	var late = mates[0]
	late.position = game.player.position + Vector3(0, 0, 40)
	assert_false(game.aboard(late))
	assert_true(game.aboard(game.player))
	var coal_before: Dictionary = h.early_cost()
	assert_eq(int(coal_before["coal"]), 10, "nothing is ready yet: the most it can cost")
	assert_eq(game.outside(), 1, "the card can say who would stay")
	game.depart()
	assert_true(h.calling)
	assert_false(game.ended)
	h.tick(1.0)
	assert_almost_eq(h.call_left, FieldHoldout.LAST_CALL_S - 1.0, 0.01)
	game.depart()
	assert_almost_eq(h.call_left, FieldHoldout.LAST_CALL_S - 1.0, 0.01, "calling again does not start it over")
	h.tick(2.1)
	assert_true(game.ended)
	assert_eq(h.left_people, 1)
	assert_true(late.brain.get("left_behind", false), "for the protest motion to read")
	var shouted: Array = game.hud.says.filter(func(s): return s["p"] == late)
	assert_eq(shouted.size(), 1)
	assert_eq(String(shouted[0]["line"]), "나도 데리고가 시발새끼들아!!")
	assert_true(game.receipt.to_dict()["people"]["leftBehind"].has(late.pid))
	assert_true(h.end_lines().has("남기고 온 사람 1 · 신임 −12"))
	assert_true(h.end_lines().has("선로 비었다 · 떠나는 값: 쟁기 부품 0 · 덜 된 채비로 석탄 +10, 부품 +2"))
	assert_true(h.leave_lines().has("남기고 온 사람 1"))
	var note: Dictionary = game.receipt.to_dict()["placeState"]["holdout"]
	assert_eq(int(note["leftPeople"]), 1)
	assert_eq(int(note["earlyCost"]["coal"]), 10)
	assert_eq(int(note["earlyCost"]["plow_part"]), 2)
	assert_eq(int(note["trustDrop"]), 12)
	assert_eq(int(note["trackDead"]), 0)
	assert_almost_eq(float(note["leftShare"]), 1.0, 0.011, "one second of three hundred gone")


func test_going_unready_costs_less_the_readier_the_train_is() -> void:
	var game = _game({"holdout": "start"})
	var h = game.holdout
	# The play check's four steps (starting values): [share left, coal, parts].
	for row: Array in [[0.9, 10, 2], [0.6, 7, 1], [0.4, 4, 1], [0.1, 2, 0]]:
		h.left = h.total * float(row[0])
		assert_eq(int(h.early_cost()["coal"]), int(row[1]), "coal with %s left" % row[0])
		assert_eq(int(h.early_cost()["plow_part"]), int(row[2]), "parts with %s left" % row[0])
	h.ready = true
	assert_eq(int(h.early_cost()["coal"]), 0)


# User decision 147: 12 for the first, 4 for each one more, 24 at the most.
func test_leaving_people_costs_trust_by_how_many() -> void:
	assert_eq(FieldHoldout.trust_drop(0), 0, "things left behind cost none")
	assert_eq(FieldHoldout.trust_drop(1), 12)
	assert_eq(FieldHoldout.trust_drop(2), 16)
	assert_eq(FieldHoldout.trust_drop(4), 24)
	assert_eq(FieldHoldout.trust_drop(9), 24)


# User decision 146: holding to the end gives no goods; the price of leaving
# is the plough's alone, by the dead on the track (s1c_domestic 6.6).
func test_the_plough_price_goes_by_the_dead_on_the_track() -> void:
	for row: Array in [[0, 0, "선로 비었다"], [10, 1, "망자 몇"], [11, 2, "무리"], [30, 2, "무리"], [31, 3, "큰 무리"]]:
		var push: Dictionary = FieldHoldout.plough(int(row[0]))
		assert_eq(int(push["parts"]), int(row[1]), "%d on the track" % row[0])
		assert_eq(String(push["word"]), String(row[2]))
	var game = _game({"holdout": "start"})
	var h = game.holdout
	h.tick(h.total + 1.0)
	game.depart()
	h.tick(FieldHoldout.LAST_CALL_S + 0.1)
	assert_true(game.ended)
	assert_true(h.end_lines().has("끝까지 버텼다 · 선로 비었다 · 떠나는 값: 쟁기 부품 0"))


# Proposed, not decided: the train does not go without its chief.
func test_the_last_call_is_lost_if_the_chief_is_not_at_the_train() -> void:
	var game = _game({"holdout": "start"})
	var h = game.holdout
	game.player.position += Vector3(0, 0, 40)
	game.depart()
	h.tick(FieldHoldout.LAST_CALL_S + 0.1)
	assert_false(game.ended, "it waits")
	assert_false(h.calling)
	assert_true(h.on, "and the doors are still to be held")
	assert_string_contains(String(game.radio_wait["text"]), "열차장이 안 탔다", "the driver says why")


# User decision 146: ready, a quiet while; after it part of every wave stands
# on the track, so the price of leaving climbs again (decision 149).
func test_a_ready_train_gets_a_quiet_while_and_then_the_track_fills() -> void:
	var game = _game({"holdout": "start", "holdout_time": 20.0})
	var h = game.holdout
	var door_cells: Array = h.doors.map(func(d: Dictionary) -> Vector3: return FieldGrid.center(d["cell"]))
	for n in range(6):
		assert_true(door_cells.has(h.target(n)), "before it is ready every body walks to a door")
	game.pending_spawn.append({"t": 0.0, "pos": Vector3.ZERO, "horde": 0, "target": Vector3.ZERO, "entry": "east"})
	game.clock.elapsed = 20.5
	h.tick(20.5)
	assert_true(h.ready)
	assert_true(game.pending_spawn.is_empty(), "those still held at the ways in turn back")
	assert_gte(game.director.next_arrival, 20.5 + FieldHoldout.QUIET_GAP_S, "the next wave is put off")
	game.director.add_noise(200, 21.0)
	assert_gte(game.director.next_arrival, 20.5 + FieldHoldout.QUIET_GAP_S, "and the blows on the doors do not call it back")
	var train: Rect2i = game.data["train"]
	var on_track := 0
	for n in range(9):
		var c: Vector2i = FieldGrid.cell_of(h.target(n, Vector3(1000, 0, 0)))
		if door_cells.has(h.target(n, Vector3(1000, 0, 0))):
			continue
		on_track += 1
		assert_true(c.y >= train.position.y and c.y < train.end.y and c.x >= train.end.x, "on the track, on the end they come from: where the plough's price is counted")
	assert_eq(on_track, 3, "one in three")
	var west: Vector2i = FieldGrid.cell_of(h.target(2, Vector3(-1000, 0, 0)))
	assert_lt(west.x, train.position.x)


# User decision 148: whether a stop can have it is rolled once as the train
# stops and kept; where it can, it opens on leaving unless the stop was quiet
# and the track beside the train is clear.
func test_a_rolled_stop_opens_on_leaving_only_if_it_can_and_was_not_quiet() -> void:
	var never = _game({"holdout": "roll", "holdout_chance": 0})
	assert_false(never.holdout.rolled)
	never.ledger.add(SimNoise.Level.VERY_LOUD, 0.0, "shot")
	never.ledger.add(SimNoise.Level.VERY_LOUD, 0.0, "shot")
	never.ledger.add(SimNoise.Level.VERY_LOUD, 0.0, "shot")
	never.depart()
	assert_true(never.ended, "a stop that cannot have it just leaves, however loud")
	assert_false(never.holdout.opened)
	assert_false(never.telemetry.to_dict()["holdout"]["rolled"], "the roll is kept for the play check")
	var quiet = _game({"holdout": "roll", "holdout_chance": 100})
	assert_true(quiet.holdout.rolled)
	assert_true(quiet.holdout.quiet_and_clear())
	quiet.depart()
	assert_true(quiet.ended, "quiet, and the track clear: it gets away")
	assert_true(quiet.telemetry.to_dict()["holdout"]["slipped"])
	var loud = _game({"holdout": "roll", "holdout_chance": 100})
	for i in range(FieldHoldout.QUIET_NOISE / 6 + 1):
		loud.ledger.add(SimNoise.Level.VERY_LOUD, 0.0, "whistle")
	assert_true(loud.holdout.opens_on_leaving())
	loud.depart()
	assert_false(loud.ended, "loud, where it can: the train has to be held")
	assert_true(loud.holdout.on)
	var crowded = _game({"holdout": "roll", "holdout_chance": 100})
	var train: Rect2i = crowded.data["train"]
	for i in range(FieldHoldout.CLEAR_TRACK + 1):
		crowded.zombies.spawn("dead", FieldGrid.center(Vector2i(train.end.x + 2 + i, train.position.y)))
	assert_false(crowded.holdout.quiet_and_clear(), "quiet, but they stand on the track")
	assert_true(crowded.holdout.opens_on_leaving())


# What the dead do to a door is in the stop's score, but it is not the
# people's noise: a quiet stop stays quiet however they beat on it.
func test_quiet_is_counted_of_what_the_people_did() -> void:
	var game = _game({"holdout": "roll", "holdout_chance": 100})
	for i in range(40):
		game.ledger.add(SimNoise.Level.NORMAL, 0.0, "bang")
	assert_gt(game.ledger.total, FieldHoldout.QUIET_NOISE)
	assert_eq(game.holdout.people_noise(), 0)
	assert_true(game.holdout.quiet_and_clear())
	# User decision 157: a stop where they only ran is a quiet one.
	for i in range(40):
		game.ledger.add(SimNoise.Level.NORMAL, 0.0, "run")
	assert_eq(game.holdout.people_noise(), 0)
	assert_true(game.holdout.quiet_and_clear())
	for i in range(FieldHoldout.QUIET_NOISE):
		game.ledger.add(SimNoise.Level.NORMAL, 0.0, "pry")
	assert_true(game.holdout.quiet_and_clear(), "twelve is still quiet")
	game.ledger.add(SimNoise.Level.NORMAL, 0.0, "pry")
	assert_false(game.holdout.quiet_and_clear())


# User decision 150: whoever was left at the train says when the quiet way
# out closes; nobody there, or a stop that cannot have it, and nothing is said.
func test_the_lookout_says_when_the_quiet_way_out_closes() -> void:
	var game = _game({"holdout": "roll", "holdout_chance": 100})
	var h = game.holdout
	assert_not_null(h.lookout(), "the squad starts by the train")
	h.watch(1.1)
	assert_false(h.told_noise, "quiet so far: nothing to say")
	for i in range(5):
		game.ledger.add(SimNoise.Level.LOUD, 0.0, "gun")
	h.watch(1.1)
	assert_true(h.told_noise)
	assert_string_contains(String(game.radio_wait["text"]), "떠날 때 붙들린다")
	assert_true(h.opens_on_leaving(), "and what it said is true")
	var train: Rect2i = game.data["train"]
	for i in range(FieldHoldout.CLEAR_TRACK + 1):
		game.zombies.spawn("dead", FieldGrid.center(Vector2i(train.end.x + 2 + i, train.position.y)))
	h.watch(1.1)
	assert_string_contains(String(game.radio_wait["text"]), "선로에 섰다")
	var alone = _game({"holdout": "roll", "holdout_chance": 100})
	for p in alone.squad + alone.crew:
		if p != alone.player:
			p.position += Vector3(0, 0, 40)
	for i in range(5):
		alone.ledger.add(SimNoise.Level.LOUD, 0.0, "gun")
	alone.holdout.watch(1.1)
	assert_false(alone.holdout.told_noise, "nobody left at the train: nobody to see it")
	var never = _game({"holdout": "roll", "holdout_chance": 0})
	for i in range(5):
		never.ledger.add(SimNoise.Level.LOUD, 0.0, "gun")
	never.holdout.watch(1.1)
	assert_false(never.holdout.told_noise, "a stop that cannot have it hears nothing")


func test_the_roll_is_the_same_for_a_seed_and_does_not_move_the_stops_dice() -> void:
	var plain = _game({"seed": 11})
	var a = _game({"seed": 11, "holdout": "roll"})
	var b = _game({"seed": 11, "holdout": "roll"})
	assert_eq(a.holdout.rolled, b.holdout.rolled)
	assert_eq(a.rng.state, plain.rng.state, "the stop's own dice are where they would be")


# User decision 150: one line anybody sees, from the kind of place, not the roll.
func test_the_risk_line_goes_by_the_kind_of_place() -> void:
	var game = _game({"holdout": "roll"})
	assert_eq(game.holdout.chance(), 10, "a freight yard: low")
	game.data["place_kind"] = "church"
	assert_eq(game.holdout.chance(), 5, "lower still")
	assert_eq(game.holdout.risk_word(), "낮다")
	game.data["place_kind"] = "freight"
	assert_string_contains(game.goal_text(), "버티기 위험: 낮다")
	game.data["place_kind"] = "lodge"
	assert_eq(game.holdout.risk_word(), "있다")
	game.data["place_kind"] = "mine"
	assert_eq(game.holdout.risk_word(), "높다")
	game.holdout.rolled = not game.holdout.rolled
	assert_eq(game.holdout.risk_word(), "높다", "whatever the roll was")


func test_a_map_with_doors_on_the_upper_side_only_or_none_still_holds() -> void:
	var game = _game({"holdout": "depart"})
	game.data["train_doors"] = {"upper": [Vector2i(40, 0), Vector2i(60, 0)]}
	game.depart()
	assert_eq(game.holdout.doors.size(), 2, "the upper side's")
	assert_eq(game.holdout.target(3), FieldGrid.center(Vector2i(60, 0)))
	var bare = _game({"holdout": "depart"})
	bare.data["train_doors"] = {}
	bare.depart()
	assert_true(bare.holdout.on, "the clock still runs")
	assert_eq(bare.holdout.target(0), FieldGrid.center(bare.horde_home()), "no door to walk to: where a horde always went")
	bare.holdout.tick(1.0)
	assert_string_contains(bare.goal_text(), "문 멀쩡 0")


func test_the_stops_time_limit_waits_for_a_held_train() -> void:
	var game = _game({"holdout": "start"})
	game.clock.elapsed = game.clock.LIMIT_SEC + 1.0
	game._check_end()
	assert_false(game.ended, "the train's own clock is the limit now")
