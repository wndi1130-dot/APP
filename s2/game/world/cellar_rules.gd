extends RefCounted
## 지하실 규칙(docs/design/briefs/house_layout.md 5장, 사용자 카드 16 「가」, 결정 423).
## 지도 파일은 고치지 않는다. field_maps.gd의 build_from이 maps/ 지도에만, 가구 놓기 앞에 건다.
## - 둘째 길(hatches): 공동주택·관청·병원 지도에서 지하 방이 HATCH_MIN_CELLS칸 넘는 건물에
##   마당 쪽 덧문을 낸다. 지하 바깥벽 한 칸을 트고 그 밖 한 칸을 계단참으로 삼아 땅 층 같은
##   칸과 계단으로 잇는다. 땅 층에는 계단 구멍과 난간이 마당에 보인다(building_view 계단 그림).
## - 지하 창(windows): 지하 방이 바깥벽에 닿는 건물마다 땅 높이 낮은 창 단서를 많아야
##   WINDOWS_PER_BUILDING개 둔다. 그림만이고 칸은 그대로다(map_view가 그린다).
## - 어두움·소리는 이미 있다: 지하 시야 7칸(field_game SIGHT_CELLAR), 층 하나마다 소리가
##   닿는 거리 절반(zombies.hear). 지하 물·진창은 3막(해빙)에만이라 여기서는 두지 않는다.

const FieldGrid = preload("res://game/world/field_grid.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")
const S = FieldGrid.Solid
const DIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]

## 덧문을 내는 지도 종류.
const HATCH_KINDS: Dictionary = {"houses": true, "office": true, "hospital": true}
## 덧문을 낼 만큼 큰 지하(건물의 지하 방 칸 수).
const HATCH_MIN_CELLS: int = 40
## 덧문 계단참은 열차 둘레 이만큼(칸) 밖에.
const HATCH_TRAIN_GAP: int = 4
## 건물 하나의 지하 창 단서 수.
const WINDOWS_PER_BUILDING: int = 2


## 건물 -> 지하 방 칸 수.
static func _cellar_cells(cel: FieldGrid) -> Dictionary:
	var map := RoomFurnish.rooms_of(cel)
	var out: Dictionary = {}
	for room: Dictionary in map["rooms"]:
		out[room["building"]] = int(out.get(room["building"], 0)) + room["cells"].size()
	return out


## 지하 바깥벽 칸 w와 방향 d: 안쪽(w - d)은 그 건물 지하 방의 빈칸, 바깥(w + d)은 두 층 모두 건물 밖.
static func _outer_walls(cel: FieldGrid, g0: FieldGrid, b: int) -> Array:
	var out: Array = []
	for y in range(cel.height):
		for x in range(cel.width):
			var w := Vector2i(x, y)
			if cel.solid_at(w) != S.WALL or cel.building_at(w) != b:
				continue
			for d in DIRS:
				var inner := w - d
				var land := w + d
				if not cel.inside(inner) or not cel.inside(land):
					continue
				if cel.building_at(inner) != b or cel.solid_at(inner) != S.NONE:
					continue
				if cel.building_at(land) >= 0 or g0.building_at(land) >= 0:
					continue
				out.append({"wall": w, "out": d, "land": land})
	return out


