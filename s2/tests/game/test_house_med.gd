extends "res://addons/gut/test.gd"
## A house's bathroom cabinet now and then holds medicine (decision 442 card, loot_dress.gd
## _house_med): of the houses with a bathroom, exactly 3 of 10 by the house_med deck turn one
## bundle of the family they hold most into a box of medicine, in a bathroom box with the
## medicine cabinet's pull. The stop holds as many bundles as before.

const LootDress = preload("res://game/sim/loot_dress.gd")

const BUILDINGS: Array = [{"name": "주택", "loot_kind": "house"}, {"name": "공방", "loot_kind": "workshop"}]


func _box(room: String, furniture: String, building: int, items: Array = []) -> Dictionary:
	return {"name": "상자", "room": room, "furniture": furniture, "building": building, "items": items.duplicate(), "locked": false, "searched": false}


## A house: a medicine cabinet and a washstand in the bathroom, a kitchen of food, a bedroom of cloth.
func _house(building: int = 0, bath: bool = true) -> Dictionary:
	var boxes := {
		"k1": _box("kitchen", "counter", building, ["food_pack", "food_pack"]),
		"k2": _box("kitchen", "cupboard", building, ["food_pack"]),
		"b1": _box("bedroom", "wardrobe", building, ["cloth"]),
	}
	if bath:
		boxes["m"] = _box("bathroom", "medicine_cabinet", building)
		boxes["w"] = _box("bathroom", "washstand", building)
	return boxes


func _bundles(boxes: Dictionary) -> int:
	var n := 0
	for id: String in boxes:
		for item in boxes[id]["items"]:
			n += int(LootDress.FAMILY.has(String(item)))
	return n


func _med_in(boxes: Dictionary) -> String:
	for id: String in boxes:
		if (boxes[id]["items"] as Array).has("med_box"):
			return id
	return ""


func test_three_houses_of_ten_get_medicine_over_the_stops() -> void:
	var decks := {}
	var got := 0
	for stop in range(10):
		var boxes := _house()
		var before := _bundles(boxes)
		got += LootDress._house_med(boxes, BUILDINGS, {0: boxes.keys()}, 100 + stop, decks)
		assert_eq(_bundles(boxes), before, "as many bundles as before")
		var at := _med_in(boxes)
		assert_true(at == "" or String(boxes[at]["room"]) == "bathroom", "the medicine lies in the bathroom")
	assert_eq(got, 3, "exactly 3 of 10")


func test_the_most_held_family_gives_and_the_cabinet_draws() -> void:
	var cab := 0
	for seed in range(1, 401):
		var boxes := _house()
		# The deck's last 3 looks of 10 are all still to come up: this house gets it.
		var decks := {"house_med": {"n": 10, "k": 3, "seen": 7, "hit": 0}}
		assert_eq(LootDress._house_med(boxes, BUILDINGS, {0: boxes.keys()}, seed, decks), 1)
		var food := 0
		for id: String in boxes:
			food += (boxes[id]["items"] as Array).count("food_pack")
		assert_eq(food, 2, "a food pack (3 of the house's 4 bundles) gave way")
		assert_eq((boxes["b1"]["items"] as Array), ["cloth"], "the cloth stays")
		cab += int(_med_in(boxes) == "m")
	# The cabinet pulls 4 against the washstand's 1.
	assert_almost_eq(cab / 400.0, 0.8, 0.05)


func test_a_house_holding_medicine_counts_as_one_that_has_it() -> void:
	var boxes := _house()
	boxes["w"]["items"] = ["med_box"]
	var decks := {}
	assert_eq(LootDress._house_med(boxes, BUILDINGS, {0: boxes.keys()}, 7, decks), 0)
	assert_eq(_bundles(boxes), 5, "nothing changed")
	assert_eq(decks["house_med"]["seen"], 1)
	assert_eq(decks["house_med"]["hit"], 1)


func test_no_bathroom_or_no_house_is_not_looked_at() -> void:
	var decks := {}
	var plain := _house(0, false)
	assert_eq(LootDress._house_med(plain, BUILDINGS, {0: plain.keys()}, 3, decks), 0)
	var shop := _house(1)
	assert_eq(LootDress._house_med(shop, BUILDINGS, {1: shop.keys()}, 3, decks), 0)
	assert_false(decks.has("house_med"), "no look counted")


func test_the_deck_is_listed() -> void:
	assert_eq(LootDress.DECKS["house_med"], [10, 0.3])
	assert_eq(LootDress.HOUSE_MED_FROM[0], "food")


func test_full_bathroom_boxes_take_no_medicine_and_the_house_is_not_looked_at() -> void:
	# Every bathroom box full (ref-ops check, decision 485): the house keeps what it holds, no
	# box goes over CAP, and the deck does not count it, so the next ten houses still get three.
	var decks := {}
	for stop in range(10):
		var boxes := _house()
		for id: String in ["m", "w"]:
			for i in range(LootDress.CAP):
				(boxes[id]["items"] as Array).append("wrist_watch")
		var before := boxes.duplicate(true)
		assert_eq(LootDress._house_med(boxes, BUILDINGS, {0: boxes.keys()}, 100 + stop, decks), 0)
		assert_eq(boxes, before, "nothing moved")
	var got := 0
	for stop in range(10):
		var boxes := _house()
		got += LootDress._house_med(boxes, BUILDINGS, {0: boxes.keys()}, 100 + stop, decks)
	assert_eq(got, 3, "the full houses were not counted")
