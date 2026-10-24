extends "res://addons/gut/test.gd"
## Going through the pockets of one that lies there (user 2026-10-11): the
## dead now and then have a small thing, a raider has what it carried, and the
## three seconds it takes are spent with the hands busy.

const FieldGame = preload("res://game/field_game.gd")
const SimNoise = preload("res://game/sim/noise.gd")

var game
var p


func _start(extra: Dictionary = {}) -> void:
	game = FieldGame.new()
	var opts := {"seed": 5, "raiders": false, "auto_pause": false}
	opts.merge(extra, true)
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	p = game.player
	p.position = game.lift(Vector2i(60, 7), 0)
	for q in game.squad:
		if q != p:
			q.position = game.lift(Vector2i(30, 7), 0)


func _dead_at(dx: float) -> Dictionary:
	return game.zombies.spawn("dead", p.position + Vector3(dx, 0, 0))


func _labels() -> Array:
	return game.actions._near_things(p).map(func(row) -> String: return row["label"])


func _work(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		game._update_person(p, 0.1)
		t += 0.1


func test_pockets_are_rolled_once_and_seldom_hold_anything() -> void:
	_start()
	var with := 0
	for i in range(400):
		var z := _dead_at(1.0)
		assert_false(z.has("loot"), "nothing is rolled for one still standing")
		game.zombies.knock_down(z)
		var first: Array = z["loot"].duplicate(true)
		z["state"] = "wander"
		game.zombies.knock_down(z)
		game.zombies.kill(z)
		assert_eq(z["loot"], first, "knocking it down again rolls nothing new")
		if not first.is_empty():
			with += 1
			assert_eq(first.size(), 1, "one small thing")
			assert_between(int(first[0]["n"]), 1, 2)
	assert_between(with, 20, 65, "about one in ten")


func test_a_standing_one_is_not_offered_and_a_fallen_one_is() -> void:
	_start()
	var z := _dead_at(1.0)
	assert_does_not_have(_labels(), "품 뒤지기")
	game.zombies.knock_down(z)
	assert_has(_labels(), "품 뒤지기")


func test_three_seconds_then_the_small_thing_is_yours_and_it_is_not_offered_again() -> void:
	_start()
	var z := _dead_at(1.0)
	game.zombies.kill(z)
	game.zombies.set_loot(z, [{"ammo": "pistol", "n": 2}, {"id": "bandage", "n": 1}])
	var rounds: int = int(game.ammo["pistol"])
	var bands: int = int(p.items.get("bandage", 0))
	game.actions.search_body(p, int(z["id"]))
	assert_eq(p.action, "loot")
	assert_almost_eq(p.action_total, game.actions.BODY_SEARCH_TIME, 0.001)
	_work(2.5)
	assert_eq(int(game.ammo["pistol"]), rounds, "not yet")
	_work(1.0)
	assert_eq(p.action, "")
	assert_eq(int(game.ammo["pistol"]), rounds + 2, "rounds, not a handful")
	assert_eq(int(p.items.get("bandage", 0)), bands + 1)
	assert_does_not_have(_labels(), "품 뒤지기")
	game.actions.search_body(p, int(z["id"]))
	assert_eq(p.action, "", "nothing to go through twice")
	assert_eq(game.telemetry.bodies, {"tried": 1, "found": 1})


func test_most_have_nothing_and_the_time_is_spent_all_the_same() -> void:
	_start()
	var z := _dead_at(1.0)
	game.zombies.kill(z)
	game.zombies.set_loot(z, [])
	game.actions.search_body(p, int(z["id"]))
	assert_eq(p.action, "loot")
	_work(3.5)
	assert_true(z["searched"])
	assert_eq(game.telemetry.bodies, {"tried": 1, "found": 0})


func test_if_it_gets_up_meanwhile_the_hands_come_away_empty() -> void:
	_start()
	var z := _dead_at(1.0)
	game.zombies.knock_down(z)
	game.zombies.set_loot(z, [{"id": "bandage", "n": 1}])
	var bands: int = int(p.items.get("bandage", 0))
	game.actions.search_body(p, int(z["id"]))
	_work(1.0)
	z["state"] = "wander"
	_work(2.5)
	assert_eq(int(p.items.get("bandage", 0)), bands)
	assert_false(z.get("searched", false), "it still has it")
	assert_eq(int(game.telemetry.bodies["tried"]), 0)


func test_a_grab_stops_the_search() -> void:
	_start()
	var z := _dead_at(1.0)
	game.zombies.kill(z)
	game.zombies.set_loot(z, [{"id": "bandage", "n": 1}])
	game.actions.search_body(p, int(z["id"]))
	p.cancel_action()   # what a grab does to any work (field_combat)
	_work(3.5)
	assert_false(z.get("searched", false))


func test_a_raider_keeps_its_things_until_searched_and_a_companion_drops_them() -> void:
	_start({"raiders": true})
	assert_gt(game.raiders.size(), 0)
	var r = null
	for q in game.raiders:
		if not q.hands.is_empty() and r == null:
			r = q
	assert_not_null(r)
	var gun: String = r.hands[0]["id"]
	r.items = {"bandage": 1}
	r.position = p.position + Vector3(1.0, 0, 0)
	var on_ground: int = game.ground_items.size()
	game.on_person_died(r)
	assert_eq(game.ground_items.size(), on_ground, "nothing falls out of a raider")
	var z: Dictionary = game.zombies.find(int(r.brain["rising_id"]))
	assert_true(game.zombies.lootable(z))
	assert_eq(z["loot"].map(func(row) -> String: return row["id"]), [gun, "bandage"])
	p.hands = []
	p.set_weapon_slots(p.hands)
	game.actions.search_body(p, int(z["id"]))
	_work(3.5)
	assert_eq(p.hands.size(), 1)
	assert_eq(p.hands[0]["id"], gun, "the gun it held")
	# A companion's things fall to the ground as before; its body is not gone through.
	var ally = null
	for q in game.squad:
		if q != p:
			ally = q
			break
	ally.items = {"bandage": 2}
	on_ground = game.ground_items.size()
	game.on_person_died(ally)
	assert_eq(game.ground_items.size(), on_ground + 1)
	assert_false(game.zombies.lootable(game.zombies.find(int(ally.brain["rising_id"]))))


func test_the_padded_ones_by_the_shed_carry_its_things_and_a_crowbar_comes_to_hand() -> void:
	_start()
	var at: Vector3 = game.lift(Vector2i(142, 16), 0)
	var tools := 0
	var scrap := 0
	for i in range(300):
		var z: Dictionary = game.zombies.spawn("clothed", at)
		game.zombies.knock_down(z)
		for row: Dictionary in z["loot"]:
			assert_false(row.get("id", "") == "flare", "the station's things are not in the shed")
			if row.has("weapon"):
				tools += 1
				assert_eq(row["weapon"]["id"], "crowbar")
			if row.get("id", "") == "scrap":
				scrap += 1
	assert_gt(tools, 0)
	assert_gt(scrap, 0)
	var z: Dictionary = game.zombies.spawn("clothed", p.position + Vector3(1.0, 0, 0))
	game.zombies.kill(z)
	game.zombies.set_loot(z, [{"id": "crowbar", "n": 1, "weapon": {"id": "crowbar", "quality": "factory", "condition": 0.7, "loaded": 0}}])
	p.hands = []
	p.set_weapon_slots(p.hands)
	game.actions.search_body(p, int(z["id"]))
	_work(4.5)  # a padded coat: four seconds (user decision 407 B5)
	assert_eq(p.hands.size(), 1)
	assert_eq(p.hands[0]["id"], "crowbar")
	assert_true(game.actions.has_pry(p), "and the locked boxes open to it")


func test_the_sewer_ones_carry_about_half_as_often() -> void:
	_start()
	var plain := 0
	var horde := 0
	for i in range(1500):
		var a := _dead_at(1.0)
		game.zombies.knock_down(a)
		plain += mini(1, a["loot"].size())
		var b: Dictionary = game.zombies.spawn("dead", p.position + Vector3(1.0, 0, 0), {"horde": 0, "target": p.position})
		game.zombies.knock_down(b)
		horde += mini(1, b["loot"].size())
	assert_between(plain, 110, 200)
	assert_between(horde, 40, 110)


func test_the_frozen_and_the_padded_take_longer_than_a_plain_body() -> void:
	_start()
	var want := {"dead": 3.0, "frozen": 5.0, "clothed": 4.0}
	for kind: String in want:
		var z: Dictionary = game.zombies.spawn(kind, p.position + Vector3(1.0, 0, 0))
		game.zombies.kill(z)
		game.zombies.set_loot(z, [{"id": "bandage", "n": 1}])
		game.actions.search_body(p, int(z["id"]))
		assert_eq(p.action, "loot", kind)
		assert_almost_eq(p.action_total, float(want[kind]), 0.001, kind)
		p.cancel_action()


func test_searching_a_container_is_heard_once_at_once_and_every_four_seconds() -> void:
	# User decision 407 B4: quiet (3 m, indoors 1.5 m) every four seconds of the search.
	_start()
	var id := ""
	for key in game.data["containers"]:
		var c: Dictionary = game.data["containers"][key]
		if not c["locked"] and not c["searched"]:
			id = key
			break
	assert_ne(id, "")
	game.data["containers"][id]["search"] = 20.0
	# A search starts only within reach of the box: stand on its cell first.
	var box: Dictionary = game.data["containers"][id]
	p.position = game.lift(box["cell"], int(box.get("level", 0)))
	game.sounds.clear()
	game.actions.search(p, id)
	_work(9.0)
	var heard: Array = game.sounds.filter(func(s) -> bool: return s["tag"] == "search")
	assert_eq(heard.size(), 3, "at the start, at four and at eight seconds")
	assert_eq(int(heard[0]["level"]), SimNoise.Level.QUIET)
	p.cancel_action()
	game.sounds.clear()
	_work(5.0)
	assert_eq(game.sounds.filter(func(s) -> bool: return s["tag"] == "search").size(), 0, "a stopped search is silent")