## 큰 지하에 덧문을 낸다. 돌려주는 값: 낸 덧문 수.
static func hatches(data: Dictionary) -> int:
	if not HATCH_KINDS.has(String(data.get("place_kind", ""))):
		return 0
	var levels: Dictionary = data.get("levels", {})
	if not levels.has(-1) or not levels.has(0):
		return 0
	var cel: FieldGrid = levels[-1]
	var g0: FieldGrid = levels[0]
	var keep_out: Array[Rect2i] = []
	for side in data.get("bands", {}):
		var band: Variant = data["bands"][side]
		if band is Rect2i:
			keep_out.append(band)
	if data.has("train"):
		keep_out.append((data["train"] as Rect2i).grow(HATCH_TRAIN_GAP))
	var sizes := _cellar_cells(cel)
	var bs: Array = sizes.keys()
	bs.sort()
	# 지하 가구가 선 칸: 덧문 안쪽 두 칸은 비어 있어야 길이 가구 사이로 꺾이지 않는다.
	var furnished: Dictionary = {}
	for p: Dictionary in data.get("props", []):
		if int(p.get("level", 0)) != -1:
			continue
		var r: Variant = RoomFurnish._rect(p.get("rect"))
		if r == null:
			continue
		for y in range((r as Rect2i).position.y, (r as Rect2i).end.y):
			for x in range((r as Rect2i).position.x, (r as Rect2i).end.x):
				furnished[Vector2i(x, y)] = true
	var made := 0
	for b: int in bs:
		if b < 0 or sizes[b] < HATCH_MIN_CELLS:
			continue
		var best: Dictionary = {}
		var best_score := -INF
		for c: Dictionary in _outer_walls(cel, g0, b):
			var land: Vector2i = c["land"]
			var inner: Vector2i = c["wall"] - c["out"]
			if furnished.has(inner) or furnished.has(inner - c["out"]):
				continue
			# 땅 층 계단참과 그 바깥 한 칸이 걸어서 다니는 마당이어야 한다.
			if not g0.people_can_walk(land) or not g0.people_can_walk(land + c["out"]):
				continue
			var blocked := false
			for r in keep_out:
				blocked = blocked or r.has_point(land)
			if blocked:
				continue
			# 열차에서 먼 뒤뜰 쪽. 같으면 위·왼쪽(읽는 차례가 위·왼쪽부터라 먼저 온 것).
			var score := 0.0
			if data.has("train"):
				var t: Rect2i = data["train"]
				score = absf(land.y + 0.5 - (t.position.y + t.size.y * 0.5))
			if score > best_score:
				best_score = score
				best = c
		if best.is_empty():
			continue
		if not data.has("stairs"):
			data["stairs"] = []
		var w: Vector2i = best["wall"]
		var land: Vector2i = best["land"]
		cel.set_solid(w, S.NONE)
		cel.building[cel.index(land)] = b
		cel.set_solid(land, S.NONE)
		data["stairs"].append({"cell": land, "low": -1, "high": 0, "ladder": false, "hatch": true, "into": w - land})
		made += 1
	if made > 0:
		cel.refresh_paths()
	return made


## 지하 창 단서: [{"cell": 땅 층 바깥벽 칸, "out": 바깥 방향, "building": 건물}].
static func windows(data: Dictionary) -> Array:
	var out: Array = []
	var levels: Dictionary = data.get("levels", {})
	if not levels.has(-1) or not levels.has(0):
		return out
	var cel: FieldGrid = levels[-1]
	var g0: FieldGrid = levels[0]
	var sizes := _cellar_cells(cel)
	var bs: Array = sizes.keys()
	bs.sort()
	for b: int in bs:
		if b < 0:
			continue
		var spots: Array = []
		for c: Dictionary in _outer_walls(cel, g0, b):
			var w: Vector2i = c["wall"]
			# 땅 층 같은 칸이 그 건물 바깥벽이고 바깥이 보이는 땅일 때만.
			if g0.solid_at(w) != S.WALL or g0.building_at(w) != b or not g0.people_can_walk(c["land"]):
				continue
			spots.append(c)
		# 필드 카메라는 남쪽에서 내려다본다: 북쪽 겉면은 지붕에 가려 안 보이니 두지 않고,
		# 남쪽 겉면을 먼저, 그다음 옆 겉면. 한 겉면 안에서는 처음과 가운데쯤.
		var picks: Array = []
		for face: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var row: Array = spots.filter(func(c: Dictionary) -> bool: return c["out"] == face)
			if row.is_empty():
				continue
			picks.append(row[0])
			if row.size() > 2:
				picks.append(row[row.size() / 2])
			if picks.size() >= WINDOWS_PER_BUILDING:
				break
		for c: Dictionary in picks.slice(0, WINDOWS_PER_BUILDING):
			out.append({"cell": c["wall"], "out": c["out"], "building": b})
	return out
