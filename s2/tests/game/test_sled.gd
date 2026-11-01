extends GutTest
## Field-only cargo, one-use work, and both save paths (sled.md 2.1-2.5).

const FieldSave = preload("res://game/sim/field_save.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const Sled = preload("res://game/sim/sled.gd")
const Carry = preload("res://game/sim/carry.gd")
const Gait = preload("res://game/sim/gait.gd")
const InventoryPane = preload("res://game/ui/inventory_pane.gd")
const FieldHud = preload("res://game/ui/field_hud.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")
const EPS: float = 0.00001
var fields: Array[Node] = []

class QuietField:
	extends "res://game/field_game.gd"
	var saved_result: Dictionary = {}

	func _save(result: Dictionary) -> void:
		saved_result = result.duplicate(true)


class RaiderLine:
	extends "res://tests/game/fixtures/bare_line_map.gd"

	static func build() -> Dictionary:
		var data: Dictionary = preload("res://tests/game/fixtures/bare_line_map.gd").build()
		data["spawns"]["raiders"] = [Vector2i(12, 20)]
		return data


func after_each() -> void:
	for field: Node in fields:
		if is_instance_valid(field):
			field.free()
	fields.clear()
	await get_tree().process_frame


func _game(with_raiders: bool = false, viewport: SubViewport = null) -> Variant:
	var field: QuietField = QuietField.new()
	field.opts = {"seed": 831, "raiders": with_raiders, "auto_pause": false, "arrive": false, "field_save": false, "receipt_id": "sled_test"}
	field.map_script = RaiderLine if with_raiders else BareLine
	if viewport == null:
		add_child(field)
	else:
		viewport.add_child(field)
	field.set_process(false)
	fields.append(field)
	field.zombies.list.clear()
	field.director.budget_left = 0
	field.director.next_arrival = INF
	field.data["unloading"] = [Rect2i(8, 18, 10, 5)]
	field.data["unload"] = Rect2i(8, 18, 10, 5)
	field.ground_items.clear()
	field.unloaded.clear()
	field.cloth_start = 0
	for person: Variant in field.people:
		person.items.clear()
		person.command = "wait"
		person.stop()
	var p: Variant = field.player
	p.position = Vector3(10.5, 0, 20.5)
	p.gloves = false
	p.heat.heat = 100.0
	p.heat.wet = 0.0
	p.running = false
	p.stick = Vector2.ZERO
	p.skills["strength"] = 5
	return field


func _discard_field(field: Node) -> void:
	fields.erase(field)
	field.free()


func _sled(game: Variant, cargo: Dictionary = {}) -> Dictionary:
	var row: Dictionary = {"id": game.next_sled_id, "level": 0, "pos": game.player.position + Vector3(-1, 0, 0), "items": cargo.duplicate(true), "puller": ""}
	game.next_sled_id += 1
	game.sleds.append(row)
	return row


func _labels(game: Variant) -> Array:
	return game.actions.context(game.player).map(func(row: Dictionary) -> String: return String(row["label"]))


func _buttons(game: Variant) -> Array:
	return game.hud.modal.find_children("*", "Button", true, false).map(func(button: Button) -> String: return button.text)


func _saved(game: Variant) -> Dictionary:
	return FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))


func _finish_work(game: Variant) -> void:
	game.player.action_t = 0.0
	game._update_person(game.player, 0.0)


func _snapshot(game: Variant) -> Dictionary:
	var p: Variant = game.player
	return {"sleds": game.sleds.duplicate(true), "next": game.next_sled_id,
		"pid": String(p.pid), "pos": p.position, "bag": p.items.duplicate(true), "hands": p.hands.duplicate(true),
		"pulling": p.sled_id, "stowed": p.sled_weapon_stowed, "for": p.sled_stowed_for,
		"rearm_t": p.sled_rearm_t, "path": p.path.duplicate(),
		"job": p.sled_job.duplicate(true), "action": p.action, "left": p.action_t,
		"callback": String(p.action_done.get_method()) if p.action != "" else "", "unloaded": game.unloaded.duplicate(true)}


func _apply(game: Variant, saved: Dictionary, exact_mode: bool) -> void:
	var copy: Dictionary = saved.duplicate(true)
	if not exact_mode:
		copy.erase("runtime")
	FieldSave.apply(game, copy)


# D1: Inclusive boundaries; the sled never reads body strength.
func test_d1_weight_boundaries_and_fixed_capacity() -> void:
	var game: Variant = _game()
	var values: Array[float] = [0.0, 5.5, 6.0, 6.5, 11.5, 12.0, 12.5, 24.0, 24.5]
	var states: Array[int] = [0, 0, 0, 1, 1, 1, 2, 2, 3]
	for strength: int in [3, 5, 7]:
		game.player.skills["strength"] = strength
		assert_eq(Sled.LIMIT, 12.0)
		for i: int in values.size():
			var row: Dictionary = {"items": {"document": int(values[i] * 2.0)}}
			assert_eq(Sled.weight(row), values[i])
			assert_eq(Sled.state(row), states[i], "strength %d, load %.1f" % [strength, values[i]])


# D2: Availability, exact base work, cancellations and stale completions.
func test_d2_craft_offer_materials_floor_and_one_sled() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	for materials: Dictionary in [{"plank": 1}, {"wood": 2, "cloth": 1}, {"plank": 2}]:
		p.items = materials.duplicate()
		assert_false(_labels(game).has("썰매 엮기"))
		assert_false(game.actions.craft_sled(p))
	p.items = {"plank": 2, "cloth": 1}
	assert_true(_labels(game).has("썰매 엮기"))
	var cell: Vector2i = FieldGrid.cell_of(p.position)
	game.grid.building[game.grid.index(cell)] = 1
	assert_false(_labels(game).has("썰매 엮기"))
	game.grid.building[game.grid.index(cell)] = -1
	p.position.y = 3.0
	assert_false(_labels(game).has("썰매 엮기"))
	p.position.y = 0.0
	_sled(game)
	assert_false(_labels(game).has("썰매 엮기"))
	assert_false(game.actions.craft_sled(p))


func test_d2_craft_thirty_seconds_once_and_quiet() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	p.items = {"plank": 2, "cloth": 1}
	var random_state: int = game.rng.state
	var noise: int = game.ledger.total
	assert_true(game.actions.craft_sled(p))
	var done: Callable = p.action_done
	assert_eq(p.action_total, 30.0)
	assert_eq(float(p.mults()["hands"]), 1.0)
	game._update_person(p, 29.0)
	assert_eq(game.sleds.size(), 0)
	assert_eq(p.items, {"plank": 2, "cloth": 1})
	game._update_person(p, 1.0)
	assert_eq(game.sleds.size(), 1)
	assert_eq(p.items, {})
	var after: Dictionary = _snapshot(game)
	done.call()
	assert_eq(_snapshot(game), after)
	assert_eq(game.ledger.total, noise)
	assert_eq(game.rng.state, random_state)


func test_d2_move_cancel_missing_material_and_old_callback() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	p.items = {"plank": 2, "cloth": 1}
	assert_true(game.actions.craft_sled(p))
	var old: Callable = p.action_done
	p.stick = Vector2(1, 0)
	game._update_person(p, 0.1)
	p.stick = Vector2.ZERO
	p.drive_speed = 0.0
	old.call()
	assert_eq(game.sleds.size(), 0)
	assert_eq(p.items, {"plank": 2, "cloth": 1})
	assert_true(game.actions.craft_sled(p))
	old.call()
	assert_eq(p.action, "craft", "an old completion does not cancel the new job")
	assert_true(game.actions.put_down(p, "cloth"))
	_finish_work(game)
	assert_eq(game.sleds.size(), 0)
	assert_eq(p.items, {"plank": 2})
	assert_eq(int(game.ground_items[0]["n"]), 1)


func test_d2_completion_rechecks_space_distance_and_id() -> void:
	for failure: String in ["space", "distance", "id", "floor"]:
		var game: Variant = _game()
		var p: Variant = game.player
		p.items = {"plank": 2, "cloth": 1}
		assert_true(game.actions.craft_sled(p))
		var done: Callable = p.action_done
		p.action_t = 0.0
		game.actions.complete_work(p)
		p.cancel_action(true)
		match failure:
			"space":
				var here: Vector2i = FieldGrid.cell_of(p.position)
				for x: int in range(-1, 2):
					for y: int in range(-1, 2):
						if x != 0 or y != 0:
							game.grid.set_solid(here + Vector2i(x, y), FieldGrid.Solid.WALL)
			"distance":
				p.position.x += 4.0
			"id":
				game.next_sled_id += 1
			"floor":
				p.position.y = 3.0
		done.call()
		done.call()
		assert_eq(game.sleds.size(), 0, failure)
		assert_eq(p.items, {"plank": 2, "cloth": 1}, failure)


func test_d2_cancel_even_after_ticket_revokes_completion() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	p.items = {"plank": 2, "cloth": 1}
	assert_true(game.actions.craft_sled(p))
	var done: Callable = p.action_done
	p.action_t = 0.0
	game.actions.complete_work(p)
	p.cancel_action()
	done.call()
	assert_eq(game.sleds, [])
	assert_eq(p.items, {"plank": 2, "cloth": 1})


