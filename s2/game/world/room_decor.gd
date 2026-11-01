extends RefCounted
## 참고 사본 방 꾸밈 표(10-30). 가구 배치 뒤, 충돌과 상자를 건드리지 않는 장식 층.

const RoomFurnish = preload("res://game/world/room_furnish.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const BuildingView = preload("res://game/world/building_view.gd")
const PropKinds = preload("res://game/world/prop_kinds.gd")
const PropModels = preload("res://game/world/prop_models.gd")
const PropFit = preload("res://game/world/prop_fit.gd")
const KINDS: Array[String] = ["wall_picture", "wall_mirror", "wall_poster", "wall_clock", "potted_plant"]
const TOP_KINDS: Array[String] = PropModels.TABLETOP_KINDS
const NAMES: Dictionary = {"wall_picture": "벽 그림", "wall_mirror": "거울", "wall_poster": "포스터",
	"wall_clock": "벽시계", "potted_plant": "화분", "alarm_clock": "탁상시계", "vase": "꽃병",
	"mug": "머그", "teapot": "찻주전자", "kettle": "주전자", "kettle_enamel": "법랑 주전자",
	"cutting_board": "도마", "serving_bowl": "사발", "dinner_plate": "접시"}
# 쓰임 번호는 배치 차례와 독립이다. 종류를 추가해도 기존 굴림이 바뀌지 않는다.
const PURPOSE: Dictionary = {"wall_picture": 0, "potted_plant": 1, "wall_mirror": 2, "wall_poster": 3, "wall_clock": 4}
const PLAN: Dictionary = {
	"bed": {"wall_picture": [0.49, 1], "potted_plant": [0.28, 1], "wall_mirror": [0.14, 1], "wall_poster": [0.08, 2], "wall_clock": [0.01, 1]},
	"living": {"wall_picture": [0.66, 2], "potted_plant": [0.53, 1], "wall_mirror": [0.32, 1], "wall_poster": [0.02, 1], "wall_clock": [0.14, 1]},
	"kitchen": {"wall_picture": [0.09, 1], "potted_plant": [0.23, 1], "wall_clock": [0.22, 1]},
	# 욕실 거울 0.80은 참고 표 밖의 새 값이며, 북·서 벽 세면대 위에만 둔다.
	"bath": {"wall_mirror": [0.80, 1]},
}
const TOP_PLAN: Dictionary = {
	"bed": ["alarm_clock", "vase", "mug"],
	"living": ["vase", "teapot", "serving_bowl", "mug"],
	"kitchen": ["kettle", "cutting_board", "dinner_plate", "serving_bowl"],
}
const TOP_HOSTS: Dictionary = {
	"bed": {"alarm_clock": ["nightstand", "dresser"], "vase": ["dresser", "nightstand"],
		"mug": ["nightstand", "dresser"]},
	"living": {"vase": ["side_table", "low_table", "radio_set"], "teapot": ["low_table", "side_table"],
		"serving_bowl": ["low_table", "side_table"], "mug": ["side_table", "low_table"]},
	"kitchen": {"kettle": ["cold_stove", "counter"], "kettle_enamel": ["cold_stove", "counter"],
		"cutting_board": ["counter"], "dinner_plate": ["counter"], "serving_bowl": ["counter"]},
}
const TOP_PURPOSE := 5
const KETTLE_PURPOSE := 6
const TOP_CELL_PURPOSE := 7
const BACKS: Dictionary = {0: Vector2i(0, -1), 3: Vector2i(-1, 0)}
const FRONTS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0)]
const BED_BACKS: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1)]
# 화분이 피할 칸의 까닭(센 쪽이 남는다). 자리가 없으면 한 단계씩 느슨하게: 먼저 깔개 위, 그다음 용기 아닌
# 가구 앞. 상자 칸·용기 가구 앞(여는 자리)은 늘 피한다.
const AVOID_RUG := 1
const AVOID_FRONT := 2
const AVOID_HOLDER_FRONT := 3
const AVOID_TAKEN := 4
const PLANT_STEPS := 3

static var _drawn_models: Dictionary = {} # enabled + kind -> 첫 유효 모형(없음도 저장)


