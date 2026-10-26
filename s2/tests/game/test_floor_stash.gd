extends "res://addons/gut/test.gd"
## The hidden place under a loose board (room_stories.gd, card K): one floor cell of a lived-in
## bedroom or living room, away from doors, stairs, furniture and boxes; an empty box for the
## loot to fill, a creak in the sound table.

const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")
const RoomStories = preload("res://game/world/room_stories.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const PLACE := "houses_01"


static var _found: Array = []


func after_all() -> void:
	_found.clear()


## The first seed (from 1) that gives PLACE a hidden place, with its map: [seed, data].
## Found once for the file: each try may need the map built again.
func _with_stash() -> Array:
	if _found.is_empty():
		_found = _first_stash()
	return _found


func _first_stash() -> Array:
	var data := FieldMaps.build(PLACE)
	for s in range(1, 40):
		var out := RoomStories.apply(data, s)
		for row: Dictionary in out:
			if row["story"] == "floor_stash":
				return [s, data]
		if data.has("floor_stashes") or out.size() > 0:
			data = FieldMaps.build(PLACE)  # the stories changed the map: start clean
	return [-1, {}]


func test_a_hidden_place_lies_on_open_floor_of_a_lived_in_room() -> void:
	var found := _with_stash()
	assert_gt(found[0], 0, "some seed hides something under a board")
	if found[0] < 0:
		return
	var data: Dictionary = found[1]
	assert_eq(data["floor_stashes"].size(), 1, "one at a stop")
	var spot: Dictionary = data["floor_stashes"][0]
	var box: Dictionary = data["containers"][spot["id"]]
	var lv: int = spot["level"]
	var c: Vector2i = spot["cell"]
	var g: FieldGrid = data["levels"][lv]
	assert_eq(box["cell"], c)
	assert_eq(box["name"], RoomStories.STASH_NAME)
	assert_eq((box["items"] as Array).size(), 0, "the loot fills it, not the map")
	assert_eq(float(box["search"]), RoomStories.STASH_SEARCH)
	assert_eq(box["stash"], "floor")
	assert_eq(box["furniture"], "loose_board", "drawn as a mark on the floor, not a crate")
	assert_true(g.people_can_walk(c), "the board is walked over")
	var boards := 0
	for p: Dictionary in data["props"]:
		if p["kind"] == "loose_board":
			boards += 1
			assert_eq(p["rect"], Rect2i(c, Vector2i.ONE))
			assert_eq(p["solid"], "none")
	assert_eq(boards, 1)
	# A bedroom or living room of a home, away from every other prop and box.
	var map := RoomFurnish.rooms_of(g)
	var ri := RoomFurnish._at(g, map["of"], c)
	assert_gt(ri, -1)
	assert_eq(int(map["rooms"][ri]["building"]), int(box["building"]))
	var forbid := RoomFurnish._forbidden(g, map["of"], ri, map["rooms"][ri]["cells"], RoomFurnish._stairs_by_level(data).get(lv, {}))
	assert_false(forbid.has(c), "not in front of a door, stair or window")
	for p: Dictionary in data["props"]:
		if p["kind"] != "loose_board" and int(p.get("level", 0)) == lv:
			assert_false((RoomFurnish._rect(p["rect"]) as Rect2i).grow(1).has_point(c), "not beside %s" % p["kind"])
	for id: String in data["containers"]:
		var other: Dictionary = data["containers"][id]
		if id != spot["id"] and int(other.get("level", 0)) == lv:
			var d: Vector2i = ((other["cell"] as Vector2i) - c).abs()
			assert_true(maxi(d.x, d.y) > 1, "not beside box " + id)


func test_the_same_seed_hides_it_in_the_same_place_and_the_creak_is_a_quiet_rule_sound() -> void:
	var found := _with_stash()
	if found[0] < 0:
		fail_test("no hidden place")
		return
	var again := FieldMaps.build(PLACE)
	RoomStories.apply(again, found[0])
	assert_eq(again["floor_stashes"], found[1]["floor_stashes"])
	var row: Dictionary = SimNoise.SOURCES["floor_creak"]
	assert_eq(row["levels"], [SimNoise.Level.QUIET])
	assert_eq(row["at"], "spot")
