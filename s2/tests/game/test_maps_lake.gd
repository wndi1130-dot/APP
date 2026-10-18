extends "res://addons/gut/test.gd"

const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const MAPS: Array = [
	preload("res://game/world/maps/lake_01.gd"),
	preload("res://game/world/maps/lake_02.gd"),
	preload("res://game/world/maps/lake_03.gd"),
	preload("res://game/world/maps/lake_04.gd"),
	preload("res://game/world/maps/lake_05.gd"),
	preload("res://game/world/maps/lake_06.gd"),
	preload("res://game/world/maps/lake_07.gd"),
	preload("res://game/world/maps/lake_08.gd"),
	preload("res://game/world/maps/lake_09.gd"),
]
const BASE_KEYS: Array[String] = [
	"grid", "levels", "stairs", "containers", "spots", "stoves", "entries",
	"buildings", "wagons", "train", "platform", "spawns", "labels", "trees",
	"low_blocks", "upper_rects", "train_cars", "lights", "manholes",
	"sewer_names", "manhole_levels", "entry_levels", "entry_gap", "unload",
]
const EXTRA_KEYS: Array[String] = [
	"place_id", "place_kind", "bands", "train_doors", "crossings",
	"barricade_slots", "interior_kind_slots", "zone_names", "props",
	"entry_names", "entry_weights", "first_entry",
]
const PROP_KINDS: Array[String] = [
	"fishing_platform", "pier_deck", "mooring_post", "shore_ice_heap",
	"frozen_reeds", "ice_cut_pool", "fishing_hole", "tip_up_flag",
	"ice_saw_frame", "ice_block_stack", "sunken_wheelhouse", "sunken_bow",
	"sunken_deck_section", "fallen_mast", "frozen_dinghy", "overturned_boat",
	"boat_on_blocks", "net_drying_rack", "net_pile", "fish_trap_stack",
	"fish_drying_frame", "fish_crate_stack", "cleaning_table", "buoy_line",
	"fish_hoist", "fuel_drum_group", "generator_unit", "fuel_tank",
	"ice_sled_load", "fish_truck", "snow_plow_tractor", "pallet_stack",
	"tool_bench", "firewood_stack", "snow_drift", "rubbish_pile",
	"dry_bush", "bare_willow",
]

const ASSEMBLY_CONTAINER_SUFFIXES: Array[String] = [
	"상자", "보관함", "묶음", "선반", "자재함", "궤", "찬장", "공구함", "책상", "침대", "옷장",
]
const ASSEMBLY_BAND_COVERS: Array[Vector2i] = [Vector2i(0, 4), Vector2i(4, 0), Vector2i(0, 4), Vector2i(4, 0), Vector2i(0, 4), Vector2i(4, 0), Vector2i(0, 4), Vector2i(0, 4), Vector2i(4, 0)]
const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
# The continuous blue ice is the exposed alternative to the marked shore road.
const ROUTE_FLOORS: Array[int] = [F.ROAD, F.GRAVEL, F.RAIL, F.PLATFORM, F.WOOD, F.ICE]
var _maps: Array[Dictionary] = []


func before_all() -> void:
	for script in MAPS:
		_maps.append(script.build())


func test_schema_names_and_nine_different_layouts() -> void:
	var comments: Dictionary = {}
	var latin := RegEx.new()
	latin.compile("[A-Za-z]")
	for index in range(_maps.size()):
		var data: Dictionary = _maps[index]
		var g: FieldGrid = data["grid"]
		var id: String = data["place_id"]
		assert_eq(id, "lake_%02d" % (index + 1))
		assert_eq(data["place_kind"], "lake")
		assert_eq(data.size(), BASE_KEYS.size() + EXTRA_KEYS.size(), id + " exact keys")
		for key in BASE_KEYS + EXTRA_KEYS:
			assert_true(data.has(key), id + " missing " + key)
		for key in data:
			assert_true(key in BASE_KEYS or key in EXTRA_KEYS, id + " unexpected " + str(key))
		assert_true(g.width >= 150 and g.width <= 180, id + " width")
		assert_true(g.height >= 90 and g.height <= 110, id + " height")
		var zones: Dictionary = _zones(g)
		assert_true(zones.size() >= 3 and zones.size() <= 6, id + " zones")
		assert_eq(data["zone_names"].get("", ""), "바깥")
		for key in zones:
			assert_true(data["zone_names"].has(key), id + " named zone " + key)
			assert_false(str(data["zone_names"].get(key, "")).is_empty())
		for name in data["zone_names"].values():
			assert_null(latin.search(name), id + " Korean zone name")
		for building in data["buildings"]:
			assert_null(latin.search(building["name"]), id + " Korean building name")
		for item in data["containers"].values():
			assert_null(latin.search(item["name"]), id + " Korean container name")
		for label in data["labels"]:
			assert_null(latin.search(label["text"]), id + " Korean label")
		assert_eq(data["interior_kind_slots"].size(), 1)
		assert_true(zones.has(data["interior_kind_slots"][0]["zone"]))
		assert_eq(data["interior_kind_slots"][0]["kinds"], ["empty", "raiders", "nest", "beasts"])
		var source: String = FileAccess.get_file_as_string(MAPS[index].resource_path)
		var first: String = source.get_slice("\n", 0).strip_edges()
		assert_true(first.begins_with("# 이 지도가 다른 판단을 만드는 것: "))
		assert_false(comments.has(first), id + " distinct decision")
		comments[first] = true
		assert_false(source.contains("sulehuf_map.gd"), id + " independent map")
		for other in range(1, 10):
			assert_false(source.contains("preload(\"res://game/world/maps/lake_%02d.gd\")" % other))
		for previous in range(index):
			var other_grid: FieldGrid = _maps[previous]["grid"]
			assert_false(g.solid == other_grid.solid and g.floor == other_grid.floor, id + " distinct grid")


