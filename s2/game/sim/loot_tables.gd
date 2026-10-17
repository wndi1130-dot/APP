extends RefCounted
## What the fallen carry and what the places hold (loot spec v1). Values only;
## the rules that read them are in loot_rules.gd. Every number is a first
## guess ("base" set), to be set after the 500-run and hand play. Item ids are
## the field items of carry.gd and the weapon ids of weapons.gd, nothing new.
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
	"frozen": {"chance": 0.10, "rolls": 1, "search": 6.0, "table": [
		[4, {"id": "bandage"}, 1],
		[3, {"ammo": "pistol"}, 2],
		[3, {"ammo": "shell"}, 2],
		[2, {"id": "cloth"}, 1],
	]},
	# The padded ones: where they worked shows in what they carry, by place.
	"clothed": {"chance": 0.35, "rolls": 2, "search": 4.5, "table": [
		[2, {"id": "cloth"}, 1],
		[2, {"ammo": "pistol"}, 2],
		[1, {"id": "document"}, 1],
	]},
	"clothed_station": {"chance": 0.35, "rolls": 2, "search": 4.5, "table": [
		[3, {"id": "flare"}, 1],
		[2, {"id": "document"}, 1],
		[2, {"ammo": "pistol"}, 2],
		[1, {"id": "info_timetable"}, 1],
		[1, {"id": "luxury_pack"}, 1],
	]},
	"clothed_shed": {"chance": 0.35, "rolls": 2, "search": 4.5, "table": [
		[3, {"id": "scrap"}, 1],
		[2, {"ammo": "shell"}, 2],
		[2, {"id": "cloth"}, 1],
		[1, {"tool": "crowbar"}, 1],
	]},
}

## Where a padded one stood, read from the building it is nearest (by name).
const PLACE_OF_BUILDING: Dictionary = {"역사": "station", "화물 창고": "shed"}
## How near (cells) a building must be to count as where it stood.
const PLACE_REACH: int = 4
## A tool found in pockets comes worn.
const TOOL_CONDITION: float = 0.7

## The dead that keep coming up the sewers and down the line come with
## emptier pockets: what never runs out must not pay out without end.
const HORDE_MULT: float = 0.5

## Container kinds of the first stop (building spec 7.2, decision 321): the
## words a container's name is folded by (first kind that matches wins, in
## this order), how many rolls, and the rows. "×2" rows are a count of 2.
const KIND_ORDER: Array[String] = ["pharmacy", "toolbox", "attic", "toilet", "junk", "desk", "shop", "kitchen", "wardrobe", "storage"]
const CONTAINER_KINDS: Dictionary = {
	"kitchen": {"name": "부엌 찬장", "words": ["부엌", "찬장"], "rolls": 2, "table": [
		[6, "food_pack", 1], [2, "bottle_spirit", 1], [1, "bandage", 1], [1, "med_box", 1], [1, "luxury_pack", 1]]},
	"wardrobe": {"name": "옷장·서랍", "words": ["옷장", "서랍", "침실"], "rolls": 2, "table": [
		[5, "cloth", 1], [2, "ammo_pistol", 1], [1, "ammo_shell", 1], [1, "bandage", 1], [1, "luxury_pack", 1], [1, "med_box", 1]]},
	"desk": {"name": "책상·장부", "words": ["책상", "탁자", "장부"], "rolls": 2, "table": [
		[5, "document", 1], [2, "info_timetable", 1], [1, "info_telegraph", 1], [1, "flare", 1], [1, "luxury_pack", 1]]},
	"shop": {"name": "가게 선반", "words": ["가게 선반", "매점 선반"], "rolls": 2, "table": [
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
