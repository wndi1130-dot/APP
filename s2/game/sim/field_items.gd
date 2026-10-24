extends RefCounted

const Wear = preload("res://game/sim/wear.gd")
## The field's named things (decision 423-8, field_unified 4장 「물건 두 층」): what
## comes out of a box has a name and a picture of its own, and on the train it
## melts into the stock numbers the politics reads, as before. Values only, and
## the small pure rules that read them; where they go into a stop is in
## loot_dress.gd.
##
## A row: name (short, 결정 417), icon (hud_icons.gd), weight (pack units, as
## carry.gd), stock and melt (what it becomes on the train), group. A thing cut
## from a bundle ("from") keeps the bundle's worth per weight, times its state:
## a food bundle is 1.0 of weight and 0.5 of food, so 1.5 of oats is 0.75 and a
## wilted apple 0.6 of its 0.5. Nothing that a rule already names (판자, 고철,
## 목재, 천, 붕대, 술 한 병, 바늘과 실, 핀셋, 구급함) is renamed: treating,
## splints, barricades and the stop goals read those ids.

## What a bundle is worth per weight on the train (field_game.gd STOCK_OF, kept).
const BUNDLES: Dictionary = {
	"food_pack": {"group": "food", "stock": "food", "per_weight": 0.5},
	"med_box": {"group": "med", "stock": "medicine", "per_weight": 0.5},
	"luxury_pack": {"group": "lux", "stock": "luxury", "per_weight": 0.5},
}

## Food states (survival_detail 3.5): what reaches the train's food.
const STATE_WORTH: Dictionary = {"sealed": 1.0, "dry": 1.0, "fresh": 1.0, "wilted": 0.6, "spoiled": 0.0, "frozen": 1.0}
## A dented tin may have gone off (survival_detail 3.5: 10%). Rolled when the
## stop is made; both look the same until opened.
const DENTED_BAD: float = 0.10