func test_train_bands_doors_and_unloading() -> void:
	for data in _maps:
		var g: FieldGrid = data["grid"]
		var train: Rect2i = data["train"]
		assert_eq(train.size, Vector2i(80, 3))
		assert_true(train.position.x > 0 and train.position.y > 0)
		assert_true(train.end.x < g.width and train.end.y < g.height)
		assert_eq(data["train_cars"].size(), 5)
		for car in data["train_cars"]:
			var r: Rect2i = car["rect"]
			assert_eq(r.size, Vector2i(16, 3))
			assert_true(train.encloses(r))
			for c in _cells(r):
				assert_eq(g.solid_at(c), S.BLOCK)
		for side in ["upper", "lower"]:
			var band: Rect2i = data["bands"][side]
			assert_eq(band.size.x, 120)
			assert_true(band.size.y >= 20 and band.size.y <= 25)
			assert_true(_inside_rect(g, band))
			assert_true(band.position.x <= train.position.x and band.end.x >= train.end.x)
			assert_eq(band.end.y if side == "upper" else band.position.y, train.position.y if side == "upper" else train.end.y)
			assert_true(data["train_doors"][side].size() >= 2)
			var outward := Vector2i.UP if side == "upper" else Vector2i.DOWN
			for door: Vector2i in data["train_doors"][side]:
				assert_eq(door.y, train.position.y - 1 if side == "upper" else train.end.y)
				for depth in range(3):
					for lateral in range(-1, 2):
						assert_eq(g.solid_at(door + outward * depth + Vector2i(lateral, 0)), S.NONE, "3 by 3 door apron")
			var unload: Dictionary = data["spots"]["unload_" + side]
			assert_eq(unload["kind"], "unload")
			var apron: Rect2i = unload["zone_rect"]
			assert_true(band.encloses(apron))
			for c in _cells(apron):
				assert_true(g.people_can_walk(c), "unload stays open")


func test_arrivals_and_every_ground_cell_are_reachable() -> void:
	for data in _maps:
		var g: FieldGrid = data["grid"]
		var train_doors: Array = data["train_doors"]["upper"] + data["train_doors"]["lower"]
		var people: Dictionary = _flood(g, [train_doors[0]])
		var dead: Dictionary = _flood(g, train_doors, true)
		assert_true(data["entries"].size() >= 2)
		for key in data["entries"]:
			assert_true(data["entry_gap"].has(key), "gap for every entry")
			var gap: float = data["entry_gap"].get(key, 0.0)
			assert_true(gap > 0.0 and gap <= 3.0)
			assert_true(is_equal_approx(gap, 0.6) or (gap >= 2.0 and gap <= 3.0), "seconds per body")
			assert_false(data["entries"][key].is_empty())
			for c: Vector2i in data["entries"][key]:
				assert_false(_in_band(data, c))
				assert_true(dead.has(c), data["place_id"] + " dead can reach train from " + str(c))
		var missing: int = 0
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				if g.people_can_walk(c) and not people.has(c):
					missing += 1
		assert_eq(missing, 0, data["place_id"] + " all walkable ground from one train door")
		for key: String in data["spawns"]:
			if not key.begins_with("dead"):
				continue
			if key == "dead_levels":
				for row in data["spawns"][key]:
					assert_false(_in_band(data, row[0]), "initial dead outside bands")
			else:
				for c: Vector2i in data["spawns"][key]:
					assert_false(_in_band(data, c), "initial dead outside bands")


