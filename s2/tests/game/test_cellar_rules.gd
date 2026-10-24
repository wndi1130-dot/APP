extends "res://addons/gut/test.gd"
## 지하실 규칙(docs/design/briefs/house_layout.md 5장, 결정 423): 큰 지하의 마당 쪽 덧문,
## 지하 창 단서, 지하 부엌·침실을 보일러실·저장 칸으로.

const FieldGrid = preload("res://game/world/field_grid.gd")
const CellarRules = preload("res://game/world/cellar_rules.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")
const S = FieldGrid.Solid
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## 집 한 채(바깥벽 x 2~11 · y 2~9, 안 8×6 = 48칸)와 그 지하. 둘레 2칸은 마당(땅 층은 눈,
## 지하는 흙 덩이). 열차는 북쪽 멀리.
func _house(kind: String, inner: Vector2i = Vector2i(8, 6)) -> Dictionary:
	var w := 16
	var h := 14
	var levels: Dictionary = {}
	for lv in [-1, 0]:
		var g := FieldGrid.new(w, h)
		for y in range(h):
			for x in range(w):
				var c := Vector2i(x, y)
				var inside := x >= 2 and x <= 3 + inner.x and y >= 2 and y <= 3 + inner.y
				if inside:
					g.building[g.index(c)] = 0
					var wall: bool = x == 2 or x == 3 + inner.x or y == 2 or y == 3 + inner.y
					g.set_solid(c, S.WALL if wall else S.NONE)
				elif lv < 0:
					g.set_solid(c, S.BLOCK)
		levels[lv] = g
	var door := Vector2i(4, 2)
	levels[0].set_solid(door, S.DOOR)
	levels[0].doors[door] = {"state": "closed", "hp": 8, "building": 0, "cell": door}
	for g: FieldGrid in levels.values():
		g.refresh_paths()
	return {"grid": levels[0], "levels": levels, "place_kind": kind, "bands": {}, "train": Rect2i(0, -30, 16, 3),
		"stairs": [{"cell": Vector2i(5, 4), "low": -1, "high": 0, "ladder": false}], "props": [], "containers": {}}


func test_a_big_cellar_gets_a_yard_hatch() -> void:
	var d := _house("houses")
	assert_eq(CellarRules.hatches(d), 1)
	var hatch: Dictionary = d["stairs"][-1]
	assert_true(hatch.get("hatch", false))
	assert_eq(d["levels"][0].building_at(hatch["cell"] + hatch["into"]), 0, "건물 쪽으로 내려간다")
	assert_eq(int(hatch["low"]), -1)
	assert_eq(int(hatch["high"]), 0)
	var land: Vector2i = hatch["cell"]
	var cel: FieldGrid = d["levels"][-1]
	assert_eq(d["levels"][0].building_at(land), -1, "땅 층에서는 마당 칸")
	assert_true(d["levels"][0].people_can_walk(land))
	assert_eq(cel.building_at(land), 0, "지하에서는 그 건물의 계단참")
	assert_true(cel.people_can_walk(land))
	# 지하 방 안에서 계단참까지 걸어서 닿는다.
	var seen := {Vector2i(5, 5): true}
	var queue: Array[Vector2i] = [Vector2i(5, 5)]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_back()
		for dd in DIRS:
			var n := cur + dd
			if not seen.has(n) and cel.people_can_walk(n):
				seen[n] = true
				queue.append(n)
	assert_true(seen.has(land), "지하 방에서 덧문 계단까지")
	assert_gt(land.y, 9, "열차에서 먼 뒤뜰(남쪽)")


func test_small_cellars_and_other_kinds_keep_one_way() -> void:
	assert_eq(CellarRules.hatches(_house("houses", Vector2i(5, 4))), 0, "20칸 지하")
	assert_eq(CellarRules.hatches(_house("church")), 0, "교회 지도")


func test_a_cellar_shows_from_outside_by_low_windows() -> void:
	var d := _house("church")
	var rows := CellarRules.windows(d)
	assert_between(rows.size(), 1, CellarRules.WINDOWS_PER_BUILDING)
	for row: Dictionary in rows:
		var c: Vector2i = row["cell"]
		assert_eq(d["levels"][0].solid_at(c), S.WALL, "땅 층 바깥벽 칸")
		assert_eq(d["levels"][-1].solid_at(c), S.WALL, "지하도 벽")
		assert_eq(d["levels"][-1].building_at(c - row["out"]), 0, "벽 안쪽은 지하 방")
		assert_true(d["levels"][0].people_can_walk(c + row["out"]), "바깥은 보이는 마당")
		assert_ne(row["out"], Vector2i(0, -1), "카메라 반대쪽(북쪽) 겉면은 안 됨")


func test_cellar_kitchens_and_bedrooms_become_boiler_rooms_and_stores() -> void:
	assert_eq(RoomFurnish.room_class("부엌", {"dining_set": true}, -1), "boiler")
	assert_eq(RoomFurnish.room_class("안방", {"bed": true}, -1), "store")
	assert_eq(RoomFurnish.room_class("거실", {"bench": true}, -1), "store")
	assert_eq(RoomFurnish.room_class("부엌", {"dining_set": true}, 0), "kitchen", "땅 위 부엌은 그대로")
	for item: Dictionary in RoomFurnish.PALETTE["boiler"]:
		assert_true(RoomFurnish.blocks(String(item["kind"]), -1), "%s: 지하에서 보이고 막는 모델" % item["kind"])
