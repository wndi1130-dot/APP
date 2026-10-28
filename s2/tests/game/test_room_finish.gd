extends "res://addons/gut/test.gd"
## 방 마감 그림(결정 469 C3, 사용자 10-28): 방 갈래를 그 방의 가구로 읽고, 층마다 채널 하나에
## 갈래 + 8 × (지역 × VARIANTS + 판)을 담는다. 그림 오른쪽 절반은 깔개 칸.

const FieldGrid = preload("res://game/world/field_grid.gd")
const RoomFinish = preload("res://game/world/room_finish.gd")
const S = FieldGrid.Solid


## 집 한 채(11×7 칸): 바깥벽, 가운데 x 5에 세로 안벽(문 하나)으로 방 둘. 땅 층과 2층.
func _house() -> Dictionary:
	var levels: Dictionary = {}
	for lv in [0, 1]:
		var g := FieldGrid.new(11, 7)
		for y in range(7):
			for x in range(11):
				var c := Vector2i(x, y)
				if x >= 1 and x <= 9 and y >= 1 and y <= 5:
					g.building[g.index(c)] = 3
					var wall: bool = x == 1 or x == 9 or y == 1 or y == 5 or x == 5
					g.set_solid(c, S.WALL if wall else S.NONE)
		g.set_solid(Vector2i(5, 3), S.DOOR)
		levels[lv] = g
	return {"grid": levels[0], "levels": levels, "props": []}


func _prop(kind: String, rect: Rect2i, lv: int) -> Dictionary:
	return {"kind": kind, "rect": rect, "solid": "low", "facing": 0, "level": lv}


func _code(img: Image, c: Vector2i, channel: int) -> int:
	return roundi(img.get_pixelv(c)[channel] * 255.0)


func test_rooms_take_their_kind_from_their_furniture() -> void:
	var data := _house()
	data["props"] = [_prop("toilet", Rect2i(2, 2, 1, 1), 0), _prop("dresser", Rect2i(3, 4, 1, 1), 0),
		_prop("bed", Rect2i(6, 2, 2, 1), 0), _prop("settee", Rect2i(6, 4, 2, 1), 1)]
	var img := RoomFinish.build(data)
	assert_eq(img.get_size(), Vector2i(22, 7), "twice the map's width: finishes, then rugs")
	var bath := _code(img, Vector2i(3, 2), 0)
	var bed := _code(img, Vector2i(8, 4), 0)
	assert_eq(bath % 8, RoomFinish.BATH, "a toilet makes a bathroom, a dresser beside it does not win")
	assert_eq(bed % 8, RoomFinish.BED)
	assert_eq(bath >> 3, RoomFinish.variant_for(3, RoomFinish.BATH))
	assert_eq(_code(img, Vector2i(5, 2), 0), 0, "the wall between is no room")
	assert_eq(_code(img, Vector2i(0, 0), 0), 0, "out of doors")
	assert_eq(_code(img, Vector2i(7, 3), 1) % 8, RoomFinish.LIVING, "the floor above is its own channel")
	assert_eq(_code(img, Vector2i(3, 3), 1), 0, "a room with no telling furniture keeps the old look")


## room_furnish가 적은 방 갈래(rule)가 가구 종류보다 먼저: 가게 조리대는 부엌이 아니다.
func test_the_rooms_rule_comes_before_the_furniture_kind() -> void:
	var data := _house()
	var shop := _prop("counter", Rect2i(2, 2, 2, 1), 0)
	shop["rule"] = "shop"
	var lounge := _prop("bed", Rect2i(6, 2, 2, 1), 0)
	lounge["rule"] = "living"
	data["props"] = [shop, lounge, _prop("sink", Rect2i(2, 2, 1, 1), 1)]
	var img := RoomFinish.build(data)
	assert_eq(_code(img, Vector2i(3, 3), 0), 0, "a shop's counter makes no kitchen")
	assert_eq(_code(img, Vector2i(8, 4), 0) % 8, RoomFinish.LIVING, "the rule wins over a bed")
	assert_eq(_code(img, Vector2i(3, 3), 1) % 8, RoomFinish.KITCHEN, "no rule: the kind still tells")


