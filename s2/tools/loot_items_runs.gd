extends SceneTree
## Before and after the named things (decision 423-8), on the same 20 seeds:
## seed n is the n-th map of MAPS, its boxes as the map gives them (before) and
## as LootDress dresses them (after). Two takes: every box in a building or not
## (a goal box left out), and the 12 boxes nearest the train door (one trip).
## What is counted: kinds of things, their weight, and what they melt into on
## the train, as field_game.finish melts an unload. Pockets are not rolled here.
## -- <out.md>

const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const Carry = preload("res://game/sim/carry.gd")
const FieldGame = preload("res://game/field_game.gd")

const MAPS: Array[String] = ["first_leg_01_sulechow", "freight_01", "freight_04", "houses_01", "houses_02",
	"houses_04", "houses_06", "hospital_01", "hospital_03", "factory_01", "factory_03", "church_01",
	"church_03", "office_01", "office_03", "lodge_01", "lake_01", "mine_01", "sawmill_01", "summit_01"]
const NEAR: int = 12
const KEYS: Array[String] = ["food", "medicine", "luxury", "coal", "scrap", "wood", "info", "symbol"]


func _initialize() -> void:
	var out_path: String = OS.get_cmdline_user_args()[0]
	var lines: PackedStringArray = []
	lines.append("# 필드 물건 전후 (같은 씨앗 20판)\n")
	lines.append("씨앗 n = MAPS의 n번째 지도. 전 = 지도가 준 상자 그대로, 후 = LootDress.dress(지도, 씨앗). 녹은 양은 field_game.finish와 같은 셈(합친 뒤 반올림 전 값).\n")
	var totals := {}
	for take in ["all", "near"]:
		lines.append("\n## %s\n" % ("상자 전부" if take == "all" else "열차 문에서 가까운 상자 %d곳" % NEAR))
		lines.append("|씨앗|지도|전 종류|후 종류|전 무게|후 무게|전 식량|후 식량|전 의약품|후 의약품|전 사치품|후 사치품|전 석탄|후 석탄|전 고철|후 고철|빈 상자 전|빈 상자 후|")
		lines.append("|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
		for n in range(1, MAPS.size() + 1):
			var before := FieldMaps.build(MAPS[n - 1])
			var after := FieldMaps.build(MAPS[n - 1])
			LootDress.dress(after, n)
			var b := _take(before, take)
			var a := _take(after, take)
			for side in [["b", b], ["a", a]]:
				var key: String = "%s:%s" % [take, side[0]]
				if not totals.has(key):
					totals[key] = {"kinds": {}, "weight": 0.0, "melt": {}, "empty": 0, "boxes": 0}
				var t: Dictionary = totals[key]
				for id: String in side[1]["items"]:
					t["kinds"][id] = true
				t["weight"] += float(side[1]["weight"])
				for k: String in side[1]["melt"]:
					t["melt"][k] = float(t["melt"].get(k, 0.0)) + float(side[1]["melt"][k])
				t["empty"] += int(side[1]["empty"])
				t["boxes"] += int(side[1]["boxes"])
			lines.append("|%d|%s|%d|%d|%.1f|%.1f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%d|%d|" % [n, MAPS[n - 1],
				b["items"].size(), a["items"].size(), b["weight"], a["weight"],
				_m(b, "food"), _m(a, "food"), _m(b, "medicine"), _m(a, "medicine"), _m(b, "luxury"), _m(a, "luxury"),
				_m(b, "coal"), _m(a, "coal"), _m(b, "scrap"), _m(a, "scrap"), b["empty"], a["empty"]])
		lines.append("")
		for side in ["b", "a"]:
			var t: Dictionary = totals["%s:%s" % [take, side]]
			var melt := []
			for k in KEYS:
				melt.append("%s %.2f" % [k, float(t["melt"].get(k, 0.0))])
			lines.append("- %s 20판 합: 종류 %d가지, 무게 %.1f, 빈 상자 %d/%d, 녹은 양 %s" % ["전" if side == "b" else "후", t["kinds"].size(), t["weight"], t["empty"], t["boxes"], ", ".join(melt)])
	lines.append("\n## 방마다 빈 상자 몫 (20판, 상자 전부)\n")
	lines.append("|방|상자 수|전 빈 몫|후 빈 몫|후 식량 든 몫|")
	lines.append("|---|---:|---:|---:|---:|")
	var rooms := _rooms()
	for room: String in LootDress.ROOM_ORDER:
		if not rooms.has(room):
			continue
		var r: Dictionary = rooms[room]
		lines.append("|%s|%d|%.2f|%.2f|%.2f|" % [room, r["n"], float(r["empty_b"]) / r["n"], float(r["empty_a"]) / r["n"], float(r["food_a"]) / r["n"]])
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("DONE ", out_path)
	quit(0)


func _m(r: Dictionary, key: String) -> float:
	return float(r["melt"].get(key, 0.0))


## Everything in the chosen boxes: kinds, weight, melt, empty boxes.
func _take(data: Dictionary, take: String) -> Dictionary:
	var ids: Array = []
	for id: String in data["containers"]:
		if not data["containers"][id].has("pick"):
			ids.append(id)
	if take == "near":
		var door: Vector2i = _door(data)
		ids.sort_custom(func(x, y) -> bool:
			return _dist(data, x, door) < _dist(data, y, door) or (_dist(data, x, door) == _dist(data, y, door) and String(x) < String(y)))
		var open: Array = []
		for id in ids:
			if not bool(data["containers"][id].get("locked", false)):
				open.append(id)
		ids = open.slice(0, NEAR)
	var items: Dictionary = {}
	var empty := 0
	for id in ids:
		var list: Array = data["containers"][id]["items"]
		if list.is_empty():
			empty += 1
		for item in list:
			items[String(item)] = int(items.get(String(item), 0)) + 1
	var weight := 0.0
	for id: String in items:
		weight += Carry.item_weight(id) * items[id]
	return {"items": items, "weight": weight, "melt": melt(items), "empty": empty, "boxes": ids.size()}


func _door(data: Dictionary) -> Vector2i:
	var doors = data.get("spawns", {}).get("train_door", [])
	if doors is Array and not doors.is_empty():
		var d = doors[0]
		return d if d is Vector2i else Vector2i(int(d[0]), int(d[1]))
	return Vector2i.ZERO


func _dist(data: Dictionary, id, door: Vector2i) -> float:
	var c = data["containers"][id]["cell"]
	var cell: Vector2i = c if c is Vector2i else Vector2i(int(c[0]), int(c[1]))
	return Vector2(cell - door).length() + 20.0 * absf(float(data["containers"][id].get("level", 0)))


## field_game.finish's melt, before rounding.
static func melt(items: Dictionary) -> Dictionary:
	var stock: Dictionary = {}
	for id: String in items:
		var n: int = int(items[id])
		if FieldGame.STOCK_OF.has(id):
			var row: Array = FieldGame.STOCK_OF[id]
			stock[row[0]] = float(stock.get(row[0], 0.0)) + float(row[1]) * n
		elif FieldItems.has(id):
			var m: Array = FieldItems.stock_of(id)
			if String(m[0]) != "":
				stock[m[0]] = float(stock.get(m[0], 0.0)) + float(m[1]) * n
	stock["scrap"] = float(stock.get("scrap", 0.0)) + float(items.get("scrap", 0))
	stock["wood"] = float(stock.get("wood", 0.0)) + float(items.get("wood", 0))
	return stock


func _rooms() -> Dictionary:
	var out: Dictionary = {}
	for n in range(1, MAPS.size() + 1):
		var before := FieldMaps.build(MAPS[n - 1])
		var after := FieldMaps.build(MAPS[n - 1])
		LootDress.dress(after, n)
		for id: String in before["containers"]:
			var c: Dictionary = before["containers"][id]
			if c.has("pick"):
				continue
			var room := LootDress.room_of(c)
			if not out.has(room):
				out[room] = {"n": 0, "empty_b": 0, "empty_a": 0, "food_a": 0}
			out[room]["n"] += 1
			if (c["items"] as Array).is_empty():
				out[room]["empty_b"] += 1
			var a: Array = after["containers"][id]["items"]
			if a.is_empty():
				out[room]["empty_a"] += 1
			for item in a:
				if FieldItems.group(String(item)) == "food":
					out[room]["food_a"] += 1
					break
	return out
