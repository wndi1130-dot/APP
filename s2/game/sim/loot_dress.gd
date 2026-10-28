extends RefCounted
## Dressing a stop's boxes when the stop is made (decision 423-8, P01·P14·P19·P20):
## what a building holds stays what the map gave it, but it goes where the room
## says it would be (food to the kitchen and the larder, iron to the toolbox,
## cloth and small things to the bedroom), so some boxes come up empty more
## often than others and 「여긴 건너뛰자」 can be learnt; then every bundle gets a
## name (field_items.gd), and a few finds of their own go in: a bigger pack, a
## watch, a can opener, nails, a fuel can, and now and then one named find.
##
## Rolled once from the run's seed, like the pockets: same seed, same stop. The
## map's numbers are not changed: a building ends with the same bundles it
## started with (the finds are added on top, each listed in the PR's new values),
## save the few moved between buildings to keep a promised share (PROMISES).
## Untouched: a stop goal's box ("pick"), the fixed boxes the story leans on
## (loot_tables.gd FIXED, only named), locked ones (only named; a named find may
## go in one), and boxes standing in no building (only named).

const FieldItems = preload("res://game/sim/field_items.gd")
const LootTables = preload("res://game/sim/loot_tables.gd")
const LootJunk = preload("res://game/sim/loot_junk.gd")
const Carry = preload("res://game/sim/carry.gd")

## What may be moved between the boxes of one building, and as what.
const FAMILY: Dictionary = {
	"food_pack": "food", "med_box": "med", "luxury_pack": "lux",
	"plank": "wood", "wood": "wood", "scrap": "scrap", "cloth": "cloth",
	"bandage": "small", "bottle_spirit": "small",
}

## The room a box stands in, from the words of its name (first kind that
## matches wins, in this order). A map may give a box a "room" of its own.
const ROOM_ORDER: Array[String] = ["toolbox", "clinic", "bathroom", "kitchen", "pantry", "bedroom", "shop", "office", "hall", "storage"]
const ROOM_WORDS: Dictionary = {
	"toolbox": ["공구", "작업", "자재함", "부품", "정비", "기계", "철물", "도면"],
	"clinic": ["진료", "약국", "약방", "약장", "병실", "간호", "처치", "구급", "의무"],
	"bathroom": ["화장실", "세면", "욕실"],
	"kitchen": ["부엌", "찬장", "식당", "취사", "식료"],
	"pantry": ["저장", "곳간", "광", "식량", "얼음", "지하실"],
	"bedroom": ["안방", "침실", "옷장", "서랍", "숙직", "기숙", "사제관"],
	"shop": ["매장", "가게", "진열", "계산대", "매점", "상회"],
	"office": ["사무", "기록", "장부", "책상", "계량", "선별", "수위", "신호", "문서"],
	"hall": ["제의", "성가", "회중", "종", "예배", "찬송", "합창", "탑"],
	"storage": [],
}
## The room a piece of furniture says (card I 가): only what map-layout lays in one
## kind of room (room_furnish.gd PALETTE, and the kitchen's run of counters); a
## shelf or a crate stack, laid in several, says nothing and the name is read.
## Their rooms as ours: bed and living → bedroom, bath → bathroom, store → pantry,
## boiler, workshop and garage → toolbox. A key the map gives comes first, then this,
## then the name.
const FURNITURE_ROOM: Dictionary = {
	"dresser": "bedroom", "wardrobe": "bedroom", "nightstand": "bedroom", "bookcase": "bedroom", "side_table": "bedroom",
	"cupboard": "kitchen", "fridge_open": "kitchen", "counter": "kitchen",
	"washstand": "bathroom", "towel_shelf": "bathroom", "medicine_cabinet": "bathroom", "waste_bin": "bathroom",
	"desk": "office", "file_cabinet": "office",
	"display_shelf": "shop", "shop_counter": "shop",
	"jar_shelf": "pantry", "tin_crate": "pantry",
	"toolbox": "toolbox", "part_crate": "toolbox", "parts_rack": "toolbox", "hardware_rack": "toolbox",
}
## How strongly each room draws each kind of thing (a weight; 0.3 is 「hardly
## ever」). The rooms with low weights everywhere are the ones often found empty.
const AFFINITY: Dictionary = {
	"kitchen": {"food": 6.0, "med": 0.3, "lux": 1.0, "wood": 0.5, "scrap": 0.3, "cloth": 0.5, "small": 1.0},
	"pantry": {"food": 6.0, "med": 0.2, "lux": 0.5, "wood": 2.0, "scrap": 1.0, "cloth": 0.3, "small": 0.5},
	"bedroom": {"food": 0.3, "med": 1.5, "lux": 3.0, "wood": 0.3, "scrap": 0.2, "cloth": 4.0, "small": 1.0},
	"bathroom": {"food": 0.1, "med": 5.0, "lux": 0.3, "wood": 0.1, "scrap": 0.1, "cloth": 1.0, "small": 3.0},
	"clinic": {"food": 0.2, "med": 6.0, "lux": 0.2, "wood": 0.2, "scrap": 0.2, "cloth": 2.0, "small": 4.0},
	"toolbox": {"food": 0.2, "med": 0.3, "lux": 0.2, "wood": 3.0, "scrap": 6.0, "cloth": 1.0, "small": 0.5},
	"shop": {"food": 5.0, "med": 1.0, "lux": 3.0, "wood": 0.5, "scrap": 0.5, "cloth": 2.0, "small": 1.0},
	"office": {"food": 0.5, "med": 0.5, "lux": 1.0, "wood": 0.5, "scrap": 0.5, "cloth": 0.5, "small": 0.5},
	"hall": {"food": 0.3, "med": 0.3, "lux": 0.3, "wood": 0.3, "scrap": 0.3, "cloth": 0.3, "small": 0.3},
	"storage": {"food": 3.0, "med": 0.5, "lux": 0.5, "wood": 4.0, "scrap": 4.0, "cloth": 1.0, "small": 0.5},
}
## Within a room, the furniture made for a thing draws it (decision 442): a medicine
## cabinet the medicine and the small things, a wardrobe, a dresser or a chest the cloth
## and the clothes, a cupboard or a larder shelf the food. A pull on the room's affinity,
## scaled so the pulls of a building's room's boxes average one: the room still draws what
## AFFINITY says, only where in it the thing lies changes. The cloth pulls harder: the cloth
## lies mostly in houses whose bedrooms have one wardrobe among side tables and shelves.
const FURNITURE_PULL: Dictionary = {
	"medicine_cabinet": {"med": 4.0, "small": 3.0},
	"wardrobe": {"cloth": 8.0}, "dresser": {"cloth": 8.0}, "blanket_chest": {"cloth": 8.0},
	"cupboard": {"food": 3.0}, "jar_shelf": {"food": 3.0}, "tin_crate": {"food": 3.0},
}
## No box takes more than this many things from the others.
const CAP: int = 6
## Nor more than it holds (carry.gd box_limit). A bundle is counted at the most
## its name can weigh (a sack of oats, a picture: 1.5), as it is named after it
## is dealt: six food bundles named sacks are 9 in a jar shelf that takes 8.
const NAMED_MOST: float = 1.5
## Promised shares (card S1, decision 442): of a stop's buildings of these kinds, this
## share holds one bundle of the family at least, so a shop holds what it sells. The
## share of their count is kept, and the part of one is rolled. Nothing is added: the
## bundle is moved from a building of the stop holding two or more (one of the same
## kinds first), so the stop's load stays what it was; with none to spare, none is
## moved. With a deck handed in (DECKS), it is kept over the stops instead.
const PROMISES: Array = [
	{"family": "food", "kinds": ["grocery", "bakery", "fish", "cold"], "deck": "food_shop"},
	{"family": "med", "kinds": ["pharmacy", "clinic"], "deck": "pharmacy"},
]

