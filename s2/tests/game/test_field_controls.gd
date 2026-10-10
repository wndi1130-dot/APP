extends "res://addons/gut/test.gd"
## Phone controls after build 47 (user feedback): the stick is fixed by default,
## running can be a hold, a drag released on empty ground shoots the ground,
## the shove comes out sooner, a raider who gave up is never hit, the ally
## buttons show the weapon, and the left side has no swap button.

const FieldGame = preload("res://game/field_game.gd")
const Boot = preload("res://game/boot.gd")

var game


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	# Open platform, nobody in the way.
	game.player.position = game.lift(Vector2i(60, 7), 0)
	for q in game.squad:
		if q != game.player:
			q.position = game.lift(Vector2i(30, 7), 0)


func _step(p, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		game._update_person(p, 0.02)
		t += 0.02


func _gun() -> void:
	game.player.hands = [{"id": "pistol", "quality": "factory", "condition": 1.0, "loaded": 8}]


func _raider(at: Vector3):
	var row := {"id": "npc_raider_t", "name": "약탈자", "role": "raider", "skills": {"strength": 6, "melee": 4, "shooting": 1, "stealth": 1, "search": 1}, "hands": [["axe", "factory", 0.9]]}
	var r = game.make_person(row, at)
	r.brain = {"role": "flanker", "state": "fight", "morale": 1.0, "last_seen": Vector3.ZERO, "home": at}
	game.raiders.append(r)
	return r


func _buttons(node: Node, out: Array = []) -> Array:
	if node is Button:
		out.append(node)
	for c in node.get_children():
		_buttons(c, out)
	return out


# ---------------------------------------------------------------- start screen

func test_start_screen_defaults_are_fixed_stick_and_toggle_run() -> void:
	var seen := {}
	for row in Boot.CHOICES:
		seen[row[0]] = row[2]
	assert_true(seen.has("stick_float"))
	assert_eq(seen["stick_float"][0][0], false, "fixed first, so it is the default")
	assert_eq(seen["stick_float"][1][0], true)
	assert_true(seen.has("run_mode"))
	assert_eq(seen["run_mode"][0][0], "toggle", "toggle stays the default")
	assert_eq(seen["run_mode"][1][0], "hold")
	assert_false(game.hud.stick_floats())
	assert_false(game.hud.run_hold())


# ---------------------------------------------------------------- the stick

func test_fixed_stick_origin_does_not_move_with_the_touch() -> void:
	var hud = game.hud
	var home: Vector2 = hud.stick_home()
	var size: Vector2 = hud._view_size()
	assert_lt(home.x, size.x * 0.25, "bottom left")
	assert_gt(home.y, size.y * 0.6)
	assert_gt(home.y - hud.STICK_R, hud.run_button.get_global_rect().end.y + 4.0 * hud.PX_PER_MM, "the run and crouch keys stay clear above it")
	var at := home + Vector2(30, -20)
	assert_true(hud.finger_down(0, at))
	assert_eq(hud.stick_index, 0)
	assert_eq(hud.stick_origin, home, "the base is home, not under the thumb")
	hud.finger_move(0, home + Vector2(hud.STICK_R * 3.0, 0))
	assert_eq(hud.stick_origin, home, "a long drag does not drag the base along")
	assert_almost_eq(game.player.stick.x, 1.0, 0.01, "full push, no more")
	hud.finger_move(0, home + Vector2(0, -hud.STICK_R * 0.5))
	assert_eq(hud.stick_origin, home)
	assert_almost_eq(game.player.stick.y, -0.5, 0.02)
	hud.finger_up(0, home)
	assert_eq(game.player.stick, Vector2.ZERO)
	assert_eq(hud.stick_origin, home)


func test_fixed_stick_ignores_a_touch_far_from_home() -> void:
	var hud = game.hud
	var far: Vector2 = hud.stick_home() + Vector2(hud.STICK_R * hud.STICK_CATCH + 90.0, 0)
	assert_lt(far.x, hud._view_size().x * 0.5, "still on the left half")
	hud.finger_down(0, far)
	assert_eq(hud.stick_index, -1, "no stick there")
	assert_true(hud.fingers[0]["kind"] == "hand", "the right-hand rules apply (a tap on the world)")


func test_floating_stick_still_follows_the_touch_when_set() -> void:
	game.opts["stick_float"] = true
	var hud = game.hud
	assert_true(hud.stick_floats())
	var at := Vector2(200, 400)
	hud.finger_down(0, at)
	assert_eq(hud.stick_index, 0)
	assert_eq(hud.stick_origin, at, "the base is where the thumb landed")
	hud.finger_move(0, at + Vector2(hud.STICK_R * 3.0, 0))
	assert_ne(hud.stick_origin, at, "a long drag takes the base along")
	assert_almost_eq(hud.stick_origin.x, at.x + hud.STICK_R * 2.0, 0.5)
	hud.finger_up(0, at)


func test_a_tap_on_the_fixed_stick_is_not_a_tap_on_the_world() -> void:
	var hud = game.hud
	var p = game.player
	p.hold_attack = false
	var home: Vector2 = hud.stick_home()
	var before: int = p.path.size()
	hud.finger_down(0, home)
	hud.finger_up(0, home)
	assert_eq(p.path.size(), before)
	assert_eq(hud.stick_index, -1)


# ---------------------------------------------------------------- run key modes

func test_run_key_toggles_by_default() -> void:
	var hud = game.hud
	var p = game.player
	var key: Vector2 = hud.run_button.get_global_rect().get_center()
	hud.finger_down(1, key)
	hud.finger_up(1, key)
	assert_true(hud.run_button.button_pressed, "stays on after the finger lifts")
	hud.finger_down(1, key)
	hud.finger_up(1, key)
	assert_false(hud.run_button.button_pressed)
	assert_false(p.running)


func test_hold_mode_runs_only_while_the_run_key_is_held() -> void:
	game.opts["run_mode"] = "hold"
	var hud = game.hud
	var p = game.player
	var home: Vector2 = hud.stick_home()
	hud.finger_down(0, home)
	hud.finger_move(0, home + Vector2(hud.STICK_R * 0.6, 0))
	_step(p, 0.1)
	assert_false(p.running, "walking to begin with")
	var key: Vector2 = hud.run_button.get_global_rect().get_center()
	hud.finger_down(1, key)
	assert_true(hud.run_button.button_pressed)
	assert_true(p.running, "held: running")
	hud.finger_move(0, home + Vector2(hud.STICK_R * 0.7, 0))
	assert_true(p.running, "the stick keeps it")
	hud.finger_up(1, key)
	assert_false(hud.run_button.button_pressed, "let go: the key is off again")
	assert_false(p.running, "and the run ends")
	hud.finger_move(0, home + Vector2(hud.STICK_R * 0.8, 0))
	assert_false(p.running, "the stick does not bring it back")
	hud.finger_up(0, home)


func test_hold_mode_cancelled_or_lost_run_key_lets_go() -> void:
	game.opts["run_mode"] = "hold"
	var hud = game.hud
	var key: Vector2 = hud.run_button.get_global_rect().get_center()
	hud.finger_down(1, key)
	assert_true(hud.run_button.button_pressed)
	hud.finger_cancel(1)
	assert_false(hud.run_button.button_pressed)
	hud.finger_down(1, key)
	hud.drop_touch()
	assert_false(hud.run_button.button_pressed)


func test_hold_mode_still_stands_a_crouching_player_up_and_rim_run_works() -> void:
	game.opts["run_mode"] = "hold"
	game.opts["stick_rim_run"] = true
	var hud = game.hud
	var p = game.player
	hud.crouch_button.button_pressed = true
	hud._toggle_crouch()
	assert_true(p.crouched)
	var key: Vector2 = hud.run_button.get_global_rect().get_center()
	hud.finger_down(1, key)
	assert_false(p.crouched)
	assert_false(hud.crouch_button.button_pressed)
	hud.finger_up(1, key)
	var home: Vector2 = hud.stick_home()
	hud.finger_down(0, home)
	hud.finger_move(0, home + Vector2(hud.STICK_R, 0))
	hud.tick(0.2)
	assert_true(p.running, "the rim option still runs")


func test_double_tap_run_still_works_on_the_fixed_stick() -> void:
	game.opts["double_tap_run"] = true
	var hud = game.hud
	var home: Vector2 = hud.stick_home()
	hud.finger_down(0, home)
	hud.finger_up(0, home)
	hud.finger_down(0, home)
	hud.finger_move(0, home + Vector2(50, 0))
	assert_true(game.player.running)
	hud.finger_up(0, home + Vector2(50, 0))
	assert_false(game.player.running)


# ---------------------------------------------------------------- free aim

func _shoot_until_a_tracer(press_at: Vector2, drag_to: Vector2, release_at: Vector2) -> Dictionary:
	var p = game.player
	var hud = game.hud
	game.combat.tracers.clear()
	var guard := 0
	while game.combat.tracers.is_empty() and guard < 30:
		guard += 1
		p.jam_t = 0.0
		p.reload_t = 0.0
		p.hands[0]["loaded"] = 8
		hud._press(press_at)
		hud._hand_move(drag_to)
		hud._release(release_at)
	assert_false(game.combat.tracers.is_empty(), "a shot left the gun")
	return game.combat.tracers[0]


func _camera_like_a_phone() -> void:
	var p = game.player
	game.cam_size = 36.0
	game.cam_focus = p.position
	game._update_camera(1.0)


func test_release_over_empty_ground_fires_at_that_ground() -> void:
	_gun()
	_camera_like_a_phone()
	var p = game.player
	p.facing = PI * 0.5
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(6, 0, 0))
	game._refresh_vision()
	var ground: Vector3 = p.position + Vector3(0, 0, 7)
	var on_z: Vector2 = game.hud._project(z["pos"])
	var on_ground: Vector2 = game.hud._project(ground)
	var tr := _shoot_until_a_tracer(on_z, on_ground, on_ground)
	var end: Vector3 = tr["to"]
	assert_almost_eq(end.x, ground.x, 0.4, "the shot goes to the ground point")
	assert_almost_eq(end.z, ground.z, 0.4)
	assert_gt(Vector2(end.x - z["pos"].x, end.z - z["pos"].z).length(), 5.0, "not at the enemy first pressed")


