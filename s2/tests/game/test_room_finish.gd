extends "res://addons/gut/test.gd"
## 방 마감 그림(결정 469 C3): 방 갈래를 그 방의 가구로 읽고, 층마다 채널 하나에 갈래 + 8 × 판을 담는다.

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
	assert_eq(img.get_size(), Vector2i(11, 7))
	var bath := _code(img, Vector2i(3, 2), 0)
	var bed := _code(img, Vector2i(8, 4), 0)
	assert_eq(bath % 8, RoomFinish.BATH, "a toilet makes a bathroom, a dresser beside it does not win")
	assert_eq(bed % 8, RoomFinish.BED)
	assert_eq(bath >> 3, RoomFinish.variant_for(3, RoomFinish.BATH))
	assert_eq(_code(img, Vector2i(5, 2), 0), 0, "the wall between is no room")
	assert_eq(_code(img, Vector2i(0, 0), 0), 0, "out of doors")
	assert_eq(_code(img, Vector2i(7, 3), 1) % 8, RoomFinish.LIVING, "the floor above is its own channel")
	assert_eq(_code(img, Vector2i(3, 3), 1), 0, "a room with no telling furniture keeps the old look")


func test_one_house_one_finish_per_kind_and_houses_differ() -> void:
	var seen: Dictionary = {}
	for b in range(12):
		var v := RoomFinish.variant_for(b, RoomFinish.KITCHEN)
		assert_between(v, 0, RoomFinish.VARIANTS - 1)
		assert_eq(v, RoomFinish.variant_for(b, RoomFinish.KITCHEN), "the same house rolls the same")
		seen[v] = true
	assert_eq(seen.size(), RoomFinish.VARIANTS, "twelve houses use every finish")
