extends RefCounted
## Odds and ends in the boxes (decision 444, 차이 목록 5; coord\review\좀보이드_잡동사니_대조_20261026.md):
## before the bundles are dealt, each box indoors gets a little of what people
## leave about, from its room's rows. Each row is its own roll (not one picked
## from the table), at most JUNK_MOST a box, on dice of its own, so nothing
## else of the stop changes. The things are light and worth little on the
## train: a choice of weight against a small gain, never a bundle's worth.
##
## Untouched: a stop goal's box, the fixed boxes the story leans on, locked
## ones and boxes in no building (nothing left lying by the train).

const LootTables = preload("res://game/sim/loot_tables.gd")

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


## Put the odds and ends in. rooms: box id -> the room it stands in
## (loot_dress.gd room_of). Returns how many went in.
static func strew(containers: Dictionary, seed: int, rooms: Dictionary) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d:dress:junk" % seed).hash()
	var ids: Array = containers.keys()
	ids.sort()
	var put := 0
	for id: String in ids:
		var c: Dictionary = containers[id]
		if c.has("pick") or LootTables.FIXED.has(id) or bool(c.get("locked", false)) or int(c.get("building", -1)) < 0:
			continue
		var rows: Array = JUNK.get(String(rooms.get(id, "")), [])
		var here := 0
		for row: Array in rows:
			# Every row is rolled, so the dice do not hang on what came before.
			if rng.randf() < float(row[1]) and here < JUNK_MOST:
				var items: Array = (c.get("items", []) as Array).duplicate()
				items.append(String(row[0]))
				c["items"] = items
				here += 1
		put += here
	return put
