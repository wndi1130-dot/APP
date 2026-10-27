extends RefCounted
## What stands round a stop map, outside its cells (결정 448 17번): bare woods
## starting just past the last walkable cell, the rails running on out of them,
## and every road ending deep in the band at sleepers or crates (지도 발주 6장:
## no wire on roads or bands; barricades are crates, sleds and sleeper piles).
## The ground and the low fog out there are fx/map_edge.gd's; this draws what
## stands on it. Nothing here is walked on: the cells end where they always did.
## The camera's reach is separate from the woods (clamp_focus).

const FieldGrid = preload("res://game/world/field_grid.gd")
const PropModels = preload("res://game/world/prop_models.gd")
const F = FieldGrid.Floor

## Metres of woods drawn outside each edge, independent of the camera's reach.
const BAND: float = 12.0
## How far past the edge the camera may look: past the woods, onto the far ground
## (user 10-27, picked from 12 / 24 / 36 m pictures). Trials set view_band.
const VIEW_BAND: float = 24.0
static var view_band: float = VIEW_BAND
## Sparse, unreachable ground beyond the woods, batched in larger pieces. It starts
## where the woods end, so the ring the camera shows past them is not left open.
const FAR_NEAR: float = BAND
const FAR_REACH: float = 60.0
const FAR_CHUNK: float = 32.0
const FAR_HOUSE := "house"
const FAR_TREES: Array[String] = ["res://models/props_field/bare_willow.glb", "res://models/props_field/bare_orchard_tree.glb"]
const FAR_BUSH := "res://models/props_field/dry_bush.glb"
const FAR_ROCK := "res://models/props_field/boulder.glb"
const FAR_POLE := "res://models/props_field/fallen_pole.glb"
const FAR_CAR := "res://models/props_field/wrecked_car_cluster.glb"
## The first rows, close and thick, read as the end of the way.
const INNER_ROW: float = 2.6
const INNER_SPACING: float = 2.0
const DEEP_SPACING: float = 4.0
## No trunk nearer the edge than this: the last walkable cell stays clear.
const TRUNK_GAP: float = 0.3
## How far that start wanders out along the edge.
const EDGE_WAVE: float = 1.2
## No tree this near a rail line running out (the train leaves along it).
const RAIL_CLEAR: float = 2.5
## A road goes on this far past the edge before it is blocked: deep in the band, so it
## reads as a way on that is shut out there, yet short of the band's far side, so the
## block is on the screen of one standing at the edge (map-layout, card O1).
const ROAD_RUN: float = BAND - 3.0
## A run of road cells along an edge wider than this is a road running beside the edge,
## not one leaving the map: no corridor and no block for it, the woods stand as anywhere
## (else a whole side was lined with crates, a wall). Roads out are 2 to 6 cells.
const ROAD_WIDEST := 8
## Trees are drawn in pieces this many metres a side, so those off screen are not.
const CHUNK: float = 16.0
## Only the first trees throw a shadow, the ones whose shadow falls on the ground
## people walk: the sun's shadow reaches the edge even from the middle of a map,
## and further out the fog past the edge (fx/map_edge.gd) lies over the ground.
const SHADE_DEPTH: float = 1.2
const TREE_HEIGHT := Vector2(3.6, 5.6)

const TREE_MODEL := "res://models/props_common/bare_tree.glb"
const BLOCK_MODELS: Array[String] = ["res://models/props_stop01/sleeper_fence.glb", "res://models/props_common/crate_stack.glb"]
## Now and then a small glade behind the first rows, with a trace of people in it, so
## the band reads as woods and not as a wall (ref-ops 참고 대조 4 E3): one chance every
## GLADE_EVERY metres along an edge, a square GLADE_SIZE metres a side, its near side
## GLADE_NEAR metres out — past the thick first rows, well inside what the camera shows.
const GLADE_EVERY: float = 48.0
const GLADE_CHANCE: float = 0.5
const GLADE_SIZE := Vector2(4.0, 6.0)
const GLADE_NEAR: float = 3.0
## Felled: a cluster of cut stumps. Rest: a log to sit on, a cold fire before it and a
## pile of firewood (needs a glade of 5 m or more). A trace whose model is not there yet
## is left out, never drawn as a grey box (the cold fire is asked of art3d).
const STUMPS_MODEL := "res://models/props_field/stump_cluster.glb"
const LOG_MODEL := "res://models/props_field/fallen_log.glb"
const FIREWOOD_MODEL := "res://models/props_field/firewood_pile.glb"
const COLD_FIRE_MODEL := "res://models/props_field/cold_campfire.glb"
## The near ring past the woods, BAND to the camera's reach, gets low cover in loose
## clumps so it does not read as bare ground (coordinator 10-27): stumps, dry bushes
## and grass, boulders, now and then a short snow bank. Clumps at uneven gaps and
## depths, some left out, so nothing lines up into a fence or a row. The reach is the
## constant, not view_band, so camera trials never move the scenery.
const FAR_GRASS := "res://models/props_field/dry_grass.glb"
const COVER_MODELS: Array[String] = [STUMPS_MODEL, FAR_BUSH, FAR_GRASS, FAR_ROCK]
## More of it near the woods: past about 17 m the edge fog is over half, and cover
## there barely shows.
const COVER_GAP := Vector2(3.5, 8.0)
const COVER_SKIP: float = 0.12
const COVER_BANK: float = 0.2
const COVER_PIECES := Vector2i(3, 6)
const COVER_SPREAD: float = 3.0


