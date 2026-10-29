extends RefCounted
## Work-site metadata only; the map's floors, solids and trees stay as built.

const FieldGrid = preload("res://game/world/field_grid.gd")
const BuildingUses = preload("res://game/world/building_uses.gd")
const FieldWork = preload("res://game/field_work.gd")
const MAX_PATH_M: float = 90.0
## Places whose work site loads stacked wood (decision 486): the houses first, the other
## places without coal wagons once the crew runs pass there as well.
const WOOD_JOB_PLACES: Array[String] = ["houses"]
const JOB_PATH_M: float = 60.0
## A pile nearer the doors than this stands at the platform's edge (houses_03 has two, 3 and
## 7 m out), where the crew would not go out at all: taken only when no farther pile is in reach.
const JOB_MIN_M: float = 15.0
const WOOD_PILES: Dictionary = {"firewood_pile": "장작 더미", "lumber_stack": "목재 더미",
	"firewood_stack": "장작 더미", "firewood_rick": "장작 단", "sleeper_stack": "침목 더미"}
const BLOCK_SEGMENTS: int = 9
const GROVE_LIMIT: int = 3
## Field steps in fifths of a metre: 7/5 is within 1% of a diagonal's root two.
const STEP: int = 5
const DIAGONAL: int = 7
const CARDINAL: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


static func dress(data: Dictionary, seg: int, run_seed: int) -> void:
	var g: FieldGrid = data.get("grid") as FieldGrid
	if g == null or _train_doors(data).is_empty():
		return
	var field: PackedInt32Array = field_of(data)
	var groves: Array = data.get("fell_groves", []) as Array
	var has_inner: bool = false
	for grove: Dictionary in groves:
		if String(grove.get("kind", "")) == "fell" and not bool(grove.get("edge", false)):
			has_inner = true
			break
	if not has_inner:
		groves.append_array(_map_groves(data, field))
	data["fell_groves"] = groves
	_wood_job(data, field)
	if seg < 0 or not depot_segments(run_seed, floori(float(seg) / float(BLOCK_SEGMENTS))).has(seg):
		return
	var sites: Array = data.get("work_sites", []) as Array
	for site: Dictionary in sites:
		if String(site.get("kind", "")) == "food":
			return
	var depot: Dictionary = _food_site(data, seg, run_seed, field)
	if not depot.is_empty():
		sites.append(depot)
		data["work_sites"] = sites


## Pick uniformly from the valid ordered pairs, without retries or shared state.
## Both stand in a block's stretches 1..7, so the last of one block and the first
## of the next are three or more apart as well.
static func depot_segments(run_seed: int, block: int) -> Array[int]:
	var pairs: Array[Vector2i] = []
	for first: int in range(1, BLOCK_SEGMENTS - 4):
		for second: int in range(first + 3, BLOCK_SEGMENTS - 1):
			pairs.append(Vector2i(first, second))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%d:food:%d" % [run_seed, block])
	var pair: Vector2i = pairs[rng.randi_range(0, pairs.size() - 1)]
	return [block * BLOCK_SEGMENTS + pair.x, block * BLOCK_SEGMENTS + pair.y]


## Walked metres from the nearest train door to `cell` (0 on a door), or -1: not
## walkable, walled off, more than MAX_PATH_M on foot, or no door within MAX_PATH_M
## in a straight line.
static func reach(data: Dictionary, cell: Vector2i, field: PackedInt32Array = PackedInt32Array()) -> float:
	var g: FieldGrid = data.get("grid") as FieldGrid
	if g == null or not g.people_can_walk(cell):
		return -1.0
	var target: Vector3 = FieldGrid.center(cell)
	var near: bool = false
	for door: Vector2i in _train_doors(data):
		if FieldGrid.center(door).distance_to(target) <= MAX_PATH_M:
			near = true
			break
	if not near:
		return -1.0
	return _metres(field if not field.is_empty() else field_of(data), g, cell)


static func _metres(field: PackedInt32Array, g: FieldGrid, cell: Vector2i) -> float:
	if not g.inside(cell) or field.size() != g.width * g.height:
		return -1.0
	var steps: int = field[g.index(cell)]
	return -1.0 if steps < 0 else float(steps) / float(STEP)


## The map's walk field, made once for the grid as it stands (its revision) and the
## doors, and kept in the data: the stop loader makes it on its worker, the field's
## dress and the woods' groves read it.
static func field_of(data: Dictionary) -> PackedInt32Array:
	var g: FieldGrid = data.get("grid") as FieldGrid
	if g == null:
		return PackedInt32Array()
	var key: Array = [g.get_instance_id(), g.revision, _train_doors(data).hash()]
	if data.get("_walk_key", []) == key:
		return data["_walk_field"] as PackedInt32Array
	var field: PackedInt32Array = walk_field(data)
	data["_walk_field"] = field
	data["_walk_key"] = key
	return field


