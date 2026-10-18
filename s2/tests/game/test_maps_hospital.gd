extends "res://addons/gut/test.gd"

const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const MAPS: Array = [
	preload("res://game/world/maps/hospital_01.gd"),
	preload("res://game/world/maps/hospital_02.gd"),
	preload("res://game/world/maps/hospital_03.gd"),
	preload("res://game/world/maps/hospital_04.gd"),
	preload("res://game/world/maps/hospital_05.gd"),
	preload("res://game/world/maps/hospital_06.gd"),
]
const KEYS: Array = ["grid","levels","stairs","containers","spots","stoves","entries","entry_gap","entry_levels","buildings","wagons","train","platform","unload","train_cars","spawns","labels","trees","low_blocks","upper_rects","lights","manholes","manhole_levels","sewer_names","anchors","zone_names","place_id","place_kind","bands","train_doors","crossings","barricade_slots","interior_kind_slots","props","hole_faces", "entry_names", "entry_weights", "first_entry"]
const KINDS: Array = ["car","handcart","firewood_pile","barrel","crate_stack","sack_pile","bench","shelf","bed","desk","cold_stove","lamp_post","display_shelf","shop_counter","checkout","shopping_cart","pallet_stack","market_stall","shop_awning","freezer_chest","bread_rack","blank_sign","floor_shell","stair_stub","water","ambulance","wheeled_bed","medicine_cart","reception_desk","blanket_curtain","oxygen_cylinder","oxygen_rack","iv_stand","lift_shaft","medicine_fridge","dispensing_counter","drug_cabinet","exam_table","eye_chart_frame","dental_chair","gurney","wheelchair","surgery_lamp","operating_table","gazebo","greenhouse_frame","folding_bed","blanket_chest","meal_cart","boiler_unit","generator_unit","laundry_tub","drying_line","boiling_pot","colonnade_post","canopy_roof","ambulance_canopy","dock_platform","flower_stand","medicine_crate","screen_frame","fir_tree","bare_tree","low_fence","oil_lamp_out","wet_blanket","glasses_rack","aid_rack","tire_stack","workbench","seedling_tray","herb_rack","water_tower","transformer_unit","log_pile","hay_bale"]
# KINDS: 원 주문의 68종과 북쪽 자료에서 이미 쓰던 후보 8종. 후보는 결과 글에 적는다.
const CONTAINER_SUFFIXES: Array[String] = ["상자", "보관함", "묶음", "선반", "자재함", "궤", "찬장", "공구함", "책상", "침대", "옷장"]
const ASSEMBLY_BAND_COVER: Array = [[4, 4], [4, 5], [5, 4], [4, 5], [4, 4], [5, 4]] # 위, 아래
const ITEMS: Array = ["ammo_pistol", "ammo_shell", "bandage", "bottle_spirit", "cloth", "document", "flare", "food_pack", "info_telegraph", "info_timetable", "luxury_pack", "med_box", "medkit", "needle_thread", "plank", "scrap", "symbol_bell", "tweezers"]
const SIZES: Array = [Vector2i(175, 150), Vector2i(180, 155), Vector2i(160, 140), Vector2i(170, 145), Vector2i(180, 155), Vector2i(165, 145)]
const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const JUDGMENTS: Array = [
	"복도가 곧아 불을 켜면 끝까지 보이고 끝에서도 보인다",
	"정원을 건널 때마다 드러난다. 구조한 사람을 데리고 두 번 건넌다",
	"약은 지하에, 사람은 3층에 있어 둘 다 가기엔 계단이 길다",
	"약이 여러 집에 나뉘어 있고 문 하나하나가 소리다. 어느 가게를 버릴지 고른다",
	"숲은 엄폐가 많고 시야가 짧다. 본관이 멀어 호송 길이 길다",
	"약품 창고와 식자재 창고가 마당을 사이에 두고 마주 본다. 무엇을 싣고 몇 번 건널지 고른다",
]

const NORTH_JUDGMENTS: Array[String] = ["연료와 부품이 넉넉한 대신 무거워 위쪽 문까지 여러 번 날라야 하고, 그동안 병동 쪽 문이 비어 간다.","가볍고 값진 약초와 씨앗을 한 사람이 열차를 넘겨 올 수 있는 대신, 온실은 사방이 트여 멀리서 보이고 온실 사이가 멀어 한 번 들어가면 오래 걸린다.","집마다 담요와 상비약 몇 갑이 나뉘어 있어 가볍고 값지게 모이지만, 한 집에서 얻는 양이 적고 문을 열 때마다 소리가 나 오래 걸린다.","식료가 상자째 많이 쌓여 있지만 무거워 걸음이 느리고, 하역 단이 트여 있어 짐을 진 사람이 멀리서 보인다.","장작과 통나무가 한 번에 많이 나오지만 가장 무거워서, 위쪽 문까지 나르는 걸음이 여러 번이고 그동안 아래쪽 문 곁이 비어 간다.","전지와 발전기 부품은 가벼워 열차를 넘겨 오지만 물통과 연료 통은 무겁고, 탑 둘레가 트여 한 번 눈에 띄면 몸을 숨길 곳이 없다."]

var maps: Array[Dictionary] = []
var routes: Array[Dictionary] = []
var forbidden_name := RegEx.new()



func before_all() -> void:
	forbidden_name.compile("[A-Za-z㐀-鿿]")
	for map_script in MAPS:
		var d: Dictionary = map_script.build()
		maps.append(d)
		routes.append({
			"people": _flood(d), "all": _flood(d, false, false, true),
			"dead": _flood(d, true), "blocked": _flood(d, false, true),
			"upper_all": _flood(d, false, false, true, "upper"),
			"upper_dead": _flood(d, true, false, false, "upper"),
			"upper_blocked": _flood(d, false, true, false, "upper")
		})


