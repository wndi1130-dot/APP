extends RefCounted
## Warm light on the ground (weather_fx 12장): which lights are on and which
## cells they reach. Pure rules, no scene. The view writes the result into the
## spare channel of the sight texture, so the number of lights costs nothing.
## Besides the picture only the eye reads them: a lit room is not dark
## (decision 439 card 1), and at night a lit cell in plain view is seen past
## the short reach (decision 479). The dead, mates and raiders never do.

const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldClock = preload("res://game/sim/field_clock.gd")
const BuildingRules = preload("res://game/sim/building_rules.gd")

## Low sun through the windows (decision 474 B8): the pools come up over the
## ten minutes before 14:50, then draw back toward the sill until sunset.
const WINDOW_FROM_MIN := 880.0
const WINDOW_REACH := Vector2(6.0, 1.5)   # cells into the room at 14:50, at sunset
const WINDOW_FACING := 0.25   # how square to the sun a window must look to let it in
const WINDOW_HALF_WIDTH := 0.6   # metres either side of the sun's line through the window
const WINDOW_TEXELS := 4   # window light texels a cell side, so a slanting patch keeps its edges
## The chief's torch beam ahead of the lantern (decision 471 B4: 12~15 m, 50~60 degrees).
const BEAM := {"strength": 0.85, "reach": 13.0, "half_deg": 27.0}


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
## outdoors: if given, a light out of doors that stays off the floors under
## this grid's roofs (a fire in the yard does not light the room past the wall).
static func stamp(cells: Dictionary, width: int, height: int, at: Vector2i, side: Vector2i, strength: float, reach: float, only: Dictionary = {}, outdoors: FieldGrid = null) -> void:
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
			if outdoors != null and outdoors.indoor(Vector2i(x, y)):
				continue
			var b := int(round(v * 255.0))
			if b > int(cells.get(i, 0)):
				cells[i] = b


## Every fixed light that is on, stamped with what falls on the floor. A row
## marked "outdoor" keeps off the floors under grid's roofs.
static func fixed_cells(lights: Array, width: int, height: int, game_minutes: float, tower_fire: bool, raiders_in: bool, grid: FieldGrid = null) -> Dictionary:
	var cells: Dictionary = {}
	for l in lights:
		if is_on(l, game_minutes, tower_fire, raiders_in):
			stamp(cells, width, height, l["cell"], l.get("side", Vector2i.ZERO), float(l.get("falls", l.get("strength", 0.0))), float(l.get("reach", 0.0)), {}, grid if bool(l.get("outdoor", false)) else null)
	return cells


## The chief's torch (decision 471 B4): light thrown ahead in a cone beside the
## lantern's circle, strong along its middle and soft at its edges, none at
## reach. only: the cells the beam may reach (line of sight, as stamp).
static func beam(cells: Dictionary, width: int, height: int, at: Vector2i, ahead: Vector2, strength: float, reach: float, half_deg: float, only: Dictionary = {}) -> void:
	if ahead.length_squared() < 0.0001 or reach <= 0.0 or strength <= 0.0:
		return
	var dir := ahead.normalized()
	var half_cos := cos(deg_to_rad(half_deg))
	var r := int(ceil(reach))
	for dy in range(-r, r + 1):
		var y := at.y + dy
		if y < 0 or y >= height:
			continue
		for dx in range(-r, r + 1):
			var x := at.x + dx
			if x < 0 or x >= width:
				continue
			var o := Vector2(dx, dy)
			var d := o.length()
			if d < 0.5 or d >= reach:
				continue
			var c := o.dot(dir) / d
			if c < half_cos:
				continue
			var i := y * width + x
			if not only.is_empty() and not only.has(i):
				continue
			var v := strength * (1.0 - d / reach) * smoothstep(half_cos, lerpf(half_cos, 1.0, 0.4), c)
			var b := int(round(clampf(v, 0.0, 1.0) * 255.0))
			if b > int(cells.get(i, 0)):
				cells[i] = b


## Ids of the lights that are on, as one string: the fixed cells only need
## stamping again when this changes.
static func on_key(lights: Array, game_minutes: float, tower_fire: bool, raiders_in: bool) -> String:
	var ids: PackedStringArray = []
	for l in lights:
		if is_on(l, game_minutes, tower_fire, raiders_in):
			ids.append(String(l["id"]))
	return ",".join(ids)


