extends RefCounted
## Sulechów stop as a graybox (s2_station.md 1장, first_leg_story.md 6.3).
## North is the top of the screen (−z). The train stands on the north track.
## All numbers are starting values; one cell is one metre.
##
## Build 21 (user, build 20 play): the map is about twice the area, so twenty
## minutes no longer cover it, and buildings have floors: the station flat,
## the signal box top, two houses with an upper floor, a three-storey
## tenement with a cellar whose drain opens on the sewer, and a goods shed
## with an office upstairs. Each level is its own grid (FieldGrid); stairs
## join the same cell on two levels.

const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor

const WIDTH: int = 170
const HEIGHT: int = 100
const LEVEL_H: float = 3.0
const PLACE_ID: String = "first_leg_01_sulechow"

const BUILDING_NAMES: Array[String] = ["역사", "신호소", "가게", "약국", "주택", "주택", "공동주택", "화물 창고", "남쪽 주택", "남쪽 주택", "남쪽 주택"]
const ZONE_NAMES: Dictionary = {"platform": "승강장", "A": "역사", "B": "화물 측선", "C": "급수탑", "D": "역 앞 거리", "E": "신호소", "F": "공동주택", "G": "화물 창고", "H": "남쪽 주택가", "": "바깥"}

## Everything the field needs besides the grid.
## grid: the ground level; levels: level -> FieldGrid (0 is grid);
## stairs: [{cell, low, high, ladder}] joining the same cell on two levels.
## containers: id -> {name, cell, level, building, search, items[], locked, searched}
## spots: interactable map features (water tower, ladder, work sites, stove, salvage)
static func build() -> Dictionary:
	var g := FieldGrid.new(WIDTH, HEIGHT)
	var up1 := _air_level()
	var up2 := _air_level()
	var cellar := _rock_level()
	var data := {
		"grid": g, "levels": {0: g, 1: up1, 2: up2, -1: cellar}, "stairs": [],
		"containers": {}, "spots": {}, "stoves": [], "entries": {},
		"buildings": [], "wagons": [], "train": Rect2i(16, 1, 80, 3), "platform": Rect2i(16, 4, 82, 6),
		"spawns": {}, "labels": [], "trees": [], "low_blocks": [], "upper_rects": [],
	}
	_fill_floor(g, Rect2i(0, 0, WIDTH, HEIGHT), F.SNOW)
	# Main track and the train.
	_fill_floor(g, Rect2i(0, 1, WIDTH, 3), F.RAIL)
	_fill_solid(g, Rect2i(16, 1, 80, 3), S.BLOCK)
	# Platform with icy ends.
	_fill_floor(g, Rect2i(16, 4, 82, 6), F.PLATFORM)
	_fill_floor(g, Rect2i(16, 4, 3, 6), F.ICE)
	_fill_floor(g, Rect2i(95, 4, 3, 6), F.ICE)
	# Roads: north road (west side), station street, south road, south-east
	# road, and the south street across the bottom of the town.
	_fill_floor(g, Rect2i(11, 0, 4, 34), F.ROAD)
	_fill_floor(g, Rect2i(11, 30, WIDTH - 11, 6), F.ROAD)
	_fill_floor(g, Rect2i(58, 36, 5, HEIGHT - 36), F.ROAD)
	_fill_floor(g, Rect2i(150, 36, 5, HEIGHT - 36), F.ROAD)
	_fill_floor(g, Rect2i(0, 76, WIDTH, 5), F.ROAD)
	# C water tower: a round solid, fire spot south of it.
	for y in range(3, 13):
		for x in range(2, 13):
			if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(7.5, 7.5)) <= 3.1:
				g.set_solid(Vector2i(x, y), S.BLOCK)
	data["spots"]["water_tower"] = {"kind": "water_tower", "cell": Vector2i(7, 12), "name": "급수탑", "state": "frozen"}
	# B freight siding: two siding tracks, wagons, deep snow between them, icy switches.
	_fill_floor(g, Rect2i(46, 16, 78, 1), F.RAIL)
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
	_station(data)
	_signal_box(data)
	_street(data)
	_tenement(data)
	_goods_shed(data)
	_south(data)
	# Wrecked cars on the streets (cover, low), fences and trees in the yards.
	for r in [Rect2i(40, 32, 4, 2), Rect2i(64, 31, 4, 2), Rect2i(90, 33, 4, 2), Rect2i(104, 31, 2, 4), Rect2i(136, 32, 4, 2), Rect2i(151, 58, 2, 4), Rect2i(30, 77, 4, 2), Rect2i(98, 78, 4, 2)]:
		_fill_solid(g, r, S.LOW)
		data["low_blocks"].append(r)
	for r in [Rect2i(2, 55, 12, 1), Rect2i(30, 56, 20, 1), Rect2i(68, 58, 30, 1), Rect2i(100, 58, 1, 14), Rect2i(104, 60, 26, 1), Rect2i(136, 44, 1, 26), Rect2i(18, 96, 30, 1), Rect2i(118, 96, 20, 1), Rect2i(160, 40, 1, 30)]:
		_fill_solid(g, r, S.LOW)
		data["low_blocks"].append(r)
	for c in [Vector2i(6, 24), Vector2i(9, 44), Vector2i(48, 62), Vector2i(80, 64), Vector2i(110, 66), Vector2i(114, 70), Vector2i(26, 64), Vector2i(4, 34), Vector2i(142, 48), Vector2i(146, 66), Vector2i(164, 52), Vector2i(8, 88), Vector2i(52, 90), Vector2i(70, 92), Vector2i(100, 90), Vector2i(144, 92), Vector2i(162, 86)]:
		g.set_solid(c, S.BLOCK)
		data["trees"].append(c)
	_zones(g)
	_containers(data)
	_salvage(data)
	# Rear hordes (user 2026-10-07): the sewer is the endless source. One street
	# manhole (can be blocked), the culvert under the water tower (cannot), and
	# the tenement cellar drain, a sewer mouth inside a building that the dead
	# climb out of and up the stairs (cannot be blocked; close the cellar door).
	# The train-following share comes along the roads and the east track end.
	data["manholes"] = {"manhole": Vector2i(54, 33), "culvert": Vector2i(3, 14), "cellar": Vector2i(110, 50)}
	data["labels"].append({"text": "맨홀", "cell": Vector2i(54, 32)})
	data["manhole_levels"] = {"cellar": -1}
	data["sewer_names"] = {"manhole": "거리 맨홀", "culvert": "급수탑 밑 암거", "cellar": "지하실 배수구"}
	data["entries"] = {
		"manhole": [Vector2i(54, 33)],
		"culvert": [Vector2i(3, 14), Vector2i(4, 14), Vector2i(3, 15), Vector2i(4, 15)],
		"cellar": [Vector2i(110, 50), Vector2i(111, 50)],
		"east_track": [Vector2i(WIDTH - 1, 2), Vector2i(WIDTH - 1, 1), Vector2i(WIDTH - 1, 3), Vector2i(WIDTH - 2, 2)],
		"north_road": [Vector2i(12, 0), Vector2i(13, 0), Vector2i(11, 0), Vector2i(14, 0)],
		"south_road": [Vector2i(60, HEIGHT - 1), Vector2i(59, HEIGHT - 1), Vector2i(61, HEIGHT - 1), Vector2i(62, HEIGHT - 1)],
		"east_road": [Vector2i(152, HEIGHT - 1), Vector2i(151, HEIGHT - 1), Vector2i(153, HEIGHT - 1), Vector2i(150, HEIGHT - 1)],
	}
	data["entry_levels"] = {"cellar": -1}
	# Seconds between bodies climbing out: a manhole lets one through every
	# 3 s, the culvert lets the horde out together (field_unified 6 하수도).
	data["entry_gap"] = {"manhole": 3.0, "culvert": 0.6, "cellar": 2.0, "east_track": 0.6, "north_road": 0.6, "south_road": 0.6, "east_road": 0.6}
	data["spawns"] = {
		"dead_street": [Vector2i(30, 33), Vector2i(46, 34), Vector2i(52, 31), Vector2i(66, 34), Vector2i(74, 32), Vector2i(80, 33), Vector2i(98, 31), Vector2i(110, 34), Vector2i(128, 33), Vector2i(146, 34), Vector2i(152, 50), Vector2i(60, 66), Vector2i(40, 78), Vector2i(86, 79), Vector2i(132, 78), Vector2i(152, 88)],
		"dead_platform": [Vector2i(12, 8), Vector2i(100, 13), Vector2i(47, 11), Vector2i(86, 11)],
		"dead_siding_end": [Vector2i(100, 17), Vector2i(101, 23), Vector2i(118, 20)],
		"clothed_station": [Vector2i(36, 16), Vector2i(30, 22)],
		"clothed_shed": [Vector2i(142, 16), Vector2i(146, 21)],
		"frozen_siding": [Vector2i(58, 20), Vector2i(63, 21), Vector2i(67, 19), Vector2i(72, 21), Vector2i(77, 20), Vector2i(86, 20)],
		"raiders": [Vector2i(35, 41), Vector2i(42, 40), Vector2i(38, 46)],
		"squad": [Vector2i(50, 6), Vector2i(48, 7), Vector2i(52, 7), Vector2i(50, 8)],
		"train_door": [Vector2i(50, 4), Vector2i(66, 4), Vector2i(34, 4)],
	}
	# The dead indoors on other floors: [cell, level].
	data["spawns"]["dead_levels"] = [
		[Vector2i(108, 44), 0], [Vector2i(125, 50), 0], [Vector2i(116, 45), 0],
		[Vector2i(108, 50), 1], [Vector2i(124, 44), 1], [Vector2i(117, 47), 1],
		[Vector2i(107, 43), 2], [Vector2i(126, 51), 2],
		[Vector2i(106, 51), -1], [Vector2i(122, 44), -1],
		[Vector2i(29, 22), 1], [Vector2i(74, 45), 1], [Vector2i(128, 20), 1],
		[Vector2i(26, 90), 0], [Vector2i(126, 89), 1],
	]
	data["unload"] = Rect2i(16, 4, 82, 3)
	for lv in data["levels"]:
		var lg: FieldGrid = data["levels"][lv]
		if lv != 0:
			lg.zone = g.zone
		lg.refresh_paths()
	return data


