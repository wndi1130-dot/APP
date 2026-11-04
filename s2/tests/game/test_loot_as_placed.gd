extends GutTest
## 지도가 놓은 상자는 정차 전 꾸미기에도 내용과 순서를 유지한다.

const FieldMaps = preload("res://game/world/field_maps.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const LootTables = preload("res://game/sim/loot_tables.gd")
const LootRules = preload("res://game/sim/loot_rules.gd")
const LootJunk = preload("res://game/sim/loot_junk.gd")
const RoomStories = preload("res://game/world/room_stories.gd")
const SideNote = preload("res://game/sim/side_note.gd")
const FloorStash = preload("res://game/sim/floor_stash.gd")

const ITEMS: Array[String] = ["nails", "junk_rag", "junk_paper"]


func _places() -> Array[String]:
	# The story map exercises the hand-made path; houses_01 also has room stories.
	var places: Array[String] = ["houses_01"]
	if FieldMaps.has("story_01"):
		places.push_front("story_01")
	return places


func _pair(data: Dictionary) -> Array[String]:
	var containers: Dictionary = data["containers"]
	var ids: Array = containers.keys()
	ids.sort()
	var by_building: Dictionary = {}
	for id: String in ids:
		var c: Dictionary = containers[id]
		var b: int = int(c.get("building", -1))
		if b < 0 or c.has("pick") or LootTables.FIXED.has(id) or bool(c.get("locked", false)) or bool(c.get("searched", false)):
			continue
		if by_building.has(b):
			return [String(by_building[b]), id]
		by_building[b] = id
	return []


func _prepare(data: Dictionary, ids: Array[String], protected: bool) -> void:
	for i: int in range(ids.size()):
		var c: Dictionary = data["containers"][ids[i]]
		# Preserve the room before giving the stash a unique, deterministic target.
		c["room"] = LootDress.room_of(c)
		c["name"] = "asplaced_pair_%d" % i
		c["items"] = ITEMS.duplicate()
		c.erase("as_placed")
		if protected:
			c["as_placed"] = true


func _assert_pair(data: Dictionary, ids: Array[String], before: Dictionary, stage: String) -> void:
	for id: String in ids:
		assert_eq(data["containers"][id], before[id], "%s: %s (items, order and box metadata)" % [stage, id])


func _stories(data: Dictionary, seed: int) -> Array:
	if data.has("room_stats"):
		return RoomStories.apply(data, ("%d:stories:%s" % [seed, data["place_id"]]).hash())
	return []


func test_as_placed_pair_survives_stop_rules() -> void:
	for place: String in _places():
		for seed: int in range(1, 13):
			# Fresh grids too: RoomStories changes doors and furniture.
			var data: Dictionary = FieldMaps.build(place)
			var ids: Array[String] = _pair(data)
			assert_eq(ids.size(), 2, "two ordinary indoor boxes: " + place)
			if ids.size() != 2:
				return
			_prepare(data, ids, true)
			var before: Dictionary = (data["containers"] as Dictionary).duplicate(true)
			LootDress.dress(data, seed, {}, true)
			_assert_pair(data, ids, before, "%s seed %d dress" % [place, seed])
			for i: int in range(ids.size()):
				var into: String = LootDress.place_stash(data, "asplaced_pair_%d" % i, seed)
				assert_false(ids.has(into), "stash skips both protected boxes")
			_assert_pair(data, ids, before, "stash")
			var stories: Array = _stories(data, seed)
			_assert_pair(data, ids, before, "room stories")
			LootJunk.spill_looted(data, stories, seed)
			_assert_pair(data, ids, before, "looted spill")


func test_unmarked_pair_really_changes_under_the_same_stop_rules() -> void:
	for place: String in _places():
		var changed: Array[bool] = [false, false]
		for seed: int in range(1, 13):
			var data: Dictionary = FieldMaps.build(place)
			var ids: Array[String] = _pair(data)
			assert_eq(ids.size(), 2, place)
			if ids.size() != 2:
				return
			_prepare(data, ids, false)
			LootDress.dress(data, seed, {}, true)
			# Unique stash names guarantee a useful negative control without relying
			# on a rare random find or putting unnamed bundles in protected boxes.
			for i: int in range(ids.size()):
				assert_eq(LootDress.place_stash(data, "asplaced_pair_%d" % i, seed), ids[i])
			var stories: Array = _stories(data, seed)
			LootJunk.spill_looted(data, stories, seed)
			for i: int in range(ids.size()):
				changed[i] = changed[i] or data["containers"][ids[i]]["items"] != ITEMS
		assert_true(changed[0], place + ": first unmarked box changed")
		assert_true(changed[1], place + ": second unmarked box changed")


func test_fill_leaves_as_placed_boxes_even_when_fixed_or_empty() -> void:
	for seed: int in range(1, 13):
		var data: Dictionary = FieldMaps.build(_places()[0])
		var ids: Array[String] = _pair(data)
		assert_eq(ids.size(), 2)
		if ids.size() != 2:
			return
		_prepare(data, ids, true)
		# A fixed box with a plus roll and an empty ordinary box must both stay put.
		var containers: Dictionary = data["containers"]
		containers["pharmacy_store"] = {"name": "약국", "items": ITEMS.duplicate(), "as_placed": true}
		containers["asplaced_empty"] = {"name": "부엌 찬장", "items": [], "as_placed": true}
		containers["bell"] = {"items": []}
		var before: Dictionary = containers.duplicate(true)
		LootRules.fill(containers, seed)
		_assert_pair(data, ids, before, "fill")
		assert_eq(containers["pharmacy_store"], before["pharmacy_store"])
		assert_eq(containers["asplaced_empty"], before["asplaced_empty"])
		assert_eq(containers["bell"]["items"], LootTables.FIXED["bell"]["items"], "unmarked fixed box still fills")


func test_missing_and_false_as_placed_dress_identically() -> void:
	for place: String in _places():
		var base: Dictionary = FieldMaps.build(place)
		for c: Dictionary in (base["containers"] as Dictionary).values():
			c.erase("as_placed")
		for seed: int in range(1, 13):
			var absent: Dictionary = base.duplicate(true)
			var explicit_false: Dictionary = base.duplicate(true)
			for c: Dictionary in (explicit_false["containers"] as Dictionary).values():
				c["as_placed"] = false
			var expected: Dictionary = LootDress.dress(absent, seed, {}, true)
			var actual: Dictionary = LootDress.dress(explicit_false, seed, {}, true)
			assert_eq(actual, expected, "%s seed %d: report and deck" % [place, seed])
			for c: Dictionary in (explicit_false["containers"] as Dictionary).values():
				c.erase("as_placed")
			assert_eq(explicit_false["containers"], absent["containers"], "all items and their order")
			assert_eq(explicit_false["buildings"], absent["buildings"], "building keys")


func test_as_placed_rare_store_is_not_refilled() -> void:
	for seed: int in range(1, 13):
		var box: Dictionary = {"name": "공구 상자", "building": 0, "items": ITEMS.duplicate(), "as_placed": true}
		var data: Dictionary = {"containers": {"kept": box}, "buildings": [{"name": LootDress.RARE_STORE}], "place_kind": "freight"}
		var before: Dictionary = box.duplicate(true)
		LootDress.dress(data, seed, {}, true)
		assert_eq(box, before, "rare store and all other dressing leave the box intact")


func test_empty_as_placed_floor_stash_and_desk_are_not_filled() -> void:
	var saw_note: bool = false
	for seed: int in range(1, 49):
		var box: Dictionary = {"items": [], "furniture": "desk", "as_placed": true}
		var data: Dictionary = {"containers": {"kept": box}, "floor_stashes": [{"id": "kept"}],
			"side_path": {"store": Rect2i(50, 50, 4, 4), "boxes": []}}
		assert_eq(FloorStash.fill(data, seed), [])
		assert_eq(SideNote.place(data, [], seed), "")
		assert_eq(box["items"], [], "empty is also placed content")
		box.erase("as_placed")
		saw_note = SideNote.place(data, [], seed) == "desk" or saw_note
		box["items"] = []
		assert_false(FloorStash.fill(data, seed).is_empty(), "unmarked empty stash fills")
	assert_true(saw_note, "unmarked desk can receive the note")


func test_looted_spill_does_not_use_an_as_placed_kept_box() -> void:
	var data: Dictionary = FieldMaps.build("houses_01")
	var ids: Array[String] = _pair(data)
	assert_eq(ids.size(), 2)
	if ids.size() != 2:
		return
	_prepare(data, ids, true)
	var b: int = int(data["containers"][ids[0]]["building"])
	var eligible: Array = RoomStories._boxes(data, b)
	assert_false(eligible.has(ids[0]))
	assert_false(eligible.has(ids[1]))
	# Only the protected pair holds anything; every other box is a spill target.
	for id: String in data["containers"]:
		if ids.has(id):
			continue
		var box: Dictionary = data["containers"][id]
		box["items"] = []
		box["searched"] = true
	var before: Dictionary = (data["containers"] as Dictionary).duplicate(true)
	assert_eq(LootJunk.spill_looted(data, [{"story": "looted", "building": b}], 5), [])
	_assert_pair(data, ids, before, "direct spill")
