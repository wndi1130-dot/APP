extends "res://addons/gut/test.gd"

const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const MAPS = [
	preload("res://game/world/maps/lodge_01.gd"),
	preload("res://game/world/maps/lodge_02.gd"),
	preload("res://game/world/maps/lodge_03.gd"),
	preload("res://game/world/maps/lodge_04.gd"),
	preload("res://game/world/maps/lodge_05.gd"),
	preload("res://game/world/maps/lodge_06.gd"),
	preload("res://game/world/maps/lodge_07.gd"),
	preload("res://game/world/maps/lodge_08.gd"),
	preload("res://game/world/maps/lodge_09.gd"),
]
const KEYS: Array[String] = [
	"grid", "levels", "stairs", "containers", "spots", "stoves", "entries",
	"buildings", "wagons", "train", "platform", "spawns", "labels", "trees",
	"low_blocks", "upper_rects", "train_cars", "lights", "manholes",
	"sewer_names", "manhole_levels", "entry_levels", "entry_gap", "unload",
	"place_id", "place_kind", "bands", "train_doors", "crossings",
	"barricade_slots", "interior_kind_slots", "props",
	"entry_names", "entry_weights", "first_entry", "zone_names",
]
const PROP_KINDS: Array[String] = [
	"log_pile", "log_stack", "firewood_stack", "firewood_rack", "woodshed",
	"chopping_block", "axe_block", "stump", "spruce", "birch", "fallen_spruce",
	"uprooted_tree", "brush_pile", "rock_outcrop", "rock_ledge", "stone_terrace",
	"snow_drift", "cairn", "sled_loaded", "wheelbarrow", "log_cart", "offroad_truck",
	"sawhorse", "field_hut", "stone_well", "porch_cover", "snow_shovel", "log_bench",
	"firewood_basket", "workbench_out", "barrel_pair", "cold_fireplace", "bunk_bed", "cellar_shelf",
]
const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const SIZES: Array[Vector2i] = [Vector2i(156, 112), Vector2i(176, 126), Vector2i(164, 120), Vector2i(172, 124), Vector2i(160, 116), Vector2i(180, 128), Vector2i(168, 122), Vector2i(158, 118), Vector2i(174, 130)]
const DISTANCES: Array[Vector2i] = [Vector2i(72, 85), Vector2i(130, 160), Vector2i(95, 115), Vector2i(90, 110), Vector2i(85, 105), Vector2i(100, 125), Vector2i(80, 100), Vector2i(90, 110), Vector2i(110, 140)]

var maps: Array[Dictionary] = []
var people: Array[PackedInt32Array] = []
var routes: Array[Array] = []


func before_all() -> void:
	for source in MAPS:
		var data: Dictionary = source.build()
		maps.append(data)
		people.append(_flood(data["grid"], _doors(data)))
		routes.append(_shortest_route(data))


func test_exact_contract_dimensions_identity_and_zones() -> void:
	for i in range(maps.size()):
		var data: Dictionary = maps[i]
		var g: FieldGrid = data["grid"]
		assert_eq(data.size(), KEYS.size())
		for key in KEYS:
			assert_true(data.has(key), key)
		for key in data:
			assert_true(KEYS.has(key), "허용하지 않은 열쇠: %s" % key)
		assert_eq(data["place_id"], "lodge_%02d" % (i + 1))
		assert_eq(data["place_id"], MAPS[i].PLACE_ID)
		assert_eq(data["place_kind"], "lodge")
		assert_eq(Vector2i(g.width, g.height), SIZES[i])
		assert_true(g.width >= 150 and g.width <= 180 and g.height >= 110 and g.height <= 130)
		assert_eq(data["levels"][0], g)
		var zones: Dictionary = {}
		for lg in data["levels"].values():
			assert_eq(Vector2i(lg.width, lg.height), SIZES[i])
			for zone_id in lg.zone:
				if zone_id != "":
					zones[zone_id] = true
		assert_true(zones.size() >= 3 and zones.size() <= 6)
		assert_true(zones.has("C"))
		assert_eq(data["interior_kind_slots"], [{"zone": "C", "kinds": ["empty", "raiders", "nest", "beasts"]}])


