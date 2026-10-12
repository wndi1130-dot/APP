extends "res://addons/gut/test.gd"
## 선로 곁 빈 땅 세 장의 계약 검사. 건너뛰는 검사는 두지 않는다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const MAPS: Array = [
	preload("res://game/world/maps/bare_line_01.gd"),
	preload("res://game/world/maps/bare_line_02.gd"),
	preload("res://game/world/maps/bare_line_03.gd"),
]
const KEYS: Array[String] = [
	"grid", "levels", "stairs", "containers", "spots", "stoves", "entries",
	"buildings", "wagons", "train", "platform", "spawns", "labels", "trees",
	"low_blocks", "upper_rects", "train_cars", "lights", "manholes",
	"manhole_levels", "sewer_names", "entry_levels", "entry_gap", "unload",
	"place_id", "place_kind", "bands", "train_doors", "crossings",
	"barricade_slots", "interior_kind_slots", "props",
	"entry_names", "entry_weights", "first_entry", "zone_names", "slow_rects",
]
const PROP_KINDS: Array[String] = [
	"sleeper_stack", "rail_stack", "rail_marker", "power_pole", "signal_post",
	"fallen_signal", "snow_bank", "snow_drift", "fallen_log", "crate_stack",
	"tool_rack", "tool_bench", "shelf", "fuel_drum", "firewood_pile", "sled_load",
	"rail_handcar", "snow_fence", "plank_bridge", "ballast_pile", "wire_coil", "fallen_pole",
]
const ITEMS: Array[String] = ["scrap", "wood", "plank", "flare", "cloth", "food_pack", "bandage"]
const TRACK_ENTRIES: Array[String] = ["track_west_upper", "track_east_upper", "track_west_lower", "track_east_lower"]
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
	assert_eq(MAPS.size(), 3)
	assert_eq(_maps.size(), 3)
	assert_eq(KEYS.size(), 37)
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var g: FieldGrid = d["grid"]
		var expected: Array = KEYS.duplicate()
		expected.sort()
		assert_eq(_sorted_keys(d), expected)
		assert_true(g.width >= 136 and g.width <= 144 and g.height >= 76 and g.height <= 84)
		assert_eq(d["place_id"], "bare_line_%02d" % (i + 1))
		assert_eq(d["place_kind"], "bare_line")
		var zones: Dictionary = {}
		var t: Rect2i = d["train"]
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				var forest: bool = y > t.position.y + 1 if i == 1 else y < t.position.y + 1
				if i == 2:
					forest = forest and x * 2 >= g.width
				var z := "forest_side" if forest else "open_side"
				if y >= t.position.y - 10 and y < t.end.y + 10:
					z = "track_bank"
				assert_eq(g.zone_at(c), z)
				zones[g.zone_at(c)] = true
		assert_eq(_sorted_keys(zones), ["forest_side", "open_side", "track_bank"])
		assert_eq(d["zone_names"], MAPS[i].ZONE_NAMES)


