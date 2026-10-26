extends RefCounted
## What lies on the ground, drawn (decision 444, 차이 6·7의 앞단): every thing in
## game.ground_items but the ones still shining in the snow (decision 423 (11):
## those are a light only, field_hud.gd) gets a grey-box shape of its kind on its
## floor, so a coat taken off, what a fallen one had, a thrown tin or a spent
## arrow is seen where it lies; before, it was found only by walking into 「줍기」.
## No word and no icon (결정 417); the real models are art3d's.
##
## 금지선: no case, bundle or bag shapes and no heaps. A sack or a crate at most;
## things at one spot are spread over their cell and no more than PER_CELL are
## drawn on a cell (the rest are still on the pick-up list).

const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const Wear = preload("res://game/sim/wear.gd")
const W = preload("res://game/sim/weapons.gd")
const Carry = preload("res://game/sim/carry.gd")

const LEVEL_H: float = 3.0
## Drawn on one cell at most.
const PER_CELL: int = 3
## How far the second and third things on a cell lie from the first (metres):
## inside the 0.9 a tap reaches (field_hud.gd _tap_thing).
const SPREAD: float = 0.3

## Kind -> [size (x, y, z: the long side along x), colour as seen (sRGB)].
## Dark, muted greys and browns, no bright ones (white snow and pale floors
## round them). world_vis.gdshader takes a vertex colour as linear, so pieces()
## turns these into linear; written as they are, the check shots lost them on
## the floorboards.
const LOOKS: Dictionary = {
	"weapon": [Vector3(0.75, 0.06, 0.1), Color(0.2, 0.2, 0.21)],
	"garment": [Vector3(0.5, 0.04, 0.38), Color(0.25, 0.26, 0.29)],
	"cloth": [Vector3(0.3, 0.03, 0.24), Color(0.33, 0.32, 0.3)],
	"paper": [Vector3(0.2, 0.01, 0.14), Color(0.52, 0.5, 0.45)],
	"board": [Vector3(0.9, 0.04, 0.18), Color(0.36, 0.27, 0.18)],
	"sack": [Vector3(0.34, 0.22, 0.26), Color(0.42, 0.36, 0.26)],
	"small": [Vector3(0.2, 0.14, 0.2), Color(0.28, 0.28, 0.29)],
	"crate": [Vector3(0.36, 0.24, 0.28), Color(0.34, 0.26, 0.17)],
	"big": [Vector3(0.5, 0.34, 0.4), Color(0.3, 0.23, 0.15)],
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


## The boxes to draw: [{"lv", "size", "at" (centre), "color"}], in list order.
static func pieces(items: Array) -> Array:
	var out: Array = []
	var on_cell: Dictionary = {}  # Vector3i(x, y, lv) -> drawn there so far
	for g: Dictionary in items:
		if bool(g.get("glint", false)):
			continue
		var pos: Vector3 = g["pos"]
		var lv := clampi(roundi(pos.y / LEVEL_H), -1, 2)
		var c := FieldGrid.cell_of(pos)
		var key := Vector3i(c.x, c.y, lv)
		var k := int(on_cell.get(key, 0))
		if k >= PER_CELL:
			continue
		on_cell[key] = k + 1
		var h: int = hash(Vector4i(c.x, c.y, lv, k))
		var at := Vector3(pos.x, lv * LEVEL_H, pos.z)
		if k > 0:
			var turn := deg_to_rad(float(posmod(h, 360)))
			at += Vector3(cos(turn), 0, sin(turn)) * SPREAD
		var look: Array = LOOKS[kind_of(g)]
		var size: Vector3 = look[0]
		if (h >> 9) & 1 == 1:
			size = Vector3(size.z, size.y, size.x)
		# Vertex alpha 0 reads as under a roof in world_vis.gdshader: no snow,
		# rain or ground grain over it, so a grey thing does not go white and
		# vanish (what lies buried shines instead, decision 423 (11)).
		var color: Color = (look[1] as Color).srgb_to_linear()
		color.a = 0.0
		out.append({"lv": lv, "size": size, "at": at + Vector3(0, size.y / 2.0, 0), "color": color})
	return out
