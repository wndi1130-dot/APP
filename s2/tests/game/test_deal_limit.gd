extends "res://addons/gut/test.gd"
## Dealing the bundles never fills a box past what it holds (carry.gd box_limit,
## #709): a bundle counts at the most its name can weigh, as it is named after.

const LootDress = preload("res://game/sim/loot_dress.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const Carry = preload("res://game/sim/carry.gd")


func test_no_name_weighs_more_than_a_bundle_is_counted_at() -> void:
	for fam: String in LootDress.NAMES:
		for table: String in LootDress.NAMES[fam]:
			for row: Array in LootDress.NAMES[fam][table]:
				assert_lte(FieldItems.weight(String(row[0])), LootDress.NAMED_MOST, String(row[0]))


func test_a_jar_shelf_is_never_dressed_past_its_limit() -> void:
	# A store room: a jar shelf (8) and a counter (20); all the food starts on the shelf.
	for seed in range(1, 41):
		var data := {"place_kind": "houses", "buildings": [{"name": "농가"}], "containers": {
			"shelf": {"id": "shelf", "name": "병 선반", "building": 0, "room": "pantry", "furniture": "jar_shelf",
				"items": ["food_pack", "food_pack", "food_pack", "food_pack", "food_pack", "food_pack"]},
			"counter": {"id": "counter", "name": "조리대", "building": 0, "room": "pantry", "furniture": "counter", "items": []},
		}}
		LootDress.dress(data, seed)
		var shelf: Dictionary = data["containers"]["shelf"]
		assert_lte(Carry.box_load(shelf), Carry.box_limit(shelf), "seed %d: %s" % [seed, shelf["items"]])
		var things := 0
		for id: String in data["containers"]:
			for item in data["containers"][id]["items"]:
				if FieldItems.stock_of(String(item))[0] == "food":
					things += 1
		assert_eq(things, 6, "seed %d: no bundle lost" % seed)
