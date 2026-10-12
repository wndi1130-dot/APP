extends "res://addons/gut/test.gd"
## 산맥 고개 다섯 장의 계약 검사. 가져오기와 실행은 이 작업 밖의 CI가 맡는다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const MAPS: Array = [
	preload("res://game/world/maps/summit_01.gd"),
	preload("res://game/world/maps/summit_02.gd"),
	preload("res://game/world/maps/summit_03.gd"),
	preload("res://game/world/maps/summit_04.gd"),
	preload("res://game/world/maps/summit_05.gd"),
]
const KEYS: Array[String] = [
	"grid", "levels", "stairs", "containers", "spots", "stoves", "entries",
	"buildings", "wagons", "train", "platform", "spawns", "labels", "trees",
	"low_blocks", "upper_rects", "train_cars", "lights", "manholes",
	"manhole_levels", "sewer_names", "entry_levels", "entry_gap", "unload",
	"place_id", "place_kind", "bands", "train_doors", "crossings",
	"barricade_slots", "interior_kind_slots", "props",
	"entry_names", "entry_weights", "first_entry", "zone_names",
]
const PROP_KINDS: Array[String] = [
	"rock_face", "rock_ridge", "snow_bank", "snow_drift", "sleeper_stack", "crate_stack", "fallen_log", "signal_post", "track_switch", "rail_marker", "power_pole", "tool_bench", "tool_rack", "parts_rack", "fuel_drum", "fuel_tank", "fuel_can_group", "generator", "ladder_rack", "inspection_pit", "snowplow_truck", "sled_load", "handcart", "bed", "desk", "radio_set", "shelf", "map_cabinet", "firewood_pile", "rail_plow", "plow_blade", "rail_stack", "fallen_signal", "wind_pole", "snow_gauge_pole", "garage_door_leaf", "siding_buffer"
]
const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var _maps: Array[Dictionary] = []
var _people: Array[PackedInt32Array] = []
var _dead: Array[PackedInt32Array] = []


func before_all() -> void:
	for script in MAPS:
		var d: Dictionary = script.build()
		_maps.append(d)
		_people.append(_flood(d["grid"], [d["spawns"]["train_door"][0]]))
		_dead.append(_flood(d["grid"], d["spawns"]["train_door"], true))


func test_exact_keys_dimensions_and_zones() -> void:
	assert_eq(_maps.size(), 5)
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var g: FieldGrid = d["grid"]
		var keys: Array = d.keys()
		var allowed: Array = KEYS.duplicate()
		keys.sort()
		allowed.sort()
		assert_eq(keys, allowed)
		assert_true(g.width >= 168 and g.width <= 180 and g.height >= 78 and g.height <= 90)
		assert_eq(d["place_id"], "summit_%02d" % (i + 1))
		assert_eq(d["place_kind"], "summit")
		var zones: Dictionary = {}
		for z: String in g.zone:
			if z != "":
				zones[z] = true
		assert_true(zones.size() >= 4 and zones.size() <= 6)
		assert_false(zones.has("below"), "지하 구역은 지상 구역 수에서 제외")


