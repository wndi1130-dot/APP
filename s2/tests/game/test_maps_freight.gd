extends "res://addons/gut/test.gd"

const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const MAPS = [
	preload("res://game/world/maps/freight_01.gd"),
	preload("res://game/world/maps/freight_02.gd"),
	preload("res://game/world/maps/freight_03.gd"),
	preload("res://game/world/maps/freight_04.gd"),
	preload("res://game/world/maps/freight_05.gd"),
	preload("res://game/world/maps/freight_06.gd"),
]
const KEYS = [
	"grid", "levels", "stairs", "containers", "spots", "stoves", "entries", "entry_gap", "entry_levels",
	"buildings", "wagons", "train", "platform", "unload", "train_cars", "spawns", "labels", "trees",
	"low_blocks", "upper_rects", "lights", "manholes", "manhole_levels", "sewer_names", "anchors", "zone_names",
	"place_id", "place_kind", "bands", "train_doors", "crossings", "barricade_slots", "interior_kind_slots", "props", "hole_faces", "entry_names", "entry_weights", "first_entry",
]
const KINDS = [
	"car", "handcart", "firewood_pile", "barrel", "crate_stack", "sack_pile", "bench", "shelf", "bed", "desk",
	"cold_stove", "lamp_post", "display_shelf", "shop_counter", "checkout", "shopping_cart", "pallet_stack",
	"market_stall", "shop_awning", "freezer_chest", "bread_rack", "blank_sign", "floor_shell", "stair_stub", "water",
	"coal_wagon", "box_wagon", "flat_wagon", "tender_wagon", "old_coach", "buffer_stop", "switch_lever",
	"switch_cluster", "sleeper_pile", "rail_pile", "coupler_set", "brake_shoe_pile", "wheelset", "water_crane",
	"water_tower", "coal_hopper", "coal_heap", "signal_bridge", "signal_post", "turntable_deck", "turntable_rim",
	"pit_rail_pair", "platform_cart", "weigh_platform", "dock_platform", "jib_crane", "forklift", "tool_cart",
	"part_crate", "conductor_log_chest", "file_cabinet", "bridge_truss", "mooring_post", "water_gauge",
	"frozen_barge", "lock_wheel", "sluice_frame", "quay_crane", "rope_coil", "reed_clump", "bare_tree", "snow_drift",
	# 북쪽 구역에서 이미 쓰는 일곱 종류. 공용 종류 표에 올릴 후보다.
	"log_pile", "lumber_rack", "grain_silo", "cable_drum", "transformer_unit", "medicine_crate", "plate_stack",
]
const CONTAINER_SUFFIXES: Array[String] = [
	"상자", "보관함", "묶음", "선반", "자재함", "궤", "찬장", "공구함", "책상", "침대", "옷장",
]
const STEP: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var built: Array[Dictionary] = []
var walks: Dictionary = {}


func before_all() -> void:
	for script in MAPS:
		built.append(script.build())
	for data in built:
		walks[data["place_id"]] = {"people": _flood(data), "dead": _flood(data, true), "levels": _flood(data, false, true)}


func _cells(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2i(x, y))
	return out


func _flat(g: FieldGrid, c: Vector2i, lv: int = 0) -> int:
	return (lv + 1) * g.width * g.height + g.index(c)


## 네 방향 최단 거리. 문은 실제 FieldGrid의 사람/망자 규칙을 따른다.
## 층 전이는 stairs에 기록된 이웃 층으로만 이동하며 비용은 한 걸음이다.
func _flood(data: Dictionary, dead: bool = false, use_stairs: bool = false, blocked: Dictionary = {}, seeds: Array = []) -> PackedInt32Array:
	var g: FieldGrid = data["grid"]
	var n: int = g.width * g.height
	var dist := PackedInt32Array()
	dist.resize(n * 4)
	dist.fill(-1)
	var queue := PackedInt32Array()
	queue.resize(n * 4)
	var head: int = 0
	var tail: int = 0
	var links: Dictionary = {}
	if use_stairs:
		for st in data["stairs"]:
			var a: int = _flat(g, st["cell"], int(st["low"]))
			var b: int = _flat(g, st["cell"], int(st["high"]))
			if not links.has(a):
				links[a] = []
			if not links.has(b):
				links[b] = []
			links[a].append(b)
			links[b].append(a)
	var starts: Array = seeds.duplicate()
	if starts.is_empty():
		for c in data["train_doors"]["lower"]:
			starts.append([c, 0])
	for seed in starts:
		var c: Vector2i = seed[0]
		var lv: int = int(seed[1])
		var lg: FieldGrid = data["levels"][lv]
		if not (lg.dead_can_walk(c) if dead else lg.people_can_walk(c)) or blocked.has(Vector3i(c.x, c.y, lv)):
			continue
		var i: int = _flat(g, c, lv)
		if dist[i] < 0:
			dist[i] = 0
			queue[tail] = i
			tail += 1
	while head < tail:
		var i: int = queue[head]
		head += 1
		var lv: int = int(i / n) - 1
		var local: int = i % n
		var c := Vector2i(local % g.width, int(local / g.width))
		var lg: FieldGrid = data["levels"][lv]
		var next: Array[int] = []
		for step in STEP:
			var to: Vector2i = c + step
			if (lg.dead_can_walk(to) if dead else lg.people_can_walk(to)) and not blocked.has(Vector3i(to.x, to.y, lv)):
				next.append(_flat(g, to, lv))
		if use_stairs and links.has(i):
			for j in links[i]:
				next.append(int(j))
		for j in next:
			if dist[j] < 0:
				dist[j] = dist[i] + 1
				queue[tail] = j
				tail += 1
	return dist