# D3: The hand slot is stored intact; drawing it is a named, one-second job.
func test_d3_pull_refusals_and_combat_lock_then_draw() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	var sled: Dictionary = _sled(game)
	var id: int = int(sled["id"])
	p.set_weapon_slots([{"id": "pistol", "quality": "factory", "condition": 0.63, "loaded": 3}, {"id": "knife", "quality": "factory", "condition": 0.42, "loaded": 0}])
	var weapons: Array = p.hands.duplicate(true)
	p.reload_t = 0.5
	assert_false(game.actions.pull_sled(p, id))
	p.reload_t = 0.0
	p.items = {"symbol_bell": 1}
	assert_false(game.actions.pull_sled(p, id))
	p.items.clear()
	p.carrying_wounded = game.squad[1]
	assert_false(game.actions.pull_sled(p, id))
	p.carrying_wounded = null
	assert_true(game.combat.start_aim(p))
	assert_false(game.actions.pull_sled(p, id))
	p.aim.stop()
	p.start_action("search", "뒤지기", 2.0, Callable())
	assert_false(game.actions.pull_sled(p, id))
	p.cancel_action()
	p.strike_t = 0.2
	assert_false(game.actions.pull_sled(p, id))
	p.strike_t = 0.0
	p.hold_attack = true
	p.target_zombie = {"id": 77}
	game.hud.auto_aim = true
	assert_true(game.actions.pull_sled(p, id))
	assert_false(game.hud.auto_aim)
	assert_false(p.hold_attack)
	assert_eq(p.target_zombie, {})
	assert_false(p.load_lets_run())
	assert_false(game.combat.can_shoot(p))
	assert_false(game.combat.start_aim(p))
	assert_false(game.combat.start_reload(p))
	game.combat.start_swing(p, {})
	game.combat.shove(p)
	game.combat.stomp(p, {})
	game.combat.swap(p)
	assert_eq(p.swing_t, 0.0)
	assert_eq(p.strike_t, 0.0)
	assert_eq(p.hands, weapons)
	assert_false(p.weapon_mesh.visible)
	assert_eq(Gait.ready_name(p), "")
	assert_eq(Gait.gait_name(p, false), Gait.CARRY_BIG)
	assert_eq(Gait.crouch_name(p, true), Gait.CARRY_BIG)
	assert_eq(Gait.burden_name(p, 0.5), Gait.CARRY_BIG)
	game.actions.release_sled(p)
	assert_eq(p.sled_id, 0)
	assert_eq(sled["puller"], "")
	assert_eq(p.action, "")
	assert_eq(p.sled_job, {})
	assert_eq(p.sled_rearm_t, Carry.swap_time("belt", p.carry_state()))
	game._update_person(p, 0.5)
	assert_false(game.combat._hands_free_for_blow(p))
	game._update_person(p, 0.5)
	assert_true(game.combat._hands_free_for_blow(p))
	assert_false(p.sled_weapon_stowed)
	assert_eq(p.sled_rearm_t, 0.0)
	assert_eq(p.hands, weapons)


func test_d3_rearm_keeps_stairs_path_and_unlocks_combat_after_one_second() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	p.set_weapon_slots([{"id": "pistol", "quality": "factory", "condition": 1.0, "loaded": 3}])
	var upper: Variant = FieldGrid.new(game.grid.width, game.grid.height)
	upper.refresh_paths()
	game.levels[1] = upper
	var stair: Dictionary = {"cell": Vector2i(12, 20), "low": 0, "high": 1, "ladder": false}
	game.stairs.append(stair)
	var sled: Dictionary = _sled(game)
	assert_true(game.actions.pull_sled(p, int(sled["id"])))
	game.actions.take_stairs(p, stair)
	assert_eq(p.sled_id, 0)
	assert_false(p.path.is_empty())
	assert_eq(p.action, "")
	assert_eq(p.sled_rearm_t, 1.0)
	var start: Vector3 = p.position
	game._update_person(p, 0.5)
	assert_gt(start.distance_to(p.position), 0.0)
	assert_false(p.path.is_empty(), "the normal tick must not erase the stair route")
	assert_false(game.combat.can_shoot(p))
	var loaded_before: int = int(p.weapon()["loaded"])
	game.combat.fire(p, p.position + Vector3(0, 0, 4))
	assert_eq(int(p.weapon()["loaded"]), loaded_before)
	game.combat.start_swing(p, {})
	game.combat.start_shove(p)
	assert_eq(p.strike_t, 0.0)
	assert_eq(p.shove_t, 0.0)
	game._update_person(p, 0.5)
	assert_false(p.sled_weapon_stowed)
	assert_true(game.combat.can_shoot(p))
	assert_true(game.combat._hands_free_for_blow(p))
	for _tick: int in 60:
		game._update_person(p, 0.1)
	assert_eq(game.level_of(p.position), 1)
	assert_true(p.path.is_empty())
	assert_eq(sled["pos"], start + Vector3(-1, 0, 0))
	p.set_weapon_slots([{"id": "knife", "quality": "factory", "condition": 1.0, "loaded": 0}])
	game.combat.swing_air(p)
	assert_gt(p.strike_t, 0.0)


func test_d3_touch_pads_ignore_stowed_weapon_then_work_after_timer() -> void:
	for pad_name: String in ["attack_button", "aim_button", "shove_button", "manual_button"]:
		var game: Variant = _game()
		var p: Variant = game.player
		var hud: Variant = game.hud
		var weapon: String = "knife" if pad_name == "attack_button" else "pistol"
		p.set_weapon_slots([{"id": weapon, "quality": "factory", "condition": 1.0, "loaded": 3}])
		var sled: Dictionary = _sled(game)
		assert_true(game.actions.pull_sled(p, int(sled["id"])))
		var button: Button = hud.get(pad_name)
		hud.tick(0.0)
		await get_tree().process_frame
		button.show()
		await get_tree().process_frame
		hud.pads = [button]
		var at: Vector2 = button.get_global_rect().get_center()
		var manual_before: bool = hud.manual_button.button_pressed
		button.disabled = false # Input must be safe even before the next HUD tick.
		for phase: int in 2:
			assert_true(hud.finger_down(9, at), pad_name)
			assert_false(hud.fingers.has(9), "a blocked pad must not become a world touch")
			hud.finger_up(9, at)
			assert_eq(hud.manual_button.button_pressed, manual_before)
			assert_false(p.aim.active)
			assert_false(p.hold_attack)
			assert_eq(p.strike_t, 0.0)
			assert_eq(p.shove_t, 0.0)
			assert_eq(p.swing_t, 0.0)
			if phase == 0:
				game.actions.release_sled(p)
				game._update_person(p, 0.5)
		game._update_person(p, 0.5)
		hud.tick(0.0)
		button.show()
		await get_tree().process_frame
		at = button.get_global_rect().get_center()
		assert_false(button.disabled)
		assert_true(hud.finger_down(9, at))
		match pad_name:
			"attack_button":
				assert_gt(p.strike_t, 0.0)
			"aim_button":
				assert_true(p.aim.active)
			"shove_button":
				assert_gt(p.shove_t, 0.0)
			"manual_button":
				assert_ne(hud.manual_button.button_pressed, manual_before)
		hud.finger_cancel(9)
		_discard_field(game)


func test_d3_touch_shove_can_drop_rope_and_escape_grab() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	var hud: Variant = game.hud
	var sled: Dictionary = _sled(game)
	assert_true(game.actions.pull_sled(p, int(sled["id"])))
	hud.tick(0.0)
	await get_tree().process_frame
	var dead: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.4, 0, 0))
	dead["state"] = "grab"
	dead["victim"] = p
	p.grabbers.append(dead)
	p.grab_left = 1.0
	hud.shove_button.show()
	hud.pads = [hud.shove_button]
	assert_true(hud.shove_button.disabled, "the old disabled appearance may still be present")
	var at: Vector2 = hud.shove_button.get_global_rect().get_center()
	assert_true(hud.finger_down(9, at))
	assert_true(p.grabbers.is_empty())
	assert_eq(p.sled_id, 0)
	assert_eq(sled["puller"], "")
	assert_eq(p.sled_rearm_t, 1.0)
	hud.finger_up(9, at)


func test_d3_grab_drops_before_escape() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	var sled: Dictionary = _sled(game, {"food_pack": 2})
	assert_true(game.actions.pull_sled(p, int(sled["id"])))
	var dead: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.4, 0, 0))
	dead["state"] = "grab"
	dead["victim"] = p
	p.grabbers.append(dead)
	p.grab_left = 1.0
	assert_true(game.combat.break_grab(p))
	assert_eq(p.sled_id, 0)
	assert_eq(sled["puller"], "")
	assert_eq(sled["items"], {"food_pack": 2})


func test_d3_weapon_pickup_blocked_small_auto_pickup_keeps_rope() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	p.set_weapon_slots([{"id": "knife", "quality": "factory", "condition": 0.73, "loaded": 0}])
	var weapons: Array = p.hands.duplicate(true)
	var sled: Dictionary = _sled(game)
	assert_true(game.actions.pull_sled(p, int(sled["id"])))
	game.ground_items.append({"pos": p.position, "id": "pistol", "n": 1, "weapon": {"id": "pistol", "quality": "factory", "condition": 0.41, "loaded": 2}})
	game.actions.pick_up(p, 0)
	assert_eq(p.hands, weapons)
	assert_eq(game.ground_items.size(), 1)
	var rounds: int = int(game.ammo["craft"])
	game.ground_items.append({"pos": p.position, "id": "ammo_craft", "n": 2})
	game.actions._auto_pickup()
	assert_eq(game.ground_items.size(), 1)
	assert_eq(int(game.ammo["craft"]), rounds + 2)
	assert_eq(p.sled_id, int(sled["id"]))


# D4: Compare actual displacement, including residual stick inertia.
func test_d4_drive_and_path_speed_ratios_and_independent_bag() -> void:
	for load_index: int in 3:
		for drive: bool in [true, false]:
			var plain: Variant = _game()
			var towing: Variant = _game()
			plain.player.items = {"scrap": 2}
			towing.player.items = {"scrap": 2}
			var sled: Dictionary = _sled(towing, {"scrap": [0, 7, 13][load_index]})
			assert_true(towing.actions.pull_sled(towing.player, int(sled["id"])))
			assert_eq(towing.player.weight(), plain.player.weight())
			var at: Vector3 = plain.player.position
			for game: Variant in [plain, towing]:
				if drive:
					game.player.stick = Vector2(1, 0)
					game._drive(game.player, 0.1)
				else:
					game.player.path = PackedVector3Array([at + Vector3(4, 0, 0)])
					game._move_person(game.player, 0.1)
			var ratio: float = Sled.LOAD_MULT[load_index] * 0.9
			assert_gt(at.distance_to(plain.player.position), 0.0, "a blocked baseline cannot prove a speed ratio")
			assert_almost_eq(at.distance_to(towing.player.position), at.distance_to(plain.player.position) * ratio, EPS)
			_discard_field(plain)
			_discard_field(towing)


func test_d4_overloaded_stops_this_tick_with_inertia() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	var sled: Dictionary = _sled(game, {"scrap": 25})
	assert_true(game.actions.pull_sled(p, int(sled["id"])))
	var at: Vector3 = p.position
	p.drive_speed = 3.0
	p.drive_dir = Vector3.RIGHT
	p.stick = Vector2.RIGHT
	game._drive(p, 0.1)
	assert_eq(p.position, at)
	assert_eq(p.drive_speed, 0.0)
	p.path = PackedVector3Array([at + Vector3(4, 0, 0)])
	game._move_person(p, 0.1)
	assert_eq(p.position, at)
	assert_eq(p.sled_id, int(sled["id"]))


