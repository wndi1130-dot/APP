extends GutTest
## J08: one rule for every door and window — boards on each face, latches,
## curtains, the glass on the floor — and a building's part in a stop read by
## its role, never by its place in the map's list (R09); a place with no map
## said so (R16).

const BuildingRules = preload("res://game/sim/building_rules.gd")
const DoorRules = preload("res://game/sim/door_rules.gd")
const WindowRules = preload("res://game/sim/window_rules.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldActions = preload("res://game/field_actions.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const Wear = preload("res://game/sim/wear.gd")


func _game(extra: Dictionary = {}) -> Node:
	var game = FieldGame.new()
	var opts := {"seed": 5, "raiders": false, "auto_pause": false}
	opts.merge(extra, true)
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	return game


func _finish(game, p) -> void:
	p.action_t = 0.001
	game._update_person(p, 0.1)


## A whole window of a home on the ground whose two faces can be stood on.
func _window(game) -> Vector2i:
	var keys: Array = game.grid.windows.keys()
	keys.sort()
	for c: Vector2i in keys:
		var w: Dictionary = game.grid.windows[c]
		if w["broken"] or game.grid.outer_face(c) < 0:
			continue
		var f: Array[Vector2i] = game.grid.faces(c)
		if game.grid.people_can_walk(f[0]) and game.grid.people_can_walk(f[1]):
			return c
	return Vector2i(-1, -1)


func _stand(game, p, c: Vector2i, face: int) -> void:
	p.position = FieldGrid.center(game.grid.faces(c)[face])
	p.stop()


func _door_of(game, b: int) -> Vector2i:
	var keys: Array = game.grid.doors.keys()
	keys.sort()
	for c: Vector2i in keys:
		if int(game.grid.doors[c].get("building", -1)) == b:
			return c
	return Vector2i(-1, -1)


func test_the_new_values_are_the_listed_ones() -> void:
	assert_eq([BuildingRules.PLANKS_PER_FACE, BuildingRules.SIGHT_PLANKS, BuildingRules.NAILS_PER_PLANK, BuildingRules.PLANK_HP], [4, 3, 1, 3])
	assert_eq([BuildingRules.UNBOARD_SECONDS, BuildingRules.WINDOW_SECONDS, BuildingRules.LATCH_TRY_SECONDS, BuildingRules.CURTAIN_SECONDS], [16.0, 0.5, 1.5, 0.5])
	assert_eq([BuildingRules.LATCH_STUCK_CHANCE, BuildingRules.LATCH_LIFT_WEAKEST, BuildingRules.LATCHED_SHARE, BuildingRules.CURTAIN_SHUT_SHARE, BuildingRules.BAREFOOT_GLASS_CUT], [0.1, 0.02, 0.6, 0.3, 1.0])
	assert_eq(BuildingRules.LATCH_LIFT, [[7, 0.25], [5, 0.15], [3, 0.1], [1, 0.05]])
	assert_eq(BuildingRules.CURTAIN_CLASSES.keys(), ["bed", "kitchen", "living"])
	assert_eq(FieldActions.BOARD_HP, BuildingRules.PLANK_HP, "a plank is the boarded door's three blows")
	assert_eq(BuildingRules.UNBOARD_SECONDS, FieldActions.BOARD_TIME * 2.0, "off is twice on")


func test_four_planks_a_face_both_faces_and_each_three_blows() -> void:
	var door := {"state": "closed", "hp": 2}
	for i in 4:
		assert_true(BuildingRules.can_add_plank(door, 0))
		BuildingRules.add_plank(door, 0)
	assert_false(BuildingRules.can_add_plank(door, 0), "four on a face")
	assert_true(BuildingRules.can_add_plank(door, 1), "the other face is its own")
	BuildingRules.add_plank(door, 1)
	assert_eq([BuildingRules.planks(door, 0), BuildingRules.planks(door, 1), int(door["hp"])], [4, 1, 2 + 5 * 3])
	assert_false(DoorRules.can_toggle(door, "open"), "a boarded door does not open")
	assert_false(DoorRules.can_force(door), "nor is it pried or kicked open")


func test_a_plank_off_takes_what_it_still_held() -> void:
	var door := {"state": "closed", "hp": 2}
	BuildingRules.add_plank(door, 0)
	BuildingRules.add_plank(door, 0)
	BuildingRules.wear_planks(door, 0)
	door["hp"] = int(door["hp"]) - 1
	assert_true(BuildingRules.remove_plank(door, 0))
	assert_eq([BuildingRules.planks_total(door), int(door["plank_hp"]), int(door["hp"])], [1, 3, 5], "the worn outer one went, the whole one stays")
	assert_false(BuildingRules.remove_plank(door, 1), "nothing on the other face")


func test_the_dead_break_the_planks_on_their_side_first() -> void:
	var door := {"state": "closed", "hp": 1}
	BuildingRules.add_plank(door, 0)
	BuildingRules.add_plank(door, 1)
	for i in 3:
		door["hp"] = int(door["hp"]) - 1
		BuildingRules.wear_planks(door, 1)
	assert_eq([BuildingRules.planks(door, 0), BuildingRules.planks(door, 1)], [1, 0], "the struck face gave first")
	for i in 3:
		door["hp"] = int(door["hp"]) - 1
		BuildingRules.wear_planks(door, 1)
	assert_eq(BuildingRules.planks_total(door), 0)
	assert_eq(int(door["hp"]), 1, "then the door itself")


func test_a_window_stops_the_eye_from_the_third_plank_or_a_drawn_curtain() -> void:
	var w := {"broken": true, "glass": false}
	assert_true(BuildingRules.window_passable(w))
	BuildingRules.add_plank(w, 1)
	assert_false(BuildingRules.window_passable(w), "one plank and nobody goes through")
	BuildingRules.add_plank(w, 1)
	assert_false(BuildingRules.window_opaque(w))
	BuildingRules.add_plank(w, 0)
	assert_false(BuildingRules.window_opaque(w), "two and one: still seen through")
	BuildingRules.add_plank(w, 1)
	assert_true(BuildingRules.window_opaque(w), "the third on a face")
	var c := {"broken": false, "curtain": "closed"}
	assert_true(BuildingRules.window_opaque(c))
	c["curtain"] = "open"
	assert_false(BuildingRules.window_opaque(c))
	assert_true(BuildingRules.window_passable({"broken": false, "open": true}), "an open window is gone through like a broken one")
	assert_false(WindowRules.can_break({"broken": false, "planks": [1, 0]}), "boards keep the blow off the glass")


func test_a_latch_tried_from_outside_snaps_or_lifts_by_strength() -> void:
	assert_eq(BuildingRules.try_latch(9, 0.05, 0.0), "stuck", "a tenth of the tries snap it")
	assert_eq(BuildingRules.try_latch(9, 0.5, 0.2), "open")
	assert_eq(BuildingRules.try_latch(9, 0.5, 0.3), "struggle")
	assert_eq([BuildingRules.latch_lift(10), BuildingRules.latch_lift(7), BuildingRules.latch_lift(6), BuildingRules.latch_lift(3), BuildingRules.latch_lift(1), BuildingRules.latch_lift(0)], [0.25, 0.25, 0.15, 0.1, 0.05, 0.02])


func test_faces_lie_across_the_wall_and_the_outer_one_looks_out() -> void:
	var g := FieldGrid.new(5, 5)
	for x in 5:
		g.set_solid(Vector2i(x, 2), FieldGrid.Solid.WALL)
	for y in range(3, 5):
		for x in 5:
			g.building[g.index(Vector2i(x, y))] = 0
	var c := Vector2i(2, 2)
	g.set_solid(c, FieldGrid.Solid.WINDOW)
	g.building[g.index(c)] = 0
	g.windows[c] = {"broken": false, "glass": false, "building": 0, "curtain": "open"}
	g.refresh_paths()
	assert_eq(g.faces(c), [Vector2i(2, 1), Vector2i(2, 3)])
	assert_eq(g.outer_face(c), 0)
	assert_eq(g.face_toward(c, Vector3(2.5, 0, 3.6)), 1)
	assert_true(g.line_clear(Vector2i(2, 0), Vector2i(2, 4)), "an open curtain lets the eye through")
	g.windows[c]["curtain"] = "closed"
	g.refresh_cell(c)
	assert_false(g.line_clear(Vector2i(2, 0), Vector2i(2, 4)), "a drawn one does not")
	g.windows[c]["open"] = true
	g.refresh_cell(c)
	assert_true(g.people_can_walk(c) and g.dead_can_walk(c), "the dead come through an open window too (card 2, as proposed)")


func test_every_map_keeps_its_buildings_in_id_order_or_is_found_by_id() -> void:
	for id: String in ["first_leg_01_sulechow", "houses_01", "office_01", "lake_01"]:
		var d := FieldMaps.build(id)
		for b: Dictionary in d["buildings"]:
			assert_eq(int(BuildingRules.building(d, int(b["id"]))["id"]), int(b["id"]), id)


func test_the_first_stops_rooms_are_read_by_role_not_by_number() -> void:
	var d := FieldMaps.build(FieldMaps.DEFAULT_PLACE)
	assert_eq(BuildingRules.role_of(d, 3), "raider_den")
	assert_eq(BuildingRules.role_of(d, 1), "lookout")
	assert_eq(BuildingRules.role_of(d, 0), "")


func test_the_raiders_hear_the_den_door_by_its_role_wherever_the_den_is() -> void:
	var game = _game()
	var r = game.make_person({"id": "r_test", "name": "약탈자", "role": "raider", "skills": {"strength": 5, "melee": 1, "shooting": 0, "stealth": 1, "search": 1}, "hands": []}, Vector3(5, 0, 5))
	r.team = "raider"
	r.brain = {"state": "idle"}
	game.raiders.append(r)
	var shop := _door_of(game, 2)
	assert_ne(shop, Vector2i(-1, -1))
	game.actions._check_raider_door(shop)
	assert_false(r.brain.has("aware"), "the shop is not the den")
	# The den moved to the shop and the pharmacy is only a pharmacy: the shop's door is heard.
	BuildingRules.building(game.data, 3)["role"] = ""
	BuildingRules.building(game.data, 2)["role"] = "raider_den"
	game.actions._check_raider_door(_door_of(game, 3))
	assert_false(r.brain.has("aware"), "the pharmacy's number no longer means anything")
	game.actions._check_raider_door(shop)
	assert_almost_eq(float(r.brain.get("aware", 0.0)), 0.6, 0.001)


func test_boarding_a_window_from_inside_and_the_plank_off_again() -> void:
	var game = _game()
	game.zombies.list.clear()
	var p = game.player
	var c := _window(game)
	assert_ne(c, Vector2i(-1, -1), "a window to work at")
	var inner: int = 1 - game.grid.outer_face(c)
	_stand(game, p, c, inner)
	p.add_item("plank", 3)
	p.add_item("nails", 3)
	for i in 3:
		assert_true(game.actions.can_board_window(p, c))
		game.actions.board_window(p, c)
		assert_eq(p.action, "craft")
		_finish(game, p)
	var w: Dictionary = game.grid.windows[c]
	assert_eq([BuildingRules.planks(w, inner), BuildingRules.planks(w, 1 - inner)], [3, 0])
	assert_true(game.grid.opaque(c), "three planks and the eye stops")
	assert_false(game.grid.people_can_walk(c))
	assert_false(game.actions.can_unboard(p, c), "no bar in hand")
	p.hands = [{"id": "crowbar", "quality": "factory", "condition": 1.0, "loaded": 0}]
	assert_true(game.actions.can_unboard(p, c))
	var heard: int = game.ledger.sound_events
	game.actions.unboard(p, c)
	assert_almost_eq(p.action_total, BuildingRules.UNBOARD_SECONDS, 0.001)
	_finish(game, p)
	assert_eq(BuildingRules.planks(w, inner), 2)
	assert_eq(int(p.items.get("plank", 0)), 1, "the plank comes back")
	assert_eq(int(p.items.get("nails", 0)), 0, "its nail does not")
	assert_gt(game.ledger.sound_events, heard, "quiet, but heard close by")
	assert_false(game.grid.opaque(c), "two planks: seen through again")


func test_the_far_faces_planks_are_kicked_off_and_ones_own_pried() -> void:
	var game = _game()
	game.zombies.list.clear()
	var p = game.player
	var c := _door_of(game, 4)
	assert_ne(c, Vector2i(-1, -1))
	game.grid.set_door_state(c, "closed")
	var door: Dictionary = game.grid.doors[c]
	BuildingRules.add_plank(door, 1)
	game.grid.refresh_cell(c)
	p.position = FieldGrid.center(game.grid.faces(c)[0])
	p.stop()
	assert_false(game.grid.people_can_walk(c))
	assert_true(game.actions._far_planks_only(p, c))
	for i in 20:
		if BuildingRules.planks_total(door) == 0:
			break
		game.actions.kick_door(p, c)
		assert_eq(p.action, "kick")
		_finish(game, p)
	assert_eq(BuildingRules.planks_total(door), 0, "kicked off from the far side")
	assert_eq(String(door["state"]), "closed", "the door itself still there")


func test_glass_falls_on_the_far_side_and_cuts_only_a_bare_foot() -> void:
	var game = _game()
	game.zombies.list.clear()
	var p = game.player
	var c := _window(game)
	var inner: int = 1 - game.grid.outer_face(c)
	_stand(game, p, c, inner)
	game.actions._break_window(p, c)
	var outside: Vector2i = game.grid.faces(c)[1 - inner]
	assert_true(game.grid.floor_glass.has(outside), "outside, away from the one who broke it")
	assert_false(game.grid.floor_glass.has(game.grid.faces(c)[inner]))
	var row: Dictionary = BuildingRules.building(game.data, int(game.grid.windows[c]["building"]))
	assert_true(bool(row["window_broken"]), "the warmth goes out of it")
	# Booted: only the crunch.
	var heard: int = game.ledger.sound_events
	var wounds: int = p.body.wounds.size()
	p.position = FieldGrid.center(outside)
	game.actions._glass_steps()
	assert_eq(game.ledger.sound_events, heard + 1)
	assert_eq(p.body.wounds.size(), wounds)
	game.actions._glass_steps()
	assert_eq(game.ledger.sound_events, heard + 1, "one crunch a step onto the cell")
	# Barefoot onto it again: a cut.
	p.position = FieldGrid.center(game.grid.faces(c)[inner])
	game.actions._glass_steps()
	Wear.take_off(p, "shoes")
	assert_true(Wear.barefoot(p))
	p.position = FieldGrid.center(outside)
	game.actions._glass_steps()
	assert_gt(p.body.wounds.size(), wounds, "the bare foot is cut")
	# Swept, it is gone.
	game.actions.sweep_glass(p, outside)
	_finish(game, p)
	assert_false(game.grid.floor_glass.has(outside))


func test_boarding_a_broken_window_to_the_third_plank_keeps_the_warmth_again() -> void:
	var game = _game()
	game.zombies.list.clear()
	var p = game.player
	var c := _window(game)
	var inner: int = 1 - game.grid.outer_face(c)
	_stand(game, p, c, inner)
	game.actions._break_window(p, c)
	var b: int = int(game.grid.windows[c]["building"])
	assert_true(game.building_open(b))
	p.add_item("plank", 3)
	p.add_item("nails", 3)
	for i in 3:
		game.actions.board_window(p, c)
		_finish(game, p)
	assert_false(game.building_open(b) and not BuildingRules.lets_cold_in(game.data.get("levels", {0: game.grid}), b), "boarded up, it keeps the warmth unless another window lets the cold in")
	assert_eq(bool(BuildingRules.building(game.data, b)["window_broken"]), BuildingRules.lets_cold_in(game.data.get("levels", {0: game.grid}), b))


func test_a_window_opens_quietly_from_inside_and_is_a_struggle_from_outside() -> void:
	var game = _game()
	game.zombies.list.clear()
	var p = game.player
	var c := _window(game)
	var w: Dictionary = game.grid.windows[c]
	var outer: int = game.grid.outer_face(c)
	w["latched"] = true
	_stand(game, p, c, 1 - outer)
	assert_false(game.actions.latched_against(p, c), "inside, the latch is just lifted")
	var heard: int = game.ledger.sound_events
	game.actions.open_window(p, c)
	assert_almost_eq(p.action_total, BuildingRules.WINDOW_SECONDS, 0.001)
	_finish(game, p)
	assert_true(bool(w["open"]))
	assert_false(bool(w["latched"]))
	assert_eq(game.ledger.sound_events, heard, "no sound")
	assert_true(game.grid.people_can_walk(c))
	game.actions.close_window(p, c)
	_finish(game, p)
	assert_false(bool(w["open"]))
	# Outside and latched: tries until it gives or snaps.
	w["latched"] = true
	_stand(game, p, c, outer)
	assert_true(game.actions.latched_against(p, c))
	game.actions.open_window(p, c)
	var tries := 0
	while p.action != "" and tries < 400:
		assert_almost_eq(p.action_total, BuildingRules.LATCH_TRY_SECONDS, 0.001)
		_finish(game, p)
		tries += 1
	assert_true(bool(w["open"]) or bool(w["stuck"]), "it gave, or the latch snapped")
	if bool(w["stuck"]):
		assert_false(BuildingRules.can_open(w), "snapped: only breaking opens it")
		assert_true(WindowRules.can_break(w))


func test_a_curtain_is_drawn_and_nobody_sees_through_that_window() -> void:
	var game = _game()
	game.zombies.list.clear()
	var p = game.player
	var c := _window(game)
	var w: Dictionary = game.grid.windows[c]
	w["curtain"] = "open"
	game.grid.refresh_cell(c)
	_stand(game, p, c, 1 - game.grid.outer_face(c))
	assert_false(game.grid.opaque(c))
	game.actions.toggle_curtain(p, c)
	assert_almost_eq(p.action_total, BuildingRules.CURTAIN_SECONDS, 0.001)
	_finish(game, p)
	assert_eq(String(w["curtain"]), "closed")
	assert_true(game.grid.opaque(c))


func test_windows_get_latches_and_home_rooms_curtains_fixed_per_map() -> void:
	var a := FieldMaps.build("houses_01")
	var b := FieldMaps.build("houses_01")
	var latched := 0
	var whole := 0
	var curtains := 0
	var g: FieldGrid = a["levels"][0]
	var g2: FieldGrid = b["levels"][0]
	for c: Vector2i in g.windows:
		var w: Dictionary = g.windows[c]
		assert_eq([w["latched"], w.get("curtain", "")], [g2.windows[c]["latched"], g2.windows[c].get("curtain", "")], "same map, same windows")
		if not w["broken"]:
			whole += 1
			latched += 1 if w["latched"] else 0
		curtains += 1 if BuildingRules.has_curtain(w) else 0
		assert_false(bool(w["open"]))
	assert_gt(whole, 20)
	assert_almost_eq(float(latched) / whole, BuildingRules.LATCHED_SHARE, 0.15)
	assert_gt(curtains, 0, "a home's rooms have curtains")


func test_a_place_with_no_map_is_played_on_the_default_and_noted() -> void:
	var game = _game({"place": "nowhere_01"})
	assert_eq(game.place, FieldMaps.DEFAULT_PLACE)
	assert_eq(String(game.receipt.to_dict()["placeState"].get("placeAsked", "")), "nowhere_01")
	var known = _game({"place": FieldMaps.DEFAULT_PLACE})
	assert_false(known.receipt.to_dict()["placeState"].has("placeAsked"), "a real place is not noted")
