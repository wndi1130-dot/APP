extends RefCounted
## Sulechów stop as a graybox (s2_station.md 1장, first_leg_story.md 6.3).
## North is the top of the screen (−z). The train stands on the north track.
## All numbers are starting values; one cell is one metre.

const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor

const WIDTH: int = 120
const HEIGHT: int = 70
const PLACE_ID: String = "first_leg_01_sulechow"

const BUILDING_NAMES: Array[String] = ["역사", "신호소", "가게", "약국", "주택", "주택"]
const ZONE_NAMES: Dictionary = {"platform": "승강장", "A": "역사", "B": "화물 측선", "C": "급수탑", "D": "역 앞 거리", "E": "신호소", "": "바깥"}

## Everything the field needs besides the grid.
## containers: id -> {name, cell, building, search, items[], locked, searched}
## spots: interactable map features (water tower, ladder, work sites, stove, salvage)
static func build() -> Dictionary:
	var g := FieldGrid.new(WIDTH, HEIGHT)
	var data := {
		"grid": g, "containers": {}, "spots": {}, "stoves": [], "entries": {},
		"buildings": [], "wagons": [], "train": Rect2i(16, 1, 80, 3), "platform": Rect2i(16, 4, 82, 6),
		"spawns": {}, "labels": [], "trees": [], "low_blocks": [],
	}
	# Map edge: one row of fence on the north edge behind the track.
	_fill_floor(g, Rect2i(0, 0, WIDTH, HEIGHT), F.SNOW)
	# Main track and the train.
	_fill_floor(g, Rect2i(0, 1, WIDTH, 3), F.RAIL)
	_fill_solid(g, Rect2i(16, 1, 80, 3), S.BLOCK)
	# Platform with icy ends.
	_fill_floor(g, Rect2i(16, 4, 82, 6), F.PLATFORM)
	_fill_floor(g, Rect2i(16, 4, 3, 6), F.ICE)
	_fill_floor(g, Rect2i(95, 4, 3, 6), F.ICE)
	# Roads: north road (west side), station street, south road.
	_fill_floor(g, Rect2i(11, 0, 4, 34), F.ROAD)
	_fill_floor(g, Rect2i(11, 30, 109, 6), F.ROAD)
	_fill_floor(g, Rect2i(58, 36, 5, 34), F.ROAD)
	# C water tower: a round solid, fire spot south of it.
	for y in range(3, 13):
		for x in range(2, 13):
			if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(7.5, 7.5)) <= 3.1:
				g.set_solid(Vector2i(x, y), S.BLOCK)
	data["spots"]["water_tower"] = {"kind": "water_tower", "cell": Vector2i(7, 12), "name": "급수탑", "state": "frozen"}
	# B freight siding: two siding tracks, wagons, deep snow between them, icy switches.
	_fill_floor(g, Rect2i(46, 16, 74, 1), F.RAIL)
	_fill_floor(g, Rect2i(46, 24, 74, 1), F.RAIL)
	_fill_floor(g, Rect2i(52, 18, 50, 5), F.DEEP_SNOW)
	_fill_floor(g, Rect2i(46, 15, 4, 3), F.ICE)
	_fill_floor(g, Rect2i(46, 23, 4, 3), F.ICE)
	var wagons := [
		{"id": "coal_1", "name": "석탄 화차", "rect": Rect2i(56, 15, 10, 3), "coal": 10.0, "work": Vector2i(60, 18)},
		{"id": "coal_2", "name": "석탄 화차", "rect": Rect2i(69, 15, 10, 3), "coal": 10.0, "work": Vector2i(73, 18)},
		{"id": "tender", "name": "버려진 탄수차", "rect": Rect2i(60, 23, 6, 3), "coal": 0.0},
		{"id": "empty", "name": "빈 화차", "rect": Rect2i(82, 23, 10, 3), "coal": 0.0},
	]
	for w in wagons:
		_fill_solid(g, w["rect"], S.BLOCK)
	data["wagons"] = wagons
	data["spots"]["work_site"] = {"kind": "work_site", "cell": Vector2i(67, 19), "name": "석탄 작업 구역", "state": "closed", "zone_rect": Rect2i(46, 13, 58, 16)}
	# A station building with five rooms.
	_building(g, data, 0, Rect2i(20, 12, 25, 14))
	_wall_h(g, 19, 21, 43, 0)
	_wall_v(g, 27, 20, 24, 0)
	_wall_v(g, 33, 20, 24, 0)
	_wall_v(g, 40, 20, 24, 0)
	for c in [Vector2i(24, 19), Vector2i(30, 19), Vector2i(37, 19), Vector2i(42, 19)]:
		_door(g, c, "closed", 0)
	for c in [Vector2i(26, 12), Vector2i(38, 12), Vector2i(44, 15), Vector2i(20, 15)]:
		_door(g, c, "closed", 0)
	for c in [Vector2i(23, 25), Vector2i(30, 25), Vector2i(36, 25)]:
		_window(g, c, 0)
	_stove(g, data, Vector2i(32, 15), 0)
	data["labels"].append({"text": "대합실", "cell": Vector2i(28, 16)})
	data["labels"].append({"text": "매표소", "cell": Vector2i(23, 22)})
	data["labels"].append({"text": "역무실", "cell": Vector2i(30, 22)})
	data["labels"].append({"text": "매점", "cell": Vector2i(36, 22)})
	data["labels"].append({"text": "화장실", "cell": Vector2i(42, 22)})
	# E signal box: two floors, ladder inside, empty stove upstairs.
	_building(g, data, 1, Rect2i(104, 6, 6, 6))
	_door(g, Vector2i(104, 9), "closed", 1)
	_window(g, Vector2i(107, 6), 1)
	data["spots"]["ladder"] = {"kind": "ladder", "cell": Vector2i(107, 8), "name": "사다리", "state": "down"}
	g.set_solid(Vector2i(108, 7), S.LOW)
	data["stoves"].append({"cell": Vector2i(108, 7), "building": 1, "lit": false, "upstairs": true})
	# D street buildings.
	_building(g, data, 2, Rect2i(16, 38, 12, 10))
	_door(g, Vector2i(21, 38), "closed", 2)
	for c in [Vector2i(18, 38), Vector2i(25, 38), Vector2i(16, 42)]:
		_window(g, c, 2)
	_building(g, data, 3, Rect2i(32, 38, 13, 11))
	_wall_h(g, 44, 33, 43, 3)
	_door(g, Vector2i(40, 44), "open", 3)
	_door(g, Vector2i(36, 38), "closed", 3)
	_door(g, Vector2i(38, 48), "locked", 3)
	for c in [Vector2i(34, 38), Vector2i(42, 38)]:
		_window(g, c, 3)
	_building(g, data, 4, Rect2i(68, 38, 11, 11))
	_wall_v(g, 73, 39, 47, 4)
	_door(g, Vector2i(73, 43), "open", 4)
	_door(g, Vector2i(71, 38), "closed", 4)
	for c in [Vector2i(76, 38), Vector2i(78, 43)]:
		_window(g, c, 4)
	_building(g, data, 5, Rect2i(84, 38, 13, 11))
	_wall_h(g, 43, 85, 95, 5)
	_door(g, Vector2i(90, 43), "open", 5)
	_door(g, Vector2i(88, 38), "closed", 5)
	for c in [Vector2i(93, 38), Vector2i(96, 41)]:
		_window(g, c, 5)
	# Wrecked cars on the street (cover, low), fences and trees in the yards.
	for r in [Rect2i(40, 32, 4, 2), Rect2i(64, 31, 4, 2), Rect2i(90, 33, 4, 2), Rect2i(104, 31, 2, 4)]:
		_fill_solid(g, r, S.LOW)
		data["low_blocks"].append(r)
	for r in [Rect2i(2, 55, 12, 1), Rect2i(30, 56, 20, 1), Rect2i(68, 58, 30, 1), Rect2i(100, 50, 1, 14)]:
		_fill_solid(g, r, S.LOW)
		data["low_blocks"].append(r)
	for c in [Vector2i(6, 24), Vector2i(9, 44), Vector2i(48, 62), Vector2i(80, 64), Vector2i(110, 45), Vector2i(114, 60), Vector2i(26, 64), Vector2i(4, 34)]:
		g.set_solid(c, S.BLOCK)
		data["trees"].append(c)
	_zones(g)
	_containers(data)
	_salvage(data)
	# Rear hordes (user 2026-10-07): the sewer is the endless source. Sulechów has
	# one street manhole (can be blocked) and one culvert under the water tower
	# (cannot). The train-following share comes along the north and south roads
	# and the east track end (s2_station 1, places.md 5).
	data["manholes"] = {"manhole": Vector2i(54, 33), "culvert": Vector2i(3, 14)}
	data["sewer_names"] = {"manhole": "거리 맨홀", "culvert": "급수탑 밑 암거"}
	data["entries"] = {
		"manhole": [Vector2i(54, 33)],
		"culvert": [Vector2i(3, 14), Vector2i(4, 14), Vector2i(3, 15), Vector2i(4, 15)],
		"east_track": [Vector2i(119, 2), Vector2i(119, 1), Vector2i(119, 3), Vector2i(118, 2)],
		"north_road": [Vector2i(12, 0), Vector2i(13, 0), Vector2i(11, 0), Vector2i(14, 0)],
		"south_road": [Vector2i(60, 69), Vector2i(59, 69), Vector2i(61, 69), Vector2i(62, 69)],
	}
	# Seconds between bodies climbing out: a manhole lets one through every
	# 3 s, the culvert lets the horde out together (field_unified 6 하수도).
	data["entry_gap"] = {"manhole": 3.0, "culvert": 0.6, "east_track": 0.6, "north_road": 0.6, "south_road": 0.6}
	data["spawns"] = {
		"dead_street": [Vector2i(30, 33), Vector2i(46, 34), Vector2i(52, 31), Vector2i(66, 34), Vector2i(74, 32), Vector2i(80, 33), Vector2i(98, 31), Vector2i(110, 34)],
		"dead_platform": [Vector2i(12, 8), Vector2i(100, 13), Vector2i(47, 11), Vector2i(86, 11)],
		"dead_siding_end": [Vector2i(100, 17), Vector2i(101, 23)],
		"clothed_station": [Vector2i(36, 16), Vector2i(30, 22)],
		"frozen_siding": [Vector2i(58, 20), Vector2i(63, 21), Vector2i(67, 19), Vector2i(72, 21), Vector2i(77, 20), Vector2i(86, 20)],
		"raiders": [Vector2i(35, 41), Vector2i(42, 40), Vector2i(38, 46)],
		"squad": [Vector2i(50, 6), Vector2i(48, 7), Vector2i(52, 7), Vector2i(50, 8)],
		"train_door": [Vector2i(50, 4), Vector2i(66, 4), Vector2i(34, 4)],
	}
	data["unload"] = Rect2i(16, 4, 82, 3)
	g.refresh_paths()
	return data