## Steps (fifths of a metre) from the train doors to every walkable cell within
## `limit_m` on foot, in one search over the grid's walk cache (refresh_paths):
## 8-way moves that never cut a blocked corner, as the people's A* walks; -1 out
## of reach. A door off the walk starts from the nearest walkable cell within two,
## as find_path does. Routes along a slant read a few per cent longer than
## find_path's smoothed walk, so the cap errs short.
static func walk_field(data: Dictionary, limit_m: float = MAX_PATH_M) -> PackedInt32Array:
	var g: FieldGrid = data.get("grid") as FieldGrid
	var field: PackedInt32Array = PackedInt32Array()
	if g == null:
		return field
	var w: int = g.width
	var size: int = w * g.height
	field.resize(size)
	field.fill(-1)
	var walk: PackedByteArray = g.walk_people
	var limit: int = int(limit_m * STEP)
	# A bucket of cell indices per step count: a move adds STEP or DIAGONAL, so a
	# bucket is full by the time the search reaches it.
	var buckets: Array = []
	buckets.resize(limit + DIAGONAL + 1)
	for door: Vector2i in _train_doors(data):
		var start: Vector2i = door if g.people_can_walk(door) else g.nearest_walkable(door, false, 2)
		if not g.people_can_walk(start):
			continue
		var first: int = roundi(FieldGrid.center(door).distance_to(FieldGrid.center(start)) * STEP)
		if first <= limit:
			if buckets[first] == null:
				buckets[first] = []
			(buckets[first] as Array).append(g.index(start))
	for steps: int in range(limit + 1):
		var bucket: Variant = buckets[steps]
		if bucket == null:
			continue
		buckets[steps] = null
		var straight: Array = []
		var slant: Array = []
		for i: int in bucket as Array:
			if field[i] >= 0:
				continue
			field[i] = steps
			var x: int = i % w
			var wl: bool = x > 0 and walk[i - 1] == 1
			var wr: bool = x < w - 1 and walk[i + 1] == 1
			var wu: bool = i >= w and walk[i - w] == 1
			var wd: bool = i + w < size and walk[i + w] == 1
			if wl and field[i - 1] < 0:
				straight.append(i - 1)
			if wr and field[i + 1] < 0:
				straight.append(i + 1)
			if wu and field[i - w] < 0:
				straight.append(i - w)
			if wd and field[i + w] < 0:
				straight.append(i + w)
			if wu and wl and walk[i - w - 1] == 1 and field[i - w - 1] < 0:
				slant.append(i - w - 1)
			if wu and wr and walk[i - w + 1] == 1 and field[i - w + 1] < 0:
				slant.append(i - w + 1)
			if wd and wl and walk[i + w - 1] == 1 and field[i + w - 1] < 0:
				slant.append(i + w - 1)
			if wd and wr and walk[i + w + 1] == 1 and field[i + w + 1] < 0:
				slant.append(i + w + 1)
		if not straight.is_empty() and steps + STEP <= limit:
			if buckets[steps + STEP] == null:
				buckets[steps + STEP] = straight
			else:
				(buckets[steps + STEP] as Array).append_array(straight)
		if not slant.is_empty() and steps + DIAGONAL <= limit:
			if buckets[steps + DIAGONAL] == null:
				buckets[steps + DIAGONAL] = slant
			else:
				(buckets[steps + DIAGONAL] as Array).append_array(slant)
	return field


static func _train_doors(data: Dictionary) -> Array[Vector2i]:
	var doors: Array[Vector2i] = []
	var sides: Dictionary = data.get("train_doors", {}) as Dictionary
	for row: Array in sides.values():
		for cell: Vector2i in row:
			if not doors.has(cell):
				doors.append(cell)
	if doors.is_empty():
		var spawns: Dictionary = data.get("spawns", {}) as Dictionary
		for cell: Vector2i in spawns.get("train_door", []) as Array:
			if not doors.has(cell):
				doors.append(cell)
	return doors


static func _stand_paths(data: Dictionary, cells: Array[Vector2i], field: PackedInt32Array, limit: float = -1.0) -> Dictionary:
	var stand: Array[Vector2i] = []
	var nearest: float = -1.0
	var g: FieldGrid = data["grid"] as FieldGrid
	for cell: Vector2i in cells:
		var distance: float = _metres(field, g, cell)
		if distance < 0.0 or (limit >= 0.0 and distance > limit):
			continue
		stand.append(cell)
		if nearest < 0.0 or distance < nearest:
			nearest = distance
	return {"stand": stand, "path_m": nearest}


