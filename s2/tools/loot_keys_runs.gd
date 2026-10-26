extends SceneTree
## J06's next step, measured (no game rule here): every map (the first stop and MAP_DIR's) as
## built, its boxes' "room" key as the names give it (LootDress.name_keys), against the room the
## furniture a box now stands in would say (map-layout puts boxes into furniture). How many boxes
## stand in furniture, and of those how many the two disagree on, room by room.
## -- <out.md>

const FieldMaps = preload("res://game/world/field_maps.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")

## The room a piece of furniture belongs to (a reading for this count only).
const FURNITURE_ROOM: Dictionary = {
	"fridge_open": "kitchen", "cupboard": "kitchen", "counter": "kitchen", "freezer_chest": "kitchen",
	"jar_shelf": "pantry", "bread_rack": "shop", "cask_stack": "pantry", "tin_crate": "pantry",
	"washstand": "bathroom", "towel_shelf": "bathroom",
	"dresser": "bedroom", "wardrobe": "bedroom", "nightstand": "bedroom", "blanket_chest": "bedroom", "side_table": "bedroom",
	"desk": "office", "typewriter_desk": "office", "office_desk": "office", "file_cabinet": "office", "map_cabinet": "office",
	"office_cabinet": "office", "record_shelf_row": "office", "evidence_shelf": "office", "mail_sorting_rack": "office",
	"conductor_log_chest": "office", "ration_ledger_chest": "office", "bookcase": "office",
	"tool_chest": "toolbox", "toolbox": "toolbox", "workbench": "toolbox", "tool_bench": "toolbox",
	"hardware_rack": "toolbox", "parts_rack": "toolbox", "part_crate": "toolbox",
	"display_shelf": "shop", "shop_counter": "shop", "checkout": "shop", "service_counter": "shop", "cloth_bolt_rack": "shop",
	"medicine_crate": "clinic", "glass_cabinet": "clinic",
	"hymn_shelf": "hall", "vestry_chest": "hall", "parish_chest": "hall", "lamp_shelf": "hall",
	"crate_stack": "storage", "shelf": "storage", "ammo_crate": "storage", "relief_crate": "storage",
	"blanket_crate": "storage", "strongbox": "storage", "drawer_chest_spilled": "bedroom",
}


func _initialize() -> void:
	var out_path: String = OS.get_cmdline_user_args()[0]
	var maps: Array[String] = [FieldMaps.DEFAULT_PLACE]
	for kind: String in FieldMaps.KINDS:
		for n in range(1, FieldMaps.MOST_PER_KIND + 1):
			var id := "%s_%02d" % [kind, n]
			if ResourceLoader.exists(FieldMaps.MAP_DIR + id + ".gd"):
				maps.append(id)
	var by_room := {}
	var boxes := 0
	var in_furniture := 0
	var differ := 0
	var pairs := {}
	for map_id: String in maps:
		var data := FieldMaps.build(map_id)
		LootDress.name_keys(data)
		for id in data["containers"]:
			var c: Dictionary = data["containers"][id]
			boxes += 1
			var room: String = String(c["room"])
			if not by_room.has(room):
				by_room[room] = {"n": 0, "furn": 0, "differ": 0}
			by_room[room]["n"] += 1
			if not c.has("furniture"):
				continue
			in_furniture += 1
			by_room[room]["furn"] += 1
			var said: String = String(FURNITURE_ROOM.get(String(c["furniture"]), ""))
			if said != "" and said != room:
				differ += 1
				by_room[room]["differ"] += 1
				var key := "%s → %s" % [room, said]
				pairs[key] = int(pairs.get(key, 0)) + 1
		print(map_id)
	var lines: PackedStringArray = []
	lines.append("# 상자 방 열쇠: 이름 대 가구 (지도 %d장)\n" % maps.size())
	lines.append("상자 %d개, 가구에 든 것 %d개, 그 가운데 이름이 말하는 방과 가구가 말하는 방이 다른 것 %d개.\n" % [boxes, in_furniture, differ])
	lines.append("|이름이 말하는 방|상자|가구에 듦|가구와 다름|")
	lines.append("|---|---:|---:|---:|")
	for room: String in LootDress.ROOM_ORDER:
		if by_room.has(room):
			lines.append("|%s|%d|%d|%d|" % [room, by_room[room]["n"], by_room[room]["furn"], by_room[room]["differ"]])
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