## Half the ground the field camera shows along the map's x and z: across from the
## aspect, along from the pitch; a camera turned yaw_deg from north (결정 476) shows
## that rectangle turned, so this is half the box round it.
static func view_half(cam_size: float, aspect: float, pitch_deg: float, yaw_deg: float = 0.0) -> Vector2:
	var across := cam_size * aspect * 0.5
	var along := cam_size * 0.5 / sin(deg_to_rad(pitch_deg))
	var c := absf(cos(deg_to_rad(yaw_deg)))
	var s := absf(sin(deg_to_rad(yaw_deg)))
	return Vector2(across * c + along * s, across * s + along * c)


## How far from the middle of the screen the player may stand, as a share of half
## the screen each way, before the view follows past view_band (keep_on_screen).
const KEEP: float = 0.6


## A turned view (결정 476) held inside view_band stops so far in at a corner of the
## map that the player would slide to the screen's corner, under the thumbs, or off
## it: the view moves toward `at` just enough to keep it inside the middle KEEP of
## the screen. Only there does the screen go past view_band, onto the fog and the
## ground past the edge (fx/map_edge.gd).
static func keep_on_screen(focus: Vector3, at: Vector3, cam_size: float, aspect: float, pitch_deg: float, yaw_deg: float) -> Vector3:
	var half := Vector2(cam_size * aspect * 0.5, cam_size * 0.5 / sin(deg_to_rad(pitch_deg))) * KEEP
	var yaw := deg_to_rad(yaw_deg)
	# Where `at` lies from the focus across and down the screen, in metres of ground.
	var off := Vector2(at.x - focus.x, at.z - focus.z).rotated(yaw)
	var over := off - Vector2(clampf(off.x, -half.x, half.x), clampf(off.y, -half.y, half.y))
	var move := over.rotated(-yaw)
	return focus + Vector3(move.x, 0, move.y)


## Resolve the omitted argument at call time, so a trial can change view_band.
static func clamp_focus(focus: Vector3, half: Vector2, width: int, height: int, band: float = -1.0) -> Vector3:
	var reach := view_band if band < 0.0 else band
	return Vector3(_clamp_axis(focus.x, half.x, float(width), reach), focus.y, _clamp_axis(focus.z, half.y, float(height), reach))


static func _clamp_axis(v: float, half: float, size: float, band: float) -> float:
	var lo := half - band
	var hi := size + band - half
	if lo > hi:
		return size * 0.5
	return clampf(v, lo, hi)


static func seed_of(data: Dictionary) -> int:
	return hash(String(data.get("place_id", "")) + ":edge")


## Where a road or the rails cross an edge: {"side": 0 west 1 east 2 north 3 south,
## "from", "to" (cells along the edge, to inclusive), "floor"}.
static func openings(g: FieldGrid) -> Array:
	var out: Array = []
	for side in 4:
		var n := g.height if side < 2 else g.width
		var run_from := -1
		var run_floor := -1
		for i in range(n + 1):
			var f := -1
			if i < n:
				var c := _edge_cell(g, side, i)
				var kind := g.floor_at(c)
				if (kind == F.ROAD or kind == F.RAIL) and g.people_can_walk(c):
					f = kind
			if f != run_floor:
				if run_from >= 0 and (run_floor == F.RAIL or i - run_from <= ROAD_WIDEST):
					out.append({"side": side, "from": run_from, "to": i - 1, "floor": run_floor})
				run_from = i if f >= 0 else -1
				run_floor = f
	return out


static func _edge_cell(g: FieldGrid, side: int, i: int) -> Vector2i:
	match side:
		0:
			return Vector2i(0, i)
		1:
			return Vector2i(g.width - 1, i)
		2:
			return Vector2i(i, 0)
	return Vector2i(i, g.height - 1)


## The ground a run keeps clear outside the edge, out to `length` metres, `pad` either side.
static func run_rect(g: FieldGrid, run: Dictionary, length: float, pad: float) -> Rect2:
	var a := float(run["from"]) - pad
	var b := float(run["to"]) + 1.0 + pad
	match int(run["side"]):
		0:
			return Rect2(-length, a, length, b - a)
		1:
			return Rect2(g.width, a, length, b - a)
		2:
			return Rect2(a, -length, b - a, length)
	return Rect2(a, g.height, b - a, length)


## How far outside the cells a point lies (0 or less: inside).
static func outside(g: FieldGrid, x: float, z: float) -> float:
	var dx := maxf(-x, x - float(g.width))
	var dz := maxf(-z, z - float(g.height))
	if dx <= 0.0 and dz <= 0.0:
		return maxf(dx, dz)
	return Vector2(maxf(dx, 0.0), maxf(dz, 0.0)).length()


