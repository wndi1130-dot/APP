extends RefCounted
## What lies on the ground, drawn (decision 444, 차이 6·7의 앞단): every thing in
## game.ground_items but the ones still shining in the snow (decision 423 (11):
## those are a light only, field_hud.gd) gets its pre-baked icon model on its
## floor (decision 550), so a coat taken off, what a fallen one had, a thrown tin or a spent
## arrow is seen where it lies; before, it was found only by walking into 「줍기」.
## No word and no flat icon (결정 417). Missing/failed bakes and BOX_ONLY things
## keep their old boxes; runtime never calls an icon builder.
##
## 금지선: no case, bundle or bag shapes and no heaps. A sack or a crate at most;
## things at one spot are spread over their cell and no more than PER_CELL are
## drawn on a cell (the rest are still on the pick-up list).

const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const Wear = preload("res://game/sim/wear.gd")
const W = preload("res://game/sim/weapons.gd")
const Carry = preload("res://game/sim/carry.gd")
const GroundModels = preload("res://game/world/ground_models.gd")

const LEVEL_H: float = 3.0
## Drawn on one cell at most.
const PER_CELL: int = 3
## How far the second and third things on a cell lie from their spot at least
## (metres), and at most: laid at real size a coat is 0.6-0.8 m, so three on one
## cell would lie on one another and read as a heap (금지선) with a knife lost
## under a shirt (11-07 shots). Each is pushed out, round its own angle, until
## its footprint is clear of those already laid (the biggest lies on its spot),
## never past SPREAD_MAX — inside the 0.9 a tap reaches (field_hud.gd _tap_thing).
const SPREAD: float = 0.3
const SPREAD_MAX: float = 0.7
const SPREAD_STEP: float = 0.05
## Room left between two footprints so their dark rims (RIM) do not merge either.
const SPREAD_GAP: float = 0.04

## Kind -> [size (x, y, z: the long side along x), colour as seen (sRGB)].
## Dark, muted greys and browns and one pale paper, none at the floors' own
## middle greys: on a yard's dry grass, a street's asphalt, room boards (late
## autumn and the dimmer deep winter) and deep snow each stands off the floor by
## 0.085 or more of screen brightness (the furniture's gauge). world_vis.gdshader
## reads a vertex colour as sRGB and makes it linear itself (floor_to_linear, as
## it does the floors), so pieces() hands these over as they are; made linear
## here as well, they were darkened twice and drawn near black.
const LOOKS: Dictionary = {
	"weapon": [Vector3(0.75, 0.06, 0.1), Color(0.2, 0.2, 0.21)],
	"garment": [Vector3(0.5, 0.04, 0.38), Color(0.21, 0.22, 0.25)],
	"cloth": [Vector3(0.3, 0.03, 0.24), Color(0.27, 0.26, 0.24)],
	"paper": [Vector3(0.2, 0.01, 0.14), Color(0.6, 0.58, 0.52)],
	"board": [Vector3(0.9, 0.04, 0.18), Color(0.31, 0.23, 0.15)],
	"sack": [Vector3(0.34, 0.22, 0.26), Color(0.23, 0.19, 0.13)],
	"small": [Vector3(0.2, 0.14, 0.2), Color(0.22, 0.22, 0.23)],
	"crate": [Vector3(0.36, 0.24, 0.28), Color(0.29, 0.22, 0.14)],
	"big": [Vector3(0.5, 0.34, 0.4), Color(0.26, 0.2, 0.13)],
}
const PAPER_IDS: Dictionary = {"document": true, "info_telegraph": true, "info_timetable": true}
const CLOTH_IDS: Dictionary = {"cloth": true, "junk_rag": true, "bandage": true}
const BOARD_IDS: Dictionary = {"plank": true, "wood": true}
## The packs and boxes things come in (carry.gd), drawn as a crate; one thing
## by itself (a tin, a jar, a handful of shells) is a small lump.
const CRATE_IDS: Dictionary = {"food_pack": true, "med_box": true, "luxury_pack": true, "ammo_box": true, "medkit": true, "scrap": true}
## This heavy or more is a big crate (a core, the bell, a crate of tins).
const BIG_WEIGHT: float = 3.0


## The kind of shape one ground row is drawn as.
static func kind_of(g: Dictionary) -> String:
	var id := String(g.get("id", ""))
	if g.has("weapon") or not W.get_data(id).is_empty():
		return "weapon"
	if Wear.is_garment(id):
		return "garment"
	if CLOTH_IDS.has(id):
		return "cloth"
	if PAPER_IDS.has(id) or FieldItems.group(id) in ["paper", "key"] or id == "junk_paper":
		return "paper"
	if BOARD_IDS.has(id):
		return "board"
	if FieldItems.icon(id).begins_with("it_sack") or FieldItems.icon(id) == "it_flour":
		return "sack"
	if Carry.item_weight(id) >= BIG_WEIGHT:
		return "big"
	if CRATE_IDS.has(id) or FieldItems.icon(id) == "it_crate":
		return "crate"
	return "small"


