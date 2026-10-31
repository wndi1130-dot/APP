extends RefCounted
## Odds and ends in the boxes (decision 444, 차이 목록 5):
## before the bundles are dealt, each box indoors gets a little of what people
## leave about, from its room's rows. Each row is its own roll (not one picked
## from the table), at most JUNK_MOST a box, on dice of its own, so nothing
## else of the stop changes. The things are light and worth little on the
## train: a choice of weight against a small gain, never a bundle's worth.
##
## Untouched: a stop goal's box, the fixed boxes the story leans on, locked
## ones and boxes in no building (nothing left lying by the train).

const LootTables = preload("res://game/sim/loot_tables.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldItems = preload("res://game/sim/field_items.gd")

## [item, chance] rows by room (loot_dress.gd room_of). The kitchen more than
## the bedroom, so the bedroom stays the one most often found empty; a store
## room little (a store holds stores, not what people leave about).
const JUNK: Dictionary = {
	"kitchen": [["can_empty", 0.25], ["junk_rag", 0.15], ["junk_paper", 0.10]],
	"pantry": [["can_empty", 0.15], ["junk_paper", 0.10]],
	"bedroom": [["junk_smokes", 0.12], ["junk_paper", 0.08], ["junk_rag", 0.05]],
	"bathroom": [["junk_rag", 0.20]],
	"clinic": [["junk_rag", 0.10], ["junk_paper", 0.05]],
	"toolbox": [["junk_nails", 0.30], ["junk_rag", 0.15]],
	"shop": [["junk_paper", 0.15], ["junk_smokes", 0.08]],
	"office": [["junk_paper", 0.30], ["junk_smokes", 0.10]],
	"hall": [["junk_paper", 0.10]],
	"storage": [["junk_nails", 0.08], ["junk_paper", 0.05]],
}
const JUNK_MOST: int = 2
## How many boxes of a room the odds and ends are reckoned for (card R2, decision
## 469): what a room of its kind holds now, about (the stops' 75th percentile of
## boxes in one room of one building, 2026-10-27). A room with more boxes than
## this does not get more odds and ends — each box's chance shrinks so the room
## keeps what it would have — so cutting a room's furniture into smaller boxes
## does not grow the stop's load.
const ROOM_BOXES: Dictionary = {
	"kitchen": 14, "pantry": 4, "bedroom": 4, "bathroom": 2, "clinic": 3,
	"toolbox": 2, "shop": 2, "office": 4, "hall": 8, "storage": 2,
}
## A looted house (spill_looted): at most this many lie tipped out on its floors,
## each within this of its cell's middle (the reference's 0.2~0.8 of a square).
const SPILL_MOST: int = 4
const SPILL_JITTER: float = 0.3
const LEVEL_H: float = 3.0
## What tips out: the odds and ends of JUNK, nothing a bundle or a find became.
const SPILLS: Dictionary = {"can_empty": true, "junk_rag": true, "junk_paper": true, "junk_smokes": true, "junk_nails": true}


## Put the odds and ends in. rooms: box id -> the room it stands in
## (loot_dress.gd room_of). Returns how many went in.
static func strew(containers: Dictionary, seed: int, rooms: Dictionary) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d:dress:junk" % seed).hash()
	var ids: Array = containers.keys()
	ids.sort()
	# The boxes of each room of each building, so a room's share is spread over them.
	var in_room: Dictionary = {}
	for id: String in ids:
		if _strewn(id, containers[id]):
			var key := _room_key(containers[id], rooms, id)
			in_room[key] = int(in_room.get(key, 0)) + 1
	var put := 0
	for id: String in ids:
		var c: Dictionary = containers[id]
		if not _strewn(id, c):
			continue
		var room := String(rooms.get(id, ""))
		var rows: Array = JUNK.get(room, [])
		var share := minf(1.0, float(ROOM_BOXES.get(room, 1)) / float(maxi(1, int(in_room[_room_key(c, rooms, id)]))))
		var here := 0
		for row: Array in rows:
			# Every row is rolled, so the dice do not hang on what came before.
			if rng.randf() < float(row[1]) * share and here < JUNK_MOST:
				var items: Array = (c.get("items", []) as Array).duplicate()
				items.append(String(row[0]))
				c["items"] = items
				here += 1
		put += here
	return put


static func _strewn(id: String, c: Dictionary) -> bool:
	return not (c.has("pick") or LootTables.FIXED.has(id) or bool(c.get("locked", false)) or int(c.get("building", -1)) < 0)


static func _room_key(c: Dictionary, rooms: Dictionary, id: String) -> String:
	return "%d|%s" % [int(c.get("building", -1)), String(rooms.get(id, ""))]


## What a looted house leaves on its floors (결정 카드 J 가, 차이 7-②). The room
## story 「털린 집」 (room_stories.gd) gathers a house's things into the one box
## it missed and empties the rest; its odds and ends do not all fit in that box:
## up to SPILL_MOST of them lie on the floor by the boxes it emptied, one a
## box, as tipped out. Nothing is added or taken (house_layout.md 4: 양 그대로)
## and the bundles and finds stay in the box that was missed. stories: what
## RoomStories.apply returned. Takes the things out of that box and returns
## them as field_game's ground_items rows [{pos, id, n}].
static func spill_looted(data: Dictionary, stories: Array, seed: int) -> Array:
	var out: Array = []
	var levels: Dictionary = data.get("levels", {})
	var containers: Dictionary = data.get("containers", {})
	for story: Dictionary in stories:
		if String(story.get("story", "")) != "looted":
			continue
		var b := int(story["building"])
		var kept := ""
		var emptied: Array = []
		var ids: Array = containers.keys()
		ids.sort()
		for id: String in ids:
			var box: Dictionary = containers[id]
			var lv := int(box.get("level", 0))
			var cell := _cell(box.get("cell"))
			if cell.x < 0 or not levels.has(lv) or (levels[lv] as FieldGrid).building_at(cell) != b:
				continue
			if bool(box.get("searched", false)) and (box.get("items", []) as Array).is_empty():
				emptied.append(id)
			elif kept == "" and not bool(box.get("searched", false)) and not bool(box.get("locked", false)) \
					and not box.has("pick") and _things(box.get("items", [])) > 0:
				kept = id
		if kept == "" or emptied.is_empty():
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = ("%d:spill:%d" % [seed, b]).hash()
		_shuffle(emptied, rng)
		var items: Array = (containers[kept]["items"] as Array).duplicate()
		var here := 0
		for id: String in emptied:
			if here >= SPILL_MOST:
				break
			var at := -1
			for i in range(items.size()):
				if SPILLS.has(String(items[i])):
					at = i
					break
			# The box that was missed is never left empty by it.
			if at < 0 or _things(items) <= 1:
				break
			var box: Dictionary = containers[id]
			var lv := int(box.get("level", 0))
			var floor_cell := _floor_by(levels[lv], _cell(box.get("cell")), b, rng)
			if floor_cell.x < 0:
				continue
			var pos := FieldGrid.center(floor_cell) + Vector3(rng.randf_range(-SPILL_JITTER, SPILL_JITTER), lv * LEVEL_H, rng.randf_range(-SPILL_JITTER, SPILL_JITTER))
			out.append({"pos": pos, "id": String(items[at]), "n": 1})
			items.remove_at(at)
			here += 1
		containers[kept]["items"] = items
	return out


## What a box holds but the everyday supplies (decision 490, put on last by the dressing):
## the spill reads the box as it was before them, so they change none of what it tips out.
static func _things(items: Array) -> int:
	var n := 0
	for item: Variant in items:
		n += int(FieldItems.group(String(item)) != "supplies")
	return n


## A floor cell beside c, in building b, people can stand on and not a door.
static func _floor_by(g: FieldGrid, c: Vector2i, b: int, rng: RandomNumberGenerator) -> Vector2i:
	var ways: Array = []
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var o := c + d
		if g.inside(o) and g.building_at(o) == b and g.indoor(o) and g.people_can_walk(o) and not g.doors.has(o):
			ways.append(o)
	return Vector2i(-1, -1) if ways.is_empty() else ways[rng.randi_range(0, ways.size() - 1)]


static func _cell(v: Variant) -> Vector2i:
	if v is Vector2i:
		return v
	if v is Array and (v as Array).size() >= 2:
		return Vector2i(int(v[0]), int(v[1]))
	return Vector2i(-1, -1)


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