## Everything the band places, the same for the same map: trees {at, yaw, height},
## blocks {at, yaw, model}, the clear corridors and the openings they come from.
static func plan(g: FieldGrid, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var runs := openings(g)
	var clear: Array[Rect2] = []
	var blocks: Array = []
	for run: Dictionary in runs:
		if int(run["floor"]) == F.RAIL:
			clear.append(run_rect(g, run, BAND + 1.0, RAIL_CLEAR))
			continue
		clear.append(run_rect(g, run, ROAD_RUN + 1.2, 0.6))
		# Across the road at the end of its run: sleepers and crates, end to end.
		var across := run_rect(g, run, ROAD_RUN + 0.6, 0.0)
		var along_x := int(run["side"]) >= 2
		var width := across.size.x if along_x else across.size.y
		var at_end := _run_end(across, int(run["side"]))
		var pieces := maxi(1, int(ceil(width / 2.2)))
		for k in pieces:
			var t := (float(k) + 0.5) / float(pieces)
			var at := Vector3(across.position.x + across.size.x * t, 0, at_end.y) if along_x \
				else Vector3(at_end.x, 0, across.position.y + across.size.y * t)
			blocks.append({"at": at, "yaw": 0.0 if along_x else PI * 0.5, "model": BLOCK_MODELS[k % 2 if rng.randf() < 0.7 else 1]})
	var glades := _glades(g, seed, clear)
	var no_trees: Array[Rect2] = clear.duplicate()
	for gl: Dictionary in glades:
		no_trees.append((gl["rect"] as Rect2).grow(0.5))  # no trunk against the trace's edge
	var trees: Array = []
	_scatter(g, rng, no_trees, trees, INNER_SPACING, TRUNK_GAP, INNER_ROW)
	_scatter(g, rng, no_trees, trees, DEEP_SPACING, INNER_ROW, BAND)
	# New scenery never consumes a draw from the woods or the glades.
	var distant := _far_plan(g, seed, runs)
	return {"trees": trees, "blocks": blocks, "glades": glades, "clear": clear, "runs": runs,
		"far": distant["far"], "fields": distant["fields"], "tracks": distant["tracks"], "sounds": distant["sounds"]}


## Scenery {at, yaw, scale, model, side}; houses use dimensions as their scale.
## Corridors continue to the far edge, without changing the near woods' clear list.
static func _far_plan(g: FieldGrid, seed: int, runs: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(seed) + ":far")
	var corridors: Array[Rect2] = []
	var rails: Array[Rect2] = []
	var roads: Array[Dictionary] = []
	var tracks: Array[Dictionary] = []
	for run: Dictionary in runs:
		var is_rail := int(run["floor"]) == F.RAIL
		corridors.append(run_rect(g, run, FAR_REACH, RAIL_CLEAR if is_rail else 0.6))
		if is_rail:
			rails.append(run_rect(g, run, FAR_REACH, RAIL_CLEAR + 6.0))
		else:
			roads.append(run)
			tracks.append({"side": int(run["side"]), "along": (float(run["from"]) + float(run["to"]) + 1.0) * 0.5,
				"width": float(int(run["to"]) - int(run["from"]) + 1), "near": ROAD_RUN + 1.2, "far": FAR_REACH})
	var scenery: Array[Dictionary] = []
	var houses: Array[Vector3] = []
	for side in 4:
		var length := float(g.height if side < 2 else g.width)
		var along := rng.randf_range(10.0, 22.0)
		while along < length:
			var center := _far_at(g, side, along, rng.randf_range(FAR_NEAR + 8.0, FAR_REACH - 9.0))
			along += rng.randf_range(25.0, 40.0)
			if not _far_empty(g, center, 7.0, corridors):
				continue
			var grove_size := rng.randi_range(3, 7)
			for tree_index in grove_size:
				var angle := TAU * float(tree_index) / float(grove_size) + rng.randf_range(-0.3, 0.3)
				var at := center + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(1.2, 3.5)
				_far_prop(scenery, at, side, FAR_TREES[rng.randi_range(0, FAR_TREES.size() - 1)], rng)
		for model: String in [FAR_BUSH, FAR_ROCK, FAR_POLE]:
			var wanted := rng.randi_range(0, 2) if model == FAR_POLE else rng.randi_range(1, 3)
			for _piece in wanted:
				for _attempt in 24:
					var at := _far_at(g, side, rng.randf_range(0.0, length), rng.randf_range(FAR_NEAR + 5.0, FAR_REACH - 5.0))
					if _far_empty(g, at, 4.0, corridors):
						_far_prop(scenery, at, side, model, rng)
						break
		var house_count := rng.randi_range(0, 2)
		for _house_index in house_count:
			for _attempt in 32:
				var at := _far_at(g, side, rng.randf_range(0.0, length), rng.randf_range(35.0, 55.0))
				if not _far_empty(g, at, 5.5, corridors) or houses.any(func(other: Vector3) -> bool: return other.distance_to(at) < 25.0):
					continue
				houses.append(at)
				scenery.append({"at": at, "yaw": rng.randf_range(0.0, TAU),
					"scale": Vector3(rng.randf_range(5.0, 8.0), rng.randf_range(2.4, 3.6), rng.randf_range(4.0, 6.0)), "model": FAR_HOUSE, "side": side})
				break
	# One wreck beside a departing road, beyond the unchanged block.
	if not roads.is_empty():
		for _attempt in 64:
			var road: Dictionary = roads[rng.randi_range(0, roads.size() - 1)]
			var side := int(road["side"])
			var along := (float(road["from"]) + float(road["to"]) + 1.0) * 0.5
			var offset := float(int(road["to"]) - int(road["from"]) + 1) * 0.5 + rng.randf_range(4.0, 7.0)
			var at := _far_at(g, side, along + offset * (-1.0 if rng.randf() < 0.5 else 1.0), rng.randf_range(24.0, 50.0))
			if _far_empty(g, at, 3.3, corridors):
				_far_prop(scenery, at, side, FAR_CAR, rng)
				break
	var fields := _far_fields(g, seed, corridors)
	var cover := _ring_cover(g, seed, corridors)
	scenery.append_array(cover["props"])
	for bank: Dictionary in cover["banks"]:
		if _far_plot_clear(bank["rect"] as Rect2, corridors, fields):
			fields.append(bank)
	return {"far": scenery, "fields": fields, "tracks": tracks, "sounds": _far_sounds(g, seed, rails)}


## Low cover in the near ring (COVER_*), from its own draw so the far scenery stands
## where it did: {props: [scenery], banks: [bank plots]}. The west and east sides run on
## past the map's corners so the corner squares are covered once.
static func _ring_cover(g: FieldGrid, seed: int, corridors: Array[Rect2]) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(seed) + ":cover")
	var props: Array[Dictionary] = []
	var banks: Array[Dictionary] = []
	for side in 4:
		var length := float(g.height if side < 2 else g.width)
		var past := VIEW_BAND if side < 2 else 0.0
		var along := -past + rng.randf_range(2.0, 8.0)
		while along < length + past:
			var here := along
			along += rng.randf_range(COVER_GAP.x, COVER_GAP.y)
			if rng.randf() < COVER_SKIP:
				continue
			var depth := minf(rng.randf_range(BAND + 1.0, VIEW_BAND - 1.0), rng.randf_range(BAND + 1.0, VIEW_BAND - 1.0))
			var center := _far_at(g, side, here, depth)
			if rng.randf() < COVER_BANK:
				var size := Vector2(rng.randf_range(3.0, 6.0), rng.randf_range(0.5, 0.9))
				if side < 2:
					size = Vector2(size.y, size.x)
				if _far_empty(g, center, maxf(size.x, size.y) * 0.5, corridors):
					banks.append({"rect": Rect2(Vector2(center.x, center.z) - size * 0.5, size), "side": side, "kind": "bank"})
				continue
			var main: String = COVER_MODELS[rng.randi_range(0, COVER_MODELS.size() - 1)]
			for _piece in rng.randi_range(COVER_PIECES.x, COVER_PIECES.y):
				var model: String = main if rng.randf() < 0.7 else COVER_MODELS[rng.randi_range(0, COVER_MODELS.size() - 1)]
				var angle := rng.randf_range(0.0, TAU)
				var at := center + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(0.5, COVER_SPREAD)
				if _far_empty(g, at, 1.0, corridors):
					_far_prop(props, at, side, model, rng)
	return {"props": props, "banks": banks}


