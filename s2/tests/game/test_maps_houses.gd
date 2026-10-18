extends "res://addons/gut/test.gd"
## 지도 계약과 실제 칸을 검사한다. 가져오기와 실행은 시험 환경에서만 한다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const MAPS = [
	preload("res://game/world/maps/houses_01.gd"),
	preload("res://game/world/maps/houses_02.gd"),
	preload("res://game/world/maps/houses_03.gd"),
	preload("res://game/world/maps/houses_04.gd"),
	preload("res://game/world/maps/houses_05.gd"),
	preload("res://game/world/maps/houses_06.gd"),
]
const KEYS = [
	"grid", "levels", "stairs", "containers", "spots", "stoves", "entries",
	"entry_gap", "entry_levels", "buildings", "wagons", "train", "platform",
	"unload", "train_cars", "spawns", "labels", "trees", "low_blocks",
	"upper_rects", "lights", "manholes", "manhole_levels", "sewer_names",
	"anchors", "zone_names", "place_id", "place_kind", "bands", "train_doors",
	"crossings", "barricade_slots", "interior_kind_slots", "props", "hole_faces", "entry_names", "entry_weights", "first_entry",
]
# 원 주문 69종과 아래에 표시한 기존 북쪽 확장 후보 8종.
const KINDS = [
	"car", "handcart", "firewood_pile", "barrel", "crate_stack", "sack_pile",
	"bench", "shelf", "bed", "desk", "cold_stove", "lamp_post", "display_shelf",
	"shop_counter", "checkout", "shopping_cart", "pallet_stack", "market_stall",
	"shop_awning", "freezer_chest", "bread_rack", "blank_sign", "floor_shell",
	"stair_stub", "water", "bridge_rail", "stalled_tram", "street_tree",
	"bare_orchard_tree", "bin_bay", "playground_frame", "laundry_line",
	"garage_door", "fieldstone_wall", "hay_cart", "well_cover", "anvil_block",
	"box_truck", "fuel_pump", "ice_sled_load", "wardrobe", "door_pile",
	"dining_set", "fridge_open", "jar_shelf", "glass_cabinet", "chiller_case",
	"high_rack", "pallet_truck", "forklift", "dock_door", "dock_plate",
	"office_cabinet", "garden_rack", "butcher_block", "hardware_rack",
	"cloth_bolt_rack", "flour_sack_pile", "tin_crate", "fishing_boat",
	"net_drying_rack", "fish_crate_stack", "anchor", "rope_coil", "mooring_post",
	"net_pile", "pier_deck", "curing_barrel", "ice_block_stack",
	# 원 주문 밖 후보: 뜻이 다른 기존 낱말이므로 통일하지 않는다.
	"garden_bed", "coal_heap", "fuel_drum_stack", "lumber_stack",
	"blanket_crate", "loom", "parts_rack", "herb_drying_rack",
]
const CONTAINER_SUFFIXES = [
	"상자", "보관함", "묶음", "선반", "자재함", "궤", "찬장", "공구함", "책상", "침대", "옷장",
]
const DIRS = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var _maps: Array = []
var _paths: Array = []


func before_all() -> void:
	for script in MAPS:
		var d: Dictionary = script.build()
		_maps.append(d)
		var closed: Dictionary = {}
		for c in d["barricade_slots"]:
			closed[c] = true
		_paths.append({
			"people": _flood(d["grid"], d["train_doors"]["lower"]),
			"dead": _flood(d["grid"], d["train_doors"]["lower"], true),
			"closed": _flood(d["grid"], d["train_doors"]["lower"], false, closed),
			"levels": _levels_flood(d),
			"upper_levels": _levels_flood(d, d["train_doors"]["upper"]),
			"upper_dead": _flood(d["grid"], d["train_doors"]["upper"], true),
			"upper_closed": _flood(d["grid"], d["train_doors"]["upper"], false, closed),
		})


func after_all() -> void:
	_paths.clear()
	_maps.clear()


