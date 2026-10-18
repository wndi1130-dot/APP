extends "res://addons/gut/test.gd"
## 탄광 지도 아홉 장의 계약 검사.
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const MAPS: Array = [
	preload("res://game/world/maps/mine_01.gd"),
	preload("res://game/world/maps/mine_02.gd"),
	preload("res://game/world/maps/mine_03.gd"),
	preload("res://game/world/maps/mine_04.gd"),
	preload("res://game/world/maps/mine_05.gd"),
	preload("res://game/world/maps/mine_06.gd"),
	preload("res://game/world/maps/mine_07.gd"),
	preload("res://game/world/maps/mine_08.gd"),
	preload("res://game/world/maps/mine_09.gd"),
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
	"rock_face", "rock_ridge", "mine_portal", "support_frame", "rubble_pile",
	"boulder", "vent_pipe", "mine_track", "ore_cart", "ore_cart_tipped",
	"track_switch", "buffer_stop", "rail_marker", "sleeper_stack",
	"coal_wagon", "coal_heap", "slag_heap",
	"hopper", "conveyor", "coal_sorter", "weigh_scale", "tool_rack", "pit_props",
	"fuel_drum", "water_barrel", "scrap_stack", "crate_stack", "ore_truck",
	"power_pole", "drain_ditch", "snow_bank", "spruce", "dry_grass",
]
const CONTAINER_SUFFIXES: Array[String] = [
	"상자", "보관함", "묶음", "선반", "자재함", "궤", "찬장", "공구함", "책상", "침대", "옷장",
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
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var g: FieldGrid = d["grid"]
		var keys: Array = d.keys()
		var allowed: Array = KEYS.duplicate()
		keys.sort()
		allowed.sort()
		assert_eq(keys, allowed)
		assert_true(g.width >= 150 and g.width <= 180 and g.height >= 90 and g.height <= 110)
		assert_eq(d["place_id"], "mine_%02d" % (i + 1))
		assert_eq(d["place_kind"], "mine")
		var zones: Dictionary = {}
		for z: String in g.zone:
			if z != "":
				zones[z] = true
		assert_true(zones.size() >= 3 and zones.size() <= 6)
		assert_false(zones.has("below"), "지하 구역은 지상 구역 수에서 제외")


func test_train_bands_and_clear_door_aprons() -> void:
	for d: Dictionary in _maps:
		var g: FieldGrid = d["grid"]
		var train: Rect2i = d["train"]
		assert_eq(train.size, Vector2i(80, 3))
		assert_true(train.position.x > 0 and train.position.y > 0 and train.end.x < g.width and train.end.y < g.height)
		assert_eq(d["train_cars"].size(), 5)
		for side: String in ["upper", "lower"]:
			var band: Rect2i = d["bands"][side]
			assert_eq(band.size.x, 120)
			assert_true(band.size.y >= 20 and band.size.y <= 25)
			assert_true(Rect2i(0, 0, g.width, g.height).encloses(band))
			assert_eq(band.end.y if side == "upper" else band.position.y, train.position.y if side == "upper" else train.end.y)
			assert_true(d["train_doors"][side].size() >= 1)
			for c: Vector2i in d["train_doors"][side]:
				assert_true(band.has_point(c) and d["unload"].has_point(c))
				assert_true(d["spawns"]["train_door"].has(c))
		for c: Vector2i in _door_apron(d):
			assert_true(g.people_can_walk(c) and g.dead_can_walk(c), "문 앞 3칸 %s" % c)


func test_entries_spawns_and_access_even_after_barricading() -> void:
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var g: FieldGrid = d["grid"]
		assert_true(d["entries"].size() >= 2)
		for name: String in d["entries"]:
			assert_true(d["entry_gap"].has(name))
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
			for c: Vector2i in group:
				assert_eq(c.y, first.y)
				min_x = mini(min_x, c.x)
				max_x = maxi(max_x, c.x)
			assert_false(g.people_can_walk(Vector2i(min_x - 1, first.y)))
			assert_false(g.people_can_walk(Vector2i(max_x + 1, first.y)))
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
		assert_true(d["trees"].size() >= 80 and d["trees"].size() <= 150)


func test_portals_building_partitions_and_shallow_loot() -> void:
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var g: FieldGrid = d["grid"]
		var mouths: Array = []
		for b: Dictionary in d["buildings"]:
			var r: Rect2i = b["rect"]
			if (r.size.x - 2) * (r.size.y - 2) > 60:
				var walls := 0
				for c: Vector2i in _cells(r.grow(-1)):
					if g.solid_at(c) == S.WALL and g.building_at(c) == (-1 if int(b["id"]) == 0 else int(b["id"])):
						walls += 1
				assert_true(walls > 0)
			if int(b["id"]) == 0:
				mouths = b.get("entrances", [])
			else:
				assert_true(b["rooms"].size() >= 2)
				for room: Dictionary in b["rooms"]:
					var content := false
					for box: Dictionary in d["containers"].values():
						content = content or (int(box.get("level", 0)) == 0 and room["rect"].has_point(box["cell"]))
					assert_true(content, b["name"] + " " + room["name"])
		assert_true(mouths.size() >= 1 and mouths.size() <= 2)
		for mouth: Dictionary in mouths:
			var c: Vector2i = mouth["cell"]
			var out: Vector2i = mouth["outward"]
			assert_true(g.dead_can_walk(c))
			var free := 0
			for depth in range(1, 5):
				for across in range(-2, 3):
					free += 1 if g.people_can_walk(c + out * depth + Vector2i(out.y, out.x) * across) else 0
			assert_true(free >= 16)
		var shallow := 0
		for box: Dictionary in d["containers"].values():
			shallow += 1 if int(box.get("level", 0)) == 0 else 0
		assert_true(shallow > 0)
		if i == 7:
			assert_true(_dead[i][g.index(mouths[0]["cell"])] >= 90)


func test_crossings_and_asymmetry() -> void:
	for d: Dictionary in _maps:
		var g: FieldGrid = d["grid"]
		assert_true(d["crossings"].size() >= 1)
		for crossing: Dictionary in d["crossings"]:
			var allowed: Dictionary = {}
			for c: Vector2i in crossing["cells"]:
				allowed[c] = true
				assert_true(g.people_can_walk(c) and g.dead_can_walk(c))
			var queue: Array = [crossing["cells"][0]]
			var reached: Dictionary = {queue[0]: true}
			var cursor := 0
			while cursor < queue.size():
				var c: Vector2i = queue[cursor]
				cursor += 1
				for step: Vector2i in DIRECTIONS:
					var next := c + step
					if allowed.has(next) and not reached.has(next):
						reached[next] = true
						queue.append(next)
			assert_eq(reached.size(), allowed.size())
		var total := 0
		var matched := 0
		var train: Rect2i = d["train"]
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				if train.has_point(c) or not [S.WALL, S.BLOCK, S.LOW].has(g.solid_at(c)):
					continue
				total += 1
				var other := Vector2i(x, 2 * (train.position.y + 1) - y)
				if g.inside(other) and g.solid_at(c) == g.solid_at(other):
					matched += 1
		assert_true(float(matched) / maxi(1, total) < 0.5, "지도 밖으로 접힌 고체도 분모에 포함")


func test_prop_vocabulary_backing_and_reserved_cells() -> void:
	for d: Dictionary in _maps:
		var g: FieldGrid = d["grid"]
		assert_true(d["props"].size() >= 40)
		var forbidden: Dictionary = {}
		for c: Vector2i in _door_apron(d) + d["barricade_slots"]:
			forbidden[c] = true
		for name: String in d["entries"]:
			if int(d["entry_levels"].get(name, 0)) == 0:
				for c: Vector2i in d["entries"][name]:
					forbidden[c] = true
		for prop: Dictionary in d["props"]:
			assert_true(PROP_KINDS.has(prop["kind"]))
			assert_true(["low", "wall", "tree", "wagon", "none"].has(prop["solid"]))
			assert_true(int(prop["facing"]) >= 0 and int(prop["facing"]) <= 3)
			var r: Rect2i = prop["rect"]
			assert_true(r.size.x > 0 and r.size.y > 0 and Rect2i(0, 0, g.width, g.height).encloses(r))
			for c: Vector2i in _cells(r):
				assert_false(forbidden.has(c), "%s 겹침 %s" % [prop["kind"], c])
				if prop["solid"] == "low":
					assert_eq(g.solid_at(c), S.LOW)
				elif prop["solid"] == "wall":
					assert_eq(g.solid_at(c), S.WALL)
				elif prop["solid"] == "tree":
					assert_true(d["trees"].has(c) and g.solid_at(c) == S.BLOCK)
			if prop["solid"] == "low":
				assert_true(d["low_blocks"].has(r))
			elif prop["solid"] == "wagon":
				var same := false
				for wagon: Dictionary in d["wagons"]:
					same = same or wagon["rect"] == r
				assert_true(same)


func test_levels_stairs_underground_extent_and_routes() -> void:
	var two_stairs := 0
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var g: FieldGrid = d["grid"]
		assert_true(d["levels"].has(1) and d["levels"].has(-1))
		var below: FieldGrid = d["levels"][-1]
		assert_eq(Vector2i(g.width, g.height), Vector2i(below.width, below.height))
		var stairs := _down(d)
		assert_true(stairs.size() >= 1 and stairs.size() <= 2)
		two_stairs += 1 if stairs.size() == 2 else 0
		var mouths: Array = []
		for b: Dictionary in d["buildings"]:
			for m: Dictionary in b.get("entrances", []):
				mouths.append(m["cell"])
		var from_portal := _flood(g, mouths)
		for c: Vector2i in stairs:
			assert_true(g.people_can_walk(c) and g.dead_can_walk(c) and below.people_can_walk(c))
			assert_false(_in_band(d, c))
			assert_eq(g.zone_at(c), "mine")
			assert_true(from_portal[g.index(c)] >= 15 and _dead[i][g.index(c)] >= 0 and _people[i][g.index(c)] >= 0)
		if stairs.size() == 2:
			var between := _flood(below, [stairs[0]])
			assert_true(between[below.index(stairs[1])] >= 30)
		var distances := _flood(below, stairs)
		var count := 0
		var bad := 0
		for y in range(below.height):
			for x in range(below.width):
				var c := Vector2i(x, y)
				if below.people_can_walk(c):
					count += 1
					if distances[below.index(c)] < 0 or _in_band(d, c) or d["train"].has_point(c) or g.zone_at(c) != "mine":
						bad += 1
				if below.solid_at(c) == S.LOW or (below.solid_at(c) == S.BLOCK and below.building_at(c) >= 0):
					bad += 1
		assert_true(count >= 300 and count <= 600)
		assert_eq(bad, 0)
		if i == 5:
			assert_true(count >= 500)
			var ground_count := 0
			for index in range(g.width * g.height):
				ground_count += 1 if g.solid[index] == S.NONE and g.building[index] == 0 else 0
			assert_true(ground_count >= 600)
		var upper_count := 0
		for stair: Dictionary in d["stairs"]:
			assert_false(stair["ladder"])
			if int(stair["low"]) == 0 and int(stair["high"]) == 1:
				upper_count += 1
				var up: FieldGrid = d["levels"][1]
				assert_true(up.people_can_walk(stair["cell"]) and g.people_can_walk(stair["cell"]))
				var up_distances := _flood(up, [stair["cell"]])
				for box: Dictionary in d["containers"].values():
					if int(box.get("level", 0)) == 1:
						assert_true(up_distances[up.index(box["cell"])] >= 0)
		assert_true(upper_count >= 1)
	assert_true(two_stairs >= 3)


func test_deep_loot_entry_dead_and_interior_zone() -> void:
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var below: FieldGrid = d["levels"][-1]
		var stairs := _down(d)
		var distances := _flood(below, stairs)
		var dead_distances := _flood(below, stairs, true)
		var boxes := 0
		var farthest := 0
		for box: Dictionary in d["containers"].values():
			if int(box.get("level", 0)) == -1:
				boxes += 1
				assert_true(below.people_can_walk(box["cell"]))
				farthest = maxi(farthest, distances[below.index(box["cell"])])
		assert_true(boxes >= 4 and boxes <= 6 and farthest >= 25)
		var entries := 0
		for name: String in d["entries"]:
			if int(d["entry_levels"].get(name, 0)) == -1:
				entries += 1
				assert_true(float(d["entry_gap"][name]) >= 2.0 and float(d["entry_gap"][name]) <= 3.0)
				for c: Vector2i in d["entries"][name]:
					assert_true(dead_distances[below.index(c)] >= 20)
		assert_eq(entries, 1)
		assert_true(d["spawns"]["dead_levels"].size() <= 12)
		for row: Array in d["spawns"]["dead_levels"]:
			assert_eq(int(row[1]), -1)
			var c: Vector2i = row[0]
			assert_true(below.dead_can_walk(c))
			for stair: Vector2i in stairs:
				assert_true(absi(c.x - stair.x) + absi(c.y - stair.y) > 5)
		var hoist := false
		for label: Dictionary in d["labels"]:
			hoist = hoist or (label["text"] == "권양기 방" and int(label.get("level", 0)) == -1)
		assert_true(hoist)
		for slot: Dictionary in d["interior_kind_slots"]:
			assert_true(below.zone.has(slot["zone"]) and MAPS[i].ZONE_NAMES.has(slot["zone"]))
		for light: Dictionary in d["lights"]:
			assert_ne(int(light.get("level", 0)), -1)


func test_all_nine_grids_comments_and_korean_names_are_distinct() -> void:
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
		for id in d["containers"]:
			var box_name := String(d["containers"][id].get("name", ""))
			assert_false(_has_roman(box_name), box_name)


func test_assembled_props_clear_structure_and_reserved_cells() -> void:
	for i in range(_maps.size()):
		var d: Dictionary = _maps[i]
		var terrain := _terrain_walls(MAPS[i].PLAN)
		var occupied: Dictionary = {}
		for prop: Dictionary in d["props"]:
			var lv := int(prop.get("level", 0))
			var g: FieldGrid = d["levels"][lv]
			var reserved := _assembly_reserved(d, lv)
			var r: Rect2i = prop["rect"]
			var collisions := 0
			for c: Vector2i in _cells(r):
				var key := Vector3i(c.x, c.y, lv)
				# wall 소품이 스스로 만든 충돌 면과 원래 지형 벽을 구별한다.
				var wall: bool = terrain.has(c) if lv == 0 else g.solid_at(c) == S.WALL
				wall = wall or (prop["solid"] != "wall" and g.solid_at(c) == S.WALL)
				var narrow: bool = lv == 0 and ((terrain.has(c + Vector2i.LEFT) and terrain.has(c + Vector2i.RIGHT)) or (terrain.has(c + Vector2i.UP) and terrain.has(c + Vector2i.DOWN)))
				if wall or narrow or reserved.has(c) or occupied.has(key):
					collisions += 1
				occupied[key] = true
			assert_eq(collisions, 0, "%s %s %s" % [d["place_id"], prop["kind"], r])
			if prop["solid"] == "low":
				assert_true(d["low_blocks"].has(r))
				for c: Vector2i in _cells(r):
					assert_eq(g.solid_at(c), S.LOW)


func test_numbered_walls_are_real_building_walls() -> void:
	for d: Dictionary in _maps:
		var bounds: Dictionary = {}
		for building: Dictionary in d["buildings"]:
			bounds[int(building["id"])] = building["rect"]
		for lv in d["levels"]:
			var g: FieldGrid = d["levels"][lv]
			var level_bounds: Dictionary = bounds.duplicate()
			if int(lv) == 1:
				for upper: Dictionary in d["upper_rects"]:
					level_bounds[int(upper["building"])] = upper["rect"]
			var outside := 0
			var rock_buildings := 0
			for y in range(g.height):
				for x in range(g.width):
					var c := Vector2i(x, y)
					if g.solid_at(c) != S.WALL or g.building_at(c) < 0:
						continue
					var id := g.building_at(c)
					rock_buildings += 1 if id == 0 else 0
					if not level_bounds.has(id) or not level_bounds[id].has_point(c):
						outside += 1
			assert_eq(outside, 0, "%s 층 %s 건물 밖 벽" % [d["place_id"], lv])
			assert_eq(rock_buildings, 0, "%s 층 %s 암벽 건물 번호" % [d["place_id"], lv])


func test_container_suffixes_and_clear_stair_landings() -> void:
	for d: Dictionary in _maps:
		for box: Dictionary in d["containers"].values():
			var matched := false
			for suffix: String in CONTAINER_SUFFIXES:
				matched = matched or String(box["name"]).ends_with(suffix)
			assert_true(matched, "%s %s" % [d["place_id"], box["name"]])
			var lv := int(box.get("level", 0))
			var g: FieldGrid = d["levels"][lv]
			assert_true(g.people_can_walk(box["cell"]))
			for stair: Dictionary in d["stairs"]:
				if lv == int(stair["low"]) or lv == int(stair["high"]):
					assert_ne(box["cell"], stair["cell"], "%s %s" % [d["place_id"], box["id"]])


func test_assembly_inventory_and_band_cover_counts() -> void:
	assert_eq(PROP_KINDS.size(), 33, "기존 아홉 장에서 수집한 낱말")
	for d: Dictionary in _maps:
		for prop: Dictionary in d["props"]:
			assert_true(PROP_KINDS.has(String(prop["kind"])), "%s %s" % [d["place_id"], prop["kind"]])
		for side: String in ["upper", "lower"]:
			var count := 0
			for r: Rect2i in d["low_blocks"]:
				count += 1 if d["bands"][side].intersects(r) else 0
			assert_eq(count, 4, "%s %s 기존 엄폐 수" % [d["place_id"], side])


func _assembly_reserved(d: Dictionary, lv: int) -> Dictionary:
	var reserved: Dictionary = {}
	var g: FieldGrid = d["levels"][lv]
	for c: Vector2i in g.doors:
		reserved[c] = true
		for step: Vector2i in DIRECTIONS:
			reserved[c + step] = true
	for c: Vector2i in g.windows:
		reserved[c] = true
	for stair: Dictionary in d["stairs"]:
		if lv == int(stair["low"]) or lv == int(stair["high"]):
			reserved[stair["cell"]] = true
	for box: Dictionary in d["containers"].values():
		if lv == int(box.get("level", 0)):
			reserved[box["cell"]] = true
	for stove: Dictionary in d["stoves"]:
		if lv == int(stove.get("level", 0)):
			reserved[stove["cell"]] = true
	for name: String in d["entries"]:
		if lv == int(d["entry_levels"].get(name, 0)):
			for c: Vector2i in d["entries"][name]:
				reserved[c] = true
	for name: String in d["spawns"]:
		if name == "dead_levels":
			for row: Array in d["spawns"][name]:
				if lv == int(row[1]):
					reserved[row[0]] = true
		elif lv == 0:
			for c: Vector2i in d["spawns"][name]:
				reserved[c] = true
	if lv == 0:
		for c: Vector2i in _door_apron(d) + d["barricade_slots"]:
			reserved[c] = true
	return reserved


func _terrain_walls(plan: Dictionary) -> Dictionary:
	var walls: Dictionary = {}
	for a: Array in plan["mountains"]:
		for c: Vector2i in _cells(_plan_rect(a)):
			walls[c] = true
	for a: Array in plan["cuts"] + plan["tunnels"]:
		for c: Vector2i in _cells(_plan_rect(a)):
			walls.erase(c)
	for a: Array in plan["cliffs"]:
		for c: Vector2i in _cells(_plan_rect(a)):
			walls[c] = true
	for house: Dictionary in plan["houses"]:
		var r := _plan_rect(house["rect"])
		for c: Vector2i in _cells(r):
			if r.grow(-1).has_point(c):
				walls.erase(c)
			else:
				walls[c] = true
		for a: Array in house["walls"]:
			for c: Vector2i in _cells(_plan_rect(a)):
				walls[c] = true
		for a: Array in house["doors"] + house["windows"]:
			walls.erase(Vector2i(int(a[0]), int(a[1])))
	return walls


func _plan_rect(a: Array) -> Rect2i:
	return Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))


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


func _down(d: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for stair: Dictionary in d["stairs"]:
		if int(stair["low"]) == -1 and int(stair["high"]) == 0 and not stair["ladder"]:
			result.append(stair["cell"])
	return result
