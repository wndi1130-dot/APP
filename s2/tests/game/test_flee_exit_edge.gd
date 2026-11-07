extends GutTest

const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const Ring = preload("res://game/world/map_ring.gd")
const StopGround = preload("res://game/world/stop_ground.gd")
# 지도 6종. test_map_ring.gd처럼 비싼 생성 결과를 읽기 전용으로 공유한다.
# lodge_01.build와 mine_01.build는 anchors를 넣지 않아 FieldMaps가 출구를 계산한다.
# 도시형은 모두 직접 지정하므로 사용자 확인에 따라 자동 계산은 야외형 2곳이다.
const COMPUTED: Array[String] = ["lodge_01", "mine_01"]
# church_01._build_plain은 모서리, factory_01._build_south는 남쪽 출구를 지정한다.
const OWN: Array[String] = ["church_01", "factory_01"]
# houses_01._build_south는 PLAN.entries의 첫 입구를 출구로 지정한다.
const SHARED_ENTRY: String = "houses_01"
static var _built: Dictionary = {}


func after_all() -> void:
	_built.clear()


func _raw(place: String) -> Dictionary:
	var key: String = "raw:" + place
	if not _built.has(key):
		var script: Script = load(FieldMaps.path_of(place))
		_built[key] = script.build()
	return _built[key]


func _map(place: String) -> Dictionary:
	var key: String = "map:" + place
	if not _built.has(key):
		_built[key] = FieldMaps.build(place)
	return _built[key]


# 습격자 쪽 후속 검사에서도 사용할 판정. 입력 지도의 최종 크기만 읽으며
# 옛 지도 크기, 띠 폭, 특정 출구 좌표 또는 출구를 고치는 함수에 기대지 않는다.
static func flee_exit_on_final_edge(data: Dictionary) -> bool:
	var g: FieldGrid = data.get("grid")
	var cell: Variant = data.get("anchors", {}).get("flee_exit")
	return (g != null and cell is Vector2i and g.inside(cell)
		and (cell.x == 0 or cell.x == g.width - 1
			or cell.y == 0 or cell.y == g.height - 1))


func _label(place: String, data: Dictionary) -> String:
	var g: FieldGrid = data.get("grid")
	var size_text: String = "%dx%d" % [g.width, g.height] if g != null else "없음"
	return "%s flee_exit=%s size=%s" % [place, data.get("anchors", {}).get("flee_exit"), size_text]


func _assert_exit(place: String, data: Dictionary) -> void:
	var label: String = _label(place, data)
	var g: FieldGrid = data.get("grid")
	var cell: Variant = data.get("anchors", {}).get("flee_exit")
	assert_not_null(g, label + ": 최종 격자가 있어야 함")
	assert_true(cell is Vector2i, label + ": 출구 좌표가 있어야 함")
	if g == null or not cell is Vector2i:
		return
	assert_true(flee_exit_on_final_edge(data), label + ": 최종 격자 바깥 줄이어야 함")
	assert_true(g.people_can_walk(cell), label + ": 사람이 걸을 수 있어야 함")


func _assert_ringed(place: String, owns_exit: bool, town: bool) -> void:
	var raw: Dictionary = _raw(place)
	var data: Dictionary = _map(place)
	var label: String = _label(place, data)
	var script: Script = load(FieldMaps.path_of(place))
	assert_true(Ring.enabled(script), label + ": 띠를 붙이는 지도여야 함")
	assert_eq(raw.get("anchors", {}).has("flee_exit"), owns_exit, label + ": 원본 출구 지정 여부")
	var kinds: Array[String] = Ring.TOWN if town else Ring.WILD
	assert_true(kinds.has(String(raw.get("place_kind", ""))), label + ": 도시형/야외형 분류")
	var old: FieldGrid = raw["grid"]
	var g: FieldGrid = data["grid"]
	assert_gt(g.width, old.width, label + ": 띠로 가로가 실제 넓어져야 함")
	assert_gt(g.height, old.height, label + ": 띠로 세로가 실제 넓어져야 함")
	_assert_exit(place, data)


func test_computed_wild_exits_reach_final_edge() -> void:
	for place: String in COMPUTED:
		_assert_ringed(place, false, false)


func test_own_town_exits_reach_final_edge_including_original_corner() -> void:
	for place: String in OWN:
		_assert_ringed(place, true, true)
	# church_01의 직접 지정 모서리를 원본 build 결과로 확인한다.
	var raw: Dictionary = _raw(OWN[0])
	var g: FieldGrid = raw["grid"]
	var cell: Vector2i = raw["anchors"]["flee_exit"]
	assert_true((cell.x == 0 or cell.x == g.width - 1)
		and (cell.y == 0 or cell.y == g.height - 1), _label(OWN[0], raw) + ": 원본 모서리 사례")


