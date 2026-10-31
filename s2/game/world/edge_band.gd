extends RefCounted
## What stands round a stop map and in its blocked deep forest (결정 448 17번): woods
## starting just past the last walkable cell, the rails running on out of them,
## and every road ending deep in the band at sleepers or crates (지도 발주 6장:
## no wire on roads or bands; barricades are crates, sleds and sleeper piles).
## The ground and the low fog out there are fx/map_edge.gd's; this draws what
## stands on it. Nothing here is walked on; deep forest keeps its blocked cells.
## The camera's reach is separate from the woods (clamp_focus).

const FieldGrid = preload("res://game/world/field_grid.gd")
const PropModels = preload("res://game/world/prop_models.gd")
const BuildingUses = preload("res://game/world/building_uses.gd")
const WorkSpots = preload("res://game/world/work_spots.gd")
const Atmosphere = preload("res://fx/atmosphere.gd")
const BuildPace = preload("res://game/world/build_pace.gd")
const F = FieldGrid.Floor

## Metres of woods drawn outside each edge, independent of the camera's reach.
const BAND: float = 12.0
## The map's own always-visible tree rows occupy the first six metres of forest.
## Kept equal to StopGround.REMOTE_FOREST_EDGE by test (no circular preload).
const FOREST_ROWS: int = 6
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
## The first rows, close and thick, read as the end of the way: young spruce and
## thicket, low enough not to hide the cells behind them from the tilted camera
## (35°: a tree hides about 1.4 times its height of ground behind it).
const INNER_ROW: float = 2.6
const FELL_SPAN: int = 8
const YOUNG_TALL := Vector2(1.8, 3.4)
## Past them the tall woods, taller deeper in (full height CANOPY_RAMP metres past
## INNER_ROW), so the edge reads as a forest's edge and the tall crowns stand back.
const CANOPY_TALL := Vector2(4.6, 8.5)
const CANOPY_RAMP: float = 5.0
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

## The woods' models. Each tree is made on a one-cell footprint (1 m across at 4~5 m
## tall), too thin for a crown: SPREAD widens it across so neighbouring crowns meet
## and the woods read as one mass from the tilted camera (user 10-28). Spruce is the
## body of the woods; the leafless broadleaf is mixed in (user 10-28).
const SPRUCE := "res://models/props_field/spruce.glb"
const BROADLEAF := "res://models/props_common/bare_tree.glb"
const ORCHARD := "res://models/props_field/bare_orchard_tree.glb"
const STREET := "res://models/props_field/street_tree.glb"
const THICKET := "res://models/props_field/thicket.glb"
const SPREAD: Dictionary = {SPRUCE: 1.9, BROADLEAF: 2.0, ORCHARD: 2.0, STREET: 2.0}
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

## How thick the woods stand by what the place is (결정 478: map group -> region):
## forest and mountain stops dense, town stops thin with fruit and street trees, the
## rail works between (user 10-28; a place with no group is "mixed").
const PROFILE_OF: Dictionary = {
	"mountain_works": "dense", "high_mountain": "dense", "waterside": "dense", "bare_line": "dense",
	"rail_works": "mixed", "town": "town",
}
## Per layer the jittered lattice's spacing and the share of its points left empty.
## young: the share of the first rows that is young spruce (the rest thicket or bush).
## conifer: the least share of spruce among the tall trees; the region band's own share
## wins when higher (Atmosphere.REGIONS, from seasons_regions.md 5장). far: the share
## of the far ground under woods (_far_woods), before the region band's forest share.
const PROFILES: Dictionary = {
	"dense": {"edge": 1.5, "edge_skip": 0.1, "young": 0.55, "canopy": 2.2, "canopy_skip": 0.04, "conifer": 0.7,
		"under": 3.0, "under_skip": 0.25, "far": 0.75, "far_fields": 1},
	"mixed": {"edge": 1.8, "edge_skip": 0.25, "young": 0.5, "canopy": 2.8, "canopy_skip": 0.12, "conifer": 0.6,
		"under": 3.6, "under_skip": 0.35, "far": 0.4, "far_fields": 3},
	"town": {"edge": 2.2, "edge_skip": 0.3, "young": 0.2, "canopy": 3.6, "canopy_skip": 0.2, "conifer": 0.15,
		"under": 4.0, "under_skip": 0.4, "far": 0.0, "far_fields": 3},
}
## What grows low under the tall trees, by weight; town edges are bush, not thicket.
const UNDER: Dictionary = {
	"dense": [[THICKET, 0.35], [FAR_GRASS, 0.35], [FAR_BUSH, 0.18], [LOG_MODEL, 0.12]],
	"mixed": [[THICKET, 0.3], [FAR_GRASS, 0.4], [FAR_BUSH, 0.22], [LOG_MODEL, 0.08]],
	"town": [[FAR_GRASS, 0.5], [FAR_BUSH, 0.35], [THICKET, 0.15]],
}
## A town's tall trees that are not spruce: fruit trees, street trees, a few others.
const TOWN_TREES: Array = [[ORCHARD, 0.5], [STREET, 0.35], [BROADLEAF, 0.15]]
## Past the band the woods go on in stands out to FAR_WOODS, where the edge fog is
## about whole (MapEdge.fog_reach at the default reach), kept where a noise is under
## the place's share so clearings open between the stands: closer in the ring the
## camera shows (BAND to VIEW_BAND), thinner past it.
const FAR_WOODS: float = 34.0
const FAR_WOODS_SPACING := Vector2(3.0, 4.2)
const FAR_WOODS_TALL := Vector2(5.0, 9.0)


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