func test_blocking_all_slots_preserves_open_sides_and_floor_routes() -> void:
	for data in _maps:
		var g: FieldGrid = data["grid"]
		var blocked: Dictionary = {}
		for c: Vector2i in data["barricade_slots"]:
			assert_true(g.people_can_walk(c))
			blocked[c] = true
		var doors: Array = data["train_doors"]["upper"] + data["train_doors"]["lower"]
		var reached: Dictionary = _flood(g, [doors[0]], false, blocked)
		var marked: Dictionary = _flood(g, doors, false, {}, Rect2i(), false, true)
		for zone_id in _zones(g):
			assert_true(_reaches_zone(g, reached, zone_id), data["place_id"] + " open side to " + zone_id)
			assert_true(_reaches_zone(g, marked, zone_id), data["place_id"] + " visible route to " + zone_id)
		# Slot count follows actual connected gaps, not a fixed count per map.
		var remaining: Dictionary = blocked.duplicate()
		while not remaining.is_empty():
			var first: Vector2i = remaining.keys()[0]
			var group: Dictionary = _slot_group(first, remaining)
			assert_true(group.size() >= 2 and group.size() <= 3, "two or three slots per gap")
			var xs: Array[int] = []
			var ys: Array[int] = []
			for c: Vector2i in group:
				xs.append(c.x)
				ys.append(c.y)
				remaining.erase(c)
			xs.sort()
			ys.sort()
			assert_true(xs[0] == xs[-1] or ys[0] == ys[-1], "straight gap")
			var a := Vector2i(xs[0], ys[0])
			var b := Vector2i(xs[-1], ys[-1])
			var along := Vector2i.RIGHT if ys[0] == ys[-1] else Vector2i.DOWN
			assert_false(g.people_can_walk(a - along), "gap touches first solid mass")
			assert_false(g.people_can_walk(b + along), "gap touches second solid mass")


func test_short_cover_has_a_visible_fallback_and_varied_shapes() -> void:
	for index in range(_maps.size()):
		var data: Dictionary = _maps[index]
		var g: FieldGrid = data["grid"]
		var lake_side: String = MAPS[index].LAKE_SIDE
		var village_side: String = "lower" if lake_side == "upper" else "upper"
		var village_covers: Array[Rect2i] = _outdoor_covers(data, data["bands"][village_side])
		var ice_covers: Array[Rect2i] = _outdoor_covers(data, data["bands"][lake_side])
		assert_true(village_covers.size() >= 3 and village_covers.size() <= 5)
		assert_true(ice_covers.size() <= 2)
		var nearby: int = 0
		var shapes: Dictionary = {}
		for rect in village_covers:
			assert_true(maxi(rect.size.x, rect.size.y) >= 2 and maxi(rect.size.x, rect.size.y) <= 6)
			shapes[rect.size] = true
			var close: bool = false
			for door: Vector2i in data["train_doors"][village_side]:
				for c in _cells(rect):
					if absi(c.x - door.x) + absi(c.y - door.y) <= 12:
						close = true
			if close:
				nearby += 1
		assert_true(nearby >= 2, "two useful covers within twelve cells")
		assert_true(shapes.size() >= 2, "cover directions and shapes differ")
		assert_true(_longest_low_run(g) <= 10)
		var low_cells: Dictionary = {}
		for rect: Rect2i in data["low_blocks"]:
			for c in _cells(rect):
				assert_eq(g.solid_at(c), S.LOW)
				low_cells[c] = true
		for stove in data["stoves"]:
			if int(stove.get("level", 0)) == 0:
				low_cells[stove["cell"]] = true
		var rendered_blocks: Dictionary = {}
		for car in data["train_cars"]:
			for c in _cells(car["rect"]):
				rendered_blocks[c] = true
		for wagon in data["wagons"]:
			for c in _cells(wagon["rect"]):
				rendered_blocks[c] = true
		for c: Vector2i in data["trees"]:
			rendered_blocks[c] = true
		var invisible_low: int = 0
		var invisible_block: int = 0
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				if g.solid_at(c) == S.LOW and not low_cells.has(c):
					invisible_low += 1
				if g.solid_at(c) == S.BLOCK and g.building_at(c) < 0:
					if not rendered_blocks.has(c) or (x < 14 and y < 14):
						invisible_block += 1
		assert_eq(invisible_low, 0, "LOW always rendered")
		assert_eq(invisible_block, 0, "no invisible wall or accidental water tower")


