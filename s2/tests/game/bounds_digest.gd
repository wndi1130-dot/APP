extends RefCounted
## 경계 도입 전후의 정차 자료 지문. make_ready()가 끝난 자료를 받는다.
## 판 0에서 추가될 bounds/bounds_stamp 등의 계약 키는 지형 지문에 넣지 않는다.
## 사전 순서는 정규화하고 배열 순서와 좌표 자료형은 보존한다.

const FieldGrid = preload("res://game/world/field_grid.gd")
const EdgeBand = preload("res://game/world/edge_band.gd")
const VERSION: int = 1
const GRID_ARRAYS: Array[String] = [
	"solid", "floor", "building", "zone", "opq", "walk_people", "walk_dead",
]
const MAP_KEYS: Array[String] = [
	"place_id", "place_kind", "region_band", "entries", "entry_levels", "bands", "spots",
	"anchors", "spawns", "train", "train_cars", "train_doors", "platform", "unload",
	"boarding", "unloading", "containers", "props", "trees", "low_blocks", "deep_forest",
	"map_ring", "side_path", "stairs", "buildings", "upper_rects", "crossings",
	"barricade_slots", "interior_kind_slots", "slow_rects", "manholes", "manhole_levels",
	"hole_faces", "sewer_names", "zone_names", "labels", "lights", "wagons", "stoves",
	"cellar_windows", "fell_groves", "work_sites", "village_middle", "walk_to_village_m",
	"stop_form", "stop_form_asked", "stop_old_ground", "stop_end_gap",
	"stop_view_rows", "stop_view_cols", "stop_view_rule", "_side_seed",
]


## 항목 이름 -> SHA-256 앞 128비트(32자리). 다른 항목을 바로 보고할 수 있다.
static func digest(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var ground: FieldGrid = data["grid"]
	var levels: Dictionary = data.get("levels", {})
	_grid_digest(result, "grid", ground)
	result["levels"] = _hash(_level_ids(levels))
	for level_id: Variant in levels:
		_grid_digest(result, "level/%s" % str(level_id), levels[level_id] as FieldGrid)
	for key: String in MAP_KEYS:
		# 없는 값과 실제 null도 구별한다. OPTIONAL에 새로 들어올 bounds는 제외한다.
		var value: Variant = data.get(key)
		if key == "map_ring" and value is Dictionary:
			value = value.duplicate()
			var width: int = int(value.get("width", -1))
			# 기존 width와 중복되는 기록만 생략하여 판 1 기준 지문을 보존한다.
			if value.get("sides", []) == [width, width, width, width]:
				value.erase("sides")
		result["map/" + key] = _hash([data.has(key), value])
	var ahead: Dictionary = data["_edge_plan"]
	var plan: Dictionary = ahead["plan"]
	var forest: Array = data.get("deep_forest", [])
	result["edge/openings"] = _hash(EdgeBand.openings(ground))
	result["edge/plan_key"] = _hash(EdgeBand.plan_key(
		ground, EdgeBand.seed_of(data), EdgeBand.look_of(data), forest))
	result["edge/stored_key"] = _hash(ahead["key"])
	# trees에는 좌표뿐 아니라 크기, 수종, skip 등이 포함된다. 순서도 보존한다.
	for key: String in plan:
		result["edge/plan/" + key] = _hash(plan[key])
	var planned_trees: Array = plan["trees"]
	result["edge/tree_count"] = _hash(planned_trees.size())
	# 화면을 만들 때 쓰는 벌목지까지 확인한다. 작업 거리 캐시는 사본에만 쓴다.
	result["edge/fell_groves"] = _hash(EdgeBand.fell_groves(ground, plan, data.duplicate()))
	return result


static func _level_ids(levels: Dictionary) -> Array:
	var ids: Array = levels.keys()
	ids.sort()
	return ids


static func _grid_digest(result: Dictionary, prefix: String, grid: FieldGrid) -> void:
	result[prefix + "/size"] = _hash(Vector2i(grid.width, grid.height))
	for key: String in GRID_ARRAYS:
		result[prefix + "/" + key] = _hash(grid.get(key))
	result[prefix + "/doors"] = _hash(grid.doors)
	result[prefix + "/windows"] = _hash(grid.windows)
	result[prefix + "/floor_glass"] = _hash(grid.floor_glass)
	result[prefix + "/people_path"] = _path_hash(grid.people_path)
	result[prefix + "/dead_path"] = _path_hash(grid.dead_path)


## 캐시 배열에서 추정하지 않고 실제 두 AStar의 모든 점을 읽는다.
static func _path_hash(path: AStarGrid2D) -> String:
	var region: Rect2i = path.region
	var blocked: PackedByteArray = PackedByteArray()
	blocked.resize(region.size.x * region.size.y)
	var at: int = 0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			blocked[at] = int(path.is_point_solid(Vector2i(x, y)))
			at += 1
	return _hash([region, blocked])


static func _hash(value: Variant) -> String:
	var context: HashingContext = HashingContext.new()
	var started: Error = context.start(HashingContext.HASH_SHA256)
	assert(started == OK)
	var updated: Error = context.update(var_to_bytes(_canonical(value)))
	assert(updated == OK)
	return context.finish().hex_encode().substr(0, 32)


## JSON은 Vector2i 사전 키와 실수 정밀도를 잃으므로 바이너리 Variant를 쓴다.
## Object ID, 경과 시간, _walk_key 같은 실행마다 달라지는 값은 입력에 넣지 않는다.
static func _canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var source: Dictionary = value
		var ordered: Dictionary = {}
		var tokens: Array[String] = []
		for key: Variant in source:
			var token: String = var_to_bytes(_canonical(key)).hex_encode()
			tokens.append(token)
			ordered[token] = _canonical(source[key])
		tokens.sort()
		var pairs: Array = []
		for token: String in tokens:
			pairs.append([token, ordered[token]])
		return [TYPE_DICTIONARY, pairs]
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(_canonical(item))
		return [TYPE_ARRAY, items]
	assert(typeof(value) not in [TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID],
		"지문에는 객체나 실행 핸들을 넣을 수 없습니다")
	return [typeof(value), value]