static func _containers(data: Dictionary) -> void:
	var list := [
		["bell", "출발 종", Vector2i(30, 13), 0, 2.0, ["symbol_bell"], false],
		["waiting_bench", "대합실 의자 밑", Vector2i(23, 17), 0, 4.0, ["cloth", "document"], false],
		["ticket_safe", "매표소 금고", Vector2i(22, 23), 0, 5.0, ["luxury_pack", "luxury_pack"], true],
		["office_desk", "역무실 책상", Vector2i(29, 21), 0, 6.0, ["info_telegraph", "info_timetable", "medkit"], false],
		["kiosk_shelf", "매점 선반", Vector2i(38, 21), 0, 5.0, ["food_pack", "food_pack", "luxury_pack"], false],
		["toilet_cabinet", "화장실 장", Vector2i(42, 23), 0, 3.0, ["cloth", "bottle_spirit"], false],
		["signal_desk", "신호소 탁자", Vector2i(106, 10), 1, 4.0, ["document", "flare"], false],
		["shop_shelf", "가게 선반", Vector2i(19, 44), 2, 6.0, ["food_pack", "food_pack", "bottle_spirit", "cloth"], false],
		["shop_back", "가게 창고", Vector2i(25, 45), 2, 5.0, ["food_pack", "plank", "plank"], false],
		["pharmacy_counter", "약국 계산대", Vector2i(38, 41), 3, 5.0, ["med_box", "bandage", "bandage"], false],
		["pharmacy_store", "약국 창고", Vector2i(36, 46), 3, 6.0, ["med_box", "med_box", "bandage"], false],
		["house1_kitchen", "주택 부엌", Vector2i(70, 45), 4, 6.0, ["food_pack", "bottle_spirit"], false],
		["house1_closet", "주택 옷장", Vector2i(76, 41), 4, 5.0, ["cloth", "ammo_pistol", "plank"], false],
		["house2_kitchen", "주택 부엌", Vector2i(87, 46), 5, 6.0, ["food_pack", "food_pack"], false],
		["house2_attic", "주택 다락 상자", Vector2i(94, 40), 5, 6.0, ["ammo_shell", "luxury_pack", "cloth"], false],
	]
	for row in list:
		data["containers"][row[0]] = {"id": row[0], "name": row[1], "cell": row[2], "building": row[3], "search": row[4], "items": row[5].duplicate(), "locked": row[6], "searched": false}


