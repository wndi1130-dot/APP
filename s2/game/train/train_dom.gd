extends RefCounted
## The train's stores under the S1 domestic branch's own key (DomState in
## s1/src/game/domestic/state.ts): what the field brings home lands here while
## the domestic rules are not ported yet (decision 426, PR 1). A dom that holds
## stores only carries no rule state, so the S1a rules still read the game as
## S1a (train_state.gd is_s1a) and nothing a domestic rule would give opens.
##
## S1's names where S1 has the store (scrap, wood, parts, cores, frags by
## field); the receipt's own names for the ones only the field fills so far
## (cloth, and the three ammo stocks as sim/receipt.gd STOCK_KEYS spells them);
## the armory holds weapons as the field carries them: id, quality, condition.

const Weapons = preload("res://game/sim/weapons.gd")

const AMOUNTS: Array[String] = ["scrap", "wood", "parts", "cores", "cloth", "ammo_pistol", "ammo_shell", "ammo_craft"]
## S1's Field, the receipt's FRAGMENT_KINDS.
const FIELDS: Array[String] = ["engine", "med", "craft", "radio", "expedition"]


## Empty stores: every amount 0, no fragments, nothing in the armory.
static func empty() -> Dictionary:
	var frags := {}
	for f: String in FIELDS:
		frags[f] = 0
	var d := {"frags": frags, "armory": []}
	for key: String in AMOUNTS:
		d[key] = 0
	return d


## A dom holding stores and nothing else: only these keys, each amount a
## number not under 0, fragments by field, the armory a list of weapons.
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
		else:
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


static func _amount(v: Variant) -> bool:
	return (v is float or v is int) and float(v) >= 0.0
