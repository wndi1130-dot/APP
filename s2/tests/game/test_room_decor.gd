extends "res://addons/gut/test.gd"

const RoomDecor = preload("res://game/world/room_decor.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const Measure = preload("res://tools/room_decor_measure.gd")
const BuildingView = preload("res://game/world/building_view.gd")
const PropModels = preload("res://game/world/prop_models.gd")

var first: Dictionary
var fourth: Dictionary
var repeated: Dictionary
var before_props: Array
var before_boxes: Dictionary
var before_grids: Dictionary
var before_other: Dictionary
var first_stats: Dictionary
var repeated_stats: Dictionary


func before_all() -> void:
	# 지도는 둘만 짓는다. 장식 전 입력 두 벌의 배열·사전은 깊게 복제하고,
	# 읽기 전용 격자 공유가 변이를 숨기지 않도록 격자 값은 따로 사본을 남긴다.
	first = Measure.prepare("houses_01")
	repeated = first.duplicate(true)
	before_props = first["props"].duplicate(true)
	before_boxes = first["containers"].duplicate(true)
	before_grids = _grids(first)
	before_other = _other(first)
	first_stats = RoomDecor.dress(first)
	repeated_stats = RoomDecor.dress(repeated)
	fourth = Measure.prepare("houses_04")
	RoomDecor.dress(fourth)


func _grids(data: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for lv: int in data.get("levels", {0: data["grid"]}):
		var g: FieldGrid = data.get("levels", {0: data["grid"]})[lv]
		out[lv] = {"solid": g.solid.duplicate(), "doors": g.doors.duplicate(true), "windows": g.windows.duplicate(true),
			"floor": g.floor.duplicate(), "building": g.building.duplicate(), "zone": g.zone.duplicate(),
			"opq": g.opq.duplicate(), "walk_people": g.walk_people.duplicate(), "walk_dead": g.walk_dead.duplicate(),
			"floor_glass": g.floor_glass.duplicate(true), "revision": g.revision}
	return out


func _other(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	for key in ["props", "grid", "levels", "_rooms"]:
		out.erase(key)
	return out


func _decor(data: Dictionary) -> Array:
	var rows: Array = []
	for p: Dictionary in data["props"]:
		if p.get("decor", false):
			rows.append(p)
	return rows


func test_only_decor_rows_are_appended_and_other_map_values_are_unchanged() -> void:
	assert_gt(int(first_stats["rows"]), 0, "장식 줄이 실제로 생긴다")
	assert_eq(first["props"].size(), before_props.size() + int(first_stats["rows"]))
	assert_eq(var_to_str(first["props"].slice(0, before_props.size())), var_to_str(before_props), "원래 props 앞부분")
	assert_eq(var_to_str(first["containers"]), var_to_str(before_boxes), "상자 수·자리·내용·규칙")
	assert_eq(var_to_str(_grids(first)), var_to_str(before_grids), "모든 층 고체·문·창·길 자료")
	assert_eq(var_to_str(_other(first)), var_to_str(before_other), "정차·전리품을 포함한 다른 지도 값")
	var faults: Array = []
	var counted: Dictionary = {}
	for p: Dictionary in first["props"].slice(before_props.size()):
		var r: Rect2i = p["rect"]
		var lv := int(p["level"])
		var g: FieldGrid = first["levels"][lv]
		var is_top: bool = RoomDecor.TOP_KINDS.has(p.get("kind", ""))
		if not p.get("decor", false) or p.get("solid", "") != "none" or (not is_top and not RoomDecor.KINDS.has(p.get("kind", ""))):
			faults.append(p)
		if r.size != Vector2i.ONE or p.has("search") or p.has("container") or p.has("holds"):
			faults.append(p)
		if is_top:
			if p["mount"] != "top" or p.has("tint") or not p["host_rect"].encloses(r):
				faults.append(p)
		else:
			if p["mount"] != ("floor" if p["kind"] == "potted_plant" else "wall"):
				faults.append(p)
			if p.get("tint") != RoomFurnish.tint_for(first["place_id"], g.building_at(r.position)):
				faults.append(p)
		if not String(p["note"]).ends_with("의 " + String(RoomDecor.NAMES[p["kind"]])):
			faults.append(p)
		counted[p["kind"]] = int(counted.get(p["kind"], 0)) + 1
	for kind: String in RoomDecor.KINDS + RoomDecor.TOP_KINDS:
		assert_eq(int(first_stats["kinds"][kind]), int(counted.get(kind, 0)), kind)
	var top_count := 0
	for kind: String in RoomDecor.TOP_KINDS:
		top_count += int(counted.get(kind, 0))
	assert_eq(first_stats["tops_placed"], top_count, "실제 탁상 줄 수")
	assert_gte(int(first_stats["tops_needed"]), top_count)
	assert_eq(faults, [], "추가 줄의 계약")


func test_top_stats_sum_room_budgets_including_unplaced_tops() -> void:
	var needed := 0
	for room: Dictionary in Measure.census(first):
		var lv := int(room["level"])
		var ri := int(room["room"])
		var rooms := RoomFurnish._rooms(first, lv, first["levels"][lv])
		var building := int(rooms["rooms"][ri]["building"])
		var seed_value: int = ("%s|%d|%d|%d|decor" % [first["place_id"], building, lv, ri]).hash() & 0x7fffffff
		var walls: Array = []
		for kind: String in room["kinds"]:
			if RoomDecor.KINDS.has(kind) and kind != "potted_plant":
				walls.append({"kind": kind, "mount": "wall"})
		needed += RoomDecor._top_budget(room["class"], seed_value, walls)
	assert_eq(first_stats["tops_needed"], needed, "놓은 수가 아니라 방마다 필요한 차례의 합")


func test_wall_decor_uses_north_or_west_without_tall_furniture_or_touching_neighbors() -> void:
	var faults: Array = []
	var checked := 0
	for data: Dictionary in [first, fourth]:
		var stairs := RoomFurnish._stairs_by_level(data)
		var hung: Array = []
		for p: Dictionary in _decor(data):
			if p["mount"] != "wall":
				continue
			checked += 1
			var c: Vector2i = p["rect"].position
			var lv := int(p["level"])
			var facing := int(p["facing"])
			if facing not in [0, 3]:
				faults.append(p)
				continue
			var g: FieldGrid = data["levels"][lv]
			var map := RoomFurnish._rooms(data, lv, g)
			var ri := RoomFurnish._at(g, map["of"], c)
			var d := Vector2i(0, -1) if facing == 0 else Vector2i(-1, 0)
			if not RoomFurnish._wall_side(g, map["of"], ri, p["rect"], d) or stairs.get(lv, {}).has(c):
				faults.append(p)
			# 안 벽은 집 안을 볼 때 턱 높이로 낮춰 그려 벽걸이가 뜬다: 등 벽은 그 집 바깥 벽이어야 한다.
			if g.building_at(c + d) != g.building_at(c) or g.building_at(c + d * 2) == g.building_at(c):
				faults.append(["inner wall", p])
			var sink := false
			for f: Dictionary in data["props"]:
				if f.get("decor", false) or int(f.get("level", 0)) != lv:
					continue
				var r: Variant = RoomFurnish._rect(f.get("rect"))
				if r == null or not r.has_point(c):
					continue
				if RoomFurnish.TALL_KINDS.has(f.get("kind", "")):
					faults.append(p)
				sink = sink or f.get("kind", "") == "washstand"
			var cls := String(data["density_classes"].get("%d:%d" % [lv, ri], ""))
			if cls == "bath" and (p["kind"] != "wall_mirror" or not sink):
				faults.append(p)
			for old: Dictionary in hung:
				if int(old["level"]) != lv:
					continue
				var delta: Vector2i = c - old["rect"].position
				var along := Vector2i(1, 0) if facing == 0 else Vector2i(0, 1)
				if delta == Vector2i.ZERO or (old["facing"] == facing and delta in [along, -along]):
					faults.append([p, old])
			hung.append(p)
	assert_gt(checked, 0)
	assert_eq(faults, [], "북·서 바깥 벽, 큰 가구 없음, 같은 벽 한 칸 띄움, 욕실 세면대")


func test_no_wall_decor_hangs_on_a_wall_that_is_lowered_inside() -> void:
	# 집 안을 볼 때 낮춰 그리는 벽(안 벽, 바깥 남·동 벽)에 건 장식은 허공에 뜬다. 그리기 계획(building_view)의
	# 벽 칸 갈래로 세어, 장식 갈래가 늘어도 다시 뜨지 않게 한다.
	var third := Measure.prepare("houses_07")
	RoomDecor.dress(third)
	var checked := 0
	var on_lowered: Array = []
	for data: Dictionary in [first, fourth, third]:
		var kinds: Dictionary = BuildingView.plan(data)["kinds"]
		for p: Dictionary in _decor(data):
			if p["mount"] != "wall":
				continue
			checked += 1
			var c: Vector2i = p["rect"].position
			var lv := int(p["level"])
			var g: FieldGrid = data["levels"][lv]
			var wall: Vector2i = c + RoomDecor.BACKS[int(p["facing"])]
			var kind: Dictionary = kinds.get(Vector2i(g.building_at(c), lv), {}).get(wall, {})
			if kind.is_empty() or kind["kind"] == "int" or BuildingView.cut_line(kind):
				on_lowered.append([data["place_id"], lv, c, p["kind"], kind.get("kind", "?")])
	assert_gt(checked, 0)
	assert_eq(on_lowered, [], "집 안을 볼 때 낮아지는 벽에 건 장식 0")


func test_outer_wall_matches_the_drawn_cut_at_corners() -> void:
	# 지도에 그 자리가 안 나와도 잡히게 작은 격자로: 방 칸 (2,2), 집 칸만 0, 나머지는 집 밖.
	# 북쪽 벽의 북동 끝과 서쪽 벽의 남서 끝은 그리기가 남동 쪽 모서리로 보고 턱 높이로 낮춘다.
	var north := Vector2i(0, -1)
	var west := Vector2i(-1, 0)
	var cases := [
		["곧은 북쪽 바깥 줄", north, [Vector2i(2, 1), Vector2i(1, 1), Vector2i(3, 1), Vector2i(1, 2), Vector2i(3, 2)], true],
		["북쪽 벽의 북동 끝", north, [Vector2i(2, 1), Vector2i(1, 1), Vector2i(1, 2)], false],
		["북쪽 벽의 북서 끝", north, [Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 2)], true],
		["곧은 서쪽 바깥 줄", west, [Vector2i(1, 2), Vector2i(1, 1), Vector2i(1, 3), Vector2i(2, 1), Vector2i(2, 3)], true],
		["서쪽 벽의 남서 끝", west, [Vector2i(1, 2), Vector2i(1, 1), Vector2i(2, 1)], false],
		["안 벽(너머도 같은 집)", north, [Vector2i(2, 1), Vector2i(2, 0), Vector2i(1, 1), Vector2i(3, 1)], false],
	]
	for case: Array in cases:
		var g := FieldGrid.new(5, 5)
		g.building[g.index(Vector2i(2, 2))] = 0
		for cell: Vector2i in case[2]:
			g.building[g.index(cell)] = 0
		assert_eq(RoomDecor._outer_wall(g, Vector2i(2, 2), case[1]), case[3], case[0])


func test_plants_keep_furniture_boxes_doors_stairs_and_holder_fronts_clear() -> void:
	# 깔개 위·용기 아닌 가구 앞은 방에 다른 자리가 없을 때만 쓰는 느슨한 단계라 여기서 막지 않는다.
	var faults: Array = []
	var checked := 0
	for data: Dictionary in [first, fourth]:
		var stairs := RoomFurnish._stairs_by_level(data)
		for p: Dictionary in _decor(data):
			if p["kind"] != "potted_plant":
				continue
			checked += 1
			var c: Vector2i = p["rect"].position
			var lv := int(p["level"])
			var g: FieldGrid = data["levels"][lv]
			var map := RoomFurnish._rooms(data, lv, g)
			var ri := RoomFurnish._at(g, map["of"], c)
			var forbidden := RoomFurnish._forbidden(g, map["of"], ri, map["rooms"][ri]["cells"], stairs.get(lv, {}))
			if forbidden.get(c, "") == "all" or g.solid_at(c) != FieldGrid.Solid.NONE:
				faults.append(p)
			for f: Dictionary in data["props"]:
				if f.get("decor", false) or int(f.get("level", 0)) != lv:
					continue
				var r: Variant = RoomFurnish._rect(f.get("rect"))
				if r == null:
					continue
				var facing := posmod(int(f.get("facing", 0)), 4)
				var front: Rect2i
				match facing:
					0: front = Rect2i(r.position.x, r.end.y, r.size.x, 1)
					1: front = Rect2i(r.position.x - 1, r.position.y, 1, r.size.y)
					2: front = Rect2i(r.position.x, r.position.y - 1, r.size.x, 1)
					3: front = Rect2i(r.end.x, r.position.y, 1, r.size.y)
				if r.has_point(c) or (front.has_point(c) and RoomFurnish.HOLDER_KINDS.has(String(f.get("kind", "")))):
					faults.append(p)
			for box: Dictionary in data["containers"].values():
				if int(box.get("level", 0)) == lv and RoomFurnish._cell(box.get("cell")) == c:
					faults.append(p)
	assert_gt(checked, 0)
	assert_eq(faults, [], "화분은 빈 바닥이고 상자·여는 자리·문 앞·계단을 비운다")


func test_room_kind_medians_and_eligible_bath_mirrors() -> void:
	var rooms := Measure.census(first) + Measure.census(fourth)
	var summary := Measure.summarize(rooms)
	# 회귀 막이 바닥(지금 잰 값 1·1·0). 합격 잣대 침실 1·거실 2·부엌 0은 일곱 장 합산으로
	# test_room_tabletop의 test_seven_house_maps_restore_room_kind_medians가 본다.
	# houses_01 거실 39방이 1 — 다음 차례(선반 위·바닥 장식)에서 2로 올리고 이 단언도 2로.
	var medians := {"bed": 1.0, "living": 1.0, "kitchen": 0.0}
	for cls: String in medians:
		assert_gt(int(summary[cls]["rooms"]), 0, cls)
		assert_eq(float(summary[cls]["median"]), float(medians[cls]), cls)
	assert_gt(int(summary["bath"]["mirror_eligible"]), 0)
	assert_gte(float(summary["bath"]["eligible_mirror_ratio"]), 0.6)
	assert_eq(int(summary["bath"]["unsupported_mirrors"]), 0, "북·서 벽 세면대 없는 욕실의 거울은 0")
	for room: Dictionary in rooms:
		for kind: String in room["kinds"]:
			if RoomDecor.TOP_KINDS.has(kind):
				assert_false(RoomDecor.top_hosts(room["class"], kind).is_empty())
				assert_lte(int(room["kinds"][kind]), 1)
			else:
				assert_true(RoomDecor.PLAN[room["class"]].has(kind))
				assert_lte(int(room["kinds"][kind]), int(RoomDecor.PLAN[room["class"]][kind][1]))


func test_the_same_prepared_map_gives_identical_rows_and_counts() -> void:
	assert_eq(var_to_str(_decor(first)), var_to_str(_decor(repeated)))
	assert_eq(var_to_str(first_stats), var_to_str(repeated_stats))
	assert_eq(var_to_str(repeated["props"].slice(0, before_props.size())), var_to_str(before_props))
	assert_eq(var_to_str(_grids(repeated)), var_to_str(before_grids))


func test_tabletops_preserve_the_legacy_wall_and_plant_rows() -> void:
	# 모형을 끄면 탁상만 불가능하다. 같은 준비 지도로 기존 줄과 셈을 직접 대조한다.
	var legacy := first.duplicate(true)
	legacy["props"] = before_props.duplicate(true)
	var had_setting := ProjectSettings.has_setting(PropModels.MODE_SETTING)
	var setting: Variant = ProjectSettings.get_setting(PropModels.MODE_SETTING, true)
	ProjectSettings.set_setting(PropModels.MODE_SETTING, false)
	var stats := RoomDecor.dress(legacy)
	ProjectSettings.set_setting(PropModels.MODE_SETTING, setting if had_setting else null)
	var rows: Array = []
	var top_count := 0
	for row: Dictionary in _decor(first):
		if row["mount"] == "top":
			top_count += 1
		else:
			rows.append(row)
	assert_gt(top_count, 0, "탁상 보충도 실제로 있는 입력")
	assert_eq(var_to_str(rows), var_to_str(_decor(legacy)), "기존 줄의 값과 차례")
	assert_eq(stats["rows"], first_stats["rows"] - top_count)
	assert_eq(first_stats["tops_placed"], top_count)
	assert_eq(stats["tops_needed"], first_stats["tops_needed"], "모형을 꺼 전부 못 놓아도 필요 수는 유지")
	assert_eq(stats["tops_placed"], 0)
	assert_eq(var_to_str(stats["rooms"]), var_to_str(first_stats["rooms"]))
	for kind: String in RoomDecor.KINDS:
		assert_eq(stats["kinds"][kind], first_stats["kinds"][kind], kind)
	for kind: String in RoomDecor.TOP_KINDS:
		assert_eq(stats["kinds"][kind], 0, kind)
	assert_eq(var_to_str(_grids(legacy)), var_to_str(before_grids))


func test_wall_hangings_sit_on_the_inner_wall_face() -> void:
	# 벽걸이 그리기(map_view): facing만큼 돌리고 줄이지 않으며, 모형 등이 벽 안쪽 면 앞 WALL_GAP에 닿는다.
	var MapView = load("res://game/world/map_view.gd")
	var box := AABB(Vector3(-0.3, 1.2, -0.02), Vector3(0.6, 0.8, 0.04))
	var at := Vector3(5.5, 0.0, 7.5)
	var outer: float = MapView.wall_face(null, Vector2i(5, 6), Vector2i(0, -1), 3)
	var north: Transform3D = MapView.wall_mount_transform(box, at, 0, outer)
	assert_almost_eq(north.origin.z - 0.02, at.z - (outer - MapView.WALL_GAP), 0.0001, "북쪽 벽: 등이 벽면 앞에")
	assert_almost_eq(north.origin.x, at.x, 0.0001)
	assert_almost_eq(north.basis.get_scale().x, 1.0, 0.0001, "벽걸이는 줄이지 않는다")
	var west: Transform3D = MapView.wall_mount_transform(box, at, 3, outer)
	assert_almost_eq(west.origin.x - 0.02, at.x - (outer - MapView.WALL_GAP), 0.0001, "서쪽 벽: 등이 벽면 앞에")
	assert_almost_eq(west.origin.z, at.z, 0.0001)
	assert_almost_eq(outer, 0.775, 0.0001, "바깥벽 안쪽 면")
	var g := FieldGrid.new(8, 8)
	var bld := PackedInt32Array()
	bld.resize(64)
	bld.fill(2)
	g.building = bld
	assert_almost_eq(MapView.wall_face(g, Vector2i(3, 3), Vector2i(0, -1), 2), 0.9, 0.0001, "벽 너머도 같은 건물이면 안벽")
	bld[2 * 8 + 3] = -1
	g.building = bld
	assert_almost_eq(MapView.wall_face(g, Vector2i(3, 3), Vector2i(0, -1), 2), 0.775, 0.0001, "벽 너머가 밖이면 바깥벽")


func test_plants_widen_one_step_at_a_time() -> void:
	# 작은 고정 방(벽 안 5×5): 빈 바닥이 있으면 빈 바닥, 다 깔개면 깔개 위, 다 가구 앞이면 그 앞,
	# 상자·여는 자리만 남으면 아무 단계에서도 안 선다.
	var g := FieldGrid.new(7, 7)
	var bld := PackedInt32Array()
	bld.resize(49)
	bld.fill(0)
	g.building = bld
	for y in range(7):
		for x in range(7):
			if x == 0 or y == 0 or x == 6 or y == 6:
				g.set_solid(Vector2i(x, y), FieldGrid.Solid.WALL)
	var map := RoomFurnish.rooms_of(g)
	var of: PackedInt32Array = map["of"]
	var ri := RoomFurnish._at(g, of, Vector2i(3, 3))
	var cells: Array[Vector2i] = map["rooms"][ri]["cells"]
	assert_eq(cells.size(), 25)
	var only_rug := {Vector2i(1, 1): RoomDecor.AVOID_RUG}
	var free_pick := RoomDecor._plant(g, of, ri, cells, {}, only_rug, {}, 7, 0)
	assert_false(free_pick.is_empty())
	assert_ne(free_pick["cell"], Vector2i(1, 1), "빈 바닥이 있으면 깔개 칸을 안 고른다")
	for why: int in [RoomDecor.AVOID_RUG, RoomDecor.AVOID_FRONT, RoomDecor.AVOID_HOLDER_FRONT, RoomDecor.AVOID_TAKEN]:
		var all: Dictionary = {}
		for c in cells:
			all[c] = why
		var opened := -1
		for step in range(RoomDecor.PLANT_STEPS):
			if not RoomDecor._plant(g, of, ri, cells, {}, all, {}, 7, step).is_empty():
				opened = step
				break
		var want: int = {RoomDecor.AVOID_RUG: 1, RoomDecor.AVOID_FRONT: 2, RoomDecor.AVOID_HOLDER_FRONT: -1, RoomDecor.AVOID_TAKEN: -1}[why]
		assert_eq(opened, want, "까닭 %d은 단계 %d에서 처음 열림" % [why, want])