func test_train_bands_unloading_and_clear_door_fronts() -> void:
	for data in maps:
		var g: FieldGrid = data["grid"]
		var train: Rect2i = data["train"]
		assert_eq(train.size, Vector2i(80, 3))
		assert_true(train.position.x > 0 and train.position.y > 0 and train.end.x < g.width and train.end.y < g.height)
		var upper: Rect2i = data["bands"]["upper"]
		var lower: Rect2i = data["bands"]["lower"]
		assert_eq(upper.end.y, train.position.y)
		assert_eq(lower.position.y, train.end.y)
		assert_true(upper.position.y >= 58)
		assert_true(g.height - lower.end.y >= 8 and g.height - lower.end.y <= 24)
		for band in [upper, lower]:
			assert_eq(band.size.x, 120)
			assert_true(band.size.y >= 20 and band.size.y <= 25 and _inside(g, band))
			assert_true(band.position.x <= train.position.x and band.end.x >= train.end.x)
		for side in ["upper", "lower"]:
			assert_eq(data["train_doors"][side].size(), 4)
			for cell in data["train_doors"][side]:
				assert_true(data["bands"][side].has_point(cell) and data["unload"].has_point(cell))
				assert_eq(cell.y, train.position.y - 1 if side == "upper" else train.end.y)
		for cell in _door_fronts(data):
			assert_true(g.people_can_walk(cell), "문 앞 3칸과 어깨 폭")
		assert_eq(data["train_cars"].size(), 5)
		var area := 0
		for car in data["train_cars"]:
			var rect: Rect2i = car["rect"]
			assert_true(train.encloses(rect))
			area += rect.get_area()
		assert_eq(area, train.get_area())


func test_entries_spawns_and_floor_routes_in_original_door_state() -> void:
	for data in maps:
		var g: FieldGrid = data["grid"]
		var dead := _flood(g, _doors(data), {}, true)
		var marked := _flood(g, _doors(data), {}, false, Vector2i(-1, -1), true)
		assert_true(data["entries"].size() >= 2)
		for entry in data["entries"]:
			assert_true(data["entry_gap"].has(entry))
			var gap: float = data["entry_gap"][entry]
			assert_true(gap > 0.0 and gap <= 3.0)
			assert_true(is_equal_approx(gap, 0.6) or gap >= 2.0)
			for cell in data["entries"][entry]:
				assert_false(_in_band(data, cell))
				assert_true(g.dead_can_walk(cell) and dead[g.index(cell)] >= 0, "닫힌 문을 열지 않은 네 방향 유입")
				assert_true(marked[g.index(cell)] >= 0, "바닥으로 표시된 유입로")
		for spawn_id in data["spawns"]:
			if not String(spawn_id).begins_with("dead_") or spawn_id == "dead_levels":
				continue
			for cell in data["spawns"][spawn_id]:
				assert_false(_in_band(data, cell))
				assert_true(dead[g.index(cell)] >= 0)


func test_all_ground_cells_and_zones_after_barricading() -> void:
	for i in range(maps.size()):
		var data: Dictionary = maps[i]
		var g: FieldGrid = data["grid"]
		var unreachable := 0
		for index in range(g.solid.size()):
			if g.walk_people[index] == 1 and people[i][index] < 0:
				unreachable += 1
		assert_eq(unreachable, 0, "%s의 고립된 1층 칸" % data["place_id"])
		var blocked: Dictionary = {}
		for cell in data["barricade_slots"]:
			assert_true(g.people_can_walk(cell))
			blocked[cell] = true
		var after := _flood(g, _doors(data), blocked)
		var zones: Dictionary = {}
		var reached: Dictionary = {}
		for index in range(g.zone.size()):
			if g.zone[index] != "":
				zones[g.zone[index]] = true
				if after[index] >= 0:
					reached[g.zone[index]] = true
		for zone_id in zones:
			assert_true(reached.has(zone_id), "방벽 뒤에도 남는 트인 변: %s" % zone_id)


