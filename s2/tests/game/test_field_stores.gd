extends "res://addons/gut/test.gd"
## Common stuff the field brings home reaches the train's stores (decision 426
## D2): cloth, and the parts stuff picked up in toolboxes and workshops, go on
## the receipt and into the train's dom; the bow's arrows have the stock's name.

const FieldItems = preload("res://game/sim/field_items.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const Receipt = preload("res://game/sim/receipt.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldActions = preload("res://game/field_actions.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const Carry = preload("res://game/sim/carry.gd")
const FieldReturn = preload("res://game/politics/field_return.gd")
const TrainDom = preload("res://game/train/train_dom.gd")
const V = preload("res://tests/politics/field_vectors.gd")

const PARTS: Array[String] = ["gears", "springs", "wire_coil"]


func _game(extra: Dictionary = {}) -> Node:
	var game = FieldGame.new()
	var opts := {"seed": 5, "raiders": false, "auto_pause": false}
	opts.merge(extra, true)
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	return game


func test_the_new_values_are_the_listed_ones() -> void:
	assert_eq([LootDress.PARTS_CHANCE, LootDress.PARTS_MOST], [0.12, 5])
	assert_eq(str(LootDress.PARTS_KINDS), str([["gears", 2], ["springs", 2], ["wire_coil", 1]]))
	var rows: Array = []
	for id: String in PARTS:
		rows.append([FieldItems.weight(id), FieldItems.stock_of(id)])
		assert_true(HudIcons.PATHS.has(FieldItems.icon(id)), id)
	assert_eq(rows, [[0.6, ["parts", 0.5]], [0.3, ["parts", 0.25]], [0.5, ["parts", 0.25]]])
	assert_eq(FieldGame.STOCK_OF["cloth"], ["cloth", 1.0])
	assert_true(Receipt.STOCK_KEYS.has("cloth") and Receipt.STOCK_KEYS.has("parts"))
	for key in ["cloth", "parts"]:
		assert_true(TrainDom.AMOUNTS.has(key), "the train has a store for " + key)


func test_parts_stuff_lies_in_toolboxes_and_workshops_and_not_too_much() -> void:
	var found := 0
	for place: String in ["factory_01"]:
		var base: Dictionary = FieldMaps.build(place)
		for seed in range(1, 7):
			var data: Dictionary = base.duplicate(true)
			var report: Dictionary = LootDress.dress(data, seed)
			var here := 0
			for row: Array in report["finds"]:
				if not PARTS.has(String(row[0])):
					continue
				here += 1
				var c: Dictionary = data["containers"][row[1]]
				var kind: String = LootDress._building_kind_of(data.get("buildings", []), c)
				assert_true(LootDress.room_of(c) == "toolbox" or kind in ["garage", "workshop"], "%s in %s" % [row[0], row[1]])
			assert_lte(here, LootDress.PARTS_MOST, "%s seed %d" % [place, seed])
			found += here
	assert_gt(found, 0, "some stop has some")


func test_the_same_seed_puts_the_same_parts() -> void:
	var a: Dictionary = FieldMaps.build("factory_01")
	var b: Dictionary = a.duplicate(true)
	var ra: Dictionary = LootDress.dress(a, 11)
	var rb: Dictionary = LootDress.dress(b, 11)
	assert_eq(str(ra["finds"]), str(rb["finds"]))


func test_found_cloth_and_parts_go_on_the_receipt_and_the_kit_cloth_does_not() -> void:
	var game = _game()
	assert_eq(game.cloth_start, 1, "the chief's strip of cloth")
	for q in game.squad:
		q.brain["boarded"] = true
	game.unloaded = {"cloth": 2, "gears": 2, "springs": 2}
	game.finish("departed")
	var stock: Dictionary = game.receipt.to_dict()["stock"]
	assert_eq(int(stock.get("cloth", 0)), 2, "two found; the kit's one came back as it went")
	assert_eq(int(stock.get("parts", 0)), 2, "two gears 1.0 + two springs 0.5 rounds to 2")
	assert_eq(game.receipt.problems().filter(func(m: String) -> bool: return m.begins_with("stock")), [])


func test_cloth_used_up_in_the_field_is_cloth_the_train_lost() -> void:
	var game = _game()
	game.player.items.erase("cloth")
	for q in game.squad:
		q.brain["boarded"] = true
	game.finish("departed")
	var stock: Dictionary = game.receipt.to_dict()["stock"]
	assert_eq(int(stock.get("cloth", 0)), -1)


func test_the_train_takes_cloth_and_parts_into_its_stores() -> void:
	var tables := V.tables()
	var row: Dictionary = V.cases()[0]
	var departure := V.departure(row["departure"])
	var receipt: Dictionary = V.receipt(row["receipt"])
	var start: Dictionary = (row["start"] as Dictionary).duplicate(true)
	start["dom"] = TrainDom.empty()
	start["dom"]["cloth"] = 1
	var got: Dictionary = receipt.duplicate(true)
	got["stock"]["cloth"] = 3
	got["stock"]["parts"] = 2
	var after := FieldReturn.apply_field_return(start, tables, departure, got)
	assert_almost_eq(float(after["g"]["dom"]["cloth"]), 4.0, 0.0001)
	assert_almost_eq(float(after["g"]["dom"]["parts"]), 2.0, 0.0001)
	var lost: Dictionary = receipt.duplicate(true)
	lost["stock"]["cloth"] = -5
	var after_lost := FieldReturn.apply_field_return(start, tables, departure, lost)
	assert_eq(float(after_lost["g"]["dom"]["cloth"]), 0.0, "never under nothing")


func test_the_bows_arrows_have_the_stocks_name_and_an_old_save_reads_the_same() -> void:
	assert_eq(FieldActions.AMMO_ITEMS["ammo_craft"], ["craft", 1])
	assert_false(FieldActions.AMMO_ITEMS.has("arrow"))
	assert_eq(Carry.ITEM_NAMES["ammo_craft"], "화살")
	var game = _game()
	var p = game.player
	var before: int = int(game.ammo["craft"])
	game.ground_items.append({"pos": p.position, "id": "ammo_craft", "n": 1})
	game.actions._auto_pickup()
	assert_eq(int(game.ammo["craft"]), before + 1, "walked over, it goes in the quiver")
	# A save written before the rename still has "arrow" on the ground.
	game.ground_items = [{"pos": Vector3(1, 0, 2), "id": "arrow", "n": 1}]
	var d: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))
	assert_false(d.is_empty(), "the save reads back")
	assert_eq(String(d["ground_items"][0]["id"]), "ammo_craft")