func test_train_bands_and_clear_door_aprons() -> void:
	for d: Dictionary in _maps:
		var g: FieldGrid = d["grid"]
		var train: Rect2i = d["train"]
		assert_eq(train.size, Vector2i(80, 3))
		assert_true(train.position.x > 0 and train.position.y > 0 and train.end.x < g.width and train.end.y < g.height)
		assert_eq(d["train_cars"].size(), 5)
		assert_eq(d["platform"], Rect2i(train.position.x, train.end.y, 80, 3))
		assert_eq(d["unload"], Rect2i(train.position.x, train.position.y - 3, 80, 9))
		assert_eq(d["spawns"]["train_door"], d["train_doors"]["lower"] + d["train_doors"]["upper"])
		var squad: Array = []
		for offset in range(39, 43):
			squad.append(Vector2i(train.position.x + offset, train.end.y + 1))
		assert_eq(d["spawns"]["squad"], squad)
		assert_eq(d["lights"].size(), 33)
		for k in range(5):
			assert_eq(d["train_cars"][k]["rect"], Rect2i(train.position.x + 16 * k, train.position.y, 16, 3))
			assert_eq(d["train_cars"][k]["kind"], "car" if k < 4 else "engine")
		for r: Rect2i in [Rect2i(train.position.x, train.position.y - 3, 80, 3), Rect2i(train.position.x, train.end.y, 80, 3)]:
			for c: Vector2i in _cells(r):
				assert_eq(g.solid_at(c), S.NONE)
				assert_eq(g.floor_at(c), F.GRAVEL)
		for side: String in ["upper", "lower"]:
			var band: Rect2i = d["bands"][side]
			assert_eq(band.size.x, 120)
			assert_eq(band.size.y, 22)
			assert_eq(band.position.x, train.position.x - 20)
			assert_true(Rect2i(0, 0, g.width, g.height).encloses(band))
			assert_eq(band.end.y if side == "upper" else band.position.y, train.position.y if side == "upper" else train.end.y)
			assert_eq(d["train_doors"][side].size(), 3)
			for k in range(3):
				var offsets: Array[int] = [8, 40, 56]
				assert_eq(d["train_doors"][side][k], Vector2i(train.position.x + offsets[k], train.position.y - 1 if side == "upper" else train.end.y))
			for c: Vector2i in d["train_doors"][side]:
				assert_true(band.has_point(c) and d["unload"].has_point(c))
				assert_true(d["spawns"]["train_door"].has(c))
		for c: Vector2i in _door_apron(d):
			assert_true(g.people_can_walk(c) and g.dead_can_walk(c), "문 앞 3칸 %s" % c)


func test_entries_spawns_and_access_even_after_barricading() -> void:
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var g: FieldGrid = d["grid"]
		assert_eq(d["entries"].size(), 6)
		var names: Array = d["entries"].keys()
		names.sort()
		var expected: Array[String] = ["track_west_upper", "track_east_upper", "track_west_lower", "track_east_lower", "access_road", "ridge_path"]
		expected.sort()
		assert_eq(names, expected)
		var level_names: Array = d["entry_levels"].keys()
		level_names.sort()
		assert_eq(level_names, expected)
		for name: String in d["entries"]:
			assert_true(d["entry_gap"].has(name))
			assert_eq(int(d["entry_levels"][name]), 0)
			assert_eq(float(d["entry_gap"][name]), 2.4 if name == "ridge_path" else 0.6)
			assert_true(float(d["entry_gap"][name]) > 0.0 and float(d["entry_gap"][name]) <= 3.0)
			for c: Vector2i in d["entries"][name]:
				assert_false(_in_band(d, c))
				if int(d["entry_levels"].get(name, 0)) == 0:
					assert_true(g.dead_can_walk(c) and _dead[i][g.index(c)] >= 0)
		for name: String in d["spawns"]:
			if name.begins_with("dead_") and name != "dead_levels":
				for c: Vector2i in d["spawns"][name]:
					assert_false(_in_band(d, c))
		var unreachable := 0
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				if g.people_can_walk(c) and _people[i][g.index(c)] < 0:
					unreachable += 1
		assert_eq(unreachable, 0, "열차에서 지상의 모든 보행 칸")
		var blocked: Dictionary = {}
		for c: Vector2i in d["barricade_slots"]:
			assert_true(g.people_can_walk(c))
			blocked[c] = true
		var distances := _flood(g, [d["spawns"]["train_door"][0]], false, blocked)
		var zones: Dictionary = {}
		var reached: Dictionary = {}
		for index in range(g.width * g.height):
			zones[g.zone[index]] = true
			if distances[index] >= 0:
				reached[g.zone[index]] = true
		for z: String in zones:
			assert_true(reached.has(z), "방벽 뒤에도 남는 트인 변: " + z)