func test_visible_cover_counts_and_no_long_low_rows() -> void:
	for data in maps:
		var g: FieldGrid = data["grid"]
		var visible_low: Dictionary = {}
		for rect in data["low_blocks"]:
			for cell in _cells(rect):
				visible_low[cell] = true
				assert_eq(g.solid_at(cell), S.LOW)
		for stove in data["stoves"]:
			if stove.get("level", 0) == 0:
				visible_low[stove["cell"]] = true
		for side in ["upper", "lower"]:
			var count := 0
			var near_doors := 0
			var shapes: Dictionary = {}
			var band: Rect2i = data["bands"][side]
			for rect in data["low_blocks"]:
				if not band.intersects(rect):
					continue
				count += 1
				shapes[rect.size] = true
				assert_true(maxi(rect.size.x, rect.size.y) >= 2 and maxi(rect.size.x, rect.size.y) <= 6)
				var nearest := 100000
				for cell in _cells(rect):
					for door in data["train_doors"][side]:
						nearest = mini(nearest, absi(cell.x - door.x) + absi(cell.y - door.y))
				if nearest <= 12:
					near_doors += 1
			assert_true(count >= 3 and count <= 5 and near_doors >= 2 and shapes.size() >= 2)
		var invisible := 0
		var uncovered := 0
		var longest := 0
		for y in range(g.height):
			var run := 0
			for x in range(g.width):
				var cell := Vector2i(x, y)
				var solid: int = g.solid_at(cell)
				run = run + 1 if solid == S.LOW else 0
				longest = maxi(longest, run)
				if solid == S.LOW and not visible_low.has(cell):
					uncovered += 1
				if solid == S.BLOCK and g.building_at(cell) < 0:
					if not _visible_block(data, cell) or (x < 14 and y < 14):
						invisible += 1
		for x in range(g.width):
			var run := 0
			for y in range(g.height):
				run = run + 1 if g.solid_at(Vector2i(x, y)) == S.LOW else 0
				longest = maxi(longest, run)
		assert_eq(invisible, 0, "보이지 않는 바깥 BLOCK 금지")
		assert_eq(uncovered, 0)
		assert_true(longest <= 10)


func test_deep_entrance_stair_zone_apron_and_reward_distance() -> void:
	for data in maps:
		var g: FieldGrid = data["grid"]
		var entrances := _labels(data, "깊은 곳 입구")
		assert_true(entrances.size() >= 1 and entrances.size() <= 2)
		var down: Dictionary = {}
		for stair in data["stairs"]:
			if stair["low"] == -1 and stair["high"] == 0:
				down = stair
		assert_false(down.is_empty())
		if down.is_empty():
			continue
		var stair_cell: Vector2i = down["cell"]
		var cellar: FieldGrid = data["levels"][-1]
		assert_eq(g.zone_at(stair_cell), "C")
		assert_eq(cellar.zone_at(stair_cell), "C")
		assert_true(_zone_size(g, stair_cell, "C") >= 16)
		var under := _flood(cellar, [stair_cell])
		var shallow := 0
		var deep := 0
		for container in data["containers"].values():
			if container.get("level", 0) == 0 and g.zone_at(container["cell"]) != "C":
				shallow += 1
			if container.get("level", 0) == -1:
				deep += 1
		assert_true(shallow > 0 and deep > 0)
		for label in entrances:
			var entrance: Vector2i = label["cell"]
			assert_eq(g.zone_at(entrance), "C")
			assert_true(g.dead_can_walk(entrance))
			if g.solid_at(entrance) == S.DOOR:
				assert_eq(g.doors[entrance]["state"], "open")
			assert_true(_apron(g, entrance) >= 16)
			var ground := _flood(g, [entrance])
			var deepest := -1
			for container in data["containers"].values():
				if container.get("level", 0) == -1:
					var index: int = cellar.index(container["cell"])
					assert_true(under[index] >= 0)
					deepest = maxi(deepest, ground[g.index(stair_cell)] + 1 + under[index])
			assert_true(deepest >= 25)
		var pockets := 0
		for room in _rooms(cellar, g.building_at(stair_cell)):
			if room["doors"].size() != 1:
				continue
			for container in data["containers"].values():
				if container.get("level", 0) == -1 and room["cells"].has(container["cell"]) and container["items"].has("luxury_pack"):
					pockets += 1
		assert_true(pockets >= 2, "한 문으로 드나드는 보상 주머니 둘")
		assert_true(_enclosed_wall(cellar), "벽 덩어리 둘레로 돌아오는 회랑")


