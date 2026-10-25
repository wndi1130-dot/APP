extends RefCounted
# Carry weight in pack units, not kg (body_injury 6).

const W = preload("res://game/sim/weapons.gd")
const FieldItems = preload("res://game/sim/field_items.gd")

const BAGS: Dictionary = {
	"pockets": {"name": "주머니만", "limit": 3},
	"pack": {"name": "배낭", "limit": 8},
	"big_pack": {"name": "큰 배낭", "limit": 12},
}

const ITEM_WEIGHTS: Dictionary = {
	"food_pack": 1.0, "med_box": 1.0, "ammo_box": 1.0, "luxury_pack": 1.0, "document": 0.5,
	"symbol_bell": 4.0, "bandage": 0.1, "cloth": 0.2, "plank": 1.0, "bottle_spirit": 0.5, "medkit": 1.0,
	"scrap": 1.0, "wood": 1.0, "info_telegraph": 0.5, "info_timetable": 0.5, "flare": 0.5,
	"ammo_pistol": 0.1, "ammo_shell": 0.2, "ammo_craft": 0.05,
	"tweezers": 0.05, "needle_thread": 0.05,
	"tourniquet": 1.2, # one cloth and one plank
	# The core of the pass's plough (user decision 194): half a pack by itself.
	"plow_core": 4.0,
	# The cores of the fixed scenes (decision 426, core_scenes.gd WEIGHT).
	"core_engine": 4.0, "core_electric": 4.0,
}

const ITEM_NAMES: Dictionary = {
	"food_pack": "식량 꾸러미", "med_box": "약 상자", "ammo_box": "탄 상자", "luxury_pack": "사치품 꾸러미",
	"document": "문서", "symbol_bell": "출발 종", "bandage": "붕대", "cloth": "천", "plank": "판자",
	"bottle_spirit": "술 한 병", "medkit": "구급함", "plow_core": "제설기 코어", "core_engine": "기관 코어", "core_electric": "전기 코어",
	"scrap": "고철", "wood": "목재", "info_telegraph": "전신 기록", "info_timetable": "시간표", "flare": "철도 섬광",
	"ammo_pistol": "권총탄 한 줌", "ammo_shell": "산탄 한 줌", "ammo_craft": "화살",
	"tweezers": "핀셋", "needle_thread": "바늘과 실",
	"tourniquet": "지혈대",
}

const STATE_NAMES: Array[String] = ["가벼움", "절반 넘음", "넘침", "못 움직임"]

const SWAP_HAND := 0.5
const SWAP_BELT := 1.0
const SWAP_BAG := 2.5
const SWAP_BAG_HEAVY := 1.0
const STRONG := 7
const WEAK := 3
const STRENGTH_CAPACITY := 2.0
const HALF_FULL := 0.5
const IMMOBILE_LOAD := 2.0
const RESERVE_WEAPON_WEIGHT := 0.5
const SOAKED_THRESHOLD := 0.5
const SOAKED_WEIGHT := 1.0


static func limit(bag: String, strength: int) -> float:
	var row: Dictionary = BAGS.get(bag, BAGS["pockets"])
	var l: float = float(row["limit"])
	if strength >= STRONG:
		l += STRENGTH_CAPACITY
	elif strength <= WEAK:
		l -= STRENGTH_CAPACITY
	return maxf(0.0, l)


# 0 up to half, 1 up to limit, 2 up to double, 3 beyond double (cannot move).
static func state(weight: float, p_limit: float) -> int:
	var load := maxf(0.0, weight)
	var capacity := maxf(0.0, p_limit)
	if load <= capacity * HALF_FULL:
		return 0
	if load <= capacity:
		return 1
	if load <= capacity * IMMOBILE_LOAD:
		return 2
	return 3


# Weight of one item id: field items first, then the named things, then weapons.
static func item_weight(id: String) -> float:
	if ITEM_WEIGHTS.has(id):
		return float(ITEM_WEIGHTS[id])
	if FieldItems.has(id):
		return FieldItems.weight(id)
	return float(W.get_data(id).get("weight", 0.0))


