extends "res://addons/gut/test.gd"

const FieldGrid = preload("res://game/world/field_grid.gd")
const StoryMaps = preload("res://game/world/story_maps.gd")
const FreightReference = preload("res://game/world/maps/freight_06.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const MAPS = [
	preload("res://game/world/maps/story_01.gd"),
	preload("res://game/world/maps/story_02.gd"),
	preload("res://game/world/maps/story_03.gd"),
]
# test_maps_freight.gd의 KEYS와 같은 계약. place_kind는 빌린 갈래(StoryMaps.BASE)다.
const KEYS = [
	"grid", "levels", "stairs", "containers", "spots", "stoves", "entries", "entry_gap", "entry_levels",
	"buildings", "wagons", "train", "platform", "unload", "train_cars", "spawns", "labels", "trees",
	"low_blocks", "upper_rects", "lights", "manholes", "manhole_levels", "sewer_names", "anchors", "zone_names",
	"place_id", "place_kind", "bands", "train_doors", "crossings", "barricade_slots", "interior_kind_slots", "props", "hole_faces", "entry_names", "entry_weights", "first_entry",
]
const BASE_KINDS: Array[String] = ["mine", "lodge", "sawmill", "lake", "freight", "houses", "hospital", "factory", "church", "office", "summit", "bare_line"]
const SPECS: Dictionary = {
	"story_01": {
		"width": 140, "height": 100, "area": 14000, "borrowed_kind": "freight", "min_zones": 3, "max_zones": 4,
		"spots": ["story_porter_01", "story_porter_02", "story_porter_03", "story_porter_04", "story_porter_05", "story_platform_end"],
		"porter_steps": 130,
		# 이 지도 절에는 별도로 지정된 망자 없는 건물이 없다.
		"safe_buildings": []
	},
	"story_02": {
		"width": 185, "height": 145, "area": 25375, "borrowed_kind": "freight", "min_zones": 4, "max_zones": 4,
		"spots": ["work_site", "story_bridge_front", "story_machine_room", "story_rear_view"],
		"spot_kinds": {"work_site": "work_site"},
		"safe_buildings": ["기계실"]
	},
	"story_03": {
		"width": 190, "height": 190, "area": 36100, "borrowed_kind": "office", "min_zones": 4, "max_zones": 5,
		"spots": ["story_transmitter", "story_log", "story_generator", "story_boiler_path"],
		"safe_buildings": ["송신실", "발전기 헛간"]
	}
}
const STEP: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var built: Array[Dictionary] = []
var walks: Dictionary = {}


func before_all() -> void:
	for script in MAPS:
		var data: Dictionary = script.build()
		built.append(data)
		var blocked: Dictionary = {}
		for c in data["barricade_slots"]:
			blocked[c] = true
		walks[data["place_id"]] = {"people": _flood(data), "dead": _flood(data, true), "blocked": _flood(data, false, blocked)}


func _cells(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2i(x, y))
	return out


# 이웃 시험처럼 네 방향의 칸 수를 센다. 대각선 지름길보다 보수적인 상한이다.
func _flood(data: Dictionary, dead: bool = false, blocked: Dictionary = {}) -> PackedInt32Array:
	var g: FieldGrid = data["grid"]
	var distance := PackedInt32Array()
	distance.resize(g.width * g.height)
	distance.fill(-1)
	var queue: Array[Vector2i] = []
	for side in data["train_doors"]:
		for c: Vector2i in data["train_doors"][side]:
			if not g.inside(c) or blocked.has(c):
				continue
			if not (g.dead_can_walk(c) if dead else g.people_can_walk(c)):
				continue
			if distance[g.index(c)] < 0:
				distance[g.index(c)] = 0
				queue.append(c)
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for step in STEP:
			var to: Vector2i = c + step
			if not g.inside(to) or blocked.has(to):
				continue
			if not (g.dead_can_walk(to) if dead else g.people_can_walk(to)):
				continue
			var index: int = g.index(to)
			if distance[index] < 0:
				distance[index] = distance[g.index(c)] + 1
				queue.append(to)
	return distance


