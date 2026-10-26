extends "res://addons/gut/test.gd"
const Grid = preload("res://game/world/field_grid.gd")
const Furnish = preload("res://game/world/room_furnish.gd")
const Kinds = preload("res://game/world/prop_kinds.gd")
const S = Grid.Solid

## Adjacent rooms, one building, with one south door per room.
func _house(specs: Array, lv: int = 0) -> Dictionary:
	var g := Grid.new(80, 20)
	var labels: Array = []
	var x0 := 2
	for spec: Array in specs:
		var w: int = spec[0]
		var h: int = spec[1]
		for y in range(1, h + 3):
			for x in range(x0 - 1, x0 + w + 1):
				var c := Vector2i(x, y)
				g.building[g.index(c)] = 0
				g.set_solid(c, S.WALL if x == x0 - 1 or x == x0 + w or y == 1 or y == h + 2 else S.NONE)
		var door := Vector2i(x0 + w / 2, h + 2)
		g.set_solid(door, S.DOOR)
		g.doors[door] = {"state": "closed", "hp": 8, "building": 0, "cell": door}
		if not String(spec[2]).is_empty():
			labels.append({"text": spec[2], "cell": Vector2i(x0, 2), "level": lv})
		x0 += w + 2
	g.refresh_paths()
	return {"grid": g, "levels": {lv: g}, "place_id": "density_fixture", "props": [], "containers": {},
		"stairs": [], "low_blocks": [], "labels": labels, "buildings": [{"id": 0, "name": "주택"}]}

func _kinds(d: Dictionary, cls: String) -> Array:
	var out: Array = []
	for p: Dictionary in d["props"]:
		if p.get("rule", "") == cls:
			out.append(p["kind"])
	return out

func test_one_small_bath_per_eligible_home_preserves_kitchen_and_only_bedroom() -> void:
	var d := _house([[6, 3, "부엌"], [4, 4, "침실"], [2, 3, ""], [3, 3, ""]])
	var plan := Furnish.density_plan(d)
	var bath: Dictionary = plan["baths"]["0"]
	assert_true(bath["selected"])
	assert_eq(bath["area"], 6)
	assert_eq(plan["classes"].values().count("bath"), 1)
	assert_eq(plan["classes"].values().count("kitchen"), 1)
	assert_eq(plan["classes"].values().count("bed"), 1)
	Furnish.furnish_rooms(d)
	assert_has(_kinds(d, "bath"), "toilet")
	assert_has(_kinds(d, "bath"), "washstand")

func test_small_rooms_are_only_repurposed_for_baths() -> void:
	var d := _house([[4, 4, "침실"], [2, 3, ""], [3, 3, ""]])
	Furnish.furnish_rooms(d)
	assert_eq(_kinds(d, "bed").count("bed"), 1)
	assert_eq(d["room_stats"]["rooms"] if d.has("room_stats") else d["density_classes"].values().count("bath"), 1)
	var map := Furnish.rooms_of(d["grid"])
	for p: Dictionary in d["props"]:
		var r: Rect2i = p["rect"]
		var ri := Furnish._at(d["grid"], map["of"], r.position)
		if map["rooms"][ri]["cells"].size() < 12:
			assert_eq(p["rule"], "bath")

func test_fallback_requires_three_rooms_and_does_not_take_only_bedroom() -> void:
	var d := _house([[5, 4, "부엌"], [4, 4, "침실"], [3, 4, "창고"]])
	var plan := Furnish.density_plan(d)
	assert_eq(plan["baths"]["0"]["reason"], "smallest_fallback")
	assert_eq(plan["baths"]["0"]["class"], "storage")
	assert_eq(plan["classes"].values().count("bed"), 1)
	var two := Furnish.density_plan(_house([[4, 4, "침실"], [3, 4, "창고"]]))
	assert_false(two["baths"]["0"]["selected"])
	var single := Furnish.density_plan(_house([[3, 3, "침실"]]))
	assert_false(single["baths"]["0"]["selected"])

