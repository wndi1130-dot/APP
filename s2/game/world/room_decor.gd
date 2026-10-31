extends RefCounted
## 참고 사본 방 꾸밈 표(10-30). 가구 배치 뒤, 충돌과 상자를 건드리지 않는 장식 층.

const RoomFurnish = preload("res://game/world/room_furnish.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const BuildingView = preload("res://game/world/building_view.gd")
const KINDS: Array[String] = ["wall_picture", "wall_mirror", "wall_poster", "wall_clock", "potted_plant"]
const NAMES: Dictionary = {"wall_picture": "벽 그림", "wall_mirror": "거울", "wall_poster": "포스터",
	"wall_clock": "벽시계", "potted_plant": "화분"}
# 쓰임 번호는 배치 차례와 독립이다. 종류를 추가해도 기존 굴림이 바뀌지 않는다.
const PURPOSE: Dictionary = {"wall_picture": 0, "potted_plant": 1, "wall_mirror": 2, "wall_poster": 3, "wall_clock": 4}
const PLAN: Dictionary = {
	"bed": {"wall_picture": [0.49, 1], "potted_plant": [0.28, 1], "wall_mirror": [0.14, 1], "wall_poster": [0.08, 2], "wall_clock": [0.01, 1]},
	"living": {"wall_picture": [0.66, 2], "potted_plant": [0.53, 1], "wall_mirror": [0.32, 1], "wall_poster": [0.02, 1], "wall_clock": [0.14, 1]},
	"kitchen": {"wall_picture": [0.09, 1], "potted_plant": [0.23, 1], "wall_clock": [0.22, 1]},
	# 욕실 거울 0.80은 참고 표 밖의 새 값이며, 북·서 벽 세면대 위에만 둔다.
	"bath": {"wall_mirror": [0.80, 1]},
}
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


static func dress(data: Dictionary) -> Dictionary:
	var stats := {"rooms": {}, "kinds": {}, "rows": 0}
	for cls: String in PLAN:
		stats["rooms"][cls] = 0
	for kind: String in KINDS:
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
	data["props"] = props
	return stats


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
