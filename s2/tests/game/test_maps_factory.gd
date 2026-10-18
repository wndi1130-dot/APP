extends "res://addons/gut/test.gd"
## 북쪽 증설의 계약 검사. 실행은 가져오기가 허용된 CI에서 한다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const MAPS: Array = [
	preload("res://game/world/maps/factory_01.gd"),
	preload("res://game/world/maps/factory_02.gd"),
	preload("res://game/world/maps/factory_03.gd"),
	preload("res://game/world/maps/factory_04.gd"),
	preload("res://game/world/maps/factory_05.gd"),
	preload("res://game/world/maps/factory_06.gd"),
]
const KEYS: Array[String] = [
	"grid", "levels", "stairs", "containers", "spots", "stoves", "entries",
	"entry_gap", "entry_levels", "buildings", "wagons", "train", "platform",
	"unload", "train_cars", "spawns", "labels", "trees", "low_blocks",
	"upper_rects", "lights", "manholes", "manhole_levels", "sewer_names",
	"anchors", "zone_names", "place_id", "place_kind", "bands", "train_doors",
	"crossings", "barricade_slots", "interior_kind_slots", "props", "hole_faces",
	"entry_names", "entry_weights", "first_entry",
]
# 원 주문의 낱말과 북쪽 증설에서 쓰인 공용 표 후보 여덟 종류.
const KINDS: Array[String] = [
	"car", "handcart", "firewood_pile", "barrel", "crate_stack", "sack_pile",
	"bench", "shelf", "bed", "desk", "cold_stove", "lamp_post",
	"display_shelf", "shop_counter", "checkout", "shopping_cart", "pallet_stack",
	"market_stall", "shop_awning", "freezer_chest", "bread_rack", "blank_sign",
	"floor_shell", "stair_stub", "water", "lignite_pile", "coal_hopper",
	"conveyor_span", "conveyor_pylon", "wheel_loader", "turbine_casing",
	"boiler_drum", "control_panel", "lathe_machine", "workbench", "tool_chest",
	"overhead_crane", "steel_bar_bundle", "parts_rack", "forklift", "welder",
	"inspection_pit", "transfer_table", "wheelset", "silo", "grain_conveyor",
	"grain_elevator_leg", "platform_scale", "farm_tractor", "loom", "bobbin_cart",
	"cotton_bale", "dye_vat", "lift_shaft_door", "cloth_bolt_rack", "scrap_heap",
	"gantry_leg", "gantry_beam", "baler_press", "wreck_stack", "cutting_torch_cart",
	"steel_plate_stack", "brick_chimney", "pipe_run", "plank_bridge", "bridge_rail",
	"gate_post", "dock_apron", "canteen_table", "transformer_unit", "cable_drum",
	"log_pile", "tire_stack", "battery_rack", "medicine_cabinet", "brick_pallet",
	"well_head",
]
const CONTAINER_SUFFIXES: Array[String] = [
	"상자", "보관함", "묶음", "선반", "자재함", "궤", "찬장", "공구함", "책상", "침대", "옷장",
]
const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const GATES: Array = [
	[[45, 49], [95, 99]], [[68, 71], [106, 111]], [[52, 57], [92, 95]],
	[[60, 63], [84, 89]], [[28, 31], [106, 111]], [[54, 59], [88, 91]],
]
var _maps: Array[Dictionary] = []


func before_all() -> void:
	for script in MAPS:
		_maps.append(script.build())


func after_all() -> void:
	_maps.clear()


func _rect(row: Array) -> Rect2i:
	return Rect2i(row[0], row[1], row[2], row[3])


func _cells(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2i(x, y))
	return out


func _in_band(d: Dictionary, c: Vector2i) -> bool:
	return d["bands"]["upper"].has_point(c) or d["bands"]["lower"].has_point(c)


func _dist(g: FieldGrid, starts: Array, dead: bool = false, blocked: Dictionary = {}) -> PackedInt32Array:
	var distances := PackedInt32Array()
	distances.resize(g.width * g.height)
	distances.fill(-1)
	var queue: Array[Vector2i] = []
	for c: Vector2i in starts:
		if g.inside(c) and not blocked.has(c) and (g.dead_can_walk(c) if dead else g.people_can_walk(c)):
			distances[g.index(c)] = 0
			queue.append(c)
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for step in DIRS:
			var n: Vector2i = c + step
			if not g.inside(n) or blocked.has(n) or distances[g.index(n)] >= 0:
				continue
			if not (g.dead_can_walk(n) if dead else g.people_can_walk(n)):
				continue
			distances[g.index(n)] = distances[g.index(c)] + 1
			queue.append(n)
	return distances


func _dist_levels(d: Dictionary, starts: Array) -> Dictionary:
	var distances: Dictionary = {}
	var links: Dictionary = {}
	for lv in d["levels"]:
		var lg: FieldGrid = d["levels"][lv]
		var values := PackedInt32Array()
		values.resize(lg.width * lg.height)
		values.fill(-1)
		distances[lv] = values
	for stair in d["stairs"]:
		var c: Vector2i = stair["cell"]
		var a := Vector3i(c.x, c.y, stair["low"])
		var b := Vector3i(c.x, c.y, stair["high"])
		if not links.has(a):
			links[a] = []
		if not links.has(b):
			links[b] = []
		links[a].append(b)
		links[b].append(a)
	var queue: Array[Vector3i] = []
	var g: FieldGrid = d["grid"]
	for c: Vector2i in starts:
		distances[0][g.index(c)] = 0
		queue.append(Vector3i(c.x, c.y, 0))
	var head := 0
	while head < queue.size():
		var at: Vector3i = queue[head]
		head += 1
		var adjacent: Array = links.get(at, []).duplicate()
		for step in DIRS:
			adjacent.append(Vector3i(at.x + step.x, at.y + step.y, at.z))
		for n: Vector3i in adjacent:
			var lg: FieldGrid = d["levels"][n.z]
			var c := Vector2i(n.x, n.y)
			if not lg.inside(c) or not lg.people_can_walk(c) or distances[n.z][lg.index(c)] >= 0:
				continue
			distances[n.z][lg.index(c)] = distances[at.z][g.index(Vector2i(at.x, at.y))] + 1
			queue.append(n)
	return distances


func test_keys_dimensions_zones_and_identity() -> void:
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var g: FieldGrid = d["grid"]
		assert_eq(d.size(), KEYS.size())
		for key in KEYS:
			assert_true(d.has(key), "%s: %s" % [d["place_id"], key])
		assert_true(g.width >= 150 and g.width <= 180)
		assert_true(g.height >= 135 and g.height <= 155)
		assert_eq(g.height, MAPS[i].SOUTH_HEIGHT + 45)
		assert_eq(d["place_id"], "factory_%02d" % (i + 1))
		assert_eq(d["place_kind"], "factory")
		var zones: Dictionary = {}
		for zone in g.zone:
			zones[zone] = true
		assert_true(zones.size() >= 8 and zones.size() <= 12)
		assert_eq(zones.size(), d["zone_names"].size())
		for zone in zones:
			assert_true(d["zone_names"].has(zone) and not str(zone).is_empty())
		assert_true(d["spots"].has("work_site"))
		assert_true(d["spots"]["work_site"].has("cell"))
		assert_true(d["spots"]["work_site"].has("zone_rect"))


func test_train_doors_buffers_and_crossings() -> void:
	for d in _maps:
		var g: FieldGrid = d["grid"]
		var t: Rect2i = d["train"]
		assert_eq(t, Rect2i(16, 46, 80, 3))
		assert_eq(d["platform"], Rect2i(t.position.x, 49, 82, 6))
		assert_eq(d["unload"], Rect2i(t.position.x, 49, 82, 3))
		assert_eq(d["bands"]["upper"], Rect2i(0, 24, 116, 22))
		assert_eq(d["bands"]["lower"], Rect2i(0, 49, 116, 26))
		var bounds := Rect2i(0, 0, g.width, g.height)
		assert_true(bounds.encloses(d["bands"]["upper"]) and bounds.encloses(d["bands"]["lower"]))
		assert_false(d["bands"]["upper"].intersects(d["bands"]["lower"]))
		var upper: Array = d["train_doors"]["upper"]
		var lower: Array = d["train_doors"]["lower"]
		assert_true(upper.size() >= 3 and lower.size() >= 3)
		assert_eq(upper.size(), lower.size())
		var door_x: Dictionary = {}
		for j in range(lower.size()):
			assert_eq(upper[j], Vector2i(lower[j].x, 45))
			assert_eq(lower[j].y, 49)
			assert_true(lower[j].x >= t.position.x + 2 and lower[j].x < t.end.x - 2)
			door_x[lower[j].x] = true
			assert_true(d["barricade_slots"].has(Vector2i(lower[j].x, 44)))
			assert_true(d["barricade_slots"].has(Vector2i(lower[j].x, 50)))
		assert_eq(d["spawns"]["train_door"], lower)
		for c: Vector2i in d["spawns"]["squad"]:
			assert_true(d["bands"]["lower"].has_point(c))
		var bad := 0
		for y in range(46, 49):
			for x in range(g.width):
				if g.floor_at(Vector2i(x, y)) != F.RAIL:
					bad += 1
		for r in [Rect2i(16, 43, 80, 3), Rect2i(16, 49, 80, 3)]:
			for c in _cells(r):
				if not g.people_can_walk(c):
					bad += 1
			for p in d["props"]:
				if int(p.get("level", 0)) == 0 and r.intersects(p["rect"]):
					bad += 1
		assert_eq(bad, 0, "선로와 열차 옆 세 줄")
		for r in [Rect2i(0, 46, 16, 3), Rect2i(96, 46, g.width - 96, 3)]:
			var free := 0
			for c in _cells(r):
				if g.people_can_walk(c):
					free += 1
			assert_true(free >= 4)
		assert_eq(d["crossings"].size(), 2)
		var used: Dictionary = {}
		for crossing in d["crossings"]:
			var cells: Array = crossing["cells"]
			assert_eq(cells.size(), 3)
			var x: int = cells[0].x
			assert_true([32, 48, 64].has(x) and not door_x.has(x) and not used.has(x))
			used[x] = true
			for k in range(3):
				assert_eq(cells[k], Vector2i(x, 46 + k))
				assert_eq(g.solid_at(cells[k]), S.BLOCK)
			assert_true(g.people_can_walk(Vector2i(x, 45)) and g.people_can_walk(Vector2i(x, 49)))
			assert_eq(crossing["who"], {"person": true, "zombie": false, "carrying": true, "wounded": false, "sled": false})


func test_entries_holes_and_closed_door_dead_routes() -> void:
	for d in _maps:
		var g: FieldGrid = d["grid"]
		var upper := _dist(g, d["train_doors"]["upper"], true)
		var lower := _dist(g, d["train_doors"]["lower"], true)
		var entry_counts: Array[int] = [0, 0]
		for key in d["entries"]:
			assert_true(d["entry_gap"].has(key))
			assert_true(float(d["entry_gap"][key]) > 0.0 and float(d["entry_gap"][key]) <= 3.0)
			if d["manholes"].has(key):
				continue
			var cells: Array = d["entries"][key]
			assert_true(cells.size() >= 2 and cells.size() <= 4)
			var north: bool = cells[0].y < 46
			entry_counts[0 if north else 1] += 1
			for c: Vector2i in cells:
				assert_false(_in_band(d, c))
				assert_true(c.x == 0 or c.y == 0 or c.x == g.width - 1 or c.y == g.height - 1)
				assert_true((upper if north else lower)[g.index(c)] >= 0, "망자 길: " + key)
		assert_true(entry_counts[0] >= 2 and entry_counts[0] <= 3)
		assert_true(entry_counts[1] >= 3 and entry_counts[1] <= 5)
		assert_true(d["manholes"].size() <= 4)
		var doors: Array = d["train_doors"]["upper"] + d["train_doors"]["lower"]
		for key in d["manholes"]:
			assert_true(d["entries"].has(key) and d["entry_gap"].has(key) and d["sewer_names"].has(key))
			var c: Vector2i = d["manholes"][key]
			if d["manhole_levels"].has(key):
				assert_eq(d["manhole_levels"][key], -1)
				assert_eq(d["entry_levels"].get(key, 0), -1)
				var stairs: Array = []
				for stair in d["stairs"]:
					if stair["low"] == -1:
						stairs.append(stair["cell"])
				var below := _dist(d["levels"][-1], stairs, true)
				assert_true(below[g.index(c)] >= 0)
			else:
				for door: Vector2i in doors:
					assert_true(absi(c.x - door.x) + absi(c.y - door.y) > 25)
				assert_true(upper[g.index(c)] >= 0 or lower[g.index(c)] >= 0)
			if str(key).begins_with("culvert_"):
				assert_true(d["hole_faces"].has(key))
				assert_true(DIRS.has(d["hole_faces"].get(key, Vector2i.ZERO)))
				assert_true(g.dead_can_walk(c + d["hole_faces"][key]))
		for c: Vector2i in d["spawns"]["dead_yard"]:
			assert_false(_in_band(d, c))
		for spawn in d["spawns"]["dead_levels"]:
			if int(spawn.get("level", 0)) == 0:
				assert_false(_in_band(d, spawn["cell"]))


func test_people_reach_all_ground_and_barricades_leave_open_sides() -> void:
	for d in _maps:
		var g: FieldGrid = d["grid"]
		var all := _dist(g, d["train_doors"]["lower"])
		var blocked: Dictionary = {}
		for c: Vector2i in d["barricade_slots"]:
			assert_true(g.people_can_walk(c))
			blocked[c] = true
		var upper := _dist(g, d["train_doors"]["upper"], false, blocked)
		var lower := _dist(g, d["train_doors"]["lower"], false, blocked)
		var reached: Dictionary = {}
		var missing := 0
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				var k := g.index(c)
				if not g.people_can_walk(c):
					continue
				if all[k] < 0:
					missing += 1
				if (upper[k] >= 0 if y < 46 else lower[k] >= 0):
					reached[g.zone_at(c)] = true
		assert_eq(missing, 0, d["place_id"] + " 보행 고립 칸")
		for zone in d["zone_names"]:
			assert_true(reached.has(zone), "방벽 뒤 우회: " + zone)


func test_visible_solids_cover_and_north_gate_geometry() -> void:
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var g: FieldGrid = d["grid"]
		var low_cells: Dictionary = {}
		var water: Dictionary = {}
		var blocks: Dictionary = {}
		for c in _cells(d["train"]):
			blocks[c] = true
		for c: Vector2i in d["trees"]:
			blocks[c] = true
			assert_eq(g.solid_at(c), S.BLOCK)
		for wagon in d["wagons"]:
			for c in _cells(wagon["rect"]):
				blocks[c] = true
		for r: Rect2i in d["low_blocks"]:
			for c in _cells(r):
				low_cells[c] = true
		for c: Vector2i in d["stoves"]:
			low_cells[c] = true
		for p in d["props"]:
			if p["kind"] == "water" and int(p.get("level", 0)) == 0:
				assert_false(d["low_blocks"].has(p["rect"]))
				for c in _cells(p["rect"]):
					water[c] = true
					assert_eq(g.solid_at(c), S.LOW)
					assert_eq(g.floor_at(c), F.ICE)
		for side in ["upper", "lower"]:
			var count := 0
			var near := 0
			for r: Rect2i in d["low_blocks"]:
				if not r.intersects(d["bands"][side]):
					continue
				count += 1
				var close := false
				for c in _cells(r):
					for door: Vector2i in d["train_doors"][side]:
						if absi(c.x - door.x) + absi(c.y - door.y) <= 12:
							close = true
				if close:
					near += 1
			assert_true(count >= 3 and count <= 5)
			if side == "upper":
				assert_true(near >= 2)
		var unsupported := 0
		var longest := 0
		for y in range(g.height):
			var run := 0
			for x in range(g.width):
				var c := Vector2i(x, y)
				var solid := g.solid_at(c)
				if solid == S.LOW and not low_cells.has(c) and not water.has(c):
					unsupported += 1
				if solid == S.BLOCK and g.building_at(c) < 0 and not blocks.has(c):
					unsupported += 1
				if x < 14 and y < 14 and solid == S.BLOCK:
					unsupported += 1
				run = run + 1 if solid == S.LOW and not water.has(c) else 0
				longest = maxi(longest, run)
		for x in range(g.width):
			var run := 0
			for y in range(g.height):
				var c := Vector2i(x, y)
				run = run + 1 if g.solid_at(c) == S.LOW and not water.has(c) else 0
				longest = maxi(longest, run)
		assert_eq(unsupported, 0, "보이지 않는 장애물")
		assert_true(longest <= 10, "이어진 낮은 장애물은 열 칸 이하")
		for b in d["buildings"]:
			if b["rect"].position.y < 46:
				assert_false(b["rect"].intersects(d["bands"]["upper"]))
		for x in range(116):
			var gate := false
			for span in GATES[i]:
				if x >= span[0] and x <= span[1]:
					gate = true
			var c := Vector2i(x, 23)
			if gate:
				assert_true(g.people_can_walk(c))
				assert_eq(g.floor_at(c), F.ROAD)

		# 동쪽 트인 변과 정해진 길목을 잠깐 닫아, 덩어리 사이의 새 통로를 찾는다.
		var closed: Dictionary = {}
		var starts: Array = []
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				if x >= 116 or y >= 46:
					closed[c] = true
				elif y < 19 and g.building_at(c) < 0 and g.dead_can_walk(c):
					starts.append(c)
		for span in GATES[i]:
			for x in range(span[0], span[1] + 1):
				for y in range(14, 25):
					closed[Vector2i(x, y)] = true
		var sealed := _dist(g, starts, true, closed)
		for c: Vector2i in d["train_doors"]["upper"]:
			assert_eq(sealed[g.index(c)], -1, "길목 밖으로 새는 북쪽 통로")
		for y in range(24, 46):
			assert_true(g.people_can_walk(Vector2i(116, y)), "동쪽 트인 변")


func test_buildings_rooms_stairs_and_loot_distances() -> void:
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var g: FieldGrid = d["grid"]
		var counts: Array[int] = [0, 0]
		var entered := 0
		var large := 0
		for j in range(d["buildings"].size()):
			var b: Dictionary = d["buildings"][j]
			var r: Rect2i = b["rect"]
			assert_eq(b["id"], j)
			counts[0 if r.position.y < 46 else 1] += 1
			var has_door := false
			for c: Vector2i in g.doors:
				if int(g.doors[c]["building"]) == j and r.has_point(c):
					has_door = true
			if has_door:
				entered += 1
			var inside := r.grow(-1)
			if inside.get_area() >= 600:
				large += 1
			if inside.get_area() > 60:
				var internal := false
				for c in _cells(inside):
					if g.solid_at(c) == S.WALL:
						internal = true
				assert_true(internal, b["name"] + " 안벽")
		assert_true(counts[0] >= 6 and counts[0] <= 9)
		assert_true(counts[1] >= 14 and counts[1] <= 22)
		assert_true(entered * 10 >= d["buildings"].size() * 7)
		assert_true(large >= 1)
		var zones: Dictionary = {}
		var northern := false
		for slot in d["interior_kind_slots"]:
			zones[slot["zone"]] = true
			if MAPS[i].NORTH["zone_names"].has(slot["zone"]):
				northern = true
		assert_eq(d["interior_kind_slots"].size(), 3)
		assert_eq(zones.size(), 3)
		assert_true(northern)
		for lv in [-1, 1, 2]:
			assert_true(d["levels"].has(lv))
			var lg: FieldGrid = d["levels"][lv]
			var usable := 0
			for y in range(lg.height):
				for x in range(lg.width):
					if lg.people_can_walk(Vector2i(x, y)):
						usable += 1
			assert_true(usable > 0)
		for stair in d["stairs"]:
			assert_eq(stair["high"], stair["low"] + 1)
			assert_true(d["levels"][stair["low"]].people_can_walk(stair["cell"]))
			assert_true(d["levels"][stair["high"]].people_can_walk(stair["cell"]))
		var upper := _dist_levels(d, d["train_doors"]["upper"])
		var lower := _dist_levels(d, d["train_doors"]["lower"])
		var far: Array[int] = [0, 0]
		var near: Array[int] = [100000, 100000]
		for box in d["containers"].values():
			var c: Vector2i = box["cell"]
			var lv: int = box.get("level", 0)
			var side := 0 if c.y < 46 else 1
			var distance: int = (upper if side == 0 else lower)[lv][g.index(c)]
			assert_true(distance >= 0, box["name"])
			far[side] = maxi(far[side], distance)
			near[side] = mini(near[side], distance)
		assert_true(far[0] >= 45 and far[1] >= 80)
		assert_true(near[0] <= 25 and near[1] <= 40)
		var largest_id := 0
		var largest_area := 0
		for j in range(MAPS[i].NORTH["buildings"].size()):
			var r := _rect(MAPS[i].NORTH["buildings"][j][1])
			if r.get_area() > largest_area:
				largest_area = r.get_area()
				largest_id = j
		var biggest_rooms := 0
		for row in MAPS[i].NORTH["rooms"]:
			var r := _rect(row[2])
			assert_true(r.size.x >= 3 and r.size.y >= 3)
			if row[0] == largest_id and row[1] == 0:
				biggest_rooms += 1
			var furnished := false
			for p in d["props"]:
				if int(p.get("level", 0)) == row[1] and r.encloses(p["rect"]):
					furnished = true
			assert_true(furnished, "위쪽 방마다 놓인 물건")
		assert_true(biggest_rooms >= 6)


func test_props_names_and_trees() -> void:
	var names := RegEx.new()
	assert_eq(names.compile("[A-Za-z㐀-鿿]"), OK)
	for d in _maps:
		var g: FieldGrid = d["grid"]
		var bounds := Rect2i(0, 0, g.width, g.height)
		var forbidden: Dictionary = {}
		for c: Vector2i in g.doors:
			for step in DIRS:
				for k in range(4):
					forbidden[c + step * k] = true
		for c: Vector2i in d["barricade_slots"]:
			forbidden[c] = true
		for cells in d["entries"].values():
			for c: Vector2i in cells:
				forbidden[c] = true
		var north := 0
		var inside := 0
		var conflicts := 0
		assert_true(d["props"].size() >= 130)
		for p in d["props"]:
			var r: Rect2i = p["rect"]
			var lv: int = p.get("level", 0)
			assert_true(KINDS.has(p["kind"]), p["kind"])
			assert_true(["none", "low", "wall", "tree", "wagon"].has(p["solid"]))
			assert_true(bounds.encloses(r) and r.size.x > 0 and r.size.y > 0)
			assert_true(lv >= -1 and lv <= 3)
			if lv == 3:
				assert_eq(p["kind"], "floor_shell")
			if lv != 0:
				assert_eq(p["solid"], "none")
			else:
				if p["solid"] == "low" and p["kind"] != "water":
					assert_true(d["low_blocks"].has(r))
				for c in _cells(r):
					if forbidden.has(c):
						conflicts += 1
					if p["solid"] == "wall":
						assert_eq(g.solid_at(c), S.WALL)
			assert_true(names.search(p["note"]) == null, p["note"])
			if r.position.y < 46:
				north += 1
				for b in d["buildings"]:
					if b["rect"].encloses(r):
						inside += 1
						break
			if p["kind"] == "floor_shell":
				var shells := 0
				var stubs := 0
				for b in d["buildings"]:
					if b["rect"] == r:
						shells += 1
				for stub in d["props"]:
					if stub["kind"] == "stair_stub" and int(stub.get("level", 0)) == 2 and r.encloses(stub["rect"]):
						stubs += 1
				assert_eq(shells, 1)
				assert_eq(stubs, 1)
		assert_eq(conflicts, 0, "문 앞 세 칸과 방벽 및 진입 칸")
		assert_true(north >= 40 and inside * 2 >= north)
		for b in d["buildings"]:
			assert_true(names.search(b["name"]) == null)
		for value in d["zone_names"].values() + d["sewer_names"].values():
			assert_true(names.search(value) == null)
		for box in d["containers"].values():
			assert_true(names.search(box["name"]) == null)
		var tree_counts: Array[int] = [0, 0]
		for c: Vector2i in d["trees"]:
			tree_counts[0 if c.y < 46 else 1] += 1
			assert_false(c.x < 14 and c.y < 14)
		assert_true(tree_counts[0] >= 12 and tree_counts[0] <= 30)
		assert_true(tree_counts[1] >= 25 and tree_counts[1] <= 60)


func test_asymmetry_and_six_distinct_north_maps() -> void:
	var grids: Dictionary = {}
	var norths: Dictionary = {}
	var first_lines: Dictionary = {}
	var second_lines: Dictionary = {}
	for i in range(_maps.size()):
		var g: FieldGrid = _maps[i]["grid"]
		var full: String = str(g.solid) + str(g.floor)
		var north: String = str(g.solid.slice(0, g.width * 46)) + str(g.floor.slice(0, g.width * 46))
		assert_false(grids.has(full))
		assert_false(norths.has(north))
		grids[full] = true
		norths[north] = true
		var lines: PackedStringArray = FileAccess.get_file_as_string(MAPS[i].resource_path).split("\n")
		assert_true(lines[0].begins_with("# 이 지도가 다른 판단을 만드는 것: "))
		assert_true(lines[1].begins_with("# 위쪽의 판단: "))
		assert_false(first_lines.has(lines[0]) or second_lines.has(lines[1]))
		first_lines[lines[0]] = true
		second_lines[lines[1]] = true
		var match_ew := 0
		var union_ew := 0
		var match_ns := 0
		var union_ns := 0
		for y in range(g.height):
			for x in range(floori(g.width * 0.5)):
				var a := g.solid_at(Vector2i(x, y))
				var b := g.solid_at(Vector2i(g.width - 1 - x, y))
				if a != S.NONE or b != S.NONE:
					union_ew += 1
					if a == b:
						match_ew += 1
		for y in range(45):
			for x in range(g.width):
				var a := g.solid_at(Vector2i(x, 45 - y))
				var b := g.solid_at(Vector2i(x, 49 + y))
				if a != S.NONE or b != S.NONE:
					union_ns += 1
					if a == b:
						match_ns += 1
		assert_true(match_ew * 2 < union_ew)
		assert_true(match_ns * 2 < union_ns)


func _decode_runs(runs: Array) -> PackedByteArray:
	var out := PackedByteArray()
	for i in range(0, runs.size(), 2):
		for n in range(int(runs[i + 1])):
			out.append(int(runs[i]))
	return out


