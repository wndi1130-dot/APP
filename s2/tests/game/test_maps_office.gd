extends "res://addons/gut/test.gd"
## 관청 지도 계약과 조립 자료를 검증한다. 실행 결과는 지도 결과 글에 남긴다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const MAP_SCRIPTS: Array = [
	preload("res://game/world/maps/office_01.gd"),
	preload("res://game/world/maps/office_02.gd"),
	preload("res://game/world/maps/office_03.gd"),
	preload("res://game/world/maps/office_04.gd"),
	preload("res://game/world/maps/office_05.gd"),
	preload("res://game/world/maps/office_06.gd"),
]
const KEYS: Array[String] = [
	"grid", "levels", "stairs", "containers", "spots", "stoves", "entries", "entry_gap",
	"entry_levels", "buildings", "wagons", "train", "platform", "unload", "train_cars",
	"spawns", "labels", "trees", "low_blocks", "upper_rects", "lights", "manholes",
	"manhole_levels", "hole_faces", "sewer_names", "anchors", "zone_names", "place_id", "place_kind",
	"bands", "train_doors", "crossings", "barricade_slots", "interior_kind_slots", "props", "entry_names", "entry_weights", "first_entry",
]
const KINDS: Array[String] = [
	"car", "handcart", "firewood_pile", "barrel", "crate_stack", "sack_pile", "bench",
	"shelf", "bed", "desk", "cold_stove", "lamp_post", "display_shelf", "shop_counter",
	"checkout", "shopping_cart", "pallet_stack", "market_stall", "shop_awning",
	"freezer_chest", "bread_rack", "blank_sign", "floor_shell", "stair_stub", "water",
	"file_cabinet", "record_shelf_row", "service_counter", "typewriter_desk", "strongbox",
	"paper_cart", "printing_press", "notice_board", "meeting_table", "mail_sorting_rack",
	"flagpole", "map_cabinet", "courtyard_planter", "arcade_column", "evidence_shelf",
	"gear_rack", "armory_rack", "ammo_crate", "quilted_vest", "radio_set", "patrol_car",
	"tow_truck", "wrecked_car_cluster", "tire_stack", "fuel_can_group", "tool_bench",
	"fire_engine", "hose_reel", "hose_rack", "axe_rack", "ladder_rack", "heavy_coat_rack",
	"bunk_bed", "training_frame", "hand_pump_cart", "weigh_platform", "post_box_row",
	"ration_ledger_chest", "stone_wall_segment", "hay_cart", "bare_tree",
	"skybridge_rail", "stationery_rack", "fuel_pump",
	# 북쪽 확장 자료의 기존 낱말: 공용 종류 표 등록 후보.
	"coal_heap", "lumber_stack", "city_bus", "snowplow_truck", "cable_drum", "battery_rack",
]
const JUDGMENTS: Array[String] = [
	"안마당을 건너면 가깝지만 구멍이 회랑 양쪽에 있다.",
	"무기고 철문은 큰 소리 없이는 못 연다. 열면 총과 탄을 얻고 무리가 당겨진다.",
	"차고 문을 올리면 가장 빠른 길이 열리지만 시끄럽고 다시 못 닫는다.",
	"구름다리로 건너야 조용하다. 서가는 길고 무엇이 쓸모 있는지 모른다.",
	"문서가 적고 가깝다. 짧게 끝낼지 둘레 농가까지 넓힐지 고른다.",
	"차량 더미는 엄폐가 많으나 시야가 짧다. 지를지 담을 따라 돌지 고른다.",
]
const ITEMS: Array[String] = [
	"ammo_pistol", "ammo_shell", "bandage", "bottle_spirit", "cloth", "document",
	"flare", "food_pack", "info_telegraph", "info_timetable", "luxury_pack",
	"med_box", "medkit", "needle_thread", "plank", "scrap", "symbol_bell", "tweezers",
]
const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var _maps: Array[Dictionary] = []
var _plans: Array[Dictionary] = []
var _people: Array[PackedInt32Array] = []
var _dead: Array[PackedInt32Array] = []
var _stacked: Array[PackedInt32Array] = []


func before_all() -> void:
	for script in MAP_SCRIPTS:
		var d: Dictionary = script.build()
		_maps.append(d)
		_plans.append(_joined_plan(script.get_script_constant_map()))
		_people.append(_flood(d["grid"], d["train_doors"]["lower"]))
		_dead.append(_flood(d["grid"], d["train_doors"]["lower"], true))
		_stacked.append(_floor_flood(d))


func _want(condition: bool, errors: Array[String], message: String) -> void:
	if not condition and errors.size() < 30:
		errors.append(message)


func _done(errors: Array[String], d: Dictionary) -> void:
	assert_eq(errors.size(), 0, "%s: %s" % [d["place_id"], "; ".join(errors)])


func _rect(raw: Array) -> Rect2i:
	return Rect2i(int(raw[0]), int(raw[1]), int(raw[2]), int(raw[3]))


func _cell(raw: Array) -> Vector2i:
	return Vector2i(int(raw[0]), int(raw[1]))


func _flood(g: FieldGrid, starts: Array, dead: bool = false, blocked: Dictionary = {}) -> PackedInt32Array:
	var distance := PackedInt32Array()
	distance.resize(g.width * g.height)
	distance.fill(-1)
	var queue: Array[Vector2i] = []
	for c: Vector2i in starts:
		if g.inside(c) and not blocked.has(c) and (g.dead_can_walk(c) if dead else g.people_can_walk(c)):
			if distance[g.index(c)] < 0:
				distance[g.index(c)] = 0
				queue.append(c)
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for direction: Vector2i in DIRS:
			var next: Vector2i = c + direction
			if not g.inside(next) or blocked.has(next):
				continue
			var i: int = g.index(next)
			if distance[i] >= 0 or not (g.dead_can_walk(next) if dead else g.people_can_walk(next)):
				continue
			distance[i] = distance[g.index(c)] + 1
			queue.append(next)
	return distance


func _floor_flood(d: Dictionary, side: String = "lower") -> PackedInt32Array:
	var g: FieldGrid = d["grid"]
	var size: int = g.width * g.height
	var distance := PackedInt32Array()
	distance.resize(size * 4)
	distance.fill(-1)
	var links: Dictionary = {}
	for stair in d["stairs"]:
		var cell: Vector2i = stair["cell"]
		var a: int = (int(stair["low"]) + 1) * size + g.index(cell)
		var b: int = (int(stair["high"]) + 1) * size + g.index(cell)
		if not links.has(a):
			links[a] = []
		if not links.has(b):
			links[b] = []
		links[a].append(b)
		links[b].append(a)
	var queue := PackedInt32Array()
	for c: Vector2i in d["train_doors"][side]:
		var i: int = size + g.index(c)
		distance[i] = 0
		queue.append(i)
	var head: int = 0
	while head < queue.size():
		var current: int = queue[head]
		head += 1
		var lv: int = floori(float(current) / float(size)) - 1
		var local: int = current % size
		var c := Vector2i(local % g.width, floori(float(local) / float(g.width)))
		var candidates: Array[int] = []
		for direction: Vector2i in DIRS:
			var next: Vector2i = c + direction
			if g.inside(next):
				candidates.append((lv + 1) * size + g.index(next))
		for next: int in links.get(current, []):
			candidates.append(next)
		for next: int in candidates:
			if distance[next] >= 0:
				continue
			var next_lv: int = floori(float(next) / float(size)) - 1
			var index: int = next % size
			var nc := Vector2i(index % g.width, floori(float(index) / float(g.width)))
			var lg: FieldGrid = d["levels"][next_lv]
			if lg.people_can_walk(nc):
				distance[next] = distance[current] + 1
				queue.append(next)
	return distance


