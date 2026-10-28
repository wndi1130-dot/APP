extends "res://addons/gut/test.gd"
## 파밍 손맛 나단계 (decision 423): a building's key on its dead (P12), what is
## grabbed to hit with (P23), what is made there and then (P22), what comes up
## out of the snow (card 11), the note of the next stop (card 10), and the
## weight of going through the dead (card 12). New values fixed here.

const FieldItems = preload("res://game/sim/field_items.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const W = preload("res://game/sim/weapons.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldActions = preload("res://game/field_actions.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const BuildingRules = preload("res://game/sim/building_rules.gd")
const FieldReturn = preload("res://game/politics/field_return.gd")
const FieldHud = preload("res://game/ui/field_hud.gd")
const V = preload("res://tests/politics/field_vectors.gd")


func _game(extra: Dictionary = {}) -> Node:
	var game = FieldGame.new()
	var opts := {"seed": 5, "raiders": false, "auto_pause": false}
	opts.merge(extra, true)
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	return game


func _finish(game, p) -> void:
	p.action_t = 0.001
	game._update_person(p, 0.1)


func test_the_new_values_are_the_listed_ones() -> void:
	assert_eq([FieldActions.KEY_TIME, FieldActions.BOARD_TIME, FieldActions.BOARD_HP, FieldActions.STAKE_TIME, FieldActions.BODY_SEEN_M], [1.5, 8.0, 3, 6.0, 8.0])
	assert_eq([FieldGame.GLINT_REACH, FieldGame.GLINT_DARK, FieldGame.GLINT_STORM, FieldGame.THROW_REACH, FieldGame.THROW_FLIGHT, FieldGame.LURE_MARK_S], [3.0, 0.6, 0.5, 8.0, 0.6, 3.0])
	assert_eq([LootDress.PAN_CHANCE, LootDress.BOTTLE_CHANCE, LootDress.GLINTS, LootDress.NOTE_CHANCE], [0.50, 0.40, 6, 0.35])
	assert_eq(LootDress.KEY_WAYS, [["dead", 6], ["snow", 2], ["box", 2]])
	assert_eq(FieldReturn.BODY_SEARCH_REL, {"tail": 0.0, "medtech": -1.0, "guard": 0.0, "front": -1.0, "engine": 0.0})
	for id: String in W.IMPROVISED:
		var d: Dictionary = W.IMPROVISED[id]
		assert_true(W.is_known(id) and W.breaks(id), id)
		assert_eq(d["kind"], "melee", id)
		assert_lt(float(d["head_kill"]), float(W.DATA["knife"]["head_kill"]), "weaker than a knife: " + id)
	assert_eq(W.DATA.size(), 7, "the weapon table itself is as it was")
	assert_eq([W.IMPROVISED["broken_bottle"]["wear"], W.IMPROVISED["wood_stake"]["wear"], W.IMPROVISED["frying_pan"]["wear"]], [0.25, 0.2, 0.05])
	var stats := {}
	for id: String in W.IMPROVISED:
		var d: Dictionary = W.IMPROVISED[id]
		stats[id] = [d["hands"], d["weight"], d["reach"], d["swing"], d["windup"], d["head_base"], d["head_kill"], d["knockdown"], d["blade"], d["fatigue"], d["feet_from"]]
	assert_eq(stats, {
		"frying_pan": [1, 1.5, 1.0, 0.6, 0.18, 0.24, 0.45, 0.45, false, 0.007, 0.1],
		"broken_bottle": [1, 0.5, 0.8, 0.4, 0.08, 0.25, 0.6, 0.05, true, 0.004, 0.5],
		"wood_stake": [1, 1.0, 1.1, 0.5, 0.12, 0.28, 0.7, 0.15, true, 0.005, 0.5]})
	assert_eq(str(LootDress.GLINT_KINDS), str([["wood", 3], ["scrap", 2], ["hare_frozen", 1]]))
	assert_eq(",".join(LootDress.STASH), "food_pack,food_pack,med_box")
	assert_eq(LootDress.NOTE_SPOTS.size(), 5)
	assert_eq([FieldItems.KEY_ROW["weight"], FieldItems.row("can_empty")["weight"], FieldItems.row("note_map")["weight"], FieldItems.row("hare_frozen")["weight"], FieldItems.row("hare_frozen")["melt"]], [0.05, 0.2, 0.05, 1.0, 0.5])
	assert_eq(FieldHud.GLINT_PULSE, 4.0)
	for id: String in ["it_key", "it_hare", "it_pan", "it_bottle_broken", "it_stake", "it_knife"]:
		assert_true(HudIcons.PATHS.has(id), id)
	assert_true(HudIcons.PATHS.has(FieldItems.KEY_ROW["icon"]))
	for id in ["can_empty", "hare_frozen", "note_map"]:
		assert_true(HudIcons.PATHS.has(FieldItems.icon(id)), id)


func test_a_key_is_one_a_building_and_stays_in_the_field() -> void:
	assert_eq(FieldItems.key_for(12), "key_12")
	assert_true(FieldItems.is_key("key_12") and FieldItems.has("key_12"))
	assert_eq(FieldItems.key_building("key_12"), 12)
	assert_false(FieldItems.is_key("key_x"))
	assert_true(FieldItems.stays_on_body("key_3") and FieldItems.stays_on_body("can_empty") and FieldItems.stays_on_body("can_opener"))
	assert_false(FieldItems.stays_on_body("can_beans"))
	assert_eq(FieldItems.stock_of("key_3"), ["", 0.0])


func test_an_improvised_weapon_goes_to_pieces_when_worn_out() -> void:
	var game = _game()
	var p = game.player
	p.set_weapon_slots([{"id": "broken_bottle", "quality": "factory", "condition": 0.3, "loaded": 0}])
	game.combat._wear(p, 0.25)
	assert_eq(p.hands.size(), 1, "still whole")
	game.combat._wear(p, 0.25)
	assert_true(p.hands.is_empty(), "gone to pieces")
	# A real knife lasts far longer and breaks only when worn to nothing (weapons.md).
	p.set_weapon_slots([{"id": "knife", "quality": "factory", "condition": 0.3, "loaded": 0}])
	game.combat._wear(p, 0.25)
	assert_eq(p.hands.size(), 1, "a real knife is not gone where a bottle would be")


func _locked_door(game) -> Vector2i:
	for c: Vector2i in game.grid.doors:
		if int(game.grid.doors[c].get("building", -1)) >= 0:
			return c
	return Vector2i(-1, -1)


func test_a_key_opens_its_buildings_door_quietly_and_a_boarded_one_not_at_all() -> void:
	var game = _game()
	game.zombies.list.clear()
	var p = game.player
	var c := _locked_door(game)
	assert_ne(c, Vector2i(-1, -1))
	game.grid.set_door_state(c, "locked")
	p.position = FieldGrid.center(c) + Vector3(0.8, 0, 0)
	p.stop()
	assert_false(game.actions.has_key(p, c))
	p.add_item(FieldItems.key_for(int(game.grid.doors[c]["building"])))
	assert_true(game.actions.has_key(p, c))
	var heard: int = game.ledger.sound_events
	game.actions.door_default(p, c, "")
	assert_eq(p.action, "door")
	assert_almost_eq(p.action_total, FieldActions.KEY_TIME, 0.001)
	_finish(game, p)
	assert_eq(game.grid.doors[c]["state"], "open")
	assert_eq(game.ledger.sound_events, heard, "no sound")
	game.grid.set_door_state(c, "locked")
	BuildingRules.add_plank(game.grid.doors[c], 0)
	assert_false(game.actions.has_key(p, c), "the boards are in the way")


func test_boarding_a_door_takes_a_plank_and_nails_and_makes_it_harder() -> void:
	var game = _game()
	game.zombies.list.clear()
	var p = game.player
	var c := _locked_door(game)
	game.grid.set_door_state(c, "closed")
	p.position = FieldGrid.center(c) + Vector3(0.8, 0, 0)
	p.stop()
	assert_false(game.actions.can_board(p, c), "nothing to do it with")
	p.add_item("plank")
	p.add_item("nails")
	assert_true(game.actions.can_board(p, c))
	var labels: Array = game.actions.context(p).map(func(r) -> String: return r["label"])
	assert_has(labels, "문 막기")
	var hp: int = int(game.grid.doors[c].get("hp", 0))
	var heard: int = game.ledger.sound_events
	game.actions.board_door(p, c)
	assert_eq(game.ledger.sound_events, heard + 1, "the hammering is heard")
	_finish(game, p)
	# The door stays shut as it was; the plank on the player's face keeps it so (J08).
	assert_eq(game.grid.doors[c]["state"], "closed")
	assert_eq(BuildingRules.planks(game.grid.doors[c], game.grid.face_toward(c, p.position)), 1)
	assert_false(game.grid.people_can_walk(c), "a boarded door is not walked through")
	assert_eq(int(game.grid.doors[c]["hp"]), hp + FieldActions.BOARD_HP)
	assert_false(p.items.has("plank") or p.items.has("nails"))


func test_a_stake_is_whittled_from_a_plank_into_a_free_hand() -> void:
	var game = _game()
	var p = game.player
	p.set_weapon_slots([])
	p.add_item("plank")
	game.actions.whittle_stake(p)
	assert_almost_eq(p.action_total, FieldActions.STAKE_TIME, 0.001)
	_finish(game, p)
	assert_eq(p.weapon_id(), "wood_stake")
	assert_false(p.items.has("plank"))


func test_a_pan_from_a_box_is_in_the_hand_at_once() -> void:
	var game = _game()
	game.zombies.list.clear()
	var p = game.player
	p.set_weapon_slots([{"id": "axe", "quality": "factory", "condition": 1.0, "loaded": 0}])
	var id: String = game.data["containers"].keys()[0]
	var c: Dictionary = game.data["containers"][id]
	c["locked"] = false
	c["searched"] = true
	c["items"] = ["frying_pan"]
	p.position = game.lift(c["cell"], int(c.get("level", 0)))
	p.stop()
	game.actions.take(p, id, 0)
	assert_eq(p.action, "take", "out by its weight's time (card R1)")
	while p.action == "take":
		p.action_t = 0.001
		game._update_person(p, 0.1)
	assert_eq(p.weapon_id(), "frying_pan", "in the hand")
	assert_eq(String(p.hands[1]["id"]), "axe", "the axe to the other")
	assert_false(p.items.has("frying_pan"))


func test_an_empty_tin_is_thrown_and_rattles_where_it_lands() -> void:
	var game = _game()
	game.zombies.list.clear()
	var p = game.player
	p.hands = []
	p.add_item("can_beans")
	p.add_item("can_opener")
	game.eat(p, "can_beans")
	_finish(game, p)
	assert_eq(int(p.items.get("can_empty", 0)), 1, "what is left of the tin")
	var heard: int = game.ledger.sound_events
	game.throw_lure(p, "can_empty")
	assert_false(p.items.has("can_empty"))
	assert_eq(game.lures.size(), 1)
	var land: Vector3 = game.lures[0]["pos"]
	assert_lte(land.distance_to(p.position), FieldGame.THROW_REACH + 0.01)
	game._land_lures()
	assert_eq(game.ledger.sound_events, heard, "not yet")
	game.clock.elapsed += FieldGame.THROW_FLIGHT + 0.01
	game._land_lures()
	assert_eq(game.ledger.sound_events, heard + 1, "heard where it came down")
	assert_eq(game.lure_marks.size(), 1)
	var there := false
	for g: Dictionary in game.ground_items:
		if g["id"] == "can_empty" and (g["pos"] as Vector3).distance_to(land) < 0.01:
			there = true
	assert_true(there, "and lies there to pick up again")


func test_what_lies_under_the_snow_shows_to_one_close_by_less_in_the_dark_and_the_storm() -> void:
	var game = _game()
	assert_eq(game.glints.size() >= 1, true, "something under the snow")
	for g: Dictionary in game.glints:
		var cell: Vector2i = g["cell"]
		assert_true(game.grid.people_can_walk(cell) and not game.grid.indoor(cell), str(cell))
	assert_almost_eq(game.glint_reach(), FieldGame.GLINT_REACH * (FieldGame.GLINT_DARK if game.clock.is_dark() else 1.0) * (FieldGame.GLINT_STORM if game.weather.kinds.has("blizzard") else 1.0), 0.0001)
	var g0: Dictionary = game.glints[0]
	var before: int = game.ground_items.size()
	for q in game.squad:
		q.position = game.lift(g0["cell"], 0) + Vector3(30, 0, 30)
	game._reveal_glints()
	assert_eq(game.ground_items.size(), before, "nobody near")
	game.player.position = game.lift(g0["cell"], 0) + Vector3(game.glint_reach() * 0.5, 0, 0)
	game._reveal_glints()
	assert_gt(game.ground_items.size(), before)
	assert_true(bool(game.ground_items[game.ground_items.size() - 1].get("glint", false)))


func test_every_building_with_a_locked_door_has_its_key_somewhere() -> void:
	var game = _game()
	assert_false(game.key_ways.is_empty(), "the first stop has locked doors")
	for b: int in game.key_ways:
		var key := FieldItems.key_for(b)
		var found := false
		match String(game.key_ways[b]):
			"dead":
				for z in game.zombies.list:
					if (z.get("carry", []) as Array).has(key):
						found = true
			"snow":
				for g: Dictionary in game.glints:
					if g["id"] == key:
						found = true
			"box":
				for id: String in game.data["containers"]:
					if (game.data["containers"][id]["items"] as Array).has(key):
						found = true
			"none":
				found = true
		assert_true(found, "%d %s" % [b, game.key_ways[b]])
	var a := LootDress.key_ways(game.grid.doors, 7)
	assert_eq(a, LootDress.key_ways(game.grid.doors, 7), "the same seed, the same ways")


func test_the_dead_carry_what_they_were_given() -> void:
	var game = _game()
	var z: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(1, 0, 0))
	z["carry"] = ["key_2", "note_map"]
	game.zombies.knock_down(z)
	var ids: Array = (z["loot"] as Array).map(func(e) -> String: return String(e.get("id", "")))
	assert_has(ids, "key_2")
	assert_has(ids, "note_map")
	assert_eq(game.item_name("key_2").ends_with("열쇠"), true)


