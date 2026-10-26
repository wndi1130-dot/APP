extends "res://addons/gut/test.gd"
## 갈래별 보장 몫(카드 S1, 결정 442): 정차 안 먹을 것 가게 10곳 중 7곳, 약국·진료소 10곳 중
## 7곳은 그 꾸러미를 하나 이상 든다. 물건을 더하지 않고 둘 이상 든 건물에서 옮겨 오니 정차
## 무게 합은 그대로, 이미 넘는 곳은 건드리지 않는다.

const LootDress = preload("res://game/sim/loot_dress.gd")
const FieldItems = preload("res://game/sim/field_items.gd")


## `shops` grocery shops, the first `full` of them holding `each` food bundles, and a house
## holding `home` of them.
func _stop(shops: int, full: int, each: int, home: int) -> Dictionary:
	var buildings: Array = []
	var boxes := {}
	for i in range(shops):
		buildings.append({"name": "식료품 가게 %d" % i})
		var items: Array = []
		if i < full:
			for k in range(each):
				items.append("food_pack")
		boxes["s%02d" % i] = {"name": "가게 진열대", "building": i, "items": items, "locked": false, "searched": false}
	buildings.append({"name": "주택"})
	var home_items: Array = []
	for k in range(home):
		home_items.append("food_pack")
	boxes["h"] = {"name": "부엌 찬장", "building": shops, "items": home_items, "locked": false, "searched": false}
	return {"place_kind": "houses", "buildings": buildings, "containers": boxes}


func _food(c: Dictionary) -> int:
	var n := 0
	for item in c.get("items", []):
		var s := String(item)
		if s == "food_pack" or String(FieldItems.row(s).get("from", "")) == "food_pack":
			n += 1
	return n


func _shops_with_food(d: Dictionary, shops: int) -> int:
	var n := 0
	for i in range(shops):
		if _food(d["containers"]["s%02d" % i]) > 0:
			n += 1
	return n


func _all_food(d: Dictionary) -> int:
	var n := 0
	for id: String in d["containers"]:
		n += _food(d["containers"][id])
	return n


func test_seven_of_ten_shops_hold_food_and_none_is_added() -> void:
	for seed in range(1, 41):
		var d := _stop(10, 4, 2, 3)
		var report := LootDress.dress(d, seed)
		assert_eq(_shops_with_food(d, 10), 7, "seed %d" % seed)
		assert_eq(_all_food(d), 11, "moved, not added")
		assert_eq(_food(d["containers"]["h"]), 3, "the shops' own spare goes first")
		assert_eq(report["promised"]["food"], [10, 7, 4, 3])


func test_with_nothing_to_spare_nothing_is_made() -> void:
	for seed in range(1, 41):
		var d := _stop(3, 0, 0, 1)
		var report := LootDress.dress(d, seed)
		assert_eq(_shops_with_food(d, 3), 0, "no building holds two")
		assert_eq(_all_food(d), 1)
		assert_eq(int(report["promised"]["food"][3]), 0)


func test_a_house_gives_when_no_shop_can() -> void:
	var d := _stop(1, 0, 0, 3)
	# One shop: 0.7 of one, so most seeds want it.
	var wanted := 0
	for seed in range(1, 201):
		d = _stop(1, 0, 0, 3)
		var report := LootDress.dress(d, seed)
		var want: int = report["promised"]["food"][1]
		wanted += want
		assert_eq(_shops_with_food(d, 1), want, "seed %d" % seed)
		assert_eq(_all_food(d), 3)
	assert_almost_eq(wanted / 200.0, 0.7, 0.08, "the part of one is rolled")


func test_shops_above_the_share_are_left_alone() -> void:
	var d := _stop(10, 10, 1, 0)
	var report := LootDress.dress(d, 5)
	assert_eq(_shops_with_food(d, 10), 10)
	assert_eq(int(report["promised"]["food"][3]), 0)


func test_a_pharmacy_and_a_clinic_get_medicine_the_same_way() -> void:
	for seed in range(1, 41):
		var d := {"place_kind": "hospital", "buildings": [{"name": "약국"}, {"name": "진료소"}, {"name": "주택"}], "containers": {
			"a": {"name": "약장", "building": 0, "items": [], "locked": false, "searched": false},
			"b": {"name": "진료 상자", "building": 1, "items": [], "locked": false, "searched": false},
			"h": {"name": "욕실 수납장", "building": 2, "items": ["med_box", "med_box", "med_box"], "locked": false, "searched": false},
		}}
		var report := LootDress.dress(d, seed)
		var places := 0
		var all := 0
		for id in ["a", "b", "h"]:
			var here := 0
			for item in d["containers"][id]["items"]:
				if String(FieldItems.row(String(item)).get("from", "")) == "med_box":
					here += 1
			all += here
			if id != "h" and here > 0:
				places += 1
		# Two places: 1.4 of them, so one or two.
		var want: int = report["promised"]["med"][1]
		assert_between(want, 1, 2)
		assert_eq(places, want, "seed %d" % seed)
		assert_eq(all, 3, "moved, not added")