const ITEMS: Dictionary = {
	# ---- food (from food_pack)
	"can_beans": {"name": "콩 통조림", "icon": "it_can", "weight": 1.0, "from": "food_pack", "state": "sealed", "eat": "can"},
	"can_meat": {"name": "고기 통조림", "icon": "it_can_meat", "weight": 1.0, "from": "food_pack", "state": "sealed", "eat": "can"},
	"can_dented": {"name": "찌그러진 통조림", "icon": "it_can_dented", "weight": 1.0, "from": "food_pack", "state": "sealed", "eat": "can"},
	# The one that has gone off: the same name and picture, nothing on the train.
	"can_dented_bad": {"name": "찌그러진 통조림", "icon": "it_can_dented", "weight": 1.0, "from": "food_pack", "state": "spoiled", "eat": "can", "looks_like": "can_dented"},
	"jar_cabbage": {"name": "절인 양배추 병", "icon": "it_jar", "weight": 1.0, "from": "food_pack", "state": "sealed", "eat": "jar"},
	"jar_jam": {"name": "잼 병", "icon": "it_jar_jam", "weight": 1.0, "from": "food_pack", "state": "sealed", "eat": "jar"},
	"jar_honey": {"name": "꿀 단지", "icon": "it_honey", "weight": 1.0, "from": "food_pack", "state": "sealed", "eat": "jar"},
	"hardtack": {"name": "건빵", "icon": "it_hardtack", "weight": 0.5, "from": "food_pack", "state": "dry", "eat": "plain"},
	"rusk": {"name": "말린 빵", "icon": "it_rusk", "weight": 0.5, "from": "food_pack", "state": "dry", "eat": "plain"},
	"sugar": {"name": "설탕 봉지", "icon": "it_sugar", "weight": 0.5, "from": "food_pack", "state": "dry", "eat": "plain"},
	"oats": {"name": "귀리 자루", "icon": "it_sack", "weight": 1.5, "from": "food_pack", "state": "dry", "eat": "cook"},
	"peas": {"name": "말린 콩 자루", "icon": "it_sack_peas", "weight": 1.5, "from": "food_pack", "state": "dry", "eat": "cook"},
	"flour": {"name": "밀가루 자루", "icon": "it_flour", "weight": 1.5, "from": "food_pack", "state": "dry", "eat": "cook"},
	"apple": {"name": "사과", "icon": "it_apple", "weight": 1.0, "from": "food_pack", "state": "fresh", "eat": "plain"},
	"apple_wilted": {"name": "시든 사과", "icon": "it_apple_wilted", "weight": 1.0, "from": "food_pack", "state": "wilted", "eat": "plain"},
	"meat_frozen": {"name": "얼어붙은 고기", "icon": "it_meat", "weight": 1.0, "from": "food_pack", "state": "frozen", "eat": "thaw"},
	"fish_frozen": {"name": "언 생선", "icon": "it_fish", "weight": 1.0, "from": "food_pack", "state": "frozen", "eat": "thaw"},
	"meat_spoiled": {"name": "상한 고기", "icon": "it_meat_bad", "weight": 1.0, "from": "food_pack", "state": "spoiled", "eat": "no"},
	"bread_moldy": {"name": "곰팡이 핀 빵", "icon": "it_bread_moldy", "weight": 0.5, "from": "food_pack", "state": "spoiled", "eat": "no"},
	# ---- medicine (from med_box)
	"painkillers": {"name": "진통제", "icon": "it_pills", "weight": 1.0, "from": "med_box"},
	"fever_pills": {"name": "해열제", "icon": "it_blister", "weight": 0.5, "from": "med_box"},
	"ointment": {"name": "연고", "icon": "it_tube", "weight": 0.5, "from": "med_box"},
	"cough_syrup": {"name": "기침약 병", "icon": "it_syrup", "weight": 1.0, "from": "med_box"},
	# Wounds only (금지선: 「소독」은 상처와 수술 도구에만).
	"antiseptic": {"name": "소독약", "icon": "it_antiseptic", "weight": 1.0, "from": "med_box"},
	"herbs": {"name": "약초 다발", "icon": "it_herbs", "weight": 1.5, "from": "med_box"},
	"saline": {"name": "링거 병", "icon": "it_saline", "weight": 1.5, "from": "med_box"},
	# ---- luxuries (from luxury_pack; the name tags of decision 071)
	"cigarettes": {"name": "담배 한 보루", "icon": "it_cigarettes", "weight": 0.5, "from": "luxury_pack", "tag": "담배"},
	"coffee": {"name": "커피 깡통", "icon": "it_coffee", "weight": 1.0, "from": "luxury_pack", "tag": "커피"},
	"record": {"name": "음반", "icon": "it_record", "weight": 1.0, "from": "luxury_pack", "tag": "음반"},
	"painting": {"name": "작은 그림", "icon": "it_painting", "weight": 1.5, "from": "luxury_pack", "tag": "그림"},
	"pocket_watch": {"name": "회중시계", "icon": "it_pocket_watch", "weight": 0.5, "from": "luxury_pack", "tag": "시계"},
	# ---- found on their own (new sources, loot_dress.gd and the pockets)
	# A wrist watch; one still set rings in the bag later unless switched off.
	"wrist_watch": {"name": "손목시계", "icon": "clock", "weight": 0.25, "stock": "luxury", "melt": 0.25, "group": "lux", "tag": "시계"},
	"wrist_watch_set": {"name": "손목시계", "icon": "clock", "weight": 0.25, "stock": "luxury", "melt": 0.25, "group": "lux", "tag": "시계", "alarm": true, "looks_like": "wrist_watch"},
	"can_opener": {"name": "깡통 따개", "icon": "it_opener", "weight": 0.1, "group": "tool", "keep": true},
	"nails": {"name": "못 한 줌", "icon": "it_nails", "weight": 0.5, "stock": "scrap", "melt": 0.5, "group": "material"},
	"fuel_can": {"name": "연료 통", "icon": "it_fuel", "weight": 1.5, "stock": "coal", "melt": 1.0, "group": "material"},
	# What the train's workshop makes parts of, picked up as it lies (decision 426 D2).
	"gears": {"name": "톱니바퀴", "icon": "gear", "weight": 0.6, "stock": "parts", "melt": 0.5, "group": "material"},
	"springs": {"name": "용수철 한 줌", "icon": "it_spring", "weight": 0.3, "stock": "parts", "melt": 0.25, "group": "material"},
	"wire_coil": {"name": "전선 뭉치", "icon": "it_wire", "weight": 0.5, "stock": "parts", "melt": 0.25, "group": "material"},
	# A bigger pack, worn at once if it is bigger than the one on the back.
	"found_big_pack": {"name": "큰 배낭", "icon": "inv", "weight": 1.0, "group": "bag", "bag": "big_pack", "keep": true},
	# ---- 나단계 (decision 423 cards 10·11, P22)
	# What is left of an opened tin: thrown, it rattles where it lands (a lure).
	"can_empty": {"name": "빈 깡통", "icon": "it_can", "weight": 0.2, "group": "tool", "throw": true, "stays": true},
	# Found in the snow (card 11): a frozen hare, food once thawed.
	"hare_frozen": {"name": "언 토끼", "icon": "it_hare", "weight": 1.0, "stock": "food", "melt": 0.5, "group": "food", "state": "frozen", "eat": "thaw"},
	# A note from a dead one's pocket (card 10): where a box is hidden at the next stop.
	"note_map": {"name": "쪽지", "icon": "papers", "weight": 0.05, "group": "paper", "keep": true},
}

