extends "res://addons/gut/test.gd"
## Boxes carry the key of the room they stand in (loot_dress.gd room_of reads it before the
## name), and a kitchen's spare counters, cupboards and fridge get an empty box each.

const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const Furnish = preload("res://game/world/room_furnish.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")


func test_room_keys_follow_the_kind_then_the_name_then_the_role() -> void:
	assert_eq(Furnish.room_key("kitchen", "", ""), "kitchen")
	assert_eq(Furnish.room_key("bed", "", ""), "bedroom")
	assert_eq(Furnish.room_key("living", "", ""), "bedroom", "a living room deals as a bedroom")
	assert_eq(Furnish.room_key("bath", "", ""), "bathroom")
	assert_eq(Furnish.room_key("store", "", ""), "pantry")
	assert_eq(Furnish.room_key("boiler", "", ""), "toolbox")
	assert_eq(Furnish.room_key("storage", "벽장 저장 칸 ", ""), "bedroom", "a closet split off a bedroom")
	assert_eq(Furnish.room_key("storage", "찬방 저장 칸 ", ""), "pantry", "a pantry split off a kitchen")
	assert_eq(Furnish.room_key("", "진료실 ", ""), "clinic")
	assert_eq(Furnish.room_key("", "공구방 ", ""), "toolbox")
	assert_eq(Furnish.room_key("", " ", "shop"), "shop")
	assert_eq(Furnish.room_key("", " ", "office"), "office")
	assert_eq(Furnish.room_key("", " ", "shed"), "", "no key where the room is not known")
	for key in Furnish.ROOM_KEYS.values():
		assert_true(LootDress.AFFINITY.has(key), key + " is a key the loot reads")


func test_kitchens_get_empty_boxes_in_spare_furniture_and_keys_stand() -> void:
	var data := FieldMaps.build("houses_01")
	var g: FieldGrid = data["grid"]
	var added := 0
	var keyed := 0
	for id: String in data["containers"]:
		var c: Dictionary = data["containers"][id]
		if c.has("room"):
			keyed += 1
			assert_true(LootDress.AFFINITY.has(String(c["room"])), id)
		if not id.begins_with("kitchen_"):
			continue
		added += 1
		assert_eq(c["room"], "kitchen", id)
		assert_true(Furnish.KITCHEN_SPARE.has(String(c["furniture"])), id)
		assert_eq((c["items"] as Array).size(), 0, id + " starts empty")
		assert_eq(float(c["search"]), Furnish.KITCHEN_SEARCH, id + " is quick to open")
		var front := false
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			front = front or g.people_can_walk(c["cell"] + d)
		assert_true(front or int(c.get("level", 0)) != 0, id + " is opened from a cell reached on foot")
	assert_gt(added, 0, "some kitchen gets more places to open")
	assert_true(_kitchens_at_most(data, Furnish.KITCHEN_MOST), "no kitchen past %d places to open" % Furnish.KITCHEN_MOST)
	assert_eq(added, int(data["box_rooms"]["kitchen_added"]))
	assert_gt(keyed, data["containers"].size() / 2, "most boxes know their room")
	# Again on the same map: nothing more is added and no key changes.
	var before: Dictionary = data["containers"].duplicate(true)
	Furnish.boxes_into_furniture(data)
	assert_eq(data["containers"], before)


## Every kitchen room that got an added box has at most `most` boxes in it.
func _kitchens_at_most(data: Dictionary, most: int) -> bool:
	for lv: int in data["levels"]:
		var g: FieldGrid = data["levels"][lv]
		var of: PackedInt32Array = Furnish.rooms_of(g)["of"]
		var count: Dictionary = {}
		var grown: Dictionary = {}
		for id: String in data["containers"]:
			var c: Dictionary = data["containers"][id]
			if int(c.get("level", 0)) != lv:
				continue
			var ri := Furnish._at(g, of, c["cell"])
			count[ri] = int(count.get(ri, 0)) + 1
			if id.begins_with("kitchen_"):
				grown[ri] = true
		for ri in grown:
			if int(count[ri]) > most:
				return false
	return true
