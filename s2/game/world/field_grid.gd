extends RefCounted
## 1m grid for one stop map: solids, floors, rooms, zones, doors, windows,
## two path grids (people open closed doors; the dead do not) and line of sight.
## A map has one grid per level (ground 0, upper floors 1 and 2, cellar −1);
## upper levels are AIR outside the buildings: nothing to stand on, nothing
## in the way of the eye.

enum Solid { NONE, WALL, BLOCK, LOW, DOOR, WINDOW, AIR }
enum Floor { SNOW, ROAD, PLATFORM, WOOD, RAIL, DEEP_SNOW, ICE, GRAVEL }
const FLOOR_SOUND: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.5, 0.5, 1.0, 1.0]
const FLOOR_SPEED: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0, 0.7, 1.0, 1.0]

var width: int
var height: int
var solid: PackedByteArray
var floor: PackedByteArray
var building: PackedInt32Array
var zone: PackedStringArray
var doors: Dictionary = {}    # Vector2i -> {"state": open|closed|locked|broken, "hp": int, "building": int, "key": String}
var windows: Dictionary = {}  # Vector2i -> {"broken": bool, "glass": bool, "building": int}
var people_path := AStarGrid2D.new()
var dead_path := AStarGrid2D.new()
var revision: int = 0         # bumps when doors or windows change
var opq: PackedByteArray      # 1 = blocks sight; kept in step with solid, doors
var _stamp: PackedInt32Array  # visible_cells dedupe marks
var _stamp_n: int = 0
var walk_people: PackedByteArray  # 1 = walkable; valid once refresh_paths ran
var walk_dead: PackedByteArray
var _walk_ready := false


func _init(w: int, h: int) -> void:
	width = w
	height = h
	solid.resize(w * h)
	floor.resize(w * h)
	building.resize(w * h)
	building.fill(-1)
	zone.resize(w * h)
	opq.resize(w * h)
	walk_people.resize(w * h)
	walk_dead.resize(w * h)
	_stamp.resize(w * h)
	for grid in [people_path, dead_path]:
		grid.region = Rect2i(0, 0, w, h)
		grid.cell_size = Vector2(1, 1)
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.update()


func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func index(c: Vector2i) -> int:
	return c.y * width + c.x


static func cell_of(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x), floori(at.z))


static func center(c: Vector2i) -> Vector3:
	return Vector3(c.x + 0.5, 0.0, c.y + 0.5)


func solid_at(c: Vector2i) -> int:
	return solid[index(c)] if inside(c) else Solid.WALL


func floor_at(c: Vector2i) -> int:
	return floor[index(c)] if inside(c) else Floor.SNOW


func building_at(c: Vector2i) -> int:
	return building[index(c)] if inside(c) else -1


func zone_at(c: Vector2i) -> String:
	return zone[index(c)] if inside(c) else ""


func indoor(c: Vector2i) -> bool:
	return building_at(c) >= 0


## People may walk through closed (unlocked) doors; they open them on the way.
func people_can_walk(c: Vector2i) -> bool:
	if not inside(c):
		return false
	match solid[index(c)]:
		Solid.NONE:
			return true
		Solid.DOOR:
			return doors[c]["state"] != "locked"
		Solid.WINDOW:
			return windows[c]["broken"]
	return false


func dead_can_walk(c: Vector2i) -> bool:
	if not inside(c):
		return false
	match solid[index(c)]:
		Solid.NONE:
			return true
		Solid.DOOR:
			return doors[c]["state"] == "open" or doors[c]["state"] == "broken"
		Solid.WINDOW:
			return windows[c]["broken"]
	return false


## Physical blocking right now (closed doors block everyone until opened).
func blocks_body(c: Vector2i) -> bool:
	if not inside(c):
		return true
	match solid[index(c)]:
		Solid.NONE:
			return false
		Solid.DOOR:
			return not (doors[c]["state"] == "open" or doors[c]["state"] == "broken")
		Solid.WINDOW:
			return not windows[c]["broken"]
	return true


func opaque(c: Vector2i) -> bool:
	if not inside(c):
		return true
	return opq[c.y * width + c.x] == 1


func _opaque_now(c: Vector2i) -> bool:
	match solid[index(c)]:
		Solid.WALL, Solid.BLOCK:
			return true
		Solid.DOOR:
			return not doors.has(c) or doors[c]["state"] == "closed" or doors[c]["state"] == "locked"
	return false