## How the woods round this map grow: {profile (PROFILES), conifer (share of spruce
## among tall trees), forest (the region band's forest share)}. The region band is
## the stretch's (field_game puts it in the map's data as "region_band").
static func look_of(data: Dictionary) -> Dictionary:
	var profile := String(PROFILE_OF.get(BuildingUses.region_of(String(data.get("place_id", ""))), "mixed"))
	var band := Atmosphere.region(String(data.get("region_band", "")))
	var least := float(PROFILES[profile]["conifer"])
	var conifer := least
	if profile != "town":
		var wood := float(band["conifer"]) + float(band["birch"])
		conifer = maxf(least, float(band["conifer"]) / maxf(wood, 0.01))
	return {"profile": profile, "conifer": conifer, "forest": float(band["forest"])}


## Everything plan() reads: of the map only its size and where roads and rails cross
## its edges and the deep forest, of the data the place (seed) and region band (look).
static func plan_key(g: FieldGrid, seed: int, look: Dictionary, forest: Array = []) -> Dictionary:
	return {"size": Vector2i(g.width, g.height), "openings": openings(g), "seed": seed, "look": look,
		"deep_forest": forest.duplicate()}


## The plan made ahead off the main thread (stop_loader.make_ready), with the key it
## was made from: {key, plan}. build() uses it only while the key still fits; a field
## given another region band than the loader saw plans again on the main thread.
static func plan_ahead(d: Dictionary) -> Dictionary:
	var g: FieldGrid = d["grid"]
	var seed := seed_of(d)
	var look := look_of(d)
	var forest: Array = d.get("deep_forest", [])
	return {"key": plan_key(g, seed, look, forest), "plan": plan(g, seed, look, forest)}


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
				# Rails as the map draws them (track_view.gd runs: the rail floor alone), so the
				# rails out of the map meet those in it even where a car stands on the last cell.
				if kind == F.RAIL or (kind == F.ROAD and g.people_can_walk(c)):
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


static func _forest_cell(forest: Array, c: Vector2i) -> bool:
	for rect: Rect2i in forest:
		if rect.has_point(c):
			return true
	return false


## Outside points start their depth at the nearest map cell, including corners.
static func _forest_origin(g: FieldGrid, forest: Array, x: float, z: float) -> bool:
	return _forest_cell(forest, Vector2i(clampi(floori(x), 0, g.width - 1), clampi(floori(z), 0, g.height - 1)))