func test_keys_tins_and_the_opener_stay_on_the_body_at_the_train() -> void:
	var game = _game()
	var p = game.player
	for id in ["key_1", "can_empty", "can_opener", "can_beans"]:
		p.add_item(id)
	var rect: Rect2i = game.data["unload"]
	p.position = game.lift(rect.position + Vector2i(3, 1), 0)
	game.actions.load_train(p)
	assert_true(p.items.has("key_1") and p.items.has("can_empty") and p.items.has("can_opener"))
	assert_false(p.items.has("can_beans"))
	assert_eq(int(game.unloaded.get("can_beans", 0)), 1)


func test_a_note_tells_of_a_box_at_the_next_stop_and_the_next_stop_has_it() -> void:
	var game = _game()
	game.note_spot = LootDress.NOTE_SPOTS[0]
	assert_true(game.note_line().contains(LootDress.NOTE_SPOTS[0]))
	# Told the stop: a stop receipt carries it as a document of the next stop.
	game.opts["next_stop"] = "first_leg_02_next"
	game.opts["segment"] = 2
	game.receipt.set_ids("r_note", "s_note")
	game.unloaded["note_map"] = 1
	game._receipt_finds([])
	var d: Dictionary = game.receipt.to_dict()
	var docs: Array = d["extras"]["documents"]
	assert_eq(docs.size(), 1)
	assert_eq(docs[0]["kind"], "next_stop")
	assert_eq(docs[0]["nextStop"]["stopId"], "first_leg_02_next")
	assert_eq(game.receipt.problems().filter(func(x) -> bool: return String(x).begins_with("extras")), [])
	# The next stop puts the box where the note said.
	var other = _game({"seed": 9, "stash": LootDress.NOTE_SPOTS[0]})
	var at: String = String(other.loot_report.get("stash", ""))
	assert_ne(at, "")
	assert_gte((other.data["containers"][at]["items"] as Array).size(), LootDress.STASH.size())


