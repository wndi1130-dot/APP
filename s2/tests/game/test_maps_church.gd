extends "res://addons/gut/test.gd"

const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const MAPS: Array = [
	preload("res://game/world/maps/church_01.gd"),
	preload("res://game/world/maps/church_02.gd"),
	preload("res://game/world/maps/church_03.gd"),
	preload("res://game/world/maps/church_04.gd"),
	preload("res://game/world/maps/church_05.gd"),
	preload("res://game/world/maps/church_06.gd"),
]
const KEYS: Array[String] = [
	"grid", "levels", "stairs", "containers", "spots", "stoves", "entries",
	"entry_gap", "entry_levels", "buildings", "wagons", "train", "platform",
	"unload", "train_cars", "spawns", "labels", "trees", "low_blocks",
	"upper_rects", "lights", "manholes", "manhole_levels", "sewer_names",
	"anchors", "zone_names", "place_id", "place_kind", "bands", "train_doors",
	"crossings", "barricade_slots", "interior_kind_slots", "props", "hole_faces", "entry_names", "entry_weights", "first_entry",
]
const KINDS: Array[String] = [
	"car", "handcart", "firewood_pile", "barrel", "crate_stack", "sack_pile",
	"bench", "shelf", "bed", "desk", "cold_stove", "lamp_post", "display_shelf",
	"shop_counter", "checkout", "shopping_cart", "pallet_stack", "market_stall",
	"shop_awning", "freezer_chest", "bread_rack", "blank_sign", "floor_shell",
	"stair_stub", "water", "hand_bell", "bell_rope", "bell_frame", "pew_row",
	"altar_table", "candle_stand", "pulpit", "hymn_shelf", "community_banner",
	"vestry_chest", "parish_chest", "relief_crate", "nave_pillar", "cloister_post",
	"frozen_fountain", "grave_slab", "grave_plot", "field_marker", "fieldstone_wall",
	"yard_gate", "fallen_bell", "roof_beam_pile", "roof_tile_heap", "rubble_heap",
	"repair_scaffold", "repair_lumber", "windbreak_fence", "reed_bundle",
	"frozen_reeds", "lamp_shelf", "blanket_screen", "cooking_pot", "plank_patch",
	"slate_board", "bookcase", "long_table", "cask_stack", "herb_rack", "herb_bed",
	"coal_bin", "dough_table", "farm_cart", "snow_drift", "bare_tree",
	"plank_fence", "hedge", "millstone", "coal_heap", "coal_wagon", "anvil_block", "loom", "hive_box",
]
const ITEMS: Array[String] = [
	"symbol_bell", "cloth", "document", "luxury_pack", "info_telegraph",
	"info_timetable", "medkit", "tweezers", "needle_thread", "food_pack",
	"bottle_spirit", "ammo_pistol", "flare", "plank", "med_box", "bandage",
	"ammo_shell", "scrap",
]
const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var maps: Array[Dictionary] = []


func before_all() -> void:
	for script in MAPS:
		maps.append(script.build())


func _cells(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2i(x, y))
	return out


func _distances(g: FieldGrid, starts: Array, dead: bool = false, blocked: Dictionary = {}) -> PackedInt32Array:
	var distances := PackedInt32Array()
	distances.resize(g.width * g.height)
	distances.fill(-1)
	var queue: Array[Vector2i] = []
	for c: Vector2i in starts:
		if not g.inside(c) or blocked.has(c):
			continue
		if not (g.dead_can_walk(c) if dead else g.people_can_walk(c)):
			continue
		distances[g.index(c)] = 0
		queue.append(c)
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for step: Vector2i in DIRS:
			var next: Vector2i = c + step
			if not g.inside(next) or blocked.has(next) or distances[g.index(next)] >= 0:
				continue
			if (g.dead_can_walk(next) if dead else g.people_can_walk(next)):
				distances[g.index(next)] = distances[g.index(c)] + 1
				queue.append(next)
	return distances


func _all_distances(d: Dictionary, side: String = "lower") -> PackedInt32Array:
	var g: FieldGrid = d["grid"]
	var count: int = g.width * g.height
	var distances := PackedInt32Array()
	distances.resize(count * 4)
	distances.fill(-1)
	var edges: Dictionary = {}
	for s: Dictionary in d["stairs"]:
		var a: int = (int(s["low"]) + 1) * count + g.index(s["cell"])
		var b: int = (int(s["high"]) + 1) * count + g.index(s["cell"])
		if not edges.has(a):
			edges[a] = []
		if not edges.has(b):
			edges[b] = []
		edges[a].append(b)
		edges[b].append(a)
	var queue: Array[int] = []
	for c: Vector2i in d["train_doors"][side]:
		var at: int = count + g.index(c)
		distances[at] = 0
		queue.append(at)
	var head: int = 0
	while head < queue.size():
		var current: int = queue[head]
		head += 1
		var level: int = floori(float(current) / float(count)) - 1
		var index: int = current % count
		var c := Vector2i(index % g.width, floori(float(index) / float(g.width)))
		var lg: FieldGrid = d["levels"][level]
		var neighbors: Array[int] = []
		for step: Vector2i in DIRS:
			var next: Vector2i = c + step
			if lg.inside(next) and lg.people_can_walk(next):
				neighbors.append((level + 1) * count + lg.index(next))
		for next: int in edges.get(current, []):
			neighbors.append(next)
		for next: int in neighbors:
			if distances[next] < 0:
				distances[next] = distances[current] + 1
				queue.append(next)
	return distances