func test_building_partitions_room_contents_and_levels() -> void:
	for data in maps:
		var g: FieldGrid = data["grid"]
		for building in data["buildings"]:
			var rect: Rect2i = building["rect"]
			var inner := Rect2i(rect.position + Vector2i.ONE, rect.size - Vector2i(2, 2))
			var walls := 0
			for cell in _cells(inner):
				if g.solid_at(cell) == S.WALL:
					walls += 1
			var rooms := _rooms(g, building["id"])
			if inner.get_area() > 60:
				assert_true(walls > 0 and rooms.size() >= 2)
			if inner.get_area() > 300:
				assert_true(rooms.size() >= 4, "방 셋과 복도 또는 작업 칸")
		var has_upper := false
		assert_true(data["levels"].has(-1))
		for level in data["levels"]:
			var lg: FieldGrid = data["levels"][level]
			has_upper = has_upper or level >= 1
			for building in data["buildings"]:
				for room in _rooms(lg, building["id"]):
					assert_true(_has_contents(data, room["cells"], level), "각 층의 빈 방 금지")
			if level == 0:
				continue
			var starts: Array = []
			for stair in data["stairs"]:
				if stair["low"] == level or stair["high"] == level:
					starts.append(stair["cell"])
			var reach := _flood(lg, starts)
			var unreachable := 0
			for index in range(lg.solid.size()):
				if lg.walk_people[index] == 1 and reach[index] < 0:
					unreachable += 1
			assert_eq(unreachable, 0)
		assert_true(has_upper)
		for stair in data["stairs"]:
			assert_true(data["levels"][stair["low"]].people_can_walk(stair["cell"]))
			assert_true(data["levels"][stair["high"]].people_can_walk(stair["cell"]))
		for container in data["containers"].values():
			assert_true(data["levels"][container.get("level", 0)].people_can_walk(container["cell"]))
	assert_true(maps[5]["levels"].has(2))


func test_crossings_trees_asymmetry_and_distinct_judgments() -> void:
	var judgments: Dictionary = {}
	var roman := RegEx.new()
	roman.compile("[A-Za-z]")
	for i in range(maps.size()):
		var data: Dictionary = maps[i]
		var g: FieldGrid = data["grid"]
		assert_true(data["crossings"].size() >= 1)
		for crossing in data["crossings"]:
			var remaining: Dictionary = {}
			for cell in crossing["cells"]:
				remaining[cell] = true
				assert_true(g.people_can_walk(cell))
			assert_true(remaining.size() > 0)
			if not remaining.is_empty():
				var queue: Array = [remaining.keys()[0]]
				remaining.erase(queue[0])
				var head := 0
				while head < queue.size():
					var cell: Vector2i = queue[head]
					head += 1
					for direction in DIRS:
						if remaining.has(cell + direction):
							remaining.erase(cell + direction)
							queue.append(cell + direction)
				assert_true(remaining.is_empty())
		assert_true(data["trees"].size() >= (800 if i == 4 else 400))
		if i != 4:
			assert_true(data["trees"].size() <= 700)
		var mirrored := 0
		var total := 0
		var train: Rect2i = data["train"]
		for y in range(train.position.y):
			var other_y := train.position.y * 2 + train.size.y - 1 - y
			if other_y >= g.height:
				continue
			for x in range(g.width):
				var a: int = g.solid_at(Vector2i(x, y))
				var b: int = g.solid_at(Vector2i(x, other_y))
				if a in [S.WALL, S.BLOCK, S.LOW] or b in [S.WALL, S.BLOCK, S.LOW]:
					total += 1
					if a == b and a in [S.WALL, S.BLOCK, S.LOW]:
						mirrored += 1
		assert_true(total > 0 and mirrored * 2 < total)
		var source := FileAccess.get_file_as_string(MAPS[i].resource_path)
		var first: String = source.get_slice("\n", 0).strip_edges()
		assert_true(first.begins_with("# 이 지도가 다른 판단을 만드는 것: "))
		assert_false(judgments.has(first))
		judgments[first] = true
		assert_false(source.contains('preload("res://game/world/sulehuf_map.gd")'))
		assert_false(source.contains('preload("res://game/world/maps/'))
		for j in range(i):
			var other: FieldGrid = maps[j]["grid"]
			assert_false(g.width == other.width and g.height == other.height and g.solid == other.solid and g.floor == other.floor)
		for building in data["buildings"]:
			assert_null(roman.search(building["name"]))
		for label in data["labels"]:
			assert_null(roman.search(label["text"]))


