extends RefCounted
## Lights people left in a town at night (decision 471 B4): a fire in a drum,
## a campfire by a woodpile, a candle in a window, a car's headlights with
## battery left. Three to six a map, spread out, chosen from what the map
## already has, so the dark has a few warm places to steer by. A map whose own
## light rows already name one of these kinds keeps its own and gets none.
## A map marked no_fire gets no fires. No smoke anywhere: a flame is a glow.

const FieldGrid = preload("res://game/world/field_grid.gd")
const BuildingRules = preload("res://game/sim/building_rules.gd")

const KINDS: Array[String] = ["campfire", "barrel_fire", "headlights", "candle"]
const FIRES: Array[String] = ["campfire", "barrel_fire"]
## What each kind throws on the ground (LampLight rows). Out of doors ones keep
## off the floors under a roof.
const LIGHT: Dictionary = {
	"campfire": {"strength": 1.0, "falls": 0.9, "reach": 6.0, "outdoor": true},
	"barrel_fire": {"strength": 1.0, "falls": 0.8, "reach": 5.0, "outdoor": true},
	"headlights": {"strength": 0.9, "falls": 0.75, "reach": 9.0, "outdoor": true},
	"candle": {"strength": 0.6, "falls": 0.45, "reach": 2.5, "outdoor": false},
}
const MOST_OF: Dictionary = {"campfire": 1, "barrel_fire": 2, "headlights": 1, "candle": 2}
const MOST := 6
const SPREAD := 10.0   # cells at least between two of them
const TRAIN_GAP := 6   # cells kept clear of the train (it has its own lights)
const ON_MIN := 890    # they show as the light goes (decision 210)


## Add the night lights to data["lights"]; returns how many.
static func plan(data: Dictionary) -> int:
	var lights: Array = data["lights"]
	for l: Dictionary in lights:
		if KINDS.has(String(l.get("kind", ""))):
			return 0
	var grid: FieldGrid = data["grid"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([String(data.get("place_id", "")), "night_lights"])
	var pools := {
		"campfire": _campfires(data, grid),
		"barrel_fire": _barrels(data, grid),
		"headlights": _cars(data, grid),
		"candle": _candles(data, grid),
	}
	if bool(data.get("no_fire", false)):
		for kind in FIRES:
			pools.erase(kind)
	for kind: String in pools:
		_shuffle(pools[kind], rng)
	var picked: Array = []
	var took: Dictionary = {}
	var more := true
	while more and picked.size() < MOST:
		more = false
		for kind: String in KINDS:
			if not pools.has(kind) or int(took.get(kind, 0)) >= int(MOST_OF[kind]) or picked.size() >= MOST:
				continue
			var pool: Array = pools[kind]
			while not pool.is_empty():
				var row: Dictionary = pool.pop_back()
				if _far(picked, row["cell"]):
					row["kind"] = kind
					picked.append(row)
					took[kind] = int(took.get(kind, 0)) + 1
					more = true
					break
	for i in picked.size():
		var row: Dictionary = picked[i]
		var light: Dictionary = (LIGHT[row["kind"]] as Dictionary).duplicate()
		light.merge({"id": "night_%d_%s" % [i + 1, row["kind"]], "kind": row["kind"], "cell": row["cell"],
			"side": row.get("side", Vector2i.ZERO), "when": "dusk", "from_min": ON_MIN})
		lights.append(light)
	return picked.size()


## Plan again from scratch, the planner's own rows dropped first: for a stop
## marked no_fire by its place on the route after its map was built.
static func replan(data: Dictionary) -> int:
	data["lights"] = (data["lights"] as Array).filter(func(l: Dictionary) -> bool: return not String(l.get("id", "")).begins_with("night_"))
	return plan(data)


## Open ground out of doors, clear of the train.
static func _open(data: Dictionary, grid: FieldGrid, c: Vector2i) -> bool:
	if not grid.inside(c) or grid.indoor(c) or grid.solid_at(c) != FieldGrid.Solid.NONE:
		return false
	var train: Variant = data.get("train")
	return not (train is Rect2i and (train as Rect2i).grow(TRAIN_GAP).has_point(c))


## Ground-floor props of these kinds out of doors.
static func _props(data: Dictionary, grid: FieldGrid, kinds: Array) -> Array:
	var out: Array = []
	for p: Dictionary in data.get("props", []):
		if int(p.get("level", 0)) != 0 or not kinds.has(String(p.get("kind", ""))):
			continue
		var r: Rect2i = p["rect"]
		if grid.indoor(r.position) or grid.indoor(r.end - Vector2i.ONE):
			continue
		out.append(r)
	return out


## A fire lit in a drum standing out of doors.
static func _barrels(data: Dictionary, grid: FieldGrid) -> Array:
	var out: Array = []
	for r: Rect2i in _props(data, grid, ["barrel"]):
		out.append({"cell": r.position})
	return out


## A campfire on open ground by a woodpile: the free cell two steps out from it
## with open ground all round.
static func _campfires(data: Dictionary, grid: FieldGrid) -> Array:
	var out: Array = []
	for r: Rect2i in _props(data, grid, ["firewood_pile", "firewood_stack"]):
		var mid := r.position + r.size / 2
		for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
			var c := mid + Vector2i(d.x * (r.size.x / 2 + 2), d.y * (r.size.y / 2 + 2))
			if _clear_round(data, grid, c):
				out.append({"cell": c})
				break
	return out


static func _clear_round(data: Dictionary, grid: FieldGrid, c: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if not _open(data, grid, c + Vector2i(dx, dy)):
				return false
	return true


## A car out of doors with its headlights left on: they throw along its length,
## from whichever end has open ground in front.
static func _cars(data: Dictionary, grid: FieldGrid) -> Array:
	var out: Array = []
	for r: Rect2i in _props(data, grid, ["car"]):
		var long := Vector2i(1, 0) if r.size.x >= r.size.y else Vector2i(0, 1)
		var mid := r.position + r.size / 2
		for ahead: Vector2i in [long, -long]:
			var front := Vector2i(r.end.x - 1 if ahead.x > 0 else (r.position.x if ahead.x < 0 else mid.x),
				r.end.y - 1 if ahead.y > 0 else (r.position.y if ahead.y < 0 else mid.y))
			if _open(data, grid, front + ahead) and _open(data, grid, front + ahead * 2):
				out.append({"cell": front, "side": ahead})
				break
	return out


## A candle left in a ground-floor window that looks out, its curtain open.
static func _candles(data: Dictionary, grid: FieldGrid) -> Array:
	var out: Array = []
	for c: Vector2i in grid.windows:
		var w: Dictionary = grid.windows[c]
		if grid.solid_at(c) != FieldGrid.Solid.WINDOW or BuildingRules.window_opaque(w):
			continue
		if BuildingRules.role_of(data, int(w.get("building", -1))) in ["store", "lookout"]:
			continue
		var o := grid.outer_face(c)
		if o < 0:
			continue
		var f := grid.faces(c)
		if not _open(data, grid, f[o]):
			continue
		out.append({"cell": c, "side": f[o] - c})
	return out


static func _far(picked: Array, c: Vector2i) -> bool:
	for row: Dictionary in picked:
		if Vector2(row["cell"] - c).length() < SPREAD:
			return false
	return true


## Fisher-Yates with the map's own dice, after a fixed order, so a map always
## gets the same lights.
static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	a.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var p: Vector2i = x["cell"]
		var q: Vector2i = y["cell"]
		return p.y < q.y or (p.y == q.y and p.x < q.x))
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t