func test_train_bands_and_clear_door_aprons() -> void:
	for d: Dictionary in _maps:
		var g: FieldGrid = d["grid"]
		var t: Rect2i = d["train"]
		assert_eq(t.size, Vector2i(80, 3))
		assert_true(t.position.x >= 12 and t.end.x + 12 <= g.width and t.position.y > 0 and t.end.y < g.height)
		assert_eq(d["platform"], Rect2i(t.position.x, t.end.y, 80, 3))
		assert_eq(d["unload"], Rect2i(t.position.x, t.position.y - 3, 80, 9))
		assert_eq(_sorted_keys(d["bands"]), ["lower", "upper"])
		for side: String in ["upper", "lower"]:
			var band: Rect2i = d["bands"][side]
			var by: int = t.position.y - 22 if side == "upper" else t.end.y
			assert_eq(band, Rect2i(t.position.x - 20, by, 120, 22))
			assert_true(Rect2i(0, 0, g.width, g.height).encloses(band))
			var expected: Array[Vector2i] = []
			for offset: int in [8, 40, 56]:
				expected.append(Vector2i(t.position.x + offset, t.position.y - 1 if side == "upper" else t.end.y))
			assert_eq(d["train_doors"][side], expected)
			for c: Vector2i in expected:
				assert_true(band.has_point(c) and d["unload"].has_point(c))
		assert_eq(d["spawns"]["train_door"], d["train_doors"]["lower"] + d["train_doors"]["upper"])
		var squad: Array[Vector2i] = []
		for x in range(t.position.x + 39, t.position.x + 43):
			squad.append(Vector2i(x, t.end.y + 1))
		assert_eq(d["spawns"]["squad"], squad)
		for c: Vector2i in _door_apron(d):
			assert_true(g.people_can_walk(c) and g.dead_can_walk(c), "문 앞 3칸 %s" % c)
		for c: Vector2i in _shoulders(d):
			assert_eq(g.solid_at(c), S.NONE)
			assert_eq(g.floor_at(c), F.GRAVEL)
		assert_eq(d["train_cars"].size(), 5)
		for k in range(5):
			assert_eq(d["train_cars"][k]["rect"], Rect2i(t.position.x + 16 * k, t.position.y, 16, 3))
			assert_eq(d["train_cars"][k]["kind"], "car" if k < 4 else "engine")
		# 본의 불빛 사전과 순서도 그대로 지킨다.
		var lights: Array = []
		for k in range(5):
			var r := Rect2i(t.position.x + k * 16, t.position.y, 16, 3)
			if k == 4:
				lights.append({"id": "firebox", "kind": "firebox", "cell": Vector2i(r.position.x + 2, r.end.y - 1), "side": Vector2i(0, 1), "strength": 0.8, "falls": 0.8, "reach": 4.0, "when": "always", "from_min": 0})
			else:
				for side: int in [-1, 1]:
					var y := r.position.y if side < 0 else r.end.y - 1
					for win in range(4):
						lights.append({"id": "car%d_%d_window%d" % [k + 1, side, win + 1], "kind": "car_window", "cell": Vector2i(r.position.x + 3 + win * 3, y), "side": Vector2i(0, side), "strength": 1.0, "falls": 0.6, "reach": 3.0, "when": "dusk", "from_min": 890})
		assert_eq(d["lights"], lights)


func test_entries_spawns_and_access_even_after_barricading() -> void:
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var g: FieldGrid = d["grid"]
		var ways: Array = TRACK_ENTRIES.duplicate()
		ways.append_array(["forest_edge", "open_field"])
		if i == 2:
			ways.append("forest_gap")
		ways.sort()
		assert_eq(_sorted_keys(d["entries"]), ways)
		assert_eq(_sorted_keys(d["entry_gap"]), ways)
		assert_eq(_sorted_keys(d["entry_levels"]), ways)
		for name: String in ways:
			assert_eq(int(d["entry_levels"][name]), 0)
			assert_eq(float(d["entry_gap"][name]), 2.0 if name.begins_with("forest_") else 0.6)
			assert_true(float(d["entry_gap"][name]) > 0.0 and float(d["entry_gap"][name]) <= 3.0)
			for c: Vector2i in d["entries"][name]:
				assert_false(_in_band(d, c))
				assert_true(g.dead_can_walk(c) and _dead[i][g.index(c)] >= 0)
		assert_eq(_sorted_keys(d["spawns"]), ["dead_field", "dead_forest", "dead_levels", "squad", "train_door"])
		for name: String in ["dead_forest", "dead_field"]:
			var count: int = d["spawns"][name].size()
			assert_true(count >= (3 if name == "dead_forest" else 2) and count <= (5 if name == "dead_forest" else 3))
			for c: Vector2i in d["spawns"][name]:
				assert_false(_in_band(d, c))
				assert_eq(g.building_at(c), -1)
				assert_true(g.dead_can_walk(c))
		var unreachable := 0
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				if g.people_can_walk(c) and _people[i][g.index(c)] < 0:
					unreachable += 1
		assert_eq(unreachable, 0)
		var blocked: Dictionary = {}
		for c: Vector2i in d["barricade_slots"]:
			assert_true(g.people_can_walk(c))
			blocked[c] = true
		var distances := _flood(g, [d["spawns"]["train_door"][0]], false, blocked)
		var reached: Dictionary = {}
		for index in range(g.width * g.height):
			if distances[index] >= 0:
				reached[g.zone[index]] = true
		assert_eq(_sorted_keys(reached), ["forest_side", "open_side", "track_bank"])