## What a building is, from the words of its name (first that matches). Only the
## naming and the finds read it.
const BUILDING_ORDER: Array[String] = ["fish", "cold", "bakery", "pharmacy", "clinic", "grocery", "farm", "garage", "workshop", "house"]
const BUILDING_WORDS: Dictionary = {
	"fish": ["낚시", "어장", "생선"],
	"cold": ["얼음", "냉장", "냉동"],
	"bakery": ["빵집", "제과"],
	"pharmacy": ["약국", "약방"],
	"clinic": ["병원", "의사", "간호", "진료", "구급"],
	"grocery": ["식료품", "잡화", "매점", "상회", "가게", "상점"],
	"farm": ["농가", "외양간", "헛간", "마구간", "우물집", "과수"],
	"garage": ["차고"],
	"workshop": ["공장", "기계", "공구", "정비", "철물", "부품", "제재", "변전", "대장"],
	"house": ["주택", "사택", "연립", "본채", "오두막", "관리인", "숙직", "기숙", "움막", "집"],
}
## Where people lived (a pack or a watch is left in a room, never on a platform).
const LIVED_IN: Array[String] = ["house", "farm", "fish", "clinic"]

## Bundle → named thing, by where it lies. [id, weight] rows; the weights are
## set so a bundle weighs 1.0 on average (± 0.05), so a pack carries as much as
## before; spoiled and wilted things are what is lost on the train.
const NAMES: Dictionary = {
	"food": {
		"default": [["can_beans", 3], ["can_meat", 2], ["can_dented", 2], ["jar_cabbage", 2], ["jar_jam", 1], ["jar_honey", 1], ["hardtack", 2], ["rusk", 2], ["sugar", 1], ["oats", 3], ["peas", 2], ["bread_moldy", 1]],
		"pantry": [["jar_cabbage", 3], ["jar_jam", 2], ["jar_honey", 1], ["oats", 2], ["peas", 2], ["flour", 1], ["can_beans", 2], ["can_dented", 1], ["apple_wilted", 1], ["hardtack", 2], ["rusk", 2]],
		"shop": [["can_beans", 4], ["can_meat", 3], ["can_dented", 2], ["sugar", 2], ["hardtack", 2], ["jar_jam", 1], ["flour", 1], ["oats", 1], ["peas", 1], ["meat_spoiled", 1]],
		# Raw meat and fish only where they were kept frozen (survival_detail 3.5).
		"cold": [["meat_frozen", 5], ["fish_frozen", 2], ["can_meat", 1]],
		"fish": [["fish_frozen", 6], ["can_beans", 1], ["hardtack", 1], ["peas", 1]],
		"bakery": [["flour", 8], ["rusk", 3], ["sugar", 2], ["bread_moldy", 3]],
		# Late autumn (decision 423-1): the orchards still bear.
		"farm": [["apple", 3], ["apple_wilted", 3], ["jar_cabbage", 2], ["jar_honey", 2], ["meat_spoiled", 1]],
	},
	"med": {
		"default": [["painkillers", 3], ["fever_pills", 2], ["ointment", 1], ["cough_syrup", 2], ["antiseptic", 3], ["herbs", 3]],
		"clinic": [["antiseptic", 3], ["painkillers", 3], ["saline", 3], ["cough_syrup", 2], ["fever_pills", 2], ["ointment", 1]],
		"herbal": [["herbs", 4], ["painkillers", 1], ["ointment", 4], ["cough_syrup", 1]],
	},
	"lux": {
		"default": [["cigarettes", 2], ["coffee", 2], ["record", 3], ["painting", 3], ["pocket_watch", 1]],
		"shop": [["cigarettes", 2], ["coffee", 5], ["record", 2], ["painting", 2]],
		"bedroom": [["pocket_watch", 2], ["record", 2], ["painting", 4], ["cigarettes", 2], ["coffee", 1]],
		# Pockets hold small things; not held to the 1.0 (a few a stop at most).
		"pocket": [["cigarettes", 3], ["pocket_watch", 2], ["coffee", 1]],
	},
}
## The naming tables not held to the 1.0 average (see above).
const LIGHT_TABLES: Array[String] = ["lux:pocket"]
## Boxes of one room split what they hold (ref-ops L1: the reference's kitchen counters each
## take one list — tins, dry food, baking, bottles — at most so many a room): where a room
## (one building, one room kind) has two boxes or more with the same family's bundles, each box
## takes one theme for all of them, the room's boxes spread over the themes as evenly as their
## shares of the table allow (room_themes). Every row of the food and medicine tables is in one
## theme; luxuries are left as they are.
const THEMES: Dictionary = {
	"food": {
		"tins": ["can_beans", "can_meat", "can_dented"],
		"jars": ["jar_cabbage", "jar_jam", "jar_honey"],
		"dry": ["oats", "peas", "flour", "sugar"],
		"biscuits": ["hardtack", "rusk"],
		"fresh": ["bread_moldy", "apple_wilted", "apple", "meat_spoiled", "meat_frozen", "fish_frozen"],
	},
	"med": {
		"pills": ["painkillers", "fever_pills"],
		"dressings": ["antiseptic", "ointment", "saline"],
		"syrups": ["cough_syrup", "herbs"],
	},
}