func test_contract_and_shifted_south() -> void:
	for mi: int in range(maps.size()):
		var d: Dictionary = maps[mi]
		var g: FieldGrid = d["grid"]
		assert_eq(d.size(), KEYS.size())
		for k: String in KEYS:
			assert_true(d.has(k), _tag(mi, "필수 열쇠 " + k))
		assert_eq(Vector2i(g.width, g.height), SIZES[mi])
		assert_true(g.width >= 150 and g.width <= 180)
		assert_true(g.height >= 135 and g.height <= 155)
		assert_eq(d["place_id"], "hospital_%02d" % (mi + 1))
		assert_eq(d["place_kind"], "hospital")
		assert_true(d["zone_names"].size() >= 8 and d["zone_names"].size() <= 12)
		var used_zones: Dictionary = {}
		for z: String in g.zone:
			assert_true(d["zone_names"].has(z))
			used_zones[z] = true
		for z: String in d["zone_names"]:
			_assert_name(d["zone_names"][z])
			assert_true(used_zones.has(z))
		var south: Dictionary = MAPS[mi]._build_south()
		assert_eq(d["hole_faces"], south["hole_faces"], "방향은 이동하지 않는다")
		for level: int in [-1, 0, 1, 2]:
			assert_true(d["levels"].has(level))
			var before: FieldGrid = south["levels"][level]
			var after: FieldGrid = d["levels"][level]
			var changes: int = 0
			# 옛 맨 윗줄은 새 북쪽 땅과 연결된다. 선로부터 남쪽 끝까지 대조한다.
			for y: int in range(1, before.height):
				for x: int in range(before.width):
					var a := Vector2i(x, y)
					var b := Vector2i(x, y + 45)
					if before.solid_at(a) != after.solid_at(b) or before.floor_at(a) != after.floor_at(b):
						changes += 1
			assert_eq(changes, 0, _tag(mi, "남쪽 칸과 바닥 보존"))
			for c: Vector2i in before.doors:
				assert_true(after.doors.has(c + Vector2i(0, 45)))
				assert_eq(after.doors[c + Vector2i(0, 45)]["state"], before.doors[c]["state"])
				assert_eq(after.doors[c + Vector2i(0, 45)]["cell"], c + Vector2i(0, 45))
			for c: Vector2i in before.windows:
				assert_true(after.windows.has(c + Vector2i(0, 45)))
				assert_eq(after.windows[c + Vector2i(0, 45)]["cell"], c + Vector2i(0, 45))
		assert_true(d["spots"].has("work_site"))
		assert_eq(d["spots"]["work_site"]["name"], "약품 싣는 터")
		assert_eq(d["spots"]["work_site"]["zone_rect"], Rect2i(south["spots"]["work_site"]["zone_rect"].position + Vector2i(0, 45), south["spots"]["work_site"]["zone_rect"].size))


func test_train_bands_clear_strips_and_crossings() -> void:
	for mi: int in range(maps.size()):
		var d: Dictionary = maps[mi]
		var g: FieldGrid = d["grid"]
		var train: Rect2i = d["train"]
		var bounds := Rect2i(0, 0, g.width, g.height)
		assert_eq(train, Rect2i(16, 46, 80, 3))
		assert_eq(d["platform"], Rect2i(train.position.x, 49, 82, 6))
		assert_eq(d["unload"], Rect2i(train.position.x, 49, 82, 3))
		assert_eq(d["bands"].size(), 2)
		assert_eq(d["bands"]["upper"], Rect2i(train.position.x - 20, 24, 120, 22).intersection(bounds))
		assert_eq(d["bands"]["lower"], Rect2i(train.position.x - 20, 49, 120, 26).intersection(bounds))
		assert_false(d["bands"]["upper"].intersects(d["bands"]["lower"]))
		var upper: Array = d["train_doors"]["upper"]
		var lower: Array = d["train_doors"]["lower"]
		assert_true(upper.size() >= 3 and lower.size() >= 3)
		assert_eq(upper.size(), lower.size())
		for j: int in range(upper.size()):
			assert_eq(upper[j], Vector2i(lower[j].x, 45))
			assert_eq(lower[j].y, 49)
			assert_true(upper[j].x >= train.position.x + 2 and upper[j].x < train.end.x - 2)
			assert_true(d["barricade_slots"].has(upper[j] + Vector2i.UP))
			assert_true(d["barricade_slots"].has(lower[j] + Vector2i.DOWN))
		assert_eq(d["spawns"]["train_door"], lower)
		for c: Vector2i in d["spawns"]["squad"]:
			assert_true(d["bands"]["lower"].has_point(c))
		for strip: Rect2i in [Rect2i(train.position.x, 43, 80, 3), Rect2i(train.position.x, 49, 80, 3)]:
			for c: Vector2i in _cells(strip):
				assert_eq(g.solid_at(c), S.NONE)
				assert_true(g.people_can_walk(c))
			for prop: Dictionary in d["props"]:
				if int(prop.get("level", 0)) == 0:
					assert_false(strip.intersects(prop["rect"]), "열차 옆 세 줄")
		for rail: Rect2i in [Rect2i(0, 46, train.position.x, 3), Rect2i(train.end.x, 46, g.width - train.end.x, 3)]:
			var clear_count: int = 0
			for c: Vector2i in _cells(rail):
				assert_eq(g.floor_at(c), F.RAIL)
				if g.people_can_walk(c):
					clear_count += 1
			assert_true(clear_count >= 4)
		assert_eq(d["crossings"].size(), 2)
		var crossing_x: Dictionary = {}
		for crossing: Dictionary in d["crossings"]:
			assert_eq(crossing["cells"].size(), 3)
			var x: int = crossing["cells"][0].x
			assert_true([train.position.x + 16, train.position.x + 32, train.position.x + 48].has(x))
			assert_false(crossing_x.has(x))
			crossing_x[x] = true
			for j: int in range(3):
				assert_eq(crossing["cells"][j], Vector2i(x, 46 + j))
				assert_eq(g.solid_at(crossing["cells"][j]), S.BLOCK)
			for c: Vector2i in upper + lower:
				assert_ne(c.x, x)
			assert_true(g.people_can_walk(Vector2i(x, 45)))
			assert_true(g.people_can_walk(Vector2i(x, 49)))
			assert_eq(crossing["who"], {"person": true, "zombie": false, "carrying": true, "wounded": false, "sled": false})