func test_barricades_span_real_short_gaps() -> void:
	for d: Dictionary in _maps:
		var g: FieldGrid = d["grid"]
		var counts := {"upper": 0, "lower": 0}
		var unique: Dictionary = {}
		for c: Vector2i in d["barricade_slots"]:
			assert_false(unique.has(c))
			unique[c] = true
		for group: Array in _slot_groups(d):
			assert_true(group.size() >= 2 and group.size() <= 3)
			var first: Vector2i = group[0]
			var min_x: int = first.x
			var max_x: int = first.x
			var side := "upper" if first.y < d["train"].position.y else "lower"
			counts[side] += 1
			for c: Vector2i in group:
				assert_eq(c.y, first.y)
				assert_true(d["bands"][side].has_point(c) and g.people_can_walk(c))
				min_x = mini(min_x, c.x)
				max_x = maxi(max_x, c.x)
			assert_eq(max_x - min_x + 1, group.size())
			for c: Vector2i in [Vector2i(min_x - 1, first.y), Vector2i(max_x + 1, first.y)]:
				assert_true([S.WALL, S.LOW].has(g.solid_at(c)))
				assert_false(g.people_can_walk(c))
			var at_gap := false
			for gap: Rect2i in _ditch_gaps(d, side):
				var row: int = gap.end.y if side == "upper" else gap.position.y - 1
				at_gap = at_gap or (first.y == row and min_x >= gap.position.x and max_x < gap.end.x)
			assert_true(at_gap, "방벽은 도랑 틈에서 열차 쪽 한 줄 앞")
		for side: String in counts:
			assert_true(counts[side] >= 2 and counts[side] <= 3)
			# 모든 짧은 틈과 도랑을 막아도 같은 쪽의 띠 밖으로 나가는 열린 변.
			var blocked: Dictionary = unique.duplicate()
			for r: Rect2i in d["slow_rects"]:
				for c: Vector2i in _cells(r):
					blocked[c] = true
			var distances := _flood(g, d["train_doors"][side], false, blocked)
			var outside := false
			for name: String in d["entries"]:
				for c: Vector2i in d["entries"][name]:
					var same_side: bool = c.y < d["train"].position.y if side == "upper" else c.y >= d["train"].end.y
					outside = outside or (same_side and not _in_band(d, c) and distances[g.index(c)] >= 0)
			assert_true(outside)


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
			var horizontal := false
			var vertical := false
			for r: Rect2i in d["low_blocks"]:
				if not d["bands"][side].intersects(r):
					continue
				count += 1
				shapes[r.size] = true
				horizontal = horizontal or r.size.x > r.size.y
				vertical = vertical or r.size.y > r.size.x
				assert_true(maxi(r.size.x, r.size.y) >= 2 and maxi(r.size.x, r.size.y) <= 6)
				var close := false
				for c: Vector2i in d["train_doors"][side]:
					var dx := maxi(0, maxi(r.position.x - c.x, c.x - r.end.x + 1))
					var dy := maxi(0, maxi(r.position.y - c.y, c.y - r.end.y + 1))
					close = close or dx + dy <= 12
				near += 1 if close else 0
			assert_true(count >= 3 and count <= 5 and near >= 2 and shapes.size() >= 2)
			assert_true(horizontal and vertical)
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
						visible = visible or (int(stove["level"]) == 0 and stove["cell"] == c)
					missing_low += 0 if visible else 1
					for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
						var n := 0
						while g.inside(c + step * n) and g.solid_at(c + step * n) == S.LOW:
							n += 1
						longest = maxi(longest, n)
				if g.solid_at(c) == S.BLOCK and g.building_at(c) < 0:
					var visible: bool = d["train"].has_point(c) or d["trees"].has(c)
					hidden_block += 0 if visible and not (x < 14 and y < 14) else 1
		assert_eq(missing_low, 0)
		assert_eq(hidden_block, 0)
		assert_true(longest <= 10)
		assert_true(d["trees"].size() >= 90 and d["trees"].size() <= 200)
		assert_true(d["wagons"].is_empty())


func test_crossings_and_asymmetry() -> void:
	for d: Dictionary in _maps:
		var g: FieldGrid = d["grid"]
		var t: Rect2i = d["train"]
		assert_eq(d["crossings"].size(), 3)
		for k in range(3):
			var crossing: Dictionary = d["crossings"][k]
			var x: int = t.position.x + 16 * (k + 1)
			var expected: Array[Vector2i] = [Vector2i(x, t.position.y), Vector2i(x, t.position.y + 1), Vector2i(x, t.position.y + 2)]
			assert_eq(crossing["cells"], expected)
			assert_eq(crossing["who"], {"person": true, "zombie": false, "carrying": true, "wounded": false, "sled": false})
			for c: Vector2i in crossing["cells"]:
				assert_eq(g.solid_at(c), S.BLOCK)
				assert_false(g.people_can_walk(c))
				assert_false(g.dead_can_walk(c))
			for c: Vector2i in [Vector2i(x, t.position.y - 1), Vector2i(x, t.end.y)]:
				assert_true(g.people_can_walk(c))
				assert_false(d["spawns"]["train_door"].has(c))
				assert_eq(g.solid_at(c), S.NONE)
		var total := 0
		var matched := 0
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				if t.has_point(c) or not [S.WALL, S.BLOCK, S.LOW].has(g.solid_at(c)):
					continue
				total += 1
				var other := Vector2i(x, 2 * (t.position.y + 1) - y)
				if g.inside(other) and g.solid_at(c) == g.solid_at(other):
					matched += 1
		assert_true(float(matched) / maxi(1, total) < 0.5)


