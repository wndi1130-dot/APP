extends "res://addons/gut/test.gd"
## J06(방·용기의 의미로 전리품, 이름이 로직 키인 구조 나누기): 전리품은 상자의 "room"과 건물의
## "loot_kind"·"dead_place"·"dead_wear" 열쇠를 읽는다. 지도가 주면 그것, 아니면 이름 낱말에서 한 번
## 읽어 적는다 — 열쇠가 적힌 뒤에는 표시 이름을 바꿔도 같은 전리품, 같은 망자 자리. 다시 뒤져도
## 물건이 늘지 않는다.

const FieldMaps = preload("res://game/world/field_maps.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const LootRules = preload("res://game/sim/loot_rules.gd")
const FieldGame = preload("res://game/field_game.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")

## map-layout's room kinds (room_furnish.gd PALETTE) read as ours (card I).
const PALETTE_ROOM: Dictionary = {"bed": "bedroom", "living": "bedroom", "kitchen": "kitchen", "bath": "bathroom", "office": "office", "shop": "shop", "store": "pantry", "boiler": "toolbox", "storage": "storage"}

const MAPS: Array[String] = ["first_leg_01_sulechow", "houses_01", "houses_04", "hospital_01", "factory_01", "freight_01", "church_01", "lodge_01", "lake_01", "office_01"]


func _renamed(data: Dictionary) -> void:
	var i := 0
	for id in data["containers"]:
		data["containers"][id]["name"] = "상자 %d" % i
		i += 1
	for b in data["buildings"]:
		b["name"] = "건물 %d" % i
		i += 1


func test_once_the_keys_are_on_a_renamed_map_dresses_the_same() -> void:
	for n in range(1, MAPS.size() + 1):
		var a := FieldMaps.build(MAPS[n - 1])
		LootDress.dress(a, n)
		var b := FieldMaps.build(MAPS[n - 1])
		LootDress.name_keys(b)
		LootRules.place_keys(b["buildings"])
		_renamed(b)
		LootDress.dress(b, n)
		var same := 0
		for id in a["containers"]:
			assert_eq(b["containers"][id]["items"], a["containers"][id]["items"], "%s %s" % [MAPS[n - 1], id])
			same += 1
		assert_gt(same, 0, MAPS[n - 1])


func test_the_fallen_stand_where_they_stood_after_renaming() -> void:
	var told := 0
	for map_id: String in MAPS:
		var a := FieldMaps.build(map_id)
		var b := FieldMaps.build(map_id)
		LootRules.place_keys(b["buildings"])
		_renamed(b)
		for bd: Dictionary in a["buildings"]:
			if not bd.has("rect"):
				continue
			var cell: Vector2i = (bd["rect"] as Rect2i).get_center()
			var place := LootRules.place_at(a["buildings"], cell)
			assert_eq(LootRules.place_at(b["buildings"], cell), place, "%s %s" % [map_id, bd["name"]])
			assert_eq(LootRules.wear_place_at(b["buildings"], cell), LootRules.wear_place_at(a["buildings"], cell), "%s %s" % [map_id, bd["name"]])
			if place != "":
				told += 1
	assert_gt(told, 5, "some buildings say where the fallen stood")


func test_a_key_the_map_gives_wins_over_the_name() -> void:
	var buildings: Array = [{"name": "주택", "rect": Rect2i(0, 0, 4, 4), "loot_kind": "bakery", "dead_place": "hospital", "dead_wear": "police"}]
	var c := {"name": "안방 서랍", "building": 0, "room": "kitchen"}
	assert_eq(LootDress.room_of(c), "kitchen")
	assert_eq(LootDress._building_kind_of(buildings, c), "bakery")
	assert_eq(LootRules.place_at(buildings, Vector2i(1, 1)), "hospital")
	assert_eq(LootRules.wear_place_at(buildings, Vector2i(1, 1)), "police")
	# Without keys the name is read, once, and written.
	var data := {"containers": {"x": {"name": "부엌 찬장", "building": 0}}, "buildings": [{"name": "빵집"}]}
	LootDress.name_keys(data)
	assert_eq(data["containers"]["x"]["room"], "kitchen")
	assert_eq(data["buildings"][0]["loot_kind"], "bakery")


func test_a_box_searched_again_holds_no_more() -> void:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	for id in game.data["containers"]:
		var c: Dictionary = game.data["containers"][id]
		if bool(c.get("locked", false)) or c.has("pick") or (c["items"] as Array).is_empty():
			continue
		var before: Array = (c["items"] as Array).duplicate()
		game.actions._searched(game.player, String(id))
		game.hud._close_modal()
		game.actions._searched(game.player, String(id))
		game.hud._close_modal()
		game.actions.search(game.player, String(id))
		game.hud._close_modal()
		assert_eq(c["items"], before, "the same things however often it is opened")
		assert_true(game.data["buildings"].any(func(b: Dictionary) -> bool: return b.has("dead_place")), "the fallen's keys are on the buildings")
		return
	fail_test("no box to search")


## Card I: a box's room is what its furniture says when map-layout lays that furniture in one kind
## of room only; a shelf laid in several says nothing. Before it a key the map gives, after it the name.
func test_the_furniture_says_the_room_when_it_is_of_one_room() -> void:
	var rooms_of: Dictionary = {}
	for room: String in RoomFurnish.PALETTE:
		for item: Dictionary in RoomFurnish.PALETTE[room]:
			if bool(item.get("holds", false)):
				if not rooms_of.has(item["kind"]):
					rooms_of[item["kind"]] = {}
				rooms_of[item["kind"]][room] = true
	for kind: String in rooms_of:
		var rooms: Array = (rooms_of[kind] as Dictionary).keys()
		if rooms.size() == 1:
			assert_eq(LootDress.FURNITURE_ROOM.get(kind, ""), PALETTE_ROOM[rooms[0]], "%s: laid in %s only" % [kind, rooms[0]])
		else:
			assert_false(LootDress.FURNITURE_ROOM.has(kind), "%s: laid in %s, says nothing" % [kind, str(rooms)])
	for kind: String in LootDress.FURNITURE_ROOM:
		assert_true(rooms_of.has(kind) or kind == "counter", "%s comes from the palette (the counter from the kitchen's run)" % kind)
	assert_eq(LootDress.FURNITURE_ROOM["counter"], "kitchen")
	# A key, then the furniture, then the name.
	assert_eq(LootDress.room_of({"name": "공구 보관함", "furniture": "washstand"}), "bathroom")
	assert_eq(LootDress.room_of({"name": "공구 보관함", "furniture": "shelf"}), "toolbox", "a shelf says nothing: the name")
	assert_eq(LootDress.room_of({"name": "현관 보관함", "furniture": "wardrobe", "room": "office"}), "office")
	var data := {"containers": {"x": {"name": "현관 방 보관함", "furniture": "dresser"}}, "buildings": []}
	LootDress.name_keys(data)
	assert_eq(data["containers"]["x"]["room"], "bedroom")