func test_ground_bath_precedes_upper_bath_and_upper_is_used_if_needed() -> void:
	var d := _house([[4, 4, "침실"], [3, 3, ""]])
	var upper := _house([[2, 3, ""]], 1)
	d["levels"][1] = upper["grid"]
	assert_eq(Furnish.density_plan(d)["baths"]["0"]["level"], 0)
	var no_ground := _house([[4, 4, "침실"]])
	no_ground["levels"][1] = upper["grid"]
	assert_eq(Furnish.density_plan(no_ground)["baths"]["0"]["level"], 1)

func test_bedroom_building_without_home_name_gets_a_bath() -> void:
	var d := _house([[4, 4, "침실"], [2, 3, ""]])
	d["buildings"][0]["name"] = "가게"
	assert_true(Furnish.density_plan(d)["baths"]["0"]["selected"])

func test_office_names_and_workshops_are_work_rooms() -> void:
	for name in ["사무방", "관리실", "역무실", "서무실", "사령실", "접수실", "계량방"]:
		assert_eq(Furnish.room_class(name, {}, 0), "office", name)
	# 일터 이름은 사무실이 아니라 일터 묶음이다(바깥 건물 가구, ref-ops 대조 7).
	for name in ["작업실", "공방", "공구실"]:
		assert_eq(Furnish.room_class(name, {}, 0), "work", name)
	assert_ne(Furnish.room_class("관리인 집 안방", {}, 0), "office")

func test_preserved_storage_on_a_door_front_uses_a_short_shape_when_needed() -> void:
	var d := _house([[5, 2, "창고"]])
	d["props"].append({"kind": "hardware_rack", "rect": Rect2i(2, 2, 3, 1), "level": 0, "note": "창고의 철물 선반"})
	d["containers"]["box"] = {"cell": Vector2i(2, 2), "level": 0, "items": ["wood"]}
	var stats := Furnish.clear_fronts(d)
	assert_eq(stats["shortened"], 1)
	assert_lt((d["props"][0]["rect"] as Rect2i).get_area(), 3)
	assert_eq(d["containers"]["box"]["items"], ["wood"])
	var map := Furnish.rooms_of(d["grid"])
	assert_false(Furnish._in_front(d["props"][0]["rect"], "hardware_rack", Furnish._forbidden(d["grid"], map["of"], 0, map["rooms"][0]["cells"], {})))

func test_kitchen_run_is_connected_contains_sink_and_stove_and_scales() -> void:
	for width in [5, 8, 12]:
		var d := _house([[width, 5, "부엌"]])
		var stats := Furnish.furnish_rooms(d)
		assert_eq(stats["need_missing"], 0, str(stats["missing"]))
		var run: Dictionary = {}
		var kinds: Array = []
		for p: Dictionary in d["props"]:
			if p.get("counter_run", false):
				run[(p["rect"] as Rect2i).position] = true
				kinds.append(p["kind"])
		assert_gte(run.size(), 4)
		assert_lte(run.size(), 8)
		assert_has(kinds, "sink")
		assert_has(kinds, "cold_stove")
		if run.is_empty():
			continue
		var seen: Dictionary = {run.keys()[0]: true}
		var queue: Array = [run.keys()[0]]
		while not queue.is_empty():
			var c: Vector2i = queue.pop_back()
			for direction in Furnish.DIRS:
				var next := c + direction
				if run.has(next) and not seen.has(next):
					seen[next] = true
					queue.append(next)
		assert_eq(seen.size(), run.size())

