extends RefCounted
# Carry weight in pack units, not kg (body_injury 6).

const W = preload("res://game/sim/weapons.gd")

const BAGS: Dictionary = {
	"pockets": {"name": "주머니만", "limit": 3},
	"pack": {"name": "배낭", "limit": 8},
	"big_pack": {"name": "큰 배낭", "limit": 12},
}

const ITEM_WEIGHTS: Dictionary = {
	"food_pack": 1.0, "med_box": 1.0, "ammo_box": 1.0, "luxury_pack": 1.0, "document": 0.5,
	"symbol_bell": 4.0, "bandage": 0.1, "cloth": 0.2, "plank": 1.0, "bottle_spirit": 0.5, "medkit": 1.0,
	"scrap": 1.0, "wood": 1.0, "info_telegraph": 0.5, "info_timetable": 0.5, "flare": 0.5,
	"ammo_pistol": 0.1, "ammo_shell": 0.2, "arrow": 0.05,
	"tweezers": 0.05, "needle_thread": 0.05,
}

const ITEM_NAMES: Dictionary = {
	"food_pack": "식량 꾸러미", "med_box": "약 상자", "ammo_box": "탄 상자", "luxury_pack": "사치품 꾸러미",
	"document": "문서", "symbol_bell": "출발 종", "bandage": "붕대", "cloth": "천", "plank": "판자",
	"bottle_spirit": "술 한 병", "medkit": "구급함",
	"scrap": "고철", "wood": "목재", "info_telegraph": "전신 기록", "info_timetable": "시간표", "flare": "철도 섬광",
	"ammo_pistol": "권총탄 한 줌", "ammo_shell": "산탄 한 줌", "arrow": "화살",
	"tweezers": "핀셋", "needle_thread": "바늘과 실",
}

const STATE_NAMES: Array[String] = ["가벼움", "절반 넘음", "넘침", "못 움직임"]

const SWAP_HAND := 0.5
const SWAP_BELT := 1.0
const SWAP_BAG := 2.5
const SWAP_BAG_HEAVY := 1.0


static func limit(bag: String, strength: int) -> float:
	var row: Dictionary = BAGS.get(bag, BAGS["pockets"])
	var l: float = float(row["limit"])
	if strength >= 7:
		l += 2.0
	elif strength <= 3:
		l -= 2.0
	return maxf(0.0, l)


# 0 up to half, 1 up to limit, 2 up to double, 3 beyond double (cannot move).
static func state(weight: float, p_limit: float) -> int:
	if weight <= p_limit * 0.5:
		return 0
	if weight <= p_limit:
		return 1
	if weight <= p_limit * 2.0:
		return 2
	return 3


# Weight of one item id: field items first, then weapons.
static func item_weight(id: String) -> float:
	if ITEM_WEIGHTS.has(id):
		return float(ITEM_WEIGHTS[id])
	return float(W.get_data(id).get("weight", 0.0))


# items: {id: count}
static func total_weight(items: Dictionary) -> float:
	var t: float = 0.0
	for id: String in items:
		t += item_weight(id) * float(items[id])
	return t


# Seconds to bring a weapon to hand from "hand", "belt" or "bag".
static func swap_time(from_slot: String, carry_state: int) -> float:
	match from_slot:
		"hand":
			return SWAP_HAND
		"belt":
			return SWAP_BELT
	return SWAP_BAG + (SWAP_BAG_HEAVY if carry_state >= 1 else 0.0)