## Strength and reach of the window pools at this hour: none before 14:40 and
## from sunset, full at 14:50, then drawing in toward the sill.
static func window_glow(game_minutes: float) -> Vector2:
	var dusk := float(FieldClock.DUSK_MIN)
	var sunset := float(FieldClock.SUNSET_MIN)
	if game_minutes < WINDOW_FROM_MIN or game_minutes >= sunset:
		return Vector2.ZERO
	var k := clampf((game_minutes - dusk) / (sunset - dusk), 0.0, 1.0)
	var rise := clampf((game_minutes - WINDOW_FROM_MIN) / (dusk - WINDOW_FROM_MIN), 0.0, 1.0)
	return Vector2(rise * (1.0 - smoothstep(0.85, 1.0, k)), lerpf(WINDOW_REACH.x, WINDOW_REACH.y, k))


## The floor the low sun reaches through the ground floor's windows: texel
## index (WINDOW_TEXELS a cell side) -> byte. to_sun: the level way to the sun (x, z); sunny:
## how much of it the clouds let through. Only windows that look out toward
## the sun and are not shut by a curtain or planks; the pool stays on its own
## room's floor (no walls, furniture or doors crossed, never out of doors).
static func window_cells(grid: FieldGrid, to_sun: Vector2, game_minutes: float, sunny: float) -> Dictionary:
	var cells: Dictionary = {}
	var glow := window_glow(game_minutes)
	if glow.x * sunny <= 0.0 or to_sun.length_squared() < 0.0001:
		return cells
	var sun := to_sun.normalized()
	for c: Vector2i in grid.windows:
		if grid.solid_at(c) != FieldGrid.Solid.WINDOW or BuildingRules.window_opaque(grid.windows[c]):
			continue
		var out := grid.outer_face(c)
		if out < 0:
			continue
		var f := grid.faces(c)
		if Vector2(f[out] - c).dot(sun) < WINDOW_FACING:
			continue
		_sun_patch(cells, grid.width, c, -sun, glow.x * sunny, glow.y, _room_floor(grid, f[1 - out], c, glow.y + 1.0))
	return cells


## One window's patch of sun: a strip about as wide as the window, thrown
## across the floor away from the sun and fading only toward its far end, so
## it reads as daylight and not as a lamp's round glow.
static func _sun_patch(cells: Dictionary, width: int, window: Vector2i, into: Vector2, strength: float, reach: float, floor_cells: Dictionary) -> void:
	var n := WINDOW_TEXELS
	var from := Vector2(window) + Vector2(0.5, 0.5)
	for i: int in floor_cells:
		var c := Vector2i(i % width, i / width)
		for sy in n:
			for sx in n:
				var o := Vector2(c) + Vector2((sx + 0.5) / n, (sy + 0.5) / n) - from
				var along := o.dot(into)
				var across := absf(o.cross(into))
				if along <= 0.0 or along >= reach or across >= WINDOW_HALF_WIDTH:
					continue
				var v := strength * (1.0 - smoothstep(0.5 * reach, reach, along)) * (1.0 - smoothstep(0.35, WINDOW_HALF_WIDTH, across))
				var b := int(round(clampf(v, 0.0, 1.0) * 255.0))
				var t := (c.y * n + sy) * width * n + c.x * n + sx
				if b > int(cells.get(t, 0)):
					cells[t] = b


## Open floor of the window's building within reach of it, walked from the
## cell just inside.
static func _room_floor(grid: FieldGrid, from: Vector2i, window: Vector2i, reach: float) -> Dictionary:
	var b := grid.building_at(from)
	var found: Dictionary = {}
	var todo: Array[Vector2i] = [from]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		if not grid.inside(c) or grid.building_at(c) != b or Vector2(c - window).length() >= reach:
			continue
		var i := grid.index(c)
		if found.has(i):
			continue
		var s := grid.solid_at(c)
		if s != FieldGrid.Solid.NONE and s != FieldGrid.Solid.LOW:
			continue
		found[i] = true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			todo.append(c + d)
	return found
