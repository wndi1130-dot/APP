extends RefCounted
## How a piece of each kind of land along the line is laid (결정 495, presentation_motion.md
## 7b 지역 키트, seasons_regions.md 5장). K1, the Greater Poland lake plain: a wood of pine
## and birch, the lake shore with its reeds, a boat on blocks and a landing stage, the
## ploughed field with the drain along the line and a willow row, and the red-brick
## village edge with barns, gardens, the crossing hut and one church tower; the
## telegraph line beats time along all of them (no catenary on the Polish side). A
## neutral piece (the border fields) is dressed bare: woods, shore and fields only, no
## house, boat, landing stage, cart or sign.
##
## The frame: x along the line from the piece's start, z across it (0 the line, +z the
## train camera's side), y up from the rails' top. The camera's side is kept low near
## the line (NEAR_CLEAR) so nothing stands between the camera and the cars. The open
## models (CC0, the field's) go in one MultiMesh a model a block; the ground and the
## buildings are one vertex-coloured mesh each, snowed and wetted the way the stop
## scene colours its ground. Looks only.

const PropModels = preload("res://game/world/prop_models.gd")
const MapView = preload("res://game/world/map_view.gd")

const FIELD := "res://models/props_field/%s.glb"
const COMMON := "res://models/props_common/%s.glb"
## How far the land is laid out from the line on each side (the diagonal view sees
## about ±30 m; the rest is for the camera pulled back and the stop scene).
const LAND_W: float = 46.0
## The fields' height under the rails' top: the line runs on a low bank.
const FIELD_Y: float = -0.85
## Nothing taller than NEAR_LOW stands nearer the camera's side of the line than
## NEAR_CLEAR (a 12 m tree there would cover the cars from the diagonal view).
const NEAR_CLEAR: float = 22.0
const NEAR_LOW: float = 2.6
## The telegraph line on the far side: a pole every POLE_STEP metres of the route.
const POLE_STEP: float = 45.0
const POLE_Z: float = -7.4
const POLE_H: float = 7.2
## A MultiMesh covers this much of the line (finer than a piece, so a piece half in
## sight does not draw all its trees).
const BLOCK_M: float = 60.0
## Out to here the far band (opts far) lays its woods and tree lines.
const FAR_W: float = 150.0
## Seen from far enough, the small things are not drawn.
const SMALL_RANGE: float = 90.0
## The models and how tall they stand here (the field's are made for its own grid).
const TALL: Dictionary = {
	"spruce": Vector2(9.5, 15.0), "bare_tree": Vector2(8.0, 12.5), "bare_willow": Vector2(5.5, 8.5),
	"street_tree": Vector2(6.0, 8.5), "bare_orchard_tree": Vector2(3.2, 4.6), "thicket": Vector2(1.4, 2.4),
	"dry_bush": Vector2(0.5, 0.9), "dry_grass": Vector2(0.35, 0.6), "reed_clump": Vector2(0.9, 1.6),
	"frozen_reeds": Vector2(0.7, 1.2), "stump_cluster": Vector2(0.4, 0.6), "fallen_log": Vector2(0.55, 0.75),
	"boat_on_blocks": Vector2(1.2, 1.3), "overturned_boat": Vector2(1.0, 1.1), "pier_deck": Vector2(0.18, 0.2),
	"mooring_post": Vector2(0.9, 1.0), "fieldstone_wall": Vector2(1.0, 1.25), "hedge": Vector2(1.0, 1.5),
	"farm_cart": Vector2(1.05, 1.15), "hay_cart": Vector2(1.15, 1.3), "plank_fence": Vector2(1.1, 1.3),
	"garden_bed": Vector2(0.3, 0.4), "car": Vector2(1.15, 1.25), "wrecked_car_cluster": Vector2(1.1, 1.25),
	"pickup_truck": Vector2(1.25, 1.4), "lamp_post": Vector2(3.6, 4.2), "power_pole": Vector2(POLE_H, POLE_H),
	"firewood_stack": Vector2(1.0, 1.2), "water_barrel": Vector2(1.0, 1.15), "log_pile": Vector2(1.0, 1.2),
	"rubble_heap": Vector2(0.6, 0.9), "stone_wall_segment": Vector2(1.0, 1.2), "gap_gate": Vector2(1.2, 1.35),
	"signal_post": Vector2(3.1, 3.3), "net_drying_rack": Vector2(1.1, 1.3),
}
const IN_COMMON: Array = ["bare_tree"]
const SMALL: Array = ["dry_grass", "dry_bush", "stump_cluster", "frozen_reeds", "reed_clump", "garden_bed", "mooring_post", "pier_deck"]
## The ground's own colours bare (sRGB, muted as the field's: the snow is the brightest).
const BALLAST := Color(0.34, 0.33, 0.31)
const BANK := Color(0.29, 0.27, 0.22)
const DITCH := Color(0.17, 0.17, 0.16)
const PLOUGHED := Color(0.25, 0.21, 0.17)
const STUBBLE := Color(0.37, 0.34, 0.26)
const MEADOW := Color(0.31, 0.32, 0.25)
const FOREST_FLOOR := Color(0.21, 0.19, 0.15)
const SHORE := Color(0.27, 0.25, 0.2)
const YARD := Color(0.29, 0.27, 0.23)
const ROAD := Color(0.31, 0.3, 0.29)
const DIRT_TRACK := Color(0.3, 0.26, 0.2)
## Red brick of the Polish villages, plank barns, the roofs (7b K1, seasons_regions 5.1).
const BRICK := Color(0.44, 0.25, 0.2)
const BRICK_DARK := Color(0.36, 0.21, 0.18)
const RENDER := Color(0.6, 0.56, 0.47)
const PLANK := Color(0.33, 0.28, 0.22)
const TILE := Color(0.33, 0.2, 0.17)
const SLATE := Color(0.22, 0.22, 0.23)
const WINDOW := Color(0.11, 0.12, 0.13)
const SNOW_LIN := Color(0.70, 0.71, 0.72)
## Lake water open and iced over (the early cold freezes the shallow lakes, seg 1~2).
const WATER := Color(0.08, 0.1, 0.12)
const ICE := Color(0.52, 0.57, 0.6)

