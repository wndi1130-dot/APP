extends "res://addons/gut/test.gd"

const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const Ring = preload("res://game/world/map_ring.gd")
const LootRules = preload("res://game/sim/loot_rules.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
## One of each edge kind (town, freight, wood, mine, open line); each map is built once for
## the whole file, plain and ringed, as building them is most of this file's time.
const PLACES: Array[String] = ["houses_01", "freight_01", "lodge_01", "mine_01", "bare_line_01"]
static var _built: Dictionary = {}


func after_all() -> void:
	_built.clear()


## The map finished at its own size, without the ring. Read only: tests copy what they change.
func _plain(place: String) -> Dictionary:
	if not _built.has("plain:" + place):
		_built["plain:" + place] = Ring.plain_build(load(FieldMaps.path_of(place)), FieldMaps.build_from)
	return _built["plain:" + place]


## The same map as the field gets it, with the ring. Read only.
func _ringed(place: String) -> Dictionary:
	if not _built.has("ring:" + place):
		_built["ring:" + place] = FieldMaps.build(place)
	return _built["ring:" + place]


func test_grow_moves_every_layer_cell_rect_key_and_preserves_directions() -> void:
	var levels := {}
	for lv in [-1, 0, 1]:
		var g := FieldGrid.new(7, 6)
		g.solid.fill(S.NONE)
		g.floor.fill(F.GRAVEL)
		g.zone.fill("old")
		g.building.fill(7)
		g.set_solid(Vector2i(1, 2), S.DOOR)
		g.doors[Vector2i(1, 2)] = {"cell": Vector2i(1, 2), "state": "closed", "hp": 8, "building": 7}
		g.set_solid(Vector2i(3, 2), S.WINDOW)
		g.windows[Vector2i(3, 2)] = {"cell": Vector2i(3, 2), "broken": false, "glass": false, "building": 7}
		g.floor_glass[Vector2i(3, 3)] = Vector2i(3, 2)
		g.refresh_paths()
		levels[lv] = g
	var c := Vector2i(2, 3)
	var r := Rect2i(1, 1, 3, 2)
	var d := {"grid": levels[0], "levels": levels, "train": r, "platform": r,
		"unload": r, "buildings": [{"id": 7, "rect": r}], "spawns": {"squad": [c]},
		"entries": {"road": [c]}, "train_doors": {"upper": [c]}, "stairs": [{"cell": c, "low": -1, "high": 0}],
		"props": [{"rect": r, "facing": Vector2i.LEFT}], "lights": [{"cell": c, "side": Vector2i.UP}],
		"containers": {"same_id": {"cell": c, "items": ["plank"], "locked": true}},
		"trees": [c], "positions": [Vector3(2.5, 3, 3.5)], "hole_faces": {"hole": Vector2i.DOWN},
		"cell_keys": {c: {"cell": c, "rect": r}}, "place_id": "same", "place_kind": "houses"}
	var offset := Vector2i(3, 4)
	var grown := MapShift.grow(d, 3, 4, 5, 2)
	assert_eq(grown["grid"].width, 15)
	assert_eq(grown["grid"].height, 12)
	assert_same(grown["grid"], grown["levels"][0])
	var expected: Dictionary = MapShift._offset(d, offset, "")
	for key in expected:
		assert_eq(grown[key], expected[key], key)
	assert_eq(grown["hole_faces"], d["hole_faces"])
	assert_eq(grown["lights"][0]["side"], Vector2i.UP)
	assert_eq(grown["props"][0]["facing"], Vector2i.LEFT)
	assert_eq(grown["cell_keys"][c + offset]["cell"], c + offset)
	assert_eq(grown["positions"][0], Vector3(5.5, 3, 7.5))
	for lv in levels:
		assert_true(_same_cells(levels[lv], grown["levels"][lv], offset), "layer %s" % lv)
		var g: FieldGrid = grown["levels"][lv]
		assert_eq(g.floor_glass[Vector2i(6, 7)], Vector2i(6, 6))
		assert_eq(g.doors[Vector2i(4, 6)]["cell"], Vector2i(4, 6))
		assert_eq(g.windows[Vector2i(6, 6)]["cell"], Vector2i(6, 6))
		for sample in [Vector2i(0, 0), Vector2i(14, 11), Vector2i(2, 8), Vector2i(11, 3)]:
			assert_eq(g.solid_at(sample), S.AIR if lv > 0 else (S.BLOCK if lv < 0 else S.NONE))
			assert_eq(g.floor_at(sample), F.SNOW)
	assert_same(MapShift.grow(d, 0, 0, 0, 0), d)
	assert_eq(d["containers"]["same_id"]["cell"], c, "input untouched")
	for minimal in [{"grid": levels[0]}, {"grid": levels[0], "levels": {}}]:
		var fallback := MapShift.grow(minimal, 1, 0, 2, 0)
		assert_eq(fallback["grid"].width, 10)
		assert_same(fallback["grid"], fallback["levels"][0])


func test_widths_and_first_stop_and_test_fixtures_are_unchanged() -> void:
	for kind in Ring.TOWN:
		assert_eq(Ring.width_for(kind), 30, kind)
	for kind in Ring.WILD:
		assert_eq(Ring.width_for(kind), 20, kind)
	var script: Script = load(FieldMaps.path_of(FieldMaps.DEFAULT_PLACE))
	assert_false(Ring.enabled(script))
	var a: Dictionary = Ring.plain_build(script, FieldMaps.build_from)
	var b: Dictionary = FieldMaps.build_from(script)
	assert_eq(b["grid"].width, a["grid"].width)
	assert_true(_same_cells(a["grid"], b["grid"], Vector2i.ZERO))
	assert_eq(b["containers"], a["containers"])
	assert_eq(b["train"], a["train"])
	assert_false(b.has("map_ring"))
	assert_false(Ring.enabled(load("res://tests/game/fixtures/tiny_map.gd")))


func test_finished_old_interior_and_loot_are_only_translated() -> void:
	for place in ["houses_01", "lodge_01", "mine_01", "freight_01"]:
		var before := _plain(place)
		var after := _ringed(place)
		var width: int = after["map_ring"]["width"]
		var offset := Vector2i.ONE * width
		for lv in before["levels"]:
			assert_true(_same_cells(before["levels"][lv], after["levels"][lv], offset), "%s level %d" % [place, lv])
		for key in ["train", "platform", "unload", "spawns", "stairs", "train_doors", "boarding", "unloading", "place_id", "place_kind"]:
			if before.has(key):
				assert_eq(after[key], MapShift._offset(before[key], offset, key), place + ": " + key)
		var before_boxes: Dictionary = before["containers"].duplicate(true)
		var after_boxes: Dictionary = after["containers"].duplicate(true)
		LootRules.fill(before_boxes, 7)
		LootRules.fill(after_boxes, 7)
		for id in before_boxes:
			assert_eq(after_boxes[id], MapShift._offset(before_boxes[id], offset, ""), place + ": " + id)
		for i in range(before["buildings"].size()):
			assert_eq(after["buildings"][i], MapShift._offset(before["buildings"][i], offset, ""))
		for i in range(before.get("props", []).size()):
			assert_eq(after["props"][i], MapShift._offset(before["props"][i], offset, ""))


func test_road_and_rail_reach_every_new_edge_and_all_new_boxes_are_reachable() -> void:
	for place in PLACES:
		var original := _plain(place)
		var after := _ringed(place)
		var old: FieldGrid = original["grid"]
		var g: FieldGrid = after["grid"]
		var meta: Dictionary = after["map_ring"]
		var width: int = meta["width"]
		assert_eq(g.width, old.width + width * 2)
		assert_eq(g.height, old.height + width * 2)
		assert_between(meta["buildings"], 4 if width == 30 else 1, 8 if width == 30 else 3, place)
		assert_eq(meta["buildings"], meta["target"], place + ": no dropped lots")
		assert_eq(meta["rooms"]["rooms"], meta["buildings"], place + ": every new room furnished")
		var lanes_ok := true
		for y in range(old.height):
			for pair in [[Vector2i(0, y), Vector2i(0, y + width), Vector2i.RIGHT], [Vector2i(old.width - 1, y), Vector2i(g.width - 1, y + width), Vector2i.LEFT]]:
				lanes_ok = lanes_ok and _lane_ok(old, g, pair, width)
		for x in range(old.width):
			for pair in [[Vector2i(x, 0), Vector2i(x + width, 0), Vector2i.DOWN], [Vector2i(x, old.height - 1), Vector2i(x + width, g.height - 1), Vector2i.UP]]:
				lanes_ok = lanes_ok and _lane_ok(old, g, pair, width)
		assert_true(lanes_ok, place + ": continuous lanes")
		var seen := reachable(g, after["spawns"]["squad"][0])
		for id in meta["containers"]:
			assert_true(touches(after["containers"][id]["cell"], seen), place + ": " + id)
		for i in range(original["buildings"].size(), after["buildings"].size()):
			var r: Rect2i = after["buildings"][i]["rect"]
			assert_false(r.intersects(meta["inner"]))
			for j in range(i):
				assert_false(r.intersects(after["buildings"][j]["rect"]), place + ": no overlapping buildings")


func test_same_place_has_same_ring_and_rooms() -> void:
	var a := _ringed("houses_01")
	var b := FieldMaps.build("houses_01")
	for key in ["map_ring", "containers", "buildings", "props", "trees", "low_blocks"]:
		assert_eq(a[key], b[key], key)
	assert_true(_same_cells(a["grid"], b["grid"], Vector2i.ZERO))
	assert_gt(a["map_ring"]["rooms"]["placed"], 0, "new rooms use existing furniture rules")


func test_ring_trees_and_yard_fences_are_drawn_as_models() -> void:
	for place in ["houses_01", "lodge_01"]:
		var original := _plain(place)
		var after := _ringed(place)
		var g: FieldGrid = after["grid"]
		var modelled := {}
		for p in after["props"].slice(original.get("props", []).size()):
			if p["kind"] == "plank_fence":
				var long_side: int = maxi(p["rect"].size.x, p["rect"].size.y)
				assert_true(long_side <= Ring.FENCE_PIECE, "%s fence piece %s" % [place, p["rect"]])
				assert_eq(int(p["facing"]) % 2, 1 if p["rect"].size.y > 1 else 0, "%s fence runs along %s" % [place, p["rect"]])
			if p["kind"] in ["bare_tree", "plank_fence"]:
				for y in range(p["rect"].position.y, p["rect"].end.y):
					for x in range(p["rect"].position.x, p["rect"].end.x):
						modelled[Vector2i(x, y)] = p["kind"]
		var ring_trees: Array = after["trees"].slice(original["trees"].size())
		assert_gt(ring_trees.size(), 0, place)
		for c in ring_trees:
			assert_eq(modelled.get(c), "bare_tree", "%s tree %s" % [place, c])
		var fences := 0
		for r: Rect2i in after["low_blocks"].slice(original["low_blocks"].size()):
			if g.building_at(r.position) < 0:
				fences += 1
				assert_eq(modelled.get(r.position), "plank_fence", "%s fence %s" % [place, r.position])
		assert_gt(fences, 0, place)


func test_dead_still_come_in_from_the_new_edge() -> void:
	for place in ["houses_01", "lodge_01", "mine_01", "freight_01"]:
		var before := _plain(place)
		var after := _ringed(place)
		var g: FieldGrid = after["grid"]
		var old: FieldGrid = before["grid"]
		var offset := Vector2i.ONE * int(after["map_ring"]["width"])
		var moved := 0
		var areas: Array[Dictionary] = []
		for id in before["entries"]:
			assert_eq(after["entries"][id].size(), before["entries"][id].size(), place + ": " + id)
			for i in range(before["entries"][id].size()):
				var c: Vector2i = before["entries"][id][i]
				var now: Vector2i = after["entries"][id][i]
				var border := c.x == 0 or c.y == 0 or c.x == old.width - 1 or c.y == old.height - 1
				if not border or before.get("manholes", {}).has(id) or int(before.get("entry_levels", {}).get(id, 0)) != 0:
					assert_eq(now, c + offset, place + ": " + id)
					continue
				moved += 1
				assert_true(now.x == 0 or now.y == 0 or now.x == g.width - 1 or now.y == g.height - 1, "%s %s on the new edge" % [place, id])
				assert_true(g.dead_can_walk(now), "%s %s open at %s" % [place, id, now])
				var area: Dictionary = {}
				for seen: Dictionary in areas:
					if seen.has(now):
						area = seen
				if area.is_empty():
					area = dead_reach(g, now)
					areas.append(area)
				assert_true(area.has(c + offset), "%s %s reaches the old way in" % [place, id])
		assert_gt(moved, 0, place)
		for key in before.get("anchors", {}):
			if key != "flee_exit":
				assert_eq(after["anchors"][key], MapShift._offset(before["anchors"][key], offset, key), place + ": " + key)
		if after.get("anchors", {}).get("flee_exit") is Vector2i:
			var flee: Vector2i = after["anchors"]["flee_exit"]
			assert_true(g.people_can_walk(flee), place + ": flee exit open")


func _lane_ok(old: FieldGrid, g: FieldGrid, pair: Array, width: int) -> bool:
	var f := old.floor_at(pair[0])
	if f != F.RAIL and not (f == F.ROAD and old.people_can_walk(pair[0])):
		return true
	for n in range(width):
		var c: Vector2i = pair[1] + pair[2] * n
		if g.floor_at(c) != f or not g.people_can_walk(c):
			return false
	return true


static func reachable(g: FieldGrid, start: Vector2i) -> Dictionary:
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var index := 0
	while index < queue.size():
		var c := queue[index]
		index += 1
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if not seen.has(n) and g.people_can_walk(n):
				seen[n] = true
				queue.append(n)
	return seen


static func dead_reach(g: FieldGrid, start: Vector2i) -> Dictionary:
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var index := 0
	while index < queue.size():
		var c := queue[index]
		index += 1
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if not seen.has(n) and g.dead_can_walk(n):
				seen[n] = true
				queue.append(n)
	return seen


static func touches(c: Vector2i, seen: Dictionary) -> bool:
	for d in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if seen.has(c + d):
			return true
	return false


static func _same_cells(a: FieldGrid, b: FieldGrid, offset: Vector2i) -> bool:
	for y in range(a.height):
		for x in range(a.width):
			var i := a.index(Vector2i(x, y))
			var j := b.index(Vector2i(x, y) + offset)
			if a.solid[i] != b.solid[j] or a.floor[i] != b.floor[j] or a.building[i] != b.building[j] or a.zone[i] != b.zone[j] or a.opq[i] != b.opq[j] or a.walk_people[i] != b.walk_people[j] or a.walk_dead[i] != b.walk_dead[j]:
				return false
	for key in ["doors", "windows", "floor_glass"]:
		var translated: Dictionary = MapShift._offset(a.get(key), offset, "")
		for c in translated:
			if b.get(key).get(c) != translated[c]:
				return false
	return true
