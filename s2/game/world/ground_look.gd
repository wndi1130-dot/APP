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
## How far the second and third things on a cell lie from their spot: laid at real
## size a coat is 0.6-0.8 m, so three on one cell lay on one another and read as a
## heap (금지선) with a knife lost under a shirt (11-07 shots); a third of a metre
## apart they still read as one pile. So each goes out along its own angle from
## SPREAD to SPREAD_MAX first, only then SPREAD_NEAR to SPREAD_NEAR_MAX, then the
## eight angles at SPREAD_MAX (코디 11-07 11:2x) — never past the 0.9 m a tap
## reaches (field_hud.gd _pick_item). A spot must keep SPREAD_GAP from every thing
## already laid on that floor, a neighbouring cell's too, and stay off walls and
## furniture (blocked cells); walls alone may be given way to when nothing else is
## left (a coat in a one-metre corridor), other things never: a thing with no
## clear spot is not drawn, still on the pick-up list like a fourth on a cell.
const SPREAD: float = 0.5
const SPREAD_MAX: float = 0.7
const SPREAD_STEP: float = 0.05
const SPREAD_NEAR: float = 0.3
const SPREAD_NEAR_MAX: float = 0.45
## Clearance between bare footprints (코디 ㉮); rims shrink after placement.
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


## [{"lv", "model", "yaw", "size", "at" (footprint centre on floor), "color", "rim"}].
static func pieces(items: Array, blocked: Callable = Callable()) -> Array:
	var out: Array = []
	var on_cell: Dictionary = {}  # Vector3i(x, y, lv) -> indexes into out drawn there
	for item: int in items.size():
		var g: Dictionary = items[item]
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
		out.append({"item": item, "lv": lv, "model": model, "yaw": yaw, "size": size, "at": at, "color": color,
			"turn": deg_to_rad(float(posmod(h, 360)))})
	out = _lay_apart(out, on_cell, blocked)
	var widths: Array[float] = _rim_widths(out)
	for slot: int in out.size():
		var piece: Dictionary = out[slot]
		piece["rim"] = widths[slot]
		piece.erase("turn")
	return out


## Lay each cell's biggest first, then its second and third, in floor/y/x order.
## Buckets cover the full footprint, including large models across cell edges.
## Gather neighbours and walls once per thing, never once per candidate.
static func _lay_apart(out: Array, on_cell: Dictionary, blocked: Callable) -> Array:
	var cells: Array = on_cell.keys()
	cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.z != b.z:
			return a.z < b.z
		return a.y < b.y if a.y != b.y else a.x < b.x)
	for cell: Vector3i in cells:
		on_cell[cell].sort_custom(func(a: int, b: int) -> bool:
			var area_a: float = _footprint_area(out[a])
			var area_b: float = _footprint_area(out[b])
			return area_a > area_b if area_a != area_b else int(out[a]["item"]) < int(out[b]["item"]))
	var buckets: Dictionary = {}
	var wall_cache: Dictionary = {}
	var kept: Dictionary = {}
	for rank: int in PER_CELL:
		for cell: Vector3i in cells:
			if rank >= on_cell[cell].size():
				continue
			var slot: int = on_cell[cell][rank]
			var piece: Dictionary = out[slot]
			var origin: Vector3 = piece["at"]
			var size: Vector3 = piece["size"]
			var foot := Footprint.new(Vector2(origin.x, origin.z), Vector2(size.x, size.z), float(piece["yaw"]))
			var neighbours: Array[Footprint] = []
			var walls: Array[Footprint] = []
			# Every rotation and offset fits inside this square about the origin.
			var radius: float = foot.half.length() + SPREAD_MAX + SPREAD_GAP
			var low := Vector2i((foot.centre - Vector2.ONE * radius).floor())
			var high := Vector2i((foot.centre + Vector2.ONE * radius).floor())
			var bounds := Rect2i(low, high - low + Vector2i.ONE)
			for y: int in range(bounds.position.y, bounds.end.y):
				for x: int in range(bounds.position.x, bounds.end.x):
					var key := Vector3i(x, y, cell.z)
					var near: Variant = buckets.get(key)
					if near != null:
						# A thing across cell edges sits in several buckets: take it once,
						# marked with this thing's slot (no lookup table per thing).
						for other: Footprint in near:
							if other.mark != slot:
								other.mark = slot
								neighbours.append(other)
					if blocked.is_valid():
						if not wall_cache.has(key):
							wall_cache[key] = Footprint.new(Vector2(x + 0.5, y + 0.5), Vector2.ONE, 0.0) if blocked.call(Vector2i(x, y), cell.z) else null
						if wall_cache[key] != null:
							walls.append(wall_cache[key])
			if not _clear_spot(foot, float(piece["turn"]), neighbours, walls, rank == 0):
				continue
			piece["at"] = Vector3(foot.centre.x, origin.y, foot.centre.y)
			piece["yaw"] = foot.yaw
			kept[slot] = true
			bounds = foot.cells()
			for y: int in range(bounds.position.y, bounds.end.y):
				for x: int in range(bounds.position.x, bounds.end.x):
					var key := Vector3i(x, y, cell.z)
					if not buckets.has(key):
						buckets[key] = []
					buckets[key].append(foot)
	var drawn: Array = []
	for slot: int in out.size():
		if kept.has(slot):
			drawn.append(out[slot])
	return drawn


