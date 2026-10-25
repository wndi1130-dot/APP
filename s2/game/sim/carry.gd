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


# Seconds to bring a weapon to hand from "hand", "belt" or "bag".
static func swap_time(from_slot: String, carry_state: int) -> float:
	match from_slot:
		"hand":
			return SWAP_HAND
		"belt":
			return SWAP_BELT
	return SWAP_BAG + (SWAP_BAG_HEAVY if carry_state >= 1 else 0.0)