## An upper level: open air everywhere until a building puts a floor in.
static func _air_level() -> FieldGrid:
	var lg := FieldGrid.new(WIDTH, HEIGHT)
	lg.solid.fill(S.AIR)
	lg.opq.fill(0)
	return lg


## The cellar level: rock everywhere until a cellar is dug out.
static func _rock_level() -> FieldGrid:
	var lg := FieldGrid.new(WIDTH, HEIGHT)
	lg.solid.fill(S.BLOCK)
	lg.opq.fill(1)
	return lg


static func _station(data: Dictionary) -> void:
	var g: FieldGrid = data["grid"]
	var up1: FieldGrid = data["levels"][1]
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
	# Upstairs over the west half: the stationmaster's flat, two rooms.
	_upper(up1, data, 0, Rect2i(20, 12, 14, 14))
	_wall_h(up1, 19, 21, 32, 0)
	up1.set_solid(Vector2i(27, 19), S.NONE)
	for c in [Vector2i(24, 12), Vector2i(30, 12), Vector2i(24, 25), Vector2i(30, 25), Vector2i(20, 17), Vector2i(20, 22)]:
		_window(up1, c, 0)
	_stair(data, Vector2i(21, 13), 0, 1)


static func _signal_box(data: Dictionary) -> void:
	var g: FieldGrid = data["grid"]
	var up1: FieldGrid = data["levels"][1]
	# E signal box: two floors, a ladder inside, an empty stove upstairs.
	_building(g, data, 1, Rect2i(104, 6, 6, 6))
	_door(g, Vector2i(104, 9), "closed", 1)
	_window(g, Vector2i(107, 6), 1)
	data["spots"]["ladder"] = {"kind": "ladder", "cell": Vector2i(107, 8), "name": "사다리", "state": "down"}
	_upper(up1, data, 1, Rect2i(104, 6, 6, 6))
	for c in [Vector2i(106, 6), Vector2i(109, 8), Vector2i(106, 11), Vector2i(104, 8)]:
		_window(up1, c, 1)
	up1.set_solid(Vector2i(108, 7), S.LOW)
	data["stoves"].append({"cell": Vector2i(108, 7), "building": 1, "lit": false, "upstairs": true, "level": 1})
	_stair(data, Vector2i(107, 8), 0, 1, true)