static func _map_groves(data: Dictionary, field: PackedInt32Array) -> Array:
	var g: FieldGrid = data["grid"] as FieldGrid
	var w: int = g.width
	var h: int = g.height
	var walk: PackedByteArray = g.walk_people
	var trees: Dictionary = {}
	for cell: Vector2i in data.get("trees", []) as Array:
		trees[cell] = true
	var seen: Dictionary = {}
	var candidates: Array[Dictionary] = []
	for first: Vector2i in trees:
		if seen.has(first):
			continue
		var cells: Array[Vector2i] = [first]
		seen[first] = true
		var cursor: int = 0
		while cursor < cells.size():
			var current: Vector2i = cells[cursor]
			cursor += 1
			for dy: int in range(-2, 3):
				for dx: int in range(-2, 3):
					var neighbor: Vector2i = current + Vector2i(dx, dy)
					if trees.has(neighbor) and not seen.has(neighbor):
						seen[neighbor] = true
						cells.append(neighbor)
		if cells.size() < 4:
			continue
		var around: Dictionary = {}
		for cell: Vector2i in cells:
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var n: Vector2i = cell + Vector2i(dx, dy)
					if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and walk[n.y * w + n.x] == 1 and not trees.has(n):
						around[n] = true
		var possible: Array[Vector2i] = []
		possible.assign(around.keys())
		var reached: Dictionary = _stand_paths(data, possible, field)
		if float(reached["path_m"]) < 0.0:
			continue
		var grove: Dictionary = {"kind": "fell", "cells": cells, "stand": reached["stand"],
			"trees": cells.size(), "level": 0, "edge": false}
		candidates.append({"site": grove, "path_m": float(reached["path_m"]), "order": candidates.size()})
	candidates.sort_custom(_nearer)
	var out: Array = []
	for i: int in range(mini(GROVE_LIMIT, candidates.size())):
		out.append(candidates[i]["site"])
	return out


static func _nearer(a: Dictionary, b: Dictionary) -> bool:
	if float(a["path_m"]) == float(b["path_m"]):
		return int(a["order"]) < int(b["order"])
	return float(a["path_m"]) < float(b["path_m"])


## A place without coal wagons gets stacked wood at its work site: what the place's wood
## table leaves after the map's salvage (FieldWork.budget), so the stop's sum is the table's.
## The map's own site stays where the crew walks to it within JOB_PATH_M; else, or with
## none, the site moves beside the nearest wood pile. A site with a job already is kept.
static func _wood_job(data: Dictionary, field: PackedInt32Array) -> void:
	var place: String = String(data.get("place_kind", ""))
	if not WOOD_JOB_PLACES.has(place) or FieldWork.wagon_coal(data) > FieldWork.EMPTY:
		return
	var spots: Dictionary = data.get("spots", {}) as Dictionary
	var site: Dictionary = spots.get("work_site", {}) as Dictionary
	if site.has("job"):
		return
	var amount: float = float(FieldWork.WOOD_TABLE.get(place, 0)) - float(FieldWork.budget(data)["wood"])
	if amount <= FieldWork.EMPTY:
		return
	var g: FieldGrid = data["grid"] as FieldGrid
	var path_m: float = _metres(field, g, site["cell"]) if site.has("cell") else -1.0
	if path_m < 0.0 or path_m > JOB_PATH_M:
		var pile: Dictionary = _wood_pile(data, field)
		if pile.is_empty():
			return
		site = {"kind": "work_site", "name": pile["name"], "state": "closed",
			"cell": pile["cell"], "zone_rect": pile["zone"]}
	site["job"] = "wood_stack"
	site["amount"] = amount
	spots["work_site"] = site
	data["spots"] = spots