func test_barricades_span_real_short_gaps() -> void:
	for d: Dictionary in _maps:
		var g: FieldGrid = d["grid"]
		var remaining: Dictionary = {}
		for c: Vector2i in d["barricade_slots"]:
			remaining[c] = true
		var upper := 0
		var lower := 0
		while not remaining.is_empty():
			var first: Vector2i = remaining.keys()[0]
			remaining.erase(first)
			var group: Array[Vector2i] = [first]
			var cursor := 0
			while cursor < group.size():
				var c: Vector2i = group[cursor]
				cursor += 1
				for step: Vector2i in DIRECTIONS:
					if remaining.erase(c + step):
						group.append(c + step)
			assert_true(group.size() >= 2 and group.size() <= 3)
			var min_x: int = first.x
			var max_x: int = first.x
			var min_y: int = first.y
			var max_y: int = first.y
			for c: Vector2i in group:
				assert_true(g.people_can_walk(c))
				min_y = mini(min_y, c.y)
				max_y = maxi(max_y, c.y)
				min_x = mini(min_x, c.x)
				max_x = maxi(max_x, c.x)
			assert_true(min_x == max_x or min_y == max_y)
			if min_y == max_y:
				assert_false(g.people_can_walk(Vector2i(min_x - 1, first.y)))
				assert_false(g.people_can_walk(Vector2i(max_x + 1, first.y)))
			else:
				assert_false(g.people_can_walk(Vector2i(first.x, min_y - 1)))
				assert_false(g.people_can_walk(Vector2i(first.x, max_y + 1)))
			if first.y < d["train"].position.y:
				upper += 1
			else:
				lower += 1
		assert_true(upper >= 2 and upper <= 3 and lower >= 2 and lower <= 3)


func test_no_featureless_thirty_by_twenty_window() -> void:
	for d: Dictionary in _maps:
		var g: FieldGrid = d["grid"]
		var prefixes: Array[PackedInt32Array] = []
		for kind in range(8):
			prefixes.append(_floor_prefix(g, kind))
		var blank := 0
		var stride: int = g.width + 1
		for y in range(g.height - 19):
			for x in range(g.width - 29):
				var p: PackedInt32Array = prefixes[g.floor_at(Vector2i(x, y))]
				var count: int = p[(y + 20) * stride + x + 30] - p[y * stride + x + 30] - p[(y + 20) * stride + x] + p[y * stride + x]
				blank += 1 if count == 600 else 0
		assert_eq(blank, 0)


func test_cover_count_length_and_visible_backing() -> void:
	for d: Dictionary in _maps:
		var g: FieldGrid = d["grid"]
		for side: String in ["upper", "lower"]:
			var count := 0
			var near := 0
			var shapes: Dictionary = {}
			for r: Rect2i in d["low_blocks"]:
				if not d["bands"][side].intersects(r):
					continue
				count += 1
				shapes[r.size] = true
				assert_true(maxi(r.size.x, r.size.y) >= 2 and maxi(r.size.x, r.size.y) <= 6)
				var close := false
				for c: Vector2i in d["train_doors"][side]:
					var dx := maxi(0, maxi(r.position.x - c.x, c.x - r.end.x + 1))
					var dy := maxi(0, maxi(r.position.y - c.y, c.y - r.end.y + 1))
					close = close or dx + dy <= 12
				near += 1 if close else 0
			assert_true(count >= 3 and count <= 5 and near >= 2 and shapes.size() >= 2)
		var missing_low := 0
		var hidden_block := 0
		var longest := 0
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				if g.solid_at(c) == S.LOW:
					var visible := false
					for r: Rect2i in d["low_blocks"]:
						visible = visible or r.has_point(c)
					for stove: Dictionary in d["stoves"]:
						visible = visible or (int(stove.get("level", 0)) == 0 and stove["cell"] == c)
					missing_low += 0 if visible else 1
					for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
						var n := 0
						while g.inside(c + step * n) and g.solid_at(c + step * n) == S.LOW:
							n += 1
						longest = maxi(longest, n)
				if g.solid_at(c) == S.BLOCK and g.building_at(c) < 0:
					var visible: bool = d["train"].has_point(c) or d["trees"].has(c)
					for wagon: Dictionary in d["wagons"]:
						visible = visible or wagon["rect"].has_point(c)
					hidden_block += 0 if visible and not (x < 14 and y < 14) else 1
		assert_eq(missing_low, 0)
		assert_eq(hidden_block, 0)
		assert_true(longest <= 10)
		assert_true(d["trees"].size() >= 60 and d["trees"].size() <= 150)
		assert_eq(d["wagons"], [])


