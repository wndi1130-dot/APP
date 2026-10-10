extends "res://addons/gut/test.gd"
## The body picture (body_injury 4.6, H3 feedback on build 47): a tap on the
## portrait opens six parts with the most urgent wound chosen, two buttons a
## wound (first aid, full care), missing tools named, and the field slowed
## (not stopped) while it is up.

const FieldGame = preload("res://game/field_game.gd")
const Treatment = preload("res://game/sim/treatment.gd")

var game


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	game.player.position = game.lift(Vector2i(60, 7), 0)
	for q in game.squad:
		if q != game.player:
			q.position = game.lift(Vector2i(30, 7), 0)
	game.player.items = {}


func _step(p, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		game._update_person(p, 0.02)
		t += 0.02


func _row(wound: Dictionary) -> Dictionary:
	for row: Dictionary in game.hud.body_buttons:
		if is_same(row["wound"], wound):
			return row
	return {}


# ---------------------------------------------------------------- where things sit

func test_the_portrait_and_the_blood_key_are_off_the_fixed_stick() -> void:
	var hud = game.hud
	hud.tick(0.02)
	await wait_frames(2)
	var home: Vector2 = hud.stick_home()
	var catch_r: float = hud.STICK_R * hud.STICK_CATCH
	for rect: Rect2 in [hud.portrait.get_global_rect(), hud.blood_button.get_global_rect()]:
		var near := Vector2(clampf(home.x, rect.position.x, rect.end.x), clampf(home.y, rect.position.y, rect.end.y))
		assert_gt(near.distance_to(home), catch_r, "outside the stick's catch ring")
	var port: Rect2 = hud.portrait.get_global_rect()
	assert_gt(port.size.y, 40.0)
	for key in [hud.run_button, hud.crouch_button, hud.pause_button]:
		assert_false(port.intersects(key.get_global_rect()), "the portrait covers no key: " + key.text)
	assert_false(hud.blood_button.get_global_rect().intersects(port))


func test_a_tap_on_the_portrait_opens_the_body_picture() -> void:
	var hud = game.hud
	await wait_frames(2)
	var at: Vector2 = hud.portrait.get_global_rect().get_center()
	assert_true(hud.finger_down(0, at))
	assert_false(hud.modal_open, "on the lift, not on the press")
	hud.finger_up(0, at)
	assert_true(hud.modal_open)
	assert_eq(hud.body_shown, game.player)
	assert_eq(hud.body_parts.size(), 6)
	assert_eq(hud.stick_index, -1, "no stick was planted")


func test_a_drag_off_the_portrait_opens_nothing() -> void:
	var hud = game.hud
	await wait_frames(2)
	var at: Vector2 = hud.portrait.get_global_rect().get_center()
	hud.finger_down(0, at)
	hud.finger_up(0, at + Vector2(0, 300))
	assert_false(hud.modal_open)


# ---------------------------------------------------------------- time

func test_the_field_slows_and_does_not_stop_while_it_is_open() -> void:
	var hud = game.hud
	assert_eq(game.slow, 1.0)
	hud.body_panel()
	assert_false(game.paused, "not a pause")
	assert_almost_eq(game.slow, 0.3, 0.001)
	var before: float = game.clock.elapsed
	game._process(0.1)
	assert_almost_eq(game.clock.elapsed - before, 0.03, 0.001, "a tenth of a second passes as three hundredths")
	hud._close_modal()
	assert_eq(game.slow, 1.0)
	assert_false(game.paused)


func test_a_pause_set_before_stays_a_pause() -> void:
	var hud = game.hud
	game.paused = true
	hud.body_panel()
	assert_true(game.paused, "the picture does not lift a pause the player set")
	hud._close_modal()
	assert_true(game.paused)
	# And a stopping panel after a slowing one puts the rate back.
	game.paused = false
	hud.body_panel()
	hud.bag_panel()
	assert_eq(game.slow, 1.0)
	assert_true(game.paused)
	hud._close_modal()
	assert_false(game.paused)


# ---------------------------------------------------------------- what it shows

func test_the_most_urgent_wound_comes_chosen() -> void:
	var p = game.player
	var hud = game.hud
	p.body.add_wound("arm_left", "scratch", 0.0)
	var worst: int = p.body.add_wound("leg_right", "laceration", 0.0)
	p.body.add_wound("arm_right", "fracture", 0.0)
	hud.body_panel()
	assert_eq(hud.body_part, "leg_right", "the part that bleeds most")
	assert_eq(hud.body_buttons.size(), 1)
	assert_true(is_same(hud.body_buttons[0]["wound"], p.body.wounds[worst]))
	assert_true(String(hud.body_parts["leg_right"].text).contains("찢김"))
	assert_true(String(hud.body_parts["arm_right"].text).contains("골절"))
	assert_eq(String(hud.body_parts["torso"].text), "몸통", "a whole part shows its name only")


func test_no_wounds_opens_on_the_torso_with_nothing_to_do() -> void:
	var hud = game.hud
	hud.body_panel()
	assert_eq(hud.body_part, "torso")
	assert_eq(hud.body_buttons.size(), 0)


func test_pressing_a_part_shows_its_wounds_most_urgent_first() -> void:
	var p = game.player
	var hud = game.hud
	var scratch: int = p.body.add_wound("arm_left", "scratch", 0.0)
	var cut: int = p.body.add_wound("arm_left", "laceration", 0.0)
	p.body.add_wound("leg_right", "deep", 0.0)
	hud.body_panel()
	assert_eq(hud.body_part, "leg_right")
	hud.body_parts["arm_left"].pressed.emit()
	assert_true(hud.modal_open)
	assert_eq(hud.body_part, "arm_left")
	assert_eq(hud.body_buttons.size(), 2)
	assert_true(is_same(hud.body_buttons[0]["wound"], p.body.wounds[cut]), "more blood first")
	assert_true(is_same(hud.body_buttons[1]["wound"], p.body.wounds[scratch]))


func test_buttons_are_off_when_the_tools_are_missing() -> void:
	var p = game.player
	var hud = game.hud
	var cut: int = p.body.add_wound("arm_left", "laceration", 0.0)
	hud.body_panel()
	var row: Dictionary = _row(p.body.wounds[cut])
	assert_true(row["aid"].disabled, "no bandage: no first aid")
	assert_true(row["full"].disabled)
	p.add_item("bandage", 1)
	hud.body_panel()
	row = _row(p.body.wounds[cut])
	assert_false(row["aid"].disabled)
	assert_true(row["full"].disabled, "full care starts with cleaning, and there is no spirit")
	p.add_item("bottle_spirit", 1)
	hud.body_panel()
	row = _row(p.body.wounds[cut])
	assert_false(row["full"].disabled)


# ---------------------------------------------------------------- care

func test_first_aid_binds_the_wound_chosen_and_takes_one_bandage() -> void:
	var p = game.player
	var hud = game.hud
	var cut: int = p.body.add_wound("arm_left", "laceration", 0.0)
	p.add_item("bandage", 2)
	p.add_item("bottle_spirit", 1)
	hud.body_panel()
	_row(p.body.wounds[cut])["aid"].pressed.emit()
	assert_false(hud.modal_open, "the panel closes and the care goes on in the field")
	assert_eq(game.slow, 1.0)
	assert_eq(p.action, "treat")
	assert_eq(p.action_label, "붕대")
	_step(p, 5.0)
	assert_eq(p.action, "")
	assert_true(p.body.wounds[cut]["bandaged"])
	assert_false(p.body.wounds[cut]["disinfected"], "first aid does not clean")
	assert_eq(int(p.items.get("bandage", 0)), 1)
	assert_eq(int(p.items.get("bottle_spirit", 0)), 1)


func test_full_care_runs_every_step_in_order() -> void:
	var p = game.player
	var hud = game.hud
	var cut: int = p.body.add_wound("arm_left", "laceration", 0.0)
	p.add_item("bandage", 1)
	p.add_item("bottle_spirit", 1)
	hud.body_panel()
	_row(p.body.wounds[cut])["full"].pressed.emit()
	assert_eq(p.action_label, "소독")
	_step(p, 2.4)
	assert_true(p.body.wounds[cut]["disinfected"])
	assert_false(p.body.wounds[cut]["bandaged"])
	assert_eq(p.action_label, "붕대", "the next step starts by itself")
	_step(p, 5.0)
	assert_true(p.body.wounds[cut]["bandaged"])
	assert_eq(p.action, "")
	assert_false(p.items.has("bandage"))
	assert_false(p.items.has("bottle_spirit"))
	assert_eq(p.body.bleed_level(), 0)


func test_walking_off_cuts_the_care_short_and_keeps_what_was_done() -> void:
	var p = game.player
	var cut: int = p.body.add_wound("arm_left", "laceration", 0.0)
	p.add_item("bandage", 1)
	p.add_item("bottle_spirit", 1)
	assert_true(game.actions.treat_wound(p, p, p.body.wounds[cut], Treatment.FULL))
	_step(p, 2.4)
	assert_true(p.body.wounds[cut]["disinfected"])
	p.cancel_action()
	_step(p, 6.0)
	assert_false(p.body.wounds[cut]["bandaged"])
	assert_eq(int(p.items.get("bandage", 0)), 1, "nothing is taken for a step not finished")


func test_a_companion_is_treated_from_arms_reach_with_either_ones_bandage() -> void:
	var p = game.player
	var hud = game.hud
	var comp = null
	for q in game.squad:
		if q != p:
			comp = q
			break
	comp.items = {"bandage": 1}
	var cut: int = comp.body.add_wound("torso", "laceration", 0.0)
	hud.body_panel(comp)
	assert_eq(hud.body_shown, comp)
	assert_true(_row(comp.body.wounds[cut])["aid"].disabled, "too far away")
	assert_false(game.actions.treat_wound(p, comp, comp.body.wounds[cut], Treatment.FIRST_AID))
	comp.position = p.position + Vector3(1.0, 0, 0)
	hud.body_panel(comp)
	var row: Dictionary = _row(comp.body.wounds[cut])
	assert_false(row["aid"].disabled)
	row["aid"].pressed.emit()
	assert_eq(p.action, "treat", "the player does it")
	_step(p, 5.0)
	assert_true(comp.body.wounds[cut]["bandaged"])
	assert_false(comp.items.has("bandage"), "the bandage came from the one treated")


func test_the_ally_menu_leads_to_the_body_picture() -> void:
	var hud = game.hud
	var comp = hud.ally_buttons[0]["p"]
	hud._ally_menu(comp)
	var found: Button = null
	var stack: Array = [hud.modal]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is Button and n.text == "몸 상태":
			found = n
		for c in n.get_children():
			stack.append(c)
	assert_not_null(found)
	found.pressed.emit()
	assert_eq(hud.body_shown, comp)
	assert_almost_eq(game.slow, 0.3, 0.001)


# ---------------------------------------------------------------- state icons

func _toast_texts() -> Array:
	return game.hud.toasts.map(func(t): return String(t["l"].text))


func test_state_icons_show_the_most_urgent_first_two_of_them_big() -> void:
	var p = game.player
	var hud = game.hud
	hud.tick(0.02)
	for pad in hud.status_pads:
		assert_false(pad.visible, "nothing wrong: no icons")
	p.body.add_wound("torso", "deep", 0.0)
	p.body.add_wound("arm_left", "fracture", 0.0)
	p.body.exhaustion = 0.6
	hud.tick(0.02)
	assert_eq(hud.status_rows.size(), 3)
	assert_eq(hud.status_pads[0].text, "출혈", "the severe one leads")
	assert_true(hud.status_pads[2].visible)
	assert_false(hud.status_pads[3].visible)
	assert_gt(hud.status_pads[0].size.x, hud.status_pads[2].size.x, "two big, the rest small")
	await wait_frames(2)
	var home: Vector2 = hud.stick_home()
	for pad in hud.status_pads:
		var rect: Rect2 = pad.get_global_rect()
		var near := Vector2(clampf(home.x, rect.position.x, rect.end.x), clampf(home.y, rect.position.y, rect.end.y))
		assert_gt(near.distance_to(home), hud.STICK_R * hud.STICK_CATCH)
		assert_false(rect.intersects(hud.portrait.get_global_rect()))
		assert_false(rect.intersects(hud.blood_button.get_global_rect()))


func test_pressing_a_state_icon_says_the_noun_phrase_and_good_or_bad() -> void:
	var p = game.player
	var hud = game.hud
	p.body.add_wound("torso", "deep", 0.0)
	hud.tick(0.02)
	await wait_frames(2)
	var at: Vector2 = hud.status_pads[0].get_global_rect().get_center()
	hud.finger_down(1, at)
	hud.finger_up(1, at)
	var said: String = _toast_texts()[-1]
	assert_true(said.begins_with("심한 출혈 (나쁨): "), said)
	assert_eq(p.action, "", "an icon only tells")
	assert_false(hud.modal_open)


func test_every_state_has_words() -> void:
	var Body = preload("res://game/sim/body_state.gd")
	var b = Body.new()
	b.add_wound("torso", "deep", 0.0)
	b.add_wound("leg_left", "fracture", 0.0)
	b.apply_bite(RandomNumberGenerator.new(), "arm", 0.0)
	b.exhaustion = 0.9
	b.cold_level = 1
	var rows: Array = b.status_notes()
	assert_eq(rows.size(), 5)
	assert_eq(rows[0]["id"], "infection", "the bite leads")
	for row: Dictionary in rows:
		assert_ne(row["short"], "", row["id"])
		assert_ne(row["title"], "", row["id"])
		assert_ne(row["text"], "", row["id"])
		assert_false(row["good"])
	assert_true(String(rows[0]["text"]).contains("8분 00초"))
	b.splint()
	var leg: Dictionary = b.status_notes().filter(func(r): return r["id"] == "fracture")[0]
	assert_eq(leg["title"], "부목 댄 다리 골절")
	assert_eq(Body.new().status_notes().size(), 0)


func test_the_blood_key_is_pointed_at_once_and_says_what_it_binds() -> void:
	var p = game.player
	var hud = game.hud
	p.add_item("bandage", 2)
	p.body.add_wound("arm_left", "laceration", 0.0)
	hud.tick(0.02)
	hud.tick(0.02)
	var hints: Array = _toast_texts().filter(func(t): return t.contains("'지혈'"))
	assert_eq(hints.size(), 1, "one line, once")
	await wait_frames(2)
	var at: Vector2 = hud.blood_button.get_global_rect().get_center()
	hud.finger_down(1, at)
	hud.finger_up(1, at)
	assert_true(_toast_texts().has("지혈한다: 왼팔 찢김 · 피 보통."))
	assert_ne(p.action, "", "and it starts")
