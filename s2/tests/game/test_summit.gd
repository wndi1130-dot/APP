extends "res://addons/gut/test.gd"
## The mountain pass (user decisions 176, 177, 180, 188): a kind of stop that
## is as likely to hold the train as the mine, likelier once what sleeps in
## the plough shed is woken; the plough's drives are loud to take off, and
## with the last of the four comes the core.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldActions = preload("res://game/field_actions.gd")
const FieldHoldout = preload("res://game/field_holdout.gd")
const SimNoise = preload("res://game/sim/noise.gd")

const DRIVES: Array[String] = ["plow_drive_1", "plow_drive_2", "plow_drive_3", "plow_drive_4"]


func _game(extra: Dictionary = {}):
	var game = FieldGame.new()
	var opts := {"seed": 5, "raiders": false, "auto_pause": false, "place": "summit_01", "holdout": "roll"}
	opts.merge(extra, true)
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	return game


func test_the_pass_is_a_kind_of_stop_and_as_likely_as_the_mine() -> void:
	for n in range(1, 6):
		assert_true(FieldMaps.has("summit_%02d" % n))
	var game = _game()
	assert_eq(game.place, "summit_01")
	assert_eq(game.data["place_kind"], "summit")
	assert_eq(game.holdout.chance(), 60)
	assert_eq(FieldHoldout.CHANCE["summit"], FieldHoldout.CHANCE["mine"])
	assert_eq(game.holdout.risk_word(), "높다")


func test_a_drive_is_six_points_so_the_third_is_heard() -> void:
	var game = _game()
	var p = game.player
	assert_eq(FieldActions.salvage_level("plow_drive_3"), SimNoise.Level.LOUD)
	assert_eq(FieldActions.salvage_level("shallow_rails"), SimNoise.Level.NORMAL)
	var heard: Array = []
	for id in DRIVES:
		game.actions.spot_default(p, id, "")
		game.actions._salvaged(p, id)
		heard.append(game.holdout.people_noise())
	assert_eq(heard, [6, 12, 18, 24])
	assert_lte(heard[1], FieldHoldout.QUIET_NOISE, "two are still quiet")
	assert_gt(heard[2], FieldHoldout.QUIET_NOISE, "the third is not")


func test_the_core_comes_with_the_last_of_the_four_drives() -> void:
	var game = _game()
	var p = game.player
	var before: int = int(p.items.get("scrap", 0))
	for i in 3:
		game.actions._salvaged(p, DRIVES[i])
	assert_eq(int(p.items.get("plow_core", 0)), 0, "three off: not yet")
	assert_eq(int(p.items.get("scrap", 0)) - before, 6)
	game.actions._salvaged(p, DRIVES[3])
	assert_eq(int(p.items.get("plow_core", 0)), 1)
	assert_eq(int(p.items.get("scrap", 0)) - before, 18, "two a drive and ten with the core")
	assert_eq(game.item_name("plow_core"), "제설기 코어")
	var rails: Dictionary = game.data["spots"]["shallow_rails"]
	assert_eq([rails["material"], int(rails["amount"])], ["scrap", 2], "the pass holds twenty in all")
	for box: Dictionary in game.data["containers"].values():
		assert_false(box["items"].has("scrap"), "no scrap in a box: " + box["id"])
	p.position = FieldGrid.center(game.data["spawns"]["train_door"][0])
	game.finish("departed")
	assert_has(game.receipt.to_dict()["items"]["gained"], "plow_core")


func test_waking_the_shed_makes_it_likelier_once() -> void:
	var game = _game()
	var h = game.holdout
	var inside: Array = game.zombies.list.filter(func(z): return bool(z.get("interior", false)))
	assert_eq(inside.size(), game.data["spawns"]["dead_shed"].size(), "those first put in the plough shed")
	assert_gt(inside.size(), 0)
	h.die = 70
	h.rolled = false
	inside[0]["state"] = "investigate"
	h.den_watch()
	assert_false(h.woke, "a sound alone wakes nothing")
	assert_eq(h.chance(), 60)
	var late: Dictionary = game.zombies.spawn("dead", inside[0]["pos"])
	late["state"] = "chase"
	h.den_watch()
	assert_false(h.woke, "one that came later is not of the shed")
	inside[0]["state"] = "chase"
	h.den_watch()
	assert_true(h.woke)
	assert_eq(h.chance(), 80)
	assert_true(h.rolled, "the same die against the new chance")
	assert_eq(h.risk_word(), "높다", "the word is of the kind")
	inside[1]["state"] = "chase"
	h.den_watch()
	assert_eq(h.chance(), 80, "once")
	assert_true(h.roll_note()["woke"])


func test_waking_is_counted_elsewhere_and_costs_nothing_there() -> void:
	var game = _game({"place": "mine_01"})
	var inside: Array = game.zombies.list.filter(func(z): return bool(z.get("interior", false)))
	if inside.is_empty():
		pass_test("this mine has none inside to wake")
		return
	inside[0]["state"] = "chase"
	game.holdout.den_watch()
	assert_true(game.holdout.woke, "the same measure")
	assert_eq(game.holdout.chance(), 60, "the mine stays as it was")