func _water(data: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for pr in data["props"]:
		if pr["kind"] == "water":
			for c in _cells(pr["rect"]):
				out[c] = true
	return out


func _protected(data: Dictionary) -> Dictionary:
	var g: FieldGrid = data["grid"]
	var out: Dictionary = {}
	for side in ["upper", "lower"]:
		for c in data["train_doors"][side]:
			for k in range(4):
				out[c + Vector2i(0, -k if side == "upper" else k)] = true
	for c in g.doors:
		var normal: Vector2i = Vector2i.RIGHT
		if g.solid_at(c + Vector2i.LEFT) in [S.WALL, S.WINDOW] or g.solid_at(c + Vector2i.RIGHT) in [S.WALL, S.WINDOW]:
			normal = Vector2i.DOWN
		out[c] = true
		for k in range(1, 4):
			out[c + normal * k] = true
			out[c - normal * k] = true
	for c in data["barricade_slots"]:
		out[c] = true
	for id in data["entries"]:
		if int(data["entry_levels"].get(id, 0)) == 0:
			for c in data["entries"][id]:
				out[c] = true
	return out


func test_exact_contract_sizes_and_zones() -> void:
	for data in built:
		var id: String = data["place_id"]
		var g: FieldGrid = data["grid"]
		assert_eq(data.size(), KEYS.size(), id)
		for k in KEYS:
			assert_true(data.has(k), id + " " + k)
		for k in data:
			assert_true(KEYS.has(k), id + " unexpected " + str(k))
		assert_true(g.width >= 150 and g.width <= 180 and g.height >= 135 and g.height <= 155, id)
		assert_eq(id, "freight_%02d" % (built.find(data) + 1))
		assert_eq(data["place_kind"], "freight")
		var zones: Dictionary = {}
		for z in g.zone:
			zones[z] = true
		assert_true(zones.size() >= 8 and zones.size() <= 12, id)
		assert_eq(zones.size(), data["zone_names"].size(), id)
		for z in zones:
			assert_true(data["zone_names"].has(z) and not String(data["zone_names"].get(z, "")).is_empty(), id + str(z))


func test_train_platform_band_and_clear_doors() -> void:
	for data in built:
		var g: FieldGrid = data["grid"]
		var train: Rect2i = data["train"]
		var bounds := Rect2i(0, 0, g.width, g.height)
		assert_eq(train, Rect2i(16, 46, 80, 3))
		assert_eq(data["platform"], Rect2i(train.position.x, 49, 82, 6))
		assert_eq(data["unload"], Rect2i(train.position.x, 49, 82, 3))
		assert_eq(data["bands"].size(), 2)
		assert_eq(data["train_doors"].size(), 2)
		assert_eq(data["bands"]["upper"], Rect2i(-4, 24, 120, 22).intersection(bounds))
		assert_eq(data["bands"]["lower"], Rect2i(-4, 49, 120, 26).intersection(bounds))
		assert_false(data["bands"]["upper"].intersects(data["bands"]["lower"]))
		assert_eq(data["train_doors"]["lower"], data["spawns"]["train_door"])
		var pairs: Array = []
		for side in ["upper", "lower"]:
			assert_true(bounds.encloses(data["bands"][side]))
			assert_gte(data["train_doors"][side].size(), 3)
			var xs: Array = []
			for c in data["train_doors"][side]:
				assert_eq(c.y, 45 if side == "upper" else 49)
				assert_true(c.x >= train.position.x + 2 and c.x < train.end.x - 2)
				assert_eq(g.solid_at(c), S.NONE)
				xs.append(c.x)
				assert_true(data["barricade_slots"].has(c + (Vector2i.UP if side == "upper" else Vector2i.DOWN)))
			xs.sort()
			pairs.append(xs)
		assert_eq(pairs[0], pairs[1])
		for r in [Rect2i(16, 43, 80, 3), Rect2i(16, 49, 80, 3)]:
			for c in _cells(r):
				assert_eq(g.solid_at(c), S.NONE)
				assert_true(g.people_can_walk(c) and g.dead_can_walk(c))
			for pr in data["props"]:
				if int(pr.get("level", 0)) == 0:
					assert_false(pr["rect"].intersects(r), data["place_id"] + pr["kind"])
		var ends: Array[int] = [0, 0]
		for x in range(g.width):
			for y in range(46, 49):
				var c := Vector2i(x, y)
				assert_eq(g.floor_at(c), F.RAIL)
				if g.people_can_walk(c):
					if x < train.position.x:
						ends[0] += 1
					elif x >= train.end.x:
						ends[1] += 1
		assert_gte(ends[0], 4)
		assert_gte(ends[1], 4)
		var covered: Dictionary = {}
		for car in data["train_cars"]:
			for c in _cells(car["rect"]):
				covered[c] = true
		assert_eq(covered.size(), 80 * 3)
		assert_eq(data["train_cars"][-1]["kind"], "engine")
		for c in data["spawns"]["squad"]:
			assert_true(data["bands"]["lower"].has_point(c))
		assert_eq(data["crossings"].size(), 2)
		var crossing_xs: Dictionary = {}
		for crossing in data["crossings"]:
			assert_eq(crossing["cells"].size(), 3)
			var x: int = crossing["cells"][0].x
			assert_true([train.position.x + 16, train.position.x + 32, train.position.x + 48].has(x))
			assert_false(pairs[0].has(x))
			assert_false(crossing_xs.has(x))
			crossing_xs[x] = true
			assert_eq(crossing["cells"], [Vector2i(x, 46), Vector2i(x, 47), Vector2i(x, 48)])
			for c in crossing["cells"]:
				assert_eq(g.solid_at(c), S.BLOCK)
				assert_false(g.people_can_walk(c) or g.dead_can_walk(c))
			assert_eq(g.solid_at(Vector2i(x, 45)), S.NONE)
			assert_eq(g.solid_at(Vector2i(x, 49)), S.NONE)
			assert_eq(crossing["who"], {"person": true, "zombie": false, "carrying": true, "wounded": false, "sled": false})


func test_edges_holes_and_dead_reach_the_train() -> void:
	for data in built:
		var id: String = data["place_id"]
		var g: FieldGrid = data["grid"]
		var reached: Dictionary = {"lower": walks[id]["dead"], "upper": _flood(data, true, false, {}, _side_seeds(data, "upper"))}
		var edge_count: Dictionary = {"upper": 0, "lower": 0}
		for name in data["entries"]:
			assert_true(data["entry_gap"].has(name), id + name)
			var gap: float = float(data["entry_gap"].get(name, 0.0))
			assert_true(gap > 0.0 and gap <= 3.0, id + name)
			var cs: Array = data["entries"][name]
			var side: String = "upper" if cs[0].y < 46 else "lower"
			if not data["manholes"].has(name):
				edge_count[side] += 1
				assert_true(cs.size() >= 2 and cs.size() <= 4, id + name)
			for c in cs:
				for band in data["bands"].values():
					assert_false(band.has_point(c), id + name)
				if int(data["entry_levels"].get(name, 0)) == 0:
					assert_gte(reached[side][_flat(g, c)], 0, id + name + str(c))
				if not data["manholes"].has(name):
					assert_true(c.x == 0 or c.x == g.width - 1 or c.y == 0 or c.y == g.height - 1, id + name)
					assert_eq(c.y < 46, side == "upper")
		assert_true(edge_count["upper"] >= 2 and edge_count["upper"] <= 3)
		assert_true(edge_count["lower"] >= 3 and edge_count["lower"] <= 5)
		assert_lte(data["manholes"].size(), 4, id)
		for name in data["manholes"]:
			var c: Vector2i = data["manholes"][name]
			for k in ["entries", "entry_gap", "sewer_names"]:
				assert_true(data[k].has(name), id + name)
			assert_true(data["entries"][name].has(c), id + name)
			if data["manhole_levels"].has(name):
				assert_eq(data["manhole_levels"][name], -1)
				assert_eq(data["entry_levels"].get(name, 99), -1)
				var cellar: PackedInt32Array = _flood(data, true, false, {}, [[c, -1]])
				var reaches_stairs: bool = false
				for st in data["stairs"]:
					if int(st["low"]) == -1 and cellar[_flat(g, st["cell"], -1)] >= 0:
						reaches_stairs = true
				assert_true(reaches_stairs, id + name)
			else:
				for side in ["upper", "lower"]:
					for d in data["train_doors"][side]:
						assert_gt(absi(c.x - d.x) + absi(c.y - d.y), 25, id + name)
				assert_gte(reached["upper" if c.y < 46 else "lower"][_flat(g, c)], 0, id + name)
			if String(name).begins_with("culvert_"):
				assert_true(data["hole_faces"].has(name) and STEP.has(data["hole_faces"].get(name)), id + name)
			elif String(name).begins_with("manhole_"):
				assert_eq(float(data["entry_gap"][name]), 3.0)
			else:
				assert_eq(float(data["entry_gap"][name]), 0.6)
		for name in data["spawns"]:
			if not String(name).begins_with("dead_"):
				continue
			for row in data["spawns"][name]:
				var c: Vector2i = row[0] if name == "dead_levels" else row
				for band in data["bands"].values():
					assert_false(band.has_point(c), id + name)


func test_every_ground_cell_and_open_side_remain_reachable() -> void:
	for data in built:
		var g: FieldGrid = data["grid"]
		var reached: PackedInt32Array = walks[data["place_id"]]["people"]
		var blocked: Dictionary = {}
		for c in data["barricade_slots"]:
			assert_true(g.people_can_walk(c))
			blocked[Vector3i(c.x, c.y, 0)] = true
		var open_side: PackedInt32Array = _flood(data, false, false, blocked)
		var zones: Dictionary = {}
		var unreachable: int = 0
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				if g.people_can_walk(c) and reached[_flat(g, c)] < 0:
					unreachable += 1
				if open_side[_flat(g, c)] >= 0:
					zones[g.zone_at(c)] = true
		assert_eq(unreachable, 0, data["place_id"])
		for zone in data["zone_names"]:
			assert_true(zones.has(zone), data["place_id"] + zone)


func test_low_cover_water_and_visible_blocks() -> void:
	for data in built:
		var g: FieldGrid = data["grid"]
		var band: Rect2i = data["bands"]["lower"]
		var water: Dictionary = _water(data)
		var drawn_low: Dictionary = {}
		var drawn_block: Dictionary = {}
		var covers: Array[Rect2i] = []
		var close_covers: int = 0
		for r: Rect2i in data["low_blocks"]:
			for c in _cells(r):
				drawn_low[c] = true
			if r.intersects(band):
				covers.append(r)
				var nearest: int = 10000
				for c in _cells(r):
					for d in data["train_doors"]["lower"]:
						nearest = mini(nearest, absi(c.x - d.x) + absi(c.y - d.y))
				if nearest <= 12:
					close_covers += 1
		for stove in data["stoves"]:
			if int(stove.get("level", 0)) == 0:
				drawn_low[stove["cell"]] = true
		for r in data["train_cars"]:
			for c in _cells(r["rect"]):
				drawn_block[c] = true
		for wagon in data["wagons"]:
			for c in _cells(wagon["rect"]):
				drawn_block[c] = true
		for c in data["trees"]:
			drawn_block[c] = true
		assert_true(covers.size() >= 3 and covers.size() <= 5, data["place_id"])
		assert_gte(close_covers, 2, data["place_id"])
		var shapes: Dictionary = {}
		for r in covers:
			shapes[r.size] = true
			assert_true(maxi(r.size.x, r.size.y) >= 2 and maxi(r.size.x, r.size.y) <= 6)
		assert_gt(shapes.size(), 1)
		var bad: int = 0
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				if g.solid_at(c) == S.LOW and not drawn_low.has(c) and not water.has(c):
					bad += 1
				if water.has(c) and (g.floor_at(c) != F.ICE or g.solid_at(c) != S.LOW or drawn_low.has(c)):
					bad += 1
				if g.solid_at(c) == S.BLOCK and g.building_at(c) < 0 and not drawn_block.has(c):
					bad += 1
				if x < 14 and y < 14 and (g.solid_at(c) == S.BLOCK or data["trees"].has(c)):
					bad += 1
		assert_eq(bad, 0, data["place_id"])
		for horizontal in [true, false]:
			for a in range(g.height if horizontal else g.width):
				var run: int = 0
				var longest: int = 0
				for b in range(g.width if horizontal else g.height):
					var c := Vector2i(b, a) if horizontal else Vector2i(a, b)
					run = run + 1 if g.solid_at(c) == S.LOW and not water.has(c) else 0
					longest = maxi(longest, run)
				assert_lte(longest, 10, data["place_id"])


func test_buildings_have_entries_partitions_and_large_main_floor() -> void:
	for data in built:
		var g: FieldGrid = data["grid"]
		var entered: Dictionary = {}
		var largest: int = 0
		var northern: int = data["buildings"].filter(func(b): return b["rect"].position.y < 46).size()
		assert_true(northern >= 6 and northern <= 9)
		assert_true(data["buildings"].size() - northern >= 14 and data["buildings"].size() - northern <= 22)
		for c in g.doors:
			entered[g.doors[c]["building"]] = true
		for i in range(data["buildings"].size()):
			var b: Dictionary = data["buildings"][i]
			var r: Rect2i = b["rect"]
			assert_eq(b["id"], i)
			assert_true(Rect2i(0, 0, g.width, g.height).encloses(r))
			var inner: Rect2i = r.grow(-1)
			largest = maxi(largest, inner.get_area())
			if inner.get_area() > 60:
				var partitions: int = 0
				for c in _cells(inner):
					if g.solid_at(c) == S.WALL:
						partitions += 1
				assert_gt(partitions, 0, data["place_id"] + b["name"])
		assert_gte(float(entered.size()) / float(data["buildings"].size()), 0.7)
		assert_gte(largest, 600)


func test_levels_stairs_and_shallow_and_deep_loot() -> void:
	for data in built:
		var g: FieldGrid = data["grid"]
		var dist: PackedInt32Array = walks[data["place_id"]]["levels"]
		for lv in [-1, 1, 2]:
			assert_true(data["levels"].has(lv))
			var lg: FieldGrid = data["levels"][lv]
			assert_eq(lg.width, g.width)
			assert_eq(lg.height, g.height)
			var floor_cells: int = 0
			var outside_walk: int = 0
			for y in range(g.height):
				for x in range(g.width):
					var c := Vector2i(x, y)
					if lg.people_can_walk(c):
						floor_cells += 1
						if lg.building_at(c) < 0:
							outside_walk += 1
			assert_gt(floor_cells, 0)
			assert_eq(outside_walk, 0)
		for st in data["stairs"]:
			assert_eq(int(st["high"]) - int(st["low"]), 1)
			for lv in [int(st["low"]), int(st["high"])]:
				assert_true(data["levels"][lv].people_can_walk(st["cell"]))
				assert_gte(dist[_flat(g, st["cell"], lv)], 0)
		assert_eq(data["interior_kind_slots"].size(), 3)
		assert_ne(data["interior_kind_slots"][0]["zone"], data["interior_kind_slots"][1]["zone"])
		for slot in data["interior_kind_slots"]:
			assert_true(data["zone_names"].has(slot["zone"]))
			assert_eq(slot["kinds"], ["empty", "raiders", "nest", "beasts"])
		var deepest: int = -1
		var shallowest: int = 100000
		for id in data["containers"]:
			var box: Dictionary = data["containers"][id]
			var d: int = dist[_flat(g, box["cell"], int(box.get("level", 0)))]
			assert_gte(d, 0, data["place_id"] + id)
			deepest = maxi(deepest, d)
			shallowest = mini(shallowest, d)
		assert_gte(deepest, 80)
		assert_lte(shallowest, 40)


func test_props_are_supported_visible_and_clear_of_routes() -> void:
	for data in built:
		var g: FieldGrid = data["grid"]
		var protect: Dictionary = _protected(data)
		var indoor: int = 0
		assert_gte(data["props"].size(), 130)
		var north_trees: int = data["trees"].filter(func(c): return c.y < 46).size()
		var south_trees: int = data["trees"].size() - north_trees
		assert_true(north_trees >= 12 and north_trees <= 30)
		assert_true(south_trees >= 25 and south_trees <= 60)
		for pr in data["props"]:
			var r: Rect2i = pr["rect"]
			var lv: int = int(pr.get("level", 0))
			assert_true(KINDS.has(pr["kind"]))
			assert_true(Rect2i(0, 0, g.width, g.height).encloses(r) and r.get_area() > 0)
			assert_true(pr["solid"] in ["low", "wall", "tree", "wagon", "none"])
			assert_true(lv >= -1 and lv <= 3)
			assert_true(lv != 3 or pr["kind"] == "floor_shell")
			for b in data["buildings"]:
				if b["rect"].encloses(r):
					indoor += 1
					break
			if lv != 0:
				assert_eq(pr["solid"], "none")
			else:
				if pr["solid"] == "low" and pr["kind"] != "water":
					assert_true(data["low_blocks"].has(r))
				if pr["kind"] == "water":
					assert_false(data["low_blocks"].has(r))
				for c in _cells(r):
					assert_false(protect.has(c), data["place_id"] + str(pr["kind"]) + str(c))
					if pr["solid"] == "wall":
						assert_eq(g.solid_at(c), S.WALL)
					elif pr["solid"] == "low":
						assert_eq(g.solid_at(c), S.LOW)
					elif pr["solid"] == "tree":
						assert_true(data["trees"].has(c) and g.solid_at(c) == S.BLOCK)
			if pr["kind"] == "floor_shell":
				var stubs: int = 0
				var exact_building: bool = false
				for b in data["buildings"]:
					if b["rect"] == r:
						exact_building = true
				for other in data["props"]:
					if other["kind"] == "stair_stub" and int(other.get("level", 0)) == 2 and r.encloses(other["rect"]):
						stubs += 1
				assert_true(exact_building)
				assert_eq(stubs, 1)
		assert_gte(indoor * 2, data["props"].size())


func test_asymmetry_names_and_six_distinct_layouts() -> void:
	var first_lines: Dictionary = {}
	var names := RegEx.new()
	assert_eq(names.compile("[A-Za-z\\x{3400}-\\x{9FFF}]"), OK)
	for i in range(built.size()):
		var data: Dictionary = built[i]
		var g: FieldGrid = data["grid"]
		var total: int = 0
		var same: int = 0
		for y in range(g.height):
			for x in range(g.width):
				var a: int = g.solid_at(Vector2i(x, y))
				if a in [S.WALL, S.BLOCK, S.LOW]:
					total += 1
					if g.solid_at(Vector2i(g.width - 1 - x, y)) == a:
						same += 1
		assert_lt(float(same) / float(maxi(1, total)), 0.5, data["place_id"])
		for j in range(i):
			assert_ne(g.solid, built[j]["grid"].solid, data["place_id"])
		var source: String = FileAccess.get_file_as_string("res://game/world/maps/%s.gd" % data["place_id"])
		var first: String = source.get_slice("\n", 0)
		assert_true(first.begins_with("# 이 지도가 다른 판단을 만드는 것: "))
		assert_false(first_lines.has(first))
		first_lines[first] = true
		var human_names: Array = data["zone_names"].values() + data["sewer_names"].values()
		for b in data["buildings"]:
			human_names.append(b["name"])
		for id in data["containers"]:
			human_names.append(data["containers"][id]["name"])
		for pr in data["props"]:
			human_names.append(pr["note"])
		for name in human_names:
			assert_null(names.search(String(name)), data["place_id"] + String(name))


func test_no_empty_thirty_by_twenty_ground_window() -> void:
	for data in built:
		var g: FieldGrid = data["grid"]
		# 누적합으로 각 바닥 종류의 완전히 빈 창을 찾는다.
		var stride: int = g.width + 1
		var bad: int = 0
		for kind in range(8):
			var prefix := PackedInt32Array()
			prefix.resize(stride * (g.height + 1))
			for y in range(g.height):
				var row_sum: int = 0
				for x in range(g.width):
					var c := Vector2i(x, y)
					if g.solid_at(c) == S.NONE and g.floor_at(c) == kind:
						row_sum += 1
					prefix[(y + 1) * stride + x + 1] = prefix[y * stride + x + 1] + row_sum
			for y in range(g.height - 19):
				for x in range(g.width - 29):
					var count: int = prefix[(y + 20) * stride + x + 30] - prefix[y * stride + x + 30] - prefix[(y + 20) * stride + x] + prefix[y * stride + x]
					if count == 600:
						bad += 1
		assert_eq(bad, 0, data["place_id"])


func _side_seeds(data: Dictionary, side: String) -> Array:
	var seeds: Array = []
	for c in data["train_doors"][side]:
		seeds.append([c, 0])
	return seeds


func test_upper_cover_buildings_loot_and_open_side() -> void:
	for data in built:
		var g: FieldGrid = data["grid"]
		var band: Rect2i = data["bands"]["upper"]
		var covers: Array = []
		var close_count: int = 0
		var shapes: Dictionary = {}
		for r in data["low_blocks"]:
			if not r.intersects(band):
				continue
			covers.append(r)
			shapes[r.size] = true
			assert_true(maxi(r.size.x, r.size.y) >= 2 and maxi(r.size.x, r.size.y) <= 6)
			var nearest: int = 10000
			for c in _cells(r):
				for d in data["train_doors"]["upper"]:
					nearest = mini(nearest, absi(c.x - d.x) + absi(c.y - d.y))
			if nearest <= 12:
				close_count += 1
		assert_true(covers.size() >= 3 and covers.size() <= 5)
		assert_gte(close_count, 2)
		assert_gt(shapes.size(), 1)
		for b in data["buildings"]:
			assert_false(b["rect"].intersects(band))
		var blocked: Dictionary = {}
		for c in data["barricade_slots"]:
			blocked[Vector3i(c.x, c.y, 0)] = true
		for side in ["upper", "lower"]:
			var reachable: PackedInt32Array = _flood(data, false, false, blocked, _side_seeds(data, side))
			var visited_zones: Dictionary = {}
			var needed_zones: Dictionary = {}
			for y in range(g.height):
				for x in range(g.width):
					var c := Vector2i(x, y)
					if (y < 46) == (side == "upper"):
						needed_zones[g.zone_at(c)] = true
					if reachable[_flat(g, c)] >= 0:
						visited_zones[g.zone_at(c)] = true
			for zone in needed_zones:
				assert_true(visited_zones.has(zone), data["place_id"] + zone)
			var distance: PackedInt32Array = _flood(data, false, true, {}, _side_seeds(data, side))
			var deepest: int = -1
			var shallowest: int = 100000
			for box in data["containers"].values():
				if (box["cell"].y < 46) != (side == "upper"):
					continue
				var steps: int = distance[_flat(g, box["cell"], int(box.get("level", 0)))]
				assert_gte(steps, 0)
				deepest = maxi(deepest, steps)
				shallowest = mini(shallowest, steps)
			assert_gte(deepest, 45 if side == "upper" else 80)
			assert_lte(shallowest, 25 if side == "upper" else 40)
		var slot_zones: Dictionary = {}
		var upper_slot: bool = false
		for slot in data["interior_kind_slots"]:
			assert_false(slot_zones.has(slot["zone"]))
			slot_zones[slot["zone"]] = true
			if ["I", "J", "K"].has(slot["zone"]):
				upper_slot = true
		assert_true(upper_slot)


func test_northern_rooms_props_and_distinct_plans() -> void:
	var judgments: Dictionary = {}
	var north_solids: Array = []
	for i in range(built.size()):
		var data: Dictionary = built[i]
		var g: FieldGrid = data["grid"]
		var props: Array = data["props"].filter(func(pr): return pr["rect"].position.y < 46)
		var indoors: int = 0
		for pr in props:
			for b in data["buildings"]:
				if b["rect"].encloses(pr["rect"]):
					indoors += 1
					break
		assert_gte(props.size(), 40)
		assert_gte(indoors * 2, props.size())
		var largest_id: int = -1
		var largest_area: int = 0
		for b in data["buildings"]:
			if b["rect"].position.y < 46 and b["rect"].get_area() > largest_area:
				largest_id = b["id"]
				largest_area = b["rect"].get_area()
		var largest_rooms: int = 0
		for row in MAPS[i].NORTH_PLAN["rooms"]:
			var r := Rect2i(row["rect"][0], row["rect"][1], row["rect"][2], row["rect"][3])
			assert_true(r.size.x >= 3 and r.size.y >= 3)
			var occupied: bool = false
			var counts: Dictionary = {}
			for pr in props:
				if int(pr.get("level", 0)) == row["level"] and r.encloses(pr["rect"]):
					occupied = true
					counts[pr["kind"]] = int(counts.get(pr["kind"], 0)) + 1
			for box in data["containers"].values():
				if int(box.get("level", 0)) == row["level"] and r.has_point(box["cell"]):
					occupied = true
			assert_true(occupied)
			for kind in counts:
				if kind not in ["shelf", "display_shelf"]:
					assert_lte(counts[kind], 4)
			if row["level"] == 0 and row["building"] == largest_id:
				largest_rooms += 1
		assert_gte(largest_rooms, 6)
		var source: String = FileAccess.get_file_as_string("res://game/world/maps/%s.gd" % data["place_id"])
		var judgment: String = source.get_slice("\n", 1)
		assert_true(judgment.begins_with("# 위쪽의 판단: "))
		assert_false(judgments.has(judgment))
		judgments[judgment] = true
		var top: PackedByteArray = g.solid.slice(0, g.width * 46)
		for prior in north_solids:
			assert_ne(top, prior)
		north_solids.append(top)
		# Fold onto corresponding cells beside the train. Count the union of occupied
		# pairs once; doors, windows and water remain part of the comparison.
		var occupied_pairs: int = 0
		var matching_pairs: int = 0
		for distance in range(1, 46):
			for x in range(g.width):
				var a: int = g.solid_at(Vector2i(x, 46 - distance))
				var b: int = g.solid_at(Vector2i(x, 48 + distance))
				if a in [S.WALL, S.BLOCK, S.LOW, S.DOOR, S.WINDOW] or b in [S.WALL, S.BLOCK, S.LOW, S.DOOR, S.WINDOW]:
					occupied_pairs += 1
					if a == b:
						matching_pairs += 1
		assert_lt(float(matching_pairs) / float(maxi(1, occupied_pairs)), 0.5, data["place_id"])


func test_south_is_shifted_exactly_except_declared_repairs() -> void:
	for i in range(MAPS.size()):
		var original: Dictionary = MAPS[i]._build_south(false)
		var data: Dictionary = built[i]
		for c in _cells(Rect2i(0, 49, 16, 6)):
			assert_eq(data["grid"].floor_at(c), FieldGrid.Floor.ROAD, data["place_id"] + " 서쪽 길")
		var exceptions: Dictionary = {}
		for a in MAPS[i].SOUTH_REPAIRS["changed"]:
			for c in _cells(Rect2i(a[0], a[1], a[2], a[3])):
				exceptions[c] = true
		var mismatches: int = 0
		for lv in [-1, 0, 1, 2]:
			var old_grid: FieldGrid = original["levels"][lv]
			var new_grid: FieldGrid = data["levels"][lv]
			for y in range(1, old_grid.height):
				for x in range(old_grid.width):
					var before := Vector2i(x, y)
					var after := before + Vector2i(0, 45)
					if lv == 0 and exceptions.has(before):
						continue
					if old_grid.solid_at(before) != new_grid.solid_at(after) or old_grid.floor_at(before) != new_grid.floor_at(after):
						mismatches += 1
		assert_eq(mismatches, 0, data["place_id"])
		assert_eq(data["hole_faces"], original["hole_faces"])
		for old in original["buildings"]:
			assert_eq(data["buildings"][old["id"]]["rect"], Rect2i(old["rect"].position + Vector2i(0, 45), old["rect"].size))
		assert_true(data["spots"].has("work_site"))
		var work: Dictionary = data["spots"]["work_site"]
		assert_true(work["zone_rect"].has_point(work["cell"]))


func test_entry_names_weights_and_first_entry() -> void:
	for n in range(1, 7):
		var d: Dictionary = load("res://game/world/maps/freight_%02d.gd" % n).build()
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


## 소품이 WALL/LOW를 덮어쓴 뒤의 격자만 보면 가려진 칸막이를 놓친다.
## 원 배치의 벽을 먼저 모으고, 열린 틈과 문을 빼서 따로 검사한다.
func _assembly_structure(map_script: Script) -> Dictionary:
	var walls: Dictionary = {}
	var constants: Dictionary = map_script.get_script_constant_map()
	for part in range(2):
		var plan: Dictionary = constants["PLAN"] if part == 0 else constants["NORTH_PLAN"]
		var dy: int = 45 if part == 0 else 0
		for row in plan["shells"]:
			var r := Rect2i(row[2], row[3] + dy, row[4], row[5])
			for c in _cells(r):
				var key := Vector3i(c.x, c.y, int(row[1]))
				if c.x == r.position.x or c.x == r.end.x - 1 or c.y == r.position.y or c.y == r.end.y - 1:
					walls[key] = true
				else:
					walls.erase(key)
		for row in plan["walls"]:
			for c in _cells(Rect2i(row[1], row[2] + dy, row[3], row[4])):
				walls[Vector3i(c.x, c.y, int(row[0]))] = true
		for row in plan["openings"]:
			for c in _cells(Rect2i(row[1], row[2] + dy, row[3], row[4])):
				walls.erase(Vector3i(c.x, c.y, int(row[0])))
		for row in plan["windows"]:
			walls[Vector3i(row[1], row[2] + dy, int(row[0]))] = true
		for row in plan["doors"]:
			walls.erase(Vector3i(row[1], row[2] + dy, int(row[0])))
	return walls


func _assembly_reserved(data: Dictionary, walls: Dictionary) -> Dictionary:
	var reserved: Dictionary = walls.duplicate()
	for c: Vector2i in _protected(data):
		reserved[Vector3i(c.x, c.y, 0)] = true
	for lv in data["levels"]:
		var g: FieldGrid = data["levels"][lv]
		for c: Vector2i in g.windows:
			reserved[Vector3i(c.x, c.y, lv)] = true
		for c: Vector2i in g.doors:
			var normal := Vector2i.RIGHT
			if g.solid_at(c + Vector2i.LEFT) in [S.WALL, S.WINDOW] or g.solid_at(c + Vector2i.RIGHT) in [S.WALL, S.WINDOW]:
				normal = Vector2i.DOWN
			for k in range(-1, 2):
				var front: Vector2i = c + normal * k
				reserved[Vector3i(front.x, front.y, lv)] = true
		# 객차·기관고의 닫히지 않는 출입 틈도 문과 그 앞 한 칸으로 센다.
		for building in data["buildings"]:
			var r: Rect2i = building["rect"]
			for c in _cells(r):
				if c.x != r.position.x and c.x != r.end.x - 1 and c.y != r.position.y and c.y != r.end.y - 1:
					continue
				var key := Vector3i(c.x, c.y, lv)
				if g.building_at(c) != int(building["id"]) or walls.has(key) or g.doors.has(c) or g.windows.has(c):
					continue
				reserved[key] = true
				for step in STEP:
					reserved[Vector3i(c.x + step.x, c.y + step.y, lv)] = true
	for st in data["stairs"]:
		for lv in [int(st["low"]), int(st["high"])]:
			reserved[Vector3i(st["cell"].x, st["cell"].y, lv)] = true
	for id in data["entries"]:
		for c: Vector2i in data["entries"][id]:
			reserved[Vector3i(c.x, c.y, int(data["entry_levels"].get(id, 0)))] = true
	for group in data["spawns"].values():
		for spawn in group:
			if spawn is Vector2i:
				reserved[Vector3i(spawn.x, spawn.y, 0)] = true
			elif spawn is Dictionary and spawn.has("cell"):
				reserved[Vector3i(spawn["cell"].x, spawn["cell"].y, int(spawn.get("level", 0)))] = true
	for box in data["containers"].values():
		reserved[Vector3i(box["cell"].x, box["cell"].y, int(box.get("level", 0)))] = true
	for stove in data["stoves"]:
		reserved[Vector3i(stove["cell"].x, stove["cell"].y, int(stove.get("level", 0)))] = true
	return reserved


func test_assembly_props_leave_cells_and_passages_clear() -> void:
	for i in range(built.size()):
		var data: Dictionary = built[i]
		var walls: Dictionary = _assembly_structure(MAPS[i])
		var reserved: Dictionary = _assembly_reserved(data, walls)
		var occupied: Dictionary = {}
		var low_cells: Dictionary = {}
		for r: Rect2i in data["low_blocks"]:
			for c in _cells(r):
				low_cells[c] = true
		var conflicts: int = 0
		var overlaps: int = 0
		var missing_low: int = 0
		var corridors: int = 0
		for pr in data["props"]:
			var lv: int = int(pr.get("level", 0))
			var g: FieldGrid = data["levels"][lv]
			for c in _cells(pr["rect"]):
				var key := Vector3i(c.x, c.y, lv)
				# wall 소품 자체의 WALL은 허용하되 원래 건물 벽과의 겹침은 허용하지 않는다.
				if reserved.has(key) or (g.solid_at(c) == S.WALL and pr["solid"] != "wall"):
					conflicts += 1
				if occupied.has(key):
					overlaps += 1
				occupied[key] = true
				# 물은 지형이며 기존 시험대로 low_blocks에 넣지 않는다.
				if pr["solid"] == "low" and pr["kind"] != "water":
					if lv != 0 or not low_cells.has(c):
						missing_low += 1
				if (walls.has(key + Vector3i.LEFT) and walls.has(key + Vector3i.RIGHT)) or (walls.has(key + Vector3i.UP) and walls.has(key + Vector3i.DOWN)):
					corridors += 1
		assert_eq(conflicts, 0, data["place_id"] + " 벽·출입·계단·수납 겹침")
		assert_eq(overlaps, 0, data["place_id"] + " 소품끼리 겹침")
		assert_eq(missing_low, 0, data["place_id"] + " 낮은 소품 대응")
		assert_eq(corridors, 0, data["place_id"] + " 한 칸 복도")


func test_assembly_wall_building_ids_stay_inside_rects() -> void:
	for data in built:
		var rects: Dictionary = {}
		for building in data["buildings"]:
			rects[int(building["id"])] = building["rect"]
		var outside: int = 0
		for lv in data["levels"]:
			var g: FieldGrid = data["levels"][lv]
			for y in range(g.height):
				for x in range(g.width):
					var c := Vector2i(x, y)
					var id: int = g.building_at(c)
					if g.solid_at(c) == S.WALL and id >= 0:
						if not rects.has(id) or not rects[id].has_point(c):
							outside += 1
		assert_eq(outside, 0, data["place_id"] + " 건물 밖 벽 번호")


func test_assembly_container_names_have_model_suffixes() -> void:
	for data in built:
		var invalid: Array[String] = []
		for box in data["containers"].values():
			var matched: bool = false
			for suffix in CONTAINER_SUFFIXES:
				matched = matched or String(box["name"]).ends_with(suffix)
			if not matched:
				invalid.append(String(box["id"]))
		assert_true(invalid.is_empty(), data["place_id"] + " " + str(invalid))


func test_assembly_prop_kinds_match_order_and_listed_candidates() -> void:
	for data in built:
		var invalid: Dictionary = {}
		for pr in data["props"]:
			if not KINDS.has(pr["kind"]):
				invalid[pr["kind"]] = true
		assert_true(invalid.is_empty(), data["place_id"] + " " + str(invalid.keys()))


func _roman_or_han(text: String) -> bool:
	for i in range(text.length()):
		var c: int = text.unicode_at(i)
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 0x3400 and c <= 0x9FFF):
			return true
	return false
