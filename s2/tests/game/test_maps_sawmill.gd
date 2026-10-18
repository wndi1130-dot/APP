extends "res://addons/gut/test.gd"

const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const BASE_KEYS: Array[String] = [
	"grid", "levels", "stairs", "containers", "spots", "stoves", "entries",
	"buildings", "wagons", "train", "platform", "spawns", "labels", "trees",
	"low_blocks", "upper_rects", "train_cars", "lights", "manholes",
	"manhole_levels", "sewer_names", "entry_levels", "entry_gap", "unload",
]
const EXTRA_KEYS: Array[String] = [
	"place_id", "place_kind", "bands", "train_doors", "crossings",
	"barricade_slots", "interior_kind_slots", "props",
	"entry_names", "entry_weights", "first_entry", "zone_names",
]
const MAPS := [
	preload("res://game/world/maps/sawmill_01.gd"),
	preload("res://game/world/maps/sawmill_02.gd"),
	preload("res://game/world/maps/sawmill_03.gd"),
	preload("res://game/world/maps/sawmill_04.gd"),
	preload("res://game/world/maps/sawmill_05.gd"),
	preload("res://game/world/maps/sawmill_06.gd"),
	preload("res://game/world/maps/sawmill_07.gd"),
	preload("res://game/world/maps/sawmill_08.gd"),
	preload("res://game/world/maps/sawmill_09.gd"),
]
const PROP_KINDS: Array[String] = [
	"log_stack_high", "log_stack_low", "plank_stack", "drying_rack", "log_cart",
	"sawhorse", "chopping_block", "firewood_rick", "pallet_stack", "fallen_log",
	"stump_cluster", "log_scatter", "bark_heap", "sawdust_pile", "sawdust_bin",
	"band_saw", "log_carriage", "circular_saw_bench", "planer", "debarker",
	"log_conveyor", "jib_crane", "farm_tractor", "skidder", "log_truck",
	"box_truck", "pickup_truck", "forklift", "flat_trailer", "log_flatcar",
	"tool_bench", "scattered_tools", "oil_drum", "fuel_tank", "generator",
	"sled_load", "handcart",
]
const MACHINES: Array[String] = [
	"band_saw", "log_carriage", "circular_saw_bench", "planer", "debarker",
	"log_conveyor", "jib_crane", "farm_tractor", "skidder", "log_truck",
	"box_truck", "pickup_truck", "forklift", "flat_trailer", "generator",
]
const TREE_MINIMUMS: Array[int] = [170, 170, 170, 190, 170, 400, 180, 400, 200]
const CONTAINER_SUFFIXES: Array[String] = [
	"상자", "보관함", "묶음", "선반", "자재함", "궤", "찬장", "공구함", "책상", "침대", "옷장",
]
const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var _maps: Array[Dictionary] = []


func before_all() -> void:
	_maps.clear()
	for script in MAPS:
		_maps.append(script.build())


func test_keys_size_identity_and_facility_names() -> void:
	assert_eq(_maps.size(), 9)
	var roman := RegEx.new()
	roman.compile("[A-Za-z]")
	for n in range(_maps.size()):
		var data: Dictionary = _maps[n]
		var g: FieldGrid = data["grid"]
		assert_eq(data.size(), BASE_KEYS.size() + EXTRA_KEYS.size(), "본의 열쇠와 props를 포함한 추가 열쇠")
		for key in BASE_KEYS + EXTRA_KEYS:
			assert_true(data.has(key), "필수 열쇠 " + key)
		for key in data:
			assert_true(key in BASE_KEYS or key in EXTRA_KEYS, "허용한 열쇠 " + str(key))
		assert_eq(data["place_id"], "sawmill_%02d" % (n + 1))
		assert_eq(data["place_id"], MAPS[n].PLACE_ID)
		assert_eq(data["place_kind"], "sawmill")
		assert_true(g.width >= 150 and g.width <= 180)
		assert_true(g.height >= 90 and g.height <= 110)
		assert_eq(data["levels"][0], g)
		var zones: Dictionary = {}
		for zone in g.zone:
			if not zone.is_empty():
				zones[zone] = true
		assert_true(zones.size() >= 3 and zones.size() <= 6, "구역 셋에서 여섯")
		assert_eq(zones.size(), 5 if n < 6 else 6, "목재소 종류별 구역 수")
		assert_true(zones.has("forest_edge"))
		var names: Array = MAPS[n].ZONE_NAMES.values()
		names.append_array(MAPS[n].BUILDING_NAMES)
		for facility_name in names:
			assert_null(roman.search(facility_name), "설비 이름에는 로마자를 쓰지 않음")
		for collection in [data["buildings"], data["containers"].values(), data["spots"].values()]:
			for item in collection:
				assert_null(roman.search(str(item.get("name", ""))))
		assert_eq(data["interior_kind_slots"].size(), 1)
		var slot: Dictionary = data["interior_kind_slots"][0]
		assert_eq(slot["zone"], "machine_room")
		assert_eq(slot["kinds"], ["empty", "raiders", "nest", "beasts"])