func test_portals_building_partitions_and_shallow_loot() -> void:
	for d: Dictionary in _maps:
		var g: FieldGrid = d["grid"]
		assert_true(d["buildings"].size() >= 2 and d["buildings"].size() <= 3)
		var shed: Dictionary = d["buildings"][0]
		var mouths: Array = shed["entrances"]
		assert_eq(mouths.size(), 2)
		for b: Dictionary in d["buildings"]:
			assert_true([0, 1, 2].has(int(b["id"])))
			var r: Rect2i = b["rect"]
			assert_false(d["bands"]["upper"].intersects(r) or d["bands"]["lower"].intersects(r))
			var area := (r.size.x - 2) * (r.size.y - 2)
			if area > 60:
				var walls := 0
				for c: Vector2i in _cells(r.grow(-1)):
					if g.solid_at(c) == S.WALL and g.building_at(c) == int(b["id"]):
						walls += 1
				assert_gt(walls, 0)
				assert_gte(b["rooms"].size(), 2)
			if area > 300:
				assert_gte(b["rooms"].size(), 3)
			var windows := 0
			for c: Vector2i in g.windows:
				if g.building_at(c) == int(b["id"]):
					windows += 1
			assert_gte(windows, 2)
			for room: Dictionary in b["rooms"]:
				var boxes := 0
				var things := 0
				for box: Dictionary in d["containers"].values():
					if int(box["level"]) == 0 and room["rect"].has_point(box["cell"]):
						boxes += 1
						things += 1
				for prop: Dictionary in d["props"]:
					if room["rect"].intersects(prop["rect"]):
						things += 1
				for stove: Dictionary in d["stoves"]:
					if room["rect"].has_point(stove["cell"]):
						things += 1
				assert_gt(boxes, 0, room["name"])
				assert_gte(things, 3, room["name"])
		var starts: Array = []
		for mouth: Dictionary in mouths:
			var c: Vector2i = mouth["cell"]
			var out: Vector2i = mouth["outward"]
			starts.append(c)
			assert_true(g.dead_can_walk(c))
			var free := 0
			for depth in range(1, 5):
				for across in range(-2, 3):
					free += 1 if g.people_can_walk(c + out * depth + Vector2i(out.y, out.x) * across) else 0
			assert_gte(free, 16)
		var distances := _flood(g, starts)
		var deepest := 0
		for box: Dictionary in d["containers"].values():
			if int(box["level"]) == 0 and int(box["building"]) == 0:
				deepest = maxi(deepest, distances[g.index(box["cell"])])
		assert_gte(deepest, 25)
		var hut: Dictionary = d["buildings"][1]
		var hut_rect: Rect2i = hut["rect"]
		var outside_doors: Array = []
		for c: Vector2i in g.doors:
			if g.building_at(c) == 1 and not hut_rect.grow(-1).has_point(c):
				outside_doors.append(c)
		assert_eq(outside_doors.size(), 1)
		var side := "lower" if hut_rect.position.y > d["train"].position.y else "upper"
		var hut_distances := _flood(g, d["train_doors"][side])
		for c: Vector2i in outside_doors:
			assert_gte(hut_distances[g.index(c)], 30)


func test_crossings_and_asymmetry() -> void:
	for d: Dictionary in _maps:
		var g: FieldGrid = d["grid"]
		var train: Rect2i = d["train"]
		assert_eq(d["crossings"].size(), 3)
		for i in range(3):
			var crossing: Dictionary = d["crossings"][i]
			var x := train.position.x + 16 * (i + 1)
			assert_eq(crossing["who"], {"person": true, "zombie": false, "carrying": true, "wounded": false, "sled": false})
			assert_eq(crossing["cells"], [Vector2i(x, train.position.y), Vector2i(x, train.position.y + 1), Vector2i(x, train.position.y + 2)])
			for c: Vector2i in crossing["cells"]:
				assert_false(g.people_can_walk(c) or g.dead_can_walk(c))
			for c: Vector2i in [Vector2i(x, train.position.y - 1), Vector2i(x, train.end.y)]:
				assert_true(g.people_can_walk(c))
				assert_false(g.doors.has(c))
				assert_false(d["spawns"]["train_door"].has(c))
		var total := 0
		var matched := 0
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				if train.has_point(c) or not [S.WALL, S.BLOCK, S.LOW].has(g.solid_at(c)):
					continue
				total += 1
				var other := Vector2i(x, 2 * (train.position.y + 1) - y)
				if g.inside(other) and g.solid_at(c) == g.solid_at(other):
					matched += 1
		assert_lt(float(matched) / maxi(1, total), 0.5)


