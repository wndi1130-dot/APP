extends "res://addons/gut/test.gd"
## The loot tables and their rules (loot spec v1): one case per table, the
## dice fixed by seed. Nothing in the game reads these yet.

const R = preload("res://game/sim/loot_rules.gd")
const T = preload("res://game/sim/loot_tables.gd")
const Zombies = preload("res://game/actors/zombies.gd")
const Carry = preload("res://game/sim/carry.gd")
const W = preload("res://game/sim/weapons.gd")
const Sulehuf = preload("res://game/world/sulehuf_map.gd")


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _sulehuf() -> Dictionary:
	var data := {"containers": {}}
	Sulehuf._containers(data)
	return data["containers"]


func _known(entry: Dictionary) -> bool:
	if entry.has("ammo"):
		return entry["ammo"] in ["pistol", "shell"]
	if entry.has("tool"):
		return W.is_known(String(entry["tool"]))
	return Carry.ITEM_NAMES.has(String(entry["id"]))


func test_the_dead_keep_todays_pockets_and_draw_the_same_dice() -> void:
	assert_eq(T.BODY["dead"]["chance"], Zombies.LOOT_CHANCE)
	assert_eq(T.BODY["dead"]["table"], Zombies.LOOT_TABLE)
	# Today's roll (zombies.gd _roll_loot) done by hand on one rng, the rule on another.
	var a := _rng(62)
	var b := _rng(62)
	for i in range(300):
		var want: Array = []
		if a.randf() < Zombies.LOOT_CHANCE:
			var pick := a.randi_range(1, 10)
			for row in Zombies.LOOT_TABLE:
				pick -= int(row[0])
				if pick <= 0:
					var e: Dictionary = row[1].duplicate()
					e["n"] = a.randi_range(1, int(row[2]))
					want.append(e)
					break
		assert_eq(R.body_roll("dead", "", false, b), want)


func test_about_one_in_ten_of_the_dead_and_half_that_from_the_sewers() -> void:
	var rng := _rng(7)
	var dead := 0
	var horde := 0
	for i in range(4000):
		dead += mini(1, R.body_roll("dead", "", false, rng).size())
		horde += mini(1, R.body_roll("dead", "", true, rng).size())
	assert_between(dead, 330, 470, "about one in ten")
	assert_between(horde, 130, 270, "about half of that")


func test_a_padded_one_has_two_pockets_and_what_it_carries_says_where_it_worked() -> void:
	var rng := _rng(11)
	var shed_tools := 0
	var station_flares := 0
	var most := 0
	for i in range(2000):
		var shed := R.body_roll("clothed", "shed", false, rng)
		var station := R.body_roll("clothed", "station", false, rng)
		most = maxi(most, maxi(shed.size(), station.size()))
		for e: Dictionary in shed:
			assert_true(_known(e), str(e))
			assert_false(e.get("id", "") == "flare", "no railway flares in the shed table")
			if e.has("tool"):
				shed_tools += 1
				assert_eq(e["tool"], "crowbar")
		for e: Dictionary in station:
			assert_true(_known(e), str(e))
			assert_false(e.has("tool"), "the station ones carry no crowbar")
			if e.get("id", "") == "flare":
				station_flares += 1
	assert_eq(most, 2, "two pockets, no more")
	assert_gt(shed_tools, 0)
	assert_gt(station_flares, 0)
	# A padded one somewhere else uses the plain padded table.
	assert_eq(R.body_key("clothed", "church"), "clothed")
	assert_eq(R.body_key("fresh"), "dead", "no table of its own: the dead's")


func test_frozen_pockets_take_twice_as_long_and_padded_ones_longer_than_the_dead() -> void:
	assert_almost_eq(R.body_search_time("dead"), 3.0, 0.001)
	assert_almost_eq(R.body_search_time("frozen"), 6.0, 0.001)
	assert_almost_eq(R.body_search_time("clothed", "shed"), 4.5, 0.001)
	var rng := _rng(3)
	var cloth := 0
	for i in range(3000):
		for e: Dictionary in R.body_roll("frozen", "", false, rng):
			assert_true(_known(e))
			if e.get("id", "") == "cloth":
				cloth += 1
	assert_gt(cloth, 0, "a frozen rag now and then")