func test_entries_holes_and_initial_dead() -> void:
	for mi: int in range(maps.size()):
		var d: Dictionary = maps[mi]
		var g: FieldGrid = d["grid"]
		var n: int = g.width * g.height
		var edge_counts: Dictionary = {"upper": 0, "lower": 0}
		for name: String in d["entries"]:
			assert_true(d["entry_gap"].has(name))
			assert_true(float(d["entry_gap"][name]) > 0.0 and float(d["entry_gap"][name]) <= 3.0)
			if d["manholes"].has(name):
				continue
			var entry_cells: Array = d["entries"][name]
			assert_true(entry_cells.size() >= 2 and entry_cells.size() <= 4)
			var side: String = "upper" if entry_cells[0].y < 46 else "lower"
			edge_counts[side] += 1
			var distance: PackedInt32Array = routes[mi]["upper_dead" if side == "upper" else "dead"]
			for c: Vector2i in entry_cells:
				assert_true(c.x == 0 or c.x == g.width - 1 or c.y == 0 or c.y == g.height - 1)
				assert_true((c.y < 46) == (side == "upper"))
				for band: Rect2i in d["bands"].values():
					assert_false(band.has_point(c))
				assert_true(distance[n + g.index(c)] >= 0, _tag(mi, "망자의 가장자리 길 " + name))
		assert_true(edge_counts["upper"] >= 2 and edge_counts["upper"] <= 3)
		assert_true(edge_counts["lower"] >= 3 and edge_counts["lower"] <= 5)
		assert_true(d["manholes"].size() <= 4)
		for name: String in d["manholes"]:
			assert_true(d["entries"].has(name) and d["sewer_names"].has(name))
			_assert_name(d["sewer_names"][name])
			var c: Vector2i = d["manholes"][name]
			var level: int = int(d["manhole_levels"].get(name, 0))
			assert_eq(d["entries"][name], [c])
			if level == 0:
				for door: Vector2i in d["train_doors"]["upper"] + d["train_doors"]["lower"]:
					assert_true(absi(c.x - door.x) + absi(c.y - door.y) > 25)
				var route: PackedInt32Array = routes[mi]["upper_dead" if c.y < 46 else "dead"]
				assert_true(route[n + g.index(c)] >= 0)
			else:
				assert_eq(level, -1)
				assert_eq(d["entry_levels"].get(name, 0), -1)
				var stair_cells: Array[Vector2i] = []
				for stair: Dictionary in d["stairs"]:
					if int(stair["low"]) == -1:
						stair_cells.append(stair["cell"])
				var distance := _level_flood(d["levels"][-1], stair_cells)
				assert_true(distance[g.index(c)] >= 0, _tag(mi, "지하 배수구에서 계단까지"))
			if name.begins_with("culvert_"):
				assert_true(d["hole_faces"].has(name))
				assert_true(DIRS.has(d["hole_faces"][name]))
		for c: Vector2i in d["spawns"]["dead_street"]:
			for band: Rect2i in d["bands"].values():
				assert_false(band.has_point(c))


func test_connected_floors_and_open_flanks() -> void:
	for mi: int in range(maps.size()):
		var d: Dictionary = maps[mi]
		var g: FieldGrid = d["grid"]
		var n: int = g.width * g.height
		var all_routes: PackedInt32Array = routes[mi]["all"]
		for level: int in [-1, 0, 1, 2]:
			var lg: FieldGrid = d["levels"][level]
			assert_eq(Vector2i(lg.width, lg.height), Vector2i(g.width, g.height))
			var walkable: int = 0
			var missed: int = 0
			for y: int in range(lg.height):
				for x: int in range(lg.width):
					var c := Vector2i(x, y)
					if lg.people_can_walk(c):
						walkable += 1
						var path: PackedInt32Array = routes[mi]["people"] if level == 0 else all_routes
						if path[(level + 1) * n + lg.index(c)] < 0:
							missed += 1
						if level != 0:
							assert_true(lg.building_at(c) >= 0)
			assert_true(walkable > 0)
			assert_eq(missed, 0, _tag(mi, "전 층 연결"))
		for c: Vector2i in d["barricade_slots"]:
			assert_true(g.people_can_walk(c))
		for side: String in ["upper", "lower"]:
			var seen_zones: Dictionary = {}
			var needed_zones: Dictionary = {}
			var blocked: PackedInt32Array = routes[mi]["upper_blocked" if side == "upper" else "blocked"]
			for y: int in range(g.height):
				if (side == "upper") != (y < 46):
					continue
				for x: int in range(g.width):
					var c := Vector2i(x, y)
					needed_zones[g.zone_at(c)] = true
					if blocked[n + g.index(c)] >= 0:
						seen_zones[g.zone_at(c)] = true
			for zone: String in needed_zones:
				assert_true(seen_zones.has(zone), _tag(mi, "방벽을 막은 뒤 트인 변 " + zone))
		for stair: Dictionary in d["stairs"]:
			assert_eq(int(stair["high"]), int(stair["low"]) + 1)
			for level: int in [int(stair["low"]), int(stair["high"])]:
				assert_true(d["levels"][level].people_can_walk(stair["cell"]))


