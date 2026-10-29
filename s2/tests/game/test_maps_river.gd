extends "res://addons/gut/test.gd"
## 강을 건너는 지도(다리·호수 마을 설계 10-29): 깊은 물은 못 건너고 건넘목으로만, 돌아가는 길은 지름길의 1.5~2.5배.

const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")
const SidePath = preload("res://game/world/side_path.gd")
const HOUSES_07 = preload("res://game/world/maps/houses_07.gd")
const DIRS = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var _d: Dictionary = {}


func before_all() -> void:
	_d = HOUSES_07.build()


func after_all() -> void:
	_d.clear()


func _rect(a: Array) -> Rect2i:
	return Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))


## 깊은 물 줄(얼음 둑 두 칸씩을 뺀 강).
func _deep() -> Rect2i:
	var river := _rect(HOUSES_07.PLAN["river"])
	return Rect2i(river.position.x, river.position.y + 2, river.size.x, river.size.y - 4)


## 네 방향 걷는 칸 수. `shut` 건넘목의 깊은 물 칸은 막는다. 못 가면 -1. 바깥 띠를 붙인 지도는
## `g`와 띠 너비만큼 밀린 `off`를 준다(a·b는 밀린 칸).
func _path(a: Vector2i, b: Vector2i, shut: Array, g: FieldGrid = null, off: Vector2i = Vector2i.ZERO) -> int:
	if g == null:
		g = _d["grid"]
	var deep := _deep()
	var seen := {a: 0}
	var queue: Array[Vector2i] = [a]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if c == b:
			return int(seen[c])
		for step: Vector2i in DIRS:
			var n := c + step
			if seen.has(n) or not g.inside(n) or not g.people_can_walk(n):
				continue
			var closed := false
			for key: String in shut:
				closed = closed or (deep.has_point(n - off) and _rect(HOUSES_07.PLAN[key]).has_point(n - off))
			if closed:
				continue
			seen[n] = int(seen[c]) + 1
			queue.append(n)
	return -1


func test_registered_with_the_judgment_line() -> void:
	assert_true(FieldMaps.has("houses_07"))
	assert_eq(_d["place_id"], "houses_07")
	var first := FileAccess.get_file_as_string("res://game/world/maps/houses_07.gd").get_slice("\n", 0)
	assert_true(first.begins_with("# 이 지도가 다른 판단을 만드는 것: "), first)


func test_deep_water_is_crossed_only_at_the_arch_ford_and_truss() -> void:
	var g: FieldGrid = _d["grid"]
	var deep := _deep()
	var spans: Array[Rect2i] = []
	for key: String in ["arch", "ford", "truss"]:
		spans.append(_rect(HOUSES_07.PLAN[key]))
	for y in range(deep.position.y, deep.end.y):
		var open_in := [0, 0, 0]
		for x in range(deep.position.x, deep.end.x):
			var c := Vector2i(x, y)
			if not g.people_can_walk(c):
				continue
			var inside := -1
			for i in range(spans.size()):
				if spans[i].has_point(c):
					inside = i
			assert_true(inside >= 0, "건넘목 밖 깊은 물이 걸린다: %s" % str(c))
			if inside >= 0:
				open_in[inside] += 1
		for i in range(spans.size()):
			assert_gt(open_in[i], 0, "건넘목 %d가 %d줄에서 끊김" % [i, y])


func test_ford_detour_is_one_and_a_half_to_two_and_a_half_times_the_arch() -> void:
	var start := Vector2i(82, 31)
	var goal := Vector2i(82, 70)
	var arch := _path(start, goal, ["ford", "truss"])
	var ford := _path(start, goal, ["arch", "truss"])
	assert_gt(arch, 0)
	assert_gt(ford, 0)
	var ratio := float(ford) / float(arch)
	assert_between(ratio, 1.5, 2.5, "여울 %d칸 / 아치 %d칸" % [ford, arch])