func test_prop_vocabulary_backing_and_reserved_cells() -> void:
	assert_eq(PROP_KINDS.size(), 22)
	for d: Dictionary in _maps:
		var g: FieldGrid = d["grid"]
		var kinds: Dictionary = {}
		var forbidden: Dictionary = {}
		for c: Vector2i in _door_apron(d) + d["barricade_slots"] + _crossing_ends(d) + _tails(d) + _shoulders(d):
			forbidden[c] = true
		for name: String in d["entries"]:
			for c: Vector2i in d["entries"][name]:
				forbidden[c] = true
		assert_true(d["props"].size() >= 40)
		for prop: Dictionary in d["props"]:
			assert_eq(_sorted_keys(prop), ["facing", "kind", "note", "rect", "solid"])
			assert_true(PROP_KINDS.has(prop["kind"]))
			kinds[prop["kind"]] = true
			assert_true(["low", "wall", "none"].has(prop["solid"]))
			assert_true(int(prop["facing"]) >= 0 and int(prop["facing"]) <= 3)
			assert_false(String(prop["note"]).is_empty())
			var r: Rect2i = prop["rect"]
			assert_true(r.size.x > 0 and r.size.y > 0 and Rect2i(0, 0, g.width, g.height).encloses(r))
			for c: Vector2i in _cells(r):
				assert_false(forbidden.has(c), "%s 겹침 %s" % [prop["kind"], c])
				if prop["solid"] == "low":
					assert_eq(g.solid_at(c), S.LOW)
				elif prop["solid"] == "wall":
					assert_eq(g.solid_at(c), S.WALL)
				else:
					assert_eq(g.solid_at(c), S.NONE)
			if prop["solid"] == "low":
				assert_true(d["low_blocks"].has(r))
				var matches := 0
				for low: Rect2i in d["low_blocks"]:
					matches += 1 if low == r else 0
				assert_eq(matches, 1)
		assert_true(kinds.size() >= 12)
		for r: Rect2i in d["low_blocks"]:
			var backed := 0
			for prop: Dictionary in d["props"]:
				backed += 1 if prop["solid"] == "low" and prop["rect"] == r else 0
			assert_eq(backed, 1)