func test_visible_solids_and_band_cover() -> void:
	for mi: int in range(maps.size()):
		var d: Dictionary = maps[mi]
		var g: FieldGrid = d["grid"]
		var low_cells: Dictionary = {}
		var water: Dictionary = {}
		var blocks: Dictionary = {}
		_add_cells(blocks, d["train"])
		for wagon: Dictionary in d["wagons"]:
			_add_cells(blocks, wagon["rect"])
		for c: Vector2i in d["trees"]:
			blocks[c] = true
		for r: Rect2i in d["low_blocks"]:
			_add_cells(low_cells, r)
			for c: Vector2i in _cells(r):
				assert_eq(g.solid_at(c), S.LOW)
		for stove: Dictionary in d["stoves"]:
			if int(stove.get("level", 0)) == 0:
				low_cells[stove["cell"]] = true
		for p: Dictionary in d["props"]:
			if p["kind"] == "water" and int(p.get("level", 0)) == 0:
				_add_cells(water, p["rect"])
				assert_false(d["low_blocks"].has(p["rect"]))
				for c: Vector2i in _cells(p["rect"]):
					assert_eq(g.solid_at(c), S.LOW)
					assert_eq(g.floor_at(c), F.ICE)
		for y: int in range(g.height):
			for x: int in range(g.width):
				var c := Vector2i(x, y)
				if g.solid_at(c) == S.LOW:
					assert_true(low_cells.has(c) or water.has(c))
				if g.solid_at(c) == S.BLOCK and g.building_at(c) < 0:
					assert_true(blocks.has(c))
					assert_false(x < 14 and y < 14)
		assert_true(_max_low_run(g, water) <= 10)
		for side: String in ["upper", "lower"]:
			var count: int = 0
			var near: int = 0
			var shapes: Dictionary = {}
			for r: Rect2i in d["low_blocks"]:
				if not r.intersects(d["bands"][side]):
					continue
				count += 1
				shapes[r.size] = true
				assert_true(maxi(r.size.x, r.size.y) <= 6)
				var close: bool = false
				for c: Vector2i in _cells(r):
					for door: Vector2i in d["train_doors"][side]:
						if absi(c.x - door.x) + absi(c.y - door.y) <= 12:
							close = true
				if close:
					near += 1
			assert_true(count >= 3 and count <= 5)
			assert_true(near >= 2)
			assert_true(shapes.size() >= 2)


func test_buildings_rooms_and_deep_supplies() -> void:
	for mi: int in range(maps.size()):
		var d: Dictionary = maps[mi]
		var g: FieldGrid = d["grid"]
		var n: int = g.width * g.height
		var counts: Dictionary = {"upper": 0, "lower": 0}
		var entered: int = 0
		var large: int = 0
		var largest_north: Rect2i
		for id: int in range(d["buildings"].size()):
			var b: Dictionary = d["buildings"][id]
			var r: Rect2i = b["rect"]
			var north: bool = r.position.y < 46
			assert_eq(b["id"], id)
			_assert_name(b["name"])
			counts["upper" if north else "lower"] += 1
			if north:
				assert_false(r.intersects(d["bands"]["upper"]))
				if r.get_area() > largest_north.get_area():
					largest_north = r
			var has_door: bool = false
			for c: Vector2i in g.doors:
				if g.doors[c]["building"] == id:
					has_door = true
			if has_door:
				entered += 1
			var interior: Rect2i = r.grow(-1)
			if interior.get_area() >= 600:
				large += 1
			if interior.get_area() > 60:
				var inner_wall: bool = false
				for c: Vector2i in _cells(interior):
					if g.solid_at(c) == S.WALL:
						inner_wall = true
				assert_true(inner_wall)
			for other: int in range(id + 1, d["buildings"].size()):
				assert_false(r.intersects(d["buildings"][other]["rect"]))
		assert_true(counts["upper"] >= 6 and counts["upper"] <= 9)
		assert_true(counts["lower"] >= 14 and counts["lower"] <= 22)
		assert_true(entered * 10 >= d["buildings"].size() * 7)
		assert_true(large >= 1)
		var largest_rooms: int = 0
		for label: Dictionary in d["labels"]:
			if int(label.get("level", 0)) == 0 and largest_north.grow(-1).has_point(label["cell"]):
				largest_rooms += 1
		assert_true(largest_rooms >= 6)
		for room: Array in MAPS[mi].NORTH["rooms"]:
			var room_rect := Rect2i(int(room[3]), int(room[4]), int(room[5]), int(room[6]))
			assert_true(room_rect.size.x >= 3 and room_rect.size.y >= 3)
			var furnished: bool = false
			var kinds: Dictionary = {}
			for prop: Dictionary in d["props"]:
				if int(prop.get("level", 0)) == int(room[0]) and room_rect.encloses(prop["rect"]):
					furnished = true
					kinds[prop["kind"]] = int(kinds.get(prop["kind"], 0)) + 1
			assert_true(furnished, "층별 방의 물건")
			for kind: String in kinds:
				assert_true(int(kinds[kind]) <= 4)
		assert_eq(d["interior_kind_slots"].size(), 3)
		var slots: Dictionary = {}
		var north_slot: bool = false
		for slot: Dictionary in d["interior_kind_slots"]:
			assert_false(slots.has(slot["zone"]))
			slots[slot["zone"]] = true
			assert_true(d["zone_names"].has(slot["zone"]))
			assert_eq(slot["kinds"], ["empty", "raiders", "nest", "beasts"])
			if MAPS[mi].NORTH_ZONE_NAMES.has(slot["zone"]):
				north_slot = true
		assert_true(north_slot)
		var farthest: Dictionary = {"upper": 0, "lower": 0}
		var nearest: Dictionary = {"upper": 100000, "lower": 100000}
		for container: Dictionary in d["containers"].values():
			var c: Vector2i = container["cell"]
			var level: int = int(container.get("level", 0))
			var side: String = "upper" if c.y < 46 else "lower"
			var distance: PackedInt32Array = routes[mi]["upper_all" if side == "upper" else "all"]
			var steps: int = distance[(level + 1) * n + g.index(c)]
			assert_true(steps >= 0, _tag(mi, "상자까지의 길"))
			farthest[side] = maxi(int(farthest[side]), steps)
			nearest[side] = mini(int(nearest[side]), steps)
			_assert_name(container["name"])
			for item: String in container["items"]:
				assert_true(ITEMS.has(item))
		assert_true(farthest["upper"] >= 45 and farthest["lower"] >= 80)
		assert_true(nearest["upper"] <= 25 and nearest["lower"] <= 40)
		var target: Dictionary = d["containers"]["north_supply_01"]
		var target_cell: Vector2i = target["cell"]
		var target_distance: int = routes[mi]["upper_all"][(int(target["level"]) + 1) * n + g.index(target_cell)]
		assert_eq(target_distance, farthest["upper"], "지정한 북쪽 끝방이 가장 깊은 상자다")
		var target_rect: Rect2i = d["buildings"][int(target["building"])]["rect"]
		var clear_entrance: bool = false
		for c: Vector2i in g.doors:
			if int(g.doors[c]["building"]) != int(target["building"]):
				continue
			var court: Rect2i
			if c.x == target_rect.position.x:
				court = Rect2i(c + Vector2i(-4, -2), Vector2i(4, 5))
			elif c.x == target_rect.end.x - 1:
				court = Rect2i(c + Vector2i(1, -2), Vector2i(4, 5))
			elif c.y == target_rect.position.y:
				court = Rect2i(c + Vector2i(-2, -4), Vector2i(5, 4))
			elif c.y == target_rect.end.y - 1:
				court = Rect2i(c + Vector2i(-2, 1), Vector2i(5, 4))
			else:
				continue
			var clear: bool = true
			for cell: Vector2i in _cells(court):
				if not g.inside(cell) or g.solid_at(cell) != S.NONE:
					clear = false
			if clear:
				clear_entrance = true
		assert_true(clear_entrance, "깊은 건물 문 앞 너비 다섯 깊이 네 칸")