func test_every_container_of_the_first_stop_folds_as_the_building_spec_counts() -> void:
	var boxes := _sulehuf()
	var counts: Dictionary = {}
	var none: Array = []
	for id: String in boxes:
		if T.FIXED.has(id):
			continue
		var c: Dictionary = boxes[id]
		var k := R.container_kind(String(c["name"]))
		if k == "":
			none.append(c["name"])
		counts[k] = int(counts.get(k, 0)) + 1
	assert_eq(none, [], "every one of the forty has a kind")
	assert_eq(counts, {"kitchen": 11, "wardrobe": 7, "desk": 5, "shop": 2, "storage": 6, "toolbox": 1, "pharmacy": 1, "attic": 3, "toilet": 1, "junk": 2})


func test_the_expected_count_per_container_matches_the_spec_table() -> void:
	var want := {"kitchen": 2.0, "wardrobe": 2.0, "desk": 2.0, "shop": 2.75, "storage": 2.36, "toolbox": 2.0, "pharmacy": 2.57, "attic": 2.0, "toilet": 2.0, "junk": 2.0}
	for k: String in want:
		var sum := 0.0
		for v: float in R.expected_container(k).values():
			sum += v
		assert_almost_eq(sum, float(want[k]), 0.01, k)


func test_filling_the_map_is_the_same_for_a_seed_and_keeps_the_fixed_ones() -> void:
	var a := _sulehuf()
	var b := _sulehuf()
	var c := _sulehuf()
	a["sv_log_office"] = {"name": "역무실 선로 기록함", "items": ["document"], "pick": 25.0, "locked": true}
	var bell_before: Array = a["bell"]["items"].duplicate()
	assert_eq(R.fill(a, 5), 40, "thirty-nine, and the pharmacy store's extra")
	R.fill(b, 5)
	R.fill(c, 6)
	var differs := false
	for id: String in a:
		if id == "sv_log_office":
			continue
		assert_eq(a[id]["items"], b[id]["items"], id)
		if a[id]["items"] != c[id]["items"]:
			differs = true
		for item in a[id]["items"]:
			assert_true(Carry.ITEM_NAMES.has(String(item)), "%s in %s" % [item, id])
	assert_true(differs, "another seed, another stop")
	assert_eq(a["bell"]["items"], bell_before)
	assert_eq(a["ticket_safe"]["items"], ["luxury_pack", "luxury_pack"])
	assert_true(a["ticket_safe"]["locked"], "locks are not rolled")
	assert_eq(a["sv_log_office"]["items"], ["document"], "a goal box is left alone")
	var store: Array = a["pharmacy_store"]["items"]
	assert_eq(store.slice(0, 4), ["tweezers", "needle_thread", "needle_thread", "needle_thread"])
	assert_gt(store.size(), 4, "and the rest rolled as the counter")


func test_the_three_sets_give_less_and_more() -> void:
	var sums: Dictionary = {}
	for s: String in ["conservative", "base", "aggressive"]:
		var t := 0.0
		for k: String in T.CONTAINER_KINDS:
			for v: float in R.expected_container(k, s).values():
				t += v
		for v: float in R.expected_body("dead", "", true, s).values():
			t += v
		sums[s] = t
	assert_lt(float(sums["conservative"]), float(sums["base"]))
	assert_lt(float(sums["base"]), float(sums["aggressive"]))
	assert_eq(R.body_chance("dead", "", true, "conservative"), 0.0, "the sewers pay nothing on the careful set")


func test_what_is_left_behind_is_counted() -> void:
	assert_eq(R.left({"items": ["plank", "plank"]}), 2)
	assert_eq(R.left({}), 0)
