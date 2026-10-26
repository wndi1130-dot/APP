extends "res://addons/gut/test.gd"
## A building's alarm (gap audit J17): breaking in may set it off, once a
## building; a key never does. It rings loud and far for a good while, only
## its first ring counts on the score, and the dead it calls stay about
## there. A building's door about to give sounds lower.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const AlarmRules = preload("res://game/sim/alarm_rules.gd")


func _game(seed: int, place: String = "houses_01"):
	var game = FieldGame.new()
	game.opts = {"seed": seed, "raiders": false, "auto_pause": false, "place": place, "arrival_horde": false}
	add_child_autofree(game)
	game.set_process(false)
	return game


## The first building of this kind on the map and one of its doors.
func _building_door(game, kind: String) -> Array:
	for c: Vector2i in game.grid.doors:
		var b: int = int(game.grid.doors[c].get("building", -1))
		if b >= 0 and b < game.data["buildings"].size() and AlarmRules.kind_of(game.data["buildings"][b]) == kind:
			return [b, c]
	return [-1, Vector2i.ZERO]


## A seed under which building b's alarm goes off (or not).
func _seed_for(b: int, role: String, on: bool) -> int:
	for s in range(1, 400):
		if AlarmRules.goes_off(s, b, role) == on:
			return s
	return -1


func test_the_chance_is_the_building_s_and_the_roll_its_own() -> void:
	assert_gt(AlarmRules.chance("shop"), AlarmRules.chance("house"))
	assert_eq(AlarmRules.chance("shed"), 0.0)
	assert_eq(AlarmRules.kind_of({"name": "빵집"}), "shop")
	assert_eq(AlarmRules.kind_of({"name": "화물 창고"}), "shed")
	assert_eq(AlarmRules.goes_off(5, 2, "shop"), AlarmRules.goes_off(5, 2, "shop"))
	var on := 0
	for s in range(1, 1001):
		if AlarmRules.goes_off(s, 0, "shop"):
			on += 1
	assert_almost_eq(on / 1000.0, AlarmRules.chance("shop"), 0.06)
	var rings := AlarmRules.rings(10.0)
	assert_eq(rings[0], 10.0)
	assert_eq(rings.size(), int(ceil(AlarmRules.RING_S / AlarmRules.RING_EVERY_S)))


func test_it_rings_loud_and_far_and_only_its_first_ring_counts() -> void:
	var probe = _game(1)
	var bd: Array = _building_door(probe, "shop")
	assert_gte(bd[0], 0, "the houses have a shop")
	var s := _seed_for(bd[0], "shop", true)
	var game = _game(s)
	var at: Vector3 = FieldGrid.center(bd[1])
	assert_true(game.building_alarms.broken_into(bd[0], bd[1]))
	var total_before: int = game.ledger.total
	var t := 0.0
	while t < AlarmRules.RING_EVERY_S * 2.5:
		game._step(0.1)
		t += 0.1
	assert_eq(int(game.ledger.by_action["building_alarm"]["events"]), 1)
	assert_gte(int(game.ledger.by_action["building_alarm_ring"]["events"]), 2)
	var pts := 0
	for e: Dictionary in game.ledger.history:
		if String(e["tag"]).begins_with("building_alarm"):
			pts += SimNoise.tag_score(int(e["level"]), String(e["tag"]))
	assert_eq(pts, SimNoise.score(SimNoise.Level.LOUD), "the first ring only")
	assert_gte(game.ledger.total - total_before, pts)
	assert_gt(float(game.ledger.by_action["building_alarm"]["max_radius"]), SimNoise.radius(SimNoise.Level.LOUD, game.grid.indoor(bd[1])) * game.weather.sound_mult(false) * (AlarmRules.REACH - 0.1), "twice a loud sound's reach")
	assert_true(game.audio.has("building_alarm"), "its bell is in")
	assert_eq(game.audio.last_tag_group, "building_alarm", "and it is what is heard")
	var called := 0
	for z in game.zombies.list:
		if z["state"] == "investigate" and (z["target"] as Vector3).distance_to(at) < 0.01:
			called += 1
	assert_gt(called, 0, "the dead turn for it")


func test_a_building_rolls_once_and_a_key_never_sets_it_off() -> void:
	var probe = _game(1)
	var bd: Array = _building_door(probe, "shop")
	var s := _seed_for(bd[0], "shop", false)
	var game = _game(s)
	assert_false(game.building_alarms.broken_into(bd[0], bd[1]))
	assert_true(game.building_alarms.decided.has(bd[0]))
	# Broken into again under any seed later: it was decided the first time.
	game.building_alarms.decided[bd[0]] = false
	assert_false(game.building_alarms.broken_into(bd[0], bd[1]))
	assert_false(game.building_alarms.any_ringing())
	var other = _game(_seed_for(bd[0], "shop", true))
	var door: Dictionary = other.grid.doors[bd[1]]
	door["state"] = "closed"
	other.actions._set_door(bd[1], "open")
	assert_false(other.building_alarms.decided.has(bd[0]), "opened as a door is, not broken into")


func test_a_door_about_to_give_sounds_lower() -> void:
	var game = _game(3)
	var bd: Array = _building_door(game, "house")
	if bd[0] < 0:
		bd = _building_door(game, "shop")
	var door: Dictionary = game.grid.doors[bd[1]]
	door["state"] = "closed"
	door["hp"] = 8
	game.audio.on_sound(FieldGrid.center(bd[1]), SimNoise.Level.NORMAL, "bang")
	door["hp"] = 2
	game.audio.on_sound(FieldGrid.center(bd[1]), SimNoise.Level.NORMAL, "bang")
	assert_eq(game.audio.door_creaks, [false, true])