func test_deep_store_has_open_entrances_loop_and_furnished_pockets() -> void:
	for data in _maps:
		var g: FieldGrid = data["grid"]
		var building: Dictionary = _deep_building(data)
		assert_false(building.is_empty())
		if building.is_empty():
			continue
		var rect: Rect2i = building["rect"]
		var entrances: Array[Vector2i] = _exterior_openings(g, rect)
		assert_true(entrances.size() >= 1 and entrances.size() <= 2)
		for c in entrances:
			assert_true(g.solid_at(c) == S.NONE or g.doors[c]["state"] in ["open", "broken"])
			var normal: Vector2i = _outward(rect, c)
			var tangent := Vector2i(1, 0) if normal.x == 0 else Vector2i(0, 1)
			var along: int = c.x - rect.position.x if normal.x == 0 else c.y - rect.position.y
			var length: int = rect.size.x if normal.x == 0 else rect.size.y
			assert_true(float(along) >= float(length) * 0.3 and float(along) <= float(length) * 0.7, "middle of wall")
			var clear: int = 0
			for depth in range(1, 5):
				for lateral in range(-2, 3):
					if g.solid_at(c + normal * depth + tangent * lateral) == S.NONE:
						clear += 1
			assert_eq(clear, 20, "5 by 4 entrance apron")
			assert_true(g.line_clear(c + normal * 4, c), "entrance visible from approach")
		var distance: Dictionary = _flood(g, entrances, false, {}, rect)
		var deepest: int = -1
		var shallow: int = 0
		var deep: int = 0
		for item in data["containers"].values():
			if int(item.get("level", 0)) != 0:
				continue
			if rect.has_point(item["cell"]):
				deep += 1
				assert_true(distance.has(item["cell"]))
				deepest = maxi(deepest, int(distance.get(item["cell"], -1)))
			else:
				shallow += 1
		assert_true(shallow > 0 and deep > 0)
		assert_true(deepest >= 25, data["place_id"] + " deep supply walk")
		var rooms: Array = _rooms(g, rect)
		assert_true(rooms.size() >= 4, "three storage rooms plus circulation")
		var pockets: int = 0
		for room: Dictionary in rooms:
			var door_count: int = 0
			for c: Vector2i in g.doors:
				if rect.has_point(c) and _touches(room, c):
					door_count += 1
			if door_count == 1:
				pockets += 1
				assert_true(_furnished(data, room, 0))
		assert_true(pockets >= 2, "at least two furnished dead ends")
		# Cut the top corridor at its first inner wall: the bottom route must survive.
		var cut: Dictionary = {}
		var middle: int = rect.position.x + floori(float(rect.size.x) / 2.0)
		for y in range(rect.position.y + 1, rect.end.y - 1):
			var c := Vector2i(middle, y)
			if not g.people_can_walk(c):
				break
			cut[c] = true
		var a := rect.position + Vector2i(1, 1)
		var b := Vector2i(rect.end.x - 2, rect.position.y + 1)
		assert_false(cut.is_empty())
		assert_true(_flood(g, [a], false, cut, rect).has(b), "circulation loop around storage rooms")


func test_buildings_and_other_levels_have_furnished_rooms_and_working_stairs() -> void:
	for data in _maps:
		var g: FieldGrid = data["grid"]
		for item in data["containers"].values():
			var item_grid: FieldGrid = data["levels"][int(item.get("level", 0))]
			assert_true(item_grid.people_can_walk(item["cell"]), item["name"] + " accessible supply cell")
		for spot in data["spots"].values():
			if spot["kind"] == "salvage":
				assert_true(g.people_can_walk(spot["cell"]), "accessible salvage cell")
		assert_true(data["levels"].has(-1))
		var has_upper: bool = false
		for level in data["levels"]:
			if int(level) > 0:
				has_upper = true
		assert_true(has_upper)
		for building in data["buildings"]:
			var rect: Rect2i = building["rect"]
			var interior_area: int = (rect.size.x - 2) * (rect.size.y - 2)
			var walls: int = 0
			for c in _cells(Rect2i(rect.position + Vector2i.ONE, rect.size - Vector2i(2, 2))):
				if g.solid_at(c) == S.WALL:
					walls += 1
			var rooms: Array = _rooms(g, rect)
			if interior_area > 60:
				assert_true(walls > 0, "internal wall")
				assert_true(rooms.size() >= 2, "multiple rooms")
			if interior_area > 300:
				assert_true(rooms.size() >= 4, "large building circulation and three rooms")
			for room: Dictionary in rooms:
				assert_true(_furnished(data, room, 0), building["name"] + " ground furniture")
			var windows: int = 0
			for c: Vector2i in g.windows:
				if rect.has_point(c):
					windows += 1
			assert_true(windows > 0, building["name"] + " windows")
		for stair in data["stairs"]:
			var cell: Vector2i = stair["cell"]
			var low: FieldGrid = data["levels"][stair["low"]]
			var high: FieldGrid = data["levels"][stair["high"]]
			assert_eq(int(stair["high"]) - int(stair["low"]), 1)
			assert_true(low.people_can_walk(cell), "same-cell lower landing")
			assert_true(high.people_can_walk(cell), "same-cell upper landing")
		for level in data["levels"]:
			if int(level) == 0:
				continue
			var lg: FieldGrid = data["levels"][level]
			var stairs: Array[Vector2i] = []
			for stair in data["stairs"]:
				if stair["low"] == level or stair["high"] == level:
					stairs.append(stair["cell"])
			assert_false(stairs.is_empty())
			var reachable: Dictionary = _flood(lg, stairs)
			var missing: int = 0
			for y in range(lg.height):
				for x in range(lg.width):
					var c := Vector2i(x, y)
					if lg.people_can_walk(c) and not reachable.has(c):
						missing += 1
			assert_eq(missing, 0, "every room on a floor has stairs access")
			# A cellar corridor crossing building outlines is one connected room.
			var rooms: Array = _rooms(lg, Rect2i(0, 0, lg.width, lg.height))
			assert_true(rooms.size() >= 2, "at least two furnished rooms per added floor")
			for room: Dictionary in rooms:
				assert_true(_furnished(data, room, int(level)), "upstairs or cellar furniture")