func test_prop_vocabulary_backing_and_reserved_cells() -> void:
	for d: Dictionary in _maps:
		var g: FieldGrid = d["grid"]
		var train: Rect2i = d["train"]
		assert_gte(d["props"].size(), 40)
		var kinds: Dictionary = {}
		var forbidden: Dictionary = {}
		for c: Vector2i in _door_apron(d) + d["barricade_slots"]:
			forbidden[c] = true
		for entry: Array in d["entries"].values():
			for c: Vector2i in entry:
				forbidden[c] = true
		for r: Rect2i in [Rect2i(train.position.x, train.position.y - 3, 80, 3), Rect2i(train.position.x, train.end.y, 80, 3), Rect2i(train.position.x - 12, train.position.y, 12, 3), Rect2i(train.end.x, train.position.y, 12, 3)]:
			for c: Vector2i in _cells(r):
				forbidden[c] = true
		for crossing: Dictionary in d["crossings"]:
			var x: int = crossing["cells"][0].x
			forbidden[Vector2i(x, train.position.y - 1)] = true
			forbidden[Vector2i(x, train.end.y)] = true
		for prop: Dictionary in d["props"]:
			kinds[prop["kind"]] = true
			assert_true(PROP_KINDS.has(prop["kind"]))
			assert_true(["low", "wall", "none"].has(prop["solid"]))
			assert_true(int(prop["facing"]) >= 0 and int(prop["facing"]) <= 3)
			var r: Rect2i = prop["rect"]
			assert_true(r.size.x > 0 and r.size.y > 0 and Rect2i(0, 0, g.width, g.height).encloses(r))
			for c: Vector2i in _cells(r):
				assert_false(forbidden.has(c), "%s 겹침 %s" % [prop["kind"], c])
				if prop["solid"] == "low":
					assert_eq(g.solid_at(c), S.LOW)
				elif prop["solid"] == "wall":
					assert_eq(g.solid_at(c), S.WALL)
			if prop["solid"] == "low":
				assert_true(d["low_blocks"].has(r))
		assert_gte(kinds.size(), 20)


func test_all_five_grids_comments_and_korean_names_are_distinct() -> void:
	var comments: Dictionary = {}
	var latin := RegEx.new()
	latin.compile("[A-Za-z]")
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var source := FileAccess.get_file_as_string(MAPS[i].resource_path)
		var first: String = source.get_slice("\n", 0)
		assert_true(first.begins_with("# 이 지도가 다른 판단을 만드는 것: "))
		assert_false(comments.has(first))
		comments[first] = true
		assert_false(source.contains("preload(\"res://game/world/sulehuf_map.gd\")"))
		for name: String in MAPS[i].ZONE_NAMES.values():
			assert_null(latin.search(name))
		for building: Dictionary in d["buildings"]:
			assert_null(latin.search(building["name"]))
		for j in range(i):
			var a: FieldGrid = d["grid"]
			var b: FieldGrid = _maps[j]["grid"]
			assert_false(a.width == b.width and a.height == b.height and a.solid == b.solid and a.floor == b.floor)
			var below_a: FieldGrid = d["levels"][-1]
			var below_b: FieldGrid = _maps[j]["levels"][-1]
			assert_false(below_a.width == below_b.width and below_a.height == below_b.height and below_a.solid == below_b.solid)


