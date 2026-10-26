extends SceneTree
## A box's room by its name against the room its furniture says (LootDress.FURNITURE_ROOM, card I):
## every map (the first stop and MAP_DIR's) as built. How many boxes stand in furniture, how many
## in furniture that says a room, and how many of those the name read otherwise (the boxes whose
## room the furniture now sets), room by room.
## -- <out.md>

const FieldMaps = preload("res://game/world/field_maps.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")


func _initialize() -> void:
	var out_path: String = OS.get_cmdline_user_args()[0]
	var maps: Array[String] = [FieldMaps.DEFAULT_PLACE]
	for kind: String in FieldMaps.KINDS:
		for n in range(1, FieldMaps.MOST_PER_KIND + 1):
			var id := "%s_%02d" % [kind, n]
			if ResourceLoader.exists(FieldMaps.MAP_DIR + id + ".gd"):
				maps.append(id)
	var by_name := {}
	var boxes := 0
	var in_furniture := 0
	var says := 0
	var flips := 0
	var pairs := {}
	for map_id: String in maps:
		var data := FieldMaps.build(map_id)
		for id in data["containers"]:
			var c: Dictionary = data["containers"][id]
			boxes += 1
			var room := LootDress.room_of_name(String(c.get("name", "")))
			if not by_name.has(room):
				by_name[room] = {"n": 0, "furn": 0, "says": 0, "flip": 0}
			by_name[room]["n"] += 1
			if not c.has("furniture"):
				continue
			in_furniture += 1
			by_name[room]["furn"] += 1
			var said: String = String(LootDress.FURNITURE_ROOM.get(String(c["furniture"]), ""))
			if said == "":
				continue
			says += 1
			by_name[room]["says"] += 1
			if said != room:
				flips += 1
				by_name[room]["flip"] += 1
				var key := "%s → %s" % [room, said]
				pairs[key] = int(pairs.get(key, 0)) + 1
		print(map_id)
	var lines: PackedStringArray = []
	lines.append("# 상자 방: 이름 대 가구 (지도 %d장)\n" % maps.size())
	lines.append("상자 %d개, 가구에 든 것 %d개, 그 가운데 방을 말하는 가구 %d개, 이름과 다른 방이 되는 것 %d개.\n" % [boxes, in_furniture, says, flips])
	lines.append("|이름이 말하는 방|상자|가구에 듦|방을 말하는 가구|가구 따라 바뀜|")
	lines.append("|---|---:|---:|---:|---:|")
	for room: String in LootDress.ROOM_ORDER:
		if by_name.has(room):
			var r: Dictionary = by_name[room]
			lines.append("|%s|%d|%d|%d|%d|" % [room, r["n"], r["furn"], r["says"], r["flip"]])
	lines.append("\n|이름 → 가구|상자|")
	lines.append("|---|---:|")
	var keys: Array = pairs.keys()
	keys.sort_custom(func(x: String, y: String) -> bool: return int(pairs[x]) > int(pairs[y]))
	for k: String in keys.slice(0, 15):
		lines.append("|%s|%d|" % [k, pairs[k]])
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("DONE ", out_path)
	quit(0)
