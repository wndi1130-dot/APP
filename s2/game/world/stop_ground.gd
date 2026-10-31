extends RefCounted
## Put the train beyond the village, keeping the finished town intact: the ground of
## decision 494's stop forms (the clock and arrivals of a form are game/sim/stop_form.gd).

const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const NightLights = preload("res://game/world/night_lights.gd")
const WorkSpots = preload("res://game/world/work_spots.gd")
const END_GAP: int = 12
const TREE_STEP: int = 9
const REMOTE_BAND: int = 24
const REMOTE_FOREST_EDGE: int = 6
## Anchors the train carries. One the map set itself moves with the train; one worked
## out from the train is worked out again.
const TRAIN_ANCHORS: Array[String] = ["horde_home", "horde_home_upper", "whistle", "engine"]
## The lights the train gives itself (the maps' cars and cab).
const TRAIN_LIGHTS: Array[String] = ["car_window", "firebox"]
## A siding's work yard is its map, as it is.
const FORMS: Array[String] = ["city", "edge", "remote", "siding"]


static func apply(data: Dictionary, form: String, run_seed: int, target_m: float = -1.0) -> Dictionary:
	if form.is_empty() or form == String(data.get("stop_form", "")):
		return data
	if form not in FORMS:
		push_warning("unknown stop form '%s'" % form)
		return data
	if String(data.get("stop_form", "")) == "edge":
		push_warning("stop form %s: the map already stands as an edge stop" % form)
		return data
	if String(data.get("stop_form", "")) == "remote":
		push_warning("stop form %s: the map already stands as a remote stop" % form)
		return data
	var out: Dictionary = data
	if form in ["edge", "remote"]:
		# The train keeps its row, so it can stand no nearer than the village's row.
		if target_m >= 0.0 and target_m < absf(_row_gap(data)):
			push_warning("stop form %s: %.0f m is nearer than the village's row, the stop stays a city one" % [form, target_m])
			# What was asked, so the loader's map and the field's agree it is done (FieldGame.shape_stop).
			data["stop_form_asked"] = form
			form = "city"
		else:
			out = _edge(data, run_seed, target_m) if form == "edge" else _outlying(data, run_seed, target_m, 400.0, 800.0, REMOTE_BAND)
			# The lights people left, planned again round where the crew now steps down.
			NightLights.follow(out)
	_set_village(out, form)
	# A remote strip cut off from the old village (a wall along the old border) would name
	# one of its own cells the village: the stop stays a city one instead.
	if out.has("stop_old_ground") and not (out.get("buildings", []) as Array).is_empty() \
			and (float(out["walk_to_village_m"]) < 0.0 or not (out["stop_old_ground"] as Rect2i).has_point(out["village_middle"])):
		push_warning("stop form %s: the walk from the train does not reach the village, the stop stays a city one" % form)
		data["stop_form_asked"] = form
		_set_village(data, "city")
		return data
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
	return _outlying(data, run_seed, target_m, 150.0, 300.0)