## Open parts of each rectangle's sides. A map edge or another forest rectangle
## closes a side; partial neighbours close only their part, with no false seam.
## Prepare once per plan/build, rather than scanning border cells for every tree.
static func _forest_borders(g: FieldGrid, forest: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rect: Rect2i in forest:
		var edges: Array[Rect2] = []
		for side: int in 4:
			var vertical: bool = side < 2
			var length: int = rect.size.y if vertical else rect.size.x
			var start: int = -1
			for along: int in range(length + 1):
				var c := Vector2i(rect.position.x - 1 if side == 0 else rect.end.x, rect.position.y + along) if vertical \
					else Vector2i(rect.position.x + along, rect.position.y - 1 if side == 2 else rect.end.y)
				var open: bool = along < length and g.inside(c) and not _forest_cell(forest, c)
				if open and start < 0:
					start = along
				elif not open and start >= 0:
					var at := Vector2(rect.position.x if side == 0 else rect.end.x, rect.position.y + start) if vertical \
						else Vector2(rect.position.x + start, rect.position.y if side == 2 else rect.end.y)
					var size := Vector2(0, along - start) if vertical else Vector2(along - start, 0)
					edges.append(Rect2(at, size))
					start = -1
		out.append({"rect": rect, "edges": edges})
	return out


## Distance past the map's tree rows, continuing unchanged over a wooded map edge.
## A sealed rectangle has infinite depth and grows nothing before the fog limit.
## `borders` is the optional precomputed _forest_borders result.
static func woods_depth(g: FieldGrid, forest: Array, x: float, z: float, borders: Array[Dictionary] = []) -> float:
	var depth: float = outside(g, x, z)
	if forest.is_empty() or not _forest_origin(g, forest, x, z):
		return depth
	var source := Vector2(clampf(x, 0.0, float(g.width)), clampf(z, 0.0, float(g.height)))
	var cell := Vector2i(clampi(floori(x), 0, g.width - 1), clampi(floori(z), 0, g.height - 1))
	var sides: Array[Dictionary] = borders if not borders.is_empty() else _forest_borders(g, forest)
	var inside: float = INF
	for part: Dictionary in sides:
		if not (part["rect"] as Rect2i).has_point(cell):
			continue
		for edge: Rect2 in part["edges"]:
			var nearest := Vector2(clampf(source.x, edge.position.x, edge.end.x), clampf(source.y, edge.position.y, edge.end.y))
			inside = minf(inside, source.distance_to(nearest))
	return maxf(depth, 0.0) + inside - float(FOREST_ROWS)


## Everything the band places, the same for the same map: trees {at, yaw, model,
## height and spread, or scale for what grows low}, blocks {at, yaw, model}, the clear
## corridors and the openings they come from. `look`: look_of, "mixed" when empty.
static func plan(g: FieldGrid, seed: int, look: Dictionary = {}, forest: Array = []) -> Dictionary:
	var lk := look if not look.is_empty() else look_of({})
	var profile: Dictionary = PROFILES[lk["profile"]]
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
	_scatter(g, rng, no_trees, trees, float(profile["edge"]), TRUNK_GAP, INNER_ROW, "edge", lk)
	_scatter(g, rng, no_trees, trees, float(profile["canopy"]), INNER_ROW, BAND, "canopy", lk)
	_scatter(g, rng, no_trees, trees, float(profile["under"]), INNER_ROW, BAND, "under", lk)
	# New scenery never consumes a draw from the woods or the glades.
	var distant := _far_plan(g, seed, runs, lk)
	var p := {"trees": trees, "blocks": blocks, "glades": glades, "clear": clear, "runs": runs,
		"far": distant["far"], "fields": distant["fields"], "tracks": distant["tracks"], "sounds": distant["sounds"]}
	if not forest.is_empty():
		# All legacy draws and indices above stay intact. Hide only the entries whose
		# starting cell is forest; replacement woods use their own draw, appended last.
		for key: String in ["trees", "glades", "far", "fields"]:
			_skip_forest(g, forest, p[key])
		trees.append_array(_forest_trees(g, seed, clear, lk, forest))
	return p


static func _skip_forest(g: FieldGrid, forest: Array, items: Array) -> void:
	for item: Dictionary in items:
		var at: Vector2
		if item.has("at"):
			var world: Vector3 = item["at"]
			at = Vector2(world.x, world.z)
		else:
			at = (item["rect"] as Rect2).get_center()
		if _forest_origin(g, forest, at.x, at.y):
			item["skip"] = true


## Continuous canopy rather than the glades and noisy far-woods stands. Only the
## first band gets young trees/undergrowth; deeper crowns are taller and spaced 25% further apart.
static func _forest_trees(g: FieldGrid, seed: int, clear: Array[Rect2], look: Dictionary, forest: Array) -> Array:
	var trees: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(seed) + ":deep_forest")
	var borders := _forest_borders(g, forest)
	var profile: Dictionary = PROFILES[look["profile"]]
	_scatter_forest(g, rng, clear, trees, float(profile["edge"]), TRUNK_GAP, INNER_ROW, "edge", look, forest, borders)
	_scatter_forest(g, rng, clear, trees, float(profile["canopy"]), INNER_ROW, BAND, "canopy", look, forest, borders)
	_scatter_forest(g, rng, clear, trees, float(profile["under"]), INNER_ROW, BAND, "under", look, forest, borders)
	_scatter_forest(g, rng, clear, trees, float(profile["canopy"]) * 1.25, BAND, FAR_WOODS, "canopy", look, forest, borders)
	return trees