## How many tries along its own angle: SPREAD to SPREAD_MAX and SPREAD_NEAR to
## SPREAD_NEAR_MAX by SPREAD_STEP (test_ground_look holds them to those).
const FAR_TRIES: int = 5
const NEAR_TRIES: int = 4
## The wide search: odd directions on the first ring, all sixteen on the rest.
## The first ring equals SPREAD_MAX, whose eight even directions came earlier.
const WIDE_ANGLES: int = 16
const WIDE_RINGS: Array[float] = [0.7, 0.6, 0.5]
## Tries in one turn: far, near, eight round, wide minus eight later repeats.
const SPIN_TRIES: int = FAR_TRIES + NEAR_TRIES + 8 + WIDE_ANGLES * 3 - 8
## cos and sin of k·22.5°: the sixteen directions, every other one the eight.
## Turned by a thing's own angle (a complex product), so no try costs a sine:
## building every thing's 130 tries with cos/sin made laying 300 things 37 →
## 215 ms (11-07 15:4x, headless).
const RING16: Array[Vector2] = [
	Vector2(1.0, 0.0), Vector2(0.9238795, 0.3826834), Vector2(0.7071068, 0.7071068), Vector2(0.3826834, 0.9238795),
	Vector2(0.0, 1.0), Vector2(-0.3826834, 0.9238795), Vector2(-0.7071068, 0.7071068), Vector2(-0.9238795, 0.3826834),
	Vector2(-1.0, 0.0), Vector2(-0.9238795, -0.3826834), Vector2(-0.7071068, -0.7071068), Vector2(-0.3826834, -0.9238795),
	Vector2(0.0, -1.0), Vector2(0.3826834, -0.9238795), Vector2(0.7071068, -0.7071068), Vector2(0.9238795, -0.3826834),
]


## Where `foot` (on its spot, at its own yaw) goes among `laid`, leaving it there:
## the first candidate SPREAD_GAP clear of every laid thing and off every wall
## (`walls`, the blocked cells' squares). For `home` (the biggest on a cell), try
## its own spot at its own yaw, then there a quarter turned: keep its pick-up
## position when a turn alone fits; turning changes only the drop's look.
## Next, at its own yaw: along its angle SPREAD to SPREAD_MAX, then SPREAD_NEAR to
## SPREAD_NEAR_MAX, eight angles at SPREAD_MAX, then the wide rings without the
## first ring's repeated even directions. Repeat these moves a quarter turned
## (a knife across the gap two coats leave, a coat along a corridor).
## Before the wide search and the quarter turn, three on open floor had one left
## undrawn (11-07 14:4x: a third with 0-4 cm of room at the best of eight).
## If only walls stand in the way of every candidate, the least buried one still
## clear of all laid things is taken (a coat in a one-metre corridor). False when
## none is clear of the laid things: then it is not drawn — no path returns a spot
## that overlaps another thing.
static func _clear_spot(foot: Footprint, turn: float, laid: Array[Footprint], walls: Array[Footprint] = [], home: bool = false) -> bool:
	var origin: Vector2 = foot.centre
	var own_yaw: float = foot.yaw
	var way := Vector2(cos(turn), sin(turn))
	var best_at: Vector2 = origin
	var best_yaw: float = own_yaw
	var best_room: float = -INF
	var found := false
	for index: int in try_count(home):
		var tried: Vector3 = try_at(index, home, way)
		var yaw: float = own_yaw + PI * 0.5 * tried.z
		if not is_equal_approx(foot.yaw, yaw):
			foot.turn_to(yaw)
		foot.centre = origin + Vector2(tried.x, tried.y)
		if not _clear_of(foot, laid, SPREAD_GAP):
			continue
		var room: float = _wall_room(foot, walls)
		if room >= 0.0:
			return true
		# Equal burial (to rounding: a turned rectangle's sides carry 1e-8) keeps
		# the earlier candidate, so a coat in a corridor stays on its spot.
		if room > best_room + ROOM_EPSILON:
			found = true
			best_room = room
			best_at = foot.centre
			best_yaw = yaw
	foot.turn_to(best_yaw)
	foot.centre = best_at
	return found


