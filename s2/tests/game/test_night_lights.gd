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
	# A 4.7 ha town gets more than a small map's six (T0-9: one on screen in three at night before).
	assert_between(_night_rows(d).size(), NightLights.MOST + 1, NightLights.most_for(d["grid"]))


func test_the_most_grows_with_the_map_up_to_twelve() -> void:
	assert_eq(NightLights.most_for(FieldGrid.new(60, 40)), NightLights.MOST, "a small map keeps six")
	assert_eq(NightLights.most_for(FieldGrid.new(170, 100)), NightLights.MOST)
	assert_eq(NightLights.most_for(FieldGrid.new(210, 146)), 7)
	assert_eq(NightLights.most_for(FieldGrid.new(230, 205)), 11)
	assert_eq(NightLights.most_for(FieldGrid.new(400, 400)), NightLights.MOST_BIG)


## A wide yard with a train along the top and the crew stepping down at
## (40, 4): drums in a row far off and one on the first screen.
func _yard(w: int, h: int, far: Array, first: Vector2i, place: String) -> Dictionary:
	var g := FieldGrid.new(w, h)
	var props := []
	for c: Vector2i in far + [first]:
		props.append({"kind": "barrel", "rect": Rect2i(c, Vector2i.ONE), "level": 0})
		g.set_solid(c, S.BLOCK)
	return {"grid": g, "props": props, "buildings": [], "lights": [], "place_id": place,
		"train": Rect2i(0, 0, w, 2), "spawns": {"squad": [Vector2i(40, 4)]}}


const FAR_DRUMS := [Vector2i(5, 60), Vector2i(17, 60), Vector2i(29, 60), Vector2i(41, 60), Vector2i(53, 60)]


func test_the_first_screen_gets_none_to_two_as_the_map_dice_fall() -> void:
	var first := Vector2i(52, 14)   # 16 m from where the crew steps down
	var counts := {}
	for i in 12:
		# 3.2 ha: eight at most, three drums (two before, one more of its share).
		var d := _yard(180, 180, FAR_DRUMS, first, "yard_%d" % i)
		NightLights.replan(d)
		var rows := _night_rows(d)
		assert_eq(rows.size(), 3, "yard_%d: three drums" % i)
		var n := NightLights.first_count(d)
		assert_between(n, 0, NightLights.FIRST_MOST)
		counts[n] = true
		if n > 0:
			assert_true(_has_cell(rows, first), "yard_%d: the drum on the first screen is lit" % i)
	assert_true(counts.has(0) and counts.size() > 1, "some first screens dark, some lit: %s" % str(counts.keys()))


func test_the_first_screen_never_holds_more_than_two() -> void:
	# A big yard (most twelve, four drums) with five drums round where the crew steps down.
	var near := [Vector2i(30, 16), Vector2i(52, 14), Vector2i(62, 26), Vector2i(18, 26), Vector2i(40, 30)]
	var far: Array = []
	for i in 6:
		far.append(Vector2i(20 + i * 30, 150))
	for i in 12:
		var d := _yard(240, 210, far + near.slice(1), near[0], "crowd_%d" % i)
		NightLights.replan(d)
		var on := 0
		for l: Dictionary in _night_rows(d):
			on += 1 if Vector2(l["cell"] - Vector2i(40, 4)).length() <= NightLights.FIRST_SCREEN else 0
		assert_lte(on, NightLights.FIRST_MOST, "crowd_%d" % i)


func test_two_of_a_kind_can_go_first() -> void:
	var near := [Vector2i(52, 14), Vector2i(30, 16)]   # both 16 m from where the crew steps down
	for i in 12:
		var d := _yard(240, 210, FAR_DRUMS + [near[1]], near[0], "pair_%d" % i)
		NightLights.replan(d)
		var rows := _night_rows(d)
		var lit := 0
		for c: Vector2i in near:
			lit += 1 if _has_cell(rows, c) else 0
		assert_gte(lit, NightLights.first_count(d), "pair_%d" % i)


func test_the_first_screen_takes_none_more_once_it_holds_two_of_any_kind() -> void:
	# The base plan's lights stay where they were (it keeps no first screen of its
	# own); a fire and a candle of it already there leave the share no room: the
	# drum 16 m off stays dark and the rest goes further off.
	for i in 6:
		var d := _yard(240, 210, FAR_DRUMS, Vector2i(52, 14), "mixed_%d" % i)
		d["lights"] = [
			{"id": "night_1_campfire", "kind": "campfire", "cell": Vector2i(45, 15)},
			{"id": "night_2_candle", "kind": "candle", "cell": Vector2i(30, 20)},
		]
		assert_gt(NightLights.extend(d), 0, "mixed_%d: the share goes further off" % i)
		var rows := _night_rows(d)
		var on := 0
		for l: Dictionary in rows:
			on += 1 if Vector2(l["cell"] - Vector2i(40, 4)).length() <= NightLights.FIRST_SCREEN else 0
		assert_eq(on, 2, "mixed_%d: the two it had, none more" % i)
		assert_false(_has_cell(rows, Vector2i(52, 14)), "mixed_%d: the drum near the crew stays dark" % i)