static func _far_at(g: FieldGrid, side: int, along: float, depth: float) -> Vector3:
	match side:
		0:
			return Vector3(-depth, 0, along)
		1:
			return Vector3(float(g.width) + depth, 0, along)
		2:
			return Vector3(along, 0, -depth)
	return Vector3(along, 0, float(g.height) + depth)


static func _far_empty(g: FieldGrid, at: Vector3, radius: float, corridors: Array[Rect2]) -> bool:
	var depth := outside(g, at.x, at.z)
	if depth - radius < FAR_NEAR or depth + radius >= FAR_REACH:
		return false
	for corridor in corridors:
		if corridor.grow(radius).has_point(Vector2(at.x, at.z)):
			return false
	return true


static func _far_prop(scenery: Array[Dictionary], at: Vector3, side: int, model: String, rng: RandomNumberGenerator) -> void:
	var scale := rng.randf_range(0.8, 1.2)
	scenery.append({"at": at, "yaw": rng.randf_range(0.0, TAU), "scale": Vector3.ONE * scale, "model": model, "side": side})


## Axis-aligned plots and a few low snow banks; leave gaps between the plots.
static func _far_fields(g: FieldGrid, seed: int, corridors: Array[Rect2]) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(seed) + ":fields")
	var plots: Array[Dictionary] = []
	for side in 4:
		var length := float(g.height if side < 2 else g.width)
		var wanted := rng.randi_range(1, 3)
		var placed := 0
		for _attempt in 96:
			if placed == wanted:
				break
			var span := rng.randf_range(12.0, 30.0)
			var depth := rng.randf_range(12.0, 30.0)
			if span > length:
				continue
			var at := _far_at(g, side, rng.randf_range(span * 0.5, length - span * 0.5), rng.randf_range(FAR_NEAR + depth * 0.5 + 0.5, FAR_REACH - depth * 0.5 - 0.5))
			var size := Vector2(depth, span) if side < 2 else Vector2(span, depth)
			var rect := Rect2(Vector2(at.x, at.z) - size * 0.5, size)
			if not _far_plot_clear(rect, corridors, plots):
				continue
			plots.append({"rect": rect, "side": side, "kind": "field", "rows_x": side >= 2, "spacing": rng.randf_range(1.3, 2.0)})
			placed += 1
		# A narrow gap beside a corridor still gets one small plot when it fits.
		var along := 6.5
		while placed == 0 and along + 6.0 <= length:
			var depth := FAR_NEAR + 6.5
			while placed == 0 and depth + 6.0 < FAR_REACH:
				var at := _far_at(g, side, along, depth)
				var rect := Rect2(Vector2(at.x, at.z) - Vector2(6, 6), Vector2(12, 12))
				if _far_plot_clear(rect, corridors, plots):
					plots.append({"rect": rect, "side": side, "kind": "field", "rows_x": side >= 2, "spacing": 1.5})
					placed += 1
				depth += 2.0
			along += 2.0
	var bank_start := rng.randi_range(0, 3)
	var bank_count := rng.randi_range(2, 4)
	for bank_index in bank_count:
		var side := (bank_start + bank_index) % 4
		var length := float(g.height if side < 2 else g.width)
		for _attempt in 24:
			var at := _far_at(g, side, rng.randf_range(0.0, length), rng.randf_range(FAR_NEAR + 6.0, FAR_REACH - 6.0))
			if not _far_empty(g, at, 5.0, corridors):
				continue
			var size := Vector2(rng.randf_range(4.0, 9.0), rng.randf_range(0.5, 1.0))
			if side < 2:
				size = Vector2(size.y, size.x)
			plots.append({"rect": Rect2(Vector2(at.x, at.z) - size * 0.5, size), "side": side, "kind": "bank"})
			break
	return plots


