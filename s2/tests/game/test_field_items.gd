extends "res://addons/gut/test.gd"
## The field's named things (decision 423-8): a name and a picture when picked
## up, the old stock numbers on the train; the boxes dressed by their rooms, the
## pockets by their places, and a few finds of their own (P01, P08, P14, P19, P20,
## P27, P28). The new values are fixed here as the PR lists them.

const FieldItems = preload("res://game/sim/field_items.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const LootRules = preload("res://game/sim/loot_rules.gd")
const LootTables = preload("res://game/sim/loot_tables.gd")
const Carry = preload("res://game/sim/carry.gd")
const Receipt = preload("res://game/sim/receipt.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldGame = preload("res://game/field_game.gd")
const Person = preload("res://game/actors/person.gd")


func _names() -> Dictionary:
	var out: Dictionary = {}
	for id: String in FieldItems.ITEMS:
		out[FieldItems.item_name(id)] = true
	return out


func test_thirty_to_fifty_things_each_with_a_short_name_a_picture_and_a_weight() -> void:
	var names := _names()
	assert_between(names.size(), 30, 50, "named things picked up in the field")
	assert_between(FieldItems.RARE.size(), 6, 10, "and the named finds")
	for id: String in FieldItems.ITEMS.keys() + FieldItems.RARE.keys():
		assert_true(FieldItems.item_name(id).length() <= 9, "short: " + id)
		assert_gt(FieldItems.weight(id), 0.0, id)
		assert_true(HudIcons.PATHS.has(FieldItems.icon(id)), "a picture: %s (%s)" % [id, FieldItems.icon(id)])
		assert_true(Carry.item_weight(id) == FieldItems.weight(id), "the pack weighs it: " + id)
		var melt: Array = FieldItems.stock_of(id)
		assert_true(String(melt[0]) == "" or Receipt.STOCK_KEYS.has(melt[0]), "a stock the receipt knows: " + id)
	for id: String in FieldItems.ITEMS:
		assert_false(Carry.ITEM_WEIGHTS.has(id), "no clash with the old ids: " + id)


func test_a_thing_cut_from_a_bundle_keeps_its_worth_by_weight_times_its_state() -> void:
	assert_eq(FieldItems.stock_of("can_beans"), ["food", 0.5])
	assert_eq(FieldItems.stock_of("oats"), ["food", 0.75])
	assert_eq(FieldItems.stock_of("rusk"), ["food", 0.25])
	assert_eq(FieldItems.stock_of("meat_frozen"), ["food", 0.5], "frozen keeps on the train")
	assert_almost_eq(float(FieldItems.stock_of("apple_wilted")[1]), 0.3, 0.0001, "wilted 0.6")
	assert_eq(FieldItems.stock_of("meat_spoiled"), ["food", 0.0], "spoiled is nothing")
	assert_eq(FieldItems.stock_of("bread_moldy"), ["food", 0.0])
	assert_eq(FieldItems.stock_of("can_dented_bad"), ["food", 0.0], "the one that went off")
	assert_eq(FieldItems.stock_of("can_dented"), ["food", 0.5])
	assert_eq(FieldItems.stock_of("saline"), ["medicine", 0.75])
	assert_eq(FieldItems.stock_of("painting"), ["luxury", 0.75])
	assert_eq(FieldItems.stock_of("fuel_can"), ["coal", 1.0])
	assert_eq(FieldItems.stock_of("nails"), ["scrap", 0.5])
	assert_eq(FieldItems.stock_of("can_opener"), ["", 0.0], "a tool melts into nothing")
	assert_true(FieldItems.kept_by_name("can_opener") and FieldItems.kept_by_name("rare_violin"))
	assert_false(FieldItems.kept_by_name("can_beans"))
	# Both dented tins look alike until opened.
	assert_eq(FieldItems.item_name("can_dented_bad"), FieldItems.item_name("can_dented"))
	assert_eq(FieldItems.icon("can_dented_bad"), FieldItems.icon("can_dented"))


func test_a_bundle_weighs_one_on_average_so_a_pack_carries_as_much_as_before() -> void:
	for family: String in LootDress.NAMES:
		for table: String in LootDress.NAMES[family]:
			for row: Array in LootDress.NAMES[family][table]:
				assert_true(FieldItems.ITEMS.has(String(row[0])), "%s:%s %s" % [family, table, row[0]])
			if LootDress.LIGHT_TABLES.has("%s:%s" % [family, table]):
				continue
			assert_between(LootDress.mean_weight(family, table), 0.95, 1.05, "%s:%s" % [family, table])


func test_the_new_values_are_the_listed_ones() -> void:
	assert_eq(FieldItems.DENTED_BAD, 0.10, "survival_detail 3.5")
	assert_eq(FieldItems.OPEN_KNIFE_S, 10.0, "survival_detail 3.5")
	assert_eq(FieldItems.KNIFE_SLIP, 0.05, "survival_detail 3.5")
	assert_eq(FieldItems.SPILL, 0.5, "survival_detail 3.5")
	assert_eq([FieldItems.OPEN_OPENER_S, FieldItems.OPEN_BASH_S, FieldItems.OPEN_JAR_S, FieldItems.EAT_S, FieldItems.EAT_REST], [3.0, 4.0, 2.0, 3.0, 0.15])
	assert_eq([LootDress.BIG_PACK_CHANCE, LootDress.WATCH_CHANCE, LootDress.WATCH_SET_SHARE, LootDress.OPENER_CHANCE], [0.35, 0.30, 0.5, 0.60])
	assert_eq([LootDress.NAILS_CHANCE, LootDress.NAILS_MOST, LootDress.FUEL_CHANCE, LootDress.RARE_CHANCE, LootDress.CAP], [0.08, 4, 0.30, 0.25, 6])
	assert_eq([FieldGame.ALARM_DELAY_MIN, FieldGame.ALARM_DELAY_MAX, FieldGame.ALARM_RINGS, FieldGame.ALARM_EVERY], [60.0, 150.0, 4, 2.0])


func test_rooms_and_buildings_are_read_from_their_names() -> void:
	assert_eq(LootDress.room_of({"name": "부엌 상자"}), "kitchen")
	assert_eq(LootDress.room_of({"name": "안방 상자"}), "bedroom")
	assert_eq(LootDress.room_of({"name": "뒤 창고 상자"}), "storage")
	assert_eq(LootDress.room_of({"name": "저장 칸 상자"}), "pantry")
	assert_eq(LootDress.room_of({"name": "작업실 상자"}), "toolbox")
	assert_eq(LootDress.room_of({"name": "매장 상자"}), "shop")
	assert_eq(LootDress.room_of({"name": "약국 진열대"}), "clinic")
	assert_eq(LootDress.room_of({"name": "화장실 장"}), "bathroom")
	assert_eq(LootDress.room_of({"name": "광산 입구 상자"}), "storage", "광 alone, not a word inside another")
	assert_eq(LootDress.room_of({"name": "부엌 상자", "room": "toolbox"}), "toolbox", "a map's own room wins")
	assert_eq(LootDress.building_kind("얼음 낚시 움막"), "fish")
	assert_eq(LootDress.building_kind("얼음 창고"), "cold")
	assert_eq(LootDress.building_kind("의사 사택"), "clinic")
	assert_eq(LootDress.building_kind("주택 가"), "house")
	assert_eq(LootDress.building_kind("역사"), "")


func _house_map() -> Dictionary:
	return {"place_kind": "houses", "buildings": [{"name": "주택 가"}, {"name": "식료품점"}], "containers": {
		"k": {"name": "부엌 상자", "building": 0, "items": ["plank", "plank"], "locked": false, "searched": false},
		"b1": {"name": "안방 상자", "building": 0, "items": ["food_pack", "plank"], "locked": false, "searched": false},
		"b2": {"name": "안방 상자", "building": 0, "items": ["food_pack", "cloth"], "locked": false, "searched": false},
		"p": {"name": "저장 칸 상자", "building": 0, "items": ["luxury_pack", "document"], "locked": false, "searched": false},
		"safe": {"name": "금고", "building": 0, "items": ["med_box", "food_pack"], "locked": true, "searched": false},
		"goal": {"name": "기록함", "building": 0, "items": ["food_pack"], "locked": false, "pick": 20.0, "searched": false},
		"out": {"name": "판자 묶음", "building": -1, "items": ["food_pack", "plank"], "locked": false, "searched": false},
		"s1": {"name": "매장 상자", "building": 1, "items": ["food_pack", "food_pack", "scrap"], "locked": false, "searched": false},
	}}


func _counts(containers: Dictionary, ids: Array) -> Dictionary:
	var out: Dictionary = {}
	for id: String in ids:
		for item in containers[id]["items"]:
			var key: String = String(item)
			var r := FieldItems.row(key)
			if r.has("from"):
				key = String(r["from"])
			out[key] = int(out.get(key, 0)) + 1
	return out


func test_dressing_keeps_what_each_building_holds_and_names_every_bundle() -> void:
	var d := _house_map()
	var before := _counts(d["containers"], ["k", "b1", "b2", "p"])
	var report := LootDress.dress(d, 7)
	var c: Dictionary = d["containers"]
	var after := _counts(c, ["k", "b1", "b2", "p"])
	# The odds and ends are put in on top (loot_junk.gd).
	for rows: Array in LootDress.LootJunk.JUNK.values():
		for row: Array in rows:
			after.erase(String(row[0]))
	for f in ["found_big_pack", "wrist_watch", "wrist_watch_set", "can_opener", "nails", "fuel_can", "frying_pan", "broken_bottle"]:
		after.erase(f)
	for rare: String in FieldItems.RARE:
		after.erase(rare)
	# A blueprint piece (S1 domestic 5.2) is put in on top as well.
	for id: String in FieldItems.ITEMS:
		if FieldItems.fragment_of(id) != "":
			after.erase(id)
	# The parts stuff and the clothes are finds too (decision 426 D2, 423 card 2).
	for found: String in ["gears", "springs", "wire_coil"] + FieldItems.Wear.KINDS.keys():
		after.erase(found)
	assert_eq(after, before, "the same bundles and things, only moved")
	for id: String in c:
		if id == "goal":
			continue
		for item in c[id]["items"]:
			assert_false(FieldItems.BUNDLES.has(String(item)), "named: %s in %s" % [item, id])
	assert_eq(c["goal"]["items"], ["food_pack"], "a goal box is left alone")
	assert_true(c["safe"]["locked"])
	assert_eq(c["safe"]["items"].size() >= 2, true, "a locked box keeps its own things")
	assert_eq(FieldItems.row(String(c["safe"]["items"][0])).get("from", ""), "med_box", "named, not moved")
	assert_eq(c["out"]["items"].size() >= 2, true, "a box in no building keeps its own")
	assert_has(c["p"]["items"], "document", "what is not a bundle stays put")
	assert_gt(int(report["named"]), 0)
	# The shop's food is named as a shop's.
	for item in c["s1"]["items"]:
		var from: String = String(FieldItems.row(String(item)).get("from", ""))
		if from == "food_pack":
			assert_true(_in_table("food", "shop", String(item)), String(item))


func _in_table(family: String, table: String, id: String) -> bool:
	if id == "can_dented_bad":
		id = "can_dented"
	for row: Array in LootDress.NAMES[family][table]:
		if row[0] == id:
			return true
	return false


func test_the_same_seed_dresses_the_same_and_another_seed_another_way() -> void:
	var a := FieldMaps.build("houses_01")
	var b := FieldMaps.build("houses_01")
	var c := FieldMaps.build("houses_01")
	LootDress.dress(a, 11)
	LootDress.dress(b, 11)
	LootDress.dress(c, 12)
	var differs := false
	for id: String in a["containers"]:
		assert_eq(a["containers"][id]["items"], b["containers"][id]["items"], id)
		if a["containers"][id]["items"] != c["containers"][id]["items"]:
			differs = true
	assert_true(differs)


func test_kitchens_hold_the_food_and_bedrooms_come_up_empty_more_often() -> void:
	# Card L (decision 442): a kitchen's spare counters, cupboards and fridge are boxes too,
	# empty until the deal, so per box a kitchen now often comes up empty. Within a house that
	# has both rooms, the food is in the kitchen and a bedroom box seldom holds any.
	var seen: Dictionary = {}
	var food_in: Dictionary = {}
	var bedroom_empty := 0
	# houses_01 holds only planks (by-products, field_unified 4장): two that hold food too.
	for run in [["houses_04", 1], ["houses_04", 2], ["houses_06", 1], ["houses_06", 2]]:
		var d := FieldMaps.build(String(run[0]))
		LootDress.dress(d, int(run[1]))
		var has: Dictionary = {}
		for id: String in d["containers"]:
			var c: Dictionary = d["containers"][id]
			has["%d|%s" % [int(c.get("building", -1)), LootDress.room_of(c)]] = true
		for id: String in d["containers"]:
			var c: Dictionary = d["containers"][id]
			var room := LootDress.room_of(c)
			var b := int(c.get("building", -1))
			if not (room in ["kitchen", "bedroom"] and has.has("%d|kitchen" % b) and has.has("%d|bedroom" % b)):
				continue
			seen[room] = int(seen.get(room, 0)) + 1
			var food := 0
			for item in c["items"]:
				if FieldItems.group(String(item)) == "food":
					food += 1
			food_in[room] = int(food_in.get(room, 0)) + food
			if room == "bedroom" and food == 0:
				bedroom_empty += 1
	assert_true(seen.has("kitchen") and seen.has("bedroom"), str(seen))
	assert_gt(int(food_in.get("kitchen", 0)), int(food_in.get("bedroom", 0)) * 4, "the food is in the kitchen (%s)" % str(food_in))
	assert_gt(float(bedroom_empty) / float(seen["bedroom"]), 0.8, "a bedroom box seldom holds food")


func test_a_named_find_turns_up_now_and_then_at_most_once_a_stop() -> void:
	var stops := 0
	for s in range(1, 201):
		var d := _house_map()
		var r := LootDress.dress(d, s)
		var n := 0
		for id: String in d["containers"]:
			for item in d["containers"][id]["items"]:
				if FieldItems.RARE.has(String(item)):
					n += 1
					assert_true((FieldItems.RARE[String(item)]["places"] as Array).has("houses"), String(item))
		assert_true(n <= 1, "one at most")
		if n == 1:
			stops += 1
			assert_ne(String(r["rare"]), "")
	assert_between(stops, 30, 70, "about one stop in four")


func test_a_pack_or_a_watch_is_found_only_where_people_lived() -> void:
	var d := {"place_kind": "freight", "buildings": [{"name": "화물 창고"}], "containers": {
		"a": {"name": "안방 상자", "building": 0, "items": ["cloth"], "locked": false},
		"b": {"name": "뒤 창고 상자", "building": 0, "items": ["plank"], "locked": false}}}
	for s in range(1, 60):
		var dd: Dictionary = d.duplicate(true)
		LootDress.dress(dd, s)
		for id: String in dd["containers"]:
			for item in dd["containers"][id]["items"]:
				assert_false(["found_big_pack", "wrist_watch", "wrist_watch_set"].has(String(item)), "not by the line: %s" % item)


func test_the_pockets_say_where_the_dead_were_found() -> void:
	var buildings := [{"name": "약국", "rect": Rect2i(0, 0, 10, 10)}, {"name": "주택 가", "rect": Rect2i(40, 0, 10, 10)}, {"name": "역사", "rect": Rect2i(80, 0, 10, 10)}]
	assert_eq(LootRules.place_at(buildings, Vector2i(5, 5)), "hospital")
	assert_eq(LootRules.place_at(buildings, Vector2i(45, 5)), "house")
	assert_eq(LootRules.place_at(buildings, Vector2i(85, 5)), "station", "the padded ones' places first")
	assert_eq(LootRules.body_key("dead", "hospital"), "dead_hospital")
	assert_eq(LootRules.body_key("clothed", "hospital"), "clothed", "no padded table of its own")
	assert_eq(LootRules.body_key("frozen", "house"), "frozen")
	for key in ["dead_hospital", "dead_workshop", "dead_shop", "dead_house", "dead_farm"]:
		var row: Dictionary = LootTables.BODY[key]
		assert_eq([row["chance"], row["rolls"], row["search"]], [0.10, 1, 3.0], "as often and as quick as the dead's: " + key)
		for r: Array in row["table"]:
			var e: Dictionary = r[1]
			assert_true(e.has("ammo") or Carry.ITEM_WEIGHTS.has(String(e.get("id", ""))) or FieldItems.has(String(e.get("id", ""))), str(e))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var watches := 0
	for i in range(3000):
		for e: Dictionary in LootRules.body_roll("dead", "house", false, rng):
			if String(e.get("id", "")).begins_with("wrist_watch"):
				watches += 1
	assert_gt(watches, 0, "a watch now and then on the dead of a house")


func test_a_padded_ones_bundle_comes_named_and_the_dice_are_the_same() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 21
	b.seed = 21
	for i in range(500):
		var x := LootRules.body_roll("clothed", "station", false, a)
		var y := LootRules.body_roll("clothed", "station", false, b)
		assert_eq(x, y)
		for e: Dictionary in x:
			assert_ne(String(e.get("id", "")), "luxury_pack", "named in the pocket")
	assert_eq(a.state, b.state)


func test_opening_a_tin_wants_an_opener_a_knife_or_a_blow() -> void:
	var opener := FieldItems.eat_plan("can_beans", {"opener": true})
	assert_true(opener["ok"])
	assert_almost_eq(float(opener["seconds"]), 6.0, 0.001)
	var knife := FieldItems.eat_plan("can_beans", {"knife": true})
	assert_almost_eq(float(knife["seconds"]), 13.0, 0.001, "ten seconds with a knife")
	assert_almost_eq(float(knife["slip"]), 0.05, 0.0001)
	var blow := FieldItems.eat_plan("can_meat", {"blunt": true})
	assert_true(blow["ok"] and blow["loud"])
	assert_almost_eq(float(blow["spill"]), 0.5, 0.0001, "half on the floor")
	assert_false(FieldItems.eat_plan("can_meat", {})["ok"], "nothing to open it with")
	assert_false(FieldItems.eat_plan("meat_frozen", {"opener": true})["ok"], "frozen wants a fire")
	assert_false(FieldItems.eat_plan("oats", {})["ok"], "a sack wants a pot")
	assert_false(FieldItems.eat_plan("meat_spoiled", {})["ok"])
	assert_true(FieldItems.eat_plan("hardtack", {})["ok"])
	assert_true(FieldItems.eat_plan("jar_jam", {})["ok"], "a jar opens by hand")
	assert_true(FieldItems.eat_result("can_dented_bad", 0.0)["bad"], "found out only when opened")
	assert_almost_eq(float(FieldItems.eat_result("can_beans", 0.5)["rest"]), 0.075, 0.0001)


func test_a_bigger_pack_is_worn_at_once_and_one_no_bigger_goes_in_the_pack() -> void:
	var p := Person.new()
	p.bag = "pack"
	p.add_item("found_big_pack")
	assert_eq(p.bag, "big_pack")
	assert_false(p.items.has("found_big_pack"))
	p.add_item("found_big_pack")
	assert_eq(int(p.items.get("found_big_pack", 0)), 1, "a second one is carried")
	p.free()


func _game(extra: Dictionary = {}) -> Node:
	var game = FieldGame.new()
	var opts := {"seed": 5, "raiders": false, "auto_pause": false}
	opts.merge(extra, true)
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	return game


func test_the_stop_starts_with_named_things_and_they_melt_on_the_train() -> void:
	var game = _game()
	for id: String in game.data["containers"]:
		var c: Dictionary = game.data["containers"][id]
		if c.has("pick"):
			continue
		for item in c["items"]:
			assert_false(FieldItems.BUNDLES.has(String(item)), "named: %s in %s" % [item, id])
	assert_eq(game.item_name("can_beans"), "콩 통조림")
	assert_eq(game.item_icon("can_beans"), "it_can")
	for q in game.squad + game.crew:
		q.items.clear()
	game.unloaded = {"can_beans": 2, "oats": 1, "meat_spoiled": 1, "painkillers": 2, "cigarettes": 1, "rare_violin": 1, "can_opener": 1, "fuel_can": 1}
	game.finish("departed")
	var d: Dictionary = game.receipt.to_dict()
	var stock: Dictionary = d["stock"]
	assert_eq(int(stock.get("food", 0)), 2, "1.0 + 0.75 + 0 rounds to 2")
	assert_eq(int(stock.get("medicine", 0)), 1, "two painkillers, 0.5 each")
	assert_eq(int(stock.get("luxury", 0)), 2, "0.25 + 1.5")
	assert_has(d["items"]["gained"], "rare_violin")
	assert_has(d["items"]["gained"], "can_opener")
	assert_eq(game.receipt.problems(), [] as Array[String])


func test_the_old_bundles_stay_when_dressing_is_off() -> void:
	var game = _game({"loot_dress": false})
	var bundles := 0
	for id: String in game.data["containers"]:
		for item in game.data["containers"][id]["items"]:
			if FieldItems.BUNDLES.has(String(item)):
				bundles += 1
	assert_gt(bundles, 0)


func test_a_set_watch_rings_later_unless_switched_off() -> void:
	var game = _game()
	game.zombies.list.clear()
	var p = game.player
	p.add_item("wrist_watch_set")
	game._watch_named()
	assert_eq(game.alarms.size(), 1)
	assert_true(game.alarm_set())
	var at: float = float(game.alarms[0]["at"])
	assert_between(at - game.clock.elapsed, 60.0, 150.0)
	var heard: int = game.ledger.sound_events
	game.clock.elapsed = at + 0.1
	game._watch_named()
	assert_eq(game.ledger.sound_events, heard + 1, "it rings at the one who carries it")
	for i in range(FieldGame.ALARM_RINGS):
		game.clock.elapsed += FieldGame.ALARM_EVERY + 0.01
		game._watch_named()
	assert_eq(game.ledger.sound_events, heard + FieldGame.ALARM_RINGS)
	assert_false(p.items.has("wrist_watch_set"), "rung out")
	assert_eq(int(p.items.get("wrist_watch", 0)), 1)
	p.add_item("wrist_watch_set")
	game._watch_named()
	game.alarm_off()
	assert_false(game.alarm_set())
	assert_eq(int(p.items.get("wrist_watch", 0)), 2, "one key: switched off and kept")


func test_eating_in_the_field_takes_a_while_and_rests_a_little() -> void:
	var game = _game()
	game.zombies.list.clear()
	var p = game.player
	p.hands = []
	p.body.exhaustion = 0.5
	p.add_item("hardtack")
	game.eat(p, "hardtack")
	assert_eq(p.action, "eat")
	assert_almost_eq(p.action_total, FieldItems.EAT_S, 0.001)
	p.action_t = 0.001
	game._update_person(p, 0.1)
	assert_false(p.items.has("hardtack"))
	assert_lt(p.body.exhaustion, 0.5)
	p.add_item("can_beans")
	game.eat(p, "can_beans")
	assert_eq(p.action, "", "no opener, no blade, nothing to hit it with")
	assert_eq(int(p.items.get("can_beans", 0)), 1)