# D5: The final movement candidate and the sled's swept cells are separate checks.
func test_d5_drive_and_path_leave_sled_outside() -> void:
	for drive: bool in [true, false]:
		var game: Variant = _game()
		var p: Variant = game.player
		p.position = Vector3(10.95, 0, 20.5)
		var sled: Dictionary = _sled(game)
		var at: Vector3 = sled["pos"]
		assert_true(game.actions.pull_sled(p, int(sled["id"])))
		game.grid.building[game.grid.index(Vector2i(11, 20))] = 1
		if drive:
			p.stick = Vector2.RIGHT
			p.drive_speed = p.speed(FieldGrid.Floor.SNOW)
			game._drive(p, 0.1)
		else:
			p.path = PackedVector3Array([Vector3(13.5, 0, 20.5)])
			game._move_person(p, 0.1)
		assert_eq(p.sled_id, 0)
		assert_eq(sled["pos"], at)
		assert_false(game.grid.indoor(FieldGrid.cell_of(sled["pos"])))
		assert_true(game.grid.indoor(FieldGrid.cell_of(p.position)))


func test_d5_blocked_segment_drops_without_teleport() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	p.position = Vector3(11.5, 0, 20.5)
	var sled: Dictionary = _sled(game)
	var at: Vector3 = sled["pos"]
	assert_true(game.actions.pull_sled(p, int(sled["id"])))
	game.grid.set_solid(Vector2i(12, 20), FieldGrid.Solid.WALL)
	Sled.before_move(game, p, p.position + Vector3(5, 0, 0))
	assert_eq(p.sled_id, 0)
	assert_eq(sled["pos"], at)
	assert_eq(p.sled_rearm_t, 1.0)


func test_d5_corner_trail_survives_both_saves_and_long_walking_ticks() -> void:
	for exact_mode: bool in [false, true]:
		var game: Variant = _game()
		var p: Variant = game.player
		p.position = Vector3(11.1, 0, 20.8)
		p.turn_rate = 0.0
		var sled: Dictionary = _sled(game)
		sled["pos"] = Vector3(10.8, 0, 20.8)
		game.grid.set_solid(Vector2i(10, 21), FieldGrid.Solid.WALL)
		assert_true(game.actions.pull_sled(p, int(sled["id"])))
		p.path = PackedVector3Array([Vector3(11.1, 0, 21.4)])
		game._update_person(p, 0.5)
		assert_almost_eq(p.position, Vector3(11.1, 0, 21.4), Vector3.ONE * Sled.ROPE_EPS)
		assert_eq(sled["pos"], Vector3(10.8, 0, 20.8), "slack rope does not pull the sled")
		assert_false(Sled.path_clear(game, sled["pos"], p.position), "the direct chord crosses the corner wall")
		assert_true(Sled.trail_clear(game, sled, p.position))
		var resumed: Variant = _game()
		resumed.grid.set_solid(Vector2i(10, 21), FieldGrid.Solid.WALL)
		var saved: Dictionary = _saved(game)
		_apply(resumed, saved, exact_mode)
		assert_eq(_snapshot(resumed), _snapshot(game))
		assert_eq(resumed.player.sled_id, int(sled["id"]))
		for field: Variant in [game, resumed]:
			var walker: Variant = field.player
			var towed: Dictionary = field.sleds[0]
			for dest: Vector3 in [Vector3(11.1, 0, 24.4), Vector3(15.1, 0, 24.4), Vector3(15.1, 0, 27.4)]:
				var old_person: Vector3 = walker.position
				var old_sled: Vector3 = towed["pos"]
				walker.path = PackedVector3Array([dest])
				field._update_person(walker, 4.0)
				assert_gt(old_person.distance_to(walker.position), Sled.ROPE_LENGTH)
				assert_lte(old_sled.distance_to(towed["pos"]), old_person.distance_to(walker.position) + Sled.ROPE_EPS)
				assert_eq(walker.sled_id, int(towed["id"]))
				assert_true(Sled.trail_clear(field, towed, walker.position))
				assert_true(Sled.walkable(field, FieldGrid.cell_of(towed["pos"])))
				assert_lte(Sled.trail_length(towed["trail"]), Sled.ROPE_LENGTH + Sled.ROPE_EPS)
				assert_lte(towed["trail"].size(), 4, "points already passed by the sled are discarded")
		assert_eq(_snapshot(resumed), _snapshot(game))
		_discard_field(game)
		_discard_field(resumed)


func test_d5_stair_level_branch_and_hands_work_menu_boundary() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	var sled: Dictionary = _sled(game)
	assert_true(game.actions.pull_sled(p, int(sled["id"])))
	game.actions.open_sled(p, int(sled["id"]))
	game.hud._close_modal()
	assert_ne(p.sled_id, 0)
	game.actions.tear_bandage(p)
	assert_ne(p.sled_id, 0, "an unavailable work does not drop the rope")
	p.items["cloth"] = 1
	game.actions.tear_bandage(p)
	assert_eq(p.sled_id, 0)
	assert_eq(p.action, "craft")
	_finish_work(game)
	game._update_person(p, 1.0)
	assert_true(game.actions.pull_sled(p, int(sled["id"])))
	p.path = PackedVector3Array([Vector3(p.position.x, 3.0, p.position.z)])
	game._move_person(p, 0.1)
	assert_eq(p.sled_id, 0)
	assert_eq(float(sled["pos"].y), 0.0)
	assert_eq(p.position.y, 3.0)


# D6: All three incapacitation entries leave cargo owned by the sled.
func test_d6_death_bleeding_down_and_fall_preserve_cargo() -> void:
	for event: String in ["death", "raider_death", "downed", "fall"]:
		var game: Variant = _game()
		var p: Variant = game.player
		p.items = {"scrap": 1}
		var sled: Dictionary = _sled(game, {"food_pack": 7})
		assert_false(is_same(p.items, sled["items"]))
		assert_true(game.actions.pull_sled(p, int(sled["id"])))
		match event:
			"death", "raider_death":
				if event == "raider_death":
					p.team = "raider"
				game.on_person_died(p)
			"downed":
				p.body.downed = true
				game._on_body_event(p, "downed")
			"fall":
				game.combat.fall(p, "넘어졌다", 0.0)
		assert_eq(p.sled_id, 0, event)
		assert_eq(sled["puller"], "", event)
		assert_eq(sled["items"], {"food_pack": 7}, event)
		assert_false(p.items.has("food_pack"))
		assert_false(game.ground_items.any(func(row: Dictionary) -> bool: return row["id"] == "food_pack"))
		for dead: Dictionary in game.zombies.list:
			for loot: Dictionary in dead.get("loot", []):
				assert_ne(String(loot.get("id", "")), "food_pack")
		p.body.downed = false
		p.fallen_t = 0.0
		game._update_person(p, 0.1)
		assert_eq(p.sled_id, 0, "recovery never reattaches")


# D7: Explicit unloading, no field-store filter on the sled, no companion ownership.
func test_d7_context_keeps_all_sled_rows_and_primary_order() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	p.items = {"food_pack": 1}
	var sled: Dictionary = _sled(game, {"food_pack": 2})
	for index: int in 4:
		var box_id: String = "near_sled_%d" % index
		game.data["containers"][box_id] = {"id": box_id, "name": "보관함", "cell": Vector2i(10, 20), "level": 0,
			"building": -1, "search": 1.0, "items": [], "locked": false, "searched": false}
	for cell: Vector2i in [Vector2i(10, 19), Vector2i(11, 20)]:
		game.grid.doors[cell] = {"state": "open"}
	var labels: Array = _labels(game)
	assert_eq(labels[0], "열차에 싣기")
	for label: String in ["열차에 싣기", "끈다", "썰매 짐"]:
		assert_has(labels, label)
	assert_lt(labels.find("끈다"), labels.find("썰매 짐"))
	game.data["unloading"] = [Rect2i(30, 18, 2, 2)]
	game.data["unload"] = Rect2i(30, 18, 2, 2)
	labels = _labels(game)
	assert_eq(labels[0], "끈다")
	assert_has(labels, "썰매 짐")
	assert_true(game.actions.pull_sled(p, int(sled["id"])))
	game.data["unloading"] = [Rect2i(8, 18, 10, 5)]
	game.data["unload"] = Rect2i(8, 18, 10, 5)
	labels = _labels(game)
	assert_eq(labels[0], "놓는다")
	assert_has(labels, "열차에 싣기")
	assert_has(labels, "썰매 짐")


func test_d7_empty_bag_sled_buttons_all_cargo_and_no_second_trip() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	var sled: Dictionary = _sled(game, {"wood": 2, "scrap": 3, "food_pack": 2})
	assert_true(_labels(game).has("열차에 싣기"))
	game.hud.bag_panel()
	assert_true(_buttons(game).has("열차에 싣기"))
	assert_true(InventoryPane.places(game, p).any(func(place: Dictionary) -> bool: return place["kind"] == "sled"))
	assert_true(game.actions.pull_sled(p, int(sled["id"])))
	assert_eq(String(game.actions._near_things(p)[0]["label"]), "놓는다")
	var mate: Variant = game.squad[1]
	mate.position = p.position
	mate.items = {"scrap": 1}
	assert_false(game.actions.pull_sled(mate, int(sled["id"])))
	assert_false(game.actions.move_sled(mate, int(sled["id"]), "wood", false))
	game.actions._auto_unload()
	assert_eq(sled["items"], {"wood": 2, "scrap": 3, "food_pack": 2})
	var trips: int = game.telemetry.trips
	assert_true(game.actions.load_train(p))
	assert_eq(sled["items"], {})
	assert_eq(game.unloaded, {"scrap": 4, "wood": 2, "food_pack": 2})
	assert_eq(game.telemetry.trips, trips + 1)
	assert_ne(p.sled_id, 0, "unloading keeps the rope")
	assert_false(game.actions.load_train(p))
	assert_eq(game.telemetry.trips, trips + 1)
	game.hud.bag_panel()
	assert_false(_buttons(game).has("열차에 싣기"))
	game.hud._close_modal()


func test_d7_bag_only_and_sled_reference_cell_outside() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	var sled: Dictionary = _sled(game)
	p.items = {"scrap": 2, "cloth": 1}
	assert_true(game.actions.load_train(p))
	assert_eq(game.unloaded, {"scrap": 2})
	assert_eq(p.items, {"cloth": 1})
	sled["items"] = {"wood": 3, "food_pack": 2}
	sled["pos"] = Vector3(7.5, 0, 20.5)
	assert_false(game.actions.load_train(p), "the sled reference is outside the actual unloading cells")
	assert_eq(sled["items"], {"wood": 3, "food_pack": 2})
	sled["pos"] = Vector3(9.5, 3, 20.5)
	sled["level"] = 1
	assert_false(game.actions.load_train(p))
	sled["pos"] = Vector3(9.5, 0, 20.5)
	sled["level"] = 0
	assert_true(game.actions.load_train(p))
	assert_eq(int(game.unloaded["wood"]), 3)
	assert_eq(int(game.unloaded["food_pack"]), 2)