## 손으로 그린 지도(첫 정차): 가구 대신 이름 붙은 상자. object_rules가 찬장에 붙인 책장은 믿지 않는다.
func test_hand_laid_boxes_tell_their_room_by_name() -> void:
	var data := _house()
	data["containers"] = {
		"pantry": {"id": "pantry", "name": "남쪽 주택 찬장", "cell": Vector2i(3, 3), "level": 0},
		"drawer": {"id": "drawer", "name": "주택 침실 서랍", "cell": Vector2i(7, 3), "level": 0,
			"furniture": "drawer_chest", "object_legacy": true},
		"attic": {"id": "attic", "name": "주택 다락 트렁크", "cell": Vector2i(3, 3), "level": 1},
		"laid": {"id": "laid", "name": "부엌 찬장", "cell": Vector2i(7, 3), "level": 1, "furniture": "cupboard"},
	}
	data["props"] = [{"kind": "bookcase", "rect": Rect2i(3, 3, 1, 1), "level": 0, "legacy_model": "res://x.glb"}]
	var img := RoomFinish.build(data)
	assert_eq(_code(img, Vector2i(2, 2), 0) % 8, RoomFinish.KITCHEN, "the cupboard's name says kitchen, not its bookcase")
	assert_eq(_code(img, Vector2i(8, 4), 0) % 8, RoomFinish.BED)
	assert_eq(_code(img, Vector2i(3, 3), 1), 0, "an attic trunk says no room")
	assert_eq(_code(img, Vector2i(7, 3), 1), 0, "a box laid in furniture is read from the furniture's prop")


func test_houses_and_rooms_of_a_kind_differ() -> void:
	var seen: Dictionary = {}
	for b in range(40):
		var v := RoomFinish.variant_for(b, RoomFinish.KITCHEN)
		assert_between(v, 0, RoomFinish.VARIANTS - 1)
		assert_eq(v, RoomFinish.variant_for(b, RoomFinish.KITCHEN), "the same house rolls the same")
		seen[v] = true
	assert_eq(seen.size(), RoomFinish.VARIANTS, "forty houses use every finish")
	var data := _house()
	data["props"] = [_prop("bed", Rect2i(2, 2, 2, 1), 0), _prop("bed", Rect2i(6, 2, 2, 1), 0)]
	var img := RoomFinish.build(data)
	var one := _code(img, Vector2i(3, 3), 0)
	var two := _code(img, Vector2i(7, 3), 0)
	assert_eq(one % 8, RoomFinish.BED)
	assert_eq(two % 8, RoomFinish.BED)
	assert_ne(one, two, "two bedrooms side by side in one house take the next finish each")


## 지역(결정 478)마다 판 묶음이 따로: 높은 산의 부엌은 읍내 부엌과 다른 판에서 고른다.
func test_the_region_picks_its_own_set_of_finishes() -> void:
	assert_eq(RoomFinish.region_index({"place_id": "houses_02"}), 0)
	assert_eq(RoomFinish.region_index({"place_id": "freight_01"}), 1)
	assert_eq(RoomFinish.region_index({"place_id": "sawmill_01"}), 2)
	assert_eq(RoomFinish.region_index({"place_id": "lodge_01"}), 3)
	assert_eq(RoomFinish.region_index({"place_id": "lake_01"}), 4)
	assert_eq(RoomFinish.region_index({"place_id": "bare_line_01"}), 5)
	assert_eq(RoomFinish.region_index({}), 0, "no place: the town's set")
	var data := _house()
	data["place_id"] = "lodge_01"
	data["props"] = [_prop("sink", Rect2i(2, 2, 1, 1), 0)]
	var code := _code(RoomFinish.build(data), Vector2i(3, 3), 0)
	assert_eq(code % 8, RoomFinish.KITCHEN)
	assert_eq(code >> 3, 3 * RoomFinish.VARIANTS + RoomFinish.variant_for(3, RoomFinish.KITCHEN))
	var top := 0
	for b in range(200):
		for cls in range(1, 8):
			for region in range(RoomFinish.REGIONS.size()):
				top = maxi(top, RoomFinish.code_for(b, cls, region))
	assert_lte(top, 255, "every code fits a byte")