static func dress(data: Dictionary) -> Dictionary:
	var stats := {"rooms": {}, "kinds": {}, "rows": 0, "tops_needed": 0, "tops_placed": 0}
	for cls: String in PLAN:
		stats["rooms"][cls] = 0
	for kind: String in KINDS:
		stats["kinds"][kind] = 0
	for kind: String in TOP_KINDS:
		stats["kinds"][kind] = 0
	var props: Array = data.get("props", [])
	var place := String(data.get("place_id", ""))
	var levels: Dictionary = data.get("levels", {0: data["grid"]})
	var stairs_by := RoomFurnish._stairs_by_level(data)
	var building_names: Dictionary = {}
	for b: Dictionary in data.get("buildings", []):
		building_names[int(b.get("id", -1))] = String(b.get("name", ""))
	var lvs: Array = levels.keys()
	lvs.sort()
	for lv: int in lvs:
		var g: FieldGrid = levels[lv]
		var map := RoomFurnish._rooms(data, lv, g)
		var of: PackedInt32Array = map["of"]
		var in_room := RoomFurnish._props_by_room(g, of, props, lv)
		var labels := RoomFurnish._room_labels(data, lv, g, of)
		var cover := _coverage(props, lv)
		var avoid := _floor_avoid(data, props, lv)
		var stairs: Dictionary = stairs_by.get(lv, {})
		for ri in range(map["rooms"].size()):
			var cls := String(data.get("density_classes", {}).get("%d:%d" % [lv, ri], ""))
			var room: Dictionary = map["rooms"][ri]
			var cells: Array[Vector2i] = room["cells"]
			if not PLAN.has(cls) or (cls != "bath" and cells.size() < RoomFurnish.ROOM_MIN_CELLS):
				continue
			stats["rooms"][cls] += 1
			var building := int(room["building"])
			var seed_value: int = ("%s|%d|%d|%d|decor" % [place, building, lv, ri]).hash() & 0x7fffffff
			var name := RoomFurnish._note_name(props, in_room.get(ri, []))
			if name.is_empty():
				name = String(labels.get(ri, building_names.get(building, "")))
			var walls := _walls(g, of, ri, cells, cover, stairs)
			var forbidden := RoomFurnish._forbidden(g, of, ri, cells, stairs)
			var hung: Array = []
			var decor_start := props.size()
			for kind: String in KINDS:
				if not PLAN[cls].has(kind):
					continue
				var rule: Array = PLAN[cls][kind]
				var roll := int(rand_from_seed(hash([seed_value, PURPOSE[kind]]))[0])
				if float(roll % 1000) / 1000.0 >= float(rule[0]):
					continue
				for _copy in range(int(rule[1])):
					var chosen: Dictionary
					if kind == "potted_plant":
						for step in range(PLANT_STEPS):
							chosen = _plant(g, of, ri, cells, cover, avoid, forbidden, seed_value, step)
							if not chosen.is_empty():
								break
					else:
						chosen = _hanging(kind, cls, walls, cover, hung, seed_value)
					if chosen.is_empty():
						break
					props.append({"kind": kind, "rect": Rect2i(chosen["cell"], Vector2i.ONE), "solid": "none",
						"mount": "floor" if kind == "potted_plant" else "wall", "facing": chosen["facing"],
						"level": lv, "note": "%s의 %s" % [name, NAMES[kind]], "decor": true,
						"tint": RoomFurnish.tint_for(place, building)})
					if kind == "potted_plant":
						avoid[chosen["cell"]] = AVOID_TAKEN
					else:
						hung.append(chosen)
					stats["kinds"][kind] += 1
					stats["rows"] += 1
			var budget := _top_budget(cls, seed_value, props.slice(decor_start))
			stats["tops_needed"] += budget
			for row: Dictionary in _tabletops(props, in_room.get(ri, []), lv, cls, seed_value, name, budget, g):
				# 벽걸이·화분 줄처럼 그 집 가구의 칠 판을 단다(map_view의 FurnitureTints.pick은 tint를 먼저 읽는다).
				row["tint"] = RoomFurnish.tint_for(place, building)
				props.append(row)
				stats["kinds"][row["kind"]] += 1
				stats["rows"] += 1
				stats["tops_placed"] += 1
	data["props"] = props
	return stats