static func _far_plot_clear(rect: Rect2, corridors: Array[Rect2], plots: Array[Dictionary]) -> bool:
	return not corridors.any(func(c: Rect2) -> bool: return c.intersects(rect.grow(0.5))) \
		and not plots.any(func(p: Dictionary) -> bool: return (p["rect"] as Rect2).grow(2.0).intersects(rect))


## Metadata only: one site on each of three or four sides, well off the rails.
static func _far_sounds(g: FieldGrid, seed: int, rails: Array[Rect2]) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(seed) + ":sounds")
	var sites: Array[Dictionary] = []
	var start := rng.randi_range(0, 3)
	var count := rng.randi_range(3, 4)
	for site_index in count:
		var side := (start + site_index) % 4
		var length := float(g.height if side < 2 else g.width)
		# A clear corner is also available when a whole side carries rails.
		var corner_along := -20.0 if side == 0 or side == 3 else length + 20.0
		var at := _far_at(g, side, corner_along, sqrt(35.0 * 35.0 - 20.0 * 20.0))
		for _attempt in 48:
			var candidate := _far_at(g, side, rng.randf_range(0.0, length), rng.randf_range(30.0, 40.0))
			if not _in_any(rails, candidate.x, candidate.z):
				at = candidate
				break
		sites.append({"at": at, "kind": "horde"})
	return sites


## The glades, {rect, kind "felled" | "rest", props [{at, yaw, model}]}, from their own
## draw so the trees elsewhere stand where they did. None on a run's corridor or a corner.
static func _glades(g: FieldGrid, seed: int, clear: Array[Rect2]) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(seed) + ":glades")
	var out: Array = []
	for side in 4:
		var length := float(g.height if side < 2 else g.width)
		var u := GLADE_NEAR + GLADE_SIZE.y
		while u + GLADE_EVERY <= length - GLADE_NEAR - GLADE_SIZE.y + 0.01:
			var roll := rng.randf()
			var s := rng.randf_range(GLADE_SIZE.x, GLADE_SIZE.y)
			var a := u + rng.randf_range(0.0, GLADE_EVERY - s)
			var rest := s >= 5.0 and rng.randf() < 0.5
			u += GLADE_EVERY
			if roll >= GLADE_CHANCE:
				continue
			var r := _side_rect(g, side, a, s)
			if clear.any(func(c: Rect2) -> bool: return c.grow(1.0).intersects(r)):
				continue
			# Props lie along the edge (yaw 0 runs along x, so turned on the west and east).
			var yaw := PI * 0.5 if side < 2 else 0.0
			var mid := Vector3(r.get_center().x, 0, r.get_center().y)
			var across := Vector3(1, 0, 0) if side < 2 else Vector3(0, 0, 1)
			var props: Array = []
			if rest:
				props.append({"at": mid - across * 1.5, "yaw": yaw, "model": LOG_MODEL})
				props.append({"at": mid + across * 0.3, "yaw": yaw, "model": COLD_FIRE_MODEL})
				props.append({"at": mid + across * 1.9, "yaw": yaw, "model": FIREWOOD_MODEL})
			else:
				props.append({"at": mid, "yaw": yaw + rng.randf_range(-0.3, 0.3), "model": STUMPS_MODEL})
			out.append({"rect": r, "kind": "rest" if rest else "felled", "props": props})
	return out


## A square `s` metres a side, `a` metres along `side`, its near side GLADE_NEAR out.
static func _side_rect(g: FieldGrid, side: int, a: float, s: float) -> Rect2:
	match side:
		0:
			return Rect2(-GLADE_NEAR - s, a, s, s)
		1:
			return Rect2(g.width + GLADE_NEAR, a, s, s)
		2:
			return Rect2(a, -GLADE_NEAR - s, s, s)
	return Rect2(a, g.height + GLADE_NEAR, s, s)


static func _run_end(r: Rect2, side: int) -> Vector2:
	match side:
		0:
			return Vector2(r.position.x, 0)
		1:
			return Vector2(r.end.x, 0)
		2:
			return Vector2(0, r.position.y)
	return Vector2(0, r.end.y)


## A jittered lattice over the ring between `near` and `far` metres outside.
static func _scatter(g: FieldGrid, rng: RandomNumberGenerator, clear: Array[Rect2], trees: Array, spacing: float, near: float, far: float) -> void:
	var lo := -far
	var hi_x := float(g.width) + far
	var hi_z := float(g.height) + far
	var z := lo
	while z < hi_z:
		var x := lo
		while x < hi_x:
			var px := x + spacing * 0.5 + rng.randf_range(-0.42, 0.42) * spacing
			var pz := z + spacing * 0.5 + rng.randf_range(-0.42, 0.42) * spacing
			var yaw := rng.randf() * TAU
			var tall := rng.randf_range(TREE_HEIGHT.x, TREE_HEIGHT.y)
			var d := outside(g, px, pz)
			var start := near if near > TRUNK_GAP else _edge_start(px, pz, rng.seed)
			if d >= start and d < far and not _in_any(clear, px, pz):
				trees.append({"at": Vector3(px, 0, pz), "yaw": yaw, "height": tall})
			x += spacing
		z += spacing