## Salvage points: scrap and wood by-products (field_unified 4장), normal sound.
static func _salvage(data: Dictionary) -> void:
	var list := [
		["salv_wagon", "화차 부품", Vector2i(80, 26), "scrap", 2],
		["salv_tender", "탄수차 철판", Vector2i(58, 26), "scrap", 1],
		["salv_bench", "대합실 긴 의자", Vector2i(40, 17), "wood", 2],
		["salv_fence", "울타리 판자", Vector2i(36, 57), "wood", 1],
		["salv_car", "부서진 차", Vector2i(66, 33), "scrap", 1],
	]
	for row in list:
		data["spots"][row[0]] = {"kind": "salvage", "name": row[1], "cell": row[2], "material": row[3], "amount": row[4], "state": "intact"}


static func _zones(g: FieldGrid) -> void:
	for y in range(g.height):
		for x in range(g.width):
			var c := Vector2i(x, y)
			var z := ""
			var b := g.building_at(c)
			if b == 0:
				z = "A"
			elif b == 1:
				z = "E"
			elif b >= 2:
				z = "D"
			elif x <= 13 and y <= 16:
				z = "C"
			elif x >= 16 and x <= 97 and y >= 4 and y <= 11:
				z = "platform"
			elif x >= 46 and y >= 13 and y <= 28:
				z = "B"
			elif y >= 29:
				z = "D"
			elif x >= 100 and y <= 14:
				z = "E"
			g.zone[g.index(c)] = z


