extends RefCounted
## Clothes in fourteen places, worn in layers from the skin out (decision 434,
## docs/design/briefs/clothing.md). Each garment keeps its own values; what is
## worn fills the body-heat inputs (body_heat.gd ctx warmth and windproof, its
## own sums and limits as they were): the warmth of everything adds up, only the
## outermost layer over the body stops the wind (body_injury 6장). A soaked
## garment keeps only some of its warmth, by what it is made of; a worn one a
## little less. The dead's nails and teeth meet the layers over a part outside
## in (3.4): the first that holds is torn a little, the ones it got through
## more; a pistol round only the vest stops (bullet). Putting one on is a job
## of the hands as long as its motion, and a layer under others takes those
## off and puts them back, step by step (dress_plan, field_actions.gd, the
## clips of #564); the head, the neck, the face and the hands at a walk. A
## garment taken off lies at the feet as it is, worn and torn (ground_items
## "garment"; by the train it goes aboard); the bag never holds clothes. The
## dead wear clothes too, and they can be taken off them (loot_rules.gd wear_roll).
## What everyone goes out in is as before: the railway coat and the gloves give
## warmth 0.8, windproof 0.5 and block 0.25, the plain cotton under them nothing.

const GrabRules = preload("res://game/sim/grab_rules.gd")

const SLOTS: Array[String] = [
	"under_top", "shirt", "sweater", "jacket", "coat",
	"under_legs", "trousers", "overtrousers",
	"socks", "shoes",
	"head", "neck", "face",
	"hands",
]
## The places worn one over another, skin first: a layer under others is only
## changed by taking those off and putting them back on (7장).
const STACKS: Array = [
	["under_top", "shirt", "sweater", "jacket", "coat"],
	["under_legs", "trousers", "overtrousers"],
	["socks", "shoes"],
]
## Over the body, outermost last: the one that stops the wind and the rain.
const UPPER: Array[String] = ["under_top", "shirt", "sweater", "jacket", "coat"]
## The body parts (body_state.gd PARTS) each place covers; the hands are the arms', the feet the legs'.
const COVERS: Dictionary = {
	"under_top": ["torso", "arm_left", "arm_right"], "shirt": ["torso", "arm_left", "arm_right"],
	"sweater": ["torso", "arm_left", "arm_right"], "jacket": ["torso", "arm_left", "arm_right"],
	"coat": ["torso", "arm_left", "arm_right"],
	"under_legs": ["leg_left", "leg_right"], "trousers": ["leg_left", "leg_right"],
	"overtrousers": ["leg_left", "leg_right"], "socks": ["leg_left", "leg_right"], "shoes": ["leg_left", "leg_right"],
	"head": ["head_neck"], "neck": ["head_neck"], "face": ["head_neck"],
	"hands": ["arm_left", "arm_right"],
}
## Where a hand or the teeth meet the clothes first, outside in.
const OUTSIDE_IN: Array[String] = ["coat", "jacket", "hands", "sweater", "shirt", "under_top",
	"overtrousers", "shoes", "trousers", "socks", "under_legs", "face", "neck", "head"]