func test_props_bind_to_visible_objects_and_keep_required_cells_clear() -> void:
	for data in maps:
		var g: FieldGrid = data["grid"]
		var forbidden := _door_fronts(data)
		var entries: Dictionary = {}
		for cell in data["barricade_slots"]:
			forbidden[cell] = true
		for lane in data["entries"].values():
			for cell in lane:
				entries[cell] = true
		assert_true(data["props"].size() >= 40)
		for prop in data["props"]:
			assert_true(PROP_KINDS.has(prop["kind"]))
			var rect: Rect2i = prop["rect"]
			var solid: String = prop["solid"]
			var level: int = prop.get("level", 0)
			assert_true(_inside(g, rect))
			assert_true(solid in ["low", "wall", "tree", "wagon", "none"])
			assert_true(prop.has("facing") and prop.has("note") and data["levels"].has(level))
			if level != 0:
				assert_eq(solid, "none")
				continue
			for cell in _cells(rect):
				assert_false(entries.has(cell))
				if solid != "none":
					assert_false(forbidden.has(cell))
				if solid == "wall":
					assert_eq(g.solid_at(cell), S.WALL)
				elif solid == "low":
					assert_eq(g.solid_at(cell), S.LOW)
				elif solid == "tree":
					assert_true(data["trees"].has(cell) and g.solid_at(cell) == S.BLOCK)
			if solid == "low":
				assert_true(data["low_blocks"].has(rect))
			elif solid == "wagon":
				var matched := false
				for wagon in data["wagons"]:
					matched = matched or wagon["rect"] == rect
				assert_true(matched)


func test_lodge_climb_turns_neck_views_and_three_by_three_detours() -> void:
	for i in range(maps.size()):
		var data: Dictionary = maps[i]
		var g: FieldGrid = data["grid"]
		var path: Array = routes[i]
		assert_true(path.size() > 70)
		assert_true(path.size() - 1 >= DISTANCES[i].x and path.size() - 1 <= DISTANCES[i].y)
		assert_true(_long_turns(path) >= 3)
		var necks := _labels(data, "좁은 목")
		assert_eq(necks.size(), 1)
		if necks.is_empty() or path.is_empty():
			continue
		var neck: Vector2i = necks[0]["cell"]
		for y in range(neck.y - 1, neck.y + 2):
			var runs := _walk_runs(g, y)
			assert_eq(runs.size(), 1, "목의 연속 세 행에는 통행 구간 하나")
			if runs.size() == 1:
				assert_true(runs[0].size() >= 3 and runs[0].size() <= 6)
		assert_true(g.people_can_walk(neck + Vector2i(0, -6)) and g.people_can_walk(neck + Vector2i(0, 6)))
		var neck_run: Array = _walk_runs(g, neck.y)[0]
		# The neck exemption includes the approach/exit touched by a 3x3 obstruction.
		for k in range(20, path.size() - 20):
			var cell: Vector2i = path[k]
			if absi(cell.y - neck.y) <= 5 and cell.x >= neck_run.front() - 1 and cell.x <= neck_run.back() + 1:
				continue
			var blocked: Dictionary = {}
			for point in _cells(Rect2i(cell - Vector2i.ONE, Vector2i(3, 3))):
				blocked[point] = true
			var reach := _flood(g, _doors(data), blocked, false, path.back())
			assert_true(reach[g.index(path.back())] >= 0, "목 밖 3×3 봉쇄 우회: %s" % cell)
		var views := _labels(data, "내려다보는 자리")
		assert_true(views.size() >= (2 if i == 1 else 1))
		for view in views:
			var seen := false
			for door in _doors(data):
				seen = seen or g.line_clear(view["cell"], door)
			assert_true(g.people_can_walk(view["cell"]) and seen)
		for door in _doors(data):
			assert_false(g.line_clear(door, path.back()), "열차에서는 본채 문이 가려짐")