# D8: The stop's receipt never includes a sled that was not unloaded.
func test_d8_all_end_reasons_leave_sled_cargo_out_of_receipt() -> void:
	# A sled left outside the unloading area: it and its load stay in the field (sled.md 2.1).
	for reason: String in ["departed", "limit", "wiped"]:
		var game: Variant = _game()
		var sled: Dictionary = _sled(game, {"food_pack": 4, "scrap": 2})
		sled["pos"] = Vector3(24.5, 0, 20.5)
		assert_false(Sled.in_unloading(game, sled))
		game.finish(reason)
		assert_eq(sled["items"], {"food_pack": 4, "scrap": 2}, reason)
		assert_eq(sled["puller"], "")
		assert_eq(game.player.sled_id, 0)
		assert_eq(game.unloaded, {})
		var stock: Dictionary = game.saved_result["receipt"]["stock"]
		assert_eq(int(stock.get("food", 0)), 0)
		assert_eq(int(stock.get("scrap", 0)), 0)


func test_d8_a_sled_in_the_unloading_area_goes_aboard_on_leaving() -> void:
	for reason: String in ["departed", "limit", "wiped"]:
		var game: Variant = _game()
		var sled: Dictionary = _sled(game, {"food_pack": 4, "scrap": 2})
		assert_true(Sled.in_unloading(game, sled))
		assert_true(game.actions.pull_sled(game.player, int(sled["id"])))
		game.finish(reason)
		assert_eq(sled["items"], {}, reason)
		assert_eq(sled["puller"], "")
		assert_eq(game.player.sled_id, 0)
		assert_eq(int(game.unloaded.get("food_pack", 0)), 4, reason)
		assert_eq(int(game.unloaded.get("scrap", 0)), 2, reason)
	# Already loaded by the key: nothing is counted twice.
	var twice: Variant = _game()
	var loaded: Dictionary = _sled(twice, {"food_pack": 3})
	assert_true(twice.actions.load_train(twice.player))
	assert_eq(int(twice.unloaded.get("food_pack", 0)), 3)
	twice.finish("departed")
	assert_eq(int(twice.unloaded.get("food_pack", 0)), 3)
	assert_eq(loaded["items"], {})


func test_d8_the_leaving_card_names_what_is_left_and_what_goes_aboard() -> void:
	var game: Variant = _game()
	var sled: Dictionary = _sled(game, {"food_pack": 2, "scrap": 3})
	assert_eq(Sled.leaving_note(game), "\n하역 칸 안 썰매의 짐 5개는 같이 싣는다.")
	sled["pos"] = Vector3(24.5, 0, 20.5)
	assert_eq(Sled.leaving_note(game), "\n하역 칸 밖 썰매 1대·짐 5개를 두고 간다.")
	sled["items"] = {}
	assert_eq(Sled.leaving_note(game), "\n하역 칸 밖 썰매 1대·짐 0개를 두고 간다.")
	game.sleds.clear()
	assert_eq(Sled.leaving_note(game), "")
	# The card shows it: opening it with a sled out runs the same note without error.
	_sled(game, {"scrap": 1})["pos"] = Vector3(24.5, 0, 20.5)
	game.hud.depart_card()
	assert_true(game.hud.modal != null)
	game.hud._close_modal()


# D9: Transfers are immediate; the transfer checkpoint is immediately after the press.
func test_d9_all_checkpoints_legacy_and_exact_resume_twice() -> void:
	for exact_mode: bool in [false, true]:
		for phase: String in ["parked", "pulling", "craft", "moved", "rearm", "before_unload", "after_unload"]:
			var game: Variant = _game()
			var p: Variant = game.player
			p.set_weapon_slots([{"id": "pipe_shotgun", "quality": "fine", "condition": 0.63, "loaded": 1}, {"id": "knife", "quality": "factory", "condition": 0.42, "loaded": 0}])
			if phase == "craft":
				p.items = {"plank": 2, "cloth": 1}
				assert_true(game.actions.craft_sled(p))
				game._update_person(p, 12.0)
			else:
				var sled: Dictionary = _sled(game, {"food_pack": 2})
				if phase in ["pulling", "rearm"]:
					assert_true(game.actions.pull_sled(p, int(sled["id"])))
				if phase == "pulling":
					p.stick = Vector2.RIGHT
					game._drive(p, 0.4)
					assert_almost_eq(p.position.distance_to(sled["pos"]), Sled.ROPE_LENGTH, Sled.ROPE_EPS)
				if phase == "rearm":
					game.actions.release_sled(p)
					game._update_person(p, 0.4)
				elif phase == "moved":
					assert_true(game.actions.move_sled(p, int(sled["id"]), "food_pack", false))
				elif phase == "after_unload":
					assert_true(game.actions.load_train(p))
			var saved: Dictionary = _saved(game)
			var original: String = FieldSave.to_json(saved)
			var resumed: Variant = _game()
			_apply(resumed, saved, exact_mode)
			assert_eq(_snapshot(resumed), _snapshot(game), phase)
			_apply(resumed, saved, exact_mode)
			assert_eq(_snapshot(resumed), _snapshot(game), phase + " applied twice")
			assert_eq(FieldSave.to_json(saved), original, "restore never mutates the save")
			if phase == "craft":
				_finish_work(game)
				_finish_work(resumed)
			elif phase == "rearm":
				game._update_person(p, 1.0)
				resumed._update_person(resumed.player, 1.0)
			elif phase == "pulling":
				for field: Variant in [game, resumed]:
					field.player.stick = Vector2.RIGHT
					field._drive(field.player, 0.25)
			elif phase == "before_unload":
				game.actions.load_train(p)
				resumed.actions.load_train(resumed.player)
			assert_eq(_snapshot(resumed), _snapshot(game), phase + " continued")
			_discard_field(game)
			_discard_field(resumed)


func test_d9_rearm_timer_and_legacy_action_resume_while_walking() -> void:
	for exact_mode: bool in [false, true]:
		for legacy: bool in [false, true]:
			var game: Variant = _game()
			var p: Variant = game.player
			var sled: Dictionary = _sled(game)
			assert_true(game.actions.pull_sled(p, int(sled["id"])))
			game.actions.release_sled(p)
			p.path = PackedVector3Array([p.position + Vector3(4, 0, 0)])
			game._update_person(p, 0.4)
			var saved: Dictionary = _saved(game)
			if legacy:
				for row: Dictionary in saved["people"]:
					if row["pid"] != p.pid:
						continue
					var state: Dictionary = row["state"]
					state.erase("sled_rearm_t")
					state["action"] = "sled_rearm"
					state["action_label"] = "무기 꺼냄"
					state["action_t"] = p.sled_rearm_t
					state["action_total"] = 1.0
					state["action_done"] = FieldSave._freeze(game, game.actions._sled_crafted.bind(p, 1, int(sled["id"])))
					state["action_done"]["$call"][1] = "_sled_rearmed"
					state["sled_job"] = {"kind": "rearm", "token": 1, "sled_id": int(sled["id"]), "ready": false}
			var original: String = FieldSave.to_json(saved)
			var resumed: Variant = _game()
			for _restore: int in 2:
				_apply(resumed, saved, exact_mode)
				assert_eq(_snapshot(resumed), _snapshot(game))
				assert_eq(resumed.player.action, "")
				assert_eq(resumed.player.sled_job, {})
			assert_eq(FieldSave.to_json(saved), original)
			for field: Variant in [game, resumed]:
				var walker: Variant = field.player
				var at: Vector3 = walker.position
				field._update_person(walker, 0.25)
				assert_true(walker.sled_weapon_stowed)
				assert_gt(walker.position.distance_to(at), 0.0)
				field._update_person(walker, 0.36)
				assert_false(walker.sled_weapon_stowed)
				assert_eq(walker.sled_rearm_t, 0.0)
			assert_eq(_snapshot(resumed), _snapshot(game))
			for row: Dictionary in _saved(resumed)["people"]:
				assert_false(row["state"].has("sled_rearm_t"), "an idle timer adds no save field")
			_discard_field(game)
			_discard_field(resumed)


func test_d9_legacy_trail_is_seeded_but_broken_or_too_long_trails_detach() -> void:
	for exact_mode: bool in [false, true]:
		for mode: String in ["legacy", "gap", "wall", "length"]:
			var game: Variant = _game()
			var p: Variant = game.player
			var sled: Dictionary = _sled(game)
			assert_true(game.actions.pull_sled(p, int(sled["id"])))
			if mode == "legacy":
				sled.erase("trail")
			elif mode == "gap":
				sled["trail"] = PackedVector3Array([sled["pos"], p.position + Vector3(0.1, 0, 0)])
			elif mode == "wall":
				game.grid.set_solid(FieldGrid.cell_of(sled["pos"]), FieldGrid.Solid.WALL)
			else:
				sled["trail"] = PackedVector3Array([sled["pos"], p.position + Vector3(0, 0, 1), p.position])
			var saved: Dictionary = _saved(game)
			_apply(game, saved, exact_mode)
			if mode == "legacy":
				assert_eq(p.sled_id, int(sled["id"]))
				assert_true(Sled.trail_clear(game, game.sleds[0], p.position))
			else:
				assert_eq(p.sled_id, 0)
				assert_eq(game.sleds[0]["puller"], "")
			_discard_field(game)


func test_d9_old_save_and_missing_or_dead_puller() -> void:
	for exact_mode: bool in [false, true]:
		for invalid: String in ["old", "missing", "dead"]:
			var game: Variant = _game()
			var sled: Dictionary = _sled(game, {"food_pack": 2})
			assert_true(game.actions.pull_sled(game.player, int(sled["id"])))
			var saved: Dictionary = _saved(game)
			if invalid == "old":
				saved.erase("sleds")
				saved.erase("next_sled_id")
				saved["runtime"]["game"].erase("sleds")
				saved["runtime"]["game"].erase("next_sled_id")
				for row: Dictionary in saved["people"]:
					for key: String in FieldSave.SLED_PERSON_FIELDS:
						row["state"].erase(key)
			elif invalid == "missing":
				saved["sleds"][0]["puller"] = "absent_pid"
				saved["runtime"]["game"]["sleds"][0]["puller"] = "absent_pid"
			else:
				for row: Dictionary in saved["people"]:
					if row["pid"] == game.player.pid:
						row["body"]["dead"] = true
			_apply(game, saved, exact_mode)
			assert_eq(game.player.sled_id, 0, invalid)
			if invalid == "old":
				assert_eq(game.sleds, [])
				assert_eq(game.next_sled_id, 1)
				assert_false(game.player.sled_weapon_stowed)
			else:
				assert_eq(game.sleds[0]["puller"], "")
				assert_eq(game.sleds[0]["items"], {"food_pack": 2})


