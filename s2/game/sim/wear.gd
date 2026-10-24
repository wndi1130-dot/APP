extends RefCounted
## Clothes in three places (decision 423 card 2): over the body, on the head,
## on the hands. What is worn fills the body-heat inputs (body_heat.gd ctx
## warmth and windproof; its own values are as they were) and the outer one is
## the coat the dead's hands meet (grab_rules.gd, person.gd coat). The warmth
## of all three adds up, only the outer one stops the wind (body_injury 6장).
## A soaked garment keeps only some of its warmth, by what it is made of.
## Putting one on or taking it off is a job of the hands as long as its motion
## (field_actions.gd dress/undress, the clips of #564). A garment taken off lies
## at the feet as it is, worn and torn, the way a weapon does (ground_items
## "garment"); the bag never holds clothes, so a swap through a box cannot mend one.

const SLOTS: Array[String] = ["outer", "head", "hands"]

## Each kind: its place, name, picture, weight (the loot list shows it), warmth,
## and for the outer one windproof, block and heavy (grab_rules.gd: heavy
## stops half the bites on what it covers, and slows, body_state.gd), and what
## it is made of. The look is the id itself: models/people/<own>/wear/<id>
## (person_visual.gd), the gloves a colour picture of the body.
## jacket_short is the coat everyone had before the three places (its numbers
## as they were); gloves give the 0.1 they gave. The rest are new.
const KINDS: Dictionary = {
	"jacket_short": {"slot": "outer", "name": "철도원 외투", "icon": "it_jacket", "weight": 2.0, "warmth": 0.7, "windproof": 0.5, "block": 0.25, "heavy": false, "stuff": "wool"},
	"coat_long": {"slot": "outer", "name": "두꺼운 겉옷", "icon": "it_coat", "weight": 3.0, "warmth": 0.9, "windproof": 0.7, "block": 0.5, "heavy": true, "stuff": "wool"},
	"hat_knit": {"slot": "head", "name": "털모자", "icon": "it_hat", "weight": 0.2, "warmth": 0.1, "stuff": "wool"},
	"hood": {"slot": "head", "name": "두건", "icon": "it_hood", "weight": 0.3, "warmth": 0.05, "stuff": "cotton"},
	"gloves": {"slot": "hands", "name": "장갑", "icon": "it_gloves", "weight": 0.2, "warmth": 0.1, "stuff": "wool"},
}
## How much of its warmth a garment keeps soaked through: wool about half
## (body_injury 6장 「털옷은 젖어도 따뜻함을 반쯤」), cotton next to none (new).
const WET_KEEP: Dictionary = {"wool": 0.5, "cotton": 0.2}
## How long putting one on takes, the length of its motion (#564: p_wear_outer
## 2.4 s, p_wear_head 1.4 s, p_wear_hands 1.8 s); taking it off, the same.
const TIME: Dictionary = {"outer": 2.4, "head": 1.4, "hands": 1.8}
const CLIP: Dictionary = {"outer": "p_wear_outer", "head": "p_wear_head", "hands": "p_wear_hands"}
## What a squad goes out in: the coat and the gloves everyone had, nothing on the head.
const DEFAULT: Dictionary = {"outer": "jacket_short", "hands": "gloves"}
## The coat's state in words (body_injury 6장 멀쩡·해짐·너덜): worn this much and over.
const TORN_AT: float = 0.34
const RAGS_AT: float = 0.67
const STATE_WORDS: Array[String] = ["멀쩡", "해짐", "너덜"]


static func is_garment(id: String) -> bool:
	return KINDS.has(id)


static func slot_of(id: String) -> String:
	return String(KINDS.get(id, {}).get("slot", ""))