func test_building_and_ground_level_only() -> void:
	for d: Dictionary in _maps:
		var g: FieldGrid = d["grid"]
		assert_eq(d["buildings"].size(), 1)
		var b: Dictionary = d["buildings"][0]
		var r: Rect2i = b["rect"]
		var inner := r.grow(-1)
		assert_eq(_sorted_keys(b), ["id", "name", "rect", "rooms", "warm", "window_broken"])
		assert_eq(b["id"], 0)
		assert_eq(b["name"], "선로 창고")
		assert_false(b["warm"])
		assert_false(b["window_broken"])
		assert_false(b.has("entrances"))
		assert_true(inner.size.x > 0 and inner.size.y > 0 and inner.get_area() <= 60)
		for band: Rect2i in d["bands"].values():
			assert_false(band.intersects(r))
		assert_eq(g.doors.size(), 1)
		assert_true(g.windows.size() >= 1)
		for c: Vector2i in g.doors:
			assert_true(r.has_point(c) and not inner.has_point(c))
			assert_eq(g.solid_at(c), S.DOOR)
			assert_eq(g.doors[c]["building"], 0)
			assert_eq(g.doors[c]["state"], "closed")
			assert_true(g.people_can_walk(c))
			assert_false(g.dead_can_walk(c))
		for c: Vector2i in g.windows:
			assert_true(r.has_point(c) and not inner.has_point(c))
			assert_eq(g.solid_at(c), S.WINDOW)
			assert_eq(g.windows[c]["building"], 0)
			assert_false(g.windows[c]["broken"])
		assert_eq(b["rooms"].size(), 1)
		assert_eq(b["rooms"][0]["name"], "연장 칸")
		assert_eq(b["rooms"][0]["rect"], inner)
		var stored := 0
		for box: Dictionary in d["containers"].values():
			assert_eq(_sorted_keys(box), ["building", "cell", "id", "items", "level", "locked", "name", "search", "searched"])
			assert_eq(int(box["level"]), 0)
			assert_eq(int(box["building"]), g.building_at(box["cell"]))
			assert_eq(int(box["building"]), 0)
			assert_eq(box["search"], 5)
			assert_false(box["locked"])
			assert_false(box["searched"])
			stored += 1 if inner.has_point(box["cell"]) else 0
		assert_eq(stored, 2)
		var furniture: Dictionary = {}
		for prop: Dictionary in d["props"]:
			if inner.encloses(prop["rect"]) and prop["solid"] == "low":
				furniture[prop["kind"]] = true
		assert_true(furniture.has("shelf") and furniture.has("tool_bench"))
		assert_eq(d["levels"].keys(), [0])
		assert_eq(d["levels"][0], g)
		for name: String in ["stairs", "upper_rects", "interior_kind_slots", "wagons"]:
			assert_true(d[name].is_empty())
		for name: String in ["manholes", "manhole_levels", "sewer_names"]:
			assert_true(d[name].is_empty())
		assert_eq(d["spawns"]["dead_levels"], [])
		assert_eq(d["stoves"].size(), 1)
		var stove: Dictionary = d["stoves"][0]
		assert_eq(_sorted_keys(stove), ["building", "cell", "level", "lit", "upstairs"])
		assert_eq(stove["building"], 0)
		assert_eq(stove["level"], 0)
		assert_false(stove["lit"])
		assert_false(stove["upstairs"])
		assert_true(inner.has_point(stove["cell"]))
		assert_eq(g.solid_at(stove["cell"]), S.LOW)
		for low: Rect2i in d["low_blocks"]:
			assert_false(low.has_point(stove["cell"]))
		assert_eq(d["labels"].size(), 2)
		assert_eq(d["labels"][0]["text"], b["name"])
		assert_eq(d["labels"][1]["text"], b["rooms"][0]["name"])


func test_shallow_loot_and_store_distance() -> void:
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var g: FieldGrid = d["grid"]
		for box: Dictionary in d["containers"].values():
			assert_true(g.people_can_walk(box["cell"]) and _people[i][g.index(box["cell"])] >= 0)
			assert_true(box["items"] is Array)
			for item: String in box["items"]:
				assert_true(ITEMS.has(item))
		var salvage := 0
		var sides: Dictionary = {}
		for spot: Dictionary in d["spots"].values():
			assert_eq(spot["kind"], "salvage")
			assert_true(["scrap", "wood"].has(spot["material"]))
			assert_gt(int(spot["amount"]), 0)
			var c: Vector2i = spot["cell"]
			assert_true(g.people_can_walk(c) and _people[i][g.index(c)] >= 0)
			sides["upper" if c.y < d["train"].position.y else "lower"] = true
			salvage += 1
		assert_true(salvage >= 4 and salvage <= 6)
		assert_eq(sides.size(), 2)
		var door: Vector2i = g.doors.keys()[0]
		assert_gte(_people[i][g.index(door)], 30)


func test_entry_sides_track_and_forest_share() -> void:
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var g: FieldGrid = d["grid"]
		var t: Rect2i = d["train"]
		for name: String in d["entries"]:
			var upper: bool = d["entries"][name][0].y < t.position.y + 1
			for c: Vector2i in d["entries"][name]:
				assert_eq(c.y < t.position.y + 1, upper)
				assert_true(c.x == 0 or c.x == g.width - 1 or c.y == 0 or c.y == g.height - 1)
			if TRACK_ENTRIES.has(name):
				var x: int = 0 if name.contains("_west_") else g.width - 1
				var y: int = t.position.y - 3 if name.ends_with("_upper") else t.end.y
				assert_eq(d["entries"][name], [Vector2i(x, y), Vector2i(x, y + 1), Vector2i(x, y + 2)])
			elif name == "open_field":
				assert_eq(d["entries"][name].size(), 4)
			else:
				assert_true(d["entries"][name].size() >= 2 and d["entries"][name].size() <= 3)
		for c: Vector2i in _tails(d):
			assert_eq(g.solid_at(c), S.NONE)
			assert_true(g.people_can_walk(c))
		for y in range(t.position.y, t.end.y):
			for x in range(g.width):
				assert_eq(g.floor_at(Vector2i(x, y)), F.RAIL)
		for kind: int in g.floor:
			assert_ne(kind, F.PLATFORM)
		var forest := 0
		var unique: Dictionary = {}
		for c: Vector2i in d["trees"]:
			assert_false(unique.has(c))
			unique[c] = true
			assert_true(g.inside(c))
			assert_eq(g.solid_at(c), S.BLOCK)
			assert_false(c.x < 14 and c.y < 14)
			var on_side: bool = c.y > t.position.y + 1 if i == 1 else c.y < t.position.y + 1
			if i == 2:
				on_side = on_side and c.x * 2 >= g.width
			forest += 1 if on_side else 0
		assert_true(d["trees"].size() >= 90 and d["trees"].size() <= 200)
		assert_gte(float(forest) / d["trees"].size(), 0.8)
		for c: Vector2i in d["trees"]:
			for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var length := 0
				while unique.has(c + step * length):
					length += 1
				assert_true(length <= 6)