func test_variant_specific_buildings_branches_and_hut() -> void:
	assert_eq(maps[3]["buildings"].size(), 5, "본채와 흩어진 별채 넷")
	var large_rooms := 0
	for level in [0, 1, 2]:
		large_rooms += _rooms(maps[5]["levels"][level], 0).size() - 1
	assert_true(large_rooms > 10)
	var fork: Dictionary = maps[6]
	var fork_grid: FieldGrid = fork["grid"]
	var goal: Vector2i = _labels(fork, "본채 문")[0]["cell"]
	for closed_label in ["본길 어귀", "샛길 어귀"]:
		var gate: Vector2i = _labels(fork, closed_label)[0]["cell"]
		var blocked: Dictionary = {}
		for run in _walk_runs(fork_grid, gate.y):
			if run.has(gate.x):
				for x in run:
					blocked[Vector2i(x, gate.y)] = true
		var reach := _flood(fork_grid, _doors(fork), blocked)
		var distance: int = reach[fork_grid.index(goal)]
		if closed_label == "본길 어귀":
			assert_true(distance >= 80 and distance <= 95, "짧은 눈비탈 길")
		else:
			assert_true(distance >= 115 and distance <= 135, "긴 본길")
	assert_eq(_rooms(maps[7]["levels"][1], 0).size(), 1, "작은 본채의 다락 한 칸")
	var front: Vector2i = _labels(maps[7], "본채 문")[0]["cell"]
	var store: Vector2i = _labels(maps[7], "깊은 곳 입구")[0]["cell"]
	assert_true(front.y - store.y >= 20 and front.y - store.y <= 30)
	var hut_data: Dictionary = maps[8]
	var hut_grid: FieldGrid = hut_data["grid"]
	var hut: Vector2i = _labels(hut_data, "오두막 문")[0]["cell"]
	var hut_distance: int = people[8][hut_grid.index(hut)]
	assert_true(hut_distance >= 40 and hut_distance <= 55)
	var supplies := 0
	for container in hut_data["containers"].values():
		if container.get("level", 0) == 0 and container["building"] == 1:
			supplies += 1
	assert_eq(supplies, 2)
	var neck: Vector2i = _labels(hut_data, "좁은 목")[0]["cell"]
	var neck_slots := 0
	for cell in hut_data["barricade_slots"]:
		if absi(cell.x - neck.x) + absi(cell.y - neck.y) <= 3:
			neck_slots += 1
	assert_eq(neck_slots, 2)


func test_no_featureless_thirty_by_twenty_window() -> void:
	for data in maps:
		var g: FieldGrid = data["grid"]
		var blank := 0
		for y in range(g.height - 19):
			for x in range(g.width - 29):
				var first: int = g.floor_at(Vector2i(x, y))
				var feature := false
				for yy in range(y, y + 20):
					for xx in range(x, x + 30):
						var cell := Vector2i(xx, yy)
						if g.solid_at(cell) != S.NONE or g.floor_at(cell) != first:
							feature = true
							break
					if feature:
						break
				if not feature:
					blank += 1
		assert_eq(blank, 0)


func _doors(data: Dictionary) -> Array:
	return data["train_doors"]["upper"] + data["train_doors"]["lower"]


func _in_band(data: Dictionary, cell: Vector2i) -> bool:
	for band in data["bands"].values():
		if band.has_point(cell):
			return true
	return false


func _inside(g: FieldGrid, rect: Rect2i) -> bool:
	return rect.size.x > 0 and rect.size.y > 0 and g.inside(rect.position) and g.inside(rect.end - Vector2i.ONE)