## 바깥 띠(map_ring.gd edge_water)에서도 강이 새 끝까지 이어진다: 띠의 깊은 물은 걷지 못하고,
## 세 건넘목을 다 막으면 띠 길로 돌아서도 건너편에 못 간다.
func test_the_river_runs_on_through_the_outer_ring() -> void:
	var d := FieldMaps.build("houses_07")
	var g: FieldGrid = d["grid"]
	var off: Vector2i = (d["map_ring"]["inner"] as Rect2i).position
	var deep := _deep()
	for y in range(deep.position.y, deep.end.y):
		for x: int in [0, off.x - 1, g.width - off.x, g.width - 1]:
			var c := Vector2i(x, y + off.y)
			assert_eq(g.floor_at(c), FieldGrid.Floor.ICE, "띠의 강 바닥: %s" % str(c))
			assert_false(g.people_can_walk(c), "띠의 깊은 물이 걸린다: %s" % str(c))
	var start := Vector2i(82, 31) + off
	var goal := Vector2i(82, 70) + off
	assert_gt(_path(start, goal, ["ford", "truss"], g, off), 0, "아치로는 건넌다")
	assert_eq(_path(start, goal, ["arch", "ford", "truss"], g, off), -1, "띠로 도는 넷째 길")
	# 늘린 강 rect는 새 끝에 닿고, 샛길(side_path.gd)은 강이 닿는 왼쪽·오른쪽 끝에 붙지 않는다.
	for r: Rect2i in d["edge_water"]:
		assert_eq([r.position.x, r.end.x], [0, g.width], "새 끝까지 늘린 강")
	var spot := SidePath.pick(d, RandomNumberGenerator.new())
	assert_false(not spot.is_empty() and int(spot["side"]) % 2 == 1, "샛길이 강 끝에: %s" % str(spot))
	# 샛길이 붙은 판에서도 세 건넘목을 다 막으면 못 건넌다.
	var s := 1
	while not SidePath.rolls("houses_07", s) and s < 200:
		s += 1
	var walked := SidePath.add(d, s)
	assert_true(walked.has("side_path"), "씨앗 %d에 샛길" % s)
	var moved: Vector2i = (walked["map_ring"]["inner"] as Rect2i).position
	var grid: FieldGrid = walked["grid"]
	assert_eq(_path(Vector2i(82, 31) + moved, Vector2i(82, 70) + moved, ["arch", "ford", "truss"], grid, moved), -1, "샛길로 도는 넷째 길")


## 모든 지도의 약속: 처음 선 망자는 열차 둘레 띠(bands) 밖이다. 북쪽 다리 끝 망자는 물가 얼음 위에 선다.
func test_initial_dead_stand_outside_the_train_bands() -> void:
	for key: String in _d["spawns"]:
		if not key.begins_with("dead_") or key == "dead_levels":
			continue
		for c: Vector2i in _d["spawns"][key]:
			for band: Rect2i in _d["bands"].values():
				assert_false(band.has_point(c), "%s %s가 열차 띠 안" % [key, str(c)])
			assert_true((_d["grid"] as FieldGrid).dead_can_walk(c), str(c))


## 아치 양 끝 둘레 10 m 안에 망자 자리 둘~넷(위험은 값진 자리 둘레).
func test_dead_stand_by_the_arch_ends() -> void:
	var arch := _rect(HOUSES_07.PLAN["arch"])
	var ends: Array[Vector2] = [Vector2(arch.get_center().x, arch.position.y), Vector2(arch.get_center().x, arch.end.y)]
	var near := 0
	for c: Vector2i in _d["spawns"]["dead_street"]:
		var at := Vector2(c) + Vector2(0.5, 0.5)
		near += 1 if at.distance_to(ends[0]) <= 10.0 or at.distance_to(ends[1]) <= 10.0 else 0
	assert_between(near, 2, 4)


## 같은 갈래의 몫: 지도가 주는 묶음 합이 houses 01~06의 정차 평균(216, 10-29 잰 값)에서 ±10% 안.
func test_bundles_keep_the_houses_share() -> void:
	var total := 0
	for box: Dictionary in _d["containers"].values():
		total += (box.get("items", []) as Array).size()
	assert_between(total, 195, 238, "묶음 %d" % total)


func test_truss_is_blocked_by_the_wagon_but_one_cell_gap() -> void:
	var g: FieldGrid = _d["grid"]
	var truss := _rect(HOUSES_07.PLAN["truss"])
	var deep := _deep()
	var narrowest := truss.size.x
	for y in range(deep.position.y, deep.end.y):
		var open := 0
		for x in range(truss.position.x, truss.end.x):
			open += 1 if g.people_can_walk(Vector2i(x, y)) else 0
		narrowest = mini(narrowest, open)
	assert_eq(narrowest, 1, "넘어진 화차 곁 한 칸 틈")


func test_row_houses_split_every_floor_into_two_homes() -> void:
	var rows := 0
	for row: Dictionary in _d["buildings"]:
		if not row.has("row_group"):
			continue
		rows += 1
		for lv in range(int(row["top"])):
			var rooms := 0
			for room: Dictionary in RoomFurnish.rooms_of(_d["levels"][lv])["rooms"]:
				rooms += 1 if int(room["building"]) == int(row["id"]) else 0
			assert_gte(rooms, 6, "%s %d층: 집 둘 × 방 셋" % [row["name"], lv])
	assert_eq(rows, 4)


