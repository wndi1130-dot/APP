extends "res://addons/gut/test.gd"
## 한 방 상자들의 주제 나누기(차이 목록 8, ref-ops L1): 한 건물 같은 방에 먹을 것(약)이 든 상자가
## 둘 이상이면 상자마다 주제 하나(통조림·병·마른 것·건빵·생것 / 알약·바르는 것·물약)를 받고, 방의
## 상자들이 주제의 몫만큼 고르게 나눠 가진다(몫이 상자 하나 몫보다 클 때만 겹침). 혼자인 상자는
## 전과 같은 표·같은 몫으로 이름을 받는다.

const LootDress = preload("res://game/sim/loot_dress.gd")
const RoomThemeRuns = preload("res://tools/room_theme_runs.gd")


func _tool_themes() -> Dictionary:
	var tool_script: Script = RoomThemeRuns
	return tool_script.get_script_constant_map()["THEME_OF"]


## Each theme's share of the kitchen's table (food:default).
func _shares() -> Dictionary:
	var out := {}
	var total := 0.0
	for r: Array in LootDress.NAMES["food"]["default"]:
		total += float(r[1])
		for theme: String in LootDress.THEMES["food"]:
			if (LootDress.THEMES["food"][theme] as Array).has(String(r[0])):
				out[theme] = float(out.get(theme, 0.0)) + float(r[1])
	for theme: String in out:
		out[theme] = float(out[theme]) / total
	return out


func test_every_row_of_the_food_and_medicine_tables_is_in_one_theme() -> void:
	for family: String in ["food", "med"]:
		var theme_of: Dictionary = {}
		for theme: String in LootDress.THEMES[family]:
			for id: String in LootDress.THEMES[family][theme]:
				assert_false(theme_of.has(id), "one theme only: " + id)
				theme_of[id] = theme
		for table: String in LootDress.NAMES[family]:
			for row: Array in LootDress.NAMES[family][table]:
				assert_true(theme_of.has(String(row[0])), "%s:%s %s" % [family, table, row[0]])


func test_the_measuring_tool_reads_the_same_themes() -> void:
	var tool_themes := _tool_themes()
	var flat: Dictionary = {"can_dented_bad": "food:tins"}
	for family: String in LootDress.THEMES:
		for theme: String in LootDress.THEMES[family]:
			for id: String in LootDress.THEMES[family][theme]:
				flat[id] = "%s:%s" % [family, theme]
	assert_eq(tool_themes, flat)


func test_a_theme_keeps_to_its_rows() -> void:
	var rows: Array = LootDress.theme_rows("food", LootDress.NAMES["food"]["default"], "jars")
	assert_eq(rows.map(func(r: Array) -> String: return String(r[0])), ["jar_cabbage", "jar_jam", "jar_honey"])
	assert_eq(LootDress.theme_rows("food", LootDress.NAMES["food"]["bakery"], "tins"), LootDress.NAMES["food"]["bakery"], "none there: the whole table")
	for seed in range(1, 40):
		var a := RandomNumberGenerator.new()
		var b := RandomNumberGenerator.new()
		a.seed = seed
		b.seed = seed
		var named := LootDress.name_bundle("food_pack", "default", a, "tins")
		assert_true(["can_beans", "can_meat", "can_dented", "can_dented_bad"].has(named), named)
		# No theme: the whole table, as before.
		assert_eq(LootDress.name_bundle("food_pack", "default", b, ""), LootDress.name_bundle("food_pack", "default", _seeded(seed)))


func _seeded(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


func _kitchen(n: int, packs: int) -> Dictionary:
	var containers := {}
	for i in n:
		var items: Array = []
		for k in packs:
			items.append("food_pack")
		containers["k%d" % i] = {"name": "부엌 찬장 %d" % i, "building": 0, "cell": [i, 0], "items": items}
	containers["alone"] = {"name": "안방 서랍", "building": 0, "cell": [9, 0], "items": ["food_pack"]}
	return containers


func test_the_boxes_of_one_kitchen_split_the_themes() -> void:
	var shares := _shares()
	var seen: Dictionary = {}
	for n in [2, 3, 6]:
		for seed in range(1, 200):
			var themes := LootDress.room_themes(_kitchen(n, 2), [{"name": "민가"}], "houses", LootDress._rng(seed, "themes"))
			assert_false(themes.has("alone|food"), "alone in its room: as before")
			var count: Dictionary = {}
			for i in n:
				var t: String = String(themes["k%d|food" % i])
				count[t] = int(count.get(t, 0)) + 1
				seen["%d:%s" % [n, t]] = int(seen.get("%d:%s" % [n, t], 0)) + 1
			for t: String in shares:
				# As evenly as the shares allow: never more than one over a theme's share of the room.
				assert_between(int(count.get(t, 0)), floori(n * float(shares[t])), ceili(n * float(shares[t])), "%d boxes, %s" % [n, t])
	# Over many rooms each theme comes up by its share (the room holds what it held before).
	for t: String in shares:
		assert_almost_eq(float(seen.get("6:%s" % t, 0)) / (199.0 * 6.0), float(shares[t]), 0.03, t)


func test_a_dressed_kitchen_box_holds_one_theme() -> void:
	var theme_of := _tool_themes()
	for seed in range(1, 30):
		var data := {"containers": _kitchen(3, 2), "buildings": [{"name": "민가"}], "place_kind": "houses"}
		LootDress.dress(data, seed)
		# The packs are dealt again by room first: the kitchen shares only when two boxes hold food.
		var holding: Array = ["k0", "k1", "k2"].filter(func(id: String) -> bool:
			return (data["containers"][id]["items"] as Array).any(func(it) -> bool: return String(theme_of.get(String(it), "")).begins_with("food:")))
		if holding.size() < 2:
			continue
		var seen: Dictionary = {}
		for id: String in holding:
			var themes: Dictionary = {}
			for item in data["containers"][id]["items"]:
				var t: String = String(theme_of.get(String(item), ""))
				if t.begins_with("food:"):
					themes[t] = true
			assert_lte(themes.size(), 1, "one theme a box: %s %s" % [id, str(data["containers"][id]["items"])])
			for t: String in themes:
				seen[t] = true
		if holding.size() == 2:
			assert_eq(seen.size(), 2, "two boxes, two themes (none has half the table)")