func test_train_bands_unloading_and_clear_door_fronts() -> void:
	for data in _maps:
		var g: FieldGrid = data["grid"]
		var train: Rect2i = data["train"]
		assert_eq(train.size, Vector2i(80, 3))
		assert_true(train.position.x > 0 and train.position.y > 0)
		assert_true(train.end.x < g.width and train.end.y < g.height)
		assert_eq(data["bands"].size(), 2)
		var bad_train := 0
		for c in _cells(train):
			if g.solid_at(c) != S.BLOCK:
				bad_train += 1
		assert_eq(bad_train, 0, "열차 격자와 차체")
		for side in ["upper", "lower"]:
			var band: Rect2i = data["bands"][side]
			assert_eq(band.size.x, 120)
			assert_true(band.size.y >= 20 and band.size.y <= 25)
			assert_true(Rect2i(0, 0, g.width, g.height).encloses(band))
			assert_eq(band.position.x, train.position.x - 20)
			var sign_y: int = -1 if side == "upper" else 1
			var door_y: int = train.position.y - 1 if side == "upper" else train.end.y
			if side == "upper":
				assert_eq(band.end.y, train.position.y)
			else:
				assert_eq(band.position.y, train.end.y)
			assert_gt(data["train_doors"][side].size(), 0)
			var blocked_fronts := 0
			for c in data["train_doors"][side]:
				assert_eq(c.y, door_y)
				assert_true(c.x >= train.position.x and c.x < train.end.x)
				for depth in range(3):
					for dx in range(-1, 2):
						if g.solid_at(c + Vector2i(dx, sign_y * depth)) != S.NONE:
							blocked_fronts += 1
			assert_eq(blocked_fronts, 0, "문 앞 폭 3칸, 깊이 3칸")
			var unload: Dictionary = data["spots"]["unload_" + side]
			assert_eq(unload["kind"], "unload")
			assert_true(band.encloses(unload["zone_rect"]))
			for c in data["train_doors"][side]:
				assert_true(unload["zone_rect"].has_point(c))
		assert_eq(data["unload"], data["spots"]["unload_lower"]["zone_rect"])


func test_entries_and_initial_dead_reach_the_train_as_built() -> void:
	for data in _maps:
		var g: FieldGrid = data["grid"]
		var starts: Array = _train_doors(data)
		var reached := _flood(g, starts, true)
		var marked := _flood(g, starts, true, {}, "", true)
		assert_true(data["entries"].size() >= 2)
		assert_eq(data["entries"].size(), data["entry_gap"].size())
		for key in data["entries"]:
			assert_true(data["entry_gap"].has(key))
			var gap: float = data["entry_gap"].get(key, 0.0)
			assert_true(gap > 0.0 and gap <= 3.0, "발생 간격의 단위는 초")
			assert_gt(data["entries"][key].size(), 0)
			for c in data["entries"][key]:
				assert_true(g.inside(c))
				assert_false(_in_band(data, c), "입구는 띠 밖")
				assert_true(g.dead_can_walk(c), "닫힌 문을 임의로 열지 않음")
				assert_true(reached.has(c), "네 방향으로 망자가 열차 문에 닿음")
				assert_true(marked.has(c), "입구에서 띠로 이어지는 바닥 표시")
		for key in data["spawns"]:
			if not str(key).begins_with("dead"):
				continue
			for spawn in data["spawns"][key]:
				var c: Vector2i = spawn["cell"] if spawn is Dictionary else spawn
				assert_true(g.inside(c))
				assert_false(_in_band(data, c), "초기 망자는 띠 밖")
				assert_true(reached.has(c), "초기 망자도 실제 보행 길 위")


func test_all_ground_walkable_cells_and_zones_survive_barricades() -> void:
	for data in _maps:
		var g: FieldGrid = data["grid"]
		var starts: Array = _train_doors(data)
		var reached := _flood(g, [starts[0]])
		var missing := 0
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				if g.people_can_walk(c) and not reached.has(c):
					missing += 1
		assert_eq(missing, 0, "열차 문에서 지상 보행 칸 전체에 닿음")
		for c in starts:
			assert_true(reached.has(c), "양쪽 문도 같은 보행 성분")
		var blocked: Dictionary = {}
		for c in data["barricade_slots"]:
			blocked[c] = true
		var remaining := _flood(g, [starts[0]], false, blocked)
		var marked := _flood(g, starts, false, {}, "", true)
		var zones: Dictionary = {}
		var remaining_zones: Dictionary = {}
		var marked_zones: Dictionary = {}
		for c in reached:
			zones[g.zone_at(c)] = true
		for c in remaining:
			remaining_zones[g.zone_at(c)] = true
		for c in marked:
			marked_zones[g.zone_at(c)] = true
		for zone in zones:
			assert_true(remaining_zones.has(zone), "모든 방벽을 막아도 구역에 닿음: " + zone)
			assert_true(marked_zones.has(zone), "바닥으로 읽히는 구역 길: " + zone)


func test_barricades_span_real_gaps_and_leave_open_edges() -> void:
	for data in _maps:
		var g: FieldGrid = data["grid"]
		var slots: Dictionary = {}
		for c in data["barricade_slots"]:
			slots[c] = true
			assert_true(g.people_can_walk(c), "방벽을 놓기 전에는 빈 길목")
		assert_eq(slots.size(), data["barricade_slots"].size(), "중복 방벽 없음")
		var counts := {"upper": 0, "lower": 0}
		for group in _components(slots):
			assert_true(group.size() >= 2 and group.size() <= 3, "틈 하나에 둘이나 셋")
			var r := _bounds(group)
			assert_true(r.size.x == 1 or r.size.y == 1, "틈을 가로질러 놓음")
			var step: Vector2i = Vector2i.RIGHT if r.size.y == 1 else Vector2i.DOWN
			assert_false(g.people_can_walk(r.position - step), "길목의 한쪽 덩어리")
			assert_false(g.people_can_walk(r.end - Vector2i.ONE + step), "길목의 다른 쪽 덩어리")
			# A siding or a building alley may form a throat outside the band.
			# Assign the approach by train side, not by an old perimeter template.
			var train: Rect2i = data["train"]
			counts["upper" if r.position.y < train.position.y else "lower"] += 1
		for side in counts:
			assert_true(counts[side] >= 2 and counts[side] <= 3, "띠마다 길목 둘이나 셋")
			assert_gt(_open_edge(g, data["bands"][side], slots), 6, "방벽 세 칸으로 닫히지 않는 트인 변")
			assert_true(_edge_wall_run(g, data["bands"][side]) <= 12, "띠 경계에 긴 벽선을 긋지 않음")