func test_props_backing_and_clearance() -> void:
	for mi: int in range(maps.size()):
		var d: Dictionary = maps[mi]
		var g: FieldGrid = d["grid"]
		var bounds := Rect2i(0, 0, g.width, g.height)
		var forbidden := _door_clearance(g)
		for c: Vector2i in d["barricade_slots"]:
			forbidden[c] = true
		for name: String in d["entries"]:
			if int(d["entry_levels"].get(name, 0)) == 0:
				for c: Vector2i in d["entries"][name]:
					forbidden[c] = true
		var north_count: int = 0
		var north_inside: int = 0
		assert_true(d["props"].size() >= 130)
		for p: Dictionary in d["props"]:
			var r: Rect2i = p["rect"]
			var level: int = int(p.get("level", 0))
			assert_true(KINDS.has(p["kind"]))
			assert_true(bounds.encloses(r) and r.size.x > 0 and r.size.y > 0)
			assert_true(["low", "wall", "tree", "wagon", "none"].has(p["solid"]))
			assert_true(level >= -1 and level <= 3)
			assert_true(level != 3 or p["kind"] == "floor_shell")
			_assert_name(p["note"])
			if r.position.y < 46:
				north_count += 1
				for b: Dictionary in d["buildings"]:
					if b["rect"].encloses(r):
						north_inside += 1
						break
			if level != 0:
				assert_eq(p["solid"], "none")
			else:
				if p["solid"] == "low" and p["kind"] != "water":
					assert_true(d["low_blocks"].has(r))
				for c: Vector2i in _cells(r):
					assert_false(forbidden.has(c), _tag(mi, "문 앞과 방벽과 진입로의 물건"))
					if p["solid"] == "wall":
						assert_eq(g.solid_at(c), S.WALL)
					if p["solid"] == "tree":
						assert_eq(g.solid_at(c), S.BLOCK)
						assert_true(d["trees"].has(c))
			if p["kind"] == "floor_shell":
				var building_found: bool = false
				var stub_found: bool = false
				for b: Dictionary in d["buildings"]:
					if b["rect"] == r:
						building_found = true
				for q: Dictionary in d["props"]:
					if q["kind"] == "stair_stub" and int(q.get("level", 0)) == 2 and r.encloses(q["rect"]):
						stub_found = true
				assert_true(building_found and stub_found)
		assert_true(north_count >= 40)
		assert_true(north_inside * 2 >= north_count)


func test_trees_asymmetry_headers_and_distinct_north() -> void:
	var headers: Dictionary = {}
	for mi: int in range(maps.size()):
		var d: Dictionary = maps[mi]
		var g: FieldGrid = d["grid"]
		var north_trees: int = 0
		var south_trees: int = 0
		var seen: Dictionary = {}
		for c: Vector2i in d["trees"]:
			assert_false(seen.has(c))
			seen[c] = true
			assert_eq(g.solid_at(c), S.BLOCK)
			assert_false(c.x < 14 and c.y < 14)
			if c.y < 46:
				north_trees += 1
			else:
				south_trees += 1
		assert_true(north_trees >= 12 and north_trees <= 30)
		assert_true(south_trees >= 25 and south_trees <= 60)
		var solid_count: int = 0
		var matched: int = 0
		for y: int in range(g.height):
			for x: int in range(g.width):
				var kind: int = g.solid_at(Vector2i(x, y))
				if kind != S.NONE:
					solid_count += 1
					if kind == g.solid_at(Vector2i(g.width - 1 - x, y)):
						matched += 1
		assert_true(matched * 2 < solid_count)
		solid_count = 0
		matched = 0
		for offset: int in range(45):
			for x: int in range(g.width):
				var a: int = g.solid_at(Vector2i(x, 45 - offset))
				var b: int = g.solid_at(Vector2i(x, 49 + offset))
				if a != S.NONE or b != S.NONE:
					solid_count += 1
					if a == b:
						matched += 1
		assert_true(matched * 2 < solid_count, "열차를 축으로 한 남북 대칭")
		var text: String = FileAccess.get_file_as_string("res://game/world/maps/hospital_%02d.gd" % (mi + 1))
		var first: String = text.get_slice("\n", 0).strip_edges()
		var second: String = text.get_slice("\n", 1).strip_edges()
		assert_eq(first, "# 이 지도가 다른 판단을 만드는 것: " + JUDGMENTS[mi])
		assert_eq(second, "# 위쪽의 판단: " + NORTH_JUDGMENTS[mi])
		assert_false(headers.has(first) or headers.has(second))
		headers[first] = true
		headers[second] = true
		for other: int in range(mi):
			var old: FieldGrid = maps[other]["grid"]
			assert_false(g.solid == old.solid and g.floor == old.floor)
			assert_false(g.width == old.width and g.solid.slice(0, g.width * 46) == old.solid.slice(0, old.width * 46) and g.floor.slice(0, g.width * 46) == old.floor.slice(0, old.width * 46))