## How many candidates _clear_spot has: both turns' SPIN_TRIES, and the own
## spot at both turns first for the biggest on a cell (`home`).
static func try_count(home: bool) -> int:
	return SPIN_TRIES * 2 + (2 if home else 0)


## Candidate `index` of _clear_spot, worked out when it is tried (most things
## take one of the first few): (offset x, offset z, quarter turns). `way` is the
## thing's own angle as (cos, sin).
static func try_at(index: int, home: bool, way: Vector2) -> Vector3:
	var k: int = index
	if home:
		if k < 2:
			return Vector3(0.0, 0.0, float(k))
		k -= 2
	var spin: float = 1.0 if k >= SPIN_TRIES else 0.0
	k = k % SPIN_TRIES
	var along: Vector2 = way
	var distance: float
	if k < FAR_TRIES:
		distance = SPREAD + SPREAD_STEP * k
	elif k < FAR_TRIES + NEAR_TRIES:
		distance = SPREAD_NEAR + SPREAD_STEP * (k - FAR_TRIES)
	elif k < FAR_TRIES + NEAR_TRIES + 8:
		along = _turned(RING16[(k - FAR_TRIES - NEAR_TRIES) * 2], way)
		distance = SPREAD_MAX
	else:
		var wide: int = k - FAR_TRIES - NEAR_TRIES - 8
		# Map the eight remaining outer directions, then both full inner rings.
		wide = wide * 2 + 1 if wide < 8 else wide + 8
		along = _turned(RING16[wide % WIDE_ANGLES], way)
		distance = WIDE_RINGS[floori(float(wide) / float(WIDE_ANGLES))]
	return Vector3(along.x * distance, along.y * distance, spin)


## `unit` turned by the angle whose (cos, sin) is `way`.
static func _turned(unit: Vector2, way: Vector2) -> Vector2:
	return Vector2(unit.x * way.x - unit.y * way.y, unit.x * way.y + unit.y * way.x)


## Burial differences under this are rounding, not room (_clear_spot).
const ROOM_EPSILON: float = 0.000001


## Whether `foot` keeps `gap` from every one of `laid`, stopping at the first
## that it does not. One of either rectangle's axes projects at least |d|/sqrt(2).
## Thus gap_to >= |d|/sqrt(2) - min(long_half + other.reach, vice versa).
static func _clear_of(foot: Footprint, laid: Array[Footprint], gap: float) -> bool:
	for other: Footprint in laid:
		var apart: float = minf(foot.long_half + other.reach, other.long_half + foot.reach) + gap
		if foot.centre.distance_squared_to(other.centre) > 2.0 * apart * apart:
			continue
		if foot.gap_to(other) < gap:
			return false
	return true


## How buried `foot` is in `walls`: the most negative gap when it overlaps any,
## otherwise some clearance >= 0 (INF when none is near — only overlap matters
## to _clear_spot, so the far squares skip the four-axis test).
static func _wall_room(foot: Footprint, walls: Array[Footprint]) -> float:
	var room: float = INF
	for wall: Footprint in walls:
		# Disjoint bounding circles cannot overlap; SAT needs no positive gap here.
		var apart: float = foot.reach + wall.reach
		if foot.centre.distance_squared_to(wall.centre) > apart * apart:
			continue
		room = minf(room, foot.gap_to(wall))
	return room


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


## Four-axis clearance at full RIM width, before adapting it to neighbours.
static func rim_gap(centre_a: Vector2, size_a: Vector2, yaw_a: float, centre_b: Vector2, size_b: Vector2, yaw_b: float) -> float:
	return Footprint.new(centre_a, size_a, yaw_a, RIM).rim_gap_to(Footprint.new(centre_b, size_b, yaw_b, RIM))