func test_short_visible_cover_and_no_unrendered_solids() -> void:
	for data in _maps:
		var g: FieldGrid = data["grid"]
		var listed_low: Dictionary = {}
		var listed_block: Dictionary = {}
		for r in data["low_blocks"]:
			for c in _cells(r):
				listed_low[c] = true
		for stove in data["stoves"]:
			if int(stove.get("level", 0)) == 0:
				listed_low[stove["cell"]] = true
		for car in data["train_cars"]:
			for c in _cells(car["rect"]):
				listed_block[c] = true
		for wagon in data["wagons"]:
			for c in _cells(wagon["rect"]):
				listed_block[c] = true
		for c in data["trees"]:
			listed_block[c] = true
		var invisible := 0
		var overdraw := 0
		var tower_cells := 0
		var longest := 0
		for y in range(g.height):
			var run := 0
			for x in range(g.width):
				var c := Vector2i(x, y)
				var solid: int = g.solid_at(c)
				run = run + 1 if solid == S.LOW else 0
				longest = maxi(longest, run)
				if solid == S.LOW and not listed_low.has(c):
					invisible += 1
				if solid == S.BLOCK and g.building_at(c) < 0 and not listed_block.has(c):
					invisible += 1
				if solid == S.BLOCK and x < 14 and y < 14:
					tower_cells += 1
		for x in range(g.width):
			var run := 0
			for y in range(g.height):
				run = run + 1 if g.solid_at(Vector2i(x, y)) == S.LOW else 0
				longest = maxi(longest, run)
		for c in listed_low:
			if g.solid_at(c) != S.LOW:
				overdraw += 1
		assert_eq(invisible, 0, "LOW와 바깥 BLOCK의 그리기 자료")
		assert_eq(overdraw, 0)
		assert_eq(tower_cells, 0, "급수탑으로 그려지는 구석에 BLOCK 없음")
		assert_true(longest <= 10, "지도 전체의 직선 LOW는 10칸 이하")
		for side in ["upper", "lower"]:
			var band: Rect2i = data["bands"][side]
			var cover := 0
			var near := 0
			var shapes: Dictionary = {}
			for r in data["low_blocks"]:
				if not band.intersects(r):
					continue
				cover += 1
				shapes[r.size] = true
				assert_true(maxi(r.size.x, r.size.y) >= 2 and maxi(r.size.x, r.size.y) <= 6)
				var closest := 999
				for c in _cells(r):
					for door in data["train_doors"][side]:
						closest = mini(closest, _steps(c, door))
				if closest <= 12:
					near += 1
			assert_true(cover >= 3 and cover <= 5, "띠 안 엄폐 셋에서 다섯")
			assert_true(near >= 2, "열차 문 12칸 안의 엄폐 둘 이상")
			assert_gt(shapes.size(), 1, "엄폐의 꼴과 방향이 모두 같지 않음")


func test_deep_entrances_landings_depth_loops_and_pockets() -> void:
	for data in _maps:
		var g: FieldGrid = data["grid"]
		var entrances := _deep_entrances(g)
		assert_true(entrances.size() >= 1 and entrances.size() <= 2, "깊은 곳 입구 하나나 둘")
		var marked := _flood(g, _train_doors(data), false, {}, "", true)
		var deep_cells: Dictionary = {}
		var open_cells: Dictionary = {}
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				if g.zone_at(c) == "machine_room":
					deep_cells[c] = true
					if g.solid_at(c) == S.NONE:
						open_cells[c] = true
		var area := _bounds(deep_cells)
		for c in entrances:
			assert_true(g.dead_can_walk(c), "다음 단계 입구는 처음부터 열림")
			assert_true(marked.has(c))
			assert_true(_two_marked_approaches(g, data["train_doors"]["lower"][0], c), "앞마당으로 가는 서로 겹치지 않는 두 길")
			assert_eq(_landing(g, c), 20, "폭 5칸 깊이 4칸의 빈 앞마당과 시야")
			var along: float = float(c.y - area.position.y) / float(area.size.y - 1) if c.x == area.position.x or c.x == area.end.x - 1 else float(c.x - area.position.x) / float(area.size.x - 1)
			assert_true(along >= 0.25 and along <= 0.75, "입구는 벽 면 가운데 부근")
		var distances := _flood(g, entrances, false, {}, "machine_room")
		var deepest := 0
		var shallow := 0
		var deep := 0
		for box in data["containers"].values():
			if int(box.get("level", 0)) != 0:
				continue
			var c: Vector2i = box["cell"]
			if g.zone_at(c) == "machine_room":
				deep += 1
				assert_true(distances.has(c), "깊은 상자는 입구에서 실제로 닿음")
				deepest = maxi(deepest, int(distances.get(c, -1)))
			else:
				shallow += 1
		assert_gt(shallow, 0)
		assert_gt(deep, 0)
		assert_true(deepest >= 25, "가까운 입구에서도 가장 깊은 상자까지 25걸음 이상")
		var pockets := 0
		var corridor: Dictionary = {}
		for room in _components(open_cells):
			if room.size() > corridor.size():
				corridor = room
			if _adjacent_doors(g, room).size() == 1 and _has_contents(data, room):
				pockets += 1
		assert_true(pockets >= 2, "상자가 놓인 한 문짜리 주머니 둘 이상")
		assert_true(_enclosed_area(corridor, area) >= 16, "작업실 둘레를 도는 통로; 작은 2칸 격자 고리는 제외")


