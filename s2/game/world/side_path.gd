extends RefCounted
## 샛길과 희귀 창고(결정 카드 「막힌 지도 가장자리의 샛길」 가, 결정 442·450).
## 정차 넷에 하나꼴(이 판 씨앗), 정차 지도의 한 끝 너머에 띠 하나(STRIP칸)를 붙인다.
## 띠에는 숲으로 둘러싼 빈터와 잠긴 「희귀 창고」 한 채(상자 4~6, 창 절반 남짓 안쪽 판자, 둘레 망자
## 2~4)가 있고, 빈터는 옛 지도 끝에 난 틈 하나로만 들어간다. 나머지 띠는 성긴 숲이다.
## 승강장에서 걸어 편도 40~60초 걸리는 틈만 쓰고, 열차에서 먼 끝을 먼저 본다. 같은 장소·같은
## 씨앗이면 같은 자리다. 오른쪽·아래를 먼저 보고(옛 지도 좌표가 하나도 움직이지 않는다), 거기에
## 맞는 틈이 없을 때만 위·왼쪽에 붙이며 그때는 지도 전체를 STRIP칸 옮긴다(map_shift.gd) —
## 바깥 마을 띠(map_ring.gd)로 넓어진 마을 지도는 오른쪽·아래 끝이 열차에서 60초 넘게 멀기도 하다.
## 출발 시계와 다른 상자는 그대로다. 상자 속은 loot_dress.gd의 희귀 창고 표가 다시 채운다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const Shell = preload("res://game/world/sulehuf_map.gd")
const BuildingRules = preload("res://game/sim/building_rules.gd")
const LootRules = preload("res://game/sim/loot_rules.gd")
const PropKinds = preload("res://game/world/prop_kinds.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const NAME := "희귀 창고"  # loot_dress.gd RARE_STORE
const FIRST_STOP := "first_leg_01_sulechow"  # field_maps.gd DEFAULT_PLACE: hand-made, never grows
const CHANCE := 0.25
const WALK_SECONDS := Vector2(40.0, 60.0)
const WALK_SPEED := 2.1  # person.gd WALK; a cell is a metre
const LOT_WIDTH := 12
const DEPTH := 12
const BELT := 2
const GAP := 2
const STRIP := DEPTH + BELT
const STORE_SIZE := Vector2i(8, 6)
const BOXES := Vector2i(4, 6)
const DEAD := Vector2i(2, 4)
const BOARDED_SHARE := 0.5
const PLANKS := Vector2i(2, 4)
const TREE_STEP := 5
const TREE_SHARE := 0.35
## 숲 띠 2×2칸 가운데 겨울 잡목 덤불(모형이 있을 때만, art3d `thicket`)의 몫.
const THICKET_SHARE := 0.5
const BOX_NAMES: Array[String] = ["궤짝", "선반", "상자", "공구함", "자루", "보관함"]
## 틈에 걸친 것(지나갈 수 있음, 모형은 art3d): 벌어진 철망(가시 없음)·열린 나무 쪽문·무너진 판자 울타리.
const GAP_KINDS: Array[String] = ["gap_wire", "gap_gate", "gap_planks"]
## Left at the store's door (ref-ops R1: a rare place tells of itself from outside): one of these.
const CART_KINDS: Array[String] = ["handcart", "sled_load"]
const CART_NOTE: Dictionary = {"handcart": "손수레", "sled_load": "짐 실은 썰매"}


## 이 판에 샛길이 나는가(씨앗만 본다).
static func rolls(place_id: String, run_seed: int) -> bool:
	return _rng(place_id, run_seed).randf() < CHANCE


## 지도를 지은 뒤, 그리기 전에 한 번. 샛길이 나면 띠를 붙인 자료(같은 사전), 아니면 받은 그대로.
static func add(data: Dictionary, run_seed: int) -> Dictionary:
	var place := String(data.get("place_id", ""))
	if data.has("side_path") or place in ["", FIRST_STOP] or not data.get("grid") is FieldGrid:
		return data
	var rng := _rng(place, run_seed)
	if rng.randf() >= CHANCE:
		return data
	var spot := pick(data, rng)
	if spot.is_empty():
		return data
	var side := int(spot["side"])
	if side == 0 or side == 3:
		data = MapShift.grow(data, STRIP if side == 3 else 0, STRIP if side == 0 else 0, 0, 0, false)
	else:
		_grow(data, side)
	_build(data, spot, rng, run_seed)
	data["side_path"] = spot
	return data


## 누가 창고에 닿았는가: 문이 더는 잠겨 있지 않거나 상자 하나라도 뒤졌다.
static func visited(data: Dictionary) -> bool:
	var spot: Dictionary = data.get("side_path", {})
	if spot.is_empty():
		return false
	var door: Dictionary = data["grid"].doors.get(spot["door"], {})
	if String(door.get("state", "locked")) != "locked":
		return true
	for id: String in spot["boxes"]:
		if bool(data["containers"].get(id, {}).get("searched", false)):
			return true
	return false


static func _rng(place_id: String, run_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d|%s|side-path" % [run_seed, place_id]).hash()
	return rng


## 끝에서 틈 자리를 훑어, 걷는 시간이 맞는 곳 가운데 하나. 오른쪽·아래를 열차에서 먼 쪽부터
## 보고, 둘 다 없으면 위·왼쪽을 먼 쪽부터 본다. 틈 바로 앞(옛 지도 끝 칸 GAP개)은 걸을 수 있는
## 바깥 땅이어야 한다.
static func pick(data: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var g: FieldGrid = data["grid"]
	var dist := _walk_from_train(data, g)
	var at := Vector2(g.width, g.height) * 0.5
	if data.get("train") is Rect2i:
		at = Vector2((data["train"] as Rect2i).get_center())
	var sides := [1, 2] if g.width - at.x >= g.height - at.y else [2, 1]
	sides.append_array([3, 0] if at.x >= at.y else [0, 3])
	for side: int in sides:
		var length := g.height if side % 2 == 1 else g.width
		var ways := _entry_lanes(data, g, side)
		var found: Array = []
		for a in range(BELT, length - LOT_WIDTH - BELT + 1, 2):
			var clash := false
			for u: int in ways:
				clash = clash or (u >= a - BELT - 2 and u < a + LOT_WIDTH + BELT + 2)
			if clash:
				continue
			var gap_u := a + LOT_WIDTH / 2 - GAP / 2
			var best := -1
			var ok := true
			for u in range(gap_u, gap_u + GAP):
				var e := _at(g, side, u, 0)
				var f := g.floor_at(e)
				if g.building_at(e) >= 0 or not g.people_can_walk(e) or f == F.RAIL or f == F.PLATFORM or dist[g.index(e)] < 0:
					ok = false
					break
				if best < 0 or dist[g.index(e)] < best:
					best = dist[g.index(e)]
			if not ok:
				continue
			var seconds := float(best) / WALK_SPEED
			if seconds < WALK_SECONDS.x or seconds > WALK_SECONDS.y:
				continue
			found.append({"side": side, "along": a, "seconds": snappedf(seconds, 0.1)})
		if not found.is_empty():
			return found[rng.randi_range(0, found.size() - 1)]
	return {}


## 그 끝에 선 무리 들어오는 칸(entries)의 u. 띠를 붙이면 새 끝으로 옮긴다.
static func _entry_lanes(data: Dictionary, g: FieldGrid, side: int) -> Array:
	var out: Array = []
	for id in data.get("entries", {}):
		for c: Vector2i in data["entries"][id]:
			if _v_of(g, side, c) == 0:
				out.append(_u_of(side, c))
	return out


## 나무 한 그루: rect 칸을 막고(나무 칸이라 회색 덩이로 안 그려짐) 맨나무 모형 소품 하나.
static func _tree(data: Dictionary, g: FieldGrid, r: Rect2i, rng: RandomNumberGenerator, kind: String = "bare_tree") -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			g.set_solid(Vector2i(x, y), S.BLOCK)
			data["trees"].append(Vector2i(x, y))
	data.get_or_add("props", []).append({"kind": kind, "rect": r, "facing": rng.randi_range(0, 3), "level": 0})


## 숲 띠는 2×2칸마다 나무나 덤불 하나(남는 칸은 2×1·1×1 나무): 칸마다 세우면 말뚝 울타리처럼 보인다.
static func _belt_trees(data: Dictionary, g: FieldGrid, cells: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	var left: Dictionary = {}
	for c: Vector2i in cells:
		left[c] = true
	var thicket := not PropKinds.model_path("thicket").is_empty()
	var order: Array = cells.duplicate()
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y if a.y != b.y else a.x < b.x)
	for c: Vector2i in order:
		if not left.has(c):
			continue
		var r := Rect2i(c, Vector2i.ONE)
		for size: Vector2i in [Vector2i(2, 2), Vector2i(2, 1), Vector2i(1, 2)]:
			var fits := true
			for y in range(size.y):
				for x in range(size.x):
					fits = fits and left.has(c + Vector2i(x, y))
			if fits:
				r = Rect2i(c, size)
				break
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				left.erase(Vector2i(x, y))
		# Its own dice by cell, so whether the thicket model is there yet moves nothing else of the path.
		var bush := thicket and r.size == Vector2i(2, 2) and float(("%d|%d|thicket" % [r.position.x, r.position.y]).hash() % 1000) < THICKET_SHARE * 1000.0
		_tree(data, g, r, rng, "thicket" if bush else "bare_tree")


## 모든 층 격자를 오른쪽(1)이나 아래(2)로 STRIP칸 넓힌다. 옛 칸·좌표·문·창은 그대로다.
static func _grow(data: Dictionary, side: int) -> void:
	var levels: Dictionary = data.get("levels", {0: data["grid"]})
	for lv in levels:
		var g: FieldGrid = levels[lv]
		var n := FieldGrid.new(g.width + (STRIP if side == 1 else 0), g.height + (STRIP if side == 2 else 0))
		n.solid.fill(S.AIR if int(lv) > 0 else (S.BLOCK if int(lv) < 0 else S.NONE))
		n.floor.fill(F.SNOW)
		for y in range(g.height):
			for x in range(g.width):
				var i := y * g.width + x
				var j := y * n.width + x
				n.solid[j] = g.solid[i]
				n.floor[j] = g.floor[i]
				n.building[j] = g.building[i]
				n.zone[j] = g.zone[i]
		n.doors = g.doors
		n.windows = g.windows
		n.floor_glass = g.floor_glass
		n.revision = g.revision
		if int(lv) != 0:
			n.refresh_paths()  # the ground floor is refreshed once the strip is built
		levels[lv] = n
	data["levels"] = levels
	data["grid"] = levels[0]


## 띠의 u(끝을 따라)·v(새 끝에서 안쪽으로) 칸. v = STRIP이 옛 지도 끝 칸이다.
## 끝: 0 위, 1 오른쪽, 2 아래, 3 왼쪽.
static func _at(g: FieldGrid, side: int, u: int, v: int) -> Vector2i:
	match side:
		0:
			return Vector2i(u, v)
		1:
			return Vector2i(g.width - 1 - v, u)
		2:
			return Vector2i(u, g.height - 1 - v)
	return Vector2i(v, u)


static func _u_of(side: int, c: Vector2i) -> int:
	return c.y if side % 2 == 1 else c.x


static func _v_of(g: FieldGrid, side: int, c: Vector2i) -> int:
	match side:
		0:
			return c.y
		1:
			return g.width - 1 - c.x
		2:
			return g.height - 1 - c.y
	return c.x


## 열차 문에서 걸어서 몇 칸(닿지 못하면 -1).
static func _walk_from_train(data: Dictionary, g: FieldGrid) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(g.width * g.height)
	dist.fill(-1)
	var queue: Array[Vector2i] = []
	for c: Vector2i in data.get("spawns", {}).get("train_door", []):
		var w := g.nearest_walkable(c, false, 3)
		if g.inside(w) and g.people_can_walk(w) and dist[g.index(w)] < 0:
			dist[g.index(w)] = 0
			queue.append(w)
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n := c + d
			if g.inside(n) and dist[g.index(n)] < 0 and g.people_can_walk(n):
				dist[g.index(n)] = dist[g.index(c)] + 1
				queue.append(n)
	return dist


static func _build(data: Dictionary, spot: Dictionary, rng: RandomNumberGenerator, run_seed: int) -> void:
	var g: FieldGrid = data["grid"]
	var side: int = spot["side"]
	var a: int = spot["along"]
	var length := g.height if side % 2 == 1 else g.width
	var gap_u := a + LOT_WIDTH / 2 - GAP / 2
	var lot: Array[Vector2i] = []
	var belt: Array[Vector2i] = []
	var gap: Array[Vector2i] = []
	for v in range(STRIP):
		for u in range(a - BELT, a + LOT_WIDTH + BELT):
			var c := _at(g, side, u, v)
			if v < DEPTH and u >= a and u < a + LOT_WIDTH:
				lot.append(c)
			elif v >= DEPTH and u >= gap_u and u < gap_u + GAP:
				gap.append(c)
			else:
				belt.append(c)
	# The ways the dead come in on that edge move out to the new edge, so they still come
	# from beyond the map; their lanes across the strip stay clear of trees.
	var lanes: Dictionary = {}
	for id in data.get("entries", {}):
		var cells: Array = data["entries"][id]
		for i in range(cells.size()):
			var c: Vector2i = cells[i]
			if _v_of(g, side, c) == STRIP:
				cells[i] = _at(g, side, _u_of(side, c), 0)
				lanes[_u_of(side, c)] = true
	var flee: Variant = data.get("anchors", {}).get("flee_exit")
	if flee is Vector2i and _v_of(g, side, flee) == STRIP:
		data["anchors"]["flee_exit"] = _at(g, side, _u_of(side, flee), 0)
	# The belt is trees, a tree on every blocked cell; the rest of the strip is sparse woods,
	# kept off the clearing, the cells either side of the gap and the lanes of the dead.
	if not data.has("trees"):
		data["trees"] = []
	_belt_trees(data, g, belt, rng)
	var woods: Array[Vector2i] = []
	for v in range(1, STRIP - 2, TREE_STEP):
		for u in range(1, length - 1, TREE_STEP):
			if u >= a - BELT - 2 and u < a + LOT_WIDTH + BELT + 2:
				continue
			var tu := clampi(u + rng.randi_range(-1, 1), 0, length - 1)
			var c := _at(g, side, tu, v + rng.randi_range(0, 1))
			if rng.randf() < TREE_SHARE and g.solid_at(c) == S.NONE and not (lanes.has(tu - 1) or lanes.has(tu) or lanes.has(tu + 1)):
				_tree(data, g, Rect2i(c, Vector2i.ONE), rng)
				woods.append(c)
	# The store: its door faces the gap, its windows shut and half boarded from inside.
	var su := a + (LOT_WIDTH - STORE_SIZE.x) / 2
	var corner_a := _at(g, side, su, 1)
	var corner_b := _at(g, side, su + STORE_SIZE.x - 1, STORE_SIZE.y)
	var store := Rect2i(corner_a.min(corner_b), (corner_a - corner_b).abs() + Vector2i.ONE)
	var id := 0
	for b: Dictionary in data.get("buildings", []):
		id = maxi(id, int(b["id"]) + 1)
	Shell._rooms(g, id, store)
	data["buildings"].append({"id": id, "name": NAME, "rect": store, "warm": false, "window_broken": false, "role": "store"})
	var door := _at(g, side, gap_u + GAP - 1, STORE_SIZE.y)
	Shell._door(g, door, "locked", id)
	var mid := (1 + STORE_SIZE.y) / 2 + 1
	var windows: Array[Vector2i] = [_at(g, side, su, mid), _at(g, side, su + STORE_SIZE.x - 1, mid), _at(g, side, su + 2, STORE_SIZE.y)]
	var boarded: int = ceili(windows.size() * BOARDED_SHARE)
	var order := range(windows.size())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: int = order[i]
		order[i] = order[j]
		order[j] = t
	for k in range(windows.size()):
		var c: Vector2i = windows[order[k]]
		Shell._window(g, c, id)
		var w: Dictionary = g.windows[c]
		w["open"] = false
		w["stuck"] = false
		w["latched"] = rng.randf() < BuildingRules.LATCHED_SHARE
		w["planks"] = [0, 0]
		if k < boarded:
			var sides := g.faces(c)
			var inside := 0 if g.building_at(sides[0]) == id else 1
			for p in range(rng.randi_range(PLANKS.x, PLANKS.y)):
				BuildingRules.add_plank(w, inside)
	# A trodden way through the gap, and what once shut it.
	var lo: Vector2i = gap[0]
	var hi: Vector2i = gap[0]
	for c: Vector2i in gap:
		g.floor[g.index(c)] = F.GRAVEL
		lo = lo.min(c)
		hi = hi.max(c)
	var gap_kind := GAP_KINDS[rng.randi_range(0, GAP_KINDS.size() - 1)]
	data.get_or_add("props", []).append({"kind": gap_kind, "rect": Rect2i(lo, hi - lo + Vector2i.ONE),
		"facing": side, "level": 0, "note": "샛길 틈"})  # front toward the map: facing 0 +Z … 3 +X
	# The boxes stand along the walls inside, clear of the door's two cells.
	var faces := g.faces(door)
	var in_door: Vector2i = faces[0] if g.building_at(faces[0]) == id else faces[1]
	var step := in_door - door
	var keep_clear := {in_door: true, in_door + step: true}
	var spots: Array[Vector2i] = []
	for y in range(store.position.y + 1, store.end.y - 1):
		for x in range(store.position.x + 1, store.end.x - 1):
			var c := Vector2i(x, y)
			if keep_clear.has(c):
				continue
			if x == store.position.x + 1 or x == store.end.x - 2 or y == store.position.y + 1 or y == store.end.y - 2:
				spots.append(c)
	var count := mini(rng.randi_range(BOXES.x, BOXES.y), spots.size())
	var boxes: Dictionary = {}
	var ids: Array[String] = []
	for i in range(count):
		var c: Vector2i = spots[(i * spots.size()) / count]
		var box_id := "rare_store_%d" % i
		boxes[box_id] = {"id": box_id, "name": "%s의 %s" % [NAME, BOX_NAMES[i % BOX_NAMES.size()]], "cell": c, "level": 0,
			"building": id, "search": 4.0, "items": [], "locked": false, "searched": false}
		ids.append(box_id)
	# Ordinary store bundles first, so a box is never empty; loot_dress.gd fills them anew.
	LootRules.fill(boxes, ("%d|rare-store" % run_seed).hash())
	data["containers"].merge(boxes)
	# Left at the door: a handcart or a loaded sled along the front wall beside it, clear of the
	# door's and the front window's cells and of the way in from the gap.
	var cart_kind: String = CART_KINDS[rng.randi_range(0, CART_KINDS.size() - 1)]
	var ca := _at(g, side, gap_u + GAP + 1, STORE_SIZE.y + 1)
	var cb := _at(g, side, gap_u + GAP + 2, STORE_SIZE.y + 1)
	var cart := Rect2i(ca.min(cb), (ca - cb).abs() + Vector2i.ONE)
	for y in range(cart.position.y, cart.end.y):
		for x in range(cart.position.x, cart.end.x):
			g.set_solid(Vector2i(x, y), S.LOW)
	data.get_or_add("low_blocks", []).append(cart)
	data["props"].append({"kind": cart_kind, "rect": cart, "solid": "low", "facing": 0 if cart.size.x > 1 else 1,
		"level": 0, "note": "문 앞에 버려진 " + String(CART_NOTE[cart_kind])})
	# The dead: one shut in with the boxes, one just inside the gap (the way they came in),
	# the rest about the clearing.
	var dead: Array[Vector2i] = [in_door + step * 2]
	var yard: Array[Vector2i] = []
	for c: Vector2i in lot:
		if not store.grow(1).has_point(c):
			yard.append(c)
	var dead_count := rng.randi_range(DEAD.x, DEAD.y)
	var by_gap := _at(g, side, gap_u + rng.randi_range(0, GAP - 1), DEPTH - 1)
	yard.erase(by_gap)
	dead.append(by_gap)
	for i in range(dead_count - 2):
		if yard.is_empty():
			break
		dead.append(yard.pop_at(rng.randi_range(0, yard.size() - 1)))
	data.get_or_add("spawns", {})["dead_rare_store"] = dead
	g.refresh_paths()
	# For the ground shade under the trees (mood, fx): the belt is darkest, the sparse woods less.
	spot["belt"] = belt
	spot["woods"] = woods
	spot["gap"] = gap
	spot["entrance"] = [_at(g, side, gap_u, STRIP), _at(g, side, gap_u + 1, STRIP)]
	spot["store"] = store
	spot["door"] = door
	spot["gap_kind"] = gap_kind
	spot["building"] = id
	spot["boxes"] = ids
	spot["dead"] = dead.size()
	spot["boarded"] = boarded