func _door_clearance(plan: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for row in plan["doors"]:
		if int(row[0]) != 0:
			continue
		var c: Vector2i = _cell(row[1])
		var direction: Vector2i = Vector2i.RIGHT if row[4] == "x" else Vector2i.DOWN
		for step in range(-3, 4):
			out[c + direction * step] = true
	for raw in plan["aprons"]:
		var r: Rect2i = _rect(raw)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				out[Vector2i(x, y)] = true
	return out


func _named_ok(name: String) -> bool:
	if name.is_empty():
		return false
	for i in range(name.length()):
		var code: int = name.unicode_at(i)
		if (code >= 65 and code <= 90) or (code >= 97 and code <= 122):
			return false
		if (code >= 0x3400 and code <= 0x9fff) or (code >= 0xf900 and code <= 0xfaff):
			return false
	return true


func _inside_building(d: Dictionary, r: Rect2i) -> bool:
	for b in d["buildings"]:
		var bounds: Rect2i = b["rect"]
		if bounds.encloses(r):
			return true
	return false


func test_exact_keys_size_identity_and_named_zones() -> void:
	for n in range(_maps.size()):
		var d: Dictionary = _maps[n]
		var g: FieldGrid = d["grid"]
		var errors: Array[String] = []
		_want(d.size() == KEYS.size(), errors, "exact key count")
		for key in KEYS:
			_want(d.has(key), errors, "missing key " + key)
		for key: String in d:
			_want(KEYS.has(key), errors, "unapproved key " + key)
		_want(g.width >= 150 and g.width <= 180 and g.height >= 135 and g.height <= 155, errors, "map dimensions")
		_want(d["place_id"] == "office_%02d" % (n + 1) and d["place_kind"] == "office", errors, "place identity")
		var zones: Dictionary = {}
		for zone: String in g.zone:
			zones[zone] = true
			_want(d["zone_names"].has(zone), errors, "zone missing a name")
		_want(zones.size() >= 8 and zones.size() <= 12, errors, "zone count")
		_want(d["zone_names"].size() == zones.size(), errors, "no unused zone names")
		for name: String in d["zone_names"].values():
			_want(_named_ok(name), errors, "zone name")
		_done(errors, d)


func test_record_cellars_have_two_cell_wide_circulation_loops() -> void:
	for n in [0, 3]:
		var d: Dictionary = _maps[n]
		var errors: Array[String] = []
		_want(_plans[n].has("archive_loop"), errors, "record cellar loop is specified")
		for row in _plans[n].get("archive_loop", []):
			var lg: FieldGrid = d["levels"][int(row[0])]
			var corners: Array = row[1]
			_want(corners.size() == 4, errors, "four sides of a circulation loop")
			for i in range(corners.size()):
				var a: Vector2i = _cell(corners[i])
				var b: Vector2i = _cell(corners[(i + 1) % corners.size()])
				_want(a.x == b.x or a.y == b.y, errors, "cardinal loop segment")
				var direction := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
				var inward := Vector2i(-direction.y, direction.x)
				var steps: int = absi(b.x - a.x) + absi(b.y - a.y)
				for step in range(steps + 1):
					var c: Vector2i = a + direction * step
					_want(lg.people_can_walk(c) and lg.people_can_walk(c + inward), errors, "two clear cells along loop")
		_done(errors, d)


func test_central_train_both_boarding_sides_and_two_crossings() -> void:
	for d in _maps:
		var g: FieldGrid = d["grid"]
		var errors: Array[String] = []
		_want(d["train"] == Rect2i(16, 46, 80, 3), errors, "central train")
		_want(d["platform"] == Rect2i(16, 49, 82, 6) and d["unload"] == Rect2i(16, 49, 82, 3), errors, "platform and unload")
		_want(d["bands"].size() == 2 and d["train_doors"].size() == 2, errors, "two sides")
		_want(d["bands"]["upper"] == Rect2i(0, 24, 116, 22), errors, "upper band")
		_want(d["bands"]["lower"] == Rect2i(0, 49, 116, 26), errors, "preserved lower band")
		_want(not d["bands"]["upper"].intersects(d["bands"]["lower"]), errors, "bands are disjoint")
		for side: String in ["upper", "lower"]:
			var row: int = 45 if side == "upper" else 49
			_want(Rect2i(0, 0, g.width, g.height).encloses(d["bands"][side]), errors, "band inside map")
			_want(d["train_doors"][side].size() >= 3, errors, "three doors on each side")
			for c: Vector2i in d["train_doors"][side]:
				_want(c.y == row and c.x >= 18 and c.x < 94, errors, "door beside train away from ends")
				var partner := Vector2i(c.x, 49 if side == "upper" else 45)
				_want(d["train_doors"]["lower" if side == "upper" else "upper"].has(partner), errors, "paired door x")
			for y in range(43 if side == "upper" else 49, 46 if side == "upper" else 52):
				for x in range(16, 96):
					var c := Vector2i(x, y)
					_want(g.people_can_walk(c) and g.solid_at(c) == S.NONE, errors, "three empty boarding rows")
					for p in d["props"]:
						_want(int(p.get("level", 0)) != 0 or not p["rect"].has_point(c), errors, "no prop in boarding rows")
		_want(d["spawns"]["train_door"] == d["train_doors"]["lower"], errors, "lower door spawn")
		for c: Vector2i in d["spawns"]["squad"]:
			_want(d["bands"]["lower"].has_point(c), errors, "squad in lower band")
		for y in range(46, 49):
			var west: int = 0
			var east: int = 0
			for x in range(g.width):
				_want(g.floor_at(Vector2i(x, y)) == F.RAIL, errors, "full width rail")
				if g.people_can_walk(Vector2i(x, y)):
					west += int(x < 16)
					east += int(x >= 96)
			_want(west >= 4 and east >= 4, errors, "walk around both ends")
		_want(d["crossings"].size() == 2, errors, "two crossings")
		var used: Dictionary = {}
		for crossing in d["crossings"]:
			var cc: Array = crossing["cells"]
			_want(cc.size() == 3, errors, "crossing only contains three train cells")
			var x: int = cc[0].x
			_want([32, 48, 64].has(x) and not used.has(x), errors, "different car joins")
			used[x] = true
			for k in range(cc.size()):
				_want(cc[k] == Vector2i(x, 46 + k) and g.solid_at(cc[k]) == S.BLOCK, errors, "crossing remains blocked")
			_want(g.people_can_walk(Vector2i(x, 45)) and g.people_can_walk(Vector2i(x, 49)), errors, "clear crossing ends")
			for c: Vector2i in d["train_doors"]["lower"]:
				_want(c.x != x, errors, "crossing avoids doors")
			_want(crossing["who"] == {"person": true, "zombie": false, "carrying": true, "wounded": false, "sled": false}, errors, "crossing access contract")
		_want(d["train_cars"].size() == 5, errors, "five cars")
		for k in range(d["train_cars"].size()):
			_want(d["train_cars"][k]["rect"] == Rect2i(16 + 16 * k, 46, 16, 3), errors, "shifted car")
		_want(d["train_cars"][-1]["kind"] == "engine", errors, "east engine")
		_done(errors, d)


func test_entries_reach_their_side_with_closed_doors_and_blocked_train() -> void:
	for d in _maps:
		var g: FieldGrid = d["grid"]
		var errors: Array[String] = []
		var counts: Dictionary = {"upper": 0, "lower": 0}
		var reach: Dictionary = {"upper": _flood(g, d["train_doors"]["upper"], true), "lower": _flood(g, d["train_doors"]["lower"], true)}
		for name: String in d["entries"]:
			var cc: Array = d["entries"][name]
			var side: String = "upper" if cc[0].y < 46 else "lower"
			var gap: float = float(d["entry_gap"].get(name, 0.0))
			_want(gap > 0.0 and gap <= 3.0, errors, "entry rate")
			if not d["manholes"].has(name):
				counts[side] += 1
				_want(cc.size() >= 2 and cc.size() <= 4, errors, "edge lane size")
			for c: Vector2i in cc:
				_want(g.inside(c) and not _in_band(d, c), errors, "entry outside both bands")
				if not d["manholes"].has(name):
					_want(c.x == 0 or c.y == 0 or c.x == g.width - 1 or c.y == g.height - 1, errors, "actual boundary")
				if int(d["entry_levels"].get(name, 0)) == 0:
					_want(reach[side][g.index(c)] >= 0, errors, "zombie reaches its own train side")
		_want(counts["upper"] >= 2 and counts["upper"] <= 3 and counts["lower"] >= 3 and counts["lower"] <= 5, errors, "edge entry counts per side")
		var dead_count: int = 0
		for c: Vector2i in d["spawns"]["dead_street"]:
			dead_count += 1
			_want(not _in_band(d, c) and g.dead_can_walk(c), errors, "initial dead outside bands")
		for row in d["spawns"]["dead_levels"]:
			dead_count += 1
			_want(not _in_band(d, row["cell"]), errors, "upper floor dead outside bands")
		_want(dead_count <= 60, errors, "initial crowd cap")
		_done(errors, d)


func test_holes_have_metadata_clear_distance_and_walkable_exits() -> void:
	for d in _maps:
		var g: FieldGrid = d["grid"]
		var errors: Array[String] = []
		_want(d["manholes"].size() <= 4, errors, "four holes at most")
		var doors: Array = d["train_doors"]["upper"] + d["train_doors"]["lower"]
		var surface: PackedInt32Array = _flood(g, doors, true)
		for name: String in d["manholes"]:
			var c: Vector2i = d["manholes"][name]
			_want(d["entries"].has(name) and d["entries"][name].has(c) and d["entry_gap"].has(name) and d["sewer_names"].has(name), errors, "shared hole identity")
			_want(_named_ok(d["sewer_names"][name]), errors, "hole name")
			var lv: int = int(d["manhole_levels"].get(name, 0))
			if lv == 0:
				_want(surface[g.index(c)] >= 0, errors, "surface hole reaches train")
				for door: Vector2i in doors:
					_want(absi(c.x - door.x) + absi(c.y - door.y) > 25, errors, "hole farther than 25 from either side")
			else:
				_want(lv == -1 and d["entry_levels"].get(name, 0) == -1, errors, "cellar hole level")
				var stairs: Array = []
				for stair in d["stairs"]:
					if int(stair["low"]) == -1:
						stairs.append(stair["cell"])
				var below: PackedInt32Array = _flood(d["levels"][-1], stairs, true)
				_want(below[g.index(c)] >= 0, errors, "cellar hole reaches stairs")
			if name.begins_with("culvert_"):
				_want(d["hole_faces"].has(name) and DIRS.has(d["hole_faces"][name]), errors, "culvert face")
			_want(is_equal_approx(float(d["entry_gap"][name]), 3.0 if name.begins_with("manhole_") else 0.6), errors, "hole gap")
		_done(errors, d)


func test_people_reach_every_ground_cell_and_all_zones_after_barricading() -> void:
	for n in range(_maps.size()):
		var d: Dictionary = _maps[n]
		var g: FieldGrid = d["grid"]
		var errors: Array[String] = []
		var blocked: Dictionary = {}
		for c: Vector2i in d["barricade_slots"]:
			_want(g.people_can_walk(c), errors, "walkable barricade slot")
			blocked[c] = true
		var reach: PackedInt32Array = _flood(g, d["train_doors"]["lower"], false, blocked)
		var reached_zones: Dictionary = {}
		var missing: int = 0
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				var i: int = g.index(c)
				if g.people_can_walk(c) and _people[n][i] < 0:
					missing += 1
				if reach[i] >= 0:
					reached_zones[g.zone_at(c)] = true
		_want(missing == 0, errors, "unreachable ground cells: %d" % missing)
		for zone: String in d["zone_names"]:
			_want(reached_zones.has(zone), errors, "barricades sealed zone " + zone)
		_done(errors, d)


func test_low_cover_is_visible_short_and_near_the_train() -> void:
	for d in _maps:
		var g: FieldGrid = d["grid"]
		var band: Rect2i = d["bands"]["lower"]
		var errors: Array[String] = []
		var visible_low: Dictionary = {}
		var water: Dictionary = {}
		var cover: int = 0
		var near: int = 0
		var shapes: Dictionary = {}
		for p in d["props"]:
			if p["kind"] == "water" and int(p.get("level", 0)) == 0:
				var r: Rect2i = p["rect"]
				for y in range(r.position.y, r.end.y):
					for x in range(r.position.x, r.end.x):
						water[Vector2i(x, y)] = true
		for r: Rect2i in d["low_blocks"]:
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					visible_low[Vector2i(x, y)] = true
			if band.intersects(r):
				cover += 1
				shapes[r.size] = true
				_want(maxi(r.size.x, r.size.y) >= 2 and maxi(r.size.x, r.size.y) <= 6, errors, "cover size")
				var close: bool = false
				for c: Vector2i in d["train_doors"]["lower"]:
					var point := Vector2i(clampi(c.x, r.position.x, r.end.x - 1), clampi(c.y, r.position.y, r.end.y - 1))
					if absi(c.x - point.x) + absi(c.y - point.y) <= 12:
						close = true
				if close:
					near += 1
		for stove in d["stoves"]:
			if int(stove.get("level", 0)) == 0:
				visible_low[stove["cell"]] = true
		_want(cover >= 3 and cover <= 5 and near >= 2 and shapes.size() >= 2, errors, "band cover count, proximity and variety")
		var longest: int = 0
		for axis in range(2):
			var outer: int = g.height if axis == 0 else g.width
			var inner: int = g.width if axis == 0 else g.height
			for a in range(outer):
				var run: int = 0
				for b in range(inner):
					var c := Vector2i(b, a) if axis == 0 else Vector2i(a, b)
					var low: bool = g.solid_at(c) == S.LOW
					if low and not water.has(c):
						_want(visible_low.has(c), errors, "invisible low cell")
					run = run + 1 if low and not water.has(c) else 0
					longest = maxi(longest, run)
		_want(longest <= 10, errors, "straight low run: %d" % longest)
		_done(errors, d)


func test_outdoor_blocks_are_explained_and_trees_are_safe() -> void:
	for d in _maps:
		var g: FieldGrid = d["grid"]
		var errors: Array[String] = []
		var allowed: Dictionary = {}
		var rects: Array[Rect2i] = [d["train"]]
		for wagon in d["wagons"]:
			rects.append(wagon["rect"])
		for r in rects:
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					allowed[Vector2i(x, y)] = true
		_want(d["trees"].size() >= 25 and d["trees"].size() <= 60, errors, "tree count")
		var distinct: Dictionary = {}
		for c: Vector2i in d["trees"]:
			distinct[c] = true
			allowed[c] = true
			_want(g.inside(c) and g.solid_at(c) == S.BLOCK and g.building_at(c) < 0, errors, "tree cell")
			_want(not (c.x < 14 and c.y < 14), errors, "northwest tree exclusion")
		_want(distinct.size() == d["trees"].size(), errors, "unique trees")
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				if g.solid_at(c) == S.BLOCK and g.building_at(c) < 0:
					_want(allowed.has(c), errors, "unexplained outdoor block")
					_want(not (x < 14 and y < 14), errors, "northwest block exclusion")
		_done(errors, d)


func test_buildings_have_rooms_doors_windows_and_furniture_on_each_floor() -> void:
	for n in range(_maps.size()):
		var d: Dictionary = _maps[n]
		var g: FieldGrid = d["grid"]
		var plan: Dictionary = _plans[n]
		var errors: Array[String] = []
		_want(d["buildings"].size() >= 20 and d["buildings"].size() <= 31, errors, "building count")
		var enterable: int = 0
		var large_main: bool = false
		var groups: int = 0
		for id in range(d["buildings"].size()):
			var b: Dictionary = d["buildings"][id]
			var r: Rect2i = b["rect"]
			_want(b["id"] == id and _named_ok(b["name"]), errors, "building identity")
			_want(Rect2i(0, 0, g.width, g.height).encloses(r), errors, "building bounds")
			var doors: int = 0
			for c: Vector2i in g.doors:
				if int(g.doors[c]["building"]) == id:
					doors += 1
					_want(g.solid_at(c) == S.DOOR, errors, "door was overwritten")
			if doors > 0:
				enterable += 1
			var area: int = (r.size.x - 2) * (r.size.y - 2)
			var rooms: int = 0
			for room in plan["rooms"]:
				if int(room[0]) == id and int(room[1]) == 0:
					rooms += 1
			if area > 60:
				var partition_wall: bool = false
				for y in range(r.position.y + 1, r.end.y - 1):
					for x in range(r.position.x + 1, r.end.x - 1):
						if g.solid_at(Vector2i(x, y)) == S.WALL:
							partition_wall = true
				_want(partition_wall, errors, "missing internal wall: " + b["name"])
			if area > 300:
				_want(rooms >= 3, errors, "large building needs three rooms: " + b["name"])
			if area >= 600 and rooms >= 10:
				large_main = true
		for room in plan["rooms"]:
			var r: Rect2i = _rect(room[2])
			var lv: int = int(room[1])
			_want(r.size.x >= 3 and r.size.y >= 3, errors, "room minimum")
			var markers: int = 0
			for p in d["props"]:
				if int(p.get("level", 0)) == lv and r.encloses(p["rect"]):
					markers += 1
			if lv == 0 and markers >= 3 and markers <= 6:
				groups += 1
			var furnished: bool = markers > 0
			for box in d["containers"].values():
				if int(box.get("level", 0)) == lv and r.has_point(box["cell"]):
					furnished = true
			_want(furnished, errors, "empty room on floor %d" % lv)
		_want(enterable * 10 >= d["buildings"].size() * 7, errors, "enterable building ratio")
		_want(large_main and groups >= 12, errors, "main rooms and twelve furniture groups")
		_want(not g.windows.is_empty(), errors, "windows exist")
		_done(errors, d)


func test_three_interior_zones_and_independent_north_south_loot_depth() -> void:
	for n in range(_maps.size()):
		var d: Dictionary = _maps[n]
		var g: FieldGrid = d["grid"]
		var errors: Array[String] = []
		var zones: Dictionary = {}
		var north_slot: bool = false
		for slot in d["interior_kind_slots"]:
			zones[slot["zone"]] = true
			_want(d["zone_names"].has(slot["zone"]) and slot["kinds"] == ["empty", "raiders", "nest", "beasts"], errors, "interior placeholder contract")
			north_slot = north_slot or ["I", "J", "K"].has(slot["zone"])
		_want(d["interior_kind_slots"].size() == 3 and zones.size() == 3 and north_slot, errors, "three distinct interior zones")
		var north: PackedInt32Array = _floor_flood(d, "upper")
		var deepest: Array[int] = [-1, -1]
		var nearest: Array[int] = [100000, 100000]
		for box in d["containers"].values():
			var c: Vector2i = box["cell"]
			var lv: int = int(box.get("level", 0))
			_want(_named_ok(box["name"]) and g.inside(c) and lv >= -1 and lv <= 2, errors, "container identity and bounds")
			var side: int = 0 if c.y < 46 else 1
			var at: int = (lv + 1) * g.width * g.height + g.index(c)
			var distance: int = north[at] if side == 0 else _stacked[n][at]
			_want(distance >= 0, errors, "reachable loot through stairs")
			deepest[side] = maxi(deepest[side], distance)
			nearest[side] = mini(nearest[side], distance)
			for item: String in box["items"]:
				_want(ITEMS.has(item), errors, "source item vocabulary")
			if box["name"] == "문서 묶음":
				_want(box["items"] == ["document"], errors, "same document bundle")
		_want(deepest[0] >= 45 and nearest[0] <= 25 and deepest[1] >= 80 and nearest[1] <= 40, errors, "separate deep and shallow choices")
		_done(errors, d)


func test_floor_footprints_stairs_and_fourth_floor_shells() -> void:
	for n in range(_maps.size()):
		var d: Dictionary = _maps[n]
		var g: FieldGrid = d["grid"]
		var errors: Array[String] = []
		_want(d["levels"].size() == 4 and d["levels"][0] == g, errors, "four playable levels")
		for lv in [-1, 1, 2]:
			_want(d["levels"].has(lv), errors, "required level")
			var lg: FieldGrid = d["levels"][lv]
			_want(lg.width == g.width and lg.height == g.height, errors, "full-size level grid")
			var floor_cells: int = 0
			for y in range(g.height):
				for x in range(g.width):
					var c := Vector2i(x, y)
					if lg.people_can_walk(c):
						floor_cells += 1
						_want(_inside_building(d, Rect2i(c, Vector2i.ONE)), errors, "floor outside building footprint")
			_want(floor_cells > 0, errors, "empty playable level")
		for stair in d["stairs"]:
			var low: int = int(stair["low"])
			var high: int = int(stair["high"])
			var c: Vector2i = stair["cell"]
			_want(high == low + 1 and low >= -1 and high <= 2, errors, "adjacent stair floors")
			var lower: FieldGrid = d["levels"][low]
			var upper: FieldGrid = d["levels"][high]
			_want(lower.people_can_walk(c) and upper.people_can_walk(c), errors, "clear stair landings")
			_want(_stacked[n][(high + 1) * g.width * g.height + g.index(c)] >= 0, errors, "reachable stair")
		for p in d["props"]:
			if p["kind"] != "floor_shell":
				continue
			var r: Rect2i = p["rect"]
			var matches: int = 0
			for b in d["buildings"]:
				if b["rect"] == r:
					matches += 1
			_want(matches == 1 and int(p["level"]) == 3, errors, "shell is a whole building")
			var stubs: int = 0
			for stub in d["props"]:
				if stub["kind"] == "stair_stub" and int(stub["level"]) == 2 and r.encloses(stub["rect"]):
					stubs += 1
					_want(stub["rect"].size == Vector2i(1, 2), errors, "reserved stair footprint")
			_want(stubs == 1, errors, "one future stair per shell")
		_done(errors, d)


func test_props_match_visible_geometry_and_protected_cells() -> void:
	for n in range(_maps.size()):
		var d: Dictionary = _maps[n]
		var g: FieldGrid = d["grid"]
		var errors: Array[String] = []
		var protected_cells: Dictionary = _door_clearance(_plans[n])
		for c: Vector2i in d["barricade_slots"]:
			protected_cells[c] = true
		for list in d["entries"].values():
			for c: Vector2i in list:
				protected_cells[c] = true
		for c: Vector2i in d["train_doors"]["lower"]:
			for step in range(4):
				protected_cells[c + Vector2i(0, step)] = true
		var indoors: int = 0
		_want(d["props"].size() >= 130, errors, "at least 130 props")
		for p in d["props"]:
			var r: Rect2i = p["rect"]
			var lv: int = int(p.get("level", 0))
			_want(KINDS.has(p["kind"]), errors, "prop vocabulary")
			_want(_named_ok(p["note"]), errors, "prop note")
			_want(r.size.x > 0 and r.size.y > 0 and Rect2i(0, 0, g.width, g.height).encloses(r), errors, "prop bounds")
			_want(["low", "wall", "tree", "wagon", "none"].has(p["solid"]), errors, "solid vocabulary")
			_want(lv >= -1 and lv <= 3 and (lv != 3 or p["kind"] == "floor_shell"), errors, "prop level")
			if _inside_building(d, r):
				indoors += 1
			if lv != 0:
				_want(p["solid"] == "none", errors, "upper props do not block")
				continue
			if p["solid"] == "low":
				_want(d["low_blocks"].has(r) != (p["kind"] == "water"), errors, "water uses ice, other low rectangles are drawn")
			if p["solid"] == "tree":
				_want(d["trees"].has(r.position), errors, "tree drawn")
			if p["solid"] == "wagon":
				var found: bool = false
				for wagon in d["wagons"]:
					if wagon["rect"] == r:
						found = true
				_want(found, errors, "wagon drawn")
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					var c := Vector2i(x, y)
					_want(not protected_cells.has(c), errors, "prop blocks a protected cell")
					if p["solid"] == "low":
						_want(g.solid_at(c) == S.LOW, errors, "low collider")
					elif p["solid"] == "wall":
						_want(g.solid_at(c) == S.WALL, errors, "wall collider")
					elif p["solid"] == "tree" or p["solid"] == "wagon":
						_want(g.solid_at(c) == S.BLOCK, errors, "block collider")
					if p["kind"] == "water":
						_want(g.floor_at(c) == F.ICE, errors, "water floor")
		_want(indoors * 2 >= d["props"].size(), errors, "half the props indoors")
		_done(errors, d)


func test_maps_and_judgment_headers_are_distinct_and_not_mirrored() -> void:
	var headers: Dictionary = {}
	for n in range(_maps.size()):
		var d: Dictionary = _maps[n]
		var g: FieldGrid = d["grid"]
		var errors: Array[String] = []
		var source: String = FileAccess.get_file_as_string(MAP_SCRIPTS[n].resource_path)
		var first: String = source.get_slice("\n", 0)
		_want(first == "# 이 지도가 다른 판단을 만드는 것: " + JUDGMENTS[n], errors, "exact first judgment line")
		_want(not headers.has(first), errors, "distinct judgment")
		headers[first] = true
		for previous in range(n):
			var other: FieldGrid = _maps[previous]["grid"]
			_want(g.width != other.width or g.height != other.height or g.solid != other.solid or g.floor != other.floor, errors, "distinct grid")
		var same: int = 0
		var occupied: int = 0
		for y in range(g.height):
			for x in range(floori(float(g.width) / 2.0)):
				var a: int = g.solid_at(Vector2i(x, y))
				var b: int = g.solid_at(Vector2i(g.width - x - 1, y))
				if a != S.NONE or b != S.NONE:
					occupied += 1
					if a == b and a != S.NONE:
						same += 1
		_want(occupied > 0 and same * 2 < occupied, errors, "mirror ratio below one half")
		_done(errors, d)


func _sum(prefix: PackedInt32Array, stride: int, r: Rect2i) -> int:
	return prefix[r.end.y * stride + r.end.x] - prefix[r.position.y * stride + r.end.x] - prefix[r.end.y * stride + r.position.x] + prefix[r.position.y * stride + r.position.x]


func test_no_empty_thirty_by_twenty_window_and_declared_road_widths() -> void:
	for n in range(_maps.size()):
		var d: Dictionary = _maps[n]
		var g: FieldGrid = d["grid"]
		var errors: Array[String] = []
		var stride: int = g.width + 1
		var masks: Array[PackedInt32Array] = []
		for kind in range(3):
			var prefix := PackedInt32Array()
			prefix.resize(stride * (g.height + 1))
			for y in range(g.height):
				for x in range(g.width):
					var c := Vector2i(x, y)
					var present: bool = g.solid_at(c) != S.NONE
					if kind == 1:
						present = x > 0 and g.floor_at(c) != g.floor_at(c + Vector2i.LEFT)
					elif kind == 2:
						present = y > 0 and g.floor_at(c) != g.floor_at(c + Vector2i.UP)
					var i: int = (y + 1) * stride + x + 1
					prefix[i] = int(present) + prefix[i - 1] + prefix[i - stride] - prefix[i - stride - 1]
			masks.append(prefix)
		var empty: int = 0
		for y in range(g.height - 19):
			for x in range(g.width - 29):
				var detail: int = _sum(masks[0], stride, Rect2i(x, y, 30, 20))
				detail += _sum(masks[1], stride, Rect2i(x + 1, y, 29, 20))
				detail += _sum(masks[2], stride, Rect2i(x, y + 1, 30, 19))
				if detail == 0:
					empty += 1
		_want(empty == 0, errors, "blank windows: %d" % empty)
		var main_road: bool = false
		for raw in _plans[n]["paths"]:
			var r: Rect2i = _rect(raw)
			_want(mini(r.size.x, r.size.y) >= 4, errors, "declared road under four cells")
			if mini(r.size.x, r.size.y) >= 6:
				main_road = true
		_want(main_road, errors, "six-cell main road")
		_done(errors, d)


func test_deep_entrance_aprons_are_empty_and_main_doors_face_different_sides() -> void:
	for n in range(_maps.size()):
		var d: Dictionary = _maps[n]
		var g: FieldGrid = d["grid"]
		var errors: Array[String] = []
		for raw in _plans[n]["aprons"]:
			var r: Rect2i = _rect(raw)
			_want(mini(r.size.x, r.size.y) >= 4 and maxi(r.size.x, r.size.y) >= 5, errors, "entrance apron dimensions")
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					_want(g.solid_at(Vector2i(x, y)) == S.NONE, errors, "entrance apron must be empty")
		var main: Rect2i = d["buildings"][0]["rect"]
		var sides: Dictionary = {}
		for c: Vector2i in g.doors:
			if int(g.doors[c]["building"]) != 0:
				continue
			if c.x == main.position.x:
				sides["west"] = true
			if c.x == main.end.x - 1:
				sides["east"] = true
			if c.y == main.position.y:
				sides["north"] = true
			if c.y == main.end.y - 1:
				sides["south"] = true
		_want(sides.size() >= 2, errors, "main entrances on different faces")
		_done(errors, d)




func _in_band(d: Dictionary, c: Vector2i) -> bool:
	return d["bands"]["upper"].has_point(c) or d["bands"]["lower"].has_point(c)


func _joined_plan(constants: Dictionary) -> Dictionary:
	var plan: Dictionary = constants["PLAN"].duplicate(true)
	var north: Dictionary = constants["NORTH"]
	var offset: int = plan["buildings"].size()
	for room in plan["rooms"]:
		room[2][1] += 45
	for row in plan["doors"]:
		row[1][1] += 45
	for field: String in ["aprons", "paths"]:
		for r in plan[field]:
			r[1] += 45
	for row in plan.get("archive_loop", []):
		for c in row[1]:
			c[1] += 45
	for raw in north["rooms"]:
		var room: Array = raw.duplicate(true)
		room[0] += offset
		plan["rooms"].append(room)
	for raw in north["doors"]:
		var row: Array = raw.duplicate(true)
		row[2] += offset
		plan["doors"].append(row)
	plan["aprons"].append_array(north["aprons"])
	plan["paths"].append_array(north["paths"])
	return plan


func test_north_buildings_cover_props_trees_and_open_flank() -> void:
	for n in range(_maps.size()):
		var d: Dictionary = _maps[n]
		var g: FieldGrid = d["grid"]
		var errors: Array[String] = []
		var band: Rect2i = d["bands"]["upper"]
		var buildings: Array[int] = [0, 0]
		var largest_id: int = -1
		var largest_area: int = 0
		for b in d["buildings"]:
			var r: Rect2i = b["rect"]
			buildings[0 if r.position.y < 46 else 1] += 1
			if r.position.y < 46:
				_want(not band.intersects(r), errors, "no building in upper band")
				if r.get_area() > largest_area:
					largest_area = r.get_area()
					largest_id = int(b["id"])
		_want(buildings[0] >= 6 and buildings[0] <= 9 and buildings[1] >= 14 and buildings[1] <= 22, errors, "building counts per side")
		var main_rooms: int = 0
		var groups: int = 0
		for room in _plans[n]["rooms"]:
			if int(room[0]) == largest_id and int(room[1]) == 0:
				main_rooms += 1
			if int(room[1]) != 0 or int(room[2][1]) >= 46:
				continue
			var counts: Dictionary = {}
			var total: int = 0
			for p in d["props"]:
				if int(p.get("level", 0)) == 0 and _rect(room[2]).encloses(p["rect"]):
					total += 1
					counts[p["kind"]] = int(counts.get(p["kind"], 0)) + 1
			for kind: String in counts:
				_want(counts[kind] <= 4 or ["shelf", "display_shelf"].has(kind), errors, "same prop cap in a room")
			groups += int(total >= 3 and total <= 6)
		_want(main_rooms >= 6 and groups >= 5, errors, "north main rooms and furniture groups")
		var cover: int = 0
		var near: int = 0
		var shapes: Dictionary = {}
		for r: Rect2i in d["low_blocks"]:
			if not band.encloses(r):
				continue
			cover += 1
			shapes[r.size] = true
			_want(maxi(r.size.x, r.size.y) >= 2 and maxi(r.size.x, r.size.y) <= 6, errors, "upper cover size")
			for door: Vector2i in d["train_doors"]["upper"]:
				var closest := Vector2i(clampi(door.x, r.position.x, r.end.x - 1), clampi(door.y, r.position.y, r.end.y - 1))
				if absi(door.x - closest.x) + absi(door.y - closest.y) <= 12:
					near += 1
					break
		_want(cover >= 3 and cover <= 5 and near >= 2 and shapes.size() >= 2, errors, "upper cover count proximity and shape")
		var props: int = 0
		var indoors: int = 0
		for p in d["props"]:
			if p["rect"].position.y < 46:
				props += 1
				indoors += int(_inside_building(d, p["rect"]))
		_want(props >= 40 and indoors * 2 >= props, errors, "north prop count and indoor share")
		var trees: Array[int] = [0, 0]
		for c: Vector2i in d["trees"]:
			trees[0 if c.y < 46 else 1] += 1
		_want(trees[0] >= 12 and trees[0] <= 30 and trees[1] >= 25 and trees[1] <= 60, errors, "trees per side")
		var blocked: Dictionary = {}
		for c: Vector2i in d["barricade_slots"]:
			blocked[c] = true
		var reach: PackedInt32Array = _flood(g, d["train_doors"]["upper"], false, blocked)
		var seen: Dictionary = {}
		for k in range(reach.size()):
			if reach[k] >= 0:
				seen[g.zone[k]] = true
		for zone: String in ["I", "J", "K"]:
			_want(seen.has(zone), errors, "upper barricades retain an open flank")
		_done(errors, d)


func test_north_layouts_headers_and_fold_across_train_are_distinct() -> void:
	var headers: Dictionary = {}
	for n in range(_maps.size()):
		var d: Dictionary = _maps[n]
		var g: FieldGrid = d["grid"]
		var errors: Array[String] = []
		var source: String = FileAccess.get_file_as_string(MAP_SCRIPTS[n].resource_path)
		var header: String = source.get_slice("\n", 1)
		_want(header == "# 위쪽의 판단: " + NORTH_JUDGMENTS[n] and not headers.has(header), errors, "exact unique north judgment")
		headers[header] = true
		for previous in range(n):
			var other: FieldGrid = _maps[previous]["grid"]
			var different: bool = g.width != other.width
			if not different:
				for k in range(g.width * 46):
					if g.solid[k] != other.solid[k] or g.floor[k] != other.floor[k]:
						different = true
						break
			_want(different, errors, "north terrain independently different")
		var occupied: int = 0
		var same: int = 0
		for y in range(45):
			for x in range(g.width):
				var a: int = g.solid_at(Vector2i(x, 45 - y))
				var b: int = g.solid_at(Vector2i(x, 49 + y))
				if a != S.NONE or b != S.NONE:
					occupied += 1
					same += int(a == b and a != S.NONE)
		_want(occupied > 0 and same * 2 < occupied, errors, "north south fold below half")
		_done(errors, d)


func test_south_cells_match_fixed_original_except_authorized_repairs() -> void:
	for n in range(_maps.size()):
		var d: Dictionary = _maps[n]
		var g: FieldGrid = d["grid"]
		var errors: Array[String] = []
		var exceptions: Dictionary = {}
		for raw in ORIGINAL_TREES[n]:
			exceptions[_cell(raw)] = true
		for c: Vector2i in d["trees"]:
			if c.y >= 46:
				exceptions[c - Vector2i(0, 45)] = true
		if n == 5:
			for r: Rect2i in [Rect2i(64, 11, 4, 2), Rect2i(66, 17, 4, 2)]:
				for y in range(r.position.y, r.end.y):
					for x in range(r.position.x, r.end.x):
						exceptions[Vector2i(x, y)] = true
		var at: int = 0
		var runs: Array = ORIGINAL_SOUTH_RUNS[n]
		for k in range(0, runs.size(), 2):
			var count: int = int(runs[k])
			var code: int = int(runs[k + 1])
			for step in range(count):
				var c := Vector2i(at % g.width, floori(float(at) / g.width))
				if c.y > 0 and not exceptions.has(c):
					var shifted: Vector2i = c + Vector2i(0, 45)
					_want(g.solid_at(shifted) == (code >> 3) and g.floor_at(shifted) == (code & 7), errors, "south original cell moved exactly")
				at += 1
		_want(at == g.width * (g.height - 45), errors, "complete original grid decoded")
		var south: Dictionary = MAP_SCRIPTS[n]._build_south()
		for lv: int in south["levels"]:
			var old: FieldGrid = south["levels"][lv]
			var current: FieldGrid = d["levels"][lv]
			for y in range(1, old.height):
				for x in range(old.width):
					var c := Vector2i(x, y)
					var moved: Vector2i = c + Vector2i(0, 45)
					_want(old.solid_at(c) == current.solid_at(moved) and old.floor_at(c) == current.floor_at(moved), errors, "every repaired floor shifts without drift")
			for c: Vector2i in current.doors:
				_want(current.doors[c]["cell"] == c, errors, "door metadata uses new coordinates")
		_done(errors, d)


const NORTH_JUDGMENTS: Array[String] = ["연료를 수레째 얻는 대신, 수레가 좁은 길목 하나로만 띠에 들어와 줄이 서고, 큰길이 곧장 닿는 띠 북동 모서리는 막을 수 없어 지킬 손이 갈린다.","약과 통조림을 가볍게 챙겨 빨리 돌아가는 대신, 좁은 빗살 골목에서 앞뒤가 막혀 지킴이 비는 값을 치른다.","판자와 소금을 한 아름씩 많이 얻는 대신, 막다른 소금 광까지 다녀오는 동안 열차가 비고 돌아오는 짐은 무겁다.","배터리와 전선을 가볍게 챙겨 값지게 돌아오는 대신, 버스가 맞물린 깊은 마당은 한번 들면 나올 입구를 지켜야 한다.","곡식 자루를 수북이 얻는 대신, 돌담 우리 안쪽까지 들어갔다가 지그재그 문을 되짚어 나와야 한다.","철물 상자를 가볍게 챙겨 돌아오는 대신, 선반 골목이 좁은 깊은 창고에서 소리가 갇혀 무리가 한꺼번에 몰린다."]

# 고정 원본: 반복 칸 수와 고체·바닥 묶음 값. 새 지도로부터 계산하지 않는다.
const ORIGINAL_SOUTH_RUNS: Array = [
	[175,0,16,4,80,20,95,4,80,20,95,4,80,20,79,4,8,0,5,1,3,0,82,2,85,0,5,1,3,0,82,2,85,0,5,1,3,0,82,2,85,0,5,1,3,0,82,2,85,0,5,1,3,0,82,2,85,0,5,1,3,0,82,2,85,0,5,1,35,7,4,1,28,7,4,1,14,7,22,0,4,1,59,0,5,1,5,7,1,23,6,7,1,23,6,7,1,23,6,7,1,23,6,7,1,23,1,7,4,1,1,7,1,23,6,7,1,23,6,7,1,23,6,7,1,23,5,7,1,1,1,17,2,1,4,7,1,23,6,7,1,23,2,7,4,0,1,16,6,0,1,16,10,0,4,1,59,0,5,1,23,7,3,31,9,7,4,1,12,7,3,31,13,7,4,1,14,7,22,0,4,1,59,0,5,1,23,7,3,31,9,7,4,1,12,7,3,31,13,7,4,1,14,7,2,11,1,43,19,11,4,1,59,0,5,1,2,7,7,11,1,35,6,11,19,7,4,1,28,7,4,1,14,7,1,11,18,3,2,27,1,11,4,1,59,0,5,1,2,7,1,11,12,3,1,11,19,7,4,1,28,7,4,1,14,7,1,11,18,3,2,27,1,11,4,1,2,11,1,43,15,11,9,0,7,11,1,35,6,11,18,0,5,1,2,7,1,43,12,3,1,11,19,7,4,1,28,7,4,1,14,7,1,11,18,3,2,27,1,11,4,1,1,11,2,27,12,3,2,27,1,11,9,0,1,11,3,27,7,3,2,27,1,11,18,0,5,1,2,7,1,11,12,3,1,11,19,7,4,1,28,7,4,1,14,7,1,11,18,3,2,27,1,11,4,1,1,11,16,3,1,11,9,0,1,43,12,3,1,11,18,0,5,1,2,7,1,11,12,3,1,11,19,7,4,1,28,7,4,1,14,7,11,11,1,35,10,11,4,1,1,11,16,3,1,11,9,0,1,11,12,3,1,11,18,0,5,1,2,7,1,11,12,3,1,11,19,7,4,1,28,7,4,1,14,7,1,11,20,3,1,11,4,1,1,11,1,27,13,3,2,27,1,11,9,0,1,11,2,27,8,3,2,27,1,11,18,0,5,1,2,7,7,11,1,35,6,11,19,7,4,1,28,7,4,1,14,7,1,35,20,3,1,35,4,1,9,11,1,35,8,11,9,0,7,11,1,35,6,11,18,0,5,1,2,7,1,11,12,3,1,11,19,7,4,1,28,7,4,1,14,7,1,11,20,3,1,11,4,1,1,11,16,3,1,11,9,0,1,11,2,27,7,3,3,27,1,11,18,0,5,1,2,7,1,11,12,3,1,11,19,7,4,1,28,7,4,1,14,7,11,11,1,35,10,11,4,1,1,35,16,3,1,35,9,0,1,11,12,3,1,43,18,0,5,1,2,7,1,11,12,3,1,43,19,7,4,1,26,7,2,31,4,1,14,7,1,11,18,3,2,27,1,11,4,1,1,11,16,3,1,11,9,0,1,11,2,27,8,3,2,27,1,11,18,0,5,1,2,7,1,11,12,3,1,11,19,7,4,1,28,7,4,1,14,7,1,11,18,3,2,27,1,11,4,1,9,11,1,35,8,11,9,0,7,11,1,35,6,11,18,0,5,1,2,7,7,11,1,35,6,11,19,7,4,1,28,7,4,1,4,7,4,31,6,7,1,11,18,3,2,27,1,11,4,1,1,11,2,27,12,3,2,27,1,11,41,0,5,1,35,7,4,1,28,7,4,1,4,7,4,31,6,7,19,11,1,43,2,11,4,1,1,11,16,3,1,11,12,0,20,5,9,0,5,1,35,7,4,1,28,7,4,1,14,7,22,0,4,1,1,11,2,27,13,3,1,27,1,11,12,0,20,5,9,0,5,1,35,7,4,1,28,7,4,1,14,7,22,0,4,1,15,11,1,43,2,11,12,0,14,5,1,21,5,5,9,0,5,1,35,7,4,1,28,7,4,1,14,7,22,0,4,1,30,0,20,5,9,0,5,1,35,7,4,1,28,7,4,1,14,7,14,0,42,1,20,5,1,1,8,0,5,1,2,7,7,11,1,35,6,11,19,7,4,1,28,7,4,1,14,7,2,24,3,0,2,24,7,0,42,1,20,5,1,1,8,0,5,1,2,7,1,11,4,27,7,3,1,27,1,11,19,7,4,1,28,7,4,1,14,7,5,0,2,24,4,0,2,24,1,0,42,1,14,5,1,21,5,5,1,1,8,0,5,1,2,7,1,43,12,3,1,11,19,7,4,1,28,7,4,1,14,7,11,0,2,24,1,0,63,1,8,0,5,1,2,7,1,11,12,3,1,11,19,7,4,1,28,7,4,1,14,7,14,0,63,1,8,0,5,1,2,7,1,11,12,3,1,11,19,7,4,1,28,7,4,1,14,7,14,0,15,1,2,11,1,43,15,11,30,1,8,0,5,1,2,7,1,11,2,27,7,3,3,27,1,11,88,1,1,0,6,1,3,0,1,11,2,27,12,3,2,27,1,11,1,0,3,1,2,11,1,43,21,11,10,0,5,1,2,7,7,11,1,35,6,11,88,1,1,0,6,1,3,0,1,11,16,3,1,11,1,0,3,1,1,11,4,27,4,3,2,27,1,11,4,27,5,3,2,27,1,11,10,0,5,1,2,7,1,11,3,27,4,3,5,27,1,11,88,1,1,0,6,1,3,0,1,11,16,3,1,11,1,0,3,1,1,11,10,3,1,11,11,3,1,11,10,0,5,1,2,7,1,11,12,3,1,11,88,1,1,0,6,1,3,0,1,11,1,27,13,3,2,27,1,11,1,0,3,1,1,11,10,3,1,11,11,3,1,11,10,0,5,1,2,7,1,11,12,3,1,43,3,0,3,11,1,43,12,11,1,43,11,11,1,43,8,11,4,35,5,11,1,43,11,11,1,43,14,11,1,43,6,11,6,0,6,1,3,0,9,11,1,35,8,11,1,0,3,1,1,11,3,27,5,3,2,27,1,11,3,27,6,3,2,27,1,11,10,0,5,1,2,7,1,11,2,27,10,3,1,11,3,0,1,11,2,27,1,3,4,27,2,3,2,27,1,11,2,27,7,3,2,27,1,11,2,27,7,3,2,27,1,11,5,3,1,11,2,27,7,3,2,27,1,11,2,27,7,3,2,27,1,11,2,27,8,3,2,27,1,11,6,0,6,1,3,0,1,11,16,3,1,11,1,0,3,1,6,11,1,35,10,11,1,35,6,11,10,0,5,1,2,7,7,11,1,35,6,11,3,0,1,11,11,3,1,11,11,3,1,11,11,3,1,11,5,3,1,11,11,3,1,11,11,3,1,11,12,3,1,11,6,0,6,1,3,0,1,35,16,3,1,35,1,0,3,1,1,11,22,3,1,11,10,0,5,1,3,7,16,0,1,11,11,3,1,11,11,3,1,11,11,3,1,11,5,3,1,11,11,3,1,11,11,3,1,11,12,3,1,11,1,0,1,16,4,0,6,1,3,0,1,11,16,3,1,11,1,0,3,1,1,35,22,3,1,35,10,0,5,1,3,7,16,0,1,11,11,3,1,11,11,3,1,11,11,3,1,11,5,3,1,11,11,3,1,11,11,3,1,11,12,3,1,11,6,0,6,1,3,0,9,11,1,35,8,11,1,0,3,1,1,11,22,3,1,11,10,0,5,1,3,7,16,0,1,11,11,3,1,11,11,3,1,11,11,3,1,11,5,3,1,11,11,3,1,11,11,3,1,11,12,3,1,11,6,0,6,1,3,0,1,11,2,27,12,3,2,27,1,11,1,0,3,1,6,11,1,35,10,11,1,35,6,11,10,0,5,1,3,7,16,0,1,11,11,3,1,11,11,3,1,11,11,3,1,11,5,3,1,11,11,3,1,11,11,3,1,11,12,3,1,11,6,0,6,1,3,0,1,11,16,3,1,11,1,0,3,1,1,11,2,27,4,3,4,27,1,11,2,27,5,3,4,27,1,11,10,0,5,1,3,7,16,0,1,11,11,3,1,11,11,3,1,11,11,3,1,11,5,3,1,11,11,3,1,11,11,3,1,11,12,3,1,11,1,0,1,16,4,0,6,1,3,0,1,11,2,27,13,3,1,27,1,11,1,0,3,1,1,11,10,3,1,11,11,3,1,11,10,0,5,1,1,7,8,11,1,35,7,11,2,0,1,11,11,3,1,11,11,3,1,11,11,3,1,11,5,3,1,11,11,3,1,11,11,3,1,11,12,3,1,11,6,0,6,1,3,0,15,11,1,43,2,11,1,0,3,1,1,11,2,27,5,3,3,27,1,11,2,27,6,3,3,27,1,11,10,0,5,1,1,7,1,11,5,27,7,3,2,27,1,11,2,0,1,11,11,3,1,11,11,3,1,11,11,3,1,11,5,3,1,11,11,3,1,11,11,3,1,11,12,3,1,11,6,0,6,1,22,0,3,1,21,11,1,43,2,11,10,0,5,1,1,7,1,43,14,3,1,11,2,0,1,11,1,27,8,3,2,27,1,11,1,27,8,3,2,27,1,11,1,27,8,3,2,27,1,11,5,3,1,11,1,27,8,3,2,27,1,11,1,27,8,3,2,27,1,11,1,27,9,3,2,27,1,11,2,0,4,24,4,1,4,25,49,1,8,0,5,1,1,7,1,11,14,3,1,11,2,0,6,11,1,35,11,11,1,35,11,11,1,35,6,11,5,3,6,11,1,35,11,11,1,35,12,11,1,35,6,11,1,0,1,16,4,24,4,1,4,25,49,1,8,0,5,1,1,7,1,11,14,3,1,11,2,0,1,11,78,3,1,11,2,0,4,24,4,1,4,25,49,1,8,0,5,1,1,7,1,11,3,27,11,3,1,11,2,0,1,11,78,3,1,11,2,0,4,24,4,1,4,25,49,1,8,0,5,1,1,7,8,11,1,35,7,11,2,0,1,11,78,3,1,11,6,0,57,1,8,0,5,1,1,7,1,11,7,27,7,3,1,11,2,0,10,11,4,3,52,0,4,3,10,11,1,0,1,16,4,0,6,1,2,0,2,11,1,43,23,11,3,0,9,11,1,35,8,11,10,0,5,1,1,7,1,11,14,3,1,11,2,0,1,11,2,27,4,3,2,27,1,11,2,3,1,11,1,3,52,0,1,3,1,11,2,3,1,11,2,27,4,3,2,27,1,11,6,0,6,1,2,0,1,11,3,27,7,3,1,27,1,11,3,27,8,3,1,27,1,11,3,0,1,11,3,27,12,3,1,27,1,11,10,0,5,1,1,7,1,11,14,3,1,43,2,0,1,11,8,3,1,11,4,3,52,0,4,3,1,11,8,3,1,11,6,0,6,1,2,0,1,11,11,3,1,11,12,3,1,11,3,0,1,43,16,3,1,11,10,0,5,1,1,7,1,11,2,27,11,3,1,27,1,11,2,0,1,11,8,3,1,11,4,3,52,0,4,3,1,11,8,3,1,11,6,0,6,1,2,0,1,11,2,27,9,3,1,11,2,27,10,3,1,11,3,0,1,11,2,27,14,3,1,11,10,0,5,1,1,7,8,11,1,35,7,11,2,0,1,11,8,3,1,11,4,3,52,0,4,3,1,11,8,3,1,11,6,0,6,1,2,0,1,11,2,27,7,3,2,27,1,11,2,27,8,3,2,27,1,11,3,0,1,11,2,27,12,3,2,27,1,11,10,0,5,1,3,7,11,1,5,0,1,11,8,3,1,11,4,3,52,0,4,3,1,11,8,3,1,11,6,0,6,1,2,0,6,11,1,35,12,11,1,35,6,11,3,0,9,11,1,35,8,11,10,0,5,1,3,7,11,1,5,0,1,11,8,3,1,11,4,3,52,0,4,3,1,11,8,3,1,11,6,0,6,1,2,0,1,11,24,3,1,11,3,0,1,11,2,27,11,3,3,27,1,11,10,0,5,1,3,7,11,1,5,0,1,11,8,3,1,35,4,3,52,0,4,3,1,35,8,3,1,11,6,0,6,1,2,0,1,35,24,3,1,35,3,0,1,11,14,3,2,27,1,43,10,0,5,1,3,7,11,1,5,0,1,11,8,3,1,11,4,3,52,0,4,3,1,11,8,3,1,11,1,0,1,16,4,0,6,1,2,0,1,11,24,3,1,11,3,0,1,11,1,27,13,3,2,27,1,11,10,0,5,1,3,7,11,1,5,0,1,11,8,3,1,11,2,3,1,11,1,3,52,1,1,3,1,11,2,3,1,11,8,3,1,11,6,0,6,1,2,0,6,11,1,35,12,11,1,35,6,11,3,0,9,11,1,35,8,11,15,0,3,7,6,0,5,1,5,0,1,11,8,3,1,11,4,3,52,1,4,3,1,11,8,3,1,11,6,0,6,1,2,0,1,11,2,27,6,3,3,27,1,11,2,27,7,3,3,27,1,11,36,0,3,7,2,0,1,16,3,0,5,1,5,0,1,11,8,3,1,11,4,3,52,1,4,3,1,11,8,3,1,11,6,0,6,1,2,0,1,11,9,3,2,27,1,11,10,3,2,27,1,11,36,0,3,7,6,0,5,1,5,0,1,11,1,27,5,3,2,27,1,11,4,3,52,1,4,3,1,11,2,27,5,3,1,27,1,11,1,0,1,16,4,0,6,1,2,0,1,11,1,27,8,3,2,27,1,11,1,27,9,3,2,27,1,11,36,0,3,7,6,0,5,1,5,0,10,11,4,3,52,0,4,3,10,11,6,0,6,1,2,0,23,11,1,43,5,11,1,35,5,11,17,0,6,11,1,35,5,11,1,7,6,0,5,1,5,0,1,11,2,27,4,3,2,27,1,11,4,3,52,0,4,3,1,11,2,27,4,3,2,27,1,11,6,0,6,1,22,0,4,1,1,11,2,27,5,3,2,27,1,11,17,0,1,11,3,27,5,3,2,27,1,11,1,7,2,0,1,16,3,0,5,1,5,0,1,11,8,3,1,11,4,3,1,0,2,24,38,0,2,24,9,0,4,3,1,11,8,3,1,11,6,0,14,1,4,25,14,1,1,43,9,3,1,11,14,1,3,0,1,43,8,3,2,27,1,11,1,7,6,0,5,1,5,0,1,11,8,3,1,11,4,3,1,0,2,24,2,0,2,24,34,0,2,24,2,0,2,24,5,0,4,3,1,11,8,3,1,11,1,0,1,16,4,0,14,1,4,25,14,1,1,11,9,3,1,11,2,1,5,11,1,35,4,11,2,1,3,0,1,11,10,3,1,11,1,7,6,0,5,1,5,0,1,11,8,3,1,11,2,3,1,11,1,3,52,0,1,3,1,11,2,3,1,11,8,3,1,11,6,0,32,1,1,11,9,3,1,11,2,1,1,11,4,27,3,3,1,27,1,11,2,1,3,0,1,11,1,27,7,3,2,27,1,11,1,7,6,0,5,1,5,0,1,11,8,3,1,11,4,3,52,0,4,3,1,11,8,3,1,11,6,0,32,1,1,11,2,27,6,3,1,27,1,11,2,1,1,43,8,3,1,11,2,1,3,0,6,11,1,35,5,11,1,7,2,0,1,16,3,0,5,1,5,0,1,11,8,3,1,11,4,3,52,0,4,3,1,11,8,3,1,11,6,0,6,1,22,0,4,1,5,11,1,35,5,11,2,0,1,11,8,3,1,11,5,0,1,11,2,27,5,3,3,27,1,11,1,7,6,0,5,1,5,0,1,11,8,3,1,35,4,3,52,0,4,3,1,35,8,3,1,11,1,0,1,16,4,0,6,1,22,0,4,1,1,11,4,27,4,3,1,27,1,11,2,0,1,11,2,27,3,3,3,27,1,11,5,0,1,11,8,3,2,27,1,43,1,7,6,0,5,1,5,0,1,11,8,3,1,11,4,3,52,0,4,3,1,11,8,3,1,11,6,0,6,1,4,0,2,11,1,43,13,11,2,0,4,1,1,11,9,3,1,11,2,0,5,11,1,35,4,11,5,0,1,11,1,27,7,3,2,27,1,11,1,7,6,0,5,1,5,0,1,11,8,3,1,11,4,3,52,0,4,3,1,11,8,3,1,11,6,0,6,1,4,0,1,11,2,27,10,3,2,27,1,11,2,0,4,1,1,11,9,3,1,43,2,0,1,11,3,27,5,3,1,11,5,0,6,11,1,35,5,11,1,7,2,0,1,16,3,0,5,1,5,0,1,11,8,3,1,11,4,3,52,0,4,3,1,11,8,3,1,11,6,0,6,1,4,0,1,11,14,3,1,11,2,0,4,1,1,11,2,27,7,3,1,11,2,0,1,11,4,27,4,3,1,43,15,0,3,7,6,0,5,1,5,0,1,11,8,3,1,11,4,3,52,0,4,3,1,11,8,3,1,11,1,0,1,16,4,0,6,1,4,0,1,11,14,3,1,11,2,0,4,1,5,11,1,35,5,11,2,0,1,11,1,27,5,3,2,27,1,11,15,0,3,7,6,0,5,1,5,0,1,11,1,27,5,3,2,27,1,11,2,3,1,11,1,3,52,0,1,3,1,11,2,3,1,11,2,27,5,3,1,27,1,11,6,0,6,1,4,0,1,11,1,27,11,3,2,27,1,11,2,0,4,1,13,0,5,11,1,35,4,11,15,0,3,7,6,0,5,1,5,0,10,11,4,3,52,0,4,3,10,11,6,0,6,1,4,0,8,11,1,35,7,11,2,0,4,1,11,0,4,24,23,0,3,7,2,0,1,16,3,0,5,1,5,0,1,11,78,3,1,11,6,0,6,1,4,0,1,11,14,3,1,11,2,0,4,1,11,0,4,24,23,0,3,7,6,0,5,1,5,0,1,11,78,3,1,35,6,0,6,1,4,0,1,35,14,3,1,35,2,0,4,1,28,0,6,11,1,35,5,11,1,7,6,0,5,1,5,0,1,11,78,3,1,11,6,0,6,1,4,0,1,11,14,3,1,11,2,0,4,1,1,0,2,11,1,43,17,11,7,0,1,11,4,27,5,3,1,27,1,11,1,7,6,0,5,1,5,0,6,11,1,35,11,11,1,35,11,11,1,35,6,11,5,3,6,11,1,35,11,11,1,35,12,11,1,35,6,11,6,0,6,1,4,0,8,11,1,35,7,11,2,0,4,1,1,0,1,11,2,27,2,3,4,27,1,11,2,27,3,3,4,27,1,11,7,0,1,43,10,3,1,11,1,7,2,0,1,16,3,0,5,1,5,0,1,11,2,27,7,3,2,27,1,11,2,27,7,3,2,27,1,11,2,27,7,3,2,27,1,11,5,3,1,11,2,27,7,3,2,27,1,11,2,27,7,3,2,27,1,11,2,27,8,3,2,27,1,11,6,0,6,1,4,0,1,11,2,27,10,3,2,27,1,11,2,0,4,1,1,0,1,11,8,3,1,11,9,3,1,11,7,0,1,11,10,3,1,11,1,7,6,0,5,1,5,0,1,11,6,3,4,27,1,3,1,11,11,3,1,11,11,3,1,11,5,3,1,11,11,3,1,11,11,3,1,11,12,3,1,11,1,0,1,16,4,0,6,1,4,0,1,11,14,3,1,11,2,0,4,1,1,0,1,11,8,3,1,11,9,3,1,11,7,0,1,11,2,27,5,3,3,27,1,11,1,7,6,0,5,1,5,0,1,11,11,3,1,11,11,3,1,11,11,3,1,11,5,3,1,11,11,3,1,11,11,3,1,11,12,3,1,11,6,0,6,1,4,0,1,11,2,27,11,3,1,27,1,11,2,0,4,1,1,0,1,11,8,3,1,11,9,3,1,11,7,0,6,11,1,35,5,11,1,7,6,0,5,1,5,0,1,11,11,3,1,11,11,3,1,11,11,3,1,11,5,3,1,11,11,3,1,11,11,3,1,11,12,3,1,11,6,0,6,1,4,0,13,11,1,43,2,11,2,0,4,1,1,0,1,11,2,27,3,3,3,27,1,11,2,27,4,3,3,27,1,11,7,0,1,11,3,27,3,3,4,27,1,11,1,7,2,0,1,16,3,0,5,1,5,0,1,11,11,3,1,11,11,3,1,11,11,3,1,11,5,3,1,11,11,3,1,11,11,3,1,11,12,3,1,11,6,0,6,1,22,0,4,1,1,0,5,11,1,35,8,11,1,35,5,11,7,0,1,11,10,3,1,43,1,7,6,0,5,1,5,0,1,11,11,3,1,11,11,3,1,11,11,3,1,11,5,3,1,11,11,3,1,11,11,3,1,11,12,3,1,11,1,0,1,16,4,0,6,1,22,0,4,1,1,0,1,11,18,3,1,11,7,0,1,11,1,27,7,3,2,27,1,11,1,7,6,0,5,1,5,0,1,11,11,3,1,11,11,3,1,11,11,3,1,11,5,3,1,11,11,3,1,11,11,3,1,11,12,3,1,11,6,0,6,1,4,0,5,11,1,35,4,11,8,0,4,1,1,0,1,35,18,3,1,35,7,0,6,11,1,35,5,11,1,7,6,0,5,1,5,0,1,11,11,3,1,11,11,3,1,11,11,3,1,11,5,3,1,11,11,3,1,11,11,3,1,11,12,3,1,11,6,0,6,1,4,0,1,11,3,27,4,3,1,27,1,11,8,0,4,1,1,0,1,11,18,3,1,11,17,0,3,7,2,0,1,16,3,0,5,1,5,0,1,11,2,27,8,3,1,27,1,11,2,27,8,3,1,27,1,11,2,27,8,3,1,27,1,11,5,3,1,11,2,27,8,3,1,27,1,11,2,27,8,3,1,27,1,11,2,27,9,3,1,27,1,11,6,0,6,1,4,0,1,43,8,3,1,11,8,0,4,1,1,0,5,11,1,35,8,11,1,35,5,11,17,0,3,7,6,0,5,1,5,0,3,11,1,43,12,11,1,43,11,11,1,43,8,11,4,35,5,11,1,43,11,11,1,43,14,11,1,43,6,11,1,0,1,16,4,0,6,1,2,0,2,1,1,11,8,3,1,11,13,1,1,11,4,27,2,3,2,27,1,11,4,27,3,3,2,27,1,11,4,1,13,0,3,7,6,0,5,1,91,0,6,1,2,0,2,1,1,11,8,3,1,11,13,1,1,11,8,3,1,11,9,3,1,11,4,1,13,0,3,7,6,0,5,1,91,0,6,1,2,0,2,1,1,11,2,27,6,3,1,43,13,1,1,11,8,3,1,11,9,3,1,11,17,1,3,7,108,1,2,0,2,1,1,11,2,27,4,3,2,27,1,11,13,1,1,11,3,27,3,3,2,27,1,11,3,27,4,3,2,27,1,11,17,1,3,7,108,1,4,0,5,11,1,35,4,11,8,0,4,1,1,0,17,11,1,43,2,11,4,0,13,1,3,7,108,1,22,0,4,1,25,0,124,1,22,0,4,1,143,0,6,1,22,0,4,1,143,0,6,1,22,0,4,1,143,0,6,1,51,0],
	[165,0,16,4,80,20,85,4,80,20,85,4,80,20,69,4,16,0,82,2,83,0,82,2,83,0,82,2,83,0,82,2,83,0,82,2,83,0,82,2,81,0,4,1,44,0,4,24,31,0,44,7,1,1,37,0,4,1,1,16,6,0,1,16,6,0,1,16,6,0,1,16,6,0,1,16,6,0,1,16,6,0,1,16,1,0,4,24,1,0,1,16,6,0,1,16,6,0,1,16,6,0,1,16,6,0,1,16,1,0,5,7,1,23,38,7,1,1,37,0,4,1,30,0,2,24,12,0,4,24,31,0,44,7,1,1,37,0,4,1,44,0,4,24,31,0,44,7,1,1,25,0,5,11,1,35,4,11,2,0,4,1,2,0,2,11,1,43,15,11,5,0,8,11,1,35,7,11,38,0,44,7,1,1,25,0,1,11,8,3,1,11,2,0,4,1,2,0,1,11,16,3,1,11,5,0,1,11,14,3,1,11,8,0,6,11,1,35,5,11,21,0,9,11,1,35,8,11,4,0,8,11,1,35,7,11,4,1,3,0,6,11,1,35,5,11,10,0,1,43,8,3,1,11,2,0,4,1,2,0,1,11,16,3,1,11,5,0,1,43,14,3,1,11,8,0,1,11,10,3,1,11,21,0,1,11,15,3,1,27,1,11,4,0,1,11,7,27,6,3,1,27,1,11,4,1,3,0,1,11,4,27,5,3,1,27,1,11,10,0,1,11,8,3,1,11,2,0,4,1,2,0,1,11,16,3,1,11,5,0,1,11,14,3,1,11,8,0,1,43,10,3,1,11,3,0,6,11,1,35,5,11,6,0,1,43,16,3,1,11,4,0,1,43,14,3,1,11,4,1,3,0,1,43,10,3,1,11,10,0,1,11,8,3,1,11,2,0,4,1,2,0,1,11,16,3,1,11,5,0,1,11,14,3,1,11,8,0,1,11,10,3,1,11,3,0,1,11,10,3,1,11,6,0,1,11,16,3,1,11,4,0,1,11,14,3,1,11,4,1,3,0,1,11,10,3,1,11,10,0,1,11,8,3,1,43,2,0,4,1,2,0,9,11,1,35,8,11,5,0,1,11,14,3,1,11,8,0,1,11,10,3,1,11,3,0,1,43,10,3,1,11,6,0,1,11,16,3,1,11,4,0,1,11,14,3,1,11,4,1,3,0,1,11,2,27,5,3,3,27,1,11,10,0,1,11,8,3,1,11,2,0,4,1,2,0,1,11,16,3,1,11,5,0,8,11,1,35,7,11,8,0,6,11,1,35,5,11,3,0,1,11,10,3,1,11,6,0,1,11,16,3,1,11,4,0,1,11,2,27,9,3,3,27,1,11,4,1,3,0,6,11,1,35,5,11,10,0,5,11,1,35,4,11,2,0,4,1,2,0,1,35,16,3,1,35,5,0,1,11,14,3,1,11,8,0,1,11,10,3,1,11,3,0,1,11,10,3,1,11,6,0,9,11,1,35,8,11,4,0,8,11,1,35,7,11,4,1,3,0,1,11,3,27,6,3,1,27,1,11,22,0,4,1,2,0,1,11,16,3,1,11,5,0,1,11,14,3,1,11,8,0,1,11,10,3,1,43,3,0,6,11,1,35,5,11,6,0,1,11,15,3,1,27,1,11,4,0,1,11,7,27,6,3,1,27,1,11,4,1,3,0,1,11,4,27,6,3,1,43,22,0,4,1,2,0,9,11,1,35,8,11,5,0,1,11,14,3,1,43,8,0,1,11,10,3,1,11,3,0,1,11,10,3,1,11,6,0,1,11,16,3,1,11,4,0,1,11,14,3,1,11,4,1,3,0,1,11,2,27,8,3,1,11,22,0,4,1,2,0,1,11,16,3,1,11,5,0,1,11,14,3,1,11,8,0,6,11,1,35,5,11,3,0,1,11,10,3,1,43,1,0,2,24,3,0,1,11,16,3,1,43,4,0,1,11,14,3,1,43,4,1,3,0,6,11,1,35,5,11,22,0,4,1,2,0,1,11,16,3,1,11,5,0,8,11,1,35,7,11,23,0,1,11,10,3,1,11,6,0,1,11,16,3,1,11,4,0,1,11,2,27,12,3,1,11,4,1,37,0,4,1,2,0,1,11,16,3,1,11,44,0,6,11,1,35,5,11,6,0,9,11,1,35,8,11,4,0,8,11,1,35,7,11,4,1,37,0,4,1,2,0,15,11,1,43,2,11,38,0,2,24,60,0,4,1,31,0,1,16,5,0,4,1,120,7,4,1,37,0,4,1,120,7,4,1,37,0,4,1,120,7,4,1,37,0,4,1,120,7,4,1,23,0,124,1,14,0,4,1,23,0,124,1,4,24,10,0,4,1,17,0,1,16,5,0,124,1,4,24,10,0,4,1,23,0,124,1,4,24,10,0,4,1,23,0,124,1,4,24,10,0,4,1,23,0,124,1,14,0,4,1,17,0,1,16,19,0,4,1,74,0,5,1,17,0,4,24,47,1,14,0,4,1,74,0,5,1,17,0,4,24,47,1,8,0,1,16,5,0,4,1,2,0,12,11,1,35,11,11,1,7,6,31,4,7,6,31,4,7,6,31,4,7,6,31,5,7,6,0,5,1,17,0,4,24,47,1,14,0,4,1,2,0,1,11,9,27,1,11,3,3,1,11,1,3,7,27,1,11,42,7,6,0,5,1,17,0,4,24,47,1,14,0,4,1,2,0,1,43,9,3,1,11,3,3,1,11,8,3,1,11,42,7,6,0,5,1,21,0,47,1,14,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,42,7,6,0,5,1,21,0,47,1,2,0,5,11,1,35,4,11,2,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,41,7,1,31,6,0,5,1,29,0,4,1,8,0,4,1,25,0,1,11,3,27,5,3,1,11,2,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,41,7,1,31,1,0,1,16,4,0,5,1,29,0,4,1,8,0,4,1,17,0,1,16,7,0,1,43,4,27,4,3,1,11,2,0,4,1,2,0,1,11,9,3,1,35,3,3,1,35,8,3,1,11,41,7,1,31,6,0,5,1,29,0,4,1,8,0,4,1,13,0,10,5,2,0,1,11,8,3,1,11,2,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,41,7,1,31,6,0,5,1,3,0,2,11,1,43,21,11,2,0,4,1,8,0,4,1,13,0,10,5,2,0,1,11,1,27,5,3,2,27,1,11,2,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,6,7,5,31,30,7,1,31,6,0,5,1,3,0,1,11,2,27,6,3,2,27,1,11,2,27,7,3,2,27,1,11,2,0,2,1,2,11,1,43,21,11,3,0,10,5,2,0,5,11,1,35,4,11,2,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,6,7,5,31,24,7,2,31,4,7,1,31,1,0,1,16,4,0,5,1,3,0,1,11,10,3,1,11,11,3,1,11,2,0,2,1,1,11,2,27,5,3,3,27,1,11,2,27,6,3,3,27,1,11,3,0,4,5,1,21,5,5,2,0,1,11,4,27,3,3,1,27,1,11,2,0,4,1,2,0,1,11,2,27,7,3,1,11,3,3,1,11,2,27,4,3,2,27,1,11,35,7,2,31,5,7,6,0,5,1,3,0,1,11,10,3,1,11,11,3,1,11,2,0,2,1,1,11,10,3,1,11,11,3,1,11,3,0,10,5,2,0,1,11,8,3,1,43,2,0,4,1,2,0,11,11,3,3,10,11,42,7,6,0,5,1,3,0,1,11,10,3,1,11,11,3,1,11,2,0,2,1,1,11,8,3,2,27,1,11,9,3,2,27,1,11,3,0,10,5,2,0,1,11,2,27,3,3,3,27,1,11,2,0,4,1,2,0,1,11,3,27,4,3,2,27,1,11,3,3,1,11,5,3,3,27,1,11,42,7,6,0,5,1,3,0,1,11,3,27,7,3,1,11,3,27,8,3,1,11,2,0,2,1,1,11,1,27,7,3,2,27,1,11,1,27,8,3,2,27,1,11,3,0,10,5,2,0,5,11,1,35,4,11,2,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,15,7,5,31,15,7,2,31,5,7,1,0,1,16,4,0,5,1,3,0,6,11,1,35,10,11,1,35,6,11,2,0,2,1,6,11,1,35,10,11,1,35,6,11,3,0,4,5,1,21,5,5,14,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,15,7,5,31,21,7,1,31,6,0,5,1,3,0,1,11,22,3,1,11,2,0,2,1,1,11,22,3,1,11,3,0,10,5,14,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,41,7,1,31,6,0,5,1,3,0,1,35,22,3,1,35,2,0,2,1,1,35,22,3,1,35,3,0,10,5,8,0,1,16,5,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,41,7,1,31,6,0,5,1,3,0,1,11,22,3,1,11,2,0,2,1,1,11,22,3,1,11,3,0,10,5,14,0,4,1,2,0,1,11,9,3,1,35,3,3,1,35,8,3,1,11,41,7,1,31,1,0,1,16,4,0,5,1,3,0,6,11,1,35,10,11,1,35,6,11,2,0,2,1,6,11,1,35,10,11,1,35,6,11,3,0,4,5,1,21,5,5,14,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,41,7,1,31,6,0,5,1,3,0,1,11,2,27,5,3,3,27,1,11,2,27,6,3,3,27,1,11,2,0,2,1,1,11,3,27,6,3,1,27,1,11,3,27,7,3,1,27,1,11,3,0,10,5,14,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,41,7,1,31,6,0,5,1,3,0,1,11,10,3,1,11,11,3,1,11,2,0,2,1,1,11,2,27,8,3,1,11,2,27,9,3,1,11,3,0,10,5,8,0,1,16,5,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,42,7,6,0,5,1,3,0,1,11,10,3,1,11,11,3,1,11,2,0,2,1,1,11,2,27,6,3,2,27,1,11,2,27,7,3,2,27,1,11,3,0,10,5,14,0,4,1,2,0,1,11,2,27,7,3,1,11,3,3,1,11,2,27,4,3,2,27,1,11,42,7,1,0,1,16,4,0,5,1,3,0,1,11,8,3,2,27,1,11,9,3,2,27,1,11,2,0,2,1,21,11,1,43,2,11,3,0,4,5,1,21,5,5,6,11,1,35,5,11,2,0,4,1,2,0,11,11,3,3,10,11,42,7,6,0,5,1,3,0,21,11,1,43,2,11,2,0,4,1,8,0,4,1,13,0,10,5,1,11,2,27,6,3,2,27,1,11,2,0,4,1,2,0,1,11,3,27,4,3,2,27,1,11,3,3,1,11,5,3,3,27,2,11,1,43,25,11,5,35,2,11,4,35,2,11,8,0,5,1,29,0,4,1,8,0,4,1,13,0,10,5,1,43,10,3,1,11,2,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,27,6,3,2,27,1,11,2,27,6,3,2,27,2,11,4,27,2,3,1,11,3,3,1,11,4,3,1,27,1,11,8,0,5,1,29,0,4,1,8,0,4,1,13,0,10,5,1,11,10,3,1,11,2,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,10,3,1,11,10,3,1,11,1,43,2,27,4,3,1,11,3,3,1,11,5,3,1,11,3,0,1,16,4,0,5,1,29,0,4,1,8,0,4,1,13,0,4,5,1,21,5,5,1,11,10,3,1,11,2,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,10,3,1,11,10,3,2,11,2,27,4,3,1,11,3,3,1,11,5,3,1,11,8,0,73,1,1,11,10,3,1,11,2,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,10,3,1,11,10,3,2,11,6,3,1,11,3,3,1,11,2,3,2,27,1,3,1,11,8,0,73,1,1,11,10,3,1,11,2,0,4,1,2,0,1,11,9,3,1,35,3,3,1,35,8,3,1,11,10,3,1,11,10,3,2,11,6,3,1,35,3,3,1,11,2,3,2,27,1,3,1,11,8,0,73,1,1,11,10,3,1,11,2,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,10,3,1,11,10,3,2,11,6,3,1,11,3,3,1,11,3,27,2,3,1,11,3,0,1,16,4,0,73,1,1,11,1,27,7,3,2,27,1,11,2,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,10,3,1,11,10,3,2,11,6,3,1,11,3,3,1,11,5,3,1,11,8,0,5,1,29,0,4,1,8,0,4,1,23,0,6,11,1,35,5,11,2,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,1,27,7,3,2,27,1,11,1,27,7,3,2,27,2,11,6,3,1,11,3,3,1,11,5,3,1,11,8,0,5,1,29,0,4,1,8,0,4,1,23,0,1,11,2,27,6,3,2,27,1,11,2,0,4,1,2,0,1,11,2,27,7,3,1,11,3,3,1,11,2,27,4,3,2,27,6,11,1,35,10,11,1,35,6,11,6,3,1,11,3,3,1,11,5,3,1,11,8,0,5,1,29,0,4,1,8,0,4,1,2,11,1,43,17,11,3,0,1,11,10,3,1,11,2,0,4,1,2,0,11,11,3,3,9,11,1,35,21,3,2,11,6,3,1,11,3,3,1,11,5,3,1,11,8,0,5,1,29,0,4,1,8,0,4,1,1,11,2,27,3,3,3,27,1,11,2,27,4,3,3,27,1,11,3,0,1,11,10,3,1,11,2,0,4,1,2,0,1,11,3,27,4,3,2,27,1,11,3,3,1,11,1,3,3,27,4,3,1,35,21,3,1,35,8,11,3,3,1,35,5,3,1,11,8,0,5,1,29,0,4,1,8,0,4,1,1,11,8,3,1,11,9,3,1,11,3,0,1,11,10,3,1,11,2,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,21,3,2,11,6,3,1,11,3,3,1,11,5,3,1,11,8,0,5,1,29,0,4,1,8,0,4,1,1,11,8,3,1,11,9,3,1,11,3,0,1,11,10,3,1,11,2,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,6,11,1,35,10,11,1,35,6,11,6,3,1,11,3,3,1,11,5,3,1,11,8,0,5,1,29,0,4,1,8,0,4,1,1,11,8,3,1,11,9,3,1,11,3,0,1,11,10,3,1,43,2,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,27,6,3,2,27,1,11,2,27,6,3,2,27,2,11,6,3,1,11,3,3,1,11,5,3,1,11,3,0,1,16,4,0,5,1,29,0,4,1,8,0,4,1,1,11,6,3,2,27,1,11,7,3,2,27,1,11,3,0,1,11,2,27,7,3,1,27,1,11,2,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,10,3,1,11,10,3,2,11,6,3,1,11,3,3,1,11,5,3,1,11,8,0,5,1,29,0,4,1,8,0,4,1,1,11,1,27,5,3,2,27,1,11,1,27,6,3,2,27,1,11,3,0,6,11,1,35,5,11,2,0,4,1,2,0,1,11,9,3,1,35,3,3,1,35,8,3,1,11,10,3,1,11,10,3,2,11,6,3,1,35,3,3,1,11,5,3,1,11,8,0,5,1,29,0,4,1,8,0,4,1,5,11,1,35,8,11,1,35,5,11,11,0,1,16,5,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,10,3,1,11,10,3,2,11,6,3,1,11,3,3,1,11,5,3,1,11,8,0,5,1,29,0,4,1,8,0,4,1,1,11,18,3,1,11,17,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,10,3,1,11,10,3,2,11,6,3,1,11,3,3,1,11,5,3,1,11,3,0,1,16,4,0,5,1,29,0,4,1,8,0,4,1,1,35,18,3,1,35,17,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,10,3,1,11,10,3,2,11,6,3,1,11,3,3,1,11,5,3,1,43,8,0,5,1,2,0,6,11,1,35,5,11,15,0,4,1,8,0,4,1,1,11,18,3,1,11,17,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,43,2,27,7,3,1,27,1,11,2,27,7,3,1,27,2,11,2,27,4,3,1,11,3,3,1,11,5,3,1,11,8,0,5,1,2,0,1,11,2,27,5,3,3,27,1,11,15,0,4,1,8,0,4,1,5,11,1,35,8,11,1,35,5,11,17,0,4,1,2,0,1,11,2,27,7,3,1,11,3,3,1,11,2,27,4,3,2,27,20,11,1,43,7,11,5,35,2,11,4,35,2,11,8,0,5,1,2,0,1,43,10,3,1,11,15,0,4,1,8,0,4,1,1,11,3,27,4,3,1,27,1,11,3,27,5,3,1,27,1,11,17,0,4,1,2,0,12,11,1,35,11,11,43,0,1,16,4,0,5,1,2,0,1,11,8,3,2,27,1,11,15,0,4,1,8,0,4,1,1,11,8,3,1,11,9,3,1,11,17,0,4,1,74,0,5,1,2,0,1,11,1,27,7,3,2,27,1,11,15,0,4,1,8,0,4,1,1,11,8,3,1,11,9,3,1,11,17,0,83,1,2,0,6,11,1,35,5,11,15,0,4,1,8,0,4,1,1,11,2,27,6,3,1,11,2,27,7,3,1,11,17,0,83,1,2,0,1,11,3,27,6,3,1,27,1,11,15,0,4,1,8,0,4,1,1,11,2,27,4,3,2,27,1,11,2,27,5,3,2,27,1,11,17,0,83,1,2,0,1,11,2,27,8,3,1,43,15,0,4,1,8,0,4,1,17,11,1,43,2,11,17,0,83,1,2,0,1,11,2,27,6,3,2,27,1,11,15,0,4,1,8,0,4,1,37,0,4,1,74,0,5,1,2,0,6,11,1,35,5,11,27,0,4,1,37,0,4,1,74,0,5,1,82,0,4,1,74,0,5,1,82,0,4,1,74,0,5,1,68,0],
	[160,0,16,4,80,20,80,4,80,20,80,4,80,20,64,4,16,0,82,2,54,0,1,16,23,0,82,2,78,0,82,2,78,0,82,2,78,0,82,2,54,0,1,16,23,0,82,2,62,0,9,5,25,0,4,24,122,0,9,5,9,0,1,16,6,0,1,16,6,0,1,16,1,0,4,24,1,0,1,16,6,0,1,16,6,0,1,16,6,0,4,24,3,0,1,16,6,0,1,16,6,0,1,16,6,0,1,16,6,0,1,16,6,0,1,16,6,0,1,16,6,0,1,16,6,0,1,16,6,0,1,16,29,0,9,5,51,0,4,24,88,0,1,16,7,0,9,5,151,0,9,5,5,0,6,11,1,35,5,11,4,0,2,11,1,43,23,11,104,0,9,5,5,0,1,11,10,3,1,11,4,0,1,11,11,3,1,11,12,3,1,11,22,0,5,11,1,35,4,11,20,0,5,11,1,35,4,11,42,0,9,5,5,0,1,43,10,3,1,11,4,0,1,11,11,3,1,11,12,3,1,11,5,0,8,11,1,35,7,11,1,0,1,11,8,3,1,11,2,0,6,11,1,35,5,11,6,0,1,11,7,3,1,27,1,11,22,0,8,11,1,35,7,11,4,0,9,5,5,0,1,11,10,3,1,11,4,0,1,11,11,3,1,11,12,3,1,11,5,0,1,11,14,3,1,11,1,0,1,43,8,3,1,11,2,0,1,11,10,3,1,11,6,0,1,43,8,3,1,11,22,0,1,11,2,27,10,3,2,27,1,11,4,0,9,5,5,0,1,11,10,3,1,11,4,0,1,11,11,3,1,11,12,3,1,11,5,0,1,43,14,3,1,11,1,0,1,11,8,3,1,11,2,0,1,43,10,3,1,11,6,0,1,11,8,3,1,11,22,0,1,43,14,3,1,11,4,0,9,5,5,0,6,11,1,35,5,11,4,0,1,11,11,3,1,11,12,3,1,11,5,0,1,11,14,3,1,11,1,0,1,11,8,3,1,11,2,0,1,11,10,3,1,11,6,0,1,11,8,3,1,11,22,0,1,11,14,3,1,11,4,0,9,5,5,0,1,11,10,3,1,11,4,0,6,11,1,35,12,11,1,35,6,11,5,0,1,11,14,3,1,11,1,0,1,11,8,3,1,11,2,0,1,11,10,3,1,11,6,0,1,11,8,3,1,43,22,0,1,11,14,3,1,11,4,0,9,5,5,0,1,11,10,3,1,43,4,0,1,11,24,3,1,11,5,0,1,11,14,3,1,11,1,0,5,11,1,35,4,11,2,0,6,11,1,35,5,11,6,0,1,11,8,3,1,11,22,0,1,11,1,27,11,3,2,27,1,11,4,0,9,5,5,0,1,11,10,3,1,11,4,0,1,35,24,3,1,35,5,0,8,11,1,35,7,11,1,0,1,11,8,3,1,11,2,0,1,11,10,3,1,11,6,0,5,11,1,35,4,11,22,0,8,11,1,35,7,11,4,0,9,5,5,0,6,11,1,35,5,11,4,0,1,11,24,3,1,11,5,0,1,11,14,3,1,11,1,0,1,11,8,3,1,11,2,0,1,11,10,3,1,43,38,0,1,11,2,27,10,3,2,27,1,11,4,0,9,5,21,0,6,11,1,35,12,11,1,35,6,11,5,0,1,11,14,3,1,11,1,0,1,11,8,3,1,43,2,0,1,11,10,3,1,11,38,0,1,11,14,3,1,11,4,0,9,5,21,0,1,11,11,3,1,11,12,3,1,11,5,0,1,11,14,3,1,43,1,0,1,11,8,3,1,11,2,0,6,11,1,35,5,11,38,0,1,11,14,3,1,43,4,0,9,5,9,0,1,24,11,0,1,11,11,3,1,11,12,3,1,11,5,0,1,11,14,3,1,11,1,0,5,11,1,35,4,11,52,0,1,11,2,27,11,3,1,27,1,11,4,0,9,5,9,0,1,24,5,0,2,24,4,0,1,11,11,3,1,11,12,3,1,11,5,0,8,11,1,35,7,11,63,0,8,11,1,35,7,11,4,0,9,5,21,0,1,11,11,3,1,11,12,3,1,11,75,0,21,5,1,21,16,5,21,0,23,11,1,43,2,11,75,0,38,5,1,0,114,7,4,31,2,7,1,0,38,5,1,0,114,7,4,31,2,7,1,0,29,5,10,0,114,7,4,31,2,7,22,0,1,16,17,0,114,7,4,31,2,7,30,0,765,1,4,25,156,1,4,25,31,1,24,0,4,1,12,0,5,1,80,0,1,24,3,25,1,1,22,0,1,16,31,0,4,1,12,0,5,1,80,0,1,24,3,25,1,1,54,0,4,1,12,0,5,1,15,0,2,11,4,35,4,11,4,35,4,11,4,35,4,11,4,35,2,11,2,0,10,11,1,35,9,11,12,0,4,1,32,0,2,11,1,43,15,11,4,0,4,1,12,0,5,1,15,0,1,11,5,3,2,27,1,11,5,3,2,27,1,11,5,3,2,27,1,11,6,3,1,11,2,0,1,11,2,27,2,3,3,27,1,11,3,3,1,11,2,27,2,3,2,27,1,11,12,0,4,1,32,0,1,11,2,27,12,3,2,27,1,11,4,0,4,1,12,0,5,1,3,0,1,16,11,0,1,11,7,3,1,11,5,3,2,27,1,11,7,3,1,11,6,3,1,11,2,0,1,43,2,27,5,3,1,11,3,3,1,11,4,3,2,27,1,11,12,0,4,1,32,0,1,11,16,3,1,11,4,0,4,1,12,0,5,1,15,0,1,11,7,3,1,11,7,3,1,11,7,3,1,11,6,3,1,11,2,0,1,11,7,3,1,11,3,3,1,11,6,3,1,11,4,0,5,11,1,35,4,11,2,1,32,0,1,11,16,3,1,11,4,0,4,1,12,0,5,1,15,0,1,11,6,27,1,3,1,11,3,27,4,3,1,11,6,27,1,3,1,11,5,27,1,3,1,11,2,0,1,11,7,3,1,11,3,3,1,11,6,3,1,11,4,0,1,11,4,27,3,3,1,27,1,11,2,1,32,0,1,11,1,27,13,3,2,27,1,11,4,0,4,1,12,0,5,1,15,0,1,11,3,27,4,3,1,35,7,3,1,35,7,3,1,35,3,3,2,27,1,3,1,11,2,0,1,11,7,3,1,35,3,3,1,35,6,3,1,11,4,0,1,43,8,3,1,11,2,1,32,0,9,11,1,35,8,11,4,0,4,1,12,0,5,1,3,0,1,16,11,0,1,11,7,3,1,11,7,3,1,11,7,3,1,11,6,3,1,11,2,0,1,11,7,3,1,11,3,3,1,11,6,3,1,11,4,0,1,11,8,3,1,11,2,1,2,0,2,11,1,43,21,11,6,0,1,11,16,3,1,11,4,0,4,1,12,0,5,1,15,0,1,11,7,3,1,11,7,3,1,11,7,3,1,11,6,3,1,11,2,0,1,11,7,3,1,11,3,3,1,11,6,3,1,11,4,0,1,11,2,27,3,3,3,27,1,11,2,1,2,0,1,11,3,27,6,3,1,27,1,11,3,27,7,3,1,27,1,11,6,0,1,35,16,3,1,35,4,0,4,1,12,0,5,1,15,0,9,11,7,3,1,11,7,3,1,11,6,3,1,11,2,0,1,11,3,27,2,3,2,27,1,11,3,3,1,11,6,27,1,11,4,0,5,11,1,35,4,11,2,1,2,0,1,11,10,3,1,11,11,3,1,11,6,0,1,11,16,3,1,11,4,0,4,1,12,0,5,1,15,0,9,11,7,3,1,11,7,3,1,11,6,3,1,11,2,0,9,11,3,3,8,11,4,0,1,11,3,27,5,3,1,11,2,1,2,0,1,11,2,27,8,3,1,11,2,27,9,3,1,11,6,0,9,11,1,35,8,11,4,0,4,1,12,0,5,1,3,0,1,16,11,0,9,11,7,3,1,11,7,3,1,11,6,3,1,11,2,0,1,11,2,27,2,3,3,27,1,11,3,3,1,11,2,27,2,3,2,27,1,11,4,0,1,11,4,27,4,3,1,43,2,1,2,0,1,11,2,27,6,3,2,27,1,11,2,27,7,3,2,27,1,11,6,0,1,11,2,27,12,3,2,27,1,11,4,0,4,1,12,0,5,1,15,0,1,11,7,3,1,11,7,3,1,11,7,3,1,11,6,3,1,11,2,0,1,11,2,27,5,3,1,11,3,3,1,11,4,3,2,27,1,11,4,0,1,11,1,27,5,3,2,27,1,11,2,1,2,0,6,11,1,35,10,11,1,35,6,11,6,0,1,11,16,3,1,11,4,0,4,1,12,0,5,1,15,0,1,11,7,3,1,11,7,3,1,11,7,3,1,11,6,3,1,11,2,0,1,11,7,3,1,11,3,3,1,11,6,3,1,11,4,0,5,11,1,35,4,11,2,1,2,0,1,11,22,3,1,11,6,0,1,11,2,27,13,3,1,27,1,11,4,0,4,1,12,0,5,1,15,0,1,11,7,3,1,11,7,3,1,11,7,3,1,11,6,3,1,11,2,0,1,11,7,3,1,11,3,3,1,11,6,3,1,11,12,0,4,1,2,0,1,35,22,3,1,35,6,0,15,11,1,43,2,11,4,0,4,1,12,0,5,1,3,0,1,16,11,0,1,11,7,3,1,11,7,3,1,11,7,3,1,11,6,3,1,11,2,0,1,11,7,3,1,35,3,3,1,35,6,3,1,11,12,0,4,1,2,0,1,11,22,3,1,11,28,0,4,1,12,0,5,1,15,0,1,11,7,3,1,11,7,3,1,11,7,3,1,11,6,3,1,11,2,0,1,11,7,3,1,11,3,3,1,11,6,3,1,11,5,0,1,16,6,0,4,1,2,0,6,11,1,35,10,11,1,35,6,11,28,0,4,1,12,0,5,1,15,0,1,11,7,3,1,11,7,3,1,11,7,3,1,11,17,3,1,11,3,3,1,11,6,3,1,11,12,0,4,1,2,0,1,11,2,27,5,3,3,27,1,11,2,27,6,3,3,27,1,11,28,0,4,1,12,0,5,1,15,0,1,11,7,3,1,11,7,3,1,11,7,3,1,11,17,3,1,11,3,3,1,11,6,3,1,11,12,0,4,1,2,0,1,11,8,3,2,27,1,11,9,3,2,27,1,11,6,0,8,11,1,35,7,11,2,0,9,11,1,35,8,11,2,0,5,1,3,0,1,16,11,0,1,11,7,3,1,35,7,3,1,35,7,3,1,35,10,3,3,27,2,3,2,27,1,11,3,3,1,11,6,27,1,11,12,0,4,1,2,0,1,11,1,27,7,3,2,27,1,11,1,27,8,3,2,27,1,11,6,0,1,11,2,27,10,3,2,27,1,11,2,0,1,11,2,27,11,3,3,27,1,11,2,0,5,1,15,0,1,11,5,3,2,27,1,11,7,3,1,11,5,3,2,27,1,11,10,3,8,11,3,3,8,11,5,0,1,16,6,0,4,1,2,0,21,11,1,43,2,11,6,0,1,43,14,3,1,11,2,0,1,43,16,3,1,11,2,0,5,1,15,0,1,11,5,3,2,27,1,11,3,27,2,3,2,27,1,11,5,3,2,27,1,11,3,27,1,3,2,27,1,11,2,0,1,11,2,27,2,3,3,27,1,11,3,3,1,11,2,27,2,3,2,27,1,11,12,0,4,1,32,0,1,11,14,3,1,11,2,0,1,11,16,3,1,11,2,0,5,1,15,0,2,11,4,35,12,11,4,35,10,11,2,0,1,11,2,27,5,3,1,11,3,3,1,11,4,3,2,27,1,11,12,0,4,1,32,0,1,11,14,3,1,11,2,0,1,11,14,3,2,27,1,11,2,0,5,1,3,0,1,16,7,0,4,1,34,0,1,11,7,3,1,11,3,3,1,11,6,3,1,11,12,0,4,1,32,0,1,11,1,27,11,3,2,27,1,11,2,0,1,11,1,27,13,3,2,27,1,11,2,0,5,1,11,0,4,1,34,0,1,11,7,3,1,11,3,3,1,11,6,3,1,11,5,0,1,16,6,0,4,1,2,0,2,11,1,43,21,11,6,0,8,11,1,35,7,11,2,0,9,11,1,35,8,11,2,0,5,1,11,0,4,1,32,7,2,0,1,11,7,3,1,35,3,3,1,35,6,3,1,11,12,0,4,1,2,0,1,11,2,27,6,3,2,27,1,11,2,27,7,3,2,27,1,11,6,0,1,11,2,27,10,3,2,27,1,11,2,0,1,11,3,27,12,3,1,27,1,11,2,0,5,1,11,0,4,1,32,7,2,0,1,11,7,3,1,11,3,3,1,11,6,3,1,11,12,0,4,1,2,0,1,11,10,3,1,11,11,3,1,11,6,0,1,11,14,3,1,11,2,0,1,11,16,3,1,11,2,0,5,1,3,0,1,16,7,0,4,1,32,7,2,0,1,11,7,3,1,11,3,3,1,11,6,3,1,11,12,0,4,1,2,0,1,11,10,3,1,11,11,3,1,11,6,0,1,11,14,3,1,43,2,0,1,11,2,27,14,3,1,43,2,0,5,1,11,0,4,1,32,7,2,0,1,11,7,3,1,11,3,3,1,11,6,3,1,43,5,0,1,16,6,0,4,1,2,0,1,11,10,3,1,11,11,3,1,11,6,0,1,11,2,27,11,3,1,27,1,11,2,0,1,11,2,27,12,3,2,27,1,11,2,0,5,1,11,0,4,1,32,7,2,0,1,11,3,27,2,3,2,27,1,11,3,3,1,11,6,27,1,11,12,0,4,1,2,0,1,11,3,27,7,3,1,11,3,27,8,3,1,11,6,0,8,11,1,35,7,11,2,0,9,11,1,35,8,11,2,0,5,1,11,0,4,1,32,7,2,0,10,11,1,35,9,11,12,0,4,1,2,0,6,11,1,35,10,11,1,35,6,11,28,0,4,1,12,0,5,1,3,0,1,16,7,0,4,1,6,7,3,31,6,7,2,31,15,7,38,1,2,0,1,11,22,3,1,11,4,0,45,1,11,0,4,1,6,7,3,31,6,7,2,31,4,7,4,31,7,7,38,1,2,0,1,35,22,3,1,35,4,0,45,1,11,0,4,1,6,7,3,31,23,7,38,1,2,0,1,11,22,3,1,11,4,0,45,1,11,0,4,1,32,7,38,1,2,0,6,11,1,35,10,11,1,35,6,11,4,0,45,1,3,0,1,16,7,0,4,1,32,7,2,0,11,11,1,35,10,11,2,0,7,11,1,35,7,11,2,27,5,3,3,27,1,11,2,27,6,3,3,27,1,11,44,0,5,1,11,0,4,1,23,7,2,31,7,7,2,0,1,11,4,27,13,3,3,27,1,11,2,0,1,11,4,27,7,3,1,27,2,11,10,3,1,11,11,3,1,11,12,0,2,11,1,43,21,11,8,0,5,1,11,0,4,1,32,7,2,0,1,43,20,3,1,11,2,0,1,43,12,3,2,11,10,3,1,11,11,3,1,11,12,0,1,11,3,27,6,3,1,27,1,11,3,27,7,3,1,27,1,11,8,0,5,1,11,0,4,1,32,7,2,0,1,11,20,3,1,11,2,0,1,11,12,3,2,11,8,3,2,27,1,11,9,3,2,27,1,11,12,0,1,11,10,3,1,11,11,3,1,11,8,0,5,1,3,0,1,16,7,0,4,1,32,7,2,0,1,11,18,3,2,27,1,11,2,0,1,11,12,3,22,11,1,43,2,11,12,0,1,11,2,27,8,3,1,11,2,27,9,3,1,11,8,0,5,1,11,0,4,1,32,7,2,0,1,11,1,27,17,3,2,27,1,11,2,0,1,11,2,27,7,3,3,27,1,11,36,0,1,11,2,27,6,3,2,27,1,11,2,27,7,3,2,27,1,11,8,0,5,1,11,0,4,1,1,7,2,31,29,7,2,0,11,11,1,35,10,11,2,0,7,11,1,35,6,11,36,0,6,11,1,35,10,11,1,35,6,11,8,0,5,1,11,0,4,1,32,7,2,0,1,11,2,27,14,3,4,27,1,11,2,0,1,11,3,27,4,3,5,27,1,11,36,0,1,11,22,3,1,11,8,0,5,1,11,0,4,1,32,7,2,0,1,11,2,27,18,3,1,11,2,0,1,11,12,3,1,11,28,1,8,0,1,35,22,3,1,35,8,0,54,1,1,11,20,3,1,43,2,1,1,11,12,3,1,43,28,1,8,0,1,11,22,3,1,11,8,0,54,1,1,11,3,27,16,3,1,27,1,11,2,1,1,11,2,27,10,3,1,11,28,1,8,0,6,11,1,35,10,11,1,35,6,11,8,0,54,1,11,11,1,35,10,11,2,1,7,11,1,35,6,11,28,1,8,0,1,11,2,27,5,3,3,27,1,11,2,27,6,3,3,27,1,11,8,0,90,1,38,0,1,11,8,3,2,27,1,11,9,3,2,27,1,11,8,0,5,1,11,0,4,1,32,7,34,0,4,1,38,0,1,11,1,27,7,3,2,27,1,11,1,27,8,3,2,27,1,11,8,0,5,1,11,0,4,1,32,7,34,0,4,1,38,0,21,11,1,43,2,11,8,0,5,1,11,0,4,1,32,7,34,0,4,1,70,0,5,1,11,0,4,1,66,0,4,1,70,0,5,1,81,0,4,1,70,0,5,1,81,0,4,1,30,0],
	[180,0,16,4,80,20,100,4,80,20,100,4,80,20,84,4,16,0,82,2,42,0,4,1,52,0,82,2,42,0,4,1,52,0,82,2,42,0,4,1,52,0,82,2,42,0,4,1,52,0,82,2,42,0,4,1,52,0,82,2,42,0,4,1,70,0,3,24,39,0,6,1,28,0,4,1,26,0,4,1,54,0,1,16,15,0,3,24,6,0,2,24,31,0,6,1,28,0,4,1,26,0,4,1,112,0,6,1,28,0,4,1,26,0,4,1,48,0,2,11,1,43,15,11,5,0,7,11,1,35,6,11,27,0,6,1,28,0,4,1,26,0,4,1,48,0,1,11,16,3,1,11,5,0,1,11,12,3,1,11,6,0,4,24,17,0,6,1,2,0,4,24,22,0,4,1,26,0,4,1,48,0,1,11,16,3,1,11,5,0,1,43,12,3,1,11,6,0,4,24,17,0,6,1,2,0,4,24,22,0,2,1,7,11,1,35,6,11,4,0,7,11,1,35,6,11,2,0,5,11,1,35,4,11,36,0,1,11,16,3,1,11,5,0,1,11,12,3,1,11,27,0,6,1,28,0,2,1,1,11,11,3,1,27,1,11,4,0,1,11,3,27,7,3,2,27,1,11,2,0,1,11,3,27,4,3,1,27,1,11,6,0,6,11,1,35,5,11,18,0,1,11,16,3,1,11,5,0,1,11,12,3,1,11,19,0,3,24,5,0,6,1,28,0,2,1,1,43,12,3,1,11,4,0,1,43,12,3,1,11,2,0,1,43,8,3,1,11,6,0,1,11,2,27,5,3,3,27,1,11,18,0,9,11,1,35,8,11,5,0,1,11,12,3,1,11,19,0,3,24,5,0,6,1,28,0,2,1,1,11,12,3,1,11,4,0,1,11,12,3,1,11,2,0,1,11,8,3,1,11,6,0,1,43,10,3,1,11,18,0,1,11,16,3,1,11,5,0,7,11,1,35,6,11,27,0,6,1,28,0,2,1,1,11,12,3,1,11,4,0,1,11,2,27,8,3,2,27,1,11,2,0,1,11,8,3,1,11,6,0,1,11,8,3,2,27,1,11,18,0,1,35,16,3,1,35,5,0,1,11,12,3,1,11,27,0,6,1,28,0,2,1,1,11,9,3,3,27,1,11,4,0,7,11,1,35,6,11,2,0,1,11,2,27,6,3,1,43,6,0,1,11,1,27,7,3,2,27,1,11,18,0,1,11,16,3,1,11,5,0,1,11,12,3,1,11,27,0,6,1,28,0,2,1,7,11,1,35,6,11,4,0,1,11,2,27,7,3,3,27,1,11,2,0,1,11,2,27,4,3,2,27,1,11,6,0,6,11,1,35,5,11,18,0,9,11,1,35,8,11,5,0,1,11,12,3,1,43,27,0,6,1,28,0,2,1,1,11,7,3,5,27,1,11,4,0,1,11,12,3,1,43,2,0,5,11,1,35,4,11,6,0,1,11,3,27,6,3,1,27,1,11,18,0,1,11,16,3,1,11,5,0,1,11,12,3,1,11,27,0,6,1,28,0,2,1,1,11,12,3,1,11,4,0,1,11,2,27,8,3,2,27,1,11,18,0,1,11,2,27,8,3,1,43,18,0,1,11,16,3,1,11,5,0,7,11,1,35,6,11,1,0,12,11,1,35,11,11,2,0,6,1,1,0,12,11,1,35,11,11,3,0,2,1,1,11,12,3,1,43,4,0,7,11,1,35,6,11,18,0,1,11,2,27,6,3,2,27,1,11,18,0,1,11,16,3,1,11,20,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,2,1,1,11,12,3,1,11,14,0,4,1,18,0,6,11,1,35,5,11,18,0,15,11,1,43,2,11,20,0,1,43,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,43,9,3,1,11,3,3,1,11,8,3,1,11,3,0,2,1,7,11,1,35,6,11,14,0,4,1,86,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,4,1,26,0,4,1,44,0,40,7,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,70,7,8,0,40,7,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,70,7,8,0,40,7,2,0,1,11,9,3,1,35,3,3,1,35,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,35,3,3,1,35,8,3,1,11,3,0,70,7,8,0,40,7,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,70,7,8,0,40,7,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,4,1,26,0,4,1,30,0,4,1,10,0,40,7,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,2,1,8,11,1,35,7,11,12,0,4,1,3,0,1,16,26,0,4,1,10,0,4,1,32,0,4,1,2,0,1,11,1,27,6,3,2,27,1,11,3,3,1,11,2,27,5,3,1,27,1,11,2,0,6,1,1,0,1,11,1,27,6,3,2,27,1,11,3,3,1,11,2,27,5,3,1,27,1,11,3,0,2,1,1,11,4,27,9,3,1,27,1,11,12,0,4,1,30,0,4,1,10,0,4,1,32,0,4,1,2,0,11,11,3,3,10,11,2,0,6,1,1,0,11,11,3,3,10,11,3,0,2,1,1,43,14,3,1,11,12,0,4,1,29,0,1,16,4,1,10,0,4,1,32,0,4,1,2,0,1,11,2,27,5,3,2,27,1,11,3,3,1,11,2,27,4,3,2,27,1,11,2,0,6,1,1,0,1,11,2,27,5,3,2,27,1,11,3,3,1,11,2,27,4,3,2,27,1,11,3,0,2,1,1,11,14,3,1,11,12,0,4,1,30,0,4,1,10,0,4,1,27,0,4,11,1,35,3,11,1,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,2,1,1,11,14,3,1,11,12,0,4,1,3,0,1,16,26,0,4,1,10,0,4,1,2,11,1,43,21,11,3,7,1,11,2,27,2,3,2,27,1,11,1,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,24,6,25,1,24,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,2,1,1,11,2,27,9,3,3,27,1,11,12,0,4,1,30,0,4,1,7,0,1,16,2,0,4,1,1,11,3,27,5,3,2,27,1,11,3,27,6,3,2,27,1,11,3,7,1,43,6,3,1,11,1,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,24,6,25,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,2,1,8,11,1,35,7,11,12,0,4,1,29,0,1,16,4,1,10,0,4,1,1,11,3,27,5,3,2,27,1,11,3,27,6,3,2,27,1,11,3,7,1,11,6,3,1,11,1,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,2,1,1,11,7,27,6,3,1,27,1,11,12,0,4,1,30,0,4,1,10,0,4,1,1,11,8,3,2,27,1,11,9,3,2,27,1,11,3,7,1,11,6,3,1,11,1,1,2,0,1,11,9,3,1,35,3,3,1,35,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,35,3,3,1,35,8,3,1,11,3,0,2,1,1,11,14,3,1,11,12,0,3,1,1,25,3,24,1,16,26,0,4,1,10,0,4,1,1,11,2,27,6,3,2,27,1,11,2,27,7,3,2,27,1,11,3,7,1,11,6,3,1,43,1,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,2,1,1,11,14,3,1,43,12,0,3,1,1,25,3,24,27,0,4,1,7,0,1,16,2,0,4,1,6,11,1,35,10,11,1,35,6,11,3,7,1,11,1,27,3,3,2,27,1,11,1,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,2,1,1,11,2,27,12,3,1,11,12,0,4,1,29,0,1,16,4,1,10,0,4,1,1,11,22,3,1,11,3,7,4,11,1,35,3,11,1,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,2,1,8,11,1,35,7,11,46,5,4,1,10,0,4,1,1,35,22,3,1,35,8,7,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,4,1,2,0,31,5,1,21,26,5,4,1,10,0,4,1,1,11,22,3,1,11,3,7,2,31,3,7,4,1,2,0,1,11,1,27,6,3,2,27,1,11,3,3,1,11,2,27,5,3,1,27,1,11,2,0,6,1,1,0,1,11,1,27,6,3,2,27,1,11,3,3,1,11,2,27,5,3,1,27,1,11,3,0,4,1,2,0,58,5,4,1,7,0,1,16,2,0,4,1,6,11,1,35,10,11,1,35,6,11,2,31,1,7,2,31,3,7,4,1,2,0,11,11,3,3,10,11,2,0,6,1,1,0,11,11,3,3,10,11,3,0,4,1,2,0,57,5,1,21,4,1,10,0,4,1,1,11,5,27,3,3,2,27,1,11,5,27,4,3,2,27,1,11,8,7,6,1,1,11,2,27,5,3,2,27,1,11,3,3,1,11,2,27,4,3,2,27,1,11,2,0,6,1,1,0,1,11,2,27,5,3,2,27,1,11,3,3,1,11,2,27,4,3,2,27,1,11,3,0,6,1,6,5,4,29,48,5,6,1,8,0,4,1,1,11,5,27,3,3,2,27,1,11,5,27,4,3,2,27,1,11,8,7,6,1,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,6,1,6,5,4,29,21,5,1,21,13,5,4,29,9,5,6,1,8,0,4,1,1,11,8,3,2,27,1,11,2,27,8,3,1,1,1,9,38,1,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,6,1,45,5,4,29,9,5,6,1,5,0,1,16,2,0,4,1,21,11,1,43,2,9,38,1,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,6,1,57,5,1,21,6,1,8,0,4,1,18,0,4,7,40,1,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,6,1,58,5,6,1,8,0,4,1,18,0,4,7,40,1,2,0,6,1,1,0,1,11,9,3,1,35,3,3,1,35,8,3,1,11,3,0,6,1,31,5,1,21,26,5,6,1,8,0,4,1,11,11,1,35,10,11,2,7,2,31,6,7,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,4,1,2,0,58,5,4,1,7,0,1,16,2,0,4,1,1,11,3,27,16,3,1,27,1,11,2,7,2,31,6,7,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,4,1,2,0,57,5,1,21,4,1,10,0,4,1,1,43,20,3,1,11,10,7,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,4,1,2,0,58,5,4,1,10,0,4,1,1,11,20,3,1,11,5,7,4,11,1,35,3,11,1,1,2,0,1,11,1,27,6,3,2,27,1,11,3,3,1,11,2,27,5,3,1,27,1,11,2,0,6,1,1,0,1,11,1,27,6,3,2,27,1,11,3,3,1,11,2,27,5,3,1,27,1,11,3,0,4,1,2,0,31,5,1,21,26,5,4,1,10,0,4,1,1,11,2,27,18,3,1,11,5,0,1,11,2,27,2,3,2,27,1,11,1,1,2,0,11,11,3,3,10,11,2,0,6,1,1,0,11,11,3,3,10,11,3,0,4,1,2,0,58,5,4,1,7,0,1,16,2,0,4,1,1,11,2,27,16,3,2,27,1,11,5,0,1,43,6,3,1,11,1,1,2,0,1,11,2,27,5,3,2,27,1,11,3,3,1,11,2,27,4,3,2,27,1,11,2,0,6,1,1,0,1,11,2,27,5,3,2,27,1,11,3,3,1,11,2,27,4,3,2,27,1,11,3,0,4,1,2,0,18,5,4,29,35,5,1,21,4,1,10,0,4,1,11,11,1,35,10,11,5,0,1,11,6,3,1,11,1,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,4,1,2,0,18,5,4,29,15,5,9,11,1,35,8,11,3,5,4,1,10,0,4,1,1,11,2,27,15,3,3,27,1,11,5,0,1,11,6,3,1,11,1,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,4,1,2,0,37,5,1,11,1,27,12,3,3,27,1,11,3,5,4,1,10,0,4,1,1,11,20,3,1,11,5,0,1,11,6,3,1,43,1,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,4,1,2,0,37,5,1,43,16,3,1,11,3,5,4,1,7,0,1,16,2,0,4,1,1,11,18,3,2,27,1,43,5,0,1,11,2,27,3,3,1,27,1,11,1,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,4,1,2,0,37,5,1,11,16,3,1,11,2,5,1,21,4,1,10,0,4,1,1,11,1,27,17,3,2,27,1,11,5,0,4,11,1,35,3,11,1,1,2,0,1,11,9,3,1,35,3,3,1,35,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,35,3,3,1,35,8,3,1,11,3,0,4,1,2,0,37,5,1,11,16,3,1,11,3,5,4,1,10,0,4,1,11,11,1,35,10,11,10,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,4,1,2,0,37,5,1,11,1,27,12,3,3,27,1,11,3,5,4,1,2,0,48,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,24,6,25,1,24,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,4,1,2,0,37,5,9,11,1,35,8,11,3,5,4,1,2,0,48,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,24,6,25,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,4,1,2,0,37,5,1,11,3,27,12,3,1,27,1,11,2,5,1,21,4,1,2,0,48,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,4,1,2,0,37,5,1,11,16,3,1,11,3,5,4,1,2,0,48,1,2,0,1,11,1,27,6,3,2,27,1,11,3,3,1,11,2,27,5,3,1,27,1,11,2,0,6,1,1,0,1,11,1,27,6,3,2,27,1,11,3,3,1,11,2,27,5,3,1,27,1,11,3,0,4,1,2,0,37,5,1,11,16,3,1,43,3,5,4,1,10,0,4,1,32,0,4,1,2,0,11,11,3,3,10,11,2,0,6,1,1,0,11,11,3,3,10,11,3,0,43,1,1,11,3,27,12,3,1,27,1,11,7,1,7,0,1,16,2,0,4,1,32,0,4,1,2,0,1,11,2,27,5,3,2,27,1,11,3,3,1,11,2,27,4,3,2,27,1,11,2,0,6,1,1,0,1,11,2,27,5,3,2,27,1,11,3,3,1,11,2,27,4,3,2,27,1,11,3,0,43,1,9,11,1,35,8,11,7,1,10,0,4,1,2,11,1,43,23,11,6,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,68,1,10,0,4,1,1,11,4,27,5,3,2,27,1,11,4,27,6,3,2,27,1,11,6,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,68,1,10,0,4,1,1,11,11,3,1,11,12,3,1,11,6,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,4,1,26,0,4,1,30,0,4,1,7,0,1,16,2,0,4,1,1,11,11,3,1,11,12,3,1,11,6,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,4,1,26,0,4,1,29,0,1,16,4,1,10,0,4,1,1,11,11,3,1,11,12,3,1,11,6,0,4,1,2,0,1,11,9,3,1,35,3,3,1,35,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,35,3,3,1,35,8,3,1,11,3,0,2,11,1,43,19,11,2,0,9,11,1,35,8,11,22,0,4,1,10,0,4,1,1,11,11,3,1,11,12,3,1,11,6,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,1,11,2,27,16,3,2,27,1,11,2,0,1,11,2,27,12,3,2,27,1,11,22,0,4,1,10,0,4,1,1,11,11,3,1,11,12,3,1,11,6,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,1,11,20,3,1,11,2,0,1,43,16,3,1,11,22,0,4,1,7,0,1,16,2,0,4,1,1,11,3,27,6,3,2,27,1,11,3,27,7,3,2,27,1,11,6,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,1,11,20,3,1,11,2,0,1,11,16,3,1,11,21,0,1,16,4,1,10,0,4,1,6,11,1,35,12,11,1,35,6,11,6,0,4,1,2,0,1,11,1,27,6,3,2,27,1,11,3,3,1,11,2,27,5,3,1,27,1,11,2,0,6,1,1,0,1,11,1,27,6,3,2,27,1,11,3,3,1,11,2,27,5,3,1,27,1,11,3,0,1,11,1,27,17,3,2,27,1,11,2,0,1,11,16,3,1,11,22,0,4,1,10,0,4,1,1,11,24,3,1,11,6,0,4,1,2,0,11,11,3,3,10,11,2,0,6,1,1,0,11,11,3,3,10,11,3,0,11,11,1,35,10,11,2,0,1,11,2,27,13,3,1,27,1,11,22,0,4,1,10,0,4,1,1,35,24,3,1,35,6,0,4,1,2,0,1,11,2,27,5,3,2,27,1,11,3,3,1,11,2,27,4,3,2,27,1,11,2,0,6,1,1,0,1,11,2,27,5,3,2,27,1,11,3,3,1,11,2,27,4,3,2,27,1,11,3,0,1,11,20,3,1,11,2,0,9,11,1,35,8,11,22,0,4,1,7,0,1,16,2,0,4,1,1,11,24,3,1,11,6,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,1,35,20,3,1,35,2,0,1,11,4,27,11,3,1,27,1,11,21,0,1,16,4,1,10,0,4,1,6,11,1,35,12,11,1,35,6,11,6,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,1,11,20,3,1,11,2,0,1,11,16,3,1,11,22,0,4,1,10,0,4,1,1,11,2,27,5,3,4,27,1,11,2,27,6,3,4,27,1,11,6,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,11,11,1,35,10,11,2,0,1,11,16,3,1,43,2,0,9,11,1,35,8,11,2,0,4,1,10,0,4,1,1,11,11,3,1,11,12,3,1,11,6,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,1,11,2,27,16,3,2,27,1,11,2,0,1,11,2,27,14,3,1,11,2,0,1,11,2,27,12,3,2,27,1,11,2,0,4,1,7,0,1,16,2,0,4,1,1,11,11,3,1,11,12,3,1,11,6,0,4,1,2,0,1,11,9,3,1,35,3,3,1,35,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,35,3,3,1,35,8,3,1,11,3,0,1,11,20,3,1,11,2,0,9,11,1,35,8,11,2,0,1,43,16,3,1,11,1,0,1,16,4,1,10,0,4,1,1,11,11,3,1,11,12,3,1,11,6,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,1,11,2,27,17,3,1,27,1,11,22,0,1,11,16,3,1,11,2,0,4,1,10,0,4,1,1,11,11,3,1,11,12,3,1,11,6,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,19,11,1,43,2,11,22,0,1,11,16,3,1,11,2,0,4,1,10,0,4,1,1,11,2,27,6,3,3,27,1,11,2,27,7,3,3,27,1,11,6,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,11,3,0,4,1,40,0,1,11,2,27,13,3,1,27,1,11,2,0,4,1,7,0,1,16,2,0,4,1,23,11,1,43,2,11,6,0,4,1,2,0,1,11,9,3,1,11,3,3,1,11,8,3,1,43,2,0,6,1,1,0,1,11,9,3,1,11,3,3,1,11,8,3,1,43,3,0,4,1,40,0,9,11,1,35,8,11,1,0,1,16,4,1,10,0,4,1,32,0,4,1,2,0,1,11,1,27,6,3,2,27,1,11,3,3,1,11,2,27,5,3,1,27,1,11,2,0,6,1,1,0,1,11,1,27,6,3,2,27,1,11,3,3,1,11,2,27,5,3,1,27,1,11,3,0,4,1,40,0,1,11,4,27,11,3,1,27,1,11,2,0,4,1,10,0,4,1,32,0,4,1,2,0,12,11,1,35,11,11,2,0,6,1,1,0,12,11,1,35,11,11,3,0,4,1,40,0,1,11,16,3,1,11,2,0,4,1,10,0,4,1,32,0,4,1,28,0,6,1,28,0,4,1,40,0,1,11,16,3,1,43,2,0,4,1,7,0,1,16,2,0,4,1,32,0,4,1,28,0,6,1,28,0,4,1,40,0,1,11,2,27,14,3,1,11,2,0,4,1,2,0,154,1,9,11,1,35,8,11,548,1,76,0,6,1,174,0,6,1,174,0,6,1,174,0,6,1,174,0,6,1,98,0],
	[150,0,16,4,80,20,70,4,80,20,70,4,80,20,54,4,16,0,82,2,68,0,82,2,68,0,82,2,68,0,82,2,68,0,82,2,68,0,82,2,104,0,2,11,1,43,33,11,80,0,1,16,6,0,1,16,6,0,1,16,5,0,2,24,6,0,1,16,5,0,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,1,16,6,0,1,16,6,0,1,16,6,0,1,16,6,0,1,16,6,0,1,16,65,0,1,16,6,0,3,24,3,0,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,108,0,3,24,3,0,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,68,0,9,11,1,35,8,11,5,0,8,11,1,35,7,11,7,0,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,4,0,8,11,1,35,7,11,4,0,7,11,1,35,6,11,30,0,1,11,16,3,1,11,5,0,1,11,14,3,1,11,7,0,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,4,0,1,11,14,3,1,11,4,0,1,11,10,3,2,27,1,11,30,0,1,43,16,3,1,11,5,0,1,43,14,3,1,11,7,0,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,4,0,1,43,14,3,1,11,4,0,1,43,12,3,1,11,30,0,1,11,16,3,1,11,5,0,1,11,14,3,1,11,7,0,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,4,0,1,11,14,3,1,11,4,0,1,11,12,3,1,11,30,0,1,11,16,3,1,11,5,0,1,11,14,3,1,11,7,0,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,4,0,1,11,14,3,1,11,4,0,1,11,10,3,2,27,1,11,30,0,1,11,16,3,1,11,5,0,1,11,14,3,1,11,7,0,4,11,1,35,6,11,1,35,6,11,1,35,6,11,1,35,6,11,1,35,3,11,4,0,1,11,14,3,1,11,4,0,7,11,1,35,6,11,30,0,9,11,1,35,8,11,5,0,8,11,1,35,7,11,7,0,1,11,34,3,1,11,4,0,8,11,1,35,7,11,4,0,1,11,11,3,1,27,1,11,30,0,1,11,16,3,1,11,5,0,1,11,14,3,1,11,7,0,1,35,34,3,1,35,4,0,1,11,14,3,1,11,4,0,1,11,10,3,2,27,1,43,30,0,1,11,16,3,1,11,5,0,1,11,14,3,1,11,7,0,1,11,34,3,1,11,4,0,1,11,14,3,1,11,4,0,1,11,10,3,2,27,1,11,30,0,1,11,16,3,1,43,5,0,1,11,14,3,1,43,7,0,4,11,1,35,6,11,1,35,6,11,1,35,6,11,1,35,6,11,1,35,3,11,4,0,1,11,14,3,1,43,4,0,7,11,1,35,6,11,30,0,1,11,16,3,1,11,5,0,1,11,14,3,1,11,7,0,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,4,0,1,11,14,3,1,11,48,0,9,11,1,35,8,11,5,0,8,11,1,35,7,11,1,0,6,24,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,4,0,8,11,1,35,7,11,94,0,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,114,0,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,92,0,5,1,17,0,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,18,0,44,1,3,0,1,16,26,0,5,1,17,0,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,6,3,1,11,18,0,44,1,6,0,6,24,4,0,6,24,8,0,5,1,1,0,6,24,10,0,1,11,1,27,3,3,2,27,1,11,1,27,3,3,2,27,1,11,1,27,3,3,2,27,1,11,1,27,3,3,2,27,1,11,1,27,3,3,2,27,1,11,4,0,6,24,8,0,44,1,30,0,5,1,17,0,18,11,1,35,14,11,1,43,2,11,18,0,2,1,4,25,38,1,30,0,5,1,71,0,2,1,4,25,144,1,44,0,106,1,40,0,1,16,3,0,106,1,44,0,106,1,3,0,2,24,7,0,2,24,5,0,2,24,23,0,106,1,19,0,2,24,1,0,1,24,21,0,106,1,40,0,1,16,25,0,4,1,4,0,5,1,13,0,4,1,4,0,29,7,5,1,10,0,6,1,66,0,4,1,4,0,5,1,13,0,4,1,4,0,29,7,5,1,10,0,6,1,2,0,2,11,1,43,4,35,5,11,4,35,4,11,25,0,1,16,18,0,4,1,4,0,5,1,13,0,4,1,4,0,29,7,5,1,10,0,6,1,2,0,1,11,2,27,6,3,1,11,2,27,4,3,3,27,1,11,44,0,4,1,4,0,5,1,5,0,6,11,1,35,5,11,4,0,29,7,5,1,10,0,6,1,2,0,1,11,2,27,6,3,1,11,2,27,7,3,1,11,18,0,1,16,9,0,6,11,1,35,5,11,4,0,4,1,4,0,5,1,5,0,1,11,3,27,5,3,2,27,1,11,4,0,1,7,1,23,27,7,5,1,10,0,6,1,2,0,1,11,8,3,1,11,9,3,1,11,2,0,7,11,1,35,6,11,12,0,1,11,1,27,6,3,3,27,1,11,4,0,4,1,4,0,5,1,5,0,1,43,10,3,1,11,4,0,29,7,5,1,10,0,6,1,2,0,1,11,3,27,5,3,1,11,9,3,1,11,2,0,1,11,2,27,8,3,2,27,1,11,9,0,1,16,2,0,1,43,10,3,1,11,4,0,4,1,4,0,5,1,5,0,1,11,10,3,1,11,4,0,29,7,5,1,10,0,6,1,2,0,1,11,3,27,3,3,2,27,1,11,3,27,4,3,2,27,1,11,2,0,1,43,2,27,10,3,1,11,12,0,1,11,10,3,1,11,4,0,4,1,4,0,5,1,5,0,1,11,2,27,6,3,2,27,1,11,4,0,29,7,5,1,10,0,6,1,2,0,5,11,1,35,8,11,1,35,5,11,2,0,1,11,12,3,1,11,2,0,1,16,9,0,1,11,1,27,6,3,3,27,1,11,4,0,4,1,4,0,5,1,5,0,6,11,1,35,5,11,4,0,1,7,1,23,27,7,5,1,10,0,6,1,2,0,1,11,18,3,1,11,2,0,1,11,1,27,9,3,2,27,1,11,12,0,6,11,1,35,5,11,4,0,4,1,4,0,5,1,5,0,1,11,2,27,5,3,3,27,1,11,4,0,29,7,5,1,10,0,6,1,2,0,1,35,18,3,1,35,2,0,7,11,1,35,6,11,9,0,1,16,2,0,1,11,3,27,6,3,1,27,1,11,4,0,4,1,4,0,5,1,5,0,1,11,10,3,1,43,4,0,29,7,5,1,4,0,2,24,4,0,6,1,2,0,1,11,18,3,1,11,2,0,1,11,2,27,9,3,1,27,1,11,12,0,1,11,10,3,1,43,4,0,4,1,4,0,5,1,5,0,1,11,2,27,6,3,2,27,1,11,4,0,29,7,4,1,1,25,1,24,3,0,2,24,4,0,6,1,2,0,5,11,1,35,8,11,1,35,5,11,2,0,1,11,10,3,2,27,1,43,2,0,1,16,9,0,1,11,3,27,6,3,1,27,1,11,4,0,4,1,4,0,5,1,5,0,6,11,1,35,5,11,4,0,1,7,1,23,27,7,5,1,10,0,6,1,2,0,1,11,2,27,3,3,3,27,1,11,2,27,4,3,3,27,1,11,2,0,1,11,2,27,8,3,2,27,1,11,12,0,6,11,1,35,5,11,4,0,4,1,4,0,5,1,13,0,4,1,4,0,29,7,5,1,6,0,2,24,2,0,6,1,2,0,1,11,8,3,1,11,9,3,1,11,2,0,7,11,1,35,6,11,9,0,1,16,18,0,4,1,4,0,24,1,2,0,29,7,5,1,10,0,6,1,2,0,1,11,6,3,2,27,1,11,2,27,7,3,1,11,44,0,4,1,4,0,24,1,2,0,29,7,3,1,5,11,1,35,4,11,2,0,6,1,2,0,1,11,6,3,2,27,1,11,2,27,4,3,3,27,1,11,18,0,1,16,25,0,4,1,4,0,24,1,2,0,1,7,1,23,27,7,3,1,1,11,2,27,5,3,1,27,1,11,2,0,6,1,2,0,3,11,4,35,5,11,4,35,1,11,1,43,2,11,30,0,7,11,1,35,6,11,4,1,4,0,24,1,2,0,29,7,3,1,1,43,8,3,1,11,2,0,6,1,47,0,1,16,4,0,1,11,2,27,8,3,2,27,1,11,4,1,4,0,5,1,13,0,4,1,4,0,29,7,3,1,1,11,8,3,1,11,2,0,50,1,8,0,1,43,2,27,10,3,1,11,4,1,4,0,5,1,13,0,4,1,4,0,29,7,3,1,1,11,8,3,1,11,2,0,30,1,3,25,4,1,2,25,11,1,8,0,1,11,12,3,1,11,4,1,4,0,5,1,13,0,4,1,4,0,29,7,3,1,1,11,6,3,2,27,1,43,2,0,30,1,3,25,9,1,2,25,6,1,8,0,1,11,12,3,1,11,4,1,4,0,5,1,13,0,4,1,4,0,29,7,3,1,1,11,2,27,4,3,2,27,1,11,2,0,50,1,3,0,1,16,4,0,1,11,1,27,9,3,2,27,1,11,4,1,4,0,58,1,5,11,1,35,4,11,8,1,12,0,4,1,4,0,6,24,4,0,6,24,16,0,7,11,1,35,6,11,4,1,4,0,76,1,12,0,4,1,24,0,1,16,11,0,1,11,2,27,9,3,1,27,1,11,4,1,4,0,76,1,12,0,4,1,36,0,1,11,12,3,1,11,4,1,4,0,64,1,3,25,9,1,12,0,4,1,31,0,1,16,4,0,1,11,10,3,2,27,1,43,4,1,4,0,5,1,13,0,4,1,1,0,2,11,1,43,19,11,10,0,5,1,4,0,3,24,3,0,6,1,12,0,4,1,4,0,2,11,1,43,17,11,12,0,1,11,2,27,8,3,2,27,1,11,4,1,4,0,5,1,13,0,4,1,1,0,1,11,2,27,5,3,2,27,1,11,2,27,6,3,2,27,1,11,10,0,5,1,10,0,6,1,12,0,4,1,4,0,1,11,2,27,4,3,2,27,1,11,2,27,5,3,2,27,1,11,1,16,11,0,7,11,1,35,6,11,4,1,4,0,5,1,13,0,4,1,1,0,1,11,9,3,1,11,10,3,1,11,3,0,8,11,1,35,7,11,6,0,6,1,12,0,4,1,4,0,1,11,2,27,6,3,1,11,2,27,7,3,1,11,26,0,4,1,4,0,5,1,13,0,4,1,1,0,1,11,9,3,1,11,10,3,1,11,3,0,1,11,3,27,7,3,4,27,1,11,6,0,6,1,12,0,4,1,4,0,1,11,8,3,1,11,9,3,1,11,4,0,3,5,1,21,25,5,1,0,5,1,13,0,4,1,1,0,1,11,1,27,6,3,2,27,1,11,1,27,7,3,2,27,1,11,3,0,1,43,14,3,1,11,6,0,6,1,12,0,4,1,4,0,1,11,8,3,1,11,9,3,1,11,4,0,29,5,1,0,5,1,13,0,4,1,1,0,5,11,1,35,10,11,1,35,5,11,3,0,1,11,14,3,1,11,6,0,6,1,12,0,4,1,4,0,1,11,8,3,1,11,9,3,1,11,1,16,3,0,29,5,1,0,5,1,13,0,4,1,1,0,1,11,20,3,1,11,3,0,1,11,14,3,1,11,6,0,6,1,12,0,4,1,4,0,1,11,8,3,1,11,9,3,1,11,4,0,29,5,1,0,5,1,13,0,4,1,1,0,1,35,20,3,1,35,3,0,1,11,1,27,11,3,2,27,1,11,6,0,6,1,12,0,4,1,4,0,1,11,1,27,5,3,2,27,1,11,1,27,6,3,2,27,1,11,8,0,2,11,1,43,19,11,4,0,5,1,1,0,8,11,1,35,7,11,1,0,1,11,20,3,1,11,3,0,8,11,1,35,7,11,6,0,6,1,12,0,4,1,4,0,5,11,1,35,8,11,1,35,5,11,8,0,1,11,2,27,16,3,2,27,1,11,4,0,5,1,1,0,1,11,2,27,9,3,3,27,1,11,1,0,5,11,1,35,10,11,1,35,5,11,3,0,1,11,4,27,8,3,2,27,1,11,6,0,6,1,12,0,4,1,4,0,1,11,18,3,1,11,1,16,7,0,1,11,20,3,1,11,4,0,5,1,1,0,1,43,14,3,1,11,1,0,1,11,2,27,5,3,2,27,1,11,2,27,6,3,2,27,1,11,3,0,1,11,14,3,1,11,6,0,6,1,12,0,4,1,4,0,1,35,18,3,1,35,8,0,1,11,20,3,1,11,4,0,5,1,1,0,1,11,14,3,1,11,1,0,1,11,9,3,1,11,10,3,1,11,3,0,1,11,14,3,1,43,6,0,6,1,12,0,4,1,4,0,1,11,18,3,1,11,8,0,1,11,3,27,17,3,1,11,4,0,5,1,1,0,1,11,12,3,2,27,1,11,1,0,1,11,2,27,6,3,1,27,1,11,2,27,7,3,1,27,1,11,3,0,1,11,3,27,10,3,1,27,1,11,6,0,6,1,12,0,4,1,4,0,5,11,1,35,8,11,1,35,5,11,8,0,11,11,1,35,10,11,4,0,5,1,1,0,1,11,1,27,11,3,2,27,1,11,1,0,19,11,1,43,2,11,3,0,8,11,1,35,7,11,6,0,6,1,12,0,4,1,4,0,1,11,2,27,5,3,1,27,1,11,2,27,6,3,1,27,1,11,1,16,7,0,1,11,20,3,1,11,4,0,5,1,1,0,8,11,1,35,7,11,48,0,6,1,12,0,4,1,4,0,1,11,8,3,1,11,9,3,1,11,8,0,1,35,20,3,1,35,4,0,5,1,1,0,1,11,3,27,10,3,1,27,1,11,48,0,6,1,12,0,4,1,4,0,1,11,8,3,1,11,9,3,1,11,8,0,1,11,20,3,1,11,4,0,5,1,1,0,1,11,14,3,1,11,48,0,6,1,12,0,4,1,4,0,1,11,8,3,1,11,9,3,1,11,8,0,11,11,1,35,10,11,4,0,5,1,1,0,1,11,2,27,12,3,1,43,48,0,6,1,12,0,4,1,4,0,1,11,6,3,2,27,1,11,7,3,2,27,1,11,1,16,7,0,1,11,2,27,15,3,3,27,1,11,4,0,5,1,1,0,1,11,2,27,10,3,2,27,1,11,48,0,6,1,12,0,4,1,4,0,1,11,2,27,4,3,2,27,1,11,2,27,5,3,2,27,1,11,8,0,1,11,20,3,1,11,4,0,5,1,1,0,8,11,1,35,7,11,48,0,6,1,12,0,4,1,4,0,17,11,1,43,2,11,8,0,1,11,18,3,2,27,1,11,4,0,5,1,13,0,4,1,48,0,6,1,12,0,4,1,32,0,19,11,1,43,2,11,4,0,76,1,12,0,4,1,8,0,6,24,44,0,76,1,12,0,4,1,58,0,76,1,12,0,4,1,58,0,76,1,12,0,4,1,28,0],
	[180,0,16,4,80,20,100,4,80,20,100,4,80,20,84,4,16,0,82,2,98,0,82,2,98,0,82,2,98,0,82,2,98,0,82,2,98,0,82,2,100,0,14,7,4,31,128,7,34,0,1,23,6,7,1,23,6,7,4,31,3,7,1,23,6,7,1,23,6,7,1,23,6,7,1,23,3,7,4,31,6,7,1,23,6,7,1,23,82,7,34,0,46,7,4,31,11,7,2,31,7,7,9,11,1,35,8,11,58,7,104,0,1,11,16,3,1,11,94,0,2,11,1,43,21,11,44,0,1,43,16,3,1,11,6,0,9,11,1,35,8,11,10,0,9,11,1,35,8,11,42,0,1,11,10,3,1,11,11,3,1,11,44,0,1,11,16,3,1,11,6,0,1,11,14,3,2,27,1,11,10,0,1,11,3,27,12,3,1,27,1,11,42,0,1,11,10,3,1,11,11,3,1,11,5,0,6,11,1,35,5,11,4,0,6,11,1,35,5,11,11,0,1,11,16,3,1,11,6,0,1,43,16,3,1,11,10,0,1,43,16,3,1,11,42,0,1,11,10,3,1,11,11,3,1,11,5,0,1,11,10,3,1,11,4,0,1,11,10,3,1,11,11,0,1,11,16,3,1,11,6,0,1,11,16,3,1,11,10,0,1,11,16,3,1,11,42,0,1,11,10,3,1,11,11,3,1,11,5,0,1,43,10,3,1,11,4,0,1,43,10,3,1,11,11,0,9,11,1,35,8,11,6,0,1,11,16,3,1,11,10,0,1,11,2,27,14,3,1,11,42,0,6,11,1,35,10,11,1,35,6,11,5,0,1,11,10,3,1,11,4,0,1,11,10,3,1,11,11,0,1,11,16,3,1,11,6,0,1,11,14,3,2,27,1,11,10,0,1,11,2,27,12,3,2,27,1,11,42,0,1,11,22,3,1,11,5,0,1,11,10,3,1,11,4,0,1,11,10,3,1,11,11,0,1,11,16,3,1,11,6,0,9,11,1,35,8,11,10,0,9,11,1,35,8,11,42,0,1,35,22,3,1,35,5,0,6,11,1,35,5,11,4,0,6,11,1,35,5,11,11,0,1,11,16,3,1,43,6,0,1,11,14,3,2,27,1,11,10,0,1,11,2,27,11,3,3,27,1,11,42,0,1,11,22,3,1,11,5,0,1,11,10,3,1,11,4,0,1,11,10,3,1,11,11,0,1,11,16,3,1,11,6,0,1,11,16,3,1,11,10,0,1,11,16,3,1,11,42,0,6,11,1,35,10,11,1,35,6,11,5,0,1,11,10,3,1,43,4,0,1,11,10,3,1,43,11,0,9,11,1,35,8,11,6,0,1,11,16,3,1,43,10,0,1,11,14,3,2,27,1,43,42,0,1,11,10,3,1,11,11,3,1,11,5,0,1,11,10,3,1,11,4,0,1,11,10,3,1,11,35,0,1,11,15,3,1,27,1,11,10,0,1,11,1,27,13,3,2,27,1,11,42,0,1,11,10,3,1,11,11,3,1,11,5,0,6,11,1,35,5,11,4,0,6,11,1,35,5,11,35,0,9,11,1,35,8,11,10,0,9,11,1,35,8,11,42,0,1,11,10,3,1,11,11,3,1,11,156,0,21,11,1,43,2,11,319,0,1,16,176,0,30,1,144,0,1,16,5,0,30,1,150,0,30,1,150,0,30,1,150,0,360,1,24,0,156,1,3,0,1,16,20,0,156,1,24,0,156,1,18,0,4,1,2,0,15,1,1,25,15,1,1,25,15,1,1,25,31,1,1,25,15,1,1,25,15,1,1,25,15,1,1,25,28,1,18,0,4,1,2,0,8,24,7,0,9,24,7,0,9,24,7,0,9,24,4,0,6,1,6,24,7,0,9,24,7,0,9,24,7,0,9,24,7,0,9,24,2,0,4,1,10,0,4,1,3,0,1,16,14,0,4,1,9,0,9,24,7,0,9,24,7,0,9,24,7,0,5,24,6,1,6,0,8,24,7,0,9,24,7,0,9,24,7,0,9,24,10,0,4,1,10,0,4,1,18,0,4,1,1,24,8,0,1,24,15,0,1,24,15,0,1,24,15,0,1,24,2,0,1,16,1,0,6,1,21,0,1,24,15,0,1,24,15,0,1,24,15,0,1,24,2,0,4,1,8,0,1,16,1,0,4,1,18,0,4,1,1,24,61,0,6,1,69,0,1,24,2,0,4,1,10,0,4,1,18,0,4,1,1,24,41,0,5,1,15,0,6,1,40,0,2,11,1,43,21,11,5,0,1,24,2,0,6,11,1,35,5,11,2,0,4,1,2,0,2,11,1,43,11,11,2,0,4,1,1,24,41,0,5,1,15,0,6,1,40,0,1,11,2,27,6,3,2,27,1,11,2,27,7,3,2,27,1,11,5,0,1,24,2,0,1,11,3,27,6,3,1,27,1,11,2,0,4,1,2,0,1,11,2,27,7,3,3,27,1,11,2,0,4,1,1,24,5,0,2,11,1,43,2,11,4,35,12,11,4,35,9,11,2,0,5,1,7,0,4,11,1,35,3,11,6,1,2,11,1,43,14,11,1,35,16,11,6,0,1,11,10,3,1,11,11,3,1,11,5,0,1,24,2,0,1,43,10,3,1,11,1,16,1,0,4,1,2,0,1,11,12,3,1,11,2,0,4,1,1,24,5,0,1,11,3,27,6,3,1,27,1,11,4,27,6,3,1,11,2,3,1,27,5,3,2,27,1,11,2,0,5,1,7,0,1,11,2,27,2,3,2,27,1,11,6,1,1,11,5,27,1,11,3,27,1,3,2,27,1,11,3,27,2,3,1,11,3,27,1,3,2,27,1,11,3,27,1,3,2,27,1,11,6,0,1,11,10,3,1,11,11,3,1,11,5,0,1,24,2,0,1,11,10,3,1,11,2,0,4,1,2,0,1,11,10,3,2,27,1,11,2,0,4,1,1,24,5,0,1,11,10,3,1,11,10,3,1,11,8,3,2,27,1,11,2,0,5,1,7,0,1,43,6,3,1,11,6,1,1,11,1,3,4,27,1,11,6,3,1,11,2,27,3,3,1,11,6,3,1,11,6,3,1,11,6,0,1,11,1,27,7,3,2,27,1,11,1,27,8,3,2,27,1,11,5,0,1,24,2,0,1,11,2,27,8,3,1,11,2,0,4,1,2,0,1,11,1,27,9,3,2,27,1,11,2,0,4,1,1,24,5,0,1,11,10,3,1,11,10,3,1,11,10,3,1,11,2,0,5,1,7,0,1,11,6,3,1,11,6,1,1,11,5,3,1,11,6,3,1,11,5,3,1,11,6,3,1,11,6,3,1,11,6,0,6,11,1,35,10,11,1,35,6,11,5,0,1,24,2,0,1,11,2,27,6,3,2,27,1,11,2,0,4,1,2,0,7,11,1,35,6,11,2,0,4,1,1,0,1,24,4,0,1,11,10,3,1,11,10,3,1,11,10,3,1,11,2,0,5,1,7,0,1,11,6,3,1,11,6,1,1,11,5,3,1,11,6,3,1,11,5,3,1,11,6,3,1,11,6,3,1,11,6,0,1,11,22,3,1,11,8,0,6,11,1,35,5,11,1,16,1,0,4,1,2,0,1,11,12,3,1,11,2,0,4,1,1,0,1,24,4,0,1,11,10,3,1,11,10,3,1,11,10,3,1,11,2,0,5,1,7,0,1,11,6,3,1,43,6,1,1,11,5,3,1,11,6,3,1,11,5,3,1,11,6,3,1,11,6,3,1,11,6,0,1,35,22,3,1,35,8,0,1,11,5,27,4,3,1,27,1,11,2,0,4,1,2,0,1,35,12,3,1,35,2,0,4,1,1,0,1,24,4,0,1,11,10,3,1,11,10,3,1,11,10,3,1,11,2,0,5,1,7,0,1,11,1,27,3,3,2,27,1,11,6,1,1,11,5,3,1,11,6,3,1,11,5,3,1,11,6,3,1,11,6,3,1,11,6,0,1,11,22,3,1,11,8,0,1,11,10,3,1,11,2,0,4,1,2,0,1,11,12,3,1,11,2,0,4,1,1,0,1,24,4,0,1,11,2,27,8,3,1,11,2,27,8,3,1,11,10,3,1,11,2,0,5,1,7,0,4,11,1,35,3,11,6,1,1,11,5,3,1,11,6,3,1,11,5,3,1,11,6,3,1,11,6,3,1,11,6,0,6,11,1,35,10,11,1,35,6,11,8,0,1,11,2,27,8,3,1,43,2,0,4,1,2,0,7,11,1,35,6,11,2,0,4,1,1,0,1,24,4,0,1,11,2,27,6,3,2,27,1,11,2,27,6,3,2,27,1,11,2,27,5,3,3,27,1,11,2,0,5,1,13,0,1,16,1,0,6,1,1,11,2,27,3,3,1,11,2,27,4,3,1,11,2,27,3,3,1,11,2,27,4,3,1,11,2,27,4,3,1,11,6,0,1,11,2,27,6,3,2,27,1,11,2,27,7,3,2,27,1,11,8,0,1,11,2,27,8,3,1,11,1,16,1,0,4,1,2,0,1,11,3,27,8,3,1,27,1,11,2,0,4,1,1,0,1,24,4,0,6,11,1,35,10,11,1,35,10,11,1,35,5,11,2,0,5,1,15,0,6,1,3,11,1,35,6,11,1,35,5,11,1,35,6,11,1,35,6,11,1,35,3,11,6,0,1,11,10,3,1,11,11,3,1,11,8,0,6,11,1,35,5,11,2,0,4,1,2,0,1,11,2,27,10,3,1,11,2,0,4,1,1,0,1,24,4,0,1,11,32,3,1,11,2,0,5,1,15,0,6,1,1,11,32,3,1,11,6,0,1,11,2,27,7,3,1,27,1,11,2,27,8,3,1,27,1,11,8,0,4,1,10,0,4,1,2,0,1,11,2,27,8,3,2,27,1,11,2,0,4,1,1,0,1,24,4,0,1,35,32,3,1,35,2,0,5,1,15,0,6,1,1,35,32,3,1,35,6,0,21,11,1,43,2,11,8,0,4,1,10,0,4,1,2,0,11,11,1,43,2,11,2,0,4,1,6,0,1,11,32,3,1,11,2,0,5,1,13,0,1,16,1,0,6,1,1,11,32,3,1,11,35,0,1,24,2,0,4,1,8,0,1,16,1,0,4,1,18,0,4,1,6,0,6,11,1,35,10,11,1,35,10,11,1,35,5,11,2,0,5,1,15,0,6,1,3,11,1,35,6,11,1,35,5,11,1,35,6,11,1,35,6,11,1,35,3,11,35,0,1,24,2,0,4,1,10,0,26,1,6,0,1,11,2,27,5,3,3,27,1,11,5,27,4,3,1,27,1,11,5,27,4,3,1,27,1,11,2,0,5,1,15,0,6,1,1,11,5,3,1,11,6,3,1,11,5,3,1,11,6,3,1,11,6,3,1,11,4,0,5,11,1,35,4,11,21,0,1,24,2,0,4,1,10,0,26,1,6,0,1,11,10,3,1,11,10,3,1,11,10,3,1,11,2,0,5,1,15,0,6,1,1,11,5,3,1,11,3,27,3,3,1,11,5,3,1,11,3,27,3,3,1,11,3,27,3,3,1,11,4,0,1,11,2,27,4,3,2,27,1,11,21,0,1,24,2,0,4,1,10,0,26,1,6,0,1,11,10,3,1,11,10,3,1,11,10,3,1,11,2,0,5,1,13,0,1,16,1,0,6,1,1,11,5,3,1,11,6,3,1,11,5,3,1,11,6,3,1,11,6,3,1,11,4,0,1,43,8,3,1,11,21,0,1,24,2,0,4,1,8,0,1,16,1,0,26,1,6,0,1,11,10,3,1,11,10,3,1,11,10,3,1,11,2,0,5,1,15,0,6,1,1,11,3,27,2,3,1,11,6,3,1,11,3,27,2,3,1,11,6,3,1,11,6,3,1,11,4,0,1,11,8,3,1,11,21,0,1,24,2,0,4,1,10,0,26,1,6,0,1,11,10,3,1,11,10,3,1,11,10,3,1,11,2,0,5,1,15,0,6,1,1,11,4,27,1,3,1,11,6,3,1,11,5,3,1,11,6,3,1,11,6,3,1,11,4,0,1,11,8,3,1,11,21,0,1,24,2,0,4,1,10,0,4,1,3,0,1,16,14,0,4,1,6,0,1,11,8,3,2,27,1,11,2,27,8,3,1,11,8,3,2,27,1,11,2,0,5,1,15,0,6,1,1,11,5,3,1,11,6,3,1,11,5,3,1,11,6,3,1,11,6,3,1,11,4,0,1,11,8,3,1,43,21,0,1,24,2,0,4,1,10,0,4,1,18,0,4,1,1,0,1,24,4,1,1,11,1,27,7,3,2,27,1,11,2,27,8,3,1,11,8,3,2,27,1,11,28,1,1,11,2,27,1,3,2,27,1,11,2,27,2,3,2,27,1,11,2,27,1,3,2,27,1,11,2,27,2,3,2,27,1,11,2,27,2,3,2,27,1,11,4,1,1,11,2,27,5,3,1,27,1,11,22,1,1,24,1,0,4,1,8,0,1,16,1,0,4,1,18,0,4,1,1,0,1,24,4,1,5,11,4,35,12,11,4,35,6,11,1,43,2,11,28,1,31,11,1,43,2,11,4,1,5,11,1,35,4,11,22,1,1,24,1,0,4,1,10,0,4,1,18,0,4,1,1,0,1,24,87,1,7,9,42,1,1,24,1,0,4,1,10,0,4,1,3,0,1,16,14,0,4,1,1,0,1,24,87,1,7,9,42,1,1,24,1,0,4,1,10,0,4,1,18,0,4,1,1,0,1,24,4,1,2,11,1,43,29,11,6,1,16,7,1,23,8,7,4,31,16,7,7,15,42,1,1,24,1,0,4,1,8,0,1,16,1,0,4,1,18,0,4,1,1,0,1,24,4,0,1,11,3,27,10,3,1,27,1,11,3,27,11,3,1,27,1,11,4,0,2,1,25,7,4,31,23,7,20,1,22,0,1,24,1,0,4,1,10,0,4,1,18,0,4,1,1,0,1,24,4,0,1,11,14,3,1,11,15,3,1,11,4,0,2,1,3,7,4,31,18,7,4,31,23,7,2,1,2,25,16,1,22,0,1,24,1,0,4,1,10,0,4,1,3,0,1,16,14,0,4,1,1,0,1,24,4,0,1,11,14,3,1,11,15,3,1,11,4,0,2,1,3,7,4,31,18,7,4,31,23,7,2,1,2,25,16,1,22,0,1,24,1,0,4,1,10,0,4,1,18,0,4,1,1,24,5,0,1,11,2,27,12,3,1,11,2,27,13,3,1,11,4,0,2,1,3,7,4,31,9,7,1,23,35,7,20,1,21,0,1,24,2,0,1,1,6,11,1,35,5,11,1,0,4,1,18,0,4,1,1,24,5,0,1,11,2,27,10,3,2,27,1,11,2,27,11,3,2,27,1,11,4,0,2,1,3,7,4,31,61,7,25,0,1,24,2,0,1,1,1,11,4,27,5,3,1,27,1,11,1,0,4,1,18,0,4,1,1,24,5,0,8,11,1,35,14,11,1,35,8,11,4,0,2,1,14,7,4,31,21,7,2,31,4,7,4,31,19,7,4,0,2,11,1,43,17,11,1,0,1,24,2,0,1,1,1,43,10,3,1,11,1,0,4,1,3,0,1,16,14,0,4,1,1,24,5,0,1,11,30,3,1,11,4,0,2,1,14,7,4,31,27,7,4,31,19,7,4,0,1,11,8,27,1,11,3,27,4,3,2,27,1,11,1,0,1,24,2,0,1,1,1,11,10,3,1,11,1,0,4,1,18,0,4,1,1,24,5,0,1,35,30,3,1,35,4,0,2,1,14,7,4,31,27,7,4,31,19,7,4,0,1,11,8,3,1,11,9,3,1,11,1,0,1,24,2,0,1,1,1,11,10,3,1,11,1,0,4,1,18,0,4,1,1,24,5,0,1,11,30,3,1,11,4,0,2,1,14,7,4,31,27,7,4,31,19,7,4,0,1,11,8,3,1,11,9,3,1,11,1,0,1,24,2,0,1,1,1,11,2,27,5,3,3,27,1,11,1,0,4,1,18,0,4,1,1,24,5,0,8,11,1,35,14,11,1,35,8,11,4,0,2,1,68,7,4,0,1,11,8,3,1,11,9,3,1,11,1,0,1,24,2,0,1,1,6,11,1,35,5,11,1,0,4,1,3,0,1,16,14,0,4,1,1,24,5,0,1,11,2,27,9,3,3,27,1,11,2,27,10,3,3,27,1,11,4,0,2,1,68,7,4,0,1,11,2,27,6,3,1,11,2,27,7,3,1,11,1,0,1,24,2,0,1,1,1,11,3,27,6,3,1,27,1,11,1,0,4,1,18,0,4,1,1,0,1,24,4,0,1,11,14,3,1,11,15,3,1,11,4,0,2,1,16,7,1,23,51,7,4,0,5,11,1,35,8,11,1,35,5,11,4,0,1,1,1,11,4,27,6,3,1,11,1,0,4,1,18,0,4,1,1,0,1,24,4,0,1,11,12,3,2,27,1,11,13,3,2,27,1,11,4,0,2,1,6,7,2,31,10,7,2,31,14,7,4,31,30,7,4,0,1,11,18,3,1,11,4,0,1,1,1,11,10,3,1,43,1,0,4,1,18,0,4,1,1,0,1,24,4,0,1,11,1,27,11,3,2,27,1,11,1,27,12,3,2,27,1,11,4,0,2,1,6,7,2,31,26,7,4,31,30,7,4,0,1,35,18,3,1,35,4,0,1,1,1,11,2,27,8,3,1,11,1,0,4,1,3,0,1,16,14,0,4,1,1,0,1,24,4,0,29,11,1,43,2,11,4,0,2,1,34,7,4,31,18,7,4,31,8,7,4,0,1,11,18,3,1,11,4,0,1,1,6,11,1,35,5,11,1,0,4,1,18,0,4,1,1,0,1,24,40,0,2,1,16,7,1,23,17,7,4,31,18,7,4,31,8,7,4,0,5,11,1,35,8,11,1,35,5,11,4,0,4,1,8,0,1,16,1,0,4,1,18,0,4,1,1,0,1,24,40,0,2,1,56,7,4,31,8,7,4,0,1,11,1,3,3,27,1,3,3,27,1,11,6,3,3,27,1,11,4,0,4,1,10,0,4,1,18,0,4,1,1,0,1,24,4,0,18,11,18,0,2,1,56,7,4,31,8,7,4,0,1,11,8,3,1,11,9,3,1,11,4,0,4,1,10,0,4,1,18,0,4,1,1,0,1,24,4,0,1,11,3,27,4,3,1,27,1,11,2,27,2,3,3,27,1,11,18,0,2,1,68,7,4,0,1,11,8,3,1,11,9,3,1,11,4,0,4,1,10,0,4,1,18,0,4,1,1,24,5,0,1,43,8,3,1,11,7,3,1,11,18,0,2,1,16,7,1,23,51,7,4,0,1,11,2,27,4,3,2,27,1,11,2,27,5,3,2,27,1,11,1,0,1,24,2,0,4,1,10,0,4,1,18,0,4,1,1,24,5,0,1,11,8,3,1,11,7,3,1,11,18,0,2,1,68,7,4,0,17,11,1,43,2,11,1,0,1,24,2,0,4,1,10,0,4,1,18,0,4,1,1,24,1,0,4,1,1,35,8,3,1,35,7,3,1,35,20,1,68,7,25,1,1,25,6,1,10,0,4,1,18,0,4,1,1,24,1,0,4,1,1,11,2,27,6,3,1,11,5,3,2,27,1,43,20,1,68,7,25,1,1,25,6,1,10,0,4,1,18,0,4,1,1,24,1,0,4,1,1,11,2,27,4,3,2,27,1,11,1,27,4,3,2,27,1,11,4,1,7,25,9,1,7,25,25,1,7,25,9,1,7,25,9,1,7,25,9,1,7,25,6,1,1,25,6,1,10,0,4,1,18,0,4,1,1,24,1,0,4,1,18,11,12,1,7,25,25,1,7,25,9,1,7,25,9,1,7,25,9,1,7,25,8,1,7,25,6,1,10,0,4,1,18,0,148,1,10,0,4,1,18,0,148,1,10,0,4,1,18,0,148,1,10,0,4,1,18,0,148,1,10,0,4,1]
]

const ORIGINAL_TREES: Array = [[[113,43],[113,47],[113,51],[113,55],[113,63],[113,67],[113,71],[113,75],[113,79],[113,87],[113,91],[113,95],[18,66],[18,70],[18,74],[18,78],[18,82],[18,86],[18,90],[18,94],[168,28],[168,32],[18,11],[25,11],[32,11],[39,11],[46,11],[53,11],[60,11],[67,11],[74,11],[81,11],[88,11],[95,11],[102,11],[109,11]],[[8,28],[8,40],[8,56],[8,60],[8,80],[159,33],[159,37],[159,45],[159,49],[159,53],[159,57],[159,61],[159,65],[87,45],[87,49],[87,53],[87,57],[87,61],[87,65],[87,69],[87,77],[87,81],[87,85],[18,11],[25,11],[32,11],[39,11],[46,11],[53,11],[60,11],[67,11],[74,11],[81,11],[88,11],[95,11],[102,11]],[[48,44],[48,48],[48,52],[48,56],[48,60],[48,64],[48,68],[48,72],[48,76],[48,80],[119,57],[119,61],[119,65],[119,69],[152,4],[152,8],[152,12],[152,28],[152,32],[152,40],[18,11],[25,11],[32,11],[39,11],[46,11],[53,11],[67,11],[74,11],[81,11],[88,11],[95,11],[102,11],[109,11],[116,11],[123,11],[130,11]],[[147,33],[147,37],[147,41],[147,45],[147,49],[147,53],[147,57],[173,35],[173,39],[173,43],[173,47],[173,51],[173,55],[173,59],[173,63],[173,67],[173,75],[173,79],[173,83],[173,87],[173,91],[5,39],[5,43],[5,47],[5,51],[5,55],[5,59],[5,63],[5,71],[5,75],[5,79],[5,83],[5,87],[5,91],[5,95],[18,11]],[[3,29],[3,41],[3,45],[3,49],[3,53],[3,57],[3,61],[3,65],[3,69],[146,34],[146,38],[146,42],[146,46],[146,50],[146,54],[146,62],[146,66],[146,70],[146,74],[146,78],[146,82],[57,43],[57,47],[57,51],[57,55],[18,11],[25,11],[32,11],[39,12],[46,11],[88,11],[95,11],[102,11],[109,11],[116,11],[123,11]],[[3,29],[3,37],[3,41],[3,65],[3,69],[3,73],[3,77],[3,81],[3,85],[174,30],[174,42],[174,46],[174,50],[174,54],[174,58],[174,62],[174,66],[174,70],[174,86],[82,42],[82,54],[82,58],[82,62],[82,70],[82,74],[82,82],[82,86],[82,90],[18,11],[25,11],[39,11],[46,11],[53,11],[60,11],[74,11],[81,11]]]


func test_entry_names_weights_and_first_entry() -> void:
	for n in range(1, 7):
		var d: Dictionary = load("res://game/world/maps/office_%02d.gd" % n).build()
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


# 조립 검증: 원 주문 69종과 KINDS 끝의 북쪽 확장 6종 후보를 사용한다.
const CONTAINER_SUFFIXES: Array[String] = [
	"상자", "보관함", "묶음", "선반", "자재함", "궤", "찬장", "공구함", "책상", "침대", "옷장",
]
const ASSEMBLY_BAND_COVER: Array = [[4, 5], [4, 5], [4, 5], [5, 5], [3, 5], [3, 5]]
# 가구 사이에 원래 비어 있던 폭 1칸 길. 좌표 순서는 x, 층, y.
const ASSEMBLY_CLEAR_AISLES: Array = [[[83,1,13]],[],[[23,1,14]],[],[],[[66,0,64],[67,0,64],[81,1,19]]]


## 소품 자신이 만든 WALL과 원래 건물 벽을 구분하기 위한 구조 격자.
func _assembly_structure(n: int) -> Dictionary:
	var d: Dictionary = _maps[n]
	var g: FieldGrid = d["grid"]
	var out: Dictionary = {}
	for lv: int in [-1, 0, 1, 2]:
		var mask := PackedByteArray()
		mask.resize(g.width * g.height)
		mask.fill(S.BLOCK if lv < 0 else S.AIR if lv > 0 else S.NONE)
		out[lv] = mask
	var constants: Dictionary = MAP_SCRIPTS[n].get_script_constant_map()
	for side in range(2):
		var plan: Dictionary = constants["PLAN" if side == 0 else "NORTH"]
		var shift := Vector2i(0, 45 if side == 0 else 0)
		for op in plan["ops"]:
			if op[0] == "floor":
				continue
			var mask: PackedByteArray = out[int(op[1])]
			var r: Rect2i = _rect(op[2])
			r.position += shift
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					var value: int = S.WALL
					if op[0] == "clear":
						value = int(op[5])
					elif op[0] == "shell":
						var edge: bool = x == r.position.x or x == r.end.x - 1 or y == r.position.y or y == r.end.y - 1
						value = S.WALL if edge else S.NONE
					mask[g.index(Vector2i(x, y))] = value
			out[int(op[1])] = mask
		for row in plan["doors"]:
			var mask: PackedByteArray = out[int(row[0])]
			mask[g.index(_cell(row[1]) + shift)] = S.DOOR
			out[int(row[0])] = mask
		for row in plan["windows"]:
			var mask: PackedByteArray = out[int(row[0])]
			var at: int = g.index(_cell(row[1]) + shift)
			if mask[at] == S.WALL:
				mask[at] = S.WINDOW
			out[int(row[0])] = mask
	var ground: PackedByteArray = out[0]
	var vehicles: Array = [d["train"]]
	for wagon in d["wagons"]:
		vehicles.append(wagon["rect"])
	for r: Rect2i in vehicles:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				ground[g.index(Vector2i(x, y))] = S.BLOCK
	out[0] = ground
	return out


func _assembly_protected(n: int) -> Dictionary:
	var d: Dictionary = _maps[n]
	var out: Dictionary = {}
	for lv: int in d["levels"]:
		var g: FieldGrid = d["levels"][lv]
		for c: Vector2i in g.doors:
			out[Vector3i(c.x, lv, c.y)] = true
		for c: Vector2i in g.windows:
			out[Vector3i(c.x, lv, c.y)] = true
	for row in _plans[n]["doors"]:
		var c: Vector2i = _cell(row[1])
		var direction: Vector2i = Vector2i.RIGHT if row[4] == "x" else Vector2i.DOWN
		var reach: int = 3 if int(row[0]) == 0 else 1
		for step in range(-reach, reach + 1):
			var at: Vector2i = c + direction * step
			out[Vector3i(at.x, int(row[0]), at.y)] = true
	for stair in d["stairs"]:
		var c: Vector2i = stair["cell"]
		for lv: int in [int(stair["low"]), int(stair["high"])]:
			out[Vector3i(c.x, lv, c.y)] = true
	for c: Vector2i in d["barricade_slots"]:
		out[Vector3i(c.x, 0, c.y)] = true
	for name: String in d["entries"]:
		for c: Vector2i in d["entries"][name]:
			out[Vector3i(c.x, int(d["entry_levels"].get(name, 0)), c.y)] = true
	for key: String in ["squad", "train_door", "dead_street"]:
		for c: Vector2i in d["spawns"].get(key, []):
			out[Vector3i(c.x, 0, c.y)] = true
	for side: String in d["train_doors"]:
		for c: Vector2i in d["train_doors"][side]:
			for step in range(4):
				out[Vector3i(c.x, 0, c.y + step * (-1 if side == "upper" else 1))] = true
	for box in d["containers"].values():
		var c: Vector2i = box["cell"]
		out[Vector3i(c.x, int(box.get("level", 0)), c.y)] = true
	for stove in d["stoves"]:
		var c: Vector2i = stove["cell"]
		out[Vector3i(c.x, int(stove.get("level", 0)), c.y)] = true
	for raw in _plans[n]["aprons"]:
		var r: Rect2i = _rect(raw)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				out[Vector3i(x, 0, y)] = true
	for raw in ASSEMBLY_CLEAR_AISLES[n]:
		out[Vector3i(int(raw[0]), int(raw[1]), int(raw[2]))] = true
	return out


func test_assembly_props_clear_structure_landings_and_each_other() -> void:
	for n in range(_maps.size()):
		var d: Dictionary = _maps[n]
		var g: FieldGrid = d["grid"]
		var structure: Dictionary = _assembly_structure(n)
		var protected_cells: Dictionary = _assembly_protected(n)
		var occupied: Dictionary = {}
		var errors: Array[String] = []
		for p in d["props"]:
			var r: Rect2i = p["rect"]
			var lv: int = int(p.get("level", 0))
			if p["solid"] == "low":
				_want(d["low_blocks"].has(r), errors, "low rectangle missing: " + String(p["kind"]))
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					var c := Vector2i(x, y)
					var key := Vector3i(x, lv, y)
					_want(not occupied.has(key), errors, "overlapping prop rectangles")
					occupied[key] = true
					_want(not protected_cells.has(key), errors, "prop covers protected cell")
					if not structure.has(lv):
						continue # floor_shell은 걷는 층 위의 외형이다.
					var mask: PackedByteArray = structure[lv]
					_want(mask[g.index(c)] == S.NONE, errors, "prop covers structural wall or non-floor")
					var lg: FieldGrid = d["levels"][lv]
					if p["solid"] != "wall":
						_want(lg.solid_at(c) != S.WALL, errors, "prop covers another wall")
					if p["solid"] == "low":
						_want(lg.solid_at(c) == S.LOW, errors, "low collider mismatch")
					if x > 0 and y > 0 and x < g.width - 1 and y < g.height - 1 and mask[g.index(c)] == S.NONE:
						var obstacles: Array[int] = [S.WALL, S.BLOCK, S.WINDOW, S.AIR]
						var horizontal: bool = obstacles.has(mask[g.index(c + Vector2i.LEFT)]) and obstacles.has(mask[g.index(c + Vector2i.RIGHT)])
						var vertical: bool = obstacles.has(mask[g.index(c + Vector2i.UP)]) and obstacles.has(mask[g.index(c + Vector2i.DOWN)])
						_want(not horizontal and not vertical, errors, "prop covers a one-cell corridor")
		_done(errors, d)


func test_assembly_building_walls_stay_inside_their_rectangles() -> void:
	for d in _maps:
		var errors: Array[String] = []
		for lv: int in d["levels"]:
			var g: FieldGrid = d["levels"][lv]
			for y in range(g.height):
				for x in range(g.width):
					var c := Vector2i(x, y)
					var id: int = g.building_at(c)
					if g.solid_at(c) != S.WALL or id < 0:
						continue
					_want(id < d["buildings"].size(), errors, "unknown wall building")
					if id < d["buildings"].size():
						var r: Rect2i = d["buildings"][id]["rect"]
						_want(r.has_point(c), errors, "wall outside building rectangle")
		_done(errors, d)


func test_assembly_container_names_have_model_suffixes() -> void:
	for d in _maps:
		var errors: Array[String] = []
		for box in d["containers"].values():
			var accepted: bool = false
			for suffix: String in CONTAINER_SUFFIXES:
				accepted = accepted or String(box["name"]).ends_with(suffix)
			_want(accepted, errors, "container suffix: " + String(box["id"]))
		_done(errors, d)


func test_assembly_vocabulary_low_runs_and_band_cover_counts() -> void:
	for n in range(_maps.size()):
		var d: Dictionary = _maps[n]
		var errors: Array[String] = []
		for p in d["props"]:
			_want(KINDS.has(p["kind"]), errors, "unknown assembly prop kind")
		for lv: int in d["levels"]:
			var g: FieldGrid = d["levels"][lv]
			var longest: int = 0
			for axis in range(2):
				for a in range(g.height if axis == 0 else g.width):
					var run: int = 0
					for b in range(g.width if axis == 0 else g.height):
						var c := Vector2i(b, a) if axis == 0 else Vector2i(a, b)
						run = run + 1 if g.solid_at(c) == S.LOW else 0
						longest = maxi(longest, run)
			_want(longest <= 10, errors, "all LOW runs including water: %d" % longest)
		for side_index in range(2):
			var band: Rect2i = d["bands"]["lower" if side_index == 0 else "upper"]
			var count: int = 0
			for r: Rect2i in d["low_blocks"]:
				count += int(band.intersects(r))
			_want(count == int(ASSEMBLY_BAND_COVER[n][side_index]), errors, "band cover count preserved")
		if d["place_id"] == "office_05":
			_want(d["hole_faces"].get("drain_01", Vector2i.ZERO) == Vector2i.UP, errors, "south drain faces open ground")
		_done(errors, d)