# ---------------------------------------------------------------- 정차를 넘는 덱 (lootDeck, s3-link)

## A stop with a garage (a toolbox in it) and a house with a kitchen and a bedroom.
func _garage_stop(garage: bool) -> Dictionary:
	var buildings: Array = [{"name": "차고" if garage else "주택"}, {"name": "주택"}]
	return {"place_kind": "houses", "buildings": buildings, "containers": {
		"g": {"name": "공구함", "building": 0, "items": [], "locked": false, "searched": false},
		"k": {"name": "부엌 찬장", "building": 1, "items": [], "locked": false, "searched": false},
		"b": {"name": "안방 옷장", "building": 1, "items": [], "locked": false, "searched": false},
	}}


func _count_of(d: Dictionary, item: String) -> int:
	var n := 0
	for id: String in d["containers"]:
		n += (d["containers"][id]["items"] as Array).count(item)
	return n


func test_a_fresh_deck_rolls_what_the_old_chances_did() -> void:
	assert_eq(LootDress._chance(LootDress._deck_row({}, "garage_fuel")), LootDress.FUEL_CHANCE)
	assert_eq(LootDress._chance(LootDress._deck_row({}, "pan")), LootDress.PAN_CHANCE)
	assert_eq(LootDress._chance(LootDress._deck_row({}, "bottle")), LootDress.BOTTLE_CHANCE)
	# With no deck handed in, the stop keeps its own share and says where the decks stand.
	var d := _stop(3, 1, 2, 0)
	var report := LootDress.dress(d, 4)
	for id: String in LootDress.DECKS:
		assert_true(report["loot_deck"].has(id), id)
	assert_eq(report["loot_deck"]["food_shop"], {"n": 10, "k": 7, "seen": 3, "hit": _shops_with_food(d, 3)})


func test_over_ten_garage_stops_exactly_three_fuel_five_pans_four_bottles() -> void:
	for start in [1, 101, 201]:
		var deck := {}
		var got := {"fuel_can": 0, "frying_pan": 0, "broken_bottle": 0}
		for i in range(20):
			# Every other stop has no garage: it turns no fuel card.
			var garage := i % 2 == 0
			var d := _garage_stop(garage)
			var report := LootDress.dress(d, start + i, deck)
			deck = report["loot_deck"]
			for item: String in got:
				got[item] += _count_of(d, item)
		assert_eq(got["fuel_can"], 3, "10 garage stops, start %d" % start)
		assert_eq(got["frying_pan"], 10, "20 stops")
		assert_eq(got["broken_bottle"], 8, "20 stops")
		assert_eq(int(deck["garage_fuel"]["seen"]), 0, "the batch starts again at ten")


func test_over_ten_shops_seven_hold_food_and_those_holding_count() -> void:
	for start in [1, 51]:
		var deck := {}
		var with_food := 0
		var moved := 0
		for i in range(10):
			# The first four shops hold food already; the house can always spare.
			var d := _stop(1, 1 if i < 4 else 0, 1, 3)
			var report := LootDress.dress(d, start + i, deck)
			deck = report["loot_deck"]
			with_food += _shops_with_food(d, 1)
			moved += int(report["promised"]["food"][3])
			assert_eq(_all_food(d), 4 if i < 4 else 3, "moved, not added")
		assert_eq(with_food, 7, "start %d" % start)
		assert_eq(moved, 3, "only what was missing")


func test_a_deck_of_other_numbers_starts_a_new_batch() -> void:
	var report := LootDress.dress(_garage_stop(true), 1, {"garage_fuel": {"n": 8, "k": 5, "seen": 7, "hit": 0}})
	assert_eq(int(report["loot_deck"]["garage_fuel"]["n"]), 10)
	assert_eq(int(report["loot_deck"]["garage_fuel"]["seen"]), 1)
	# One with every card left to come up gives it.
	var d := _garage_stop(true)
	LootDress.dress(d, 1, {"garage_fuel": {"n": 10, "k": 3, "seen": 7, "hit": 0}})
	assert_eq(_count_of(d, "fuel_can"), 1)
	d = _garage_stop(true)
	LootDress.dress(d, 1, {"garage_fuel": {"n": 10, "k": 3, "seen": 5, "hit": 3}})
	assert_eq(_count_of(d, "fuel_can"), 0)