## The same seeded train move for both outlying forms; only remote ground is narrowed.
static func _outlying(data: Dictionary, run_seed: int, target_m: float, minimum_m: float, maximum_m: float, band: int = 0) -> Dictionary:
	var old: FieldGrid = data["grid"]
	var train: Rect2i = data["train"]
	var middle: Vector2 = village_middle(data)
	var center: Vector2 = Vector2(train.position) + Vector2(train.size) * 0.5
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%d:stop_form:%s" % [run_seed, String(data.get("place_id", ""))])
	var dy: float = center.y - middle.y
	# A seeded walk-off is never nearer than the village's row either.
	var lowest: float = maxf(minimum_m, absf(dy) + 1.0)
	var highest: float = maxf(lowest, maximum_m)
	if target_m < 0.0 and lowest > maximum_m:
		push_warning("stop form %s: the village's row is %.0f m off the train's" % ["remote" if band > 0 else "edge", absf(dy)])
	var distance: float = target_m if target_m >= 0.0 else rng.randf_range(lowest, highest)
	var direction: int = 1 if middle.x <= center.x else -1
	var along: float = sqrt(maxf(0.0, distance * distance - dy * dy))
	var empty_length: int = 0
	if data.get("buildings", []).is_empty():
		# With no houses the fallback middle moves by half the added width.
		empty_length = maxi(1, ceili(2.0 * along + float(train.size.x + 2 * END_GAP + 2)) - old.width)
		middle.x += float(direction * empty_length) * 0.5
	var x: int = roundi(middle.x + float(direction) * along - float(train.size.x) * 0.5)
	if target_m < 0.0:
		var rounded: float = Vector2(float(x) + float(train.size.x) * 0.5 - middle.x, dy).length()
		if rounded < lowest:
			x += direction
		elif rounded > highest:
			x -= direction
	var dx: int = x - train.position.x
	var length: int = maxi(1, x + train.size.x + END_GAP - old.width) if direction > 0 else maxi(1, END_GAP - x)
	if empty_length > 0:
		length = empty_length
	var left: int = length if direction < 0 else 0
	# Which anchors the map set itself, told apart from the worked-out ones on the map as it was.
	var own: Dictionary = {}
	var was_worked: Dictionary = FieldMaps.anchors(data)
	var was_anchors: Dictionary = data.get("anchors", {})
	for key: String in was_anchors:
		own[key] = not was_worked.has(key) or was_anchors[key] != was_worked[key]
	# A finished map's paths are right: grow carries every floor's over (map_shift.gd), and
	# after the train moves only the cells whose solid changed are refreshed (_move_train,
	# _add_trees).
	var out: Dictionary = MapShift.grow(data, left, 0, length - left, 0, true, true)
	# Its size is a Vector2i too: grow can shift a stale cache key into a match.
	out.erase("_edge_plan")
	if band > 0:
		# Where the old map now lies, for apply's check that the walk reaches its village. A
		# Rect2i, so a later shift (the side path's) moves it with the cells.
		out["stop_old_ground"] = Rect2i(left, 0, old.width, old.height)
	var g: FieldGrid = out["grid"]
	var added: Rect2i = Rect2i(0 if left > 0 else old.width, 0, length, old.height)
	var old_border: int = left if left > 0 else old.width - 1
	var new_border: int = 0 if left > 0 else g.width - 1
	_extend_ground(g, old, added, 0 if left > 0 else old.width - 1)
	var strip: Rect2i = Rect2i()
	if band > 0:
		strip = _remote_strip(out, old, added, 0 if left > 0 else old.width - 1, band)
	var moved_out: Dictionary = _move_entries_out(out, old_border, new_border, strip)
	var floored: Array = _move_train(out, Vector2i(dx, 0))
	if band > 0:
		_remote_band(out, added, strip)
		_add_trees(out, strip, rng)
		_add_forest_trees(out, strip, rng)
	else:
		_add_trees(out, added, rng)
	# The old and new footprints, the trees and the platform's moved floor.
	var was_at: Rect2i = Rect2i((data["train"] as Rect2i).position + Vector2i(left, 0), (data["train"] as Rect2i).size)
	for c: Vector2i in _cells(was_at) + _cells(out["train"]) + out["trees"] + floored:
		g.refresh_cell(c)
	out["boarding"] = [out["platform"]] + FieldMaps.side_strips(out, out["platform"])
	out["unloading"] = [out["unload"]] + FieldMaps.side_strips(out, out["unload"])
	var anchors: Dictionary = out.get("anchors", {})
	var worked: Dictionary = FieldMaps.anchors(out)
	for key: String in TRAIN_ANCHORS:
		if own.get(key, false):
			anchors[key] += Vector2i(dx, 0)
			# One the map set off the strip's rows would stand in the deep forest: worked out again.
			if band > 0 and key != "horde_home_upper" and _in_deep_forest(out, anchors[key]):
				if worked.has(key):
					anchors[key] = worked[key]
				else:
					anchors.erase(key)
		elif worked.has(key):
			anchors[key] = worked[key]
		else:
			anchors.erase(key)
	# A way out the map set goes out with its entry; a worked-out one is worked out again.
	if own.get("flee_exit", false):
		var flee: Vector2i = anchors["flee_exit"]
		if moved_out.has(flee):
			anchors["flee_exit"] = moved_out[flee]
		elif flee.x == old_border and (band == 0 or (flee.y >= strip.position.y and flee.y < strip.end.y)):
			anchors["flee_exit"] = Vector2i(new_border, flee.y)
	elif worked.has("flee_exit"):
		anchors["flee_exit"] = worked["flee_exit"]
	out["anchors"] = anchors
	return out


static func _in_deep_forest(data: Dictionary, c: Vector2i) -> bool:
	for rect: Rect2i in data.get("deep_forest", []):
		if rect.has_point(c):
			return true
	return false


## Every cell of `r`, in the grid's own order.
static func _cells(r: Rect2i) -> Array:
	var out: Array = []
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			out.append(Vector2i(x, y))
	return out