static func _street(data: Dictionary) -> void:
	var g: FieldGrid = data["grid"]
	var up1: FieldGrid = data["levels"][1]
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
	# House 1 with bedrooms upstairs.
	_building(g, data, 4, Rect2i(68, 38, 11, 11))
	_wall_v(g, 73, 39, 47, 4)
	_door(g, Vector2i(73, 43), "open", 4)
	_door(g, Vector2i(71, 38), "closed", 4)
	for c in [Vector2i(76, 38), Vector2i(78, 43)]:
		_window(g, c, 4)
	_upper(up1, data, 4, Rect2i(68, 38, 11, 11))
	_wall_v(up1, 73, 39, 47, 4)
	up1.set_solid(Vector2i(73, 42), S.NONE)
	for c in [Vector2i(71, 38), Vector2i(76, 38), Vector2i(68, 43), Vector2i(78, 45), Vector2i(71, 48)]:
		_window(up1, c, 4)
	_stair(data, Vector2i(70, 39), 0, 1)
	# House 2 with an attic room.
	_building(g, data, 5, Rect2i(84, 38, 13, 11))
	_wall_h(g, 43, 85, 95, 5)
	_door(g, Vector2i(90, 43), "open", 5)
	_door(g, Vector2i(88, 38), "closed", 5)
	for c in [Vector2i(93, 38), Vector2i(96, 41)]:
		_window(g, c, 5)
	_upper(up1, data, 5, Rect2i(84, 38, 13, 11))
	for c in [Vector2i(88, 38), Vector2i(93, 38), Vector2i(96, 45), Vector2i(84, 44)]:
		_window(up1, c, 5)
	_stair(data, Vector2i(85, 39), 0, 1)