## Distance from the finger's floor-to-top segment to the rotated footprint.
static func press_off(piece: Dictionary, low: Vector2, high: Vector2) -> float:
	var at: Vector3 = piece["at"]
	var size: Vector3 = piece["size"]
	var foot := Footprint.new(Vector2(at.x, at.z), Vector2(size.x, size.z), float(piece["yaw"]))
	var a := Vector2((low - foot.centre).dot(foot.along_x), (low - foot.centre).dot(foot.along_z))
	var b := Vector2((high - foot.centre).dot(foot.along_x), (high - foot.centre).dot(foot.along_z))
	var delta: Vector2 = b - a
	var lo := 0.0
	var hi := 1.0
	for axis: int in 2:
		if absf(delta[axis]) < 0.0000001:
			if absf(a[axis]) > foot.half[axis]:
				hi = -1.0
		else:
			var enter: float = (-foot.half[axis] - a[axis]) / delta[axis]
			var leave: float = (foot.half[axis] - a[axis]) / delta[axis]
			lo = maxf(lo, minf(enter, leave))
			hi = minf(hi, maxf(enter, leave))
	if lo <= hi:
		return 0.0
	var distance: float = minf((a.abs() - foot.half).max(Vector2.ZERO).length_squared(), (b.abs() - foot.half).max(Vector2.ZERO).length_squared())
	var length_sq: float = delta.length_squared()
	for corner: int in 4:
		var point := Vector2(foot.half.x if (corner & 1) != 0 else -foot.half.x, foot.half.y if (corner & 2) != 0 else -foot.half.y)
		var t: float = clampf((point - a).dot(delta) / length_sq, 0.0, 1.0) if length_sq > 0.0 else 0.0
		distance = minf(distance, point.distance_squared_to(a + delta * t))
	return sqrt(distance)


## Visible things win over hidden rows. Equal footprint distances follow draw
## order, then centre reach; hidden rows keep the old nearest-centre rule.
static func pick(cands: Array) -> int:
	var visible: Dictionary = {}
	var hidden: Dictionary = {}
	var nearest_off: float = INF
	for cand: Dictionary in cands:
		var reach: float = cand["reach"]
		if reach >= 0.9:
			continue
		if int(cand["order"]) < 0:
			if hidden.is_empty() or reach < float(hidden["reach"]):
				hidden = cand
			continue
		nearest_off = minf(nearest_off, float(cand["off"]))
	# Anchor ties to the minimum, so a chain of near-equals cannot drift away.
	for cand: Dictionary in cands:
		if int(cand["order"]) < 0 or float(cand["reach"]) >= 0.9 or float(cand["off"]) > nearest_off + 0.0001:
			continue
		if visible.is_empty() or int(cand["order"]) > int(visible["order"]) or (int(cand["order"]) == int(visible["order"]) and float(cand["reach"]) < float(visible["reach"])):
			visible = cand
	return int(visible["item"]) if not visible.is_empty() else int(hidden.get("item", -1))