func test_required_furniture_by_class_and_no_new_boxes() -> void:
	var expected := {"침실": ["bed"], "부엌": ["cold_stove", "sink", "counter"], "거실": ["cold_stove", "armchair"], "욕실": ["toilet", "washstand"], "사무실": ["desk", "chair"]}
	for name: String in expected:
		var d := _house([[8, 5, name]])
		var stats := Furnish.furnish_rooms(d)
		var cls := Furnish.room_class(name, {}, 0)
		assert_eq(stats["need_missing"], 0, name + str(stats["missing"]))
		for kind: String in expected[name]:
			assert_has(_kinds(d, cls), kind)
		assert_eq(d["containers"].size(), 0)

func test_doors_stairs_windows_boxes_and_paths_stay_open() -> void:
	for name in [" 침실", "부엌", "거실", "욕실", "사무실", "창고", "매장"]:
		var d := _house([[8, 6, name]])
		var g: Grid = d["grid"]
		var window := Vector2i(5, 1)
		g.set_solid(window, S.WINDOW)
		g.windows[window] = {"broken": false}
		d["stairs"] = [{"cell": Vector2i(8, 5), "low": 0, "high": 1}]
		d["containers"]["box"] = {"cell": Vector2i(3, 4), "level": 0, "items": [{"id": "wood", "n": 3}]}
		var floor_before := g.floor.duplicate()
		var map := Furnish.rooms_of(g)
		var cells: Array[Vector2i] = map["rooms"][0]["cells"]
		var stairs: Dictionary = Furnish._stairs_by_level(d)[0]
		var keys := Furnish._keys(g, map["of"], 0, cells, stairs, [Vector2i(3, 4)])
		var before := Furnish._from_first(g, map["of"], 0, keys)
		Furnish.furnish_rooms(d)
		Furnish.clear_fronts(d)
		Furnish.block_furniture(d)
		var rects: Array = []
		var forbid := Furnish._forbidden(g, map["of"], 0, cells, stairs)
		for p: Dictionary in d["props"]:
			rects.append(p["rect"])
			assert_false(Furnish._in_front(p["rect"], p["kind"], forbid), name + p["kind"])
		assert_true(Furnish._still_open(g, map["of"], 0, keys, before, rects), name)
		assert_eq(g.floor, floor_before)
		assert_eq(d["containers"].size(), 1)
		assert_eq(d["containers"]["box"]["items"], [{"id": "wood", "n": 3}])
		var seen := Furnish._from_first(g, map["of"], 0, keys)
		assert_true(Furnish._touches(Rect2i(d["containers"]["box"]["cell"], Vector2i.ONE), seen))

func test_same_seed_is_identical_and_targets_are_hard_caps() -> void:
	for name in ["침실", "부엌", "거실", "욕실", "사무실"]:
		var a := _house([[8, 6, name]])
		var b := _house([[8, 6, name]])
		Furnish.furnish_rooms(a)
		Furnish.furnish_rooms(b)
		assert_eq(var_to_str(a["props"]), var_to_str(b["props"]))
		assert_eq(a["grid"].solid, b["grid"].solid)
		var used: Dictionary = {}
		for p: Dictionary in a["props"]:
			var r: Rect2i = p["rect"]
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					assert_false(used.has(Vector2i(x, y)), "no overlap")
					used[Vector2i(x, y)] = true
		var cls := Furnish.room_class(name, {}, 0)
		assert_lte(float(used.size()) / 48, float(Furnish.DENSITY[cls][2]))

func test_new_kinds_block_only_where_they_can_be_drawn() -> void:
	for kind: String in Kinds.ROOM_SIZES:
		assert_eq(Kinds.MODELS[kind], "")
		assert_true(Furnish.blocks(kind, 0))
		assert_false(Furnish.PASS_KINDS.has(kind))
	var d := _house([[8, 5, "사무실"]], 1)
	Furnish.furnish_rooms(d)
	Furnish.block_furniture(d)
	for p: Dictionary in d["props"]:
		if not Furnish.blocks(p["kind"], 1):
			var r: Rect2i = p["rect"]
			assert_eq(d["grid"].solid_at(r.position), S.NONE, "unmodelled upper furniture is not an invisible wall")