func set_solid(c: Vector2i, kind: int) -> void:
	if inside(c):
		solid[index(c)] = kind
		opq[index(c)] = 1 if kind == Solid.WALL or kind == Solid.BLOCK or kind == Solid.DOOR else 0


func refresh_paths() -> void:
	for y in range(height):
		for x in range(width):
			var c := Vector2i(x, y)
			_cache_cell(c)
			people_path.set_point_solid(c, walk_people[y * width + x] == 0)
			dead_path.set_point_solid(c, walk_dead[y * width + x] == 0)
			# Deep snow and ice cost more so people route around them when cheap.
			var cost := 1.0
			if floor[index(c)] == Floor.DEEP_SNOW:
				cost = 1.6
			people_path.set_point_weight_scale(c, cost)
	_walk_ready = true
	revision += 1


func _cache_cell(c: Vector2i) -> void:
	var i := index(c)
	opq[i] = 1 if _opaque_now(c) else 0
	walk_people[i] = 1 if people_can_walk(c) else 0
	walk_dead[i] = 1 if dead_can_walk(c) else 0


func refresh_cell(c: Vector2i) -> void:
	if inside(c):
		_cache_cell(c)
	people_path.set_point_solid(c, not people_can_walk(c))
	dead_path.set_point_solid(c, not dead_can_walk(c))
	revision += 1


func set_door_state(c: Vector2i, state: String) -> void:
	if doors.has(c):
		doors[c]["state"] = state
		refresh_cell(c)


func break_window(c: Vector2i) -> void:
	if windows.has(c):
		windows[c]["broken"] = true
		windows[c]["glass"] = true
		refresh_cell(c)