static func _fill_floor(g: FieldGrid, r: Rect2i, kind: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			if g.inside(c):
				g.floor[g.index(c)] = kind


static func _fill_solid(g: FieldGrid, r: Rect2i, kind: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			g.set_solid(Vector2i(x, y), kind)


## Outer walls on the rectangle border; inside is a wooden floor of building id.
static func _building(g: FieldGrid, data: Dictionary, id: int, r: Rect2i) -> void:
	data["buildings"].append({"id": id, "name": BUILDING_NAMES[id], "rect": r, "warm": id == 0, "window_broken": false})
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			g.building[g.index(c)] = id
			g.floor[g.index(c)] = F.WOOD
			if x == r.position.x or y == r.position.y or x == r.end.x - 1 or y == r.end.y - 1:
				g.set_solid(c, S.WALL)


static func _wall_h(g: FieldGrid, y: int, x0: int, x1: int, id: int) -> void:
	for x in range(x0, x1 + 1):
		g.set_solid(Vector2i(x, y), S.WALL)


static func _wall_v(g: FieldGrid, x: int, y0: int, y1: int, id: int) -> void:
	for y in range(y0, y1 + 1):
		g.set_solid(Vector2i(x, y), S.WALL)


static func _door(g: FieldGrid, c: Vector2i, state: String, id: int) -> void:
	g.set_solid(c, S.DOOR)
	g.doors[c] = {"state": state, "hp": 8, "building": id, "cell": c}


static func _window(g: FieldGrid, c: Vector2i, id: int) -> void:
	g.set_solid(c, S.WINDOW)
	g.windows[c] = {"broken": false, "glass": false, "building": id, "cell": c}


static func _stove(g: FieldGrid, data: Dictionary, c: Vector2i, id: int) -> void:
	g.set_solid(c, S.LOW)
	data["stoves"].append({"cell": c, "building": id, "lit": true, "upstairs": false})