func test_dragging_off_the_enemy_leaves_no_target_behind() -> void:
	_gun()
	_camera_like_a_phone()
	var p = game.player
	p.facing = PI * 0.5
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(6, 0, 0))
	game._refresh_vision()
	var on_z: Vector2 = game.hud._project(z["pos"])
	var on_ground: Vector2 = game.hud._project(p.position + Vector3(0, 0, 7))
	game.hud._press(on_z)
	assert_eq(game.hud.aim_target, z, "pressed on the enemy")
	game.hud._hand_move(on_ground)
	assert_null(game.hud.aim_target, "nobody near the finger now: no target kept")
	assert_almost_eq(game.hud.aim_point.z, p.position.z + 7.0, 0.4)
	game.hud._hand_move(on_z)
	assert_eq(game.hud.aim_target, z, "back on him: picked again")
	game.hud._release(on_z)


func test_release_near_an_enemy_still_picks_that_enemy() -> void:
	_gun()
	_camera_like_a_phone()
	var p = game.player
	# Both in the forward cone: one to the east, one to the south.
	p.facing = PI * 0.25
	var a: Dictionary = game.zombies.spawn("dead", p.position + Vector3(6, 0, 0))
	var b: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0, 0, 7))
	game._refresh_vision()
	var on_a: Vector2 = game.hud._project(a["pos"])
	var near_b: Vector2 = game.hud._project(b["pos"] + Vector3(0.5, 0, -0.4))
	game.hud._press(on_a)
	game.hud._hand_move(near_b)
	assert_eq(game.hud.aim_target, b, "within the pick radius of b")
	game.hud._release(near_b)
	game.hud.aim_target = null
	var tr := _shoot_until_a_tracer(on_a, near_b, near_b)
	var end: Vector3 = tr["to"]
	assert_almost_eq(end.x, b["pos"].x, 0.01, "snapped onto b")
	assert_almost_eq(end.z, b["pos"].z, 0.01)