## Only open rail rows touching the train's rows widen the strip's core. The train's
## carried cells and rectangles keep their rows too; detached roads and rails do not.
static func _remote_strip(data: Dictionary, old: FieldGrid, added: Rect2i, edge_x: int, band: int) -> Rect2i:
	var train: Rect2i = data["train"]
	var top: int = train.position.y
	var bottom: int = train.end.y
	while top > 0:
		var edge: Vector2i = Vector2i(edge_x, top - 1)
		if old.solid_at(edge) != FieldGrid.Solid.NONE or old.floor_at(edge) != FieldGrid.Floor.RAIL:
			break
		top -= 1
	while bottom < old.height:
		var edge: Vector2i = Vector2i(edge_x, bottom)
		if old.solid_at(edge) != FieldGrid.Solid.NONE or old.floor_at(edge) != FieldGrid.Floor.RAIL:
			break
		bottom += 1
	var rects: Array[Rect2i] = []
	for car: Dictionary in data.get("train_cars", []):
		rects.append(car["rect"])
	for key: String in ["platform", "unload"]:
		var rect: Rect2i = data.get(key, train.grow(FieldMaps.BY_TRAIN))
		if rect.intersects(train.grow(3)):
			rects.append(rect)
	for rect: Rect2i in rects:
		top = mini(top, rect.position.y)
		bottom = maxi(bottom, rect.end.y)
	var carried: Array = []
	for doors: Array in data.get("train_doors", {}).values():
		carried.append_array(doors)
	for key: String in ["train_door", "squad"]:
		carried.append_array(data.get("spawns", {}).get(key, []))
	for light: Dictionary in data.get("lights", []):
		if String(light.get("kind", "")) in TRAIN_LIGHTS or (int(light.get("level", 0)) == 0 and train.has_point(light["cell"])):
			carried.append(light["cell"])
	for cell: Vector2i in data.get("barricade_slots", []):
		if train.grow(3).has_point(cell):
			carried.append(cell)
	for crossing: Dictionary in data.get("crossings", []):
		carried.append_array(crossing["cells"])
	for cell: Vector2i in carried:
		top = mini(top, cell.y)
		bottom = maxi(bottom, cell.y + 1)
	top = maxi(added.position.y, top - band)
	bottom = mini(added.end.y, bottom + band)
	return Rect2i(added.position.x, top, added.size.x, bottom - top)


## Only the added ground outside the strip becomes forest; other floors stay intact.
static func _remote_band(data: Dictionary, added: Rect2i, strip: Rect2i) -> void:
	var g: FieldGrid = data["grid"]
	var top: int = strip.position.y
	var bottom: int = strip.end.y
	var forest: Array[Rect2i] = []
	if top > added.position.y:
		forest.append(Rect2i(added.position, Vector2i(added.size.x, top - added.position.y)))
	if bottom < added.end.y:
		forest.append(Rect2i(added.position.x, bottom, added.size.x, added.end.y - bottom))
	data["deep_forest"] = forest
	for rect: Rect2i in forest:
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				var i: int = y * g.width + x
				g.solid[i] = FieldGrid.Solid.BLOCK
				g.floor[i] = FieldGrid.Floor.SNOW
				g.building[i] = -1
				g.opq[i] = 1
				g.walk_people[i] = 0
				g.walk_dead[i] = 0
		# These cells all changed the same way: keep both paths in step in one call.
		g.people_path.fill_solid_region(rect, true)
		g.dead_path.fill_solid_region(rect, true)
		g.revision += 1


## Only the first six metres of blocked forest carry trees, two or three cells apart.
## Spruce is the existing field-tree model (PropKinds.candidates).
static func _add_forest_trees(data: Dictionary, strip: Rect2i, rng: RandomNumberGenerator) -> void:
	var trees: Array = data.get("trees", [])
	var props: Array = data.get("props", [])
	for rect: Rect2i in data.get("deep_forest", []):
		var above: bool = rect.end.y == strip.position.y
		var depth: int = mini(REMOTE_FOREST_EDGE, rect.size.y)
		var row: int = rng.randi_range(0, 1)
		while row < depth:
			var y: int = rect.end.y - 1 - row if above else rect.position.y + row
			var x: int = rect.position.x + rng.randi_range(0, 2)
			while x < rect.end.x:
				var c: Vector2i = Vector2i(x, y)
				trees.append(c)
				props.append({"kind": "spruce", "rect": Rect2i(c, Vector2i.ONE), "facing": rng.randi_range(0, 3), "level": 0})
				x += rng.randi_range(2, 3)
			row += rng.randi_range(2, 3)
	data["trees"] = trees
	data["props"] = props