func test_no_empty_thirty_by_twenty_view_and_main_road_floor() -> void:
	var roads: Array = [
		[Rect2i(0, 32, 175, 6)],
		[Rect2i(0, 31, 180, 6)],
		[Rect2i(0, 31, 160, 6)],
		[Rect2i(0, 38, 64, 6), Rect2i(58, 38, 6, 29), Rect2i(58, 61, 112, 6)],
		[Rect2i(0, 38, 50, 6)],
		[Rect2i(0, 40, 28, 6), Rect2i(22, 40, 6, 60)],
	]
	for mi: int in range(maps.size()):
		var g: FieldGrid = maps[mi]["grid"]
		for r: Rect2i in roads[mi]:
			for c: Vector2i in _cells(Rect2i(r.position + Vector2i(0, 45), r.size)):
				assert_eq(g.floor_at(c), F.ROAD, _tag(mi, "큰길 바닥"))
		for row: Array in MAPS[mi].NORTH["floors"].slice(3):
			var r := Rect2i(int(row[0]), int(row[1]), int(row[2]), int(row[3]))
			for c: Vector2i in _cells(r):
				assert_eq(g.floor_at(c), F.ROAD)
			var vertical_road: bool = r.size.y > r.size.x
			var length: int = r.size.y if vertical_road else r.size.x
			var width: int = r.size.x if vertical_road else r.size.y
			for along: int in range(length):
				var run: int = 0
				var longest: int = 0
				for across: int in range(width):
					var c: Vector2i = r.position + (Vector2i(across, along) if vertical_road else Vector2i(along, across))
					run = run + 1 if g.people_can_walk(c) else 0
					longest = maxi(longest, run)
				assert_true(longest >= mini(4, width), "북쪽 운반길의 네 칸 폭")
		var solids := _prefix(g, 0)
		var horizontal := _prefix(g, 1)
		var vertical := _prefix(g, 2)
		var empty_count: int = 0
		for y: int in range(g.height - 19):
			for x: int in range(g.width - 29):
				var features: int = _sum(solids, g.width + 1, Rect2i(x, y, 30, 20))
				features += _sum(horizontal, g.width + 1, Rect2i(x + 1, y, 29, 20))
				features += _sum(vertical, g.width + 1, Rect2i(x, y + 1, 30, 19))
				if features == 0:
					empty_count += 1
		assert_eq(empty_count, 0, _tag(mi, "빈 화면"))



func _level_flood(g: FieldGrid, starts: Array[Vector2i]) -> PackedInt32Array:
	var distance := PackedInt32Array()
	distance.resize(g.width * g.height)
	distance.fill(-1)
	var queue: Array[Vector2i] = []
	for c: Vector2i in starts:
		if g.dead_can_walk(c) and distance[g.index(c)] < 0:
			distance[g.index(c)] = 0
			queue.append(c)
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for direction: Vector2i in DIRS:
			var next: Vector2i = c + direction
			if g.dead_can_walk(next) and distance[g.index(next)] < 0:
				distance[g.index(next)] = distance[g.index(c)] + 1
				queue.append(next)
	return distance


func _flood(d: Dictionary, dead: bool = false, blocked: bool = false, all_levels: bool = false, side: String = "lower") -> PackedInt32Array:
	var ground: FieldGrid = d["grid"]
	var n: int = ground.width * ground.height
	var distance := PackedInt32Array()
	distance.resize(n * 4)
	distance.fill(-1)
	var queue := PackedInt32Array()
	queue.resize(n * 4)
	var head: int = 0
	var tail: int = 0
	var denied: Dictionary = {}
	if blocked:
		for c: Vector2i in d["barricade_slots"]:
			denied[c] = true
	var links: Dictionary = {}
	if all_levels:
		for stair: Dictionary in d["stairs"]:
			var a: int = (int(stair["low"]) + 1) * n + ground.index(stair["cell"])
			var b: int = (int(stair["high"]) + 1) * n + ground.index(stair["cell"])
			if not links.has(a):
				links[a] = []
			if not links.has(b):
				links[b] = []
			links[a].append(b)
			links[b].append(a)
	for c: Vector2i in d["train_doors"][side]:
		var start: int = n + ground.index(c)
		distance[start] = 0
		queue[tail] = start
		tail += 1
	while head < tail:
		var current: int = queue[head]
		head += 1
		var level: int = floori(float(current) / float(n)) - 1
		var i: int = current % n
		var c := Vector2i(i % ground.width, floori(float(i) / float(ground.width)))
		var candidates: Array[int] = []
		for direction: Vector2i in DIRS:
			var next: Vector2i = c + direction
			if ground.inside(next):
				candidates.append((level + 1) * n + ground.index(next))
		for next: int in links.get(current, []):
			candidates.append(next)
		for next: int in candidates:
			if distance[next] >= 0:
				continue
			var next_level: int = floori(float(next) / float(n)) - 1
			var ni: int = next % n
			var nc := Vector2i(ni % ground.width, floori(float(ni) / float(ground.width)))
			var g: FieldGrid = d["levels"][next_level]
			if next_level == 0 and denied.has(nc):
				continue
			if not (g.dead_can_walk(nc) if dead else g.people_can_walk(nc)):
				continue
			distance[next] = distance[current] + 1
			queue[tail] = next
			tail += 1
	return distance