## Each kind: its place (and "also" the places a whole suit takes with it),
## name, picture, weight, warmth, what it is made of, and when it has them
## windproof, water (keeps the rain out), block (nails) and bite (teeth),
## heavy (grab_rules.gd: half of nails and teeth on what it covers, and slower,
## body_state.gd), "covers" for a vest that leaves the arms bare, and how it
## looks: the shell drawn over the body (models/people/<own>/wear/<shell>, ""
## for none), its tint and pattern (the 3D side's look_* fields, look()).
## jacket_short, coat_long, hat_knit, hood and gloves keep #594's numbers;
## the rest are new (PR 「새로 넣은 값」).
const KINDS: Dictionary = {
	# Under it all.
	"undershirt_cotton": {"slot": "under_top", "name": "면 윗속옷", "icon": "it_undershirt", "weight": 0.1, "warmth": 0.0, "stuff": "cotton", "covers": ["torso"]},
	"undershirt_wool": {"slot": "under_top", "name": "털 윗속옷", "icon": "it_undershirt", "weight": 0.2, "warmth": 0.1, "stuff": "wool"},
	"drawers_cotton": {"slot": "under_legs", "name": "면 아랫속옷", "icon": "it_drawers", "weight": 0.1, "warmth": 0.0, "stuff": "cotton"},
	"long_johns": {"slot": "under_top", "also": ["under_legs"], "name": "털 긴 속옷", "icon": "it_drawers", "weight": 0.4, "warmth": 0.2, "stuff": "wool"},
	# Shirts.
	"shirt_cotton": {"slot": "shirt", "name": "면 셔츠", "icon": "it_shirt", "weight": 0.3, "warmth": 0.0, "stuff": "cotton"},
	"shirt_flannel": {"slot": "shirt", "name": "플란넬 셔츠", "icon": "it_shirt", "weight": 0.4, "warmth": 0.08, "stuff": "cotton"},
	"shirt_work": {"slot": "shirt", "name": "작업 셔츠", "icon": "it_shirt", "weight": 0.5, "warmth": 0.05, "block": 0.05, "stuff": "cotton"},
	"shirt_wool": {"slot": "shirt", "name": "털 셔츠", "icon": "it_shirt", "weight": 0.5, "warmth": 0.12, "stuff": "wool"},
	# Sweaters.
	"sweater_wool": {"slot": "sweater", "name": "털 스웨터", "icon": "it_sweater", "weight": 0.6, "warmth": 0.15, "block": 0.05, "stuff": "wool"},
	"sweater_thick": {"slot": "sweater", "name": "두꺼운 스웨터", "icon": "it_sweater", "weight": 0.9, "warmth": 0.22, "block": 0.1, "stuff": "wool"},
	"vest_knit": {"slot": "sweater", "name": "뜨개 조끼", "icon": "it_vest", "weight": 0.3, "warmth": 0.08, "stuff": "wool", "covers": ["torso"]},
	# Jackets: the railway coat everyone has is one.
	"jacket_short": {"slot": "jacket", "name": "철도원 외투", "icon": "it_jacket", "weight": 2.0, "warmth": 0.7, "windproof": 0.5, "block": 0.25, "heavy": false, "stuff": "wool", "shell": "jacket_short", "tint": [0.1, 0.11, 0.14], "pattern": "plain"},
	"jacket_plain": {"slot": "jacket", "name": "짧은 재킷", "icon": "it_jacket", "weight": 1.5, "warmth": 0.45, "windproof": 0.4, "block": 0.2, "stuff": "wool", "shell": "jacket_short", "tint": [0.13, 0.12, 0.11], "pattern": "check"},
	"jacket_work": {"slot": "jacket", "name": "작업 재킷", "icon": "it_jacket", "weight": 1.8, "warmth": 0.4, "windproof": 0.45, "block": 0.3, "stuff": "cotton", "shell": "jacket_short", "tint": [0.11, 0.12, 0.12], "pattern": "plain"},
	"coat_leather": {"slot": "jacket", "name": "가죽 외투", "icon": "it_coat", "weight": 2.5, "warmth": 0.5, "windproof": 0.8, "block": 0.4, "bite": 0.25, "stuff": "leather", "shell": "coat_long", "tint": [0.1, 0.085, 0.075], "pattern": "plain"},
	"vest_quilted": {"slot": "jacket", "name": "누빔 조끼", "icon": "it_vest", "weight": 0.8, "warmth": 0.25, "windproof": 0.2, "block": 0.1, "stuff": "padded", "covers": ["torso"]},
	# Coats, over the jacket.
	"coat_long": {"slot": "coat", "name": "두꺼운 겉옷", "icon": "it_coat", "weight": 3.0, "warmth": 0.9, "windproof": 0.7, "block": 0.5, "bite": 0.5, "heavy": true, "stuff": "wool", "shell": "coat_long", "tint": [0.12, 0.1, 0.085], "pattern": "plain"},
	"coat_padded": {"slot": "coat", "name": "솜 외투", "icon": "it_coat", "weight": 2.5, "warmth": 0.8, "windproof": 0.6, "block": 0.5, "bite": 0.5, "heavy": true, "stuff": "padded", "shell": "coat_long", "tint": [0.1, 0.11, 0.12], "pattern": "quilt"},
	"coat_wool_long": {"slot": "coat", "name": "긴 털 외투", "icon": "it_coat", "weight": 2.8, "warmth": 0.75, "windproof": 0.6, "block": 0.3, "stuff": "wool", "shell": "coat_long", "tint": [0.11, 0.105, 0.1], "pattern": "plain"},
	"raincoat": {"slot": "coat", "name": "비옷", "icon": "it_coat", "weight": 0.8, "warmth": 0.05, "windproof": 0.7, "water": 0.9, "block": 0.05, "stuff": "oilcloth", "shell": "coat_long", "tint": [0.12, 0.13, 0.12], "pattern": "plain"},
	"fire_suit": {"slot": "coat", "also": ["overtrousers"], "name": "방화복", "icon": "it_coat", "weight": 5.0, "warmth": 0.6, "windproof": 0.8, "water": 0.6, "block": 0.5, "bite": 0.5, "heavy": true, "stuff": "oilcloth", "shell": "coat_long", "tint": [0.13, 0.12, 0.1], "pattern": "plain"},
	"vest_armor": {"slot": "coat", "name": "방탄조끼", "icon": "it_vest", "weight": 3.0, "warmth": 0.15, "windproof": 0.2, "block": 0.5, "bite": 0.5, "bullet": 1.0, "heavy": true, "stuff": "padded", "covers": ["torso"], "shell": "vest", "pattern": "quilt", "tint": [0.13, 0.135, 0.14]},
	# Trousers.
	"trousers_cotton": {"slot": "trousers", "name": "면 바지", "icon": "it_trousers", "weight": 0.5, "warmth": 0.0, "stuff": "cotton"},
	"trousers_work": {"slot": "trousers", "name": "작업 바지", "icon": "it_trousers", "weight": 0.7, "warmth": 0.05, "block": 0.1, "stuff": "cotton"},
	"trousers_wool": {"slot": "trousers", "name": "털 바지", "icon": "it_trousers", "weight": 0.8, "warmth": 0.12, "block": 0.05, "stuff": "wool"},
	"overtrousers_oil": {"slot": "overtrousers", "name": "기름천 덧바지", "icon": "it_trousers", "weight": 0.6, "warmth": 0.03, "water": 0.8, "block": 0.1, "stuff": "oilcloth"},
	"bib_work": {"slot": "overtrousers", "name": "멜빵 작업 바지", "icon": "it_overalls", "weight": 1.0, "warmth": 0.1, "block": 0.2, "stuff": "cotton"},
	# Feet.
	"socks_cotton": {"slot": "socks", "name": "면 양말", "icon": "it_socks", "weight": 0.05, "warmth": 0.0, "stuff": "cotton"},
	"socks_wool": {"slot": "socks", "name": "털 양말", "icon": "it_socks", "weight": 0.1, "warmth": 0.05, "stuff": "wool"},
	"shoes_leather": {"slot": "shoes", "name": "구두", "icon": "it_shoes", "weight": 0.6, "warmth": 0.0, "stuff": "leather"},
	"boots_work": {"slot": "shoes", "name": "작업화", "icon": "it_boots", "weight": 1.0, "warmth": 0.03, "block": 0.2, "bite": 0.2, "stuff": "leather"},
	"boots_rubber": {"slot": "shoes", "name": "장화", "icon": "it_boots", "weight": 1.2, "warmth": 0.03, "water": 0.9, "block": 0.2, "bite": 0.2, "stuff": "oilcloth"},
	"boots_fur": {"slot": "shoes", "name": "털장화", "icon": "it_boots", "weight": 1.3, "warmth": 0.1, "block": 0.15, "bite": 0.15, "stuff": "wool"},
	# Head, neck and face.
	"hat_knit": {"slot": "head", "name": "털모자", "icon": "it_hat", "weight": 0.2, "warmth": 0.1, "stuff": "wool", "shell": "hat_knit", "tint": [0.17, 0.12, 0.1], "pattern": "knit"},
	"hat_earflap": {"slot": "head", "name": "귀마개 모자", "icon": "it_hat", "weight": 0.3, "warmth": 0.15, "stuff": "wool", "shell": "hat_knit", "tint": [0.12, 0.11, 0.1], "pattern": "plain"},
	"cap_brim": {"slot": "head", "name": "챙 모자", "icon": "it_cap", "weight": 0.2, "warmth": 0.03, "stuff": "cotton", "shell": "hat_knit", "tint": [0.11, 0.11, 0.12], "pattern": "check"},
	"hood": {"slot": "head", "name": "두건", "icon": "it_hood", "weight": 0.3, "warmth": 0.05, "stuff": "cotton", "shell": "hood", "tint": [0.13, 0.135, 0.14], "pattern": "plain"},
	"hood_wool": {"slot": "head", "name": "털 두건", "icon": "it_hood", "weight": 0.35, "warmth": 0.12, "stuff": "wool", "shell": "hood", "tint": [0.12, 0.115, 0.11], "pattern": "knit"},
	"scarf_wool": {"slot": "neck", "name": "털 목도리", "icon": "it_scarf", "weight": 0.2, "warmth": 0.08, "stuff": "wool"},
	"scarf_thick": {"slot": "neck", "name": "두꺼운 목도리", "icon": "it_scarf", "weight": 0.3, "warmth": 0.12, "stuff": "wool"},
	"mask_cloth": {"slot": "face", "name": "천 마스크", "icon": "it_mask", "weight": 0.05, "warmth": 0.02, "stuff": "cotton"},
	# Hands.
	# The hands are painted, not shelled: a tint each (the 3D side's glove colour,
	# #616); the plain ones keep the dark worn wool of the gloved picture.
	"gloves": {"slot": "hands", "name": "장갑", "icon": "it_gloves", "weight": 0.2, "warmth": 0.1, "stuff": "wool", "pattern": "knit"},
	"gloves_cotton": {"slot": "hands", "name": "면 장갑", "icon": "it_gloves", "weight": 0.1, "warmth": 0.05, "stuff": "cotton", "tint": [0.17, 0.165, 0.155], "pattern": "plain"},
	"gloves_leather": {"slot": "hands", "name": "가죽 장갑", "icon": "it_gloves", "weight": 0.3, "warmth": 0.08, "block": 0.1, "bite": 0.2, "stuff": "leather", "tint": [0.12, 0.095, 0.075], "pattern": "plain"},
	"mittens": {"slot": "hands", "name": "손모아장갑", "icon": "it_gloves", "weight": 0.2, "warmth": 0.15, "stuff": "wool", "tint": [0.13, 0.11, 0.1], "pattern": "knit"},
	# Whole suits: a shirt and trousers in one.
	"coverall": {"slot": "shirt", "also": ["trousers"], "name": "작업복", "icon": "it_overalls", "weight": 1.2, "warmth": 0.1, "block": 0.15, "stuff": "cotton"},
	"dress_wool": {"slot": "shirt", "also": ["trousers"], "name": "원피스", "icon": "it_dress", "weight": 0.6, "warmth": 0.08, "stuff": "wool"},
}
## The values a garment carries on itself, so a worn one keeps what it was.
## "bullet" is the vest's alone: it stops a pistol round on what it covers
## (body_injury 6장: the only garment that does; a thick coat stops blades and
## teeth, never a round).
const VALUE_KEYS: Array[String] = ["warmth", "windproof", "water", "block", "bite", "bullet"]
## How much of its warmth a garment keeps soaked through: wool about half
## (body_injury 6장 「털옷은 젖어도 따뜻함을 반쯤」), cotton next to none (#594);
## leather, oilcloth and wadding new.
const WET_KEEP: Dictionary = {"wool": 0.5, "cotton": 0.2, "leather": 0.6, "oilcloth": 0.9, "padded": 0.3}
## How long putting one on takes, the length of its motion (#564: p_wear_outer
## 2.4 s, p_wear_head 1.4 s, p_wear_hands 1.8 s); taking it off, the same. The
## places with no motion of their own borrow the nearest.
const TIME: Dictionary = {
	"under_top": 2.4, "shirt": 2.4, "sweater": 2.4, "jacket": 2.4, "coat": 2.4,
	"under_legs": 2.4, "trousers": 2.4, "overtrousers": 2.4, "socks": 2.4, "shoes": 2.4,
	"head": 1.4, "neck": 1.4, "face": 1.4, "hands": 1.8,
}
const CLIP: Dictionary = {
	"under_top": "p_wear_outer", "shirt": "p_wear_outer", "sweater": "p_wear_outer", "jacket": "p_wear_outer",
	"coat": "p_wear_outer", "under_legs": "p_wear_outer", "trousers": "p_wear_outer", "overtrousers": "p_wear_outer",
	"socks": "p_wear_outer", "shoes": "p_wear_outer", "head": "p_wear_head", "neck": "p_wear_head",
	"face": "p_wear_head", "hands": "p_wear_hands",
}
## What a squad goes out in: plain cotton, shoes, the railway coat and the
## gloves everyone had, nothing on the head (10장).
const DEFAULT: Dictionary = {
	"under_top": "undershirt_cotton", "shirt": "shirt_cotton", "jacket": "jacket_short",
	"under_legs": "drawers_cotton", "trousers": "trousers_cotton", "socks": "socks_cotton",
	"shoes": "shoes_leather", "hands": "gloves",
}
## A garment's wear in words (body_injury 6장 멀쩡·해짐·너덜): worn this much and over.
const TORN_AT: float = 0.34
const RAGS_AT: float = 0.67
const STATE_WORDS: Array[String] = ["멀쩡", "해짐", "너덜"]
## What wearing more costs (5장, new values): the share of a worn garment's
## weight that goes on the load past what everyone goes out in, and the share
## of its warmth a garment worn through has lost.
const WORN_WEIGHT_SHARE: float = 0.3
const WORN_WARMTH_LOSS: float = 0.5
## Sweat (survival_detail 1장): dressed warmer than this, running or at work
## soaks one from the inside, so much a second, never past this (under the
## carry.gd 「soaked」 line, so sweat alone adds no load). New values.
const SWEAT_AT: float = 1.0
const SWEAT_RATE: float = 0.004
const SWEAT_MOST: float = 0.4
## Rain and sleet under the open sky (the weather that wets, weather.gd
## wets_clothes), so much a second, less what the outermost layer keeps out. New value.
const RAIN_WET: float = 0.003
## The places put on and taken off at a walk (7장): the head, the neck, the
## face and the hands; the rest stop when one walks. A run stops them all.
const WALKABLE: Array[String] = ["head", "neck", "face", "hands"]
## Worn this far through a garment is in rags: it cannot be put on any more
## (3.3; cut into cloth on the train, PR D).
const BROKEN_AT: float = 1.0
## Taking a garment off one of the fallen (8장): so many seconds for each unit
## of its weight (as long as one 2.4 s motion a unit), the weight counted from
## this little up to this much. New values.
const STRIP_PER_WEIGHT: float = 2.4
const STRIP_WEIGHT_LEAST: float = 0.5
const STRIP_WEIGHT_MOST: float = 3.0
## A round stopped by the vest tears what stopped it there this often at the
## least, the less so the more that holds teeth (1 − bite / this): so the
## next round on that spot most often goes through. New values.
const SHOT_HOLE_LEAST: float = 0.3
const SHOT_HOLE_BITE: float = 1.5