## [{"lv", "model", "yaw", "size", "at" (footprint centre on floor), "color"}].
static func pieces(items: Array) -> Array:
	var out: Array = []
	var on_cell: Dictionary = {}  # Vector3i(x, y, lv) -> indexes into out drawn there
	for g: Dictionary in items:
		if bool(g.get("glint", false)):
			continue
		var pos: Vector3 = g["pos"]
		var lv := clampi(roundi(pos.y / LEVEL_H), -1, 2)
		var c := FieldGrid.cell_of(pos)
		var key := Vector3i(c.x, c.y, lv)
		var drawn: Array = on_cell.get(key, [])
		var k: int = drawn.size()
		if k >= PER_CELL:
			continue
		drawn.append(out.size())
		on_cell[key] = drawn
		var h: int = hash(Vector4i(c.x, c.y, lv, k))
		var at := Vector3(pos.x, lv * LEVEL_H, pos.z)
		var look: Array = LOOKS[kind_of(g)]
		var size: Vector3 = look[0]
		var id: String = String(g.get("id", ""))
		var weapon: Dictionary = W.get_data(id)
		var icon: String = String(weapon.get("icon", FieldItems.icon(id)))
		var model: String = GroundModels.resolve(id, icon)
		if not model.is_empty():
			size = GroundModels.template(model)["size"]
		var yaw: float = deg_to_rad(float(posmod(h >> 9, 360)))
		# Vertex alpha 0 reads as under a roof in world_vis.gdshader: no snow,
		# rain or ground grain over it, so a grey thing does not go white and
		# vanish (what lies buried shines instead, decision 423 (11)).
		var color: Color = look[1]
		color.a = 0.0
		out.append({"lv": lv, "model": model, "yaw": yaw, "size": size, "at": at, "color": color,
			"turn": deg_to_rad(float(posmod(h, 360)))})
	for key: Vector3i in on_cell:
		_lay_apart(out, on_cell[key])
	for piece: Dictionary in out:
		piece.erase("turn")
	return out


## The things on one cell (indexes into `out`, list order) laid so their
## footprints keep clear of one another: the biggest stays on its spot, then each
## next biggest goes out from its own spot along its own angle ("turn"), SPREAD
## and on by SPREAD_STEP, to the first place clear of all laid before; when none
## is by SPREAD_MAX, eight angles round its own are tried there and the one with
## the most room taken. Deterministic: the same list lays the same.
static func _lay_apart(out: Array, slots: Array) -> void:
	var order: Array = slots.duplicate()
	order.sort_custom(func(a: int, b: int) -> bool:
		var area_a: float = _footprint_area(out[a])
		var area_b: float = _footprint_area(out[b])
		return area_a > area_b if not is_equal_approx(area_a, area_b) else a < b)
	var laid: Array[Footprint] = []
	for slot: int in order:
		var piece: Dictionary = out[slot]
		var origin: Vector3 = piece["at"]
		var size: Vector3 = piece["size"]
		var foot := Footprint.new(Vector2(origin.x, origin.z), Vector2(size.x, size.z), float(piece["yaw"]))
		if not laid.is_empty():
			var spot: Vector2 = _clear_spot(foot, float(piece["turn"]), laid)
			piece["at"] = Vector3(spot.x, origin.y, spot.y)
		laid.append(foot)


## Where `foot`, on its own spot, goes among `laid` (and leaves it there): out
## along `turn` from SPREAD by SPREAD_STEP to the first spot SPREAD_GAP clear of
## them all; when none is by SPREAD_MAX, the roomiest of eight angles round
## `turn` at SPREAD_MAX.
static func _clear_spot(foot: Footprint, turn: float, laid: Array[Footprint]) -> Vector2:
	var origin: Vector2 = foot.centre
	var way := Vector2(cos(turn), sin(turn))
	var distance: float = SPREAD
	while distance <= SPREAD_MAX + 0.0001:
		foot.centre = origin + way * distance
		if _room_among(foot, laid) >= SPREAD_GAP:
			return foot.centre
		distance += SPREAD_STEP
	var best_at: Vector2 = origin
	var best_room: float = -INF
	for step: int in 8:
		var angle: float = turn + TAU * float(step) / 8.0
		foot.centre = origin + Vector2(cos(angle), sin(angle)) * SPREAD_MAX
		var room: float = _room_among(foot, laid)
		if room > best_room:
			best_room = room
			best_at = foot.centre
	foot.centre = best_at
	return best_at