static func _scatter_forest(g: FieldGrid, rng: RandomNumberGenerator, clear: Array[Rect2], trees: Array, spacing: float, near: float, far: float, layer: String, look: Dictionary, forest: Array, borders: Array[Dictionary]) -> void:
	var z: float = -far
	while z < float(g.height) + far:
		var x: float = -far
		while x < float(g.width) + far:
			var px: float = x + spacing * 0.5
			var pz: float = z + spacing * 0.5
			var middle: float = woods_depth(g, forest, px, pz, borders)
			if not _forest_origin(g, forest, px, pz) or middle < near - spacing or middle > far + spacing:
				x += spacing
				continue
			px += rng.randf_range(-0.42, 0.42) * spacing
			pz += rng.randf_range(-0.42, 0.42) * spacing
			var yaw: float = rng.randf() * TAU
			var roll: float = rng.randf()
			var pick: float = rng.randf()
			var size: float = rng.randf()
			var d: float = woods_depth(g, forest, px, pz, borders)
			var start: float = near if near > TRUNK_GAP else _edge_start(px, pz, rng.seed)
			if _forest_origin(g, forest, px, pz) and d >= start and d < far and not _in_any(clear, px, pz):
				var item := _pick(layer, look, d, roll, pick, size)
				if not item.is_empty():
					if layer == "canopy" and near >= BAND:
						item["height"] = lerpf(lerpf(CANOPY_TALL.x, CANOPY_TALL.y, 0.75), CANOPY_TALL.y, size)
					item["at"] = Vector3(px, 0, pz)
					item["yaw"] = yaw
					trees.append(item)
			x += spacing
		z += spacing


## Work from the same plan build() draws. Corner trees belong to one side, with
## their projection clamped to that side's last span; their plan indices stay intact.
static func fell_groves(g: FieldGrid, p: Dictionary, data: Dictionary) -> Array:
	var trees: Array = p.get("trees", []) as Array
	var spans: Dictionary = {}
	for plan_idx: int in range(trees.size()):
		var tree: Dictionary = trees[plan_idx] as Dictionary
		if bool(tree.get("skip", false)) or not tree.has("height"):
			continue
		var at: Vector3 = tree["at"] as Vector3
		var depth: float = outside(g, at.x, at.z)
		if depth <= 0.0 or depth > INNER_ROW:
			continue
		var side: int = _side_of(g, at)
		var length: int = g.height if side < 2 else g.width
		var along: float = at.z if side < 2 else at.x
		var projection: int = clampi(floori(along), 0, length - 1)
		var key: Vector2i = Vector2i(side, floori(float(projection) / float(FELL_SPAN)))
		if not spans.has(key):
			var indices: Array[int] = []
			spans[key] = indices
		(spans[key] as Array[int]).append(plan_idx)
	var field: PackedInt32Array = PackedInt32Array()
	var candidates: Array[Dictionary] = []
	for key: Vector2i in spans:
		var indices: Array[int] = spans[key] as Array[int]
		if indices.size() < 6:
			continue
		var stand: Array[Vector2i] = []
		var nearest: float = -1.0
		var length: int = g.height if key.x < 2 else g.width
		for along: int in range(key.y * FELL_SPAN, mini((key.y + 1) * FELL_SPAN, length)):
			var cell: Vector2i = _edge_cell(g, key.x, along)
			if not g.people_can_walk(cell):
				continue
			if field.is_empty():
				field = WorkSpots.field_of(data)
			var distance: float = WorkSpots.reach(data, cell, field)
			if distance < 0.0:
				continue
			stand.append(cell)
			if nearest < 0.0 or distance < nearest:
				nearest = distance
		if stand.is_empty():
			continue
		var cells: Array[Vector2i] = []
		for plan_idx: int in indices:
			var tree: Dictionary = trees[plan_idx] as Dictionary
			cells.append(FieldGrid.cell_of(tree["at"] as Vector3))
		var grove: Dictionary = {"kind": "fell", "cells": cells, "stand": stand,
			"trees": indices.size(), "level": 0, "edge": true, "plan_idx": indices}
		candidates.append({"grove": grove, "path_m": nearest, "order": candidates.size()})
	candidates.sort_custom(_fell_nearer)
	var out: Array = []
	for i: int in range(mini(2, candidates.size())):
		out.append(candidates[i]["grove"])
	return out