static func is_garment(id: String) -> bool:
	return KINDS.has(id)


static func slot_of(id: String) -> String:
	return String(KINDS.get(id, {}).get("slot", ""))


## Every place a kind takes: its own, then the ones a whole suit takes with it.
static func slots_of(id: String) -> Array[String]:
	var out: Array[String] = []
	if not KINDS.has(id):
		return out
	out.append(String(KINDS[id]["slot"]))
	for s in KINDS[id].get("also", []):
		out.append(String(s))
	return out


## The body parts a garment covers.
static func covers(id: String) -> Array[String]:
	var out: Array[String] = []
	var k: Dictionary = KINDS.get(id, {})
	if k.has("covers"):
		for part in k["covers"]:
			out.append(String(part))
		return out
	for s: String in slots_of(id):
		for part in COVERS[s]:
			if not out.has(String(part)):
				out.append(String(part))
	return out


## A fresh one, as it is worn: its id, name and wear, and its values (grab_rules.gd
## and body heat read them off the garment, so a worn one keeps what it was).
static func make(id: String) -> Dictionary:
	var k: Dictionary = KINDS.get(id, {})
	if k.is_empty():
		return {}
	var d := {"id": id, "name": String(k["name"]), "wear": 0.0, "heavy": bool(k.get("heavy", false))}
	for key: String in VALUE_KEYS:
		d[key] = float(k.get(key, 0.0))
	return d