func test_a_press_that_never_moves_stays_on_the_enemy_pressed() -> void:
	_gun()
	_camera_like_a_phone()
	var p = game.player
	p.facing = PI * 0.5
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(6, 0, 0))
	game._refresh_vision()
	var on_z: Vector2 = game.hud._project(z["pos"])
	var tr := _shoot_until_a_tracer(on_z, on_z + Vector2(6, 4), on_z + Vector2(6, 4))
	assert_almost_eq(tr["to"].x, z["pos"].x, 0.01)
	assert_almost_eq(tr["to"].z, z["pos"].z, 0.01)


func test_manual_mode_on_empty_ground_still_fires_at_the_ground() -> void:
	_gun()
	_camera_like_a_phone()
	var p = game.player
	game.hud.manual_button.button_pressed = true
	var ground: Vector3 = p.position + Vector3(8, 0, 0)
	var at: Vector2 = game.hud._project(ground)
	var tr := _shoot_until_a_tracer(at, at + Vector2(20, 0), at + Vector2(20, 0))
	assert_almost_eq(tr["to"].z, ground.z, 0.8)


# ---------------------------------------------------------------- shove

func test_shove_lockout_is_about_a_third_of_a_second() -> void:
	var p = game.player
	assert_almost_eq(game.combat.SHOVE_TIME, 0.35, 0.001)
	p.facing = PI * 0.5
	game.zombies.spawn("dead", p.position + Vector3(0.8, 0, 0))
	game.combat.shove(p)
	var m: float = float(p.mults()["swing"])
	assert_almost_eq(p.swing_t, 0.35 / m, 0.001)
	assert_lt(p.swing_t, 0.4)


