extends RefCounted
## The train's stores under the S1 domestic branch's own key (DomState in
## s1/src/game/domestic/state.ts): what the field brings home lands here
## (decision 426, PR 1), and the workshop and research (PR 3, PR 6) keep their
## state beside it. The rest of S1's domestic branch is not ported, so a dom of
## this subset still reads as S1a (train_state.gd is_s1a) and no other
## domestic rule opens.
##
## S1's names where S1 has the store (scrap, wood, parts, cores, frags by
## field); the receipt's own names for the ones only the field fills so far
## (cloth, and the three ammo stocks as sim/receipt.gd STOCK_KEYS spells them);
## the armory holds weapons as the field carries them: id, quality, condition.

const Weapons = preload("res://game/sim/weapons.gd")

const AMOUNTS: Array[String] = ["scrap", "wood", "parts", "cores", "cloth", "ammo_pistol", "ammo_shell", "ammo_craft"]
## S1's Field, the receipt's FRAGMENT_KINDS.
const FIELDS: Array[String] = ["engine", "med", "craft", "radio", "expedition"]
## What the wardrobe can hold: the long coat the workshop makes (decision 070).
## The field's own clothes table takes this over when it comes.
const WEARABLES: Array[String] = ["coat_long"]
## The train's stores at the start of a run (S1 domestic/data.ts D.scrap0, wood0, parts0).
const START: Dictionary = {"scrap": 10, "wood": 10, "parts": 4}
const START_FRAGS: Dictionary = {"engine": 1, "med": 1}
## S1's eight specialties; first unused community names in PROFILES order.
const START_EXPERTS: Array = [
	{
		"name": "킨가 자크",
		"comm": "engine",
		"field": "engine",
		"skill": 3
	},
	{
		"name": "보이테흐 포스피실",
		"comm": "engine",
		"field": "engine",
		"skill": 1
	},
	{
		"name": "빅토리야 트카첸코",
		"comm": "medtech",
		"field": "med",
		"skill": 3
	},
	{
		"name": "레오나르도 숄츠",
		"comm": "front",
		"field": "med",
		"skill": 1
	},
	{
		"name": "솔로미야 트카첸코",
		"comm": "medtech",
		"field": "craft",
		"skill": 3
	},
	{
		"name": "알기르다스 유레비추스",
		"comm": "tail",
		"field": "craft",
		"skill": 1
	},
	{
		"name": "라우라 크뤼거",
		"comm": "guard",
		"field": "radio",
		"skill": 2
	},
	{
		"name": "도미니크 슐츠",
		"comm": "guard",
		"field": "expedition",
		"skill": 2
	}
]
const TECH_IDS: Array[String] = ["e1", "e2", "e3", "e4", "e5", "m1", "m2", "m3", "m4", "m5", "w1", "w2", "w3", "w4", "r1", "r2", "r3", "r4", "x1", "x2", "x3"]


## Empty stores: every amount 0, no fragments, nothing in the armory or the wardrobe.
static func empty() -> Dictionary:
	var frags := {}
	for f: String in FIELDS:
		frags[f] = 0
	var d := {"frags": frags, "armory": [], "wardrobe": []}
	for key: String in AMOUNTS:
		d[key] = 0
	return d


## The stores a new run starts with: S1's starting scrap, wood and parts.
static func start() -> Dictionary:
	var d := empty()
	for key: String in START:
		d[key] = START[key]
	for field: String in START_FRAGS:
		d["frags"][field] = START_FRAGS[field]
	d["techs"] = {}
	d["restoring"] = null
	d["experts"] = START_EXPERTS.duplicate(true)
	return d


## The S2-ported domestic subset: stores, workshop and PR 6 research only.
## S1a hooks remain off; people/manuals/classroom and all other keys reject it.
static func is_store(dom: Variant) -> bool:
	if not dom is Dictionary:
		return false
	for key: Variant in dom:
		var v: Variant = dom[key]
		if AMOUNTS.has(key):
			if not _amount(v):
				return false
		elif key == "frags":
			if not v is Dictionary:
				return false
			for f: Variant in v:
				if not FIELDS.has(f) or not _amount(v[f]):
					return false
		elif key == "armory":
			if not v is Array:
				return false
			for w: Variant in v:
				if not is_weapon(w):
					return false
		elif key == "wardrobe":
			if not v is Array:
				return false
			for c: Variant in v:
				if not is_wearable(c):
					return false
		elif key == "target":
			# The workshop's parts target (train_workshop.gd).
			if not (v is int or v is float) or float(v) < 0.0 or float(v) > 10.0:
				return false
		elif key == "partWork":
			if not (v is int or v is float) or float(v) < 0.0 or float(v) > 1.0:
				return false
		elif key == "make":
			if v != null and not is_line(v):
				return false
		elif key == "techs":
			if not v is Dictionary:
				return false
			for id: Variant in v:
				if not TECH_IDS.has(id) or not is_tech(v[id]):
					return false
		elif key == "restoring":
			if v != null and (not v is String or not TECH_IDS.has(v)):
				return false
		elif key == "experts":
			if not v is Array:
				return false
			for expert: Variant in v:
				if not is_expert(expert):
					return false
		else:
			return false
	return true