func test_exit_shared_with_moved_ground_entry_keeps_working() -> void:
	_assert_ringed(SHARED_ENTRY, true, true)
	var raw: Dictionary = _raw(SHARED_ENTRY)
	var data: Dictionary = _map(SHARED_ENTRY)
	var label: String = _label(SHARED_ENTRY, data)
	var exit_cell: Vector2i = raw["anchors"]["flee_exit"]
	assert_true(flee_exit_on_final_edge(raw), _label(SHARED_ENTRY, raw) + ": 원본 경계 입구")
	var matches: int = 0
	for id in raw.get("entries", {}):
		if raw.get("manholes", {}).has(id) or int(raw.get("entry_levels", {}).get(id, 0)) != 0:
			continue
		var before: Array = raw["entries"][id]
		for index in range(before.size()):
			if before[index] != exit_cell:
				continue
			matches += 1
			var after: Array = data.get("entries", {}).get(id, [])
			assert_gt(after.size(), index, label + ": 같은 입구 %s가 남아야 함" % id)
			if index >= after.size():
				continue
			assert_eq(data["anchors"]["flee_exit"], after[index], label + ": 이동한 입구 %s와 같은 출구" % id)
	assert_gt(matches, 0, label + ": 출구와 겹치는 지상 입구 사례가 있어야 함")


func test_unringed_default_keeps_original_exit_and_size() -> void:
	# BUILT_IN의 sulehuf_map.gd는 MAP_DIR 밖이므로 Ring.enabled가 거짓이다.
	# 원본 build가 직접 정한 출구를 읽으며 좌표를 시험에 복사하지 않는다.
	var place: String = FieldMaps.DEFAULT_PLACE
	var raw: Dictionary = _raw(place)
	var data: Dictionary = _map(place)
	var label: String = _label(place, data)
	var script: Script = load(FieldMaps.path_of(place))
	assert_false(Ring.enabled(script), label + ": 띠 없는 지도여야 함")
	assert_true(raw.get("anchors", {}).has("flee_exit"), _label(place, raw) + ": 원본이 출구를 지정함")
	assert_eq(data["anchors"]["flee_exit"], raw["anchors"]["flee_exit"], label + ": 원래 출구 보존")
	var old: FieldGrid = raw["grid"]
	var g: FieldGrid = data["grid"]
	assert_eq(Vector2i(g.width, g.height), Vector2i(old.width, old.height), label + ": 크기 보존")
	_assert_exit(place, raw)
	_assert_exit(place, data)


func test_two_fresh_builds_choose_the_same_exit() -> void:
	var place: String = COMPUTED[0]
	var first: Dictionary = _map(place)
	var first_exit: Variant = first.get("anchors", {}).get("flee_exit")
	var first_label: String = _label(place, first)
	# 두 번째는 공유 캐시를 쓰지 않고 실제 FieldMaps.build를 다시 부른다.
	var second: Dictionary = FieldMaps.build(place)
	var second_exit: Variant = second.get("anchors", {}).get("flee_exit")
	assert_true(first_exit is Vector2i, first_label + ": 첫 출구 존재")
	assert_true(second_exit is Vector2i, _label(place, second) + ": 둘째 출구 존재")
	assert_eq(second_exit, first_exit, "%s / 첫 생성 %s: 반복 생성 출구 일치" % [_label(place, second), first_label])


func test_edge_stop_exit_reaches_the_last_grid_edge() -> void:
	var place: String = OWN[0]
	# 정차 형태 적용이 공유 캐시를 건드리지 않도록 새 지도를 넘긴다.
	var ringed: Dictionary = FieldMaps.build(place)
	var old: FieldGrid = ringed["grid"]
	# test_stop_ground.gd의 _edge와 같은 형태, 씨앗, 목표 거리.
	var data: Dictionary = StopGround.apply(ringed, "edge", 71, 200.0)
	var label: String = _label(place + " edge", data)
	var g: FieldGrid = data["grid"]
	assert_eq(data.get("stop_form", ""), "edge", label + ": edge 적용이 실제 이루어져야 함")
	assert_gt(g.width, old.width, label + ": 끝 정차로 가로가 더 넓어져야 함")
	_assert_exit(place + " edge", data)


func test_edge_predicate_includes_corners_and_excludes_outside_cells() -> void:
	var g: FieldGrid = FieldGrid.new(5, 4)
	var data: Dictionary = {"grid": g, "anchors": {}}
	var xmax: int = g.width - 1
	var ymax: int = g.height - 1
	for cell: Vector2i in [Vector2i.ZERO, Vector2i(xmax, 0), Vector2i(0, ymax), Vector2i(xmax, ymax),
		Vector2i(1, 0), Vector2i(0, 1), Vector2i(xmax, 1), Vector2i(1, ymax)]:
		data["anchors"]["flee_exit"] = cell
		assert_true(flee_exit_on_final_edge(data), _label("경계 판정", data))
	for cell: Vector2i in [Vector2i(1, 1), Vector2i(-1, 0), Vector2i(0, -1),
		Vector2i(g.width, ymax), Vector2i(xmax, g.height)]:
		data["anchors"]["flee_exit"] = cell
		assert_false(flee_exit_on_final_edge(data), _label("경계 밖/안쪽 판정", data))
	data["anchors"].erase("flee_exit")
	assert_false(flee_exit_on_final_edge(data), _label("출구 누락 판정", data))