## A building's key (P12): one id a building, "key_<building index>". It opens
## that building's locked doors without a sound and stays in the field.
const KEY_PREFIX: String = "key_"
const KEY_ROW: Dictionary = {"name": "열쇠", "icon": "it_key", "weight": 0.05, "group": "key", "stays": true}

## Named finds, at most one a stop (P14). "places" are the stop kinds it can
## turn up at; "line" is what the one who finds it says, once.
const RARE: Dictionary = {
	"rare_silver_case": {"name": "은 담뱃갑", "icon": "it_cigarettes", "weight": 0.5, "stock": "luxury", "melt": 1.0, "places": ["houses", "lodge", "lake", "office"], "line": "뚜껑 안에 이름 두 개가 새겨져 있다."},
	"rare_violin": {"name": "낡은 바이올린", "icon": "it_violin", "weight": 2.0, "stock": "luxury", "melt": 1.5, "places": ["houses", "church", "lodge"], "line": "케이스 안에 접힌 악보가 끼워져 있다."},
	"rare_doctor_case": {"name": "왕진 상자", "icon": "it_doctor_box", "weight": 1.5, "stock": "medicine", "melt": 2.0, "places": ["hospital", "houses", "lake"], "line": "뚜껑에 마을 이름과 번지가 적혀 있다."},
	"rare_coffee_sack": {"name": "커피 원두 자루", "icon": "it_sack", "weight": 1.5, "stock": "luxury", "melt": 1.5, "places": ["freight", "office", "factory"], "line": "자루에 항구 도장이 찍혀 있다."},
	"rare_herbal": {"name": "약초 도감", "icon": "book", "weight": 1.0, "stock": "medicine", "melt": 1.0, "places": ["church", "lodge", "houses", "office"], "line": "여백마다 다른 손글씨가 덧붙어 있다."},
	"rare_can_crate": {"name": "통조림 궤짝", "icon": "it_crate", "weight": 3.0, "stock": "food", "melt": 1.5, "places": ["freight", "factory", "mine", "sawmill"], "line": "궤짝 옆에 「겨울용」이라고 분필로 적혀 있다."},
	"rare_wine_case": {"name": "포도주 한 상자", "icon": "it_crate", "weight": 2.0, "stock": "luxury", "melt": 2.0, "places": ["lodge", "houses", "church", "lake"], "line": "병마다 같은 해 숫자가 적혀 있다."},
	"rare_saw_blades": {"name": "새 톱날 꾸러미", "icon": "wrench", "weight": 1.0, "stock": "scrap", "melt": 2.0, "places": ["sawmill", "factory", "mine", "summit", "bare_line"], "line": "기름종이에 싸여 녹 하나 없다."},
}


## Clothes are on the list too (decision 423 card 2): their name, picture and
## weight are wear.gd's; they are worn, not carried, so they never melt.
static func has(id: String) -> bool:
	return ITEMS.has(id) or RARE.has(id) or is_key(id) or Wear.is_garment(id)


static func row(id: String) -> Dictionary:
	if ITEMS.has(id):
		return ITEMS[id]
	if is_key(id):
		return KEY_ROW
	if Wear.is_garment(id):
		return Wear.KINDS[id]
	return RARE.get(id, {})


static func is_key(id: String) -> bool:
	return id.begins_with(KEY_PREFIX) and id.trim_prefix(KEY_PREFIX).is_valid_int()


static func key_for(building: int) -> String:
	return "%s%d" % [KEY_PREFIX, building]


## The building a key opens (-1 for no key).
static func key_building(id: String) -> int:
	return int(id.trim_prefix(KEY_PREFIX)) if is_key(id) else -1


## Things that stay on the body when the rest is loaded on the train: a key,
## an empty tin, the can opener.
static func stays_on_body(id: String) -> bool:
	return bool(row(id).get("stays", false)) or id == "can_opener"


static func throwable(id: String) -> bool:
	return bool(row(id).get("throw", false))


static func item_name(id: String) -> String:
	return String(row(id).get("name", id))


static func icon(id: String) -> String:
	return String(row(id).get("icon", ""))