## F: a three-storey tenement with a stairwell in the middle, a flat on each
## side of it on every floor, and a cellar. The cellar drain is a sewer mouth;
## the cellar door off the stairwell is the only thing between it and the stairs.
static func _tenement(data: Dictionary) -> void:
	var g: FieldGrid = data["grid"]
	var r := Rect2i(104, 40, 26, 14)
	_building(g, data, 6, r)
	_tenement_floor(g, 0)
	_door(g, Vector2i(116, 40), "closed", 6)
	_door(g, Vector2i(113, 46), "closed", 6)
	_door(g, Vector2i(120, 46), "locked", 6)
	# Cellar nook: a door off the stairwell, the stair down behind it.
	_wall_v(g, 118, 48, 52, 6)
	_wall_h(g, 48, 118, 119, 6)
	_door(g, Vector2i(119, 48), "closed", 6)
	for c in [Vector2i(107, 40), Vector2i(110, 40), Vector2i(123, 40), Vector2i(126, 40), Vector2i(107, 53), Vector2i(126, 53), Vector2i(104, 46)]:
		_window(g, c, 6)
	data["labels"].append({"text": "계단실", "cell": Vector2i(116, 44)})
	for lv in [1, 2]:
		var lg: FieldGrid = data["levels"][lv]
		_upper(lg, data, 6, r)
		_tenement_floor(lg, lv)
		for c in [Vector2i(107, 40), Vector2i(110, 40), Vector2i(123, 40), Vector2i(126, 40), Vector2i(107, 53), Vector2i(110, 53), Vector2i(123, 53), Vector2i(126, 53), Vector2i(104, 46), Vector2i(129, 46)]:
			_window(lg, c, 6)
	_stair(data, Vector2i(114, 51), 0, 1)
	_stair(data, Vector2i(116, 51), 1, 2)
	_stair(data, Vector2i(119, 51), -1, 0)
	# Cellar: a corridor and storage stalls under the whole house.
	var cel: FieldGrid = data["levels"][-1]
	_dig(cel, data, 6, r)
	_wall_h(cel, 47, 105, 117, 6)
	_wall_h(cel, 47, 121, 128, 6)
	for x in [108, 125]:
		cel.set_solid(Vector2i(x, 47), S.NONE)
	_wall_v(cel, 113, 41, 46, 6)
	_wall_v(cel, 120, 41, 46, 6)
	data["labels"].append({"text": "지하실", "cell": Vector2i(112, 50), "level": -1})


## One floor of the tenement: stairwell walls with flat doorways.
static func _tenement_floor(lg: FieldGrid, lv: int) -> void:
	_wall_v(lg, 113, 41, 52, 6)
	_wall_v(lg, 120, 41, 52, 6)
	_wall_h(lg, 47, 105, 112, 6)
	_wall_h(lg, 47, 121, 128, 6)
	lg.set_solid(Vector2i(108, 47), S.NONE)
	lg.set_solid(Vector2i(125, 47), S.NONE)
	if lv > 0:
		lg.set_solid(Vector2i(113, 46), S.NONE)
		lg.set_solid(Vector2i(120, 46), S.NONE)