func test_original_south_cells_move_exactly_forty_five_rows() -> void:
	for i in range(_maps.size()):
		var g: FieldGrid = _maps[i]["grid"]
		var old_solid := _decode_runs(ORIGINAL_SOUTH[i]["solid"])
		var old_floor := _decode_runs(ORIGINAL_SOUTH[i]["floor"])
		# 허용된 남쪽 수정은 나무 재배치뿐이다. 원본 값에서 그 칸만 바꾼다.
		for row in ORIGINAL_SOUTH[i]["trees"]:
			old_solid[row[1] * g.width + row[0]] = S.NONE
		for row in MAPS[i].PLAN["trees"]:
			old_solid[row[1] * g.width + row[0]] = S.BLOCK
		# 검수에서 더한 안벽(안이 넓은 헛간과 창고의 짧은 칸막이).
		for cell: Vector2i in SOUTH_WALL_FIXES.get(i, []):
			old_solid[cell.y * g.width + cell.x] = S.WALL
		var bad := 0
		# 옛 맨 위 줄은 새 북쪽 접속부다. 선로와 그 남쪽은 모두 비교한다.
		for y in range(1, MAPS[i].SOUTH_HEIGHT):
			for x in range(g.width):
				var before: int = y * g.width + x
				var after: int = (y + 45) * g.width + x
				if g.solid[after] != old_solid[before] or g.floor[after] != old_floor[before]:
					bad += 1
		assert_eq(bad, 0, _maps[i]["place_id"] + " 원본 남쪽 보존")
		var old: Dictionary = MAPS[i]._build_south()
		for lv in [-1, 1, 2]:
			var before: FieldGrid = old["levels"][lv]
			var after: FieldGrid = _maps[i]["levels"][lv]
			var differences := 0
			for y in range(before.height):
				for x in range(before.width):
					var a := before.index(Vector2i(x, y))
					var b := after.index(Vector2i(x, y + 45))
					if before.solid[a] != after.solid[b] or before.floor[a] != after.floor[b]:
						differences += 1
			assert_eq(differences, 0, "남쪽 위층과 지하 보존")
		for lg: FieldGrid in _maps[i]["levels"].values():
			for c: Vector2i in lg.doors:
				assert_eq(lg.doors[c]["cell"], c)
			for c: Vector2i in lg.windows:
				assert_eq(lg.windows[c]["cell"], c)


func test_north_upper_and_cellar_doors_are_already_open() -> void:
	# 현재 이동 코드는 지상 문만 자동으로 연다.
	for d in _maps:
		for lv in [-1, 1, 2]:
			var g: FieldGrid = d["levels"][lv]
			for c: Vector2i in g.doors:
				if c.y < 46:
					assert_true(["open", "broken"].has(g.doors[c]["state"]))