func test_a_note_without_a_next_stop_is_only_a_thing_on_the_list() -> void:
	var game = _game()
	game.note_spot = LootDress.NOTE_SPOTS[1]
	game.unloaded["note_map"] = 1
	game._receipt_finds([])
	assert_false(game.receipt.is_stop_receipt())
	assert_true(FieldItems.kept_by_name("note_map"), "it goes on items.gained at the end")


func test_going_through_the_dead_is_seen_said_and_told_by_those_who_came_back() -> void:
	var game = _game()
	game.zombies.list.clear()
	var p = game.player
	var q = game.squad[1]
	q.position = p.position + Vector3(1.5, 0, 0)
	for o in game.squad:
		if o != p and o != q:
			o.position = p.position + Vector3(40, 0, 0)
	game.actions._body_seen(p)
	assert_eq(game.body_searches.size(), 1)
	assert_eq(game.body_searches[0]["seen"], [String(q.pid)])
	game._receipt_finds([q])
	var rows: Array = game.receipt.to_dict()["witnessed"].filter(func(r) -> bool: return r.get("template", "") == "body_search")
	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["witnesses"], [String(q.pid)])
	# The row itself is one the contract knows (the stop's times come at the end).
	assert_eq(game.receipt.problems().filter(func(m: String) -> bool: return m.begins_with("witnessed")), [])
	# Nobody came back who saw it: the train never hears of it.
	var none = _game()
	none.body_searches = [{"who": "p_chief", "seen": ["p_x"]}]
	none._receipt_finds([])
	assert_eq((none.receipt.to_dict()["witnessed"] as Array).size(), 0)


