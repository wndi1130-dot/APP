extends "res://addons/gut/test.gd"
## The scrawled map to the side path (side_note.gd, card M): on about half the side-path
## stops, in a dead one's pocket or a desk; held, it marks the way in until reached.

const SideNote = preload("res://game/sim/side_note.gd")
const SidePath = preload("res://game/world/side_path.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const FieldGame = preload("res://game/field_game.gd")
const PLACE := "houses_01"


## The first run seed (from 1) that gives PLACE a side path.
func _path_seed() -> int:
	for s in range(1, 80):
		if SidePath.rolls(FieldMaps.resolve(PLACE), s):
			return s
	return -1


func _with_path() -> Dictionary:
	var s := _path_seed()
	return SidePath.add(FieldMaps.build(PLACE), s) if s > 0 else {}


func _dead(data: Dictionary) -> Array:
	var out: Array = []
	for key: String in data.get("spawns", {}):
		if key.begins_with("dead_") and key != "dead_levels":
			for c in data["spawns"][key]:
				out.append({"pos": FieldGrid.center(c), "kind": "walker"})
	return out


func test_the_note_is_a_light_paper_that_stays_and_melts_into_nothing() -> void:
	assert_true(FieldItems.has(SideNote.ID))
	assert_eq(FieldItems.item_name(SideNote.ID), "쪽지", "no new name: decision 423 (8) keeps 30~50")
	assert_eq(FieldItems.group(SideNote.ID), "paper")
	assert_eq(FieldItems.stock_of(SideNote.ID)[0], "", "nothing on the train: no reward added")
	assert_true(FieldItems.stays_on_body(SideNote.ID))


func test_about_half_the_side_path_stops_get_one_in_a_pocket_or_a_desk() -> void:
	var base := _with_path()
	assert_false(base.is_empty(), "a run of %s with a side path" % PLACE)
	var where := {"dead": 0, "desk": 0, "": 0}
	for seed in range(1, 201):
		var data := base.duplicate(true)
		var dead := _dead(data)
		var at := SideNote.place(data, dead, seed)
		where[at] += 1
		var found := 0
		for z: Dictionary in dead:
			found += (z.get("carry", []) as Array).count(SideNote.ID)
		for id: String in data["containers"]:
			found += (data["containers"][id].get("items", []) as Array).count(SideNote.ID)
		assert_eq(found, 0 if at == "" else 1, "seed %d: one note or none" % seed)
	assert_between(where[""], 70, 130, "about half (200 runs): %s" % [where])
	assert_gt(where["dead"], 0)


func test_never_on_the_dead_round_the_store_and_none_without_a_path() -> void:
	var data := _with_path()
	var store: Rect2i = data["side_path"]["store"]
	var near := {"pos": FieldGrid.center(store.get_center()), "kind": "walker"}
	for seed in range(1, 60):
		var d := data.duplicate(true)
		for id: String in d["containers"]:
			if SideNote.DESKS.has(String(d["containers"][id].get("furniture", ""))):
				d["containers"][id]["furniture"] = "shelf"
		var body := near.duplicate(true)
		SideNote.place(d, [body], seed)
		assert_false((body.get("carry", []) as Array).has(SideNote.ID), "seed %d" % seed)
	assert_eq(SideNote.place(FieldMaps.build(PLACE), [{"pos": Vector3(5, 0, 5), "kind": "walker"}], 3), "")


func test_the_hint_points_at_the_way_in_while_held_and_not_yet_reached() -> void:
	var data := _with_path()
	var cells: Array = data["side_path"]["entrance"]
	var mid := (FieldGrid.center(cells[0]) + FieldGrid.center(cells[1])) / 2.0
	assert_eq(SideNote.way_in(data), mid)
	assert_eq(SideNote.hint(data, true, false, false), {"at": mid})
	assert_eq(SideNote.hint(data, false, false, false), {}, "not held")
	assert_eq(SideNote.hint(data, true, true, false), {}, "reached")
	assert_eq(SideNote.hint(data, true, false, true), {}, "the store already got into")
	assert_eq(SideNote.way_in(FieldMaps.build(PLACE)), Vector3.INF)


func test_a_field_marks_the_way_in_once_the_note_is_held_and_clears_it_there() -> void:
	var s := _path_seed()
	var game = FieldGame.new()
	game.opts = {"seed": s, "auto_pause": false, "raiders": false, "place": PLACE}
	add_child_autofree(game)
	game.set_process(false)
	assert_true(game.data.has("side_path"))
	game._read_side_note()
	assert_eq(game.side_hint, {}, "nothing before the note is held")
	game.player.add_item(SideNote.ID, 1)
	game._read_side_note()
	assert_eq(game.side_hint.get("at"), SideNote.way_in(game.data))
	game.player.position = SideNote.way_in(game.data)
	game._read_side_note()
	assert_eq(game.side_hint, {}, "reached: the stamp is gone")
	assert_true(game.side_reached)