func test_hill_house_and_hall_share_the_short_cellar_passage() -> void:
	var data: Dictionary = _maps[8]
	var g: FieldGrid = data["grid"]
	var cellar: FieldGrid = data["levels"][-1]
	var ends: Array[Vector2i] = []
	for stair in data["stairs"]:
		if stair["low"] != -1 or stair["high"] != 0:
			continue
		var building_id: int = g.building_at(stair["cell"])
		for building in data["buildings"]:
			if building["id"] == building_id and building["name"] in ["어장 큰 집", "마을 회관"]:
				ends.append(stair["cell"])
	assert_eq(ends.size(), 2, "a stair at each end of the passage")
	if ends.size() != 2:
		return
	var reached: Dictionary = _flood(cellar, [ends[0]])
	assert_true(reached.has(ends[1]), "underground alternative between the two houses")
	var distance: int = int(reached.get(ends[1], -1))
	assert_true(distance >= 12 and distance <= 20, "short usable cellar passage")


func test_crossings_asymmetry_and_every_screen_sized_window() -> void:
	for data in _maps:
		var g: FieldGrid = data["grid"]
		assert_true(data["crossings"].size() >= 1)
		for crossing in data["crossings"]:
			var allowed: Dictionary = {}
			for c: Vector2i in crossing["cells"]:
				allowed[c] = true
				assert_true(g.people_can_walk(c))
			assert_false(allowed.is_empty())
			if allowed.is_empty():
				continue
			assert_eq(_slot_group(crossing["cells"][0], allowed).size(), allowed.size())
			for mode in ["person", "zombie", "carrying", "wounded", "sled"]:
				assert_true(crossing["who"].get(mode, false))
		var train: Rect2i = data["train"]
		var matched: int = 0
		var occupied: int = 0
		for y in range(train.position.y):
			var reflected_y: int = train.position.y + train.end.y - 1 - y
			if reflected_y >= g.height:
				continue
			for x in range(g.width):
				var a: int = g.solid_at(Vector2i(x, y))
				var b: int = g.solid_at(Vector2i(x, reflected_y))
				if a in [S.WALL, S.LOW, S.BLOCK] or b in [S.WALL, S.LOW, S.BLOCK]:
					occupied += 1
					if a == b and a in [S.WALL, S.LOW, S.BLOCK]:
						matched += 1
		assert_true(occupied > 0 and float(matched) / float(maxi(1, occupied)) < 0.5, "asymmetric shores")
		var empty_windows: int = 0
		for kind in range(8):
			var prefix: PackedInt32Array = _uniform_floor_prefix(g, kind)
			for y in range(g.height - 19):
				for x in range(g.width - 29):
					if _rect_sum(prefix, g.width + 1, Rect2i(x, y, 30, 20)) == 600:
						empty_windows += 1
		assert_eq(empty_windows, 0, data["place_id"] + " no empty 30 by 20 window")


func test_props_are_named_in_bounds_visible_and_clear_of_protected_cells() -> void:
	for data in _maps:
		var g: FieldGrid = data["grid"]
		var protected_cells: Dictionary = {}
		for side in ["upper", "lower"]:
			var normal := Vector2i.UP if side == "upper" else Vector2i.DOWN
			for c: Vector2i in data["train_doors"][side]:
				for depth in range(3):
					for lateral in range(-1, 2):
						protected_cells[c + normal * depth + Vector2i(lateral, 0)] = true
		for c: Vector2i in data["barricade_slots"]:
			protected_cells[c] = true
		for entry in data["entries"].values():
			for c: Vector2i in entry:
				protected_cells[c] = true
		assert_true(data["props"].size() >= 40)
		for prop in data["props"]:
			for key in ["kind", "rect", "solid", "facing", "note"]:
				assert_true(prop.has(key))
			assert_true(prop["kind"] in PROP_KINDS)
			var rect: Rect2i = prop["rect"]
			assert_true(_inside_rect(g, rect))
			assert_true(rect.size.x > 0 and rect.size.y > 0)
			assert_true(prop["solid"] in ["low", "wall", "tree", "wagon", "none"])
			for c in _cells(rect):
				assert_false(protected_cells.has(c), prop["kind"] + " protected cell " + str(c))
			match prop["solid"]:
				"low":
					assert_true(data["low_blocks"].has(rect), "same render rectangle")
					for c in _cells(rect):
						assert_eq(g.solid_at(c), S.LOW)
				"wall":
					for c in _cells(rect):
						assert_eq(g.solid_at(c), S.WALL)
				"tree":
					assert_eq(rect.size, Vector2i.ONE)
					assert_true(data["trees"].has(rect.position))
					assert_eq(g.solid_at(rect.position), S.BLOCK)
				"wagon":
					var found: bool = false
					for wagon in data["wagons"]:
						if wagon["rect"] == rect:
							found = true
					assert_true(found)
					for c in _cells(rect):
						assert_eq(g.solid_at(c), S.BLOCK)