func test_buildings_have_partitioned_furnished_rooms_and_windows() -> void:
	for data in _maps:
		var g: FieldGrid = data["grid"]
		for building in data["buildings"]:
			var r: Rect2i = building["rect"]
			var id: int = building["id"]
			var inside_area: int = (r.size.x - 2) * (r.size.y - 2)
			var walls := 0
			var windows := 0
			var open: Dictionary = {}
			for c in _cells(r):
				if g.building_at(c) != id:
					continue
				if r.grow(-1).has_point(c) and g.solid_at(c) == S.WALL:
					walls += 1
				if g.solid_at(c) == S.WINDOW:
					windows += 1
				if g.solid_at(c) == S.NONE:
					open[c] = true
			var rooms := _components(open)
			assert_gt(windows, 0, "각 건물에 창")
			if inside_area > 60:
				assert_gt(walls, 0, "넓은 건물에 안벽")
				assert_true(rooms.size() >= 2, "안문을 닫으면 방 둘 이상")
			if inside_area > 300:
				assert_true(rooms.size() >= 3, "큰 제재동과 기계실은 방 셋 이상")
			for room in rooms:
				var furnished: bool = _has_contents(data, room)
				for c in room:
					for step in DIRS:
						if g.solid_at(c + step) == S.LOW:
							furnished = true
				assert_true(furnished, "작업 칸·곁방·복도마다 가구나 자원")
				assert_gt(_adjacent_doors(g, room).size(), 0, "벽만 있고 문이 없는 방 없음")


func test_crossings_connect_both_sides_and_resource_cells_are_reachable() -> void:
	for data in _maps:
		var g: FieldGrid = data["grid"]
		var train: Rect2i = data["train"]
		assert_gt(data["crossings"].size(), 0)
		for crossing in data["crossings"]:
			var cells: Dictionary = {}
			var north := false
			var south := false
			for c in crossing["cells"]:
				cells[c] = true
				assert_true(g.people_can_walk(c) and g.dead_can_walk(c))
				north = north or c.y < train.position.y
				south = south or c.y >= train.end.y
			assert_eq(_components(cells).size(), 1, "건널목 칸은 네 방향으로 연결")
			assert_true(north and south)
			for who in ["person", "zombie", "carrying", "wounded", "sled"]:
				assert_true(crossing["who"].get(who, false))
		var reached := _flood(g, _train_doors(data))
		var materials: Dictionary = {}
		var salvage_zones: Dictionary = {}
		for box in data["containers"].values():
			var level: int = int(box.get("level", 0))
			var floor_grid: FieldGrid = data["levels"][level]
			if level == 0:
				assert_true(reached.has(box["cell"]), "지상 상자까지 닿음")
			else:
				assert_true(floor_grid.people_can_walk(box["cell"]), "해당 층의 상자 칸")
			assert_eq(floor_grid.building_at(box["cell"]), box["building"])
			for item in box["items"]:
				assert_true(item in ["wood", "plank", "scrap"], "본에 있는 자원 이름")
				materials[item] = true
		for spot in data["spots"].values():
			if spot["kind"] == "salvage":
				assert_true(reached.has(spot["cell"]))
				salvage_zones[g.zone_at(spot["cell"])] = true
		for material in ["wood", "plank", "scrap"]:
			assert_true(materials.has(material))
		assert_true(salvage_zones.has("log_yard") and salvage_zones.has("drying"))


func test_no_empty_thirty_by_twenty_viewport_and_no_mirrored_plan() -> void:
	for data in _maps:
		var g: FieldGrid = data["grid"]
		var stride: int = g.width + 1
		var count: int = stride * (g.height + 1)
		var solid_sum := PackedInt32Array()
		var floor_sum := PackedInt32Array()
		var square_sum := PackedInt32Array()
		solid_sum.resize(count)
		floor_sum.resize(count)
		square_sum.resize(count)
		var total_solids := 0
		var matched := 0
		var train: Rect2i = data["train"]
		for y in range(g.height):
			for x in range(g.width):
				var c := Vector2i(x, y)
				var i: int = (y + 1) * stride + x + 1
				var f: int = g.floor_at(c)
				var occupied: int = 1 if g.solid_at(c) != S.NONE else 0
				solid_sum[i] = occupied + solid_sum[i - 1] + solid_sum[i - stride] - solid_sum[i - stride - 1]
				floor_sum[i] = f + floor_sum[i - 1] + floor_sum[i - stride] - floor_sum[i - stride - 1]
				square_sum[i] = f * f + square_sum[i - 1] + square_sum[i - stride] - square_sum[i - stride - 1]
				if occupied == 1 and not train.has_point(c):
					total_solids += 1
					var mirror := Vector2i(x, 2 * train.position.y + train.size.y - 1 - y)
					if g.inside(mirror) and g.solid_at(mirror) == g.solid_at(c):
						matched += 1
		var blank := 0
		for y in range(g.height - 19):
			for x in range(g.width - 29):
				if _sum(solid_sum, stride, x, y, 30, 20) > 0:
					continue
				var a: int = _sum(floor_sum, stride, x, y, 30, 20)
				var b: int = _sum(square_sum, stride, x, y, 30, 20)
				if b * 600 == a * a:
					blank += 1
		assert_eq(blank, 0, "고체도 바닥 변화도 없는 30×20 창 없음")
		assert_gt(total_solids, 0)
		assert_lt(float(matched) / float(maxi(1, total_solids)), 0.5, "열차 축으로 접은 같은 종류 고체의 겹침은 절반 미만")


