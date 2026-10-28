extends "res://addons/gut/test.gd"
const SidePath = preload("res://game/world/side_path.gd")
const Maps = preload("res://game/world/field_maps.gd")
const Grid = preload("res://game/world/field_grid.gd")
const BuildingRules = preload("res://game/sim/building_rules.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const FieldGame = preload("res://game/field_game.gd")
const BuildingView = preload("res://game/world/building_view.gd")
const MapView = preload("res://game/world/map_view.gd")
const RoomFinish = preload("res://game/world/room_finish.gd")
const S = Grid.Solid
const PLACE := "houses_01"


## The first run seed that gives the place a side path.
func _with_path(place: String = PLACE) -> Array:
	for s in range(1, 200):
		if not SidePath.rolls(place, s):
			continue
		var d := SidePath.add(Maps.build(place), s)
		if d.has("side_path"):
			return [s, d]
	return [-1, {}]


## How far the old map moved: a strip on the top or the left shifts it all.
func _shift(side: int) -> Vector2i:
	return Vector2i(SidePath.STRIP, 0) if side == 3 else (Vector2i(0, SidePath.STRIP) if side == 0 else Vector2i.ZERO)


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
	# One of them just inside the gap, the way they came in.
	var by_gap: Vector2i = d["spawns"]["dead_rare_store"][1]
	var touches_gap := false
	for c: Vector2i in spot["gap"]:
		touches_gap = touches_gap or (c - by_gap).length_squared() == 1
	assert_true(touches_gap, "one of the dead stands just inside the gap")
	# A handcart or a sled left at the door, beside it and not in the way.
	var carts: Array = d["props"].filter(func(p: Dictionary) -> bool:
		return SidePath.CART_KINDS.has(String(p["kind"])) and String(p.get("note", "")).begins_with("문 앞에 버려진"))
	assert_eq(carts.size(), 1)
	var cart: Rect2i = carts[0]["rect"]
	assert_false(cart.has_point(spot["door"]), "not on the door")
	assert_true(cart.intersects(spot["store"].grow(1)), "at the store's front")
	for c: Vector2i in spot["entrance"]:
		assert_false(cart.has_point(c), "not in the gap")
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
	_kept_cell_for_cell(a, b)


## The old map is all there, moved only by a strip on the top or the left; the dead's
## ways on the grown edge moved out to the new edge.
func _kept_cell_for_cell(a: Dictionary, b: Dictionary) -> void:
	var ga: Grid = a["grid"]
	var gb: Grid = b["grid"]
	var side: int = b["side_path"]["side"]
	var off := _shift(side)
	assert_eq(gb.width + gb.height, ga.width + ga.height + SidePath.STRIP, "one strip on one edge")
	for y in range(ga.height):
		for x in range(ga.width):
			var c := Vector2i(x, y)
			if ga.solid_at(c) != gb.solid_at(c + off) or ga.floor_at(c) != gb.floor_at(c + off):
				fail_test("old cell %s changed" % c)
				return
	assert_eq(b["containers"].size(), a["containers"].size() + b["side_path"]["boxes"].size())
	for id: String in a["containers"]:
		assert_eq(b["containers"][id]["items"], a["containers"][id]["items"], id)
		assert_eq(b["containers"][id]["cell"], a["containers"][id]["cell"] + off, id)
	assert_eq(b["buildings"].size(), a["buildings"].size() + 1)
	assert_eq(b["train"], MapShift._offset(a["train"], off, "train"))
	for id in a.get("entries", {}):
		for i in range(a["entries"][id].size()):
			var was: Vector2i = a["entries"][id][i]
			var now: Vector2i = b["entries"][id][i]
			if SidePath._v_of(ga, side, was) == 0:
				assert_eq(SidePath._v_of(gb, side, now), 0, id + " on the new edge")
				assert_eq(SidePath._u_of(side, now), SidePath._u_of(side, was + off), id)
				assert_true(gb.people_can_walk(now), "%s comes in on open ground" % id)
			else:
				assert_eq(now, was + off, id)


## With the outer village a town map's right and bottom edges can lie over a minute
## from the train; the path then opens on the top or the left, the old map moved whole.
func test_a_town_map_too_deep_on_the_right_and_bottom_opens_on_the_top_or_left() -> void:
	var found := _with_path("freight_02")
	if found[0] < 0:
		fail_test("no side path on freight_02")
		return
	var d: Dictionary = found[1]
	var spot: Dictionary = d["side_path"]
	assert_true(int(spot["side"]) in [0, 3], "side %d" % spot["side"])
	assert_between(float(spot["seconds"]), SidePath.WALK_SECONDS.x, SidePath.WALK_SECONDS.y)
	var g: Grid = d["grid"]
	var front := _outside_of(g, spot["door"], spot["building"])
	assert_gt(SidePath._walk_from_train(d, g)[g.index(front)], 0, "the store's door is reached on foot")
	_kept_cell_for_cell(Maps.build("freight_02"), d)


## 정차 연출 로더가 미리 지어 넘긴 지도(map_data)에도, 같은 씨앗이면 필드가 지은 지도와 같은 샛길이 붙는다.
func test_a_map_handed_over_built_gets_the_same_way_as_one_built_in_the_field() -> void:
	var found := _with_path()
	var s: int = found[0]
	assert_gt(s, 0)
	var game = FieldGame.new()
	game.opts = {"seed": s, "place": PLACE, "map_data": Maps.build(PLACE), "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	assert_true(game.data.has("side_path"), "the loader's map gets its side path")
	if game.data.has("side_path"):
		assert_eq(game.data["side_path"]["door"], found[1]["side_path"]["door"])


## 정차 연출 로더는 지도와 함께 건물 계획·땅 무늬·방 마감을 미리 지어 넘긴다. 필드가 붙인 샛길은 지도를
## 넓히고 창고를 더하므로(탄광 1은 동쪽으로 넓어짐), 샛길 전 지도로 지은 그것들은 버리고 다시 짓는다.
func test_a_side_path_drops_what_the_loader_made_ahead_from_the_map_as_it_was() -> void:
	var found := _with_path("mine_01")
	var s: int = found[0]
	assert_gt(s, 0)
	var handed := Maps.build("mine_01")
	handed["_building_plan"] = BuildingView.plan(handed)
	handed["_ground_details"] = MapView.ground_details(handed["grid"])
	handed["_room_finish"] = RoomFinish.build(handed)
	var d := FieldGame.with_side_path(handed, s)
	assert_true(d.has("side_path"))
	for key in FieldGame.AHEAD_KEYS:
		assert_false(d.has(key), "%s made from the map before its side path is dropped" % key)
	# No side path rolled: what was made ahead still fits and is kept.
	for other in range(1, 200):
		if SidePath.rolls("mine_01", other):
			continue
		var kept := Maps.build("mine_01")
		kept["_ground_details"] = MapView.ground_details(kept["grid"])
		assert_true(FieldGame.with_side_path(kept, other).has("_ground_details"))
		break