func _water(data: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for prop in data["props"]:
		if prop["kind"] == "water":
			for c in _cells(prop["rect"]):
				out[c] = true
	return out


func _dead_cells(data: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for key: String in data["spawns"]:
		if key.begins_with("dead_") and key != "dead_levels":
			for c: Vector2i in data["spawns"][key]:
				out.append(c)
	return out


func test_keys_sizes_ground_only_and_borrowed_kind() -> void:
	for data in built:
		var spec: Dictionary = SPECS[data["place_id"]]
		var g: FieldGrid = data["grid"]
		assert_eq(data.size(), KEYS.size(), data["place_id"])
		for key in KEYS:
			assert_true(data.has(key), data["place_id"] + ": " + key)
		for key in data:
			assert_true(KEYS.has(key), data["place_id"] + " unexpected " + str(key))
		# The game reads its loot, horde and roof rules by place_kind: a story map keeps its borrowed kind.
		assert_eq(data["place_kind"], spec["borrowed_kind"])
		assert_eq(data["place_kind"], StoryMaps.base_of(data["place_id"]))
		assert_true(BASE_KINDS.has(data["place_kind"]))
		assert_false(data.has("base_kind"))
		assert_lte(g.width, spec["width"])
		assert_lte(g.height, spec["height"])
		assert_lte(g.width * g.height, spec["area"])
		assert_eq(data["levels"].keys(), [0])
		assert_eq(data["levels"][0], g)
		assert_true(data["stairs"].is_empty())
		assert_true(data["upper_rects"].is_empty())
		assert_true(data["spawns"]["dead_levels"].is_empty())
		assert_gte(data["zone_names"].size(), spec["min_zones"])
		assert_lte(data["zone_names"].size(), spec["max_zones"])
		for key in ["squad", "train_door", "dead_levels"]:
			assert_true(data["spawns"].has(key))


func test_all_recorded_coordinates_fit_the_final_grid() -> void:
	for data in built:
		var g: FieldGrid = data["grid"]
		var bounds := Rect2i(0, 0, g.width, g.height)
		var rects: Array = [data["train"], data["platform"], data["unload"]] + data["bands"].values() + data["low_blocks"]
		var cells: Array = data["barricade_slots"].duplicate() + data["trees"] + data["anchors"].values()
		for key in ["buildings", "props", "train_cars", "wagons"]:
			for row in data[key]:
				rects.append(row["rect"])
		for key in ["containers", "spots"]:
			for row in data[key].values():
				cells.append(row["cell"])
				if row.has("zone_rect"):
					rects.append(row["zone_rect"])
		for row in data["labels"]:
			cells.append(row["cell"])
		for row in data["wagons"]:
			cells.append(row["work"])
		for row in data["crossings"]:
			cells.append_array(row["cells"])
		for key in ["entries", "train_doors", "spawns"]:
			for group in data[key].values():
				cells.append_array(group)
		for r: Rect2i in rects:
			assert_true(r.size.x > 0 and r.size.y > 0 and bounds.encloses(r), str(r))
		for c: Vector2i in cells:
			assert_true(g.inside(c), str(c))


func test_horizontal_train_clear_doors_and_both_returns() -> void:
	for data in built:
		var g: FieldGrid = data["grid"]
		var train: Rect2i = data["train"]
		assert_eq(train.size, Vector2i(80, 3))
		assert_gt(train.position.y, 0)
		assert_lt(train.end.y, g.height)
		assert_eq(data["train_cars"].size(), 5)
		assert_eq(data["train_cars"][-1]["kind"], "engine")
		assert_eq(data["spawns"]["train_door"], data["train_doors"]["upper"] + data["train_doors"]["lower"])
		for side in ["upper", "lower"]:
			assert_true(data["bands"].has(side))
			assert_true(data["spots"].has("unload_" + side))
			var band: Rect2i = data["bands"][side]
			assert_eq(band.size.x, 120)
			assert_eq(band.position.x, train.position.x - 20)
			assert_gte(band.size.y, 20)
			assert_lte(band.size.y, 25)
			assert_eq(band.end.y if side == "upper" else band.position.y, train.position.y if side == "upper" else train.end.y)
			assert_gte(data["train_doors"][side].size(), 3)
			for c: Vector2i in data["train_doors"][side]:
				assert_eq(c.y, train.position.y - 1 if side == "upper" else train.end.y)
				assert_true(c.x >= train.position.x + 2 and c.x < train.end.x - 2)
				for offset in range(3):
					var ahead := c + Vector2i(0, -offset if side == "upper" else offset)
					assert_eq(g.solid_at(ahead), S.NONE)
			var unload: Dictionary = data["spots"]["unload_" + side]
			assert_eq(unload["kind"], "unload")
			assert_true(band.encloses(unload["zone_rect"]))
		for crossing in data["crossings"]:
			for c: Vector2i in crossing["cells"]:
				assert_false(train.has_point(c))
				assert_true(g.people_can_walk(c) and g.dead_can_walk(c))
		for c in _cells(train):
			assert_eq(g.solid_at(c), S.BLOCK)
			assert_eq(g.floor_at(c), F.RAIL)


func test_entries_and_dead_stay_outside_bands() -> void:
	for data in built:
		var g: FieldGrid = data["grid"]
		var reached: PackedInt32Array = walks[data["place_id"]]["dead"]
		assert_gte(data["entries"].size(), 2)
		assert_true(data["entries"].has(data["first_entry"]))
		var ways: Array = data["entries"].keys()
		var named: Array = data["entry_names"].keys()
		var weighed: Array = data["entry_weights"].keys()
		ways.sort()
		named.sort()
		weighed.sort()
		assert_eq(named, ways)
		assert_eq(weighed, ways)
		for key in data["entries"]:
			assert_true(data["entry_names"].has(key))
			assert_gt(float(data["entry_weights"].get(key, 0.0)), 0.0)
			assert_gt(float(data["entry_gap"].get(key, 0.0)), 0.0)
			assert_eq(data["entry_levels"].get(key, 0), 0)
			for c: Vector2i in data["entries"][key]:
				assert_true(g.dead_can_walk(c))
				assert_gte(reached[g.index(c)], 0)
				assert_lte(reached[g.index(c)], 150)
				for band: Rect2i in data["bands"].values():
					assert_false(band.has_point(c))
		for c in _dead_cells(data) + data["manholes"].values():
			for band: Rect2i in data["bands"].values():
				assert_false(band.has_point(c))
		assert_true(data["manholes"].is_empty())
		assert_true(data["manhole_levels"].is_empty())
		assert_true(data["sewer_names"].is_empty())


func test_spots_zone_labels_and_all_walkable_ground_are_reachable() -> void:
	for data in built:
		var g: FieldGrid = data["grid"]
		var spec: Dictionary = SPECS[data["place_id"]]
		var reached: PackedInt32Array = walks[data["place_id"]]["people"]
		for key in spec["spots"]:
			assert_true(data["spots"].has(key), key)
			var spot: Dictionary = data["spots"][key]
			assert_eq(spot["kind"], spec.get("spot_kinds", {}).get(key, "story"))
			assert_true(g.inside(spot["cell"]))
			assert_true(spot["zone_rect"].has_point(spot["cell"]))
			var distance: int = reached[g.index(spot["cell"])]
			assert_gte(distance, 0, key)
			if String(key).begins_with("story_porter_"):
				assert_lte(distance, spec["porter_steps"], key)
		for row in data["spots"].values() + data["containers"].values() + data["labels"]:
			assert_gte(reached[g.index(row["cell"])], 0, str(row))
		var labeled_zones: Dictionary = {}
		for row in data["labels"]:
			labeled_zones[g.zone_at(row["cell"])] = true
		for zone in data["zone_names"]:
			assert_true(labeled_zones.has(zone), zone)
		var unreachable: int = 0
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				if g.people_can_walk(c) and reached[g.index(c)] < 0:
					unreachable += 1
		assert_eq(unreachable, 0)


func test_barricades_leave_a_broad_open_side() -> void:
	for data in built:
		var g: FieldGrid = data["grid"]
		var reached: PackedInt32Array = walks[data["place_id"]]["blocked"]
		for c: Vector2i in data["barricade_slots"]:
			assert_true(g.people_can_walk(c))
		for side in ["upper", "lower"]:
			var band: Rect2i = data["bands"][side]
			var y: int = band.position.y if side == "upper" else band.end.y - 1
			var run: int = 0
			var longest: int = 0
			for x in range(band.position.x, band.end.x):
				var c := Vector2i(x, y)
				var outside := c + (Vector2i.UP if side == "upper" else Vector2i.DOWN)
				run = run + 1 if reached[g.index(c)] >= 0 and reached[g.index(outside)] >= 0 else 0
				longest = maxi(longest, run)
			assert_gte(longest, 20, side)
		for row in data["entries"].values():
			assert_gte(reached[g.index(row[0])], 0)


func test_water_is_not_cover_or_a_straight_low_run() -> void:
	for data in built:
		var g: FieldGrid = data["grid"]
		var water: Dictionary = _water(data)
		var cover: Dictionary = {}
		for r: Rect2i in data["low_blocks"]:
			for c in _cells(r):
				cover[c] = true
		for c: Vector2i in water:
			assert_eq(g.solid_at(c), S.LOW)
			assert_eq(g.floor_at(c), F.ICE)
			assert_false(cover.has(c))
			for band: Rect2i in data["bands"].values():
				assert_false(band.has_point(c))
		for band: Rect2i in data["bands"].values():
			var count: int = 0
			for r: Rect2i in data["low_blocks"]:
				if band.intersects(r):
					count += 1
			assert_gte(count, 3)
			assert_lte(count, 5)
		for horizontal in [true, false]:
			for a in range(g.height if horizontal else g.width):
				var run: int = 0
				var longest: int = 0
				for b in range(g.width if horizontal else g.height):
					var c := Vector2i(b, a) if horizontal else Vector2i(a, b)
					run = run + 1 if g.solid_at(c) == S.LOW and not water.has(c) else 0
					longest = maxi(longest, run)
				assert_lte(longest, 10)


func test_designated_safe_buildings_and_five_cell_door_aprons() -> void:
	for data in built:
		var g: FieldGrid = data["grid"]
		if SPECS[data["place_id"]]["safe_buildings"].is_empty():
			pass_test("No safe buildings named for " + data["place_id"])
			continue
		for name in SPECS[data["place_id"]]["safe_buildings"]:
			var found: bool = false
			for b in data["buildings"]:
				if b["name"] != name:
					continue
				found = true
				for c in _dead_cells(data):
					assert_ne(g.building_at(c), int(b["id"]))
					for door: Vector2i in g.doors:
						if int(g.doors[door]["building"]) == int(b["id"]):
							assert_gt(maxi(absi(c.x - door.x), absi(c.y - door.y)), 5)
			assert_true(found, name)


func test_story_01_coal_porters_and_platform_end() -> void:
	var data: Dictionary = built[0]
	var g: FieldGrid = data["grid"]
	var work: Dictionary = data["spots"]["work_site"]
	assert_eq(work["kind"], "work_site")
	assert_eq(work["state"], "closed")
	assert_true(work["zone_rect"].has_point(work["cell"]))
	var front: int = 0
	var ice: int = 0
	for key: String in data["containers"]:
		if key.begins_with("coal_"):
			assert_eq(data["containers"][key]["name"], "석탄 자루 상자")
			assert_true(data["containers"][key]["items"].is_empty())
			if key.begins_with("coal_front_"):
				front += 1
			else:
				ice += 1
	assert_eq(front, 4)
	assert_eq(ice, 4)
	for i in range(1, 6):
		var c: Vector2i = data["spots"]["story_porter_%02d" % i]["cell"]
		assert_eq(work["zone_rect"].has_point(c), i <= 3)
		if i >= 4:
			assert_eq(g.floor_at(c), F.ICE)
	var end: Rect2i = data["spots"]["story_platform_end"]["zone_rect"]
	assert_gte(end.get_area(), 80)
	for c in _cells(end):
		assert_true(g.people_can_walk(c))
	for prop in data["props"]:
		assert_false(end.intersects(prop["rect"]))
	for box in data["containers"].values():
		assert_false(end.has_point(box["cell"]))
	assert_true(_dead_cells(data).is_empty())
	assert_eq(data["spawns"]["squad"].size(), 3)
	for wagon in data["wagons"]:
		assert_true(g.people_can_walk(wagon["work"]))
		for band: Rect2i in data["bands"].values():
			assert_false(band.intersects(wagon["rect"]))
		for key in SPECS["story_01"]["spots"]:
			assert_false(wagon["rect"].grow(2).has_point(data["spots"][key]["cell"]))


func test_story_01_roundhouse_has_two_front_doors_and_one_visible_deep_door() -> void:
	var data: Dictionary = built[0]
	var g: FieldGrid = data["grid"]
	var plan: Dictionary = MAPS[0].PLAN
	var r: Array = plan["deep"]["rect"]
	var deep := Rect2i(r[0], r[1], r[2], r[3])
	var exits: Dictionary = {}
	for c in _cells(deep):
		if g.building_at(c) != 0 or not g.people_can_walk(c):
			continue
		for step in STEP:
			var to: Vector2i = c + step
			if not deep.has_point(to) and g.people_can_walk(to):
				exits[to] = true
	assert_eq(exits.size(), 1)
	assert_true(exits.has(Vector2i(40, 83)))
	var front_doors: int = 0
	for c: Vector2i in g.doors:
		var exterior: bool = false
		for step in STEP:
			if g.building_at(c + step) < 0 and g.people_can_walk(c + step):
				exterior = true
		if exterior:
			front_doors += 1
	assert_eq(front_doors, 2)
	for y in range(79, 84):
		assert_false(g.opaque(Vector2i(40, y)))
		assert_true(g.people_can_walk(Vector2i(40, y)))
	assert_false(deep.has_point(data["containers"]["tools_shallow"]["cell"]))
	assert_true(deep.has_point(data["containers"]["tools_deep"]["cell"]))
	assert_eq(data["containers"]["tools_shallow"]["items"], data["containers"]["tools_deep"]["items"])


func test_story_01_first_ice_approach_is_about_two_minutes_of_walking() -> void:
	var data: Dictionary = built[0]
	var g: FieldGrid = data["grid"]
	assert_true(["ice_west", "ice_east"].has(data["first_entry"]))
	assert_eq(data["entries"].size(), 3)
	var shortest: float = INF
	for start: Vector2i in data["entries"][data["first_entry"]]:
		for side in data["train_doors"]:
			for door: Vector2i in data["train_doors"][side]:
				var path: Array[Vector2i] = g.dead_path.get_id_path(start, door)
				assert_false(path.is_empty())
				var meters: float = 0.0
				for i in range(1, path.size()):
					meters += Vector2(path[i - 1]).distance_to(Vector2(path[i]))
				shortest = minf(shortest, meters)
	# 초속 1m일 때의 기하학적 거리다. 출현 시각과 실제 물결 수는 사건 쪽에서 정한다.
	assert_gte(shortest, 110.0)
	assert_lte(shortest, 145.0)


func test_distinct_grids_judgment_line_allowed_preloads_and_facility_names() -> void:
	var roman := RegEx.new()
	assert_eq(roman.compile("[A-Za-z]"), OK)
	var preloads := RegEx.new()
	assert_eq(preloads.compile("preload\\(\"([^\"]+)\"\\)"), OK)
	# With one story map the cross-map grid check has nothing to compare; two builds are kept apart below.
	for i in range(built.size()):
		var data: Dictionary = built[i]
		var g: FieldGrid = data["grid"]
		for j in range(i):
			var other: FieldGrid = built[j]["grid"]
			assert_false(g.solid == other.solid and g.floor == other.floor)
		var source: String = FileAccess.get_file_as_string(MAPS[i].resource_path)
		assert_true(source.get_slice("\n", 0).begins_with("# 이 지도가 다른 판단을 만드는 것: "))
		for hit in preloads.search_all(source):
			assert_true(["res://game/world/field_grid.gd", "res://game/world/map_shift.gd"].has(hit.get_string(1)))
		var names: Array = data["zone_names"].values() + data["entry_names"].values()
		for key in ["containers", "spots"]:
			for row in data[key].values():
				names.append(row["name"])
		for row in data["buildings"] + data["wagons"]:
			names.append(row["name"])
		for row in data["props"]:
			names.append(row["note"])
		for name in names:
			assert_null(roman.search(String(name)), String(name))
		var asymmetric: bool = false
		for y in range(g.height):
			for x in range(g.width):
				if g.solid_at(Vector2i(x, y)) != g.solid_at(Vector2i(x, g.height - 1 - y)):
					asymmetric = true
		assert_true(asymmetric)


func test_two_builds_share_no_grid_or_nested_data() -> void:
	# A later build() that handed back a cached grid or shared rows would let one field change the next.
	for script in MAPS:
		var a: Dictionary = script.build()
		var b: Dictionary = script.build()
		assert_ne(a["grid"], b["grid"])
		for key in ["containers", "spots", "entries", "bands", "entry_names", "entry_weights"]:
			a[key]["_probe"] = true
			assert_false(b[key].has("_probe"), key)


func _story(id: String) -> Dictionary:
	for data in built:
		if data["place_id"] == id:
			return data
	return {}


func _plan_rect(row: Array) -> Rect2i:
	return Rect2i(int(row[0]), int(row[1]), int(row[2]), int(row[3]))


func _deep_exits(g: FieldGrid, deep: Rect2i) -> Dictionary:
	var exits: Dictionary = {}
	for c in _cells(deep):
		if not g.people_can_walk(c):
			continue
		for step in STEP:
			var to: Vector2i = c + step
			if not deep.has_point(to) and g.people_can_walk(to):
				exits[to] = true
	return exits


func _exterior_doors(g: FieldGrid, building: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in g.doors:
		if int(g.doors[c]["building"]) != building:
			continue
		for step in STEP:
			if g.building_at(c + step) < 0 and g.people_can_walk(c + step):
				out.append(c)
				break
	return out


func _first_entry_steps(data: Dictionary, reached: PackedInt32Array) -> int:
	var g: FieldGrid = data["grid"]
	var nearest: int = g.width * g.height
	for c: Vector2i in data["entries"][data["first_entry"]]:
		assert_gte(reached[g.index(c)], 0)
		nearest = mini(nearest, reached[g.index(c)])
	return nearest


# 지정된 길의 바닥 안에서만 걷는다. 표시만 있고 바위나 벽으로 끊긴 길을 잡는다.
func _route_exists(g: FieldGrid, rects: Array, start: Vector2i, goal: Vector2i) -> bool:
	var allowed: Dictionary = {}
	for row in rects:
		for c in _cells(_plan_rect(row)):
			if g.people_can_walk(c):
				allowed[c] = true
	if not allowed.has(start) or not allowed.has(goal):
		return false
	var seen: Dictionary = {}
	seen[start] = true
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if c == goal:
			return true
		for step in STEP:
			var to: Vector2i = c + step
			if allowed.has(to) and not seen.has(to):
				seen[to] = true
				queue.append(to)
	return false


func test_entry_metadata_spawn_names_and_nested_build_isolation() -> void:
	for script in MAPS:
		var a: Dictionary = script.build()
		var b: Dictionary = script.build()
		var keys: Array = a["entries"].keys()
		keys.sort()
		for name in ["entry_names", "entry_weights", "entry_gap", "entry_levels"]:
			var actual: Array = a[name].keys()
			actual.sort()
			assert_eq(actual, keys, name)
		assert_true(a["hole_faces"].is_empty())
		for key: String in a["spawns"]:
			assert_true(["squad", "train_door"].has(key) or key.begins_with("dead_"), key)
		var key: String = keys[0]
		var original: Vector2i = b["entries"][key][0]
		a["entries"][key][0] = Vector2i(-1, -1)
		assert_eq(b["entries"][key][0], original)
		a["props"][0]["note"] = "변경 확인"
		assert_ne(b["props"][0]["note"], "변경 확인")
		var box: String = a["containers"].keys()[0]
		a["containers"][box]["items"].append("_probe")
		assert_false(b["containers"][box]["items"].has("_probe"))
		var later: Dictionary = script.build()
		assert_eq(later["entries"][key][0], original)
		assert_ne(later["props"][0]["note"], "변경 확인")
		assert_false(later["containers"][box]["items"].has("_probe"))


func test_story_02_canal_has_one_bridge_and_an_irregular_river_mouth() -> void:
	var data: Dictionary = _story("story_02")
	var g: FieldGrid = data["grid"]
	var plan: Dictionary = MAPS[1].PLAN
	var bridge := _plan_rect(plan["bridge"])
	for y in range(g.height):
		assert_eq(g.people_can_walk(Vector2i(135, y)), y >= bridge.position.y and y < bridge.end.y)
	for x in range(bridge.position.x, bridge.end.x):
		assert_eq(g.floor_at(Vector2i(x, 64)), F.RAIL)
		assert_true(g.people_can_walk(Vector2i(x, 64)))
	var water: Dictionary = _water(data)
	var shores: Dictionary = {}
	for y in range(117, g.height):
		var first: int = g.width
		var last: int = -1
		for x in range(g.width):
			if water.has(Vector2i(x, y)):
				first = mini(first, x)
				last = maxi(last, x)
		shores[Vector2i(first, last)] = true
	assert_gte(shores.size(), 3)
	var piers: int = 0
	var crossbars: int = 0
	var reeds: int = 0
	for prop in data["props"]:
		var note: String = prop["note"]
		if note.contains("철교") and note.contains("기둥"):
			piers += 1
			assert_eq(prop["solid"], "wall")
		if note.contains("위 가로대"):
			crossbars += 1
			assert_eq(prop["solid"], "none")
		if prop["kind"] == "frozen_reeds":
			reeds += 1
	assert_eq(piers, 4)
	assert_eq(crossbars, 2)
	assert_gte(reeds, 2)


func test_story_02_open_wagons_siding_and_flat_loading_yard() -> void:
	var data: Dictionary = _story("story_02")
	var g: FieldGrid = data["grid"]
	var plan: Dictionary = MAPS[1].PLAN
	var train: Rect2i = data["train"]
	assert_lte(train.position.x, 25)
	assert_gte(data["wagons"].size(), 2)
	assert_lte(data["wagons"].size(), 3)
	for wagon in data["wagons"]:
		var r: Rect2i = wagon["rect"]
		assert_eq(r.position.y, train.position.y)
		assert_gte(r.position.x, train.end.x)
		assert_lte(r.end.x, 130)
		assert_true(String(wagon["name"]).contains("열린"))
		assert_eq(wagon["coal"], 0)
		assert_true(g.people_can_walk(wagon["work"]))
	var work: Dictionary = data["spots"]["work_site"]
	assert_eq(work["kind"], "work_site")
	assert_eq(work["state"], "closed")
	assert_true(work["zone_rect"].has_point(work["cell"]))
	assert_eq(g.floor_at(Vector2i(54, 93)), F.RAIL)
	assert_eq(g.floor_at(Vector2i(91, 72)), F.RAIL)
	var yard := _plan_rect(plan["loading_yard"])
	for band: Rect2i in data["bands"].values():
		assert_false(band.intersects(yard))
		assert_false(band.intersects(work["zone_rect"]))
	for c in _cells(yard):
		assert_eq(g.floor_at(c), F.GRAVEL)
		assert_true(g.people_can_walk(c))
	assert_eq(_exterior_doors(g, 0), [Vector2i(78, 33)])


func test_story_02_warehouse_has_one_visible_deep_door_and_split_tools() -> void:
	var data: Dictionary = _story("story_02")
	var g: FieldGrid = data["grid"]
	var deep := _plan_rect(MAPS[1].PLAN["deep"]["rect"])
	var exits := _deep_exits(g, deep)
	assert_eq(exits.size(), 1)
	assert_true(exits.has(Vector2i(78, 21)))
	for y in range(21, 28):
		assert_true(g.people_can_walk(Vector2i(78, y)))
		assert_false(g.opaque(Vector2i(78, y)))
	assert_false(deep.has_point(data["containers"]["tools_shallow"]["cell"]))
	assert_true(deep.has_point(data["containers"]["tools_deep"]["cell"]))
	assert_eq(data["containers"]["tools_shallow"]["items"], data["containers"]["tools_deep"]["items"])


func test_story_02_west_wave_walks_in_earlier_than_the_freight_reference() -> void:
	var data: Dictionary = _story("story_02")
	assert_eq(data["first_entry"], "west_track")
	assert_eq(data["entries"].size(), 3)
	for key in data["entry_weights"]:
		if key != data["first_entry"]:
			assert_gt(data["entry_weights"][data["first_entry"]], data["entry_weights"][key])
	var early: int = _first_entry_steps(data, walks["story_02"]["dead"])
	var reference: Dictionary = FreightReference.build()
	var ordinary: int = _first_entry_steps(reference, _flood(reference, true))
	assert_lte(early, 45)
	assert_lt(early, ordinary)
	# 물결 시작 시각은 사건 코드 소유다. 여기서는 같은 네 방향 보행 거리만 비교한다.


func test_story_02_east_field_is_open_and_machine_room_faces_it() -> void:
	var data: Dictionary = _story("story_02")
	var g: FieldGrid = data["grid"]
	var field := _plan_rect(MAPS[1].PLAN["field"])
	assert_gte(field.size.x, 40)
	assert_eq(field.end.x, g.width)
	for c in _cells(field):
		if g.building_at(c) != 1:
			assert_true(g.solid_at(c) != S.WALL and g.solid_at(c) != S.BLOCK)
	for group in data["entries"].values():
		for c: Vector2i in group:
			assert_lt(c.x, 132)
	for c in _dead_cells(data):
		assert_lt(c.x, 132)
	assert_eq(_exterior_doors(g, 1), [Vector2i(156, 52)])
	assert_eq(g.doors[Vector2i(156, 52)]["state"], "open")
	var outside: Vector2i = data["spots"]["story_machine_room"]["cell"]
	assert_gt(outside.x, 156)
	assert_eq(g.building_at(outside), -1)
	assert_true(field.has_point(outside))
	assert_true(field.has_point(data["spots"]["story_rear_view"]["cell"]))
	assert_lt(data["spots"]["story_bridge_front"]["cell"].x, 132)


func test_story_03_two_separate_climbs_reach_the_summit_from_a_southern_train() -> void:
	var data: Dictionary = _story("story_03")
	var g: FieldGrid = data["grid"]
	var plan: Dictionary = MAPS[2].PLAN
	var train: Rect2i = data["train"]
	assert_gte(train.position.y, int(g.height * 0.8))
	assert_lte(g.height - train.end.y, 30)
	assert_true(_route_exists(g, plan["winding"], Vector2i(80, 127), Vector2i(80, 62)))
	assert_true(_route_exists(g, plan["shortcut"], Vector2i(101, 127), Vector2i(114, 59)))
	var yard := _plan_rect(plan["yard"])
	for left in plan["winding"]:
		for right in plan["shortcut"]:
			var overlap := _plan_rect(left).intersection(_plan_rect(right))
			assert_true(not overlap.has_area() or yard.encloses(overlap))
	var boiler: Vector2i = data["spots"]["story_boiler_path"]["cell"]
	assert_true(_route_exists(g, plan["shortcut"], boiler, Vector2i(101, 127)))
	assert_lt(boiler.y, data["bands"]["upper"].position.y)


func test_story_03_residents_only_circle_the_hill_in_forest_and_brush() -> void:
	var data: Dictionary = _story("story_03")
	var g: FieldGrid = data["grid"]
	var dead := _dead_cells(data)
	assert_gt(dead.size(), 0)
	assert_lte(dead.size(), 60)
	var groups: int = 0
	for key: String in data["spawns"]:
		if key.begins_with("dead_forest_"):
			groups += 1
			assert_lte(data["spawns"][key].size(), 15)
	assert_eq(groups, 4)
	for c in dead:
		var in_forest: bool = false
		for row in MAPS[2].PLAN["forests"]:
			in_forest = in_forest or _plan_rect(row).has_point(c)
		assert_true(in_forest)
		assert_eq(g.floor_at(c), F.DEEP_SNOW)
		assert_eq(g.building_at(c), -1)
		assert_true(g.dead_can_walk(c))
		var brush: bool = false
		for prop in data["props"]:
			if prop["kind"] == "dry_bush" and prop["rect"].has_point(c):
				brush = true
		assert_true(brush)
	var entries: Array = data["entries"].keys()
	entries.sort()
	assert_eq(entries, ["forest_east", "forest_north", "forest_west", "west_track"])
	for i in range(entries.size()):
		var a: Vector2i = data["entries"][entries[i]][0]
		for j in range(i):
			var b: Vector2i = data["entries"][entries[j]][0]
			assert_gte(maxi(absi(a.x - b.x), absi(a.y - b.y)), 45)


func test_story_03_safe_equipment_rooms_keep_the_story_inside_and_tools_split() -> void:
	var data: Dictionary = _story("story_03")
	var g: FieldGrid = data["grid"]
	assert_eq(data["buildings"].size(), 2)
	assert_eq(data["buildings"][0]["role"], "office")
	assert_eq(g.building_at(data["spots"]["story_transmitter"]["cell"]), 0)
	assert_eq(g.building_at(data["spots"]["story_log"]["cell"]), 0)
	assert_eq(g.building_at(data["spots"]["story_generator"]["cell"]), 1)
	assert_eq(_exterior_doors(g, 0), [Vector2i(80, 62)])
	assert_eq(_exterior_doors(g, 1), [Vector2i(114, 59)])
	for door in g.doors.values():
		assert_eq(door["state"], "open")
	var deep := _plan_rect(MAPS[2].PLAN["deep"]["rect"])
	var exits := _deep_exits(g, deep)
	assert_eq(exits.size(), 1)
	assert_true(exits.has(Vector2i(80, 54)))
	for y in range(54, 59):
		assert_true(g.people_can_walk(Vector2i(80, y)))
		assert_false(g.opaque(Vector2i(80, y)))
	assert_false(deep.has_point(data["containers"]["tools_shallow"]["cell"]))
	assert_true(deep.has_point(data["containers"]["tools_deep"]["cell"]))
	assert_eq(data["containers"]["tools_shallow"]["items"], data["containers"]["tools_deep"]["items"])
	assert_true(data["stoves"].is_empty())
	assert_eq(data["interior_kind_slots"], [{"zone": "D", "kinds": ["empty"]}])
	var kinds: Array = []
	for prop in data["props"]:
		kinds.append(prop["kind"])
	for kind in ["radio_set", "cold_stove", "notice_board", "generator_unit", "fuel_tank"]:
		assert_true(kinds.has(kind), kind)


func test_story_03_lattice_tower_has_four_piers_without_a_roof_or_standing_deck() -> void:
	var data: Dictionary = _story("story_03")
	var g: FieldGrid = data["grid"]
	var tower := _plan_rect(MAPS[2].PLAN["tower"])
	var piers: int = 0
	for prop in data["props"]:
		if String(prop["note"]).contains("격자 철탑"):
			assert_eq(prop["solid"], "wall")
			assert_eq(prop["rect"].size, Vector2i.ONE)
			assert_true(tower.encloses(prop["rect"]))
			piers += 1
	assert_eq(piers, 4)
	for c in _cells(tower):
		assert_eq(g.building_at(c), -1)
		assert_ne(g.floor_at(c), F.PLATFORM)
	for building in data["buildings"]:
		assert_false(tower.intersects(building["rect"]))
	assert_eq(data["levels"].keys(), [0])
	assert_true(data["upper_rects"].is_empty())


func test_story_02_and_story_03_safe_maps_have_no_body_props_or_forbidden_set_dressing() -> void:
	for id in ["story_02", "story_03"]:
		var data := _story(id)
		for prop in data["props"]:
			var kind: String = prop["kind"]
			for forbidden in ["corpse", "body", "barbed", "watchtower", "chimney", "smoke", "luggage", "shoe", "clothes", "ramp"]:
				assert_false(kind.contains(forbidden), id + ": " + kind)