# items: {id: count}
static func total_weight(items: Dictionary) -> float:
	var t: float = 0.0
	for id: String in items:
		t += item_weight(id) * maxf(0.0, float(items[id]))
	return t


## How much a box takes from a bag (inventory.md 3.3), by the furniture it
## stands in: a drawer's 20, a counter's or a crate's 50 on our scale (×0.4 —
## a 배낭 is a drawer's worth); a small cabinet's 10 would be 4, but the maps
## already dress some with up to 5.7, so 6. A box of its own is a crate; a
## furniture this does not know, a drawer. What a map is dressed with is not
## held to it: only what is put in.
const BOX_SMALL: float = 6.0
const BOX_MID: float = 8.0
const BOX_BIG: float = 20.0
const BOX_LIMITS: Dictionary = {
	"": BOX_BIG,
	"nightstand": BOX_SMALL, "side_table": BOX_SMALL, "washstand": BOX_SMALL, "towel_shelf": BOX_SMALL,
	"toolbox": BOX_SMALL, "strongbox": BOX_SMALL, "glass_cabinet": BOX_SMALL,
	"dresser": BOX_MID, "cupboard": BOX_MID, "bookcase": BOX_MID, "jar_shelf": BOX_MID, "desk": BOX_MID,
	"typewriter_desk": BOX_MID, "office_desk": BOX_MID, "file_cabinet": BOX_MID, "map_cabinet": BOX_MID,
	"office_cabinet": BOX_MID, "record_shelf_row": BOX_MID, "hymn_shelf": BOX_MID, "lamp_shelf": BOX_MID,
	"evidence_shelf": BOX_MID, "bread_rack": BOX_MID, "mail_sorting_rack": BOX_MID, "medicine_crate": BOX_MID,
	"vestry_chest": BOX_MID, "conductor_log_chest": BOX_MID, "ration_ledger_chest": BOX_MID,
	"drawer_chest_spilled": BOX_MID,
	"wardrobe": BOX_BIG, "counter": BOX_BIG, "shop_counter": BOX_BIG, "service_counter": BOX_BIG,
	"checkout": BOX_BIG, "shelf": BOX_BIG, "display_shelf": BOX_BIG, "crate_stack": BOX_BIG, "tin_crate": BOX_BIG,
	"part_crate": BOX_BIG, "ammo_crate": BOX_BIG, "relief_crate": BOX_BIG, "blanket_crate": BOX_BIG,
	"blanket_chest": BOX_BIG, "parish_chest": BOX_BIG, "fridge_open": BOX_BIG, "freezer_chest": BOX_BIG,
	"workbench": BOX_BIG, "tool_bench": BOX_BIG, "tool_chest": BOX_BIG, "hardware_rack": BOX_BIG,
	"parts_rack": BOX_BIG, "cloth_bolt_rack": BOX_BIG, "cask_stack": BOX_BIG,
}


## A box's limit (c: a game.data["containers"] row).
static func box_limit(c: Dictionary) -> float:
	return float(BOX_LIMITS.get(String(c.get("furniture", "")), BOX_MID))


## What a box holds now.
static func box_load(c: Dictionary) -> float:
	var t: float = 0.0
	for id in c.get("items", []):
		t += item_weight(String(id))
	return t


## How many of `id` the box still takes (none once it is at its limit or over).
static func box_room(c: Dictionary, id: String) -> int:
	var room: float = box_limit(c) - box_load(c)
	var w: float = item_weight(id)
	if w <= 0.0:
		return 999 if room >= 0.0 else 0
	return maxi(0, floori((room + 0.0001) / w))


# Seconds to bring a weapon to hand from "hand", "belt" or "bag".
static func swap_time(from_slot: String, carry_state: int) -> float:
	match from_slot:
		"hand":
			return SWAP_HAND
		"belt":
			return SWAP_BELT
	return SWAP_BAG + (SWAP_BAG_HEAVY if carry_state >= 1 else 0.0)