## 정차를 차릴 때 물건은 같은 건물 상자끼리만 옮겨 담긴다: 연립마다 지도 물건이 있고(통째로 빈 건물 없음),
## 선창 창고는 상자당 물건이 다음 건물의 두 배를 넘는 가장 값진 자리다(코디 판단 442, 10-30).
func test_every_row_house_holds_things_and_the_warehouse_leads() -> void:
	var per: Dictionary = {}  # 건물 -> [상자, 물건]
	for box: Dictionary in _d["containers"].values():
		var b := int(box.get("building", -1))
		if b < 0:
			continue
		var pb: Array = per.get_or_add(b, [0, 0])
		pb[0] += 1
		pb[1] += (box.get("items", []) as Array).size()
	var best_other := 0.0
	for row: Dictionary in _d["buildings"]:
		var pb: Array = per.get(int(row["id"]), [0, 0])
		if row.has("row_group"):
			assert_gt(int(pb[1]), 0, "%s에 물건" % row["name"])
		if int(row["id"]) != 8 and int(pb[0]) > 0:
			best_other = maxf(best_other, float(pb[1]) / pb[0])
	var wh: Array = per[8]
	assert_gte(float(wh[1]) / wh[0], 2.0 * best_other, "선창 창고 상자당 물건")


## 같은 셈의 상자 몫: 상자 하나당 묶음이 houses 01~06(0.46~0.70, 10-29 잰 값)의 +25% 안이고, 연립은 층마다
## 두 집 모두 부엌 여닫는 자리가 선다(방 이름표가 없으면 이름에 「집」이 없는 연립은 방 갈래를 못 물려받는다).
func test_boxes_keep_the_houses_share() -> void:
	var d := FieldMaps.build("houses_07")
	var bundles := 0
	var kitchens: Dictionary = {}
	for id: String in d["containers"]:
		var box: Dictionary = d["containers"][id]
		bundles += (box.get("items", []) as Array).size()
		if id.begins_with("kitchen_"):
			var b := int(box.get("building", -1))
			kitchens[b] = int(kitchens.get(b, 0)) + 1
	assert_between(float(bundles) / d["containers"].size(), 0.46, 0.875, "상자 %d · 묶음 %d" % [d["containers"].size(), bundles])
	for row: Dictionary in d["buildings"]:
		if row.has("row_group"):
			assert_gte(int(kitchens.get(int(row["id"]), 0)), 2 * int(row["top"]), "%s 부엌 자리" % row["name"])


func test_every_box_is_reached_from_the_train_across_floors() -> void:
	var links: Dictionary = {}
	for s: Dictionary in _d["stairs"]:
		var c: Vector2i = s["cell"]
		for pair: Array in [[s["low"], s["high"]], [s["high"], s["low"]]]:
			var k := Vector3i(c.x, c.y, int(pair[0]))
			if not links.has(k):
				links[k] = []
			links[k].append(Vector3i(c.x, c.y, int(pair[1])))
	var reach: Dictionary = {}
	var queue: Array[Vector3i] = []
	for c: Vector2i in _d["train_doors"]["lower"]:
		reach[Vector3i(c.x, c.y, 0)] = true
		queue.append(Vector3i(c.x, c.y, 0))
	var head := 0
	while head < queue.size():
		var at := queue[head]
		head += 1
		var next: Array = links.get(at, []).duplicate()
		for step: Vector2i in DIRS:
			next.append(at + Vector3i(step.x, step.y, 0))
		for value in next:
			var n: Vector3i = value
			var g: FieldGrid = _d["levels"].get(n.z)
			if g != null and not reach.has(n) and g.inside(Vector2i(n.x, n.y)) and g.people_can_walk(Vector2i(n.x, n.y)):
				reach[n] = true
				queue.append(n)
	for id: String in _d["containers"]:
		var box: Dictionary = _d["containers"][id]
		var cell: Vector2i = box["cell"]
		var lv := int(box.get("level", 0))
		var near := reach.has(Vector3i(cell.x, cell.y, lv))
		for step: Vector2i in DIRS:
			near = near or reach.has(Vector3i(cell.x + step.x, cell.y + step.y, lv))
		assert_true(near, "%s(%s, %d층)에 못 닿는다" % [id, str(cell), lv])