func test_a_big_map_adds_to_what_it_had_and_keeps_off_the_train() -> void:
	var far: Array = []
	for i in 8:
		far.append(Vector2i(10 + i * 25, 120))
	var d := _yard(240, 210, far, Vector2i(52, 5), "keeps")   # the last drum 4 cells off the train
	d["lights"] = [{"id": "night_1_barrel_fire", "kind": "barrel_fire", "cell": far[3]}]
	var added := NightLights.extend(d)
	var rows := _night_rows(d)
	assert_gt(added, 0, "a 5 ha map's share")
	assert_true(_has_cell(rows, far[3]), "the light it had stays where it was")
	assert_false(_has_cell(rows, Vector2i(52, 5)), "none added by the train: it has its own lights")
	# A map's own rows of these kinds: it keeps them and gets none.
	var own := _yard(240, 210, far, Vector2i(52, 5), "own")
	own["lights"] = [{"id": "mine", "kind": "candle", "cell": Vector2i(9, 12)}]
	assert_eq(NightLights.extend(own), 0)


func test_the_lights_follow_a_moved_stop() -> void:
	# A stop form moves the train and the crew (stop_ground.gd): planned again round them.
	var lit_any := false
	for i in 12:
		var m := _yard(240, 210, FAR_DRUMS, Vector2i(52, 14), "moved_%d" % i)
		NightLights.replan(m)
		m["spawns"] = {"squad": [Vector2i(29, 70)]}
		m["train"] = Rect2i(0, 76, 240, 2)
		NightLights.follow(m)
		var near := 0
		var on := 0
		for l: Dictionary in _night_rows(m):
			var d: float = Vector2(l["cell"] - Vector2i(29, 70)).length()
			near += 1 if d <= NightLights.FIRST_REACH else 0
			on += 1 if d <= NightLights.FIRST_SCREEN else 0
		# Lit as the dice fell, unless the lights it had already fill its far corners.
		assert_true(near >= NightLights.first_count(m) or on >= NightLights.FIRST_MOST, "moved_%d: the new first screen" % i)
		lit_any = lit_any or NightLights.first_count(m) > 0
	assert_true(lit_any, "some map of 12 lights its first screen")


func test_a_big_map_lights_more_of_a_kind() -> void:
	var far: Array = []
	for i in 8:
		far.append(Vector2i(10 + i * 25, 120))
	var d := _yard(240, 210, far, Vector2i(120, 40), "big")
	NightLights.replan(d)
	# 5 ha: twelve at most, a drum's two grow to four.
	assert_eq(_night_rows(d).size(), 4)


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


func test_at_night_the_eye_sees_what_a_light_shows_past_its_reach() -> void:
	# Decision 479: past the short night reach, a lit cell with no wall between
	# is seen (the dead by a fire), an unlit one at the same distance is not.
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "weather": ["clear"]}
	add_child_autofree(game)
	game.set_process(false)
	game.clock.elapsed = (1000.0 - 630.0) * 60.0 / 15.0
	var g: FieldGrid = game.grid
	var origin := FieldGrid.cell_of(game.player.position)
	var lit := Vector2i(-1, -1)
	var dark := Vector2i(-1, -1)
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var a := origin + d * 14
		var b := origin + d * 14 + Vector2i(d.y, d.x) * 3
		if g.inside(a) and g.inside(b) and not g.indoor(a) and not g.indoor(b) and g.line_clear(origin, a) and g.line_clear(origin, b):
			lit = a
			dark = b
			game.player.facing = atan2(float(d.x), float(d.y))
			break
	assert_ne(lit, Vector2i(-1, -1), "an open line 14 cells out from the chief")
	game.data["lights"].append({"id": "test_fire", "kind": "barrel_fire", "cell": lit, "side": Vector2i.ZERO, "strength": 1.0, "falls": 0.9, "reach": 2.0, "outdoor": true, "when": "always", "from_min": 0})
	game.lamp_key = "-"
	game._refresh_vision()
	assert_true(game.seen_now.has(game.seen_key(FieldGrid.center(lit))), "the fire 14 cells out is seen")
	assert_false(game.seen_now.has(game.seen_key(FieldGrid.center(dark))), "the dark ground beside it is not")
