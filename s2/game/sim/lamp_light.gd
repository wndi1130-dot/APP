extends RefCounted
## Warm light on the ground (weather_fx 12장): which lights are on and which
## cells they reach. Pure rules, no scene. The view writes the result into the
## spare channel of the sight texture, so the number of lights costs nothing.
## Picture only: no game rule reads these cells.


## Is this light (a row of SulehufMap data["lights"]) on?
static func is_on(light: Dictionary, game_minutes: float, tower_fire: bool, raiders_in: bool) -> bool:
	match String(light.get("when", "always")):
		"always":
			return true
		"dusk":
			return game_minutes >= float(light.get("from_min", 0))
		"tower_fire":
			return tower_fire
		"raiders_dusk":
			return raiders_in and game_minutes >= float(light.get("from_min", 0))
	return false


## Light that reaches a cell at this offset from the source: full at the source,
## none at reach. A light that throws one way (side) only lights what is in
## front of it: not its own row (the car roof) and nothing behind.
static func falloff(offset: Vector2i, side: Vector2i, strength: float, reach: float) -> float:
	if reach <= 0.0 or strength <= 0.0:
		return 0.0
	if side != Vector2i.ZERO and offset.x * side.x + offset.y * side.y <= 0:
		return 0.0
	var t := 1.0 - Vector2(offset).length() / reach
	return 0.0 if t <= 0.0 else clampf(strength * t * t, 0.0, 1.0)


## Add one light to cells (cell index -> byte 0..255); the brighter light wins.
## only: if given, a set of cell indexes the light may reach (line of sight).
static func stamp(cells: Dictionary, width: int, height: int, at: Vector2i, side: Vector2i, strength: float, reach: float, only: Dictionary = {}) -> void:
	var r := int(ceil(reach))
	for dy in range(-r, r + 1):
		var y := at.y + dy
		if y < 0 or y >= height:
			continue
		for dx in range(-r, r + 1):
			var x := at.x + dx
			if x < 0 or x >= width:
				continue
			var v := falloff(Vector2i(dx, dy), side, strength, reach)
			if v <= 0.0:
				continue
			var i := y * width + x
			if not only.is_empty() and not only.has(i):
				continue
			var b := int(round(v * 255.0))
			if b > int(cells.get(i, 0)):
				cells[i] = b


## Every fixed light that is on, stamped with what falls on the floor.
static func fixed_cells(lights: Array, width: int, height: int, game_minutes: float, tower_fire: bool, raiders_in: bool) -> Dictionary:
	var cells: Dictionary = {}
	for l in lights:
		if is_on(l, game_minutes, tower_fire, raiders_in):
			stamp(cells, width, height, l["cell"], l.get("side", Vector2i.ZERO), float(l.get("falls", l.get("strength", 0.0))), float(l.get("reach", 0.0)))
	return cells


## Ids of the lights that are on, as one string: the fixed cells only need
## stamping again when this changes.
static func on_key(lights: Array, game_minutes: float, tower_fire: bool, raiders_in: bool) -> String:
	var ids: PackedStringArray = []
	for l in lights:
		if is_on(l, game_minutes, tower_fire, raiders_in):
			ids.append(String(l["id"]))
	return ",".join(ids)
