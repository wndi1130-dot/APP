extends RefCounted
## What stands round a stop map, outside its cells (결정 448 17번): bare woods
## starting just past the last walkable cell, the rails running on out of them,
## and every road ending a few metres out at sleepers or crates (지도 발주 6장:
## no wire on roads or bands; barricades are crates, sleds and sleeper piles).
## The ground and the low fog out there are fx/map_edge.gd's; this draws what
## stands on it. Nothing here is walked on: the cells end where they always did.
## The camera is held so the screen never reaches past the band (clamp_focus).

const FieldGrid = preload("res://game/world/field_grid.gd")
const PropModels = preload("res://game/world/prop_models.gd")
const F = FieldGrid.Floor

## Metres of woods drawn outside each edge; the camera may look this far out.
## The fog past the edge (fx/map_edge.gd FOG_REACH) covers all from here on.
const BAND: float = 12.0
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
## A road goes on this far past the edge before it is blocked.
const ROAD_RUN: float = 5.0
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


## Half the ground the field camera shows: across from the aspect, along from the pitch.
static func view_half(cam_size: float, aspect: float, pitch_deg: float) -> Vector2:
	return Vector2(cam_size * aspect * 0.5, cam_size * 0.5 / sin(deg_to_rad(pitch_deg)))


## The point the camera looks at, kept so its view ends inside the band.
static func clamp_focus(focus: Vector3, half: Vector2, width: int, height: int, band: float = BAND) -> Vector3:
	return Vector3(_clamp_axis(focus.x, half.x, float(width), band), focus.y, _clamp_axis(focus.z, half.y, float(height), band))


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
	return {"trees": trees, "blocks": blocks, "glades": glades, "clear": clear, "runs": runs}


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
	# metre), a hair above the ground past the edge (fx/map_edge.gd).
	var ground := SurfaceTool.new()
	ground.begin(Mesh.PRIMITIVE_TRIANGLES)
	for run: Dictionary in p["runs"]:
		var f := int(run["floor"])
		var r := run_rect(g, run, BAND if f == F.RAIL else ROAD_RUN, 0.0)
		var base: Color = colors[f]
		for yy in range(floori(r.position.y), ceili(r.end.y)):
			for xx in range(floori(r.position.x), ceili(r.end.x)):
				var col := base.darkened(0.15) if f == F.RAIL and posmod(xx, 2) == 0 else base
				_quad(ground, Rect2(xx, yy, 1, 1), 0.004, col)
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
	return {"trees": p["trees"].size(), "blocks": p["blocks"].size(), "glades": p["glades"].size(), "traces": traces, "chunks": by_chunk.size(), "runs": p["runs"].size()}


static func _model_mesh(path: String) -> Mesh:
	if not PropModels.enabled() or not ResourceLoader.exists(path):
		return null
	var meshes := PropModels.batch_meshes(path)
	return meshes.get(0, null)


static func _quad(st: SurfaceTool, r: Rect2, y: float, color: Color) -> void:
	var a := Vector3(r.position.x, y, r.position.y)
	var corners := [a, a + Vector3(r.size.x, 0, 0), a + Vector3(r.size.x, 0, r.size.y), a + Vector3(0, 0, r.size.y)]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_color(color)
		st.set_normal(Vector3.UP)
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
