extends "res://addons/gut/test.gd"
## 상자 속 잡동사니(결정 444, 차이 목록 5; 대조 글 coord\review\좀보이드_잡동사니_대조_20261026.md):
## 본 꾸러미보다 먼저, 방 종류마다 줄마다 따로 굴려 상자당 많아야 둘. 가볍고 열차에서 조금
## 녹는다. 목표·고정·잠긴 상자와 건물 밖 상자는 그대로.

const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const LootJunk = preload("res://game/sim/loot_junk.gd")
const Carry = preload("res://game/sim/carry.gd")
const Receipt = preload("res://game/sim/receipt.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")

const MAPS: Array[String] = ["houses_04", "houses_06", "office_01", "hospital_01", "factory_01", "freight_01", "church_01", "lodge_01"]


func test_the_things_are_light_named_pictured_and_melt_a_little() -> void:
	var ids: Dictionary = {}
	for rows: Array in LootJunk.JUNK.values():
		for row: Array in rows:
			ids[String(row[0])] = true
			assert_between(float(row[1]), 0.0, 0.35, "a chance: " + String(row[0]))
	for id: String in ids:
		assert_true(FieldItems.has(id), id)
		assert_lte(FieldItems.weight(id), 0.2, "light: " + id)
		assert_true(FieldItems.item_name(id).length() <= 9, "short: " + id)
		assert_true(HudIcons.PATHS.has(FieldItems.icon(id)), "a picture: " + id)
		var melt: Array = FieldItems.stock_of(id)
		assert_true(String(melt[0]) == "" or Receipt.STOCK_KEYS.has(melt[0]), id)
		assert_lte(float(melt[1]), 0.1, "worth little: " + id)
	assert_eq(LootJunk.JUNK_MOST, 2)
	# The values listed in the PR.
	assert_eq(LootJunk.JUNK["kitchen"], [["can_empty", 0.25], ["junk_rag", 0.15], ["junk_paper", 0.10]])
	assert_eq(LootJunk.JUNK["bedroom"], [["junk_smokes", 0.12], ["junk_paper", 0.08], ["junk_rag", 0.05]])


func test_each_row_is_its_own_roll_and_at_most_two_a_box() -> void:
	var hits: Dictionary = {}
	var runs := 2000
	for seed in range(1, runs + 1):
		var boxes := {"k": {"name": "부엌 찬장", "building": 0, "items": []}}
		var n := LootJunk.strew(boxes, seed, {"k": "kitchen"})
		assert_lte(n, LootJunk.JUNK_MOST)
		assert_eq((boxes["k"]["items"] as Array).size(), n)
		for item in boxes["k"]["items"]:
			hits[item] = int(hits.get(item, 0)) + 1
	# Each row near its own chance (the cap of two takes a little off the last).
	for row: Array in LootJunk.JUNK["kitchen"]:
		assert_almost_eq(int(hits.get(row[0], 0)) / float(runs), float(row[1]), 0.03, String(row[0]))


func test_goal_fixed_locked_and_outdoor_boxes_are_left_alone() -> void:
	for seed in range(1, 200):
		var boxes := {
			"goal": {"name": "부엌 찬장", "building": 0, "items": ["food_pack"], "pick": true},
			"bell": {"name": "부엌 찬장", "building": 0, "items": ["symbol_bell"]},
			"safe": {"name": "부엌 찬장", "building": 0, "items": [], "locked": true},
			"out": {"name": "부엌 찬장", "building": -1, "items": []},
		}
		LootJunk.strew(boxes, seed, {"goal": "kitchen", "bell": "kitchen", "safe": "kitchen", "out": "kitchen"})
		assert_eq(boxes["goal"]["items"], ["food_pack"])
		assert_eq(boxes["bell"]["items"], ["symbol_bell"])
		assert_eq(boxes["safe"]["items"], [])
		assert_eq(boxes["out"]["items"], [])


func test_fewer_boxes_come_up_empty_and_the_bedroom_still_most_often() -> void:
	# Before and after on the maps (the PR's table), and the order of rooms kept.
	var before := {"seen": {}, "empty": {}}
	var after := {"seen": {}, "empty": {}}
	var junk := 0
	for place: String in MAPS:
		var base: Dictionary = FieldMaps.build(place)
		for seed in range(1, 11):
			for side: Dictionary in [before, after]:
				var d: Dictionary = base.duplicate(true)
				if side == before:
					# As before: the odds and ends taken back out (what the map held stays).
					LootDress.dress(d, seed)
					for id: String in d["containers"]:
						d["containers"][id]["items"] = (d["containers"][id]["items"] as Array).filter(func(i) -> bool: return not _is_junk(String(i)) or _was_there(base, id, String(i)))
				else:
					junk += int(LootDress.dress(d, seed)["junk"])
				for id: String in d["containers"]:
					var c: Dictionary = d["containers"][id]
					if int(c.get("building", -1)) < 0 or c.has("pick"):
						continue
					var room := LootDress.room_of(c)
					side["seen"][room] = int(side["seen"].get(room, 0)) + 1
					if (c["items"] as Array).is_empty():
						side["empty"][room] = int(side["empty"].get(room, 0)) + 1
	assert_gt(junk, 0, "some went in")
	var share := func(side: Dictionary, room: String) -> float:
		return float(side["empty"].get(room, 0)) / maxf(1.0, float(side["seen"].get(room, 0)))
	var lines: Array = []
	for room: String in after["seen"]:
		lines.append("%s %.2f→%.2f" % [room, share.call(before, room), share.call(after, room)])
		assert_lte(share.call(after, room), share.call(before, room) + 0.0001, room)
	gut.p(" · ".join(lines))
	assert_lt(share.call(after, "kitchen"), share.call(after, "bedroom"), "the bedroom is still the one to skip")


func _is_junk(item: String) -> bool:
	for rows: Array in LootJunk.JUNK.values():
		for row: Array in rows:
			if String(row[0]) == item:
				return true
	return false


func _was_there(base: Dictionary, id: String, item: String) -> bool:
	return base["containers"].has(id) and (base["containers"][id].get("items", []) as Array).has(item)