func test_a_second_shove_inside_the_lockout_still_does_nothing() -> void:
	var p = game.player
	p.facing = PI * 0.5
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.8, 0, 0))
	game.combat.shove(p)
	var t0: float = p.swing_t
	var after_first: Vector3 = z["pos"]
	var cooldown: float = z["cooldown"]
	# Mash the button: the zombie stands where the first one left it.
	game.combat.update(0.1)
	z["pos"] = p.position + Vector3(0.8, 0, 0)
	after_first = z["pos"]
	game.combat.shove(p)
	assert_almost_eq(p.swing_t, t0 - 0.1, 0.001, "the swing time is not restarted")
	assert_eq(z["pos"], after_first, "nobody is pushed again")
	assert_eq(z["cooldown"], cooldown)
	# After the lockout the next one comes out.
	game.combat.update(0.3)
	assert_eq(p.swing_t, 0.0)
	game.combat.shove(p)
	assert_gt(p.swing_t, 0.0, "ready again")
	assert_ne(z["pos"], after_first, "and it pushes")


func test_the_shove_pad_does_nothing_inside_the_lockout() -> void:
	var p = game.player
	var hud = game.hud
	p.facing = PI * 0.5
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.8, 0, 0))
	hud._shove()
	assert_eq(z["pos"], p.position + Vector3(0.8, 0, 0), "the arms come back first")
	game.combat.update(game.combat.SHOVE_WINDUP + 0.01)
	var pos1: Vector3 = z["pos"]
	var t1: float = p.swing_t
	z["pos"] = p.position + Vector3(0.8, 0, 0)
	hud._shove()
	assert_eq(z["pos"], p.position + Vector3(0.8, 0, 0))
	assert_eq(p.swing_t, t1)
	assert_ne(pos1, p.position + Vector3(0.8, 0, 0))