## The walkable cell beside a ground-floor wood pile that is best to work from: out of doors
## first, then JOB_MIN_M or more on foot, then room in its row for four carriers two metres
## apart, then the shorter walk. Empty when no pile is within JOB_PATH_M.
static func _wood_pile(data: Dictionary, field: PackedInt32Array) -> Dictionary:
	var g: FieldGrid = data["grid"] as FieldGrid
	var best: Dictionary = {}
	var best_rank: float = INF
	for prop: Dictionary in data.get("props", []) as Array:
		var kind: String = String(prop.get("kind", ""))
		if not WOOD_PILES.has(kind) or int(prop.get("level", 0)) != 0:
			continue
		var rect: Rect2i = prop["rect"] as Rect2i
		for y: int in range(rect.position.y - 1, rect.end.y + 1):
			for x: int in range(rect.position.x - 1, rect.end.x + 1):
				var cell: Vector2i = Vector2i(x, y)
				var metres: float = _metres(field, g, cell)
				if rect.has_point(cell) or metres < 0.0 or metres > JOB_PATH_M:
					continue
				var room: int = 0
				for dx: int in range(-2, 3):
					if g.people_can_walk(cell + Vector2i(dx, 0)):
						room += 1
				# Each rule outweighs every later one: the walk stays under 100 m.
				var rank: float = (2000.0 if g.indoor(cell) else 0.0) + (1000.0 if metres < JOB_MIN_M else 0.0) \
					+ 100.0 * (5 - room) + metres
				if rank < best_rank:
					best_rank = rank
					best = {"cell": cell, "name": String(WOOD_PILES[kind]) + " 작업 구역",
						"zone": rect.grow(2).intersection(Rect2i(0, 0, g.width, g.height))}
	return best


static func _food_site(data: Dictionary, seg: int, run_seed: int, field: PackedInt32Array) -> Dictionary:
	var g: FieldGrid = data["grid"] as FieldGrid
	var group: String = BuildingUses.group_of(String(data.get("place_id", "")))
	var candidates: Array[Dictionary] = []
	if group in ["freight", "first_stop"]:
		# The maps keep siding stock separately from the player's train cars.
		for wagon: Dictionary in data.get("wagons", []) as Array:
			candidates.append({"row": wagon, "food": "reefer", "rank": 0, "use": ""})
	for row: Dictionary in data.get("buildings", []) as Array:
		var use: String = BuildingUses.use_of(row)
		var food: String = ""
		var rank: int = 0
		if group == "factory" and use in ["store", "works"]:
			food = "canned"
		elif group in ["freight", "first_stop"] and use == "store":
			food = "wholesale"
			rank = 1
		elif group in ["houses", "office", "hospital", "church"] and use in ["store", "shop"]:
			food = "wholesale"
			var label: String = String(row.get("name", ""))
			rank = 0 if label.contains("도매") or label.contains("식료") or label.contains("창고") else 1
		elif use == "barn":
			food = "grain"
			rank = 2
		if not food.is_empty():
			candidates.append({"row": row, "food": food, "rank": rank, "use": use})
	var best: Dictionary = {}
	var best_rank: int = 3
	var best_distance: float = INF
	var best_use: String = ""
	for candidate: Dictionary in candidates:
		var rank: int = int(candidate["rank"])
		if rank > best_rank:
			continue
		var row: Dictionary = candidate["row"] as Dictionary
		var rect: Rect2i = row["rect"] as Rect2i
		var reached: Dictionary = _stand_paths(data, _building_stand(g, rect), field, MAX_PATH_M)
		var distance: float = float(reached["path_m"])
		if distance < 0.0 or (rank == best_rank and distance >= best_distance):
			continue
		var food: String = String(candidate["food"])
		best = {"kind": "food", "food": food, "rect": rect, "stand": reached["stand"],
			"level": 0, "building": -1 if food == "reefer" else int(row["id"]),
			"path_m": distance, "cap_segments": 1.5}
		best_rank = rank
		best_distance = distance
		best_use = String(candidate["use"])
	if not best.is_empty() and best_use == "store":
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = hash("%d:military:%d" % [run_seed, seg])
		if rng.randi_range(0, 11) == 0:
			best["food"] = "military"
	return best


## Doors contribute their orthogonal outside neighbours. A doorless footprint
## contributes its one-cell outside ring; blocked door fronts never use that fallback.
static func _building_stand(g: FieldGrid, rect: Rect2i) -> Array[Vector2i]:
	var around: Dictionary = {}
	var has_door: bool = false
	for door: Vector2i in g.doors:
		if not rect.has_point(door):
			continue
		if door.x != rect.position.x and door.x != rect.end.x - 1 \
				and door.y != rect.position.y and door.y != rect.end.y - 1:
			continue
		has_door = true
		for offset: Vector2i in CARDINAL:
			var cell: Vector2i = door + offset
			if not rect.has_point(cell) and g.people_can_walk(cell):
				around[cell] = true
	if not has_door:
		for x: int in range(rect.position.x - 1, rect.end.x + 1):
			for y: int in [rect.position.y - 1, rect.end.y]:
				var cell: Vector2i = Vector2i(x, y)
				if g.people_can_walk(cell):
					around[cell] = true
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in [rect.position.x - 1, rect.end.x]:
				var cell: Vector2i = Vector2i(x, y)
				if g.people_can_walk(cell):
					around[cell] = true
	var stand: Array[Vector2i] = []
	stand.assign(around.keys())
	return stand