func test_slow_rects_and_crossable_gaps() -> void:
	for d: Dictionary in _maps:
		var g: FieldGrid = d["grid"]
		var t: Rect2i = d["train"]
		assert_true(d["slow_rects"].size() >= 4)
		var forbidden: Dictionary = {}
		for c: Vector2i in _door_apron(d) + d["barricade_slots"] + _crossing_ends(d):
			forbidden[c] = true
		for name: String in d["entries"]:
			for c: Vector2i in d["entries"][name]:
				forbidden[c] = true
		for name: String in d["spawns"]:
			if name != "dead_levels":
				for c: Vector2i in d["spawns"][name]:
					forbidden[c] = true
		var blocked: Dictionary = {}
		for j in range(d["slow_rects"].size()):
			var r: Rect2i = d["slow_rects"][j]
			assert_true(Rect2i(0, 0, g.width, g.height).encloses(r))
			assert_true(r.size.x >= 12 and r.size.x <= 40 and r.size.y >= 2 and r.size.y <= 3)
			var side := "upper" if r.end.y <= t.position.y else "lower"
			assert_true(d["bands"][side].encloses(r))
			for k in range(j):
				assert_false(r.intersects(d["slow_rects"][k]))
			for c: Vector2i in _cells(r):
				var distance: int = t.position.y - 1 - c.y if side == "upper" else c.y - t.end.y
				assert_true(distance >= 5 and distance <= 8)
				assert_true(g.people_can_walk(c))
				assert_eq(g.floor_at(c), F.SNOW)
				assert_false(forbidden.has(c))
				blocked[c] = true
		for side: String in ["upper", "lower"]:
			var rows := _side_ditches(d, side)
			assert_true(rows.size() >= 3 and rows.size() <= 4)
			var gaps := _ditch_gaps(d, side)
			assert_true(gaps.size() >= 2)
			assert_eq(gaps.size(), rows.size() - 1)
			for gap: Rect2i in gaps:
				assert_true(gap.size.x >= 3 and gap.size.x <= 6)
				for c: Vector2i in _cells(gap):
					assert_true(g.people_can_walk(c))
					assert_false(blocked.has(c))
			var distances := _flood(g, d["train_doors"][side], false, blocked)
			var reached := false
			for name: String in d["entries"]:
				for c: Vector2i in d["entries"][name]:
					var same_side: bool = c.y < t.position.y if side == "upper" else c.y >= t.end.y
					reached = reached or (same_side and not _in_band(d, c) and distances[g.index(c)] >= 0)
			assert_true(reached)


func test_visible_store_routes_survive_one_gap_closure() -> void:
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var g: FieldGrid = d["grid"]
		var door: Vector2i = g.doors.keys()[0]
		var approach: Vector2i = door + (Vector2i.UP if i == 2 else Vector2i.DOWN)
		var side := "lower" if i == 2 else "upper"
		var bridges := 0
		for prop: Dictionary in d["props"]:
			if prop["kind"] != "plank_bridge":
				continue
			var r: Rect2i = prop["rect"]
			if (r.position.y < d["train"].position.y) != (side == "upper"):
				continue
			bridges += 1
			var blocked: Dictionary = {}
			var found := false
			for gap: Rect2i in _ditch_gaps(d, side):
				if gap.encloses(r):
					found = true
					for c: Vector2i in _cells(gap):
						blocked[c] = true
			assert_true(found)
			var route := _flood(g, d["train_doors"][side], false, blocked, true)
			assert_gte(route[g.index(approach)], 0, "건너는 틈 하나를 모두 닫아도 바닥으로 읽히는 다른 창고 길")
		assert_true(bridges >= 2)