# 증설 전 원본 격자의 (칸 종류, 연속 칸 수). 나무 이동 외의 변경을 검출한다.
const SOUTH_WALL_FIXES: Dictionary = {
	1: [Vector2i(153, 83), Vector2i(153, 84), Vector2i(153, 85)],
	3: [Vector2i(49, 55), Vector2i(49, 56), Vector2i(49, 57)],
}
const ORIGINAL_SOUTH: Array = [
	{
		"solid": [
			0,196,2,80,0,100,2,80,0,100,2,80,0,1392,3,3,0,195,3,1,0,63,1,2,5,1,1,24,5,1,1,2,0,86,3,1,0,63,1,1,0,8,1,1,0,9,1,1,0,9,1,1,0,28,1,2,5,1,1,12,5,1,1,2,0,104,1,1,0,1,3,1,0,1,3,3,0,2,1,1,0,1,3,1,0,1,3,2,0,4,1,1,0,1,3,3,0,1,3,1,0,3,5,1,0,28,1,1,0,16,1,1,0,96,2,1,0,7,1,1,0,8,1,1,0,9,1,1,0,9,1,1,0,2,1,2,5,1,1,10,5,1,1,2,0,10,1,1,0,16,5,1,0,46,1,2,5,1,1,8,
			5,1,1,2,0,44,1,1,0,3,3,1,0,1,3,2,0,1,1,1,0,1,3,3,0,3,3,1,0,1,1,1,0,2,3,2,0,3,3,1,0,1,1,1,0,2,1,1,0,7,1,1,0,6,1,1,0,10,1,1,0,16,1,1,0,46,1,1,0,12,1,1,0,44,1,1,0,8,1,1,0,9,1,1,0,9,1,1,0,2,1,1,0,1,3,1,0,1,3,3,0,1,1,1,0,1,3,2,0,3,5,1,0,10,1,1,0,16,1,1,0,46,1,1,0,12,5,1,0,32,2,1,0,6,2,1,0,4,1,5,4,1,1,8,4,1,1,9,4,1,1,5,0,2,1,1,0,7,1,1,
			0,6,1,1,0,10,4,1,1,1,4,1,1,6,4,1,1,8,0,46,1,1,0,12,1,1,0,6,3,2,0,36,1,1,0,28,1,1,0,2,1,1,0,7,1,1,0,1,3,3,0,2,1,1,0,10,1,1,0,16,1,1,0,22,1,2,5,2,1,2,0,18,4,1,1,6,4,1,1,6,0,6,3,2,0,36,1,1,0,28,1,1,0,2,1,1,0,7,1,1,0,6,1,1,0,10,1,1,0,16,1,1,0,22,1,1,0,4,1,1,0,18,1,1,0,12,1,1,0,35,2,1,0,8,4,1,0,28,4,1,0,2,1,1,0,7,1,1,0,6,1,1,0,10,1,1,0,16,1,1,
			0,13,3,5,0,4,4,1,0,4,5,1,0,18,1,1,0,12,1,1,0,44,1,5,4,1,1,8,4,1,1,9,4,1,1,5,0,2,4,1,0,7,4,1,0,6,1,1,0,10,1,9,4,1,1,8,0,13,3,5,0,4,1,1,0,4,1,1,0,18,1,1,0,12,1,1,0,44,1,1,0,8,1,1,0,9,1,1,0,9,1,1,0,2,1,1,0,7,1,1,0,6,1,1,0,50,1,3,4,1,1,2,0,18,1,7,4,1,1,6,0,31,2,1,0,6,2,1,0,5,1,1,0,1,3,1,0,6,1,1,0,1,3,1,0,3,3,3,0,1,1,1,0,1,3,1,0,3,3,2,
			0,2,1,1,0,2,1,1,0,3,3,3,0,1,1,1,0,2,3,3,0,1,1,1,0,132,1,1,0,5,3,2,0,1,1,1,0,9,1,1,0,9,1,1,0,2,1,1,0,7,1,1,0,6,1,1,0,132,1,1,0,1,3,3,0,4,1,1,0,9,1,1,0,9,1,1,0,2,1,1,0,4,3,2,0,1,1,1,0,4,3,1,0,1,1,1,0,129,2,1,0,2,1,1,0,6,3,1,0,1,1,1,0,3,3,2,0,2,3,1,0,1,1,1,0,3,3,1,0,1,3,3,0,1,1,1,0,2,1,1,0,7,1,1,0,6,1,1,0,106,1,2,5,1,1,16,5,1,1,2,
			0,4,1,1,0,8,1,1,0,9,1,1,0,9,1,1,0,2,1,8,4,1,1,7,0,106,1,1,0,10,1,1,0,9,1,1,0,4,1,15,4,1,1,14,0,24,2,1,0,3,1,2,5,1,1,12,5,1,1,2,0,4,1,2,5,1,1,12,5,1,1,2,0,5,2,1,0,13,2,1,0,6,2,1,0,20,2,1,0,6,2,1,0,1,1,1,0,1,3,3,0,1,3,3,0,2,1,1,0,1,3,1,0,1,3,2,0,4,5,1,0,39,2,1,0,6,2,1,0,15,1,1,0,8,1,1,0,7,1,1,0,4,1,1,0,8,1,1,0,7,1,1,0,30,1,2,5,1,1,8,
			5,1,1,2,0,12,1,1,0,10,1,1,0,9,1,1,0,62,1,1,0,1,3,3,0,1,3,2,0,1,1,1,0,1,3,1,0,1,3,2,0,2,5,1,0,4,1,1,0,1,3,2,0,1,3,1,0,3,1,1,0,1,3,2,0,1,3,1,0,2,5,1,0,30,1,1,0,6,1,1,0,5,1,1,0,12,1,1,0,10,1,1,0,9,1,1,0,62,1,1,0,8,1,1,0,7,1,1,0,2,2,1,0,1,1,1,0,8,1,1,0,7,1,1,0,1,2,1,0,6,2,1,0,13,2,1,0,7,1,1,0,1,3,1,0,4,1,1,0,1,3,1,0,3,5,1,0,6,2,1,
			0,5,1,1,0,10,1,1,0,9,1,1,0,35,2,1,0,20,3,4,0,2,1,1,0,8,1,1,0,7,1,1,0,4,1,1,0,8,1,1,0,7,1,1,0,30,1,1,0,3,3,2,0,1,1,1,0,5,1,1,0,12,1,1,0,10,1,1,0,9,1,1,0,8,1,2,5,1,1,18,5,1,1,2,0,6,1,2,5,1,1,6,5,1,1,2,0,6,3,4,0,2,1,1,0,8,1,1,0,7,1,1,0,4,1,1,0,8,1,1,0,7,1,1,0,30,1,1,0,3,3,2,0,1,1,1,0,1,3,2,0,2,1,1,0,12,4,1,0,10,4,1,0,9,1,1,0,8,1,1,
			0,11,1,1,0,10,1,1,0,6,1,1,0,5,1,1,0,4,1,1,0,12,4,1,0,8,4,1,0,7,1,1,0,4,4,1,0,8,4,1,0,7,1,1,0,4,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,4,4,1,0,6,4,1,0,5,1,1,0,2,2,1,0,6,2,1,0,2,1,1,0,10,1,1,0,9,1,1,0,3,2,1,0,4,1,1,0,1,3,4,0,1,3,2,0,3,1,1,0,1,3,4,0,1,3,2,0,2,5,1,0,6,1,1,0,1,3,3,0,1,1,1,0,4,5,1,0,6,3,4,0,2,1,1,0,8,1,1,0,4,3,2,0,1,1,1,
			0,4,1,1,0,8,1,1,0,3,3,3,0,1,1,1,0,30,1,1,0,1,3,2,0,3,1,1,0,5,1,1,0,12,1,1,0,10,1,1,0,9,1,1,0,8,1,1,0,6,3,2,0,3,1,1,0,6,3,2,0,2,1,1,0,6,1,1,0,5,1,1,0,4,1,1,0,6,3,4,0,2,1,1,0,8,1,1,0,7,1,1,0,4,1,1,0,8,1,1,0,7,1,1,0,30,1,1,0,6,1,1,0,2,3,2,0,1,1,1,0,12,1,1,0,10,1,1,0,9,1,1,0,8,1,1,0,11,1,1,0,10,1,1,0,6,1,1,0,2,3,2,0,1,1,1,0,2,3,1,
			0,1,1,1,0,12,1,1,0,3,3,2,0,1,3,1,0,1,1,1,0,3,3,3,0,1,1,1,0,1,2,1,0,2,1,1,0,1,3,2,0,1,3,3,0,1,1,1,0,4,3,2,0,1,1,1,0,7,2,1,0,13,2,1,0,6,2,1,0,1,1,1,0,2,3,3,0,1,1,1,0,2,3,2,0,1,1,1,0,5,2,1,0,6,1,1,0,10,1,1,0,9,1,1,0,6,2,1,0,1,1,1,0,11,1,1,0,10,1,1,0,2,2,1,0,3,4,1,0,5,4,1,0,4,1,1,0,6,3,4,0,2,1,1,0,8,1,1,0,7,1,1,0,4,1,1,0,8,1,1,
			0,7,1,1,0,30,1,1,0,6,1,1,0,5,1,1,0,12,1,1,0,5,3,2,0,1,3,1,0,1,1,1,0,1,3,3,0,1,3,3,0,1,1,1,0,8,4,1,0,11,4,1,0,10,4,1,0,6,1,1,0,5,1,1,0,4,1,1,0,6,3,4,0,2,1,9,4,1,1,8,0,4,1,9,4,1,1,8,0,30,1,7,4,1,1,6,0,12,1,1,0,10,1,1,0,9,1,1,0,8,1,1,0,11,1,1,0,10,1,1,0,6,1,1,0,3,3,1,0,1,1,1,0,1,3,2,0,1,1,1,0,55,2,1,0,52,1,11,4,1,1,10,0,8,1,1,0,8,3,2,
			0,1,1,1,0,4,3,2,0,4,1,1,0,6,1,1,0,5,1,1,0,4,1,1,0,138,1,1,0,5,3,2,0,1,3,2,0,1,1,1,0,4,3,2,0,1,3,2,0,1,1,1,0,6,1,6,4,1,1,5,0,138,1,1,0,11,1,1,0,10,1,1,0,156,1,12,4,1,1,11,0,614,3,4,0,132,1,2,5,1,1,38,5,1,1,2,3,4,0,6,1,2,5,1,1,50,5,1,1,2,0,4,1,2,5,1,1,34,5,1,1,2,0,26,1,1,0,7,1,1,0,7,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,10,
			1,1,0,10,1,1,0,10,1,1,0,4,1,1,0,12,1,1,0,12,1,1,0,12,1,1,0,26,1,1,0,1,3,1,0,5,1,1,0,1,3,1,0,5,1,1,0,1,3,2,0,1,3,3,0,1,1,1,0,1,3,2,0,1,3,1,0,3,1,1,0,1,3,2,0,1,3,1,0,3,5,1,0,10,1,1,0,10,1,1,0,1,3,2,0,7,1,1,0,1,3,2,0,7,1,1,0,1,3,3,0,1,3,3,0,2,1,1,0,1,1,8,0,1,5,1,0,4,1,1,0,1,1,6,0,1,3,2,0,2,1,1,0,1,3,3,0,1,3,3,0,4,1,1,0,1,3,2,0,1,
			1,6,0,2,5,1,0,2,1,2,5,1,1,8,5,1,1,2,0,10,1,1,0,4,3,2,0,1,1,1,0,4,3,2,0,1,1,1,0,1,3,2,0,5,1,1,0,8,1,1,0,8,1,1,0,10,1,1,0,1,1,8,0,1,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,1,1,8,0,1,1,1,0,4,1,1,0,1,1,6,0,5,1,1,0,12,1,1,0,4,1,6,0,2,1,1,0,2,1,1,0,6,1,1,0,5,1,1,0,10,1,1,0,1,3,2,0,1,3,2,0,1,1,1,0,1,3,2,0,1,3,2,0,1,1,1,0,8,1,1,0,8,1,1,0,8,
			1,1,0,10,1,1,0,1,1,8,0,1,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,1,1,8,0,1,1,1,0,4,1,1,0,1,1,6,0,5,1,1,0,5,1,6,0,1,1,1,0,4,1,6,0,2,1,1,0,2,1,1,0,1,3,3,0,2,1,1,0,1,3,2,0,2,5,1,0,10,1,1,0,7,1,1,0,7,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,10,1,1,0,1,1,8,0,1,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,1,1,8,0,1,1,1,0,4,1,1,0,12,1,1,0,5,1,6,0,1,1,1,0,12,1,1,0,2,
			1,1,0,6,1,1,0,1,3,2,0,2,1,1,0,10,1,1,0,3,3,3,0,1,1,1,0,3,3,3,0,1,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,10,1,1,0,1,1,8,0,1,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,4,1,1,0,12,1,1,0,5,1,6,0,1,1,1,0,12,1,1,0,2,1,1,0,6,1,1,0,5,1,1,0,10,1,1,0,7,1,1,0,7,1,1,0,8,1,1,0,5,3,2,0,1,1,1,0,5,3,2,0,1,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,10,
			1,1,0,4,1,1,0,12,1,1,0,12,1,1,0,12,1,1,0,2,1,1,0,3,3,2,0,1,1,1,0,1,3,2,0,2,1,1,0,10,1,1,0,7,1,1,0,7,1,1,0,2,3,2,0,2,3,1,0,1,1,1,0,1,3,3,0,1,3,2,0,1,1,1,0,1,3,3,0,1,3,2,0,1,1,1,0,10,1,1,0,1,3,3,0,3,3,2,0,1,1,1,0,2,3,3,0,1,3,3,0,1,1,1,0,2,3,3,0,1,3,3,0,1,1,1,0,7,3,2,0,1,1,1,0,2,3,3,0,1,3,3,0,1,1,1,0,4,1,1,0,3,3,3,0,2,3,3,0,1,
			1,1,0,9,3,2,0,1,1,1,0,3,3,3,0,2,3,3,0,1,1,1,0,2,4,1,0,6,4,1,0,5,1,1,0,10,1,1,0,7,1,1,0,7,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,4,1,1,0,12,1,1,0,12,1,1,0,12,1,1,0,2,1,1,0,6,1,1,0,5,1,1,0,10,1,4,4,1,1,7,4,1,1,8,4,1,1,8,4,1,1,8,4,1,1,4,0,10,1,6,4,1,1,10,4,1,1,10,4,1,1,10,4,1,1,10,4,1,1,5,0,4,
			1,7,4,1,1,12,4,1,1,12,4,1,1,6,0,2,1,1,0,3,3,2,0,1,1,1,0,5,1,1,0,10,1,1,0,42,1,1,0,10,1,1,0,54,1,1,0,4,1,1,0,38,1,1,0,2,1,1,0,3,3,2,0,1,1,1,0,1,3,3,0,1,1,1,0,10,1,1,0,42,1,1,0,10,1,1,0,54,1,1,0,4,1,1,0,38,1,1,0,2,1,1,0,6,1,1,0,5,1,1,0,10,4,1,0,42,4,1,0,10,4,1,0,54,4,1,0,4,4,1,0,38,4,1,0,2,1,7,4,1,1,6,0,10,1,4,4,1,1,7,4,1,1,8,4,1,1,8,4,1,
			1,8,4,1,1,4,0,10,1,6,4,1,1,10,4,1,1,10,4,1,1,10,4,1,1,10,4,1,1,5,0,4,1,7,4,1,1,12,4,1,1,12,4,1,1,6,0,26,1,1,0,7,1,1,0,7,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,4,1,1,0,12,1,1,0,12,1,1,0,12,1,1,0,26,1,1,0,7,1,1,0,1,3,1,0,2,3,2,0,1,1,1,0,1,3,1,0,3,3,2,0,1,1,1,0,1,3,2,0,5,1,1,0,1,3,2,0,2,3,1,0,2,
			1,1,0,10,1,1,0,1,3,2,0,7,1,1,0,1,3,3,0,2,3,3,0,1,1,1,0,1,3,2,0,7,1,1,0,1,3,2,0,7,1,1,0,1,3,3,0,2,3,3,0,1,1,1,0,4,1,1,0,1,3,2,0,9,1,1,0,1,3,2,0,9,1,1,0,1,3,3,0,3,3,3,0,2,1,1,0,2,1,2,5,1,1,8,5,1,1,2,0,10,1,1,0,7,1,1,0,7,1,1,0,8,1,1,0,1,3,2,0,5,1,1,0,8,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,4,1,1,0,12,1,1,0,12,
			1,1,0,12,1,1,0,2,1,1,0,6,1,1,0,5,1,1,0,10,1,1,0,1,3,3,0,3,1,1,0,7,1,1,0,8,1,1,0,4,3,3,0,1,1,1,0,8,1,1,0,10,1,1,0,1,1,8,0,1,1,1,0,1,1,8,0,1,1,1,0,1,1,8,0,1,1,1,0,1,1,8,0,1,1,1,0,7,3,2,0,1,1,1,0,4,1,1,0,1,1,6,0,5,1,1,0,1,1,6,0,5,1,1,0,12,1,1,0,2,1,1,0,1,3,2,0,1,3,1,0,1,1,1,0,1,3,3,0,1,5,1,0,10,1,1,0,7,1,1,0,7,1,1,0,8,1,1,0,8,
			1,1,0,8,1,1,0,10,1,1,0,1,1,8,0,1,1,1,0,1,1,8,0,1,1,1,0,1,1,8,0,1,1,1,0,1,1,8,0,1,1,1,0,10,1,1,0,4,1,1,0,1,1,6,0,5,1,1,0,1,1,6,0,5,1,1,0,12,1,1,0,2,1,1,0,6,1,1,0,5,1,1,0,10,1,1,0,1,3,2,0,4,1,1,0,3,3,3,0,1,1,1,0,4,3,3,0,1,1,1,0,8,1,1,0,8,1,1,0,10,1,1,0,1,1,8,0,1,1,1,0,1,1,8,0,1,1,1,0,1,1,8,0,1,1,1,0,1,1,8,0,1,1,1,0,1,1,8,0,1,
			1,1,0,4,1,1,0,1,1,6,0,5,1,1,0,1,1,6,0,5,1,1,0,12,1,1,0,2,1,1,0,4,3,1,0,1,1,1,0,1,3,1,0,3,1,1,0,10,1,1,0,1,3,2,0,4,1,1,0,7,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,10,1,1,0,1,1,8,0,1,1,1,0,1,1,8,0,1,1,1,0,1,1,8,0,1,1,1,0,1,1,8,0,1,1,1,0,1,1,8,0,1,1,1,0,4,1,1,0,12,1,1,0,12,1,1,0,2,1,6,0,4,1,1,0,2,4,1,0,6,4,1,0,3,3,1,0,1,1,1,0,10,1,1,0,7,
			1,1,0,4,3,2,0,1,1,1,0,3,3,2,0,3,1,1,0,8,1,1,0,1,3,2,0,5,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,1,1,8,0,1,1,1,0,4,1,1,0,12,1,1,0,12,1,1,0,2,1,6,0,4,1,1,0,2,1,1,0,6,1,1,0,5,1,1,0,10,1,1,0,2,3,2,0,1,3,1,0,1,1,1,0,4,3,2,0,1,1,1,0,3,3,2,0,3,1,1,0,3,3,1,0,1,3,2,0,1,1,1,0,1,3,2,0,1,3,3,0,1,1,1,0,10,1,1,0,2,3,3,0,1,3,3,0,1,
			1,1,0,7,3,2,0,1,1,1,0,2,3,3,0,1,3,3,0,1,1,1,0,2,3,3,0,1,3,3,0,1,1,1,0,1,1,8,0,1,1,1,0,4,1,1,0,4,3,3,0,1,3,3,0,1,1,1,0,3,3,3,0,2,3,3,0,1,1,1,0,2,1,6,0,1,3,2,0,1,1,1,0,2,1,1,0,2,3,3,0,1,1,1,0,2,3,2,0,1,1,1,0,10,1,1,0,7,1,1,0,7,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,10,1,1,0,4,1,1,0,12,1,1,0,12,
			1,1,0,12,1,1,0,2,1,1,0,6,1,1,0,5,1,1,0,10,1,22,4,1,1,21,0,10,1,28,4,1,1,27,0,4,1,20,4,1,1,19,0,2,1,7,4,1,1,6,0,886,1,5,0,13,1,2,5,1,1,6,5,1,1,2,0,88,1,2,0,60,1,5,0,13,1,1,0,5,1,1,0,4,1,1,0,88,1,2,0,60,1,5,0,13,1,1,0,1,3,1,0,3,1,1,0,1,3,2,0,1,5,1,0,38,3,3,0,1,3,2,0,16,3,3,0,1,3,2,0,82,3,3,0,1,3,2,0,14,1,1,0,5,1,1,0,4,1,1,0,26,3,10,0,63,1,2,0,9,
			1,2,0,56,1,1,0,3,3,1,0,1,1,1,0,1,3,1,0,2,1,1,0,26,3,10,0,63,1,2,0,9,1,2,0,2,1,3,0,51,4,1,0,5,4,1,0,4,1,1,0,26,3,10,0,2,3,1,0,4,3,2,0,15,3,1,0,4,3,2,0,29,3,10,0,8,1,3,0,3,1,2,0,26,3,1,0,4,3,2,0,13,1,1,0,5,1,1,0,4,1,1,0,26,3,10,0,7,3,2,0,20,3,2,0,29,3,10,0,8,1,3,0,3,1,2,0,10,1,2,0,19,3,2,0,13,1,1,0,2,3,2,0,1,1,1,0,2,3,1,0,1,1,1,0,2,1,2,5,1,
			1,12,5,1,1,2,0,6,3,10,0,60,3,10,0,26,1,2,0,34,1,1,0,5,1,1,0,4,1,1,0,2,1,1,0,16,1,1,0,6,3,10,0,60,3,10,0,62,1,6,4,1,1,5,0,2,1,1,0,1,3,3,0,1,3,2,0,9,5,1,0,6,3,10,0,20,3,3,0,1,3,2,0,5,3,3,0,1,3,2,0,23,3,10,0,5,3,3,0,1,3,2,0,5,3,3,0,1,3,2,0,54,1,1,0,16,1,1,0,6,3,10,0,60,3,10,0,76,1,1,0,16,1,1,0,76,3,10,0,34,1,2,5,1,1,18,5,1,1,2,0,18,1,1,0,16,1,1,0,36,
			3,1,0,4,3,2,0,4,3,1,0,4,3,2,0,22,3,10,0,5,3,1,0,4,3,2,0,4,3,1,0,4,3,2,0,11,1,1,0,6,1,1,0,7,1,1,0,7,1,1,0,18,1,1,0,10,3,2,0,4,1,1,0,41,3,2,0,9,3,2,0,42,3,2,0,9,3,2,0,11,1,1,0,6,1,1,0,1,3,2,0,4,1,1,0,1,3,2,0,4,5,1,0,18,1,1,0,10,3,2,0,1,3,2,0,1,1,1,0,120,1,1,0,1,3,2,0,3,1,1,0,1,3,2,0,1,3,2,0,1,1,1,0,1,3,2,0,1,3,2,0,1,1,1,0,18,1,1,0,16,
			1,1,0,114,1,4,0,2,1,1,0,6,1,1,0,7,1,1,0,7,1,1,0,18,4,1,1,1,4,1,1,6,4,1,1,8,0,10,3,3,0,1,3,2,0,27,3,3,0,1,3,2,0,5,3,3,0,1,3,2,0,16,3,3,0,1,3,2,0,5,3,3,0,1,3,2,0,21,1,4,0,2,1,4,4,1,1,6,4,1,1,7,4,1,1,4,0,18,1,1,0,16,1,1,0,28,3,9,0,77,1,4,0,2,1,1,0,22,1,1,0,18,1,1,0,2,3,2,0,1,3,2,0,9,1,1,0,28,3,9,0,77,1,4,0,2,1,1,0,22,1,1,0,18,1,1,0,5,3,2,
			0,9,1,1,0,10,3,1,0,4,3,2,0,11,3,9,0,6,3,1,0,4,3,2,0,4,3,1,0,4,3,2,0,15,3,1,0,4,3,2,0,4,3,1,0,4,3,2,0,8,3,8,0,10,4,1,0,22,4,1,0,18,1,1,0,16,1,1,0,15,3,2,0,11,3,9,0,11,3,2,0,9,3,2,0,20,3,2,0,9,3,2,0,8,3,8,0,10,1,4,4,1,1,6,4,1,1,7,4,1,1,4,0,18,1,1,0,16,1,1,0,28,3,9,0,65,3,8,0,10,1,1,0,6,1,1,0,7,1,1,0,7,1,1,0,18,1,1,0,9,3,2,0,1,3,3,0,1,1,1,
			0,28,3,9,0,65,3,8,0,10,1,1,0,1,3,2,0,3,1,1,0,1,3,2,0,1,3,2,0,1,1,1,0,1,3,2,0,1,3,2,0,1,1,1,0,18,1,1,0,16,1,1,0,28,3,9,0,65,3,8,0,10,1,1,0,6,1,1,0,7,1,1,0,1,3,2,0,4,1,1,0,18,1,9,4,1,1,8,0,102,3,8,0,10,1,1,0,2,3,3,0,1,1,1,0,1,3,3,0,3,1,1,0,4,3,2,0,1,1,1,0,156,1,1,0,6,1,1,0,7,1,1,0,7,1,1,0,156,1,12,4,1,1,11,0,362
		],
		"floor": [
			0,180,4,540,0,16,2,82,0,98,2,82,0,98,2,82,0,98,2,82,0,98,2,82,0,98,2,82,0,142,1,6,0,174,1,6,0,174,1,6,0,64,3,30,0,80,1,6,0,64,3,30,0,28,3,18,0,34,1,6,0,64,3,30,0,28,3,18,0,34,1,6,0,64,3,30,0,2,3,16,0,10,3,18,0,34,1,6,0,6,3,14,0,44,3,30,0,2,3,16,0,10,3,18,0,34,1,6,0,6,3,14,0,44,3,30,0,2,3,16,0,10,3,18,0,34,1,6,0,6,3,14,0,44,3,30,0,2,3,16,0,10,3,18,0,34,1,6,0,6,3,14,0,44,3,30,0,2,3,16,
			0,10,3,18,0,22,3,6,0,6,1,6,0,6,3,14,0,44,3,30,0,2,3,16,0,10,3,18,0,22,3,6,0,6,1,6,0,6,3,14,0,44,3,30,0,2,3,16,0,10,3,18,0,22,3,6,0,6,1,6,0,6,3,14,0,44,3,30,0,2,3,16,0,10,3,18,0,22,3,6,0,6,1,6,0,6,3,14,0,44,3,30,0,2,3,16,0,50,3,6,0,6,1,6,0,6,3,14,0,44,3,30,0,2,3,16,0,62,1,6,0,64,3,30,0,2,3,16,0,62,1,6,0,64,3,30,0,2,3,16,0,62,1,6,0,64,3,30,0,2,3,16,0,62,1,6,0,38,3,22,
			0,4,3,30,0,2,3,16,0,62,1,6,0,38,3,22,0,4,3,30,0,26,1,2,3,18,0,4,3,18,0,12,1,6,0,38,3,22,0,60,1,2,3,18,0,4,3,18,0,12,1,6,0,12,3,14,0,12,3,22,0,60,1,2,3,18,0,4,3,18,0,12,1,6,0,12,3,14,0,12,3,22,0,60,1,2,3,18,0,4,3,18,0,12,1,6,0,12,3,14,0,12,3,22,0,60,1,2,3,18,0,4,3,18,0,12,1,6,0,12,3,14,0,12,3,22,0,8,3,24,0,6,3,12,0,10,1,2,3,18,0,4,3,18,0,12,1,6,0,12,3,14,0,12,3,22,0,8,3,24,
			0,6,3,12,0,10,1,2,3,18,0,4,3,18,0,12,1,6,0,12,3,14,0,12,3,22,0,8,3,24,0,6,3,12,0,10,1,2,3,18,0,4,3,18,0,12,1,6,0,12,3,14,0,12,3,22,0,8,3,24,0,6,3,12,0,10,1,2,3,18,0,4,3,18,0,12,1,6,0,12,3,14,0,12,3,22,0,8,3,24,0,6,3,12,0,10,1,2,3,18,0,4,3,18,0,12,1,6,0,12,3,14,0,12,3,22,0,8,3,24,0,6,3,12,0,10,1,2,3,18,0,4,3,18,0,12,1,6,0,12,3,14,0,12,3,22,0,8,3,24,0,6,3,12,0,10,1,2,3,18,
			0,4,3,18,0,12,1,6,0,12,3,14,0,12,3,22,0,8,3,24,0,6,3,12,0,10,1,4,0,50,1,6,0,38,3,22,0,8,3,24,0,6,3,12,0,10,1,4,0,50,1,6,0,68,3,24,0,6,3,12,0,8,1,130,3,24,1,22,0,4,1,130,3,24,1,22,0,4,1,176,0,4,1,176,0,4,1,176,0,60,1,6,0,122,3,44,0,8,1,2,3,56,0,4,3,40,0,26,3,44,0,8,1,2,3,56,0,4,3,40,0,26,3,44,0,8,1,2,3,56,0,4,3,40,0,2,3,14,0,10,3,44,0,8,1,2,3,56,0,4,3,40,0,2,3,14,0,10,3,44,
			0,8,1,2,3,56,0,4,3,40,0,2,3,14,0,10,3,44,0,8,1,2,3,56,0,4,3,40,0,2,3,14,0,10,3,44,0,8,1,2,3,56,0,4,3,40,0,2,3,14,0,10,3,44,0,8,1,2,3,56,0,4,3,40,0,2,3,14,0,10,3,44,0,8,1,2,3,56,0,4,3,40,0,2,3,14,0,10,3,44,0,8,1,2,3,56,0,4,3,40,0,2,3,14,0,10,3,44,0,8,1,2,3,56,0,4,3,40,0,2,3,14,0,10,3,44,0,8,1,2,3,56,0,4,3,40,0,2,3,14,0,10,3,44,0,8,1,2,3,56,0,4,3,40,0,2,3,14,0,10,
			3,44,0,8,1,2,3,56,0,4,3,40,0,2,3,14,0,10,3,44,0,8,1,2,3,56,0,4,3,40,0,26,3,44,0,8,1,2,3,56,0,4,3,40,0,26,3,44,0,8,1,2,3,56,0,4,3,40,0,2,3,14,0,10,3,44,0,8,1,2,3,56,0,4,3,40,0,2,3,14,0,10,3,44,0,8,1,2,3,56,0,4,3,40,0,2,3,14,0,10,3,44,0,8,1,2,3,56,0,4,3,40,0,2,3,14,0,10,3,44,0,8,1,2,3,56,0,4,3,40,0,2,3,14,0,10,3,44,0,8,1,2,3,56,0,4,3,40,0,2,3,14,0,10,3,44,0,8,1,2,
			3,56,0,4,3,40,0,2,3,14,0,10,3,44,0,8,1,2,3,56,0,4,3,40,0,2,3,14,0,10,3,44,0,8,1,2,3,56,0,4,3,40,0,2,3,14,0,10,3,44,0,8,1,2,3,56,0,4,3,40,0,2,3,14,0,62,1,6,0,114,1,720,7,2,3,12,7,46,1,6,7,30,1,6,7,80,3,12,7,46,1,6,7,30,1,6,7,80,3,12,7,46,1,6,7,30,1,6,7,80,3,12,7,46,1,6,7,30,1,6,7,80,3,12,7,46,1,6,7,30,1,6,7,80,3,12,7,46,1,6,7,30,1,6,7,78,1,2,3,12,1,4,7,42,1,6,7,30,1,6,
			7,78,1,2,3,12,1,2,3,18,7,26,1,6,7,30,1,6,7,78,1,2,3,12,1,2,3,18,7,26,1,6,7,30,1,6,7,78,1,2,3,12,1,2,3,18,7,26,1,6,7,30,1,6,7,94,3,18,7,26,1,6,7,30,1,6,7,94,3,18,7,26,1,6,7,30,1,6,7,52,3,24,7,18,3,18,7,26,1,6,7,30,1,6,7,52,3,24,7,18,3,18,7,26,1,6,7,30,1,6,7,52,3,24,7,18,3,18,7,26,1,6,7,30,1,6,7,52,3,24,7,18,3,18,7,26,1,6,7,30,1,6,7,52,3,24,7,18,3,18,7,26,1,6,7,30,1,6,7,52,
			3,24,7,18,3,18,7,26,1,6,7,30,1,6,7,52,3,24,7,18,3,18,7,26,1,6,7,30,1,6,7,52,3,24,7,18,3,18,7,26,1,6,7,30,1,6,7,52,3,24,7,18,3,18,7,26,1,6,7,30,1,6,7,52,3,24,7,18,3,18,7,26,1,6,7,30,1,6,7,52,3,24,7,18,3,18,7,26,1,6,7,30,1,6,7,52,3,24,7,18,3,18,7,26,1,6,7,30,1,6,7,52,3,24,7,18,3,18,7,26,1,6,7,30,1,6,7,52,3,24,7,62,1,6,7,30,1,6,7,52,3,24,7,62,1,6,7,30,1,6,7,52,3,24,7,62,1,6,7,30,
			1,6,7,138,1,6,7,30,1,6,7,78
		],
		"trees": [[122,15],[118,18],[125,18],[121,21],[117,24],[124,24],[127,27],[4,30],[53,30],[67,30],[74,30],[95,30],[102,30],[165,30],[172,30],[28,33],[49,33],[56,33],[70,33],[98,33],[161,33],[52,36],[59,36],[66,36],[73,36],[94,36],[101,36],[129,36],[27,39],[55,39],[69,39],[76,39],[97,39],[132,39],[160,39],[51,42]]
	},
	{
		"solid": [
			0,186,2,80,0,90,2,80,0,90,2,80,0,1312,3,3,0,185,3,1,0,29,1,2,5,1,1,16,5,1,1,2,0,14,1,2,5,1,1,24,5,1,1,2,0,74,3,1,0,29,1,1,0,10,1,1,0,9,1,1,0,14,1,1,0,8,1,1,0,9,1,1,0,9,1,1,0,78,1,2,5,1,1,14,5,1,1,2,0,6,1,1,0,10,1,1,0,9,5,1,0,14,1,1,0,1,3,2,0,2,3,2,0,1,1,1,0,1,3,2,0,3,3,2,0,1,1,1,0,1,3,2,0,3,3,2,0,1,5,1,0,78,1,1,0,18,1,1,0,6,1,1,0,10,1,1,0,9,1,1,
			0,4,2,1,0,6,2,1,0,2,1,1,0,5,3,2,0,1,1,1,0,1,3,2,0,3,3,2,0,1,1,1,0,1,3,2,0,3,3,2,0,1,1,1,0,2,2,1,0,7,1,2,5,1,1,12,5,1,1,2,0,50,1,1,0,18,5,1,0,6,1,1,0,10,1,1,0,9,1,1,0,14,1,1,0,8,1,1,0,9,1,1,0,9,1,1,0,10,1,1,0,16,1,1,0,50,1,1,0,18,1,1,0,6,1,1,0,10,1,1,0,9,1,1,0,14,1,5,4,1,1,8,4,1,1,9,4,1,1,5,0,10,1,1,0,16,5,1,0,20,1,2,5,1,1,6,5,1,1,2,
			0,18,1,1,0,18,1,1,0,6,1,1,0,10,1,1,0,9,1,1,0,7,2,1,0,6,1,1,0,28,1,1,0,5,2,1,0,4,1,1,0,16,1,1,0,20,1,1,0,10,1,1,0,18,1,1,0,18,1,1,0,6,1,1,0,10,1,1,0,9,1,1,0,14,1,1,0,28,1,1,0,10,1,1,0,16,1,1,0,20,1,1,0,10,5,1,0,4,1,2,5,2,1,2,0,8,1,1,0,18,1,1,0,6,4,1,0,10,4,1,0,9,1,1,0,14,4,1,0,28,4,1,0,10,1,1,0,16,1,1,0,12,3,4,0,4,1,1,0,10,1,1,0,4,1,1,0,4,1,1,
			0,8,4,1,1,1,4,1,1,7,4,1,1,9,0,6,1,1,0,10,1,1,0,9,1,1,0,3,2,1,0,6,2,1,0,3,1,5,4,1,1,8,4,1,1,9,4,1,1,5,0,1,2,1,0,8,4,1,1,1,4,1,1,6,4,1,1,8,0,12,3,4,0,4,4,1,0,10,1,1,0,4,4,1,0,4,5,1,0,8,1,1,0,18,1,1,0,6,1,1,0,10,1,1,0,9,1,1,0,14,1,1,0,8,1,1,0,9,1,1,0,9,1,1,0,10,1,1,0,16,1,1,0,20,1,1,0,10,1,1,0,4,1,1,0,4,1,1,0,8,1,1,0,18,1,1,0,6,1,1,
			0,10,1,1,0,9,1,1,0,14,1,1,0,1,3,2,0,5,1,1,0,1,3,2,0,6,1,1,0,2,3,2,0,5,1,1,0,10,1,1,0,16,1,1,0,20,1,1,0,10,1,1,0,4,1,3,4,1,1,2,0,8,1,1,0,18,1,1,0,6,1,1,0,10,1,1,0,9,1,1,0,6,2,1,0,7,1,1,0,1,3,2,0,5,1,1,0,1,3,2,0,3,3,2,0,1,1,1,0,6,3,2,0,1,1,1,0,4,2,1,0,5,1,1,0,16,1,1,0,20,1,6,4,1,1,5,0,18,1,1,0,18,1,1,0,6,1,1,0,10,1,1,0,9,1,1,0,14,1,1,
			0,5,3,2,0,1,1,1,0,6,3,2,0,1,1,1,0,1,3,4,0,1,3,2,0,1,1,1,0,10,1,1,0,16,1,1,0,50,1,1,0,18,1,1,0,6,1,1,0,10,1,1,0,9,1,1,0,14,1,1,0,8,1,1,0,9,1,1,0,9,1,1,0,10,1,9,4,1,1,8,0,50,1,10,4,1,1,9,0,6,1,11,4,1,1,10,0,2,2,1,0,6,2,1,0,4,1,15,4,1,1,14,0,102,3,2,0,168,3,2,0,78,2,1,0,13,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,13,2,1,0,6,2,1,0,6,2,1,
			0,6,2,1,0,13,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,857,2,1,0,6,2,1,0,6,2,1,0,12,1,26,0,10,1,73,0,61,1,1,0,107,1,1,0,61,1,1,0,39,1,2,5,1,1,12,5,1,1,2,0,26,1,2,5,1,1,16,5,1,1,2,0,2,1,1,0,3,1,2,5,1,1,21,5,1,1,2,0,31,1,1,0,3,1,2,5,1,1,22,5,1,1,2,0,8,1,1,0,8,1,1,0,7,1,1,0,26,1,1,0,7,1,1,0,3,1,1,0,8,1,1,
			0,2,1,1,0,3,1,1,0,12,1,1,0,12,1,1,0,5,1,2,5,1,1,10,5,1,1,2,0,10,1,1,0,3,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,1,3,1,0,1,3,2,0,3,1,1,0,1,3,2,0,4,5,1,0,6,1,2,5,1,1,10,5,1,1,2,0,4,1,1,0,1,3,2,0,4,1,1,0,3,1,1,0,1,3,3,0,4,5,1,0,2,1,1,0,3,1,1,0,1,3,2,0,1,3,2,0,6,1,1,0,1,3,2,0,1,3,4,0,4,5,1,0,5,1,1,0,14,1,1,0,10,1,1,0,3,1,1,0,1,3,1,
			0,1,3,2,0,3,1,1,0,1,3,1,0,1,3,2,0,3,1,1,0,1,3,2,0,1,3,3,0,1,5,1,0,8,1,1,0,8,1,1,0,1,3,2,0,4,1,1,0,6,1,1,0,7,1,1,0,6,1,1,0,4,1,1,0,7,1,1,0,3,1,1,0,8,1,1,0,2,1,1,0,3,1,1,0,1,3,2,0,9,1,1,0,1,3,2,0,9,1,1,0,5,1,1,0,1,3,3,0,1,3,1,0,8,5,1,0,10,1,1,0,3,1,1,0,8,1,1,0,8,1,1,0,1,3,2,0,5,1,1,0,8,1,1,0,8,1,1,0,7,1,1,0,6,1,1,0,1,3,2,
			0,1,3,2,0,1,1,1,0,1,3,4,0,1,5,1,0,4,1,1,0,1,3,3,0,3,1,1,0,3,1,1,0,1,3,3,0,4,1,1,0,2,1,1,0,3,1,1,0,12,1,1,0,12,1,1,0,5,1,1,0,14,1,1,0,10,1,1,0,3,1,1,0,5,3,2,0,1,1,1,0,5,3,2,0,1,1,1,0,8,1,1,0,8,4,1,0,8,4,1,0,3,3,3,0,1,1,1,0,6,1,1,0,1,3,2,0,4,1,1,0,6,1,1,0,4,1,1,0,1,3,3,0,3,4,1,0,3,4,1,0,8,1,1,0,2,1,1,0,3,1,1,0,12,1,1,0,12,1,1,
			0,5,1,1,0,14,1,1,0,10,1,1,0,3,1,1,0,1,3,3,0,1,3,2,0,1,1,1,0,1,3,3,0,1,3,2,0,1,1,1,0,3,3,1,0,1,3,2,0,1,1,1,0,8,1,1,0,5,3,2,0,1,1,1,0,7,1,1,0,6,1,1,0,4,3,2,0,1,1,1,0,6,1,1,0,4,1,1,0,7,1,1,0,3,1,1,0,1,3,3,0,4,1,1,0,2,1,1,0,3,1,1,0,12,1,1,0,12,1,1,0,5,1,1,0,14,1,1,0,10,1,1,0,3,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,1,3,3,0,1,3,2,
			0,1,1,1,0,2,3,2,0,1,3,1,0,1,1,1,0,6,1,1,0,4,3,2,0,1,1,1,0,6,1,1,0,4,1,1,0,3,3,3,0,1,1,1,0,3,1,1,0,1,3,3,0,1,3,2,0,1,1,1,0,2,1,1,0,3,4,1,0,12,4,1,0,12,4,1,0,5,1,1,0,9,3,1,0,1,3,2,0,1,1,1,0,10,1,1,0,3,1,5,4,1,1,8,4,1,1,8,4,1,1,4,0,8,1,1,0,8,1,1,0,7,1,1,0,6,4,1,0,7,4,1,0,3,3,2,0,1,1,1,0,4,1,1,0,7,1,1,0,3,1,1,0,8,1,1,0,2,1,1,
			0,3,1,1,0,12,1,1,0,12,1,1,0,5,1,1,0,14,1,1,0,10,1,1,0,3,1,1,0,26,1,1,0,8,1,9,4,1,1,8,0,6,1,1,0,7,1,1,0,6,1,1,0,4,1,9,0,3,1,10,0,2,1,1,0,3,1,1,0,12,1,1,0,12,1,1,0,5,4,1,1,7,4,1,1,7,0,10,1,1,0,3,1,1,0,26,1,1,0,21,3,3,0,1,3,2,0,5,1,1,0,7,1,1,0,3,3,2,0,1,1,1,0,4,1,1,0,7,1,1,0,3,1,1,0,8,1,1,0,2,1,1,0,3,1,1,0,9,3,2,0,1,1,1,0,9,3,2,0,1,
			1,1,0,5,1,1,0,14,1,1,0,10,1,1,0,3,4,1,0,26,4,1,0,32,1,1,0,2,3,4,0,1,1,1,0,3,3,2,0,1,1,1,0,4,1,1,0,1,3,2,0,4,1,1,0,3,1,1,0,1,3,3,0,1,3,2,0,1,1,1,0,2,1,1,0,3,1,1,0,4,3,4,0,1,3,2,0,1,1,1,0,6,3,2,0,1,3,2,0,1,1,1,0,5,1,1,0,1,3,2,0,1,3,1,0,9,1,1,0,10,1,1,0,3,1,5,4,1,1,8,4,1,1,8,4,1,1,4,0,32,1,1,0,7,1,1,0,6,1,1,0,4,1,1,0,7,1,1,0,3,
			1,1,0,1,3,3,0,4,1,1,0,2,1,1,0,3,1,1,0,12,1,1,0,12,1,1,0,5,1,1,0,14,1,1,0,10,1,1,0,3,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,21,3,1,0,4,3,2,0,4,1,8,4,1,1,7,0,4,1,1,0,1,3,3,0,3,1,1,0,3,1,1,0,8,1,1,0,2,1,1,0,3,1,13,4,1,1,13,0,5,1,1,0,14,1,1,0,10,1,1,0,3,1,1,0,1,3,2,0,5,1,1,0,1,3,2,0,2,3,1,0,2,1,1,0,1,3,2,0,2,3,1,0,2,1,1,0,26,3,2,0,24,1,1,0,1,
			3,3,0,3,4,1,0,3,4,1,0,4,3,3,0,1,1,1,0,38,1,1,0,8,3,1,0,1,3,3,0,1,1,1,0,10,1,1,0,3,1,1,0,1,3,2,0,5,1,1,0,8,1,1,0,8,1,1,0,52,1,1,0,7,1,1,0,3,1,1,0,8,1,1,0,38,1,1,0,14,1,1,0,10,1,1,0,3,1,1,0,4,3,3,0,1,1,1,0,8,1,1,0,8,1,1,0,52,1,1,0,3,3,3,0,1,1,1,0,3,1,1,0,4,3,3,0,1,1,1,0,38,1,8,4,1,1,7,0,10,1,1,0,3,1,1,0,8,1,1,0,5,3,2,0,1,1,1,0,5,
			3,2,0,1,1,1,0,6,3,3,0,1,3,2,0,5,3,3,0,1,3,2,0,5,3,3,0,1,3,2,0,5,3,3,0,1,3,2,0,7,1,1,0,7,1,1,0,3,1,1,0,8,1,1,0,64,1,1,0,3,1,1,0,3,3,2,0,1,3,1,0,1,1,1,0,1,3,3,0,1,3,2,0,1,1,1,0,1,3,3,0,1,3,2,0,1,1,1,0,52,1,9,0,3,1,10,0,64,1,1,0,3,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,52,1,1,0,7,1,1,0,3,1,1,0,8,1,1,0,68,1,14,4,1,1,13,0,6,3,1,0,4,3,2,0,4,
			3,1,0,4,3,2,0,4,3,1,0,4,3,2,0,4,3,1,0,4,3,2,0,6,1,1,0,1,3,3,0,3,1,1,0,3,1,1,0,1,3,3,0,1,3,2,0,1,1,1,0,2,1,1,0,3,3,4,0,1,3,4,0,1,3,4,0,87,3,2,0,9,3,2,0,9,3,2,0,9,3,2,0,6,1,1,0,7,1,1,0,3,1,1,0,1,3,3,0,4,1,1,0,2,1,1,0,3,3,4,0,1,3,4,0,1,3,4,0,128,1,1,0,2,3,3,0,2,1,1,0,3,1,1,0,8,1,1,0,2,1,1,0,145,4,1,0,7,4,1,0,3,4,1,0,4,3,3,0,1,
			1,1,0,2,1,1,0,33,1,2,5,1,1,10,5,1,1,2,0,12,1,1,0,83,1,1,0,3,3,3,0,1,1,1,0,3,1,1,0,8,1,1,0,2,1,1,0,3,1,2,5,1,1,20,5,1,1,2,0,4,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,12,1,1,0,83,1,1,0,3,3,3,0,1,1,1,0,3,1,1,0,4,3,3,0,1,1,1,0,2,1,1,0,3,1,1,0,7,1,1,0,7,1,1,0,8,1,1,0,4,1,1,0,1,3,2,0,1,1,1,0,3,1,1,0,1,3,1,0,3,5,1,0,12,1,1,0,3,1,2,5,1,1,72,5,1,
			1,2,0,2,1,1,0,7,1,1,0,3,1,1,0,8,1,1,0,2,1,1,0,3,1,1,0,1,3,2,0,4,1,1,0,1,3,2,0,4,1,1,0,1,3,2,0,2,3,2,0,1,5,1,0,4,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,12,1,1,0,3,1,1,0,14,1,1,0,14,1,1,0,14,1,1,0,15,1,1,0,15,1,1,0,2,1,9,0,3,1,10,0,2,1,1,0,3,1,1,0,1,3,2,0,1,3,2,0,1,1,1,0,1,3,2,0,1,3,2,0,1,1,1,0,1,3,2,0,2,3,2,0,1,1,1,0,4,1,1,0,4,4,1,0,3,
			4,1,0,5,1,1,0,12,1,1,0,3,1,1,0,1,3,2,0,1,3,3,0,7,1,1,0,1,3,2,0,1,3,3,0,7,1,1,0,1,3,3,0,1,3,3,0,6,1,1,0,1,3,3,0,1,3,2,0,8,1,1,0,1,3,3,0,1,3,2,0,8,5,1,0,2,1,1,0,7,1,1,0,3,1,1,0,8,1,1,0,2,1,1,0,3,1,1,0,7,1,1,0,7,1,1,0,8,1,1,0,4,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,12,1,1,0,3,1,1,0,4,3,3,0,7,1,1,0,4,3,3,0,7,1,1,0,14,1,1,0,1,3,3,0,11,
			1,1,0,1,3,3,0,11,1,1,0,2,1,1,0,1,3,3,0,3,1,1,0,3,1,1,0,1,3,3,0,4,1,1,0,2,1,1,0,3,1,4,4,1,1,7,4,1,1,8,4,1,1,4,0,4,1,1,0,1,3,2,0,1,1,1,0,3,1,1,0,2,3,2,0,1,1,1,0,16,1,1,0,14,1,1,0,14,1,1,0,14,1,1,0,15,1,1,0,15,1,1,0,2,1,1,0,1,3,3,0,3,1,1,0,3,1,1,0,8,1,1,0,2,1,1,0,3,1,1,0,24,1,1,0,4,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,16,1,1,0,14,1,1,0,14,
			1,1,0,10,3,3,0,1,1,1,0,15,1,1,0,15,1,1,0,2,1,1,0,7,1,1,0,3,1,1,0,1,3,3,0,4,1,1,0,2,1,1,0,3,1,1,0,24,1,1,0,4,1,6,0,3,1,7,0,16,1,1,0,4,3,3,0,3,3,3,0,1,1,1,0,4,3,3,0,3,3,3,0,1,1,1,0,5,3,2,0,3,3,3,0,1,1,1,0,4,3,3,0,4,3,3,0,1,1,1,0,4,3,3,0,4,3,3,0,1,1,1,0,2,1,1,0,1,3,2,0,4,4,1,0,3,4,1,0,8,1,1,0,2,1,1,0,3,4,1,0,24,4,1,0,4,1,1,0,4,
			1,1,0,3,1,1,0,5,1,1,0,16,1,1,0,14,1,1,0,14,1,1,0,14,1,1,0,15,1,1,0,15,1,1,0,2,1,1,0,7,1,1,0,3,1,1,0,4,3,3,0,1,1,1,0,2,1,1,0,3,1,4,4,1,1,7,4,1,1,8,4,1,1,4,0,4,1,1,0,1,3,2,0,1,1,1,0,3,1,1,0,1,3,1,0,3,1,1,0,16,1,8,4,1,1,14,4,1,1,14,4,1,1,14,4,1,1,15,4,1,1,8,0,2,1,1,0,3,3,3,0,1,1,1,0,3,1,1,0,1,3,2,0,1,3,3,0,1,1,1,0,2,1,1,0,3,1,1,0,7,
			1,1,0,7,1,1,0,8,1,1,0,4,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,16,1,1,0,76,1,1,0,2,1,1,0,7,1,1,0,3,1,1,0,8,1,1,0,2,1,1,0,3,1,1,0,1,3,2,0,4,1,1,0,1,3,2,0,1,3,2,0,1,1,1,0,1,3,2,0,5,1,1,0,4,1,1,0,4,4,1,0,3,4,1,0,5,1,1,0,12,1,1,0,3,1,1,0,76,1,1,0,2,1,9,0,3,1,10,0,2,1,1,0,3,1,1,0,4,3,2,0,1,1,1,0,1,3,2,0,4,1,1,0,1,3,2,0,2,3,2,0,1,1,1,0,4,
			4,1,0,4,1,1,0,3,1,1,0,5,1,1,0,12,1,1,0,3,4,1,0,76,4,1,0,2,1,1,0,7,1,1,0,3,1,1,0,8,1,1,0,2,1,1,0,3,1,1,0,4,3,2,0,1,1,1,0,7,1,1,0,5,3,2,0,1,1,1,0,4,1,1,0,2,3,1,0,1,1,1,0,3,1,1,0,2,3,2,0,1,1,1,0,12,1,1,0,3,1,8,4,1,1,14,4,1,1,14,4,1,1,14,4,1,1,15,4,1,1,8,0,2,1,1,0,1,3,3,0,3,1,1,0,3,1,1,0,1,3,2,0,1,3,3,0,1,1,1,0,2,1,1,0,3,1,1,0,7,
			1,1,0,7,1,1,0,8,1,1,0,4,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,12,1,1,0,3,1,1,0,14,1,1,0,14,1,1,0,14,1,1,0,15,1,1,0,15,1,1,0,2,1,1,0,1,3,3,0,3,1,1,0,3,1,1,0,4,3,3,0,1,1,1,0,2,1,1,0,3,1,13,4,1,1,12,0,4,1,6,0,3,1,7,0,12,1,1,0,3,1,1,0,1,3,3,0,4,3,3,0,3,1,1,0,1,3,3,0,1,3,2,0,7,1,1,0,1,3,3,0,1,3,2,0,7,1,1,0,1,3,3,0,4,3,3,0,4,1,1,0,1,3,2,0,1,
			3,3,0,8,1,1,0,2,1,1,0,7,1,1,0,3,1,1,0,8,1,1,0,2,1,1,0,33,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,12,1,1,0,3,1,1,0,14,1,1,0,1,3,3,0,10,1,1,0,1,3,3,0,10,1,1,0,15,1,1,0,4,3,3,0,8,1,1,0,2,1,1,0,1,3,2,0,4,4,1,0,3,4,1,0,4,3,3,0,1,1,1,0,2,1,1,0,33,1,1,0,1,3,1,0,2,1,1,0,3,1,1,0,1,3,3,0,1,1,1,0,12,1,1,0,3,1,1,0,14,1,1,0,14,1,1,0,14,1,1,0,15,1,1,0,15,
			1,1,0,2,1,1,0,7,1,1,0,3,1,1,0,8,1,1,0,2,1,1,0,33,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,12,1,1,0,3,1,1,0,14,1,1,0,14,1,1,0,14,1,1,0,15,1,1,0,15,1,1,0,2,1,1,0,3,3,3,0,1,1,1,0,3,1,1,0,4,3,3,0,1,1,1,0,2,1,1,0,33,1,1,0,1,3,2,0,1,1,1,0,3,1,1,0,2,3,2,0,1,1,1,0,12,1,1,0,3,1,1,0,7,3,3,0,4,1,1,0,14,1,1,0,14,1,1,0,11,3,3,0,1,1,1,0,15,1,1,0,2,1,1,0,7,
			1,1,0,3,1,1,0,8,1,1,0,2,1,1,0,5,1,2,5,1,1,14,5,1,1,2,0,8,1,1,0,4,4,1,0,3,4,1,0,5,1,1,0,12,1,1,0,3,1,1,0,7,3,3,0,1,3,2,0,1,1,1,0,6,3,3,0,1,3,3,0,1,1,1,0,5,3,3,0,2,3,3,0,1,1,1,0,8,3,2,0,1,3,3,0,1,1,1,0,7,3,3,0,1,3,3,0,1,1,1,0,2,1,11,4,1,1,10,0,2,1,1,0,5,1,1,0,18,1,1,0,8,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,12,1,1,0,3,1,1,0,14,1,1,0,14,
			1,1,0,14,1,1,0,15,1,1,0,15,1,1,0,26,1,1,0,5,1,1,0,1,3,3,0,1,3,2,0,11,5,1,0,8,1,1,0,1,3,2,0,1,1,1,0,3,1,1,0,3,3,1,0,1,1,1,0,12,1,1,0,3,1,39,4,1,1,38,0,26,1,1,0,5,1,1,0,5,3,2,0,11,1,1,0,8,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,12,1,1,0,85,1,2,5,1,1,8,5,1,1,2,0,8,1,1,0,5,4,1,0,12,3,2,0,4,1,1,0,8,1,8,4,1,1,7,0,12,1,1,0,85,1,1,0,12,1,1,0,8,1,1,0,5,
			1,1,0,12,3,2,0,1,3,2,0,1,1,1,0,36,1,1,0,85,1,1,0,1,3,3,0,8,5,1,0,8,1,1,0,5,1,1,0,18,1,1,0,36,1,1,0,85,4,1,0,7,3,1,0,1,3,2,0,1,1,1,0,8,1,1,0,5,1,10,4,1,1,9,0,36,1,109,0,147,1,7,4,1,1,6,0,1400
		],
		"floor": [
			0,170,4,510,0,16,2,82,0,88,2,82,0,88,2,82,0,88,2,82,0,88,2,82,0,88,2,82,0,130,1,6,0,164,1,6,0,164,1,6,0,32,3,22,0,14,3,30,0,66,1,6,0,32,3,22,0,14,3,30,0,66,1,6,0,6,3,20,0,6,3,22,0,14,3,30,0,66,1,6,0,6,3,20,0,6,3,22,0,14,3,30,0,10,3,18,0,38,1,6,0,6,3,20,0,6,3,22,0,14,3,30,0,10,3,18,0,38,1,6,0,6,3,20,0,6,3,22,0,14,3,30,0,10,3,18,0,20,3,12,0,6,1,6,0,6,3,20,0,6,3,22,0,14,3,30,0,10,3,18,
			0,20,3,12,0,6,1,6,0,6,3,20,0,6,3,22,0,14,3,30,0,10,3,18,0,20,3,12,0,4,3,6,1,2,0,6,3,20,0,6,3,22,0,14,3,30,0,10,3,18,0,20,3,12,0,4,3,6,1,2,0,6,3,20,0,6,3,22,0,14,3,30,0,10,3,18,0,20,3,12,0,4,3,6,1,2,0,6,3,20,0,6,3,22,0,14,3,30,0,10,3,18,0,20,3,12,0,4,3,6,1,2,0,6,3,20,0,6,3,22,0,14,3,30,0,10,3,18,0,20,3,12,0,4,3,6,1,2,0,6,3,20,0,6,3,22,0,14,3,30,0,10,3,18,0,20,3,12,0,6,
			1,6,0,6,3,20,0,6,3,22,0,14,3,30,0,10,3,18,0,38,1,6,0,6,3,20,0,6,3,22,0,14,3,30,0,10,3,18,0,38,1,6,0,6,3,20,0,6,3,22,0,14,3,30,0,66,1,6,0,164,1,6,0,164,1,6,0,106,1,850,0,22,1,4,0,32,1,6,0,76,7,30,0,22,1,4,0,32,1,6,0,76,7,30,0,22,1,4,0,6,7,26,1,6,7,6,3,18,7,24,0,2,3,22,0,4,7,2,3,27,7,1,0,22,1,4,0,6,7,2,3,28,1,2,7,6,3,18,7,24,0,2,3,22,0,4,7,2,3,27,7,1,0,4,3,16,0,2,1,4,
			0,6,7,2,3,28,1,2,7,6,3,18,7,6,3,16,7,2,0,2,3,22,0,4,7,2,3,27,7,1,0,4,3,16,0,2,1,4,0,6,7,2,3,28,1,2,7,6,3,18,7,6,3,16,7,2,0,2,3,22,0,4,7,2,3,27,7,1,0,4,3,16,0,2,1,4,0,6,7,2,3,28,1,2,7,6,3,18,7,6,3,16,7,2,0,2,3,22,0,4,7,2,3,27,7,1,0,4,3,16,0,2,1,4,0,6,7,2,3,28,1,2,7,6,3,18,7,6,3,16,7,2,0,2,3,22,0,4,7,2,3,27,7,1,0,4,3,16,0,2,1,4,0,6,7,2,3,28,1,2,
			7,6,3,18,7,6,3,16,7,2,0,2,3,22,0,4,7,2,3,27,7,1,0,4,3,16,0,2,1,4,0,6,7,2,3,28,1,2,7,6,3,18,7,6,3,16,7,2,0,2,3,22,0,4,7,2,3,27,7,1,0,4,3,16,0,2,1,4,0,6,7,2,3,28,1,2,7,6,3,18,7,6,3,16,7,2,0,2,3,22,0,4,7,2,3,27,7,1,0,4,3,16,0,2,1,4,0,6,7,2,3,28,1,2,7,6,3,18,7,6,3,16,7,2,0,2,3,22,0,4,7,2,3,27,7,1,0,4,3,16,0,2,1,4,0,6,7,2,3,28,1,2,7,30,3,16,7,2,0,2,
			3,22,0,4,7,2,3,27,7,1,0,4,3,16,0,2,1,4,0,6,7,2,3,28,1,2,7,30,3,16,7,2,0,2,3,22,0,4,7,2,3,27,7,1,0,4,3,16,0,2,1,4,0,6,7,2,3,28,1,2,7,30,3,16,7,2,0,2,3,22,0,4,7,2,3,27,7,1,0,4,3,16,0,2,1,4,0,6,7,2,3,28,1,2,7,30,3,16,7,2,0,2,3,22,0,4,7,2,3,27,7,1,0,4,3,16,0,2,1,4,0,6,7,2,3,28,1,2,7,46,1,4,3,22,1,34,0,4,3,16,0,2,1,4,0,6,7,2,3,28,1,2,7,46,1,4,3,22,1,6,
			4,28,0,4,3,16,0,2,1,4,0,6,7,2,3,28,1,2,7,46,1,4,3,22,1,6,4,28,0,4,3,16,0,2,1,4,0,6,7,2,3,28,1,2,7,46,1,4,3,22,1,6,4,28,0,22,1,4,0,6,7,2,3,28,1,2,7,46,1,4,3,22,1,6,4,28,0,22,1,4,0,6,7,2,3,28,1,2,7,46,1,4,3,22,1,34,0,22,1,4,0,6,7,2,3,28,1,2,7,48,0,2,3,22,0,4,7,30,0,22,1,4,0,6,7,26,1,6,7,48,0,2,3,22,0,4,7,30,0,20,1,6,0,6,7,26,1,6,7,48,0,2,3,22,0,4,7,30,0,20,
			1,6,0,6,7,26,1,6,7,48,0,2,3,22,0,4,7,30,0,2,3,16,0,2,1,6,0,32,1,6,0,50,3,22,0,4,7,2,3,26,7,2,0,2,3,16,0,2,1,6,0,32,1,6,0,50,3,22,0,4,7,2,3,26,7,2,0,2,3,16,0,2,1,6,0,8,3,78,0,2,3,22,0,4,7,2,3,26,7,2,0,2,3,16,0,2,1,6,0,8,3,78,0,2,3,22,0,4,7,2,3,26,7,2,0,2,3,16,0,2,1,6,0,8,3,78,0,2,3,22,0,4,7,2,3,26,7,2,0,2,3,16,0,2,1,6,0,8,3,78,0,2,3,22,0,4,7,2,3,26,
			7,2,0,2,3,16,0,2,1,14,3,78,0,2,3,22,0,4,7,2,3,26,7,2,0,2,3,16,0,2,1,14,3,78,0,2,3,22,0,4,7,2,3,26,7,2,0,2,3,16,0,2,1,14,3,78,0,2,3,22,0,4,7,2,3,26,7,2,0,2,3,16,0,2,1,14,3,78,0,2,3,22,0,4,7,2,3,26,7,2,0,2,3,16,0,2,1,14,3,78,0,2,3,22,0,4,7,2,3,26,7,2,0,2,3,16,0,2,1,14,3,78,0,2,3,22,0,4,7,2,3,26,7,2,0,2,3,16,0,2,1,6,0,8,3,78,0,2,3,22,0,4,7,2,3,26,7,2,0,2,
			3,16,0,2,1,6,0,8,3,78,0,2,3,22,0,4,7,2,3,26,7,2,0,2,3,16,0,2,1,6,0,8,3,78,0,2,3,22,0,4,7,2,3,26,7,2,0,2,3,16,0,2,1,6,0,8,3,78,0,2,3,22,0,4,7,2,3,26,7,2,0,2,3,16,0,2,1,6,0,8,3,78,0,2,3,22,0,4,7,30,0,2,3,16,0,2,1,6,0,8,3,78,0,2,3,22,0,4,7,30,0,2,3,16,0,2,1,6,0,8,3,78,0,2,3,22,0,4,7,30,0,2,3,16,0,2,1,6,0,8,3,78,0,2,3,22,0,4,7,30,0,2,3,16,0,2,1,6,0,8,
			3,78,0,2,3,22,0,4,7,4,3,20,7,6,0,2,3,16,0,2,1,6,0,8,3,78,0,2,3,22,0,4,7,4,3,20,7,6,0,2,3,16,0,2,1,6,0,8,3,78,0,28,7,4,3,20,7,6,0,2,3,16,0,2,1,6,0,8,3,78,0,28,7,4,3,20,7,6,0,2,3,16,0,2,1,6,0,90,3,14,0,10,7,4,3,20,7,6,0,2,3,16,0,2,1,6,0,90,3,14,0,10,7,4,3,20,7,6,0,20,1,6,0,90,3,14,0,10,7,4,3,20,7,6,0,20,1,6,0,90,3,14,0,10,7,4,3,20,7,6,0,20,1,6,0,90,3,14,0,10,
			7,30,0,20,1,6,0,90,3,14,0,40,1,850,0,20,1,6,0,164,1,6,0,164,1,6,0,144
		],
		"trees": [[122,15],[129,15],[164,15],[125,18],[167,18],[121,21],[128,21],[163,21],[124,24],[166,24],[120,27],[127,27],[4,30],[18,30],[25,30],[32,30],[39,30],[46,30],[53,30],[67,30],[74,30],[81,30],[88,30],[102,30],[109,30],[116,30],[123,30],[130,30],[137,30],[144,30],[151,30],[158,30],[165,30],[3,36],[10,36],[17,36]]
	},
	{
		"solid": [
			0,191,2,80,0,95,2,80,0,95,2,80,0,1352,3,3,0,190,3,1,0,174,3,1,0,116,1,2,5,1,1,10,5,1,1,2,0,12,1,2,5,2,1,2,0,141,1,1,0,7,1,1,0,6,1,1,0,12,1,1,0,4,1,1,0,87,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,11,1,1,0,7,1,1,0,6,5,1,0,12,4,1,0,4,5,1,0,66,1,2,5,1,1,8,5,1,1,2,0,61,1,1,0,7,1,1,0,6,1,1,0,12,1,1,0,4,1,1,0,66,1,1,0,12,1,1,0,61,1,1,0,7,1,1,
			0,6,1,1,0,12,1,3,4,1,1,2,0,66,1,1,0,12,5,1,0,3,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,15,1,1,0,7,1,1,0,6,1,1,0,84,1,1,0,12,1,1,0,61,4,1,0,7,4,1,0,6,1,1,0,34,1,2,5,1,1,14,5,1,1,2,0,30,1,1,0,12,1,1,0,61,1,1,0,7,1,1,0,6,1,1,0,34,1,1,0,18,1,1,0,30,1,1,0,12,1,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,12,1,1,
			0,7,1,1,0,6,1,1,0,34,1,1,0,18,5,1,0,30,1,1,0,12,1,1,0,61,1,1,0,7,1,1,0,6,1,1,0,34,1,1,0,18,1,1,0,30,1,1,0,12,1,1,0,61,1,1,0,7,1,1,0,6,1,1,0,12,1,2,5,1,1,4,5,1,1,2,0,12,1,1,0,18,1,1,0,6,3,2,0,22,1,1,0,12,1,1,0,2,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,16,1,8,4,1,1,7,0,12,1,1,0,8,1,1,0,12,1,1,0,18,1,1,0,6,3,2,0,22,1,1,0,12,1,1,
			0,81,3,4,0,4,1,1,0,8,5,1,0,12,1,1,0,18,1,1,0,30,1,1,0,12,1,1,0,81,3,4,0,4,4,1,0,8,1,1,0,12,4,1,1,9,4,1,1,9,0,30,1,1,0,8,3,3,0,1,1,1,0,5,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,41,1,1,0,8,1,1,0,12,1,1,0,18,1,1,0,30,1,1,0,12,1,1,0,89,1,5,4,1,1,4,0,12,1,1,0,18,1,1,0,30,4,1,1,6,4,1,1,6,0,57,2,1,0,53,1,1,0,18,1,1,0,30,1,1,0,12,1,1,
			0,111,1,1,0,18,1,1,0,30,1,1,0,1,3,2,0,1,3,1,0,7,1,1,0,111,1,1,0,6,3,3,0,4,3,4,0,1,1,1,0,30,1,1,0,12,1,1,0,111,1,1,0,18,1,1,0,30,1,1,0,12,1,1,0,111,1,10,4,1,1,9,0,30,1,1,0,12,1,1,0,2,3,2,0,2,3,2,0,5,3,2,0,2,3,2,0,5,3,2,0,2,3,2,0,5,3,2,0,2,3,2,0,120,1,1,0,12,1,1,0,2,3,2,0,9,3,2,0,9,3,2,0,9,3,2,0,22,1,2,5,1,1,14,5,1,1,2,0,52,1,2,5,1,1,12,5,1,1,2,
			0,12,1,1,0,12,1,1,0,59,1,1,0,9,1,1,0,8,1,1,0,52,1,1,0,16,1,1,0,12,1,1,0,12,1,1,0,2,3,2,0,3,3,1,0,5,3,2,0,3,3,1,0,5,3,2,0,3,3,1,0,5,3,2,0,3,3,1,0,18,1,1,0,1,3,2,0,1,3,3,0,2,1,1,0,1,3,1,0,1,3,2,0,3,5,1,0,52,1,1,0,1,3,4,0,1,3,1,0,9,5,1,0,12,1,1,0,12,1,1,0,2,3,2,0,9,3,2,0,9,3,2,0,9,3,2,0,22,1,1,0,9,1,1,0,8,1,1,0,52,1,1,0,9,3,1,0,1,3,4,
			0,1,1,1,0,12,1,1,0,4,3,2,0,2,3,3,0,1,1,1,0,59,1,1,0,9,1,1,0,8,1,1,0,52,1,1,0,16,1,1,0,12,1,1,0,12,1,1,0,24,1,2,5,1,1,8,5,1,1,2,0,2,1,2,5,1,1,4,5,1,1,2,0,9,1,1,0,9,1,1,0,8,1,1,0,6,3,2,0,2,3,2,0,27,3,2,0,2,3,2,0,7,4,1,1,8,4,1,1,8,0,2,3,2,0,2,3,2,0,4,1,7,4,1,1,6,0,9,3,2,0,2,3,2,0,9,1,1,0,6,1,1,0,5,1,1,0,2,1,1,0,8,1,1,0,9,4,1,0,9,
			4,1,0,8,1,1,0,6,3,2,0,31,3,2,0,11,1,1,0,16,1,1,0,2,3,2,0,31,3,2,0,13,1,1,0,1,3,3,0,2,1,1,0,1,3,1,0,3,5,1,0,2,1,1,0,1,3,3,0,4,5,1,0,9,1,1,0,9,1,1,0,8,1,1,0,52,1,1,0,1,3,1,0,1,3,4,0,2,3,1,0,1,3,4,0,1,1,1,0,50,1,1,0,6,1,1,0,5,1,1,0,2,1,1,0,8,1,1,0,9,1,1,0,9,1,1,0,8,1,1,0,6,3,2,0,3,3,1,0,27,3,2,0,3,3,1,0,7,1,1,0,16,1,1,0,2,3,2,0,3,
			3,1,0,27,3,2,0,3,3,1,0,9,1,1,0,1,3,1,0,4,1,1,0,1,3,2,0,2,1,1,0,2,4,1,0,8,1,1,0,9,1,1,0,4,3,2,0,1,3,1,0,1,1,1,0,1,3,3,0,1,3,2,0,1,1,1,0,6,3,2,0,31,3,2,0,11,1,9,4,1,1,8,0,2,3,2,0,31,3,2,0,13,1,1,0,6,1,1,0,5,1,1,0,2,1,1,0,2,3,2,0,2,3,1,0,1,1,1,0,9,1,1,0,9,1,1,0,8,1,1,0,120,4,1,0,6,4,1,0,5,1,1,0,2,1,1,0,8,1,1,0,9,1,10,4,1,1,9,0,120,
			1,1,0,6,1,1,0,3,3,1,0,1,1,1,0,2,1,5,4,1,1,4,0,149,1,1,0,6,1,1,0,5,1,1,0,161,1,1,0,1,3,2,0,1,3,1,0,1,1,1,0,1,3,3,0,1,1,1,0,161,1,1,0,6,1,1,0,5,1,1,0,161,1,7,4,1,1,6,0,17,3,4,0,171,3,4,0,346,3,4,0,6,3,4,0,52,3,2,0,2,3,2,0,103,3,4,0,6,3,4,0,52,3,2,0,294,1,2,5,1,1,40,5,1,1,2,0,8,3,2,0,3,3,1,0,4,1,2,5,1,1,28,5,1,1,2,0,2,1,6,0,2,1,6,0,2,1,6,0,53,
			1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,8,3,2,0,8,1,1,0,5,1,1,0,5,1,1,0,6,1,1,0,6,1,1,0,6,1,1,0,2,1,6,0,2,1,6,0,2,1,6,0,53,1,1,0,1,3,2,0,2,3,2,0,1,1,1,0,1,3,2,0,2,3,2,0,1,1,1,0,1,3,2,0,5,1,1,0,1,3,2,0,2,3,2,0,1,1,1,0,1,3,2,0,2,3,2,0,1,5,1,0,18,1,1,0,1,3,2,0,2,1,1,0,1,3,2,0,2,1,1,0,1,3,2,0,3,1,1,0,1,3,3,0,2,1,1,0,1,
			3,2,0,3,5,1,0,2,1,6,0,2,1,6,0,2,1,6,0,10,1,2,5,1,1,20,5,1,1,2,0,17,1,1,0,1,3,2,0,2,3,2,0,1,1,1,0,1,3,2,0,2,3,2,0,1,1,1,0,1,3,2,0,2,3,2,0,1,1,1,0,5,3,2,0,1,1,1,0,5,3,2,0,1,1,1,0,18,1,1,0,1,3,2,0,2,1,1,0,5,1,1,0,6,1,1,0,6,1,1,0,1,3,2,0,3,1,1,0,2,1,6,0,2,1,6,0,2,1,6,0,10,1,1,0,7,1,1,0,7,1,1,0,8,1,1,0,17,1,1,0,8,1,1,0,8,1,1,0,8,
			1,1,0,8,1,1,0,8,1,1,0,4,3,2,0,2,3,2,0,8,1,1,0,5,1,1,0,5,1,1,0,6,1,1,0,3,3,2,0,1,1,1,0,6,1,1,0,2,1,6,0,2,1,6,0,2,1,6,0,10,1,1,0,1,3,1,0,1,3,3,0,1,1,1,0,1,3,1,0,1,3,3,0,1,1,1,0,1,3,1,0,1,3,2,0,3,5,1,0,17,1,5,4,1,1,8,4,1,1,8,4,1,1,8,4,1,1,8,4,1,1,4,0,4,3,2,0,12,1,1,0,2,3,2,0,1,1,1,0,1,3,3,0,1,1,1,0,2,3,3,0,1,1,1,0,6,1,1,0,6,
			1,1,0,2,1,6,0,2,1,6,0,2,1,6,0,10,1,1,0,7,1,1,0,7,1,1,0,8,1,1,0,17,1,1,0,44,1,1,0,18,1,1,0,5,1,1,0,5,1,1,0,6,1,1,0,1,3,2,0,3,1,1,0,1,3,2,0,3,1,1,0,34,1,1,0,2,3,1,0,1,3,2,0,1,1,1,0,2,3,1,0,1,3,2,0,1,1,1,0,1,3,3,0,2,3,1,0,1,1,1,0,17,1,1,0,44,1,1,0,4,3,2,0,3,3,1,0,8,1,1,0,5,1,1,0,5,1,1,0,6,1,1,0,1,3,2,0,3,1,1,0,1,3,2,0,3,1,1,0,34,
			1,1,0,7,1,1,0,7,1,1,0,8,1,1,0,17,4,1,0,44,4,1,0,4,3,2,0,12,1,1,0,5,1,1,0,5,1,1,0,6,1,1,0,6,1,1,0,6,1,1,0,34,1,4,4,1,1,7,4,1,1,8,4,1,1,4,0,17,1,5,4,1,1,8,4,1,1,8,4,1,1,8,4,1,1,8,4,1,1,4,0,18,1,3,4,1,1,5,4,1,1,6,4,1,1,6,4,1,1,6,4,1,1,3,0,34,1,1,0,24,1,1,0,17,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,18,1,1,0,32,1,1,0,34,1,1,0,24,
			1,1,0,17,1,1,0,1,3,2,0,5,1,1,0,1,3,2,0,5,1,1,0,1,3,2,0,5,1,1,0,1,3,3,0,4,1,1,0,1,3,2,0,2,3,2,0,1,1,1,3,2,0,2,3,2,0,12,1,1,0,32,1,1,0,34,4,1,0,24,4,1,0,17,1,1,0,1,3,2,0,2,3,2,0,1,1,1,0,5,3,2,0,1,1,1,0,5,3,2,0,1,1,1,0,8,1,1,0,1,3,2,0,5,1,1,3,2,0,16,4,1,0,32,4,1,0,34,1,4,4,1,1,7,4,1,1,8,4,1,1,4,0,17,1,1,0,5,3,2,0,1,1,1,0,1,3,3,0,1,
			3,2,0,1,1,1,0,1,3,3,0,1,3,2,0,1,1,1,0,5,3,2,0,1,1,1,0,4,3,3,0,1,1,1,0,18,1,3,4,1,1,5,4,1,1,6,4,1,1,6,4,1,1,6,4,1,1,3,0,34,1,1,0,7,1,1,0,7,1,1,0,8,1,1,0,17,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,8,1,1,3,2,0,3,3,1,0,12,1,1,0,5,1,1,0,5,1,1,0,6,1,1,0,6,1,1,0,6,1,1,0,34,1,1,0,1,3,2,0,1,3,1,0,2,1,1,0,1,3,1,0,2,3,2,0,1,1,1,0,1,3,1,
			0,6,1,1,0,17,1,23,4,1,1,22,3,2,0,16,1,1,0,5,1,1,0,5,1,1,0,1,3,2,0,3,1,1,0,1,3,2,0,3,1,1,0,1,3,2,0,3,1,1,0,34,1,1,0,7,1,1,0,7,1,1,0,5,3,2,0,1,1,1,0,81,1,1,0,5,1,1,0,5,1,1,0,1,3,2,0,3,1,1,0,1,3,2,0,3,1,1,0,1,3,2,0,3,1,1,0,10,1,6,0,2,1,6,0,10,1,1,0,7,1,1,0,1,3,3,0,3,1,1,0,1,3,3,0,4,1,1,0,81,1,1,0,1,3,2,0,2,1,1,0,1,3,3,0,1,1,1,0,6,
			1,1,0,6,1,1,0,6,1,1,0,10,1,6,0,2,1,6,0,10,1,1,0,1,3,3,0,1,3,1,0,1,1,1,0,5,3,1,0,1,1,1,0,6,3,1,0,1,1,1,0,48,3,2,0,2,3,2,0,27,1,1,0,5,1,1,0,5,1,1,0,3,3,2,0,1,1,1,0,3,3,2,0,1,1,1,0,3,3,2,0,1,1,1,0,10,1,6,0,2,1,6,0,10,1,1,0,7,1,1,0,7,1,1,0,8,1,1,0,48,3,2,0,31,1,1,0,5,1,1,0,5,1,1,0,3,3,2,0,1,1,1,0,3,3,2,0,1,1,1,0,6,1,1,0,10,1,6,0,2,
			1,6,0,10,1,13,4,1,1,12,0,17,1,2,5,1,1,10,5,1,1,2,0,48,1,1,0,2,3,2,0,1,1,1,0,5,1,1,0,6,1,1,0,6,1,1,0,3,3,2,0,1,1,1,0,10,1,6,0,2,1,6,0,53,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,15,3,2,0,3,3,1,0,27,1,1,0,2,3,2,0,1,1,1,0,2,3,2,0,1,1,1,0,1,3,3,0,2,1,1,0,2,3,3,0,1,1,1,0,3,3,2,0,1,1,1,0,10,1,6,0,2,1,6,0,53,1,1,0,1,3,2,0,1,1,1,0,3,1,1,0,1,3,2,0,2,
			5,1,0,15,3,2,0,31,1,1,0,5,1,1,0,5,1,1,0,6,1,1,0,6,1,1,0,6,1,1,0,77,1,1,0,1,3,2,0,1,1,1,0,3,1,1,0,1,3,2,0,2,1,1,0,48,1,17,4,1,1,16,0,77,1,1,0,4,4,1,0,3,4,1,0,5,1,1,0,8,1,2,5,1,1,12,5,1,1,2,0,92,1,4,0,37,1,1,0,4,1,1,0,3,1,1,0,1,3,3,0,1,1,1,0,8,1,1,0,16,1,1,0,92,1,4,0,37,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,8,1,1,0,1,3,2,0,1,3,2,0,10,5,1,0,133,
			1,6,0,3,1,7,0,8,1,1,0,1,3,2,0,13,1,1,0,133,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,8,1,1,0,16,1,1,0,6,1,2,5,1,1,20,5,1,1,2,0,42,1,6,0,53,1,1,0,1,3,2,0,1,1,1,0,3,1,1,0,1,3,2,0,2,1,1,0,8,1,1,0,16,1,1,0,6,1,1,0,7,1,1,0,7,1,1,0,8,1,1,0,42,1,6,0,53,1,1,0,1,3,2,0,1,1,1,0,3,1,1,0,1,3,2,0,2,1,1,0,8,1,1,0,9,3,2,0,5,1,1,0,6,1,1,0,7,1,1,0,3,3,3,0,1,
			1,1,0,1,3,2,0,1,3,3,0,1,5,1,0,12,1,2,5,1,1,6,5,1,1,2,0,18,1,6,0,12,1,2,5,1,1,18,5,1,1,2,0,17,1,1,0,4,4,1,0,3,4,1,0,5,1,1,0,8,1,1,0,9,3,2,0,1,3,3,0,1,1,1,0,6,1,1,0,4,3,2,0,1,1,1,0,7,1,1,0,1,3,2,0,5,1,1,0,12,1,1,0,10,1,1,0,18,1,6,0,12,1,1,0,11,1,1,0,10,1,1,0,17,4,1,0,4,1,1,0,3,1,1,0,2,3,2,0,1,1,1,0,8,1,1,0,16,1,1,0,6,1,1,0,1,3,2,0,1,
			3,2,0,1,1,1,0,1,3,2,0,4,1,1,0,5,3,2,0,1,1,1,0,12,1,1,0,1,3,1,0,1,3,2,0,5,5,1,0,18,1,6,0,12,1,1,0,1,3,2,0,1,3,2,0,5,1,1,0,1,3,4,0,1,3,2,0,2,5,1,0,17,1,1,0,4,1,1,0,3,1,1,0,2,3,2,0,1,1,1,0,8,4,1,1,8,4,1,1,8,0,6,1,1,0,7,1,1,0,7,1,1,0,8,1,1,0,12,1,1,0,10,1,1,0,18,1,6,0,12,1,1,0,4,3,2,0,5,1,1,0,6,3,2,0,2,1,1,0,17,1,1,0,4,1,1,0,3,1,1,
			0,5,1,1,0,8,1,1,0,16,1,1,0,6,1,4,4,1,1,7,4,1,1,8,4,1,1,4,0,12,1,1,0,4,3,1,0,1,3,3,0,1,1,1,0,36,1,1,0,11,1,1,0,10,1,1,0,17,1,6,0,3,1,7,0,8,1,1,0,1,3,2,0,1,3,2,0,10,1,1,0,6,1,1,0,24,1,1,0,12,1,1,0,10,1,1,0,36,1,1,0,11,1,1,0,10,1,1,0,17,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,8,1,1,0,1,3,2,0,13,1,1,0,6,4,1,0,24,4,1,0,12,4,1,1,5,4,1,1,5,0,36,1,1,0,11,
			1,1,0,10,1,1,0,17,1,1,0,1,3,2,0,1,1,1,0,3,1,1,0,1,3,2,0,2,1,1,0,8,1,1,0,16,1,1,0,6,1,1,0,24,1,1,0,12,1,1,0,10,1,1,0,36,4,1,0,11,4,1,0,10,4,1,0,17,1,1,0,1,3,2,0,1,1,1,0,3,1,1,0,5,1,1,0,8,1,1,0,13,3,2,0,1,1,1,0,6,1,4,4,1,1,7,4,1,1,8,4,1,1,4,0,12,1,1,0,1,3,3,0,2,3,1,0,3,1,1,0,36,1,1,0,11,1,1,0,10,1,1,0,17,1,1,0,4,4,1,0,3,4,1,0,5,1,1,0,8,
			1,1,0,9,3,3,0,1,3,2,0,1,1,1,0,6,1,1,0,7,1,1,0,7,1,1,0,8,1,1,0,12,1,1,0,8,3,1,0,1,1,1,0,36,1,1,0,11,1,1,0,10,1,1,0,17,1,1,0,1,3,2,0,1,1,1,0,3,1,1,0,2,3,2,0,1,1,1,0,8,1,1,0,16,1,1,0,6,1,1,0,4,3,2,0,1,1,1,0,4,3,2,0,1,1,1,0,1,3,2,0,5,1,1,0,12,1,1,0,10,1,1,0,36,1,1,0,3,3,2,0,6,1,1,0,4,3,2,0,4,1,1,0,17,1,1,0,1,3,2,0,1,1,1,0,3,1,1,0,2,
			3,2,0,1,1,1,0,8,1,9,4,1,1,8,0,6,1,1,0,7,1,1,0,7,1,1,0,5,3,2,0,1,1,1,0,12,1,6,4,1,1,5,0,36,1,1,0,3,3,2,0,1,3,4,0,1,1,1,0,4,3,2,0,1,3,2,0,1,1,1,0,17,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,32,1,1,0,1,3,3,0,3,1,1,0,1,3,3,0,3,1,1,0,1,3,3,0,1,3,2,0,1,1,1,0,60,1,1,0,11,1,1,0,10,1,1,0,17,1,8,4,1,1,7,0,32,1,1,0,7,1,1,0,7,1,1,0,8,1,1,0,60,1,12,4,1,
			1,11,0,65,1,13,4,1,1,12,0,437
		],
		"floor": [
			0,175,4,525,0,16,2,82,0,93,2,82,0,93,2,82,0,93,2,82,0,93,2,82,0,93,2,82,0,127,1,6,0,87,5,32,0,50,1,6,0,87,5,32,0,50,1,6,0,87,5,32,0,50,1,6,0,87,5,32,0,8,3,16,0,12,3,6,0,8,1,6,0,87,5,32,0,8,3,16,0,12,3,6,0,8,1,6,0,87,5,32,0,8,3,16,0,12,3,6,0,8,1,6,0,52,3,14,0,21,5,32,0,8,3,16,0,12,3,6,0,8,1,6,0,52,3,14,0,21,5,32,0,8,3,16,0,12,3,6,0,8,1,6,0,52,3,14,0,21,5,32,0,8,3,16,0,26,1,6,
			0,52,3,14,0,21,5,32,0,8,3,16,0,26,1,6,0,2,3,20,0,30,3,14,0,21,5,32,0,8,3,16,0,26,1,6,0,2,3,20,0,30,3,14,0,21,5,32,0,8,3,16,0,26,1,6,0,2,3,20,0,30,3,14,0,21,5,32,0,8,3,16,0,26,1,6,0,2,3,20,0,30,3,14,0,21,5,32,0,8,3,16,0,12,3,10,0,4,1,6,0,2,3,20,0,30,3,14,0,21,5,32,0,8,3,16,0,12,3,10,0,4,1,6,0,2,3,20,0,30,3,14,0,21,5,32,0,36,3,10,0,4,1,6,0,2,3,20,0,30,3,14,0,21,5,32,0,36,3,10,
			0,4,1,6,0,2,3,20,0,30,3,14,0,21,5,32,0,36,3,10,0,4,1,6,0,2,3,20,0,30,3,14,0,21,5,32,0,36,3,10,0,4,1,6,0,2,3,20,0,30,3,14,0,21,5,32,0,50,1,6,0,2,3,20,0,30,3,14,0,21,5,32,1,58,3,20,0,30,3,14,0,21,5,32,1,58,3,20,0,30,3,14,0,21,5,32,1,58,3,20,0,30,3,14,0,21,5,32,1,58,3,20,0,30,3,14,0,21,5,32,1,58,0,50,3,14,0,21,5,32,0,6,3,20,0,24,1,6,0,22,3,18,0,12,3,14,0,21,5,32,0,6,3,20,0,24,1,6,0,22,
			3,18,0,12,3,14,0,21,5,32,0,6,3,20,0,24,1,6,0,22,3,18,0,12,3,14,0,21,5,32,0,6,3,20,0,24,1,6,0,22,3,18,0,12,3,14,0,21,5,32,0,6,3,20,0,24,1,6,0,22,3,18,0,12,3,14,0,21,5,3,3,14,5,2,3,10,5,3,0,6,3,20,0,24,1,6,0,22,3,18,0,12,3,14,0,21,5,3,3,14,5,2,3,10,5,3,0,6,3,20,0,24,1,6,0,22,3,18,0,47,5,3,3,14,5,2,3,10,5,3,0,6,3,20,0,24,1,6,0,22,3,18,0,47,5,3,3,14,5,2,3,10,5,3,0,6,3,20,0,24,
			1,6,0,22,3,18,0,47,5,3,3,14,5,2,3,10,5,3,0,6,3,20,0,24,1,6,0,22,3,18,0,47,5,3,3,14,5,2,3,10,5,3,0,6,3,20,0,24,1,6,0,87,5,3,3,14,5,2,3,10,5,3,0,6,3,20,0,24,1,6,0,87,5,3,3,14,5,2,3,10,5,3,0,50,1,6,0,87,5,3,3,14,5,15,0,50,1,6,0,87,5,3,3,14,5,15,0,6,1,137,5,3,3,14,5,15,0,6,1,137,5,3,3,14,5,15,0,6,1,137,5,32,0,6,1,137,5,32,0,6,1,137,5,32,0,6,1,4,0,128,1,5,5,32,0,6,1,4,0,2,
			7,124,0,2,1,5,5,32,0,6,1,4,0,2,7,124,0,2,1,5,5,32,0,6,1,4,0,2,7,2,3,46,7,18,3,34,7,24,0,2,1,5,5,32,0,6,1,4,0,2,7,2,3,46,7,18,3,34,7,24,0,2,1,5,5,32,0,6,1,4,0,2,7,2,3,46,7,18,3,34,7,24,0,2,1,5,5,3,3,26,5,3,0,6,1,4,0,2,7,2,3,46,7,18,3,34,7,24,0,2,1,5,5,3,3,26,5,3,0,6,1,4,0,2,7,2,3,46,7,18,3,34,7,24,0,2,1,5,5,3,3,26,5,3,0,6,1,4,0,2,7,2,3,46,7,18,3,34,7,24,
			0,2,1,5,5,3,3,26,5,3,0,6,1,4,0,2,7,2,3,46,7,18,3,34,7,24,0,2,1,5,5,3,3,26,5,3,0,6,1,4,0,2,7,2,3,46,7,18,3,34,7,24,0,2,1,5,5,3,3,26,5,3,0,6,1,4,0,2,7,2,3,46,7,18,3,34,7,24,0,2,1,5,5,3,3,26,5,3,0,6,1,4,0,2,7,2,3,46,7,18,3,34,7,24,0,2,1,5,5,3,3,26,5,3,0,6,1,4,0,2,7,2,3,46,7,18,3,34,7,24,0,2,1,5,5,3,3,26,5,3,0,6,1,4,0,2,7,2,3,46,7,18,3,34,7,24,0,2,1,5,
			5,3,3,26,5,3,0,6,1,4,0,2,7,2,3,46,7,18,3,34,7,24,0,2,1,5,5,3,3,26,5,3,0,6,1,4,0,2,7,2,3,46,7,18,3,34,7,24,0,2,1,5,5,3,3,26,5,3,0,6,1,4,0,2,7,2,3,46,7,18,3,34,7,24,0,2,1,5,5,3,3,26,5,3,0,6,1,4,0,2,7,2,3,46,7,18,3,34,7,24,0,2,1,5,5,3,3,26,5,3,0,6,1,4,0,2,7,66,3,34,7,24,0,2,1,5,5,3,3,26,5,3,0,6,1,4,0,2,7,66,3,34,7,24,0,2,1,5,5,3,3,26,5,3,0,6,1,4,0,2,
			7,66,3,34,7,24,0,2,1,5,5,3,3,26,5,3,0,6,1,4,0,2,7,66,3,34,7,24,0,2,1,5,5,3,3,26,5,3,0,6,1,4,0,2,7,2,3,16,7,48,3,34,7,24,0,2,1,5,5,32,0,6,1,4,0,2,7,2,3,16,7,48,3,34,7,24,0,2,1,5,5,32,0,6,1,4,0,2,7,2,3,16,7,48,3,34,7,24,0,2,1,5,5,32,0,6,1,4,0,2,7,2,3,16,7,48,3,34,7,24,0,2,1,5,5,32,0,6,1,4,0,2,7,2,3,16,7,8,3,18,7,34,1,6,7,40,0,2,1,5,5,32,0,6,1,4,0,2,7,2,
			3,16,7,8,3,18,7,34,1,6,7,40,0,2,1,5,5,32,0,6,1,4,0,2,7,2,3,16,7,8,3,18,7,34,1,6,7,40,0,2,1,5,5,32,0,6,1,4,0,2,7,2,3,16,7,8,3,18,7,34,1,6,7,40,0,2,1,5,5,32,0,6,1,4,0,2,7,2,3,16,7,8,3,18,7,6,3,26,7,2,1,6,7,40,0,2,1,5,5,32,0,6,1,4,0,2,7,2,3,16,7,8,3,18,7,6,3,26,7,2,1,6,7,40,0,2,1,5,5,32,0,6,1,4,0,2,7,2,3,16,7,8,3,18,7,6,3,26,7,2,1,6,7,4,3,12,7,24,0,2,
			1,5,5,5,3,24,5,3,0,6,1,4,0,2,7,2,3,16,7,8,3,18,7,6,3,26,7,2,1,6,7,4,3,12,7,24,0,2,1,5,5,5,3,24,5,3,1,14,3,16,7,8,3,18,7,6,3,26,7,2,1,6,7,4,3,12,7,24,0,2,1,5,5,5,3,24,5,3,1,14,3,16,7,8,3,18,7,6,3,26,7,2,1,6,7,4,3,12,7,24,0,2,1,5,5,5,3,24,5,3,1,14,3,16,7,8,3,18,7,6,3,26,7,2,1,6,7,4,3,12,7,24,0,2,1,5,5,5,3,24,5,3,1,14,3,16,7,8,3,18,7,6,3,26,7,2,1,6,7,4,
			3,12,7,24,0,2,1,5,5,5,3,24,5,3,0,12,7,2,3,16,7,8,3,18,7,6,3,26,7,2,1,6,7,4,3,12,7,24,0,2,1,5,5,5,3,24,5,3,0,12,7,2,3,16,7,8,3,18,7,6,3,26,7,2,1,6,7,4,3,12,7,24,0,2,1,5,5,5,3,24,5,3,0,12,7,2,3,16,7,8,3,18,7,6,3,26,7,2,1,6,7,4,3,12,7,24,0,2,1,5,5,5,3,24,5,3,0,12,7,2,3,16,7,8,3,18,7,6,3,26,7,2,1,6,7,4,3,12,7,24,0,2,1,5,5,5,3,24,5,3,0,12,7,2,3,16,7,8,3,18,
			7,6,3,26,7,2,1,6,7,4,3,12,7,24,0,2,1,5,5,5,3,24,5,3,0,12,7,2,3,16,7,8,3,18,7,6,3,26,7,2,1,6,7,4,3,12,7,24,0,2,1,5,5,5,3,24,5,3,0,12,7,2,3,16,7,32,3,26,7,2,1,6,7,40,0,2,1,5,5,5,3,24,5,3,0,12,7,2,3,16,7,32,3,26,7,2,1,6,7,40,0,2,1,5,5,5,3,24,5,3,0,12,7,50,3,26,7,2,1,6,7,40,0,2,1,5,5,122,1,6,5,42,1,5,5,122,1,6,5,42,1,5,5,32
		],
		"trees": [[129,15],[136,15],[143,15],[150,15],[157,15],[164,15],[171,15],[125,18],[132,18],[139,18],[146,18],[153,18],[160,18],[167,18],[128,21],[135,21],[142,21],[149,21],[156,21],[163,21],[170,21],[124,24],[131,24],[138,24],[145,24],[152,24],[159,24],[166,24],[127,27],[134,27],[141,27],[148,27],[155,27],[162,27],[169,27],[4,30]]
	},
	{
		"solid": [
			0,196,2,80,0,100,2,80,0,100,2,80,0,1392,3,3,0,15,3,1,0,179,3,1,0,341,1,2,5,1,1,12,5,1,1,2,0,20,1,2,5,1,1,10,5,1,1,2,0,34,1,2,5,1,1,16,5,1,1,2,0,6,1,2,5,1,1,8,5,1,1,2,0,50,1,1,0,16,1,1,0,20,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,20,2,1,0,6,2,1,0,6,1,1,0,10,1,1,0,9,1,1,0,6,1,1,0,12,1,1,0,50,1,1,0,16,5,1,0,6,3,4,0,10,1,1,0,4,1,1,0,3,1,1,0,5,5,1,0,34,1,1,0,1,3,3,
			0,1,3,2,0,3,1,1,0,1,3,3,0,1,3,2,0,2,5,1,0,6,1,1,0,1,3,3,0,1,3,1,0,6,5,1,0,50,1,1,0,16,1,1,0,6,3,4,0,10,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,34,1,1,0,5,3,2,0,3,1,1,0,5,3,2,0,2,1,1,0,6,1,1,0,12,1,1,0,50,1,1,0,16,1,1,0,20,1,1,0,4,4,1,0,3,4,1,0,5,1,1,0,16,2,1,0,6,2,1,0,6,2,1,0,3,1,1,0,10,1,1,0,9,1,1,0,2,2,1,0,3,1,1,0,12,1,1,0,50,1,1,0,16,1,1,
			0,20,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,34,1,1,0,10,1,1,0,9,1,1,0,6,1,1,0,7,3,1,0,1,3,2,0,1,1,1,0,16,1,2,5,1,1,6,5,1,1,2,0,22,4,1,1,1,4,1,1,6,4,1,1,8,0,20,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,34,1,1,0,10,1,1,0,9,1,1,0,6,1,1,0,12,1,1,0,16,1,1,0,10,1,1,0,22,1,1,0,16,1,1,0,20,1,6,0,3,1,7,0,19,2,1,0,6,2,1,0,7,4,1,0,10,4,1,0,9,1,1,0,6,4,1,1,6,4,1,1,6,
			0,16,1,1,0,10,5,1,0,22,1,1,0,16,1,1,0,6,3,2,0,12,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,34,1,1,0,10,1,1,0,9,1,1,0,6,1,1,0,12,1,1,0,16,1,1,0,10,1,1,0,22,1,1,0,16,1,1,0,6,3,2,0,12,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,34,1,1,0,10,1,1,0,9,1,1,0,6,1,1,0,1,3,2,0,1,3,1,0,7,1,1,0,16,4,1,0,10,1,1,0,4,1,2,5,2,1,2,0,12,1,1,0,16,1,1,0,20,1,1,0,4,1,1,0,3,1,1,0,5,1,1,
			0,15,2,1,0,6,2,1,0,6,2,1,0,4,1,1,0,7,3,2,0,1,1,1,0,3,3,2,0,4,1,1,0,1,2,1,0,4,1,1,0,12,1,1,0,16,1,1,0,10,1,1,0,4,1,1,0,4,1,1,0,12,1,9,4,1,1,8,0,20,1,1,0,4,4,1,0,3,4,1,0,5,1,1,0,34,1,1,0,4,3,2,0,1,3,2,0,1,1,1,0,3,3,2,0,1,3,2,0,1,1,1,0,6,1,1,0,5,3,1,0,2,3,3,0,1,1,1,0,16,1,1,0,10,1,1,0,4,4,1,0,4,5,1,0,50,4,1,0,4,1,1,0,3,1,1,0,5,1,1,
			0,6,1,2,5,1,1,16,5,1,1,2,0,6,1,1,0,10,1,1,0,9,1,1,0,6,1,1,0,12,1,1,0,16,1,6,4,1,1,5,0,4,1,1,0,4,1,1,0,50,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,6,1,1,0,10,1,1,0,9,1,1,0,4,2,1,0,1,1,11,4,1,1,10,0,4,2,1,0,1,1,7,4,1,1,6,0,32,1,3,4,1,1,2,0,50,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,6,1,1,0,10,1,1,0,1,3,2,0,1,3,1,0,4,5,1,0,136,1,6,0,3,1,7,0,6,1,1,0,10,1,1,
			0,9,1,1,0,103,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,4,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,6,1,1,0,10,1,1,0,9,1,1,0,7,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,93,1,1,0,1,3,2,0,1,1,1,0,3,1,1,0,1,3,2,0,2,1,1,0,6,1,1,0,10,1,1,0,9,1,1,0,58,1,2,5,1,1,22,5,1,1,2,0,50,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,6,4,1,0,10,4,1,0,9,1,1,0,6,1,2,5,1,1,18,
			5,1,1,2,0,28,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,20,2,1,0,20,2,1,0,6,2,1,0,1,1,1,0,4,4,1,0,3,4,1,0,3,3,1,0,1,1,1,0,3,2,1,0,2,1,1,0,10,1,1,0,9,1,1,0,3,2,1,0,2,1,1,0,11,1,1,0,10,1,1,0,1,2,1,0,6,2,1,0,6,2,1,0,12,1,1,0,1,3,1,0,3,3,2,0,1,1,1,0,1,3,1,0,3,3,2,0,1,1,1,0,1,3,3,0,1,3,2,0,1,5,1,0,11,3,3,0,1,3,2,0,5,3,3,0,1,3,2,0,5,3,3,0,1,3,2,
			0,11,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,6,1,1,0,10,1,1,0,9,1,1,0,6,1,1,0,1,3,2,0,1,3,1,0,6,1,1,0,1,3,1,0,1,3,3,0,4,5,1,0,28,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,50,1,1,0,1,3,2,0,1,1,1,0,3,1,1,0,2,3,2,0,1,1,1,0,6,1,1,0,5,3,1,0,1,3,2,0,1,1,1,0,2,3,3,0,1,3,2,0,1,1,1,0,6,1,1,0,11,1,1,0,10,1,1,0,23,2,1,0,4,1,5,4,1,1,8,4,1,1,8,4,1,1,4,0,2,2,1,
			0,27,2,1,0,19,1,1,0,4,1,1,0,3,1,1,0,5,1,1,0,6,1,1,0,10,1,1,0,9,1,1,0,6,1,1,0,11,1,1,0,10,1,1,0,8,1,2,5,1,1,4,5,1,1,2,0,10,1,1,0,26,1,1,0,11,3,1,0,4,3,2,0,4,3,1,0,4,3,2,0,4,3,1,0,4,3,2,0,10,1,8,4,1,1,7,0,6,1,11,4,1,1,10,0,6,1,1,0,11,1,1,0,10,1,1,0,8,1,1,0,8,1,1,0,10,1,1,0,26,1,1,0,16,3,2,0,9,3,2,0,9,3,2,0,60,1,1,0,11,1,1,0,10,1,1,0,8,1,1,
			0,1,3,3,0,4,5,1,0,10,4,1,0,26,4,1,0,100,4,1,0,11,4,1,0,10,4,1,0,8,1,1,0,6,3,1,0,1,1,1,0,10,1,5,4,1,1,8,4,1,1,8,4,1,1,4,0,100,1,1,0,11,1,1,0,10,1,1,0,8,4,1,0,8,1,1,0,10,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,100,1,1,0,11,1,1,0,10,1,1,0,8,1,1,0,1,3,3,0,1,3,2,0,1,1,1,0,10,1,1,0,1,3,2,0,5,1,1,0,1,3,2,0,2,3,2,0,1,1,1,0,1,3,2,0,2,3,2,0,1,1,1,0,100,1,1,
			0,11,1,1,0,10,1,1,0,8,1,1,0,8,1,1,0,10,1,1,0,1,3,2,0,3,3,1,0,1,1,1,0,5,3,2,0,1,1,1,0,5,3,2,0,1,1,1,0,100,1,1,0,5,3,3,0,1,3,1,0,1,1,1,0,5,3,1,0,1,3,2,0,1,1,1,0,8,1,5,4,1,1,4,0,10,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,100,1,1,0,11,1,1,0,10,1,1,0,28,1,14,4,1,1,13,0,100,1,12,4,1,1,11,0,748,1,2,5,1,1,12,5,1,1,2,0,162,1,1,0,16,1,1,0,162,1,1,0,1,3,1,0,1,3,3,
			0,10,5,1,0,16,3,4,0,16,3,4,0,122,1,1,0,16,1,1,0,16,3,4,0,16,3,4,0,122,1,1,0,16,1,1,0,14,1,2,5,1,1,12,5,1,1,2,0,4,1,2,5,1,1,64,5,1,1,2,0,56,1,1,0,4,3,4,0,5,3,2,0,1,1,1,0,14,1,1,0,16,1,1,0,4,1,1,0,12,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,56,1,1,0,16,1,1,0,14,1,1,0,1,3,2,0,1,3,3,0,9,5,1,0,4,1,1,0,1,3,2,0,1,3,2,0,2,3,3,0,1,1,1,0,1,3,2,0,1,3,2,
			0,3,3,3,0,1,1,1,0,1,3,3,0,3,3,2,0,1,3,2,0,1,1,1,0,1,3,2,0,1,3,2,0,3,3,3,0,1,1,1,0,1,3,2,0,1,3,2,0,3,3,3,0,1,5,1,0,56,4,1,1,1,4,1,1,6,4,1,1,8,0,14,1,1,0,1,3,2,0,13,1,1,0,4,1,1,0,12,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,56,1,1,0,16,1,1,0,14,4,1,0,10,3,2,0,4,1,1,0,4,1,7,4,1,1,12,4,1,1,13,4,1,1,13,4,1,1,13,4,1,1,7,0,56,1,1,0,2,3,2,0,5,
			3,4,0,3,1,1,0,14,1,1,0,10,3,2,0,1,3,2,0,1,1,1,0,4,1,1,0,68,1,1,0,56,1,1,0,16,1,1,0,14,1,1,0,16,1,1,0,4,1,1,0,1,3,3,0,8,3,3,0,53,1,1,0,56,1,1,0,10,3,3,0,1,3,1,0,1,1,1,0,14,1,9,4,1,1,8,0,4,1,1,0,12,3,3,0,53,1,1,0,56,1,1,0,16,1,1,0,5,3,3,0,1,3,2,0,25,1,1,0,68,1,1,0,56,1,9,4,1,1,8,0,36,1,1,0,68,1,1,0,110,1,1,0,68,1,1,0,79,3,1,0,4,3,2,0,24,1,1,0,68,
			1,1,0,52,3,4,0,28,3,2,0,4,1,2,5,1,1,8,5,1,1,2,0,6,1,1,0,68,1,1,0,52,3,4,0,34,1,1,0,6,1,1,0,5,1,1,0,6,4,1,0,68,4,1,0,90,1,1,0,1,3,4,0,1,1,1,0,1,3,2,0,2,5,1,0,6,1,1,0,68,1,1,0,90,1,1,0,6,1,1,0,5,1,1,0,6,1,1,0,68,1,1,0,56,1,2,5,1,1,24,5,1,1,2,0,4,1,1,0,6,1,1,0,5,1,1,0,6,1,1,0,68,1,1,0,56,1,1,0,4,1,1,0,5,1,1,0,5,1,1,0,5,1,1,0,5,1,1,0,4,
			4,1,0,6,4,1,0,5,1,1,0,6,1,1,0,68,1,1,0,56,1,1,0,1,3,2,0,1,1,1,0,1,3,2,0,2,1,1,0,1,3,2,0,2,1,1,0,1,3,2,0,2,1,1,0,1,3,2,0,2,5,1,0,4,1,1,0,6,1,1,0,2,3,2,0,1,1,1,0,6,1,1,0,68,1,1,0,22,1,2,5,1,1,16,5,1,1,2,0,12,1,1,0,1,3,2,0,1,1,1,0,1,3,2,0,2,1,1,0,1,3,2,0,2,1,1,0,1,3,2,0,2,1,1,0,5,1,1,0,4,1,1,0,3,3,2,0,1,1,1,0,2,3,2,0,1,1,1,0,6,
			1,1,0,62,3,2,0,1,3,2,0,1,1,1,0,22,1,1,0,10,1,1,0,9,1,1,0,12,1,1,0,4,1,1,0,5,1,1,0,5,1,1,0,5,1,1,0,5,1,1,0,4,1,1,0,6,1,1,0,5,1,1,0,6,1,1,0,68,1,1,0,22,1,1,0,1,3,2,0,1,3,3,0,3,1,1,0,1,3,3,0,1,3,3,0,1,5,1,0,12,1,1,0,4,1,1,0,1,3,2,0,2,1,1,0,5,1,1,0,5,1,1,0,5,1,1,0,4,1,7,4,1,1,6,0,6,1,7,4,1,1,12,4,1,1,13,4,1,1,13,4,1,1,13,4,1,1,7,0,22,
			1,1,0,4,3,3,0,3,1,1,0,9,1,1,0,12,1,1,0,1,3,2,0,1,1,1,0,5,1,1,0,5,1,1,0,5,1,1,0,2,3,2,0,1,1,1,0,24,1,1,0,12,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,22,1,1,0,10,1,1,0,9,1,1,0,12,1,1,0,1,3,2,0,1,1,1,0,5,1,1,0,2,3,2,0,1,1,1,0,2,3,2,0,1,1,1,0,2,3,2,0,1,1,1,0,24,1,1,0,4,3,2,0,3,3,2,0,1,1,1,0,1,3,2,0,1,3,2,0,3,3,3,0,1,1,1,0,1,3,2,0,1,
			3,2,0,3,3,3,0,1,1,1,0,1,3,3,0,3,3,2,0,1,3,2,0,1,1,1,0,1,3,2,0,1,3,2,0,3,3,3,0,1,1,1,0,22,1,1,0,10,1,1,0,9,1,1,0,12,1,1,0,4,1,1,0,5,1,1,0,5,1,1,0,5,1,1,0,5,1,1,0,24,1,1,0,12,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,22,1,1,0,10,1,1,0,9,1,1,0,12,1,1,0,4,1,1,0,5,1,1,0,5,1,1,0,5,1,1,0,5,1,1,0,24,1,35,4,1,1,34,0,22,4,1,0,10,4,1,0,9,1,1,0,12,
			1,1,0,4,1,1,0,5,1,1,0,5,1,1,0,5,1,1,0,5,1,1,0,4,1,2,5,1,1,8,5,1,1,2,0,98,1,1,0,10,1,1,0,9,1,1,0,12,1,3,4,1,1,4,4,1,1,5,4,1,1,5,4,1,1,5,4,1,1,3,0,4,1,1,0,6,1,1,0,5,1,1,0,98,1,1,0,10,1,1,0,9,1,1,0,12,1,1,0,28,1,1,0,4,1,1,0,1,3,1,0,4,1,1,0,1,3,2,0,2,5,1,0,6,3,4,0,88,1,1,0,10,1,1,0,2,3,3,0,4,1,1,0,12,1,1,0,28,1,1,0,4,1,1,0,6,1,1,0,5,
			1,1,0,6,3,4,0,88,1,1,0,2,3,3,0,1,3,3,0,1,1,1,0,2,3,3,0,1,3,2,0,1,1,1,0,12,4,1,0,28,4,1,0,4,1,1,0,1,3,3,0,2,1,1,0,1,3,1,0,3,1,1,0,98,1,1,0,10,1,1,0,9,1,1,0,12,1,3,4,1,1,4,4,1,1,5,4,1,1,5,4,1,1,5,4,1,1,3,0,4,4,1,0,6,4,1,0,5,1,1,0,98,1,11,4,1,1,10,0,12,1,1,0,4,1,1,0,5,1,1,0,5,1,1,0,5,1,1,0,5,1,1,0,4,1,1,0,6,1,1,0,5,1,1,0,132,1,1,0,4,
			1,1,0,5,1,1,0,5,1,1,0,5,1,1,0,5,1,1,0,4,1,1,0,1,3,1,0,1,3,2,0,1,1,1,0,3,3,1,0,1,1,1,0,132,1,1,0,4,1,1,0,5,1,1,0,5,1,1,0,5,1,1,0,5,1,1,0,4,1,1,0,6,1,1,0,5,1,1,0,132,1,1,0,1,3,2,0,1,1,1,0,1,3,2,0,2,1,1,0,1,3,2,0,2,1,1,0,1,3,2,0,2,1,1,0,1,3,2,0,2,1,1,0,4,1,7,4,1,1,6,0,132,1,1,0,1,3,2,0,1,1,1,0,1,3,2,0,2,1,1,0,5,1,1,0,1,3,2,0,2,
			1,1,0,1,3,2,0,2,1,1,0,150,1,1,0,4,1,1,0,5,1,1,0,1,3,2,0,2,1,1,0,5,1,1,0,5,1,1,0,150,1,1,0,1,3,2,0,1,1,1,0,2,3,2,0,1,1,1,0,1,3,2,0,2,1,1,0,2,3,2,0,1,1,1,0,2,3,2,0,1,1,1,0,150,1,1,0,4,1,1,0,5,1,1,0,5,1,1,0,2,3,2,0,1,1,1,0,2,3,2,0,1,1,1,0,150,1,1,0,1,3,2,0,1,1,1,0,2,3,2,0,1,1,1,0,1,3,2,0,2,1,1,0,5,1,1,0,5,1,1,0,150,1,1,0,1,3,2,0,1,
			1,1,0,2,3,2,0,1,1,1,0,1,3,2,0,2,1,1,0,2,3,2,0,1,1,1,0,2,3,2,0,1,1,1,0,150,1,1,0,4,1,1,0,5,1,1,0,5,1,1,0,5,1,1,0,5,1,1,0,150,1,15,4,1,1,14,0,502
		],
		"floor": [
			0,180,4,540,0,16,2,82,0,98,2,82,0,98,2,82,0,98,2,82,0,98,2,82,0,98,2,82,0,122,1,6,0,174,1,6,0,174,1,6,0,174,1,6,0,174,1,6,0,2,3,18,0,20,3,16,0,34,3,22,0,6,3,14,0,42,1,6,0,2,3,18,0,20,3,16,0,34,3,22,0,6,3,14,0,42,1,6,0,2,3,18,0,20,3,16,0,34,3,22,0,6,3,14,0,42,1,6,0,2,3,18,0,20,3,16,0,34,3,22,0,6,3,14,0,42,1,6,0,2,3,18,0,20,3,16,0,34,3,22,0,6,3,14,0,42,1,6,0,2,3,18,0,20,3,16,0,34,3,22,
			0,6,3,14,0,16,3,12,0,14,1,6,0,2,3,18,0,20,3,16,0,34,3,22,0,6,3,14,0,16,3,12,0,14,1,6,0,2,3,18,0,20,3,16,0,34,3,22,0,6,3,14,0,16,3,12,0,14,1,6,0,2,3,18,0,20,3,16,0,34,3,22,0,6,3,14,0,16,3,12,0,14,1,6,0,2,3,18,0,20,3,16,0,34,3,22,0,6,3,14,0,16,3,12,0,4,3,6,0,4,1,6,0,2,3,18,0,20,3,16,0,34,3,22,0,6,3,14,0,16,3,12,0,4,3,6,0,4,1,6,0,2,3,18,0,20,3,16,0,34,3,22,0,6,3,14,0,16,3,12,
			0,4,3,6,0,4,1,6,0,40,3,16,0,6,3,22,0,6,3,22,0,6,3,14,0,16,3,12,0,4,3,6,0,4,1,6,0,40,3,16,0,6,3,22,0,6,3,22,0,6,3,14,0,32,3,6,0,4,1,6,0,40,3,16,0,6,3,22,0,90,1,6,0,40,3,16,0,6,3,22,0,50,1,48,0,38,3,16,0,6,3,22,0,50,1,48,0,38,3,16,0,6,3,22,0,50,1,8,3,28,1,12,0,38,3,16,0,6,3,22,0,6,3,24,0,20,1,8,3,28,1,12,0,38,3,16,0,6,3,22,0,6,3,24,0,24,1,4,3,28,0,4,1,6,0,40,3,16,0,6,
			3,22,0,6,3,24,0,24,1,4,3,28,0,4,1,6,0,40,3,16,0,6,3,22,0,6,3,24,0,24,1,4,3,28,0,4,1,6,0,40,3,16,0,6,3,22,0,6,3,24,0,8,3,10,0,6,1,4,3,28,0,4,1,6,0,40,3,16,0,6,3,22,0,6,3,24,0,8,3,10,0,6,1,4,3,28,0,4,1,6,0,90,3,24,0,8,3,10,0,6,1,4,3,28,0,4,1,6,0,90,3,24,0,8,3,10,0,6,1,4,3,28,0,4,1,6,0,90,3,24,0,8,3,10,0,6,1,4,3,28,0,4,1,6,0,90,3,24,0,8,3,10,0,6,1,4,3,28,0,4,
			1,6,0,90,3,24,0,8,3,10,0,6,1,4,3,28,0,4,1,6,0,90,3,24,0,8,3,10,0,6,1,4,3,28,0,4,1,6,0,90,3,24,0,24,1,4,3,28,0,4,1,6,0,90,3,24,0,24,1,176,0,4,1,176,0,4,1,176,0,4,1,176,0,4,1,4,3,18,1,154,0,4,1,4,3,18,0,14,1,6,0,12,1,4,0,70,1,6,0,46,1,4,3,18,0,32,1,4,0,70,1,6,7,42,0,4,1,4,3,18,0,32,1,4,0,70,1,6,7,42,0,4,1,4,3,18,0,14,3,18,1,4,3,70,1,6,7,42,0,4,1,4,3,18,0,14,3,18,1,4,
			3,70,1,6,7,42,0,4,1,4,3,18,0,14,3,18,1,4,3,70,1,6,7,42,0,4,1,4,3,18,0,14,3,18,1,4,3,70,1,6,7,42,0,4,1,4,3,18,0,14,3,18,1,4,3,70,1,6,7,42,0,4,1,4,3,18,0,14,3,18,1,4,3,70,4,48,0,4,1,4,3,18,0,14,3,18,1,4,3,70,1,6,7,42,0,4,1,4,3,18,0,14,3,18,1,4,3,70,1,6,7,42,0,4,1,4,3,18,0,32,1,4,3,70,1,6,7,42,0,4,1,4,3,18,0,32,1,4,3,70,1,6,7,42,0,4,1,4,0,50,1,4,3,70,1,6,7,42,0,4,
			1,4,0,50,1,4,3,70,4,48,0,42,3,14,0,2,1,4,3,70,1,6,7,42,0,42,3,14,0,2,1,4,3,70,1,6,7,42,0,42,3,14,0,2,1,4,3,70,1,6,7,42,0,42,3,14,0,2,1,4,3,70,1,6,7,42,0,8,3,30,0,4,3,14,0,2,1,4,3,70,1,6,7,42,0,8,3,30,0,4,3,14,0,2,1,4,3,70,4,48,0,8,3,30,0,4,3,14,0,2,1,4,3,70,1,6,7,16,3,22,7,4,0,8,3,30,0,4,3,14,0,2,1,4,3,70,1,6,7,16,3,22,7,4,0,8,3,30,0,4,3,14,0,2,1,4,3,70,1,6,
			7,16,3,22,7,4,0,8,3,30,0,4,3,14,0,2,1,4,3,70,1,6,7,16,3,22,7,4,0,8,3,30,0,20,1,4,3,70,1,6,7,16,3,22,7,4,0,8,3,30,0,20,1,4,3,70,1,6,7,16,3,22,7,4,0,8,3,30,0,20,1,4,3,70,1,6,7,16,3,22,7,4,0,8,3,30,0,20,1,4,3,70,1,6,7,16,3,22,7,4,0,8,3,30,0,4,3,14,0,2,1,4,0,70,1,6,7,16,3,22,7,4,0,8,3,30,0,4,3,14,0,2,1,4,0,70,1,6,7,16,3,22,7,4,0,8,3,30,0,4,3,14,0,2,1,4,0,70,1,6,
			7,16,3,22,7,4,0,8,3,30,0,4,3,14,0,2,1,4,0,70,1,6,7,16,3,22,7,4,0,8,3,30,0,4,3,14,0,2,1,4,0,70,1,6,7,16,3,22,7,4,0,8,3,30,0,4,3,14,0,2,1,4,0,70,1,6,7,16,3,22,7,4,0,8,3,30,0,4,3,14,0,2,1,4,0,70,1,6,0,50,3,30,0,4,3,14,0,2,1,4,0,70,1,6,0,42,1,8,3,30,1,4,3,14,1,132,3,30,1,4,3,14,1,132,3,30,1,150,3,30,1,150,3,30,1,142,0,8,3,30,0,150,3,30,0,150,3,30,0,150,3,30,0,150,3,30,0,502
		],
		"trees": [[122,15],[129,15],[118,18],[125,18],[132,18],[160,18],[121,21],[128,21],[117,24],[124,24],[131,24],[159,24],[134,27],[162,27],[53,30],[60,30],[67,30],[74,30],[81,30],[137,30],[144,30],[151,30],[158,30],[165,30],[172,30],[56,33],[77,33],[84,33],[105,33],[133,33],[161,33],[168,33],[175,33],[3,36],[38,36],[66,36]]
	},
	{
		"solid": [
			0,181,2,80,0,85,2,80,0,85,2,80,0,1272,3,3,0,15,3,1,0,104,1,2,5,1,1,12,5,1,1,2,0,42,3,1,0,104,1,1,0,8,1,1,0,7,1,1,0,147,1,1,0,8,1,1,0,7,5,1,0,34,1,2,5,1,1,12,5,1,1,2,0,95,1,1,0,8,1,1,0,7,1,1,0,34,1,1,0,16,1,1,0,95,1,1,0,8,1,1,0,7,1,1,0,34,1,1,0,16,5,1,0,22,1,2,5,1,1,6,5,1,1,2,0,61,1,1,0,8,1,1,0,7,1,1,0,34,1,1,0,16,1,1,0,22,1,1,0,10,1,1,0,61,1,1,0,8,1,1,
			0,7,1,1,0,34,1,1,0,16,1,1,0,14,3,2,0,6,1,1,0,10,5,1,0,8,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,10,1,1,0,8,1,1,0,7,1,1,0,34,1,1,0,16,1,1,0,14,3,2,0,6,1,1,0,10,1,1,0,61,4,1,0,8,4,1,0,7,1,1,0,34,4,1,1,1,4,1,1,6,4,1,1,8,0,22,4,1,0,10,1,1,0,61,1,1,0,8,1,1,0,7,1,1,0,34,1,1,0,16,1,1,0,22,1,1,0,10,1,1,0,11,2,1,0,6,2,1,0,6,2,1,0,6,
			2,1,0,6,2,1,0,6,2,1,0,14,1,1,0,8,1,1,0,7,1,1,0,34,1,1,0,16,1,1,0,22,1,1,0,10,1,1,0,61,1,1,0,8,1,1,0,7,1,1,0,34,1,1,0,16,1,1,0,22,1,6,4,1,1,5,0,61,1,1,0,8,1,1,0,7,1,1,0,34,1,1,0,16,1,1,3,2,0,4,1,2,5,2,1,2,0,29,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,11,1,1,0,8,1,1,0,7,1,1,0,34,1,9,4,1,1,8,3,2,0,4,1,1,0,4,1,1,0,83,1,1,0,8,
			1,1,0,7,1,1,0,58,4,1,0,4,5,1,0,83,1,9,4,1,1,8,0,58,1,1,0,4,1,1,0,32,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,84,1,3,4,1,1,2,0,246,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,13,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,598,1,2,5,1,1,14,5,1,1,2,0,10,3,3,0,1,3,2,0,5,3,3,0,1,3,2,0,5,3,3,0,1,3,2,0,3,3,4,0,1,3,4,0,1,3,4,0,1,3,4,0,85,1,1,0,9,
			1,1,0,8,1,1,0,41,3,4,0,1,3,4,0,1,3,4,0,1,3,4,0,85,1,1,0,1,3,1,0,1,3,2,0,4,1,1,0,1,3,2,0,1,3,3,0,1,5,1,0,116,1,2,5,1,1,4,5,1,1,2,0,19,1,1,0,9,1,1,0,1,3,2,0,5,1,1,0,10,3,1,0,4,3,2,0,4,3,1,0,4,3,2,0,4,3,1,0,4,3,2,0,77,1,1,0,8,1,1,0,19,1,1,0,9,1,1,0,8,1,1,0,15,3,2,0,9,3,2,0,9,3,2,0,77,1,1,0,1,3,2,0,1,3,1,0,3,5,1,0,19,1,1,0,9,1,1,0,8,
			1,1,0,116,1,1,0,8,1,1,0,19,1,1,0,9,1,1,0,8,1,1,0,116,4,1,0,8,1,1,0,19,1,1,0,9,1,1,0,8,1,1,0,94,3,3,0,1,3,2,0,16,1,1,0,1,3,3,0,4,1,1,0,1,3,3,0,1,3,2,0,12,4,1,0,9,4,1,0,8,1,1,0,24,1,2,5,1,1,64,5,1,1,2,0,22,1,1,0,8,1,1,0,19,1,1,0,9,1,1,0,8,1,1,0,24,1,1,0,12,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,22,1,5,4,1,1,4,0,19,1,1,0,9,1,1,0,8,1,1,0,24,
			1,1,0,1,3,4,0,1,3,3,0,3,1,1,0,1,3,4,0,1,3,3,0,4,1,1,0,1,3,2,0,1,3,2,0,7,1,1,0,1,3,3,0,1,3,4,0,4,1,1,0,1,3,3,0,1,3,4,0,4,5,1,3,1,0,4,3,2,0,26,3,1,0,4,3,2,0,11,1,1,0,9,1,1,0,8,1,1,0,24,1,1,0,1,3,4,0,7,1,1,0,1,3,4,0,8,1,1,0,13,1,1,0,5,3,4,0,4,1,1,0,5,3,4,0,4,1,1,0,5,3,2,0,31,3,2,0,11,1,1,0,6,3,2,0,1,1,1,0,8,1,1,0,24,1,1,0,12,1,1,
			0,13,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,51,1,1,0,2,3,3,0,1,3,2,0,1,1,1,0,3,3,2,0,1,3,1,0,1,1,1,0,24,1,1,0,12,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,51,1,1,0,9,1,1,0,8,1,1,0,24,1,1,0,12,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,51,1,10,4,1,1,9,0,24,1,1,0,12,1,1,0,13,1,1,0,10,1,2,0,1,1,1,0,13,1,1,0,13,1,1,0,95,1,1,0,12,1,1,0,13,1,1,0,10,1,2,0,1,1,1,
			0,13,1,1,0,13,1,1,0,20,1,2,5,1,1,18,5,1,1,2,0,51,1,1,0,12,1,1,0,13,1,1,0,2,3,4,0,7,1,1,0,13,1,1,0,13,1,1,0,20,1,1,0,6,1,1,0,7,1,1,0,7,1,1,0,41,1,2,5,1,1,4,5,1,1,3,0,4,3,2,0,3,3,2,0,1,1,1,0,7,3,2,0,1,3,2,0,1,1,1,0,2,3,4,0,3,3,3,0,1,1,1,0,7,3,2,0,1,3,2,0,1,1,1,0,7,3,2,0,1,3,2,0,1,1,3,5,1,1,4,5,1,1,2,0,10,1,1,0,1,3,1,0,2,3,1,0,1,1,1,
			0,7,1,1,0,7,5,1,0,41,1,1,0,8,1,2,0,12,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,13,1,2,0,8,1,1,0,10,1,1,0,6,1,1,0,5,3,1,0,1,1,1,0,5,3,1,0,1,1,1,0,41,1,1,0,2,3,2,0,4,5,1,1,7,4,1,1,12,4,1,1,13,4,1,1,13,4,1,1,13,4,1,1,8,0,2,3,2,0,4,5,1,0,10,1,1,0,6,1,1,0,7,1,1,0,7,1,1,0,41,1,1,0,8,1,2,0,68,1,2,0,8,1,1,0,10,1,4,4,1,1,6,4,1,1,7,4,1,1,4,0,7,1,2,5,1,
			1,14,5,1,1,2,0,14,1,1,0,8,1,2,0,68,1,2,0,8,1,1,0,10,1,1,0,22,1,1,0,7,1,1,0,9,1,1,0,8,1,1,0,14,4,1,1,1,4,1,1,2,4,1,1,2,4,3,0,68,4,4,1,2,4,1,1,4,0,10,1,1,0,22,1,1,0,7,1,1,0,1,3,2,0,1,3,2,0,3,1,1,0,1,3,4,0,3,5,1,0,14,1,1,0,8,1,8,4,1,1,12,4,1,1,13,4,1,1,13,4,1,1,13,4,1,1,8,0,8,1,1,0,10,4,1,0,22,4,1,0,7,1,1,0,1,3,2,0,6,1,1,0,8,1,1,0,14,1,1,
			0,5,3,2,0,1,1,2,0,12,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,13,1,2,0,5,3,2,0,1,1,1,0,10,1,4,4,1,1,6,4,1,1,7,4,1,1,4,0,7,1,1,0,9,1,1,0,1,3,2,0,5,1,1,0,14,1,1,0,8,1,2,0,1,3,2,0,1,3,2,0,6,1,1,0,1,3,3,0,3,3,4,0,2,1,1,0,1,3,3,0,3,3,4,0,2,1,1,0,1,3,2,0,1,3,2,0,7,1,1,0,1,3,4,0,2,3,3,0,3,1,2,0,8,1,1,0,10,1,1,0,6,1,1,0,7,1,1,0,7,1,1,0,7,1,1,
			0,9,1,1,0,1,3,2,0,5,1,1,0,14,1,5,4,1,1,5,0,12,1,1,0,7,3,4,0,2,1,1,0,7,3,4,0,2,1,1,0,13,1,1,0,1,3,4,0,8,1,6,4,1,1,4,0,10,1,1,0,6,1,1,0,1,3,1,0,2,3,1,0,2,1,1,0,5,3,1,0,1,1,1,0,7,1,1,0,9,1,1,0,8,1,1,0,24,1,1,0,12,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,20,1,1,0,6,1,1,0,7,1,1,0,7,1,1,0,7,1,1,0,9,1,1,0,8,1,1,0,24,1,1,0,12,1,1,0,13,1,1,
			0,13,1,1,0,13,1,1,0,13,1,1,0,20,1,1,0,2,3,1,0,1,3,1,0,1,1,1,0,1,3,3,0,3,1,1,0,1,3,3,0,1,3,1,0,1,1,1,0,7,1,1,0,9,1,1,0,8,1,1,0,24,1,1,0,12,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,20,1,1,0,6,1,1,0,7,1,1,0,7,1,1,0,7,4,1,0,9,4,1,0,8,1,1,0,24,1,1,0,12,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,20,1,12,4,1,1,11,0,7,1,1,0,9,1,1,0,8,1,1,0,24,1,1,
			0,12,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,51,1,1,0,9,1,1,0,8,1,1,0,24,1,1,0,12,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,51,1,1,0,9,1,1,0,8,1,1,0,24,1,1,0,7,3,4,0,1,1,1,0,13,1,1,0,13,1,1,0,4,3,4,0,5,1,1,0,13,1,1,0,51,1,1,0,9,1,1,0,8,1,1,0,24,1,1,0,3,3,3,0,1,3,4,0,1,1,1,0,7,3,2,0,1,3,2,0,1,1,1,0,5,3,2,0,3,3,2,0,1,1,1,0,4,3,4,0,1,3,3,
			0,1,1,1,0,7,3,2,0,1,3,2,0,1,1,1,0,51,1,1,0,1,3,2,0,6,1,1,0,5,3,2,0,1,1,1,0,24,1,1,0,12,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,13,1,1,0,51,1,1,0,1,3,2,0,1,3,4,0,1,1,1,0,2,3,2,0,1,3,2,0,1,1,1,0,24,1,35,4,1,1,34,0,51,1,1,0,9,1,1,0,8,1,1,0,78,1,2,5,1,1,24,5,1,1,2,0,6,1,2,5,1,1,18,5,1,1,2,0,7,1,10,4,1,1,9,0,78,1,1,0,14,1,1,0,13,1,1,0,6,1,1,0,11,1,1,
			0,10,1,1,0,105,1,1,0,1,3,3,0,1,3,3,0,6,1,1,0,1,3,3,0,1,3,3,0,5,5,1,0,6,1,1,0,1,3,3,0,1,3,3,0,3,1,1,0,1,3,2,0,1,3,2,0,4,5,1,0,105,1,1,0,1,3,3,0,10,1,1,0,5,3,3,0,5,1,1,0,6,1,1,0,5,3,3,0,3,1,1,0,1,3,2,0,7,1,1,0,105,1,1,0,14,1,1,0,13,1,1,0,6,1,1,0,11,1,1,0,10,1,1,0,105,4,1,0,14,4,1,0,13,4,1,0,6,4,1,0,11,4,1,0,10,4,1,0,105,1,1,0,8,3,2,0,4,1,1,
			0,7,3,2,0,4,1,1,0,6,1,1,0,8,3,2,0,1,1,1,0,2,3,3,0,5,1,1,0,105,1,1,0,8,3,2,0,1,3,2,0,1,1,1,0,7,3,2,0,1,3,2,0,1,1,1,0,6,1,1,0,5,3,2,0,1,3,2,0,1,1,1,0,2,3,3,0,1,3,3,0,1,1,1,0,105,1,1,0,14,1,1,0,13,1,1,0,6,1,1,0,11,1,1,0,10,1,1,0,105,1,15,4,1,1,14,0,6,1,12,4,1,1,11,0,997,1,2,5,1,1,16,5,1,1,2,0,6,1,2,5,1,1,16,5,1,1,2,0,4,1,2,5,1,1,10,5,1,1,2,
			0,6,1,2,5,1,1,10,5,1,1,2,0,2,1,2,5,1,1,10,5,1,1,2,0,55,1,1,0,10,1,1,0,9,1,1,0,6,1,1,0,10,1,1,0,9,1,1,0,4,1,1,0,14,1,1,0,6,1,1,0,14,1,1,0,2,1,1,0,7,1,1,0,6,1,1,0,55,1,1,0,1,3,1,0,1,3,2,0,5,1,1,0,1,3,1,0,1,3,2,0,4,5,1,0,6,1,1,0,1,3,2,0,1,3,1,0,5,1,1,0,1,3,2,0,1,3,1,0,4,5,1,0,4,1,1,0,2,3,3,0,9,5,1,0,6,1,1,0,2,3,1,0,1,3,3,0,7,5,1,
			0,2,1,1,0,1,3,3,0,1,3,1,0,1,1,1,0,1,3,3,0,2,5,1,0,9,3,3,0,1,3,2,0,16,3,3,0,1,3,2,0,18,1,1,0,10,1,1,0,9,1,1,0,6,1,1,0,10,1,1,0,9,1,1,0,4,1,1,0,10,3,3,0,1,1,1,0,6,1,1,0,11,3,2,0,1,1,1,0,2,1,1,0,7,1,1,0,6,1,1,0,55,1,1,0,10,1,1,0,9,1,1,0,6,1,1,0,10,1,1,0,9,1,1,0,4,1,1,0,14,1,1,0,6,1,1,0,14,1,1,0,2,1,1,0,7,1,1,0,1,3,1,0,4,1,1,0,55,4,1,
			0,10,4,1,0,9,1,1,0,6,4,1,0,10,4,1,0,9,1,1,0,4,4,1,1,1,4,1,1,5,4,1,1,7,0,6,4,1,1,1,4,1,1,5,4,1,1,7,0,2,4,1,0,7,4,1,0,6,1,1,0,9,3,1,0,4,3,2,0,15,3,1,0,4,3,2,0,17,1,1,0,10,1,1,0,9,1,1,0,6,1,1,0,10,1,1,0,9,1,1,0,4,1,1,0,14,1,1,0,6,1,1,0,14,1,1,0,2,1,1,0,7,1,1,0,6,1,1,0,14,3,2,0,20,3,2,0,17,1,1,0,10,1,1,0,9,1,1,0,6,1,1,0,10,1,1,0,9,1,1,
			0,4,1,1,0,2,3,3,0,9,1,1,0,6,1,1,0,2,3,2,0,10,1,1,0,2,1,1,0,2,3,2,0,1,3,1,0,1,1,1,0,1,3,1,0,1,3,2,0,1,1,1,0,55,1,1,0,3,3,3,0,1,3,2,0,1,1,1,0,2,3,2,0,1,3,3,0,1,1,1,0,6,1,1,0,3,3,2,0,1,3,3,0,1,1,1,0,2,3,3,0,1,3,2,0,1,1,1,0,4,1,1,0,10,3,3,0,1,1,1,0,6,1,1,0,8,3,3,0,1,3,1,0,1,1,1,0,2,1,1,0,7,1,1,0,6,1,1,0,55,1,1,0,10,1,1,0,9,1,1,
			0,6,1,1,0,10,1,1,0,9,1,1,0,4,1,1,0,14,1,1,0,6,1,1,0,14,1,1,0,2,1,8,4,1,1,7,0,55,1,11,4,1,1,10,0,6,1,11,4,1,1,10,0,4,1,8,4,1,1,7,0,6,1,8,4,1,1,7,0,232
		],
		"floor": [
			0,165,4,495,0,16,2,82,0,83,2,82,0,83,2,82,0,83,2,82,0,83,2,82,0,83,2,82,0,95,1,5,0,59,1,6,0,95,1,5,0,59,1,6,0,73,3,18,0,4,1,5,0,59,1,6,0,73,3,18,0,4,1,5,0,59,1,6,0,73,3,18,0,4,1,5,0,25,3,18,0,16,1,6,0,18,1,49,0,6,3,18,0,4,1,5,0,25,3,18,0,16,1,6,0,18,1,49,0,6,3,18,0,4,1,5,0,25,3,18,0,16,1,6,3,12,0,6,1,49,0,6,3,18,0,4,1,5,0,25,3,18,0,16,1,6,3,12,0,6,1,49,0,6,3,18,0,4,1,5,
			0,25,3,18,0,16,1,6,3,12,0,61,3,18,0,4,1,5,0,25,3,18,0,16,1,6,3,12,0,61,3,18,0,4,1,5,0,25,3,18,0,16,1,6,3,12,0,61,3,18,0,4,1,5,0,25,3,18,0,16,1,6,3,12,0,61,3,18,0,4,1,5,0,25,3,18,0,16,1,6,3,12,0,61,3,18,0,4,1,5,0,25,3,18,0,16,1,6,3,12,0,61,3,18,0,4,1,5,0,25,3,18,0,6,3,6,0,4,1,6,0,73,3,18,0,4,1,5,0,25,3,18,0,6,3,6,0,4,1,6,0,73,3,18,0,4,1,5,0,49,3,6,0,4,1,6,0,73,3,18,
			0,4,1,5,0,49,3,6,0,4,1,6,0,95,1,5,0,49,3,6,0,4,1,6,0,95,1,5,0,59,1,6,0,95,1,5,0,59,1,6,0,95,1,5,0,59,1,6,0,95,1,5,0,59,1,6,0,95,1,5,0,59,1,6,0,73,3,20,0,2,1,5,0,59,1,6,0,73,3,20,0,2,1,5,0,59,1,6,0,73,3,20,0,2,1,5,0,33,1,73,0,3,3,10,0,19,3,20,0,2,1,5,0,33,1,73,0,3,3,10,0,19,3,20,0,2,1,5,0,1,7,32,1,73,0,3,3,10,0,19,3,20,0,2,1,5,0,1,7,32,1,73,0,3,3,10,0,19,3,20,
			0,2,1,5,0,1,7,32,1,73,0,3,3,10,0,19,3,20,0,2,1,5,0,1,7,100,1,5,0,3,3,10,0,19,3,20,0,2,1,5,0,1,7,16,3,70,7,14,1,5,0,3,3,10,0,19,3,20,0,2,1,5,0,1,7,16,3,70,7,14,1,5,0,3,3,10,0,19,3,20,0,2,1,5,0,1,7,16,3,70,7,14,1,5,0,32,3,20,0,2,1,5,0,1,7,16,3,70,7,14,1,5,0,32,3,20,0,2,1,5,0,1,7,16,3,70,7,14,1,5,0,32,3,20,0,2,1,5,0,1,7,16,3,70,7,14,1,5,0,32,3,20,0,2,1,5,0,1,7,16,
			3,70,7,14,1,5,0,32,3,20,0,2,1,5,0,1,7,16,3,70,7,14,1,5,0,54,1,5,0,1,7,16,3,70,7,14,1,5,0,1,3,24,0,29,1,5,0,1,7,16,3,70,7,14,1,5,0,1,3,24,0,29,1,5,0,1,7,6,3,90,7,4,1,5,0,1,3,24,0,29,1,5,0,1,7,6,3,90,7,4,1,5,0,1,3,24,0,29,1,5,0,1,7,6,3,90,7,4,1,5,0,1,3,24,0,29,1,5,0,1,7,6,3,90,7,4,1,5,0,1,3,24,0,7,3,20,0,2,1,5,0,1,7,6,3,90,7,4,1,5,0,1,3,24,0,7,3,20,0,2,
			1,5,0,1,7,6,3,90,7,4,1,5,0,1,3,24,0,7,3,20,0,2,1,5,0,1,7,6,3,90,7,4,1,5,0,1,3,24,0,7,3,20,0,2,1,5,0,1,7,6,3,90,7,4,1,5,0,1,3,24,0,7,3,20,0,2,1,5,0,1,7,6,3,90,7,4,1,5,0,1,3,24,0,7,3,20,0,2,1,5,0,1,7,6,3,90,7,4,1,5,0,1,3,24,0,7,3,20,0,2,1,5,0,1,7,16,3,70,7,14,1,5,0,1,3,24,0,7,3,20,0,2,1,5,0,1,7,16,3,70,7,14,1,5,0,1,3,24,0,7,3,20,0,2,1,5,0,1,7,16,
			3,70,7,14,1,5,0,1,3,24,0,7,3,20,0,2,1,5,0,1,7,16,3,70,7,14,1,5,0,1,3,24,0,7,3,20,0,2,1,5,0,1,7,16,3,70,7,14,1,5,0,32,3,20,0,2,1,5,0,1,7,16,3,70,7,14,1,5,0,32,3,20,0,2,1,5,0,1,7,16,3,70,7,14,1,5,0,32,3,20,0,2,1,5,0,1,7,16,3,70,7,14,1,5,0,32,3,20,0,2,1,5,0,1,7,16,3,70,7,14,1,5,0,32,3,20,0,2,1,5,0,1,7,16,3,70,7,14,1,5,0,32,3,20,0,2,1,5,0,1,1,70,3,30,1,5,0,1,3,24,
			0,7,3,20,0,2,1,5,0,1,1,70,3,30,1,5,0,1,3,24,0,29,1,5,0,1,1,70,3,30,1,5,0,1,3,24,0,29,1,5,0,1,1,70,3,30,1,5,0,1,3,24,0,29,1,5,0,1,1,70,3,30,1,5,0,1,3,24,0,29,1,5,0,1,7,70,3,30,1,5,0,1,3,24,0,29,1,5,0,1,7,70,3,30,1,5,0,1,3,24,0,29,1,5,0,1,7,70,3,30,1,5,0,1,3,24,0,29,1,5,0,1,7,70,3,30,1,5,0,1,3,24,0,29,1,5,0,1,7,70,3,30,1,5,0,1,3,24,0,1,1,825,0,28,1,5,0,101,1,5,
			0,32,3,22,1,5,0,1,3,22,0,4,3,16,0,6,3,16,0,2,3,16,0,18,1,5,0,32,3,22,1,5,0,1,3,22,0,4,3,16,0,6,3,16,0,2,3,16,0,18,1,5,0,32,3,22,1,5,0,1,3,22,0,4,3,16,0,6,3,16,0,2,3,16,0,18,1,5,0,32,3,22,1,5,0,1,3,22,0,4,3,16,0,6,3,16,0,2,3,16,0,18,1,5,0,32,3,22,1,5,0,1,3,22,0,4,3,16,0,6,3,16,0,2,3,16,0,18,1,5,0,32,3,22,1,5,0,1,3,22,0,4,3,16,0,6,3,16,0,2,3,16,0,18,1,5,0,32,3,22,
			1,5,0,1,3,22,0,4,3,16,0,6,3,16,0,2,3,16,0,18,1,5,0,32,3,22,1,5,0,1,3,22,0,4,3,16,0,6,3,16,0,2,3,16,0,18,1,5,0,32,3,22,1,5,0,1,3,22,0,4,3,16,0,6,3,16,0,2,3,16,0,18,1,5,0,32,3,22,1,5,0,1,3,22,0,4,3,16,0,6,3,16,0,2,3,16,0,18,1,5,0,32,3,22,1,5,0,1,3,22,0,4,3,16,0,6,3,16,0,36,1,5,0,54,1,5,0,101,1,5,0,26
		],
		"trees": [[118,18],[125,18],[132,18],[139,18],[146,18],[153,18],[160,18],[121,21],[128,21],[135,21],[142,21],[149,21],[156,21],[117,24],[124,24],[131,24],[138,24],[145,24],[152,24],[159,24],[120,27],[127,27],[134,27],[141,27],[148,27],[155,27],[162,27],[4,30],[11,30],[18,30],[25,30],[39,30],[46,30],[53,30],[60,30],[67,30]]
	},
	{
		"solid": [
			0,191,2,80,0,95,2,80,0,95,2,80,0,1352,3,3,0,15,3,1,0,116,1,2,5,1,1,12,5,1,1,2,0,40,3,1,0,29,1,2,5,1,1,14,5,1,1,2,0,8,1,2,5,1,1,22,5,1,1,2,0,31,1,1,0,16,1,1,0,70,1,1,0,9,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,31,1,1,0,16,5,1,0,70,1,1,0,9,1,1,0,8,5,1,0,8,1,1,0,1,3,2,0,2,3,2,0,1,1,1,0,1,3,3,0,1,3,2,0,1,1,1,0,1,3,3,0,1,3,2,0,1,5,1,0,2,1,2,
			5,1,1,4,5,1,1,2,0,19,1,1,0,16,1,1,0,70,1,1,0,9,1,1,0,8,1,1,0,8,1,1,0,1,3,2,0,2,3,2,0,1,1,1,0,5,3,2,0,1,1,1,0,5,3,2,0,1,1,1,0,2,1,1,0,8,1,1,0,7,2,1,0,11,1,1,0,16,1,1,0,40,1,2,5,1,1,6,5,1,1,2,0,18,1,1,0,9,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,2,1,1,0,1,3,2,0,5,5,1,0,19,1,1,0,16,1,1,0,40,1,1,0,10,1,1,0,18,1,1,0,9,1,1,0,8,1,1,
			0,8,1,5,4,1,1,8,4,1,1,8,4,1,1,4,0,2,1,1,0,4,3,3,0,1,1,1,0,19,4,1,1,1,4,1,1,6,4,1,1,8,0,40,1,1,0,10,5,1,0,18,1,1,0,9,1,1,0,8,1,1,0,8,1,1,0,26,1,1,0,2,4,1,0,8,1,1,0,3,2,1,0,15,1,1,0,16,1,1,0,40,1,1,0,10,1,1,0,6,3,4,0,8,4,1,0,9,4,1,0,8,1,1,0,8,1,1,0,26,1,1,0,2,1,1,0,1,3,3,0,1,3,1,0,2,1,1,0,19,1,1,0,16,1,1,0,40,4,1,0,10,1,1,0,6,3,4,0,8,
			1,1,0,9,1,1,0,8,1,1,0,8,4,1,0,26,4,1,0,2,1,1,0,8,1,1,0,19,1,1,0,16,1,1,0,40,1,1,0,10,1,1,0,6,3,4,0,8,1,1,0,9,1,1,0,8,1,1,0,8,1,5,4,1,1,8,4,1,1,8,4,1,1,4,0,2,1,5,4,1,1,4,0,6,2,1,0,12,1,1,0,16,1,1,0,14,1,2,5,2,1,2,0,20,1,1,0,10,1,1,0,18,1,1,0,9,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,31,1,9,4,1,1,8,0,14,1,1,0,4,1,1,0,20,1,6,4,1,
			1,5,0,18,1,1,0,9,1,1,0,8,1,1,0,8,1,1,0,1,3,2,0,5,1,1,0,1,3,2,0,2,3,2,0,1,1,1,0,1,3,3,0,4,1,1,0,54,3,4,0,5,4,1,0,4,5,1,0,50,1,1,0,9,1,1,0,8,1,1,0,1,2,1,0,6,1,1,0,1,3,2,0,2,3,2,0,1,1,1,0,1,3,2,0,5,1,1,0,8,1,1,0,14,2,1,0,39,3,4,0,5,1,1,0,4,1,1,0,50,1,10,4,1,1,9,0,8,1,1,0,5,3,2,0,1,1,1,0,8,1,1,0,5,3,2,0,1,1,1,0,63,1,3,4,1,1,2,0,78,
			1,1,0,8,1,1,0,8,1,1,0,8,1,1,0,147,1,14,4,1,1,13,0,169,1,2,5,1,1,20,5,1,1,2,0,149,1,1,0,12,1,1,0,11,1,1,0,7,2,1,0,6,2,1,0,6,1,2,5,1,1,6,5,1,1,2,0,2,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,13,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,2,1,2,5,1,1,8,5,1,1,2,0,4,2,1,0,1,1,1,0,1,3,3,0,1,3,1,0,6,1,1,0,1,3,2,0,1,3,3,0,4,
			5,1,0,21,1,1,0,10,1,1,0,96,1,1,0,12,1,1,0,6,1,1,0,12,1,1,0,11,1,1,0,21,1,1,0,1,3,2,0,1,3,3,0,3,5,1,0,96,1,1,0,1,3,2,0,1,3,3,0,5,5,1,0,6,4,1,0,12,4,1,0,11,4,1,0,17,2,1,0,3,1,1,0,1,3,2,0,7,1,1,0,47,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,6,2,1,0,13,1,1,0,12,1,1,0,6,1,1,0,5,3,3,0,1,3,2,0,1,1,1,0,5,3,1,0,1,3,3,0,1,1,1,0,21,4,1,0,10,1,1,0,4,
			1,2,5,1,1,10,5,1,1,2,0,2,3,4,0,6,3,4,0,1,3,4,0,55,1,1,0,12,1,1,0,6,1,1,0,12,1,1,0,11,1,1,0,21,1,1,0,4,3,1,0,2,3,2,0,1,1,1,0,4,1,1,0,7,1,1,0,6,1,1,0,2,3,4,0,6,3,4,0,1,3,4,0,55,1,1,0,12,1,1,0,6,1,13,4,1,1,12,0,13,2,1,0,7,1,1,0,10,1,1,0,1,2,1,0,2,1,1,0,1,3,3,0,1,3,1,0,1,1,1,0,1,3,1,0,1,3,2,0,1,5,1,0,76,1,1,0,7,3,2,0,1,3,1,0,1,1,1,0,53,
			1,6,4,1,1,5,0,4,1,1,0,7,1,1,0,6,1,1,0,76,1,1,0,12,1,1,0,69,1,1,0,7,1,1,0,6,1,1,0,76,4,1,1,6,4,1,1,6,0,4,1,2,5,1,1,18,5,1,1,2,0,20,2,1,0,6,2,1,0,6,2,1,0,6,4,1,0,7,4,1,0,4,3,1,0,1,1,1,0,5,2,1,0,6,2,1,0,63,1,1,0,12,1,1,0,4,1,1,0,11,1,1,0,10,1,1,0,7,3,10,0,24,1,1,0,7,1,1,0,6,1,1,0,20,1,2,5,1,1,8,5,1,1,2,0,42,1,1,0,1,3,1,0,1,3,2,0,7,1,1,
			0,4,1,1,0,1,3,3,0,1,3,4,0,2,1,1,0,1,3,3,0,1,3,4,0,1,5,1,0,7,3,10,0,24,1,1,0,2,3,2,0,1,3,1,0,1,1,1,0,2,3,3,0,1,1,1,0,20,1,1,0,6,1,1,0,5,1,1,0,25,3,3,0,1,3,2,0,11,1,1,0,12,1,1,0,4,1,1,0,5,3,4,0,2,1,1,0,5,3,4,0,1,1,1,0,7,3,20,0,3,2,1,0,10,1,1,0,7,1,1,0,6,1,1,0,20,1,1,0,1,3,3,0,2,1,1,0,1,3,2,0,2,5,1,0,42,1,1,0,12,1,1,0,4,1,1,0,11,1,1,
			0,10,1,1,0,7,3,20,0,14,1,8,4,1,1,7,0,20,1,1,0,6,1,1,0,5,1,1,0,42,1,1,0,3,3,3,0,3,3,2,0,1,1,1,0,4,1,1,0,11,1,1,0,10,1,1,0,7,3,30,0,40,1,1,0,1,3,1,0,4,1,1,0,1,3,1,0,3,1,1,0,4,1,2,0,12,1,2,0,5,3,1,0,4,3,2,0,10,1,1,0,12,1,1,0,4,1,1,0,11,1,1,0,10,1,1,0,7,3,30,0,40,4,1,0,6,4,1,0,3,3,1,0,1,1,1,0,4,1,2,0,12,1,2,0,10,3,2,0,10,1,7,4,1,1,6,0,4,4,1,
			0,11,4,1,0,10,4,1,0,17,3,30,0,30,1,1,0,6,1,1,0,5,1,1,0,60,1,1,0,11,1,1,0,10,1,1,0,17,3,30,0,30,1,1,0,1,3,1,0,1,3,2,0,1,1,1,0,1,3,3,0,1,1,1,0,60,1,1,0,11,1,1,0,10,1,1,0,13,3,3,0,1,3,2,0,8,3,30,0,20,1,1,0,6,1,1,0,5,1,1,0,2,3,6,0,2,3,3,0,1,3,2,0,4,3,6,0,24,3,6,0,4,1,1,0,8,3,2,0,1,1,1,0,4,3,2,0,4,1,1,0,27,3,30,0,20,1,7,4,1,1,6,0,2,3,6,0,12,3,6,
			0,24,3,6,0,4,1,1,0,5,3,2,0,1,3,2,0,1,1,1,0,4,3,2,0,1,3,2,0,1,1,1,0,37,3,26,0,30,3,6,0,12,3,6,0,24,3,6,0,4,1,1,0,11,1,1,0,10,1,1,0,13,3,1,0,4,3,2,0,17,3,26,0,30,3,6,0,2,3,1,0,4,3,2,0,3,3,6,0,24,3,6,0,4,1,12,4,1,1,11,0,18,3,2,0,27,3,16,0,6,3,8,0,29,3,2,0,114,3,16,0,6,3,8,0,155,3,6,0,6,3,18,0,64,1,2,5,1,1,22,5,1,1,2,0,5,3,3,0,1,3,2,0,5,3,3,0,1,3,2,
			0,5,3,3,0,1,3,2,0,5,3,3,0,1,3,2,0,9,3,6,0,6,3,18,0,43,3,3,0,1,3,2,0,15,1,1,0,13,1,1,0,12,1,1,0,65,3,28,0,54,1,1,0,1,3,2,0,1,3,4,0,5,1,1,0,1,3,4,0,1,3,2,0,4,5,1,0,65,3,28,0,54,1,1,0,1,3,2,0,10,1,1,0,6,3,2,0,4,1,1,0,5,3,1,0,4,3,2,0,4,3,1,0,4,3,2,0,4,3,1,0,4,3,2,0,4,3,1,0,4,3,2,0,28,3,30,0,23,3,1,0,4,3,2,0,14,1,1,0,13,1,1,0,12,1,1,0,10,3,2,
			0,9,3,2,0,9,3,2,0,9,3,2,0,28,3,30,0,28,3,2,0,14,1,1,0,13,1,1,0,12,1,1,0,83,3,30,0,34,4,1,0,13,4,1,0,12,4,1,0,83,3,30,0,34,1,1,0,13,1,1,0,12,1,1,0,11,1,2,5,1,1,28,5,1,1,2,3,3,0,1,3,2,0,16,3,3,0,1,3,2,0,5,3,3,0,1,3,2,0,9,3,28,0,26,1,1,0,10,3,2,0,1,1,1,0,9,3,2,0,1,1,1,0,11,1,1,0,5,1,1,0,5,1,1,0,6,1,1,0,6,1,1,0,6,1,1,0,48,3,28,0,26,1,1,0,7,3,2,0,1,
			3,2,0,1,1,1,0,6,3,2,0,1,3,2,0,1,1,1,0,11,1,1,0,1,3,1,0,3,1,1,0,1,3,1,0,3,1,1,0,1,3,2,0,3,1,1,0,1,3,2,0,1,3,1,0,1,1,1,0,1,3,2,0,1,3,1,0,1,5,1,0,58,3,18,0,5,3,7,0,14,1,1,0,13,1,1,0,12,1,1,0,11,1,1,0,5,1,1,0,5,1,1,0,1,3,2,0,3,1,1,0,6,1,1,0,6,1,1,3,1,0,4,3,2,0,15,3,1,0,4,3,2,0,4,3,1,0,4,3,2,0,18,3,18,0,5,3,7,0,14,1,14,4,1,1,13,0,11,1,1,
			0,1,3,2,0,2,1,1,0,1,3,2,0,2,1,1,0,6,1,1,0,3,3,2,0,1,1,1,0,3,3,2,0,1,1,1,0,5,3,2,0,20,3,2,0,9,3,2,0,28,3,8,0,5,3,17,0,43,1,1,0,5,1,1,0,5,1,1,0,1,3,3,0,2,1,1,0,3,3,2,0,1,1,1,0,3,3,2,0,1,1,1,0,68,3,8,0,5,3,17,0,43,1,1,0,2,3,2,0,1,1,1,0,2,3,2,0,1,1,1,0,6,1,1,0,6,1,1,0,6,1,1,0,81,3,27,0,33,1,1,0,2,3,2,0,1,1,1,0,2,3,2,0,1,1,1,0,6,1,1,
			0,2,3,3,0,1,1,1,0,2,3,3,0,1,1,1,0,62,3,3,0,1,3,2,0,13,3,27,0,33,1,1,0,5,1,1,0,5,1,1,0,6,1,1,0,6,1,1,0,6,1,1,0,2,1,2,5,1,1,4,5,1,1,2,0,76,3,30,0,23,1,1,0,5,1,1,0,5,1,1,0,1,3,2,0,1,3,1,0,1,1,1,0,6,1,1,0,6,1,1,0,2,1,1,0,8,1,1,0,76,3,30,0,23,1,1,0,5,1,1,0,5,1,1,0,6,1,1,0,6,1,1,0,6,1,1,0,2,1,1,0,1,3,1,0,1,3,2,0,3,5,1,0,16,1,2,5,1,1,24,
			5,1,1,2,0,4,3,1,0,4,3,2,0,29,3,30,0,13,1,3,4,1,1,5,4,1,1,6,4,1,1,6,4,1,1,6,4,1,1,3,0,2,1,1,0,8,1,1,0,16,1,1,0,8,1,1,0,9,1,1,0,9,1,1,0,9,3,2,0,29,3,30,0,13,1,1,0,32,1,1,0,2,1,1,0,8,1,1,0,16,1,1,0,1,1,6,0,1,1,1,0,1,3,4,0,1,3,2,0,1,1,1,0,1,3,3,0,5,5,1,0,50,3,25,0,8,1,1,0,32,1,1,0,2,1,1,0,8,1,1,0,16,1,1,0,1,1,6,0,1,1,1,0,1,3,4,0,1,3,2,
			0,1,1,1,0,1,3,3,0,5,1,1,0,50,3,25,0,8,4,1,0,32,4,1,0,2,1,1,0,8,1,1,0,16,1,1,0,1,1,6,0,1,1,1,0,9,1,1,0,9,1,1,0,60,3,15,0,8,1,3,4,1,1,5,4,1,1,6,4,1,1,6,4,1,1,6,4,1,1,3,0,2,1,1,0,8,1,1,0,16,1,1,0,8,1,1,0,9,1,1,0,9,1,1,0,60,3,15,0,8,1,1,0,5,1,1,0,5,1,1,0,6,1,1,0,6,1,1,0,6,1,1,0,2,1,1,0,8,1,1,0,16,1,1,0,3,3,4,0,1,1,1,0,9,1,1,0,1,3,4,
			0,4,1,1,0,70,3,5,0,8,1,1,0,5,1,1,0,1,3,1,0,3,1,1,0,1,3,2,0,1,3,1,0,1,1,1,0,6,1,1,0,1,3,1,0,4,1,1,0,2,1,1,0,1,3,3,0,1,3,2,0,1,1,1,0,16,1,1,0,3,3,4,0,1,1,1,0,9,1,1,0,1,3,4,0,4,1,1,0,70,3,5,0,8,1,1,0,5,1,1,0,5,1,1,0,6,1,1,0,6,1,1,0,6,1,1,0,2,1,1,0,8,1,1,0,16,1,1,0,8,1,1,0,5,3,3,0,1,1,1,0,6,3,2,0,1,1,1,0,83,1,1,0,1,3,2,0,2,1,1,
			0,1,3,2,0,2,1,1,0,6,1,1,0,1,3,3,0,2,1,1,0,1,3,2,0,3,1,1,0,2,4,1,1,4,4,1,1,4,0,16,1,1,0,8,1,1,0,5,3,3,0,1,1,1,0,6,3,2,0,1,1,1,0,83,1,1,0,1,3,2,0,2,1,1,0,5,1,1,0,6,1,1,0,6,1,1,0,6,1,1,0,2,1,1,0,8,1,1,0,16,1,1,0,8,1,1,0,9,1,1,0,9,1,1,0,26,1,2,5,1,1,26,5,1,1,2,0,25,1,1,0,5,1,1,0,5,1,1,0,6,1,1,0,1,3,2,0,3,1,1,0,6,1,1,0,2,1,1,0,1,
			3,2,0,2,3,1,0,2,1,1,0,16,1,5,4,1,1,8,4,1,1,9,4,1,1,5,0,26,1,1,0,9,1,1,0,9,1,1,0,10,1,1,0,25,1,1,0,5,1,1,0,1,3,3,0,1,1,1,0,2,3,3,0,1,1,1,0,1,3,2,0,3,1,1,0,3,3,2,0,1,1,1,0,2,1,1,0,8,1,1,0,16,1,1,0,28,1,1,0,26,1,1,0,1,3,2,0,1,3,3,0,2,1,1,0,1,3,1,0,7,1,1,0,1,3,3,0,1,3,2,0,3,5,1,0,25,1,1,0,2,3,2,0,1,1,1,0,5,1,1,0,6,1,1,0,6,1,1,0,3,
			3,2,0,1,1,1,0,2,1,1,0,8,1,1,0,16,1,1,0,28,1,1,0,26,1,1,0,9,1,1,0,9,1,1,0,10,1,1,0,25,1,1,0,5,1,1,0,2,3,2,0,1,1,1,0,2,3,2,0,2,1,1,0,6,1,1,0,6,1,1,0,2,1,1,0,8,1,1,0,16,4,1,0,28,4,1,0,26,1,1,0,7,3,1,0,1,1,1,0,2,3,2,0,1,3,3,0,1,1,1,0,8,3,1,0,1,1,1,0,25,1,1,0,3,3,1,0,1,1,1,0,2,3,2,0,1,1,1,0,2,3,2,0,2,1,1,0,1,3,1,0,1,3,2,0,1,1,1,0,2,
			3,3,0,1,1,1,0,2,1,1,0,8,1,1,0,16,1,5,4,1,1,8,4,1,1,9,4,1,1,5,0,26,1,1,0,9,1,1,0,9,1,1,0,10,1,1,0,25,1,1,0,5,1,1,0,5,1,1,0,6,1,1,0,6,1,1,0,6,1,1,0,2,1,1,0,8,1,1,0,16,1,1,0,8,1,1,0,9,1,1,0,9,1,1,0,26,1,5,4,1,1,9,4,1,1,10,4,1,1,5,0,25,1,17,4,1,1,16,0,2,1,1,0,1,3,3,0,1,3,2,0,1,1,1,0,16,1,1,0,1,3,3,0,4,1,1,0,1,3,3,0,5,1,1,0,1,3,2,0,6,
			1,1,0,26,1,1,0,30,1,1,0,61,1,1,0,8,1,1,0,16,1,1,0,1,3,3,0,4,1,1,0,1,3,3,0,5,1,1,0,1,3,2,0,6,1,1,0,26,1,1,0,30,1,1,0,61,1,5,4,1,1,4,0,16,1,1,0,8,1,1,0,9,1,1,0,9,1,1,0,26,4,1,0,30,4,1,0,87,1,1,0,8,1,1,0,1,1,6,0,2,1,1,0,2,1,6,0,1,1,1,0,26,1,5,4,1,1,9,4,1,1,10,4,1,1,5,0,87,1,1,0,5,3,2,0,1,1,1,0,1,1,6,0,2,1,1,0,2,1,6,0,1,1,1,0,26,1,1,0,9,
			1,1,0,9,1,1,0,10,1,1,0,87,1,1,0,5,3,2,0,1,1,1,0,1,1,6,0,2,1,1,0,2,1,6,0,1,1,1,0,26,1,1,0,1,3,3,0,1,3,2,0,2,1,1,0,1,3,3,0,1,3,2,0,2,1,1,0,1,3,1,0,8,1,1,0,87,1,1,0,8,1,1,0,9,1,1,0,9,1,1,0,26,1,1,0,9,1,1,0,9,1,1,0,10,1,1,0,23,1,2,5,1,1,10,5,1,1,2,0,48,1,1,0,3,3,4,0,1,1,1,0,1,3,4,0,1,3,2,0,1,1,1,0,5,3,3,0,1,1,1,0,26,1,1,0,4,3,4,0,1,
			1,1,0,1,3,4,0,4,1,1,0,10,1,1,0,23,1,1,0,7,1,1,0,6,1,1,0,48,1,1,0,3,3,4,0,1,1,1,0,1,3,4,0,1,3,2,0,1,1,1,0,5,3,3,0,1,1,1,0,26,1,1,0,2,3,1,0,1,3,4,0,1,1,1,0,1,3,4,0,2,3,1,0,1,1,1,0,3,3,2,0,1,3,3,0,1,1,1,0,23,1,1,0,1,3,3,0,1,3,1,0,1,1,1,0,1,3,3,0,2,5,1,0,48,1,1,0,8,1,1,0,9,1,1,0,9,1,1,0,26,1,1,0,9,1,1,0,9,1,1,0,10,1,1,0,23,1,1,0,7,
			1,1,0,6,1,1,0,48,1,15,4,1,1,14,0,26,1,16,4,1,1,15,0,23,4,1,0,7,4,1,0,6,1,1,0,159,1,1,0,2,3,2,0,1,3,1,0,1,1,1,0,1,3,1,0,1,3,2,0,1,1,1,0,159,1,1,0,7,1,1,0,6,1,1,0,159,1,8,4,1,1,7,0,328
		],
		"floor": [
			0,175,4,525,0,16,2,82,0,93,2,82,0,93,2,82,0,93,2,82,0,93,2,82,0,93,2,82,0,133,1,6,0,56,1,5,0,108,1,6,0,56,1,5,0,60,3,18,0,30,1,6,0,34,3,20,0,2,1,5,0,1,3,28,0,31,3,18,0,30,1,6,0,34,3,20,0,2,1,5,0,1,3,28,0,31,3,18,0,30,1,6,0,34,3,20,0,2,1,5,0,1,3,28,0,2,3,10,0,19,3,18,0,30,1,6,0,34,3,20,0,2,1,5,0,1,3,28,0,2,3,10,0,19,3,18,0,30,1,6,0,4,3,12,0,18,3,20,0,2,1,5,0,1,3,28,0,2,3,10,
			0,19,3,18,0,30,1,6,0,4,3,12,0,18,3,20,0,2,1,5,0,1,3,28,0,2,3,10,0,19,3,18,0,30,1,6,0,4,3,12,0,18,3,20,0,2,1,5,0,1,3,28,0,2,3,10,0,19,3,18,0,30,1,6,0,4,3,12,0,18,3,20,0,2,1,5,0,1,3,28,0,2,3,10,0,19,3,18,0,30,1,6,0,4,3,12,0,18,3,20,0,2,1,5,0,1,3,28,0,2,3,10,0,19,3,18,0,30,1,6,0,4,3,12,0,18,3,20,0,2,1,5,0,1,3,28,0,2,3,10,0,19,3,18,0,14,3,6,0,10,1,6,0,4,3,12,0,18,3,20,
			0,2,1,5,0,1,3,28,0,31,3,18,0,14,3,6,0,10,1,6,0,4,3,12,0,18,3,20,0,2,1,5,0,1,3,28,0,63,3,6,0,10,1,6,0,34,3,20,0,2,1,5,0,1,3,28,0,63,3,6,0,10,1,6,0,34,3,20,0,2,1,5,0,1,3,28,0,63,3,6,0,10,1,6,0,56,1,5,0,1,3,28,0,79,1,6,0,56,1,5,0,1,3,28,0,79,1,6,0,56,1,5,0,23,3,26,0,59,1,6,0,56,1,5,0,23,3,26,0,9,1,4,0,8,3,12,0,26,1,6,0,56,1,5,0,3,3,14,0,6,3,26,0,9,1,4,0,8,3,12,
			0,26,1,6,0,56,1,5,0,3,3,14,0,6,3,26,0,9,1,4,0,8,3,12,0,26,1,6,0,56,1,5,0,3,3,14,0,6,3,26,0,9,1,4,0,8,3,12,0,26,1,6,0,56,1,5,0,3,3,14,0,6,3,26,0,9,1,4,0,8,3,12,0,4,3,16,0,6,1,6,0,56,1,5,0,3,3,14,0,6,3,26,0,9,1,4,0,8,3,12,0,4,3,16,0,6,1,6,0,56,1,5,0,3,3,14,0,6,3,26,0,9,1,4,0,8,3,12,0,4,3,16,0,6,1,6,0,2,1,62,3,14,1,35,0,6,1,4,0,8,3,12,0,4,3,16,0,6,1,6,
			0,2,1,62,3,14,1,35,0,6,1,4,0,24,3,16,0,6,1,6,0,2,1,62,3,14,1,4,3,24,1,7,0,34,3,16,0,6,1,6,0,2,1,62,3,14,1,4,3,24,1,7,6,10,0,24,3,16,0,6,1,6,0,2,7,6,3,14,7,34,1,5,7,3,3,14,7,4,3,24,7,7,6,10,0,24,3,16,0,6,1,6,0,2,7,6,3,14,7,34,1,5,7,3,3,14,7,4,3,24,7,7,6,20,0,14,3,16,0,6,1,6,0,2,7,6,3,14,7,34,1,5,7,3,3,14,7,4,3,24,7,7,6,20,0,14,3,16,0,6,1,6,0,2,7,6,3,14,7,34,
			1,5,7,3,3,14,7,4,3,24,7,7,6,30,0,26,1,6,0,2,7,6,3,14,7,34,1,5,7,3,3,14,7,4,3,24,7,7,6,30,0,26,1,6,0,2,7,6,3,14,7,34,1,5,7,3,3,14,7,4,3,24,7,7,0,10,6,30,0,16,1,6,0,2,7,6,3,14,7,34,1,5,7,21,3,24,7,7,0,10,6,30,0,16,1,6,0,2,7,6,3,14,7,34,1,5,7,21,3,24,7,7,0,20,6,30,0,6,1,6,0,2,7,6,3,14,7,34,1,5,7,21,3,24,7,7,0,20,6,30,0,6,1,6,0,2,7,6,3,14,7,34,1,5,7,21,3,24,7,7,
			0,30,6,26,1,6,0,2,7,54,1,5,7,21,3,24,7,7,0,30,6,26,1,6,0,2,7,54,1,5,7,21,3,24,7,7,0,40,6,16,1,6,6,8,7,48,1,5,7,52,0,40,6,16,1,6,6,8,7,48,1,5,7,52,0,50,6,6,1,6,6,18,7,38,1,5,7,21,3,28,7,3,0,50,6,6,1,6,6,18,7,38,1,5,7,21,3,28,7,3,0,56,1,6,6,28,7,28,1,5,7,21,3,28,7,3,0,56,1,6,6,28,7,28,1,5,7,21,3,28,7,3,0,56,1,6,0,2,7,6,6,30,7,18,1,5,7,21,3,28,7,3,0,56,1,6,0,2,7,6,
			6,30,7,18,1,5,7,21,3,28,7,3,0,56,1,6,0,18,6,30,0,8,1,5,0,21,3,28,0,59,1,6,0,18,6,30,0,8,1,5,0,21,3,28,0,11,3,34,0,14,1,6,0,28,6,28,1,5,0,21,3,28,0,11,3,34,0,14,1,6,0,28,6,28,1,5,0,21,3,28,0,11,3,34,0,14,1,6,0,38,6,18,1,5,6,7,0,14,3,28,0,11,3,34,0,14,1,6,0,38,6,18,1,5,6,7,0,14,3,28,0,11,3,34,0,14,1,6,0,48,6,8,1,5,6,17,0,43,3,34,0,14,1,6,0,48,6,8,1,5,6,17,0,43,3,34,0,14,1,6,
			0,56,1,5,6,27,0,33,3,34,0,14,1,6,0,56,1,5,6,27,0,33,3,34,0,2,3,10,0,2,1,6,0,56,1,5,0,7,6,30,0,23,3,34,0,2,3,10,0,2,1,6,0,56,1,5,0,7,6,30,0,23,3,34,0,2,3,10,0,2,1,6,0,2,7,6,3,30,7,18,1,5,7,17,6,30,7,5,0,8,3,34,0,2,3,10,0,2,1,6,0,2,7,6,3,30,7,18,1,5,7,17,6,30,7,5,0,8,3,34,0,2,3,10,0,2,1,6,0,2,7,6,3,30,7,18,1,5,7,27,6,25,0,8,3,34,0,2,3,10,0,2,1,6,0,2,7,6,3,30,
			7,18,1,5,7,27,6,25,0,8,3,34,0,2,3,10,0,2,1,6,0,2,7,6,3,30,7,18,1,5,7,37,6,15,0,8,3,34,0,2,3,10,0,2,1,6,0,2,7,6,3,30,7,18,1,5,7,37,6,15,0,8,3,34,0,2,3,10,0,2,1,6,0,2,7,6,3,30,7,18,1,5,7,1,1,46,6,5,0,8,3,34,0,2,3,10,0,2,1,6,0,2,7,6,3,30,7,18,1,5,7,1,1,46,6,5,0,8,3,34,0,2,3,10,0,2,1,6,0,2,7,6,3,30,7,18,1,5,7,1,1,51,0,8,3,34,0,2,3,10,0,2,1,6,0,2,7,6,3,30,
			7,18,1,5,7,1,1,51,0,8,3,34,0,2,3,10,0,2,1,6,0,2,7,6,3,30,7,18,1,5,7,3,3,32,7,17,0,8,3,34,0,2,3,10,0,2,1,6,0,2,7,6,3,30,7,18,1,5,7,3,3,32,7,17,0,8,3,34,0,2,3,10,0,2,1,6,0,2,7,6,3,30,7,18,1,5,7,3,3,32,7,17,0,8,3,34,0,2,3,10,0,2,1,6,0,2,7,6,3,30,7,18,1,5,7,3,3,32,7,17,0,8,3,34,0,2,3,10,0,2,1,6,0,2,7,6,3,30,7,18,1,5,7,3,3,32,7,17,0,8,3,34,0,2,3,10,0,2,1,6,
			0,2,7,6,3,30,7,18,1,5,7,3,3,32,7,17,0,8,3,34,0,2,3,10,0,2,1,6,0,2,7,6,3,30,7,18,1,5,7,3,3,32,7,17,0,8,3,34,0,2,3,10,0,2,1,6,0,2,7,6,3,30,7,18,1,5,7,3,3,32,7,17,0,44,3,10,0,2,1,6,0,2,7,6,3,30,7,18,1,5,7,3,3,32,7,17,0,44,3,10,0,2,1,6,0,2,7,6,3,30,7,18,1,5,7,3,3,32,7,17,1,64,7,6,3,30,7,18,1,5,7,3,3,32,7,17,1,64,7,6,3,30,7,18,1,5,7,3,3,32,7,17,1,64,7,6,3,30,7,18,
			1,5,7,3,3,32,7,17,1,64,7,6,3,30,7,18,1,5,7,3,3,32,7,17,1,6,3,16,1,42,7,6,3,30,7,18,1,5,7,3,3,32,7,17,0,6,3,16,0,34,1,6,0,2,7,6,3,30,7,18,1,5,7,3,3,32,7,17,0,6,3,16,0,34,1,6,0,2,7,6,3,30,7,18,1,5,7,3,3,32,7,17,0,6,3,16,0,34,1,6,0,2,7,6,3,30,7,18,1,5,7,3,3,32,7,17,0,6,3,16,0,34,1,6,0,2,1,111,0,6,3,16,0,34,1,6,0,2,1,111,0,6,3,16,0,34,1,6,0,2,1,111,0,6,3,16,0,34,1,6,
			0,2,1,111,0,56,1,6,0,2,1,111
		],
		"trees": [[171,15],[167,18],[170,21],[117,24],[166,24],[4,30],[11,30],[32,30],[39,30],[46,30],[53,30],[67,30],[74,30],[81,30],[88,30],[95,30],[102,30],[109,30],[116,30],[123,30],[144,30],[14,33],[77,33],[84,33],[91,33],[98,33],[105,33],[112,33],[10,36],[31,36],[13,39],[20,39],[27,39],[55,39],[62,39],[23,42]]
	}
]


