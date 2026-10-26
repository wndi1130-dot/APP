extends SceneTree
## What the loose boards hide (결정 카드 K, floor_stash.gd): every map (the first stop and
## MAP_DIR's), SEEDS runs each (seed n×10+k), dressed and storied as the field does
## (LootDress.dress, RoomStories.apply on the rule maps, then FloorStash.fill). How often a
## stop has one, what is in them, and what a stop gives on average — before there was none.
## -- <out.md>

const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const RoomStories = preload("res://game/world/room_stories.gd")
const FloorStash = preload("res://game/sim/floor_stash.gd")

const SEEDS: int = 3


func _initialize() -> void:
	var out_path: String = OS.get_cmdline_user_args()[0]
	var maps: Array[String] = [FieldMaps.DEFAULT_PLACE]
	for kind: String in FieldMaps.KINDS:
		for n in range(1, FieldMaps.MOST_PER_KIND + 1):
			var id := "%s_%02d" % [kind, n]
			if ResourceLoader.exists(FieldMaps.MAP_DIR + id + ".gd"):
				maps.append(id)
	var runs := 0
	var with_one := 0
	var stashes := 0
	var by_id := {}
	var lux := 0.0
	var ammo := 0
	var weight := 0.0
	for n in range(1, maps.size() + 1):
		for k in range(SEEDS):
			var seed := n * 10 + k
			var data := FieldMaps.build(maps[n - 1])
			LootDress.dress(data, seed)
			runs += 1
			if not data.has("room_stats"):
				continue
			RoomStories.apply(data, ("%d:stories:%s" % [seed, data["place_id"]]).hash())
			FloorStash.fill(data, seed)
			var here: Array = data.get("floor_stashes", [])
			if here.is_empty():
				continue
			with_one += 1
			for s: Dictionary in here:
				stashes += 1
				for item in data["containers"][s["id"]]["items"]:
					var id := String(item)
					by_id[id] = int(by_id.get(id, 0)) + 1
					var melt: Array = FieldItems.stock_of(id)
					if String(melt[0]) == "luxury":
						lux += float(melt[1])
					if id == "ammo_pistol":
						ammo += 1
					weight += FieldItems.weight(id) if FieldItems.has(id) else 0.1
		print(n, " ", maps[n - 1])
	var lines: PackedStringArray = []
	lines.append("# 마루 밑 숨긴 칸 (지도 %d장 × 씨앗 %d = %d판)\n" % [maps.size(), SEEDS, runs])
	lines.append("|값|전|후|")
	lines.append("|---|---:|---:|")
	lines.append("|숨긴 칸이 있는 판|0|%d (%.1f%%)|" % [with_one, 100.0 * with_one / runs])
	lines.append("|정차당 숨긴 칸|0|%.3f|" % (float(stashes) / runs))
	lines.append("|정차당 사치품(열차 몫)|0|%.3f|" % (lux / runs))
	lines.append("|정차당 권총탄 한 줌|0|%.3f|" % (float(ammo) / runs))
	lines.append("|숨긴 칸 하나에 든 무게(평균)|-|%.2f|" % (weight / maxi(stashes, 1)))
	lines.append("")
	var keys: Array = by_id.keys()
	keys.sort()
	lines.append("든 것: " + ", ".join(PackedStringArray(keys.map(func(id): return "%s %d" % [id, by_id[id]]))))
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("\n".join(lines))
	quit()