func _counts(game: Variant) -> Dictionary:
	var out: Dictionary = {}
	for p: Variant in game.people:
		_sum(out, p.items)
	for box: Dictionary in game.data["containers"].values():
		for item: String in box["items"]:
			out[item] = int(out.get(item, 0)) + 1
	for ground: Dictionary in game.ground_items:
		var item: String = String(ground["id"])
		out[item] = int(out.get(item, 0)) + int(ground["n"])
	for sled: Dictionary in game.sleds:
		_sum(out, sled["items"])
	_sum(out, game.unloaded)
	return out


func _sum(into: Dictionary, counts: Dictionary) -> void:
	for item: String in counts:
		into[item] = int(into.get(item, 0)) + int(counts[item])


func _conserved(game: Variant, start: Dictionary, consumed: Dictionary) -> void:
	var total: Dictionary = _counts(game)
	_sum(total, consumed)
	assert_eq(total, start, "start + created = inventories + explicitly consumed crafting materials")


# D10: Check every operation, including one-use transfer completion and both restore paths.
func test_d10_conservation_each_step_and_transfer_commit_checks() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	p.items = {"plank": 2, "cloth": 1, "food_pack": 3, "scrap": 2}
	game.data["containers"]["sled_counts"] = {"id": "sled_counts", "name": "보관함", "cell": Vector2i(5, 20), "level": 0,
		"building": -1, "search": 1.0, "items": ["scrap", "document"], "locked": false, "searched": true}
	game.view.add_container("sled_counts")
	game.ground_items.append({"id": "document", "n": 2, "pos": p.position})
	var start: Dictionary = _counts(game)
	_conserved(game, start, {})
	assert_true(game.actions.craft_sled(p))
	_finish_work(game)
	var consumed: Dictionary = {"plank": 2, "cloth": 1}
	_conserved(game, start, consumed)
	var id: int = int(game.sleds[0]["id"])
	for _press: int in 3:
		assert_true(game.actions.move_sled(p, id, "food_pack", true))
		_conserved(game, start, consumed)
	var moved_ticket: int = game.actions.sled_move_serial
	assert_false(game.actions._sled_moved(p, moved_ticket))
	_conserved(game, start, consumed)
	assert_true(game.actions.move_sled(p, id, "food_pack", false))
	_conserved(game, start, consumed)
	var at: Vector3 = p.position
	p.position.x += 4.0
	assert_false(game.actions.move_sled(p, id, "scrap", true))
	p.position = at + Vector3(0, 3, 0)
	assert_false(game.actions.move_sled(p, id, "scrap", true))
	p.position = at
	assert_false(game.actions.move_sled(p, id + 99, "scrap", true))
	_conserved(game, start, consumed)
	assert_true(game.actions.pull_sled(p, id))
	_conserved(game, start, consumed)
	game.actions.release_sled(p)
	_finish_work(game)
	_conserved(game, start, consumed)
	var saved: Dictionary = _saved(game)
	for exact_mode: bool in [false, true]:
		_apply(game, saved, exact_mode)
		_conserved(game, start, consumed)
	assert_true(game.actions.load_train(p))
	_conserved(game, start, consumed)
	assert_false(game.actions.load_train(p))
	_conserved(game, start, consumed)


func test_d10_pane_moves_counts_immediately_past_capacity() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	p.items = {"junk_nails": 25, "scrap": 2}
	var sled: Dictionary = _sled(game, {"scrap": 24})
	var id: int = int(sled["id"])
	var start: Dictionary = _counts(game)
	game.hud.sled_panel(id)
	assert_false(_buttons(game).has("모두 담기"))
	game.hud._inv_bag()
	game.hud._inv_put("junk_nails")
	assert_eq(int(sled["items"]["junk_nails"]), 25)
	assert_false(p.items.has("junk_nails"))
	assert_eq(p.action, "")
	_conserved(game, start, {})
	game.hud._inv_put("scrap")
	assert_eq(int(sled["items"]["scrap"]), 25)
	assert_eq(int(p.items["scrap"]), 1)
	assert_eq(Sled.state(sled), 3)
	_conserved(game, start, {})
	game.hud._inv_sled_take(id, "junk_nails")
	assert_eq(int(p.items["junk_nails"]), 25)
	_conserved(game, start, {})
	game.hud._inv_sled_take(id, "scrap")
	assert_eq(int(p.items["scrap"]), 2)
	assert_eq(Sled.state(sled), 2)
	assert_eq(p.action, "")
	_conserved(game, start, {})
	game.hud._close_modal()


# D11: Same build and seed; the caller separately compares the pre-change HEAD.
func test_d11_unused_sled_queries_do_not_change_field_or_rng() -> void:
	var plain: Variant = _game()
	var queried: Variant = _game()
	var before: int = queried.rng.state
	for _query: int in 20:
		Sled.can_craft(queried, queried.player)
		Sled.placement(queried, queried.player)
		queried.actions.near_sleds(queried.player)
		Sled.speed_mult(queried, queried.player)
	assert_eq(queried.rng.state, before)
	for tick: int in 40:
		for game: Variant in [plain, queried]:
			game.player.stick = Vector2.RIGHT if tick < 20 else Vector2.ZERO
			game._step(0.1)
	assert_eq(queried.sleds, [])
	assert_eq(queried.next_sled_id, 1)
	for row: Dictionary in _saved(queried)["people"]:
		assert_false(row["state"].has("sled_rearm_t"))
	assert_eq(queried.rng.state, plain.rng.state)
	assert_eq(queried.zombies.loot_rng.state, plain.zombies.loot_rng.state)
	assert_eq(queried.combat._pace_rng.state, plain.combat._pace_rng.state)
	var first: Dictionary = _without_unseeded(_saved(plain))
	var second: Dictionary = _without_unseeded(_saved(queried))
	assert_eq(second, first, "no query creates a reservation, spends an id, or advances a random stream")


## The combat's gear and wound streams are not seeded (each new game rolls its own),
## so two games never match on them, sled or no sled; everything else must.
func _without_unseeded(saved: Dictionary) -> Dictionary:
	var runtime: Dictionary = saved.get("runtime", {})
	var components: Dictionary = runtime.get("components", {})
	var combat: Dictionary = components.get("combat", {})
	combat.erase("_gear_rng")
	combat.erase("_wound_rng")
	return saved


func test_d3_surrender_card_and_direct_shoot_wait_for_rearm() -> void:
	var game: Variant = _game(true)
	assert_eq(game.raiders.size(), 1)
	if game.raiders.is_empty():
		return
	var p: Variant = game.player
	var raider: Variant = game.raiders[0]
	var sled: Dictionary = _sled(game)
	assert_true(game.actions.pull_sled(p, int(sled["id"])))
	game.ai._surrender(raider)
	var dropped: Array = game.ground_items.duplicate(true)
	var decisions: Array = game.decisions.duplicate(true)
	var sounds: Array = game.sounds.duplicate(true)
	var witnesses: Array = game.receipt._witnessed.duplicate(true)
	for released: bool in [false, true]:
		if released:
			game.actions.release_sled(p)
			assert_eq(p.sled_id, 0)
			assert_gt(p.sled_rearm_t, 0.0)
		assert_true(p.sled_weapon_stowed)
		var shoot: Button = game.hud.modal.find_child("Say_shoot", true, false) as Button
		assert_not_null(shoot)
		if shoot == null:
			return
		assert_true(shoot.disabled)
		assert_eq(shoot.modulate, Color(0.5, 0.5, 0.5))
		var words: String = ""
		for label: Label in shoot.find_children("*", "Label", true, false):
			words += label.text.replace(FieldHud.UiFonts.WORD_JOINER, "")
		assert_true(words.contains("무기를 썰매 짐에 묶어 두었다."))
		game.ai._on_surrender_choice("shoot", raider)
		var reopened: Button = game.hud.modal.find_child("Say_shoot", true, false) as Button
		assert_true(reopened.disabled)
		for choice: String in ["take", "disarm"]:
			var other: Button = game.hud.modal.find_child("Say_" + choice, true, false) as Button
			assert_false(other.disabled)
		assert_true(raider.is_alive())
		assert_eq(String(raider.brain["state"]), "surrender")
		assert_eq(game.sounds, sounds)
		assert_eq(game.decisions, decisions)
		assert_eq(game.receipt._witnessed, witnesses)
		assert_eq(game.ground_items, dropped, "reopening does not surrender or drop a weapon twice")
	Sled.tick_rearm(p, 1.01)
	assert_false(p.sled_weapon_stowed)
	game.ai._surrender_card(raider)
	var ready: Button = game.hud.modal.find_child("Say_shoot", true, false) as Button
	assert_false(ready.disabled)
	assert_eq(ready.modulate, Color.WHITE)
	ready.pressed.emit()
	assert_false(raider.is_alive())
	assert_eq(game.decisions.size(), decisions.size() + 1)
	assert_eq(game.decisions[-1], {"id": "raider_surrender", "choice": "shoot"})
	assert_eq(String(game.sounds[-1]["tag"]), "gun")
	assert_eq(game.receipt._witnessed.size(), witnesses.size() + 1)


func _take_box(game: Variant, contents: Array) -> Dictionary:
	var box: Dictionary = {"id": "sled_weapons", "name": "보관함", "cell": Vector2i(11, 20), "level": 0,
		"building": -1, "search": 1.0, "items": contents.duplicate(), "locked": false, "searched": true}
	game.data["containers"]["sled_weapons"] = box
	game.view.add_container("sled_weapons")
	return box


func test_d3_rearm_blocks_box_row_and_ground_weapon_until_one_second() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	p.set_weapon_slots([{"id": "knife", "quality": "factory", "condition": 0.73, "loaded": 0}])
	p.items = {"scrap": 1}
	var box: Dictionary = _take_box(game, ["pistol"])
	var sled: Dictionary = _sled(game)
	assert_true(game.actions.pull_sled(p, int(sled["id"])))
	game.actions.release_sled(p)
	assert_eq(p.sled_id, 0)
	assert_eq(p.sled_rearm_t, 1.0)
	var bag: Dictionary = p.items.duplicate(true)
	var hands: Array = p.hands.duplicate(true)
	game.ground_items.append({"pos": p.position, "id": "pistol", "n": 1,
		"weapon": {"id": "pistol", "quality": "factory", "condition": 0.41, "loaded": 2}})
	game.ground_items.append({"pos": p.position, "id": "wood_stake", "n": 1})
	var ground: Array = game.ground_items.duplicate(true)
	game.hud.loot("sled_weapons")
	game.hud._loot_take("sled_weapons", 0)
	game.actions.pick_up(p, 0)
	game.actions.pick_up(p, 1)
	assert_eq(p.action, "")
	assert_eq(game.actions.taking_item(p), "")
	assert_eq(box["items"], ["pistol"])
	assert_eq(p.items, bag)
	assert_eq(p.hands, hands)
	assert_eq(game.ground_items, ground)
	Sled.tick_rearm(p, 0.99)
	assert_true(p.sled_weapon_stowed)
	game.hud._loot_take("sled_weapons", 0)
	assert_eq(p.action, "")
	Sled.tick_rearm(p, 0.02)
	assert_false(p.sled_weapon_stowed)
	game.hud._loot_take("sled_weapons", 0)
	assert_eq(p.action, "take")
	_finish_work(game)
	assert_eq(box["items"], [])
	assert_eq(p.items, bag)
	assert_eq(p.hands.size(), 2)
	assert_eq(String(p.hands[0]["id"]), "pistol")
	assert_eq(game.ground_items, ground)
	game.actions.pick_up(p, 1)
	assert_eq(int(p.items.get("wood_stake", 0)), 1)
	assert_eq(game.ground_items.size(), 1)


