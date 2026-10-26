extends RefCounted
## The departure kit from the train's stores (decision 426 PR 5; s3 contract 2): each one goes
## out with what their role takes (field_departure.gd's kits, now a wish list), taken from the
## armory: that very weapon if it is there, else the same kind in the best condition left, else
## that hand stays empty. The train also hands over its rounds (and the workshop's lures once it
## keeps any). A train that keeps no armory or rounds of its own (S1's states: S1 has neither)
## sends the kits as they are and no rounds, so the same state still gives the same sheet.


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
## {ammo: {pistol, shell, craft}, lures?}, or {} for a train that keeps no rounds.
static func train_kit(g: Dictionary) -> Dictionary:
	var dom: Variant = g.get("dom")
	if not dom is Dictionary or not dom.has("ammo_pistol"):
		return {}
	var out := {"ammo": {"pistol": int(dom.get("ammo_pistol", 0)), "shell": int(dom.get("ammo_shell", 0)), "craft": int(dom.get("ammo_craft", 0))}}
	if dom.has("lures"):
		out["lures"] = int(dom["lures"])
	return out
