extends "res://addons/gut/test.gd"
## 맞는 가구로(결정 442): 같은 방 안에서는 그 물건을 담는 가구가 끌어당긴다 — 약장에 약, 옷장·서랍장·
## 궤에 천과 옷, 찬장·식료 선반에 먹을 것. 방이 끄는 몫(AFFINITY)은 그대로, 방 안 자리만 바뀐다.

const LootDress = preload("res://game/sim/loot_dress.gd")
const FieldItems = preload("res://game/sim/field_items.gd")


func _box(room: String, furniture: String, items: Array = []) -> Dictionary:
	return {"name": "상자", "room": room, "furniture": furniture, "building": 0, "items": items.duplicate(), "locked": false, "searched": false}


## One building: a bedroom of a wardrobe and three side tables, a larder of four shelves
## holding four cloth bundles.
func _house() -> Dictionary:
	var boxes := {
		"w": _box("bedroom", "wardrobe"),
		"t1": _box("bedroom", "side_table"), "t2": _box("bedroom", "side_table"), "t3": _box("bedroom", "side_table"),
		"p1": _box("pantry", "shelf", ["cloth", "cloth"]), "p2": _box("pantry", "shelf", ["cloth", "cloth"]),
		"p3": _box("pantry", "shelf"), "p4": _box("pantry", "shelf"),
	}
	return boxes


func _cloth(c: Dictionary) -> int:
	var n := 0
	for item in c["items"]:
		var s := String(item)
		if s == "cloth" or String(FieldItems.row(s).get("from", "")) == "cloth":
			n += 1
	return n


func test_the_wardrobe_draws_the_cloth_and_the_bedroom_its_share() -> void:
	var in_wardrobe := 0
	var in_bedroom := 0
	var all := 0
	for seed in range(1, 401):
		var boxes := _house()
		LootDress._deal(boxes, boxes.keys(), LootDress._rng(seed, "deal:0"))
		for id: String in boxes:
			var n := _cloth(boxes[id])
			all += n
			if String(boxes[id]["room"]) == "bedroom":
				in_bedroom += n
			if id == "w":
				in_wardrobe += n
	assert_eq(all, 1600, "nothing added or lost")
	# The room's share is AFFINITY's: bedroom 4.0 × 4 boxes against larder 0.3 × 4.
	var room_share := 4.0 * 4 / (4.0 * 4 + 0.3 * 4)
	assert_almost_eq(in_bedroom / float(all), room_share, 0.03, "the bedroom draws what it did")
	# In the bedroom, the wardrobe pulls 8 against the tables' 1 each: 8 of 11.
	assert_almost_eq(in_wardrobe / float(in_bedroom), 8.0 / 11.0, 0.04, "most of the bedroom's cloth is in the wardrobe")


func test_the_medicine_cabinet_draws_the_medicine() -> void:
	var cab := 0
	var all := 0
	for seed in range(1, 401):
		var boxes := {
			"m": _box("bathroom", "medicine_cabinet"),
			"s1": _box("bathroom", "washstand", ["med_box"]), "s2": _box("bathroom", "towel_shelf", ["med_box"]),
			"s3": _box("bathroom", "waste_bin"),
		}
		LootDress._deal(boxes, boxes.keys(), LootDress._rng(seed, "deal:0"))
		cab += (boxes["m"]["items"] as Array).size()
		for id: String in boxes:
			all += (boxes[id]["items"] as Array).size()
	assert_eq(all, 800)
	assert_gt(cab / float(all), 0.5, "4 of 7 in the cabinet")


func test_a_room_without_such_furniture_gives_every_box_one() -> void:
	var boxes := {"a": _box("bedroom", "side_table"), "b": _box("bedroom", ""), "k": _box("kitchen", "counter")}
	var shares := LootDress._room_shares(boxes, boxes.keys(), "cloth")
	assert_eq(shares.values(), [1.0, 1.0, 1.0])
	var mixed := _house()
	var s := LootDress._room_shares(mixed, mixed.keys(), "cloth")
	assert_almost_eq(float(s["w"]) + float(s["t1"]) + float(s["t2"]) + float(s["t3"]), 4.0, 0.0001, "a room's shares average one")
	assert_almost_eq(float(s["w"]) / float(s["t1"]), 8.0, 0.0001)