# ---------------------------------------------------------------- a raider who gave up

func test_a_fleeing_raider_is_not_a_target_any_more() -> void:
	var p = game.player
	var r = _raider(p.position + Vector3(1.0, 0, 0))
	r.visible = true
	assert_true(game.combat.hostile(r))
	assert_eq(game.hud._pick_enemy(r.position), r, "a fighting raider can be picked")
	assert_eq(game.combat.melee_pick(p), r)
	r.brain["state"] = "flee"
	assert_false(game.combat.hostile(r), "disarmed and sent off: let go")
	assert_null(game.hud._pick_enemy(r.position))
	assert_null(game.combat.melee_pick(p))
	p.hands = [{"id": "pistol", "quality": "factory", "condition": 1.0, "loaded": 8}]
	assert_false(game.combat.aim_candidates(p).has(r))


func test_every_state_that_gave_up_drops_the_target_and_nothing_swings() -> void:
	var p = game.player
	p.hands = [{"id": "axe", "quality": "factory", "condition": 0.9, "loaded": 0}]
	for state in ["surrender", "flee", "prisoner", "gone"]:
		var r = _raider(p.position + Vector3(1.0, 0, 0))
		r.visible = true
		game.combat.fight(p, r, true)
		assert_eq(p.target_person, r, "while he fights, the order stands")
		r.brain["state"] = state
		game.combat.update(0.02)
		assert_null(p.target_person, "%s: dropped" % state)
		assert_false(p.hold_attack, "%s: no held attack left over" % state)
		assert_eq(p.swing_t, 0.0, "%s: no blow" % state)
		assert_false(game.combat.fighting(p))
		# A late order on him (a finger still down) is refused too.
		game.combat.fight(p, r, true)
		assert_null(p.target_person, "%s: not taken up again" % state)
		game.raiders.erase(r)


func test_a_companion_with_an_order_on_a_raider_drops_it_when_he_gives_up() -> void:
	var comp = null
	for q in game.squad:
		if q != game.player:
			comp = q
			break
	var r = _raider(comp.position + Vector3(1.0, 0, 0))
	game.combat.melee_person(comp, r)
	assert_eq(comp.target_person, r)
	game.ai._surrender(r)
	assert_null(comp.target_person)
	assert_false(comp.hold_attack)
	# A stale order does not strike, whoever holds it.
	comp.target_person = r
	comp.hold_attack = true
	game.combat.update(0.02)
	assert_null(comp.target_person)
	assert_eq(comp.swing_t, 0.0)


func test_companions_do_not_shoot_a_raider_who_gave_up_or_ran() -> void:
	var comp = null
	for q in game.squad:
		if q != game.player:
			comp = q
			break
	comp.position = game.lift(Vector2i(60, 7), 0) + Vector3(0, 0, 5)
	var r = _raider(game.lift(Vector2i(60, 7), 0) + Vector3(5, 0, 5))
	r.brain["aware_of_us"] = true
	game._refresh_vision()
	assert_eq(game.ai._hostile_raider_near(comp, 20.0), r, "baseline: a fighting raider is a target")
	for state in ["surrender", "flee", "prisoner", "gone"]:
		r.brain["state"] = state
		assert_null(game.ai._hostile_raider_near(comp, 20.0), state)