func test_continuous_lake_and_trees_on_land() -> void:
	for data in _maps:
		var g: FieldGrid = data["grid"]
		var seen: Dictionary = {}
		var largest: int = 0
		for y in range(g.height):
			for x in range(g.width):
				var start := Vector2i(x, y)
				if g.floor_at(start) != F.ICE or seen.has(start):
					continue
				var queue: Array[Vector2i] = [start]
				seen[start] = true
				var head: int = 0
				while head < queue.size():
					var c: Vector2i = queue[head]
					head += 1
					for direction in DIRS:
						var next: Vector2i = c + direction
						if g.inside(next) and g.floor_at(next) == F.ICE and not seen.has(next):
							seen[next] = true
							queue.append(next)
				largest = maxi(largest, queue.size())
		assert_true(float(largest) >= float(g.width * g.height) * 0.3, data["place_id"] + " one large lake")
		assert_true(data["trees"].size() >= 20 and data["trees"].size() <= 40)
		for c: Vector2i in data["trees"]:
			assert_ne(g.floor_at(c), F.ICE)
			assert_false(c.x < 14 and c.y < 14)
			assert_eq(g.solid_at(c), S.BLOCK)


func _flood(g: FieldGrid, starts: Array, for_dead: bool = false, blocked: Dictionary = {}, limit: Rect2i = Rect2i(), rooms_only: bool = false, marked: bool = false) -> Dictionary:
	var distance: Dictionary = {}
	var queue: Array[Vector2i] = []
	for c: Vector2i in starts:
		if _allowed(g, c, for_dead, blocked, limit, rooms_only, marked):
			if not distance.has(c):
				distance[c] = 0
				queue.append(c)
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for direction in DIRS:
			var next: Vector2i = c + direction
			if distance.has(next) or not _allowed(g, next, for_dead, blocked, limit, rooms_only, marked):
				continue
			distance[next] = int(distance[c]) + 1
			queue.append(next)
	return distance


func _allowed(g: FieldGrid, c: Vector2i, for_dead: bool, blocked: Dictionary, limit: Rect2i, rooms_only: bool, marked: bool) -> bool:
	if not g.inside(c) or blocked.has(c):
		return false
	if limit.size != Vector2i.ZERO and not limit.has_point(c):
		return false
	if rooms_only and g.solid_at(c) == S.DOOR:
		return false
	if marked and not (g.floor_at(c) in ROUTE_FLOORS):
		return false
	return g.dead_can_walk(c) if for_dead else g.people_can_walk(c)


func _rooms(g: FieldGrid, rect: Rect2i) -> Array:
	var rooms: Array = []
	var seen: Dictionary = {}
	for c in _cells(rect):
		if seen.has(c) or not g.people_can_walk(c) or g.solid_at(c) == S.DOOR:
			continue
		var room: Dictionary = _flood(g, [c], false, {}, rect, true)
		seen.merge(room)
		rooms.append(room)
	return rooms


func _furnished(data: Dictionary, room: Dictionary, level: int) -> bool:
	for item in data["containers"].values():
		if int(item.get("level", 0)) == level and room.has(item["cell"]):
			return true
	for spot in data["spots"].values():
		if spot["kind"] == "salvage" and int(spot.get("level", 0)) == level and room.has(spot["cell"]):
			return true
	for stove in data["stoves"]:
		if int(stove.get("level", 0)) == level and _touches(room, stove["cell"]):
			return true
	if level == 0:
		for rect: Rect2i in data["low_blocks"]:
			for c in _cells(rect):
				if _touches(room, c):
					return true
	return false


func _touches(room: Dictionary, c: Vector2i) -> bool:
	for direction in DIRS:
		if room.has(c + direction):
			return true
	return false


func _outdoor_covers(data: Dictionary, band: Rect2i) -> Array[Rect2i]:
	var g: FieldGrid = data["grid"]
	var result: Array[Rect2i] = []
	for rect: Rect2i in data["low_blocks"]:
		if not band.intersects(rect):
			continue
		var outdoor: bool = true
		for c in _cells(rect):
			if g.building_at(c) >= 0:
				outdoor = false
		if outdoor:
			result.append(rect)
	return result


func _deep_building(data: Dictionary) -> Dictionary:
	var g: FieldGrid = data["grid"]
	var zone_id: String = data["interior_kind_slots"][0]["zone"]
	for building in data["buildings"]:
		var rect: Rect2i = building["rect"]
		if g.zone_at(rect.get_center()) == zone_id:
			return building
	return {}