func test_d3_take_completion_and_take_all_preserve_stowed_weapons() -> void:
	for full_hands: bool in [false, true]:
		var game: Variant = _game()
		var p: Variant = game.player
		p.set_weapon_slots([{"id": "knife", "quality": "factory", "condition": 1.0, "loaded": 0},
			{"id": "axe", "quality": "factory", "condition": 1.0, "loaded": 0}] if full_hands else [])
		var hands: Array = p.hands.duplicate(true)
		var box: Dictionary = _take_box(game, ["pistol", "scrap"])
		assert_true(game.actions._begin_take(p, "sled_weapons", "pistol"))
		# A completion already in flight must not fall through into the bag.
		p.sled_weapon_stowed = true
		p.sled_rearm_t = 1.0
		_finish_work(game)
		assert_eq(box["items"], ["pistol", "scrap"])
		assert_eq(p.items, {})
		assert_eq(p.hands, hands)
		assert_false(bool(box.get("busy", false)))
		game.actions.take_all(p, "sled_weapons")
		assert_eq(game.actions.taking_item(p), "scrap", "the queue skips the weapon and continues")
		_finish_work(game)
		assert_eq(box["items"], ["pistol"])
		assert_eq(p.items, {"scrap": 1})
		assert_eq(p.hands, hands)
		assert_eq(p.action, "")
		assert_false(game.actions.take_queue.has(p.get_instance_id()))


func test_d3_whittling_keeps_plank_while_weapon_is_stowed() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	p.set_weapon_slots([])
	p.items = {"plank": 1}
	var sled: Dictionary = _sled(game)
	assert_true(game.actions.pull_sled(p, int(sled["id"])))
	game.actions.release_sled(p)
	game.actions.whittle_stake(p)
	assert_eq(p.action, "")
	game.actions._whittled(p)
	assert_false(game.actions._into_hand(p, "wood_stake"))
	assert_eq(p.items, {"plank": 1})
	assert_eq(p.hands, [])
	Sled.tick_rearm(p, 1.01)
	game.actions.whittle_stake(p)
	assert_eq(p.action, "craft")
	_finish_work(game)
	assert_eq(p.items, {})
	assert_eq(p.hands.size(), 1)
	assert_eq(String(p.hands[0]["id"]), "wood_stake")


func test_d5_taut_rope_stays_put_on_two_half_metre_backsteps() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	p.position = Vector3(11.35, 0, 20.5)
	var sled: Dictionary = _sled(game)
	sled["pos"] = Vector3(10, 0, 20.5)
	var parked: Vector3 = sled["pos"]
	assert_true(game.actions.pull_sled(p, int(sled["id"])))
	for _step: int in 2:
		var dest: Vector3 = p.position - Vector3(0.5, 0, 0)
		Sled.before_move(game, p, dest)
		p.position = dest
		assert_eq(sled["pos"], parked)
		assert_eq(sled["trail"][-1], dest)
		assert_eq(sled["trail"].size(), 2)
		assert_true(Sled.trail_clear(game, sled, p.position))


func test_d5_corner_backsteps_keep_sled_and_clear_bends() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	p.position = Vector3(11.1, 0, 20.8)
	var sled: Dictionary = _sled(game)
	sled["pos"] = Vector3(10.8, 0, 20.8)
	game.grid.set_solid(Vector2i(10, 21), FieldGrid.Solid.WALL)
	assert_true(game.actions.pull_sled(p, int(sled["id"])))
	var round_corner: Vector3 = Vector3(11.1, 0, 22.0)
	Sled.before_move(game, p, round_corner)
	p.position = round_corner
	var parked: Vector3 = sled["pos"]
	assert_gt(parked.x, 10.8, "the initial outward step actually pulled the sled")
	assert_false(Sled.path_clear(game, parked, p.position))
	for dest: Vector3 in [Vector3(11.1, 0, 21.6), Vector3(11.1, 0, 21.2)]:
		Sled.before_move(game, p, dest)
		p.position = dest
		assert_eq(sled["pos"], parked)
		assert_eq(sled["trail"][-1], dest)
		assert_true(Sled.trail_clear(game, sled, p.position))
		assert_eq(p.sled_id, int(sled["id"]))


func test_d5_two_hundred_zigzag_steps_keep_trail_small() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	var sled: Dictionary = _sled(game)
	assert_true(game.actions.pull_sled(p, int(sled["id"])))
	for step: int in 200:
		var old_person: Vector3 = p.position
		var old_sled: Vector3 = sled["pos"]
		var dest: Vector3 = Vector3(10.5 + float(step + 1) * 0.05, 0, 20.5 + (0.02 if step % 2 == 0 else 0.0))
		Sled.before_move(game, p, dest)
		p.position = dest
		assert_lte(sled["trail"].size(), 8, "step %d" % step)
		assert_eq(sled["trail"][-1], dest)
		assert_true(Sled.trail_clear(game, sled, p.position))
		assert_lte(old_sled.distance_to(sled["pos"]), old_person.distance_to(dest) + Sled.ROPE_EPS)


func test_d7_sled_refuses_body_items_and_dims_bag_rows() -> void:
	var game: Variant = _game()
	var p: Variant = game.player
	p.items = {"bandage": 2, "pistol": 1, "cloth": 1, "medkit": 1, "ammo_craft": 2,
		"flare": 1, "tweezers": 1, "needle_thread": 1, "can_opener": 1, "scrap": 2}
	var bag: Dictionary = p.items.duplicate(true)
	var sled: Dictionary = _sled(game)
	var id: int = int(sled["id"])
	var pane: Control = InventoryPane._bag_rows(game.hud, p, {"kind": "sled", "id": id})
	add_child(pane)
	var disabled: Dictionary = {}
	for key: Button in pane.find_children("*", "Button", true, false):
		if key.has_meta("item_id"):
			disabled[String(key.get_meta("item_id"))] = key.disabled
	for item: String in bag:
		assert_eq(bool(disabled.get(item, false)), item != "scrap", item)
		assert_eq(game.actions.goes_to_train(item), item == "scrap", item)
	pane.free()
	game.hud.sled_panel(id)
	game.hud._inv_bag()
	for item: String in bag:
		if item == "scrap":
			continue
		game.hud._inv_put(item)
		assert_eq(p.items, bag)
		assert_eq(sled["items"], {})
		var note: String = String(game.hud.toasts[-1]["l"].text).replace(FieldHud.UiFonts.WORD_JOINER, "")
		assert_eq(note, "이건 가방에 둔다")
	game.hud._inv_put("scrap")
	assert_eq(sled["items"], {"scrap": 1})
	assert_eq(int(p.items["scrap"]), 1)
	game.hud._inv_sled_take(id, "scrap")
	assert_eq(sled["items"], {})
	assert_eq(p.items, bag)


func test_d8_train_button_and_departure_conserve_sled_stock_and_named_receipts() -> void:
	# Whole stock units leave the receipt's existing rounding outside this check.
	var cargo: Dictionary = {"scrap": 2, "food_pack": 4, "rare_saw_blades": 2}
	for by_button: bool in [false, true]:
		var game: Variant = _game()
		var p: Variant = game.player
		p.items = cargo.duplicate()
		var sled: Dictionary = _sled(game)
		for item: String in cargo:
			assert_true(game.actions.goes_to_train(item))
			for _piece: int in int(cargo[item]):
				assert_true(game.actions.move_sled(p, int(sled["id"]), item, true))
		assert_eq(sled["items"], cargo)
		assert_eq(p.items, {})
		if by_button:
			assert_true(game.actions.load_train(p))
			assert_eq(game.unloaded, cargo)
			assert_eq(sled["items"], {})
			assert_false(game.actions.load_train(p))
		game.finish("departed")
		assert_eq(game.unloaded, cargo, "every accepted count reaches settlement exactly once")
		assert_eq(sled["items"], {})
		var receipt: Dictionary = game.saved_result["receipt"]
		assert_almost_eq(float(receipt["stock"].get("scrap", 0.0)), 6.0, EPS)
		assert_almost_eq(float(receipt["stock"].get("food", 0.0)), 2.0, EPS)
		assert_eq(receipt["items"]["gained"].count("rare_saw_blades"), 2)


func test_d7_offer_layout_wraps_two_four_six_at_both_widths() -> void:
	for view: Vector2 in [Vector2(1280, 720), Vector2(1560, 720)]:
		var screen: Rect2 = Rect2(Vector2.ZERO, view)
		var depart: Rect2 = Rect2(view + FieldHud.DEPART_AT, Vector2(140, 84))
		var context: Rect2 = Rect2(view + FieldHud.CONTEXT_AT, Vector2(140, 84))
		var faces: Rect2 = Rect2(Vector2(0, view.y - FieldHud.ALLIES_UP), Vector2(view.x, FieldHud.CHIP_TOKEN))
		for count: int in [2, 4, 6]:
			var sizes: Array[Vector2] = []
			for index: int in count:
				sizes.append(Vector2(100 if index == count - 1 else 180, 72))
			var gap: float = FieldHud.offer_gap(sizes, view, depart.position.x)
			assert_eq(gap, 24.0)
			var rects: Array[Rect2] = FieldHud.offer_rects(sizes, view, depart.position.x - gap, faces.position.y - 12.0)
			assert_eq(rects.size(), count)
			var first_row: int = 0
			for index: int in rects.size():
				var rect: Rect2 = rects[index]
				assert_eq(rect.size, sizes[index])
				assert_true(screen.encloses(rect))
				assert_false(rect.intersects(depart))
				assert_false(rect.intersects(context))
				assert_false(rect.intersects(faces))
				assert_lte(rect.end.x, depart.position.x - 24.0)
				assert_lte(rect.end.y, faces.position.y - 12.0)
				if rect.position.y == rects[0].position.y:
					first_row += 1
				for previous: int in index:
					assert_false(rect.intersects(rects[previous]))
			assert_eq(first_row, mini(count, 2 if view.x == 1280 else 3))
			assert_eq(rects[0].position.x, view.x * 0.5 - 260.0)
			if count == 2:
				assert_eq(rects[0].position, view * 0.5 + Vector2(-260, 90))
				assert_eq(rects[1].position, rects[0].position + Vector2(192, 0))