func test_prop_clusters_pole_spacing_and_staggered_fences() -> void:
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var useful := 0
		for group: Array in _prop_clusters(d["props"]):
			useful += 1 if group.size() >= 3 and group.size() <= 6 else 0
		assert_true(useful >= 5, "네모 사이 세 칸 이내로 연결한 물건 무리")
		var stations: Array[Vector2i] = []
		var fences: Array[Rect2i] = []
		var fallen := 0
		var signals := 0
		for prop: Dictionary in d["props"]:
			if prop["kind"] == "power_pole" or prop["kind"] == "fallen_pole":
				stations.append(prop["rect"].position)
				if prop["kind"] == "power_pole":
					assert_eq(prop["solid"], "wall")
					assert_eq(prop["rect"].size, Vector2i.ONE)
				else:
					fallen += 1
			if prop["kind"] == "signal_post":
				signals += 1
			if prop["kind"] == "snow_fence":
				fences.append(prop["rect"])
				assert_eq(prop["rect"].size, Vector2i(5, 1))
				assert_eq(prop["solid"], "low")
				var distance: int = absi(prop["rect"].position.y - (d["train"].position.y + 1))
				assert_true(distance >= 12 and distance <= 25)
		assert_true(fallen >= 1 and fallen <= 2)
		assert_eq(signals, 1)
		stations.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
		for j in range(1, stations.size()):
			var gap: int = stations[j].x - stations[j - 1].x
			assert_true(gap >= 12 and gap <= 16)
			assert_eq(stations[j].y, stations[0].y)
		assert_eq(fences.size(), 5 if i == 2 else 3)
		var fence_rows: Dictionary = {}
		for j in range(fences.size()):
			fence_rows[fences[j].position.y] = true
			for k in range(j):
				assert_true(_rect_distance(fences[j], fences[k]) >= 3, "울타리 토막 사이 빈 칸 두 개 이상")
		assert_true(fence_rows.size() >= 2)
		if i == 2:
			assert_eq(fence_rows.size(), 2)


func test_all_three_grids_comments_and_korean_names_are_distinct() -> void:
	var comments: Dictionary = {}
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var source := FileAccess.get_file_as_string(MAPS[i].resource_path)
		var first: String = source.get_slice("\n", 0)
		assert_true(first.begins_with("# 이 지도가 다른 판단을 만드는 것: "))
		assert_false(comments.has(first))
		comments[first] = true
		assert_false(source.contains("preload(\"res://game/world/sulehuf_map.gd\")"))
		assert_false(source.contains("preload(\"res://game/world/maps/"))
		for j in range(i):
			var a: FieldGrid = d["grid"]
			var b: FieldGrid = _maps[j]["grid"]
			assert_false(a.width == b.width and a.height == b.height and a.solid == b.solid and a.floor == b.floor)


func test_entry_names_weights_first_entry_and_zone_names() -> void:
	var first_entries: Dictionary = {}
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var ways: Array = _sorted_keys(d["entries"])
		assert_eq(_sorted_keys(d["entry_names"]), ways)
		assert_eq(_sorted_keys(d["entry_weights"]), ways)
		assert_eq(d["entry_names"], MAPS[i].ENTRY_NAMES)
		assert_eq(d["entry_weights"], MAPS[i].ENTRY_WEIGHTS)
		assert_eq(d["zone_names"], MAPS[i].ZONE_NAMES)
		assert_true(TRACK_ENTRIES.has(d["first_entry"]))
		assert_false(first_entries.has(d["first_entry"]))
		first_entries[d["first_entry"]] = true
		assert_eq(int(d["entry_levels"][d["first_entry"]]), 0)
		var names: Array = d["zone_names"].values() + d["entry_names"].values()
		var total := 0.0
		for way: String in ways:
			var weight: float = float(d["entry_weights"][way])
			assert_eq(weight, 1.5 if TRACK_ENTRIES.has(way) else 1.0)
			total += weight
			var expected := "트인 눈밭" if way == "open_field" else "숲 가장자리"
			if way == "forest_gap":
				expected = "숲이 끊긴 자리"
			elif TRACK_ENTRIES.has(way):
				var west := way.contains("_west_")
				var upper := way.ends_with("_upper")
				expected = "서쪽 선로" if west else "동쪽 선로"
				if i == 2:
					expected += ", " + (("위 눈밭 쪽" if upper else "아래 눈밭 쪽") if west else ("숲 쪽" if upper else "눈밭 쪽"))
				else:
					var forest: bool = upper if i == 0 else not upper
					expected += ", " + ("숲 쪽" if forest else "눈밭 쪽")
			assert_eq(d["entry_names"][way], expected)
		assert_gt(total, 0.0)
		for b: Dictionary in d["buildings"]:
			names.append(b["name"])
			for room: Dictionary in b["rooms"]:
				names.append(room["name"])
		for box: Dictionary in d["containers"].values():
			names.append(box["name"])
		for spot: Dictionary in d["spots"].values():
			names.append(spot["name"])
		for label: Dictionary in d["labels"]:
			names.append(label["text"])
		for name: String in names:
			assert_false(name.is_empty())
			assert_false(_has_roman(name), name)