func _cells(r: Rect2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			cells.append(Vector2i(x, y))
	return cells


func _add_cells(target: Dictionary, r: Rect2i) -> void:
	for c: Vector2i in _cells(r):
		target[c] = true


func _door_clearance(g: FieldGrid) -> Dictionary:
	var cells: Dictionary = {}
	for c: Vector2i in g.doors:
		var horizontal: bool = g.solid_at(c + Vector2i.LEFT) in [S.WALL, S.WINDOW] or g.solid_at(c + Vector2i.RIGHT) in [S.WALL, S.WINDOW]
		var axis: Vector2i = Vector2i.DOWN if horizontal else Vector2i.RIGHT
		for step: int in range(-3, 4):
			cells[c + axis * step] = true
	return cells


func _max_low_run(g: FieldGrid, water: Dictionary) -> int:
	var longest: int = 0
	for vertical: bool in [false, true]:
		var rows: int = g.width if vertical else g.height
		var columns: int = g.height if vertical else g.width
		for row: int in range(rows):
			var length: int = 0
			for col: int in range(columns):
				var c := Vector2i(row, col) if vertical else Vector2i(col, row)
				length = length + 1 if g.solid_at(c) == S.LOW and not water.has(c) else 0
				longest = maxi(longest, length)
	return longest


func _prefix(g: FieldGrid, mode: int) -> PackedInt32Array:
	var stride: int = g.width + 1
	var out := PackedInt32Array()
	out.resize(stride * (g.height + 1))
	for y: int in range(g.height):
		for x: int in range(g.width):
			var c := Vector2i(x, y)
			var present: bool = g.solid_at(c) != S.NONE
			if mode == 1:
				present = x > 0 and g.floor_at(c) != g.floor_at(c + Vector2i.LEFT)
			elif mode == 2:
				present = y > 0 and g.floor_at(c) != g.floor_at(c + Vector2i.UP)
			var i: int = (y + 1) * stride + x + 1
			out[i] = int(present) + out[i - 1] + out[i - stride] - out[i - stride - 1]
	return out


func _sum(prefix: PackedInt32Array, stride: int, r: Rect2i) -> int:
	return prefix[r.end.y * stride + r.end.x] - prefix[r.position.y * stride + r.end.x] - prefix[r.end.y * stride + r.position.x] + prefix[r.position.y * stride + r.position.x]


func _assert_name(value: String) -> void:
	assert_false(value.is_empty())
	assert_null(forbidden_name.search(value), "한국어 설비 이름: " + value)


func _tag(index: int, message: String) -> String:
	return "hospital_%02d: %s" % [index + 1, message]



func test_assembly_prop_footprints_and_low_backing() -> void:
	for mi: int in range(maps.size()):
		var d: Dictionary = maps[mi]
		# 소품 자체의 WALL 받침과 건축 벽을 구별한다. 덮어쓴 벽도 원 표에서 찾는다.
		var structure := _assembly_structure(MAPS[mi])
		var forbidden: Dictionary = {}
		var occupied: Dictionary = {}
		for level: int in d["levels"]:
			var g: FieldGrid = d["levels"][level]
			for c: Vector2i in _door_clearance(g):
				forbidden[Vector3i(c.x, c.y, level)] = true
			for c: Vector2i in g.windows:
				forbidden[Vector3i(c.x, c.y, level)] = true
		for stair: Dictionary in d["stairs"]:
			var c: Vector2i = stair["cell"]
			for level: int in [int(stair["low"]), int(stair["high"])]:
				forbidden[Vector3i(c.x, c.y, level)] = true
		for row: Dictionary in d["containers"].values() + d["stoves"]:
			var c: Vector2i = row["cell"]
			forbidden[Vector3i(c.x, c.y, int(row.get("level", 0)))] = true
		for name: String in d["entries"]:
			for c: Vector2i in d["entries"][name]:
				forbidden[Vector3i(c.x, c.y, int(d["entry_levels"].get(name, 0)))] = true
		for c: Vector2i in d["barricade_slots"]:
			forbidden[Vector3i(c.x, c.y, 0)] = true
		for name: String in ["squad", "train_door", "dead_street"]:
			for c: Vector2i in d["spawns"][name]:
				forbidden[Vector3i(c.x, c.y, 0)] = true
		for spawn: Dictionary in d["spawns"]["dead_levels"]:
			var c: Vector2i = spawn["cell"]
			forbidden[Vector3i(c.x, c.y, int(spawn["level"]))] = true
		for side: String in ["upper", "lower"]:
			var direction := Vector2i.UP if side == "upper" else Vector2i.DOWN
			for door: Vector2i in d["train_doors"][side]:
				for step: int in range(3):
					var c := door + direction * step
					forbidden[Vector3i(c.x, c.y, 0)] = true
		for prop: Dictionary in d["props"]:
			var level: int = int(prop.get("level", 0))
			var r: Rect2i = prop["rect"]
			var message := _tag(mi, "%s 층 %d 자리 %s" % [prop["kind"], level, r])
			for c: Vector2i in _cells(r):
				var key := Vector3i(c.x, c.y, level)
				assert_false(structure.has(key), message + " 건축 벽")
				assert_false(forbidden.has(key), message + " 예약 칸")
				assert_false(occupied.has(key), message + " 소품 겹침")
				occupied[key] = true
				var across_x: bool = structure.has(key + Vector3i.LEFT) and structure.has(key + Vector3i.RIGHT)
				var across_y: bool = structure.has(key + Vector3i.UP) and structure.has(key + Vector3i.DOWN)
				assert_false(across_x or across_y, message + " 한 칸 통로")
			if prop["solid"] == "low":
				assert_eq(level, 0, message)
				# 물은 기존 시험의 ICE 규칙을 유지한다. 일괄 LOW 받침 규칙과의 충돌은 결과 글에 남긴다.
				if prop["kind"] != "water":
					assert_true(d["low_blocks"].has(r), message + " LOW 받침")
					for c: Vector2i in _cells(r):
						assert_eq(d["grid"].solid_at(c), S.LOW, message)

		assert_eq(_assembly_corridor_cuts(d, MAPS[mi], occupied, structure), 0, _tag(mi, "소품 뒤에도 이어지는 복도"))


func test_assembly_building_walls_and_low_runs() -> void:
	for mi: int in range(maps.size()):
		var d: Dictionary = maps[mi]
		for level: int in d["levels"]:
			var g: FieldGrid = d["levels"][level]
			for y: int in range(g.height):
				for x: int in range(g.width):
					var c := Vector2i(x, y)
					var id: int = g.building_at(c)
					if g.solid_at(c) != S.WALL or id < 0:
						continue
					assert_true(id < d["buildings"].size(), _tag(mi, "벽의 건물 번호"))
					if id < d["buildings"].size():
						var r: Rect2i = d["buildings"][id]["rect"]
						assert_true(r.has_point(c), _tag(mi, "건물 네모 밖의 벽"))
		assert_true(_max_low_run(d["grid"], {}) <= 10, _tag(mi, "물까지 포함한 곧은 LOW"))
		for side_index: int in range(2):
			var side: String = ["upper", "lower"][side_index]
			var count: int = 0
			for r: Rect2i in d["low_blocks"]:
				if r.intersects(d["bands"][side]):
					count += 1
			assert_eq(count, ASSEMBLY_BAND_COVER[mi][side_index], _tag(mi, "띠 엄폐 수 보존"))


func test_assembly_container_name_suffixes() -> void:
	for mi: int in range(maps.size()):
		for row: Dictionary in maps[mi]["containers"].values():
			var name: String = row["name"]
			var matched: bool = false
			for suffix: String in CONTAINER_SUFFIXES:
				if name.ends_with(suffix):
					matched = true
					break
			assert_true(matched, _tag(mi, "수납 끝말 " + name))


func test_assembly_prop_vocabulary() -> void:
	for mi: int in range(maps.size()):
		for prop: Dictionary in maps[mi]["props"]:
			assert_true(KINDS.has(prop["kind"]), _tag(mi, "원 주문 또는 후보 낱말 " + String(prop["kind"])))


func _assembly_structure(map_script) -> Dictionary:
	var walls: Dictionary = {}
	for part: int in range(2):
		var plan: Dictionary = map_script.PLAN if part == 0 else map_script.NORTH
		var shift: int = 45 if part == 0 else 0
		for row: Array in plan["shells"]:
			var r := Rect2i(int(row[2]), int(row[3]) + shift, int(row[4]), int(row[5]))
			for c: Vector2i in _cells(r):
				var key := Vector3i(c.x, c.y, int(row[0]))
				if c.x == r.position.x or c.x == r.end.x - 1 or c.y == r.position.y or c.y == r.end.y - 1:
					walls[key] = true
				else:
					walls.erase(key)
		for row: Array in plan["walls"]:
			var r := Rect2i(int(row[2]), int(row[3]) + shift, int(row[4]), int(row[5]))
			for c: Vector2i in _cells(r):
				walls[Vector3i(c.x, c.y, int(row[0]))] = true
		for row: Array in plan["openings"]:
			var r := Rect2i(int(row[1]), int(row[2]) + shift, int(row[3]), int(row[4]))
			for c: Vector2i in _cells(r):
				walls.erase(Vector3i(c.x, c.y, int(row[0])))
		for row: Array in plan["windows"]:
			walls[Vector3i(int(row[2]), int(row[3]) + shift, int(row[0]))] = true
		for row: Array in plan["doors"]:
			walls.erase(Vector3i(int(row[2]), int(row[3]) + shift, int(row[0])))
	return walls




func _assembly_corridor_cuts(d: Dictionary, map_script, occupied: Dictionary, structure: Dictionary) -> int:
	var rooms: Dictionary = {}
	for part: int in range(2):
		var plan: Dictionary = map_script.PLAN if part == 0 else map_script.NORTH
		var shift: int = 45 if part == 0 else 0
		for row: Array in plan["rooms"]:
			var r := Rect2i(int(row[3]), int(row[4]) + shift, int(row[5]), int(row[6]))
			for c: Vector2i in _cells(r):
				rooms[Vector3i(c.x, c.y, int(row[0]))] = true
	var cuts: int = 0
	for level: int in d["levels"]:
		var g: FieldGrid = d["levels"][level]
		var remaining: Dictionary = {}
		for y: int in range(g.height):
			for x: int in range(g.width):
				var key := Vector3i(x, y, level)
				if g.building_at(Vector2i(x, y)) >= 0 and not structure.has(key) and not rooms.has(key):
					remaining[key] = true
		while not remaining.is_empty():
			var component := _assembly_take_component(remaining)
			for key: Vector3i in occupied:
				component.erase(key)
			var pieces: int = 0
			while not component.is_empty():
				_assembly_take_component(component)
				pieces += 1
			if pieces != 1:
				cuts += 1
	return cuts


func _assembly_take_component(remaining: Dictionary) -> Dictionary:
	var start: Vector3i = remaining.keys()[0]
	var queue: Array[Vector3i] = [start]
	var found: Dictionary = {start: true}
	remaining.erase(start)
	var head: int = 0
	while head < queue.size():
		var key: Vector3i = queue[head]
		head += 1
		for direction: Vector2i in DIRS:
			var next := key + Vector3i(direction.x, direction.y, 0)
			if remaining.has(next):
				remaining.erase(next)
				found[next] = true
				queue.append(next)
	return found



func test_entry_names_weights_and_first_entry() -> void:
	for n in range(1, 7):
		var d: Dictionary = load("res://game/world/maps/hospital_%02d.gd" % n).build()
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