## G: the goods shed at the east end of the siding; the foreman's office
## upstairs looks over the whole siding.
static func _goods_shed(data: Dictionary) -> void:
	var g: FieldGrid = data["grid"]
	var up1: FieldGrid = data["levels"][1]
	_building(g, data, 7, Rect2i(124, 12, 30, 14))
	_door(g, Vector2i(124, 16), "closed", 7)
	_door(g, Vector2i(138, 25), "closed", 7)
	_door(g, Vector2i(153, 20), "locked", 7)
	for c in [Vector2i(130, 12), Vector2i(146, 12), Vector2i(146, 25)]:
		_window(g, c, 7)
	_wall_v(g, 134, 13, 24, 7)
	_door(g, Vector2i(134, 18), "open", 7)
	data["labels"].append({"text": "창고", "cell": Vector2i(144, 18)})
	data["labels"].append({"text": "사무실", "cell": Vector2i(129, 19)})
	_upper(up1, data, 7, Rect2i(124, 12, 11, 14))
	for c in [Vector2i(128, 12), Vector2i(131, 12), Vector2i(124, 20), Vector2i(128, 25)]:
		_window(up1, c, 7)
	_stair(data, Vector2i(126, 23), 0, 1)


## H: the south street, three houses, gardens behind fences.
static func _south(data: Dictionary) -> void:
	var g: FieldGrid = data["grid"]
	var up1: FieldGrid = data["levels"][1]
	_building(g, data, 8, Rect2i(20, 84, 12, 10))
	_door(g, Vector2i(25, 84), "closed", 8)
	_wall_h(g, 89, 21, 30, 8)
	g.set_solid(Vector2i(23, 89), S.NONE)
	for c in [Vector2i(22, 84), Vector2i(29, 84), Vector2i(31, 90)]:
		_window(g, c, 8)
	_upper(up1, data, 8, Rect2i(20, 84, 12, 10))
	for c in [Vector2i(22, 84), Vector2i(29, 84), Vector2i(20, 90)]:
		_window(up1, c, 8)
	_stair(data, Vector2i(30, 92), 0, 1)
	_building(g, data, 9, Rect2i(80, 84, 12, 10))
	_door(g, Vector2i(85, 84), "locked", 9)
	_door(g, Vector2i(91, 90), "closed", 9)
	for c in [Vector2i(82, 84), Vector2i(89, 84)]:
		_window(g, c, 9)
	_building(g, data, 10, Rect2i(120, 84, 14, 10))
	_door(g, Vector2i(126, 84), "closed", 10)
	_wall_v(g, 127, 85, 92, 10)
	g.set_solid(Vector2i(127, 88), S.NONE)
	for c in [Vector2i(122, 84), Vector2i(131, 84), Vector2i(133, 89)]:
		_window(g, c, 10)
	_upper(up1, data, 10, Rect2i(120, 84, 14, 10))
	for c in [Vector2i(122, 84), Vector2i(131, 84), Vector2i(120, 89), Vector2i(133, 89)]:
		_window(up1, c, 10)
	_stair(data, Vector2i(121, 92), 0, 1)


