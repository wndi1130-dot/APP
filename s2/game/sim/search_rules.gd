extends RefCounted
## Container work uses seconds; body/temperature multipliers belong to the tick.

const Carry = preload("res://game/sim/carry.gd")

const SKILL_STEP := 0.15
const NOISE_EVERY := 4.0
const COMPANION_LIMIT := 1
## How long opening a box takes by its size (card R1 가, after card H): a small
## cabinet half a second, a drawer or a desk a second and a half, a wardrobe, a
## counter or a crate (and a box of its own) three — whatever the map's seconds.
## The look is short; the time goes into what is taken (take_seconds).
const SIZE_SECONDS: Dictionary = {Carry.BOX_SMALL: 0.5, Carry.BOX_MID: 1.5, Carry.BOX_BIG: 3.0}
## What stands open with no door — shelves, racks, an open fridge, a bench top —
## shows what it holds at a glance, so it opens as a small cabinet does, however
## much it takes (card R1, the coordinator's detail by decision 442).
const SEE_THROUGH: Array = [
	"towel_shelf", "small_shelf", "bookcase", "jar_shelf", "record_shelf_row", "hymn_shelf", "lamp_shelf",
	"evidence_shelf", "bread_rack", "mail_sorting_rack", "shelf", "display_shelf", "fridge_open",
	"workbench", "tool_bench", "hardware_rack", "parts_rack", "cloth_bolt_rack",
]
## Taking a thing out of a box (card R1 가): this many seconds a unit of weight,
## never more than TAKE_MOST for one thing.
const TAKE_PER_WEIGHT := 0.6
const TAKE_MOST := 2.0


static func seconds(base: float, skill: int) -> float:
	return maxf(base, 0.0) / (1.0 + SKILL_STEP * maxi(skill, 0))


## A box's own seconds before the searcher's skill: by its size, or a small
## cabinet's when it stands open.
static func box_seconds(c: Dictionary) -> float:
	if SEE_THROUGH.has(String(c.get("furniture", ""))):
		return float(SIZE_SECONDS[Carry.BOX_SMALL])
	return float(SIZE_SECONDS.get(Carry.box_limit(c), SIZE_SECONDS[Carry.BOX_BIG]))


## How long one thing takes to come out of a box, by its weight.
static func take_seconds(item: String) -> float:
	return minf(TAKE_PER_WEIGHT * Carry.item_weight(item), TAKE_MOST)


## The order 「모두 담기」 takes things in: the heaviest first (card R1 가), so the
## time it costs shows at once; the same weight keeps the box's order.
static func take_order(items: Array) -> Array:
	var order: Array = range(items.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var wa := Carry.item_weight(String(items[a]))
		var wb := Carry.item_weight(String(items[b]))
		return wa > wb or (wa == wb and a < b))
	var out: Array = []
	for i: int in order:
		out.append(items[i])
	return out


static func can_search(container: Dictionary) -> bool:
	return not container.is_empty() and not bool(container.get("locked", false)) and not bool(container.get("searched", false)) and not bool(container.get("busy", false))


static func can_take(container: Dictionary) -> bool:
	return not container.is_empty() and bool(container.get("searched", false)) and not bool(container.get("locked", false)) and not bool(container.get("busy", false))