func _cells(rect: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			result.append(Vector2i(x, y))
	return result


func _labels(data: Dictionary, text: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for label in data["labels"]:
		if label["text"] == text and label.get("level", 0) == 0:
			result.append(label)
	return result


func _door_fronts(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for side in ["upper", "lower"]:
		var step := Vector2i.UP if side == "upper" else Vector2i.DOWN
		for door in data["train_doors"][side]:
			for k in range(4):
				for dx in range(-1, 2):
					result[door + step * k + Vector2i(dx, 0)] = true
	return result


func _visible_block(data: Dictionary, cell: Vector2i) -> bool:
	if data["train"].has_point(cell) or data["trees"].has(cell):
		return true
	for wagon in data["wagons"]:
		if wagon["rect"].has_point(cell):
			return true
	return false


func _flood(g: FieldGrid, starts: Array, blocked: Dictionary = {}, dead: bool = false, target: Vector2i = Vector2i(-1, -1), marked: bool = false) -> PackedInt32Array:
	var distance := PackedInt32Array()
	distance.resize(g.width * g.height)
	distance.fill(-1)
	var queue := PackedInt32Array()
	queue.resize(distance.size())
	var head := 0
	var tail := 0
	# build() refreshes these from people_can_walk/dead_can_walk with original door states.
	var passable: PackedByteArray = g.walk_dead if dead else g.walk_people
	for cell in starts:
		if not g.inside(cell) or blocked.has(cell):
			continue
		var index: int = g.index(cell)
		if passable[index] == 0 or distance[index] >= 0:
			continue
		distance[index] = 0
		queue[tail] = index
		tail += 1
	while head < tail:
		var index: int = queue[head]
		head += 1
		var cell := Vector2i(index % g.width, int(index / g.width))
		if cell == target:
			break
		for direction in DIRS:
			var next := cell + direction
			if not g.inside(next) or blocked.has(next):
				continue
			var ni: int = g.index(next)
			if passable[ni] == 0 or distance[ni] >= 0 or (marked and g.floor_at(next) == F.SNOW):
				continue
			distance[ni] = distance[index] + 1
			queue[tail] = ni
			tail += 1
	return distance


func _shortest_route(data: Dictionary) -> Array:
	var g: FieldGrid = data["grid"]
	var labels := _labels(data, "본채 문")
	if labels.size() != 1:
		return []
	var goal: Vector2i = labels[0]["cell"]
	var forward := _flood(g, _doors(data))
	var backward := _flood(g, [goal])
	var length: int = forward[g.index(goal)]
	if length < 0:
		return []
	# Choose the fewest turns among equally short four-way paths, avoiding BFS-order zigzags.
	var costs := PackedInt32Array()
	var parents := PackedInt32Array()
	costs.resize(g.width * g.height * 4)
	costs.fill(100000)
	parents.resize(costs.size())
	parents.fill(-1)
	var layers: Array = []
	for k in range(length + 1):
		layers.append([])
	for index in range(forward.size()):
		if forward[index] >= 0 and forward[index] + backward[index] == length:
			layers[forward[index]].append(index)
	for index in layers[0]:
		for direction in range(4):
			costs[index * 4 + direction] = 0
	for step in range(length):
		for index in layers[step]:
			var cell := Vector2i(index % g.width, int(index / g.width))
			for direction in range(4):
				var next: Vector2i = cell + DIRS[direction]
				if not g.inside(next) or not g.people_can_walk(next):
					continue
				var ni: int = g.index(next)
				if forward[ni] != step + 1 or forward[ni] + backward[ni] != length:
					continue
				for previous in range(4):
					var score: int = costs[index * 4 + previous] + (0 if previous == direction else 1)
					if score < costs[ni * 4 + direction]:
						costs[ni * 4 + direction] = score
						parents[ni * 4 + direction] = index * 4 + previous
	var state: int = g.index(goal) * 4
	for direction in range(1, 4):
		if costs[g.index(goal) * 4 + direction] < costs[state]:
			state = g.index(goal) * 4 + direction
	var result: Array = []
	while state >= 0:
		var index := int(state / 4)
		result.append(Vector2i(index % g.width, int(index / g.width)))
		state = parents[state]
	result.reverse()
	return result


func _long_turns(path: Array) -> int:
	var directions: Array[Vector2i] = []
	var lengths: Array[int] = []
	for k in range(1, path.size()):
		var direction: Vector2i = path[k] - path[k - 1]
		if not directions.is_empty() and directions.back() == direction:
			lengths[lengths.size() - 1] += 1
		else:
			directions.append(direction)
			lengths.append(1)
	var count := 0
	for k in range(1, lengths.size()):
		if lengths[k - 1] >= 6 and lengths[k] >= 6:
			count += 1
	return count


func _walk_runs(g: FieldGrid, y: int) -> Array:
	var runs: Array = []
	var run: Array = []
	for x in range(g.width):
		if g.people_can_walk(Vector2i(x, y)):
			run.append(x)
		elif not run.is_empty():
			runs.append(run)
			run = []
	if not run.is_empty():
		runs.append(run)
	return runs


func _apron(g: FieldGrid, entrance: Vector2i) -> int:
	var best := 0
	for sign_value in [-1, 1]:
		var count := 0
		for depth in range(1, 5):
			for x in range(-2, 3):
				if g.people_can_walk(entrance + Vector2i(x, depth * sign_value)):
					count += 1
		best = maxi(best, count)
	return best


func _zone_size(g: FieldGrid, start: Vector2i, zone_id: String) -> int:
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for direction in DIRS:
			var next := cell + direction
			if g.people_can_walk(next) and g.zone_at(next) == zone_id and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen.size()


func _rooms(g: FieldGrid, building_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var visited: Dictionary = {}
	for y in range(g.height):
		for x in range(g.width):
			var start := Vector2i(x, y)
			if g.building_at(start) != building_id or g.solid_at(start) != S.NONE or visited.has(start):
				continue
			var room: Dictionary = {"cells": {start: true}, "doors": {}}
			var queue: Array[Vector2i] = [start]
			var head := 0
			visited[start] = true
			while head < queue.size():
				var cell: Vector2i = queue[head]
				head += 1
				for direction in DIRS:
					var next := cell + direction
					if not g.inside(next) or g.building_at(next) != building_id:
						continue
					if g.solid_at(next) == S.DOOR:
						room["doors"][next] = true
					elif g.solid_at(next) == S.NONE and not visited.has(next):
						visited[next] = true
						room["cells"][next] = true
						queue.append(next)
			result.append(room)
	return result


func _has_contents(data: Dictionary, room: Dictionary, level: int) -> bool:
	for container in data["containers"].values():
		if container.get("level", 0) == level and room.has(container["cell"]):
			return true
	for stove in data["stoves"]:
		if stove.get("level", 0) == level:
			for direction in DIRS:
				if room.has(stove["cell"] + direction):
					return true
	for prop in data["props"]:
		if prop.get("level", 0) == level:
			for cell in _cells(prop["rect"]):
				if room.has(cell):
					return true
	for spot in data["spots"].values():
		if spot.get("level", 0) == level and room.has(spot["cell"]):
			return true
	return false


func _enclosed_wall(g: FieldGrid) -> bool:
	var visited: Dictionary = {}
	for y in range(g.height):
		for x in range(g.width):
			var start := Vector2i(x, y)
			if g.solid_at(start) != S.WALL or visited.has(start):
				continue
			var queue: Array[Vector2i] = [start]
			var head := 0
			var outside := false
			visited[start] = true
			while head < queue.size():
				var cell: Vector2i = queue[head]
				head += 1
				for direction in DIRS:
					var next := cell + direction
					if not g.inside(next) or g.solid_at(next) in [S.AIR, S.BLOCK]:
						outside = true
					elif g.solid_at(next) == S.WALL and not visited.has(next):
						visited[next] = true
						queue.append(next)
			if not outside and queue.size() >= 4:
				return true
	return false


func test_entry_names_weights_first_entry_and_zone_names() -> void:
	for d: Dictionary in maps:
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