func test_a_finger_down_on_a_raider_who_just_gave_up_hits_nothing() -> void:
	var p = game.player
	var hud = game.hud
	p.hands = [{"id": "axe", "quality": "factory", "condition": 0.9, "loaded": 0}]
	var r = _raider(p.position + Vector3(1.0, 0, 0))
	r.visible = true
	hud.pressing = true
	hud.press_ms = Time.get_ticks_msec() - 1000   # held long enough to start the hold
	hud.melee_pending = r
	game.ai._surrender(r)
	hud.tick(0.02)
	assert_null(p.target_person, "the held order on him is refused")
	assert_null(hud.melee_pending, "and the held target is let go")
	hud.pressing = false
	game.combat.update(0.02)
	assert_eq(p.swing_t, 0.0)


func test_a_shot_aimed_at_a_raider_who_then_gave_up_hurts_nobody() -> void:
	var p = game.player
	var hud = game.hud
	_gun()
	var r = _raider(p.position + Vector3(6.0, 0, 0))
	r.visible = true
	hud.aim_target = r
	game.ai._surrender(r)
	hud._drop_stale_person()
	assert_null(hud.aim_target, "the aim lets go of him")
	var guard := 0
	while guard < 12:
		guard += 1
		p.jam_t = 0.0
		p.reload_t = 0.0
		p.hands[0]["loaded"] = 8
		game.combat.fire(p, r.position, r)   # even a stale fire call finds no one to hit
	assert_eq(r.last_hurt_by, "", "never hurt")
	assert_eq(r.body.bleed, 0)


# ---------------------------------------------------------------- the bottom bar and the left side

func test_each_ally_button_shows_the_name_and_the_weapon_held() -> void:
	var hud = game.hud
	hud.tick(0.02)
	assert_gt(hud.ally_buttons.size(), 0)
	for row in hud.ally_buttons:
		var p = row["p"]
		var b: Button = row["b"]
		var first: String = b.text.split("\n")[0]
		assert_true(first.contains(p.display_name), "the name")
		assert_true(first.contains(hud.short_weapon(p)), "the weapon: " + first)
	# A different weapon in hand changes the button.
	var comp = hud.ally_buttons[0]["p"]
	comp.hands = [{"id": "bow", "quality": "factory", "condition": 0.9, "loaded": 1}]
	hud.tick(0.02)
	assert_eq(hud.short_weapon(comp), "활", "short name: the last word")
	assert_true(String(hud.ally_buttons[0]["b"].text).contains("활"))
	comp.hands = []
	hud.tick(0.02)
	assert_true(String(hud.ally_buttons[0]["b"].text).contains("맨손"))


func test_the_ally_bar_has_no_swap_button() -> void:
	for b in _buttons(game.hud.allies_box):
		assert_false(String(b.text).contains("바꾸"), "no swap in the bar")
		assert_ne(String(b.text), "무기")


func test_no_weapon_button_on_the_left_but_the_bag_stays() -> void:
	var texts: Array = []
	for b in _buttons(game.hud.root):
		if b.get_global_rect().position.x < game.hud._view_size().x * 0.5:
			texts.append(String(b.text))
	assert_false(texts.has("무기"), "no weapon button on the left")
	assert_true(texts.has("가방"), "the bag is still there")


func test_the_bag_button_stays_off_the_fixed_stick() -> void:
	var hud = game.hud
	var bag: Button = null
	for b in _buttons(hud.root):
		if b.text == "가방":
			bag = b
	assert_not_null(bag)
	var rect: Rect2 = bag.get_global_rect()
	var near: Vector2 = Vector2(clampf(hud.stick_home().x, rect.position.x, rect.end.x), clampf(hud.stick_home().y, rect.position.y, rect.end.y))
	assert_gt(near.distance_to(hud.stick_home()), hud.STICK_R * hud.STICK_CATCH, "outside the stick's catch ring")


func test_swapping_is_inside_the_bag_panel() -> void:
	var hud = game.hud
	var p = game.player
	assert_gt(p.hands.size(), 1)
	var first: String = p.weapon_id()
	hud.bag_panel()
	var swap: Button = null
	for b in _buttons(hud.modal):
		if b.text == "바꾸기":
			swap = b
	assert_not_null(swap, "a swap button in the bag panel")
	swap.pressed.emit()
	assert_false(hud.modal_open, "the panel closes")
	assert_eq(p.action, "swap")
	for i in range(100):
		game._update_person(p, 0.05)
	assert_ne(p.weapon_id(), first, "the other weapon is in hand")


