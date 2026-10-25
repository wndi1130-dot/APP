extends RefCounted
## What the fallen carry and what the places hold (loot spec v1). Values only;
## the rules that read them are in loot_rules.gd. Every number is a first
## guess ("base" set), to be set after the 500-run and hand play. Item ids are
## the field items of carry.gd, the named things of field_items.gd and the
## weapon ids of weapons.gd.
##
## A table row is [weight, entry, most]: the row is picked by weight, then
## 1..most of it. An entry is {"id": item}, {"ammo": "pistol"|"shell"} (rounds
## straight into the pool, as the pockets give them now) or {"tool": weapon id}.

## Pockets by kind of the fallen. "chance" is the roll for "something there",
## "rolls" how many times it is made (a padded coat has two pockets).
## "search" is the seconds it takes (the frozen pockets are slow).
const BODY: Dictionary = {
	# The dead: now and then a small thing (user 2026-10-11). The values of today.
	"dead": {"chance": 0.10, "rolls": 1, "search": 3.0, "table": [
		[4, {"id": "bandage"}, 1],
		[3, {"ammo": "pistol"}, 2],
		[3, {"ammo": "shell"}, 2],
	]},
	# Frozen pockets: the same small things and a rag, and twice the time.
	"frozen": {"chance": 0.10, "rolls": 1, "search": 5.0, "table": [
		[4, {"id": "bandage"}, 1],
		[3, {"ammo": "pistol"}, 2],
		[3, {"ammo": "shell"}, 2],
		[2, {"id": "cloth"}, 1],
	]},
	# The padded ones: where they worked shows in what they carry, by place.
	"clothed": {"chance": 0.35, "rolls": 2, "search": 4.0, "table": [
		[2, {"id": "cloth"}, 1],
		[2, {"ammo": "pistol"}, 2],
		[1, {"id": "document"}, 1],
	]},
	"clothed_station": {"chance": 0.35, "rolls": 2, "search": 4.0, "table": [
		[3, {"id": "flare"}, 1],
		[2, {"id": "document"}, 1],
		[2, {"ammo": "pistol"}, 2],
		[1, {"id": "info_timetable"}, 1],
		[1, {"id": "luxury_pack"}, 1],
	]},
	"clothed_shed": {"chance": 0.35, "rolls": 2, "search": 4.0, "table": [
		[3, {"id": "scrap"}, 1],
		[2, {"ammo": "shell"}, 2],
		[2, {"id": "cloth"}, 1],
		[1, {"tool": "crowbar"}, 1],
	]},
	# The dead by the building they are found in (decision 423, P08): as often and
	# as quick as the dead's, but what they carry says what the place was. The
	# named things are field_items.gd's; a watch may still be set to ring (P19).
	"dead_hospital": {"chance": 0.10, "rolls": 1, "search": 3.0, "table": [
		[3, {"id": "painkillers"}, 1],
		[3, {"id": "bandage"}, 1],
		[2, {"id": "ointment"}, 1],
		[1, {"id": "antiseptic"}, 1],
	]},
	"dead_workshop": {"chance": 0.10, "rolls": 1, "search": 3.0, "table": [
		[3, {"id": "nails"}, 1],
		[2, {"id": "scrap"}, 1],
		[2, {"ammo": "shell"}, 2],
		[1, {"id": "bandage"}, 1],
	]},
	"dead_shop": {"chance": 0.10, "rolls": 1, "search": 3.0, "table": [
		[3, {"id": "cigarettes"}, 1],
		[2, {"id": "hardtack"}, 1],
		[2, {"ammo": "pistol"}, 2],
		[1, {"id": "wrist_watch_set"}, 1],
	]},
	"dead_house": {"chance": 0.10, "rolls": 1, "search": 3.0, "table": [
		[3, {"id": "wrist_watch_set"}, 1],
		[2, {"id": "wrist_watch"}, 1],
		[2, {"id": "bandage"}, 1],
		[2, {"ammo": "pistol"}, 2],
		[1, {"id": "pocket_watch"}, 1],
	]},
	"dead_farm": {"chance": 0.10, "rolls": 1, "search": 3.0, "table": [
		[3, {"id": "apple"}, 1],
		[2, {"id": "bandage"}, 1],
		[2, {"ammo": "shell"}, 2],
	]},
}

