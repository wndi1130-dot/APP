extends SceneTree
## Where the scrawled map to the side path lies (결정 카드 M, side_note.gd): every map (the
## first stop and MAP_DIR's), SEEDS run seeds each (n×10+k), the side path added as the
## field does (SidePath.add) and the stop dressed; the dead are the map's "dead_..." spawns.
## How many stops have a side path, how many of those a note, and where.
## -- <out.md>

const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const SidePath = preload("res://game/world/side_path.gd")
const SideNote = preload("res://game/sim/side_note.gd")

const SEEDS: int = 4


func _initialize() -> void:
	var out_path: String = OS.get_cmdline_user_args()[0]
	var maps: Array[String] = [FieldMaps.DEFAULT_PLACE]
	for kind: String in FieldMaps.KINDS:
		for n in range(1, FieldMaps.MOST_PER_KIND + 1):
			var id := "%s_%02d" % [kind, n]
			if ResourceLoader.exists(FieldMaps.MAP_DIR + id + ".gd"):
				maps.append(id)
	var runs := 0
	var paths := 0
	var where := {"dead": 0, "desk": 0, "": 0}
	var walk := 0.0
	for n in range(1, maps.size() + 1):
		for k in range(SEEDS):
			var seed := n * 10 + k
			var data := SidePath.add(FieldMaps.build(maps[n - 1]), seed)
			runs += 1
			if not data.has("side_path"):
				continue
			paths += 1
			walk += float(data["side_path"].get("seconds", 0.0))
			LootDress.dress(data, seed)
			var dead: Array = []
			for key: String in data.get("spawns", {}):
				if key.begins_with("dead_") and key != "dead_levels":
					for c in data["spawns"][key]:
						dead.append({"pos": FieldGrid.center(c), "kind": "walker"})
			where[SideNote.place(data, dead, seed)] += 1
		print(n, " ", maps[n - 1])
	var lines: PackedStringArray = []
	lines.append("# 샛길 낙서 지도 (지도 %d장 × 씨앗 %d = %d판)\n" % [maps.size(), SEEDS, runs])
	lines.append("|값|전|후|")
	lines.append("|---|---:|---:|")
	lines.append("|샛길이 난 판|%d (%.1f%%)|%d|" % [paths, 100.0 * paths / runs, paths])
	lines.append("|그 가운데 낙서 지도가 있는 판|0|%d (%.1f%%)|" % [where["dead"] + where["desk"], 100.0 * (where["dead"] + where["desk"]) / maxi(paths, 1)])
	lines.append("|망자 주머니 / 책상|-|%d / %d|" % [where["dead"], where["desk"]])
	lines.append("|승강장에서 틈까지 걸음(평균 초)|%.1f|%.1f|" % [walk / maxi(paths, 1), walk / maxi(paths, 1)])
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("\n".join(lines))
	quit()
