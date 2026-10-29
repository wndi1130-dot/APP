extends RefCounted
## Put the train beyond the village, keeping the finished town intact.

const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const WorkSpots = preload("res://game/world/work_spots.gd")
const END_GAP: int = 12
const TREE_STEP: int = 9
const TRAIN_ANCHORS: Array[String] = ["horde_home", "horde_home_upper", "whistle", "engine", "flee_exit"]


static func apply(data: Dictionary, form: String, run_seed: int, target_m: float = -1.0) -> Dictionary:
	if form.is_empty():
		return data
	if form != "city" and form != "edge":
		push_warning("unknown stop form '%s'" % form)
		return data
	if form == "edge" and data.get("stop_form", "") == "edge":
		return data
	# The train keeps its row, so it can stand no nearer than the village's row.
	if form == "edge" and target_m >= 0.0 and target_m < absf(_row_gap(data)):
		push_warning("stop form edge: %.0f m is nearer than the village's row" % target_m)
		return data
	var out: Dictionary = data
	if form == "edge":
		out = _edge(data, run_seed, target_m)
	_set_village(out, form)
	return out


static func village_middle(data: Dictionary) -> Vector2:
	var weighted: Vector2 = Vector2.ZERO
	var area: float = 0.0
	for building: Dictionary in data.get("buildings", []):
		var rect: Rect2i = building["rect"]
		var weight: float = float(rect.size.x * rect.size.y)
		weighted += (Vector2(rect.position) + Vector2(rect.size) * 0.5) * weight
		area += weight
	if area > 0.0:
		return weighted / area
	var g: FieldGrid = data["grid"]
	return Vector2(g.width, g.height) * 0.5


static func _row_gap(data: Dictionary) -> float:
	var train: Rect2i = data["train"]
	return float(train.position.y) + float(train.size.y) * 0.5 - village_middle(data).y


static func _edge(data: Dictionary, run_seed: int, target_m: float) -> Dictionary:
	var old: FieldGrid = data["grid"]
	var train: Rect2i = data["train"]
	var middle: Vector2 = village_middle(data)
	var center: Vector2 = Vector2(train.position) + Vector2(train.size) * 0.5
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%d:stop_form:%s" % [run_seed, String(data.get("place_id", ""))])
	var distance: float = target_m if target_m >= 0.0 else rng.randf_range(150.0, 300.0)
	var direction: int = 1 if middle.x <= center.x else -1
	var dy: float = center.y - middle.y
	var along: float = sqrt(maxf(0.0, distance * distance - dy * dy))
	var empty_length: int = 0
	if data.get("buildings", []).is_empty():
		# With no houses the fallback middle moves by half the added width.
		empty_length = maxi(1, ceili(2.0 * along + float(train.size.x + 2 * END_GAP + 2)) - old.width)
		middle.x += float(direction * empty_length) * 0.5
	var x: int = roundi(middle.x + float(direction) * along - float(train.size.x) * 0.5)
	if target_m < 0.0:
		var rounded: float = Vector2(float(x) + float(train.size.x) * 0.5 - middle.x, dy).length()
		if rounded < 150.0:
			x += direction
		elif rounded > 300.0:
			x -= direction
	var dx: int = x - train.position.x
	var length: int = maxi(1, x + train.size.x + END_GAP - old.width) if direction > 0 else maxi(1, END_GAP - x)
	if empty_length > 0:
		length = empty_length
	var left: int = length if direction < 0 else 0
	# grow refreshes the other floors; the ground is refreshed once, after the train moves.
	var out: Dictionary = MapShift.grow(data, left, 0, length - left, 0, false)
	# Its size is a Vector2i too: grow can shift a stale cache key into a match.
	out.erase("_edge_plan")
	var added: Rect2i = Rect2i(0 if left > 0 else old.width, 0, length, old.height)
	_extend_ground(out["grid"], old, added, 0 if left > 0 else old.width - 1)
	_move_train(out, Vector2i(dx, 0))
	_add_trees(out, added, rng)
	(out["grid"] as FieldGrid).refresh_paths()
	out["boarding"] = [out["platform"]] + FieldMaps.side_strips(out, out["platform"])
	out["unloading"] = [out["unload"]] + FieldMaps.side_strips(out, out["unload"])
	var anchors: Dictionary = out.get("anchors", {})
	var worked: Dictionary = FieldMaps.anchors(out)
	for key: String in TRAIN_ANCHORS:
		if worked.has(key):
			anchors[key] = worked[key]
		else:
			anchors.erase(key)
	out["anchors"] = anchors
	return out


static func _extend_ground(g: FieldGrid, old: FieldGrid, added: Rect2i, edge_x: int) -> void:
	for y: int in range(old.height):
		var edge: Vector2i = Vector2i(edge_x, y)
		var floor_kind: int = old.floor_at(edge)
		if old.solid_at(edge) != FieldGrid.Solid.NONE or floor_kind not in [FieldGrid.Floor.RAIL, FieldGrid.Floor.ROAD]:
			continue
		for x: int in range(added.position.x, added.end.x):
			g.floor[g.index(Vector2i(x, y))] = floor_kind