func test_clothes_found_go_to_the_wardrobe_and_rooms_without_one_roll_as_before() -> void:
	var boxes := _house()
	var ids := ["w", "t1", "t2", "t3"]
	var in_w := 0
	for i in range(1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var report := {"finds": []}
		LootDress._put_fit(boxes, ids, "scarf_thick", "cloth", rng, report)
		in_w += int(report["finds"][0][1] == "w")
	assert_almost_eq(in_w / 1000.0, 8.0 / 11.0, 0.04, "8 of 11")
	# No pulling furniture: the same box as _put on the same dice.
	var plain := {"a": _box("bedroom", "side_table"), "b": _box("bedroom", "side_table"), "c": _box("bedroom", "")}
	for i in range(200):
		var r1 := RandomNumberGenerator.new()
		r1.seed = i
		var r2 := RandomNumberGenerator.new()
		r2.seed = i
		var a := {"finds": []}
		var b := {"finds": []}
		LootDress._put_fit(plain, plain.keys(), "x", "cloth", r1, a)
		LootDress._put(plain, plain.keys(), "x", r2, b)
		assert_eq(a["finds"][0][1], b["finds"][0][1])


func test_the_new_values_are_the_listed_ones() -> void:
	assert_eq(LootDress.FURNITURE_PULL["medicine_cabinet"], {"med": 4.0, "small": 3.0})
	assert_eq(LootDress.FURNITURE_PULL["wardrobe"], {"cloth": 8.0})
	assert_eq(LootDress.FURNITURE_PULL["cupboard"], {"food": 3.0})


func test_each_building_draws_its_finds_as_before() -> void:
	# A house with a wardrobe and a side table, a house with two side tables: a find falls in
	# the second house half the time, as _put gives it, the wardrobe only wins within its own.
	var boxes := {"w": _box("bedroom", "wardrobe"), "a": _box("bedroom", "side_table"),
		"b": _box("bedroom", "side_table"), "c": _box("bedroom", "side_table")}
	boxes["b"]["building"] = 1
	boxes["c"]["building"] = 1
	var other := 0
	var in_w := 0
	for i in range(2000):
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var report := {"finds": []}
		LootDress._put_fit(boxes, ["w", "a", "b", "c"], "scarf_thick", "cloth", rng, report)
		var to := String(report["finds"][0][1])
		other += int(to == "b" or to == "c")
		in_w += int(to == "w")
	assert_almost_eq(other / 2000.0, 0.5, 0.04, "the other house keeps its half")
	assert_almost_eq(in_w / 2000.0, 0.5 * 8.0 / 9.0, 0.04, "the wardrobe takes 8 of 9 in its own house")


func test_a_full_wardrobe_leaves_its_rooms_draw_to_the_room() -> void:
	# The wardrobe already holds CAP things: the cloth falls where it would with no wardrobe
	# at all, the side tables drawing the bedroom's whole share (ref-ops check, decision 485).
	var differ := 0
	for seed in range(1, 201):
		var full := _house()
		for i in range(LootDress.CAP):
			(full["w"]["items"] as Array).append("wrist_watch")
		var none := _house()
		none.erase("w")
		LootDress._deal(full, full.keys(), LootDress._rng(seed, "deal:0"))
		LootDress._deal(none, none.keys(), LootDress._rng(seed, "deal:0"))
		for id: String in none:
			differ += int(_cloth(full[id]) != _cloth(none[id]))
		assert_eq((full["w"]["items"] as Array).size(), LootDress.CAP, "nothing more in the full wardrobe")
	assert_eq(differ, 0, "the same boxes as a bedroom without the wardrobe")