func test_entry_names_weights_and_first_entry() -> void:
	for n in range(1, 7):
		var d: Dictionary = load("res://game/world/maps/factory_%02d.gd" % n).build()
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


## 설비 자신의 WALL 대체 표현과 건물의 구조 벽을 구분한다.
func _assembly_structural_walls(script: Script) -> Dictionary:
	var walls: Dictionary = {}
	var constants: Dictionary = script.get_script_constant_map()
	for part in range(2):
		var plan: Dictionary = constants["PLAN"] if part == 0 else constants["NORTH"]
		var offset := Vector2i(0, 45 if part == 0 else 0)
		for row in plan["surfaces"]:
			var r := _rect(row[2])
			r.position += offset
			for c in _cells(r):
				var key := Vector3i(c.x, c.y, int(row[1]))
				if c.x == r.position.x or c.y == r.position.y or c.x == r.end.x - 1 or c.y == r.end.y - 1:
					walls[key] = true
				else:
					walls.erase(key)
		for row in plan["walls"]:
			var r := _rect(row[1])
			r.position += offset
			for c in _cells(r):
				walls[Vector3i(c.x, c.y, int(row[0]))] = true
		for row in plan["voids"]:
			var r := _rect(row[1])
			r.position += offset
			for c in _cells(r):
				var key := Vector3i(c.x, c.y, int(row[0]))
				if int(row[2]) == S.WALL:
					walls[key] = true
				else:
					walls.erase(key)
		for field in ["doors", "windows"]:
			for row in plan[field]:
				walls.erase(Vector3i(int(row[1]), int(row[2]) + offset.y, int(row[0])))
	return walls


