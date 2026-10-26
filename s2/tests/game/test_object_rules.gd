extends GutTest
## J08 furniture and contained stove fuel. The real first stop and houses_01
## provide rooms, doors, furnishings and containers; no loot tables are changed.

const Rules = preload("res://game/sim/object_rules.gd")
const Building = preload("res://game/sim/building_rules.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const Grid = preload("res://game/world/field_grid.gd")
const Lamp = preload("res://game/sim/lamp_light.gd")
const SimNoise = preload("res://game/sim/noise.gd")


func _game(place: String = FieldMaps.DEFAULT_PLACE) -> Node:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "place": place, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	return game


func _finish(game) -> void:
	game.player.action_t = 0.001
	game._update_person(game.player, 0.1)


## Find an actual push in a map, from beside its destination rather than
## standing on the square the wardrobe is about to cover.
func _push_site(game) -> Dictionary:
	var p = game.player
	for lv: int in game.levels:
		var g = game.levels[lv]
		for c: Vector2i in g.doors:
			for front: Vector2i in g.faces(c):
				for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
					var stand: Vector2i = front + offset
					if not g.people_can_walk(stand) or g.blocks_body(stand):
						continue
					p.position = game.lift(stand, lv)
					var plan := Rules.push_plan(game, p, c)
					if not plan.is_empty():
						plan["stand"] = p.position
						return plan
	return {}


func _box(game, prop: Dictionary) -> Dictionary:
	var boxes := Rules.boxes_of(game.data, prop)
	if not boxes.is_empty():
		return boxes[0]
	var r: Rect2i = prop["rect"]
	var box := {"id": "object_test_box", "name": "선반 안", "cell": r.position,
		"level": prop.get("level", 0), "building": prop.get("building", -1),
		"furniture": prop["kind"], "items": ["plank", "plank", "food_pack"],
		"locked": false, "searched": false, "search": 3.0}
	game.data["containers"][box["id"]] = box
	game.view.add_container(box["id"])
	return box


func _assert_prop_view(game, prop: Dictionary, removed: bool = false) -> void:
	var count := 0
	var r: Rect2i = prop["rect"]
	var middle := Vector2(r.position) + Vector2(r.size) * 0.5
	for batch: Dictionary in game.view.prop_batches.values():
		for item: Dictionary in batch["items"]:
			if is_same(item.get("prop", {}), prop):
				count += 1
				assert_eq(item["rect"], r)
				var xf: Transform3D = item["xf"]
				assert_almost_eq(xf.origin.x, middle.x, 0.001)
				assert_almost_eq(xf.origin.z, middle.y, 0.001)
				for node: MultiMeshInstance3D in batch["nodes"].values():
					assert_eq(node.multimesh.instance_count, batch["items"].size())
	for row: Dictionary in game.view.object_gray:
		if is_same(row["prop"], prop):
			count += 1
			var bounds: AABB = row["node"].mesh.get_aabb()
			assert_almost_eq(bounds.get_center().x, middle.x, 0.001)
			assert_almost_eq(bounds.get_center().z, middle.y, 0.001)
	assert_eq(count, 0 if removed else 1, "exactly one updated drawing, or none after removal")


func test_values_are_fixed_and_only_the_named_wood_is_usable() -> void:
	assert_eq(Rules.PUSH_KINDS, {"wardrobe": 9, "bookcase": 6, "shelf": 3})
	assert_eq(Rules.LEGACY_KINDS, {"wardrobe": "wardrobe", "bookcase": "bookcase", "shop_shelf": "shelf", "dining_set": "dining_set"})
	assert_eq(Rules.LEGACY_BOXES, {"waiting_bench": "bench", "shed_crates": "crate_stack"})
	assert_eq(Rules.WOOD_KINDS, ["wardrobe", "bookcase", "shelf", "bed", "bench", "dining_set", "blanket_chest", "crate_stack"])
	assert_eq([Rules.PUSH_REACH, Rules.USE_REACH, Rules.PUSH_BASE_SECONDS, Rules.PUSH_CELL_SECONDS], [6.0, 1.7, 4.0, 2.0])
	assert_eq([Rules.BREAK_BASE_SECONDS, Rules.BREAK_CELL_SECONDS, Rules.LIGHT_SECONDS, Rules.FUEL_CAP], [7.5, 2.5, 2.0, 600.0])
	assert_eq([Rules.PUSH_NOISE, Rules.BREAK_NOISE, Rules.LIGHT_NOISE], [SimNoise.Level.NORMAL, SimNoise.Level.LOUD, SimNoise.Level.QUIET])
	assert_eq(Rules.FUEL_SECONDS, {"plank": 60.0, "wood": 120.0})
	assert_eq([Rules.PLANKS_PER_CELL, Rules.LIGHT_REACH, Rules.LIGHT_STRENGTH], [1, 4.0, 0.7])
	assert_eq(Rules.HEAP_SEARCH_SECONDS, 1.0)
	assert_eq(Rules.plank_yield({"rect": Rect2i(1, 1, 2, 3)}), 6)
	assert_eq(Rules.push_seconds({"rect": Rect2i(1, 1, 2, 3)}), 16.0)
	assert_eq(Rules.break_seconds({"rect": Rect2i(1, 1, 2, 3)}), 22.5)


func test_push_and_remove_preserve_boxes_and_stop_opening_and_kicking() -> void:
	for place in [FieldMaps.DEFAULT_PLACE, "houses_01"]:
		var model_setting: bool = ProjectSettings.get_setting("visuals/prop_models_enabled", true)
		if place == FieldMaps.DEFAULT_PLACE:
			ProjectSettings.set_setting("visuals/prop_models_enabled", false)
		var game = _game(place)
		var plan := _push_site(game)
		assert_false(plan.is_empty(), place + " has a real same-room push")
		if plan.is_empty():
			ProjectSettings.set_setting("visuals/prop_models_enabled", model_setting)
			continue
		var prop: Dictionary = plan["prop"]
		var old: Rect2i = prop["rect"]
		var box := _box(game, prop)
		var box_cell: Vector2i = box["cell"]
		var contents: Array = box["items"].duplicate(true)
		var lv: int = plan["level"]
		var g = game.levels[lv]
		var door: Dictionary = g.doors[plan["door"]]
		var hp: int = door["hp"]
		assert_has(game.actions.context(game.player).map(func(row): return row["label"]), "가구로 문 막기")
		game.actions.push_furniture(game.player, plan["door"])
		assert_eq(game.player.action, "craft")
		assert_eq(game.player.action_total, Rules.push_seconds(prop))
		assert_true(bool(box.get("busy", false)), "contents cannot be searched from the old position while moving")
		assert_eq(game.sounds[-1]["level"], Rules.PUSH_NOISE)
		_finish(game)
		assert_true(Building.has_brace(door))
		assert_eq(prop["rect"], plan["rect"])
		_assert_prop_view(game, prop)
		assert_eq(door["hp"], hp + int(Rules.PUSH_KINDS[prop["kind"]]))
		assert_has(game.actions.context(game.player).map(func(row): return row["label"]), "가구 치우기")
		assert_true(is_same(box, game.data["containers"][box["id"]]))
		assert_false(bool(box.get("busy", false)))
		assert_eq(box["items"], contents)
		assert_true((prop["rect"] as Rect2i).has_point(box["cell"]))
		for c in Rules.cells(old):
			if not (prop["rect"] as Rect2i).has_point(c):
				assert_false(g.blocks_body(c), "old footprint clear")
		for c in Rules.cells(prop["rect"]):
			assert_true(g.blocks_body(c), "new footprint blocks")
		var normal: Vector2i = g.faces(plan["door"])[0] - plan["door"]
		var r: Rect2i = prop["rect"]
		assert_true(r.size.x >= r.size.y if normal.y != 0 else r.size.y >= r.size.x, "parallel to wall")
		game.player.position = game.lift(g.faces(plan["door"])[1 - int(plan["face"])], lv)
		assert_false(Rules.can_remove(game, game.player, plan["door"]))
		if lv == 0:
			game.actions.door_default(game.player, plan["door"], "")
			assert_eq(game.player.action, "", "far face cannot begin opening")
			game.actions.kick_door(game.player, plan["door"])
			assert_eq(game.player.action, "", "far face cannot kick through furniture")
		game.player.position = plan["stand"]
		game.actions.remove_furniture(game.player, plan["door"])
		_finish(game)
		assert_false(Building.has_brace(door))
		assert_eq(prop["rect"], old)
		_assert_prop_view(game, prop)
		assert_eq(box["cell"], box_cell)
		assert_eq(box["items"], contents)
		assert_eq(door["hp"], hp)
		assert_false(bool(door["busy"]))
		if place == FieldMaps.DEFAULT_PLACE:
			# Existing boards do not prevent pushing. An occupied home makes the
			# piece move just aside, with the same box, instead of crushing it.
			Building.add_plank(door, 0)
			Building.add_plank(door, 1)
			game.actions.push_furniture(game.player, plan["door"])
			_finish(game)
			assert_true(Building.has_brace(door))
			assert_eq(Building.planks_total(door), 2)
			game.data["containers"]["occupied_home"] = {"id": "occupied_home", "name": "상자", "cell": old.position,
				"level": lv, "items": [], "searched": true, "locked": false, "search": 1.0}
			var aside: Rect2i = Rules.for_game(game).return_rect(prop, plan["door"])
			assert_ne(aside.size, Vector2i.ZERO, "there is a spare cell beside this doorway")
			game.actions.remove_furniture(game.player, plan["door"])
			_finish(game)
			assert_eq(prop["rect"], aside)
			assert_ne(prop["rect"], old)
			assert_true(aside.has_point(box["cell"]))
			assert_eq(box["items"], contents)
			assert_false(g.blocks_body(g.faces(plan["door"])[plan["face"]]))
			game.data["containers"].erase("occupied_home")
		ProjectSettings.set_setting("visuals/prop_models_enabled", model_setting)


func test_destination_rejects_people_boxes_stairs_and_other_rooms() -> void:
	var game = _game("houses_01")
	var plan := _push_site(game)
	assert_false(plan.is_empty())
	if plan.is_empty():
		return
	var prop: Dictionary = plan["prop"]
	var dest: Rect2i = plan["rect"]
	var room: int = plan["room"]
	assert_true(Rules.free_rect(game, prop, dest, room))
	game.player.position = game.lift(dest.position, plan["level"])
	assert_false(Rules.free_rect(game, prop, dest, room), "the pusher is not crushed")
	game.player.position = plan["stand"]
	var box := {"id": "block", "cell": dest.position, "level": plan["level"]}
	game.data["containers"]["block"] = box
	assert_false(Rules.free_rect(game, prop, dest, room), "loose box")
	game.data["containers"].erase("block")
	var stair := {"cell": dest.position, "low": plan["level"], "high": plan["level"] + 1}
	game.stairs.append(stair)
	assert_false(Rules.free_rect(game, prop, dest, room), "stairs")
	game.stairs.erase(stair)
	assert_false(Rules.free_rect(game, prop, dest, room + 1), "same room required")
	var other := {"kind": "bench", "rect": dest, "level": plan["level"]}
	game.data["props"].append(other)
	assert_false(Rules.free_rect(game, prop, dest, room), "other furniture")


func test_blows_take_near_boards_then_brace_then_far_boards_then_door() -> void:
	for face in [0, 1]:
		var door := {"state": "closed", "hp": 8}
		var prop := {"kind": "shelf", "rect": Rect2i(2, 2, 2, 1)}
		Building.add_plank(door, 0)
		Building.add_plank(door, 1)
		Building.add_brace(door, 1 - face, prop, 3)
		for i in range(3):
			assert_true(_hit(door, face).is_empty())
		assert_eq(Building.planks(door, face), 0)
		assert_eq(Building.planks(door, 1 - face), 1)
		assert_eq(door["brace"]["hp"], 3)
		assert_true(_hit(door, face).is_empty())
		assert_true(_hit(door, face).is_empty())
		assert_true(is_same(_hit(door, face), prop))
		assert_false(Building.has_brace(door))
		assert_eq(Building.planks_total(door), 1)
		for i in range(3):
			_hit(door, face)
		assert_eq(door["hp"], 8, "bare door untouched until both defences are gone")
		assert_eq(Building.planks_total(door), 0)
		_hit(door, face)
		assert_eq(door["hp"], 7)


func _hit(door: Dictionary, face: int) -> Dictionary:
	door["hp"] -= 1
	return Building.wear_defences(door, face)


func test_toppled_furniture_remains_but_does_not_block_the_body() -> void:
	var game = _game()
	var plan := _push_site(game)
	assert_false(plan.is_empty())
	if plan.is_empty():
		return
	game.actions.push_furniture(game.player, plan["door"])
	_finish(game)
	var prop: Dictionary = plan["prop"]
	var g = game.levels[plan["level"]]
	var door: Dictionary = g.doors[plan["door"]]
	for i in range(int(Rules.PUSH_KINDS[prop["kind"]])):
		if plan["level"] == 0:
			game.on_door_banged(plan["door"])
		else:
			var fallen := _hit(door, 0)
			if not fallen.is_empty():
				game.actions.topple_furniture(fallen, plan["door"])
	assert_false(Building.has_brace(door))
	assert_true(bool(prop.get("fallen", false)))
	assert_has(game.data["props"], prop)
	for c in Rules.cells(prop["rect"]):
		assert_false(g.blocks_body(c))


func test_breaking_keeps_every_item_and_gives_size_based_planks_and_loud_sound() -> void:
	var game = _game("houses_01")
	var plan := _push_site(game)
	assert_false(plan.is_empty())
	if plan.is_empty():
		return
	var prop: Dictionary = plan["prop"]
	var box := _box(game, prop)
	box["items"] = ["plank", "plank", "food_pack", "food_pack", "nails"]
	var items: Array = box["items"].duplicate(true)
	var old: Rect2i = prop["rect"]
	var lv := int(prop.get("level", 0))
	for c in Rules.cells(old):
		for d in Rules.DIRS:
			if game.levels[lv].people_can_walk(c + d):
				game.player.position = game.lift(c + d, lv)
				if Rules.near_prop(game, game.player, prop):
					break
	game.player.set_weapon_slots([{"id": "axe", "quality": "factory", "condition": 1.0, "loaded": 0}])
	assert_true(Rules.can_break(game, game.player, prop))
	game.player.set_weapon_slots([{"id": "crowbar", "quality": "factory", "condition": 1.0, "loaded": 0}])
	assert_true(Rules.can_break(game, game.player, prop), "pry tool in hand")
	game.player.set_weapon_slots([{"id": "knife", "quality": "factory", "condition": 1.0, "loaded": 0}])
	assert_false(Rules.can_break(game, game.player, prop), "knife is not a demolition tool")
	game.player.set_weapon_slots([{"id": "axe", "quality": "factory", "condition": 1.0, "loaded": 0}])
	var before := int(game.player.items.get("plank", 0))
	game.actions.break_furniture(game.player, prop)
	assert_eq(game.player.action, "craft")
	assert_eq(game.sounds[-1]["level"], Rules.BREAK_NOISE)
	assert_eq(game.audio.played[-1], "door_bang", "wood impact is routed to an audible asset group")
	_finish(game)
	assert_false(game.data["props"].has(prop))
	_assert_prop_view(game, prop, true)
	assert_false(game.data["containers"].has(box["id"]))
	var heaps: Array = game.data["containers"].values().filter(func(b): return b["name"] == "부순 가구 더미")
	assert_eq(heaps.size(), 1)
	assert_eq(heaps[0]["items"], items, "duplicates and quantity unchanged")
	assert_eq(heaps[0]["cell"], old.position)
	assert_eq(int(game.player.items.get("plank", 0)) - before, Rules.plank_yield(prop))
	for c in Rules.cells(old):
		assert_false(game.levels[lv].blocks_body(c))


func test_cancelled_push_does_not_move_anything() -> void:
	var game = _game()
	var plan := _push_site(game)
	assert_false(plan.is_empty())
	if plan.is_empty():
		return
	var old: Rect2i = plan["prop"]["rect"]
	game.actions.push_furniture(game.player, plan["door"])
	game.player.cancel_action()
	Rules.for_game(game)._process(0.1)
	assert_eq(plan["prop"]["rect"], old)
	assert_false(Building.has_brace(game.levels[plan["level"]].doors[plan["door"]]))
	assert_false(bool(plan["prop"].get("busy", false)))


func test_stove_one_fuel_extends_to_cap_then_goes_out_and_keeps_existing_warmth() -> void:
	var game = _game()
	assert_gt(game.data["stoves"].size(), 0)
	var stove: Dictionary = game.data["stoves"][0]
	stove["lit"] = false
	var lv := int(stove.get("level", 0))
	var p = game.player
	p.position = game.lift(stove["cell"], lv)
	p.items["plank"] = 20
	game.actions.light_stove(p, stove)
	assert_eq(p.action, "craft")
	assert_eq(game.sounds[-1]["level"], Rules.LIGHT_NOISE)
	_finish(game)
	assert_true(stove["lit"])
	assert_eq(int(p.items["plank"]), 19)
	assert_almost_eq(float(stove["fuel_until"]) - game.clock.elapsed, 60.0, 0.001)
	var building := Building.building(game.data, int(stove["building"]))
	if not building.is_empty():
		building["window_broken"] = false
	assert_true(game.near_stove(p.position))
	if not building.is_empty():
		building["window_broken"] = true
		assert_false(game.near_stove(p.position), "open building still loses its warmth")
		building["window_broken"] = false
	var lights: Array = game.data["lights"].filter(func(l): return l.get("kind") == "stove")
	assert_eq(lights.size(), 1)
	assert_false(Lamp.is_on(lights[0], 630, false, false))
	assert_true(Lamp.is_on(lights[0], 945, false, false))
	for i in range(9):
		game.actions.light_stove(p, stove)
		_finish(game)
	assert_almost_eq(float(stove["fuel_until"]) - game.clock.elapsed, Rules.FUEL_CAP, 0.001)
	assert_false(Rules.can_light(game, p, stove))
	assert_eq(game.data["lights"].filter(func(l): return l.get("kind") == "stove").size(), 1)
	var fuel_before: float = stove["fuel_until"]
	game.paused = true
	Rules.for_game(game)._process(999.0)
	assert_eq(stove["fuel_until"], fuel_before, "wall time while paused consumes no fuel")
	game.paused = false
	game.clock.advance(Rules.FUEL_CAP)
	assert_false(stove["lit"], "expires in the clock advance, before the next body tick or render")
	assert_false(game.near_stove(p.position))
	assert_eq(game.data["lights"].filter(func(l): return l.get("kind") == "stove").size(), 0)
	assert_false(game.view.stove_glows.has(0))
	p.items.erase("plank")
	p.items["wood"] = 1
	game.actions.light_stove(p, stove)
	_finish(game)
	assert_true(stove["lit"])
	assert_false(p.items.has("wood"))
	assert_almost_eq(float(stove["fuel_until"]) - game.clock.elapsed, 120.0, 0.001)
	assert_eq(game.view.stove_glows[0].get_child_count(), 4, "one light and three low wisps")
