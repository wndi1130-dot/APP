extends RefCounted
## Pure rules for what the fallen carry and what the places hold (loot spec
## v1). The values are in loot_tables.gd. Nothing in the game calls these yet:
## swapping zombies.gd's pockets and filling the first stop's containers are
## value changes of their own, shown with numbers before they go in.
##
## Rolled once: pockets when one first goes down, containers when the map is
## made, from the run's seed. Same seed, same stop.

const T = preload("res://game/sim/loot_tables.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")


static func _values(set_name: String) -> Dictionary:
	return T.SETS.get(set_name, T.SETS["base"])


## Which pocket table a fallen one uses: a padded one or one of the dead by
## where it lies, anything without a table of its own as the dead.
static func body_key(kind: String, place: String = "") -> String:
	if kind == "clothed" and T.BODY.has("clothed_" + place):
		return "clothed_" + place
	if kind == "dead" and place != "" and T.BODY.has("dead_" + place):
		return "dead_" + place
	return kind if T.BODY.has(kind) else "dead"


static func body_chance(kind: String, place: String = "", in_horde: bool = false, set_name: String = "base") -> float:
	var key := body_key(kind, place)
	var s := _values(set_name)
	var c: float = float(s["clothed_chance"]) if key.begins_with("clothed") else float(T.BODY[key]["chance"]) * float(s["body_chance"])
	if in_horde:
		c *= float(s["horde_mult"])
	return clampf(c, 0.0, 1.0)


## Seconds it takes to go through one's pockets.
static func body_search_time(kind: String, place: String = "") -> float:
	return float(T.BODY[body_key(kind, place)]["search"])


## One fallen one's pockets: a list of entries with "n". The dice are drawn in
## the order the pockets use today (chance, row, count), so the dead roll the
## same things from the same seed as before.
static func body_roll(kind: String, place: String, in_horde: bool, rng: RandomNumberGenerator, set_name: String = "base") -> Array:
	var row: Dictionary = T.BODY[body_key(kind, place)]
	var chance := body_chance(kind, place, in_horde, set_name)
	var out: Array = []
	for i in range(int(row["rolls"])):
		if rng.randf() >= chance:
			continue
		var pick: Array = _pick(row["table"], rng.randi_range(1, _total(row["table"])))
		var entry: Dictionary = (pick[1] as Dictionary).duplicate()
		entry["n"] = rng.randi_range(1, int(pick[2]))
		# A bundle gets its name from the dice as they stand, drawing none of them.
		if entry.has("id"):
			entry["id"] = LootDress.name_pocket(String(entry["id"]), rng.state)
		out.append(entry)
	return out


## The place tag of a fallen one lying at cell, from the map's buildings: the
## named buildings first (where a padded one worked), then by the words of a
## building's name (decision 423, P08).
static func place_at(buildings: Array, cell: Vector2i) -> String:
	for b: Dictionary in buildings:
		if not T.PLACE_OF_BUILDING.has(String(b.get("name", ""))):
			continue
		if (b["rect"] as Rect2i).grow(T.PLACE_REACH).has_point(cell):
			return String(T.PLACE_OF_BUILDING[b["name"]])
	for b: Dictionary in buildings:
		if not b.has("rect") or not (b["rect"] as Rect2i).grow(T.PLACE_REACH).has_point(cell):
			continue
		var place := place_of_name(String(b.get("name", "")))
		if place != "":
			return place
	return ""


## The place a building's name says ("" for none of PLACE_WORDS).
static func place_of_name(building_name: String) -> String:
	for place: String in T.PLACE_ORDER:
		for w: String in T.PLACE_WORDS[place]:
			if building_name.contains(w):
				return place
	return ""


## A rolled entry in the shape the pockets hold (field_actions reads "ammo",
## "weapon" or "id"): a tool becomes a worn weapon in hand form.
static func to_pocket(entry: Dictionary) -> Dictionary:
	if not entry.has("tool"):
		return entry
	var id := String(entry["tool"])
	return {"id": id, "n": 1, "weapon": {"id": id, "quality": "factory", "condition": T.TOOL_CONDITION, "loaded": 0}}