## 식당(「식당」 이름표 방의 가구에 단 dining)은 식당, 그냥 거실의 식탁은 거실.
func test_a_dining_room_is_told_by_its_mark_not_by_its_table() -> void:
	var data := _house()
	var table := _prop("dining_set", Rect2i(2, 2, 2, 2), 0)
	table["rule"] = "living"
	table["dining"] = true
	var lounge_table := _prop("dining_set", Rect2i(6, 2, 2, 2), 0)
	lounge_table["rule"] = "living"
	data["props"] = [table, lounge_table]
	var img := RoomFinish.build(data)
	assert_eq(_code(img, Vector2i(3, 3), 0) % 8, RoomFinish.DINING)
	assert_eq(_code(img, Vector2i(7, 3), 0) % 8, RoomFinish.LIVING)


## 살림집 안의 찬방(rule store)은 창고 칸, 가구 없는 좁은 방은 복도. 살림집 밖은 그대로.
func test_store_rooms_and_halls_only_in_homes() -> void:
	var data := _house()
	var g0: FieldGrid = data["levels"][0]
	for y in range(2, 5):
		g0.set_solid(Vector2i(7, y), S.WALL)
	g0.set_solid(Vector2i(7, 3), S.DOOR)
	var pantry := _prop("small_shelf", Rect2i(8, 2, 1, 1), 0)
	pantry["rule"] = "store"
	data["props"] = [_prop("toilet", Rect2i(2, 2, 1, 1), 0), pantry]
	var img := RoomFinish.build(data)
	assert_eq(_code(img, Vector2i(8, 4), 0) % 8, RoomFinish.UTILITY, "a pantry in a home")
	assert_eq(_code(img, Vector2i(6, 3), 0) % 8, RoomFinish.HALL, "a bare room one cell wide")
	var shed := _house()
	var store := _prop("shelf", Rect2i(2, 2, 1, 1), 0)
	store["rule"] = "store"
	shed["props"] = [store]
	var img2 := RoomFinish.build(shed)
	assert_eq(_code(img2, Vector2i(3, 3), 0), 0, "a store room in a shop keeps the old look")
	assert_eq(_code(img2, Vector2i(7, 3), 0), 0, "no home, no hall")


## 깔개(room_furnish data.rugs)는 그림 오른쪽 절반의 같은 칸에 look 값으로.
func test_rugs_go_in_the_right_half() -> void:
	var data := _house()
	data["props"] = [_prop("bed", Rect2i(6, 2, 2, 1), 0)]
	data["rugs"] = [{"rect": Rect2i(6, 3, 2, 2), "level": 0, "look": 37}, {"rect": Rect2i(2, 2, 2, 2), "level": 1, "look": 5}]
	var img := RoomFinish.build(data)
	assert_eq(_code(img, Vector2i(11 + 6, 3), 0), 37)
	assert_eq(_code(img, Vector2i(11 + 7, 4), 0), 37)
	assert_eq(_code(img, Vector2i(11 + 6, 2), 0), 0, "only the rug's own cells")
	assert_eq(_code(img, Vector2i(11 + 3, 3), 1), 5, "a rug upstairs in its own channel")
	assert_eq(_code(img, Vector2i(6, 3), 0) % 8, RoomFinish.BED, "the finish half is untouched")