func test_entry_names_weights_first_entry_and_zone_names() -> void:
	var firsts: Dictionary = {}
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		assert_eq(d["zone_names"], MAPS[i].ZONE_NAMES)
		assert_true(["track_west_upper", "track_east_upper", "track_west_lower", "track_east_lower"].has(d["first_entry"]))
		firsts[d["first_entry"]] = true
		var shed_rect: Rect2i = d["buildings"][0]["rect"]
		var shed_up: bool = shed_rect.position.y < d["train"].position.y
		for side: String in ["upper", "lower"]:
			for end: String in ["west", "east"]:
				var key := "track_%s_%s" % [end, side]
				assert_true(String(d["entry_names"][key]).contains("차고" if (side == "upper") == shed_up else "오두막"))
		var ways: Array = d["entries"].keys()
		var named: Array = d["entry_names"].keys()
		var weighed: Array = d["entry_weights"].keys()
		ways.sort()
		named.sort()
		weighed.sort()
		assert_eq(named, ways)
		assert_eq(weighed, ways)
		assert_true(ways.has(d["first_entry"]))
		assert_eq(int(d["entry_levels"][d["first_entry"]]), 0, "첫 물결은 땅 위 길로 온다")
		var total := 0.0
		for way: String in ways:
			var name: String = d["entry_names"][way]
			assert_false(name.is_empty())
			assert_false(_has_roman(name), name)
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
			assert_false(_has_roman(String(d["zone_names"].get(z, ""))), z)
		for b: Dictionary in d["buildings"]:
			assert_false(_has_roman(String(b["name"])), String(b["name"]))
			for room: Dictionary in b["rooms"]:
				assert_false(_has_roman(String(room["name"])))
		for spot: Dictionary in d["spots"].values():
			assert_false(_has_roman(String(spot["name"])))
		for id in d["containers"]:
			var box_name := String(d["containers"][id].get("name", ""))
			assert_false(_has_roman(box_name), box_name)

	assert_gt(firsts.size(), 1)


func test_levels_stairs_and_small_cellar() -> void:
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var g: FieldGrid = d["grid"]
		var levels: Array = d["levels"].keys()
		levels.sort()
		assert_eq(levels, [-1, 0])
		assert_false(d["levels"].has(1) or d["levels"].has(2))
		assert_eq(d["upper_rects"], [])
		assert_eq(d["stairs"].size(), 1)
		assert_eq(d["spawns"]["dead_levels"], [])
		var below: FieldGrid = d["levels"][-1]
		assert_eq(Vector2i(below.width, below.height), Vector2i(g.width, g.height))
		var stair: Dictionary = d["stairs"][0]
		assert_eq(stair["low"], -1)
		assert_eq(stair["high"], 0)
		assert_false(stair["ladder"])
		var at: Vector2i = stair["cell"]
		assert_true(g.people_can_walk(at) and below.people_can_walk(at))
		assert_eq(g.building_at(at), 0)
		assert_false(_in_band(d, at))
		var reached := _flood(below, [at])
		for y in range(below.height):
			for x in range(below.width):
				var c := Vector2i(x, y)
				assert_eq(below.zone_at(c), "plow_shed")
				if below.people_can_walk(c):
					assert_gte(reached[below.index(c)], 0)
					assert_false(_in_band(d, c) or d["train"].has_point(c))
		var boxes := 0
		for box: Dictionary in d["containers"].values():
			if int(box["level"]) == -1:
				boxes += 1
				assert_true(below.people_can_walk(box["cell"]))
		assert_gte(boxes, 2)
		for room: Dictionary in MAPS[i].PLAN["underground"]["rooms"]:
			var a: Array = room["rect"]
			var r := Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))
			var stocked := false
			for box: Dictionary in d["containers"].values():
				stocked = stocked or (int(box["level"]) == -1 and r.has_point(box["cell"]))
			assert_true(stocked)