func _exterior_openings(g: FieldGrid, rect: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for c in _cells(rect):
		if c.x != rect.position.x and c.x != rect.end.x - 1 and c.y != rect.position.y and c.y != rect.end.y - 1:
			continue
		if g.people_can_walk(c):
			result.append(c)
	return result


func _outward(rect: Rect2i, c: Vector2i) -> Vector2i:
	if c.y == rect.position.y:
		return Vector2i.UP
	if c.y == rect.end.y - 1:
		return Vector2i.DOWN
	return Vector2i.LEFT if c.x == rect.position.x else Vector2i.RIGHT


func _slot_group(start: Vector2i, allowed: Dictionary) -> Dictionary:
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for direction in DIRS:
			var next: Vector2i = c + direction
			if allowed.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen


func _cells(rect: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			result.append(Vector2i(x, y))
	return result


func _zones(g: FieldGrid) -> Dictionary:
	var result: Dictionary = {}
	for zone_id in g.zone:
		if not zone_id.is_empty():
			result[zone_id] = true
	return result


func _reaches_zone(g: FieldGrid, reached: Dictionary, zone_id: String) -> bool:
	for c: Vector2i in reached:
		if g.zone_at(c) == zone_id:
			return true
	return false


func _inside_rect(g: FieldGrid, rect: Rect2i) -> bool:
	return rect.size.x > 0 and rect.size.y > 0 and g.inside(rect.position) and g.inside(rect.end - Vector2i.ONE)


func _in_band(data: Dictionary, c: Vector2i) -> bool:
	for band: Rect2i in data["bands"].values():
		if band.has_point(c):
			return true
	return false


func _longest_low_run(g: FieldGrid) -> int:
	var longest: int = 0
	for y in range(g.height):
		var run: int = 0
		for x in range(g.width):
			run = run + 1 if g.solid_at(Vector2i(x, y)) == S.LOW else 0
			longest = maxi(longest, run)
	for x in range(g.width):
		var run: int = 0
		for y in range(g.height):
			run = run + 1 if g.solid_at(Vector2i(x, y)) == S.LOW else 0
			longest = maxi(longest, run)
	return longest


func _uniform_floor_prefix(g: FieldGrid, kind: int) -> PackedInt32Array:
	var stride: int = g.width + 1
	var prefix := PackedInt32Array()
	prefix.resize(stride * (g.height + 1))
	for y in range(g.height):
		for x in range(g.width):
			var c := Vector2i(x, y)
			var value: int = 1 if g.solid_at(c) == S.NONE and g.floor_at(c) == kind else 0
			prefix[(y + 1) * stride + x + 1] = value + prefix[y * stride + x + 1] + prefix[(y + 1) * stride + x] - prefix[y * stride + x]
	return prefix


func _rect_sum(prefix: PackedInt32Array, stride: int, rect: Rect2i) -> int:
	return prefix[rect.end.y * stride + rect.end.x] - prefix[rect.position.y * stride + rect.end.x] - prefix[rect.end.y * stride + rect.position.x] + prefix[rect.position.y * stride + rect.position.x]


func test_entry_names_weights_first_entry_and_zone_names() -> void:
	for d: Dictionary in _maps:
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
		var total := 0.0
		for way: String in ways:
			var way_name: String = d["entry_names"][way]
			assert_false(way_name.is_empty())
			assert_false(_has_roman_or_han(way_name), way_name)
			assert_gte(float(d["entry_weights"][way]), 0.0)
			total += float(d["entry_weights"][way])
		assert_gt(total, 0.0)
		var g: FieldGrid = d["grid"]
		var zones: Dictionary = {}
		for z: String in g.zone:
			if z != "":
				zones[z] = true
		for z: String in zones:
			assert_true(d["zone_names"].has(z), z)
			assert_false(_has_roman_or_han(String(d["zone_names"].get(z, ""))), z)
		for b: Dictionary in d["buildings"]:
			assert_false(_has_roman_or_han(String(b["name"])), String(b["name"]))
		for id in d["containers"]:
			var box_name := String(d["containers"][id].get("name", ""))
			assert_false(_has_roman_or_han(box_name), box_name)


func _has_roman_or_han(text: String) -> bool:
	for i in range(text.length()):
		var c: int = text.unicode_at(i)
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 0x3400 and c <= 0x9FFF):
			return true
	return false


func test_assembly_props_are_separate_and_keep_reserved_cells_clear() -> void:
	for index in range(_maps.size()):
		var data: Dictionary = _maps[index]
		for level in data["levels"]:
			var g: FieldGrid = data["levels"][level]
			var reserved: Dictionary = _assembly_reserved_cells(data, int(level))
			var occupied: Dictionary = {}
			var low_cells: Dictionary = {}
			if int(level) == 0:
				for rect: Rect2i in data["low_blocks"]:
					for c in _cells(rect):
						low_cells[c] = true
			for prop: Dictionary in data["props"]:
				if int(prop.get("level", 0)) != int(level):
					continue
				var rect: Rect2i = prop["rect"]
				var label: String = "%s %s" % [data["place_id"], prop["kind"]]
				for c in _cells(rect):
					assert_true(g.inside(c), label + " bounds")
					assert_false(reserved.has(c), label + " reserved " + str(c))
					assert_false(occupied.has(c), label + " prop overlap " + str(c))
					occupied[c] = true
					# WALL props use their own freestanding backing; building walls stay clear.
					if prop["solid"] == "wall":
						assert_eq(g.building_at(c), -1, label + " freestanding wall")
					else:
						assert_ne(g.solid_at(c), S.WALL, label + " wall")
					assert_false(g.solid_at(c) in [S.DOOR, S.WINDOW, S.AIR], label + " opening or void")
					if prop["solid"] == "low":
						assert_true(low_cells.has(c), label + " low_blocks")
						assert_eq(g.solid_at(c), S.LOW, label + " LOW")
					if g.solid_at(c) in [S.NONE, S.LOW]:
						var across_x: bool = g.solid_at(c + Vector2i.LEFT) in [S.WALL, S.WINDOW] and g.solid_at(c + Vector2i.RIGHT) in [S.WALL, S.WINDOW]
						var across_y: bool = g.solid_at(c + Vector2i.UP) in [S.WALL, S.WINDOW] and g.solid_at(c + Vector2i.DOWN) in [S.WALL, S.WINDOW]
						assert_false(across_x or across_y, label + " one-cell passage")
		var ground: FieldGrid = data["grid"]
		var counts := Vector2i.ZERO
		for rect: Rect2i in data["low_blocks"]:
			var outdoor := true
			for c in _cells(rect):
				outdoor = outdoor and ground.building_at(c) < 0
			if not outdoor:
				continue
			if data["bands"]["upper"].intersects(rect):
				counts.x += 1
			if data["bands"]["lower"].intersects(rect):
				counts.y += 1
		assert_eq(counts, ASSEMBLY_BAND_COVERS[index], data["place_id"] + " unchanged band cover")


func test_assembly_wall_ids_stay_inside_their_buildings() -> void:
	for data: Dictionary in _maps:
		var rects: Dictionary = {}
		var house_rows: Dictionary = {}
		for building: Dictionary in data["buildings"]:
			var rect: Rect2i = building["rect"]
			rects[int(building["id"])] = rect
			if rect.size.x == 14:
				var row := Vector2i(rect.position.y, rect.size.y)
				house_rows[row] = int(house_rows.get(row, 0)) + 1
				assert_lte(house_rows[row], 2, data["place_id"] + " staggered houses")
		for g: FieldGrid in data["levels"].values():
			for y in range(g.height):
				for x in range(g.width):
					var c := Vector2i(x, y)
					var building_id: int = g.building_at(c)
					if g.solid_at(c) != S.WALL or building_id < 0:
						continue
					assert_true(rects.has(building_id), data["place_id"] + " known building")
					if rects.has(building_id):
						assert_true(rects[building_id].has_point(c), data["place_id"] + " wall in rect " + str(c))


func test_assembly_container_names_have_supported_endings() -> void:
	for data: Dictionary in _maps:
		for box: Dictionary in data["containers"].values():
			var supported := false
			for suffix: String in ASSEMBLY_CONTAINER_SUFFIXES:
				supported = supported or String(box["name"]).ends_with(suffix)
			assert_true(supported, "%s %s: %s" % [data["place_id"], box["id"], box["name"]])


func test_assembly_prop_kinds_stay_in_the_local_vocabulary() -> void:
	for data: Dictionary in _maps:
		var unexpected: Array[String] = []
		for prop: Dictionary in data["props"]:
			if not PROP_KINDS.has(prop["kind"]) and not unexpected.has(prop["kind"]):
				unexpected.append(prop["kind"])
		assert_true(unexpected.is_empty(), "%s unknown kinds: %s" % [data["place_id"], unexpected])


func _assembly_reserved_cells(data: Dictionary, level: int) -> Dictionary:
	var g: FieldGrid = data["levels"][level]
	var result: Dictionary = {}
	for c: Vector2i in g.doors:
		result[c] = true
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			result[c + step] = true
	for c: Vector2i in g.windows:
		result[c] = true
	for stair: Dictionary in data["stairs"]:
		if level == int(stair["low"]) or level == int(stair["high"]):
			result[stair["cell"]] = true
	for box: Dictionary in data["containers"].values():
		if int(box.get("level", 0)) == level:
			result[box["cell"]] = true
	for stove: Dictionary in data["stoves"]:
		if int(stove.get("level", 0)) == level:
			result[stove["cell"]] = true
	for key in data["entries"]:
		if int(data["entry_levels"].get(key, 0)) == level:
			for c: Vector2i in data["entries"][key]:
				result[c] = true
	for key in data["spawns"]:
		if key == "dead_levels":
			for spawn: Array in data["spawns"][key]:
				if int(spawn[1]) == level:
					result[spawn[0]] = true
		elif level == 0:
			for c: Vector2i in data["spawns"][key]:
				result[c] = true
	if level == 0:
		for c: Vector2i in data["barricade_slots"]:
			result[c] = true
		for side: String in ["upper", "lower"]:
			var outward := Vector2i.UP if side == "upper" else Vector2i.DOWN
			for door: Vector2i in data["train_doors"][side]:
				for depth in range(3):
					for lateral in range(-1, 2):
						result[door + outward * depth + Vector2i(lateral, 0)] = true
	return result