## The kind a container is folded into by its name, "" if none.
static func container_kind(container_name: String) -> String:
	for kind in T.KIND_ORDER:
		for word: String in T.CONTAINER_KINDS[kind]["words"]:
			if container_name.contains(word):
				return kind
	return ""


static func container_rng(seed: int, id: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d:%s" % [seed, id]).hash()
	return rng


static func _rows(kind: String, set_name: String) -> Array:
	var rows: Array = (T.CONTAINER_KINDS[kind]["table"] as Array).duplicate()
	var blank: int = int(_values(set_name)["blank"])
	if blank > 0:
		rows.append([blank, "", 0])
	return rows


static func container_rolls(kind: String, set_name: String = "base") -> int:
	return int(T.CONTAINER_KINDS[kind]["rolls"]) + (1 if (_values(set_name)["extra_rolls"] as Array).has(kind) else 0)


## What one container of this kind holds, rolled from the seed and its id.
static func container_roll(kind: String, seed: int, id: String, set_name: String = "base") -> Array:
	var rng := container_rng(seed, id)
	var rows := _rows(kind, set_name)
	var total := _total(rows)
	var items: Array = []
	for i in range(container_rolls(kind, set_name)):
		var pick: Array = _pick(rows, rng.randi_range(1, total))
		for k in range(int(pick[2])):
			items.append(pick[1])
	return items


## Fill a map's containers in place. The fixed ones keep their things (and
## roll their "plus" kind on top), a stop's goal boxes ("pick") and the ones
## whose name folds into no kind are left as they are. Locks are not rolled.
## Returns how many were rolled.
static func fill(containers: Dictionary, seed: int, set_name: String = "base") -> int:
	var n := 0
	for id: String in containers:
		var c: Dictionary = containers[id]
		if c.has("pick"):
			continue
		if T.FIXED.has(id):
			var fixed: Dictionary = T.FIXED[id]
			var items: Array = (fixed["items"] as Array).duplicate()
			if fixed.has("plus"):
				items.append_array(container_roll(String(fixed["plus"]), seed, id, set_name))
				n += 1
			c["items"] = items
			continue
		var kind := container_kind(String(c.get("name", "")))
		if kind == "":
			continue
		c["items"] = container_roll(kind, seed, id, set_name)
		n += 1
	return n


## Expected count of each item in one container of this kind.
static func expected_container(kind: String, set_name: String = "base") -> Dictionary:
	var rows := _rows(kind, set_name)
	var total := float(_total(rows))
	var rolls := float(container_rolls(kind, set_name))
	var out: Dictionary = {}
	for r: Array in rows:
		if String(r[1]) == "":
			continue
		out[r[1]] = float(out.get(r[1], 0.0)) + rolls * float(r[0]) / total * float(r[2])
	return out


## Expected count of each pocket entry ("id", "ammo:<kind>" or "tool:<id>") on one fallen one.
static func expected_body(kind: String, place: String = "", in_horde: bool = false, set_name: String = "base") -> Dictionary:
	var row: Dictionary = T.BODY[body_key(kind, place)]
	var rows: Array = row["table"]
	var total := float(_total(rows))
	var each := body_chance(kind, place, in_horde, set_name) * float(row["rolls"])
	var out: Dictionary = {}
	for r: Array in rows:
		var key := entry_key(r[1])
		out[key] = float(out.get(key, 0.0)) + each * float(r[0]) / total * (1.0 + float(r[2])) / 2.0
	return out


## One name for an entry: the item id, "ammo:pistol", "tool:crowbar".
static func entry_key(entry: Dictionary) -> String:
	if entry.has("ammo"):
		return "ammo:" + String(entry["ammo"])
	if entry.has("tool"):
		return "tool:" + String(entry["tool"])
	return String(entry.get("id", ""))


## How many things are still in a container (left behind when the bag was full).
static func left(container: Dictionary) -> int:
	return (container.get("items", []) as Array).size()


static func _total(rows: Array) -> int:
	var t := 0
	for r: Array in rows:
		t += int(r[0])
	return t


static func _pick(rows: Array, at: int) -> Array:
	for r: Array in rows:
		at -= int(r[0])
		if at <= 0:
			return r
	return rows[rows.size() - 1]
