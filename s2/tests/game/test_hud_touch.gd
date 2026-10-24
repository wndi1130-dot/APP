extends "res://addons/gut/test.gd"
## The field HUD's small keys keep the picture they have and take a finger
## 48 dp wide (user 2026-10-24): a touch just off one still lands on it, and
## where two of those widened rects meet the nearer key wins.

const FieldGame = preload("res://game/field_game.gd")

var game
var hud


func _start() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	hud = game.hud
	for i in 2:
		hud.tick(0.016)
		await get_tree().process_frame


## The keys drawn under 48 dp: the top row (the clock's glass, the goals' and
## promises' keys, the test keys), the lever's handle, pause, the companions'
## faces, the gear, the state icons, the bag, 지혈, 따라와 · 대기.
func _small_keys() -> Dictionary:
	var top: Array = [hud.clock_pill, hud.promise_key, hud.goal_key]
	top.append_array(hud.test_keys.get_children())
	return {
		"top row": top,
		"lever": [hud.lever_button],
		"pause": [hud.pause_button],
		"faces": hud.ally_buttons.map(func(r): return r["b"]),
		"gear": [hud.settings_button],
		"state icons": hud.status_pads,
		"bag": [hud.bag_button],
		"bleeding": [hud.blood_button],
		"orders": [hud.follow_button, hud.wait_button],
	}


func test_every_small_key_takes_a_finger_48_dp_wide_round_its_picture() -> void:
	await _start()
	assert_eq(hud.MIN_TOUCH, ceilf(7.62 * hud.PX_PER_MM), "48 dp is 7.62 mm")
	var keys: Dictionary = _small_keys()
	assert_eq(keys.size(), 9)
	var n: int = 0
	for kind: String in keys:
		assert_gt(keys[kind].size(), 0, kind)
		for k: Control in keys[kind]:
			var drawn: Rect2 = k.get_global_rect()
			var touch: Rect2 = hud.touch_rect(k)
			assert_lt(minf(drawn.size.x, drawn.size.y), hud.MIN_TOUCH, "%s %s: drawn under 48 dp" % [kind, k.name])
			assert_gte(touch.size.x, hud.MIN_TOUCH - 0.01, "%s %s: wide enough" % [kind, k.name])
			assert_gte(touch.size.y, hud.MIN_TOUCH - 0.01, "%s %s: tall enough" % [kind, k.name])
			assert_true(touch.encloses(drawn), "%s %s: round its picture" % [kind, k.name])
			assert_almost_eq(touch.get_center(), drawn.get_center(), Vector2.ONE * 0.01, "%s %s: grown evenly" % [kind, k.name])
			n += 1
	gut.p("%d keys widened" % n)


func test_a_touch_just_off_pause_still_pauses_and_one_further_out_does_not() -> void:
	await _start()
	var r: Rect2 = hud.pause_button.get_global_rect()
	var far := Vector2(r.position.x - 6.0, r.get_center().y)
	var near := Vector2(r.position.x - 2.0, r.get_center().y)
	assert_null(hud._button_at(near), "nothing drawn there")
	assert_false(hud.portrait.get_global_rect().has_point(near))
	hud.finger_down(0, far)
	hud.finger_cancel(0)
	assert_false(game.paused, "6 px off: outside 48 dp")
	assert_true(hud.finger_down(0, near), "2 px off: the first finger is the HUD's")
	assert_eq(hud.fingers[0]["kind"], "pad")
	assert_true(game.paused, "pause takes it")
	hud.finger_up(0, near)
	game.paused = false


func test_where_two_widened_keys_meet_the_nearer_one_wins() -> void:
	await _start()
	var minus: Button = hud.test_keys.get_child(0)
	var plus: Button = hud.test_keys.get_child(1)
	var a: Rect2 = minus.get_global_rect()
	var b: Rect2 = plus.get_global_rect()
	assert_almost_eq(b.position.x - a.end.x, 8.0, 0.5, "8 apart")
	# 2 px right of 「−」 is 6 left of 「+」: both widened rects hold it.
	var at := Vector2(a.end.x + 2.0, a.get_center().y)
	assert_true(hud.touch_rect(minus).has_point(at) and hud.touch_rect(plus).has_point(at))
	watch_signals(minus)
	watch_signals(plus)
	assert_true(hud.finger_down(0, at))
	assert_eq(hud.fingers[0]["button"], minus, "the nearer: 「−」")
	hud.finger_up(0, at)
	assert_signal_emitted(minus, "pressed")
	assert_signal_not_emitted(plus, "pressed")
	# And 2 px left of 「+」 is 「+」.
	var at2 := Vector2(b.position.x - 2.0, b.get_center().y)
	assert_true(hud.finger_down(0, at2))
	assert_eq(hud.fingers[0]["button"], plus, "the nearer: 「+」")
	hud.finger_up(0, at2)
	assert_signal_emitted(plus, "pressed")
