extends SceneTree
## Do the boxes of one room hold the same things (ref-ops L1)? Every map (the first stop and
## MAP_DIR's), seed n for the n-th, LootDress.dress as the field does. A room is one building's
## boxes of one room kind; in each room with two boxes or more that hold food (or medicine),
## how many pairs of those boxes share a theme of what they hold (the themes below, fixed here so
## that before and after are read alike), and the named things' weight and kinds in all.
## -- <out.md>

const FieldMaps = preload("res://game/world/field_maps.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const FieldItems = preload("res://game/sim/field_items.gd")

const THEME_OF: Dictionary = {
	"can_beans": "food:tins", "can_meat": "food:tins", "can_dented": "food:tins", "can_dented_bad": "food:tins",
	"jar_cabbage": "food:jars", "jar_jam": "food:jars", "jar_honey": "food:jars",
	"oats": "food:dry", "peas": "food:dry", "flour": "food:dry", "sugar": "food:dry",
	"hardtack": "food:biscuits", "rusk": "food:biscuits",
	"bread_moldy": "food:fresh", "apple_wilted": "food:fresh", "apple": "food:fresh", "meat_spoiled": "food:fresh",
	"meat_frozen": "food:fresh", "fish_frozen": "food:fresh",
	"painkillers": "med:pills", "fever_pills": "med:pills",
	"antiseptic": "med:dressings", "ointment": "med:dressings", "saline": "med:dressings",
	"cough_syrup": "med:syrups", "herbs": "med:syrups",
}


func _initialize() -> void:
	var out_path: String = OS.get_cmdline_user_args()[0]
	var maps: Array[String] = [FieldMaps.DEFAULT_PLACE]
	for kind: String in FieldMaps.KINDS:
		for n in range(1, FieldMaps.MOST_PER_KIND + 1):
			var id := "%s_%02d" % [kind, n]
			if ResourceLoader.exists(FieldMaps.MAP_DIR + id + ".gd"):
				maps.append(id)
	var fam := {"food": {"rooms": 0, "boxes": 0, "pairs": 0, "same": 0, "one_theme": 0},
		"med": {"rooms": 0, "boxes": 0, "pairs": 0, "same": 0, "one_theme": 0}}
	var count := {}
	var weight := 0.0
	var things := 0
	for n in range(1, maps.size() + 1):
		var data := FieldMaps.build(maps[n - 1])
		LootDress.dress(data, n)
		var rooms := {}
		for id: String in data["containers"]:
			var c: Dictionary = data["containers"][id]
			var b := int(c.get("building", -1))
			for item in c.get("items", []):
				var t: String = String(THEME_OF.get(String(item), ""))
				if t == "":
					continue
				count[String(item)] = int(count.get(String(item), 0)) + 1
				weight += FieldItems.weight(String(item))
				things += 1
				if b < 0:
					continue
				var key := "%d|%s|%s" % [b, LootDress.room_of(c), t.get_slice(":", 0)]
				if not rooms.has(key):
					rooms[key] = {}
				if not (rooms[key] as Dictionary).has(id):
					rooms[key][id] = {}
				rooms[key][id][t] = true
		for key: String in rooms:
			var boxes: Dictionary = rooms[key]
			if boxes.size() < 2:
				continue
			var f: Dictionary = fam[key.get_slice("|", 2)]
			f["rooms"] += 1
			f["boxes"] += boxes.size()
			var ids: Array = boxes.keys()
			for i in ids.size():
				if (boxes[ids[i]] as Dictionary).size() == 1:
					f["one_theme"] += 1
				for j in range(i + 1, ids.size()):
					f["pairs"] += 1
					for t: String in boxes[ids[i]]:
						if (boxes[ids[j]] as Dictionary).has(t):
							f["same"] += 1
							break
		print(n, " ", maps[n - 1])
	var lines: PackedStringArray = []
	lines.append("# 한 방 상자들의 주제 (지도 %d장, 씨앗 n = n번째 지도)\n" % maps.size())
	lines.append("방 = 한 건물의 같은 방 갈래. 그 방에 먹을 것(약)이 든 상자가 둘 이상일 때만 센다.\n")
	lines.append("|갈래|방 수|상자 수|상자 짝|같은 주제를 나눈 짝|그 몫|한 주제만 든 상자|")
	lines.append("|---|---:|---:|---:|---:|---:|---:|")
	for k: String in ["food", "med"]:
		var f: Dictionary = fam[k]
		lines.append("|%s|%d|%d|%d|%d|%.2f|%d / %d|" % ["먹을 것" if k == "food" else "약", f["rooms"], f["boxes"], f["pairs"], f["same"],
			float(f["same"]) / maxi(1, int(f["pairs"])), f["one_theme"], f["boxes"]])
	lines.append("\n이름 붙은 먹을 것·약 %d개, 무게 합 %.1f (평균 %.3f)\n" % [things, weight, weight / maxi(1, things)])
	lines.append("|물건|개수|")
	lines.append("|---|---:|")
	var ids: Array = count.keys()
	ids.sort()
	for id: String in ids:
		lines.append("|%s|%d|" % [id, count[id]])
	var fo := FileAccess.open(out_path, FileAccess.WRITE)
	fo.store_string("\n".join(lines) + "\n")
	fo.close()
	print("DONE ", out_path)
	quit(0)