## Where the woods begin past the edge, uneven along it so the edge is not ruled.
static func _edge_start(x: float, z: float, seed: int) -> float:
	var along := x + z
	var k := float(posmod(seed, 1000)) * 0.01
	var wave := (0.5 + 0.5 * sin(along * 0.37 + k)) * (0.5 + 0.5 * sin(along * 0.113 + k * 1.7))
	return TRUNK_GAP + EDGE_WAVE * wave


static func _in_any(rects: Array[Rect2], x: float, z: float) -> bool:
	for r in rects:
		if r.has_point(Vector2(x, z)):
			return true
	return false


static func _chunk(at: Vector3) -> Vector2i:
	return Vector2i(floori((at.x + BAND) / CHUNK), floori((at.z + BAND) / CHUNK))


## Draw the band under `parent` (the ground level's root): the road and rail runs
## in the map's own material, trees and blocks as models. Returns counts for the
## build log and the tests.
static func build(parent: Node3D, g: FieldGrid, data: Dictionary, material: Material, colors: Array) -> Dictionary:
	var p := plan(g, seed_of(data))
	var root := Node3D.new()
	root.name = "EdgeBand"
	parent.add_child(root)
	# Roads and rails run on out in their own colour (the rails' sleepers every other
	# metre), a hair above the ground past the edge (fx/map_edge.gd). Roads end at their
	# block; rails go on through the far ground into the fog, past the camera's reach.
	var ground := SurfaceTool.new()
	ground.begin(Mesh.PRIMITIVE_TRIANGLES)
	for run: Dictionary in p["runs"]:
		var f := int(run["floor"])
		var r := run_rect(g, run, FAR_REACH if f == F.RAIL else ROAD_RUN, 0.0)
		var base: Color = colors[f]
		for yy in range(floori(r.position.y), ceili(r.end.y)):
			for xx in range(floori(r.position.x), ceili(r.end.x)):
				var col := base.darkened(0.15) if f == F.RAIL and posmod(xx, 2) == 0 else base
				_quad(ground, Rect2(xx, yy, 1, 1), 0.004, col, f)
	if not p["runs"].is_empty():
		var ground_node := MeshInstance3D.new()
		ground_node.name = "Runs"
		ground_node.mesh = ground.commit()
		ground_node.material_override = material
		ground_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ground_node)
	# Trees and blocks: models when there are, else the grey trunk and crown the map uses.
	var tree_mesh: Mesh = _model_mesh(TREE_MODEL)
	var tree_h := tree_mesh.get_aabb().size.y if tree_mesh else 1.0
	# Trees deep in the band throw no shadow: half the cost of a shadow pass for woods
	# the player only sees the tops of (SHADE_DEPTH).
	var by_chunk: Dictionary = {}
	for t: Dictionary in p["trees"]:
		var cell := _chunk(t["at"])
		var at: Vector3 = t["at"]
		var key := Vector3i(cell.x, cell.y, 1 if outside(g, at.x, at.z) > SHADE_DEPTH else 0)
		if not by_chunk.has(key):
			by_chunk[key] = []
		by_chunk[key].append(t)
	for key: Vector3i in by_chunk:
		var list: Array = by_chunk[key]
		if tree_mesh:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = tree_mesh
			mm.instance_count = list.size()
			for i in list.size():
				var t: Dictionary = list[i]
				var s := float(t["height"]) / maxf(tree_h, 0.01)
				mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, float(t["yaw"])).scaled(Vector3(s, s, s)), t["at"]))
			var node := MultiMeshInstance3D.new()
			node.name = "Trees_%d_%d_%d" % [key.x, key.y, key.z]
			node.multimesh = mm
			if key.z == 1:
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(node)
		else:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for t: Dictionary in list:
				var tall := float(t["height"])
				_box(st, Vector3(0.4, tall * 0.55, 0.4), t["at"] + Vector3(0, tall * 0.275, 0), Color(0.3, 0.26, 0.22))
				_box(st, Vector3(2.0, tall * 0.4, 2.0), t["at"] + Vector3(0, tall * 0.75, 0), Color(0.62, 0.66, 0.66))
			var node := MeshInstance3D.new()
			node.name = "Trees_%d_%d_%d" % [key.x, key.y, key.z]
			node.mesh = st.commit()
			node.material_override = material
			root.add_child(node)
	var traces := 0
	for gl: Dictionary in p["glades"]:
		for t: Dictionary in gl["props"]:
			var mesh := _model_mesh(String(t["model"]))
			if mesh == null:
				continue
			var node := MeshInstance3D.new()
			node.name = "Trace"
			node.mesh = mesh
			node.transform = Transform3D(Basis(Vector3.UP, float(t["yaw"])), t["at"])
			root.add_child(node)
			traces += 1
	for b: Dictionary in p["blocks"]:
		var mesh := _model_mesh(String(b["model"]))
		var node := MeshInstance3D.new()
		node.name = "Block"
		if mesh:
			node.mesh = mesh
		else:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_box(st, Vector3(2.0, 1.0, 0.8), Vector3(0, 0.5, 0), Color(0.42, 0.4, 0.38))
			node.mesh = st.commit()
			node.material_override = material
		node.transform = Transform3D(Basis(Vector3.UP, float(b["yaw"])), b["at"])
		root.add_child(node)
	var counts := {"trees": (p["trees"] as Array).size(), "blocks": (p["blocks"] as Array).size(), "glades": (p["glades"] as Array).size(), "traces": traces, "chunks": by_chunk.size(), "runs": (p["runs"] as Array).size()}
	counts.merge(_build_far(root, g, p, material, colors))
	# Where the danger past the woods is heard (field_audio.gd, the edge bed).
	var spots: Array[Vector3] = []
	for s: Dictionary in p["sounds"]:
		spots.append(s["at"] as Vector3)
	counts["sound_spots"] = spots
	return counts