static var _meshes: Dictionary = {}
## Each model's height in its mesh (AABB y, NAN without the file), read on the main
## thread by warm(): plan() on a worker reads only this.
static var _heights: Dictionary = {}


## Read every model of the kit once on the main thread, its mesh and its height, so a
## plan() worked out on a worker only reads (a worker loading meshes into _meshes while
## the stop scene lays the same kit on the main thread would race). Cheap once done.
static func warm() -> void:
	for model: String in TALL:
		if _heights.has(model):
			continue
		var mesh: Mesh = mesh_of(model)
		_heights[model] = mesh.get_aabb().size.y if mesh != null else NAN


## How white and wet the stretch's look lays the ground (as outside_view.gd reads it).
static func weather_of(look: Dictionary) -> Dictionary:
	var level: int = int(look.get("snow_level", 0))
	var white: float = [0.0, 0.55, 0.95][clampi(level, 0, 2)]
	var wet_ground: float = float(look.get("wet_ground", 1.0))
	var thaw: float = 0.4 if String(look.get("season", "")) in ["early_thaw", "late_autumn"] else 0.0
	var wet: float = clampf(float(look.get("fall", 0.0)) * wet_ground + thaw * wet_ground, 0.0, 1.0)
	return {"white": white, "wet": wet, "ice": float(look.get("ice", 0.0))}


## Lay the piece of `kind` from route metres s0 to s1 (local x 0 at s0) under a new
## node, dressed by `section` (its seed and mirror) and the weather of `look`.
## opts: ground (lay the bank and the land, else only what stands on it), field_y
## (the land's height under the rails' top), neutral (dressed bare), chunk (its
## number in the section, so a section's pieces differ), cast_shadow, white and wet
## (the ground's snow and wet given outright, as the stop scene has worked them out),
## far (the woods and tree lines out to FAR_W too: a camera that sees the horizon),
## near_clear (how far out the camera's side keeps low, NEAR_CLEAR by default).
static func build(kind: String, s0: float, s1: float, section: Dictionary, look: Dictionary, opts: Dictionary = {}) -> Node3D:
	return make(plan(kind, s0, s1, section, look, opts))