static func _footprint_area(piece: Dictionary) -> float:
	var size: Vector3 = piece["size"]
	return size.x * size.z


## The least clearance (metres, negative when they overlap) between `foot` and
## each of `laid`.
static func _room_among(foot: Footprint, laid: Array[Footprint]) -> float:
	var room: float = INF
	for other: Footprint in laid:
		room = minf(room, foot.gap_to(other))
	return room


## The gap between two footprints on the floor — rectangles of `size` (x, z)
## round `centre`, turned by `yaw` as the 3D pieces are — see Footprint.gap_to.
static func footprint_gap(centre_a: Vector2, size_a: Vector2, yaw_a: float, centre_b: Vector2, size_b: Vector2, yaw_b: float) -> float:
	return Footprint.new(centre_a, size_a, yaw_a).gap_to(Footprint.new(centre_b, size_b, yaw_b))


## One thing's footprint on the floor: a rectangle `half` its sides (x, z) out
## from `centre` each way, turned by yaw as the 3D piece is (Basis(UP, yaw)).
## Its own x and z directions are worked out once, so trying it at spot after
## spot (_clear_spot) moves only the centre; before, every try turned both
## rectangles again and built arrays, and spreading 300 things went from 86 to
## 137 ms of rebuild (11-07 g6).
class Footprint:
	var centre: Vector2
	var half: Vector2
	var along_x: Vector2
	var along_z: Vector2

	func _init(at: Vector2, size: Vector2, yaw: float) -> void:
		centre = at
		half = size * 0.5
		var turn := Basis(Vector3.UP, yaw)
		var x3: Vector3 = turn * Vector3.RIGHT
		var z3: Vector3 = turn * Vector3.BACK
		along_x = Vector2(x3.x, x3.z)
		along_z = Vector2(z3.x, z3.z)

	## The gap to `other` along the side direction, of the four, that parts them
	## most (SAT); negative when they overlap (then the least push that would part
	## them, as a negative). Along its own side direction a rectangle reaches its
	## half side; the other reaches by how its sides lie across that direction.
	func gap_to(other: Footprint) -> float:
		var d: Vector2 = other.centre - centre
		var xx: float = absf(along_x.dot(other.along_x))
		var xz: float = absf(along_x.dot(other.along_z))
		var zx: float = absf(along_z.dot(other.along_x))
		var zz: float = absf(along_z.dot(other.along_z))
		var on_x: float = absf(d.dot(along_x)) - half.x - xx * other.half.x - xz * other.half.y
		var on_z: float = absf(d.dot(along_z)) - half.y - zx * other.half.x - zz * other.half.y
		var on_other_x: float = absf(d.dot(other.along_x)) - other.half.x - xx * half.x - zx * half.y
		var on_other_z: float = absf(d.dot(other.along_z)) - other.half.y - xz * half.x - zz * half.y
		return maxf(maxf(on_x, on_z), maxf(on_other_x, on_other_z))


## A dark rim round each thing (T0-6): a quad flat on its floor, RIM wider than
## the thing on every side, that makes the floor there darker
## (contact_shade.gdshader: black at RIM_STRENGTH over whatever the floor is, so
## asphalt, boards and snow each go darker in their own colour, lighter on snow).
## From above it is the outline of the flat things (a coat, a map, a knife) and
## the contact line of the taller ones, so a dark thing still stands off a
## street's grey asphalt at a phone's size; the things keep their colours (LOOKS).
const RIM: float = 0.1
const RIM_LIFT: float = 0.004
const RIM_STRENGTH: float = 0.8


## The rim under one of pieces()'s boxes: {"lv", "at" (centre, on the floor),
## "size" (along x and z), "inner" (the thing's share of it along x and z)}.
static func rim(piece: Dictionary) -> Dictionary:
	var size: Vector3 = piece["size"]
	var at: Vector3 = piece["at"]
	var outer := Vector2(size.x + 2.0 * RIM, size.z + 2.0 * RIM)
	# Existing container/sled bars pass a box centre, without the new model key.
	var floor_y: float = at.y if piece.has("model") else at.y - size.y / 2.0
	return {"lv": piece["lv"], "at": Vector3(at.x, floor_y + RIM_LIFT, at.z), "size": outer, "yaw": float(piece.get("yaw", 0.0)),
		"inner": Vector2(size.x / outer.x, size.z / outer.y)}