## One thing's footprint on the floor: a rectangle `half` its sides (x, z) out
## from `centre` each way, turned by yaw as the 3D piece is (Basis(UP, yaw)).
## Its own x and z directions are worked out once, so trying it at spot after
## spot (_clear_spot) moves only the centre; before, every try turned both
## rectangles again and built arrays, and spreading 300 things went from 86 to
## 137 ms of rebuild (11-07 g6).
class Footprint:
	var centre: Vector2
	var half: Vector2
	var yaw: float
	## The slot of the last neighbour query (placement or rim widths).
	var mark: int = -1
	var along_x: Vector2
	var along_z: Vector2

	## Half its diagonal: no part of it lies further from its centre, at any yaw.
	var reach: float
	## Longest half side; like reach, unchanged by turn_to.
	var long_half: float
	## Padded bounds, cached once; walls and buckets still use the bare footprint.
	var rim_half: Vector2
	var rim_reach: float
	var rim_long_half: float

	func _init(at: Vector2, size: Vector2, turn: float, pad: float = 0.0) -> void:
		centre = at
		half = size * 0.5
		reach = half.length()
		long_half = maxf(half.x, half.y)
		rim_half = half + Vector2.ONE * pad
		rim_reach = rim_half.length()
		rim_long_half = maxf(rim_half.x, rim_half.y)
		turn_to(turn)

	## Turn it to `turn` (radians, as Basis(UP, turn)): its side directions worked
	## out again, only when the yaw really changes (_clear_spot's quarter turn).
	func turn_to(turn: float) -> void:
		yaw = turn
		var basis := Basis(Vector3.UP, turn)
		var x3: Vector3 = basis * Vector3.RIGHT
		var z3: Vector3 = basis * Vector3.BACK
		along_x = Vector2(x3.x, x3.z)
		along_z = Vector2(z3.x, z3.z)

	func cells(margin: float = 0.0) -> Rect2i:
		var extent: Vector2 = along_x.abs() * half.x + along_z.abs() * half.y + Vector2.ONE * margin
		var low := Vector2i((centre - extent).floor())
		var high := Vector2i((centre + extent).floor())
		return Rect2i(low, high - low + Vector2i.ONE)

	## The gap to `other` along the side direction, of the four, that parts them
	## most (SAT); negative when they overlap (then the least push that would part
	## them, as a negative). Along its own side direction a rectangle reaches its
	## half side; the other reaches by how its sides lie across that direction.
	func gap_to(other: Footprint) -> float:
		return _gap_to(other, half, other.half)

	func rim_gap_to(other: Footprint) -> float:
		return _gap_to(other, rim_half, other.rim_half)

	## Same axes for footprint and rim; only their half sides differ.
	func _gap_to(other: Footprint, own_half: Vector2, other_half: Vector2) -> float:
		var d: Vector2 = other.centre - centre
		var xx: float = absf(along_x.dot(other.along_x))
		var xz: float = absf(along_x.dot(other.along_z))
		var zx: float = absf(along_z.dot(other.along_x))
		var zz: float = absf(along_z.dot(other.along_z))
		var on_x: float = absf(d.dot(along_x)) - own_half.x - xx * other_half.x - xz * other_half.y
		var on_z: float = absf(d.dot(along_z)) - own_half.y - zx * other_half.x - zz * other_half.y
		var on_other_x: float = absf(d.dot(other.along_x)) - other_half.x - xx * own_half.x - zx * own_half.y
		var on_other_z: float = absf(d.dot(other.along_z)) - other_half.y - xz * own_half.x - zz * own_half.y
		return maxf(maxf(on_x, on_z), maxf(on_other_x, on_other_z))


## A dark rim round each thing (T0-6): a quad flat on its floor, up to RIM wider
## than the thing on every side. Close neighbours narrow it to leave RIM_SPACE
## of bare floor between rims, without moving the things. It darkens the floor
## (ground_rim.gdshader: black at GROUND_RIM_STRENGTH over whatever the floor is,
## so asphalt, boards and snow each go darker in their own colour).
## From above it is the outline of the flat things (a coat, a map, a knife) and
## the contact line of the taller ones, so a dark thing still stands off a
## street's grey asphalt at a phone's size; the things keep their colours (LOOKS).
const RIM: float = 0.1
## Bare floor left between two drawn rims (they narrow to keep it).
const RIM_SPACE: float = 0.01
const RIM_LIFT: float = 0.004
## Container and sled bars' rims (map_view._rim_quad's default), as before.
const RIM_STRENGTH: float = 0.8
## A ground thing's rim at its full RIM width (rim_strength).
const GROUND_RIM_STRENGTH: float = 0.8
## A ground rim narrowed to nothing by a close neighbour (rim_strength): the
## thinner it gets, the darker, so the line between two things still reads.
const NARROW_RIM_STRENGTH: float = 1.0
## ground_rim.gdshader controls: the share of the margin kept at full strength,
## and what is left of the strength on deep snow out of doors. On the new thin
## snow with grass showing (#1465) a light plank stood only 0.079 off the floor
## with the bars' 0.5 (day bar 0.085); 0.85 keeps it at 0.108.
const RIM_CORE: float = 0.6
const RIM_SNOW_KEEP: float = 0.85


## Largest common width that keeps these two rims RIM_SPACE apart (unclamped).
## Each axis gap is b - r*w, with w > 0; SAT needs any one axis to clear.
## Thus max((b - RIM_SPACE)/w) is exact. Giving both pieces no more than this
## width only increases every gap, so taking each piece's minimum is safe.
static func _rim_limit(a: Footprint, b: Footprint) -> float:
	var d: Vector2 = b.centre - a.centre
	var xx: float = absf(a.along_x.dot(b.along_x))
	var xz: float = absf(a.along_x.dot(b.along_z))
	var zx: float = absf(a.along_z.dot(b.along_x))
	var zz: float = absf(a.along_z.dot(b.along_z))
	var on_x: float = (absf(d.dot(a.along_x)) - a.half.x - xx * b.half.x - xz * b.half.y - RIM_SPACE) / (1.0 + xx + xz)
	var on_z: float = (absf(d.dot(a.along_z)) - a.half.y - zx * b.half.x - zz * b.half.y - RIM_SPACE) / (1.0 + zx + zz)
	var on_other_x: float = (absf(d.dot(b.along_x)) - b.half.x - xx * a.half.x - zx * a.half.y - RIM_SPACE) / (1.0 + xx + zx)
	var on_other_z: float = (absf(d.dot(b.along_z)) - b.half.y - xz * a.half.x - zz * a.half.y - RIM_SPACE) / (1.0 + xz + zz)
	return maxf(maxf(on_x, on_z), maxf(on_other_x, on_other_z))