## Nothing over the body: what the dead's hands meet with no coat on.
static func bare_outer() -> Dictionary:
	return {"id": "", "name": "", "warmth": 0.0, "windproof": 0.0, "block": 0.0, "heavy": false, "wear": 0.0}


## A whole outfit, place by place: {slot: id} -> {slot: state}.
static func outfit(ids: Dictionary) -> Dictionary:
	var out := {}
	for s in ids:
		var g := make(String(ids[s]))
		if not g.is_empty():
			out[String(s)] = g
	return out


## The place in p.worn of what takes `slot` (its own, or a whole suit's), "" for nothing.
static func holder_slot(p, slot: String) -> String:
	if p.worn.has(slot):
		return slot
	for key in p.worn:
		var id: String = String((p.worn[key] as Dictionary).get("id", ""))
		if slots_of(id).has(slot):
			return String(key)
	return ""


## What takes `slot`, {} for nothing.
static func occupant(p, slot: String) -> Dictionary:
	var key := holder_slot(p, slot)
	return p.worn[key] if key != "" else {}


## Everything worn, each once, skin first.
static func worn_list(p) -> Array:
	var out: Array = []
	for s: String in SLOTS:
		if p.worn.has(s):
			out.append(p.worn[s])
	return out


## What is in each place: an id, "" for nothing (a whole suit shows in its own place only).
static func worn_ids(p) -> Dictionary:
	var out := {}
	for s: String in SLOTS:
		out[s] = String((p.worn[s] as Dictionary).get("id", "")) if p.worn.has(s) else ""
	return out