static func _fell_nearer(a: Dictionary, b: Dictionary) -> bool:
	if float(a["path_m"]) == float(b["path_m"]):
		return int(a["order"]) < int(b["order"])
	return float(a["path_m"]) < float(b["path_m"])


## Scenery {at, yaw, scale (trees: height and spread), model, side}; houses use
## dimensions as their scale.
## Corridors continue to the far edge, without changing the near woods' clear list.
static func _far_plan(g: FieldGrid, seed: int, runs: Array, look: Dictionary) -> Dictionary:
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
				# A town's groves are willow and fruit trees; elsewhere the woods' own
				# trees, from as many draws, so the rest of the far ground stays put.
				if String(look["profile"]) == "town":
					_far_prop(scenery, at, side, FAR_TREES[rng.randi_range(0, FAR_TREES.size() - 1)], rng)
				else:
					_far_tree(scenery, at, side, SPRUCE if rng.randf() < float(look["conifer"]) else BROADLEAF, rng)
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
	var fields := _far_fields(g, seed, corridors, int(PROFILES[look["profile"]]["far_fields"]))
	var cover := _ring_cover(g, seed, corridors)
	scenery.append_array(cover["props"])
	for bank: Dictionary in cover["banks"]:
		if _far_plot_clear(bank["rect"] as Rect2, corridors, fields):
			fields.append(bank)
	scenery.append_array(_far_woods(g, seed, corridors, fields, houses, look))
	return {"far": scenery, "fields": fields, "tracks": tracks, "sounds": _far_sounds(g, seed, rails)}


## The woods going on past the band (FAR_WOODS*), from their own draw: stands where a
## noise is under the place's share, none on a corridor, a plot or near a house.
static func _far_woods(g: FieldGrid, seed: int, corridors: Array[Rect2], plots: Array[Dictionary], houses: Array[Vector3], look: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var share := float(PROFILES[look["profile"]]["far"]) * (0.6 + 0.5 * float(look["forest"]))
	if share <= 0.0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(seed) + ":woods")
	var noise := FastNoiseLite.new()
	noise.seed = posmod(seed, 100000)
	noise.frequency = 0.05
	var rings := [[BAND, VIEW_BAND, FAR_WOODS_SPACING.x, share], [VIEW_BAND, FAR_WOODS, FAR_WOODS_SPACING.y, share * 0.65]]
	for ring: Array in rings:
		var near := float(ring[0])
		var far := float(ring[1])
		var spacing := float(ring[2])
		var z := -far
		while z < float(g.height) + far:
			var x := -far
			while x < float(g.width) + far:
				if outside(g, x + spacing * 0.5, z + spacing * 0.5) < near - spacing:
					x += spacing
					continue
				var at := Vector3(x + spacing * (0.5 + rng.randf_range(-0.42, 0.42)), 0, z + spacing * (0.5 + rng.randf_range(-0.42, 0.42)))
				var yaw := rng.randf() * TAU
				var size := rng.randf()
				var pick := rng.randf()
				x += spacing
				var depth := outside(g, at.x, at.z)
				if depth < near or depth >= far or noise.get_noise_2d(at.x, at.z) * 0.5 + 0.5 > float(ring[3]):
					continue
				if not _far_empty(g, at, 1.2, corridors) or _near_house(houses, at, 7.0) or _on_plot(plots, at, 1.5):
					continue
				var model := SPRUCE if pick < float(look["conifer"]) else BROADLEAF
				out.append({"at": at, "yaw": yaw, "height": lerpf(FAR_WOODS_TALL.x, FAR_WOODS_TALL.y, size), "spread": SPREAD[model],
					"model": model, "side": _side_of(g, at)})
			z += spacing
	return out


static func _near_house(houses: Array[Vector3], at: Vector3, reach: float) -> bool:
	for h in houses:
		if h.distance_to(at) < reach:
			return true
	return false


static func _on_plot(plots: Array[Dictionary], at: Vector3, pad: float) -> bool:
	for p in plots:
		if (p["rect"] as Rect2).grow(pad).has_point(Vector2(at.x, at.z)):
			return true
	return false


## Which side's far ground a point lies on (0 west 1 east 2 north 3 south); a corner
## square goes with the side it lies further out from.
static func _side_of(g: FieldGrid, at: Vector3) -> int:
	var dx := maxf(-at.x, at.x - float(g.width))
	var dz := maxf(-at.z, at.z - float(g.height))
	if dx >= dz:
		return 0 if at.x < 0.0 else 1
	return 2 if at.z < 0.0 else 3


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