## The piece worked out as data only, the same as build lays it but with no node, mesh
## or server call, so a worker thread can work it out ahead: its surfaces as SurfaceTool
## arrays, what stands as a MultiMesh buffer a model a block, what was built. warm()
## first, on the main thread.
static func plan(kind: String, s0: float, s1: float, section: Dictionary, look: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var w: Dictionary = weather_of(look)
	if opts.has("white"):
		w["white"] = float(opts["white"])
	if opts.has("wet"):
		w["wet"] = float(opts["wet"])
	var p := {
		"kind": kind, "len": maxf(s1 - s0, 1.0), "s0": s0, "rng": RandomNumberGenerator.new(),
		"far": -1.0 if not bool(section.get("mirror", false)) else 1.0,
		"neutral": bool(opts.get("neutral", false)), "field_y": float(opts.get("field_y", FIELD_Y)),
		"white": float(w["white"]), "wet": float(w["wet"]), "ice": float(w["ice"]),
		"props": {}, "build": SurfaceTool.new(), "built": false,
		"lake": {}, "roads": [], "chunk": int(opts.get("chunk", 0)), "flat": not bool(opts.get("ground", true)),
		"houses": 0, "churches": 0, "near_clear": float(opts.get("near_clear", NEAR_CLEAR)),
	}
	(p["rng"] as RandomNumberGenerator).seed = hash([int(section.get("seed", 0)), int(opts.get("chunk", 0)), kind])
	(p["build"] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"wood":
			_wood(p)
		"lake":
			_lake(p)
		"field":
			_field(p)
		"village":
			_village(p)
	_poles(p)
	if bool(opts.get("far", false)):
		_far_band(p)
	# What was built, for the tests (a neutral piece has none).
	var out := {"name": "Land_%s_%d" % [kind, int(s0)], "houses": int(p["houses"]), "churches": int(p["churches"]),
		"shadow": bool(opts.get("cast_shadow", false))}
	if bool(opts.get("ground", true)):
		out["ground"] = _ground_arrays(p)
	elif not (p["roads"] as Array).is_empty():
		# On another scene's ground (the stop scene's): its roads only, laid on it.
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for r: Dictionary in p["roads"]:
			_road(st, p, r)
		out["roads"] = st.commit_to_arrays()
	if not (p["lake"] as Dictionary).is_empty():
		out["water"] = _water_plan(p)
	if bool(p["built"]):
		out["built"] = (p["build"] as SurfaceTool).commit_to_arrays()
	out["props"] = _prop_buffers(p)
	return out


## The piece's nodes from its plan (the main thread): the surfaces' meshes, a MultiMesh
## a model a block.
static func make(pl: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = String(pl["name"])
	if pl.has("ground"):
		var ground := _array_node(pl["ground"])
		ground.name = "Ground"
		root.add_child(ground)
	elif pl.has("roads"):
		var roads := _array_node(pl["roads"])
		roads.name = "Roads"
		root.add_child(roads)
	if pl.has("water"):
		root.add_child(_water_node(pl["water"]))
	if pl.has("built"):
		var mi := _array_node(pl["built"])
		mi.name = "Built"
		root.add_child(mi)
	_commit_buffers(root, pl["props"], bool(pl["shadow"]))
	root.set_meta("houses", int(pl["houses"]))
	root.set_meta("churches", int(pl["churches"]))
	return root


# ---------------------------------------------------------------- the kinds

## Pine and birch both sides; the camera's side thinned to young birch and brush
## near the line (a cleared strip, as railways keep), a forest track across now and then.
static func _wood(p: Dictionary) -> void:
	var rng: RandomNumberGenerator = p["rng"]
	var length: float = p["len"]
	var track_x: float = rng.randf_range(20.0, length - 20.0) if rng.randf() < 0.22 and not bool(p["neutral"]) else -100.0
	if track_x > 0.0:
		(p["roads"] as Array).append({"x": track_x, "w": 3.2, "color": DIRT_TRACK, "across": true})
	for side: float in [-1.0, 1.0]:
		var from: float = 9.0 if side < 0.0 else 7.5
		var count: int = int(length * (LAND_W - from) / 26.0)
		for i in count:
			var at := Vector3(rng.randf_range(0.0, length), 0.0, side * rng.randf_range(from, LAND_W))
			if absf(at.x - track_x) < 5.0:
				continue
			var near: bool = side > 0.0 and at.z < float(p["near_clear"])
			if near:
				_put(p, "bare_tree" if rng.randf() < 0.3 else ("thicket" if rng.randf() < 0.6 else "dry_bush"), at, rng, 2.4)
			else:
				_put(p, "spruce" if rng.randf() < 0.62 else "bare_tree", at, rng)
		for i in int(length / 9.0):
			var at := Vector3(rng.randf_range(0.0, length), 0.0, side * rng.randf_range(from - 2.0, LAND_W))
			_put(p, ["thicket", "stump_cluster", "dry_grass", "fallen_log", "dry_bush"][rng.randi_range(0, 4)], at, rng)


## Water on one side from a shore that winds along the line, reeds and willows at
## the edge, a boat drawn up and a landing stage now and then; wood or meadow behind.
static func _lake(p: Dictionary) -> void:
	var rng: RandomNumberGenerator = p["rng"]
	var length: float = p["len"]
	var side: float = p["far"]
	var shore: float = rng.randf_range(11.0, 15.0)
	p["lake"] = {"side": side, "shore": shore, "phase": rng.randf() * TAU, "phase2": rng.randf() * TAU}
	var x: float = rng.randf_range(0.0, 4.0)
	while x < length:
		var z: float = side * (_shore_at(p, x) - rng.randf_range(0.5, 2.5))
		_put(p, "frozen_reeds" if float(p["ice"]) > 0.5 else "reed_clump", Vector3(x, 0.0, z), rng)
		if rng.randf() < 0.45:
			_put(p, "reed_clump", Vector3(x + rng.randf_range(-1.0, 1.0), 0.0, z + side * rng.randf_range(0.5, 2.0)), rng)
		if rng.randf() < 0.09:
			_put(p, "bare_willow", Vector3(x, 0.0, side * (_shore_at(p, x) - rng.randf_range(2.0, 4.0))), rng)
		x += rng.randf_range(1.6, 3.4)
	if not bool(p["neutral"]):
		if rng.randf() < 0.55:
			var bx: float = rng.randf_range(10.0, length - 10.0)
			_put(p, "boat_on_blocks" if rng.randf() < 0.6 else "overturned_boat", Vector3(bx, 0.0, side * (_shore_at(p, bx) - 4.5)), rng, -1.0, rng.randf_range(-0.4, 0.4) + PI * 0.5)
		if rng.randf() < 0.3:
			var px: float = rng.randf_range(15.0, length - 15.0)
			var at := Vector3(px, -0.1, side * (_shore_at(p, px) + 9.0))
			_put(p, "pier_deck", at, rng, -1.0, PI * 0.5 + rng.randf_range(-0.1, 0.1))
			_put(p, "mooring_post", at + Vector3(1.6, 0.1, side * 7.0), rng)
	# Behind the line, on the other side: a birch and pine edge or a wet meadow.
	var other: float = -side
	var woods: bool = rng.randf() < 0.6
	for i in int(length * 0.55):
		var at := Vector3(rng.randf_range(0.0, length), 0.0, other * rng.randf_range(9.0, LAND_W))
		if woods and (other < 0.0 or at.z > float(p["near_clear"])):
			_put(p, "bare_tree" if rng.randf() < 0.55 else "spruce", at, rng)
		else:
			_put(p, ["dry_grass", "dry_bush", "thicket"][rng.randi_range(0, 2)], at, rng)


## Ploughed strips and stubble both sides, the drain along the bank, a willow row on
## a field's edge, a stone wall, a farm track over the line with a cart left by it;
## now and then a farmstead far off.
static func _field(p: Dictionary) -> void:
	var rng: RandomNumberGenerator = p["rng"]
	var length: float = p["len"]
	var neutral: bool = p["neutral"]
	var row_z: float = p["far"] * rng.randf_range(24.0, 34.0)
	var x: float = rng.randf_range(0.0, 6.0)
	while x < length:
		if row_z < 0.0 or row_z > float(p["near_clear"]):
			_put(p, "bare_willow", Vector3(x, 0.0, row_z + rng.randf_range(-1.0, 1.0)), rng)
		x += rng.randf_range(7.0, 13.0)
	for i in int(length / 6.0):
		var at := Vector3(rng.randf_range(0.0, length), 0.0, (-1.0 if rng.randf() < 0.5 else 1.0) * rng.randf_range(7.5, LAND_W))
		_put(p, "dry_grass" if rng.randf() < 0.7 else "dry_bush", at, rng)
	if rng.randf() < 0.5:
		var wx: float = rng.randf_range(5.0, length - 30.0)
		var wz: float = -rng.randf_range(12.0, 20.0)
		for k in 4:
			_put(p, "fieldstone_wall", Vector3(wx + k * 6.0, 0.0, wz), rng, -1.0, PI * 0.5)
	if rng.randf() < 0.35:
		var hx: float = rng.randf_range(10.0, length - 10.0)
		for k in 5:
			_put(p, "hedge", Vector3(hx, 0.0, 9.0 + k * 3.2), rng, -1.0, 0.0)
	if not neutral and rng.randf() < 0.32:
		var cross_x: float = rng.randf_range(20.0, length - 20.0)
		(p["roads"] as Array).append({"x": cross_x, "w": 3.6, "color": DIRT_TRACK, "across": true})
		_put(p, "hay_cart" if rng.randf() < 0.5 else "farm_cart", Vector3(cross_x + rng.randf_range(4.0, 8.0), 0.0, rng.randf_range(10.0, 16.0)), rng, -1.0, rng.randf() * TAU)
	if not neutral and rng.randf() < 0.18:
		var fx: float = rng.randf_range(20.0, length - 20.0)
		var fz: float = -rng.randf_range(32.0, 40.0)
		_house(p, Vector3(fx, 0.0, fz), Vector2(9.0, 8.0), 1, BRICK, TILE)
		_barn(p, Vector3(fx + 14.0, 0.0, fz - 2.0), Vector2(14.0, 9.0))
		_put(p, "bare_orchard_tree", Vector3(fx - 6.0, 0.0, fz + 7.0), rng)
		_put(p, "bare_orchard_tree", Vector3(fx - 2.0, 0.0, fz + 9.0), rng)


## The village's edge: a road along the line on the far side, red-brick houses and
## their barns behind it, gardens and plank fences down to the line, street trees and
## cars left on the road, the crossing hut where a road goes over, one church tower.
static func _village(p: Dictionary) -> void:
	var rng: RandomNumberGenerator = p["rng"]
	var length: float = p["len"]
	var road_z: float = -rng.randf_range(13.0, 16.0)
	(p["roads"] as Array).append({"z": road_z, "w": 5.0, "color": ROAD, "across": false})
	var x: float = rng.randf_range(0.0, 8.0)
	while x < length - 6.0:
		var wide: float = rng.randf_range(8.0, 11.0)
		var deep: float = rng.randf_range(8.0, 10.0)
		var floors: int = 2 if rng.randf() < 0.35 else 1
		var wall: Color = BRICK if rng.randf() < 0.7 else (RENDER if rng.randf() < 0.5 else BRICK_DARK)
		_house(p, Vector3(x + wide * 0.5, 0.0, road_z - 6.0 - deep * 0.5 - rng.randf_range(0.0, 3.0)), Vector2(wide, deep), floors, wall, TILE if rng.randf() < 0.75 else SLATE)
		if rng.randf() < 0.55:
			_barn(p, Vector3(x + wide * 0.5 + rng.randf_range(-2.0, 2.0), 0.0, road_z - 26.0 - rng.randf_range(0.0, 6.0)), Vector2(rng.randf_range(11.0, 16.0), rng.randf_range(8.0, 10.0)))
		if rng.randf() < 0.6:
			_put(p, "street_tree", Vector3(x + rng.randf_range(0.0, wide), 0.0, road_z + 3.6), rng)
		if rng.randf() < 0.22:
			_put(p, ["car", "wrecked_car_cluster", "pickup_truck"][rng.randi_range(0, 2)], Vector3(x + rng.randf_range(1.0, wide), 0.0, road_z + rng.randf_range(-1.2, 1.2)), rng, -1.0, PI * 0.5 + rng.randf_range(-0.3, 0.3))
		# The garden down to the line, fenced.
		_put(p, "garden_bed", Vector3(x + wide * 0.5, 0.0, road_z + 7.5), rng)
		_put(p, "bare_orchard_tree", Vector3(x + rng.randf_range(1.0, wide), 0.0, road_z + rng.randf_range(5.0, 8.5)), rng)
		for k in int(wide / 2.6):
			_put(p, "plank_fence", Vector3(x + 1.3 + k * 2.6, 0.0, -8.4), rng, -1.0, 0.0)
		x += wide + rng.randf_range(4.0, 9.0)
	# The camera's side: gardens and low sheds only, out past the clear strip a few trees.
	for i in int(length / 14.0):
		var at := Vector3(rng.randf_range(0.0, length), 0.0, rng.randf_range(8.0, float(p["near_clear"]) - 2.0))
		_put(p, ["garden_bed", "firewood_stack", "water_barrel", "dry_bush", "plank_fence"][rng.randi_range(0, 4)], at, rng, -1.0, rng.randf() * TAU)
	for i in int(length / 20.0):
		_put(p, "bare_orchard_tree", Vector3(rng.randf_range(0.0, length), 0.0, rng.randf_range(float(p["near_clear"]) + 1.0, LAND_W)), rng)
	if rng.randf() < 0.55:
		var cx: float = rng.randf_range(16.0, length - 16.0)
		(p["roads"] as Array).append({"x": cx, "w": 5.0, "color": ROAD, "across": true})
		_hut(p, Vector3(cx + 4.8, 0.0, -4.6))
		_put(p, "signal_post", Vector3(cx - 9.0, 0.0, -3.2), rng)
	if int(p["chunk"]) == 1 and rng.randf() < 0.7:
		_church(p, Vector3(rng.randf_range(20.0, maxf(length - 20.0, 21.0)), 0.0, road_z - rng.randf_range(24.0, 30.0)), rng.randf() < 0.5)
	for i in int(length / 4.0):
		_put(p, "dry_grass", Vector3(rng.randf_range(0.0, length), 0.0, (-1.0 if rng.randf() < 0.5 else 1.0) * rng.randf_range(4.8, 8.0)), rng)


## Telegraph poles along the far side a pole every POLE_STEP of the route (so pieces
## meet without a gap), now and then one leaning or gone, three sagging wires between.
static func _poles(p: Dictionary) -> void:
	var rng: RandomNumberGenerator = p["rng"]
	var s0: float = p["s0"]
	var length: float = p["len"]
	var fy: float = float(p["field_y"])
	var first: float = ceilf(s0 / POLE_STEP) * POLE_STEP - s0
	var x: float = first
	var tops: Array = []
	while x < length:
		var lean: float = rng.randf_range(-0.03, 0.03)
		if rng.randf() < 0.06:
			lean = rng.randf_range(0.12, 0.22) * (-1.0 if rng.randf() < 0.5 else 1.0)
		var gone: bool = rng.randf() < 0.04
		if not gone:
			var basis := Basis(Vector3.FORWARD, lean) * Basis(Vector3.UP, PI * 0.5)
			_put_t(p, "power_pole", Transform3D(basis.scaled(Vector3.ONE * _scale_of("power_pole", POLE_H)), Vector3(x, fy, POLE_Z)))
			tops.append(Vector3(x - sin(lean) * POLE_H, fy + cos(lean) * POLE_H - 0.5, POLE_Z))
		else:
			tops.append(null)
		x += POLE_STEP
	# The spans from this piece's poles to the next pole are this piece's (the one
	# before its first pole is the piece before's).
	var st: SurfaceTool = p["build"]
	for i in tops.size():
		var a: Variant = tops[i]
		var b: Variant = tops[i + 1] if i + 1 < tops.size() else Vector3(first + POLE_STEP * tops.size(), fy + POLE_H - 0.5, POLE_Z)
		if a == null or b == null:
			continue
		for k in 3:
			_wire(st, (a as Vector3) + Vector3(0, -0.25 * k, 0.35 * (k - 1)), (b as Vector3) + Vector3(0, -0.25 * k, 0.35 * (k - 1)), 0.9 + 0.15 * k)
		p["built"] = true


## Beyond LAND_W, for a camera that sees the horizon (the stop scene's roof): the
## kind's far side as woods, tree lines between fields, the far shore's trees.
static func _far_band(p: Dictionary) -> void:
	var rng: RandomNumberGenerator = p["rng"]
	var length: float = p["len"]
	var per: float = {"wood": 0.9, "lake": 0.35, "field": 0.22, "village": 0.4}.get(String(p["kind"]), 0.3)
	for side: float in [-1.0, 1.0]:
		var n: int = int(length * per * 0.5)
		var line_z: float = side * rng.randf_range(60.0, 110.0)
		for i in n:
			var z: float = side * rng.randf_range(LAND_W, FAR_W)
			if String(p["kind"]) == "field" and rng.randf() < 0.6:
				z = line_z + rng.randf_range(-3.0, 3.0)
			var at := Vector3(rng.randf_range(0.0, length), 0.0, z)
			_put_far(p, "spruce" if rng.randf() < 0.55 else "bare_tree", at, rng)


static func _put_far(p: Dictionary, model: String, at: Vector3, rng: RandomNumberGenerator) -> void:
	var span: Vector2 = TALL.get(model, Vector2(8.0, 12.0))
	var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * _scale_of(model, rng.randf_range(span.x, span.y))),
		Vector3(at.x, float(p["field_y"]), at.z))
	_put_t(p, model + "_far", t)


# ---------------------------------------------------------------- what stands

static func _put(p: Dictionary, model: String, at: Vector3, rng: RandomNumberGenerator, cap: float = -1.0, yaw: float = INF) -> void:
	var span: Vector2 = TALL.get(model, Vector2(1.0, 1.0))
	var tall: float = rng.randf_range(span.x, span.y)
	if cap > 0.0:
		tall = minf(tall, cap)
	if at.z > 0.0 and at.z < float(p["near_clear"]) and tall > NEAR_LOW:
		return
	if at.x < -0.5 or at.x > float(p["len"]) + 0.5 or absf(at.z) > LAND_W:
		return
	var turn: float = rng.randf() * TAU if yaw == INF else yaw
	var basis := Basis(Vector3.UP, turn)
	if model in ["spruce", "bare_tree", "bare_willow", "street_tree"]:
		basis = basis * Basis(Vector3.RIGHT, rng.randf_range(-0.03, 0.03))
	var y: float = float(p["field_y"]) + at.y
	_put_t(p, model, Transform3D(basis.scaled(Vector3.ONE * _scale_of(model, tall)), Vector3(at.x, y, at.z)))


static func _put_t(p: Dictionary, model: String, t: Transform3D) -> void:
	var props: Dictionary = p["props"]
	var block: int = int(floor(t.origin.x / BLOCK_M))
	var key := "%s|%d" % [model, block]
	if not props.has(key):
		props[key] = []
	(props[key] as Array).append(t)


static func _scale_of(model: String, tall: float) -> float:
	var h: float = NAN
	if _heights.has(model):
		h = float(_heights[model])
	elif OS.get_thread_caller_id() == OS.get_main_thread_id():
		# Not warmed: read the mesh now (the main thread only).
		var mesh: Mesh = mesh_of(model)
		h = mesh.get_aabb().size.y if mesh != null else NAN
	else:
		# A worker cannot read a mesh: a model TALL lacks stands unscaled.
		push_warning("journey_kit: %s not warmed (TALL), laid unscaled" % model)
	if is_nan(h):
		return 1.0
	return tall / maxf(h, 0.01)


static func path_of(model: String) -> String:
	return (COMMON if model in IN_COMMON else FIELD) % model


## A model's mesh (the field's batched one, LOD 0), null without the file.
static func mesh_of(model: String) -> Mesh:
	if _meshes.has(model):
		return _meshes[model]
	var path := path_of(model)
	var mesh: Mesh = null
	if PropModels.enabled() and ResourceLoader.exists(path):
		var batches: Dictionary = PropModels.batch_meshes(path)
		mesh = batches.get(0, null)
	_meshes[model] = mesh
	return mesh


## What stands, a model a block, as MultiMesh buffers (TRANSFORM_3D: a 3x4 matrix by
## rows, twelve floats an instance).
static func _prop_buffers(p: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var props: Dictionary = p["props"]
	for key: String in props:
		var list: Array = props[key]
		if list.is_empty():
			continue
		var buf := PackedFloat32Array()
		buf.resize(list.size() * 12)
		var i: int = 0
		for t: Transform3D in list:
			var b: Basis = t.basis
			buf[i] = b.x.x
			buf[i + 1] = b.y.x
			buf[i + 2] = b.z.x
			buf[i + 3] = t.origin.x
			buf[i + 4] = b.x.y
			buf[i + 5] = b.y.y
			buf[i + 6] = b.z.y
			buf[i + 7] = t.origin.y
			buf[i + 8] = b.x.z
			buf[i + 9] = b.y.z
			buf[i + 10] = b.z.z
			buf[i + 11] = t.origin.z
			i += 12
		out[key] = {"count": list.size(), "buffer": buf}
	return out


static func _commit_buffers(root: Node3D, props: Dictionary, shadow: bool) -> void:
	for key: String in props:
		var model: String = key.split("|")[0].trim_suffix("_far")
		var mesh: Mesh = mesh_of(model)
		if mesh == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = int(props[key]["count"])
		mm.buffer = props[key]["buffer"]
		var node := MultiMeshInstance3D.new()
		node.name = key.replace("|", "_")
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow and not (model in SMALL) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if model in SMALL:
			node.visibility_range_end = SMALL_RANGE
		root.add_child(node)


# ---------------------------------------------------------------- buildings

## A house: walls of its paint, a gable roof along its long side (the line's
## direction), dark windows a floor at a time, a chimney with no smoke (7b).
static func _house(p: Dictionary, at: Vector3, size: Vector2, floors: int, wall: Color, roof_color: Color) -> void:
	if bool(p["neutral"]) or (at.z > 0.0 and at.z < float(p["near_clear"])):
		return
	var st: SurfaceTool = p["build"]
	var y0: float = float(p["field_y"])
	var h: float = 2.9 * floors + 0.3
	var base := Vector3(at.x, y0, at.z)
	MapView.box(st, Vector3(size.x, h, size.y), base + Vector3(0, h * 0.5, 0), _tone(p, wall, 0.0))
	for fl in floors:
		var y: float = y0 + 1.5 + 2.9 * fl
		for face: float in [-1.0, 1.0]:
			var wx: float = at.x - size.x * 0.5 + 1.4
			while wx < at.x + size.x * 0.5 - 0.9:
				MapView.box(st, Vector3(0.75, 1.15, 0.06), Vector3(wx, y, at.z + face * (size.y * 0.5 + 0.03)), WINDOW)
				wx += 2.4
	_gable(p, st, base + Vector3(0, h, 0), size, clampf(size.y * 0.42, 2.2, 4.2), roof_color, wall)
	MapView.box(st, Vector3(0.7, 1.6, 0.7), base + Vector3(size.x * 0.25, h + 2.2, -size.y * 0.15), _tone(p, BRICK_DARK, 0.0))
	p["built"] = true
	p["houses"] = int(p["houses"]) + 1


## A barn of weathered upright planks, larger and plainer, a wide door on its long side.
static func _barn(p: Dictionary, at: Vector3, size: Vector2) -> void:
	if bool(p["neutral"]) or (at.z > 0.0 and at.z < float(p["near_clear"])):
		return
	var st: SurfaceTool = p["build"]
	var y0: float = float(p["field_y"])
	var h: float = 4.2
	var base := Vector3(at.x, y0, at.z)
	MapView.box(st, Vector3(size.x, h, size.y), base + Vector3(0, h * 0.5, 0), _tone(p, PLANK, 0.0))
	MapView.box(st, Vector3(3.2, 3.0, 0.08), base + Vector3(0, 1.5, size.y * 0.5 + 0.04), _tone(p, PLANK.darkened(0.35), 0.0))
	_gable(p, st, base + Vector3(0, h, 0), size, clampf(size.y * 0.5, 3.0, 5.0), SLATE, PLANK)
	p["built"] = true
	p["houses"] = int(p["houses"]) + 1


## The little brick hut by a level crossing (7b K1 「벽돌 건널목 초소」), hipped roof.
static func _hut(p: Dictionary, at: Vector3) -> void:
	if bool(p["neutral"]):
		return
	var st: SurfaceTool = p["build"]
	var base := Vector3(at.x, float(p["field_y"]) + 0.3, at.z)
	MapView.box(st, Vector3(3.0, 2.5, 2.4), base + Vector3(0, 1.25, 0), _tone(p, BRICK, 0.0))
	MapView.box(st, Vector3(0.9, 0.9, 0.06), base + Vector3(0.4, 1.5, 1.23), WINDOW)
	var top := base + Vector3(0, 2.5, 0)
	var r: Color = _tone(p, TILE, 1.0)
	var c := [top + Vector3(-1.75, 0, -1.45), top + Vector3(1.75, 0, -1.45), top + Vector3(1.75, 0, 1.45), top + Vector3(-1.75, 0, 1.45)]
	var apex := top + Vector3(0, 1.3, 0)
	for i in 4:
		_tri(st, c[i], c[(i + 1) % 4], apex, r)
	p["built"] = true
	p["houses"] = int(p["houses"]) + 1


## One church a village (7b K1: a pointed spire, or the round-capped clock tower
## common in Greater Poland): a brick nave and its tower at the end.
static func _church(p: Dictionary, at: Vector3, spire: bool) -> void:
	if bool(p["neutral"]):
		return
	var st: SurfaceTool = p["build"]
	var y0: float = float(p["field_y"])
	var base := Vector3(at.x, y0, at.z)
	var nave := Vector2(17.0, 10.0)
	MapView.box(st, Vector3(nave.x, 7.0, nave.y), base + Vector3(0, 3.5, 0), _tone(p, BRICK_DARK, 0.0))
	_gable(p, st, base + Vector3(0, 7.0, 0), nave, 4.6, TILE, BRICK_DARK)
	var tower := base + Vector3(-nave.x * 0.5 - 2.4, 0, 0)
	var th: float = 17.0
	MapView.box(st, Vector3(4.8, th, 4.8), tower + Vector3(0, th * 0.5, 0), _tone(p, BRICK if spire else RENDER, 0.0))
	for face in 4:
		var n := Vector3(1, 0, 0).rotated(Vector3.UP, face * PI * 0.5)
		var pane := Vector3(0.08, 1.6, 0.9) if absf(n.x) > 0.5 else Vector3(0.9, 1.6, 0.08)
		MapView.box(st, pane, tower + Vector3(0, th - 2.4, 0) + n * 2.42, WINDOW)
	var top := tower + Vector3(0, th, 0)
	if spire:
		var r: Color = _tone(p, SLATE, 0.4)
		var c := [top + Vector3(-2.6, 0, -2.6), top + Vector3(2.6, 0, -2.6), top + Vector3(2.6, 0, 2.6), top + Vector3(-2.6, 0, 2.6)]
		var apex := top + Vector3(0, 9.5, 0)
		for i in 4:
			_tri(st, c[i], c[(i + 1) % 4], apex, r)
	else:
		# The round cap: three shrinking drums and a lantern.
		var cap: Color = _tone(p, SLATE, 0.5)
		MapView.box(st, Vector3(4.4, 1.4, 4.4), top + Vector3(0, 0.7, 0), cap)
		MapView.box(st, Vector3(3.4, 1.3, 3.4), top + Vector3(0, 2.0, 0), cap)
		MapView.box(st, Vector3(2.0, 1.1, 2.0), top + Vector3(0, 3.2, 0), cap)
		MapView.box(st, Vector3(0.9, 2.0, 0.9), top + Vector3(0, 4.7, 0), cap.darkened(0.2))
	p["built"] = true
	p["houses"] = int(p["houses"]) + 1
	p["churches"] = int(p["churches"]) + 1


## A gable roof on a block of `size` (x along the ridge) whose top is at `top`.
static func _gable(p: Dictionary, st: SurfaceTool, top: Vector3, size: Vector2, rise: float, roof_color: Color, wall: Color) -> void:
	var eave: float = 0.35
	var x0: float = top.x - size.x * 0.5 - eave
	var x1: float = top.x + size.x * 0.5 + eave
	var z0: float = top.z - size.y * 0.5 - eave
	var z1: float = top.z + size.y * 0.5 + eave
	var y: float = top.y
	var ridge: float = y + rise
	var zm: float = top.z
	var near_face: Color = _tone(p, roof_color, 1.0)
	var far_face: Color = _tone(p, roof_color.darkened(0.12), 1.0)
	_quad(st, Vector3(x0, y, z1), Vector3(x1, y, z1), Vector3(x1, ridge, zm), Vector3(x0, ridge, zm), near_face)
	_quad(st, Vector3(x1, y, z0), Vector3(x0, y, z0), Vector3(x0, ridge, zm), Vector3(x1, ridge, zm), far_face)
	var end: Color = _tone(p, wall.darkened(0.1), 0.0)
	_tri(st, Vector3(x0 + eave, y, z0 + eave), Vector3(x0 + eave, y, z1 - eave), Vector3(x0 + eave, ridge - 0.2, zm), end)
	_tri(st, Vector3(x1 - eave, y, z1 - eave), Vector3(x1 - eave, y, z0 + eave), Vector3(x1 - eave, ridge - 0.2, zm), end)


## A wire hanging between two pole tops, as a thin dark strip in a few pieces.
static func _wire(st: SurfaceTool, a: Vector3, b: Vector3, sag: float) -> void:
	var steps: int = 6
	var color := Color(0.12, 0.12, 0.12)
	for i in steps:
		var t0: float = float(i) / steps
		var t1: float = float(i + 1) / steps
		var p0: Vector3 = a.lerp(b, t0) + Vector3(0, -sag * 4.0 * t0 * (1.0 - t0), 0)
		var p1: Vector3 = a.lerp(b, t1) + Vector3(0, -sag * 4.0 * t1 * (1.0 - t1), 0)
		var w := Vector3(0, 0.025, 0)
		_quad(st, p0 - w, p1 - w, p1 + w, p0 + w, color)


# ---------------------------------------------------------------- the ground

static func _shore_at(p: Dictionary, x: float) -> float:
	var l: Dictionary = p["lake"]
	var s0: float = float(p["s0"])
	return float(l["shore"]) + 2.6 * sin((s0 + x) * 0.045 + float(l["phase"])) + 1.2 * sin((s0 + x) * 0.13 + float(l["phase2"]))


## The bank under the line and the land each side: ballast, the bank's slope, the
## drain, then the land of this kind rising and falling a little; roads laid on it.
static func _ground_arrays(p: Dictionary) -> Array:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length: float = p["len"]
	var fy: float = p["field_y"]
	var cols: int = maxi(2, int(ceil(length / 6.0)))
	var zs: Array = [-LAND_W]
	var z: float = -LAND_W + 4.0
	while z < -7.6:
		zs.append(z)
		z += 4.0
	zs.append_array([-7.6, -6.8, -6.0, -5.2, -4.4, -2.5, -1.8, 0.0, 1.8, 2.5, 4.4, 5.2, 6.0, 6.8, 7.6])
	z = 11.6
	while z < LAND_W:
		zs.append(z)
		z += 4.0
	zs.append(LAND_W)
	var grid: Array = []
	for i in cols + 1:
		var x: float = length * float(i) / float(cols)
		var row: Array = []
		for zz: float in zs:
			row.append(_ground_point(p, x, zz, fy))
		grid.append(row)
	for i in cols:
		for j in zs.size() - 1:
			var a: Array = grid[i][j]
			var b: Array = grid[i + 1][j]
			var c: Array = grid[i + 1][j + 1]
			var d: Array = grid[i][j + 1]
			_tri_colors(st, a, b, c)
			_tri_colors(st, a, c, d)
	for r: Dictionary in p["roads"]:
		_road(st, p, r)
	return st.commit_to_arrays()


## [position, colour] of the ground at x, z.
static func _ground_point(p: Dictionary, x: float, z: float, fy: float) -> Array:
	var az: float = absf(z)
	var y: float
	var base: Color
	if az <= 1.8:
		y = -0.2
		base = BALLAST
	elif az <= 2.5:
		y = lerpf(-0.2, -0.5, (az - 1.8) / 0.7)
		base = BALLAST.lerp(BANK, 0.4)
	elif az <= 4.4:
		y = lerpf(-0.5, fy, (az - 2.5) / 1.9)
		base = BANK
	elif az <= 7.6:
		var d: float = clampf(1.0 - absf(az - 6.0) / 1.6, 0.0, 1.0)
		y = fy - 0.4 * d
		base = BANK.lerp(DITCH, d)
	else:
		var s: float = float(p["s0"]) + x
		y = fy + 0.22 * sin(s * 0.031 + z * 0.05) + 0.14 * sin(s * 0.087 - z * 0.11)
		base = _land_colour(p, x, z)
		var l: Dictionary = p["lake"]
		if not l.is_empty() and signf(z) == float(l["side"]):
			var shore: float = _shore_at(p, x)
			if az > shore:
				var k: float = clampf((az - shore) / 3.0, 0.0, 1.0)
				y = lerpf(fy, fy - 0.9, k)
				base = SHORE
	var wet_more: float = 1.0 if az > 4.4 and az < 7.6 else 0.0
	return [Vector3(x, y, z), _tone(p, base, 1.0, wet_more)]


## The land's own colour for this kind at x, z, in patches (field strips, the wood's floor …).
static func _land_colour(p: Dictionary, x: float, z: float) -> Color:
	var s: float = float(p["s0"]) + x
	var patch: float = fposmod(floor(s / 38.0) * 7.31 + floor(z / 17.0) * 3.17, 3.0)
	match String(p["kind"]):
		"wood":
			return FOREST_FLOOR.lerp(MEADOW, 0.25 if absf(z) < 11.0 else 0.0)
		"lake":
			return MEADOW.lerp(SHORE, 0.3)
		"village":
			return YARD if z < 0.0 else MEADOW.lerp(YARD, 0.4)
	return [PLOUGHED, STUBBLE, MEADOW][int(patch)]


static func _road(st: SurfaceTool, p: Dictionary, r: Dictionary) -> void:
	var fy: float = float(p["field_y"]) + 0.04
	var w: float = float(r["w"]) * 0.5
	var color: Color = _tone(p, r["color"] as Color, 0.6)
	if bool(r.get("across", false)):
		var x: float = float(r["x"])
		for side: float in [-1.0, 1.0]:
			var z0: float = side * 7.6
			var z1: float = side * LAND_W
			_quad(st, Vector3(x - w, fy, z0), Vector3(x + w, fy, z0), Vector3(x + w, fy, z1), Vector3(x - w, fy, z1), color)
			# Up the bank to the rails: a ramp of packed earth and the planks between.
			_quad(st, Vector3(x - w, -0.18, side * 1.9), Vector3(x + w, -0.18, side * 1.9), Vector3(x + w, fy, side * 7.6), Vector3(x - w, fy, side * 7.6), color.darkened(0.08))
		MapView.box(st, Vector3(w * 2.0, 0.1, 3.8), Vector3(x, -0.12, 0.0), _tone(p, PLANK.darkened(0.2), 0.4))
	else:
		var z: float = float(r["z"])
		var length: float = p["len"]
		_quad(st, Vector3(0.0, fy, z + w), Vector3(length, fy, z + w), Vector3(length, fy, z - w), Vector3(0.0, fy, z - w), color)


## The lake's water: open and dark, or iced over and dusted where the cold has frozen it.
static func _water_plan(p: Dictionary) -> Dictionary:
	var l: Dictionary = p["lake"]
	var side: float = float(l["side"])
	var length: float = p["len"]
	# Set down in its bed on our own ground; on another scene's flat ground, just over it.
	var y: float = float(p["field_y"]) + (0.03 if bool(p["flat"]) else -0.32)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: int = maxi(2, int(ceil(length / 6.0)))
	var iced: float = clampf(float(p["ice"]), 0.0, 1.0)
	var c: Color = WATER.lerp(ICE, iced)
	c = _tone(p, c, 0.0, 0.0, 0.3 * iced * float(p["white"]))
	for i in steps:
		var x0: float = length * float(i) / steps
		var x1: float = length * float(i + 1) / steps
		var a := Vector3(x0, y, side * (_shore_at(p, x0) + 1.0))
		var b := Vector3(x1, y, side * (_shore_at(p, x1) + 1.0))
		var e := Vector3(x1, y, side * LAND_W)
		var d := Vector3(x0, y, side * LAND_W)
		if side > 0.0:
			_quad(st, a, d, e, b, c)
		else:
			_quad(st, a, b, e, d, c)
	return {"arrays": st.commit_to_arrays(), "iced": iced}


static func _water_node(water: Dictionary) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, water["arrays"])
	var node := MeshInstance3D.new()
	node.name = "Water"
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = lerpf(0.12, 0.55, float(water["iced"]))
	mat.metallic_specular = 0.6
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


# ---------------------------------------------------------------- mesh helpers

## A colour laid open to the sky, as the stop scene's ground (stop_cinema.gd _ground):
## darker when wet, under the snow as far as it lies; `cover` how much snow a face
## holds (0 walls, 1 roofs and ground), `more_wet` for the drain's floor.
static func _tone(p: Dictionary, base: Color, cover: float, more_wet: float = 0.0, extra_snow: float = 0.0) -> Color:
	var wet: float = clampf(float(p["wet"]) + more_wet * 0.5, 0.0, 1.0)
	var white: float = clampf(float(p["white"]) * maxf(cover, 0.15) + extra_snow, 0.0, 1.0)
	var damp: float = 1.0 - 0.35 * wet
	var lin := base.srgb_to_linear()
	var bare := Color(lin.r * damp, lin.g * damp, lin.b * damp)
	var snowy: Color = SNOW_LIN * lerpf(1.0, 0.75, wet)
	return bare.lerp(Color(snowy.r, snowy.g, snowy.b), 0.75 * white).linear_to_srgb()


static func _array_node(arrays: Array) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	# sRGB numbers, as the field's floors and the stop scene's ground (mood C9).
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_tri(st, a, b, c, color)
	_tri(st, a, c, d, color)


## One face, both ways round (roofs are seen from under the eaves, wires from both sides).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var n: Vector3 = (c - a).cross(b - a).normalized()
	for v in [a, b, c]:
		st.set_color(color)
		st.set_normal(n)
		st.add_vertex(v)
	for v in [a, c, b]:
		st.set_color(color)
		st.set_normal(-n)
		st.add_vertex(v)


## A ground face from three [position, colour] points, facing up.
static func _tri_colors(st: SurfaceTool, a: Array, b: Array, c: Array) -> void:
	var pa: Vector3 = a[0]
	var pb: Vector3 = b[0]
	var pc: Vector3 = c[0]
	var cross: Vector3 = (pb - pa).cross(pc - pa)
	if cross.y > 0.0:
		var tmp: Array = b
		b = c
		c = tmp
		cross = -cross
	var n: Vector3 = -cross.normalized()
	for v: Array in [a, b, c]:
		st.set_color(v[1] as Color)
		st.set_normal(n)
		st.add_vertex(v[0] as Vector3)