## The share of a garment's warmth left at this wetness (0 dry .. 1 soaked).
static func keep_when(id: String, wet: float) -> float:
	var stuff: String = String(KINDS.get(id, {}).get("stuff", "wool"))
	return 1.0 - clampf(wet, 0.0, 1.0) * (1.0 - float(WET_KEEP.get(stuff, 1.0)))


## What everything worn gives body_heat.gd as warmth, wet as one is now (its
## own limit 1.2 still holds). Dry and new, what everyone goes out in gives 0.8.
static func warmth(p, wet: float) -> float:
	var w := 0.0
	for g: Dictionary in worn_list(p):
		var worn_through: float = clampf(float(g.get("wear", 0.0)), 0.0, 1.0)
		w += float(g.get("warmth", 0.0)) * keep_when(String(g.get("id", "")), wet) * (1.0 - WORN_WARMTH_LOSS * worn_through)
	return w


## The outermost layer over the body, {} for none.
static func outer_upper(p) -> Dictionary:
	for i in range(UPPER.size() - 1, -1, -1):
		var g := occupant(p, UPPER[i])
		if not g.is_empty():
			return g
	return {}


## Only the outermost layer over the body stops the wind (body_injury 6장).
static func windproof(p) -> float:
	return float(outer_upper(p).get("windproof", 0.0))


## And keeps the rain off.
static func water(p) -> float:
	return float(outer_upper(p).get("water", 0.0))


## The coat as the dead's hands and the bag list used to see it: the coat over
## the jacket, else the jacket, else nothing (a throwaway bare one).
static func torso_outer(p) -> Dictionary:
	for s: String in ["coat", "jacket"]:
		if p.worn.has(s):
			return p.worn[s]
	return bare_outer()


## Putting a coat on the old way: into its own place, or a bare one clears both.
static func set_torso_outer(p, state: Dictionary) -> void:
	var id: String = String(state.get("id", ""))
	if id == "":
		p.worn.erase("coat")
		p.worn.erase("jacket")
		return
	put_on(p, state)


## Anything heavy on (one heavy or several, the same slowness, body_state.gd).
static func heavy(p) -> bool:
	for g: Dictionary in worn_list(p):
		if bool(g.get("heavy", false)):
			return true
	return false


static func barefoot(p) -> bool:
	return occupant(p, "shoes").is_empty()


## What everyone goes out in weighs this; it is already in the carry limits.
static func default_weight() -> float:
	var w := 0.0
	for s in DEFAULT:
		w += float(KINDS[DEFAULT[s]]["weight"])
	return w


## The load the clothes add: a share of what is worn past what everyone wears.
static func extra_weight(p) -> float:
	var w := 0.0
	for g: Dictionary in worn_list(p):
		w += float(KINDS.get(String(g.get("id", "")), {}).get("weight", 0.0))
	return maxf(0.0, w - default_weight()) * WORN_WEIGHT_SHARE


## How much of a nail or a tooth one garment stops on one part: nothing where
## it does not cover or has a hole; heavy, half (grab_rules.gd); else its own
## block (nails) or bite (teeth), less as it wears.
static func layer_block(g: Dictionary, part: String, bite: bool) -> float:
	if not covers(String(g.get("id", ""))).has(part) or (g.get("holes", {}) as Dictionary).has(part):
		return 0.0
	var b: float = GrabRules.HEAVY_COAT_BLOCK if bool(g.get("heavy", false)) else float(g.get("bite" if bite else "block", 0.0))
	return clampf(b * (1.0 - float(g.get("wear", 0.0))), 0.0, 1.0)