## Nearest walkable cell for people around c (spiral), or c itself.
func nearest_walkable(c: Vector2i, for_dead: bool = false, max_r: int = 6) -> Vector2i:
	for r in range(max_r + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if (dead_can_walk(n) if for_dead else people_can_walk(n)):
					return n
	return c


func find_path(from: Vector3, to: Vector3, for_dead: bool = false) -> PackedVector3Array:
	var grid := dead_path if for_dead else people_path
	var a := nearest_walkable(cell_of(from), for_dead, 2)
	var b := nearest_walkable(cell_of(to), for_dead)
	var result := PackedVector3Array()
	if not inside(a) or not inside(b) or grid.is_point_solid(a) or grid.is_point_solid(b):
		return result
	var cells := grid.get_id_path(a, b, true)
	# Drop the start cell and smooth straight runs by line checks.
	var points: Array[Vector2i] = []
	for p in cells:
		points.append(p)
	if points.size() > 0 and points[0] == a:
		points.remove_at(0)
	var smoothed: Array[Vector2i] = []
	var anchor := a
	var i := 0
	while i < points.size():
		var j := i
		while j + 1 < points.size() and clear_walk(anchor, points[j + 1], for_dead):
			j += 1
		smoothed.append(points[j])
		anchor = points[j]
		i = j + 1
	for p in smoothed:
		result.append(center(p))
	if result.size() > 0 and cell_of(to) == b:
		result[result.size() - 1] = Vector3(to.x, 0, to.z)
	return result


## Straight walk between two cells stays on walkable cells (thick line check).
func clear_walk(a: Vector2i, b: Vector2i, for_dead: bool) -> bool:
	var from := Vector2(a) + Vector2(0.5, 0.5)
	var to := Vector2(b) + Vector2(0.5, 0.5)
	var steps := int(ceil(from.distance_to(to) * 3.0))
	var walk := walk_dead if for_dead else walk_people
	for s in range(steps + 1):
		var p := from.lerp(to, float(s) / maxf(1, steps))
		for k in range(4):
			var cx := floori(p.x + (0.3 if k & 1 else -0.3))
			var cy := floori(p.y + (0.3 if k & 2 else -0.3))
			if _walk_ready:
				if cx < 0 or cy < 0 or cx >= width or cy >= height or walk[cy * width + cx] == 0:
					return false
			elif not (dead_can_walk(Vector2i(cx, cy)) if for_dead else people_can_walk(Vector2i(cx, cy))):
				return false
	return true


## Line of sight between cells (Bresenham, blocker cell itself is seen).
func line_clear(a: Vector2i, b: Vector2i) -> bool:
	var x := a.x
	var y := a.y
	var dx := absi(b.x - x)
	var dy := absi(b.y - y)
	var sx := 1 if x < b.x else -1
	var sy := 1 if y < b.y else -1
	var err := dx - dy
	while x != b.x or y != b.y:
		var px := x
		var py := y
		var e2 := err * 2
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
		if x < 0 or y < 0 or x >= width or y >= height:
			return false
		if x != px and y != py and opq[py * width + x] == 1 and opq[y * width + px] == 1:
			return false
		if x == b.x and y == b.y:
			return true
		if opq[y * width + x] == 1:
			return false
	return true


## A cell that stops a blow: wall, block, shut door, whole window. Low cover
## and open air do not; glass lets the eye through but not an axe.
func stops_melee(c: Vector2i) -> bool:
	match solid_at(c):
		Solid.WALL, Solid.BLOCK:
			return true
		Solid.DOOR, Solid.WINDOW:
			return blocks_body(c)
	return false


## Nothing that stops a blow between two cells (same Bresenham as line_clear).
func body_line_clear(a: Vector2i, b: Vector2i) -> bool:
	var x := a.x
	var y := a.y
	var dx := absi(b.x - x)
	var dy := absi(b.y - y)
	var sx := 1 if x < b.x else -1
	var sy := 1 if y < b.y else -1
	var err := dx - dy
	while x != b.x or y != b.y:
		var px := x
		var py := y
		var e2 := err * 2
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
		if x != px and y != py and stops_melee(Vector2i(x, py)) and stops_melee(Vector2i(px, y)):
			return false
		if stops_melee(Vector2i(x, y)):
			return false
	return true


## Visible cells within radius of origin; result maps cell index -> true.
## Slow reference (every cell gets its own line); kept for tests.
func visible_from(origin: Vector2i, radius: int) -> Dictionary:
	var result: Dictionary = {}
	var r2 := radius * radius
	for y in range(maxi(0, origin.y - radius), mini(height, origin.y + radius + 1)):
		for x in range(maxi(0, origin.x - radius), mini(width, origin.x + radius + 1)):
			var c := Vector2i(x, y)
			if (c - origin).length_squared() <= r2 and line_clear(origin, c):
				result[index(c)] = true
	return result


## Fast sight: rays from origin to every cell on the square's rim, walked
## until a blocker (which is itself seen). Rays outside the cone only reach
## `near` cells. Returns cell index -> true.
func visible_cells(origin: Vector2i, radius: int, forward: Vector2, cone_cos: float, near: float) -> Dictionary:
	var result: Dictionary = {}
	if not inside(origin):
		return result
	_stamp_n += 1
	var r2 := radius * radius
	var near2 := near * near
	var oi := origin.y * width + origin.x
	result[oi] = true
	_stamp[oi] = _stamp_n
	var rim: Array[Vector2i] = []
	for i in range(-radius, radius + 1):
		rim.append(Vector2i(i, -radius))
		rim.append(Vector2i(i, radius))
	for i in range(-radius + 1, radius):
		rim.append(Vector2i(-radius, i))
		rim.append(Vector2i(radius, i))
	for d in rim:
		var dir := Vector2(d).normalized()
		var reach2 := float(r2) if forward == Vector2.ZERO or dir.dot(forward) >= cone_cos else near2
		_ray(origin, origin + d, reach2, result)
	return result


func _ray(a: Vector2i, b: Vector2i, reach2: float, result: Dictionary) -> void:
	var x := a.x
	var y := a.y
	var dx := absi(b.x - x)
	var dy := absi(b.y - y)
	var sx := 1 if x < b.x else -1
	var sy := 1 if y < b.y else -1
	var err := dx - dy
	while x != b.x or y != b.y:
		var px := x
		var py := y
		var e2 := err * 2
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
		if x < 0 or y < 0 or x >= width or y >= height:
			return
		var ox := x - a.x
		var oy := y - a.y
		if ox * ox + oy * oy > reach2:
			return
		if x != px and y != py and opq[py * width + x] == 1 and opq[y * width + px] == 1:
			return
		var i := y * width + x
		if _stamp[i] != _stamp_n:
			_stamp[i] = _stamp_n
			result[i] = true
		if opq[i] == 1:
			return