func test_d7_offer_reflows_open_list_from_live_node_bounds() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child(viewport)
	var game: Variant = _game(false, viewport)
	fields.append(viewport)
	var hud: Variant = game.hud
	for view: Vector2i in [Vector2i(1280, 720), Vector2i(1560, 720)]:
		viewport.size = view
		await get_tree().process_frame
		await get_tree().process_frame
		var depart: Rect2 = hud.depart_button.get_global_rect()
		var context: Rect2 = hud.context_button.get_global_rect()
		var faces: Rect2 = hud.allies_box.get_global_rect()
		var plate: StyleBox = hud.depart_button.get_theme_stylebox("normal")
		var seen: Vector2 = plate.get("seen")
		var drawn: Rect2 = Rect2(depart.get_center() - seen * 0.5, seen)
		assert_eq(seen, FieldHud.DEPART_SEEN)
		assert_gte(seen.y, FieldHud.MIN_TOUCH)
		assert_true(hud.touch_rect(hud.depart_button).encloses(drawn))
		var pressed_plate: StyleBox = hud.depart_button.get_theme_stylebox("pressed")
		var pressed_drawn: Rect2 = pressed_plate.call("_shape", depart)
		assert_true(hud.touch_rect(hud.depart_button).encloses(pressed_drawn))
		assert_gte(context.position.y - depart.end.y, 0.0)
		assert_gte(context.position.y - drawn.end.y, 0.0)
		assert_gte(context.position.y - pressed_drawn.end.y, 0.0)
		for count: int in [2, 4, 6]:
			var choices: Array = []
			for choice_index: int in count - 1:
				choices.append({"label": "선택 %d" % choice_index, "call": Callable()})
			hud.offer(choices)
			var first_y: float = (hud.offer_box.get_child(0) as Control).global_position.y
			var first_row: int = 0
			assert_eq(hud.offer_box.get_child_count(), count)
			for key: Control in hud.offer_box.get_children():
				var rect: Rect2 = key.get_global_rect()
				assert_true(Rect2(Vector2.ZERO, Vector2(view)).encloses(rect))
				assert_false(rect.intersects(depart))
				assert_false(rect.intersects(context))
				assert_false(rect.intersects(faces))
				assert_lte(rect.end.x, depart.position.x - 24.0)
				assert_gte(drawn.position.x - rect.end.x, 24.0)
				assert_lte(rect.end.y, faces.position.y - 12.0)
				if rect.position.y == first_y:
					first_row += 1
			assert_eq(first_row, mini(count, 2 if view.x == 1280 else 3))
	# Moving the actual pad changes the limit without changing any layout constant.
	hud.depart_button.position.x -= 40.0
	hud._layout_offer()
	var third: Control = hud.offer_box.get_child(2)
	var first: Control = hud.offer_box.get_child(0)
	assert_gt(third.position.y, first.position.y)
	hud._offer_pick(Callable())
	assert_eq(hud.offer_box.get_child_count(), 0)


func test_d9_legacy_body_cargo_drops_once_in_both_restore_paths() -> void:
	for exact_mode: bool in [false, true]:
		for by_button: bool in [false, true]:
			var game: Variant = _game()
			var sled: Dictionary = _sled(game, {"pistol": 1, "bandage": 2, "scrap": 2})
			var at: Vector3 = sled["pos"]
			var saved: Dictionary = _saved(game)
			var original: String = FieldSave.to_json(saved)
			for _restore: int in 2:
				_apply(game, saved, exact_mode)
				assert_eq(game.sleds[0]["items"], {"scrap": 2})
				assert_eq(game.ground_items.size(), 2, "exact resume must not duplicate either drop")
				var ground_counts: Dictionary = {}
				for ground: Dictionary in game.ground_items:
					ground_counts[String(ground["id"])] = int(ground["n"])
					assert_almost_eq(ground["pos"], at, Vector3.ONE * Sled.ROPE_EPS)
					if ground["id"] == "pistol":
						assert_eq(ground["weapon"], {"id": "pistol", "quality": "factory", "condition": 1.0, "loaded": 0})
					else:
						assert_false(ground.has("weapon"))
				assert_eq(ground_counts, {"pistol": 1, "bandage": 2})
				var rng_state: int = game.rng.state
				Sled.reconcile(game)
				assert_eq(game.rng.state, rng_state)
				assert_eq(game.ground_items.size(), 2)
			assert_eq(FieldSave.to_json(saved), original, "migration does not edit the source save")
			if by_button:
				assert_true(game.actions.load_train(game.player))
				assert_eq(game.unloaded, {"scrap": 2})
			game.finish("departed")
			assert_eq(game.unloaded, {"scrap": 2})
			assert_eq(game.sleds[0]["items"], {})
			assert_eq(game.ground_items.size(), 2)
			assert_almost_eq(float(game.saved_result["receipt"]["stock"].get("scrap", 0)), 2.0, EPS)
			_discard_field(game)


func test_d8_sled_unload_guards_keep_injected_body_cargo() -> void:
	for by_button: bool in [false, true]:
		var game: Variant = _game()
		var sled: Dictionary = _sled(game, {"pistol": 1, "bandage": 2, "scrap": 2})
		if by_button:
			assert_true(game.actions.load_train(game.player))
			assert_eq(sled["items"], {"pistol": 1, "bandage": 2})
			assert_eq(game.unloaded, {"scrap": 2})
			assert_false(game.actions.load_train(game.player))
		game.finish("departed")
		assert_eq(sled["items"], {"pistol": 1, "bandage": 2})
		assert_eq(game.unloaded, {"scrap": 2}, "both exits reject cargo that bypassed restore")
		assert_almost_eq(float(game.saved_result["receipt"]["stock"].get("scrap", 0)), 2.0, EPS)
		_discard_field(game)


func test_d9_dense_legacy_trail_simplifies_before_its_last_bend() -> void:
	for exact_mode: bool in [false, true]:
		var game: Variant = _game()
		var p: Variant = game.player
		var start: Vector3 = Vector3(10.8, 0, 20.8)
		var corner: Vector3 = Vector3(11.1, 0, 20.8)
		var end: Vector3 = Vector3(11.1, 0, 21.4)
		p.position = corner
		var sled: Dictionary = _sled(game, {"scrap": 2})
		sled["pos"] = start
		game.grid.set_solid(Vector2i(10, 21), FieldGrid.Solid.WALL)
		assert_true(game.actions.pull_sled(p, int(sled["id"])))
		var dense: PackedVector3Array = PackedVector3Array()
		for point_index: int in 59:
			dense.append(start.lerp(corner, float(point_index) / 58.0))
		dense.append(end)
		p.position = end
		sled["trail"] = dense
		assert_eq(dense.size(), 60)
		assert_lte(Sled.trail_length(dense), Sled.ROPE_LENGTH)
		assert_true(Sled.trail_clear(game, sled, p.position))
		assert_false(Sled.path_clear(game, start, end))
		var saved: Dictionary = _saved(game)
		_apply(game, saved, exact_mode)
		var restored: Dictionary = game.sleds[0]
		var trail: PackedVector3Array = restored["trail"]
		assert_eq(p.sled_id, int(restored["id"]))
		assert_eq(trail.size(), 3, "the dense front is reduced before the final blocked shortcut")
		assert_lte(trail.size(), Sled.TRAIL_MAX_POINTS)
		assert_almost_eq(trail[0], start, Vector3.ONE * Sled.ROPE_EPS)
		assert_almost_eq(trail[-1], end, Vector3.ONE * Sled.ROPE_EPS)
		assert_true(Sled.trail_clear(game, restored, p.position))
		assert_eq(restored["items"], {"scrap": 2})
		_discard_field(game)


func test_d9_irreducible_legacy_trail_over_cap_uses_safe_release() -> void:
	assert_eq(Sled.TRAIL_MAX_POINTS, 16)
	for exact_mode: bool in [false, true]:
		var game: Variant = _game()
		var p: Variant = game.player
		p.position = Vector3(3.5, 0, 8.5)
		var sled: Dictionary = _sled(game, {"scrap": 2})
		assert_true(game.actions.pull_sled(p, int(sled["id"])))
		var trail: PackedVector3Array = PackedVector3Array()
		for point_index: int in 20:
			trail.append(Vector3(2.5 + 2.0 * point_index, 0, 8.5 if point_index % 2 == 0 else 10.5))
			if point_index > 0 and point_index < 19:
				game.grid.set_solid(Vector2i(2 + 2 * point_index, 10 if point_index % 2 == 0 else 8), FieldGrid.Solid.WALL)
		for point_index: int in range(1, trail.size()):
			assert_true(Sled.path_clear(game, trail[point_index - 1], trail[point_index]))
		assert_eq(Sled.simplify_trail(game, trail).size(), 20, "all eighteen bends are required")
		p.position = trail[-1]
		sled["trail"] = trail
		var at: Vector3 = sled["pos"]
		var saved: Dictionary = _saved(game)
		_apply(game, saved, exact_mode)
		assert_eq(p.sled_id, 0)
		assert_true(p.sled_weapon_stowed)
		assert_gt(p.sled_rearm_t, 0.0, "the ordinary rope release starts drawing the weapon")
		assert_eq(game.sleds[0]["puller"], "")
		assert_false(game.sleds[0].has("trail"))
		assert_eq(game.sleds[0]["pos"], at)
		assert_eq(game.sleds[0]["items"], {"scrap": 2})
		assert_true(game.hud.toasts.any(func(row: Dictionary) -> bool: return String(row["l"].text).replace("\u2060", "") == "썰매가 걸려 줄을 놓았다"))
		_discard_field(game)


