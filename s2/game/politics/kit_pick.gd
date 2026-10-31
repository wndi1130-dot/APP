extends RefCounted
## The departure kit from the train's stores (decision 426 PR 5; s3 contract 2): each one goes
## out with what their role takes (field_departure.gd's kits, now a wish list), taken from the
## armory: that very weapon if it is there, else the same kind in the best condition left, else
## that hand stays empty. The train also hands over its rounds (and the workshop's lures once it
## keeps any). A train that keeps no armory or rounds of its own (S1's states: S1 has neither)
## sends the kits as they are and no rounds, so the same state still gives the same sheet.
## The chief and the companions are dressed out of the wardrobe the same way (dress).

const Wear = preload("res://game/sim/wear.gd")


## The armory to take from (a copy: taking spends it), or null when the train keeps none.
static func stock_of(g: Dictionary) -> Variant:
	var dom: Variant = g.get("dom")
	if dom is Dictionary and dom.get("armory") is Array:
		return (dom["armory"] as Array).duplicate(true)
	return null


## `gear` with its hands taken from `stock` (spent as they are taken); as it is when the
## train keeps no armory.
static func kit(gear: Dictionary, stock: Variant) -> Dictionary:
	var out := gear.duplicate(true)
	if stock == null:
		return out
	var hands: Array = []
	for want: Array in gear["hands"]:
		var at := _find(stock, want)
		if at < 0:
			continue
		var w: Dictionary = stock[at]
		hands.append([String(w["id"]), String(w["quality"]), float(w["condition"])])
		stock.remove_at(at)
	out["hands"] = hands
	return out


## Where in `stock` the wanted [id, quality, condition] is: the very one, else the same id in
## the best condition, else -1.
static func _find(stock: Array, want: Array) -> int:
	var best := -1
	for i in stock.size():
		var w: Dictionary = stock[i]
		if String(w["id"]) != String(want[0]):
			continue
		if String(w["quality"]) == String(want[1]) and is_equal_approx(float(w["condition"]), float(want[2])):
			return i
		if best < 0 or float(w["condition"]) > float(stock[best]["condition"]):
			best = i
	return best


## What the train hands the field to shoot and lure with, for the contract's train block:
## {ammo: {pistol, shell, craft}, lures?, sleds?}, or {} for a train that keeps nothing to hand.
## Lures go only when there are some: the stores always count them now (the
## workshop makes them, decision 449), and none kept is none handed over.
static func train_kit(g: Dictionary) -> Dictionary:
	var dom: Variant = g.get("dom")
	if not dom is Dictionary:
		return {}
	var out := {}
	if dom.has("ammo_pistol"):
		out["ammo"] = {"pistol": int(dom.get("ammo_pistol", 0)), "shell": int(dom.get("ammo_shell", 0)), "craft": int(dom.get("ammo_craft", 0))}
		if int(dom.get("lures", 0)) > 0:
			out["lures"] = int(dom["lures"])
	# The workshop's load sleds (two at most, sled.md 94), not taken from the stores either,
	# whether or not the train keeps rounds.
	if int(dom.get("sleds", 0)) > 0:
		out["sleds"] = int(dom["sleds"])
	return out


## What everyone goes out in over their own underthings (decision 443, card E 가): the railway
## coat and the gloves, by the place they are worn.
const OUTER_WISH: Dictionary = {"jacket": "jacket_short", "hands": "gloves"}


## The wardrobe to take from (a copy: taking spends it), or null when the train keeps none.
static func closet_of(g: Dictionary) -> Variant:
	var dom: Variant = g.get("dom")
	if dom is Dictionary and dom.get("wardrobe") is Array:
		return (dom["wardrobe"] as Array).duplicate(true)
	return null


## `gear` dressed out of `closet` (spent as taken): for each place of OUTER_WISH the wished
## thing in the best condition left, else anything for that place in the best condition, else
## that place goes bare ("": dress_from takes it off). As it is when the train keeps no
## wardrobe. The work crew is not dressed out of it (443: they go in what everyone wears).
static func dress(gear: Dictionary, closet: Variant) -> Dictionary:
	var out := gear.duplicate(true)
	if closet == null:
		return out
	var wear: Dictionary = out.get("wear", {})
	for slot: String in OUTER_WISH:
		var at := _garment(closet, slot, String(OUTER_WISH[slot]))
		if at < 0:
			wear[slot] = ""
			continue
		wear[slot] = (closet[at] as Dictionary).duplicate(true)
		closet.remove_at(at)
	out["wear"] = wear
	return out


## Where in `closet` a thing for `slot` is: the wished id in the best condition, else any for
## that place in the best condition, else -1.
static func _garment(closet: Array, slot: String, wish: String) -> int:
	var best := -1
	var best_any := -1
	for i in closet.size():
		var c: Dictionary = closet[i]
		var id: String = String(c.get("id", ""))
		if Wear.slot_of(id) != slot:
			continue
		if best_any < 0 or float(c["condition"]) > float(closet[best_any]["condition"]):
			best_any = i
		if id == wish and (best < 0 or float(c["condition"]) > float(closet[best]["condition"])):
			best = i
	return best if best >= 0 else best_any