## A tree of the woods out there, by height and crown (SPREAD), from two draws like _far_prop.
static func _far_tree(scenery: Array[Dictionary], at: Vector3, side: int, model: String, rng: RandomNumberGenerator) -> void:
	var tall := rng.randf_range(FAR_WOODS_TALL.x, FAR_WOODS_TALL.y)
	scenery.append({"at": at, "yaw": rng.randf_range(0.0, TAU), "height": tall, "spread": SPREAD[model], "model": model, "side": side})


## Axis-aligned plots and a few low snow banks; leave gaps between the plots.
static func _far_fields(g: FieldGrid, seed: int, corridors: Array[Rect2], most: int = 3) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(seed) + ":fields")
	var plots: Array[Dictionary] = []
	for side in 4:
		var length := float(g.height if side < 2 else g.width)
		var wanted := mini(rng.randi_range(1, 3), most)
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


## A jittered lattice over the ring between `near` and `far` metres outside; what each
## point there grows is the layer's (_pick), or nothing. Every point takes the same
## draws, so one layer's choices never move another's points; lattice cells too far
## in to reach the ring take none (most of the lattice: the plan is built on the way in).
static func _scatter(g: FieldGrid, rng: RandomNumberGenerator, clear: Array[Rect2], trees: Array, spacing: float, near: float, far: float, layer: String, look: Dictionary) -> void:
	var lo := -far
	var hi_x := float(g.width) + far
	var hi_z := float(g.height) + far
	var z := lo
	while z < hi_z:
		var x := lo
		while x < hi_x:
			if outside(g, x + spacing * 0.5, z + spacing * 0.5) < near - spacing:
				x += spacing
				continue
			var px := x + spacing * 0.5 + rng.randf_range(-0.42, 0.42) * spacing
			var pz := z + spacing * 0.5 + rng.randf_range(-0.42, 0.42) * spacing
			var yaw := rng.randf() * TAU
			var roll := rng.randf()
			var pick := rng.randf()
			var size := rng.randf()
			var d := outside(g, px, pz)
			var start := near if near > TRUNK_GAP else _edge_start(px, pz, rng.seed)
			if d >= start and d < far and not _in_any(clear, px, pz):
				var item := _pick(layer, look, d, roll, pick, size)
				if not item.is_empty():
					item["at"] = Vector3(px, 0, pz)
					item["yaw"] = yaw
					trees.append(item)
			x += spacing
		z += spacing


## What a layer grows at `d` metres out: {} (the point stays empty, `roll`), else
## {model, height, spread} for a tree or {model, scale} for what grows low.
static func _pick(layer: String, look: Dictionary, d: float, roll: float, pick: float, size: float) -> Dictionary:
	var name := String(look["profile"])
	var profile: Dictionary = PROFILES[name]
	match layer:
		"edge":
			if roll < float(profile["edge_skip"]):
				return {}
			var young := float(profile["young"])
			if pick < young:
				return _tree(SPRUCE, lerpf(YOUNG_TALL.x, YOUNG_TALL.y, size))
			var bush := THICKET if name != "town" or (pick - young) / (1.0 - young) < 0.4 else FAR_BUSH
			return {"model": bush, "scale": lerpf(0.7, 1.2, size)}
		"canopy":
			if roll < float(profile["canopy_skip"]):
				return {}
			var tall := lerpf(CANOPY_TALL.x, CANOPY_TALL.y, clampf((d - INNER_ROW) / CANOPY_RAMP, 0.0, 1.0)) * lerpf(0.7, 1.0, size)
			var conifer := float(look["conifer"])
			if pick < conifer:
				return _tree(SPRUCE, tall)
			if name != "town":
				return _tree(BROADLEAF, tall)
			var other := _weighted(TOWN_TREES, (pick - conifer) / (1.0 - conifer))
			return _tree(other, tall * (0.55 if other == ORCHARD else 0.85))
	if roll < float(profile["under_skip"]):
		return {}
	return {"model": _weighted(UNDER[name], pick), "scale": lerpf(0.8, 1.3, size)}


static func _tree(model: String, tall: float) -> Dictionary:
	return {"model": model, "height": tall, "spread": SPREAD[model]}