func _mask(g: FieldGrid, rectangles: Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(g.width * g.height)
	for r: Rect2i in rectangles:
		for c: Vector2i in _cells(r):
			if g.inside(c):
				out[g.index(c)] = 1
	return out


func _korean_name(value: String) -> bool:
	for i in range(value.length()):
		var code: int = value.unicode_at(i)
		if (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or (code >= 0x3400 and code <= 0x9fff):
			return false
	return not value.is_empty()


func _door_normal(g: FieldGrid, c: Vector2i, buildings: Array) -> Vector2i:
	var id: int = g.doors[c]["building"]
	var r: Rect2i = buildings[id]["rect"]
	if c.x == r.position.x or c.x == r.end.x - 1:
		return Vector2i.RIGHT
	if c.y == r.position.y or c.y == r.end.y - 1:
		return Vector2i.DOWN
	if [S.WALL, S.WINDOW].has(g.solid_at(c + Vector2i.LEFT)) or [S.WALL, S.WINDOW].has(g.solid_at(c + Vector2i.RIGHT)):
		return Vector2i.DOWN
	return Vector2i.RIGHT


func test_exact_contract_sizes_zones_and_identity() -> void:
	for i in range(maps.size()):
		var d: Dictionary = maps[i]
		var g: FieldGrid = d["grid"]
		var actual: Array = d.keys()
		var expected: Array = KEYS.duplicate()
		actual.sort()
		expected.sort()
		assert_eq(actual, expected, d["place_id"])
		assert_eq(d["place_id"], "church_%02d" % (i + 1))
		assert_eq(d["place_kind"], "church")
		assert_between(g.width, 150, 180)
		assert_between(g.height, 135, 155)
		assert_between(d["zone_names"].size(), 8, 12)
		var used: Dictionary = {}
		for z: String in g.zone:
			used[z] = true
		assert_eq(used.size(), d["zone_names"].size())
		for z: String in used:
			assert_true(d["zone_names"].has(z))
			assert_true(_korean_name(d["zone_names"].get(z, "")))


func test_train_bands_doors_clear_strips_and_crossings() -> void:
	for d: Dictionary in maps:
		var g: FieldGrid = d["grid"]
		var train: Rect2i = d["train"]
		var bounds := Rect2i(0, 0, g.width, g.height)
		assert_eq(train, Rect2i(16, 46, 80, 3))
		assert_eq(d["platform"], Rect2i(16, 49, 82, 6))
		assert_eq(d["unload"], Rect2i(16, 49, 82, 3))
		assert_eq(d["bands"].size(), 2)
		assert_eq(d["train_doors"].size(), 2)
		assert_eq(d["bands"]["lower"], Rect2i(-4, 49, 120, 26).intersection(bounds))
		assert_eq(d["bands"]["upper"], Rect2i(-4, 24, 120, 22).intersection(bounds))
		assert_false(d["bands"]["upper"].intersects(d["bands"]["lower"]))
		assert_eq(d["train_doors"]["lower"], d["spawns"]["train_door"])
		var door_x: Dictionary = {}
		for side: String in ["upper", "lower"]:
			assert_true(bounds.encloses(d["bands"][side]))
			assert_gte(d["train_doors"][side].size(), 3)
			var xs: Array[int] = []
			for c: Vector2i in d["train_doors"][side]:
				assert_eq(c.y, 45 if side == "upper" else 49)
				assert_between(c.x, train.position.x + 2, train.end.x - 3)
				assert_true(g.people_can_walk(c))
				assert_true(d["barricade_slots"].has(c + Vector2i(0, -1 if side == "upper" else 1)))
				xs.append(c.x)
			xs.sort()
			door_x[side] = xs
		assert_eq(door_x["upper"], door_x["lower"])
		for r: Rect2i in [Rect2i(16, 43, 80, 3), Rect2i(16, 49, 80, 3)]:
			for c: Vector2i in _cells(r):
				assert_eq(g.solid_at(c), S.NONE)
			for p: Dictionary in d["props"]:
				if int(p.get("level", 0)) == 0:
					assert_false(r.intersects(p["rect"]))
		var ends: Array[int] = [0, 0]
		for y in range(46, 49):
			for x in range(g.width):
				var c := Vector2i(x, y)
				assert_eq(g.floor_at(c), F.RAIL)
				if x < train.position.x and g.dead_can_walk(c):
					ends[0] += 1
				if x >= train.end.x and g.dead_can_walk(c):
					ends[1] += 1
		assert_gte(ends[0], 4)
		assert_gte(ends[1], 4)
		assert_eq(d["crossings"].size(), 2)
		var crossing_x: Dictionary = {}
		for crossing: Dictionary in d["crossings"]:
			var cc: Array = crossing["cells"]
			assert_eq(cc.size(), 3)
			var x: int = cc[0].x
			assert_true([32, 48, 64].has(x))
			assert_false(door_x["upper"].has(x))
			assert_false(crossing_x.has(x))
			crossing_x[x] = true
			assert_eq(cc, [Vector2i(x, 46), Vector2i(x, 47), Vector2i(x, 48)])
			for c: Vector2i in cc:
				assert_eq(g.solid_at(c), S.BLOCK)
				assert_false(g.people_can_walk(c))
				assert_false(g.dead_can_walk(c))
			assert_true(g.people_can_walk(Vector2i(x, 45)))
			assert_true(g.people_can_walk(Vector2i(x, 49)))
			assert_eq(crossing["who"], {"person": true, "zombie": false, "carrying": true, "wounded": false, "sled": false})
		assert_eq(d["train_cars"].size(), 5)
		assert_eq(d["train_cars"][4]["kind"], "engine")
		assert_eq(d["train_cars"][4]["rect"].end.x, train.end.x)
		for c: Vector2i in d["spawns"]["squad"]:
			assert_true(d["bands"]["lower"].has_point(c))
			assert_true(g.people_can_walk(c))

func test_edge_entries_and_initial_dead_reach_the_correct_side() -> void:
	for d: Dictionary in maps:
		var g: FieldGrid = d["grid"]
		var paths := {"upper": _distances(g, d["train_doors"]["upper"], true), "lower": _distances(g, d["train_doors"]["lower"], true)}
		var edges := {"upper": 0, "lower": 0}
		for key: String in d["entries"]:
			assert_true(d["entry_gap"].has(key))
			assert_gt(float(d["entry_gap"].get(key, 0.0)), 0.0)
			assert_lte(float(d["entry_gap"].get(key, 0.0)), 3.0)
			var cc: Array = d["entries"][key]
			var side: String = "upper" if cc[0].y < 46 else "lower"
			if not d["manholes"].has(key):
				edges[side] += 1
				assert_between(cc.size(), 2, 4)
			for c: Vector2i in cc:
				assert_true(g.inside(c))
				for band: Rect2i in d["bands"].values():
					assert_false(band.has_point(c))
				if not d["manholes"].has(key):
					assert_true(c.x == 0 or c.y == 0 or c.x == g.width - 1 or c.y == g.height - 1)
					assert_eq(c.y < 46, side == "upper")
				if int(d["entry_levels"].get(key, 0)) == 0:
					assert_gte(paths[side][g.index(c)], 0, key)
		assert_between(edges["upper"], 2, 3)
		assert_between(edges["lower"], 3, 5)
		var initially_dead: int = 0
		for key: String in d["spawns"]:
			if not key.begins_with("dead_"):
				continue
			for value in d["spawns"][key]:
				var c: Vector2i = value[0] if key == "dead_levels" else value
				for band: Rect2i in d["bands"].values():
					assert_false(band.has_point(c))
				initially_dead += 1
		assert_lte(initially_dead, 60)

func test_sewer_contract_and_walkability() -> void:
	for d: Dictionary in maps:
		var g: FieldGrid = d["grid"]
		var distances: PackedInt32Array = _distances(g, d["train_doors"]["lower"], true)
		assert_lte(d["manholes"].size(), 4)
		for key: String in d["manholes"]:
			var c: Vector2i = d["manholes"][key]
			assert_true(d["entries"].has(key))
			assert_true(d["entry_gap"].has(key))
			assert_true(d["sewer_names"].has(key))
			assert_true(_korean_name(d["sewer_names"][key]))
			assert_true(d["entries"][key].has(c))
			if d["manhole_levels"].has(key):
				assert_eq(d["manhole_levels"][key], -1)
				assert_eq(d["entry_levels"].get(key, 0), -1)
				var lower: FieldGrid = d["levels"][-1]
				var from_hole: PackedInt32Array = _distances(lower, [c], true)
				var stair_reached: bool = false
				for stair: Dictionary in d["stairs"]:
					if int(stair["low"]) == -1 and from_hole[lower.index(stair["cell"])] >= 0:
						stair_reached = true
				assert_true(stair_reached)
			else:
				for train_door: Vector2i in d["train_doors"]["lower"] + d["train_doors"]["upper"]:
					assert_gt(absi(c.x - train_door.x) + absi(c.y - train_door.y), 25)
				assert_gte(distances[g.index(c)], 0)
			if key.begins_with("manhole_"):
				assert_eq(float(d["entry_gap"][key]), 3.0)
			if key.begins_with("culvert_"):
				assert_true(d["hole_faces"].has(key))
				assert_true(DIRS.has(d["hole_faces"].get(key, Vector2i.ZERO)))
		for key: String in d["hole_faces"]:
			assert_true(key.begins_with("culvert_"))
			assert_true(d["manholes"].has(key))


func test_ground_and_both_open_flanks_remain_connected() -> void:
	for i in range(maps.size()):
		var d: Dictionary = maps[i]
		var g: FieldGrid = d["grid"]
		var distances: PackedInt32Array = _distances(g, d["train_doors"]["lower"])
		var missed: int = 0
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				if g.people_can_walk(c) and distances[g.index(c)] < 0:
					missed += 1
		assert_eq(missed, 0, d["place_id"])
		var blocked: Dictionary = {}
		for c: Vector2i in d["barricade_slots"]:
			assert_true(g.people_can_walk(c))
			blocked[c] = true
		for side: String in ["upper", "lower"]:
			var after: PackedInt32Array = _distances(g, d["train_doors"][side], false, blocked)
			var zones: Dictionary = {}
			for at in range(after.size()):
				var c := Vector2i(at % g.width, floori(float(at) / float(g.width)))
				if after[at] >= 0 and not d["bands"]["upper"].has_point(c) and not d["bands"]["lower"].has_point(c):
					zones[g.zone[at]] = true
			var wanted: Dictionary = MAPS[i].NORTH["names"] if side == "upper" else MAPS[i].PLAN["names"]
			for z: String in wanted:
				assert_true(zones.has(z), d["place_id"] + " " + z)

func test_visible_solids_water_cover_and_no_long_low_runs() -> void:
	for d: Dictionary in maps:
		var g: FieldGrid = d["grid"]
		var water_rects: Array = []
		for p: Dictionary in d["props"]:
			if p["kind"] == "water":
				water_rects.append(p["rect"])
				assert_false(d["low_blocks"].has(p["rect"]))
				for c: Vector2i in _cells(p["rect"]):
					assert_eq(g.solid_at(c), S.LOW)
					assert_eq(g.floor_at(c), F.ICE)
		var water: PackedByteArray = _mask(g, water_rects)
		var low_rects: Array = d["low_blocks"].duplicate()
		for stove: Dictionary in d["stoves"]:
			if int(stove.get("level", 0)) == 0:
				low_rects.append(Rect2i(stove["cell"], Vector2i.ONE))
		var visible_low: PackedByteArray = _mask(g, low_rects)
		var block_rects: Array = [d["train"]]
		for wagon: Dictionary in d["wagons"]:
			block_rects.append(wagon["rect"])
		for tree: Vector2i in d["trees"]:
			block_rects.append(Rect2i(tree, Vector2i.ONE))
		var visible_block: PackedByteArray = _mask(g, block_rects)
		var invisible: int = 0
		var max_run: int = 0
		for y in range(g.height):
			var run: int = 0
			for x in range(g.width):
				var c := Vector2i(x, y)
				var i: int = g.index(c)
				if g.solid[i] == S.LOW and water[i] == 0:
					run += 1
					if visible_low[i] == 0:
						invisible += 1
				else:
					run = 0
				max_run = maxi(max_run, run)
				if g.solid[i] == S.BLOCK and g.building[i] < 0 and visible_block[i] == 0:
					invisible += 1
				if x < 14 and y < 14:
					assert_ne(g.solid[i], S.BLOCK)
		for x in range(g.width):
			var run: int = 0
			for y in range(g.height):
				var i: int = y * g.width + x
				run = run + 1 if g.solid[i] == S.LOW and water[i] == 0 else 0
				max_run = maxi(max_run, run)
		assert_eq(invisible, 0)
		assert_lte(max_run, 10)
		for side: String in ["upper", "lower"]:
			var covers: int = 0
			var near: int = 0
			var shapes: Dictionary = {}
			for r: Rect2i in d["low_blocks"]:
				if not r.intersects(d["bands"][side]):
					continue
				covers += 1
				shapes[r.size] = true
				assert_between(maxi(r.size.x, r.size.y), 2, 6)
				var closest: int = 9999
				for c: Vector2i in d["train_doors"][side]:
					var at := Vector2i(clampi(c.x, r.position.x, r.end.x - 1), clampi(c.y, r.position.y, r.end.y - 1))
					closest = mini(closest, absi(c.x - at.x) + absi(c.y - at.y))
				if closest <= 12:
					near += 1
			assert_between(covers, 3, 5)
			assert_gte(near, 2)
			assert_gte(shapes.size(), 2)

		var north_trees: int = 0
		for c: Vector2i in d["trees"]:
			if c.y < 46:
				north_trees += 1
		assert_between(north_trees, 12, 30)
		assert_between(d["trees"].size() - north_trees, 25, 60)

func test_buildings_have_doors_rooms_windows_and_a_large_main_building() -> void:
	for d: Dictionary in maps:
		var g: FieldGrid = d["grid"]
		assert_between(d["buildings"].size(), 20, 31)
		var north_count: int = 0
		for b: Dictionary in d["buildings"]:
			if b["rect"].position.y < 46:
				north_count += 1
				assert_false(b["rect"].intersects(d["bands"]["upper"]))
		assert_between(north_count, 6, 9)
		assert_between(d["buildings"].size() - north_count, 14, 22)
		var enterable: int = 0
		var largest: int = 0
		for i in range(d["buildings"].size()):
			var b: Dictionary = d["buildings"][i]
			var r: Rect2i = b["rect"]
			assert_eq(b["id"], i)
			assert_true(_korean_name(b["name"]))
			var has_door: bool = false
			for c: Vector2i in g.doors:
				if int(g.doors[c]["building"]) == i and (c.x == r.position.x or c.x == r.end.x - 1 or c.y == r.position.y or c.y == r.end.y - 1):
					has_door = true
			if has_door:
				enterable += 1
			var area: int = (r.size.x - 2) * (r.size.y - 2)
			largest = maxi(largest, area)
			var inner_walls: int = 0
			for c: Vector2i in _cells(r.grow(-1)):
				if g.solid_at(c) == S.WALL:
					inner_walls += 1
			if area > 60:
				assert_gt(inner_walls, 0, b["name"])
			var window_count: int = 0
			for c: Vector2i in g.windows:
				if int(g.windows[c]["building"]) == i:
					window_count += 1
			assert_gt(window_count, 0)
		assert_gte(enterable * 10, d["buildings"].size() * 7)
		assert_gte(largest, 600)


func test_deep_and_shallow_loot_on_both_sides_and_adjacent_level_stairs() -> void:
	for i in range(maps.size()):
		var d: Dictionary = maps[i]
		var g: FieldGrid = d["grid"]
		var n: int = g.width * g.height
		var all: PackedInt32Array = _all_distances(d)
		assert_eq(d["interior_kind_slots"].size(), 3)
		var slot_zones: Dictionary = {}
		var north_slots: int = 0
		for slot: Dictionary in d["interior_kind_slots"]:
			assert_false(slot_zones.has(slot["zone"]))
			slot_zones[slot["zone"]] = true
			assert_true(d["zone_names"].has(slot["zone"]))
			assert_eq(slot["kinds"], ["empty", "raiders", "nest", "beasts"])
			if MAPS[i].NORTH["names"].has(slot["zone"]):
				north_slots += 1
		assert_eq(north_slots, 1)
		for side: String in ["upper", "lower"]:
			var distances: PackedInt32Array = _all_distances(d, side)
			var deepest: int = 0
			var nearest: int = 9999
			var valuable: int = 0
			for box: Dictionary in d["containers"].values():
				if (box["cell"].y < 46) != (side == "upper"):
					continue
				var at: int = (int(box.get("level", 0)) + 1) * n + g.index(box["cell"])
				assert_gte(distances[at], 0, box["name"])
				deepest = maxi(deepest, distances[at])
				nearest = mini(nearest, distances[at])
				if not box["items"].is_empty():
					valuable = maxi(valuable, distances[at])
				assert_true(_korean_name(box["name"]))
				for item: String in box["items"]:
					assert_true(ITEMS.has(item), item)
			assert_gte(deepest, 45 if side == "upper" else 80)
			assert_gte(valuable, 45 if side == "upper" else 80)
			assert_lte(nearest, 25 if side == "upper" else 40)
		for level in [-1, 0, 1, 2]:
			assert_true(d["levels"].has(level))
			var lg: FieldGrid = d["levels"][level]
			assert_eq(lg.width, g.width)
			assert_eq(lg.height, g.height)
			var floors: int = 0
			var disconnected: int = 0
			for y in range(lg.height):
				for x in range(lg.width):
					var c := Vector2i(x, y)
					if lg.people_can_walk(c):
						floors += 1
						if level != 0:
							assert_gte(lg.building_at(c), 0)
						if all[(level + 1) * n + lg.index(c)] < 0:
							disconnected += 1
			assert_gt(floors, 0)
			assert_eq(disconnected, 0)
		for stair: Dictionary in d["stairs"]:
			assert_eq(stair["high"], stair["low"] + 1)
			assert_true(d["levels"][stair["low"]].people_can_walk(stair["cell"]))
			assert_true(d["levels"][stair["high"]].people_can_walk(stair["cell"]))

func test_asymmetry_distinct_grids_and_first_line() -> void:
	var comments: Dictionary = {}
	for i in range(maps.size()):
		var d: Dictionary = maps[i]
		var g: FieldGrid = d["grid"]
		var solids: int = 0
		var matches: int = 0
		for y in range(g.height):
			for x in range(g.width):
				var at: int = y * g.width + x
				if g.solid[at] == S.NONE or g.solid[at] == S.AIR:
					continue
				solids += 1
				if g.solid[at] == g.solid[y * g.width + g.width - x - 1]:
					matches += 1
		assert_lt(matches * 2, solids)
		var north_solids: int = 0
		var train_matches: int = 0
		for y in range(1, 46):
			for x in range(g.width):
				var kind: int = g.solid[y * g.width + x]
				if kind == S.NONE or kind == S.AIR:
					continue
				north_solids += 1
				if kind == g.solid[(94 - y) * g.width + x]:
					train_matches += 1
		assert_lt(train_matches * 2, north_solids)
		var source: String = FileAccess.get_file_as_string("res://game/world/maps/" + d["place_id"] + ".gd")
		var first: String = source.get_slice("\n", 0)
		assert_true(first.begins_with("# 이 지도가 다른 판단을 만드는 것: "))
		assert_false(comments.has(first))
		comments[first] = true
		var second: String = source.get_slice("\n", 1)
		assert_true(second.begins_with("# 위쪽의 판단: "))
		assert_false(comments.has(second))
		comments[second] = true
		assert_false(source.contains("sulehuf_map.gd"))
		for j in range(i):
			assert_ne(g.solid, maps[j]["grid"].solid)
			assert_ne(g.solid.slice(0, g.width * 46), maps[j]["grid"].solid.slice(0, maps[j]["grid"].width * 46))


func test_prop_vocabulary_floors_render_backing_and_protected_cells() -> void:
	for d: Dictionary in maps:
		var g: FieldGrid = d["grid"]
		var bounds := Rect2i(0, 0, g.width, g.height)
		var protected: Dictionary = {}
		for c: Vector2i in g.doors:
			var normal: Vector2i = _door_normal(g, c, d["buildings"])
			for step in range(1, 4):
				protected[c + normal * step] = true
				protected[c - normal * step] = true
		for c: Vector2i in d["train_doors"]["lower"]:
			for step in range(4):
				protected[c + Vector2i(0, step)] = true
		for c: Vector2i in d["barricade_slots"]:
			protected[c] = true
		for cc: Array in d["entries"].values():
			for c: Vector2i in cc:
				protected[c] = true
		assert_gte(d["props"].size(), 130)
		var north_props: int = 0
		var north_indoors: int = 0
		var indoors: int = 0
		var collisions: int = 0
		for p: Dictionary in d["props"]:
			var r: Rect2i = p["rect"]
			var level: int = int(p.get("level", 0))
			if r.position.y < 46:
				north_props += 1
				for b: Dictionary in d["buildings"]:
					if b["rect"].encloses(r):
						north_indoors += 1
						break
			assert_true(KINDS.has(p["kind"]), p["kind"])
			assert_true(bounds.encloses(r))
			assert_gt(r.size.x, 0)
			assert_gt(r.size.y, 0)
			assert_true(["low", "wall", "tree", "wagon", "none"].has(p["solid"]))
			assert_true(_korean_name(p["note"]))
			assert_between(level, -1, 3)
			for b: Dictionary in d["buildings"]:
				if b["rect"].encloses(r):
					indoors += 1
					break
			if level != 0:
				assert_eq(p["solid"], "none")
			if level == 3:
				assert_eq(p["kind"], "floor_shell")
				var shell_building: Dictionary = {}
				for b: Dictionary in d["buildings"]:
					if b["rect"] == r:
						shell_building = b
				assert_false(shell_building.is_empty())
				var stubs: int = 0
				for q: Dictionary in d["props"]:
					if q["kind"] == "stair_stub" and int(q.get("level", 0)) == 2 and r.encloses(q["rect"]):
						stubs += 1
						assert_eq(q["rect"].size, Vector2i(1, 2))
				assert_eq(stubs, 1)
			if level == 0:
				if p["solid"] == "low" and p["kind"] != "water":
					assert_true(d["low_blocks"].has(r))
				for c: Vector2i in _cells(r):
					if protected.has(c):
						collisions += 1
					if p["solid"] == "wall":
						assert_eq(g.solid_at(c), S.WALL)
					if p["solid"] == "tree":
						assert_true(d["trees"].has(c))
						assert_eq(g.solid_at(c), S.BLOCK)
		assert_gte(indoors * 2, d["props"].size())
		assert_gte(north_props, 40)
		assert_gte(north_indoors * 2, north_props)
		assert_eq(collisions, 0, d["place_id"])


func test_every_large_view_has_ground_detail() -> void:
	for d: Dictionary in maps:
		var g: FieldGrid = d["grid"]
		var stride: int = g.width + 1
		var solids := PackedInt32Array()
		var horizontal := PackedInt32Array()
		var vertical := PackedInt32Array()
		solids.resize(stride * (g.height + 1))
		horizontal.resize(solids.size())
		vertical.resize(solids.size())
		for y in range(g.height):
			for x in range(g.width):
				var i: int = y * g.width + x
				var at: int = (y + 1) * stride + x + 1
				var solid: int = 1 if g.solid[i] != S.NONE else 0
				var h: int = 1 if x > 0 and g.floor[i] != g.floor[i - 1] else 0
				var v: int = 1 if y > 0 and g.floor[i] != g.floor[i - g.width] else 0
				solids[at] = solid + solids[at - 1] + solids[at - stride] - solids[at - stride - 1]
				horizontal[at] = h + horizontal[at - 1] + horizontal[at - stride] - horizontal[at - stride - 1]
				vertical[at] = v + vertical[at - 1] + vertical[at - stride] - vertical[at - stride - 1]
		var empty: int = 0
		for y in range(g.height - 19):
			for x in range(g.width - 29):
				var total: int = _sum_rect(solids, stride, Rect2i(x, y, 30, 20))
				total += _sum_rect(horizontal, stride, Rect2i(x + 1, y, 29, 20))
				total += _sum_rect(vertical, stride, Rect2i(x, y + 1, 30, 19))
				if total == 0:
					empty += 1
		assert_eq(empty, 0, d["place_id"])


func _sum_rect(prefix: PackedInt32Array, stride: int, r: Rect2i) -> int:
	return prefix[r.end.y * stride + r.end.x] - prefix[r.position.y * stride + r.end.x] - prefix[r.end.y * stride + r.position.x] + prefix[r.position.y * stride + r.position.x]


func test_kind_specific_landmarks_and_market() -> void:
	for i in range(maps.size()):
		var d: Dictionary = maps[i]
		var counts: Dictionary = {}
		for p: Dictionary in d["props"]:
			counts[p["kind"]] = int(counts.get(p["kind"], 0)) + 1
			if p["kind"] == "bell_rope":
				assert_eq(p.get("level", 0), 1)
		assert_eq(counts.get("bell_rope", 0), 1)
		assert_eq(counts.get("bell_frame", 0), 1)
		var tower: Dictionary = {}
		for building: Dictionary in d["buildings"]:
			if building["name"] == "종탑":
				tower = building
		assert_false(tower.is_empty())
		var flights: Dictionary = {}
		for stair: Dictionary in d["stairs"]:
			if tower["rect"].has_point(stair["cell"]):
				flights[stair["low"]] = stair["cell"]
		assert_eq(flights.size(), 2)
		var ground: FieldGrid = d["grid"]
		var exits: Array = []
		for c: Vector2i in ground.doors:
			var r: Rect2i = tower["rect"]
			if int(ground.doors[c]["building"]) == int(tower["id"]) and (c.x == r.position.x or c.x == r.end.x - 1 or c.y == r.position.y or c.y == r.end.y - 1):
				exits.append(c)
		assert_eq(exits.size(), 1)
		var approach: PackedInt32Array = _distances(ground, exits)
		var winding: PackedInt32Array = _distances(d["levels"][1], [flights[0]])
		var minimum: int = 14 if i == 4 else 12
		assert_gte(approach[ground.index(flights[0])], minimum)
		assert_gte(winding[ground.index(flights[1])], minimum)
		assert_gte(counts.get("hand_bell", 0), 2)
		assert_gte(counts.get("hymn_shelf", 0), 2)
		if i == 1:
			assert_eq(counts.get("floor_shell", 0), 4)
			assert_eq(counts.get("nave_pillar", 0), 12)
		else:
			assert_eq(counts.get("floor_shell", 0), 0)
		if i == 4:
			for p: Dictionary in d["props"]:
				if p["kind"] == "water" and p["rect"].position.y >= 46:
					assert_lte(p["rect"].size.x, 10)
					assert_lte(p["rect"].size.y, 8)
		if i == 5:
			assert_eq(counts.get("hand_bell", 0), 2)
			assert_gte(counts.get("display_shelf", 0), 5)
			assert_gte(counts.get("checkout", 0), 2)
			assert_eq(counts.get("plank_patch", 0), 4)


# 수정 전 남쪽의 모든 칸 종류와 바닥. 세 바이트는 반복 수 둘과 칸 값 하나다.
const SOUTH_BEFORE: Array[String] = [
	"lgAAEAAgUAAiRgAgUAAiRgAgUAAiNgAgEAAAUgAQRAAAUgAQRAAAUgAQRAAAUgAQRAAAUgAQRAAAUgAQNAAAEgAoFAAABQAISwAAMgAoDQAABAADAwAABQAISwAAMgAoDQAABAADAwAABQAIBwAAAwADDQAAAgADMgAAMgAoFAAABQAIFwAAAgADMgAAMgAoFAAABQAISwAAMgAoFAAABQAISwAAMgAoFAAABQAIFQAABAAZAQAdBgAZAQAdBAAZJgAAJAAoBAAZAQAdBAAZAQAdBAAZFAAABQAIFQAAAQAZDgAYAQAZJgAADgAoAQAqFQAoAQAZDAAYAQAZFAAABQAIAQAABAAZAQAdBAAZAQAdBAAZBgAAAQAdDgAYAQAZBAAABAAZAQAdBgAZAQAdBAAZCAAAAQACCQAAJAAoAQAdDAAYAQAZFAAABQAIAQAAAQAZBgAYAQAZBQAYAQAZBgAAAQAZDgAYAQAZBAAAAQAZBwAYAQAZBgAYAQAZEgAAJAAoAQAZDAAYAQAZFAAABQAIAQAAAQAdBgAYAQAZBQAYAQAZBgAACAAZAQAcBwAZBAAAAQAdBwAYAQAZBgAYAQAZEgAAAwAoAQAqGAAoAQAqBwAoBwAZAQAcBgAZFAAABQAIAQAAAQAZBgAYAQAZBQAYAQAZBgAAAQAcDgAYAQAcBAAAAQAZBwAYAQAZBgAYAQAZEgAAJAAoAQAcDAAYAQAcFAAABQAIAQAAAQAZBgAYAQAZBQAYAQAZBgAAAQAZDgAYAQAZBAAAAQAZBwAYAQAZBgAYAQAZCgAAAQACBwAAJAAoAQAZDAAYAQAZFAAABQAIAQAAAQAcBgAYAQAcBQAYAQAcBgAACAAZAQAcBwAZBAAAAQAcBwAYAQAcBgAYAQAcEgAAJAAoBwAZAQAcBgAZFAAABQAIAQAAAQAZBgAYAQAZBQAYAQAZBgAAAQAZDgAYAQAZBAAAAQAZBwAYAQAZBgAYAQAZEgAAJAAoAQAZDAAYAQAZFAAABQAIAQAAAQAZBgAYAQAZBQAYAQAZBgAAAQAZDgAYAQAZBAAAAQAZBwAYAQAZBAAYAgAbAQAZDgAAAQACAwAAJAAoAQAZDAAYAQAZFAAABQAIAQAAAQAZBgAYAQAZBQAYAQAZBgAAAQAZDgAYAQAZBAAAAQAZBwAYAQAZBgAYAQAZEgAAJAAoAQAZDAAYAQAZFAAABQAIAQAABAAZAQAdBAAZAQAdBAAZBgAABAAZAQAdBgAZAQAdBAAZBAAABAAZAQAdBgAZAQAdBAAZBgAAAQACAgAAAQACCAAAJAAoBAAZAQAdBAAZAQAdBAAZFAAABQAISwAALwAoAQAqAgAoFAAABQAISwAAGAAoAQAqBwAoPwAIVwAAPwAIVwAAPwAITAAAAQACCgAAPwAIVwAAPwAIVwAAgwAIKwAABAAZAQAdBAAZAQAdBAAZEQAATAAIFwAAAQACEwAAAQAZBgAbAQAYAgAbAQAYAgAbAQAZEQAACgAICAALBgAICAALDwAICAALBAAICAALCQAIKwAAAQAdBAAbBgAYAgAbAQAZEQAATAAIKwAAAQAZAgAbCQAYAQAbAQAZEQAATAAIKwAABwAZAQAcBgAZEQAABQAIQQA4AQAABQAIKwAAAQAcDAAYAQAcEQAABQAIOAA4AgAZAQAdAgAZAQAdAgAZAQA4AQAABQAIKwAAAQAZDAAYAQAZEQAABQAIDAA4CwAZAQAdEQAZAQAdDAAZAgA4AQAZAgAbBAAYAQAZAQA4AQAABQAIAQAABAAZAQAdBAAZAQAdBAAZHAAABwAZAQAcBgAZAQAABAAZAQAdBAAZAQAdBAAZAgAABQAIAwAZAQAdAgAZAQAdAwAZAgA4AQAZAgAbBAAYAQAbAQAZAQAYAgAbAwAYAQAbAQAZAQAYAgAbBAAYAQAZAgAbBAAYAQAbAQAZAQAYAgAbAwAYAgAbAQAZAgA4AQAdAgAbBAAYAQAZAQA4AQAABQAIAQAAAQAZAgAbBwAYAwAbAQAZHAAAAQAZAwAbBwAYAgAbAQAZAQAAAQAZAwAbCQAYAQAZAgAABQAIAQAZAQAYAQAbAQAYAQAZAgAbAgAYAQAZAgA4AQAdBwAYAQAZBwAYAQAZBwAYAQAZBwAYAQAZCAAYAQAZAgA4AQAcBgAYAQAZAQA4AQAABQAIAQAAAQAdDAAYAQAZHAAAAQAZAQAYAgAbCQAYAQAZAQAAAQAdDAAYAQAZAgAABQAIAQAdAwAYAQAZBAAYAQAZAgA4AQAZBwAYAQAZBwAYAQAZBwAYAQAZBwAYAQAZCAAYAQAZAgA4AQAZBgAbAQAZAQA4AQAABQAIAQAAAQAZDAAYAQAZHAAAAQAZCwAYAQAbAQAZAQAAAQAZAwAbBgAYAgAbAQAYAQAZAgAABQAIAQAZAwAYAQAZBAAYAQAZAgA4AQAZBwAYAQAZBwAYAQAZBwAYAQAZBwAYAQAZCAAYAQAZAgA4AgAZAQAdAgAZAQAdAgAZAQA4AQAABQAIAQAAAQAZAQAbCQAYAgAbAQAZHAAABAAZAQAdBAAZAQAdBAAZAQAABwAZAQAcBgAZAgAABQAIAQAZAwAYAQAZBAAYAQAZAgA4AQAZAgAbBAAYAQAbAQAZAgAbAwAYAQAbAQAYAQAZAgAbAwAYAgAbAQAZAgAbBAAYAQAbAQAZAgAbBAAYAQAbAQAYAQAZCwA4AQAABQAIAQAABwAZAQAcBgAZKwAAAQAcDAAYAQAcAgAABQAIAQAZAwAYAQAZBAAYAQAZAgA4BAAZAQAcBwAZAQAcBwAZAQAcBwAZAQAcCAAZAQAcBAAZCwA4AQAABQAIAQAAAQAcDAAYAQAcKwAAAQAZDAAYAQAZAgAABQAIAQAZAwAYAQAZBAAYAQAZAgA4AQAZBAAYBgAbEgAYBgAbBgAYAQAZCwA4AQAABQAIAQAAAQAZDAAYAQAZHwAAAgAZAgAdAgAZBgAABwAZAQAcBgAZAgAABQAIAQAZAwAYAQAcBAAYAQAZAgA4AQAZHwAYBQAbAQAYAgAbAQAYAQAZCwA4AQAABQAIAQAABwAZAQAcBgAZHwAAAQAZAwAbAQAYAQAZBgAAAQAZAgAbCgAYAQAZAgAABQAIAQAZAwAbAQAZAQAbAQAYAQAbAQAYAQAZAgA4AQAZBAAYBgAbEgAYBgAbAwAYAgAbAQAYAQAZCwA4AQAABQAIAQAAAQAZAQAYAwAbBwAYAQAbAQAZHwAAAQAdBAAYAQAZBgAAAQAZDAAYAQAZAgAABQAIAwAZAQAdAgAZAQAdAQAZAQAcAQAZAgA4AQAZKAAYAQAZCgA4AQA6AQAABQAIAQAAAQAZDAAYAQAZHwAAAQAcBAAYAQAZBgAAAQAZAwAbBgAYAwAbAQAZAgAABQAIDAA4AQAZAQAYBgAbEQAYBgAbCgAYAQAZCwA4AQAABQAIAQAAAQAZDAAYAQAZHwAAAQAZAQAYAgAbAQAYAQAZBgAABAAZAQAdBAAZAQAdBAAZAgAABQAIDAA4AQAZKAAYAQAZCwA4AQAABQAIAQAAAQAZAgAbCAAYAgAbAQAZGwAAAQACAwAAAgAZAgAdAgAZFgAABQAIDAA4AQAcAwAYBgAbDwAYBgAbCgAYAQAcCwA4AQAABQAIAQAABAAZAQAdBAAZAQAdBAAZCgAAAQACMAAABQAIDAA4AQAZKAAYAQAZCwA4AQAABQAIEwAAPAAIDAA4AQAZAQAYBgAbEQAYBgAbCgAYAQAZAgA4AgAZAQAdAgAZAQAdAgAZAQA4AQAABQAIEwAAPAAIDAA4AQAZKAAYAQAZAgA4AQAZAwAbAwAYAQAZAQA4AQAABQAIEwAAPAAIDAA4AQAZKAAYAQAZAgA4AQAdBgAYAQAZAQA4AQAABQAIBQAAAQACCwAAAQACAQAAPAAIDAA4AQAZKAAYAQAZAgA4AQAcBgAYAQAZAQA4AQAABQAIEwA4PAAIDAA4BAAZAQAcBwAZAQAcBwAZAQAcBwAZAQAcCAAZAQAcBAAZAgA4AQAZBQAbAQAYAQAZAQA4AQAABQAIEwA4NwAABQAIDAA4AQAZAQAYAQAbAwAYAgAbAQAZAgAbAwAYAgAbAQAZAQAbBQAYAQAbAQAZAQAYAQAbAwAYAgAbAQAZAgAbBAAYAgAbAQAZAgA4AgAZAQAdAgAZAQAdAgAZAQA4AQAABQAIEwA4GgAoAQAqFAAoCAAABQAIDAA4AQAZBwAYAQAZBwAYAQAZBwAYAQAZBwAYAQAZCAAYAQAZCwA4AQAABQAIEwA4LwAoCAAABQAIDAA4AQAZBwAYAQAZBwAYAQAZBwAYAQAZBwAYAQAZCAAYAQAZCwA4AQAAGAAIAwAoAQAqKwAoCAAABQAIDAA4AQAZBwAYAQAZBwAYAQAZBwAYAQAZBwAYAQAZCAAYAQAZCAA4AQA6AgA4AQAAGAAILwAoBAAZAQAdBAAZAQAdBAAZCwA4AQAZAQAbBAAYAgAbAQAZBAAYAgAbAQAYAQAZAgAbAgAYAgAbAQAYAQAZAQAbBAAYAgAbAQAZBQAYAgAbAQAYAQAZCwA4AQAAGAAIFQAoFgAzBAAoAQAZBAAbAgAYAQAZAgAbAQAYAgAbAQAZCwA4CwAZAQAdEQAZAQAdDAAZCwA4AQAAGAAIFQAoFgAzBAAoAQAdBgAYAQAZAgAbAwAYAQAZQAA4AQAAGAAIFQAoFgAzBAAoAQAZBgAYAQAZBQAYAQAZBgA4BAA7FAA4BQAZAQAdBgAZAQAdBQAZBgA4BAA7BgA4AQAABgAIAwAZAQAdBAAZAQAdAwAZBgA4BAAoBAAZAQAdBAAZAQAdBAAZAwAoFgAzBAAoAQAZBgAYAQAZBQAYAQAZBgA4BAA7FAA4AQAZAQAYAgAbAwAYAgAbAQAZAwAbAgAYAgAbAQAZBgA4BAA7BgA4AQAABgAIAQAZAgAbCAAYAQAZBgA4BAAoAQAZAQAYAQAbCAAYAgAbAQAZAwAoFgAzBAAoAQAcBgAYAQAcBQAYAQAcBgA4BAA7FAA4AQAdBgAYAgAbAQAZAQAYAgAbAgAYAgAbAQAZBgA4BAA7BgA4AQAABgAIAQAdAgAbCAAYAQAZBgA4BAAoAQAdDAAYAQAZAwAoFgAzBAAoAQAZBgAYAQAZBQAYAQAZHgA4AQAZCAAYAQAZBwAYAQAZEAA4AQAABgAIAQAZCgAYAQAZBgA4BAAoAQAZAgAbBgAYAwAbAQAYAQAZAwAoFgAzBAAoAQAZAwAYAgAbAQAYAQAZBQAYAQAZDgA4BAA7DAA4AQAZCAAYAQAZBwAYAQAZEAA4AQAABgAIAQAcCgAYAQAcBgA4BAAoBwAZAQAcBgAZAwAoFgAzBAAoAQAZAgAbAQAYAgAbAQAYAQAZAQAYBAAbAQAZDgA4BAA7DAA4AQAcCAAYAQAcBwAYAQAcEAA4AQAABgAIAQAZCgAYAQAZAQA4AQA6BAA4BAAoAQAcDAAYAQAcAwAoFgAzBAAoBAAZAQAdBAAZAQAdBAAZDgA4BAA7DAA4AQAZCAAYAQAZBwAYAQAZEAA4AQAABgAIAQAZAgAbBAAYBAAbAQAZBgA4BAAoAQAZDAAYAQAZAwAoFgAzBAAoCAAABQAIHwA4AQAZAgAbBgAYAQAZBwAYAQAZDAA4AQA6AwA4AQAABgAIAwAZAQAdBAAZAQAdAwAZBgA4BAAoBwAZAQAcBgAZAwAoFgAzBAAoCAAABQAIAwA4AQA6GwA4AQAZAgAbBAAYAQAbAQAYAQAZBAAYAgAbAQAYAQAZEAA4AQAACQAIDwA4BAAoAQAZAQAYAgAbBwAYAgAbAQAZAwAoFgAzBAAoCAAABQAIAgA7AwA4CAA7BQA4CAA7BQA4BQAZAQAdBgAZAQAdBQAZBAA4CAA7BAA4AQAACQAIDwA4BAAoAQAZDAAYAQAZAwAoFgAzBAAoBwAAAQACBQAIAgA7PwA4AQAACQAIDwA4BAAoAQAZAwAbBwAYAQAbAQAYAQAZAwAoFgAzBAAoCAAAUAAIDwA4BAAoBAAZAQAdBAAZAQAdBAAZAwAoFgAzBAAoCAAAOAAIBAALFAAIDwA4FQAoFgAzBAAoCAAAOAAIBAALAwAIBAALDQAICgA4AQA6BAA4FQAoFgAzBAAoCAAAPwAIBAALDQAIDwA4FQAoFgAzBAAoCAAATAAIEwA4FQAoFgAzAgAoAQAqAQAoFAAAAgADGQAABgAIMgAAEgAoAQAqAgAoFgAzBAAoAwAAAQACEAAAAgADDQAAAQACCwAABgAIMgAALwAoEwAAAgADAQACGQAABgAIMgAALwAoLwAABgAICgAAAQACJwAALwAoLwAABgAIMgAA",
	"rwAAEAAgUAAiXwAgUAAiXwAgUAAiTwAgEAAAUgAQXQAAUgAQXQAAUgAQXQAAUgAQXQAAUgAQXQAAUgAQTQAAFgAoPgAABgAIOAAAMwAoCQAABAADMQAABgAIOAAABwAoAQAqKwAoAgAABwA4BAA7DwA4AwA7DQA4AgA7EAA4BgAIHgA4AQACGQAAMwAoAgAAKgA4AgA7EAA4BgAIHgA4GgAAMwAoAgAAPAA4BgAIHgA4GgAAMwAoAgAAPAA4BgAIHgA4AwAABgAZAQAdCQAZAQAdBwAZJAAoAQAqDQAoAgAAPAA4BgAIHgA4AwAAAQAZBAAbBQAYAQAbAQAZAQAYAQAbBwAYAgAbAQAZMgAoAgAAPAA4BgAIHgA4AwAAAQAdCgAYAQAZCwAYAQAZMgAoAgAABAA4BQAZAQAdBwAZAQAdBgAZJAA4BgAIBwA4AwAZAQAdBAAZAQAdBAAZCgA4AwAAAQAZCgAYAQAZCwAYAQAZDAAoAQAqJQAoAgAABAA4AQAZEgAYAQAZJAA4BgAIBwA4AQAZBQAYAQAZBQAYAQAZCgA4AwAAAQAZCgAYAQAZCwAYAQAZMgAoAgAABAA4AQAdEgAYAQAZBQA4BAAZAQAdBgAZAQAdBAAZDwA4BgAIBwA4AQAdBQAYAQAZBQAYAQAZCgA4AwAAAQAZCgAYAQAZCwAYAQAZMgAoAgAABAA4AQAZEgAYAQAZBQA4AQAZBwAYAQAZBgAYAQAZDwA4BgAIBwA4AQAZBQAYAQAZBQAYAQAZBQA4AQA6BAA4AwAAAQAZCgAYAQAZCwAYAQAZMgAoAgAABAA4CgAZAQAcCQAZBQA4AQAdBwAYAQAZBgAYAQAZDwA4BgAIBwA4AQAZBQAYAQAZBQAYAQAZCgA4AwAAAQAZAgAbBQAYAwAbAQAZAwAbBAAYBAAbAQAZMgAoAgAABAA4AQAcEgAYAQAcBQA4AQAZBwAYAQAZBgAYAQAZDwA4BgAIBwA4AQAcBQAYAQAcBQAYAQAcCgA4AwAABgAZAQAcCgAZAQAcBgAZKAAoAQAqCQAoAgAABAA4AQAZEgAYAQAZBQA4AQAcBwAYAQAcBgAYAQAcBQA4BAA7BgA4BgAIBwA4AQAZBQAYAQAZBQAYAQAZCgA4AwAAAQAcFgAYAQAcMgAoAgAABAA4CgAZAQAcCQAZBQA4AQAZBwAYAQAZBgAYAQAZBQA4BAA7BgA4BgAIBwA4AQAZBQAYAQAZBQAYAQAZBQA4AQA6BAA4AwAAAQAZFgAYAQAZMgAoAgAABAA4AQAZEgAYAQAZBQA4AQAZBwAYAQAZBgAYAQAZDwA4BgAIBwA4AQAZBQAYAQAZBQAYAQAZCgA4AwAABgAZAQAcCgAZAQAcBgAZFgAoAQAqGwAoAgAABAA4AQAZEgAYAQAZBQA4BAAZAQAdBgAZAQAdBAAZDwA4BgAIBwA4AwAZAQAdBAAZAQAdBAAZCgA4AwAAAQAZBAAbBQAYAQAbAQAZAQAYAgAbBQAYAwAbAQAZCgAoAQAqJwAoAgAABAA4AQAZEgAYAQAZJAA4BgAIHgA4AQACAgAAAQAZCgAYAQAZCwAYAQAZMgAoAgAABAA4BQAZAQAdBwAZAQAdBgAZJAA4BgAIHgA4AwAAAQAZCgAYAQAZCwAYAQAZHAAoGAAAPAA4BgAIHgA4AwAAAQAZCgAYAQAZCwAYAQAZMAAAAQACAwAAPAA4BgAIAwA4AQA6GgA4AwAAAQAZCgAYAQAZCwAYAQAZcAAABgAIIQAAAQAZCgAYAQAZCwAYBwAZAQAdCAAZAQAdBgAZWgAABgAIHQAAAQACAwAAAQAZAgAbBQAYAwAbAQAZBAAbBQAYAQAbAQAYAgAZAgAbEgAYAQAZDAAAAQACTQAABgAIIQAABgAZAQAdCQAZAQAdBwAZAQAdFAAYAQAZIAAABgAZAQAdCAAZAQAdBgAZCAAAAQACGwAABgAIOQAAAQAZFAAYAQAZIAAAAQAZBQAbCAAYAgAbBQAYAQAZRAAAAQACHgAAAQAZFAAYAQAZIAAAAQAdAgAYAQAbAgAYAQAbAgAYAQAbBgAYAQAbAgAYAQAbAQAYAQAZSgAAGQAoAQAZAwAbDgAYAwAbAQAZIAAAAQAZAQAbAQAYAQAbAgAYAQAbAgAYAQAbBgAYAQAbAgAYAQAbAQAYAQAZPgAAAQACCwAAGQAoCwAZAQAcCgAZEgAAAQACDQAAAQAZAgAYAQAbAgAYAQAbAgAYAQAbBgAYAQAbAgAYAQAbAQAYAQAZDQAAAwADOgAABQAIFAAoAQAcFAAYAQAcIAAAAQAZAgAYAQAbAgAYAQAbAgAYAQAbBAAYAwAbAgAYAQAbAQAYAQAZDQAAAwADOgAABQAIFAAoAQAZFAAYAQAZIAAAAQAZFAAYAQAZFgAAAwADMQAABQAIFAAoCwAZAQAcCgAZIAAAAQAZEAAYAgAbAgAYAQAZFgAAAwADMQAABQAIFAAoAQAZAgAbDwAYAwAbAQAZIAAAAQAcFAAYAQAcCAAAAQACQQAABQAIFAAoAQAZFAAYAQAZBgAAGQAIAQAAAQAZFAAYAQAZBgAIRAAABQAIFAAoAQAZFAAYAQAZBgAAGQAIAQAAAQAZAQAYAwAbAwAYAgAbCwAYAQAZBgAIRAAABQAIFAAoAQAZFAAYAQAZAgAAAQACAwAAGQAIAQAAAQAZFAAYAQAZBgAICQAAAwADCAAAAgADCAAABAADIgAABQAIFAAoAQAZAQAbEQAYAgAbAQAZBgAAGQAIAQAAAQAZFAAYAQAZBgAICQAAAwADAgAAAgADBAAAAgADCAAABAADIgAABQAIFAAoBgAZAQAdCAAZAQAdBgAZBgAAGQAIAQAABgAZAQAcCgAZAQAcBAAZBgAIDgAAAgADDgAABAADIgAABQAIFAAoMQAABAAIAQAAAQAZAgAbBgAYAgAbAgAYAQAZAgAbBQAYAQAZBgAIFwAAAgADBQAABAADEgAAAwADDQAABQAIRQAABAAIAQAAAQAZAgAbBgAYAgAbAgAYAQAZBAAYAwAbAQAZBgAIDwAAAQADBwAAAgADGwAAAwADDQAABQAIRQAABAAIAQAAAQAZDAAYAQAZBwAYAQAZBgAIRAAABQAIRQAABAAIAQAABgAZAQAdBQAZAQAcAgAZAQAdCQAZAQAdBAAZAQAdAwAZPgAANQAIEwAAAQACAQAABAAIFwAAAQAZAQAYAQAbAgAYAQAZAgAbAgAYAQAbAQAZPgAADAAIBAALJQAIFQAABAAIFwAAAQAdBAAYAQAZBQAYAQAZPgAADAAIBAALBQAIBAALHAAIFQAABAAIFwAAAQAZBAAYAQAZBQAYAQAZPgAAFQAIBAALHAAIFQAABAAIFwAAAQAZBAAYAQAZBQAYAQAZPgAANQAIFQAABAAICgAAAwADBQAAAgADAwAAAQAZBAAYAQAZBQAYAQAZTgAABAAICgAABAAZAQAdBAAZAQAdBAAZAwAABQAIBwAAAQACDgAAGwAIAQAZBAAYAQAZBQAYAQAZTgAABAAICgAAAQAZAgAbAQAYAwAbAQAZAQAYBAAbAQAZAwAABQAIFgAAGwAIAQAZBAAYAQAZBQAYAQAZTgAABAAICgAAAQAdBgAYAQAZBQAYAQAZAwAABQAIFgAAGwAIAQAZBAAYAQAZBQAYAQAZTgAABAAICgAAAQAZBgAYAQAZBQAYAQAZAwAABQAIFgAAFgAIAgALAwAIAQAZBAAYAQAcBQAYAQAcRgAAAwAZAQAdAgAZAQAdAwAZAgAICgAAAQAZBgAYAQAZBQAYAQAZAwAABQAIBAAABQAZAQAdBwAZAQAdBgAZAwAAAQACCwAABQAIAgADAwAAAQAZAQAYAwAbAQAZBAAbAQAYAQAZRgAAAQAZAwAbBQAYAQAZAgAICgAAAQAcBgAYAQAcBQAYAQAcAwAABQAIBAAAAQAZAwAbDgAYAQAbAQAZDQAAAgADCgAIAwAZAQAdBAAZAQAdAwAZRgAAAQAdCAAYAQAZAgAICgAAAQAZBgAYAQAZBQAYAQAZAwAABQAIBAAAAQAdEgAYAQAZDQAAAgADCgAIUgAAAQAZCAAYAQAZAgAICgAAAQAZBgAYAQAZBQAYAQAZAwAABQAIBAAAAQAZEgAYAQAZCQAAAQACBQAACgAIUgAAAQAcCAAYAQAcAgAICgAAAQAZAQAbAwAYAgAbAQAZAgAbAQAYAgAbAQAZAwAABQAIBAAAAQAZEgAYAQAZDwAACgAIFgAZAQAdEQAZAQAcEAAZAQAdFgAZAgAAAQAZCAAYAQAZAgAICgAABAAZAQAdBAAZAQAdBAAZAwAABQAIBAAAAQAZEgAYAQAZDwAACgAIAQAZAgAbCwAYAQAbAQAZAQAYAgAbCwAYAQAbAQAZAQAYAgAbDAAYAQAZAgAbDAAYAQAbAQAZAQAYAgAbCgAYAgAbAQAZAgAAAQAZAwAbAgAYAgAbAQAYAQAZAgAIGwAABQAIBAAAAQAZAgAbCwAYBAAbAQAYAQAZDwAABQAIBQAAAQAdDgAYAQAZDwAYAQAZDwAYAQAZDwAYAQAZDwAYAQAZAgAAAwAZAQAdAgAZAQAdAwAZAgAIAQAABQAZAQAdBwAZAQAdBgAZBgAABQAIBAAACgAZAQAcCQAZDwAABQAIBQAAAQAZDgAYAQAZDwAYAQAZDwAYAQAZDwAYAQAZDwAYAQAZCgAABAAIAQAAAQAZAgAbEAAYAQAZBgAABQAIBAAAAQAcEgAYAQAcDwAABQAIAQAAAQACAwAAAQAZDgAYAQAZDwAYAQAZDwAYAQAZDwAYAQAZDwAYAQAZCgAABAAIAQAAAQAdEgAYAQAZBgAABQAIBAAAAQAZEgAYAQAZDwAABQAIBQAAAQAZAgAbCwAYAQAbAQAZAgAbCwAYAQAbAQAYAQAZAgAbCwAYAgAbAQAZAgAbDAAYAQAbAQAZAgAbCwAYAQAbAQAYAQAZCgAABAAIAQAAAQAZEgAYAQAZBgAABQAIBAAACgAZAQAcCQAZDwAABQAIBQAACAAZAQAcDgAZAQAcDwAZAQAcDwAZAQAcDwAZAQAcCAAZCgAABAAIAQAAAQAZAwAbDAAYAwAbAQAZBgAABQAIBAAAAQAZBAAbDQAYAQAbAQAZAgAABAAZAQAdBgAZAQAdBAAZAgAIBQAAAQAZAQAYBgAbJAAYBgAbHQAYAQAZCgAABAAIAQAACgAZAQAcCQAZBgAABQAIBAAAAQAZEgAYAQAZAgAAAQAZAQAYAgAbCQAYAgAbAQAZAgAIBQAAAQAZRQAYAQAbAQAYBgAbAQAYAQAZCgAABAAIAQAAAQAcEgAYAQAcBgAABQAIBAAAAQAZEgAYAQAZAgAAAQAdDgAYAQAZAgAIBQAAAQAZAQAYBgAbJAAYBgAbFwAYAgAbBAAYAQAZCgAABAAIAQAAAQAZEgAYAQAZBgAABQAIBAAAAQAZEgAYAQAZAgAAAQAZAwAbCQAYAQAbAQAYAQAZAgAIBQAAAQAZTgAYAQAZCgAABAAIAQAACgAZAQAcCQAZBgAABQAIBAAAAQAZEgAYAQAZAgAACAAZAQAcBwAZAgAIAQAAAQACAwAAAQAZAQAYBgAbJAAYBgAbHQAYAQAZCgAABAAIAQAAAQAZAgAbDQAYAwAbAQAZBgAABQAIBAAAAQAZAgAbDQAYAwAbAQAZAgAAAQAcDgAYAQAcAgAIBQAAAQAZDQAYAgAZCAAYAgAZCAAYAgAZCgAYAgAZCAAYAgAZCAAYAgAZCwAYAQAZCgAABAAIAQAAAQAZEgAYAQAZBgAABQAIBAAABQAZAQAdBwAZAQAdBgAZAgAAAQAZDgAYAQAZAgAIBQAAAQAZAQAYBgAbBgAYAgAZCAAYAgAZCAAYAgAZCgAYAgAZBgAbAgAYAgAZCAAYAgAZCwAYAQAZCgAABAAIAQAAAQAZEgAYAQAZBgAABQAIGgAACAAZAQAcBwAZAgAIBQAAAQAZTgAYAQAZCgAABAAIAQAAAQAZAQAbDwAYAgAbAQAZBgAABQAIGgAAAQAZAwAbCwAYAQAZAgAIBQAAAQAZAQAYBgAbJAAYBgAbHQAYAQAZDwAIBQAZAQAdBwAZAQAdBgAZDAAIGQAAAQAZDgAYAQAZAgAIBQAAAQAZTgAYAQAZLwAIGQAAAQAZAwAbCAAYAgAbAQAYAQAZAgAIBQAAAQAZTgAYAQAZLwAIGQAABAAZAQAdBgAZAQAdBAAZAgAIBQAAAQAcTgAYAQAcLwAIAwAABAAZAQAdBAAZAQAdBAAZFQAABQAIBQAAAQAZTgAYAQAZCgAABAAIAQAAGQA4AQAABQAIBAAAAQAZAQAYAQAbCAAYAgAbAQAZFQAABQAIBQAAAQAZTgAYAQAZCgAABAAIAQAAGQA4CgAAAQAdDAAYAQAZFQAABQAIBQAAAQAZTgAYAQAZCgAABAAIAQAAAwA4AwAZAQAdBAAZAQAdAwAZCgA4CgAAAQAZAgAbBgAYAwAbAQAYAQAZFQAABQAIBQAAAQAZDQAYAgAZCAAYAgAZCAAYAgAZCgAYAgAZCAAYAgAZCAAYAgAZCwAYAQAZCgAABAAIAQAAAwA4AQAZAQAYAQAbBgAYAgAbAQAZCgA4BwAoAwAABwAZAQAcBgAZFQAABQAIBQAAAQAZDQAYAgAZCAAYAgAZCAAYAgAZCgAYAgAZCAAYAgAZCAAYAgAZCwAYAQAZBQAAAQACBAAABAAIAQAAAwA4AQAdCgAYAQAZCgA4BwAoAwAAAQAcDAAYAQAcBwAAAwAZAQAdBAAZAQAdAwAZAgAABQAIBQAAAQAZTgAYAQAZCgAABAAIAQAAAwA4AQAZCgAYAQAZCgA4AQAqBgAoAwAAAQAZDAAYAQAZBwAAAQAZAwAbAgAYAQAZAgAbAgAYAQAZAgAABQAIBQAAAQAZTgAYAQAZCgAABAAIAQAAAwA4AQAcCgAYAQAcCgA4BwAoAwAABwAZAQAcBgAZBwAAAQAdBQAYAQAZBAAYAQAZAgAABQAIAQACBAAAAQAZTgAYAQAZCgAABAAIAQAAAwA4AQAZAwAbBwAYAQAZCgA4BwAoAwAAAQAZAQAYAgAbBwAYAgAbAQAZBwAAAQAZBQAYAQAZBAAYAQAZAgAABQAIBQAAAQAZTgAYAQAZCgAABAAIAQAAAwA4AQAZAwAbBgAYAQAbAQAZCgA4BwAoAwAAAQAZDAAYAQAZBwAAAQAZBQAYAQAZBAAYAQAZAgAABQAIBQAAAQAZTgAYAQAZCgAABAAIAQAAAwA4AwAZAQAdBAAZAQAdAwAZCgA4BwAoAwAAAQAZAwAbBwAYAQAbAQAYAQAZBwAAAQAcBQAYAQAcBAAYAQAcAgAABQAIBQAACAAZAQAcDgAZAQAcDwAZAQAcDwAZAQAcDwAZAQAcCAAZCgAABAAIAQAAGQA4BwAoAwAABAAZAQAdBAAZAQAdBAAZBwAAAQAZBQAYAQAZBAAYAQAZAgAABQAIBQAAAQAZAQAYAQAbCgAYAgAbAQAZAgAbCwAYAgAbAQAZAQAbDQAYAQAbAQAZAQAYAQAbCwAYAgAbAQAZAgAbCwAYAgAbAQAZCgAABAAIAQAAFwA4AQA6AQA4HwAoAQAZBQAYAQAZBAAYAQAZAgAABQAIBQAAAQAZDgAYAQAZDwAYAQAZDwAYAQAZDwAYAQAZDwAYAQAZCgAABAAIAQAAGQA4HwAoAQAZAgAYAgAbAQAYAQAZAQAYAwAbAQAZAgAABQAIBQAAAQAZDgAYAQAZDwAYAQAZDwAYAQAZDwAYAQAZDwAYAQAZAQAAAQACCAAABAAIAQAAGQA4HwAoAwAZAQAdBAAZAQAdAwAZAgAABQAIBQAAAQAZDgAYAQAZDwAYAQAZDwAYAQAZDwAYAQAZDwAYAQAZCgAABAAIFQAALwAoAwAABQAIBQAAAQAZAQAbCwAYAgAbAQAZDAAYAgAbAQAYAQAZAgAbCgAYAgAbAQAYAQAZAQAbDAAYAgAbAQAZDAAYAgAbAQAYAQAZCgAABAAIFQAAEAAoAQAqDQAoAQAqDQAoAQAqAgAoAwAABQAIBQAAFgAZAQAdIgAZAQAdFgAZCgAABAAIFQAALwAoAwAABQAIXwAABAAIFQAALwAoAwAABQAIXwAABAAIFQAALwAoAwAABQAIXwAABAAIFQAADAAo",
	"qgAAEAAgUAAiWgAgUAAiWgAgUAAiSgAgEAAAUgAQWAAAUgAQWAAAUgAQWAAAUgAQWAAAUgAQWAAAUgAQSAAAFAAoEgAABQAITwAARAAoCwAABAADAwAABQAITwAARAAoCwAABAADAwAABQAIBwAAAwADRQAARAAoEgAABQAITwAARAAoEgAABQAITwAARAAoEgAABQAITwAAKwAoAQAqGAAoEgAABQAITwAARAAoAgAABAAZAQAdBAAZAQAdBAAZAgAABQAIOQAABAAZAQAdBAAZAQAdBAAZCAAAAQAoAQAqQgAoAgAAAQAZDAAYAQAZAgAABQAIBQAABAAZAQAdBgAZAQAdBAAZEAAAAwAZAQAdBAAZAQAdAwAZCAAAAQAZDAAYAQAZCAAAFQAoAQAqHwAoAQAqDgAoAgAAAQAdDAAYAQAZAgAABQAIBQAAAQAZBwAYAQAZBgAYAQAZEAAAAQAZBQAYAQAZBAAYAQAZCAAAAQAdDAAYAQAZCAAARAAoAgAAAQAZDAAYAQAZAgAABQAIBQAAAQAdBwAYAQAZBgAYAQAZEAAAAQAdBQAYAQAZBAAYAQAZCAAAAQAZDAAYAQAZCAAARAAoAgAABwAZAQAcBgAZAgAABQAIBQAAAQAZBwAYAQAZBgAYAQAZEAAAAQAZBQAYAQAZBAAYAQAZCAAABwAZAQAcBgAZCAAARAAoAgAAAQAcDAAYAQAcAgAABQAIBQAAAQAZBwAYAQAZBgAYAQAZEAAAAQAZBQAYAQAZBAAYAQAZCAAAAQAcDAAYAQAcCAAARAAoAgAAAQAZDAAYAQAZAgAABQAIBQAAAQAcBwAYAQAcBgAYAQAcEAAAAQAcBQAYAQAcBAAYAQAcCAAAAQAZDAAYAQAZCAAAIQAoAQAqGAAoAQAqCQAoAgAABwAZAQAcBgAZAgAABAALAQAIBQAAAQAZBwAYAQAZBgAYAQAZBgAABAADBgAAAQAZBQAYAQAZBAAYAQAZCAAABwAZAQAcBgAZCAAACAAoAQAqOwAoAgAAAQAZDAAYAQAZAgAABAALAQAIBQAAAQAZBwAYAQAZBgAYAQAZBgAABAADBgAAAQAZBQAYAQAZBAAYAQAZAgADBgAAAQAZDAAYAQAZCAAARAAoAgAAAQAZDAAYAQAZAgAABQAIBQAAAQAZBwAYAQAZBgAYAQAZEAAAAQAZBQAYAQAZBAAYAQAZCAAAAQAZDAAYAQAZCAAARAAoAgAAAQAZDAAYAQAZAgAABQAIBQAABAAZAQAdBgAZAQAdBAAZEAAAAwAZAQAdBAAZAQAdAwAZCAAAAQAZDAAYAQAZCAAAQAAoAQAqAwAoAgAABAAZAQAdBAAZAQAdBAAZAgAABQAIOQAABAAZAQAdBAAZAQAdBAAZCAAARAAoEgAABQAITwAAKQAoAQAqBgAoagAIQAAAagAIQAAAagAIQAAAagAIDgAAAgADMAAAagAIDgAAAgADMAAAagAIDQAAAwADBQAAAgADKQAAFAAoCgAABQAIHgAAAQACCgAAAQACEAAAAQACBgAARgAIFAAoCgAABQAIAQAAQAABGgAJBgAIIgAJBAAIFAAoCgAABQAIAQAAAQA5EQA4DQAZAQAdFQAZAQAdDgAZQgAIFAAoCgAABQAIAQAAAQA5EQA4AQAZAgAbBQAYAQAbAQAZAQAYAgAbBQAYAQAbAQAZAQAYAgAbBgAYAQAZAgAbBgAYAQAbAQAZAQAYAgAbBAAYAgAbAQAZQgAIBAAoAQAqDwAoCgAABQAIAQAAAQA5AwA4AwAZAQAdBAAZAQAdAwAZAgA4AQAdCAAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZQgAIFAAoCgAABQAIAQAAAQA5AwA4AQAZAQAYAQAbAgAYAQAZAgAbAgAYAQAbAQAZAgA4AQAZCAAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZQgAIFAAoCgAABQAIAQAAAQA5AwA4AQAdBAAYAQAZBQAYAQAZAgA4AQAZCAAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZAwA4BAAZAQAdBgAZAQAdBAAZAQA4BgAIJQA4AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAZBAAYAQAZBQAYAQAZAgA4AQAZAgAbBQAYAQAbAQAZAgAbBQAYAQAbAQAYAQAZAgAbBQAYAgAbAQAZAgAbBgAYAQAbAQAZAgAbBQAYAQAbAQAYAQAZAwA4AQAZAQAYAgAbCQAYAgAbAQAZAQA4BgAICQA4BAAZAQAdBAAZAQAdBAAZDQA4AQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAZBAAYAQAZBQAYAQAZAgA4BQAZAQAcCAAZAQAcCQAZAQAcCQAZAQAcCQAZAQAcBQAZAwA4AQAdDgAYAQAZAQA4BgAIAgA7BwA4AQAZBgAbAQAZAQAbAgAYAgAbAQAZDQA4AQA5AwAAFAAoCQAAAQACBQAIAQAAAQA5AwA4AQAZBAAYAQAZBQAYAQAZAgA4AQAZBQAYBgAbFwAYBgAbCAAYAQAZAwA4AQAZAwAbCQAYAQAbAQAYAQAZAQA4BgAIAgA7BwA4AQAdBgAbAQAZAwAYAgAbAQAZDQA4AQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAZBAAYAQAZBQAYAQAZAgA4AQAZJwAYBAAbAQAYAwAbAQAYAQAZAwA4CAAZAQAcBwAZAQA4BgAICQA4AQAZBgAbAQAZBQAYAQAZDQA4AQA5AwAACQAoAQAqCgAoCgAABQAIAQAAAQA5AwA4AQAZBAAYAQAZBQAYAQAZAgA4AQAZBQAYBgAbFwAYBgAbAQAYAgAbBQAYAQAZAwA4AQAcDgAYAQAcAQA4BgAICQA4AQAZBAAYAgAbAQAZBQAYAQAZDQA4AQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAZBAAYAQAZBQAYAQAZAgA4AQAZMAAYAQAZAwA4AQAZDgAYAQAZAQA4BgAICQA4AQAcBgAYAQAcBQAYAQAcDQA4AQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAZBAAYAQAcBQAYAQAZAgA4AQAZAQAYBgAbFQAYBgAbDgAYAQAZAwA4CAAZAQAcBwAZAQA4BgAICQA4AQAZBgAYAQAZBQAYAQAZDQA4AQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAZAQAYAwAbAQAZBAAbAQAYAQAZAgA4AQAcMAAYAQAcAwA4AQAZAwAbCwAYAQAZAQA4BgAICQA4AQAZBgAYAQAZBQAYAQAZDQA4AQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AwAZAQAdBAAZAQAdAQAZAQAcAQAZAgA4AQAZAQAYBgAbFQAYBgAbDgAYAQAZAwA4AQAZDgAYAQAZAQA4BgAICQA4AQAZAgAbAgAYAQAbAQAYAQAZAgAbAgAYAQAbAQAZDQA4AQA5AwAAFAAoCgAABQAIAQAAAQA5EQA4AQAZMAAYAQAZAwA4AQAZAwAbCAAYAgAbAQAYAQAZAQA4BgAICQA4BAAZAQAdBAAZAQAdBAAZDQA4AQA5AwAAEAAoAQAqAwAoCgAABQAIAQAAAQA5EQA4AQAZBQAYBgAbFwAYBgAbCAAYAQAZAwA4BAAZAQAdBgAZAQAdBAAZAQA4BgAIJAA4AQA5AwAAFAAoCgAABQAIAQAAAQA5EQA4AQAZMAAYAQAZFAA4BgAIJAA4AQA5AwAAFAAoBQAAAQACBAAABQAIAQAAAQA5EQA4BQAZAQAcCAAZAQAcCQAZAQAcCQAZAQAcCQAZAQAcBQAZFAA4BgAIJAA4AQA5AwAAFAAoCgAABQAIAQAAAQA5EQA4AQAZAQAYAQAbBAAYAgAbAQAZAgAbBQAYAgAbAQAZAQAbBwAYAQAbAQAZAQAYAQAbBQAYAgAbAQAZAgAbBQAYAgAbAQAZFAA4KgAIAQA5AwAAFAAoCgAABQAIAQAAAQA5AgA4AQA6DgA4AQAZCAAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZBgA4BgAZAQAdCAAZAQAdBgAZIgAIAQA5AwAAFAAoCgAABQAIAQAAAQA5EQA4AQAZCAAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZBgA4AQAZAgAbEAAYAgAbAQAZIgAIAQA5AQAAAQACAQAAFAAoCgAABQAIAQAAAQA5EQA4AQAZCAAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZBgA4AQAdAgAbEAAYAgAbAQAZIgAIAQA5AwAAFAAoCgAABQAIAQAAAQA5EQA4AQAZAQAbBQAYAgAbAQAZBgAYAgAbAQAYAQAZAgAbBAAYAgAbAQAYAQAZAQAbBgAYAgAbAQAZBgAYAgAbAQAYAQAZBgA4AQAZBAAbEAAYAQAZIgAIAQA5AwAAFAAoCgAABQAIAQAAAQA5EQA4DQAZAQAdCgAZAQAcCgAZAQAdDgAZAgA4BAAIAQAZBAAbDgAYAQAbAQAYAQAZIgA4AQA5AwAABAAoAQAqDwAoCgAABQAIAQAAAQA5AwA4BgAZAQAdCAAZAQAdBgAZBAA4KAAYBAAICwAZAQAcCgAZIgA4AQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAZAQAYAgAbBgAYAQAZAgAbBwAYAQAbAQAZBAA4AQAYAQAZIwAYAQAZAgAYBAAIAQAcFAAYAQAZIgA4AQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAdAQAYAgAbBgAYAQAZAgAbCAAYAQAZBAA4KAAYBAAIAQAZFAAYAQAZIgA4AQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAZCQAYAQAZCgAYAQAZBAA4KAAYBAAICwAZAQAcCgAZBAA4AwAZAQAdBAAZAQAdAwAZEgA4AQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAZCQAYAQAZCgAYAQAZBAA4BAAYIAAABAAYBAAIAQAZAQAbBAAYAgAbDQAYAQAZBAA4AQAZBAAbBQAYAQAbAQAZBwA4AQA6CgA4AQA5AwAADQAoAQAqBgAoCgAABQAIAQAAAQA5AwA4AQAZCQAYAQAZCgAYAQAZBAA4BAAYIAAABAAYBAAIAQAZBQAYAgAbDQAYAQAZBAA4AQAdAQAYAwAbBgAYAQAZEgA4AQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAZCQAYAQAZCgAYAQAZBAA4BAAYIAAABAAYBAAIAQAZBAAbDQAYAgAbAQAYAQAZBAA4AQAZCgAYAQAZEgA4AQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAZCQAYAQAZCgAYAQAZBAA4BAAYIAAABAAYBAAIAQAZBAAbDQAYAgAbAQAYAQAZBAA4AQAcCgAYAQAcEgA4AQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAZCQAYAQAZCgAYAQAZBAA4BAAYIAAAAwAYAQAaBAAIBgAZAQAdCAAZAQAdBgAZBAA4AQAZCgAYAQAZEgA4AQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAZCQAYAQAZCgAYAQAZBAA4BAAYIAAABAAYBAAIGgA4AQAZBwAYAgAbAQAYAQAZEgA4AQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAZCQAYAQAZCgAYAQAZBAA4BAAYIAAABAAYBAAIGgA4AwAZAQAdBAAZAQAdAwAZAwA4AQA6DgA4AQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAZBgAYAgAbAQAYAQAZCAAYAgAbAQAZBAA4BAAYIAAABAAYBAAIBgAZAQAdCAAZAQAdBgAZIgA4AQA5AwAAFAAoAQACCQAABQAIAQAAAQA5AwA4AQAZAgAbBAAYAwAbAQAZAgAbBgAYAgAbAQAZBAA4AQAYAQAZAgAYIAAABAAYBAAIAQAZAQAYBgAbDAAYAQAbAQAZDAA4AwA7EwA4AQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4BQAZAQAcCgAZAQAcBQAZBAA4BAAYIAAABAAYBAAIAQAdAQAYBgAbDQAYAQAZGwAoAgArBQAoAQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAcFAAYAQAcBAA4BAAYDwAAAQACEAAABAAYBAAIAQAZEgAYAgAbAQAZHwAoAgArAQAoAQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAZFAAYAQAZBAA4BAAYIAAABAAYBAAIAQAZEgAYAgAbAQAZHwAoAgArAQAoAQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4BQAZAQAcCgAZAQAcBQAZBAA4BAAYIAAAAQAYAQAZAgAYBAAICwAZAQAcCgAZFwAoAwArCAAoAQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAZAgAbBgAYAQAbAQAZAQAYAgAbBQAYAgAbAQAZBAA4BAAYIAAABAAYBAAIAQAcFAAYAQAZIgAoAQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAZAgAbBwAYAQAZCAAYAgAbAQAZBAA4BAAYIAAABAAYBAAIAQAZFAAYAQAZIgAoAQA5AwAABwAoAQAqDAAoCgAABQAIAQAAAQA5AwA4AQAZCQAYAQAZCgAYAQAZBAA4BAAYIAAABAAYBAAICwAZAQAcCgAZIgAoAQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAZCQAYAQAZCgAYAQAZBAA4BAAYIAAABAAYBAAIAQAZAQAYAQAbAQAYAgAbDwAYAQAZFQAoAwAZAQAdBAAZAQAdAwAZAQAoAQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAZCQAYAQAZCgAYAQAZBAA4BAAYIAAABAAYBAAIAQAZAwAYAgAbDwAYAQAZFQAoAQAZAwAbBgAYAQAbAQAZAQAoAQA5AwAAFAAoCgAABQAIAQAAAQA5AwA4AQAZCQAYAQAZCgAYAQAZBAA4BAAYAQACHwAABAAYBAAIAQAZAgAbDQAYBAAbAQAYAQAZAQAoBAAZAQAdBAAZAQAdBAAZBgAoAQAdAgAbCAAYAQAZAQAoAQA5AwAAFAAoCAAAAQACAQAABQAIAQAAAQA5AwA4AQAZCQAYAQAZCgAYAQAZBAA4BAAYIAAABAAYBAAIAQAZAgAbDQAYBAAbAQAYAQAZAQAoAQAZAQAYAwAbAQAYAQAbAQAZAQAYAQAbAQAYAgAbAQAZBgAoAQAZAgAbBQAYAwAbAQAZAQAoAQA5AwAAFAAoCgAABQAIAQAABAA4AQAZCQAYAQAZCgAYAQAZBAA4KAAYBAAIBgAZAQAdCAAZAQAdBgAZAQAoAQAdBgAYAQAZBQAYAQAZBgAoBgAZAQAcBQAZAQAoAQA5AwAAFAAoCgAABQAIAQAABAA4AQAZCQAYAQAZCgAYAQAZBAA4AQAYAQAZIwAYAQAZAgAYBAAIFgA4AQAoAQAZBgAYAQAZBQAYAQAZBgAoAQAcCgAYAQAcAQAoAQA5AwAAFAAoCgAACgAIAQAZCQAYAQAZCgAYAQAZBAA4KAAYBAAICgA4BAAICAA4AQAoAQAZBgAYAQAZBQAYAQAZBgAoAQAZCgAYAQAZAQAoAQA5AwAAFAAoCgAACgAIAQAZBgAYAgAbAQAYAQAZAgAbCAAYAQAZBAA4KAAYBAAICgA4BAAICAA4AQAoAQAcBgAYAQAcBQAYAQAcBgAoBgAZAQAcBQAZAQAoAQA5AwAAEQAoAQAqAgAoCgAACgAIAQAZAgAbBAAYAgAbAQAYAQAZAgAbBgAYAQAbAQAYAQAZAQA4BQAZAQAcBwAZAQAdBgAZAgA4BAAZAQAdAQAZAQAcAgAZAQAdBAAZFQA4BAAICAA4AQAoAQAZBgAYAQAZBQAYAQAZBgAoAQAZAQAYAQAbCAAYAQAZAQAoAQA5AwAAFAAoCgAACgAIBgAZAQAdCAAZAQAdBgAZAQA4AQAZAgAbBgAYAQAbAQAZAgAbBQAYAQAbAQAZAgA4AQAZAwAbAwAYAQAZAwAbAgAYAQAZFQA4BAAICAA4AQAoAQAZBgAYAQAZBQAYAQAZBgAoAQAZAwAYAgAbBQAYAQAZAQAoAQA5AwAAFAAoCgAAIAAIAQA4AQAdCQAYAQAZCAAYAQAZAgA4AQAdBgAYAQAZBQAYAQAZCAA4AQA6DAA4BAAICAA4AQAoAQAZAgAbAgAYAgAbAQAZBQAbAQAZBgAoAQAZBQAbAgAYAgAbAQAYAQAZAQAoAQA5AwAAFAAoCgAABQAIAQAAGwA4AQAZCQAYAQAZCAAYAQAZAgA4AQAZBgAYAQAZBQAYAQAZFQA4BAAICAA4AQAqBAAZAQAdBAAZAQAdBAAZBgAoAwAZAQAdBAAZAQAdAwAZAQAoAQA5AwAAFAAoCgAABQAIAQAAGwA4AQAZCQAYAQAZCAAYAQAZAgA4AQAZBgAYAQAZBQAYAQAZBgA4DwA5BAAJCAA5EgApEAAoAQA4AwAAFAAoBQAAAQACBAAABQAIAQAAGwA4AQAcCQAYAQAcCAAYAQAcAgA4AQAcBgAYAQAcBQAYAQAcFQA4BAAIKwA4AwAAFAAoCgAABQAIAQAAGwA4AQAZCQAYAQAZCAAYAQAZAgA4AQAZBgAYAQAZBQAYAQAZFQA4BAAIKwA4AwAAFAAoCgAABQAIAQAAGwA4AQAZCQAYAQAZCAAYAQAZAgA4AQAZBgAYAQAZBQAYAQAZFQA4BAAIKwA4IQAABQAIHAAAAQAZAgAbBAAYAgAbAQAYAQAZAgAbBAAYAgAbAQAZAgAAAQAZBQAbAQAYAQAZAgAYAgAbAQAYAQAZFQAABAAITAAABQAIHAAABQAZAQAdBwAZAQAdBgAZAgAABAAZAQAdBAAZAQAdBAAZFQAABAAILgAA",
	"oAAAEAAgUAAiUAAgUAAiUAAgUAAiQAAgEAAAUgAQTgAAUgAQTgAAUgAQTgAAUgAQTgAAUgAQTgAAUgAQPgAAHgAoHAAABQAINQAASgAoAQAABAADFwAABQAINQAASgAoAQAABAADDwAAAwADBQAABQAIAwAAAgADMAAARwAoAQAqAgAoHAAABQAIAwAAAgADMAAASgAoHAAABQAINQAASgAoHAAABQAINQAAMgAoAQAqFwAoBAAAAQACFwAABQAINQAASgAoHAAABQAIIQAABAAZAQAdBAAZAQAdBAAZBgAABQAoAQAqRAAoCAAABAAZAQAdBgAZAQAdBAAZBAAABQAIAwAABQAZAQAdBwAZAQAdBgAZCgAAAQAZDAAYAQAZBgAASgAoCAAAAQAZBwAYAQAZBgAYAQAZBAAABQAIAwAAAQAZCQAYAQAZCAAYAQAZCgAAAQAdDAAYAQAZBgAASgAoCAAAAQAdBwAYAQAZBgAYAQAZBAAABQAIAwAAAQAdCQAYAQAZCAAYAQAZCgAAAQAZDAAYAQAZBQAAAQACSgAoCAAAAQAZBwAYAQAZBgAYAQAZBAAABQAIAwAAAQAZCQAYAQAZCAAYAQAZCgAABwAZAQAcBgAZBgAANwAoAQAqEgAoCAAAAQAZBwAYAQAZBgAYAQAZBAAABQAIAwAAAQAZCQAYAQAZCAAYAQAZCgAAAQAcDAAYAQAcBgAAGgAoAQAqLwAoCAAAAQAcBwAYAQAcBgAYAQAcBAAABQAIAwAAAQAcCQAYAQAcCAAYAQAcCgAAAQAZDAAYAQAZBgAASgAoCAAAAQAZBwAYAQAZBgAYAQAZBAAABQAIAwAAAQAZCQAYAQAZCAAYAQAZBAADBgAABwAZAQAcBgAZBgAAQQAoAQAqCAAoCAAAAQAZBwAYAQAZBgAYAQAZBAAABQAIAwAAAQAZCQAYAQAZCAAYAQAZBAADBgAAAQAZDAAYAQAZBgAASgAoCAAAAQAZBwAYAQAZBgAYAQAZBAAABQAIAwAAAQAZCQAYAQAZCAAYAQAZCgAAAQAZDAAYAQAZBQAAAQACSgAoCAAABAAZAQAdBgAZAQAdBAAZBAAABQAIAwAABQAZAQAdBwAZAQAdBgAZCgAAAQAZDAAYAQAZBgAADwAoAQAqIAAoAQAqGQAoHAAABQAIIQAABAAZAQAdBAAZAQAdBAAZBgAASgAoHAAABQAINQAALAAoDAAABAAZAQAdBAAZAQAdBAAZCQAAAQACFAAAAgA4BQAIBwA4BAA7FgA4FAAAJwAoAQAqBAAoDAAAAQAZAQAYAgAbBwAYAgAbAQAZHgAAAgA4BQAIBwA4BAA7FgA4FAAALAAoDAAAAQAdDAAYAQAZHgAAAgA4BQAIAwA4BAA7GgA4FAAALAAoDAAAAQAZAwAbBwAYAQAbAQAYAQAZHgAAAgA4BQAIAwA4BAA7EQA4BAA7BQA4FAAALAAoDAAABwAZAQAcBgAZHgAAAgA4BQAIGAA4BAA7BQA4EQAAAQACAgAALAAoDAAAAQAcDAAYAQAcAgAAAgAZAgAdAgAZFgAAAgA4BQAIDQA4BAA7EAA4FAAALAAoDAAAAQAZDAAYAQAZAgAAAQAZAQAbAQAYAgAbAQAZCAAAAQACDQAAAgA4BQAIDQA4BAA7EAA4FAAALAAoDAAABwAZAQAcBgAZAgAAAQAdBAAYAQAZFgAAAgA4BQAIIQA4EAAAMAAIBwAAAQACBAAAAQAZAwAbCQAYAQAZAgAAAQAcBAAYAQAZFgAAAgA4BQAIGgA4BAA7AwA4EAAAMAAIDAAAAQAZDAAYAQAZAgAAAQAZAQAYAgAbAQAYAQAZEAAAAQACBQAAAgA4BQAIAQA4AgA7FwA4BAA7AwA4EAAAMAAIDAAAAQAZAwAbBgAYAgAbAQAYAQAZAgAAAgAZAgAdAgAZFgAAAgA4BQAIEQA4AgA7DgA4EAAAMAAIDAAABAAZAQAdBAAZAQAdBAAZHgAAAgA4BQAIIQA4EAAAMAAIOgAABQAIDgAAAgADBgAAAgADQwAABgAIGgAAAQACHwAABQAIDgAAAgADSwAAogAIBAAAjwAIBAALCQAIBAAAjwAIBAALCQAIBAAAnAAIBAAAnAAIBAAAnAAIJAAABQAIEwAABQAIGAAAAgADIwAABAAIGAAABgAIJAAABQAIEwAABQAIGAAAAgADIwAABAAIEwAAAQACBAAABgAIJAAABQAIEwAABQAIAQAADQAZAQAdFQAZAQAdDgAZAQAAAwAZAQAdAgAZAQAdAwAZAwAIGAAABgAIJAAABQAIEwAABQAIAQAAAQAZAgAbBQAYAQAbAQAZAQAYAgAbBQAYAQAbAQAZAQAYAgAbBgAYAQAZAgAbBgAYAQAbAQAZAQAYAgAbBAAYAgAbAQAZAQAAAQAZAQAYAQAbAQAYAQAZAgAbAgAYAQAZAwAIGAAABgAIBwAAAQACCAAABAAZAQAdBgAZAQAdBAAZBAAABQAIAwAABAAZAQAdBgAZAQAdBAAZBQAIAQAAAQAdCAAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZAQAAAQAdAwAYAQAZBAAYAQAZAwAIGAAABgAIEAAAAQAZBwAbAQAYAwAbAQAYAgAbAQAZBAAABQAIAwAAAQAZAQAYAgAbCQAYAgAbAQAZBQAIAQAAAQAZCAAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZAQAAAQAZAwAYAQAZBAAYAQAZAwAIBgAZAQAdCAAZAQAdBgAZAgAABgAIEAAAAQAdBwAbBwAYAQAZBAAABQAIAwAAAQAdDgAYAQAZBQAIAQAAAQAZCAAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZAQAAAQAZAwAYAQAZBAAYAQAZAwAIAQAZAwAbBgAYAQAZAgAbBQAYAwAbAQAZAgAABgAIEAAAAQAZBwAbAwAYBAAbAQAZBAAABQAIAwAAAQAZAwAbCQAYAQAbAQAYAQAZBQAIAQAAAQAZAgAbBQAYAQAbAQAZAgAbBQAYAQAbAQAYAQAZAgAbBQAYAgAbAQAZAgAbBgAYAQAbAQAZAgAbBQAYAQAbAQAYAQAZAQAAAQAZAwAYAQAZBAAYAQAZAwAIAQAdCQAYAQAZCgAYAQAZAgAABgAIEAAACAAZAQAcBwAZBAAABQAIAwAACAAZAQAcBwAZBQAIAQAABQAZAQAcCAAZAQAcCQAZAQAcCQAZAQAcCQAZAQAcBQAZAQAAAQAZAwAYAQAZBAAYAQAZAwAIAQAZCQAYAQAZCgAYAQAZAgAABgAIEAAAAQAcDgAYAQAcBAAABQAIAwAAAQAcDgAYAQAcBQAIAQAAAQAZBQAYBgAbBgAYBgAbAgA4AQAABAADBAAABgADCAAAAQAZAQAAAQAZAwAYAQAcBAAYAQAcAwAIAQAZCQAYAQAZCgAYAQAZAgAABgAIEAAAAQAZDgAYAQAZBAAABQAIAwAAAQAZDgAYAQAZBQAIAQAAAQAZEQAYBgAbAgA4AQAABAADCQAABAADAQAAAwADAQAAAQAZAQAAAQAZAwAbAQAZAQAbAQAYAQAbAQAYAQAZAwAIAQAZCQAYAQAZCgAYAQAZAgAABgAIEAAACAAZAQAcBwAZBAAABQAIAwAACAAZAQAcBwAZBQAIAQAAAQAZBQAYBgAbBgAYBgAbAgA4AQAABAADBAAABgADAQAAAgADBQAAAQAZAQAAAwAZAQAdAgAZAQAdAwAZAwAIAQAZCQAYAQAZCgAYAQAZAgAABgAIEAAAAQAZAQAYAgAbCAAYAwAbAQAZBAAABQAIAwAAAQAZAwAbCwAYAQAZBQAIAQAAAQAZFwAYAgA4FwAAAQAZCgAABAAIAQAZAwAbAwAYAgAbAQAYAQAZAQAbBwAYAgAbAQAZAgAABgAICgAAAQACBQAAAQAZDgAYAQAZBAAABQAIAwAAAQAZDgAYAQAZBQAIAQAAAQAZAQAYBgAbEAAYAgA4AwAABgADDgAAAQAZCgAABAAIBQAZAQAcCgAZAQAcBQAZAgAABgAIEAAAAQAZBAAbCAAYAQAbAQAYAQAZBAAABQAIAwAAAQAZAwAbCAAYAgAbAQAYAQAZBQAIAQAAAQAZFwAYAgA4BAADAwAAAwADDQAAAQAZCgAABAAIAQAcFAAYAQAcAgAABgAIEAAABAAZAQAdBgAZAQAdBAAZBAAABQAIAwAABAAZAQAdBgAZAQAdBAAZBQAIAQAAAQAcAwAYBgAbDgAYAgA4BAADAwAACQADBwAAAQAcCgAABAAIAQAZFAAYAQAZAgAABgAIJAAABQAIEwAABQAIAQAAAQAZFwAYAgA4BAADAwAAAwADDQAAAQAZCgAABAAIBQAZAQAcCgAZAQAcBQAZAgAABgAIBAAAIAAoBQAIAwAoEAAABQAIAQAAAQAZAQAYBgAbEAAYAgA4BgADEQAAAQAZCgAABAAIAQAZAgAbBwAYAQAZAQAYAwAbBQAYAQAbAQAZAgAABgAIBAAADAAoBAAZAQAdBAAZAQAdBAAZBgAoBQAIAwAoEAAABQAIAQAAAQAZFwAYAgA4FwAAAQAZCgAABAAIAQAZCQAYAQAZCgAYAQAZAgAABgAIBAAADAAoAQAZAgAbBAAYAQAZBQAbAQAZBgAoBQAIAwAoEAAABQAIAQAAAQAZMAAYAQAZCgAABAAIAQAZCQAYAQAZCgAYAQAZAgAABgAIAwAAAQACDAAoAQAdBgAYAQAZBQAYAQAZBgAoBQAIAwAoEAAABQAIAQAAAQAZMAAYAQAZCgAABAAIAQAZCQAYAQAZCgAYAQAZAgAABgAIBAAADAAoAQAZBgAYAQAZBQAYAQAZBgAoBQAIAwAoEAAABQAIAQAABQAZAQAcCAAZAQAcCQAZAQAcCQAZAQAcCQAZAQAcBQAZCgAABAAIAQAZCQAYAQAZCgAYAQAZAgAABgAIBAAADAAoAQAZBgAYAQAZBQAYAQAZBgAoBQAIAwAoEAAABQAIAQAAAQAZAQAYAQAbBAAYAgAbAQAZAgAbBQAYAgAbAQAZAQAbBwAYAQAbAQAZAQAYAQAbBQAYAgAbAQAZAgAbBQAYAgAbAQAZCgAABAAIAQAZCQAYAQAZCgAYAQAZAgAABgAIBAAADAAoAQAcBgAYAQAcBQAYAQAcBgAoBQAIAwAoEAAABQAIAQAAAQAZCAAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZCgAABAAIAQAZAwAbAwAYAwAbAQAZAgAbBgAYAgAbAQAZAgAABgAIBAAADAAoAQAZBgAYAQAZBQAYAQAZBgAoBQAIAwAoEAAABQAIAQAAAQAZCAAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZCgAABAAIBgAZAQAdCAAZAQAdBgAZAgAABgAIBAAABAAoAQAqBwAoAQAZBgAYAQAZBQAYAQAZBgAoBQAIAwAoEAAABQAIAQAAAQAZCAAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZCQAYAQAZCgAABAAIGAAABgAIBAAADAAoAQAZBgAbAQAZAQAbAgAYAgAbAQAZBgAoBQAIAwAoEAAABQAIAQAAAQAZAQAbBQAYAgAbAQAZBgAYAgAbAQAYAQAZAgAbBAAYAgAbAQAYAQAZAQAbBgAYAgAbAQAZBgAYAgAbAQAYAQAZCgAABAAIGAAABgAIBAAADAAoBAAZAQAdBAAZAQAdBAAZBgAoBQAIAwAoEAAABQAIAQAADQAZAQAdFQAZAQAdDgAZCgAAAwAIAQALAgADFgAABgAIBAAAIAAoBQAIAwAoEAAABQAIPQAABAAIBAAABAAZAQAdBAAZAQAdBAAZAQAAAQADBAAABgAIBAAALQAICwAABQAIPQAABAAIBAAAAQAZAgAbBAAYAQAZBQAbAQAZBgAABgAIBAAALQAICwAABQAIPQAABAAIBAAAAQAdAgAbBAAYAQAZBQAYAQAZBgAABgAIBAAALQAICwAABQAIGwAABAADGAAABAADAgAABAAIBAAAAQAZBgAYAQAZBQAYAQAZBgAABgAIBAAALQAICwAABQAIAwAABAADFAAABAADGAAABAADAgAABAAIBAAAAQAZBgAYAQAZBQAYAQAZBgAABgAIBAAABQAIBAAZAQAdBAAZAQAdBAAZGgAIAQAAAgAZAQAdAgAZAQAdAgAZAgAABQAIAwAABAADFAAABAADGAAABAADAgAABAAIBAAAAQAcBgAYAQAcBQAYAQAcBgAABgAIBAAABQAoAQAZAQAYAgAbAQAYAgAbAQAZAwAbAgAYAQAZCwAoAwAZAQAdBAAZAQAdAwAZBAAAAQAZAQAYAQAbAgAYAgAbAQAZAgAABQAIAwAABAADNgAABAAIBAAAAQAZBgAYAQAZBQAYAQAZBgAABgAIBAAABQAoAQAdBgAYAQAZBQAYAQAZCwAoAQAZAQAYAQAbBgAYAgAbAQAZBAAAAQAdBAAYAgAbAQAZAgAABQAIPQAABAAIBAAAAQAZBgAYAQAZAwAYAgAbAQAZBgAABgAIBAAABQAoAQAZBgAYAQAZBQAYAQAZCwAoAQAdCgAYAQAZBAAAAQAcBgAYAQAZAgAABQAIDgAABAADGgAABAADDQAABAAIBAAAAQAZBgAbAQAZAQAbAgAYAgAbAQAZBgAABgAIAgAAAQACAQAABQAoAQAZBgAYAQAZBQAYAQAZCwAoAQAZCgAYAQAZBAAAAQAZBQAbAQAYAQAZAgAABQAIDgAABAADGgAABAADDQAABAAIBAAABAAZAQAdBAAZAQAdBAAZBgAABgAIBAAABQAoAQAcBgAYAQAcBQAYAQAcCwAoAQAcCgAYAQAcBAAAAgAZAQAdAgAZAQAdAgAZAgAABQAIDgAABAADGgAABAADDQAABAAIFQAAAQACAgAABgAIBAAABQAoAQAZBgAYAQAZBQAYAQAZCwAoAQAZAwAbBwAYAQAZDgAABQAIPQAABAAIGAAABgAIBAAABQAoAQAZBgAYAQAZBQAYAQAZBQAoAQAqBQAoAQAZAwAbBgAYAQAbAQAZDgAABQAIJgAAAQACFgAABAAIGAAABgAIBAAABQAoAQAZAwAbAQAYAQAbAQAYAQAZAgAYAgAbAQAYAQAZCwAoAwAZAQAdBAAZAQAdAwAZDgAABQAIBwAAAQACNQAABAAIGAAABgAIBAAABQAoBAAZAQAdBAAZAQAdBAAZFQAoBAAAAQACCwAABQAIPQAABAAIGAAABgAIBAAAKAAoEAAABQAIFgAAAQACJgAABAAIGAAABgAIBAAAKAAoEAAABQAIPQAABAAIGAAABgAIBAAA",
	"tAAAEAAgUAAiZAAgUAAiZAAgUAAiVAAgEAAAUgAQYgAAUgAQYgAAUgAQYgAAUgAQYgAAUgAQYgAAUgAQpgAACAAIdwAABAADMQAACAAIdwAABAADDwAAAwADDQAAAgADEAAACAAIBgAAAQACGQAAAQACeQAAAgADEAAACAAIZwAAAQACRAAACAAIMwAAAQACTwAAAQACHAAAAQACCwAACAAIEgAAAQACNAAAAQACKgAAAQACHwAAAQACGQAACAAIrAAACAAIWAAAVgAzBAAIsAAzBAAIrgAzCAAIrAAzCAAIrAAzAgALBgAIrAAzAgALBgAIrAAzCAAIrAAzCAAIWAAzDwAoRQAzCAAIWAAzDwAoRQAzBAAIBAALWAAzDwAoRQAzBAAIBAALWAAzDwAoRQAzBAAIBAALWAAzDwAoRQAzCAAIDAAARAAoCAAzDwAoRQAzCAAIDAAARAAoCAAzBwAoAQAqBwAoRQAzCAAIDAAARAAoCAAzDwAoRQAzCAAIDAAARAAoCAAzDwAoRQAzCAAIDAAAAQAqHgAoAQAqJAAoCAAzDwAoRQAzCAAIDAAARAAoCAAzDwAoRQAzCAAIDAAARAAoCAAzDwAoRQAzCAAIDAAARAAoCAAzDwAoRQAzCAAIDAAARAAoCAAzDwAoRQAzCAAIDAAARAAoCAAzDwAoRQAzCAAIDAAARAAoCAAzDwAoRQAzCAAIDAAARAAoCAAzDwAoRQAzCAAIDAAACQAoAQAqOgAoCAAzCQAoAQAqBQAoRQAzCAAIDAAALQAoAQAqFgAoCAAzDwAoRQAzCAAIDAAARAAoCAAzDwAoRQAzCAAIDAAARAAoCAAzDwAoRQAzCAAIDAAARAAoCAAzDwAoRQAzCAAIDAAARAAoCAAzDwAoRQAzCAAIDAAAFQAoAQAqLgAoCAAzDwAoRQAzCAAIDAAARAAoCAAzDwAoRQAzCAAIDAAARAAoCAAzDwAoRQAzCAAIDAAARAAoCAAzBAAoAQAqCgAoRQAzCAAIDAAARAAoCAAzDwAoRQAzCAAIDAAARAAoCAAzDwAoRQAzCAAIDAAAPAAoAQAqBwAoCAAzDwAoRQAzLgAIKgAoCAAzDwAoRQAzLgAIKgAoCAAzDwAoRQAzMQAIJwAACAAzDwAoRQAAMQAIIgAABQAILgAALgA4EAAIBAAZAQAdBgAZAQAdBAAZEQAIAQA4IQAABQAIDAAABQAZAQAdBwAZAQAdBgAZDgAAAQA4AwAZAQAdBAAZAQAdAwAZBAA4DAAZAQAdEgAZAQAdDAAZAQA4AQAZBwAbAQAZAwAbAQAYAgAbAQAZDAA4BQAIAQA4IQAABQAIDAAAAQAZAQAYAQAbAgAYAgAbDAAYAQAZDgAAAQA4AQAZAQAYAQAbAgAYAQAZAgAbAgAYAQAbAQAZBAA4AQAZAgAbBAAYAQAbAQAZAQAYAgAbBAAYAQAbAQAZAQAYAgAbBAAYAQAZAgAbBQAYAQAbAQAZAQAYAgAbAwAYAgAbAQAZAQA4AQAdAQAbBgAYAQAZBgAYAQAZDAA4BQAIBQAZAQAdBgAZAQAdBQAZEAAABQAIAQAAAQACCgAAAQAdBAAYAgAbDAAYAQAZDgAAAQA4AQAdBAAYAQAZBQAYAQAZBAA4AQAdBwAYAQAZCAAYAQAZBwAYAQAZCAAYAQAZCAAYAQAZAQA4AQAZBwAYAQAZBgAYAQAZDAA4BQAIAQAZAwAbDQAYAQAZAgAABAAZAQAdBAAZAQAdBAAZBQAIDAAAAQAZAwAbDAAYAgAbAQAYAQAZDgAAAQA4AQAZBAAYAQAZBQAYAQAZBAA4AQAZBwAYAQAZCAAYAQAZBwAYAQAZCAAYAQAZCAAYAQAZAQA4AQAZBwAYAQAZBgAYAQAZDAA4BQAIAQAdEAAYAQAZAgAAAQAZAwAbAwAYAQAZBQAbAQAZBQAICAAABAAICgAZAQAcCQAZDwAIAQAZBAAYAQAZBQAYAQAZBAA4AQAZBwAYAQAZCAAYAQAZBwAYAQAZCAAYAQAZCAAYAQAZAQA4AQAcBwAYAQAcBgAYAQAcDAA4BQAIAQAZEAAYAQAZAgAAAQAdBgAYAQAZBQAYAQAZBQAICAAABAAIAQAcEgAYAQAcDwAIAQAZBAAYAQAZBQAYAQAZBAA4AQAZAgAbBAAYAQAbAQAZAgAbBAAYAQAbAQAYAQAZAgAbAwAYAgAbAQAZAgAbBQAYAQAbAQAZAgAbBAAYAQAbAQAYAQAZAQA4AQAZBwAYAQAZBgAYAQAZDAA4BQAIAQAZAwAbCgAYAgAbAQAYAQAZAgAAAQAZBgAYAQAZBQAYAQAZBQAICAAABAAIAQAZEgAYAQAZDwAIAQAZBAAYAQAZBQAYAQAZBAA4BAAZAQAcCAAZAQAcBwAZAQAcCAAZAQAcCAAZAQAcBAAZAQA4AQAZBwAYAQAZBgAYAQAZDAA4BQAICQAZAQAcCAAZAgAAAQAZBgAYAQAZBQAYAQAZBQAICAAABAAICgAZAQAcCQAZDwAIAQAZBAAYAQAZBQAYAQAZBAA4AQAZBAAYBgAbFAAYBgAbBgAYAQAZAQA4AQAZAgAbAQAYBAAbAQAZBQAbAQAYAQAZDAA4BQAIAQAcEAAYAQAcAgAAAQAcBgAYAQAcBQAYAQAcBQAICAAABAAIAQAZAgAbDQAYAwAbAQAZDwAIAQAZBAAYAQAZBQAYAQAZBAA4AQAZIQAYBQAbAQAYAgAbAQAYAQAZAQA4BAAZAQAdBgAZAQAdBAAZDAA4BQAIAQAZEAAYAQAZAgAAAQAZBgAYAQAZBQAYAQAZBQAIBAAAAQACBwAAAQAZAgAbEAAYAQAZAQAABQAICAAAAQA4AQAZBAAYAQAcBQAYAQAcBAA4AQAZBAAYBgAbFAAYBgAbAwAYAgAbAQAYAQAZBQAIGAA4BQAICQAZAQAcCAAZAgAAAQAZBgAYAQAZBQAYAQAZBQAIDAAAAQAZAgAbDgAYAQAbAQAYAQAZAQAABQAICAAAAQA4AQAZAQAYAwAbAQAZBAAbAQAYAQAZBAA4AQAZKgAYAQAZBQAIGAA4BQAIAQAZAgAbDgAYAQAZAgAAAQAZBQAbAQAYAQAZAgAYAwAbAQAZBQAIDAAABQAZAQAdBwAZAQAdBgAZAQAABQAICAAAAQA4AwAZAQAdBAAZAQAdAwAZBAA4AQAZAQAYBgAbEgAYBgAbCwAYAQAZBQAIGAA4BQAIAQAZEAAYAQAZAgAABAAZAQAdBAAZAQAdBAAZBQAIIQAABQAICAAAEQA4AQAcKgAYAQAcBQAIGAA4BQAIAQAZEAAYAQAZEAAABQAIDwAAAgADBAAAAgADAwAAAQADBgAABQAIAgADAgAAFQAIAQAZAQAYBgAbEgAYBgAbCwAYAQAZBQAIGAA4BQAIAQAZAwAbCgAYAwAbAQAZEAAABQAIDwAAAgADBAAAAgADBwAAAQADAgAABQAIBAAAFQAIAQAZKgAYAQAZBQAIGAA4BQAIBQAZAQAdBgAZAQAdBQAZEAAABQAIIQAABQAIBAAAFQAIAQAZBAAYBgAbFAAYBgAbBgAYAQAZBQAIDgA4BAAZAQAdBAAZAQAdBAAZAQAIAQA4IQAABQAIDQAABAAZAQAdBgAZAQAdBAAZBAAABQAIBAAAFQAIAQAZKgAYAQAZBQAIDgA4AQAZAgAbAQAYAwAbAQAZAQAYBAAbAQAZMAAIBQAAAQAZAwAbAgAYAgAbAQAZAQAYAgAbAgAYAQAbAQAZAwAABAAZAQAdBAAZAQAdBAAZBQAIAgAZAQAdAgAZAQAdAgAZBAAIBAAZAQAcCAAZAQAcBwAZAQAcCAAZAQAcCAAZAQAcBAAZBQAIDgA4AQAdBgAYAQAZBQAYAQAZMAAIBQAAAQAdBwAYAQAZBgAYAQAZAwAAAQAZAQAYAQAbAgAYAgAbAQAZAQAbAQAYAwAbAQAZBQA4AQAZAQAYAgAbAQAYAgAbAQAZBAA4AQAZAQAYAQAbAwAYAgAbAQAZAgAbBAAYAgAbAQAZAQAbBQAYAQAbAQAZAQAYAQAbBAAYAgAbAQAZAgAbBAAYAgAbAQAZBQAIDgA4AQAZBgAYAQAZBQAYAQAZMAAIBQAAAQAZBwAYAQAZBgAYAQAZAwAAAQAdBAAYAgAbAQAZBQAYAQAZBQA4AQAdBgAYAQAZBAA4AQAZBwAYAQAZCAAYAQAZBwAYAQAZCAAYAQAZCAAYAQAZBQAIAQA4AgAZAgAdAgAZBwA4AQAZBgAYAQAZBQAYAQAZBgAIAwAZAQAdAgAZAQAdAwAZIAAIBQAAAQAZBwAYAQAZBgAYAQAZAwAAAQAZBgAYAQAZBQAYAQAZBQA4AQAcBgAYAQAZBAA4AQAZBwAYAQAZCAAYAQAZBwAYAQAZCAAYAQAZCAAYAQAZBQAIAQA4AQAZBAAbAQAZBwA4AQAcBgAYAQAcBQAYAQAcBgAIAQAZAQAYAgAbAgAYAwAbAQAZIAAIBQAAAQAcBwAYAQAcBgAYAQAcAwAAAQAZBgAYAQAZBQAYAQAZBQA4AQAZAwAbAQAYAQAbAQAYAQAZBAA4AQAZBwAYAQAZCAAYAQAZBwAYAQAZCAAYAQAZCAAYAQAZBQAIAQA4AQAdBAAYAQAZBwA4AQAZBgAYAQAZBQAYAQAZAQAIAQA4BAAAAQAdBQAYAwAbAQAZEwAABQAIDQAAAQAZBwAYAQAZBgAYAQAZAwAAAQAcBgAYAQAcBQAYAQAcBQA4AgAZAQAdAgAZAQAdAgAZBAA4AQAZAQAbBAAYAgAbAQAZBQAYAgAbAQAYAQAZAgAbAgAYAgAbAQAYAQAZAQAbBQAYAgAbAQAZBQAYAgAbAQAYAQAZBQAIAQA4AQAcBAAYAQAZBwA4AQAZBgAYAQAZBQAYAQAZAQAIAQA4BAAAAQAZCAAYAQAZBwAAAwAZAQAdBAAZAQAdAwAZBQAIDQAAAQAZBQAYAgAbAQAZAgAbBAAYAQAZAwAAAQAZBgAYAQAZBQAYAQAZEQA4DAAZAQAdEgAZAQAdDAAZBQAIAQA4AQAZBAAbAQAZBwA4AQAZAQAbAwAYAgAbAQAZAgAbAQAYAgAbAQAZAQAIAQA4BAAAAQAcCAAYAQAcBwAAAQAZBQAbAQAZBAAbAQAZBQAIDQAAAQAZAQAbBAAYAgAbAQAZAgAbAQAYAwAbAQAZAwAAAQAZBgAYAQAZAgAYAgAbAQAYAQAZPQA4BQAIAQA4AgAZAgAdAgAZBwA4BAAZAQAdBAAZAQAdBAAZAQAIAQA4BAAAAQAZCAAYAQAZBwAAAQAdBQAYAQAZBAAYAQAZBQAIDQAABAAZAQAdBgAZAQAdBAAZAwAAAQAZBQAbAQAYAQAZBAAbAQAYAQAZDwA4AQA6LQA4BQAIGAA4BQAIAQA4BAAAAQAZAQAbBQAYAQAbAQAYAQAZBwAAAQAZBQAYAQAZBAAYAQAZBQAIIAAABAAZAQAdBAAZAQAdBAAZOQA4AQA6AwA4BQAICQA4AwA7BQA4AgA7BQA4BQAIAQA4BAAAAwAZAQAdAgAZAQAdAwAZBwAAAQAZBQAYAQAZBAAYAQAZBAAIAQALAwADBQAAmwAIAQAcBQAYAQAcBAAYAQAcBAAIBAALoAAIAQAZBQAYAQAZBAAYAQAZqAAIAQAZBQAYAQAZBAAYAQAZLAAIAgALegAIAQAZAQAbAgAYAgAbAQAZBAAbAQAZHgAIAgALDAAIAgALMAAIAwAZAQAdBAAZAQAdAwAZPgAIAwAZAQAdBAAZAQAdAwAZDQAIEQAAAgADEwAAAQACDAAAAQACBQAABQAZAQAdBgAZAQAdBQAZBgAAAQAZAwAbBQAYAgAbAQAZFQAAAgADEwAAAQACZQAAAQAZBAAbBAAYAQAZAgAbBQAYAQAZBgAAAQAdCgAYAQAZFQAAAgADBAAAAgADQAAACAADBwAACAADBgAAAgADFAAAAQAdCAAYAQAZAgAbBQAYAQAZBgAAAQAZCgAYAQAZBwAAAQACCAAAAgADCQAAAgADcwAAAQAZCAAYAQAZBwAYAQAZAgAAAQACAwAAAQAcCgAYAQAcEAAAAgADKAAAAQACEQAAAQACDQAAAQACFAAAAQACIAAAAQAcCAAYAQAcBwAYAQAcBgAAAQAZCAAYAgAbAQAZCAAACAADDAAACAADbAAAAQAZBQAYAgAbAQAYAQAZBwAYAQAZBgAAAQAZAQAbBwAYAgAbAQAZkAAAAQAZAgAbAwAYAgAbAQAYAQAZAgAbAQAYBAAbAQAZBgAAAwAZAQAdBAAZAQAdAwAZkAAABQAZAQAdBgAZAQAdBQAZaQAA",
	"pQAAEAAgUAAiVQAgUAAiVQAgUAAiRQAgEAAAUgAQUwAAUgAQUwAAUgAQUwAAUgAQUwAAUgAQUwAAUgAQQwAAGAAoKAAAKQAIAwAAUQAoBwAABAADHQAAKQAIAwAAUQAoBwAABAADDwAAAwADCwAAKQAIAwAAUQAoKAAAKQAIAwAAUQAoTAAABQAIAwAAEQAoAQAqPwAoTAAABQAIAwAAUQAoTAAABQAIAwAAPgAoAQAqEgAoBAAABAAZAQAdBAAZAQAdBAAZKgAAAwAZAQAdBAAZAQAdAwAZBAAABQAIAwAAUQAoBAAAAQAZDAAYAQAZKgAAAQAZCgAYAQAZBAAABQAIAwAAKgAoAQAqJgAoBAAAAQAdDAAYAQAZKgAAAQAdCgAYAQAZBAAABQAIAwAAUQAoBAAAAQAZDAAYAQAZDAAABAAZAQAdBgAZAQAdBAAZDgAAAQAZCgAYAQAZBAAABQAIAwAAUQAoBAAABwAZAQAcBgAZDAAAAQAZBwAYAQAZBgAYAQAZDgAABgAZAQAcBQAZBAAABQAIAwAARwAoAQAqCQAoBAAAAQAcDAAYAQAcDAAAAQAdBwAYAQAZBgAYAQAZDgAAAQAcCgAYAQAcBAAABQAIAwAAUQAoBAAAAQAZDAAYAQAZDAAAAQAZBwAYAQAZBgAYAQAZDgAAAQAZCgAYAQAZBAAABQAIAwAABwAoAQAqSQAoBAAABwAZAQAcBgAZDAAAAQAcBwAYAQAcBgAYAQAcDgAABgAZAQAcBQAZBAAABQAIAwAAUQAoBAAAAQAZDAAYAQAZAgAABAADBgAAAQAZBwAYAQAZBgAYAQAZBAAAAgADAgAAAgADBAAAAQAZCgAYAQAZBAAABQAIAwAAUQAoBAAAAQAZDAAYAQAZAgAABAADBgAAAQAZBwAYAQAZBgAYAQAZCAAAAgADBAAAAQAZCgAYAQAZBAAABQAIAwAAHQAoAQAqMwAoBAAAAQAZDAAYAQAZDAAABAAZAQAdBgAZAQAdBAAZDgAAAQAZCgAYAQAZBAAABQAIAwAAUQAoBAAABAAZAQAdBAAZAQAdBAAZKgAAAwAZAQAdBAAZAQAdAwAZBAAABQAIAwAATgAoAQAqAgAoTAAABQAIAwAAUQAoKAAACQAZAQAdDgAZAQAdCQAZAgAABQAIAwAABgAoAQAqSgAoKAAAAQAZBwAbEgAYAgAbBQAYAQAZAgAABQAIAwAANAAoAQAqHAAoKAAAAQAdAgAYAQAbAgAYAQAbAgAYAQAbCAAYAQAbAgAYAQAbCwAYAQAZAgAABQAIAwAAUQAoKAAAAQAZAQAbAQAYAQAbAgAYAQAbAgAYAQAbCAAYAQAbAgAYAQAbCwAYAQAZAgAABQAIAwAAUQAoKAAAAQAZAgAYAQAbAgAYAQAbAgAYAQAbCAAYAQAbAgAYAQAbCwAYAQAZAgAABQAIAwAAUQAoKAAAAQAZAgAYAQAbAgAYAQAbAgAYAQAbCAAYAQAbAgAYAQAbBAAYAgAbBQAYAQAZAgAABQAIAwAAQAAoAQAqEAAoKAAAAQAcIAAYAQAcAgAABQAIAwAAUQAoKAAAAQAZIAAYAQAZAQAAAQACBQAIAwAAUQAoFwAAAQACEAAAAQAZIAAYAQAZAgAABQAIAwAAJQAoAQAqKwAoKAAABgAZAQAcFgAZAQAcBAAZAgAABQAIAwAAUQAoKAAAAQAZAgAbBgAYAgAbDgAYAQAZAgAbBQAYAQAZAgAABQAIPAAAEwAoAQAqBAAoKAAAAQAZAgAbBgAYAgAbDgAYAQAZBAAYAwAbAQAZAgAABQAIYQAAAgADDgAAAQACCgAAAQAZGAAYAQAZBwAYAQAZAgAABQAIYQAAAgADGQAACQAZAQAdAgAZAQAcCwAZAQAdCQAZAgAABQAIoAAABQAIMwAACQAIZAAABQAIMwAAQAEIBAALoQAIBAALAwAIBAALoQAIBAALUgEIIAAAAgADBQAAAgADAQAABQAIVQAABAAIIAAAAQACIwAAAgADAQAABQAIVQAABAAIRwAABQAIAQAAAwAZAQAdAgAZAQAdAwAZAgAACwAZAQAdEAAZAQAdCwAZCgAABgAZAQAdCAAZAQAdBgAZBAAIIQAABAAZAQAdBAAZAQAdBAAZBwAABQAZAQAdBgAZAQAdBQAZBAAIAQAAAQAZAQAYAQAbAQAYAQAZAgAbAgAYAQAZAgAAAQAZAgAbAwAYAQAbAQAZAQAYAgAbAwAYAQAbAQAZAQAYAgAbBAAYAQAZAgAbBAAYAQAbAQAZAQAYAgAbAgAYAgAbAQAZCgAAAQAZAQAYAgAbAwAYAwAbAQAZAgAbBQAYAwAbAQAZBAAICwAAAQACFQAAAQAZAwAbCQAYAQAZBwAAAQAZAwAbDQAYAQAZBAAIAQAAAQAdAwAYAQAZBAAYAQAZAgAAAQAdBgAYAQAZBwAYAQAZBwAYAQAZBwAYAQAZBwAYAQAZCgAAAQAdCQAYAQAZCgAYAQAZBAAIIQAAAQAdDAAYAQAZBwAAAQAdEAAYAQAZBAAIAQAAAQAZAwAYAQAZBAAYAQAZAgAAAQAZBgAYAQAZBwAYAQAZBwAYAQAZBwAYAQAZBwAYAQAZCgAAAQAZCQAYAQAZCgAYAQAZBAAIIQAAAQAZAwAbBgAYAgAbAQAYAQAZBwAAAQAZEAAYAQAZBAAIAQAAAQAZAwAYAQAZBAAYAQAZAgAAAQAZBgAYAQAZBwAYAQAZBwAYAQAZBwAYAQAZBwAYAQAZCgAAAQAZCQAYAQAZCgAYAQAZBAAIIQAABwAZAQAcBgAZBwAAAQAZAwAbCgAYAgAbAQAYAQAZBAAIAQAAAQAZAwAYAQAZBAAYAQAZAgAAAQAZAgAbAwAYAQAbAQAZAgAbAwAYAQAbAQAYAQAZAgAbAwAYAgAbAQAZAgAbBAAYAQAbAQAZAgAbAwAYAQAbAQAYAQAZCgAAAQAZCQAYAQAZCgAYAQAZBAAIIQAAAQAcDAAYAQAcBwAACQAZAQAcCAAZBAAIAQAAAQAZAwAYAQAZBAAYAQAZAgAABAAZAQAcBgAZAQAcBwAZAQAcBwAZAQAcBwAZAQAcBAAZCgAAAQAZCQAYAQAZCgAYAQAZBAAIFwAAAQACCQAAAQAZDAAYAQAZBwAAAQAcEAAYAQAcBAAIAQAAAQAZAwAYAQAcBAAYAQAZAgAAAQAZBQAYAwAbDQAYAwAbAwAYBgAbBQAYAQAZCgAAAQAZAgAbBAAYAgAbAQAYAQAZAgAbBgAYAgAbAQAZBAAIIQAABwAZAQAcBgAZBwAAAQAZEAAYAQAZBAAIAQAAAQAZAwAbAQAZAQAbAQAYAQAbAQAYAQAZAgAAAQAZHQAYBQAbAQAYAgAbAQAYAQAZCgAABQAZAQAcCgAZAQAcBQAZBAAIIQAAAQAZAgAbCgAYAQAZBwAACQAZAQAcCAAZBAAIAQAAAwAZAQAdAgAZAQAdAQAZAQAcAQAZAgAAAQAZBAAYBgAbEQAYBgAbAgAYAgAbAQAYAQAZCgAAAQAcFAAYAQAcBAAIIQAAAQAZDAAYAQAZBwAAAQAZAgAbDgAYAQAZBAAIDQAAAQAZBQAYAwAbBQAYAwAbDQAYAwAbBgAYAQAZCgAAAQAZFAAYAQAZIQAIBAAAAQAZAwAbBgAYAwAbAQAZBwAAAQAZEAAYAQAZBAAIDQAAAQAZAQAYBgAbDgAYCAAbCQAYAQAZCgAABQAZAQAcCgAZAQAcBQAZIQAIBAAABAAZAQAdBAAZAQAdBAAZAwAAAQACAwAAAQAZEAAYAQAZBAAIDQAAAQAcFQAYAgAbDwAYAQAZCgAAAQAZAgAbBAAYAwAbAQAZAQAYAwAbBAAYAgAbAQAZIQAIGQAAAQAZAwAbCgAYAwAbAQAZBAAIDQAAAQAZAQAYCgAbDgAYCQAbBAAYAQAZCgAAAQAZCQAYAQAZCgAYAQAZIQAIGQAABQAZAQAdBgAZAQAdBQAZBAAIDQAAAQAZHQAYAgAbBwAYAQAZCgAAAQAZCQAYAQAZCgAYAQAZIQAIKgAABQAIDQAAAQAZBAAYBgAbEQAYBgAbBQAYAQAZCgAAAQAZCQAYAQAZCgAYAQAZBAAILwAAHQAIDQAAAQAZJgAYAQAZCgAAAQAZCQAYAQAZCgAYAQAZBAAIAQAAAgAZAQAdAgAZAQAdAgAZFwAAAQACDgAAHQAIDQAABAAZAQAcBgAZAQAcBwAZAQAcBwAZAQAcBwAZAQAcBAAZCgAAAQAZCQAYAQAZCgAYAQAZBAAIAQAAAQAZAgAbBAAYAQAZJgAAHQAIDQAAAQAZAQAYAQAbAgAYAgAbAQAZAgAbAwAYAgAbAQAZAgAbBAAYAQAbAQAZAQAYAQAbAwAYAgAbAQAZAgAbAwAYAgAbAQAZCgAAAQAZAgAbBAAYAgAbAQAYAQAZAgAbBgAYAgAbAQAZBAAIAQAAAQAdBgAYAQAZJgAAHQAIDQAAAQAZBgAYAQAZBwAYAQAZBwAYAQAZBwAYAQAZBwAYAQAZCgAABgAZAQAdCAAZAQAdBgAZBAAIAQAAAQAcBgAYAQAZDwAAAQACLgAABQAIDQAAAQAZBgAYAQAZBwAYAQAZBwAYAQAZBwAYAQAZBwAYAQAZIAAABAAIAQAAAQAZBgAbAQAZGQAABAAZAQAdBAAZAQAdBAAZBwAABAAZAQAdBgAZAQAdBAAZBQAIDQAAAQAZBgAYAQAZBwAYAQAZBwAYAQAZBwAYAQAZBwAYAQAZIAAABAAIAQAAAgAZAQAdAgAZAQAdAgAZGQAAAQAZAQAYAQAbAgAYAgAbAQAZAQAYBAAbAQAZBwAAAQAZAgAbCQAYAwAbAQAZBQAIDQAAAQAZAQAbAwAYAgAbAQAZBAAYAgAbAQAYAQAZAgAbBAAYAQAbAQAZAQAbBAAYAgAbAQAZBAAYAgAbAQAYAQAZIAAABAAIIgAAAQAdBgAYAQAZBQAYAQAZBwAAAQAdDgAYAQAZBQAIDQAACwAZAQAdCAAZAQAcBwAZAQAdCwAZIAAABAAIIgAAAQAZBgAYAQAZBQAYAQAZBwAAAQAZAQAbCwAYAgAbAQAZBQAIAQA4WAAIGwA4BwAAAQAZBgAYAQAZBQAYAQAZBwAACAAZAQAcBwAZBQAIAQA4WAAIGwA4BwAAAQAcBgAYAQAcBQAYAQAcBwAAAQAcDgAYAQAcBQAIAQA4WAAIGwA4BwAAAQAZBgAYAQAZBQAYAQAZBwAAAQAZDgAYAQAZBQAIAQA4WAAIGwA4BwAAAQAZBgAYAQAZBQAYAQAZBwAACAAZAQAcBwAZBQAIBQA4BAAIDgA4BAAZAQAdBgAZAQAdBAAZLgA4BAAIGwA4BwAAAQAZBQAbAQAYAQAZBAAbAQAYAQAZBwAAAQAZAQAYAwAbCQAYAQAbAQAZBQAIBQA4BAAIDgA4AQAZAQAYAwAbCAAYAgAbAQAZBgA4AwAZAQAdBAAZAQAdAwAZBAA4AgAZAgAdAgAZEgA4BAAIEwA4AQA6BwA4BwAABAAZAQAdBAAZAQAdBAAZBwAAAQAZDgAYAQAZBQAIBQA4BAAIDgA4AQAdAgAYAgAbCAAYAgAbAQAZBgA4AQAZAQAYAQAbCAAYAQAZBAA4AQAZAgAbAgAYAQAZEgA4BAAIGwA4AgAAGgAoAQAZAgAbCgAYAgAbAQAZBQAIBQA4BAAIDgA4AQAZDgAYAQAZBgA4AQAdCgAYAQAZBAA4AQAdBAAYAQAZEgA4BAAIGwA4AgAAGgAoBAAZAQAdBgAZAQAdBAAZBQAIBQA4BAAIDgA4CAAZAQAcBwAZBgA4AQAZCgAYAQAZBAA4AQAcBAAYAQAZEgA4BAAIGwA4AgAAKgAoBQAIBQA4BAAIDgA4AQAcDgAYAQAcBgA4AQAcCgAYAQAcBAA4AQAZAQAbAQAYAgAbAQAZEgA4BAAIGwA4AgAAFgAoAQAqEwAoBQAIBQA4BAAIBAA4AQA6CQA4AQAZDgAYAQAZBgA4AQAZBgAYAwAbAQAYAQAZBAA4AgAZAgAdAgAZDQA4AQA6BAA4BAAIGwA4AgAAKgAoBQAIBQA4BAAIDgA4CAAZAQAcBwAZAgA4AQA6AwA4AQAZAgAbBAAYBAAbAQAZHAA4BAAICwA4AQA6DwA4AgAACQAoAQAqIAAoBQAIBQA4BAAIDgA4AQAZAQAYBAAbCQAYAQAZBgA4AwAZAQAdBAAZAQAdAwAZHAA4BAAIGwA4AgAAIAAoAQAqCQAoBQAIBQA4BAAIDgA4AQAZAQAYBAAbCQAYAQAZIAA4AQA6DQA4BAAIGwA4AgAAKgAoBQAIBQA4BAAIDgA4AQAZDAAYAQAbAQAYAQAZLgA4BAAIGwA4AgAAKgAoBQAIBQA4BAAICwA4AQA6AgA4BAAZAQAdBgAZAQAdBAAZEgA4AQA6GwA4BAAIGwA4AgAALQAoBwA4BAAIawA4AgAA"
]

# 나무 분산, 본당 더미 길, 반복 가구 정리로 실제 바뀐 옛 좌표만 기대값으로 적는다.
const SOUTH_CORRECTIONS: Array[Dictionary] = [
	{12500: 2, 12950: 0},
	{17339: 42, 17505: 42, 17679: 40, 17693: 40, 17707: 40, 17859: 42},
	{3063: 42, 3071: 42, 3235: 40, 3577: 42, 4090: 40, 4425: 42, 4604: 42, 4776: 40, 6804: 40, 7314: 42, 7494: 42, 7679: 0, 7828: 42, 7999: 40, 8675: 42, 8858: 42, 9026: 40, 9375: 0, 10544: 40, 11403: 40, 12600: 0, 13604: 42, 13777: 40, 13785: 42, 14119: 42, 14478: 0, 14968: 42, 15317: 40, 15489: 42, 16175: 0},
	{9508: 24, 9509: 24, 9510: 24, 9511: 24, 9512: 24, 9513: 24, 9520: 24, 9521: 24, 9522: 24, 9523: 24, 9524: 24, 9525: 24, 9526: 24, 9527: 24, 9528: 3, 9533: 3, 9534: 3, 9535: 3, 9536: 24, 9537: 24, 9538: 24, 9539: 24, 9540: 24, 9541: 24, 9542: 24, 9543: 24, 9544: 24, 9545: 24, 9546: 24, 9547: 24, 9548: 24, 9549: 24, 9550: 24, 9680: 24, 9681: 24, 9682: 24, 9683: 24, 9684: 24, 9685: 24, 9686: 24, 9687: 24, 9688: 3, 9690: 0, 9691: 0, 9692: 0, 9696: 24, 9697: 24, 9698: 24, 9699: 24, 9700: 24, 9701: 24, 9702: 24, 9703: 24, 9704: 24, 9705: 24, 9706: 24, 9707: 24, 9708: 24, 9709: 24, 9710: 24, 9828: 24, 9829: 24, 9830: 24, 9831: 24, 9840: 24, 9841: 24, 9842: 24, 9843: 24, 9844: 24, 9845: 24, 9846: 24, 9847: 24, 9848: 3, 9850: 0, 9851: 0, 9852: 0, 9856: 24, 9857: 24, 9863: 3, 9864: 0, 9865: 0, 9869: 24, 9870: 24, 9986: 27, 9987: 27, 9988: 27, 9989: 27, 9990: 27, 9991: 27, 9992: 27, 9993: 27, 10006: 24, 10007: 24, 10008: 3, 10009: 3, 10016: 24, 10017: 24, 10018: 3, 10019: 3, 10020: 3, 10021: 3, 10022: 3, 10023: 3, 10024: 3, 10025: 3, 10026: 3, 10027: 3, 10029: 24, 10030: 24, 10144: 24, 10145: 24, 10150: 27, 10151: 27, 10152: 27, 10153: 27, 10166: 24, 10167: 24, 10168: 3, 10169: 3, 10170: 3, 10176: 24, 10177: 24, 10180: 3, 10181: 3, 10186: 3, 10187: 3, 10188: 3, 10189: 24, 10190: 24, 10312: 56, 10313: 56, 10326: 24, 10327: 24, 10328: 56, 10329: 56, 10330: 0, 10331: 0, 10335: 0, 10336: 24, 10337: 24, 10340: 56, 10341: 56, 10349: 24, 10350: 24, 10466: 24, 10467: 24, 10468: 24, 10469: 24, 10470: 24, 10471: 24, 10472: 56, 10473: 56, 10486: 24, 10487: 24, 10488: 56, 10489: 56, 10490: 0, 10491: 0, 10495: 0, 10496: 24, 10497: 24, 10498: 0, 10499: 0, 10500: 56, 10501: 56, 10502: 0, 10503: 0, 10509: 24, 10510: 24, 10623: 27, 10624: 27, 10625: 27, 10626: 27, 10627: 27, 10628: 27, 10632: 27, 10633: 27, 10638: 27, 10639: 27, 10640: 27, 10641: 27, 10642: 27, 10643: 27, 10646: 24, 10647: 24, 10650: 0, 10651: 0, 10653: 3, 10654: 3, 10656: 24, 10657: 24, 10660: 3, 10661: 3, 10662: 3, 10663: 3, 10664: 3, 10665: 3, 10666: 3, 10667: 3, 10792: 27, 10793: 27, 10802: 27, 10803: 27, 10804: 27, 10805: 27, 10806: 27, 10807: 27, 10810: 0, 10811: 0, 10812: 0, 10814: 3, 10815: 3, 10816: 24, 10817: 24, 10820: 3, 10821: 3, 10952: 27, 10953: 27, 10966: 24, 10967: 24, 10968: 3, 10969: 3, 10973: 3, 10974: 3, 10975: 3, 10976: 24, 10977: 24, 10980: 3, 10981: 3, 11112: 27, 11113: 27, 11140: 27, 11141: 27, 11272: 27, 11273: 27, 11300: 27, 11301: 27},
	{},
	{9141: 24, 9152: 24, 9153: 24, 9159: 24, 9160: 24, 9165: 24, 9172: 24, 9173: 24, 9245: 24, 9246: 24, 9247: 24, 9267: 24, 9268: 24, 9584: 24, 9585: 24, 9774: 24, 9775: 24, 9803: 24, 9804: 24, 9808: 24, 9816: 24, 9817: 24, 9825: 24, 9832: 24, 10176: 24, 10177: 24, 10182: 24, 10183: 24, 10186: 24, 10187: 24, 10194: 24, 10195: 24, 10281: 24, 10283: 24, 10285: 24, 10320: 24, 10321: 24, 10400: 24, 10401: 24, 10586: 24, 10587: 24, 10739: 24, 10740: 24, 10741: 24, 11001: 24, 11002: 24, 11019: 24, 11020: 24, 11094: 24, 11095: 24, 11096: 24, 11853: 24, 11854: 24, 11942: 24, 11948: 24, 11953: 24, 11954: 24, 11956: 24, 11957: 24, 11962: 24, 11965: 24, 11972: 24, 11973: 24, 11977: 24, 11978: 24, 11991: 24, 11992: 24, 12001: 24, 12002: 24, 12351: 24, 12352: 24, 12353: 24, 12547: 24, 12550: 24, 12551: 24, 12554: 24, 12555: 24, 12556: 24, 12557: 24, 12567: 24, 12568: 24, 12605: 24, 12606: 24, 12622: 24, 12624: 24, 12629: 24, 12630: 24, 12897: 24, 12909: 24, 12910: 24, 13701: 24, 13702: 24, 13711: 24, 13735: 24, 13954: 24, 13969: 24, 13970: 24, 14052: 24, 14053: 24, 14064: 24, 14065: 24, 14464: 24, 14466: 24, 14467: 24}
]


func test_shift_preserves_each_original_south_cell_with_exact_corrections() -> void:
	for i in range(maps.size()):
		var g: FieldGrid = maps[i]["grid"]
		var raw: PackedByteArray = Marshalls.base64_to_raw(SOUTH_BEFORE[i])
		var at: int = 0
		var differences: int = 0
		for offset in range(0, raw.size(), 3):
			var count: int = int(raw[offset]) + int(raw[offset + 1]) * 256
			var value: int = int(raw[offset + 2])
			for _unused in range(count):
				# 열차 바로 위의 옛 맨 윗줄까지 칸 종류와 바닥을 대조한다.
				var expected: int = int(SOUTH_CORRECTIONS[i].get(at, value))
				var actual: int = g.solid[at + 45 * g.width] + g.floor[at + 45 * g.width] * 8
				if actual != expected:
					differences += 1
				at += 1
		assert_eq(at, g.width * (g.height - 45))
		assert_eq(differences, 0, maps[i]["place_id"])


func test_north_room_sizes_furnishing_stairwells_and_three_gates() -> void:
	for i in range(maps.size()):
		var d: Dictionary = maps[i]
		var plan: Dictionary = MAPS[i].NORTH
		var largest: int = -1
		var largest_area: int = -1
		var room_counts: Dictionary = {}
		for b: Dictionary in plan["buildings"]:
			var area: int = (b["rect"][2] - 2) * (b["rect"][3] - 2)
			if area > largest_area:
				largest_area = area
				largest = b["id"]
		for room: Dictionary in plan["rooms"]:
			var rr: Array = room["rect"]
			var r := Rect2i(rr[0], rr[1], rr[2], rr[3])
			assert_gte(r.size.x, 3)
			assert_gte(r.size.y, 3)
			assert_true(_korean_name(room["name"]))
			if room["level"] == 0:
				room_counts[room["building"]] = int(room_counts.get(room["building"], 0)) + 1
			var contents: int = 0
			var kinds: Dictionary = {}
			for p: Dictionary in d["props"]:
				if p.get("level", 0) == room["level"] and r.encloses(p["rect"]):
					contents += 1
					kinds[p["kind"]] = int(kinds.get(p["kind"], 0)) + 1
			for box: Dictionary in d["containers"].values():
				if box.get("level", 0) == room["level"] and r.has_point(box["cell"]):
					contents += 1
			assert_gt(contents, 0, room["name"])
			for kind: String in kinds:
				if kind != "shelf" and kind != "display_shelf":
					assert_lte(kinds[kind], 4, room["name"])
		assert_gte(int(room_counts.get(largest, 0)), 6)
		var gate_slots: int = 0
		for c: Vector2i in d["barricade_slots"]:
			if c.y >= 23 and c.y <= 42:
				gate_slots += 1
		assert_between(gate_slots, 4, 9)
		for lv in [-1, 0, 1, 2]:
			var lg: FieldGrid = d["levels"][lv]
			for c: Vector2i in lg.doors:
				assert_eq(lg.doors[c]["cell"], c)
			for c: Vector2i in lg.windows:
				assert_eq(lg.windows[c]["cell"], c)


func test_collapsed_roof_has_a_longer_clear_wooden_detour() -> void:
	var d: Dictionary = maps[3]
	var g: FieldGrid = d["grid"]
	var main: Rect2i = d["buildings"][0]["rect"]
	var start := Vector2i(62, 110)
	var end := Vector2i(111, 110)
	var outside: Dictionary = {}
	var quiet: Dictionary = {}
	for y in range(g.height):
		for x in range(g.width):
			var c := Vector2i(x, y)
			if not main.has_point(c):
				outside[c] = true
				quiet[c] = true
			elif g.floor_at(c) == F.GRAVEL:
				quiet[c] = true
	var short_path: PackedInt32Array = _distances(g, [start], false, outside)
	var long_path: PackedInt32Array = _distances(g, [start], false, quiet)
	assert_gte(short_path[g.index(end)], 0)
	assert_gte(long_path[g.index(end)] - short_path[g.index(end)], 28)
	assert_lte(long_path[g.index(end)] - short_path[g.index(end)], 34)
	for r: Rect2i in [Rect2i(76, 114, 22, 2), Rect2i(63, 104, 15, 2), Rect2i(96, 104, 15, 2)]:
		for c: Vector2i in _cells(r):
			assert_true(g.people_can_walk(c))
			assert_eq(g.floor_at(c), F.WOOD)


func test_north_shops_have_a_sales_room_storage_and_a_back_door() -> void:
	for i in range(maps.size()):
		var plan: Dictionary = MAPS[i].NORTH
		for b: Dictionary in plan["buildings"]:
			if not ["철물점", "기름 가게", "연료 상회 본관"].has(b["name"]):
				continue
			var front: Rect2i
			var storage: Rect2i
			for room: Dictionary in plan["rooms"]:
				if room["building"] != b["id"] or room["level"] != 0:
					continue
				var rr: Array = room["rect"]
				var r := Rect2i(rr[0], rr[1], rr[2], rr[3])
				if room["name"].contains("매장") or room["name"].contains("가게방"):
					front = r
				if room["name"].contains("창고"):
					storage = r
			assert_true(front.has_area())
			assert_true(storage.has_area())
			var counter: bool = false
			var stored: bool = false
			for p: Dictionary in maps[i]["props"]:
				if p.get("level", 0) != 0:
					continue
				if front.encloses(p["rect"]) and p["kind"] == "shop_counter":
					counter = true
				if storage.encloses(p["rect"]) and ["shelf", "barrel", "sack_pile", "coal_bin", "crate_stack", "pallet_stack"].has(p["kind"]):
					stored = true
			assert_true(counter, b["name"])
			assert_true(stored, b["name"])
			var faces: Dictionary = {}
			for door: Dictionary in plan["doors"]:
				if door["building"] == b["id"] and door["level"] == 0 and door["outer"]:
					faces[Vector2i(door["side"][0], door["side"][1])] = true
			assert_gte(faces.size(), 2, b["name"])


func test_entry_names_weights_and_first_entry() -> void:
	for n in range(1, 7):
		var d: Dictionary = load("res://game/world/maps/church_%02d.gd" % n).build()
		var ways: Array = d["entries"].keys()
		var named: Array = d["entry_names"].keys()
		var weighed: Array = d["entry_weights"].keys()
		ways.sort()
		named.sort()
		weighed.sort()
		assert_eq(named, ways)
		assert_eq(weighed, ways)
		assert_true(ways.has(d["first_entry"]))
		assert_eq(int(d["entry_levels"].get(d["first_entry"], 0)), 0, "첫 물결은 땅 위 길로 온다")
		assert_false(d.get("manholes", {}).has(d["first_entry"]), "첫 물결은 구멍이 아니라 길로 온다")
		var seen: Dictionary = {}
		var total := 0.0
		for way: String in ways:
			var way_name: String = d["entry_names"][way]
			assert_false(way_name.is_empty())
			assert_false(_roman_or_han(way_name), way_name)
			assert_false(seen.has(way_name), way_name)
			seen[way_name] = true
			assert_gte(float(d["entry_weights"][way]), 0.0)
			total += float(d["entry_weights"][way])
		assert_gt(total, 0.0)
		for b: Dictionary in d["buildings"]:
			assert_false(_roman_or_han(String(b["name"])), String(b["name"]))
		for id in d["containers"]:
			var box_name := String(d["containers"][id].get("name", ""))
			assert_false(_roman_or_han(box_name), box_name)
		for z in d.get("zone_names", {}):
			assert_false(_roman_or_han(String(d["zone_names"][z])), String(d["zone_names"][z]))


func _roman_or_han(text: String) -> bool:
	for i in range(text.length()):
		var c: int = text.unicode_at(i)
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 0x3400 and c <= 0x9FFF):
			return true
	return false