func _has_roman(text: String) -> bool:
	for i in range(text.length()):
		var c: int = text.unicode_at(i)
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 0x3400 and c <= 0x9FFF) or (c >= 0xF900 and c <= 0xFAFF):
			return true
	return false


func _sorted_keys(d: Dictionary) -> Array:
	var keys: Array = d.keys()
	keys.sort()
	return keys


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


func _flood(g: FieldGrid, starts: Array, dead: bool = false, blocked: Dictionary = {}, visible: bool = false) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(g.width * g.height)
	result.fill(-1)
	var queue: Array[Vector2i] = []
	for c: Vector2i in starts:
		var walk: bool = g.dead_can_walk(c) if dead else g.people_can_walk(c)
		walk = walk and (not visible or g.floor_at(c) != F.SNOW)
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
			walk = walk and (not visible or g.floor_at(next) != F.SNOW)
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


func _shoulders(d: Dictionary) -> Array[Vector2i]:
	var t: Rect2i = d["train"]
	return _cells(Rect2i(t.position.x, t.position.y - 3, 80, 3)) + _cells(Rect2i(t.position.x, t.end.y, 80, 3))


func _tails(d: Dictionary) -> Array[Vector2i]:
	var t: Rect2i = d["train"]
	return _cells(Rect2i(t.position.x - 12, t.position.y, 12, 3)) + _cells(Rect2i(t.end.x, t.position.y, 12, 3))


func _crossing_ends(d: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var t: Rect2i = d["train"]
	for offset: int in [16, 32, 48]:
		result.append(Vector2i(t.position.x + offset, t.position.y - 1))
		result.append(Vector2i(t.position.x + offset, t.end.y))
	return result


func _in_band(d: Dictionary, c: Vector2i) -> bool:
	for band: Rect2i in d["bands"].values():
		if band.has_point(c):
			return true
	return false


func _slot_groups(d: Dictionary) -> Array:
	var remaining: Dictionary = {}
	for c: Vector2i in d["barricade_slots"]:
		remaining[c] = true
	var result: Array = []
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
		result.append(group)
	return result


func _side_ditches(d: Dictionary, side: String) -> Array[Rect2i]:
	var rows: Array[Rect2i] = []
	for r: Rect2i in d["slow_rects"]:
		if (r.position.y < d["train"].position.y) == (side == "upper"):
			rows.append(r)
	rows.sort_custom(func(a: Rect2i, b: Rect2i) -> bool: return a.position.x < b.position.x)
	return rows


func _ditch_gaps(d: Dictionary, side: String) -> Array[Rect2i]:
	var rows := _side_ditches(d, side)
	var result: Array[Rect2i] = []
	for i in range(1, rows.size()):
		var a: Rect2i = rows[i - 1]
		var b: Rect2i = rows[i]
		var width: int = b.position.x - a.end.x
		if width >= 3 and width <= 6:
			var top: int = mini(a.position.y, b.position.y)
			var bottom: int = maxi(a.end.y, b.end.y)
			result.append(Rect2i(a.end.x, top, width, bottom - top))
	return result


func _rect_distance(a: Rect2i, b: Rect2i) -> int:
	var dx := maxi(0, maxi(a.position.x - b.end.x + 1, b.position.x - a.end.x + 1))
	var dy := maxi(0, maxi(a.position.y - b.end.y + 1, b.position.y - a.end.y + 1))
	return maxi(dx, dy)


func _prop_clusters(props: Array) -> Array:
	var seen: Dictionary = {}
	var result: Array = []
	for i in range(props.size()):
		if seen.has(i):
			continue
		var group: Array[int] = [i]
		seen[i] = true
		var cursor := 0
		while cursor < group.size():
			var r: Rect2i = props[group[cursor]]["rect"]
			cursor += 1
			for j in range(props.size()):
				if not seen.has(j) and _rect_distance(r, props[j]["rect"]) <= 3:
					seen[j] = true
					group.append(j)
		result.append(group)
	return result
