extends "res://addons/gut/test.gd"
## Night lights people left (decision 471 B4) and the lamp pools out of doors
## showing through the sight mask (decision 474 B9).

const NightLights = preload("res://game/world/night_lights.gd")
const NightLightView = preload("res://game/world/night_light_view.gd")
const LampLight = preload("res://game/sim/lamp_light.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldGame = preload("res://game/field_game.gd")

const S = FieldGrid.Solid


## 60 × 40 칸 마을 하나: 집 둘(창이 바깥을 봄), 마당에 드럼통 셋·차 하나·장작더미 하나.
func _town() -> Dictionary:
	var g := FieldGrid.new(60, 40)
	var buildings := []
	for b in 2:
		var r := Rect2i(5 + b * 30, 5, 10, 8)
		buildings.append({"id": b, "role": "home", "rect": r})
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				g.building[g.index(c)] = b
				if x == r.position.x or y == r.position.y or x == r.end.x - 1 or y == r.end.y - 1:
					g.set_solid(c, S.WALL)
		var w := Vector2i(r.position.x + 4, r.end.y - 1)
		g.set_solid(w, S.WINDOW)
		g.windows[w] = {"broken": false, "glass": true, "building": b, "curtain": "open"}
	var props := [
		{"kind": "barrel", "rect": Rect2i(4, 25, 1, 1), "level": 0},
		{"kind": "barrel", "rect": Rect2i(25, 30, 1, 1), "level": 0},
		{"kind": "barrel", "rect": Rect2i(52, 25, 1, 1), "level": 0},
		{"kind": "car", "rect": Rect2i(40, 33, 4, 2), "level": 0},
		{"kind": "firewood_pile", "rect": Rect2i(18, 20, 2, 1), "level": 0},
		{"kind": "barrel", "rect": Rect2i(7, 7, 1, 1), "level": 0},   # indoors: never lit
	]
	for p: Dictionary in props:
		var r: Rect2i = p["rect"]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if g.solid_at(Vector2i(x, y)) == S.NONE:
					g.set_solid(Vector2i(x, y), S.BLOCK)
	return {"grid": g, "props": props, "buildings": buildings, "lights": [], "place_id": "test_town"}


func _night_rows(d: Dictionary) -> Array:
	return (d["lights"] as Array).filter(func(l: Dictionary) -> bool: return NightLights.KINDS.has(String(l["kind"])))


func test_a_town_gets_three_to_six_spread_out_lights() -> void:
	var d := _town()
	var n := NightLights.plan(d)
	var rows := _night_rows(d)
	assert_eq(rows.size(), n)
	assert_between(n, 3, NightLights.MOST)
	var kinds := {}
	for i in rows.size():
		var l: Dictionary = rows[i]
		kinds[l["kind"]] = true
		assert_eq(String(l["when"]), "dusk")
		assert_false((d["grid"] as FieldGrid).indoor(l["cell"]) and l["kind"] != "candle", "%s out of doors" % l["id"])
		for j in range(i + 1, rows.size()):
			assert_gte(Vector2(l["cell"] - rows[j]["cell"]).length(), NightLights.SPREAD, "spread out")
	assert_gte(kinds.size(), 3, "more than one kind of light")
	assert_false(_has_cell(rows, Vector2i(7, 7)), "the drum indoors is not lit")


func _has_cell(rows: Array, c: Vector2i) -> bool:
	for l: Dictionary in rows:
		if l["cell"] == c:
			return true
	return false


func test_the_same_map_always_gets_the_same_lights() -> void:
	var a := _town()
	var b := _town()
	NightLights.plan(a)
	NightLights.plan(b)
	assert_eq(str(_night_rows(a)), str(_night_rows(b)))


func test_a_map_with_its_own_rows_keeps_them_and_no_fire_means_no_fire() -> void:
	var own := _town()
	own["lights"].append({"id": "mine", "kind": "candle", "cell": Vector2i(9, 12), "when": "dusk", "from_min": 890})
	assert_eq(NightLights.plan(own), 0)
	assert_eq(_night_rows(own).size(), 1)
	var calm := _town()
	calm["no_fire"] = true
	NightLights.plan(calm)
	for l: Dictionary in _night_rows(calm):
		assert_false(NightLights.FIRES.has(String(l["kind"])), "%s is a fire" % l["kind"])
	# Marked after the map was built (by its place on the route): planned again.
	var late := _town()
	NightLights.plan(late)
	late["no_fire"] = true
	assert_gt(NightLights.replan(late), 0)
	for l: Dictionary in _night_rows(late):
		assert_false(NightLights.FIRES.has(String(l["kind"])), "%s is a fire" % l["kind"])


func test_a_light_out_of_doors_keeps_off_the_floor_past_the_wall() -> void:
	var d := _town()
	var g: FieldGrid = d["grid"]
	var out: Dictionary = {}
	# A drum fire right outside the first house's south wall.
	LampLight.stamp(out, g.width, g.height, Vector2i(9, 14), Vector2i.ZERO, 1.0, 5.0, {}, g)
	assert_gt(int(out.get(g.index(Vector2i(9, 15)), 0)), 0)
	assert_eq(int(out.get(g.index(Vector2i(9, 11)), 0)), 0, "the room inside stays dark")


func test_the_torch_throws_a_beam_ahead_not_behind_or_aside() -> void:
	var cells: Dictionary = {}
	var at := Vector2i(30, 20)
	LampLight.beam(cells, 60, 40, at, Vector2(1, 0), 0.85, 13.0, 27.0)
	assert_gt(int(cells.get(20 * 60 + 40, 0)), 0, "ten metres ahead")
	assert_gt(int(cells.get(20 * 60 + 33, 0)), int(cells.get(20 * 60 + 40, 0)), "brighter near the hand")
	assert_eq(int(cells.get(20 * 60 + 25, 0)), 0, "nothing behind")
	assert_eq(int(cells.get(26 * 60 + 34, 0)), 0, "nothing far off its line")
	assert_eq(int(cells.get(20 * 60 + 44, 0)), 0, "none past its reach")
	var walled: Dictionary = {}
	LampLight.beam(walled, 60, 40, at, Vector2(1, 0), 0.85, 13.0, 27.0, {20 * 60 + 33: true})
	assert_eq(walled.size(), 1, "only where the eye could reach")


func test_a_real_town_map_gets_its_night_lights() -> void:
	var d := FieldMaps.build("houses_01")
	assert_between(_night_rows(d).size(), 3, NightLights.MOST)


func test_the_view_lights_them_at_dusk_only() -> void:
	var d := _town()
	NightLights.plan(d)
	var view := NightLightView.new()
	add_child_autofree(view)
	view.build(d)
	var rows := _night_rows(d)
	for l: Dictionary in rows:
		assert_false(view.is_on(String(l["id"])), "out by day")
	for l: Dictionary in rows:
		view.set_on(String(l["id"]), LampLight.is_on(l, 900.0, false, false))
	for l: Dictionary in rows:
		assert_true(view.is_on(String(l["id"])), "lit at dusk")
	# Their light on the ground: out of doors ones keep off the rooms.
	var cells := LampLight.fixed_cells(d["lights"], 60, 40, 900.0, false, false, d["grid"])
	assert_gt(cells.size(), 0)
	for i in cells:
		var c := Vector2i(int(i) % 60, int(i) / 60)
		if (d["grid"] as FieldGrid).indoor(c):
			assert_true(_near_candle(rows, c), "%s indoors is lit only by a candle" % c)


func _near_candle(rows: Array, c: Vector2i) -> bool:
	for l: Dictionary in rows:
		if l["kind"] == "candle" and Vector2(c - l["cell"]).length() < float(NightLights.LIGHT["candle"]["reach"]):
			return true
	return false