func _assembly_reserved_cells(d: Dictionary) -> Dictionary:
	var reserved: Dictionary = {}
	for lv in d["levels"]:
		var g: FieldGrid = d["levels"][lv]
		for c: Vector2i in g.doors:
			reserved[Vector3i(c.x, c.y, int(lv))] = true
			for step in DIRS:
				var front: Vector2i = c + step
				reserved[Vector3i(front.x, front.y, int(lv))] = true
		for c: Vector2i in g.windows:
			reserved[Vector3i(c.x, c.y, int(lv))] = true
	for stair in d["stairs"]:
		var c: Vector2i = stair["cell"]
		for lv in [stair["low"], stair["high"]]:
			reserved[Vector3i(c.x, c.y, int(lv))] = true
	for c: Vector2i in d["barricade_slots"] + d["stoves"]:
		reserved[Vector3i(c.x, c.y, 0)] = true
	for group in d["spawns"].values():
		for c in group:
			if c is Vector2i:
				reserved[Vector3i(c.x, c.y, 0)] = true
			elif c is Vector3i:
				reserved[c] = true
	for name in d["entries"]:
		for c: Vector2i in d["entries"][name]:
			reserved[Vector3i(c.x, c.y, int(d["entry_levels"].get(name, 0)))] = true
	for side in d["train_doors"]:
		var direction: Vector2i = Vector2i.UP if side == "upper" else Vector2i.DOWN
		for door: Vector2i in d["train_doors"][side]:
			for distance in range(3):
				var c: Vector2i = door + direction * distance
				reserved[Vector3i(c.x, c.y, 0)] = true
	for box in d["containers"].values():
		var c: Vector2i = box["cell"]
		reserved[Vector3i(c.x, c.y, int(box.get("level", 0)))] = true
	return reserved