## One MultiMesh per model and large chunk, plus one shared terrain/house mesh
## per chunk. No colliders, audio players or placeholder boxes for missing art.
static func _build_far(parent: Node3D, g: FieldGrid, p: Dictionary, material: Material, colors: Array) -> Dictionary:
	var root := Node3D.new()
	root.name = "Far"
	parent.add_child(root)
	var surfaces: Dictionary = {}
	var groups: Dictionary = {}
	var ground := _far_ground(g, colors)
	var ground_color := ground["color"] as Color
	var ground_kind := int(ground["kind"])
	var house_count := 0
	for item: Dictionary in p["far"]:
		var at := item["at"] as Vector3
		var chunk := _far_chunk(at)
		var model := String(item["model"])
		if model == FAR_HOUSE:
			_house(_far_surface(surfaces, chunk), item, ground_color)
			house_count += 1
			continue
		var key := "%s:%d:%d" % [model, chunk.x, chunk.y]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(item)
	var prop_count := 0
	for key: String in groups:
		var instances := groups[key] as Array
		var first := instances[0] as Dictionary
		var mesh := _model_mesh(String(first["model"]))
		if mesh == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = instances.size()
		for index in instances.size():
			var item := instances[index] as Dictionary
			mm.set_instance_transform(index, Transform3D(Basis(Vector3.UP, float(item["yaw"])).scaled(item["scale"] as Vector3), item["at"] as Vector3))
		var node := MultiMeshInstance3D.new()
		var chunk := _far_chunk(first["at"] as Vector3)
		node.name = "%s_%d_%d" % [String(first["model"]).get_file().get_basename(), chunk.x, chunk.y]
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
		prop_count += instances.size()
	for plot: Dictionary in p["fields"]:
		var rect := plot["rect"] as Rect2
		if String(plot["kind"]) == "bank":
			_far_quad(surfaces, rect, 0.018, ground_color.darkened(0.05), ground_kind)
			continue
		_far_quad(surfaces, rect, 0.004, ground_color.darkened(0.05), ground_kind)
		var rows_x := bool(plot["rows_x"])
		var span := rect.size.y if rows_x else rect.size.x
		var offset := float(plot["spacing"]) * 0.5
		while offset < span - 0.2:
			var row := Rect2(rect.position + Vector2(0, offset), Vector2(rect.size.x, 0.16)) if rows_x else Rect2(rect.position + Vector2(offset, 0), Vector2(0.16, rect.size.y))
			_far_quad(surfaces, row, 0.006, ground_color.darkened(0.08), ground_kind)
			offset += float(plot["spacing"])
	for track: Dictionary in p["tracks"]:
		var depth := float(track["near"])
		while depth < float(track["far"]):
			var next_depth := minf(depth + 4.0, float(track["far"]))
			var t0 := inverse_lerp(float(track["near"]), float(track["far"]), depth)
			var t1 := inverse_lerp(float(track["near"]), float(track["far"]), next_depth)
			var half0 := float(track["width"]) * 0.5 * lerpf(1.0, 0.25, t0)
			var half1 := float(track["width"]) * 0.5 * lerpf(1.0, 0.25, t1)
			var side := int(track["side"])
			var along := float(track["along"])
			var a := _far_at(g, side, along - half0, depth) + Vector3.UP * 0.008
			var b := _far_at(g, side, along + half0, depth) + Vector3.UP * 0.008
			var c := _far_at(g, side, along + half1, next_depth) + Vector3.UP * 0.008
			var d := _far_at(g, side, along - half1, next_depth) + Vector3.UP * 0.008
			var road_color := colors[F.ROAD] as Color
			var near_color := ground_color.lerp(road_color, 0.28 * (1.0 - t0))
			var far_color := ground_color.lerp(road_color, 0.28 * (1.0 - t1))
			var st := _far_surface(surfaces, _far_chunk((a + c) * 0.5))
			var points: Array[Vector3] = [a, b, c, d]
			if side == 1 or side == 2:
				points = [b, a, d, c]
			for index: int in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP)
				st.set_color(near_color if index < 2 else far_color)
				st.set_uv(Vector2.ZERO)
				st.set_uv2(Vector2(ground_kind + 1, 0))
				st.add_vertex(points[index])
			depth = next_depth
	for chunk: Vector2i in surfaces:
		var node := MeshInstance3D.new()
		node.name = "Ground_%d_%d" % [chunk.x, chunk.y]
		node.mesh = (surfaces[chunk] as SurfaceTool).commit()
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
	return {"far": prop_count, "houses": house_count, "fields": (p["fields"] as Array).size(), "tracks": (p["tracks"] as Array).size(), "sounds": (p["sounds"] as Array).size()}


## Match the ground outside the blend without depending on map_view (which
## builds this band): indoor edge cells have a quarter of the outdoor weight.
static func _far_ground(g: FieldGrid, colors: Array) -> Dictionary:
	var cells: Array[Vector2i] = []
	for x in g.width:
		cells.append(Vector2i(x, 0))
		cells.append(Vector2i(x, g.height - 1))
	for z in range(1, g.height - 1):
		cells.append(Vector2i(0, z))
		cells.append(Vector2i(g.width - 1, z))
	var total := Color(0, 0, 0, 0)
	var weight := 0.0
	var kinds: Dictionary = {}
	var best := 0
	for cell in cells:
		var kind := g.floor_at(cell)
		var share := 0.25 if g.indoor(cell) else 1.0
		total += (colors[kind] as Color) * share
		weight += share
		kinds[kind] = float(kinds.get(kind, 0.0)) + share
	for kind: int in kinds:
		if float(kinds[kind]) > float(kinds.get(best, 0.0)):
			best = kind
	var mean := total / maxf(weight, 1.0)
	return {"color": Color(mean.r, mean.g, mean.b, 1.0), "kind": best}