func test_nine_grids_and_first_decisions_are_different() -> void:
	var comments: Dictionary = {}
	for n in range(MAPS.size()):
		var first: String = MAPS[n].source_code.get_slice("\n", 0)
		assert_true(first.begins_with("# 이 지도가 다른 판단을 만드는 것: "))
		assert_false(comments.has(first))
		comments[first] = true
		var g: FieldGrid = _maps[n]["grid"]
		for previous in range(n):
			var other: FieldGrid = _maps[previous]["grid"]
			var same: bool = g.width == other.width and g.height == other.height and g.solid == other.solid and g.floor == other.floor and g.zone == other.zone
			assert_false(same, "격자 내용이 서로 다름")
		assert_false(MAPS[n].source_code.contains("sulehuf_map.gd"))
		assert_false(MAPS[n].source_code.contains("res://game/world/maps/"), "지도끼리 불러 쓰지 않음")


func test_props_match_known_kinds_rendered_solids_and_access_reservations() -> void:
	for n in range(_maps.size()):
		var data: Dictionary = _maps[n]
		var g: FieldGrid = data["grid"]
		var kinds: Dictionary = {}
		var protected_cells: Dictionary = {}
		var building_doors: Array = g.doors.keys()
		for c in _deep_entrances(g):
			if not building_doors.has(c):
				building_doors.append(c)
		for value in building_doors:
			var c: Vector2i = value
			var wall_kinds := [S.WALL, S.DOOR, S.WINDOW]
			var horizontal: int = int(g.solid_at(c + Vector2i.LEFT) in wall_kinds) + int(g.solid_at(c + Vector2i.RIGHT) in wall_kinds)
			var vertical: int = int(g.solid_at(c + Vector2i.UP) in wall_kinds) + int(g.solid_at(c + Vector2i.DOWN) in wall_kinds)
			var normal := Vector2i.DOWN if horizontal >= vertical else Vector2i.RIGHT
			var across := Vector2i(normal.y, normal.x)
			for depth in range(-3, 4):
				if depth == 0:
					continue
				for width in range(-1, 2):
					protected_cells[c + normal * depth + across * width] = true
		for side in ["upper", "lower"]:
			var direction := Vector2i.UP if side == "upper" else Vector2i.DOWN
			for c in data["train_doors"][side]:
				for depth in range(3):
					for width in range(-1, 2):
						protected_cells[c + direction * depth + Vector2i(width, 0)] = true
		for c in data["barricade_slots"]:
			protected_cells[c] = true
		for route in data["entries"].values():
			for c in route:
				protected_cells[c] = true
		var overlaps := 0
		var mismatches := 0
		assert_true(data["props"].size() >= 40)
		for p in data["props"]:
			kinds[p["kind"]] = true
			assert_true(p["kind"] in PROP_KINDS, "목재소 물건 낱말만 허용")
			assert_true(p["solid"] in ["low", "wall", "tree", "wagon", "none"])
			assert_ne(p["solid"], "tree", "목재소 나무는 trees에만 기록")
			assert_true(p.has("facing") and p.has("note"))
			var r: Rect2i = p["rect"]
			assert_true(r.size.x > 0 and r.size.y > 0)
			assert_true(Rect2i(0, 0, g.width, g.height).encloses(r))
			if p["solid"] == "low":
				assert_true(data["low_blocks"].has(r), "LOW 이름표와 같은 사각형")
			if p["solid"] == "wagon":
				var matching := false
				for wagon in data["wagons"]:
					matching = matching or wagon["rect"] == r
				assert_true(matching)
				assert_eq(n, 6, "평 화차는 7번 측선에만")
			for side in data["bands"]:
				if data["bands"][side].intersects(r):
					assert_true(p["solid"] == "none" or (p["solid"] == "low" and data["low_blocks"].has(r)))
			for c in _cells(r):
				if protected_cells.has(c):
					overlaps += 1
				if p["solid"] == "wall" and g.solid_at(c) != S.WALL:
					mismatches += 1
				if p["solid"] == "low" and g.solid_at(c) != S.LOW:
					mismatches += 1
				if p["solid"] in ["low", "wall"]:
					assert_false(c.x < 14 and c.y < 14, "급수탑으로 오인하는 구석은 비움")
		assert_true(kinds.size() >= 20)
		assert_eq(overlaps, 0, "문 앞·방벽·유입 칸과 물건이 겹치지 않음")
		assert_eq(mismatches, 0, "이름표와 실제 고체의 일치")


func test_vehicles_and_machines_have_two_cells_of_working_space() -> void:
	for data in _maps:
		var g: FieldGrid = data["grid"]
		var blocked := 0
		for p in data["props"]:
			if not p["kind"] in MACHINES:
				continue
			var r: Rect2i = p["rect"]
			for c in _cells(r.grow(2)):
				if not r.has_point(c) and (not g.inside(c) or g.solid_at(c) != S.NONE):
					blocked += 1
		assert_eq(blocked, 0)