## 그리기와 받침 검사가 같은 첫 유효 모형을 쓴다. 윗면 없는 대체도 그대로 고른다.
static func drawn_model(kind: String) -> String:
	var models_enabled := PropModels.enabled()
	var key := "%s:%s" % [models_enabled, kind]
	if _drawn_models.has(key):
		# 고른 모형의 메시가 그 뒤 비었으면(모형 캐시를 바꿔 끼운 경우) 처음부터 다시 고른다.
		var cached: String = _drawn_models[key]
		if cached.is_empty() or not PropModels.batch_meshes(cached).is_empty():
			return cached
	var chosen := ""
	if models_enabled:
		for path in PropKinds.candidates(kind):
			if ResourceLoader.exists(path) and not PropModels.batch_meshes(path).is_empty():
				chosen = path
				break
	_drawn_models[key] = chosen
	return chosen


## 모형 캐시를 바꿔 끼운 뒤(시험) 고른 모형 기억을 비운다.
static func forget_models() -> void:
	_drawn_models.clear()


## 메시의 AABB와 윗면 표는 저장된 값이라 따로 기억하지 않는다(바꿔 끼운 메시도 그대로 따른다).
static func _model_box(path: String) -> AABB:
	return PropModels.batch_meshes(path)[0].get_aabb()


static func _tops(path: String) -> Array:
	return PropModels.tops(path)


## 기존 굴림은 다시 읽기만 한다. 복사본이 하나라도 걸렸으면 그 종류는 보충하지 않는다.
static func _top_budget(cls: String, seed_value: int, rows: Array) -> int:
	if not TOP_PLAN.has(cls):
		return 0
	var hung: Dictionary = {}
	for row: Dictionary in rows:
		if row.get("mount", "") == "wall":
			hung[String(row["kind"])] = true
	var count := 0
	for kind: String in KINDS:
		if kind == "potted_plant" or not PLAN[cls].has(kind):
			continue
		var roll := int(rand_from_seed(hash([seed_value, PURPOSE[kind]]))[0])
		if float(roll % 1000) / 1000.0 < float(PLAN[cls][kind][0]) and not hung.has(kind):
			count += 1
	return count


static func _top_order(cls: String, seed_value: int) -> Array[String]:
	var out: Array[String] = []
	if not TOP_PLAN.has(cls):
		return out
	var plan: Array = TOP_PLAN[cls].duplicate()
	if cls == "kitchen":
		var kettle_roll := int(rand_from_seed(hash([seed_value, KETTLE_PURPOSE]))[0])
		plan[0] = "kettle" if kettle_roll % 2 == 0 else "kettle_enamel"
	var roll := int(rand_from_seed(hash([seed_value, TOP_PURPOSE]))[0])
	for i in range(plan.size()):
		out.append(plan[(i + roll % plan.size()) % plan.size()])
	return out


static func top_hosts(cls: String, kind: String) -> Array:
	return TOP_HOSTS.get(cls, {}).get(kind, [])


## 탁상은 줄이지 않는다. 받침이 줄어든 축의 여백도 모형 좌표에서 미리 뺀다.
static func _top_fits(box: AABB, rect: Rect2, scale: Vector2 = Vector2.ONE) -> bool:
	var at := rect.get_center()
	var lo := at + Vector2(box.position.x, box.position.z) / scale
	var hi := at + Vector2(box.end.x, box.end.z) / scale
	return lo.x >= rect.position.x and lo.y >= rect.position.y and hi.x <= rect.end.x and hi.y <= rect.end.y


## 2칸 받침은 윗면의 긴 축을 반으로 나눈다. 실제 크기로 절반에 못 들어가면 가운데를 유지한다.
static func _top_at(box: AABB, surface: Rect2, scale: Vector2, host_rect: Rect2i, seed_value: int) -> Vector2:
	if host_rect.get_area() != 2:
		return surface.get_center()
	var half := surface
	var along_x := surface.size.x >= surface.size.y
	if along_x:
		half.size.x *= 0.5
	else:
		half.size.y *= 0.5
	if not _top_fits(box, half, scale):
		return surface.get_center()
	var roll := int(rand_from_seed(hash([seed_value, TOP_CELL_PURPOSE]))[0])
	if roll % 2 != 0:
		if along_x:
			half.position.x += half.size.x
		else:
			half.position.y += half.size.y
	return half.get_center()