## What covers `part`, outside in.
static func layers(p, part: String) -> Array:
	return layers_in(p.worn, part)


## The same for clothes as a place-by-place dictionary (one of the dead's).
static func layers_in(worn: Dictionary, part: String) -> Array:
	var ranked: Array = []
	for key in worn:
		var g: Dictionary = worn[key]
		var id: String = String(g.get("id", ""))
		if not covers(id).has(part):
			continue
		var rank := OUTSIDE_IN.size()
		for s: String in slots_of(id):
			if (COVERS[s] as Array).has(part) or KINDS[id].has("covers"):
				rank = mini(rank, OUTSIDE_IN.find(s))
		ranked.append([rank, g])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	return ranked.map(func(r: Array) -> Dictionary: return r[1])


## The chance the clothes over `part` stop a nail (or a tooth): each layer in turn.
static func block(p, part: String, bite: bool = false) -> float:
	var through := 1.0
	for g: Dictionary in layers(p, part):
		through *= 1.0 - layer_block(g, part, bite)
	return 1.0 - through


## A nail or a tooth met the clothes over `part` (grab_rules.gd damage_clothing,
## a layer at a time, outside in): each it went through is holed there and
## worn the more, the one that held is holed and worn a little, and what is
## under that is untouched. Comes back with the name of the one that held ("" for none).
static func tear(p, part: String, blocked: bool, bite: bool = false) -> String:
	for g: Dictionary in layers(p, part):
		var held: bool = blocked and layer_block(g, part, bite) > 0.0
		_hole(g, part, GrabRules.COAT_BLOCK_WEAR if held else GrabRules.COAT_HIT_WEAR)
		if held:
			return String(g.get("name", ""))
	return ""


static func _hole(g: Dictionary, part: String, wear: float) -> void:
	var holes: Dictionary = g.get("holes", {})
	holes[part] = true
	g["holes"] = holes
	g["wear"] = minf(1.0, float(g.get("wear", 0.0)) + wear)


## A garment's own stop for a pistol round on `part`: nothing where it does not
## cover or is holed; its bullet value (a vest saved before it had one keeps
## its kind's), less as it wears.
static func layer_bullet(g: Dictionary, part: String) -> float:
	var id: String = String(g.get("id", ""))
	if not covers(id).has(part) or (g.get("holes", {}) as Dictionary).has(part):
		return 0.0
	var b: float = float(g.get("bullet", KINDS.get(id, {}).get("bullet", 0.0)))
	return clampf(b * (1.0 - float(g.get("wear", 0.0))), 0.0, 1.0)


## The chance the clothes over `part` stop a pistol round: only the vest does.
static func bullet_block_in(worn: Dictionary, part: String) -> float:
	var through := 1.0
	for g: Dictionary in layers_in(worn, part):
		through *= 1.0 - layer_bullet(g, part)
	return 1.0 - through


## A pistol round met the clothes over `part`, outside in: each layer it went
## through is holed there and worn the more (as a nail that got through);
## the one that stopped it is worn a little and, more often than not, holed
## there too (SHOT_HOLE_*), what is under it untouched. `rng` is drawn once,
## only when a round was stopped. Comes back with the name of the one that held.
static func shot_in(worn: Dictionary, part: String, blocked: bool, rng: RandomNumberGenerator) -> String:
	for g: Dictionary in layers_in(worn, part):
		if blocked and layer_bullet(g, part) > 0.0:
			g["wear"] = minf(1.0, float(g.get("wear", 0.0)) + GrabRules.COAT_BLOCK_WEAR)
			var bite: float = float(g.get("bite", 0.0))
			if rng.randf() < maxf(SHOT_HOLE_LEAST, 1.0 - bite / SHOT_HOLE_BITE):
				var holes: Dictionary = g.get("holes", {})
				holes[part] = true
				g["holes"] = holes
			return String(g.get("name", ""))
		_hole(g, part, GrabRules.COAT_HIT_WEAR)
	return ""


## Put `state` on in its place (and the places a whole suit takes); what was
## there comes back, each as it was.
static func put_on(p, state: Dictionary) -> Array:
	var off: Array = []
	var slots := slots_of(String(state.get("id", "")))
	if slots.is_empty():
		return off
	for s: String in slots:
		var key := holder_slot(p, s)
		if key != "":
			off.append(p.worn[key])
			p.worn.erase(key)
	p.worn[slots[0]] = state
	return off


## Take off what takes `slot`; it comes back as it was ({} for nothing there).
static func take_off(p, slot: String) -> Dictionary:
	var key := holder_slot(p, slot)
	if key == "":
		return {}
	var g: Dictionary = p.worn[key]
	p.worn.erase(key)
	return g