func test_summit_salvage_supplies_and_stoves() -> void:
	var allowed: Array[String] = ["scrap", "wood", "plank", "flare", "cloth", "food_pack", "bandage", "document"]
	for d: Dictionary in _maps:
		var g: FieldGrid = d["grid"]
		var plow := Rect2i()
		var plows := 0
		for prop: Dictionary in d["props"]:
			if prop["kind"] == "rail_plow":
				plow = prop["rect"]
				plows += 1
		assert_eq(plows, 1)
		for k in range(1, 5):
			var key := "plow_drive_%d" % k
			assert_true(d["spots"].has(key))
			var spot: Dictionary = d["spots"][key]
			var c: Vector2i = spot["cell"]
			assert_eq(spot["kind"], "salvage")
			assert_eq(spot["material"], "scrap")
			assert_eq(spot["amount"], 2)
			assert_eq(spot["state"], "intact")
			assert_true(g.people_can_walk(c))
			var dx := maxi(0, maxi(plow.position.x - c.x, c.x - plow.end.x + 1))
			var dy := maxi(0, maxi(plow.position.y - c.y, c.y - plow.end.y + 1))
			assert_lte(dx + dy, 2)
		for key: String in ["hut_radio_notes", "hut_engine_notes"]:
			assert_true(d["containers"].has(key))
			assert_eq(d["containers"][key]["building"], 1)
			assert_eq(d["containers"][key]["items"], ["document"])
		for box: Dictionary in d["containers"].values():
			# The pass's scrap is the plough's and the rails' alone (user decision 188).
			assert_false(box["items"].has("scrap"), box["id"])
			var keys: Array = box.keys()
			keys.sort()
			var expected: Array[String] = ["id", "name", "cell", "level", "building", "search", "items", "locked", "searched"]
			expected.sort()
			assert_eq(keys, expected)
			var lg: FieldGrid = d["levels"][int(box["level"])]
			assert_true(lg.people_can_walk(box["cell"]))
			assert_eq(box["building"], lg.building_at(box["cell"]))
			assert_eq(box["search"], 7 if int(box["level"]) == -1 else 5)
			assert_false(box["locked"] or box["searched"])
			for item: String in box["items"]:
				assert_true(allowed.has(item))
		for spot: Dictionary in d["spots"].values():
			assert_eq(spot["kind"], "salvage")
			assert_true(["scrap", "wood"].has(spot["material"]))
			assert_true(g.people_can_walk(spot["cell"]))
		assert_eq(d["wagons"], [])
		assert_eq(d["manholes"], {})
		assert_eq(d["manhole_levels"], {})
		assert_eq(d["sewer_names"], {})
		assert_eq(d["stoves"].size(), 2)
		for stove: Dictionary in d["stoves"]:
			assert_false(stove["lit"] or stove["upstairs"])
			assert_eq(stove["level"], 0)
			assert_eq(stove["building"], g.building_at(stove["cell"]))
			assert_eq(g.solid_at(stove["cell"]), S.LOW)
			for r: Rect2i in d["low_blocks"]:
				assert_false(r.has_point(stove["cell"]))


func test_summit_entries_width_and_edges() -> void:
	for d: Dictionary in _maps:
		var g: FieldGrid = d["grid"]
		var train: Rect2i = d["train"]
		var track_weight := 0.0
		var all_weight := 0.0
		for name: String in d["entries"]:
			var upper := false
			var lower := false
			for c: Vector2i in d["entries"][name]:
				upper = upper or c.y < train.position.y + 1
				lower = lower or c.y > train.position.y + 1
				assert_ne(c.y, train.position.y + 1)
				if name.begins_with("track_"):
					assert_false(c.y >= train.position.y and c.y < train.end.y)
			assert_ne(upper, lower)
			var weight := float(d["entry_weights"][name])
			all_weight += weight
			if name.begins_with("track_"):
				track_weight += weight
				assert_eq(weight, 2.0)
			else:
				assert_eq(weight, 1.5 if name == "access_road" else 0.5)
		assert_gte(track_weight / all_weight, 0.7)
		for r: Rect2i in [Rect2i(train.position.x - 12, train.position.y, 12, 3), Rect2i(train.end.x, train.position.y, 12, 3)]:
			for c: Vector2i in _cells(r):
				assert_true(g.people_can_walk(c))
				assert_eq(g.solid_at(c), S.NONE)
				assert_eq(g.floor_at(c), F.RAIL)
		for y in range(train.position.y, train.end.y):
			for x in range(g.width):
				var c := Vector2i(x, y)
				assert_eq(g.floor_at(c), F.RAIL)
				assert_eq(g.solid_at(c), S.BLOCK if train.has_point(c) else S.NONE)
		for side: String in ["upper", "lower"]:
			var band: Rect2i = d["bands"][side]
			var good := 0
			var direction := -1 if side == "upper" else 1
			for x in range(band.position.x, band.end.x):
				var y := train.position.y - 1 if side == "upper" else train.end.y
				var width := 0
				while g.people_can_walk(Vector2i(x, y)):
					width += 1
					y += direction
				good += 1 if width >= 8 and width <= 12 else 0
			assert_gte(good, 84)
		assert_true(d["trees"].size() >= 60 and d["trees"].size() <= 150)
		for c: Vector2i in d["trees"]:
			assert_false(c.x < 14 and c.y < 14)
			for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var run := 0
				while d["trees"].has(c + step * run):
					run += 1
				assert_lte(run, 6)
		assert_eq(d["interior_kind_slots"], [{"zone": "plow_shed", "kinds": ["empty", "raiders", "nest", "beasts"]}])
		assert_true(d["zone_names"].has("plow_shed"))
		for c: Vector2i in d["spawns"]["dead_shed"]:
			assert_eq(g.building_at(c), 0)
			assert_true(g.people_can_walk(c))
		for c: Vector2i in d["spawns"]["dead_ridge"]:
			assert_true(["ledge_hut", "ridge_edge"].has(g.zone_at(c)))
			assert_true(g.people_can_walk(c))


