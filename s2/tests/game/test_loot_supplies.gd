extends GutTest
## Supplies keep every earlier dressing roll and melt into one stock (decision 490).

const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const LootJunk = preload("res://game/sim/loot_junk.gd")
const LootSupplies = preload("res://game/sim/loot_supplies.gd")
const LootTables = preload("res://game/sim/loot_tables.gd")
const Receipt = preload("res://game/sim/receipt.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const Carry = preload("res://game/sim/carry.gd")
const FieldGame = preload("res://game/field_game.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")
const FieldDeparture = preload("res://game/politics/field_departure.gd")
const V = preload("res://tests/politics/field_vectors.gd")

## houses_01: homes; office_01: a general store; church_06: the parish school.
const MAPS: Array[String] = ["houses_01", "office_01", "church_06"]
const VALUES: Dictionary = {
	"toilet_paper": [0.1, 0.25], "soap": [0.1, 0.25], "candle": [0.1, 0.25],
	"sewing_kit": [0.2, 0.25], "old_clothes": [0.5, 0.5], "child_clothes": [0.3, 0.5],
	"book": [0.5, 0.5], "toy": [0.2, 0.25], "razor": [0.05, 0.25],
}


func test_rows_name_light_supplies_with_the_listed_values_and_distinct_pictures() -> void:
	var seen := {}
	var pictures := {}
	for room: String in LootSupplies.ROWS:
		assert_true(LootJunk.ROOM_BOXES.has(room), room)
		for row: Array in LootSupplies.ROWS[room]:
			var id := String(row[0])
			seen[id] = true
			assert_true(FieldItems.ITEMS.has(id), id)
			assert_true(VALUES.has(id), id)
			assert_between(float(row[1]), 0.0, 1.0, id)
			assert_true(String(row[2]) in ["any", "lived", "home", "kids", "shop", "school"], id)
			if not VALUES.has(id):
				continue
			assert_eq(FieldItems.stock_of(id), ["supplies", VALUES[id][1]], id)
			assert_eq(FieldItems.group(id), "supplies", id)
			assert_eq(FieldItems.weight(id), float(VALUES[id][0]), id)
			assert_lte(FieldItems.weight(id), 0.5, id)
	for id: String in VALUES:
		assert_true(seen.has(id), "a row for " + id)
		var icon := FieldItems.icon(id)
		assert_eq(icon, "it_" + id, id)
		assert_true(HudIcons.PATHS.has(icon), icon)
		if not HudIcons.PATHS.has(icon):
			continue
		var drawing := String(HudIcons.PATHS[icon])
		assert_false(pictures.has(drawing), "a distinct picture: " + id)
		pictures[drawing] = true
		for other: String in HudIcons.PATHS:
			if other != icon:
				assert_ne(drawing, String(HudIcons.PATHS[other]), "%s / %s" % [icon, other])
	assert_eq(seen.size(), 9)
	assert_eq(LootSupplies.MOST, 1)
	assert_between(LootSupplies.YIELD, 0.0, 1.0)


func test_supplies_leave_every_other_item_and_report_field_unchanged() -> void:
	var in_houses := 0
	var in_school := 0
	for place: String in MAPS:
		var deck: Dictionary = {}
		for seed in range(1, 6):
			var before: Dictionary = FieldMaps.build(place)
			var after: Dictionary = FieldMaps.build(place)
			# From the second seed on, a deck carried from the stop before.
			var old_report: Dictionary = LootDress.dress(before, seed, deck, false)
			var new_report: Dictionary = LootDress.dress(after, seed, deck, true)
			deck = old_report["loot_deck"]
			# Whole rows, not the item lists only: take the supplies out and the rest is the same text.
			for id: String in after["containers"]:
				var bare: Dictionary = (after["containers"][id] as Dictionary).duplicate(true)
				bare["items"] = _without_supplies(bare.get("items", []))
				assert_eq(JSON.stringify(bare), JSON.stringify(before["containers"][id]), "%s:%d:%s row" % [place, seed, id])
			assert_eq(JSON.stringify(after["buildings"]), JSON.stringify(before["buildings"]), "%s:%d buildings" % [place, seed])
			var count := 0
			assert_eq(old_report["supplies"], 0)
			assert_eq(after["containers"].keys(), before["containers"].keys(), place)
			for id: String in after["containers"]:
				var c: Dictionary = after["containers"][id]
				var items: Array = c.get("items", [])
				var supplies := _supply_count(items)
				var label := "%s:%d:%s" % [place, seed, id]
				assert_eq(_without_supplies(items), before["containers"][id].get("items", []), label)
				assert_lte(supplies, 1, label)
				if c.has("pick") or LootTables.FIXED.has(id) or bool(c.get("locked", false)) or int(c.get("building", -1)) < 0 or bool(c.get("searched", false)):
					assert_eq(supplies, 0, label)
				if not _kids_building(after["buildings"], c):
					assert_false(items.has("child_clothes") or items.has("toy"), label)
				count += supplies
			assert_eq(new_report["supplies"], count, place)
			if place == "houses_01":
				in_houses += count
			if place == "church_06":
				for id: String in after["containers"]:
					var c: Dictionary = after["containers"][id]
					var b := int(c.get("building", -1))
					if b >= 0 and String(after["buildings"][b].get("name", "")).contains("학교"):
						in_school += _supply_count(c.get("items", []))
			old_report.erase("supplies")
			new_report.erase("supplies")
			assert_eq(JSON.stringify(new_report), JSON.stringify(old_report), "%s:%d: report" % [place, seed])
	assert_gt(in_houses, 0, "supplies appear across the five house seeds")
	assert_gt(in_school, 0, "and in the parish school (its unnamed rooms read as storage)")


func test_the_same_seed_dresses_the_same_boxes() -> void:
	var once: Dictionary = FieldMaps.build("houses_01")
	var twice: Dictionary = FieldMaps.build("houses_01")
	assert_eq(LootDress.dress(once, 3), LootDress.dress(twice, 3))
	for id: String in once["containers"]:
		assert_eq(once["containers"][id]["items"], twice["containers"][id]["items"], id)


func test_goal_fixed_locked_outdoor_and_searched_boxes_are_left_alone() -> void:
	for seed in range(1, 26):
		var boxes := {
			"goal": {"building": 0, "items": ["food_pack"], "pick": false},
			"safe": {"building": 0, "items": [], "locked": true},
			"outside": {"building": -1, "items": []},
			"searched": {"building": 0, "items": ["junk_rag"], "searched": true},
		}
		for id: String in LootTables.FIXED:
			boxes[id] = {"building": 0, "items": []}
		var rooms := {}
		for id: String in boxes:
			rooms[id] = "bathroom"
		var before: Dictionary = boxes.duplicate(true)
		assert_eq(LootSupplies.strew(boxes, seed, rooms, [{"name": "주택"}]), 0)
		assert_eq(boxes, before)


func test_children_things_stay_in_homes_farms_fishing_houses_and_schools() -> void:
	var buildings: Array = [
		{"name": "주택"}, {"name": "농가"}, {"name": "낚시 오두막"},
		{"name": "작은 학교"}, {"name": "산골 분교"}, {"name": "기계 공장"},
		{"name": "강변 여관"}, {"name": "주택", "loot_kind": "workshop"},
		{"name": "기계 공장", "loot_kind": "house"}, {"name": "간호 기숙사"},
	]
	var allowed: Array[bool] = [true, true, true, true, true, false, false, false, true, false]
	var found := 0
	var found_in: Array[int] = []
	found_in.resize(buildings.size())
	for seed in range(1, 81):
		var boxes := {}
		var rooms := {}
		for b in range(buildings.size()):
			for room: String in ["bedroom", "office", "storage"]:
				var id := "%02d:%s" % [b, room]
				boxes[id] = {"building": b, "items": []}
				rooms[id] = room
		LootSupplies.strew(boxes, seed, rooms, buildings)
		for id: String in boxes:
			var c: Dictionary = boxes[id]
			for item: String in c["items"]:
				if item in ["toy", "child_clothes"]:
					assert_true(allowed[int(c["building"])], id)
					found += 1
					found_in[int(c["building"])] += 1
	assert_gt(found, 0, "children's things were exercised")
	# Each place that may hold them does, each on its own (a school's too, not only a house's).
	for b in range(buildings.size()):
		if allowed[b]:
			assert_gt(found_in[b], 0, String(buildings[b]["name"]))


func test_a_full_box_takes_no_supplies_past_what_it_holds() -> void:
	for seed in range(1, 81):
		# A washstand (6) already holding its 6 of wood, and an empty one beside it.
		var boxes := {
			"full": {"building": 0, "furniture": "washstand", "items": ["wood", "wood", "wood", "wood", "wood", "wood"]},
			"empty": {"building": 0, "furniture": "washstand", "items": []},
		}
		var rooms := {"full": "bathroom", "empty": "bathroom"}
		LootSupplies.strew(boxes, seed, rooms, [{"name": "주택"}])
		assert_eq(boxes["full"]["items"].size(), 6, str(seed))
		assert_lte(Carry.box_load(boxes["empty"]), Carry.box_limit(boxes["empty"]), str(seed))


func test_caps_and_building_gates_do_not_skip_later_dice() -> void:
	for seed in range(1, 81):
		var home := {"a": {"building": 0, "items": []}, "z": {"building": 1, "items": []}}
		# Reversed insertion order must still visit a before z.
		var work := {"z": {"building": 1, "items": []}, "a": {"building": 0, "items": []}}
		var rooms := {"a": "bedroom", "z": "bathroom"}
		LootSupplies.strew(home, seed, rooms, [{"name": "주택"}, {"name": "공장"}])
		LootSupplies.strew(work, seed, rooms, [{"name": "공장"}, {"name": "공장"}])
		assert_eq(home["z"]["items"], work["z"]["items"], str(seed))
		assert_lte((home["a"]["items"] as Array).size(), 1)
		assert_eq(work["a"]["items"], [])


func test_supplies_are_optional_integer_stock_on_the_receipt() -> void:
	var receipt := Receipt.new("houses_01", "houses")
	assert_true(receipt.set_time("D1 10:30", "D1 10:40", 10))
	assert_false((receipt.to_dict()["stock"] as Dictionary).has("supplies"))
	assert_true(receipt.add_stock("supplies", 3))
	# A legacy receipt has no place for it (the shared schema's stock is closed): kept, not written.
	var legacy: Dictionary = receipt.to_dict()
	assert_false((legacy["stock"] as Dictionary).has("supplies"))
	assert_eq(Receipt.check(legacy), [] as Array[String])
	legacy["stock"]["supplies"] = 3
	assert_eq(Receipt.check(legacy), ["stock.supplies: 판 3 전 영수증에는 없는 칸"] as Array[String])
	# From v3 on (S1 stop_receipt v3Schema) it goes as it is.
	assert_true(receipt.set_ids("ret_houses_01", "stop_houses_01"))
	assert_true(receipt.set_goal("food", 4, 2))
	assert_true(receipt.set_extras(0, [], 0))
	var data: Dictionary = receipt.to_dict()
	assert_eq(data["version"], 3)
	assert_eq(data["stock"]["supplies"], 3)
	assert_eq(Receipt.check(data), [] as Array[String])


func test_the_stay_key_is_read_before_the_name() -> void:
	# name_keys reads a school or an inn from the name once; renamed after, the key still holds.
	var data := {"containers": {}, "buildings": [{"name": "작은 학교"}, {"name": "강변 여관"}, {"name": "주택"}]}
	LootDress.name_keys(data)
	assert_eq(data["buildings"][0]["stay_kind"], "school")
	assert_eq(data["buildings"][1]["stay_kind"], "inn")
	assert_eq(data["buildings"][2]["stay_kind"], "")
	data["buildings"][0]["name"] = "창고"
	# A key that says school wins over a name that says nothing, and an empty key over a school's name.
	var buildings: Array = [data["buildings"][0], {"name": "작은 학교", "stay_kind": "", "loot_kind": ""}]
	var keyed := 0
	var named := 0
	for seed in range(1, 161):
		var boxes := {"a": {"building": 0, "items": []}, "b": {"building": 1, "items": []}}
		LootSupplies.strew(boxes, seed, {"a": "storage", "b": "storage"}, buildings)
		for item: String in boxes["a"]["items"]:
			if item in ["book", "toy", "child_clothes"]:
				keyed += 1
		for item: String in boxes["b"]["items"]:
			if item in ["toy", "child_clothes"]:
				named += 1
	assert_gt(keyed, 0, "the school rows follow the key")
	assert_eq(named, 0, "not the name")


func _contract_game(departure: Variant):
	var game = FieldGame.new()
	game.opts = {"seed": 4, "auto_pause": false, "raiders": false}
	if departure is Dictionary:
		game.opts["departure"] = departure
	game.map_script = BareLine
	add_child_autofree(game)
	game.set_process(false)
	return game


func test_the_contract_says_whether_the_boxes_get_supplies() -> void:
	# departure.supplies (s3 contract) is the run's supOn: off, no box gets one; on, or a
	# contract without it, or no contract at all, they are dressed as always.
	var got := {}
	for which: Variant in [0, 6, "old", null]:
		var d: Variant = null
		if which is int:
			var state: Dictionary = (V.data()["contracts"][which]["state"] as Dictionary).duplicate(true)
			d = FieldDeparture.build(state, V.tables(), {"placeId": "sulechow_station"})
		elif which is String:
			d = FieldDeparture.build((V.data()["contracts"][0]["state"] as Dictionary).duplicate(true), V.tables(), {"placeId": "sulechow_station"})
			(d as Dictionary).erase("supplies")
		var game = FieldGame.new()
		game.opts = {"seed": 4, "auto_pause": false, "raiders": false, "place": "houses_01"}
		if d is Dictionary:
			game.opts["departure"] = d
		add_child_autofree(game)
		game.set_process(false)
		var in_boxes := 0
		for c: Dictionary in game.data["containers"].values():
			in_boxes += _supply_count(c.get("items", []))
		got[str(which)] = [int(game.loot_report.get("supplies", -1)), in_boxes]
	assert_false(bool(FieldDeparture.build((V.data()["contracts"][0]["state"] as Dictionary).duplicate(true), V.tables(), {"placeId": "sulechow_station"})["supplies"]), "contract 0 runs with supplies off")
	assert_eq(got["0"], [0, 0], "off: none")
	for key: String in ["6", "old", "<null>"]:
		assert_gt(int(got[key][0]), 0, key)
		assert_gt(int(got[key][1]), 0, key + ": and they are in the boxes")


func test_in_the_field_supplies_go_in_last_and_move_nothing_else() -> void:
	# A barricaded room takes the back half of each box and a looted house tips its first full box
	# out: they count the lists without the supplies, so the same run with supplies off and on
	# differs in them only (a looted house still gathers them with the rest into its hidden box).
	var stories := {}
	for place: String in ["houses_01", "houses_03"]:
		for seed in range(1, 7):
			var games: Array = []
			for turned: bool in [false, true]:
				var d: Dictionary = FieldDeparture.build((V.data()["contracts"][6]["state"] as Dictionary).duplicate(true), V.tables(), {"placeId": "sulechow_station"})
				d["supplies"] = turned
				var game = FieldGame.new()
				game.opts = {"seed": seed, "auto_pause": false, "raiders": false, "place": place, "departure": d}
				add_child_autofree(game)
				game.set_process(false)
				games.append(game)
			var off = games[0]
			var lit = games[1]
			var label := "%s:%d" % [place, seed]
			assert_eq(int(off.loot_report["supplies"]), 0, label)
			assert_eq(lit.data["containers"].keys(), off.data["containers"].keys(), label)
			for id: String in off.data["containers"]:
				var bare: Dictionary = (lit.data["containers"][id] as Dictionary).duplicate(true)
				bare["items"] = _without_supplies(bare.get("items", []))
				assert_eq(JSON.stringify(bare), JSON.stringify(off.data["containers"][id]), "%s:%s" % [label, id])
			assert_eq(JSON.stringify(lit.data.get("loose", [])), JSON.stringify(off.data.get("loose", [])), label + " floors")
			for s: Dictionary in lit.data.get("floor_stashes", []):
				assert_eq(_supply_count(lit.data["containers"][s["id"]].get("items", [])), 0, label + " board stash")
			for row: Variant in (lit.receipt.to_dict().get("placeState", {}) as Dictionary).get("roomStories", []):
				if row is Dictionary:
					stories[String((row as Dictionary).get("story", ""))] = true
	# The paths that read the lists were walked.
	assert_true(stories.has("barricaded"), str(stories.keys()))
	assert_true(stories.has("looted"), str(stories.keys()))


func test_unloaded_supplies_melt_into_one_stock_rounded_once_a_stop() -> void:
	# The train's contract makes the receipt v5; the stock is added up by key and rounded once
	# (field_game.finish), so one cake of soap (0.25) is nothing and two are one.
	for unloaded: Dictionary in [{"soap": 1}, {"soap": 2}, {"soap": 3}, {"book": 1, "soap": 3}, {"book": 3}]:
		var d: Dictionary = FieldDeparture.build((V.data()["contracts"][0]["state"] as Dictionary).duplicate(true), V.tables(), {"placeId": "sulechow_station"})
		var game = _contract_game(d)
		for q in game.squad + game.crew:
			q.items.clear()
		game.unloaded = unloaded.duplicate()
		game.finish("departed")
		var r: Dictionary = JSON.parse_string(JSON.stringify(game.receipt.to_dict()))
		var sum := 0.0
		for id: String in unloaded:
			sum += float(FieldItems.stock_of(id)[1]) * int(unloaded[id])
		assert_gte(int(r["version"]), 3, str(unloaded))
		assert_eq(int((r["stock"] as Dictionary).get("supplies", 0)), roundi(sum), "%s: %.2f rounded once" % [unloaded, sum])
		assert_eq(Receipt.check(r), [] as Array[String], str(unloaded))
	# Without the contract the receipt is a legacy one: taken, not written.
	var plain = _contract_game(null)
	for q in plain.squad + plain.crew:
		q.items.clear()
	plain.unloaded = {"book": 2}
	plain.finish("departed")
	assert_false((plain.receipt.to_dict()["stock"] as Dictionary).has("supplies"))


func _supply_count(items: Array) -> int:
	return items.size() - _without_supplies(items).size()


func _without_supplies(items: Array) -> Array:
	var out: Array = []
	for item: String in items:
		if not VALUES.has(item):
			out.append(item)
	return out


func _kids_building(buildings: Array, c: Dictionary) -> bool:
	var b := int(c.get("building", -1))
	if b < 0 or b >= buildings.size():
		return false
	var kind := LootDress._building_kind_of(buildings, c)
	var name := String(buildings[b].get("name", ""))
	var stay := String(buildings[b].get("stay_kind", LootSupplies.stay_kind(name)))
	return (kind in ["house", "farm", "fish"] and stay != "inn") or stay == "school"