# Build 89 (user): the shove landed the instant the key went down and the body
# jumped back. Now it winds up, and the shoved body is seen going back.
func test_a_shove_winds_up_and_the_body_is_seen_going_back() -> void:
	var p = game.player
	var hud = game.hud
	p.facing = PI * 0.5
	var from: Vector3 = p.position + Vector3(0.8, 0, 0)
	var z: Dictionary = game.zombies.spawn("dead", from)
	hud._shove()
	assert_gt(p.shove_t, 0.0)
	hud._shove()
	game.combat.update(0.05)
	assert_eq(z["pos"], from, "not yet")
	game.combat.update(game.combat.SHOVE_WINDUP)
	assert_gt(z["pos"].distance_to(from), 1.0, "it lands")
	assert_gt(p.lunge_t, 0.0)
	assert_almost_eq(game.zombies.draw_pos(z).distance_to(from), 0.0, 0.01, "drawn where it stood")
	game.zombies.update(game.zombies.SHOVED_TIME * 0.5)
	var mid: float = game.zombies.draw_pos(z).distance_to(from)
	assert_gt(mid, 0.3)
	game.zombies.update(game.zombies.SHOVED_TIME)
	assert_eq(game.zombies.shoved_k(z), 1.0, "then it is drawn where the rules have it")


func test_paused_the_stick_can_be_switched_between_fixed_and_following() -> void:
	var hud = game.hud
	hud.tick(0.02)
	assert_false(hud.stick_opt_button.visible, "only while paused")
	game.paused = true
	hud.tick(0.02)
	assert_true(hud.stick_opt_button.visible)
	assert_false(hud.stick_floats())
	hud._pad_down(hud.stick_opt_button, Vector2.ZERO)
	assert_true(hud.stick_floats())
	hud.tick(0.02)
	assert_eq(hud.stick_opt_button.text, "스틱: 따라오기")
	hud._pad_down(hud.stick_opt_button, Vector2.ZERO)
	assert_false(hud.stick_floats())


func test_the_dusk_test_key_jumps_to_1540_and_keeps_the_next_horde_as_far_off() -> void:
	var hud = game.hud
	var gap: float = game.director.next_arrival - game.clock.elapsed
	hud._debug_dusk()
	assert_almost_eq(game.clock.game_minutes(), 940.0, 0.01)
	assert_false(game.clock.is_dark())
	assert_almost_eq(game.director.next_arrival - game.clock.elapsed, gap, 0.01)
	var at: float = game.clock.elapsed
	hud._debug_dusk()
	assert_eq(game.clock.elapsed, at, "a second press does nothing")


func test_state_icons_sit_in_a_small_column_at_the_right_edge() -> void:
	var p = game.player
	var hud = game.hud
	p.body.add_wound("torso", "deep", 0.0)
	p.body.add_wound("arm_left", "fracture", 0.0)
	hud.tick(0.02)
	await wait_frames(2)
	var view: Vector2 = hud.root.get_viewport_rect().size
	var a: Rect2 = hud.status_pads[0].get_global_rect()
	var b: Rect2 = hud.status_pads[1].get_global_rect()
	assert_gt(a.position.x, view.x * 0.8, "right edge")
	assert_almost_eq(a.end.x, b.end.x, 0.5, "one column, right-aligned")
	assert_gt(b.position.y, a.end.y - 0.5, "one under the other")
	assert_lt(hud.status_pads[0].get_theme_font_size("font_size"), 18, "small words")
	for pad in [hud.shove_button, hud.manual_button, hud.aim_button]:
		assert_false(hud.status_pads[4].get_global_rect().intersects(pad.get_global_rect()))