func test_d3_companion_search_respects_both_weapon_storage_states() -> void:
	for stowed: bool in [false, true]:
		var game: Variant = _game()
		var mate: Variant = game.squad[1]
		mate.position = game.player.position
		mate.bag = "pack"
		mate.set_weapon_slots([{"id": "knife", "quality": "factory", "condition": 0.75, "loaded": 0}])
		mate.sled_weapon_stowed = stowed
		var hands: Array = mate.hands.duplicate(true)
		var box: Dictionary = _take_box(game, ["pistol", "bandage", "scrap"])
		box["searched"] = false
		game.actions._searched(mate, "sled_weapons")
		assert_true(box["searched"])
		assert_eq(mate.hands, hands)
		assert_eq(int(mate.items.get("bandage", 0)), 1)
		assert_eq(int(mate.items.get("scrap", 0)), 1)
		assert_eq(int(mate.items.get("pistol", 0)), 0 if stowed else 1)
		assert_eq(box["items"], ["pistol"] if stowed else [])
		assert_true(game.ground_items.is_empty())
		_discard_field(game)


func test_d3_body_search_respects_both_weapon_storage_states() -> void:
	for stowed: bool in [false, true]:
		var game: Variant = _game()
		var p: Variant = game.player
		p.set_weapon_slots([])
		p.sled_weapon_stowed = stowed
		var weapon: Dictionary = {"id": "pistol", "quality": "factory", "condition": 0.43, "loaded": 3}
		var dead: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.4, 0, 0))
		dead["state"] = "dead"
		game.zombies.set_loot(dead, [{"id": "pistol", "n": 1, "weapon": weapon.duplicate()},
			{"id": "knife", "n": 2}, {"id": "bandage", "n": 2}, {"id": "scrap", "n": 1}])
		game.actions.search_body(p, int(dead["id"]))
		assert_eq(p.action, "loot")
		_finish_work(game)
		assert_true(dead["searched"])
		assert_eq(dead["loot"], [])
		assert_eq(int(p.items.get("bandage", 0)), 2)
		assert_eq(int(p.items.get("scrap", 0)), 1)
		if stowed:
			assert_eq(p.hands, [])
			assert_false(p.items.has("pistol"))
			assert_false(p.items.has("knife"))
			assert_eq(game.ground_items.size(), 2)
			for ground: Dictionary in game.ground_items:
				assert_eq(ground["pos"], p.position)
				if ground["id"] == "pistol":
					assert_eq(ground["weapon"], weapon)
				else:
					assert_eq(ground["id"], "knife")
					assert_eq(int(ground["n"]), 2)
			# A second completion cannot duplicate the weapons left at the feet.
			game.actions._body_searched(p, int(dead["id"]))
			assert_eq(game.ground_items.size(), 2)
			p.sled_weapon_stowed = false
			game.actions.pick_up(p, 0)
			game.actions.pick_up(p, 0)
		assert_eq(p.hands, [weapon])
		assert_eq(int(p.items.get("knife", 0)), 2)
		assert_true(game.ground_items.is_empty())
		_discard_field(game)


func _touch_field() -> Variant:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child(viewport)
	var game: Variant = _game(false, viewport)
	fields.append(viewport)
	return game


func test_b03_offer_blocks_new_depart_shove_attack_and_aim_presses() -> void:
	var game: Variant = _touch_field()
	var p: Variant = game.player
	var hud: Variant = game.hud
	p.set_weapon_slots([{"id": "pistol", "quality": "factory", "condition": 1.0, "loaded": 8}])
	hud.tick(0.0)
	await get_tree().process_frame
	hud.offer([{"label": "목록 유지", "call": Callable()}])
	var before: Array = [p.strike_t, p.shove_t, p.hold_attack, p.aim.active, hud.auto_aim]
	for key: Button in [hud.depart_button, hud.shove_button, hud.attack_button, hud.aim_button, hud.manual_button]:
		key.show()
		key.disabled = false
		var at: Vector2 = key.get_global_rect().get_center()
		for finger: int in [0, 7]:
			assert_true(hud.finger_down(finger, at))
			assert_false(hud.fingers.has(finger), "a covered pad never owns the new finger")
			hud.finger_up(finger, at)
			assert_false(key.button_pressed)
	assert_eq([p.strike_t, p.shove_t, p.hold_attack, p.aim.active, hud.auto_aim], before)
	assert_false(hud.modal_open, "departure did not open")
	assert_false(game.ended)
	# Walking and RUN still take new fingers while the offer remains up.
	var run_at: Vector2 = hud.run_button.get_global_rect().get_center()
	assert_true(hud.finger_down(12, run_at))
	assert_eq(hud.fingers[12]["pad"], hud.run_button)
	hud.finger_cancel(12)
	assert_true(hud.finger_down(13, hud.stick_home()))
	assert_eq(hud.fingers[13]["kind"], "stick")
	hud.finger_cancel(13)
	assert_eq(hud.offer_box.get_child_count(), 2)


func test_b03_top_offer_touch_rect_beats_overlapping_pad() -> void:
	var game: Variant = _touch_field()
	var hud: Variant = game.hud
	await get_tree().process_frame
	hud.depart_button.show()
	var picked: Array[String] = []
	for finger: int in [0, 7]:
		hud.offer([{"label": "아래 선택", "call": func() -> void: picked.append("아래")},
			{"label": "위 선택", "call": func() -> void: picked.append("위")}])
		var depart: Rect2 = hud.depart_button.get_global_rect()
		var top: Button = hud.offer_box.get_child(1) as Button
		for choice_index: int in 2:
			var choice: Button = hud.offer_box.get_child(choice_index) as Button
			choice.global_position = depart.position - Vector2(0, 72)
			choice.size = Vector2(180, 72)
		var at: Vector2 = depart.position + Vector2(20, 1)
		assert_false(top.get_global_rect().has_point(at), "only the offer's enlarged touch skirt holds it")
		assert_true(hud.touch_rect(top).has_point(at))
		assert_true(hud.touch_rect(hud.depart_button).has_point(at))
		assert_true(hud.finger_down(finger, at))
		assert_eq(hud.fingers[finger]["button"], top)
		assert_false(hud.depart_button.button_pressed)
		assert_true(hud.finger_up(finger, at))
		assert_eq(picked, ["위"])
		assert_eq(hud.offer_box.get_child_count(), 0)
		assert_false(hud.modal_open)
		# Choosing releases the pad immediately, in the same frame.
		assert_true(hud.finger_down(finger, depart.get_center()))
		assert_eq(hud.fingers[finger]["pad"], hud.depart_button)
		hud.finger_cancel(finger)
		picked.clear()


func test_b03_cancel_restores_pads_and_existing_fingers_finish() -> void:
	var game: Variant = _touch_field()
	var hud: Variant = game.hud
	await get_tree().process_frame
	hud.depart_button.show()
	var depart_at: Vector2 = hud.depart_button.get_global_rect().get_center()
	assert_true(hud.finger_down(4, depart_at))
	hud.offer([])
	assert_true(hud.finger_up(4, depart_at))
	assert_true(hud.modal_open, "a finger held before the offer keeps its old lift rule")
	hud._close_modal()
	hud.offer([])
	var cancel: Button = hud.offer_box.get_child(0) as Button
	var cancel_at: Vector2 = cancel.get_global_rect().get_center()
	assert_true(hud.finger_down(0, cancel_at))
	assert_true(hud.finger_up(0, cancel_at))
	assert_eq(hud.offer_box.get_child_count(), 0)
	for key: Button in [hud.depart_button, hud.shove_button, hud.attack_button, hud.aim_button, hud.manual_button]:
		key.show()
		key.disabled = false
		assert_true(hud.finger_down(8, key.get_global_rect().get_center()))
		assert_eq(hud.fingers[8]["kind"], "pad")
		assert_eq(hud.fingers[8]["pad"], key)
		hud.finger_cancel(8)


func test_b03_replaced_offer_does_not_fire_held_choice() -> void:
	var game: Variant = _touch_field()
	var hud: Variant = game.hud
	await get_tree().process_frame
	var picked: Array[String] = []
	hud.offer([{"label": "옛 선택", "call": func() -> void: picked.append("옛")}])
	var old_key: Button = hud.offer_box.get_child(0) as Button
	var at: Vector2 = old_key.get_global_rect().get_center()
	assert_true(hud.finger_down(5, at))
	hud.offer([{"label": "새 선택", "call": func() -> void: picked.append("새")}])
	assert_true(hud.finger_up(5, at))
	assert_true(picked.is_empty())
	assert_eq(hud.offer_box.get_child_count(), 2)


func test_b03_offer_gap_falls_back_only_when_one_choice_needs_it() -> void:
	var sizes: Array[Vector2] = [Vector2(180, 72), Vector2(100, 72)]
	for width: float in [720.0, 760.0]:
		var view: Vector2 = Vector2(width, 720)
		var depart_left: float = width + FieldHud.DEPART_AT.x
		var gap: float = FieldHud.offer_gap(sizes, view, depart_left)
		assert_eq(gap, 12.0 if width == 720.0 else 24.0)
		var rects: Array[Rect2] = FieldHud.offer_rects(sizes, view, depart_left - gap, 600.0)
		for rect: Rect2 in rects:
			assert_lte(rect.end.x, depart_left - gap)


## A save whose sled rows are not the shape the restore reads is refused before any
## of the game changes, so the read falls back to the good backup; a save from
## before sleds (no sled keys at all) still reads.
func test_d9_bad_sled_rows_send_the_read_to_the_backup() -> void:
	var game: Variant = _game()
	_sled(game, {"scrap": 2})
	var text: String = FieldSave.to_json(FieldSave.capture(game))
	assert_false(FieldSave.from_json(text).is_empty())
	var bad: Array[String] = []
	for shape: String in ["sleds_not_a_list", "items_not_counts", "no_pos", "next_id_text"]:
		var parsed: Dictionary = JSON.parse_string(text)
		match shape:
			"sleds_not_a_list":
				parsed["sleds"] = {}
			"items_not_counts":
				parsed["sleds"][0]["items"] = ["scrap"]
			"no_pos":
				parsed["sleds"][0].erase("pos")
			"next_id_text":
				parsed["next_sled_id"] = "two"
		bad.append(JSON.stringify(parsed))
		assert_true(FieldSave.from_json(bad[-1]).is_empty(), shape)
	var old: Dictionary = JSON.parse_string(text)
	old.erase("sleds")
	old.erase("next_sled_id")
	assert_false(FieldSave.from_json(JSON.stringify(old)).is_empty(), "a save from before sleds still reads")
	var path: String = "user://test_sled_bad_rows.json"
	FieldSave.clear(path)
	var main_file := FileAccess.open(path, FileAccess.WRITE)
	main_file.store_string(bad[0])
	main_file.close()
	var backup := FileAccess.open(path + ".bak", FileAccess.WRITE)
	backup.store_string(text)
	backup.close()
	var read: Dictionary = FieldSave.read(path)
	assert_false(read.is_empty(), "the good backup is read")
	assert_eq((read["sleds"] as Array).size(), 1)
	FieldSave.clear(path)
	_discard_field(game)
