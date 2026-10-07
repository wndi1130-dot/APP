extends RefCounted
## Integer grid LOS. Blocker itself is visible; cells behind it are hidden.

static func compute(width: int, height: int, origin: Vector2i, radius: int, blockers: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if radius < 0 or origin.x < 0 or origin.y < 0 or origin.x >= width or origin.y >= height:
		return result
	for y in range(maxi(0, origin.y - radius), mini(height, origin.y + radius + 1)):
		for x in range(maxi(0, origin.x - radius), mini(width, origin.x + radius + 1)):
			var cell := Vector2i(x, y)
			var offset := cell - origin
			if offset.length_squared() <= radius * radius and _clear_line(origin, cell, blockers):
				result[cell] = true
	return result

static func _clear_line(origin: Vector2i, target: Vector2i, blockers: Dictionary) -> bool:
	var x := origin.x
	var y := origin.y
	var dx := absi(target.x - x)
	var dy := absi(target.y - y)
	var sx := 1 if x < target.x else -1
	var sy := 1 if y < target.y else -1
	var error := dx - dy
	while x != target.x or y != target.y:
		var previous := Vector2i(x, y)
		var twice := error * 2
		if twice > -dy:
			error -= dy
			x += sx
		if twice < dx:
			error += dx
			y += sy
		var cell := Vector2i(x, y)
		# A diagonal ray cannot squeeze through two touching solid corners.
		if x != previous.x and y != previous.y:
			if blockers.has(Vector2i(x, previous.y)) and blockers.has(Vector2i(previous.x, y)):
				return false
		if cell == target:
			return true
		if blockers.has(cell):
			return false
	return true
