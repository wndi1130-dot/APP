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