## Finds of their own, a stop at a time (new values, PR 「새로 넣은 값」).
const BIG_PACK_CHANCE: float = 0.35     # one bigger pack in a lived-in bedroom or store room
const WATCH_CHANCE: float = 0.30        # one wrist watch left in a lived-in bedroom
const WATCH_SET_SHARE: float = 0.5      # how many of the watches are still set to ring
const OPENER_CHANCE: float = 0.60       # one can opener in a kitchen or larder
const NAILS_CHANCE: float = 0.08        # each toolbox: a handful of nails
const NAILS_MOST: int = 4
## Parts stuff (decision 426 D2): each toolbox, or any box in a garage or a
## workshop, may hold one; so many a stop at most; which one by weight.
const PARTS_CHANCE: float = 0.12
const PARTS_MOST: int = 5
const PARTS_KINDS: Array = [["gears", 2], ["springs", 2], ["wire_coil", 1]]
## Clothes left behind (decision 423 card 2, more of them decision 434): each
## may lie, once a stop, in one of these rooms ([] for any) of these buildings:
## the warm and the plain where people lived, the work clothes where people
## worked. The first five as they were; the rest new (common 0.1, 0.06, rare 0.03).
## What everyone goes out in is not left lying, and the fire suit and the vest
## come off the dead (PR C).
const WORK_PLACES: Array[String] = ["farm", "garage", "workshop"]
const WEAR_FINDS: Array = [
	["coat_long", 0.30, ["bedroom", "storage", "hall"], LIVED_IN],
	["jacket_short", 0.20, ["bedroom", "storage", "hall"], LIVED_IN],
	["hat_knit", 0.40, ["bedroom", "hall"], LIVED_IN],
	["hood", 0.30, ["bedroom", "storage"], LIVED_IN],
	["gloves", 0.35, [], ["house", "farm", "fish", "clinic", "garage", "workshop"]],
	["sweater_wool", 0.10, ["bedroom", "storage"], LIVED_IN],
	["socks_wool", 0.10, ["bedroom"], LIVED_IN],
	["scarf_wool", 0.10, ["bedroom", "hall"], LIVED_IN],
	["shirt_flannel", 0.10, ["bedroom", "storage"], LIVED_IN],
	["hat_earflap", 0.10, ["bedroom", "hall"], LIVED_IN],
	["mittens", 0.10, ["bedroom", "hall"], LIVED_IN],
	["raincoat", 0.10, ["hall", "storage"], ["house", "farm", "fish"]],
	["jacket_work", 0.10, ["hall", "storage"], ["farm", "fish", "garage", "workshop"]],
	["trousers_work", 0.10, ["storage"], WORK_PLACES],
	["boots_work", 0.10, ["hall", "storage"], WORK_PLACES],
	["gloves_cotton", 0.10, [], ["clinic", "garage", "workshop"]],
	["undershirt_wool", 0.06, ["bedroom"], LIVED_IN],
	["long_johns", 0.06, ["bedroom"], LIVED_IN],
	["shirt_wool", 0.06, ["bedroom"], LIVED_IN],
	["sweater_thick", 0.06, ["bedroom", "storage"], LIVED_IN],
	["vest_knit", 0.06, ["bedroom"], LIVED_IN],
	["jacket_plain", 0.06, ["bedroom", "hall"], LIVED_IN],
	["coat_padded", 0.06, ["bedroom", "hall"], LIVED_IN],
	["trousers_wool", 0.06, ["bedroom"], LIVED_IN],
	["hood_wool", 0.06, ["bedroom"], LIVED_IN],
	["cap_brim", 0.06, ["hall"], ["house", "farm", "garage"]],
	["vest_quilted", 0.06, ["hall", "storage"], ["house", "farm", "fish"]],
	["shirt_work", 0.06, ["storage", "hall"], WORK_PLACES],
	["overtrousers_oil", 0.06, ["storage"], ["farm", "fish"]],
	["boots_rubber", 0.06, ["hall", "storage"], ["farm", "fish"]],
	["bib_work", 0.06, ["storage"], WORK_PLACES],
	["coverall", 0.06, ["storage"], ["garage", "workshop"]],
	["gloves_leather", 0.06, ["storage", "toolbox"], ["garage", "workshop"]],
	["mask_cloth", 0.06, [], ["clinic", "workshop"]],
	["coat_leather", 0.03, ["hall", "storage"], ["house", "garage"]],
	["coat_wool_long", 0.03, ["hall"], LIVED_IN],
	["boots_fur", 0.03, ["hall"], LIVED_IN],
	["scarf_thick", 0.03, ["bedroom"], LIVED_IN],
	["dress_wool", 0.03, ["bedroom"], ["house"]],
]
const FUEL_CHANCE: float = 0.30         # one fuel can in a garage
const RARE_CHANCE: float = 0.25         # one named find
# 나단계 (decision 423, P23, card 11)
const PAN_CHANCE: float = 0.50          # one frying pan in a kitchen
const BOTTLE_CHANCE: float = 0.40       # one broken bottle in a washroom, a bedroom or a store
## Decks over the stops (card S1, decision 442; the contract's lootDeck, kept on the
## train by s3-link): [n, share] — of every n looks, n × share (rounded) come up. A look is a
## building of a promise's kinds (food_shop, pharmacy: it comes up when it holds the
## family after it is seen, as it was or moved in), a stop with a garage
## (garage_fuel), a stop with a stopped machine in it (core_scene: a core left in it,
## core_scenes.gd P_CORE, decisions 474 S3·442 — of seven, since a run has seven or so),
## or a stop (pan, bottle). The state
## handed in and out is {id: {n, k, seen, hit}}; one of another n or k starts a new batch.
const DECKS: Dictionary = {
	"food_shop": [10, 0.7], "pharmacy": [10, 0.7],
	"garage_fuel": [10, FUEL_CHANCE], "pan": [10, PAN_CHANCE], "bottle": [10, BOTTLE_CHANCE],
	"core_scene": [7, 0.15],
}
## Things lying under the snow out of doors, shown only to one close by
## (field_game.glint_reach): how many a stop, and what they are.
const GLINTS: int = 6
const GLINT_KINDS: Array = [["wood", 3], ["scrap", 2], ["hare_frozen", 1]]
## How the key of a building with a locked door is found (P12): on one of the
## dead inside it, dropped in the snow by its door, or in a drawer inside.
const KEY_WAYS: Array = [["dead", 6], ["snow", 2], ["box", 2]]
## One of the dead may carry a note of a box hidden at the next stop (card 10).
const NOTE_CHANCE: float = 0.35
const NOTE_SPOTS: Array[String] = ["신호소 마루 밑", "급수탑 발치", "화물 창고 뒤 돌무더기", "역사 지하 계단 밑", "선로 반대편 헛간"]
## A blueprint piece a stop (S1 domestic data.ts BYPRODUCT, 5.2): the chance at
## each kind of place and the fields of research it may be for ("any": all
## five). A kind of place not listed has none. It lies with the papers (an
## office's desk or cabinet) if the stop has any, else in any box indoors.
const FRAGMENT_PLACES: Dictionary = {
	"freight": [0.3, ["engine", "expedition"]],
	"houses": [0.15, ["med", "expedition"]],
	"hospital": [0.4, ["med"]],
	"factory": [0.4, ["craft", "engine"]],
	"church": [0.05, "any"],
	"office": [0.4, ["radio"]],
}
const FRAGMENT_FIELDS: Array[String] = ["engine", "med", "craft", "radio", "expedition"]

