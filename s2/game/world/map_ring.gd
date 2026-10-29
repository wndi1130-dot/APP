extends RefCounted
## A stop's outer village. The finished old map is translated as one unit:
## room-number and window-coordinate seeds must not reroll its interiors.
const FieldGrid = preload("res://game/world/field_grid.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const Shell = preload("res://game/world/sulehuf_map.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")
const BuildingRules = preload("res://game/sim/building_rules.gd")
const LootRules = preload("res://game/sim/loot_rules.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const TOWN: Array[String] = ["houses", "freight", "office", "factory", "hospital", "church"]
const WILD: Array[String] = ["lake", "sawmill", "lodge", "mine", "summit", "bare_line"]
const TOWN_WIDTH := 30
const WILD_WIDTH := 20
const ROAD_WIDTH := 2
const LOT_STEP := 22
const TREE_STEP := 9
const FENCE_PIECE := 7
const TOWN_SHEDS: Array[String] = ["차고", "바깥 헛간"]
const WILD_SHEDS: Array[String] = ["장작 헛간", "외양간"]
static var _finishing := false
## Set while the plain map is built for a ring: its own path refresh is skipped, as the
## ring builds every floor's grid anew at the larger size (field_maps.gd build_from).
static var skip_paths := false


static func width_for(kind: String) -> int:
	return TOWN_WIDTH if TOWN.has(kind) else (WILD_WIDTH if WILD.has(kind) else 0)


static func enabled(script: Script) -> bool:
	return not _finishing and script.resource_path.begins_with("res://game/world/maps/")


## Re-enter the existing finishing pipeline once, at the original coordinates.
## Synchronous only: no scene state, random stream or save file is changed.
static func plain_build(script: Script, finish: Callable) -> Dictionary:
	var previous := _finishing
	_finishing = true
	var data: Dictionary = finish.call(script)
	_finishing = previous
	return data


static func build(script: Script, finish: Callable) -> Dictionary:
	skip_paths = true
	var plain := plain_build(script, finish)
	skip_paths = false
	var data := add(plain)
	if is_same(data, plain):
		for g: FieldGrid in plain.get("levels", {0: plain["grid"]}).values():
			g.refresh_paths()
	return data


static func add(original: Dictionary) -> Dictionary:
	if original.get("place_id", "") == "first_leg_01_sulechow":
		return original
	var width := width_for(String(original.get("place_kind", "")))
	if width == 0:
		return original
	var old: FieldGrid = original["grid"]
	var inner := Rect2i(width, width, old.width, old.height)
	var data := MapShift.grow(original, width, width, width, width, false)
	var g: FieldGrid = data["grid"]
	var rng := RandomNumberGenerator.new()
	rng.seed = (String(data["place_id"]) + "|outer-village").hash()
	var seed_value := rng.seed
	var target := rng.randi_range(4, 8) if width == TOWN_WIDTH else rng.randi_range(1, 3)
	# Work only on the ring. The solid mask prevents furnishing the old rooms.
	var rg := FieldGrid.new(g.width, g.height)
	for y in range(g.height):
		for x in range(g.width):
			var c := Vector2i(x, y)
			if inner.has_point(c):
				rg.solid[rg.index(c)] = S.BLOCK
	var ring := {"grid": rg, "levels": {0: rg}, "place_id": data["place_id"],
		"place_kind": data["place_kind"], "buildings": [], "props": [], "containers": {},
		"stairs": [], "low_blocks": [], "trees": [], "labels": [], "_defer_paths": true}
	var roads: Array[Rect2i] = []
	var mid := width / 2
	for r in [Rect2i(mid, mid, g.width - mid * 2, ROAD_WIDTH),
		Rect2i(mid, g.height - mid - ROAD_WIDTH, g.width - mid * 2, ROAD_WIDTH),
		Rect2i(mid, mid, ROAD_WIDTH, g.height - mid * 2),
		Rect2i(g.width - mid - ROAD_WIDTH, mid, ROAD_WIDTH, g.height - mid * 2)]:
		_paint_floor(rg, r, F.ROAD)
		roads.append(r)
	# Boundary lanes retain their whole width, including track on any side.
	for y in range(old.height):
		_extend(rg, old, Vector2i(0, y), Rect2i(0, y + width, width, 1), roads)
		_extend(rg, old, Vector2i(old.width - 1, y), Rect2i(inner.end.x, y + width, width, 1), roads)
	for x in range(old.width):
		_extend(rg, old, Vector2i(x, 0), Rect2i(x + width, 0, 1, width), roads)
		_extend(rg, old, Vector2i(x, old.height - 1), Rect2i(x + width, inner.end.y, 1, width), roads)
	# A river the map names (edge_water) runs on to the new edge as it lies at the old one, its
	# frozen bank and its deep water, so the ring road does not walk round it. Laid before the
	# lots and trees, which stand only on clear snow.
	var water: Array[Rect2i] = []
	for r: Rect2i in original.get("edge_water", []):
		for y in range(r.position.y, r.end.y):
			if r.position.x == 0:
				_run_water(rg, old, Vector2i(0, y), Rect2i(0, y + width, width, 1), water)
			if r.end.x == old.width:
				_run_water(rg, old, Vector2i(old.width - 1, y), Rect2i(inner.end.x, y + width, width, 1), water)
		for x in range(r.position.x, r.end.x):
			if r.position.y == 0:
				_run_water(rg, old, Vector2i(x, 0), Rect2i(x + width, 0, 1, width), water)
			if r.end.y == old.height:
				_run_water(rg, old, Vector2i(x, old.height - 1), Rect2i(x + width, inner.end.y, 1, width), water)
	for r in _merge_runs(water):
		ring["props"].append({"kind": "water", "rect": r, "solid": "low", "facing": 0, "level": 0})
		ring["low_blocks"].append(r)
	# The named rects too, at the grown map's cells and out to the new edge: side_path.gd keeps
	# its strip off an edge the river reaches, where it would walk round the river's end.
	var reaches: Array[Rect2i] = []
	for r: Rect2i in original.get("edge_water", []):
		var x0 := 0 if r.position.x == 0 else r.position.x + width
		var y0 := 0 if r.position.y == 0 else r.position.y + width
		var x1 := g.width if r.end.x == old.width else r.end.x + width
		var y1 := g.height if r.end.y == old.height else r.end.y + width
		reaches.append(Rect2i(x0, y0, x1 - x0, y1 - y0))
	if not reaches.is_empty():
		data["edge_water"] = reaches
	var next_id := 0
	for b: Dictionary in data.get("buildings", []):
		next_id = maxi(next_id, int(b["id"]) + 1)
	# Choose among all four sides. Try every candidate, with no random retry loop.
	var sides: Array = [[], [], [], []]
	for x in range(width, g.width - width - 12, LOT_STEP):
		sides[0].append(Rect2i(x, 2, 12, 7 if width == TOWN_WIDTH else 6))
		sides[2].append(Rect2i(x, g.height - (9 if width == TOWN_WIDTH else 8), 12, 7 if width == TOWN_WIDTH else 6))
	for y in range(width, g.height - width - 12, LOT_STEP):
		sides[1].append(Rect2i(g.width - (9 if width == TOWN_WIDTH else 8), y, 7 if width == TOWN_WIDTH else 6, 12))
		sides[3].append(Rect2i(2, y, 7 if width == TOWN_WIDTH else 6, 12))
	for list: Array in sides:
		for i in range(list.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: Rect2i = list[i]
			list[i] = list[j]
			list[j] = tmp
	var lots: Array[Rect2i] = []
	_move_entries_out(data, inner)
	var start_side := rng.randi_range(0, 3)
	for round_index in range(20):
		for k in range(4):
			var side := (start_side + k) % 4
			if lots.size() >= target or round_index >= sides[side].size():
				continue
			var r: Rect2i = sides[side][round_index]
			if not _clear(rg, r.grow(1), inner, lots):
				continue
			_house(ring, r, next_id + lots.size(), lots.size(), side, mid)
			lots.append(r.grow(1))
	# Snow-covered furrows are floor colour only; no props or collision rows.
	var fields: Array[Rect2i] = []
	for x in range(width, g.width - width - 10, LOT_STEP):
		for y in [2, g.height - 8]:
			var r := Rect2i(x, y, 10, 6)
			if _clear(rg, r.grow(1), inner, lots):
				for fy in range(r.position.y, r.end.y, 2):
					_paint_floor(rg, Rect2i(r.position.x, fy, r.size.x, 1), F.GRAVEL)
				fields.append(r)
				lots.append(r.grow(1))
	for y in range(3, g.height - 3, TREE_STEP):
		for x in range(3, g.width - 3, TREE_STEP):
			var c := Vector2i(x + rng.randi_range(-1, 1), y + rng.randi_range(-1, 1))
			if rng.randf() < 0.55 and _clear(rg, Rect2i(c - Vector2i.ONE * 2, Vector2i.ONE * 5), inner.grow(2), lots):
				rg.set_solid(c, S.BLOCK)
				ring["trees"].append(c)
				ring["props"].append({"kind": "bare_tree", "rect": Rect2i(c, Vector2i.ONE), "facing": rng.randi_range(0, 3), "level": 0})
	ring["room_stats"] = RoomFurnish.furnish_rooms(ring)
	RoomFurnish.clear_fronts(ring)
	RoomFurnish.block_furniture(ring)
	# Fill by name before the spare boxes come: they stay empty and take a share of the place's
	# bundles when the stop opens (room_furnish boxes_into_furniture), as on the inner map. Their
	# names (서랍장, 찬장, 곁탁자, 수건 선반) would roll a box of their own.
	LootRules.fill(ring["containers"], seed_value)
	RoomFurnish.boxes_into_furniture(ring)
	BuildingRules.dress_windows(ring)
	# After the fill (it reads the names): a box in a piece whose name says another room takes the piece's name.
	RoomFurnish.name_boxes_by_furniture(ring)
	_keep_place_kinds(ring["containers"], data["containers"])
	for y in range(g.height):
		for x in range(g.width):
			var c := Vector2i(x, y)
			if inner.has_point(c):
				continue
			var i := g.index(c)
			g.solid[i] = rg.solid[i]
			g.floor[i] = rg.floor[i]
			g.building[i] = rg.building[i]
			g.zone[i] = ""
	g.doors.merge(rg.doors)
	g.windows.merge(rg.windows)
	for key in ["buildings", "props", "low_blocks", "trees", "labels", "rugs"]:
		if not data.has(key):
			data[key] = []
		data[key].append_array(ring.get(key, []))
	data["containers"].merge(ring["containers"])
	g.refresh_paths()
	# The room kinds were numbered by room on the grid that was furnished: the grown grid numbers
	# its rooms anew, so the old table would name the wrong rooms (box keys, room_furnish.gd).
	data.erase("density_classes")
	data["map_ring"] = {"width": width, "inner": inner, "seed": seed_value,
		"buildings": ring["buildings"].size(), "target": target, "roads": roads,
		"fields": fields, "containers": ring["containers"].keys(), "rooms": ring["room_stats"]}
	return data


## The outer houses belong to the same place: their boxes keep only the kinds of things the
## place's own boxes hold, so a place whose boxes have none of a thing (the pass's scrap lies
## only on its rails and core heap) gets none from its outer houses either.
static func _keep_place_kinds(ring_boxes: Dictionary, place_boxes: Dictionary) -> void:
	var kinds: Dictionary = {}
	for id in place_boxes:
		for it in place_boxes[id].get("items", []):
			kinds[_item_id(it)] = true
	for id in ring_boxes:
		var kept: Array = []
		for it in ring_boxes[id].get("items", []):
			if kinds.has(_item_id(it)):
				kept.append(it)
		ring_boxes[id]["items"] = kept


static func _item_id(it: Variant) -> String:
	return String(it.get("id", "")) if it is Dictionary else String(it)


## The dead still come from beyond the map: a ground entry on the old border moves
## straight out to the new edge. No lot, fence or tree stands on the outermost row, so
## the dead walk in round the yards. The flee exit goes with it.
static func _move_entries_out(data: Dictionary, inner: Rect2i) -> void:
	var g: FieldGrid = data["grid"]
	var moved := {}
	for id in data.get("entries", {}):
		if data.get("manholes", {}).has(id) or int(data.get("entry_levels", {}).get(id, 0)) != 0:
			continue
		var cells: Array = data["entries"][id]
		for i in range(cells.size()):
			var c: Vector2i = cells[i]
			var out := c
			if c.x == inner.position.x:
				out = Vector2i(0, c.y)
			elif c.x == inner.end.x - 1:
				out = Vector2i(g.width - 1, c.y)
			elif c.y == inner.position.y:
				out = Vector2i(c.x, 0)
			elif c.y == inner.end.y - 1:
				out = Vector2i(c.x, g.height - 1)
			if out == c:
				continue
			moved[c] = out
			cells[i] = out
	var anchors: Dictionary = data.get("anchors", {})
	if anchors.get("flee_exit") is Vector2i and moved.has(anchors["flee_exit"]):
		anchors["flee_exit"] = moved[anchors["flee_exit"]]


static func _paint_floor(g: FieldGrid, r: Rect2i, floor_kind: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := g.index(Vector2i(x, y))
			if g.floor[i] != F.RAIL:
				g.floor[i] = floor_kind


static func _extend(g: FieldGrid, old: FieldGrid, c: Vector2i, r: Rect2i, roads: Array[Rect2i]) -> void:
	var floor_kind := old.floor_at(c)
	if floor_kind == F.RAIL or (floor_kind == F.ROAD and old.people_can_walk(c)):
		_paint_floor(g, r, floor_kind)
		roads.append(r)


## One edge cell of a named river: its ice runs on over `r`, and deep water (the low water
## blocks) blocks it as it does inside.
static func _run_water(g: FieldGrid, old: FieldGrid, c: Vector2i, r: Rect2i, deep: Array[Rect2i]) -> void:
	if old.floor_at(c) != F.ICE:
		return
	var low := old.solid_at(c) == S.LOW
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var at := Vector2i(x, y)
			g.floor[g.index(at)] = F.ICE
			g.set_solid(at, S.LOW if low else S.NONE)
	if low:
		deep.append(r)


## Rows (or columns) of deep water laid one by one, joined where they lie side by side.
static func _merge_runs(runs: Array[Rect2i]) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for r in runs:
		var joined := false
		for i in range(out.size()):
			var o := out[i]
			if (o.position.x == r.position.x and o.size.x == r.size.x and o.end.y == r.position.y) \
					or (o.position.y == r.position.y and o.size.y == r.size.y and o.end.x == r.position.x):
				out[i] = o.merge(r)
				joined = true
				break
		if not joined:
			out.append(r)
	return out


static func _clear(g: FieldGrid, r: Rect2i, inner: Rect2i, lots: Array[Rect2i]) -> bool:
	if inner.intersects(r) or not Rect2i(0, 0, g.width, g.height).encloses(r):
		return false
	for lot in lots:
		if r.intersects(lot):
			return false
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := g.index(Vector2i(x, y))
			if g.solid[i] != S.NONE or g.floor[i] != F.SNOW:
				return false
	return true


static func _house(data: Dictionary, r: Rect2i, id: int, number: int, side: int, road: int) -> void:
	var g: FieldGrid = data["grid"]
	var home := number % 3 == 2
	# Every third lot a lone house, the rest sheds by what the place is (ref-ops 대조 7): the
	# room names furnish them (room_furnish.gd: garage, barn, woodshed kits). Box names stay.
	var sheds: Array[String] = TOWN_SHEDS if TOWN.has(String(data.get("place_kind", ""))) else WILD_SHEDS
	var name: String = "외딴집" if home else (sheds[(number / 3) % sheds.size()] if number % 3 == 0 else "바깥 창고")
	data["buildings"].append({"id": id, "name": name, "rect": r, "warm": false,
		"window_broken": false, "role": "home" if home else "shed"})
	if number % 3 == 0:
		data["labels"].append({"text": name, "cell": r.position + Vector2i(2, 2), "level": 0})
	Shell._rooms(g, id, r)
	var door := Vector2i(r.position.x + r.size.x / 2, r.end.y - 1)
	var direction := Vector2i.DOWN
	var end := Vector2i(door.x, road)
	if side == 2:
		door.y = r.position.y
		direction = Vector2i.UP
		end = Vector2i(door.x, g.height - road - 1)
	elif side == 1:
		door = Vector2i(r.position.x, r.position.y + r.size.y / 2)
		direction = Vector2i.LEFT
		end = Vector2i(g.width - road - 1, door.y)
	elif side == 3:
		door = Vector2i(r.end.x - 1, r.position.y + r.size.y / 2)
		direction = Vector2i.RIGHT
		end = Vector2i(road, door.y)
	Shell._door(g, door, "closed", id)
	Shell._window(g, Vector2i(r.position.x + 2, r.position.y), id)
	Shell._window(g, Vector2i(r.end.x - 3, r.end.y - 1), id)
	# Low wooden yard fences, with a three-cell opening facing the road; each straight
	# run is drawn as plank-fence models (6 m) of at most FENCE_PIECE cells, turned
	# along the run: the model fit turns a piece only when it fits either way.
	var yard := r.grow(1)
	var gate := door + direction
	var sides_cells: Array = [[], [], [], []]
	for x in range(yard.position.x, yard.end.x):
		sides_cells[0].append(Vector2i(x, yard.position.y))
		sides_cells[1].append(Vector2i(x, yard.end.y - 1))
	for y in range(yard.position.y + 1, yard.end.y - 1):
		sides_cells[2].append(Vector2i(yard.position.x, y))
		sides_cells[3].append(Vector2i(yard.end.x - 1, y))
	for side_index in range(4):
		var cells: Array = sides_cells[side_index]
		var facing := 0 if side_index < 2 else 1
		var run: Array[Vector2i] = []
		for k in range(cells.size() + 1):
			var c: Vector2i = cells[k] if k < cells.size() else Vector2i(-1, -1)
			var open: bool = k < cells.size() and (c - gate).length_squared() > 1
			if open:
				g.set_solid(c, S.LOW)
				data["low_blocks"].append(Rect2i(c, Vector2i.ONE))
				run.append(c)
			if not open and not run.is_empty():
				# Even pieces of 4 to 7 cells from a run of 4 on (8 -> 4, 4; 15 -> 5, 5, 5),
				# so no short stub squashes the planks past what the fit allows.
				var pieces := ceili(float(run.size()) / FENCE_PIECE)
				var from := 0
				for p in range(pieces):
					var n := run.size() / pieces + (1 if p < run.size() % pieces else 0)
					data["props"].append({"kind": "plank_fence", "rect": Rect2i(run[from], run[from + n - 1] - run[from] + Vector2i.ONE), "facing": facing, "level": 0})
					from += n
				run.clear()
	var at := door + direction
	while at != end:
		g.floor[g.index(at)] = F.ROAD
		at += direction
	g.floor[g.index(end)] = F.ROAD
	for i in range(2):
		var box_id := "ring_%d_%d" % [id, i]
		var c := r.position + Vector2i(2 + i * (r.size.x - 5), 2)
		data["containers"][box_id] = {"id": box_id, "name": ("부엌 찬장" if i == 0 else "옷장") if home else ("창고 상자" if i == 0 else "공구함"),
			"cell": c, "level": 0, "building": id, "search": 4.0, "items": [], "locked": false, "searched": false}