## A fresh one, as a person wears it. The outer one has the keys grab_rules.gd
## reads (block, heavy, wear, holes when torn) and body heat reads (warmth,
## windproof): the coat dictionary person.gd always had, with its id.
static func make(id: String) -> Dictionary:
	var k: Dictionary = KINDS.get(id, {})
	if k.is_empty():
		return {}
	var d := {"id": id, "name": String(k["name"]), "warmth": float(k["warmth"])}
	if String(k["slot"]) == "outer":
		d.merge({"windproof": float(k["windproof"]), "block": float(k["block"]), "heavy": bool(k["heavy"]), "wear": 0.0})
	return d


## No coat: nothing between the dead's hands and the arms.
static func bare_outer() -> Dictionary:
	return {"id": "", "name": "", "warmth": 0.0, "windproof": 0.0, "block": 0.0, "heavy": false, "wear": 0.0}


## The share of a garment's warmth left at this wetness (0 dry .. 1 soaked).
static func keep_when(id: String, wet: float) -> float:
	var stuff: String = String(KINDS.get(id, {}).get("stuff", "wool"))
	return 1.0 - clampf(wet, 0.0, 1.0) * (1.0 - float(WET_KEEP.get(stuff, 1.0)))


## What the three places give body_heat.gd as warmth, wet as one is now. Dry,
## the coat and gloves everyone had give 0.7 + 0.1, as before.
static func warmth(p, wet: float) -> float:
	var w: float = float(p.coat.get("warmth", 0.0)) * keep_when(String(p.coat.get("id", "jacket_short")), wet)
	if not p.hat.is_empty():
		w += float(p.hat.get("warmth", 0.0)) * keep_when(String(p.hat.get("id", "")), wet)
	if p.gloves:
		w += float(KINDS["gloves"]["warmth"]) * keep_when("gloves", wet)
	return w


## Only the outer one stops the wind.
static func windproof(p) -> float:
	return float(p.coat.get("windproof", 0.0))


## What is in each place: an id, "" for nothing.
static func worn_ids(p) -> Dictionary:
	return {"outer": String(p.coat.get("id", "")), "head": String(p.hat.get("id", "")), "hands": "gloves" if p.gloves else ""}


## The coat's wear in a word, "" for a place that does not wear.
static func state_word(state: Dictionary) -> String:
	if not state.has("wear"):
		return ""
	var w: float = float(state["wear"])
	return STATE_WORDS[2] if w >= RAGS_AT else (STATE_WORDS[1] if w >= TORN_AT else STATE_WORDS[0])


## Put `state` on in its place; what was there comes back ({} for nothing).
static func put_on(p, state: Dictionary) -> Dictionary:
	var id: String = String(state.get("id", ""))
	match slot_of(id):
		"outer":
			var old: Dictionary = p.coat if String(p.coat.get("id", "")) != "" else {}
			p.coat = state
			return old
		"head":
			var old_hat: Dictionary = p.hat
			p.hat = state
			return old_hat
		"hands":
			var had: bool = p.gloves
			p.gloves = true
			return make("gloves") if had else {}
	return {}


## Take off what is in `slot`; it comes back as it was ({} for nothing there).
static func take_off(p, slot: String) -> Dictionary:
	match slot:
		"outer":
			if String(p.coat.get("id", "")) == "":
				return {}
			var old: Dictionary = p.coat
			p.coat = bare_outer()
			return old
		"head":
			var old_hat: Dictionary = p.hat
			p.hat = {}
			return old_hat
		"hands":
			if not p.gloves:
				return {}
			p.gloves = false
			return make("gloves")
	return {}


## What a save keeps of one person's clothes, and how it comes back.
static func save_of(p) -> Dictionary:
	return {"outer": p.coat.duplicate(true), "head": p.hat.duplicate(true), "hands": p.gloves}


static func restore(p, d: Dictionary) -> void:
	if d.get("outer") is Dictionary and not (d["outer"] as Dictionary).is_empty():
		p.coat = (d["outer"] as Dictionary).duplicate(true)
	if d.get("head") is Dictionary:
		p.hat = (d["head"] as Dictionary).duplicate(true)
	if d.has("hands"):
		p.gloves = bool(d["hands"])