func test_trees_meet_each_target_and_form_large_and_small_groups() -> void:
	for n in range(_maps.size()):
		var data: Dictionary = _maps[n]
		var g: FieldGrid = data["grid"]
		assert_true(data["trees"].size() >= 160)
		assert_true(data["trees"].size() >= TREE_MINIMUMS[n])
		var unique: Dictionary = {}
		for c in data["trees"]:
			unique[c] = true
			assert_true(g.inside(c))
			assert_eq(g.solid_at(c), S.BLOCK)
			assert_false(c.x < 14 and c.y < 14)
		assert_eq(unique.size(), data["trees"].size())
		var large := 0
		var small := 0
		for group in _components(unique):
			if group.size() >= 20 and group.size() <= 40:
				large += 1
			if group.size() >= 3 and group.size() <= 8:
				small += 1
		assert_true(large > 0 and small > 0, "큰 숲 무리와 작은 나무 무리")
		if n == 5:
			assert_true(large >= 10, "숲에 먹힌 목재소는 큰 무리 열 이상")


func test_upper_and_cellar_connect_at_the_same_stair_cells() -> void:
	for data in _maps:
		assert_true(data["levels"].has(1) and data["levels"].has(-1))
		var cellar_links := 0
		for stair in data["stairs"]:
			assert_true(data["levels"].has(stair["low"]) and data["levels"].has(stair["high"]))
			var c: Vector2i = stair["cell"]
			var low: FieldGrid = data["levels"][stair["low"]]
			var high: FieldGrid = data["levels"][stair["high"]]
			assert_true(low.people_can_walk(c) and high.people_can_walk(c))
			assert_eq(int(stair["high"]) - int(stair["low"]), 1)
			if int(stair["low"]) == -1:
				cellar_links += 1
		assert_eq(cellar_links, 1, "지하로 내려가는 계단은 한 곳")
		for level in [1, -1]:
			var g: FieldGrid = data["levels"][level]
			var starts: Array = []
			for stair in data["stairs"]:
				if int(stair["low"]) == level or int(stair["high"]) == level:
					starts.append(stair["cell"])
			assert_gt(starts.size(), 0)
			var reached := _flood(g, starts)
			var open: Dictionary = {}
			var missed := 0
			for y in range(g.height):
				for x in range(g.width):
					var c := Vector2i(x, y)
					if g.people_can_walk(c) and not reached.has(c):
						missed += 1
					if g.solid_at(c) == S.NONE and g.building_at(c) >= 0:
						open[c] = true
			assert_eq(missed, 0, "위층과 지하의 방 전체가 계단과 연결")
			var rooms := _components(open)
			assert_true(rooms.size() >= 2)
			for room in rooms:
				var furnished := false
				for item in data["containers"].values():
					if int(item.get("level", 0)) == level and room.has(item["cell"]):
						furnished = true
				assert_true(furnished, "층의 방마다 연료·공구·부품 또는 자재")
			if level > 0:
				assert_true(g.windows.size() >= 2)