func test_shed_loop_and_two_stock_pockets() -> void:
	for d: Dictionary in _maps:
		var g: FieldGrid = d["grid"]
		for prop: Dictionary in d["props"]:
			if prop["kind"] != "rail_plow":
				continue
			var r: Rect2i = prop["rect"]
			for c: Vector2i in _cells(r.grow(1)):
				if not r.has_point(c):
					assert_true(g.people_can_walk(c), "제설기 둘레 순환 칸 %s" % c)
		var shed: Dictionary = d["buildings"][0]
		for room: Dictionary in shed["rooms"]:
			if not ["부품 창고", "연료 칸"].has(room["name"]):
				continue
			var r: Rect2i = room["rect"]
			var doors := 0
			for c: Vector2i in g.doors:
				if r.grow(1).has_point(c) and not r.has_point(c):
					doors += 1
			assert_eq(doors, 1, room["name"])
			var boxes := 0
			for box: Dictionary in d["containers"].values():
				if int(box["level"]) == 0 and r.has_point(box["cell"]):
					boxes += 1
			assert_gt(boxes, 0)


func _has_roman(text: String) -> bool:
	for i in range(text.length()):
		var c: int = text.unicode_at(i)
		# 로마자와 한자.
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 0x3400 and c <= 0x9FFF):
			return true
	return false


func _floor_prefix(g: FieldGrid, kind: int) -> PackedInt32Array:
	var prefix := PackedInt32Array()
	var stride: int = g.width + 1
	prefix.resize(stride * (g.height + 1))
	for y in range(g.height):
		var row := 0
		for x in range(g.width):
			var c := Vector2i(x, y)
			row += 1 if g.solid_at(c) == S.NONE and g.floor_at(c) == kind else 0
			prefix[(y + 1) * stride + x + 1] = prefix[y * stride + x + 1] + row
	return prefix


func _flood(g: FieldGrid, starts: Array, dead: bool = false, blocked: Dictionary = {}) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(g.width * g.height)
	result.fill(-1)
	var queue: Array[Vector2i] = []
	for c: Vector2i in starts:
		var walk: bool = g.dead_can_walk(c) if dead else g.people_can_walk(c)
		if walk and not blocked.has(c) and result[g.index(c)] < 0:
			result[g.index(c)] = 0
			queue.append(c)
	var cursor := 0
	while cursor < queue.size():
		var c: Vector2i = queue[cursor]
		cursor += 1
		for step: Vector2i in DIRECTIONS:
			var next := c + step
			var walk: bool = g.dead_can_walk(next) if dead else g.people_can_walk(next)
			if walk and not blocked.has(next) and result[g.index(next)] < 0:
				result[g.index(next)] = result[g.index(c)] + 1
				queue.append(next)
	return result


func _cells(r: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			result.append(Vector2i(x, y))
	return result


func _door_apron(d: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for side: String in ["upper", "lower"]:
		var step := Vector2i.UP if side == "upper" else Vector2i.DOWN
		for c: Vector2i in d["train_doors"][side]:
			for depth in range(3):
				for across in range(-1, 2):
					result.append(c + step * depth + Vector2i(across, 0))
	return result


func _in_band(d: Dictionary, c: Vector2i) -> bool:
	for band: Rect2i in d["bands"].values():
		if band.has_point(c):
			return true
	return false