## The rare store at the end of a side path (decision 450, card F 가 by
## decision 442; the path, the building and its locked door are map-layout's):
## the building named RARE_STORE. Its boxes are filled anew from the full store
## of the stop's kind, RARE_STORE_ROLLS a box, and one rare thing goes in one.
const RARE_STORE: String = "희귀 창고"
const RARE_STORE_KIND: Dictionary = {
	"freight": "rail", "factory": "rail", "mine": "rail", "sawmill": "rail", "bare_line": "rail",
	"houses": "arms", "office": "arms", "hospital": "arms", "church": "arms",
	"lodge": "winter", "lake": "winter", "summit": "winter",
}
const RARE_STORE_ROLLS: int = 3
## [weight, item, count] rows; the bundles weigh twice the common store's
## (loot_tables.gd CONTAINER_KINDS storage) and there is no empty row.
const RARE_STORE_TABLES: Dictionary = {
	"rail": [[4, "plank", 2], [4, "scrap", 2], [2, "nails", 1], [2, "gears", 1], [2, "springs", 1], [1, "wire_coil", 1], [2, "food_pack", 1], [1, "cloth", 1]],
	"arms": [[2, "ammo_pistol", 1], [1, "ammo_shell", 1], [3, "bandage", 2], [2, "med_box", 1], [4, "food_pack", 1], [1, "flare", 1], [2, "cloth", 1]],
	"winter": [[6, "food_pack", 1], [3, "cloth", 2], [3, "plank", 2], [2, "bottle_spirit", 1], [2, "med_box", 1], [2, "luxury_pack", 1]],
}
## The rare thing. Rail: a core half the time, else a crate of parts stuff
## (RARE_PARTS of them). Arms: a gun by weight and so many of its rounds.
## Winter: a fur garment and a fuel can. A core here may at most double what a
## stop gives now (0.15 seen): the side path is one stop in four, so 0.125.
const RARE_CORE_CHANCE: float = 0.5
const RARE_CORE: String = "core_engine"
const RARE_PARTS: Vector2i = Vector2i(4, 6)
const RARE_GUNS: Array = [["pistol", 3], ["shotgun", 2]]
const RARE_GUN_ROUNDS: Dictionary = {"pistol": ["ammo_pistol", 2], "shotgun": ["ammo_shell", 2]}
const RARE_FURS: Array = [["coat_wool_long", 1], ["boots_fur", 1]]


static func _has_word(name: String, words: Array) -> bool:
	var tokens: PackedStringArray = name.split(" ", false)
	for w: String in words:
		for t in tokens:
			if t == w or (w.length() >= 2 and t.begins_with(w)):
				return true
	return false


## The room a box stands in: its "room" key (name_keys), else what its name
## says ("storage" when it says nothing).
static func room_of(c: Dictionary) -> String:
	if c.has("room") and AFFINITY.has(String(c["room"])):
		return String(c["room"])
	return room_of_box(c)


## A box's room without a key: what the furniture it stands in says, else its name.
static func room_of_box(c: Dictionary) -> String:
	var by_furniture: String = String(FURNITURE_ROOM.get(String(c.get("furniture", "")), ""))
	return by_furniture if by_furniture != "" else room_of_name(String(c.get("name", "")))


static func room_of_name(n: String) -> String:
	for kind in ROOM_ORDER:
		if _has_word(n, ROOM_WORDS[kind]):
			return kind
	return "storage"


## The keys the loot reads instead of names (J06): each box's "room" and each
## building's "loot_kind", read once unless the map gives them — a box's room from
## the furniture it stands in when that says one (FURNITURE_ROOM, card I), else
## from the words of its name — and written on the map's rows, so what is
## dressed no longer follows a name once the keys are there (LootRules.place_keys
## does the same for where the fallen stood).
static func name_keys(data: Dictionary) -> void:
	var containers: Dictionary = data.get("containers", {})
	for id in containers:
		var c: Dictionary = containers[id]
		if not (c.has("room") and AFFINITY.has(String(c["room"]))):
			c["room"] = room_of_box(c)
	for b in data.get("buildings", []):
		if b is Dictionary and not (b as Dictionary).has("loot_kind"):
			b["loot_kind"] = building_kind(String(b.get("name", "")))


## What a building is by its name ("" for none of these).
static func building_kind(name: String) -> String:
	for kind in BUILDING_ORDER:
		for w: String in BUILDING_WORDS[kind]:
			if name.contains(w):
				return kind
	return ""


