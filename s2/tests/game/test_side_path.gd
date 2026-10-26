extends "res://addons/gut/test.gd"
const SidePath = preload("res://game/world/side_path.gd")
const Maps = preload("res://game/world/field_maps.gd")
const Grid = preload("res://game/world/field_grid.gd")
const BuildingRules = preload("res://game/sim/building_rules.gd")
const S = Grid.Solid
const PLACE := "houses_01"


## The first run seed that gives PLACE a side path.
func _with_path() -> Array:
	for s in range(1, 200):
		if not SidePath.rolls(PLACE, s):
			continue
		var d := SidePath.add(Maps.build(PLACE), s)
		if d.has("side_path"):
			return [s, d]
	return [-1, {}]


func _outside_of(g: Grid, door: Vector2i, b: int) -> Vector2i:
	var faces := g.faces(door)
	return faces[0] if g.building_at(faces[0]) != b else faces[1]


func test_about_one_stop_in_four_gets_a_side_path() -> void:
	var n := 0
	for s in range(1, 401):
		n += int(SidePath.rolls(PLACE, s))
	assert_between(n, 70, 130)


func test_no_roll_changes_nothing_and_the_first_stop_never_gets_one() -> void:
	var first := Maps.build(Maps.DEFAULT_PLACE)
	for s in range(1, 40):
		assert_same(SidePath.add(first, s), first)
	var s := 1
	while SidePath.rolls(PLACE, s):
		s += 1
	var d := Maps.build(PLACE)
	assert_same(SidePath.add(d, s), d)
	assert_false(d.has("side_path"))


func test_the_rare_store_is_locked_boarded_boxed_and_watched() -> void:
	var found := _with_path()
	assert_gt(found[0], 0, "some seed gives a side path")
	if found[0] < 0:
		return
	var d: Dictionary = found[1]
	var spot: Dictionary = d["side_path"]
	var b: int = spot["building"]
	assert_eq(int(d["buildings"][b]["id"]), b, "the store's id is its index")
	assert_eq(d["buildings"][b]["name"], "희귀 창고")
	assert_eq(d["grid"].doors[spot["door"]]["state"], "locked")
	assert_between(spot["boxes"].size(), 4, 6)
	for id: String in spot["boxes"]:
		var box: Dictionary = d["containers"][id]
		assert_true(String(box["name"]).begins_with("희귀 창고의 "), box["name"])
		assert_eq(int(box["building"]), b)
		assert_gt(box["items"].size(), 0, "never an empty box")
	assert_between(d["spawns"]["dead_rare_store"].size(), 2, 4)
	var boarded := 0
	for c: Vector2i in d["grid"].windows:
		var w: Dictionary = d["grid"].windows[c]
		if int(w.get("building", -1)) == b and BuildingRules.planks_total(w) > 0:
			boarded += 1
	assert_eq(boarded, spot["boarded"])
	assert_gt(boarded, 0)


func test_the_gap_is_the_only_way_in_and_the_walk_is_fair() -> void:
	var found := _with_path()
	if found[0] < 0:
		fail_test("no side path")
		return
	var d: Dictionary = found[1]
	var spot: Dictionary = d["side_path"]
	var g: Grid = d["grid"]
	assert_between(float(spot["seconds"]), SidePath.WALK_SECONDS.x, SidePath.WALK_SECONDS.y)
	var front := _outside_of(g, spot["door"], spot["building"])
	assert_gt(SidePath._walk_from_train(d, g)[g.index(front)], 0, "the store's door is reached on foot")
	for c: Vector2i in spot["gap"]:
		g.set_solid(c, S.BLOCK)
	g.refresh_paths()
	assert_eq(SidePath._walk_from_train(d, g)[g.index(front)], -1, "only through the gap")


func test_same_seed_same_place_and_the_old_map_is_kept_cell_for_cell() -> void:
	var found := _with_path()
	if found[0] < 0:
		fail_test("no side path")
		return
	var b: Dictionary = found[1]
	var a := Maps.build(PLACE)
	var again := SidePath.add(Maps.build(PLACE), found[0])
	assert_eq(again["side_path"]["door"], b["side_path"]["door"])
	assert_eq(again["side_path"]["store"], b["side_path"]["store"])
	var ga: Grid = a["grid"]
	var gb: Grid = b["grid"]
	assert_eq(gb.width + gb.height, ga.width + ga.height + SidePath.STRIP, "one strip on the right or the bottom")
	for y in range(ga.height):
		for x in range(ga.width):
			var c := Vector2i(x, y)
			if ga.solid_at(c) != gb.solid_at(c) or ga.floor_at(c) != gb.floor_at(c):
				fail_test("old cell %s changed" % c)
				return
	assert_eq(b["containers"].size(), a["containers"].size() + b["side_path"]["boxes"].size())
	for id: String in a["containers"]:
		assert_eq(b["containers"][id]["items"], a["containers"][id]["items"], id)
		assert_eq(b["containers"][id]["cell"], a["containers"][id]["cell"], id)
	assert_eq(b["buildings"].size(), a["buildings"].size() + 1)
	assert_eq(b["train"], a["train"])
	# The dead's ways on the grown edge moved out to the new edge; the others stayed.
	var side: int = b["side_path"]["side"]
	for id in a.get("entries", {}):
		for i in range(a["entries"][id].size()):
			var was: Vector2i = a["entries"][id][i]
			var now: Vector2i = b["entries"][id][i]
			if side == 1 and was.x == ga.width - 1 or side == 2 and was.y == ga.height - 1:
				assert_eq(now, Vector2i(gb.width - 1, was.y) if side == 1 else Vector2i(was.x, gb.height - 1), id)
				assert_true(gb.people_can_walk(now), "%s comes in on open ground" % id)
			else:
				assert_eq(now, was, id)
