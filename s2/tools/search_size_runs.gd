extends SceneTree
## How long the boxes take to look through, before (the map's seconds) and after (by their size,
## SearchRules.box_seconds — card H, then card R1): every map (the first stop and MAP_DIR's), as
## built, by the three box sizes, and how long an empty box keeps one waiting (dressed with seed n).
## Then what taking it all out costs (card R1, SearchRules.take_seconds, clothes left) and both by
## stop: the loot loop's time table. Before the searcher's skill.
## -- <out.md>

const FieldMaps = preload("res://game/world/field_maps.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const Carry = preload("res://game/sim/carry.gd")
const SearchRules = preload("res://game/sim/search_rules.gd")
const Wear = preload("res://game/sim/wear.gd")


func _initialize() -> void:
	var out_path: String = OS.get_cmdline_user_args()[0]
	var maps: Array[String] = [FieldMaps.DEFAULT_PLACE]
	for kind: String in FieldMaps.KINDS:
		for n in range(1, FieldMaps.MOST_PER_KIND + 1):
			var id := "%s_%02d" % [kind, n]
			if ResourceLoader.exists(FieldMaps.MAP_DIR + id + ".gd"):
				maps.append(id)
	var names := {Carry.BOX_SMALL: "작은 가구", Carry.BOX_MID: "중간 가구", Carry.BOX_BIG: "큰 가구·상자만"}
	var rows := {}
	var takes := {}
	for size in names:
		rows[size] = {"n": 0, "before": 0.0, "after": 0.0, "empty": 0, "empty_before": 0.0, "empty_after": 0.0}
		takes[size] = {"boxes": 0, "items": 0, "seconds": 0.0}
	for n in range(1, maps.size() + 1):
		var data := FieldMaps.build(maps[n - 1])
		LootDress.dress(data, n)
		for id in data["containers"]:
			var c: Dictionary = data["containers"][id]
			var r: Dictionary = rows[Carry.box_limit(c)]
			var before := float(c.get("search", 0.0))
			var after := SearchRules.box_seconds(c)
			r["n"] += 1
			r["before"] += before
			r["after"] += after
			if (c.get("items", []) as Array).is_empty():
				r["empty"] += 1
				r["empty_before"] += before
				r["empty_after"] += after
			var t: Dictionary = takes[Carry.box_limit(c)]
			var any := false
			for item in c.get("items", []):
				if not Wear.is_garment(String(item)):
					any = true
					t["items"] += 1
					t["seconds"] += SearchRules.take_seconds(String(item))
			if any:
				t["boxes"] += 1
		print(n, " ", maps[n - 1])
	var lines: PackedStringArray = []
	lines.append("# 뒤지기 시간 전/후 (지도 %d장, 씨앗 n = n번째 지도, 솜씨 0)\n" % maps.size())
	lines.append("|크기|상자|평균 초 전 → 후|합 초 전 → 후|빈 상자|빈 상자 기다림 합 전 → 후|")
	lines.append("|---|---:|---:|---:|---:|---:|")
	var tot := {"n": 0, "before": 0.0, "after": 0.0, "empty": 0, "empty_before": 0.0, "empty_after": 0.0}
	for size in [Carry.BOX_SMALL, Carry.BOX_MID, Carry.BOX_BIG]:
		var r: Dictionary = rows[size]
		lines.append("|%s|%d|%.2f → %.2f|%.0f → %.0f|%d|%.0f → %.0f|" % [names[size], r["n"], float(r["before"]) / maxi(1, int(r["n"])),
			float(r["after"]) / maxi(1, int(r["n"])), r["before"], r["after"], r["empty"], r["empty_before"], r["empty_after"]])
		for k: String in tot:
			tot[k] += r[k]
	lines.append("|모두|%d|%.2f → %.2f|%.0f → %.0f|%d|%.0f → %.0f|" % [tot["n"], float(tot["before"]) / maxi(1, int(tot["n"])),
		float(tot["after"]) / maxi(1, int(tot["n"])), tot["before"], tot["after"], tot["empty"], tot["empty_before"], tot["empty_after"]])
	lines.append("
## 챙기는 데 시간 (무게 1에 %.1f초, 한 번 최대 %.0f초, 옷 빼고 다 꺼낼 때)
" % [SearchRules.TAKE_PER_WEIGHT, SearchRules.TAKE_MOST])
	lines.append("|크기|물건 든 상자|물건|꺼내기 합 초|상자당 꺼내기 초|")
	lines.append("|---|---:|---:|---:|---:|")
	var all_take := {"boxes": 0, "items": 0, "seconds": 0.0}
	for size in [Carry.BOX_SMALL, Carry.BOX_MID, Carry.BOX_BIG]:
		var t: Dictionary = takes[size]
		lines.append("|%s|%d|%d|%.0f|%.2f|" % [names[size], t["boxes"], t["items"], t["seconds"], float(t["seconds"]) / maxi(1, int(t["boxes"]))])
		for k: String in all_take:
			all_take[k] += t[k]
	lines.append("|모두 꺼내기|%d|%d|%.0f|%.2f|" % [all_take["boxes"], all_take["items"], all_take["seconds"], float(all_take["seconds"]) / maxi(1, int(all_take["boxes"]))])
	var stops := float(maps.size())
	lines.append("
정차(지도)당: 다 열기 %.0f초 · 다 꺼내기 %.0f초 · 그중 빈 상자 기다림 %.0f초" % [float(tot["after"]) / stops, float(all_take["seconds"]) / stops, float(tot["empty_after"]) / stops])
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("DONE ", out_path)
	quit(0)