## Pure width pass after placement, once per rebuild. Buckets cover bare feet.
static func _rim_widths(out: Array) -> Array[float]:
	var widths: Array[float] = []
	var feet: Array[Footprint] = []
	var buckets: Dictionary = {}
	for slot: int in out.size():
		var piece: Dictionary = out[slot]
		var at: Vector3 = piece["at"]
		var size: Vector3 = piece["size"]
		var foot := Footprint.new(Vector2(at.x, at.z), Vector2(size.x, size.z), float(piece["yaw"]))
		feet.append(foot)
		widths.append(RIM)
		var bounds: Rect2i = foot.cells()
		for y: int in range(bounds.position.y, bounds.end.y):
			for x: int in range(bounds.position.x, bounds.end.x):
				var key := Vector3i(x, y, int(piece["lv"]))
				if not buckets.has(key):
					buckets[key] = []
				buckets[key].append(slot)
	# Query both ways: cell rounding can expose a pair from just one side.
	# Each found pair limits both widths; marks skip repeated footprint buckets.
	# A pair whose bare boxes lie `m` apart along x or z is at least m apart; a
	# full rim reaches RIM*sqrt(2) further at a corner, and the four-axis gap is
	# at least the true distance over sqrt(2) — so beyond sqrt(2)*(2*RIM +
	# RIM_SPACE) two full rims already keep RIM_SPACE and need no narrowing.
	var margin: float = sqrt(2.0) * (2.0 * RIM + RIM_SPACE)
	for slot: int in out.size():
		var foot: Footprint = feet[slot]
		var bounds: Rect2i = foot.cells(margin)
		for y: int in range(bounds.position.y, bounds.end.y):
			for x: int in range(bounds.position.x, bounds.end.x):
				var key := Vector3i(x, y, int(out[slot]["lv"]))
				var near: Variant = buckets.get(key)
				if near == null:
					continue
				for other_slot: int in near:
					if other_slot == slot:
						continue
					var other: Footprint = feet[other_slot]
					if other.mark == slot:
						continue
					other.mark = slot
					# Each full rim fits in reach + sqrt(2)*RIM about its centre.
					# Beyond both radii plus sqrt(2)*RIM_SPACE, a SAT axis already
					# keeps RIM_SPACE. Square the bound to skip four-axis work.
					var far: float = foot.reach + other.reach + margin
					if foot.centre.distance_squared_to(other.centre) > far * far:
						continue
					var width: float = clampf(_rim_limit(foot, other), 0.0, RIM)
					widths[slot] = minf(widths[slot], width)
					widths[other_slot] = minf(widths[other_slot], width)
	return widths


## How dark a ground thing's rim is drawn for its width (pieces()'s "rim"):
## GROUND_RIM_STRENGTH at the full RIM, up to NARROW_RIM_STRENGTH as a close
## neighbour narrows it, so a thin rim in a crowded spot keeps its outline.
static func rim_strength(width: float) -> float:
	return lerpf(NARROW_RIM_STRENGTH, GROUND_RIM_STRENGTH, clampf(width / RIM, 0.0, 1.0))


## The rim under one of pieces()'s boxes: {"lv", "at" (centre, on the floor),
## "size" (along x and z), "inner" (the thing's share of it along x and z)}.
## Close neighbours narrow the stored width; legacy bars keep full RIM width.
static func rim(piece: Dictionary) -> Dictionary:
	var size: Vector3 = piece["size"]
	var at: Vector3 = piece["at"]
	var width: float = float(piece.get("rim", RIM))
	var outer := Vector2(size.x + 2.0 * width, size.z + 2.0 * width)
	# Existing container/sled bars pass a box centre, without the new model key.
	var floor_y: float = at.y if piece.has("model") else at.y - size.y / 2.0
	return {"lv": piece["lv"], "at": Vector3(at.x, floor_y + RIM_LIFT, at.z), "size": outer, "yaw": float(piece.get("yaw", 0.0)),
		"inner": Vector2(size.x / outer.x, size.z / outer.y)}