## Where a padded one stood, read from the building it is nearest (by name).
const PLACE_OF_BUILDING: Dictionary = {"역사": "station", "화물 창고": "shed"}
## Then by the words of the building's name, in this order (the first that
## matches): where the dead were found, for the tables above. A padded one with
## no table of its own for the place keeps the padded table.
const PLACE_ORDER: Array[String] = ["hospital", "shop", "workshop", "farm", "house"]
const PLACE_WORDS: Dictionary = {
	"hospital": ["병원", "약국", "약방", "의사", "간호", "진료", "구급"],
	"shop": ["식료품", "잡화", "매점", "상회", "가게", "상점", "빵집"],
	"workshop": ["공장", "기계", "공구", "정비", "철물", "부품", "제재", "변전", "차고", "대장"],
	"farm": ["농가", "외양간", "헛간", "마구간", "우물집", "과수"],
	"house": ["주택", "사택", "연립", "본채", "오두막", "관리인", "숙직", "기숙", "움막", "집"],
}
## How near (cells) a building must be to count as where it stood.
const PLACE_REACH: int = 4
## A tool found in pockets comes worn.
const TOOL_CONDITION: float = 0.7

## The dead that keep coming up the sewers and down the line come with
## emptier pockets: what never runs out must not pay out without end.
const HORDE_MULT: float = 0.5

## What the fallen have on (decision 434, clothing.md 8장, zombies.md 「껴입은
## 자와 전리품」): every one of the dead is in worn plain winter clothes; the
## padded ones are thickly dressed over that; where one stood shows in a
## garment or two over the rest (near the police station many wear the grey
## quilted vest, at the fire station the fire suit). Place by place, rows of
## [id, weight] ("" for nothing there); the kind's rows replace the plain
## ones of that place, and the place's replace both. A whole suit takes its
## other place with it. New values (PR 「새로 넣은 값」).
const WEAR_PLAIN: Dictionary = {
	"under_top": [["undershirt_cotton", 3], ["undershirt_wool", 1]],
	"shirt": [["shirt_cotton", 3], ["shirt_flannel", 2], ["shirt_wool", 1]],
	"sweater": [["", 2], ["sweater_wool", 2], ["vest_knit", 1]],
	"jacket": [["jacket_plain", 3], ["vest_quilted", 1], ["", 1]],
	"coat": [["", 3], ["coat_wool_long", 2], ["coat_long", 1]],
	"under_legs": [["drawers_cotton", 1]],
	"trousers": [["trousers_cotton", 3], ["trousers_wool", 1]],
	"socks": [["socks_cotton", 2], ["socks_wool", 1]],
	"shoes": [["shoes_leather", 3], ["boots_work", 1], ["", 1]],
	"head": [["", 3], ["hat_knit", 1], ["hat_earflap", 1]],
	"neck": [["", 3], ["scarf_wool", 1]],
	"hands": [["", 3], ["gloves", 1], ["mittens", 1]],
}
const WEAR_KIND: Dictionary = {
	"clothed": {
		"sweater": [["sweater_thick", 2], ["sweater_wool", 1]],
		"coat": [["coat_padded", 2], ["coat_long", 2]],
		"trousers": [["trousers_wool", 2], ["trousers_work", 1]],
		"head": [["hat_earflap", 2], ["hat_knit", 1], ["", 1]],
		"hands": [["mittens", 1], ["gloves", 1], ["", 1]],
	},
}
const WEAR_PLACE: Dictionary = {
	"police": {"coat": [["vest_armor", 2], ["", 1]]},
	"fire": {"coat": [["fire_suit", 2], ["coat_long", 1]], "shoes": [["boots_rubber", 2], ["boots_work", 1]]},
	"station": {"jacket": [["jacket_short", 2], ["jacket_plain", 1]]},
	"shed": {"shirt": [["coverall", 1], ["shirt_work", 1]], "jacket": [["jacket_work", 2], ["vest_quilted", 1]], "hands": [["gloves_leather", 1], ["gloves_cotton", 1], ["", 1]]},
	"workshop": {"shirt": [["shirt_work", 2], ["coverall", 1]], "jacket": [["jacket_work", 2], ["", 1]], "trousers": [["trousers_work", 1]], "overtrousers": [["", 2], ["bib_work", 1]], "shoes": [["boots_work", 1]], "hands": [["gloves_leather", 1], ["gloves_cotton", 1], ["", 1]]},
	"farm": {"jacket": [["jacket_work", 1], ["vest_quilted", 1]], "coat": [["", 2], ["raincoat", 1]], "overtrousers": [["", 1], ["overtrousers_oil", 1]], "shoes": [["boots_rubber", 2], ["boots_work", 1]]},
	"hospital": {"sweater": [["", 3], ["vest_knit", 1]], "coat": [["", 1]], "face": [["", 2], ["mask_cloth", 1]]},
}
## Where a fallen one stood, for what it has on: these words of a building's
## name first (the pockets keep their own places, PLACE_WORDS), then as the pockets.
const WEAR_PLACE_WORDS: Dictionary = {"police": ["경찰"], "fire": ["소방"]}
## How worn the dead's clothes are, [least, most] of wear by kind, and the
## chance each part a garment covers already has a hole in it (a few holes
## on each at the start of the winter). New values.
const WEAR_WORN: Dictionary = {"dead": [0.25, 0.75], "frozen": [0.25, 0.75], "clothed": [0.2, 0.6], "fresh": [0.05, 0.35]}
const WEAR_HOLES: Dictionary = {"dead": 0.2, "frozen": 0.2, "clothed": 0.15, "fresh": 0.1}