static func _extend_ground(g: FieldGrid, old: FieldGrid, added: Rect2i, edge_x: int) -> void:
	for y: int in range(old.height):
		var edge: Vector2i = Vector2i(edge_x, y)
		var floor_kind: int = old.floor_at(edge)
		if old.solid_at(edge) != FieldGrid.Solid.NONE or floor_kind not in [FieldGrid.Floor.RAIL, FieldGrid.Floor.ROAD]:
			continue
		for x: int in range(added.position.x, added.end.x):
			g.floor[g.index(Vector2i(x, y))] = floor_kind


## The dead still come from beyond the map (map_ring.gd does the same): a ground entry on
## the grown side moves out, except where the remote forest starts. Old cell -> new cell.
static func _move_entries_out(data: Dictionary, old_border: int, new_border: int, strip: Rect2i = Rect2i()) -> Dictionary:
	var moved: Dictionary = {}
	for id in data.get("entries", {}):
		if data.get("manholes", {}).has(id) or int(data.get("entry_levels", {}).get(id, 0)) != 0:
			continue
		var cells: Array = data["entries"][id]
		for i: int in range(cells.size()):
			var c: Vector2i = cells[i]
			if c.x == old_border and (strip.size.y == 0 or (c.y >= strip.position.y and c.y < strip.end.y)):
				moved[c] = Vector2i(new_border, c.y)
				cells[i] = moved[c]
	return moved


## Moves the train and what it carries; returns the cells whose floor it repainted (the
## platform's, old and new).
static func _move_train(data: Dictionary, offset: Vector2i) -> Array:
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
	# The platform by the train goes with it, its painted floor too.
	var platform_cells: Dictionary = {}
	for key: String in ["platform", "unload"]:
		var rect: Rect2i = data.get(key, train.grow(FieldMaps.BY_TRAIN))
		if rect.intersects(train.grow(3)):
			for y: int in range(rect.position.y, rect.end.y):
				for x: int in range(rect.position.x, rect.end.x):
					var c: Vector2i = Vector2i(x, y)
					if g.inside(c) and g.floor_at(c) == FieldGrid.Floor.PLATFORM:
						platform_cells[c] = true
			rect.position += offset
		data[key] = rect
	var floored: Array = []
	for c: Vector2i in platform_cells:
		g.floor[g.index(c)] = FieldGrid.Floor.SNOW
		floored.append(c)
	for c: Vector2i in platform_cells:
		var to: Vector2i = c + offset
		if g.inside(to) and g.solid_at(to) == FieldGrid.Solid.NONE and g.floor_at(to) != FieldGrid.Floor.RAIL:
			g.floor[g.index(to)] = FieldGrid.Floor.PLATFORM
			floored.append(to)
	for light: Dictionary in data.get("lights", []):
		if String(light.get("kind", "")) in TRAIN_LIGHTS or (int(light.get("level", 0)) == 0 and train.has_point(light["cell"])):
			light["cell"] += offset
	var slots: Array = data.get("barricade_slots", [])
	for i: int in range(slots.size()):
		if train.grow(3).has_point(slots[i]):
			slots[i] += offset
	for crossing: Dictionary in data.get("crossings", []):
		_move_cells(crossing["cells"], offset)
	return floored


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


## The keys other strands read: the form, the village's cell and the walk there from the
## train doors. The cell is the outdoor one nearest the buildings' middle that the doors
## reach on foot within the form's limit (the middle often falls in a hall or a locked
## yard); with none, the middle's own cell and -1 m.
static func _set_village(data: Dictionary, form: String) -> void:
	var g: FieldGrid = data["grid"]
	var middle: Vector2 = village_middle(data)
	var limit_m: float = 1000.0 if form == "remote" else 600.0
	var field: PackedInt32Array = WorkSpots.walk_field(data, limit_m)
	var best: Vector2i = Vector2i(-1, -1)
	var best_d: float = INF
	for y: int in range(g.height):
		for x: int in range(g.width):
			var i: int = y * g.width + x
			if field[i] < 0 or g.building[i] >= 0:
				continue
			var d: float = Vector2(float(x) + 0.5, float(y) + 0.5).distance_squared_to(middle)
			if d < best_d:
				best_d = d
				best = Vector2i(x, y)
	data["stop_form"] = form
	if best.x < 0:
		data["village_middle"] = Vector2i(floori(middle.x), floori(middle.y))
		data["walk_to_village_m"] = -1.0
	else:
		data["village_middle"] = best
		data["walk_to_village_m"] = float(field[g.index(best)]) / float(WorkSpots.STEP)
