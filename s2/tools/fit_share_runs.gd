extends SceneTree
## Where the right things lie (decision 442, loot_dress.gd FURNITURE_PULL), the one count for it:
## the 6 house maps, seeds 1..20 each, dressed. For each room, the things of its family (FIT
## below) and how many lie in its fitting furniture, against how many of the room's boxes that
## furniture is; and the things that lie in a room (of its building) with no fitting furniture at
## all, which no pull can move. Clothes count as cloth. Boxes of no building and the picked
## ones are left out.
## -- <out.md>

const FieldMaps = preload("res://game/world/field_maps.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const FieldItems = preload("res://game/sim/field_items.gd")

const MAPS: Array[String] = ["houses_01", "houses_02", "houses_03", "houses_04", "houses_05", "houses_06"]
const SEEDS: int = 20
## room -> [family, the fitting furniture]
const FIT: Dictionary = {
	"bedroom": ["cloth", ["wardrobe", "dresser", "blanket_chest"]],
	"kitchen": ["food", ["cupboard", "jar_shelf", "tin_crate"]],
	"bathroom": ["med", ["medicine_cabinet"]],
}
const NAMES: Dictionary = {"bedroom": "침실(거실 포함) 천·옷", "kitchen": "부엌 먹을 것", "bathroom": "욕실 약"}


static func family(item: String) -> String:
	if FieldItems.has(item) and FieldItems.Wear.KINDS.has(item):
		return "cloth"
	var from := String(FieldItems.row(item).get("from", item)) if FieldItems.has(item) else item
	return String(LootDress.FAMILY.get(from, ""))


## {room: {things, fit, boxes, fit_boxes, in_fit_room, in_fit_room_fit}} over the maps and seeds.
static func count(seeds: int = SEEDS) -> Dictionary:
	var t := {}
	for room in FIT:
		t[room] = {"things": 0, "fit": 0, "boxes": 0, "fit_boxes": 0, "in_fit_room": 0, "in_fit_room_fit": 0}
	for place in MAPS:
		if not ResourceLoader.exists(FieldMaps.MAP_DIR + place + ".gd"):
			continue
		var base := FieldMaps.build(place)
		for seed in range(1, seeds + 1):
			var d: Dictionary = base.duplicate(true)
			LootDress.dress(d, seed)
			var fitting := {}   # building|room -> fitting boxes
			for id: String in d["containers"]:
				var c: Dictionary = d["containers"][id]
				var room := LootDress.room_of(c)
				if int(c.get("building", -1)) < 0 or c.has("pick") or not FIT.has(room):
					continue
				var key := "%d|%s" % [int(c["building"]), room]
				fitting[key] = int(fitting.get(key, 0)) + int(_fits(c, room))
				t[room]["boxes"] += 1
				t[room]["fit_boxes"] += int(_fits(c, room))
			for id: String in d["containers"]:
				var c: Dictionary = d["containers"][id]
				var room := LootDress.room_of(c)
				if int(c.get("building", -1)) < 0 or c.has("pick") or not FIT.has(room):
					continue
				var key := "%d|%s" % [int(c["building"]), room]
				for item in c["items"]:
					if family(String(item)) != String(FIT[room][0]):
						continue
					t[room]["things"] += 1
					t[room]["fit"] += int(_fits(c, room))
					if int(fitting[key]) > 0:
						t[room]["in_fit_room"] += 1
						t[room]["in_fit_room_fit"] += int(_fits(c, room))
	return t


static func _fits(c: Dictionary, room: String) -> bool:
	return (FIT[room][1] as Array).has(String(c.get("furniture", "")))


static func _pct(a: int, b: int) -> String:
	return "%d/%d (%.0f%%)" % [a, b, 100.0 * a / b] if b > 0 else "0/0"


func _initialize() -> void:
	var out_path: String = OS.get_cmdline_user_args()[0]
	var t := count()
	var lines: PackedStringArray = []
	lines.append("# 맞는 가구 몫 (집 지도 6장 × 씨앗 %d)\n" % SEEDS)
	lines.append("셈: 침실(거실 포함) 천 꾸러미·옷 → 옷장·서랍장·궤, 부엌 먹을 것 → 찬장·식료 선반·통조림 궤, 욕실 약 → 약장. 맞는 가구 몫 = 그 방 물건 중 맞는 가구에 든 것, 상자 몫 = 그 방 상자 중 맞는 가구, 맞는 가구 있는 방 = 같은 건물 그 방에 맞는 가구가 하나라도 있는 곳.\n")
	lines.append("|방·물건|맞는 가구 몫|상자 몫|맞는 가구 있는 방에 든 것|그 안에서 맞는 가구 몫|")
	lines.append("|---|---:|---:|---:|---:|")
	for room in FIT:
		var r: Dictionary = t[room]
		lines.append("|%s|%s|%s|%s|%s|" % [NAMES[room], _pct(r["fit"], r["things"]), _pct(r["fit_boxes"], r["boxes"]),
			_pct(r["in_fit_room"], r["things"]), _pct(r["in_fit_room_fit"], r["in_fit_room"])])
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("\n".join(lines))
	quit(0)