func test_the_car_of_one_who_saw_it_minds_it_on_the_train() -> void:
	var tables := V.tables()
	var row: Dictionary = V.cases()[0]
	var departure := V.departure(row["departure"])
	var receipt: Dictionary = V.receipt(row["receipt"])
	var plain := FieldReturn.apply_field_return(row["start"], tables, departure, receipt)
	var medtech := ""
	var guard := ""
	for r: Dictionary in departure["roster"]:
		if r["comm"] == "medtech" and medtech == "":
			medtech = r["id"]
		if r["comm"] == "guard" and guard == "":
			guard = r["id"]
	assert_ne(medtech, "", "a medtech in the roster")
	var seen: Dictionary = receipt.duplicate(true)
	seen["receiptId"] = String(receipt["receiptId"]) + "_b"
	var w: Array = [medtech]
	if guard != "":
		w.append(guard)
	(seen["witnessed"] as Array).append({"who": guard if guard != "" else medtech, "what": "body_search", "where": "x", "when": "D1 10:00", "why": "searched_the_dead", "witnesses": w, "template": "body_search"})
	(seen["witnessed"] as Array).append({"who": medtech, "what": "body_search", "where": "x", "when": "D1 10:05", "why": "searched_the_dead", "witnesses": [medtech], "template": "body_search"})
	var after := FieldReturn.apply_field_return(row["start"], tables, departure, seen)
	var d: float = float(after["g"]["comms"]["medtech"]["rel"]) - float(plain["g"]["comms"]["medtech"]["rel"])
	assert_almost_eq(d, -1.0, 0.0001, "once a return, however many saw it")
	assert_almost_eq(float(after["g"]["comms"]["guard"]["rel"]), float(plain["g"]["comms"]["guard"]["rel"]), 0.0001)


func test_the_car_never_hears_of_it_when_the_one_who_saw_it_stays_out() -> void:
	var tables := V.tables()
	var departure := V.departure("departure_prologue")
	var receipt: Dictionary = V.receipt("case3_nosymbol_kept").duplicate(true)
	receipt["people"]["leftBehind"] = ["p_122"]
	var start: Dictionary = V.cases()[0]["start"]
	var plain := FieldReturn.apply_field_return(start, tables, departure, receipt)
	var seen: Dictionary = receipt.duplicate(true)
	(seen["witnessed"] as Array).append({"who": "p_151", "what": "body_search", "where": "x", "when": "D1 10:00", "why": "searched_the_dead", "witnesses": ["p_122"], "template": "body_search"})
	var after := FieldReturn.apply_field_return(start, tables, departure, seen)
	assert_almost_eq(float(after["g"]["comms"]["medtech"]["rel"]), float(plain["g"]["comms"]["medtech"]["rel"]), 0.0001)