## The model whose share of the weights `t` (0~1) falls in.
static func _weighted(table: Array, t: float) -> String:
	var total := 0.0
	for row: Array in table:
		total += float(row[1])
	var at := t * total
	for row: Array in table:
		at -= float(row[1])
		if at < 0.0:
			return String(row[0])
	return String(table[-1][0])


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
## build log and the tests. With a staged build's `pace` it rests between pieces
## (build_pace.gd), so a stop being made ready never stops the screen for the woods.
## A map torn down while it rests (the stop left) is not built on: the band stops
## there and makes nothing more.
static func build(parent: Node3D, g: FieldGrid, data: Dictionary, material: Material, colors: Array, pace = null) -> Dictionary:
	var seed := seed_of(data)
	var look := look_of(data)
	var forest: Array = data.get("deep_forest", [])
	var borders := _forest_borders(g, forest)
	# The plan made ahead on the stop loader's worker (plan_ahead), read once, when it
	# was made from the same inputs; else made here, on the main thread.
	var ahead: Dictionary = data.get("_edge_plan", {})
	data.erase("_edge_plan")
	var planned_ahead: bool = not ahead.is_empty() and ahead["key"] == plan_key(g, seed, look, forest)
	var p: Dictionary = (ahead["plan"] as Dictionary) if planned_ahead else plan(g, seed, look, forest)
	var root := Node3D.new()
	root.name = "EdgeBand"
	parent.add_child(root)
	# Roads and rails run on out in their own colour, a hair above the ground past the
	# edge (fx/map_edge.gd). Roads end at their block; rails go on through the far ground
	# into the fog, past the camera's reach. Their sleepers and rails are the map's
	# (track_view.gd, from rail_runs).
	var ground := SurfaceTool.new()
	ground.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rail_runs: Array[Rect2] = []
	for run: Dictionary in p["runs"]:
		var f := int(run["floor"])
		var r := run_rect(g, run, FAR_REACH if f == F.RAIL else ROAD_RUN, 0.0)
		if f == F.RAIL:
			rail_runs.append(r)
		var base: Color = colors[f]
		for yy in range(floori(r.position.y), ceili(r.end.y)):
			for xx in range(floori(r.position.x), ceili(r.end.x)):
				_quad(ground, Rect2(xx, yy, 1, 1), 0.004, base, f)
	if not p["runs"].is_empty():
		var ground_node := MeshInstance3D.new()
		ground_node.name = "Runs"
		ground_node.mesh = ground.commit()
		ground_node.material_override = material
		ground_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ground_node)
	await BuildPace.rest(pace)
	if not is_instance_valid(root):
		return {}
	# Trees and what grows under them. Only the first rows' spruce throw a shadow, on the
	# ground people walk (SHADE_DEPTH): they go in CHUNK pieces here. Every other plant
	# throws none and is batched with the far ground by model in its larger pieces
	# (_build_far), so the woods' many models add few draws. Without its model a tree
	# is the grey trunk and crown the map uses, here; what grows low is left out.
	var meshes: Dictionary = {}
	var with_far: Array = []
	var groups: Dictionary = {}
	var tree_count: int = 0
	for t: Dictionary in p["trees"]:
		if bool(t.get("skip", false)):
			continue
		tree_count += 1
		var at: Vector3 = t["at"]
		var model := String(t["model"])
		if not meshes.has(model):
			meshes[model] = _model_mesh(model)
		var shade := woods_depth(g, forest, at.x, at.z, borders) <= SHADE_DEPTH
		if meshes[model] != null and not (model == SPRUCE and shade):
			with_far.append(t)
			continue
		if meshes[model] == null and not t.has("height"):
			continue
		var cell := _chunk(at)
		var key := "%s|%d|%d|%d" % [model, cell.x, cell.y, 0 if shade else 1]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(t)
	for key: String in groups:
		var parts := key.split("|")
		var model := parts[0]
		var list: Array = groups[key]
		var mesh: Mesh = meshes[model]
		var node: GeometryInstance3D
		if mesh:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = list.size()
			var mesh_h := maxf(mesh.get_aabb().size.y, 0.01)
			for i in list.size():
				mm.set_instance_transform(i, _plant_transform(list[i], mesh_h))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			node = mmi
		else:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for t: Dictionary in list:
				var tall := float(t["height"])
				_box(st, Vector3(0.4, tall * 0.55, 0.4), t["at"] + Vector3(0, tall * 0.275, 0), Color(0.3, 0.26, 0.22))
				_box(st, Vector3(2.0, tall * 0.4, 2.0), t["at"] + Vector3(0, tall * 0.75, 0), Color(0.62, 0.66, 0.66))
			var mi := MeshInstance3D.new()
			mi.mesh = st.commit()
			mi.material_override = material
			node = mi
		var label := "Trees" if model == SPRUCE else model.get_file().get_basename()
		node.name = "%s_%s_%s_%s" % [label, parts[1], parts[2], parts[3]]
		if parts[3] == "1":
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
		await BuildPace.rest(pace)
		if not is_instance_valid(root):
			return {}
	var traces := 0
	var glade_count: int = 0
	for gl: Dictionary in p["glades"]:
		if bool(gl.get("skip", false)):
			continue
		glade_count += 1
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
	var counts := {"trees": tree_count, "blocks": (p["blocks"] as Array).size(), "glades": glade_count, "traces": traces, "chunks": groups.size(), "runs": (p["runs"] as Array).size(), "planned_ahead": planned_ahead}
	await BuildPace.rest(pace)
	if not is_instance_valid(root):
		return {}
	counts.merge(await _build_far(root, g, p, material, colors, with_far, pace))
	# Where the danger past the woods is heard (field_audio.gd, the edge bed).
	var spots: Array[Vector3] = []
	for s: Dictionary in p["sounds"]:
		spots.append(s["at"] as Vector3)
	counts["sound_spots"] = spots
	counts["rail_runs"] = rail_runs
	# The band's groves are this build's: a band drawn again replaces them.
	var groves: Array = []
	for grove: Dictionary in data.get("fell_groves", []) as Array:
		if not bool(grove.get("edge", false)):
			groves.append(grove)
	groves.append_array(fell_groves(g, p, data))
	data["fell_groves"] = groves
	return counts