static func _move_train(data: Dictionary, offset: Vector2i) -> void:
	var g: FieldGrid = data["grid"]
	var train: Rect2i = data["train"]
	var moved: Rect2i = Rect2i(train.position + offset, train.size)
	var solids: PackedByteArray = PackedByteArray()
	var floors: PackedByteArray = PackedByteArray()
	# Save the whole footprint before clearing it, even when the two overlap.
	for y: int in range(train.position.y, train.end.y):
		for x: int in range(train.position.x, train.end.x):
			var c: Vector2i = Vector2i(x, y)
			solids.append(g.solid_at(c))
			floors.append(g.floor_at(c))
	for y: int in range(train.position.y, train.end.y):
		var rail: Vector2i = _open_rail(g, train, y)
		for x: int in range(train.position.x, train.end.x):
			var i: int = g.index(Vector2i(x, y))
			g.solid[i] = g.solid_at(rail)
			g.floor[i] = g.floor_at(rail)
	var at: int = 0
	for y: int in range(moved.position.y, moved.end.y):
		for x: int in range(moved.position.x, moved.end.x):
			var i: int = g.index(Vector2i(x, y))
			g.solid[i] = solids[at]
			g.floor[i] = floors[at]
			at += 1
	data["train"] = moved
	for car: Dictionary in data.get("train_cars", []):
		var rect: Rect2i = car["rect"]
		car["rect"] = Rect2i(rect.position + offset, rect.size)
	for cells: Array in data.get("train_doors", {}).values():
		_move_cells(cells, offset)
	var spawns: Dictionary = data.get("spawns", {})
	for key: String in ["train_door", "squad"]:
		_move_cells(spawns.get(key, []), offset)
	for key: String in ["platform", "unload"]:
		var rect: Rect2i = data.get(key, train.grow(FieldMaps.BY_TRAIN))
		if rect.intersects(train.grow(3)):
			rect.position += offset
		data[key] = rect
	for light: Dictionary in data.get("lights", []):
		if int(light.get("level", 0)) == 0 and train.grow(1).has_point(light["cell"]):
			light["cell"] += offset
	var slots: Array = data.get("barricade_slots", [])
	for i: int in range(slots.size()):
		if train.grow(3).has_point(slots[i]):
			slots[i] += offset
	for crossing: Dictionary in data.get("crossings", []):
		_move_cells(crossing["cells"], offset)


## The uncovered track on this row is the ground beneath the train.
static func _open_rail(g: FieldGrid, train: Rect2i, y: int) -> Vector2i:
	for step: int in range(g.width):
		for x: int in [train.position.x - step - 1, train.end.x + step]:
			var c: Vector2i = Vector2i(x, y)
			if g.inside(c) and g.floor_at(c) == FieldGrid.Floor.RAIL and g.solid_at(c) == FieldGrid.Solid.NONE:
				return c
	assert(false, "a train row needs uncovered walkable rail")
	return Vector2i(train.position.x - 1, y)


static func _move_cells(cells: Array, offset: Vector2i) -> void:
	for i: int in range(cells.size()):
		cells[i] += offset


static func _add_trees(data: Dictionary, added: Rect2i, rng: RandomNumberGenerator) -> void:
	var g: FieldGrid = data["grid"]
	var rail_rows: Array[int] = []
	for y: int in range(g.height):
		if g.floor_at(Vector2i(added.position.x, y)) == FieldGrid.Floor.RAIL:
			rail_rows.append(y)
	var trees: Array = data.get("trees", [])
	var props: Array = data.get("props", [])
	for y: int in range(3, g.height - 3, TREE_STEP):
		for x: int in range(added.position.x + 3, added.end.x - 3, TREE_STEP):
			var c: Vector2i = Vector2i(x + rng.randi_range(-1, 1), y + rng.randi_range(-1, 1))
			if rng.randf() >= 0.55 or not _tree_clear(data, added, c, rail_rows):
				continue
			g.set_solid(c, FieldGrid.Solid.BLOCK)
			trees.append(c)
			props.append({"kind": "bare_tree", "rect": Rect2i(c, Vector2i.ONE), "facing": rng.randi_range(0, 3), "level": 0})
	data["trees"] = trees
	data["props"] = props


static func _tree_clear(data: Dictionary, added: Rect2i, c: Vector2i, rail_rows: Array[int]) -> bool:
	for y: int in rail_rows:
		if absi(c.y - y) <= 3:
			return false
	var patch: Rect2i = Rect2i(c - Vector2i.ONE * 2, Vector2i.ONE * 5)
	if not added.encloses(patch):
		return false
	for key: String in ["platform", "unload"]:
		var rect: Rect2i = data[key]
		if rect.intersects(patch):
			return false
	for cell: Vector2i in data.get("spawns", {}).get("squad", []):
		if patch.has_point(cell):
			return false
	var g: FieldGrid = data["grid"]
	for y: int in range(patch.position.y, patch.end.y):
		for x: int in range(patch.position.x, patch.end.x):
			var at: Vector2i = Vector2i(x, y)
			if g.solid_at(at) != FieldGrid.Solid.NONE or g.floor_at(at) != FieldGrid.Floor.SNOW:
				return false
	return true


static func _set_village(data: Dictionary, form: String) -> void:
	var g: FieldGrid = data["grid"]
	var middle: Vector2 = village_middle(data)
	var c: Vector2i = g.nearest_walkable(Vector2i(floori(middle.x), floori(middle.y)), false, 12)
	var field: PackedInt32Array = WorkSpots.walk_field(data, 600.0)
	var steps: int = field[g.index(c)] if g.inside(c) else -1
	data["stop_form"] = form
	data["village_middle"] = c
	data["walk_to_village_m"] = -1.0 if steps < 0 else float(steps) / float(WorkSpots.STEP)
