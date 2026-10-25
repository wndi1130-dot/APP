extends SceneTree
## What the boxes hold as the maps are dressed, against how much each may take
## (inventory.md 3.3): every map (the first stop and MAP_DIR's), seed n for the
## n-th, LootDress.dress as the field does. Per kind of furniture a box stands
## in ("" = a box of its own): how many, the heaviest and the mean load, how
## many already hold more than their limit, and how many could still take a
## full 배낭 (8) or 큰 배낭 (12) from a bag — before (no limit) and after.
## -- <out.md>

const FieldMaps = preload("res://game/world/field_maps.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const Carry = preload("res://game/sim/carry.gd")


func _initialize() -> void:
	var out_path: String = OS.get_cmdline_user_args()[0]
	var maps: Array[String] = [FieldMaps.DEFAULT_PLACE]
	for kind: String in FieldMaps.KINDS:
		for n in range(1, FieldMaps.MOST_PER_KIND + 1):
			var id := "%s_%02d" % [kind, n]
			if ResourceLoader.exists(FieldMaps.MAP_DIR + id + ".gd"):
				maps.append(id)
	var kinds := {}
	for n in range(1, maps.size() + 1):
		var data := FieldMaps.build(maps[n - 1])
		LootDress.dress(data, n)
		for id: String in data["containers"]:
			var c: Dictionary = data["containers"][id]
			var kind := String(c.get("furniture", ""))
			if not kinds.has(kind):
				kinds[kind] = {"n": 0, "max": 0.0, "sum": 0.0, "over": 0, "pack": 0, "big": 0}
			var k: Dictionary = kinds[kind]
			var w := Carry.box_load(c)
			var cap := Carry.box_limit(c)
			k["n"] += 1
			k["max"] = maxf(float(k["max"]), w)
			k["sum"] += w
			if w > cap:
				k["over"] += 1
			if cap - w >= 8.0:
				k["pack"] += 1
			if cap - w >= 12.0:
				k["big"] += 1
		print(n, " ", maps[n - 1])
	var lines: PackedStringArray = []
	lines.append("# 상자 한도 대 차려진 짐 (지도 %d장, 씨앗 n = n번째 지도)\n" % maps.size())
	lines.append("전에는 한도가 없어 어느 상자든 배낭(8)·큰 배낭(12)을 다 받았다. 후 = `Carry.box_limit`.\n")
	lines.append("|가구|상자 수|한도|가장 무거운 짐|평균 짐|한도 넘게 차려짐|배낭 다 받음 전→후|큰 배낭 다 받음 전→후|")
	lines.append("|---|---:|---:|---:|---:|---:|---:|---:|")
	var order: Array = kinds.keys()
	order.sort_custom(func(a: String, b: String) -> bool: return int(kinds[a]["n"]) > int(kinds[b]["n"]))
	var tot := {"n": 0, "over": 0, "pack": 0, "big": 0}
	for kind: String in order:
		var k: Dictionary = kinds[kind]
		lines.append("|%s|%d|%.0f|%.1f|%.2f|%d|%d→%d|%d→%d|" % [kind if kind != "" else "(상자만)", k["n"],
			Carry.box_limit({"furniture": kind}), k["max"], float(k["sum"]) / int(k["n"]), k["over"],
			k["n"], k["pack"], k["n"], k["big"]])
		for key: String in tot:
			tot[key] += int(k[key])
	lines.append("|모두|%d||||%d|%d→%d|%d→%d|" % [tot["n"], tot["over"], tot["n"], tot["pack"], tot["n"], tot["big"]])
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("DONE ", out_path)
	quit(0)