## One MultiMesh per model and large chunk, plus one shared terrain/house mesh
## per chunk. No colliders, audio players or placeholder boxes for missing art.
## `plants`: the band's woods that throw no shadow, batched with these by model.
## Rests between pieces with a staged build's `pace`, as build() does.
static func _build_far(parent: Node3D, g: FieldGrid, p: Dictionary, material: Material, colors: Array, plants: Array = [], pace = null) -> Dictionary:
	var root := Node3D.new()
	root.name = "Far"
	parent.add_child(root)
	var surfaces: Dictionary = {}
	var groups: Dictionary = {}
	var ground := _far_ground(g, colors)
	var ground_color := ground["color"] as Color
	var ground_kind := int(ground["kind"])
	var house_count := 0
	for item: Dictionary in (p["far"] as Array) + plants:
		if bool(item.get("skip", false)):
			continue
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
		var mesh_h := maxf(mesh.get_aabb().size.y, 0.01)
		for index in instances.size():
			var item := instances[index] as Dictionary
			mm.set_instance_transform(index, _plant_transform(item, mesh_h))
		var node := MultiMeshInstance3D.new()
		var chunk := _far_chunk(first["at"] as Vector3)
		node.name = "%s_%d_%d" % [String(first["model"]).get_file().get_basename(), chunk.x, chunk.y]
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
		prop_count += instances.size()
		await BuildPace.rest(pace)
		if not is_instance_valid(root):
			return {}
	var field_count: int = 0
	for plot: Dictionary in p["fields"]:
		if bool(plot.get("skip", false)):
			continue
		field_count += 1
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
		await BuildPace.rest(pace)
		if not is_instance_valid(root):
			return {}
	# far_pieces: every piece drawn out there (each model's batches and the ground), for
	# comparing what the band costs to draw beside chunks (the band's own pieces).
	return {"far": prop_count, "far_pieces": root.get_child_count(), "houses": house_count, "fields": field_count, "tracks": (p["tracks"] as Array).size(), "sounds": (p["sounds"] as Array).size()}


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


## A plant's place: a tree stands `height` metres tall with its crown widened by
## `spread`; anything else is scaled by `scale` (a number, or a Vector3 out far).
static func _plant_transform(t: Dictionary, mesh_h: float) -> Transform3D:
	var s := Vector3.ONE
	if t.has("height"):
		var up := float(t["height"]) / mesh_h
		var across := up * float(t["spread"])
		s = Vector3(across, up, across)
	else:
		var scale: Variant = t.get("scale", 1.0)
		s = scale as Vector3 if scale is Vector3 else Vector3.ONE * float(scale)
	return Transform3D(Basis(Vector3.UP, float(t["yaw"])).scaled(s), t["at"] as Vector3)


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