## Container kinds of the first stop (building spec 7.2, decision 321): the
## words a container's name is folded by (first kind that matches wins, in
## this order), how many rolls, and the rows. "×2" rows are a count of 2.
const KIND_ORDER: Array[String] = ["pharmacy", "toolbox", "attic", "toilet", "junk", "desk", "shop", "kitchen", "wardrobe", "storage"]
const CONTAINER_KINDS: Dictionary = {
	"kitchen": {"name": "부엌 찬장", "words": ["부엌", "찬장"], "rolls": 2, "table": [
		[8, "food_pack", 1], [2, "bottle_spirit", 1], [1, "bandage", 1], [1, "med_box", 1], [1, "luxury_pack", 1]]},
	"wardrobe": {"name": "옷장·서랍", "words": ["옷장", "서랍", "침실"], "rolls": 2, "table": [
		[5, "cloth", 1], [2, "ammo_pistol", 1], [1, "ammo_shell", 1], [1, "bandage", 1], [1, "luxury_pack", 1], [1, "med_box", 1]]},
	"desk": {"name": "책상·장부", "words": ["책상", "탁자", "장부"], "rolls": 2, "table": [
		[5, "document", 1], [2, "info_timetable", 1], [1, "info_telegraph", 1], [1, "flare", 1], [1, "luxury_pack", 1]]},
	"shop": {"name": "가게 선반", "words": ["가게 선반", "매점 선반"], "rolls": 3, "table": [
		[3, "food_pack", 2], [2, "food_pack", 1], [1, "bottle_spirit", 1], [1, "cloth", 1], [1, "luxury_pack", 1]]},
	"storage": {"name": "창고 상자·자루", "words": ["창고", "상자", "자루", "선반"], "rolls": 2, "table": [
		[2, "plank", 2], [2, "plank", 1], [3, "food_pack", 1], [1, "cloth", 1], [1, "bottle_spirit", 1], [1, "luxury_pack", 1], [1, "scrap", 1]]},
	"toolbox": {"name": "공구함", "words": ["공구함"], "rolls": 2, "table": [
		[3, "scrap", 1], [1, "plank", 1], [1, "cloth", 1]]},
	"pharmacy": {"name": "약국 진열대", "words": ["약국"], "rolls": 2, "table": [
		[3, "med_box", 1], [2, "bandage", 2], [1, "bandage", 1], [1, "cloth", 1]]},
	"attic": {"name": "다락 상자", "words": ["다락"], "rolls": 2, "table": [
		[3, "luxury_pack", 1], [2, "cloth", 1], [2, "ammo_shell", 1]]},
	"toilet": {"name": "화장실 장", "words": ["화장실"], "rolls": 2, "table": [
		[2, "cloth", 1], [1, "bandage", 1], [1, "bottle_spirit", 1]]},
	"junk": {"name": "잡동사니", "words": ["대합실", "사물함"], "rolls": 2, "table": [
		[2, "cloth", 1], [1, "document", 1], [1, "ammo_shell", 1], [1, "medkit", 1]]},
}

## What the story and the tests lean on by name (building spec 7.2). These are
## not rolled. "plus" is a kind still rolled on top (the pharmacy store keeps
## its tweezers and thread and rolls the rest like the counter).
const FIXED: Dictionary = {
	"bell": {"items": ["symbol_bell"]},
	"office_desk": {"items": ["info_telegraph", "info_timetable", "medkit", "tweezers", "needle_thread", "needle_thread", "needle_thread"]},
	"ticket_safe": {"items": ["luxury_pack", "luxury_pack"]},
	"pharmacy_store": {"items": ["tweezers", "needle_thread", "needle_thread", "needle_thread"], "plus": "pharmacy"},
}

## Three sets to show side by side (spec 5). Each scales the base values.
## blank: weight of an empty row added to every container table.
## extra_rolls: a roll more for these kinds.
const SETS: Dictionary = {
	"conservative": {"body_chance": 0.7, "horde_mult": 0.0, "clothed_chance": 0.25, "blank": 1, "extra_rolls": []},
	"base": {"body_chance": 1.0, "horde_mult": HORDE_MULT, "clothed_chance": 0.35, "blank": 0, "extra_rolls": []},
	"aggressive": {"body_chance": 1.5, "horde_mult": 1.0, "clothed_chance": 0.5, "blank": 0, "extra_rolls": ["kitchen", "shop", "storage"]},
}

## Going through a container is heard this often at "quiet" (spec 4, open
## question 4). 0 is silent, as it is today. Not read by the game yet.
const SEARCH_NOISE_EVERY: Dictionary = {"conservative": 3.0, "base": 4.0, "aggressive": 0.0}