## 방의 받침 줄마다 한 번만 모형·맞춤·윗면 순서를 구한다. 종류별 배열 안의 가구 줄 순서는 그대로다.
static func _top_candidates(props: Array, idxs: Array, lv: int, cls: String, grid: FieldGrid) -> Dictionary:
	var hosts: Dictionary = {}
	for kinds: Array in TOP_HOSTS.get(cls, {}).values():
		for host_kind: String in kinds:
			hosts[host_kind] = []
	for i: int in idxs:
		var host: Dictionary = props[i]
		var on := String(host.get("kind", ""))
		if host.get("decor", false) or int(host.get("level", 0)) != lv or not hosts.has(on):
			continue
		var r: Variant = RoomFurnish._rect(host.get("rect"))
		if r == null:
			continue
		var path := drawn_model(on)
		var tops := _tops(path)
		if tops.is_empty():
			continue
		var box := _model_box(path)
		var facing := int(host.get("facing", 0))
		var fit := PropFit.fit(box.position, box.end, r, facing, grid)
		var basis := Basis.from_scale(fit["scale"]) * Basis(Vector3.UP, -float(fit["facing"]) * PI * 0.5)
		var scale := Vector2(basis.x.length(), basis.z.length())
		var spots: Array = range(tops.size())
		if on == "cold_stove":
			spots.sort_custom(func(a: int, b: int) -> bool:
				return tops[a]["y"] > tops[b]["y"] if tops[a]["y"] != tops[b]["y"] else a < b)
		var surfaces: Array = []
		for spot: int in spots:
			surfaces.append({"spot": spot, "rect": tops[spot]["rect"], "slot": "%d:%s:%s:%d" % [lv, r, on, spot]})
		hosts[on].append({"rect": r, "facing": facing, "scale": scale, "surfaces": surfaces})
	return hosts


static func _tabletops(props: Array, idxs: Array, lv: int, cls: String, seed_value: int,
		name: String, limit: int, grid: FieldGrid = null) -> Array:
	if limit <= 0 or not PropModels.enabled():
		return []
	var hosts := _top_candidates(props, idxs, lv, cls, grid)
	var options: Array = []
	for kind: String in _top_order(cls, seed_value):
		var choices: Array = []
		var path := drawn_model(kind)
		if path.is_empty():
			options.append(choices)
			continue
		var box := _model_box(path)
		for on: String in top_hosts(cls, kind):
			for host: Dictionary in hosts.get(on, []):
				var r: Rect2i = host["rect"]
				var scale: Vector2 = host["scale"]
				for top: Dictionary in host["surfaces"]:
					var surface: Rect2 = top["rect"]
					if not _top_fits(box, surface, scale):
						continue
					var row := {"kind": kind, "rect": Rect2i(r.position, Vector2i.ONE), "solid": "none",
						"mount": "top", "on": on, "host_rect": r, "spot": top["spot"], "at": _top_at(box, surface, scale, r, seed_value),
						"facing": host["facing"], "level": lv, "note": "%s의 %s" % [name, NAMES[kind]], "decor": true}
					choices.append({"slot": top["slot"],
						"order": options.size(), "choice": choices.size(), "row": row})
		options.append(choices)
	var out: Array = []
	for picked: Dictionary in _match_tops(options, limit):
		out.append(picked["row"])
	return out