func _flood(g: FieldGrid, seeds: Array, dead: bool = false, blocked: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	var queue: Array[Vector2i] = []
	for value in seeds:
		var c: Vector2i = value
		if not blocked.has(c) and (g.dead_can_walk(c) if dead else g.people_can_walk(c)):
			out[c] = 0
			queue.append(c)
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for step in DIRS:
			var n: Vector2i = c + step
			if out.has(n) or blocked.has(n):
				continue
			if (g.dead_can_walk(n) if dead else g.people_can_walk(n)):
				out[n] = int(out[c]) + 1
				queue.append(n)
	return out


func _levels_flood(d: Dictionary, starts: Array = []) -> Dictionary:
	var out: Dictionary = {}
	var links: Dictionary = {}
	for s in d["stairs"]:
		for lv in [s["low"], s["high"]]:
			var c: Vector2i = s["cell"]
			var a := Vector3i(c.x, c.y, lv)
			var b := Vector3i(c.x, c.y, s["high"] if lv == s["low"] else s["low"])
			if not links.has(a):
				links[a] = []
			links[a].append(b)
	var queue: Array[Vector3i] = []
	for c in (d["train_doors"]["lower"] if starts.is_empty() else starts):
		var n := Vector3i(c.x, c.y, 0)
		queue.append(n)
		out[n] = 0
	var head := 0
	while head < queue.size():
		var at := queue[head]
		head += 1
		var candidates: Array = links.get(at, []).duplicate()
		for step in DIRS:
			candidates.append(at + Vector3i(step.x, step.y, 0))
		for value in candidates:
			var n: Vector3i = value
			var g: FieldGrid = d["levels"][n.z]
			if not out.has(n) and g.people_can_walk(Vector2i(n.x, n.y)):
				out[n] = int(out[at]) + 1
				queue.append(n)
	return out


func _cells(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2i(x, y))
	return out


func _mask(rects: Array) -> Dictionary:
	var out: Dictionary = {}
	for value in rects:
		var r: Rect2i = value
		for c in _cells(r):
			out[c] = true
	return out


func _encloses(a: Rect2i, b: Rect2i) -> bool:
	return b.size.x > 0 and b.size.y > 0 and a.encloses(b)


func _normal(g: FieldGrid, c: Vector2i, b: Rect2i) -> Vector2i:
	if c.x == b.position.x:
		return Vector2i.LEFT
	if c.x == b.end.x - 1:
		return Vector2i.RIGHT
	if c.y == b.position.y:
		return Vector2i.UP
	if c.y == b.end.y - 1:
		return Vector2i.DOWN
	if g.solid_at(c + Vector2i.UP) in [S.WALL, S.WINDOW] and g.solid_at(c + Vector2i.DOWN) in [S.WALL, S.WINDOW]:
		return Vector2i.RIGHT
	return Vector2i.DOWN


func _protected(d: Dictionary) -> Dictionary:
	var mask: Dictionary = {}
	var g: FieldGrid = d["grid"]
	for side in ["upper", "lower"]:
		for c in d["train_doors"][side]:
			for n in range(1, 4):
				mask[c + Vector2i(0, -n if side == "upper" else n)] = true
	for c in d["barricade_slots"]:
		mask[c] = true
	for id in d["entries"]:
		if int(d["entry_levels"].get(id, 0)) == 0:
			for c in d["entries"][id]:
				mask[c] = true
	for cell in g.doors:
		var c: Vector2i = cell
		var id: int = g.doors[c]["building"]
		var r: Rect2i = d["buildings"][id]["rect"]
		var n := _normal(g, c, r)
		var interior: bool = c.x > r.position.x and c.x < r.end.x - 1 and c.y > r.position.y and c.y < r.end.y - 1
		for step in range(1, 4):
			mask[c + n * step] = true
			if interior:
				mask[c - n * step] = true
	return mask


func test_exact_keys_sizes_zones_and_place_identity() -> void:
	var expected: Array = KEYS.duplicate()
	expected.sort()
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var got: Array = d.keys()
		got.sort()
		assert_eq(got, expected, "허용 열쇠만 반환한다")
		assert_eq(d["place_id"], "houses_%02d" % (i + 1))
		assert_eq(d["place_kind"], "houses")
		var g: FieldGrid = d["grid"]
		assert_between(g.width, 150, 180)
		assert_between(g.height, 135, 155)
		assert_between(d["zone_names"].size(), 8, 12)
		var used: Dictionary = {}
		for z in g.zone:
			used[z] = true
		assert_between(used.size(), 8, 12)
		for z in used:
			assert_true(d["zone_names"].has(z), "모든 칸의 구역 이름")
		for z in d["zone_names"]:
			assert_true(used.has(z), "빈 이름만 등록한 구역은 없다")


func test_train_platform_band_and_clear_doors() -> void:
	for d in _maps:
		var g: FieldGrid = d["grid"]
		var bounds := Rect2i(0, 0, g.width, g.height)
		var train: Rect2i = d["train"]
		var tx: int = train.position.x
		assert_eq(train, Rect2i(16, 46, 80, 3))
		assert_eq(d["platform"], Rect2i(tx, 49, 82, 6))
		assert_eq(d["unload"], Rect2i(tx, 49, 82, 3))
		assert_eq(d["bands"].size(), 2)
		assert_eq(d["bands"]["lower"], Rect2i(tx - 20, 49, 120, 26).intersection(bounds))
		assert_eq(d["bands"]["upper"], Rect2i(tx - 20, 24, 120, 22).intersection(bounds))
		assert_false(d["bands"]["upper"].intersects(d["bands"]["lower"]))
		assert_eq(d["train_doors"].size(), 2)
		assert_eq(d["train_doors"]["lower"], d["spawns"]["train_door"])
		assert_eq(d["train_doors"]["upper"].size(), d["train_doors"]["lower"].size())
		var door_x: Dictionary = {}
		for side in ["upper", "lower"]:
			assert_true(bounds.encloses(d["bands"][side]))
			assert_gte(d["train_doors"][side].size(), 3)
			for c: Vector2i in d["train_doors"][side]:
				assert_eq(c.y, 45 if side == "upper" else 49)
				assert_between(c.x, tx + 2, train.end.x - 3)
				assert_eq(g.solid_at(c), S.NONE)
				assert_true(d["train_doors"]["lower"].has(Vector2i(c.x, 49)))
				assert_true(d["barricade_slots"].has(c + Vector2i.UP if side == "upper" else c + Vector2i.DOWN))
				door_x[c.x] = true
			var strip := Rect2i(tx, 43 if side == "upper" else 49, 80, 3)
			for c in _cells(strip):
				assert_eq(g.solid_at(c), S.NONE, "승차 세 줄은 빈 보행 칸")
				assert_true(g.people_can_walk(c))
			for p in d["props"]:
				if int(p.get("level", 0)) == 0:
					assert_false(strip.intersects(p["rect"]), "장식도 승차 구역 밖")
		for c in d["spawns"]["squad"]:
			assert_true(d["bands"]["lower"].has_point(c))
		for side in [0, 1]:
			var clear_columns := 0
			for x in range(0 if side == 0 else train.end.x, tx if side == 0 else g.width):
				var clear := true
				for y in range(46, 49):
					clear = clear and g.people_can_walk(Vector2i(x, y))
				if clear:
					clear_columns += 1
			assert_gte(clear_columns, 4)
		for x in range(g.width):
			for y in range(46, 49):
				assert_eq(g.floor_at(Vector2i(x, y)), F.RAIL)
		assert_eq(d["crossings"].size(), 2)
		var crossing_x: Dictionary = {}
		var who := {"person": true, "zombie": false, "carrying": true, "wounded": false, "sled": false}
		for crossing in d["crossings"]:
			var cs: Array = crossing["cells"]
			assert_eq(cs.size(), 3)
			if cs.size() != 3:
				continue
			var x: int = cs[0].x
			assert_true([tx + 16, tx + 32, tx + 48].has(x))
			assert_false(door_x.has(x))
			assert_false(crossing_x.has(x))
			crossing_x[x] = true
			assert_eq(cs, [Vector2i(x, 46), Vector2i(x, 47), Vector2i(x, 48)])
			for c in cs:
				assert_eq(g.solid_at(c), S.BLOCK)
				assert_false(g.people_can_walk(c))
				assert_false(g.dead_can_walk(c))
			assert_eq(g.solid_at(Vector2i(x, 45)), S.NONE)
			assert_eq(g.solid_at(Vector2i(x, 49)), S.NONE)
			assert_eq(crossing["who"], who)
		assert_eq(d["train_cars"].size(), 5)
		assert_eq(d["train_cars"][-1]["kind"], "engine")


func test_entries_holes_and_initial_dead_are_reachable_outside_band() -> void:
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var g: FieldGrid = d["grid"]
		var edge_counts := {"upper": 0, "lower": 0}
		assert_lte(d["manholes"].size(), 4)
		for id in d["entries"]:
			assert_true(d["entry_gap"].has(id))
			assert_gt(float(d["entry_gap"][id]), 0.0)
			assert_lte(float(d["entry_gap"][id]), 3.0)
			var cs: Array = d["entries"][id]
			assert_false(cs.is_empty())
			if cs.is_empty():
				continue
			var side: String = "upper" if cs[0].y < 46 else "lower"
			var paths: Dictionary = _paths[i]["upper_dead" if side == "upper" else "dead"]
			if not d["manholes"].has(id):
				edge_counts[side] += 1
				assert_between(cs.size(), 2, 4)
				for c: Vector2i in cs:
					assert_true(c.x == 0 or c.x == g.width - 1 or c.y == 0 or c.y == g.height - 1)
					assert_eq(c.y < 46, side == "upper")
			for c in cs:
				for band in d["bands"].values():
					assert_false(band.has_point(c))
				if int(d["entry_levels"].get(id, 0)) == 0:
					assert_true(paths.has(c), "%s에서 같은 쪽 열차 문까지 망자 보행" % id)
		assert_between(int(edge_counts["upper"]), 2, 3)
		assert_between(int(edge_counts["lower"]), 3, 5)
		for id in d["manholes"]:
			var c: Vector2i = d["manholes"][id]
			assert_true(d["entries"].has(id))
			assert_true(d["entries"][id].has(c))
			assert_true(d["sewer_names"].has(id))
			assert_true(d["entry_gap"].has(id))
			if d["manhole_levels"].has(id):
				assert_eq(d["manhole_levels"][id], -1)
				assert_eq(d["entry_levels"].get(id, 99), -1)
				var reached := _flood(d["levels"][-1], [c], true)
				var has_stair := false
				for s in d["stairs"]:
					if s["low"] == -1 and reached.has(s["cell"]):
						has_stair = true
				assert_true(has_stair)
			else:
				var paths: Dictionary = _paths[i]["upper_dead" if c.y < 46 else "dead"]
				assert_true(paths.has(c))
				for side in ["upper", "lower"]:
					for door_cell in d["train_doors"][side]:
						assert_gt(Vector2(c).distance_to(Vector2(door_cell)), 25.0)
			if String(id).begins_with("culvert_"):
				assert_true(DIRS.has(d["hole_faces"].get(id, Vector2i.ZERO)))
			assert_eq(float(d["entry_gap"][id]), 3.0 if String(id).begins_with("manhole_") else 0.6)
		for id in d["spawns"]:
			if not String(id).begins_with("dead_"):
				continue
			for row in d["spawns"][id]:
				var c: Vector2i = row[0] if id == "dead_levels" else row
				var lv: int = row[1] if id == "dead_levels" else 0
				for band in d["bands"].values():
					assert_false(band.has_point(c))
				assert_true(d["levels"][lv].dead_can_walk(c))


func test_all_ground_and_zones_remain_reachable_with_barricades() -> void:
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var g: FieldGrid = d["grid"]
		var reached: Dictionary = _paths[i]["people"]
		var side_zones := {"upper": {}, "lower": {}}
		var missing := 0
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				if g.people_can_walk(c) and not reached.has(c):
					missing += 1
				for side in ["upper", "lower"]:
					if _paths[i]["upper_closed" if side == "upper" else "closed"].has(c):
						side_zones[side][g.zone_at(c)] = true
		assert_eq(missing, 0, "모든 일층 보행 칸은 열차 끝을 돌아 이어진다")
		for zone in MAPS[i].PLAN["zones"]:
			assert_true(side_zones["lower"].has(zone["id"]))
		for zone in MAPS[i].NORTH["zones"]:
			assert_true(side_zones["upper"].has(zone["id"]))
		for c in d["barricade_slots"]:
			assert_true(g.people_can_walk(c))
		assert_true(d["spots"].has("work_site"))
		var work: Dictionary = d["spots"]["work_site"]
		assert_true(work["zone_rect"].has_point(work["cell"]))
		assert_true(g.people_can_walk(work["cell"]))
		assert_true(Rect2i(0, 0, g.width, g.height).encloses(work["zone_rect"]))


func test_low_cover_water_and_visible_blockers() -> void:
	for d in _maps:
		var g: FieldGrid = d["grid"]
		for side in ["upper", "lower"]:
			_assert_cover(d, side)
		var low := _mask(d["low_blocks"])
		var water: Dictionary = {}
		for p in d["props"]:
			if p["kind"] == "water":
				assert_eq(p["solid"], "low")
				assert_false(d["low_blocks"].has(p["rect"]))
				for c in _cells(p["rect"]):
					water[c] = true
					assert_eq(g.solid_at(c), S.LOW)
					assert_eq(g.floor_at(c), F.ICE)
		for stove in d["stoves"]:
			if int(stove.get("level", 0)) == 0:
				low[stove["cell"]] = true
		var block := _mask([d["train"]])
		for w in d["wagons"]:
			block.merge(_mask([w["rect"]]))
		for c in d["trees"]:
			block[c] = true
		var invisible := 0
		var unknown_low := 0
		var longest := 0
		for y in range(g.height):
			var run := 0
			for x in range(g.width):
				var c := Vector2i(x, y)
				if g.solid_at(c) == S.LOW:
					if not low.has(c) and not water.has(c):
						unknown_low += 1
				if g.solid_at(c) == S.BLOCK and g.building_at(c) < 0:
					if not block.has(c) or (x < 14 and y < 14):
						invisible += 1
				run = run + 1 if g.solid_at(c) == S.LOW and not water.has(c) else 0
				longest = maxi(longest, run)
		for x in range(g.width):
			var run := 0
			for y in range(g.height):
				var c := Vector2i(x, y)
				run = run + 1 if g.solid_at(c) == S.LOW and not water.has(c) else 0
				longest = maxi(longest, run)
		assert_eq(unknown_low, 0)
		assert_eq(invisible, 0)
		assert_lte(longest, 10)
		var north_trees := 0
		var south_trees := 0
		for c: Vector2i in d["trees"]:
			if c.y < 46:
				north_trees += 1
			else:
				south_trees += 1
		assert_between(north_trees, 12, 30)
		assert_between(south_trees, 25, 60)


func test_buildings_have_interiors_and_deep_and_shallow_loot() -> void:
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var g: FieldGrid = d["grid"]
		var counts := {"upper": 0, "lower": 0}
		var accessible := 0
		var large := 0
		for id in range(d["buildings"].size()):
			var b: Dictionary = d["buildings"][id]
			var r: Rect2i = b["rect"]
			var side: String = "upper" if r.position.y < 46 else "lower"
			counts[side] += 1
			assert_eq(b["id"], id)
			if side == "upper":
				assert_false(r.intersects(d["bands"]["upper"]))
			var entrance := false
			for c in g.doors:
				if g.doors[c]["building"] == id and (c.x == r.position.x or c.x == r.end.x - 1 or c.y == r.position.y or c.y == r.end.y - 1):
					entrance = true
			if entrance:
				accessible += 1
			var inner := Rect2i(r.position + Vector2i.ONE, r.size - Vector2i(2, 2))
			var area: int = inner.size.x * inner.size.y
			if area >= 600:
				large += 1
			if area > 60:
				var has_wall := false
				for c in _cells(inner):
					if g.solid_at(c) == S.WALL:
						has_wall = true
				assert_true(has_wall)
		assert_between(int(counts["upper"]), 6, 9)
		assert_between(int(counts["lower"]), 14, 22)
		assert_gte(float(accessible) / d["buildings"].size(), 0.7)
		assert_gte(large, 1)
		assert_eq(d["interior_kind_slots"].size(), 3)
		var slot_zones: Dictionary = {}
		var north_zones: Dictionary = {}
		for z in MAPS[i].NORTH["zones"]:
			north_zones[z["id"]] = true
		var northern_slot_count := 0
		for slot in d["interior_kind_slots"]:
			assert_false(slot_zones.has(slot["zone"]))
			slot_zones[slot["zone"]] = true
			assert_true(d["zone_names"].has(slot["zone"]))
			assert_eq(slot["kinds"], ["empty", "raiders", "nest", "beasts"])
			if north_zones.has(slot["zone"]):
				northern_slot_count += 1
		assert_eq(northern_slot_count, 1)
		var deep_zones: Dictionary = {}
		var target_deep: int = MAPS[i].NORTH["buildings"][MAPS[i].NORTH["deep"]]["id"]
		for side in ["upper", "lower"]:
			var distances: Dictionary = _paths[i]["upper_levels" if side == "upper" else "levels"]
			var nearest := 999999
			var farthest := -1
			var farthest_target := -1
			var farthest_ordinary := -1
			var unreachable := 0
			for box in d["containers"].values():
				var c: Vector2i = box["cell"]
				if (c.y < 46) != (side == "upper"):
					continue
				for item in box["items"]:
					assert_true(["plank", "food_pack", "scrap", "cloth", "needle_thread", "bottle_spirit", "med_box", "bandage", "tweezers"].has(item))
				var at := Vector3i(c.x, c.y, int(box.get("level", 0)))
				if not distances.has(at):
					unreachable += 1
					continue
				var steps: int = distances[at]
				nearest = mini(nearest, steps)
				farthest = maxi(farthest, steps)
				if side == "upper":
					if int(box["building"]) == target_deep:
						farthest_target = maxi(farthest_target, steps)
					else:
						farthest_ordinary = maxi(farthest_ordinary, steps)
				if bool(box["locked"]) and steps >= (45 if side == "upper" else 80):
					deep_zones[g.zone_at(c)] = true
			assert_eq(unreachable, 0)
			assert_lte(nearest, 25 if side == "upper" else 40)
			assert_gte(farthest, 45 if side == "upper" else 80)
			if side == "upper":
				assert_gt(farthest_target, farthest_ordinary, "지정된 깊은 자리가 실제로 가장 멀다")
		for zone in slot_zones:
			assert_true(deep_zones.has(zone))


func test_levels_stairs_and_floor_shells() -> void:
	for d in _maps:
		for lv in [-1, 0, 1, 2]:
			assert_true(d["levels"].has(lv))
			var g: FieldGrid = d["levels"][lv]
			assert_eq(g.width, d["grid"].width)
			assert_eq(g.height, d["grid"].height)
			var count := 0
			for y in range(g.height):
				for x in range(g.width):
					var c := Vector2i(x, y)
					if g.people_can_walk(c):
						count += 1
						if lv != 0:
							assert_gte(g.building_at(c), 0)
			assert_gt(count, 0)
		for s in d["stairs"]:
			assert_eq(s["high"], s["low"] + 1)
			assert_true(d["levels"][s["low"]].people_can_walk(s["cell"]))
			assert_true(d["levels"][s["high"]].people_can_walk(s["cell"]))
		for p in d["props"]:
			if p["kind"] != "floor_shell":
				continue
			var owner := -1
			for b in d["buildings"]:
				if b["rect"] == p["rect"]:
					owner = b["id"]
			assert_gte(owner, 0)
			var stubs := 0
			for q in d["props"]:
				if q["kind"] == "stair_stub" and int(q.get("level", 0)) == 2 and _encloses(p["rect"], q["rect"]):
					assert_eq(q["rect"].size, Vector2i(1, 2))
					stubs += 1
			assert_eq(stubs, 1)


func test_props_contract_and_door_entry_clearance() -> void:
	for d in _maps:
		var g: FieldGrid = d["grid"]
		var bounds := Rect2i(0, 0, g.width, g.height)
		var guarded := _protected(d)
		var inside := 0
		var north_count := 0
		var north_inside := 0
		var overlaps := 0
		assert_gte(d["props"].size(), 130)
		for p in d["props"]:
			assert_true(KINDS.has(p["kind"]))
			assert_true(["low", "wall", "tree", "wagon", "none"].has(p["solid"]))
			var r: Rect2i = p["rect"]
			assert_true(_encloses(bounds, r))
			if r.position.y < 46:
				north_count += 1
			var lv: int = p.get("level", 0)
			assert_between(lv, -1, 3)
			assert_between(int(p["facing"]), 0, 3)
			if lv == 3:
				assert_eq(p["kind"], "floor_shell")
			if lv != 0:
				assert_eq(p["solid"], "none")
			for b in d["buildings"]:
				if _encloses(b["rect"], r):
					inside += 1
					if r.position.y < 46:
						north_inside += 1
					break
			if lv != 0:
				continue
			if p["solid"] == "low" and p["kind"] != "water":
				assert_true(d["low_blocks"].has(r))
			if p["solid"] == "wall":
				for c in _cells(r):
					assert_eq(g.solid_at(c), S.WALL)
			if p["solid"] == "tree":
				assert_eq(r.size, Vector2i.ONE)
				assert_true(d["trees"].has(r.position))
			for c in _cells(r):
				if guarded.has(c):
					overlaps += 1
		assert_gte(inside * 2, d["props"].size())
		assert_gte(north_count, 40)
		assert_gte(north_inside * 2, north_count)
		assert_eq(overlaps, 0, "장식도 문 앞과 진입 칸을 덮지 않는다")


func test_asymmetry_unique_grids_comments_and_korean_names() -> void:
	var name_pattern := RegEx.new()
	assert_eq(name_pattern.compile("[A-Za-z㐀-鿿]"), OK)
	var comments: Dictionary = {}
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var g: FieldGrid = d["grid"]
		var same := 0
		var total := 0
		for y in range(g.height):
			for x in range(g.width):
				var value: int = g.solid_at(Vector2i(x, y))
				if value in [S.WALL, S.BLOCK, S.LOW, S.WINDOW]:
					total += 1
					if value == g.solid_at(Vector2i(g.width - 1 - x, y)):
						same += 1
		assert_gt(total, 0)
		assert_lt(float(same) / total, 0.5)
		var folded := 0
		var northern_solids := 0
		for offset in range(1, 46):
			for x in range(g.width):
				var value: int = g.solid_at(Vector2i(x, 46 - offset))
				if value in [S.WALL, S.BLOCK, S.LOW, S.WINDOW]:
					northern_solids += 1
					if value == g.solid_at(Vector2i(x, 48 + offset)):
						folded += 1
		assert_gt(northern_solids, 0)
		assert_lt(float(folded) / northern_solids, 0.5)
		var src: String = FileAccess.get_file_as_string("res://game/world/maps/houses_%02d.gd" % (i + 1))
		var first: String = src.get_slice("\n", 0)
		assert_true(first.begins_with("# 이 지도가 다른 판단을 만드는 것: "))
		assert_false(comments.has(first))
		comments[first] = true
		var second: String = src.get_slice("\n", 1)
		assert_true(second.begins_with("# 위쪽의 판단: "))
		assert_false(comments.has(second))
		comments[second] = true
		assert_eq(second.strip_edges(), "# 위쪽의 판단: " + String(MAPS[i].NORTH["judgment"]))
		assert_false(src.contains("sulehuf_map.gd"))
		for j in range(i):
			var other: FieldGrid = _maps[j]["grid"]
			assert_false(g.width == other.width and g.height == other.height and g.solid == other.solid and g.floor == other.floor)
			var identical_north := true
			for y in range(46):
				for x in range(mini(g.width, other.width)):
					var c := Vector2i(x, y)
					if g.solid_at(c) != other.solid_at(c) or g.floor_at(c) != other.floor_at(c):
						identical_north = false
			assert_false(identical_north)
		var names: Array = []
		for b in d["buildings"]:
			names.append(b["name"])
		names.append_array(d["zone_names"].values())
		names.append_array(d["sewer_names"].values())
		for box in d["containers"].values():
			names.append(box["name"])
		for p in d["props"]:
			names.append(p["note"])
		for name in names:
			assert_false(String(name).is_empty())
			assert_null(name_pattern.search(String(name)), "설비 이름과 물건 설명은 한국어다")


func test_every_thirty_by_twenty_view_has_structure_or_floor_change() -> void:
	# Summed-area tables keep this exhaustive check linear in the map area.
	for d in _maps:
		var g: FieldGrid = d["grid"]
		var stride: int = g.width + 1
		var occupied := PackedInt32Array()
		occupied.resize(stride * (g.height + 1))
		var floors: Array = []
		for kind in range(8):
			var table := PackedInt32Array()
			table.resize(stride * (g.height + 1))
			floors.append(table)
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				var at: int = (y + 1) * stride + x + 1
				occupied[at] = occupied[at - 1] + occupied[at - stride] - occupied[at - stride - 1] + (1 if g.solid_at(c) != S.NONE else 0)
				for kind in range(8):
					floors[kind][at] = floors[kind][at - 1] + floors[kind][at - stride] - floors[kind][at - stride - 1] + (1 if g.floor_at(c) == kind else 0)
		var empty := 0
		for y in range(g.height - 19):
			for x in range(g.width - 29):
				var a: int = y * stride + x
				var b: int = a + 30
				var c: int = a + 20 * stride
				var e: int = c + 30
				if occupied[e] - occupied[b] - occupied[c] + occupied[a] != 0:
					continue
				var kind: int = g.floor_at(Vector2i(x, y))
				if floors[kind][e] - floors[kind][b] - floors[kind][c] + floors[kind][a] == 600:
					empty += 1
		assert_eq(empty, 0)


func test_market_stock_and_pier_have_their_own_structure() -> void:
	var market: Dictionary = _maps[4]
	var counts: Dictionary = {}
	for p in market["props"]:
		if int(p.get("level", 0)) == 0 and p["rect"].position.y >= 46:
			counts[p["kind"]] = int(counts.get(p["kind"], 0)) + 1
	assert_gte(int(counts.get("display_shelf", 0)), 12)
	assert_between(int(counts.get("checkout", 0)), 5, 7)
	assert_between(int(counts.get("car", 0)), 18, 23)
	assert_eq(int(counts.get("dock_door", 0)), 3)
	var quay: Dictionary = _maps[5]
	var cut: Dictionary = {}
	for x in range(62, 65):
		cut[Vector2i(x, 115)] = true
	var reached := _flood(quay["grid"], quay["train_doors"]["lower"], false, cut)
	assert_false(reached.has(Vector2i(63, 119)), "잔교를 끊으면 끝 판의 다른 입구는 없다")
	assert_eq(_maps[2]["manholes"].size(), 4)
	assert_eq(quay["manholes"].size(), 4)
	for d in _maps:
		var initial := 0
		for id in d["spawns"]:
			if String(id).begins_with("dead_"):
				initial += d["spawns"][id].size()
		assert_lte(initial, 60, "초기 배치 상한이며 이후 유입량의 실시간 보증은 아니다")


func test_barricades_cross_actual_four_to_six_cell_gaps() -> void:
	for d in _maps:
		var g: FieldGrid = d["grid"]
		var mouths := {"upper": {}, "lower": {}}
		for cell in d["barricade_slots"]:
			var c: Vector2i = cell
			if c.y == 44 or c.y == 50:
				assert_true(g.people_can_walk(c))
				continue
			var left: int = c.x
			var right: int = c.x
			while left > 0 and g.people_can_walk(Vector2i(left - 1, c.y)) and g.building_at(Vector2i(left - 1, c.y)) < 0:
				left -= 1
			while right < g.width - 1 and g.people_can_walk(Vector2i(right + 1, c.y)) and g.building_at(Vector2i(right + 1, c.y)) < 0:
				right += 1
			assert_between(right - left + 1, 4, 6)
			assert_false(g.people_can_walk(Vector2i(left - 1, c.y)))
			assert_false(g.people_can_walk(Vector2i(right + 1, c.y)))
			var side: String = "upper" if c.y < 46 else "lower"
			var mouth := Rect2i(left, c.y, right - left + 1, 1)
			mouths[side][mouth] = int(mouths[side].get(mouth, 0)) + 1
		for side in ["upper", "lower"]:
			assert_between(mouths[side].size(), 2, 3)
			for count in mouths[side].values():
				assert_between(int(count), 2, 3)


func test_farm_gate_closure_preserves_building_escape_routes() -> void:
	var d: Dictionary = _maps[2]
	var gates: Array = [Rect2i(53, 28, 1, 4), Rect2i(77, 30, 4, 1), Rect2i(36, 40, 1, 4), Rect2i(12, 75, 4, 1), Rect2i(48, 76, 4, 1), Rect2i(107, 85, 1, 4)]
	for i in range(gates.size()):
		gates[i] = Rect2i(gates[i].position + Vector2i(0, 45), gates[i].size)
	var blocked := _mask(gates)
	assert_eq(blocked.size(), 24)
	var reached := _flood(d["grid"], d["train_doors"]["lower"], false, blocked)
	var missing := 0
	for c in _paths[2]["people"]:
		if not blocked.has(c) and not reached.has(c):
			missing += 1
	assert_eq(missing, 0, "대문 여섯을 막아도 건물 안으로 빠져나갈 수 있다")


func _assert_cover(d: Dictionary, side: String) -> void:
	var band: Rect2i = d["bands"][side]
	var covers: Array = []
	for r: Rect2i in d["low_blocks"]:
		if r.intersects(band):
			covers.append(r)
	assert_between(covers.size(), 3, 5)
	var near := 0
	var shapes: Dictionary = {}
	for r: Rect2i in covers:
		assert_between(maxi(r.size.x, r.size.y), 2, 6)
		shapes[r.size] = true
		var close := false
		for c in _cells(r):
			for door_cell in d["train_doors"][side]:
				if Vector2(c).distance_to(Vector2(door_cell)) <= 12.0:
					close = true
		if close:
			near += 1
	assert_gte(near, 2)
	assert_gte(shapes.size(), 2)

func test_north_rooms_shops_and_deep_forecourt() -> void:
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var plan: Dictionary = MAPS[i].NORTH
		var largest_id := -1
		var largest_area := 0
		for row in plan["buildings"]:
			var r: Rect2i = d["buildings"][row["id"]]["rect"]
			if r.size.x * r.size.y > largest_area:
				largest_area = r.size.x * r.size.y
				largest_id = row["id"]
			if row["role"] == "shop":
				var front := false
				var back := false
				var counter := false
				var display := false
				for c in d["grid"].doors:
					if d["grid"].doors[c]["building"] == row["id"]:
						front = front or c.y == r.end.y - 1
						back = back or c.y == r.position.y
				for p in d["props"]:
					if int(p.get("level", 0)) == 0 and r.encloses(p["rect"]):
						counter = counter or p["kind"] == "shop_counter"
						display = display or p["kind"] in ["display_shelf", "glass_cabinet"]
				assert_true(front and back and counter and display, "가게의 매장과 뒷문")
		var largest_rooms := 0
		var furnished_groups := 0
		for room in plan["rooms"]:
			var a: Array = room["rect"]
			var r := Rect2i(a[0], a[1], a[2], a[3])
			var lv: int = room["level"]
			var building: Rect2i = d["buildings"][room["building"]]["rect"]
			assert_true(building.encloses(r))
			assert_gte(r.size.x, 3)
			assert_gte(r.size.y, 3)
			if room["building"] == largest_id and lv == 0:
				largest_rooms += 1
			var objects := 0
			var prop_count := 0
			var kinds: Dictionary = {}
			for p in d["props"]:
				if int(p.get("level", 0)) == lv and r.encloses(p["rect"]):
					objects += 1
					prop_count += 1
					kinds[p["kind"]] = int(kinds.get(p["kind"], 0)) + 1
			for box in d["containers"].values():
				if int(box.get("level", 0)) == lv and r.has_point(box["cell"]):
					objects += 1
			assert_gt(objects, 0, "위층과 지하를 포함한 방마다 물건")
			if prop_count >= 3 and prop_count <= 6:
				furnished_groups += 1
			for kind in kinds:
				if kind != "display_shelf" and kind != "shelf":
					assert_lte(int(kinds[kind]), 4)
			var grid: FieldGrid = d["levels"][lv]
			for c in _cells(r):
				assert_eq(grid.building_at(c), room["building"])
		assert_gte(largest_rooms, 6)
		assert_gte(furnished_groups, 5)
		var biggest: Rect2i = d["buildings"][largest_id]["rect"]
		for y in range(biggest.end.y - 3, biggest.end.y - 1):
			for x in range(biggest.position.x + 1, biggest.end.x - 1):
				assert_true(d["grid"].people_can_walk(Vector2i(x, y)), "가장 큰 건물의 두 칸 복도")
		var deep_id: int = plan["buildings"][plan["deep"]]["id"]
		var deep: Rect2i = d["buildings"][deep_id]["rect"]
		var checked := false
		for c in d["grid"].doors:
			if d["grid"].doors[c]["building"] != deep_id:
				continue
			if c.x > deep.position.x and c.x < deep.end.x - 1 and c.y > deep.position.y and c.y < deep.end.y - 1:
				continue
			var court := _front_court(c, deep)
			for point in _cells(court):
				assert_eq(d["grid"].solid_at(point), S.NONE)
			for p in d["props"]:
				if int(p.get("level", 0)) == 0:
					assert_false(court.intersects(p["rect"]))
			checked = true
		assert_true(checked)


func test_south_rows_match_original_except_recorded_tree_moves() -> void:
	for i in range(_maps.size()):
		# 원래 PLAN과 보정 전 생성 경로를 기준으로 비교한다.
		# 옛 맨 위 줄은 새 북쪽 승차 바닥이므로 열차 아래부터 비교한다.
		var original: Dictionary = MAPS[i]._build_south(false)
		var current: Dictionary = _maps[i]
		var moved: Dictionary = {}
		for row in MAPS[i].SOUTH_TREE_MOVES:
			moved[Vector2i(row[0][0], row[0][1])] = true
			moved[Vector2i(row[1][0], row[1][1])] = true
		for lv in [-1, 0, 1, 2]:
			var old_grid: FieldGrid = original["levels"][lv]
			var new_grid: FieldGrid = current["levels"][lv]
			assert_eq(new_grid.height, old_grid.height + 45)
			assert_eq(new_grid.width, old_grid.width)
			var solids_changed := 0
			var floors_changed := 0
			var metadata_changed := 0
			for y in range(1, old_grid.height):
				for x in range(old_grid.width):
					var before := Vector2i(x, y)
					var after := before + Vector2i(0, 45)
					if old_grid.floor_at(before) != new_grid.floor_at(after):
						floors_changed += 1
					if not (lv == 0 and moved.has(before)) and old_grid.solid_at(before) != new_grid.solid_at(after):
						solids_changed += 1
					if old_grid.building_at(before) != new_grid.building_at(after) or old_grid.zone_at(before) != new_grid.zone_at(after):
						metadata_changed += 1
			assert_eq(solids_changed, 0)
			assert_eq(floors_changed, 0)
			assert_eq(metadata_changed, 0)
			for c in old_grid.doors:
				assert_true(new_grid.doors.has(c + Vector2i(0, 45)))
				assert_eq(new_grid.doors[c + Vector2i(0, 45)]["state"], old_grid.doors[c]["state"])
				assert_eq(new_grid.doors[c + Vector2i(0, 45)]["cell"], c + Vector2i(0, 45))
			for c in old_grid.windows:
				assert_true(new_grid.windows.has(c + Vector2i(0, 45)))
				assert_eq(new_grid.windows[c + Vector2i(0, 45)]["cell"], c + Vector2i(0, 45))

func _front_court(c: Vector2i, r: Rect2i) -> Rect2i:
	if c.x == r.position.x:
		return Rect2i(c.x - 4, c.y - 2, 4, 5)
	if c.x == r.end.x - 1:
		return Rect2i(c.x + 1, c.y - 2, 4, 5)
	if c.y == r.position.y:
		return Rect2i(c.x - 2, c.y - 4, 5, 4)
	return Rect2i(c.x - 2, c.y + 1, 5, 4)


func test_entry_names_weights_and_first_entry() -> void:
	for n in range(1, 7):
		var d: Dictionary = load("res://game/world/maps/houses_%02d.gd" % n).build()
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


# 조립 검사: 건물 벽은 원자료에서도 읽어 소품이 덮어 쓴 벽을 놓치지 않는다.
func _assembly_reserved(d: Dictionary, script: Script) -> Dictionary:
	var blocked := {-1: {}, 0: {}, 1: {}, 2: {}, 3: {}}
	var consts: Dictionary = script.get_script_constant_map()
	for section in [[consts["PLAN"], 45], [consts["NORTH"], 0]]:
		var plan: Dictionary = section[0]
		var offset := Vector2i(0, int(section[1]))
		for row in plan["shells"]:
			var a: Array = row["rect"]
			var r := Rect2i(a[0], a[1], a[2], a[3])
			for c in _cells(r):
				if c.x in [r.position.x, r.end.x - 1] or c.y in [r.position.y, r.end.y - 1]:
					blocked[row["level"]][c + offset] = true
		for row in plan["walls"]:
			var a: Array = row["rect"]
			for c in _cells(Rect2i(a[0], a[1], a[2], a[3])):
				blocked[row["level"]][c + offset] = true
	for lv in d["levels"]:
		var g: FieldGrid = d["levels"][lv]
		for c: Vector2i in g.doors:
			blocked[lv][c] = true
			var r: Rect2i = d["buildings"][g.doors[c]["building"]]["rect"]
			var normal := _normal(g, c, r)
			blocked[lv][c + normal] = true
			blocked[lv][c - normal] = true
		for c in g.windows:
			blocked[lv][c] = true
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				if g.solid_at(c) != S.NONE:
					continue
				var sides := [S.WALL, S.BLOCK, S.WINDOW, S.AIR]
				if (g.solid_at(c + Vector2i.LEFT) in sides and g.solid_at(c + Vector2i.RIGHT) in sides) or (g.solid_at(c + Vector2i.UP) in sides and g.solid_at(c + Vector2i.DOWN) in sides):
					blocked[lv][c] = true
	for stair in d["stairs"]:
		blocked[stair["low"]][stair["cell"]] = true
		blocked[stair["high"]][stair["cell"]] = true
	for box in d["containers"].values():
		blocked[int(box.get("level", 0))][box["cell"]] = true
	for stove in d["stoves"]:
		blocked[int(stove.get("level", 0))][stove["cell"]] = true
	for id in d["entries"]:
		var lv: int = int(d["entry_levels"].get(id, 0))
		for c in d["entries"][id]:
			blocked[lv][c] = true
	for group in d["spawns"].values():
		for value in group:
			if value is Vector2i:
				blocked[0][value] = true
			elif value is Dictionary:
				blocked[int(value.get("level", 0))][value["cell"]] = true
	for c in d["barricade_slots"]:
		blocked[0][c] = true
	for side in d["train_doors"]:
		for c: Vector2i in d["train_doors"][side]:
			for step in range(4):
				blocked[0][c + Vector2i(0, -step if side == "upper" else step)] = true
	blocked[0].merge(_protected(d))
	return blocked


func test_assembly_props_leave_structures_and_reserved_cells_clear() -> void:
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var blocked := _assembly_reserved(d, MAPS[i])
		var occupied := {-1: {}, 0: {}, 1: {}, 2: {}, 3: {}}
		var reserved_hits := 0
		var wall_hits := 0
		var prop_hits := 0
		var unpaired_low := 0
		for p in d["props"]:
			var lv: int = int(p.get("level", 0))
			var r: Rect2i = p["rect"]
			for c in _cells(r):
				if blocked[lv].has(c):
					reserved_hits += 1
				if occupied[lv].has(c):
					prop_hits += 1
				occupied[lv][c] = true
				# 높은 소품이 스스로 만드는 WALL과 건물 벽의 겹침을 구분한다.
				if d["levels"].has(lv) and p["solid"] != "wall":
					var g: FieldGrid = d["levels"][lv]
					if g.solid_at(c) == S.WALL:
						wall_hits += 1
			# 물은 기존 지형 계약을 보존한다. 모든 LOW 조건과의 충돌은 결과 글에 남긴다.
			if p["solid"] == "low" and p["kind"] != "water" and not d["low_blocks"].has(r):
				unpaired_low += 1
		assert_eq(reserved_hits, 0, d["place_id"] + ": 벽·문·창·계단·예약 칸")
		assert_eq(wall_hits, 0, d["place_id"] + ": 실제 WALL 겹침")
		assert_eq(prop_hits, 0, d["place_id"] + ": 같은 층 소품 겹침")
		assert_eq(unpaired_low, 0, d["place_id"] + ": 낮은 소품과 low_blocks")


func test_assembly_numbered_walls_stay_inside_their_building() -> void:
	for d in _maps:
		var outside := 0
		for g: FieldGrid in d["levels"].values():
			for y in range(g.height):
				for x in range(g.width):
					var c := Vector2i(x, y)
					var id: int = g.building_at(c)
					if g.solid_at(c) == S.WALL and id >= 0:
						if id >= d["buildings"].size() or not d["buildings"][id]["rect"].has_point(c):
							outside += 1
		assert_eq(outside, 0, d["place_id"] + ": 건물 바깥 WALL 번호")


func test_assembly_container_names_have_model_suffixes() -> void:
	for d in _maps:
		for box in d["containers"].values():
			var valid := false
			for suffix in CONTAINER_SUFFIXES:
				valid = valid or String(box["name"]).ends_with(suffix)
			assert_true(valid, d["place_id"] + ": " + String(box["id"]) + " " + String(box["name"]))


func test_assembly_prop_kinds_match_order_and_recorded_candidates() -> void:
	for d in _maps:
		for p in d["props"]:
			assert_true(KINDS.has(p["kind"]), d["place_id"] + ": " + String(p["kind"]))
