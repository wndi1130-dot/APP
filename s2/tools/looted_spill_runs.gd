extends SceneTree
## What the looted houses tip out (결정 카드 J, loot_junk.gd spill_looted): every
## map (the first stop and MAP_DIR's), seed n for the n-th, dressed and storied
## as the field does (LootDress.dress, RoomStories.apply on the rule maps). Per
## looted house: things in its boxes before, on its floors after, and the boxes
## left empty — the same things before and after, only some on the floor.
## -- <out.md>

const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const LootJunk = preload("res://game/sim/loot_junk.gd")
const RoomStories = preload("res://game/world/room_stories.gd")


func _initialize() -> void:
	var out_path: String = OS.get_cmdline_user_args()[0]
	var maps: Array[String] = [FieldMaps.DEFAULT_PLACE]
	for kind: String in FieldMaps.KINDS:
		for n in range(1, FieldMaps.MOST_PER_KIND + 1):
			var id := "%s_%02d" % [kind, n]
			if ResourceLoader.exists(FieldMaps.MAP_DIR + id + ".gd"):
				maps.append(id)
	var t := {"maps": 0, "storied": 0, "houses": 0, "spilled_houses": 0, "spilled": 0, "box_before": 0, "box_after": 0,
		"empty_before": 0, "empty_after": 0, "junk_before": 0, "most": 0}
	var by_id := {}
	for n in range(1, maps.size() + 1):
		var data := FieldMaps.build(maps[n - 1])
		LootDress.dress(data, n)
		t["maps"] += 1
		if not data.has("room_stats"):
			continue
		t["storied"] += 1
		var stories := RoomStories.apply(data, ("%d:stories:%s" % [n, data["place_id"]]).hash())
		var looted: Array = []
		for s: Dictionary in stories:
			if s["story"] == "looted":
				looted.append(int(s["building"]))
		var before := _count(data, looted)
		var loose := LootJunk.spill_looted(data, stories, n)
		var after := _count(data, looted)
		t["houses"] += looted.size()
		t["box_before"] += before["items"]
		t["box_after"] += after["items"]
		t["empty_before"] += before["empty"]
		t["empty_after"] += after["empty"]
		t["junk_before"] += before["junk"]
		t["spilled"] += loose.size()
		var per := {}
		for g: Dictionary in loose:
			var b := (data["levels"][clampi(roundi(g["pos"].y / 3.0), -1, 2)] as FieldGrid).building_at(FieldGrid.cell_of(g["pos"]))
			per[b] = int(per.get(b, 0)) + 1
			by_id[g["id"]] = int(by_id.get(g["id"], 0)) + 1
		t["spilled_houses"] += per.size()
		for b in per:
			t["most"] = maxi(int(t["most"]), int(per[b]))
		print(n, " ", maps[n - 1], " looted ", looted.size(), " spilled ", loose.size())
	var lines: PackedStringArray = []
	lines.append("# 털린 집 바닥에 쏟긴 것 (지도 %d장, 방 이야기가 붙는 지도 %d장, 씨앗 n = n번째 지도)\n" % [t["maps"], t["storied"]])
	lines.append("|값|전|후|")
	lines.append("|---|---:|---:|")
	lines.append("|털린 집|%d|%d|" % [t["houses"], t["houses"]])
	lines.append("|털린 집 상자 속 물건|%d|%d|" % [t["box_before"], t["box_after"]])
	lines.append("|털린 집 바닥 물건|0|%d|" % t["spilled"])
	lines.append("|상자+바닥 합|%d|%d|" % [t["box_before"], t["box_after"] + t["spilled"]])
	lines.append("|털린 집 빈 상자|%d|%d|" % [t["empty_before"], t["empty_after"]])
	lines.append("|털린 집 상자 속 잡동사니|%d|%d|" % [t["junk_before"], t["junk_before"] - t["spilled"]])
	lines.append("|바닥에 쏟긴 것이 있는 털린 집|0|%d|" % t["spilled_houses"])
	lines.append("|한 집에 가장 많이|0|%d|" % t["most"])
	lines.append("")
	lines.append("쏟긴 것: " + ", ".join(PackedStringArray(by_id.keys().map(func(k): return "%s %d" % [k, by_id[k]]))))
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("\n".join(lines))
	quit()


## In the looted houses: things in boxes, empty boxes, odds and ends in boxes.
func _count(data: Dictionary, houses: Array) -> Dictionary:
	var r := {"items": 0, "empty": 0, "junk": 0}
	for id: String in data["containers"]:
		var c: Dictionary = data["containers"][id]
		var lv := int(c.get("level", 0))
		var cell := LootJunk._cell(c.get("cell"))
		if cell.x < 0 or not data["levels"].has(lv):
			continue
		if not houses.has((data["levels"][lv] as FieldGrid).building_at(cell)):
			continue
		var items: Array = c.get("items", [])
		r["items"] += items.size()
		if items.is_empty():
			r["empty"] += 1
		for it in items:
			if LootJunk.SPILLS.has(String(it)):
				r["junk"] += 1
	return r