static func is_expert(v: Variant) -> bool:
	if not v is Dictionary or v.size() != 4:
		return false
	if not v.get("name") is String or String(v["name"]).is_empty() or not FIELDS.has(v.get("field")):
		return false
	if v.get("comm") not in ["engine", "medtech", "front", "tail", "guard"]:
		return false
	var skill: Variant = v.get("skill")
	return _amount(skill) and float(skill) <= 3.0 and float(skill) == floorf(float(skill))


static func is_tech(v: Variant) -> bool:
	if not v is Dictionary or v.get("stage") not in ["restoring", "defective", "done"]:
		return false
	if not v.get("defect") is bool or not _amount(v.get("progress")) or not _amount(v.get("need")):
		return false
	for key: Variant in v:
		if key in ["stage", "defect", "progress", "need"]:
			continue
		if key == "variant":
			if v[key] not in ["a", "b"]:
				return false
		elif key in ["finishing", "starved", "off", "pending"]:
			if not v[key] is bool:
				return false
		else:
			return false
	return true


## One wardrobe entry: a thing the wardrobe knows and a condition from 0 to 1.
static func is_wearable(c: Variant) -> bool:
	if not c is Dictionary or c.size() != 2:
		return false
	var id: Variant = c.get("id")
	var condition: Variant = c.get("condition")
	return id is String and WEARABLES.has(id) and (condition is float or condition is int) \
		and float(condition) >= 0.0 and float(condition) <= 1.0


## What is on the workshop's line (train_workshop.gd): {id, progress, need, paid}.
static func is_line(m: Variant) -> bool:
	if not m is Dictionary or m.size() != 4:
		return false
	var paid: Variant = m.get("paid")
	if not m.get("id") is String or not paid is Dictionary:
		return false
	for k: Variant in [m.get("progress"), m.get("need")]:
		if not (k is int or k is float) or float(k) < 0.0:
			return false
	for key: Variant in paid:
		if not AMOUNTS.has(key) or not _amount(paid[key]):
			return false
	return true


## One armory entry: a weapon the field knows, a quality it knows, a
## condition from 0 to 1.
static func is_weapon(w: Variant) -> bool:
	if not w is Dictionary or w.size() != 3:
		return false
	var id: Variant = w.get("id")
	var quality: Variant = w.get("quality")
	var condition: Variant = w.get("condition")
	return id is String and Weapons.DATA.has(id) and quality is String and Weapons.QUALITY.has(quality) \
		and (condition is float or condition is int) and float(condition) >= 0.0 and float(condition) <= 1.0


## The domestic rules are on: a dom with more than stores (S1's whole DomState).
static func rules_on(g: Dictionary) -> bool:
	var dom: Variant = g.get("dom")
	return dom is Dictionary and not is_store(dom)


## A state with no dom (a new game from the S1a sample, an older save) gets
## the empty stores; one that has a dom keeps it as it is.
static func ensure(g: Dictionary) -> void:
	if g.get("dom") == null:
		g["dom"] = empty()


## A stop receipt's fragments and cores into the stores (S1 stop_receipt.ts
## applyStopResult: a fragment for each field entry, the cores by count). The
## slice calls it once a stop is back (_after_return). Refused (false, nothing
## changed) when the extras are not that shape.
static func take_extras(g: Dictionary, extras: Variant) -> bool:
	if not extras is Dictionary:
		return false
	var found: Variant = extras.get("fragments", [])
	var cores: Variant = extras.get("coreCount", 0)
	if not found is Array or not _amount(cores) or float(cores) != floorf(float(cores)):
		return false
	for f: Variant in found:
		if not FIELDS.has(f):
			return false
	ensure(g)
	var d: Dictionary = g["dom"]
	for f: String in found:
		d["frags"][f] = float(d["frags"].get(f, 0)) + 1.0
	if float(cores) > 0.0:
		d["cores"] = float(d.get("cores", 0)) + float(cores)
	return true


static func _amount(v: Variant) -> bool:
	return (v is float or v is int) and float(v) >= 0.0