func _cells(r: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			result.append(Vector2i(x, y))
	return result


func _train_doors(data: Dictionary) -> Array:
	var result: Array = data["train_doors"]["upper"].duplicate()
	result.append_array(data["train_doors"]["lower"])
	return result


func _in_band(data: Dictionary, c: Vector2i) -> bool:
	for band in data["bands"].values():
		if band.has_point(c):
			return true
	return false


func _steps(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _allowed(g: FieldGrid, c: Vector2i, dead: bool, blocked: Dictionary, zone: String, marked: bool) -> bool:
	if blocked.has(c) or not g.inside(c):
		return false
	if not zone.is_empty() and g.zone_at(c) != zone:
		return false
	if marked and g.floor_at(c) not in [F.ROAD, F.GRAVEL, F.RAIL, F.PLATFORM, F.WOOD, F.ICE]:
		return false
	return g.dead_can_walk(c) if dead else g.people_can_walk(c)


func _flood(g: FieldGrid, starts: Array, dead: bool = false, blocked: Dictionary = {}, zone: String = "", marked: bool = false) -> Dictionary:
	var distance: Dictionary = {}
	var queue: Array[Vector2i] = []
	for c in starts:
		if _allowed(g, c, dead, blocked, zone, marked) and not distance.has(c):
			distance[c] = 0
			queue.append(c)
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for step in DIRS:
			var next: Vector2i = c + step
			if not distance.has(next) and _allowed(g, next, dead, blocked, zone, marked):
				distance[next] = int(distance[c]) + 1
				queue.append(next)
	return distance


func _components(cells: Dictionary) -> Array[Dictionary]:
	var pending: Dictionary = cells.duplicate()
	var result: Array[Dictionary] = []
	while not pending.is_empty():
		var first: Vector2i = pending.keys()[0]
		var group: Dictionary = {first: true}
		var queue: Array[Vector2i] = [first]
		pending.erase(first)
		var head := 0
		while head < queue.size():
			var c: Vector2i = queue[head]
			head += 1
			for step in DIRS:
				var next: Vector2i = c + step
				if pending.has(next):
					pending.erase(next)
					group[next] = true
					queue.append(next)
		result.append(group)
	return result


func _bounds(cells: Dictionary) -> Rect2i:
	if cells.is_empty():
		return Rect2i()
	var first: Vector2i = cells.keys()[0]
	var low: Vector2i = first
	var high: Vector2i = first
	for c in cells:
		low = Vector2i(mini(low.x, c.x), mini(low.y, c.y))
		high = Vector2i(maxi(high.x, c.x), maxi(high.y, c.y))
	return Rect2i(low, high - low + Vector2i.ONE)


func _open_edge(g: FieldGrid, r: Rect2i, blocked: Dictionary) -> int:
	var best := 0
	for edge in [
		[r.position, Vector2i.RIGHT, r.size.x, Vector2i.UP],
		[Vector2i(r.position.x, r.end.y - 1), Vector2i.RIGHT, r.size.x, Vector2i.DOWN],
		[r.position, Vector2i.DOWN, r.size.y, Vector2i.LEFT],
		[Vector2i(r.end.x - 1, r.position.y), Vector2i.DOWN, r.size.y, Vector2i.RIGHT],
	]:
		var run := 0
		for n in range(int(edge[2])):
			var c: Vector2i = edge[0] + edge[1] * n
			var outside: Vector2i = c + edge[3]
			run = run + 1 if not blocked.has(c) and g.people_can_walk(c) and g.people_can_walk(outside) else 0
			best = maxi(best, run)
	return best


func _edge_wall_run(g: FieldGrid, r: Rect2i) -> int:
	var longest := 0
	for edge in [
		[r.position, Vector2i.RIGHT, r.size.x],
		[Vector2i(r.position.x, r.end.y - 1), Vector2i.RIGHT, r.size.x],
		[r.position, Vector2i.DOWN, r.size.y],
		[Vector2i(r.end.x - 1, r.position.y), Vector2i.DOWN, r.size.y],
	]:
		var run := 0
		for n in range(int(edge[2])):
			var c: Vector2i = edge[0] + edge[1] * n
			run = run + 1 if g.solid_at(c) == S.WALL else 0
			longest = maxi(longest, run)
	return longest


func _deep_entrances(g: FieldGrid) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(g.height):
		for x in range(g.width):
			var c := Vector2i(x, y)
			if g.zone_at(c) != "machine_room" or not g.people_can_walk(c):
				continue
			for step in DIRS:
				var next: Vector2i = c + step
				if g.inside(next) and g.zone_at(next) != "machine_room" and g.people_can_walk(next):
					result.append(c)
					break
	return result


func _two_marked_approaches(g: FieldGrid, start: Vector2i, entrance: Vector2i) -> bool:
	var target := Vector2i(-1, -1)
	for step in DIRS:
		var c: Vector2i = entrance + step
		if g.inside(c) and g.zone_at(c) != "machine_room" and g.people_can_walk(c):
			target = c
			break
	if not g.inside(target):
		return false
	var blocked: Dictionary = {}
	for y in range(g.height):
		for x in range(g.width):
			var c := Vector2i(x, y)
			if g.zone_at(c) == "machine_room":
				blocked[c] = true
	var distance := _flood(g, [start], false, blocked, "", true)
	if not distance.has(target):
		return false
	var cursor: Vector2i = target
	var route: Array[Vector2i] = [cursor]
	while cursor != start:
		var found := false
		for step in DIRS:
			var next: Vector2i = cursor + step
			if distance.has(next) and int(distance[next]) == int(distance[cursor]) - 1:
				cursor = next
				route.append(cursor)
				found = true
				break
		if not found:
			return false
	# 첫 길의 중간 칸들을 막아 두 번째 길의 존재를 확인한다.
	for n in range(1, route.size() - 1):
		blocked[route[n]] = true
	return _flood(g, [start], false, blocked, "", true).has(target)


func _landing(g: FieldGrid, entrance: Vector2i) -> int:
	var best := 0
	for out in DIRS:
		var neighbour := entrance + out
		if not g.inside(neighbour) or g.zone_at(neighbour) == "machine_room":
			continue
		var across := Vector2i(-out.y, out.x)
		var clear := 0
		for depth in range(1, 5):
			for width in range(-2, 3):
				var c: Vector2i = entrance + out * depth + across * width
				if g.inside(c) and g.solid_at(c) == S.NONE and g.zone_at(c) != "machine_room":
					clear += 1
		best = maxi(best, clear)
	return best


func _adjacent_doors(g: FieldGrid, room: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for c in room:
		for step in DIRS:
			var next: Vector2i = c + step
			if g.solid_at(next) == S.DOOR:
				result[next] = true
	return result


func _has_contents(data: Dictionary, room: Dictionary) -> bool:
	for box in data["containers"].values():
		if int(box.get("level", 0)) == 0 and room.has(box["cell"]):
			return true
	for spot in data["spots"].values():
		if spot["kind"] == "salvage" and room.has(spot["cell"]):
			return true
	return false


func _enclosed_area(corridor: Dictionary, area: Rect2i) -> int:
	var outside: Dictionary = {}
	var queue: Array[Vector2i] = []
	for c in _cells(area):
		if not area.grow(-1).has_point(c) and not corridor.has(c):
			outside[c] = true
			queue.append(c)
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for step in DIRS:
			var next: Vector2i = c + step
			if area.has_point(next) and not corridor.has(next) and not outside.has(next):
				outside[next] = true
				queue.append(next)
	return area.size.x * area.size.y - corridor.size() - outside.size()


func _sum(prefix: PackedInt32Array, stride: int, x: int, y: int, w: int, h: int) -> int:
	return prefix[(y + h) * stride + x + w] - prefix[y * stride + x + w] - prefix[(y + h) * stride + x] + prefix[y * stride + x]


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


## 자기 WALL 충돌체와 이름표는 같은 물건이다. 건물 벽과 다른 물건은 겹칠 수 없다.
func test_assembly_props_clear_reserved_cells_and_keep_low_cells() -> void:
	for n in range(_maps.size()):
		var data: Dictionary = _maps[n]
		var source: Dictionary = MAPS[n].get_script_constant_map()["LAYOUT"]
		for level: int in data["levels"]:
			var g: FieldGrid = data["levels"][level]
			var reserved: Dictionary = {}
			var occupied: Dictionary = {}
			var trees: Dictionary = {}
			var low_cells: Dictionary = {}
			for c: Vector2i in g.doors:
				reserved[c] = true
				for step in DIRS:
					reserved[c + step] = true
			for c: Vector2i in g.windows:
				reserved[c] = true
			for stair: Dictionary in data["stairs"]:
				if level == int(stair["low"]) or level == int(stair["high"]):
					reserved[stair["cell"]] = true
			for box: Dictionary in data["containers"].values():
				if level == int(box.get("level", 0)):
					reserved[box["cell"]] = true
			for stove: Dictionary in data["stoves"]:
				if level == int(stove.get("level", 0)):
					reserved[stove["cell"]] = true
			for way: String in data["entries"]:
				if level == int(data["entry_levels"].get(way, 0)):
					for c: Vector2i in data["entries"][way]:
						reserved[c] = true
			for group: Array in data["spawns"].values():
				for spawn in group:
					if spawn is Vector2i and level == 0:
						reserved[spawn] = true
					elif spawn is Dictionary and level == int(spawn.get("level", 0)):
						reserved[spawn["cell"]] = true
			if level == 0:
				for c: Vector2i in data["barricade_slots"]:
					reserved[c] = true
				for c: Vector2i in data["trees"]:
					trees[c] = true
				for r: Rect2i in data["low_blocks"]:
					for c in _cells(r):
						low_cells[c] = true
				for side: String in data["train_doors"]:
					var direction := Vector2i.UP if side == "upper" else Vector2i.DOWN
					for door: Vector2i in data["train_doors"][side]:
						for depth in range(3):
							for width in range(-1, 2):
								reserved[door + direction * depth + Vector2i(width, 0)] = true
			for p: Dictionary in data["props"]:
				if int(p.get("level", 0)) != level:
					continue
				var r: Rect2i = p["rect"]
				var context := "%s 층 %d %s %s" % [data["place_id"], level, p["kind"], r]
				var own_wall: bool = level == 0 and p["solid"] == "wall" and source["walls"].has(
					[r.position.x, r.position.y, r.size.x, r.size.y])
				for c in _cells(r):
					assert_false(reserved.has(c), context + " 예약 칸")
					assert_false(occupied.has(c), context + " 소품 겹침")
					assert_false(trees.has(c), context + " 나무 겹침")
					assert_false(g.solid_at(c) in [S.DOOR, S.WINDOW], context + " 문·창")
					if g.solid_at(c) == S.WALL:
						assert_true(own_wall and g.building_at(c) < 0, context + " 다른 벽")
					if p["solid"] == "low":
						assert_true(low_cells.has(c), context + " LOW 목록")
						assert_eq(g.solid_at(c), S.LOW, context + " LOW 격자")
					# 양쪽 벽 사이 한 칸짜리 통로에는 장식 소품도 놓지 않는다.
					if p["solid"] == "none":
						var across_x: bool = g.solid_at(c + Vector2i.LEFT) in [S.WALL, S.BLOCK] and g.solid_at(c + Vector2i.RIGHT) in [S.WALL, S.BLOCK]
						var across_y: bool = g.solid_at(c + Vector2i.UP) in [S.WALL, S.BLOCK] and g.solid_at(c + Vector2i.DOWN) in [S.WALL, S.BLOCK]
						assert_false(across_x or across_y, context + " 한 칸 통로")
					occupied[c] = true


func test_assembly_building_walls_stay_inside_their_rects() -> void:
	for data: Dictionary in _maps:
		for level: int in data["levels"]:
			var g: FieldGrid = data["levels"][level]
			for y in range(g.height):
				for x in range(g.width):
					var c := Vector2i(x, y)
					var id: int = g.building_at(c)
					if g.solid_at(c) != S.WALL or id < 0:
						continue
					assert_lt(id, data["buildings"].size(), data["place_id"])
					if id < data["buildings"].size():
						var r: Rect2i = data["buildings"][id]["rect"]
						assert_true(r.has_point(c), "%s 층 %d 건물 %d 벽 %s" % [data["place_id"], level, id, c])


func test_assembly_container_names_have_model_suffixes() -> void:
	for data: Dictionary in _maps:
		for box: Dictionary in data["containers"].values():
			var matched := false
			for suffix: String in CONTAINER_SUFFIXES:
				matched = matched or String(box["name"]).ends_with(suffix)
			assert_true(matched, "%s %s: %s" % [data["place_id"], box["id"], box["name"]])


func test_assembly_prop_vocabulary_matches_the_nine_maps() -> void:
	var used: Dictionary = {}
	for data: Dictionary in _maps:
		for p: Dictionary in data["props"]:
			assert_true(PROP_KINDS.has(p["kind"]), "%s %s" % [data["place_id"], p["kind"]])
			used[p["kind"]] = true
	for kind: String in PROP_KINDS:
		assert_true(used.has(kind), "기존 아홉 장에서 모은 낱말: " + kind)