func test_assembly_props_clear_structures_and_reserved_cells() -> void:
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var walls := _assembly_structural_walls(MAPS[i])
		var reserved := _assembly_reserved_cells(d)
		var occupied: Dictionary = {}
		var wall_conflicts := 0
		var reserved_conflicts := 0
		var prop_conflicts := 0
		var missing_low := 0
		for p in d["props"]:
			var lv: int = p.get("level", 0)
			var r: Rect2i = p["rect"]
			if p["solid"] == "low" and p["kind"] != "water" and not d["low_blocks"].has(r):
				missing_low += 1
			for c in _cells(r):
				var key := Vector3i(c.x, c.y, lv)
				var wall: bool = walls.has(key)
				if d["levels"].has(lv) and p["solid"] != "wall":
					var g: FieldGrid = d["levels"][lv]
					wall = wall or g.solid_at(c) == S.WALL
				if wall:
					wall_conflicts += 1
				if reserved.has(key):
					reserved_conflicts += 1
				if occupied.has(key):
					prop_conflicts += 1
				occupied[key] = true
		assert_eq(wall_conflicts, 0, d["place_id"] + " 소품과 구조 벽")
		assert_eq(reserved_conflicts, 0, d["place_id"] + " 소품과 출입·수납 칸")
		assert_eq(prop_conflicts, 0, d["place_id"] + " 같은 층 소품 겹침")
		# 물은 기존 계약대로 low_blocks 밖이다(위 시험들과 같은 예외).
		assert_eq(missing_low, 0, d["place_id"] + " 물을 뺀 low 소품의 low_blocks 대응")


