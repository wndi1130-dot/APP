extends RefCounted
## Everyday supplies (decision 490), appended after all other dressing rolls.

const LootTables = preload("res://game/sim/loot_tables.gd")
const LootJunk = preload("res://game/sim/loot_junk.gd")
const Carry = preload("res://game/sim/carry.gd")

## [item, chance, where] rows, using LootDress.room_of's room names. A room it cannot
## read is "storage", so a school's unnamed rooms take the "school" rows there.
const ROWS: Dictionary = {
	"bathroom": [["toilet_paper", 0.30, "any"], ["soap", 0.25, "any"], ["razor", 0.10, "lived"]],
	"bedroom": [["old_clothes", 0.10, "lived"], ["book", 0.08, "lived"], ["candle", 0.06, "lived"], ["sewing_kit", 0.05, "home"], ["child_clothes", 0.04, "kids"], ["toy", 0.04, "kids"]],
	"kitchen": [["candle", 0.03, "lived"], ["soap", 0.02, "lived"]],
	"pantry": [["candle", 0.05, "lived"]],
	"shop": [["toilet_paper", 0.10, "shop"], ["soap", 0.10, "shop"], ["candle", 0.08, "shop"], ["razor", 0.05, "shop"], ["sewing_kit", 0.04, "shop"]],
	"office": [["book", 0.05, "any"], ["toy", 0.03, "kids"]],
	"storage": [["old_clothes", 0.04, "lived"], ["candle", 0.03, "any"], ["book", 0.06, "school"], ["toy", 0.04, "school"], ["child_clothes", 0.03, "school"]],
	"clinic": [["soap", 0.08, "any"]],
	"hall": [["candle", 0.06, "any"], ["book", 0.04, "any"]],
}
const MOST: int = 1
## Every row's chance is scaled by this, so a house stop searched to its last box melts to
## about 5 supplies (S1 SUP_YIELD.houses; the median over the seven house maps' expected
## values, which run 2.4 to 7.4 by map size). A house gives the same in any stop's map.
const YIELD: float = 0.72
const HOME_KINDS: Array[String] = ["house", "farm", "fish"]
## Where people stayed that loot_kind does not tell: read from the name once, into the
## building's "stay_kind" key (LootDress.name_keys), and read from the key after (J06).
const STAY_WORDS: Dictionary = {"school": ["학교", "분교"], "inn": ["여관", "여인숙", "호텔", "하숙", "기숙사"]}


static func stay_kind(name: String) -> String:
	for kind: String in ["school", "inn"]:
		for word: String in STAY_WORDS[kind]:
			if name.contains(word):
				return kind
	return ""


## Each row rolls even when its building, the box's cap or what the box still takes
## (carry.gd box_room, as the deal keeps to) keeps it out.
static func strew(containers: Dictionary, seed: int, rooms: Dictionary, buildings: Array) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d:dress:supplies" % seed).hash()
	var ids: Array = containers.keys()
	ids.sort()
	var in_room: Dictionary = {}
	for id: String in ids:
		if _strewn(id, containers[id]):
			var key := _room_key(containers[id], rooms, id)
			in_room[key] = int(in_room.get(key, 0)) + 1
	# Loaded at call time to avoid a preload cycle with LootDress.
	var loot_dress = load("res://game/sim/loot_dress.gd")
	var put := 0
	for id: String in ids:
		var c: Dictionary = containers[id]
		if not _strewn(id, c):
			continue
		var room := String(rooms.get(id, ""))
		var rows: Array = ROWS.get(room, [])
		var share := minf(1.0, float(LootJunk.ROOM_BOXES.get(room, 1)) / float(maxi(1, int(in_room[_room_key(c, rooms, id)]))))
		var kind: String = loot_dress._building_kind_of(buildings, c)
		var b := int(c.get("building", -1))
		var stay := ""
		if b >= 0 and b < buildings.size():
			var bd: Dictionary = buildings[b]
			stay = String(bd["stay_kind"]) if bd.has("stay_kind") else stay_kind(String(bd.get("name", "")))
		var here := 0
		for row: Array in rows:
			var rolled := rng.randf()
			if rolled < float(row[1]) * YIELD * share and here < MOST and _fits(String(row[2]), kind, stay) and Carry.box_room(c, String(row[0])) > 0:
				var items: Array = (c.get("items", []) as Array).duplicate()
				items.append(String(row[0]))
				c["items"] = items
				here += 1
		put += here
	return put


static func _strewn(id: String, c: Dictionary) -> bool:
	return not (c.has("pick") or LootTables.FIXED.has(id) or bool(c.get("locked", false)) or int(c.get("building", -1)) < 0 or bool(c.get("searched", false)))


static func _room_key(c: Dictionary, rooms: Dictionary, id: String) -> String:
	return "%d|%s" % [int(c.get("building", -1)), String(rooms.get(id, ""))]


static func _fits(where: String, kind: String, stay: String) -> bool:
	match where:
		"any":
			return true
		"home":
			return HOME_KINDS.has(kind)
		"lived":
			return HOME_KINDS.has(kind) or stay != ""
		"kids":
			# A dormitory reads as a house by its name and as an inn by its stay key: grown-ups only.
			return (HOME_KINDS.has(kind) and stay != "inn") or stay == "school"
		"school":
			return stay == "school"
		"shop":
			return kind in ["grocery", "pharmacy"]
	return false
