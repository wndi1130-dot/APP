extends SceneTree
## The promised shares (card S1, loot_dress.gd PROMISES) on the same 20 seeds as
## loot_items_runs.gd: seed n is the n-th map. For each family, the stop's buildings
## of the kinds, how many must hold it, how many did before the move and after the
## dressing, and the bundles moved; then the 20 stops together.
## -- <out.md>

const FieldMaps = preload("res://game/world/field_maps.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const LootItemsRuns = preload("res://tools/loot_items_runs.gd")


func _initialize() -> void:
	var out_path: String = OS.get_cmdline_user_args()[0]
	var lines: PackedStringArray = []
	lines.append("# 갈래별 보장 몫 (같은 씨앗 20판)\n")
	lines.append("씨앗 n = loot_items_runs.gd MAPS의 n번째 지도. 곳 = 그 갈래 건물 수, 몫 = 지켜야 할 곳(곳 × 비율, 남는 조각은 굴림), 전 = 옮기기 전 하나 이상 든 곳, 후 = 다 채운 뒤 하나 이상 든 곳, 옮김 = 다른 건물에서 옮겨 온 꾸러미.\n")
	var head := "|씨앗|지도|"
	var rule := "|---:|---|"
	for p: Dictionary in LootDress.PROMISES:
		head += "%s 곳|몫|전|후|옮김|" % p["family"]
		rule += "---:|---:|---:|---:|---:|"
	lines.append(head)
	lines.append(rule)
	var sums := {}
	var short: Array = []
	for n in range(1, LootItemsRuns.MAPS.size() + 1):
		var data := FieldMaps.build(LootItemsRuns.MAPS[n - 1])
		var report := LootDress.dress(data, n)
		var row := "|%d|%s|" % [n, LootItemsRuns.MAPS[n - 1]]
		for p: Dictionary in LootDress.PROMISES:
			var family := String(p["family"])
			var r: Array = report["promised"][family]
			var after := _holding(data, p)
			row += "%d|%d|%d|%d|%d|" % [r[0], r[1], r[2], after, r[3]]
			var s: Array = sums.get(family, [0, 0, 0, 0, 0])
			for i in range(4):
				s[i] += int(r[i])
			s[4] += after
			sums[family] = s
			if after < int(r[1]):
				short.append("%d %s %s %d/%d" % [n, LootItemsRuns.MAPS[n - 1], family, after, r[1]])
		lines.append(row)
	lines.append("\n## 20판 합\n")
	lines.append("|갈래|곳|몫|전 ≥1|후 ≥1|옮김|")
	lines.append("|---|---:|---:|---:|---:|---:|")
	for family: String in sums:
		var s: Array = sums[family]
		lines.append("|%s|%d|%d|%d (%.2f)|%d (%.2f)|%d|" % [family, s[0], s[1], s[2], s[2] / maxf(1.0, s[0]), s[4], s[4] / maxf(1.0, s[0]), s[3]])
	lines.append("\n몫에 못 미친 정차(나눠 줄 건물이 없음): %s\n" % ("없음" if short.is_empty() else ", ".join(short)))
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("\n".join(lines))
	quit(0)


## How many of the stop's buildings of the promise's kinds hold its family now.
func _holding(data: Dictionary, p: Dictionary) -> int:
	var containers: Dictionary = data["containers"]
	var by_building := {}
	for id: String in containers:
		var c: Dictionary = containers[id]
		var b: int = int(c.get("building", -1))
		if b < 0 or not LootDress._movable_box(id, c):
			continue
		if not by_building.has(b):
			by_building[b] = []
		(by_building[b] as Array).append(id)
	var n := 0
	for b: int in by_building:
		if (p["kinds"] as Array).has(LootDress._building_kind_of(data["buildings"], containers[by_building[b][0]])) \
				and LootDress._held(containers, by_building[b], String(p["family"])) > 0:
			n += 1
	return n