func test_assembly_building_wall_bounds() -> void:
	for d in _maps:
		var outside := 0
		for g: FieldGrid in d["levels"].values():
			for y in range(g.height):
				for x in range(g.width):
					var c := Vector2i(x, y)
					var id: int = g.building_at(c)
					if g.solid_at(c) != S.WALL or id < 0:
						continue
					if id >= d["buildings"].size() or not d["buildings"][id]["rect"].has_point(c):
						outside += 1
		assert_eq(outside, 0, d["place_id"] + " 건물 바깥의 건물 벽 번호")


func test_assembly_container_name_suffixes() -> void:
	for d in _maps:
		for box in d["containers"].values():
			var matched := false
			for suffix in CONTAINER_SUFFIXES:
				if String(box["name"]).ends_with(suffix):
					matched = true
					break
			assert_true(matched, d["place_id"] + ": " + String(box["name"]))


func test_assembly_prop_vocabulary_and_low_lines() -> void:
	for d in _maps:
		for p in d["props"]:
			assert_true(KINDS.has(p["kind"]), d["place_id"] + ": " + String(p["kind"]))
		# 물(못·도랑)은 기존 계약대로 곧은 LOW 길이에서 뺀다.
		var water: Dictionary = {}
		for p in d["props"]:
			if p["kind"] == "water":
				var lv: int = int(p.get("level", 0))
				for c in _cells(p["rect"]):
					water[Vector3i(c.x, c.y, lv)] = true
		var longest := 0
		for lv in d["levels"]:
			var g: FieldGrid = d["levels"][lv]
			for y in range(g.height):
				var run := 0
				for x in range(g.width):
					run = run + 1 if g.solid_at(Vector2i(x, y)) == S.LOW and not water.has(Vector3i(x, y, lv)) else 0
					longest = maxi(longest, run)
			for x in range(g.width):
				var run := 0
				for y in range(g.height):
					run = run + 1 if g.solid_at(Vector2i(x, y)) == S.LOW and not water.has(Vector3i(x, y, lv)) else 0
					longest = maxi(longest, run)
		assert_true(longest <= 10, d["place_id"] + " 물을 뺀 LOW 최대 길이")


func _roman_or_han(text: String) -> bool:
	for i in range(text.length()):
		var c: int = text.unicode_at(i)
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 0x3400 and c <= 0x9FFF):
			return true
	return false