static func _far_chunk(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / FAR_CHUNK), floori(at.z / FAR_CHUNK))


static func _far_surface(surfaces: Dictionary, chunk: Vector2i) -> SurfaceTool:
	if not surfaces.has(chunk):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_uv(Vector2.ZERO)
		surfaces[chunk] = st
	return surfaces[chunk] as SurfaceTool


## Split long plots at chunk boundaries so off-screen ground can be culled.
static func _far_quad(surfaces: Dictionary, rect: Rect2, y: float, color: Color, kind: int) -> void:
	for cz in range(floori(rect.position.y / FAR_CHUNK), ceili(rect.end.y / FAR_CHUNK)):
		for cx in range(floori(rect.position.x / FAR_CHUNK), ceili(rect.end.x / FAR_CHUNK)):
			var piece := rect.intersection(Rect2(float(cx) * FAR_CHUNK, float(cz) * FAR_CHUNK, FAR_CHUNK, FAR_CHUNK))
			_quad(_far_surface(surfaces, Vector2i(cx, cz)), piece, y, color, kind)


## A small box and gabled roof, baked straight into the shared chunk mesh.
static func _house(st: SurfaceTool, item: Dictionary, color: Color) -> void:
	var size := item["scale"] as Vector3
	var x := size.x * 0.5
	var z := size.z * 0.5
	var h := size.y
	var points: Array[Vector3] = [Vector3(-x, 0, -z), Vector3(x, 0, -z), Vector3(x, 0, z), Vector3(-x, 0, z),
		Vector3(-x, h, -z), Vector3(x, h, -z), Vector3(x, h, z), Vector3(-x, h, z), Vector3(-x, h + 1.4, 0), Vector3(x, h + 1.4, 0)]
	var transform := Transform3D(Basis(Vector3.UP, float(item["yaw"])), item["at"] as Vector3)
	var faces: Array = [[3, 7, 6, 2], [1, 5, 4, 0], [2, 6, 5, 1], [0, 4, 7, 3], [4, 8, 7], [6, 9, 5], [4, 5, 9, 8], [8, 9, 6, 7]]
	for face_index in faces.size():
		var face := faces[face_index] as Array
		var a := transform * points[int(face[0])]
		var normal := ((transform * points[int(face[2])]) - a).cross((transform * points[int(face[1])]) - a).normalized()
		for index in range(1, face.size() - 1):
			for corner: int in [int(face[0]), int(face[index]), int(face[index + 1])]:
				st.set_color(color.darkened(0.5 if face_index >= 6 else 0.3))
				st.set_normal(normal)
				st.set_uv(Vector2.ZERO)
				st.set_uv2(Vector2.ZERO)
				st.add_vertex(transform * points[corner])


static func _model_mesh(path: String) -> Mesh:
	if not PropModels.enabled() or not ResourceLoader.exists(path):
		return null
	var meshes := PropModels.batch_meshes(path)
	return meshes.get(0, null)


## `kind`: the floor kind, so the ground shader gives the run the map's own bare
## look (world_vis bare_ground: asphalt, sleepers' gravel); -1 none.
static func _quad(st: SurfaceTool, r: Rect2, y: float, color: Color, kind: int = -1) -> void:
	var a := Vector3(r.position.x, y, r.position.y)
	var corners := [a, a + Vector3(r.size.x, 0, 0), a + Vector3(r.size.x, 0, r.size.y), a + Vector3(0, 0, r.size.y)]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_color(color)
		st.set_normal(Vector3.UP)
		st.set_uv2(Vector2(kind + 1, 0))
		st.add_vertex(corners[idx])


static func _box(st: SurfaceTool, size: Vector3, at: Vector3, color: Color) -> void:
	var hs := size * 0.5
	var faces := [
		[Vector3(0, 1, 0), [Vector3(-hs.x, hs.y, -hs.z), Vector3(hs.x, hs.y, -hs.z), Vector3(hs.x, hs.y, hs.z), Vector3(-hs.x, hs.y, hs.z)]],
		[Vector3(0, 0, 1), [Vector3(-hs.x, -hs.y, hs.z), Vector3(-hs.x, hs.y, hs.z), Vector3(hs.x, hs.y, hs.z), Vector3(hs.x, -hs.y, hs.z)]],
		[Vector3(0, 0, -1), [Vector3(hs.x, -hs.y, -hs.z), Vector3(hs.x, hs.y, -hs.z), Vector3(-hs.x, hs.y, -hs.z), Vector3(-hs.x, -hs.y, -hs.z)]],
		[Vector3(1, 0, 0), [Vector3(hs.x, -hs.y, hs.z), Vector3(hs.x, hs.y, hs.z), Vector3(hs.x, hs.y, -hs.z), Vector3(hs.x, -hs.y, -hs.z)]],
		[Vector3(-1, 0, 0), [Vector3(-hs.x, -hs.y, -hs.z), Vector3(-hs.x, hs.y, -hs.z), Vector3(-hs.x, hs.y, hs.z), Vector3(-hs.x, -hs.y, hs.z)]],
	]
	for face in faces:
		var n: Vector3 = face[0]
		var v: Array = face[1]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(color)
			st.set_normal(n)
			st.add_vertex(at + v[idx])