static func _rng(seed: int, what: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = ("%d:dress:%s" % [seed, what]).hash()
	return r


static func _pick(rows: Array, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for r: Array in rows:
		total += float(r[1])
	var at := rng.randf() * total
	for r: Array in rows:
		at -= float(r[1])
		if at < 0.0:
			return String(r[0])
	return String(rows[rows.size() - 1][0])


## Average weight of a naming table's things.
static func mean_weight(family: String, table: String) -> float:
	var rows: Array = NAMES[family][table]
	var n := 0.0
	var w := 0.0
	for r: Array in rows:
		n += float(r[1])
		w += float(r[1]) * FieldItems.weight(String(r[0]))
	return w / n


## Which naming table a bundle uses where it lies.
static func name_table(family: String, room: String, building: String, place_kind: String) -> String:
	match family:
		"food":
			if ["cold", "fish", "bakery", "farm"].has(building):
				return building
			if room == "pantry" or room == "shop":
				return room
			if building == "grocery":
				return "shop"
		"med":
			if building == "pharmacy" or building == "clinic" or room == "clinic" or place_kind == "hospital":
				return "clinic"
			if building == "farm" or place_kind == "church" or place_kind == "lodge":
				return "herbal"
		"lux":
			if room == "shop" or building == "grocery":
				return "shop"
			if room == "bedroom":
				return "bedroom"
	return "default"


## One bundle id named, or the id itself when it is no bundle. A dented tin may
## have gone off (rolled here, hidden until it is opened). `theme` (THEMES) keeps
## to that theme's rows of the table; the dice are drawn as often either way.
static func name_bundle(id: String, table: String, rng: RandomNumberGenerator, theme: String = "") -> String:
	var family: String = String(FAMILY.get(id, ""))
	if not FieldItems.BUNDLES.has(id) or not NAMES.has(family):
		return id
	var rows: Array = theme_rows(family, NAMES[family].get(table, NAMES[family]["default"]), theme)
	var named := _pick(rows, rng)
	if named == "can_dented" and rng.randf() < FieldItems.DENTED_BAD:
		return "can_dented_bad"
	return named


## A table's rows of one theme (all of them for "" or a theme with none there).
static func theme_rows(family: String, rows: Array, theme: String) -> Array:
	if theme == "" or not THEMES.has(family) or not (THEMES[family] as Dictionary).has(theme):
		return rows
	var ids: Array = THEMES[family][theme]
	var out: Array = rows.filter(func(r: Array) -> bool: return ids.has(String(r[0])))
	return out if not out.is_empty() else rows


## Which theme each box of a shared room takes, as {"<box>|<family>": theme}: rooms
## (building, room kind, family, naming table) with two boxes or more holding that family's
## bundles, box ids in order, the themes dealt evenly by their shares of the table.
static func room_themes(containers: Dictionary, buildings: Array, place_kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var rooms: Dictionary = {}
	var ids: Array = containers.keys()
	ids.sort()
	for id: String in ids:
		var c: Dictionary = containers[id]
		var b: int = int(c.get("building", -1))
		if c.has("pick") or b < 0:
			continue
		var room := room_of(c)
		var bk := _building_kind_of(buildings, c)
		var seen: Dictionary = {}
		for item in c.get("items", []):
			var family: String = String(FAMILY.get(String(item), ""))
			if not THEMES.has(family) or not FieldItems.BUNDLES.has(String(item)) or seen.has(family):
				continue
			seen[family] = true
			var key := "%d|%s|%s|%s" % [b, room, family, name_table(family, room, bk, place_kind)]
			if not rooms.has(key):
				rooms[key] = []
			(rooms[key] as Array).append(id)
	var out: Dictionary = {}
	var keys: Array = rooms.keys()
	keys.sort()
	for key: String in keys:
		var boxes: Array = rooms[key]
		if boxes.size() < 2:
			continue
		var family: String = key.get_slice("|", 2)
		var table: String = key.get_slice("|", 3)
		var shares: Dictionary = {}
		for r: Array in NAMES[family].get(table, NAMES[family]["default"]):
			for theme: String in THEMES[family]:
				if (THEMES[family][theme] as Array).has(String(r[0])):
					shares[theme] = float(shares.get(theme, 0.0)) + float(r[1])
		# Evenly by share: the themes laid end to end in a shuffled order, the boxes' marks one
		# box apart from a random start. A theme comes up about as often as its share of the
		# table says (so the room holds what it held before, in all) and twice only when its
		# share is more than one box's.
		var order: Array = shares.keys()
		for i in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t: Variant = order[i]
			order[i] = order[j]
			order[j] = t
		var total := 0.0
		for theme: String in order:
			total += float(shares[theme])
		var start := rng.randf()
		for k in boxes.size():
			var at := (start + k) / boxes.size() * total
			var drawn: String = String(order[order.size() - 1])
			for theme: String in order:
				at -= float(shares[theme])
				if at < 0.0:
					drawn = theme
					break
			out["%s|%s" % [boxes[k], family]] = drawn
	return out


## A pocket's bundle named without drawing from the pockets' dice (the dead roll
## the same things from the same seed as before): from a number the caller
## already has (the pockets' dice state).
static func name_pocket(id: String, salt: int) -> String:
	if not FieldItems.BUNDLES.has(id):
		return id
	var r := RandomNumberGenerator.new()
	r.seed = ("pocket:%d:%s" % [salt, id]).hash()
	return name_bundle(id, "pocket" if FAMILY.get(id, "") == "lux" else "default", r)


## Dress the stop in place. data: the map's dictionary (containers, buildings,
## place_kind). Returns what was done, for the tests and the measuring tool:
## {"moved", "named", "finds": [[id, box]], "rare": id or "", "fragment": id or "",
## "store": kind or "", "promised", "loot_deck"}. deck: where the decks stood after
## the last stop (DECKS); empty, the promised shares are kept within this stop and
## the rest roll as before. Where they stand after this one is "loot_deck".
static func dress(data: Dictionary, seed: int, deck: Dictionary = {}) -> Dictionary:
	var containers: Dictionary = data.get("containers", {})
	var buildings: Array = data.get("buildings", [])
	var place_kind: String = String(data.get("place_kind", ""))
	var report := {"moved": 0, "named": 0, "finds": [], "rare": "", "fragment": "", "store": ""}
	var decks := deck.duplicate(true)
	name_keys(data)
	# 1. Within each building, the bundles go where the room says.
	# The odds and ends go in first, as the reference rolls them, and stay where
	# they are put (loot_junk.gd).
	var rooms: Dictionary = {}
	for id: String in containers:
		rooms[id] = room_of(containers[id])
	report["junk"] = LootJunk.strew(containers, seed, rooms)
	var by_building: Dictionary = {}
	for id: String in containers:
		var c: Dictionary = containers[id]
		if not _movable_box(id, c):
			continue
		var b: int = int(c.get("building", -1))
		if b < 0:
			continue
		if not by_building.has(b):
			by_building[b] = []
		(by_building[b] as Array).append(id)
	report["promised"] = _keep_promises(containers, buildings, by_building, seed, decks, not deck.is_empty())
	for b: int in by_building:
		report["moved"] += _deal(containers, by_building[b], _rng(seed, "deal:%d" % b))
	# 1b. The rare store, if the stop has one, is filled anew (its own dice).
	_rare_store(containers, buildings, place_kind, seed, report)
	# 2. Every bundle gets its name; boxes of one room split the themes (THEMES).
	var themes := room_themes(containers, buildings, place_kind, _rng(seed, "themes"))
	var name_rng := _rng(seed, "names")
	for id: String in containers:
		var c: Dictionary = containers[id]
		if c.has("pick"):
			continue
		var room := room_of(c)
		var bk := _building_kind_of(buildings, c)
		# A fresh list: a map may hand out the same list (or a read-only one) twice.
		var items: Array = (c.get("items", []) as Array).duplicate()
		c["items"] = items
		for i in range(items.size()):
			var item: String = String(items[i])
			if not FieldItems.BUNDLES.has(item):
				continue
			var table := name_table(String(FAMILY[item]), room, bk, place_kind)
			items[i] = name_bundle(item, table, name_rng, String(themes.get("%s|%s" % [id, FAMILY[item]], "")))
			report["named"] += 1
	# 3. Finds of their own.
	_finds(containers, buildings, seed, report, decks)
	_rare(containers, place_kind, seed, report)
	_fragment(containers, place_kind, seed, report)
	for id: String in DECKS:
		_deck_row(decks, id)
	report["loot_deck"] = decks
	return report


static func _movable_box(id: String, c: Dictionary) -> bool:
	return not c.has("pick") and not LootTables.FIXED.has(id) and not bool(c.get("locked", false))


static func _building_kind_of(buildings: Array, c: Dictionary) -> String:
	var b: int = int(c.get("building", -1))
	if b < 0 or b >= buildings.size():
		return ""
	var bd: Dictionary = buildings[b]
	return String(bd["loot_kind"]) if bd.has("loot_kind") else building_kind(String(bd.get("name", "")))


## Take the movable things out of these boxes and deal them again by room.
## Returns how many ended in another box than they started in.
static func _deal(containers: Dictionary, ids: Array, rng: RandomNumberGenerator) -> int:
	var pool: Array = []   # [item, from box]
	for id: String in ids:
		var keep: Array = []
		for item in containers[id].get("items", []):
			if FAMILY.has(String(item)):
				pool.append([String(item), id])
			else:
				keep.append(item)
		containers[id]["items"] = keep
	var moved := 0
	var shares: Dictionary = {}   # family -> {box: its share of its room's draw}
	for row: Array in pool:
		var family: String = FAMILY[row[0]]
		if not shares.has(family):
			shares[family] = _room_shares(containers, ids, family)
		var total := 0.0
		var weights: Array = []
		for id: String in ids:
			var w := 0.0
			var c: Dictionary = containers[id]
			if (c["items"] as Array).size() < CAP and _dealt_load(c) + _dealt_weight(row[0]) <= Carry.box_limit(c):
				w = float(AFFINITY[room_of(c)][family]) * float(shares[family][id])
			weights.append(w)
			total += w
		var to: String = row[1]
		if total > 0.0:
			var at := rng.randf() * total
			for i in range(ids.size()):
				at -= float(weights[i])
				if at < 0.0:
					to = ids[i]
					break
		(containers[to]["items"] as Array).append(row[0])
		if to != row[1]:
			moved += 1
	return moved


## The promised shares (PROMISES), before the boxes are dealt. Returns, for each
## family, [buildings of the kinds, how many must hold it, how many did, bundles moved]
## (with a deck carried over, how many must is how many came up). The deck rows are
## counted either way, so the next stop can carry on.
static func _keep_promises(containers: Dictionary, buildings: Array, by_building: Dictionary, seed: int,
		decks: Dictionary, carried: bool) -> Dictionary:
	var out := {}
	var all: Array = by_building.keys()
	all.sort()
	for p: Dictionary in PROMISES:
		var family := String(p["family"])
		var rng := _rng(seed, "promise:" + family)
		var mine: Array = []
		for b: int in all:
			if (p["kinds"] as Array).has(_building_kind_of(buildings, containers[by_building[b][0]])):
				mine.append(b)
		var others: Array = all.filter(func(b: int) -> bool: return not mine.has(b))
		var row := _deck_row(decks, String(p["deck"]))
		if carried:
			out[family] = _keep_deck(containers, by_building, mine, others, family, row, rng)
			continue
		var exact := float(DECKS[p["deck"]][1]) * mine.size()
		var wanted := floori(exact) + (1 if rng.randf() < exact - floorf(exact) else 0)
		var bare: Array = []
		for b: int in mine:
			if _held(containers, by_building[b], family) == 0:
				bare.append(b)
		var held := mine.size() - bare.size()
		# Which bare ones get it: shuffled, so it is not always the first on the map.
		for i in range(bare.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t: int = bare[i]
			bare[i] = bare[j]
			bare[j] = t
		var moved := 0
		for b: int in bare:
			if held + moved >= wanted:
				break
			if not _move_in(containers, by_building, mine, others, family, b):
				break
			moved += 1
		for b: int in mine:
			_count(row, _held(containers, by_building[b], family) > 0)
		out[family] = [mine.size(), wanted, held, moved]
	return out


## A promise kept over the stops: each building of the kinds, in order, is one look;
## one that holds the family comes up, a bare one gets a bundle moved in with the
## chance the deck has left (and comes up if one could be spared).
static func _keep_deck(containers: Dictionary, by_building: Dictionary, mine: Array, others: Array,
		family: String, row: Dictionary, rng: RandomNumberGenerator) -> Array:
	var held := 0
	var up := 0
	var moved := 0
	for b: int in mine:
		var holds := _held(containers, by_building[b], family) > 0
		if holds:
			held += 1
		elif rng.randf() < _chance(row) and _move_in(containers, by_building, mine, others, family, b):
			holds = true
			moved += 1
		if holds:
			up += 1
		_count(row, holds)
	return [mine.size(), up, held, moved]


## Move one bundle of the family into building b from one that can spare it (one of
## the same kinds first). False when none can.
static func _move_in(containers: Dictionary, by_building: Dictionary, mine: Array, others: Array, family: String, b: int) -> bool:
	var from := _spare(containers, by_building, mine, family)
	if from.is_empty():
		from = _spare(containers, by_building, others, family)
	if from.is_empty():
		return false
	# Fresh lists: a map may hand out the same list (or a read-only one) twice.
	var left: Array = (containers[from[0]]["items"] as Array).duplicate()
	left.remove_at(int(from[1]))
	containers[from[0]]["items"] = left
	var to: String = by_building[b][0]
	containers[to]["items"] = (containers[to]["items"] as Array) + [String(from[2])]
	return true


## The row of one deck in the state, made fresh when it is missing, of another n or k,
## or used up.
static func _deck_row(decks: Dictionary, id: String) -> Dictionary:
	var n: int = DECKS[id][0]
	var k: int = roundi(float(DECKS[id][1]) * n)
	var row: Dictionary = decks.get(id, {})
	if int(row.get("n", 0)) != n or int(row.get("k", -1)) != k or int(row.get("seen", 0)) >= n:
		row = {"n": n, "k": k, "seen": 0, "hit": 0}
	else:
		row = {"n": n, "k": k, "seen": int(row["seen"]), "hit": int(row.get("hit", 0))}
	decks[id] = row
	return row


## The chance the next look comes up: what is left of k over what is left of n.
static func _chance(row: Dictionary) -> float:
	return float(maxi(0, int(row["k"]) - int(row["hit"]))) / float(int(row["n"]) - int(row["seen"]))


## Count one look; at n looks the batch starts again.
static func _count(row: Dictionary, up: bool) -> void:
	row["seen"] = int(row["seen"]) + 1
	if up:
		row["hit"] = int(row["hit"]) + 1
	if int(row["seen"]) >= int(row["n"]):
		row["seen"] = 0
		row["hit"] = 0


## A deck looked at from outside (core_scenes.gd): the chance the next look comes up —
## at the start of a batch first_chance when one is given, so a stop with no deck
## rolls as it did before (the batch still comes up exactly k times) — and the look counted.
static func deck_chance(decks: Dictionary, id: String, first_chance: float = -1.0) -> float:
	var row := _deck_row(decks, id)
	return first_chance if first_chance >= 0.0 and int(row["seen"]) == 0 else _chance(row)


static func deck_count(decks: Dictionary, id: String, up: bool) -> void:
	_count(_deck_row(decks, id), up)


## One look at a deck with a roll already made (so the dice fall as they did before
## the decks): true when it comes up.
static func _look(decks: Dictionary, id: String, roll: float) -> bool:
	var row := _deck_row(decks, id)
	var up := roll < _chance(row)
	_count(row, up)
	return up


## How many things of the family these boxes hold (a bundle or a thing named from one).
static func _held(containers: Dictionary, ids: Array, family: String) -> int:
	var n := 0
	for id: String in ids:
		for item in containers[id].get("items", []):
			var s := String(item)
			var from := String(FieldItems.row(s).get("from", s)) if FieldItems.has(s) else s
			if String(FAMILY.get(from, "")) == family:
				n += 1
	return n


## A bundle of the family that one of these buildings can spare (it holds two or
## more; the one holding most first): [box, index, bundle], or [] when none can.
static func _spare(containers: Dictionary, by_building: Dictionary, among: Array, family: String) -> Array:
	var best: Array = []
	var most := 1
	for b: int in among:
		var n := _held(containers, by_building[b], family)
		if n <= most:
			continue
		for id: String in by_building[b]:
			var items: Array = containers[id].get("items", [])
			for i in range(items.size()):
				if String(FAMILY.get(String(items[i]), "")) == family:
					best = [id, i, String(items[i])]
					most = n
					break
			if not best.is_empty() and most == n:
				break
	return best


## Each box's share of its room's draw for a family: its furniture's pull (FURNITURE_PULL),
## over the average of that room in its building. A room with no such furniture gives every
## box 1, and each building's room draws as much as before.
static func _room_shares(containers: Dictionary, ids: Array, family: String) -> Dictionary:
	var count: Dictionary = {}
	var sum: Dictionary = {}
	for id: String in ids:
		var key := _room_key(containers[id])
		count[key] = int(count.get(key, 0)) + 1
		sum[key] = float(sum.get(key, 0.0)) + _pull(containers[id], family)
	var out: Dictionary = {}
	for id: String in ids:
		var key := _room_key(containers[id])
		out[id] = _pull(containers[id], family) * float(count[key]) / float(sum[key])
	return out


static func _room_key(c: Dictionary) -> String:
	return "%d|%s" % [int(c.get("building", -1)), room_of(c)]


static func _pull(c: Dictionary, family: String) -> float:
	return float((FURNITURE_PULL.get(String(c.get("furniture", "")), {}) as Dictionary).get(family, 1.0))


## What a thing weighs while the boxes are dealt: a bundle at the most its name can.
static func _dealt_weight(item: String) -> float:
	return NAMED_MOST if FieldItems.BUNDLES.has(item) else Carry.item_weight(item)


static func _dealt_load(c: Dictionary) -> float:
	var t := 0.0
	for item in c.get("items", []):
		t += _dealt_weight(String(item))
	return t


static func _boxes(containers: Dictionary, buildings: Array, rooms: Array, kinds: Array) -> Array:
	var out: Array = []
	for id: String in containers:
		var c: Dictionary = containers[id]
		if not _movable_box(id, c):
			continue
		if not rooms.is_empty() and not rooms.has(room_of(c)):
			continue
		if not kinds.is_empty() and not kinds.has(_building_kind_of(buildings, c)):
			continue
		out.append(id)
	return out


## _put, with the furniture made for the thing drawing it within its room (FURNITURE_PULL).
## Where no box's furniture pulls the family, the same dice as _put.
static func _put_fit(containers: Dictionary, ids: Array, item: String, family: String, rng: RandomNumberGenerator, report: Dictionary) -> void:
	var shares := _room_shares(containers, ids, family)
	if ids.is_empty() or shares.values().all(func(v: float) -> bool: return v == 1.0):
		_put(containers, ids, item, rng, report)
		return
	var total := 0.0
	for id: String in ids:
		total += float(shares[id])
	var at := rng.randf() * total
	var to: String = ids[ids.size() - 1]
	for id: String in ids:
		at -= float(shares[id])
		if at < 0.0:
			to = id
			break
	(containers[to]["items"] as Array).append(item)
	(report["finds"] as Array).append([item, to])


static func _put(containers: Dictionary, ids: Array, item: String, rng: RandomNumberGenerator, report: Dictionary) -> void:
	if ids.is_empty():
		return
	var id: String = ids[rng.randi_range(0, ids.size() - 1)]
	(containers[id]["items"] as Array).append(item)
	(report["finds"] as Array).append([item, id])


static func _finds(containers: Dictionary, buildings: Array, seed: int, report: Dictionary, decks: Dictionary) -> void:
	var rng := _rng(seed, "finds")
	if rng.randf() < BIG_PACK_CHANCE:
		_put(containers, _boxes(containers, buildings, ["bedroom", "storage"], LIVED_IN), "found_big_pack", rng, report)
	if rng.randf() < WATCH_CHANCE:
		var watch := "wrist_watch_set" if rng.randf() < WATCH_SET_SHARE else "wrist_watch"
		_put(containers, _boxes(containers, buildings, ["bedroom"], LIVED_IN), watch, rng, report)
	if rng.randf() < OPENER_CHANCE:
		_put(containers, _boxes(containers, buildings, ["kitchen", "pantry"], []), "can_opener", rng, report)
	var nails := 0
	for id: String in _boxes(containers, buildings, ["toolbox"], []):
		if nails >= NAILS_MOST:
			break
		if rng.randf() < NAILS_CHANCE:
			(containers[id]["items"] as Array).append("nails")
			(report["finds"] as Array).append(["nails", id])
			nails += 1
	# A stop with no garage rolls too but turns no card: the dice fall as before.
	var garages := _boxes(containers, buildings, [], ["garage"])
	var fuel_roll := rng.randf()
	if not garages.is_empty() and _look(decks, "garage_fuel", fuel_roll):
		_put(containers, garages, "fuel_can", rng, report)
	# Its own dice, so the finds above come out as they did.
	var parts_rng := _rng(seed, "parts")
	var where: Array = _boxes(containers, buildings, ["toolbox"], [])
	for id: String in _boxes(containers, buildings, [], ["garage", "workshop"]):
		if not where.has(id):
			where.append(id)
	where.sort()
	var parts := 0
	for id: String in where:
		if parts >= PARTS_MOST:
			break
		if parts_rng.randf() < PARTS_CHANCE:
			var what := _pick(PARTS_KINDS, parts_rng)
			(containers[id]["items"] as Array).append(what)
			(report["finds"] as Array).append([what, id])
			parts += 1
	# Clothes, on dice of their own too.
	var wear_rng := _rng(seed, "wear")
	for row: Array in WEAR_FINDS:
		if wear_rng.randf() < float(row[1]):
			_put_fit(containers, _boxes(containers, buildings, row[2], row[3]), String(row[0]), "cloth", wear_rng, report)
	# Something to grab when there is nothing better (P23).
	var hands_rng := _rng(seed, "grab")
	if _look(decks, "pan", hands_rng.randf()):
		_put(containers, _boxes(containers, buildings, ["kitchen"], []), "frying_pan", hands_rng, report)
	if _look(decks, "bottle", hands_rng.randf()):
		_put(containers, _boxes(containers, buildings, ["bathroom", "bedroom", "storage"], LIVED_IN), "broken_bottle", hands_rng, report)


## Where things lie under the snow (card 11): out of doors, where one can
## walk, off the train. [{"cell", "id"}]; a key dropped by a door is added by
## the field when it gives out the keys.
static func glints(data: Dictionary, seed: int) -> Array:
	var out: Array = []
	var grid = data.get("grid")
	if grid == null:
		return out
	var train: Rect2i = data.get("train", Rect2i())
	var rng := _rng(seed, "glints")
	var tries := 0
	while out.size() < GLINTS and tries < GLINTS * 40:
		tries += 1
		var c := Vector2i(rng.randi_range(1, grid.width - 2), rng.randi_range(1, grid.height - 2))
		if not grid.people_can_walk(c) or grid.indoor(c) or train.grow(2).has_point(c):
			continue
		out.append({"cell": c, "id": _pick(GLINT_KINDS, rng)})
	return out


## What a hidden box holds (card 10): three bundles, named where they lie.
const STASH: Array[String] = ["food_pack", "food_pack", "med_box"]


## The box a note told of: the first box whose name shares a word with the
## spot ("신호소 마루 밑" → a 신호소 box), else one in a building; its things
## are added, named. Returns the box id ("" when there is none).
static func place_stash(data: Dictionary, spot: String, seed: int) -> String:
	var containers: Dictionary = data.get("containers", {})
	var words: PackedStringArray = spot.split(" ", false)
	var at := ""
	var any := ""
	for id: String in containers:
		var c: Dictionary = containers[id]
		if c.has("pick") or LootTables.FIXED.has(id):
			continue
		if any == "" and int(c.get("building", -1)) >= 0:
			any = id
		for w in words:
			if w.length() >= 2 and String(c.get("name", "")).contains(w):
				at = id
				break
		if at != "":
			break
	if at == "":
		at = any
	if at == "":
		return ""
	var rng := _rng(seed, "stash")
	var c: Dictionary = containers[at]
	var room := room_of(c)
	var items: Array = (c.get("items", []) as Array).duplicate()
	for b: String in STASH:
		items.append(name_bundle(b, name_table(String(FAMILY[b]), room, "", String(data.get("place_kind", ""))), rng))
	c["items"] = items
	return at


## How each building with a locked door gives its key: {building: "dead" |
## "snow" | "box"}, in building order.
static func key_ways(doors: Dictionary, seed: int) -> Dictionary:
	var out: Dictionary = {}
	var rng := _rng(seed, "keys")
	var shut: Array = []
	for c: Vector2i in doors:
		var d: Dictionary = doors[c]
		var b: int = int(d.get("building", -1))
		if b >= 0 and String(d.get("state", "")) == "locked" and not shut.has(b):
			shut.append(b)
	shut.sort()
	for b: int in shut:
		out[b] = _pick(KEY_WAYS, rng)
	return out


## The named find of this stop, if there is one: a box in a building (a locked
## one too: a safe is a good place for it).
static func _rare(containers: Dictionary, place_kind: String, seed: int, report: Dictionary) -> void:
	var rng := _rng(seed, "rare")
	if rng.randf() >= RARE_CHANCE:
		return
	var kinds: Array = []
	for id: String in FieldItems.RARE:
		if (FieldItems.RARE[id]["places"] as Array).has(place_kind):
			kinds.append(id)
	if kinds.is_empty():
		return
	var boxes: Array = []
	for id: String in containers:
		var c: Dictionary = containers[id]
		if not c.has("pick") and not LootTables.FIXED.has(id) and int(c.get("building", -1)) >= 0:
			boxes.append(id)
	if boxes.is_empty():
		return
	var rare: String = kinds[rng.randi_range(0, kinds.size() - 1)]
	var at: String = boxes[rng.randi_range(0, boxes.size() - 1)]
	(containers[at]["items"] as Array).append(rare)
	report["rare"] = rare
	(report["finds"] as Array).append([rare, at])


## This stop's blueprint piece, if there is one (FRAGMENT_PLACES): a box in a
## building, the office's first (a locked one too, like the named find).
static func _fragment(containers: Dictionary, place_kind: String, seed: int, report: Dictionary) -> void:
	if not FRAGMENT_PLACES.has(place_kind):
		return
	var rng := _rng(seed, "fragment")
	var row: Array = FRAGMENT_PLACES[place_kind]
	if rng.randf() >= float(row[0]):
		return
	var fields: Array = FRAGMENT_FIELDS if row[1] is String else row[1]
	var papers: Array = []
	var indoors: Array = []
	for id: String in containers:
		var c: Dictionary = containers[id]
		if c.has("pick") or LootTables.FIXED.has(id) or int(c.get("building", -1)) < 0:
			continue
		indoors.append(id)
		if room_of(c) == "office":
			papers.append(id)
	var boxes: Array = papers if not papers.is_empty() else indoors
	if boxes.is_empty():
		return
	var piece: String = "frag_" + String(fields[rng.randi_range(0, fields.size() - 1)])
	var at: String = boxes[rng.randi_range(0, boxes.size() - 1)]
	(containers[at]["items"] as Array).append(piece)
	report["fragment"] = piece
	(report["finds"] as Array).append([piece, at])


## The id of the building that is the rare store, as a box's "building" names it (its place
## in the list for a map whose buildings carry no id); -1 for a stop without one.
static func rare_store_of(buildings: Array) -> int:
	for i in buildings.size():
		var b: Dictionary = buildings[i]
		if String(b.get("name", "")) == RARE_STORE:
			return int(b.get("id", i))
	return -1


## A [weight, item, count] row by weight.
static func _row(rows: Array, rng: RandomNumberGenerator) -> Array:
	var total := 0.0
	for r: Array in rows:
		total += float(r[0])
	var at := rng.randf() * total
	for r: Array in rows:
		at -= float(r[0])
		if at < 0.0:
			return r
	return rows[rows.size() - 1]


## Fill the rare store's boxes (RARE_STORE_TABLES) and put its rare thing in one.
static func _rare_store(containers: Dictionary, buildings: Array, place_kind: String, seed: int, report: Dictionary) -> void:
	var b := rare_store_of(buildings)
	if b < 0:
		return
	var kind: String = RARE_STORE_KIND.get(place_kind, "rail")
	var ids: Array = []
	for id: String in containers:
		if int(containers[id].get("building", -1)) == b and not containers[id].has("pick"):
			ids.append(id)
	if ids.is_empty():
		return
	ids.sort()
	var rng := _rng(seed, "rare_store")
	for id: String in ids:
		var items: Array = []
		for r in range(RARE_STORE_ROLLS):
			var row := _row(RARE_STORE_TABLES[kind], rng)
			for k in range(int(row[2])):
				items.append(String(row[1]))
		containers[id]["items"] = items
	var rare: Array = []
	match kind:
		"rail":
			if rng.randf() < RARE_CORE_CHANCE:
				rare.append(RARE_CORE)
			else:
				for k in range(rng.randi_range(RARE_PARTS.x, RARE_PARTS.y)):
					rare.append(_pick(PARTS_KINDS, rng))
		"arms":
			var gun := _pick(RARE_GUNS, rng)
			rare.append(gun)
			for k in range(int(RARE_GUN_ROUNDS[gun][1])):
				rare.append(String(RARE_GUN_ROUNDS[gun][0]))
		"winter":
			rare.append(_pick(RARE_FURS, rng))
			rare.append("fuel_can")
	var into: String = ids[rng.randi_range(0, ids.size() - 1)]
	for item: String in rare:
		(containers[into]["items"] as Array).append(item)
		(report["finds"] as Array).append([item, into])
	report["store"] = kind