static func weight(id: String) -> float:
	return float(row(id).get("weight", 0.0))


static func group(id: String) -> String:
	var r := row(id)
	if r.has("from"):
		return String(BUNDLES[r["from"]]["group"])
	if RARE.has(id):
		return "rare"
	return String(r.get("group", ""))


## [stock key, amount] this thing becomes on the train, or ["", 0.0].
static func stock_of(id: String) -> Array:
	var r := row(id)
	if r.is_empty():
		return ["", 0.0]
	if r.has("from"):
		var b: Dictionary = BUNDLES[r["from"]]
		var worth: float = float(STATE_WORTH.get(String(r.get("state", "")), 1.0))
		return [String(b["stock"]), float(b["per_weight"]) * float(r["weight"]) * worth]
	if r.has("stock"):
		return [String(r["stock"]), float(r.get("melt", 0.0))]
	return ["", 0.0]


## Things that go on the receipt's list by name as well (field_unified 4장:
## 「개별 물건」): the named finds, and a tool or a pack the train keeps.
static func kept_by_name(id: String) -> bool:
	return RARE.has(id) or bool(row(id).get("keep", false))


## What the one who picks it up says once (a named find).
static func line(id: String) -> String:
	return String(RARE.get(id, {}).get("line", ""))


static func rings(id: String) -> bool:
	return bool(row(id).get("alarm", false))


## The same thing with its alarm off (or the id itself).
static func silenced(id: String) -> String:
	return String(row(id).get("looks_like", id)) if rings(id) else id


## The bag a found pack is (or "").
static func bag_of(id: String) -> String:
	return String(row(id).get("bag", ""))


# ---------------------------------------------------------------- eating

## Opening and eating in the field (survival_detail 3.5): a tin wants an opener,
## or a knife for ten seconds (the blade slips now and then), or a blunt blow
## that spills half and is heard. A jar opens by hand. Raw and frozen things
## want a fire, spoiled ones are left, sacks of grain want a pot: not here.
const OPEN_OPENER_S: float = 3.0
const OPEN_KNIFE_S: float = 10.0
const KNIFE_SLIP: float = 0.05
const OPEN_BASH_S: float = 4.0
const OPEN_JAR_S: float = 2.0
const EAT_S: float = 3.0
## What a meal takes off exhaustion (body_state 0..1); a spilled tin half.
const EAT_REST: float = 0.15
const SPILL: float = 0.5


## How this one would eat it: {"ok", "seconds", "slip" (chance of a light cut),
## "spill" (share lost), "loud" (a blow that is heard), "why" (when not ok)}.
## tools: "opener" (has a can opener), "knife" (a blade in hand or belt),
## "blunt" (another melee weapon).
static func eat_plan(id: String, tools: Dictionary) -> Dictionary:
	var r := row(id)
	var how: String = String(r.get("eat", ""))
	var out := {"ok": false, "seconds": 0.0, "slip": 0.0, "spill": 0.0, "loud": false, "why": ""}
	match how:
		"plain":
			out["ok"] = true
			out["seconds"] = EAT_S
		"jar":
			out["ok"] = true
			out["seconds"] = OPEN_JAR_S + EAT_S
		"can":
			if bool(tools.get("opener", false)):
				out["ok"] = true
				out["seconds"] = OPEN_OPENER_S + EAT_S
			elif bool(tools.get("knife", false)):
				out["ok"] = true
				out["seconds"] = OPEN_KNIFE_S + EAT_S
				out["slip"] = KNIFE_SLIP
			elif bool(tools.get("blunt", false)):
				out["ok"] = true
				out["seconds"] = OPEN_BASH_S + EAT_S
				out["spill"] = SPILL
				out["loud"] = true
			else:
				out["why"] = "딸 것이 없다"
		"thaw":
			out["why"] = "녹여야 먹는다"
		"cook":
			out["why"] = "끓여야 먹는다"
		"no":
			out["why"] = "상했다"
		_:
			out["why"] = "먹을 것이 아니다"
	return out


## What a meal of it does: exhaustion taken off, and whether it had gone off.
static func eat_result(id: String, spill: float) -> Dictionary:
	if String(row(id).get("state", "")) == "spoiled":
		return {"rest": 0.0, "bad": true}
	return {"rest": EAT_REST * (1.0 - clampf(spill, 0.0, 1.0)), "bad": false}


static func edible(id: String) -> bool:
	return ["plain", "jar", "can", "thaw", "cook", "no"].has(String(row(id).get("eat", "")))