## 수를 먼저 최대화하고, 같은 수면 종류 차례 전체를 받침 선호보다 먼저 비교한다.
static func _top_ahead(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return a.size() > b.size()
	for key: String in ["order", "choice"]:
		for i in range(a.size()):
			if a[i][key] != b[i][key]:
				return a[i][key] < b[i][key]
	return false


static func _match_tops(options: Array, limit: int, index: int = 0, used: Dictionary = {}) -> Array:
	if limit <= 0 or index >= options.size():
		return []
	var best: Array = []
	for choice: Dictionary in options[index]:
		if used.has(choice["slot"]):
			continue
		used[choice["slot"]] = true
		var picked: Array = [choice]
		picked.append_array(_match_tops(options, limit - 1, index + 1, used))
		used.erase(choice["slot"])
		if _top_ahead(picked, best):
			best = picked
	var skipped := _match_tops(options, limit, index + 1, used)
	return skipped if _top_ahead(skipped, best) else best


static func _coverage(props: Array, lv: int) -> Dictionary:
	var out: Dictionary = {}
	for p: Dictionary in props:
		if int(p.get("level", 0)) != lv or p.get("decor", false):
			continue
		var r: Variant = RoomFurnish._rect(p.get("rect"))
		if r == null:
			continue
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if not out.has(c):
					out[c] = []
				out[c].append(p)
	return out


static func _floor_avoid(data: Dictionary, props: Array, lv: int) -> Dictionary:
	var out: Dictionary = {}
	for box: Dictionary in data.get("containers", {}).values():
		if int(box.get("level", 0)) == lv:
			_avoid(out, RoomFurnish._cell(box.get("cell")), AVOID_TAKEN)
	for rug: Dictionary in data.get("rugs", []):
		if int(rug.get("level", 0)) != lv:
			continue
		var r: Rect2i = RoomFurnish._rect(rug["rect"])
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				_avoid(out, Vector2i(x, y), AVOID_RUG)
	# facing이 가리키는 면 전체의 바로 앞 한 칸을 비운다.
	for p: Dictionary in props:
		if int(p.get("level", 0)) != lv or p.get("decor", false):
			continue
		var r: Variant = RoomFurnish._rect(p.get("rect"))
		if r == null:
			continue
		var why := AVOID_HOLDER_FRONT if RoomFurnish.HOLDER_KINDS.has(String(p.get("kind", ""))) else AVOID_FRONT
		var front := FRONTS[posmod(int(p.get("facing", 0)), 4)]
		if front.x == 0:
			for x in range(r.position.x, r.end.x):
				_avoid(out, Vector2i(x, r.end.y if front.y > 0 else r.position.y - 1), why)
		else:
			for y in range(r.position.y, r.end.y):
				_avoid(out, Vector2i(r.end.x if front.x > 0 else r.position.x - 1, y), why)
	return out


static func _avoid(out: Dictionary, c: Vector2i, why: int) -> void:
	out[c] = maxi(int(out.get(c, 0)), why)


static func _walls(g: FieldGrid, of: PackedInt32Array, ri: int, cells: Array[Vector2i], cover: Dictionary, stairs: Dictionary) -> Array:
	var out: Array = []
	for facing: int in BACKS:
		var line: Dictionary = {}
		var along := Vector2i(1, 0) if facing == 0 else Vector2i(0, 1)
		for c in cells:
			if RoomFurnish._wall_side(g, of, ri, Rect2i(c, Vector2i.ONE), BACKS[facing]) \
					and _outer_wall(g, c, BACKS[facing]):
				line[c] = true
		# 이어진 벽 구간마다 한 번만 끝을 찾아 칸마다 [구간 안 자리, 구간 길이]를 둔다(칸마다 다시 찾으면 긴 벽에서 제곱).
		var spot: Dictionary = {}
		for c: Vector2i in line:
			if spot.has(c):
				continue
			var start := c
			while line.has(start - along):
				start -= along
			var run: Array[Vector2i] = []
			var e := start
			while line.has(e):
				run.append(e)
				e += along
			for i in range(run.size()):
				spot[run[i]] = Vector2i(i, run.size())
		for c: Vector2i in line:
			var tall := false
			for p: Dictionary in cover.get(c, []):
				tall = tall or RoomFurnish.TALL_KINDS.has(String(p.get("kind", "")))
			if tall or stairs.has(c):
				continue
			var at: Vector2i = spot[c]
			var lo := at.x
			var hi := at.y - 1 - at.x
			out.append({"cell": c, "facing": facing, "middle": 1.0 / (1.0 + absf(float(hi - lo)) / 2.0)})
	return out


## 등 벽이 집 안을 볼 때도 높이 그대로 서는 바깥 벽인가: 벽 칸이 같은 집이고 그 너머가 집 밖이며, 그리기의
## 칸 갈래(building_view cell_kind)가 턱 줄도 아니다. 안 벽과 턱 줄(남·동 바깥 줄, 그쪽으로 꺾인 모서리 —
## 북쪽 벽의 북동 끝, 서쪽 벽의 남서 끝)은 턱 높이로 낮춰 그려 거기 건 장식은 허공에 뜬다.
static func _outer_wall(g: FieldGrid, c: Vector2i, back: Vector2i) -> bool:
	var b := g.building_at(c)
	var w := c + back
	if g.building_at(w) != b or g.building_at(w + back) == b:
		return false
	return not BuildingView.cut_line(BuildingView.cell_kind(g, w, b))


static func _hanging(kind: String, cls: String, walls: Array, cover: Dictionary, hung: Array, seed_value: int) -> Dictionary:
	var best: Dictionary = {}
	for wall: Dictionary in walls:
		var c: Vector2i = wall["cell"]
		var facing: int = wall["facing"]
		var along := Vector2i(1, 0) if facing == 0 else Vector2i(0, 1)
		var crowded := false
		for other: Dictionary in hung:
			var delta: Vector2i = c - other["cell"]
			if delta == Vector2i.ZERO or (facing == other["facing"] and delta in [along, -along]):
				crowded = true
		if crowded:
			continue
		var kinds: Dictionary = {}
		var head := false
		for p: Dictionary in cover.get(c, []):
			var pk := String(p.get("kind", ""))
			kinds[pk] = true
			if pk in ["bed", "bunk_bed"]:
				var pf := posmod(int(p.get("facing", 0)), 4)
				head = head or (RoomFurnish.bed_head(RoomFurnish._rect(p["rect"]), pf) == c and BED_BACKS[pf] == BACKS[facing])
		if kind == "wall_mirror" and cls == "bath" and not kinds.has("washstand"):
			continue
		var score := 1.0 if not cover.has(c) else 0.0
		match kind:
			"wall_picture":
				score += 3.0 if head else (2.0 if kinds.has("settee") or kinds.has("dresser") else 0.0)
			"wall_mirror":
				score += 2.0 if kinds.has("dresser") else 0.0
			"wall_poster":
				score -= 1.0 if head else 0.0
			"wall_clock":
				score = float(wall["middle"]) if cls in ["kitchen", "living"] else 0.0
		var candidate := {"cell": c, "facing": facing, "score": score, "tie": hash([c.x, c.y, seed_value]) % 1000}
		if _better(candidate, best):
			best = candidate
	return best


static func _plant(g: FieldGrid, of: PackedInt32Array, ri: int, cells: Array[Vector2i], cover: Dictionary,
		avoid: Dictionary, forbidden: Dictionary, seed_value: int, step: int = 0) -> Dictionary:
	var best: Dictionary = {}
	for c in cells:
		var why := int(avoid.get(c, 0))
		if why >= AVOID_HOLDER_FRONT or (why == AVOID_FRONT and step < 2) or (why == AVOID_RUG and step < 1):
			continue
		if cover.has(c) or forbidden.get(c, "") == "all" or g.solid_at(c) != FieldGrid.Solid.NONE:
			continue
		var sides := 0
		var window := false
		for d in RoomFurnish.DIRS:
			sides += int(RoomFurnish._wall_side(g, of, ri, Rect2i(c, Vector2i.ONE), d))
			window = window or g.windows.has(c + d)
		var score := (2 if sides >= 2 else sides) + (2 if window else 0)
		var candidate := {"cell": c, "facing": 0, "score": float(score), "tie": hash([c.x, c.y, seed_value]) % 1000}
		if _better(candidate, best):
			best = candidate
	return best


static func _better(a: Dictionary, b: Dictionary) -> bool:
	if b.is_empty():
		return true
	if a["score"] != b["score"]:
		return a["score"] > b["score"]
	if a["tie"] != b["tie"]:
		return a["tie"] > b["tie"]
	if a["cell"].y != b["cell"].y:
		return a["cell"].y < b["cell"].y
	if a["cell"].x != b["cell"].x:
		return a["cell"].x < b["cell"].x
	return a["facing"] < b["facing"]