## The places worn over `slots` in their stacks, each holder once ("" places skipped).
static func _over(p, slots: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for s: String in slots:
		for stack: Array in STACKS:
			var at := stack.find(s)
			if at < 0:
				continue
			for i in range(at + 1, stack.size()):
				var key := holder_slot(p, String(stack[i]))
				if key != "" and not slots.has(key) and not out.has(key):
					out.append(key)
	return out


## How long putting `id` on takes: its own motion, and for each layer over it
## taking that off and putting it back (7장), and taking off a whole suit it
## puts aside elsewhere. Swapping what is in its own place costs nothing more.
static func dress_time(p, id: String) -> float:
	return plan_time(dress_plan(p, id))


## How long taking off what takes `slot` takes, the layers over it off and back on.
static func undress_time(p, slot: String) -> float:
	return plan_time(undress_plan(p, slot))


## The steps of putting `id` on, in order (7장): each layer over its places
## off, the outermost first; what holds another place a whole suit takes off
## and put aside; the garment on in its own place (what was there comes off
## with it); then the layers taken off back on, the innermost first. A layer
## over it worn to rags comes off and stays down (3.3: it is not put on). A
## step is {"op": "off" | "aside" | "on" | "back", "slot", "t" seconds}. Cut
## short, the steps done stay done.
static func dress_plan(p, id: String) -> Array:
	var slots := slots_of(id)
	if slots.is_empty():
		return []
	var aside: Array[String] = []
	for s: String in slots:
		var key := holder_slot(p, s)
		if key != "" and key != slots[0] and not aside.has(key):
			aside.append(key)
	var over: Array[String] = []
	for key: String in _over(p, slots):
		if not aside.has(key):
			over.append(key)
	var plan: Array = _off_steps(p, over)
	for key: String in aside:
		plan.append({"op": "aside", "slot": key, "t": float(TIME[key])})
	plan.append({"op": "on", "slot": slots[0], "t": float(TIME[slots[0]])})
	plan.append_array(_back_steps(p, over))
	return plan


## Taking off what holds `slot`: the layers over it off, it off and put down,
## the layers back on ({"op": "drop"} is the one taken off; rags over it stay down).
static func undress_plan(p, slot: String) -> Array:
	var key := holder_slot(p, slot)
	if key == "":
		return []
	var over := _over(p, slots_of(String((p.worn[key] as Dictionary).get("id", ""))))
	var plan: Array = _off_steps(p, over)
	plan.append({"op": "drop", "slot": key, "t": float(TIME[key])})
	plan.append_array(_back_steps(p, over))
	return plan


## The layers in `over` off, the outermost first: for a while, or put aside
## for good when worn to rags.
static func _off_steps(p, over: Array[String]) -> Array:
	var out: Array = []
	for i in range(over.size() - 1, -1, -1):
		out.append({"op": "off" if wearable(p.worn[over[i]]) else "aside", "slot": over[i], "t": float(TIME[over[i]])})
	return out


## The layers taken off for a while back on, the innermost first.
static func _back_steps(p, over: Array[String]) -> Array:
	var out: Array = []
	for key: String in over:
		if wearable(p.worn[key]):
			out.append({"op": "back", "slot": key, "t": float(TIME[key])})
	return out


## A plan's steps that take a garment off (the motion played backwards).
static func step_off(step: Dictionary) -> bool:
	return ["off", "aside", "drop"].has(String(step.get("op", "")))


## A plan done at a walk: every step on the head, the neck, the face or the hands.
static func plan_walks(plan: Array) -> bool:
	for step: Dictionary in plan:
		if not WALKABLE.has(String(step["slot"])):
			return false
	return not plan.is_empty()


static func plan_time(plan: Array) -> float:
	var t := 0.0
	for step: Dictionary in plan:
		t += float(step["t"])
	return t


## What putting `id` on puts down for good: what holds its places now, and a
## layer over them worn to rags, each once.
static func displaced(p, id: String) -> Array:
	var keys: Array[String] = []
	var out: Array = []
	for s: String in slots_of(id):
		var key := holder_slot(p, s)
		if key != "" and not keys.has(key):
			keys.append(key)
			out.append(p.worn[key])
	for key: String in _over(p, slots_of(id)):
		if not keys.has(key) and not wearable(p.worn[key]):
			keys.append(key)
			out.append(p.worn[key])
	return out


## Not worn through to rags (3.3): it can still be put on.
static func wearable(state: Dictionary) -> bool:
	return float(state.get("wear", 0.0)) < BROKEN_AT


## How long taking `id` off one of the fallen takes, by its weight.
static func strip_time(id: String) -> float:
	return STRIP_PER_WEIGHT * clampf(float(KINDS.get(id, {}).get("weight", 0.0)), STRIP_WEIGHT_LEAST, STRIP_WEIGHT_MOST)


## How much wetter one gets this tick: rain or sleet under the open sky, less
## what the outermost layer keeps off; and sweat, dressed warm and running or at work.
static func wet_gain(p, delta: float, rain: bool, working: bool) -> float:
	var gain := 0.0
	if rain:
		gain += RAIN_WET * (1.0 - clampf(water(p), 0.0, 1.0)) * delta
	var wet: float = float(p.heat.wet)
	if working and wet < SWEAT_MOST and warmth(p, 0.0) > SWEAT_AT:
		gain += minf(SWEAT_RATE * delta, SWEAT_MOST - wet)
	return gain


## The garment's wear in a word, "" for one that does not wear.
static func state_word(state: Dictionary) -> String:
	if not state.has("wear"):
		return ""
	var w: float = float(state["wear"])
	return STATE_WORDS[2] if w >= RAGS_AT else (STATE_WORDS[1] if w >= TORN_AT else STATE_WORDS[0])


## How a kind looks over the body, for the drawing side: where it is drawn
## (torso_outer, head, hands or ""), the shell, a tint (dark and cold) and a pattern.
static func look(id: String) -> Dictionary:
	var k: Dictionary = KINDS.get(id, {})
	var slot: String = String(k.get("slot", ""))
	var where := ""
	if slot == "jacket" or slot == "coat":
		where = "torso_outer"
	elif slot == "head" or slot == "hands":
		where = slot
	return {"look_slot": where, "look_shell": String(k.get("shell", "")), "look_tint": k.get("tint", []), "look_pattern": String(k.get("pattern", "plain"))}


## The shells one person wears over the body: the outermost over the body that
## has one, and what is on the head.
static func shells(p) -> Array[String]:
	var out: Array[String] = []
	for s: String in ["coat", "jacket"]:
		if p.worn.has(s):
			var shell: String = String(KINDS.get(String(p.worn[s].get("id", "")), {}).get("shell", ""))
			if shell != "":
				out.append(shell)
				break
	if p.worn.has("head"):
		var hat_shell: String = String(KINDS.get(String(p.worn["head"].get("id", "")), {}).get("shell", ""))
		if hat_shell != "":
			out.append(hat_shell)
	return out


## Dress `p` the way a squad row says: place by place {slot: id or ""}, or the
## three places of before (outer, head and hands as a yes or no).
static func dress_from(p, d: Dictionary) -> void:
	if d.has("outer") or d.get("hands") is bool:
		if d.has("outer"):
			p.worn.erase("coat")
			p.worn.erase("jacket")
			if String(d["outer"]) != "":
				put_on(p, make(String(d["outer"])))
		if d.has("head"):
			p.hat = make(String(d["head"]))
		if d.get("hands") is bool:
			p.gloves = bool(d["hands"])
		return
	for s in d:
		if not SLOTS.has(String(s)):
			continue
		# A thing out of the wardrobe comes as it is kept there: {id, condition, holes?}.
		if d[s] is Dictionary:
			put_on(p, from_wardrobe(d[s]))
		elif String(d[s]) == "":
			take_off(p, String(s))
		else:
			put_on(p, make(String(d[s])))


## The places the train's wardrobe keeps (train_dom.gd WARDROBE_SLOTS): what comes back of them
## goes on the receipt (s3 contract 3).
const OUTER_PLACES: Array[String] = ["jacket", "coat", "hands"]


## A garment worn made back into a wardrobe entry ({id, condition, holes?}), the other way of
## from_wardrobe; {} for what is not a garment.
static func to_wardrobe(g: Dictionary) -> Dictionary:
	var id: String = String(g.get("id", ""))
	if not is_garment(id):
		return {}
	var e := {"id": id, "condition": snappedf(clampf(1.0 - float(g.get("wear", 0.0)), 0.0, 1.0), 0.01)}
	var holes: Dictionary = g.get("holes", {})
	if not holes.is_empty():
		e["holes"] = holes.duplicate()
	return e


## What `p` comes back in at the wardrobe's places (receipt gearBack.wear): jacket and hands
## each an entry or "" for bare, and a coat only when one is on (picked up in the field).
static func back_of(p) -> Dictionary:
	var out := {}
	for s: String in OUTER_PLACES:
		var e: Dictionary = to_wardrobe(p.worn[s]) if p.worn.has(s) else {}
		if e.is_empty() and s == "coat":
			continue
		out[s] = e if not e.is_empty() else ""
	return out


## A garment as the train's wardrobe keeps it ({id, condition, holes?}, train_dom.gd) made
## into the state worn: its wear is what its condition lacks.
static func from_wardrobe(entry: Dictionary) -> Dictionary:
	var g := make(String(entry.get("id", "")))
	if g.is_empty():
		return g
	g["wear"] = clampf(1.0 - float(entry.get("condition", 1.0)), 0.0, 1.0)
	if not (entry.get("holes", {}) as Dictionary).is_empty():
		g["holes"] = (entry["holes"] as Dictionary).duplicate()
	return g


## What a save keeps of one person's clothes, and how it comes back. A save
## of the three places (#594) comes back as it was; one from before keeps the default.
static func save_of(p) -> Dictionary:
	return {"worn": p.worn.duplicate(true)}


static func restore(p, d: Dictionary) -> void:
	if d.get("worn") is Dictionary:
		var back := {}
		var saved: Dictionary = d["worn"]
		for s in saved:
			if SLOTS.has(String(s)) and saved[s] is Dictionary and is_garment(String((saved[s] as Dictionary).get("id", ""))):
				back[String(s)] = (saved[s] as Dictionary).duplicate(true)
		p.worn = back
		return
	if d.get("outer") is Dictionary and not (d["outer"] as Dictionary).is_empty():
		p.worn.erase("coat")
		p.worn.erase("jacket")
		var outer: Dictionary = (d["outer"] as Dictionary).duplicate(true)
		if is_garment(String(outer.get("id", ""))):
			put_on(p, outer)
	if d.get("head") is Dictionary:
		p.hat = (d["head"] as Dictionary).duplicate(true)
	if d.has("hands"):
		p.gloves = bool(d["hands"])