static func _containers(data: Dictionary) -> void:
	# id, name, cell, building, search seconds, items, locked, level
	var list := [
		["bell", "출발 종", Vector2i(30, 13), 0, 2.0, ["symbol_bell"], false, 0],
		["waiting_bench", "대합실 의자 밑", Vector2i(23, 17), 0, 4.0, ["cloth", "document"], false, 0],
		["ticket_safe", "매표소 금고", Vector2i(22, 23), 0, 5.0, ["luxury_pack", "luxury_pack"], true, 0],
		["office_desk", "역무실 책상", Vector2i(29, 21), 0, 6.0, ["info_telegraph", "info_timetable", "medkit"], false, 0],
		["kiosk_shelf", "매점 선반", Vector2i(38, 21), 0, 5.0, ["food_pack", "food_pack", "luxury_pack"], false, 0],
		["toilet_cabinet", "화장실 장", Vector2i(42, 23), 0, 3.0, ["cloth", "bottle_spirit"], false, 0],
		["flat_wardrobe", "역장 옷장", Vector2i(31, 14), 0, 5.0, ["cloth", "ammo_pistol"], false, 1],
		["flat_desk", "역장 책상", Vector2i(24, 22), 0, 5.0, ["document", "info_timetable"], false, 1],
		["flat_cupboard", "역장 부엌 찬장", Vector2i(31, 23), 0, 4.0, ["food_pack", "bottle_spirit"], false, 1],
		["signal_desk", "신호소 탁자", Vector2i(106, 10), 1, 4.0, ["document", "flare"], false, 1],
		["shop_shelf", "가게 선반", Vector2i(19, 44), 2, 6.0, ["food_pack", "food_pack", "bottle_spirit", "cloth"], false, 0],
		["shop_back", "가게 창고", Vector2i(25, 45), 2, 5.0, ["food_pack", "plank", "plank"], false, 0],
		["pharmacy_counter", "약국 계산대", Vector2i(38, 41), 3, 5.0, ["med_box", "bandage", "bandage"], false, 0],
		["pharmacy_store", "약국 창고", Vector2i(36, 46), 3, 6.0, ["med_box", "med_box", "bandage"], false, 0],
		["house1_kitchen", "주택 부엌", Vector2i(70, 45), 4, 6.0, ["food_pack", "bottle_spirit"], false, 0],
		["house1_closet", "주택 옷장", Vector2i(76, 41), 4, 5.0, ["cloth", "ammo_pistol", "plank"], false, 0],
		["house1_bedroom", "주택 침실 서랍", Vector2i(76, 46), 4, 5.0, ["cloth", "bandage"], false, 1],
		["house1_trunk", "주택 다락 트렁크", Vector2i(70, 46), 4, 6.0, ["luxury_pack", "cloth"], false, 1],
		["house2_kitchen", "주택 부엌", Vector2i(87, 46), 5, 6.0, ["food_pack", "food_pack"], false, 0],
		["house2_attic", "주택 다락 상자", Vector2i(94, 40), 5, 6.0, ["ammo_shell", "luxury_pack", "cloth"], false, 1],
		["ten_w0_kitchen", "1층 서쪽 집 부엌", Vector2i(106, 50), 6, 5.0, ["food_pack", "bottle_spirit"], false, 0],
		["ten_w0_wardrobe", "1층 서쪽 집 옷장", Vector2i(111, 42), 6, 5.0, ["cloth", "cloth"], false, 0],
		["ten_e0_kitchen", "1층 동쪽 집 부엌", Vector2i(127, 50), 6, 5.0, ["food_pack", "food_pack", "luxury_pack"], false, 0],
		["ten_w1_kitchen", "2층 서쪽 집 부엌", Vector2i(106, 50), 6, 5.0, ["food_pack", "bandage"], false, 1],
		["ten_w1_desk", "2층 서쪽 집 책상", Vector2i(111, 42), 6, 4.0, ["document", "luxury_pack"], false, 1],
		["ten_e1_kitchen", "2층 동쪽 집 부엌", Vector2i(127, 50), 6, 5.0, ["food_pack", "bottle_spirit"], false, 1],
		["ten_e1_wardrobe", "2층 동쪽 집 옷장", Vector2i(122, 42), 6, 5.0, ["cloth", "ammo_shell"], false, 1],
		["ten_w2_kitchen", "3층 서쪽 집 부엌", Vector2i(106, 50), 6, 5.0, ["food_pack", "med_box"], false, 2],
		["ten_e2_wardrobe", "3층 동쪽 집 옷장", Vector2i(122, 42), 6, 5.0, ["cloth", "ammo_pistol", "luxury_pack"], false, 2],
		["ten_e2_kitchen", "3층 동쪽 집 부엌", Vector2i(127, 50), 6, 5.0, ["food_pack", "food_pack"], false, 2],
		["cellar_stall_w", "지하 창고 칸", Vector2i(106, 42), 6, 6.0, ["plank", "bottle_spirit", "food_pack"], false, -1],
		["cellar_stall_e", "지하 창고 칸", Vector2i(126, 42), 6, 6.0, ["cloth", "luxury_pack", "plank"], false, -1],
		["shed_crates", "창고 나무 상자", Vector2i(140, 15), 7, 7.0, ["plank", "plank", "food_pack"], false, 0],
		["shed_cabinet", "창고 공구함", Vector2i(142, 23), 7, 5.0, ["scrap", "cloth"], false, 0],
		["shed_sacks", "창고 자루 더미", Vector2i(149, 22), 7, 6.0, ["food_pack", "food_pack"], false, 0],
		["shed_office_desk", "창고 사무실 책상", Vector2i(128, 14), 7, 5.0, ["document", "info_telegraph"], false, 0],
		["shed_foreman", "반장 사물함", Vector2i(130, 15), 7, 5.0, ["ammo_shell", "medkit", "cloth"], true, 1],
		["shed_files", "운송 장부", Vector2i(127, 22), 7, 4.0, ["document", "info_timetable"], false, 1],
		["south1_kitchen", "남쪽 주택 부엌", Vector2i(22, 87), 8, 5.0, ["food_pack", "bottle_spirit"], false, 0],
		["south1_bedroom", "남쪽 주택 침실", Vector2i(28, 87), 8, 5.0, ["cloth", "med_box"], false, 1],
		["south2_pantry", "남쪽 주택 찬장", Vector2i(86, 91), 9, 6.0, ["food_pack", "food_pack", "food_pack"], false, 0],
		["south3_shelf", "남쪽 주택 선반", Vector2i(124, 88), 10, 5.0, ["plank", "cloth"], false, 0],
		["south3_attic", "남쪽 주택 다락", Vector2i(130, 86), 10, 6.0, ["ammo_shell", "luxury_pack"], false, 1],
	]
	for row in list:
		data["containers"][row[0]] = {"id": row[0], "name": row[1], "cell": row[2], "building": row[3], "search": row[4], "items": row[5].duplicate(), "locked": row[6], "level": row[7], "searched": false}


