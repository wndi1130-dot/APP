extends SceneTree
## What each room kind holds once the stop is dressed (card I: a box's room from its furniture):
## every map (the first stop and MAP_DIR's), seed n for the n-th, LootDress.dress as the field
## does. Per room: boxes, how many hold nothing, the bundles by family, the finds of their own
## (packs, watches, openers, nails, parts, clothes, named finds) and the odds and ends.
## -- <out.md>

const FieldMaps = preload("res://game/world/field_maps.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const LootJunk = preload("res://game/sim/loot_junk.gd")
const FieldItems = preload("res://game/sim/field_items.gd")

const FAMILIES: Array[String] = ["food", "med", "lux", "wood", "scrap", "cloth", "small"]


func _family_of(id: String) -> String:
	if LootDress.FAMILY.has(id):
		return String(LootDress.FAMILY[id])
	for fam: String in LootDress.NAMES:
		for table: String in LootDress.NAMES[fam]:
			for r: Array in LootDress.NAMES[fam][table]:
				if String(r[0]) == id:
					return fam
	if id == "can_dented_bad":
		return "food"
	return ""


func _initialize() -> void:
	var out_path: String = OS.get_cmdline_user_args()[0]
	var maps: Array[String] = [FieldMaps.DEFAULT_PLACE]
	for kind: String in FieldMaps.KINDS:
		for n in range(1, FieldMaps.MOST_PER_KIND + 1):
			var id := "%s_%02d" % [kind, n]
			if ResourceLoader.exists(FieldMaps.MAP_DIR + id + ".gd"):
				maps.append(id)
	var junk_ids := {}
	for rows: Array in LootJunk.JUNK.values():
		for r: Array in rows:
			junk_ids[String(r[0])] = true
	var rooms := {}
	for n in range(1, maps.size() + 1):
		var data := FieldMaps.build(maps[n - 1])
		var report: Dictionary = LootDress.dress(data, n)
		var find_box := {}
		for f: Array in report.get("finds", []):
			find_box[String(f[1])] = int(find_box.get(String(f[1]), 0)) + 1
		for id in data["containers"]:
			var c: Dictionary = data["containers"][id]
			var room := LootDress.room_of(c)
			if not rooms.has(room):
				rooms[room] = {"boxes": 0, "empty": 0, "finds": 0, "junk": 0}
				for fam: String in FAMILIES:
					rooms[room][fam] = 0
			var r: Dictionary = rooms[room]
			r["boxes"] += 1
			var items: Array = c.get("items", [])
			if items.is_empty():
				r["empty"] += 1
			r["finds"] += int(find_box.get(String(id), 0))
			for it in items:
				if junk_ids.has(String(it)):
					r["junk"] += 1
					continue
				var fam := _family_of(String(it))
				if fam != "":
					r[fam] += 1
		print(n, " ", maps[n - 1])
	var lines: PackedStringArray = []
	lines.append("# 방마다 든 것 (지도 %d장, 씨앗 n = n번째 지도)\n" % maps.size())
	lines.append("|방|상자|빈 몫|먹을 것|약|사치품|목재|고철|천|잔것|찾은 것|잡동사니|")
	lines.append("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
	for room: String in LootDress.ROOM_ORDER:
		if not rooms.has(room):
			continue
		var r: Dictionary = rooms[room]
		lines.append("|%s|%d|%.2f|%d|%d|%d|%d|%d|%d|%d|%d|%d|" % [room, r["boxes"], float(r["empty"]) / maxi(1, int(r["boxes"])),
			r["food"], r["med"], r["lux"], r["wood"], r["scrap"], r["cloth"], r["small"], r["finds"], r["junk"]])
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("DONE ", out_path)
	quit(0)