## Salvage points: scrap and wood by-products (field_unified 4장), normal sound.
static func _salvage(data: Dictionary) -> void:
	var list := [
		["salv_wagon", "화차 부품", Vector2i(80, 26), "scrap", 2],
		["salv_tender", "탄수차 철판", Vector2i(58, 26), "scrap", 1],
		["salv_bench", "대합실 긴 의자", Vector2i(40, 17), "wood", 2],
		["salv_fence", "울타리 판자", Vector2i(36, 57), "wood", 1],
		["salv_car", "부서진 차", Vector2i(66, 33), "scrap", 1],
		["salv_shed_shelf", "창고 선반", Vector2i(150, 14), "wood", 2],
		["salv_cart", "고장 난 손수레", Vector2i(144, 21), "scrap", 2],
		["salv_south_fence", "뒤뜰 울타리", Vector2i(40, 95), "wood", 1],
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
			elif b == 6:
				z = "F"
			elif b == 7:
				z = "G"
			elif b >= 8:
				z = "H"
			elif b >= 2:
				z = "D"
			elif x <= 13 and y <= 16:
				z = "C"
			elif x >= 16 and x <= 97 and y >= 4 and y <= 11:
				z = "platform"
			elif x >= 122 and y >= 10 and y <= 28:
				z = "G"
			elif x >= 46 and y >= 13 and y <= 28:
				z = "B"
			elif y >= 76:
				z = "H"
			elif x >= 100 and y >= 36:
				z = "F"
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
	_rooms(g, id, r)


## An upper floor of building id over rect r on level grid lg.
static func _upper(lg: FieldGrid, data: Dictionary, id: int, r: Rect2i) -> void:
	_rooms(lg, id, r)
	data["upper_rects"].append({"building": id, "rect": r})


## The cellar under rect r: dug out of the rock, walled round.
static func _dig(lg: FieldGrid, data: Dictionary, id: int, r: Rect2i) -> void:
	_rooms(lg, id, r)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			lg.floor[lg.index(Vector2i(x, y))] = F.GRAVEL


static func _rooms(g: FieldGrid, id: int, r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			g.building[g.index(c)] = id
			g.floor[g.index(c)] = F.WOOD
			if x == r.position.x or y == r.position.y or x == r.end.x - 1 or y == r.end.y - 1:
				g.set_solid(c, S.WALL)
			else:
				g.set_solid(c, S.NONE)


## Stairs (or a ladder) join the same cell on two levels.
static func _stair(data: Dictionary, c: Vector2i, low: int, high: int, ladder: bool = false) -> void:
	data["stairs"].append({"cell": c, "low": low, "high": high, "ladder": ladder})


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
	data["stoves"].append({"cell": c, "building": id, "lit": true, "upstairs": false, "level": 0})
